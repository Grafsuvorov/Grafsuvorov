from __future__ import annotations

import sys
import types
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import json

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

sqlalchemy_stub = types.ModuleType("sqlalchemy")
sqlalchemy_stub.create_engine = lambda *args, **kwargs: None
sqlalchemy_stub.text = lambda value: value
sys.modules.setdefault("sqlalchemy", sqlalchemy_stub)

yaml_stub = types.ModuleType("yaml")
yaml_stub.SafeDumper = object
yaml_stub.dump = lambda *args, **kwargs: ""
yaml_stub.safe_load = lambda *args, **kwargs: {}
sys.modules.setdefault("yaml", yaml_stub)

dotenv_stub = types.ModuleType("dotenv")
dotenv_stub.load_dotenv = lambda *args, **kwargs: None
sys.modules.setdefault("dotenv", dotenv_stub)

import api.services.entity_dev_meta as entity_dev_meta
import api.services.prototype_review as prototype_review
from api.services.entity_dev_meta import _build_depends_on, validate_entity_dev_meta_bundle
from api.services.meta_workspace import _read_branch_gp_sql_from_yaml
from api.services.prototype_review import build_review_execution_plan, create_ytrack_issue, extract_sql_dependencies, infer_review_targets


class ExtractSqlDependenciesTests(unittest.TestCase):
    def test_preserves_case_for_quoted_fqn_without_quotes(self) -> None:
        files = [
            {
                "statements": [
                    'insert into ods.target_table select * from "ODS"."SourceTable"',
                ]
            }
        ]

        result = extract_sql_dependencies(files, known_schemas={"ods"})

        self.assertEqual(result, ["ODS.SourceTable"])

    def test_deduplicates_quoted_and_unquoted_same_dependency(self) -> None:
        files = [
            {
                "statements": [
                    'select * from "ODS"."SourceTable"',
                    "select * from ods.sourcetable",
                ]
            }
        ]

        result = extract_sql_dependencies(files, known_schemas={"ods"})

        self.assertEqual(result, ["ODS.SourceTable"])


class PrototypeReviewExecutionPlanTests(unittest.TestCase):
    def test_orders_targets_by_internal_dependencies_even_within_same_file(self) -> None:
        sql = """
        drop table if exists dict_dds.posting_period cascade;
        create table if not exists dict_dds.posting_period (id int);
        insert into dict_dds.posting_period select id from dict_dds.posting_period_change_history;
        drop table if exists dict_dds.posting_period_change_history cascade;
        create table if not exists dict_dds.posting_period_change_history (id int);
        insert into dict_dds.posting_period_change_history select 1 as id;
        """
        files = [{
            "path": "sample.sql",
            "sql": sql,
            "statements": [
                'drop table if exists dict_dds.posting_period cascade',
                'create table if not exists dict_dds.posting_period (id int)',
                'insert into dict_dds.posting_period select id from dict_dds.posting_period_change_history',
                'drop table if exists dict_dds.posting_period_change_history cascade',
                'create table if not exists dict_dds.posting_period_change_history (id int)',
                'insert into dict_dds.posting_period_change_history select 1 as id',
            ],
        }]

        review_targets = infer_review_targets(files)
        plan = build_review_execution_plan(files=files, review_targets=review_targets, known_schemas={"dict_dds"})

        self.assertEqual(
            [item.get("target_fqn") for item in plan],
            ["dict_dds.posting_period_change_history", "dict_dds.posting_period"],
        )
        self.assertIn('insert into dict_dds.posting_period_change_history select 1 as id', plan[0].get("sql_text") or "")
        self.assertNotIn('posting_period_change_history select 1 as id', plan[1].get("sql_text") or "")


