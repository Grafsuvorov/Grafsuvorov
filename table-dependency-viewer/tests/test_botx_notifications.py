from __future__ import annotations

import unittest
from unittest.mock import Mock

from api.services.botx_notifications import BotXNotifier, send_completion_notification


class BotXNotificationsTests(unittest.TestCase):
    def test_missing_settings_disable_notifications(self) -> None:
        self.assertEqual(
            send_completion_notification(
                email="user@example.com",
                message="done",
                cts_url="",
                bot_id="",
                secret_key="",
                verify_ssl=True,
            ),
            "disabled",
        )

    def test_absent_personal_chat_is_skipped_without_creating_one(self) -> None:
        notifier = BotXNotifier(
            cts_url="https://botx.example",
            bot_id="bot-id",
            secret_key="secret",
            verify_ssl=True,
        )
        notifier.call = Mock(side_effect=[
            [{"user_huid": "user-1"}],
            [],
        ])

        status = notifier.notify_existing_personal_chat(email="user@example.com", message="done")

        self.assertEqual(status, "chat_not_found")
        self.assertEqual(notifier.call.call_count, 2)
        self.assertEqual(notifier.call.call_args_list[1].args[:2], ("GET", "/api/v3/botx/chats/list"))

    def test_sends_to_existing_botx_chat(self) -> None:
        notifier = BotXNotifier(
            cts_url="https://botx.example",
            bot_id="bot-id",
            secret_key="secret",
            verify_ssl=True,
        )
        notifier.call = Mock(side_effect=[
            [{"user_huid": "user-1"}],
            [{"chat_type": "botx", "members": ["user-1"], "group_chat_id": "chat-1"}],
            {"sync_id": "sync-1"},
        ])

        status = notifier.notify_existing_personal_chat(email="user@example.com", message="done")

        self.assertEqual(status, "sent")
        self.assertEqual(notifier.call.call_args_list[2].args[:2], ("POST", "/api/v4/botx/notifications/direct"))


if __name__ == "__main__":
    unittest.main()
