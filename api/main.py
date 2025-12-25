from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
import json
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set
from pydantic import BaseModel
import os
import yaml
from datetime import datetime
from sqlalchemy import create_engine, text
from typing import Optional
from pathlib import Path
import re

app = FastAPI()

# CORS для взаимодействия с фронтом
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение к PostgreSQL
DATABASE_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
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

# Верхнеуровневые директории
PROJECT_DIR = Path(__file__).resolve().parent.parent / "project"

from functools import lru_cache

@lru_cache(maxsize=1)
def get_cached_meta():
    print("🔁 Загрузка YAML-файлов...")
    return find_all_meta_files(PROJECT_DIR)

@app.on_event("startup")
def preload_metadata():
    get_cached_meta()

def find_all_meta_files(base_dir: Path) -> List[Dict]:
    all_meta = []
    for root, _, files in os.walk(base_dir):
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

    all_meta = get_cached_meta()
    reverse_index = build_reverse_index(all_meta)
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
                    FROM public.log_objects_loading_history
                    WHERE object_id = :object_id
                      AND loading_state = 'SUCCESS'
                      AND loading_finish_dttm >= NOW() - INTERVAL '7 days'
                """)
                avg_result = conn.execute(avg_query, {"object_id": row["table_id"]})
                avg_value = avg_result.scalar()
                avg_minutes = round(avg_value, 2) if avg_value else None

            output.append(DependencyItem(
                step=i,
                schema=row["schema"],
                table_name=row["table_name"],
                entity_id=row["entity_id"],
                entity_name=row.get("entity_name"),
                start_time=row["start_time"].strftime("%H:%M:%S") if row["start_time"] else None,
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
            FROM public.log_objects_loading_history AS l2
            WHERE l2.object_name = l1.object_name
              AND l2.object_type = l1.object_type
              AND l2.loading_state = 'SUCCESS'
        ) AS last_success_time
    FROM public.log_objects_loading_history l1
    inner join tables_meta tm on l1.object_id = tm.table_id
    WHERE loading_state = 'FAILED'
    ORDER BY loading_finish_dttm DESC
    LIMIT 100
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
    FROM public.log_objects_loading_history
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
                SELECT COUNT(*) FROM tables_meta WHERE flag_active = true
            """)).scalar()

            error_count = conn.execute(text("""
                SELECT COUNT(*)
                FROM public.log_objects_loading_history
                WHERE loading_state = 'FAILED'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            avg_duration = conn.execute(text("""
                SELECT ROUND(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60), 1)
                FROM public.log_objects_loading_history
                WHERE loading_state = 'SUCCESS'
                  AND loading_start_dttm >= date_trunc('day', now() - interval '1 day') + interval '21 hour'
                  AND loading_start_dttm < date_trunc('day', now()) + interval '21 hour'
            """)).scalar()

            active_entities = conn.execute(text("""
                SELECT COUNT(*) FROM entities_meta WHERE flag_active = true
            """)).scalar()

            return JSONResponse(content={
                "total_tables": total_tables,
                "error_count": error_count,
                "avg_duration_minutes": avg_duration,
                "active_entities": active_entities
            }, media_type="application/json; charset=utf-8")
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})



BASE_DIR = Path(__file__).resolve().parent.parent / "project"

from datetime import datetime
from sqlalchemy import text

@app.get("/api/card/{schema}/{table}")
def get_table_card_info_by_path(schema: str, table: str):
    """
    Ищет YAML и SQL по пути: BASE_DIR / <ENTITY_NAME> / schema / table
    Пример: table-dependency-viewer/TRANSPORTATION/stg/LIPS/
    """
    for entity_folder in BASE_DIR.iterdir():
        potential_path = entity_folder / schema / table
        if potential_path.exists():
            yaml_file = potential_path / "meta_data_file.yaml"
            if not yaml_file.exists():
                return JSONResponse(status_code=404, content={"error": "table_meta.yaml not found"})

            try:
                with open(yaml_file, encoding="utf-8") as f:
                    meta = yaml.safe_load(f)
            except Exception as e:
                return JSONResponse(status_code=500, content={"error": str(e)})

            # Чтение SQL файлов из той же директории
            def read_sql_file(filename: str) -> str:
                file_path = potential_path / filename
                return file_path.read_text(encoding="utf-8") if file_path.exists() else f"-- {filename} not found"

            meta["sql_query_insert_init_sql"] = read_sql_file("sql_query_insert_init.sql")
            meta["sql_query_recreate_init_sql"] = read_sql_file("sql_query_recreate_init.sql")
            meta["sql_query_truncate_sql"] = read_sql_file("sql_query_truncate.sql")

            # ⏱ Средняя длительность загрузки
            table_id = meta.get("table_id")
            avg_duration = None
            last_success_time = None

            if table_id:
                try:
                    with engine.connect() as conn:
                        # Среднее время загрузки
                        duration_result = conn.execute(text("""
                            SELECT ROUND(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60), 1)
                            FROM public.log_objects_loading_history
                            WHERE loading_state = 'SUCCESS'
                              AND object_id = :object_id
                        """), {"object_id": table_id})
                        val = duration_result.scalar()
                        avg_duration = float(val) if val is not None else None

                        # Последнее время загрузки
                        time_result = conn.execute(text("""
                            SELECT table_last_load
                            FROM public.tables_meta
                            WHERE table_id = :object_id
                        """), {"object_id": table_id})
                        dt_val = time_result.scalar()
                        if isinstance(dt_val, datetime):
                            last_success_time = dt_val.strftime("%Y-%m-%d %H:%M:%S")
                except Exception as e:
                    print(f"Ошибка при получении метрик: {e}")

            meta["avg_duration_minutes"] = avg_duration
            meta["last_success_time"] = last_success_time

            return JSONResponse(content=meta, media_type="application/json; charset=utf-8")

    return JSONResponse(status_code=404, content={"error": "Table not found in any folder"})


@app.get("/api/tables")
def list_all_tables():
    all_tables = []
    for entity_path in PROJECT_DIR.iterdir():
        if not entity_path.is_dir():
            continue
        for schema_path in entity_path.iterdir():
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
    all_meta = get_cached_meta()
    dependency_pairs = []

    # Соберем пары: (source_schema, source_table) → (dependent_schema, dependent_table)
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

    # Получим последнее время загрузки для всех таблиц
    all_tables = set()
    for src, dep in dependency_pairs:
        all_tables.add(src)
        all_tables.add(dep)

    # Подготовим словарь: (schema, table) → last_load
    last_loads = {}
    with engine.connect() as conn:
        for schema, table in all_tables:
            result = conn.execute(text("""
                SELECT table_last_load
                FROM public.tables_meta
                WHERE table_schema = :schema AND table_name = :table
            """), {"schema": schema, "table": table})
            dt = result.scalar()
            last_loads[(schema, table)] = dt

    # Найдём несоответствия
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

@app.post("/api/reload-meta")
def reload_meta():
    get_cached_meta.cache_clear()
    get_cached_meta()
    return {"status": "Кэш мета-данных обновлён"}

def load_all_meta():
    all_meta = {}

    for entity_dir in PROJECT_DIR.glob("*/*/*"):
        yaml_path = entity_dir / "meta_data_file.yaml"
        if yaml_path.exists():
            with open(yaml_path, encoding="utf-8") as f:
                try:
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


@app.get("/api/sla")
def get_sla_monitoring():
    query = """
        SELECT 
          s.report,
          s.table_name,
          s.source_table,
          s.owner_report,
          s.load_update_table,
          s.load_update_report,
          s.load_interval,
          tm.table_last_load
        FROM yt_sla s
        LEFT JOIN tables_meta tm 
          ON CONCAT(tm.table_schema,tm.table_name) = s.table_name
    """
    with engine.connect() as conn:
        result = conn.execute(text(query))
        rows = [dict(row._mapping) for row in result]

    # Преобразуем: вычисляем, нарушен ли SLA
    for row in rows:
        last_load = row["table_last_load"]
        interval = row["load_interval"] or ""
        row["sla_ok"] = True

        if isinstance(last_load, datetime):
            hours_passed = (datetime.now() - last_load).total_seconds() / 3600
            if "сут" in interval.lower() and hours_passed > 24:
                row["sla_ok"] = False
            elif "час" in interval.lower() and hours_passed > 1:
                row["sla_ok"] = False
        else:
            row["sla_ok"] = False

        if last_load:
            row["table_last_load"] = last_load.strftime("%Y-%m-%d %H:%M:%S")
        else:
            row["table_last_load"] = "Нет данных"

    return rows

def build_system_focus(failures: list, sla_rows: list):
    failed_count = len(failures)
    sla_violations = sum(1 for s in sla_rows if not s.get("sla_ok", True))

    if failed_count > 0:
        return {
            "state": "DEGRADED",
            "title": "Частичная деградация системы",
            "summary": f"{failed_count} сбоев · {sla_violations} нарушений SLA"
        }

    if sla_violations > 0:
        return {
            "state": "RISK",
            "title": "Риск нарушения SLA",
            "summary": f"{sla_violations} витрин с нарушенным SLA"
        }

    return {
        "state": "OK",
        "title": "Система работает штатно",
        "summary": "Ошибок и нарушений SLA не обнаружено"
    }


def build_primary_incident(failures, sla_rows):
    if not failures:
        return None

    primary = failures[0]
    table_fqn = f"{primary['schema']}.{primary['table_name']}"

    # SLA для таблицы
    sla_row = next(
        (s for s in sla_rows if s["table_name"].endswith(primary["table_name"])),
        None
    )

    return {
        "severity": "CRITICAL",
        "table": {
            "schema": primary["schema"],
            "name": primary["table_name"],
            "fqn": table_fqn
        },
        "error": {
            "message": primary["error_message"],
            "time": primary["error_time"],
            "last_success_time": primary["last_success_time"]
        },
        "sla": {
            "enabled": sla_row is not None,
            "status": "VIOLATED" if sla_row and not sla_row["sla_ok"] else "OK",
            "interval": sla_row.get("load_interval") if sla_row else None
        }
    }


def build_secondary_incidents(failures, limit=5):
    items = []
    for f in failures[1:limit]:
        items.append({
            "severity": "CRITICAL",
            "table": f"{f['schema']}.{f['table_name']}",
            "type": "ERROR"
        })
    return items


def build_impact(primary_table_fqn, dependencies, sla_rows):
    entities = set()
    for d in dependencies:
        if d.get("entity_name"):
            entities.add(d["entity_name"])

    reports_at_risk = {
        s["report"] for s in sla_rows if not s.get("sla_ok", True)
    }

    return {
        "affected_entities": sorted(entities),
        "blocked_tables_count": len(dependencies),
        "reports_at_risk": sorted(reports_at_risk),
        "sla_violations": len(reports_at_risk)
    }


import json

@app.get("/api/control-center")
def get_control_center():
    # failures
    failures_resp = get_failed_tables()
    failures = json.loads(failures_resp.body.decode("utf-8"))

    # sla
    sla_rows = get_sla_monitoring()

    # metrics
    metrics_resp = get_metrics()
    metrics = json.loads(metrics_resp.body.decode("utf-8"))

    # system focus
    system_focus = build_system_focus(failures, sla_rows)

    # primary incident
    primary_incident = build_primary_incident(failures, sla_rows)

    dependencies = []
    impact = None

    if primary_incident:
        table_fqn = primary_incident["table"]["fqn"]

        try:
            deps_resp = get_dependencies(table=table_fqn)
            dependencies = json.loads(deps_resp.body.decode("utf-8"))
        except Exception as e:
            print("deps error:", e)
            dependencies = []

        impact = build_impact(
            table_fqn,
            dependencies,
            sla_rows
        )

    secondary = build_secondary_incidents(failures)

    return JSONResponse(
        content={
            "system_focus": system_focus,
            "primary_incident": primary_incident,
            "impact": impact,
            "dependencies": {
                "depth": max((d["step"] for d in dependencies), default=0),
                "tables": [
                    {
                        "schema": d["schema"],
                        "table": d["table_name"],
                        "entity": d.get("entity_name"),
                        "avg_duration_minutes": d.get("avg_duration_minutes")
                    }
                    for d in dependencies
                ]
            },
            "secondary_incidents": secondary,
            "metrics": metrics,
            "navigation": {
                "incidents": "/errors",
                "dependency_graph": "/dependency-graph",
                "tables": "/table-catalog",
                "sla": "/sla"
            }
        },
        media_type="application/json; charset=utf-8"
    )




from fastapi import APIRouter
router = APIRouter()
app.include_router(router)

from sqlalchemy import bindparam

@router.get("/api/gantt/{schema}/{table:path}")
def get_gantt_data(schema: str, table: str):
    try:
        raw_meta = get_cached_meta()
        all_meta = {
            f"{m['table_schema']}.{m['table_name']}": m
            for m in raw_meta
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

        query = text("""
            SELECT object_id, loading_start_dttm, loading_finish_dttm
            FROM public.log_objects_loading_history
            WHERE loading_state = 'SUCCESS'
              AND object_id IN :id_list
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

