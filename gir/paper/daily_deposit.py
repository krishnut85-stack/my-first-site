#!/usr/bin/env python3
"""daily_deposit.py - adds daily Rs.5000 to capital ledger (weekdays only).
Idempotent: won't double-deposit on same date. Called by EOD service.
"""
import sqlite3, sys
from datetime import datetime, timezone

TRADES_DB = "/home/globalbot/paper/trades.db"
DAILY_AMOUNT = 5000.00

def main():
    now = datetime.now(timezone.utc)
    # Weekday check: 0=Mon, 6=Sun
    if now.weekday() >= 5:
        print(f"[deposit] skipped - weekend (day={now.weekday()})")
        return
    today_str = now.strftime("%Y-%m-%d")
    conn = sqlite3.connect(TRADES_DB)
    cur = conn.cursor()
    # Idempotent check: did we already deposit today?
    cur.execute("""SELECT COUNT(*) FROM paper_capital_ledger
                   WHERE kind='DAILY_DEPOSIT' AND date(ts_utc) = ?""", (today_str,))
    if cur.fetchone()[0] > 0:
        print(f"[deposit] already deposited for {today_str}")
        conn.close()
        return
    cur.execute("""INSERT INTO paper_capital_ledger (ts_utc, kind, amount, note)
                   VALUES (?, 'DAILY_DEPOSIT', ?, ?)""",
                (now.isoformat(), DAILY_AMOUNT, f"Daily Rs.{DAILY_AMOUNT} weekday deposit"))
    conn.commit()
    conn.close()
    print(f"[deposit] Rs.{DAILY_AMOUNT} credited for {today_str}")

if __name__ == "__main__":
    main()
