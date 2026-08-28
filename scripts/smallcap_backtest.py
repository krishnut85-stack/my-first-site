#!/usr/bin/env python3
"""
SMALLCAP FRAMEWORK BACKTESTER
=============================
Backtests the technical/momentum/risk layer of the small-cap swing framework
(smallcap_framework.py) on NSE daily data via yfinance.

WHAT THIS TESTS:   breakout entry, RS-rank selection, regime gate, ATR stops,
                   3R scale-out, chandelier trail, momentum-weakness exit,
                   time stop, portfolio heat / sizing rules, realistic costs.
WHAT IT CANNOT TEST (results are therefore an UPPER BOUND):
  - Survivorship bias: universe = CURRENT index constituents (survivors only)
  - Fundamental screen (no free point-in-time fundamentals)
  - ASM/GSM & circuit-band history (approximated by liquidity filter)

USAGE (droplet):
    pip3 install yfinance pandas numpy --break-system-packages  # (or plain pip3)
    # Option A: auto-download current Nifty Smallcap 250 list
    python3 smallcap_backtest.py --start 2019-01-01
    # Option B: your own universe CSV (column: Symbol, optional: Industry)
    python3 smallcap_backtest.py --universe my_universe.csv --start 2019-01-01
    # Engine self-test on synthetic data (no internet needed):
    python3 smallcap_backtest.py --selftest

OUTPUTS:  ./bt_out/trades.csv  bt_out/equity_curve.csv  bt_out/report.txt
"""

import argparse, math, os, sys, io
from dataclasses import dataclass
from datetime import datetime

import numpy as np
import pandas as pd

# ============================ CONFIG ============================

@dataclass
class Cfg:
    start: str = "2019-01-01"
    end: str = None                    # None = today
    initial_equity: float = 1_000_000.0

    # universe / liquidity (proxy for the live surveillance filters)
    min_price: float = 30.0
    min_adv_cr: float = 2.0            # 20d median traded value >= ₹2 cr
    min_history_days: int = 260

    # momentum selection
    rs_lookbacks: tuple = (63, 126)
    rs_top_quantile: float = 0.20
    sector_top_n: int = 4              # used only if Industry column present
    sector_lookback: int = 63

    # regime
    regime_ma: int = 200               # EW universe index vs 200 DMA

    # entry
    breakout_lb: int = 55
    vol_mult: float = 1.75
    max_gap_up: float = 0.03
    max_ext_50: float = 0.15
    rsi_floor: float = 50.0
    rsi_ceiling: float = 78.0

    # sizing / portfolio
    risk_per_trade: float = 0.01
    max_pos_pct: float = 0.10
    max_pct_adv: float = 0.05
    max_positions: int = 8
    max_heat: float = 0.06

    # stops / exits
    atr_n: int = 14
    stop_atr: float = 2.0
    stop_max_pct: float = 0.08
    scale_r: float = 3.0
    scale_frac: float = 0.5
    trail_atr: float = 3.0
    momo_rsi: float = 45.0
    time_days: int = 30
    time_min_gain: float = 0.05

    # costs (per side): STT 0.1% + charges ~0.03% + slippage 0.3%
    cost_side: float = 0.0043

UNIVERSE_URL = ("https://www.niftyindices.com/IndexConstituent/"
                "ind_niftysmallcap250list.csv")

# ============================ INDICATORS ============================

def wilder_ema(s: pd.Series, n: int) -> pd.Series:
    return s.ewm(alpha=1.0 / n, adjust=False).mean()

def add_indicators(df: pd.DataFrame, cfg: Cfg) -> pd.DataFrame:
    c, h, l, v = df["Close"], df["High"], df["Low"], df["Volume"]
    out = df.copy()
    out["ema50"] = c.ewm(span=50, adjust=False).mean()
    out["ema200"] = c.ewm(span=200, adjust=False).mean()
    # ATR (Wilder)
    tr = pd.concat([h - l, (h - c.shift()).abs(), (l - c.shift()).abs()],
                   axis=1).max(axis=1)
    out["atr"] = wilder_ema(tr, cfg.atr_n)
    # RSI (Wilder)
    d = c.diff()
    gain = wilder_ema(d.clip(lower=0), 14)
    loss = wilder_ema((-d).clip(lower=0), 14)
    rs = gain / loss.replace(0, np.nan)
    out["rsi"] = 100 - 100 / (1 + rs)
    # MACD 12/26/9
    macd = c.ewm(span=12, adjust=False).mean() - c.ewm(span=26, adjust=False).mean()
    out["macd"] = macd
    out["macds"] = macd.ewm(span=9, adjust=False).mean()
    # breakout ref & volume
    out["hh"] = c.shift(1).rolling(cfg.breakout_lb).max()
    out["vavg20"] = v.rolling(20).mean()
    out["adv_val"] = (c * v).rolling(20).median()
    # returns for RS
    for lb in cfg.rs_lookbacks:
        out[f"ret{lb}"] = c.pct_change(lb)
    return out