def normalize_fqn(table_fqn: str) -> str:
    """
    UI иногда шлёт stg./RUSAL/PERW или с лишними символами.
    Приводим к schema.table
    """
    if not table_fqn:
        return table_fqn

    # stg./RUSAL/PERW -> stg.RUSALPERW? (в твоём фронте раньше было replaceAll("/", ""))
    # но правильнее: schema.table, поэтому если пришло с /, пытаемся восстановить:
    # stg./RUSAL/PERW => schema=stg, table=RUSALPERW (как у тебя раньше)
    # Если у тебя таблицы реально называются PERW, тогда лучше передавать нормальный fqn.
    s = table_fqn.strip()

    # если видим "schema./SOMETHING/NAME" -> schema.NAME (склейка)
    if "/" in s and "." in s:
        schema_part = s.split(".", 1)[0]
        rest = s.split(".", 1)[1]
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema_part}.{rest}"

    # просто подчистим мусор
    s = s.replace(" ", "")
    return s

def get_table_id_by_fqn(conn, schema: str, table: str):
    q = text("""
        SELECT table_id
        FROM public.tables_meta
        WHERE table_schema = :schema
          AND table_name   = :table
        LIMIT 1
    """)
    return conn.execute(q, {"schema": schema, "table": table}).scalar()

