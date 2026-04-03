from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
import logging
import math
from api.core.config import settings

logger = logging.getLogger("uvicorn")

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

router = APIRouter(prefix="/api", tags=["Search"])


def _sanitize(rows):
    out = []
    for r in rows:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


@router.get("/search")
def global_search(
    q: str = Query("", description="Search query"),
    league: str = Query(None),
    season: str = Query(None),
    limit: int = Query(8, ge=1, le=25),
):
    try:
        q = (q or "").strip()
        if not q:
            return {"players": [], "teams": [], "matches": []}
        pattern = f"%{q}%"

        with engine.begin() as con:
            # Players
            player_sql = text(
                """
                WITH base AS (
                  SELECT fixture_id, date::date AS dt, league_name, season::text
                  FROM football.api_football_schedule
                  WHERE (:league IS NULL OR league_name = :league)
                    AND (:season IS NULL OR season::text = :season)
                ),
                j AS (
                  SELECT
                    p.player_id,
                    p.player_name AS player,
                    p.team_id,
                    p.team_name,
                    b.dt
                  FROM football.api_football_player_stats p
                  JOIN base b USING (fixture_id)
                  WHERE p.player_name ILIKE :q
                ),
                latest_team AS (
                  SELECT DISTINCT ON (player_id)
                    player_id, team_id, team_name AS team
                  FROM j
                  ORDER BY player_id, dt DESC
                )
                SELECT p.player_id, p.player, lt.team_id, lt.team
                FROM (SELECT DISTINCT player_id, player FROM j) p
                LEFT JOIN latest_team lt USING (player_id)
                ORDER BY p.player
                LIMIT :limit;
                """
            )
            players = [
                dict(r)
                for r in con.execute(
                    player_sql,
                    {
                        "q": pattern,
                        "league": league,
                        "season": season,
                        "limit": limit,
                    },
                ).mappings()
            ]

            # Teams
            teams_sql = text(
                """
                WITH base AS (
                  SELECT home_team_id AS team_id, home_team AS team
                  FROM football.api_football_schedule
                  WHERE (:league IS NULL OR league_name = :league)
                    AND (:season IS NULL OR season::text = :season)
                  UNION
                  SELECT away_team_id AS team_id, away_team AS team
                  FROM football.api_football_schedule
                  WHERE (:league IS NULL OR league_name = :league)
                    AND (:season IS NULL OR season::text = :season)
                )
                SELECT DISTINCT team_id, team
                FROM base
                WHERE team ILIKE :q
                ORDER BY team
                LIMIT :limit;
                """
            )
            teams = [
                dict(r)
                for r in con.execute(
                    teams_sql,
                    {
                        "q": pattern,
                        "league": league,
                        "season": season,
                        "limit": limit,
                    },
                ).mappings()
            ]

            # Matches
            matches_sql = text(
                """
                SELECT
                  s.fixture_id,
                  s.date::date AS dt,
                  s.league_name AS league,
                  s.season::text AS season,
                  s.home_team_id,
                  s.away_team_id,
                  s.home_team,
                  s.away_team
                FROM football.api_football_schedule s
                WHERE (:league IS NULL OR s.league_name = :league)
                  AND (:season IS NULL OR s.season::text = :season)
                  AND (s.home_team ILIKE :q OR s.away_team ILIKE :q)
                ORDER BY s.date DESC
                LIMIT :limit;
                """
            )
            matches = [
                dict(r)
                for r in con.execute(
                    matches_sql,
                    {
                        "q": pattern,
                        "league": league,
                        "season": season,
                        "limit": limit,
                    },
                ).mappings()
            ]

        return {
            "players": _sanitize(players),
            "teams": _sanitize(teams),
            "matches": _sanitize(matches),
        }
    except Exception as e:
        logger.exception("global_search failed")
        raise HTTPException(status_code=500, detail=str(e))
