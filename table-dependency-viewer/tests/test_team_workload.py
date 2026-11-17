import unittest
from datetime import datetime

from api.services.team_workload import build_team_workload, parse_origin

NOW = datetime(2026, 11, 17, 12)
USERS = [
    dict(id=1, email="Ivan@company.ru", username="ivan", role="engineer", is_active=True),
    dict(id=2, email="admin@company.ru", username="admin", role="admin", is_active=True),
    dict(id=3, email="analyst@company.ru", username="analyst", role="analyst", is_active=True),
    dict(id=4, email="idle@company.ru", username="idle", role="engineer", is_active=False),
]
DESCRIPTION = """## MR
Email инициатора: analyst@company.ru
MR: https://git.example/merge_requests/2507
Родительская задача: DWH-18035
## Объект 1
Витрина: dm.table_one
Время выполнения SQL: 15.315 сек
## Объект 2
Витрина: dm.table_two
## Объект 3
Витрина: dm.table_one
"""


def issue(key="DWH-1", **kwargs):
    return dict(issue_id=key, summary="Test", description=DESCRIPTION,
                assignee="ivan", created_by="tech_etl", created_at="2026-09-01",
                updated_at="2026-10-01", resolved_at=None,
                dttm_loaded="2026-11-17", **kwargs)


def work(key="DWH-1", uid="Ivan@company.ru", minutes=120, when="2026-11-16", **kwargs):
    return dict(issue_id=key, author_email=uid, author="youtrack-login", minutes=minutes, work_date=when, **kwargs)


def report(issues=None, logs=None, users=None):
    return build_team_workload(USERS if users is None else users, issues or [], logs or [], days=30, now=NOW)


class TeamWorkloadTests(unittest.TestCase):
    def test_template_plain_and_bold_and_distinct_objects(self):
        for description in (DESCRIPTION, DESCRIPTION.replace("Витрина:", "**Витрина:**").replace("Email инициатора:", "**Email инициатора:**")):
            origin = parse_origin(dict(description=description, created_by="service"))
            self.assertEqual(origin["category"], "tech_etl")
            self.assertEqual(origin["objects"], ["dm.table_one", "dm.table_two"])
            self.assertEqual(origin["initiator_email"], "analyst@company.ru")
            self.assertEqual(origin["parent_issue"], "DWH-18035")

    def test_bot_without_template_and_other_task(self):
        self.assertEqual(parse_origin(dict(created_by="TECH_ETL", description=""))["category"], "tech_etl")
        self.assertEqual(parse_origin(dict(created_by="developer", description="MR: link"))["category"], "other")

    def test_hours_not_multiplied_by_number_of_objects(self):
        data = report([issue()], [work()])
        self.assertEqual(data["summary"]["hours"], 2)
        self.assertEqual(data["engineers"][0]["open_count"], 1)
        self.assertEqual(data["tasks"][0]["lifetime_hours"], 2)

    def test_author_bridge_assigns_login_even_without_time_on_owned_task(self):
        other = issue("DWH-2"); other["assignee"] = "youtrack-login"
        data = report([other], [work("DWH-1", uid=" ivan@COMPANY.ru ")])
        self.assertEqual(data["summary"]["open_count"], 1)
        self.assertEqual(data["tasks"][0]["owner_id"], 1)
        self.assertEqual(data["summary"]["orphan_hours"], 2)

    def test_initiator_and_worklog_contributor_not_counted_as_owner(self):
        data = report([issue()], [work(uid="admin@company.ru")])
        by_id = {r["user_id"]: r for r in data["engineers"]}
        self.assertEqual(by_id[1]["open_count"], 1)
        self.assertEqual(by_id[1]["hours"], 0)
        self.assertEqual(by_id[2]["open_count"], 0)
        self.assertEqual(by_id[2]["hours"], 2)
        self.assertNotIn(3, by_id)

    def test_open_portfolio_not_limited_to_window(self):
        data = report([issue()])
        self.assertEqual(data["summary"]["open_count"], 1)
        self.assertGreater(data["tasks"][0]["age_days"], 60)
        self.assertEqual(data["engineers"][0]["stale_count"], 1)

    def test_current_snapshot_after_reopening(self):
        old = issue(); old.update(resolved_at="2026-11-01", dttm_loaded="2026-11-02")
        data = report([old, issue()], [work()])
        self.assertEqual(len(data["tasks"]), 1)
        self.assertEqual(data["summary"]["closed_count"], 0)
        self.assertEqual(data["summary"]["open_count"], 1)

    def test_completed_effort_includes_prior_work_but_period_hours_do_not(self):
        closed = issue(); closed["resolved_at"] = "2026-11-10"
        without_time = issue("DWH-2"); without_time["resolved_at"] = "2026-11-12"
        data = report([closed, without_time], [work(when="2026-09-10"), work(uid="admin@company.ru", minutes=60)])
        person = next(r for r in data["engineers"] if r["user_id"] == 1)
        self.assertEqual(person["closed_count"], 2)
        self.assertEqual(person["hours"], 0)
        self.assertEqual(person["avg_task_hours"], 3)
        self.assertEqual(person["tracked_closed_count"], 1)
        self.assertEqual(data["summary"]["hours"], 1)
        self.assertEqual(data["summary"]["avg_task_hours"], 3)

    def test_deleted_worklog_does_not_bridge_or_contribute(self):
        task = issue(); task["assignee"] = "youtrack-login"
        data = report([task], [work(deleted_flag=True)])
        self.assertEqual(data["summary"]["hours"], 0)
        self.assertEqual(data["summary"]["unmatched_open"], 1)

    def test_unknown_email_must_not_fall_back_to_known_login(self):
        log = work(uid="someone@company.ru"); log["author"] = "ivan"
        data = report([issue()], [log])
        self.assertEqual(data["summary"]["unknown_author_hours"], 2)
        self.assertEqual(data["summary"]["hours"], 0)

    def test_ambiguous_login_is_unmatched(self):
        a = work(uid="ivan@company.ru")
        b = work(uid="admin@company.ru")
        task = issue(); task["assignee"] = "youtrack-login"
        data = report([task], [a, b])
        self.assertIsNone(data["tasks"][0]["owner_id"])
        self.assertEqual(data["summary"]["hours"], 4)
        self.assertEqual(data["summary"]["unmatched_open"], 1)

    def test_work_date_drives_daily_and_future_work_excluded(self):
        data = report([issue()], [work(), work(when="2026-12-01"), work(when=None)])
        self.assertEqual(data["summary"]["hours"], 2)
        self.assertEqual(data["daily"], [dict(day="2026-11-16", user_id=1, tech_etl=2, other=0)])

    def test_zero_activity_users_and_empty_data(self):
        data = report()
        self.assertEqual(data["summary"]["employees"], 3)
        self.assertEqual(len(data["engineers"]), 3)
        self.assertIsNone(data["summary"]["avg_task_hours"])
        self.assertEqual(data["tasks"], [])
        self.assertIsNone(data["snapshot_loaded_at"])


if __name__ == "__main__":
    unittest.main()
