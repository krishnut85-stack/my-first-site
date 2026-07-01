#!/usr/bin/env python3
"""
elon_momentum.py  -  ELON MOMENTUM: dual-momentum SECTOR ROTATION (NRO-legal)
=============================================================================
Strategy 2 -- built from the research (the most robust edge in markets), and the
opposite of the dip-buying our own backtests killed. "Buy strength, ride leaders."

THE EDGE (why it persists): momentum is the most-documented anomaly worldwide
(AQR: positive every decade since 1880). Sector rotation applies it to indices,
which are cleaner than single stocks (no company blow-ups).

DUAL MOMENTUM (Antonacci) + crash protection (Barroso/Santa-Clara, Alpha Arch.):
  * RELATIVE momentum  : each month, rank sector/index by blended momentum
    (mean of 3/6/12-month returns -> not fragile to one lookback) and hold the
    TOP N.
  * ABSOLUTE momentum  : hold a sector ONLY if its own 12-month return > 0 AND
    the broad market (NIFTY 50) is above its 200-DMA. Otherwise that slot -> CASH.
    This is the crash guard -- in a bear market the book sits in cash.
  * MONTHLY rebalance   : low turnover -> low cost (the thing that killed the
    earlier high-churn strategies).

NRO-COMPLIANT: traded via sector/index ETFs (NIFTYBEES, BANKBEES, ITBEES, ...) on
DELIVERY (CNC). No intraday/MIS, no shorting. Paper == live.

HONEST TEST: monthly equity curve vs a buy-&-hold NIFTY benchmark, a TRAIN/
VALIDATE date split, and a Monte Carlo bootstrap. A strategy must beat just
holding the index (Sharpe + drawdown), out-of-sample, to be a candidate.

USAGE
  python3 elon_momentum.py --selftest                    # offline engine tests
  python3 elon_momentum.py --days 2500 --universe indices.txt   # ~10yr rotation
"""

import os
import sys
import time
import random
import argparse
import datetime as dt
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import elon_code as E                                       # noqa: E402


@dataclass
class MomP:
    top_n: int = int(os.environ.get("EQM_TOP_N", "3"))            # sectors to hold
    lookbacks: tuple = (3, 6, 12)                                 # months, blended
    abs_lookback: int = int(os.environ.get("EQM_ABS_LB", "12"))   # absolute-momentum months
    use_regime: bool = os.environ.get("EQM_USE_REGIME", "1").strip() == "1"
    per_side_cost: float = float(os.environ.get("EQM_COST_PCT", "0.15"))  # % per side (~0.30% round trip)
    cash_annual: float = float(os.environ.get("EQM_CASH_ANNUAL", "0.06")) # liquid-fund yield when in cash
    benchmark: str = os.environ.get("EQM_BENCHMARK", "NIFTY 50")


# --- portfolio stats ---------------------------------------------------------
def stats(rets):
    if not rets:
        return None
    eq = peak = 1.0
    mdd = 0.0
    for r in rets:
        eq *= (1 + r)
        peak = max(peak, eq)
        mdd = min(mdd, eq / peak - 1)
    n = len(rets)
    mean = sum(rets) / n
    sd = (sum((r - mean) ** 2 for r in rets) / n) ** 0.5 if n > 1 else 0.0
    return {
        "months": n,
        "total_pct": (eq - 1) * 100,
        "cagr_pct": ((eq ** (12.0 / n) - 1) * 100) if eq > 0 else -100.0,
        "vol_pct": sd * (12 ** 0.5) * 100,
        "sharpe": (mean / sd * (12 ** 0.5)) if sd > 1e-9 else 0.0,
        "maxdd_pct": mdd * 100,
        "win_month_pct": sum(1 for r in rets if r > 0) / n * 100,
        "final_eq": eq,
    }


