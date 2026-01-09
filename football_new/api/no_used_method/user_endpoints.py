# api/user_endpoints.py
from fastapi import APIRouter, Depends, Query
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
import pandas as pd
import math

from api.database import get_db
from api.core.api_auth import require_user_auth, require_website_access
from api.models import User

router = APIRouter(
    prefix="/user",
    tags=["Пользовательские данные"],
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
    summary="Матчи для пользователей",
    description="Расширенная информация о матчах для авторизованных пользователей"
)
def get_user_matches(
    from_date: str = Query(..., description="Начальная дата в формате YYYY-MM-DD"),
    to_date: str = Query(..., description="Конечная дата в формате YYYY-MM-DD"),
    league: str = Query(default=None, description="Название лиги для фильтрации"),
    current_user: User = Depends(require_user_auth),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить расширенную информацию о матчах (для авторизованных пользователей)"""
    try:
        query = """
        SELECT 
            m.date, 
            m.league,
            m.home_team,
            m.away_team,
            m.home_score,
            m.away_score,
            m.status,
            m.venue,
            m.referee,
            m.weather,
            m.temperature
        FROM football.api_football_matches m
        WHERE m.date BETWEEN :from_date AND :to_date
        """
        
        params = {"from_date": from_date, "to_date": to_date}
        
        if league:
            query += " AND m.league = :league"
            params["league"] = league
        
        query += " ORDER BY m.date DESC LIMIT 200"
        
        df = pd.read_sql(query, engine, params=params)
        matches = [clean_record(row) for _, row in df.iterrows()]
        
        return {
            "matches": matches,
            "total": len(matches),
            "user": current_user.username,
            "access_level": "user_authenticated"
        }
    except Exception as e:
        return {"error": str(e), "matches": []}

@router.get("/player-stats",
    summary="Статистика игроков",
    description="Детальная статистика игроков для авторизованных пользователей"
)
def get_user_player_stats(
    player_id: int = Query(..., description="ID игрока"),
    season: str = Query(..., description="Сезон"),
    current_user: User = Depends(require_user_auth),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить детальную статистику игрока (для авторизованных пользователей)"""
    try:
        query = text("""
            SELECT 
                p.player_name,
                p.team_name,
                p.position,
                p.age,
                p.height,
                p.weight,
                p.nationality,
                s.goals,
                s.assists,
                s.appearances,
                s.minutes,
                s.yellow_cards,
                s.red_cards,
                s.rating
            FROM football.api_football_players p
            LEFT JOIN football.api_football_player_stats s 
                ON p.player_id = s.player_id AND s.season = :season
            WHERE p.player_id = :player_id
        """)
        
        with engine.begin() as con:
            result = con.execute(query, {"player_id": player_id, "season": season})
            player_data = dict(result.mappings().first()) if result.mappings().first() else {}
        
        return {
            "player": player_data,
            "user": current_user.username,
            "access_level": "user_authenticated"
        }
    except Exception as e:
        return {"error": str(e), "player": {}}

@router.get("/team-analysis",
    summary="Анализ команды",
    description="Аналитические данные о команде для авторизованных пользователей"
)
def get_user_team_analysis(
    team_id: int = Query(..., description="ID команды"),
    season: str = Query(..., description="Сезон"),
    current_user: User = Depends(require_user_auth),
    # _: None = Depends(require_website_access)  # Временно отключено
):
    """Получить аналитические данные о команде (для авторизованных пользователей)"""
    try:
        query = text("""
            SELECT 
                t.team_name,
                t.venue,
                t.capacity,
                t.founded,
                s.points,
                s.rank,
                s.wins,
                s.draws,
                s.losses,
                s.goals_for,
                s.goals_against,
                s.goals_diff,
                s.form
            FROM football.api_football_teams t
            LEFT JOIN football.api_football_standings s 
                ON t.team_id = s.team_id AND s.season = :season
            WHERE t.team_id = :team_id
        """)
        
        with engine.begin() as con:
            result = con.execute(query, {"team_id": team_id, "season": season})
            team_data = dict(result.mappings().first()) if result.mappings().first() else {}
        
        return {
            "team": team_data,
            "user": current_user.username,
            "access_level": "user_authenticated"
        }
    except Exception as e:
        return {"error": str(e), "team": {}}
