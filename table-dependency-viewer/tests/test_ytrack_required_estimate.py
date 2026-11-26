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
