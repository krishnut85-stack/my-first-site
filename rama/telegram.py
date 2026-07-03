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


def send_telegram(text: str, parse_mode: str = "HTML") -> bool:
    """Send `text` to the configured Telegram chat. Returns True if delivered.

    Falls back to a console dry-run when no token/chat id is configured.
    """
    if not configured():
        print("\n[telegram dry-run] TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set "
              "— would have sent:\n")
        print(text + "\n")
        print("Set the two env vars (see .env.example) to actually deliver.")
        return False

    url = f"https://api.telegram.org/bot{config.TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = urllib.parse.urlencode({
        "chat_id": config.TELEGRAM_CHAT_ID,
        "text": text[:4096],          # Telegram hard limit per message
        "parse_mode": parse_mode,
        "disable_web_page_preview": "true",
    }).encode()

    try:
        with urllib.request.urlopen(url, data=payload, timeout=20) as resp:
            body = json.loads(resp.read().decode())
        if body.get("ok"):
            print(f"[telegram] sent to chat {config.TELEGRAM_CHAT_ID}")
            return True
        print(f"[telegram] WARNING: API rejected the message: {body}")
        return False
    except urllib.error.HTTPError as exc:
        # Most common cause: wrong token (401) or chat id / bot never /start-ed.
        detail = ""
        try:
            detail = exc.read().decode()
        except Exception:  # noqa: BLE001
            pass
        print(f"[telegram] WARNING: HTTP {exc.code} — {detail or exc.reason}. "
              "Check the token and that you have messaged the bot at least once.")
        return False
    except Exception as exc:  # noqa: BLE001
        print(f"[telegram] WARNING: send failed ({exc}). Trading run still OK.")
        return False


if __name__ == "__main__":  # `python -m rama.telegram`
    send_telegram("✅ Rama Telegram alert test — your bridge is wired up.")
