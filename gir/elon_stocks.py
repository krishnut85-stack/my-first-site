#!/usr/bin/env python3
"""
elon_stocks.py  -  ELON Strategy 2: SECTOR-LEADERS MOMENTUM (two-stage, NRO)
============================================================================
Buys the 1-2 real runners inside the strong sectors -- not the sector average
(ETF), and NOT the mega-caps (research: momentum is ~zero in the largest-cap
class; it lives in smaller, less-covered stocks).

TWO STAGES (top-down then bottom-up, per the user + the literature):
  1. STRONG SECTORS: each sector's strength = the average blended momentum of
     its liquid member stocks; keep the TOP 5 (only in a healthy market).
  2. SECTOR LEADERS: inside each strong sector, take the TOP 2 stocks by
     momentum -> 5 x 2 = ~10 holdings, equal weight.

UNIVERSE: mid + small (+ liquid micro) caps, EXCLUDING the Nifty 50 mega-caps.
A daily-TURNOVER floor keeps only names we can actually buy and EXIT (this
auto-drops illiquid micro-caps -- correct, since illiquid momentum isn't real).

RISK: 200-DMA regime -> cash in bear markets; 10 names diversify single-stock
news-gap risk; a per-stock stop-loss is added in the LIVE engine (NOT modelled
here, so these numbers are conservative, not flattered).

HONEST TEST: monthly returns vs a buy-&-hold Nifty benchmark, TRAIN/VALIDATE
date split, Monte Carlo. Must beat the index out-of-sample to be a candidate.
NRO-legal: plain delivery (CNC) stocks.

DATA (upload via Termius): drop your CSVs into --dir (default
/home/globalbot/data/elon2/). ANY filename works -- every *.csv there is read
and combined -- e.g. 500.csv, mid.csv, micro.csv. Each CSV MUST have a Symbol
column AND an Industry/Sector column (NSE constituent lists or Trendlyne
exports). Nifty 50 mega-caps are auto-excluded.

USAGE
  python3 elon_stocks.py --selftest
  python3 elon_stocks.py --days 2000 --dir /home/globalbot/data/elon2
"""

import os
import sys
import csv
import glob
import time
import argparse
import datetime as dt
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import elon_code as E                                       # noqa: E402
from elon_momentum import stats, monte_carlo, _hist_chunked  # noqa: E402


@dataclass
class StockP:
    top_sectors: int = int(os.environ.get("EQS2_TOP_SECTORS", "5"))
    per_sector: int = int(os.environ.get("EQS2_PER_SECTOR", "2"))
    lookbacks: tuple = (3, 6, 12)
    abs_lookback: int = 12
    min_turnover: float = float(os.environ.get("EQS2_MIN_TURNOVER", "50000000"))  # ~5cr/day
    cost_pct: float = float(os.environ.get("EQS2_COST_PCT", "0.20"))   # per side (small/mid: wide)
    cash_annual: float = float(os.environ.get("EQS2_CASH_ANNUAL", "0.06"))
    use_regime: bool = os.environ.get("EQS2_USE_REGIME", "1").strip() == "1"
    benchmark: str = "NIFTY 50"


_SYMBOL_COLS = ("symbol", "nse code", "nsecode", "nse symbol", "tradingsymbol", "ticker")
_IND_COLS = ("industry", "sector", "sub sector", "macro sector")


def load_universe(dirpath):
    """Combine every CSV in dirpath into {symbol: sector}, EXCLUDING Nifty 50
    mega-caps. Needs a Symbol column + an Industry/Sector column."""
    excl = {s.upper() for s in getattr(E, "FALLBACK_UNIVERSE", [])}   # ~Nifty 50
    uni = {}
    files = sorted(glob.glob(os.path.join(dirpath, "*.csv")))
    for path in files:
        try:
            with open(path, newline="", encoding="utf-8", errors="ignore") as f:
                rd = csv.DictReader(f)
                cols = {(c or "").lower().strip(): c for c in (rd.fieldnames or [])}
                sc = next((cols[c] for c in _SYMBOL_COLS if c in cols), None)
                ic = next((cols[c] for c in _IND_COLS if c in cols), None)
                if not sc or not ic:
                    print(f"  skip {os.path.basename(path)} (need Symbol + Industry cols)")
                    continue
                n = 0
                for r in rd:
                    sym = (r.get(sc) or "").strip().upper()
                    sec = (r.get(ic) or "").strip()
                    if sym and sec and sym not in excl:
                        uni[sym] = sec
                        n += 1
                print(f"  loaded {n} from {os.path.basename(path)}")
        except OSError as e:
            print(f"  {path}: {e}")
    return uni


