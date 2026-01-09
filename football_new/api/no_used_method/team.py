# api/team.py
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
import pandas as pd
import math
import os
import logging
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")

DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:0506@localhost:5432/dwh")
engine: Engine = create_engine(DB_URL, pool_pre_ping=True)

router = APIRouter(
    prefix="/api",
    tags=["Команды"],
    responses={404: {"description": "Not found"}}
)


def _sanitize_list(records):
    out = []
    for r in records:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


def _sanitize_one(d):
    return _sanitize_list([d])[0]


# -----------------------------
# 1) УНИКАЛЬНЫЕ КОМАНДЫ ЛИГИ
# -----------------------------
@router.get("/league/teams")
def league_teams(
    league: str = Query(..., description="Premier League | La Liga | Bundesliga | Serie A | Ligue 1"),
    season: str = Query(..., description="Год сезона, напр. 2025"),
):
    """
    Уникальные команды лиги/сезона из расписания.
    Возвращает [{team_id, team}]
    """
    try:
        q = """
        WITH t AS (
          SELECT DISTINCT s.home_team_id AS team_id, s.home_team AS team
          FROM football.api_football_schedule s
          WHERE s.league_name = :league AND s.season::text = :season
          UNION
          SELECT DISTINCT s.away_team_id AS team_id, s.away_team AS team
          FROM football.api_football_schedule s
          WHERE s.league_name = :league AND s.season::text = :season
        )
        SELECT team_id, team
        FROM t
        WHERE team_id IS NOT NULL AND team IS NOT NULL
        ORDER BY team;
        """
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(text(q), {"league": league, "season": season}).mappings()]
        return rows
    except Exception as e:
        logger.exception("league_teams failed")
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------
# 2) ОБЩАЯ СВОДКА ПО КОМАНДЕ (SEASON)
# ---------------------------------
@router.get("/team/overview")
def team_overview(
    team_id: int = Query(..., description="ID команды"),
    season: str = Query(..., description="Год сезона, напр. 2025"),
    league: Optional[str] = Query(None, description="Название лиги (если нет league_id)"),
    league_id: Optional[int] = Query(None, description="ID лиги (приоритетнее league)"),
):
    """
    Унифицированная сводка по команде за сезон.
    Можно передавать league ИЛИ league_id (league_id приоритетнее).
    Возвращает и per-game, и алиасы для сравнения (xg/xga/shots/possession/tempo).
    """
    try:
        if league_id is None and not league:
            raise HTTPException(status_code=400, detail="Передай league или league_id")

        with engine.begin() as con:
            q = text("""
            -- 1) league_name из SCHEDULE (с приоритетом league_id), иначе параметр league
            WITH ln AS (
              SELECT COALESCE(
                (SELECT sc.league_name
                   FROM football.api_football_schedule sc
                  WHERE sc.season::text = :season
                    AND (:league_id IS NULL OR sc.league_id = :league_id)
                    AND (sc.home_team_id = :team_id OR sc.away_team_id = :team_id)
                  ORDER BY sc.date DESC
                  LIMIT 1),
                :league
              ) AS league_name
            ),

            -- 2) Сыгранные матчи команды
            played AS (
              SELECT sc.fixture_id,
                     sc.date::date AS dt,
                     sc.home_team_id, sc.away_team_id,
                     sc.home_team, sc.away_team,
                     sc.score_fulltime_home, sc.score_fulltime_away,
                     (sc.home_team_id = :team_id) AS is_home
              FROM football.api_football_schedule sc
              JOIN ln ON ln.league_name = sc.league_name
              WHERE sc.season::text = :season
                AND (sc.home_team_id = :team_id OR sc.away_team_id = :team_id)
                AND COALESCE(sc.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
            ),

            -- 3) Итоги по результатам
            res_agg AS (
              SELECT
                COUNT(*) AS matches_played,
                SUM(CASE WHEN (is_home AND score_fulltime_home > score_fulltime_away)
                          OR (NOT is_home AND score_fulltime_away > score_fulltime_home) THEN 1 ELSE 0 END) AS wins,
                SUM(CASE WHEN score_fulltime_home = score_fulltime_away THEN 1 ELSE 0 END) AS draws,
                SUM(CASE WHEN (is_home AND score_fulltime_home < score_fulltime_away)
                          OR (NOT is_home AND score_fulltime_away < score_fulltime_home) THEN 1 ELSE 0 END) AS losses,
                SUM(CASE WHEN is_home THEN score_fulltime_home ELSE score_fulltime_away END) AS goals_for,
                SUM(CASE WHEN is_home THEN score_fulltime_away ELSE score_fulltime_home END) AS goals_against
              FROM played
            ),

            -- 4) Матчстаты нашей команды и соперника
            ms_team AS (
              SELECT
                ms.fixture_id,
                ms.expected_goals AS xg,
                ms.total_shots    AS shots,
                NULLIF(regexp_replace(COALESCE(ms.possession::text,''), '[^0-9\\.]', '', 'g'),'')::numeric AS possession
              FROM football.api_football_match_stats ms
              JOIN played p USING (fixture_id)
              WHERE ms.team_id = :team_id
            ),
            ms_opp AS (
              SELECT
                ms.fixture_id,
                ms.expected_goals AS xg_opp,
                ms.total_shots    AS shots_opp
              FROM football.api_football_match_stats ms
              JOIN played p USING (fixture_id)
              WHERE ms.team_id <> :team_id
            ),
            ms_agg AS (
              SELECT
                AVG(ms_team.xg)::double precision         AS xg_avg,
                AVG(ms_opp.xg_opp)::double precision      AS xga_avg,
                AVG(ms_team.shots)::double precision      AS shots_avg,
                AVG(ms_team.possession)::double precision AS poss_avg,
                AVG(COALESCE(ms_team.shots,0)+COALESCE(ms_opp.shots_opp,0))::double precision AS tempo_avg
              FROM ms_team LEFT JOIN ms_opp USING (fixture_id)
            ),

            -- 5) league_id: параметр → standings → schedule
            lid AS (
              SELECT COALESCE(
                :league_id,
                (SELECT s.league_id
                   FROM football.api_football_standings s
                  WHERE s.team_id = :team_id AND s.season::text = :season
                  ORDER BY s.league_id NULLS LAST
                  LIMIT 1),
                (SELECT sc.league_id
                   FROM football.api_football_schedule sc
                   JOIN ln ON ln.league_name = sc.league_name
                  WHERE sc.season::text = :season
                    AND (sc.home_team_id = :team_id OR sc.away_team_id = :team_id)
                  ORDER BY sc.date DESC
                  LIMIT 1)
              ) AS league_id
            ),

            -- 6) team_stats/standings по league_id
            ts AS (
              SELECT t.*
              FROM football.api_football_team_stats t
              JOIN lid ON lid.league_id = t.league_id
              WHERE t.team_id = :team_id
                AND t.season::text = :season
              LIMIT 1
            ),
            st AS (
              SELECT s.rank, s.points, s.form
              FROM football.api_football_standings s
              JOIN lid ON lid.league_id = s.league_id
              WHERE s.team_id = :team_id
                AND s.season::text = :season
              ORDER BY s.rank NULLS LAST
              LIMIT 1
            ),

            team_name_src AS (
              SELECT
                COALESCE(
                  (SELECT home_team FROM played WHERE is_home = TRUE  ORDER BY dt DESC LIMIT 1),
                  (SELECT away_team FROM played WHERE is_home = FALSE ORDER BY dt DESC LIMIT 1)
                ) AS team_name
            )

            -- 7) Единый ряд (все обращения к CTE только через скалярные подзапросы)
            SELECT
              COALESCE((SELECT team_name FROM ts), (SELECT team_name FROM team_name_src)) AS team_name,
              (SELECT league_name FROM ln)                                              AS league_name,

              COALESCE((SELECT matches_played FROM ts), (SELECT matches_played FROM res_agg)) AS matches_played,
              COALESCE((SELECT wins           FROM ts), (SELECT wins           FROM res_agg)) AS wins,
              COALESCE((SELECT draws          FROM ts), (SELECT draws          FROM res_agg)) AS draws,
              COALESCE((SELECT losses         FROM ts), (SELECT losses         FROM res_agg)) AS losses,
              COALESCE((SELECT goals_for      FROM ts), (SELECT goals_for      FROM res_agg)) AS goals_for,
              COALESCE((SELECT goals_against  FROM ts), (SELECT goals_against  FROM res_agg)) AS goals_against,

              (SELECT expected_goals_total         FROM ts) AS xg_total_ts,
              (SELECT expected_goals_against_total FROM ts) AS xga_total_ts,

              (SELECT shots_avg            FROM ts) AS shots_avg_ts,
              (SELECT possession_avg       FROM ts) AS poss_avg_ts,
              (SELECT tempo_shots_per_game FROM ts) AS tempo_avg_ts,

              (SELECT xg_avg   FROM ms_agg) AS xg_avg_ms,
              (SELECT xga_avg  FROM ms_agg) AS xga_avg_ms,
              (SELECT shots_avg FROM ms_agg) AS shots_avg_ms,
              (SELECT poss_avg  FROM ms_agg) AS poss_avg_ms,
              (SELECT tempo_avg FROM ms_agg) AS tempo_avg_ms,

              (SELECT rank   FROM st) AS rank,
              (SELECT points FROM st) AS points,
              (SELECT form   FROM st) AS form
            """)
            df = pd.read_sql(
                q,
                con,
                params={
                    "team_id": team_id,
                    "season": str(season),
                    "league": league,
                    "league_id": league_id,
                },
            )

        if df.empty:
            return {}

        r = df.iloc[0].to_dict()
        mp = int(r.get("matches_played") or 0)

        def pick(*vals):
            for v in vals:
                if v is None:
                    continue
                try:
                    f = float(v)
                    if math.isnan(f) or math.isinf(f):
                        continue
                except Exception:
                    pass
                return v
            return None

        # totals
        xg_total  = pick(r.get("xg_total_ts"),  (r.get("xg_avg_ms")  * mp if (r.get("xg_avg_ms")  is not None and mp) else None))
        xga_total = pick(r.get("xga_total_ts"), (r.get("xga_avg_ms") * mp if (r.get("xga_avg_ms") is not None and mp) else None))

        # per-game
        goals_per_game    = (float(r["goals_for"])/mp) if (r.get("goals_for") is not None and mp) else None
        conceded_per_game = (float(r["goals_against"])/mp) if (r.get("goals_against") is not None and mp) else None
        xg_per_game       = pick(r.get("xg_avg_ms"),  (xg_total/mp if (xg_total is not None and mp) else None))
        xga_per_game      = pick(r.get("xga_avg_ms"), (xga_total/mp if (xga_total is not None and mp) else None))
        shots_avg         = pick(r.get("shots_avg_ts"), r.get("shots_avg_ms"))
        possession_avg    = pick(r.get("poss_avg_ts"),  r.get("poss_avg_ms"))
        tempo_avg         = pick(r.get("tempo_avg_ts"), r.get("tempo_avg_ms"))

        out = {
            "team_id": team_id,
            "league": r.get("league_name") or league,
            "league_name": r.get("league_name") or league,
            "season": str(season),
            "team_name": r.get("team_name"),

            "matches_played": mp or None,
            "wins": r.get("wins"),
            "draws": r.get("draws"),
            "losses": r.get("losses"),
            "goals_for": r.get("goals_for"),
            "goals_against": r.get("goals_against"),
            "goal_diff": (int(r["goals_for"]) - int(r["goals_against"])) if (r.get("goals_for") is not None and r.get("goals_against") is not None) else None,

            "rank": r.get("rank"),
            "points": r.get("points"),
            "form": r.get("form"),

            "xg_total": xg_total,
            "xga_total": xga_total,

            "goals_per_game": round(goals_per_game, 2) if goals_per_game is not None else None,
            "conceded_per_game": round(conceded_per_game, 2) if conceded_per_game is not None else None,
            "xg_per_game": round(xg_per_game, 2) if xg_per_game is not None else None,
            "xga_per_game": round(xga_per_game, 2) if xga_per_game is not None else None,
            "shots_avg": round(float(shots_avg), 2) if shots_avg is not None else None,
            "possession_avg": round(float(possession_avg), 2) if possession_avg is not None else None,
            "tempo_shots_per_game": round(float(tempo_avg), 2) if tempo_avg is not None else None,
        }

        # Алиасы для сравнения/старых компонентов
        out["xg"] = out["xg_per_game"]
        out["xga"] = out["xga_per_game"]
        out["shots"] = out["shots_avg"]
        out["possession"] = out["possession_avg"]
        out["tempo"] = out["tempo_shots_per_game"]
        out["team"] = out["team_name"]  # для старой TeamPage

        return _sanitize_one(out)

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("team_overview failed")
        raise HTTPException(status_code=500, detail=str(e))


