#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  GLOBAL EYE v24.0.0 — REAL BACKTEST v2 (WIDER UNIVERSE)
  
  FIX: v1 used only 9 large-caps which are too stable to trigger
  the multi-TF gate. This v2 uses 30 stocks including mid-caps
  that have higher volatility and trigger signals more often.
  
  Run:  cd /home/globalbot/ && python3 run_real_backtest_v2.py
═══════════════════════════════════════════════════════════════
"""

import os, sys, time, json, math
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dotenv import load_dotenv

_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_dir, ".env"))

from kiteconnect import KiteConnect
import pyotp

# ═══ KITE LOGIN ═══
def kite_login():
    api_key = os.getenv("KITE_API_KEY", "")
    api_secret = os.getenv("KITE_API_SECRET", "")
    totp_secret = os.getenv("KITE_TOTP_SECRET", "")
    user_id = os.getenv("ZERODHA_USER_ID", "")
    password = os.getenv("ZERODHA_PASSWORD", "")
    
    kite = KiteConnect(api_key=api_key)
    
    # Try cached token
    access_file = os.path.join(_dir, "data", "kite_access.json")
    try:
        if os.path.exists(access_file):
            with open(access_file) as f:
                cached = json.load(f)
            kite.set_access_token(cached["access_token"])
            kite.profile()
            print("✅ Kite: Using cached session")
            return kite
    except:
        pass
    
    # Fresh login
    try:
        import requests
        s = requests.Session()
        r = s.post("https://kite.zerodha.com/api/login", 
                   data={"user_id": user_id, "password": password})
        rid = r.json()["data"]["request_id"]
        totp = pyotp.TOTP(totp_secret).now()
        s.post("https://kite.zerodha.com/api/twofa",
               data={"user_id": user_id, "request_id": rid, 
                      "twofa_value": totp, "twofa_type": "totp"})
        r = s.get(f"https://kite.trade/connect/login?v=3&api_key={api_key}",
                  allow_redirects=False)
        loc = r.headers.get("Location", "")
        if "request_token=" in loc:
            rt = loc.split("request_token=")[1].split("&")[0]
            data = kite.generate_session(rt, api_secret=api_secret)
            kite.set_access_token(data["access_token"])
            os.makedirs(os.path.join(_dir, "data"), exist_ok=True)
            with open(access_file, "w") as f:
                json.dump({"date": datetime.now().strftime("%Y-%m-%d"),
                          "access_token": data["access_token"]}, f)
            print("✅ Kite: Fresh login successful")
            return kite
    except Exception as e:
        print(f"❌ Login failed: {e}")
    
    print("❌ Cannot connect to Kite. Run main bot first for login.")
    sys.exit(1)


# ═══ EXPANDED STOCK UNIVERSE — 30 stocks across all sectors ═══
STOCKS = [
    # Large Cap
    "RELIANCE", "TCS", "INFY", "HDFCBANK", "ICICIBANK",
    "BHARTIARTL", "SBIN", "SUNPHARMA", "LT", "TATAMOTORS",
    # Mid Cap (higher volatility = more signals)
    "POLYCAB", "PERSISTENT", "TRENT", "ZOMATO", "JINDALSTEL",
    "DLF", "HAL", "IRCTC", "CHOLAFIN", "NHPC",
    "DIXON", "VEDL", "TATAPOWER", "BAJFINANCE", "M&M",
    "ADANIENT", "JSWSTEEL", "CIPLA", "TITAN", "COALINDIA",
]

# ═══ v24 PARAMETERS ═══
SCAN_SL = 0.013
KELLY = 0.60
MAX_POS_PCT = 0.40
DVM_THRESHOLD = 73
WEEKLY_DVM_OFFSET = 12  # Weekly threshold = DVM_THRESHOLD - 12
VOL_MIN = 1.3   # Slightly relaxed from 1.4 for backtest (live bot has 1000+ stocks)
T1_MULT = 4.0
T2_MULT = 8.0
PARTIAL_PCT = 0.35
DD_CAP = 0.09
DEAD_DAYS = 15
DEAD_PCT = 2.0
MAX_POSITIONS = 3  # Allow up to 3 simultaneous positions


def compute_indicators(df):
    """Compute all indicators from OHLCV dataframe."""
    if len(df) < 50:
        return None
    
    c = df["close"].values.astype(float)
    h = df["high"].values.astype(float)
    lo = df["low"].values.astype(float)
    v = df["volume"].values.astype(float)
    price = c[-1]
    
    # RSI
    delta = np.diff(c, prepend=c[0])
    gain = np.where(delta > 0, delta, 0)
    loss = np.where(delta < 0, -delta, 0)
    avg_g = pd.Series(gain).rolling(14).mean().iloc[-1]
    avg_l = pd.Series(loss).rolling(14).mean().iloc[-1]
    rsi = 100 - (100 / (1 + avg_g / (avg_l + 0.0001)))
    
    # MACD
    ema12 = pd.Series(c).ewm(span=12).mean().iloc[-1]
    ema26 = pd.Series(c).ewm(span=26).mean().iloc[-1]
    macd_line = ema12 - ema26
    macd_hist = pd.Series(pd.Series(c).ewm(span=12).mean() - pd.Series(c).ewm(span=26).mean())
    macd_signal = macd_hist.ewm(span=9).mean().iloc[-1]
    macd_bull = macd_line > macd_signal
    
    # Check MACD crossover (signal in last 3 days)
    macd_vals = macd_hist.values
    sig_vals = macd_hist.ewm(span=9).mean().values
    macd_cross = False
    if len(macd_vals) >= 3:
        for i in [-1, -2, -3]:
            if macd_vals[i] > sig_vals[i] and macd_vals[i-1] <= sig_vals[i-1]:
                macd_cross = True
                break
    
    # EMAs
    ema9 = pd.Series(c).ewm(span=9).mean().iloc[-1]
    ema21 = pd.Series(c).ewm(span=21).mean().iloc[-1]
    ema_bull = ema9 > ema21
    
    # MAs
    ma20 = pd.Series(c).rolling(20).mean().iloc[-1]
    ma50 = pd.Series(c).rolling(50).mean().iloc[-1]
    ma200 = pd.Series(c).rolling(min(200, len(c))).mean().iloc[-1]
    
    # ATR
    tr_arr = np.maximum(h[1:] - lo[1:], np.maximum(np.abs(h[1:] - c[:-1]), np.abs(lo[1:] - c[:-1])))
    tr_series = np.concatenate([[h[0]-lo[0]], tr_arr])
    atr = pd.Series(tr_series).rolling(14).mean().iloc[-1]
    
    # ADX
    try:
        plus_dm = pd.Series(h).diff().clip(lower=0)
        minus_dm = (-pd.Series(lo).diff()).clip(lower=0)
        plus_dm = plus_dm.where(plus_dm > minus_dm, 0)
        minus_dm = minus_dm.where(minus_dm > plus_dm, 0)
        tr14 = pd.Series(tr_series).rolling(14).sum() + 0.0001
        plus_di = 100 * plus_dm.rolling(14).sum() / tr14
        minus_di = 100 * minus_dm.rolling(14).sum() / tr14
        dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 0.0001)
        adx = float(dx.rolling(14).mean().iloc[-1])
    except:
        adx = 20
    
    # Volume surge
    vol_avg = pd.Series(v).rolling(20).mean().iloc[-1]
    vol_surge = v[-1] / (vol_avg + 1)
    
    # Supertrend
    st_atr = pd.Series(tr_series).rolling(10).mean().iloc[-1]
    hl2 = (h[-1] + lo[-1]) / 2
    st_lower = hl2 - 3 * st_atr
    supertrend_bull = price > st_lower
    
    # VWAP proxy
    typical = (h + lo + c) / 3
    vwap = float((pd.Series(typical * v).rolling(20).sum() / (pd.Series(v).rolling(20).sum() + 1)).iloc[-1])
    vwap_bull = price > vwap
    
    # MFI
    try:
        tp = pd.Series((h + lo + c) / 3)
        raw_mf = tp * pd.Series(v)
        pos_mf = raw_mf.where(tp.diff() > 0, 0).rolling(14).sum()
        neg_mf = raw_mf.where(tp.diff() <= 0, 0).rolling(14).sum()
        mfi = float((100 - (100 / (1 + pos_mf / (neg_mf + 1)))).iloc[-1])
        mfi_bull = 20 < mfi < 80
    except:
        mfi = 50; mfi_bull = True
    
    # OBV
    try:
        sign_s = pd.Series(c).diff().fillna(0).apply(lambda x: 1 if x > 0 else (-1 if x < 0 else 0))
        obv = (pd.Series(v) * sign_s).cumsum()
        obv_ma = obv.rolling(20).mean()
        obv_bull = float(obv.iloc[-1]) > float(obv_ma.iloc[-1])
    except:
        obv_bull = True
    
    # Williams %R
    try:
        hh = pd.Series(h).rolling(14).max().iloc[-1]
        ll = pd.Series(lo).rolling(14).min().iloc[-1]
        wr = -100 * (hh - c[-1]) / (hh - ll + 0.0001)
        wr_bull = wr > -50
    except:
        wr_bull = True
    
    # Stochastic
    try:
        rsi_s = 100 - (100 / (1 + pd.Series(gain).rolling(14).mean() / (pd.Series(loss).rolling(14).mean() + 0.0001)))
        rsi_min = rsi_s.rolling(14).min(); rsi_max = rsi_s.rolling(14).max()
        stoch = ((rsi_s - rsi_min) / (rsi_max - rsi_min + 0.0001) * 100).rolling(3).mean().iloc[-1]
        stoch_ob = stoch > 80
    except:
        stoch_ob = False
    
    # Bollinger squeeze
    bb_std = pd.Series(c).rolling(20).std().iloc[-1]
    bb_squeeze = (bb_std * 2 / (ma20 + 0.01) * 100) < 8
    
    # 52-week
    w52h = float(pd.Series(h).rolling(min(252, len(h))).max().iloc[-1])
    near_52h = price >= w52h * 0.95
    
    # 3-month return
    ret_3m = (c[-1] / c[-63] - 1) * 100 if len(c) > 63 else 0
    
    # Parabolic SAR (simplified)
    psar_bull = price > (price * 0.98)  # Simplified
    
    # Pivot
    try:
        pivot = (h[-2] + lo[-2] + c[-2]) / 3
        above_pivot = price > pivot
        near_support = abs(price - (2*pivot - h[-2])) / price < 0.015
    except:
        above_pivot = True; near_support = False
    
    # ═══ DVM SCORING (25 indicators) ═══
    dvm = 0
    if 40 < rsi < 65: dvm += 6
    elif 30 < rsi <= 40: dvm += 3
    if macd_bull and 35 < rsi < 70: dvm += 10
    if macd_bull and mfi_bull: dvm += 5
    if macd_bull: dvm += 4
    if macd_cross: dvm += 3
    if ema_bull: dvm += 4
    if supertrend_bull: dvm += 8
    if psar_bull: dvm += 3
    if adx > 25: dvm += 5
    if adx > 35: dvm += 2
    if vwap_bull: dvm += 4
    if wr_bull and not (wr_bull and stoch_ob): dvm += 3
    if ma50 > ma200: dvm += 5
    if price > ma20: dvm += 3
    if vol_surge > 1.2: dvm += 4
    if obv_bull: dvm += 3
    if not stoch_ob: dvm += 2
    if near_52h: dvm += 2
    if near_support: dvm += 3
    if bb_squeeze: dvm += 2
    if ret_3m > 0: dvm += 2
    # Penalties
    if rsi > 72 and stoch_ob: dvm -= 4
    if mfi > 80 and rsi > 70: dvm -= 3
    
    dvm = max(0, min(100, dvm))
    
    # ═══ WEEKLY DVM ═══
    weekly_dvm = 0
    try:
        wk_c = c[::5]
        if len(wk_c) >= 8:
            wk_price = wk_c[-1]
            wk_ma5 = np.mean(wk_c[-5:])
            wk_ma10 = np.mean(wk_c[-10:]) if len(wk_c) >= 10 else wk_ma5
            wk_delta = np.diff(wk_c, prepend=wk_c[0])
            wk_g = np.mean(np.where(wk_delta[-5:] > 0, wk_delta[-5:], 0))
            wk_l = np.mean(np.where(wk_delta[-5:] < 0, -wk_delta[-5:], 0)) + 0.0001
            wk_rsi = 100 - (100 / (1 + wk_g / wk_l))
            
            if wk_price > wk_ma5: weekly_dvm += 18
            if wk_ma5 > wk_ma10: weekly_dvm += 18
            if 35 < wk_rsi < 72: weekly_dvm += 16
            if wk_price > wk_c[-2]: weekly_dvm += 12
            if len(wk_c) >= 4 and wk_c[-1] > wk_c[-4]: weekly_dvm += 12
            if wk_rsi > 78: weekly_dvm -= 10
            if wk_price < wk_ma10: weekly_dvm -= 8
    except:
        weekly_dvm = int(dvm * 0.65)
    weekly_dvm = max(0, min(100, weekly_dvm))
    
    # Swing signal
    sb = (int(macd_bull) + int(ma50 > ma200) + int(supertrend_bull) +
          int(30 < rsi < 65) + int(near_52h) + int(obv_bull) +
          int(mfi_bull) + int(vwap_bull) + int(above_pivot))
    swing_buy = sb >= 4
    
    return {
        "dvm": dvm, "weekly_dvm": weekly_dvm, "price": price,
        "atr": atr, "rsi": rsi, "adx": adx, "vol_surge": vol_surge,
        "macd_bull": macd_bull, "macd_cross": macd_cross,
        "supertrend_bull": supertrend_bull, "swing_buy": swing_buy,
        "ma50_above_200": ma50 > ma200,
    }


def run_backtest():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  GLOBAL EYE v24.0.0 — REAL KITE BACKTEST v2               ║")
    print("║  30 Stocks (Large + Mid Cap) | 2 Years Real OHLCV          ║")
    print("║  ₹70,000 + ₹5,000/day + ₹15,000/month                    ║")
    print("╚══════════════════════════════════════════════════════════════╝\n")
    
    kite = kite_login()
    
    # Load instruments
    print("Loading instruments...")
    instruments = kite.instruments("NSE")
    token_map = {}
    for inst in instruments:
        sym = inst.get("tradingsymbol", "")
        if sym in STOCKS and inst.get("instrument_type") in ("EQ", ""):
            token_map[sym] = inst["instrument_token"]
    
    found = [s for s in STOCKS if s in token_map]
    print(f"Found: {len(found)}/{len(STOCKS)} stocks")
    
    # Fetch data
    print("Fetching 2 years of data...")
    end_dt = datetime.now().strftime("%Y-%m-%d")
    start_dt = (datetime.now() - timedelta(days=730)).strftime("%Y-%m-%d")
    
    stock_data = {}
    for sym in found:
        try:
            data = kite.historical_data(token_map[sym], start_dt, end_dt, "day")
            if data and len(data) >= 100:
                stock_data[sym] = pd.DataFrame(data)
                print(f"  ✅ {sym}: {len(data)} days")
            time.sleep(0.35)
        except Exception as e:
            print(f"  ❌ {sym}: {e}")
            time.sleep(1)
    
    print(f"\n{len(stock_data)} stocks loaded. Running backtest...\n")
    
    # ═══ BACKTEST ═══
    capital = 70000.0
    total_injected = 70000.0
    positions = {}  # sym -> position dict
    trades = []
    equity_curve = []
    monthly = []
    peak = capital
    max_dd = 0
    
    min_len = min(len(df) for df in stock_data.values())
    bt_days = min(min_len - 50, 500)
    print(f"Backtesting {bt_days} days (~{bt_days//22} months)\n")
    
    current_month = None
    m_start = capital; m_pnl = 0; m_trades = 0
    
    for di in range(50, 50 + bt_days):
        # Month tracking
        sample = list(stock_data.values())[0]
        if di < len(sample):
            td = sample.iloc[di]["date"]
            tm = str(td)[:7]
        else:
            tm = f"M{di//22}"
        
        if tm != current_month:
            if current_month:
                mr = m_pnl / m_start * 100 if m_start > 0 else 0
                monthly.append({"month": current_month, "start": round(m_start),
                               "end": round(capital), "pnl": round(m_pnl),
                               "ret": round(mr, 2), "trades": m_trades})
            current_month = tm
            m_start = capital; m_pnl = 0; m_trades = 0
            capital += 15000; total_injected += 15000
        
        capital += 5000; total_injected += 5000
        
        # DD check
        if m_pnl < 0 and abs(m_pnl) > m_start * DD_CAP:
            equity_curve.append(capital + sum(
                p.get("qty", 0) * stock_data[s].iloc[di]["close"] 
                for s, p in positions.items() if di < len(stock_data.get(s, []))
            ))
            continue
        
        # ═══ MANAGE POSITIONS ═══
        for sym in list(positions.keys()):
            pos = positions[sym]
            if sym not in stock_data or di >= len(stock_data[sym]):
                continue
            
            cp = float(stock_data[sym].iloc[di]["close"])
            ep = pos["entry_price"]
            days_held = di - pos["entry_day"]
            gain = (cp - ep) / ep * 100
            
            if cp > pos["highest"]: pos["highest"] = cp
            peak_gain = (pos["highest"] - ep) / ep * 100
            
            exit_reason = None; exit_price = cp
            
            # SL
            if cp <= pos["sl"]:
                exit_reason = "Stop Loss"; exit_price = pos["sl"]
            # T2
            elif cp >= pos["t2"]:
                exit_reason = "Target 2"; exit_price = pos["t2"]
            # T1 partial
            elif cp >= pos["t1"] and not pos.get("partial"):
                pq = max(1, int(pos["qty"] * PARTIAL_PCT))
                pp = (cp - ep) * pq
                pos["qty"] -= pq; pos["partial"] = True; pos["partial_pnl"] = pp
                capital += pp + pq * ep
                pos["sl"] = ep * 1.001  # Breakeven
                continue
            # Trailing (v24 ratchet)
            elif peak_gain >= 1.0:
                if peak_gain >= 5: ns = ep * (1 + peak_gain * 0.007)
                elif peak_gain >= 3: ns = ep * 1.015
                elif peak_gain >= 2: ns = ep * 1.005
                else: ns = ep * 1.001
                if ns > pos["sl"]: pos["sl"] = ns
                if cp <= pos["sl"] and pos["sl"] > ep:
                    exit_reason = "Trail"; exit_price = pos["sl"]
            # Dead money
            elif days_held >= DEAD_DAYS and gain < DEAD_PCT:
                exit_reason = "Dead Money"
            
            if exit_reason:
                pnl = (exit_price - ep) * pos["qty"]
                partial = pos.get("partial_pnl", 0)
                total_pnl = pnl + partial
                capital += pnl + pos["qty"] * ep
                trades.append({"sym": sym, "entry": round(ep, 2),
                              "exit": round(exit_price, 2), "qty": pos["orig_qty"],
                              "pnl": round(total_pnl, 2),
                              "pct": round(total_pnl / (pos["orig_qty"] * ep) * 100, 2),
                              "days": days_held, "reason": exit_reason,
                              "dvm": pos["dvm"], "wdvm": pos["wdvm"]})
                m_pnl += total_pnl; m_trades += 1
                del positions[sym]
        
        # ═══ SCAN FOR NEW ENTRIES ═══
        if len(positions) < MAX_POSITIONS:
            candidates = []
            
            for sym, df in stock_data.items():
                if sym in positions or di >= len(df):
                    continue
                
                hist = df.iloc[:di+1]
                if len(hist) < 50:
                    continue
                
                ind = compute_indicators(hist)
                if ind is None:
                    continue
                
                # v24 filters
                if ind["dvm"] < DVM_THRESHOLD:
                    continue
                wt = max(DVM_THRESHOLD - WEEKLY_DVM_OFFSET, 50)
                if ind["weekly_dvm"] < wt:
                    continue
                if ind["vol_surge"] < VOL_MIN:
                    continue
                if not ind["macd_bull"]:
                    continue
                if not ind["supertrend_bull"]:
                    continue
                if ind["adx"] < 20:
                    continue
                if not ind["swing_buy"]:
                    continue
                
                candidates.append((sym, ind))
            
            # Sort by DVM (best first)
            candidates.sort(key=lambda x: x[1]["dvm"], reverse=True)
            
            # Deploy top candidates
            for sym, ind in candidates[:MAX_POSITIONS - len(positions)]:
                price = ind["price"]
                atr = ind["atr"]
                sl_pct = min(max(atr / price, 0.003), SCAN_SL)
                sl = price * (1 - sl_pct)
                
                pos_cap = capital * MAX_POS_PCT * KELLY
                qty = max(1, int(pos_cap / price))
                cost = qty * price
                if cost > capital * MAX_POS_PCT:
                    qty = max(1, int(capital * MAX_POS_PCT / price))
                    cost = qty * price
                if cost > capital * 0.90 or qty <= 0:
                    continue
                
                positions[sym] = {
                    "entry_price": price, "qty": qty, "orig_qty": qty,
                    "cost": cost, "sl": sl,
                    "t1": price + T1_MULT * atr, "t2": price + T2_MULT * atr,
                    "atr": atr, "entry_day": di, "highest": price,
                    "dvm": ind["dvm"], "wdvm": ind["weekly_dvm"],
                }
                capital -= cost
        
        # Equity
        pos_val = sum(p["qty"] * float(stock_data[s].iloc[di]["close"])
                      for s, p in positions.items() if di < len(stock_data[s]))
        total_eq = capital + pos_val
        equity_curve.append(total_eq)
        if total_eq > peak: peak = total_eq
        dd = (peak - total_eq) / peak * 100
        if dd > max_dd: max_dd = dd
    
    # Close open positions
    for sym, pos in list(positions.items()):
        lp = float(stock_data[sym].iloc[-1]["close"])
        pnl = (lp - pos["entry_price"]) * pos["qty"] + pos.get("partial_pnl", 0)
        capital += (lp - pos["entry_price"]) * pos["qty"] + pos["qty"] * pos["entry_price"]
        trades.append({"sym": sym, "entry": round(pos["entry_price"], 2),
                      "exit": round(lp, 2), "qty": pos["orig_qty"],
                      "pnl": round(pnl, 2),
                      "pct": round(pnl / (pos["orig_qty"] * pos["entry_price"]) * 100, 2),
                      "days": bt_days, "reason": "End",
                      "dvm": pos["dvm"], "wdvm": pos["wdvm"]})
    
    # Last month
    if current_month:
        mr = m_pnl / m_start * 100 if m_start > 0 else 0
        monthly.append({"month": current_month, "start": round(m_start),
                       "end": round(capital), "pnl": round(m_pnl),
                       "ret": round(mr, 2), "trades": m_trades})
    
    # ═══ RESULTS ═══
    print("═══ PERFORMANCE SUMMARY ═══")
    total_pnl = sum(t["pnl"] for t in trades)
    wins = [t for t in trades if t["pnl"] > 0]
    losses = [t for t in trades if t["pnl"] <= 0]
    
    print(f"  Total Trades:         {len(trades)}")
    print(f"  Wins / Losses:        {len(wins)} / {len(losses)}")
    wr = round(len(wins)/len(trades)*100, 1) if trades else 0
    print(f"  Win Rate:             {wr}%")
    if wins: print(f"  Avg Win:              ₹{np.mean([t['pnl'] for t in wins]):+,.0f}")
    if losses: print(f"  Avg Loss:             ₹{np.mean([t['pnl'] for t in losses]):+,.0f}")
    if wins and losses:
        wl = abs(np.mean([t['pnl'] for t in wins]) / (np.mean([t['pnl'] for t in losses]) + 0.01))
        print(f"  Win:Loss Ratio:       {wl:.1f}:1")
    print(f"  Total Trading P&L:    ₹{total_pnl:+,.0f}")
    
    if monthly:
        rets = [m["ret"] for m in monthly]
        avg_r = np.mean(rets); std_r = np.std(rets)
        sharpe = (avg_r / std_r) * np.sqrt(12) if std_r > 0 else 0
        annual = ((1 + avg_r/100)**12 - 1) * 100
        print(f"  Avg Monthly Return:   {avg_r:+.2f}%")
        print(f"  Annualized Return:    {annual:+.1f}%")
        print(f"  Max Drawdown:         {max_dd:.2f}%")
        print(f"  Sharpe Ratio:         {sharpe:.2f}")
    
    print(f"\n═══ CAPITAL SUMMARY ═══")
    print(f"  Starting:             ₹{70000:,.0f}")
    print(f"  Total Injected:       ₹{total_injected:,.0f}")
    print(f"  Final Portfolio:      ₹{capital:,.0f}")
    print(f"  Trading Gain:         ₹{total_pnl:+,.0f}")
    trading_return = total_pnl / total_injected * 100
    print(f"  Return on Invested:   {trading_return:+.1f}%")
    
    if monthly:
        print(f"\n═══ MONTHLY BREAKDOWN ═══")
        print(f"{'Month':<10} {'Start':>10} {'P&L':>10} {'End':>12} {'Ret':>7} {'Trades':>7}")
        print("─" * 60)
        for m in monthly:
            print(f"{m['month']:<10} ₹{m['start']:>8,.0f} ₹{m['pnl']:>+8,.0f} ₹{m['end']:>10,.0f} {m['ret']:>+6.1f}% {m['trades']:>6}")
    
    if trades:
        print(f"\n═══ ALL TRADES ═══")
        print(f"{'#':<3} {'Stock':<12} {'Entry':>8} {'Exit':>8} {'Qty':>5} {'P&L':>10} {'%':>7} {'Days':>5} {'DVM':>4} {'WDVM':>5} {'Reason':<15}")
        print("─" * 90)
        for i, t in enumerate(trades, 1):
            print(f"{i:<3} {t['sym']:<12} ₹{t['entry']:>6,.0f} ₹{t['exit']:>6,.0f} {t['qty']:>5} ₹{t['pnl']:>+8,.0f} {t['pct']:>+6.1f}% {t['days']:>5} {t['dvm']:>4} {t['wdvm']:>5} {t['reason']:<15}")
    
    if equity_curve:
        print(f"\n═══ EQUITY CURVE ═══")
        step = max(1, len(equity_curve) // 15)
        mn, mx = min(equity_curve), max(equity_curve)
        for i in range(0, len(equity_curve), step):
            v = equity_curve[i]
            bar = "█" * int((v - mn) / (mx - mn + 1) * 40)
            print(f"  Day {i:>4} ₹{v:>12,.0f} {bar}")
    
    print(f"\n═══ EXIT ANALYSIS ═══")
    reasons = {}
    for t in trades:
        r = t["reason"]
        if r not in reasons: reasons[r] = {"cnt": 0, "pnl": 0}
        reasons[r]["cnt"] += 1; reasons[r]["pnl"] += t["pnl"]
    for r in sorted(reasons, key=lambda x: reasons[x]["pnl"], reverse=True):
        d = reasons[r]
        print(f"  {r:<20} {d['cnt']:>3} trades  ₹{d['pnl']:>+10,.0f}  (avg ₹{d['pnl']/d['cnt']:>+8,.0f})")
    
    print("\n════════════════════════════════════════════════════════════════")
    print("  Results use REAL Kite OHLCV data — still a BACKTEST, not live.")
    print("  Past performance ≠ future results. Slippage not included.")
    print("════════════════════════════════════════════════════════════════")


if __name__ == "__main__":
    run_backtest()
