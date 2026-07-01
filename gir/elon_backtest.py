#!/usr/bin/env python3
"""
elon_backtest.py  -  Walk-forward backtester for the ELON CODE mean-reversion bot
=================================================================================
"You cannot manage what you cannot measure." A live paper bot tells you what
happened; a backtest tells you whether the EDGE is real BEFORE you commit. This
replays historical minute bars through the EXACT same arm -> confirm -> trend-
filter -> exit logic Elon trades live, charges real round-trip costs, and prints
expectancy, win-rate, profit factor, max drawdown and a rough Sharpe.

DESIGN (why it is trustworthy):
  * SINGLE SOURCE OF TRUTH. All strategy knobs are imported from elon_code, so
    the backtest and the live bot can never silently disagree on parameters.
  * DATA-SOURCE AGNOSTIC CORE. `simulate_symbol_day()` is pure: feed it bars, it
    returns trades. That lets us unit-test it offline (./elon_backtest.py
    --selftest) with zero Kite access, and run it on real data on the droplet.
  * HONEST COSTS. Every round trip is charged EQ_COST_PCT (~0.11% all-in), so a
    high-churn result is penalised exactly like reality.

USAGE
  # offline correctness self-test (no Kite, runs anywhere):
  python elon_backtest.py --selftest
  # real backtest on the droplet (uses the daily Kite token, like elon_code):
  python elon_backtest.py --days 30 [--universe FILE] [--target 1.5 --stop 0.8]

This measures a COARSE minute-bar approximation (one bar ~ one live poll). It is
a genuine test of whether the ranking/timing adds value, not a profit guarantee.
"""

import os
import sys
import time
import argparse
import datetime as dt
from dataclasses import dataclass, field
from statistics import mean, pstdev

# Single source of truth: pull every strategy constant from the live bot.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import elon_code as E   # noqa: E402  (import after sys.path tweak)


# --- parameters (defaults mirror elon_code; CLI can override for sweeps) ------
@dataclass
class Params:
    stretch_min: float = E.STRETCH_MIN_PCT
    knife: float = E.KNIFE_PCT
    min_turnover: float = E.MIN_TURNOVER
    confirm: float = E.CONFIRM_PCT
    arm_max_cycles: int = E.ARM_MAX_CYCLES
    target: float = E.TARGET_PCT
    stop: float = E.STOP_PCT
    notional: float = E.PER_TRADE_NOTIONAL
    trend_filter: bool = E.TREND_FILTER
    trend_sma: int = E.TREND_SMA
    entry_before: tuple = E.NO_NEW_ENTRY_BEFORE
    entry_after: tuple = E.NO_NEW_ENTRY_AFTER
    squareoff: tuple = E.SQUARE_OFF
    cost_pct: float = float(os.environ.get("EQ_COST_PCT", "0.11"))   # all-in round trip
    # --- edge experiments (OFF by default so the baseline == live logic) ------
    time_stop_min: int = int(os.environ.get("EQ_TIME_STOP_MIN", "0"))     # 0 = off
    atr_exits: bool = os.environ.get("EQ_ATR_EXITS", "0").strip() == "1"  # ATR stop/target
    atr_stop_mult: float = float(os.environ.get("EQ_ATR_STOP_MULT", "1.5"))
    atr_target_mult: float = float(os.environ.get("EQ_ATR_TARGET_MULT", "2.5"))


@dataclass
class Trade:
    symbol: str
    day: str
    entry: float
    exit: float
    qty: int
    reason: str
    gross: float
    cost: float
    net: float
    r_multiple: float


