# api/api_endpoints.py
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
import pandas as pd
import math
import time

from api.database import get_db
from api.core.api_auth import (
    require_api_access, 
    require_premium_api, 
    require_business_api,
    log_api_usage
)
from api.models import APIClient

router = APIRouter(
    prefix="/api",
    tags=["API данные"],
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
    summary="API матчи",
    description="Данные о матчах через API (требует API ключ)"
)
def get_api_matches(
    request: Request,
    from_date: str = Query(..., description="Начальная дата в формате YYYY-MM-DD"),
    to_date: str = Query(..., description="Конечная дата в формате YYYY-MM-DD"),
    league: str = Query(default=None, description="Название лиги для фильтрации"),
    include_stats: bool = Query(False, description="Включить детальную статистику"),
    api_client: APIClient = Depends(require_api_access),
    db: Session = Depends(get_db)
):
    """Получить данные о матчах через API"""
    start_time = time.time()
    
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
            m.referee
        """
        
        if include_stats and api_client.role in ["premium", "business", "admin"]:
            query += """,
            m.weather,
            m.temperature,
            m.attendance,
            m.periods
            """
        
        query += """
        FROM football.api_football_matches m
        WHERE m.date BETWEEN :from_date AND :to_date
        """
        
        params = {"from_date": from_date, "to_date": to_date}
        
        if league:
            query += " AND m.league = :league"
            params["league"] = league
        
        query += " ORDER BY m.date DESC LIMIT 500"
        
        df = pd.read_sql(query, engine, params=params)
        matches = [clean_record(row) for _, row in df.iterrows()]
        
        response_time = int((time.time() - start_time) * 1000)
        
        # Логируем использование
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/matches",
            method="GET",
            status_code=200,
            response_time_ms=response_time,
            db=db
        )
        
        return {
            "matches": matches,
            "total": len(matches),
            "client": api_client.name,
            "quota_used": api_client.used_current_month,
            "quota_limit": api_client.quota_monthly,
            "access_level": "api"
        }
    except Exception as e:
        response_time = int((time.time() - start_time) * 1000)
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/matches",
            method="GET",
            status_code=500,
            response_time_ms=response_time,
            db=db
        )
        return {"error": str(e), "matches": []}

@router.get("/premium/advanced-stats",
    summary="Премиум статистика",
    description="Расширенная статистика (требует премиум API)"
)
def get_premium_stats(
    request: Request,
    team_id: int = Query(..., description="ID команды"),
    season: str = Query(..., description="Сезон"),
    api_client: APIClient = Depends(require_premium_api),
    db: Session = Depends(get_db)
):
    """Получить расширенную статистику (премиум API)"""
    start_time = time.time()
    
    try:
        query = text("""
            SELECT 
                t.team_name,
                s.points,
                s.rank,
                s.wins,
                s.draws,
                s.losses,
                s.goals_for,
                s.goals_against,
                s.goals_diff,
                s.form,
                s.home_wins,
                s.home_draws,
                s.home_losses,
                s.away_wins,
                s.away_draws,
                s.away_losses,
                s.clean_sheets,
                s.failed_to_score
            FROM football.api_football_teams t
            LEFT JOIN football.api_football_standings s 
                ON t.team_id = s.team_id AND s.season = :season
            WHERE t.team_id = :team_id
        """)
        
        with engine.begin() as con:
            result = con.execute(query, {"team_id": team_id, "season": season})
            team_data = dict(result.mappings().first()) if result.mappings().first() else {}
        
        response_time = int((time.time() - start_time) * 1000)
        
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/premium/advanced-stats",
            method="GET",
            status_code=200,
            response_time_ms=response_time,
            db=db
        )
        
        return {
            "team": team_data,
            "client": api_client.name,
            "access_level": "premium_api"
        }
    except Exception as e:
        response_time = int((time.time() - start_time) * 1000)
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/premium/advanced-stats",
            method="GET",
            status_code=500,
            response_time_ms=response_time,
            db=db
        )
        return {"error": str(e), "team": {}}

@router.get("/business/raw-data",
    summary="Бизнес сырые данные",
    description="Сырые данные для бизнес-клиентов (требует бизнес API)"
)
def get_business_raw_data(
    request: Request,
    table_name: str = Query(..., description="Название таблицы"),
    limit: int = Query(1000, description="Количество записей"),
    api_client: APIClient = Depends(require_business_api),
    db: Session = Depends(get_db)
):
    """Получить сырые данные (бизнес API)"""
    start_time = time.time()
    
    try:
        # Проверяем, что таблица разрешена для бизнес-клиентов
        allowed_tables = [
            "api_football_matches",
            "api_football_players", 
            "api_football_teams",
            "api_football_standings"
        ]
        
        if table_name not in allowed_tables:
            raise ValueError(f"Table {table_name} not allowed for business access")
        
        query = f"SELECT * FROM football.{table_name} LIMIT :limit"
        
        with engine.begin() as con:
            result = con.execute(text(query), {"limit": limit})
            data = [dict(row) for row in result.mappings()]
        
        response_time = int((time.time() - start_time) * 1000)
        
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/business/raw-data",
            method="GET",
            status_code=200,
            response_time_ms=response_time,
            db=db
        )
        
        return {
            "table": table_name,
            "data": data,
            "count": len(data),
            "client": api_client.name,
            "access_level": "business_api"
        }
    except Exception as e:
        response_time = int((time.time() - start_time) * 1000)
        log_api_usage(
            api_client=api_client,
            request=request,
            endpoint="/api/business/raw-data",
            method="GET",
            status_code=500,
            response_time_ms=response_time,
            db=db
        )
        return {"error": str(e), "data": []}
