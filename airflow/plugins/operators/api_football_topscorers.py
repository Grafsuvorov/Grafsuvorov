# operators/api_football_topscorers.py
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


class FetchTopScorersOperator(BaseOperator):
    """
    Обновляет football.api_football_topscorers UPSERT'ом.
    Берём пары (league_id, season), где расписание свежее, чем topscorers + буфер.
    Ключ таблицы: (league_id, season, player_id).
    """

    template_fields = ("min_staleness_minutes", "leagues", "seasons")
    ui_color = "#e3f2fd"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        leagues: Optional[List[int]] = None,
        seasons: Optional[List[int]] = None,
        finished_only: bool = True,
        min_staleness_minutes: int = 10,
        throttle_sec: float = 0.4,
        per_call_retries: int = 3,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id = postgres_conn_id
        self.api_variable_key = api_variable_key
        self.api_host = api_host
        self.leagues = leagues or []
        self.seasons = seasons or []
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
            # если используете прямой ключ API-Sports, можно заменить на "x-apisports-key"
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        })
        retry = Retry(
            total=3, connect=3, read=3, backoff_factor=0.6,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods={"GET"}, raise_on_status=False
        )
        adapter = HTTPAdapter(max_retries=retry, pool_connections=8, pool_maxsize=16)
        s.mount("https://", adapter)
        s.mount("http://", adapter)
        return s

    def _pick_pairs_by_updated(self, engine: Engine) -> List[Tuple[int, int]]:
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
                AND (:seasons_empty OR s.season = ANY(:seasons))
              {finished_filter.text}
              GROUP BY s.league_id, s.season
            ),
            ts AS (
              SELECT league_id, season, MAX(updated_dttm) AS ts_last
              FROM football.api_football_topscorers
              GROUP BY league_id, season
            )
            SELECT sc.league_id, sc.season
            FROM sched sc
            LEFT JOIN ts
              ON ts.league_id = sc.league_id AND ts.season = sc.season
            WHERE sc.sched_last >
                  COALESCE(ts.ts_last, to_timestamp(0)) + make_interval(mins => :mins_buf)
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql, conn,
                params={
                    "leagues": self.leagues,
                    "leagues_empty": len(self.leagues) == 0,
                    "seasons": self.seasons,
                    "seasons_empty": len(self.seasons) == 0,
                    "mins_buf": self.min_staleness_minutes,
                }
            )
        return [(int(r.league_id), int(r.season)) for r in df.itertuples(index=False)]

    def _api_get_topscorers(self, session: requests.Session, league_id: int, season: int):
        url = f"{self.api_host}/players/topscorers"
        params = {"league": league_id, "season": season}
        last_err = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_total += 1
            try:
                self.log.info("[topscorers] GET %s lg=%s season=%s attempt=%s", url, league_id, season, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                r.raise_for_status()
                data = r.json() or {}
                resp = data.get("response", []) or []
                self.req_success += 1
                return resp, None
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[topscorers] lg=%s season=%s attempt=%s error: %s", league_id, season, attempt, e)
                time.sleep(2 ** attempt)
        return [], last_err

    @staticmethod
    def _to_float(x) -> Optional[float]:
        try:
            if x is None:
                return None
            v = float(x)
            if pd.isna(v):
                return None
            return v
        except Exception:
            return None

    @classmethod
    def _parse_payload(cls, league_id: int, season: int, response: list) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        for entry in (response or []):
            player = entry.get("player", {}) or {}
            stats  = (entry.get("statistics") or [{}])[0] or {}

            league = stats.get("league", {}) or {}
            team   = stats.get("team", {}) or {}
            games  = stats.get("games", {}) or {}
            shots  = stats.get("shots", {}) or {}
            goals  = stats.get("goals", {}) or {}
            passes = stats.get("passes", {}) or {}
            tackles= stats.get("tackles", {}) or {}
            duels  = stats.get("duels", {}) or {}
            dribbl = stats.get("dribbles", {}) or {}
            fouls  = stats.get("fouls", {}) or {}
            cards  = stats.get("cards", {}) or {}
            pen    = stats.get("penalty", {}) or {}

            rating = cls._to_float(games.get("rating"))

            rows.append({
                "league_id": int(league.get("id") or league_id),
                "season": int(league.get("season") or season),
                "league_name": league.get("name"),
                "league_country": league.get("country"),
                "team_id": team.get("id"),
                "team_name": team.get("name"),
                "player_id": player.get("id"),
                "player_name": player.get("name"),
                "player_age": player.get("age"),
                "player_nationality": player.get("nationality"),
                "appearances": games.get("appearences"),
                "lineups": games.get("lineups"),
                "minutes_played": games.get("minutes"),
                "position": games.get("position"),
                "rating": rating if rating is not None else None,
                "shots_total": shots.get("total"),
                "shots_on": shots.get("on"),
                "goals_total": goals.get("total"),
                "goals_assists": goals.get("assists"),
                "passes_total": passes.get("total"),
                "passes_key": passes.get("key"),
                "tackles_total": tackles.get("total"),
                "tackles_interceptions": tackles.get("interceptions"),
                "duels_total": duels.get("total"),
                "duels_won": duels.get("won"),
                "dribbles_attempts": dribbl.get("attempts"),
                "dribbles_success": dribbl.get("success"),
                "fouls_drawn": fouls.get("drawn"),
                "fouls_committed": fouls.get("committed"),
                "cards_yellow": cards.get("yellow"),
                "cards_red": cards.get("red"),
                "penalties_scored": pen.get("scored"),
                "penalties_missed": pen.get("missed"),
            })
        return rows

    def _upsert(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0

        # ВАЖНО: конфликт по PK (league_id, season, player_id) — как в схеме таблицы
        stmt = text("""
            INSERT INTO football.api_football_topscorers (
                league_id, season, league_name, league_country,
                team_id, team_name,
                player_id, player_name, player_age, player_nationality,
                appearances, lineups, minutes_played, position, rating,
                shots_total, shots_on,
                goals_total, goals_assists,
                passes_total, passes_key,
                tackles_total, tackles_interceptions,
                duels_total, duels_won,
                dribbles_attempts, dribbles_success,
                fouls_drawn, fouls_committed,
                cards_yellow, cards_red,
                penalties_scored, penalties_missed,
                updated_dttm
            )
            VALUES (
                :league_id, :season, :league_name, :league_country,
                :team_id, :team_name,
                :player_id, :player_name, :player_age, :player_nationality,
                :appearances, :lineups, :minutes_played, :position, :rating,
                :shots_total, :shots_on,
                :goals_total, :goals_assists,
                :passes_total, :passes_key,
                :tackles_total, :tackles_interceptions,
                :duels_total, :duels_won,
                :dribbles_attempts, :dribbles_success,
                :fouls_drawn, :fouls_committed,
                :cards_yellow, :cards_red,
                :penalties_scored, :penalties_missed,
                now()
            )
            ON CONFLICT (league_id, season, player_id) DO UPDATE SET
                league_name           = EXCLUDED.league_name,
                league_country        = EXCLUDED.league_country,
                team_id               = EXCLUDED.team_id,
                team_name             = EXCLUDED.team_name,
                player_name           = EXCLUDED.player_name,
                player_age            = EXCLUDED.player_age,
                player_nationality    = EXCLUDED.player_nationality,
                appearances           = EXCLUDED.appearances,
                lineups               = EXCLUDED.lineups,
                minutes_played        = EXCLUDED.minutes_played,
                position              = EXCLUDED.position,
                rating                = EXCLUDED.rating,
                shots_total           = EXCLUDED.shots_total,
                shots_on              = EXCLUDED.shots_on,
                goals_total           = EXCLUDED.goals_total,
                goals_assists         = EXCLUDED.goals_assists,
                passes_total          = EXCLUDED.passes_total,
                passes_key            = EXCLUDED.passes_key,
                tackles_total         = EXCLUDED.tackles_total,
                tackles_interceptions = EXCLUDED.tackles_interceptions,
                duels_total           = EXCLUDED.duels_total,
                duels_won             = EXCLUDED.duels_won,
                dribbles_attempts     = EXCLUDED.dribbles_attempts,
                dribbles_success      = EXCLUDED.dribbles_success,
                fouls_drawn           = EXCLUDED.fouls_drawn,
                fouls_committed       = EXCLUDED.fouls_committed,
                cards_yellow          = EXCLUDED.cards_yellow,
                cards_red             = EXCLUDED.cards_red,
                penalties_scored      = EXCLUDED.penalties_scored,
                penalties_missed      = EXCLUDED.penalties_missed,
                updated_dttm          = now()
        """)
        with engine.begin() as conn:
            conn.execute(stmt, rows)
        return len(rows)

    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine  = _engine(self.postgres_conn_id)

        pairs = self._pick_pairs_by_updated(engine)
        if not pairs:
            self.log.info("Нет пар (league, season) свежее topscorers (buffer %s min).", self.min_staleness_minutes)
            self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===",
                          self.req_total, self.req_success, self.req_errors)
            return {"updated_pairs": [], "rows_written": 0,
                    "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors}}

        session = self._session(api_key)

        total_rows = 0
        report: List[Dict[str, Any]] = []

        for lg, ssn in pairs:
            resp, err = self._api_get_topscorers(session, lg, ssn)
            time.sleep(self.throttle_sec)

            rows = self._parse_payload(lg, ssn, resp)
            written = self._upsert(engine, rows) if rows else 0
            total_rows += written

            report.append({
                "league_id": lg, "season": ssn,
                "players_in_payload": len(rows),
                "rows_written": written,
                "error": err or "",
            })
            self.log.info("league=%s season=%s -> players=%s, written=%s, error=%s",
                          lg, ssn, len(rows), written, bool(err))

        if report:
            df_rep = pd.DataFrame(report, columns=["league_id","season","players_in_payload","rows_written","error"])
            self.log.info("\n" + df_rep.to_string(index=False))

        self.log.info("=== Topscorers total rows written: %s ===", total_rows)
        self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===",
                      self.req_total, self.req_success, self.req_errors)

        return {
            "updated_pairs": pairs,
            "rows_written": total_rows,
            "requests": {"total": self.req_total, "success": self.req_success, "errors": self.req_errors},
            "report": report,
        }
