from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["Топ бомбардиры"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine("postgresql://postgres:0506@localhost:5432/dwh")


@router.get("/top-scorers")
def get_top_scorers(
    league: str = Query(...),
    season: int = Query(...)
):
    try:
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

        with engine.connect() as conn:
            df = pd.read_sql(query, conn, params={"league": league, "season": season})
            return df.to_dict(orient="records")

    except Exception as e:
        return {"error": str(e)}
