"""LAB DIP RACE — the smallcap tuning decided in rupees, not per-trade stats.

Per-trade averages can't price OPPORTUNITY COST: a 180-day hold that earns
+1.25%/trade might still lose the race if it jails capital while better dips
fly past. This racer settles it at the portfolio level — same capital, same
2% slots, same cash limits, day by day over the full history:

    QUICK    the current book  : RSI-2<10 uptrend dip · exit RSI-2>85 / 30d /
             20% hard stop
    PATIENT  the exam's winner : same entries · 25% trailing stop / 180d cap

For each it reports final rupees, CAGR, max drawdown — AND the numbers that
answer "what if a better stock runs while I'm holding": average holding days,
average open slots, and how many buy signals were SKIPPED for lack of cash.

    python3 -m garuda.lab_dip_race --csv strength_history.csv --list smallcap_list.csv

PAPER / research only.
"""

import argparse
import csv as _csv
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_portfolio import metrics
from .lab_tournament import judge_window_start, window_metrics
from .setups import rsi, sma

CONFIGS = {
    "QUICK (current book)": dict(exit_rsi=85.0, max_hold=30, hard_stop=0.20, trail=0.0),
    "PATIENT (exam winner)": dict(exit_rsi=None, max_hold=180, hard_stop=0.0, trail=0.25),
}


def race(dated_series, cfg, capital=1_000_000.0, cost=LAB_COST_PER_SIDE,
         alloc=0.02):
    """Day-loop dip portfolio under one exit config. Entries: RSI-2 < 10 above
    the 200-DMA, deepest RSI first, 2% slots, cash-limited."""
    px, sig, r2d = {}, {}, {}
    for sym, dv in dated_series.items():
        if len(dv) < 260:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        r2 = rsi(closes, 2)
        s200 = sma(closes, 200)
        px[sym] = dict(dv)
        r2d[sym] = dict(zip(dates, r2))
        for i in range(200, len(closes) - 1):
            if (r2[i] is not None and r2[i] < 10.0
                    and s200[i] is not None and closes[i] > s200[i]):
                sig.setdefault(dates[i], []).append((r2[i], sym))
    calendar = sorted({d for p in px.values() for d in p})
    cash, held, last = capital, {}, {}
    curve, trades, wins, skipped, hold_sum, slot_sum = [], 0, 0, 0, 0, 0
    for d in calendar:
        sold = set()
        for sym in list(held):
            p = px[sym].get(d)
            if p is None or p <= 0:
                continue
            h = held[sym]
            last[sym] = p
            h["bars"] += 1
            h["peak"] = max(h["peak"], p)
            r = r2d[sym].get(d)
            out = ((cfg["hard_stop"] and p <= h["entry"] * (1 - cfg["hard_stop"]))
                   or (cfg["trail"] and p <= h["peak"] * (1 - cfg["trail"]))
                   or (cfg["exit_rsi"] is not None and r is not None
                       and r > cfg["exit_rsi"])
                   or h["bars"] >= cfg["max_hold"])
            if out:
                cash += h["qty"] * p * (1 - cost)
                trades += 1
                wins += p > h["entry"]
                hold_sum += h["bars"]
                sold.add(sym)
                del held[sym]
        equity = cash + sum(h["qty"] * last.get(s, h["entry"])
                            for s, h in held.items())
        for _r, sym in sorted(sig.get(d, [])):          # deepest dip first
            if sym in held or sym in sold:
                continue
            p = px[sym].get(d)
            if not p or p <= 0:
                continue
            budget = min(alloc * equity, cash)
            qty = int(budget // (p * (1 + cost)))
            if qty <= 0:
                skipped += 1                             # opportunity lost: no cash
                continue
            cash -= qty * p * (1 + cost)
            held[sym] = {"qty": qty, "peak": p, "bars": 0, "entry": p}
            last[sym] = p
        slot_sum += len(held)
        curve.append((d, round(cash + sum(h["qty"] * last.get(s, h["entry"])
                                          for s, h in held.items()), 2)))
    n = len(calendar) or 1
    return {"curve": curve, "trades": trades,
            "win": round(wins / trades * 100, 1) if trades else None,
            "avg_hold": round(hold_sum / trades, 1) if trades else None,
            "avg_slots": round(slot_sum / n, 1), "skipped": skipped}


def format_race(rows, start, capital):
    w = 106
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · DIP RACE   (quick exit vs patient exit — decided in "
             "rupees, opportunity cost included)",
             f"  Same entries, same 2% slots, same cash. TEST window from {start}",
             "=" * w,
             f"  {'CONFIG':<24}{'full FINAL':>13}{'CAGR':>8}{'DD':>7}"
             f"{'TEST CAGR':>10}{'win%':>6}{'avg hold':>9}{'avg slots':>10}"
             f"{'skipped':>8}",
             "-" * w]
    for name, sim, fm, wm in rows:
        lines.append(
            f"  {name:<24}{money(fm['final']):>13}{fm['cagr_pct']:>+7.1f}%"
            f"{fm['max_dd_pct']:>6.1f}%"
            + (f"{wm['cagr_pct']:>+9.1f}%" if wm else f"{'—':>10}")
            + f"{(str(sim['win']) if sim['win'] is not None else '—'):>6}"
            + f"{(str(sim['avg_hold']) + 'd' if sim['avg_hold'] else '—'):>9}"
            + f"{sim['avg_slots']:>10}{sim['skipped']:>8}")
    lines += ["-" * w,
              "  'skipped' = buy signals missed because cash was tied up — the "
              "opportunity cost, as a number.",
              "  avg hold shows how long positions REALLY live (the trail exits "
              "laggards long before the 180d cap).",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda DIP RACE (portfolio-level)")
    ap.add_argument("--csv", default="strength_history.csv")
    ap.add_argument("--list", default="",
                    help="optional constituent CSV, e.g. smallcap_list.csv")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    ap.add_argument("--cost", type=float, default=LAB_COST_PER_SIDE)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    if a.list:
        lp = Path(a.list)
        if not lp.exists():
            sys.exit(f"{a.list} not found")
        with open(lp, newline="", encoding="utf-8") as f:
            keep = {(r.get("Symbol") or r.get("symbol") or "").strip()
                    for r in _csv.DictReader(f)}
        dated = {s: dv for s, dv in dated.items() if s in keep}
        print(f"[dip-race] universe restricted to {len(dated)} names")
    start = judge_window_start(dated)
    rows = []
    for name, cfg in CONFIGS.items():
        print(f"[dip-race] running {name} ...")
        sim = race(dated, cfg, capital=a.capital, cost=a.cost)
        rows.append((name, sim, metrics(sim["curve"], a.capital),
                     window_metrics(sim["curve"], start)))
    print(format_race(rows, start, a.capital))


if __name__ == "__main__":
    main()
