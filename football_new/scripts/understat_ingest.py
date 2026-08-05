import argparse
import json
import os
import re
import subprocess
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
from curl_cffi import requests


DEFAULT_PSQL = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"


def resolve_default_understat_season(now: Optional[datetime] = None) -> int:
    current = now or datetime.utcnow()
    return current.year if current.month >= 7 else current.year - 1


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Ingest Understat data into Postgres tables.")
    p.add_argument("--league", default="EPL", help="League code for Understat (default: EPL)")
    p.add_argument(
        "--season",
        type=int,
        default=resolve_default_understat_season(),
        help="Season year for Understat (defaults to the current football season)",
    )
    p.add_argument("--year", type=int, default=None, help="Calendar year filter by match datetime, e.g. 2026")
    p.add_argument("--match-id", type=int, default=None, help="Single match id to ingest")
    p.add_argument(
        "--only-new",
        action="store_true",
        help="Ingest only matches not fully present in football.understat_matches for this league/season",
    )
    p.add_argument("--limit", type=int, default=None, help="Optional limit for number of matches")
    p.add_argument("--sleep-ms", type=int, default=120, help="Sleep between match requests (ms)")
    p.add_argument("--no-match-info", action="store_true", help="Skip match_info page parsing (faster)")

    p.add_argument("--db-host", default=os.getenv("PGHOST", "localhost"))
    p.add_argument("--db-port", default=os.getenv("PGPORT", "5432"))
    p.add_argument("--db-name", default=os.getenv("PGDATABASE", "dwh"))
    p.add_argument("--db-user", default=os.getenv("PGUSER", "postgres"))
    p.add_argument("--db-password", default=os.getenv("PGPASSWORD", "0506"))
    p.add_argument("--psql", default=DEFAULT_PSQL, help="Path to psql binary")
    p.add_argument("--schema-file", default="understat_schema.sql", help="Schema SQL file path")
    return p.parse_args()


def _req(url: str, headers: Optional[Dict[str, str]] = None) -> requests.Response:
    return requests.get(url, headers=headers or {}, impersonate="chrome110", timeout=30)


def fetch_league_dates(league: str, season: int) -> List[Dict[str, Any]]:
    headers = {
        "X-Requested-With": "XMLHttpRequest",
        "Referer": f"https://understat.com/league/{league}/{season}",
        "Accept": "application/json, text/javascript, */*; q=0.01",
    }
    r = _req(f"https://understat.com/getLeagueData/{league}/{season}", headers=headers)
    r.raise_for_status()
    payload = r.json()
    return payload.get("dates", [])


def fetch_match_data(match_id: int) -> Dict[str, Any]:
    headers = {
        "X-Requested-With": "XMLHttpRequest",
        "Referer": f"https://understat.com/match/{match_id}",
        "Accept": "application/json, text/javascript, */*; q=0.01",
    }
    r = _req(f"https://understat.com/getMatchData/{match_id}", headers=headers)
    r.raise_for_status()
    return r.json()


def fetch_match_info(match_id: int) -> Dict[str, Any]:
    html = _req(f"https://understat.com/match/{match_id}").text
    m = re.search(r"var\s+match_info\s*=\s*JSON\.parse\('((?:\\.|[^'])*)'\)", html, re.S)
    if not m:
        return {}
    try:
        return json.loads(m.group(1).encode("utf-8").decode("unicode_escape"))
    except Exception:
        return {}


def _to_int(v: Any) -> Optional[int]:
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except Exception:
        return None


def _to_float(v: Any) -> Optional[float]:
    if v is None or v == "":
        return None
    try:
        return float(v)
    except Exception:
        return None


