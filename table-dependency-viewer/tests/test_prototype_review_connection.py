import unittest
from types import SimpleNamespace
from unittest.mock import patch

import test_prototype_review as fixtures
from api.services import prototype_review_connection as diagnostics


class OhdConnectionDiagnosticsTests(unittest.TestCase):
    url = "postgresql+psycopg2://app_user:s3cr%40t@configured-host:5433/expected_db"

    def test_read_only_probe_logs_configured_and_actual_database_without_password(self):
        queries, disposed = [], []
        identity = {"database_name": "actual_db", "user_name": "actual_user", "server_address": "10.1.2.3", "server_port": 5432}
        class Connection:
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def execute(self, query):
                queries.append(str(query))
                return SimpleNamespace(mappings=lambda: SimpleNamespace(one=lambda: identity))
        engine = SimpleNamespace(connect=lambda: Connection(), dispose=lambda: disposed.append(True))
        with patch.object(diagnostics, "create_engine", return_value=engine) as create, \
             self.assertLogs("uvicorn.error", level="INFO") as logs:
            result = diagnostics.check_ohd_database_connection(self.url, source="OHD_DEV_DATABASE_URL")
        self.assertEqual(result, identity)
        self.assertEqual(disposed, [True])
        self.assertEqual(create.call_args.kwargs["connect_args"], {"connect_timeout": 5})
        self.assertEqual(len(queries), 1)
        self.assertIn("SELECT current_database()", queries[0])
        message = "\n".join(logs.output)
        for value in ("START", "OK", "OHD_DEV_DATABASE_URL", "configured-host", "expected_db", "10.1.2.3", "actual_db", "actual_user"):
            self.assertIn(value, message)
        self.assertNotIn("s3cr", message)
        self.assertNotIn(self.url, message)

    def test_failed_connection_is_redacted_disposed_and_reported_before_sql(self):
        disposed = []
        def connect():
            raise RuntimeError(f"Connection failed: {self.url}; password=s3cr@t")
        engine = SimpleNamespace(connect=connect, dispose=lambda: disposed.append(True))
        with patch.object(diagnostics, "create_engine", return_value=engine), \
             self.assertLogs("uvicorn.error", level="INFO") as logs, \
             self.assertRaisesRegex(ValueError, "Не удалось подключиться к ОХД") as error:
            diagnostics.check_ohd_database_connection(self.url)
        self.assertEqual(disposed, [True])
        message = "\n".join(logs.output) + str(error.exception)
        self.assertIn("FAILED", message)
        self.assertIn("configured-host", message)
        self.assertNotIn("s3cr@t", message)
        self.assertNotIn("s3cr%40t", message)
        self.assertNotIn(self.url, message)
        self.assertTrue(all(record.exc_info is None for record in logs.records))
        self.assertTrue(error.exception.__suppress_context__)

    def test_invalid_port_does_not_echo_credential_bearing_input(self):
        with patch.object(diagnostics, "create_engine", side_effect=AssertionError("Must not connect")), \
             self.assertLogs("uvicorn.error", level="ERROR") as logs, \
             self.assertRaisesRegex(ValueError, "Некорректный формат") as error:
            diagnostics.check_ohd_database_connection("postgresql://app:secret@host:not-a-port/db")
        self.assertNotIn("secret", "\n".join(logs.output) + str(error.exception))
