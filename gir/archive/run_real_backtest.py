#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  GLOBAL EYE v24.0.0 — REAL BACKTEST ON KITE HISTORICAL DATA
  
  Run this ON YOUR DROPLET (not here — needs Kite API access):
  
    cd /home/globalbot/
    python3 run_real_backtest.py
  
  This uses ACTUAL Kite historical OHLCV data for 10 NSE stocks
  over 2 years, applies all v24 parameters (DVM scoring, multi-TF
  gate, trailing ratchet, Kelly sizing), and reports real metrics.
  
  Capital: ₹70,000 start + ₹5,000/day + ₹15,000/month
═══════════════════════════════════════════════════════════════
"""

import os, sys, time, json, math
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load .env for Kite credentials
_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_dir, ".env"))

from kiteconnect import KiteConnect
import pyotp

# ═══ KITE LOGIN ═══
def kite_login():
    """Auto-login to Kite using .env credentials."""
    api_key = os.getenv("KITE_API_KEY", "")
    api_secret = os.getenv("KITE_API_SECRET", "")
    totp_secret = os.getenv("KITE_TOTP_SECRET", "")
    user_id = os.getenv("ZERODHA_USER_ID", "")
    password = os.getenv("ZERODHA_PASSWORD", "")
    
    if not all([api_key, api_secret]):
        print("❌ KITE_API_KEY or KITE_API_SECRET missing from .env")
        sys.exit(1)
    
    kite = KiteConnect(api_key=api_key)
    
    # Try to load cached access token
    access_file = os.path.join(_dir, "data", "kite_access.json")
    try:
        if os.path.exists(access_file):
            with open(access_file) as f:
                cached = json.load(f)
            if cached.get("date") == datetime.now().strftime("%Y-%m-%d"):
                kite.set_access_token(cached["access_token"])
                # Test the token
                kite.profile()
                print("✅ Kite: Using cached session")
                return kite
    except Exception:
        pass
    
    # Fresh login
    try:
        import requests
        session = requests.Session()
        
        # Step 1: Login
        login_url = "https://kite.zerodha.com/api/login"
        r = session.post(login_url, data={"user_id": user_id, "password": password})
        request_id = r.json().get("data", {}).get("request_id", "")
        
        if not request_id:
            print("❌ Kite login failed — check ZERODHA_USER_ID and ZERODHA_PASSWORD")
            sys.exit(1)
        
        # Step 2: TOTP
        totp = pyotp.TOTP(totp_secret).now()
        r = session.post("https://kite.zerodha.com/api/twofa", data={
            "user_id": user_id, "request_id": request_id, "twofa_value": totp,
            "twofa_type": "totp"
        })
        
        # Step 3: Get request token from redirect
        r = session.get(f"https://kite.trade/connect/login?v=3&api_key={api_key}", allow_redirects=False)
        location = r.headers.get("Location", "")
        
        if "request_token=" not in location:
            # Try alternate method
            r = session.get(f"https://kite.trade/connect/login?api_key={api_key}", allow_redirects=True)
            location = r.url
        
        if "request_token=" in location:
            request_token = location.split("request_token=")[1].split("&")[0]
            data = kite.generate_session(request_token, api_secret=api_secret)
            kite.set_access_token(data["access_token"])
            
            # Cache
            os.makedirs(os.path.join(_dir, "data"), exist_ok=True)
            with open(access_file, "w") as f:
                json.dump({"date": datetime.now().strftime("%Y-%m-%d"),
                          "access_token": data["access_token"]}, f)
            
            print("✅ Kite: Fresh login successful")
            return kite
        else:
            print("❌ Could not get request_token — try running the main bot first to login")
            print("   Then re-run this backtest script (it will use the cached session)")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Kite login error: {e}")
        print("   TIP: Start the main bot first (python3 global_eye_v24_STRATEGY5.py)")
        print("   Wait for Telegram 'Kite Login' message, then Ctrl+C and run this script")
        sys.exit(1)


# ═══ v24 PARAMETERS ═══
SCAN_SL = 0.013
MAX_SL = 0.022
KELLY = 0.60
MAX_POS_PCT = 0.40
DVM_SWING = 73
MIN_CONF = 50
VOL_MIN = 1.4
T1_MULT = 4.0
T2_MULT = 8.0
PARTIAL_PCT = 0.35
MONTHLY_DD_CAP = 0.09
DEAD_MONEY_DAYS = 15
DEAD_MONEY_PCT = 2.0
BREAKEVEN_AT = 1.0  # Breakeven at +1%

# ═══ STOCKS TO BACKTEST ═══
STOCKS = ["RELIANCE", "TCS", "INFY", "HDFCBANK", "ICICIBANK",
          "BHARTIARTL", "TATAMOTORS", "SUNPHARMA", "LT", "SBIN"]

# ═══ DVM SCORING (simplified version of the 25-indicator system) ═══
def compute_dvm(df):
    """Compute DVM score from OHLCV DataFrame. Returns score 0-100."""
    if len(df) < 50:
        return 0, {}
    
    c = df["close"].values
    h = df["high"].values
    lo = df["low"].values
    v = df["volume"].values
    price = c[-1]
    
    dvm = 0
    details = {}
    
    # RSI (14)
    delta = np.diff(c, prepend=c[0])
    gain = np.where(delta > 0, delta, 0)
    loss = np.where(delta < 0, -delta, 0)
    avg_gain = pd.Series(gain).rolling(14).mean().iloc[-1]
    avg_loss = pd.Series(loss).rolling(14).mean().iloc[-1]
    rs = avg_gain / (avg_loss + 0.0001)
    rsi = 100 - (100 / (1 + rs))
    details["rsi"] = round(rsi, 1)
    
    if 40 < rsi < 65: dvm += 6
    elif 30 < rsi <= 40: dvm += 3
    
    # MACD
    ema12 = pd.Series(c).ewm(span=12).mean().iloc[-1]
    ema26 = pd.Series(c).ewm(span=26).mean().iloc[-1]
    macd = ema12 - ema26
    macd_signal = pd.Series(pd.Series(c).ewm(span=12).mean() - pd.Series(c).ewm(span=26).mean()).ewm(span=9).mean().iloc[-1]
    macd_bull = macd > macd_signal
    details["macd_bull"] = macd_bull
    
    if macd_bull and 35 < rsi < 70: dvm += 10
    if macd_bull: dvm += 4
    
    # EMA 9/21
    ema9 = pd.Series(c).ewm(span=9).mean().iloc[-1]
    ema21 = pd.Series(c).ewm(span=21).mean().iloc[-1]
    ema_bull = ema9 > ema21
    if ema_bull: dvm += 4
    
    # Moving averages
    ma20 = pd.Series(c).rolling(20).mean().iloc[-1]
    ma50 = pd.Series(c).rolling(50).mean().iloc[-1]
    ma200 = pd.Series(c).rolling(min(200, len(c))).mean().iloc[-1]
    
    if ma50 > ma200: dvm += 5
    if price > ma20: dvm += 3
    
    # Supertrend (simplified)
    tr = np.maximum(h[1:] - lo[1:], np.maximum(np.abs(h[1:] - c[:-1]), np.abs(lo[1:] - c[:-1])))
    atr14 = pd.Series(np.concatenate([[0], tr])).rolling(14).mean().iloc[-1]
    hl2 = (h[-1] + lo[-1]) / 2
    st_lower = hl2 - 3 * atr14
    supertrend_bull = price > st_lower
    if supertrend_bull: dvm += 8
    details["supertrend"] = supertrend_bull
    
    # ADX (simplified)
    try:
        plus_dm = pd.Series(h).diff().clip(lower=0)
        minus_dm = (-pd.Series(lo).diff()).clip(lower=0)
        plus_dm = plus_dm.where(plus_dm > minus_dm, 0)
        minus_dm = minus_dm.where(minus_dm > plus_dm, 0)
        tr14 = pd.Series(np.concatenate([[0], tr])).rolling(14).sum() + 0.0001
        plus_di = 100 * plus_dm.rolling(14).sum() / tr14
        minus_di = 100 * minus_dm.rolling(14).sum() / tr14
        dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 0.0001)
        adx = dx.rolling(14).mean().iloc[-1]
    except:
        adx = 20
    details["adx"] = round(adx, 1)
    
    if adx > 25: dvm += 5
    if adx > 35: dvm += 2
    
    # Volume
    vol_avg = pd.Series(v).rolling(20).mean().iloc[-1]
    vol_surge = v[-1] / (vol_avg + 1)
    details["vol_surge"] = round(vol_surge, 2)
    if vol_surge > 1.2: dvm += 4
    
    # VWAP proxy
    typical = (h + lo + c) / 3
    vwap = (pd.Series(typical * v).rolling(20).sum() / (pd.Series(v).rolling(20).sum() + 1)).iloc[-1]
    if price > vwap: dvm += 4
    
    # MFI
    try:
        tp = pd.Series((h + lo + c) / 3)
        raw_mf = tp * pd.Series(v)
        pos_mf = raw_mf.where(tp.diff() > 0, 0).rolling(14).sum()
        neg_mf = raw_mf.where(tp.diff() <= 0, 0).rolling(14).sum()
        mfi = (100 - (100 / (1 + pos_mf / (neg_mf + 1)))).iloc[-1]
        if macd_bull and 20 < mfi < 80: dvm += 5
    except:
        pass
    
    # Bollinger
    bb_mid = pd.Series(c).rolling(20).mean().iloc[-1]
    bb_std = pd.Series(c).rolling(20).std().iloc[-1]
    bb_squeeze = (bb_std * 2 / bb_mid * 100) < 8
    if bb_squeeze: dvm += 2
    
    # Returns
    if len(c) > 63:
        ret_3m = (c[-1] / c[-63] - 1) * 100
        if ret_3m > 0: dvm += 2
    
    # Fundamentals (can't get from OHLCV — skip, +0)
    
    # Penalties
    if rsi > 72: dvm -= 4
    
    dvm = max(0, min(100, dvm))
    details["dvm"] = dvm
    
    # ATR for targets
    details["atr"] = atr14
    details["price"] = price
    details["ma20"] = ma20
    details["ma50"] = ma50
    details["ma200"] = ma200
    
    return dvm, details


def compute_weekly_dvm(df):
    """Compute weekly DVM from daily OHLCV."""
    if len(df) < 50:
        return 0
    
    c = df["close"].values
    
    # Resample to weekly
    wk_c = c[::5]
    if len(wk_c) < 8:
        return 0
    
    wdvm = 0
    wk_price = wk_c[-1]
    wk_ma5 = np.mean(wk_c[-5:])
    wk_ma10 = np.mean(wk_c[-10:]) if len(wk_c) >= 10 else wk_ma5
    
    # Weekly RSI
    wk_delta = np.diff(wk_c, prepend=wk_c[0])
    wk_gain = np.where(wk_delta > 0, wk_delta, 0)
    wk_loss = np.where(wk_delta < 0, -wk_delta, 0)
    wk_avg_gain = np.mean(wk_gain[-5:])
    wk_avg_loss = np.mean(wk_loss[-5:]) + 0.0001
    wk_rsi = 100 - (100 / (1 + wk_avg_gain / wk_avg_loss))
    
    if wk_price > wk_ma5: wdvm += 18
    if wk_ma5 > wk_ma10: wdvm += 18
    if 35 < wk_rsi < 72: wdvm += 16
    if wk_price > wk_c[-2]: wdvm += 12
    if len(wk_c) >= 4 and wk_c[-1] > wk_c[-4]: wdvm += 12
    
    if wk_rsi > 78: wdvm -= 10
    if wk_price < wk_ma10: wdvm -= 8
    
    return max(0, min(100, wdvm))


# ═══ MAIN BACKTEST ═══
def run_backtest():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  GLOBAL EYE v24.0.0 — REAL KITE DATA BACKTEST              ║")
    print("║  ₹70,000 start + ₹5,000/day + ₹15,000/month              ║")
    print("║  Period: 2 years of actual NSE OHLCV data                   ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    # Login to Kite
    print("Connecting to Kite...")
    kite = kite_login()
    
    # Get instrument tokens
    print("Loading instruments...")
    instruments = kite.instruments("NSE")
    token_map = {}
    for inst in instruments:
        sym = inst.get("tradingsymbol", "")
        if sym in STOCKS and inst.get("instrument_type") == "EQ":
            token_map[sym] = inst["instrument_token"]
    
    found = [s for s in STOCKS if s in token_map]
    missing = [s for s in STOCKS if s not in token_map]
    print(f"  Found: {len(found)} stocks | Missing: {missing}")
    
    if not found:
        print("❌ No stocks found — check Kite connection")
        return
    
    # Fetch 2 years of historical data for each stock
    print("Fetching 2 years of historical data...")
    end_date = datetime.now().strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=730)).strftime("%Y-%m-%d")
    
    stock_data = {}
    for sym in found:
        try:
            token = token_map[sym]
            data = kite.historical_data(token, start_date, end_date, "day")
            if data and len(data) >= 100:
                df = pd.DataFrame(data)
                stock_data[sym] = df
                print(f"  ✅ {sym}: {len(df)} days loaded")
            else:
                print(f"  ⚠️ {sym}: Only {len(data) if data else 0} days — skipping")
            time.sleep(0.3)  # Rate limit
        except Exception as e:
            print(f"  ❌ {sym}: {e}")
            time.sleep(1)
    
    if not stock_data:
        print("❌ No data loaded — cannot backtest")
        return
    
    print(f"\nData loaded for {len(stock_data)} stocks. Running backtest...\n")
    
    # ═══ BACKTEST ENGINE ═══
    capital = 70000.0
    total_injected = 70000.0
    trades = []
    equity_curve = []
    monthly_results = []
    peak = capital
    max_dd = 0
    
    # Get the common date range
    min_len = min(len(df) for df in stock_data.values())
    backtest_days = min(min_len - 50, 500)  # Need 50 days warmup
    
    if backtest_days < 100:
        print(f"⚠️ Only {backtest_days} backtest days available — need at least 100")
        return
    
    print(f"Backtesting over {backtest_days} trading days (~{backtest_days//22} months)")
    print()
    
    position = None  # One position at a time for simplicity
    month_start_capital = capital
    month_pnl = 0
    current_month = None
    month_trades = 0
    day_count_in_month = 0
    
    for day_idx in range(50, 50 + backtest_days):
        # Track month transitions
        sample_df = list(stock_data.values())[0]
        if day_idx < len(sample_df):
            today = sample_df.iloc[day_idx]["date"]
            if hasattr(today, 'month'):
                this_month = today.strftime("%Y-%m") if hasattr(today, 'strftime') else str(today)[:7]
            else:
                this_month = str(today)[:7]
        else:
            this_month = f"M{day_idx//22}"
        
        if this_month != current_month:
            # New month — record previous month
            if current_month is not None:
                m_ret = (capital - month_start_capital) / month_start_capital * 100 if month_start_capital > 0 else 0
                monthly_results.append({
                    "month": current_month,
                    "start": round(month_start_capital, 0),
                    "end": round(capital, 0),
                    "pnl": round(month_pnl, 0),
                    "ret": round(m_ret, 2),
                    "trades": month_trades,
                })
            current_month = this_month
            month_start_capital = capital
            month_pnl = 0
            month_trades = 0
            day_count_in_month = 0
            
            # Monthly injection
            capital += 15000
            total_injected += 15000
        
        # Daily injection
        capital += 5000
        total_injected += 5000
        day_count_in_month += 1
        
        # Monthly DD check
        if month_pnl < 0 and abs(month_pnl) > month_start_capital * MONTHLY_DD_CAP:
            continue  # Observe mode
        
        # ═══ MANAGE EXISTING POSITION ═══
        if position is not None:
            sym = position["symbol"]
            if sym in stock_data and day_idx < len(stock_data[sym]):
                current_price = stock_data[sym].iloc[day_idx]["close"]
                entry_price = position["entry_price"]
                atr = position["atr"]
                days_held = day_idx - position["entry_day"]
                gain_pct = (current_price - entry_price) / entry_price * 100
                
                # Update highest
                if current_price > position["highest"]:
                    position["highest"] = current_price
                peak_gain = (position["highest"] - entry_price) / entry_price * 100
                
                # ═══ EXIT LOGIC (v24 trailing ratchet) ═══
                exit_reason = None
                exit_price = current_price
                
                # SL check
                if current_price <= position["sl"]:
                    exit_reason = "Stop Loss"
                    exit_price = position["sl"]
                
                # T2 check
                elif current_price >= position["t2"]:
                    exit_reason = "Target 2"
                    exit_price = position["t2"]
                
                # T1 partial
                elif current_price >= position["t1"] and not position.get("partial_done"):
                    # Sell 35% at T1
                    p_qty = max(1, int(position["qty"] * PARTIAL_PCT))
                    p_pnl = (current_price - entry_price) * p_qty
                    position["qty"] -= p_qty
                    position["partial_done"] = True
                    position["partial_pnl"] = p_pnl
                    capital += p_pnl + (p_qty * entry_price)  # Return cost + profit
                    # Move SL to breakeven
                    position["sl"] = entry_price * 1.001
                    continue
                
                # Trailing ratchet (v24)
                elif peak_gain >= 1.0:
                    if peak_gain >= 5:
                        new_sl = entry_price * (1 + peak_gain * 0.007)
                    elif peak_gain >= 3:
                        new_sl = entry_price * 1.015
                    elif peak_gain >= 2:
                        new_sl = entry_price * 1.005
                    else:
                        new_sl = entry_price * 1.001  # Breakeven at +1%
                    
                    if new_sl > position["sl"]:
                        position["sl"] = new_sl
                    
                    # Check if trailed out
                    if current_price <= position["sl"] and position["sl"] > entry_price:
                        exit_reason = "Trailing SL"
                        exit_price = position["sl"]
                
                # Dead money
                elif days_held >= DEAD_MONEY_DAYS and gain_pct < DEAD_MONEY_PCT:
                    exit_reason = f"Dead Money ({days_held}d)"
                
                # Execute exit
                if exit_reason:
                    pnl = (exit_price - entry_price) * position["qty"]
                    partial = position.get("partial_pnl", 0)
                    total_trade_pnl = pnl + partial
                    capital += pnl + (position["qty"] * entry_price)
                    
                    trades.append({
                        "symbol": sym,
                        "entry": round(entry_price, 2),
                        "exit": round(exit_price, 2),
                        "qty": position["original_qty"],
                        "pnl": round(total_trade_pnl, 2),
                        "pnl_pct": round(total_trade_pnl / (position["original_qty"] * entry_price) * 100, 2),
                        "days": days_held,
                        "reason": exit_reason,
                    })
                    month_pnl += total_trade_pnl
                    month_trades += 1
                    position = None
        
        # ═══ SCAN FOR NEW ENTRY ═══
        if position is None:
            best_candidate = None
            best_dvm = 0
            
            for sym, df in stock_data.items():
                if day_idx >= len(df):
                    continue
                
                # Get data up to today (no lookahead)
                hist = df.iloc[:day_idx+1].copy()
                
                if len(hist) < 50:
                    continue
                
                # Compute DVM
                dvm, details = compute_dvm(hist)
                
                # v24 Multi-TF gate
                weekly_dvm = compute_weekly_dvm(hist)
                weekly_threshold = max(DVM_SWING - 12, 50)
                
                if dvm < DVM_SWING:
                    continue
                if weekly_dvm < weekly_threshold:
                    continue
                
                # Volume filter
                if details.get("vol_surge", 0) < VOL_MIN:
                    continue
                
                # ADX filter
                if details.get("adx", 0) < 20:
                    continue
                
                # MACD must be bullish
                if not details.get("macd_bull", False):
                    continue
                
                # Supertrend must be bullish
                if not details.get("supertrend", False):
                    continue
                
                # Best candidate by DVM
                if dvm > best_dvm:
                    best_dvm = dvm
                    best_candidate = (sym, details)
            
            # Enter best candidate
            if best_candidate:
                sym, details = best_candidate
                price = details["price"]
                atr = details["atr"]
                
                # Position sizing (v24 Kelly)
                sl_pct = min(max(atr / price, 0.003), SCAN_SL)
                sl = price * (1 - sl_pct)
                risk = price - sl
                
                pos_capital = capital * MAX_POS_PCT * KELLY
                qty = max(1, int(pos_capital / price))
                cost = qty * price
                
                if cost > capital * MAX_POS_PCT:
                    qty = max(1, int(capital * MAX_POS_PCT / price))
                    cost = qty * price
                
                if cost <= capital * 0.95 and qty > 0:
                    t1 = price + T1_MULT * atr
                    t2 = price + T2_MULT * atr
                    
                    position = {
                        "symbol": sym,
                        "entry_price": price,
                        "qty": qty,
                        "original_qty": qty,
                        "cost": cost,
                        "sl": sl,
                        "t1": t1,
                        "t2": t2,
                        "atr": atr,
                        "entry_day": day_idx,
                        "highest": price,
                        "dvm": best_dvm,
                        "weekly_dvm": compute_weekly_dvm(stock_data[sym].iloc[:day_idx+1]),
                    }
                    capital -= cost
        
        # Equity curve
        pos_value = 0
        if position and position["symbol"] in stock_data:
            if day_idx < len(stock_data[position["symbol"]]):
                curr_p = stock_data[position["symbol"]].iloc[day_idx]["close"]
                pos_value = position["qty"] * curr_p
        
        total_equity = capital + pos_value
        equity_curve.append(total_equity)
        
        if total_equity > peak:
            peak = total_equity
        dd = (peak - total_equity) / peak * 100
        if dd > max_dd:
            max_dd = dd
    
    # Record last month
    if current_month:
        m_ret = (capital - month_start_capital) / month_start_capital * 100 if month_start_capital > 0 else 0
        monthly_results.append({
            "month": current_month, "start": round(month_start_capital, 0),
            "end": round(capital, 0), "pnl": round(month_pnl, 0),
            "ret": round(m_ret, 2), "trades": month_trades,
        })
    
    # Close any open position at last price
    if position:
        sym = position["symbol"]
        last_price = stock_data[sym].iloc[-1]["close"]
        pnl = (last_price - position["entry_price"]) * position["qty"]
        partial = position.get("partial_pnl", 0)
        capital += pnl + (position["qty"] * position["entry_price"])
        trades.append({
            "symbol": sym, "entry": position["entry_price"],
            "exit": round(last_price, 2), "qty": position["original_qty"],
            "pnl": round(pnl + partial, 2),
            "pnl_pct": round((pnl + partial) / (position["original_qty"] * position["entry_price"]) * 100, 2),
            "days": backtest_days - position["entry_day"] + 50,
            "reason": "Backtest End",
        })
    
    # ═══ RESULTS ═══
    print()
    print("═══ PERFORMANCE SUMMARY ═══")
    total_pnl = sum(t["pnl"] for t in trades)
    wins = [t for t in trades if t["pnl"] > 0]
    losses = [t for t in trades if t["pnl"] <= 0]
    
    print(f"  Total Trades:         {len(trades)}")
    print(f"  Wins / Losses:        {len(wins)} / {len(losses)}")
    print(f"  Win Rate:             {round(len(wins)/len(trades)*100, 1) if trades else 0}%")
    
    if wins:
        print(f"  Avg Win:              ₹{np.mean([t['pnl'] for t in wins]):+,.0f}")
    if losses:
        print(f"  Avg Loss:             ₹{np.mean([t['pnl'] for t in losses]):+,.0f}")
    if wins and losses:
        wr = abs(np.mean([t['pnl'] for t in wins]) / np.mean([t['pnl'] for t in losses]))
        print(f"  Win:Loss Ratio:       {wr:.1f}:1")
    
    print(f"  Total Trading P&L:    ₹{total_pnl:+,.0f}")
    
    if monthly_results:
        rets = [m["ret"] for m in monthly_results]
        avg_m = np.mean(rets)
        std_m = np.std(rets)
        sharpe = (avg_m / std_m) * np.sqrt(12) if std_m > 0 else 0
        annual = ((1 + avg_m/100)**12 - 1) * 100
        
        print(f"  Avg Monthly Return:   {avg_m:+.2f}%")
        print(f"  Annualized Return:    {annual:+.1f}%")
        print(f"  Max Drawdown:         {max_dd:.2f}%")
        print(f"  Sharpe Ratio:         {sharpe:.2f}")
    
    print()
    print("═══ CAPITAL SUMMARY ═══")
    print(f"  Starting Capital:     ₹{70000:,.0f}")
    print(f"  Total Injected:       ₹{total_injected:,.0f}")
    print(f"  Final Portfolio:      ₹{capital:,.0f}")
    print(f"  Trading Gain:         ₹{total_pnl:+,.0f}")
    print(f"  Gain on Invested:     {round(total_pnl/total_injected*100, 2):+}%")
    
    # Monthly table
    if monthly_results:
        print()
        print("═══ MONTHLY BREAKDOWN ═══")
        print(f"{'Month':<10} {'Start':>12} {'P&L':>10} {'End':>12} {'Ret':>7} {'Trades':>7}")
        print("─" * 62)
        for m in monthly_results:
            print(f"{m['month']:<10} ₹{m['start']:>10,.0f} ₹{m['pnl']:>+8,.0f} ₹{m['end']:>10,.0f} {m['ret']:>+6.1f}% {m['trades']:>6}")
    
    # Trade details
    if trades:
        print()
        print("═══ ALL TRADES ═══")
        print(f"{'#':<3} {'Stock':<12} {'Entry':>8} {'Exit':>8} {'Qty':>5} {'P&L':>10} {'%':>7} {'Days':>5} {'Reason':<20}")
        print("─" * 85)
        for i, t in enumerate(trades, 1):
            print(f"{i:<3} {t['symbol']:<12} ₹{t['entry']:>6,.0f} ₹{t['exit']:>6,.0f} {t['qty']:>5} ₹{t['pnl']:>+8,.0f} {t['pnl_pct']:>+6.1f}% {t['days']:>5} {t['reason']:<20}")
    
    # Equity curve
    if equity_curve:
        print()
        print("═══ EQUITY CURVE ═══")
        step = max(1, len(equity_curve) // 15)
        for i in range(0, len(equity_curve), step):
            val = equity_curve[i]
            bar = "█" * int((val - min(equity_curve)) / (max(equity_curve) - min(equity_curve) + 1) * 40)
            print(f"  Day {i:>4} | ₹{val:>12,.0f} {bar}")
    
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("  DISCLAIMER: These results use REAL Kite historical OHLCV")
    print("  data but are still BACKTESTS — not live trading results.")
    print("  Past performance does not guarantee future returns.")
    print("  Actual results will differ due to slippage, execution")
    print("  timing, API latency, and market regime changes.")
    print("═══════════════════════════════════════════════════════════════")


if __name__ == "__main__":
    run_backtest()
