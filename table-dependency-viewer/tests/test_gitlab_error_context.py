import io
import unittest
from urllib.error import HTTPError
from unittest.mock import patch

import test_prototype_review as fixtures
from api.services import gitlab_delivery


class GitLabErrorContextTests(unittest.TestCase):
    def not_found(self, request, **kwargs):
        raise HTTPError(request.full_url, 404, "Not Found", {}, io.BytesIO(b'{"message":"404 Not Found"}'))

    def test_missing_mr_reports_project_and_endpoint_without_token(self):
        with patch.object(fixtures.entity_dev_meta, "_urlopen_without_proxy", side_effect=self.not_found), \
             self.assertRaises(ValueError) as error:
            fixtures.entity_dev_meta._gitlab_json_request(api_url="https://git.example/api/v4", project="analyst/sql",
                token="private-secret-token", ssl_verify=True, path="merge_requests/2507")
        message = str(error.exception)
        self.assertIn("GitLab вернул 404", message)
        self.assertIn("GET /projects/analyst%2Fsql/merge_requests/2507", message)
        self.assertIn("проект: analyst/sql", message)
        self.assertNotIn("private-secret-token", message)

    def test_file_404_reports_ref_and_still_means_missing_optional_file(self):
        with patch.object(fixtures.entity_dev_meta, "_urlopen_without_proxy", side_effect=self.not_found), \
             self.assertRaises(ValueError) as error:
            fixtures.entity_dev_meta._gitlab_json_request(api_url="https://git.example/api/v4", project="dwh/dbt",
                token="secret", ssl_verify=True, path="repository/files/ods%2Fods.table.yml", query={"ref": "main"})
        self.assertIn("ref: main", str(error.exception))
        with patch.object(gitlab_delivery, "_gitlab_json_request", side_effect=error.exception):
            self.assertIsNone(gitlab_delivery.file_content(project="dwh/dbt", token="secret", file_path="ods/ods.table.yml", ref="main"))
            self.assertFalse(gitlab_delivery.resource_exists(project="dwh/dbt", token="secret", path="repository/branches/new"))
