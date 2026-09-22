from __future__ import annotations

import sys
import types
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


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

from api.services.meta_workspace import _find_gp_object_dir_by_fqn


class MetaWorkspaceDeleteTests(unittest.TestCase):
    def test_finds_object_case_insensitively_in_entity_catalog(self) -> None:
        with TemporaryDirectory() as raw_root:
            worktree = Path(raw_root)
            object_dir = worktree / "meta/root" / "ENTITY_A" / "DDS" / "Account_Debt_1C"
            object_dir.mkdir(parents=True)
            (object_dir / "meta_data_file.yaml").write_text("table_schema: dds\n", encoding="utf-8")

            result = _find_gp_object_dir_by_fqn(
                worktree_dir=worktree,
                entity_git_root_value="meta/root",
                schema_name="dds",
                table_name="account_debt_1c",
            )

            self.assertEqual(result, object_dir.resolve())

    def test_rejects_ambiguous_objects_in_multiple_entities(self) -> None:
        with TemporaryDirectory() as raw_root:
            worktree = Path(raw_root)
            for entity_name in ("ENTITY_A", "ENTITY_B"):
                object_dir = worktree / "meta/root" / entity_name / "dds" / "target"
                object_dir.mkdir(parents=True)
                (object_dir / "meta_data_file.yaml").write_text("table_schema: dds\n", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "нескольких сущностях"):
                _find_gp_object_dir_by_fqn(
                    worktree_dir=worktree,
                    entity_git_root_value="meta/root",
                    schema_name="dds",
                    table_name="target",
                )

    def test_rejects_path_outside_worktree(self) -> None:
        with TemporaryDirectory() as raw_root:
            with self.assertRaisesRegex(ValueError, "Некорректный"):
                _find_gp_object_dir_by_fqn(
                    worktree_dir=Path(raw_root),
                    entity_git_root_value="../outside",
                    schema_name="dds",
                    table_name="target",
                )


if __name__ == "__main__":
    unittest.main()
