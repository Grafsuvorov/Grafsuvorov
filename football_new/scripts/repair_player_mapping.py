import argparse
import html
import os
import re
import subprocess
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Dict, List, Optional, Tuple


DEFAULT_PSQL = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Auto-repair player_cross_source_map by pairing understat_only with api_only.")
    p.add_argument("--season", type=int, default=2025)
    p.add_argument("--league-name", default="Premier League")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--min-score", type=float, default=0.88)
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


def run_sql(args: argparse.Namespace, sql: str) -> str:
    env = os.environ.copy()
    env["PGPASSWORD"] = args.db_password
    proc = subprocess.run(psql_cmd(args), input=sql, text=True, capture_output=True, env=env, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"psql failed:\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")
    return proc.stdout


def normalize_name(v: str) -> str:
    s = html.unescape(str(v or "")).strip().lower()
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9\s-]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def canonical_tokens(v: str) -> List[str]:
    s = normalize_name(v).replace("-", " ")
    return [t for t in s.split() if t]


def score_name(u_name: str, a_name: str) -> Tuple[float, str]:
    u = canonical_tokens(u_name)
    a = canonical_tokens(a_name)
    if not u or not a:
        return 0.0, "none"

    us = " ".join(u)
    ass = " ".join(a)
    if us == ass:
        return 1.0, "exact"

    # one-token vs multi-token (e.g. "gabriel" vs "gabriel magalhaes")
    if len(u) == 1 and len(a) >= 2:
        if u[0] == a[0]:
            return 0.92, "single_firstname"
        if u[0] == a[-1]:
            return 0.90, "single_surname"
    if len(a) == 1 and len(u) >= 2:
        if a[0] == u[0]:
            return 0.92, "single_firstname"
        if a[0] == u[-1]:
            return 0.90, "single_surname"

    def possible_surnames(toks: List[str]) -> List[str]:
        if len(toks) <= 1:
            return toks
        out = [toks[-1]]
        if len(toks) >= 3:
            out.append(toks[-2])  # handles names like "ezri konsa ngoyo" vs "e konsa"
        return out

    # initial + (exact/near) surname patterns
    if len(u) >= 2 and len(a) >= 2 and u[0][0] == a[0][0]:
        u_s = possible_surnames(u)
        a_s = possible_surnames(a)
        best_sur = 0.0
        for su in u_s:
            for sa in a_s:
                best_sur = max(best_sur, SequenceMatcher(None, su, sa).ratio())
        if best_sur >= 0.97:
            return 0.95, "initial_surname"
        if best_sur >= 0.86:
            return 0.91, "initial_near_surname"

    # surname + first token similarity
    if u[-1] == a[-1]:
        first_sim = SequenceMatcher(None, u[0], a[0]).ratio()
        return 0.82 + 0.18 * first_sim, "surname_first"

    sim = SequenceMatcher(None, us, ass).ratio()
    return sim, "fuzzy"


@dataclass
class Row:
    id: int
    team: str
    canonical_name: str
    api_player_id: Optional[int]
    api_player_name: Optional[str]
    api_team_id: Optional[int]
    api_team_name: Optional[str]
    under_player_id: Optional[int]
    under_player_name: Optional[str]
    under_team_id: Optional[int]
    under_team_name: Optional[str]


def parse_tsv(text: str) -> List[Row]:
    rows: List[Row] = []
    for line in text.strip().splitlines():
        parts = line.split("\t")
        if len(parts) != 12:
            continue
        rows.append(
            Row(
                id=int(parts[0]),
                team=parts[1] or "",
                canonical_name=parts[2] or "",
                api_player_id=int(parts[3]) if parts[3] else None,
                api_player_name=parts[4] or None,
                api_team_id=int(parts[5]) if parts[5] else None,
                api_team_name=parts[6] or None,
                under_player_id=int(parts[7]) if parts[7] else None,
                under_player_name=parts[8] or None,
                under_team_id=int(parts[9]) if parts[9] else None,
                under_team_name=parts[10] or None,
                # 11 is mapping_method in query, ignored here
            )
        )
    return rows


def sql_quote(s: str) -> str:
    return s.replace("'", "''")


