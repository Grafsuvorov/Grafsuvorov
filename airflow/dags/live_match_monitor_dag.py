from __future__ import annotations

from datetime import datetime
import time
from typing import Any, Dict, Iterable, List

import requests
from airflow import DAG
from airflow.decorators import task
from airflow.hooks.base import BaseHook
from airflow.models import Variable
from airflow.operators.empty import EmptyOperator
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine


LEAGUES = [144, 61, 78, 203, 2, 3, 88, 140, 135, 39, 94, 1, 4, 29, 30, 31, 32, 33, 34, 37]
SEASON = 2025
API_HOST = "https://v3.football.api-sports.io"
API_POOL = "api_football_pool"
PREMATCH_LINEUPS_MINUTES = 75


def _engine(conn_id: str = "dwh_postgres") -> Engine:
    conn = BaseHook.get_connection(conn_id)
    uri = f"postgresql+psycopg2://{conn.login}:{conn.password}@{conn.host}:{conn.port}/{conn.schema}"
    return create_engine(uri, pool_pre_ping=True)


def _session(api_key: str) -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        }
    )
    return session


def _chunked(rows: Iterable[dict], size: int):
    batch: List[dict] = []
    for row in rows:
        batch.append(row)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch


def _safe_int(value: Any):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except Exception:
        return None


def _safe_float(value: Any):
    if value in (None, ""):
        return None
    if isinstance(value, str) and value.endswith("%"):
        value = value[:-1]
    try:
        return float(value)
    except Exception:
        return None


def _api_get(session: requests.Session, path: str, params: Dict[str, Any]) -> list[dict]:
    response = session.get(f"{API_HOST}{path}", params=params, timeout=(5, 45))
    response.raise_for_status()
    payload = response.json() or {}
    return payload.get("response", []) or []


def _ensure_schedule_live_columns(engine: Engine) -> None:
    sql = text(
        """
        ALTER TABLE football.api_football_schedule
            ADD COLUMN IF NOT EXISTS status_short text,
            ADD COLUMN IF NOT EXISTS elapsed integer
        """
    )
    with engine.begin() as conn:
        conn.execute(sql)


