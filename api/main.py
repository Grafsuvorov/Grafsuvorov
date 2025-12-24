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
from config import (TABLE_LOADING_HISTORY, TABLE_ENTITIES_META, TABLE_TABLES_META, TABLE_TABLE_COMPARE, TABLE_YT_SLA,TABLE_TABLES_META_CLICK, DATABASE_URL)
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

# Модель для ответа зависимостей
class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: str = None
    start_time: str = None
    avg_duration_minutes: Optional[float]  = None

TOP_DIRS = ["BI_FI", "BI_INVESTMENT", "BI_TAXES", "CASE_4", "DICT_LOADER", "MISHKADEV_TABLES", "FI_COUNTERPARTY", "ISUIP_INVESTMENT", "LOGISTICS", "TRANSPORTATION", "BI_SB_WUC", "BI_FI_FACT_PAYMENTS", "STG_LOADER", "SD_STOCKS", "SALES_SHIPMENT_FROM_PLANT", "SALES_MM", "SALES_MARGIN","MANAGEMENT_REPORTING_1", "TEST_SAP_ODATA_DELTA"]


_cached_meta_index = None
_cache_timestamp = 0
_CACHE_TTL = 86400  # 24 часа
@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
    except Exception as e:
        print("Ошибка при старте приложения:", e)



BASE_DIR = Path(__file__).resolve().parent.parent


@app.get("/api/routes")
def list_routes():
    return [route.path for route in app.routes]

@app.get("/ping")
def ping():
    return {"pong": True}

def get_cached_meta_and_index() -> Tuple[List[Dict], Dict[Tuple[str, str], List[Dict]]]:
    global _cached_meta_index, _cache_timestamp
    now = time.time()
    if _cached_meta_index is None or now - _cache_timestamp > _CACHE_TTL:
        print(" Обновляем кэш метаданных...")
        all_meta = find_all_meta_files(TOP_DIRS)
        reverse_index = build_reverse_index(all_meta)
        _cached_meta_index = (all_meta, reverse_index)
        _cache_timestamp = now
    return _cached_meta_index







def find_all_meta_files(top_dirs: List[str]) -> List[Dict]:
    all_meta = []
    for top_dir in top_dirs:
        for root, _, files in os.walk(BASE_DIR / top_dir):
            if "meta_data_file.yaml" in files:
                path = os.path.join(root, "meta_data_file.yaml")
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        meta = yaml.safe_load(f)
                        start_time = None
                        if meta.get("start_date"):
                            try:
                                start_time = datetime.strptime(meta["start_date"], "%Y-%m-%d %H:%M:%S").time()
                            except:
                                pass
                        all_meta.append({
                            "table_schema": meta.get("table_schema"),
                            "table_name": meta.get("table_name"),
                            "entity_id": meta.get("entity_id"),
                            "entity_name": meta.get("entity_name"),
                            "depends_on": meta.get("depends_on", {}),
                            "start_time": start_time,
                            "table_id": meta.get("table_id")
                        })
                except Exception as e:
                    print(f"Error reading {path}: {e}")
    return all_meta

def build_reverse_index(all_meta: List[Dict]) -> Dict[Tuple[str, str], List[Dict]]:
    reverse_index = {}
    for meta in all_meta:
        consumer_schema = meta["table_schema"]
        consumer_table = meta["table_name"]
        entity_id = meta["entity_id"]
        entity_name = meta.get("entity_name")
        start_time = meta.get("start_time")
        table_id = meta.get("table_id")
        depends_on = meta["depends_on"]
        for dep_schema, tables in depends_on.items():
            for table in tables:
                key = (dep_schema, table)
                reverse_index.setdefault(key, []).append({
                    "schema": consumer_schema,
                    "table_name": consumer_table,
                    "entity_id": entity_id,
                    "entity_name": entity_name,
                    "start_time": start_time,
                    "table_id": table_id
                })
    return reverse_index

