import io
import json
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit, parse_qs
from urllib.error import HTTPError

import test_prototype_review as fixtures

review = fixtures.prototype_review


class RequiredEstimateTests(unittest.TestCase):
    def test_estimate_on_next_project_fields_page_is_sent_during_creation(self):
        requests = []
        estimate = {"id": "173-515", "$type": "PeriodProjectCustomField",
                    "field": {"name": "Оценка (чел./час.)", "fieldType": {"id": "period", "valueType": "period"}}}

        def open_request(req, **kwargs):
            requests.append(req)
            if req.get_method() == "POST":
                return io.BytesIO(b'{"id":"2-1","idReadable":"SDS-1"}')
            skip = int(parse_qs(urlsplit(req.full_url).query)["$skip"][0])
            pages = {0: [{"id": "other", "field": {"name": "Other"}}], 1: [estimate], 2: []}
            return io.BytesIO(json.dumps(pages[skip], ensure_ascii=False).encode())

        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-42"), \
             patch.object(review, "_urlopen_without_proxy", side_effect=open_request):
            review.create_ytrack_issue(base_url="https://yt.example", project_id="0-42", project="ОХД",
                                      token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False,
                                      summary="Prototype", description="", default_estimate_minutes=60,
                                      assignee_query="")
        payload = json.loads(requests[-1].data)
        field = next(f for f in payload["customFields"] if f["id"] == "173-515")
        self.assertEqual(field["name"], "Оценка (чел./час.)")
        self.assertEqual(field["value"], {"minutes": 60})
        self.assertTrue(all(req.headers["Authorization"] == "Bearer ohd-token" for req in requests))

    def test_field_read_denied_stops_before_post_and_does_not_hide_failure(self):
        requests = []
        def denied(req, **kwargs):
            requests.append(req)
            raise HTTPError(req.full_url, 403, "Forbidden", {}, io.BytesIO(b"denied"))
        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-42"), \
             patch.object(review, "_urlopen_without_proxy", side_effect=denied):
            with self.assertRaisesRegex(ValueError, "HTTP 403"):
                review.create_ytrack_issue(base_url="https://yt.example", project_id="0-42", project="ОХД",
                                          token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False,
                                          summary="Prototype", description="")
        self.assertTrue(all(req.get_method() == "GET" for req in requests))

    def test_reference_issue_supplies_field_schema_but_not_values(self):
        requests = []
        reference = {"project": {"id": "0-83"}, "customFields": [
            {"id": "173-515", "name": "Оценка (чел./час.)", "$type": "SimpleIssueCustomField", "value": 8},
            {"id": "173-646", "name": "Дашборд КХД/Направление", "$type": "SimpleIssueCustomField", "value": "OLD direction"},
            {"id": "134-1948", "name": "Тип карточки", "$type": "SingleEnumIssueCustomField", "value": {"name": "Release Slot"}},
            {"id": "134-490", "name": "State", "$type": "StateMachineIssueCustomField", "value": {"name": "Завершена"}},
            {"id": "173-517", "name": "Дата релиза", "$type": "DateIssueCustomField", "value": 1792670400000},
        ]}
        def open_request(req, **kwargs):
            requests.append(req)
            if req.get_method() == "POST":
                value = {"idReadable": "SDS-544"}
            elif "/api/issues/SDS-543?" in req.full_url:
                value = reference
            else:
                value = []
            return io.BytesIO(json.dumps(value).encode())
        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-83"), \
             patch.object(review, "_urlopen_without_proxy", side_effect=open_request):
            result = review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                reference_issue="SDS-543", direction="LE-TR03 Shipping", direction_field_name="Дашборд КХД/Направление",
                default_estimate_minutes=60, assignee_query="")
        self.assertEqual(result["issue_id"], "SDS-544")
        payload = json.loads(requests[-1].data)
        custom = {f["name"]: f for f in payload["customFields"]}
        self.assertEqual(custom["Оценка (чел./час.)"]["value"], 1)
        self.assertEqual(custom["Оценка (чел./час.)"]["$type"], "SimpleIssueCustomField")
        self.assertEqual(custom["Дашборд КХД/Направление"]["value"], "LE-TR03 Shipping")
        self.assertEqual(custom["Тип карточки"]["value"], {"name": "Task"})
        self.assertNotIn("State", custom)
        self.assertNotIn("Дата релиза", custom)
        self.assertTrue(all(r.headers["Authorization"] == "Bearer ohd-token" for r in requests))

    def test_reference_in_another_project_never_creates_task(self):
        requests = []
        def open_request(req, **kwargs):
            requests.append(req)
            value = {"project": {"id": "0-30"}, "customFields": []} if "/api/issues/" in req.full_url else []
            return io.BytesIO(json.dumps(value).encode())
        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-83"), \
             patch.object(review, "_urlopen_without_proxy", side_effect=open_request):
            with self.assertRaisesRegex(ValueError, "другому проекту"):
                review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                    token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                    reference_issue="DWH-1")
        self.assertTrue(all(r.get_method() == "GET" for r in requests))

    def test_ohd_missing_reference_stops_before_sending_empty_estimate(self):
        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-83"), \
             patch.object(review, "_get_ytrack_project_custom_fields", return_value=[]), \
             patch.object(review, "_urlopen_without_proxy") as send:
            with self.assertRaisesRegex(ValueError, "задача-образец: не задана"):
                review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                    token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                    required_custom_fields=("Оценка (чел./час.)", "Дашборд КХД/Направление"))
            send.assert_not_called()

    def test_incomplete_admin_schema_uses_reference_before_post(self):
        schema = [{"id": "173-515", "$type": "SimpleIssueCustomField", "field": {
            "name": "Оценка (чел./час.)", "fieldType": {"valueType": "integer"}}}]
        with patch.object(review, "_resolve_ytrack_project_id", return_value="0-83"), \
             patch.object(review, "_get_ytrack_project_custom_fields", return_value=[{"id": "other", "field": {"name": "Other"}}]), \
             patch.object(review, "_get_ytrack_reference_custom_fields", return_value=schema) as reference, \
             patch.object(review, "_urlopen_without_proxy", return_value=io.BytesIO(b'{"idReadable":"SDS-1"}')) as send:
            review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                reference_issue="SDS-543", required_custom_fields=("Оценка (чел./час.)",), assignee_query="")
            reference.assert_called_once()
            payload = json.loads(send.call_args.args[0].data)
            self.assertEqual(payload["customFields"][0]["value"], 1)

    def test_verified_ohd_schema_matches_successful_manual_payload_without_metadata_apis(self):
        import importlib.util
        from pathlib import Path
        from api.services.prototype_review_youtrack_ohd import VERIFIED_FIELDS
        spec = importlib.util.spec_from_file_location("manual_ohd_payload", Path("scripts/ytrack_ohd_create_test_issue.py"))
        script = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(script)
        manual = script.build_payload(script.VERIFIED_OHD_FIELDS, "0-83", script.CONFIG)
        with patch.object(review, "_get_ytrack_project_custom_fields", side_effect=AssertionError("No admin fields API")), \
             patch.object(review, "_get_ytrack_reference_custom_fields", side_effect=AssertionError("No reference issue API")), \
             patch.object(review, "_urlopen_without_proxy", return_value=io.BytesIO(b'{"idReadable":"SDS-548"}')) as send:
            result = review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                custom_fields_override=VERIFIED_FIELDS, custom_fields_project_id="0-83",
                required_custom_fields=("Оценка (чел./час.)", "Дашборд КХД/Направление", "Тип карточки"),
                direction="LE-TR03 Shipping", direction_field_name="Дашборд КХД/Направление", assignee_query="")
        self.assertEqual(result["issue_id"], "SDS-548")
        send.assert_called_once()
        request = send.call_args.args[0]
        payload = json.loads(request.data)
        self.assertEqual(payload["customFields"], manual["customFields"])
        self.assertEqual(payload["project"], manual["project"])
        self.assertEqual(payload["queue"], manual["queue"])
        self.assertEqual(payload["type"], "task")
        self.assertEqual(request.headers["Authorization"], "Bearer ohd-token")

    def test_verified_schema_cannot_be_used_for_another_project(self):
        from api.services.prototype_review_youtrack_ohd import VERIFIED_FIELDS
        with patch.object(review, "_urlopen_without_proxy") as send:
            with self.assertRaisesRegex(ValueError, "не соответствует проекту"):
                review.create_ytrack_issue(base_url="https://yt.example", project_id="0-30", project="КХД",
                    token="token", queue="DWH", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                    custom_fields_override=VERIFIED_FIELDS, custom_fields_project_id="0-83")
            send.assert_not_called()

    def test_verified_ohd_keeps_assignee_and_release_date(self):
        from api.services.prototype_review_youtrack_ohd import VERIFIED_FIELDS
        with patch.object(review, "_resolve_ytrack_user_value", return_value={"login": "Engineer"}) as user, \
             patch.object(review, "_urlopen_without_proxy", return_value=io.BytesIO(b'{"idReadable":"SDS-548"}')) as send:
            review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                token="ohd-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                custom_fields_override=VERIFIED_FIELDS, custom_fields_project_id="0-83",
                assignee_query="engineer@example.com", release_date="2026-11-26")
        payload = json.loads(send.call_args.args[0].data)
        custom = {field["id"]: field for field in payload["customFields"]}
        self.assertEqual(custom["135-769"]["value"], {"login": "Engineer"})
        self.assertEqual(custom["173-517"]["$type"], "DateIssueCustomField")
        self.assertIsInstance(custom["173-517"]["value"], int)
        self.assertGreater(custom["173-517"]["value"], 0)
        self.assertEqual(user.call_args.kwargs["token"], "ohd-token")

    def test_failed_post_reports_actual_schema_and_estimate_without_token(self):
        from api.services.prototype_review_youtrack_ohd import VERIFIED_FIELDS
        def rejected(req, **kwargs):
            raise HTTPError(req.full_url, 400, "Bad Request", {}, io.BytesIO(b'Field required secret-token'))
        with patch.object(review, "_urlopen_without_proxy", side_effect=rejected):
            with self.assertRaises(ValueError) as raised:
                review.create_ytrack_issue(base_url="https://yt.example", project_id="0-83", project="ОХД",
                    token="secret-token", queue="SDS", issue_type="task", ssl_verify=False, summary="Prototype", description="",
                    custom_fields_override=VERIFIED_FIELDS, custom_fields_project_id="0-83",
                    direction="LE-TR03 Shipping", direction_field_name="Дашборд КХД/Направление", assignee_query="")
        message = str(raised.exception)
        self.assertIn("ytrack-create-v2", message)
        diagnostic = json.loads(message.split("Диагностика запроса: ", 1)[1])
        self.assertEqual(diagnostic["schema"], "verified_ohd")
        self.assertEqual(diagnostic["estimate"]["id"], "173-515")
        self.assertEqual(diagnostic["estimate"]["value"], 1)
        self.assertEqual(diagnostic["project_id"], "0-83")
        self.assertNotIn("secret-token", message)
