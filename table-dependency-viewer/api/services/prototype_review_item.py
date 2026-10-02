"""Resolution of a single table in the prototype review workflow."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Optional

import yaml


@dataclass(frozen=True)
class PrototypeReviewItemDependencies:
    find_meta: Callable[[str], dict[str, Any] | None]
    find_meta_variants: Callable[[str], list[dict[str, Any]]]
    init_meta_bundle: Callable[..., dict[str, Any]]
    get_click_meta_index: Callable[[], dict[str, Any]]
    clean_table_name: Callable[[str], str | None]
    collect_target_sql: Callable[..., dict[str, Any]]
    validate_meta_bundle: Callable[..., dict[str, Any]]
    extract_dependencies: Callable[..., list[str]]
    apply_yaml_dependencies: Callable[[str, list[str]], str]
    impact_summary: Callable[[str], dict[str, Any]]
    query_table_checks: Callable[..., dict[str, Any]]
    existing_null_conditions: Callable[[str, str], list[str]]
    item_needs_attention: Callable[[dict[str, Any]], tuple[bool, list[str]]]
    engine: Any
    base_dir: Any
    entity_meta_dir: Any
    dev_entity_meta_dir: Any
    dev_database_url: str


def resolve_prototype_review_item(
    *,
    target_fqn: str,
    path_value: str = "",
    execution_row: Optional[dict[str, Any]] = None,
    known_schemas: Optional[set[str]] = None,
    file_item: Optional[dict[str, Any]] = None,
    related_files: Optional[list[dict[str, Any]]] = None,
    fallback_entity_name: str = "",
    key_attributes_override: Optional[list[str]] = None,
    object_type_hint: str = "",
    reserved_table_ids: Optional[set[int]] = None,
    resolver: PrototypeReviewItemDependencies,
) -> dict[str, Any]:
    meta = resolver.find_meta(target_fqn)
    meta_variants = resolver.find_meta_variants(target_fqn)
    schema_name, table_name = target_fqn.split(".", 1)
    yaml_bundle = None
    yaml_key_attributes: list[str] = []
    yaml_entity_name = None
    entity_name_seed = (
        str((meta or {}).get("entity_name") or "").strip()
        or str(fallback_entity_name or "").strip()
    )
    try:
        yaml_bundle = resolver.init_meta_bundle(
            engine=resolver.engine,
            base_dir=resolver.base_dir,
            prod_root_value=resolver.entity_meta_dir,
            dev_root_value=resolver.dev_entity_meta_dir,
            entity_name=entity_name_seed,
            schema_name=schema_name,
            table_name=table_name,
            key_attributes=list(key_attributes_override or []) or None,
            reserved_table_ids=reserved_table_ids,
            prod_only=True,
        )
    except Exception:
        yaml_bundle = None
    if yaml_bundle:
        yaml_key_attributes = list(yaml_bundle.get("key_attributes") or [])
        yaml_entity_name = str(yaml_bundle.get("entity_name") or "").strip() or None
    detected_keys = list(key_attributes_override or []) or yaml_key_attributes
    entity_names = []
    entity_names_seen = set()
    for variant in meta_variants:
        value = str((variant or {}).get("entity_name") or "").strip()
        if not value:
            continue
        key = value.lower()
        if key in entity_names_seen:
            continue
        entity_names_seen.add(key)
        entity_names.append(value)
    entity_name = (
        str(fallback_entity_name or "").strip()
        or yaml_entity_name
        or str((meta or {}).get("entity_name") or "").strip()
        or None
    )
    click_idx = resolver.get_click_meta_index()
    click_meta = (click_idx.get("meta") or {}).get((schema_name.lower(), table_name.lower())) or (click_idx.get("meta") or {}).get((schema_name.lower(), resolver.clean_table_name(table_name.lower())))
    clickhouse_keys = list(((click_meta or {}).get("order_by") or []))
    yaml_payload = None
    if yaml_bundle and yaml_bundle.get("yaml_content"):
        try:
            yaml_payload = yaml.safe_load(yaml_bundle.get("yaml_content")) or {}
        except Exception:
            yaml_payload = {}
    current_files = [item for item in (related_files or []) if isinstance(item, dict)]
    if not current_files and file_item:
        current_files = [file_item]
    if yaml_bundle and entity_name_seed and current_files:
        sql_bundle = resolver.collect_target_sql(target_fqn, current_files)
        normalized = resolver.validate_meta_bundle(
            engine=resolver.engine,
            base_dir=resolver.base_dir,
            prod_root_value=resolver.entity_meta_dir,
            dev_root_value=resolver.dev_entity_meta_dir,
            entity_name=entity_name_seed,
            schema_name=schema_name,
            table_name=table_name,
            key_attributes=detected_keys,
            source_object_key=None,
            yaml_content=str(yaml_bundle.get("yaml_content") or ""),
            recreate_sql=sql_bundle.get("recreate_sql", ""),
            insert_sql=sql_bundle.get("insert_sql", ""),
            truncate_sql=sql_bundle.get("truncate_sql", ""),
            dev_database_url=resolver.dev_database_url,
        )
        normalized_bundle = normalized.get("normalized") or {}
        if normalized_bundle.get("yaml_content"):
            yaml_bundle["yaml_content"] = normalized_bundle.get("yaml_content")
        if isinstance(normalized_bundle.get("key_attributes"), list):
            yaml_bundle["key_attributes"] = normalized_bundle.get("key_attributes")
            yaml_key_attributes = list(normalized_bundle.get("key_attributes") or [])
        try:
            yaml_payload = yaml.safe_load(yaml_bundle.get("yaml_content") or "") or {}
        except Exception:
            yaml_payload = {}
        detected_keys = list(key_attributes_override or []) or yaml_key_attributes
    table_load_mode = str((yaml_payload or {}).get("table_load_mode") or (meta or {}).get("table_load_mode") or "").strip()
    dependencies: list[str] = []
    impact = resolver.impact_summary(target_fqn)
    is_new = bool(yaml_bundle and yaml_bundle.get("source") == "new") or not meta
    item_object_type = (
        str((yaml_payload or {}).get("object_type") or "").strip().upper()
        or str(object_type_hint or "").strip().upper()
        or ("VIEW" if schema_name.lower().endswith("_view") else "TABLE")
    )
    if item_object_type != "TABLE":
        detected_keys = []
    checks = {"row_count": None, "duplicate_groups": None, "distributed_by": None}
    checks_error = None
    current_execution = execution_row or {"status": "skipped", "duration_sec": 0.0}
    if str(current_execution.get("status") or "") == "ok" and item_object_type in {"TABLE", "VIEW"}:
        try:
            checks = resolver.query_table_checks(
                dev_database_url=resolver.dev_database_url,
                target_fqn=target_fqn,
                key_attributes=detected_keys if item_object_type == "TABLE" else [],
            )
        except Exception as exc:
            checks = {"row_count": None, "duplicate_groups": None, "distributed_by": None}
            checks_error = str(exc)
    item_warnings: list[str] = []
    null_conditions: list[str] = []
    if item_object_type == "TABLE":
        try:
            null_conditions = resolver.existing_null_conditions(schema_name, table_name)
        except Exception as exc:
            item_warnings.append(f"Не удалось загрузить существующие DQ nulls: {exc}")
    if item_object_type == "TABLE" and not detected_keys:
        item_warnings.append("Ключевые поля не найдены автоматически")
    if current_execution.get("status") == "error":
        item_warnings.append(f"Ошибка в файле `{path_value}`: {current_execution.get('error_message') or 'SQL не выполнился'}")
    if checks.get("duplicate_groups") not in (None, 0):
        item_warnings.append(f"Обнаружены дубли по ключу: {checks.get('duplicate_groups')}")
    if checks_error:
        item_warnings.append(f"Не удалось посчитать строки/дубли в DEV: {checks_error}")
    requires_item_input, missing_fields = resolver.item_needs_attention({
        "is_new": is_new,
        "entity_name": entity_name,
        "key_attributes": detected_keys,
        "object_type": item_object_type,
    })
    return {
        "path": path_value,
        "target_fqn": target_fqn,
        "object_type": item_object_type,
        "entity_name": entity_name,
        "entity_names": entity_names,
        "load_mode": table_load_mode,
        "key_attributes": detected_keys,
        "auto_detected_key_attributes": detected_keys,
        "scd_type": "scd1",
        "version_key": [],
        "filter": "",
        "null_conditions": null_conditions,
        "clickhouse_keys": clickhouse_keys,
        "dependencies": dependencies,
        "execution": current_execution,
        "duration_sec": float(current_execution.get("duration_sec") or 0.0),
        "checks": checks,
        "impact": impact,
        "yaml_bundle": yaml_bundle,
        "is_new": is_new,
        "stand_dev": True,
        "stand_prod": True,
        "copy_to_clickhouse": bool(clickhouse_keys),
        "requires_user_input": requires_item_input,
        "missing_fields": missing_fields,
        "warnings": item_warnings,
    }