# ============================ DATA ============================

def load_universe(path: str | None) -> pd.DataFrame:
    if path:
        u = pd.read_csv(path)
    else:
        import urllib.request
        req = urllib.request.Request(UNIVERSE_URL,
                                     headers={"User-Agent": "Mozilla/5.0"})
        u = pd.read_csv(io.StringIO(
            urllib.request.urlopen(req, timeout=30).read().decode()))
    sym_col = next(c for c in u.columns if c.strip().lower() == "symbol")
    u = u.rename(columns={sym_col: "Symbol"})
    if "Industry" not in u.columns:
        u["Industry"] = "NA"
    u["Symbol"] = u["Symbol"].str.strip()
    return u[["Symbol", "Industry"]]

def download_prices(symbols, cfg: Cfg) -> dict:
    import yfinance as yf
    data, chunk = {}, 40
    for i in range(0, len(symbols), chunk):
        batch = [s + ".NS" for s in symbols[i:i + chunk]]
        raw = yf.download(batch, start=cfg.start, end=cfg.end,
                          auto_adjust=True, group_by="ticker",
                          progress=False, threads=True)
        for s in symbols[i:i + chunk]:
            t = s + ".NS"
            try:
                df = raw[t].dropna(how="all") if len(batch) > 1 else raw.dropna(how="all")
            except KeyError:
                continue
            df = df.dropna(subset=["Close"])
            if len(df) >= cfg.min_history_days:
                data[s] = df[["Open", "High", "Low", "Close", "Volume"]]
        print(f"  downloaded {min(i+chunk, len(symbols))}/{len(symbols)}")
    return data

# ============================ ENGINE ============================

class Position:
    __slots__ = ("sym", "entry", "qty", "stop", "init_stop", "hi_close",
                 "scaled", "days", "entry_date", "sector")
    def __init__(self, sym, entry, qty, stop, date, sector):
        self.sym, self.entry, self.qty = sym, entry, qty
        self.stop = self.init_stop = stop
        self.hi_close, self.scaled, self.days = entry, False, 0
        self.entry_date, self.sector = date, sector

