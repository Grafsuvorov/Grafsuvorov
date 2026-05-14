from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Optional

import yaml

from sqlalchemy import text

from ..config import TABLE_ENTITIES_META
from .dev_meta import (
    _audit_dev_meta,
    _ensure_meta_permissions,
    _resolve_root,
    acquire_dev_meta_lock,
    assert_dev_meta_lock_owner,
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
IGNORE_SCHEMAS = {"information_schema", "pg_catalog"}
EXTRA_SCHEMAS = {"raw_ext", "dict_raw_ext", "dq"}


def _normalize_name(value: str) -> str:
    return str(value or "").strip().strip('"').lower()


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
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=float("inf"),
    )


def _build_default_yaml(entity_name: str, schema_name: str, table_name: str) -> dict[str, Any]:
    schema_norm = _normalize_name(schema_name)
    return {
        "entity_name": entity_name,
        "table_schema": schema_norm,
        "table_name": table_name,
        "object_type": "view" if schema_norm.endswith("_view") else "table",
        "table_load_mode": "full_reload",
        "sql_query_recreate_init": f"etl_loads_entity/{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['recreate_sql']}",
        "sql_query_insert_init": f"etl_loads_entity/{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['insert_sql']}",
        "sql_query_truncate": f"etl_loads_entity/{entity_name}/{schema_name}/{table_name}/{SQL_FILE_NAMES['truncate_sql']}",
        "depends_on": {},
    }


def _extract_created_object(sql: str) -> tuple[str, str] | None:
    normalized = _normalize_sql(sql)
    match = re.search(
        r"\bcreate\s+(?:or\s+replace\s+)?(?:materialized\s+)?(view|table)\s+(?:if\s+not\s+exists\s+)?([a-z0-9_\".]+)",
        normalized,
    )
    if not match:
        return None
    return match.group(1), match.group(2).replace('"', "").lower()


def _extract_schema_table_refs(sql: str, known_schemas: set[str]) -> set[tuple[str, str]]:
    refs: set[tuple[str, str]] = set()
    pattern = re.compile(
        r"\b(?:from|join)\s+(\"?[A-Za-z_][\w]*\"?)\s*\.\s*(\"[^\"]+\"|[A-Za-z_][\w]*)",
        re.IGNORECASE,
    )
    for match in pattern.finditer(_strip_sql_comments(sql)):
        schema_name = _normalize_name(match.group(1))
        table_name = _normalize_name(match.group(2))
        if not schema_name or not table_name or schema_name in IGNORE_SCHEMAS:
            continue
        if known_schemas and schema_name not in known_schemas:
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
        if schema_name == target_schema and table_name == target_table:
            continue
        grouped.setdefault(schema_name, set()).add(table_name)
    return {schema_name: sorted(table_names) for schema_name, table_names in sorted(grouped.items())}


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
    return {
        "entity_name": entity_name,
        "schema_name": schema_name,
        "table_name": table_name,
        "object_key": _build_object_key(entity_name, schema_name, table_name),
        "yaml_content": _read_text_if_exists(yaml_path),
        "recreate_sql": _read_text_if_exists(object_dir / SQL_FILE_NAMES["recreate_sql"]),
        "insert_sql": _read_text_if_exists(object_dir / SQL_FILE_NAMES["insert_sql"]),
        "truncate_sql": _read_text_if_exists(object_dir / SQL_FILE_NAMES["truncate_sql"]),
        "path": str(object_dir),
    }


def init_entity_dev_meta_bundle(
    *,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
) -> dict[str, Any]:
    try:
        bundle = read_entity_dev_meta_bundle(
            base_dir=base_dir,
            root_value=dev_root_value,
            entity_name=entity_name,
            schema_name=schema_name,
            table_name=table_name,
        )
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
        bundle["source"] = "prod"
        bundle["exists"] = True
        return bundle
    except FileNotFoundError:
        pass

    yaml_payload = _build_default_yaml(entity_name, schema_name, table_name)
    return {
        "entity_name": entity_name,
        "schema_name": schema_name,
        "table_name": table_name,
        "object_key": _build_object_key(entity_name, schema_name, table_name),
        "yaml_content": _dump_yaml(yaml_payload),
        "recreate_sql": "",
        "insert_sql": "",
        "truncate_sql": "",
        "source": "new",
        "exists": False,
        "path": str(_resolve_object_dir(_resolve_root(base_dir, dev_root_value), entity_name, schema_name, table_name)),
    }


