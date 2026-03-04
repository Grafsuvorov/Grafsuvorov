#!/usr/bin/env python3
import os
import re
from datetime import datetime, timezone

import requests
import urllib3
from sqlalchemy import create_engine, text

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- FILL THESE FOR LOCAL USE (do not commit real secrets) ---
YOUTRACK_URL = "https://yt.rusal.ru"
YOUTRACK_TOKEN = "perm:PASTE_TOKEN_HERE"
PG_DSN = "postgresql+psycopg2://user:pass@host:5432/db"
ISSUE_IDS = ["DWH-10667"]

# Optional override via env
YOUTRACK_URL = os.getenv("YOUTRACK_URL", YOUTRACK_URL)
YOUTRACK_TOKEN = os.getenv("YOUTRACK_TOKEN", YOUTRACK_TOKEN)
PG_DSN = os.getenv("YT_PG_DSN", PG_DSN)

TRUNCATE_BEFORE_LOAD = False
ONLY_NEW_ISSUES = True
ONLY_RELEASE_TASKS = True

ISSUE_FIELDS = (
    "id,idReadable,summary,description,project(name,key),"
    "customFields(name,value(id,name)),reporter(login,name),assignee(login,name),"
    "created,updated,resolved"
)
ACTIVITY_FIELDS = "author(name,login),timestamp,field(name),added(name,login),removed(name,login),to(name,login)"
ACTIVITY_CATEGORIES = "CustomFieldCategory,CommentsCategory,WorkItemCategory"
WORKITEM_FIELDS = "author(name,login),creator(name,login),date,duration(minutes),text,workType(name)"
COMMENT_FIELDS = "author(name,login),created,text"


DDL = """
CREATE SCHEMA IF NOT EXISTS tech_etl;

CREATE TABLE IF NOT EXISTS tech_etl.yt_issue_snapshot (
  issue_id text not null,
  summary text,
  description text,
  project_name text,
  project_key text,
  created_by text,
  assignee text,
  created_at timestamp,
  updated_at timestamp,
  resolved_at timestamp,
  current_state text,
  last_state_changed_by text,
  last_state_changed_at timestamp,
  last_updated_by text,
  last_updated_at timestamp,
  last_updated_field text,
  last_assignee_changed_by text,
  last_assignee_changed_at timestamp,
  last_assignee_set text,
  dttm_loaded timestamp default now()
);

CREATE TABLE IF NOT EXISTS tech_etl.yt_issue_custom_field (
  issue_id text not null,
  field_name text not null,
  field_value text,
  dttm_loaded timestamp default now()
);

CREATE TABLE IF NOT EXISTS tech_etl.yt_issue_timeline (
  issue_id text not null,
  ts timestamp,
  author text,
  event_type text,
  field_name text,
  value_from text,
  value_to text,
  dttm_loaded timestamp default now()
);

CREATE TABLE IF NOT EXISTS tech_etl.yt_issue_worklog (
  issue_id text not null,
  author text,
  creator text,
  work_date timestamp,
  minutes int,
  work_type text,
  work_text text,
  dttm_loaded timestamp default now()
);

CREATE TABLE IF NOT EXISTS tech_etl.yt_issue_comment (
  issue_id text not null,
  author text,
  created_at timestamp,
  comment_text text,
  dttm_loaded timestamp default now()
);
"""

def api_get(url, params):
    headers = {"Authorization": f"Bearer {YOUTRACK_TOKEN}", "Accept": "application/json"}
    resp = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
    if resp.status_code == 404:
        return None
    if resp.status_code != 200:
        raise SystemExit(f"API error {resp.status_code}: {resp.text}")
    return resp.json()


def fmt_ts(value):
    if not value:
        return None
    try:
        dt = datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
        return dt.astimezone().strftime("%Y-%m-%d %H:%M")
    except Exception:
        return None


def fmt_period_value(value):
    if not isinstance(value, dict):
        return value
    if value.get("$type") != "PeriodValue":
        return value.get("name", value)
    raw = value.get("id") or ""
    if not raw.startswith("PT"):
        return raw or None
    hours = 0
    minutes = 0
    chunk = raw[2:]
    if "H" in chunk:
        h_part, chunk = chunk.split("H", 1)
        try:
            hours = int(h_part)
        except Exception:
            hours = 0
    if "M" in chunk:
        m_part = chunk.split("M", 1)[0]
        try:
            minutes = int(m_part)
        except Exception:
            minutes = 0
    parts = []
    if hours:
        parts.append(f"{hours}ч")
    if minutes:
        parts.append(f"{minutes}м")
    return " ".join(parts) if parts else raw


def fmt_minutes(value):
    try:
        minutes = int(value)
    except Exception:
        return value
    if minutes % 60 == 0:
        return f"{minutes // 60}ч"
    return f"{minutes} мин"


