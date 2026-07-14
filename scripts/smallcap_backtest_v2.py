#!/usr/bin/env python3
"""
SMALLCAP BACKTESTER V2 — two engines, one harness
==================================================
MODE 1 (default): rotation  — weekly cross-sectional momentum rotation.
    Hold top-N by blended 3m/6m return, equal weight, weekly rebalance
    with rank buffer, regime gate (EW universe index vs 200 DMA) -> cash,
    catastrophic -20% per-name stop. Always deployed when regime is ON.
    Same strategy family as the validated GIR-CRYPTO momentum design.

MODE 2: breakout — v1 engine with loosened, configurable gates.

Same cost model (0.43%/side), same survivorship caveat: UPPER BOUND.

USAGE:
    python3 smallcap_backtest_v2.py --universe smallcap_list.csv --start 2019-01-01
    python3 smallcap_backtest_v2.py --mode breakout --universe smallcap_list.csv
    python3 smallcap_backtest_v2.py --selftest            # both engines, synthetic
OUTPUT: bt_out/report_<mode>.txt, trades_<mode>.csv, equity_<mode>.csv
"""

import argparse, io, math, os, sys
from dataclasses import dataclass
import numpy as np
import pandas as pd

# ============================ CONFIG ============================

@dataclass
class Cfg:
    mode: str = "rotation"
    start: str = "2019-01-01"
    end: str = None
    initial_equity: float = 1_000_000.0

    # universe / liquidity
    min_price: float = 30.0
    min_adv_cr: float = 2.0
    min_history_days: int = 260

    # regime
    regime_ma: int = 200

    # ---------- rotation ----------
    rot_n: int = 15                  # target holdings
    rot_buffer: float = 1.8          # keep holding while rank <= N*buffer
    rot_lookbacks: tuple = (63, 126)
    rot_skip: int = 5                # skip most recent week (reversal noise)
    rot_reb_days: int = 5            # rebalance every ~week
    rot_stop: float = -0.20          # catastrophic per-name stop

    # ---------- breakout (loosened defaults) ----------
    rs_lookbacks: tuple = (63, 126)
    rs_top_quantile: float = 0.35
    breakout_lb: int = 20
    vol_mult: float = 1.3
    max_gap_up: float = 0.04
    max_ext_50: float = 0.20
    use_confirms: bool = False       # RSI/MACD confirmations off by default
    rsi_floor: float = 50.0
    rsi_ceiling: float = 80.0
    risk_per_trade: float = 0.0125
    max_pos_pct: float = 0.10
    max_pct_adv: float = 0.05
    max_positions: int = 10
    max_heat: float = 0.08
    atr_n: int = 14
    stop_atr: float = 2.0
    stop_max_pct: float = 0.08
    scale_r: float = 3.0
    scale_frac: float = 0.5
    trail_atr: float = 3.0
    momo_rsi: float = 45.0
    time_days: int = 30
    time_min_gain: float = 0.05

    cost_side: float = 0.0043

UNIVERSE_URL = ("https://www.niftyindices.com/IndexConstituent/"
                "ind_niftysmallcap250list.csv")

# ============================ SHARED ============================

def wilder_ema(s, n):
    return s.ewm(alpha=1.0 / n, adjust=False).mean()

def add_indicators(df, cfg: Cfg):
    c, h, l, v = df["Close"], df["High"], df["Low"], df["Volume"]
    out = df.copy()
    out["ema50"] = c.ewm(span=50, adjust=False).mean()
    out["ema200"] = c.ewm(span=200, adjust=False).mean()
    tr = pd.concat([h - l, (h - c.shift()).abs(), (l - c.shift()).abs()],
                   axis=1).max(axis=1)
    out["atr"] = wilder_ema(tr, cfg.atr_n)
    d = c.diff()
    rs = wilder_ema(d.clip(lower=0), 14) / wilder_ema((-d).clip(lower=0), 14).replace(0, np.nan)
    out["rsi"] = 100 - 100 / (1 + rs)
    macd = c.ewm(span=12, adjust=False).mean() - c.ewm(span=26, adjust=False).mean()
    out["macd"], out["macds"] = macd, macd.ewm(span=9, adjust=False).mean()
    out["hh"] = c.shift(1).rolling(cfg.breakout_lb).max()
    out["vavg20"] = v.rolling(20).mean()
    out["adv_val"] = (c * v).rolling(20).median()
    for lb in set(cfg.rs_lookbacks) | set(cfg.rot_lookbacks):
        out[f"ret{lb}"] = c.pct_change(lb)
    out[f"retskip"] = c.pct_change(cfg.rot_skip)
    return out

