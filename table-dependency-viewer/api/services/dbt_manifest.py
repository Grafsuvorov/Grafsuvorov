from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


_MANIFEST_CACHE: dict[str, dict[str, Any]] = {}
_GRAPH_CACHE: dict[str, dict[str, Any]] = {}


def _resolve_manifest_path(base_dir: Path, manifest_dir: str, source: str) -> Path:
    root = Path(manifest_dir)
    if not root.is_absolute():
        root = (base_dir / root).resolve()
    return root / source / "manifest.json"


def _parse_relation_name(value: Any) -> tuple[str | None, str | None]:
    text = str(value or "").strip()
    if not text:
        return None, None
    quoted = re.findall(r'"([^"]+)"', text)
    if len(quoted) >= 3:
        return quoted[-2], quoted[-1]
    parts = [part.strip().strip('"') for part in text.split(".") if part.strip()]
    if len(parts) >= 2:
        return parts[-2], parts[-1]
    return None, None


def _normalize_columns(columns: Any) -> list[dict[str, Any]]:
    if not isinstance(columns, dict):
        return []
    items: list[dict[str, Any]] = []
    for key, value in columns.items():
        if isinstance(value, dict):
            items.append(
                {
                    "name": value.get("name") or key,
                    "description": value.get("description") or "",
                    "data_type": value.get("data_type"),
                }
            )
        else:
            items.append({"name": key, "description": "", "data_type": None})
    return items


def _normalize_refs(items: Any) -> list[dict[str, Any]]:
    if not isinstance(items, list):
        return []
    out: list[dict[str, Any]] = []
    for item in items:
        if isinstance(item, dict):
            out.append(
                {
                    "name": item.get("name"),
                    "package": item.get("package"),
                    "version": item.get("version"),
                }
            )
    return out


def _candidate_keys(node: dict[str, Any]) -> set[str]:
    keys: set[str] = set()
    schema_name = str(node.get("schema") or "").strip()
    table_name = str(node.get("alias") or node.get("name") or "").strip()
    if schema_name and table_name:
        keys.add(f"{schema_name.lower()}.{table_name.lower()}")
    relation_schema, relation_table = _parse_relation_name(node.get("relation_name"))
    if relation_schema and relation_table:
        keys.add(f"{relation_schema.lower()}.{relation_table.lower()}")
    name_value = str(node.get("name") or "").strip()
    if schema_name and name_value:
        keys.add(f"{schema_name.lower()}.{name_value.lower()}")
    return keys


def _dbt_relation_parts(node: dict[str, Any]) -> tuple[str | None, str | None]:
    schema_name = str(node.get("schema") or "").strip()
    table_name = str(
        node.get("alias")
        or node.get("identifier")
        or node.get("name")
        or ""
    ).strip()
    if schema_name and table_name:
        return schema_name.lower(), table_name.lower()
    relation_schema, relation_table = _parse_relation_name(node.get("relation_name"))
    if relation_schema and relation_table:
        return relation_schema.lower(), relation_table.lower()
    return None, None