# --- the pure simulation core (no Kite, unit-testable) ------------------------
def simulate_symbol_day(symbol, day, bars, prev_close, trend_ok, P,
                        regime_block=False, atr=0.0):
    """Replay ONE symbol on ONE day. `bars` is an ordered list of dicts with
    keys ts(datetime), open, high, low, close, volume. Returns list[Trade].

    Mirrors elon_code: arm on a liquid dip below VWAP that isn't a knife, wait
    for the turn (tick up off the low), apply the completed-close trend filter,
    then exit on target / stop / (optional) time-stop / square-off. Intrabar we
    assume the STOP fills before the target (conservative)."""
    trades = []
    if prev_close <= 0 or not bars:
        return trades

    cum_pv = cum_v = 0.0
    day_low = float("inf")
    state = "IDLE"        # IDLE -> ARMED -> IN
    low_seen = None
    cycles = 0
    entry = stop = target = entry_ts = None

    def _exits_for(px):
        if P.atr_exits and atr > 0:
            return (round(px - P.atr_stop_mult * atr, 2),
                    round(px + P.atr_target_mult * atr, 2))
        return (round(px * (1 - P.stop / 100.0), 2),
                round(px * (1 + P.target / 100.0), 2))

    def _book(exit_px, reason):
        qty = max(1, int(P.notional / entry))
        gross = (exit_px - entry) * qty
        cost = P.cost_pct / 100.0 * entry * qty       # ~0.11% all-in round trip
        net = gross - cost
        risk = abs(entry - stop) * qty or 1.0
        trades.append(Trade(symbol, day, round(entry, 2), round(exit_px, 2), qty,
                            reason, round(gross, 2), round(cost, 2), round(net, 2),
                            round(net / risk, 2)))

    for b in bars:
        o, h, l, c, v = (b["open"], b["high"], b["low"], b["close"], b["volume"])
        ts = b["ts"]
        tp = (h + l + c) / 3.0 if (h and l and c) else c
        cum_pv += tp * (v or 0); cum_v += (v or 0)
        vwap = (cum_pv / cum_v) if cum_v > 0 else c
        day_low = min(day_low, l if l else c)
        hm = (ts.hour, ts.minute)
        in_entry_window = P.entry_before <= hm < P.entry_after
        in_squareoff = hm >= P.squareoff

        # 1) manage an open position first (exits win over new entries)
        if state == "IN":
            exit_px = reason = None
            if l and l <= stop:
                exit_px, reason = stop, "STOP"            # stop-first (conservative)
            elif h and h >= target:
                exit_px, reason = target, "TARGET"
            elif P.time_stop_min and (ts - entry_ts).total_seconds() / 60.0 >= P.time_stop_min:
                exit_px, reason = c, "TIME"
            elif in_squareoff:
                exit_px, reason = c, "SQUAREOFF"
            if reason:
                _book(exit_px, reason)
                state, low_seen, cycles = "IDLE", None, 0
                if reason in ("SQUAREOFF",):
                    break            # day is done
            continue

        if in_squareoff:
            continue                 # no new entries in the square-off window

        # 2) arm a fresh dip
        if state == "IDLE" and in_entry_window and not regime_block:
            day_change = (c - prev_close) / prev_close * 100.0
            below_vwap = (vwap - c) / vwap * 100.0 if vwap > 0 else 0.0
            turnover = c * cum_v
            if (below_vwap >= P.stretch_min and day_change <= 0
                    and day_change >= -P.knife and turnover >= P.min_turnover):
                state, low_seen, cycles = "ARMED", min(c, l if l else c), 0
            continue

        # 3) an armed setup: wait for the turn, then apply the trend filter
        if state == "ARMED":
            cycles += 1
            low_seen = min(low_seen, c)
            day_change = (c - prev_close) / prev_close * 100.0
            if day_change < -P.knife or c >= vwap or cycles >= P.arm_max_cycles:
                state, low_seen = "IDLE", None
                continue
            if c < low_seen * (1 + P.confirm / 100.0):
                continue             # not turned yet
            if P.trend_filter and not trend_ok:
                state, low_seen = "IDLE", None
                continue
            if not in_entry_window:
                state, low_seen = "IDLE", None
                continue
            entry, entry_ts = c, ts
            stop, target = _exits_for(c)
            state = "IN"

    # 4) never carry overnight: force-close anything still open at the last bar
    if state == "IN":
        _book(bars[-1]["close"], "FORCE_EOD")
    return trades


