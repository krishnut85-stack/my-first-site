#!/usr/bin/env python3
"""
gir_telegram_cmd.py
Standalone Telegram command listener for GIR.
"""
import os
import time
import json
import logging
import subprocess
from pathlib import Path

import requests

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
CHAT_ID   = os.getenv("TELEGRAM_CHAT_ID", "").strip()
GIR_PY    = Path("/home/globalbot/gir.py")
STATE_FILE = Path("/home/globalbot/data/telegram_cmd_offset.json")

if not BOT_TOKEN or not CHAT_ID:
    raise SystemExit("TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set")

AUTHORIZED = {int(CHAT_ID)}
API = f"https://api.telegram.org/bot{BOT_TOKEN}"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [cmd] %(levelname)s %(message)s",
)
log = logging.getLogger("gir_cmd")


def tg_send_message(text):
    try:
        requests.post(f"{API}/sendMessage",
                      data={"chat_id": CHAT_ID, "text": text},
                      timeout=20)
    except Exception as e:
        log.error("sendMessage failed: %s", e)


def tg_send_document(path, caption=""):
    try:
        with open(path, "rb") as f:
            r = requests.post(
                f"{API}/sendDocument",
                data={"chat_id": CHAT_ID, "caption": caption},
                files={"document": (path.name, f)},
                timeout=120,
            )
        r.raise_for_status()
    except Exception as e:
        log.error("sendDocument failed: %s", e)
        tg_send_message("Failed to send %s: %s" % (path.name, e))


def cmd_getcode(chat_id):
    if not GIR_PY.exists():
        tg_send_message("gir.py not found")
        return
    size_kb = GIR_PY.stat().st_size / 1024
    tg_send_document(GIR_PY, caption="gir.py (%.1f KB)" % size_kb)
    log.info("Sent gir.py to chat %s", chat_id)


def cmd_status(chat_id):
    try:
        r = subprocess.run(["systemctl", "is-active", "globaleye"],
                           capture_output=True, text=True, timeout=10)
        state = r.stdout.strip() or "unknown"
        tg_send_message("globaleye.service: " + state)
    except Exception as e:
        tg_send_message("status check failed: %s" % e)


def cmd_ping(chat_id):
    tg_send_message("pong - command listener alive")


COMMANDS = {
    "/getcode": cmd_getcode,
    "/status":  cmd_status,
    "/ping":    cmd_ping,
}


def load_offset():
    try:
        return json.loads(STATE_FILE.read_text()).get("offset", 0)
    except Exception:
        return 0


def save_offset(offset):
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps({"offset": offset}))
    except Exception as e:
        log.warning("couldn't persist offset: %s", e)


def process_update(upd):
    msg = upd.get("message") or upd.get("channel_post") or {}
    text = (msg.get("text") or "").strip()
    chat_id = (msg.get("chat") or {}).get("id")

    if not text or chat_id is None:
        return
    if chat_id not in AUTHORIZED:
        log.warning("Ignoring command from unauthorized chat %s", chat_id)
        return

    cmd = text.split()[0].split("@")[0].lower()
    handler = COMMANDS.get(cmd)
    if handler:
        log.info("Running %s for chat %s", cmd, chat_id)
        try:
            handler(chat_id)
        except Exception as e:
            log.exception("Handler %s crashed", cmd)
            tg_send_message("%s crashed: %s" % (cmd, e))


def main():
    offset = load_offset()
    log.info("Starting command listener (offset=%d)", offset)
    while True:
        try:
            r = requests.get(
                f"{API}/getUpdates",
                params={"offset": offset, "timeout": 30},
                timeout=40,
            )
            data = r.json()
            if not data.get("ok"):
                log.error("getUpdates not ok: %s", data)
                time.sleep(5)
                continue
            for upd in data.get("result", []):
                process_update(upd)
                offset = upd["update_id"] + 1
                save_offset(offset)
        except requests.exceptions.ReadTimeout:
            continue
        except Exception as e:
            log.exception("poll loop error: %s", e)
            time.sleep(5)


if __name__ == "__main__":
main()	
