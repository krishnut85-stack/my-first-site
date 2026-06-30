#!/usr/bin/env python3
"""
GLOBAL EYE v24.1.3 — HISTORICAL BACKTEST
Runs on DigitalOcean using real Kite OHLCV data.
Tests Standard Variation B strategy over available history.

Usage: python3 /home/globalbot/run_backtest_v6.py

Output: Console table with monthly P&L, drawdown, returns.
Runtime: ~5-10 minutes depending on stock count.
"""

import os, sys, json, math, time
from datetime import datetime, timedelta
from collections import defaultdict

# ── Load credentials from bot's .env ──
ENV_FILE = "/home/globalbot/.env"
if os.path.exists(ENV_FILE):
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()

KITE_API_KEY = os.getenv("KITE_API_KEY", "")

# Load access token from bot's saved session
ACCESS_FILE = "/home/globalbot/data/kite_access.json"
access_token = ""
if os.path.exists(ACCESS_FILE):
    with open(ACCESS_FILE) as f:
        data = json.load(f)
        access_token = data.get("access_token", "")

if not access_token or not KITE_API_KEY:
    print("❌ No Kite session — run this AFTER the bot has logged in (after 08:30 IST)")
    sys.exit(1)

from kiteconnect import KiteConnect
kite = KiteConnect(api_key=KITE_API_KEY)
kite.set_access_token(access_token)

# Verify connection
try:
    profile = kite.profile()
    print(f"✅ Kite connected: {profile['user_name']} ({profile['user_id']})")
except Exception as e:
    print(f"❌ Kite auth failed: {e}")
    print("   Run this after bot logs in at 08:30 IST")
    sys.exit(1)

# ══════════════════════════════════════════════════════════════
#  STRATEGY PARAMETERS (Standard Variation B)
# ══════════════════════════════════════════════════════════════
SL_ATR_MULT     = 2.0
T1_ATR_MULT     = 5.0
T2_ATR_MULT     = 12.0
PARTIAL_PCT     = 25
DVM_THRESHOLD   = 68
MAX_POSITIONS   = 5
INITIAL_CAPITAL = 50000
DAILY_INJECTION = 5000
KELLY_FRACTION  = 0.70    # v24.1.3: 70% Kelly fraction (matches bot)
KELLY_FLOOR     = 0.05    # 5% minimum floor
MAX_POSITION_PCT= 0.50    # v24.1.3: 50% max per trade (matches bot)
SL_CAP_PCT      = 0.025   # v24.1.3: 2.5% max SL (matches SCAN_SL_PERCENT)
MIN_SL_PCT      = 0.005   # v24.1.3: 0.5% min SL floor
CHASE_LIMIT_NORMAL = 2.0  # Normal day
CHASE_LIMIT_GAP = 5.0     # Gap-up day
RECOVERY_TRIGGER = 0.03   # 3% drawdown
RECOVERY_SIZE    = 0.35   # 35% sizing in recovery
LOOKBACK_MONTHS  = 20     # How many months of history

# ══════════════════════════════════════════════════════════════
#  STOCK UNIVERSE (top liquid stocks)
# ══════════════════════════════════════════════════════════════
STOCKS = [
    "RELIANCE", "HDFCBANK", "TCS", "INFY", "ICICIBANK",
    "HINDUNILVR", "ITC", "SBIN", "BHARTIARTL", "KOTAKBANK",
    "LT", "AXISBANK", "BAJFINANCE", "SUNPHARMA", "TATAMOTORS",
    "MARUTI", "WIPRO", "NTPC", "POWERGRID", "TECHM",
    "HCLTECH", "M&M", "TITAN", "ADANIPORTS", "COALINDIA",
    "JSWSTEEL", "TATASTEEL", "DLF", "BAJAJ-AUTO", "DRREDDY",
    "CIPLA", "DIVISLAB", "BPCL", "NESTLEIND", "ULTRACEMCO",
    "HEROMOTOCO", "EICHERMOT", "BEL", "TATAPOWER", "ADANIGREEN",
]

