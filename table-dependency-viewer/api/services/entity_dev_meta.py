from __future__ import annotations

import json
import os
import re
import shutil
import ssl
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Optional
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

import yaml

from sqlalchemy import create_engine, text

from ..config import TABLE_ENTITIES_META
from .dev_meta import (
    _audit_dev_meta,
    _ensure_meta_permissions,
    _resolve_root,
    acquire_dev_meta_lock,
    assert_dev_meta_lock_owner,
    ensure_dev_meta_tables,
    get_dev_meta_status,
    release_dev_meta_lock,
)


ENTITY_LOCK_SCHEMA = "entity_meta"
REQUIRED_YAML_FIELDS = ("table_name", "table_schema", "entity_name", "object_type", "table_load_mode")
SQL_FILE_NAMES = {
    "yaml": "meta_data_file.yaml",
    "recreate_sql": "sql_query_recreate_init.sql",
    "insert_sql": "sql_query_insert_init.sql",
    "truncate_sql": "sql_query_truncate.sql",
}
SYSTEM_FIELDS = ("dttm_inserted", "dttm_updated", "deleted_flag")
IGNORE_SCHEMAS = {"information_schema", "pg_catalog", "pg_temp"}
EXTRA_SCHEMAS = {"raw_ext", "dict_raw_ext", "dq"}
TABLE_ID_MAX_NORMAL = 100000
DEFAULT_INTERVAL = {"days": 1, "hours": 0, "minutes": 0, "seconds": 0}
SAFE_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
MAX_REPLICA_ENTITIES = 4


class _IndentedSafeDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


def _normalize_name(value: str) -> str:
    return str(value or "").strip().strip('"').lower()


def _normalize_path_segment(value: str) -> str:
    return re.sub(r"[^a-z0-9_]+", "", _normalize_name(value))


def _is_equivalent_object_name(left: str, right: str) -> bool:
    left_norm = _normalize_name(left)
    right_norm = _normalize_name(right)
    if left_norm == right_norm:
        return True
    left_path = _normalize_path_segment(left)
    right_path = _normalize_path_segment(right)
    return bool(left_path and right_path and left_path == right_path)


def _normalize_sql_identifier(raw: str) -> str:
    value = str(raw or "").strip()
    if value.startswith('"') and value.endswith('"') and len(value) >= 2:
        return value[1:-1]
    return value.strip('"').lower()


def _is_safe_identifier(value: str) -> bool:
    return bool(SAFE_IDENTIFIER_RE.fullmatch(str(value or "").strip()))


def _quote_ident(value: str) -> str:
    raw = str(value or "")
    return '"' + raw.replace('"', '""') + '"'


def _strip_sql_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    sql = re.sub(r"(?m)--.*?$", " ", sql)
    return sql


def _normalize_sql(sql: str) -> str:
    return re.sub(r"\s+", " ", _strip_sql_comments(sql)).strip().lower()


def _find_child_case_insensitive(parent: Path, name: str) -> Optional[Path]:
    if not parent.exists():
        return None
    for child in parent.iterdir():
        if child.name.lower() == name.lower():
            return child
    return None


def _iter_entity_dirs(root: Path) -> Iterable[Path]:
    if not root.exists():
        return []
    return [path for path in root.iterdir() if path.is_dir()]


def _resolve_object_dir(root: Path, entity_name: str, schema_name: str, table_name: str) -> Path:
    entity_dir = _find_child_case_insensitive(root, entity_name) or (root / entity_name)
    schema_dir = _find_child_case_insensitive(entity_dir, schema_name) or (entity_dir / schema_name)
    table_dir = _find_child_case_insensitive(schema_dir, table_name) or (schema_dir / table_name)
    return table_dir


def _build_object_key(entity_name: str, schema_name: str, table_name: str) -> str:
    return f"{entity_name}/{schema_name}/{table_name}"


def _read_text_if_exists(path: Path) -> str:
    if not path.exists() or not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def _dump_yaml(data: dict[str, Any]) -> str:
    return yaml.dump(
        data,
        Dumper=_IndentedSafeDumper,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=float("inf"),
        indent=2,
    )


def _normalize_key_attributes(items: Optional[list[str]]) -> Optional[list[str]]:
    if items is None:
        return None
    normalized = [str(item).strip() for item in items if str(item).strip()]
    return normalized or []


def _normalize_entity_names(items: Optional[list[str]], primary_entity_name: str) -> list[str]:
    if not items:
        return []
    primary = _normalize_name(primary_entity_name)
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        value = str(item or "").strip()
        if not value:
            continue
        norm = _normalize_name(value)
        if not norm or norm == primary or norm in seen:
            continue
        seen.add(norm)
        result.append(value)
    return result


def _ensure_default_verification(payload: dict[str, Any], key_attributes: Optional[list[str]]) -> None:
    verification = payload.get("verification")
    if not isinstance(verification, list):
        verification = []
    verification = [
        item
        for item in verification
        if str(item or "").strip() and _normalize_name(str(item or "")) != "duplicate_check"
    ]
    if verification:
        payload["verification"] = verification
        return
    payload.pop("verification", None)


def _normalize_yaml_payload_fields(
    *,
    payload: dict[str, Any],
    entity_name: str,
    schema_name: str,
    table_name: str,
    insert_sql: str,
    key_attributes: Optional[list[str]],
    prod_root: Path,
    dev_root: Path,
) -> tuple[dict[str, Any], list[str]]:
    normalized_payload = dict(payload) if isinstance(payload, dict) else {}
    normalized_keys = _normalize_key_attributes(key_attributes)
    effective_keys = normalized_keys
    if effective_keys is None:
        raw_keys = normalized_payload.get("key_attributes")
        effective_keys = _normalize_key_attributes(raw_keys if isinstance(raw_keys, list) else [])

    if effective_keys:
        normalized_payload["key_attributes"] = effective_keys
    else:
        normalized_payload.pop("key_attributes", None)

    known_schemas = _collect_known_schemas(prod_root) | _collect_known_schemas(dev_root)
    normalized_payload["depends_on"] = (
        _build_depends_on(insert_sql, _normalize_name(schema_name), _normalize_name(table_name), known_schemas)
        if str(insert_sql or "").strip()
        else {}
    )
    _ensure_default_verification(normalized_payload, effective_keys)
    return normalized_payload, effective_keys or []


def _build_default_yaml(entity_name: str, schema_name: str, table_name: str) -> dict[str, Any]:
    schema_norm = _normalize_name(schema_name)
    return {
        "table_name": table_name,
        "table_schema": schema_norm,
        "table_id": None,
        "source_id": None,
        "source_type": "GREENPLUM",
        "flag_has_views": schema_norm.endswith("_view"),
        "table_load_mode": "TRUNCATE_INIT",
        "job_id": None,
        "job_name": None,
        "table_loading_index": 1,
        "entity_id": None,
        "entity_name": entity_name,
        "object_type": "VIEW" if schema_norm.endswith("_view") else "TABLE",
        "table_load_interval": dict(DEFAULT_INTERVAL),
        "flag_waiting_dag_finished": False,
        "start_date": None,
        "sql_query_recreate_init": (
            f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
            f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['recreate_sql']}"
        ),
        "sql_query_insert_init": (
            f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
            f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['insert_sql']}"
        ),
        "sql_query_truncate": (
            f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
            f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['truncate_sql']}"
        ),
        "depends_on": {},
        "verification": [],
        "key_attributes": [],
    }


def _iter_yaml_paths(root: Path) -> Iterable[Path]:
    if not root.exists():
        return []
    return root.rglob("meta_data_file.yaml")


def _load_yaml_file(path: Path) -> dict[str, Any]:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        return {}


def _load_yaml_text(yaml_content: str) -> dict[str, Any]:
    try:
        return yaml.safe_load(yaml_content) or {}
    except Exception:
        return {}