# --- per-stock momentum (same blended logic as the sector strategy) ----------
def stock_scores(monthly, months, i, P, syms):
    scores, absm = {}, {}
    for s in syms:
        c = monthly.get(s)
        m = months[i]
        if not c or m not in c:
            continue
        if all(months[i - lb] in c for lb in P.lookbacks):
            rs = [c[m] / c[months[i - lb]] - 1 for lb in P.lookbacks if c[months[i - lb]] > 0]
            if len(rs) == len(P.lookbacks):
                scores[s] = sum(rs) / len(rs)
        base = c.get(months[i - P.abs_lookback], 0)
        absm[s] = (c[m] / base - 1) if base > 0 else -1.0
    return scores, absm


def select_stocks(scores, absm, turnover_m, sector_map, regime, P):
    """Two-stage pick. turnover_m: {sym: this-month avg daily turnover}."""
    if not regime:
        return []
    cand = [s for s in scores if absm.get(s, -1) > 0
            and turnover_m.get(s, 0) >= P.min_turnover]
    by_sec = {}
    for s in cand:
        by_sec.setdefault(sector_map.get(s, "UNKNOWN"), []).append(s)
    # sector strength = mean stock momentum; need at least `per_sector` names
    strength = {sec: sum(scores[s] for s in mem) / len(mem)
                for sec, mem in by_sec.items() if len(mem) >= P.per_sector}
    top = [sec for sec in sorted(strength, key=strength.get, reverse=True)
           if strength[sec] > 0][:P.top_sectors]
    picks = []
    for sec in top:
        mem = sorted(by_sec[sec], key=scores.get, reverse=True)
        picks += mem[:P.per_sector]
    return picks


# --- backtest ----------------------------------------------------------------
def backtest(monthly, turnover, sector_map, regime_ok, months, P):
    lb_max = max(P.lookbacks + (P.abs_lookback,))
    syms = [s for s in monthly if s != P.benchmark]
    strat, bench, dates = [], [], []
    prev = set()
    cash_m = (1 + P.cash_annual) ** (1 / 12.0) - 1
    for i in range(lb_max, len(months) - 1):
        m, nxt = months[i], months[i + 1]
        reg = regime_ok.get(m, True) if P.use_regime else True
        scores, absm = stock_scores(monthly, months, i, P, syms)
        turnover_m = {s: turnover.get(s, {}).get(m, 0) for s in scores}
        picks = select_stocks(scores, absm, turnover_m, sector_map, reg, P)
        # next-month return, equal weight; empty slots (fewer than target) -> cash
        target = P.top_sectors * P.per_sector
        rets = []
        for s in picks:
            c = monthly[s]
            if m in c and nxt in c and c[m] > 0:
                rets.append(c[nxt] / c[m] - 1)
        held = len(rets)
        gross = (sum(rets) + (target - held) * cash_m) / target if target else cash_m
        cur = set(picks)
        turnover_frac = len(cur ^ prev) / target if target else 0     # symmetric diff / N
        cost = turnover_frac * P.cost_pct / 100.0
        strat.append(gross - cost)
        b = monthly.get(P.benchmark)
        bench.append((b[nxt] / b[m] - 1) if (b and m in b and nxt in b and b[m] > 0) else 0.0)
        dates.append(nxt); prev = cur
    return dates, strat, bench