def _load_manifest_index(base_dir: Path, manifest_dir: str, source: str = "ohd") -> dict[str, Any]:
    path = _resolve_manifest_path(base_dir, manifest_dir, source)
    cache_key = str(path)
    try:
        stat = path.stat()
    except FileNotFoundError:
        _MANIFEST_CACHE.pop(cache_key, None)
        return {"path": path, "index": {}, "nodes": {}, "metadata": None}

    cached = _MANIFEST_CACHE.get(cache_key)
    if cached and cached.get("mtime_ns") == stat.st_mtime_ns and cached.get("size") == stat.st_size:
        return cached["payload"]

    raw = json.loads(path.read_text(encoding="utf-8"))
    nodes = raw.get("nodes") or {}
    sources = raw.get("sources") or {}
    index: dict[str, dict[str, Any]] = {}

    for unique_id, node in nodes.items():
        if not isinstance(node, dict):
            continue
        if node.get("resource_type") != "model":
            continue
        normalized = {
            "unique_id": unique_id,
            "schema": node.get("schema"),
            "table_name": node.get("alias") or node.get("name"),
            "model_name": node.get("name"),
            "database": node.get("database"),
            "package_name": node.get("package_name"),
            "resource_type": node.get("resource_type"),
            "access": node.get("access"),
            "description": node.get("description") or "",
            "tags": node.get("tags") or node.get("config", {}).get("tags") or [],
            "original_file_path": node.get("original_file_path") or node.get("path"),
            "path": node.get("path"),
            "patch_path": node.get("patch_path"),
            "build_path": node.get("build_path"),
            "compiled_path": node.get("compiled_path"),
            "relation_name": node.get("relation_name"),
            "materialized": (node.get("config") or {}).get("materialized"),
            "config": node.get("config") or {},
            "meta": node.get("meta") or {},
            "checksum": (node.get("checksum") or {}).get("checksum"),
            "created_at": node.get("created_at"),
            "raw_code": node.get("raw_code") or "",
            "language": node.get("language"),
            "refs": _normalize_refs(node.get("refs")),
            "sources": list(node.get("sources") or []),
            "metrics": list(node.get("metrics") or []),
            "columns": _normalize_columns(node.get("columns")),
            "depends_on_nodes": list(((node.get("depends_on") or {}).get("nodes") or [])),
        }
        for key in _candidate_keys(node):
            index[key] = normalized

    for record in index.values():
        upstream_models: list[dict[str, Any]] = []
        for dep_unique_id in record["depends_on_nodes"]:
            dep_node = nodes.get(dep_unique_id)
            if not isinstance(dep_node, dict):
                upstream_models.append({"unique_id": dep_unique_id, "schema": None, "table_name": None})
                continue
            upstream_models.append(
                {
                    "unique_id": dep_unique_id,
                    "schema": dep_node.get("schema"),
                    "table_name": dep_node.get("alias") or dep_node.get("name"),
                    "model_name": dep_node.get("name"),
                }
            )
        record["upstream_models"] = upstream_models

    payload = {
        "path": path,
        "index": index,
        "nodes": nodes,
        "sources": sources,
        "metadata": raw.get("metadata") or {},
    }
    _MANIFEST_CACHE[cache_key] = {
        "mtime_ns": stat.st_mtime_ns,
        "size": stat.st_size,
        "payload": payload,
    }
    return payload


def get_dbt_graph_snapshot(base_dir: Path, manifest_dir: str, source: str = "ohd") -> dict[str, Any]:
    payload = _load_manifest_index(base_dir, manifest_dir, source)
    path = payload["path"]
    graph_cache_key = str(path)
    manifest_cache = _MANIFEST_CACHE.get(graph_cache_key) or {}
    cache_stamp = (manifest_cache.get("mtime_ns"), manifest_cache.get("size"))
    cached_graph = _GRAPH_CACHE.get(graph_cache_key)
    if cached_graph and cached_graph.get("stamp") == cache_stamp:
        return cached_graph["payload"]

    nodes_raw = payload["nodes"] or {}
    sources_raw = payload.get("sources") or {}
    table_nodes: dict[str, dict[str, Any]] = {}
    unique_to_node_id: dict[str, str] = {}
    fqn_to_node_ids: dict[str, set[str]] = {}
    edges: list[dict[str, str]] = []

    allowed_resource_types = {"model", "seed", "snapshot"}

    for unique_id, node in nodes_raw.items():
        if not isinstance(node, dict) or node.get("resource_type") not in allowed_resource_types:
            continue
        schema_name, table_name = _dbt_relation_parts(node)
        if not schema_name or not table_name:
            continue
        fqn = f"{schema_name}.{table_name}"
        node_id = unique_id
        unique_to_node_id[unique_id] = node_id
        fqn_to_node_ids.setdefault(fqn, set()).add(node_id)
        table_nodes[node_id] = {
            "id": node_id,
            "schema": schema_name,
            "table": table_name,
            "entity": f"dbt:{source}",
            "entities": [f"dbt:{source}"],
            "label": fqn,
            "table_id": None,
            "entity_id": None,
            "width": 220,
            "height": 64,
            "dbt_unique_id": unique_id,
            "dbt_resource_type": node.get("resource_type"),
            "dbt_model_name": node.get("name"),
            "dbt_original_file_path": node.get("original_file_path") or node.get("path"),
            "dbt_description": node.get("description") or "",
        }

    for unique_id, node in sources_raw.items():
        if not isinstance(node, dict):
            continue
        schema_name, table_name = _dbt_relation_parts(node)
        if not schema_name or not table_name:
            continue
        fqn = f"{schema_name}.{table_name}"
        node_id = unique_id
        unique_to_node_id[unique_id] = node_id
        fqn_to_node_ids.setdefault(fqn, set()).add(node_id)
        table_nodes[node_id] = {
            "id": node_id,
            "schema": schema_name,
            "table": table_name,
            "entity": f"dbt:{source}",
            "entities": [f"dbt:{source}"],
            "label": fqn,
            "table_id": None,
            "entity_id": None,
            "width": 220,
            "height": 64,
            "dbt_unique_id": unique_id,
            "dbt_resource_type": "source",
            "dbt_model_name": node.get("name"),
            "dbt_original_file_path": node.get("original_file_path") or node.get("path"),
            "dbt_description": node.get("description") or "",
        }

    seen_edges: set[tuple[str, str]] = set()
    combined_nodes = {}
    combined_nodes.update(nodes_raw)
    combined_nodes.update(sources_raw)
    for unique_id, node in combined_nodes.items():
        target_node_id = unique_to_node_id.get(unique_id)
        if not target_node_id:
            continue
        for dep_unique_id in ((node.get("depends_on") or {}).get("nodes") or []):
            source_node_id = unique_to_node_id.get(dep_unique_id)
            if not source_node_id:
                continue
            edge_key = (source_node_id, target_node_id)
            if edge_key in seen_edges:
                continue
            seen_edges.add(edge_key)
            edges.append({"source": source_node_id, "target": target_node_id})

    graph_payload = {
        "table_graph": {
            "nodes": table_nodes,
            "edges": edges,
        },
        "table_fqn_map": {k: sorted(v) for k, v in fqn_to_node_ids.items()},
        "table_entity_map": {node_id: set(node.get("entities") or []) for node_id, node in table_nodes.items()},
        "source": source,
        "manifest_path": str(path),
        "metadata": payload.get("metadata") or {},
    }
    _GRAPH_CACHE[graph_cache_key] = {"stamp": cache_stamp, "payload": graph_payload}
    return graph_payload