def execute_entity_dev_meta_sql(
    *,
    engine,
    entity_name: str,
    schema_name: str,
    table_name: str,
    sql_kind: str,
    sql_text: str,
    dev_database_url: str,
    author: str,
) -> dict[str, Any]:
    sql_kind_norm = str(sql_kind or "").strip().lower()
    if sql_kind_norm not in {"recreate", "insert", "truncate"}:
        raise ValueError("sql_kind должен быть одним из: recreate, insert, truncate")
    sql_value = str(sql_text or "").strip()
    if not sql_value:
        raise ValueError("SQL текст пустой")
    if not dev_database_url:
        raise ValueError("Не настроен DEV_DATABASE_URL")

    exec_engine = create_engine(dev_database_url)
    connection = None
    cursor = None
    try:
        connection = exec_engine.raw_connection()
        cursor = connection.cursor()
        cursor.execute(sql_value)
        connection.commit()
    except Exception as exc:
        if connection is not None:
            try:
                connection.rollback()
            except Exception:
                pass
        raise ValueError(f"Не удалось выполнить {sql_kind_norm} SQL в DEV: {exc}") from exc
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                pass
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass
        exec_engine.dispose()

    object_key = _build_object_key(entity_name, schema_name, table_name)
    _audit_dev_meta(
        engine,
        ENTITY_LOCK_SCHEMA,
        object_key,
        author,
        f"run_{sql_kind_norm}",
        sql_value,
        {
            "entity_name": entity_name,
            "schema_name": schema_name,
            "table_name": table_name,
            "sql_kind": sql_kind_norm,
        },
    )
    return {
        "status": "ok",
        "object_key": object_key,
        "sql_kind": sql_kind_norm,
        "executed_at": datetime.utcnow().isoformat(),
        "message": f"{sql_kind_norm.upper()} SQL выполнен в DEV",
    }


def _find_template_payload(root: Path, entity_name: str, schema_name: str) -> Optional[dict[str, Any]]:
    entity_dir = _find_child_case_insensitive(root, entity_name)
    if not entity_dir:
        return None
    schema_dir = _find_child_case_insensitive(entity_dir, schema_name)
    if not schema_dir or not schema_dir.exists():
        return None

    candidates: list[tuple[Path, dict[str, Any]]] = []
    for yaml_path in schema_dir.rglob("meta_data_file.yaml"):
        payload = _load_yaml_file(yaml_path)
        if isinstance(payload, dict) and payload:
            candidates.append((yaml_path, payload))
    if not candidates:
        return None

    candidates.sort(key=lambda item: str(item[0]).lower())
    return dict(candidates[0][1])


def _collect_used_table_ids(*roots: Path) -> set[int]:
    used_ids: set[int] = set()
    for root in roots:
        for yaml_path in _iter_yaml_paths(root):
            payload = _load_yaml_file(yaml_path)
            raw_value = payload.get("table_id")
            try:
                value = int(raw_value)
            except Exception:
                continue
            if value > 0:
                used_ids.add(value)
    return used_ids


def _find_table_id_conflicts(
    *,
    current_object_key: str,
    table_id: Any,
    roots: Iterable[Path],
    ignored_object_keys: Optional[Iterable[str]] = None,
) -> list[str]:
    try:
        target_id = int(table_id)
    except Exception:
        return []
    if target_id <= 0:
        return []

    conflicts: list[str] = []
    current_key_norm = str(current_object_key or "").strip().lower()
    ignored = {
        str(item or "").strip().lower()
        for item in (ignored_object_keys or [])
        if str(item or "").strip()
    }
    ignored.add(current_key_norm)
    for root in roots:
        for yaml_path in _iter_yaml_paths(root):
            payload = _load_yaml_file(yaml_path)
            try:
                existing_id = int(payload.get("table_id"))
            except Exception:
                continue
            if existing_id != target_id:
                continue
            rel = yaml_path.relative_to(root)
            if len(rel.parts) < 4:
                continue
            object_key = _build_object_key(rel.parts[0], rel.parts[1], rel.parts[2])
            if object_key.lower() in ignored:
                continue
            conflicts.append(object_key)
    return sorted(set(conflicts), key=str.lower)


def _is_move_like_table_id_conflict(current_object_key: str, conflict_object_key: str) -> bool:
    current_parts = str(current_object_key or "").split("/")
    conflict_parts = str(conflict_object_key or "").split("/")
    if len(current_parts) != 3 or len(conflict_parts) != 3:
        return False
    return current_parts[1:] == conflict_parts[1:]


def _format_branch_name(value: Any) -> Optional[str]:
    branch_name = str(value or "").strip()
    if not branch_name:
        return None
    if re.fullmatch(r"DWH-\d+", branch_name, flags=re.IGNORECASE):
        return f"feature/{branch_name.upper()}"
    return branch_name


def _lookup_object_branch_contexts(engine, object_keys: Iterable[str]) -> dict[str, str]:
    keys = {
        str(item or "").strip()
        for item in object_keys
        if str(item or "").strip()
    }
    if not keys:
        return {}
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                """
                SELECT file_name, details
                FROM tech_etl.app_dev_meta_audit
                WHERE schema_name = :schema_name
                ORDER BY created_at DESC
                """
            ),
            {"schema_name": ENTITY_LOCK_SCHEMA},
        ).mappings().all()

    result: dict[str, str] = {}
    for row in rows:
        object_key = str(row.get("file_name") or "").strip()
        if object_key not in keys or object_key in result:
            continue
        try:
            details = json.loads(row.get("details") or "{}")
        except Exception:
            details = {}
        branch_name = (
            _format_branch_name(details.get("feature_branch"))
            or _format_branch_name(details.get("branch_name"))
            or _format_branch_name(details.get("task_id"))
        )
        if branch_name:
            result[object_key] = branch_name
    return result


def _next_table_id(*roots: Path) -> int:
    used_ids = _collect_used_table_ids(*roots)
    normal_ids = [value for value in used_ids if 0 < value <= TABLE_ID_MAX_NORMAL]
    if normal_ids:
        return max(normal_ids) + 1
    return 1


def _lookup_entity_id(engine, entity_name: str) -> Optional[int]:
    table_ref = TABLE_ENTITIES_META or "tech_etl.entities_meta"
    query = text(
        f"""
        SELECT entity_id
        FROM {table_ref}
        WHERE lower(trim(entity_name)) = lower(trim(:entity_name))
        ORDER BY entity_id
        LIMIT 1
        """
    )
    with engine.connect() as conn:
        value = conn.execute(query, {"entity_name": entity_name}).scalar()
    try:
        return int(value) if value is not None else None
    except Exception:
        return None


def _build_generated_yaml(
    *,
    engine,
    prod_root: Path,
    dev_root: Path,
    entity_name: str,
    schema_name: str,
    table_name: str,
) -> dict[str, Any]:
    schema_norm = _normalize_name(schema_name)
    table_norm = _normalize_name(table_name)
    template = (
        _find_template_payload(dev_root, entity_name, schema_name)
        or _find_template_payload(prod_root, entity_name, schema_name)
        or {}
    )

    payload = dict(template) if isinstance(template, dict) else {}
    if not payload:
        payload = _build_default_yaml(entity_name, schema_name, table_name)
    else:
        merged_default = _build_default_yaml(entity_name, schema_name, table_name)
        merged_default.update(payload)
        payload = merged_default

    payload["table_name"] = table_norm
    payload["table_schema"] = schema_norm
    payload["entity_name"] = entity_name
    payload["table_id"] = _next_table_id(prod_root, dev_root)

    entity_id = payload.get("entity_id")
    if entity_id in (None, "", 0, "0"):
        resolved_entity_id = _lookup_entity_id(engine, entity_name)
        if resolved_entity_id is not None:
            payload["entity_id"] = resolved_entity_id

    known_schemas = _collect_known_schemas(prod_root) | _collect_known_schemas(dev_root)
    insert_sql_path = _resolve_object_dir(dev_root, entity_name, schema_name, table_name) / SQL_FILE_NAMES["insert_sql"]
    if not insert_sql_path.exists():
        insert_sql_path = _resolve_object_dir(prod_root, entity_name, schema_name, table_name) / SQL_FILE_NAMES["insert_sql"]
    insert_sql = insert_sql_path.read_text(encoding="utf-8") if insert_sql_path.exists() else ""
    payload["depends_on"] = _build_depends_on(insert_sql, schema_norm, table_norm, known_schemas) if insert_sql.strip() else {}

    object_type = str(payload.get("object_type") or "").strip()
    if not object_type:
        payload["object_type"] = "VIEW" if schema_norm.endswith("_view") else "TABLE"
    else:
        payload["object_type"] = object_type.upper()

    if "table_load_mode" not in payload or not payload.get("table_load_mode"):
        payload["table_load_mode"] = "TRUNCATE_INIT"

    if schema_norm in {"stg", "dict_stg"}:
        payload["source_id"] = None

    interval = payload.get("table_load_interval")
    if not isinstance(interval, dict):
        payload["table_load_interval"] = dict(DEFAULT_INTERVAL)
    else:
        normalized_interval = dict(DEFAULT_INTERVAL)
        normalized_interval.update({key: interval.get(key) for key in DEFAULT_INTERVAL.keys() if key in interval})
        payload["table_load_interval"] = normalized_interval

    if not isinstance(payload.get("verification"), list):
        payload["verification"] = []
    payload["key_attributes"] = []

    payload["sql_query_recreate_init"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['recreate_sql']}"
    )
    payload["sql_query_insert_init"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['insert_sql']}"
    )
    payload["sql_query_truncate"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['truncate_sql']}"
    )
    return payload


