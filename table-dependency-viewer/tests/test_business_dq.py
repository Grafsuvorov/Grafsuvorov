from __future__ import annotations

import unittest

from api.services.business_dq import (
    _business_dq_model,
    _business_dq_registry,
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


if __name__ == "__main__":
    unittest.main()
