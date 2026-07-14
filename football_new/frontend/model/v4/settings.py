from __future__ import annotations

import os
from pathlib import Path

DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:0506@localhost:5432/dwh")

LEAGUES = (39, 61, 78, 135, 140)
LEAGUE_NAMES = {
    39: "Premier League",
    61: "Ligue 1",
    78: "Bundesliga",
    135: "Serie A",
    140: "La Liga",
}

OUTPUT_PATH = Path("tmp/outcome_v4_baseline.json")

DEFAULT_CAL_DAYS = 120
DEFAULT_VAL_DAYS = 30
DEFAULT_GAP_DAYS = 0

FALLBACK_HOME_GOALS = 1.45
FALLBACK_AWAY_GOALS = 1.15
MIN_MATCHES_FOR_TEAM_STATE = 3
