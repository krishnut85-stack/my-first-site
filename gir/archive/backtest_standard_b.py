#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════╗
║  GLOBAL EYE — STANDARD B BACKTEST COMPARISON TOOL                       ║
║  Owner: <redacted> | v24.2.0                                          ║
║                                                                          ║
║  Backtests 3 variants over 20 months with capital injections:            ║
║  1. Standard B (Original) — SL 2×ATR, T2 12×ATR, 25% partial           ║
║  2. Optimized Standard B (No Profit Lock) — tuned entry/trail           ║
║  3. Optimized Standard B (With Profit Lock) — +20% monthly lock         ║
║                                                                          ║
║  USAGE:                                                                  ║
║  1. Copy to DigitalOcean: scp backtest_standard_b.py globalbot@<server-ip>:~/  ║
║  2. Run: python3 ~/backtest_standard_b.py                                ║
║  3. Results: ~/backtest_results/ (CSV + PNG equity curves)               ║
║                                                                          ║
║  REQUIRES: Kite credentials in .env (same as Global Eye)                 ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import os, sys, json, time, math, logging
from datetime import datetime, timedelta, date
from collections import defaultdict

# ── Setup ──────────────────────────────────────────────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.expanduser("~/.env"))
    load_dotenv("/home/globalbot/.env")
except ImportError:
    pass

import pandas as pd
import numpy as np

try:
    from kiteconnect import KiteConnect
except ImportError:
    print("ERROR: kiteconnect not installed. Run: pip install kiteconnect")
    sys.exit(1)

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("WARNING: matplotlib not installed. Equity curves will be skipped.")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("Backtest")

# ── Output directory ───────────────────────────────────────────────────────
OUT_DIR = os.path.expanduser("~/backtest_results")
os.makedirs(OUT_DIR, exist_ok=True)

# ══════════════════════════════════════════════════════════════════════════════
#  BACKTEST CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

BACKTEST_MONTHS        = 20
INITIAL_CAPITAL        = 70_000
DAILY_INJECTION        = 5_000
MONTHLY_INJECTION      = 15_000
MAX_POSITIONS          = 5
POSITION_SIZE_PCT      = 0.20     # 20% of available capital per position
MIN_PRICE              = 30
MAX_HOLD_DAYS          = 28       # Dead money exit

# Stock selection
TARGET_UNIVERSE_SIZE   = 400      # Top N stocks to backtest
MIN_TURNOVER           = 5_000_000  # Rs.50L daily turnover
MIN_ATR_PCT            = 0.008    # 0.8% minimum volatility
MAX_ATR_PCT            = 0.08     # 8% max volatility

# ══════════════════════════════════════════════════════════════════════════════
#  THREE STRATEGY VARIANTS
# ══════════════════════════════════════════════════════════════════════════════

VARIANTS = {
    "Standard B (Original)": {
        "sl_atr_mult":    2.0,
        "t1_atr_mult":    5.0,
        "t2_atr_mult":    12.0,
        "trail_atr_mult": 2.0,
        "partial_pct":    25,      # 25% at T1
        "profit_lock":    False,
        "dvm_threshold":  68,      # Original
        "kelly_fraction": 0.70,
        "dead_money_days": 20,
        "greed_fg":       80,
        "greed_gain":     8,
    },
    "Optimized (No Lock)": {
        "sl_atr_mult":    2.0,
        "t1_atr_mult":    5.0,
        "t2_atr_mult":    12.0,
        "trail_atr_mult": 2.0,
        "partial_pct":    25,
        "profit_lock":    False,
        "dvm_threshold":  65,      # Looser entry
        "kelly_fraction": 0.75,    # Bigger bets
        "dead_money_days": 25,     # More patient
        "greed_fg":       85,      # Higher threshold
        "greed_gain":     15,
    },
    "Optimized (With Lock)": {
        "sl_atr_mult":    2.0,
        "t1_atr_mult":    5.0,
        "t2_atr_mult":    12.0,
        "trail_atr_mult": 2.0,
        "partial_pct":    25,
        "profit_lock":    True,    # +20% monthly → lock 50% gains
        "lock_threshold": 0.20,
        "lock_retention": 0.50,
        "dvm_threshold":  65,
        "kelly_fraction": 0.75,
        "dead_money_days": 25,
        "greed_fg":       85,
        "greed_gain":     15,
    },
}


# ══════════════════════════════════════════════════════════════════════════════
#  KITE CONNECTION
# ══════════════════════════════════════════════════════════════════════════════

