#!/usr/bin/env python3
"""eod_report.py - Phase 6C Daily EOD Summary
Generates a readable markdown report of the day's paper trading activity.
Saves to /home/globalbot/paper/reports/YYYY-MM-DD.md
Updates /home/globalbot/paper/reports/latest.md symlink.

Run via systemd timer at 10:30 UTC daily (4:00 PM IST).
Read-only on databases. Cannot place orders.
"""
import os, sys, sqlite3, json, subprocess
from datetime import datetime, timezone, timedelta
from collections import defaultdict
from pathlib import Path
import notify

TRADES_DB = "/home/globalbot/paper/trades.db"
EVENTS_DB = "/home/globalbot/paper/events.db"
REPORTS_DIR = Path("/home/globalbot/paper/reports")
SCOREBOARD = "/home/globalbot/paper/scoreboard.py"

def run_scoreboard_json(since):
    """Invoke scoreboard.py --json to get the day's stats."""
    result = subprocess.run(
        ["python3", SCOREBOARD, "--json", "--since", since],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode != 0:
        raise RuntimeError(f"scoreboard failed: {result.stderr}")
    return json.loads(result.stdout)

def fetch_day_trades(date_str):
    """All trades that entered OR exited on the given date."""
    conn = sqlite3.connect(TRADES_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("""
        SELECT * FROM paper_trades
        WHERE date(entry_ts) = ? OR date(exit_ts) = ?
        ORDER BY entry_ts
    """, (date_str, date_str))
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows

def fetch_errors(date_str):
    conn = sqlite3.connect(EVENTS_DB)
    cur = conn.cursor()
    cur.execute("""
        SELECT module, event_type, COUNT(*)
        FROM bot_events
        WHERE date(ts_utc) = ?
          AND (event_type LIKE '%FAIL%' OR event_type LIKE '%ERROR%')
        GROUP BY module, event_type
        ORDER BY COUNT(*) DESC
    """, (date_str,))
    rows = cur.fetchall()
    conn.close()
    return rows

def fmt_trade_row(t):
    pnl = t.get("pnl")
    pnl_str = f"Rs.{pnl:+.2f}" if pnl is not None else "-"
    pct = t.get("pnl_pct")
    pct_str = f"{pct:+.2f}%" if pct is not None else "-"
    return (f"| {t['trade_id'][-12:]} | {t['strategy']} | {t['symbol']:<12} | "
            f"{t['side']:<4} | {t['qty']:>4} | {t['entry_price']:>8.2f} | "
            f"{(t.get('exit_price') or 0):>8.2f} | {pnl_str:>10} | {pct_str:>7} | "
            f"{t['status']:<6} | {(t.get('exit_reason') or '-')[:20]:<20} |")

def generate_report(date_str):
    data = run_scoreboard_json(date_str)
    trades = fetch_day_trades(date_str)
    errors = fetch_errors(date_str)
    o = data["overview"]
    lines = []
    lines.append(f"# Paper Trading EOD Report - {date_str}")
    lines.append(f"")
    lines.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")
    lines.append(f"")
    lines.append(f"## Overview")
    lines.append(f"")
    lines.append(f"- **Total trades**: {o['total']}")
    lines.append(f"- **Closed**: {o['closed']}  ({o['wins']} wins / {o['losses']} losses)")
    lines.append(f"- **Open**: {o['open']}")
    lines.append(f"- **Win rate**: {o['win_rate_pct']}%")
    lines.append(f"- **Total P&L**: Rs.{o['total_pnl']}")
    lines.append(f"- **Avg P&L %**: {o['avg_pnl_pct']}%")
    lines.append(f"- **Avg hold**: {o['avg_hold_days']} days")
    if o['exit_capture_pct'] is not None:
        lines.append(f"- **Exit capture**: {o['exit_capture_pct']}% of best possible price during life of trade")
    lines.append(f"")
    lines.append(f"## By Strategy")
    lines.append(f"")
    lines.append(f"| Strategy | Total | Closed | Win% | Total P&L | Avg P&L% | Hold days |")
    lines.append(f"|---|---:|---:|---:|---:|---:|---:|")
    for k, s in data["by_strategy"].items():
        lines.append(f"| {k} | {s['total']} | {s['closed']} | {s['win_rate_pct']}% | Rs.{s['total_pnl']} | {s['avg_pnl_pct']}% | {s['avg_hold_days']} |")
    lines.append(f"")
    lines.append(f"## By Signal Source")
    lines.append(f"")
    lines.append(f"| Signal Source | Total | Closed | Win% | Total P&L | Avg P&L% |")
    lines.append(f"|---|---:|---:|---:|---:|---:|")
    for k, s in data["by_signal_source"].items():
        lines.append(f"| {k} | {s['total']} | {s['closed']} | {s['win_rate_pct']}% | Rs.{s['total_pnl']} | {s['avg_pnl_pct']}% |")
    lines.append(f"")
    lines.append(f"## Exit Reasons")
    lines.append(f"")
    if data["exit_reasons"]:
        lines.append(f"| Reason | Count | Total P&L |")
        lines.append(f"|---|---:|---:|")
        for r, v in sorted(data["exit_reasons"].items(), key=lambda x: -x[1]["count"]):
            lines.append(f"| {r} | {v['count']} | Rs.{v['total_pnl']} |")
    else:
        lines.append(f"_No exits today._")
    lines.append(f"")
    lines.append(f"## Trade Details")
    lines.append(f"")
    if trades:
        lines.append(f"| Trade ID | Strategy | Symbol | Side | Qty | Entry | Exit | P&L | % | Status | Reason |")
        lines.append(f"|---|---|---|---|---:|---:|---:|---:|---:|---|---|")
        for t in trades:
            lines.append(fmt_trade_row(t))
    else:
        lines.append(f"_No trades today._")
    lines.append(f"")
    lines.append(f"## Gemini Cost")
    lines.append(f"")
    g = data["gemini"]
    lines.append(f"- Calls: {g['calls']}")
    lines.append(f"- Tokens: {g['tokens']:,}")
    lines.append(f"- Cost: **Rs.{g['cost_inr']}**")
    lines.append(f"")
    lines.append(f"## Errors / Failures Today")
    lines.append(f"")
    if errors:
        lines.append(f"| Module | Event | Count |")
        lines.append(f"|---|---|---:|")
        for module, event, count in errors:
            lines.append(f"| {module} | {event} | {count} |")
    else:
        lines.append(f"_No errors recorded._")
    lines.append(f"")
    lines.append(f"## Top Event Types Today")
    lines.append(f"")
    lines.append(f"| Module | Event | Count |")
    lines.append(f"|---|---|---:|")
    for ev in data["events"][:15]:
        lines.append(f"| {ev['module']} | {ev['event']} | {ev['count']} |")
    lines.append(f"")
    return "\n".join(lines)

def main():
    if len(sys.argv) > 1:
        date_str = sys.argv[1]
    else:
        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report = generate_report(date_str)
    out_path = REPORTS_DIR / f"{date_str}.md"
    out_path.write_text(report)
    latest = REPORTS_DIR / "latest.md"
    if latest.exists() or latest.is_symlink():
        latest.unlink()
    latest.symlink_to(out_path.name)
    print(f"Report written: {out_path}")
    print(f"Latest symlink: {latest} -> {out_path.name}")
    # Push Telegram summary
    try:
        o = data["overview"] if "data" in dir() else None
    except Exception:
        o = None
    try:
        import json as _json, subprocess as _sp
        r = _sp.run(["python3", "/home/globalbot/paper/scoreboard.py", "--json", "--since", date_str],
                    capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            sb = _json.loads(r.stdout)
            ov = sb["overview"]
            cap = sb.get("capital") or {}
            notify.notify_eod_summary(
                date_str=date_str,
                n_total=ov["total"],
                n_closed=ov["closed"],
                total_pnl=ov["total_pnl"],
                win_rate=ov["win_rate_pct"],
                capital_balance=cap.get("current_balance", 0),
            )
    except Exception:
        pass
    print()
    print(f"=== PREVIEW (first 60 lines) ===")
    print("\n".join(report.split("\n")[:60]))

if __name__ == "__main__":
    main()