def load_universe(path):
    if path:
        u = pd.read_csv(path)
    else:
        import urllib.request
        req = urllib.request.Request(UNIVERSE_URL, headers={"User-Agent": "Mozilla/5.0"})
        u = pd.read_csv(io.StringIO(urllib.request.urlopen(req, timeout=30).read().decode()))
    sym = next(c for c in u.columns if c.strip().lower() == "symbol")
    u = u.rename(columns={sym: "Symbol"})
    if "Industry" not in u.columns:
        u["Industry"] = "NA"
    u["Symbol"] = u["Symbol"].str.strip()
    return u[["Symbol", "Industry"]]

def download_prices(symbols, cfg: Cfg):
    import yfinance as yf
    data, chunk = {}, 40
    for i in range(0, len(symbols), chunk):
        batch = [s + ".NS" for s in symbols[i:i + chunk]]
        raw = yf.download(batch, start=cfg.start, end=cfg.end, auto_adjust=True,
                          group_by="ticker", progress=False, threads=True)
        for s in symbols[i:i + chunk]:
            try:
                df = raw[s + ".NS"].dropna(how="all") if len(batch) > 1 else raw.dropna(how="all")
            except KeyError:
                continue
            df = df.dropna(subset=["Close"])
            if len(df) >= cfg.min_history_days:
                data[s] = df[["Open", "High", "Low", "Close", "Volume"]]
        print(f"  downloaded {min(i+chunk, len(symbols))}/{len(symbols)}")
    return data

def build_panel(data, cfg):
    ind = {s: add_indicators(df, cfg) for s, df in data.items()}
    dates = pd.DatetimeIndex(sorted(set().union(*[set(df.index) for df in ind.values()])))
    closes = pd.DataFrame({s: df["Close"] for s, df in ind.items()}, index=dates)
    norm = closes / closes.bfill().iloc[0]
    ew = norm.mean(axis=1, skipna=True)
    return ind, dates, ew, ew.rolling(cfg.regime_ma).mean()

# ============================ ROTATION ENGINE ============================

def run_rotation(data, cfg: Cfg):
    ind, dates, ew, ew_ma = build_panel(data, cfg)
    cash = cfg.initial_equity
    hold = {}                     # sym -> [qty, avg_cost]
    trades, curve = [], []
    pending_sells, pending_buys = [], []   # execute next open
    last_reb = None

    def book(sym, qty, px, side, reason, d):
        nonlocal cash
        cost = px * qty * cfg.cost_side
        cash += (px * qty - cost) if side == "SELL" else -(px * qty + cost)
        trades.append(dict(date=d.date(), sym=sym, side=side, qty=qty,
                           px=round(px, 2), reason=reason))

    for i, d in enumerate(dates):
        # ---- execute pending at open ----
        for sym, reason in pending_sells:
            if sym in hold and d in ind[sym].index:
                o = ind[sym].at[d, "Open"]
                book(sym, hold[sym][0], o, "SELL", reason, d)
                hold.pop(sym)
        pending_sells = []
        if pending_buys:
            eq = cash + sum(q * ind[s].at[d, "Open"] for s, (q, _) in hold.items()
                            if d in ind[s].index)
            slot_val = eq / cfg.rot_n
            for sym in pending_buys:
                if sym in hold or sym not in ind or d not in ind[sym].index:
                    continue
                o = ind[sym].at[d, "Open"]
                qty = int(min(slot_val, cash / (1 + cfg.cost_side)) / o)
                if qty > 0:
                    book(sym, qty, o, "BUY", "rotate_in", d)
                    hold[sym] = [qty, o]
        pending_buys = []

        # ---- daily catastrophic stop ----
        for sym, (q, ac) in list(hold.items()):
            if d in ind[sym].index and ind[sym].at[d, "Close"] / ac - 1 <= cfg.rot_stop:
                pending_sells.append((sym, "cat_stop"))

        # ---- weekly rebalance decision at close ----
        do_reb = last_reb is None or (i - last_reb) >= cfg.rot_reb_days
        if do_reb:
            last_reb = i
            regime_on = np.isfinite(ew_ma.iloc[i]) and ew.iloc[i] > ew_ma.iloc[i]
            if not regime_on:
                for sym in hold:
                    if (sym, "regime_off") not in pending_sells:
                        pending_sells.append((sym, "regime_off"))
            else:
                scores = {}
                for sym, df in ind.items():
                    if d not in df.index:
                        continue
                    row = df.loc[d]
                    if row["Close"] < cfg.min_price:
                        continue
                    if not np.isfinite(row["adv_val"]) or row["adv_val"] < cfg.min_adv_cr * 1e7:
                        continue
                    sc, ok = 0.0, True
                    for lb in cfg.rot_lookbacks:
                        r_ = row[f"ret{lb}"]
                        if not np.isfinite(r_):
                            ok = False; break
                        sc += r_
                    if ok:
                        # skip most-recent-week return (short-term reversal)
                        sk = row["retskip"]
                        scores[sym] = sc / len(cfg.rot_lookbacks) - (sk if np.isfinite(sk) else 0) * 0.5
                ranked = sorted(scores, key=scores.get, reverse=True)
                rank_of = {s: k + 1 for k, s in enumerate(ranked)}
                keep = {s for s in hold
                        if rank_of.get(s, 10**9) <= int(cfg.rot_n * cfg.rot_buffer)}
                for s in list(hold):
                    if s not in keep:
                        pending_sells.append((s, "rotate_out"))
                slots = cfg.rot_n - len(keep)
                for s in ranked:
                    if slots <= 0:
                        break
                    if s not in hold:
                        pending_buys.append(s); slots -= 1

        # ---- MTM ----
        mv = sum(q * ind[s].at[d, "Close"] for s, (q, _) in hold.items()
                 if d in ind[s].index)
        curve.append((d, cash + mv, len(hold),
                      bool(np.isfinite(ew_ma.iloc[i]) and ew.iloc[i] > ew_ma.iloc[i])))

    return trades, pd.DataFrame(curve, columns=["date", "equity", "npos", "regime"]
                                ).set_index("date"), ew

