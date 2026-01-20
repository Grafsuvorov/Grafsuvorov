from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Dict, Tuple, Set, Union
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
import hashlib
import subprocess
import tempfile

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

_graph_snapshot = None
_graph_snapshot_ts = 0
_graph_snapshot_hash = None
_GRAPH_SNAPSHOT_TTL = 86400  # 24 часа
_CACHE_TTL = 86400  # 24 часа

_order_breaches_cache = None
_order_breaches_ts = 0
_ORDER_BREACHES_TTL = 300  # 5 минут

_graph_cache = {}
_graph_cache_ts = 0
_GRAPH_CACHE_TTL = 86400  # 24 часа
_graph_cache_meta_ts = 0

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
    seen = set()
    for entity_root in iter_meta_dirs():
        for root, _, files in os.walk(entity_root):
            if "meta_data_file.yaml" not in files:
                continue
            path = Path(root) / "meta_data_file.yaml"
            try:
                meta = yaml.safe_load(path.read_text("utf-8")) or {}
                schema = norm(meta.get("table_schema"))
                table = norm(meta.get("table_name"))
                if not schema or not table:
                    continue
                key = f"{schema}.{table}"
                seen.add(key)
                depends_on = {}
                for src_schema, tables in (meta.get("depends_on") or {}).items():
                    src_schema_norm = norm(src_schema)
                    if not src_schema_norm:
                        continue
                    cleaned = [norm(t) for t in (tables or []) if t]
                    depends_on[src_schema_norm] = [t for t in cleaned if t]
                all_meta.append({
                    "table_schema": schema,
                    "table_name": table,
                    "entity_id": meta.get("entity_id"),
                    "entity_name": meta.get("entity_name"),
                    "depends_on": depends_on,
                    "table_id": meta.get("table_id"),
                })
            except Exception as e:
                print("META ERROR:", path, e)

    print("META COUNT:", len(seen))
    print("META SAMPLE:", sorted(list(seen))[:30])

    meta_lookup = {
        (m.get("table_schema"), m.get("table_name"))
        for m in all_meta
        if m.get("table_schema") and m.get("table_name")
    }
    reverse = {}
    for m in all_meta:
        consumer = (m["table_schema"], m["table_name"])
        for src_schema, tables in m["depends_on"].items():
            for src_table in tables:
                if (src_schema or "").lower() in ("raw_ext", "dict_raw_ext"):
                    continue
                if (src_schema, src_table) not in meta_lookup:
                    print(
                        "❌ BROKEN DEP:",
                        f"{consumer[0]}.{consumer[1]}",
                        "depends on",
                        f"{src_schema}.{src_table}",
                        "BUT META NOT FOUND",
                    )
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

def norm(s: Optional[str]) -> Optional[str]:
    return s.lower() if isinstance(s, str) else s


def _hash_meta(all_meta: list[dict]) -> str:
    items = []
    for m in all_meta:
        items.append({
            "table_schema": m.get("table_schema"),
            "table_name": m.get("table_name"),
            "entity_name": m.get("entity_name"),
            "depends_on": m.get("depends_on") or {},
            "table_id": m.get("table_id"),
        })
    payload = json.dumps(items, ensure_ascii=True, sort_keys=True)
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def _estimate_node_width(label: str, min_width: int = 160, max_width: int = 420) -> int:
    base = 120
    per_char = 7
    width = base + (len(label or "") * per_char)
    return max(min_width, min(max_width, width))


def _find_sccs(nodes: list[str], edges: list[dict]) -> list[list[str]]:
    adj = {n: [] for n in nodes}
    for e in edges:
        src = e.get("source")
        tgt = e.get("target")
        if src in adj and tgt:
            adj[src].append(tgt)

    index = 0
    stack = []
    on_stack = set()
    indices = {}
    lowlinks = {}
    sccs = []

    def strongconnect(v):
        nonlocal index
        indices[v] = index
        lowlinks[v] = index
        index += 1
        stack.append(v)
        on_stack.add(v)

        for w in adj.get(v, []):
            if w not in indices:
                strongconnect(w)
                lowlinks[v] = min(lowlinks[v], lowlinks[w])
            elif w in on_stack:
                lowlinks[v] = min(lowlinks[v], indices[w])

        if lowlinks[v] == indices[v]:
            scc = []
            while stack:
                w = stack.pop()
                on_stack.remove(w)
                scc.append(w)
                if w == v:
                    break
            sccs.append(scc)

    for n in nodes:
        if n not in indices:
            strongconnect(n)

    return sccs


def _layer_of_table(fqn: str) -> str:
    if not fqn or "." not in fqn:
        return "other"
    schema = fqn.split(".", 1)[0]
    schema_norm = schema.lower()
    if schema_norm in ("dict", "dict_stg", "dict_dds"):
        if "dict_dds" in fqn or schema_norm == "dict_dds":
            return "dict_dds"
        return "dict_stg"
    if schema_norm in ("raw_ext", "dict_raw_ext"):
        return "raw_ext"
    if schema_norm in ("stg", "ods", "dds", "dm", "dm_calc", "dm_view", "landing", "raw_ext"):
        return schema_norm
    return "other"


