#!/usr/bin/env python3
"""
elon_swing.py  -  ELON SWING: "Buy fear in strong companies" (NRO-compliant)
============================================================================
Strategy 1 of the new Elon lanes. Built to fit the mindset:

  * THINK DIFFERENTLY: don't chase strength (the crowd). Buy a QUALITY stock the
    day it gets irrationally sold off -- while its long-term trend is still up --
    and let it snap back. Buy fear, not momentum.
  * NO FAILURES = NO BLOW-UPS (inversion / avoid-losing first):
      - long-term trend intact (close > 200-DMA) -> not a dying company
      - buy only a SHARP oversold dip (RSI(2) < threshold, below the 5-DMA)
      - skip 1-day crashes (news disasters) -> not a falling knife
      - HARD stop set before entry -> every loss is small and pre-decided
      - only when the broad market itself is in an uptrend (regime)
      - if nothing qualifies, HOLD CASH. Cash is a position.

  * NRO-COMPLIANT: cash equity, DELIVERY (CNC) only. No intraday/MIS, no
    shorting. Buy at the next day's OPEN (signal at close -> no look-ahead),
    hold several days, exit on reversion / stop / time. Paper == live, no
    account conflict when you flip the switch.

HONESTY: real delivery round-trip cost (~0.30% all-in, STT-heavy), a date-based
TRAIN/VALIDATE split (a strategy only earns trust if it's positive on data it
was NOT fitted to), and a Monte Carlo bootstrap. A green backtest is a
hypothesis to live-paper, never a promise.

USAGE
  python3 elon_swing.py --selftest                 # offline engine tests (no Kite)
  python3 elon_swing.py --days 250                  # ~1yr daily backtest, full universe
  python3 elon_swing.py --days 250 --universe /tmp/mini.txt
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
from elon_backtest import Trade, summarize                  # noqa: E402


@dataclass
class SwingP:
    rsi_period: int = int(os.environ.get("EQS_RSI_PERIOD", "2"))
    rsi_buy: float = float(os.environ.get("EQS_RSI_BUY", "10"))     # "fear" trigger
    sma_trend: int = int(os.environ.get("EQS_SMA_TREND", "200"))    # quality/trend filter
    sma_exit: int = int(os.environ.get("EQS_SMA_EXIT", "5"))        # reversion exit
    stop_pct: float = float(os.environ.get("EQS_STOP_PCT", "6"))    # hard controlled loss
    max_hold: int = int(os.environ.get("EQS_MAX_HOLD", "10"))       # trading days
    knife_pct: float = float(os.environ.get("EQS_KNIFE_PCT", "8"))  # skip 1-day crashes
    cost_pct: float = float(os.environ.get("EQS_COST_PCT", "0.30")) # delivery all-in round trip
    notional: float = float(os.environ.get("EQS_NOTIONAL", "100000"))
    use_regime: bool = os.environ.get("EQS_USE_REGIME", "1").strip() == "1"


# --- tiny indicators ---------------------------------------------------------
def _sma(vals, n):
    return sum(vals[-n:]) / n if len(vals) >= n else None


def _rsi(closes, n):
    """Simple RSI over the last n deltas (n=2 -> very responsive to sharp dips)."""
    if len(closes) < n + 1:
        return None
    deltas = [closes[i] - closes[i - 1] for i in range(len(closes) - n, len(closes))]
    gain = sum(d for d in deltas if d > 0) / n
    loss = -sum(d for d in deltas if d < 0) / n
    if loss == 0:
        return 100.0
    rs = gain / loss
    return 100.0 - 100.0 / (1.0 + rs)


def _book(sym, day, entry, exit_px, reason, P, stop):
    qty = max(1, int(P.notional / entry))
    gross = (exit_px - entry) * qty
    cost = P.cost_pct / 100.0 * entry * qty            # delivery all-in round trip
    net = gross - cost
    risk = abs(entry - stop) * qty or 1.0
    return Trade(sym, day, round(entry, 2), round(exit_px, 2), qty, reason,
                 round(gross, 2), round(cost, 2), round(net, 2), round(net / risk, 2))


# --- the pure simulation core (daily bars, unit-testable) --------------------
def simulate_symbol_swing(sym, bars, P, regime_ok=None):
    """Replay ONE symbol over its daily OHLC series. `bars` = ordered list of
    dicts {date, open, high, low, close}. Returns list[Trade].

    Signal is measured at day t's CLOSE; entry is day t+1's OPEN (no look-ahead).
    regime_ok: optional {date_str: bool}; if given, new entries need regime True."""
    n = len(bars)
    if n < P.sma_trend + 2:
        return []
    closes = [b["close"] for b in bars]
    trades = []
    pos = None
    t = P.sma_trend
    while t < n - 1:
        if pos is None:
            c = closes[:t + 1]
            sma200 = _sma(c, P.sma_trend)
            sma5 = _sma(c, P.sma_exit)
            r = _rsi(c, P.rsi_period)
            if None in (sma200, sma5, r) or closes[t - 1] <= 0:
                t += 1; continue
            day_ret = (closes[t] - closes[t - 1]) / closes[t - 1] * 100.0
            date = str(bars[t]["date"])[:10]
            reg = True if regime_ok is None else regime_ok.get(date, True)
            # BUY FEAR: uptrend intact, sharply oversold, below short MA, not a
            # crash, market healthy.
            if (closes[t] > sma200 and r < P.rsi_buy and closes[t] < sma5
                    and day_ret > -P.knife_pct and reg):
                entry = bars[t + 1]["open"]
                if entry and entry > 0:
                    pos = {"idx": t + 1, "entry": entry,
                           "stop": entry * (1 - P.stop_pct / 100.0),
                           "date": str(bars[t + 1]["date"])[:10]}
                    t += 1; continue
            t += 1
        else:
            b = bars[t]
            held = t - pos["idx"]
            reason = exit_px = None
            if b["low"] <= pos["stop"]:                 # hard stop first (conservative)
                reason, exit_px = "STOP", pos["stop"]
            else:
                sma5 = _sma(closes[:t + 1], P.sma_exit)
                if sma5 is not None and closes[t] >= sma5:   # reverted -> take it
                    reason, exit_px = "REVERT", closes[t]
                elif held >= P.max_hold:                     # thesis stalled -> free capital
                    reason, exit_px = "TIME", closes[t]
            if reason:
                trades.append(_book(sym, pos["date"], pos["entry"], exit_px, reason, P, pos["stop"]))
                pos = None
            t += 1
    if pos is not None:                                 # never leave it open past the data
        trades.append(_book(sym, pos["date"], pos["entry"], closes[-1], "EOD", P, pos["stop"]))
    return trades


# --- Monte Carlo robustness --------------------------------------------------
def monte_carlo(trades, iters=2000):
    nets = [t.net for t in trades]
    if len(nets) < 5:
        return None
    totals = sorted(sum(random.choice(nets) for _ in range(len(nets))) for _ in range(iters))
    return {"p_loss_pct": sum(1 for x in totals if x < 0) / iters * 100.0,
            "p05": totals[int(0.05 * iters)], "median": totals[iters // 2]}


# --- Kite data (daily bars; 1 call/symbol -> fast) ---------------------------
def _regime_map(kite, P, days):
    """{date: NIFTY-above-200DMA} so we only buy dips in a healthy market."""
    try:
        tok = E.KiteDataSource._INDEX_TOKENS.get(E.REGIME_INDEX.split(":")[-1]) \
            if hasattr(E, "KiteDataSource") else None
    except Exception:
        tok = None
    # elon_code has no index-token map; use a known NIFTY 50 token.
    tok = tok or 256265  # NSE:NIFTY 50 instrument_token
    try:
        to = dt.datetime.now()
        frm = to - dt.timedelta(days=days + 320)
        bars = kite.historical_data(tok, frm, to, "day")
    except Exception as e:
        print(f"[swing] regime fetch failed ({e}) -> regime filter OFF (fail-open)")
        return None
    closes = [b["close"] for b in bars]
    out = {}
    for i in range(len(bars)):
        if i >= 200:
            sma = sum(closes[i - 200:i]) / 200
            out[str(bars[i]["date"])[:10]] = closes[i] > sma
    return out


def run_swing(P, days, universe):
    E._load_env()
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[swing] Kite login failed: {e}\n  -> source /home/globalbot/.env first.")
        return
    regime = _regime_map(kite, P, days) if P.use_regime else None
    print(f"[swing] Kite up. Universe={len(universe)}, ~{days}d daily bars "
          f"(regime filter {'ON' if regime else 'OFF'}).")
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=days + 320)          # +320 cal days warms up the 200-DMA
    all_trades = []
    for i, sym in enumerate(universe, 1):
        try:
            tok = E._TOKENS.get(sym) or kite.ltp([f"NSE:{sym}"]).get(f"NSE:{sym}", {}).get("instrument_token")
            if not tok:
                continue
            bars = kite.historical_data(tok, frm, to, "day")
            time.sleep(0.3)
        except Exception as e:
            print(f"  {sym}: fetch failed ({e})")
            continue
        all_trades += simulate_symbol_swing(sym, bars, P, regime)
        if i % 50 == 0:
            print(f"  ...{i}/{len(universe)} symbols, {len(all_trades)} trades so far")

    if not all_trades:
        print("[swing] no trades generated.")
        return
    days_sorted = sorted({t.day for t in all_trades})
    cut = days_sorted[int(len(days_sorted) * 0.7)] if len(days_sorted) >= 4 else days_sorted[-1]
    train = [t for t in all_trades if t.day < cut]
    val = [t for t in all_trades if t.day >= cut]
    _report(summarize(all_trades), summarize(train), summarize(val),
            monte_carlo(all_trades), cut, P)
    return all_trades


def _report(all_s, tr_s, val_s, mc, cut, P):
    def line(lbl, s):
        if not s or s.get("trades", 0) == 0:
            print(f"  {lbl:16}: no trades"); return
        pf = s["profit_factor"]
        pf = f"{pf:.2f}" if pf != float("inf") else "inf"
        print(f"  {lbl:16}: {s['trades']:>4} trades | win {s['win_rate_pct']:.1f}% | "
              f"exp/trade Rs {s['expectancy_per_trade']:+.0f} | net Rs {s['net']:+,.0f} | PF {pf}")
    print("\n" + "=" * 72)
    print("  ELON SWING · 'BUY FEAR IN STRONG COMPANIES'  (NRO delivery — paper)")
    print("=" * 72)
    print(f"  Rules : buy RSI({P.rsi_period})<{P.rsi_buy:.0f} dip while close>{P.sma_trend}-DMA, "
          f"exit>{P.sma_exit}-DMA / -{P.stop_pct:.0f}% stop / {P.max_hold}d")
    print(f"  Cost  : {P.cost_pct:.2f}% delivery round trip     Regime split at {cut}")
    print("-" * 72)
    line("ALL", all_s)
    line("TRAIN (in-sample)", tr_s)
    line("VALIDATE (OOS)", val_s)
    if all_s.get("trades"):
        print(f"  Max drawdown    : Rs {all_s['max_drawdown']:,.0f}   "
              f"Sharpe(daily,rough) {all_s['sharpe_daily']:.2f}")
    if mc:
        print(f"  Monte Carlo     : P(loss) {mc['p_loss_pct']:.0f}% | 5th pct Rs {mc['p05']:,.0f} | "
              f"median Rs {mc['median']:,.0f}")
    print("-" * 72)
    va = val_s.get("expectancy_per_trade") if val_s.get("trades") else None
    aa = all_s.get("expectancy_per_trade") if all_s.get("trades") else None
    if va is not None and va > 0 and aa and aa > 0:
        v = "CANDIDATE — positive IN-sample AND OUT-of-sample. Worth live-paper."
    elif aa and aa > 0:
        v = "FRAGILE — positive overall but NOT out-of-sample (likely curve-fit). Do not trust."
    else:
        v = "REJECT — negative expectancy after costs. Do NOT risk money."
    print(f"  VERDICT: {v}")
    print("=" * 72)
    print("  Coarse daily-bar test, NRO delivery. Not advice. Live-paper before real money.\n")


# --- offline self-test -------------------------------------------------------
def _series(closes):
    """Build daily bars from a close list (open=prev close, small H/L wedge)."""
    bars = []
    for i, c in enumerate(closes):
        o = closes[i - 1] if i else c
        hi = max(o, c) * 1.005
        lo = min(o, c) * 0.995
        bars.append({"date": dt.date(2026, 1, 1) + dt.timedelta(days=i),
                     "open": round(o, 2), "high": round(hi, 2),
                     "low": round(lo, 2), "close": round(c, 2)})
    return bars


def selftest():
    P = SwingP()
    ok = True

    # 1) UPTREND + sharp oversold dip that recovers -> one WIN (REVERT).
    up = [100 + i * 0.25 for i in range(210)]          # steady uptrend, price ~ 152 > 200DMA
    up += [up[-1] * 0.96, up[-1] * 0.93]               # 2-day sharp dip -> RSI(2) collapses
    up += [up[-3] * 0.99, up[-3] * 1.01, up[-3] * 1.02]  # recovery back above the 5-DMA
    t1 = simulate_symbol_swing("UPDIP", _series(up), P)
    win_ok = len(t1) >= 1 and t1[0].reason in ("REVERT", "TIME") and t1[0].net > 0
    print(f"  [1] uptrend dip -> recover WIN       : {'PASS' if win_ok else 'FAIL'} "
          f"({[(x.reason, x.net) for x in t1]})")
    ok &= win_ok

    # 2) DOWNTREND (below 200-DMA) dip -> NO trade (quality/trend filter blocks).
    down = [200 - i * 0.4 for i in range(210)]         # steady downtrend
    down += [down[-1] * 0.96, down[-1] * 0.93, down[-1] * 0.95]
    t2 = simulate_symbol_swing("DOWNDIP", _series(down), P)
    print(f"  [2] downtrend dip -> NO trade        : {'PASS' if len(t2)==0 else 'FAIL'} ({len(t2)})")
    ok &= (len(t2) == 0)

    # 3) uptrend dip that keeps falling -> one LOSS at the hard stop.
    up2 = [100 + i * 0.25 for i in range(210)]
    up2 += [up2[-1] * 0.96, up2[-1] * 0.93]            # oversold -> entry
    up2 += [up2[-1] * 0.90, up2[-1] * 0.85, up2[-1] * 0.82]  # keeps crashing -> stop
    t3 = simulate_symbol_swing("KEEPFALL", _series(up2), P)
    loss_ok = len(t3) >= 1 and t3[0].reason == "STOP" and t3[0].net < 0
    print(f"  [3] dip keeps falling -> STOP LOSS   : {'PASS' if loss_ok else 'FAIL'} "
          f"({[(x.reason, x.net) for x in t3]})")
    ok &= loss_ok

    # 4) Monte Carlo aggregates.
    mc = monte_carlo(t1 + t3 + [Trade("X", "d", 100, 99, 10, "STOP", -10, 1, -11, -1)] * 6)
    print(f"  [4] Monte Carlo produces stats       : {'PASS' if mc else 'FAIL'} "
          f"({'p_loss=%.0f%%' % mc['p_loss_pct'] if mc else 'none'})")
    ok &= (mc is not None)

    print("\n" + ("✓ ALL SELF-TESTS PASSED — swing engine verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Elon Swing: buy fear in strong companies (NRO delivery).")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--days", type=int, default=250)
    ap.add_argument("--universe", default=None)
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    universe = (E.load_universe() if not args.universe
                else [l.strip().upper() for l in open(args.universe)
                      if l.strip() and not l.startswith("#")])
    run_swing(SwingP(), args.days, universe)


if __name__ == "__main__":
    main()
