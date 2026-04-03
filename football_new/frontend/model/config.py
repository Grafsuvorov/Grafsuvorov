# config.py
# Централизованная конфигурация проекта
# Совместимо с Python 3.9

import os

# =========================
# DATABASE
# =========================

DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:0506@localhost:5432/dwh")

# =========================
# LEAGUES
# =========================

# API-Football league_id
LEAGUES = [39, 61, 78, 135, 140]  # EPL, Ligue 1, Bundesliga, Serie A, La Liga

LEAGUE_ID_TO_UNDERSTAT = {
    39: "EPL",
    61: "Ligue_1",
    78: "Bundesliga",
    135: "Serie_A",
    140: "La_liga",
}

UNDERSTAT_MIN_SEASON = 2024

TOTALS_USE_SELECTED_UNDERSTAT = True
TOTALS_UNDERSTAT_MIN_SEASON = 2024
TOTALS_UNDERSTAT_SELECTED_FEATURES = [
    "home_us_xg_all_5",
    "away_us_xg_all_5",
    "home_us_xga_all_5",
    "away_us_xga_all_5",
    "home_us_npxg_all_5",
    "away_us_npxg_all_5",
    "home_us_npxga_all_5",
    "away_us_npxga_all_5",
    "home_us_npxg_all_3",
    "away_us_npxg_all_3",
    "home_us_npxga_all_3",
    "away_us_npxga_all_3",
    "home_us_goal_minus_npxg_all_3",
    "away_us_goal_minus_npxg_all_3",
    "home_us_goal_against_minus_npxga_all_3",
    "away_us_goal_against_minus_npxga_all_3",
    "home_us_goal_minus_npxg_home_5",
    "away_us_goal_minus_npxg_away_5",
    "home_us_goal_against_minus_npxga_home_5",
    "away_us_goal_against_minus_npxga_away_5",
    "home_us_goal_minus_npxg_std_all_5",
    "away_us_goal_minus_npxg_std_all_5",
    "home_us_goal_against_minus_npxga_std_all_5",
    "away_us_goal_against_minus_npxga_std_all_5",
    "usys_home_npxg_matchup_3",
    "usys_away_npxg_matchup_3",
    "usys_home_npxg_matchup_5",
    "usys_away_npxg_matchup_5",
    "usys_home_npxg_matchup_10",
    "usys_away_npxg_matchup_10",
    "usys_home_xg_matchup_5",
    "usys_away_xg_matchup_5",
    "usys_home_control_matchup_5",
    "usys_away_control_matchup_5",
    "usys_home_press_matchup_5",
    "usys_away_press_matchup_5",
    "usys_home_control_matchup_10",
    "usys_away_control_matchup_10",
    "usys_home_venue_strength_5",
    "usys_away_venue_strength_5",
    "usys_home_venue_strength_10",
    "usys_away_venue_strength_10",
    "usys_home_finish_edge_5",
    "usys_away_finish_edge_5",
    "usys_matchup_venue_edge_5",
    "usys_matchup_venue_edge_10",
    "usys_home_regression_noise_5",
    "usys_away_regression_noise_5",
    "usys_home_regression_edge_5",
    "usys_away_regression_edge_5",
]

TOTALS_USE_SELECTED_TEAM_POTENTIAL = True
TOTALS_TEAM_POTENTIAL_SELECTED_FEATURES = [
    "tp_attack_box_share_diff",
    "tp_attack_pressure_diff",
    "tp_attack_quality_diff",
    "tp_attack_trend_diff",
    "tp_attack_xg_diff",
    "tp_away_attack_box_pressure",
    "tp_away_attack_box_share",
    "tp_away_attack_control",
    "tp_away_attack_finish_edge",
    "tp_away_attack_pressure",
    "tp_away_attack_sog_share",
    "tp_away_attack_trend",
    "tp_away_attack_xg",
    "tp_away_attack_xg_per_deep",
    "tp_away_attack_xg_per_shot",
    "tp_away_defense_concede_edge",
    "tp_away_defense_pressure",
    "tp_away_defense_resistance",
    "tp_away_defense_trend",
    "tp_away_defense_xga",
    "tp_away_defense_xga_per_deep_allowed",
    "tp_away_matchup_attack_vs_defense",
    "tp_defense_concede_edge_diff",
    "tp_defense_resistance_diff",
    "tp_defense_trend_diff",
    "tp_defense_xga_diff",
    "tp_home_attack_box_pressure",
    "tp_home_attack_box_share",
    "tp_home_attack_control",
    "tp_home_attack_finish_edge",
    "tp_home_attack_pressure",
    "tp_home_attack_sog_share",
    "tp_home_attack_trend",
    "tp_home_attack_xg",
    "tp_home_attack_xg_per_deep",
    "tp_home_attack_xg_per_shot",
    "tp_home_defense_concede_edge",
    "tp_home_defense_pressure",
    "tp_home_defense_resistance",
    "tp_home_defense_trend",
    "tp_home_defense_xga",
    "tp_home_defense_xga_per_deep_allowed",
    "tp_home_matchup_attack_vs_defense",
    "tp_matchup_attack_diff",
]