def _upsert_live_schedule(engine: Engine, payload: list[dict]) -> int:
    if not payload:
        return 0

    rows = []
    for item in payload:
        fixture = item.get("fixture") or {}
        league = item.get("league") or {}
        teams = item.get("teams") or {}
        goals = item.get("goals") or {}
        score = item.get("score") or {}
        venue = fixture.get("venue") or {}
        status = fixture.get("status") or {}
        rows.append(
            {
                "fixture_id": fixture.get("id"),
                "date": fixture.get("date"),
                "timestamp": fixture.get("timestamp"),
                "timezone": fixture.get("timezone"),
                "venue_name": venue.get("name"),
                "venue_city": venue.get("city"),
                "referee": fixture.get("referee"),
                "status": status.get("long"),
                "status_short": status.get("short"),
                "elapsed": _safe_int(status.get("elapsed")),
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
            }
        )

    sql = text(
        """
        INSERT INTO football.api_football_schedule (
            fixture_id, date, timestamp, timezone, venue_name, venue_city, referee, status, status_short, elapsed,
            round, league_id, league_name, league_country, season,
            home_team_id, home_team, home_team_winner,
            away_team_id, away_team, away_team_winner,
            home_goals, away_goals,
            score_halftime_home, score_halftime_away,
            score_fulltime_home, score_fulltime_away,
            score_penalty_home, score_penalty_away
        ) VALUES (
            :fixture_id, :date, :timestamp, :timezone, :venue_name, :venue_city, :referee, :status, :status_short, :elapsed,
            :round, :league_id, :league_name, :league_country, :season,
            :home_team_id, :home_team, :home_team_winner,
            :away_team_id, :away_team, :away_team_winner,
            :home_goals, :away_goals,
            :score_halftime_home, :score_halftime_away,
            :score_fulltime_home, :score_fulltime_away,
            :score_penalty_home, :score_penalty_away
        )
        ON CONFLICT (fixture_id) DO UPDATE SET
            date = EXCLUDED.date,
            timestamp = EXCLUDED.timestamp,
            timezone = EXCLUDED.timezone,
            venue_name = COALESCE(EXCLUDED.venue_name, football.api_football_schedule.venue_name),
            venue_city = COALESCE(EXCLUDED.venue_city, football.api_football_schedule.venue_city),
            referee = COALESCE(EXCLUDED.referee, football.api_football_schedule.referee),
            status = COALESCE(EXCLUDED.status, football.api_football_schedule.status),
            status_short = COALESCE(EXCLUDED.status_short, football.api_football_schedule.status_short),
            elapsed = COALESCE(EXCLUDED.elapsed, football.api_football_schedule.elapsed),
            round = COALESCE(EXCLUDED.round, football.api_football_schedule.round),
            league_id = COALESCE(EXCLUDED.league_id, football.api_football_schedule.league_id),
            league_name = COALESCE(EXCLUDED.league_name, football.api_football_schedule.league_name),
            league_country = COALESCE(EXCLUDED.league_country, football.api_football_schedule.league_country),
            season = COALESCE(EXCLUDED.season, football.api_football_schedule.season),
            home_team_id = COALESCE(EXCLUDED.home_team_id, football.api_football_schedule.home_team_id),
            home_team = COALESCE(EXCLUDED.home_team, football.api_football_schedule.home_team),
            home_team_winner = COALESCE(EXCLUDED.home_team_winner, football.api_football_schedule.home_team_winner),
            away_team_id = COALESCE(EXCLUDED.away_team_id, football.api_football_schedule.away_team_id),
            away_team = COALESCE(EXCLUDED.away_team, football.api_football_schedule.away_team),
            away_team_winner = COALESCE(EXCLUDED.away_team_winner, football.api_football_schedule.away_team_winner),
            home_goals = COALESCE(EXCLUDED.home_goals, football.api_football_schedule.home_goals),
            away_goals = COALESCE(EXCLUDED.away_goals, football.api_football_schedule.away_goals),
            score_halftime_home = COALESCE(EXCLUDED.score_halftime_home, football.api_football_schedule.score_halftime_home),
            score_halftime_away = COALESCE(EXCLUDED.score_halftime_away, football.api_football_schedule.score_halftime_away),
            score_fulltime_home = COALESCE(EXCLUDED.score_fulltime_home, football.api_football_schedule.score_fulltime_home),
            score_fulltime_away = COALESCE(EXCLUDED.score_fulltime_away, football.api_football_schedule.score_fulltime_away),
            score_penalty_home = COALESCE(EXCLUDED.score_penalty_home, football.api_football_schedule.score_penalty_home),
            score_penalty_away = COALESCE(EXCLUDED.score_penalty_away, football.api_football_schedule.score_penalty_away),
            updated_dttm = now()
        """
    )
    written = 0
    with engine.begin() as conn:
        for chunk in _chunked(rows, 500):
            conn.execute(sql, chunk)
            written += len(chunk)
    return written


def _pick_soon_without_lineups(engine: Engine) -> List[Dict[str, int]]:
    sql = text(
        """
        SELECT
            s.fixture_id,
            s.league_id
        FROM football.api_football_schedule s
        WHERE s.season = :season
          AND s.league_id = ANY(:leagues)
          AND s.fixture_id IS NOT NULL
          AND s.date >= now() - interval '20 minutes'
          AND s.date <= now() + make_interval(mins => :ahead_mins)
          AND NOT (
                s.status ILIKE '%Match Finished%'
             OR s.status ILIKE '%Full Time%'
             OR s.status ILIKE '%FT%'
             OR s.status ILIKE '%AET%'
             OR s.status ILIKE '%PEN%'
          )
          AND NOT EXISTS (
                SELECT 1
                FROM football.api_football_lineups l
                WHERE l.fixture_id = s.fixture_id
          )
        GROUP BY s.fixture_id, s.league_id
        ORDER BY MIN(s.date), s.fixture_id
        """
    )
    with engine.begin() as conn:
        rows = conn.execute(
            sql,
            {
                "season": SEASON,
                "leagues": LEAGUES,
                "ahead_mins": PREMATCH_LINEUPS_MINUTES,
            },
        ).fetchall()
    return [{"fixture_id": int(r[0]), "league_id": int(r[1])} for r in rows]


