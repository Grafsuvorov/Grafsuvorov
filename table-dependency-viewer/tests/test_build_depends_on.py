from __future__ import annotations

import sys
import types
import unittest

yaml_stub = types.ModuleType("yaml")
yaml_stub.SafeDumper = object
yaml_stub.dump = lambda *args, **kwargs: ""
yaml_stub.safe_load = lambda *args, **kwargs: {}
sys.modules.setdefault("yaml", yaml_stub)

from scripts.build_depends_on import extract_schema_table_refs


class BuildDependsOnTests(unittest.TestCase):
    def test_preserves_quoted_schema_case(self) -> None:
        refs = extract_schema_table_refs(
            'select * from "ZTSD"."SourceTable"',
            known_schemas={"ztsd"},
        )

        self.assertEqual(refs, {("ZTSD", "SourceTable")})


if __name__ == "__main__":
    unittest.main()