# --- aggregate stats ----------------------------------------------------------
def summarize(trades):
    if not trades:
        return {"trades": 0, "message": "no trades generated in this window"}
    nets = [t.net for t in trades]
    wins = [t for t in trades if t.net > 0]
    losses = [t for t in trades if t.net <= 0]
    gross = sum(t.gross for t in trades)
    net = sum(nets)
    gw = sum(t.net for t in wins)
    gl = -sum(t.net for t in losses)

    # equity curve by day -> max drawdown + rough daily Sharpe
    by_day = {}
    for t in trades:
        by_day[t.day] = by_day.get(t.day, 0.0) + t.net
    days = sorted(by_day)
    daily = [by_day[d] for d in days]
    equity, peak, mdd = 0.0, 0.0, 0.0
    for pnl in daily:
        equity += pnl
        peak = max(peak, equity)
        mdd = min(mdd, equity - peak)
    base = P_NOTIONAL_HINT or 1.0
    dret = [d / base for d in daily]
    sharpe = (mean(dret) / pstdev(dret) * (252 ** 0.5)) if len(dret) > 1 and pstdev(dret) > 1e-9 else 0.0

    return {
        "trades": len(trades),
        "win_rate_pct": len(wins) / len(trades) * 100.0,
        "gross": gross,
        "net": net,
        "cost_drag": gross - net,
        "expectancy_per_trade": net / len(trades),
        "avg_win": (gw / len(wins)) if wins else 0.0,
        "avg_loss": (-gl / len(losses)) if losses else 0.0,
        "profit_factor": (gw / gl) if gl > 0 else float("inf"),
        "avg_r": mean(t.r_multiple for t in trades),
        "max_drawdown": mdd,
        "sharpe_daily": sharpe,
        "days_traded": len(days),
    }


P_NOTIONAL_HINT = E.PER_TRADE_NOTIONAL   # denominator for the rough Sharpe


def print_report(stats, P):
    print("\n" + "=" * 64)
    print("  ELON CODE · BACKTEST REPORT  (paper — coarse minute-bar replay)")
    print("=" * 64)
    if stats["trades"] == 0:
        print(f"  {stats['message']}")
        print("=" * 64 + "\n")
        return
    tf = "ON" if P.trend_filter else "OFF"
    extra = []
    if P.time_stop_min:
        extra.append(f"time-stop {P.time_stop_min}m")
    if P.atr_exits:
        extra.append(f"ATR exits {P.atr_stop_mult}/{P.atr_target_mult}")
    cfg = f"target {P.target}% / stop {P.stop}% · trend-filter {tf}"
    if extra:
        cfg += " · " + ", ".join(extra)
    print(f"  Config              : {cfg}")
    print(f"  Cost per round trip : {P.cost_pct:.2f}% all-in")
    print("-" * 64)
    print(f"  Trades              : {stats['trades']}   over {stats['days_traded']} day(s)")
    print(f"  Win rate            : {stats['win_rate_pct']:.1f}%")
    print(f"  Net P&L             : Rs {stats['net']:,.0f}   (gross {stats['gross']:,.0f}, "
          f"costs -{stats['cost_drag']:,.0f})")
    print(f"  Expectancy / trade  : Rs {stats['expectancy_per_trade']:,.1f}   "
          f"(avg R {stats['avg_r']:+.2f})  <- the number that matters")
    print(f"  Avg win / avg loss  : Rs {stats['avg_win']:,.0f} / Rs {stats['avg_loss']:,.0f}")
    pf = stats["profit_factor"]
    print(f"  Profit factor       : {pf:.2f}" if pf != float("inf") else "  Profit factor       : inf (no losses)")
    print(f"  Max drawdown        : Rs {stats['max_drawdown']:,.0f}")
    print(f"  Sharpe (daily,rough): {stats['sharpe_daily']:.2f}")
    print("-" * 64)
    exp = stats["expectancy_per_trade"]
    verdict = ("POSITIVE expectancy after costs — worth walking forward on paper."
               if exp > 0 else
               "NEGATIVE expectancy after costs — do NOT risk money; tune or reject.")
    print(f"  VERDICT: {verdict}")
    print("=" * 64)
    print("  Coarse minute-bar test. Not advice. Validate live-paper before real money.\n")


