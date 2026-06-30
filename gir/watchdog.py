#!/usr/bin/env python3
"""GIR service watchdog. Alerts Telegram if a core service is down or stale.
Separate from the bot so the bug it's watching for can't take it down too."""
import os, sys, time, subprocess, requests
from datetime import datetime, timezone, timedelta

# Reuse the bot's Telegram creds (same var the bot reads — gir.py line 201)
TG_TOKEN = os.getenv("TELEGRAM_TOKEN", "")
TG_CHAT  = os.getenv("TELEGRAM_CHAT_ID", "")

# (service, log_file_to_check_freshness, max_stale_minutes). None = check active only.
CHECKS = [
    ("globaleye.service",          None,                                   None),
    ("raven.service",              None,                                   None),
    ("paper_exit_monitor.service", "/home/globalbot/paper/exit_monitor.service.log", 3),
]

def tg(msg):
    if not TG_TOKEN or not TG_CHAT:
        print("WATCHDOG: no TG creds, cannot alert:", msg); return
    try:
        requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage",
                      json={"chat_id": TG_CHAT, "text": msg, "parse_mode": "Markdown"},
                      timeout=10)
    except Exception as e:
        print("WATCHDOG: TG send failed:", e)

def is_active(svc):
    r = subprocess.run(["systemctl","is-active",svc], capture_output=True, text=True)
    return r.stdout.strip() == "active"

def log_stale_min(path):
    try: return (time.time() - os.path.getmtime(path)) / 60.0
    except Exception: return None


def _nse_open():
    ist = datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)
    if ist.weekday() >= 5:  # Sat/Sun
        return False
    mins = ist.hour * 60 + ist.minute
    return (9*60+15) <= mins <= (15*60+30)


def raven_blind_problem():
    """RAVEN-specific: process can be ACTIVE but blind (bad token => every quote fails),
    which is exactly what process-alive checks miss. Only meaningful in market hours."""
    if not _nse_open():
        return None
    try:
        # last 6 minutes of RAVEN journal
        r = subprocess.run(["journalctl","-u","raven.service","--since","6 min ago","--no-pager"],
                           capture_output=True, text=True, timeout=15)
        out = r.stdout
    except Exception:
        return None
    if not out.strip():
        return None
    # 1) explicit token failure = blind
    if "Incorrect" in out and "access_token" in out:
        return "RAVEN active but BLIND: 'Incorrect access_token' in last 6 min"
    # 2) repeated quote failures
    if out.count("quote failed") >= 3:
        return "RAVEN active but failing quotes (>=3 'quote failed' in 6 min)"
    # 3) no heartbeat AND no scan evidence in 6 min during market hours = stalled
    if ("heartbeat" not in out) and ("scan" not in out) and ("PARSED" not in out):
        return "RAVEN active but SILENT: no heartbeat/scan in last 6 min during market hours"
    return None


problems = []
for svc, logf, max_stale in CHECKS:
    if not is_active(svc):
        problems.append(f"❌ *{svc}* is DOWN (not active)")
        continue
    if logf and max_stale and _nse_open():
        stale = log_stale_min(logf)
        if stale is None:
            problems.append(f"⚠️ *{svc}* active but log missing: {logf}")
        elif stale > max_stale:
            problems.append(f"⚠️ *{svc}* active but log STALE {stale:.0f}min (>{max_stale})")

_rb = raven_blind_problem()
if _rb:
    problems.append(f"\u26a0\ufe0f *raven.service* {_rb}")

if problems:
    tg("🚨 *GIR WATCHDOG*\n" + "\n".join(problems))
    print("WATCHDOG ALERT:", problems); sys.exit(1)
else:
    print("WATCHDOG OK: all core services healthy"); sys.exit(0)
