from __future__ import annotations

import os
from pathlib import Path


DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:0506@localhost:5432/dwh")

LEAGUES = (39, 61, 78, 135, 140)

SNAPSHOT_OUTPUT = Path("tmp/v5_snapshot.csv")
RESEARCH_OUTPUT = Path("tmp/outcome_v5_0_baseline.json")

DEFAULT_MODE = "pre_lineup"
DEFAULT_PREDICTION_HOURS = 24

TRAIN_DAYS = 540
CAL_DAYS = 120
VAL_DAYS = 30
STEP_DAYS = 30
