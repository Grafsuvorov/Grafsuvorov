import json
import ast
import os
import unittest
from dataclasses import fields, replace
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import test_prototype_review as fixtures
from api.services.prototype_review_ohd import OhdReviewContext, ohd_settings, require_ohd_settings, deliver_ohd_issue
from api.services.prototype_review_item import PrototypeReviewItemDependencies
from api.services.prototype_review_issue_delivery import PrototypeIssueDeliveryDependencies
from api.services.prototype_review_issue_workflow import create_prototype_review_issue
from api.services.prototype_review_delivery import publish_dbt_registry


class OhdPrototypeReviewTests(unittest.TestCase):
    @staticmethod
    def forbidden(*args, **kwargs):
        raise AssertionError("OHD must not call KHD metadata or ETL delivery")

    def test_missing_ohd_configuration_never_falls_back_to_khd_dev_or_project(self):
        with patch.dict(os.environ, {"DEV_DATABASE_URL": "khd-dev", "DBT_GITLAB_PROJECT": "khd/dbt",
                                     "DBT_GITLAB_TOKEN": "common-token"}, clear=True):
            settings = ohd_settings()
        self.assertEqual(settings["dev_database_url"], "")
        self.assertEqual(settings["project"], "")
        self.assertEqual(settings["token"], "common-token")
        with self.assertRaisesRegex(ValueError, "OHD_DEV_DATABASE_URL"):
            require_ohd_settings(settings)

    def test_ohd_uses_existing_dbt_connection_with_optional_override(self):
        with patch.dict(os.environ, {"DBT_LOGS_DATABASE_URL": "ohd-existing", "DEV_DATABASE_URL": "khd-dev",
                                     "OHD_DEV_DATABASE_URL": ""}, clear=True):
            self.assertEqual(ohd_settings()["dev_database_url"], "ohd-existing")
            with patch.dict(os.environ, {"OHD_DEV_DATABASE_URL": "ohd-override"}):
                self.assertEqual(ohd_settings()["dev_database_url"], "ohd-override")

    def test_run_handler_uses_ohd_dependencies_without_loading_khd_metadata(self):
        module = ast.parse(Path("api/main.py").read_text())
        node = next(n for n in module.body if isinstance(n, ast.FunctionDef) and n.name == "_prototype_review_build_result")
        settings = {"project": "ohd/dbt", "token": "ohd-token", "dev_database_url": "ohd-dev", "analyst_project": "ohd/analyst"}
        captured = []
        namespace = {"Any": object, "PrototypeReviewRunPayload": object,
            "PrototypeReviewWorkflowDependencies": fixtures.PrototypeReviewWorkflowDependencies,
            "replace": replace, "OhdReviewContext": OhdReviewContext, "ohd_settings": lambda: settings,
            "require_ohd_settings": require_ohd_settings,
            "_prototype_gitlab_file_content": self.forbidden, "_prototype_review_item_dependencies": lambda: None,
            "load_merge_request_sql_bundle": self.forbidden, "get_cached_meta_and_index": self.forbidden,
            "_prototype_review_resolve_item": self.forbidden, "execute_sql_review_items_in_dev": self.forbidden,
            "build_prototype_review_result": lambda *a, **kw: captured.append(kw["dependencies"]) or {}}
        namespace.update({name: "khd-value" for name in ("GITLAB_API_URL", "GITLAB_PROJECT", "GITLAB_TOKEN",
            "GITLAB_SSL_VERIFY", "ANALYST_GITLAB_PROJECT", "DEV_DATABASE_URL")})
        exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
        namespace[node.name](SimpleNamespace(mode="ohd"), None)
        self.assertEqual(captured[0].dev_database_url, "ohd-dev")
        self.assertEqual(captured[0].gitlab_token, "ohd-token")
        self.assertEqual(captured[0].get_meta_and_index(), ([], {}))
        self.assertEqual(captured[0].analyst_gitlab_project, "ohd/analyst")

    def context(self, registry):
        reads, checks = [], []
        def read(**kw):
            reads.append(kw)
            return json.dumps(registry) if registry else None
        params = {f.name: self.forbidden for f in fields(PrototypeReviewItemDependencies)}
        params.update(query_table_checks=lambda **kw: checks.append(kw) or {"row_count": 20, "duplicate_groups": 0},
                      item_needs_attention=lambda _: (False, []), clean_table_name=lambda n: n)
        context = OhdReviewContext(settings={"project": "ohd/dbt", "token": "ohd-token", "dev_database_url": "ohd-dev"},
                                  read_file=read, base_resolver=PrototypeReviewItemDependencies(**params))
        return context, reads, checks

    def test_keys_entity_and_scd_come_only_from_ohd_registry_checks_use_ohd_dev(self):
        registry = {"relation": {"schema_name": "ods", "table_name": "/bic/asb_do00800", "scd_type": "scd2",
            "unique_key": ["/bic/zakazn_md", "calday"], "version_key": ["valid_from"], "entity": ["TRANSPORTATION"]},
            "dq": [{"check_type": "duplicates", "filter": "is_actual is true"}]}
        context, reads, checks = self.context(registry)
        with patch.object(fixtures.entity_dev_meta.yaml, "safe_load", side_effect=json.loads):
            item = context.resolve_item(target_fqn="ods./bic/asb_do00800", execution_row={"status": "ok"})
        self.assertEqual(reads[0]["project"], "ohd/dbt")
        self.assertEqual(reads[0]["ref"], "main")
        self.assertTrue(reads[0]["file_path"].endswith("/ods/ods.bicasb_do00800.yml"))
        self.assertEqual(checks[0]["dev_database_url"], "ohd-dev")
        self.assertEqual(checks[0]["key_attributes"], ["/bic/zakazn_md", "calday"])
        self.assertEqual(item["entity_names"], ["TRANSPORTATION"])
        self.assertEqual(item["scd_type"], "scd2")
        self.assertEqual(item["version_key"], ["valid_from"])
        self.assertEqual(item["filter"], "is_actual is true")
        self.assertIsNone(item["table_id"])
        self.assertFalse(item["copy_to_clickhouse"])

    def test_new_ohd_object_does_not_allocate_etl_identity(self):
        context, _, _ = self.context(None)
        item = context.resolve_item(target_fqn="ods.ral_bse_clr", fallback_entity_name="TRANSPORTATION",
                                    key_attributes_override=["bukrs_clr"], execution_row={"status": "ok"})
        self.assertTrue(item["is_new"])
        self.assertIsNone(item["table_id"])
        self.assertEqual(item["key_attributes"], ["bukrs_clr"])

    def test_registry_path_collision_is_not_used_as_another_physical_table(self):
        context, _, _ = self.context({"relation": {"schema_name": "ods", "table_name": "wrong"}})
        with patch.object(fixtures.entity_dev_meta.yaml, "safe_load", side_effect=json.loads), self.assertRaisesRegex(ValueError, "не совпадает"):
            context.resolve_item(target_fqn="ods.ral_bse_clr")

    def test_ohd_issue_creation_skips_all_etl_yaml_preparation(self):
        created, delivered = [], []
        item = {"target_fqn": "ods.ral_bse_clr", "paths": ["ods.sql"], "entity_name": "TRANSPORTATION",
                "key_attributes": ["bukrs_clr", "gjahr_clr"], "is_new": True}
        payload = SimpleNamespace(mode="ohd", direction="LE-TR03 Shipping", mr_input="1", task_text="", issue_summary="OHD prototype",
            linked_issues=[], release_date="", business_key_changed=False,
            review_items=[SimpleNamespace(model_dump=lambda: dict(item))])
        deps = fixtures.PrototypeIssueWorkflowTests.dependencies(
            load_bundle=lambda **kw: {"mr": {}, "files": [{"path": "ods.sql", "sql": "create table ods.ral_bse_clr(id int);"}]},
            parse_task=lambda _: {}, prepare_yaml=self.forbidden, apply_yaml_dependencies=self.forbidden,
            extract_dependencies=self.forbidden, item_needs_attention=lambda _: (False, []),
            build_description=lambda **kw: "OHD description", create_issue=lambda **kw: created.append(kw) or {"issue_id": "OHD-5"},
            link_issues=lambda **kw: [], deliver_issue=lambda **kw: delivered.append(kw) or {},
            build_issue_link=lambda i: f"/issue/{i}", youtrack_project="ОХД", youtrack_queue="OHD")
        result = create_prototype_review_issue(payload, SimpleNamespace(email="test@example.com"), dependencies=deps)
        self.assertEqual(created[0]["project"], "ОХД")
        self.assertEqual(result["issue"]["issue_id"], "OHD-5")
        self.assertEqual(delivered[0]["review_items"][0]["yaml_content"], "")
        self.assertIsNone(delivered[0]["review_items"][0]["table_id"])
        self.assertEqual(delivered[0]["review_items"][0]["dependencies"], [])

    def test_ohd_full_and_selective_execution_never_parse_source_dependencies(self):
        files = [{"path": p, "sql": s, "statements": fixtures.prototype_review._split_sql_statements(s)} for p, s in [
            ("ods/downstream.sql", "insert into ods.downstream select * from ods.upstream;"),
            ("ods/upstream.sql", "insert into ods.upstream select 1;")]]
        executed = []
        def execute(**kw):
            self.assertFalse(kw["parse_dependencies"])
            plan = fixtures.build_review_execution_plan(files=kw["files"], review_targets=kw["review_targets"],
                                                       parse_dependencies=kw["parse_dependencies"])
            executed.extend(p["target_fqn"] for p in plan)
            return [], [{**p, "status": "ok"} for p in plan]
        dependencies = fixtures.PrototypeReviewWorkflowDependencies(load_bundle=lambda **kw: {"files": files, "mr": {}},
            get_meta_and_index=lambda: ([], {}), resolve_item=lambda **kw: {"target_fqn": kw["target_fqn"], "warnings": []},
            execute_review=execute, dev_database_url="ohd-dev", gitlab_api_url="", gitlab_project="", gitlab_token="",
            gitlab_ssl_verify=True, analyst_gitlab_project="")
        payload = SimpleNamespace(mode="ohd", mr_input="1", task_text="", issue_summary="", entity_name="TRANSPORTATION",
            dependent_views=[], linked_issues=[], release_date="", direction="", business_key_changed=None)
        with patch.object(fixtures.prototype_review, "_extract_statement_dependencies_normalized", side_effect=self.forbidden):
            fixtures.build_prototype_review_result(payload, None, dependencies=dependencies)
            self.assertEqual(executed, ["ods.downstream", "ods.upstream"])
            executed.clear()
            payload.selected_item_ids = ["ods.upstream::TABLE"]
            result = fixtures.build_prototype_review_result(payload, None, dependencies=dependencies)
        self.assertEqual(executed, ["ods.upstream"])
        self.assertEqual(result["invalidated_item_ids"], [])

    def test_ohd_delivery_only_publishes_dbt_and_links_it_to_ohd_task(self):
        params = {f.name: self.forbidden for f in fields(PrototypeIssueDeliveryDependencies)}
        published, comments = [], []
        params.update(publish_dbt=lambda **kw: published.append(kw) or {"mr_url": "https://git/ohd/mr/1"},
                      add_comment=lambda **kw: comments.append(kw))
        result = deliver_ohd_issue(issue_result={"issue_id": "OHD-5"}, review_items=[], bundle={},
            user=SimpleNamespace(email="test@example.com"), dependencies=PrototypeIssueDeliveryDependencies(**params))
        self.assertEqual(published[0]["task_id"], "OHD-5")
        self.assertIsNone(result["meta_mr"])
        self.assertEqual(result["meta_files"], [])
        self.assertEqual(comments[0]["issue_id"], "OHD-5")
        self.assertTrue(result["dbt_registry"]["task_link_attached"])

    def test_source_load_is_rejected_before_any_ohd_external_calls(self):
        with self.assertRaisesRegex(ValueError, "без STG-загрузки"):
            create_prototype_review_issue(SimpleNamespace(mode="ohd", source_load={"target_table": "unsafe"}, review_items=[]),
                None, dependencies=fixtures.PrototypeIssueWorkflowTests.dependencies())

    def test_ohd_publishes_actual_sql_target_and_registry_in_main_not_khd_project(self):
        requests = []
        def git(**kw):
            requests.append(kw)
            return [] if kw["method"] == "GET" else {"id": "commit", "iid": 4, "web_url": "https://git/ohd/mr/4"}
        sql = "drop table if exists ods.ral_bse_clr; create table ods.ral_bse_clr(bukrs_clr text); insert into ods.ral_bse_clr select '1';"
        files = [{"path": "dbt_greenplum_elt/models_metadata/ods/ods.bicatr_to12900.sql", "sql": sql,
                  "statements": fixtures.prototype_review._split_sql_statements(sql)}]
        item = {**fixtures.infer_review_targets(files)[0], "key_attributes": ["bukrs_clr"], "entity_name": "TRANSPORTATION"}
        with patch.dict(os.environ, {"DBT_GITLAB_PROJECT": "khd/dbt", "DBT_GITLAB_TARGET_BRANCH": "develop"}), \
             patch.object(fixtures.prototype_review_delivery, "resource_exists", return_value=False), \
             patch.object(fixtures.prototype_review_delivery, "file_content", return_value=None), \
             patch.object(fixtures.prototype_review, "_extract_statement_dependencies_normalized", side_effect=self.forbidden), \
             patch.object(fixtures.prototype_review_delivery, "_gitlab_json_request", side_effect=git):
            result = publish_dbt_registry(task_id="OHD-5", author="test", review_items=[item], changed_files=files,
                                          mode="ohd", gitlab_project="ohd/dbt", gitlab_token="ohd-token")
        self.assertEqual(result["target_branch"], "main")
        self.assertTrue(all(r["project"] == "ohd/dbt" for r in requests))
        actions = next(r["payload"]["actions"] for r in requests if r["path"] == "repository/commits")
        self.assertTrue(any(a["file_path"].endswith("/ods/ods.ral_bse_clr.sql") for a in actions))
        registry = next(a for a in actions if a["file_path"].endswith("/ods/ods.ral_bse_clr.yml"))
        self.assertIn("table_name: ral_bse_clr", registry["content"])
        self.assertIn("    - TRANSPORTATION", registry["content"])
