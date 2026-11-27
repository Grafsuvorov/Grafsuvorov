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
            "_prototype_gitlab_file_content": lambda **kw: calls.append(kw) or ('{}' if kw["file_path"].endswith(".yml") else sql),
            "yaml": SimpleNamespace(safe_load=__import__("json").loads),
            "source_loader_parameters_from_sql": source_loader_parameters_from_sql,
            "HTTPException": test_prototype_review.SourceLoadWithoutYamlTests.HttpError}
        exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
        result = namespace[node.name]("stg", "existingmixed", None, mode="ohd")
        self.assertTrue(result["found"])
        self.assertEqual(result["table_name"], "ExistingMixed")
        self.assertEqual(result["fields"], "ALL")
        self.assertEqual(result["fields_source"], "unspecified")
        self.assertEqual(result["metadata"]["source_id"], "2")
        self.assertEqual(result["metadata"]["source_table_name"], "/BIC/TABLE")
        self.assertEqual(calls[0]["project"], "ohd/dbt")
        self.assertEqual(calls[0]["api_url"], "https://ohd.example/api/v4")
        self.assertEqual(calls[0]["file_path"], "dbt_greenplum_elt/models_metadata/stg/stg.existingmixed.sql")
        namespace["_prototype_gitlab_file_content"] = lambda **kw: ('{"relation":{"fields":["ID","SOURCE"],"unique_key":["ID"]}}'
            if kw["file_path"].endswith(".yml") else sql)
        restored = namespace[node.name]("stg", "existingmixed", None, mode="ohd")
        self.assertEqual(restored["fields"], "ID,SOURCE")
        self.assertEqual(restored["fields_source"], "yaml")
        self.assertEqual(restored["metadata"]["unique_key"], ["ID"])

class SourceProjectionTests(unittest.TestCase):
    def test_yaml_projection_wins_over_saved_sql(self):
        from api.services.stg_source_loader import source_loader_metadata
        for key, value in [('fields', 'ID,SOURCE'), ('fields_list', ['ID', 'SOURCE'])]:
            metadata, origin = source_loader_metadata({key: value, 'primary_key': 'ID'},
                "SELECT loader(v_fields_list := 'ID,DEV_ONLY', v_pk := 'WRONG');")
            self.assertEqual(metadata['fields'], 'ID,SOURCE')
            self.assertEqual(metadata['primary_key'], 'ID')
            self.assertEqual(origin, 'yaml')

    def test_legacy_sql_and_missing_projection_are_explicit(self):
        from api.services.stg_source_loader import source_loader_metadata
        self.assertEqual(source_loader_metadata({}, "SELECT loader(v_fields_list := 'ID,SOURCE');"),
                         ({'fields': 'ID,SOURCE'}, 'sql'))
        self.assertEqual(source_loader_metadata({}), ({'fields': 'ALL'}, 'unspecified'))

    def test_khd_details_restore_yaml_fields_in_both_stg_schemas(self):
        import ast
        import json
        from pathlib import Path
        from types import SimpleNamespace
        node = next(n for n in ast.parse(Path('api/main.py').read_text()).body
                    if isinstance(n, ast.FunctionDef) and n.name == 'get_admin_prototype_source_table_details')
        for schema in ['stg', 'dict_stg']:
            engine = MagicMock()
            engine.connect.return_value.__enter__.return_value.execute.return_value.mappings.return_value.first.return_value = {
                'entity_id': 6, 'entity_name': 'DAILY'}
            namespace = {'__package__': 'api', 'Request': object,
                '_require_authenticated': lambda _: SimpleNamespace(email='user@example.com'),
                'list_target_tables': lambda *_: [{'table_name': 'Existing', 'fields': 'ID,DEV_ONLY', 'primary_key': 'DEV_ONLY'}],
                'engine': engine, 'dev_engine': object(), 'text': lambda sql: sql,
                'TABLE_TABLES_META': 'tables_meta', 'TABLE_ENTITIES_META': 'entities_meta',
                'read_meta_workspace_branch_gp_bundle': lambda **_: {'yaml_content': json.dumps({'fields_list': ['ID','SOURCE'], 'key_attributes': ['ID']}), 'recreate_sql': "SELECT loader(v_fields_list := 'WRONG');"},
                'yaml': SimpleNamespace(safe_load=json.loads),
                'HTTPException': test_prototype_review.SourceLoadWithoutYamlTests.HttpError,
                'MetaWorkspaceObjectNotFoundError': KeyError}
            namespace.update({key: 'fixture' for key in ['ENTITY_META_GIT_REPO','ENTITY_META_GIT_META_ROOT','META_WORKSPACE_ROOT','PROTOTYPE_ETL_BASE_BRANCH']})
            exec(compile(ast.Module(body=[node], type_ignores=[]), 'api/main.py', 'exec'), namespace)
            result = namespace[node.name](schema, 'existing', None)
            self.assertEqual(result['fields'], 'ID,SOURCE')
            self.assertEqual(result['fields_source'], 'yaml')
            self.assertNotIn('DEV_ONLY', result['primary_key'])
            namespace['list_target_tables'] = lambda *_: []
            restored = namespace[node.name](schema, 'existing', None)
            self.assertTrue(restored['found'])
            self.assertEqual(restored['fields'], 'ID,SOURCE')
