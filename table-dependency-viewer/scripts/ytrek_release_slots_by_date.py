#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
from datetime import datetime, timezone

import requests
import urllib3
from dotenv import load_dotenv

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

load_dotenv()

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru").rstrip("/")
YOUTRACK_TOKEN = os.getenv("YOUTRACK_TOKEN", "")
PAGE_SIZE = int(os.getenv("YOUTRACK_PAGE_SIZE", "100"))

ISSUE_FIELDS = (
    "id,idReadable,summary,created,updated,resolved,"
    "customFields(id,name,$type,value(id,name,text,presentation)),"  # release date lives here
    "links(direction,linkType(name,localizedSourceToTarget,localizedTargetToSource),issues(id,idReadable,summary))"
)

RELEASE_DATE_FIELD_NAMES = {
    "фактическая дата релиза",
    "actual release date",
}
ISSUE_TYPE_FIELD_NAMES = {
    "тип карточки",
    "type",
}
RELEASE_SLOT_TYPE_NAMES = {
    "release slot",
}
ISSUE_KEY_RE = re.compile(r"^[A-Z][A-Z0-9_]+-\d+$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Вывести Release Slot задачи и связанные issue IDs за дату релиза"
    )
    parser.add_argument(
        "--date",
        default=datetime.now().strftime("%Y-%m-%d"),
        help="Дата релиза в формате YYYY-MM-DD. По умолчанию сегодня.",
    )
    parser.add_argument(
        "--query",
        default="",
        help="Необязательный YouTrack query. Если пусто, скрипт сам попробует несколько вариантов поиска release slot.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=500,
        help="Лимит найденных release slot карточек до локальной фильтрации.",
    )
    return parser.parse_args()


def headers() -> dict[str, str]:
    if not YOUTRACK_TOKEN:
        raise SystemExit("Нужен YOUTRACK_TOKEN в env или .env")
    return {
        "Accept": "application/json",
        "Authorization": f"Bearer {YOUTRACK_TOKEN}",
    }


def api_get(path: str, params: dict | None = None) -> object:
    resp = requests.get(
        f"{YOUTRACK_URL}{path}",
        headers=headers(),
        params=params,
        verify=False,
        timeout=90,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"API {path} -> {resp.status_code}: {resp.text[:500]}")
    return resp.json()


def search_issues(query: str, top_limit: int) -> list[dict]:
    issues: list[dict] = []
    skip = 0
    while True:
        batch = api_get(
            "/api/issues",
            {
                "query": query,
                "$top": min(PAGE_SIZE, top_limit - len(issues)),
                "$skip": skip,
                "fields": ISSUE_FIELDS,
            },
        ) or []
        if not batch:
            break
        issues.extend(batch)
        if len(batch) < PAGE_SIZE or len(issues) >= top_limit:
            break
        skip += PAGE_SIZE
    return issues[:top_limit]


def merge_unique_issues(*groups: list[dict]) -> list[dict]:
    seen: set[str] = set()
    merged: list[dict] = []
    for group in groups:
        for issue in group:
            key = str(issue.get("id") or issue.get("idReadable") or "").strip()
            if not key or key in seen:
                continue
            seen.add(key)
            merged.append(issue)
    return merged


def normalize_cf_name(value: str) -> str:
    return " ".join(str(value or "").strip().lower().split())


def extract_date_value(raw_value) -> str | None:
    if raw_value in (None, "", {}):
        return None
    if isinstance(raw_value, int):
        dt = datetime.fromtimestamp(raw_value / 1000, tz=timezone.utc)
        return dt.date().isoformat()
    if isinstance(raw_value, str):
        text = raw_value.strip()
        if re.match(r"^\d{4}-\d{2}-\d{2}$", text):
            return text
        if re.match(r"^\d{2}\.\d{2}\.\d{4}$", text):
            day, month, year = text.split(".")
            return f"{year}-{month}-{day}"
        return None
    if isinstance(raw_value, dict):
        presentation = str(raw_value.get("presentation") or raw_value.get("name") or raw_value.get("text") or "").strip()
        if presentation:
            parsed = extract_date_value(presentation)
            if parsed:
                return parsed
        if raw_value.get("id") and str(raw_value.get("id")).isdigit():
            return extract_date_value(int(raw_value["id"]))
    return None


def issue_release_date(issue: dict) -> str | None:
    for field in issue.get("customFields") or []:
        if normalize_cf_name(field.get("name")) in RELEASE_DATE_FIELD_NAMES:
            return extract_date_value(field.get("value"))
    return None


def issue_type_name(issue: dict) -> str | None:
    for field in issue.get("customFields") or []:
        if normalize_cf_name(field.get("name")) in ISSUE_TYPE_FIELD_NAMES:
            value = field.get("value")
            if isinstance(value, dict):
                text = str(value.get("name") or value.get("text") or value.get("presentation") or "").strip()
                return text.lower() if text else None
            if isinstance(value, str):
                text = value.strip()
                return text.lower() if text else None
    return None


def is_release_slot(issue: dict) -> bool:
    issue_type = issue_type_name(issue)
    if issue_type and issue_type in RELEASE_SLOT_TYPE_NAMES:
        return True
    summary = str(issue.get("summary") or "").lower()
    return "релиз" in summary


def extract_linked_issue_ids(issue: dict) -> list[str]:
    found: set[str] = set()
    for link in issue.get("links") or []:
        for linked_issue in link.get("issues") or []:
            readable = str(linked_issue.get("idReadable") or "").strip()
            if readable and ISSUE_KEY_RE.match(readable):
                found.add(readable)
    return sorted(found)


def fetch_candidate_release_slots(query: str, top_limit: int) -> tuple[list[dict], list[str]]:
    if query.strip():
        return search_issues(query.strip(), top_limit), [query.strip()]

    candidates = [
        "Type: {Release Slot}",
        "Тип карточки: {Release Slot}",
        'summary: Релиз',
        'summary: Release',
    ]
    batches: list[list[dict]] = []
    used_queries: list[str] = []
    for candidate in candidates:
        try:
            batch = search_issues(candidate, top_limit)
        except Exception:
            continue
        used_queries.append(candidate)
        batches.append(batch)
    return merge_unique_issues(*batches), used_queries


def main() -> int:
    args = parse_args()
    try:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date().isoformat()
    except ValueError as exc:
        raise SystemExit(f"Неверная дата `{args.date}`. Нужен формат YYYY-MM-DD.") from exc

    issues, used_queries = fetch_candidate_release_slots(args.query, args.top)
    matched = [issue for issue in issues if is_release_slot(issue) and issue_release_date(issue) == target_date]

    print(f"Дата релиза: {target_date}")
    if used_queries:
        print(f"Использованы query: {', '.join(used_queries)}")
    print(f"Кандидатов найдено: {len(issues)}")
    print(f"Найдено Release Slot карточек: {len(matched)}")
    print("")

    if not matched:
        return 0

    all_related: set[str] = set()
    for issue in matched:
        issue_id = issue.get("idReadable") or "<unknown>"
        summary = (issue.get("summary") or "").strip()
        related = extract_linked_issue_ids(issue)
        all_related.update(related)

        print(f"{issue_id} | {summary}")
        print(f"  release_date: {issue_release_date(issue) or '-'}")
        print(f"  linked: {', '.join(related) if related else '-'}")
        print("")

    print("Все связанные задачи:")
    if all_related:
        for key in sorted(all_related):
            print(key)
    else:
        print("-")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
