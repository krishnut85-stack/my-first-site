# GIR — main trading bot 🦅

This folder holds the **GIR ("My Stock Alerts") main bot** — the program that runs
the strategies that post to the **GIR Alerts** Telegram group:

| Strategy | File (entry/logic) |
|----------|--------------------|
| 🏛️ Parliament | `gir.py` |
| 📈 FNO (F&O) | `fno_paper_study.py` |
| 🦅 Falcon | `falcon.py` |
| 🐦‍⬛ Raven | `raven.py` |
| 🔥 Phoenix / Health | `gir.py`, `decision_brain.py`, `hunter*.py` |

Supporting modules: `decision_brain.py`, `executor.py`, `scorer.py`,
`paper_trader.py`, `gir_eq_floor.py`, `market_calendar.py`,
`hunter.py` / `hunter_config.py` / `hunter_execute.py` / `hunter_manage.py`.

> **This is a separate program from Mayura** (the peacock bot in the rest of this
> repo). It is kept here only so Claude Code can read and work on it directly.

## 🔒 Secrets — NONE are committed
Every credential is loaded from environment variables at runtime
(`KITE_API_KEY`, `KITE_API_SECRET`, `KITE_TOTP_SECRET`, `ZERODHA_USER_ID`,
`ZERODHA_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, …) — typically from
`/home/globalbot/.env` on the droplet. Nothing secret lives in these files, and
`.gitignore` here blocks `.env`, tokens, logs and data files. The hardcoded
Zerodha login-ID fallback was scrubbed before upload.

## Runs on the droplet
On the server this lives at `/home/globalbot/gircrypto` and is driven by cron +
the live Kite token. This GitHub copy is the **source code** for review/edits —
data files, portfolios and tokens stay on the droplet (not in git).
