#!/usr/bin/env python3
"""
elon_analyzer.py  -  Performance analyzer for the ELON CODE paper bot
====================================================================
Reads the paper trade log and tells you, in plain numbers, what is working and
what is NOT - so you can improve the bot instead of guessing.

It answers:
  - Are we making or losing money? (net P&L, profit factor, expectancy)
  - WHY are trades closing? (target vs stop vs 3:15 square-off)
  - Which days / stocks help or hurt the most?
  - WHAT to change next (auto-generated, rule-based suggestions)

Usage:
  python3 elon_analyzer.py                # all ELON_CODE paper trades
  python3 elon_analyzer.py --days 7       # last 7 calendar days
  python3 elon_analyzer.py --csv out.csv  # also dump every trade to CSV
  python3 elon_analyzer.py --strategy FNO_PAPER_STUDY   # analyze a different bot

Pure standard library. Safe to run while the bot is trading (read-only).
"""

import os
import sys
import csv
import sqlite3
import argparse
from datetime import datetime, timedelta

TRADES_DB = os.environ.get("EQ_TRADES_DB", "/home/globalbot/paper/trades.db")
DEFAULT_STRATEGY = "ELON_CODE"
DEFAULT_DAILY_LOSS_CAP = float(os.environ.get("EQ_MAX_DAILY_LOSS", "20000"))


def _fmt(n, dp=0):
    try:
        return f"{n:,.{dp}f}"
    except Exception:
        return str(n)


def _rule(title=""):
    line = "-" * 70
    if title:
        print(f"\n{line}\n{title}\n{line}")
    else:
        print(line)


def load_trades(strategy, days):
    if not os.path.exists(TRADES_DB):
        print(f"ERROR: trades DB not found at {TRADES_DB}")
        sys.exit(1)
    conn = sqlite3.connect(TRADES_DB, timeout=10)
    conn.row_factory = sqlite3.Row
    q = "SELECT * FROM paper_trades WHERE strategy = ?"
    args = [strategy]
    if days:
        cutoff = (datetime.utcnow() - timedelta(days=days)).strftime("%Y-%m-%d")
        q += " AND substr(entry_ts,1,10) >= ?"
        args.append(cutoff)
    q += " ORDER BY entry_ts ASC"
    rows = [dict(r) for r in conn.execute(q, args).fetchall()]
    conn.close()
    return rows