def clean_text(value):
    if not value:
        return value
    text = str(value)
    # strip markdown links: [text](url) -> text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # remove bold/italic/code markers
    text = text.replace("**", "").replace("__", "").replace("*", "").replace("_", "")
    text = text.replace("`", "")
    # collapse extra whitespace
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def normalize_value(value):
    if isinstance(value, list):
        return ", ".join([v.get("name", str(v)) if isinstance(v, dict) else str(v) for v in value])
    if isinstance(value, dict):
        if value.get("$type") == "PeriodValue":
            return fmt_period_value(value)
        return value.get("name", str(value))
    if isinstance(value, int):
        if value > 1_000_000_000_000:
            return fmt_ts(value)
    return value


def fetch_release_tasks(engine):
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT DISTINCT task_id
                FROM tech_etl.release_objects
                WHERE task_id IS NOT NULL
                """
            )
        ).fetchall()
    return [r[0] for r in rows if r[0]]


def existing_issues(engine, issue_ids):
    if not issue_ids:
        return set()
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT DISTINCT issue_id
                FROM tech_etl.yt_issue_snapshot
                WHERE issue_id = ANY(:ids)
                """
            ),
            {"ids": issue_ids},
        ).fetchall()
    return {r[0] for r in rows}


def get_current_state(custom_fields):
    for cf in custom_fields or []:
        name = cf.get("name", "")
        if name.lower() in ("state", "состояние", "статус"):
            value = cf.get("value")
            if isinstance(value, dict) and "name" in value:
                return value["name"]
            return str(value) if value is not None else None
    return None


