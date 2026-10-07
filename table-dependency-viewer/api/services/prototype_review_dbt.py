"""Pure path, parsing and rendering helpers for Prototype Review dbt files."""

import ast
import json
import os
import re
from pathlib import Path
from posixpath import join as posix_join
from typing import Any, Optional

DBT_DQ_TECHNICAL_ROOT = os.getenv("DBT_DQ_TECHNICAL_ROOT", "dbt_greenplum_elt/models/dq/technical")
DBT_REGISTRY_ROOT = os.getenv("DBT_REGISTRY_ROOT", "dbt_greenplum_elt/models_metadata")
ENTITY_META_GIT_META_ROOT = os.getenv(
    "ENTITY_META_GIT_META_ROOT",
    "meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity",
)


def _object_directory_name(table_name: str) -> str:
    return re.sub(r"[^a-z0-9_]+", "", str(table_name or "").strip().strip('"').lower())


def yaml_repo_path(entity_name: str, schema_name: str, table_name: str) -> str:
    table_directory = _object_directory_name(table_name) or str(table_name or "").strip()
    return posix_join(Path(ENTITY_META_GIT_META_ROOT).as_posix().strip("/"), str(entity_name or "").strip(), str(schema_name or "").strip(), table_directory, "meta_data_file.yaml")


def dbt_registry_path(schema_name: str, table_name: str) -> str:
    schema_name_norm = str(schema_name or "").strip().lower()
    table_name_norm = str(table_name or "").strip().lower()
    return posix_join(str(DBT_REGISTRY_ROOT or "dbt_greenplum_elt/models_metadata").strip("/"), schema_name_norm, f"{schema_name_norm}.{table_name_norm}.yml")


def dbt_duplicates_path(schema_name: str, table_name: str) -> str:
    schema_name_norm = str(schema_name or "").strip().lower()
    table_name_norm = str(table_name or "").strip().lower()
    return posix_join(str(DBT_DQ_TECHNICAL_ROOT or "dbt_greenplum_elt/models/dq/technical").strip("/"), f"dq_{schema_name_norm}_s_{table_name_norm}_s_duplicates.sql")


def dbt_nulls_path(schema_name: str, table_name: str) -> str:
    return posix_join(str(DBT_DQ_TECHNICAL_ROOT or "dbt_greenplum_elt/models/dq/technical").strip("/"), f"dq_{schema_name.strip().lower()}_s_{table_name.strip().lower()}_s_nulls.sql")


