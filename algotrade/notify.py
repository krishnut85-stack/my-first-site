"""Telegram alerts for the headless bot. Silent no-op when unconfigured.

Reads the same env var names the previous server setup used, so an existing
/home/<user>/.env keeps working:
    TELEGRAM_TOKEN / TELEGRAM_BOT_TOKEN / TG_BOT_TOKEN
    TELEGRAM_CHAT_ID / TG_CHAT_ID
"""

from __future__ import annotations

import logging
import os

log = logging.getLogger(__name__)


class Telegram:
    def __init__(self):
        self.token = (
            os.environ.get("TELEGRAM_TOKEN")
            or os.environ.get("TELEGRAM_BOT_TOKEN")
            or os.environ.get("TG_BOT_TOKEN", "")
        ).strip()
        self.chat = (
            os.environ.get("TELEGRAM_CHAT_ID") or os.environ.get("TG_CHAT_ID", "")
        ).strip()
        self.enabled = bool(self.token and self.chat)

    def send(self, text: str) -> None:
        if not self.enabled:
            return
        try:
            import requests

            requests.post(
                f"https://api.telegram.org/bot{self.token}/sendMessage",
                data={"chat_id": self.chat, "text": f"📈 FNO-BOT\n{text}"},
                timeout=10,
            )
        except Exception as exc:
            log.warning("telegram send failed: %s", exc)


_telegram: Telegram | None = None


def notify(text: str) -> None:
    global _telegram
    if _telegram is None:
        _telegram = Telegram()
    log.info("ALERT: %s", text.replace("\n", " | "))
    _telegram.send(text)
