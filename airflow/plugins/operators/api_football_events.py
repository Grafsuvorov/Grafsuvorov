from __future__ import annotations

import time
from typing import List, Dict, Any, Optional

import requests
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from sqlalchemy import text
from sqlalchemy.engine import Engine

# переиспользуем утилиты логирования и подключения из вашего модуля
from operators.api_football import (
    _create_engine_from_conn_id,
    log_start,
    log_finish,
)


class FetchMatchEventsOperator(BaseOperator):
    """
    Тянет события для матчей последнего сезона из football.api_football_schedule,
    только для завершённых матчей, и только для тех fixture_id, которых ещё нет
    в football.api_football_match_events.

    Вставка идёт простым INSERT (без апсерта), т.к. выбираются только отсутствующие матчи.
    Логи пишет в football.etl_task_logs.
    """
    ui_color = "#fff3e0"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        seasons: Optional[List[int]] = None,
        leagues: Optional[List[int]] = None,
        throttle_sec: float = 0.7,
        per_call_retries: int = 3,
        request_timeout_sec: int = 20,
        batch_insert_size: int = 1000,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host.rstrip("/")
        self.seasons = seasons or []
        self.leagues = leagues or []
        self.throttle_sec = float(throttle_sec)
        self.per_call_retries = int(per_call_retries)
        self.request_timeout_sec = int(request_timeout_sec)
        self.batch_insert_size = int(batch_insert_size)

    # ---------- DB helpers ----------
    @staticmethod
    def _get_last_season(engine: Engine) -> Optional[int]:
        with engine.begin() as conn:
            res = conn.execute(text("SELECT MAX(season) FROM football.api_football_schedule"))
            val = res.scalar()
            return int(val) if val is not None else None

    @staticmethod
    def _get_missing_fixture_ids_for_scope(
        engine: Engine,
        seasons: List[int],
        leagues: List[int],
    ) -> List[int]:
        """
        Берём fixture_id последнего сезона, завершённые, отсутствующие в таблице событий.
        """
        sql = text(
            """
            SELECT DISTINCT s.fixture_id
            FROM football.api_football_schedule s
            WHERE (:seasons_empty OR s.season = ANY(:seasons))
              AND (:leagues_empty OR s.league_id = ANY(:leagues))
              AND s.fixture_id IS NOT NULL
              AND (s.status ILIKE 'Match Finished%' OR s.status = 'FT')
              AND NOT EXISTS (
                    SELECT 1
                    FROM football.api_football_match_events e
                    WHERE e.fixture_id = s.fixture_id
              )
            ORDER BY s.fixture_id
            """
        )
        with engine.begin() as conn:
            rows = conn.execute(
                sql,
                {
                    "seasons": seasons,
                    "seasons_empty": len(seasons) == 0,
                    "leagues": leagues,
                    "leagues_empty": len(leagues) == 0,
                },
            ).fetchall()
        return [int(r[0]) for r in rows]

    # ---------- HTTP ----------
    def _fetch_events_once(self, api_key: str, fixture_id: int) -> List[Dict[str, Any]]:
        url = f"{self.api_host}/fixtures/events"
        headers = {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
        }
        params = {"fixture": fixture_id}

        r = requests.get(url, headers=headers, params=params, timeout=self.request_timeout_sec)
        r.raise_for_status()
        data = (r.json() or {}).get("response", []) or []

        out: List[Dict[str, Any]] = []
        for ev in data:
            team = ev.get("team") or {}
            player = ev.get("player") or {}
            assist = ev.get("assist") or {}
            tm = ev.get("time") or {}
            out.append({
                "fixture_id": fixture_id,
                "team_id": team.get("id"),
                "team_name": team.get("name"),
                "player_id": player.get("id"),
                "player_name": player.get("name"),
                "assist_id": assist.get("id"),
                "assist_name": assist.get("name"),
                "type": ev.get("type"),
                "detail": ev.get("detail"),
                "comments": ev.get("comments"),
                "elapsed": tm.get("elapsed"),
                "extra": tm.get("extra"),
            })
        return out

    def _fetch_events_with_retry(self, api_key: str, fixture_id: int) -> List[Dict[str, Any]]:
        last_exc: Optional[Exception] = None
        for attempt in range(1, self.per_call_retries + 1):
            try:
                return self._fetch_events_once(api_key, fixture_id)
            except Exception as e:
                last_exc = e
                self.log.warning("Attempt %s/%s failed for fixture_id=%s: %s",
                                 attempt, self.per_call_retries, fixture_id, e)
                time.sleep(self.throttle_sec)
        if last_exc:
            raise last_exc
        return []

    # ---------- sanitize & insert ----------
    @staticmethod
    def _sanitize_records(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        def to_int(x):
            if x is None:
                return None
            try:
                return int(x)
            except Exception:
                return None

        out: List[Dict[str, Any]] = []
        for r in records:
            r = dict(r)
            # ints
            for k in ["fixture_id", "team_id", "player_id", "assist_id", "elapsed", "extra"]:
                r[k] = to_int(r.get(k))
            # strings, обрежем до разумных лимитов
            for k, lim in [
                ("team_name", 120),
                ("player_name", 120),
                ("assist_name", 120),
                ("type", 50),
                ("detail", 120),
                ("comments", 200),
            ]:
                v = r.get(k)
                if v is not None:
                    r[k] = str(v)[:lim]
            out.append(r)
        return out

    def _insert_events(self, engine: Engine, records: List[Dict[str, Any]]) -> int:
        if not records:
            return 0
        sql = text("""
            INSERT INTO football.api_football_match_events (
                fixture_id, team_id, team_name,
                player_id, player_name,
                assist_id, assist_name,
                type, detail, comments,
                elapsed, extra
            ) VALUES (
                :fixture_id, :team_id, :team_name,
                :player_id, :player_name,
                :assist_id, :assist_name,
                :type, :detail, :comments,
                :elapsed, :extra
            )
        """)
        inserted = 0
        recs = self._sanitize_records(records)
        with engine.begin() as conn:
            # батчим вставку
            for i in range(0, len(recs), self.batch_insert_size):
                chunk = recs[i:i + self.batch_insert_size]
                conn.execute(sql, chunk)
                inserted += len(chunk)
        return inserted

    # ---------- Airflow entry ----------
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
            target_table="football.api_football_match_events",
            operation="insert_missing_events",
            extra=None,
        )

        total_read = 0
        total_inserted = 0
        processed_fixtures: List[int] = []
        last_season: Optional[int] = None

        try:
            scoped_seasons = self.seasons
            if not scoped_seasons:
                last_season = self._get_last_season(engine)
                scoped_seasons = [last_season] if last_season is not None else []
            if not scoped_seasons:
                self.log.info("No season in schedule. Nothing to do.")
                log_finish(engine, log_id, status="success",
                           rows_read=0, rows_inserted=0,
                            extra={"last_season": None, "fixtures_total": 0})
                return {"last_season": None, "fixtures_total": 0, "events_inserted": 0}

            fixture_ids = self._get_missing_fixture_ids_for_scope(engine, scoped_seasons, self.leagues)
            self.log.info(
                "Seasons=%s leagues=%s, missing fixtures to load events: %s",
                scoped_seasons,
                self.leagues or "ALL",
                len(fixture_ids),
            )

            all_records: List[Dict[str, Any]] = []
            for idx, fx in enumerate(fixture_ids, start=1):
                self.log.info("Processing [%s/%s] fixture_id=%s", idx, len(fixture_ids), fx)
                try:
                    rows = self._fetch_events_with_retry(api_key, fx)
                    total_read += len(rows)
                    if rows:
                        all_records.extend(rows)
                        processed_fixtures.append(fx)
                    else:
                        self.log.info("No events returned for fixture_id=%s", fx)
                except Exception as e:
                    self.log.warning("Failed to fetch events for fixture_id=%s: %s", fx, e)
                time.sleep(self.throttle_sec)

            if all_records:
                total_inserted = self._insert_events(engine, all_records)
                self.log.info("Inserted events: %s", total_inserted)
            else:
                self.log.info("No records to insert.")

            # лог успеха
            log_finish(
                engine=engine,
                log_id=log_id,
                status="success",
                rows_read=total_read,
                rows_inserted=total_inserted,
                extra={
                    "last_season": last_season,
                    "seasons": scoped_seasons,
                    "leagues": self.leagues,
                    "fixtures_total": len(fixture_ids),
                    "fixtures_processed": processed_fixtures[:200],
                    "events_inserted": total_inserted,
                },
            )

            return {
                "last_season": last_season,
                "seasons": scoped_seasons,
                "fixtures_total": len(fixture_ids),
                "fixtures_processed": processed_fixtures,
                "events_inserted": total_inserted,
            }

        except Exception as e:
            log_finish(
                engine=engine,
                log_id=log_id,
                status="failed",
                rows_read=total_read,
                rows_inserted=total_inserted,
                error_type=type(e).__name__,
                error_message=str(e),
                extra={"last_season": last_season},
            )
            raise
