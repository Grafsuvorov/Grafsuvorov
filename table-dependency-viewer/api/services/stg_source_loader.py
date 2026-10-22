"""Execution helpers for loading source tables into STG metadata.

The database function is the source of truth for source-specific types and
PXF objects.  This module deliberately does not try to reproduce its logic.
"""

from __future__ import annotations

import re
from typing import Any

from sqlalchemy import text


ALLOWED_SCHEMAS = {"stg", "dict_stg"}
IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_$#/]*$")


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


def list_target_tables(engine, schema_name: str) -> list[dict[str, Any]]:
    schema = str(schema_name or "").strip().lower()
    if schema not in ALLOWED_SCHEMAS:
        raise ValueError("Доступны только схемы stg и dict_stg")

    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT
                c.table_name,
                string_agg(c.column_name, ',' ORDER BY c.ordinal_position) AS fields,
                string_agg(
                    CASE WHEN tc.constraint_type = 'PRIMARY KEY' THEN quote_ident(kcu.column_name) END,
                    ' || ' ORDER BY kcu.ordinal_position
                ) AS primary_key
            FROM information_schema.columns c
            LEFT JOIN information_schema.key_column_usage kcu
              ON kcu.table_schema = c.table_schema
             AND kcu.table_name = c.table_name
             AND kcu.column_name = c.column_name
            LEFT JOIN information_schema.table_constraints tc
              ON tc.constraint_schema = kcu.constraint_schema
             AND tc.constraint_name = kcu.constraint_name
             AND tc.table_schema = kcu.table_schema
             AND tc.table_name = kcu.table_name
            WHERE c.table_schema = :schema_name
              -- etl_source_to_greenplum_new adds these fields itself; passing
              -- them as source fields would make an update of an existing
              -- table fail against the external source.
              AND lower(c.column_name) NOT IN (
                  'rn', 'dttm_inserted', 'dttm_updated', 'job_name',
                  'deleted_flag', 'is_actual'
              )
            GROUP BY c.table_name
            ORDER BY c.table_name
        """), {"schema_name": schema}).mappings().all()
    return [dict(row) for row in rows]


def target_table_exists(engine, schema_name: str, table_name: str) -> bool:
    """Return whether the physical DEV target already exists.

    A source-load update must never silently receive a new metadata identity.
    The caller uses this check before it invokes the database loading function.
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
            if any(tail_text.upper().startswith(item.upper()) for item in stop_markers):
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
