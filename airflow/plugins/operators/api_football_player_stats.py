# D:\airflow\plugins\operators\api_football_player_stats.py
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


# =============== infra & logging ===============

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

class FetchPlayerStatsOperator(BaseOperator):
    """
    Тянет /fixtures/players и делает UPSERT в football.api_football_player_stats.

    Логика выбора:
      * берём fixture_id из football.api_football_schedule за сезоны (по умолчанию 2025),
        только "сыгранные" статусы (Match Finished/Full Time/FT/AET/PEN)
      * исключаем fixture_id, которые уже присутствуют в football.api_football_player_stats
      * для оставшихся вызываем API и пишем UPSERT (ключ: fixture_id, team_id, player_id)

    Поля соответствуют вашему скрипту:
      fixture_id, team_id, team_name, player_id, player_name,
      player_rating, minutes, captain, substitute,
      goals, assists, shots_total, shots_on,
      passes_total, passes_key, passes_accuracy,
      tackles_total, tackles_blocks, tackles_interceptions,
      duels_total, duels_won,
      dribbles_attempts, dribbles_success,
      fouls_drawn, fouls_committed,
      cards_yellow, cards_red,
      penalty_won, penalty_committed, penalty_scored, penalty_missed, penalty_saved,
      updated_dttm
    """

    template_fields = ("seasons", "leagues")
    ui_color = "#ffe0b2"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        seasons: List[int] = [2025],
        leagues: Optional[List[int]] = None,    # если None — все лиги из schedule
        throttle_sec: float = 0.6,
        per_call_retries: int = 3,
        batch_size: int = 1000,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.seasons = seasons or [2025]
        self.leagues = leagues or []
        self.throttle_sec = throttle_sec
        self.per_call_retries = per_call_retries
        self.batch_size = batch_size

        self.req_total = 0
        self.req_success = 0
        self.req_errors = 0

    # ---- HTTP session ----
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

    # ---- выбор кандидатов (сыгранные из schedule, отсутствуют в player_stats) ----
    def _pick_candidates(self, engine: Engine) -> pd.DataFrame:
        sql = text("""
            WITH finished AS (
              SELECT
                s.fixture_id, s.league_id, s.season
              FROM football.api_football_schedule s
              WHERE s.season = ANY(:seasons)
                AND (:leagues_empty OR s.league_id = ANY(:leagues))
                AND (
                     s.status ILIKE '%Match Finished%'
                  OR s.status ILIKE '%Full Time%'
                  OR s.status ILIKE '%FT%'
                  OR s.status ILIKE '%AET%'
                  OR s.status ILIKE '%PEN%'
                )
            ),
            loaded AS (
              SELECT DISTINCT fixture_id
              FROM football.api_football_player_stats
            )
            SELECT f.fixture_id, f.league_id, f.season
            FROM finished f
            LEFT JOIN loaded l ON l.fixture_id = f.fixture_id
            WHERE l.fixture_id IS NULL
            ORDER BY f.league_id, f.season, f.fixture_id
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql, conn,
                params={
                    "seasons": self.seasons,
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                },
            )
        return df

    # ---- API call ----
    def _api_get_fixture_players(self, session: requests.Session, fixture_id: int):
        url = f"{self.api_host}/fixtures/players"
        params = {"fixture": fixture_id}
        last_err = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_total += 1
            try:
                self.log.info("[players] GET %s fixture=%s attempt=%s", url, fixture_id, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                r.raise_for_status()
                data = r.json() or {}
                resp = data.get("response", []) or []
                self.req_success += 1
                return resp, None
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[players] fixture=%s attempt=%s error: %s", fixture_id, attempt, e)
                time.sleep(2 ** attempt)
        return [], last_err

    # ---- sanitize helpers ----
    @staticmethod
    def _to_int(x):
        if x in (None, "", "null"):
            return None
        try:
            return int(x)
        except Exception:
            return None

    @staticmethod
    def _to_float(x):
        if x in (None, "", "null"):
            return None
        try:
            return float(x)
        except Exception:
            return None

    # ---- parse ----
    def _parse_rows(self, fixture_id: int, payload: List[dict]) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        for team in payload:
            tinfo = team.get("team", {}) or {}
            tid   = tinfo.get("id")
            tname = tinfo.get("name")

            for pentry in team.get("players", []) or []:
                pl    = pentry.get("player", {}) or {}
                stats = (pentry.get("statistics") or [{}])[0] or {}
                games = stats.get("games", {}) or {}

                rating = self._to_float(games.get("rating"))

                rows.append({
                    "fixture_id": fixture_id,
                    "team_id": tid,
                    "team_name": (tname or None),
                    "player_id": pl.get("id"),
                    "player_name": pl.get("name"),

                    "player_rating": rating,
                    "minutes": self._to_int(games.get("minutes")),
                    "captain": bool(games.get("captain")) if games.get("captain") is not None else None,
                    "substitute": bool(games.get("substitute")) if games.get("substitute") is not None else None,

                    "goals": (stats.get("goals") or {}).get("total"),
                    "assists": (stats.get("goals") or {}).get("assists"),

                    "shots_total": (stats.get("shots") or {}).get("total"),
                    "shots_on": (stats.get("shots") or {}).get("on"),

                    "passes_total": (stats.get("passes") or {}).get("total"),
                    "passes_key": (stats.get("passes") or {}).get("key"),
                    "passes_accuracy": (stats.get("passes") or {}).get("accuracy"),

                    "tackles_total": (stats.get("tackles") or {}).get("total"),
                    "tackles_blocks": (stats.get("tackles") or {}).get("blocks"),
                    "tackles_interceptions": (stats.get("tackles") or {}).get("interceptions"),

                    "duels_total": (stats.get("duels") or {}).get("total"),
                    "duels_won": (stats.get("duels") or {}).get("won"),

                    "dribbles_attempts": (stats.get("dribbles") or {}).get("attempts"),
                    "dribbles_success": (stats.get("dribbles") or {}).get("success"),

                    "fouls_drawn": (stats.get("fouls") or {}).get("drawn"),
                    "fouls_committed": (stats.get("fouls") or {}).get("committed"),

                    "cards_yellow": (stats.get("cards") or {}).get("yellow"),
                    "cards_red": (stats.get("cards") or {}).get("red"),

                    "penalty_won": (stats.get("penalty") or {}).get("won"),
                    "penalty_committed": (stats.get("penalty") or {}).get("commited"),  # орфография API
                    "penalty_scored": (stats.get("penalty") or {}).get("scored"),
                    "penalty_missed": (stats.get("penalty") or {}).get("missed"),
                    "penalty_saved": (stats.get("penalty") or {}).get("saved"),
                })
        return rows

    # ---- upsert ----
    def _upsert(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0

        stmt = text("""
            INSERT INTO football.api_football_player_stats (
                fixture_id, team_id, team_name, player_id, player_name,
                player_rating, minutes, captain, substitute,
                goals, assists,
                shots_total, shots_on,
                passes_total, passes_key, passes_accuracy,
                tackles_total, tackles_blocks, tackles_interceptions,
                duels_total, duels_won,
                dribbles_attempts, dribbles_success,
                fouls_drawn, fouls_committed,
                cards_yellow, cards_red,
                penalty_won, penalty_committed, penalty_scored, penalty_missed, penalty_saved,
                updated_dttm
            )
            VALUES (
                :fixture_id, :team_id, :team_name, :player_id, :player_name,
                :player_rating, :minutes, :captain, :substitute,
                :goals, :assists,
                :shots_total, :shots_on,
                :passes_total, :passes_key, :passes_accuracy,
                :tackles_total, :tackles_blocks, :tackles_interceptions,
                :duels_total, :duels_won,
                :dribbles_attempts, :dribbles_success,
                :fouls_drawn, :fouls_committed,
                :cards_yellow, :cards_red,
                :penalty_won, :penalty_committed, :penalty_scored, :penalty_missed, :penalty_saved,
                now()
            )
            ON CONFLICT (fixture_id, team_id, player_id) DO UPDATE SET
                team_name               = EXCLUDED.team_name,
                player_name             = EXCLUDED.player_name,
                player_rating           = EXCLUDED.player_rating,
                minutes                 = EXCLUDED.minutes,
                captain                 = EXCLUDED.captain,
                substitute              = EXCLUDED.substitute,
                goals                   = EXCLUDED.goals,
                assists                 = EXCLUDED.assists,
                shots_total             = EXCLUDED.shots_total,
                shots_on                = EXCLUDED.shots_on,
                passes_total            = EXCLUDED.passes_total,
                passes_key              = EXCLUDED.passes_key,
                passes_accuracy         = EXCLUDED.passes_accuracy,
                tackles_total           = EXCLUDED.tackles_total,
                tackles_blocks          = EXCLUDED.tackles_blocks,
                tackles_interceptions   = EXCLUDED.tackles_interceptions,
                duels_total             = EXCLUDED.duels_total,
                duels_won               = EXCLUDED.duels_won,
                dribbles_attempts       = EXCLUDED.dribbles_attempts,
                dribbles_success        = EXCLUDED.dribbles_success,
                fouls_drawn             = EXCLUDED.fouls_drawn,
                fouls_committed         = EXCLUDED.fouls_committed,
                cards_yellow            = EXCLUDED.cards_yellow,
                cards_red               = EXCLUDED.cards_red,
                penalty_won             = EXCLUDED.penalty_won,
                penalty_committed       = EXCLUDED.penalty_committed,
                penalty_scored          = EXCLUDED.penalty_scored,
                penalty_missed          = EXCLUDED.penalty_missed,
                penalty_saved           = EXCLUDED.penalty_saved,
                updated_dttm            = now()
        """)

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
            target_table="football.api_football_player_stats", operation="upsert",
            extra={"seasons": self.seasons, "leagues": self.leagues}
        )

        total_candidates = 0
        total_written = 0
        report: List[Dict[str, Any]] = []

        try:
            cand = self._pick_candidates(engine)
            total_candidates = len(cand)
            self.log.info("Кандидатов fixture_id к загрузке player stats: %s", total_candidates)

            if cand.empty:
                self.log.info("Новых сыгранных матчей без player stats не найдено.")
                log_finish(engine, log_id, status="success",
                           rows_read=0, rows_inserted=0, rows_updated=0,
                           extra={"requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}})
                return {"candidates": 0, "rows_written": 0,
                        "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

            session = self._session(api_key)

            rows_to_write: List[Dict[str, Any]] = []
            for r in cand.itertuples(index=False):
                fid = int(r.fixture_id)

                payload, err = self._api_get_fixture_players(session, fid)
                time.sleep(self.throttle_sec)

                parsed = self._parse_rows(fid, payload)
                rows_to_write.extend(parsed)

                report.append({"fixture_id": fid, "ok": bool(parsed), "error": "" if not err else err})

            if rows_to_write:
                total_written = self._upsert(engine, rows_to_write)

            if report:
                rep_df = pd.DataFrame(report, columns=["fixture_id","ok","error"])
                self.log.info("\n" + rep_df.to_string(index=False))

            self.log.info("=== PlayerStats rows written: %s (fixtures=%s) ===", total_written, total_candidates)
            self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===", self.req_total, self.req_success, self.req_errors)
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
