from __future__ import annotations

import ast
import json
import re
import unittest
from pathlib import Path
from posixpath import join as posix_join
from typing import Any


def _load_functions():
    source = Path("api/main.py").read_text(encoding="utf-8")
    module = ast.parse(source, filename="api/main.py")
    names = {
        "_prototype_item_needs_attention",
        "_prototype_review_dbt_registry_path",
        "_prototype_review_dbt_dq_path",
        "_prototype_review_dbt_key_list",
        "_prototype_review_build_dbt_dq_model",
        "_prototype_review_update_dbt_dq_model",
        "_prototype_review_build_dbt_registry_yaml",
    }
    nodes = [
        node for node in module.body
        if isinstance(node, ast.FunctionDef) and node.name in names
    ]
    isolated_module = ast.Module(body=nodes, type_ignores=[])
    namespace = {
        "Any": Any,
        "DBT_REGISTRY_ROOT": "dbt_greenplum_elt/models_metadata",
        "DBT_DQ_TECHNICAL_ROOT": "dbt_greenplum_elt/models/dq/technical",
        "posix_join": posix_join,
        "json": json,
        "re": re,
    }
    exec(compile(isolated_module, "api/main.py", "exec"), namespace)
    return namespace


class PrototypeReviewDbtRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.functions = _load_functions()

    def test_scd1_omits_version_key_distribution_and_empty_filter(self) -> None:
        build = self.functions["_prototype_review_build_dbt_registry_yaml"]

        content = build({
            "target_fqn": "dict_dds.address",
            "key_attributes": ["address_code", "international_display_format_code"],
            "scd_type": "scd1",
            "version_key": ["valid_from", "valid_to"],
            "filter": "",
        })

        self.assertNotIn("version_key:", content)
        self.assertNotIn("distributed_by:", content)
        self.assertNotIn("    filter:", content)
        self.assertNotIn("error_code:", content)
        self.assertIn("    - address_code\n    - international_display_format_code", content)
        self.assertIn("# наименование схемы", content)
        self.assertIn('check_type: "duplicates"', content)

    def test_scd2_includes_version_key_and_filter(self) -> None:
        build = self.functions["_prototype_review_build_dbt_registry_yaml"]

        content = build({
            "target_fqn": "dds.accounting_documents",
            "key_attributes": ["unit_balance_code", "fiscal_year"],
            "scd_type": "scd2",
            "version_key": ["dttm_from", "dttm_to"],
            "filter": "is_active is true",
        })

        self.assertIn("    - dttm_from\n    - dttm_to", content)
        self.assertIn('filter: "is_active is true"', content)
        self.assertIn("#Актуально только для scd_type: scd2", content)

    def test_scd2_requires_only_version_key_besides_unique_key(self) -> None:
        needs_attention = self.functions["_prototype_item_needs_attention"]

        required, missing = needs_attention({
            "object_type": "TABLE",
            "entity_name": "ACCOUNTING",
            "key_attributes": ["id"],
            "scd_type": "scd2",
            "version_key": [],
        })

        self.assertTrue(required)
        self.assertNotIn("дистрибуция", missing)
        self.assertIn("version key для SCD2", missing)

    def test_registry_path_is_scoped_by_schema(self) -> None:
        build_path = self.functions["_prototype_review_dbt_registry_path"]

        self.assertEqual(
            build_path("DDS", "Accounting_Documents"),
            "dbt_greenplum_elt/models_metadata/dds/dds.accounting_documents.yml",
        )

    def test_dq_path_uses_schema_table_mask(self) -> None:
        build_path = self.functions["_prototype_review_dbt_dq_path"]

        self.assertEqual(
            build_path("DDS", "Account_Debt_1C"),
            "dbt_greenplum_elt/models/dq/technical/dq_dds_s_account_debt_1c_s_duplicates.sql",
        )

    def test_new_dq_model_contains_review_keys(self) -> None:
        build = self.functions["_prototype_review_build_dbt_dq_model"]

        content = build({"key_attributes": ["dt_report", "unit_balance_code", "posting_uid_code_1c"]})

        self.assertIn(
            "check_columns      = ['dt_report', 'unit_balance_code', 'posting_uid_code_1c']",
            content,
        )
        self.assertIn("error_code         = 'dq_all0001'", content)
        self.assertIn("tags               = ['dq', 'technical', 'duplicates']", content)

    def test_existing_dq_model_changes_only_check_columns(self) -> None:
        update = self.functions["_prototype_review_update_dbt_dq_model"]
        original = """{{- config(
    error_code         = 'custom_code',
    check_columns      = ['old_key'],
    tags               = ['dq', 'technical', 'duplicates']
    ) -}}

-- custom model comment
select 1
"""

        updated = update(original, ["new_key", "second_key"])

        self.assertIn("check_columns      = ['new_key', 'second_key']", updated)
        self.assertIn("error_code         = 'custom_code'", updated)
        self.assertIn("-- custom model comment\nselect 1", updated)
        self.assertNotIn("old_key", updated)


if __name__ == "__main__":
    unittest.main()
