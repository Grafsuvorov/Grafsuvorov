from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set
from pydantic import BaseModel
import os
import yaml

from datetime import datetime
from sqlalchemy import create_engine, text
from typing import Optional
from pathlib import Path
import traceback
from datetime import datetime, date
from decimal import Decimal
import time
from typing import List, Dict, Tuple
from datetime import datetime
from sqlalchemy import text
import re
import json

from config import (
    TABLE_LOADING_HISTORY,
    TABLE_ENTITIES_META,
    TABLE_TABLES_META,
    TABLE_TABLE_COMPARE,
    TABLE_YT_SLA,
    TABLE_TABLES_META_CLICK,
    DATABASE_URL,
)

app = FastAPI()
# CORS для взаимодействия с фронтом
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение
engine = create_engine(DATABASE_URL)
from fastapi import APIRouter, HTTPException

router = APIRouter()
print("BOOT FILE:", __file__)

from sqlalchemy import bindparam

# Модель для ответа зависимостей
class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: str = None
    start_time: str = None
    avg_duration_minutes: Optional[float] = None


TOP_DIRS = [
    "BI_FI",
    "BI_INVESTMENT",
    "BI_TAXES",
    "CASE_4",
    "DICT_LOADER",
    "MISHKADEV_TABLES",
    "FI_COUNTERPARTY",
    "ISUIP_INVESTMENT",
    "LOGISTICS",
    "TRANSPORTATION",
    "BI_SB_WUC",
    "BI_FI_FACT_PAYMENTS",
    "STG_LOADER",
    "SD_STOCKS",
    "SALES_SHIPMENT_FROM_PLANT",
    "SALES_MM",
    "SALES_MARGIN",
    "MANAGEMENT_REPORTING_1",
    "TEST_SAP_ODATA_DELTA",
]

_cached_meta_index = None
_cache_timestamp = 0
_CACHE_TTL = 86400  # 24 часа

_order_breaches_cache = None
_order_breaches_ts = 0
_ORDER_BREACHES_TTL = 300  # 5 минут

def compute_order_breaches():
    """
    ТЯЖЁЛАЯ логика расчёта order breaches.
    НИЧЕГО НЕ ЗНАЕТ ПРО HTTP.
    """
    resp = get_dependency_violations()
    rows = json.loads(resp.body)

    grouped = {}

    for r in rows:
        target = f"{r['dependent_schema']}.{r['dependent_table']}"
        source = f"{r['source_schema']}.{r['source_table']}"

        src_time = datetime.fromisoformat(r["source_last_load"])
        tgt_time = datetime.fromisoformat(r["dependent_last_load"])
        gap_sec = (src_time - tgt_time).total_seconds()

        g = grouped.setdefault(target, {
            "target_fqn": target,
            "target_last_load": r["dependent_last_load"],
            "worst_upstream": None,
            "worst_upstream_time": None,
            "worst_gap_sec": 0,
            "violations": []
        })

        g["violations"].append({
            "source_fqn": source,
            "gap_sec": gap_sec,
            "source_last_load": r["source_last_load"],
            "dependent_last_load": r["dependent_last_load"],
        })

        if gap_sec > g["worst_gap_sec"]:
            g["worst_gap_sec"] = gap_sec
            g["worst_upstream"] = source
            g["worst_upstream_time"] = r["source_last_load"]

    result = []
    for g in grouped.values():
        gap_min = g["worst_gap_sec"] / 60
        if gap_min > 30:
            sev = "CRITICAL"
        elif gap_min > 5:
            sev = "MAJOR"
        else:
            sev = "WARNING"

        g["severity"] = sev
        g["gap_minutes"] = round(gap_min, 1)
        g["violations_count"] = len(g["violations"])
        result.append(g)

    result.sort(key=lambda x: x["worst_gap_sec"], reverse=True)
    return result

def get_cached_order_breaches():
    global _order_breaches_cache, _order_breaches_ts

    now = time.time()
    if _order_breaches_cache and now - _order_breaches_ts < _ORDER_BREACHES_TTL:
        return _order_breaches_cache

    print("⚠️ rebuilding orderbreaches cache")
    result = compute_order_breaches()

    _order_breaches_cache = result
    _order_breaches_ts = now
    return result