def _upsert_lineups(engine: Engine, rows: List[Dict[str, Any]]) -> int:
    if not rows:
        return 0
    sql = text(
        """
        INSERT INTO football.api_football_lineups (
            fixture_id, team_id, team_name, coach_id, coach_name, formation,
            player_id, player_name, number, position, grid, is_starting, updated_dttm
        ) VALUES (
            :fixture_id, :team_id, :team_name, :coach_id, :coach_name, :formation,
            :player_id, :player_name, :number, :position, :grid, :is_starting, now()
        )
        ON CONFLICT (fixture_id, team_id, player_id) DO UPDATE SET
            team_name = EXCLUDED.team_name,
            coach_id = EXCLUDED.coach_id,
            coach_name = EXCLUDED.coach_name,
            formation = EXCLUDED.formation,
            player_name = EXCLUDED.player_name,
            number = EXCLUDED.number,
            position = EXCLUDED.position,
            grid = EXCLUDED.grid,
            is_starting = EXCLUDED.is_starting,
            updated_dttm = now()
        """
    )
    written = 0
    with engine.begin() as conn:
        for chunk in _chunked(rows, 1000):
            conn.execute(sql, chunk)
            written += len(chunk)
    return written


def _parse_lineups(fixture_id: int, payload: list[dict]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for team in payload:
        team_id = (team.get("team") or {}).get("id")
        team_name = (team.get("team") or {}).get("name")
        coach_id = (team.get("coach") or {}).get("id")
        coach_name = (team.get("coach") or {}).get("name")
        formation = team.get("formation")
        for side_key, is_starting in (("startXI", True), ("substitutes", False)):
            for player in team.get(side_key, []) or []:
                info = player.get("player") or {}
                rows.append(
                    {
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
                        "is_starting": is_starting,
                    }
                )
    return rows


def _parse_stats(fixture_id: int, payload: list[dict]) -> List[Dict[str, Any]]:
    mapping = {
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
    rows: List[Dict[str, Any]] = []
    for team_data in payload:
        team = team_data.get("team") or {}
        record = {
            "fixture_id": fixture_id,
            "team_id": team.get("id"),
            "team_name": team.get("name"),
            "shots_on_goal": None,
            "total_shots": None,
            "shots_off_goal": None,
            "shots_insidebox": None,
            "shots_outsidebox": None,
            "blocked_shots": None,
            "possession": None,
            "passes": None,
            "passes_accurate": None,
            "passes_percentage": None,
            "fouls": None,
            "corners": None,
            "offsides": None,
            "yellow_cards": None,
            "red_cards": None,
            "saves": None,
            "tackles": None,
            "attacks": None,
            "dangerous_attacks": None,
            "expected_goals": None,
            "goals_prevented": None,
        }
        for stat in team_data.get("statistics", []) or []:
            key = mapping.get(stat.get("type"))
            if key:
                record[key] = _safe_float(stat.get("value"))
        rows.append(record)
    return rows


def _upsert_stats(engine: Engine, rows: List[Dict[str, Any]]) -> int:
    if not rows:
        return 0
    sql = text(
        """
        INSERT INTO football.api_football_match_stats (
            fixture_id, team_id, team_name,
            shots_on_goal, total_shots, shots_off_goal,
            shots_insidebox, shots_outsidebox, blocked_shots,
            possession, passes, passes_accurate, passes_percentage,
            fouls, corners, offsides, yellow_cards, red_cards,
            saves, tackles, attacks, dangerous_attacks,
            expected_goals, goals_prevented
        ) VALUES (
            :fixture_id, :team_id, :team_name,
            :shots_on_goal, :total_shots, :shots_off_goal,
            :shots_insidebox, :shots_outsidebox, :blocked_shots,
            :possession, :passes, :passes_accurate, :passes_percentage,
            :fouls, :corners, :offsides, :yellow_cards, :red_cards,
            :saves, :tackles, :attacks, :dangerous_attacks,
            :expected_goals, :goals_prevented
        )
        ON CONFLICT (fixture_id, team_id) DO UPDATE SET
            team_name = EXCLUDED.team_name,
            shots_on_goal = EXCLUDED.shots_on_goal,
            total_shots = EXCLUDED.total_shots,
            shots_off_goal = EXCLUDED.shots_off_goal,
            shots_insidebox = EXCLUDED.shots_insidebox,
            shots_outsidebox = EXCLUDED.shots_outsidebox,
            blocked_shots = EXCLUDED.blocked_shots,
            possession = EXCLUDED.possession,
            passes = EXCLUDED.passes,
            passes_accurate = EXCLUDED.passes_accurate,
            passes_percentage = EXCLUDED.passes_percentage,
            fouls = EXCLUDED.fouls,
            corners = EXCLUDED.corners,
            offsides = EXCLUDED.offsides,
            yellow_cards = EXCLUDED.yellow_cards,
            red_cards = EXCLUDED.red_cards,
            saves = EXCLUDED.saves,
            tackles = EXCLUDED.tackles,
            attacks = EXCLUDED.attacks,
            dangerous_attacks = EXCLUDED.dangerous_attacks,
            expected_goals = EXCLUDED.expected_goals,
            goals_prevented = EXCLUDED.goals_prevented
        """
    )
    written = 0
    with engine.begin() as conn:
        for chunk in _chunked(rows, 1000):
            conn.execute(sql, chunk)
            written += len(chunk)
    return written


def _parse_events(fixture_id: int, payload: list[dict]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for event in payload:
        team = event.get("team") or {}
        player = event.get("player") or {}
        assist = event.get("assist") or {}
        tm = event.get("time") or {}
        rows.append(
            {
                "fixture_id": fixture_id,
                "team_id": _safe_int(team.get("id")),
                "team_name": str(team.get("name") or "")[:120] or None,
                "player_id": _safe_int(player.get("id")),
                "player_name": str(player.get("name") or "")[:120] or None,
                "assist_id": _safe_int(assist.get("id")),
                "assist_name": str(assist.get("name") or "")[:120] or None,
                "type": str(event.get("type") or "")[:50] or None,
                "detail": str(event.get("detail") or "")[:120] or None,
                "comments": str(event.get("comments") or "")[:200] or None,
                "elapsed": _safe_int(tm.get("elapsed")),
                "extra": _safe_int(tm.get("extra")),
            }
        )
    return rows


def _replace_events(engine: Engine, fixture_id: int, rows: List[Dict[str, Any]]) -> int:
    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM football.api_football_match_events WHERE fixture_id = :fixture_id"),
            {"fixture_id": fixture_id},
        )
        if not rows:
            return 0
        sql = text(
            """
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
            """
        )
        inserted = 0
        for chunk in _chunked(rows, 500):
            conn.execute(sql, chunk)
            inserted += len(chunk)
        return inserted


with DAG(
    dag_id="live_match_monitor",
    start_date=datetime(2026, 3, 22),
    schedule_interval="*/5 * * * *",
    catchup=False,
    max_active_runs=1,
    tags=["football", "live", "lineups", "events", "stats"],
) as dag:
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    @task(pool=API_POOL)
    def discover_watchlist() -> Dict[str, Any]:
        api_key = Variable.get("API_FOOTBALL_KEY")
        engine = _engine()
        _ensure_schedule_live_columns(engine)
        session = _session(api_key)

        live_payload = _api_get(session, "/fixtures", {"live": "all"})
        live_payload = [
            item
            for item in live_payload
            if int((item.get("league") or {}).get("id") or 0) in LEAGUES
        ]
        _upsert_live_schedule(engine, live_payload)

        live_ids = sorted(
            {
                int((item.get("fixture") or {}).get("id"))
                for item in live_payload
                if (item.get("fixture") or {}).get("id") is not None
            }
        )
        soon_rows = _pick_soon_without_lineups(engine)
        soon_ids = sorted({int(item["fixture_id"]) for item in soon_rows if item.get("fixture_id")})

        return {
            "live_fixture_ids": live_ids,
            "soon_lineup_fixture_ids": soon_ids,
            "api_requests": 1,
            "live_count": len(live_ids),
            "soon_count": len(soon_ids),
        }

    @task(pool=API_POOL)
    def fetch_pre_match_lineups(watchlist: Dict[str, Any]) -> Dict[str, int]:
        fixture_ids = sorted(
            {
                int(fx)
                for fx in (watchlist.get("live_fixture_ids") or []) + (watchlist.get("soon_lineup_fixture_ids") or [])
            }
        )
        if not fixture_ids:
            return {"fixtures": 0, "rows_written": 0, "api_requests": 0}

        api_key = Variable.get("API_FOOTBALL_KEY")
        engine = _engine()
        session = _session(api_key)
        req = 0
        rows: List[Dict[str, Any]] = []

        for fixture_id in fixture_ids:
            payload = _api_get(session, "/fixtures/lineups", {"fixture": fixture_id})
            req += 1
            rows.extend(_parse_lineups(fixture_id, payload))
            time.sleep(0.4)

        written = _upsert_lineups(engine, rows)
        return {"fixtures": len(fixture_ids), "rows_written": written, "api_requests": req}

    @task(pool=API_POOL)
    def refresh_live_stats(watchlist: Dict[str, Any]) -> Dict[str, int]:
        fixture_ids = [int(fx) for fx in (watchlist.get("live_fixture_ids") or [])]
        if not fixture_ids:
            return {"fixtures": 0, "rows_written": 0, "api_requests": 0}

        api_key = Variable.get("API_FOOTBALL_KEY")
        engine = _engine()
        session = _session(api_key)
        req = 0
        rows: List[Dict[str, Any]] = []

        for fixture_id in fixture_ids:
            payload = _api_get(session, "/fixtures/statistics", {"fixture": fixture_id})
            req += 1
            rows.extend(_parse_stats(fixture_id, payload))
            time.sleep(0.4)

        written = _upsert_stats(engine, rows)
        return {"fixtures": len(fixture_ids), "rows_written": written, "api_requests": req}

    @task(pool=API_POOL)
    def refresh_live_events(watchlist: Dict[str, Any]) -> Dict[str, int]:
        fixture_ids = [int(fx) for fx in (watchlist.get("live_fixture_ids") or [])]
        if not fixture_ids:
            return {"fixtures": 0, "rows_written": 0, "api_requests": 0}

        api_key = Variable.get("API_FOOTBALL_KEY")
        engine = _engine()
        session = _session(api_key)
        req = 0
        written = 0

        for fixture_id in fixture_ids:
            payload = _api_get(session, "/fixtures/events", {"fixture": fixture_id})
            req += 1
            written += _replace_events(engine, fixture_id, _parse_events(fixture_id, payload))
            time.sleep(0.4)

        return {"fixtures": len(fixture_ids), "rows_written": written, "api_requests": req}

    watchlist = discover_watchlist()
    lineups = fetch_pre_match_lineups(watchlist)
    stats = refresh_live_stats(watchlist)
    events = refresh_live_events(watchlist)

    start >> watchlist >> [lineups, stats, events] >> end
