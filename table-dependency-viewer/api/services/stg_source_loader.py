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


def list_source_servers(engine) -> list[dict[str, Any]]:
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT
                service_name,
                server_id,
                source_type,
                server_name,
                dag_name,
                meta_view_name
            FROM tech_etl.source_servers_meta
            ORDER BY service_name, server_id
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
                max(CASE WHEN tc.constraint_type = 'PRIMARY KEY' THEN kcu.column_name END) AS primary_key
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
    recreate_sql = _notice_value(notices, "DDL CREATE TABLE:", ("STATUS:", "QUERY TO GET COLUMNS:"))
    if not recreate_sql:
        recreate_sql = _notice_value(notices, "QUERY DDL:", ("DDL CREATE TABLE:", "STATUS:"))
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
    primary_key = str(payload.get("primary_key") or "").strip().strip('"')
    if primary_key:
        primary_key = _identifier(primary_key, "Первичный ключ")
    fields = _fields(payload.get("fields"))
    try:
        server_id = int(payload.get("server_id"))
    except (TypeError, ValueError) as exc:
        raise ValueError("Выберите сервер источника") from exc

    with engine.connect() as conn:
        server = conn.execute(text("""
            SELECT service_name, server_id, source_type, server_name, dag_name, meta_view_name
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
        """, (source_schema, source_table, fields, schema_name.upper(), target_table, str(server_id), distribution_field, f'"{primary_key}"' if primary_key else None))
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
