  python scripts\build_depends_on.py --file "C:
  \Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity\dm\sales_delivery_tracking\meta_data_file.yaml" --write

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

try:
    import yaml
except ModuleNotFoundError as exc:
    raise SystemExit("PyYAML is required. Install: python -m pip install pyyaml") from exc


FROM_JOIN_RE = re.compile(
    r"\b(?:from|join)\s+(\"?[A-Za-z_][\w]*\"?)\s*\.\s*(\"[^\"]+\"|[A-Za-z_][\w]*)",
    re.IGNORECASE,
)
IGNORE_SCHEMAS = {"information_schema", "pg_catalog"}


def _normalize_ident(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2:
        return raw[1:-1]
    return raw.strip('"').lower()


def extract_schema_table_refs(sql: str) -> Set[Tuple[str, str]]:
    refs: Set[Tuple[str, str]] = set()
    for match in FROM_JOIN_RE.finditer(sql):
        schema = _normalize_ident(match.group(1))
        table = _normalize_ident(match.group(2))
        if not schema or not table:
            continue
        schema_key = schema.lower()
        if schema_key in IGNORE_SCHEMAS:
            continue
        refs.add((schema_key, table))
    return refs


def resolve_sql_path(repo_root: Path, root_dir: Path, raw_path: str) -> Optional[Path]:
    if not raw_path:
        return None
    raw_path = raw_path.strip()
    raw_candidate = Path(raw_path)
    if raw_candidate.is_absolute() and raw_candidate.exists():
        return raw_candidate

    candidate = (repo_root / raw_path).resolve()
    if candidate.exists():
        return candidate
    candidate = (root_dir / raw_path).resolve()
    if candidate.exists():
        return candidate
    marker = "etl_loads_entity/"
    if marker in raw_path:
        suffix = raw_path.split(marker, 1)[1]
        candidate = (root_dir / suffix).resolve()
        if candidate.exists():
            return candidate
    return None


def _fallback_sql_path(meta_path: Path) -> Optional[Path]:
    candidate = meta_path.parent / "sql_query_insert_init.sql"
    return candidate if candidate.exists() else None


def build_depends_on_from_sql(sql_path: Path, target_schema: str, target_table: str) -> Dict[str, List[str]]:
    sql = sql_path.read_text(encoding="utf-8", errors="ignore")
    refs = extract_schema_table_refs(sql)

    target = (target_schema.lower(), target_table.lower())
    if target in refs:
        refs.remove(target)

    grouped: Dict[str, Set[str]] = defaultdict(set)
    for schema, table in refs:
        grouped[schema].add(table)

    # Sort for stable output
    depends_on: Dict[str, List[str]] = {}
    for schema in sorted(grouped.keys()):
        depends_on[schema] = sorted(grouped[schema])
    return depends_on


def iter_meta_files(root: Path) -> Iterable[Path]:
    yield from root.rglob("meta_data_file.yaml")


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def dump_yaml(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False, allow_unicode=True)


def _detect_root(repo_root: Path, arg_root: str) -> Path:
    if arg_root:
        root_arg = Path(arg_root)
        return root_arg if root_arg.is_absolute() else (repo_root / root_arg).resolve()

    candidates = [
        (repo_root / "etl_loads_entity").resolve(),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def main() -> int:
    parser = argparse.ArgumentParser(description="Build depends_on from sql_query_insert_init.sql")
    parser.add_argument("--root", default="", help="Root directory with meta_data_file.yaml")
    parser.add_argument("--file", default="", help="Single meta_data_file.yaml (absolute or relative to root)")
    parser.add_argument("--write", action="store_true", help="Write depends_on back to meta_data_file.yaml")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of files (for testing)")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    root = _detect_root(repo_root, args.root)

    count = 0
    updated = 0

    if args.file:
        file_arg = Path(args.file)
        if file_arg.is_absolute():
            meta_paths = [file_arg.resolve()]
        else:
            if file_arg.parts and file_arg.parts[0] == "etl_loads_entity":
                meta_paths = [(repo_root / file_arg).resolve()]
            else:
                meta_paths = [(root / file_arg).resolve()]
    else:
        meta_paths = list(iter_meta_files(root))

    for meta_path in meta_paths:
        data = load_yaml(meta_path)
        sql_path_raw = data.get("sql_query_insert_init")
        if not sql_path_raw:
            continue
        sql_path = resolve_sql_path(repo_root, root, sql_path_raw)
        if not sql_path or not sql_path.exists():
            fallback = _fallback_sql_path(meta_path)
            if fallback:
                sql_path = fallback
                print(f"[WARN] sql_query_insert_init path not found, used local file: {meta_path}")
            else:
                print(f"[WARN] sql_query_insert_init not found: {meta_path} -> {sql_path_raw}")
                continue

        target_schema = str(data.get("table_schema", "")).strip()
        target_table = str(data.get("table_name", "")).strip()
        if not target_schema or not target_table:
            print(f"[WARN] missing table_schema/table_name: {meta_path}")
            continue

        depends_on = build_depends_on_from_sql(sql_path, target_schema, target_table)

        count += 1
        if args.write:
            data["depends_on"] = depends_on
            dump_yaml(meta_path, data)
            updated += 1
        else:
            print(f"\n== {meta_path.relative_to(repo_root)} ==")
            print(yaml.safe_dump({"depends_on": depends_on}, sort_keys=False, allow_unicode=True))

        if args.limit and count >= args.limit:
            break

    if args.write:
        print(f"\nUpdated {updated} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
