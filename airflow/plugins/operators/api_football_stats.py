from __future__ import annotations

import json
import os
import socket
import time
from typing import Iterable, List, Dict, Any, Optional

import requests
import pandas as pd
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from airflow.hooks.base import BaseHook
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

# -------- utils --------
def _chunked(iterable: Iterable, size: int):
    batch = []
    for x in iterable:
        batch.append(x)
        if len(batch) == size:
            yield batch
            batch = []
    if batch:
        yield batch

def _create_engine_from_conn_id(conn_id: str) -> Engine:
    conn = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{conn.login}:{conn.password}@{conn.host}:{conn.port}/{conn.schema}"
    return create_engine(uri, pool_pre_ping=True)

# -------- logging to football.etl_task_logs --------
def _log_start(engine: Engine, dag_id: str, task_id: str, run_id: Optional[str], try_number: int,
               target_table: Optional[str], operation: Optional[str], extra: Optional[dict] = None) -> int:
    with engine.begin() as conn:
        res = conn.execute(
            text("""
              INSERT INTO football.etl_task_logs
                (dag_id, task_id, run_id, try_number, status,
                 target_table, operation, host, container_id, extra)
              VALUES
                (:dag_id, :task_id, :run_id, :try_number, 'running',
                 :target_table, :operation, :host, :container_id, :extra)
              RETURNING id
            """),
            dict(
                dag_id=dag_id, task_id=task_id, run_id=run_id, try_number=try_number,
                target_table=target_table, operation=operation,
                host=socket.gethostname(), container_id=os.environ.get("HOSTNAME"),
                extra=json.dumps(extra) if extra else None
            )
        )
        return int(res.scalar_one())

def _log_finish(engine: Engine, log_id: int, status: str = "success",
                rows_read: Optional[int] = None, rows_inserted: Optional[int] = None,
                rows_updated: Optional[int] = None, rows_deleted: Optional[int] = None,
                rows_unchanged: Optional[int] = None,
                error_type: Optional[str] = None, error_message: Optional[str] = None,
                extra: Optional[dict] = None) -> None:
    with engine.begin() as conn:
        conn.execute(
            text("""
              UPDATE football.etl_task_logs
              SET ended_at       = now(),
                  status         = :status,
                  rows_read      = COALESCE(:rows_read, rows_read),
                  rows_inserted  = COALESCE(:rows_inserted, rows_inserted),
                  rows_updated   = COALESCE(:rows_updated, rows_updated),
                  rows_deleted   = COALESCE(:rows_deleted, rows_deleted),
                  rows_unchanged = COALESCE(:rows_unchanged, rows_unchanged),
                  error_type     = COALESCE(:error_type, error_type),
                  error_message  = COALESCE(:error_message, error_message),
                  extra          = COALESCE(:extra, extra)
              WHERE id = :log_id
            """),
            dict(
                log_id=log_id, status=status, rows_read=rows_read,
                rows_inserted=rows_inserted, rows_updated=rows_updated,
                rows_deleted=rows_deleted, rows_unchanged=rows_unchanged,
                error_type=error_type, error_message=(error_message or "")[:2000] if error_message else None,
                extra=json.dumps(extra) if extra else None
            )
        )

STAT_MAPPING = {
    "Shots on Goal": "shots_on_goal",
    "Total Shots": "total_shots",
    "Shots off Goal": "shots_off_goal",
    "Shots insidebox": "shots_insidebox",
    "Shots outsidebox": "shots_outsidebox",
    "Blocked Shots": "blocked_shots",
    "Ball Possession": "possession",
    "Total passes": "passes",
    "Passes accurate": "passes_accurate",
    "Passes %": "passes_percentage",
    "Fouls": "fouls",
    "Corner Kicks": "corners",
    "Offsides": "offsides",
    "Yellow Cards": "yellow_cards",
    "Red Cards": "red_cards",
    "Goalkeeper Saves": "saves",
    "Tackles": "tackles",
    "Attacks": "attacks",
    "Dangerous Attacks": "dangerous_attacks",
    "expected_goals": "expected_goals",
    "goals_prevented": "goals_prevented",
}

