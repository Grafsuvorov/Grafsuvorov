#!/usr/bin/env python3
"""Debug helper for creating one YouTrack issue directly via API."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

import requests
import urllib3
from dotenv import load_dotenv

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

# Debug defaults. Edit these values directly and run the script without arguments.
DEBUG_CONFIG = {
    "summary": "Debug issue from API",
    "description": "Created by debug script.",
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
    "enable_card_type": True,
    "enable_assignee": True,
    "enable_estimate": True,
    "list_fields": False,
    "dry_run": False,
}


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


def get_bundle_values(bundle_id: str) -> list[dict[str, Any]]:
    bundle = str(bundle_id or "").strip()
    if not bundle:
        return []
    return api_get(
        f"/api/admin/customFieldSettings/bundles/enum/{bundle}/values",
        {"fields": "id,name,description,isArchived"},
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
    print(f"enable_card_type={not args.disable_card_type}")
    print(f"enable_assignee={not args.disable_assignee}")
    print(f"enable_estimate={not args.disable_estimate}")
    print()
    print_fields(fields, args.estimate_field)

    card_type_field = resolve_field(fields, args.card_type_field)
    if card_type_field:
        bundle = card_type_field.get("bundle") or {}
        bundle_id = str(bundle.get("id") or "").strip()
        if bundle_id:
            print()
            print(f"Enum values for `{args.card_type_field}` (bundle `{bundle_id}`):")
            try:
                values = get_bundle_values(bundle_id)
            except Exception as exc:
                print(f"Failed to load enum values: {exc}", file=sys.stderr)
                values = []
            for item in values:
                print(
                    json.dumps(
                        {
                            "id": item.get("id"),
                            "name": item.get("name"),
                            "description": item.get("description"),
                            "isArchived": item.get("isArchived"),
                        },
                        ensure_ascii=False,
                    )
                )

    if args.list_fields:
        return 0

    payload: dict[str, Any] = {
        "project": {"id": project_id},
        "queue": args.queue,
        "summary": args.summary,
        "description": args.description,
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

    if custom_fields:
        payload["customFields"] = custom_fields

    print()
    print("POST /api/issues payload:")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    if args.dry_run:
        return 0

    print()
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
