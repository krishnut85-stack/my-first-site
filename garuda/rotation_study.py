"""Does buying the beaten-down industry actually work? Ask the 21 years.

The idea under test, in the user's words: when an industry falls, buy it; when
it has run up, sell it and move to the next one that is down. That is
**mean reversion** — and it is the opposite of "go with the trend", which would
have you buy whatever is already strongest. Both are testable, so this tests
both rather than arguing about them.

The method
----------
At each month end, rank every industry by its trailing L-month return, then
hold K of them for H months, equally weighted:

* ``contrarian`` buys the WEAKEST K — the user's idea
* ``momentum``  buys the STRONGEST K — its opposite

Switching costs are charged on the fraction of the book that actually turns
over, so a strategy that churns every month pays for it.

Why the split matters
---------------------
Sixteen combinations over one history will always produce a winner; that is
arithmetic, not insight. So every run is scored twice — on the older **PAST**
years, and on the **UNSEEN** years that follow. A rule that only works on the
past is labelled OVERFIT and is worth nothing. This is the same discipline
lab.py already applies to single-stock ideas.

Everything here is measurement. It places no orders and proposes no trades.
"""

import json
import statistics
from datetime import datetime
from pathlib import Path

from . import config

STUDY_FILE = config.DATA_DIR / "rotation_study.json"

#: Round-trip cost charged on the turned-over fraction, per rebalance.
COST_BPS = 30

#: The grid. Small on purpose — every extra knob buys another chance to fool
#: ourselves, and the split can only absorb so much.
LOOKBACKS = (1, 3, 6, 12)
HOLDS = (1, 3, 6)
KS = (3, 5)
DIRECTIONS = ("contrarian", "momentum")

#: Fraction of history used to fit intuition; the rest is never looked at
#: while choosing.
PAST_FRACTION = 0.70


# ------------------------------------------------------------ the maths ----

def month_key(t):
    return t[:7]


def monthly_returns_by_industry(series_by_industry):
    """{industry: {'YYYY-MM': pct return}} from {industry: [{t, c}]}."""
    out = {}
    for ind, rows in series_by_industry.items():
        closes = {}
        for r in rows:
            k = month_key(str(r["t"]))
            prev = closes.get(k)
            if prev is None or str(r["t"]) >= prev[0]:
                closes[k] = (str(r["t"]), float(r["c"]))
        keys = sorted(closes)
        rets = {}
        for i in range(1, len(keys)):
            a, b = closes[keys[i - 1]][1], closes[keys[i]][1]
            if a:
                rets[keys[i]] = (b - a) / a * 100.0
        if rets:
            out[ind] = rets
    return out


def all_months(rets):
    return sorted({m for r in rets.values() for m in r})


def trailing(rets, ind, upto_idx, months, lookback):
    """Compound return over the `lookback` months ending at upto_idx."""
    lo = upto_idx - lookback + 1
    if lo < 0:
        return None
    acc = 1.0
    for i in range(lo, upto_idx + 1):
        r = rets.get(ind, {}).get(months[i])
        if r is None:
            return None
        acc *= (1 + r / 100.0)
    return (acc - 1) * 100.0


def backtest(rets, months, lookback, hold, k, direction, cost_bps=COST_BPS):
    """Monthly portfolio returns for one rule. [] if history is too short.

    Holds are re-picked every `hold` months; in between the book is left alone,
    which is what "wait for the next one" actually means in practice.
    """
    out, held, since = [], [], 0
    for i in range(len(months) - 1):
        if i < lookback:
            continue
        if not held or since >= hold:
            scored = [(ind, trailing(rets, ind, i, months, lookback))
                      for ind in rets]
            scored = [(a, b) for a, b in scored if b is not None]
            if len(scored) < k:
                continue
            scored.sort(key=lambda x: x[1])
            picks = [a for a, _ in (scored[:k] if direction == "contrarian"
                                    else scored[-k:])]
            turnover = 1.0 if not held else \
                len(set(picks) - set(held)) / float(k)
            cost = turnover * cost_bps / 100.0
            held, since = picks, 0
        else:
            cost = 0.0
        since += 1
        nxt = months[i + 1]
        got = [rets[p][nxt] for p in held if nxt in rets.get(p, {})]
        if not got:
            continue
        out.append((nxt, statistics.fmean(got) - cost))
    return out


def equal_weight_all(rets, months):
    """The market proxy: hold every industry, every month, for nothing."""
    out = []
    for m in months:
        got = [r[m] for r in rets.values() if m in r]
        if got:
            out.append((m, statistics.fmean(got)))
    return out


def stats(series):
    """CAGR, worst drawdown, hit rate — enough to judge, no more."""
    if not series:
        return {"months": 0, "cagr": None, "total": None, "maxdd": None,
                "hit": None}
    lvl, peak, dd = 100.0, 100.0, 0.0
    for _m, r in series:
        lvl *= (1 + r / 100.0)
        peak = max(peak, lvl)
        dd = min(dd, (lvl / peak - 1) * 100.0)
    years = len(series) / 12.0
    cagr = ((lvl / 100.0) ** (1 / years) - 1) * 100 if years >= 1 else None
    return {"months": len(series),
            "cagr": round(cagr, 2) if cagr is not None else None,
            "total": round(lvl - 100, 1),
            "maxdd": round(dd, 1),
            "hit": round(sum(1 for _m, r in series if r > 0) / len(series) * 100)}


