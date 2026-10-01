"""Business DQ parsing, validation and rendering services."""

import re
import time
from collections.abc import Callable
from typing import Any, Union

_BUSINESS_DQ_PATH = re.compile(r"(?:^|/)dq/data_quality_results/(dq_([a-z]+\d+)\.sql)$", re.IGNORECASE)
_BUSINESS_DQ_VIEW = re.compile(r"\bcreate\s+(?:or\s+replace\s+)?view\s+(dm_view\.[a-z0-9_]+)\b", re.IGNORECASE)


def checks_from_merge_request(
    mr_input: str,
    business_area_code: str | None,
    *,
    load_bundle: Callable[..., dict[str, Any]],
    gitlab_api_url: str,
    gitlab_project: str,
    gitlab_token: str,
    gitlab_ssl_verify: bool,
    default_project: str,
) -> tuple[dict[str, Any], list[dict[str, Any]], str, list[dict[str, str]]]:
    """Load a merge request and extract its business DQ checks and ClickHouse views."""
    requested_code = str(business_area_code or "").strip().lower()
    bundle = load_bundle(
        gitlab_api_url=gitlab_api_url,
        gitlab_project=gitlab_project,
        gitlab_token=gitlab_token,
        gitlab_ssl_verify=gitlab_ssl_verify,
        mr_input=mr_input,
        default_project=default_project,
    )
    checks: list[dict[str, Any]] = []
    codes: set[str] = set()
    views: list[dict[str, str]] = []
    for item in bundle.get("files") or []:
        path = str(item.get("path") or "")
        match = _BUSINESS_DQ_PATH.fullmatch(path)
        sql = str(item.get("sql") or item.get("content") or "").strip()
        view_match = _BUSINESS_DQ_VIEW.search(sql)
        if view_match:
            views.append({"fqn": view_match.group(1).lower(), "source_path": path, "sql": sql.rstrip()})
        if not match or not sql:
            continue
        error_code = f"dq_{match.group(2).lower()}"
        code_match = re.fullmatch(r"dq_([a-z]+)\d+", error_code)
        if not code_match:
            raise ValueError(f"Некорректный код проверки `{error_code}`")
        codes.add(code_match.group(1))
        if not re.match(r"^(?:--[^\n]*\n|/\*.*?\*/\s*)*select\b", sql, re.IGNORECASE | re.DOTALL):
            raise ValueError(f"{match.group(1)}: ожидается SQL SELECT с нарушениями")
        checks.append({"error_code": error_code, "source_path": path, "sql": sql.rstrip(";\n \t")})
    if not checks:
        raise ValueError("В MR не найдены файлы dq/data_quality_results/dq_<код>.sql")
    if len(codes) != 1:
        raise ValueError("В DQ-файлах должен использоваться один код предметной области")
    code = next(iter(codes))
    if requested_code and requested_code != code:
        raise ValueError(f"Код области `{requested_code}` не совпадает с кодом `{code}` из имени DQ-файлов")
    return bundle, sorted(checks, key=lambda item: item["error_code"]), code, views


def validate_checks(checks: list[dict[str, Any]], *, engine: Any) -> list[dict[str, Any]]:
    """Execute DQ SELECT statements in DEV and always roll their transactions back."""
    results: list[dict[str, Any]] = []
    forbidden = re.compile(r"\b(?:insert|update|delete|drop|alter|create|truncate|copy|call)\b", re.IGNORECASE)
    for item in checks:
        sql = str(item.get("sql") or "").strip().rstrip(";")
        if not re.match(r"^select\b", sql, re.IGNORECASE) or forbidden.search(sql):
            raise ValueError(f"{item.get('error_code') or 'DQ'}: допускается только SELECT без изменяющих команд")
        from sqlalchemy import text

        started = time.monotonic()
        try:
            with engine.connect() as connection:
                transaction = connection.begin()
                try:
                    connection.execute(text("SET LOCAL statement_timeout = '120000'"))
                    connection.execute(text(sql)).fetchmany(1)
                finally:
                    transaction.rollback()
            results.append({"error_code": item.get("error_code"), "status": "ok", "duration_sec": round(time.monotonic() - started, 3)})
        except Exception as exc:
            results.append({"error_code": item.get("error_code"), "status": "error", "duration_sec": round(time.monotonic() - started, 3), "error": str(exc)})
    errors = [f"{item.get('error_code')}: {item.get('error')}" for item in results if item.get("status") == "error"]
    if errors:
        raise ValueError("SQL DQ не прошли DEV-проверку: " + "; ".join(errors))
    return results


def normalize_detail_store_limit(value: Union[int, str, None]) -> str:
    raw_limit = str(value if value is not None else 100000).strip().lower()
    if raw_limit == "none":
        return "none"
    try:
        limit = int(raw_limit)
    except (TypeError, ValueError) as exc:
        raise ValueError("Лимит детализации должен быть положительным числом или `none`") from exc
    if limit <= 0:
        raise ValueError("Лимит детализации должен быть больше нуля")
    return str(limit)


def build_business_dq_model(check: dict[str, Any], area_code: str, detail_store_limit: Union[int, str]) -> str:
    limit = normalize_detail_store_limit(detail_store_limit)
    return "\n".join([
        "{{ config(",
        f"    error_code = '{check['error_code']}',",
        "    detail_store_flag = true,",
        f"    detail_store_limit = {limit},",
        f"    tags = ['dq', '{area_code}', 'business']",
        ") }}", "", check["sql"], "",
    ])


def build_business_dq_registry(error_code: str) -> str:
    return "\n".join(["relation:", "  schema_name: dm", f"  table_name: {error_code}", "  scd_type: scd1", ""])


_business_dq_model = build_business_dq_model
_business_dq_normalize_limit = normalize_detail_store_limit
_business_dq_registry = build_business_dq_registry
