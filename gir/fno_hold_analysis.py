#!/usr/bin/env python3
"""
fno_hold_analysis.py  -  "Should we have held instead of squaring off?"
=======================================================================
The F&O build-up bot squares off intraday (15:20). But a build-up signal can
keep playing out - the option might "explode" the next day. This tool tests that
hunch: for each closed build-up trade, it fetches the option's CURRENT price via
kite.quote() and compares two outcomes:

  - actual  : the square-off P&L we recorded
  - if-held : (current option price - entry) x qty  (i.e. still holding today)

If "if-held" beats "square-off" across the book, holding longer is worth testing.
Uses live quotes only (no paid historical-data subscription needed).

NOTE: only works for options that are still LISTED (not expired) and quotable.
Expired/illiquid ones are skipped and reported.

Usage:
  python3 fno_hold_analysis.py                       # strategy FNO_BUILDUP, last 10 days
  python3 fno_hold_analysis.py --strategy FNO_PAPER_STUDY --days 5
"""

import os
import sys
import json
import sqlite3
import argparse
from datetime import datetime, timedelta

HOME = "/home/globalbot"
TRADES_DB = os.environ.get("EQ_TRADES_DB", f"{HOME}/paper/trades.db")
TOKEN_FILE = f"{HOME}/data/kite_token.json"
ENV_FILE = f"{HOME}/.env"


def _fmt(n):
    try:
        return f"{n:,.0f}"
    except Exception:
        return str(n)


def _load_env():
    try:
        from dotenv import load_dotenv
        load_dotenv(ENV_FILE)
    except Exception:
        try:
            for line in open(ENV_FILE):
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())
        except Exception:
            pass


def get_kite():
    from kiteconnect import KiteConnect
    api_key = os.environ.get("KITE_API_KEY", "").strip()
    token = ""
    try:
        token = (json.load(open(TOKEN_FILE)).get("access_token") or "").strip()
    except Exception:
        pass
    if not token:
        token = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    k = KiteConnect(api_key=api_key)
    k.set_access_token(token)
    return k


def load_trades(strategy, days):
    conn = sqlite3.connect(TRADES_DB, timeout=10)
    conn.row_factory = sqlite3.Row
    cutoff = (datetime.utcnow() - timedelta(days=days)).strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT * FROM paper_trades WHERE strategy=? AND status='CLOSED' "
        "AND substr(entry_ts,1,10) >= ? ORDER BY entry_ts ASC",
        (strategy, cutoff)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def quote_now(kite, symbols):
    out = {}
    CHUNK = 200
    uniq = list({s for s in symbols if s})
    import time
    for i in range(0, len(uniq), CHUNK):
        batch = uniq[i:i + CHUNK]
        keys = [f"NFO:{s}" for s in batch]
        try:
            q = kite.quote(keys)
            for s in batch:
                d = q.get(f"NFO:{s}")
                if d and d.get("last_price"):
                    out[s] = float(d["last_price"])
        except Exception:
            pass
        time.sleep(0.35)
    return out


def main():
    ap = argparse.ArgumentParser(description="Hold vs square-off analysis for F&O option trades")
    ap.add_argument("--strategy", default="FNO_BUILDUP")
    ap.add_argument("--days", type=int, default=10)
    args = ap.parse_args()

    _load_env()
    trades = load_trades(args.strategy, args.days)
    if not trades:
        print(f"No closed {args.strategy} trades in the last {args.days} days.")
        return

    try:
        kite = get_kite()
    except Exception as e:
        print(f"Kite login failed: {e}")
        sys.exit(1)

    now_px = quote_now(kite, [t["symbol"] for t in trades])

    print("=" * 78)
    print(f"  HOLD vs SQUARE-OFF  -  strategy={args.strategy}  ({len(trades)} closed trades)")
    print(f"  'if-held' = option's price RIGHT NOW vs entry (still holding today)")
    print("=" * 78)
    print(f"\n  {'option':<24}{'entry':>8}{'exit(sq)':>9}{'now':>8}"
          f"{'sq P&L':>10}{'held P&L':>10}  better")

    tot_sq = tot_held = 0.0
    counted = skipped = 0
    better_held = 0
    for t in trades:
        sym = t["symbol"]
        entry = float(t.get("entry_price") or 0)
        qty = int(t.get("qty") or 0)
        sq_pnl = float(t.get("pnl") or 0)
        cur = now_px.get(sym)
        if entry <= 0 or qty <= 0 or cur is None:
            skipped += 1
            continue
        held_pnl = (cur - entry) * qty
        tot_sq += sq_pnl
        tot_held += held_pnl
        counted += 1
        better = "HELD" if held_pnl > sq_pnl else "sq-off"
        if held_pnl > sq_pnl:
            better_held += 1
        print(f"  {sym[:24]:<24}{entry:>8.1f}{float(t.get('exit_price') or 0):>9.1f}"
              f"{cur:>8.1f}{_fmt(sq_pnl):>10}{_fmt(held_pnl):>10}  {better}")

    if counted == 0:
        print("\n  No quotable (still-listed) options to compare - likely all expired.")
        return

    print("-" * 78)
    print(f"  Trades compared: {counted}   (skipped/expired: {skipped})")
    print(f"  Square-off total P&L : Rs {_fmt(tot_sq)}")
    print(f"  If-held-to-now P&L   : Rs {_fmt(tot_held)}")
    diff = tot_held - tot_sq
    print(f"  Difference (held - sq): Rs {_fmt(diff)}   "
          f"({better_held}/{counted} trades better held)")
    print()
    if diff > abs(tot_sq) * 0.2 and tot_held > tot_sq:
        print("  => Holding would have made meaningfully MORE. Worth testing a multi-day")
        print("     hold variant (no intraday square-off) on a few trades.")
    elif diff < 0:
        print("  => Squaring off was BETTER - the options faded after entry day.")
        print("     Intraday square-off is protecting you; keep it.")
    else:
        print("  => Roughly a wash so far. Re-run with more trades before deciding.")
    print("\n  NOTE: 'now' is a single snapshot; it captures explosions AND fades up to")
    print("  today. More trades = more reliable signal. Not a full day-by-day backtest.")


if __name__ == "__main__":
    main()
