import importlib
import sys
import types
import unittest


def _load_prototype_review_module():
    sqlalchemy_stub = types.ModuleType("sqlalchemy")
    sqlalchemy_stub.create_engine = lambda *args, **kwargs: None
    sqlalchemy_stub.text = lambda value: value
    sys.modules.setdefault("sqlalchemy", sqlalchemy_stub)

    entity_dev_meta_stub = types.ModuleType("api.services.entity_dev_meta")
    entity_dev_meta_stub._gitlab_json_request = lambda **kwargs: {}
    entity_dev_meta_stub._parse_gitlab_project = lambda value: value
    entity_dev_meta_stub._urlopen_without_proxy = lambda *args, **kwargs: None
    sys.modules.setdefault("api.services.entity_dev_meta", entity_dev_meta_stub)

    return importlib.import_module("api.services.prototype_review")


prototype_review = _load_prototype_review_module()
_is_clickhouse_sql_path = prototype_review._is_clickhouse_sql_path
infer_review_targets = prototype_review.infer_review_targets


class PrototypeReviewTests(unittest.TestCase):
    def test_is_clickhouse_sql_path_detects_clickhouse_subtree(self):
        self.assertTrue(_is_clickhouse_sql_path("clickhouse/dm/orders.sql"))
        self.assertTrue(_is_clickhouse_sql_path("schemas/clickhouse/dm/orders.sql"))
        self.assertFalse(_is_clickhouse_sql_path("gp/dm/orders.sql"))

    def test_infer_review_targets_skips_clickhouse_dev_execution(self):
        files = [
            {
                "path": "gp/dm/orders/sql_query_insert_init.sql",
                "sql": "insert into dm.orders select * from ods.source_table;",
                "statements": ["insert into dm.orders select * from ods.source_table"],
            },
            {
                "path": "clickhouse/dm/orders.sql",
                "sql": "create table dm.orders as select * from dm.orders_src;",
                "statements": ["create table dm.orders as select * from dm.orders_src"],
            },
        ]

        result = infer_review_targets(files)
        self.assertEqual(len(result), 1)

        item = result[0]
        self.assertEqual(item["target_fqn"], "dm.orders")
        self.assertEqual(
            item["execution_paths"],
            ["gp/dm/orders/sql_query_insert_init.sql"],
        )
        self.assertFalse(item["skip_dev_execution"])
        self.assertFalse(item["requires_pretruncate"])

    def test_infer_review_targets_skips_clickhouse_only_target(self):
        files = [
            {
                "path": "clickhouse/dm/orders.sql",
                "sql": "create table dm.orders as select * from dm.orders_src;",
                "statements": ["create table dm.orders as select * from dm.orders_src"],
            }
        ]

        result = infer_review_targets(files)

        self.assertEqual(len(result), 1)
        item = result[0]
        self.assertEqual(item["target_fqn"], "dm.orders")
        self.assertEqual(item["execution_paths"], [])
        self.assertTrue(item["skip_dev_execution"])
        self.assertFalse(item["requires_pretruncate"])


if __name__ == "__main__":
    unittest.main()
