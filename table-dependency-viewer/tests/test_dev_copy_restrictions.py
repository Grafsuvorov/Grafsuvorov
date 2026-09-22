from __future__ import annotations

import ast
import unittest
from pathlib import Path


def _load_validator():
    source = Path("api/main.py").read_text(encoding="utf-8")
    module = ast.parse(source, filename="api/main.py")
    node = next(
        item
        for item in module.body
        if isinstance(item, ast.FunctionDef) and item.name == "_assert_dev_copy_target_schema_allowed"
    )
    namespace = {}
    exec(compile(ast.Module(body=[node], type_ignores=[]), "api/main.py", "exec"), namespace)
    return namespace["_assert_dev_copy_target_schema_allowed"]


class DevCopyRestrictionsTests(unittest.TestCase):
    def test_dm_view_is_blocked_case_insensitively(self) -> None:
        validate = _load_validator()

        for value in ("dm_view", "DM_VIEW", "  dm_view  ", '"dm_view"'):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "dm_view"):
                validate(value)

    def test_regular_target_schemas_are_allowed(self) -> None:
        validate = _load_validator()

        for value in ("dm", "dds", "sandbox"):
            with self.subTest(value=value):
                validate(value)


if __name__ == "__main__":
    unittest.main()