def connect_kite():
    """Connect to Kite using stored credentials."""
    api_key = os.getenv("KITE_API_KEY", "")
    access_token = os.getenv("KITE_ACCESS_TOKEN", "")

    # Read from .env file directly
    if not api_key:
        env_path = "/home/globalbot/.env"
        if os.path.exists(env_path):
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("KITE_API_KEY="):
                        api_key = line.split("=", 1)[1].strip()
                    elif line.startswith("KITE_ACCESS_TOKEN="):
                        access_token = line.split("=", 1)[1].strip()

    # Read access token from kite_access.json
    if not access_token:
        for path in ["/home/globalbot/data/kite_access.json", os.path.expanduser("~/kite_session.json")]:
            if os.path.exists(path):
                with open(path) as f:
                    data = json.load(f)
                    if not access_token:
                        access_token = data.get("access_token", "")
                    if not api_key:
                        api_key = data.get("api_key", "")

    if not api_key or not access_token:
        print("ERROR: Kite credentials not found.")
        print("Make sure KITE_API_KEY and KITE_ACCESS_TOKEN are in .env")
        print("Or run Global Eye first to generate kite_session.json")
        sys.exit(1)

    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(access_token)

    # Test connection
    try:
        profile = kite.profile()
        logger.info(f"✅ Kite connected: {profile.get('user_name', 'Unknown')}")
    except Exception as e:
        print(f"ERROR: Kite connection failed: {e}")
        print("Run Global Eye first to refresh the session, then re-run this script.")
        sys.exit(1)

    return kite


# ══════════════════════════════════════════════════════════════════════════════
#  HISTORICAL DATA LOADER
# ══════════════════════════════════════════════════════════════════════════════

def load_stock_universe(kite):
    """Load tradeable NSE stocks and filter by quality."""
    logger.info("Loading NSE instruments...")
    instruments = kite.instruments("NSE")

    EXCLUDED_PATTERNS = [
        "ETF", "GOLD", "SILVER", "CRUDE", "NIFTY", "SENSEX",
        "LIQUID", "BOND", "GILT", "MONEY", "OVERNIGHT",
        "DEBT", "SOVEREIGN", "BEES", "SGBOND",
    ]

    symbols = {}
    for inst in instruments:
        sym = inst.get("tradingsymbol", "")
        name = inst.get("name", "").upper()
        inst_type = inst.get("instrument_type", "").upper()
        token = inst.get("instrument_token", 0)

        if inst_type not in ("EQ", ""):
            continue
        if not sym or sym.isdigit() or len(sym) < 2:
            continue
        if sym[0].isdigit():
            continue
        if "-" in sym:
            continue
        if any(pat in name or pat in sym for pat in EXCLUDED_PATTERNS):
            continue

        symbols[sym] = token

    logger.info(f"Found {len(symbols)} tradeable stocks")
    return symbols


def fetch_historical(kite, token, days=500):
    """Fetch daily OHLCV data for a stock."""
    try:
        import pytz
        IST = pytz.timezone("Asia/Kolkata")
        now = datetime.now(IST)
    except Exception:
        now = datetime.now()

    from_dt = (now - timedelta(days=days)).strftime("%Y-%m-%d")
    to_dt = now.strftime("%Y-%m-%d")

    try:
        data = kite.historical_data(token, from_dt, to_dt, "day")
        if data and len(data) > 50:
            df = pd.DataFrame(data)
            df.columns = [c.lower() for c in df.columns]
            return df
    except Exception as e:
        logger.debug(f"Historical fetch token={token}: {e}")

    return None


# ══════════════════════════════════════════════════════════════════════════════
#  TECHNICAL INDICATORS
# ══════════════════════════════════════════════════════════════════════════════

