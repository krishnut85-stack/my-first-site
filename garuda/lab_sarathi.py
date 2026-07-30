"""LAB SARATHI — does a market-regime gate improve the champion portfolio?

SARATHI (the charioteer) trades the two validated engines — the -8% crash
bounce (25% trail / 180d) and the 52-week-high cross (15% trail / 120d) — but
through a BREADTH gate computed from the universe itself each day:

    breadth = % of stocks above their own 200-DMA (min 100 stocks measurable)

    GREEN  breadth > 50   both engines fire, full size (2% of equity/name)
    YELLOW 35 <= b <= 50  only the crash engine, HALF size (mean reversion
                          survives chop; strength entries pause)
    RED    breadth < 35   no new buys — sit in cash; open positions keep
                          their normal exits

Thresholds 50/35 are the classic breadth levels, fixed A PRIORI — deliberately
NOT swept, so the gate can't be overfit. Days before enough stocks have a
200-DMA (the warmup) are treated as GREEN (no gate).

The race, in rupees over the full history, same capital, same costs:

    SARATHI (gated)   vs   UNGATED 50/50 (identical engines/exits, no gate)
                      vs   NIFTY buy & hold (if nifty_daily.csv present)

Ship rule (decided before running): SARATHI earns the 10th book ONLY if it
beats the ungated blend on drawdown AND worst year, with CAGR equal or better.
Otherwise it failed — and we say so.

    python3 -m garuda.lab_sarathi --csv strength_history.csv --nifty nifty_daily.csv

No lookahead: a day's breadth uses only closes up to that day, and gates only
that day's NEW entries. PAPER / research only.
"""

import argparse
import sys
from pathlib import Path

from .cross import _load_long
from .lab import LAB_COST_PER_SIDE
from .lab_portfolio import metrics, nifty_hold, signals_crash, signals_hi52

GREEN_MIN = 50.0          # breadth above this -> GREEN
YELLOW_MIN = 35.0         # breadth in [YELLOW_MIN, GREEN_MIN] -> YELLOW, below -> RED
MIN_MEASURED = 100        # need >=100 stocks with a 200-DMA to trust the reading

ENGINES = [
    # (key, signal fn, trailing stop, max hold) — the validated exits per engine
    ("crash", signals_crash, 0.25, 180),
    ("hi52", signals_hi52, 0.15, 120),
]


def breadth_series(dated_series):
    """{date: breadth% or None} — % of stocks above their own 200-DMA that day.
    None when fewer than MIN_MEASURED stocks have a 200-DMA yet (warmup)."""
    counts = {}
    for _sym, dv in dated_series.items():
        if len(dv) < 220:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        run = sum(closes[:200])
        for i in range(199, len(closes)):
            if i > 199:
                run += closes[i] - closes[i - 200]
            c = counts.setdefault(dates[i], [0, 0])
            c[1] += 1
            if closes[i] > run / 200.0:
                c[0] += 1
    return {d: (round(a / t * 100, 1) if t >= MIN_MEASURED else None)
            for d, (a, t) in counts.items()}


def regime_of(breadth):
    """'G' / 'Y' / 'R' — warmup (None) counts as GREEN (no gate)."""
    if breadth is None or breadth > GREEN_MIN:
        return "G"
    return "Y" if breadth >= YELLOW_MIN else "R"


def simulate_sarathi(dated_series, gate=True, capital=1_000_000.0,
                     cost=LAB_COST_PER_SIDE):
    """Day-by-day portfolio of the two engines, each with ITS OWN exit, with an
    optional breadth gate on new entries. Returns curve + stats + regime days."""
    px = {}
    sig_by_date = {}                       # date -> [(strength, sym, engine_idx)]
    for sym, dv in dated_series.items():
        if len(dv) < 260:
            continue
        dates = [d for d, _ in dv]
        closes = [v for _, v in dv]
        px[sym] = dict(dv)
        for ei, (_k, fn, _t, _h) in enumerate(ENGINES):
            for d, strength in fn(dates, closes):
                sig_by_date.setdefault(d, []).append((strength, sym, ei))
    breadth = breadth_series(dated_series) if gate else {}
    calendar = sorted({d for p in px.values() for d in p})
    cash = capital
    held = {}                              # sym -> {qty, peak, bars, entry, trail, hold}
    last_price = {}
    curve, trades, wins = [], 0, 0
    reg_days = {"G": 0, "Y": 0, "R": 0}
    for d in calendar:
        reg = regime_of(breadth.get(d)) if gate else "G"
        reg_days[reg] += 1
        sold_today = set()
        for sym in list(held):
            p = px[sym].get(d)
            if p is None or p <= 0:
                continue
            h = held[sym]
            last_price[sym] = p
            h["bars"] += 1
            h["peak"] = max(h["peak"], p)
            if p <= h["peak"] * (1 - h["trail"]) or h["bars"] >= h["hold"]:
                cash += h["qty"] * p * (1 - cost)
                trades += 1
                if p > h["entry"]:
                    wins += 1
                sold_today.add(sym)
                del held[sym]
        equity = cash + sum(h["qty"] * last_price.get(s, h["entry"])
                            for s, h in held.items())
        # new entries, gated by today's regime
        if reg != "R":
            alloc = 0.02 if reg == "G" else 0.01
            for strength, sym, ei in sorted(sig_by_date.get(d, []), reverse=True):
                _k, _fn, trail, hold = ENGINES[ei]
                if reg == "Y" and ENGINES[ei][0] != "crash":
                    continue                       # YELLOW: crash engine only
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
                held[sym] = {"qty": qty, "peak": p, "bars": 0, "entry": p,
                             "trail": trail, "hold": hold}
                last_price[sym] = p
        curve.append((d, round(cash + sum(h["qty"] * last_price.get(s, h["entry"])
                                          for s, h in held.items()), 2)))
    return {"curve": curve, "trades": trades,
            "win": round(wins / trades * 100, 1) if trades else None,
            "final": curve[-1][1] if curve else capital, "regime_days": reg_days}


