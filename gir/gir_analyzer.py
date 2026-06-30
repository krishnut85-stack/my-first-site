#!/usr/bin/env python3
"""GIR Analyzer — read-only diagnostics."""
import json, os, sys
from collections import defaultdict, Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

DATA_DIR = Path("/home/globalbot/data")
SCOUT_DIR = Path("/home/globalbot")
IST = timezone(timedelta(hours=5, minutes=30))

def load_json(path, default=None):
    try:
        if not Path(path).exists():
            return default if default is not None else {}
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        print(f"[WARN] failed to load {path}: {e}", file=sys.stderr)
        return default if default is not None else {}

def parse_iso(s):
    if not s: return None
    try: return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        try: return datetime.strptime(s[:19], "%Y-%m-%dT%H:%M:%S")
        except Exception: return None

def days_held(entry, exit_iso):
    e = parse_iso(entry); x = parse_iso(exit_iso)
    if not e or not x: return None
    if e.tzinfo and not x.tzinfo: x = x.replace(tzinfo=e.tzinfo)
    if x.tzinfo and not e.tzinfo: e = e.replace(tzinfo=x.tzinfo)
    return (x - e).total_seconds() / 86400

def fmt_pct(num, den):
    if den == 0: return "  -- "
    return f"{100*num/den:5.1f}%"

def fmt_inr(x):
    if x is None: return "--"
    s = "+" if x >= 0 else "-"
    return f"Rs.{s}{abs(x):,.0f}"

def build_conviction_index(cache_paths):
    idx = defaultdict(list)
    for p in cache_paths:
        cache = load_json(p, {})
        if not isinstance(cache, dict): continue
        for _key, entry in cache.items():
            if not isinstance(entry, dict): continue
            ts = entry.get("ts", 0)
            for cand in entry.get("candidates", []):
                if not isinstance(cand, dict): continue
                sym = (cand.get("symbol") or "").strip().upper()
                if not sym: continue
                direction = (cand.get("direction") or "").upper()
                conv = int(cand.get("score") or cand.get("conviction") or 0)
                source = cand.get("source", "")
                idx[(sym, direction)].append((ts, conv, source))
    for k in idx:
        idx[k].sort(key=lambda x: x[0])
    return idx

def lookup_conviction_for_trade(idx, symbol, direction, entry_iso):
    e = parse_iso(entry_iso)
    if not e: return None
    e_ts = e.timestamp()
    for d_try in [direction, ""]:
        keys = [(symbol, d_try)] if d_try else [(symbol, x) for x in ("BULLISH", "BEARISH", "")]
        for k in keys:
            if k not in idx: continue
            best = None
            for ts, conv, source in idx[k]:
                if ts <= e_ts + 86400:
                    best = (ts, conv, source)
            if best: return best
    return None