def analyze(rows, strategy, daily_cap):
    print("=" * 70)
    print(f"  ELON CODE ANALYZER  -  strategy={strategy}")
    print(f"  source: {TRADES_DB}")
    print(f"  generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    if not rows:
        print("\nNo trades found yet. Once the bot records trades, re-run this.")
        return

    closed = [r for r in rows if r.get("status") == "CLOSED"]
    open_t = [r for r in rows if r.get("status") == "OPEN"]

    print(f"\nTotal trades: {len(rows)}   (closed: {len(closed)}, still open: {len(open_t)})")

    if not closed:
        print("No CLOSED trades yet - nothing to score. Open positions:")
        for r in open_t:
            print(f"  OPEN  {r['symbol']:<14} qty {r['qty']}  entry {r['entry_price']}")
        return

    pnls = [float(r.get("pnl") or 0) for r in closed]
    wins = [p for p in pnls if p > 0]
    losses = [p for p in pnls if p < 0]
    net = sum(pnls)
    gross_win = sum(wins)
    gross_loss = sum(losses)          # negative
    win_rate = len(wins) / len(closed) * 100
    avg_win = (gross_win / len(wins)) if wins else 0
    avg_loss = (gross_loss / len(losses)) if losses else 0
    profit_factor = (gross_win / abs(gross_loss)) if gross_loss else float("inf")
    expectancy = net / len(closed)

    # ---- headline scorecard ----
    _rule("SCORECARD")
    print(f"  Net P&L            : Rs {_fmt(net)}")
    print(f"  Closed trades      : {len(closed)}")
    print(f"  Win rate           : {win_rate:.1f}%   ({len(wins)} win / {len(losses)} loss)")
    print(f"  Avg win            : Rs {_fmt(avg_win)}")
    print(f"  Avg loss           : Rs {_fmt(avg_loss)}")
    rr = (avg_win / abs(avg_loss)) if avg_loss else float("inf")
    print(f"  Reward:risk (avg)  : {rr:.2f} : 1")
    pf_str = "inf" if profit_factor == float("inf") else f"{profit_factor:.2f}"
    print(f"  Profit factor      : {pf_str}   (gross win / gross loss; >1 = profitable)")
    print(f"  Expectancy/trade   : Rs {_fmt(expectancy, 1)}")
    if wins:
        print(f"  Biggest win        : Rs {_fmt(max(wins))}")
    if losses:
        print(f"  Biggest loss       : Rs {_fmt(min(losses))}")

    # ---- why trades closed (the key diagnostic) ----
    _rule("WHY TRADES CLOSED (exit reason)")
    by_reason = {}
    for r in closed:
        reason = r.get("exit_reason") or "UNKNOWN"
        d = by_reason.setdefault(reason, {"n": 0, "pnl": 0.0})
        d["n"] += 1
        d["pnl"] += float(r.get("pnl") or 0)
    print(f"  {'reason':<20}{'count':>7}{'share':>9}{'net P&L':>14}")
    for reason, d in sorted(by_reason.items(), key=lambda x: -x[1]["n"]):
        share = d["n"] / len(closed) * 100
        print(f"  {reason:<20}{d['n']:>7}{share:>8.0f}%{('Rs ' + _fmt(d['pnl'])):>14}")

    # ---- by day (and daily-cap check) ----
    _rule("BY DAY")
    by_day = {}
    for r in closed:
        day = (r.get("entry_ts") or "")[:10]
        d = by_day.setdefault(day, {"n": 0, "pnl": 0.0})
        d["n"] += 1
        d["pnl"] += float(r.get("pnl") or 0)
    print(f"  {'date':<12}{'trades':>8}{'net P&L':>14}   note")
    cap_hits = 0
    for day in sorted(by_day):
        d = by_day[day]
        note = ""
        if d["pnl"] <= -abs(daily_cap):
            note = f"<= hit daily loss cap (Rs {_fmt(daily_cap)})"
            cap_hits += 1
        print(f"  {day:<12}{d['n']:>8}{('Rs ' + _fmt(d['pnl'])):>14}   {note}")
    green = sum(1 for d in by_day.values() if d["pnl"] > 0)
    print(f"\n  Green days: {green}/{len(by_day)}   Days hitting loss cap: {cap_hits}")

    # ---- worst / best symbols ----
    _rule("BY SYMBOL (top movers)")
    by_sym = {}
    for r in closed:
        s = r.get("symbol")
        d = by_sym.setdefault(s, {"n": 0, "pnl": 0.0})
        d["n"] += 1
        d["pnl"] += float(r.get("pnl") or 0)
    ranked = sorted(by_sym.items(), key=lambda x: x[1]["pnl"])
    print("  Worst 5:")
    for s, d in ranked[:5]:
        print(f"    {s:<14}{d['n']:>3} trades   Rs {_fmt(d['pnl'])}")
    print("  Best 5:")
    for s, d in reversed(ranked[-5:]):
        print(f"    {s:<14}{d['n']:>3} trades   Rs {_fmt(d['pnl'])}")

    # ---- auto suggestions (rule-based) ----
    _rule("WHAT TO IMPROVE (auto-diagnosis)")
    tips = []
    stop_share = by_reason.get("STOP", {}).get("n", 0) / len(closed) * 100
    sq_share = by_reason.get("SQUARE_OFF_1515", {}).get("n", 0) / len(closed) * 100
    tgt_share = by_reason.get("TARGET", {}).get("n", 0) / len(closed) * 100

    if profit_factor != float("inf") and profit_factor < 1:
        tips.append("Losing overall (profit factor < 1). The edge is not working as-is - "
                    "tighten the entry filters before risking more.")
    if stop_share >= 45:
        tips.append(f"Stops dominate ({stop_share:.0f}% of exits). Entries may be too early / "
                    "catching knives. Try a bigger confirmation (EQ_CONFIRM_PCT, e.g. 0.25) "
                    "or stricter dip filter (EQ_STRETCH_MIN_PCT higher).")
    if sq_share >= 40:
        tips.append(f"Many 3:15 square-offs ({sq_share:.0f}%): trades neither hit target nor stop. "
                    "Target may be too far - test a smaller EQ_TARGET_PCT (e.g. 1.0).")
    if tgt_share >= 55 and win_rate >= 55 and rr < 1:
        tips.append("High hit-rate but small reward vs risk. You could widen EQ_TARGET_PCT "
                    "to let winners run further.")
    if avg_loss and abs(avg_loss) > avg_win and avg_win > 0:
        tips.append(f"Avg loss (Rs {_fmt(abs(avg_loss))}) bigger than avg win (Rs {_fmt(avg_win)}). "
                    "Stops may be too wide or targets too tight - rebalance EQ_STOP_PCT / EQ_TARGET_PCT.")
    if cap_hits > 0:
        tips.append(f"Hit the daily loss cap on {cap_hits} day(s). Good - the brake worked. "
                    "Review those days' symbols above for a common cause (e.g. a market-wide selloff).")
    if win_rate >= 55 and profit_factor != float("inf") and profit_factor >= 1.3:
        tips.append("Healthy stats. Let it gather more trades before changing anything - "
                    "small samples lie.")
    if len(closed) < 20:
        tips.append(f"Only {len(closed)} closed trades - too few to trust. Let it run longer "
                    "before drawing conclusions.")
    if not tips:
        tips.append("Nothing alarming. Keep collecting trades and re-check.")
    for i, t in enumerate(tips, 1):
        print(f"  {i}. {t}")

    if open_t:
        _rule("STILL OPEN")
        for r in open_t:
            print(f"  {r['symbol']:<14} qty {r['qty']}  entry {r['entry_price']}  since {(r.get('entry_ts') or '')[:16]}")
    print()


def dump_csv(rows, path):
    if not rows:
        print("No rows to export.")
        return
    cols = ["trade_id", "symbol", "side", "qty", "entry_ts", "entry_price",
            "exit_ts", "exit_price", "exit_reason", "pnl", "pnl_pct", "status"]
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            w.writerow([r.get(c, "") for c in cols])
    print(f"Wrote {len(rows)} trades to {path}")


def main():
    ap = argparse.ArgumentParser(description="ELON CODE paper-trade analyzer")
    ap.add_argument("--strategy", default=DEFAULT_STRATEGY, help="strategy tag to analyze")
    ap.add_argument("--days", type=int, default=0, help="only last N calendar days")
    ap.add_argument("--csv", default="", help="also export all trades to this CSV path")
    ap.add_argument("--cap", type=float, default=DEFAULT_DAILY_LOSS_CAP,
                    help="daily loss cap used for the by-day note")
    args = ap.parse_args()

    rows = load_trades(args.strategy, args.days)
    analyze(rows, args.strategy, args.cap)
    if args.csv:
        dump_csv(rows, args.csv)


if __name__ == "__main__":
    main()
