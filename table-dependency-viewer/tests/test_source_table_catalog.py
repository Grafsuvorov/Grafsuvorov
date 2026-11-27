import unittest
from unittest.mock import MagicMock
import test_prototype_review
from api.services.stg_source_loader import list_target_tables


class SourceTableCatalogTests(unittest.TestCase):
    def test_catalog_preserves_case_and_key_order_and_omits_technical_fields(self):
        rows = [{"table_name": "s1c_Mixed", "column_name": name, "ordinal_position": pos,
                 "primary_key_positions": [2, 1]} for pos, name in enumerate(["ID", "/BIC/KEY", "RN", "DTTM_UPDATED"], 1)]
        rows.append({"table_name": "TechOnly", "column_name": "DTTM_UPDATED", "ordinal_position": 1, "primary_key_positions": None})
        engine = MagicMock()
        conn = engine.connect.return_value.__enter__.return_value
        conn.execute.return_value.mappings.return_value.all.return_value = rows
        result = list_target_tables(engine, "stg")
        self.assertEqual(result[0], {"table_name": "s1c_Mixed", "fields": "ID,/BIC/KEY", "primary_key": '"/BIC/KEY" || "ID"'})
        self.assertEqual(result[1]["table_name"], "TechOnly")
        self.assertEqual(result[1]["fields"], "")
        statement, params = conn.execute.call_args.args
        self.assertIn("pg_catalog.pg_attribute", str(statement))
        self.assertNotIn("pg_total_relation_size", str(statement))
        self.assertEqual(params, {"schema_name": "stg", "table_name": None})

    def test_single_target_lookup_is_bound_and_does_not_read_whole_schema(self):
        engine = MagicMock()
        conn = engine.connect.return_value.__enter__.return_value
        conn.execute.return_value.mappings.return_value.all.return_value = []
        self.assertEqual(list_target_tables(engine, "STG", '"BIP_/BIC/NAME"'), [])
        self.assertEqual(conn.execute.call_args.args[1], {"schema_name": "stg", "table_name": "BIP_/BIC/NAME"})

    def test_invalid_schema_does_not_query_database(self):
        engine = MagicMock()
        with self.assertRaises(ValueError):
            list_target_tables(engine, "public")
        engine.connect.assert_not_called()

    def test_ohd_target_details_read_source_arguments_from_ohd_sql(self):
        import ast
        from contextlib import contextmanager
        from pathlib import Path
        from types import SimpleNamespace
        from api.services.stg_source_loader import source_loader_parameters_from_sql
        node = next(n for n in ast.parse(Path("api/main.py").read_text()).body
                    if isinstance(n, ast.FunctionDef) and n.name == "get_admin_prototype_source_table_details")
        calls = []
        @contextmanager
        def source_engine(mode):
            self.assertEqual(mode, "ohd")
            yield "ohd-engine"
        sql = "SELECT loader(v_source_schema_name := 'SAPSR3', v_source_table_name := '/BIC/TABLE', v_pk := '\"ID\"', v_server_id := '2');"
        def physical(engine, schema, table):
            self.assertEqual((engine, schema, table), ("ohd-engine", "stg", "existingmixed"))
            return [{"table_name": "ExistingMixed", "fields": "ID,KEY", "primary_key": ""}]
        namespace = {"__package__": "api", "Request": object,
            "_require_authenticated": lambda _: SimpleNamespace(email="user@example.com"),
            "_prototype_source_engine": source_engine, "list_target_tables": physical,
            "ohd_settings": lambda: {"project": "ohd/dbt", "token": "ohd-token", "api_url": "https://ohd.example/api/v4", "ssl_verify": False},
            "_prototype_gitlab_file_content": lambda **kw: calls.append(kw) or sql,
            "source_loader_parameters_from_sql": source_loader_parameters_from_sql,
            "HTTPException": test_prototype_review.SourceLoadWithoutYamlTests.HttpError}
        exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
        result = namespace[node.name]("stg", "existingmixed", None, mode="ohd")
        self.assertTrue(result["found"])
        self.assertEqual(result["table_name"], "ExistingMixed")
        self.assertEqual(result["metadata"]["source_id"], "2")
        self.assertEqual(result["metadata"]["source_table_name"], "/BIC/TABLE")
        self.assertEqual(calls[0]["project"], "ohd/dbt")
        self.assertEqual(calls[0]["api_url"], "https://ohd.example/api/v4")
        self.assertEqual(calls[0]["file_path"], "dbt_greenplum_elt/models_metadata/stg/stg.existingmixed.sql")
