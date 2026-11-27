from dataclasses import fields
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import test_prototype_review as fixtures
from api.services.prototype_source_batch import validate_source_loads, source_dbt_items
from api.services.prototype_review_issue_workflow import create_prototype_review_issue
from api.services.prototype_review_issue_delivery import PrototypeIssueDeliveryDependencies, deliver_prototype_issue
from api.services.prototype_review_ohd import deliver_ohd_issue
from api.services.prototype_review_delivery import publish_dbt_registry


def load(table="First", mode="khd"):
    return dict(mode=mode, target_schema="stg", target_table=table, source_schema="SRC", source_table=table,
                primary_key='"ID", "/BIC/KEY"', entity_name="DAILY" if mode == "khd" else "",
                yaml_content="table_name: " + table if mode == "khd" else "", load_status="ok",
                recreate_sql=f"SELECT tech_etl.etl_source_to_greenplum_new(v_target_table_name := '{table}');",
                insert_sql=f'INSERT INTO stg."{table}" SELECT * FROM raw_ext."{table}_READ";', truncate_sql="")


class SourceBatchTests(unittest.TestCase):
    def test_source_only_batch_creates_one_issue_without_reading_mr(self):
        for mode in ("khd", "ohd"):
            created, delivered = [], []
            values = [load(mode=mode), load("Second", mode)]
            payload = SimpleNamespace(mode=mode, source_loads=values, mr_input="", direction="Shipping", task_text="",
                review_items=[], issue_summary="Two STG tables", linked_issues=[], release_date="", business_key_changed=False)
            deps = fixtures.PrototypeIssueWorkflowTests.dependencies(
                load_bundle=lambda **kw: self.fail("No MR lookup for STG-only task"), parse_task=lambda _: {},
                build_description=lambda **kw: "Description", item_needs_attention=lambda _: (False, []),
                create_issue=lambda **kw: created.append(kw) or {"issue_id": "SDS-548" if mode == "ohd" else "DWH-19"},
                link_issues=lambda **kw: [], deliver_issue=lambda **kw: delivered.append(kw) or {},
                build_issue_link=lambda issue_id: f"/issue/{issue_id}")
            result = create_prototype_review_issue(payload, SimpleNamespace(email="engineer@example.com"), dependencies=deps)
            self.assertEqual(len(created), 1)
            self.assertEqual(delivered[0]["source_load"], values)
            self.assertIn('stg."First"', result["description"])
            self.assertIn('stg."Second"', result["description"])
            self.assertEqual(result["task_contents"]["source_targets"], ["stg.First", "stg.Second"])

    def test_duplicates_dirty_results_and_cross_mode_stop_before_external_calls(self):
        for values, mode, error in [([load(), load()], "khd", "повторяется"),
                                    ([{**load(), "load_status": "error"}], "khd", "генерацию"),
                                    ([load(mode="ohd")], "khd", "другом контуре")]:
            payload = SimpleNamespace(mode=mode, source_loads=values, review_items=[])
            with self.assertRaisesRegex(ValueError, error):
                create_prototype_review_issue(payload, None, dependencies=fixtures.PrototypeIssueWorkflowTests.dependencies())
        with self.assertRaisesRegex(ValueError, "присутствует в diff"):
            validate_source_loads([load()], mode="khd", review_items=[{"target_fqn": "stg.first"}])

    def test_khd_batch_saves_each_table_once_into_same_task_branch(self):
        saved, mrs, dbt = [], [], []
        params = {f.name: "" for f in fields(PrototypeIssueDeliveryDependencies)}
        params.update(engine=None, collect_target_sql=lambda **kw: {},
            prepare_source_load=lambda **kw: {"DAILY": kw["source_load"]["yaml_content"]},
            save_gp_bundle=lambda **kw: saved.append(kw) or {"branch_name": kw["branch_name"]},
            create_meta_mr=lambda **kw: mrs.append(kw) or {}, publish_dbt=lambda **kw: dbt.append(kw) or {}, base_branch="main")
        result = deliver_prototype_issue(issue_result={"issue_id": "DWH-19", "raw": {"id": "2-19"}}, review_items=[], bundle={"files": []},
            user=SimpleNamespace(email="eng@example.com"), dependencies=PrototypeIssueDeliveryDependencies(**params),
            source_load=[load(), load("Second")])
        self.assertIsNone(result["meta_error"])
        self.assertEqual([s["table_name"] for s in saved], ["First", "Second"])
        self.assertEqual(len({s["branch_name"] for s in saved}), 1)
        self.assertEqual(len(mrs), 1)
        self.assertEqual([i["target_fqn"] for i in dbt[0]["review_items"]], ["stg.First", "stg.Second"])
        self.assertEqual(dbt[0]["review_items"][0]["entity_names"], ["DAILY"])

    def test_ohd_diff_and_sources_publish_in_one_dbt_call_without_etl_writes(self):
        calls = []
        params = {f.name: None for f in fields(PrototypeIssueDeliveryDependencies)}
        params.update(publish_dbt=lambda **kw: calls.append(kw) or {}, add_comment=lambda **kw: None)
        deliver_ohd_issue(issue_result={"issue_id": "SDS-548"}, review_items=[{"target_fqn": "dm.Report"}],
            bundle={"files": [{"path": "dm.sql"}]}, user=SimpleNamespace(email="eng@example.com"),
            dependencies=PrototypeIssueDeliveryDependencies(**params), source_load=[load(mode="ohd"), load("Second", "ohd")])
        self.assertEqual(len(calls), 1)
        self.assertEqual([i["target_fqn"] for i in calls[0]["review_items"]], ["dm.Report", "stg.First", "stg.Second"])
        self.assertEqual(calls[0]["review_items"][1]["key_attributes"], ["ID", "/BIC/KEY"])

    def test_ohd_source_sql_and_registry_are_published_without_duplicate_insert(self):
        import api.services.prototype_review_delivery as delivery
        requests = []
        def git(**kw):
            requests.append(kw)
            return {"id": "commit", "iid": 1} if kw["method"] != "GET" else []
        with patch.object(delivery, "resource_exists", return_value=False), \
             patch.object(delivery, "file_content", return_value=None), patch.object(delivery, "_gitlab_json_request", side_effect=git):
            publish_dbt_registry(task_id="SDS-548", author="eng", review_items=source_dbt_items([load(mode="ohd"), load("Second", "ohd")]),
                mode="ohd", gitlab_project="ohd/dbt", gitlab_token="token", gitlab_api_url="https://git.example/api/v4")
        commit = next(r for r in requests if r["path"] == "repository/commits")
        actions = commit["payload"]["actions"]
        models = [a for a in actions if a["file_path"].endswith(("stg.first.sql", "stg.second.sql"))]
        self.assertEqual(len(models), 2)
        for model in models:
            self.assertEqual(model["content"].count("etl_source_to_greenplum_new"), 1)
            self.assertNotIn("INSERT INTO", model["content"])
        registries = [a for a in actions if a["file_path"].endswith(("stg.first.yml", "stg.second.yml"))]
        self.assertEqual(len(registries), 2)
        self.assertTrue(all("  entity:" not in a["content"] for a in registries))

    def test_ohd_generation_handler_uses_only_ohd_engine_and_skips_khd_yaml_catalog(self):
        import ast
        from contextlib import contextmanager
        from pathlib import Path
        node = next(n for n in ast.parse(Path("api/main.py").read_text()).body
                    if isinstance(n, ast.FunctionDef) and n.name == "run_admin_prototype_source_load")
        calls = []
        @contextmanager
        def source_engine(mode):
            self.assertEqual(mode, "ohd")
            yield "ohd-only-engine"
        namespace = {"__package__": "api", "Request": object,
            "_require_authenticated": lambda _: SimpleNamespace(email="eng@example.com"),
            "_prototype_source_engine": source_engine,
            "run_source_loader": lambda engine, data: calls.append((engine, data)) or {"status": "ok", "recreate_sql": "SELECT loader();"},
            "HTTPException": fixtures.SourceLoadWithoutYamlTests.HttpError, "traceback": __import__("traceback")}
        exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
        value = load(mode="ohd")
        payload = SimpleNamespace(**value, model_dump=lambda: value)
        result = namespace[node.name](payload, None)
        self.assertEqual(calls[0][0], "ohd-only-engine")
        self.assertEqual(result["yaml_contents"], {})
        self.assertEqual(result["key_attributes"], ["ID", "/BIC/KEY"])

    def test_source_engine_selects_ohd_url_and_disposes_only_temporary_engine(self):
        import ast
        from contextlib import contextmanager
        from pathlib import Path
        from unittest.mock import Mock
        node = next(n for n in ast.parse(Path("api/main.py").read_text()).body
                    if isinstance(n, ast.FunctionDef) and n.name == "_prototype_source_engine")
        engine = Mock()
        factory = Mock(return_value=engine)
        namespace = {"contextmanager": contextmanager, "create_engine": factory,
                     "dev_engine": "khd-engine", "ohd_settings": lambda: {"dev_database_url": "ohd-only-url"}}
        exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
        with namespace[node.name]("khd") as selected:
            self.assertEqual(selected, "khd-engine")
        factory.assert_not_called()
        with namespace[node.name]("ohd") as selected:
            self.assertIs(selected, engine)
        factory.assert_called_once_with("ohd-only-url", pool_pre_ping=True)
        engine.dispose.assert_called_once()

    def test_checked_diff_and_two_stg_tables_create_and_deliver_one_task(self):
        created, delivered = [], []
        item = {"target_fqn": "ods.Report", "paths": ["ods.sql"], "key_attributes": ["ID"], "is_new": True}
        sources = [load(mode="ohd"), load("Second", "ohd")]
        payload = SimpleNamespace(mode="ohd", source_loads=sources, mr_input="78", direction="Shipping", task_text="",
            review_items=[SimpleNamespace(model_dump=lambda: dict(item))], issue_summary="Combined", linked_issues=[], release_date="", business_key_changed=False)
        deps = fixtures.PrototypeIssueWorkflowTests.dependencies(
            load_bundle=lambda **kw: {"mr": {"iid": 78}, "files": [{"path": "ods.sql", "sql": "create table ods.Report(ID int);"}]},
            parse_task=lambda _: {}, item_needs_attention=lambda _: (False, []), build_description=lambda **kw: "Checked diff",
            create_issue=lambda **kw: created.append(kw) or {"issue_id": "SDS-548"}, link_issues=lambda **kw: [],
            deliver_issue=lambda **kw: delivered.append(kw) or {}, build_issue_link=lambda i: f"/issue/{i}")
        result = create_prototype_review_issue(payload, SimpleNamespace(email="eng@example.com"), dependencies=deps)
        self.assertEqual(len(created), 1)
        self.assertEqual(len(delivered), 1)
        self.assertEqual(len(delivered[0]["review_items"]), 1)
        self.assertEqual(len(delivered[0]["source_load"]), 2)
        self.assertIn("Checked diff", result["description"])
        self.assertIn('stg."First"', created[0]["description"])

    def test_expected_source_count_mismatch_stops_before_issue_creation(self):
        payload = SimpleNamespace(mode="khd", source_loads=[], expected_source_load_count=2, review_items=[])
        with self.assertRaisesRegex(ValueError, "ожидалось 2, получено 0"):
            create_prototype_review_issue(payload, None, dependencies=fixtures.PrototypeIssueWorkflowTests.dependencies())

    def test_khd_dbt_commit_contains_diff_and_both_stg_models_and_registries(self):
        import os
        import api.services.prototype_review_delivery as delivery
        requests = []
        def git(**kw):
            requests.append(kw)
            return {} if kw["method"] != "GET" else []
        sql = 'CREATE TABLE ods.Report(ID int); INSERT INTO ods.Report VALUES(1);'
        files = [{"path": "ods.sql", "sql": sql, "statements": fixtures.prototype_review._split_sql_statements(sql)}]
        items = [{"target_fqn": "ods.Report", "key_attributes": ["ID"], "paths": ["ods.sql"], "entity_name": "DAILY"},
                 *source_dbt_items([load(), load("Second")])]
        with patch.dict(os.environ, {"DBT_GITLAB_TOKEN": "token", "DBT_GITLAB_PROJECT": "khd/dbt"}), \
             patch.object(delivery, "resource_exists", return_value=False), patch.object(delivery, "file_content", return_value=None), \
             patch.object(delivery, "_gitlab_json_request", side_effect=git):
            publish_dbt_registry(task_id="DWH-19", author="eng", review_items=items, changed_files=files)
        actions = next(r["payload"]["actions"] for r in requests if r["path"] == "repository/commits")
        for target in ("ods/ods.report", "stg/stg.first", "stg/stg.second"):
            self.assertTrue(any(a["file_path"].endswith(target + ".sql") for a in actions), target)
            self.assertTrue(any(a["file_path"].endswith(target + ".yml") for a in actions), target)
