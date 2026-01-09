# api/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware import Middleware

# базовые роутеры (используемые фронтендом)
from api.league_table import router as league_table_router
from api.top_scorers import router as top_scorers_router
from api.match_stats_v3 import router as match_stats_v3_router
from api.test import router as test_router
from api.matchday_elo import router as matchday_elo_router
from api.players import router as players_router

# новые (используемые фронтендом)
from api.top_assists import router as top_assists_router
from api.top_rated_players import router as top_rated_players_router

# best-picks страница
from api.best_picks import router as best_picks_router
from api.match_insight import router as match_insight_router

# авторизация/статичка
from api.auth_dwh import router as auth_dwh_router
from api.static_router import router as static_router
from api.database import create_tables

# Подписки (наш роутер)
from api.no_used_method.team import router as team_router
from api.no_used_method.lineups_events import router as lineups_events_router

from api.subscriptions import router as subscriptions_router

# UCL
import api.ucl as ucl

# Новые роутеры с разными уровнями доступа (перенесены в no_used_method)

# Документация
from api.docs_config import custom_openapi

# Middleware
from api.middleware import RequestSourceCheckerMiddleware


middleware = [
    Middleware(
        CORSMiddleware,
        allow_origins=[
            "https://your-website.com",
            "https://www.your-website.com",
            "http://localhost:3000",  # Для разработки
            "http://localhost:3001"   # Для разработки
        ],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["*"],
    )
    # Middleware(RequestSourceCheckerMiddleware)  # Временно отключено
]

app = FastAPI(
    title="Football ML API",
    description="""
    ## Football ML API - Система анализа футбольных данных
    
    Комплексная API для анализа футбольных матчей, статистики игроков и команд, прогнозов и аналитики.
    
    ### Основные возможности:
    - 📊 **Статистика матчей** - детальная статистика игр, составы, события
    - 👥 **Анализ игроков** - рейтинги, статистика, карьера
    - 🏆 **Турнирные таблицы** - позиции команд в лигах
    - 🎯 **Прогнозы и аналитика** - ML-модели для предсказания исходов
    - 🔐 **Система подписок** - управление пользователями и планами
    - 🏟️ **UEFA Champions League** - специальная аналитика для ЛЧ
    
    ### Аутентификация:
    - Регистрация и вход через email
    - JWT токены для авторизации
    - Система верификации email
    
    ### Поддерживаемые лиги:
    - Premier League (Англия)
    - La Liga (Испания) 
    - Bundesliga (Германия)
    - Serie A (Италия)
    - Ligue 1 (Франция)
    - И другие европейские лиги
    """,
    version="1.0.0",
    contact={
        "name": "Football ML Team",
        "email": "support@footballml.com",
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
    middleware=middleware
)

# Подключаем кастомную OpenAPI схему (временно отключено)
# app.openapi = custom_openapi

# Базовая документация для локальной разработки

# регистрация роутеров с тегами для организации в Swagger

# 📊 МАТЧИ И СТАТИСТИКА (только используемые фронтендом)
app.include_router(match_stats_v3_router, tags=["Статистика матчей v3"])

# 🏆 ТУРНИРНЫЕ ТАБЛИЦЫ И ЛИГИ
app.include_router(league_table_router, tags=["Турнирные таблицы"])
app.include_router(matchday_elo_router, tags=["ELO рейтинги"])

# 👥 ИГРОКИ И КОМАНДЫ (только используемые фронтендом)
app.include_router(players_router, tags=["Игроки"])
app.include_router(top_scorers_router, tags=["Топ бомбардиры"])
app.include_router(top_assists_router, tags=["Топ ассистенты"])
app.include_router(top_rated_players_router, tags=["Топ игроки по рейтингу"])

# 🏟️ UEFA CHAMPIONS LEAGUE
app.include_router(ucl.router, tags=["UEFA Champions League"])

# 🎯 BEST PICKS И АНАЛИТИКА
app.include_router(best_picks_router, tags=["Лучшие ставки"])
app.include_router(match_insight_router, tags=["Аналитика матчей"])

# 🔐 АУТЕНТИФИКАЦИЯ И ПОЛЬЗОВАТЕЛИ
app.include_router(auth_dwh_router, tags=["Аутентификация"])

# 💳 ПОДПИСКИ И ПЛАТЕЖИ
app.include_router(subscriptions_router, prefix="/api", tags=["Подписки"])
app.include_router(team_router, tags=["Команды"])
app.include_router(lineups_events_router, tags=["Составы и события"])

# 🛠️ СЛУЖЕБНЫЕ
app.include_router(test_router, tags=["Тестирование"])
app.include_router(static_router, tags=["Статические страницы"])

# 🔐 НОВАЯ СИСТЕМА ДОСТУПА (перенесены в no_used_method)


@app.get("/_debug/routes")
def _debug_routes():
    # быстрый просмотр всех зарегистрированных путей
    out = []
    for r in app.routes:
        methods = sorted(list(getattr(r, "methods", []) or []))
        out.append({"path": r.path, "methods": methods, "name": getattr(r, "name", None)})
    return out


@app.get("/health")
def health():
    return {"ok": True}



@app.on_event("startup")
async def startup_event():
    create_tables()
    # печать всех путей при старте — удобно для отладки
    print("=== ROUTES START ===")
    for r in app.routes:
        methods = getattr(r, "methods", None)
        print(f"{methods} {r.path}")
    print("=== ROUTES END ===")