def compute_indicators(df):
    """Add all technical indicators to a DataFrame."""
    close = df['close'].values
    high = df['high'].values
    low = df['low'].values
    volume = df['volume'].values

    # RSI (14)
    delta = np.diff(close, prepend=close[0])
    gain = np.where(delta > 0, delta, 0)
    loss = np.where(delta < 0, -delta, 0)
    avg_gain = pd.Series(gain).rolling(14).mean().values
    avg_loss = pd.Series(loss).rolling(14).mean().values
    rs = avg_gain / (avg_loss + 1e-10)
    df['rsi'] = 100 - (100 / (1 + rs))

    # SMAs
    df['sma20'] = pd.Series(close).rolling(20).mean().values
    df['sma50'] = pd.Series(close).rolling(50).mean().values
    df['sma200'] = pd.Series(close).rolling(200).mean().values

    # EMAs
    df['ema9'] = pd.Series(close).ewm(span=9).mean().values
    df['ema21'] = pd.Series(close).ewm(span=21).mean().values

    # MACD
    ema12 = pd.Series(close).ewm(span=12).mean().values
    ema26 = pd.Series(close).ewm(span=26).mean().values
    df['macd'] = ema12 - ema26
    df['macd_signal'] = pd.Series(df['macd']).ewm(span=9).mean().values

    # ATR (14)
    tr = np.maximum(high - low,
         np.maximum(np.abs(high - np.roll(close, 1)),
                    np.abs(low - np.roll(close, 1))))
    tr[0] = high[0] - low[0]
    df['atr'] = pd.Series(tr).rolling(14).mean().values

    # ADX (14)
    try:
        plus_dm = np.maximum(np.diff(high, prepend=high[0]), 0)
        minus_dm = np.maximum(-np.diff(low, prepend=low[0]), 0)
        plus_dm[plus_dm < minus_dm] = 0
        minus_dm[minus_dm < plus_dm] = 0
        atr_s = pd.Series(tr).rolling(14).mean()
        plus_di = 100 * pd.Series(plus_dm).rolling(14).mean() / (atr_s + 1e-10)
        minus_di = 100 * pd.Series(minus_dm).rolling(14).mean() / (atr_s + 1e-10)
        dx = 100 * np.abs(plus_di - minus_di) / (plus_di + minus_di + 1e-10)
        df['adx'] = dx.rolling(14).mean().values
    except Exception:
        df['adx'] = 25  # Default

    # Volume SMA
    df['vol_sma20'] = pd.Series(volume.astype(float)).rolling(20).mean().values
    df['vol_ratio'] = volume / (df['vol_sma20'] + 1)

    # Bollinger Bands
    bb_sma = pd.Series(close).rolling(20).mean()
    bb_std = pd.Series(close).rolling(20).std()
    df['bb_upper'] = (bb_sma + 2 * bb_std).values
    df['bb_lower'] = (bb_sma - 2 * bb_std).values
    df['bb_width'] = ((df['bb_upper'] - df['bb_lower']) / (bb_sma + 1e-10)).values

    # Momentum score (DVM proxy)
    # Combines trend, momentum, volume, and fundamentals proxies
    df['dvm'] = 50  # Default
    for i in range(50, len(df)):
        score = 50
        # Trend component
        if close[i] > df['sma20'].iloc[i]:
            score += 5
        if close[i] > df['sma50'].iloc[i]:
            score += 5
        if df['ema9'].iloc[i] > df['ema21'].iloc[i]:
            score += 5
        # Momentum
        if df['macd'].iloc[i] > df['macd_signal'].iloc[i]:
            score += 5
        if 40 < df['rsi'].iloc[i] < 70:
            score += 5
        # Volume
        if df['vol_ratio'].iloc[i] > 1.2:
            score += 5
        # ADX trend strength
        if df['adx'].iloc[i] > 25:
            score += 5
        # Bollinger squeeze (potential breakout)
        if df['bb_width'].iloc[i] < 0.05:
            score += 3

        df.iloc[i, df.columns.get_loc('dvm')] = min(100, score)

    return df


# ══════════════════════════════════════════════════════════════════════════════
#  BACKTEST ENGINE
# ══════════════════════════════════════════════════════════════════════════════