def _extract_created_object(sql: str) -> tuple[str, str] | None:
    normalized = _normalize_sql(sql)
    match = re.search(
        r"\bcreate\s+(?:or\s+replace\s+)?(?:materialized\s+)?(view|table)\s+"
        r"(?:if\s+not\s+exists\s+)?"
        r"((?:\"[^\"]+\"|[a-z0-9_]+)\s*\.\s*(?:\"[^\"]+\"|[a-z0-9_./]+))",
        normalized,
    )
    if not match:
        return None
    return match.group(1), re.sub(r"\s+", "", match.group(2).replace('"', "").lower())


def _extract_insert_targets(sql: str) -> list[str]:
    normalized = _normalize_sql(sql)
    targets: list[str] = []
    for match in re.finditer(
        r"\binsert\s+into\s+((?:\"[^\"]+\"|[a-z0-9_]+)\s*\.\s*(?:\"[^\"]+\"|[a-z0-9_./]+))",
        normalized,
    ):
        targets.append(re.sub(r"\s+", "", match.group(1).replace('"', "").lower()))
    return targets


def _extract_mutation_targets(sql: str) -> list[tuple[str, str]]:
    normalized = _normalize_sql(sql)
    targets: list[tuple[str, str]] = []
    patterns = (
        (
            r"\btruncate\s+(?:table\s+)?((?:\"[^\"]+\"|[a-z0-9_]+)\s*\.\s*(?:\"[^\"]+\"|[a-z0-9_./]+))",
            "truncate",
        ),
        (
            r"\bdelete\s+from\s+((?:\"[^\"]+\"|[a-z0-9_]+)\s*\.\s*(?:\"[^\"]+\"|[a-z0-9_./]+))",
            "delete",
        ),
    )
    for pattern, kind in patterns:
        for match in re.finditer(pattern, normalized):
            target = re.sub(r"\s+", "", match.group(1).replace('"', "").lower())
            targets.append((kind, target))
    return targets


def _extract_cte_names(sql: str) -> set[str]:
    normalized = _normalize_sql(sql)
    result: set[str] = set()
    for match in re.finditer(r"\bwith\s+([a-z_][\w]*)\s+as\s*\(", normalized):
        result.add(match.group(1))
    for match in re.finditer(r",\s*([a-z_][\w]*)\s+as\s*\(", normalized):
        result.add(match.group(1))
    return result


def _extract_temp_table_names(sql: str) -> set[str]:
    normalized = _normalize_sql(sql)
    result: set[str] = set()
    for pattern in (
        r"\bcreate\s+temporary\s+table\s+([a-z_][\w]*)\b",
        r"\bcreate\s+temp\s+table\s+([a-z_][\w]*)\b",
        r"\bcreate\s+temporary\s+table\s+pg_temp\.([a-z_][\w]*)\b",
        r"\bcreate\s+temp\s+table\s+pg_temp\.([a-z_][\w]*)\b",
    ):
        for match in re.finditer(pattern, normalized):
            result.add(match.group(1))
    return result


def _extract_relation_aliases(sql: str) -> set[str]:
    normalized = _normalize_sql(sql)
    aliases: set[str] = set()
    pattern = re.compile(
        r"\b(?:from|join)\s+(?:\"?[A-Za-z_][\w]*\"?)\s*\.\s*(?:\"[^\"]+\"|[A-Za-z_][\w]*)"
        r"(?:\s+(?:as\s+)?)\s*([A-Za-z_][\w]*)\b",
        re.IGNORECASE,
    )
    for match in pattern.finditer(normalized):
        alias = _normalize_name(match.group(1))
        if alias:
            aliases.add(alias)
    return aliases


def _extract_all_schema_refs(sql: str) -> set[str]:
    schemas: set[str] = set()
    cte_names = _extract_cte_names(sql)
    relation_aliases = _extract_relation_aliases(sql)
    pattern = re.compile(
        r"\b(?:from|join|insert\s+into|truncate\s+table|delete\s+from)\s+(\"?[A-Za-z_][\w]*\"?)\s*\.",
        re.IGNORECASE,
    )
    for match in pattern.finditer(_strip_sql_comments(sql)):
        schema_name = _normalize_name(match.group(1))
        if (
            schema_name
            and schema_name not in cte_names
            and schema_name not in relation_aliases
            and len(schema_name) > 1
        ):
            schemas.add(schema_name)
    return schemas


def _extract_schema_table_refs(sql: str, known_schemas: set[str]) -> set[tuple[str, str]]:
    refs: set[tuple[str, str]] = set()
    pattern = re.compile(
        r"\b(?:from|join)\s+(\"?[A-Za-z_][\w]*\"?)\s*\.\s*(\"[^\"]+\"|[A-Za-z_][\w]*)",
        re.IGNORECASE,
    )
    for match in pattern.finditer(_strip_sql_comments(sql)):
        schema_name = _normalize_sql_identifier(match.group(1))
        table_name = _normalize_sql_identifier(match.group(2))
        schema_key = _normalize_name(schema_name)
        table_key = _normalize_name(table_name)
        if not schema_name or not table_name or schema_key in IGNORE_SCHEMAS:
            continue
        if known_schemas and schema_key not in known_schemas:
            continue
        refs.add((schema_name, table_name))
    return refs


def _collect_known_schemas(root: Path) -> set[str]:
    result = set(EXTRA_SCHEMAS)
    if not root.exists():
        return result
    for path in root.rglob("meta_data_file.yaml"):
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except Exception:
            continue
        schema_name = _normalize_name(str(data.get("table_schema") or ""))
        if schema_name:
            result.add(schema_name)
    return result


def _flatten_depends_on(depends_on: Any) -> set[tuple[str, str]]:
    result: set[tuple[str, str]] = set()
    if not isinstance(depends_on, dict):
        return result
    for schema_name, tables in depends_on.items():
        schema_norm = _normalize_name(schema_name)
        if not schema_norm or not isinstance(tables, list):
            continue
        for table_name in tables:
            table_norm = _normalize_name(table_name)
            if table_norm:
                result.add((schema_norm, table_norm))
    return result


def _build_depends_on(sql: str, target_schema: str, target_table: str, known_schemas: set[str]) -> dict[str, list[str]]:
    refs = _extract_schema_table_refs(sql, known_schemas)
    grouped: dict[str, set[str]] = {}
    for schema_name, table_name in refs:
        if _normalize_name(schema_name) == target_schema and _normalize_name(table_name) == target_table:
            continue
        grouped.setdefault(schema_name, set()).add(table_name)
    return {
        schema_name: sorted(table_names, key=lambda item: str(item).lower())
        for schema_name, table_names in sorted(grouped.items(), key=lambda item: str(item[0]).lower())
    }


def _apply_bundle_identity(
    *,
    yaml_content: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    path_entity_name: Optional[str] = None,
    entity_id: Optional[int] = None,
) -> str:
    payload = _load_yaml_text(yaml_content)
    if not isinstance(payload, dict):
        payload = _build_default_yaml(entity_name, schema_name, table_name)
    sql_owner_entity = path_entity_name or entity_name
    payload["entity_name"] = entity_name
    if entity_id is not None:
        payload["entity_id"] = entity_id
    payload["table_schema"] = _normalize_name(schema_name)
    payload["table_name"] = _normalize_name(table_name)
    payload["sql_query_recreate_init"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{sql_owner_entity}/{schema_name}/{table_name}/{SQL_FILE_NAMES['recreate_sql']}"
    )
    payload["sql_query_insert_init"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{sql_owner_entity}/{schema_name}/{table_name}/{SQL_FILE_NAMES['insert_sql']}"
    )
    payload["sql_query_truncate"] = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{sql_owner_entity}/{schema_name}/{table_name}/{SQL_FILE_NAMES['truncate_sql']}"
    )
    return _dump_yaml(payload)


def _dev_object_exists(dev_database_url: str, schema_name: str, table_name: str) -> tuple[bool, Optional[str]]:
    if not dev_database_url:
        return False, "Не настроен DEV_DATABASE_URL для проверки объекта в DEV"
    dev_engine = create_engine(dev_database_url)
    try:
        with dev_engine.connect() as conn:
            exists = conn.execute(
                text(
                    """
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = :schema_name
                      AND table_name = :table_name
                    LIMIT 1
                    """
                ),
                {"schema_name": schema_name, "table_name": table_name},
            ).scalar()
    except Exception as exc:
        return False, f"Не удалось проверить DEV Greenplum: {exc}"
    return bool(exists), None


