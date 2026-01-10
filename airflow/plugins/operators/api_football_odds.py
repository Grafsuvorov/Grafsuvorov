# D:\airflow\plugins\operators\api_football_odds.py
from __future__ import annotations

import json
import time
from typing import List, Dict, Any, Optional, Iterable

import requests
import pandas as pd
from airflow.models import BaseOperator, Variable
from airflow.utils.context import Context
from airflow.hooks.base import BaseHook
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from sqlalchemy import text
from sqlalchemy.engine import Engine, create_engine


# ========= utils =========
def _chunked(iterable: Iterable, size: int):
    buf = []
    for x in iterable:
        buf.append(x)
        if len(buf) >= size:
            yield buf
            buf = []
    if buf:
        yield buf


def _create_engine_from_conn_id(conn_id: str) -> Engine:
    c = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{c.login}:{c.password}@{c.host}:{c.port}/{c.schema}"
    return create_engine(uri, pool_pre_ping=True)


# ========= logging to football.etl_task_logs =========
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
                 :target_table, :operation, current_setting('HOSTNAME', true), null, :extra)
                RETURNING id
            """),
            {
                "dag_id": dag_id,
                "task_id": task_id,
                "run_id": run_id,
                "try_number": try_number,
                "target_table": target_table,
                "operation": operation,
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


# ========= parsers =========
def parse_bet1_match_winner(items) -> Dict[str, Dict[str, Optional[float]]]:
    out: Dict[str, Dict[str, Optional[float]]] = {}
    for it in items:
        for bm in it.get("bookmakers", []):
            name = bm.get("name")
            for bet in bm.get("bets", []):
                if bet.get("id") != 1:
                    continue
                rec = out.setdefault(name, {"home": None, "draw": None, "away": None})
                for v in bet.get("values", []):
                    val = (v.get("value") or "").strip().lower()
                    try:
                        oddf = float(v.get("odd"))
                    except (TypeError, ValueError):
                        continue
                    if val == "home":
                        rec["home"] = oddf
                    elif val == "draw":
                        rec["draw"] = oddf
                    elif val == "away":
                        rec["away"] = oddf
    return out


def parse_bet5_totals_ou25(items) -> Dict[str, Dict[str, Optional[float]]]:
    out: Dict[str, Dict[str, Optional[float]]] = {}
    for it in items:
        for bm in it.get("bookmakers", []):
            name = bm.get("name")
            for bet in bm.get("bets", []):
                if bet.get("id") != 5:
                    continue
                rec = out.setdefault(name, {"over25": None, "under25": None})
                for v in bet.get("values", []):
                    val = (v.get("value") or "").strip().lower()
                    try:
                        oddf = float(v.get("odd"))
                    except (TypeError, ValueError):
                        continue
                    if val == "over 2.5":
                        rec["over25"] = oddf
                    elif val == "under 2.5":
                        rec["under25"] = oddf
    return out


def choose_top_bookmakers(mw: dict, tt: dict, top_n: int) -> List[str]:
    all_bk = set(mw.keys()) | set(tt.keys())
    def score(b: str) -> int:
        return sum(v is not None for v in [
            mw.get(b, {}).get("home"),
            mw.get(b, {}).get("draw"),
            mw.get(b, {}).get("away"),
            tt.get(b, {}).get("over25"),
            tt.get(b, {}).get("under25"),
        ])
    return sorted(all_bk, key=lambda b: (-score(b), b.lower()))[:top_n]


# ========= Operator =========
class FetchOddsOperator(BaseOperator):
    """
    Тянет коэффициенты (1X2 и Over/Under 2.5) для ближайших матчей сезона,
    которых ещё нет в football.match_odds (или < min_bookmakers на матч).
    Корректно обрабатывает отсутствие коэффициентов и сетевые ошибки.
    В конце печатает общий счётчик API-запросов.
    """

    template_fields = ("season", "leagues", "lookahead_days", "lookback_days")

    ui_color = "#fff3e0"

    def __init__(
        self,
        postgres_conn_id: str = "dwh_postgres",
        api_variable_key: str = "API_FOOTBALL_KEY",
        api_host: str = "https://v3.football.api-sports.io",
        season: int = 2025,
        leagues: Optional[List[int]] = None,
        lookahead_days: int = 7,       # сегодня..+7
        lookback_days: int = 0,        # иногда 1 — на переносы
        min_bookmakers: int = 3,       # если уже >=3 буков — матч не берём
        top_n_bookmakers: int = 5,
        throttle_sec: float = 0.5,     # пауза между вызовами
        per_call_retries: int = 3,     # локальные ретраи на запрос odds
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.postgres_conn_id   = postgres_conn_id
        self.api_variable_key   = api_variable_key
        self.api_host           = api_host
        self.season             = season
        self.leagues            = leagues or []
        self.lookahead_days     = lookahead_days
        self.lookback_days      = lookback_days
        self.min_bookmakers     = min_bookmakers
        self.top_n_bookmakers   = top_n_bookmakers
        self.throttle_sec       = throttle_sec
        self.per_call_retries   = per_call_retries

        # счётчики запросов
        self.req_count   = 0
        self.req_success = 0
        self.req_errors  = 0

    # --- HTTP session с ретраями и Connection: close ---
    def _make_session(self, api_key: str) -> requests.Session:
        s = requests.Session()
        # Если ключ от RapidAPI — оставляй x-rapidapi-key. Если прямой API-Sports, меняй на x-apisports-key.
        s.headers.update({
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        })
        retry = Retry(
            total=3,
            connect=3,
            read=3,
            backoff_factor=0.6,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods={"GET"},
            raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry, pool_connections=16, pool_maxsize=32)
        s.mount("https://", adapter)
        s.mount("http://", adapter)
        return s

    # --- HTTP odds с локальными ретраями и учётом счётчика ---
    def _api_get_odds(self, session: requests.Session, fixture_id: int, league_id: int, bet_id: int):
        params = {"season": self.season, "fixture": fixture_id, "league": league_id, "bet": bet_id}
        url = f"{self.api_host}/odds"

        last_err: Optional[str] = None
        for attempt in range(1, self.per_call_retries + 1):
            self.req_count += 1
            try:
                self.log.info("[odds] GET %s bet=%s fx=%s lg=%s (attempt=%s)", url, bet_id, fixture_id, league_id, attempt)
                r = session.get(url, params=params, timeout=(5, 45))
                # 200/204/404/… — не считаем ошибкой сети, просто разбираем payload
                r.raise_for_status()
                payload = r.json() or {}
                resp = payload.get("response", []) or []
                self.req_success += 1
                return resp, None  # None = без ошибки
            except requests.RequestException as e:
                self.req_errors += 1
                last_err = f"{type(e).__name__}: {e}"
                self.log.warning("[odds] fx=%s lg=%s bet=%s attempt=%s error: %s",
                                 fixture_id, league_id, bet_id, attempt, e)
                time.sleep(2 ** attempt)  # backoff: 2s, 4s, 8s

        # все попытки исчерпаны
        return [], last_err

    # --- кандидаты (окно дат, покрытие по букам) ---
    def _load_candidates(self, engine: Engine) -> pd.DataFrame:
        sql = text("""
            WITH windowed AS (
                SELECT
                    s.fixture_id,
                    s.league_id,
                    s.league_name,
                    s.season,
                    s.date::timestamp AT TIME ZONE 'UTC' AS match_utc,
                    s.home_team_id,
                    s.away_team_id,
                    s.home_team AS home_team_name,
                    s.away_team AS away_team_name
                FROM football.api_football_schedule s
                WHERE s.season = :season
                  AND s.league_id = ANY(:leagues)
                  AND s.date::date BETWEEN (current_date - :lookback) AND (current_date + :lookahead)
            ),
            coverage AS (
                SELECT
                    mo.game_id,
                    COUNT(DISTINCT mo.bookmaker) AS bk_cnt
                FROM football.match_odds mo
                GROUP BY mo.game_id
            )
            SELECT
                w.fixture_id,
                w.league_id,
                w.league_name,
                w.match_utc,
                w.home_team_id,
                w.away_team_id,
                w.home_team_name,
                w.away_team_name,
                COALESCE(c.bk_cnt, 0) AS bk_cnt
            FROM windowed w
            LEFT JOIN coverage c ON c.game_id = cast(w.fixture_id as varchar)
            WHERE COALESCE(c.bk_cnt, 0) < :min_bookmakers
            ORDER BY w.match_utc, w.fixture_id
        """)
        with engine.connect() as conn:
            df = pd.read_sql(
                sql,
                conn,
                params={
                    "season": self.season,
                    "leagues": self.leagues,
                    "lookback": self.lookback_days,
                    "lookahead": self.lookahead_days,
                    "min_bookmakers": self.min_bookmakers,
                },
            )
        return df

    # --- UPSERT в football.match_odds ---
    def _upsert_odds(self, engine: Engine, rows: List[Dict[str, Any]]) -> int:
        if not rows:
            return 0
        stmt = text("""
            INSERT INTO football.match_odds (
                game_id, date, home_team, away_team,
                bookmaker, odds_home_win, odds_draw, odds_away_win,
                odds_over_25, odds_under_25, league, home_team_id, away_team_id
            )
            VALUES (
                :game_id, :date, :home_team, :away_team,
                :bookmaker, :odds_home_win, :odds_draw, :odds_away_win,
                :odds_over_25, :odds_under_25, :league, :home_team_id, :away_team_id
            )
            ON CONFLICT (game_id, bookmaker) DO UPDATE SET
                odds_home_win = COALESCE(EXCLUDED.odds_home_win, football.match_odds.odds_home_win),
                odds_draw     = COALESCE(EXCLUDED.odds_draw,     football.match_odds.odds_draw),
                odds_away_win = COALESCE(EXCLUDED.odds_away_win, football.match_odds.odds_away_win),
                odds_over_25  = COALESCE(EXCLUDED.odds_over_25,  football.match_odds.odds_over_25),
                odds_under_25 = COALESCE(EXCLUDED.odds_under_25, football.match_odds.odds_under_25),
                inserted_dttm = now()
        """)
        # локальный дедуп
        dedup = {}
        for r in rows:
            dedup[(r["game_id"], r["bookmaker"])] = r
        rows = list(dedup.values())
        with engine.begin() as conn:
            conn.execute(stmt, rows)
        return len(rows)

    def execute(self, context: Context):
        api_key = Variable.get(self.api_variable_key)
        engine  = _create_engine_from_conn_id(self.postgres_conn_id)

        dag_id   = context["dag"].dag_id if context.get("dag") else "unknown_dag"
        task_id  = context["task"].task_id if context.get("task") else self.task_id
        run_id   = context.get("run_id")
        try_num  = getattr(context.get("ti"), "try_number", 1)

        log_id = log_start(
            engine, dag_id, task_id, run_id, try_num,
            target_table="football.match_odds", operation="upsert",
            extra={"season": self.season, "leagues": self.leagues,
                   "lookahead_days": self.lookahead_days, "min_bookmakers": self.min_bookmakers}
        )

        total_rows = 0
        total_matches = 0
        report_rows: List[Dict[str, Any]] = []

        session = self._make_session(api_key)

        try:
            df = self._load_candidates(engine)
            total_matches = len(df)
            self.log.info("Кандидатов на загрузку коэффициентов: %s", total_matches)

            for _, row in df.iterrows():
                fx = int(row["fixture_id"])
                lg = int(row["league_id"])
                league_name = row["league_name"] or ""
                dt = pd.to_datetime(row["match_utc"]).date()
                home_name = (row["home_team_name"] or "").strip() or str(row["home_team_id"])
                away_name = (row["away_team_name"] or "").strip() or str(row["away_team_id"])
                home_id   = int(row["home_team_id"])
                away_id   = int(row["away_team_id"])

                # 1) 1X2
                items_1, err_1 = self._api_get_odds(session, fx, lg, bet_id=1)
                time.sleep(self.throttle_sec)

                # 2) Totals 2.5
                items_5, err_5 = self._api_get_odds(session, fx, lg, bet_id=5)
                time.sleep(self.throttle_sec)

                mw = parse_bet1_match_winner(items_1)
                tt = parse_bet5_totals_ou25(items_5)

                top_bk = choose_top_bookmakers(mw, tt, self.top_n_bookmakers)

                rows_to_write: List[Dict[str, Any]] = []
                for bk in top_bk:
                    r = {
                        "game_id": fx,
                        "date": dt,
                        "home_team": home_name,
                        "away_team": away_name,
                        "bookmaker": bk,
                        "odds_home_win": mw.get(bk, {}).get("home"),
                        "odds_draw":     mw.get(bk, {}).get("draw"),
                        "odds_away_win": mw.get(bk, {}).get("away"),
                        "odds_over_25":  tt.get(bk, {}).get("over25"),
                        "odds_under_25": tt.get(bk, {}).get("under25"),
                        "league": league_name,
                        "home_team_id": home_id,
                        "away_team_id": away_id,
                    }
                    # если у бука вообще пусто — пропускаем
                    if all(r[k] is None for k in ("odds_home_win","odds_draw","odds_away_win","odds_over_25","odds_under_25")):
                        continue
                    rows_to_write.append(r)

                inserted = self._upsert_odds(engine, rows_to_write) if rows_to_write else 0
                total_rows += inserted

                report_rows.append({
                    "fixture_id": fx,
                    "league_id": lg,
                    "date": str(dt),
                    "home": home_name,
                    "away": away_name,
                    "bk_found_total": len(set(mw.keys()) | set(tt.keys())),
                    "bk_written": inserted,
                    "bet1_err": err_1 or "",
                    "bet5_err": err_5 or "",
                    "has_any_odds": bool(rows_to_write),
                })

                self.log.info(
                    "fx=%s: bk_total=%s, top_used=%s, written=%s (bet1_err=%s; bet5_err=%s)",
                    fx, len(set(mw.keys())|set(tt.keys())), len(top_bk), inserted, bool(err_1), bool(err_5)
                )

            # напечатаем полный список (таблицей)
            if report_rows:
                rep_df = pd.DataFrame(report_rows, columns=[
                    "fixture_id","league_id","date","home","away",
                    "bk_found_total","bk_written","has_any_odds","bet1_err","bet5_err"
                ])
                self.log.info("\n" + rep_df.to_string(index=False))

            # финальные логи
            self.log.info("=== Итог: обработано матчей=%s, записано строк=%s ===", total_matches, total_rows)
            self.log.info("=== API requests used: total=%s, success=%s, errors=%s ===",
                          self.req_count, self.req_success, self.req_errors)
            # прямой print — по просьбе: будет в логах таска
            print(f"=== API requests used: total={self.req_count}, success={self.req_success}, errors={self.req_errors} ===")

            log_finish(
                engine, log_id, status="success",
                rows_read=total_matches, rows_inserted=total_rows, rows_updated=0,
                extra={
                    "matches": total_matches,
                    "rows_written": total_rows,
                    "req_total": self.req_count,
                    "req_success": self.req_success,
                    "req_errors": self.req_errors,
                }
            )
            # вернём XCom с отчётом
            return {
                "matches": total_matches,
                "rows_written": total_rows,
                "requests": {
                    "total": self.req_count, "success": self.req_success, "errors": self.req_errors
                },
                "report": report_rows,
            }

        except Exception as e:
            self.log.error("Task failed: %s", e)
            # тоже печатаем счётчик, чтобы видеть даже при падении
            print(f"=== API requests used (before fail): total={self.req_count}, success={self.req_success}, errors={self.req_errors} ===")
            log_finish(
                engine, log_id, status="failed",
                rows_read=total_matches, rows_inserted=total_rows, rows_updated=0,
                error_type=type(e).__name__, error_message=str(e),
                extra={"req_total": self.req_count, "req_success": self.req_success, "req_errors": self.req_errors}
            )
            raise
