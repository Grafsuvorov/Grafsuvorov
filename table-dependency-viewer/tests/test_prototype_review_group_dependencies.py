from __future__ import annotations

import ast
from pathlib import Path
from typing import Any
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

from api.services.prototype_review import _normalize_fqn


def _load_group_dependencies():
    source = Path("api/main.py").read_text(encoding="utf-8")
    module = ast.parse(source, filename="api/main.py")
    function_node = next(
        node for node in module.body
        if isinstance(node, ast.FunctionDef) and node.name == "_prototype_review_group_dependencies"
    )
    isolated_module = ast.Module(body=[function_node], type_ignores=[])
    namespace = {"_normalize_fqn": _normalize_fqn, "Any": Any}
    exec(compile(isolated_module, "api/main.py", "exec"), namespace)
    return namespace["_prototype_review_group_dependencies"]


class PrototypeReviewGroupDependenciesTests(unittest.TestCase):
    def test_preserves_quoted_schema_case_in_depends_on(self) -> None:
        group_dependencies = _load_group_dependencies()

        result = group_dependencies(["ZTSD.SourceTable", "ztsd.sourcetable"])

        self.assertEqual(result, {"ZTSD": ["SourceTable"]})


if __name__ == "__main__":
    unittest.main()
