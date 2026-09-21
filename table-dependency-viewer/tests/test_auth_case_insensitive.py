from __future__ import annotations

import ast
import unittest
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class AuthUser:
    id: int
    email: str
    username: str
    role: str
    password_hash: str
    password_salt: str
    is_active: bool


class _Result:
    def __init__(self, row):
        self.row = row

    def fetchone(self):
        return self.row


class _Connection:
    def __init__(self, engine):
        self.engine = engine

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.engine.query = query
        self.engine.params = params
        return _Result(self.engine.row)


class _Engine:
    def __init__(self, row):
        self.row = row
        self.query = None
        self.params = None

    def connect(self):
        return _Connection(self)


def _load_get_user(engine):
    source = Path("api/auth.py").read_text(encoding="utf-8")
    module = ast.parse(source, filename="api/auth.py")
    node = next(
        item
        for item in module.body
        if isinstance(item, ast.FunctionDef) and item.name == "_get_user_by_email"
    )
    namespace = {
        "Optional": Optional,
        "AuthUser": AuthUser,
        "engine": engine,
        "text": lambda value: value,
    }
    exec(compile(ast.Module(body=[node], type_ignores=[]), "api/auth.py", "exec"), namespace)
    return namespace["_get_user_by_email"]


class CaseInsensitiveLoginTests(unittest.TestCase):
    def test_email_lookup_ignores_case_and_outer_spaces(self) -> None:
        engine = _Engine((7, "User.Name@Company.RU", "User.Name", "engineer", "hash", "salt", True))
        get_user = _load_get_user(engine)

        user = get_user("  USER.NAME@COMPANY.ru  ")

        self.assertEqual(engine.params, {"email_normalized": "user.name@company.ru"})
        self.assertIn("lower(email) = :email_normalized", engine.query)
        self.assertEqual(user.email, "User.Name@Company.RU")
        self.assertEqual(user.username, "User.Name")

    def test_empty_login_does_not_query_database(self) -> None:
        engine = _Engine(None)
        get_user = _load_get_user(engine)

        self.assertIsNone(get_user("   "))
        self.assertIsNone(engine.query)


if __name__ == "__main__":
    unittest.main()