def _dev_table_has_duplicates(
    dev_database_url: str,
    schema_name: str,
    table_name: str,
    key_attributes: list[str],
) -> tuple[Optional[bool], Optional[str]]:
    if not dev_database_url:
        return None, None
    if not key_attributes:
        return None, None

    dev_engine = create_engine(dev_database_url)
    group_by = ", ".join(_quote_ident(column) for column in key_attributes)
    duplicate_sql = text(
        f"""
        SELECT 1
        FROM {_quote_ident(schema_name)}.{_quote_ident(table_name)}
        GROUP BY {group_by}
        HAVING COUNT(*) > 1
        LIMIT 1
        """
    )
    try:
        with dev_engine.connect() as conn:
            exists = conn.execute(duplicate_sql).scalar()
    except Exception as exc:
        return None, f"Не удалось проверить дубли в DEV Greenplum: {exc}"
    return bool(exists), None


def _urlopen_without_proxy(req: urlrequest.Request, timeout: int, *, ssl_verify: bool = True):
    handlers: list[Any] = [urlrequest.ProxyHandler({})]
    if not ssl_verify:
        handlers.append(urlrequest.HTTPSHandler(context=ssl._create_unverified_context()))
    opener = urlrequest.build_opener(*handlers)
    return opener.open(req, timeout=timeout)


def _gitlab_json_request(
    *,
    api_url: str,
    project: str,
    token: str,
    ssl_verify: bool,
    path: str,
    method: str = "GET",
    payload: Optional[dict[str, Any]] = None,
    query: Optional[dict[str, Any]] = None,
    timeout: int = 30,
) -> Any:
    if not api_url:
        raise ValueError("Не настроен GITLAB_API_URL")
    project_ref = urlparse.quote(str(project or "").strip(), safe="")
    base_url = f"{api_url.rstrip('/')}/projects/{project_ref}/{path.lstrip('/')}"
    if query:
        query_text = urlparse.urlencode(
            {key: value for key, value in query.items() if value is not None},
            doseq=True,
        )
        url = f"{base_url}?{query_text}" if query_text else base_url
    else:
        url = base_url
    req = urlrequest.Request(
        url,
        data=json.dumps(payload).encode("utf-8") if payload is not None else None,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "PRIVATE-TOKEN": token,
        },
        method=method,
    )
    try:
        with _urlopen_without_proxy(req, timeout=timeout, ssl_verify=ssl_verify) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise ValueError(f"GitLab вернул {exc.code}: {body}") from exc
    except Exception as exc:
        raise ValueError(f"Не удалось вызвать GitLab API: {exc}") from exc


def _parse_gitlab_project(value: str) -> Optional[str]:
    text_value = str(value or "").strip()
    if not text_value:
        return None
    if text_value.isdigit():
        return text_value
    if "://" in text_value:
        parsed = urlparse.urlparse(text_value)
        path_value = parsed.path.lstrip("/").removesuffix(".git")
        return path_value or None
    if ":" in text_value and "@" in text_value.split(":", 1)[0]:
        _, path_value = text_value.split(":", 1)
        path_value = path_value.strip().lstrip("/").removesuffix(".git")
        return path_value or None
    return text_value.strip("/").removesuffix(".git") or None


def _git_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in (
        "http_proxy",
        "https_proxy",
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "all_proxy",
        "ALL_PROXY",
        "no_proxy",
        "NO_PROXY",
    ):
        env.pop(key, None)
    env["GIT_SSL_NO_VERIFY"] = "1"
    return env


