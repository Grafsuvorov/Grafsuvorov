from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set
from collections import deque
from pydantic import BaseModel
import os
import yaml

from datetime import datetime
from sqlalchemy import create_engine, text, bindparam
from typing import Optional
from pathlib import Path
from openpyxl import load_workbook
import traceback
from datetime import datetime, date, timedelta
from decimal import Decimal
import time
from typing import List, Dict, Tuple
from datetime import datetime
from sqlalchemy import text
import re
import json

from .config import (
    TABLE_LOADING_HISTORY,
    TABLE_ENTITIES_META,
    TABLE_TABLES_META,
    TABLE_TABLE_COMPARE,
    TABLE_YT_SLA,
    TABLE_YTREK_INCIDENTS,
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

# Модель для ответа зависимостей
class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: str = None
    start_time: str = None
    avg_duration_minutes: Optional[float] = None
    depth: int = 0
    path: Optional[List[str]] = None


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
            "violations": [],
            "_seen": set(),
        })

        dedupe_key = (source, r["source_last_load"], r["dependent_last_load"])
        if dedupe_key in g["_seen"]:
            continue
        g["_seen"].add(dedupe_key)

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
        g.pop("_seen", None)
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


def normalize_excel_table_name(value: str | None) -> str | None:
    if not value:
        return None

    cleaned = (
        str(value)
        .strip()
        .replace('"', "")
        .replace("'", "")
        .replace("`", "")
        .replace("[", "")
        .replace("]", "")
        .replace(" ", "")
        .replace("\n", "")
    )

    if not cleaned or cleaned == "-":
        return None

    cleaned = cleaned.lower()
    cleaned = cleaned.replace("..", ".")

    if "." in cleaned:
        schema, table = cleaned.split(".", 1)
        schema = schema.strip()
        table = table.strip()
        if not schema or not table:
            return None
        return f"{schema}.{table}"

    return cleaned or None


def format_excel_datetime(value) -> str | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time()).strftime("%Y-%m-%d %H:%M:%S")
    try:
        parsed = datetime.fromisoformat(str(value))
        return parsed.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return str(value)


def parse_ytrek_excel(file_path: Path) -> List[dict]:
    if not file_path.exists():
        raise FileNotFoundError(file_path)

    header_map = {
        "№": "index",
        "id задачи": "issue_id",
        "название задачи": "title",
        "дата начала сбоя": "start_at",
        "дата обнаружения": "detected_at",
        "дата окончания работ": "resolved_at",
        "ссылка на задачу": "link",
        "название таблицы": "table_raw",
        "название сущности": "entity_name",
    }

    def norm_header(value):
        return (value or "").strip().lower()

    workbook = load_workbook(file_path, read_only=True, data_only=True)
    sheet = workbook.active

    header_row = next(sheet.iter_rows(min_row=1, max_row=1, values_only=True))
    normalized_headers = [norm_header(h) for h in header_row]

    incidents = []
    for raw_row in sheet.iter_rows(min_row=2, values_only=True):
        record = {}
        for idx, cell_value in enumerate(raw_row):
            header_key = normalized_headers[idx] if idx < len(normalized_headers) else None
            mapped_key = header_map.get(header_key)
            if not mapped_key:
                continue
            record[mapped_key] = cell_value

        issue_id = str(record.get("issue_id") or "").strip()
        title = str(record.get("title") or "").strip()

        if not issue_id and not title:
            continue

        table_raw = str(record.get("table_raw") or "").strip()
        incidents.append(
            {
                "issue_id": issue_id,
                "title": title or "Без названия",
                "start_at": format_excel_datetime(record.get("start_at")),
                "detected_at": format_excel_datetime(record.get("detected_at")),
                "resolved_at": format_excel_datetime(record.get("resolved_at")),
                "link": record.get("link"),
                "table_raw": table_raw,
                "table_normalized": normalize_excel_table_name(table_raw),
                "entity_name": str(record.get("entity_name") or "").strip(),
            }
        )

    incidents.sort(key=lambda x: x.get("start_at") or "", reverse=True)
    return incidents


