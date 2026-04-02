#!/usr/bin/env python3
"""Fetch YouTrack tasks for one employee from loaded yt_issue_* tables."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


DEFAULT_DATABASE_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
DEFAULT_TABLE_SNAPSHOT = "tech_etl.yt_issue_snapshot"
DEFAULT_TABLE_CUSTOM = "tech_etl.yt_issue_custom_field"
DEFAULT_TABLE_TIMELINE = "tech_etl.yt_issue_timeline"
DEFAULT_TABLE_WORKLOG = "tech_etl.yt_issue_worklog"
DEFAULT_ISSUE_URL = "https://yt.rusal.ru/issue/{id}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Показать задачи сотрудника по почте из таблиц tech_etl.yt_issue_*"
    )
    parser.add_argument("email", help="Почта сотрудника, например ivan.ivanov@rusal.com")
    parser.add_argument(
        "--days",
        type=int,
        default=365,
        help="Окно поиска по created_at / updated_at / worklog, дней назад. По умолчанию 365.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=500,
        help="Максимум строк в выводе. По умолчанию 500.",
    )
    parser.add_argument(
        "--format",
        choices=("table", "json", "csv"),
        default="table",
        help="Формат вывода. По умолчанию table.",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="",
        help="Путь для сохранения результата в файл. Для csv/json.",
    )
    return parser.parse_args()


def normalize_email(email: str) -> str:
    value = (email or "").strip().lower()
    if "@" not in value:
        raise SystemExit("Нужна именно почта, например ivan.ivanov@rusal.com")
    return value


def build_identifiers(email: str) -> list[str]:
    local_part = email.split("@", 1)[0]
    normalized = {email, local_part}

    normalized.add(local_part.replace(".", "_"))
    normalized.add(local_part.replace("_", "."))
    normalized.add(re.sub(r"\+.*$", "", local_part))

    return sorted(x for x in normalized if x)


def get_env(name: str, default: str) -> str:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def fetch_rows(
    database_url: str,
    snapshot_table: str,
    custom_table: str,
    timeline_table: str,
    worklog_table: str,
    issue_url: str,
    identifiers: list[str],
    days: int,
    limit: int,
) -> list[dict]:
    engine = create_engine(database_url)
    query = text(
        f"""
        WITH ids AS (
            SELECT unnest(:identifiers) AS ident
        ),
        worklog AS (
            SELECT
                w.issue_id,
                COALESCE(SUM(w.minutes), 0) AS work_minutes,
                MAX(w.work_date) AS last_work_date,
                BOOL_OR(LOWER(COALESCE(w.author, '')) IN (SELECT ident FROM ids)) AS has_worklog_author,
                BOOL_OR(LOWER(COALESCE(w.creator, '')) IN (SELECT ident FROM ids)) AS has_worklog_creator
            FROM {worklog_table} w
            GROUP BY w.issue_id
        ),
        executor AS (
            SELECT DISTINCT ON (t.issue_id)
                t.issue_id,
                t.author AS executor,
                t.ts AS executor_ts
            FROM {timeline_table} t
            WHERE t.event_type = 'State change'
              AND t.value_to IN ('Ожидание релиза', 'В работе')
            ORDER BY t.issue_id, t.ts DESC NULLS LAST
        ),
        subsystem AS (
            SELECT c.issue_id, c.field_value AS subsystem
            FROM {custom_table} c
            WHERE c.field_name = 'Subsystem'
        ),
        dashboard AS (
            SELECT c.issue_id, c.field_value AS dashboard_direction
            FROM {custom_table} c
            WHERE c.field_name = 'Дашборд КХД/Направление'
        ),
        matched AS (
            SELECT
                s.issue_id,
                s.summary,
                s.project_name,
                s.project_key,
                s.created_by,
                s.assignee,
                e.executor,
                s.current_state,
                s.created_at,
                s.updated_at,
                s.resolved_at,
                COALESCE(ss.subsystem, 'Не указан') AS subsystem,
                COALESCE(dd.dashboard_direction, 'Не указан') AS dashboard_direction,
                COALESCE(w.work_minutes, 0) AS work_minutes,
                w.last_work_date,
                (LOWER(COALESCE(s.assignee, '')) IN (SELECT ident FROM ids)) AS is_assignee,
                (LOWER(COALESCE(s.created_by, '')) IN (SELECT ident FROM ids)) AS is_creator,
                (LOWER(COALESCE(e.executor, '')) IN (SELECT ident FROM ids)) AS is_executor,
                COALESCE(w.has_worklog_author, FALSE) AS has_worklog_author,
                COALESCE(w.has_worklog_creator, FALSE) AS has_worklog_creator
            FROM {snapshot_table} s
            LEFT JOIN worklog w ON w.issue_id = s.issue_id
            LEFT JOIN executor e ON e.issue_id = s.issue_id
            LEFT JOIN subsystem ss ON ss.issue_id = s.issue_id
            LEFT JOIN dashboard dd ON dd.issue_id = s.issue_id
            WHERE (
                LOWER(COALESCE(s.assignee, '')) IN (SELECT ident FROM ids)
                OR LOWER(COALESCE(s.created_by, '')) IN (SELECT ident FROM ids)
                OR LOWER(COALESCE(e.executor, '')) IN (SELECT ident FROM ids)
                OR COALESCE(w.has_worklog_author, FALSE)
                OR COALESCE(w.has_worklog_creator, FALSE)
            )
            AND (
                COALESCE(s.created_at, s.updated_at, s.resolved_at) >= now() - (:days || ' days')::interval
                OR COALESCE(w.last_work_date, s.updated_at, s.created_at) >= now() - (:days || ' days')::interval
            )
        )
        SELECT
            issue_id,
            summary,
            project_key,
            project_name,
            current_state,
            created_by,
            assignee,
            executor,
            subsystem,
            dashboard_direction,
            work_minutes,
            created_at,
            updated_at,
            resolved_at,
            last_work_date,
            is_assignee,
            is_creator,
            is_executor,
            has_worklog_author,
            has_worklog_creator
        FROM matched
        ORDER BY
            COALESCE(work_minutes, 0) DESC,
            COALESCE(last_work_date, updated_at, created_at) DESC NULLS LAST,
            issue_id
        LIMIT :limit
        """
    )

    with engine.connect() as conn:
        rows = conn.execute(
            query,
            {
                "identifiers": identifiers,
                "days": days,
                "limit": limit,
            },
        ).mappings().all()

    result = []
    for row in rows:
        role_bits = []
        if row["is_assignee"]:
            role_bits.append("assignee")
        if row["is_executor"]:
            role_bits.append("executor")
        if row["has_worklog_author"]:
            role_bits.append("worklog_author")
        if row["has_worklog_creator"]:
            role_bits.append("worklog_creator")
        if row["is_creator"]:
            role_bits.append("creator")

        payload = dict(row)
        payload["roles"] = ", ".join(role_bits) if role_bits else "unknown"
        payload["issue_url"] = issue_url.format(id=row["issue_id"])
        result.append(payload)
    return result


def render_table(rows: list[dict]) -> str:
    if not rows:
        return "Ничего не найдено."

    headers = [
        ("issue_id", 14),
        ("roles", 28),
        ("work_minutes", 10),
        ("current_state", 22),
        ("subsystem", 18),
        ("summary", 70),
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


def dump_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    load_dotenv()
    args = parse_args()

    email = normalize_email(args.email)
    identifiers = build_identifiers(email)

    database_url = get_env("DATABASE_URL", get_env("YT_PG_DSN", DEFAULT_DATABASE_URL))
    snapshot_table = get_env("TABLE_YT_ISSUE_SNAPSHOT", DEFAULT_TABLE_SNAPSHOT)
    custom_table = get_env("TABLE_YT_ISSUE_CUSTOM", DEFAULT_TABLE_CUSTOM)
    timeline_table = get_env("TABLE_YT_ISSUE_TIMELINE", DEFAULT_TABLE_TIMELINE)
    worklog_table = get_env("TABLE_YT_ISSUE_WORKLOG", DEFAULT_TABLE_WORKLOG)
    issue_url = get_env("YTRACK_ISSUE_URL", DEFAULT_ISSUE_URL)

    try:
        rows = fetch_rows(
            database_url=database_url,
            snapshot_table=snapshot_table,
            custom_table=custom_table,
            timeline_table=timeline_table,
            worklog_table=worklog_table,
            issue_url=issue_url,
            identifiers=identifiers,
            days=args.days,
            limit=args.limit,
        )
    except Exception as exc:
        print(f"Ошибка при чтении задач: {exc}", file=sys.stderr)
        return 1

    print(f"Поиск по почте: {email}")
    print(f"Идентификаторы для матчинга: {', '.join(identifiers)}")
    print(f"Найдено задач: {len(rows)}")

    if args.format == "table":
        print()
        print(render_table(rows))
    elif args.format == "json":
        payload = json.dumps(rows, ensure_ascii=False, indent=2, default=str)
        if args.output:
            Path(args.output).write_text(payload, encoding="utf-8")
            print(f"\nJSON сохранен в {args.output}")
        else:
            print(payload)
    else:
        output_path = Path(args.output or f"ytrek_tasks_{email.split('@', 1)[0]}.csv")
        dump_csv(output_path, rows)
        print(f"\nCSV сохранен в {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