@app.get("/api/incident")
def get_incident(table_fqn: str = Query(..., description="Format: schema.table")):
    """
    Агрегатор инцидента:
    - summary: повторяемость (24h/7d), подряд, last success/fail
    - timeline: последние события (FAIL/SUCCESS)
    - dependencies: downstream (как на dashboard)
    - impact: сущности/отчёты под риском (как у тебя в build_impact)
    """
    table_fqn = normalize_fqn(table_fqn)

    try:
        schema, table = table_fqn.split(".", 1)
    except ValueError:
        return JSONResponse(status_code=400, content={"error": "table_fqn must be schema.table"})

    with engine.connect() as conn:
        table_id = get_table_id_by_fqn(conn, schema, table)

        if not table_id:
            return JSONResponse(status_code=404, content={"error": "table not found in tables_meta", "table_fqn": table_fqn})

        # --- timeline (последние 15) ---
        tl_q = text("""
            SELECT
                loading_start_dttm,
                loading_finish_dttm,
                loading_state,
                message,
                EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) AS duration_seconds
            FROM public.log_objects_loading_history
            WHERE object_id = :object_id
            ORDER BY loading_finish_dttm DESC
            LIMIT 15
        """)
        rows = conn.execute(tl_q, {"object_id": table_id}).mappings().all()

        timeline = []
        for r in rows:
            msg = r.get("message") or ""
            msg = re.sub(r"\s+", " ", msg).strip()
            snippet = msg[:180] if msg else None

            timeline.append({
                "start": r["loading_start_dttm"].strftime("%Y-%m-%d %H:%M:%S") if r["loading_start_dttm"] else None,
                "finish": r["loading_finish_dttm"].strftime("%Y-%m-%d %H:%M:%S") if r["loading_finish_dttm"] else None,
                "state": r["loading_state"],
                "duration_sec": float(r["duration_seconds"]) if r["duration_seconds"] is not None else None,
                "message": snippet
            })

        # --- counts 24h / 7d ---
        c24_q = text("""
            SELECT COUNT(*) 
            FROM public.log_objects_loading_history
            WHERE object_id = :object_id
              AND loading_state = 'FAILED'
              AND loading_finish_dttm >= NOW() - INTERVAL '24 hours'
        """)
        c7d_q = text("""
            SELECT COUNT(*) 
            FROM public.log_objects_loading_history
            WHERE object_id = :object_id
              AND loading_state = 'FAILED'
              AND loading_finish_dttm >= NOW() - INTERVAL '7 days'
        """)
        failures_24h = int(conn.execute(c24_q, {"object_id": table_id}).scalar() or 0)
        failures_7d  = int(conn.execute(c7d_q,  {"object_id": table_id}).scalar() or 0)

        # --- last success / last fail ---
        last_fail_q = text("""
            SELECT MAX(loading_finish_dttm)
            FROM public.log_objects_loading_history
            WHERE object_id = :object_id
              AND loading_state = 'FAILED'
        """)
        last_succ_q = text("""
            SELECT MAX(loading_finish_dttm)
            FROM public.log_objects_loading_history
            WHERE object_id = :object_id
              AND loading_state = 'SUCCESS'
        """)
        last_failure = conn.execute(last_fail_q, {"object_id": table_id}).scalar()
        last_success = conn.execute(last_succ_q, {"object_id": table_id}).scalar()

        # --- consecutive failures (считаем подряд сверху таймлайна до первого SUCCESS) ---
        consecutive_failures = 0
        for ev in timeline:
            if ev["state"] == "FAILED":
                consecutive_failures += 1
            elif ev["state"] == "SUCCESS":
                break

        # --- state ---
        state = "UNKNOWN"
        if timeline:
            state = "FAILING" if timeline[0]["state"] == "FAILED" else "RECOVERED"

        # --- dependencies (downstream из твоего /api/dependencies) ---
        try:
            deps_resp = get_dependencies(table=f"{schema}.{table}")
            deps = json.loads(deps_resp.body.decode("utf-8"))
        except Exception:
            deps = []

        # --- sla / impact (используем твою логику, как в /api/control-center) ---
        sla_rows = get_sla_monitoring()
        impact = build_impact(f"{schema}.{table}", deps, sla_rows) if deps is not None else {
            "affected_entities": [],
            "blocked_tables_count": 0,
            "reports_at_risk": [],
            "sla_violations": 0
        }

        # --- severity (простая и честная логика) ---
        # CRITICAL если сейчас FAILING или есть sla violations, иначе HIGH если много падений
        severity = "CRITICAL" if (state == "FAILING" or (impact.get("sla_violations", 0) > 0)) else ("HIGH" if failures_24h >= 2 else "MEDIUM")

        summary = {
            "table_fqn": f"{schema}.{table}",
            "table_id": table_id,
            "severity": severity,
            "state": state,
            "failures_24h": failures_24h,
            "failures_7d": failures_7d,
            "consecutive_failures": consecutive_failures,
            "last_failure_time": last_failure.strftime("%Y-%m-%d %H:%M:%S") if isinstance(last_failure, datetime) else None,
            "last_success_time": last_success.strftime("%Y-%m-%d %H:%M:%S") if isinstance(last_success, datetime) else None,
        }

        return JSONResponse(
            content={
                "summary": summary,
                "timeline": timeline,
                "dependencies": deps,
                "impact": impact
            },
            media_type="application/json; charset=utf-8"
        )

