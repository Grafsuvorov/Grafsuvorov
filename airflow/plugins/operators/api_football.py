# D:\airflow\plugins\operators\api_football.py
from __future__ import annotations

import json
import os
import socket
import time
import math
from typing import Iterable, List, Dict, Any, Optional, Set

import requests
import pandas as pd
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from airflow.hooks.base import BaseHook
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine


# =========================
# utils
# =========================
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
    # postgresql+psycopg2://user:pass@host:port/schema
    uri = f"postgresql+psycopg2://{conn.login}:{conn.password}@{conn.host}:{conn.port}/{conn.schema}"
    return create_engine(uri, pool_pre_ping=True)


# =========================
# logging to football.etl_task_logs
# =========================
def log_start(engine: Engine,
              dag_id: str,
              task_id: str,
              run_id: Optional[str],
              try_number: int,
              target_table: Optional[str],
              operation: Optional[str],
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
            },
        )
        return int(res.scalar_one())


def log_finish(engine: Engine,
               log_id: int,
               status: str = "success",
               rows_read: Optional[int] = None,
               rows_inserted: Optional[int] = None,
               rows_updated: Optional[int] = None,
               rows_deleted: Optional[int] = None,
               rows_unchanged: Optional[int] = None,
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
                    rows_deleted  = COALESCE(:rows_deleted, rows_deleted),
                    rows_unchanged= COALESCE(:rows_unchanged, rows_unchanged),
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
                "rows_deleted": rows_deleted,
                "rows_unchanged": rows_unchanged,
                "error_type": error_type,
                "error_message": (error_message or "")[:2000] if error_message else None,
                "extra": json.dumps(extra) if extra else None,
            },
        )


