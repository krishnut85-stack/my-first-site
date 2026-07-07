"""LAB PORTFOLIO — the rupee answer: what does ₹10 lakh actually become?

Every LAB number so far is per-trade ("+1.92%/trade"). This module answers the
only question that matters to a human: run the VALIDATED strategies as a real
portfolio over the full history — daily marks, position sizing, cash limits,
costs both sides — and print what the money becomes, next to the honest
benchmark (buy-and-hold), with CAGR, worst drawdown and year-by-year returns.

Simulated books (the two triple-checked winners, same rules as validated):

  HI52   — buy the fresh cross into 2% of the 52-week high
  CRASH  — buy a 5-day drop <= -8% while still above the 50-DMA
  BOTH exit identically: 15% trailing stop off the peak close, or 120 trading
  days. Sizing: 2% of CURRENT equity per position, cash-limited, no count cap.

  50/50  — half the capital in each book (they fire in opposite regimes: one
           buys strength at highs, one buys fear after crashes).

Benchmark: NIFTY buy-and-hold if a nifty_daily.csv is given (--nifty), else an
equal-weight buy-and-hold of the same universe.

HONESTY NOTES (read before believing any number):
  • The universe is TODAY's top-1500 list -> survivorship bias: stocks that
    died/delisted aren't in the file, which flatters every strategy AND the
    equal-weight benchmark alike. Treat relative comparison as fairer than
    absolute levels.
  • Fills are at daily closes; no slippage beyond the 0.10%/side cost.
  • Past CAGR is a measurement, not a promise — the paper books' forward
    record is the number that ultimately counts.

    python3 -m garuda.lab_portfolio --csv strength_history.csv
    python3 -m garuda.lab_portfolio --csv strength_history.csv --nifty nifty_daily.csv
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .setups import sma

CAPITAL = 1_000_000.0
ALLOC = 0.02
TRAIL = 0.15
MAX_HOLD = 120


# --------------------------------------------------------------------------
# Signals (same rules the LABs validated)
# --------------------------------------------------------------------------

def signals_hi52(dates, closes):
    """[(date, strength)] — fresh cross into 2% of the 252-day high."""
    out = []
    n = len(closes)
    for i in range(252, n):
        hi = max(closes[i - 251:i + 1])
        hi_prev = max(closes[i - 252:i])
        if hi <= 0 or hi_prev <= 0 or closes[i] <= 0:
            continue
        near = closes[i] >= 0.98 * hi
        was = closes[i - 1] >= 0.98 * hi_prev
        if near and not was:
            mom = closes[i] / closes[i - 63] - 1.0 if closes[i - 63] > 0 else 0.0
            out.append((dates[i], mom))
    return out


def signals_crash(dates, closes):
    """[(date, strength)] — 5-day return <= -8% while above the 50-DMA."""
    out = []
    s50 = sma(closes, 50)
    n = len(closes)
    for i in range(50, n):
        if closes[i - 5] <= 0 or closes[i] <= 0 or s50[i] is None:
            continue
        wk = closes[i] / closes[i - 5] - 1.0
        if wk <= -0.08 and closes[i] > s50[i]:
            out.append((dates[i], -wk))          # deeper crash = stronger signal
    return out


# --------------------------------------------------------------------------
# The day-by-day portfolio engine
# --------------------------------------------------------------------------

def simulate(dated_series, signal_fns, capital=CAPITAL, cost=LAB_COST_PER_SIDE,
             alloc=ALLOC, trail=TRAIL, max_hold=MAX_HOLD):
    """Run one portfolio over the shared calendar. signal_fns: list of signal
    generators whose entries share this portfolio's cash (each sized at `alloc`
    of current equity). Returns {curve: [(date, equity)], trades: int, ...}."""
    px = {}                                   # sym -> {date: close}
    sig_by_date = {}                          # date -> [(strength, sym)]
    for sym, dv in dated_series.items():
        if len(dv) < 260:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        px[sym] = dict(dv)
        for fn in signal_fns:
            for d, strength in fn(dates, closes):
                sig_by_date.setdefault(d, []).append((strength, sym))
    calendar = sorted({d for p in px.values() for d in p})
    cash = capital
    held = {}                                 # sym -> {qty, peak, bars, last}
    curve, trades, wins = [], 0, 0
    last_price = {}
    for d in calendar:
        # 1. mark + exits
        sold_today = set()
        for sym in list(held):
            p = px[sym].get(d)
            if p is None or p <= 0:
                continue
            h = held[sym]
            last_price[sym] = p
            h["bars"] += 1
            h["peak"] = max(h["peak"], p)
            if p <= h["peak"] * (1 - trail) or h["bars"] >= max_hold:
                cash += h["qty"] * p * (1 - cost)
                trades += 1
                if p > h["entry"]:
                    wins += 1
                sold_today.add(sym)
                del held[sym]
        # 2. equity mark (positions at last known close)
        equity = cash + sum(h["qty"] * last_price.get(s, h["entry"])
                            for s, h in held.items())
        # 3. entries, strongest first, cash-limited
        for strength, sym in sorted(sig_by_date.get(d, []), reverse=True):
            if sym in held or sym in sold_today:
                continue
            p = px[sym].get(d)
            if not p or p <= 0:
                continue
            budget = min(alloc * equity, cash)
            qty = int(budget // (p * (1 + cost)))
            if qty <= 0:
                continue
            cash -= qty * p * (1 + cost)
            held[sym] = {"qty": qty, "peak": p, "bars": 0, "entry": p}
            last_price[sym] = p
        curve.append((d, round(cash + sum(h["qty"] * last_price.get(s, h["entry"])
                                          for s, h in held.items()), 2)))
    return {"curve": curve, "trades": trades,
            "win": round(wins / trades * 100, 1) if trades else None,
            "final": curve[-1][1] if curve else capital}


def buy_and_hold(dated_series, capital=CAPITAL, cost=LAB_COST_PER_SIDE):
    """Equal-weight buy-and-hold of every symbol alive at the calendar start."""
    calendar = sorted({d for dv in dated_series.values() for d, _ in dv})
    start_win = set(calendar[:5])
    basket = {}
    for sym, dv in dated_series.items():
        first = next(((d, c) for d, c in dv if d in start_win and c > 0), None)
        if first:
            basket[sym] = (dict(dv), first[1])
    if not basket:
        return {"curve": [], "final": capital}
    per = capital / len(basket) * (1 - cost)
    curve, last = [], {}
    for d in calendar:
        total = 0.0
        for sym, (pmap, first_px) in basket.items():
            p = pmap.get(d)
            if p and p > 0:
                last[sym] = p
            total += per / first_px * last.get(sym, first_px)
        curve.append((d, round(total, 2)))
    return {"curve": curve, "final": curve[-1][1]}


def nifty_hold(nifty_series, capital=CAPITAL, cost=LAB_COST_PER_SIDE):
    dv = [x for x in nifty_series if x[1] > 0]
    if not dv:
        return None
    qty = capital * (1 - cost) / dv[0][1]
    return {"curve": [(d, round(qty * c, 2)) for d, c in dv],
            "final": round(qty * dv[-1][1], 2)}


# --------------------------------------------------------------------------
# Metrics + report
# --------------------------------------------------------------------------

def metrics(curve, capital=CAPITAL):
    if not curve:
        return {}
    final = curve[-1][1]
    days = len(curve)
    years = max(days / 250.0, 1e-9)
    cagr = (final / capital) ** (1 / years) - 1 if final > 0 else -1.0
    peak, dd = curve[0][1], 0.0
    for _, v in curve:
        peak = max(peak, v)
        dd = max(dd, 1 - v / peak)
    yearly = {}
    for d, v in curve:
        yearly.setdefault(d[:4], []).append(v)
    yr = {y: round((vs[-1] / vs[0] - 1) * 100, 1) for y, vs in yearly.items()}
    return {"final": round(final, 0), "total_pct": round((final / capital - 1) * 100, 1),
            "cagr_pct": round(cagr * 100, 1), "max_dd_pct": round(dd * 100, 1),
            "years": round(years, 1), "yearly": yr}


def format_report(rows, capital=CAPITAL):
    w = 96
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             f"  Garuda · LAB PORTFOLIO   (the rupee answer — {money(capital)} run "
             f"through the validated strategies)",
             "=" * w,
             f"  {'PORTFOLIO':<26}{'FINAL':>14}{'TOTAL':>9}{'CAGR/yr':>9}"
             f"{'worst DD':>10}{'trades':>8}{'win%':>6}",
             "-" * w]
    for name, sim, m in rows:
        lines.append(f"  {name:<26}{money(m['final']):>14}{m['total_pct']:>+8.1f}%"
                     f"{m['cagr_pct']:>+8.1f}%{m['max_dd_pct']:>9.1f}%"
                     f"{(sim.get('trades') or '—'):>8}"
                     f"{(str(sim['win']) if sim.get('win') is not None else '—'):>6}")
    lines.append("-" * w)
    years = sorted({y for _, _, m in rows for y in m["yearly"]})
    lines.append("  YEAR BY YEAR (%):" + "".join(f"{y:>12}" for y in years))
    for name, _sim, m in rows:
        lines.append(f"  {name:<18}" + "".join(
            f"{(('%+.1f' % m['yearly'][y]) if y in m['yearly'] else '—'):>12}"
            for y in years))
    lines += ["-" * w,
              "  Universe = TODAY'S top-1500 list -> survivorship bias flatters every row",
              "  (benchmark included) — trust the COMPARISON more than the absolute levels.",
              "  Past CAGR is a measurement, not a promise. The paper books' forward record decides.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB PORTFOLIO (rupee simulation)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="deep-history long CSV (symbol,date,close)")
    ap.add_argument("--nifty", default="nifty_daily.csv",
                    help="optional Nifty daily CSV for the index benchmark")
    ap.add_argument("--capital", type=float, default=CAPITAL)
    ap.add_argument("--exits", default=f"{TRAIL}/{MAX_HOLD}",
                    help="comma-separated trail/hold exits to race, e.g. "
                         "'0.15/120,0.20/120,0.25/180' (default: the books' exit)")
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    exits = []
    for spec in a.exits.split(","):
        t, h = spec.strip().split("/")
        exits.append((float(t), int(h)))
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    print(f"[portfolio] {len(dated)} symbols · exits {a.exits} · simulating "
          f"HI52, CRASH, 50/50, benchmark ...")
    rows = []
    for trail, hold in exits:
        tag = f" · {trail*100:.0f}%/{hold}d" if len(exits) > 1 else ""
        hi = simulate(dated, [signals_hi52], capital=a.capital, trail=trail,
                      max_hold=hold)
        rows.append((f"HI52{tag}", hi, metrics(hi["curve"], a.capital)))
        cr = simulate(dated, [signals_crash], capital=a.capital, trail=trail,
                      max_hold=hold)
        rows.append((f"CRASH{tag}", cr, metrics(cr["curve"], a.capital)))
        both = simulate(dated, [signals_hi52, signals_crash], capital=a.capital,
                        trail=trail, max_hold=hold)
        rows.append((f"50/50{tag}", both, metrics(both["curve"], a.capital)))
    npath = Path(a.nifty)
    if npath.exists():
        nser = sorted(next(iter(_load_long(npath).values())).items())
        nf = nifty_hold(nser, a.capital)
        rows.append(("NIFTY buy & hold", nf, metrics(nf["curve"], a.capital)))
    else:
        bh = buy_and_hold(dated, a.capital)
        rows.append(("Equal-wt buy & hold", bh, metrics(bh["curve"], a.capital)))
        print(f"[portfolio] {a.nifty} not found — using equal-weight universe "
              f"buy-and-hold as the benchmark")
    print(format_report(rows, a.capital))


if __name__ == "__main__":
    main()