# --- Kite data adapter (runs on the droplet, like elon_code) ------------------
def _trend_ok_from_daily(daily_closes_before, P):
    """Uptrend if the last COMPLETED close is above the trend SMA (same rule as
    the fixed live filter). `daily_closes_before` must EXCLUDE the test day."""
    if len(daily_closes_before) < P.trend_sma:
        return True   # fail-open, matches live
    sma = sum(daily_closes_before[-P.trend_sma:]) / P.trend_sma
    return daily_closes_before[-1] > sma


def run_kite_backtest(P, days, universe):
    kite = E.get_kite()
    print(f"[backtest] Kite session up. Universe={len(universe)} symbols, {days} day(s).")
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=days + P.trend_sma * 2 + 15)   # enough for the SMA
    all_trades = []
    for n, sym in enumerate(universe, 1):
        try:
            tok = E._TOKENS.get(sym) or kite.ltp([f"NSE:{sym}"]).get(f"NSE:{sym}", {}).get("instrument_token")
            if not tok:
                continue
            daily = kite.historical_data(tok, frm, to, "day")
            minutes = kite.historical_data(tok, to - dt.timedelta(days=days + 5), to, "minute")
            time.sleep(0.35)   # rate limit
        except Exception as e:
            print(f"  {sym}: history fetch failed ({e})")
            continue
        # group minute bars by day
        by_day = {}
        for m in minutes:
            d = str(m["date"])[:10]
            by_day.setdefault(d, []).append({
                "ts": m["date"], "open": m["open"], "high": m["high"],
                "low": m["low"], "close": m["close"], "volume": m.get("volume") or 0})
        daily_closes = [(str(d["date"])[:10], d["close"]) for d in daily]
        for d, bars in sorted(by_day.items()):
            before = [c for (dd, c) in daily_closes if dd < d]
            if not before:
                continue
            prev_close = before[-1]
            trend_ok = _trend_ok_from_daily(before, P)
            all_trades += simulate_symbol_day(sym, d, bars, prev_close, trend_ok, P)
        if n % 25 == 0:
            print(f"  ...{n}/{len(universe)} symbols processed, {len(all_trades)} trades so far")
    return all_trades


# --- offline self-test (proves the engine with zero Kite access) --------------
def _mk_bars(day, points):
    """points: list of (hh, mm, o, h, l, c, v) -> bar dicts."""
    return [{"ts": dt.datetime(2026, 6, 22, hh, mm), "open": o, "high": h,
             "low": l, "close": c, "volume": v} for (hh, mm, o, h, l, c, v) in points]


