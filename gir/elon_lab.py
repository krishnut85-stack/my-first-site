#!/usr/bin/env python3
"""
elon_lab.py  -  Multi-strategy research lab for the ELON CODE project
=====================================================================
Don't marry one idea. A desk generates MANY candidate strategies and lets the
data kill the losers and keep the survivors. This lab replays several genuinely
different intraday edges through ONE honest engine -- real ~0.11% costs, a
train/validate split (tune on part, judge on data it never saw), and a Monte
Carlo bootstrap -- then ranks them and prints a plain verdict per strategy.

STRATEGIES (deliberately different theses, so we're not betting on one premise):
  * meanrev  : buy a dip below VWAP that turns back up      (the current Elon)
  * orb      : buy the break of the first ORB_MIN-minute range   (momentum)
  * momentum : buy STRENGTH -- above VWAP and up on the day  (opposite of dip)

HONESTY RULES baked in:
  * Fetch history ONCE, replay every strategy on the SAME symbol-days.
  * TRAIN/VALIDATE split by date: a strategy only earns "candidate" status if it
    is positive on the VALIDATE window it was never fitted to (kills curve-fits).
  * Monte Carlo bootstrap of per-trade P&L -> probability of loss + 5th pct.
  * A strategy that isn't positive out-of-sample is REJECTED. That's the point.

USAGE
  python3 elon_lab.py --selftest                       # offline engine tests
  python3 elon_lab.py --days 30                         # all strategies, full universe
  python3 elon_lab.py --days 30 --strategies orb,momentum --universe /tmp/mini.txt

Coarse minute-bar replay. Not advice. A green backtest is a hypothesis, not a
promise -- validate live-paper before a single real rupee.
"""

import os
import sys
import time
import random
import argparse
import datetime as dt
from collections import namedtuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import elon_code as E                                    # noqa: E402
from elon_backtest import (Trade, Params, summarize, simulate_symbol_day,     # noqa: E402
                           _trend_ok_from_daily)

Rec = namedtuple("Rec", "sym day bars prev_close before")

# --- strategy-specific knobs (env-overridable, so we can sweep) --------------
ORB_MIN        = int(os.environ.get("EQ_ORB_MIN", "15"))        # opening-range minutes
ORB_TARGET_R   = float(os.environ.get("EQ_ORB_TARGET_R", "1.5"))# target = R x range
ORB_MIN_RANGE  = float(os.environ.get("EQ_ORB_MIN_RANGE", "0.3"))  # min range % to bother
ORB_MIN_TURN   = float(os.environ.get("EQ_ORB_MIN_TURN", "20000000"))
MOM_MIN        = float(os.environ.get("EQ_MOM_MIN", "1.0"))     # min day % up to call it strength
MOM_MAX        = float(os.environ.get("EQ_MOM_MAX", "6.0"))     # skip blow-off tops
MOM_TARGET     = float(os.environ.get("EQ_MOM_TARGET", "2.0"))  # take-profit %
MOM_STOP       = float(os.environ.get("EQ_MOM_STOP", "1.0"))    # stop %
MOM_MIN_TURN   = float(os.environ.get("EQ_MOM_MIN_TURN", "20000000"))
ENTRY_BEFORE   = E.NO_NEW_ENTRY_BEFORE
ENTRY_AFTER    = E.NO_NEW_ENTRY_AFTER
SQUARE_OFF     = E.SQUARE_OFF


def _book(sym, day, entry, exit_px, reason, P, stop=None):
    """Turn one entry/exit into a costed Trade (shared by all strategies)."""
    qty = max(1, int(P.notional / entry))
    gross = (exit_px - entry) * qty
    cost = P.cost_pct / 100.0 * entry * qty                    # ~0.11% all-in round trip
    net = gross - cost
    risk = (abs(entry - stop) * qty) if stop else (0.01 * entry * qty)
    return Trade(sym, day, round(entry, 2), round(exit_px, 2), qty, reason,
                 round(gross, 2), round(cost, 2), round(net, 2), round(net / (risk or 1.0), 2))


# --- STRATEGY 1: mean reversion (reuse the exact live/backtest engine) --------
def strat_meanrev(rec, P):
    trend_ok = _trend_ok_from_daily(rec.before, P)
    return simulate_symbol_day(rec.sym, rec.day, rec.bars, rec.prev_close, trend_ok, P)


