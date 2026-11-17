"""Exercise the loader without network access or optional database packages."""
import ast
import re
import unittest
from datetime import datetime, timezone
from pathlib import Path


def loader_functions(**overrides):
    tree = ast.parse(Path("scripts/ytrek_load_to_gp.py").read_text())
    namespace = dict(re=re, datetime=datetime, timezone=timezone,
                     YOUTRACK_URL="https://yt.example", ISSUE_FIELDS="issue-fields",
                     ACTIVITY_FIELDS="activities", ACTIVITY_CATEGORIES="categories",
                     WORKITEM_FIELDS="workitems", COMMENT_FIELDS="comments", text=lambda s: s)
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)]
    exec(compile(ast.Module(body=functions, type_ignores=[]), "loader", "exec"), namespace)
    namespace.update(overrides)
    return namespace


class Connection:
    def __init__(self):
        self.queries = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def begin(self):
        return self

    def execute(self, sql, values):
        self.queries.append((sql, values))


class TeamWorkloadLoaderTests(unittest.TestCase):
    def test_paginated_work_items_are_not_truncated(self):
        calls = []
        def api_get(url, params):
            calls.append(params)
            return list(range(100)) if params["$skip"] == 0 else [100, 101]
        ns = loader_functions(api_get=api_get)
        result = ns["api_get_all"]("workItems", {"fields": "author"})
        self.assertEqual(len(result), 102)
        self.assertEqual([c["$skip"] for c in calls], [0, 100])
        self.assertTrue(all(c["fields"] == "author" for c in calls))

    def test_multi_assignee_is_not_arbitrarily_attributed(self):
        ns = loader_functions()
        self.assertEqual(ns["get_assignee"]({"customFields": [dict(name="Исполнитель", value=[dict(login="a"), dict(login="b")])]}), {})

    def test_single_assignee_list(self):
        ns = loader_functions()
        self.assertEqual(ns["get_assignee"]({"customFields": [dict(name="Assignee", value=[dict(login="a")])]}), dict(login="a"))

    def test_loaded_snapshot_keeps_object_identifiers_and_author_email(self):
        issue = dict(id="internal-1", idReadable="DWH-1", summary="Review", description="**Витрина:** dm.sales_table\nMR: https://git.example/a_b",
                     reporter=dict(login="tech_etl"), customFields=[dict(name="Assignee", value=dict(login="yt-login", email="ivan@example.com"))])
        conn = Connection()
        ns = loader_functions()
        ns["api_get"] = lambda *_: issue
        ns["api_get_all"] = lambda url, params: [dict(author=dict(login="yt-login", email="ivan@example.com"), duration=dict(minutes=90), date=1794823200000)] if url.endswith("workItems") else []
        ns["load_issue"](conn, "DWH-1")
        snapshot = next(values[0] for sql, values in conn.queries if "INSERT INTO tech_etl.yt_issue_snapshot" in sql)
        worklog = next(values[0] for sql, values in conn.queries if "INSERT INTO tech_etl.yt_issue_worklog" in sql)
        self.assertEqual(snapshot["description"], issue["description"])
        self.assertEqual(snapshot["assignee"], "ivan@example.com")
        self.assertEqual(worklog["author_email"], "ivan@example.com")
        self.assertEqual(worklog["minutes"], 90)


if __name__ == "__main__":
    unittest.main()
