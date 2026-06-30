# GIR — main NSE trading bot 🦅 (full source backup)

This folder is the **complete source of the GIR main NSE bot** — the program that
posts to the **GIR Alerts** Telegram group. Main entry point: **`gir.py`**.

> ⚠️ This is **NOT** the `gircrypto` crypto bot — that was deliberately excluded.
> This is the **NSE equity / derivatives** system only.

## Live strategies → files
| Strategy | File |
|----------|------|
| 🏛️ Parliament | `gir.py` |
| 📈 FNO (F&O) | `fno_paper_study.py`, `regime_monitor_fno.py` |
| 🦅 Falcon | `falcon/falcon.py` |
| 🐦‍⬛ Raven | `raven/raven.py` |
| 🔥 Phoenix / equity floor | `gir_eq_floor.py`, `gir.py` |
| 🎯 Hunter | `hunter/` |
| 📝 Paper engine | `paper/` |

Older versions, patches and one-off scripts are kept at the top level and in
`archive/`, `old_python_backup/`, `old_griffin_backup/` as a historical backup.

## 🔒 Privacy & secrets
- **No credentials are committed** — keys load from env at runtime
  (`KITE_*`, `ZERODHA_*`, `TELEGRAM_*`, `GEMINI_*`) via `/home/globalbot/.env`.
- Personal identifiers (Kite login ID, owner name, server IP) were **scrubbed**
  from every file before upload.
- `.gitignore` blocks `.env`, tokens, logs, databases and CSV/JSON data.

## Runs on the droplet
Lives at **`/home/globalbot/`** (e.g. `/home/globalbot/gir.py`,
`/home/globalbot/raven/raven.py`). Raven runs as a systemd service
(`raven.service`). This GitHub copy is **source only** — data/portfolios/tokens
stay on the droplet. Deploy a fix with: edit here → `git pull` on the droplet →
copy the file to its live path → restart the relevant service.