def build_tables_meta_index() -> tuple[dict, dict]:
    """Return lookup dictionaries for tables_meta: by fqn and by table name."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                f"""
                SELECT t.table_id, t.table_schema, t.table_name, t.entity_id, e.entity_name
                FROM {TABLE_TABLES_META} t
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE t.table_schema IS NOT NULL AND t.table_name IS NOT NULL
                """
            )
        ).mappings().all()

    by_fqn = {}
    by_name = {}

    for row in rows:
        schema = (row["table_schema"] or "").lower()
        table = (row["table_name"] or "").lower()
        if not schema or not table:
            continue
        key = f"{schema}.{table}"
        by_fqn[key] = row
        by_name.setdefault(table, []).append(row)

    return by_fqn, by_name


def ensure_ytrek_table_exists(conn) -> None:
    conn.execute(
        text(
            f"""
            CREATE TABLE IF NOT EXISTS {TABLE_YTREK_INCIDENTS} (
                issue_id TEXT PRIMARY KEY,
                title TEXT,
                start_at TIMESTAMP NULL,
                detected_at TIMESTAMP NULL,
                resolved_at TIMESTAMP NULL,
                link TEXT,
                table_raw TEXT,
                table_normalized TEXT,
                table_schema TEXT,
                table_name TEXT,
                table_id BIGINT,
                entity_name TEXT,
                inserted_at TIMESTAMP DEFAULT NOW()
            )
            """
        )
    )


def parse_timestamp_value(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.strptime(str(value), "%Y-%m-%d %H:%M:%S")
    except Exception:
        return None


def pick_table_match(table_normalized: str | None, entity_hint: str | None, by_fqn: dict, by_name: dict):
    if not table_normalized:
        return None

    normalized = table_normalized.lower()
    entity_hint = (entity_hint or "").lower()

    if "." in normalized and normalized in by_fqn:
        return by_fqn[normalized]

    # Fall back to table-name-only match
    table_name = normalized.split(".")[-1]
    candidates = by_name.get(table_name) or []
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    if entity_hint:
        filtered = [c for c in candidates if (c.get("entity_name") or "").lower() == entity_hint]
        if len(filtered) == 1:
            return filtered[0]
    return candidates[0]


def import_ytrek_from_excel(file_path: str | Path) -> int:
    """Load incidents from an Excel export into the database table."""
    path = Path(file_path)
    incidents = parse_ytrek_excel(path)
    by_fqn, by_name = build_tables_meta_index()

    rows = []
    for record in incidents:
        table_norm = record.get("table_normalized")
        entity_hint = record.get("entity_name")
        match = pick_table_match(table_norm, entity_hint, by_fqn, by_name)

        matched_schema = match.get("table_schema") if match else None
        matched_table = match.get("table_name") if match else None
        consolidated_entity = match.get("entity_name") if match else None
        if not consolidated_entity:
            consolidated_entity = entity_hint or None

        rows.append(
            {
                "issue_id": record.get("issue_id"),
                "title": record.get("title"),
                "start_at": parse_timestamp_value(record.get("start_at")),
                "detected_at": parse_timestamp_value(record.get("detected_at")),
                "resolved_at": parse_timestamp_value(record.get("resolved_at")),
                "link": record.get("link"),
                "table_raw": record.get("table_raw"),
                "table_normalized": table_norm,
                "table_schema": matched_schema,
                "table_name": matched_table,
                "table_id": match.get("table_id") if match else None,
                "entity_name": consolidated_entity,
            }
        )

    with engine.begin() as conn:
        ensure_ytrek_table_exists(conn)
        conn.execute(text(f"TRUNCATE TABLE {TABLE_YTREK_INCIDENTS}"))
        if rows:
            conn.execute(
                text(
                    f"""
                    INSERT INTO {TABLE_YTREK_INCIDENTS} (
                        issue_id, title, start_at, detected_at, resolved_at,
                        link, table_raw, table_normalized, table_schema, table_name,
                        table_id, entity_name
                    ) VALUES (
                        :issue_id, :title, :start_at, :detected_at, :resolved_at,
                        :link, :table_raw, :table_normalized, :table_schema, :table_name,
                        :table_id, :entity_name
                    )
                    """
                ),
                rows,
            )

    return len(rows)


def extract_incident_day(row: dict) -> date | None:
    for key in ("start_at", "detected_at", "resolved_at"):
        value = row.get(key)
        if not value:
            continue
        if isinstance(value, datetime):
            return value.date()
        try:
            return datetime.fromisoformat(str(value)).date()
        except Exception:
            continue
    return None


def fetch_failure_lookup(conn, incident_rows):
    combos = []
    for row in incident_rows:
        table_id = row.get("table_id")
        if not table_id:
            continue
        day = extract_incident_day(row)
        if not day:
            continue
        combos.append((table_id, day))

    if not combos:
        return {}

    unique_ids = sorted({tid for tid, _ in combos})
    min_day = min(day for _, day in combos)
    max_day = max(day for _, day in combos)

    start_bound = datetime.combine(min_day, datetime.min.time())
    end_bound = datetime.combine(max_day + timedelta(days=1), datetime.min.time())

    placeholders = ", ".join(f":id{i}" for i in range(len(unique_ids)))
    params = {f"id{i}": tid for i, tid in enumerate(unique_ids)}
    params.update({"start_bound": start_bound, "end_bound": end_bound})

    query = text(
        f"""
        SELECT object_id, DATE(loading_finish_dttm) AS incident_day, COUNT(*) AS fail_count
        FROM {TABLE_LOADING_HISTORY}
        WHERE object_id IN ({placeholders})
          AND loading_state = 'FAILED'
          AND loading_finish_dttm >= :start_bound
          AND loading_finish_dttm < :end_bound
        GROUP BY object_id, DATE(loading_finish_dttm)
        """
    )

    rows = conn.execute(query, params).mappings().all()
    lookup = {}
    for row in rows:
        lookup[(row["object_id"], row["incident_day"])] = row["fail_count"]

    return lookup


def build_ytrek_dashboard(top_limit: int):
    with engine.begin() as conn:
        ensure_ytrek_table_exists(conn)

    with engine.connect() as conn:
        incident_rows = conn.execute(
            text(
                f"""
                SELECT issue_id, title, start_at, detected_at, resolved_at, link,
                       table_raw, table_normalized, table_schema, table_name,
                       table_id, entity_name
                FROM {TABLE_YTREK_INCIDENTS}
                ORDER BY COALESCE(start_at, detected_at, resolved_at) DESC NULLS LAST,
                         issue_id DESC
                """
            )
        ).mappings().all()

        timeline_rows = conn.execute(
            text(
                f"""
                SELECT DATE(COALESCE(start_at, detected_at, resolved_at)) AS incident_day,
                       COUNT(*) AS incidents_count
                FROM {TABLE_YTREK_INCIDENTS}
                WHERE COALESCE(start_at, detected_at, resolved_at) IS NOT NULL
                GROUP BY DATE(COALESCE(start_at, detected_at, resolved_at))
                ORDER BY incident_day DESC
                LIMIT 30
                """
            )
        ).mappings().all()

        top_tables_rows = conn.execute(
            text(
                f"""
                SELECT
                    table_schema,
                    table_name,
                    table_raw,
                    COUNT(*) AS incidents_count,
                    MAX(COALESCE(start_at, detected_at, resolved_at)) AS last_incident
                FROM {TABLE_YTREK_INCIDENTS}
                GROUP BY table_schema, table_name, table_raw
                ORDER BY incidents_count DESC, last_incident DESC
                LIMIT :limit
                """
            ),
            {"limit": top_limit},
        ).mappings().all()

        top_entities_rows = conn.execute(
            text(
                f"""
                SELECT
                    COALESCE(NULLIF(entity_name, ''), 'Не указано') AS entity_key,
                    COUNT(*) AS incidents_count,
                    MAX(COALESCE(start_at, detected_at, resolved_at)) AS last_incident
                FROM {TABLE_YTREK_INCIDENTS}
                GROUP BY entity_key
                ORDER BY incidents_count DESC, entity_key
                LIMIT :limit
                """
            ),
            {"limit": top_limit},
        ).mappings().all()

        failure_lookup = fetch_failure_lookup(conn, incident_rows)

    incidents = []
    tables_set = set()
    entities_set = set()
    mapped_count = 0
    db_matches = 0

    for row in incident_rows:
        table_schema = row.get("table_schema")
        table_name = row.get("table_name")
        table_fqn = None
        if table_schema and table_name:
            table_fqn = f"{table_schema}.{table_name}"
            tables_set.add(table_fqn)
            mapped_count += 1

        entity_value = row.get("entity_name")
        if isinstance(entity_value, str):
            entity_value = entity_value.strip()
        if entity_value:
            entities_set.add(entity_value)

        incident_day = extract_incident_day(row)
        day_key = incident_day.strftime("%Y-%m-%d") if incident_day else None
        failures = 0
        if row.get("table_id") and incident_day:
            failures = failure_lookup.get((row["table_id"], incident_day), 0)
        if failures:
            db_matches += 1

        incidents.append(
            {
                "issue_id": row["issue_id"],
                "title": row["title"],
                "link": row.get("link"),
                "start_at": serialize_datetime(row.get("start_at")),
                "detected_at": serialize_datetime(row.get("detected_at")),
                "resolved_at": serialize_datetime(row.get("resolved_at")),
                "table_raw": row.get("table_raw"),
                "table_normalized": row.get("table_normalized"),
                "table_schema": table_schema,
                "table_name": table_name,
                "table_fqn": table_fqn,
                "table_id": row.get("table_id"),
                "entity_name": row.get("entity_name"),
                "has_table": bool(table_fqn),
                "incident_day": day_key,
                "has_db_failures": failures > 0,
                "db_failures_count": failures,
            }
        )

    stats = {
        "total": len(incidents),
        "with_table": mapped_count,
        "unique_tables": len(tables_set),
        "unique_entities": len(entities_set),
        "with_db_failures": db_matches,
    }

    timeline = [
        {
            "day": row["incident_day"].strftime("%Y-%m-%d"),
            "count": row["incidents_count"],
        }
        for row in reversed(timeline_rows)
        if row.get("incident_day")
    ]

    top_tables = []
    for row in top_tables_rows:
        schema = row.get("table_schema")
        table = row.get("table_name")
        table_fqn = f"{schema}.{table}" if schema and table else None
        label = table_fqn or row.get("table_raw") or "—"
        top_tables.append(
            {
                "label": label,
                "table_fqn": table_fqn,
                "count": row["incidents_count"],
                "last_incident": serialize_datetime(row.get("last_incident")),
                "has_table": bool(table_fqn),
            }
        )

    top_entities = [
        {
            "label": row["entity_key"],
            "count": row["incidents_count"],
            "last_incident": serialize_datetime(row.get("last_incident")),
        }
        for row in top_entities_rows
    ]

    return {
        "stats": stats,
        "timeline": timeline,
        "top_tables": top_tables,
        "top_entities": top_entities,
        "incidents": incidents,
    }


def serialize_datetime(value):
    if not value:
        return None
    if isinstance(value, str):
        return value
    return value.strftime("%Y-%m-%d %H:%M:%S")


@router.get("/api/ytrek/incidents")
def get_ytrek_incidents(top_limit: int = Query(5, ge=1, le=50)):
    return build_ytrek_dashboard(top_limit)

def resolve_dependencies(schema: str, table: str) -> List[DependencyItem]:
    all_meta, reverse_index = get_cached_meta_and_index()

    start = (schema, table)
    visited = {start}
    parent = {}
    depth = {start: 0}
    meta_by_node = {}
    order = []

    queue = deque([start])
    while queue:
        node = queue.popleft()
        for dep in reverse_index.get(node, []):
            child = (dep["schema"], dep["table_name"])
            if child in visited:
                continue
            visited.add(child)
            parent[child] = node
            depth[child] = depth[node] + 1
            meta_by_node[child] = dep
            order.append(child)
            queue.append(child)

    out = []
    with engine.connect() as conn:
        for i, node in enumerate(order, 1):
            r = meta_by_node[node]
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

            path = []
            current = node
            while current != start:
                path.append(f"{current[0]}.{current[1]}")
                current = parent[current]
            path.append(f"{start[0]}.{start[1]}")
            path.reverse()

            out.append(DependencyItem(
                step=i,
                schema=r["schema"],
                table_name=r["table_name"],
                entity_id=r["entity_id"],
                entity_name=r.get("entity_name"),
                avg_duration_minutes=avg,
                depth=depth.get(node, 0),
                path=path,
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

                    schema_name = meta.get("table_schema") or schema
                    table_name = meta.get("table_name") or table
                    schema_name = str(schema_name or "")
                    table_name = str(table_name or "")

                    def quote_ident(value: str) -> str:
                        escaped = value.replace('"', '""')
                        return f"\"{escaped}\""

                    def build_regclass(schema_val: str, table_val: str) -> str:
                        if not schema_val or not table_val:
                            return ""
                        needs_quote = (
                            schema_val.lower() in {"stg", "dict_stg"}
                            or schema_val != schema_val.lower()
                            or table_val != table_val.lower()
                        )
                        if needs_quote:
                            return f"{quote_ident(schema_val)}.{quote_ident(table_val)}"
                        return f"{schema_val.lower()}.{table_val.lower()}"

                    regclass_name = build_regclass(schema_name, table_name)

                    size_result = conn.execute(
                        size_sql,
                        {"full_table_name": regclass_name},
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
    all_tables = {}
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
                                key = f"{schema}.{table}"
                                all_tables.setdefault(key.lower(), key)
                    except:
                        continue
    return JSONResponse(content=sorted(all_tables.values(), key=lambda v: v.lower()))


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
def get_slowest_tables(
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(20, ge=1, le=200),
):
    try:
        query = f"""
            WITH base AS (
                SELECT
                    COALESCE(t.table_schema, '') AS table_schema,
                    COALESCE(t.table_name, l.object_name) AS table_name,
                    e.entity_name,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            )
            SELECT
                table_schema,
                table_name,
                entity_name,
                COUNT(*) AS runs_count,
                AVG(duration) AS avg_duration,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY duration) AS p95_duration,
                MAX(duration) AS max_duration,
                STDDEV_SAMP(duration) AS stddev_duration
            FROM base
            GROUP BY table_schema, table_name, entity_name
        """
        with engine.connect() as conn:
            rows = conn.execute(text(query), {"days": days}).mappings().all()

        threshold_minutes = 10.0
        data = []
        for row in rows:
            r = dict(row)
            runs = int(r.get("runs_count") or 0)
            avg = float(r["avg_duration"]) if r.get("avg_duration") is not None else None
            p95 = float(r["p95_duration"]) if r.get("p95_duration") is not None else None
            max_d = float(r["max_duration"]) if r.get("max_duration") is not None else None
            std = float(r["stddev_duration"]) if r.get("stddev_duration") is not None else None

            cv = (std / avg) if (std is not None and avg) else None
            p95_ratio = (p95 / avg) if (p95 is not None and avg) else None

            slow = bool(p95 is not None and p95 > threshold_minutes)
            unstable = bool(cv is not None and cv >= 0.3)
            critical_unstable = bool(cv is not None and cv >= 0.6) or bool(
                p95_ratio is not None and p95_ratio > 2
            )
            low_sample = runs < 5

            if low_sample:
                status = "low_sample"
            elif slow and unstable:
                status = "slow_unstable"
            elif slow and not unstable:
                status = "slow"
            elif unstable:
                status = "unstable"
            else:
                status = "ok"

            if not (slow or unstable):
                continue

            data.append(
                {
                    "table_schema": r.get("table_schema") or "",
                    "table_name": r.get("table_name") or "",
                    "entity_name": r.get("entity_name"),
                    "runs_count": runs,
                    "avg_duration": round(avg, 2) if avg is not None else None,
                    "p95_duration": round(p95, 2) if p95 is not None else None,
                    "max_duration": round(max_d, 2) if max_d is not None else None,
                    "stddev_duration": round(std, 2) if std is not None else None,
                    "cv": round(cv, 4) if cv is not None else None,
                    "p95_avg_ratio": round(p95_ratio, 3) if p95_ratio is not None else None,
                    "slow": slow,
                    "unstable": unstable,
                    "critical_unstable": critical_unstable,
                    "low_sample": low_sample,
                    "status": status,
                }
            )

        status_order = {
            "slow_unstable": 0,
            "slow": 1,
            "unstable": 2,
            "low_sample": 3,
            "ok": 4,
        }
        data.sort(
            key=lambda x: (
                status_order.get(x["status"], 9),
                -(x.get("p95_duration") or 0),
            )
        )
        limited = data[:limit]

        now_dt = datetime.utcnow().date()
        period_from = now_dt - timedelta(days=days)
        payload = {
            "meta": {
                "window_days": days,
                "period_from": period_from.strftime("%Y-%m-%d"),
                "period_to": now_dt.strftime("%Y-%m-%d"),
                "total_tables": len(rows),
                "candidates": len(data),
                "limit": limit,
            },
            "rows": limited,
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/slowest-tables error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/load-profile")
def get_load_profile(days: int = Query(30, ge=1, le=120)):
    try:
        query = f"""
            SELECT
                EXTRACT(HOUR FROM l.loading_start_dttm) AS hour,
                COUNT(*) AS runs_count,
                SUM(EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0) AS total_duration_minutes
            FROM {TABLE_LOADING_HISTORY} l
            WHERE l.object_type = 'table'
              AND l.loading_state = 'SUCCESS'
              AND l.loading_start_dttm IS NOT NULL
              AND l.loading_finish_dttm IS NOT NULL
              AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
            GROUP BY EXTRACT(HOUR FROM l.loading_start_dttm)
            ORDER BY hour
        """
        with engine.connect() as conn:
            rows = conn.execute(text(query), {"days": days}).mappings().all()

        profile_map = {int(r["hour"]): r for r in rows}
        profile = []
        for h in range(24):
            row = profile_map.get(h, {})
            runs = int(row.get("runs_count") or 0)
            total = float(row.get("total_duration_minutes") or 0.0)
            profile.append(
                {
                    "hour": h,
                    "runs_count": runs,
                    "total_duration_minutes": round(total, 2),
                }
            )

        return JSONResponse(
            content={"days": days, "profile": profile},
            media_type="application/json; charset=utf-8",
        )
    except Exception as e:
        print("❌ /api/load-profile error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/night-summary")
def get_night_summary(
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(50, ge=1, le=200),
    start_hour: int = Query(21, ge=0, le=23),
    end_hour: int = Query(8, ge=0, le=23),
):
    try:
        with engine.connect() as conn:
            window_row = conn.execute(
                text(
                    """
                    SELECT
                        (date_trunc('day', now()) - interval '1 day' + (:start_hour || ' hours')::interval) AS start_ts,
                        (date_trunc('day', now()) + (:end_hour || ' hours')::interval) AS end_ts
                    """
                ),
                {"start_hour": start_hour, "end_hour": end_hour},
            ).mappings().first()

        start_ts = window_row["start_ts"]
        end_ts = window_row["end_ts"]

        base_cte = f"""
            WITH night_runs AS (
                SELECT
                    l.object_id,
                    COALESCE(t.table_schema, '') AS table_schema,
                    COALESCE(t.table_name, l.object_name) AS table_name,
                    e.entity_name,
                    l.loading_start_dttm,
                    l.loading_finish_dttm,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration,
                    EXTRACT(HOUR FROM l.loading_start_dttm) AS hour
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND l.loading_start_dttm >= :start_ts
                  AND l.loading_start_dttm < :end_ts
            )
        """

        with engine.connect() as conn:
            summary = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        COUNT(*) AS runs_count,
                        COUNT(DISTINCT object_id) AS tables_count,
                        COUNT(DISTINCT entity_name) AS entities_count,
                        SUM(duration) AS total_duration_minutes,
                        MAX(duration) AS max_duration_minutes
                    FROM night_runs
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts},
            ).mappings().first()

            hourly = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        hour,
                        COUNT(*) AS runs_count,
                        SUM(duration) AS total_duration_minutes
                    FROM night_runs
                    GROUP BY hour
                    ORDER BY hour
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts},
            ).mappings().all()

            hourly_top = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT hour, table_schema, table_name, entity_name, duration
                    FROM (
                        SELECT
                            hour,
                            table_schema,
                            table_name,
                            entity_name,
                            duration,
                            ROW_NUMBER() OVER (PARTITION BY hour ORDER BY duration DESC) AS rn
                        FROM night_runs
                    ) ranked
                    WHERE rn <= :limit
                    ORDER BY hour, duration DESC
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts, "limit": limit},
            ).mappings().all()

            top_runs = conn.execute(
                text(
                    base_cte
                    + """
                    SELECT
                        table_schema,
                        table_name,
                        entity_name,
                        duration,
                        loading_start_dttm,
                        loading_finish_dttm
                    FROM night_runs
                    ORDER BY duration DESC
                    LIMIT :limit
                    """
                ),
                {"start_ts": start_ts, "end_ts": end_ts, "limit": limit},
            ).mappings().all()

            anomalies = conn.execute(
                text(
                    f"""
                    WITH history AS (
                        SELECT
                            l.object_id,
                            percentile_cont(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0) AS p95_duration
                        FROM {TABLE_LOADING_HISTORY} l
                        WHERE l.object_type = 'table'
                          AND l.loading_state = 'SUCCESS'
                          AND l.loading_start_dttm IS NOT NULL
                          AND l.loading_finish_dttm IS NOT NULL
                          AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
                        GROUP BY l.object_id
                    ),
                    night_runs AS (
                        SELECT
                            l.object_id,
                            COALESCE(t.table_schema, '') AS table_schema,
                            COALESCE(t.table_name, l.object_name) AS table_name,
                            e.entity_name,
                            l.loading_start_dttm,
                            l.loading_finish_dttm,
                            EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration
                        FROM {TABLE_LOADING_HISTORY} l
                        LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                        LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                        WHERE l.object_type = 'table'
                          AND l.loading_state = 'SUCCESS'
                          AND l.loading_start_dttm IS NOT NULL
                          AND l.loading_finish_dttm IS NOT NULL
                          AND l.loading_start_dttm >= :start_ts
                          AND l.loading_start_dttm < :end_ts
                    )
                    SELECT
                        n.table_schema,
                        n.table_name,
                        n.entity_name,
                        n.duration,
                        n.loading_start_dttm,
                        n.loading_finish_dttm,
                        h.p95_duration,
                        CASE
                            WHEN h.p95_duration > 0 THEN n.duration / h.p95_duration
                            ELSE NULL
                        END AS ratio
                    FROM night_runs n
                    JOIN history h ON h.object_id = n.object_id
                    WHERE n.duration > h.p95_duration * 1.5
                    ORDER BY n.duration DESC
                    LIMIT :limit
                    """
                ),
                {
                    "days": days,
                    "start_ts": start_ts,
                    "end_ts": end_ts,
                    "limit": limit,
                },
            ).mappings().all()

        hourly_top_map = {}
        for row in hourly_top:
            hour = int(row["hour"])
            hourly_top_map.setdefault(hour, []).append(
                {
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                }
            )

        hourly_payload = []
        for row in hourly:
            hour = int(row["hour"])
            total = float(row.get("total_duration_minutes") or 0.0)
            hourly_payload.append(
                {
                    "hour": hour,
                    "runs_count": int(row.get("runs_count") or 0),
                    "total_duration_minutes": round(total, 2),
                    "top_tables": hourly_top_map.get(hour, []),
                }
            )

        payload = {
            "window": {
                "start": serialize_datetime(start_ts),
                "end": serialize_datetime(end_ts),
                "start_hour": start_hour,
                "end_hour": end_hour,
            },
            "summary": {
                "runs_count": int(summary.get("runs_count") or 0),
                "tables_count": int(summary.get("tables_count") or 0),
                "entities_count": int(summary.get("entities_count") or 0),
                "total_duration_minutes": round(float(summary.get("total_duration_minutes") or 0.0), 2),
                "max_duration_minutes": round(float(summary.get("max_duration_minutes") or 0.0), 2)
                if summary.get("max_duration_minutes") is not None
                else None,
            },
            "hourly": hourly_payload,
            "top_runs": [
                {
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                    "start": serialize_datetime(row.get("loading_start_dttm")),
                    "end": serialize_datetime(row.get("loading_finish_dttm")),
                }
                for row in top_runs
            ],
            "anomalies": [
                {
                    "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                    "entity_name": row.get("entity_name"),
                    "duration_minutes": round(float(row["duration"]), 2) if row["duration"] is not None else None,
                    "p95_minutes": round(float(row["p95_duration"]), 2) if row["p95_duration"] is not None else None,
                    "ratio": round(float(row["ratio"]), 2) if row["ratio"] is not None else None,
                    "start": serialize_datetime(row.get("loading_start_dttm")),
                    "end": serialize_datetime(row.get("loading_finish_dttm")),
                }
                for row in anomalies
            ],
        }
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/night-summary error:", e)
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/entity-loads")
def get_entity_loads(
    entity_id: int = Query(..., ge=1),
    days: int = Query(30, ge=1, le=120),
    limit: int = Query(30, ge=1, le=200),
    schema: str | None = Query(None),
):
    try:
        schema = schema.strip() if isinstance(schema, str) else None
        query = f"""
            WITH base AS (
                SELECT
                    COALESCE(t.table_schema, '') AS table_schema,
                    COALESCE(t.table_name, l.object_name) AS table_name,
                    e.entity_name,
                    EXTRACT(EPOCH FROM (l.loading_finish_dttm - l.loading_start_dttm)) / 60.0 AS duration,
                    l.loading_finish_dttm
                FROM {TABLE_LOADING_HISTORY} l
                LEFT JOIN {TABLE_TABLES_META} t ON t.table_id = l.object_id
                LEFT JOIN {TABLE_ENTITIES_META} e ON e.entity_id = t.entity_id
                WHERE l.object_type = 'table'
                  AND l.loading_state = 'SUCCESS'
                  AND l.loading_start_dttm IS NOT NULL
                  AND l.loading_finish_dttm IS NOT NULL
                  AND e.entity_id = :entity_id
                  AND l.loading_finish_dttm >= now() - (:days || ' days')::interval
                  AND (:schema IS NULL OR t.table_schema = :schema)
            )
            SELECT
                table_schema,
                table_name,
                entity_name,
                COUNT(*) AS runs_count,
                AVG(duration) AS avg_duration,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY duration) AS p95_duration,
                MAX(duration) AS max_duration,
                MAX(loading_finish_dttm) AS last_finish
            FROM base
            GROUP BY table_schema, table_name, entity_name
            ORDER BY MAX(duration) DESC NULLS LAST
            LIMIT :limit
        """
        with engine.connect() as conn:
            rows = conn.execute(
                text(query),
                {"entity_id": entity_id, "days": days, "limit": limit, "schema": schema},
            ).mappings().all()

        payload = [
            {
                "table_fqn": f"{row['table_schema']}.{row['table_name']}".strip("."),
                "entity_name": row.get("entity_name"),
                "runs_count": int(row.get("runs_count") or 0),
                "avg_duration": round(float(row["avg_duration"]), 2) if row.get("avg_duration") is not None else None,
                "p95_duration": round(float(row["p95_duration"]), 2) if row.get("p95_duration") is not None else None,
                "max_duration": round(float(row["max_duration"]), 2) if row.get("max_duration") is not None else None,
                "last_finish": serialize_datetime(row.get("last_finish")),
            }
            for row in rows
        ]
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        print("❌ /api/entity-loads error:", e)
        print(traceback.format_exc())
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
        print("❌ Ошибка при построении Gantt:", str(e))
        print(traceback.format_exc())
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