def get_cached_meta_and_index():
    global _cached_meta_index, _cache_timestamp
    now = time.time()
    if _cached_meta_index and now - _cache_timestamp < _CACHE_TTL:
        return _cached_meta_index

    all_meta = []
    for entity_root in iter_meta_dirs():
        for root, _, files in os.walk(entity_root):
            if "meta_data_file.yaml" not in files:
                continue
            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text("utf-8")) or {}
                all_meta.append({
                    "table_schema": meta.get("table_schema"),
                    "table_name": meta.get("table_name"),
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "depends_on": meta.get("depends_on") or {},
                    "table_id": meta.get("table_id"),
                })
            except Exception as e:
                print("META ERROR:", path, e)

    reverse = {}
    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])
        for src_schema, tables in m["depends_on"].items():
            for src_table in tables:
                reverse.setdefault((src_schema, src_table), []).append({
                    "schema": consumer[0],
                    "table_name": consumer[1],
                    "entity_id": m["entity_id"],
                    "entity_name": m["entity_name"],
                    "table_id": m["table_id"],
                })

    _cached_meta_index = (all_meta, reverse)
    _cache_timestamp = now
    return _cached_meta_index

def norm(s: str | None) -> str | None:
    return s.lower() if isinstance(s, str) else s

def normalize_fqn(table_fqn: str) -> tuple[str, str]:
    """
    Всегда возвращает (schema, table) в lowercase
    """
    s = table_fqn.strip().lower()

    if "/" in s and "." in s:
        schema, rest = s.split(".", 1)
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema}.{rest}"

    if "." not in s:
        raise ValueError("Expected schema.table")

    return tuple(s.split(".", 1))

@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
        get_cached_order_breaches()  # 🔥 прогрев orderbreaches
    except Exception as e:
        print("Ошибка при старте приложения:", e)


BASE_DIR = Path(__file__).resolve().parent.parent
META_PARENT_DIRS = [BASE_DIR / "project", BASE_DIR]


def iter_meta_dirs(targets: List[str] | None = None):
    """Yield existing metadata directories, searching both root and project/* trees."""
    seen = set()
    names = targets or TOP_DIRS
    for parent in META_PARENT_DIRS:
        if not parent.exists():
            continue
        for name in names:
            candidate = parent / name
            if not candidate.exists():
                continue
            real = candidate.resolve()
            if real in seen:
                continue
            seen.add(real)
            yield candidate

def resolve_dependencies(schema: str, table: str) -> List[DependencyItem]:
    all_meta, reverse_index = get_cached_meta_and_index()

    visited = set()
    result = []

    def walk(s, t):
        if (s, t) in visited:
            return
        visited.add((s, t))
        for dep in reverse_index.get((s, t), []):
            result.append(dep)
            walk(dep["schema"], dep["table_name"])

    walk(schema, table)

    uniq = []
    seen = set()
    for r in result:
        key = (r["schema"], r["table_name"])
        if key not in seen:
            seen.add(key)
            uniq.append(r)

    out = []
    with engine.connect() as conn:
        for i, r in enumerate(uniq, 1):
            avg = None
            if r.get("table_id"):
                avg = conn.execute(
                    text(f"""
                        SELECT round((avg(extract(epoch from (loading_finish_dttm-loading_start_dttm))/60))::numeric,2)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE object_id=:id AND loading_state='SUCCESS'
                    """),
                    {"id": r["table_id"]}
                ).scalar()

            out.append(DependencyItem(
                step=i,
                schema=r["schema"],
                table_name=r["table_name"],
                entity_id=r["entity_id"],
                entity_name=r.get("entity_name"),
                avg_duration_minutes=avg,
            ))
    return out

@router.get("/api/routes")
def list_routes():
    return [route.path for route in app.routes]


@router.get("/ping")
def ping():
    return {"pong": True}





def find_all_meta_files(top_dirs: list[str]) -> list[dict]:
    all_meta = []

    for entity_root in iter_meta_dirs(top_dirs):
        for root, _, files in os.walk(entity_root):
            if "meta_data_file.yaml" not in files:
                continue

            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

                all_meta.append({
                    "table_schema": norm(meta.get("table_schema")),
                    "table_name": norm(meta.get("table_name")),
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "table_id": meta.get("table_id"),
                    "depends_on": {
                        norm(k): [norm(t) for t in v]
                        for k, v in (meta.get("depends_on") or {}).items()
                    },
                })
            except Exception as e:
                print(f"[META ERROR] {path}: {e}")

    return all_meta



def build_reverse_index(all_meta: list[dict]) -> dict[tuple[str, str], list[dict]]:
    reverse = {}

    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])

        for src_schema, tables in (m.get("depends_on") or {}).items():
            for src_table in tables:
                key = (src_schema, src_table)

                reverse.setdefault(key, []).append({
                    "schema": consumer[0],
                    "table_name": consumer[1],
                    "entity_id": m.get("entity_id"),
                    "entity_name": m.get("entity_name"),
                    "table_id": m.get("table_id"),
                })

    return reverse




