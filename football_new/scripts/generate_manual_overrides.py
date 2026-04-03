import argparse
import csv
import html
import os
import re
import subprocess
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path
from typing import Dict, List, Tuple


DEFAULT_PSQL = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate manual override suggestions for unmatched player mappings.")
    p.add_argument("--season", type=int, default=2025)
    p.add_argument("--league-name", default="Premier League")
    p.add_argument("--out", default="player_mapping_manual_overrides_2025.csv")
    p.add_argument("--top-k", type=int, default=3)
    p.add_argument("--min-score", type=float, default=0.70)
    p.add_argument("--db-host", default=os.getenv("PGHOST", "localhost"))
    p.add_argument("--db-port", default=os.getenv("PGPORT", "5432"))
    p.add_argument("--db-name", default=os.getenv("PGDATABASE", "dwh"))
    p.add_argument("--db-user", default=os.getenv("PGUSER", "postgres"))
    p.add_argument("--db-password", default=os.getenv("PGPASSWORD", "0506"))
    p.add_argument("--psql", default=DEFAULT_PSQL)
    return p.parse_args()


def run_sql(args: argparse.Namespace, sql: str) -> str:
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
    proc = subprocess.run(cmd, input=sql, text=True, capture_output=True, env=env, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"psql failed:\n{proc.stderr}")
    return proc.stdout


def normalize(v: str) -> str:
    s = html.unescape(str(v or "")).strip().lower()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9\\s-]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def toks(v: str) -> List[str]:
    return [t for t in normalize(v).replace("-", " ").split() if t]


def score_name(u_name: str, a_name: str) -> Tuple[float, str]:
    u = toks(u_name)
    a = toks(a_name)
    if not u or not a:
        return 0.0, "none"
    us = " ".join(u)
    ass = " ".join(a)
    if us == ass:
        return 1.0, "exact"
    if len(u) == 1 and len(a) >= 2 and u[0] == a[0]:
        return 0.92, "single_firstname"
    if len(a) == 1 and len(u) >= 2 and a[0] == u[0]:
        return 0.92, "single_firstname"
    if len(u) >= 2 and len(a) >= 2 and u[0][0] == a[0][0]:
        if u[-1] == a[-1]:
            return 0.95, "initial_surname"
        sur = SequenceMatcher(None, u[-1], a[-1]).ratio()
        if sur >= 0.86:
            return 0.90, "initial_near_surname"
    # reversed names handling
    if len(u) >= 2 and len(a) >= 2 and u[0] == a[-1] and u[-1] == a[0]:
        return 0.94, "reversed_fullname"
    # surname/first hybrid
    if len(u) >= 2 and len(a) >= 2 and u[-1] == a[-1]:
        first = SequenceMatcher(None, u[0], a[0]).ratio()
        return 0.82 + 0.18 * first, "surname_first"
    return SequenceMatcher(None, us, ass).ratio(), "fuzzy"


def parse_rows(text: str) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for line in text.strip().splitlines():
        p = line.split("\t")
        if len(p) != 5:
            continue
        rows.append(
            {
                "id": p[0],
                "team": p[1],
                "canonical": p[2],
                "under_name": p[3],
                "api_name": p[4],
            }
        )
    return rows


def main() -> None:
    args = parse_args()
    q_under = f"""
    SELECT id, canonical_team_name, canonical_player_name, COALESCE(understat_player_name,''), ''
    FROM football.player_cross_source_map
    WHERE season={args.season}
      AND league_name='{args.league_name.replace("'", "''")}'
      AND mapping_method='understat_only'
    ORDER BY canonical_team_name, canonical_player_name
    """
    q_api = f"""
    SELECT id, canonical_team_name, canonical_player_name, '', COALESCE(api_player_name,'')
    FROM football.player_cross_source_map
    WHERE season={args.season}
      AND league_name='{args.league_name.replace("'", "''")}'
      AND mapping_method='api_only'
    ORDER BY canonical_team_name, canonical_player_name
    """
    under_txt = run_sql(args, f"\\pset tuples_only on\n\\pset format unaligned\n\\pset fieldsep '\\t'\n{q_under}")
    api_txt = run_sql(args, f"\\pset tuples_only on\n\\pset format unaligned\n\\pset fieldsep '\\t'\n{q_api}")
    under = parse_rows(under_txt)
    api = parse_rows(api_txt)

    by_team_api: Dict[str, List[Dict[str, str]]] = {}
    for a in api:
        by_team_api.setdefault(a["team"], []).append(a)

    out_rows: List[Dict[str, str]] = []
    for u in under:
        cands = by_team_api.get(u["team"], [])
        scored: List[Tuple[float, str, Dict[str, str]]] = []
        for a in cands:
            sc, rs = score_name(u["under_name"] or u["canonical"], a["api_name"] or a["canonical"])
            if sc >= args.min_score:
                scored.append((sc, rs, a))
        scored.sort(key=lambda x: x[0], reverse=True)
        top = scored[: args.top_k]
        if not top:
            out_rows.append(
                {
                    "apply": "0",
                    "season": str(args.season),
                    "league_name": args.league_name,
                    "canonical_team_name": u["team"],
                    "understat_row_id": u["id"],
                    "understat_player_name": u["under_name"],
                    "api_row_id": "",
                    "api_player_name_suggested": "",
                    "score": "",
                    "reason": "",
                    "note": "no_candidate",
                }
            )
            continue
        for sc, rs, a in top:
            out_rows.append(
                {
                    "apply": "0",
                    "season": str(args.season),
                    "league_name": args.league_name,
                    "canonical_team_name": u["team"],
                    "understat_row_id": u["id"],
                    "understat_player_name": u["under_name"],
                    "api_row_id": a["id"],
                    "api_player_name_suggested": a["api_name"],
                    "score": f"{sc:.4f}",
                    "reason": rs,
                    "note": "",
                }
            )

    out = Path(args.out)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "apply",
                "season",
                "league_name",
                "canonical_team_name",
                "understat_row_id",
                "understat_player_name",
                "api_row_id",
                "api_player_name_suggested",
                "score",
                "reason",
                "note",
            ],
        )
        w.writeheader()
        w.writerows(out_rows)
    print(f"[OK] wrote {out} rows={len(out_rows)}")


if __name__ == "__main__":
    main()