def _run_git(repo_root: Path, args: list[str], *, cwd: Optional[Path] = None) -> str:
    git_cmd = [
        "git",
        "-c",
        "http.proxy=",
        "-c",
        "https.proxy=",
        "-c",
        "core.gitProxy=",
    ]
    try:
        result = subprocess.run(
            [*git_cmd, "-C", str(repo_root), *args] if cwd is None else [*git_cmd, *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            env=_git_env(),
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        details = "\n".join(
            part.strip()
            for part in (exc.stdout or "", exc.stderr or "")
            if str(part or "").strip()
        ).strip()
        joined_args = " ".join(args)
        raise ValueError(f"Git команда завершилась с ошибкой: git {joined_args}\n{details}".strip()) from exc
    return result.stdout.strip()


def _ensure_git_identity(*, repo_root: Path, cwd: Path, author: str) -> None:
    email = str(author or "").strip() or "table-dependency-viewer@local"
    name = email.split("@", 1)[0].replace(".", " ").replace("_", " ").strip().title() or "Table Dependency Viewer"
    _run_git(repo_root, ["config", "user.email", email], cwd=cwd)
    _run_git(repo_root, ["config", "user.name", name], cwd=cwd)


def _object_dir_from_key(root: Path, object_key: str) -> Path:
    parts = [part for part in str(object_key or "").split("/") if part]
    if len(parts) != 3:
        raise ValueError(f"Некорректный object_key: {object_key}")
    return _resolve_object_dir(root, parts[0], parts[1], parts[2])


def _ensure_entity_lock(*, engine, object_key: str, author: str, ttl_minutes: int) -> None:
    try:
        assert_dev_meta_lock_owner(
            engine=engine,
            schema_name=ENTITY_LOCK_SCHEMA,
            file_name=object_key,
            author=author,
        )
    except PermissionError as exc:
        if str(exc) != "Перед сохранением возьмите файл в работу":
            raise
        acquire_dev_meta_lock(
            engine=engine,
            schema_name=ENTITY_LOCK_SCHEMA,
            file_name=object_key,
            author=author,
            ttl_minutes=ttl_minutes,
        )


def get_entity_dev_meta_status(*, engine, base_dir: Path, prod_root_value: str, dev_root_value: str, lock_ttl_minutes: int) -> dict[str, Any]:
    return get_dev_meta_status(
        engine=engine,
        base_dir=base_dir,
        prod_root_value=prod_root_value,
        dev_root_value=dev_root_value,
        airflow_base_url="",
        airflow_dag_id="",
        lock_ttl_minutes=lock_ttl_minutes,
        dev_database_url="",
    )


def list_entity_dev_catalog(*, base_dir: Path, prod_root_value: str, dev_root_value: str) -> dict[str, Any]:
    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)

    entities: list[dict[str, Any]] = []
    entity_names = {path.name for path in _iter_entity_dirs(prod_root)} | {path.name for path in _iter_entity_dirs(dev_root)}
    for entity_name in sorted(entity_names, key=str.lower):
        prod_entity = _find_child_case_insensitive(prod_root, entity_name)
        dev_entity = _find_child_case_insensitive(dev_root, entity_name)
        schema_names: set[str] = set()
        for base in (prod_entity, dev_entity):
            if not base or not base.exists():
                continue
            schema_names |= {item.name for item in base.iterdir() if item.is_dir()}
        entities.append({"entity_name": entity_name, "schemas": sorted(schema_names, key=str.lower)})

    dev_files: list[dict[str, Any]] = []
    if dev_root.exists():
        for yaml_path in dev_root.rglob("meta_data_file.yaml"):
            rel = yaml_path.relative_to(dev_root)
            if len(rel.parts) < 4:
                continue
            entity_name, schema_name, table_name = rel.parts[0], rel.parts[1], rel.parts[2]
            stat = yaml_path.stat()
            dev_files.append(
                {
                    "entity_name": entity_name,
                    "schema_name": schema_name,
                    "table_name": table_name,
                    "object_key": _build_object_key(entity_name, schema_name, table_name),
                    "updated_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                }
            )

    return {
        "prod_root": str(prod_root),
        "dev_root": str(dev_root),
        "entities": entities,
        "dev_files": sorted(dev_files, key=lambda item: item["updated_at"], reverse=True),
    }


def list_entity_reference_rows(*, engine) -> list[dict[str, Any]]:
    table_ref = TABLE_ENTITIES_META or "tech_etl.entities_meta"
    query = text(
        f"""
        SELECT DISTINCT
            entity_id,
            entity_name
        FROM {table_ref}
        WHERE entity_id IS NOT NULL
          AND NULLIF(TRIM(entity_name), '') IS NOT NULL
        ORDER BY entity_name
        """
    )
    with engine.connect() as conn:
        rows = conn.execute(query).mappings().all()
    return [
        {
            "entity_id": row.get("entity_id"),
            "entity_name": str(row.get("entity_name") or "").strip(),
        }
        for row in rows
        if str(row.get("entity_name") or "").strip()
    ]


def read_entity_dev_meta_bundle(
    *,
    base_dir: Path,
    root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
) -> dict[str, Any]:
    root = _resolve_root(base_dir, root_value)
    object_dir = _resolve_object_dir(root, entity_name, schema_name, table_name)
    yaml_path = object_dir / SQL_FILE_NAMES["yaml"]
    if not yaml_path.exists():
        raise FileNotFoundError(str(yaml_path))
    yaml_content = _read_text_if_exists(yaml_path)
    insert_sql = _read_text_if_exists(object_dir / SQL_FILE_NAMES["insert_sql"])
    return {
        "entity_name": entity_name,
        "schema_name": schema_name,
        "table_name": table_name,
        "object_key": _build_object_key(entity_name, schema_name, table_name),
        "yaml_content": yaml_content,
        "key_attributes": (_load_yaml_text(yaml_content).get("key_attributes") if isinstance(_load_yaml_text(yaml_content).get("key_attributes"), list) else []),
        "recreate_sql": _read_text_if_exists(object_dir / SQL_FILE_NAMES["recreate_sql"]),
        "insert_sql": insert_sql,
        "truncate_sql": _read_text_if_exists(object_dir / SQL_FILE_NAMES["truncate_sql"]),
        "path": str(object_dir),
    }


def init_entity_dev_meta_bundle(
    *,
    engine,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    key_attributes: Optional[list[str]] = None,
) -> dict[str, Any]:
    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)
    try:
        bundle = read_entity_dev_meta_bundle(
            base_dir=base_dir,
            root_value=dev_root_value,
            entity_name=entity_name,
            schema_name=schema_name,
            table_name=table_name,
        )
        normalized_payload, normalized_keys = _normalize_yaml_payload_fields(
            payload=_load_yaml_text(bundle.get("yaml_content", "")),
            entity_name=entity_name,
            schema_name=schema_name,
            table_name=table_name,
            insert_sql=bundle.get("insert_sql", ""),
            key_attributes=key_attributes,
            prod_root=prod_root,
            dev_root=dev_root,
        )
        bundle["yaml_content"] = _dump_yaml(normalized_payload)
        bundle["key_attributes"] = normalized_keys
        bundle["source"] = "dev"
        bundle["exists"] = True
        return bundle
    except FileNotFoundError:
        pass

    try:
        bundle = read_entity_dev_meta_bundle(
            base_dir=base_dir,
            root_value=prod_root_value,
            entity_name=entity_name,
            schema_name=schema_name,
            table_name=table_name,
        )
        normalized_payload, normalized_keys = _normalize_yaml_payload_fields(
            payload=_load_yaml_text(bundle.get("yaml_content", "")),
            entity_name=entity_name,
            schema_name=schema_name,
            table_name=table_name,
            insert_sql=bundle.get("insert_sql", ""),
            key_attributes=key_attributes,
            prod_root=prod_root,
            dev_root=dev_root,
        )
        bundle["yaml_content"] = _dump_yaml(normalized_payload)
        bundle["key_attributes"] = normalized_keys
        bundle["source"] = "prod"
        bundle["exists"] = True
        return bundle
    except FileNotFoundError:
        pass

    yaml_payload = _build_generated_yaml(
        engine=engine,
        prod_root=prod_root,
        dev_root=dev_root,
        entity_name=entity_name,
        schema_name=schema_name,
        table_name=table_name,
    )
    normalized_keys = _normalize_key_attributes(key_attributes)
    if normalized_keys:
        yaml_payload["key_attributes"] = normalized_keys
    else:
        yaml_payload.pop("key_attributes", None)
    _ensure_default_verification(yaml_payload, normalized_keys)
    return {
        "entity_name": entity_name,
        "schema_name": schema_name,
        "table_name": table_name,
        "object_key": _build_object_key(entity_name, schema_name, table_name),
        "yaml_content": _dump_yaml(yaml_payload),
        "key_attributes": normalized_keys or [],
        "recreate_sql": "",
        "insert_sql": "",
        "truncate_sql": "",
        "source": "new",
        "exists": False,
        "path": str(_resolve_object_dir(dev_root, entity_name, schema_name, table_name)),
    }


def validate_entity_dev_meta_bundle(
    *,
    engine=None,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    key_attributes: Optional[list[str]],
    source_object_key: Optional[str],
    yaml_content: str,
    recreate_sql: str,
    insert_sql: str,
    truncate_sql: str,
    dev_database_url: str = "",
) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    checks: list[str] = []
    normalized_schema = _normalize_name(schema_name)
    normalized_table = _normalize_name(table_name)
    is_stg_schema = normalized_schema in {"stg", "dict_stg"}
    current_object_key = _build_object_key(entity_name, schema_name, table_name)
    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)

    try:
        payload = yaml.safe_load(yaml_content) or {}
    except Exception as exc:
        return {"valid": False, "errors": [f"YAML не распарсился: {exc}"], "warnings": [], "normalized": None}

    if not isinstance(payload, dict):
        return {"valid": False, "errors": ["Корневой YAML должен быть объектом"], "warnings": [], "normalized": None}

    normalized_keys = _normalize_key_attributes(key_attributes)
    if normalized_keys is not None:
        if normalized_keys:
            payload["key_attributes"] = normalized_keys
        else:
            payload.pop("key_attributes", None)
    payload, normalized_keys_effective = _normalize_yaml_payload_fields(
        payload=payload,
        entity_name=entity_name,
        schema_name=schema_name,
        table_name=table_name,
        insert_sql=insert_sql,
        key_attributes=normalized_keys,
        prod_root=prod_root,
        dev_root=dev_root,
    )

    for field in REQUIRED_YAML_FIELDS:
        if not payload.get(field):
            errors.append(f"Не заполнено обязательное поле `{field}`")

    if _normalize_name(payload.get("entity_name")) != _normalize_name(entity_name):
        errors.append("`entity_name` в YAML не совпадает с выбранной сущностью")
    if _normalize_name(payload.get("table_schema")) != normalized_schema:
        errors.append("`table_schema` в YAML не совпадает с выбранной схемой")
    payload_table_name = str(payload.get("table_name") or "").strip()
    if not _is_equivalent_object_name(payload_table_name, table_name):
        errors.append("`table_name` в YAML не совпадает с выбранной таблицей")
    effective_table_name = payload_table_name or table_name
    effective_normalized_table = _normalize_name(effective_table_name)

    table_id_value = payload.get("table_id")
    try:
        table_id_int = int(table_id_value)
        if table_id_int <= 0:
            raise ValueError()
    except Exception:
        errors.append("`table_id` должен быть положительным числом")
        table_id_int = None
    if table_id_int is not None:
        conflicts = _find_table_id_conflicts(
            current_object_key=current_object_key,
            table_id=table_id_int,
            roots=(prod_root, dev_root),
            ignored_object_keys=[source_object_key] if source_object_key else None,
        )
        conflicts = [item for item in conflicts if not _is_move_like_table_id_conflict(current_object_key, item)]
        if conflicts:
            branch_contexts = _lookup_object_branch_contexts(engine, conflicts) if engine is not None else {}
            errors.append(
                f"`table_id` {table_id_int} уже используется в других объектах: "
                + ", ".join(
                    f"`{item}`"
                    + (f" (ветка `{branch_contexts[item]}`)" if branch_contexts.get(item) else "")
                    for item in conflicts
                )
            )

    object_type = _normalize_name(payload.get("object_type"))
    if object_type not in {"table", "view"}:
        errors.append("`object_type` должен быть `table` или `view`")

    expected_prefix = (
        f"meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/"
        f"{entity_name}/{schema_name}/{table_name}/"
    )
    for field_name, file_name in (
        ("sql_query_recreate_init", SQL_FILE_NAMES["recreate_sql"]),
        ("sql_query_insert_init", SQL_FILE_NAMES["insert_sql"]),
        ("sql_query_truncate", SQL_FILE_NAMES["truncate_sql"]),
    ):
        value = str(payload.get(field_name) or "").strip().replace("\\", "/")
        if not value:
            if object_type == "view" and field_name in {"sql_query_insert_init", "sql_query_truncate"}:
                continue
            errors.append(f"Не заполнено `{field_name}`")
            continue
        expected_value = expected_prefix + file_name
        if value != expected_value:
            warnings.append(f"`{field_name}` отличается от стандартного пути: ожидается `{expected_value}`")

    if not recreate_sql.strip():
        errors.append("Recreate SQL не должен быть пустым")
    elif not is_stg_schema:
        created = _extract_created_object(recreate_sql)
        expected_fqn = f"{normalized_schema}.{effective_normalized_table}"
        if not created:
            warnings.append("В recreate SQL не найден `CREATE TABLE` или `CREATE VIEW`")
        else:
            actual_type, actual_fqn = created
            if actual_fqn != expected_fqn:
                errors.append(f"Recreate SQL создает `{actual_fqn}`, а ожидается `{expected_fqn}`")
            if object_type and actual_type != object_type:
                errors.append(f"Recreate SQL создает `{actual_type}`, а в YAML указан `{object_type}`")

    if object_type != "view" and not insert_sql.strip():
        errors.append("Insert SQL не должен быть пустым для table")
    elif insert_sql.strip():
        temp_table_names = _extract_temp_table_names(insert_sql)
        insert_targets = _extract_insert_targets(insert_sql)
        expected_fqn = f"{normalized_schema}.{effective_normalized_table}"
        if not is_stg_schema:
            if not insert_targets:
                errors.append("В insert SQL не найден `INSERT INTO schema.table`")
            elif expected_fqn not in insert_targets:
                meaningful_targets = [
                    target
                    for target in insert_targets
                    if not target.startswith("pg_temp.") and ("." in target or target not in temp_table_names)
                ]
                actual_target = (meaningful_targets or insert_targets)[-1]
                errors.append(f"Insert SQL пишет в `{actual_target}`, а ожидается `{expected_fqn}`")

        if re.search(r"\bselect\s+\*", _normalize_sql(insert_sql)):
            warnings.append("В insert SQL найден `SELECT *`")
        drop_matches = list(re.finditer(r"\bdrop\s+(table|view)\s+(?:if\s+exists\s+)?([a-z0-9_\".]+)", _normalize_sql(insert_sql)))
        risky_drop_targets: list[str] = []
        for match in drop_matches:
            drop_kind = match.group(1)
            drop_target = match.group(2).replace('"', "").lower()
            if drop_target.startswith("pg_temp."):
                continue
            if drop_kind == "table" and "." not in drop_target and drop_target in temp_table_names:
                continue
            risky_drop_targets.append(f"{drop_kind} {drop_target}")
        if risky_drop_targets:
            warnings.append(
                "В insert SQL найден `DROP TABLE/VIEW`; проверьте, что удаляются только временные объекты: "
                + ", ".join(f"`{item}`" for item in risky_drop_targets)
            )
        if re.search(r"\btruncate\s+table\b", _normalize_sql(insert_sql)):
            warnings.append("В insert SQL найден `TRUNCATE TABLE`; проверьте, что это действительно нужно")

        known_schemas = _collect_known_schemas(prod_root) | _collect_known_schemas(dev_root)
        unknown_schemas = sorted(
            schema_name
            for schema_name in _extract_all_schema_refs(insert_sql)
            if schema_name not in known_schemas
            and schema_name not in IGNORE_SCHEMAS
            and schema_name not in EXTRA_SCHEMAS
            and schema_name != normalized_schema
        )
        if unknown_schemas:
            errors.extend([f"Неизвестная схема в insert SQL: `{schema_name}`" for schema_name in unknown_schemas])

    if object_type != "view" and not truncate_sql.strip():
        warnings.append("Truncate SQL пустой. Если это допустимо, проверьте руками")
    elif truncate_sql.strip():
        normalized_truncate = _normalize_sql(truncate_sql)
        mutation_targets = _extract_mutation_targets(truncate_sql)
        expected_fqn = f"{normalized_schema}.{effective_normalized_table}"
        if normalized_truncate in {"select 1;", "select 1"}:
            pass
        elif not mutation_targets:
            warnings.append("В truncate SQL не найдены `TRUNCATE TABLE` или `DELETE FROM`")
        else:
            wrong_targets = [
                target
                for _kind, target in mutation_targets
                if not target.startswith("pg_temp.") and target != expected_fqn
            ]
            if wrong_targets:
                errors.append(
                    "Truncate SQL обращается не к целевой таблице: "
                    + ", ".join(f"`{target}`" for target in wrong_targets)
                )

    if not is_stg_schema:
        for field_name in SYSTEM_FIELDS:
            if not re.search(rf"\b{re.escape(field_name)}\b", _normalize_sql(recreate_sql)):
                errors.append(f"В recreate SQL отсутствует системное поле `{field_name}`")

    known_schemas = _collect_known_schemas(prod_root) | _collect_known_schemas(dev_root)
    if insert_sql.strip():
        expected_depends_on = _build_depends_on(insert_sql, normalized_schema, effective_normalized_table, known_schemas)
        current_depends_on = _flatten_depends_on(payload.get("depends_on"))
        expected_depends_on_flat = _flatten_depends_on(expected_depends_on)
        missing = sorted(expected_depends_on_flat - current_depends_on)
        extra = sorted(current_depends_on - expected_depends_on_flat)
        if missing:
            errors.append(
                "В `depends_on` не хватает зависимостей из insert SQL: "
                + ", ".join(f"{schema_part}.{table_part}" for schema_part, table_part in missing)
            )
        if extra:
            warnings.append(
                "В `depends_on` есть лишние записи относительно insert SQL: "
                + ", ".join(f"{schema_part}.{table_part}" for schema_part, table_part in extra)
            )

    normalized_payload, normalized_keys_effective = _normalize_yaml_payload_fields(
        payload=payload,
        entity_name=entity_name,
        schema_name=schema_name,
        table_name=table_name,
        insert_sql=insert_sql,
        key_attributes=normalized_keys,
        prod_root=prod_root,
        dev_root=dev_root,
    )

    dev_check_table_name = str(payload.get("table_name") or effective_table_name or "").strip()
    dev_exists, dev_error = _dev_object_exists(dev_database_url, str(payload.get("table_schema") or schema_name or "").strip(), dev_check_table_name)
    if dev_error:
        errors.append(dev_error)
    elif not dev_exists:
        errors.append(f"Объект `{normalized_schema}.{effective_normalized_table}` не найден в DEV Greenplum")
    else:
        checks.append(f"Объект `{normalized_schema}.{effective_normalized_table}` найден в DEV Greenplum")
        duplicate_status, duplicate_error = _dev_table_has_duplicates(
            dev_database_url,
            str(payload.get("table_schema") or schema_name or "").strip(),
            dev_check_table_name,
            normalized_keys or [],
        )
        if duplicate_error:
            warnings.append(duplicate_error)
        elif duplicate_status is True:
            warnings.append("В таблице имеются дубли, уточнить у аналитика")
        elif duplicate_status is False:
            checks.append("Дубли по key_attributes не найдены")

    return {
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "checks": checks,
        "normalized": {
            "yaml_content": _dump_yaml(normalized_payload),
            "key_attributes": normalized_keys_effective,
            "recreate_sql": recreate_sql,
            "insert_sql": insert_sql,
            "truncate_sql": truncate_sql,
        },
    }