# --- STRATEGY 2: opening-range breakout (momentum) ---------------------------
def strat_orb(rec, P):
    bars, prev = rec.bars, rec.prev_close
    if not bars or prev <= 0:
        return []
    or_end = (9, 15 + ORB_MIN)          # tuple time cutoff for the opening range
    or_hi = or_lo = None
    cum_v = 0.0
    entered = False
    entry = stop = target = None
    for b in bars:
        h, l, c, v = b["high"], b["low"], b["close"], (b["volume"] or 0)
        cum_v += v
        hm = (b["ts"].hour, b["ts"].minute)
        if hm < or_end:                 # still building the opening range
            or_hi = h if or_hi is None else max(or_hi, h)
            or_lo = l if or_lo is None else min(or_lo, l)
            continue
        if or_hi is None or or_lo is None or or_lo <= 0:
            continue
        rng = or_hi - or_lo
        if rng <= 0 or (rng / or_lo * 100.0) < ORB_MIN_RANGE:
            return []                   # range too tight to be meaningful
        in_squareoff = hm >= SQUARE_OFF

        if entered:
            if l <= stop:
                return [_book(rec.sym, rec.day, entry, stop, "STOP", P, stop)]
            if h >= target:
                return [_book(rec.sym, rec.day, entry, target, "TARGET", P, stop)]
            if in_squareoff:
                return [_book(rec.sym, rec.day, entry, c, "SQUAREOFF", P, stop)]
            continue

        if in_squareoff or hm >= ENTRY_AFTER:
            break                       # too late to open a new ORB trade
        # breakout above the range high, with enough liquidity
        if h >= or_hi and (c * cum_v) >= ORB_MIN_TURN:
            entry = or_hi
            stop = or_lo
            target = round(entry + ORB_TARGET_R * rng, 2)
            entered = True
    if entered:                         # ran out of bars still holding
        return [_book(rec.sym, rec.day, entry, bars[-1]["close"], "FORCE_EOD", P, stop)]
    return []


# --- STRATEGY 3: momentum -- buy STRENGTH above VWAP (opposite of the dip) ----
def strat_momentum(rec, P):
    bars, prev = rec.bars, rec.prev_close
    if not bars or prev <= 0:
        return []
    cum_pv = cum_v = 0.0
    entered = False
    entry = stop = target = None
    for b in bars:
        o, h, l, c, v = b["open"], b["high"], b["low"], b["close"], (b["volume"] or 0)
        tp = (h + l + c) / 3.0 if (h and l and c) else c
        cum_pv += tp * v; cum_v += v
        vwap = (cum_pv / cum_v) if cum_v > 0 else c
        hm = (b["ts"].hour, b["ts"].minute)
        in_window = ENTRY_BEFORE <= hm < ENTRY_AFTER
        in_squareoff = hm >= SQUARE_OFF

        if entered:
            if l <= stop:
                return [_book(rec.sym, rec.day, entry, stop, "STOP", P, stop)]
            if h >= target:
                return [_book(rec.sym, rec.day, entry, target, "TARGET", P, stop)]
            if in_squareoff:
                return [_book(rec.sym, rec.day, entry, c, "SQUAREOFF", P, stop)]
            continue

        if in_squareoff:
            break
        day_change = (c - prev) / prev * 100.0
        turnover = c * cum_v
        # strength: above VWAP, up MOM_MIN..MOM_MAX on the day, liquid
        if (in_window and c > vwap and MOM_MIN <= day_change <= MOM_MAX
                and turnover >= MOM_MIN_TURN):
            entry = c
            stop = round(entry * (1 - MOM_STOP / 100.0), 2)
            target = round(entry * (1 + MOM_TARGET / 100.0), 2)
            entered = True
    if entered:
        return [_book(rec.sym, rec.day, entry, bars[-1]["close"], "FORCE_EOD", P, stop)]
    return []


STRATEGIES = {"meanrev": strat_meanrev, "orb": strat_orb, "momentum": strat_momentum}


