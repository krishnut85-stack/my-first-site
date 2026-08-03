"""Telegram alerts (standard library only — no extra dependencies).

Sends a message via the Telegram Bot API. Credentials come from environment
variables so nothing secret is committed:

    TELEGRAM_BOT_TOKEN   from @BotFather  (e.g. 123456:ABC-DEF...)
    TELEGRAM_CHAT_ID     your chat/channel id (talk to @userinfobot to get it)

If they are not set, the message is printed to the console instead of sent, so
this is always safe to call (a dry-run). Sending NEVER raises — a delivery
failure is logged and swallowed, exactly like the email path, so a flaky network
can never crash a trading run.
"""

import json
import urllib.error
import urllib.parse
import urllib.request

from . import config


def configured() -> bool:
    return bool(config.TELEGRAM_BOT_TOKEN and config.TELEGRAM_CHAT_ID)


def _post(text: str, parse_mode: str, message_thread_id) -> tuple:
    """One sendMessage attempt. Returns (ok: bool, detail: str)."""
    url = f"https://api.telegram.org/bot{config.TELEGRAM_BOT_TOKEN}/sendMessage"
    fields = {
        "chat_id": config.TELEGRAM_CHAT_ID,
        "text": text[:4096],          # Telegram hard limit per message
        "parse_mode": parse_mode,
        "disable_web_page_preview": "true",
    }
    if message_thread_id:
        fields["message_thread_id"] = str(message_thread_id)
    payload = urllib.parse.urlencode(fields).encode()
    try:
        with urllib.request.urlopen(url, data=payload, timeout=20) as resp:
            body = json.loads(resp.read().decode())
        return (True, "") if body.get("ok") else (False, json.dumps(body))
    except urllib.error.HTTPError as exc:
        detail = ""
        try:
            detail = exc.read().decode()
        except Exception:  # noqa: BLE001
            pass
        return False, f"HTTP {exc.code} — {detail or exc.reason}"
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


def send_telegram(text: str, parse_mode: str = "HTML",
                  message_thread_id=None) -> bool:
    """Send `text` to the configured Telegram chat. Returns True if delivered.

    `message_thread_id` posts into a specific FORUM TOPIC. CRITICAL: if the topic
    id is wrong/stale (Telegram error 'message thread not found'), we RETRY to the
    group's General (no topic) so a TRADE ALERT IS NEVER LOST. Falls back to a
    console dry-run only when no token/chat id is configured.
    """
    if not configured():
        print("\n[telegram dry-run] TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set "
              "— would have sent:\n")
        print(text + "\n")
        print("Set the two env vars (see .env.example) to actually deliver.")
        return False

    ok, detail = _post(text, parse_mode, message_thread_id)
    if ok:
        print(f"[telegram] sent to chat {config.TELEGRAM_CHAT_ID}"
              + (f" (topic {message_thread_id})" if message_thread_id else ""))
        return True

    # Topic id stale/invalid? Don't lose the alert — resend to General + flag it.
    if message_thread_id and "thread not found" in detail.lower():
        print(f"[telegram] topic {message_thread_id} invalid — resending to "
              "General so the alert isn't lost (fix the topic id with telegram-setup).")
        note = ("⚠️ <i>(topic id stale — posted here; re-run telegram-setup)</i>\n")
        ok2, detail2 = _post(note + text, parse_mode, None)
        if ok2:
            print(f"[telegram] sent to chat {config.TELEGRAM_CHAT_ID} (General)")
            return True
        detail = detail2 or detail

    print(f"[telegram] WARNING: {detail}. Check the token / that you've messaged "
          "the bot, and the topic ids (telegram-setup).")
    return False


if __name__ == "__main__":  # `python -m sectorbot.telegram`
    send_telegram("✅ SectorBot Telegram alert test — your bridge is wired up.")