class FetchMatchStatsOperator(BaseOperator):
    """
    Тянет статистику (/fixtures/statistics) для:
      - явно переданных fixture_ids,
      - иначе — только завершённых матчей, которых ещё нет в football.api_football_match_stats.
    Делает UPSERT, логирует результат. Если новых матчей нет — пишет лог и завершается успехом.
    """
    template_fields = ("fixture_ids", "api_host", "seasons", "leagues")
    ui_color = "#f1f8e9"

    def __init__(
        self,
        fixture_ids: Optional[List[int]] = None,
        seasons: Optional[List[int]] = None,
        leagues: Optional[List[int]] = None,
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        postgres_conn_id: str = "dwh_postgres",
        throttle_sec: float = 0.5,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.fixture_ids = fixture_ids
        self.seasons = seasons or []
        self.leagues = leagues or []
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.postgres_conn_id = postgres_conn_id
        self.throttle_sec = throttle_sec

    def _resolve_fixture_ids(self, engine: Engine) -> List[int]:
        """
        Если список не задан:
          берём ТОЛЬКО завершённые матчи из расписания, которых нет в статистике.
        По статусу используем гибкое условие: finished/full time/aet/pen (ILIKE).
        """
        if self.fixture_ids:
            return sorted(set(int(x) for x in self.fixture_ids))

        sql = text("""
          SELECT s.fixture_id
          FROM football.api_football_schedule s
          LEFT JOIN football.api_football_match_stats ms
                 ON ms.fixture_id = s.fixture_id
          WHERE ms.fixture_id IS NULL
            AND s.status IS NOT NULL
            AND (:seasons_empty OR s.season = ANY(:seasons))
            AND (:leagues_empty OR s.league_id = ANY(:leagues))
            AND (
                  s.status ILIKE '%finished%'
               OR s.status ILIKE '%full time%'
               OR s.status ILIKE '%aet%'
               OR s.status ILIKE '%pen%'
            )
        """)
        with engine.begin() as conn:
            rows = conn.execute(
                sql,
                {
                    "seasons": self.seasons,
                    "seasons_empty": len(self.seasons) == 0,
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                },
            ).fetchall()
        return [int(r[0]) for r in rows]

    def _fetch_stats_for_fixture(self, api_key: str, fixture_id: int) -> List[Dict[str, Any]]:
        headers = {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
        }
        url = f"{self.api_host}/fixtures/statistics"
        r = requests.get(url, headers=headers, params={"fixture": fixture_id}, timeout=20)
        r.raise_for_status()
        return r.json().get("response", []) or []

    @staticmethod
    def _normalize_value(val):
        if val is None or val == "":
            return None
        if isinstance(val, str) and val.endswith("%"):
            val = val.replace("%", "")
        try:
            return float(val)
        except Exception:
            return None

    def _rows_from_response(self, fixture_id: int, resp: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        rows = []
        for team_data in resp:
            team = team_data.get("team") or {}
            stats = team_data.get("statistics") or []
            rec = {
                "fixture_id": fixture_id,
                "team_id": team.get("id"),
                "team_name": team.get("name"),
                "shots_on_goal": None, "total_shots": None, "shots_off_goal": None,
                "shots_insidebox": None, "shots_outsidebox": None, "blocked_shots": None,
                "possession": None, "passes": None, "passes_accurate": None, "passes_percentage": None,
                "fouls": None, "corners": None, "offsides": None,
                "yellow_cards": None, "red_cards": None, "saves": None, "tackles": None,
                "attacks": None, "dangerous_attacks": None,
                "expected_goals": None, "goals_prevented": None,
            }
            for s in stats:
                key = STAT_MAPPING.get(s.get("type"))
                if key:
                    rec[key] = self._normalize_value(s.get("value"))
            rows.append(rec)
        return rows

    def _upsert_rows(self, engine: Engine, rows: List[Dict[str, Any]]) -> Dict[str, int]:
        if not rows:
            return {"inserted": 0, "updated": 0}
        upsert_sql = text("""
          INSERT INTO football.api_football_match_stats (
            fixture_id, team_id, team_name,
            shots_on_goal, total_shots, shots_off_goal,
            shots_insidebox, shots_outsidebox, blocked_shots,
            possession, passes, passes_accurate, passes_percentage,
            fouls, corners, offsides,
            yellow_cards, red_cards, saves, tackles,
            attacks, dangerous_attacks, expected_goals, goals_prevented
          )
          VALUES (
            :fixture_id, :team_id, :team_name,
            :shots_on_goal, :total_shots, :shots_off_goal,
            :shots_insidebox, :shots_outsidebox, :blocked_shots,
            :possession, :passes, :passes_accurate, :passes_percentage,
            :fouls, :corners, :offsides,
            :yellow_cards, :red_cards, :saves, :tackles,
            :attacks, :dangerous_attacks, :expected_goals, :goals_prevented
          )
          ON CONFLICT (fixture_id, team_id) DO UPDATE SET
            team_name         = EXCLUDED.team_name,
            shots_on_goal     = EXCLUDED.shots_on_goal,
            total_shots       = EXCLUDED.total_shots,
            shots_off_goal    = EXCLUDED.shots_off_goal,
            shots_insidebox   = EXCLUDED.shots_insidebox,
            shots_outsidebox  = EXCLUDED.shots_outsidebox,
            blocked_shots     = EXCLUDED.blocked_shots,
            possession        = EXCLUDED.possession,
            passes            = EXCLUDED.passes,
            passes_accurate   = EXCLUDED.passes_accurate,
            passes_percentage = EXCLUDED.passes_percentage,
            fouls             = EXCLUDED.fouls,
            corners           = EXCLUDED.corners,
            offsides          = EXCLUDED.offsides,
            yellow_cards      = EXCLUDED.yellow_cards,
            red_cards         = EXCLUDED.red_cards,
            saves             = EXCLUDED.saves,
            tackles           = EXCLUDED.tackles,
            attacks           = EXCLUDED.attacks,
            dangerous_attacks = EXCLUDED.dangerous_attacks,
            expected_goals    = EXCLUDED.expected_goals,
            goals_prevented   = EXCLUDED.goals_prevented
        """)
        inserted = 0
        with engine.begin() as conn:
            for batch in _chunked(rows, 1000):
                conn.execute(upsert_sql, batch)
                inserted += len(batch)
        return {"inserted": inserted, "updated": 0}

    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine = _create_engine_from_conn_id(self.postgres_conn_id)

        dag_id = context["dag"].dag_id if context.get("dag") else "unknown_dag"
        task_id = context["task"].task_id if context.get("task") else self.task_id
        run_id = context.get("run_id")
        try_number = getattr(context.get("ti"), "try_number", 1)

        log_id = _log_start(
            engine, dag_id, task_id, run_id, try_number,
            target_table="football.api_football_match_stats", operation="upsert",
            extra={"source": "/fixtures/statistics"}
        )

        try:
            fx_ids = self._resolve_fixture_ids(engine)
            self.log.info("Finished fixtures missing in stats: %s", len(fx_ids))

            if not fx_ids:
                _log_finish(
                    engine, log_id, status="success",
                    rows_read=0, rows_inserted=0,
                    extra={"note": "no finished fixtures to load"}
                )
                return {"fixtures": [], "rows": 0}

            total_read = 0
            total_inserted = 0

            for i, fx in enumerate(fx_ids, 1):
                try:
                    resp = self._fetch_stats_for_fixture(api_key, fx)
                    rows = self._rows_from_response(fx, resp)
                    total_read += len(rows)
                    if rows:
                        res = self._upsert_rows(engine, rows)
                        total_inserted += res["inserted"]
                except Exception as e:
                    self.log.warning("Failed fx=%s: %s", fx, e)
                time.sleep(self.throttle_sec)

            _log_finish(
                engine, log_id, status="success",
                rows_read=total_read, rows_inserted=total_inserted,
                extra={"fixtures_processed": len(fx_ids)}
            )
            return {"fixtures": fx_ids, "rows": total_read}

        except Exception as e:
            _log_finish(
                engine, log_id, status="failed",
                error_type=type(e).__name__, error_message=str(e)
            )
            raise