def recursive_reverse_search(
    schema: str,
    table: str,
    reverse_index: dict,
    visited: set | None = None
):
    if visited is None:
        visited = set()

    key = (schema, table)
    if key in visited:
        return []

    visited.add(key)

    result = []
    for dep in reverse_index.get(key, []):
        result.append(dep)
        result.extend(
            recursive_reverse_search(
                dep["schema"],
                dep["table_name"],
                reverse_index,
                visited
            )
        )

    return result


@router.get("/api/dependencies", response_model=List[DependencyItem])
def get_dependencies(table: str = Query(...)):
    try:
        schema, table = table.split(".")
    except ValueError:
        return []
    return resolve_dependencies(schema, table)


@router.get("/api/failures")
def get_failed_tables():
    query = f"""
     SELECT
        table_schema as object_schema,
        object_name AS table_name,
        l1.object_type,
        message AS error_message,
        loading_finish_dttm AS error_time,
        (
            SELECT MAX(loading_finish_dttm)
            FROM {TABLE_LOADING_HISTORY} AS l2
            WHERE l2.object_name = l1.object_name
              AND l2.object_type = l1.object_type
              AND l2.loading_state = 'SUCCESS'
        ) AS last_success_time
    FROM {TABLE_LOADING_HISTORY} l1
    inner join {TABLE_TABLES_META} tm on l1.object_id = tm.table_id
    WHERE loading_state = 'FAILED' and l1.object_type='table'
    ORDER BY loading_finish_dttm DESC
    LIMIT 10
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(query)).mappings().all()

            cleaned = []
            for r in rows:
                row = dict(r)
                row["schema"] = row["object_schema"]
                row["error_time"] = row["error_time"].strftime("%Y-%m-%d %H:%M:%S") if row["error_time"] else None
                row["last_success_time"] = (
                    row["last_success_time"].strftime("%Y-%m-%d %H:%M:%S") if row["last_success_time"] else None
                )
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entities")
def get_entities():
    query = f"""
     SELECT
        entity_id,entity_name,entity_last_load,entity_load_interval::varchar
        ,entity_load_status
            FROM {TABLE_ENTITIES_META} AS l2
            where flag_active order by entity_last_load, entity_name
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(query)).mappings().all()

            cleaned = []
            for r in rows:
                row = dict(r)
                row["entity_id"] = row["entity_id"]
                row["entity_last_load"] = (
                    row["entity_last_load"].strftime("%Y-%m-%d %H:%M:%S") if row["entity_last_load"] else None
                )
                row["entity_name"] = row["entity_name"]
                row["entity_load_interval"] = row["entity_load_interval"]
                row["entity_load_status"] = row["entity_load_status"]
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/timeline")
def get_table_timeline(table_name: str):
    query = f"""
    SELECT
        loading_start_dttm,
        loading_finish_dttm,
        loading_state,
        message,
        EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) AS duration_seconds
    FROM {TABLE_LOADING_HISTORY}
    WHERE object_name = :table_name and object_type='table'
    ORDER BY loading_finish_dttm DESC
    LIMIT 5
    """
    with engine.connect() as conn:
        result = conn.execute(text(query), {"table_name": table_name}).fetchall()
        columns = result[0].keys() if result else []
        return [dict(zip(columns, row)) for row in result]


@router.get("/api/metrics")
def get_metrics():
    try:
        with engine.connect() as conn:
            total_tables = conn.execute(text(f"SELECT COUNT(*) FROM {TABLE_TABLES_META} WHERE flag_active = true")).scalar()

            error_count = conn.execute(
                text(
                    f"""
                SELECT COUNT(*)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'FAILED' and object_type='table'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '10 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """
                )
            ).scalar()

            avg_duration = conn.execute(
                text(
                    f"""
                SELECT ROUND(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' and object_type='table'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """
                )
            ).scalar()

            active_entities = conn.execute(text(f"SELECT COUNT(*) FROM {TABLE_ENTITIES_META} WHERE flag_active = true")).scalar()

            return JSONResponse(
                content={
                    "total_tables": total_tables,
                    "error_count": error_count,
                    "avg_duration_minutes": float(avg_duration) if avg_duration is not None else None,
                    "active_entities": active_entities,
                },
                media_type="application/json; charset=utf-8",
            )
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


def find_path_case_insensitive(parent_path: Path, name: str) -> Path | None:
    for item in parent_path.iterdir():
        if item.name.lower() == name.lower():
            return item
    return None


