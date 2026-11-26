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
