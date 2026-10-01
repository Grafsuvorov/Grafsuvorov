from __future__ import annotations

import unittest

from api.services.business_dq import (
    _business_dq_model,
    _business_dq_registry,
    checks_from_merge_request,
    validate_checks,
)


class BusinessDqTemplateTests(unittest.TestCase):
    def test_builds_business_model_with_default_limit_and_unchanged_sql(self):
        build = _business_dq_model
        sql = "select delivery_code from dm.transportation where weight = 0"
        result = build({"error_code": "dq_le0001", "sql": sql}, "le", 100000)
        self.assertIn("error_code = 'dq_le0001'", result)
        self.assertIn("detail_store_limit = 100000", result)
        self.assertIn("tags = ['dq', 'le', 'business']", result)
        self.assertTrue(result.endswith(sql + "\n"))

    def test_allows_unlimited_detail_storage(self):
        build = _business_dq_model
        result = build({"error_code": "dq_fi0001", "sql": "select 1"}, "fi", "none")
        self.assertIn("detail_store_limit = none", result)

    def test_builds_dbt_registry_for_check_code(self):
        build = _business_dq_registry
        self.assertEqual(build("dq_le0002"), "relation:\n  schema_name: dm\n  table_name: dq_le0002\n  scd_type: scd1\n")

    def test_extracts_checks_and_click_view_from_merge_request(self):
        bundle = {
            "files": [
                {"path": "dq/data_quality_results/dq_le0002.sql", "sql": "select 2;"},
                {"path": "click/view.sql", "sql": "create or replace view dm_view.delivery as select 1"},
                {"path": "dq/data_quality_results/dq_le0001.sql", "content": "-- check\nselect 1;"},
            ],
            "mr": {"web_url": "https://gitlab.example/mr/1"},
        }
        calls = []

        def load_bundle(**kwargs):
            calls.append(kwargs)
            return bundle

        loaded, checks, area_code, views = checks_from_merge_request(
            "1",
            "LE",
            load_bundle=load_bundle,
            gitlab_api_url="https://gitlab.example/api",
            gitlab_project="etl",
            gitlab_token="token",
            gitlab_ssl_verify=True,
            default_project="analyst",
        )

        self.assertIs(loaded, bundle)
        self.assertEqual([item["error_code"] for item in checks], ["dq_le0001", "dq_le0002"])
        self.assertEqual(area_code, "le")
        self.assertEqual(views[0]["fqn"], "dm_view.delivery")
        self.assertEqual(calls[0]["default_project"], "analyst")

    def test_rejects_mutating_sql_before_opening_dev_connection(self):
        class EngineThatMustNotConnect:
            def connect(self):
                raise AssertionError("connection should not be opened")

        with self.assertRaisesRegex(ValueError, "допускается только SELECT"):
            validate_checks(
                [{"error_code": "dq_le0001", "sql": "delete from dm.orders"}],
                engine=EngineThatMustNotConnect(),
            )


if __name__ == "__main__":
    unittest.main()
