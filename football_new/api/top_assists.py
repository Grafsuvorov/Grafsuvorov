# api/top_assists.py
from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["Топ ассистенты"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine("postgresql://postgres:0506@localhost:5432/dwh")

@router.get("/top-assists")
def get_top_assists(
    league: str = Query(...),
    season: int = Query(...)
):
    try:
        q = text("""
            SELECT
                player_id,
                player_name,
                player_age,
                player_nationality,
                team_name,
                team_id,
                appearances,
                lineups,
                minutes_played,
                position,
                rating,
                goals_assists   AS assists,
                passes_key       AS key_passes
            FROM football.api_football_topassists_min
            WHERE league_name = :league
              AND season      = :season
            ORDER BY
              goals_assists DESC NULLS LAST,
              passes_key    DESC NULLS LAST,
              rating        DESC NULLS LAST,
              minutes_played DESC NULLS LAST
            LIMIT 30
        """)

        with engine.connect() as conn:
            df = pd.read_sql(q, conn, params={"league": league, "season": season})
        return df.to_dict(orient="records")

    except Exception as e:
        return {"error": str(e)}