def format_race(rows, breadth_today, capital):
    w = 100
    money = lambda v: f"₹{v:,.0f}"  # noqa: E731
    lines = ["=" * w,
             "  Garuda · LAB SARATHI   (the charioteer's exam — does the breadth "
             "gate earn its seat?)",
             f"  Gate: GREEN >{GREEN_MIN:.0f}% breadth · YELLOW {YELLOW_MIN:.0f}-"
             f"{GREEN_MIN:.0f} (crash only, half size) · RED <{YELLOW_MIN:.0f}% "
             f"(cash) · thresholds fixed a priori",
             "=" * w,
             f"  {'PORTFOLIO':<22}{'FINAL':>14}{'CAGR/yr':>9}{'worst DD':>10}"
             f"{'worst YEAR':>12}{'trades':>8}{'win%':>6}",
             "-" * w]
    for name, sim, m in rows:
        worst_yr = min(m["yearly"].values()) if m["yearly"] else 0.0
        lines.append(f"  {name:<22}{money(m['final']):>14}{m['cagr_pct']:>+8.1f}%"
                     f"{m['max_dd_pct']:>9.1f}%{worst_yr:>+11.1f}%"
                     f"{(sim.get('trades') or '—'):>8}"
                     f"{(str(sim['win']) if sim.get('win') is not None else '—'):>6}")
    lines.append("-" * w)
    years = sorted({y for _, _, m in rows for y in m["yearly"]})
    lines.append("  YEAR BY YEAR (%):" + "".join(f"{y:>12}" for y in years))
    for name, _s, m in rows:
        lines.append(f"  {name:<18}" + "".join(
            f"{(('%+.1f' % m['yearly'][y]) if y in m['yearly'] else '—'):>12}"
            for y in years))
    g = rows[0][1].get("regime_days", {})
    lines += ["-" * w,
              f"  Regime days — GREEN {g.get('G', 0)} · YELLOW {g.get('Y', 0)} · "
              f"RED {g.get('R', 0)}   ·   breadth today: "
              f"{breadth_today if breadth_today is not None else '—'}%",
              "  SHIP RULE (fixed before the run): SARATHI must beat the ungated "
              "blend on drawdown AND worst",
              "  year, with CAGR equal or better. Anything less = FAILED, and the "
              "10th book goes to the fallback.",
              "=" * w]
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Garuda LAB SARATHI (regime-gate exam)")
    ap.add_argument("--csv", default="strength_history.csv",
                    help="deep-history long CSV (symbol,date,close)")
    ap.add_argument("--nifty", default="nifty_daily.csv",
                    help="optional Nifty daily CSV benchmark")
    ap.add_argument("--capital", type=float, default=1_000_000.0)
    a = ap.parse_args(argv)
    p = Path(a.csv)
    if not p.exists():
        sys.exit(f"{a.csv} not found — run scripts/run_lab.sh first")
    dated = {s: sorted(dv.items()) for s, dv in _load_long(p).items()}
    print(f"[sarathi] {len(dated)} symbols · computing breadth + racing "
          f"gated vs ungated ...")
    b = breadth_series(dated)
    b_today = b.get(max(b)) if b else None
    rows = []
    sar = simulate_sarathi(dated, gate=True, capital=a.capital)
    m1 = metrics(sar["curve"], a.capital)
    rows.append(("SARATHI (gated)", sar, m1))
    plain = simulate_sarathi(dated, gate=False, capital=a.capital)
    rows.append(("UNGATED 50/50", plain, metrics(plain["curve"], a.capital)))
    npath = Path(a.nifty)
    if npath.exists():
        nser = sorted(next(iter(_load_long(npath).values())).items())
        nf = nifty_hold(nser, a.capital)
        rows.append(("NIFTY buy & hold", nf, metrics(nf["curve"], a.capital)))
    print(format_race(rows, b_today, a.capital))


if __name__ == "__main__":
    main()
