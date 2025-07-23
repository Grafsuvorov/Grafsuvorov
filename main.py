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
app = FastAPI()
import time
from typing import List, Dict, Tuple
from datetime import datetime
from sqlalchemy import text

# CORS для взаимодействия с фронтом
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение
DATABASE_URL = "postgresql+psycopg2://gpetl:gpetl@10.66.229.201:5432/dwh"
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

TOP_DIRS = ["BI_FI", "BI_INVESTMENT", "BI_TAXES", "CASE_4", "DICT_LOADER", "FI_COUNTERPARTY", "ISUIP_INVESTMENT", "LOGISTICS", "TRANSPORTATION", "BI_SB_WUC", "BI_FI_FACT_PAYMENTS", "STG_LOADER", "SD_STOCKS", "SALES_SHIPMENT_FROM_PLANT", "SALES_MM", "SALES_MARGIN","MANAGEMENT_REPORTING_1"]


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
                avg_query = text("""
                    SELECT AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm))/60.0) AS avg_duration
                    FROM tech_etl.log_objects_loading_history
                    WHERE object_id = :object_id
                      AND loading_state = 'SUCCESS'
                      AND loading_finish_dttm >= NOW() - INTERVAL '7 days'
                """)
                avg_result = conn.execute(avg_query, {"object_id": row["table_id"]})
                avg_value = avg_result.scalar()
                avg_minutes = round(avg_value, 2) if avg_value else None
            if row.get("entity_id"):
                # последнее время загрузки entity
                load_result = conn.execute(text("""
                           SELECT entity_last_load FROM tech_etl.entities_meta WHERE entity_id = :eid
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
    query = """
     SELECT
        table_schema as object_schema,
        object_name AS table_name,
        l1.object_type,
        message AS error_message,
        loading_finish_dttm AS error_time,
        (
            SELECT MAX(loading_finish_dttm)
            FROM tech_etl.log_objects_loading_history AS l2
            WHERE l2.object_name = l1.object_name
              AND l2.object_type = l1.object_type
              AND l2.loading_state = 'SUCCESS'
        ) AS last_success_time
    FROM tech_etl.log_objects_loading_history l1
    inner join tech_etl.tables_meta tm on l1.object_id = tm.table_id
    WHERE loading_state = 'FAILED'
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

@app.get("/api/timeline")
def get_table_timeline(table_name: str):
    query = """
    SELECT
        loading_start_dttm,
        loading_finish_dttm,
        loading_state,
        message,
        EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) AS duration_seconds
    FROM tech_etl.log_objects_loading_history
    WHERE object_name = :table_name
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
            total_tables = conn.execute(text("""
                SELECT COUNT(*) FROM tech_etl.tables_meta WHERE flag_active = true
            """)).scalar()

            error_count = conn.execute(text("""
                SELECT COUNT(*)
                FROM tech_etl.log_objects_loading_history
                WHERE loading_state = 'FAILED'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            avg_duration = conn.execute(text("""
                SELECT ROUND(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                FROM tech_etl.log_objects_loading_history
                WHERE loading_state = 'SUCCESS'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            active_entities = conn.execute(text("""
                SELECT COUNT(*) FROM tech_etl.entities_meta WHERE flag_active = true
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





@app.get("/api/card/{schema}/{table}")
def get_table_card_info_by_path(schema: str, table: str):
    schema = schema.lower()
    table = table.lower()
    for top in TOP_DIRS:
        entity_folder = BASE_DIR / top
        if not entity_folder.exists():
            continue
        potential_path = entity_folder / schema / table
        if potential_path.exists():
            yaml_file = potential_path / "meta_data_file.yaml"
            if not yaml_file.exists():
                return JSONResponse(status_code=404, content={"error": "meta_data_file.yaml not found"})
            try:
                with open(yaml_file, encoding="utf-8") as f:
                    meta = yaml.safe_load(f)
            except Exception as e:
                return JSONResponse(status_code=500, content={"error": str(e)})
            def read_sql_file(filename: str) -> str:
                file_path = potential_path / filename
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
                        duration_result = conn.execute(text("""
                            SELECT round(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric),1)
                            FROM tech_etl.log_objects_loading_history
                            WHERE loading_state = 'SUCCESS'
                              AND object_id = :object_id
                        """), {"object_id": table_id})
                        avg_duration = float(duration_result.scalar() or 0)
                        time_result = conn.execute(text("""
                            SELECT table_last_load
                            FROM tech_etl.tables_meta
                            WHERE table_id = :object_id
                        """), {"object_id": table_id})
                        dt_val = time_result.scalar()
                        if isinstance(dt_val, datetime):
                            last_success_time = dt_val.strftime("%Y-%m-%d %H:%M:%S")
                        result = conn.execute(text("""
                            SELECT pg_total_relation_size(:full_table_name)::bigint / 1024 / 1024
                        """), {"full_table_name": f"{schema}.{table}"})
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
            result = conn.execute(text("""
                SELECT table_last_load
                FROM tech_Etl.tables_meta
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


@app.get("/api/slowest-tables")
def get_slowest_tables():
    query = """
        SELECT 
            date_id, 
            entity_name, 
            table_schema, 
            table_name,
            ROUND(CAST(EXTRACT(EPOCH FROM (curr_finish_dttm - curr_start_dttm)) / 60 AS numeric), 1) AS duration
        FROM tech_monitoring.vw_table_compare
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