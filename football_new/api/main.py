# api/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware import Middleware

# базовые роутеры (используемые фронтендом)
from api.league_table import router as league_table_router
from api.top_scorers import router as top_scorers_router
from api.match_stats_v3 import router as match_stats_v3_router
from api.matchday_elo import router as matchday_elo_router
from api.roi_admin import router as roi_admin_router
from api.players import router as players_router
from api.insights import router as insights_router
from api.search import router as search_router
from api.league_analytics import router as league_analytics_router
from api.audit import router as audit_router
from api.image_proxy import router as image_proxy_router

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

# Команды / составы / события
from api.team import router as team_router
from api.lineups_events import router as lineups_events_router
from api.match_events import router as match_events_router

from api.subscriptions import router as subscriptions_router
from api.favorites import router as favorites_router

# UCL
import api.ucl as ucl
from api.cups import router as cups_router

# Новые роутеры с разными уровнями доступа (перенесены в no_used_method)

from api.core.config import settings

# Middleware
from api.middleware import ActivityLoggerMiddleware


middleware = [
    Middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ALLOW_ORIGINS,
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
        "name": "EdgeScore",
        "email": "support@edgescore.pro",
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
    middleware=middleware
)
app.add_middleware(ActivityLoggerMiddleware)

# safety net: /api/match-events should never 404
@app.middleware("http")
async def _match_events_fallback(request: Request, call_next):
    if request.url.path == "/api/match-events":
        return JSONResponse([])
    return await call_next(request)

# регистрация роутеров с тегами для организации в Swagger

# 📊 МАТЧИ И СТАТИСТИКА (только используемые фронтендом)
app.include_router(match_stats_v3_router, tags=["Статистика матчей v3"])

# 🏆 ТУРНИРНЫЕ ТАБЛИЦЫ И ЛИГИ
app.include_router(league_table_router, tags=["Турнирные таблицы"])
app.include_router(matchday_elo_router, tags=["ELO рейтинги"])
app.include_router(roi_admin_router, tags=["ROI admin"])

# 👥 ИГРОКИ И КОМАНДЫ (только используемые фронтендом)
app.include_router(players_router, tags=["Игроки"])
app.include_router(insights_router, tags=["Insights"])
app.include_router(search_router, tags=["Search"])
app.include_router(league_analytics_router, tags=["League Analytics"])
app.include_router(audit_router, tags=["Audit"])
app.include_router(image_proxy_router, tags=["Image Proxy"])
app.include_router(top_scorers_router, tags=["Топ бомбардиры"])
app.include_router(top_assists_router, tags=["Топ ассистенты"])
app.include_router(top_rated_players_router, tags=["Топ игроки по рейтингу"])

# 🏟️ UEFA CHAMPIONS LEAGUE
app.include_router(ucl.router, tags=["UEFA Champions League"])
app.include_router(cups_router, tags=["International Cups"])

# 🎯 BEST PICKS И АНАЛИТИКА
app.include_router(best_picks_router, tags=["Лучшие ставки"])
app.include_router(match_insight_router, tags=["Аналитика матчей"])

# 🔐 АУТЕНТИФИКАЦИЯ И ПОЛЬЗОВАТЕЛИ
app.include_router(auth_dwh_router, tags=["Аутентификация"])

# 💳 ПОДПИСКИ И ПЛАТЕЖИ
app.include_router(subscriptions_router, prefix="/api", tags=["Подписки"])
app.include_router(favorites_router, tags=["Избранное"])
app.include_router(team_router, tags=["Команды"])
app.include_router(lineups_events_router, tags=["Составы и события"])
app.include_router(match_events_router, tags=["События матчей"])

# 🛠️ СЛУЖЕБНЫЕ
app.include_router(static_router, tags=["Статические страницы"])
if settings.ENABLE_TEST_ROUTES:
    from api.test import router as test_router
    app.include_router(test_router, tags=["Тестирование"])

# 🔐 НОВАЯ СИСТЕМА ДОСТУПА (перенесены в no_used_method)


if settings.ENABLE_DEBUG_ROUTES:
    @app.get("/_debug/routes")
    def _debug_routes():
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
    if settings.LOG_ROUTES_ON_STARTUP:
        print("=== ROUTES START ===")
        for r in app.routes:
            methods = getattr(r, "methods", None)
            print(f"{methods} {r.path}")
        print("=== ROUTES END ===")
