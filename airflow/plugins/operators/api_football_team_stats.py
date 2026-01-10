# D:\airflow\plugins\operators\api_football_team_stats.py
from __future__ import annotations

import json
import os
import socket
import time
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
import requests
from airflow.hooks.base import BaseHook
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from sqlalchemy import text
from sqlalchemy.engine import Engine, create_engine

# =============== infra ===============

def _engine(conn_id: str) -> Engine:
    c = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{c.login}:{c.password}@{c.host}:{c.port}/{c.schema}"
    return create_engine(uri, pool_pre_ping=True)

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

# =============== operator ===============

class FetchTeamStatsOperator(BaseOperator):
    """
    Тянет /teams/statistics и делает UPSERT в football.api_football_team_stats.

    * Берём пары (league_id, season, team_id, team_name) из football.api_football_schedule
      для заданных сезонов (и, опционально, лиг).
    * Обновляем только те пары, где schedule свежее team_stats по updated_dttm
      (с буфером min_staleness_minutes).
    * UPSERT ключ: (team_id, league_id, season), updated_dttm = now() на insert/update.
    * Логи пишем в football.etl_task_logs.
    """

    template_fields = ("seasons", "leagues", "min_staleness_minutes")

    ui_color = "#ede7f6"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        seasons: List[int] = [2025],
        leagues: Optional[List[int]] = None,    # если None — все лиги из schedule
        finished_only: bool = True,             # учитывать в schedule только завершённые матчи для свежести
        min_staleness_minutes: int = 10,        # буфер к team_stats.updated_dttm
        throttle_sec: float = 0.4,
        per_call_retries: int = 3,
        batch_size: int = 1000,                 # батч для upsert
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.seasons = seasons or []
        self.leagues = leagues or []
        self.finished_only = finished_only
        self.min_staleness_minutes = min_staleness_minutes
        self.throttle_sec = throttle_sec
        self.per_call_retries = per_call_retries
        self.batch_size = batch_size

        # счётчики запросов
        self.req_total = 0
        self.req_success = 0
        self.req_errors = 0

    # ---- HTTP session ----
    def _session(self, api_key: str) -> requests.Session:
        s = requests.Session()
        # Если используешь прямой ключ API-Sports, замени на {"x-apisports-key": api_key}
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

    # ---- выбор кандидатов ----
    def _pick_candidates(self, engine: Engine) -> pd.DataFrame:
        """
        Возвращает список (league_id, season, team_id, team_name) из schedule,
        где schedule свежeе, чем team_stats + буфер.
        """
        finished_filter = """
            AND (
                 s.status ILIKE '%Match Finished%'
              OR s.status ILIKE '%Full Time%'
              OR s.status ILIKE '%FT%'
              OR s.status ILIKE '%AET%'
              OR s.status ILIKE '%PEN%'
            )
        """ if self.finished_only else ""

        sql = text(f"""
            WITH teams_raw AS (
              -- home
              SELECT s.league_id, s.season, s.home_team_id AS team_id,
                     COALESCE(s.home_team, s.home_team_id::text) AS team_name,
                     MAX(s.updated_dttm) AS sched_last
              FROM football.api_football_schedule s
              WHERE s.season = ANY(:seasons)
                AND (:leagues_empty OR s.league_id = ANY(:leagues))
              {finished_filter}
              GROUP BY s.league_id, s.season, s.home_team_id, s.home_team
              UNION ALL
              -- away
              SELECT s.league_id, s.season, s.away_team_id AS team_id,
                     COALESCE(s.away_team, s.away_team_id::text) AS team_name,
                     MAX(s.updated_dttm) AS sched_last
              FROM football.api_football_schedule s
              WHERE s.season = ANY(:seasons)
                AND (:leagues_empty OR s.league_id = ANY(:leagues))
              {finished_filter}
              GROUP BY s.league_id, s.season, s.away_team_id, s.away_team
            ),
            teams AS (
              SELECT league_id, season, team_id,
                     MAX(team_name) AS team_name,
                     MAX(sched_last) AS sched_last
              FROM teams_raw
              WHERE team_id IS NOT NULL
              GROUP BY league_id, season, team_id
            ),
            ts AS (
              SELECT league_id, season, team_id, MAX(updated_dttm) AS ts_last
              FROM football.api_football_team_stats
              WHERE season = ANY(:seasons)
                AND (:leagues_empty OR league_id = ANY(:leagues))
              GROUP BY league_id, season, team_id
            )
            SELECT
              t.league_id, t.season, t.team_id, t.team_name,
              t.sched_last,
              COALESCE(ts.ts_last, to_timestamp(0)) AS ts_last
            FROM teams t
            LEFT JOIN ts ON ts.league_id = t.league_id AND ts.season = t.season AND ts.team_id = t.team_id
            WHERE t.sched_last >
                  COALESCE(ts.ts_last, to_timestamp(0)) + make_interval(mins => :mins_buf)
            ORDER BY t.league_id, t.season, t.team_id
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql, conn,
                params={
                    "seasons": self.seasons,
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                    "mins_buf": self.min_staleness_minutes,
                },
            )
        return df

    # ---- API call ----
    def _api_get_team_stats(self, session: requests.Session, team_id: int, league_id: int, season: int):
        url = f"{self.api_host}/teams/statistics"
        params = {"team": team_id, "league": league_id, "season": season}
        last_err = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_total += 1
            try:
                self.log.info("[team_stats] GET %s team=%s lg=%s season=%s attempt=%s",
                              url, team_id, league_id, season, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                r.raise_for_status()
                data = r.json() or {}
                resp = data.get("response", {}) or {}
                self.req_success += 1
                return resp, None
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[team_stats] team=%s lg=%s season=%s attempt=%s error: %s",
                                 team_id, league_id, season, attempt, e)
                time.sleep(2 ** attempt)
        return {}, last_err

    # ---- parse ----
    @staticmethod
    def _parse_payload(team_id: int, league_id: int, season: int, resp: dict) -> Optional[Dict[str, Any]]:
        if not resp:
            return None
        # Защита от «пустых» статистик
        fixtures = (resp.get("fixtures") or {}).get("played", {}) or {}
        # если вообще нет числа матчей — считаем пустым ответом
        if fixtures.get("total") is None:
            return None

        return {
            "team_id": team_id,
            "league_id": league_id,
            "season": season,
            "team_name": (resp.get("team") or {}).get("name"),
            "league_name": (resp.get("league") or {}).get("name"),
            "matches_played": fixtures.get("total"),
            "wins": (resp.get("fixtures") or {}).get("wins", {}).get("total"),
            "draws": (resp.get("fixtures") or {}).get("draws", {}).get("total"),
            "losses": (resp.get("fixtures") or {}).get("loses", {}).get("total"),
            "goals_for": (resp.get("goals") or {}).get("for", {}).get("total", {}).get("total"),
            "goals_against": (resp.get("goals") or {}).get("against", {}).get("total", {}).get("total"),
            "clean_sheets": (resp.get("clean_sheet") or {}).get("total"),
            "failed_to_score": (resp.get("failed_to_score") or {}).get("total"),
            "penalties_scored": (resp.get("penalty") or {}).get("scored", {}).get("total"),
            "penalties_missed": (resp.get("penalty") or {}).get("missed", {}).get("total"),
            "expected_goals_total": (resp.get("expected") or {}).get("goals", {}).get("for", {}).get("total"),
            "expected_goals_against_total": (resp.get("expected") or {}).get("goals", {}).get("against", {}).get("total"),
        }

    # ---- upsert ----
    def _upsert(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0
        stmt = text("""
            INSERT INTO football.api_football_team_stats (
                team_id, league_id, season, team_name, league_name,
                matches_played, wins, draws, losses,
                goals_for, goals_against, clean_sheets, failed_to_score,
                penalties_scored, penalties_missed,
                expected_goals_total, expected_goals_against_total,
                updated_dttm
            )
            VALUES (
                :team_id, :league_id, :season, :team_name, :league_name,
                :matches_played, :wins, :draws, :losses,
                :goals_for, :goals_against, :clean_sheets, :failed_to_score,
                :penalties_scored, :penalties_missed,
                :expected_goals_total, :expected_goals_against_total,
                now()
            )
            ON CONFLICT (team_id, league_id, season) DO UPDATE SET
                team_name                      = EXCLUDED.team_name,
                league_name                    = EXCLUDED.league_name,
                matches_played                 = EXCLUDED.matches_played,
                wins                           = EXCLUDED.wins,
                draws                          = EXCLUDED.draws,
                losses                         = EXCLUDED.losses,
                goals_for                      = EXCLUDED.goals_for,
                goals_against                  = EXCLUDED.goals_against,
                clean_sheets                   = EXCLUDED.clean_sheets,
                failed_to_score                = EXCLUDED.failed_to_score,
                penalties_scored               = EXCLUDED.penalties_scored,
                penalties_missed               = EXCLUDED.penalties_missed,
                expected_goals_total           = EXCLUDED.expected_goals_total,
                expected_goals_against_total   = EXCLUDED.expected_goals_against_total,
                updated_dttm                   = now()
        """)
        # батчево
        total = 0
        with engine.begin() as conn:
            for i in range(0, len(rows), self.batch_size):
                conn.execute(stmt, rows[i:i+self.batch_size])
                total += len(rows[i:i+self.batch_size])
        return total

    # ---- execute ----
    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine  = _engine(self.postgres_conn_id)

        dag_id  = context["dag"].dag_id if context.get("dag") else "unknown_dag"
        task_id = context["task"].task_id if context.get("task") else self.task_id
        run_id  = context.get("run_id")
        try_no  = getattr(context.get("ti"), "try_number", 1)

        log_id = log_start(
            engine, dag_id, task_id, run_id, try_no,
            target_table="football.api_football_team_stats", operation="upsert",
            extra={"seasons": self.seasons, "leagues": self.leagues,
                   "finished_only": self.finished_only, "staleness_min": self.min_staleness_minutes}
        )

        total_written = 0
        total_candidates = 0
        report: List[Dict[str, Any]] = []

        try:
            cand = self._pick_candidates(engine)
            total_candidates = len(cand)
            self.log.info("Кандидатов (team,league,season) к обновлению: %s", total_candidates)

            if cand.empty:
                print(f"=== API requests used: total={self.req_total}, success={self.req_success}, errors={self.req_errors} ===")
                log_finish(engine, log_id, status="success",
                           rows_read=0, rows_inserted=0, rows_updated=0,
                           extra={"requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
                return {"candidates": 0, "rows_written": 0,
                        "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

            session = self._session(api_key)

            rows_to_write: List[Dict[str, Any]] = []
            for r in cand.itertuples(index=False):
                lg  = int(r.league_id)
                ssn = int(r.season)
                tid = int(r.team_id)
                tnm = (r.team_name or "").strip() or str(tid)

                resp, err = self._api_get_team_stats(session, tid, lg, ssn)
                time.sleep(self.throttle_sec)

                parsed = self._parse_payload(tid, lg, ssn, resp)
                if parsed:
                    # если team_name пуст из API — подставим из schedule
                    if not parsed.get("team_name"):
                        parsed["team_name"] = tnm
                    rows_to_write.append(parsed)

                report.append({
                    "team_id": tid, "league_id": lg, "season": ssn,
                    "sched_last": str(r.sched_last), "ts_last": str(r.ts_last),
                    "ok": bool(parsed), "error": "" if not err else err,
                })

            if rows_to_write:
                total_written = self._upsert(engine, rows_to_write)

            # табличка в лог
            if report:
                rep_df = pd.DataFrame(report, columns=["team_id","league_id","season","ok","error","sched_last","ts_last"])
                self.log.info("\n" + rep_df.to_string(index=False))

            self.log.info("=== TeamStats rows written: %s (candidates=%s) ===", total_written, total_candidates)
            self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===",
                          self.req_total, self.req_success, self.req_errors)
            print(f"=== API requests used: total={self.req_total}, success={self.req_success}, errors={self.req_errors} ===")

            log_finish(engine, log_id, status="success",
                       rows_read=total_candidates, rows_inserted=total_written, rows_updated=0,
                       extra={"rows_written": total_written,
                              "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
            return {"candidates": total_candidates, "rows_written": total_written,
                    "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

        except Exception as e:
            print(f"=== API requests used (before fail): total={self.req_total}, success={self.req_success}, errors={self.req_errors} ===")
            log_finish(engine, log_id, status="failed",
                       rows_read=total_candidates, rows_inserted=total_written, rows_updated=0,
                       error_type=type(e).__name__, error_message=str(e),
                       extra={"rows_written": total_written,
                              "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
            raise
