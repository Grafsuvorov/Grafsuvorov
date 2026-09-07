from __future__ import annotations

import sys
import types
import unittest
from pathlib import Path
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

import api.services.prototype_review as prototype_review
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


if __name__ == "__main__":
    unittest.main()
