# api/public_endpoints.py
from fastapi import APIRouter, Depends, Query
from sqlalchemy import create_engine, text
import pandas as pd
import math

from api.core.api_auth import require_website_access

router = APIRouter(
    prefix="/public",
    tags=["Публичные данные"],
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
    summary="Публичные матчи",
    description="Список матчей доступный всем пользователям сайта"
)
def get_public_matches(
    from_date: str = Query(..., description="Начальная дата в формате YYYY-MM-DD"),
    to_date: str = Query(..., description="Конечная дата в формате YYYY-MM-DD"),
    league: str = Query(default=None, description="Название лиги для фильтрации"),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить список матчей (только через сайт)"""
    try:
        query = """
        SELECT 
            m.date, 
            m.league,
            m.home_team,
            m.away_team,
            m.home_score,
            m.away_score,
            m.status
        FROM football.api_football_matches m
        WHERE m.date BETWEEN :from_date AND :to_date
        """
        
        params = {"from_date": from_date, "to_date": to_date}
        
        if league:
            query += " AND m.league = :league"
            params["league"] = league
        
        query += " ORDER BY m.date DESC LIMIT 100"
        
        df = pd.read_sql(query, engine, params=params)
        matches = [clean_record(row) for _, row in df.iterrows()]
        
        return {
            "matches": matches,
            "total": len(matches),
            "access_level": "public"
        }
    except Exception as e:
        return {"error": str(e), "matches": []}

@router.get("/league-table",
    summary="Публичная турнирная таблица",
    description="Турнирная таблица доступная всем пользователям сайта"
)
def get_public_league_table(
    league: str = Query(..., description="Название лиги"),
    season: str = Query(..., description="Сезон в формате YYYY"),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить турнирную таблицу (только через сайт)"""
    try:
        query = text("""
            SELECT 
                s.team_name AS team,
                s.rank,
                s.points,
                s.goals_diff,
                s.form
            FROM football.api_football_standings s
            WHERE s.league = :league AND s.season = :season
            ORDER BY s.rank
        """)
        
        with engine.begin() as con:
            result = con.execute(query, {"league": league, "season": season})
            teams = [dict(row) for row in result.mappings()]
        
        return {
            "league": league,
            "season": season,
            "teams": teams,
            "access_level": "public"
        }
    except Exception as e:
        return {"error": str(e), "teams": []}

@router.get("/top-scorers",
    summary="Публичные топ бомбардиры",
    description="Топ бомбардиры доступные всем пользователям сайта"
)
def get_public_top_scorers(
    league: str = Query(..., description="Название лиги"),
    season: int = Query(..., description="Сезон"),
    limit: int = Query(10, description="Количество игроков"),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить топ бомбардиров (только через сайт)"""
    try:
        query = text("""
            SELECT 
                p.player_name,
                p.team_name,
                p.goals,
                p.assists,
                p.appearances
            FROM football.api_football_top_scorers p
            WHERE p.league = :league AND p.season = :season
            ORDER BY p.goals DESC, p.assists DESC
            LIMIT :limit
        """)
        
        with engine.begin() as con:
            result = con.execute(query, {"league": league, "season": season, "limit": limit})
            players = [dict(row) for row in result.mappings()]
        
        return {
            "league": league,
            "season": season,
            "players": players,
            "access_level": "public"
        }
    except Exception as e:
        return {"error": str(e), "players": []}