# ============================ BREAKOUT ENGINE (v1, loosened) ============================

class Pos:
    __slots__ = ("sym", "entry", "qty", "stop", "init_stop", "hi", "scaled", "days")
    def __init__(self, sym, entry, qty, stop):
        self.sym, self.entry, self.qty = sym, entry, qty
        self.stop = self.init_stop = stop
        self.hi, self.scaled, self.days = entry, False, 0

def run_breakout(data, cfg: Cfg):
    ind, dates, ew, ew_ma = build_panel(data, cfg)
    ew_ret = {lb: ew.pct_change(lb) for lb in cfg.rs_lookbacks}
    cash = cfg.initial_equity
    positions, trades, curve = {}, [], []
    pend_ent, pend_ex = [], []

    def book(sym, qty, px, side, reason, d):
        nonlocal cash
        cost = px * qty * cfg.cost_side
        cash += (px * qty - cost) if side == "SELL" else -(px * qty + cost)
        trades.append(dict(date=d.date(), sym=sym, side=side, qty=qty,
                           px=round(px, 2), reason=reason))

    for i, d in enumerate(dates):
        for sym, frac, reason in pend_ex:
            p = positions.get(sym)
            if p and d in ind[sym].index:
                o = ind[sym].at[d, "Open"]
                q = p.qty if frac >= 1 else int(p.qty * frac)
                if q > 0:
                    book(sym, q, o, "SELL", reason, d)
                    p.qty -= q
                    if p.qty <= 0:
                        positions.pop(sym)
                    else:
                        p.scaled = True
                        p.stop = max(p.stop, p.entry)
        pend_ex = []
        for sym, prev_c in pend_ent:
            if sym in positions or d not in ind[sym].index:
                continue
            row = ind[sym].loc[d]
            o = row["Open"]
            if o / prev_c - 1 > cfg.max_gap_up or not np.isfinite(row["atr"]) or row["atr"] <= 0:
                continue
            stop = max(o - cfg.stop_atr * row["atr"], o * (1 - cfg.stop_max_pct))
            per = o - stop
            if per <= 0:
                continue
            eq = cash + sum(pp.qty * ind[pp.sym].at[d, "Open"] for pp in positions.values()
                            if d in ind[pp.sym].index)
            qty = int(eq * cfg.risk_per_trade / per)
            qty = min(qty, int(eq * cfg.max_pos_pct / o))
            qty = min(qty, int(row["adv_val"] * cfg.max_pct_adv / o)
                      if np.isfinite(row["adv_val"]) else 0)
            heat = sum((pp.entry - pp.stop) * pp.qty for pp in positions.values()
                       if pp.stop < pp.entry)
            if (qty > 0 and len(positions) < cfg.max_positions
                    and heat + per * qty <= eq * cfg.max_heat and qty * o <= cash):
                book(sym, qty, o, "BUY", "entry", d)
                positions[sym] = Pos(sym, o, qty, stop)
        pend_ent = []

        for sym, p in list(positions.items()):
            if d not in ind[sym].index:
                p.days += 1; continue
            row = ind[sym].loc[d]
            p.days += 1
            if row["Low"] <= p.stop:
                book(sym, p.qty, min(row["Open"], p.stop), "SELL", "stop", d)
                positions.pop(sym); continue
            c = row["Close"]
            p.hi = max(p.hi, c)
            if np.isfinite(row["atr"]):
                p.stop = max(p.stop, p.hi - cfg.trail_atr * row["atr"])
            r = (c - p.entry) / max(p.entry - p.init_stop, 1e-9)
            if not p.scaled and r >= cfg.scale_r:
                pend_ex.append((sym, cfg.scale_frac, "scale_3R")); continue
            weak = sum([row["rsi"] < cfg.momo_rsi, row["macd"] < row["macds"],
                        c < row["ema50"]])
            if p.scaled and weak >= 2:
                pend_ex.append((sym, 1.0, "momo_weak")); continue
            if p.days >= cfg.time_days and r < 1.0 and c / p.entry - 1 < cfg.time_min_gain:
                pend_ex.append((sym, 1.0, "time_stop"))

        regime_on = np.isfinite(ew_ma.iloc[i]) and ew.iloc[i] > ew_ma.iloc[i]
        if regime_on and len(positions) < cfg.max_positions:
            rs = {}
            for sym, df in ind.items():
                if d not in df.index or sym in positions:
                    continue
                row = df.loc[d]
                if row["Close"] < cfg.min_price:
                    continue
                if not np.isfinite(row["adv_val"]) or row["adv_val"] < cfg.min_adv_cr * 1e7:
                    continue
                sc, ok = 0.0, True
                for lb in cfg.rs_lookbacks:
                    r_, b_ = row[f"ret{lb}"], ew_ret[lb].iloc[i]
                    if not (np.isfinite(r_) and np.isfinite(b_)):
                        ok = False; break
                    sc += r_ - b_
                if ok:
                    rs[sym] = sc
            if rs:
                cut = max(1, int(len(rs) * cfg.rs_top_quantile))
                for sym in sorted(rs, key=rs.get, reverse=True)[:cut]:
                    row = ind[sym].loc[d]
                    if not (np.isfinite(row["hh"]) and row["Close"] > row["hh"]):
                        continue
                    if not (np.isfinite(row["vavg20"]) and row["Volume"] >= cfg.vol_mult * row["vavg20"]):
                        continue
                    if not (row["Close"] > row["ema50"] > row["ema200"]):
                        continue
                    if row["Close"] / row["ema50"] - 1 > cfg.max_ext_50:
                        continue
                    if cfg.use_confirms:
                        if not (cfg.rsi_floor <= row["rsi"] <= cfg.rsi_ceiling):
                            continue
                        if not row["macd"] > row["macds"]:
                            continue
                    pend_ent.append((sym, row["Close"]))

        mv = sum(p.qty * ind[p.sym].at[d, "Close"] for p in positions.values()
                 if d in ind[p.sym].index)
        curve.append((d, cash + mv, len(positions), regime_on))

    return trades, pd.DataFrame(curve, columns=["date", "equity", "npos", "regime"]
                                ).set_index("date"), ew

