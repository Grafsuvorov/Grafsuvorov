PS C:\Users\SuvorovND\GIT\table-dependency-viewer> python .\generate_stg_files.py                                                                          
Traceback (most recent call last):
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 270, in <module>
    sys.exit(main())
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 250, in main
    args = parse_args()
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 43, in parse_args
    parser.add_argument("SAPSR3", required=True)
  File "C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\argparse.py", line 1398, in add_argument
    kwargs = self._get_positional_kwargs(*args, **kwargs)
  File "C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\argparse.py", line 1514, in _get_positional_kwargs
    raise TypeError(msg)
TypeError: 'required' is an invalid argument for positionals


import argparse
import os
import re
import sys
from datetime import datetime
from dataclasses import dataclass
from typing import Iterable, List, Optional

try:
    import psycopg2
except ImportError:  # pragma: no cover - optional runtime dependency
    psycopg2 = None


@dataclass
class Metadata:
    table_name: str
    table_schema: str
    table_id: int
    source_id: int
    source_type: str
    flag_has_views: bool
    table_load_mode: str
    job_id: int
    job_name: str
    table_loading_index: int
    entity_id: int
    entity_name: str
    object_type: str
    load_interval_days: int
    load_interval_hours: int
    load_interval_minutes: int
    load_interval_seconds: int
    flag_waiting_dag_finished: bool
    start_date: str
    depends_on_raw_ext: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate STG SQL/YAML files using etl_source_to_greenplum_new output.",
    )
    parser.add_argument("SAPSR3", required=True)
    parser.add_argument("KLAH", required=True)
    parser.add_argument("STG", required=True)
    parser.add_argument("KLAH", required=True)
    parser.add_argument("1", required=True, type=int)
    parser.add_argument("RN", default="")
    parser.add_argument('"MANDT" || "CLINT"', required=True)
    parser.add_argument("ALL", default="ALL")

    parser.add_argument("39", required=True, type=int)
    parser.add_argument("SALES_MM", required=True)

    parser.add_argument("1359", type=int, default=0)
    parser.add_argument("1", type=int, default=1)
    parser.add_argument("ORACLE_ERP_PROD", default="ORACLE_ERP_PROD")
    parser.add_argument("false", action="store_true")
    parser.add_argument("--table-load-mode", default="TRUNCATE_INIT")
    parser.add_argument("--job-id", type=int, default=296)
    parser.add_argument("--job-name", default="STG_JOB")
    parser.add_argument("--table-loading-index", type=int, default=1)
    parser.add_argument("--object-type", default="TABLE")
    parser.add_argument("--load-interval-days", type=int, default=1)
    parser.add_argument("--load-interval-hours", type=int, default=0)
    parser.add_argument("--load-interval-minutes", type=int, default=0)
    parser.add_argument("--load-interval-seconds", type=int, default=0)
    parser.add_argument("--flag-waiting-dag-finished", action="store_true")
    parser.add_argument("--start-date", default=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    parser.add_argument("--out-dir", default=".")
    parser.add_argument("--dsn")
    parser.add_argument("10.66.229.171")
    parser.add_argument("5432", type=int)
    parser.add_argument("dwh")
    parser.add_argument("gpetl")
    parser.add_argument("gpetl")
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def build_call_query(args: argparse.Namespace, fields_list: str) -> str:
    return (
        "select tech_etl.etl_source_to_greenplum_new(\n"
        "    v_source_schema_name := %s,\n"
        "    v_source_table_name := %s,\n"
        "    v_fields_list := %s,\n"
        "    v_target_schema_name := %s,\n"
        "    v_target_table_name := %s,\n"
        "    v_server_id := %s,\n"
        "    v_distribution_field := %s,\n"
        "    v_pk := %s\n"
        ");"
    ), (
        args.source_schema,
        args.source_table,
        fields_list,
        args.target_schema,
        args.target_table,
        args.server_id,
        args.distribution_field,
        args.pk,
    )


def connect(args: argparse.Namespace):
    if psycopg2 is None:
        raise RuntimeError("psycopg2 is required. Install it with pip install psycopg2-binary.")
    if args.dsn:
        return psycopg2.connect(args.dsn)
    return psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
    )


def collect_items(notices: Iterable[str], rows: Iterable[Iterable[str]]) -> List[str]:
    items: List[str] = []
    for notice in notices:
        if not notice:
            continue
        if isinstance(notice, bytes):
            notice = notice.decode("utf-8", errors="replace")
        items.append(str(notice))
    for row in rows:
        if not row:
            continue
        for item in row:
            if item is None:
                continue
            items.append(str(item))
    return items


LABELS = (
    "Insert query:",
    "DML INSERT QUERY:",
    "QUERY CREATE WITH FIELDS:",
    "Value:",
    "Status:",
)