def get_dbt_manifest_model(
    *,
    base_dir: Path,
    manifest_dir: str,
    schema_name: str,
    table_name: str,
    source: str = "ohd",
) -> dict[str, Any] | None:
    payload = _load_manifest_index(base_dir, manifest_dir, source)
    key = f"{schema_name.strip().lower()}.{table_name.strip().lower()}"
    model = payload["index"].get(key)
    if not model:
        return None
    return {
        **model,
        "source": source,
        "manifest_path": str(payload["path"]),
        "metadata": payload["metadata"],
    }


def get_dbt_table_catalog(base_dir: Path, manifest_dir: str, source: str = "ohd") -> list[dict[str, Any]]:
    payload = _load_manifest_index(base_dir, manifest_dir, source)
    rows = []
    seen = set()
    for fqn, model in (payload.get("index") or {}).items():
        if fqn in seen:
            continue
        seen.add(fqn)
        rows.append(
            {
                "fqn": fqn,
                "schema": model.get("schema"),
                "table": model.get("table_name"),
                "label": f"{fqn} [dbt:{source}]",
                "source": source,
                "description": model.get("description") or "",
                "tags": model.get("tags") or [],
                "entity_name": f"dbt:{source}",
            }
        )
    rows.sort(key=lambda item: item["fqn"])
    return rows


def build_dbt_fallback_card(
    *,
    base_dir: Path,
    manifest_dir: str,
    schema_name: str,
    table_name: str,
    source: str = "ohd",
) -> dict[str, Any] | None:
    model = get_dbt_manifest_model(
        base_dir=base_dir,
        manifest_dir=manifest_dir,
        schema_name=schema_name,
        table_name=table_name,
        source=source,
    )
    if not model:
        return None
    return {
        "table_schema": model.get("schema") or schema_name,
        "table_name": model.get("table_name") or table_name,
        "entity_name": "dbt manifest",
        "table_id": None,
        "table_load_mode": f"dbt:{source}",
        "avg_duration_minutes": None,
        "last_success_time": None,
        "table_size_mb": None,
        "key_attributes": [],
        "dbt_manifest": model,
    }