def _grid_layout_table(table_nodes: dict, edges: list[dict]) -> dict:
    order = ["raw_ext", "landing", "dict_stg", "dict_dds", "stg", "ods", "dds", "dm_calc", "dm_view", "other", "dm"]
    columns = {key: [] for key in order}
    for node_id in table_nodes:
        layer = _layer_of_table(node_id)
        columns.setdefault(layer, []).append(node_id)

    col_gap = 120
    row_gap = 110
    layout = {}
    cursor_x = 0
    layer_index = {layer: idx for idx, layer in enumerate(order)}
    neighbors = {node_id: [] for node_id in table_nodes}
    for edge in edges or []:
        src = edge.get("source")
        tgt = edge.get("target")
        if src in table_nodes and tgt in table_nodes:
            neighbors[src].append(layer_index.get(_layer_of_table(tgt), 0))
            neighbors[tgt].append(layer_index.get(_layer_of_table(src), 0))
    for layer in order:
        items = columns.get(layer) or []
        if not items:
            continue
        items.sort(key=lambda n: (sum(neighbors.get(n) or [0]) / max(len(neighbors.get(n) or [1]), 1), n))
        max_width = max(table_nodes[n].get("width") or 0 for n in items)
        column_center = cursor_x + (max_width / 2)
        for row_idx, node_id in enumerate(items):
            layout[node_id] = {"x": column_center, "y": row_idx * row_gap}
        cursor_x += max_width + col_gap

    return layout


def _grid_layout_subset(table_nodes: dict, edges: list[dict], node_ids: set) -> dict:
    subset = {nid: table_nodes[nid] for nid in node_ids if nid in table_nodes}
    subset_edges = [e for e in edges if e.get("source") in subset and e.get("target") in subset]
    return _grid_layout_table(subset, subset_edges)


def _normalize_layer_widths(nodes: list[dict]) -> list[dict]:
    if not nodes:
        return []
    layers = {}
    for node in nodes:
        layer = _layer_of_table(node.get("id") or "")
        layers.setdefault(layer, []).append(node)

    max_widths = {
        layer: max(n.get("width") or 0 for n in items)
        for layer, items in layers.items()
    }
    out = []
    for node in nodes:
        layer = _layer_of_table(node.get("id") or "")
        width = max_widths.get(layer) or node.get("width") or 200
        updated = dict(node)
        updated["width"] = width
        updated["height"] = 64
        out.append(updated)
    return out


