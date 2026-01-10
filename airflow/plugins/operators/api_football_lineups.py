# D:\airflow\plugins\operators\api_football_lineups.py
from __future__ import annotations

import json
import os
import socket
import time
from typing import Any, Dict, List, Optional

import pandas as pd
import requests
from airflow.hooks.base import BaseHook
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from requests.adapters import HTTPAdapter
from sqlalchemy import text
from sqlalchemy.engine import Engine, create_engine
from urllib3.util.retry import Retry


def _engine(conn_id: str) -> Engine:
    c = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{c.login}:{c.password}@{c.host}:{c.port}/{c.schema}"
    return create_engine(uri, pool_pre_ping=True)


def _chunked(lst: List[dict], size: int):
    for i in range(0, len(lst), size):
        yield lst[i : i + size]


def log_start(engine: Engine, dag_id: str, task_id: str, run_id: Optional[str],
              try_number: int, target_table: Optional[str], operation: Optional[str],
              extra: Optional[dict] = None) -> int:
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
            {
                "dag_id": dag_id,
                "task_id": task_id,
                "run_id": run_id,
                "try_number": try_number,
                "target_table": target_table,
                "operation": operation,
                "host": socket.gethostname(),
                "container_id": os.environ.get("HOSTNAME"),
                "extra": json.dumps(extra) if extra else None,
            }
        )
        return int(res.scalar_one())


def log_finish(engine: Engine, log_id: int, status: str = "success",
               rows_read: Optional[int] = None,
               rows_inserted: Optional[int] = None,
               rows_updated: Optional[int] = None,
               error_type: Optional[str] = None,
               error_message: Optional[str] = None,
               extra: Optional[dict] = None) -> None:
    with engine.begin() as conn:
        conn.execute(
            text("""
                UPDATE football.etl_task_logs
                SET ended_at      = now(),
                    status        = :status,
                    rows_read     = COALESCE(:rows_read, rows_read),
                    rows_inserted = COALESCE(:rows_inserted, rows_inserted),
                    rows_updated  = COALESCE(:rows_updated, rows_updated),
                    error_type    = COALESCE(:error_type, error_type),
                    error_message = COALESCE(:error_message, error_message),
                    extra         = COALESCE(:extra, extra)
                WHERE id = :log_id
            """),
            {
                "log_id": log_id,
                "status": status,
                "rows_read": rows_read,
                "rows_inserted": rows_inserted,
                "rows_updated": rows_updated,
                "error_type": error_type,
                "error_message": (error_message or "")[:2000] if error_message else None,
                "extra": json.dumps(extra) if extra else None,
            }
        )


