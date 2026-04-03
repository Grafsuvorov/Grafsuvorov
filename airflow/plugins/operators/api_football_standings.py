from __future__ import annotations

import time
from typing import List, Dict, Any, Optional, Tuple

import pandas as pd
import requests
from airflow.hooks.base import BaseHook
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from sqlalchemy import text
from sqlalchemy.engine import Engine, create_engine


def _engine(conn_id: str) -> Engine:
    c = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{c.login}:{c.password}@{c.host}:{c.port}/{c.schema}"
    return create_engine(uri, pool_pre_ping=True)


class FetchStandingsOperator(BaseOperator):
    """
    Обновляет football.api_football_standings UPSERT'ом.
    Берём пары (league_id, season) у которых max(updated_dttm) в schedule
    новее, чем max(updated_dttm) в standings + буфер.

    Ключ: (league_id, season, team_id).
    """

    template_fields = ("min_staleness_minutes", "leagues")

    ui_color = "#e8f5e9"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        leagues: Optional[List[int]] = None,   # если None — все лиги
        finished_only: bool = True,            # учитывать в schedule только завершённые матчи при расчёте max(updated_dttm)
        min_staleness_minutes: int = 5,        # буфер к stand.updated_dttm
        throttle_sec: float = 0.4,
        per_call_retries: int = 3,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.leagues = leagues or []
        self.finished_only = finished_only
        self.min_staleness_minutes = min_staleness_minutes
        self.throttle_sec = throttle_sec
        self.per_call_retries = per_call_retries

        self.req_total = 0
        self.req_success = 0
        self.req_errors = 0

    def _session(self, api_key: str) -> requests.Session:
        s = requests.Session()
        s.headers.update({
            "x-rapidapi-key": api_key,                   # замени на x-apisports-key если используешь прямой ключ
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        })
        retry = Retry(total=3, connect=3, read=3, backoff_factor=0.6,
                      status_forcelist=[429, 500, 502, 503, 504],
                      allowed_methods={"GET"}, raise_on_status=False)
        adapter = HTTPAdapter(max_retries=retry, pool_connections=8, pool_maxsize=16)
        s.mount("https://", adapter)
        s.mount("http://", adapter)
        return s

    def _pick_pairs_by_updated(self, engine: Engine) -> List[Tuple[int, int]]:
        """
        Сопоставляем max(updated_dttm) между schedule и standings.
        Берём пары, где schedule свежее, чем standings + буфер.
        """
        finished_filter = text("""
            AND (
                 s.status ILIKE '%Match Finished%'
              OR s.status ILIKE '%Full Time%'
              OR s.status ILIKE '%FT%'
              OR s.status ILIKE '%AET%'
              OR s.status ILIKE '%PEN%'
            )
        """) if self.finished_only else text("")

        sql = text(f"""
            WITH sched AS (
              SELECT
                s.league_id,
                s.season,
                MAX(s.updated_dttm) AS sched_last
              FROM football.api_football_schedule s
              WHERE (:leagues_empty OR s.league_id = ANY(:leagues))
              {finished_filter.text}
              GROUP BY s.league_id, s.season
            ),
            stand AS (
              SELECT league_id, season, MAX(updated_dttm) AS stand_last
              FROM football.api_football_standings
              GROUP BY league_id, season
            )
            SELECT
              sc.league_id, sc.season
            FROM sched sc
            LEFT JOIN stand st
              ON st.league_id = sc.league_id AND st.season = sc.season
            WHERE sc.sched_last >
                  COALESCE(st.stand_last, to_timestamp(0)) + make_interval(mins => :mins_buf)
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql, conn,
                params={
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                    "mins_buf": self.min_staleness_minutes,
                }
            )
        return [(int(r.league_id), int(r.season)) for r in df.itertuples(index=False)]

    def _api_get_standings(self, session: requests.Session, league_id: int, season: int):
        url = f"{self.api_host}/standings"
        params = {"league": league_id, "season": season}
        last_err = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_total += 1
            try:
                self.log.info("[standings] GET %s lg=%s season=%s attempt=%s", url, league_id, season, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                r.raise_for_status()
                data = r.json() or {}
                resp = data.get("response", []) or []
                self.req_success += 1
                return resp, None
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[standings] lg=%s season=%s attempt=%s error: %s", league_id, season, attempt, e)
                time.sleep(2 ** attempt)
        return [], last_err

    @staticmethod
    def _parse_payload(league_id: int, season: int, response: list) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        if not response:
            return rows
        league = response[0].get("league", {}) if response else {}
        groups = league.get("standings", []) or []
        for group in groups:
            for entry in group or []:
                team = entry.get("team", {}) or {}
                all_stats = entry.get("all", {}) or {}
                home = entry.get("home", {}) or {}
                away = entry.get("away", {}) or {}
                rows.append({
                    "league_id": league_id,
                    "season": season,
                    "team_id": team.get("id"),
                    "team_name": team.get("name"),
                    "group_name": entry.get("group"),
                    "rank": entry.get("rank"),
                    "points": entry.get("points"),
                    "goals_diff": entry.get("goalsDiff"),
                    "form": entry.get("form"),
                    "status": entry.get("status"),
                    "description": entry.get("description"),
                    "all_played": all_stats.get("played"),
                    "all_win": all_stats.get("win"),
                    "all_draw": all_stats.get("draw"),
                    "all_lose": all_stats.get("lose"),
                    "all_goals_for": (all_stats.get("goals") or {}).get("for"),
                    "all_goals_against": (all_stats.get("goals") or {}).get("against"),
                    "home_played": home.get("played"),
                    "home_win": home.get("win"),
                    "home_draw": home.get("draw"),
                    "home_lose": home.get("lose"),
                    "home_goals_for": (home.get("goals") or {}).get("for"),
                    "home_goals_against": (home.get("goals") or {}).get("against"),
                    "away_played": away.get("played"),
                    "away_win": away.get("win"),
                    "away_draw": away.get("draw"),
                    "away_lose": away.get("lose"),
                    "away_goals_for": (away.get("goals") or {}).get("for"),
                    "away_goals_against": (away.get("goals") or {}).get("against"),
                })
        return rows

    def _upsert(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0
        with engine.begin() as conn:
            conn.execute(
                text(
                    """
                    ALTER TABLE football.api_football_standings
                    ADD COLUMN IF NOT EXISTS group_name text
                    """
                )
            )
        stmt = text("""
            INSERT INTO football.api_football_standings (
                league_id, season, team_id, team_name, group_name, rank, points, goals_diff, form, status, description,
                all_played, all_win, all_draw, all_lose, all_goals_for, all_goals_against,
                home_played, home_win, home_draw, home_lose, home_goals_for, home_goals_against,
                away_played, away_win, away_draw, away_lose, away_goals_for, away_goals_against,
                updated_dttm
            )
            VALUES (
                :league_id, :season, :team_id, :team_name, :group_name, :rank, :points, :goals_diff, :form, :status, :description,
                :all_played, :all_win, :all_draw, :all_lose, :all_goals_for, :all_goals_against,
                :home_played, :home_win, :home_draw, :home_lose, :home_goals_for, :home_goals_against,
                :away_played, :away_win, :away_draw, :away_lose, :away_goals_for, :away_goals_against,
                now()
            )
            ON CONFLICT (league_id, season, team_id) DO UPDATE SET
                team_name          = EXCLUDED.team_name,
                group_name         = EXCLUDED.group_name,
                rank               = EXCLUDED.rank,
                points             = EXCLUDED.points,
                goals_diff         = EXCLUDED.goals_diff,
                form               = EXCLUDED.form,
                status             = EXCLUDED.status,
                description        = EXCLUDED.description,
                all_played         = EXCLUDED.all_played,
                all_win            = EXCLUDED.all_win,
                all_draw           = EXCLUDED.all_draw,
                all_lose           = EXCLUDED.all_lose,
                all_goals_for      = EXCLUDED.all_goals_for,
                all_goals_against  = EXCLUDED.all_goals_against,
                home_played        = EXCLUDED.home_played,
                home_win           = EXCLUDED.home_win,
                home_draw          = EXCLUDED.home_draw,
                home_lose          = EXCLUDED.home_lose,
                home_goals_for     = EXCLUDED.home_goals_for,
                home_goals_against = EXCLUDED.home_goals_against,
                away_played        = EXCLUDED.away_played,
                away_win           = EXCLUDED.away_win,
                away_draw          = EXCLUDED.away_draw,
                away_lose          = EXCLUDED.away_lose,
                away_goals_for     = EXCLUDED.away_goals_for,
                away_goals_against = EXCLUDED.away_goals_against,
                updated_dttm       = now()
        """)
        with engine.begin() as conn:
            conn.execute(stmt, rows)
        return len(rows)

    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine  = _engine(self.postgres_conn_id)

        pairs = self._pick_pairs_by_updated(engine)  # [(league_id, season), ...]
        if not pairs:
            self.log.info("Нет лиг/сезонов новее standings (по updated_dttm, буфер %s мин).", self.min_staleness_minutes)
            print(f"=== API requests used: total={self.req_total}, success={self.req_success}, errors={self.req_errors} ===")
            return {"updated_pairs": [], "rows_written": 0,
                    "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

        session = self._session(api_key)

        total_rows = 0
        report: List[Dict[str, Any]] = []

        for lg, ssn in pairs:
            resp, err = self._api_get_standings(session, lg, ssn)
            time.sleep(self.throttle_sec)

            rows = self._parse_payload(lg, ssn, resp)
            written = self._upsert(engine, rows) if rows else 0
            total_rows += written

            report.append({
                "league_id": lg, "season": ssn,
                "teams_in_payload": len(rows),
                "rows_written": written,
                "error": err or "",
            })
            self.log.info("league=%s season=%s -> teams=%s, written=%s, error=%s",
                          lg, ssn, len(rows), written, bool(err))

        if report:
            df_rep = pd.DataFrame(report, columns=["league_id","season","teams_in_payload","rows_written","error"])
            self.log.info("\n" + df_rep.to_string(index=False))

        self.log.info("=== Standings total rows written: %s ===", total_rows)
        self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===",
                      self.req_total, self.req_success, self.req_errors)
        print(f"=== API requests used: total={self.req_total}, success={self.req_success}, errors={self.req_errors} ===")

        return {
            "updated_pairs": pairs,
            "rows_written": total_rows,
            "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors},
            "report": report,
        }