# ============================ REPORT ============================

def pair_trades(trades):
    lots, out = {}, []
    for t in trades:
        s = t["sym"]
        if t["side"] == "BUY":
            lots.setdefault(s, []).append([t["qty"], t["px"], t["date"]])
        else:
            q = t["qty"]
            while q > 0 and lots.get(s):
                lot = lots[s][0]
                take = min(q, lot[0])
                out.append(dict(sym=s, qty=take, buy=lot[1], sell=t["px"],
                                pnl=(t["px"] - lot[1]) * take,
                                ret=t["px"] / lot[1] - 1,
                                opened=lot[2], closed=t["date"], reason=t["reason"]))
                lot[0] -= take; q -= take
                if lot[0] == 0:
                    lots[s].pop(0)
    return pd.DataFrame(out)

def report(trades, curve, ew, cfg: Cfg, outdir="bt_out"):
    os.makedirs(outdir, exist_ok=True)
    m = cfg.mode
    pd.DataFrame(trades).to_csv(f"{outdir}/trades_{m}.csv", index=False)
    curve.to_csv(f"{outdir}/equity_{m}.csv")
    eq = curve["equity"]
    yrs = max((eq.index[-1] - eq.index[0]).days / 365.25, 1e-9)
    cagr = (eq.iloc[-1] / eq.iloc[0]) ** (1 / yrs) - 1
    dd = (eq / eq.cummax() - 1).min()
    daily = eq.pct_change().dropna()
    sharpe = daily.mean() / (daily.std() + 1e-12) * math.sqrt(252)
    b = ew.reindex(eq.index).ffill().dropna()
    bcagr = (b.iloc[-1] / b.iloc[0]) ** (1 / yrs) - 1
    p = pair_trades(trades)
    L = ["=" * 62, f"SMALLCAP BACKTEST V2 — mode: {m}",
         "*** SURVIVORSHIP-BIASED UNIVERSE: UPPER BOUND ***", "=" * 62,
         f"Period        : {eq.index[0].date()} -> {eq.index[-1].date()} ({yrs:.1f}y)",
         f"End equity    : ₹{eq.iloc[-1]:,.0f}  (start ₹{cfg.initial_equity:,.0f})",
         f"CAGR          : {cagr*100:6.2f}%   (EW universe B&H: {bcagr*100:.2f}%)",
         f"Max drawdown  : {dd*100:6.2f}%",
         f"Sharpe (daily): {sharpe:6.2f}",
         f"Time in regime: {curve['regime'].mean()*100:5.1f}%",
         f"Avg open pos  : {curve['npos'].mean():5.2f}"]
    if len(p):
        w = p[p.pnl > 0]
        pf = w.pnl.sum() / max(-p[p.pnl <= 0].pnl.sum(), 1e-9)
        L += [f"Closed lots   : {len(p)}   Win rate: {len(w)/len(p)*100:.1f}%   PF: {pf:.2f}",
              f"Avg win/loss  : {w.ret.mean()*100:+.2f}% / {p[p.pnl<=0].ret.mean()*100:+.2f}%",
              "", "Exit-reason P&L:",
              p.groupby("reason").pnl.agg(["count", "sum"]).to_string()]
        p["yr"] = pd.to_datetime(p["closed"]).dt.year
        L += ["", "Per-year closed P&L:",
              p.groupby("yr").pnl.agg(["count", "sum"]).to_string()]
    txt = "\n".join(L)
    open(f"{outdir}/report_{m}.txt", "w").write(txt + "\n")
    print(txt)
    print(f"\nSaved: {outdir}/report_{m}.txt, trades_{m}.csv, equity_{m}.csv")