# -----------------------------
# 3) РОЛЛИНГИ (сырые матчи)
# -----------------------------
@router.get("/team/rolling")
def team_rolling(
    team_id: int = Query(...),
    league: str = Query(...),
    season: str = Query(...),
    window: int = Query(5, description="Окно сглаживания делает фронт; здесь отдаём сырые матчи"),
):
    """
    Сырые матчи команды (для построения трендов на фронте).
    """
    try:
        q = """
        WITH base AS (
          SELECT s.fixture_id, s.date::date AS dt,
                 s.league_name AS league, s.season::text AS season,
                 s.home_team_id, s.away_team_id
          FROM football.api_football_schedule s
          WHERE s.league_name = :league AND s.season::text = :season
        ),
        j AS (
          SELECT b.dt, b.league, b.season,
                 b.home_team_id, b.away_team_id,
                 h.expected_goals        AS home_xg,
                 a.expected_goals        AS away_xg,
                 h.total_shots           AS home_shots,
                 a.total_shots           AS away_shots,
                 NULLIF(regexp_replace(COALESCE(h.possession::text,''), '[^0-9\\.]', '', 'g'),'')::numeric AS home_poss,
                 NULLIF(regexp_replace(COALESCE(a.possession::text,''), '[^0-9\\.]', '', 'g'),'')::numeric AS away_poss
          FROM base b
          LEFT JOIN football.api_football_match_stats h
                 ON h.fixture_id = b.fixture_id AND h.team_id = b.home_team_id
          LEFT JOIN football.api_football_match_stats a
                 ON a.fixture_id = b.fixture_id AND a.team_id = b.away_team_id
        ),
        rows AS (
          SELECT
            to_char(dt, 'YYYY-MM-DD') AS date,
            home_xg         AS xg,
            away_xg         AS xga,
            home_shots      AS shots,
            home_poss       AS possession
          FROM j WHERE home_team_id = :team_id

          UNION ALL

          SELECT
            to_char(dt, 'YYYY-MM-DD'),
            away_xg,
            home_xg,
            away_shots,
            away_poss
          FROM j WHERE away_team_id = :team_id
        )
        SELECT * FROM rows ORDER BY date;
        """
        with engine.begin() as con:
            rows = [dict(r) for r in con.execute(
                text(q),
                {"league": league, "season": str(season), "team_id": team_id},
            ).mappings()]
        return _sanitize_list(rows)

    except Exception as e:
        logger.exception("team_rolling failed")
        raise HTTPException(status_code=500, detail=str(e))


