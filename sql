Добавил диагностику и эксепты в scripts/audit_depends_on.py.

  Теперь можно понять, где проблема с путями:

  Запусти с дебагом:

  cd C:\Users\SuvorovND\GIT\table-dependency-viewer
  python scripts\audit_depends_on.py --root "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity" --debug --out
  reports\depends_audit.txt

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

import yaml


SQL_REF_RE = re.compile(r"\b([A-Za-z_][\w]*)\s*\.\s*(\"?[^\s,;\)\(]+\"?)")
IGNORE_SCHEMAS = {"information_schema", "pg_catalog"}


def _normalize_ident(value: str) -> str:
    return value.strip('"').strip().lower()


def extract_schema_table_refs(sql: str) -> Set[Tuple[str, str]]:
    refs: Set[Tuple[str, str]] = set()
    for match in SQL_REF_RE.finditer(sql):
        schema = _normalize_ident(match.group(1))
        table = _normalize_ident(match.group(2))
        if not schema or not table:
            continue
        if schema in IGNORE_SCHEMAS:
            continue
        refs.add((schema, table))
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


def iter_meta_files(root: Path) -> Iterable[Path]:
    yield from root.rglob("meta_data_file.yaml")


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def flatten_depends_on(depends_on: dict) -> Set[Tuple[str, str]]:
    flat: Set[Tuple[str, str]] = set()
    if not isinstance(depends_on, dict):
        return flat
    for schema, tables in depends_on.items():
        if not tables:
            continue
        schema_l = str(schema).strip().lower()
        if isinstance(tables, list):
            for table in tables:
                table_l = str(table).strip().strip('"').lower()
                if schema_l and table_l:
                    flat.add((schema_l, table_l))
    return flat


def build_meta_index(root: Path) -> Set[Tuple[str, str]]:
    index: Set[Tuple[str, str]] = set()
    for meta_path in iter_meta_files(root):
        data = load_yaml(meta_path)
        schema = str(data.get("table_schema", "")).strip().lower()
        table = str(data.get("table_name", "")).strip().lower()
        if schema and table:
            index.add((schema, table))
    return index


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit depends_on vs SQL references")
    parser.add_argument(
        "--root",
        default=r"C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity",
        help="Root directory with meta_data_file.yaml",
    )
    parser.add_argument("--out", default="", help="Write text report to file")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of files (for testing)")
    parser.add_argument("--debug", action="store_true", help="Print debug info")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    root_arg = Path(args.root)
    root = root_arg if root_arg.is_absolute() else (repo_root / root_arg).resolve()

    meta_index = build_meta_index(root)
    report_lines: List[str] = []

    count = 0
    if args.debug:
        print(f"[DEBUG] repo_root={repo_root}")
        print(f"[DEBUG] root={root}")
        print(f"[DEBUG] meta_index size={len(meta_index)}")
    for meta_path in iter_meta_files(root):
        try:
            data = load_yaml(meta_path)
        except Exception as exc:
            report_lines.append(f"{meta_path.relative_to(repo_root)}: ERROR read yaml -> {exc}")
            continue
        sql_path_raw = data.get("sql_query_insert_init")
        if not sql_path_raw:
            continue
        sql_path = resolve_sql_path(repo_root, root, sql_path_raw)
        if not sql_path or not sql_path.exists():
            report_lines.append(
                f"{meta_path.relative_to(repo_root)}: ERROR sql_query_insert_init not found -> {sql_path_raw}"
            )
            continue

        target_schema = str(data.get("table_schema", "")).strip().lower()
        target_table = str(data.get("table_name", "")).strip().lower()

        try:
            sql = sql_path.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:
            report_lines.append(f"{meta_path.relative_to(repo_root)}: ERROR read sql -> {exc}")
            continue
        refs = extract_schema_table_refs(sql)
        if target_schema and target_table:
            refs.discard((target_schema, target_table))

        depends_on = flatten_depends_on(data.get("depends_on", {}))

        missing = sorted(refs - depends_on)
        extra = sorted(depends_on - refs)
        unknown = sorted([pair for pair in depends_on if pair not in meta_index])

        if missing or extra or unknown:
            rel = str(meta_path.relative_to(repo_root))
            if missing:
                report_lines.append(f"{rel}: MISSING depends_on entries:")
                for schema, table in missing:
                    report_lines.append(f"  - {schema}.{table}")
            if extra:
                report_lines.append(f"{rel}: EXTRA depends_on entries (not in SQL):")
                for schema, table in extra:
                    report_lines.append(f"  - {schema}.{table}")
            if unknown:
                report_lines.append(f"{rel}: UNKNOWN depends_on entries (no meta):")
                for schema, table in unknown:
                    report_lines.append(f"  - {schema}.{table}")

        count += 1
        if args.limit and count >= args.limit:
            break

    if args.debug:
        print(f"[DEBUG] scanned meta files={count}")

    output = "\n".join(report_lines)
    if args.out:
        out_path = (repo_root / args.out).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output, encoding="utf-8")
        print(f"Wrote report to {out_path}")
    else:
        print(output)

    return 1 if report_lines else 0


if __name__ == "__main__":
    raise SystemExit(main())