def run_backtest(data: dict, sectors: dict, cfg: Cfg):
    # ---- panel prep ----
    ind = {s: add_indicators(df, cfg) for s, df in data.items()}
    all_dates = sorted(set().union(*[set(df.index) for df in ind.values()]))
    dates = pd.DatetimeIndex(all_dates)

    closes = pd.DataFrame({s: df["Close"] for s, df in ind.items()},
                          index=dates)
    # equal-weight universe index (normalized) -> regime + RS benchmark
    norm = closes / closes.bfill().iloc[0]
    ew = norm.mean(axis=1, skipna=True)
    ew_ma = ew.rolling(cfg.regime_ma).mean()
    ew_ret = {lb: ew.pct_change(lb) for lb in cfg.rs_lookbacks}

    # sector momentum (only if real Industry data)
    use_sectors = len(set(sectors.values())) > 1
    sec_close = None
    if use_sectors:
        sec_close = pd.DataFrame({
            sec: norm[[s for s, x in sectors.items() if x == sec and s in norm]].mean(axis=1)
            for sec in set(sectors.values())})

    equity, cash = cfg.initial_equity, cfg.initial_equity
    positions, trades, curve = {}, [], []
    pending_entries, pending_exits = [], []   # execute at next open

    def book(sym, qty, px, side, reason, d):
        nonlocal cash
        cost = px * qty * cfg.cost_side
        if side == "BUY":
            cash -= px * qty + cost
        else:
            cash += px * qty - cost
        trades.append(dict(date=d.date(), sym=sym, side=side, qty=qty,
                           px=round(px, 2), reason=reason))

    for i, d in enumerate(dates):
        # ---------- 1. execute pending exits at today's open ----------
        for sym, frac, reason in pending_exits:
            p = positions.get(sym)
            if p is None or d not in ind[sym].index:
                continue
            o = ind[sym].at[d, "Open"]
            q = p.qty if frac >= 1 else int(p.qty * frac)
            if q <= 0:
                continue
            book(sym, q, o, "SELL", reason, d)
            p.qty -= q
            if frac >= 1 or p.qty <= 0:
                positions.pop(sym, None)
            else:
                p.scaled = True
                p.stop = max(p.stop, p.entry)          # ride risk-free
        pending_exits = []

        # ---------- 2. execute pending entries at today's open ----------
        for sym, prev_close in pending_entries:
            if sym in positions or sym not in ind or d not in ind[sym].index:
                continue
            row = ind[sym].loc[d]
            o = row["Open"]
            if o / prev_close - 1 > cfg.max_gap_up:     # anti-chase
                continue
            atr = row["atr"]
            if not np.isfinite(atr) or atr <= 0:
                continue
            stop = max(o - cfg.stop_atr * atr, o * (1 - cfg.stop_max_pct))
            per_share = o - stop
            if per_share <= 0:
                continue
            eq_now = cash + sum(pp.qty * ind[pp.sym].at[d, "Open"]
                                for pp in positions.values()
                                if d in ind[pp.sym].index)
            qty = int(eq_now * cfg.risk_per_trade / per_share)
            qty = min(qty, int(eq_now * cfg.max_pos_pct / o))
            qty = min(qty, int(row["adv_val"] * cfg.max_pct_adv / o)
                      if np.isfinite(row["adv_val"]) else 0)
            heat = sum((pp.entry - pp.stop) * pp.qty for pp in positions.values()
                       if pp.stop < pp.entry)
            if (qty <= 0 or len(positions) >= cfg.max_positions
                    or heat + per_share * qty > eq_now * cfg.max_heat
                    or qty * o > cash):
                continue
            book(sym, qty, o, "BUY", "entry", d)
            positions[sym] = Position(sym, o, qty, stop, d, sectors.get(sym, "NA"))
        pending_entries = []

        # ---------- 3. intraday stop check + close-based management ----------
        for sym, p in list(positions.items()):
            if d not in ind[sym].index:
                p.days += 1
                continue
            row = ind[sym].loc[d]
            p.days += 1
            # stop hit intraday (gap-aware fill)
            if row["Low"] <= p.stop:
                fill = min(row["Open"], p.stop)
                book(sym, p.qty, fill, "SELL", "stop", d)
                positions.pop(sym)
                continue
            c = row["Close"]
            p.hi_close = max(p.hi_close, c)
            # trailing ratchet
            if np.isfinite(row["atr"]):
                p.stop = max(p.stop, p.hi_close - cfg.trail_atr * row["atr"])
            r = (c - p.entry) / max(p.entry - p.init_stop, 1e-9)
            if not p.scaled and r >= cfg.scale_r:
                pending_exits.append((sym, cfg.scale_frac, "scale_3R"))
                continue
            weak = sum([row["rsi"] < cfg.momo_rsi,
                        row["macd"] < row["macds"],
                        c < row["ema50"]])
            if p.scaled and weak >= 2:
                pending_exits.append((sym, 1.0, "momo_weak"))
                continue
            if (p.days >= cfg.time_days and r < 1.0
                    and c / p.entry - 1 < cfg.time_min_gain):
                pending_exits.append((sym, 1.0, "time_stop"))

        # ---------- 4. scan entries on close (regime-gated) ----------
        regime_on = np.isfinite(ew_ma.iloc[i]) and ew.iloc[i] > ew_ma.iloc[i]
        if regime_on and len(positions) < cfg.max_positions:
            top_secs = None
            if use_sectors and i > cfg.sector_lookback:
                mom = (sec_close.iloc[i] / sec_close.iloc[i - cfg.sector_lookback] - 1)
                top_secs = set(mom.nlargest(cfg.sector_top_n).index)
            # RS scores today
            rs_scores = {}
            for sym, df in ind.items():
                if d not in df.index or sym in positions:
                    continue
                row = df.loc[d]
                if row["Close"] < cfg.min_price:
                    continue
                if not np.isfinite(row["adv_val"]) or row["adv_val"] < cfg.min_adv_cr * 1e7:
                    continue
                if top_secs and sectors.get(sym, "NA") not in top_secs:
                    continue
                sc, ok = 0.0, True
                for lb in cfg.rs_lookbacks:
                    r_ = row[f"ret{lb}"]
                    b_ = ew_ret[lb].iloc[i]
                    if not (np.isfinite(r_) and np.isfinite(b_)):
                        ok = False; break
                    sc += r_ - b_
                if ok:
                    rs_scores[sym] = sc
            if rs_scores:
                cut = max(1, int(len(rs_scores) * cfg.rs_top_quantile))
                elig = set(sorted(rs_scores, key=rs_scores.get, reverse=True)[:cut])
                for sym in elig:
                    row = ind[sym].loc[d]
                    if not (np.isfinite(row["hh"]) and row["Close"] > row["hh"]):
                        continue
                    if not (np.isfinite(row["vavg20"])
                            and row["Volume"] >= cfg.vol_mult * row["vavg20"]):
                        continue
                    if not (row["Close"] > row["ema50"] > row["ema200"]):
                        continue
                    if row["Close"] / row["ema50"] - 1 > cfg.max_ext_50:
                        continue
                    if not (cfg.rsi_floor <= row["rsi"] <= cfg.rsi_ceiling):
                        continue
                    if not row["macd"] > row["macds"]:
                        continue
                    pending_entries.append((sym, row["Close"]))

        # ---------- 5. mark to market ----------
        mv = sum(p.qty * ind[p.sym].at[d, "Close"]
                 for p in positions.values() if d in ind[p.sym].index)
        equity = cash + mv
        curve.append((d, equity, len(positions), regime_on))

    return trades, pd.DataFrame(curve, columns=["date", "equity", "npos",
                                                "regime"]).set_index("date"), ew