print(f"\n{'='*80}")
print(f"  GLOBAL EYE v24.1.3 — BACKTEST ({LOOKBACK_MONTHS} months, {len(STOCKS)} stocks)")
print(f"  Strategy: Standard Variation B | SL: {SL_ATR_MULT}×ATR | T2: {T2_ATR_MULT}×ATR")
print(f"{'='*80}\n")

# ══════════════════════════════════════════════════════════════
#  FETCH HISTORICAL DATA FROM KITE
# ══════════════════════════════════════════════════════════════

print("Fetching historical data from Kite...")
stock_data = {}
instruments = kite.instruments("NSE")
token_map = {i["tradingsymbol"]: i["instrument_token"] for i in instruments if i["segment"] == "NSE"}

from_date = (datetime.now() - timedelta(days=LOOKBACK_MONTHS * 30)).strftime("%Y-%m-%d")
to_date = datetime.now().strftime("%Y-%m-%d")

fetched = 0
for sym in STOCKS:
    token = token_map.get(sym)
    if not token:
        continue
    try:
        data = kite.historical_data(token, from_date, to_date, "day")
        if data and len(data) >= 50:
            stock_data[sym] = data
            fetched += 1
            if fetched % 10 == 0:
                print(f"  Fetched {fetched}/{len(STOCKS)} stocks...")
        time.sleep(0.35)  # Rate limit
    except Exception as e:
        pass

print(f"  ✅ {fetched} stocks loaded with {LOOKBACK_MONTHS} months of daily data\n")

if fetched < 10:
    print("❌ Not enough data — need at least 10 stocks")
    sys.exit(1)

# ══════════════════════════════════════════════════════════════
#  COMPUTE INDICATORS
# ══════════════════════════════════════════════════════════════

def compute_indicators(bars):
    """Add ATR, RSI, SMA20, SMA50, DVM to each bar."""
    for i in range(len(bars)):
        bars[i]["atr"] = 0
        bars[i]["rsi"] = 50
        bars[i]["sma20"] = 0
        bars[i]["sma50"] = 0
        bars[i]["dvm"] = 50
        bars[i]["vol_avg"] = 0

    for i in range(1, len(bars)):
        # ATR (14-period)
        if i >= 14:
            tr_sum = 0
            for j in range(i-13, i+1):
                h = bars[j]["high"]
                l = bars[j]["low"]
                pc = bars[j-1]["close"]
                tr = max(h - l, abs(h - pc), abs(l - pc))
                tr_sum += tr
            bars[i]["atr"] = round(tr_sum / 14, 2)

        # RSI (14-period)
        if i >= 15:
            gains = losses = 0
            for j in range(i-13, i+1):
                change = bars[j]["close"] - bars[j-1]["close"]
                if change > 0:
                    gains += change
                else:
                    losses += abs(change)
            avg_gain = gains / 14
            avg_loss = losses / 14 + 0.001
            rs = avg_gain / avg_loss
            bars[i]["rsi"] = round(100 - 100 / (1 + rs), 1)

        # SMA 20
        if i >= 20:
            bars[i]["sma20"] = round(sum(b["close"] for b in bars[i-19:i+1]) / 20, 2)

        # SMA 50
        if i >= 50:
            bars[i]["sma50"] = round(sum(b["close"] for b in bars[i-49:i+1]) / 50, 2)

        # Volume average
        if i >= 20:
            bars[i]["vol_avg"] = sum(b["volume"] for b in bars[i-19:i+1]) / 20

        # DVM Score (simplified)
        dvm = 50
        if bars[i]["sma20"] > 0 and bars[i]["close"] > bars[i]["sma20"]:
            dvm += 10
        if bars[i]["sma50"] > 0 and bars[i]["close"] > bars[i]["sma50"]:
            dvm += 10
        if 40 < bars[i]["rsi"] < 70:
            dvm += 5
        if bars[i]["vol_avg"] > 0 and bars[i]["volume"] > bars[i]["vol_avg"] * 1.2:
            dvm += 5
        if i >= 5:
            week_ret = (bars[i]["close"] - bars[i-5]["close"]) / bars[i-5]["close"]
            if week_ret > 0.02:
                dvm += 8
            elif week_ret > 0:
                dvm += 3
        bars[i]["dvm"] = min(95, max(30, dvm))

    return bars