def save_entity_dev_meta_bundle(
    *,
    engine,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    task_id: str,
    key_attributes: Optional[list[str]],
    source_object_key: Optional[str],
    replica_entity_names: Optional[list[str]],
    yaml_content: str,
    recreate_sql: str,
    insert_sql: str,
    truncate_sql: str,
    author: str,
    dev_database_url: str = "",
    lock_ttl_minutes: int = 30,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"DWH-\d+", task_id_norm):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")
    replica_entities = _normalize_entity_names(replica_entity_names, entity_name)
    if len(replica_entities) > MAX_REPLICA_ENTITIES:
        raise ValueError(f"Можно указать не больше {MAX_REPLICA_ENTITIES} дополнительных сущностей")
    object_key = _build_object_key(entity_name, schema_name, table_name)
    _ensure_entity_lock(engine=engine, object_key=object_key, author=author, ttl_minutes=lock_ttl_minutes)
    validation = validate_entity_dev_meta_bundle(
        engine=engine,
        base_dir=base_dir,
        prod_root_value=prod_root_value,
        dev_root_value=dev_root_value,
        entity_name=entity_name,
        schema_name=schema_name,
        table_name=table_name,
        key_attributes=key_attributes,
        source_object_key=source_object_key,
        yaml_content=yaml_content,
        recreate_sql=recreate_sql,
        insert_sql=insert_sql,
        truncate_sql=truncate_sql,
        dev_database_url=dev_database_url,
    )
    if not validation["valid"]:
        raise ValueError("; ".join(validation["errors"]))

    root = _resolve_root(base_dir, dev_root_value)
    object_dir = _resolve_object_dir(root, entity_name, schema_name, table_name)
    object_dir.mkdir(parents=True, exist_ok=True)

    normalized = validation["normalized"] or {}
    yaml_path = object_dir / SQL_FILE_NAMES["yaml"]
    recreate_path = object_dir / SQL_FILE_NAMES["recreate_sql"]
    insert_path = object_dir / SQL_FILE_NAMES["insert_sql"]
    truncate_path = object_dir / SQL_FILE_NAMES["truncate_sql"]
    yaml_path.write_text(normalized.get("yaml_content", yaml_content), encoding="utf-8")
    recreate_path.write_text(normalized.get("recreate_sql", recreate_sql), encoding="utf-8")
    insert_text = normalized.get("insert_sql", insert_sql)
    if insert_text.strip():
        insert_path.write_text(insert_text, encoding="utf-8")
    elif insert_path.exists():
        insert_path.unlink()
    truncate_text = normalized.get("truncate_sql", truncate_sql)
    if truncate_text.strip():
        truncate_path.write_text(truncate_text, encoding="utf-8")
    elif truncate_path.exists():
        truncate_path.unlink()

    warnings = []
    for file_path in (yaml_path, recreate_path):
        warnings.extend(_ensure_meta_permissions(file_path, root))
    if insert_text.strip():
        warnings.extend(_ensure_meta_permissions(insert_path, root))
    if truncate_text.strip():
        warnings.extend(_ensure_meta_permissions(truncate_path, root))

    replica_paths: list[str] = []
    for replica_entity_name in replica_entities:
        replica_entity_id = _lookup_entity_id(engine, replica_entity_name)
        if replica_entity_id is None:
            raise ValueError(f"Не удалось определить entity_id для сущности `{replica_entity_name}`")
        replica_dir = _resolve_object_dir(root, replica_entity_name, schema_name, table_name)
        replica_dir.mkdir(parents=True, exist_ok=True)
        replica_yaml = _apply_bundle_identity(
            yaml_content=normalized.get("yaml_content", yaml_content),
            entity_name=replica_entity_name,
            schema_name=schema_name,
            table_name=table_name,
            path_entity_name=entity_name,
            entity_id=replica_entity_id,
        )
        replica_yaml_path = replica_dir / SQL_FILE_NAMES["yaml"]
        replica_yaml_path.write_text(replica_yaml, encoding="utf-8")
        warnings.extend(_ensure_meta_permissions(replica_yaml_path, root))
        replica_paths.append(str(replica_dir))

    _audit_dev_meta(
        engine,
        ENTITY_LOCK_SCHEMA,
        object_key,
        author,
        "save",
        normalized.get("yaml_content", yaml_content),
        {
            "path": str(object_dir),
            "entity_name": entity_name,
            "schema_name": schema_name,
            "table_name": table_name,
            "task_id": task_id_norm,
            "branch_name": task_id_norm,
            "replica_entity_names": replica_entities,
            "replica_paths": replica_paths,
            "warnings": [*validation["warnings"], *warnings],
        },
    )

    return {
        "path": str(object_dir),
        "object_key": object_key,
        "task_id": task_id_norm,
        "branch_name": task_id_norm,
        "replica_paths": replica_paths,
        "validation": {
            **validation,
            "warnings": [*validation["warnings"], *warnings],
        },
    }


