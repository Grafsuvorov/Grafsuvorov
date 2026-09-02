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

from api.services.dev_meta import _normalize_click_type, _validate_required_tech_fields


class DevMetaHelpersTests(unittest.TestCase):
    def test_validate_required_tech_fields_accepts_full_set(self) -> None:
        _validate_required_tech_fields(
            ["id", "dttm_inserted", "dttm_updated", "job_name", "deleted_flag"]
        )

    def test_validate_required_tech_fields_reports_missing(self) -> None:
        with self.assertRaisesRegex(ValueError, "job_name"):
            _validate_required_tech_fields(["dttm_inserted", "dttm_updated", "deleted_flag"])

    def test_normalize_click_type_supports_timestamptz(self) -> None:
        self.assertEqual(_normalize_click_type("timestamptz"), "DateTime")


if __name__ == "__main__":
    unittest.main()
