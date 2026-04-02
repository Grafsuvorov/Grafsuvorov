#!/usr/bin/env python3
"""Load YouTrack tasks for one employee directly from API."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
import urllib3
from dotenv import load_dotenv

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru").rstrip("/")
YOUTRACK_TOKEN = os.getenv("YOUTRACK_TOKEN", "")
PAGE_SIZE = int(os.getenv("YOUTRACK_PAGE_SIZE", "100"))

ISSUE_FIELDS = (
    "id,idReadable,summary,description,project(name,key),"
    "customFields(id,name,$type,value(id,name,login,fullName,text,presentation)),"
    "reporter(login,name,fullName),assignee(login,name,fullName),"
    "created,updated,resolved"
)
ACTIVITY_FIELDS = "author(name,login,fullName),timestamp,field(name),added(name,login,fullName),removed(name,login,fullName),to(name,login,fullName)"
ACTIVITY_CATEGORIES = "CustomFieldCategory,CommentsCategory,WorkItemCategory"
WORKITEM_FIELDS = "author(name,login,fullName),creator(name,login,fullName),date,duration(minutes),text,workType(name)"
COMMENT_FIELDS = "author(name,login,fullName),created,text"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Выгрузить из YouTrack все задачи сотрудника по почте за период"
    )
    parser.add_argument("email", help="Почта сотрудника, например ivan.ivanov@rusal.com")
    parser.add_argument(
        "--login",
        type=str,
        default="",
        help="Логин YouTrack. Если известен, лучше передавать его явно.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=30,
        help="Окно в днях назад. По умолчанию 30.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=500,
        help="Лимит найденных задач после фильтрации. По умолчанию 500.",
    )
    parser.add_argument(
        "--mode",
        choices=("assignee", "all"),
        default="assignee",
        help="assignee = только по исполнителю, all = еще по истории и worklog.",
    )
    parser.add_argument(
        "--format",
        choices=("table", "json", "csv"),
        default="table",
        help="Формат итогового вывода. По умолчанию table.",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="",
        help="Путь для сохранения итогового json/csv.",
    )
    parser.add_argument(
        "--dump-dir",
        type=str,
        default="",
        help="Каталог для raw json по найденным задачам.",
    )
    return parser.parse_args()


def normalize_email(value: str) -> str:
    email = (value or "").strip().lower()
    if "@" not in email:
        raise SystemExit("Нужна именно почта, например ivan.ivanov@rusal.com")
    return email


def build_candidates(email: str) -> list[str]:
    local = email.split("@", 1)[0]
    candidates = {
        email,
        local,
        local.replace(".", "_"),
        local.replace("_", "."),
        re.sub(r"\+.*$", "", local),
    }
    return sorted(x for x in candidates if x)


def build_candidates_from_login(login: str) -> list[str]:
    value = (login or "").strip().lower()
    if not value:
        return []
    return sorted({value, value.replace(".", "_"), value.replace("_", ".")})


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


def fmt_ts(value) -> str | None:
    if not value:
        return None
    try:
        dt = datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
        return dt.astimezone().strftime("%Y-%m-%d %H:%M")
    except Exception:
        return None


def normalize_value(value):
    if isinstance(value, list):
        values = [normalize_value(v) for v in value]
        return ", ".join(str(v) for v in values if v not in (None, "", "None"))
    if isinstance(value, dict):
        for key in ("login", "name", "fullName", "text", "presentation"):
            if value.get(key) not in (None, ""):
                return value.get(key)
        return str(value)
    return value


def get_current_state(custom_fields) -> str | None:
    for cf in custom_fields or []:
        name = str(cf.get("name") or "").lower()
        if name in ("state", "состояние", "статус"):
            return normalize_value(cf.get("value"))
    return None


def resolve_users(email: str, candidates: list[str], login: str = "") -> tuple[list[str], list[dict], list[str]]:
    found = set(candidates)
    queries_tried = []
    raw_users = []
    seen_users = set()

    query_candidates = []
    if login.strip():
        query_candidates.extend(build_candidates_from_login(login))
    query_candidates.extend(candidates)
    query_candidates.append(email)

    for query in query_candidates:
        if not query:
            continue
        queries_tried.append(query)
        try:
            users = api_get(
                "/api/users",
                {
                    "fields": "id,login,name,fullName,email",
                    "query": query,
                },
            ) or []
        except Exception:
            continue

        for user in users:
            user_id = user.get("id")
            if user_id and user_id not in seen_users:
                raw_users.append(user)
                seen_users.add(user_id)
            for key in ("login", "name", "fullName", "email"):
                value = user.get(key)
                if value:
                    found.add(str(value).strip().lower())

    return sorted(x for x in found if x), raw_users, queries_tried


def search_issues(query: str) -> list[dict]:
    issues = []
    skip = 0
    while True:
        batch = api_get(
            "/api/issues",
            {
                "query": query,
                "$top": PAGE_SIZE,
                "$skip": skip,
                "fields": ISSUE_FIELDS,
            },
        ) or []
        if not batch:
            break
        issues.extend(batch)
        if len(batch) < PAGE_SIZE:
            break
        skip += PAGE_SIZE
    return issues


def collect_issue_candidates(identifiers: list[str]) -> tuple[dict[str, dict], list[str]]:
    seen: dict[str, dict] = {}
    queries_used: list[str] = []

    for ident in identifiers:
        for template in (
            "Assignee: {ident}",
            "Assignee: {{{ident}}}",
            "Исполнитель: {ident}",
            "Исполнитель: {{{ident}}}",
        ):
            query = template.format(ident=ident)
            try:
                issues = search_issues(query)
            except Exception:
                continue
            queries_used.append(query)
            for issue in issues:
                readable = issue.get("idReadable")
                if readable and readable not in seen:
                    seen[readable] = issue

    return seen, queries_used


def fetch_issue_details(issue: dict) -> dict:
    issue_id = issue.get("id")
    issue_readable = issue.get("idReadable")
    activities = api_get(
        f"/api/issues/{issue_id}/activities",
        {"fields": ACTIVITY_FIELDS, "categories": ACTIVITY_CATEGORIES},
    ) or []
    workitems = api_get(
        f"/api/issues/{issue_id}/timeTracking/workItems",
        {"fields": WORKITEM_FIELDS},
    ) or []
    comments = api_get(
        f"/api/issues/{issue_id}/comments",
        {"fields": COMMENT_FIELDS},
    ) or []

    custom_map = {}
    for cf in issue.get("customFields") or []:
        name = cf.get("name") or cf.get("id") or "custom"
        custom_map[name] = normalize_value(cf.get("value"))

    return {
        "issue": {
            "issue_id": issue_readable,
            "summary": issue.get("summary"),
            "description": issue.get("description"),
            "project_name": (issue.get("project") or {}).get("name"),
            "project_key": (issue.get("project") or {}).get("key"),
            "created_by": normalize_value(issue.get("reporter") or {}),
            "assignee": normalize_value(issue.get("assignee") or {}),
            "created_at": fmt_ts(issue.get("created")),
            "updated_at": fmt_ts(issue.get("updated")),
            "resolved_at": fmt_ts(issue.get("resolved")),
            "current_state": get_current_state(issue.get("customFields")),
        },
        "custom_fields": custom_map,
        "activities": activities,
        "workitems": workitems,
        "comments": comments,
    }


def parse_ms(value) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
    except Exception:
        return None


def issue_matches_period(bundle: dict, cutoff: datetime) -> bool:
    issue = bundle["issue"]
    for key in ("created_at", "updated_at", "resolved_at"):
        value = issue.get(key)
        if value:
            try:
                dt = datetime.strptime(value, "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc)
                if dt >= cutoff:
                    return True
            except Exception:
                pass

    for activity in bundle.get("activities") or []:
        dt = parse_ms(activity.get("timestamp"))
        if dt and dt >= cutoff:
            return True

    for work in bundle.get("workitems") or []:
        dt = parse_ms(work.get("date"))
        if dt and dt >= cutoff:
            return True

    for comment in bundle.get("comments") or []:
        dt = parse_ms(comment.get("created"))
        if dt and dt >= cutoff:
            return True

    return False


def bundle_roles(bundle: dict, identifiers: set[str], mode: str) -> list[str]:
    roles = []
    issue = bundle["issue"]
    if str(issue.get("assignee") or "").strip().lower() in identifiers:
        roles.append("assignee")

    if mode == "all":
        for activity in bundle.get("activities") or []:
            author = normalize_value(activity.get("author") or {})
            if str(author or "").strip().lower() not in identifiers:
                continue
            field_name = str((activity.get("field") or {}).get("name") or "").lower()
            if "исполнитель" in field_name or "assignee" in field_name:
                roles.append("assignee_change_author")
                break

        for work in bundle.get("workitems") or []:
            author = str(normalize_value(work.get("author") or {}) or "").strip().lower()
            creator = str(normalize_value(work.get("creator") or {}) or "").strip().lower()
            if author in identifiers:
                roles.append("worklog_author")
                break
            if creator in identifiers:
                roles.append("worklog_creator")
                break

    return sorted(set(roles))


def summarize_bundle(bundle: dict, roles: list[str]) -> dict:
    issue = bundle["issue"]
    work_minutes = 0
    last_work_date = None
    for work in bundle.get("workitems") or []:
        duration = (work.get("duration") or {}).get("minutes")
        if isinstance(duration, int):
            work_minutes += duration
        dt = fmt_ts(work.get("date"))
        if dt and (not last_work_date or dt > last_work_date):
            last_work_date = dt

    return {
        "issue_id": issue["issue_id"],
        "summary": issue.get("summary"),
        "project_key": issue.get("project_key"),
        "current_state": issue.get("current_state"),
        "assignee": issue.get("assignee"),
        "created_at": issue.get("created_at"),
        "updated_at": issue.get("updated_at"),
        "resolved_at": issue.get("resolved_at"),
        "work_minutes": work_minutes,
        "last_work_date": last_work_date,
        "subsystem": bundle["custom_fields"].get("Subsystem"),
        "dashboard_direction": bundle["custom_fields"].get("Дашборд КХД/Направление"),
        "roles": ", ".join(roles) if roles else "unknown",
        "issue_url": f"{YOUTRACK_URL}/issue/{issue['issue_id']}",
    }


def render_table(rows: list[dict]) -> str:
    if not rows:
        return "Ничего не найдено."

    headers = [
        ("issue_id", 14),
        ("roles", 26),
        ("work_minutes", 10),
        ("current_state", 20),
        ("updated_at", 16),
        ("summary", 72),
    ]

    def fmt(value: object, width: int) -> str:
        text_value = "" if value is None else str(value)
        if len(text_value) > width:
            return text_value[: width - 1] + "…"
        return text_value.ljust(width)

    lines = []
    lines.append(" | ".join(fmt(name, width) for name, width in headers))
    lines.append("-+-".join("-" * width for _, width in headers))
    for row in rows:
        lines.append(" | ".join(fmt(row.get(name), width) for name, width in headers))
    return "\n".join(lines)


def save_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def dump_raw_bundles(path: Path, bundles: list[dict]) -> None:
    path.mkdir(parents=True, exist_ok=True)
    for bundle in bundles:
        issue_id = bundle["issue"]["issue_id"]
        file_path = path / f"{issue_id}.json"
        file_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    load_dotenv()
    global YOUTRACK_URL, YOUTRACK_TOKEN, PAGE_SIZE
    YOUTRACK_URL = os.getenv("YOUTRACK_URL", YOUTRACK_URL).rstrip("/")
    YOUTRACK_TOKEN = os.getenv("YOUTRACK_TOKEN", YOUTRACK_TOKEN)
    PAGE_SIZE = int(os.getenv("YOUTRACK_PAGE_SIZE", str(PAGE_SIZE)))

    args = parse_args()
    email = normalize_email(args.email)
    base_candidates = build_candidates(email)
    identifiers, resolved_users, user_queries = resolve_users(email, base_candidates, args.login)
    identifiers_set = {x.strip().lower() for x in identifiers if x}

    issues_map, queries_used = collect_issue_candidates(identifiers)
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    matched_bundles = []
    for issue in issues_map.values():
        try:
            bundle = fetch_issue_details(issue)
        except Exception as exc:
            print(f"[WARN] {issue.get('idReadable')}: {exc}", file=sys.stderr)
            continue
        if not issue_matches_period(bundle, cutoff):
            continue
        roles = bundle_roles(bundle, identifiers_set, args.mode)
        if not roles:
            continue
        bundle["matched_roles"] = roles
        matched_bundles.append(bundle)
        if len(matched_bundles) >= args.top:
            break

    rows = [summarize_bundle(bundle, bundle["matched_roles"]) for bundle in matched_bundles]
    rows.sort(
        key=lambda row: (
            -(row.get("work_minutes") or 0),
            row.get("updated_at") or "",
            row.get("issue_id") or "",
        )
    )

    print(f"Почта: {email}")
    if args.login.strip():
        print(f"Переданный логин: {args.login.strip()}")
    print(f"Поиск пользователя: {', '.join(user_queries) if user_queries else 'не выполнялся'}")
    print(f"Идентификаторы: {', '.join(identifiers)}")
    if resolved_users:
        preview = []
        for user in resolved_users[:10]:
            preview.append(
                " / ".join(
                    [
                        str(user.get("login") or "").strip(),
                        str(user.get("fullName") or user.get("name") or "").strip(),
                        str(user.get("email") or "").strip(),
                    ]
                ).strip(" /")
            )
        print(f"Найденные пользователи: {'; '.join(preview)}")
    else:
        print("Найденные пользователи: не удалось получить из /api/users, поиск идет только по локальным кандидатам")
    print(f"Запросы: {', '.join(queries_used[:8]) if queries_used else 'не удалось подобрать'}")
    print(f"Найдено задач за {args.days} дней: {len(rows)}")

    if args.dump_dir:
        dump_raw_bundles(Path(args.dump_dir), matched_bundles)
        print(f"Raw JSON сохранен в {args.dump_dir}")

    if args.format == "table":
        print()
        print(render_table(rows))
    elif args.format == "json":
        payload = json.dumps(
            {"email": email, "identifiers": identifiers, "rows": rows},
            ensure_ascii=False,
            indent=2,
        )
        if args.output:
            Path(args.output).write_text(payload, encoding="utf-8")
            print(f"\nJSON сохранен в {args.output}")
        else:
            print(payload)
    else:
        output_path = Path(args.output or f"ytrek_tasks_{email.split('@', 1)[0]}.csv")
        save_csv(output_path, rows)
        print(f"\nCSV сохранен в {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
