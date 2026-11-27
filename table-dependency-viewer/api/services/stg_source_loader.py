"""Execution helpers for loading source tables into STG metadata.

The database function is the source of truth for source-specific types and
PXF objects.  This module deliberately does not try to reproduce its logic.
"""

from __future__ import annotations

import re
from typing import Any

from sqlalchemy import text


ALLOWED_SCHEMAS = {"stg", "dict_stg"}
# SAP namespace identifiers may start with '/', e.g. /BIC/ATR_TO13000.
# These names are passed as bound function arguments, preserving their case.
IDENTIFIER_RE = re.compile(r"^/?[A-Za-z_][A-Za-z0-9_$#/]*$")


def source_load_entity_names(value: Any) -> list[str]:
    """Return ordered unique schedules entered as a comma-separated value."""
    result: list[str] = []
    seen: set[str] = set()
    for part in str(value or "").split(","):
        entity_name = part.strip()
        key = entity_name.lower()
        if entity_name and key not in seen:
            seen.add(key)
            result.append(entity_name)
    return result


def prepare_source_load_yaml_contents(
    *, engine, yaml_content: str, entity_names: list[str], schema_name: str,
    table_name: str, yaml_contents: dict[str, str] | None = None, read_existing_yaml=None,
) -> dict[str, str]:
    """Resolve each entity's own catalog identity, keeping preview IDs stable."""
    from .entity_dev_meta import _lookup_entity_id, _reserve_next_table_id
    from ..config import TABLE_TABLES_META
    import yaml

    names = source_load_entity_names(",".join(entity_names))
    if not names:
        raise ValueError("Не заполнены сущности загрузки")
    primary = yaml.safe_load(yaml_content) or {}
    if not isinstance(primary, dict):
        raise ValueError("YAML загрузки должен быть объектом")
    if (str(primary.get("entity_name") or "").lower() != names[0].lower()
        or str(primary.get("table_schema") or "").lower() != schema_name.lower()
        or str(primary.get("table_name") or "").lower() != table_name.lower()):
        raise ValueError("Сущность, схема или таблица изменились после генерации YAML; повторите генерацию")
    drafts = dict(yaml_contents or {})
    if drafts and any(name not in drafts for name in names):
        raise ValueError("Список сущностей изменился после генерации YAML; повторите генерацию")
    drafts[names[0]] = yaml_content
    identities = {}
    used_ids = {}
    for name in names:
        entity_id = _lookup_entity_id(engine, name)
        if not entity_id:
            raise ValueError(f"Не найден entity_id для сущности `{name}`")
        with engine.connect() as conn:
            existing = conn.execute(text(f"""
                SELECT table_id FROM {TABLE_TABLES_META}
                WHERE entity_id = :entity_id
                  AND lower(table_schema) = lower(:schema_name)
                  AND lower(table_name) = lower(:table_name)
                ORDER BY table_id LIMIT 1
            """), {"entity_id": entity_id, "schema_name": schema_name, "table_name": table_name}).scalar()
        canonical_text = read_existing_yaml(name) if read_existing_yaml and not existing else None
        canonical = yaml.safe_load(canonical_text) if canonical_text else {}
        draft = yaml.safe_load(drafts.get(name) or "") or {}
        if not isinstance(draft, dict) or not isinstance(canonical, dict):
            raise ValueError(f"YAML сущности `{name}` должен быть объектом")
        own_draft = (
            str(draft.get("entity_name") or "").strip().lower() == name.lower()
            and str(draft.get("table_schema") or "").strip().lower() == schema_name.lower()
            and str(draft.get("table_name") or "").strip().lower() == table_name.lower()
        )
        table_id = existing or canonical.get("table_id") or (draft.get("table_id") if own_draft else None)
        if not table_id:
            table_id = _reserve_next_table_id(engine)
        try:
            table_id = int(table_id)
        except (ValueError, TypeError):
            raise ValueError(f"Некорректный table_id для сущности `{name}`") from None
        if table_id <= 0:
            raise ValueError(f"Некорректный table_id для сущности `{name}`")
        with engine.connect() as conn:
            owner = conn.execute(text(f"""
                SELECT entity_id, table_schema, table_name FROM {TABLE_TABLES_META}
                WHERE table_id = :table_id
            """), {"table_id": table_id}).mappings().first()
        if owner and (int(owner["entity_id"]) != int(entity_id)
                      or str(owner["table_schema"]).lower() != schema_name.lower()
                      or str(owner["table_name"]).lower() != table_name.lower()):
            raise ValueError(f"table_id {table_id} принадлежит другому объекту; сущность `{name}`")
        if table_id in used_ids:
            raise ValueError(f"Одинаковый table_id {table_id} у сущностей `{used_ids[table_id]}` и `{name}`")
        used_ids[table_id] = name
        identities[name] = {"table_id": table_id, "entity_id": int(entity_id)}

    def replace_field(content, key, value):
        pattern = re.compile(rf"(?m)^{key}:[^\r\n]*$")
        line = f"{key}: {value}"
        return pattern.sub(lambda _: line, content, count=1) if pattern.search(content) else content.rstrip() + "\n" + line + "\n"

    result = {}
    for name in names:
        # Ordinary schedule identifiers stay plain YAML, without JSON quotes.
        plain_name = re.fullmatch(r"[A-Za-z0-9_]+", name) and not name.isdigit() and name.lower() not in {"null", "true", "false", "yes", "no", "on", "off"}
        scalar = name if plain_name else yaml.safe_dump(name, allow_unicode=True).strip().removesuffix("...").strip()
        content = replace_field(str(yaml_content), "entity_name", scalar)
        for key, value in identities[name].items():
            content = replace_field(content, key, value)
        result[name] = content.rstrip() + "\n"
    return result