OUTCOMES_USE_SELECTED_TEAM_POTENTIAL = True
OUTCOMES_TEAM_POTENTIAL_SELECTED_FEATURES = [
    "tp_attack_box_share_diff",
    "tp_attack_pressure_diff",
    "tp_attack_quality_diff",
    "tp_attack_trend_diff",
    "tp_attack_xg_diff",
    "tp_away_attack_box_pressure",
    "tp_away_attack_box_share",
    "tp_away_attack_control",
    "tp_away_attack_finish_edge",
    "tp_away_attack_pressure",
    "tp_away_attack_sog_share",
    "tp_away_attack_trend",
    "tp_away_attack_xg",
    "tp_away_attack_xg_per_deep",
    "tp_away_attack_xg_per_shot",
    "tp_away_balance_score",
    "tp_away_control_to_quality",
    "tp_away_defense_concede_edge",
    "tp_away_defense_pressure",
    "tp_away_defense_resistance",
    "tp_away_defense_trend",
    "tp_away_defense_xga",
    "tp_away_defense_xga_per_deep_allowed",
    "tp_away_matchup_attack_vs_defense",
    "tp_away_matchup_finish_vs_concede",
    "tp_away_matchup_pressure_vs_defense",
    "tp_away_matchup_quality_vs_defense",
    "tp_balance_score_diff",
    "tp_control_diff",
    "tp_defense_concede_edge_diff",
    "tp_defense_resistance_diff",
    "tp_defense_trend_diff",
    "tp_defense_xga_diff",
    "tp_finish_edge_diff",
    "tp_home_attack_box_pressure",
    "tp_home_attack_box_share",
    "tp_home_attack_control",
    "tp_home_attack_finish_edge",
    "tp_home_attack_pressure",
    "tp_home_attack_sog_share",
    "tp_home_attack_trend",
    "tp_home_attack_xg",
    "tp_home_attack_xg_per_deep",
    "tp_home_attack_xg_per_shot",
    "tp_home_balance_score",
    "tp_home_control_to_quality",
    "tp_home_defense_concede_edge",
    "tp_home_defense_pressure",
    "tp_home_defense_resistance",
    "tp_home_defense_trend",
    "tp_home_defense_xga",
    "tp_home_defense_xga_per_deep_allowed",
    "tp_home_matchup_attack_vs_defense",
    "tp_home_matchup_finish_vs_concede",
    "tp_home_matchup_pressure_vs_defense",
    "tp_home_matchup_quality_vs_defense",
    "tp_match_balance_abs",
    "tp_match_control_balance_abs",
    "tp_match_openness",
    "tp_match_quality_edge_abs",
    "tp_match_tempo_sum",
    "tp_matchup_attack_diff",
    "tp_matchup_finish_diff",
    "tp_matchup_pressure_diff",
    "tp_matchup_quality_diff",
]

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

TOTALS_EPL_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_over25_epl_model.pkl"
)

TOTALS_AUX_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_over25_aux_model.pkl"
)

OUTCOME_AUX_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_outcome_aux_model.pkl"
)

TOTALS_EPL_HEAD_MODEL_PATH = os.path.join(
    ARTIFACTS_DIR,
    "xgb_over25_epl_head.pkl"
)

ENABLE_TOTALS_EPL_HEAD = False
ENABLE_TOTALS_EPL_MODEL = False

# =========================
# DRAW / BET FILTERS
# =========================

DRAW_CAP_MAX = 0.62
DRAW_CAP_MIN = 0.06
DRAW_CLASS_WEIGHT = 1.60  # усиливаем вес ничьих при обучении 1X2

MIN_BET_ODDS = 1.40

ALLOWED_BET_TYPES_BY_LEAGUE = {
    39: {"1X2", "TOTAL"},
    61: {"1X2", "TOTAL"},
    78: {"1X2", "TOTAL"},
    135: {"1X2", "TOTAL"},
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

# Temporarily disabled leagues for totals ROI gating
DISABLED_LEAGUES = {61, 39}

# =========================
# MODEL TUNING
# =========================

OUTCOME_XGB_PARAMS_BY_LEAGUE = {
    39: {"max_depth": 7, "eta": 0.03, "min_child_weight": 12.0},
    61: {"max_depth": 5, "eta": 0.04, "min_child_weight": 8.0},
    78: {"max_depth": 4, "eta": 0.06, "min_child_weight": 6.0},
    135: {"max_depth": 5, "eta": 0.04, "min_child_weight": 8.0},
    140: {"max_depth": 8, "eta": 0.025, "min_child_weight": 14.0},
}

# =========================
# DEBUG / MODES
# =========================

DEBUG = False
