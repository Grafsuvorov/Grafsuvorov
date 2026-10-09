#!/usr/bin/env python3
"""Send a test message to an existing eXpress personal chat via Bearer token.

Required environment variables:
  BOTX_BASE_URL       e.g. https://usr.al.team
  BOTX_BEARER_TOKEN   token value without the ``Bearer `` prefix
  BOTX_USER_EMAIL     recipient email

By default the script finds the recipient and their personal chat with the bot.
Passing ``--send`` sends one message to that chat. The recipient must first
open a dialog with the bot and send it a message; only then does BotX create a
personal chat that the bot can use. No credentials are written to disk or
printed.
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class BotXError(RuntimeError):
    pass


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise BotXError(f"Environment variable {name} is required")
    return value


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Test eXpress BotX personal chat creation with a Bearer token",
    )
    parser.add_argument(
        "--send",
        action="store_true",
        help="send one test message to the existing personal chat",
    )
    parser.add_argument(
        "--message",
        default=os.getenv("BOTX_MESSAGE", "Тест: бот успешно создал чат и отправил сообщение."),
    )
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="disable TLS certificate verification (testing only)",
    )
    return parser.parse_args()


class BotXClient:
    def __init__(self, base_url: str, token: str, timeout: float, insecure: bool) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token.removeprefix("Bearer ").strip()
        self.timeout = timeout
        self.ssl_context = ssl._create_unverified_context() if insecure else None

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = Request(
            f"{self.base_url}{path}",
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with urlopen(
                request,
                timeout=self.timeout,
                context=self.ssl_context,
            ) as response:
                raw = response.read().decode("utf-8")
        except HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            try:
                error = json.loads(raw)
                reason = error.get("reason") or error.get("errors") or raw
            except json.JSONDecodeError:
                reason = raw or exc.reason
            raise BotXError(f"{method} {path}: HTTP {exc.code}: {reason}") from exc
        except URLError as exc:
            raise BotXError(f"{method} {path}: connection failed: {exc.reason}") from exc

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise BotXError(f"{method} {path}: server returned non-JSON response") from exc
        if data.get("status") != "ok":
            raise BotXError(f"{method} {path}: {data.get('reason', 'unknown BotX error')}")
        return data

    def find_user(self, email: str) -> dict[str, Any]:
        result = self.request(
            "POST",
            "/api/v3/botx/users/by_email",
            {"emails": [email]},
        ).get("result") or []
        if isinstance(result, dict):
            return result
        if not result:
            raise BotXError(f"User was not found for email {email}")
        return result[0]

    def get_personal_chat(self, user_huid: str) -> str:
        try:
            result = self.request(
                "GET",
                f"/api/v1/botx/chats/personal?user_huid={user_huid}",
            ).get("result") or {}
        except BotXError as exc:
            if "HTTP 404" in str(exc):
                raise BotXError(
                    "Personal chat was not found. Open the bot in Pulse and send it any message first."
                ) from exc
            raise
        chat_id = result.get("group_chat_id")
        if not chat_id:
            raise BotXError("Personal chat response has no group_chat_id")
        return str(chat_id)

    def send_message(self, chat_id: str, message: str) -> str:
        send_path = os.getenv(
            "BOTX_SEND_PATH",
            "/api/v4/botx/notifications/direct",
        ).strip()
        result = self.request(
            "POST",
            send_path,
            {
                "group_chat_id": chat_id,
                "notification": {"status": "ok", "body": message},
            },
        ).get("result")
        if isinstance(result, dict):
            return str(result.get("sync_id") or result)
        return str(result)


def main() -> int:
    args = parse_args()
    try:
        client = BotXClient(
            base_url=required_env("BOTX_BASE_URL"),
            token=required_env("BOTX_BEARER_TOKEN"),
            timeout=args.timeout,
            insecure=args.insecure,
        )
        email = required_env("BOTX_USER_EMAIL")

        user = client.find_user(email)
        user_huid = user.get("user_huid")
        if not user_huid:
            raise BotXError("User search response has no user_huid")
        print(f"User found: {user.get('name', email)} ({user_huid})")

        chat_id = client.get_personal_chat(str(user_huid))
        print(f"Personal chat found: {chat_id}")

        if not args.send:
            print("Dry run complete. Re-run with --send to send a message.")
            return 0

        sync_id = client.send_message(chat_id, args.message)
        print(f"Message accepted by BotX: {sync_id}")
        return 0
    except (BotXError, ValueError) as exc:
        print(f"BotX test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
