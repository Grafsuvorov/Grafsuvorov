# ===== main.py (FIXED: downstream, reverse_index, FQN normalization) =====
from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set, Optional
from pydantic import BaseModel
import os
import yaml
import json
import time
import re
import traceback

from pathlib import Path
from datetime import datetime, date
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

# ---------------------------------------------------------------------
# App
# ---------------------------------------------------------------------

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

# ---------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------

class DependencyItem(BaseModel):
    step: int
    schema: str
    table_name: str
    entity_id: int
    entity_name: Optional[str] = None
    start_time: Optional[str] = None
    avg_duration_minutes: Optional[float] = None

# ---------------------------------------------------------------------
# Const
# ---------------------------------------------------------------------

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
_CACHE_TTL = 86400  # 24h

# ---------------------------------------------------------------------
# Utils
# ---------------------------------------------------------------------

def norm(s: str | None) -> str | None:
    return s.lower() if isinstance(s, str) else s


def normalize_fqn(table_fqn: str) -> str:
    if not table_fqn:
        return table_fqn
    s = table_fqn.strip()
    if "/" in s and "." in s:
        schema_part, rest = s.split(".", 1)
        rest = rest.replace("/", "").replace("-", "").replace(" ", "")
        s = f"{schema_part}.{rest}"
    return s.replace(" ", "").lower()

# ---------------------------------------------------------------------
# Meta cache
# ---------------------------------------------------------------------

@app.on_event("startup")
def warm_up_cache():
    get_cached_meta_and_index()


def get_cached_meta_and_index() -> Tuple[List[Dict], Dict[Tuple[str, str], List[Dict]]]:
    global _cached_meta_index, _cache_timestamp
    now = time.time()
    if _cached_meta_index is None or now - _cache_timestamp > _CACHE_TTL:
        all_meta = find_all_meta_files(TOP_DIRS)
        reverse_index = build_reverse_index(all_meta)
        _cached_meta_index = (all_meta, reverse_index)
        _cache_timestamp = now
    return _cached_meta_index


def find_all_meta_files(top_dirs: List[str]) -> List[Dict]:
    all_meta = []
    for top_dir in top_dirs:
        for root, _, files in os.walk(BASE_DIR / top_dir):
            if "meta_data_file.yaml" not in files:
                continue
            path = os.path.join(root, "meta_data_file.yaml")
            try:
                with open(path, encoding="utf-8") as f:
                    meta = yaml.safe_load(f) or {}
                    start_time = None
                    if meta.get("start_date"):
                        try:
                            start_time = datetime.strptime(meta["start_date"], "%Y-%m-%d %H:%M:%S").time()
                        except:
                            pass

                    all_meta.append({
                        "table_schema": norm(meta.get("table_schema")),
                        "table_name": norm(meta.get("table_name")),
                        "entity_id": meta.get("entity_id"),
                        "entity_name": meta.get("entity_name"),
                        "depends_on": {
                            norm(k): [norm(t) for t in v]
                            for k, v in (meta.get("depends_on") or {}).items()
                        },
                        "start_time": start_time,
                        "table_id": meta.get("table_id"),
                    })
            except Exception as e:
                print(f"[META ERROR] {path}: {e}")
    return all_meta


def build_reverse_index(all_meta: List[Dict]) -> Dict[Tuple[str, str], List[Dict]]:
    reverse_index = {}
    for meta in all_meta:
        consumer_schema = meta["table_schema"]
        consumer_table = meta["table_name"]
        depends_on = meta.get("depends_on") or {}

        for dep_schema, tables in depends_on.items():
            for table in tables:
                key = (dep_schema, table)
                reverse_index.setdefault(key, []).append({
                    "schema": consumer_schema,
                    "table_name": consumer_table,
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "start_time": meta.get("start_time"),
                    "table_id": meta.get("table_id"),
                })
    return reverse_index


def recursive_reverse_search(
    start_schema: str,
    start_table: str,
    reverse_index: Dict[Tuple[str, str], List[Dict]],
    visited: Set[Tuple[str, str]] | None = None,
) -> List[Dict]:
    if visited is None:
        visited = set()
    key = (start_schema, start_table)
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
                visited,
            )
        )
    return result

# ---------------------------------------------------------------------
# API: Dependencies (FIXED)
# ---------------------------------------------------------------------

@app.get("/api/dependencies", response_model=List[DependencyItem])
def get_dependencies(table: str = Query(..., description="schema.table")):
    try:
        schema, table = normalize_fqn(table).split(".", 1)
    except ValueError:
        return JSONResponse(content=[])

    all_meta, reverse_index = get_cached_meta_and_index()
    result = recursive_reverse_search(schema, table, reverse_index)

    seen = set()
    uniq = []
    for r in result:
        k = (r["schema"], r["table_name"])
        if k not in seen:
            seen.add(k)
            uniq.append(r)

    output = []
    with engine.connect() as conn:
        for i, row in enumerate(uniq, 1):
            avg_minutes = None
            if row.get("table_id"):
                avg_minutes = conn.execute(
                    text(f"""
                        SELECT round(avg(extract(epoch from (loading_finish_dttm-loading_start_dttm))/60),2)
                        FROM {TABLE_LOADING_HISTORY}
                        WHERE object_id=:id AND loading_state='SUCCESS'
                    """),
                    {"id": row["table_id"]}
                ).scalar()

            output.append(DependencyItem(
                step=i,
                schema=row["schema"],
                table_name=row["table_name"],
                entity_id=row["entity_id"],
                entity_name=row.get("entity_name"),
                avg_duration_minutes=avg_minutes,
            ))

    return JSONResponse(content=[o.dict() for o in output])

# ---------------------------------------------------------------------
# !!! ОСТАЛЬНАЯ ЧАСТЬ ФАЙЛА
# ---------------------------------------------------------------------
# ⛔ Без изменений по логике, только normalize_fqn() используется
# ⛔ Incident / gantt / graph работают на том же lower-FQN
# ⛔ Ты можешь смело оставить остальной код как есть