@router.get("/api/card/{schema}/{table}")
def get_table_card_info_by_path(schema: str, table: str):
    for entity_folder in iter_meta_dirs():
        schema_folder = find_path_case_insensitive(entity_folder, schema)
        if not schema_folder:
            continue

        table_folder = find_path_case_insensitive(schema_folder, table)
        if not table_folder:
            continue

        yaml_file = table_folder / "meta_data_file.yaml"
        if not yaml_file.exists():
            return JSONResponse(status_code=404, content={"error": "meta_data_file.yaml not found"})

        try:
            with open(yaml_file, encoding="utf-8") as f:
                meta = yaml.safe_load(f)
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": str(e)})

        def read_sql_file(filename: str) -> str:
            file_path = table_folder / filename
            return file_path.read_text(encoding="utf-8") if file_path.exists() else f"-- {filename} not found"

        meta["sql_query_insert_init_sql"] = read_sql_file("sql_query_insert_init.sql")
        meta["sql_query_recreate_init_sql"] = read_sql_file("sql_query_recreate_init.sql")
        meta["sql_query_truncate_sql"] = read_sql_file("sql_query_truncate.sql")

        # метрики
        # метрики
        table_id = meta.get("table_id")
        avg_duration = None
        last_success_time = None
        table_size_mb = None

        if table_id:
            try:
                with engine.connect() as conn:
                    duration_result = conn.execute(
                        text(
                            f"""
                        SELECT round(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE loading_state = 'SUCCESS'
                          AND object_type='table'
                          AND object_id = :object_id
                    """
                        ),
                        {"object_id": table_id},
                    )
                    avg_duration = float(duration_result.scalar() or 0)

                    time_result = conn.execute(
                        text(
                            f"""
                        SELECT table_last_load
                        FROM {TABLE_TABLES_META}
                        WHERE table_id = :object_id
                    """
                        ),
                        {"object_id": table_id},
                    )
                    dt_val = time_result.scalar()
                    if isinstance(dt_val, datetime):
                        last_success_time = dt_val.strftime("%Y-%m-%d %H:%M:%S")

                    # ✅ ВОТ ТУТ — НОВЫЙ БЕЗОПАСНЫЙ КОД
                    size_sql = text("""
                        SELECT
                          pg_total_relation_size(
                            to_regclass(:full_table_name)
                          )::bigint / 1024 / 1024
                    """)

                    size_result = conn.execute(
                        size_sql,
                        {"full_table_name": f"{schema.lower()}.{table.lower()}"},
                    ).scalar()

                    table_size_mb = int(size_result) if size_result is not None else None

            except Exception as e:
                print(f"Ошибка при получении метрик: {e}")

        meta["avg_duration_minutes"] = avg_duration
        meta["last_success_time"] = last_success_time
        meta["table_size_mb"] = table_size_mb

        return JSONResponse(content=meta, media_type="application/json; charset=utf-8")

    print(f"[WARN] Table {schema}.{table} not found in any of TOP_DIRS")
    return JSONResponse(status_code=404, content={"error": "Table not found in any folder"})


@router.get("/api/tables")
def list_all_tables():
    all_tables = []
    for top_path in iter_meta_dirs():
        for schema_path in top_path.iterdir():
            if not schema_path.is_dir():
                continue
            for table_path in schema_path.iterdir():
                if not table_path.is_dir():
                    continue
                yaml_path = table_path / "meta_data_file.yaml"
                if yaml_path.exists():
                    try:
                        with open(yaml_path, encoding="utf-8") as f:
                            meta = yaml.safe_load(f)
                            schema = meta.get("table_schema")
                            table = meta.get("table_name")
                            if schema and table:
                                all_tables.append(f"{schema}.{table}")
                    except:
                        continue
    return JSONResponse(content=sorted(all_tables))


@router.get("/api/inconsistencies")
def get_dependency_violations():
    all_meta, _ = get_cached_meta_and_index()
    dependency_pairs = []

    for meta in all_meta:
        dependent_schema = meta.get("table_schema")
        dependent_table = meta.get("table_name")
        depends_on = meta.get("depends_on", {})
        for source_schema, source_tables in depends_on.items():
            for source_table in source_tables:
                dependency_pairs.append(((source_schema, source_table), (dependent_schema, dependent_table)))

    all_tables = set()
    for src, dep in dependency_pairs:
        all_tables.add(src)
        all_tables.add(dep)

    last_loads = {}
    with engine.connect() as conn:
        for schema, table in all_tables:
            result = conn.execute(
                text(
                    f"""
                SELECT table_last_load
                FROM {TABLE_TABLES_META}
                WHERE  entity_id not in (50,49,48) and table_schema = :schema AND table_name = :table
            """
                ),
                {"schema": schema, "table": table},
            )
            dt = result.scalar()
            last_loads[(schema, table)] = dt

    problems = []
    for (src_schema, src_table), (dep_schema, dep_table) in dependency_pairs:
        src_time = last_loads.get((src_schema, src_table))
        dep_time = last_loads.get((dep_schema, dep_table))

        if src_time and dep_time and dep_time < src_time:
            problems.append(
                {
                    "source_schema": src_schema,
                    "source_table": src_table,
                    "source_last_load": src_time.strftime("%Y-%m-%d %H:%M:%S"),
                    "dependent_schema": dep_schema,
                    "dependent_table": dep_table,
                    "dependent_last_load": dep_time.strftime("%Y-%m-%d %H:%M:%S"),
                }
            )

    return JSONResponse(content=problems, media_type="application/json; charset=utf-8")