class FetchLineupsOperator(BaseOperator):
    """
    Тянет /fixtures/lineups ТОЛЬКО для тех fixture_id, которые:
      1) есть в football.api_football_schedule,
      2) имеют статус «сыгран»,
      3) отсутствуют в football.api_football_lineups.

    Можно дополнительно ограничить выборку по сезонам/лигам.
    """

    template_fields = ("seasons", "leagues")
    ui_color = "#e8f5e9"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        seasons: Optional[List[int]] = None,       # если None — все сезоны из schedule
        leagues: Optional[List[int]] = None,       # если None — все лиги из schedule
        throttle_sec: float = 0.5,
        per_call_retries: int = 3,
        upsert_batch_size: int = 1000,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.seasons = seasons or []
        self.leagues = leagues or []
        self.throttle_sec = throttle_sec
        self.per_call_retries = per_call_retries
        self.upsert_batch_size = upsert_batch_size

        self.req_total = 0
        self.req_success = 0
        self.req_errors = 0

    # ---------- кандидаты: finished в schedule и нет в lineups ----------
    def _pick_candidates(self, engine: Engine) -> List[int]:
        finished_filter = """
            s.status ILIKE '%Match Finished%' OR
            s.status ILIKE '%Full Time%'      OR
            s.status ILIKE '%FT%'             OR
            s.status ILIKE '%AET%'            OR
            s.status ILIKE '%PEN%'
        """
        sql = text(f"""
            SELECT DISTINCT s.fixture_id
            FROM football.api_football_schedule s
            WHERE s.fixture_id IS NOT NULL
              AND ({finished_filter})
              AND s.season = 2025
              AND (:leagues_empty OR s.league_id = ANY(:leagues))
              AND NOT EXISTS (
                    SELECT 1
                    FROM football.api_football_lineups l
                    WHERE l.fixture_id = s.fixture_id
              )
            ORDER BY s.fixture_id
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql, conn,
                params={
                    "seasons": self.seasons,
                    "seasons_empty": len(self.seasons) == 0,
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                },
            )
        return [int(x) for x in df["fixture_id"].tolist()]

    # ---------- HTTP ----------
    def _session(self, api_key: str) -> requests.Session:
        s = requests.Session()
        s.headers.update({
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        })
        retry = Retry(
            total=3, connect=3, read=3,
            backoff_factor=0.6,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods={"GET"},
            raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry, pool_connections=8, pool_maxsize=16)
        s.mount("https://", adapter)
        s.mount("http://", adapter)
        return s

    def _api_get_lineups(self, session: requests.Session, fixture_id: int):
        url = f"{self.api_host}/fixtures/lineups"
        params = {"fixture": fixture_id}
        last_err = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_total += 1
            try:
                self.log.info("[lineups] GET %s fixture=%s attempt=%s", url, fixture_id, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                r.raise_for_status()
                data = r.json() or {}
                resp = data.get("response", []) or []
                self.req_success += 1
                return resp, None
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[lineups] fixture=%s attempt=%s error: %s", fixture_id, attempt, e)
                time.sleep(2 ** attempt)
        return [], last_err

    @staticmethod
    def _parse_rows(fixture_id: int, response: list[dict]) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        for team in response:
            team_id = (team.get("team") or {}).get("id")
            team_name = (team.get("team") or {}).get("name")
            coach_id = (team.get("coach") or {}).get("id")
            coach_name = (team.get("coach") or {}).get("name")
            formation = team.get("formation")

            for p in team.get("startXI", []) or []:
                info = p.get("player", {}) or {}
                rows.append({
                    "fixture_id": fixture_id,
                    "team_id": team_id,
                    "team_name": team_name,
                    "coach_id": coach_id,
                    "coach_name": coach_name,
                    "formation": formation,
                    "player_id": info.get("id"),
                    "player_name": info.get("name"),
                    "number": info.get("number"),
                    "position": info.get("pos"),
                    "grid": info.get("grid"),
                    "is_starting": True,
                })
            for p in team.get("substitutes", []) or []:
                info = p.get("player", {}) or {}
                rows.append({
                    "fixture_id": fixture_id,
                    "team_id": team_id,
                    "team_name": team_name,
                    "coach_id": coach_id,
                    "coach_name": coach_name,
                    "formation": formation,
                    "player_id": info.get("id"),
                    "player_name": info.get("name"),
                    "number": info.get("number"),
                    "position": info.get("pos"),
                    "grid": info.get("grid"),
                    "is_starting": False,
                })
        return rows

    def _upsert(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0
        stmt = text("""
            INSERT INTO football.api_football_lineups (
                fixture_id, team_id, team_name, coach_id, coach_name, formation,
                player_id, player_name, number, position, grid, is_starting, updated_dttm
            )
            VALUES (
                :fixture_id, :team_id, :team_name, :coach_id, :coach_name, :formation,
                :player_id, :player_name, :number, :position, :grid, :is_starting, now()
            )
            ON CONFLICT (fixture_id, team_id, player_id) DO UPDATE SET
                team_name   = EXCLUDED.team_name,
                coach_id    = EXCLUDED.coach_id,
                coach_name  = EXCLUDED.coach_name,
                formation   = EXCLUDED.formation,
                player_name = EXCLUDED.player_name,
                number      = EXCLUDED.number,
                position    = EXCLUDED.position,
                grid        = EXCLUDED.grid,
                is_starting = EXCLUDED.is_starting,
                updated_dttm= now()
        """)
        total = 0
        with engine.begin() as conn:
            for batch in _chunked(rows, self.upsert_batch_size):
                conn.execute(stmt, batch)
                total += len(batch)
        return total

    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine  = _engine(self.postgres_conn_id)

        dag_id  = context["dag"].dag_id if context.get("dag") else "unknown_dag"
        task_id = context["task"].task_id if context.get("task") else self.task_id
        run_id  = context.get("run_id")
        try_no  = getattr(context.get("ti"), "try_number", 1)

        log_id = log_start(
            engine, dag_id, task_id, run_id, try_no,
            target_table="football.api_football_lineups", operation="upsert",
            extra={"filter": "finished_in_schedule_and_absent_in_lineups",
                   "seasons": self.seasons, "leagues": self.leagues}
        )

        total_read = 0
        total_written = 0

        try:
            fixture_ids = self._pick_candidates(engine)
            self.log.info("Кандидатов (fixture_id): %s", len(fixture_ids))

            if not fixture_ids:
                log_finish(engine, log_id, status="success",
                           rows_read=0, rows_inserted=0, rows_updated=0,
                           extra={"requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
                return {"fixtures": 0, "rows": 0,
                        "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

            session = self._session(api_key)

            buffer: List[Dict[str, Any]] = []
            for fx in fixture_ids:
                resp, err = self._api_get_lineups(session, int(fx))
                if err:
                    self.log.warning("fixture_id=%s: error: %s", fx, err)
                rows = self._parse_rows(int(fx), resp)
                total_read += 1
                if rows:
                    buffer.extend(rows)
                time.sleep(self.throttle_sec)

            if buffer:
                total_written = self._upsert(engine, buffer)

            self.log.info("=== Lineups rows written: %s (fixtures=%s) ===", total_written, len(fixture_ids))
            self.log.info("=== API requests: total=%s success=%s errors=%s ===",
                          self.req_total, self.req_success, self.req_errors)

            log_finish(engine, log_id, status="success",
                       rows_read=total_read, rows_inserted=total_written, rows_updated=0,
                       extra={"fixtures": len(fixture_ids),
                              "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
            return {"fixtures": len(fixture_ids), "rows": total_written,
                    "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

        except Exception as e:
            log_finish(engine, log_id, status="failed",
                       rows_read=total_read, rows_inserted=total_written, rows_updated=0,
                       error_type=type(e).__name__, error_message=str(e))
            raise