def extract_section(items: Iterable[str], label: str) -> Optional[str]:
    terminators = "|".join(re.escape(item) for item in LABELS)
    pattern = re.compile(
        rf"{re.escape(label)}\s*(.*?)(?=\n(?:{terminators})|\Z)",
        re.IGNORECASE | re.DOTALL,
    )
    for item in items:
        match = pattern.search(item)
        if match:
            return match.group(1).strip()
    return None


def fetch_queries(args: argparse.Namespace) -> tuple[str, str]:
    query, params = build_call_query(args, args.fields_list)
    with connect(args) as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            rows = cur.fetchall() if cur.description else []

        notices = getattr(conn, "notices", [])

    items = collect_items(notices, rows)

    insert_query = extract_section(items, "DML INSERT QUERY:") or extract_section(items, "Insert query:")
    create_query = extract_section(items, "QUERY CREATE WITH FIELDS:")

    if not insert_query:
        raise RuntimeError("Insert query not found in database output.")
    if not create_query:
        raise RuntimeError("Create-with-fields query not found in database output.")

    return insert_query, create_query


def build_metadata(args: argparse.Namespace) -> Metadata:
    return Metadata(
        table_name=args.target_table,
        table_schema=args.target_schema.lower(),
        table_id=args.table_id,
        source_id=args.source_id,
        source_type=args.source_type,
        flag_has_views=args.flag_has_views,
        table_load_mode=args.table_load_mode,
        job_id=args.job_id,
        job_name=args.job_name,
        table_loading_index=args.table_loading_index,
        entity_id=args.entity_id,
        entity_name=args.entity_name,
        object_type=args.object_type,
        load_interval_days=args.load_interval_days,
        load_interval_hours=args.load_interval_hours,
        load_interval_minutes=args.load_interval_minutes,
        load_interval_seconds=args.load_interval_seconds,
        flag_waiting_dag_finished=args.flag_waiting_dag_finished,
        start_date=args.start_date,
        depends_on_raw_ext=f"{args.source_table}_READ",
    )


def render_metadata(meta: Metadata) -> str:
    return (
        f"table_name: {meta.table_name}\n"
        f"table_schema: {meta.table_schema}\n"
        f"table_id: {meta.table_id}\n"
        f"source_id: {meta.source_id}\n"
        f"source_type: {meta.source_type}\n"
        f"flag_has_views: {str(meta.flag_has_views).lower()}\n"
        f"table_load_mode: {meta.table_load_mode}\n"
        f"job_id: {meta.job_id}\n"
        f"job_name: {meta.job_name}\n"
        f"table_loading_index: {meta.table_loading_index}\n"
        f"entity_id: {meta.entity_id}\n"
        f"entity_name: {meta.entity_name}\n"
        f"object_type: {meta.object_type}\n"
        "table_load_interval:\n"
        f"  days: {meta.load_interval_days}\n"
        f"  hours: {meta.load_interval_hours}\n"
        f"  minutes: {meta.load_interval_minutes}\n"
        f"  seconds: {meta.load_interval_seconds}\n"
        f"flag_waiting_dag_finished: {str(meta.flag_waiting_dag_finished).lower()}\n"
        f"start_date: '{meta.start_date}'\n"
        f"sql_query_recreate_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/{meta.entity_name}/{meta.table_schema}/{meta.table_name.lower()}/sql_query_recreate_init.sql\n"
        f"sql_query_insert_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/{meta.entity_name}/{meta.table_schema}/{meta.table_name.lower()}/sql_query_insert_init.sql\n"
        f"sql_query_truncate: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/{meta.entity_name}/{meta.table_schema}/{meta.table_name.lower()}/sql_query_truncate.sql\n"
        "depends_on:\n"
        "  raw_ext:\n"
        f"    - {meta.depends_on_raw_ext}\n"
    )


def ensure_write_path(path: str, overwrite: bool) -> None:
    if os.path.exists(path) and not overwrite:
        raise RuntimeError(f"File already exists: {path}")


def write_file(path: str, content: str, overwrite: bool) -> None:
    ensure_write_path(path, overwrite)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(content.rstrip() + "\n")


def main() -> int:
    args = parse_args()

    insert_query, create_query = fetch_queries(args)

    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    meta = build_metadata(args)
    metadata_content = render_metadata(meta)
    truncate_sql = f'truncate {args.target_schema.lower()}."{args.target_table}";'

    write_file(os.path.join(out_dir, "meta_data_file.yaml"), metadata_content, args.overwrite)
    write_file(os.path.join(out_dir, "sql_query_recreate_init.sql"), create_query, args.overwrite)
    write_file(os.path.join(out_dir, "sql_query_insert_init.sql"), insert_query, args.overwrite)
    write_file(os.path.join(out_dir, "sql_query_truncate.sql"), truncate_sql, args.overwrite)

    return 0


if __name__ == "__main__":
    sys.exit(main())