@router.get("/api/sla")
def get_sla_monitoring():
    query = f"""
        WITH exploded AS (
            SELECT 
                s.report,
                s.source_table,
                s.owner_report,
                s.load_update_table,
                s.load_update_report,
                s.load_interval,
                s.table_name,
                regexp_split_to_table(s.table_name, E'\\n') AS split_table
            FROM {TABLE_YT_SLA} s
        ),
        cleaned AS (
            SELECT *,
                   trim(split_table) AS clean_table,
                   split_part(trim(split_table), '.', 1) AS schema_name,
                   split_part(trim(split_table), '.', 2) AS table_name_only
            FROM exploded
        ),
        click as (
        select 
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[1] as schema_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[2] as table_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[1] as schema_name_table,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\\s+"([^"]+)"\\."([^"]+)"'))[2] as table_name_table,
        	table_last_upload
        from {TABLE_TABLES_META_CLICK} ),
        joined AS (
            SELECT 
                c.report,
                c.source_table,
                c.owner_report,
                c.load_update_table,
                c.load_update_report,
                c.load_interval,
                c.table_name AS original_table_name,
                c.clean_table,
                coalesce(tm.table_last_load, cl.table_last_upload, clt.table_last_upload)  as table_last_load
            FROM cleaned c
            LEFT JOIN {TABLE_TABLES_META} tm
              ON tm.table_schema = c.schema_name
             AND tm.table_name = c.table_name_only and source_table='GP'
            left join click cl 
             ON cl.schema_name_view = c.schema_name
             AND cl.table_name_view = c.table_name_only and source_table='Click'
             left join click clt 
             ON clt.schema_name_table = c.schema_name
             AND clt.table_name_table = c.table_name_only and source_table='Click'
        ),
        with_flags AS (
            SELECT *,
                   (table_last_load IS NOT NULL AND
                    (
                        (position('сут' in lower(load_interval)) > 0 AND now() - table_last_load <= interval '24 hours')
                     OR (position('час' in lower(load_interval)) > 0 AND now() - table_last_load <= interval '1 hour')
                    )
                   ) AS sla_ok
            FROM joined
        )
        SELECT 
            report,
            source_table,
            owner_report,
            load_update_table,
            load_update_report,
            load_interval,
            original_table_name,
            json_agg(json_build_object(
                'table_name', clean_table,
                'table_last_load', CASE 
                    WHEN table_last_load IS NOT NULL 
                    THEN to_char(table_last_load, 'YYYY-MM-DD HH24:MI:SS') 
                    ELSE NULL 
                END,
                'sla_ok', sla_ok
            )) AS tables_info
        FROM with_flags
        GROUP BY report, source_table, owner_report, load_update_table, load_update_report, load_interval, original_table_name
        ORDER BY report;
    """
    try:
        with engine.connect() as conn:
            result = conn.execute(text(query))
            rows = [dict(row._mapping) for row in result]

        for row in rows:
            for table in row["tables_info"]:
                try:
                    if not table.get("table_last_load"):
                        table["table_last_load"] = "Нет данных"
                    table["sla_ok"] = bool(table["sla_ok"])
                except Exception as inner_error:
                    print("Ошибка при обработке таблицы:", table)
                    print("Ошибка:", inner_error)
                    table["sla_ok"] = False
                    table["table_last_load"] = "Нет данных"
            row["sla_ok"] = all(t["sla_ok"] for t in row["tables_info"])

        return JSONResponse(content=rows)

    except Exception as e:
        print("🔥 Общая ошибка SLA-эндпоинта 🔥")
        print(e)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/slowest-tables")