# --- Monte Carlo robustness (framework item 9) -------------------------------
def monte_carlo(trades, iters=2000):
    nets = [t.net for t in trades]
    if len(nets) < 5:
        return None
    n = len(nets)
    totals = []
    for _ in range(iters):
        totals.append(sum(random.choice(nets) for _ in range(n)))
    totals.sort()
    return {
        "p_loss_pct": sum(1 for t in totals if t < 0) / iters * 100.0,
        "p05": totals[int(0.05 * iters)],
        "median": totals[iters // 2],
    }


# --- data: fetch once, reuse for every strategy ------------------------------
def fetch_recs(kite, universe, days, P):
    to = dt.datetime.now()
    frm_daily = to - dt.timedelta(days=days + P.trend_sma * 2 + 15)
    recs = []
    for n, sym in enumerate(universe, 1):
        try:
            tok = E._TOKENS.get(sym) or kite.ltp([f"NSE:{sym}"]).get(f"NSE:{sym}", {}).get("instrument_token")
            if not tok:
                continue
            daily = kite.historical_data(tok, frm_daily, to, "day")
            minutes = kite.historical_data(tok, to - dt.timedelta(days=days + 5), to, "minute")
            time.sleep(0.35)
        except Exception as e:
            print(f"  {sym}: fetch failed ({e})")
            continue
        by_day = {}
        for m in minutes:
            d = str(m["date"])[:10]
            by_day.setdefault(d, []).append({
                "ts": m["date"], "open": m["open"], "high": m["high"],
                "low": m["low"], "close": m["close"], "volume": m.get("volume") or 0})
        daily_closes = [(str(x["date"])[:10], x["close"]) for x in daily]
        for d, bars in sorted(by_day.items()):
            before = [c for (dd, c) in daily_closes if dd < d]
            if before:
                recs.append(Rec(sym, d, bars, before[-1], before))
        if n % 50 == 0:
            print(f"  ...{n}/{len(universe)} fetched, {len(recs)} symbol-days")
    return recs


def _split(trades, cut_day):
    train = [t for t in trades if t.day < cut_day]
    val = [t for t in trades if t.day >= cut_day]
    return train, val


def run_lab(P, days, universe, which):
    E._load_env()
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[lab] Kite login failed: {e}\n  -> source /home/globalbot/.env first, "
              "and check the daily token file exists.")
        return
    print(f"[lab] Kite up. Fetching {len(universe)} symbols x {days}d (once, reused for all)...")
    recs = fetch_recs(kite, universe, days, P)
    if not recs:
        print("[lab] no data fetched.")
        return
    all_days = sorted({r.day for r in recs})
    cut = all_days[int(len(all_days) * 0.7)] if len(all_days) >= 4 else all_days[-1]
    print(f"[lab] {len(recs)} symbol-days over {len(all_days)} days. "
          f"Train < {cut} <= Validate.\n")

    results = {}
    for name in which:
        fn = STRATEGIES[name]
        trades = []
        for r in recs:
            try:
                trades += fn(r, P)
            except Exception as e:
                print(f"  [{name}] {r.sym} {r.day}: {e}")
        tr, val = _split(trades, cut)
        results[name] = {
            "all": summarize(trades),
            "train": summarize(tr),
            "validate": summarize(val),
            "mc": monte_carlo(trades),
        }
    _print_comparison(results, P)
    return results


def _fmt(stats, key, money=False):
    if not stats or stats.get("trades", 0) == 0:
        return "   n/a"
    v = stats.get(key)
    if v is None:
        return "   n/a"
    return f"{v:,.0f}" if money else f"{v:+.1f}"


def _print_comparison(results, P):
    print("=" * 78)
    print("  ELON LAB · MULTI-STRATEGY COMPARISON  (paper — real costs, out-of-sample)")
    print("=" * 78)
    hdr = f"  {'strategy':10} {'trades':>7} {'win%':>6} {'exp/trade':>10} " \
          f"{'net(all)':>11} {'exp(VALIDATE)':>13} {'MC P(loss)':>11}"
    print(hdr)
    print("  " + "-" * 74)
    ranked = sorted(results.items(),
                    key=lambda kv: (kv[1]["validate"] or {}).get("expectancy_per_trade", -9e9)
                    if kv[1]["validate"].get("trades") else -9e9, reverse=True)
    for name, r in ranked:
        a, v, mc = r["all"], r["validate"], r["mc"]
        exp_all = _fmt(a, "expectancy_per_trade")
        exp_val = _fmt(v, "expectancy_per_trade")
        net_all = _fmt(a, "net", money=True)
        win = _fmt(a, "win_rate_pct")
        mcp = f"{mc['p_loss_pct']:.0f}%" if mc else "n/a"
        ntr = a.get("trades", 0)
        print(f"  {name:10} {ntr:>7} {win:>6} {exp_all:>10} {net_all:>11} "
              f"{exp_val:>13} {mcp:>11}")
    print("  " + "-" * 74)
    print("\n  VERDICTS (a candidate must be POSITIVE on the VALIDATE window it never saw):")
    for name, r in ranked:
        a, v, mc = r["all"], r["validate"], r["mc"]
        va = v.get("expectancy_per_trade") if v.get("trades") else None
        aa = a.get("expectancy_per_trade") if a.get("trades") else None
        if va is not None and va > 0 and aa is not None and aa > 0:
            msg = (f"CANDIDATE — positive in-sample AND out-of-sample"
                   + (f", MC P(loss) {mc['p_loss_pct']:.0f}%" if mc else ""))
        elif aa is not None and aa > 0 and (va is None or va <= 0):
            msg = "FRAGILE — positive overall but NOT out-of-sample (likely curve-fit) -> reject"
        else:
            msg = "REJECT — negative expectancy after costs"
        print(f"    • {name:10}: {msg}")
    print("=" * 78)
    print("  Coarse minute-bar replay. A green result is a hypothesis to live-paper,")
    print("  not a promise. Validate forward before risking real money.\n")