from collections import defaultdict
from datetime import timedelta

INCIDENT_WINDOW_MIN = 60  # минут

def group_failures(failures: list):
    incidents = []
    failures_sorted = sorted(
        failures,
        key=lambda x: x["error_time"],
        reverse=True
    )

    used = set()

    for i, f in enumerate(failures_sorted):
        if i in used:
            continue

        entity = f.get("entity_name")

        if not entity:
            meta = next(
                (m for m in get_cached_meta()
                 if m["table_schema"] == f["schema"]
                 and m["table_name"] == f["table_name"]),
                None
            )
            entity = meta.get("entity_name") if meta else None

        entity = entity or f"{f['schema']}"
        f["entity_name"] = entity  # 🔴 фикс

        t0 = datetime.strptime(f["error_time"], "%Y-%m-%d %H:%M:%S")

        group = [f]
        used.add(i)

        for j, other in enumerate(failures_sorted[i+1:], start=i+1):
            if j in used:
                continue

            other_entity = other.get("entity_name")

            if not other_entity:
                meta = next(
                    (m for m in get_cached_meta()
                     if m["table_schema"] == other["schema"]
                     and m["table_name"] == other["table_name"]),
                    None
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
import json

@app.get("/api/incidents/active")
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

        incidents.append({
            "entity": entity,
            "severity": "CRITICAL",
            "failed_tables": len(failed_tables),      # ← сколько реально упало
            "root_tables": sorted(failed_tables)[:3], # ← точки входа
            "last_failure_time": last_failure
        })

    # 3️⃣ самые свежие сверху
    incidents.sort(
        key=lambda x: x["last_failure_time"],
        reverse=True
    )

    return incidents





# ---------- Подключаем роутер ПОСЛЕ всех @router.get ----------
app.include_router(router)