# -----------------------------
# 4) РЕЗУЛЬТАТЫ КОМАНДЫ
# -----------------------------
@router.get("/team/results")
def team_results(
    team_id: int = Query(..., description="ID команды"),
    league: str = Query(..., description="Название лиги"),
    season: str = Query(..., description="Год сезона, напр. 2025"),
):
    """
    Все сыгранные матчи команды с ключевой матстатой.
    """
    try:
        q = """
        WITH base AS (
          SELECT
            s.fixture_id,
            s.date::date AS date,
            s.round AS round_label,
            s.home_team_id, s.away_team_id,
            s.home_team, s.away_team,
            s.score_fulltime_home, s.score_fulltime_away
          FROM football.api_football_schedule s
          WHERE s.league_name = :league
            AND s.season::text = :season
            AND (s.home_team_id = :team_id OR s.away_team_id = :team_id)
            AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
        ),
        me AS (
          SELECT ms.fixture_id,
                 ms.expected_goals      AS xg,
                 ms.total_shots         AS shots,
                 ms.shots_on_goal       AS shots_on_goal,
                 NULLIF(regexp_replace(COALESCE(ms.possession::text,''), '[^0-9\\.]', '', 'g'),'')::numeric AS possession
          FROM football.api_football_match_stats ms
          WHERE ms.team_id = :team_id
        )
        SELECT
          b.fixture_id,
          to_char(b.date, 'YYYY-MM-DD') AS date,
          b.round_label,

          CASE WHEN b.home_team_id = :team_id THEN 'H' ELSE 'A' END AS side,

          CASE WHEN b.home_team_id = :team_id THEN b.away_team ELSE b.home_team END AS opponent_name,
          CASE WHEN b.home_team_id = :team_id THEN b.away_team_id ELSE b.home_team_id END AS opponent_id,

          CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_home ELSE b.score_fulltime_away END AS team_goals,
          CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_away ELSE b.score_fulltime_home END AS opp_goals,

          CASE
            WHEN b.score_fulltime_home IS NULL OR b.score_fulltime_away IS NULL THEN NULL
            ELSE CONCAT(b.score_fulltime_home::text,'-',b.score_fulltime_away::text)
          END AS score_str,

          CASE
            WHEN b.score_fulltime_home IS NULL OR b.score_fulltime_away IS NULL THEN NULL
            WHEN (CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_home ELSE b.score_fulltime_away END) >
                 (CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_away ELSE b.score_fulltime_home END)
              THEN 1
            WHEN (CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_home ELSE b.score_fulltime_away END) <
                 (CASE WHEN b.home_team_id = :team_id THEN b.score_fulltime_away ELSE b.score_fulltime_home END)
              THEN -1
            ELSE 0
          END AS result,

          me.xg,
          me.shots,
          me.shots_on_goal,
          me.possession

        FROM base b
        LEFT JOIN me USING (fixture_id)
        ORDER BY b.date DESC, b.fixture_id DESC
        """
        with engine.begin() as con:
            df = pd.read_sql(text(q), con, params={"team_id": team_id, "league": league, "season": str(season)})
        return _sanitize_list(df.to_dict(orient="records"))

    except Exception as e:
        logger.exception("team_results failed")
        raise HTTPException(status_code=500, detail=str(e))
