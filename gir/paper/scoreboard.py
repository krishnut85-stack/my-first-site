#!/usr/bin/env python3
"""scoreboard.py - Phase 6B Signal Performance Scoreboard
Reads trades.db + events.db, computes per-strategy/per-signal performance.
Read-only. Cannot place orders. Safe to run anytime.

Usage:
  python3 scoreboard.py          # human-readable summary
  python3 scoreboard.py --json   # JSON output for Phase 7 engine
  python3 scoreboard.py --since 2026-05-22  # filter by start date
"""
import sys, sqlite3, json, argparse
from collections import defaultdict
from datetime import datetime, timezone

TRADES_DB = "/home/globalbot/paper/trades.db"
EVENTS_DB = "/home/globalbot/paper/events.db"

def fetch_trades(since=None):
    conn = sqlite3.connect(TRADES_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    q = "SELECT * FROM paper_trades"
    params = []
    if since:
        q += " WHERE entry_ts >= ?"
        params.append(since)
    cur.execute(q, params)
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows

def fetch_gemini_cost(since=None):
    conn = sqlite3.connect(EVENTS_DB)
    cur = conn.cursor()
    q = "SELECT COUNT(*), COALESCE(SUM(cost_inr),0), COALESCE(SUM(tokens_in+tokens_out),0) FROM gemini_costs"
    params = []
    if since:
        q += " WHERE ts_utc >= ?"
        params.append(since)
    cur.execute(q, params)
    n, cost, toks = cur.fetchone()
    conn.close()
    return {"calls": n, "cost_inr": round(cost, 2), "tokens": toks}

def fetch_event_counts(since=None):
    conn = sqlite3.connect(EVENTS_DB)
    cur = conn.cursor()
    q = "SELECT module, event_type, COUNT(*) FROM bot_events"
    params = []
    if since:
        q += " WHERE ts_utc >= ?"
        params.append(since)
    q += " GROUP BY module, event_type ORDER BY COUNT(*) DESC"
    cur.execute(q, params)
    rows = cur.fetchall()
    conn.close()
    return [{"module": m, "event": e, "count": c} for m, e, c in rows]

def compute_stats(trades, group_by):
    """Group trades by field and compute aggregate stats."""
    groups = defaultdict(list)
    for t in trades:
        key = t.get(group_by) or "unknown"
        groups[key].append(t)
    out = {}
    for key, lst in groups.items():
        closed = [t for t in lst if t["status"] == "CLOSED"]
        open_ = [t for t in lst if t["status"] == "OPEN"]
        wins = [t for t in closed if (t.get("pnl") or 0) > 0]
        losses = [t for t in closed if (t.get("pnl") or 0) <= 0]
        total_pnl = sum(t.get("pnl") or 0 for t in closed)
        avg_pnl_pct = (sum(t.get("pnl_pct") or 0 for t in closed) / len(closed)) if closed else 0
        avg_hold = (sum(t.get("days_held") or 0 for t in closed) / len(closed)) if closed else 0
        win_rate = (len(wins) / len(closed) * 100) if closed else 0
        avg_win = (sum(t.get("pnl") or 0 for t in wins) / len(wins)) if wins else 0
        avg_loss = (sum(t.get("pnl") or 0 for t in losses) / len(losses)) if losses else 0
        # exit-quality: gap between actual exit and best counterfactual price during life
        cf_gaps = []
        for t in closed:
            if t.get("cf_max_favorable") is not None and t.get("entry_price") and t.get("exit_price"):
                if t["side"] == "BUY":
                    best_exit_price = t["entry_price"] + t["cf_max_favorable"]
                    actual_gain = t["exit_price"] - t["entry_price"]
                    best_gain = t["cf_max_favorable"]
                    if best_gain > 0:
                        cf_gaps.append(actual_gain / best_gain)
        exit_capture = (sum(cf_gaps) / len(cf_gaps) * 100) if cf_gaps else None
        out[key] = {
            "total": len(lst),
            "closed": len(closed),
            "open": len(open_),
            "wins": len(wins),
            "losses": len(losses),
            "win_rate_pct": round(win_rate, 1),
            "total_pnl": round(total_pnl, 2),
            "avg_pnl_pct": round(avg_pnl_pct, 2),
            "avg_win": round(avg_win, 2),
            "avg_loss": round(avg_loss, 2),
            "avg_hold_days": round(avg_hold, 1),
            "exit_capture_pct": round(exit_capture, 1) if exit_capture is not None else None,
        }
    return out

def exit_reason_breakdown(trades):
    out = defaultdict(lambda: {"count": 0, "total_pnl": 0.0})
    for t in trades:
        if t["status"] != "CLOSED": continue
        r = t.get("exit_reason") or "UNKNOWN"
        out[r]["count"] += 1
        out[r]["total_pnl"] += t.get("pnl") or 0
    return {k: {"count": v["count"], "total_pnl": round(v["total_pnl"], 2)} for k, v in out.items()}

def print_human(data):
    print()
    if data.get("capital"):
        c = data["capital"]
        print("=" * 70)
        print(f"  OBSERVATION MODE - Day {c['day_n']} (started {c['start_date']})")
        print(f"  Paper trading only - no real money involved")
        print("=" * 70)
        print()
        print(f"CAPITAL LEDGER")
        print(f"  Initial capital:       Rs.{c['initial_capital']:>12,.2f}")
        print(f"  Daily deposits:        Rs.{c['daily_deposits_total']:>12,.2f}  ({c['daily_deposit_amt']}/weekday)")
        print(f"  Total deposited:       Rs.{c['total_deposited']:>12,.2f}")
        print(f"  Realized P&L:          Rs.{c['realized_pnl']:>+12,.2f}")
        print(f"  Cash in open trades:   Rs.{c['cash_invested_open']:>12,.2f}")
        print(f"  Cash available:        Rs.{c['cash_available']:>12,.2f}")
        print(f"  Current balance:       Rs.{c['current_balance']:>12,.2f}")
        print(f"  Return on capital:     {c['return_pct']:>+12.2f}%")
        print()

    print("=" * 70)
    print("  PAPER TRADING SCOREBOARD")
    if data["since"]:
        print(f"  Since: {data['since']}")
    print("=" * 70)
    print()
    print(f"OVERVIEW")
    o = data["overview"]
    print(f"  Total trades:   {o['total']}")
    print(f"  Closed:         {o['closed']}  ({o['wins']} wins / {o['losses']} losses)")
    print(f"  Open:           {o['open']}")
    print(f"  Win rate:       {o['win_rate_pct']}%")
    print(f"  Total P&L:      Rs.{o['total_pnl']}")
    print(f"  Avg P&L %:      {o['avg_pnl_pct']}%")
    print(f"  Avg hold:       {o['avg_hold_days']} days")
    if o['exit_capture_pct'] is not None:
        print(f"  Exit capture:   {o['exit_capture_pct']}%  (of best possible price during trade)")
    print()
    print(f"BY STRATEGY")
    print(f"  {'strategy':<20} {'total':>6} {'closed':>7} {'win%':>6} {'totPnL':>10} {'avgPnL%':>8} {'hold':>6} {'capture%':>9}")
    for k, s in data["by_strategy"].items():
        cap = f"{s['exit_capture_pct']}" if s['exit_capture_pct'] is not None else "-"
        print(f"  {k:<20} {s['total']:>6} {s['closed']:>7} {s['win_rate_pct']:>6} {s['total_pnl']:>10} {s['avg_pnl_pct']:>8} {s['avg_hold_days']:>6} {cap:>9}")
    print()
    print(f"BY SIGNAL SOURCE")
    print(f"  {'signal_source':<30} {'total':>6} {'closed':>7} {'win%':>6} {'totPnL':>10} {'avgPnL%':>8}")
    for k, s in data["by_signal_source"].items():
        ks = (k or "")[:30]
        print(f"  {ks:<30} {s['total']:>6} {s['closed']:>7} {s['win_rate_pct']:>6} {s['total_pnl']:>10} {s['avg_pnl_pct']:>8}")
    print()
    print(f"EXIT REASON BREAKDOWN")
    for r, v in sorted(data["exit_reasons"].items(), key=lambda x: -x[1]["count"]):
        print(f"  {r:<30} count={v['count']:>4}  totPnL={v['total_pnl']}")
    print()
    g = data["gemini"]
    print(f"GEMINI COST")
    print(f"  Calls: {g['calls']}    Tokens: {g['tokens']}    Cost: Rs.{g['cost_inr']}")
    print()
    print(f"TOP 10 EVENT TYPES")
    for ev in data["events"][:10]:
        print(f"  {ev['module']:<25} {ev['event']:<30} {ev['count']:>6}")
    print()


def fetch_capital_state(trades):
    """Read capital ledger + compute current balance with unrealized P&L."""
    import sqlite3
    from datetime import datetime, timezone
    conn = sqlite3.connect(TRADES_DB)
    cur = conn.cursor()
    try:
        cur.execute("SELECT key, value FROM observation_meta")
        meta = dict(cur.fetchall())
        cur.execute("SELECT kind, SUM(amount) FROM paper_capital_ledger GROUP BY kind")
        ledger_sums = dict(cur.fetchall())
    except sqlite3.OperationalError:
        conn.close()
        return None
    conn.close()
    initial = ledger_sums.get("INITIAL_DEPOSIT", 0)
    daily = ledger_sums.get("DAILY_DEPOSIT", 0)
    total_deposited = initial + daily
    realized_pnl = sum((t.get("pnl") or 0) for t in trades if t["status"] == "CLOSED")
    open_trades = [t for t in trades if t["status"] == "OPEN"]
    unrealized = 0.0
    for t in open_trades:
        ltp = t.get("current_sl")
        ref = t.get("entry_price")
        if ref:
            unrealized += 0
    cash_invested = sum((t.get("entry_price") or 0) * (t.get("qty") or 0)
                        for t in open_trades)
    start_date = meta.get("start_date", "?")
    try:
        sd = datetime.strptime(start_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        day_n = (datetime.now(timezone.utc).date() - sd.date()).days + 1
    except Exception:
        day_n = "?"
    return {
        "mode": meta.get("mode", "?"),
        "start_date": start_date,
        "day_n": day_n,
        "initial_capital": initial,
        "daily_deposit_amt": float(meta.get("daily_deposit", 5000)),
        "daily_deposits_total": daily,
        "total_deposited": total_deposited,
        "realized_pnl": round(realized_pnl, 2),
        "cash_invested_open": round(cash_invested, 2),
        "cash_available": round(total_deposited + realized_pnl - cash_invested, 2),
        "current_balance": round(total_deposited + realized_pnl, 2),
        "return_pct": round((realized_pnl / total_deposited * 100) if total_deposited else 0, 2),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--since", default=None)
    args = ap.parse_args()
    trades = fetch_trades(args.since)
    closed = [t for t in trades if t["status"] == "CLOSED"]
    open_ = [t for t in trades if t["status"] == "OPEN"]
    wins = [t for t in closed if (t.get("pnl") or 0) > 0]
    losses = [t for t in closed if (t.get("pnl") or 0) <= 0]
    total_pnl = sum(t.get("pnl") or 0 for t in closed)
    avg_pnl_pct = (sum(t.get("pnl_pct") or 0 for t in closed) / len(closed)) if closed else 0
    avg_hold = (sum(t.get("days_held") or 0 for t in closed) / len(closed)) if closed else 0
    win_rate = (len(wins) / len(closed) * 100) if closed else 0
    cf_gaps = []
    for t in closed:
        if t.get("cf_max_favorable") is not None and t.get("entry_price") and t.get("exit_price"):
            if t["side"] == "BUY":
                actual_gain = t["exit_price"] - t["entry_price"]
                best_gain = t["cf_max_favorable"]
                if best_gain > 0:
                    cf_gaps.append(actual_gain / best_gain)
    exit_capture = (sum(cf_gaps) / len(cf_gaps) * 100) if cf_gaps else None
    data = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "since": args.since,
        "overview": {
            "total": len(trades),
            "closed": len(closed),
            "open": len(open_),
            "wins": len(wins),
            "losses": len(losses),
            "win_rate_pct": round(win_rate, 1),
            "total_pnl": round(total_pnl, 2),
            "avg_pnl_pct": round(avg_pnl_pct, 2),
            "avg_hold_days": round(avg_hold, 1),
            "exit_capture_pct": round(exit_capture, 1) if exit_capture is not None else None,
        },
        "by_strategy": compute_stats(trades, "strategy"),
        "by_signal_source": compute_stats(trades, "signal_source"),
        "exit_reasons": exit_reason_breakdown(trades),
        "gemini": fetch_gemini_cost(args.since),
        "events": fetch_event_counts(args.since),
        "capital": fetch_capital_state(trades),
    }
    if args.json:
        print(json.dumps(data, indent=2, default=str))
    else:
        print_human(data)

if __name__ == "__main__":
    main()
