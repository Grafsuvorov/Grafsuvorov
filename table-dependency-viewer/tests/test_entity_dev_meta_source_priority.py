from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch
import sys
import types


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

from api.services import entity_dev_meta


class EntityDevMetaSourcePriorityTests(unittest.TestCase):
    def test_prod_only_does_not_read_dev_catalog(self) -> None:
        calls = []

        def fake_read(**kwargs):
            calls.append(kwargs["root_value"])
            return {
                "yaml_content": "key_attributes:\n  - prod_key\n",
                "insert_sql": "",
                "key_attributes": ["prod_key"],
            }

        with (
            patch.object(entity_dev_meta, "_resolve_root", side_effect=lambda _base, value: Path(value)),
            patch.object(entity_dev_meta, "read_entity_dev_meta_bundle", side_effect=fake_read),
            patch.object(
                entity_dev_meta,
                "_normalize_yaml_payload_fields",
                return_value=({"key_attributes": ["prod_key"]}, ["prod_key"]),
            ),
            patch.object(entity_dev_meta, "_dump_yaml", return_value="key_attributes:\n  - prod_key\n"),
        ):
            result = entity_dev_meta.init_entity_dev_meta_bundle(
                engine=None,
                base_dir=Path("."),
                prod_root_value="prod_catalog",
                dev_root_value="dev_catalog",
                entity_name="ENTITY",
                schema_name="dds",
                table_name="target",
                prod_only=True,
            )

        self.assertEqual(calls, ["prod_catalog"])
        self.assertEqual(result["source"], "prod")
        self.assertEqual(result["key_attributes"], ["prod_key"])

    def test_default_mode_keeps_dev_first_for_other_pages(self) -> None:
        calls = []

        def fake_read(**kwargs):
            calls.append(kwargs["root_value"])
            return {"yaml_content": "", "insert_sql": "", "key_attributes": ["dev_key"]}

        with (
            patch.object(entity_dev_meta, "_resolve_root", side_effect=lambda _base, value: Path(value)),
            patch.object(entity_dev_meta, "read_entity_dev_meta_bundle", side_effect=fake_read),
            patch.object(
                entity_dev_meta,
                "_normalize_yaml_payload_fields",
                return_value=({"key_attributes": ["dev_key"]}, ["dev_key"]),
            ),
            patch.object(entity_dev_meta, "_dump_yaml", return_value="key_attributes:\n  - dev_key\n"),
        ):
            result = entity_dev_meta.init_entity_dev_meta_bundle(
                engine=None,
                base_dir=Path("."),
                prod_root_value="prod_catalog",
                dev_root_value="dev_catalog",
                entity_name="ENTITY",
                schema_name="dds",
                table_name="target",
            )

        self.assertEqual(calls, ["dev_catalog"])
        self.assertEqual(result["source"], "dev")


if __name__ == "__main__":
    unittest.main()
