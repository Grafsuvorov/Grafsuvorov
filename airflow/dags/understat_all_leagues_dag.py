from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Sequence

from airflow import DAG
from airflow.operators.python import PythonOperator


SCRIPTS_DIR = Path(os.getenv("UNDERSTAT_SCRIPTS_DIR", "/opt/airflow/scripts"))
DEFAULT_PYTHON = sys.executable
DEFAULT_SCHEDULE = os.getenv("UNDERSTAT_ALL_LEAGUES_SCHEDULE", "0 1 * * *")
DEFAULT_SLEEP_MS = os.getenv("UNDERSTAT_SLEEP_MS", "120")
ONLY_NEW_MATCHES = os.getenv("UNDERSTAT_ONLY_NEW_MATCHES", "1").lower() not in {"0", "false", "no"}
DEFAULT_PSQL = os.getenv("UNDERSTAT_PSQL_BIN", "/usr/bin/psql")
LEAGUES: Sequence[str] = ("EPL", "La_liga", "Bundesliga", "Serie_A", "Ligue_1")


def resolve_season() -> int:
    season_override = os.getenv("UNDERSTAT_SEASON")
    if season_override:
        return int(season_override)

    now = datetime.utcnow()
    return now.year if now.month >= 7 else now.year - 1


def run_script(script_name: str, league: str) -> None:
    python_bin = os.getenv("UNDERSTAT_PYTHON_BIN", DEFAULT_PYTHON)
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"

    cmd = [
        python_bin,
        str(SCRIPTS_DIR / script_name),
        "--league",
        league,
        "--season",
        str(resolve_season()),
        "--psql",
        DEFAULT_PSQL,
    ]

    if script_name == "understat_ingest.py":
        cmd.extend(["--sleep-ms", DEFAULT_SLEEP_MS])
        if ONLY_NEW_MATCHES:
            cmd.append("--only-new")

    print(f"[INFO] running {' '.join(cmd)}")
    subprocess.run(cmd, cwd=str(SCRIPTS_DIR), env=env, check=True)


default_args = {
    "owner": "codex",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=10),
}


with DAG(
    dag_id="understat_all_leagues_ingest",
    description="Full Understat ingest for all supported leagues and all Understat tables.",
    default_args=default_args,
    start_date=datetime(2026, 3, 13),
    schedule_interval=DEFAULT_SCHEDULE,
    catchup=False,
    max_active_runs=1,
    tags=["understat", "ingest", "all-leagues"],
) as dag:
    previous_task = None

    for league_code in LEAGUES:
        extras_task = PythonOperator(
            task_id=f"understat_extras_{league_code.lower()}",
            python_callable=run_script,
            op_kwargs={
                "script_name": "understat_extras_ingest.py",
                "league": league_code,
            },
        )

        matches_task = PythonOperator(
            task_id=f"understat_matches_{league_code.lower()}",
            python_callable=run_script,
            op_kwargs={
                "script_name": "understat_ingest.py",
                "league": league_code,
            },
        )

        extras_task >> matches_task
        if previous_task is not None:
            previous_task >> extras_task
        previous_task = matches_task
