# === imports без изменений ===
from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set, Optional
from pydantic import BaseModel
import os, yaml, time, json, re, traceback
from pathlib import Path
from datetime import datetime, date, timedelta
from decimal import Decimal
from collections import defaultdict

from sqlalchemy import create_engine, text, bindparam

from config import (
    TABLE_LOADING_HISTORY,
    TABLE_ENTITIES_META,
    TABLE_TABLES_META,
    TABLE_TABLE_COMPARE,
    TABLE_YT_SLA,
    TABLE_TABLES_META_CLICK,
    DATABASE_URL,
)

# =========================================================
# APP / ENGINE
# =========================================================

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

engine = create_engine(DATABASE_URL)

BASE_DIR = Path(__file__).resolve().parent.parent

TOP_DIRS = [
    "BI_FI","BI_INVESTMENT","BI_TAXES","CASE_4","DICT_LOADER","MISHKADEV_TABLES",
    "FI_COUNTERPARTY","ISUIP_INVESTMENT","LOGISTICS","TRANSPORTATION","BI_SB_WUC",
    "BI_FI_FACT_PAYMENTS","STG_LOADER","SD_STOCKS","SALES_SHIPMENT_FROM_PLANT",
    "SALES_MM","SALES_MARGIN","MANAGEMENT_REPORTING_1","TEST_SAP_ODATA_DELTA"
]

# =========================================================
# MODELS
# =========================================================

class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: Optional[str] = None
    start_time: Optional[str] = None
    avg_duration_minutes: Optional[float] = None

# =========================================================
# META CACHE (НЕ ТРОГАЕМ)
# =========================================================

_cached_meta_index = None
_cache_timestamp = 0
_CACHE_TTL = 86400

def get_cached_meta_and_index():
    global _cached_meta_index, _cache_timestamp
    now = time.time()
    if _cached_meta_index and now - _cache_timestamp < _CACHE_TTL:
        return _cached_meta_index

    all_meta = []
    for top in TOP_DIRS:
        for root, _, files in os.walk(BASE_DIR / top):
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

# =========================================================
# DEPENDENCY HELPER (🔥 КЛЮЧЕВОЕ МЕСТО)
# =========================================================

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
                        SELECT round(avg(extract(epoch from (loading_finish_dttm-loading_start_dttm))/60),2)
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

# =========================================================
# API: DEPENDENCIES (РАБОТАЕТ КАК РАНЬШЕ)
# =========================================================

@app.get("/api/dependencies", response_model=List[DependencyItem])
def get_dependencies(table: str = Query(...)):
    try:
        schema, table = table.split(".")
    except ValueError:
        return []
    return resolve_dependencies(schema, table)

# =========================================================
# API: INCIDENT (ТЕПЕРЬ НЕ ЛОМАЕТСЯ)
# =========================================================

@app.get("/api/incident")
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
