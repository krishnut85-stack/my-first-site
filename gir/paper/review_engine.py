#!/usr/bin/env python3
"""review_engine.py - Phase 7 Optimization Recommendation Engine
Reads paper trade history and emits concrete tuning recommendations.
Read-only on databases. Cannot place orders.

Usage:
  python3 review_engine.py                # default 10-day window
  python3 review_engine.py --days 30      # 30-day window
  python3 review_engine.py --json         # JSON output
"""
import sys, sqlite3, json, argparse, statistics
from collections import defaultdict
from datetime import datetime, timezone, timedelta

TRADES_DB = "/home/globalbot/paper/trades.db"
EVENTS_DB = "/home/globalbot/paper/events.db"

# Current tunable parameters (mirror config from gir.py / paper_exit_monitor.py)
CURRENT = {
    "EQ_INITIAL_SL_PCT": 0.06,
    "EQ_TRAIL_SL_PCT":   0.07,
    "EQ_MAX_HOLD_DAYS":  30,
    "FNO_SL_PCT":        0.25,
    "FNO_MAX_HOLD_DAYS": 7,
}

# Confidence thresholds
MIN_N_HIGH = 20
MIN_N_MED  = 8

def fetch_trades(days):
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    conn = sqlite3.connect(TRADES_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT * FROM paper_trades WHERE entry_ts >= ?", (cutoff,))
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows

def confidence(n):
    if n >= MIN_N_HIGH: return "HIGH"
    if n >= MIN_N_MED:  return "MEDIUM"
    if n >= 3:          return "LOW"
    return "INSUFFICIENT"

def pct(x, total):
    return round(100 * x / total, 1) if total else 0

def analyze_exit_quality(trades):
    """For each closed trade, compare actual exit vs cf_max_favorable.
    Returns dict of insights per exit_reason."""
    by_reason = defaultdict(list)
    for t in trades:
        if t["status"] != "CLOSED": continue
        if t["entry_price"] is None or t["exit_price"] is None: continue
        if t["cf_max_favorable"] is None: continue
        reason = t.get("exit_reason") or "UNKNOWN"
        if t["side"] == "BUY":
            actual_gain = t["exit_price"] - t["entry_price"]
            best_gain = t["cf_max_favorable"]
            actual_pct = (actual_gain / t["entry_price"]) * 100
            best_pct = (best_gain / t["entry_price"]) * 100
            left_on_table_pct = best_pct - actual_pct
            by_reason[reason].append({
                "trade_id": t["trade_id"],
                "actual_pct": actual_pct,
                "best_pct": best_pct,
                "left_on_table_pct": left_on_table_pct,
                "pnl": t.get("pnl") or 0,
            })
    summary = {}
    for reason, items in by_reason.items():
        if not items: continue
        avg_left = statistics.mean(i["left_on_table_pct"] for i in items)
        median_left = statistics.median(i["left_on_table_pct"] for i in items)
        pct_with_big_gap = pct(sum(1 for i in items if i["left_on_table_pct"] > 5), len(items))
        summary[reason] = {
            "n": len(items),
            "avg_left_on_table_pct": round(avg_left, 2),
            "median_left_on_table_pct": round(median_left, 2),
            "pct_trades_left_5pct_plus": pct_with_big_gap,
            "avg_pnl": round(statistics.mean(i["pnl"] for i in items), 2),
        }
    return summary

def analyze_signal_sources(trades):
    by_src = defaultdict(list)
    for t in trades:
        src = t.get("signal_source") or "unknown"
        by_src[src].append(t)
    out = {}
    for src, ts in by_src.items():
        closed = [t for t in ts if t["status"] == "CLOSED"]
        if not closed:
            out[src] = {"n_total": len(ts), "n_closed": 0, "status": "NO_DATA_YET"}
            continue
        wins = [t for t in closed if (t.get("pnl") or 0) > 0]
        losses = [t for t in closed if (t.get("pnl") or 0) <= 0]
        win_rate = pct(len(wins), len(closed))
        avg_pnl = statistics.mean(t.get("pnl") or 0 for t in closed)
        avg_win = statistics.mean(t.get("pnl") or 0 for t in wins) if wins else 0
        avg_loss = statistics.mean(t.get("pnl") or 0 for t in losses) if losses else 0
        out[src] = {
            "n_total": len(ts),
            "n_closed": len(closed),
            "n_wins": len(wins),
            "n_losses": len(losses),
            "win_rate_pct": win_rate,
            "avg_pnl": round(avg_pnl, 2),
            "avg_win": round(avg_win, 2),
            "avg_loss": round(avg_loss, 2),
            "total_pnl": round(sum(t.get("pnl") or 0 for t in closed), 2),
        }
    return out

def generate_recommendations(trades, exit_q, sig_perf, days):
    recs = []
    closed = [t for t in trades if t["status"] == "CLOSED"]
    n_closed = len(closed)
    if n_closed < 3:
        recs.append({
            "type": "DATA",
            "priority": "INFO",
            "title": "Insufficient data for recommendations",
            "evidence": f"Only {n_closed} closed trades in last {days} days. Need >= 8 for meaningful tuning.",
            "confidence": "INSUFFICIENT",
        })
        return recs

    # REC: Trail SL too loose?
    trail_reasons = [r for r in exit_q if "TRAIL_SL" in r]
    for r in trail_reasons:
        s = exit_q[r]
        if s["avg_left_on_table_pct"] > 5 and s["n"] >= MIN_N_MED:
            current = CURRENT["EQ_TRAIL_SL_PCT"]
            suggested = round(max(0.03, current - 0.02), 3)
            recs.append({
                "type": "PARAM",
                "priority": "HIGH",
                "title": f"EQ_TRAIL_SL_PCT: tighten {current} -> {suggested}",
                "evidence": (f"{r}: {s['pct_trades_left_5pct_plus']}% of trades had >5% more upside left. "
                             f"avg left on table: {s['avg_left_on_table_pct']}% (n={s['n']})"),
                "confidence": confidence(s["n"]),
            })

    # REC: Hard SL too tight?
    hard_reasons = [r for r in exit_q if "HARD_SL" in r]
    for r in hard_reasons:
        s = exit_q[r]
        # If hard SL exits frequently and avg left on table is positive, SL too tight
        if s["n"] >= MIN_N_MED and s["avg_left_on_table_pct"] > 8:
            current = CURRENT["EQ_INITIAL_SL_PCT"]
            suggested = round(min(0.10, current + 0.02), 3)
            recs.append({
                "type": "PARAM",
                "priority": "MEDIUM",
                "title": f"EQ_INITIAL_SL_PCT: widen {current} -> {suggested}",
                "evidence": (f"{r}: stopped out then recovered. "
                             f"avg upside left after exit: {s['avg_left_on_table_pct']}% (n={s['n']})"),
                "confidence": confidence(s["n"]),
            })

    # REC: Per signal source — kill losers
    for src, p in sig_perf.items():
        if p.get("n_closed", 0) >= MIN_N_MED:
            if p["win_rate_pct"] < 30 and p["total_pnl"] < 0:
                recs.append({
                    "type": "SOURCE",
                    "priority": "HIGH",
                    "title": f"Signal source '{src}': REDUCE or DISABLE",
                    "evidence": (f"Win rate {p['win_rate_pct']}%, total P&L Rs.{p['total_pnl']}, "
                                 f"avg win {p['avg_win']}, avg loss {p['avg_loss']} (n_closed={p['n_closed']})"),
                    "confidence": confidence(p["n_closed"]),
                })
            elif p["win_rate_pct"] >= 60 and p["total_pnl"] > 0:
                recs.append({
                    "type": "SOURCE",
                    "priority": "INFO",
                    "title": f"Signal source '{src}': STRONG performer",
                    "evidence": (f"Win rate {p['win_rate_pct']}%, total P&L Rs.{p['total_pnl']}, "
                                 f"consider INCREASE allocation (n_closed={p['n_closed']})"),
                    "confidence": confidence(p["n_closed"]),
                })

    # REC: Time-stop frequency check
    time_stop_count = sum(s["n"] for r, s in exit_q.items() if "TIME_STOP" in r)
    if time_stop_count >= MIN_N_MED:
        recs.append({
            "type": "OBSERVATION",
            "priority": "MEDIUM",
            "title": f"{time_stop_count} trades hit time-stop",
            "evidence": "Many trades ride the full hold period without resolution. "
                        "Consider stricter entry quality or shorter time-stop.",
            "confidence": confidence(time_stop_count),
        })

    if not recs:
        recs.append({
            "type": "OK",
            "priority": "INFO",
            "title": "No tuning recommendations at this time",
            "evidence": f"{n_closed} closed trades reviewed; no statistically significant edge or leak detected.",
            "confidence": "OK",
        })
    return recs

def print_human(data):
    print()
    print("=" * 76)
    print(f"  OPTIMIZATION REVIEW - {data['window_days']}-day window")
    print(f"  Generated: {data['generated_at']}")
    print("=" * 76)
    print()
    print(f"SAMPLE")
    print(f"  Total trades: {data['n_total']}    Closed: {data['n_closed']}    Open: {data['n_open']}")
    print()
    print(f"RECOMMENDATIONS ({len(data['recommendations'])})")
    print()
    for i, r in enumerate(data["recommendations"], 1):
        print(f"  [{i}] [{r['priority']}] {r['title']}")
        print(f"      Evidence:   {r['evidence']}")
        print(f"      Confidence: {r['confidence']}")
        print()
    print(f"EXIT REASON QUALITY")
    if data["exit_quality"]:
        print(f"  {'reason':<28} {'n':>4} {'avg_pnl':>9} {'avg_left%':>10} {'med_left%':>10}")
        for r, s in data["exit_quality"].items():
            print(f"  {r:<28} {s['n']:>4} {s['avg_pnl']:>9} {s['avg_left_on_table_pct']:>10} {s['median_left_on_table_pct']:>10}")
    else:
        print(f"  No exits with counterfactual data yet.")
    print()
    print(f"SIGNAL SOURCE PERFORMANCE")
    print(f"  {'source':<28} {'n_tot':>6} {'closed':>7} {'win%':>6} {'totPnL':>10} {'avgPnL':>8}")
    for src, p in data["signal_performance"].items():
        if p.get("status") == "NO_DATA_YET":
            print(f"  {src:<28} {p['n_total']:>6} {0:>7} {'-':>6} {'-':>10} {'-':>8}")
        else:
            print(f"  {src:<28} {p['n_total']:>6} {p['n_closed']:>7} {p['win_rate_pct']:>6} {p['total_pnl']:>10} {p['avg_pnl']:>8}")
    print()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=10)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    trades = fetch_trades(args.days)
    exit_q = analyze_exit_quality(trades)
    sig_perf = analyze_signal_sources(trades)
    recs = generate_recommendations(trades, exit_q, sig_perf, args.days)
    data = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "window_days": args.days,
        "n_total": len(trades),
        "n_closed": sum(1 for t in trades if t["status"] == "CLOSED"),
        "n_open":   sum(1 for t in trades if t["status"] == "OPEN"),
        "current_config": CURRENT,
        "recommendations": recs,
        "exit_quality": exit_q,
        "signal_performance": sig_perf,
    }
    if args.json:
        print(json.dumps(data, indent=2, default=str))
    else:
        print_human(data)

if __name__ == "__main__":
    main()
