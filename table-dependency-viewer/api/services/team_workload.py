"""Team workload: ownership and personal work logs are counted independently."""
from __future__ import annotations

import re
from collections import defaultdict
from datetime import datetime, timedelta
from statistics import mean, median


def _dt(value):
    if not value:
        return None
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace("Z", "+00:00"))
    # Warehouse timestamps are local timestamp without time zone.
    return value.replace(tzinfo=None)


def _norm(value):
    return str(value or "").strip().casefold()


def parse_origin(issue):
    description = str(issue.get("description") or "").replace("**", "")
    def field(label):
        match = re.search(rf"^\s*{label}:\s*(.+)$", description, re.M | re.I)
        return match.group(1).strip().strip("`") if match else None
    objects = list(dict.fromkeys(re.findall(
        r"^\s*Витрина:\s*`?([\w]+\.[\w]+)", description, re.M | re.I
    )))
    initiator = field("Email инициатора")
    mr = field("MR")
    template = bool(initiator and mr and objects)
    creator = _norm(issue.get("created_by"))
    bot = creator.split("@", 1)[0] == "tech_etl"
    return {
        "category": "tech_etl" if template or bot else "other",
        "origin_evidence": "Шаблон Tech ETL" if template else "Автор tech_etl" if bot else "Другие задачи",
        "initiator_email": initiator,
        "mr_url": mr if mr and mr.startswith("https://") else None,
        "parent_issue": field("Родительская задача"),
        "objects": objects,
    }