def analyze(label, trades_path, scout_paths):
    print(f"\n{'='*70}\n  {label}\n{'='*70}")
    data = load_json(trades_path, {"trades": []})
    trades = data.get("trades", []) if isinstance(data, dict) else []
    if not trades:
        print(f"  [skip] no trades in {trades_path}")
        return
    print(f"  trades file: {trades_path}")
    print(f"  total trades: {len(trades)}")
    idx = build_conviction_index(scout_paths)
    print(f"  scout cache (sym,dir) keys indexed: {len(idx)}")

    wins, losses, breakevens = [], [], []
    total_pnl = 0.0
    by_reason = Counter()
    by_source = defaultdict(lambda: {"count": 0, "pnl": 0.0, "wins": 0})
    by_holding = defaultdict(lambda: {"count": 0, "pnl": 0.0, "wins": 0})

    for t in trades:
        pnl = float(t.get("pnl") or 0)
        total_pnl += pnl
        by_reason[t.get("reason", "UNKNOWN")] += 1
        source = t.get("source", "UNKNOWN")
        by_source[source]["count"] += 1
        by_source[source]["pnl"] += pnl
        if pnl > 0: by_source[source]["wins"] += 1
        held = days_held(t.get("entry_time"), t.get("exit_time"))
        if held is not None:
            band = ("<1d" if held < 1 else "1-3d" if held < 3 else
                    "3-7d" if held < 7 else "7-15d" if held < 15 else
                    "15-30d" if held < 30 else ">30d")
            by_holding[band]["count"] += 1
            by_holding[band]["pnl"] += pnl
            if pnl > 0: by_holding[band]["wins"] += 1
        if pnl > 0: wins.append(t)
        elif pnl < 0: losses.append(t)
        else: breakevens.append(t)

    print(f"\n  Net P&L:        {fmt_inr(total_pnl)}")
    print(f"  Wins:           {len(wins)} ({fmt_pct(len(wins), len(trades))})")
    print(f"  Losses:         {len(losses)} ({fmt_pct(len(losses), len(trades))})")
    print(f"  Breakeven/exit: {len(breakevens)}")
    if wins and losses:
        avg_win = sum(float(t.get("pnl", 0)) for t in wins) / len(wins)
        avg_loss = sum(float(t.get("pnl", 0)) for t in losses) / len(losses)
        rr = abs(avg_win / avg_loss) if avg_loss else 0
        print(f"  Avg win:        {fmt_inr(avg_win)}")
        print(f"  Avg loss:       {fmt_inr(avg_loss)}")
        print(f"  R:R ratio:      {rr:.2f}")
        print(f"  Expectancy/tr:  {fmt_inr(total_pnl / len(trades))}")

    print("\n  -- Win rate by NewsBrain conviction band --")
    bands = {"55-59": [55, 60], "60-69": [60, 70], "70-79": [70, 80],
             "80-89": [80, 90], "90-100": [90, 101], "no-validation": [None, None]}
    band_stats = {b: {"trades": [], "pnl": 0.0, "wins": 0} for b in bands}
    for t in trades:
        sym = (t.get("symbol") or "").strip().upper()
        ts_sym = (t.get("tradingsymbol") or "").upper()
        d = "BULLISH" if ts_sym.endswith("CE") else "BEARISH" if ts_sym.endswith("PE") else "BULLISH"
        match = lookup_conviction_for_trade(idx, sym, d, t.get("entry_time"))
        pnl = float(t.get("pnl") or 0)
        if match is None:
            band_stats["no-validation"]["trades"].append(t)
            band_stats["no-validation"]["pnl"] += pnl
            if pnl > 0: band_stats["no-validation"]["wins"] += 1
            continue
        _, conv, _ = match
        for bname, (lo, hi) in bands.items():
            if lo is None: continue
            if lo <= conv < hi:
                band_stats[bname]["trades"].append(t)
                band_stats[bname]["pnl"] += pnl
                if pnl > 0: band_stats[bname]["wins"] += 1
                break
    print(f"  {'band':<14} {'trades':>7} {'wins':>5} {'win%':>6} {'P&L':>12}")
    for bname, st in band_stats.items():
        n = len(st["trades"])
        if n == 0: continue
        print(f"  {bname:<14} {n:>7} {st['wins']:>5} {fmt_pct(st['wins'], n):>6} {fmt_inr(st['pnl']):>12}")

    print("\n  -- Performance by entry source --")
    print(f"  {'source':<25} {'trades':>7} {'wins':>5} {'win%':>6} {'P&L':>12}")
    for src, st in sorted(by_source.items(), key=lambda x: -x[1]["pnl"]):
        n = st["count"]
        print(f"  {src[:24]:<25} {n:>7} {st['wins']:>5} {fmt_pct(st['wins'], n):>6} {fmt_inr(st['pnl']):>12}")

    print("\n  -- Performance by holding duration --")
    print(f"  {'band':<10} {'trades':>7} {'wins':>5} {'win%':>6} {'P&L':>12}")
    for b in ["<1d", "1-3d", "3-7d", "7-15d", "15-30d", ">30d"]:
        st = by_holding.get(b)
        if not st or st["count"] == 0: continue
        n = st["count"]
        print(f"  {b:<10} {n:>7} {st['wins']:>5} {fmt_pct(st['wins'], n):>6} {fmt_inr(st['pnl']):>12}")

    print("\n  -- Top exit reasons --")
    for reason, n in by_reason.most_common(10):
        print(f"  {reason[:40]:<40} {n:>4}")