def recursive_reverse_search(
    start_schema: str,
    start_table: str,
    reverse_index: Dict[Tuple[str, str], List[Dict]],
    visited: Set[Tuple[str, str]] = None
) -> List[Dict]:
    if visited is None:
        visited = set()
    key = (start_schema, start_table)
    if key in visited:
        return []
    visited.add(key)
    dependents = reverse_index.get(key, [])
    result = []
    for dep in dependents:
        result.append(dep)
        result.extend(
            recursive_reverse_search(dep["schema"], dep["table_name"], reverse_index, visited)
        )
    return result

@app.get("/api/dependencies", response_model=List[DependencyItem])
def get_dependencies(table: str = Query(..., description="Format: schema.table")):
    try:
        target_schema, target_table = table.split(".")
    except ValueError:
        return JSONResponse(content=[], media_type="application/json; charset=utf-8")

    all_meta, reverse_index = get_cached_meta_and_index()
    result = recursive_reverse_search(target_schema, target_table, reverse_index)

    seen = set()
    unique_sorted = []
    for item in sorted(result, key=lambda x: x.get("start_time") or datetime.strptime("00:00:00", "%H:%M:%S").time()):
        key = (item["schema"], item["table_name"])
        if key not in seen:
            seen.add(key)
            unique_sorted.append(item)

    output = []
    with engine.connect() as conn:
        for i, row in enumerate(unique_sorted, 1):
            avg_minutes = None
            if row.get("table_id"):
                avg_query = text(f"""
                    SELECT AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm))/60.0) AS avg_duration
                    FROM {TABLE_LOADING_HISTORY}
                    WHERE object_id = :object_id 
                      and object_type='table'
                      AND loading_state = 'SUCCESS'
                      AND loading_finish_dttm >= NOW() - INTERVAL '7 days'
                """)
                avg_result = conn.execute(avg_query, {"object_id": row["table_id"]})
                avg_value = avg_result.scalar()
                avg_minutes = round(avg_value, 2) if avg_value else None
            if row.get("entity_id"):
                # последнее время загрузки entity
                load_result = conn.execute(text(f"""
                           SELECT entity_last_load FROM {TABLE_ENTITIES_META} WHERE entity_id = :eid
                       """), {"eid": row["entity_id"]})
                dt_val = load_result.scalar()
                if isinstance(dt_val, datetime):
                    last_load = dt_val.strftime("%Y-%m-%d %H:%M:%S")

            output.append(DependencyItem(
                step=i,
                schema=row["schema"],
                table_name=row["table_name"],
                entity_id=row["entity_id"],
                entity_name=row.get("entity_name"),
                start_time=last_load,
                avg_duration_minutes=avg_minutes
            ))

    return JSONResponse(content=[item.dict() for item in output], media_type="application/json; charset=utf-8")

@app.get("/api/failures")
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
                row["last_success_time"] = row["last_success_time"].strftime("%Y-%m-%d %H:%M:%S") if row["last_success_time"] else None
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/api/entities")
def get_failed_tables():
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
                row["entity_last_load"] = row["entity_last_load"].strftime("%Y-%m-%d %H:%M:%S") if row[
                    "entity_last_load"] else None
                row["entity_name"] = row["entity_name"]
                row["entity_load_interval"] = row["entity_load_interval"]
                row["entity_load_status"] = row["entity_load_status"]
                cleaned.append(row)


            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})



@app.get("/api/timeline")
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

