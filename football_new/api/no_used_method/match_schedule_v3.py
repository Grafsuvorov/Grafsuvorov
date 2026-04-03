# api/no_used_method/match_schedule_v3.py
from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
import pandas as pd
import math
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn")
router = APIRouter(
    prefix="/api",
    tags=["Расписание матчей v3 (не используется)"],
    responses={404: {"description": "Not found"}}
)
DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
engine = create_engine(DB_URL)


def _sanitize(records):
    out = []
    for r in records:
        for k, v in list(r.items()):
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                r[k] = None
        out.append(r)
    return out


# =========================
# API — upcoming (calendar)
# =========================
@router.get("/match-schedule-v3")
def match_schedule_v3(
    league: str = Query(..., description="Premier League | La Liga | Bundesliga | Serie A | Ligue 1"),
    season: str = Query(..., description="Год сезона, напр. 2025"),
):
    """
    Только НЕсыгранные матчи лиги/сезона.
    Если в ml_predictions уже есть прогноз — вернём его и рынок.
    Поле week — это номер тура (из 'Regular Season - N').
    Поле datetime — строка 'DD.MM HH:MM' (для удобства фронта).
    """
    try:
        q = """
        WITH upcoming AS (
            SELECT
                s.fixture_id,
                s.date,
                s.league_name AS league,
                s.season::text AS season,
                s.home_team, s.away_team,
                s.home_team_id, s.away_team_id,
                s.round AS round_label,
                NULLIF(REGEXP_REPLACE(COALESCE(s.round,''), '^.*- *', ''), '')::int AS week
            FROM football.api_football_schedule s
            WHERE s.league_name = :league
              AND s.season::text = :season
              AND (s.score_fulltime_home IS NULL AND s.score_fulltime_away IS NULL)
              AND COALESCE(s.status,'') NOT IN ('Match Finished','FT','FT_PEN','AET','PEN','AWARDED','Awarded','Abandoned','Canceled')
        )
        SELECT
            u.fixture_id,
            u.league,
            u.season,
            u.home_team, u.away_team,
            u.home_team_id, u.away_team_id,
            u.week,
            u.round_label,
            to_char(u.date AT TIME ZONE 'UTC', 'DD.MM HH24:MI') AS datetime,

            -- прогноз/рынок (если есть)
            p.p_home, p.p_draw, p.p_away, p.p_over25, p.p_under25,
            p.n_bookmakers,
            p.avg_odds_home, p.avg_odds_draw, p.avg_odds_away,
            p.avg_odds_over25, p.avg_odds_under25,
            p.decision_1x2   AS rec_decision,
            p.bet_rating     AS bet_rating,
            p.bet_reason     AS rec_reason,
            p.best_bet_type  AS signal_market,
            p.best_bet_outcome AS signal_pick,
            p.best_bet_odds  AS signal_odds,
            p.best_bet_ev    AS signal_value,
            p.best_bet_edge  AS signal_edge
        FROM upcoming u
        LEFT JOIN football.ml_predictions p USING (fixture_id)
        ORDER BY u.date ASC, u.home_team, u.away_team;
        """

        with engine.connect() as conn:
            df = pd.read_sql(text(q), conn, params={"league": league, "season": season})

        return _sanitize(df.to_dict(orient="records"))

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
