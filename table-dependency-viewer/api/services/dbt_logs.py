from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

from sqlalchemy import bindparam, text

from .dbt_manifest import get_dbt_manifest_model


def _fmt_dt(value: Any) -> str | None:
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if value is None:
        return None
    text_value = str(value).strip()
    return text_value or None


def _normalize_path_candidates(model: dict[str, Any] | None) -> list[str]:
    if not isinstance(model, dict):
        return [""]
    values: list[str] = []
    for key in ("original_file_path", "path", "build_path", "compiled_path", "patch_path"):
        raw = str(model.get(key) or "").strip().lower()
        if raw and raw not in values:
            values.append(raw)
    return values or [""]


def get_dbt_model_run_history(
    *,
    engine,
    base_dir: Path,
    manifest_dir: str,
    schema_name: str,
    table_name: str,
    source: str = "ohd",
    limit: int = 12,
    table_model_catalog: str,
    table_model_log: str,
    table_run_log: str,
) -> dict[str, Any]:
    model = get_dbt_manifest_model(
        base_dir=base_dir,
        manifest_dir=manifest_dir,
        schema_name=schema_name,
        table_name=table_name,
        source=source,
    )
    if not model:
        return {"configured": True, "model": None, "catalog": None, "runs": []}

    schema_norm = str(schema_name or "").strip().lower()
    table_norm = str(table_name or "").strip().lower()
    fqn = f"{schema_norm}.{table_norm}"
    model_name = str(model.get("model_name") or "").strip().lower()
    path_candidates = _normalize_path_candidates(model)

    catalog_query = text(
        f"""
        SELECT
            model_name,
            model_path,
            model_type,
            model_tags,
            schema_name,
            table_name,
            table_full_name,
            inserted_dttm,
            updated_dttm,
            deleted_flag,
            CASE
                WHEN lower(coalesce(table_full_name, '')) = :fqn THEN 0
                WHEN lower(coalesce(schema_name, '')) = :schema_name
                 AND lower(coalesce(table_name, '')) = :table_name THEN 1
                WHEN lower(coalesce(model_name, '')) = :model_name THEN 2
                WHEN lower(coalesce(model_path, '')) IN :path_candidates THEN 3
                ELSE 10
            END AS match_rank
        FROM {table_model_catalog}
        WHERE NOT COALESCE(deleted_flag, false)
          AND (
            lower(coalesce(table_full_name, '')) = :fqn
            OR (
                lower(coalesce(schema_name, '')) = :schema_name
                AND lower(coalesce(table_name, '')) = :table_name
            )
            OR lower(coalesce(model_name, '')) = :model_name
            OR lower(coalesce(model_path, '')) IN :path_candidates
          )
        ORDER BY match_rank, updated_dttm DESC NULLS LAST, inserted_dttm DESC NULLS LAST
        LIMIT 1
        """
    ).bindparams(bindparam("path_candidates", expanding=True))

    with engine.connect() as conn:
        catalog_row = conn.execute(
            catalog_query,
            {
                "fqn": fqn,
                "schema_name": schema_norm,
                "table_name": table_norm,
                "model_name": model_name,
                "path_candidates": path_candidates,
            },
        ).mappings().first()

        resolved_model_name = str((catalog_row or {}).get("model_name") or model.get("model_name") or "").strip()
        resolved_model_type = str((catalog_row or {}).get("model_type") or "").strip().lower()
        resolved_model_path = str((catalog_row or {}).get("model_path") or "").strip().lower()

        filters: list[str] = []
        params: dict[str, Any] = {"limit": limit}
        if resolved_model_path:
            filters.append("lower(coalesce(m.model_path, '')) = :model_path")
            params["model_path"] = resolved_model_path
        if resolved_model_name:
            filters.append("lower(coalesce(m.model_name, '')) = :model_name")
            params["model_name"] = resolved_model_name.lower()
        if not filters:
            return {
                "configured": True,
                "model": model,
                "catalog": dict(catalog_row) if catalog_row else None,
                "runs": [],
            }
        model_type_sql = ""
        if resolved_model_type:
            model_type_sql = " AND lower(coalesce(m.model_type, '')) = :model_type "
            params["model_type"] = resolved_model_type

        runs_query = text(
            f"""
            SELECT
                m.execution_guid,
                m.model_name,
                m.model_path,
                m.model_type,
                m.model_status,
                m.materialized,
                m.start_dttm,
                m.finish_dttm,
                m.duration,
                EXTRACT(EPOCH FROM COALESCE(m.duration, m.finish_dttm - m.start_dttm)) / 60.0 AS duration_minutes,
                m.thread_id,
                m.error_message,
                m.inserted_dttm,
                r.dag_run_id,
                r.dag_name,
                r.dbt_run_status,
                r.total_model_count,
                r.success_model_count,
                r.failed_model_count
            FROM {table_model_log} m
            LEFT JOIN {table_run_log} r
              ON r.execution_guid = m.execution_guid
            WHERE ({' OR '.join(filters)})
            {model_type_sql}
            ORDER BY COALESCE(m.finish_dttm, m.start_dttm, m.inserted_dttm) DESC NULLS LAST,
                     m.inserted_dttm DESC NULLS LAST
            LIMIT :limit
            """
        )
        run_rows = conn.execute(runs_query, params).mappings().all()

    payload_runs = [
        {
            "execution_guid": row.get("execution_guid"),
            "model_name": row.get("model_name"),
            "model_path": row.get("model_path"),
            "model_type": row.get("model_type"),
            "model_status": row.get("model_status"),
            "materialized": row.get("materialized"),
            "start_dttm": _fmt_dt(row.get("start_dttm")),
            "finish_dttm": _fmt_dt(row.get("finish_dttm")),
            "duration_minutes": round(float(row.get("duration_minutes") or 0), 2) if row.get("duration_minutes") is not None else None,
            "thread_id": row.get("thread_id"),
            "error_message": row.get("error_message"),
            "inserted_dttm": _fmt_dt(row.get("inserted_dttm")),
            "dag_run_id": row.get("dag_run_id"),
            "dag_name": row.get("dag_name"),
            "dbt_run_status": row.get("dbt_run_status"),
            "total_model_count": row.get("total_model_count"),
            "success_model_count": row.get("success_model_count"),
            "failed_model_count": row.get("failed_model_count"),
        }
        for row in run_rows
    ]

    catalog_payload = None
    if catalog_row:
        catalog_payload = {
            "model_name": catalog_row.get("model_name"),
            "model_path": catalog_row.get("model_path"),
            "model_type": catalog_row.get("model_type"),
            "model_tags": catalog_row.get("model_tags"),
            "schema_name": catalog_row.get("schema_name"),
            "table_name": catalog_row.get("table_name"),
            "table_full_name": catalog_row.get("table_full_name"),
            "inserted_dttm": _fmt_dt(catalog_row.get("inserted_dttm")),
            "updated_dttm": _fmt_dt(catalog_row.get("updated_dttm")),
            "match_rank": catalog_row.get("match_rank"),
        }

    return {
        "configured": True,
        "model": model,
        "catalog": catalog_payload,
        "runs": payload_runs,
    }
