import contextlib
import importlib.util
import io
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ytrack_find_project", Path("scripts/ytrack_find_project.py"))
lookup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lookup)


class YouTrackProjectLookupTests(unittest.TestCase):
    def test_inline_token_overrides_env_and_is_redacted_on_error(self):
        output = io.StringIO()
        with patch.object(lookup, "SCRIPT_YOUTRACK_TOKEN", " inline-secret "), \
             patch.dict(os.environ, {"YOUTRACK_TOKEN": "env-secret"}, clear=True), \
             patch.object(lookup, "load_env"), \
             patch.object(lookup, "YouTrack", side_effect=ValueError("inline-secret env-secret")) as client, \
             contextlib.redirect_stderr(output):
            self.assertEqual(lookup.main(["--issue", "SDS-471"]), 1)
        self.assertEqual(client.call_args.args[1], "inline-secret")
        self.assertNotIn("inline-secret", output.getvalue())
        self.assertNotIn("env-secret", output.getvalue())

    def test_known_issue_reads_actual_project_without_admin_api(self):
        client = lookup.YouTrack("https://yt.example", "secret", True)
        expected = {"id": "0-42", "shortName": "SDS", "name": "ОХД"}
        with patch.object(client, "get", return_value={"project": expected}) as get:
            self.assertEqual(client.project_from_issue("https://yt.example/issue/SDS-471/title"), expected)
        self.assertEqual(get.call_args.args[0], "/api/issues/SDS-471")
        with self.assertRaises(ValueError):
            client.project_from_issue("https://yt.example/not-an-issue")

    def test_projects_are_paginated_even_when_page_is_short(self):
        client = lookup.YouTrack("https://yt.example", "secret", True)
        first = [{"id": "0-1", "name": "КХД", "shortName": "DWH"}]
        second = [{"id": "0-2", "name": "ОХД", "shortName": "SDS"}]
        with patch.object(client, "get", side_effect=[first, second, []]) as get:
            self.assertEqual(client.projects(), first + second)
        self.assertEqual([c.args[1]["$skip"] for c in get.call_args_list], [0, 1, 2])

    def test_exact_code_wins_over_partial_name_and_partial_search_is_supported(self):
        projects = [{"id": "0-1", "shortName": "SDS", "name": "ОХД"},
                    {"id": "0-2", "shortName": "OTHER", "name": "SDS архив"}]
        self.assertEqual(lookup.find_projects(projects, "sds"), projects[:1])
        self.assertEqual(lookup.find_projects(projects, "архив"), projects[1:])

    def test_cli_prints_real_project_id_and_queue_without_token(self):
        output = io.StringIO()
        with patch.dict(os.environ, {"YOUTRACK_TOKEN": "secret-token"}, clear=True), \
             patch.object(lookup, "load_env"), \
             patch.object(lookup.YouTrack, "get", return_value={"project": {"id": "0-42", "shortName": "SDS", "name": "ОХД"}}), \
             contextlib.redirect_stdout(output):
            self.assertEqual(lookup.main(["--issue", "SDS-471"]), 0)
        self.assertIn("OHD_YOUTRACK_PROJECT_ID=0-42", output.getvalue())
        self.assertIn("OHD_YOUTRACK_QUEUE=SDS", output.getvalue())
        self.assertNotIn("secret-token", output.getvalue())
