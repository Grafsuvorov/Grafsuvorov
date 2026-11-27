"""Validation and publication data for multiple independently generated STG tables."""
import re
from .stg_source_loader import _primary_key_expression


def source_load_items(value):
    if not value:
        return []
    return [dict(item) for item in value] if isinstance(value, list) else [dict(value)]


def payload_source_loads(payload):
    batch = getattr(payload, "source_loads", None) or []
    single = getattr(payload, "source_load", None)
    if batch and single:
        raise ValueError("Передайте source_loads или source_load, а не оба поля")
    values = batch or ([single] if single else [])
    return [item.model_dump() if hasattr(item, "model_dump") else dict(item) for item in values]


def source_keys(load):
    expression = _primary_key_expression(load.get("primary_key"))
    return re.findall(r'"([^"]+)"', expression)


def validate_source_loads(loads, *, mode, review_items):
    occupied = {str(item.get("target_fqn") or "").lower() for item in review_items}
    seen = set()
    for load in loads:
        schema = str(load.get("target_schema") or "").strip().lower()
        table = str(load.get("target_table") or "").strip().strip('"')
        target = f"{schema}.{table}"
        if schema not in {"stg", "dict_stg"} or not table:
            raise ValueError("Для STG укажите схему stg/dict_stg и имя таблицы")
        if load.get("mode", "khd") != mode:
            raise ValueError(f"STG {target} подготовлена в другом контуре. Повторите генерацию в {mode.upper()}")
        if target.lower() in occupied or target.lower() in seen:
            raise ValueError(f"STG {target} повторяется в наборе или уже присутствует в diff")
        seen.add(target.lower())
        if load.get("load_status", "ok") != "ok" or not str(load.get("recreate_sql") or "").strip():
            raise ValueError(f"STG {target}: сначала успешно выполните генерацию в DEV")
        source_keys(load)
        if mode == "khd" and (not str(load.get("entity_name") or "").strip() or not str(load.get("yaml_content") or "").strip()):
            raise ValueError(f"STG {target}: отсутствует сущность или YAML")
        load.update(target_schema=schema, target_table=table)


def source_dbt_items(loads):
    return [{"item_id": f"source:{load['target_schema']}.{load['target_table']}",
             "target_fqn": f"{load['target_schema']}.{load['target_table']}", "object_type": "TABLE",
             "key_attributes": source_keys(load), "scd_type": "scd1", "entity_name": "",
             "source_load_sql": load["recreate_sql"]} for load in loads]