def _dagre_layout(nodes: list[dict], edges: list[dict], rankdir: str = "LR") -> dict:
    if not nodes:
        return {}

    base_dir = Path(__file__).resolve().parent.parent
    script_path = base_dir / "scripts" / "dagre_layout.cjs"
    if not script_path.exists():
        raise FileNotFoundError(script_path)

    payload = {
        "nodes": nodes,
        "edges": edges,
        "rankdir": rankdir,
        "nodesep": 32,
        "ranksep": 90,
        "marginx": 20,
        "marginy": 20,
    }

    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = Path(tmpdir) / "dagre_input.json"
        output_path = Path(tmpdir) / "dagre_output.json"
        input_path.write_text(json.dumps(payload), encoding="utf-8")

        result = subprocess.run(
            ["node", str(script_path), str(input_path), str(output_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(f"dagre layout failed: {result.stderr.strip()}")

        out = json.loads(output_path.read_text(encoding="utf-8"))
        layout = out.get("nodes", {})

        # Normalize ranks to a grid to avoid excessive vertical drift.
        buckets = {}
        for node_id, pos in layout.items():
            if not pos:
                continue
            key = int(round(pos.get("x", 0)))
            buckets.setdefault(key, []).append((node_id, pos.get("y", 0)))

        if not buckets:
            return layout

        col_gap = 240
        row_gap = 90
        new_layout = {}
        for col_idx, x_key in enumerate(sorted(buckets.keys())):
            items = sorted(buckets[x_key], key=lambda item: item[1])
            for row_idx, (node_id, _y) in enumerate(items):
                new_layout[node_id] = {"x": col_idx * col_gap, "y": row_idx * row_gap}

        return new_layout


def build_graph_snapshot():
    all_meta, _ = get_cached_meta_and_index()
    meta_hash = _hash_meta(all_meta)

    entries = []
    for m in all_meta:
        schema = norm(m.get("table_schema"))
        table = norm(m.get("table_name"))
        entity = m.get("entity_name")
        if not schema or not table:
            continue
        if schema in ("raw_ext", "dict_raw_ext"):
            continue
        if isinstance(entity, str) and entity.lower() == "raw_ext":
            continue

        depends = {}
        for src_schema, tables in (m.get("depends_on") or {}).items():
            src_schema_norm = norm(src_schema)
            if not src_schema_norm:
                continue
            cleaned = [norm(t) for t in (tables or []) if t]
            depends[src_schema_norm] = [t for t in cleaned if t]

        entries.append({
            "table_schema": schema,
            "table_name": table,
            "entity_name": entity or "UNKNOWN",
            "table_id": m.get("table_id"),
            "depends_on": depends,
        })

    table_entities: dict[str, set[str]] = {}
    table_info: dict[str, dict] = {}

    def register_table(fqn: str, schema: str, table: str, entity: str, table_id):
        if fqn not in table_info:
            table_info[fqn] = {
                "id": fqn,
                "schema": schema,
                "table": table,
                "table_id": table_id,
            }
        table_entities.setdefault(fqn, set()).add(entity)

    for m in entries:
        fqn = f"{m['table_schema']}.{m['table_name']}"
        register_table(fqn, m["table_schema"], m["table_name"], m["entity_name"], m.get("table_id"))

    edges_set: set[tuple[str, str]] = set()
    for m in entries:
        target = f"{m['table_schema']}.{m['table_name']}"
        for src_schema, tables in (m.get("depends_on") or {}).items():
            for src_table in tables:
                source = f"{src_schema}.{src_table}"
                edges_set.add((source, target))
                if source not in table_info:
                    schema_val, table_val = source.split(".", 1)
                    register_table(source, schema_val, table_val, "UNKNOWN", None)

    table_nodes = {}
    for fqn, info in table_info.items():
        entities = sorted(table_entities.get(fqn) or [])
        width = _estimate_node_width(fqn, min_width=200, max_width=520)
        table_nodes[fqn] = {
            "id": fqn,
            "schema": info["schema"],
            "table": info["table"],
            "entity": entities[0] if entities else "UNKNOWN",
            "entities": entities,
            "table_id": info.get("table_id"),
            "shared": len(entities) > 1,
            "width": width,
            "height": 64,
        }

    table_edges = [{"source": s, "target": t} for s, t in sorted(edges_set)]

    entity_nodes = {}
    entity_tables: dict[str, set[str]] = {}
    for fqn, entities in table_entities.items():
        for ent in entities:
            if not ent or ent == "UNKNOWN":
                continue
            entity_tables.setdefault(ent, set()).add(fqn)

    for ent, tables in entity_tables.items():
        node_id = f"ENTITY::{ent}"
        width = _estimate_node_width(ent, min_width=140, max_width=320)
        entity_nodes[node_id] = {
            "id": node_id,
            "label": ent,
            "tables_count": len(tables),
            "width": width,
            "height": 56,
        }

    entity_edges_set: set[tuple[str, str]] = set()
    for edge in edges_set:
        src, tgt = edge
        src_entities = table_entities.get(src) or set()
        tgt_entities = table_entities.get(tgt) or set()
        for src_ent in src_entities:
            for tgt_ent in tgt_entities:
                if (
                    not src_ent
                    or not tgt_ent
                    or src_ent == tgt_ent
                    or src_ent == "UNKNOWN"
                    or tgt_ent == "UNKNOWN"
                ):
                    continue
                entity_edges_set.add((f"ENTITY::{src_ent}", f"ENTITY::{tgt_ent}"))

    entity_edges = [{"source": s, "target": t} for s, t in sorted(entity_edges_set)]

    entity_ids = list(entity_nodes.keys())
    sccs = _find_sccs(entity_ids, entity_edges)
    entity_cycles = []
    for scc in sccs:
        if len(scc) <= 1:
            continue
        labels = [entity_nodes.get(node_id, {}).get("label", node_id) for node_id in scc]
        entity_cycles.append({"nodes": labels, "size": len(labels)})

    edge_set = {(e["source"], e["target"]) for e in entity_edges}
    entity_mutual = []
    entity_mutual_any = []
    mutual_pairs = set()
    mutual_pairs_any = set()
    for src, tgt in edge_set:
        if (tgt, src) in edge_set:
            pair_key = tuple(sorted([src, tgt]))
            mutual_pairs_any.add(pair_key)

    table_pair_edges = {}
    table_pair_edges_rev = {}
    table_pair_edges_any = {}
    table_pair_edges_any_rev = {}
    exclusive_pair_edges = set()
    def is_exclusive_edge(src_ents: set, tgt_ents: set, left_ent: str, right_ent: str) -> bool:
        return (
            left_ent in src_ents
            and right_ent in tgt_ents
            and right_ent not in src_ents
            and left_ent not in tgt_ents
            and len(src_ents) == 1
            and len(tgt_ents) == 1
        )

    def is_pair_edge(src_ents: set, tgt_ents: set, left_ent: str, right_ent: str) -> bool:
        src_norm = {e.lower() for e in src_ents if isinstance(e, str)}
        tgt_norm = {e.lower() for e in tgt_ents if isinstance(e, str)}
        left_norm = left_ent.lower()
        right_norm = right_ent.lower()
        allowed = {left_norm, right_norm}
        return (
            left_norm in src_norm
            and right_norm in tgt_norm
            and left_norm not in tgt_norm
            and right_norm not in src_norm
            and src_norm.issubset(allowed)
            and tgt_norm.issubset(allowed)
        )

    for edge in table_edges:
        src = edge["source"]
        tgt = edge["target"]
        src_entities = table_entities.get(src) or set()
        tgt_entities = table_entities.get(tgt) or set()
        for src_ent in src_entities:
            for tgt_ent in tgt_entities:
                if not src_ent or not tgt_ent or src_ent == tgt_ent:
                    continue
                pair_key = (f"ENTITY::{src_ent}", f"ENTITY::{tgt_ent}")
                if tuple(sorted(pair_key)) in mutual_pairs_any and is_pair_edge(src_entities, tgt_entities, src_ent, tgt_ent):
                    table_pair_edges_any.setdefault(pair_key, set()).add((src, tgt))
                    table_pair_edges_any_rev.setdefault(tuple(sorted(pair_key)), {}).setdefault(pair_key, set()).add((src, tgt))
                if is_exclusive_edge(src_entities, tgt_entities, src_ent, tgt_ent):
                    exclusive_pair_edges.add(pair_key)
                    table_pair_edges.setdefault(pair_key, set()).add((src, tgt))
                    table_pair_edges_rev.setdefault(tuple(sorted(pair_key)), {}).setdefault(pair_key, set()).add((src, tgt))

    for src, tgt in exclusive_pair_edges:
        if (tgt, src) in exclusive_pair_edges:
            mutual_pairs.add(tuple(sorted([src, tgt])))

    for pair_key in sorted(mutual_pairs_any):
        left, right = pair_key
        edges_forward = sorted(table_pair_edges_any_rev.get(pair_key, {}).get((left, right), set()))
        edges_backward = sorted(table_pair_edges_any_rev.get(pair_key, {}).get((right, left), set()))
        entity_mutual_any.append({
            "a": entity_nodes.get(left, {}).get("label", left),
            "b": entity_nodes.get(right, {}).get("label", right),
            "edges_ab_count": len(edges_forward),
            "edges_ba_count": len(edges_backward),
            "edges_ab_sample": [{"source": s, "target": t} for s, t in edges_forward[:10]],
            "edges_ba_sample": [{"source": s, "target": t} for s, t in edges_backward[:10]],
        })

    for pair_key in sorted(mutual_pairs):
        left, right = pair_key
        edges_forward = sorted(table_pair_edges_rev.get(pair_key, {}).get((left, right), set()))
        edges_backward = sorted(table_pair_edges_rev.get(pair_key, {}).get((right, left), set()))
        entity_mutual.append({
            "a": entity_nodes.get(left, {}).get("label", left),
            "b": entity_nodes.get(right, {}).get("label", right),
            "edges_ab_count": len(edges_forward),
            "edges_ba_count": len(edges_backward),
            "edges_ab_sample": [{"source": s, "target": t} for s, t in edges_forward[:10]],
            "edges_ba_sample": [{"source": s, "target": t} for s, t in edges_backward[:10]],
        })

    table_ids = list(table_nodes.keys())
    table_sccs = _find_sccs(table_ids, table_edges)
    table_cycles = []
    for scc in table_sccs:
        if len(scc) <= 1:
            continue
        sample = sorted(scc)[:8]
        table_cycles.append({"size": len(scc), "nodes": sample})
    table_cycles.sort(key=lambda c: c["size"], reverse=True)
    table_cycles = table_cycles[:10]

    entity_layout_nodes = []
    for node_id, node in entity_nodes.items():
        label = node["label"]
        entity_layout_nodes.append({
            "id": node_id,
            "width": node.get("width") or _estimate_node_width(label, min_width=140, max_width=320),
            "height": node.get("height") or 56,
        })

    table_layout_nodes = []
    for fqn, node in table_nodes.items():
        label = fqn
        table_layout_nodes.append({
            "id": fqn,
            "width": node.get("width") or _estimate_node_width(label, min_width=170, max_width=460),
            "height": node.get("height") or 56,
        })

    entity_layout = _dagre_layout(entity_layout_nodes, entity_edges, rankdir="LR")
    table_layout = _grid_layout_table(table_nodes, table_edges)

    return {
        "meta_hash": meta_hash,
        "meta_ts": _cache_timestamp,
        "generated_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
        "table_graph": {"nodes": table_nodes, "edges": table_edges},
        "entity_graph": {"nodes": entity_nodes, "edges": entity_edges},
        "layouts": {"entity": entity_layout, "table": table_layout},
        "table_entity_map": {k: sorted(v) for k, v in table_entities.items()},
        "entity_cycles": entity_cycles,
        "entity_mutual": entity_mutual,
        "entity_mutual_any": entity_mutual_any,
        "table_cycles": table_cycles,
    }


def get_graph_snapshot():
    global _graph_snapshot, _graph_snapshot_ts, _graph_snapshot_hash
    now = time.time()

    if _graph_snapshot and now - _graph_snapshot_ts < _GRAPH_SNAPSHOT_TTL:
        if _graph_snapshot.get("meta_ts") == _cache_timestamp:
            return _graph_snapshot

    snapshot = build_graph_snapshot()
    _graph_snapshot = snapshot
    _graph_snapshot_ts = now
    _graph_snapshot_hash = snapshot.get("meta_hash")
    return snapshot


def _cap_graph(nodes: dict, edges: list, layout: dict, max_nodes: int, max_edges: int, sort_key: str = None):
    node_list = list(nodes.values())
    if sort_key:
        node_list.sort(key=lambda n: n.get(sort_key) or 0, reverse=True)
    node_ids = {n["id"] for n in node_list[:max_nodes]}

    truncated = len(nodes) > max_nodes
    filtered_edges = [e for e in edges if e["source"] in node_ids and e["target"] in node_ids]

    if len(filtered_edges) > max_edges:
        filtered_edges = filtered_edges[:max_edges]
        truncated = True

    filtered_nodes = {nid: nodes[nid] for nid in node_ids if nid in nodes}
    filtered_layout = {nid: layout.get(nid) for nid in node_ids if nid in layout}
    return filtered_nodes, filtered_edges, filtered_layout, truncated

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
        get_graph_snapshot()
    except Exception as e:
        print("Ошибка при старте приложения:", e)


BASE_DIR = Path(__file__).resolve().parent.parent
META_PARENT_DIRS = [BASE_DIR / "project", BASE_DIR]


def iter_meta_dirs(targets: Optional[List[str]] = None):
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


def normalize_excel_table_name(value: Optional[str]) -> Optional[str]:
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


def format_excel_datetime(value) -> Optional[str]:
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


def pick_table_match(table_normalized: Optional[str], entity_hint: Optional[str], by_fqn: dict, by_name: dict):
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


def import_ytrek_from_excel(file_path: Union[str, Path]) -> int:
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


def extract_incident_day(row: dict) -> Optional[date]:
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
    schema = (schema or "").strip().lower()
    table = (table or "").strip().lower()
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
    visited: Optional[set] = None
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
                  AND loading_start_dttm >= now() - interval '24 hours'
            """
                )
            ).scalar()

            avg_duration = conn.execute(
                text(
                    f"""
                SELECT ROUND(cast(AVG(EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60) as numeric), 1)
                FROM {TABLE_LOADING_HISTORY}
                WHERE loading_state = 'SUCCESS' and object_type='table'
                  AND loading_start_dttm >= now() - interval '24 hours'
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


@router.get("/api/table-history/{schema}/{table}")
def get_table_history(schema: str, table: str, limit: int = Query(10, ge=1, le=50)):
    schema_norm = norm(schema)
    table_norm = norm(table)
    table_id = None

    try:
        with engine.connect() as conn:
            table_id = conn.execute(
                text(
                    f"""
                    SELECT table_id
                    FROM {TABLE_TABLES_META}
                    WHERE lower(table_schema) = :schema
                      AND lower(table_name) = :table
                    LIMIT 1
                    """
                ),
                {"schema": schema_norm, "table": table_norm},
            ).scalar()

            params = {"limit": limit}
            if table_id:
                where_clause = "object_id = :table_id"
                params["table_id"] = table_id
            else:
                where_clause = "lower(object_name) = :table_fqn OR lower(object_name) = :table_name"
                params["table_fqn"] = f"{schema_norm}.{table_norm}"
                params["table_name"] = table_norm

            rows = conn.execute(
                text(
                    f"""
                    SELECT
                        loading_start_dttm,
                        loading_finish_dttm,
                        loading_state,
                        message,
                        EXTRACT(EPOCH FROM (loading_finish_dttm - loading_start_dttm)) / 60.0 AS duration_minutes
                    FROM {TABLE_LOADING_HISTORY}
                    WHERE object_type = 'table'
                      AND {where_clause}
                    ORDER BY loading_finish_dttm DESC NULLS LAST
                    LIMIT :limit
                    """
                ),
                params,
            ).mappings().all()

        payload = [
            {
                "start": serialize_datetime(row.get("loading_start_dttm")),
                "finish": serialize_datetime(row.get("loading_finish_dttm")),
                "state": row.get("loading_state"),
                "message": row.get("message"),
                "duration_minutes": round(float(row["duration_minutes"]), 2)
                if row.get("duration_minutes") is not None
                else None,
            }
            for row in rows
        ]
        return JSONResponse(content=payload, media_type="application/json; charset=utf-8")
    except Exception as e:
        traceback.print_exc()
        return JSONResponse(status_code=500, content={"error": str(e)})


def find_path_case_insensitive(parent_path: Path, name: str) -> Optional[Path]:
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
    all_meta, _ = get_cached_meta_and_index()
    all_tables = {}
    for meta in all_meta:
        schema = meta.get("table_schema")
        table = meta.get("table_name")
        if schema and table:
            key = f"{schema}.{table}"
            all_tables.setdefault(key.lower(), key)
    return JSONResponse(content=sorted(all_tables.values(), key=lambda v: v.lower()))


@router.get("/api/graph/overview")
def get_graph_overview():
    snapshot = get_graph_snapshot()
    nodes = snapshot["entity_graph"]["nodes"]
    edges = snapshot["entity_graph"]["edges"]
    layout = snapshot["layouts"]["entity"]

    nodes, edges, layout, truncated = _cap_graph(
        nodes, edges, layout, max_nodes=150, max_edges=300, sort_key="tables_count"
    )
    return {
        "nodes": list(nodes.values()),
        "edges": edges,
        "layout": layout,
        "truncated": truncated,
        "entity_cycles": snapshot.get("entity_cycles", []),
        "entity_mutual": snapshot.get("entity_mutual_any", []),
        "table_cycles": snapshot.get("table_cycles", []),
    }


@router.get("/api/graph/diagnostics")
def get_graph_diagnostics(include_any: bool = Query(True)):
    snapshot = get_graph_snapshot()
    return {
        "entity_cycles": snapshot.get("entity_cycles", []),
        "entity_mutual": snapshot.get("entity_mutual_any", []) if include_any else snapshot.get("entity_mutual", []),
        "table_cycles": snapshot.get("table_cycles", []),
    }


@router.get("/api/graph/diagnostics/mutual")
def get_graph_mutual_details(
    entity_a: str = Query(...),
    entity_b: str = Query(...),
    strict: bool = Query(True),
):
    snapshot = get_graph_snapshot()
    table_edges = snapshot["table_graph"]["edges"]
    table_entities = {k: set(v) for k, v in snapshot["table_entity_map"].items()}

    def norm_entity(value: str) -> str:
        return (value or "").strip().lower()

    a = norm_entity(entity_a)
    b = norm_entity(entity_b)
    if not a or not b:
        return JSONResponse(status_code=400, content={"error": "invalid entities"})

    edges_ab = []
    edges_ba = []
    for edge in table_edges:
        src = edge.get("source")
        tgt = edge.get("target")
        if not src or not tgt:
            continue
        src_ents = table_entities.get(src) or set()
        tgt_ents = table_entities.get(tgt) or set()
        for src_ent in src_ents:
            for tgt_ent in tgt_ents:
                if not src_ent or not tgt_ent or src_ent == tgt_ent:
                    continue
                src_norm = {norm_entity(e) for e in src_ents if isinstance(e, str)}
                tgt_norm = {norm_entity(e) for e in tgt_ents if isinstance(e, str)}
                allowed = {a, b}
                if strict and (not src_norm.issubset(allowed) or not tgt_norm.issubset(allowed)):
                    continue
                if (
                    norm_entity(src_ent) == a
                    and norm_entity(tgt_ent) == b
                    and norm_entity(tgt_ent) not in {norm_entity(e) for e in src_ents}
                    and norm_entity(src_ent) not in {norm_entity(e) for e in tgt_ents}
                ):
                    edges_ab.append({
                        "source": src,
                        "target": tgt,
                        "source_entities": sorted(src_ents),
                        "target_entities": sorted(tgt_ents),
                    })
                elif (
                    norm_entity(src_ent) == b
                    and norm_entity(tgt_ent) == a
                    and norm_entity(tgt_ent) not in {norm_entity(e) for e in src_ents}
                    and norm_entity(src_ent) not in {norm_entity(e) for e in tgt_ents}
                ):
                    edges_ba.append({
                        "source": src,
                        "target": tgt,
                        "source_entities": sorted(src_ents),
                        "target_entities": sorted(tgt_ents),
                    })

    return {
        "entity_a": entity_a,
        "entity_b": entity_b,
        "edges_ab": edges_ab,
        "edges_ba": edges_ba,
    }


@router.get("/api/graph/entity/{entity_name}")
def get_graph_entity(entity_name: str):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]
    table_entity_map = snapshot["table_entity_map"]

    target = (entity_name or "").strip().lower()
    all_entities = {e for ents in table_entity_map.values() for e in ents}
    entity_key = next((e for e in all_entities if e.lower() == target), None)

    if not entity_key:
        return JSONResponse(status_code=404, content={"error": "entity not found"})

    entity_tables = {t for t, ents in table_entity_map.items() if entity_key in ents}
    if not entity_tables:
        return JSONResponse(status_code=404, content={"error": "entity has no tables"})

    nodes_set = set(entity_tables)
    edges_filtered = []
    for e in table_edges:
        if e["source"] in entity_tables or e["target"] in entity_tables:
            nodes_set.add(e["source"])
            nodes_set.add(e["target"])
            edges_filtered.append(e)

    truncated = False
    if len(nodes_set) > 300:
        keep = set(entity_tables)
        extra = [n for n in nodes_set if n not in keep]
        extra.sort()
        for n in extra:
            if len(keep) >= 300:
                truncated = True
                break
            keep.add(n)
        nodes_set = keep

    edges_filtered = [e for e in edges_filtered if e["source"] in nodes_set and e["target"] in nodes_set]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in nodes_set if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, nodes_set)

    return {
        "entity": {
            "id": f"ENTITY::{entity_key}",
            "label": entity_key,
            "tables_count": len(entity_tables),
        },
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "truncated": truncated,
    }


@router.get("/api/graph/table/{schema}/{table}")
def get_graph_table(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    rev = {}
    for e in table_edges:
        rev.setdefault(e["target"], []).append(e["source"])

    visited = {key}
    queue = deque([(key, 0)])
    truncated = False
    max_nodes = 300

    while queue:
        node, d = queue.popleft()
        if d >= depth:
            continue
        for nxt in rev.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            if len(visited) >= max_nodes:
                truncated = True
                queue.clear()
                break
            queue.append((nxt, d + 1))
        if truncated:
            break

    edges_filtered = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in visited if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, visited)

    return {
        "table": table_nodes[key],
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "depth": depth,
        "truncated": truncated,
    }


def _layer_label_from_schema(schema: str) -> str:
    if not schema:
        return "OTHER"
    schema = schema.lower()
    if schema.startswith("dict_"):
        return "DICT"
    if schema == "stg":
        return "STG"
    if schema == "ods":
        return "ODS"
    if schema == "dds":
        return "DDS"
    if schema == "dm_calc":
        return "DM_CALC"
    if schema.startswith("dm"):
        return "DM"
    return schema.upper()


def _traverse_forward(
    start: str,
    edges: list[dict],
    depth: int,
    max_nodes: int,
) -> tuple[set[str], dict[str, int], bool]:
    forward = {}
    for edge in edges:
        forward.setdefault(edge["source"], []).append(edge["target"])

    visited = {start}
    depth_map = {start: 0}
    queue = deque([(start, 0)])
    truncated = False

    while queue:
        node, d = queue.popleft()
        if d >= depth:
            continue
        for nxt in forward.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            depth_map[nxt] = d + 1
            if len(visited) >= max_nodes:
                truncated = True
                queue.clear()
                break
            queue.append((nxt, d + 1))
        if truncated:
            break

    return visited, depth_map, truncated


@router.get("/api/graph/impact/{schema}/{table}")
def get_graph_impact(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, _, truncated = _traverse_forward(key, table_edges, depth, max_nodes=300)

    edges_filtered = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
    if len(edges_filtered) > 500:
        edges_filtered = edges_filtered[:500]
        truncated = True

    nodes_payload = _normalize_layer_widths([table_nodes[n] for n in visited if n in table_nodes])
    layout_payload = _grid_layout_subset(table_nodes, edges_filtered, visited)

    return {
        "table": table_nodes[key],
        "nodes": nodes_payload,
        "edges": edges_filtered,
        "layout": layout_payload,
        "depth": depth,
        "truncated": truncated,
    }


@router.get("/api/impact/summary/{schema}/{table}")
def get_impact_summary(
    schema: str,
    table: str,
    depth: int = Query(3, ge=1, le=5),
    max_nodes: int = Query(800, ge=50, le=5000),
    limit: int = Query(120, ge=0, le=2000),
):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, depth_map, truncated = _traverse_forward(key, table_edges, depth, max_nodes=max_nodes)
    visited.discard(key)

    entity_counts = {}
    layer_counts = {}
    table_rows = []
    for node_id in visited:
        node = table_nodes.get(node_id)
        if not node:
            continue
        schema_val = node.get("schema") or ""
        layer = _layer_label_from_schema(schema_val)
        layer_counts[layer] = layer_counts.get(layer, 0) + 1

        entities = node.get("entities") or []
        if not entities:
            entities = [node.get("entity") or "UNKNOWN"]
        for ent in entities:
            if not ent:
                continue
            entity_counts[ent] = entity_counts.get(ent, 0) + 1

        table_rows.append(
            {
                "id": node_id,
                "schema": node.get("schema"),
                "table": node.get("table"),
                "entity": node.get("entity"),
                "entities": entities,
                "layer": layer,
                "depth": depth_map.get(node_id, 0),
            }
        )

    entities_list = [
        {"entity": ent, "count": count}
        for ent, count in sorted(entity_counts.items(), key=lambda x: (-x[1], x[0]))
    ]
    layers_list = [
        {"layer": layer, "count": count}
        for layer, count in sorted(layer_counts.items(), key=lambda x: (-x[1], x[0]))
    ]

    table_rows.sort(key=lambda r: (r.get("depth") or 0, r.get("id") or ""))
    if limit:
        table_rows = table_rows[:limit]

    return {
        "table": table_nodes[key],
        "total_tables": len(visited),
        "total_entities": len(entity_counts),
        "entities": entities_list,
        "layers": layers_list,
        "tables": table_rows,
        "depth": depth,
        "truncated": truncated,
    }


@router.get("/api/impact/list/{schema}/{table}")
def get_impact_list(
    schema: str,
    table: str,
    depth: int = Query(4, ge=1, le=6),
    max_nodes: int = Query(2500, ge=100, le=10000),
):
    snapshot = get_graph_snapshot()
    table_nodes = snapshot["table_graph"]["nodes"]
    table_edges = snapshot["table_graph"]["edges"]

    schema_norm = norm(schema)
    table_norm = norm(table)
    key = f"{schema_norm}.{table_norm}"
    if key not in table_nodes:
        return JSONResponse(status_code=404, content={"error": "table not found"})

    visited, depth_map, truncated = _traverse_forward(key, table_edges, depth, max_nodes=max_nodes)
    visited.discard(key)

    table_rows = []
    for node_id in visited:
        node = table_nodes.get(node_id)
        if not node:
            continue
        schema_val = node.get("schema") or ""
        layer = _layer_label_from_schema(schema_val)
        entities = node.get("entities") or []
        if not entities:
            entities = [node.get("entity") or "UNKNOWN"]
        table_rows.append(
            {
                "id": node_id,
                "schema": node.get("schema"),
                "table": node.get("table"),
                "entities": entities,
                "layer": layer,
                "depth": depth_map.get(node_id, 0),
            }
        )

    table_rows.sort(key=lambda r: (r.get("depth") or 0, r.get("id") or ""))
    return {
        "table": table_nodes[key],
        "tables": table_rows,
        "depth": depth,
        "truncated": truncated,
    }


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
    schema: Optional[str] = Query(None),
):
    try:
        schema = schema.strip() if isinstance(schema, str) else None
        query = f"""
            WITH base AS (
                SELECT
                    COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), '')) AS table_schema,
                    COALESCE(t.table_name, NULLIF(split_part(l.object_name, '.', 2), ''), l.object_name) AS table_name,
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
                  AND (
                    :schema IS NULL OR
                    LOWER(COALESCE(t.table_schema, NULLIF(split_part(l.object_name, '.', 1), ''))) = LOWER(:schema)
                  )
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
def get_dependency_graph(
    schema: str,
    table: str,
    max_depth: Optional[int] = Query(None, ge=1),
    max_edges: Optional[int] = Query(None, ge=1),
):
    try:
        schema_norm = norm(schema)
        table_norm = norm(table)
        key = f"{schema_norm}.{table_norm}"
        now = time.time()

        all_meta_list, _ = get_cached_meta_and_index()
        if _graph_cache_meta_ts != _cache_timestamp:
            _graph_cache.clear()
            globals()["_graph_cache_meta_ts"] = _cache_timestamp
            globals()["_graph_cache_ts"] = now

        cache_key = (key, max_depth, max_edges)
        if _graph_cache and now - _graph_cache_ts < _GRAPH_CACHE_TTL:
            cached = _graph_cache.get(cache_key)
            if cached is not None:
                return cached

        all_meta = {
            f"{m.get('table_schema')}.{m.get('table_name')}": m
            for m in all_meta_list
            if m.get("table_schema") and m.get("table_name")
        }
        reverse_index = {}
        for m in all_meta_list:
            consumer = (m.get("table_schema"), m.get("table_name"))
            for src_schema, tables in (m.get("depends_on") or {}).items():
                for src_table in tables or []:
                    reverse_index.setdefault((src_schema, src_table), []).append({
                        "schema": consumer[0],
                        "table_name": consumer[1],
                    })
        visited = set()
        edges_set = set()
        truncated = False

        stack = [(key, 0)]
        while stack:
            current, depth = stack.pop()
            if current in visited:
                continue
            visited.add(current)

            meta = all_meta.get(current)
            if not meta:
                continue
            if max_depth is not None and depth >= max_depth:
                schema_val, table_val = current.split(".", 1)
                if meta.get("depends_on") or reverse_index.get((schema_val, table_val)):
                    truncated = True
                continue

            depends_on = meta.get("depends_on") or {}
            for source_schema, source_tables in depends_on.items():
                if not source_schema:
                    continue
                for source_table in source_tables or []:
                    if not source_table:
                        continue
                    source = f"{source_schema}.{source_table}"
                    edge_key = (source, current)
                    if edge_key not in edges_set:
                        edges_set.add(edge_key)
                        if max_edges is not None and len(edges_set) >= max_edges:
                            truncated = True
                            stack = []
                            break
                    stack.append((source, depth + 1))
                if truncated:
                    break
            if truncated:
                break

            schema_val, table_val = current.split(".", 1)
            for consumer in reverse_index.get((schema_val, table_val), []):
                if not consumer.get("schema") or not consumer.get("table_name"):
                    continue
                target = f"{consumer['schema']}.{consumer['table_name']}"
                edge_key = (current, target)
                if edge_key not in edges_set:
                    edges_set.add(edge_key)
                    if max_edges is not None and len(edges_set) >= max_edges:
                        truncated = True
                        stack = []
                        break
                stack.append((target, depth + 1))
            if truncated:
                break

        edges = [{"source": s, "target": t} for s, t in edges_set]
        payload = {"centralNode": key, "edges": edges, "truncated": truncated}

        if now - _graph_cache_ts >= _GRAPH_CACHE_TTL:
            _graph_cache.clear()
            globals()["_graph_cache_ts"] = now
        _graph_cache[cache_key] = payload
        return payload

    except Exception as e:
        print("Ошибка при построении графа зависимостей:", e)
        return JSONResponse(status_code=500, content={"error": str(e)})


@router.get("/api/dependencies-nodes/{schema}/{table}")
def get_dependency_nodes(
    schema: str,
    table: str,
    max_depth: Optional[int] = Query(None, ge=1),
    max_nodes: Optional[int] = Query(None, ge=1),
):
    try:
        schema_norm = norm(schema)
        table_norm = norm(table)
        key = f"{schema_norm}.{table_norm}"

        all_meta_list, _ = get_cached_meta_and_index()
        all_meta = {
            f"{m.get('table_schema')}.{m.get('table_name')}": m
            for m in all_meta_list
            if m.get("table_schema") and m.get("table_name")
        }
        reverse_index = {}
        for m in all_meta_list:
            consumer = (m.get("table_schema"), m.get("table_name"))
            for src_schema, tables in (m.get("depends_on") or {}).items():
                for src_table in tables or []:
                    reverse_index.setdefault((src_schema, src_table), []).append({
                        "schema": consumer[0],
                        "table_name": consumer[1],
                    })

        visited = set()
        truncated = False
        stack = [(key, 0)]

        while stack:
            current, depth = stack.pop()
            if current in visited:
                continue
            visited.add(current)
            if max_nodes is not None and len(visited) >= max_nodes:
                truncated = True
                break

            meta = all_meta.get(current)
            if not meta:
                continue
            if max_depth is not None and depth >= max_depth:
                schema_val, table_val = current.split(".", 1)
                if meta.get("depends_on") or reverse_index.get((schema_val, table_val)):
                    truncated = True
                continue

            depends_on = meta.get("depends_on") or {}
            for source_schema, source_tables in depends_on.items():
                if not source_schema:
                    continue
                for source_table in source_tables or []:
                    if not source_table:
                        continue
                    source = f"{source_schema}.{source_table}"
                    stack.append((source, depth + 1))

            schema_val, table_val = current.split(".", 1)
            for consumer in reverse_index.get((schema_val, table_val), []):
                if not consumer.get("schema") or not consumer.get("table_name"):
                    continue
                target = f"{consumer['schema']}.{consumer['table_name']}"
                stack.append((target, depth + 1))

        nodes = sorted(visited, key=lambda v: v.lower())
        return {"centralNode": key, "nodes": nodes, "truncated": truncated}
    except Exception as e:
        print("Ошибка при построении списка зависимостей:", e)
        return JSONResponse(status_code=500, content={"error": str(e)})





@router.get("/api/gantt/{schema}/{table:path}")
def get_gantt_data(schema: str, table: str, depth: int = Query(3, ge=1, le=4)):
    try:
        snapshot = get_graph_snapshot()
        table_nodes = snapshot["table_graph"]["nodes"]
        table_edges = snapshot["table_graph"]["edges"]

        schema_norm = norm(schema)
        table_norm = norm(table)
        start_table = f"{schema_norm}.{table_norm}"
        if start_table not in table_nodes:
            return JSONResponse(status_code=404, content={"error": f"'{start_table}' not found in meta"})

        reverse = {}
        for edge in table_edges:
            reverse.setdefault(edge["target"], []).append(edge["source"])

        visited = {start_table}
        queue = deque([(start_table, 0)])
        while queue:
            node, d = queue.popleft()
            if d >= depth:
                continue
            for src in reverse.get(node, []):
                if src in visited:
                    continue
                visited.add(src)
                queue.append((src, d + 1))

        edges = [e for e in table_edges if e["source"] in visited and e["target"] in visited]
        table_to_id = {
            t: table_nodes[t]["table_id"]
            for t in visited
            if t in table_nodes and table_nodes[t].get("table_id")
        }

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