def source_load_replica_yaml_contents(yaml_content: str, entity_names: list[str], **identity_context) -> dict[str, str]:
    """Compatibility entry point; never copy primary IDs into another entity."""
    names = source_load_entity_names(",".join(entity_names))
    if len(names) < 2:
        return {}
    if not identity_context:
        raise ValueError("Для YAML нескольких сущностей нужно отдельно определить entity_id и table_id")
    contents = prepare_source_load_yaml_contents(yaml_content=yaml_content, entity_names=names, **identity_context)
    return {name: contents[name] for name in names[1:]}


def source_loader_parameters_from_sql(sql: str) -> dict[str, str]:
    """Extract persisted ``etl_source_to_greenplum_new`` arguments from SQL.

    Older STG metadata does not keep source relation and key fields in YAML,
    but its ``sql_query_recreate_init.sql`` already contains the canonical
    function call.  This also makes old tables editable without migration.
    """
    result: dict[str, str] = {}
    field_map = {
        "v_source_schema_name": "source_schema_name",
        "v_source_table_name": "source_table_name",
        "v_fields_list": "fields",
        "v_distribution_field": "distribution_field",
        "v_pk": "primary_key",
        "v_server_id": "source_id",
    }
    for argument_name, result_name in field_map.items():
        match = re.search(
            rf"\b{argument_name}\s*:=\s*'((?:''|[^'])*)'",
            str(sql or ""),
            flags=re.IGNORECASE,
        )
        if match:
            result[result_name] = match.group(1).replace("''", "'").strip()
    return result


def _identifier(value: str, label: str) -> str:
    result = str(value or "").strip().strip('"')
    if not result or not IDENTIFIER_RE.fullmatch(result):
        raise ValueError(f"Некорректное значение поля «{label}»")
    return result


def _fields(value: str) -> str:
    raw = str(value or "ALL").strip()
    if raw.upper() == "ALL":
        return "ALL"
    names = [_identifier(item, "Список полей") for item in raw.split(",") if item.strip()]
    if not names:
        raise ValueError("Укажите хотя бы одно поле или ALL")
    return ",".join(names)