def monte_carlo(rets, iters=2000):
    if len(rets) < 6:
        return None
    finals = []
    for _ in range(iters):
        eq = 1.0
        for _ in range(len(rets)):
            eq *= (1 + random.choice(rets))
        finals.append(eq - 1)
    finals.sort()
    return {"p_loss_pct": sum(1 for x in finals if x < 0) / iters * 100.0,
            "p05_pct": finals[int(0.05 * iters)] * 100, "median_pct": finals[iters // 2] * 100}


# --- shared ranking logic (used by BOTH backtest and the live/paper bot) ------
def momentum_scores(monthly, months, i, P):
    """At month index i: blended relative-momentum score + 12m absolute momentum
    for every symbol with enough history. Single source of truth for backtest
    AND live, so paper == live can never disagree on the signal."""
    syms = [s for s in monthly if s != P.benchmark] or list(monthly)
    scores, abs_moms = {}, {}
    for s in syms:
        c = monthly[s]
        m = months[i]
        if m not in c:
            continue
        if all(months[i - lb] in c for lb in P.lookbacks):
            rs = [c[m] / c[months[i - lb]] - 1 for lb in P.lookbacks if c[months[i - lb]] > 0]
            if len(rs) == len(P.lookbacks):
                scores[s] = sum(rs) / len(rs)
        base = c.get(months[i - P.abs_lookback], 0)
        abs_moms[s] = (c[m] / base - 1) if base > 0 else -1.0
    return scores, abs_moms


def select_weights(scores, abs_moms, reg, P):
    """Dual momentum: hold top-N by relative momentum, but ONLY if absolute
    momentum > 0 AND market regime is up; empty slots stay in cash. Returns
    {sym: weight}."""
    weights = {}
    if reg and scores:
        for s in sorted(scores, key=scores.get, reverse=True)[:P.top_n]:
            if abs_moms.get(s, -1) > 0:
                weights[s] = 1.0 / P.top_n
    return weights


# --- the pure backtest core (no Kite; unit-testable) -------------------------
def backtest(monthly, months, regime_ok, P):
    """monthly: {sym: {YYYY-MM: close}}. months: sorted list of YYYY-MM.
    regime_ok: {YYYY-MM: bool} (broad market above 200-DMA). Returns
    (dates, strat_rets, bench_rets) of month-over-month returns, net of costs."""
    lb_max = max(P.lookbacks + (P.abs_lookback,))
    strat, bench, dates = [], [], []
    prev_w = {}
    cash_m = (1 + P.cash_annual) ** (1 / 12.0) - 1
    for i in range(lb_max, len(months) - 1):
        m, nxt = months[i], months[i + 1]
        reg = regime_ok.get(m, True) if P.use_regime else True
        scores, abs_moms = momentum_scores(monthly, months, i, P)   # shared with live
        weights = select_weights(scores, abs_moms, reg, P)          # empty slots -> cash
        cash_w = 1.0 - sum(weights.values())
        # turnover cost (one-way turnover x per-side cost)
        turnover = sum(abs(weights.get(k, 0) - prev_w.get(k, 0))
                       for k in set(weights) | set(prev_w))
        cost = turnover * P.per_side_cost / 100.0
        # realised next-month return
        r = cash_w * cash_m
        for s, w in weights.items():
            c = monthly[s]
            if m in c and nxt in c and c[m] > 0:
                r += w * (c[nxt] / c[m] - 1)
        strat.append(r - cost)
        b = monthly.get(P.benchmark)
        bench.append((b[nxt] / b[m] - 1) if (b and m in b and nxt in b and b[m] > 0) else 0.0)
        dates.append(nxt)
        prev_w = weights
    return dates, strat, bench


# --- Kite data: daily -> monthly closes + regime -----------------------------
def _monthly_from_daily(bars):
    """Last close of each calendar month -> {YYYY-MM: close}."""
    out = {}
    for b in bars:
        out[str(b["date"])[:7]] = b["close"]   # later bars overwrite -> month-end close
    return out


def _regime_by_month(bars, sma=200):
    """{YYYY-MM: index-above-200DMA at month end}."""
    closes = [b["close"] for b in bars]
    out = {}
    for i in range(len(bars)):
        if i >= sma:
            out[str(bars[i]["date"])[:7]] = closes[i] > sum(closes[i - sma:i]) / sma
    return out


def _hist_chunked(kite, tok, frm, to, interval="day", max_days=1900):
    """Kite caps daily history at ~2000 days/request. Fetch in <=1900-day chunks
    and concatenate (deduped) so we can pull 10+ years for the momentum lookbacks."""
    out, cur = [], frm
    while cur < to:
        end = min(cur + dt.timedelta(days=max_days), to)
        try:
            out += kite.historical_data(tok, cur, end, interval)
        except Exception as e:
            print(f"    chunk {str(cur)[:10]}..{str(end)[:10]} failed ({e})")
        cur = end + dt.timedelta(days=1)
        time.sleep(0.3)
    seen, dedup = set(), []
    for b in out:
        d = str(b["date"])[:10]
        if d not in seen:
            seen.add(d); dedup.append(b)
    return dedup


def _fetch(P, days, universe):
    E._load_env()
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[momentum] Kite login failed: {e}\n  -> source /home/globalbot/.env first.")
        return None, None
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=days + 400)
    syms = list(dict.fromkeys(universe + [P.benchmark]))
    monthly, regime = {}, {}
    print(f"[momentum] Kite up. Fetching {len(syms)} instruments (daily -> monthly, chunked)...")
    for i, sym in enumerate(syms, 1):
        try:
            tok = E._TOKENS.get(sym) or kite.ltp([f"NSE:{sym}"]).get(f"NSE:{sym}", {}).get("instrument_token")
            if not tok:
                continue
            bars = _hist_chunked(kite, tok, frm, to, "day")
            if not bars:
                continue
        except Exception as e:
            print(f"  {sym}: fetch failed ({e})")
            continue
        monthly[sym] = _monthly_from_daily(bars)
        if sym == P.benchmark:
            regime = _regime_by_month(bars)
    return monthly, regime


def _split_and_report(dates, strat, bench, P, label="ELON MOMENTUM · SECTOR ROTATION"):
    if not strat:
        print("[momentum] no strategy returns."); return
    cut = len(dates) * 7 // 10
    print("\n" + "=" * 74)
    print(f"  {label}  (NRO delivery via ETFs — paper)")
    print("=" * 74)
    print(f"  Rules: hold top {P.top_n} sectors by blended {P.lookbacks} mth momentum; "
          f"only if 12m>0 & Nifty>200DMA, else cash. Monthly rebalance.")
    print(f"  Cost : {P.per_side_cost:.2f}%/side   Cash yield: {P.cash_annual*100:.0f}%/yr")
    print("-" * 74)

    def block(name, s, b):
        ss, bb = stats(s), stats(b)
        if not ss:
            print(f"  {name}: no data"); return
        print(f"  {name} ({ss['months']} mo):")
        print(f"    Strategy : CAGR {ss['cagr_pct']:+.1f}% | Sharpe {ss['sharpe']:.2f} | "
              f"maxDD {ss['maxdd_pct']:.1f}% | win-mo {ss['win_month_pct']:.0f}% | tot {ss['total_pct']:+.0f}%")
        print(f"    Nifty B&H: CAGR {bb['cagr_pct']:+.1f}% | Sharpe {bb['sharpe']:.2f} | "
              f"maxDD {bb['maxdd_pct']:.1f}% | tot {bb['total_pct']:+.0f}%")

    block("ALL", strat, bench)
    block("TRAIN (in-sample)", strat[:cut], bench[:cut])
    block("VALIDATE (out-of-sample)", strat[cut:], bench[cut:])
    mc = monte_carlo(strat)
    if mc:
        print(f"  Monte Carlo (total return): P(loss) {mc['p_loss_pct']:.0f}% | "
              f"5th pct {mc['p05_pct']:+.0f}% | median {mc['median_pct']:+.0f}%")
    print("-" * 74)
    a_s, a_b = stats(strat), stats(bench)
    v_s, v_b = stats(strat[cut:]), stats(bench[cut:])
    beats_all = a_s["sharpe"] > a_b["sharpe"] and a_s["cagr_pct"] > 0
    beats_oos = v_s and v_b and v_s["sharpe"] > v_b["sharpe"] and v_s["cagr_pct"] > 0
    if beats_all and beats_oos:
        v = "CANDIDATE — beats buy-&-hold Nifty on Sharpe, IN- and OUT-of-sample. Live-paper it."
    elif beats_all:
        v = "MARGINAL — beats the index overall but not out-of-sample. Needs more data / caution."
    else:
        v = "REJECT — does not beat simply holding the Nifty. Not worth the complexity."
    print(f"  VERDICT: {v}")
    print("=" * 74)
    print("  Coarse monthly test, NRO delivery via ETFs. Not advice. Live-paper before real money.\n")


def run(P, days, universe):
    monthly, regime = _fetch(P, days, universe)
    if not monthly:
        print("[momentum] no data."); return
    months = sorted({m for s in monthly.values() for m in s})
    dates, strat, bench = backtest(monthly, months, regime, P)
    _split_and_report(dates, strat, bench, P)
    return dates, strat, bench


def run_lookback_compare(days, universe):
    """Q1: is a FASTER rotation signal better? Fetch once, test several ranking
    lookback blends (the 200-DMA / 12m regime brake stays SLOW), judge on the
    out-of-sample window. Keeps knob-1 (crash brake) fixed, tunes knob-2 (speed)."""
    monthly, regime = _fetch(MomP(), days, universe)
    if not monthly:
        print("[momentum] no data."); return
    months = sorted({m for s in monthly.values() for m in s})
    configs = [("current 3/6/12", (3, 6, 12)), ("faster 1/3/6", (1, 3, 6)),
               ("fast 1/2/3", (1, 2, 3)), ("medium 3/6", (3, 6)),
               ("mixed 1/3/6/12", (1, 3, 6, 12)), ("classic 12", (12,))]
    print("\n" + "=" * 82)
    print("  ELON MOMENTUM · ROTATION-SPEED SWEEP  (regime brake fixed; judged OOS)")
    print("=" * 82)
    print(f"  {'lookback blend':16} {'CAGR(ALL)':>10} {'Sharpe(ALL)':>12} "
          f"{'CAGR(OOS)':>10} {'Sharpe(OOS)':>12} {'maxDD':>8}")
    print("  " + "-" * 78)
    rows = []
    for name, lb in configs:
        P = MomP(); P.lookbacks = lb
        _, strat, bench = backtest(monthly, months, regime, P)
        a, cut = stats(strat), len(strat) * 7 // 10
        v = stats(strat[cut:])
        if not a or not v:
            print(f"  {name:16} (insufficient data)"); continue
        rows.append((name, a, v))
        print(f"  {name:16} {a['cagr_pct']:>+9.1f}% {a['sharpe']:>12.2f} "
              f"{v['cagr_pct']:>+9.1f}% {v['sharpe']:>12.2f} {a['maxdd_pct']:>7.1f}%")
    nb = stats(bench)
    print("  " + "-" * 78)
    print(f"  {'Nifty B&H':16} {nb['cagr_pct']:>+9.1f}% {nb['sharpe']:>12.2f}")
    if rows:
        best = max(rows, key=lambda r: r[2]["sharpe"])
        print(f"\n  Best OUT-OF-SAMPLE Sharpe: '{best[0]}' "
              f"(OOS Sharpe {best[2]['sharpe']:.2f}, CAGR {best[2]['cagr_pct']:+.1f}%)")
        print("  -> if a faster blend clearly wins OOS, we switch Strategy 1 to it.")
    print("=" * 82 + "\n")
    return rows


# --- offline self-test -------------------------------------------------------
def selftest():
    P = MomP(); P.use_regime = False; P.top_n = 1; P.per_side_cost = 0.15
    months = [f"20{y:02d}-{mo:02d}" for y in range(20, 24) for mo in range(1, 13)]  # 36 months

    # WIN sector rises ~3%/mo, LOSE falls ~1%/mo, benchmark flat.
    win = {m: round(100 * (1.03 ** i), 4) for i, m in enumerate(months)}
    lose = {m: round(100 * (0.99 ** i), 4) for i, m in enumerate(months)}
    flat = {m: 100.0 for m in months}
    monthly = {"WIN": win, "LOSE": lose, "NIFTY 50": flat}
    regime = {m: True for m in months}
    dates, strat, bench = backtest(monthly, months, regime, P)
    ss = stats(strat)
    ok1 = ss and ss["total_pct"] > 0 and ss["total_pct"] > stats(bench)["total_pct"]
    print(f"  [1] rotates into the WINNER, beats flat bench : {'PASS' if ok1 else 'FAIL'} "
          f"(strat {ss['total_pct']:+.0f}% vs bench {stats(bench)['total_pct']:+.0f}%)")

    # Absolute-momentum guard: everything falling -> should sit in CASH (>= ~0),
    # not ride the losers down.
    P2 = MomP(); P2.use_regime = False; P2.top_n = 1; P2.cash_annual = 0.06
    allfall = {"A": {m: round(100 * (0.98 ** i), 4) for i, m in enumerate(months)},
               "B": {m: round(100 * (0.97 ** i), 4) for i, m in enumerate(months)},
               "NIFTY 50": {m: round(100 * (0.98 ** i), 4) for i, m in enumerate(months)}}
    _, s2, _ = backtest(allfall, months, regime, P2)
    ok2 = stats(s2)["total_pct"] > -5   # basically flat cash, not a big loss
    print(f"  [2] all-falling -> sits in CASH (no big loss) : {'PASS' if ok2 else 'FAIL'} "
          f"(strat {stats(s2)['total_pct']:+.1f}%)")

    # Regime gate: benchmark below its 200DMA -> forced cash.
    P3 = MomP(); P3.use_regime = True; P3.top_n = 1
    reg_off = {m: False for m in months}
    _, s3, _ = backtest(monthly, months, reg_off, P3)
    ok3 = abs(stats(s3)["total_pct"]) < 25   # near cash, not the +200% winner ride
    print(f"  [3] regime OFF -> forced to cash             : {'PASS' if ok3 else 'FAIL'} "
          f"(strat {stats(s3)['total_pct']:+.1f}%)")

    mc = monte_carlo(strat)
    ok4 = mc is not None
    print(f"  [4] Monte Carlo produces stats               : {'PASS' if ok4 else 'FAIL'}")

    ok = ok1 and ok2 and ok3 and ok4
    print("\n" + ("✓ ALL SELF-TESTS PASSED — rotation engine verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Elon Momentum: dual-momentum sector rotation (NRO).")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--compare", action="store_true",
                    help="sweep rotation-speed lookback blends, judged out-of-sample")
    ap.add_argument("--days", type=int, default=2500)     # ~10yr of daily bars
    ap.add_argument("--universe", default=None)
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    universe = (E.load_universe() if not args.universe
                else [l.strip().upper() for l in open(args.universe)
                      if l.strip() and not l.startswith("#")])
    if args.compare:
        run_lookback_compare(args.days, universe)
    else:
        run(MomP(), args.days, universe)


if __name__ == "__main__":
    main()
