# config.py
# Централизованная конфигурация проекта
# Совместимо с Python 3.9

import os

# =========================
# DATABASE
# =========================

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"

# =========================
# LEAGUES
# =========================

# API-Football league_id
LEAGUES = [39, 61, 78, 135, 140]  # EPL, Ligue 1, Bundesliga, Serie A, La Liga

# =========================
# RANDOM / REPRODUCIBILITY
# =========================

RANDOM_SEED = 42

# =========================
# SPLITS (TIME-AWARE)
# =========================

CAL_DAYS = 90
VAL_DAYS = 14
GAP_DAYS = 0

# =========================
# ANTI-LEAK RULES
# =========================

# Разрешённые суффиксы агрегатов
SAFE_SUFFIXES = ("_mean", "_std", "_ema", "_sum", "_slope")

# Маркет-фичи (НИКОГДА не таргеты)
MARKET_TOKENS = (
    "odds",
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "overround",
    "n_bookmakers",
    "p_over_mkt",
)

# =========================
# ELO
# =========================

ELO_INIT = 1500
ELO_HOME_ADV = 60

# =========================
# FORM / ROLLING
# =========================

ROLL_N = 5
ROLL_SHORT = 3

# =========================
# POISSON
# =========================

POISSON_MAX = 10
POISSON_MIN_LAMBDA = 0.05
POISSON_MAX_LAMBDA = 4.0

# =========================
# ARTIFACTS / MODELS
# =========================

# Базовая папка для всех моделей
ARTIFACTS_DIR = os.path.join(os.path.dirname(__file__), "models")

# Создаём папку автоматически
os.makedirs(ARTIFACTS_DIR, exist_ok=True)

# Пути моделей
OUTCOME_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_outcome_model.pkl"
)

TOTALS_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_over25_model.pkl"
)

# =========================
# DRAW / BET FILTERS
# =========================

DRAW_CAP_MAX = 0.62
DRAW_CAP_MIN = 0.03
DRAW_CLASS_WEIGHT = 1.35  # усиливаем вес ничьих при обучении 1X2

MIN_BET_ODDS = 1.40

ALLOWED_BET_TYPES_BY_LEAGUE = {
    39: {"1X2", "TOTAL"},
    61: {"TOTAL"},
    78: {"TOTAL"},
    135: {"TOTAL"},
    140: {"1X2", "TOTAL"},
}

MIN_EV_BY_TYPE = {
    "1X2": 0.05,
    "TOTAL": 0.02,
}

MIN_EV_BY_LEAGUE_BET = {
    39: {"1X2": 0.12},
    78: {"TOTAL": 0.10},
    135: {"TOTAL": 0.10},
    140: {"1X2": 0.12, "TOTAL": 0.08},
}

# Порог для аналитики ROI (только высокое EV)
HIGH_EV_REPORT_THRESHOLD = 0.08

# =========================
# DEBUG / MODES
# =========================

DEBUG = False
