import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd
from curl_cffi import requests


DEFAULT_PSQL = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"


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


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Standalone ingest of Understat league extras into Postgres.")
    p.add_argument("--league", default="EPL", help="League code, e.g. EPL")
    p.add_argument("--season", type=int, default=2025, help="Season year, e.g. 2025")
    p.add_argument("--year", type=int, default=None, help="Optional calendar year filter for matches/team_history")
    p.add_argument("--schema-file", default="understat_extras_schema.sql")

    p.add_argument("--db-host", default=os.getenv("PGHOST", "localhost"))
    p.add_argument("--db-port", default=os.getenv("PGPORT", "5432"))
    p.add_argument("--db-name", default=os.getenv("PGDATABASE", "dwh"))
    p.add_argument("--db-user", default=os.getenv("PGUSER", "postgres"))
    p.add_argument("--db-password", default=os.getenv("PGPASSWORD", "0506"))
    p.add_argument("--psql", default=DEFAULT_PSQL)
    return p.parse_args()


def fetch_league_payload(league: str, season: int) -> Dict[str, Any]:
    headers = {
        "X-Requested-With": "XMLHttpRequest",
        "Referer": f"https://understat.com/league/{league}/{season}",
        "Accept": "application/json, text/javascript, */*; q=0.01",
    }
    r = requests.get(
        f"https://understat.com/getLeagueData/{league}/{season}",
        headers=headers,
        impersonate="chrome110",
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def build_matches_df(payload: Dict[str, Any], league: str, season: int, year: Optional[int]) -> pd.DataFrame:
    rows: List[Dict[str, Any]] = []
    for m in payload.get("dates", []):
        dt = str(m.get("datetime", ""))
        if year and not dt.startswith(f"{year}-"):
            continue
        rows.append(
            {
                "league_code": league,
                "season": season,
                "match_id": _to_int(m.get("id")),
                "match_dt_utc": dt or None,
                "is_result": bool(m.get("isResult")),
                "home_team_id": _to_int((m.get("h") or {}).get("id")),
                "home_team_name": (m.get("h") or {}).get("title"),
                "home_team_short": (m.get("h") or {}).get("short_title"),
                "away_team_id": _to_int((m.get("a") or {}).get("id")),
                "away_team_name": (m.get("a") or {}).get("title"),
                "away_team_short": (m.get("a") or {}).get("short_title"),
                "home_goals": _to_int((m.get("goals") or {}).get("h")),
                "away_goals": _to_int((m.get("goals") or {}).get("a")),
                "home_xg": _to_float((m.get("xG") or {}).get("h")),
                "away_xg": _to_float((m.get("xG") or {}).get("a")),
                "forecast_home_win": _to_float((m.get("forecast") or {}).get("w")),
                "forecast_draw": _to_float((m.get("forecast") or {}).get("d")),
                "forecast_away_win": _to_float((m.get("forecast") or {}).get("l")),
                "raw_json": json.dumps(m, ensure_ascii=False),
            }
        )
    if not rows:
        return pd.DataFrame(columns=[
            "league_code", "season", "match_id", "match_dt_utc", "is_result",
            "home_team_id", "home_team_name", "home_team_short", "away_team_id",
            "away_team_name", "away_team_short", "home_goals", "away_goals",
            "home_xg", "away_xg", "forecast_home_win", "forecast_draw",
            "forecast_away_win", "raw_json",
        ])
    return pd.DataFrame(rows).drop_duplicates(subset=["league_code", "season", "match_id"], keep="last")


def build_team_history_df(payload: Dict[str, Any], league: str, season: int, year: Optional[int]) -> pd.DataFrame:
    rows: List[Dict[str, Any]] = []
    for team_id_str, team_obj in (payload.get("teams") or {}).items():
        team_id = _to_int(team_obj.get("id") or team_id_str)
        team_title = team_obj.get("title")
        for h in team_obj.get("history", []):
            dt = str(h.get("date", ""))
            if year and not dt.startswith(f"{year}-"):
                continue
            ppda = h.get("ppda") or {}
            ppda_allowed = h.get("ppda_allowed") or {}
            rows.append(
                {
                    "league_code": league,
                    "season": season,
                    "team_id": team_id,
                    "team_title": team_title,
                    "h_a": h.get("h_a"),
                    "match_dt_utc": dt or None,
                    "result": h.get("result"),
                    "wins": _to_int(h.get("wins")),
                    "draws": _to_int(h.get("draws")),
                    "loses": _to_int(h.get("loses")),
                    "pts": _to_int(h.get("pts")),
                    "scored": _to_int(h.get("scored")),
                    "missed": _to_int(h.get("missed")),
                    "xg": _to_float(h.get("xG")),
                    "xga": _to_float(h.get("xGA")),
                    "npxg": _to_float(h.get("npxG")),
                    "npxga": _to_float(h.get("npxGA")),
                    "npxgd": _to_float(h.get("npxGD")),
                    "xpts": _to_float(h.get("xpts")),
                    "deep": _to_int(h.get("deep")),
                    "deep_allowed": _to_int(h.get("deep_allowed")),
                    "ppda_att": _to_float(ppda.get("att")),
                    "ppda_def": _to_float(ppda.get("def")),
                    "ppda_allowed_att": _to_float(ppda_allowed.get("att")),
                    "ppda_allowed_def": _to_float(ppda_allowed.get("def")),
                    "raw_json": json.dumps(h, ensure_ascii=False),
                }
            )
    if not rows:
        return pd.DataFrame(columns=[
            "league_code", "season", "team_id", "team_title", "h_a", "match_dt_utc",
            "result", "wins", "draws", "loses", "pts", "scored", "missed", "xg", "xga",
            "npxg", "npxga", "npxgd", "xpts", "deep", "deep_allowed", "ppda_att",
            "ppda_def", "ppda_allowed_att", "ppda_allowed_def", "raw_json",
        ])
    return pd.DataFrame(rows).drop_duplicates(
        subset=["league_code", "season", "team_id", "match_dt_utc"], keep="last"
    )


def build_players_df(payload: Dict[str, Any], league: str, season: int) -> pd.DataFrame:
    rows: List[Dict[str, Any]] = []
    for p in payload.get("players", []):
        rows.append(
            {
                "league_code": league,
                "season": season,
                "player_id": _to_int(p.get("id")),
                "player_name": p.get("player_name"),
                "team_title": p.get("team_title"),
                "position": p.get("position"),
                "games": _to_int(p.get("games")),
                "minutes": _to_int(p.get("time")),
                "goals": _to_int(p.get("goals")),
                "assists": _to_int(p.get("assists")),
                "shots": _to_int(p.get("shots")),
                "key_passes": _to_int(p.get("key_passes")),
                "yellow_cards": _to_int(p.get("yellow_cards")),
                "red_cards": _to_int(p.get("red_cards")),
                "xg": _to_float(p.get("xG")),
                "xa": _to_float(p.get("xA")),
                "npg": _to_int(p.get("npg")),
                "npxg": _to_float(p.get("npxG")),
                "xg_chain": _to_float(p.get("xGChain")),
                "xg_buildup": _to_float(p.get("xGBuildup")),
                "raw_json": json.dumps(p, ensure_ascii=False),
            }
        )
    if not rows:
        return pd.DataFrame(columns=[
            "league_code", "season", "player_id", "player_name", "team_title", "position",
            "games", "minutes", "goals", "assists", "shots", "key_passes", "yellow_cards",
            "red_cards", "xg", "xa", "npg", "npxg", "xg_chain", "xg_buildup", "raw_json",
        ])
    return pd.DataFrame(rows).drop_duplicates(subset=["league_code", "season", "player_id"], keep="last")


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


def sql_quote_path(p: Path) -> str:
    return str(p).replace("'", "''")


def load_with_copy(args: argparse.Namespace, mdf: pd.DataFrame, hdf: pd.DataFrame, pdf: pd.DataFrame) -> None:
    # Keep integer columns as nullable ints, not floats like 1.0.
    m_int_cols = [
        "season",
        "match_id",
        "home_team_id",
        "away_team_id",
        "home_goals",
        "away_goals",
    ]
    h_int_cols = [
        "season",
        "team_id",
        "wins",
        "draws",
        "loses",
        "pts",
        "scored",
        "missed",
        "deep",
        "deep_allowed",
    ]
    p_int_cols = [
        "season",
        "player_id",
        "games",
        "minutes",
        "goals",
        "assists",
        "shots",
        "key_passes",
        "yellow_cards",
        "red_cards",
        "npg",
    ]
    for c in m_int_cols:
        if c in mdf.columns:
            mdf[c] = pd.to_numeric(mdf[c], errors="coerce").astype("Int64")
    for c in h_int_cols:
        if c in hdf.columns:
            hdf[c] = pd.to_numeric(hdf[c], errors="coerce").astype("Int64")
    for c in p_int_cols:
        if c in pdf.columns:
            pdf[c] = pd.to_numeric(pdf[c], errors="coerce").astype("Int64")

    with tempfile.TemporaryDirectory(prefix="understat_extras_") as d:
        dpath = Path(d)
        m_csv = dpath / "league_matches.csv"
        h_csv = dpath / "team_history.csv"
        p_csv = dpath / "league_players.csv"
        mdf.to_csv(m_csv, index=False)
        hdf.to_csv(h_csv, index=False)
        pdf.to_csv(p_csv, index=False)

        sql = f"""
\\i {sql_quote_path(Path(args.schema_file).resolve())}

DROP TABLE IF EXISTS tmp_understat_league_matches;
CREATE TEMP TABLE tmp_understat_league_matches (LIKE football.understat_league_matches INCLUDING DEFAULTS);
\\copy tmp_understat_league_matches(league_code,season,match_id,match_dt_utc,is_result,home_team_id,home_team_name,home_team_short,away_team_id,away_team_name,away_team_short,home_goals,away_goals,home_xg,away_xg,forecast_home_win,forecast_draw,forecast_away_win,raw_json) FROM '{sql_quote_path(m_csv)}' WITH (FORMAT csv, HEADER true, NULL '');
INSERT INTO football.understat_league_matches(
  league_code,season,match_id,match_dt_utc,is_result,home_team_id,home_team_name,home_team_short,away_team_id,away_team_name,away_team_short,home_goals,away_goals,home_xg,away_xg,forecast_home_win,forecast_draw,forecast_away_win,raw_json,updated_dttm
)
SELECT
  league_code,season,match_id,match_dt_utc,is_result,home_team_id,home_team_name,home_team_short,away_team_id,away_team_name,away_team_short,home_goals,away_goals,home_xg,away_xg,forecast_home_win,forecast_draw,forecast_away_win,raw_json,NOW()
FROM tmp_understat_league_matches
ON CONFLICT (league_code,season,match_id) DO UPDATE SET
  match_dt_utc = EXCLUDED.match_dt_utc,
  is_result = EXCLUDED.is_result,
  home_team_id = EXCLUDED.home_team_id,
  home_team_name = EXCLUDED.home_team_name,
  home_team_short = EXCLUDED.home_team_short,
  away_team_id = EXCLUDED.away_team_id,
  away_team_name = EXCLUDED.away_team_name,
  away_team_short = EXCLUDED.away_team_short,
  home_goals = EXCLUDED.home_goals,
  away_goals = EXCLUDED.away_goals,
  home_xg = EXCLUDED.home_xg,
  away_xg = EXCLUDED.away_xg,
  forecast_home_win = EXCLUDED.forecast_home_win,
  forecast_draw = EXCLUDED.forecast_draw,
  forecast_away_win = EXCLUDED.forecast_away_win,
  raw_json = EXCLUDED.raw_json,
  updated_dttm = NOW();

DROP TABLE IF EXISTS tmp_understat_team_history;
CREATE TEMP TABLE tmp_understat_team_history (LIKE football.understat_league_team_history INCLUDING DEFAULTS);
\\copy tmp_understat_team_history(league_code,season,team_id,team_title,h_a,match_dt_utc,result,wins,draws,loses,pts,scored,missed,xg,xga,npxg,npxga,npxgd,xpts,deep,deep_allowed,ppda_att,ppda_def,ppda_allowed_att,ppda_allowed_def,raw_json) FROM '{sql_quote_path(h_csv)}' WITH (FORMAT csv, HEADER true, NULL '');
INSERT INTO football.understat_league_team_history(
  league_code,season,team_id,team_title,h_a,match_dt_utc,result,wins,draws,loses,pts,scored,missed,xg,xga,npxg,npxga,npxgd,xpts,deep,deep_allowed,ppda_att,ppda_def,ppda_allowed_att,ppda_allowed_def,raw_json,updated_dttm
)
SELECT
  league_code,season,team_id,team_title,h_a,match_dt_utc,result,wins,draws,loses,pts,scored,missed,xg,xga,npxg,npxga,npxgd,xpts,deep,deep_allowed,ppda_att,ppda_def,ppda_allowed_att,ppda_allowed_def,raw_json,NOW()
FROM tmp_understat_team_history
ON CONFLICT (league_code,season,team_id,match_dt_utc) DO UPDATE SET
  team_title = EXCLUDED.team_title,
  h_a = EXCLUDED.h_a,
  result = EXCLUDED.result,
  wins = EXCLUDED.wins,
  draws = EXCLUDED.draws,
  loses = EXCLUDED.loses,
  pts = EXCLUDED.pts,
  scored = EXCLUDED.scored,
  missed = EXCLUDED.missed,
  xg = EXCLUDED.xg,
  xga = EXCLUDED.xga,
  npxg = EXCLUDED.npxg,
  npxga = EXCLUDED.npxga,
  npxgd = EXCLUDED.npxgd,
  xpts = EXCLUDED.xpts,
  deep = EXCLUDED.deep,
  deep_allowed = EXCLUDED.deep_allowed,
  ppda_att = EXCLUDED.ppda_att,
  ppda_def = EXCLUDED.ppda_def,
  ppda_allowed_att = EXCLUDED.ppda_allowed_att,
  ppda_allowed_def = EXCLUDED.ppda_allowed_def,
  raw_json = EXCLUDED.raw_json,
  updated_dttm = NOW();

DROP TABLE IF EXISTS tmp_understat_league_players;
CREATE TEMP TABLE tmp_understat_league_players (LIKE football.understat_league_players INCLUDING DEFAULTS);
\\copy tmp_understat_league_players(league_code,season,player_id,player_name,team_title,position,games,minutes,goals,assists,shots,key_passes,yellow_cards,red_cards,xg,xa,npg,npxg,xg_chain,xg_buildup,raw_json) FROM '{sql_quote_path(p_csv)}' WITH (FORMAT csv, HEADER true, NULL '');
INSERT INTO football.understat_league_players(
  league_code,season,player_id,player_name,team_title,position,games,minutes,goals,assists,shots,key_passes,yellow_cards,red_cards,xg,xa,npg,npxg,xg_chain,xg_buildup,raw_json,updated_dttm
)
SELECT
  league_code,season,player_id,player_name,team_title,position,games,minutes,goals,assists,shots,key_passes,yellow_cards,red_cards,xg,xa,npg,npxg,xg_chain,xg_buildup,raw_json,NOW()
FROM tmp_understat_league_players
WHERE player_id IS NOT NULL
ON CONFLICT (league_code,season,player_id) DO UPDATE SET
  player_name = EXCLUDED.player_name,
  team_title = EXCLUDED.team_title,
  position = EXCLUDED.position,
  games = EXCLUDED.games,
  minutes = EXCLUDED.minutes,
  goals = EXCLUDED.goals,
  assists = EXCLUDED.assists,
  shots = EXCLUDED.shots,
  key_passes = EXCLUDED.key_passes,
  yellow_cards = EXCLUDED.yellow_cards,
  red_cards = EXCLUDED.red_cards,
  xg = EXCLUDED.xg,
  xa = EXCLUDED.xa,
  npg = EXCLUDED.npg,
  npxg = EXCLUDED.npxg,
  xg_chain = EXCLUDED.xg_chain,
  xg_buildup = EXCLUDED.xg_buildup,
  raw_json = EXCLUDED.raw_json,
  updated_dttm = NOW();
"""
        run_psql(sql, args)


def main() -> None:
    args = parse_args()
    if not Path(args.schema_file).exists():
        raise RuntimeError(f"Schema file not found: {args.schema_file}")

    payload = fetch_league_payload(args.league, args.season)
    matches_df = build_matches_df(payload, args.league, args.season, args.year)
    history_df = build_team_history_df(payload, args.league, args.season, args.year)
    players_df = build_players_df(payload, args.league, args.season)

    print(
        f"[INFO] prepared: matches={len(matches_df)} team_history={len(history_df)} players={len(players_df)}"
    )
    if matches_df.empty and history_df.empty and players_df.empty:
        raise RuntimeError("No rows prepared. Check filters.")

    load_with_copy(args, matches_df, history_df, players_df)
    print("[OK] Upsert completed into understat_league_* tables.")


if __name__ == "__main__":
    main()