def main() -> None:
    args = parse_args()

    q = f"""
    SELECT
      id,
      canonical_team_name,
      canonical_player_name,
      COALESCE(api_player_id::text, ''),
      COALESCE(api_player_name, ''),
      COALESCE(api_team_id::text, ''),
      COALESCE(api_team_name, ''),
      COALESCE(understat_player_id::text, ''),
      COALESCE(understat_player_name, ''),
      COALESCE(understat_team_id::text, ''),
      COALESCE(understat_team_name, ''),
      mapping_method
    FROM football.player_cross_source_map
    WHERE season = {args.season}
      AND league_name = '{sql_quote(args.league_name)}'
      AND mapping_method IN ('understat_only','api_only')
    ORDER BY canonical_team_name, canonical_player_name;
    """
    out = run_sql(args, f"\\pset tuples_only on\n\\pset format unaligned\n\\pset fieldsep '\\t'\n{q}")
    all_rows = parse_tsv(out)

    under_only = [r for r in all_rows if r.under_player_id is not None and r.api_player_id is None]
    api_only = [r for r in all_rows if r.api_player_id is not None and r.under_player_id is None]

    by_team_api: Dict[str, List[Row]] = {}
    for r in api_only:
        by_team_api.setdefault(r.team, []).append(r)

    matched: List[Tuple[Row, Row, float, str]] = []
    used_api_ids = set()

    for u in under_only:
        cands = by_team_api.get(u.team, [])
        best = None
        best_score = 0.0
        best_reason = "none"
        for a in cands:
            if a.id in used_api_ids:
                continue
            score, reason = score_name(u.under_player_name or u.canonical_name, a.api_player_name or a.canonical_name)
            if score > best_score:
                best_score = score
                best = a
                best_reason = reason
        if best and best_score >= args.min_score:
            matched.append((u, best, round(best_score, 4), best_reason))
            used_api_ids.add(best.id)
            continue

        # 2nd pass: global unique high-confidence name match (for team drifts/transfers)
        g_best = None
        g_score = 0.0
        g_reason = "none"
        second = 0.0
        for a in api_only:
            if a.id in used_api_ids:
                continue
            score, reason = score_name(u.under_player_name or u.canonical_name, a.api_player_name or a.canonical_name)
            if score > g_score:
                second = g_score
                g_score = score
                g_best = a
                g_reason = reason
            elif score > second:
                second = score
        # require very high confidence and clear winner
        if g_best and g_score >= 0.97 and (g_score - second) >= 0.04:
            matched.append((u, g_best, round(g_score, 4), f"global_{g_reason}"))
            used_api_ids.add(g_best.id)

    print(f"[INFO] understat_only={len(under_only)} api_only={len(api_only)}")
    print(f"[INFO] candidate matches={len(matched)} (min_score={args.min_score})")

    if not matched:
        return

    # Preview top 20
    for u, a, sc, rs in matched[:20]:
        print(f"[PAIR] {u.team}: '{u.under_player_name}' -> '{a.api_player_name}' score={sc} ({rs})")

    if args.dry_run:
        print("[DRY] no DB updates")
        return

    statements = ["BEGIN;"]
    delete_ids = []
    for u, a, sc, rs in matched:
        method = f"auto_repair_{rs}"
        statements.append(
            f"""
UPDATE football.player_cross_source_map
SET api_player_id = {a.api_player_id if a.api_player_id is not None else 'NULL'},
    api_player_name = {("'" + sql_quote(a.api_player_name) + "'") if a.api_player_name else "NULL"},
    api_team_id = {a.api_team_id if a.api_team_id is not None else 'NULL'},
    api_team_name = {("'" + sql_quote(a.api_team_name) + "'") if a.api_team_name else "NULL"},
    mapping_method = '{method}',
    confidence = {sc},
    updated_dttm = NOW()
WHERE id = {u.id};
"""
        )
        delete_ids.append(str(a.id))

    if delete_ids:
        statements.append(
            f"DELETE FROM football.player_cross_source_map WHERE id IN ({','.join(delete_ids)});"
        )
    statements.append("COMMIT;")
    run_sql(args, "\n".join(statements))
    print(f"[OK] updated={len(matched)} deleted_api_only={len(delete_ids)}")


if __name__ == "__main__":
    main()