def selftest():
    P = Params()
    ok = True

    # Scenario 1: a clean dip below VWAP that turns and hits target -> 1 WIN.
    # prev_close 100; price opens ~99, dips to 97 (below vwap), ticks up (turn),
    # then rallies to the +1.5% target off the ~98 entry.
    bars = _mk_bars("2026-06-22", [
        (10, 0, 99.5, 99.6, 99.0, 99.2, 400000),
        (10, 1, 99.2, 99.2, 97.0, 97.05, 400000),  # deep dip below VWAP (low 97.0)
        (10, 2, 97.05, 97.2, 97.0, 97.1, 300000),  # basing at the low
        (10, 3, 97.1, 97.5, 97.05, 97.35, 300000), # TURN off 97.0, still BELOW VWAP -> entry 97.35
        (10, 4, 97.35, 99.9, 97.3, 99.8, 400000),  # rallies through the +1.5% target (~98.81)
    ])
    t1 = simulate_symbol_day("WINSTOCK", "2026-06-22", bars, 100.0, True, P)
    win_ok = len(t1) == 1 and t1[0].reason == "TARGET" and t1[0].net > 0
    print(f"  [1] uptrend dip -> target WIN         : {'PASS' if win_ok else 'FAIL'} "
          f"({[ (x.reason, x.net) for x in t1 ]})")
    ok &= win_ok

    # Scenario 2: a falling knife (down > KNIFE_PCT on the day) -> NO trade.
    bars = _mk_bars("2026-06-22", [
        (10, 0, 99.0, 99.0, 94.0, 94.0, 200000),   # -6% crash, below -KNIFE (4%)
        (10, 1, 94.0, 95.0, 93.0, 93.5, 200000),
        (10, 2, 93.5, 94.0, 93.0, 93.8, 150000),
    ])
    t2 = simulate_symbol_day("KNIFE", "2026-06-22", bars, 100.0, True, P)
    knife_ok = len(t2) == 0
    print(f"  [2] falling knife -> NO trade         : {'PASS' if knife_ok else 'FAIL'} "
          f"({len(t2)} trades)")
    ok &= knife_ok

    # Scenario 3: dip turns, enters, then falls to the stop -> 1 LOSS.
    bars = _mk_bars("2026-06-22", [
        (10, 0, 99.5, 99.6, 99.0, 99.2, 400000),
        (10, 1, 99.2, 99.2, 97.0, 97.05, 400000),
        (10, 2, 97.05, 97.2, 97.0, 97.1, 300000),
        (10, 3, 97.1, 97.5, 97.05, 97.35, 300000),  # turn -> entry 97.35 (stop ~96.57)
        (10, 4, 97.35, 97.4, 96.0, 96.1, 400000),   # falls through the -0.8% stop
    ])
    t3 = simulate_symbol_day("LOSER", "2026-06-22", bars, 100.0, True, P)
    loss_ok = len(t3) == 1 and t3[0].reason == "STOP" and t3[0].net < 0
    print(f"  [3] dip -> stop LOSS                  : {'PASS' if loss_ok else 'FAIL'} "
          f"({[ (x.reason, x.net) for x in t3 ]})")
    ok &= loss_ok

    # Scenario 4: identical good dip but trend_ok=False -> filter blocks entry.
    bars = _mk_bars("2026-06-22", [
        (10, 0, 99.5, 99.6, 99.0, 99.2, 400000),
        (10, 1, 99.2, 99.2, 97.0, 97.05, 400000),
        (10, 2, 97.05, 97.2, 97.0, 97.1, 300000),
        (10, 3, 97.1, 97.5, 97.05, 97.35, 300000),  # would turn+enter, but trend_ok=False
        (10, 4, 97.35, 99.9, 97.3, 99.8, 400000),
    ])
    t4 = simulate_symbol_day("DOWNTREND", "2026-06-22", bars, 100.0, False, P)
    filt_ok = len(t4) == 0
    print(f"  [4] trend filter blocks downtrend dip : {'PASS' if filt_ok else 'FAIL'} "
          f"({len(t4)} trades)")
    ok &= filt_ok

    # Scenario 5: stats aggregation sanity on the WIN + LOSS set.
    stats = summarize(t1 + t3)
    stats_ok = (stats["trades"] == 2 and abs(stats["win_rate_pct"] - 50.0) < 1e-6
                and stats["profit_factor"] > 0)
    print(f"  [5] summarize() aggregates correctly  : {'PASS' if stats_ok else 'FAIL'} "
          f"(win_rate={stats['win_rate_pct']:.0f}%, pf={stats['profit_factor']:.2f})")
    ok &= stats_ok

    print("\n" + ("✓ ALL SELF-TESTS PASSED — engine logic verified offline."
                  if ok else "✗ SELF-TEST FAILURES — do not trust results until fixed."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Backtest the ELON CODE mean-reversion bot.")
    ap.add_argument("--selftest", action="store_true", help="run offline engine tests (no Kite)")
    ap.add_argument("--days", type=int, default=20, help="lookback trading days for the real run")
    ap.add_argument("--universe", default=None, help="symbol file (default: elon_code's universe)")
    ap.add_argument("--target", type=float, default=None, help="override take-profit %%")
    ap.add_argument("--stop", type=float, default=None, help="override stop %%")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(0 if selftest() else 1)

    P = Params()
    if args.target is not None:
        P.target = args.target
    if args.stop is not None:
        P.stop = args.stop
    universe = (E.load_universe() if not args.universe
                else [l.strip().upper() for l in open(args.universe) if l.strip() and not l.startswith("#")])
    trades = run_kite_backtest(P, args.days, universe)
    print_report(summarize(trades), P)


if __name__ == "__main__":
    main()