def load_issue(engine, issue_readable):
    issue = api_get(f"{YOUTRACK_URL}/api/issues/{issue_readable}", {"fields": ISSUE_FIELDS})
    if not issue:
        print(f"[WARN] Issue not found: {issue_readable}")
        return
    issue_id = issue.get("id")
    project = issue.get("project", {})
    reporter = issue.get("reporter") or {}
    assignee = issue.get("assignee") or {}

    activities = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/activities",
        {"fields": ACTIVITY_FIELDS, "categories": ACTIVITY_CATEGORIES},
    ) or []
    workitems = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/timeTracking/workItems",
        {"fields": WORKITEM_FIELDS},
    ) or []
    comments = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/comments",
        {"fields": COMMENT_FIELDS},
    ) or []

    # snapshot
    snapshot_row = {
        "issue_id": issue.get("idReadable"),
        "summary": clean_text(issue.get("summary")),
        "description": clean_text(issue.get("description")),
        "project_name": project.get("name"),
        "project_key": project.get("key"),
        "created_by": reporter.get("login") or reporter.get("name"),
        "assignee": assignee.get("login") or assignee.get("name"),
        "created_at": fmt_ts(issue.get("created")),
        "updated_at": fmt_ts(issue.get("updated")),
        "resolved_at": fmt_ts(issue.get("resolved")),
        "current_state": get_current_state(issue.get("customFields")),
        "last_state_changed_by": None,
        "last_state_changed_at": None,
        "last_updated_by": None,
        "last_updated_at": None,
        "last_updated_field": None,
        "last_assignee_changed_by": None,
        "last_assignee_changed_at": None,
        "last_assignee_set": None,
    }

    # custom fields
    custom_rows = []
    for cf in issue.get("customFields") or []:
        name = cf.get("name") or cf.get("id") or "custom"
        value = normalize_value(cf.get("value"))
        custom_rows.append({"issue_id": issue.get("idReadable"), "field_name": name, "field_value": value})

    # timeline from activities
    raw_events = []
    for act in activities:
        field = (act.get("field") or {}).get("name")
        if not field:
            continue
        lower = field.lower()
        if "комментарии" in lower or "работа" in lower:
            continue

        added = normalize_value(act.get("added") or act.get("to"))
        removed = normalize_value(act.get("removed"))

        event_type = None
        if "исполнитель" in lower or "assignee" in lower:
            event_type = "Assignee change"
        elif "состояние" in lower or "state" in lower:
            event_type = "State change"
        elif "трудозатрат" in lower or "spent" in lower:
            event_type = "Work logged"

        if not event_type:
            continue

        raw_events.append(
            {
                "issue_id": issue.get("idReadable"),
                "ts": fmt_ts(act.get("timestamp")),
                "author": (act.get("author") or {}).get("login") or (act.get("author") or {}).get("name"),
                "field_name": field,
                "event_type": event_type,
                "value_from": removed,
                "value_to": added,
            }
        )

    # merge paired added/removed events for same timestamp/author/field
    timeline_rows = []
    bucket = {}
    for ev in raw_events:
        key = (ev["issue_id"], ev["ts"], ev["author"], ev["field_name"], ev["event_type"])
        existing = bucket.get(key, {})
        value_from = ev.get("value_from") or existing.get("value_from")
        value_to = ev.get("value_to") or existing.get("value_to")
        bucket[key] = {**ev, "value_from": value_from, "value_to": value_to}
    for ev in bucket.values():
        if ev.get("event_type") == "Work logged":
            if isinstance(ev.get("value_from"), int):
                ev["value_from"] = fmt_minutes(ev.get("value_from"))
            if isinstance(ev.get("value_to"), int):
                ev["value_to"] = fmt_minutes(ev.get("value_to"))
        if ev.get("value_from") is None and ev.get("value_to") is None:
            continue
        timeline_rows.append(ev)

    # worklog
    worklog_rows = []
    for wi in workitems:
        worklog_rows.append(
            {
                "issue_id": issue.get("idReadable"),
                "author": (wi.get("author") or {}).get("login") or (wi.get("author") or {}).get("name"),
                "creator": (wi.get("creator") or {}).get("login") or (wi.get("creator") or {}).get("name"),
                "work_date": fmt_ts(wi.get("date")),
                "minutes": (wi.get("duration") or {}).get("minutes") if isinstance(wi.get("duration"), dict) else None,
                "work_type": (wi.get("workType") or {}).get("name") if isinstance(wi.get("workType"), dict) else None,
                "work_text": wi.get("text"),
            }
        )

    # comments
    comments_rows = []
    for cm in comments:
        comments_rows.append(
            {
                "issue_id": issue.get("idReadable"),
                "author": (cm.get("author") or {}).get("login") or (cm.get("author") or {}).get("name"),
                "created_at": fmt_ts(cm.get("created")),
                "comment_text": cm.get("text"),
            }
        )

    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO tech_etl.yt_issue_snapshot (
                  issue_id, summary, description, project_name, project_key, created_by, assignee,
                  created_at, updated_at, resolved_at, current_state,
                  last_state_changed_by, last_state_changed_at,
                  last_updated_by, last_updated_at, last_updated_field,
                  last_assignee_changed_by, last_assignee_changed_at, last_assignee_set
                )
                VALUES (
                  :issue_id, :summary, :description, :project_name, :project_key, :created_by, :assignee,
                  :created_at, :updated_at, :resolved_at, :current_state,
                  :last_state_changed_by, :last_state_changed_at,
                  :last_updated_by, :last_updated_at, :last_updated_field,
                  :last_assignee_changed_by, :last_assignee_changed_at, :last_assignee_set
                )
                """
            ),
            [snapshot_row],
        )
        if custom_rows:
            conn.execute(
                text(
                    """
                    INSERT INTO tech_etl.yt_issue_custom_field (issue_id, field_name, field_value)
                    VALUES (:issue_id, :field_name, :field_value)
                    """
                ),
                custom_rows,
            )
        if timeline_rows:
            conn.execute(
                text(
                    """
                    INSERT INTO tech_etl.yt_issue_timeline (
                      issue_id, ts, author, event_type, field_name, value_from, value_to
                    )
                    VALUES (:issue_id, :ts, :author, :event_type, :field_name, :value_from, :value_to)
                    """
                ),
                timeline_rows,
            )
        if worklog_rows:
            conn.execute(
                text(
                    """
                    INSERT INTO tech_etl.yt_issue_worklog (
                      issue_id, author, creator, work_date, minutes, work_type, work_text
                    )
                    VALUES (:issue_id, :author, :creator, :work_date, :minutes, :work_type, :work_text)
                    """
                ),
                worklog_rows,
            )
        if comments_rows:
            conn.execute(
                text(
                    """
                    INSERT INTO tech_etl.yt_issue_comment (
                      issue_id, author, created_at, comment_text
                    )
                    VALUES (:issue_id, :author, :created_at, :comment_text)
                    """
                ),
                comments_rows,
            )


def main():
    if "PASTE_TOKEN_HERE" in YOUTRACK_TOKEN:
        raise SystemExit("Set YOUTRACK_TOKEN in script or env")
    if "user:pass" in PG_DSN:
        raise SystemExit("Set PG_DSN in script or env")
    engine = create_engine(PG_DSN)

    if ONLY_RELEASE_TASKS:
        ISSUE_IDS[:] = fetch_release_tasks(engine)
    if not ISSUE_IDS:
        raise SystemExit("No ISSUE_IDS found")

    with engine.begin() as conn:
        for stmt in DDL.strip().split(";"):
            sql = stmt.strip()
            if sql:
                conn.execute(text(sql))

    if TRUNCATE_BEFORE_LOAD:
        with engine.begin() as conn:
            conn.execute(text("TRUNCATE tech_etl.yt_issue_snapshot"))
            conn.execute(text("TRUNCATE tech_etl.yt_issue_custom_field"))
            conn.execute(text("TRUNCATE tech_etl.yt_issue_timeline"))
            conn.execute(text("TRUNCATE tech_etl.yt_issue_worklog"))
            conn.execute(text("TRUNCATE tech_etl.yt_issue_comment"))

    if ONLY_NEW_ISSUES:
        existing = existing_issues(engine, ISSUE_IDS)
    else:
        existing = set()

    for issue_id in ISSUE_IDS:
        if ONLY_NEW_ISSUES and issue_id in existing:
            continue
        load_issue(engine, issue_id)

    print("Done.")


if __name__ == "__main__":
    main()