def parse_null_conditions(content: Optional[str]) -> list[str]:
    source = str(content or "")
    match = re.search(r"\bcheck_conditions\s*=\s*\[", source)
    if not match:
        return []
    start, depth, quote, escaped, end = match.end() - 1, 0, "", False, None
    for index in range(start, len(source)):
        char = source[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in {"'", '"'}:
            quote = char
        elif char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    if end is None:
        raise ValueError("В существующей DQ nulls-модели не закрыт список check_conditions")
    try:
        values = ast.literal_eval(source[start:end])
    except (SyntaxError, ValueError) as exc:
        raise ValueError("Не удалось разобрать check_conditions существующей DQ nulls-модели") from exc
    if not isinstance(values, (list, tuple)):
        raise ValueError("check_conditions существующей DQ nulls-модели должен быть списком")
    return [str(value).strip() for value in values if str(value).strip()]


def dbt_key_list(key_attributes: list[Any]) -> str:
    values = [str(value).strip() for value in key_attributes if str(value).strip()]
    if not values:
        raise ValueError("Не заполнены ключевые поля для DQ duplicates")
    return "[" + ", ".join("'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'" for value in values) + "]"


def build_duplicates_model(item: dict[str, Any]) -> str:
    check_columns = dbt_key_list(item.get("key_attributes") or [])
    return "\n".join(["{{- config(", "    error_code         = 'dq_all0001',", "    detail_store_flag  = true,", "    detail_store_limit = 30,", "    check_type         = 'duplicates',", f"    check_columns      = {check_columns},", "    tags               = ['dq', 'technical', 'duplicates']", "    ) -}}", ""])


def build_nulls_model(item: dict[str, Any]) -> str:
    conditions = [str(value).strip() for value in (item.get("null_conditions") or []) if str(value).strip()]
    if not conditions:
        raise ValueError("Не заполнены условия для DQ nulls")
    rendered = ",\n".join(f"        {json.dumps(value, ensure_ascii=False)}" for value in conditions)
    return "\n".join(["{{- config(", "    error_code         = 'dq_all0003',", "    detail_store_flag  = true,", "    detail_store_limit = none,", "    check_type         = 'nulls',", "    check_conditions   = [", rendered, "    ],", "    check_filter       = none,", "    tags               = ['dq', 'technical', 'nulls']", "    ) -}}", ""])


def update_duplicates_model(content: str, key_attributes: list[Any]) -> str:
    check_columns = dbt_key_list(key_attributes)
    pattern = re.compile(r"(?P<prefix>\bcheck_columns\s*=\s*)\[(?P<body>.*?)\]", re.DOTALL)
    source = str(content or "")
    if len(list(pattern.finditer(source))) != 1:
        raise ValueError("В DQ-модели не найден единственный параметр check_columns")
    return pattern.sub(lambda match: f"{match.group('prefix')}{check_columns}", source, count=1)


def build_registry_yaml(item: dict[str, Any]) -> str:
    target_fqn = str(item.get("target_fqn") or "").strip().lower()
    if "." not in target_fqn:
        raise ValueError(f"Не удалось определить schema/table для dbt registry: {target_fqn or '—'}")
    schema_name, table_name = target_fqn.split(".", 1)
    unique_key = [str(value).strip() for value in (item.get("key_attributes") or []) if str(value).strip()]
    if not unique_key:
        raise ValueError(f"Для {target_fqn} не заполнен unique_key")
    scd_type = str(item.get("scd_type") or "scd1").strip().lower()
    if scd_type not in {"scd1", "scd2"}:
        raise ValueError(f"Для {target_fqn} указан неподдерживаемый scd_type: {scd_type}")
    version_key = [str(value).strip() for value in (item.get("version_key") or []) if str(value).strip()]
    if scd_type == "scd2" and not version_key:
        raise ValueError(f"Для SCD2-объекта {target_fqn} не заполнен version_key")
    dq_filter = str(item.get("filter") or "").strip()
    if not dq_filter:
        legacy_filters = [str(value).strip() for value in (item.get("filters") or []) if str(value).strip()]
        dq_filter = legacy_filters[0] if legacy_filters else ""
    lines = ["relation:", "  # наименование схемы", f"  schema_name: {schema_name}", "  # наименование таблицы", f"  table_name: {table_name}", "  # тип scd (scd1, scd2)", f"  scd_type: {scd_type}", "  unique_key: # список полей уникального ключа", *[f"    - {value}" for value in unique_key]]
    if scd_type == "scd2":
        lines.extend(["  version_key: #Актуально только для scd_type: scd2, в остальных случаях блок не создавать", *[f"    - {value}" for value in version_key]])
    lines.extend(["dq:", '  - check_type: "duplicates"', "    detail_store_flag: true", "    detail_store_limit: 30"])
    if dq_filter:
        lines.append(f"    filter: {json.dumps(dq_filter, ensure_ascii=False)}")
    null_conditions = [str(value).strip() for value in (item.get("null_conditions") or []) if str(value).strip()]
    if null_conditions:
        lines.extend(['  - check_type: "nulls"', "    detail_store_flag: true", "    detail_store_limit: none", "    conditions:", *[f"      - {json.dumps(value, ensure_ascii=False)}" for value in null_conditions]])
    return "\n".join(lines) + "\n"


# Compatibility aliases while callers are migrated away from main.py names.
_prototype_review_yaml_repo_path = yaml_repo_path
_prototype_review_dbt_registry_path = dbt_registry_path
_prototype_review_dbt_dq_path = dbt_duplicates_path
_prototype_review_dbt_nulls_path = dbt_nulls_path
_prototype_review_parse_null_conditions = parse_null_conditions
_prototype_review_dbt_key_list = dbt_key_list
_prototype_review_build_dbt_dq_model = build_duplicates_model
_prototype_review_build_dbt_nulls_model = build_nulls_model
_prototype_review_update_dbt_dq_model = update_duplicates_model
_prototype_review_build_dbt_registry_yaml = build_registry_yaml