# --- Kite fetch: daily -> monthly close + monthly turnover -------------------
def _monthly_close_turnover(bars):
    close, tsum, tcnt = {}, {}, {}
    for b in bars:
        mk = str(b["date"])[:7]
        close[mk] = b["close"]                        # month-end close
        tv = (b["close"] or 0) * (b.get("volume") or 0)
        tsum[mk] = tsum.get(mk, 0) + tv
        tcnt[mk] = tcnt.get(mk, 0) + 1
    turn = {mk: tsum[mk] / tcnt[mk] for mk in tsum}    # avg daily turnover that month
    return close, turn


def _regime_by_month(bars, sma=200):
    closes = [b["close"] for b in bars]
    out = {}
    for i in range(len(bars)):
        if i >= sma:
            out[str(bars[i]["date"])[:7]] = closes[i] > sum(closes[i - sma:i]) / sma
    return out


def fetch(P, days, sector_map):
    E._load_env()
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[stocks] Kite login failed: {e}\n  -> source /home/globalbot/.env first.")
        return None, None, None
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=days + 400)
    syms = list(sector_map) + [P.benchmark]
    monthly, turnover, regime = {}, {}, {}
    print(f"[stocks] Kite up. Fetching {len(syms)} symbols (this is the slow part)...")
    for n, s in enumerate(syms, 1):
        try:
            tok = E._TOKENS.get(s) or kite.ltp([f"NSE:{s}"]).get(f"NSE:{s}", {}).get("instrument_token")
            if not tok:
                continue
            bars = _hist_chunked(kite, tok, frm, to, "day")
            if not bars:
                continue
            c, t = _monthly_close_turnover(bars)
            monthly[s] = c
            turnover[s] = t
            if s == P.benchmark:
                regime = _regime_by_month(bars)
            time.sleep(0.25)
        except Exception as e:
            print(f"  {s}: {e}")
        if n % 100 == 0:
            print(f"  ...{n}/{len(syms)} fetched")
    return monthly, turnover, regime


def _report(dates, strat, bench, P, nstocks, nsectors):
    if not strat:
        print("[stocks] no returns produced."); return
    cut = len(dates) * 7 // 10
    print("\n" + "=" * 76)
    print("  ELON STRATEGY 2 · SECTOR-LEADERS MOMENTUM  (mid/small-cap, NRO delivery)")
    print("=" * 76)
    print(f"  Rules: top {P.top_sectors} sectors x top {P.per_sector} stocks = "
          f"{P.top_sectors*P.per_sector} names; blended {P.lookbacks} mth momentum; "
          f">Rs {P.min_turnover/1e7:.1f}cr/day; Nifty>200DMA else cash. Monthly.")
    print(f"  Universe: {nstocks} stocks across {nsectors} sectors (Nifty 50 excluded). "
          f"Cost {P.cost_pct:.2f}%/side")
    print("-" * 76)

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
        print(f"  Monte Carlo: P(loss) {mc['p_loss_pct']:.0f}% | 5th pct {mc['p05_pct']:+.0f}% | "
              f"median {mc['median_pct']:+.0f}%")
    print("-" * 76)
    a_s, a_b = stats(strat), stats(bench)
    v_s, v_b = stats(strat[cut:]), stats(bench[cut:])
    beats_all = a_s["sharpe"] > a_b["sharpe"] and a_s["cagr_pct"] > 0
    beats_oos = v_s and v_b and v_s["sharpe"] > v_b["sharpe"] and v_s["cagr_pct"] > 0
    if beats_all and beats_oos:
        v = "CANDIDATE — beats buy-&-hold Nifty on Sharpe IN- and OUT-of-sample. Build the live engine."
    elif beats_all:
        v = "MARGINAL — beats overall but not out-of-sample. Caution / more data."
    else:
        v = "REJECT — does not beat holding the Nifty. Not worth the single-stock risk."
    print(f"  VERDICT: {v}")
    print("=" * 76)
    print("  Coarse monthly test; per-stock stop-loss NOT modelled (live adds it). Not advice.\n")


