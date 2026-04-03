from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
import pandas as pd
from api.ucl_filters import schedule_round_filter_sql
from api.core.config import settings

router = APIRouter(
    prefix="/api",
    tags=["Топ бомбардиры"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
FIXTURE_SCOPED_LEAGUES = {"World Cup", "Euro Championship"}


def _records(df: pd.DataFrame):
    return df.astype(object).where(pd.notnull(df), None).to_dict(orient="records")


@router.get("/top-scorers")
def get_top_scorers(
    league: str = Query(...),
    season: int = Query(...),
    window: int = Query(None, ge=1, le=38),
    ucl_stage: str = Query("league", pattern="^(league|playoff|all)$"),
):
    try:
        if window:
            query = text("""
                WITH fx AS (
                  SELECT s.fixture_id
                  FROM football.api_football_schedule s
                  WHERE s.league_name = :league AND s.season = :season
                    AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                    """ + schedule_round_filter_sql(":league") + """
                  ORDER BY s.date DESC
                  LIMIT :window
                ),
                ps AS (
                  SELECT
                    p.player_id,
                    p.player_name,
                    p.team_name,
                    p.team_id,
                    COALESCE(p.goals,0) AS goals,
                    COALESCE(p.assists,0) AS assists,
                    COALESCE(p.minutes,0) AS minutes
                  FROM football.api_football_player_stats p
                  JOIN fx USING (fixture_id)
                ),
                agg AS (
                  SELECT
                    player_id, player_name, team_name, team_id,
                    SUM(goals)::int AS goals,
                    SUM(assists)::int AS assists,
                    SUM(minutes)::int AS minutes_played
                  FROM ps
                  GROUP BY player_id, player_name, team_name, team_id
                )
                SELECT
                  player_id, player_name, team_name, team_id,
                  goals, assists, minutes_played
                FROM agg
                ORDER BY goals DESC, assists DESC, minutes_played DESC
                LIMIT 30
            """)
            with engine.connect() as conn:
                df = pd.read_sql(
                    query,
                    conn,
                    params={"league": league, "season": season, "window": window, "ucl_stage": ucl_stage},
                )
                return _records(df)

        query = text("""
            SELECT 
                player_id,
                player_name,
                player_age,
                player_nationality,
                team_name,
                team_id,
                goals_total AS goals,
                goals_assists AS assists,
                appearances,
                minutes_played,
                position,
                penalties_scored,
                penalties_missed
            FROM football.api_football_topscorers
            WHERE league_name = :league AND season = :season
            ORDER BY goals_total DESC
            LIMIT 30
        """)

        fallback = text("""
            WITH pmeta AS (
              SELECT
                pcs.player_id,
                MAX(pcs.player_age) AS player_age,
                MAX(pcs.player_nationality) AS player_nationality,
                MAX(pcs.position) AS position
              FROM football.api_football_player_comp_season_stats pcs
              GROUP BY pcs.player_id
            ),
            fx AS (
              SELECT s.fixture_id
              FROM football.api_football_schedule s
              WHERE s.league_name = :league
                AND s.season = :season
                AND COALESCE(s.status,'') IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
                """ + schedule_round_filter_sql(":league") + """
            ),
            ps AS (
              SELECT
                p.player_id,
                p.player_name,
                p.team_name,
                p.team_id,
                COALESCE(p.goals,0) AS goals,
                COALESCE(p.assists,0) AS assists,
                COALESCE(p.minutes,0) AS minutes
              FROM football.api_football_player_stats p
              JOIN fx USING (fixture_id)
            ),
            agg AS (
              SELECT
                player_id, player_name, team_name, team_id,
                SUM(goals)::int AS goals,
                SUM(assists)::int AS assists,
                SUM(minutes)::int AS minutes_played
              FROM ps
              GROUP BY player_id, player_name, team_name, team_id
            )
            SELECT
              agg.*,
              pmeta.player_age,
              pmeta.player_nationality,
              pmeta.position
            FROM agg
            LEFT JOIN pmeta USING (player_id)
            ORDER BY goals DESC, assists DESC, minutes_played DESC
            LIMIT 30
        """)

        with engine.connect() as conn:
            df = pd.read_sql(query, conn, params={"league": league, "season": season})
            if (
                not df.empty
                and league != "UEFA Champions League"
                and league not in FIXTURE_SCOPED_LEAGUES
            ):
                return _records(df)
            df_fb = pd.read_sql(fallback, conn, params={"league": league, "season": season, "ucl_stage": ucl_stage})
            return _records(df_fb)

    except Exception as e:
        return {"error": str(e)}