def delete_entity_dev_meta_bundle(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    task_id: str,
    author: str,
    lock_ttl_minutes: int = 30,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"DWH-\d+", task_id_norm):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")

    object_key = _build_object_key(entity_name, schema_name, table_name)
    _ensure_entity_lock(engine=engine, object_key=object_key, author=author, ttl_minutes=lock_ttl_minutes)

    root = _resolve_root(base_dir, dev_root_value)
    object_dir = _resolve_object_dir(root, entity_name, schema_name, table_name)
    if not object_dir.exists():
        raise ValueError("DEV объект не найден, удалять нечего")

    shutil.rmtree(object_dir)

    parent = object_dir.parent
    while parent != root and parent.exists():
        try:
            parent.rmdir()
        except OSError:
            break
        parent = parent.parent

    _audit_dev_meta(
        engine,
        ENTITY_LOCK_SCHEMA,
        object_key,
        author,
        "delete",
        "",
        {
            "path": str(object_dir),
            "entity_name": entity_name,
            "schema_name": schema_name,
            "table_name": table_name,
            "task_id": task_id_norm,
            "branch_name": task_id_norm,
        },
    )
    release_dev_meta_lock(
        engine=engine,
        schema_name=ENTITY_LOCK_SCHEMA,
        file_name=object_key,
        author=author,
    )
    return {
        "path": str(object_dir),
        "object_key": object_key,
        "task_id": task_id_norm,
        "branch_name": task_id_norm,
    }


def move_entity_dev_meta_bundle(
    *,
    engine,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    source_entity_name: str,
    source_schema_name: str,
    source_table_name: str,
    target_entity_name: str,
    target_schema_name: str,
    target_table_name: str,
    task_id: str,
    author: str,
    lock_ttl_minutes: int = 30,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"DWH-\d+", task_id_norm):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")

    source_key = _build_object_key(source_entity_name, source_schema_name, source_table_name)
    target_key = _build_object_key(target_entity_name, target_schema_name, target_table_name)
    _ensure_entity_lock(engine=engine, object_key=source_key, author=author, ttl_minutes=lock_ttl_minutes)

    prod_root = _resolve_root(base_dir, prod_root_value)
    dev_root = _resolve_root(base_dir, dev_root_value)
    source_dev_dir = _resolve_object_dir(dev_root, source_entity_name, source_schema_name, source_table_name)
    target_dev_dir = _resolve_object_dir(dev_root, target_entity_name, target_schema_name, target_table_name)
    target_prod_dir = _resolve_object_dir(prod_root, target_entity_name, target_schema_name, target_table_name)
    source_path_for_audit = str(source_dev_dir if source_dev_dir.exists() else _resolve_object_dir(prod_root, source_entity_name, source_schema_name, source_table_name))

    if target_dev_dir.exists() or target_prod_dir.exists():
        raise ValueError(f"Целевой объект `{target_key}` уже существует")

    if source_dev_dir.exists():
        bundle = read_entity_dev_meta_bundle(
            base_dir=base_dir,
            root_value=dev_root_value,
            entity_name=source_entity_name,
            schema_name=source_schema_name,
            table_name=source_table_name,
        )
    else:
        bundle = read_entity_dev_meta_bundle(
            base_dir=base_dir,
            root_value=prod_root_value,
            entity_name=source_entity_name,
            schema_name=source_schema_name,
            table_name=source_table_name,
        )

    target_dev_dir.mkdir(parents=True, exist_ok=True)
    normalized_yaml = _apply_bundle_identity(
        yaml_content=bundle.get("yaml_content", ""),
        entity_name=target_entity_name,
        schema_name=target_schema_name,
        table_name=target_table_name,
    )
    (target_dev_dir / SQL_FILE_NAMES["yaml"]).write_text(normalized_yaml, encoding="utf-8")
    (target_dev_dir / SQL_FILE_NAMES["recreate_sql"]).write_text(bundle.get("recreate_sql", ""), encoding="utf-8")

    insert_sql = bundle.get("insert_sql", "")
    truncate_sql = bundle.get("truncate_sql", "")
    if str(insert_sql).strip():
        (target_dev_dir / SQL_FILE_NAMES["insert_sql"]).write_text(insert_sql, encoding="utf-8")
    if str(truncate_sql).strip():
        (target_dev_dir / SQL_FILE_NAMES["truncate_sql"]).write_text(truncate_sql, encoding="utf-8")

    warnings = []
    for file_path in target_dev_dir.glob("*"):
        if file_path.is_file():
            warnings.extend(_ensure_meta_permissions(file_path, dev_root))

    if source_dev_dir.exists():
        shutil.rmtree(source_dev_dir)
        parent = source_dev_dir.parent
        while parent != dev_root and parent.exists():
            try:
                parent.rmdir()
            except OSError:
                break
            parent = parent.parent

    _audit_dev_meta(
        engine,
        ENTITY_LOCK_SCHEMA,
        source_key,
        author,
        "move",
        normalized_yaml,
        {
            "task_id": task_id_norm,
            "branch_name": task_id_norm,
            "source_path": source_path_for_audit,
            "target_path": str(target_dev_dir),
            "source_object_key": source_key,
            "target_object_key": target_key,
            "warnings": warnings,
        },
    )
    release_dev_meta_lock(
        engine=engine,
        schema_name=ENTITY_LOCK_SCHEMA,
        file_name=source_key,
        author=author,
    )
    moved_payload = _load_yaml_text(normalized_yaml)
    return {
        "path": str(target_dev_dir),
        "object_key": target_key,
        "source_object_key": source_key,
        "task_id": task_id_norm,
        "branch_name": task_id_norm,
        "warnings": warnings,
        "bundle": {
            "entity_name": target_entity_name,
            "schema_name": target_schema_name,
            "table_name": target_table_name,
            "object_key": target_key,
            "source_object_key": source_key,
            "yaml_content": normalized_yaml,
            "key_attributes": (moved_payload.get("key_attributes") if isinstance(moved_payload.get("key_attributes"), list) else []),
            "recreate_sql": bundle.get("recreate_sql", ""),
            "insert_sql": bundle.get("insert_sql", ""),
            "truncate_sql": bundle.get("truncate_sql", ""),
            "source": "dev",
            "exists": True,
            "path": str(target_dev_dir),
        },
    }