def split_months(months, past_fraction=PAST_FRACTION):
    cut = int(len(months) * past_fraction)
    return months[:cut], months[cut:]


def run_grid(rets, months, cost_bps=COST_BPS):
    """Every rule, scored on PAST and again on the UNSEEN years that follow."""
    past, unseen = split_months(months)
    rows = []
    for direction in DIRECTIONS:
        for lookback in LOOKBACKS:
            for hold in HOLDS:
                for k in KS:
                    a = stats(backtest(rets, past, lookback, hold, k,
                                       direction, cost_bps))
                    b = stats(backtest(rets, unseen, lookback, hold, k,
                                       direction, cost_bps))
                    rows.append({
                        "direction": direction, "lookback": lookback,
                        "hold": hold, "k": k, "past": a, "unseen": b,
                        "verdict": verdict(a, b),
                    })
    return rows, past, unseen


def verdict(past, unseen):
    """Only a rule that pays in BOTH halves earns anything but a warning."""
    if past["cagr"] is None or unseen["cagr"] is None:
        return "NO DATA"
    if past["cagr"] > 0 and unseen["cagr"] > 0:
        return "HOLDS UP"
    if past["cagr"] > 0 >= unseen["cagr"]:
        return "OVERFIT"
    return "REJECTED"


# ------------------------------------------------------------------ CLI ----

def _load_industry_series(csv_dir=None, universe_arg=None, log=print):
    from .cycle_study import (by_industry, find_universe_files,
                              gather_industries, load_universe)
    files = find_universe_files(universe_arg, csv_dir)
    universe = load_universe(files)
    if not universe:
        log("no universe found — run cycle_study --scan first")
        return {}
    log(f"universe: {len(universe)} stocks · "
        f"{len(by_industry(universe))} industries")
    data, _meta = gather_industries(None, universe, offline=True, log=log)
    return data


def main(argv=None):
    import sys
    argv = list(sys.argv[1:] if argv is None else argv)

    def opt(flag, cast=str, default=None):
        return cast(argv[argv.index(flag) + 1]) if flag in argv else default

    cost = opt("--cost-bps", int, COST_BPS)
    data = _load_industry_series(opt("--csv-dir"), opt("--universe"))
    if not data:
        return 1
    rets = monthly_returns_by_industry(data)
    months = all_months(rets)
    if len(months) < 60:
        print(f"only {len(months)} months of history — not enough to judge")
        return 1

    past, unseen = split_months(months)
    print(f"\n{len(rets)} industries · {len(months)} months "
          f"({months[0]} to {months[-1]})")
    print(f"PAST {past[0]}..{past[-1]}   UNSEEN {unseen[0]}..{unseen[-1]}")
    print(f"costs: {cost} bps on the turned-over fraction each rebalance\n")

    bench_all = stats(equal_weight_all(rets, months))
    bench_past = stats(equal_weight_all(rets, past))
    bench_unseen = stats(equal_weight_all(rets, unseen))
    print(f"BENCHMARK — hold every industry, always:")
    print(f"  whole period  CAGR {bench_all['cagr']}%  maxDD {bench_all['maxdd']}%")
    print(f"  past          CAGR {bench_past['cagr']}%")
    print(f"  unseen        CAGR {bench_unseen['cagr']}%\n")

    rows, _p, _u = run_grid(rets, months, cost)
    rows.sort(key=lambda r: (r["unseen"]["cagr"] is None,
                             -(r["unseen"]["cagr"] or -999)))
    print(f"{'RULE':<34}{'PAST':>9}{'UNSEEN':>9}{'UNSEEN dd':>11}  VERDICT")
    for r in rows:
        name = (f"{r['direction']:<11} look {r['lookback']:>2}m "
                f"hold {r['hold']}m top{r['k']}")
        print(f"{name:<34}{_pc(r['past']['cagr']):>9}"
              f"{_pc(r['unseen']['cagr']):>9}"
              f"{_pc(r['unseen']['maxdd']):>11}  {r['verdict']}")

    best = rows[0]
    print(f"\nBest on unseen years: {best['direction']} "
          f"look {best['lookback']}m hold {best['hold']}m top{best['k']} — "
          f"{_pc(best['unseen']['cagr'])} vs benchmark "
          f"{_pc(bench_unseen['cagr'])}")
    print("Read the VERDICT column, not this line: one winner out of "
          f"{len(rows)} tries is what chance looks like.")

    STUDY_FILE.parent.mkdir(parents=True, exist_ok=True)
    STUDY_FILE.write_text(json.dumps({
        "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "industries": sorted(rets), "months": len(months),
        "first": months[0], "last": months[-1],
        "past": [past[0], past[-1]], "unseen": [unseen[0], unseen[-1]],
        "cost_bps": cost,
        "benchmark": {"all": bench_all, "past": bench_past,
                      "unseen": bench_unseen},
        "rules": rows,
    }, indent=1))
    print(f"\nwrote {STUDY_FILE}")
    return 0


def _pc(v):
    return "—" if v is None else f"{v:+.2f}%"


if __name__ == "__main__":
    raise SystemExit(main())
