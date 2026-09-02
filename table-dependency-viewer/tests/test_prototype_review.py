from __future__ import annotations

import sys
import types
import unittest

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

from api.services.prototype_review import extract_sql_dependencies


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


if __name__ == "__main__":
    unittest.main()