def _list_task_entity_object_keys(*, engine, task_id: str) -> set[str]:
    ensure_dev_meta_tables(engine)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                """
                SELECT file_name, action, details
                FROM tech_etl.app_dev_meta_audit
                WHERE schema_name = :schema_name
                ORDER BY created_at
                """
            ),
            {"schema_name": ENTITY_LOCK_SCHEMA},
        ).mappings().all()
    result: set[str] = set()
    for row in rows:
        try:
            details = json.loads(row.get("details") or "{}")
        except Exception:
            details = {}
        if str(details.get("task_id") or "").strip().upper() != task_id:
            continue
        file_name = str(row.get("file_name") or "").strip()
        action = str(row.get("action") or "").strip().lower()
        is_object_key = file_name.count("/") == 2
        if file_name and is_object_key:
            result.add(file_name)
        if action == "move":
            for extra_key in ("source_object_key", "target_object_key"):
                extra_value = str(details.get(extra_key) or "").strip()
                if extra_value and extra_value.count("/") == 2:
                    result.add(extra_value)
        if action == "save":
            entity_name = str(details.get("entity_name") or "").strip()
            schema_name = str(details.get("schema_name") or "").strip()
            table_name = str(details.get("table_name") or "").strip()
            for replica_entity_name in details.get("replica_entity_names") or []:
                if entity_name and schema_name and table_name and replica_entity_name:
                    result.add(_build_object_key(str(replica_entity_name).strip(), schema_name, table_name))
    return result


def _sync_task_objects_to_worktree(
    *,
    dev_root: Path,
    worktree_meta_root: Path,
    object_keys: set[str],
) -> dict[str, list[str]]:
    updated_paths: list[str] = []
    removed_paths: list[str] = []
    for object_key in sorted(object_keys):
        dev_object_dir = _object_dir_from_key(dev_root, object_key)
        repo_object_dir = _object_dir_from_key(worktree_meta_root, object_key)
        if dev_object_dir.exists():
            repo_object_dir.parent.mkdir(parents=True, exist_ok=True)
            if repo_object_dir.exists():
                shutil.rmtree(repo_object_dir)
            shutil.copytree(dev_object_dir, repo_object_dir)
            updated_paths.append(str(repo_object_dir))
        elif repo_object_dir.exists():
            shutil.rmtree(repo_object_dir)
            removed_paths.append(str(repo_object_dir))
            parent = repo_object_dir.parent
            while parent != worktree_meta_root and parent.exists():
                try:
                    parent.rmdir()
                except OSError:
                    break
                parent = parent.parent
    return {"updated_paths": updated_paths, "removed_paths": removed_paths}


def create_entity_meta_mr(
    *,
    engine,
    base_dir: Path,
    dev_root_value: str,
    git_repo_value: str,
    git_meta_root_value: str,
    gitlab_token: str,
    gitlab_project: str,
    gitlab_api_url: str,
    gitlab_ssl_verify: str,
    task_id: str,
    release_branch: str,
    author: str,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"DWH-\d+", task_id_norm):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")
    release_branch_norm = str(release_branch or "").strip() or "main"
    if not git_repo_value:
        raise ValueError("Не настроен ENTITY_META_GIT_REPO")
    if not gitlab_token:
        raise ValueError("Не настроен GITLAB_TOKEN")

    dev_root = _resolve_root(base_dir, dev_root_value)
    git_repo_root = Path(git_repo_value).resolve()
    worktree_meta_root_rel = Path(git_meta_root_value)
    ssl_verify = str(gitlab_ssl_verify or "true").strip().lower() not in {"0", "false", "no", "off"}
    project_ref = _parse_gitlab_project(gitlab_project) or _parse_gitlab_project(
        _run_git(git_repo_root, ["remote", "get-url", "origin"])
    )
    if not project_ref:
        raise ValueError("Не удалось определить GitLab project")

    object_keys = _list_task_entity_object_keys(engine=engine, task_id=task_id_norm)
    if not object_keys:
        raise ValueError(f"Не найдено объектов для задачи {task_id_norm}")

    feature_branch = f"feature/{task_id_norm}"
    _run_git(git_repo_root, ["fetch", "origin"])
    release_exists = _run_git(git_repo_root, ["ls-remote", "--heads", "origin", release_branch_norm])
    if not release_exists:
        raise ValueError(f"Release-ветка `{release_branch_norm}` не найдена в origin")

    worktree_dir = Path(tempfile.mkdtemp(prefix=f"entity-meta-{task_id_norm.lower()}-"))
    try:
        remote_feature_exists = bool(_run_git(git_repo_root, ["ls-remote", "--heads", "origin", feature_branch]))
        if remote_feature_exists:
            _run_git(git_repo_root, ["worktree", "add", "-B", feature_branch, str(worktree_dir), f"origin/{feature_branch}"])
        else:
            _run_git(git_repo_root, ["worktree", "add", "-B", feature_branch, str(worktree_dir), f"origin/{release_branch_norm}"])
        _ensure_git_identity(repo_root=git_repo_root, cwd=worktree_dir, author=author)

        worktree_meta_root = worktree_dir / worktree_meta_root_rel
        sync_result = _sync_task_objects_to_worktree(
            dev_root=dev_root,
            worktree_meta_root=worktree_meta_root,
            object_keys=object_keys,
        )

        status_output = _run_git(git_repo_root, ["status", "--porcelain"], cwd=worktree_dir)
        if status_output:
            _run_git(git_repo_root, ["add", "."], cwd=worktree_dir)
            commit_message = f"{task_id_norm}: update GP meta objects"
            _run_git(git_repo_root, ["commit", "-m", commit_message], cwd=worktree_dir)

        _run_git(git_repo_root, ["push", "origin", f"HEAD:{feature_branch}"], cwd=worktree_dir)

        title = f"{task_id_norm}: GP meta changes"
        description_lines = [
            f"Task: {task_id_norm}",
            f"Author: {author}",
            "",
            "Objects:",
            *[f"- {item}" for item in sorted(object_keys)],
        ]
        existing = _gitlab_json_request(
            api_url=gitlab_api_url,
            project=project_ref,
            token=gitlab_token,
            ssl_verify=ssl_verify,
            path="merge_requests",
            method="GET",
            query={
                "state": "opened",
                "source_branch": feature_branch,
                "target_branch": release_branch_norm,
            },
        )
        if existing:
            mr_data = existing[0]
        else:
            mr_data = _gitlab_json_request(
                api_url=gitlab_api_url,
                project=project_ref,
                token=gitlab_token,
                ssl_verify=ssl_verify,
                path="merge_requests",
                method="POST",
                payload={
                    "source_branch": feature_branch,
                    "target_branch": release_branch_norm,
                    "title": title,
                    "description": "\n".join(description_lines),
                    "remove_source_branch": False,
                },
            )

        _audit_dev_meta(
            engine,
            ENTITY_LOCK_SCHEMA,
            task_id_norm,
            author,
            "create_mr",
            "",
            {
                "task_id": task_id_norm,
                "feature_branch": feature_branch,
                "release_branch": release_branch_norm,
                "object_keys": sorted(object_keys),
                "updated_paths": sync_result["updated_paths"],
                "removed_paths": sync_result["removed_paths"],
                "mr_url": mr_data.get("web_url"),
            },
        )
        return {
            "task_id": task_id_norm,
            "feature_branch": feature_branch,
            "release_branch": release_branch_norm,
            "object_keys": sorted(object_keys),
            "updated_paths": sync_result["updated_paths"],
            "removed_paths": sync_result["removed_paths"],
            "mr_url": mr_data.get("web_url"),
            "mr_iid": mr_data.get("iid"),
        }
    finally:
        try:
            _run_git(git_repo_root, ["worktree", "remove", "--force", str(worktree_dir)])
        except Exception:
            pass
        shutil.rmtree(worktree_dir, ignore_errors=True)


def lock_entity_dev_meta(*, engine, entity_name: str, schema_name: str, table_name: str, author: str, ttl_minutes: int) -> dict[str, Any]:
    return acquire_dev_meta_lock(
        engine=engine,
        schema_name=ENTITY_LOCK_SCHEMA,
        file_name=_build_object_key(entity_name, schema_name, table_name),
        author=author,
        ttl_minutes=ttl_minutes,
    )


def unlock_entity_dev_meta(*, engine, entity_name: str, schema_name: str, table_name: str, author: str) -> None:
    release_dev_meta_lock(
        engine=engine,
        schema_name=ENTITY_LOCK_SCHEMA,
        file_name=_build_object_key(entity_name, schema_name, table_name),
        author=author,
    )
