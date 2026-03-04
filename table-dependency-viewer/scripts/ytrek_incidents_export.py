#!/usr/bin/env python3
import csv
import os
import sys
from datetime import datetime, timezone

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru")
TOKEN = os.getenv("YOUTRACK_TOKEN", "")
PAGE_SIZE = int(os.getenv("YOUTRACK_PAGE_SIZE", "50"))

if not TOKEN:
    raise SystemExit("YOUTRACK_TOKEN is required")

headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {TOKEN}",
}


def fmt_ts(value):
    if not value:
        return "—"
    try:
        # YouTrack timestamps are in ms
        dt = datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)
        return dt.astimezone().strftime("%Y-%m-%d %H:%M")
    except Exception:
        return str(value)


def fetch_issue_activities(issue_id):
    url = f"{YOUTRACK_URL}/api/issues/{issue_id}/activities"
    params = {
        "fields": "author(name,login),timestamp,field(name),added(name),removed(name),to(name)"
    }
    resp = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
    if resp.status_code != 200:
        return []
    return resp.json()


def find_last_state_transition(activities):
    state_changes = []
    for a in activities:
        field = (a.get("field") or {}).get("name")
        if field and field.lower() in ("state", "статус"):
            state_changes.append(a)
    if not state_changes:
        return None, None
    last = sorted(state_changes, key=lambda x: x.get("timestamp", 0))[-1]
    author = (last.get("author") or {}).get("login") or (last.get("author") or {}).get("name")
    ts = last.get("timestamp")
    return author, ts


def fetch_issue_by_readable(issue_readable):
    url = f"{YOUTRACK_URL}/api/issues/{issue_readable}"
    params = {
        "fields": "id,idReadable,summary,description,project(name,key),"
                  "customFields(name,value,id),reporter(login,name),assignee(login,name),"
                  "created,updated,resolved",
    }
    resp = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
    if resp.status_code != 200:
        raise SystemExit(f"Ошибка {resp.status_code} для {issue_readable}: {resp.text}")
    return resp.json()


def main():
    issue_ids = [arg.strip() for arg in sys.argv[1:] if arg.strip()]
    if not issue_ids:
        raise SystemExit("Укажи задачи в аргументах, например: DWH-10841 DWH-10842")

    issues_data = []
    for issue_readable in issue_ids:
        issue = fetch_issue_by_readable(issue_readable)

        project = issue.get("project", {})
        reporter = issue.get("reporter") or {}
        assignee = issue.get("assignee") or {}

        activities = fetch_issue_activities(issue.get("id"))
        last_state_author, last_state_ts = find_last_state_transition(activities)

        issues_data.append({
            "ID": issue.get("idReadable", "N/A"),
            "Summary": issue.get("summary", "N/A"),
            "Description": issue.get("description", "N/A"),
            "Project_Name": project.get("name", "N/A"),
            "Project_Key": project.get("key", "N/A"),
            "Created_By": reporter.get("login") or reporter.get("name") or "N/A",
            "Assignee": assignee.get("login") or assignee.get("name") or "N/A",
            "Created_At": fmt_ts(issue.get("created")),
            "Updated_At": fmt_ts(issue.get("updated")),
            "Resolved_At": fmt_ts(issue.get("resolved")),
            "Last_State_Changed_By": last_state_author or "N/A",
            "Last_State_Changed_At": fmt_ts(last_state_ts),
        })

    filename = f"issues_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    out_path = os.path.join(os.path.dirname(__file__), filename)

    fieldnames = list(issues_data[0].keys())
    with open(out_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in issues_data:
            writer.writerow(row)

    print(f"✓ Данные сохранены: {out_path}")


if __name__ == "__main__":
    main()