# --- offline self-test (no Kite) ---------------------------------------------
def _mk(points):
    return [{"ts": dt.datetime(2026, 6, 22, h, m), "open": o, "high": hi,
             "low": lo, "close": c, "volume": v} for (h, m, o, hi, lo, c, v) in points]


def selftest():
    P = Params()
    ok = True

    # ORB: build a 9:15-9:30 range then break above it to target.
    bars = _mk([
        (9, 15, 100, 101, 99.5, 100.5, 500000),    # opening range forms...
        (9, 20, 100.5, 101, 100, 100.8, 500000),
        (9, 29, 100.8, 101, 100.2, 100.9, 500000), # OR high 101, low 99.5 (range 1.5)
        (9, 35, 101, 101.5, 101, 101.3, 800000),   # BREAKOUT bar -> ENTER at 101, tgt 103.25
        (9, 40, 101.3, 103.5, 101.3, 103.3, 800000),  # runs to the target -> TARGET
    ])
    t = strat_orb(Rec("ORBWIN", "2026-06-22", bars, 100.0, [100]), P)
    orb_ok = len(t) == 1 and t[0].reason == "TARGET" and t[0].net > 0
    print(f"  [1] ORB breakout -> target WIN       : {'PASS' if orb_ok else 'FAIL'} "
          f"({[(x.reason, x.net) for x in t]})")
    ok &= orb_ok

    # ORB: tight range (< ORB_MIN_RANGE) -> no trade.
    flat = _mk([(9, 15, 100, 100.1, 99.99, 100.05, 500000),
                (9, 29, 100.05, 100.1, 100.0, 100.05, 500000),
                (9, 35, 100.05, 100.1, 100.0, 100.05, 500000)])
    t2 = strat_orb(Rec("FLAT", "2026-06-22", flat, 100.0, [100]), P)
    print(f"  [2] ORB tight range -> NO trade      : {'PASS' if len(t2)==0 else 'FAIL'} ({len(t2)})")
    ok &= (len(t2) == 0)

    # Momentum: strong stock above VWAP, up ~2% -> enters, rides to target.
    mom = _mk([
        (10, 0, 100, 101.5, 100, 101.4, 600000),   # up ~1.4%... building vwap
        (10, 5, 101.4, 102.6, 101.4, 102.5, 700000),  # up 2.5%, above vwap -> ENTER ~102.5
        (10, 20, 102.5, 105.0, 102.5, 104.8, 800000), # +2% target ~104.55 hit
    ])
    t3 = strat_momentum(Rec("MOM", "2026-06-22", mom, 100.0, [100]), P)
    mom_ok = len(t3) == 1 and t3[0].reason == "TARGET" and t3[0].net > 0
    print(f"  [3] Momentum strength -> target WIN  : {'PASS' if mom_ok else 'FAIL'} "
          f"({[(x.reason, x.net) for x in t3]})")
    ok &= mom_ok

    # Monte Carlo returns a dict on a mixed set.
    mc = monte_carlo(t + t3 + [Trade("X", "d", 100, 99, 10, "STOP", -10, 1, -11, -1)] * 6)
    mc_ok = mc is not None and "p_loss_pct" in mc
    print(f"  [4] Monte Carlo produces stats       : {'PASS' if mc_ok else 'FAIL'} "
          f"({'p_loss=%.0f%%' % mc['p_loss_pct'] if mc else 'none'})")
    ok &= mc_ok

    print("\n" + ("✓ ALL SELF-TESTS PASSED — strategy engines verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Multi-strategy research lab for Elon.")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--universe", default=None)
    ap.add_argument("--strategies", default="meanrev,orb,momentum",
                    help="comma list: meanrev,orb,momentum")
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    which = [s.strip() for s in args.strategies.split(",") if s.strip() in STRATEGIES]
    if not which:
        print("No valid strategies. Choose from: " + ", ".join(STRATEGIES))
        sys.exit(1)
    universe = (E.load_universe() if not args.universe
                else [l.strip().upper() for l in open(args.universe)
                      if l.strip() and not l.startswith("#")])
    run_lab(Params(), args.days, universe, which)


if __name__ == "__main__":
    main()