def _primary_key_expression(value: str) -> str:
    """Build the expression expected by ``etl_source_to_greenplum_new``.

    The loader accepts a compound business key as ``"FIELD_A" || "FIELD_B"``.
    In the UI it is convenient to enter either this expression or a comma
    separated list; normalising both forms prevents malformed SQL parameters.
    """
    raw = str(value or "").strip()
    if not raw:
        raise ValueError("Заполните обязательное поле «Первичный ключ»")
    parts = re.split(r"\s*\|\|\s*|\s*,\s*", raw)
    names = [_identifier(part, "Первичный ключ") for part in parts if part.strip()]
    if not names or len(names) != len(parts):
        raise ValueError("Первичный ключ должен содержать одно или несколько имён полей")
    return " || ".join(f'"{name}"' for name in names)


def list_source_servers(engine) -> list[dict[str, Any]]:
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT
                server_id,
                source_type,
                server_name,
                dag_name,
                meta_view_name
            FROM tech_etl.source_servers_meta
            ORDER BY server_id
        """)).mappings().all()
    return [
        {
            **dict(row),
            # Backwards-compatible names for older clients.
            "source_id": row["server_id"],
            "source_server_name": row["server_name"],
            "source_columns_catalog": row["meta_view_name"],
        }
        for row in rows
    ]


def list_target_tables(engine, schema_name: str, table_name: str | None = None) -> list[dict[str, Any]]:
    schema = str(schema_name or "").strip().lower()
    if schema not in ALLOWED_SCHEMAS:
        raise ValueError("Доступны только схемы stg и dict_stg")
    selected_table = str(table_name).strip().strip('"') if table_name is not None else None
    # Read physical relations directly. information_schema joins can multiply
    # column rows across constraints and are expensive on Greenplum catalogs.
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT c.relname AS table_name, a.attname AS column_name,
                   a.attnum AS ordinal_position, pk.conkey AS primary_key_positions
            FROM pg_catalog.pg_class c
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_catalog.pg_attribute a
              ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
            LEFT JOIN pg_catalog.pg_constraint pk
              ON pk.conrelid = c.oid AND pk.contype = 'p'
            WHERE n.nspname = :schema_name
              AND c.relkind IN ('r', 'p', 'f')
              AND (:table_name IS NULL OR lower(c.relname) = lower(:table_name))
            ORDER BY c.relname, a.attnum
        """), {"schema_name": schema, "table_name": selected_table}).mappings().all()
    technical = {"rn", "dttm_inserted", "dttm_updated", "job_name", "deleted_flag", "is_actual"}
    tables = {}
    for row in rows:
        table = tables.setdefault(row["table_name"], {"columns": {}, "keys": row.get("primary_key_positions") or []})
        name = row.get("column_name")
        if name and name.lower() not in technical:
            table["columns"][int(row["ordinal_position"])] = name
    result = []
    for name, table in tables.items():
        columns = table["columns"]
        keys = [columns[pos] for pos in table["keys"] if pos in columns]
        result.append({"table_name": name, "fields": ",".join(columns[pos] for pos in sorted(columns)),
                       "primary_key": " || ".join('"' + key.replace('"', '""') + '"' for key in keys)})
    return result


def target_table_exists(engine, schema_name: str, table_name: str) -> bool:
    """Return whether the physical DEV target already exists.

    Physical existence is independent of ETL metadata: hand-created DEV
    tables can legitimately have no YAML or metadata catalog entry yet.
    """
    schema = str(schema_name or "").strip().lower()
    table = _identifier(table_name, "Таблица target")
    if schema not in ALLOWED_SCHEMAS:
        raise ValueError("Доступны только схемы stg и dict_stg")
    with engine.connect() as conn:
        return bool(conn.execute(text("""
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.tables
                WHERE table_schema = :schema_name
                  AND lower(table_name) = lower(:table_name)
            )
        """), {"schema_name": schema, "table_name": table}).scalar())