# ============================ REPORT ============================

def pair_trades(trades):
    """FIFO pairing of buys->sells per symbol to compute per-trade P&L."""
    open_lots, results = {}, []
    for t in trades:
        s = t["sym"]
        if t["side"] == "BUY":
            open_lots.setdefault(s, []).append([t["qty"], t["px"], t["date"]])
        else:
            q = t["qty"]
            while q > 0 and open_lots.get(s):
                lot = open_lots[s][0]
                take = min(q, lot[0])
                results.append(dict(sym=s, qty=take, buy=lot[1], sell=t["px"],
                                    pnl=(t["px"] - lot[1]) * take,
                                    ret=t["px"] / lot[1] - 1,
                                    opened=lot[2], closed=t["date"],
                                    reason=t["reason"]))
                lot[0] -= take; q -= take
                if lot[0] == 0:
                    open_lots[s].pop(0)
    return pd.DataFrame(results)

def report(trades, curve, ew, cfg: Cfg, outdir="bt_out"):
    os.makedirs(outdir, exist_ok=True)
    tdf = pd.DataFrame(trades)
    tdf.to_csv(f"{outdir}/trades.csv", index=False)
    curve.to_csv(f"{outdir}/equity_curve.csv")

    eq = curve["equity"]
    yrs = max((eq.index[-1] - eq.index[0]).days / 365.25, 1e-9)
    cagr = (eq.iloc[-1] / eq.iloc[0]) ** (1 / yrs) - 1
    dd = (eq / eq.cummax() - 1).min()
    daily = eq.pct_change().dropna()
    sharpe = daily.mean() / (daily.std() + 1e-12) * math.sqrt(252)
    bench = (ew.reindex(eq.index).ffill())
    bench_cagr = (bench.iloc[-1] / bench.dropna().iloc[0]) ** (1 / yrs) - 1

    p = pair_trades(trades)
    lines = ["=" * 62,
             "SMALLCAP FRAMEWORK BACKTEST — technical layer only",
             "*** SURVIVORSHIP-BIASED UNIVERSE: treat as UPPER BOUND ***",
             "=" * 62,
             f"Period        : {eq.index[0].date()} -> {eq.index[-1].date()} ({yrs:.1f}y)",
             f"Start equity  : ₹{cfg.initial_equity:,.0f}",
             f"End equity    : ₹{eq.iloc[-1]:,.0f}",
             f"CAGR          : {cagr*100:6.2f}%   (EW universe B&H: {bench_cagr*100:.2f}%)",
             f"Max drawdown  : {dd*100:6.2f}%",
             f"Sharpe (daily): {sharpe:6.2f}",
             f"Time in regime: {curve['regime'].mean()*100:5.1f}% of days",
             f"Avg open pos  : {curve['npos'].mean():5.2f}"]
    if len(p):
        wins = p[p.pnl > 0]
        pf = wins.pnl.sum() / max(-p[p.pnl <= 0].pnl.sum(), 1e-9)
        lines += [f"Closed lots   : {len(p)}",
                  f"Win rate      : {len(wins)/len(p)*100:5.1f}%",
                  f"Avg win/loss  : {wins.ret.mean()*100:+.2f}% / "
                  f"{p[p.pnl<=0].ret.mean()*100:+.2f}%",
                  f"Profit factor : {pf:5.2f}",
                  "", "Exit-reason P&L:",
                  p.groupby("reason").pnl.agg(["count", "sum"]).to_string()]
        # yearly table
        p["yr"] = pd.to_datetime(p["closed"]).dt.year
        lines += ["", "Per-year closed P&L:",
                  p.groupby("yr").pnl.agg(["count", "sum"]).to_string()]
    txt = "\n".join(lines)
    with open(f"{outdir}/report.txt", "w") as f:
        f.write(txt + "\n")
    print(txt)
    print(f"\nSaved: {outdir}/report.txt, trades.csv, equity_curve.csv")