class CreateYTrackIssueTests(unittest.TestCase):
    def test_sends_dashboard_direction_as_custom_field(self) -> None:
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return b'{"id": "2-89955", "idReadable": "KHD-1"}'

        captured = {}

        def fake_urlopen(request, **_kwargs):
            captured["payload"] = json.loads(request.data.decode("utf-8"))
            return FakeResponse()

        dashboard_field = {
            "id": "173-627",
            "$type": "EnumProjectCustomField",
            "field": {
                "name": "Дашборд КХД/Направление",
                "fieldType": {"id": "enum", "valueType": "enum"},
            },
        }
        with (
            patch.object(prototype_review, "_resolve_ytrack_project_id", return_value="0-1"),
            patch.object(prototype_review, "_get_ytrack_project_custom_fields", return_value=[dashboard_field]),
            patch.object(prototype_review, "_urlopen_without_proxy", side_effect=fake_urlopen),
        ):
            create_ytrack_issue(
                base_url="https://youtrack.example",
                project_id="0-1",
                project="KHD",
                token="token",
                queue="KHD",
                issue_type="task",
                ssl_verify="false",
                summary="Проверка",
                description="",
                direction="Финансы / Оборотный капитал",
                direction_field_name="Дашборд КХД/Направление",
            )

        self.assertEqual(
            captured["payload"]["customFields"],
            [{
                "id": "173-627",
                "name": "Дашборд КХД/Направление",
                "$type": "SingleEnumIssueCustomField",
                "value": {"name": "Финансы / Оборотный капитал"},
            }],
        )


class EntityMetaDependenciesTests(unittest.TestCase):
    def test_keeps_qualified_sources_when_schema_is_absent_from_local_catalog(self) -> None:
        sql = """
        create temp table pg_temp.payments as (
          with payment_clearing as (
            select * from dds.bank_statement_position_clearing_record
          )
          select *
          from ods.accounting_documents as ad
          join dds.payment_documents as pd on true
          join payment_clearing as cr on true
          join dds.bank_statement_documents as bsd on true
        );
        insert into dds.payment_request select * from dds.accounting_documents;
        """

        dependencies = _build_depends_on(
            sql,
            target_schema="dds",
            target_table="payment_request",
            known_schemas={"ods"},
        )

        self.assertEqual(
            dependencies,
            {
                "dds": [
                    "accounting_documents",
                    "bank_statement_documents",
                    "bank_statement_position_clearing_record",
                    "payment_documents",
                ],
                "ods": ["accounting_documents"],
            },
        )

    def test_reports_dependencies_missing_from_original_yaml(self) -> None:
        yaml_payload = {
            "table_name": "payment_request",
            "table_schema": "dds",
            "table_id": 6586,
            "entity_name": "BI_FI",
            "object_type": "TABLE",
            "table_load_mode": "TRUNCATE_INIT",
            "depends_on": {"ods": ["accounting_documents"]},
        }
        recreate_sql = """
        create table dds.payment_request (
          dttm_inserted timestamp,
          dttm_updated timestamp,
          deleted_flag bool
        )
        """
        insert_sql = """
        do $$ begin
          insert into dds.payment_request
          select * from ods.accounting_documents
          join dds.payment_documents on true;
        end; $$;
        """
        with patch.object(entity_dev_meta.yaml, "safe_load", return_value=yaml_payload):
            result = validate_entity_dev_meta_bundle(
                base_dir=Path.cwd(),
                prod_root_value="missing-prod-root",
                dev_root_value="missing-dev-root",
                entity_name="BI_FI",
                schema_name="dds",
                table_name="payment_request",
                key_attributes=[],
                source_object_key=None,
                yaml_content="placeholder",
                recreate_sql=recreate_sql,
                insert_sql=insert_sql,
                truncate_sql="truncate table dds.payment_request",
            )

        self.assertTrue(any("dds.payment_documents" in error for error in result["errors"]))


class MetaWorkspaceSqlSourceTests(unittest.TestCase):
    def test_prefers_sql_path_declared_in_branch_yaml(self) -> None:
        with TemporaryDirectory() as temp_dir:
            worktree_dir = Path(temp_dir)
            object_dir = worktree_dir / "etl_loads_entity" / "BI_FI" / "dds" / "payment_request"
            object_dir.mkdir(parents=True)
            (object_dir / "sql_query_insert_init.sql").write_text("select 'sibling'", encoding="utf-8")
            configured_path = "meta_info/custom/payment_request_insert.sql"
            configured_file = worktree_dir / configured_path
            configured_file.parent.mkdir(parents=True)
            configured_file.write_text("select 'yaml path'", encoding="utf-8")

            sql, source = _read_branch_gp_sql_from_yaml(
                worktree_dir=worktree_dir,
                object_dir=object_dir,
                yaml_payload={"sql_query_insert_init": configured_path},
                yaml_field="sql_query_insert_init",
                fallback_file_name="sql_query_insert_init.sql",
            )

        self.assertEqual(sql, "select 'yaml path'")
        self.assertEqual(source, configured_path)


if __name__ == "__main__":
    unittest.main()