for sym in stock_data:
    stock_data[sym] = compute_indicators(stock_data[sym])

# ══════════════════════════════════════════════════════════════
#  RUN BACKTEST
# ══════════════════════════════════════════════════════════════

# Get common date range
all_dates = set()
for sym, bars in stock_data.items():
    for b in bars:
        d = b["date"].strftime("%Y-%m-%d") if isinstance(b["date"], datetime) else str(b["date"])[:10]
        all_dates.add(d)

all_dates = sorted(all_dates)
print(f"  Date range: {all_dates[0]} to {all_dates[-1]} ({len(all_dates)} trading days)")

# Build date-indexed lookup
date_lookup = defaultdict(dict)
for sym, bars in stock_data.items():
    for b in bars:
        d = b["date"].strftime("%Y-%m-%d") if isinstance(b["date"], datetime) else str(b["date"])[:10]
        date_lookup[d][sym] = b

capital = INITIAL_CAPITAL
positions = {}
all_trades = []
monthly_stats = defaultdict(lambda: {"pnl": 0, "trades": 0, "wins": 0, "losses": 0})
equity_curve = []
peak_equity = INITIAL_CAPITAL
max_dd = 0
in_recovery = False
prev_nifty = 0

print(f"  Running backtest...\n")

for day_idx, date_str in enumerate(all_dates):
    day_data = date_lookup.get(date_str, {})
    if not day_data:
        continue

    month_key = date_str[:7]

    # Capital injection
    capital += DAILY_INJECTION
    if day_idx % 22 == 0:
        capital += 15000

    # Detect market gap (using RELIANCE as proxy)
    nifty_proxy = day_data.get("RELIANCE", {}).get("close", 0)
    market_gap = 0
    if prev_nifty > 0 and nifty_proxy > 0:
        nifty_open = day_data.get("RELIANCE", {}).get("open", nifty_proxy)
        market_gap = (nifty_open - prev_nifty) / prev_nifty * 100
    prev_nifty = nifty_proxy

    # Dynamic chase limit (v24.1.3)
    if market_gap >= 1.5:
        chase_limit = CHASE_LIMIT_GAP
    elif market_gap >= 0.8:
        chase_limit = 3.5
    else:
        chase_limit = CHASE_LIMIT_NORMAL

    day_pnl = 0

    # ── EXITS ──
    for sym in list(positions.keys()):
        pos = positions[sym]
        d = day_data.get(sym)
        if not d:
            continue

        price = d["close"]
        atr = pos["atr"]
        days_held = day_idx - pos["day"]

        if price > pos["highest"]:
            pos["highest"] = price

        gain_pct = (pos["highest"] - pos["entry"]) / pos["entry"] * 100

        # Trailing SL (Standard B ratchet)
        if gain_pct >= 20:
            trail = pos["highest"] - 1.5 * atr
        elif gain_pct >= 10:
            trail = pos["highest"] - 2.0 * atr
        elif gain_pct >= 5:
            trail = max(pos["highest"] - 2.0 * atr, pos["entry"] * 1.005)
        elif gain_pct >= 2:
            trail = pos["entry"] * 1.001
        else:
            trail = pos["sl"]

        if trail > pos["sl"]:
            pos["sl"] = trail

        exit_reason = None
        exit_price = price

        if d["low"] <= pos["sl"]:
            exit_reason = "SL"
            exit_price = pos["sl"]
        elif d["high"] >= pos["t2"]:
            exit_reason = "T2"
            exit_price = pos["t2"]
        elif days_held >= 25 and (price - pos["entry"]) / pos["entry"] * 100 < 2:
            exit_reason = "DEAD"

        # T1 partial
        if not exit_reason and d["high"] >= pos["t1"] and not pos.get("t1_done") and pos["qty"] >= 2:
            pq = max(1, pos["qty"] * PARTIAL_PCT // 100)
            ppnl = (pos["t1"] - pos["entry"]) * pq
            all_trades.append({
                "date": date_str, "sym": sym, "entry": pos["entry"],
                "exit": round(pos["t1"], 2), "qty": pq, "pnl": round(ppnl, 2),
                "reason": "T1", "days": days_held, "month": month_key,
            })
            pos["qty"] -= pq
            pos["t1_done"] = True
            pos["sl"] = max(pos["sl"], pos["entry"] * 1.001)
            capital += pq * pos["t1"]
            day_pnl += ppnl
            monthly_stats[month_key]["trades"] += 1
            monthly_stats[month_key]["wins"] += 1

        if exit_reason:
            pnl = (exit_price - pos["entry"]) * pos["qty"]
            all_trades.append({
                "date": date_str, "sym": sym, "entry": round(pos["entry"], 2),
                "exit": round(exit_price, 2), "qty": pos["qty"],
                "pnl": round(pnl, 2), "reason": exit_reason,
                "days": days_held, "month": month_key,
            })
            capital += pos["qty"] * exit_price
            day_pnl += pnl
            monthly_stats[month_key]["trades"] += 1
            if pnl > 0:
                monthly_stats[month_key]["wins"] += 1
            else:
                monthly_stats[month_key]["losses"] += 1
            del positions[sym]

    # ── ENTRIES ──
    if len(positions) < MAX_POSITIONS:
        candidates = []
        for sym, d in day_data.items():
            if sym in positions or d.get("close", 0) < 50:
                continue
            if d.get("dvm", 0) >= DVM_THRESHOLD and d.get("atr", 0) > 0:
                # Chase check: simulate gap effect
                signal_price = d["close"]
                open_price = d.get("open", signal_price)
                chase_pct = abs(open_price - signal_price) / signal_price * 100 if signal_price > 0 else 0
                if chase_pct > chase_limit:
                    continue
                candidates.append({"sym": sym, **d})

        candidates.sort(key=lambda x: x.get("dvm", 0), reverse=True)

        for cand in candidates[:MAX_POSITIONS - len(positions)]:
            sym = cand["sym"]
            price = cand["close"]
            atr = max(cand.get("atr", price * 0.02), price * 0.005)

            sl_pct = (SL_ATR_MULT * atr) / price if price > 0 else 0.01
            sl_pct = min(sl_pct, SL_CAP_PCT)     # Cap at 2.5%
            sl_pct = max(sl_pct, MIN_SL_PCT)      # Floor at 0.5%
            sl = price * (1 - sl_pct)
            t1 = price + T1_ATR_MULT * atr
            t2 = price + T2_ATR_MULT * atr
            risk = price - sl

            if risk <= 0:
                continue

            # R:R check (recovery mode requires 2:1)
            rr = (t2 - price) / risk
            if in_recovery and rr < 2.0:
                continue
            if rr < 1.5:
                continue

            # Kelly position sizing (matches bot's v24.1.3 logic)
            _wins_bt = [t for t in all_trades if t["pnl"] > 0]
            _losses_bt = [t for t in all_trades if t["pnl"] <= 0]
            _bt_wr = len(_wins_bt) / len(all_trades) if all_trades else 0.5
            _bt_avg_w = sum(t["pnl"] for t in _wins_bt) / len(_wins_bt) if _wins_bt else 1
            _bt_avg_l = abs(sum(t["pnl"] for t in _losses_bt) / len(_losses_bt)) if _losses_bt else 1
            _bt_rr = _bt_avg_w / (_bt_avg_l + 0.01)
            kelly_raw = _bt_wr - (1 - _bt_wr) / (_bt_rr + 0.01)
            kelly_pct = max(KELLY_FLOOR, kelly_raw * KELLY_FRACTION)
            kelly_pct = min(kelly_pct, 0.35)

            # Recovery mode reduces sizing
            if in_recovery:
                kelly_pct *= RECOVERY_SIZE
                kelly_pct = max(kelly_pct, KELLY_FLOOR)

            qty = max(1, int(capital * kelly_pct / risk))
            cost = qty * price
            if cost > capital * MAX_POSITION_PCT:
                qty = max(1, int(capital * MAX_POSITION_PCT / price))
                cost = qty * price
            if cost > capital or cost < 3000:
                continue

            capital -= cost
            positions[sym] = {
                "entry": price, "qty": qty, "cost": cost,
                "sl": sl, "t1": t1, "t2": t2,
                "atr": atr, "highest": price,
                "day": day_idx, "t1_done": False,
            }

    # Track equity
    unrealized = sum(
        (day_data.get(s, {}).get("close", p["entry"]) - p["entry"]) * p["qty"]
        for s, p in positions.items()
    )
    portfolio = capital + sum(p["cost"] for p in positions.values()) + unrealized
    equity_curve.append(portfolio)
    monthly_stats[month_key]["pnl"] += day_pnl

    # Drawdown recovery tracking
    if portfolio > peak_equity:
        peak_equity = portfolio
        if in_recovery:
            in_recovery = False
    dd = (peak_equity - portfolio) / peak_equity
    if dd > max_dd:
        max_dd = dd
    if dd >= RECOVERY_TRIGGER and not in_recovery:
        in_recovery = True

# ══════════════════════════════════════════════════════════════
#  RESULTS
# ══════════════════════════════════════════════════════════════

total_pnl = sum(t["pnl"] for t in all_trades)
wins = [t for t in all_trades if t["pnl"] > 0]
losses = [t for t in all_trades if t["pnl"] <= 0]
win_rate = len(wins) / len(all_trades) * 100 if all_trades else 0
avg_win = sum(t["pnl"] for t in wins) / len(wins) if wins else 0
avg_loss = sum(t["pnl"] for t in losses) / len(losses) if losses else 0

# Annualized return
total_days = len(all_dates)
total_invested = INITIAL_CAPITAL + DAILY_INJECTION * total_days + 15000 * (total_days // 22)
final_equity = equity_curve[-1] if equity_curve else INITIAL_CAPITAL
ann_return = ((final_equity / (INITIAL_CAPITAL + 100000)) ** (252 / max(total_days, 1)) - 1) * 100

# Print results
print("=" * 90)
print(f"  {'Month':<10} {'P&L':>12} {'Cumulative':>14} {'Trades':>8} {'WinRate':>10} {'Drawdown':>10}")
print(f"  {'─'*10} {'─'*12} {'─'*14} {'─'*8} {'─'*10} {'─'*10}")

cumulative = 0
for month in sorted(monthly_stats.keys()):
    s = monthly_stats[month]
    cumulative += s["pnl"]
    wr = s["wins"] / s["trades"] * 100 if s["trades"] else 0
    print(f"  {month:<10} ₹{s['pnl']:>10,.0f} ₹{cumulative:>12,.0f} {s['trades']:>8} {wr:>9.1f}% {max_dd*100:>9.1f}%")

print(f"  {'─'*10} {'─'*12} {'─'*14} {'─'*8} {'─'*10} {'─'*10}")

# Yearly summary
print(f"\n  YEARLY SUMMARY:")
years = defaultdict(float)
for m, s in monthly_stats.items():
    years[m[:4]] += s["pnl"]
for y in sorted(years.keys()):
    print(f"    {y}: ₹{years[y]:>12,.0f}")

print(f"""
{'='*90}
  PERFORMANCE SUMMARY
{'='*90}
  Total Trades:       {len(all_trades)}
  Wins / Losses:      {len(wins)} / {len(losses)}
  Win Rate:           {win_rate:.1f}%
  Avg Win:            ₹{avg_win:,.0f}
  Avg Loss:           ₹{avg_loss:,.0f}
  Win:Loss Ratio:     {abs(avg_win/avg_loss):.2f}:1
  Total Trading P&L:  ₹{total_pnl:,.0f}
  Max Drawdown:       {max_dd*100:.1f}%
  Final Portfolio:    ₹{final_equity:,.0f}
  Total Invested:     ₹{total_invested:,.0f}
  Capital Growth:     {(final_equity/total_invested-1)*100:+.1f}%
{'='*90}

  Note: This backtest uses REAL Kite OHLCV data with Standard
  Variation B parameters. Results include capital injections
  (₹5K daily + ₹15K monthly). The DVM scoring is simplified
  compared to the full bot's 3-Agent AI + 12-step pipeline,
  so live results will differ.
""")