def build_team_workload(users, issues, worklogs, *, days=30, now=None, issue_url="https://yt.rusal.ru/issue/{id}"):
    now = _dt(now or datetime.now())
    start = (now - timedelta(days=days - 1)).replace(hour=0, minute=0, second=0, microsecond=0)
    weekdays = sum((start + timedelta(days=i)).weekday() < 5 for i in range(days))
    users = [dict(u) for u in users if u["role"] in ("engineer", "admin")]
    by_id = {u["id"]: u for u in users}
    aliases = defaultdict(set)
    for u in users:
        for alias in (u.get("email"), u.get("username")):
            if _norm(alias):
                aliases[_norm(alias)].add(u["id"])
    # Worklog is an explicit bridge between YouTrack login and application email.
    emails = defaultdict(set)
    for u in users:
        emails[_norm(u.get("email"))].add(u["id"])
    worklogs = [dict(w) for w in worklogs if not w.get("deleted_flag")]
    for w in worklogs:
        ids = emails.get(_norm(w.get("author_email")), set())
        if len(ids) == 1 and _norm(w.get("author")):
            aliases[_norm(w["author"])].update(ids)
    def resolve(value):
        ids = aliases.get(_norm(value), set())
        return next(iter(ids)) if len(ids) == 1 else None
    def work_author(w):
        # An explicit but unknown email must never fall back to a different login.
        email = _norm(w.get("author_email"))
        if email:
            ids = emails.get(email, set())
            return next(iter(ids)) if len(ids) == 1 else None
        return resolve(w.get("author"))

    latest = {}
    for issue in issues:
        issue = dict(issue)
        key = issue["issue_id"]
        rank = (_dt(issue.get("dttm_loaded")) or datetime.min, _dt(issue.get("updated_at")) or datetime.min)
        previous = latest.get(key)
        if previous is None or rank > previous[0]:
            latest[key] = (rank, issue)
    logs = defaultdict(list)
    for w in worklogs:
        logs[w["issue_id"]].append(w)
    tasks = []
    daily = defaultdict(lambda: {"tech_etl": 0, "other": 0})
    unknown_hours = 0
    orphan_hours = 0
    for w in worklogs:
        when = _dt(w.get("work_date"))
        if when and start <= when <= now and w["issue_id"] not in latest:
            orphan_hours += max(float(w.get("minutes") or 0), 0) / 60
    for _, issue in latest.values():
        created = _dt(issue.get("created_at"))
        resolved = _dt(issue.get("resolved_at"))
        updated = _dt(issue.get("updated_at"))
        closed_in_period = bool(resolved and start <= resolved <= now)
        open_task = resolved is None
        owner = resolve(issue.get("assignee"))
        origin = parse_origin(issue)
        personal = defaultdict(lambda: {"hours": 0, "lifetime_hours": 0})
        period_hours = 0
        lifetime_hours = 0
        for w in logs[issue["issue_id"]]:
            uid = work_author(w)
            hours = max(float(w.get("minutes") or 0), 0) / 60
            when = _dt(w.get("work_date"))
            in_period = bool(when and start <= when <= now)
            lifetime_hours += hours
            if uid is not None:
                personal[uid]["lifetime_hours"] += hours
            if in_period:
                period_hours += hours
                if uid is None:
                    unknown_hours += hours
                else:
                    personal[uid]["hours"] += hours
                    daily[(when.date().isoformat(), uid)][origin["category"]] += hours
        # Keep all open tasks, recent completions and tasks with work in the window.
        if not (open_task or closed_in_period or period_hours):
            continue
        tasks.append({
            "issue_id": issue["issue_id"], "summary": issue.get("summary") or issue["issue_id"],
            "url": issue_url.replace("{id}", issue["issue_id"]),
            "state": issue.get("current_state") or "Не указан", "assignee": issue.get("assignee"),
            "owner_id": owner, "owner_name": by_id[owner]["username"] if owner is not None else None,
            "created_by": issue.get("created_by"), **origin,
            "created_at": created.isoformat() if created else None,
            "updated_at": updated.isoformat() if updated else None,
            "resolved_at": resolved.isoformat() if resolved else None,
            "is_open": open_task, "closed_in_period": closed_in_period,
            "age_days": max((now - created).total_seconds() / 86400, 0) if created and open_task else None,
            "cycle_days": max((resolved - created).total_seconds() / 86400, 0) if created and resolved else None,
            "stale_days": max((now - (updated or created)).total_seconds() / 86400, 0) if open_task and (updated or created) else None,
            "hours": period_hours, "lifetime_hours": lifetime_hours,
            "contributions": [{"user_id": uid, **values} for uid, values in personal.items()],
        })
    rows = []
    for u in users:
        owned = [t for t in tasks if t["owner_id"] == u["id"]]
        opened = [t for t in owned if t["is_open"]]
        closed = [t for t in owned if t["closed_in_period"]]
        contributions = [(t, c) for t in tasks for c in t["contributions"] if c["user_id"] == u["id"]]
        tracked_closed = [t for t in closed if t["lifetime_hours"] > 0]
        cycles = [t["cycle_days"] for t in closed if t["cycle_days"] is not None]
        hours = sum(c["hours"] for _, c in contributions)
        rows.append({
            "user_id": u["id"], "engineer": u["username"], "email": u["email"],
            "role": u["role"], "is_active": u["is_active"],
            "open_count": len(opened), "tech_etl_open": sum(t["category"] == "tech_etl" for t in opened),
            "other_open": sum(t["category"] == "other" for t in opened), "closed_count": len(closed),
            "stale_count": sum(t["stale_days"] is not None and t["stale_days"] >= 14 for t in opened),
            "oldest_days": max((t["age_days"] or 0 for t in opened), default=0),
            "hours": hours,
            "tech_etl_hours": sum(c["hours"] for t, c in contributions if t["category"] == "tech_etl"),
            "other_hours": sum(c["hours"] for t, c in contributions if t["category"] == "other"),
            "worked_tasks": sum(c["hours"] > 0 for _, c in contributions),
            # Full task effort, across all authors, only completed tasks with recorded time.
            "avg_task_hours": mean(t["lifetime_hours"] for t in tracked_closed) if tracked_closed else None,
            "tracked_closed_count": len(tracked_closed),
            "avg_cycle_days": mean(cycles) if cycles else None,
            "median_cycle_days": median(cycles) if cycles else None,
        })
    rows.sort(key=lambda u: (-u["open_count"], -u["hours"], u["engineer"]))
    loaded = [_dt(s.get("dttm_loaded")) for _, s in latest.values() if s.get("dttm_loaded")]
    owned_tasks = [t for t in tasks if t["owner_id"] is not None]
    completed = [t for t in owned_tasks if t["closed_in_period"]]
    measured = [t for t in completed if t["lifetime_hours"] > 0]
    return {
        "days": days, "period_start": start.isoformat(), "period_end": now.isoformat(),
        "working_days": weekdays, "snapshot_loaded_at": max(loaded).isoformat() if loaded else None,
        "oldest_snapshot_at": min(loaded).isoformat() if loaded else None,
        "summary": {
            "employees": len(users), "open_count": sum(t["is_open"] for t in owned_tasks),
            "closed_count": len(completed), "hours": sum(u["hours"] for u in rows),
            "tech_etl_open": sum(t["is_open"] and t["category"] == "tech_etl" for t in owned_tasks),
            "other_open": sum(t["is_open"] and t["category"] == "other" for t in owned_tasks),
            "avg_task_hours": mean(t["lifetime_hours"] for t in measured) if measured else None,
            "tracked_closed_count": len(measured),
            "unmatched_open": sum(t["is_open"] and t["owner_id"] is None for t in tasks),
            "unknown_author_hours": unknown_hours, "orphan_hours": orphan_hours,
        },
        "engineers": rows, "tasks": tasks,
        "daily": [{"day": day, "user_id": uid, **values} for (day, uid), values in sorted(daily.items())],
    }


def load_team_workload(conn, *, text, snapshot_table, worklog_table, days, issue_url):
    users = conn.execute(text("""
        SELECT id, email, username, role, is_active FROM tech_etl.app_users
        WHERE role IN ('engineer', 'admin')
    """)).mappings().all()
    # row_to_json keeps compatibility with older worklog tables without email/deleted_flag.
    issues = conn.execute(text(f"""
        SELECT DISTINCT ON (issue_id) issue_id, summary, description, assignee,
               created_by, current_state, created_at, updated_at, resolved_at, dttm_loaded
        FROM {snapshot_table}
        ORDER BY issue_id, dttm_loaded DESC NULLS LAST, updated_at DESC NULLS LAST
    """)).mappings().all()
    worklogs = conn.execute(text(f"""
        SELECT w.issue_id, w.author, row_to_json(w)->>'author_email' AS author_email,
               w.work_date, w.minutes
        FROM {worklog_table} w
        WHERE COALESCE((row_to_json(w)->>'deleted_flag')::boolean, false) = false
    """)).mappings().all()
    return build_team_workload(users, issues, worklogs, days=days, issue_url=issue_url)