# ============================ SELFTEST / MAIN ============================

def synthetic_data(n_sym=60, days=900, seed=7):
    rng = np.random.default_rng(seed)
    idx = pd.bdate_range("2021-01-01", periods=days)
    data = {}
    for k in range(n_sym):
        r = rng.normal(rng.normal(0.0004, 0.0006), rng.uniform(0.015, 0.035), days)
        for _ in range(rng.integers(1, 4)):
            s0 = rng.integers(50, days - 120)
            r[s0:s0 + 90] += rng.uniform(0.001, 0.004)
        c = 100 * np.exp(np.cumsum(r))
        o = c * (1 + rng.normal(0, 0.004, days))
        h = np.maximum(o, c) * (1 + np.abs(rng.normal(0, 0.006, days)))
        l = np.minimum(o, c) * (1 - np.abs(rng.normal(0, 0.006, days)))
        data[f"SYN{k:03d}"] = pd.DataFrame(dict(Open=o, High=h, Low=l, Close=c,
                                                Volume=rng.lognormal(13.5, .7, days)),
                                           index=idx)
    return data

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["rotation", "breakout"], default="rotation")
    ap.add_argument("--start", default="2019-01-01")
    ap.add_argument("--end", default=None)
    ap.add_argument("--universe", default=None)
    ap.add_argument("--equity", type=float, default=1_000_000)
    ap.add_argument("--top-n", type=int, default=15)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    cfg = Cfg(mode=a.mode, start=a.start, end=a.end,
              initial_equity=a.equity, rot_n=a.top_n)

    if a.selftest:
        print("SELFTEST (synthetic — numbers meaningless, machinery only)")
        data = synthetic_data()
        cfg.min_adv_cr = 0.0
        for mode, fn in (("rotation", run_rotation), ("breakout", run_breakout)):
            cfg.mode = mode
            print(f"\n----- {mode} -----")
            t, c, ew = fn(data, cfg)
            report(t, c, ew, cfg)
        return

    uni = load_universe(a.universe)
    print(f"Universe: {len(uni)} symbols. Downloading daily data...")
    data = download_prices(list(uni["Symbol"]), cfg)
    print(f"Usable symbols with history: {len(data)}")
    if len(data) < 50:
        sys.exit("Too few symbols — check internet/universe CSV.")
    fn = run_rotation if cfg.mode == "rotation" else run_breakout
    t, c, ew = fn(data, cfg)
    report(t, c, ew, cfg)

if __name__ == "__main__":
    main()
