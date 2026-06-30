"""
F&O SELL safety gate.
Uses Kite live positions as source of truth, bypassing self.positions amnesia.
Blocks any SELL that would create or deepen a short position.

Created May 18 2026 after UNITDSPR naked short incident.
"""
import json
import os
import re
from datetime import datetime, timezone, timedelta

IST = timezone(timedelta(hours=5, minutes=30))
EXIT_HISTORY_PATH = '/home/globalbot/data/exit_history.json'
SAFETY_LOG_PATH = '/home/globalbot/logs/safety_gate.log'


def _log(msg):
    try:
        os.makedirs(os.path.dirname(SAFETY_LOG_PATH), exist_ok=True)
        ts = datetime.now(IST).strftime('%Y-%m-%d %H:%M:%S')
        with open(SAFETY_LOG_PATH, 'a') as f:
            f.write(ts + ' ' + msg + '\n')
    except Exception:
        pass


def can_sell_fno(kite, tradingsymbol, requested_qty):
    """
    Returns (allowed, safe_qty, reason).
    True only if SELL would close an existing long. False if no position,
    qty<=0, or fetch fails. safe_qty is capped to actual held quantity.
    """
    if not tradingsymbol or requested_qty <= 0:
        return False, 0, "invalid_input"

    try:
        positions = kite.positions().get('net', [])
    except Exception as e:
        _log("BLOCK " + str(tradingsymbol) + " qty=" + str(requested_qty) + ": positions fetch failed: " + str(e))
        return False, 0, "kite_fetch_failed"

    current = None
    for p in positions:
        if p.get('tradingsymbol') == tradingsymbol:
            current = p
            break

    if current is None:
        _log("BLOCK " + tradingsymbol + " qty=" + str(requested_qty) + ": NOT IN KITE - would create naked short")
        return False, 0, "not_in_kite_naked_short_risk"

    held_qty = current.get('quantity', 0)

    if held_qty <= 0:
        _log("BLOCK " + tradingsymbol + " qty=" + str(requested_qty) + ": current_qty=" + str(held_qty) + " (flat/short) - would deepen short")
        return False, 0, "current_qty_" + str(held_qty) + "_would_short"

    safe_qty = min(requested_qty, held_qty)
    if safe_qty < requested_qty:
        _log("CAP " + tradingsymbol + ": requested=" + str(requested_qty) + " held=" + str(held_qty) + " using=" + str(safe_qty))

    _log("ALLOW " + tradingsymbol + " qty=" + str(safe_qty) + " (held=" + str(held_qty) + ")")
    return True, safe_qty, "ok"


def was_exited_today(tradingsymbol):
    """Check exit_history.json for any exit of tradingsymbol on today's IST date."""
    try:
        with open(EXIT_HISTORY_PATH) as f:
            history = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return False

    today = datetime.now(IST).strftime('%Y-%m-%d')

    entries = history.get(tradingsymbol, [])
    if not isinstance(entries, list):
        entries = [entries]

    for e in entries:
        if not isinstance(e, dict):
            continue
        ts = e.get('ts', '') or e.get('exit_time', '')
        if ts.startswith(today):
            return True

    m = re.match(r'^([A-Z]+)\d', tradingsymbol)
    if m:
        underlying = m.group(1)
        for key, val in history.items():
            if key == tradingsymbol:
                continue
            if key.startswith(underlying) and key != underlying:
                entries2 = val if isinstance(val, list) else [val]
                for e2 in entries2:
                    if isinstance(e2, dict):
                        ts2 = e2.get('ts', '') or e2.get('exit_time', '')
                        if ts2.startswith(today):
                            return True

    return False