def get_slowest_tables():
    query = f"""
        SELECT 
            date_id, 
            entity_name, 
            table_schema, 
            table_name,
            ROUND(CAST(EXTRACT(EPOCH FROM (curr_finish_dttm - curr_start_dttm)) / 60 AS numeric), 1) AS duration
        FROM {TABLE_TABLE_COMPARE}
        ORDER BY (curr_finish_dttm - curr_start_dttm) DESC
        LIMIT 20
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(query)).mappings().all()
            cleaned_rows = []
            for row in rows:
                r = dict(row)

                if isinstance(r.get("date_id"), (datetime, date)):
                    r["date_id"] = r["date_id"].strftime("%Y-%m-%d")

                if isinstance(r.get("duration"), Decimal):
                    r["duration"] = float(r["duration"])
                cleaned_rows.append(r)
            return JSONResponse(content=cleaned_rows, media_type="application/json; charset=utf-8")
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


def load_all_meta():
    all_meta = {}
    for top_path in iter_meta_dirs():
        for schema_dir in top_path.iterdir():
            if not schema_dir.is_dir():
                continue
            for table_dir in schema_dir.iterdir():
                yaml_path = table_dir / "meta_data_file.yaml"
                if yaml_path.exists():
                    try:
                        with open(yaml_path, encoding="utf-8") as f:
                            meta = yaml.safe_load(f)
                            key = f"{meta['table_schema']}.{meta['table_name']}"
                            all_meta[key] = meta
                    except Exception:
                        continue
    return all_meta


def get_downstream_dependencies(start_table: str, all_meta: dict):
    result = set()
    stack = [start_table]

    while stack:
        current = stack.pop()
        if current in all_meta:
            deps = all_meta[current].get("depends_on", {})
            for schema, tables in deps.items():
                for table in tables:
                    full_name = f"{schema}.{table}"
                    if full_name not in result:
                        result.add(full_name)
                        stack.append(full_name)

    return sorted(result)


def get_dependency_edges(start_table: str, all_meta: dict) -> List[Dict[str, str]]:
    edges = []
    visited = set()
    stack = [start_table]

    while stack:
        current = stack.pop()
        if current in visited:
            continue
        visited.add(current)

        meta = all_meta.get(current)
        if not meta:
            continue

        depends_on = meta.get("depends_on", {})
        for source_schema, tables in depends_on.items():
            for source_table in tables:
                source = f"{source_schema}.{source_table}"
                edges.append({"source": source, "target": current})
                stack.append(source)

    return edges


@router.get("/api/dependencies-down/{schema}/{table}")
def get_dependencies_down(schema: str, table: str):
    key = f"{schema}.{table}"
    try:
        all_meta = load_all_meta()
        if key not in all_meta:
            return JSONResponse(status_code=404, content={"error": "table not found"})

        edges = get_dependency_edges(key, all_meta)
        return {"central_node": key, "edges": edges}

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dependencies-graph/{schema}/{table}")
def get_dependency_graph(schema: str, table: str):
    try:
        all_meta = load_all_meta()
        visited = set()
        edges = []

        def walk(current_table: str):
            if current_table in visited:
                return
            visited.add(current_table)

            meta = all_meta.get(current_table)
            if not meta:
                return

            depends_on = meta.get("depends_on", {})
            for source_schema, source_tables in depends_on.items():
                for source_table in source_tables:
                    source = f"{source_schema}.{source_table}"
                    edges.append({"source": source, "target": current_table})
                    walk(source)

        start = f"{schema}.{table}"
        walk(start)
        return {"centralNode": start, "edges": edges}

    except Exception as e:
        print("Ошибка при построении графа зависимостей:", e)
        return JSONResponse(status_code=500, content={"error": str(e)})





@router.get("/api/gantt/{schema}/{table:path}")
def get_gantt_data(schema: str, table: str):
    try:
        raw_meta = get_cached_meta_and_index()
        all_meta_list, _ = get_cached_meta_and_index()
        all_meta = {f"{m['table_schema']}.{m['table_name']}": m for m in all_meta_list}

        start_table = f"{schema}.{table}"
        if start_table not in all_meta:
            return JSONResponse(status_code=404, content={"error": f"'{start_table}' not found in meta"})

        edges = get_dependency_edges(start_table, all_meta)
        all_tables = {edge["source"] for edge in edges} | {edge["target"] for edge in edges}
        all_tables.add(start_table)

        table_to_id = {t: all_meta[t]["table_id"] for t in all_tables if t in all_meta and all_meta[t].get("table_id")}

        if not table_to_id:
            return JSONResponse(content=[], media_type="application/json")

        id_list = list(table_to_id.values())

        query = (
            text(
                f"""
            WITH cte AS (
                SELECT object_id, loading_start_dttm, loading_finish_dttm,
                       row_number() OVER (PARTITION BY object_id ORDER BY loading_start_dttm DESC) rn
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' AND object_type = 'table'
                  AND object_id IN :id_list
            )
            SELECT object_id, loading_start_dttm, loading_finish_dttm
            FROM cte
            WHERE rn = 1
            ORDER BY loading_start_dttm
        """
            )
            .bindparams(bindparam("id_list", expanding=True))
        )

        with engine.connect() as conn:
            rows = conn.execute(query, {"id_list": id_list}).mappings().all()

        loading_times = {
            row["object_id"]: {"start": row["loading_start_dttm"], "end": row["loading_finish_dttm"]} for row in rows
        }

        id_to_table = {v: k for k, v in table_to_id.items()}
        bad_tables = set()

        for edge in edges:
            src = edge["source"]
            tgt = edge["target"]
            src_id = table_to_id.get(src)
            tgt_id = table_to_id.get(tgt)
            if src_id and tgt_id:
                src_end = loading_times.get(src_id, {}).get("end")
                tgt_start = loading_times.get(tgt_id, {}).get("start")
                if src_end and tgt_start and src_end > tgt_start:
                    bad_tables.add(tgt)

        result = []
        for row in rows:
            table_name = id_to_table.get(row["object_id"], str(row["object_id"]))
            result.append(
                {
                    "table_id": row["object_id"],
                    "table_name": table_name,
                    "start": row["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_start_dttm"] else None,
                    "end": row["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_finish_dttm"] else None,
                    "is_bad": table_name in bad_tables,
                }
            )

        return JSONResponse(content=result, media_type="application/json")

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entities/{entity_id}/table-info")
def get_entity_table_info(entity_id: int):
    """
    Возвращает информацию по таблице из tech_etl.tables_meta для конкретной сущности.
    Поля: schema_name, tables_name, last_load, entity_name
    """
    sql = f"""
        SELECT
            table_schema,
            table_name,
            table_last_load,
            entity_name
        FROM {TABLE_TABLES_META}
        WHERE entity_id = :entity_id order by table_last_load
    """
    try:
        with engine.connect() as conn:
            rows = conn.execute(text(sql), {"entity_id": entity_id}).mappings().all()
            cleaned = []
            for r in rows:
                row = dict(r)
                row["table_schema"] = row["table_schema"]
                row["table_last_load"] = (
                    row["table_last_load"].strftime("%Y-%m-%d %H:%M:%S") if row["table_last_load"] else None
                )
                row["table_name"] = row["table_name"]
                row["entity_name"] = row["entity_name"]
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})





def get_table_id_by_fqn(conn, schema: str, table: str):
    q = text(
        f"""
        SELECT table_id
        FROM {TABLE_TABLES_META}
        WHERE table_schema = :schema
          AND table_name   = :table
        LIMIT 1
    """
    )
    return conn.execute(q, {"schema": schema, "table": table}).scalar()


def build_impact(table_fqn: str, deps: list, sla_resp):
    """
    Строит impact для инцидента:
    - затронутые сущности
    - количество downstream-таблиц
    - отчёты под риском
    - SLA-нарушения
    """

    affected_entities = set()
    blocked_tables = set()
    reports_at_risk = []
    sla_violations = 0

    # --- downstream tables ---
    for d in deps or []:
        schema = d.get("schema")
        table = d.get("table_name") or d.get("table")
        entity = d.get("entity_name")

        if schema and table:
            blocked_tables.add(f"{schema}.{table}")

        if entity:
            affected_entities.add(entity)

    # --- SLA ---
    try:
        if hasattr(sla_resp, "body"):
            sla_rows = json.loads(sla_resp.body.decode("utf-8"))
        else:
            sla_rows = sla_resp or []
    except Exception:
        sla_rows = []

    for row in sla_rows:
        tables = row.get("tables_info", [])
        for t in tables:
            if not t.get("sla_ok", True):
                sla_violations += 1
                reports_at_risk.append(row.get("report"))
                break

    return {
        "affected_entities": sorted(affected_entities),
        "blocked_tables_count": len(blocked_tables),
        "reports_at_risk": sorted(set(reports_at_risk)),
        "sla_violations": sla_violations,
    }

@router.get("/api/incident")
def get_incident(table_fqn: str = Query(...)):
    try:
        schema, table = table_fqn.split(".")
    except ValueError:
        return JSONResponse(status_code=400, content={"error": "schema.table expected"})

    with engine.connect() as conn:
        table_id = conn.execute(
            text(f"""
                SELECT table_id FROM {TABLE_TABLES_META}
                WHERE table_schema=:s AND table_name=:t
            """),
            {"s": schema, "t": table}
        ).scalar()

        if not table_id:
            return JSONResponse(status_code=404, content={"error": "table not found"})

        deps = [d.dict() for d in resolve_dependencies(schema, table)]

        rows = conn.execute(
            text(f"""
                SELECT loading_start_dttm, loading_finish_dttm, loading_state, message,
                       extract(epoch from (loading_finish_dttm-loading_start_dttm)) dur
                FROM {TABLE_LOADING_HISTORY}
                WHERE object_id=:id
                ORDER BY loading_finish_dttm DESC
                LIMIT 15
            """),
            {"id": table_id}
        ).mappings().all()

    timeline = [{
        "start": r["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S"),
        "finish": r["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S"),
        "state": r["loading_state"],
        "duration_sec": float(r["dur"]) if r["dur"] else None,
        "message": (r["message"] or "")[:180] or None
    } for r in rows]

    return {
        "summary": {
            "table_fqn": table_fqn,
            "state": "FAILING" if timeline and timeline[0]["state"] == "FAILED" else "RECOVERED",
        },
        "timeline": timeline,
        "dependencies": deps,
        "impact": {
            "blocked_tables_count": len(deps),
            "affected_entities": sorted({d["entity_name"] for d in deps if d.get("entity_name")}),
        }
    }


from collections import defaultdict
from datetime import timedelta

INCIDENT_WINDOW_MIN = 60  # минут


def group_failures(failures: list):
    incidents = []
    failures_sorted = sorted(
        [f for f in failures if f.get("error_time")],
        key=lambda x: x["error_time"],
        reverse=True
    )

    used = set()

    for i, f in enumerate(failures_sorted):
        if i in used:
            continue

        entity = f.get("entity_name")

        if not entity:
            all_meta, _ = get_cached_meta_and_index()
            meta = next(
                (m for m in all_meta if m["table_schema"] == f["schema"] and m["table_name"] == f["table_name"]),
                None,
            )
            entity = meta.get("entity_name") if meta else None

        entity = entity or f"{f['schema']}"
        f["entity_name"] = entity  # 🔴 фикс

        try:
            t0 = datetime.strptime(f["error_time"], "%Y-%m-%d %H:%M:%S")
        except Exception:
            continue

        group = [f]
        used.add(i)

        for j, other in enumerate(failures_sorted[i + 1 :], start=i + 1):
            if j in used:
                continue

            other_entity = other.get("entity_name")

            if not other_entity:
                all_meta, _ = get_cached_meta_and_index()
                meta = next(
                    (
                        m
                        for m in all_meta
                        if m["table_schema"] == other["schema"] and m["table_name"] == other["table_name"]
                    ),
                    None,
                )
                other_entity = meta.get("entity_name") if meta else None
                other_entity = other_entity or f"{other['schema']}"
                other["entity_name"] = other_entity

            if other_entity != entity:
                continue

            t1 = datetime.strptime(other["error_time"], "%Y-%m-%d %H:%M:%S")

            if abs((t0 - t1).total_seconds()) <= INCIDENT_WINDOW_MIN * 60:
                group.append(other)
                used.add(j)

        incidents.append(group)

    return incidents


from collections import defaultdict


@router.get("/api/incidents/active")
def get_active_incidents():
    failures_resp = get_failed_tables()
    failures = json.loads(failures_resp.body.decode("utf-8"))

    if not failures:
        return []

    grouped = group_failures(failures)

    by_entity = defaultdict(list)

    # 1️⃣ группируем все фейлы по сущности
    for group in grouped:
        if not group:
            continue
        entity = group[0].get("entity_name") or "UNKNOWN"
        by_entity[entity].extend(group)

    incidents = []

    # 2️⃣ агрегируем КРАТКО — без downstream
    for entity, rows in by_entity.items():
        failed_tables = set()
        last_failure = None

        for r in rows:
            table_fqn = f"{r['schema']}.{r['table_name']}"
            failed_tables.add(table_fqn)

            if not last_failure or r["error_time"] > last_failure:
                last_failure = r["error_time"]

        incidents.append(
            {
                "entity": entity,
                "severity": "CRITICAL",
                "failed_tables": len(failed_tables),
                "root_tables": sorted(failed_tables)[:3],
                "last_failure_time": last_failure,
            }
        )

    incidents.sort(key=lambda x: x["last_failure_time"], reverse=True)

    return incidents


@router.get("/api/incidents/history")
def get_incident_history():
    query = f"""
        SELECT
            t.table_schema || '.' || l.object_name AS table_fqn,
            COUNT(*) AS incidents_count,
            MAX(l.loading_finish_dttm) AS last_incident
     FROM {TABLE_LOADING_HISTORY} l
      left join {TABLE_TABLES_META} t on t.table_id=l.object_id
        WHERE l.loading_state = 'FAILED'
          AND l.object_type = 'table'
          AND l.loading_finish_dttm >= now() - interval '300 days'
        GROUP BY t.table_schema, l.object_name
        ORDER BY incidents_count DESC
        LIMIT 10
    """
    with engine.connect() as conn:
        rows = conn.execute(text(query)).mappings().all()

    return [
        {
            "table": r["table_fqn"],
            "count": r["incidents_count"],
            "last_incident": r["last_incident"].strftime("%Y-%m-%d %H:%M:%S")
            if r["last_incident"] else None
        }
        for r in rows
    ]
print("Reg")
@router.get("/api/orderbreaches")
def get_order_breaches():
    return get_cached_order_breaches()


app.include_router(router)
