#!/usr/bin/env python3
import os
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
    issue_id = issue.get("id")
    project = issue.get("project", {})
    reporter = issue.get("reporter") or {}
    assignee = issue.get("assignee") or {}

    activities = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/activities",
        {"fields": ACTIVITY_FIELDS, "categories": ACTIVITY_CATEGORIES},
    )
    workitems = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/timeTracking/workItems",
        {"fields": WORKITEM_FIELDS},
    )
    comments = api_get(
        f"{YOUTRACK_URL}/api/issues/{issue_id}/comments",
        {"fields": COMMENT_FIELDS},
    )

    # snapshot
    snapshot_row = {
        "issue_id": issue.get("idReadable"),
        "summary": issue.get("summary"),
        "description": issue.get("description"),
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
        value = cf.get("value")
        if isinstance(value, list):
            value = ", ".join([v.get("name", str(v)) if isinstance(v, dict) else str(v) for v in value])
        elif isinstance(value, dict):
            if value.get("$type") == "PeriodValue":
                value = fmt_period_value(value)
            else:
                value = value.get("name", str(value))
        elif isinstance(value, int):
            if value > 1_000_000_000_000:
                value = fmt_ts(value)
        custom_rows.append({"issue_id": issue.get("idReadable"), "field_name": name, "field_value": value})

    # timeline from activities
    timeline_rows = []
    for act in activities:
        field = (act.get("field") or {}).get("name")
        added = act.get("added") or act.get("to") or ""
        removed = act.get("removed") or ""
        if isinstance(added, list):
            added = ", ".join([a.get("name", str(a)) if isinstance(a, dict) else str(a) for a in added])
        elif isinstance(added, dict):
            added = added.get("name", str(added))
        if isinstance(removed, list):
            removed = ", ".join([r.get("name", str(r)) if isinstance(r, dict) else str(r) for r in removed])
        elif isinstance(removed, dict):
            removed = removed.get("name", str(removed))

        event_type = "Other"
        if field:
            lower = field.lower()
            if "исполнитель" in lower or "assignee" in lower:
                event_type = "Assignee change"
            elif "состояние" in lower or "state" in lower:
                event_type = "State change"
            elif "трудозатрат" in lower or "spent" in lower:
                event_type = "Work logged"

        timeline_rows.append(
            {
                "issue_id": issue.get("idReadable"),
                "ts": fmt_ts(act.get("timestamp")),
                "author": (act.get("author") or {}).get("login") or (act.get("author") or {}).get("name"),
                "event_type": event_type,
                "field_name": field,
                "value_from": removed,
                "value_to": added,
            }
        )

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
    if not ISSUE_IDS:
        raise SystemExit("Set ISSUE_IDS list")

    engine = create_engine(PG_DSN)

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

    for issue_id in ISSUE_IDS:
        load_issue(engine, issue_id)

    print("Done.")


if __name__ == "__main__":
    main()