# =========================
# operator
# =========================
class FetchFixturesOperator(BaseOperator):
    """
    Тянет расписание для набора лиг/сезонов из API-Football и делает UPSERT в football.api_football_schedule.
    Пишет логи в football.etl_task_logs (running -> success/failed).
    В XCom возвращает список fixture_id, которые были вставлены/обновлены.
    """

    template_fields = ("leagues", "seasons",)
    ui_color = "#e0f7fa"

    def __init__(
        self,
        leagues: List[int],
        seasons: List[int],
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        postgres_conn_id: str = "dwh_postgres",
        chunk_size: int = 1000,
        sleep_sec: float = 0.5,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.leagues = leagues
        self.seasons = seasons
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.postgres_conn_id = postgres_conn_id
        self.chunk_size = chunk_size
        self.sleep_sec = sleep_sec

    # -------- HTTP --------
    def _fetch_fixtures(self, league_id: int, season: int, api_key: str) -> pd.DataFrame:
        headers = {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
        }
        params = {"league": league_id, "season": season}
        url = f"{self.api_host}/fixtures"

        self.log.info("Request: %s league=%s season=%s", url, league_id, season)
        r = requests.get(url, headers=headers, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        fixtures = data.get("response", []) or []

        rows = []
        for f in fixtures:
            fixture = f.get("fixture", {}) or {}
            league = f.get("league", {}) or {}
            venue = (fixture.get("venue") or {})
            status = (fixture.get("status") or {})
            teams = f.get("teams", {}) or {}
            goals = f.get("goals", {}) or {}
            score = f.get("score", {}) or {}

            rows.append({
                "fixture_id": fixture.get("id"),
                "date": fixture.get("date"),
                "timestamp": fixture.get("timestamp"),
                "timezone": fixture.get("timezone"),
                "venue_name": venue.get("name"),
                "venue_city": venue.get("city"),
                "referee": fixture.get("referee"),
                "status": status.get("long"),
                "round": league.get("round"),
                "league_id": league.get("id"),
                "league_name": league.get("name"),
                "league_country": league.get("country"),
                "season": league.get("season"),
                "home_team_id": (teams.get("home") or {}).get("id"),
                "home_team": (teams.get("home") or {}).get("name"),
                "home_team_winner": (teams.get("home") or {}).get("winner"),
                "away_team_id": (teams.get("away") or {}).get("id"),
                "away_team": (teams.get("away") or {}).get("name"),
                "away_team_winner": (teams.get("away") or {}).get("winner"),
                "home_goals": goals.get("home"),
                "away_goals": goals.get("away"),
                "score_halftime_home": (score.get("halftime") or {}).get("home"),
                "score_halftime_away": (score.get("halftime") or {}).get("away"),
                "score_fulltime_home": (score.get("fulltime") or {}).get("home"),
                "score_fulltime_away": (score.get("fulltime") or {}).get("away"),
                "score_penalty_home": (score.get("penalty") or {}).get("home"),
                "score_penalty_away": (score.get("penalty") or {}).get("away"),
            })

        df = pd.DataFrame(rows)
        self.log.info("Fetched fixtures: %s", len(df))
        return df

    # -------- DB helpers --------
    @staticmethod
    def _existing_ids(engine: Engine, ids: List[int]) -> Set[int]:
        if not ids:
            return set()
        # берём существующие fixture_id одним запросом (батчим по 10k для надёжности)
        exist: Set[int] = set()
        with engine.begin() as conn:
            for chunk in _chunked(ids, 10000):
                res = conn.execute(
                    text("""
                        SELECT fixture_id
                        FROM football.api_football_schedule
                        WHERE fixture_id = ANY(:ids)
                    """),
                    {"ids": chunk},
                )
                exist.update(int(r[0]) for r in res.fetchall())
        return exist

    @staticmethod
    def _sanitize_records(df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Привести pandas-данные к типам БД:
         - NaN/NaT -> None
         - числовые поля -> int или None
         - обрезать очень длинные строки
        """
        # заменим NaN/NaT на None
        df = df.replace({pd.NA: None, pd.NaT: None}).where(pd.notnull(df), None)

        int_fields = [
            "fixture_id", "timestamp", "league_id", "season",
            "home_team_id", "away_team_id",
            "home_goals", "away_goals",
            "score_halftime_home", "score_halftime_away",
            "score_fulltime_home", "score_fulltime_away",
            "score_penalty_home", "score_penalty_away",
        ]

        def to_int(v):
            if v is None:
                return None
            if isinstance(v, float) and math.isnan(v):
                return None
            try:
                return int(v)
            except Exception:
                return None

        out: List[Dict[str, Any]] = []
        for rec in df.to_dict(orient="records"):
            for k in int_fields:
                rec[k] = to_int(rec.get(k))
            # подрежем особо длинные/шумные строки
            for k, lim in [
                ("referee", 200),
                ("venue_name", 200),
                ("venue_city", 200),
                ("round", 100),
                ("timezone", 50),
                ("league_name", 120),
                ("league_country", 120),
                ("home_team", 120),
                ("away_team", 120),
                ("status", 100),
            ]:
                if rec.get(k) is not None:
                    rec[k] = str(rec[k])[:lim]
            out.append(rec)
        return out

    def _upsert(self, engine: Engine, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Возвращает dict с метриками:
        {
          "affected_ids": [...],
          "rows_inserted": int,
          "rows_updated": int
        }
        """
        metrics = {
            "affected_ids": [],
            "rows_inserted": 0,
            "rows_updated": 0,
        }
        if df.empty:
            return metrics

        all_ids = [int(x) for x in df["fixture_id"].dropna().tolist()]
        existed = self._existing_ids(engine, all_ids)
        rows_updated = len(existed)
        rows_inserted = max(len(all_ids) - rows_updated, 0)

        upsert_sql = text("""
            INSERT INTO football.api_football_schedule (
              fixture_id, date, timestamp, timezone, venue_name, venue_city, referee, status, round,
              league_id, league_name, league_country, season,
              home_team_id, home_team, home_team_winner,
              away_team_id, away_team, away_team_winner,
              home_goals, away_goals,
              score_halftime_home, score_halftime_away,
              score_fulltime_home, score_fulltime_away,
              score_penalty_home, score_penalty_away,
              updated_dttm
            )
            VALUES (
              :fixture_id, :date, :timestamp, :timezone, :venue_name, :venue_city, :referee, :status, :round,
              :league_id, :league_name, :league_country, :season,
              :home_team_id, :home_team, :home_team_winner,
              :away_team_id, :away_team, :away_team_winner,
              :home_goals, :away_goals,
              :score_halftime_home, :score_halftime_away,
              :score_fulltime_home, :score_fulltime_away,
              :score_penalty_home, :score_penalty_away,
              now()
            )
            ON CONFLICT (fixture_id) DO UPDATE SET
              date                = EXCLUDED.date,
              timestamp           = EXCLUDED.timestamp,
              timezone            = EXCLUDED.timezone,
              venue_name          = EXCLUDED.venue_name,
              venue_city          = EXCLUDED.venue_city,
              referee             = EXCLUDED.referee,
              status              = EXCLUDED.status,
              round               = EXCLUDED.round,
              league_id           = EXCLUDED.league_id,
              league_name         = EXCLUDED.league_name,
              league_country      = EXCLUDED.league_country,
              season              = EXCLUDED.season,
              home_team_id        = EXCLUDED.home_team_id,
              home_team           = EXCLUDED.home_team,
              home_team_winner    = EXCLUDED.home_team_winner,
              away_team_id        = EXCLUDED.away_team_id,
              away_team           = EXCLUDED.away_team,
              away_team_winner    = EXCLUDED.away_team_winner,
              home_goals          = EXCLUDED.home_goals,
              away_goals          = EXCLUDED.away_goals,
              score_halftime_home = EXCLUDED.score_halftime_home,
              score_halftime_away = EXCLUDED.score_halftime_away,
              score_fulltime_home = EXCLUDED.score_fulltime_home,
              score_fulltime_away = EXCLUDED.score_fulltime_away,
              score_penalty_home  = EXCLUDED.score_penalty_home,
              score_penalty_away  = EXCLUDED.score_penalty_away,
              updated_dttm        = now()
        """)

        sanitized: List[Dict[str, Any]] = self._sanitize_records(df)

        affected_ids: List[int] = []
        with engine.begin() as conn:
            for batch in _chunked(sanitized, 1000):
                conn.execute(upsert_sql, batch)
                affected_ids.extend([int(r["fixture_id"]) for r in batch if r.get("fixture_id") is not None])

        metrics["affected_ids"] = sorted(set(affected_ids))
        metrics["rows_inserted"] = rows_inserted
        metrics["rows_updated"] = rows_updated
        return metrics

    # -------- Airflow entry --------
    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine = _create_engine_from_conn_id(self.postgres_conn_id)

        dag_id = context["dag"].dag_id if context.get("dag") else "unknown_dag"
        task_id = context["task"].task_id if context.get("task") else self.task_id
        run_id = context.get("run_id")
        try_number = getattr(context.get("ti"), "try_number", 1)

        # лог запуска
        log_id = log_start(
            engine=engine,
            dag_id=dag_id,
            task_id=task_id,
            run_id=run_id,
            try_number=try_number,
            target_table="football.api_football_schedule",
            operation="upsert",
            extra={"leagues": self.leagues, "seasons": self.seasons},
        )

        all_ids: List[int] = []
        total_read = 0
        total_ins = 0
        total_upd = 0

        try:
            for lg in self.leagues:
                for ssn in self.seasons:
                    df = self._fetch_fixtures(lg, ssn, api_key)
                    total_read += len(df)

                    metrics = self._upsert(engine, df)
                    all_ids.extend(metrics["affected_ids"])
                    total_ins += metrics["rows_inserted"]
                    total_upd += metrics["rows_updated"]

                    self.log.info(
                        "Upserted league=%s season=%s: rows_inserted=%s rows_updated=%s (read=%s)",
                        lg, ssn, metrics["rows_inserted"], metrics["rows_updated"], len(df)
                    )
                    time.sleep(self.sleep_sec)

            out_ids = sorted(set(all_ids))
            self.log.info("Total affected fixtures: %s", len(out_ids))

            # лог завершения - success
            log_finish(
                engine=engine,
                log_id=log_id,
                status="success",
                rows_read=total_read,
                rows_inserted=total_ins,
                rows_updated=total_upd,
                extra={"affected_fixtures": out_ids[:200]}  # не засоряем лог огромными payload'ами
            )

            return out_ids

        except Exception as e:
            # лог завершения - failed
            log_finish(
                engine=engine,
                log_id=log_id,
                status="failed",
                rows_read=total_read,
                rows_inserted=total_ins,
                rows_updated=total_upd,
                error_type=type(e).__name__,
                error_message=str(e),
            )
            raise
