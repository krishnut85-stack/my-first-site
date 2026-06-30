#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  GLOBAL EYE v24.0.0 — BACKTEST v3: THREE VARIATIONS
  
  Root Cause Analysis from v2 results:
  1. SAME STOCK REPEATED: JSWSTEEL traded 4 times, all losses
     → FIX: Add cooldown blacklist (no re-entry for 20 days after loss)
  2. ALL EXITS WERE SL: T1/T2 never hit in 20 months
     → FIX: SL too tight. Widen SL to 2×ATR. Targets were unreachable.
  3. ENTRIES BARELY ABOVE THRESHOLD: DVM 73-76, weekly 64
     → FIX: Raise quality bar OR add momentum confirmation
  4. NO POSITION MANAGEMENT: Backtest v2 had no trailing ratchet
     → FIX: Implement proper trailing with ATR-based dynamic stops
  5. POSITION SIZING IGNORES CAPITAL GROWTH: Tiny positions vs large capital
     → FIX: Scale position size with growing capital
  
  Run: cd /home/globalbot/ && python3 run_backtest_v3.py
═══════════════════════════════════════════════════════════════
"""

import os, sys, time, json
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dotenv import load_dotenv

_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_dir, ".env"))

from kiteconnect import KiteConnect
import pyotp

def kite_login():
    api_key = os.getenv("KITE_API_KEY", "")
    api_secret = os.getenv("KITE_API_SECRET", "")
    kite = KiteConnect(api_key=api_key)
    access_file = os.path.join(_dir, "data", "kite_access.json")
    try:
        if os.path.exists(access_file):
            with open(access_file) as f:
                cached = json.load(f)
            kite.set_access_token(cached["access_token"])
            kite.profile()
            print("✅ Kite: Cached session")
            return kite
    except:
        pass
    
    try:
        import requests
        user_id = os.getenv("ZERODHA_USER_ID", "")
        password = os.getenv("ZERODHA_PASSWORD", "")
        totp_secret = os.getenv("KITE_TOTP_SECRET", "")
        s = requests.Session()
        r = s.post("https://kite.zerodha.com/api/login", data={"user_id": user_id, "password": password})
        rid = r.json()["data"]["request_id"]
        totp = pyotp.TOTP(totp_secret).now()
        s.post("https://kite.zerodha.com/api/twofa", data={"user_id": user_id, "request_id": rid, "twofa_value": totp, "twofa_type": "totp"})
        r = s.get(f"https://kite.trade/connect/login?v=3&api_key={api_key}", allow_redirects=False)
        loc = r.headers.get("Location", "")
        if "request_token=" in loc:
            rt = loc.split("request_token=")[1].split("&")[0]
            data = kite.generate_session(rt, api_secret=os.getenv("KITE_API_SECRET", ""))
            kite.set_access_token(data["access_token"])
            os.makedirs(os.path.join(_dir, "data"), exist_ok=True)
            with open(access_file, "w") as f:
                json.dump({"date": datetime.now().strftime("%Y-%m-%d"), "access_token": data["access_token"]}, f)
            print("✅ Kite: Fresh login")
            return kite
    except Exception as e:
        print(f"❌ Login: {e}")
    sys.exit(1)


STOCKS = [
    "RELIANCE", "TCS", "INFY", "HDFCBANK", "ICICIBANK",
    "BHARTIARTL", "SBIN", "SUNPHARMA", "LT", "TATAMOTORS",
    "POLYCAB", "PERSISTENT", "TRENT", "ZOMATO", "JINDALSTEL",
    "DLF", "HAL", "IRCTC", "CHOLAFIN", "NHPC",
    "DIXON", "VEDL", "TATAPOWER", "BAJFINANCE", "M&M",
    "ADANIENT", "JSWSTEEL", "CIPLA", "TITAN", "COALINDIA",
]


def compute_indicators(df):
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
    rsi = 100 - (100 / (1 + pd.Series(gain).rolling(14).mean().iloc[-1] / (pd.Series(loss).rolling(14).mean().iloc[-1] + 0.0001)))

    # MACD
    ema12 = pd.Series(c).ewm(span=12).mean()
    ema26 = pd.Series(c).ewm(span=26).mean()
    macd_line = ema12 - ema26
    macd_signal = macd_line.ewm(span=9).mean()
    macd_bull = float(macd_line.iloc[-1]) > float(macd_signal.iloc[-1])
    macd_hist = float(macd_line.iloc[-1] - macd_signal.iloc[-1])
    
    # MACD crossover in last 5 days
    macd_cross = False
    for i in range(-1, -6, -1):
        if len(macd_line) + i > 0 and len(macd_line) + i - 1 > 0:
            if float(macd_line.iloc[i]) > float(macd_signal.iloc[i]) and float(macd_line.iloc[i-1]) <= float(macd_signal.iloc[i-1]):
                macd_cross = True
                break

    # EMAs
    ema9 = float(pd.Series(c).ewm(span=9).mean().iloc[-1])
    ema21 = float(pd.Series(c).ewm(span=21).mean().iloc[-1])
    ema_bull = ema9 > ema21

    # MAs
    ma20 = float(pd.Series(c).rolling(20).mean().iloc[-1])
    ma50 = float(pd.Series(c).rolling(50).mean().iloc[-1])
    ma200 = float(pd.Series(c).rolling(min(200, len(c))).mean().iloc[-1])

    # ATR
    tr_arr = np.maximum(h[1:] - lo[1:], np.maximum(np.abs(h[1:] - c[:-1]), np.abs(lo[1:] - c[:-1])))
    tr_series = np.concatenate([[h[0]-lo[0]], tr_arr])
    atr = float(pd.Series(tr_series).rolling(14).mean().iloc[-1])

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

    # Volume
    vol_avg = float(pd.Series(v).rolling(20).mean().iloc[-1])
    vol_surge = float(v[-1] / (vol_avg + 1))

    # Supertrend
    st_atr = float(pd.Series(tr_series).rolling(10).mean().iloc[-1])
    hl2 = (h[-1] + lo[-1]) / 2
    st_lower = hl2 - 3 * st_atr
    supertrend_bull = price > st_lower

    # VWAP
    typical = (h + lo + c) / 3
    vwap = float((pd.Series(typical * v).rolling(20).sum() / (pd.Series(v).rolling(20).sum() + 1)).iloc[-1])
    vwap_bull = price > vwap

    # OBV
    try:
        sign_s = pd.Series(c).diff().fillna(0).apply(lambda x: 1 if x > 0 else (-1 if x < 0 else 0))
        obv = (pd.Series(v) * sign_s).cumsum()
        obv_bull = float(obv.iloc[-1]) > float(obv.rolling(20).mean().iloc[-1])
    except:
        obv_bull = True

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

    # Bollinger
    bb_std = float(pd.Series(c).rolling(20).std().iloc[-1])
    bb_squeeze = (bb_std * 2 / (ma20 + 0.01) * 100) < 8

    # 52W
    w52h = float(pd.Series(h).rolling(min(252, len(h))).max().iloc[-1])
    near_52h = price >= w52h * 0.95

    # Returns
    ret_1w = (c[-1] / c[-5] - 1) * 100 if len(c) > 5 else 0
    ret_1m = (c[-1] / c[-21] - 1) * 100 if len(c) > 21 else 0
    ret_3m = (c[-1] / c[-63] - 1) * 100 if len(c) > 63 else 0

    # DVM
    dvm = 0
    if 40 < rsi < 65: dvm += 6
    elif 30 < rsi <= 40: dvm += 3
    if macd_bull and 35 < rsi < 70: dvm += 10
    if macd_bull and mfi_bull: dvm += 5
    if macd_bull: dvm += 4
    if macd_cross: dvm += 3
    if ema_bull: dvm += 4
    if supertrend_bull: dvm += 8
    if adx > 25: dvm += 5
    if adx > 35: dvm += 2
    if vwap_bull: dvm += 4
    if ma50 > ma200: dvm += 5
    if price > ma20: dvm += 3
    if vol_surge > 1.2: dvm += 4
    if obv_bull: dvm += 3
    if not (rsi > 80): dvm += 2
    if near_52h: dvm += 2
    if bb_squeeze: dvm += 2
    if ret_3m > 0: dvm += 2
    if rsi > 72: dvm -= 4
    if mfi > 80 and rsi > 70: dvm -= 3
    dvm = max(0, min(100, dvm))

    # Weekly DVM
    wdvm = 0
    try:
        wk_c = c[::5]
        if len(wk_c) >= 8:
            wp = wk_c[-1]; wm5 = np.mean(wk_c[-5:]); wm10 = np.mean(wk_c[-10:]) if len(wk_c) >= 10 else wm5
            wd = np.diff(wk_c, prepend=wk_c[0])
            wg = np.mean(np.where(wd[-5:] > 0, wd[-5:], 0))
            wl = np.mean(np.where(wd[-5:] < 0, -wd[-5:], 0)) + 0.0001
            wrsi = 100 - (100 / (1 + wg / wl))
            if wp > wm5: wdvm += 18
            if wm5 > wm10: wdvm += 18
            if 35 < wrsi < 72: wdvm += 16
            if wp > wk_c[-2]: wdvm += 12
            if len(wk_c) >= 4 and wk_c[-1] > wk_c[-4]: wdvm += 12
            if wrsi > 78: wdvm -= 10
            if wp < wm10: wdvm -= 8
    except:
        wdvm = int(dvm * 0.65)
    wdvm = max(0, min(100, wdvm))

    # Swing signal count
    sb = sum([macd_bull, ma50 > ma200, supertrend_bull, 30 < rsi < 65,
              near_52h, obv_bull, mfi_bull, vwap_bull, price > (h[-2]+lo[-2]+c[-2])/3])

    return {
        "dvm": dvm, "wdvm": wdvm, "price": price, "atr": atr,
        "rsi": rsi, "adx": adx, "vol": vol_surge, "macd_bull": macd_bull,
        "macd_cross": macd_cross, "ema_bull": ema_bull,
        "supertrend": supertrend_bull, "sb": sb,
        "ma50_200": ma50 > ma200, "above_ma20": price > ma20,
        "ret_1w": ret_1w, "ret_1m": ret_1m, "near_52h": near_52h,
    }


def run_variation(stock_data, name, config):
    """Run one backtest variation with given config."""
    capital = 70000.0
    total_injected = 70000.0
    positions = {}
    trades = []
    equity = []
    monthly = []
    peak = capital
    max_dd = 0
    blacklist = {}  # sym -> unblock_day
    
    min_len = min(len(df) for df in stock_data.values())
    bt_days = min(min_len - 50, 500)
    
    current_month = None
    m_start = capital; m_pnl = 0; m_trades = 0
    
    for di in range(50, 50 + bt_days):
        sample = list(stock_data.values())[0]
        td = str(sample.iloc[di]["date"])[:7] if di < len(sample) else f"M{di//22}"
        
        if td != current_month:
            if current_month:
                mr = m_pnl / m_start * 100 if m_start > 0 else 0
                monthly.append({"month": current_month, "start": round(m_start),
                               "pnl": round(m_pnl), "ret": round(mr, 2), "trades": m_trades})
            current_month = td
            m_start = capital; m_pnl = 0; m_trades = 0
            capital += 15000; total_injected += 15000
        
        capital += 5000; total_injected += 5000
        
        # DD cap
        if m_pnl < 0 and abs(m_pnl) > m_start * config["dd_cap"]:
            pos_val = sum(p["qty"] * float(stock_data[s].iloc[di]["close"])
                         for s, p in positions.items() if di < len(stock_data.get(s, pd.DataFrame())))
            equity.append(capital + pos_val)
            continue
        
        # ═══ MANAGE POSITIONS ═══
        for sym in list(positions.keys()):
            pos = positions[sym]
            if sym not in stock_data or di >= len(stock_data[sym]):
                continue
            
            cp = float(stock_data[sym].iloc[di]["close"])
            hp = float(stock_data[sym].iloc[di]["high"])
            lp = float(stock_data[sym].iloc[di]["low"])
            ep = pos["entry_price"]
            atr = pos["atr"]
            days = di - pos["entry_day"]
            gain = (cp - ep) / ep * 100
            
            # Track intraday high
            if hp > pos["highest"]: pos["highest"] = hp
            peak_gain = (pos["highest"] - ep) / ep * 100
            
            exit_r = None; exit_p = cp
            
            # ═══ VARIATION-SPECIFIC EXIT LOGIC ═══
            
            # Check if intraday low hit SL
            if lp <= pos["sl"]:
                exit_r = "Stop Loss"
                exit_p = pos["sl"]
            # Check if intraday high hit T2
            elif hp >= pos["t2"]:
                exit_r = "Target 2"
                exit_p = pos["t2"]
            # Check if intraday high hit T1 (partial)
            elif hp >= pos["t1"] and not pos.get("partial"):
                pq = max(1, int(pos["qty"] * config["partial_pct"]))
                pp = (pos["t1"] - ep) * pq
                pos["qty"] -= pq
                pos["partial"] = True
                pos["partial_pnl"] = pp
                capital += pp + pq * ep
                # Move SL up based on variation
                pos["sl"] = max(pos["sl"], ep * (1 + config["post_t1_sl_lock"]))
                continue
            # Dynamic trailing
            elif peak_gain >= config["trail_start_pct"]:
                # ATR-based trailing stop
                trail_sl = pos["highest"] - config["trail_atr_mult"] * atr
                # Percentage-based floor
                pct_sl = ep * (1 + peak_gain * config["trail_lock_ratio"] / 100)
                new_sl = max(trail_sl, pct_sl)
                if new_sl > pos["sl"]:
                    pos["sl"] = new_sl
                # Check if trailed out
                if lp <= pos["sl"] and pos["sl"] > ep:
                    exit_r = "Trail"
                    exit_p = pos["sl"]
            # Dead money
            elif days >= config["dead_days"] and gain < config["dead_pct"]:
                exit_r = "Dead Money"
            # Maximum hold
            elif days >= config.get("max_hold", 60):
                exit_r = "Max Hold"
            
            if exit_r:
                pnl = (exit_p - ep) * pos["qty"] + pos.get("partial_pnl", 0)
                capital += (exit_p - ep) * pos["qty"] + pos["qty"] * ep
                trades.append({"sym": sym, "entry": round(ep, 2), "exit": round(exit_p, 2),
                              "qty": pos["orig_qty"], "pnl": round(pnl, 2),
                              "pct": round(pnl / (pos["orig_qty"] * ep) * 100, 2),
                              "days": days, "reason": exit_r, "dvm": pos["dvm"], "wdvm": pos["wdvm"]})
                m_pnl += pnl; m_trades += 1
                del positions[sym]
                # BLACKLIST on loss
                if pnl < 0:
                    blacklist[sym] = di + config["cooldown_days"]
        
        # ═══ SCAN FOR ENTRIES ═══
        if len(positions) < config["max_pos"]:
            candidates = []
            for sym, df in stock_data.items():
                if sym in positions or di >= len(df):
                    continue
                # Blacklist check
                if sym in blacklist and di < blacklist[sym]:
                    continue
                
                hist = df.iloc[:di+1]
                if len(hist) < 50:
                    continue
                
                ind = compute_indicators(hist)
                if ind is None:
                    continue
                
                # ═══ VARIATION-SPECIFIC ENTRY FILTERS ═══
                if ind["dvm"] < config["dvm_min"]:
                    continue
                if ind["wdvm"] < config["wdvm_min"]:
                    continue
                if ind["vol"] < config["vol_min"]:
                    continue
                if not ind["macd_bull"]:
                    continue
                if not ind["supertrend"]:
                    continue
                if ind["adx"] < config["adx_min"]:
                    continue
                if ind["sb"] < config["swing_signals_min"]:
                    continue
                
                # Additional filters per variation
                if config.get("require_macd_cross") and not ind["macd_cross"]:
                    continue
                if config.get("require_above_ma20") and not ind["above_ma20"]:
                    continue
                if config.get("require_ema_bull") and not ind["ema_bull"]:
                    continue
                if config.get("require_positive_1w") and ind["ret_1w"] <= 0:
                    continue
                if config.get("min_rsi") and ind["rsi"] < config["min_rsi"]:
                    continue
                if config.get("max_rsi") and ind["rsi"] > config["max_rsi"]:
                    continue
                
                candidates.append((sym, ind))
            
            candidates.sort(key=lambda x: x[1]["dvm"] + x[1]["wdvm"] * 0.3 + x[1]["adx"] * 0.2, reverse=True)
            
            for sym, ind in candidates[:config["max_pos"] - len(positions)]:
                price = ind["price"]; atr = ind["atr"]
                # SL width from config
                sl_pct = min(max(atr * config["sl_atr_mult"] / price, 0.005), config["sl_max_pct"])
                sl = price * (1 - sl_pct)
                
                pos_pct = config["pos_pct"]
                qty = max(1, int(capital * pos_pct / price))
                cost = qty * price
                if cost > capital * pos_pct:
                    qty = max(1, int(capital * pos_pct / price))
                    cost = qty * price
                if cost > capital * 0.90 or qty <= 0:
                    continue
                
                positions[sym] = {
                    "entry_price": price, "qty": qty, "orig_qty": qty,
                    "cost": cost, "sl": sl,
                    "t1": price + config["t1_atr"] * atr,
                    "t2": price + config["t2_atr"] * atr,
                    "atr": atr, "entry_day": di, "highest": price,
                    "dvm": ind["dvm"], "wdvm": ind["wdvm"],
                }
                capital -= cost
        
        # Equity
        pos_val = sum(p["qty"] * float(stock_data[s].iloc[di]["close"])
                      for s, p in positions.items() if di < len(stock_data.get(s, pd.DataFrame())))
        total_eq = capital + pos_val
        equity.append(total_eq)
        if total_eq > peak: peak = total_eq
        dd = (peak - total_eq) / peak * 100
        if dd > max_dd: max_dd = dd
    
    # Close remaining
    for sym, pos in list(positions.items()):
        lp = float(stock_data[sym].iloc[-1]["close"])
        pnl = (lp - pos["entry_price"]) * pos["qty"] + pos.get("partial_pnl", 0)
        capital += (lp - pos["entry_price"]) * pos["qty"] + pos["qty"] * pos["entry_price"]
        trades.append({"sym": sym, "entry": round(pos["entry_price"], 2), "exit": round(lp, 2),
                      "qty": pos["orig_qty"], "pnl": round(pnl, 2),
                      "pct": round(pnl / (pos["orig_qty"] * pos["entry_price"]) * 100, 2),
                      "days": bt_days, "reason": "End", "dvm": pos["dvm"], "wdvm": pos["wdvm"]})
    
    if current_month:
        mr = m_pnl / m_start * 100 if m_start > 0 else 0
        monthly.append({"month": current_month, "start": round(m_start),
                       "pnl": round(m_pnl), "ret": round(mr, 2), "trades": m_trades})
    
    return trades, monthly, equity, capital, total_injected, max_dd


# ═══ THREE VARIATIONS ═══

VARIATION_A = {
    "name": "A: HIGH WIN RATE (Tighter Entry)",
    "dvm_min": 78,           # RAISED from 73 — only strong confluence
    "wdvm_min": 68,          # RAISED from 61 — strong weekly confirmation
    "vol_min": 1.5,          # RAISED from 1.3 — need real institutional volume
    "adx_min": 25,           # RAISED from 20 — confirmed trend only
    "swing_signals_min": 6,  # RAISED from 4 — need 6/9 signals
    "require_macd_cross": True,  # NEW — must have fresh MACD crossover
    "require_above_ma20": True,  # NEW — price above 20-day MA
    "require_ema_bull": True,    # NEW — EMA9 > EMA21
    "require_positive_1w": True, # NEW — positive 1-week return
    "min_rsi": 40,           # RSI floor
    "max_rsi": 68,           # RSI ceiling (avoid overbought)
    "sl_atr_mult": 2.0,     # WIDER SL: 2× ATR (was 1× — too tight!)
    "sl_max_pct": 0.025,    # Max 2.5% SL
    "t1_atr": 3.0,          # TIGHTER T1: 3× ATR (more reachable)
    "t2_atr": 6.0,          # TIGHTER T2: 6× ATR
    "partial_pct": 0.50,    # Sell 50% at T1 (take profits!)
    "post_t1_sl_lock": 0.005, # Lock +0.5% after T1 hit
    "trail_start_pct": 1.5, # Start trailing at +1.5%
    "trail_atr_mult": 1.5,  # Trail at 1.5× ATR below high
    "trail_lock_ratio": 50, # Lock 50% of peak gain
    "dead_days": 12,        # Exit dead money at 12 days
    "dead_pct": 1.5,        # Need 1.5% in 12 days
    "max_hold": 30,         # Maximum 30 day hold
    "cooldown_days": 25,    # 25-day blacklist after loss
    "pos_pct": 0.30,        # 30% per position (conservative)
    "max_pos": 3,
    "dd_cap": 0.09,
}

VARIATION_B = {
    "name": "B: BIG WINNERS (Wider Targets)",
    "dvm_min": 73,           # Keep v24 threshold
    "wdvm_min": 61,          # Keep v24 threshold
    "vol_min": 1.3,          # Keep
    "adx_min": 22,           # Slightly raised
    "swing_signals_min": 5,  # 5/9 signals
    "require_macd_cross": False,
    "require_above_ma20": True,
    "require_ema_bull": False,
    "require_positive_1w": False,
    "min_rsi": 35,
    "max_rsi": 70,
    "sl_atr_mult": 2.5,     # VERY WIDE SL: 2.5× ATR — survive pullbacks
    "sl_max_pct": 0.035,    # Max 3.5% SL
    "t1_atr": 5.0,          # WIDE T1: 5× ATR
    "t2_atr": 12.0,         # VERY WIDE T2: 12× ATR — let winners run
    "partial_pct": 0.25,    # Only sell 25% at T1 — keep riding
    "post_t1_sl_lock": 0.01,# Lock +1% after T1
    "trail_start_pct": 2.0, # Start trailing at +2%
    "trail_atr_mult": 2.0,  # Wide trail: 2× ATR
    "trail_lock_ratio": 40, # Lock 40% of peak gain
    "dead_days": 20,        # Patient — hold 20 days
    "dead_pct": 2.0,
    "max_hold": 45,         # Maximum 45 day hold
    "cooldown_days": 20,    # 20-day blacklist
    "pos_pct": 0.35,        # 35% per position
    "max_pos": 3,
    "dd_cap": 0.09,
}

VARIATION_C = {
    "name": "C: BALANCED (Risk-Adjusted)",
    "dvm_min": 76,           # Moderate raise
    "wdvm_min": 65,          # Moderate raise
    "vol_min": 1.4,
    "adx_min": 23,
    "swing_signals_min": 5,
    "require_macd_cross": False,
    "require_above_ma20": True,
    "require_ema_bull": True,
    "require_positive_1w": False,
    "min_rsi": 38,
    "max_rsi": 68,
    "sl_atr_mult": 2.0,     # 2× ATR SL
    "sl_max_pct": 0.028,    # Max 2.8% SL
    "t1_atr": 4.0,          # Standard T1: 4× ATR
    "t2_atr": 8.0,          # Standard T2: 8× ATR
    "partial_pct": 0.35,    # 35% at T1
    "post_t1_sl_lock": 0.008, # Lock +0.8% after T1
    "trail_start_pct": 1.5,
    "trail_atr_mult": 1.8,  # 1.8× ATR trail
    "trail_lock_ratio": 45,
    "dead_days": 15,
    "dead_pct": 2.0,
    "max_hold": 35,
    "cooldown_days": 22,
    "pos_pct": 0.35,
    "max_pos": 3,
    "dd_cap": 0.09,
}


def print_results(name, trades, monthly, equity, capital, invested, max_dd):
    total_pnl = sum(t["pnl"] for t in trades)
    wins = [t for t in trades if t["pnl"] > 0]
    losses = [t for t in trades if t["pnl"] <= 0]
    wr = round(len(wins)/len(trades)*100, 1) if trades else 0
    
    rets = [m["ret"] for m in monthly]
    avg_r = np.mean(rets) if rets else 0
    std_r = np.std(rets) if rets else 1
    sharpe = (avg_r / std_r) * np.sqrt(12) if std_r > 0 else 0
    annual = ((1 + avg_r/100)**12 - 1) * 100
    
    print(f"\n{'═'*60}")
    print(f"  {name}")
    print(f"{'═'*60}")
    print(f"  Trades: {len(trades)} | Wins: {len(wins)} | Losses: {len(losses)} | WR: {wr}%")
    if wins: print(f"  Avg Win: ₹{np.mean([t['pnl'] for t in wins]):+,.0f}")
    if losses: print(f"  Avg Loss: ₹{np.mean([t['pnl'] for t in losses]):+,.0f}")
    if wins and losses:
        wlr = abs(np.mean([t['pnl'] for t in wins]) / (np.mean([t['pnl'] for t in losses]) + 0.01))
        print(f"  Win:Loss Ratio: {wlr:.1f}:1")
    print(f"  Trading P&L: ₹{total_pnl:+,.0f}")
    print(f"  Monthly Return: {avg_r:+.2f}% | Annual: {annual:+.1f}%")
    print(f"  Max Drawdown: {max_dd:.2f}% | Sharpe: {sharpe:.2f}")
    print(f"  Invested: ₹{invested:,.0f} | Final: ₹{capital:,.0f}")
    print(f"  Trading Return: {total_pnl/invested*100:+.2f}%")
    
    # Exit analysis
    reasons = {}
    for t in trades:
        r = t["reason"]
        if r not in reasons: reasons[r] = {"cnt": 0, "pnl": 0}
        reasons[r]["cnt"] += 1; reasons[r]["pnl"] += t["pnl"]
    
    print(f"\n  Exit Analysis:")
    for r in sorted(reasons, key=lambda x: reasons[x]["pnl"], reverse=True):
        d = reasons[r]
        print(f"    {r:<15} {d['cnt']:>3} trades  ₹{d['pnl']:>+10,.0f}")
    
    # Individual trades
    if trades:
        print(f"\n  Trade Log:")
        print(f"  {'#':<3} {'Stock':<12} {'Entry':>7} {'Exit':>7} {'P&L':>9} {'%':>6} {'Days':>4} {'DVM':>4} {'Reason'}")
        for i, t in enumerate(trades, 1):
            print(f"  {i:<3} {t['sym']:<12} ₹{t['entry']:>5,.0f} ₹{t['exit']:>5,.0f} ₹{t['pnl']:>+7,.0f} {t['pct']:>+5.1f}% {t['days']:>4} {t['dvm']:>4} {t['reason']}")
    
    # Monthly
    if monthly:
        pos_months = sum(1 for m in monthly if m["ret"] > 0)
        neg_months = sum(1 for m in monthly if m["ret"] < 0)
        print(f"\n  Months: {len(monthly)} total | {pos_months} positive | {neg_months} negative")
    
    return {"name": name, "trades": len(trades), "wr": wr, "pnl": total_pnl,
            "monthly_ret": avg_r, "annual": annual, "max_dd": max_dd,
            "sharpe": sharpe, "final": capital, "invested": invested}


def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  GLOBAL EYE v24 — BACKTEST v3: THREE VARIATIONS            ║")
    print("║  Root cause fixes: Wider SL, Blacklist, Better Trailing     ║")
    print("║  30 Stocks | 2 Years | ₹70K + ₹5K/day + ₹15K/month       ║")
    print("╚══════════════════════════════════════════════════════════════╝\n")
    
    kite = kite_login()
    
    print("Loading instruments...")
    instruments = kite.instruments("NSE")
    token_map = {}
    for inst in instruments:
        sym = inst.get("tradingsymbol", "")
        if sym in STOCKS and inst.get("instrument_type") in ("EQ", ""):
            token_map[sym] = inst["instrument_token"]
    
    print(f"Found: {len([s for s in STOCKS if s in token_map])}/{len(STOCKS)}")
    
    print("Fetching data...")
    end_dt = datetime.now().strftime("%Y-%m-%d")
    start_dt = (datetime.now() - timedelta(days=730)).strftime("%Y-%m-%d")
    
    stock_data = {}
    for sym in STOCKS:
        if sym not in token_map:
            continue
        try:
            data = kite.historical_data(token_map[sym], start_dt, end_dt, "day")
            if data and len(data) >= 100:
                stock_data[sym] = pd.DataFrame(data)
                print(f"  ✅ {sym}: {len(data)} days")
            time.sleep(0.35)
        except Exception as e:
            print(f"  ❌ {sym}: {e}")
            time.sleep(1)
    
    print(f"\n{len(stock_data)} stocks loaded.\n")
    
    # Run all three variations
    results = []
    for config in [VARIATION_A, VARIATION_B, VARIATION_C]:
        print(f"\nRunning {config['name']}...")
        trades, monthly, equity, capital, invested, max_dd = run_variation(stock_data, config["name"], config)
        r = print_results(config["name"], trades, monthly, equity, capital, invested, max_dd)
        results.append(r)
    
    # Comparison table
    print(f"\n{'═'*70}")
    print(f"  COMPARISON TABLE")
    print(f"{'═'*70}")
    print(f"{'Metric':<20} {'A: High WR':>15} {'B: Big Wins':>15} {'C: Balanced':>15}")
    print(f"{'─'*70}")
    for metric, key in [("Trades", "trades"), ("Win Rate", "wr"), ("Trading P&L", "pnl"),
                         ("Monthly Return", "monthly_ret"), ("Annual Return", "annual"),
                         ("Max Drawdown", "max_dd"), ("Sharpe Ratio", "sharpe"),
                         ("Final Portfolio", "final")]:
        vals = []
        for r in results:
            v = r[key]
            if key == "pnl" or key == "final" or key == "invested":
                vals.append(f"₹{v:>+10,.0f}" if key == "pnl" else f"₹{v:>10,.0f}")
            elif key in ("wr", "monthly_ret", "annual", "max_dd"):
                vals.append(f"{v:>+.1f}%" if key != "wr" else f"{v:.1f}%")
            elif key == "sharpe":
                vals.append(f"{v:.2f}")
            else:
                vals.append(f"{v}")
        print(f"  {metric:<20} {vals[0]:>15} {vals[1]:>15} {vals[2]:>15}")
    
    # Recommendation
    best = max(results, key=lambda x: x["pnl"])
    safest = min(results, key=lambda x: x["max_dd"])
    print(f"\n  🏆 Highest P&L: {best['name']}")
    print(f"  🛡️ Lowest Risk: {safest['name']}")
    
    print(f"\n{'═'*70}")
    print(f"  KEY FIXES APPLIED (vs v2 baseline that lost ₹25,348):")
    print(f"  1. SL widened from 1×ATR to 2-2.5×ATR — stops survive normal noise")
    print(f"  2. BLACKLIST: 20-25 day cooldown after loss (no JSWSTEEL 4x repeat)")
    print(f"  3. INTRADAY HIGH/LOW used for T1/T2 (v2 only checked close price)")
    print(f"  4. TRAILING RATCHET: ATR-based dynamic trail (v2 had none)")
    print(f"  5. RANKING: DVM + weekly DVM + ADX composite (v2 used DVM only)")
    print(f"  6. MAX HOLD: 30-45 day cap (v2 could hold forever)")
    print(f"{'═'*70}")
    print(f"  DISCLAIMER: Historical backtest on real Kite OHLCV data.")
    print(f"  Past performance ≠ future results. Slippage not included.")
    print(f"{'═'*70}")


if __name__ == "__main__":
    main()
