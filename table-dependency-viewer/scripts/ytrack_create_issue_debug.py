#!/usr/bin/env python3
"""Debug helper for creating one YouTrack issue directly via API.

Updated for prototype-review issue creation debugging on September 1, 2026.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import date
from typing import Any

import requests
import urllib3
try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - optional local convenience dependency
    def load_dotenv(path: str | None = None, *args, **kwargs):
        candidates = [path] if path else [".env"]
        loaded = False
        for candidate in candidates:
            if not candidate:
                continue
            try:
                with open(candidate, "r", encoding="utf-8") as handle:
                    for raw_line in handle:
                        line = raw_line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        key, value = line.split("=", 1)
                        key = key.strip()
                        if not key or key in os.environ:
                            continue
                        value = value.strip().strip('"').strip("'")
                        os.environ[key] = value
                    loaded = True
            except FileNotFoundError:
                continue
        return loaded

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

load_dotenv()
load_dotenv("api/.env")

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru").rstrip("/")
YOUTRACK_TOKEN = os.getenv("YOUTRACK_TOKEN", "")
YOUTRACK_PROJECT = os.getenv("YOUTRACK_PROJECT", "КХД")
YOUTRACK_PROJECT_ID = os.getenv("YOUTRACK_PROJECT_ID", "")
YOUTRACK_QUEUE = os.getenv("YOUTRACK_QUEUE", "")
YOUTRACK_ISSUE_TYPE = os.getenv("YOUTRACK_ISSUE_TYPE", "task")
YOUTRACK_SSL_VERIFY = str(os.getenv("YOUTRACK_SSL_VERIFY", "false")).lower() == "true"
YOUTRACK_ESTIMATE_FIELD_NAME = os.getenv("YOUTRACK_ESTIMATE_FIELD_NAME", "Оценка (чел./час.)")
YOUTRACK_DEFAULT_ESTIMATE_MINUTES = int(os.getenv("YOUTRACK_DEFAULT_ESTIMATE_MINUTES", "60"))
YOUTRACK_CARD_TYPE_FIELD_NAME = os.getenv("YOUTRACK_CARD_TYPE_FIELD_NAME", "Тип карточки")
YOUTRACK_CARD_TYPE_VALUE = os.getenv("YOUTRACK_CARD_TYPE_VALUE", "Task")
YOUTRACK_ASSIGNEE_FIELD_NAME = os.getenv("YOUTRACK_ASSIGNEE_FIELD_NAME", "Assignee")
YOUTRACK_ASSIGNEE_QUERY = os.getenv("YOUTRACK_ASSIGNEE_QUERY", "Suvorov Nikita")
YOUTRACK_RELEASE_DATE_FIELD_NAME = os.getenv("YOUTRACK_RELEASE_DATE_FIELD_NAME", "Дата релиза")
YOUTRACK_DIRECTION_FIELD_NAME = os.getenv("YOUTRACK_DIRECTION_FIELD_NAME", "Направление")
YOUTRACK_BUSINESS_KEY_CHANGED_FIELD_NAME = os.getenv("YOUTRACK_BUSINESS_KEY_CHANGED_FIELD_NAME", "Меняется бизнес-ключ")

# Debug defaults. Edit these values directly and run the script without arguments.
DEBUG_CONFIG = {
    "summary": "[DEBUG] Prototype Review issue",
    "description": "",
    "project": YOUTRACK_PROJECT,
    "project_id": YOUTRACK_PROJECT_ID,
    "queue": YOUTRACK_QUEUE,
    "issue_type": YOUTRACK_ISSUE_TYPE,
    "card_type_field": YOUTRACK_CARD_TYPE_FIELD_NAME,
    "card_type_value": YOUTRACK_CARD_TYPE_VALUE,
    "assignee_field": YOUTRACK_ASSIGNEE_FIELD_NAME,
    "assignee_query": YOUTRACK_ASSIGNEE_QUERY,
    "estimate_field": YOUTRACK_ESTIMATE_FIELD_NAME,
    "estimate_minutes": YOUTRACK_DEFAULT_ESTIMATE_MINUTES,
    "release_date_field": YOUTRACK_RELEASE_DATE_FIELD_NAME,
    "release_date": date.today().isoformat(),
    "direction_field": YOUTRACK_DIRECTION_FIELD_NAME,
    "direction": "TECH",
    "business_key_changed_field": YOUTRACK_BUSINESS_KEY_CHANGED_FIELD_NAME,
    "business_key_changed": False,
    "enable_card_type": True,
    "enable_assignee": True,
    "enable_estimate": True,
    "enable_release_date": True,
    "enable_direction": True,
    "enable_business_key_changed": True,
    "list_fields": False,
    "dry_run": False,
    "probe_permissions": True,
    "use_sample_cards": True,
}

SAMPLE_REVIEW_ITEMS = [
    {
        "target_fqn": "dm.sales_pricing_documents",
        "object_type": "TABLE",
        "entity_name": "DM_SALES_PRICING_DOCUMENTS",
        "key_attributes": ["doc_id", "line_id"],
        "row_count": 128745,
        "duplicate_groups": 0,
        "duration_sec": 38.412,
        "dependencies": ["ods.sales_documents", "dds.sales_pricing"],
    },
    {
        "target_fqn": "dm_view.sales_pricing_documents",
        "object_type": "VIEW",
        "entity_name": "DM_VIEW_SALES_PRICING_DOCUMENTS",
        "key_attributes": [],
        "row_count": 128745,
        "duplicate_groups": None,
        "duration_sec": 1.287,
        "dependencies": ["dm.sales_pricing_documents"],
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Создать тестовую задачу в YouTrack и отладить custom field оценки."
    )
    parser.add_argument("--summary", default=DEBUG_CONFIG["summary"], help="Заголовок задачи.")
    parser.add_argument("--description", default=DEBUG_CONFIG["description"], help="Описание задачи.")
    parser.add_argument("--project", default=DEBUG_CONFIG["project"], help="Project shortName/name.")
    parser.add_argument("--project-id", default=DEBUG_CONFIG["project_id"], help="Project id, если известен.")
    parser.add_argument("--queue", default=DEBUG_CONFIG["queue"], help="Queue проекта.")
    parser.add_argument("--issue-type", default=DEBUG_CONFIG["issue_type"], help="Тип задачи.")
    parser.add_argument("--card-type-field", default=DEBUG_CONFIG["card_type_field"], help="Имя поля типа карточки.")
    parser.add_argument("--card-type-value", default=DEBUG_CONFIG["card_type_value"], help="Значение типа карточки.")
    parser.add_argument("--assignee-field", default=DEBUG_CONFIG["assignee_field"], help="Имя поля исполнителя.")
    parser.add_argument("--assignee-query", default=DEBUG_CONFIG["assignee_query"], help="Поиск пользователя в YouTrack.")
    parser.add_argument(
        "--estimate-field",
        default=DEBUG_CONFIG["estimate_field"],
        help="Точное имя поля оценки.",
    )
    parser.add_argument(
        "--estimate-minutes",
        type=int,
        default=DEBUG_CONFIG["estimate_minutes"],
        help="Оценка в минутах.",
    )
    parser.add_argument(
        "--disable-estimate",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_estimate"]),
        help="Не отправлять custom field оценки.",
    )
    parser.add_argument(
        "--disable-card-type",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_card_type"]),
        help="Не отправлять поле типа карточки.",
    )
    parser.add_argument(
        "--disable-assignee",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_assignee"]),
        help="Не отправлять поле исполнителя.",
    )
    parser.add_argument("--release-date-field", default=DEBUG_CONFIG["release_date_field"], help="Имя поля даты релиза.")
    parser.add_argument("--release-date", default=DEBUG_CONFIG["release_date"], help="Дата релиза в формате YYYY-MM-DD.")
    parser.add_argument(
        "--disable-release-date",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_release_date"]),
        help="Не отправлять поле даты релиза.",
    )
    parser.add_argument("--direction-field", default=DEBUG_CONFIG["direction_field"], help="Имя поля направления.")
    parser.add_argument("--direction", default=DEBUG_CONFIG["direction"], help="Значение направления.")
    parser.add_argument(
        "--disable-direction",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_direction"]),
        help="Не отправлять поле направления.",
    )
    parser.add_argument(
        "--business-key-changed-field",
        default=DEBUG_CONFIG["business_key_changed_field"],
        help="Имя поля флага изменения бизнес-ключа.",
    )
    parser.add_argument(
        "--business-key-changed",
        default="Да" if DEBUG_CONFIG["business_key_changed"] else "Нет",
        help="Значение поля бизнес-ключа: Да/Нет.",
    )
    parser.add_argument(
        "--disable-business-key-changed",
        action="store_true",
        default=not bool(DEBUG_CONFIG["enable_business_key_changed"]),
        help="Не отправлять поле изменения бизнес-ключа.",
    )
    parser.add_argument(
        "--list-fields",
        action="store_true",
        default=bool(DEBUG_CONFIG["list_fields"]),
        help="Только вывести custom fields проекта и выйти.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=bool(DEBUG_CONFIG["dry_run"]),
        help="Не отправлять POST, только показать итоговый payload.",
    )
    parser.add_argument(
        "--probe-permissions",
        action="store_true",
        default=bool(DEBUG_CONFIG["probe_permissions"]),
        help="При 403 проверить, какое custom field ломает создание.",
    )
    parser.add_argument(
        "--no-sample-cards",
        action="store_true",
        default=not bool(DEBUG_CONFIG["use_sample_cards"]),
        help="Не добавлять тестовые карточки prototype review в описание.",
    )
    parser.add_argument(
        "--probe-field-values",
        default="",
        help="Имя custom field для перебора bundle-значений и форматов payload.",
    )
    return parser.parse_args()


def headers() -> dict[str, str]:
    if not YOUTRACK_TOKEN:
        raise SystemExit("Нужен YOUTRACK_TOKEN в env или api/.env")
    return {
        "Accept": "application/json",
        "Authorization": f"Bearer {YOUTRACK_TOKEN}",
    }


def api_get(path: str, params: dict[str, Any] | None = None) -> Any:
    resp = requests.get(
        f"{YOUTRACK_URL}{path}",
        headers=headers(),
        params=params,
        verify=YOUTRACK_SSL_VERIFY,
        timeout=90,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"GET {path} -> {resp.status_code}: {resp.text[:2000]}")
    return resp.json()


def api_post(path: str, payload: dict[str, Any]) -> Any:
    resp = requests.post(
        f"{YOUTRACK_URL}{path}",
        headers={**headers(), "Content-Type": "application/json"},
        json=payload,
        verify=YOUTRACK_SSL_VERIFY,
        timeout=90,
    )
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"POST {path} -> {resp.status_code}: {resp.text[:4000]}")
    return resp.json() if resp.text.strip() else {}


def api_post_raw(path: str, payload: dict[str, Any]) -> requests.Response:
    return requests.post(
        f"{YOUTRACK_URL}{path}",
        headers={**headers(), "Content-Type": "application/json"},
        json=payload,
        verify=YOUTRACK_SSL_VERIFY,
        timeout=90,
    )


def resolve_project_id(project: str, project_id: str) -> str:
    explicit = str(project_id or "").strip()
    if explicit:
        return explicit
    project_value = str(project or "").strip()
    if not project_value:
        raise SystemExit("Нужен --project или --project-id")
    if "-" in project_value and project_value.replace("-", "").isdigit():
        return project_value

    items = api_get("/api/admin/projects", {"fields": "id,shortName,name"}) or []
    project_value_lower = project_value.lower()
    for item in items:
        item_id = str(item.get("id") or "").strip()
        short_name = str(item.get("shortName") or "").strip()
        name = str(item.get("name") or "").strip()
        if short_name.lower() == project_value_lower or name.lower() == project_value_lower:
            return item_id
    raise SystemExit(f"Не найден project.id для `{project_value}`")


def get_project_custom_fields(project_id: str) -> list[dict[str, Any]]:
    return api_get(
        f"/api/admin/projects/{project_id}/customFields",
        {"fields": "id,$type,canBeEmpty,bundle(id),field(id,name,fieldType(id,valueType))"},
    ) or []


def get_bundle_values(bundle_id: str, bundle_type: str = "enum") -> list[dict[str, Any]]:
    bundle = str(bundle_id or "").strip()
    if not bundle:
        return []
    normalized_type_raw = str(bundle_type or "enum").strip()
    normalized_type = {
        "enum": "enum",
        "state": "state",
        "version": "version",
        "ownedfield": "ownedField",
        "ownedField": "ownedField",
        "user": "user",
    }.get(normalized_type_raw, normalized_type_raw)
    return api_get(
        f"/api/admin/customFieldSettings/bundles/{normalized_type}/{bundle}/values",
        {"fields": "id,name,description,isArchived,localizedName,fullName"},
    ) or []


def normalize_issue_custom_field_type(project_field_type: str, field_type_id: str) -> str:
    if project_field_type == "EnumProjectCustomField":
        return "SingleEnumIssueCustomField"
    if project_field_type == "OwnedProjectCustomField":
        return "SingleOwnedIssueCustomField"
    if project_field_type == "UserProjectCustomField":
        return "SingleUserIssueCustomField"
    if project_field_type == "StateProjectCustomField":
        return "StateIssueCustomField"
    if project_field_type == "VersionProjectCustomField":
        return "SingleVersionIssueCustomField"
    if project_field_type.endswith("ProjectCustomField"):
        return f"{project_field_type[:-18]}IssueCustomField"
    if field_type_id == "period":
        return "PeriodIssueCustomField"
    return "SimpleIssueCustomField"


def resolve_estimate_field(items: list[dict[str, Any]], estimate_field_name: str) -> dict[str, Any] | None:
    return resolve_field(items, estimate_field_name, fallback_contains="оценк")


def resolve_field(items: list[dict[str, Any]], field_name_query: str, fallback_contains: str = "") -> dict[str, Any] | None:
    configured = str(field_name_query or "").strip().lower()
    fallback = None
    for item in items:
        field = item.get("field") or {}
        field_name = str(field.get("name") or "").strip()
        if not field_name:
            continue
        if field_name.lower() == configured:
            return item
        if fallback is None and fallback_contains and fallback_contains in field_name.lower():
            fallback = item
    return fallback


def build_estimate_payload(field_item: dict[str, Any], estimate_minutes: int) -> dict[str, Any]:
    field = field_item.get("field") or {}
    field_name = str(field.get("name") or "").strip()
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    field_value_type = str(field_type.get("valueType") or field_type.get("id") or "").strip().lower()
    issue_custom_field_type = normalize_issue_custom_field_type(
        str(field_item.get("$type") or "").strip(),
        field_type_id,
    )

    if field_value_type == "period" or issue_custom_field_type == "PeriodIssueCustomField":
        value: Any = {"minutes": estimate_minutes}
    elif field_value_type in {"integer", "int"}:
        value = estimate_minutes
    else:
        hours = estimate_minutes / 60
        value = f"{int(hours) if hours.is_integer() else hours}ч"

    payload = {
        "id": str(field_item.get("id") or "").strip(),
        "name": field_name,
        "$type": issue_custom_field_type,
        "value": value,
    }
    return payload


def build_named_value_payload(field_item: dict[str, Any], raw_value: str) -> dict[str, Any]:
    field = field_item.get("field") or {}
    field_name = str(field.get("name") or "").strip()
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    issue_custom_field_type = normalize_issue_custom_field_type(
        str(field_item.get("$type") or "").strip(),
        field_type_id,
    )
    payload = {
        "id": str(field_item.get("id") or "").strip(),
        "name": field_name,
        "$type": issue_custom_field_type,
        "value": {"name": raw_value},
    }
    return payload


def build_named_id_payload(field_item: dict[str, Any], raw_id: str, raw_name: str = "") -> dict[str, Any]:
    field = field_item.get("field") or {}
    field_name = str(field.get("name") or "").strip()
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    issue_custom_field_type = normalize_issue_custom_field_type(
        str(field_item.get("$type") or "").strip(),
        field_type_id,
    )
    value: dict[str, Any] = {"id": str(raw_id).strip()}
    if str(raw_name or "").strip():
        value["name"] = str(raw_name).strip()
    return {
        "id": str(field_item.get("id") or "").strip(),
        "name": field_name,
        "$type": issue_custom_field_type,
        "value": value,
    }


def resolve_user(user_query: str) -> dict[str, str] | None:
    query = str(user_query or "").strip()
    if not query:
        return None
    items = api_get(
        "/api/users",
        {"fields": "id,login,name,fullName,email", "query": query},
    ) or []
    normalized = query.lower()
    for item in items:
        login = str(item.get("login") or "").strip()
        name = str(item.get("name") or "").strip()
        full_name = str(item.get("fullName") or "").strip()
        email = str(item.get("email") or "").strip()
        if normalized in {login.lower(), name.lower(), full_name.lower(), email.lower()}:
            return {"login": login} if login else {"name": full_name or name}
    first = (items or [None])[0]
    if not first:
        return None
    login = str(first.get("login") or "").strip()
    name = str(first.get("fullName") or first.get("name") or "").strip()
    return {"login": login} if login else {"name": name} if name else None


def build_user_payload(field_item: dict[str, Any], user_value: dict[str, str]) -> dict[str, Any]:
    field = field_item.get("field") or {}
    field_name = str(field.get("name") or "").strip()
    payload = {
        "id": str(field_item.get("id") or "").strip(),
        "name": field_name,
        "$type": "SingleUserIssueCustomField",
        "value": user_value,
    }
    return payload


def normalize_bool_text(value: str, default: bool = False) -> bool:
    text = str(value or "").strip().lower()
    if not text:
        return default
    return text in {"1", "true", "yes", "y", "да"}


def parse_date_value(raw_value: str) -> int:
    text = str(raw_value or "").strip()
    if not text:
        raise ValueError("Пустая дата для custom field")
    for fmt in ("%Y-%m-%d", "%d.%m.%Y"):
        try:
            import time
            parsed = time.strptime(text, fmt)
            return int(time.mktime(parsed)) * 1000
        except ValueError:
            continue
    raise ValueError(f"Не удалось распознать дату `{text}`")


def build_value_payload(field_item: dict[str, Any], raw_value: Any) -> dict[str, Any]:
    field = field_item.get("field") or {}
    field_name = str(field.get("name") or "").strip()
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    field_value_type = str(field_type.get("valueType") or field_type.get("id") or "").strip().lower()
    issue_custom_field_type = normalize_issue_custom_field_type(
        str(field_item.get("$type") or "").strip(),
        field_type_id,
    )
    if issue_custom_field_type in {
        "SingleEnumIssueCustomField",
        "SingleOwnedIssueCustomField",
        "StateIssueCustomField",
        "SingleVersionIssueCustomField",
    }:
        value = {"name": str(raw_value).strip()}
    elif issue_custom_field_type == "PeriodIssueCustomField" or field_value_type == "period":
        value = {"minutes": int(raw_value)}
    elif field_value_type in {"date", "datetime", "date and time"} or issue_custom_field_type in {"DateIssueCustomField", "DateTimeIssueCustomField"}:
        value = parse_date_value(str(raw_value))
    elif field_value_type in {"boolean", "bool"} or issue_custom_field_type == "BooleanIssueCustomField":
        value = normalize_bool_text(str(raw_value), default=False)
    elif field_value_type in {"integer", "int"}:
        value = int(raw_value)
    else:
        value = raw_value
    return {
        "id": str(field_item.get("id") or "").strip(),
        "name": field_name,
        "$type": issue_custom_field_type,
        "value": value,
    }


def build_sample_description(use_sample_cards: bool) -> str:
    lines = [
        "Отладочная задача для проверки создания issue из prototype review.",
        "",
        "Поля и карточки заполнены тестовыми значениями.",
    ]
    if not use_sample_cards:
        return "\n".join(lines)
    lines.extend(["", "## Карточки prototype review"])
    for item in SAMPLE_REVIEW_ITEMS:
        object_type = str(item.get("object_type") or "TABLE").upper()
        row_count = item.get("row_count")
        duplicate_groups = item.get("duplicate_groups")
        duration_sec = item.get("duration_sec")
        dependencies = item.get("dependencies") or []
        lines.extend(
            [
                "",
                f"### {item.get('target_fqn')}",
                f"- Тип: {object_type}",
                f"- Сущность: {item.get('entity_name') or '—'}",
                f"- Ключевые поля: {', '.join(item.get('key_attributes') or []) or '—'}",
                f"- Количество строк: {row_count if row_count is not None else '—'}",
                f"- Кол-во дублей: {duplicate_groups if duplicate_groups is not None else '—'}",
                f"- Время SQL: {duration_sec if duration_sec is not None else '—'} сек",
            ]
        )
        if dependencies:
            lines.append(f"- Зависимости: {', '.join(dependencies)}")
    return "\n".join(lines)


def summarize_custom_fields(custom_fields: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result = []
    for item in custom_fields:
        result.append(
            {
                "name": item.get("name"),
                "id": item.get("id"),
                "$type": item.get("$type"),
                "value": item.get("value"),
            }
        )
    return result


def print_bundle_values(field_label: str, field_item: dict[str, Any]) -> None:
    bundle = field_item.get("bundle") or {}
    bundle_id = str(bundle.get("id") or "").strip()
    if not bundle_id:
        return
    field = field_item.get("field") or {}
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    bundle_type = field_type_id.split("[", 1)[0] if "[" in field_type_id else field_type_id
    if not bundle_type:
        return
    print()
    print(f"Values for `{field_label}` (bundle `{bundle_id}`, type `{bundle_type}`):")
    try:
        values = get_bundle_values(bundle_id, bundle_type=bundle_type)
    except Exception as exc:
        print(f"Failed to load bundle values: {exc}", file=sys.stderr)
        return
    for item in values:
        print(
            json.dumps(
                {
                    "id": item.get("id"),
                    "name": item.get("name"),
                    "localizedName": item.get("localizedName"),
                    "fullName": item.get("fullName"),
                    "description": item.get("description"),
                    "isArchived": item.get("isArchived"),
                },
                ensure_ascii=False,
            )
        )


def probe_named_field_values(
    *,
    payload: dict[str, Any],
    field_item: dict[str, Any],
    field_name: str,
    requested_value: str,
) -> int:
    bundle = field_item.get("bundle") or {}
    bundle_id = str(bundle.get("id") or "").strip()
    field = field_item.get("field") or {}
    field_type = field.get("fieldType") or {}
    field_type_id = str(field_type.get("id") or field_type.get("valueType") or "").strip().lower()
    bundle_type = field_type_id.split("[", 1)[0] if "[" in field_type_id else field_type_id
    if not bundle_id or not bundle_type:
        print(f"Field `{field_name}` has no bundle metadata to probe.", file=sys.stderr)
        return 2
    try:
        bundle_values = get_bundle_values(bundle_id, bundle_type=bundle_type)
    except Exception as exc:
        print(f"Failed to load bundle values for `{field_name}`: {exc}", file=sys.stderr)
        return 2

    print()
    print(f"Probe values for `{field_name}`:")
    print(f"Requested value: {requested_value}")
    print(f"Bundle id: {bundle_id}")
    print(f"Bundle type: {bundle_type}")
    print(f"Available values: {len(bundle_values)}")
    for item in bundle_values:
        print(
            json.dumps(
                {
                    "id": item.get("id"),
                    "name": item.get("name"),
                    "localizedName": item.get("localizedName"),
                    "fullName": item.get("fullName"),
                },
                ensure_ascii=False,
            )
        )

    base_payload = dict(payload)
    custom_fields = [dict(item) for item in (payload.get("customFields") or [])]
    filtered_custom_fields = [item for item in custom_fields if str(item.get("name") or "").strip() != field_name]
    base_payload["customFields"] = filtered_custom_fields

    print()
    print("Control probe without this field:")
    control = api_post_raw("/api/issues", base_payload)
    print(f"status={control.status_code}")
    print(control.text[:1000])

    matched_values = []
    requested_lower = str(requested_value or "").strip().lower()
    for item in bundle_values:
        candidates = {
            str(item.get("name") or "").strip().lower(),
            str(item.get("localizedName") or "").strip().lower(),
            str(item.get("fullName") or "").strip().lower(),
        }
        if requested_lower and requested_lower in candidates:
            matched_values.append(item)

    if requested_lower and not matched_values:
        print()
        print(f"Requested value `{requested_value}` was not found in bundle values.", file=sys.stderr)

    for item in bundle_values:
        item_id = str(item.get("id") or "").strip()
        item_name = str(item.get("name") or "").strip()
        item_localized_name = str(item.get("localizedName") or "").strip()
        for label, candidate_payload in (
            ("name", build_named_value_payload(field_item, item_name)),
            ("id", build_named_id_payload(field_item, item_id, item_name)),
        ):
            probe_payload = dict(base_payload)
            probe_payload["customFields"] = [*filtered_custom_fields, candidate_payload]
            response = api_post_raw("/api/issues", probe_payload)
            print()
            print(
                json.dumps(
                    {
                        "probe_format": label,
                        "bundle_value_id": item_id,
                        "bundle_value_name": item_name,
                        "bundle_value_localized_name": item_localized_name,
                        "status_code": response.status_code,
                        "response": response.text[:1000],
                    },
                    ensure_ascii=False,
                )
            )
    return 0


def probe_permissions(payload: dict[str, Any]) -> int:
    response = api_post_raw("/api/issues", payload)
    if response.status_code in (200, 201):
        print("CREATE OK:")
        print(json.dumps(response.json() if response.text.strip() else {}, ensure_ascii=False, indent=2))
        return 0

    print(f"CREATE ERROR: POST /api/issues -> {response.status_code}: {response.text[:4000]}", file=sys.stderr)
    if response.status_code != 403:
        return 1

    custom_fields = list(payload.get("customFields") or [])
    if not custom_fields:
        return 1

    print("\nPermission probe:", file=sys.stderr)
    print("Full customFields payload:", file=sys.stderr)
    print(json.dumps(summarize_custom_fields(custom_fields), ensure_ascii=False, indent=2), file=sys.stderr)

    offenders: list[str] = []
    for field in custom_fields:
        field_name = str(field.get("name") or field.get("id") or "unknown").strip()
        probe_payload = dict(payload)
        probe_payload["customFields"] = [item for item in custom_fields if item is not field]
        probe_response = api_post_raw("/api/issues", probe_payload)
        if probe_response.status_code in (200, 201):
            offenders.append(field_name)
            print(f"- Поле `{field_name}` выглядит проблемным: без него задача создаётся.", file=sys.stderr)
            print(json.dumps(probe_response.json() if probe_response.text.strip() else {}, ensure_ascii=False, indent=2), file=sys.stderr)
        else:
            print(
                f"- Без поля `{field_name}` всё ещё ошибка {probe_response.status_code}: {probe_response.text[:1000]}",
                file=sys.stderr,
            )
    return 1


def print_fields(items: list[dict[str, Any]], estimate_field_name: str) -> None:
    print("Project custom fields:")
    for item in items:
        field = item.get("field") or {}
        field_name = str(field.get("name") or "").strip()
        field_type = field.get("fieldType") or {}
        bundle = item.get("bundle") or {}
        marker = " <==" if field_name.lower() == estimate_field_name.lower() else ""
        print(
            json.dumps(
                {
                    "id": item.get("id"),
                    "project_field_type": item.get("$type"),
                    "canBeEmpty": item.get("canBeEmpty"),
                    "bundle_id": bundle.get("id"),
                    "field_name": field_name,
                    "field_type_id": field_type.get("id"),
                    "field_value_type": field_type.get("valueType"),
                },
                ensure_ascii=False,
            ) + marker
        )


def main() -> int:
    args = parse_args()
    project_id = resolve_project_id(args.project, args.project_id)
    fields = get_project_custom_fields(project_id)

    print(f"YOUTRACK_URL={YOUTRACK_URL}")
    print(f"project_id={project_id}")
    print(f"queue={args.queue}")
    print(f"issue_type={args.issue_type}")
    print(f"card_type_field={args.card_type_field}")
    print(f"card_type_value={args.card_type_value}")
    print(f"assignee_field={args.assignee_field}")
    print(f"assignee_query={args.assignee_query}")
    print(f"estimate_field={args.estimate_field}")
    print(f"estimate_minutes={args.estimate_minutes}")
    print(f"release_date_field={args.release_date_field}")
    print(f"release_date={args.release_date}")
    print(f"direction_field={args.direction_field}")
    print(f"direction={args.direction}")
    print(f"business_key_changed_field={args.business_key_changed_field}")
    print(f"business_key_changed={args.business_key_changed}")
    print(f"enable_card_type={not args.disable_card_type}")
    print(f"enable_assignee={not args.disable_assignee}")
    print(f"enable_estimate={not args.disable_estimate}")
    print(f"enable_release_date={not args.disable_release_date}")
    print(f"enable_direction={not args.disable_direction}")
    print(f"enable_business_key_changed={not args.disable_business_key_changed}")
    print(f"probe_permissions={bool(args.probe_permissions)}")
    print()
    print_fields(fields, args.estimate_field)

    card_type_field = resolve_field(fields, args.card_type_field)
    if card_type_field:
        print_bundle_values(args.card_type_field, card_type_field)
    direction_field_meta = resolve_field(fields, args.direction_field, fallback_contains="направлен")
    if direction_field_meta:
        print_bundle_values(args.direction_field, direction_field_meta)

    if args.list_fields:
        return 0

    payload: dict[str, Any] = {
        "project": {"id": project_id},
        "queue": args.queue,
        "summary": args.summary,
        "description": args.description or build_sample_description(not args.no_sample_cards),
        "type": args.issue_type,
    }

    custom_fields = []

    if not args.disable_estimate:
        estimate_field = resolve_estimate_field(fields, args.estimate_field)
        if not estimate_field:
            print()
            print("Не найдено поле оценки в custom fields проекта.", file=sys.stderr)
            return 2
        custom_fields.append(build_estimate_payload(estimate_field, max(1, args.estimate_minutes)))

    if not args.disable_card_type:
        card_type_field = resolve_field(fields, args.card_type_field)
        if not card_type_field:
            print()
            print("Не найдено поле типа карточки в custom fields проекта.", file=sys.stderr)
            return 2
        custom_fields.append(build_named_value_payload(card_type_field, str(args.card_type_value).strip()))

    if not args.disable_assignee:
        assignee_field = resolve_field(fields, args.assignee_field)
        if not assignee_field:
            print()
            print("Не найдено поле исполнителя в custom fields проекта.", file=sys.stderr)
            return 2
        user_value = resolve_user(args.assignee_query)
        if not user_value:
            print()
            print("Не найден пользователь для поля исполнителя.", file=sys.stderr)
            return 2
        custom_fields.append(build_user_payload(assignee_field, user_value))

    if not args.disable_release_date and str(args.release_date or "").strip():
        release_date_field = resolve_field(fields, args.release_date_field, fallback_contains="дата релиз")
        if not release_date_field:
            print()
            print("Не найдено поле даты релиза в custom fields проекта.", file=sys.stderr)
            return 2
        custom_fields.append(build_value_payload(release_date_field, str(args.release_date).strip()))

    if not args.disable_direction and str(args.direction or "").strip():
        direction_field = resolve_field(fields, args.direction_field, fallback_contains="направлен")
        if not direction_field:
            print()
            print("Не найдено поле направления в custom fields проекта.", file=sys.stderr)
            return 2
        custom_fields.append(build_value_payload(direction_field, str(args.direction).strip()))

    if not args.disable_business_key_changed:
        business_key_changed_field = resolve_field(fields, args.business_key_changed_field, fallback_contains="бизнес-ключ")
        if not business_key_changed_field:
            print()
            print("Не найдено поле флага бизнес-ключа в custom fields проекта.", file=sys.stderr)
            return 2
        custom_fields.append(build_value_payload(business_key_changed_field, str(args.business_key_changed).strip()))

    if custom_fields:
        payload["customFields"] = custom_fields

    print()
    print("POST /api/issues payload:")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if args.dry_run:
        return 0

    probe_field_name = str(args.probe_field_values or "").strip()
    if probe_field_name:
        target_field = resolve_field(fields, probe_field_name)
        if not target_field:
            print(f"Не найдено поле `{probe_field_name}` в custom fields проекта.", file=sys.stderr)
            return 2
        requested_value = ""
        if probe_field_name.lower() == str(args.direction_field or "").strip().lower():
            requested_value = str(args.direction or "").strip()
        elif probe_field_name.lower() == str(args.card_type_field or "").strip().lower():
            requested_value = str(args.card_type_value or "").strip()
        elif probe_field_name.lower() == str(args.business_key_changed_field or "").strip().lower():
            requested_value = str(args.business_key_changed or "").strip()
        return probe_named_field_values(
            payload=payload,
            field_item=target_field,
            field_name=str((target_field.get("field") or {}).get("name") or probe_field_name).strip(),
            requested_value=requested_value,
        )

    print()
    if args.probe_permissions:
        return probe_permissions(payload)

    try:
        result = api_post("/api/issues", payload)
    except Exception as exc:
        print(f"CREATE ERROR: {exc}", file=sys.stderr)
        return 1

    print("CREATE OK:")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
