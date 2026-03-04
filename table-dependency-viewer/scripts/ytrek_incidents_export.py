#!/usr/bin/env python3
import csv
import os
from datetime import datetime, timezone

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru")
TOKEN = os.getenv("YOUTRACK_TOKEN", "")
CUSTOM_FIELD_ID = os.getenv("YOUTRACK_CUSTOM_FIELD_ID", "134-394")
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


def main():
    print(f"Получение задач с кастомным полем {CUSTOM_FIELD_ID}...")
    url = f"{YOUTRACK_URL}/api/issues"

    all_issues = []
    page = 0

    while True:
        params = {
            "fields": "id,idReadable,summary,description,project(name,key),"
                      "customFields(name,value,id),reporter(login,name),assignee(login,name),"
                      "created,updated,resolved",
            "$top": PAGE_SIZE,
            "$skip": page * PAGE_SIZE,
        }
        response = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
        if response.status_code != 200:
            raise SystemExit(f"Ошибка {response.status_code}: {response.text}")

        issues_list = response.json()
        if not issues_list:
            break
        all_issues.extend(issues_list)
        if len(issues_list) < PAGE_SIZE:
            break
        page += 1

    incident_issues = []
    for issue in all_issues:
        custom_fields = issue.get("customFields", [])
        is_incident = False
        incident_value = "N/A"

        for cf in custom_fields:
            if cf.get("id") == CUSTOM_FIELD_ID:
                is_incident = True
                value = cf.get("value", "N/A")
                if isinstance(value, dict) and "name" in value:
                    incident_value = value["name"]
                else:
                    incident_value = str(value)
                break

        if not is_incident:
            continue

        project = issue.get("project", {})
        reporter = issue.get("reporter") or {}
        assignee = issue.get("assignee") or {}

        activities = fetch_issue_activities(issue.get("id"))
        last_state_author, last_state_ts = find_last_state_transition(activities)

        incident_issues.append({
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
            "Custom_Field_ID": CUSTOM_FIELD_ID,
            "Custom_Field_Value": incident_value,
        })

    if not incident_issues:
        print("Нет задач с указанным кастомным полем.")
        return

    filename = f"incident_issues_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    out_path = os.path.join(os.path.dirname(__file__), filename)

    fieldnames = list(incident_issues[0].keys())
    with open(out_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in incident_issues:
            writer.writerow(row)

    print(f"✓ Данные сохранены: {out_path}")


if __name__ == "__main__":
    main()