@app.get("/api/metrics")
def get_metrics():
    try:
        with engine.connect() as conn:
            total_tables = conn.execute(text(f"""
                SELECT COUNT(*) FROM {TABLE_TABLES_META} WHERE flag_active = true
            """)).scalar()

            error_count = conn.execute(text(f"""
                SELECT COUNT(*)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'FAILED' and object_type='table'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            avg_duration = conn.execute(text(f"""
                SELECT ROUND(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' and object_type='table'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            active_entities = conn.execute(text(f"""
                SELECT COUNT(*) FROM {TABLE_ENTITIES_META} WHERE flag_active = true
            """)).scalar()

            return JSONResponse(content={
                "total_tables": total_tables,
                "error_count": error_count,
                "avg_duration_minutes": float(avg_duration) if avg_duration is not None else None,
                "active_entities": active_entities
            }, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})





def find_path_case_insensitive(parent_path: Path, name: str) -> Path | None:
    for item in parent_path.iterdir():
        if item.name.lower() == name.lower():
            return item
    return None

@app.get("/api/card/{schema}/{table}")
def get_table_card_info_by_path(schema: str, table: str):
    for top in TOP_DIRS:
        entity_folder = BASE_DIR / top
        if not entity_folder.exists():
            continue

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
        table_id = meta.get("table_id")
        avg_duration = None
        last_success_time = None
        table_size_mb = None

        if table_id:
            try:
                with engine.connect() as conn:
                    duration_result = conn.execute(text(f"""
                        SELECT round(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE loading_state = 'SUCCESS'  and object_type='table'
                          AND object_id = :object_id
                    """), {"object_id": table_id})
                    avg_duration = float(duration_result.scalar() or 0)

                    time_result = conn.execute(text(f"""
                        SELECT table_last_load
                        FROM {TABLE_TABLES_META}
                        WHERE table_id = :object_id
                    """), {"object_id": table_id})
                    dt_val = time_result.scalar()
                    if isinstance(dt_val, datetime):
                        last_success_time = dt_val.strftime("%Y-%m-%d %H:%M:%S")

                    result = conn.execute(text("""
                        SELECT pg_total_relation_size(:full_table_name)::bigint / 1024 / 1024
                    """), {"full_table_name": f"{schema.lower()}.{table.lower()}"})
                    table_size_mb = int(result.scalar() or 0)
            except Exception as e:
                print(f"Ошибка при получении метрик: {e}")

        meta["avg_duration_minutes"] = avg_duration
        meta["last_success_time"] = last_success_time
        meta["table_size_mb"] = table_size_mb

        return JSONResponse(content=meta, media_type="application/json; charset=utf-8")

    print(f"[WARN] Table {schema}.{table} not found in any of TOP_DIRS")
    return JSONResponse(status_code=404, content={"error": "Table not found in any folder"})


@app.get("/api/tables")
def list_all_tables():
    all_tables = []
    for top in TOP_DIRS:
        top_path = BASE_DIR / top
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

@app.get("/api/inconsistencies")
def get_dependency_violations():
    all_meta, _ = get_cached_meta_and_index()
    dependency_pairs = []


    for meta in all_meta:
        dependent_schema = meta.get("table_schema")
        dependent_table = meta.get("table_name")
        depends_on = meta.get("depends_on", {})
        for source_schema, source_tables in depends_on.items():
            for source_table in source_tables:
                dependency_pairs.append((
                    (source_schema, source_table),
                    (dependent_schema, dependent_table)
                ))


    all_tables = set()
    for src, dep in dependency_pairs:
        all_tables.add(src)
        all_tables.add(dep)


    last_loads = {}
    with engine.connect() as conn:
        for schema, table in all_tables:
            result = conn.execute(text(f"""
                SELECT table_last_load
                FROM {TABLE_TABLES_META}
                WHERE  entity_id not in (50,49,48) and table_schema = :schema AND table_name = :table
            """), {"schema": schema, "table": table})
            dt = result.scalar()
            last_loads[(schema, table)] = dt


    problems = []
    for (src_schema, src_table), (dep_schema, dep_table) in dependency_pairs:
        src_time = last_loads.get((src_schema, src_table))
        dep_time = last_loads.get((dep_schema, dep_table))

        if src_time and dep_time and dep_time < src_time:
            problems.append({
                "source_schema": src_schema,
                "source_table": src_table,
                "source_last_load": src_time.strftime("%Y-%m-%d %H:%M:%S"),
                "dependent_schema": dep_schema,
                "dependent_table": dep_table,
                "dependent_last_load": dep_time.strftime("%Y-%m-%d %H:%M:%S")
            })

    return JSONResponse(content=problems, media_type="application/json; charset=utf-8")


@app.get("/api/sla")
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
                --regexp_split_to_table(regexp_replace(regexp_replace(table_name, E'_view+', '', 'g'), E'view_+', '', 'g'), E'\\n') AS split_table
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
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\s+"([^"]+)"\."([^"]+)"'))[1] as schema_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_view, 'DROP VIEW IF EXISTS\s+"([^"]+)"\."([^"]+)"'))[2] as table_name_view,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\s+"([^"]+)"\."([^"]+)"'))[1] as schema_name_table,
        	(REGEXP_MATCHES(ddl_clickhouse_target, 'DROP TABLE IF EXISTS\s+"([^"]+)"\."([^"]+)"'))[2] as table_name_table,
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

@app.get("/api/slowest-tables")
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
    for top_dir in TOP_DIRS:
        top_path = BASE_DIR / top_dir
        if not top_path.exists():
            continue
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



@app.get("/api/dependencies-down/{schema}/{table}")
def get_dependencies_down(schema: str, table: str):
    key = f"{schema}.{table}"
    try:
        all_meta = load_all_meta()
        if key not in all_meta:
            return JSONResponse(status_code=404, content={"error": "table not found"})

        edges = get_dependency_edges(key, all_meta)
        return {
            "central_node": key,
            "edges": edges
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

@app.get("/api/dependencies-graph/{schema}/{table}")
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

from fastapi import APIRouter, HTTPException
router = APIRouter()
app.include_router(router)

from sqlalchemy import bindparam

@router.get("/api/gantt/{schema}/{table:path}")
def get_gantt_data(schema: str, table: str):
    try:
        raw_meta = get_cached_meta_and_index()
        all_meta_list, _ = get_cached_meta_and_index()
        all_meta = {
            f"{m['table_schema']}.{m['table_name']}": m
            for m in all_meta_list
        }

        start_table = f"{schema}.{table}"
        if start_table not in all_meta:
            return JSONResponse(status_code=404, content={"error": f"'{start_table}' not found in meta"})

        edges = get_dependency_edges(start_table, all_meta)
        all_tables = {edge["source"] for edge in edges} | {edge["target"] for edge in edges}
        all_tables.add(start_table)

        table_to_id = {
            t: all_meta[t]["table_id"]
            for t in all_tables
            if t in all_meta and all_meta[t].get("table_id")
        }

        if not table_to_id:
            return JSONResponse(content=[], media_type="application/json")

        id_list = list(table_to_id.values())

        query = text(f"""
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
        """).bindparams(bindparam("id_list", expanding=True))

        with engine.connect() as conn:
            rows = conn.execute(query, {"id_list": id_list}).mappings().all()

        loading_times = {
            row["object_id"]: {
                "start": row["loading_start_dttm"],
                "end": row["loading_finish_dttm"]
            }
            for row in rows
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
            result.append({
                "table_id": row["object_id"],
                "table_name": table_name,
                "start": row["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_start_dttm"] else None,
                "end": row["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S") if row["loading_finish_dttm"] else None,
                "is_bad": table_name in bad_tables
            })

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
                row["table_last_load"] = row["table_last_load"].strftime("%Y-%m-%d %H:%M:%S") if row[
                    "table_last_load"] else None
                row["table_name"] = row["table_name"]
                row["entity_name"] = row["entity_name"]
                cleaned.append(row)

            return JSONResponse(content=cleaned, media_type="application/json; charset=utf-8")

    except Exception as e:
        print("❌ Ошибка при получении данных об ошибках:", str(e))
        return JSONResponse(status_code=500, content={"error": str(e)})

app.include_router(router)