def build_match_row(match_id: int, date_item: Dict[str, Any], match_info: Dict[str, Any]) -> Dict[str, Any]:
    h = match_info if match_info else {}
    home = date_item.get("h", {}) if date_item else {}
    away = date_item.get("a", {}) if date_item else {}
    goals = date_item.get("goals", {}) if date_item else {}
    xg = date_item.get("xG", {}) if date_item else {}
    forecast = date_item.get("forecast", {}) if date_item else {}

    return {
        "match_id": _to_int(h.get("id")) or match_id,
        "source": "understat",
        "fixture_ext_id": _to_int(h.get("fid")),
        "league": h.get("league"),
        "league_id": _to_int(h.get("league_id")),
        "season": _to_int(h.get("season")),
        "match_dt_utc": h.get("date") or date_item.get("datetime"),
        "home_team_id": _to_int(h.get("h")) or _to_int(home.get("id")),
        "home_team_name": h.get("team_h") or home.get("title"),
        "away_team_id": _to_int(h.get("a")) or _to_int(away.get("id")),
        "away_team_name": h.get("team_a") or away.get("title"),
        "home_goals": _to_int(h.get("h_goals")) if h else _to_int(goals.get("h")),
        "away_goals": _to_int(h.get("a_goals")) if h else _to_int(goals.get("a")),
        "home_xg": _to_float(h.get("h_xg")) if h else _to_float(xg.get("h")),
        "away_xg": _to_float(h.get("a_xg")) if h else _to_float(xg.get("a")),
        "home_shots": _to_int(h.get("h_shot")),
        "away_shots": _to_int(h.get("a_shot")),
        "home_sot": _to_int(h.get("h_shotOnTarget")),
        "away_sot": _to_int(h.get("a_shotOnTarget")),
        "home_deep": _to_int(h.get("h_deep")),
        "away_deep": _to_int(h.get("a_deep")),
        "home_ppda": _to_float(h.get("h_ppda")),
        "away_ppda": _to_float(h.get("a_ppda")),
        "prob_home_win": _to_float(h.get("h_w")) if h else _to_float(forecast.get("w")),
        "prob_draw": _to_float(h.get("h_d")) if h else _to_float(forecast.get("d")),
        "prob_home_loss": _to_float(h.get("h_l")) if h else _to_float(forecast.get("l")),
        "is_data": bool(h.get("isData")) if h else bool(date_item.get("isResult")),
        "raw_json": json.dumps(h if h else date_item, ensure_ascii=False),
    }


