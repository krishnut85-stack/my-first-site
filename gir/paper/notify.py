#!/usr/bin/env python3
"""notify.py - Telegram notification helper for paper trading layer.
Reads TELEGRAM_TOKEN + TELEGRAM_CHAT_ID from /home/globalbot/.env.
Silent on failure - notification errors never crash a calling service.
"""
import os, sys, requests, logging
from datetime import datetime, timezone

try:
    from dotenv import load_dotenv
    load_dotenv("/home/globalbot/.env")
except ImportError:
    pass

log = logging.getLogger("notify")
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

def send(text: str, parse_mode: str = "Markdown") -> bool:
    """Send Telegram message. Returns True on success, False otherwise. Never raises."""
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        return False
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
        r = requests.post(url, data={
            "chat_id": TELEGRAM_CHAT_ID,
            "text": text,
            "parse_mode": parse_mode,
            "disable_web_page_preview": "true",
        }, timeout=10)
        return r.status_code == 200 and r.json().get("ok", False)
    except Exception as e:
        try:
            log.warning("telegram send failed: %s", e)
        except Exception:
            pass
        return False

def notify_paper_entry(symbol, side, qty, price, strategy, signal_source=""):
    """Called when paper_place_order records a new paper entry."""
    msg = (
        f"📈 *PAPER ENTRY*\n"
        f"`{symbol}` {side} qty {qty} @ Rs.{price:.2f}\n"
        f"Strategy: `{strategy}`\n"
        f"Source: `{signal_source}`\n"
        f"_Paper trade — no real money_"
    )
    return send(msg)

def notify_paper_exit(symbol, qty, entry_price, exit_price, pnl, reason, strategy=""):
    """Called when virtual exit fires."""
    pnl_pct = ((exit_price - entry_price) / entry_price) * 100 if entry_price else 0
    emoji = "🟢" if pnl > 0 else ("🔴" if pnl < 0 else "⚪")
    msg = (
        f"{emoji} *PAPER EXIT*\n"
        f"`{symbol}` qty {qty} entry Rs.{entry_price:.2f} → exit Rs.{exit_price:.2f}\n"
        f"P&L: *Rs.{pnl:+.2f}* ({pnl_pct:+.2f}%)\n"
        f"Reason: `{reason}`\n"
        f"Strategy: `{strategy}`"
    )
    return send(msg)

def notify_eod_summary(date_str, n_total, n_closed, total_pnl, win_rate, capital_balance):
    """Daily EOD summary push."""
    msg = (
        f"📊 *EOD REPORT — {date_str}*\n\n"
        f"Trades today: *{n_total}* (closed: {n_closed})\n"
        f"Win rate: *{win_rate}%*\n"
        f"Total P&L: *Rs.{total_pnl:+.2f}*\n"
        f"Capital balance: Rs.{capital_balance:,.2f}\n\n"
        f"`cat /home/globalbot/paper/reports/latest.md` for full report"
    )
    return send(msg)

def notify_error(module, event, detail=""):
    """Critical error notification."""
    msg = (
        f"🚨 *ERROR — {module}*\n"
        f"Event: `{event}`\n"
        f"{detail[:300]}"
    )
    return send(msg)

if __name__ == "__main__":
    # CLI test mode
    if len(sys.argv) > 1:
        ok = send(" ".join(sys.argv[1:]))
        print(f"Send result: {ok}")
    else:
        ok = send(f"✅ notify.py wired at {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')} — Standard mode")
        print(f"Test send: {ok}")