def validate_entity_dev_meta_bundle(
    *,
    base_dir: Path,
    prod_root_value: str,
    dev_root_value: str,
    entity_name: str,
    schema_name: str,
    table_name: str,
    yaml_content: str,
    recreate_sql: str,
    insert_sql: str,
    truncate_sql: str,
) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    normalized_schema = _normalize_name(schema_name)
    normalized_table = _normalize_name(table_name)

    try:
        payload = yaml.safe_load(yaml_content) or {}
    except Exception as exc:
        return {"valid": False, "errors": [f"YAML не распарсился: {exc}"], "warnings": [], "normalized": None}

    if not isinstance(payload, dict):
        return {"valid": False, "errors": ["Корневой YAML должен быть объектом"], "warnings": [], "normalized": None}

    for field in REQUIRED_YAML_FIELDS:
        if not payload.get(field):
            errors.append(f"Не заполнено обязательное поле `{field}`")

    if _normalize_name(payload.get("entity_name")) != _normalize_name(entity_name):
        errors.append("`entity_name` в YAML не совпадает с выбранной сущностью")
    if _normalize_name(payload.get("table_schema")) != normalized_schema:
        errors.append("`table_schema` в YAML не совпадает с выбранной схемой")
    if _normalize_name(payload.get("table_name")) != normalized_table:
        errors.append("`table_name` в YAML не совпадает с выбранной таблицей")

    object_type = _normalize_name(payload.get("object_type"))
    if object_type not in {"table", "view"}:
        errors.append("`object_type` должен быть `table` или `view`")

    expected_prefix = f"etl_loads_entity/{entity_name}/{schema_name}/{table_name}/"
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
    else:
        created = _extract_created_object(recreate_sql)
        expected_fqn = f"{normalized_schema}.{normalized_table}"
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

    if object_type != "view" and not truncate_sql.strip():
        warnings.append("Truncate SQL пустой. Если это допустимо, проверьте руками")

    for field_name in SYSTEM_FIELDS:
        if not re.search(rf"\b{re.escape(field_name)}\b", _normalize_sql(recreate_sql)):
            errors.append(f"В recreate SQL отсутствует системное поле `{field_name}`")

    known_schemas = _collect_known_schemas(_resolve_root(base_dir, prod_root_value)) | _collect_known_schemas(_resolve_root(base_dir, dev_root_value))
    if insert_sql.strip():
        expected_depends_on = _build_depends_on(insert_sql, normalized_schema, normalized_table, known_schemas)
        current_depends_on = _flatten_depends_on(payload.get("depends_on"))
        expected_depends_on_flat = _flatten_depends_on(expected_depends_on)
        missing = sorted(expected_depends_on_flat - current_depends_on)
        if missing:
            errors.append(
                "В `depends_on` не хватает зависимостей из insert SQL: "
                + ", ".join(f"{schema_part}.{table_part}" for schema_part, table_part in missing)
            )
        extra = sorted(current_depends_on - expected_depends_on_flat)
        if extra:
            warnings.append(
                "В `depends_on` есть лишние записи относительно insert SQL: "
                + ", ".join(f"{schema_part}.{table_part}" for schema_part, table_part in extra)
            )

    normalized_payload = dict(payload)
    if insert_sql.strip():
        normalized_payload["depends_on"] = _build_depends_on(insert_sql, normalized_schema, normalized_table, known_schemas)

    return {
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "normalized": {
            "yaml_content": _dump_yaml(normalized_payload),
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
    yaml_content: str,
    recreate_sql: str,
    insert_sql: str,
    truncate_sql: str,
    author: str,
) -> dict[str, Any]:
    task_id_norm = str(task_id or "").strip().upper()
    if not re.fullmatch(r"DWH-\d+", task_id_norm):
        raise ValueError("Номер задачи должен быть в формате DWH-12345")
    object_key = _build_object_key(entity_name, schema_name, table_name)
    assert_dev_meta_lock_owner(
        engine=engine,
        schema_name=ENTITY_LOCK_SCHEMA,
        file_name=object_key,
        author=author,
    )
    validation = validate_entity_dev_meta_bundle(
        base_dir=base_dir,
        prod_root_value=prod_root_value,
        dev_root_value=dev_root_value,
        entity_name=entity_name,
        schema_name=schema_name,
        table_name=table_name,
        yaml_content=yaml_content,
        recreate_sql=recreate_sql,
        insert_sql=insert_sql,
        truncate_sql=truncate_sql,
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
            "branch_name": f"{task_id_norm}/{_normalize_name(entity_name)}/{_normalize_name(schema_name)}/{_normalize_name(table_name)}",
            "warnings": [*validation["warnings"], *warnings],
        },
    )

    return {
        "path": str(object_dir),
        "object_key": object_key,
        "task_id": task_id_norm,
        "branch_name": f"{task_id_norm}/{_normalize_name(entity_name)}/{_normalize_name(schema_name)}/{_normalize_name(table_name)}",
        "validation": {
            **validation,
            "warnings": [*validation["warnings"], *warnings],
        },
    }


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