# ============================ SELFTEST ============================

def synthetic_data(n_sym=60, days=900, seed=7):
    rng = np.random.default_rng(seed)
    idx = pd.bdate_range("2021-01-01", periods=days)
    data, sectors = {}, {}
    for k in range(n_sym):
        drift = rng.normal(0.0004, 0.0006)
        vol = rng.uniform(0.015, 0.035)
        r = rng.normal(drift, vol, days)
        # inject occasional momentum runs so breakouts exist
        for _ in range(rng.integers(1, 4)):
            s0 = rng.integers(50, days - 120)
            r[s0:s0 + 90] += rng.uniform(0.001, 0.004)
        c = 100 * np.exp(np.cumsum(r))
        o = c * (1 + rng.normal(0, 0.004, days))
        h = np.maximum(o, c) * (1 + np.abs(rng.normal(0, 0.006, days)))
        l = np.minimum(o, c) * (1 - np.abs(rng.normal(0, 0.006, days)))
        v = rng.lognormal(13.5, 0.7, days)   # ~₹ value via price*vol varies
        df = pd.DataFrame(dict(Open=o, High=h, Low=l, Close=c, Volume=v),
                          index=idx)
        data[f"SYN{k:03d}"] = df
        sectors[f"SYN{k:03d}"] = f"SEC{k % 6}"
    return data, sectors

# ============================ MAIN ============================

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", default="2019-01-01")
    ap.add_argument("--end", default=None)
    ap.add_argument("--universe", default=None,
                    help="CSV with Symbol[,Industry] columns")
    ap.add_argument("--equity", type=float, default=1_000_000)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()

    cfg = Cfg(start=a.start, end=a.end, initial_equity=a.equity)

    if a.selftest:
        print("SELFTEST: synthetic universe, engine validation only "
              "(P&L numbers are meaningless).")
        data, sectors = synthetic_data()
        cfg.min_adv_cr = 0.0            # synthetic volumes aren't in ₹ cr
    else:
        uni = load_universe(a.universe)
        sectors = dict(zip(uni["Symbol"], uni["Industry"]))
        print(f"Universe: {len(uni)} symbols. Downloading daily data...")
        data = download_prices(list(uni["Symbol"]), cfg)
        print(f"Usable symbols with history: {len(data)}")
        if len(data) < 50:
            sys.exit("Too few symbols downloaded — check internet/universe CSV.")

    trades, curve, ew = run_backtest(data, sectors, cfg)
    report(trades, curve, ew, cfg)

if __name__ == "__main__":
    main()
