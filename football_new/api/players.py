# api/players.py
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from typing import Optional
import math
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
engine: Engine = create_engine(DB_URL, pool_pre_ping=True)

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
        sql = """
        WITH j AS (
          SELECT
            p.player_id, p.player_name AS player,
            p.team_id, p.team_name,
            s.date::date AS dt, s.league_name AS league, s.season::text AS season
          FROM football.api_football_player_stats p
          JOIN football.api_football_schedule s USING (fixture_id)
          WHERE p.player_id = :player_id
        ),
        last_row AS (
          SELECT DISTINCT ON (player_id)
                 player_id, player, team_id, team_name, league, season, dt
          FROM j
          ORDER BY player_id, dt DESC
        )
        SELECT
          player_id, player,
          team_id AS last_team_id, team_name AS last_team,
          league AS last_league, season AS last_season
        FROM last_row;
        """
        with engine.begin() as con:
            row = con.execute(text(sql), {"player_id": player_id}).mappings().first()
        return _sanitize([dict(row or {})])[0]
    except Exception as e:
        logger.exception("player_overview failed")
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
