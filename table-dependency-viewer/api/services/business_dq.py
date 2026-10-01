"""Pure rendering and validation helpers for business DQ models."""

from typing import Any, Union


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