def _notice_value(notices: list[str], marker: str, stop_markers: tuple[str, ...]) -> str:
    for index, raw in enumerate(notices):
        line = str(raw or "")
        pos = line.upper().find(marker.upper())
        if pos < 0:
            continue
        value = line[pos + len(marker):].strip()
        chunks = [value]
        for tail in notices[index + 1:]:
            tail_text = str(tail or "")
            # psycopg2 may retain PostgreSQL's ``NOTICE:`` prefix.  Compare
            # the actual notice body so a following ``NOTICE: Value:`` or
            # ``NOTICE: Status:`` ends the SQL block as intended.
            notice_body = re.sub(r"^\s*NOTICE:\s*", "", tail_text, flags=re.IGNORECASE)
            if any(notice_body.upper().startswith(item.upper()) for item in stop_markers):
                break
            chunks.append(tail_text)
        return "\n".join(chunks).strip()
    return ""


def _parse_output(notices: list[str], schema_name: str, table_name: str) -> dict[str, str]:
    all_fields = _notice_value(notices, "ALL FIELDS", ("GARBAGE:", "QUERY TO GET DDL:"))
    # The function logs a temporary physical DDL as ``DDL CREATE TABLE``.
    # It must not be committed as recreate SQL: the canonical source file is
    # the final ``QUERY CREATE WITH FIELDS`` call to etl_source_to_greenplum_new.
    recreate_sql = _notice_value(notices, "QUERY CREATE WITH FIELDS:", ())
    insert_sql = _notice_value(notices, "DML INSERT QUERY:", ("VALUE:", "STATUS:", "QUERY CREATE WITH FIELDS:"))
    target = f'{schema_name.lower()}."{table_name}"'
    return {
        "fields": re.sub(r"\s+", "", all_fields),
        "recreate_sql": recreate_sql,
        "insert_sql": insert_sql,
        "truncate_sql": f"truncate table {target};",
    }


def run_source_loader(engine, payload: dict[str, Any]) -> dict[str, Any]:
    schema_name = str(payload.get("target_schema") or "").strip().lower()
    if schema_name not in ALLOWED_SCHEMAS:
        raise ValueError("Доступны только схемы stg и dict_stg")
    source_schema = _identifier(payload.get("source_schema"), "Схема источника")
    source_table = _identifier(payload.get("source_table"), "Таблица источника")
    target_table = _identifier(payload.get("target_table"), "Таблица target")
    distribution_field = _identifier(payload.get("distribution_field") or "RN", "Ключ распределения")
    primary_key = _primary_key_expression(payload.get("primary_key"))
    fields = _fields(payload.get("fields"))
    try:
        server_id = int(payload.get("server_id"))
    except (TypeError, ValueError) as exc:
        raise ValueError("Выберите сервер источника") from exc

    with engine.connect() as conn:
        server = conn.execute(text("""
            SELECT server_id, source_type, server_name, dag_name, meta_view_name
            FROM tech_etl.source_servers_meta
            WHERE server_id = :server_id
        """), {"server_id": server_id}).mappings().first()
    if not server:
        raise ValueError("Выбранный сервер не найден в tech_etl.source_servers_meta")

    raw_connection = engine.raw_connection()
    cursor = raw_connection.cursor()
    try:
        cursor.execute("""
            SELECT tech_etl.etl_source_to_greenplum_new(
                v_source_schema_name := %s,
                v_source_table_name := %s,
                v_fields_list := %s,
                v_target_schema_name := %s,
                v_target_table_name := %s,
                v_server_id := %s,
                v_distribution_field := %s,
                v_pk := %s
            )
        """, (source_schema, source_table, fields, schema_name.upper(), target_table, str(server_id), distribution_field, primary_key))
        raw_connection.commit()
        notices = list(getattr(raw_connection, "notices", []) or [])
    except Exception as exc:
        raw_connection.rollback()
        notices = list(getattr(raw_connection, "notices", []) or [])
        return {
            "status": "error", "error": str(exc), "notices": notices[-200:],
            "server": dict(server), "fields": fields,
        }
    finally:
        cursor.close()
        raw_connection.close()

    parsed = _parse_output(notices, schema_name, target_table)
    return {"status": "ok", "notices": notices[-200:], "server": dict(server), **parsed}