def open_position_health():
    print(f"\n{'='*70}\n  CURRENT OPEN POSITION HEALTH\n{'='*70}")
    eq_pos = load_json(DATA_DIR / "equity_positions.json", {}).get("positions", {})
    fno_pos = load_json(DATA_DIR / "fno_positions.json", {}).get("positions", {})
    now = datetime.now(IST)
    print(f"  Equity open: {len(eq_pos)} positions")
    print(f"  F&O open:    {len(fno_pos)} positions")
    if eq_pos:
        print(f"\n  -- Equity positions --")
        print(f"  {'symbol':<14} {'qty':>5} {'entry':>9} {'days':>5} {'source':<20}")
        for sym, p in eq_pos.items():
            e = parse_iso(p.get("entry_time"))
            try:
                if e and e.tzinfo: days = (now - e).days
                elif e: days = (now.replace(tzinfo=None) - e).days
                else: days = 0
            except Exception: days = 0
            stale = " DEAD" if days >= 15 else ""
            print(f"  {sym[:13]:<14} {p.get('qty',0):>5} Rs.{p.get('entry_price',0):>6.2f} {days:>5}d {p.get('source','?'):<20}{stale}")
    if fno_pos:
        print(f"\n  -- F&O positions --")
        print(f"  {'symbol':<26} {'qty':>5} {'entry':>9} {'sl':>9} {'days':>5}")
        for ts, p in fno_pos.items():
            e = parse_iso(p.get("entry_time"))
            try:
                if e and e.tzinfo: days = (now - e).days
                elif e: days = (now.replace(tzinfo=None) - e).days
                else: days = 0
            except Exception: days = 0
            print(f"  {ts[:25]:<26} {p.get('qty',0):>5} Rs.{p.get('entry_price',0):>6.2f} Rs.{p.get('sl_price',0):>6.2f} {days:>5}d")

def newsbrain_cost_view():
    print(f"\n{'='*70}\n  NEWSBRAIN COST VIEW\n{'='*70}")
    for label, path in [("EQUITY", SCOUT_DIR / "news_brain_scout_cache_EQUITY.json"),
                        ("FNO",    SCOUT_DIR / "news_brain_scout_cache_FNO.json")]:
        cache = load_json(path, {})
        if not isinstance(cache, dict) or not cache:
            print(f"  {label}: cache empty or missing ({path})")
            continue
        total = len(cache)
        validated = sum(1 for v in cache.values() if isinstance(v, dict) and v.get("candidates"))
        rejected = total - validated
        cands = sum(len(v.get("candidates", [])) for v in cache.values() if isinstance(v, dict))
        est_inr = total * 0.07
        print(f"  {label}: entries={total}  validated={validated} ({fmt_pct(validated,total)})  rejected={rejected}  candidates_emitted={cands}  est_cost~={fmt_inr(est_inr)}")

def main():
    print("GIR Analyzer - read-only diagnostics")
    print(f"Run at: {datetime.now(IST).isoformat()}")
    analyze("EQUITY", DATA_DIR / "equity_trades.json",
            [SCOUT_DIR / "news_brain_scout_cache_EQUITY.json"])
    analyze("F&O", DATA_DIR / "fno_trades.json",
            [SCOUT_DIR / "news_brain_scout_cache_FNO.json"])
    open_position_health()
    newsbrain_cost_view()
    print(f"\n{'='*70}\n  Done.\n{'='*70}\n")

if __name__ == "__main__":
    main()
