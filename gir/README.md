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
| 🕐 Session clock | `market_session.py` (shared by all of the above) |
| 🧭 Macro cycle | `macro_cycle.py` + `macro_signals.json` |

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

> ⏰ **`market_session.py` must sit at `/home/globalbot/market_session.py`.**
> Every strategy imports it for the NSE session clock — since the Closing
> Auction Session went live (2026-08-03) the day ends in stages: F&O stocks
> leave continuous trading at 15:15 and settle by auction, the closing price is
> published at 15:35, and derivatives run to 15:40. The files in `raven/`,
> `falcon/` and `hunter/` find it one directory up, so copy it before (or with)
> any strategy file that imports it — they will not start without it.
>
> 🧭 **`macro_cycle.py` and `macro_signals.json` go beside `gir.py` too.**
> `macro_signals.json` holds the three inputs to the rate-cycle state machine —
> repo direction, the 10-year G-sec 3-month slope, and bank credit growth —
> and needs refreshing **monthly, and after every MPC meeting**. Past 45 days
> the signals stop being able to change the phase and GIR logs a reminder
> instead of trading on a stale read.
