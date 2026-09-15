from __future__ import annotations

import ast
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
        "_prototype_review_build_dbt_registry_yaml",
    }
    nodes = [
        node for node in module.body
        if isinstance(node, ast.FunctionDef) and node.name in names
    ]
    isolated_module = ast.Module(body=nodes, type_ignores=[])
    namespace = {
        "Any": Any,
        "DBT_REGISTRY_ROOT": "dbt_greenplum_elt/registry",
        "posix_join": posix_join,
        "re": re,
        "_dump_yaml": lambda payload: payload,
    }
    exec(compile(isolated_module, "api/main.py", "exec"), namespace)
    return namespace


class PrototypeReviewDbtRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.functions = _load_functions()

    def test_scd1_omits_version_key_and_empty_filters(self) -> None:
        build = self.functions["_prototype_review_build_dbt_registry_yaml"]

        payload = build({
            "target_fqn": "dict_dds.address",
            "key_attributes": ["address_code", "international_display_format_code"],
            "distributed_by": "replicated",
            "scd_type": "scd1",
            "version_key": ["valid_from", "valid_to"],
            "filters": [],
        })

        self.assertNotIn("version_key", payload["relation"])
        self.assertNotIn("filters", payload["dq"][0])
        self.assertEqual(payload["relation"]["unique_key"], ["address_code", "international_display_format_code"])

    def test_scd2_includes_version_key_and_filters(self) -> None:
        build = self.functions["_prototype_review_build_dbt_registry_yaml"]

        payload = build({
            "target_fqn": "dds.accounting_documents",
            "key_attributes": ["unit_balance_code", "fiscal_year"],
            "distributed_by": "unit_balance_code, fiscal_year",
            "scd_type": "scd2",
            "version_key": ["dttm_from", "dttm_to"],
            "filters": ["is_active is true"],
        })

        self.assertEqual(payload["relation"]["version_key"], ["dttm_from", "dttm_to"])
        self.assertEqual(payload["dq"][0]["filters"], ["is_active is true"])

    def test_scd2_requires_version_key_and_distribution(self) -> None:
        needs_attention = self.functions["_prototype_item_needs_attention"]

        required, missing = needs_attention({
            "object_type": "TABLE",
            "entity_name": "ACCOUNTING",
            "key_attributes": ["id"],
            "distributed_by": "",
            "scd_type": "scd2",
            "version_key": [],
        })

        self.assertTrue(required)
        self.assertIn("дистрибуция", missing)
        self.assertIn("version key для SCD2", missing)

    def test_registry_path_is_scoped_by_schema(self) -> None:
        build_path = self.functions["_prototype_review_dbt_registry_path"]

        self.assertEqual(
            build_path("DDS", "Accounting_Documents"),
            "dbt_greenplum_elt/registry/dds/accounting_documents.yml",
        )


if __name__ == "__main__":
    unittest.main()
