"""Best-effort eXpress notifications for completed long-running operations."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import ssl
import time
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import urlsplit


class BotXNotificationError(RuntimeError):
    pass


def _b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _make_token(bot_id: str, secret_key: str, host: str) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "iss": bot_id,
        "aud": host,
        "exp": now + 60,
        "nbf": now,
        "iat": now,
        "jti": secrets.token_hex(12),
        "version": 2,
    }
    signing_input = ".".join(
        _b64(json.dumps(part, separators=(",", ":")).encode("utf-8"))
        for part in (header, payload)
    )
    signature = hmac.new(secret_key.encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256).digest()
    return f"{signing_input}.{_b64(signature)}"


class BotXNotifier:
    def __init__(self, *, cts_url: str, bot_id: str, secret_key: str, verify_ssl: bool) -> None:
        self.cts_url = cts_url.rstrip("/")
        self.bot_id = bot_id
        self.secret_key = secret_key
        self.host = urlsplit(self.cts_url).hostname or ""
        self.ssl_context = None if verify_ssl else ssl._create_unverified_context()

    def call(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        request = urllib.request.Request(
            f"{self.cts_url}{path}",
            method=method,
            data=None if body is None else json.dumps(body).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {_make_token(self.bot_id, self.secret_key, self.host)}",
                "Content-Type": "application/json",
            },
        )
        try:
            # CTS is an internal service.  Do not inherit HTTP(S)_PROXY from
            # the container: corporate proxies reject this traffic with 407.
            handlers: list[Any] = [urllib.request.ProxyHandler({})]
            if self.ssl_context is not None:
                handlers.append(urllib.request.HTTPSHandler(context=self.ssl_context))
            opener = urllib.request.build_opener(*handlers)
            with opener.open(request, timeout=20) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", "replace")[:500]
            raise BotXNotificationError(f"HTTP {exc.code}: {details}") from None
        except urllib.error.URLError as exc:
            raise BotXNotificationError(f"connection failed: {exc.reason}") from None
        try:
            return json.loads(raw).get("result")
        except (AttributeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise BotXNotificationError("unexpected BotX response") from exc

    def notify_existing_personal_chat(self, *, email: str, message: str) -> str:
        users = self.call("POST", "/api/v3/botx/users/by_email", {"emails": [email]}) or []
        if not isinstance(users, list) or not users:
            return "user_not_found"
        user_huid = str((users[0] or {}).get("user_huid") or "").strip()
        if not user_huid:
            return "user_not_found"
        chats = self.call("GET", "/api/v3/botx/chats/list") or []
        for chat in chats if isinstance(chats, list) else []:
            members = (chat or {}).get("members") or []
            member_ids = {
                str(member.get("user_huid") if isinstance(member, dict) else member)
                for member in members
            }
            # eXpress uses ``botx`` for a dialog with a bot; ``chat`` is a
            # regular personal dialog. Both can be an existing private route
            # for a completion notification.
            if (chat or {}).get("chat_type") in {"chat", "botx"} and user_huid in member_ids:
                chat_id = str((chat or {}).get("group_chat_id") or "").strip()
                if chat_id:
                    self.call(
                        "POST",
                        "/api/v4/botx/notifications/direct",
                        {"group_chat_id": chat_id, "notification": {"status": "ok", "body": message}},
                    )
                    return "sent"
        # Do not create a chat here: the bot can lack allow_chat_creating and
        # notifications must never affect the primary user operation.
        return "chat_not_found"


def send_completion_notification(
    *,
    email: str,
    message: str,
    cts_url: str,
    bot_id: str,
    secret_key: str,
    verify_ssl: bool,
) -> str:
    """Attempt delivery without ever raising into the caller's workflow."""
    if not (email and cts_url and bot_id and secret_key):
        return "disabled"
    try:
        return BotXNotifier(
            cts_url=cts_url,
            bot_id=bot_id,
            secret_key=secret_key,
            verify_ssl=verify_ssl,
        ).notify_existing_personal_chat(email=email, message=message)
    except Exception as exc:  # BotX is optional: never fail the main operation.
        print(f"BotX completion notification skipped for {email}: {exc}")
        return "error"