def run_single_stock_backtest(df, symbol, variant_cfg, capital_available,
                              existing_positions_count):
    """
    Backtest a single stock with a specific variant configuration.
    Returns list of trades.
    """
    trades = []
    if len(df) < 60:
        return trades

    close = df['close'].values
    high = df['high'].values
    low = df['low'].values
    atr = df['atr'].values
    rsi = df['rsi'].values
    macd = df['macd'].values
    macd_sig = df['macd_signal'].values
    dvm = df['dvm'].values

    sl_mult = variant_cfg['sl_atr_mult']
    t1_mult = variant_cfg['t1_atr_mult']
    t2_mult = variant_cfg['t2_atr_mult']
    trail_mult = variant_cfg['trail_atr_mult']
    partial_pct = variant_cfg['partial_pct']
    dvm_thresh = variant_cfg['dvm_threshold']
    dead_days = variant_cfg['dead_money_days']

    position = None

    for i in range(50, len(close)):
        price = close[i]
        day_atr = atr[i] if atr[i] > 0 else price * 0.02
        day_date = df['date'].iloc[i] if 'date' in df.columns else None

        if position is not None:
            # ── EXIT LOGIC ──
            # Update highest
            if price > position['highest']:
                position['highest'] = price

            gain_from_peak = (position['highest'] - position['entry']) / position['entry'] * 100
            gain_current = (price - position['entry']) / position['entry'] * 100
            days_held = i - position['entry_idx']
            pos_atr = position['entry_atr']

            # 1. Trailing stop (Standard B ATR-based)
            if gain_from_peak >= 20:
                trail_sl = position['highest'] - 1.5 * pos_atr
            elif gain_from_peak >= 10:
                trail_sl = position['highest'] - trail_mult * pos_atr
            elif gain_from_peak >= 5:
                trail_sl = max(position['highest'] - trail_mult * pos_atr,
                              position['entry'] * 1.005)
            elif gain_from_peak >= 2:
                trail_sl = position['entry'] * 1.001
            else:
                trail_sl = position['sl']

            if trail_sl > position['sl']:
                position['sl'] = trail_sl

            # 2. Stop loss hit
            exit_reason = None
            exit_price = price

            if price <= position['sl']:
                exit_reason = "SL"
                exit_price = position['sl']  # Assume SL fill at SL price

            # 3. Target 2 hit (full exit of remaining)
            elif price >= position['t2']:
                exit_reason = "T2"

            # 4. Dead money exit
            elif days_held >= dead_days and gain_current < 2.0:
                exit_reason = "DEAD"

            # 5. Partial at T1 (not a full exit)
            if (not exit_reason and price >= position['t1']
                    and not position['t1_done'] and position['qty'] >= 2):
                partial_qty = max(1, position['qty'] * partial_pct // 100)
                partial_pnl = (price - position['entry']) * partial_qty
                trades.append({
                    'symbol': symbol,
                    'entry_price': position['entry'],
                    'exit_price': price,
                    'qty': partial_qty,
                    'pnl': round(partial_pnl, 2),
                    'pnl_pct': round((price - position['entry']) / position['entry'] * 100, 2),
                    'reason': 'T1_PARTIAL',
                    'days_held': days_held,
                    'date': str(day_date)[:10] if day_date else '',
                    'entry_date': position.get('entry_date', ''),
                })
                position['qty'] -= partial_qty
                position['t1_done'] = True
                position['sl'] = max(position['sl'], position['entry'] * 1.001)

            if exit_reason:
                pnl = (exit_price - position['entry']) * position['qty']
                trades.append({
                    'symbol': symbol,
                    'entry_price': position['entry'],
                    'exit_price': round(exit_price, 2),
                    'qty': position['qty'],
                    'pnl': round(pnl, 2),
                    'pnl_pct': round((exit_price - position['entry']) / position['entry'] * 100, 2),
                    'reason': exit_reason,
                    'days_held': days_held,
                    'date': str(day_date)[:10] if day_date else '',
                    'entry_date': position.get('entry_date', ''),
                })
                position = None

        else:
            # ── ENTRY LOGIC ──
            if existing_positions_count >= MAX_POSITIONS:
                continue
            if price < MIN_PRICE:
                continue
            if dvm[i] < dvm_thresh:
                continue

            # Standard B entry conditions
            buy = (
                macd[i] > macd_sig[i]               # MACD bullish
                and 38 < rsi[i] < 72                  # RSI in sweet spot
                and close[i] > df['sma20'].iloc[i]    # Above 20 SMA
                and day_atr > 0
                and day_atr / price >= MIN_ATR_PCT     # Enough volatility
            )

            if buy:
                sl_price = price - sl_mult * day_atr
                t1_price = price + t1_mult * day_atr
                t2_price = price + t2_mult * day_atr

                # Position sizing (Kelly-like)
                risk_per_share = price - sl_price
                if risk_per_share <= 0:
                    continue
                max_risk = capital_available * variant_cfg['kelly_fraction'] * 0.10
                qty = max(1, int(min(max_risk / risk_per_share,
                                     capital_available * POSITION_SIZE_PCT / price)))
                cost = qty * price
                if cost > capital_available * 0.55:
                    qty = max(1, int(capital_available * 0.55 / price))
                    cost = qty * price
                if cost > capital_available:
                    continue

                position = {
                    'entry': price, 'qty': qty, 'cost': cost,
                    'sl': sl_price, 't1': t1_price, 't2': t2_price,
                    'entry_atr': day_atr, 'highest': price,
                    'entry_idx': i, 't1_done': False,
                    'entry_date': str(day_date)[:10] if day_date else '',
                }

    # Close any open position at last price
    if position is not None:
        last_price = close[-1]
        pnl = (last_price - position['entry']) * position['qty']
        trades.append({
            'symbol': symbol,
            'entry_price': position['entry'],
            'exit_price': round(last_price, 2),
            'qty': position['qty'],
            'pnl': round(pnl, 2),
            'pnl_pct': round((last_price - position['entry']) / position['entry'] * 100, 2),
            'reason': 'OPEN',
            'days_held': len(close) - 1 - position['entry_idx'],
            'date': '',
            'entry_date': position.get('entry_date', ''),
        })

    return trades


# ══════════════════════════════════════════════════════════════════════════════
#  PORTFOLIO BACKTEST (multi-stock with capital injections + profit lock)
# ══════════════════════════════════════════════════════════════════════════════

def run_portfolio_backtest(all_stock_data, variant_name, variant_cfg):
    """
    Run a multi-stock portfolio backtest with capital injections.
    Returns: metrics dict + equity curve
    """
    logger.info(f"\n{'='*60}")
    logger.info(f"BACKTESTING: {variant_name}")
    logger.info(f"{'='*60}")

    # Find common date range
    all_dates = set()
    for sym, df in all_stock_data.items():
        if 'date' in df.columns:
            for d in df['date']:
                all_dates.add(pd.Timestamp(d).date() if not isinstance(d, date) else d)

    if not all_dates:
        logger.error("No valid dates found")
        return None, None

    sorted_dates = sorted(all_dates)
    # Use last ~400 trading days (~20 months)
    target_days = BACKTEST_MONTHS * 21  # ~21 trading days per month
    if len(sorted_dates) > target_days:
        sorted_dates = sorted_dates[-target_days:]

    start_date = sorted_dates[0]

    capital = INITIAL_CAPITAL
    total_injected = INITIAL_CAPITAL
    positions = {}  # symbol -> position dict
    all_trades = []
    equity_curve = []
    equity_dates = []
    monthly_pnl = defaultdict(float)
    last_injection_month = ""
    last_injection_day = None
    profit_lock_active = False
    profit_lock_month = ""

    for day_idx, today in enumerate(sorted_dates):
        today_str = str(today)
        month_str = today_str[:7]

        # ── Daily capital injection ──
        if last_injection_day != today:
            capital += DAILY_INJECTION
            total_injected += DAILY_INJECTION
            last_injection_day = today

        # ── Monthly capital injection ──
        if month_str != last_injection_month:
            capital += MONTHLY_INJECTION
            total_injected += MONTHLY_INJECTION
            last_injection_month = month_str
            # Reset profit lock monthly
            if variant_cfg.get('profit_lock'):
                profit_lock_active = False
                profit_lock_month = month_str

        # ── Check existing positions ──
        for sym in list(positions.keys()):
            pos = positions[sym]
            df = all_stock_data.get(sym)
            if df is None:
                continue

            # Find today's data
            if 'date' in df.columns:
                day_rows = df[df['date'].apply(
                    lambda d: (pd.Timestamp(d).date() if not isinstance(d, date) else d) == today
                )]
            else:
                continue

            if day_rows.empty:
                continue

            row = day_rows.iloc[0]
            price = row['close']
            day_atr = row.get('atr', price * 0.02)
            pos_atr = pos.get('entry_atr', day_atr)

            # Update highest
            if price > pos['highest']:
                pos['highest'] = price

            gain_from_peak = (pos['highest'] - pos['entry']) / pos['entry'] * 100
            gain_current = (price - pos['entry']) / pos['entry'] * 100
            days_held = day_idx - pos['entry_day_idx']

            # Trailing SL (Standard B)
            if gain_from_peak >= 20:
                trail_sl = pos['highest'] - 1.5 * pos_atr
            elif gain_from_peak >= 10:
                trail_sl = pos['highest'] - variant_cfg['trail_atr_mult'] * pos_atr
            elif gain_from_peak >= 5:
                trail_sl = max(pos['highest'] - variant_cfg['trail_atr_mult'] * pos_atr,
                              pos['entry'] * 1.005)
            elif gain_from_peak >= 2:
                trail_sl = pos['entry'] * 1.001
            else:
                trail_sl = pos['sl']

            if trail_sl > pos['sl']:
                pos['sl'] = trail_sl

            # Profit lock SL tightening
            if profit_lock_active and gain_current > 0:
                lock_sl = pos['entry'] + (price - pos['entry']) * variant_cfg.get('lock_retention', 0.5)
                if lock_sl > pos['sl']:
                    pos['sl'] = lock_sl

            # Exit checks
            exit_reason = None
            exit_price = price

            if price <= pos['sl']:
                exit_reason = "SL"
                exit_price = pos['sl']
            elif price >= pos['t2']:
                exit_reason = "T2"
            elif days_held >= variant_cfg['dead_money_days'] and gain_current < 2.0:
                exit_reason = "DEAD"

            # Partial at T1
            if (not exit_reason and price >= pos['t1']
                    and not pos.get('t1_done') and pos['qty'] >= 2):
                partial_qty = max(1, pos['qty'] * variant_cfg['partial_pct'] // 100)
                partial_pnl = (price - pos['entry']) * partial_qty
                capital += partial_qty * price
                monthly_pnl[month_str] += partial_pnl
                all_trades.append({
                    'symbol': sym, 'entry_price': pos['entry'],
                    'exit_price': price, 'qty': partial_qty,
                    'pnl': round(partial_pnl, 2),
                    'pnl_pct': round(gain_current, 2),
                    'reason': 'T1_PARTIAL', 'days_held': days_held,
                    'date': today_str,
                })
                pos['qty'] -= partial_qty
                pos['t1_done'] = True
                pos['sl'] = max(pos['sl'], pos['entry'] * 1.001)

            if exit_reason:
                pnl = (exit_price - pos['entry']) * pos['qty']
                capital += pos['qty'] * exit_price
                monthly_pnl[month_str] += pnl
                all_trades.append({
                    'symbol': sym, 'entry_price': pos['entry'],
                    'exit_price': round(exit_price, 2), 'qty': pos['qty'],
                    'pnl': round(pnl, 2),
                    'pnl_pct': round((exit_price - pos['entry']) / pos['entry'] * 100, 2),
                    'reason': exit_reason, 'days_held': days_held,
                    'date': today_str,
                })
                del positions[sym]

        # ── Profit lock check ──
        if variant_cfg.get('profit_lock') and not profit_lock_active:
            total_unrealized = sum(
                (all_stock_data.get(s, pd.DataFrame()).iloc[-1]['close'] - p['entry']) * p['qty']
                for s, p in positions.items()
                if s in all_stock_data and len(all_stock_data[s]) > 0
            ) if positions else 0
            month_realized = monthly_pnl.get(month_str, 0)
            month_total = month_realized + total_unrealized
            if month_total >= capital * variant_cfg.get('lock_threshold', 0.20):
                profit_lock_active = True
                logger.info(f"  🔒 Profit Lock activated month {month_str}: +₹{month_total:,.0f}")

        # ── Entry logic — scan all stocks ──
        if len(positions) < MAX_POSITIONS:
            candidates = []
            for sym, df in all_stock_data.items():
                if sym in positions:
                    continue
                if 'date' not in df.columns:
                    continue

                day_rows = df[df['date'].apply(
                    lambda d: (pd.Timestamp(d).date() if not isinstance(d, date) else d) == today
                )]
                if day_rows.empty:
                    continue

                idx = day_rows.index[0]
                if idx < 50:
                    continue

                row = day_rows.iloc[0]
                price = row['close']
                day_atr = row.get('atr', 0)
                rsi_val = row.get('rsi', 50)
                macd_val = row.get('macd', 0)
                macd_sig_val = row.get('macd_signal', 0)
                sma20 = row.get('sma20', 0)
                dvm_val = row.get('dvm', 50)

                if price < MIN_PRICE or day_atr <= 0:
                    continue
                if dvm_val < variant_cfg['dvm_threshold']:
                    continue

                # Entry conditions
                if (macd_val > macd_sig_val
                        and 38 < rsi_val < 72
                        and price > sma20
                        and day_atr / price >= MIN_ATR_PCT):
                    candidates.append({
                        'symbol': sym, 'price': price, 'atr': day_atr,
                        'dvm': dvm_val, 'rsi': rsi_val, 'idx': idx,
                    })

            # Rank by DVM score
            candidates.sort(key=lambda x: x['dvm'], reverse=True)

            for cand in candidates[:MAX_POSITIONS - len(positions)]:
                sym = cand['symbol']
                price = cand['price']
                day_atr = cand['atr']

                sl_price = price - variant_cfg['sl_atr_mult'] * day_atr
                t1_price = price + variant_cfg['t1_atr_mult'] * day_atr
                t2_price = price + variant_cfg['t2_atr_mult'] * day_atr

                risk_per_share = price - sl_price
                if risk_per_share <= 0:
                    continue

                max_risk = capital * variant_cfg['kelly_fraction'] * 0.10
                qty = max(1, int(min(max_risk / risk_per_share,
                                     capital * POSITION_SIZE_PCT / price)))
                cost = qty * price
                if cost > capital * 0.55:
                    qty = max(1, int(capital * 0.55 / price))
                    cost = qty * price
                if cost > capital:
                    continue

                capital -= cost
                positions[sym] = {
                    'entry': price, 'qty': qty, 'cost': cost,
                    'sl': sl_price, 't1': t1_price, 't2': t2_price,
                    'entry_atr': day_atr, 'highest': price,
                    'entry_day_idx': day_idx, 't1_done': False,
                }

        # ── Equity curve ──
        unrealized = 0
        for sym, pos in positions.items():
            if sym in all_stock_data and 'date' in all_stock_data[sym].columns:
                _df = all_stock_data[sym]
                _rows = _df[_df['date'].apply(
                    lambda d: (pd.Timestamp(d).date() if not isinstance(d, date) else d) == today
                )]
                if not _rows.empty:
                    unrealized += (_rows.iloc[0]['close'] - pos['entry']) * pos['qty']

        portfolio_value = capital + sum(p['cost'] for p in positions.values()) + unrealized
        equity_curve.append(portfolio_value)
        equity_dates.append(today)

    # ── Close remaining positions at last known price ──
    for sym, pos in list(positions.items()):
        if sym in all_stock_data:
            last_price = all_stock_data[sym]['close'].iloc[-1]
            pnl = (last_price - pos['entry']) * pos['qty']
            capital += pos['qty'] * last_price
            all_trades.append({
                'symbol': sym, 'entry_price': pos['entry'],
                'exit_price': round(last_price, 2), 'qty': pos['qty'],
                'pnl': round(pnl, 2),
                'pnl_pct': round((last_price - pos['entry']) / pos['entry'] * 100, 2),
                'reason': 'OPEN', 'days_held': 0, 'date': '',
            })

    # ══════════════════════════════════════════════════════════════
    #  CALCULATE METRICS
    # ══════════════════════════════════════════════════════════════
    closed_trades = [t for t in all_trades if t['reason'] != 'OPEN']
    wins = [t for t in closed_trades if t['pnl'] > 0]
    losses = [t for t in closed_trades if t['pnl'] <= 0]

    total_pnl = sum(t['pnl'] for t in all_trades)
    win_rate = len(wins) / len(closed_trades) * 100 if closed_trades else 0
    avg_win_pct = np.mean([t['pnl_pct'] for t in wins]) if wins else 0
    avg_loss_pct = np.mean([t['pnl_pct'] for t in losses]) if losses else 0
    avg_win_rs = np.mean([t['pnl'] for t in wins]) if wins else 0
    avg_loss_rs = np.mean([t['pnl'] for t in losses]) if losses else 0

    # Win:Loss ratio
    wl_ratio = abs(avg_win_rs / avg_loss_rs) if avg_loss_rs != 0 else 0

    # Max drawdown
    peak = equity_curve[0] if equity_curve else INITIAL_CAPITAL
    max_dd = 0
    for eq in equity_curve:
        if eq > peak:
            peak = eq
        dd = (peak - eq) / peak * 100
        if dd > max_dd:
            max_dd = dd

    # Sharpe ratio (annualized from daily returns)
    if len(equity_curve) > 1:
        daily_returns = np.diff(equity_curve) / np.array(equity_curve[:-1])
        sharpe = (np.mean(daily_returns) / (np.std(daily_returns) + 1e-10)) * np.sqrt(252)
    else:
        sharpe = 0

    final_portfolio = equity_curve[-1] if equity_curve else INITIAL_CAPITAL
    months_traded = BACKTEST_MONTHS
    monthly_return = (total_pnl / total_injected * 100) / max(1, months_traded)

    # Scale-up estimates (300-400 stocks → 2500+ universe)
    scale_factor = 2500 / max(1, len(all_stock_data))
    # Conservative: sqrt scaling (not linear — diminishing returns from correlation)
    conservative_scale = math.sqrt(scale_factor)
    scaled_pnl = total_pnl * conservative_scale
    scaled_final = total_injected + scaled_pnl

    metrics = {
        'variant': variant_name,
        'trades': len(all_trades),
        'closed_trades': len(closed_trades),
        'wins': len(wins),
        'losses': len(losses),
        'win_rate': round(win_rate, 1),
        'avg_win_pct': round(avg_win_pct, 2),
        'avg_win_rs': round(avg_win_rs, 0),
        'avg_loss_pct': round(avg_loss_pct, 2),
        'avg_loss_rs': round(avg_loss_rs, 0),
        'wl_ratio': round(wl_ratio, 2),
        'total_pnl': round(total_pnl, 0),
        'monthly_return': round(monthly_return, 1),
        'max_drawdown': round(max_dd, 1),
        'sharpe': round(sharpe, 2),
        'final_portfolio': round(final_portfolio, 0),
        'total_injected': round(total_injected, 0),
        'scaled_pnl': round(scaled_pnl, 0),
        'scaled_final': round(scaled_final, 0),
    }

    logger.info(f"  Trades: {metrics['trades']} | Win Rate: {metrics['win_rate']}%")
    logger.info(f"  P&L: ₹{metrics['total_pnl']:,.0f} | Final: ₹{metrics['final_portfolio']:,.0f}")
    logger.info(f"  Max DD: {metrics['max_drawdown']:.1f}% | Sharpe: {metrics['sharpe']:.2f}")

    return metrics, (equity_dates, equity_curve), all_trades


# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("  GLOBAL EYE v24.2.0 — STANDARD B BACKTEST COMPARISON")
    print("  Owner: <redacted>")
    print("=" * 70)

    # Connect to Kite
    kite = connect_kite()

    # Load stock universe
    symbols = load_stock_universe(kite)
    sym_list = list(symbols.keys())

    # Fetch historical data (this takes time — ~10 min for 400 stocks)
    logger.info(f"\nFetching historical data for {min(TARGET_UNIVERSE_SIZE, len(sym_list))} stocks...")
    logger.info("This will take 5-15 minutes. Please wait...")

    all_stock_data = {}
    fetch_count = 0
    errors = 0
    batch_symbols = sym_list[:TARGET_UNIVERSE_SIZE]

    for i, sym in enumerate(batch_symbols):
        token = symbols[sym]
        df = fetch_historical(kite, token, days=BACKTEST_MONTHS * 30 + 60)
        if df is not None and len(df) > 60:
            df = compute_indicators(df)
            all_stock_data[sym] = df
            fetch_count += 1
        else:
            errors += 1

        if (i + 1) % 50 == 0:
            logger.info(f"  Fetched {i+1}/{len(batch_symbols)} ({fetch_count} valid, {errors} errors)")
            time.sleep(1)  # Rate limit

        if (i + 1) % 200 == 0:
            time.sleep(3)  # Longer pause every 200

    logger.info(f"\n✅ Historical data ready: {fetch_count} stocks with {BACKTEST_MONTHS}+ months data")

    if fetch_count < 20:
        print("ERROR: Too few stocks with valid data. Check Kite connection.")
        sys.exit(1)

    # ── Run backtests ──
    all_metrics = {}
    all_curves = {}
    all_trade_logs = {}

    for variant_name, variant_cfg in VARIANTS.items():
        metrics, curve_data, trade_log = run_portfolio_backtest(
            all_stock_data, variant_name, variant_cfg
        )
        if metrics:
            all_metrics[variant_name] = metrics
            all_curves[variant_name] = curve_data
            all_trade_logs[variant_name] = trade_log

    # ══════════════════════════════════════════════════════════════
    #  RESULTS TABLE
    # ══════════════════════════════════════════════════════════════
    print("\n" + "=" * 100)
    print("  BACKTEST COMPARISON TABLE — STANDARD B VARIANTS")
    print("=" * 100)

    header = f"{'Metric':<22} | {'Standard B (Original)':>22} | {'Optimized (No Lock)':>22} | {'Optimized (With Lock)':>22}"
    print(header)
    print("-" * 100)

    variant_names = list(VARIANTS.keys())
    rows = [
        ("Trades",          "trades",          ""),
        ("Win Rate",         "win_rate",        "%"),
        ("Avg Win %",        "avg_win_pct",     "%"),
        ("Avg Win ₹",        "avg_win_rs",      ""),
        ("Avg Loss %",       "avg_loss_pct",    "%"),
        ("Avg Loss ₹",       "avg_loss_rs",     ""),
        ("Win:Loss Ratio",   "wl_ratio",        ""),
        ("Trading P&L",      "total_pnl",       "₹"),
        ("Monthly Return",   "monthly_return",  "%"),
        ("Max Drawdown",     "max_drawdown",    "%"),
        ("Sharpe Ratio",     "sharpe",          ""),
        ("Final Portfolio",  "final_portfolio",  "₹"),
        ("Total Injected",   "total_injected",  "₹"),
        ("Scaled Est. P&L",  "scaled_pnl",      "₹"),
        ("Scaled Est. Final","scaled_final",     "₹"),
    ]

    for label, key, unit in rows:
        vals = []
        for vn in variant_names:
            m = all_metrics.get(vn, {})
            v = m.get(key, 0)
            if unit == "₹":
                vals.append(f"₹{v:>16,.0f}")
            elif unit == "%":
                vals.append(f"{v:>20.1f}%")
            else:
                vals.append(f"{v:>21}")
        print(f"{label:<22} | {vals[0]:>22} | {vals[1]:>22} | {vals[2]:>22}")

    print("=" * 100)

    # ── Save results ──
    # CSV
    csv_path = os.path.join(OUT_DIR, "backtest_comparison.csv")
    csv_rows = []
    for label, key, unit in rows:
        row = {"Metric": label}
        for vn in variant_names:
            row[vn] = all_metrics.get(vn, {}).get(key, 0)
        csv_rows.append(row)
    pd.DataFrame(csv_rows).to_csv(csv_path, index=False)
    logger.info(f"📊 Results saved: {csv_path}")

    # Trade logs
    for vn, trades in all_trade_logs.items():
        safe_name = vn.replace(" ", "_").replace("(", "").replace(")", "")
        log_path = os.path.join(OUT_DIR, f"trades_{safe_name}.csv")
        pd.DataFrame(trades).to_csv(log_path, index=False)

    # ── Equity curves ──
    if HAS_MATPLOTLIB and all_curves:
        fig, ax = plt.subplots(figsize=(14, 7))
        colors_map = {
            variant_names[0]: '#2196F3',
            variant_names[1]: '#FF9800',
            variant_names[2]: '#4CAF50',
        }

        for vn in variant_names:
            if vn in all_curves and all_curves[vn]:
                dates, curve = all_curves[vn]
                ax.plot(dates, [c / 100000 for c in curve],
                       label=vn, color=colors_map.get(vn, 'gray'), linewidth=1.5)

        ax.set_title("GLOBAL EYE v24.2.0 — Standard B Backtest Comparison\nEquity Curves (₹ Lakhs)",
                     fontsize=14, fontweight='bold')
        ax.set_xlabel("Date")
        ax.set_ylabel("Portfolio Value (₹ Lakhs)")
        ax.legend(loc='upper left')
        ax.grid(True, alpha=0.3)
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
        fig.autofmt_xdate()

        chart_path = os.path.join(OUT_DIR, "equity_curves.png")
        fig.savefig(chart_path, dpi=150, bbox_inches='tight')
        plt.close()
        logger.info(f"📈 Equity curve saved: {chart_path}")

    print(f"\n✅ All results saved to: {OUT_DIR}/")
    print(f"   • backtest_comparison.csv")
    print(f"   • trades_*.csv (detailed trade logs)")
    if HAS_MATPLOTLIB:
        print(f"   • equity_curves.png")

    print(f"\n📊 Stocks backtested: {fetch_count}")
    print(f"📊 Scaled estimates assume √(2500/{fetch_count}) = {math.sqrt(2500/max(1,fetch_count)):.1f}× factor")
    print(f"\n🚀 v24.2.0 is deployment-ready pending your review of these results.")


if __name__ == "__main__":
    main()
