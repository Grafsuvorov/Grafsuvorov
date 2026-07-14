from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator


MODEL_DIR = Path(os.getenv("PORTFOLIO_MODEL_DIR", "/opt/airflow/model"))
DEFAULT_PYTHON = os.getenv("PORTFOLIO_PYTHON_BIN", sys.executable)
DEFAULT_SCHEDULE = os.getenv("PORTFOLIO_REFRESH_SCHEDULE", "20 3 * * *")
DEFAULT_DB_URL = os.getenv("PORTFOLIO_DB_URL", "postgresql+psycopg2://postgres:0506@edgescore-db-shared:5432/dwh")


def run_portfolio_refresh() -> None:
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    env["PYTHONPATH"] = str(MODEL_DIR)
    env["DB_URL"] = DEFAULT_DB_URL

    cmd = [
        DEFAULT_PYTHON,
        str(MODEL_DIR / "rebuild_portfolio_signals.py"),
    ]

    print(f"[INFO] running {' '.join(cmd)}")
    subprocess.run(cmd, cwd=str(MODEL_DIR), env=env, check=True)


default_args = {
    "owner": "codex",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=10),
}


with DAG(
    dag_id="portfolio_signals_refresh",
    description="Daily rebuild of v6 outcome predictor + totals portfolio into football.ml_predictions.",
    default_args=default_args,
    start_date=datetime(2026, 5, 17),
    schedule_interval=DEFAULT_SCHEDULE,
    catchup=False,
    max_active_runs=1,
    tags=["portfolio", "predictions", "daily"],
) as dag:
    PythonOperator(
        task_id="rebuild_v6_portfolio_signals",
        python_callable=run_portfolio_refresh,
    )
