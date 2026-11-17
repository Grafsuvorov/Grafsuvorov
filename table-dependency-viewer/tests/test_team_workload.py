import unittest
from datetime import datetime
from unittest.mock import patch

from api.services.team_workload import build_team_workload, load_team_workload, parse_origin

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
    def test_shkretov_four_tasks_from_custom_fields_with_and_without_snapshot(self):
        user = dict(id=10, email="Dmitriy.Shkretov@rusal.com", username="Shkretov", role="engineer", is_active=True)
        states = {"DWH-18285": "Зарегистрирована", "DWH-18275": "Зарегистрирована",
                  "DWH-17608": "Ожидание релиза", "DWH-18284": "Зарегистрирована"}
        fields = [dict(issue_id=key, field_name=name, field_value=value, dttm_loaded="2026-11-16 20:01:44")
                  for key, state in states.items() for name, value in [("Assignee", "Shkretov Dmitriy"), ("State", state)]]
        snapshots = [dict(issue_id=key, summary=key, assignee=None, current_state=None) for key in states]
        for rows in (snapshots, []):
            with self.subTest(has_snapshot=bool(rows)):
                data = build_team_workload([user], rows, [], custom_fields=fields, now=NOW)
                person = data["engineers"][0]
                self.assertEqual(person["open_count"], 4)
                self.assertEqual(person["closed_total"], 0)
                self.assertEqual({t["issue_id"]: t["state"] for t in data["tasks"]}, states)
                self.assertTrue(all(t["owner_id"] == 10 for t in data["tasks"]))
                self.assertTrue(all(t["identity_source"] == "person_name" for t in data["tasks"]))
                if not rows:
                    self.assertEqual(person["unknown_open"], 4)
                    self.assertTrue(all(t["category"] == "unknown" for t in data["tasks"]))

    def test_two_part_name_match_refuses_ambiguity_and_single_surname(self):
        users = [dict(id=i, email=email, username="user"+str(i), role="engineer", is_active=True)
                 for i, email in [(10, "Dmitriy.Shkretov@rusal.com"), (11, "Shkretov.Dmitriy@other.com")]]
        task = issue(); task["assignee"] = "Shkretov Dmitriy"
        data = build_team_workload(users, [task], [], now=NOW)
        self.assertIsNone(data["tasks"][0]["owner_id"])
        task["assignee"] = "Shkretov"
        data = build_team_workload(users[:1], [task], [], now=NOW)
        self.assertIsNone(data["tasks"][0]["owner_id"])

    def test_exact_worklog_identity_has_priority_over_inferred_name(self):
        users = [dict(id=i, email=email, username="user"+str(i), role="engineer", is_active=True)
                 for i, email in [(10, "Dmitriy.Shkretov@rusal.com"), (11, "Shkretov.Dmitriy@other.com")]]
        task = issue(); task["assignee"] = "Shkretov Dmitriy"
        data = build_team_workload(users, [task], [], now=NOW,
            identity_links=[dict(user_id=10, author="Shkretov Dmitriy")])
        self.assertEqual(data["tasks"][0]["owner_id"], 10)
        self.assertEqual(data["tasks"][0]["identity_source"], "exact")

    def test_newer_custom_state_and_assignee_override_stale_snapshot(self):
        task = issue(); task.update(current_state="Done", resolved_at="2026-11-01", dttm_loaded="2026-11-02")
        fields = [dict(issue_id="DWH-1", field_name="State", field_value="В работе", dttm_loaded="2026-11-16"),
                  dict(issue_id="DWH-1", field_name="Assignee", field_value="admin", dttm_loaded="2026-11-16")]
        data = build_team_workload(USERS, [task], [], now=NOW, custom_fields=fields)
        self.assertTrue(data["tasks"][0]["is_open"])
        self.assertEqual(data["tasks"][0]["owner_id"], 2)
        self.assertEqual(data["summary"]["closed_total"], 0)

    def test_older_custom_values_do_not_override_newer_snapshot(self):
        task = issue(); task.update(current_state="В работе", dttm_loaded="2026-11-17")
        fields = [dict(issue_id="DWH-1", field_name="State", field_value="Done", dttm_loaded="2026-11-01"),
                  dict(issue_id="DWH-1", field_name="Assignee", field_value="admin", dttm_loaded="2026-11-01")]
        data = build_team_workload(USERS, [task], [], now=NOW, custom_fields=fields)
        self.assertTrue(data["tasks"][0]["is_open"])
        self.assertEqual(data["tasks"][0]["owner_id"], 1)

    def test_closed_task_from_custom_fields_does_not_require_snapshot_or_worklog(self):
        fields = [dict(issue_id="DWH-1", field_name="State", field_value="Done"),
                  dict(issue_id="DWH-1", field_name="Assignee", field_value="ivan")]
        data = build_team_workload(USERS, [], [], now=NOW, custom_fields=fields)
        self.assertEqual(data["summary"]["closed_total"], 1)
        self.assertEqual(data["summary"]["closed_without_date"], 1)
        self.assertEqual(data["summary"]["open_count"], 0)

    def test_previous_call_signature_and_configured_tables(self):
        for env in ({}, {"TABLE_YT_ISSUE_TIMELINE": "custom.history", "TABLE_YT_ISSUE_CUSTOM": "custom.fields"}):
            with self.subTest(env=env), patch.dict("os.environ", env, clear=True):
                queries = []
                class EmptyResult:
                    def mappings(self): return self
                    def all(self): return []
                class Connection:
                    def execute(self, sql):
                        queries.append(sql)
                        return EmptyResult()
                # This is the exact older call shape shown in the server logs.
                data = load_team_workload(Connection(), text=lambda s: s, snapshot_table="snap",
                    worklog_table="logs", days=30, issue_url="https://yt/{id}")
                self.assertIn("FROM " + env.get("TABLE_YT_ISSUE_TIMELINE", "tech_etl.yt_issue_timeline"), queries[4])
                self.assertIn("FROM " + env.get("TABLE_YT_ISSUE_CUSTOM", "tech_etl.yt_issue_custom_field"), queries[5])
                self.assertEqual(data["tasks"], [])

    def test_all_supplied_states_without_resolved_timestamp(self):
        completed = ["Done", "Fixed", "Завершена"]
        cancelled = ["Duplicate", "Отклонено"]
        opened = ["DEV. Подготовлено к релизу", "New", "Open", "To do", "В работе", "Визуализация",
                  "Зарегистрирована", "Интеграция", "Ожидание релиза", "Отложена / в ожидании",
                  "Подлежит обсуждению", "Проверка / Тест", "ПРОД. Подлежит проверке",
                  "Системный анализ", "Требуется уточнение"]
        for state in completed + cancelled + opened:
            with self.subTest(state=state):
                task = issue(); task["current_state"] = f"  {state}  "
                data = report([task])
                expected = "completed" if state in completed else "cancelled" if state in cancelled else "open"
                self.assertEqual(data["tasks"][0]["status_group"], expected)
                self.assertEqual(data["summary"]["open_count"], int(expected == "open"))
                self.assertEqual(data["summary"]["closed_total"], int(expected != "open"))

    def test_reopened_state_overrides_old_resolved_date(self):
        task = issue(); task.update(current_state="В работе", resolved_at="2026-11-01")
        data = report([task])
        self.assertEqual(data["summary"]["open_count"], 1)
        self.assertEqual(data["summary"]["closed_count"], 0)
        self.assertIsNone(data["tasks"][0]["resolved_at"])

    def test_closed_without_date_is_visible_but_not_falsely_attributed_to_period(self):
        task = issue(); task.update(current_state="Done", updated_at="2026-11-16")
        data = report([task])
        self.assertEqual(data["summary"]["closed_total"], 1)
        self.assertEqual(data["summary"]["closed_count"], 0)
        self.assertEqual(data["summary"]["closed_without_date"], 1)
        self.assertIsNone(data["tasks"][0]["cycle_days"])

    def test_closure_date_from_transition_not_updated_at(self):
        task = issue(); task.update(current_state="Fixed", updated_at="2026-11-17")
        events = [dict(issue_id="DWH-1", event_type="State change", value_to="Fixed", ts="2026-11-01")]
        data = build_team_workload(USERS, [task], [], timelines=events, days=30, now=NOW)
        self.assertEqual(data["summary"]["closed_count"], 1)
        self.assertEqual(data["tasks"][0]["resolved_at"], "2026-11-01T00:00:00")
        self.assertEqual(data["tasks"][0]["closed_at_source"], "state_history")
        self.assertEqual(data["tasks"][0]["cycle_days"], 61)

    def test_cancelled_tasks_excluded_from_delivery_averages(self):
        task = issue(); task.update(current_state="Duplicate", resolved_at="2026-11-10")
        data = report([task], [work()])
        self.assertEqual(data["summary"]["closed_count"], 1)
        self.assertEqual(data["summary"]["cancelled_total"], 1)
        self.assertEqual(data["summary"]["hours"], 2)
        self.assertIsNone(data["summary"]["avg_task_hours"])
        self.assertIsNone(data["engineers"][0]["avg_cycle_days"])

    def test_executor_fallback_without_any_worklog_for_task(self):
        task = issue(); task["assignee"] = None
        events = [dict(issue_id="DWH-1", event_type="State change", value_to="В работе", author="YT Person", ts="2026-11-10")]
        data = build_team_workload(USERS, [task], [], identity_links=[dict(user_id=1, author="YT Person")],
                                   timelines=events, now=NOW)
        self.assertEqual(data["summary"]["open_count"], 1)
        self.assertEqual(data["tasks"][0]["owner_id"], 1)
        self.assertEqual(data["tasks"][0]["assignment_source"], "state_author")

    def test_explicit_assignee_is_not_replaced_by_old_state_author(self):
        events = [dict(issue_id="DWH-1", event_type="State change", value_to="В работе", author="admin", ts="2026-11-10")]
        data = build_team_workload(USERS, [issue()], [], timelines=events, now=NOW)
        self.assertEqual(data["tasks"][0]["owner_id"], 1)

    def test_unassignment_does_not_restore_old_executor(self):
        task = issue(); task["assignee"] = None
        events = [dict(issue_id="DWH-1", event_type="Assignee change", value_to=None, ts="2026-11-11"),
                  dict(issue_id="DWH-1", event_type="State change", value_to="В работе", author="ivan", ts="2026-11-10")]
        data = build_team_workload(USERS, [task], [], timelines=events, now=NOW)
        self.assertIsNone(data["tasks"][0]["owner_id"])

    def test_custom_field_assignee_without_logs(self):
        task = issue(); task["assignee"] = None
        data = build_team_workload(USERS, [task], [], now=NOW,
            custom_fields=[dict(issue_id="DWH-1", field_name="Исполнитель", field_value="admin")])
        self.assertEqual(data["tasks"][0]["owner_id"], 2)
        self.assertEqual(data["tasks"][0]["assignment_source"], "custom_field")

    def test_database_identity_join_uses_only_email_not_issue(self):
        task = issue(); task["assignee"] = "Person From Another Task"
        results = [USERS, [dict(user_id=1, author=task["assignee"])], [task], [], [], []]
        queries = []
        class Result:
            def __init__(self, rows): self.rows = rows
            def mappings(self): return self
            def all(self): return self.rows
        class Connection:
            def execute(self, sql):
                queries.append(sql)
                return Result(results[len(queries) - 1])
        data = load_team_workload(Connection(), text=lambda s: s, snapshot_table="snapshot", worklog_table="worklog",
                                 timeline_table="timeline", custom_table="custom", days=30, issue_url="https://yt/{id}")
        self.assertIn("INNER JOIN tech_etl.app_users", queries[1])
        self.assertIn("lower(trim(w.author_email)) = lower(trim(u.email))", queries[1])
        self.assertNotIn("issue_id", queries[1])
        self.assertEqual(data["tasks"][0]["owner_id"], 1)
        self.assertEqual(data["summary"]["open_count"], 1)

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
        self.assertEqual(data["daily"], [dict(day="2026-11-16", user_id=1, tech_etl=2, other=0, unknown=0)])

    def test_zero_activity_users_and_empty_data(self):
        data = report()
        self.assertEqual(data["summary"]["employees"], 3)
        self.assertEqual(len(data["engineers"]), 3)
        self.assertIsNone(data["summary"]["avg_task_hours"])
        self.assertEqual(data["tasks"], [])
        self.assertIsNone(data["snapshot_loaded_at"])


if __name__ == "__main__":
    unittest.main()
