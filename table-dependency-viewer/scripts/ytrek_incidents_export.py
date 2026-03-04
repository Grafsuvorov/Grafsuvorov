#!/usr/bin/env python3
import csv
import json
import os
import sys
from datetime import datetime, timezone

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

YOUTRACK_URL = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru")
TOKEN = os.getenv("YOUTRACK_TOKEN", "")
PAGE_SIZE = int(os.getenv("YOUTRACK_PAGE_SIZE", "50"))
ISSUE_FIELDS_DEFAULT = os.getenv("YOUTRACK_ISSUE_FIELDS", "$all")
ACTIVITY_FIELDS_DEFAULT = os.getenv("YOUTRACK_ACTIVITY_FIELDS", "$all")

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
    params = {"fields": ACTIVITY_FIELDS_DEFAULT}
    resp = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
    if resp.status_code == 200:
        return resp.json()
    # fallback
    params = {"fields": "author(name,login),timestamp,field(name),added(name),removed(name),to(name)"}
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


def find_last_activity(activities):
    if not activities:
        return None, None, None
    last = sorted(activities, key=lambda x: x.get("timestamp", 0))[-1]
    author = (last.get("author") or {}).get("login") or (last.get("author") or {}).get("name")
    field = (last.get("field") or {}).get("name")
    return author, last.get("timestamp"), field


def find_last_assignee_change(activities):
    assignee_changes = []
    for a in activities:
        field = (a.get("field") or {}).get("name")
        if field and field.lower() in ("assignee", "исполнитель", "назначено"):
            assignee_changes.append(a)
    if not assignee_changes:
        return None, None, None
    last = sorted(assignee_changes, key=lambda x: x.get("timestamp", 0))[-1]
    author = (last.get("author") or {}).get("login") or (last.get("author") or {}).get("name")
    added = last.get("added") or last.get("to")
    assignee_name = None
    if isinstance(added, list) and added:
        assignee_name = added[0].get("name")
    elif isinstance(added, dict):
        assignee_name = added.get("name")
    return author, last.get("timestamp"), assignee_name


def get_current_state(custom_fields):
    for cf in custom_fields or []:
        name = cf.get("name", "")
        if name.lower() in ("state", "статус"):
            value = cf.get("value")
            if isinstance(value, dict) and "name" in value:
                return value["name"]
            return str(value) if value is not None else "—"
    return "—"


def fetch_issue_by_readable(issue_readable):
    url = f"{YOUTRACK_URL}/api/issues/{issue_readable}"
    params = {"fields": ISSUE_FIELDS_DEFAULT}
    resp = requests.get(url, headers=headers, params=params, verify=False, timeout=60)
    if resp.status_code == 200:
        return resp.json()
    # fallback
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
    all_custom_names = set()
    raw_dump = len(issue_ids) == 1
    for issue_readable in issue_ids:
        issue = fetch_issue_by_readable(issue_readable)

        project = issue.get("project", {})
        reporter = issue.get("reporter") or {}
        assignee = issue.get("assignee") or {}

        activities = fetch_issue_activities(issue.get("id"))
        last_state_author, last_state_ts = find_last_state_transition(activities)
        last_activity_author, last_activity_ts, last_activity_field = find_last_activity(activities)
        last_assignee_author, last_assignee_ts, last_assignee_name = find_last_assignee_change(activities)
        current_state = get_current_state(issue.get("customFields"))

        if raw_dump:
            out_dir = os.path.dirname(__file__)
            issue_path = os.path.join(out_dir, f"ytrek_issue_raw_{issue_readable}.json")
            act_path = os.path.join(out_dir, f"ytrek_issue_activities_{issue_readable}.json")
            with open(issue_path, "w", encoding="utf-8") as f:
                json.dump(issue, f, ensure_ascii=False, indent=2)
            with open(act_path, "w", encoding="utf-8") as f:
                json.dump(activities, f, ensure_ascii=False, indent=2)

        custom_fields_map = {}
        for cf in issue.get("customFields") or []:
            name = cf.get("name") or cf.get("id") or "custom"
            value = cf.get("value")
            if isinstance(value, list):
                value = ", ".join([v.get("name", str(v)) if isinstance(v, dict) else str(v) for v in value])
            elif isinstance(value, dict):
                value = value.get("name", str(value))
            elif isinstance(value, int):
                # heuristic for timestamps in ms
                if value > 1_000_000_000_000:
                    value = fmt_ts(value)
            custom_fields_map[name] = value if value is not None else "N/A"
            all_custom_names.add(name)

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
            "Current_State": current_state,
            "Last_Updated_By": last_activity_author or "N/A",
            "Last_Updated_At": fmt_ts(last_activity_ts),
            "Last_Updated_Field": last_activity_field or "N/A",
            "Last_Assignee_Changed_By": last_assignee_author or "N/A",
            "Last_Assignee_Changed_At": fmt_ts(last_assignee_ts),
            "Last_Assignee_Set": last_assignee_name or "N/A",
            **custom_fields_map,
        })

    filename = f"issues_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    out_path = os.path.join(os.path.dirname(__file__), filename)

    base_fields = [
        "ID",
        "Summary",
        "Description",
        "Project_Name",
        "Project_Key",
        "Created_By",
        "Assignee",
        "Created_At",
        "Updated_At",
        "Resolved_At",
        "Last_State_Changed_By",
        "Last_State_Changed_At",
        "Current_State",
        "Last_Updated_By",
        "Last_Updated_At",
        "Last_Updated_Field",
        "Last_Assignee_Changed_By",
        "Last_Assignee_Changed_At",
        "Last_Assignee_Set",
    ]
    custom_fields_sorted = sorted(all_custom_names)
    fieldnames = base_fields + [name for name in custom_fields_sorted if name not in base_fields]
    with open(out_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in issues_data:
            writer.writerow(row)

    print(f"✓ Данные сохранены: {out_path}")
    if raw_dump:
        print("✓ Raw JSON сохранен рядом со скриптом (ytrek_issue_raw_*.json, ytrek_issue_activities_*.json)")


if __name__ == "__main__":
    main()
