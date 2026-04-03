from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

router = APIRouter(
    prefix="/api",
    tags=["Расписание матчей"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine("postgresql://postgres:0506@localhost:5432/dwh")

@router.get("/match-schedule")
def get_match_schedule(league: str = Query(...), season: str = Query(...)):
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT week, day, date::date AS match_date, time, home_team, away_team
                FROM football.match_stats_fbref
                WHERE league = :league
                  AND season = :season
                  AND (home_xg IS NULL OR away_xg IS NULL)
                ORDER BY week, date, time
            """), {"league": league, "season": season}).mappings().all()

        matches = [
            {
                "week": row["week"],
                "day": row["day"],
                "datetime": f"{row['match_date'].strftime('%d.%m.')} {row['time']}",
                "home_team": row["home_team"],
                "away_team": row["away_team"]
            }
            for row in result
        ]

        return matches

    except SQLAlchemyError as e:
        return {"error": str(e)}
