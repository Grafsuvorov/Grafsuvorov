import contextlib
from copy import deepcopy
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ohd_create_test", Path("scripts/ytrack_ohd_create_test_issue.py"))
script = importlib.util.module_from_spec(spec)
spec.loader.exec_module(script)

FIELDS = [{"id": "173-515", "$type": "PeriodProjectCustomField",
           "field": {"name": "Оценка (чел./час.)", "fieldType": {"id": "period", "valueType": "period"}}},
          {"id": "173-2", "$type": "EnumProjectCustomField", "field": {"name": "Тип карточки"}}]


class OhdCreateTestIssueTests(unittest.TestCase):
    def test_empty_admin_fields_uses_reference_and_sends_numeric_estimate_without_copying_state(self):
        reference = {"project": {"id": "0-83"}, "customFields": [
            {"id": "173-515", "name": "Оценка (чел./час.)", "$type": "SimpleIssueCustomField", "value": 0},
            {"id": "134-1948", "name": "Тип карточки", "$type": "SingleEnumIssueCustomField", "value": {"name": "Task"}},
            {"id": "134-490", "name": "State", "$type": "StateMachineIssueCustomField", "value": {"name": "Завершена"}},
            {"id": "135-769", "name": "Assignee", "$type": "SingleUserIssueCustomField", "value": {"login": "another-user"}},
        ]}
        with patch.object(script, "CONFIG", {**script.CONFIG, "token": "secret"}), \
             patch.object(script, "Api") as api_type, patch.object(script, "project_id", return_value="0-83"), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            api = api_type.return_value
            api.list_all.return_value = []
            api.call.return_value = reference
            self.assertEqual(script.main(["--dry-run"]), 0)
            api.call.assert_called_once()
            self.assertEqual(api.call.call_args.args[:2], ("GET", "/api/issues/SDS-471"))
        payload = script.build_payload(script.fields_from_reference(reference, "0-83"), "0-83", script.CONFIG)
        estimate = payload["customFields"][0]
        self.assertEqual(estimate["$type"], "SimpleIssueCustomField")
        self.assertEqual(estimate["value"], 1)
        self.assertEqual([f["name"] for f in payload["customFields"]], ["Оценка (чел./час.)", "Тип карточки"])

    def test_reference_from_another_project_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "другому проекту"):
            script.fields_from_reference({"project": {"id": "0-30"}, "customFields": []}, "0-83")

    def test_issue_fields_uses_issue_api_and_never_creates_issue(self):
        with patch.object(script, "CONFIG", {**script.CONFIG, "token": "secret"}), \
             patch.object(script, "Api") as api_type, patch.object(script, "project_id", return_value="0-83"), \
             contextlib.redirect_stdout(io.StringIO()):
            api = api_type.return_value
            api.call.return_value = {"project": {"id": "0-83"}, "customFields": []}
            self.assertEqual(script.main(["--issue-fields", "SDS-471"]), 0)
            api.call.assert_called_once()
            self.assertEqual(api.call.call_args.args[:2], ("GET", "/api/issues/SDS-471"))
            api.list_all.assert_not_called()

    def test_exact_workflow_id_is_required_instead_of_picking_another_estimate(self):
        config = deepcopy(script.CONFIG)
        with self.assertRaisesRegex(ValueError, "173-515"):
            script.build_payload([{**FIELDS[0], "id": "another-field"}, FIELDS[1]], "0-42", config)
        payload = script.build_payload(FIELDS, "0-42", config)
        estimate = payload["customFields"][0]
        self.assertEqual(estimate["id"], "173-515")
        self.assertEqual(estimate["$type"], "PeriodIssueCustomField")
        self.assertEqual(estimate["value"], {"minutes": 60})

    def test_manual_type_value_and_identifier_can_be_tested(self):
        config = {**deepcopy(script.CONFIG), "field_identifier": "name",
                  "estimate_type_override": "SimpleIssueCustomField", "estimate_value_override_enabled": True,
                  "estimate_value_override": 1}
        estimate = script.build_payload(FIELDS, "0-42", config)["customFields"][0]
        self.assertNotIn("id", estimate)
        self.assertEqual(estimate["value"], 1)
        self.assertEqual(estimate["$type"], "SimpleIssueCustomField")

    def test_dry_run_and_fields_never_post_and_normal_run_posts_once(self):
        for args in (["--dry-run"], ["--fields"], []):
            with self.subTest(args=args), patch.object(script, "CONFIG", {**script.CONFIG, "token": "secret"}), \
                 patch.object(script, "Api") as api_type, patch.object(script, "project_id", return_value="0-42"), \
                 contextlib.redirect_stdout(io.StringIO()):
                api = api_type.return_value
                api.base = "https://yt.example"
                api.list_all.return_value = FIELDS
                api.call.return_value = {"id": "2-1", "idReadable": "SDS-1"}
                self.assertEqual(script.main(args), 0)
                posts = [c for c in api.call.call_args_list if c.args[0] == "POST"]
                self.assertEqual(len(posts), 0 if args else 1)

    def test_failed_post_is_not_retried_and_token_is_redacted(self):
        output = io.StringIO()
        with patch.object(script, "CONFIG", {**script.CONFIG, "token": "secret-token"}), \
             patch.object(script, "Api") as api_type, patch.object(script, "project_id", return_value="0-42"), \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(output):
            api = api_type.return_value
            api.list_all.return_value = FIELDS
            api.call.side_effect = ValueError('HTTP 400 error_issue_id=2-1 secret-token')
            self.assertEqual(script.main([]), 1)
            api.call.assert_called_once()
        self.assertNotIn("secret-token", output.getvalue())
        self.assertIn("error_issue_id", output.getvalue())
