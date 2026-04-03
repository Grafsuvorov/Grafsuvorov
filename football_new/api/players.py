# api/players.py
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
from api.ucl_filters import schedule_round_filter_sql
from sqlalchemy.engine import Engine
from typing import Optional
import math
import logging
from api.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")

engine: Engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

router = APIRouter(
    prefix="/api",
    tags=["Игроки"],
    responses={404: {"description": "Not found"}}
)

def _sanitize(rows):
    out = []
    for r in rows:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


# 1) Поиск игроков (по имени), можно ограничить лигой/сезоном
@router.get("/players/search",
    summary="Поиск игроков",
    description="Поиск игроков по имени с возможностью фильтрации по лиге и сезону"
)
def players_search(
    q: str = Query("", description="Поисковый запрос по имени игрока"),
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    """
    Возвращает список игроков под поиск.
    Если league/season заданы — фильтруем, иначе ищем по всей БД.
    """
    try:
        qpattern = f"%{q.strip()}%" if q else "%"
        where_base = []
        params = {"q": qpattern, "limit": limit}  # <-- ВАЖНО: добавили limit

        base_sql = (
            "SELECT fixture_id, date::date AS dt, league_name, season::text, "
            "home_team_id, away_team_id, home_team, away_team "
            "FROM football.api_football_schedule"
        )
        if league:
            where_base.append("league_name = :league")
            params["league"] = league
        if season:
            where_base.append("season::text = :season")
            params["season"] = season
        if where_base:
            base_sql += " WHERE " + " AND ".join(where_base)

        sql = f"""
        WITH base AS (
          {base_sql}
        ),
        j AS (
          SELECT
            p.player_id,
            p.player_name AS player,
            p.team_id,
            p.team_name,
            p.player_rating::numeric AS rating,
            COALESCE(p.minutes,0)::int AS minutes,
            COALESCE(p.goals,0)::int   AS goals,
            COALESCE(p.assists,0)::int AS assists,
            b.dt, b.league_name AS league, b.season
          FROM football.api_football_player_stats p
          JOIN base b USING (fixture_id)
          WHERE p.player_name ILIKE :q
        ),
        agg AS (
          SELECT
            player_id, player,
            AVG(rating)             AS avg_rating,
            COUNT(*)                AS apps,
            SUM(minutes)            AS minutes,
            SUM(goals)              AS goals,
            SUM(assists)            AS assists
          FROM j
          WHERE rating IS NOT NULL
          GROUP BY player_id, player
        ),
        latest_team AS (
          SELECT DISTINCT ON (player_id)
                 player_id, team_id, team_name, dt
          FROM j
          ORDER BY player_id, dt DESC
        )
        SELECT
          a.player_id, a.player,
          lt.team_id, lt.team_name AS team,
          a.apps, a.minutes, a.goals, a.assists,
          ROUND(COALESCE(a.avg_rating,0)::numeric, 2) AS rating
        FROM agg a
        LEFT JOIN latest_team lt USING (player_id)
        ORDER BY rating DESC NULLS LAST, minutes DESC
        LIMIT :limit;
        """
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(text(sql), params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_search failed")
        raise HTTPException(status_code=500, detail=str(e))


# 2) Топ по рейтингу в рамках лиги/сезона (дефолтный список)


# 3) Овервью игрока (последний клуб/лига/сезон)
@router.get("/player/overview")
def player_overview(player_id: int = Query(...)):
    try:
        with engine.begin() as con:
            has_players_table = con.execute(
                text("SELECT to_regclass('football.api_football_players')")
            ).scalar()
            has_topscorers_table = con.execute(
                text("SELECT to_regclass('football.api_football_topscorers')")
            ).scalar()
            has_topassists_table = con.execute(
                text("SELECT to_regclass('football.api_football_topassists_min')")
            ).scalar()
            stats_cols = [
                r[0]
                for r in con.execute(
                    text(
                        """
                        SELECT column_name
                        FROM information_schema.columns
                        WHERE table_schema = 'football'
                          AND table_name = 'api_football_player_stats'
                        """
                    )
                ).all()
            ]
        stats_has_age = "player_age" in stats_cols or "age" in stats_cols
        stats_has_pos = "player_position" in stats_cols or "position" in stats_cols

        select_age = "p.age" if has_players_table else (
            "j.player_age" if "player_age" in stats_cols else ("j.age" if "age" in stats_cols else "NULL")
        )
        select_birth = "p.birth_date" if has_players_table else "NULL"
        select_pos = "p.position" if has_players_table else (
            "j.player_position" if "player_position" in stats_cols else ("j.position" if "position" in stats_cols else "NULL")
        )

        topscorers_cte = """
        , top_scorers AS (
          SELECT DISTINCT ON (t.player_id)
                 t.player_id,
                 t.player_age,
                 t.position AS ts_position
          FROM football.api_football_topscorers t
          JOIN last_row lr ON lr.player_id = t.player_id
          WHERE t.league_name = lr.league AND t.season::text = lr.season
          ORDER BY t.player_id, COALESCE(t.goals_total, 0) DESC
        )
        """ if has_topscorers_table else ""

        topassists_cte = """
        , top_assists AS (
          SELECT DISTINCT ON (t.player_id)
                 t.player_id,
                 t.player_age,
                 t.position AS ta_position
          FROM football.api_football_topassists_min t
          JOIN last_row lr ON lr.player_id = t.player_id
          WHERE t.league_name = lr.league AND t.season::text = lr.season
          ORDER BY t.player_id, COALESCE(t.goals_assists, 0) DESC
        )
        """ if has_topassists_table else ""

        topscorers_join = "LEFT JOIN top_scorers ts ON ts.player_id = lr.player_id" if has_topscorers_table else ""
        topassists_join = "LEFT JOIN top_assists ta ON ta.player_id = lr.player_id" if has_topassists_table else ""
        select_age_expr = (
            f"COALESCE({select_age}, ts.player_age, ta.player_age)"
            if has_topscorers_table or has_topassists_table
            else select_age
        )
        select_pos_expr = (
            f"COALESCE(ts.ts_position, ta.ta_position, {select_pos}, ll.position)"
            if has_topscorers_table or has_topassists_table
            else f"COALESCE({select_pos}, ll.position)"
        )

        sql = f"""
        WITH j AS (
          SELECT
            p.player_id, p.player_name AS player,
            p.team_id, p.team_name,
            s.date::date AS dt, s.league_name AS league, s.season::text AS season
            {', p.player_age' if 'player_age' in stats_cols else ''}
            {', p.age' if 'age' in stats_cols and 'player_age' not in stats_cols else ''}
            {', p.player_position' if 'player_position' in stats_cols else ''}
            {', p.position' if 'position' in stats_cols and 'player_position' not in stats_cols else ''}
          FROM football.api_football_player_stats p
          JOIN football.api_football_schedule s USING (fixture_id)
          WHERE p.player_id = :player_id
        ),
        last_row AS (
          SELECT DISTINCT ON (player_id)
                 player_id, player, team_id, team_name, league, season, dt
          FROM j
          ORDER BY player_id, dt DESC
        ),
        last_lineup AS (
          SELECT DISTINCT ON (l.player_id)
                 l.player_id,
                 l.position
          FROM football.api_football_lineups l
          JOIN last_row lr ON lr.player_id = l.player_id
          JOIN football.api_football_schedule s
            ON s.fixture_id = l.fixture_id
           AND s.date::date = lr.dt
          ORDER BY l.player_id, s.date::date DESC
        )
        {topscorers_cte}
        {topassists_cte}
        SELECT
          lr.player_id,
          lr.player,
          lr.team_id AS last_team_id,
          lr.team_name AS last_team,
          lr.league AS last_league,
          lr.season AS last_season,
          {select_age_expr} AS age,
          {select_age_expr} AS player_age,
          {select_birth} AS birth_date,
          {select_pos_expr} AS position,
          ll.position AS player_position
        FROM last_row lr
        {"LEFT JOIN football.api_football_players p ON p.player_id = lr.player_id" if has_players_table else ""}
        LEFT JOIN last_lineup ll
          ON ll.player_id = lr.player_id
        {topscorers_join}
        {topassists_join};
        """
        with engine.begin() as con:
            row = con.execute(text(sql), {"player_id": player_id}).mappings().first()
        return _sanitize([dict(row or {})])[0]
    except Exception as e:
        logger.exception("player_overview failed")
        raise HTTPException(status_code=500, detail=str(e))


# 4) MVP counts by season (based on highest rating per match)
@router.get("/players/mvp")
def players_mvp(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(30, ge=0, le=120),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.fixture_id,
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                p.player_rating::numeric AS rating,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.goals,0) AS goals,
                COALESCE(p.assists,0) AS assists
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE p.player_rating IS NOT NULL
                AND COALESCE(p.minutes,0) >= :min_minutes
            ),
            ranked AS (
              SELECT
                ps.*,
                ROW_NUMBER() OVER (
                  PARTITION BY ps.fixture_id
                  ORDER BY ps.rating DESC, ps.minutes DESC, ps.goals DESC, ps.assists DESC
                ) AS rn
              FROM ps
            ),
            mvps AS (
              SELECT player_id, player_name, team_id, team_name
              FROM ranked
              WHERE rn = 1
            )
            SELECT
              player_id,
              player_name,
              team_id,
              team_name,
              COUNT(*)::int AS mvp_count
            FROM mvps
            GROUP BY player_id, player_name, team_id, team_name
            ORDER BY mvp_count DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_mvp failed")
        raise HTTPException(status_code=500, detail=str(e))


# 5) Players by total shots (season)
@router.get("/players/shots")
def players_shots(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.shots_total, p.shots_on, 0) AS shots
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(shots)::int AS shots_total
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY shots_total DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_shots failed")
        raise HTTPException(status_code=500, detail=str(e))


# 6) Players by key passes (season)
@router.get("/players/key-passes")
def players_key_passes(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.passes_key, 0) AS key_passes
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(key_passes)::int AS key_passes
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY key_passes DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_key_passes failed")
        raise HTTPException(status_code=500, detail=str(e))


# 7) Players by tackles (season)
@router.get("/players/tackles")
def players_tackles(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.tackles_total, 0) AS tackles
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(tackles)::int AS tackles
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY tackles DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_tackles failed")
        raise HTTPException(status_code=500, detail=str(e))


# 8) Players by dribbles (success)
@router.get("/players/dribbles")
def players_dribbles(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.dribbles_success, 0) AS dribbles
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(dribbles)::int AS dribbles
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY dribbles DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_dribbles failed")
        raise HTTPException(status_code=500, detail=str(e))


# 9) Players by duels won (season)
@router.get("/players/duels-won")
def players_duels_won(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.duels_won, 0) AS duels_won
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(duels_won)::int AS duels_won
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY duels_won DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_duels_won failed")
        raise HTTPException(status_code=500, detail=str(e))


# 10) Players by interceptions (season)
@router.get("/players/interceptions")
def players_interceptions(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes,
                COALESCE(p.tackles_interceptions, 0) AS interceptions
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(interceptions)::int AS interceptions
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY interceptions DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_interceptions failed")
        raise HTTPException(status_code=500, detail=str(e))


# 11) Players by minutes played (season)
@router.get("/players/minutes")
def players_minutes(
    league: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
    min_minutes: int = Query(0, ge=0, le=3000),
    window: Optional[int] = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        sql = text(
            """
            WITH fx AS (
              SELECT s.fixture_id, s.league_name, s.season::text AS season, s.date
              FROM football.api_football_schedule s
              WHERE (:league IS NULL OR s.league_name = :league)
                AND (:season IS NULL OR s.season::text = :season)
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql("COALESCE(:league, '')") + """
              ORDER BY s.date DESC
              LIMIT COALESCE(:window, 1000000)
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_id,
                p.team_name,
                COALESCE(p.minutes,0) AS minutes
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
              WHERE COALESCE(p.minutes,0) >= :min_minutes
            ),
            agg AS (
              SELECT
                player_id, player_name, team_id, team_name,
                SUM(minutes)::int AS minutes
              FROM ps
              GROUP BY player_id, player_name, team_id, team_name
            )
            SELECT *
            FROM agg
            ORDER BY minutes DESC, player_name
            LIMIT :limit;
            """
        )
        params = {
            "league": league,
            "season": season,
            "limit": limit,
            "min_minutes": min_minutes,
            "window": window,
            "ucl_stage": ucl_stage,
        }
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(sql, params).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("players_minutes failed")
        raise HTTPException(status_code=500, detail=str(e))


# 4) Последние матчи игрока
# api/players.py

@router.get("/player/recent")
def player_recent(
    player_id: int = Query(..., description="ID игрока"),
    limit: int = Query(12, ge=1, le=50),
):
    """
    Последние игры игрока (лига/сезон/его команда vs соперник) + side, рейтинг.
    Теперь отдаем opponent_team_id для лого соперника.
    """
    try:
        q = """
        WITH j AS (
          SELECT
            s.date::date                         AS date,
            s.league_name                        AS league,
            s.season::text                       AS season,
            s.fixture_id,
            -- счёт
    s.home_goals      AS home_score,
    s.away_goals      AS away_score,
            p.team_id,
            p.team_name,
            CASE WHEN p.team_id = s.home_team_id THEN 'H' ELSE 'A' END AS side,
            CASE WHEN p.team_id = s.home_team_id THEN s.away_team    ELSE s.home_team END AS opponent,
            CASE WHEN p.team_id = s.home_team_id THEN s.away_team_id ELSE s.home_team_id END AS opponent_team_id,
            COALESCE(p.minutes,0)::int           AS minutes,
            COALESCE(p.goals,0)::int             AS goals,
            COALESCE(p.assists,0)::int           AS assists,
            COALESCE(p.cards_yellow,0)::int      AS cards_yellow,
            COALESCE(p.cards_red,0)::int         AS cards_red,
            NULLIF(regexp_replace(COALESCE(p.player_rating::text,''), '[^0-9\\.]', '', 'g'),'')::numeric AS rating
          FROM football.api_football_player_stats p
          JOIN football.api_football_schedule s USING (fixture_id)
          WHERE p.player_id = :player_id
        )
        SELECT *
        FROM j
        ORDER BY date DESC
        LIMIT :limit;
        """
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(text(q), {"player_id": player_id, "limit": limit}).mappings()]
        # маленькая санитация
        for r in rows:
            if isinstance(r.get("rating"), float):
                pass
        return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




# 5) Карьера по сезонам и клубам
@router.get("/player/career")
def player_career(player_id: int = Query(...)):
    try:
        sql = """
        WITH j AS (
          SELECT
            p.player_id, p.player_name AS player,
            p.team_id, p.team_name,
            s.season::text AS season,
            p.player_rating::numeric AS rating,
            COALESCE(p.minutes,0)::int AS minutes,
            COALESCE(p.goals,0)::int   AS goals,
            COALESCE(p.assists,0)::int AS assists,
            COALESCE(p.cards_yellow,0)::int AS yc,
            COALESCE(p.cards_red,0)::int    AS rc
          FROM football.api_football_player_stats p
          JOIN football.api_football_schedule s USING (fixture_id)
          WHERE p.player_id = :player_id
        )
        SELECT
          season,
          team_id, team_name AS team,
          COUNT(*)                 AS apps,
          SUM(minutes)             AS minutes,
          SUM(goals)               AS goals,
          SUM(assists)             AS assists,
          SUM(yc)                  AS yellow,
          SUM(rc)                  AS red,
          ROUND(AVG(rating)::numeric, 2) AS rating
        FROM j
        GROUP BY season, team_id, team
        ORDER BY season DESC, team;
        """
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(text(sql), {"player_id": player_id}).mappings()]
        return _sanitize(rows)
    except Exception as e:
        logger.exception("player_career failed")
        raise HTTPException(status_code=500, detail=str(e))
