from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import create_engine, text
import pandas as pd
import numpy as np
import math

router = APIRouter(
    prefix="/api",
    tags=["Матчи"],
    responses={404: {"description": "Not found"}}
)
DB_URL = 'postgresql+psycopg2://postgres:0506@localhost:5432/dwh'
engine = create_engine(DB_URL)

def clean_record(record):
    """Заменяет NaN и бесконечные значения на 0 или None."""
    return {
        k: (
            0.0 if isinstance(v, float) and (math.isnan(v) or math.isinf(v))
            else v
        )
        for k, v in record.items()
    }

@router.get("/matches", 
    summary="Получить список матчей",
    description="Возвращает список матчей за указанный период с возможностью фильтрации по лиге"
)
def get_matches(
    from_date: str = Query(..., description="Начальная дата в формате YYYY-MM-DD"),
    to_date: str = Query(..., description="Конечная дата в формате YYYY-MM-DD"),
    league: str = Query(default=None, description="Название лиги для фильтрации")
):
    try:
        query = """
        SELECT 
            m.date, 
            m.league,
            m.home_team, 
            m.away_team, 
            m.score,
            m.result,
            m.home_tackles_tkl, m.away_tackles_tkl,
            m.home_interceptions, m.away_interceptions,
            m.home_clearances, m.away_clearances,
            m.home_total_cmp, m.away_total_cmp,
            m.home_total_att, m.away_total_att,
            m.home_total_cmpp, m.away_total_cmpp,
            m.home_possession, m.away_possession,
            m.home_touches, m.away_touches,
            m.home_goals, m.away_goals,
            m.home_shots, m.away_shots,
            m.home_shots_on_target, m.away_shots_on_target,
            m.home_expected_xg, m.away_expected_xg,

            -- outcome
            p_outcome.prediction_label AS outcome_label,
            p_outcome.prob_p1 AS outcome_p1,
            p_outcome.prob_x AS outcome_x,
            p_outcome.prob_p2 AS outcome_p2,

            -- total 2.5
            p_total.prediction_label AS total_label,
            p_total.prob_p1 AS total_u25,
            p_total.prob_p2 AS total_o25

        FROM football.stats_match_fbref_v2 m

        LEFT JOIN football.match_predictions p_outcome
          ON m.date = p_outcome.date 
         AND m.home_team = p_outcome.home_team 
         AND m.away_team = p_outcome.away_team 
         AND p_outcome.prediction_type = 'outcome'

        LEFT JOIN football.match_predictions p_total
          ON m.date = p_total.date 
         AND m.home_team = p_total.home_team 
         AND m.away_team = p_total.away_team 
         AND p_total.prediction_type = 'total25'

        WHERE m.date::date BETWEEN :from_date AND :to_date
        """ + ("""
        AND m.league = :league
        """ if league else "") + """
        ORDER BY m.date DESC
        """

        params = {"from_date": from_date, "to_date": to_date}
        if league:
            params["league"] = league

        with engine.connect() as conn:
            df = pd.read_sql(text(query), conn, params=params)

        df["date"] = pd.to_datetime(df["date"], errors="coerce").dt.strftime("%Y-%m-%d")

        # Обработка некорректных значений
        records = [clean_record(r) for r in df.to_dict(orient="records")]

        return records

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