def run(P, days, dirpath):
    sector_map = load_universe(dirpath)
    if not sector_map:
        print(f"[stocks] no universe loaded from {dirpath}. Upload CSVs (Symbol+Industry) there.")
        return
    nsectors = len(set(sector_map.values()))
    print(f"[stocks] universe: {len(sector_map)} stocks across {nsectors} sectors.")
    monthly, turnover, regime = fetch(P, days, sector_map)
    if not monthly:
        return
    months = sorted({m for c in monthly.values() for m in c})
    dates, strat, bench = backtest(monthly, turnover, sector_map, regime, months, P)
    _report(dates, strat, bench, P, len(sector_map), nsectors)
    return dates, strat, bench


# --- offline self-test (no Kite) ---------------------------------------------
def selftest():
    P = StockP(); P.top_sectors = 1; P.per_sector = 2; P.min_turnover = 0
    ok = True

    # Stage logic: sector A stocks strong, sector B weak -> pick A's top 2.
    scores = {"A1": 0.30, "A2": 0.25, "A3": 0.05, "B1": 0.02, "B2": 0.01}
    absm = {k: 0.2 for k in scores}
    smap = {"A1": "SECA", "A2": "SECA", "A3": "SECA", "B1": "SECB", "B2": "SECB"}
    turn = {k: 1e9 for k in scores}
    picks = select_stocks(scores, absm, turn, smap, True, P)
    ok1 = set(picks) == {"A1", "A2"}
    print(f"  [1] top sector -> its top 2 stocks   : {'PASS' if ok1 else 'FAIL'} ({picks})")
    ok &= ok1

    # Regime OFF -> nothing.
    ok2 = select_stocks(scores, absm, turn, smap, False, P) == []
    print(f"  [2] regime OFF -> no picks (cash)    : {'PASS' if ok2 else 'FAIL'}")
    ok &= ok2

    # Liquidity filter drops an illiquid leader.
    turn2 = dict(turn); turn2["A1"] = 0
    picks3 = select_stocks(scores, absm, turn2, smap, True, StockP(top_sectors=1, per_sector=2, min_turnover=1e6))
    ok3 = "A1" not in picks3 and set(picks3) == {"A2", "A3"}
    print(f"  [3] illiquid leader filtered out     : {'PASS' if ok3 else 'FAIL'} ({picks3})")
    ok &= ok3

    # Negative absolute momentum excluded.
    absm4 = dict(absm); absm4["A1"] = -0.1
    picks4 = select_stocks(scores, absm4, turn, smap, True, P)
    ok4 = "A1" not in picks4
    print(f"  [4] falling stock (abs<0) excluded   : {'PASS' if ok4 else 'FAIL'} ({picks4})")
    ok &= ok4

    # Backtest wiring: 2 sectors over months, A trends up -> positive, beats flat.
    months = [f"20{y:02d}-{mo:02d}" for y in range(20, 24) for mo in range(1, 13)]
    up = {mm: round(100 * (1.02 ** i), 3) for i, mm in enumerate(months)}
    dn = {mm: round(100 * (0.99 ** i), 3) for i, mm in enumerate(months)}
    flat = {mm: 100.0 for mm in months}
    monthly = {"A1": up, "A2": up, "B1": dn, "B2": dn, "NIFTY 50": flat}
    turnover = {s: {mm: 1e9 for mm in months} for s in monthly}
    regime = {mm: True for mm in months}
    P2 = StockP(top_sectors=1, per_sector=2, min_turnover=0)
    smap2 = {"A1": "SECA", "A2": "SECA", "B1": "SECB", "B2": "SECB"}
    _, strat, bench = backtest(monthly, turnover, smap2, regime, months, P2)
    ok5 = stats(strat)["total_pct"] > stats(bench)["total_pct"]
    print(f"  [5] backtest picks winners > bench   : {'PASS' if ok5 else 'FAIL'} "
          f"(strat {stats(strat)['total_pct']:+.0f}% vs {stats(bench)['total_pct']:+.0f}%)")
    ok &= ok5

    print("\n" + ("✓ ALL SELF-TESTS PASSED — sector-leaders engine verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Elon Strategy 2: sector-leaders momentum (NRO).")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--days", type=int, default=2000)
    ap.add_argument("--dir", default=os.environ.get("EQS2_DIR", "/home/globalbot/data/elon2"))
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    run(StockP(), args.days, args.dir)


if __name__ == "__main__":
    main()