def build_player_rows(match_id: int, match_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    rosters = match_data.get("rosters", {})
    for side in ("h", "a"):
        for rec in (rosters.get(side) or {}).values():
            out.append(
                {
                    "match_id": match_id,
                    "side": side,
                    "row_id": _to_int(rec.get("id")),
                    "player_id": _to_int(rec.get("player_id")),
                    "player_name": rec.get("player"),
                    "team_id": _to_int(rec.get("team_id")),
                    "position": rec.get("position"),
                    "position_order": _to_int(rec.get("positionOrder")),
                    "minutes": _to_int(rec.get("time")),
                    "goals": _to_int(rec.get("goals")),
                    "assists": _to_int(rec.get("assists")),
                    "shots": _to_int(rec.get("shots")),
                    "key_passes": _to_int(rec.get("key_passes")),
                    "xg": _to_float(rec.get("xG")),
                    "xa": _to_float(rec.get("xA")),
                    "xg_chain": _to_float(rec.get("xGChain")),
                    "xg_buildup": _to_float(rec.get("xGBuildup")),
                    "yellow_cards": _to_int(rec.get("yellow_card")),
                    "red_cards": _to_int(rec.get("red_card")),
                    "own_goals": _to_int(rec.get("own_goals")),
                    "roster_in": _to_int(rec.get("roster_in")),
                    "roster_out": _to_int(rec.get("roster_out")),
                    "raw_json": json.dumps(rec, ensure_ascii=False),
                }
            )
    return out


def build_shot_rows(match_id: int, match_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    shots = match_data.get("shots", {})
    for side in ("h", "a"):
        for rec in (shots.get(side) or []):
            out.append(
                {
                    "shot_id": _to_int(rec.get("id")),
                    "match_id": _to_int(rec.get("match_id")) or match_id,
                    "side": side,
                    "minute": _to_int(rec.get("minute")),
                    "player_id": _to_int(rec.get("player_id")),
                    "player_name": rec.get("player"),
                    "assisted_by": rec.get("player_assisted"),
                    "result": rec.get("result"),
                    "situation": rec.get("situation"),
                    "shot_type": rec.get("shotType"),
                    "last_action": rec.get("lastAction"),
                    "x": _to_float(rec.get("X")),
                    "y": _to_float(rec.get("Y")),
                    "xg": _to_float(rec.get("xG")),
                    "score_home_after": _to_int(rec.get("h_goals")),
                    "score_away_after": _to_int(rec.get("a_goals")),
                    "shot_dt_utc": rec.get("date"),
                    "raw_json": json.dumps(rec, ensure_ascii=False),
                }
            )
    return out


def run_psql(sql: str, args: argparse.Namespace) -> None:
    env = os.environ.copy()
    env["PGPASSWORD"] = args.db_password
    cmd = [
        args.psql,
        "-h",
        str(args.db_host),
        "-p",
        str(args.db_port),
        "-U",
        str(args.db_user),
        "-d",
        str(args.db_name),
        "-v",
        "ON_ERROR_STOP=1",
    ]
    subprocess.run(cmd, input=sql, text=True, check=True, env=env)


def run_psql_query(sql: str, args: argparse.Namespace) -> str:
    env = os.environ.copy()
    env["PGPASSWORD"] = args.db_password
    cmd = [
        args.psql,
        "-h",
        str(args.db_host),
        "-p",
        str(args.db_port),
        "-U",
        str(args.db_user),
        "-d",
        str(args.db_name),
        "-v",
        "ON_ERROR_STOP=1",
        "-At",
        "-c",
        sql,
    ]
    res = subprocess.run(cmd, text=True, check=True, env=env, capture_output=True)
    return res.stdout


def sql_quote_literal(value: str) -> str:
    return value.replace("'", "''")


def fetch_loaded_match_ids(args: argparse.Namespace) -> set[int]:
    league = sql_quote_literal(args.league)
    sql = f"""
SELECT match_id
FROM football.understat_matches
WHERE league = '{league}'
  AND season = {int(args.season)}
  AND COALESCE(is_data, false) = true
"""
    out = run_psql_query(sql, args)
    return {int(line.strip()) for line in out.splitlines() if line.strip()}


def sql_quote_path(p: Path) -> str:
    return str(p).replace("'", "''")


def load_with_copy(
    args: argparse.Namespace,
    matches_df: pd.DataFrame,
    players_df: pd.DataFrame,
    shots_df: pd.DataFrame,
) -> None:
    with tempfile.TemporaryDirectory(prefix="understat_ingest_") as d:
        dpath = Path(d)
        m_csv = dpath / "matches.csv"
        p_csv = dpath / "players.csv"
        s_csv = dpath / "shots.csv"

        matches_df.to_csv(m_csv, index=False)
        players_df.to_csv(p_csv, index=False)
        shots_df.to_csv(s_csv, index=False)

        m_path = sql_quote_path(m_csv)
        p_path = sql_quote_path(p_csv)
        s_path = sql_quote_path(s_csv)

        sql = f"""
\\i {sql_quote_path(Path(args.schema_file).resolve())}

DROP TABLE IF EXISTS tmp_understat_matches;
CREATE TEMP TABLE tmp_understat_matches (LIKE football.understat_matches INCLUDING DEFAULTS);
TRUNCATE tmp_understat_matches;
\\copy tmp_understat_matches(match_id,source,fixture_ext_id,league,league_id,season,match_dt_utc,home_team_id,home_team_name,away_team_id,away_team_name,home_goals,away_goals,home_xg,away_xg,home_shots,away_shots,home_sot,away_sot,home_deep,away_deep,home_ppda,away_ppda,prob_home_win,prob_draw,prob_home_loss,is_data,raw_json) FROM '{m_path}' WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO football.understat_matches(
  match_id, source, fixture_ext_id, league, league_id, season, match_dt_utc,
  home_team_id, home_team_name, away_team_id, away_team_name, home_goals, away_goals,
  home_xg, away_xg, home_shots, away_shots, home_sot, away_sot, home_deep, away_deep,
  home_ppda, away_ppda, prob_home_win, prob_draw, prob_home_loss, is_data, raw_json, updated_dttm
)
SELECT
  match_id, source, fixture_ext_id, league, league_id, season, match_dt_utc,
  home_team_id, home_team_name, away_team_id, away_team_name, home_goals, away_goals,
  home_xg, away_xg, home_shots, away_shots, home_sot, away_sot, home_deep, away_deep,
  home_ppda, away_ppda, prob_home_win, prob_draw, prob_home_loss, is_data, raw_json, NOW()
FROM tmp_understat_matches
ON CONFLICT (match_id) DO UPDATE SET
  source = EXCLUDED.source,
  fixture_ext_id = EXCLUDED.fixture_ext_id,
  league = EXCLUDED.league,
  league_id = EXCLUDED.league_id,
  season = EXCLUDED.season,
  match_dt_utc = EXCLUDED.match_dt_utc,
  home_team_id = EXCLUDED.home_team_id,
  home_team_name = EXCLUDED.home_team_name,
  away_team_id = EXCLUDED.away_team_id,
  away_team_name = EXCLUDED.away_team_name,
  home_goals = EXCLUDED.home_goals,
  away_goals = EXCLUDED.away_goals,
  home_xg = EXCLUDED.home_xg,
  away_xg = EXCLUDED.away_xg,
  home_shots = EXCLUDED.home_shots,
  away_shots = EXCLUDED.away_shots,
  home_sot = EXCLUDED.home_sot,
  away_sot = EXCLUDED.away_sot,
  home_deep = EXCLUDED.home_deep,
  away_deep = EXCLUDED.away_deep,
  home_ppda = EXCLUDED.home_ppda,
  away_ppda = EXCLUDED.away_ppda,
  prob_home_win = EXCLUDED.prob_home_win,
  prob_draw = EXCLUDED.prob_draw,
  prob_home_loss = EXCLUDED.prob_home_loss,
  is_data = EXCLUDED.is_data,
  raw_json = EXCLUDED.raw_json,
  updated_dttm = NOW();

DROP TABLE IF EXISTS tmp_understat_players;
CREATE TEMP TABLE tmp_understat_players (LIKE football.understat_match_players INCLUDING DEFAULTS);
TRUNCATE tmp_understat_players;
\\copy tmp_understat_players(match_id,side,row_id,player_id,player_name,team_id,position,position_order,minutes,goals,assists,shots,key_passes,xg,xa,xg_chain,xg_buildup,yellow_cards,red_cards,own_goals,roster_in,roster_out,raw_json) FROM '{p_path}' WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO football.understat_match_players(
  match_id, side, row_id, player_id, player_name, team_id, position, position_order, minutes, goals, assists,
  shots, key_passes, xg, xa, xg_chain, xg_buildup, yellow_cards, red_cards, own_goals, roster_in, roster_out, raw_json
)
SELECT
  match_id, side, row_id, player_id, player_name, team_id, position, position_order, minutes, goals, assists,
  shots, key_passes, xg, xa, xg_chain, xg_buildup, yellow_cards, red_cards, own_goals, roster_in, roster_out, raw_json
FROM tmp_understat_players
WHERE player_id IS NOT NULL
ON CONFLICT (match_id, player_id, side) DO UPDATE SET
  row_id = EXCLUDED.row_id,
  player_name = EXCLUDED.player_name,
  team_id = EXCLUDED.team_id,
  position = EXCLUDED.position,
  position_order = EXCLUDED.position_order,
  minutes = EXCLUDED.minutes,
  goals = EXCLUDED.goals,
  assists = EXCLUDED.assists,
  shots = EXCLUDED.shots,
  key_passes = EXCLUDED.key_passes,
  xg = EXCLUDED.xg,
  xa = EXCLUDED.xa,
  xg_chain = EXCLUDED.xg_chain,
  xg_buildup = EXCLUDED.xg_buildup,
  yellow_cards = EXCLUDED.yellow_cards,
  red_cards = EXCLUDED.red_cards,
  own_goals = EXCLUDED.own_goals,
  roster_in = EXCLUDED.roster_in,
  roster_out = EXCLUDED.roster_out,
  raw_json = EXCLUDED.raw_json;

DROP TABLE IF EXISTS tmp_understat_shots;
CREATE TEMP TABLE tmp_understat_shots (LIKE football.understat_match_shots INCLUDING DEFAULTS);
TRUNCATE tmp_understat_shots;
\\copy tmp_understat_shots(shot_id,match_id,side,minute,player_id,player_name,assisted_by,result,situation,shot_type,last_action,x,y,xg,score_home_after,score_away_after,shot_dt_utc,raw_json) FROM '{s_path}' WITH (FORMAT csv, HEADER true, NULL '');

INSERT INTO football.understat_match_shots(
  shot_id, match_id, side, minute, player_id, player_name, assisted_by, result, situation, shot_type, last_action,
  x, y, xg, score_home_after, score_away_after, shot_dt_utc, raw_json
)
SELECT
  shot_id, match_id, side, minute, player_id, player_name, assisted_by, result, situation, shot_type, last_action,
  x, y, xg, score_home_after, score_away_after, shot_dt_utc, raw_json
FROM tmp_understat_shots
WHERE shot_id IS NOT NULL
ON CONFLICT (shot_id) DO UPDATE SET
  match_id = EXCLUDED.match_id,
  side = EXCLUDED.side,
  minute = EXCLUDED.minute,
  player_id = EXCLUDED.player_id,
  player_name = EXCLUDED.player_name,
  assisted_by = EXCLUDED.assisted_by,
  result = EXCLUDED.result,
  situation = EXCLUDED.situation,
  shot_type = EXCLUDED.shot_type,
  last_action = EXCLUDED.last_action,
  x = EXCLUDED.x,
  y = EXCLUDED.y,
  xg = EXCLUDED.xg,
  score_home_after = EXCLUDED.score_home_after,
  score_away_after = EXCLUDED.score_away_after,
  shot_dt_utc = EXCLUDED.shot_dt_utc,
  raw_json = EXCLUDED.raw_json;
"""
        run_psql(sql, args)


def main() -> None:
    args = parse_args()

    if not Path(args.schema_file).exists():
        raise RuntimeError(f"Schema file not found: {args.schema_file}")

    if args.match_id:
        match_ids = [args.match_id]
        dates_by_id: Dict[int, Dict[str, Any]] = {}
    else:
        dates = fetch_league_dates(args.league, args.season)
        if args.year:
            dates = [d for d in dates if str(d.get("datetime", "")).startswith(f"{args.year}-")]
        if args.only_new:
            dates = [d for d in dates if bool(d.get("isResult"))]
            loaded_match_ids = fetch_loaded_match_ids(args)
            before = len(dates)
            dates = [d for d in dates if int(d.get("id")) not in loaded_match_ids]
            print(
                f"[INFO] only-new filter: selected {len(dates)} of {before} matches "
                f"for league={args.league} season={args.season}"
            )
        if args.limit:
            dates = dates[: args.limit]
        match_ids = sorted({int(d.get("id")) for d in dates if d.get("id") is not None})
        dates_by_id = {int(d["id"]): d for d in dates if d.get("id") is not None}

    if not match_ids:
        print("[INFO] No new completed matches selected.")
        return

    match_rows: List[Dict[str, Any]] = []
    player_rows: List[Dict[str, Any]] = []
    shot_rows: List[Dict[str, Any]] = []

    print(f"[INFO] ingest matches: {len(match_ids)}")
    for i, mid in enumerate(match_ids, start=1):
        try:
            md = fetch_match_data(mid)
            mi = {} if args.no_match_info else fetch_match_info(mid)
            di = dates_by_id.get(mid, {})

            match_rows.append(build_match_row(mid, di, mi))
            player_rows.extend(build_player_rows(mid, md))
            shot_rows.extend(build_shot_rows(mid, md))
            print(f"[OK] {i}/{len(match_ids)} match_id={mid} players={len(md.get('rosters', {}).get('h', {})) + len(md.get('rosters', {}).get('a', {}))} shots={len(md.get('shots', {}).get('h', [])) + len(md.get('shots', {}).get('a', []))}")
        except Exception as e:
            print(f"[WARN] skip match_id={mid}: {e}")
        time.sleep(max(0, args.sleep_ms) / 1000.0)

    if not match_rows:
        print("[INFO] No new completed matches to load.")
        return

    matches_df = pd.DataFrame(match_rows).drop_duplicates(subset=["match_id"], keep="last")
    players_df = pd.DataFrame(player_rows)
    shots_df = pd.DataFrame(shot_rows)

    if not players_df.empty:
        players_df = players_df.drop_duplicates(subset=["match_id", "player_id", "side"], keep="last")
    if not shots_df.empty:
        shots_df = shots_df.drop_duplicates(subset=["shot_id"], keep="last")

    print(
        f"[INFO] rows prepared: matches={len(matches_df)}, players={len(players_df)}, shots={len(shots_df)}"
    )

    load_with_copy(args, matches_df, players_df, shots_df)
    print("[OK] Upsert completed: football.understat_matches / understat_match_players / understat_match_shots")


if __name__ == "__main__":
    main()
