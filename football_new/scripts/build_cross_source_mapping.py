import argparse
import csv
import html
import io
import os
import re
import subprocess
import tempfile
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd


DEFAULT_PSQL = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"


TEAM_ALIASES = {
    "man utd": "manchester united",
    "manchester utd": "manchester united",
    "man city": "manchester city",
    "spurs": "tottenham hotspur",
    "tottenham": "tottenham hotspur",
    "wolves": "wolverhampton wanderers",
    "nottm forest": "nottingham forest",
    "newcastle": "newcastle united",
    "west ham": "west ham united",
    "brighton": "brighton hove albion",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build Understat <-> API-Football team/player mapping tables.")
    p.add_argument("--season", type=int, default=2025)
    p.add_argument("--league-name", default="Premier League")
    p.add_argument("--api-league-id", type=int, default=39)
    p.add_argument("--understat-league-code", default="EPL")
    p.add_argument("--schema-file", default="cross_source_mapping_schema.sql")
    p.add_argument("--team-fuzzy-threshold", type=float, default=0.86)
    p.add_argument("--player-fuzzy-threshold", type=float, default=0.88)

    p.add_argument("--db-host", default=os.getenv("PGHOST", "localhost"))
    p.add_argument("--db-port", default=os.getenv("PGPORT", "5432"))
    p.add_argument("--db-name", default=os.getenv("PGDATABASE", "dwh"))
    p.add_argument("--db-user", default=os.getenv("PGUSER", "postgres"))
    p.add_argument("--db-password", default=os.getenv("PGPASSWORD", "0506"))
    p.add_argument("--psql", default=DEFAULT_PSQL)
    return p.parse_args()


def psql_cmd(args: argparse.Namespace) -> List[str]:
    return [
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


def run_psql(args: argparse.Namespace, sql: str) -> str:
    env = os.environ.copy()
    env["PGPASSWORD"] = args.db_password
    proc = subprocess.run(psql_cmd(args), input=sql, text=True, capture_output=True, env=env, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"psql failed (code={proc.returncode}):\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
    return proc.stdout


def query_df(args: argparse.Namespace, sql: str) -> pd.DataFrame:
    copy_sql = f"COPY ({sql}) TO STDOUT WITH CSV HEADER"
    out = run_psql(args, copy_sql)
    return pd.read_csv(io.StringIO(out))


def normalize_text(v: str) -> str:
    s = html.unescape(str(v or "")).strip().lower()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.replace("&", " and ")
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def canonical_team(v: str) -> str:
    s = normalize_text(v)
    if s in TEAM_ALIASES:
        return TEAM_ALIASES[s]
    # remove trailing club suffixes
    tokens = [t for t in s.split() if t not in {"fc", "afc", "cf", "sc", "club"}]
    s2 = " ".join(tokens).strip()
    if s2 in TEAM_ALIASES:
        return TEAM_ALIASES[s2]
    return s2


def canonical_player(v: str) -> str:
    return normalize_text(v)


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def initial_surname_match(a: str, b: str) -> bool:
    """
    Match formats like:
    - "m caicedo" vs "moises caicedo"
    - "e fernandez" vs "enzo fernandez"
    """
    ta = [x for x in a.split() if x]
    tb = [x for x in b.split() if x]
    if len(ta) < 2 or len(tb) < 2:
        return False
    if ta[-1] != tb[-1]:
        return False
    return ta[0][0] == tb[0][0]


def token_subset_match(a: str, b: str) -> bool:
    """
    Match extended / shortened legal names on the same team, e.g.:
    - "kylian mbappe" vs "kylian mbappe lottin"
    - "joao felix" vs "joao felix sequeira"
    Avoid single-token false positives like "gabriel" vs "gabriel jesus".
    """
    ta = [x for x in a.split() if x]
    tb = [x for x in b.split() if x]
    if len(ta) < 2 or len(tb) < 2:
        return False

    short_tokens, long_tokens = (ta, tb) if len(ta) <= len(tb) else (tb, ta)
    if len(short_tokens) == len(long_tokens):
        return False

    if short_tokens[0] != long_tokens[0]:
        return False

    return all(token in long_tokens for token in short_tokens)


def split_team_names(raw_team: str) -> List[str]:
    s = html.unescape(str(raw_team or "")).strip()
    if not s:
        return []
    parts = [p.strip() for p in re.split(r"\s*,\s*|\s*/\s*|\s+\|\s+", s) if p.strip()]
    return parts if parts else [s]


def expand_players_by_team(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    rows: List[Dict[str, object]] = []
    for _, r in df.iterrows():
        team = r.get("team_name")
        parts = split_team_names(str(team))
        if not parts:
            rows.append(r.to_dict())
            continue
        for p in parts:
            row = r.to_dict()
            row["team_name"] = p
            rows.append(row)
    return pd.DataFrame(rows)


@dataclass
class TeamRec:
    team_id: Optional[int]
    team_name: str
    canon: str


def build_team_map(api_teams: pd.DataFrame, under_teams: pd.DataFrame, threshold: float) -> pd.DataFrame:
    api_rows = [
        TeamRec(
            team_id=int(r["team_id"]) if pd.notna(r["team_id"]) else None,
            team_name=str(r["team_name"]),
            canon=canonical_team(str(r["team_name"])),
        )
        for _, r in api_teams.drop_duplicates(subset=["team_id", "team_name"]).iterrows()
    ]
    under_rows = [
        TeamRec(
            team_id=int(r["team_id"]) if pd.notna(r["team_id"]) else None,
            team_name=str(r["team_name"]),
            canon=canonical_team(str(r["team_name"])),
        )
        for _, r in under_teams.drop_duplicates(subset=["team_id", "team_name"]).iterrows()
    ]

    api_by_canon: Dict[str, List[TeamRec]] = {}
    for r in api_rows:
        api_by_canon.setdefault(r.canon, []).append(r)

    used_api: set = set()
    out: List[Dict[str, object]] = []

    for u in under_rows:
        match: Optional[TeamRec] = None
        method = "understat_only"
        conf = 0.0

        if u.canon in api_by_canon and api_by_canon[u.canon]:
            match = api_by_canon[u.canon][0]
            method = "exact_canonical"
            conf = 1.0
        else:
            best = None
            best_score = 0.0
            for a in api_rows:
                sc = similarity(u.canon, a.canon)
                if sc > best_score:
                    best_score = sc
                    best = a
            if best and best_score >= threshold:
                match = best
                method = "fuzzy_canonical"
                conf = round(best_score, 4)

        if match:
            used_api.add((match.team_id, match.team_name))
        out.append(
            {
                "canonical_team_name": match.canon if match else u.canon,
                "api_team_id": match.team_id if match else None,
                "api_team_name": match.team_name if match else None,
                "understat_team_id": u.team_id,
                "understat_team_name": u.team_name,
                "mapping_method": method,
                "confidence": conf,
                "notes": None,
            }
        )

    # API-only teams
    for a in api_rows:
        if (a.team_id, a.team_name) in used_api:
            continue
        out.append(
            {
                "canonical_team_name": a.canon,
                "api_team_id": a.team_id,
                "api_team_name": a.team_name,
                "understat_team_id": None,
                "understat_team_name": None,
                "mapping_method": "api_only",
                "confidence": 0.0,
                "notes": None,
            }
        )

    return pd.DataFrame(out).drop_duplicates(subset=["canonical_team_name"], keep="first")


def _safe_int(v: object) -> int:
    if pd.isna(v):
        return 0
    try:
        return int(float(v))
    except Exception:
        return 0


def build_player_map(
    api_players: pd.DataFrame,
    under_players: pd.DataFrame,
    team_map: pd.DataFrame,
    threshold: float,
) -> pd.DataFrame:
    api = api_players.copy()
    under = under_players.copy()

    api["canon_team"] = api["team_name"].map(canonical_team)
    under["canon_team"] = under["team_name"].map(canonical_team)
    api["canon_player"] = api["player_name"].map(canonical_player)
    under["canon_player"] = under["player_name"].map(canonical_player)

    # Resolve team aliases through mapped canonical if available
    canon_dict = {}
    for _, r in team_map.iterrows():
        if pd.notna(r.get("understat_team_name")):
            canon_dict[canonical_team(str(r["understat_team_name"]))] = str(r["canonical_team_name"])
        if pd.notna(r.get("api_team_name")):
            canon_dict[canonical_team(str(r["api_team_name"]))] = str(r["canonical_team_name"])

    api["canon_team"] = api["canon_team"].map(lambda x: canon_dict.get(x, x))
    under["canon_team"] = under["canon_team"].map(lambda x: canon_dict.get(x, x))

    out: List[Dict[str, object]] = []
    used_api_idx: set = set()

    api_by_team: Dict[str, pd.DataFrame] = {t: g for t, g in api.groupby("canon_team")}
    api_by_player: Dict[str, pd.DataFrame] = {n: g for n, g in api.groupby("canon_player")}

    for ui, u in under.iterrows():
        team = u["canon_team"]
        cands = api_by_team.get(team)
        best_idx = None
        best_score = 0.0
        best_method = "understat_only"

        if cands is not None and not cands.empty:
            # 1) exact by canonical name
            exact = cands[cands["canon_player"] == u["canon_player"]]
            if not exact.empty:
                best_idx = exact.index[0]
                best_score = 1.0
                best_method = "exact_name_team"
            else:
                # 1.5) initial+surname on same team
                for ai, a in cands.iterrows():
                    if initial_surname_match(str(u["canon_player"]), str(a["canon_player"])):
                        best_idx = ai
                        best_score = 0.95
                        best_method = "initial_surname_team"
                        break
            if best_idx is None:
                # 1.6) same-team shortened/full-name compatibility
                for ai, a in cands.iterrows():
                    if token_subset_match(str(u["canon_player"]), str(a["canon_player"])):
                        best_idx = ai
                        best_score = 0.93
                        best_method = "subset_name_team"
                        break
            if best_idx is None:
                # 2) fuzzy name + stats sanity
                u_min = _safe_int(u.get("minutes"))
                u_goals = _safe_int(u.get("goals"))
                for ai, a in cands.iterrows():
                    name_sc = similarity(str(u["canon_player"]), str(a["canon_player"]))
                    min_sc = 1.0
                    a_min = _safe_int(a.get("minutes"))
                    if max(u_min, a_min) > 0:
                        min_sc = 1.0 - abs(u_min - a_min) / max(u_min, a_min)
                    goal_sc = 1.0
                    a_goals = _safe_int(a.get("goals"))
                    if max(u_goals, a_goals) > 0:
                        goal_sc = 1.0 - abs(u_goals - a_goals) / max(u_goals, a_goals)
                    score = 0.78 * name_sc + 0.15 * min_sc + 0.07 * goal_sc
                    if score > best_score:
                        best_score = score
                        best_idx = ai
                        best_method = "fuzzy_name_team_stats"

        matched_api = None
        if best_idx is not None and best_score >= threshold:
            matched_api = api.loc[best_idx]
            used_api_idx.add(best_idx)
            conf = round(float(best_score), 4)
            method = best_method
        else:
            # Secondary pass: unique global exact name (useful for transferred players / noisy team names)
            uniq = api_by_player.get(str(u["canon_player"]))
            if uniq is not None and len(uniq) == 1:
                ai = uniq.index[0]
                matched_api = api.loc[ai]
                used_api_idx.add(ai)
                conf = 0.91
                method = "exact_name_global_unique"
            else:
                conf = 0.0
                method = "understat_only"

        out.append(
            {
                "canonical_team_name": team,
                "canonical_player_name": str(u["canon_player"]),
                "api_player_id": int(matched_api["player_id"]) if matched_api is not None and pd.notna(matched_api["player_id"]) else None,
                "api_player_name": str(matched_api["player_name"]) if matched_api is not None else None,
                "api_team_id": int(matched_api["team_id"]) if matched_api is not None and pd.notna(matched_api["team_id"]) else None,
                "api_team_name": str(matched_api["team_name"]) if matched_api is not None else None,
                "understat_player_id": int(u["player_id"]) if pd.notna(u["player_id"]) else None,
                "understat_player_name": str(u["player_name"]),
                "understat_team_id": int(u["team_id"]) if pd.notna(u["team_id"]) else None,
                "understat_team_name": str(u["team_name"]),
                "mapping_method": method,
                "confidence": conf,
                "notes": None,
            }
        )

    # add API-only players
    for ai, a in api.iterrows():
        if ai in used_api_idx:
            continue
        out.append(
            {
                "canonical_team_name": str(a["canon_team"]),
                "canonical_player_name": str(a["canon_player"]),
                "api_player_id": int(a["player_id"]) if pd.notna(a["player_id"]) else None,
                "api_player_name": str(a["player_name"]),
                "api_team_id": int(a["team_id"]) if pd.notna(a["team_id"]) else None,
                "api_team_name": str(a["team_name"]),
                "understat_player_id": None,
                "understat_player_name": None,
                "understat_team_id": None,
                "understat_team_name": None,
                "mapping_method": "api_only",
                "confidence": 0.0,
                "notes": None,
            }
        )

    player_map = pd.DataFrame(out)
    if player_map.empty:
        return player_map

    # Keep the strongest row when the raw source contains duplicate player entries.
    player_map["_match_rank"] = (
        player_map["api_player_id"].notna().astype(int) * 10
        + player_map["understat_player_id"].notna().astype(int) * 10
        + player_map["confidence"].fillna(0.0).astype(float)
    )
    player_map = player_map.sort_values(
        by=["canonical_team_name", "canonical_player_name", "_match_rank"],
        ascending=[True, True, False],
        kind="stable",
    ).drop_duplicates(subset=["canonical_team_name", "canonical_player_name"], keep="first")
    return player_map.drop(columns=["_match_rank"])


def sql_quote_path(p: Path) -> str:
    return str(p).replace("'", "''")


def load_to_db(args: argparse.Namespace, team_df: pd.DataFrame, player_df: pd.DataFrame) -> None:
    team_df = team_df.copy()
    player_df = player_df.copy()
    team_df["season"] = args.season
    team_df["league_name"] = args.league_name
    player_df["season"] = args.season
    player_df["league_name"] = args.league_name

    team_cols = [
        "season",
        "league_name",
        "canonical_team_name",
        "api_team_id",
        "api_team_name",
        "understat_team_id",
        "understat_team_name",
        "mapping_method",
        "confidence",
        "notes",
    ]
    player_cols = [
        "season",
        "league_name",
        "canonical_team_name",
        "canonical_player_name",
        "api_player_id",
        "api_player_name",
        "api_team_id",
        "api_team_name",
        "understat_player_id",
        "understat_player_name",
        "understat_team_id",
        "understat_team_name",
        "mapping_method",
        "confidence",
        "notes",
    ]
    team_df = team_df[team_cols]
    player_df = player_df[player_cols]

    team_int_cols = ["season", "api_team_id", "understat_team_id"]
    player_int_cols = [
        "season",
        "api_player_id",
        "api_team_id",
        "understat_player_id",
        "understat_team_id",
    ]
    for c in team_int_cols:
        if c in team_df.columns:
            team_df[c] = pd.to_numeric(team_df[c], errors="coerce").astype("Int64")
    for c in player_int_cols:
        if c in player_df.columns:
            player_df[c] = pd.to_numeric(player_df[c], errors="coerce").astype("Int64")

    with tempfile.TemporaryDirectory(prefix="cross_src_map_") as d:
        dpath = Path(d)
        t_csv = dpath / "team_map.csv"
        p_csv = dpath / "player_map.csv"
        team_df.to_csv(t_csv, index=False)
        player_df.to_csv(p_csv, index=False)

        sql = f"""
\\i {sql_quote_path(Path(args.schema_file).resolve())}

DELETE FROM football.team_cross_source_map
 WHERE season = {args.season}
   AND league_name = '{args.league_name.replace("'", "''")}';

DROP TABLE IF EXISTS tmp_team_cross_source_map;
CREATE TEMP TABLE tmp_team_cross_source_map (LIKE football.team_cross_source_map INCLUDING DEFAULTS);
\\copy tmp_team_cross_source_map(season,league_name,canonical_team_name,api_team_id,api_team_name,understat_team_id,understat_team_name,mapping_method,confidence,notes) FROM '{sql_quote_path(t_csv)}' WITH (FORMAT csv, HEADER true, NULL '');
INSERT INTO football.team_cross_source_map(
  season,league_name,canonical_team_name,api_team_id,api_team_name,understat_team_id,understat_team_name,mapping_method,confidence,notes,updated_dttm
)
SELECT
  season,league_name,canonical_team_name,api_team_id,api_team_name,understat_team_id,understat_team_name,mapping_method,confidence,notes,NOW()
FROM tmp_team_cross_source_map;

DELETE FROM football.player_cross_source_map
 WHERE season = {args.season}
   AND league_name = '{args.league_name.replace("'", "''")}';

DROP TABLE IF EXISTS tmp_player_cross_source_map;
CREATE TEMP TABLE tmp_player_cross_source_map (LIKE football.player_cross_source_map INCLUDING DEFAULTS);
\\copy tmp_player_cross_source_map(season,league_name,canonical_team_name,canonical_player_name,api_player_id,api_player_name,api_team_id,api_team_name,understat_player_id,understat_player_name,understat_team_id,understat_team_name,mapping_method,confidence,notes) FROM '{sql_quote_path(p_csv)}' WITH (FORMAT csv, HEADER true, NULL '');
INSERT INTO football.player_cross_source_map(
  season,league_name,canonical_team_name,canonical_player_name,api_player_id,api_player_name,api_team_id,api_team_name,understat_player_id,understat_player_name,understat_team_id,understat_team_name,mapping_method,confidence,notes,updated_dttm
)
SELECT
  season,league_name,canonical_team_name,canonical_player_name,api_player_id,api_player_name,api_team_id,api_team_name,understat_player_id,understat_player_name,understat_team_id,understat_team_name,mapping_method,confidence,notes,NOW()
FROM tmp_player_cross_source_map;
"""
        run_psql(args, sql)


def main() -> None:
    args = parse_args()
    if not Path(args.schema_file).exists():
        raise RuntimeError(f"Schema file not found: {args.schema_file}")

    api_teams_sql = f"""
    SELECT DISTINCT team_id, team_name
    FROM (
      SELECT home_team_id AS team_id, home_team AS team_name
      FROM football.api_football_schedule
      WHERE season = {args.season} AND league_id = {args.api_league_id}
      UNION
      SELECT away_team_id AS team_id, away_team AS team_name
      FROM football.api_football_schedule
      WHERE season = {args.season} AND league_id = {args.api_league_id}
    ) t
    WHERE team_name IS NOT NULL
    ORDER BY team_name
    """
    under_teams_sql = f"""
    SELECT DISTINCT team_id, team_name
    FROM (
      SELECT home_team_id AS team_id, home_team_name AS team_name
      FROM football.understat_league_matches
      WHERE season = {args.season} AND league_code = '{args.understat_league_code.replace("'", "''")}'
      UNION
      SELECT away_team_id AS team_id, away_team_name AS team_name
      FROM football.understat_league_matches
      WHERE season = {args.season} AND league_code = '{args.understat_league_code.replace("'", "''")}'
    ) t
    WHERE team_name IS NOT NULL
    ORDER BY team_name
    """

    api_players_sql = f"""
    SELECT DISTINCT
      player_id, player_name, team_id, team_name, minutes, goals_total AS goals
    FROM football.api_football_player_comp_season_stats
    WHERE season = {args.season}
      AND league_id = {args.api_league_id}
      AND player_name IS NOT NULL
    """
    under_players_sql = f"""
    SELECT DISTINCT
      player_id, player_name, team_title AS team_name, NULL::INT AS team_id, minutes, goals
    FROM football.understat_league_players
    WHERE season = {args.season}
      AND league_code = '{args.understat_league_code.replace("'", "''")}'
      AND player_name IS NOT NULL
    """

    api_teams = query_df(args, api_teams_sql)
    under_teams = query_df(args, under_teams_sql)
    api_players = query_df(args, api_players_sql)
    # Always enrich API players with match-level rows joined to schedule.
    # This captures winter transfers where one player appears for 2+ teams in the same season.
    team_ids = [str(int(x)) for x in api_teams["team_id"].dropna().unique().tolist()]
    if team_ids:
        team_ids_sql = ",".join(team_ids)
        api_players_fallback_sql = f"""
        WITH by_match AS (
          SELECT
            p.player_id,
            p.player_name,
            p.team_id,
            p.team_name,
            MAX(p.minutes) AS minutes,
            MAX(p.goals) AS goals
          FROM football.api_football_player_stats p
          JOIN football.api_football_schedule s
            ON s.fixture_id = p.fixture_id
          WHERE s.season = {args.season}
            AND s.league_id = {args.api_league_id}
            AND p.player_name IS NOT NULL
          GROUP BY p.player_id, p.player_name, p.team_id, p.team_name
        ),
        by_season AS (
          SELECT DISTINCT
            player_id, player_name, team_id, team_name, minutes, goals_total AS goals
          FROM football.api_football_player_season_stats
          WHERE season = {args.season}
            AND team_id IN ({team_ids_sql})
            AND player_name IS NOT NULL
        ),
        by_top_scorers AS (
          SELECT DISTINCT
            player_id, player_name, team_id, team_name, minutes_played AS minutes, goals_total AS goals
          FROM football.api_football_topscorers
          WHERE season = {args.season}
            AND league_id = {args.api_league_id}
            AND player_name IS NOT NULL
        ),
        by_top_assists AS (
          SELECT DISTINCT
            player_id, player_name, team_id, team_name, minutes_played AS minutes, NULL::INT AS goals
          FROM football.api_football_topassists_min
          WHERE season = {args.season}
            AND league_id = {args.api_league_id}
            AND player_name IS NOT NULL
        )
        SELECT * FROM by_match
        UNION
        SELECT * FROM by_season
        UNION
        SELECT * FROM by_top_scorers
        UNION
        SELECT * FROM by_top_assists
        """
        fallback_df = query_df(args, api_players_fallback_sql)
        if api_players.empty:
            api_players = fallback_df
        else:
            api_players = pd.concat([api_players, fallback_df], ignore_index=True)
    under_players = query_df(args, under_players_sql)
    api_players = expand_players_by_team(api_players)
    under_players = expand_players_by_team(under_players)
    if not api_players.empty:
        api_players["minutes_num"] = pd.to_numeric(api_players.get("minutes"), errors="coerce").fillna(0)
        api_players = (
            api_players.sort_values(["player_id", "team_name", "minutes_num"], ascending=[True, True, False])
            .drop_duplicates(subset=["player_id", "team_name"], keep="first")
            .drop(columns=["minutes_num"])
        )
    if not under_players.empty:
        under_players["minutes_num"] = pd.to_numeric(under_players.get("minutes"), errors="coerce").fillna(0)
        under_players = (
            under_players.sort_values(["player_id", "team_name", "minutes_num"], ascending=[True, True, False])
            .drop_duplicates(subset=["player_id", "team_name"], keep="first")
            .drop(columns=["minutes_num"])
        )

    team_map = build_team_map(api_teams, under_teams, args.team_fuzzy_threshold)

    # Understat league players table doesn't include team_id; enrich from team_map by team name.
    team_id_map = {
        canonical_team(str(r["understat_team_name"])): int(r["understat_team_id"])
        for _, r in team_map.iterrows()
        if pd.notna(r.get("understat_team_name")) and pd.notna(r.get("understat_team_id"))
    }
    under_players["team_id"] = under_players["team_name"].map(lambda x: team_id_map.get(canonical_team(str(x))))

    player_map = build_player_map(api_players, under_players, team_map, args.player_fuzzy_threshold)

    load_to_db(args, team_map, player_map)

    team_matched = len(team_map[(team_map["api_team_id"].notna()) & (team_map["understat_team_id"].notna())])
    player_matched = len(
        player_map[(player_map["api_player_id"].notna()) & (player_map["understat_player_id"].notna())]
    )
    print(
        f"[OK] team map rows={len(team_map)} matched={team_matched}; "
        f"player map rows={len(player_map)} matched={player_matched}"
    )


if __name__ == "__main__":
    main()
