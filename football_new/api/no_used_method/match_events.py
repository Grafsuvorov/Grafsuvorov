# api/match_events.py
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["События матчей"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine("postgresql+psycopg2://postgres:0506@localhost:5432/dwh")

@router.get("/match-events")
def match_events(fixture_id: int = Query(...)):
    try:
        q = """
        WITH base AS (
          SELECT
            e.fixture_id,
            e.team_id, e.team_name,
            e.player_id, e.player_name,
            e.assist_id, e.assist_name,
            e.type, e.detail, e.comments,
            e.elapsed, e.extra,
            -- человеко-минуты (без апострофа, чтобы избежать SQL-кавычек)
            CASE WHEN e.elapsed >= 90 AND COALESCE(e.extra,0) > 0
                 THEN e.elapsed::text || '+' || COALESCE(e.extra,0)::text
                 ELSE e.elapsed::text
            END AS minute_str
          FROM football.api_football_match_events e
          WHERE e.fixture_id = :fx
        ),
        with_side AS (
          -- определяем, чей гол: home/away (требуется расписание)
          SELECT
            b.*,
            s.home_team_id,
            s.away_team_id,
            CASE WHEN b.team_id = s.home_team_id THEN 'home'
                 WHEN b.team_id = s.away_team_id THEN 'away'
                 ELSE NULL END AS team_side
          FROM base b
          LEFT JOIN football.api_football_schedule s
            ON s.fixture_id = b.fixture_id
        ),
        normalized AS (
          -- нормализуем тип события -> kind (goal, own_goal, goal_cancelled, pen_missed, yellow, red, sub_in, sub_out, var, other)
          SELECT *,
            LOWER(COALESCE(type,''))  AS _t,
            LOWER(COALESCE(detail,'')) AS _d
          FROM with_side
        ),
        enriched AS (
          SELECT
            n.*,
            CASE
              WHEN _t LIKE '%goal%' AND _d NOT IN ('goal cancelled') AND _d NOT LIKE '%cancelled%' THEN
                   CASE WHEN _d = 'own goal' THEN 'own_goal' ELSE 'goal' END
              WHEN _d = 'goal cancelled' OR _d LIKE '%cancelled%' THEN 'goal_cancelled'
              WHEN _d IN ('penalty', 'penalty confirmed', 'penalty awarded') AND _t LIKE '%missed%' THEN 'pen_missed'
              WHEN _d = 'yellow card' THEN 'yellow'
              WHEN _d LIKE 'red card%' OR _d = 'red card' THEN 'red'
              WHEN _t LIKE 'subst%' OR _d LIKE 'substitution%' THEN 'sub'
              WHEN _d ILIKE '%var%' OR _d IN ('card reviewed','penalty cancelled','card upgrade') THEN 'var'
              ELSE 'other'
            END AS kind
          FROM normalized n
        ),
        scored AS (
          -- посчитаем счёт на каждой точке времени
          SELECT
            e.*,
            CASE
              WHEN kind='goal'     AND team_side='home' THEN 1
              WHEN kind='own_goal' AND team_side='home' THEN -1
              ELSE 0
            END AS delta_home,
            CASE
              WHEN kind='goal'     AND team_side='away' THEN 1
              WHEN kind='own_goal' AND team_side='away' THEN -1
              ELSE 0
            END AS delta_away
          FROM enriched e
        ),
        timeline AS (
          SELECT
            s.*,
            SUM(delta_home) OVER (ORDER BY elapsed, COALESCE(extra,0), player_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS home_goals,
            SUM(delta_away) OVER (ORDER BY elapsed, COALESCE(extra,0), player_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS away_goals
          FROM scored s
        )
        SELECT
          fixture_id, team_id, team_name, team_side,
          player_id, player_name, assist_id, assist_name,
          type, detail, comments,
          elapsed, extra, minute_str,
          kind,
          home_goals, away_goals,
          CASE
            WHEN home_goals IS NULL OR away_goals IS NULL THEN NULL
            ELSE home_goals::text || '-' || away_goals::text
          END AS score_after
        FROM timeline
        ORDER BY elapsed NULLS LAST, COALESCE(extra,0), player_id;
        """

        with engine.connect() as conn:
            df = pd.read_sql(text(q), conn, params={"fx": fixture_id})

        return df.to_dict(orient="records")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
