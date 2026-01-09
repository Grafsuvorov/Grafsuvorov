from fastapi import APIRouter, Query
from sqlalchemy import create_engine, text
import pandas as pd

router = APIRouter(
    prefix="/api",
    tags=["Турнирные таблицы"],
    responses={404: {"description": "Not found"}}
)
engine = create_engine("postgresql://postgres:0506@localhost:5432/dwh")

@router.get("/league-table",
    summary="Получить турнирную таблицу",
    description="Возвращает турнирную таблицу указанной лиги и сезона с возможностью просмотра общей, домашней или гостевой статистики"
)
def league_table(
    league: str = Query(..., description="Название лиги (Premier League, La Liga, Bundesliga, Serie A, Ligue 1)"),
    season: str = Query(..., description="Сезон в формате YYYY"),
    view: str = Query("total", description="Тип таблицы: total (общая), home (домашняя), away (гостевая)")
):
    query = text("""
        SELECT 
            s.team_name AS team,
            s.rank,
            s.points,
            s.goals_diff,
            s.form,
            s.status,
            s.description,
            s.all_played,
            s.all_win,
            s.all_draw,
            s.all_lose,
            s.all_goals_for,
            s.all_goals_against,
            s.home_played, s.home_win, s.home_draw, s.home_lose,
            s.home_goals_for, s.home_goals_against,
            s.away_played, s.away_win, s.away_draw, s.away_lose,
            s.away_goals_for, s.away_goals_against,
            s.team_id, s.league_id, s.season,
            l.league_name
        FROM football.api_football_standings s
        LEFT JOIN football.api_football_league l ON s.league_id = l.league_id
        WHERE s.season = :season AND l.league_name = :league
        ORDER BY s.rank ASC;
    """)

    with engine.connect() as conn:
        df = pd.read_sql(query, conn, params={"league": league, "season": season})

        if view == "home":
            df["games_played"] = df["home_played"]
            df["wins"] = df["home_win"]
            df["draws"] = df["home_draw"]
            df["losses"] = df["home_lose"]
            df["goals_for"] = df["home_goals_for"]
            df["goals_against"] = df["home_goals_against"]
        elif view == "away":
            df["games_played"] = df["away_played"]
            df["wins"] = df["away_win"]
            df["draws"] = df["away_draw"]
            df["losses"] = df["away_lose"]
            df["goals_for"] = df["away_goals_for"]
            df["goals_against"] = df["away_goals_against"]
        else:
            df["games_played"] = df["all_played"]
            df["wins"] = df["all_win"]
            df["draws"] = df["all_draw"]
            df["losses"] = df["all_lose"]
            df["goals_for"] = df["all_goals_for"]
            df["goals_against"] = df["all_goals_against"]

        df["goals_diff"] = df["goals_for"] - df["goals_against"]

        drop_cols = [col for col in df.columns if col.startswith("home_") or col.startswith("away_") or col.startswith("all_")]
        df = df.drop(columns=drop_cols)

        return df.to_dict(orient="records")