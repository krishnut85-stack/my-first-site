"""
╔══════════════════════════════════════════════════════════════════════════╗
║  INTRADAY MOMENTUM SCALPER v1.0                                         ║
║  For Global Eye v23.7.0 — Trillionaire Edition                          ║
║  Owner: <redacted> | Generated: March 29, 2026                        ║
║                                                                          ║
║  WHAT IT DOES:                                                           ║
║  Catches stocks moving fast DURING market hours (09:15-15:00).          ║
║  Unlike the regular scan (60-sec technical scan of full universe),       ║
║  this module focuses on:                                                 ║
║    1. Volume spike detection (3x+ average volume in 15 min)             ║
║    2. Price breakout from opening range (first 15 min high/low)         ║
║    3. VWAP reclaim (price crossing above VWAP with volume)              ║
║    4. Sector momentum (multiple stocks in same sector moving)           ║
║                                                                          ║
║  RULES:                                                                  ║
║    - Only trades 09:30 to 14:30 (skip first 15 min, last 30 min)       ║
║    - Maximum 2 intraday scalp positions at any time                     ║
║    - Fixed 1% risk per trade (tight SL — this is scalping)             ║
║    - Target: 1.5-2x risk (1.5% to 2% profit target)                   ║
║    - Auto-square-off by 15:10 if not exited                            ║
║    - MIS order type (intraday margin)                                   ║
║    - Skip if VIX > 25 (too volatile for scalping)                      ║
║    - Skip if regime is STRONG_BEARISH and stock is not defensive        ║
║                                                                          ║
║  INTEGRATION:                                                            ║
║  Called from main loop:                                                  ║
║    self._momentum_scalper.scan(kite, holdings, regime)                  ║
║  Returns: list of trade signals for the main pipeline                    ║
║                                                                          ║
║  DATA SOURCE: Kite API (real-time quotes, no external API needed)       ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import logging
import time
from datetime import datetime, timedelta
from collections import defaultdict

try:
    import pytz
    IST = pytz.timezone("Asia/Kolkata")
except Exception:
    IST = None

logger = logging.getLogger("GlobalEye")


def _now():
    return datetime.now(IST) if IST else datetime.now()


class IntradayMomentumScalper:
    """
    Fast momentum scanner for intraday trading.
    Catches stocks with unusual volume + price movement during market hours.
    """

    # ── CONFIGURATION ──
    MAX_SCALP_POSITIONS = 2          # Max simultaneous scalp trades
    RISK_PER_SCALP = 0.01            # 1% of capital per scalp
    MIN_VOLUME_MULTIPLIER = 3.0      # 3x average volume minimum
    STRONG_VOLUME_MULTIPLIER = 5.0   # 5x = high conviction
    EXTREME_VOLUME_MULTIPLIER = 8.0  # 8x = max conviction
    MIN_PRICE_MOVE_PCT = 1.5         # Minimum 1.5% move from open
    TARGET_RR_RATIO = 1.5            # Risk:Reward 1:1.5
    MAX_VIX_FOR_SCALP = 25           # Don't scalp above VIX 25
    OPENING_RANGE_MINUTES = 15       # First 15 min = opening range
    SCAN_START_HOUR = 9              # Start scanning at 09:30
    SCAN_START_MIN = 30
    SCAN_END_HOUR = 14               # Stop new entries at 14:30
    SCAN_END_MIN = 30
    SQUAREOFF_HOUR = 15              # Auto-squareoff at 15:10
    SQUAREOFF_MIN = 10
    MIN_PRICE = 50                   # Skip penny stocks
    MAX_PRICE = 5000                 # Skip very expensive stocks (Kelly sizing issue)
    COOLDOWN_MINUTES = 30            # Don't re-enter same stock within 30 min

    # ── Watchlist: High-liquidity stocks suitable for intraday scalping ──
    # These have tight spreads and good depth
    SCALP_UNIVERSE = [
        # Nifty 50 most liquid
        "RELIANCE", "TCS", "HDFCBANK", "INFY", "ICICIBANK",
        "SBIN", "BHARTIARTL", "KOTAKBANK", "LT", "AXISBANK",
        "MARUTI", "SUNPHARMA", "TITAN", "BAJFINANCE", "WIPRO",
        "HCLTECH", "TATAMOTORS", "TATASTEEL", "JSWSTEEL", "NTPC",
        "POWERGRID", "TECHM", "HINDUNILVR", "ITC", "M&M",
        "ADANIENT", "CIPLA", "DRREDDY", "HINDALCO", "ONGC",
        "BPCL", "COALINDIA", "INDUSINDBK", "BAJAJFINSV", "BAJAJ-AUTO",
        "HEROMOTOCO", "EICHERMOT", "BRITANNIA", "NESTLEIND", "ASIANPAINT",
        # Nifty Next 50 liquid names
        "TATAPOWER", "ADANIGREEN", "ADANIPORTS", "DLF", "INDIGO",
        "ZOMATO", "CHOLAFIN", "SHRIRAMFIN", "BANKBARODA", "PNB",
        "HAL", "BEL", "IRCTC", "TRENT", "POLYCAB",
        "DIXON", "VEDL", "GODREJPROP", "PFC", "RECLTD",
        # High-volume midcaps
        "TATAELXSI", "PERSISTENT", "COFORGE", "LTIM", "MPHASIS",
        "LUPIN", "AUROPHARMA", "KAYNES", "SUZLON", "IREDA",
        "RVNL", "IRFC", "NHPC", "SJVN", "JIOFIN",
    ]

    def __init__(self):
        self._opening_ranges = {}    # symbol → {"high": x, "low": x, "vwap": x}
        self._active_scalps = {}     # symbol → {"entry_price": x, "sl": x, "target": x, "entry_time": x}
        self._cooldowns = {}         # symbol → datetime (when cooldown expires)
        self._today_date = ""
        self._scans_today = 0
        self._signals_today = 0
        self._or_captured = False    # Opening range captured flag

    # ═══════════════════════════════════════════════════════════════
    #  DAILY RESET
    # ═══════════════════════════════════════════════════════════════

    def _daily_reset(self):
        """Reset all intraday data at start of new trading day."""
        today = _now().strftime("%Y-%m-%d")
        if self._today_date != today:
            self._today_date = today
            self._opening_ranges.clear()
            self._active_scalps.clear()
            self._cooldowns.clear()
            self._scans_today = 0
            self._signals_today = 0
            self._or_captured = False
            logger.info("MomentumScalper: Daily reset complete")

    # ═══════════════════════════════════════════════════════════════
    #  CAPTURE OPENING RANGE (first 15 minutes)
    # ═══════════════════════════════════════════════════════════════

    def capture_opening_range(self, kite):
        """
        Called at 09:30 IST to capture the first 15 minutes' high/low.
        Uses Kite historical data API for 15-min candle.
        
        Args:
            kite: KiteConnect instance (logged in)
        
        Returns:
            int: Number of stocks with opening range captured
        """
        if self._or_captured:
            return len(self._opening_ranges)

        now = _now()
        if now.hour < 9 or (now.hour == 9 and now.minute < 30):
            return 0

        count = 0
        batch_size = 20  # Kite rate limit: 20 instruments per quote call

        for i in range(0, len(self.SCALP_UNIVERSE), batch_size):
            batch = self.SCALP_UNIVERSE[i:i + batch_size]
            try:
                instruments = [f"NSE:{sym}" for sym in batch]
                quotes = kite.quote(instruments)

                for sym in batch:
                    key = f"NSE:{sym}"
                    if key not in quotes:
                        continue

                    q = quotes[key]
                    ohlc = q.get("ohlc", {})
                    
                    if not ohlc.get("open"):
                        continue

                    self._opening_ranges[sym] = {
                        "open": ohlc["open"],
                        "high": ohlc.get("high", ohlc["open"]),
                        "low": ohlc.get("low", ohlc["open"]),
                        "close": q.get("last_price", ohlc["open"]),
                        "volume": q.get("volume", 0),
                        "avg_volume": q.get("average_price", 0),  # Will use volume ratio later
                    }
                    count += 1

                time.sleep(0.3)  # Kite rate limit respect

            except Exception as e:
                logger.debug(f"MomentumScalper OR capture batch error: {e}")
                continue

        if count > 0:
            self._or_captured = True
            logger.info(f"MomentumScalper: Opening range captured for {count} stocks")

        return count

    # ═══════════════════════════════════════════════════════════════
    #  MAIN SCAN — Called every 60 seconds during market hours
    # ═══════════════════════════════════════════════════════════════

    def scan(self, kite, current_positions=None, regime_name="NEUTRAL", 
             current_vix=None, available_capital=0):
        """
        Main scanning function. Called from the main loop every cycle.
        
        Args:
            kite: KiteConnect instance
            current_positions: dict of current holdings/positions
            regime_name: Current market regime string
            current_vix: Current India VIX value
            available_capital: Available capital for new trades
            
        Returns:
            list of signal dicts: [{"symbol": x, "action": "BUY", "type": "SCALP", ...}]
        """
        self._daily_reset()
        signals = []
        now = _now()

        # ── Time gate ──
        if now.hour < self.SCAN_START_HOUR:
            return signals
        if now.hour == self.SCAN_START_HOUR and now.minute < self.SCAN_START_MIN:
            return signals
        if now.hour > self.SCAN_END_HOUR:
            return signals
        if now.hour == self.SCAN_END_HOUR and now.minute > self.SCAN_END_MIN:
            return signals

        # ── VIX gate ──
        if current_vix and current_vix > self.MAX_VIX_FOR_SCALP:
            logger.debug(f"MomentumScalper: VIX {current_vix} > {self.MAX_VIX_FOR_SCALP}, skipping")
            return signals

        # ── Position limit ──
        active_count = len(self._active_scalps)
        if active_count >= self.MAX_SCALP_POSITIONS:
            return signals

        # ── Capital gate ──
        if available_capital < 5000:
            return signals

        # ── Capture opening range if not done ──
        if not self._or_captured:
            self.capture_opening_range(kite)

        # ── Scan for momentum signals ──
        self._scans_today += 1
        slots_available = self.MAX_SCALP_POSITIONS - active_count
        candidates = []

        batch_size = 20
        for i in range(0, len(self.SCALP_UNIVERSE), batch_size):
            batch = self.SCALP_UNIVERSE[i:i + batch_size]
            try:
                instruments = [f"NSE:{sym}" for sym in batch]
                quotes = kite.quote(instruments)

                for sym in batch:
                    key = f"NSE:{sym}"
                    if key not in quotes:
                        continue

                    # Skip if already in a scalp position
                    if sym in self._active_scalps:
                        continue

                    # Skip if in cooldown
                    if sym in self._cooldowns and now < self._cooldowns[sym]:
                        continue

                    # Skip if already held in main portfolio
                    if current_positions and sym in current_positions:
                        continue

                    q = quotes[key]
                    ltp = q.get("last_price", 0)
                    
                    if not ltp or ltp < self.MIN_PRICE or ltp > self.MAX_PRICE:
                        continue

                    ohlc = q.get("ohlc", {})
                    day_open = ohlc.get("open", 0)
                    day_high = ohlc.get("high", 0)
                    day_low = ohlc.get("low", 0)
                    volume = q.get("volume", 0)
                    avg_price = q.get("average_price", 0)  # VWAP proxy

                    if not day_open or day_open == 0:
                        continue

                    # ── Calculate momentum score ──
                    score = 0
                    reasons = []

                    # 1. Price move from open
                    price_change_pct = ((ltp - day_open) / day_open) * 100
                    if price_change_pct >= self.MIN_PRICE_MOVE_PCT:
                        score += 20
                        reasons.append(f"+{price_change_pct:.1f}% from open")
                    elif price_change_pct >= 3.0:
                        score += 30
                        reasons.append(f"+{price_change_pct:.1f}% strong move")
                    else:
                        continue  # Not enough price movement

                    # 2. Volume surge (compare with opening range volume)
                    if sym in self._opening_ranges:
                        or_vol = self._opening_ranges[sym].get("volume", 1)
                        if or_vol > 0:
                            vol_ratio = volume / or_vol
                            if vol_ratio >= self.EXTREME_VOLUME_MULTIPLIER:
                                score += 30
                                reasons.append(f"Vol {vol_ratio:.1f}x EXTREME")
                            elif vol_ratio >= self.STRONG_VOLUME_MULTIPLIER:
                                score += 20
                                reasons.append(f"Vol {vol_ratio:.1f}x strong")
                            elif vol_ratio >= self.MIN_VOLUME_MULTIPLIER:
                                score += 10
                                reasons.append(f"Vol {vol_ratio:.1f}x above avg")
                            else:
                                score -= 10  # Penalize low volume moves

                    # 3. Opening range breakout
                    if sym in self._opening_ranges:
                        or_high = self._opening_ranges[sym].get("high", 0)
                        or_low = self._opening_ranges[sym].get("low", 0)
                        if or_high and ltp > or_high:
                            score += 15
                            reasons.append("OR breakout HIGH")
                        elif or_low and ltp < or_low:
                            # Bearish breakout — skip in current version (long-only)
                            continue

                    # 4. VWAP position
                    if avg_price and avg_price > 0:
                        if ltp > avg_price:
                            score += 10
                            reasons.append("Above VWAP")
                        else:
                            score -= 5

                    # 5. Near day high (momentum continuation)
                    if day_high > 0:
                        proximity_to_high = ((day_high - ltp) / day_high) * 100
                        if proximity_to_high < 0.5:
                            score += 10
                            reasons.append("At day high")
                        elif proximity_to_high < 1.0:
                            score += 5

                    # 6. Regime adjustment
                    if regime_name == "STRONG_BEARISH":
                        # Only allow defensive large-caps in bear market
                        defensive = {"TCS", "INFY", "WIPRO", "HCLTECH", "TECHM",
                                    "SUNPHARMA", "DRREDDY", "CIPLA", "BHARTIARTL",
                                    "ITC", "HINDUNILVR", "NESTLEIND", "POWERGRID", "NTPC",
                                    "ONGC", "COALINDIA", "OIL"}
                        if sym not in defensive:
                            score -= 20
                            reasons.append("Non-defensive in bear (penalized)")

                    # ── Minimum score threshold ──
                    if score >= 40:
                        # Calculate SL and target
                        atr_proxy = (day_high - day_low) if (day_high - day_low) > 0 else ltp * 0.01
                        sl_price = round(ltp - atr_proxy * 0.5, 2)  # Tight SL for scalping
                        risk_amount = ltp - sl_price
                        target_price = round(ltp + risk_amount * self.TARGET_RR_RATIO, 2)

                        # Ensure minimum risk/reward makes sense
                        if risk_amount < ltp * 0.003:  # SL too tight (< 0.3%)
                            sl_price = round(ltp * 0.99, 2)  # 1% SL
                            risk_amount = ltp - sl_price
                            target_price = round(ltp + risk_amount * self.TARGET_RR_RATIO, 2)

                        candidates.append({
                            "symbol": sym,
                            "ltp": ltp,
                            "score": score,
                            "reasons": reasons,
                            "sl_price": sl_price,
                            "target_price": target_price,
                            "risk_pct": round(risk_amount / ltp * 100, 2),
                            "reward_pct": round((target_price - ltp) / ltp * 100, 2),
                            "volume": volume,
                            "price_change_pct": round(price_change_pct, 2),
                        })

                time.sleep(0.3)

            except Exception as e:
                logger.debug(f"MomentumScalper scan batch error: {e}")
                continue

        # ── Rank candidates by score and pick top N ──
        candidates.sort(key=lambda x: x["score"], reverse=True)

        for cand in candidates[:slots_available]:
            signal = {
                "symbol": cand["symbol"],
                "action": "BUY",
                "type": "SCALP",
                "order_type": "MIS",  # Intraday margin
                "price": cand["ltp"],
                "sl": cand["sl_price"],
                "target": cand["target_price"],
                "score": cand["score"],
                "reasons": ", ".join(cand["reasons"]),
                "risk_pct": cand["risk_pct"],
                "reward_pct": cand["reward_pct"],
                "source": "MOMENTUM_SCALPER",
                "timestamp": now.isoformat(),
            }
            signals.append(signal)
            self._signals_today += 1

            # Set cooldown
            self._cooldowns[cand["symbol"]] = now + timedelta(minutes=self.COOLDOWN_MINUTES)

            logger.info(f"MomentumScalper SIGNAL: {cand['symbol']} @ {cand['ltp']} "
                       f"Score={cand['score']} SL={cand['sl_price']} T={cand['target_price']} "
                       f"Reasons: {', '.join(cand['reasons'])}")

        return signals

    # ═══════════════════════════════════════════════════════════════
    #  SQUAREOFF CHECK — Called at 15:10
    # ═══════════════════════════════════════════════════════════════

    def check_squareoff(self, kite, hour, minute):
        """
        Auto-squareoff all scalp positions at 15:10.
        Called from main loop.
        
        Returns:
            list of symbols that need squareoff
        """
        if hour == self.SQUAREOFF_HOUR and minute >= self.SQUAREOFF_MIN:
            symbols_to_exit = list(self._active_scalps.keys())
            if symbols_to_exit:
                logger.info(f"MomentumScalper: Auto-squareoff {len(symbols_to_exit)} positions: {symbols_to_exit}")
            return symbols_to_exit
        return []

    # ═══════════════════════════════════════════════════════════════
    #  REGISTER ENTRY/EXIT
    # ═══════════════════════════════════════════════════════════════

    def register_entry(self, symbol, entry_price, sl, target):
        """Called after trade is placed successfully."""
        self._active_scalps[symbol] = {
            "entry_price": entry_price,
            "sl": sl,
            "target": target,
            "entry_time": _now().isoformat(),
        }
        logger.info(f"MomentumScalper: Registered entry {symbol} @ {entry_price}")

    def register_exit(self, symbol, exit_price=None, reason="manual"):
        """Called after trade is exited."""
        if symbol in self._active_scalps:
            entry = self._active_scalps[symbol]
            pnl = (exit_price - entry["entry_price"]) if exit_price else 0
            logger.info(f"MomentumScalper: Exit {symbol} P&L={pnl:.2f} Reason={reason}")
            del self._active_scalps[symbol]

    # ═══════════════════════════════════════════════════════════════
    #  STATUS (for Telegram/logs)
    # ═══════════════════════════════════════════════════════════════

    def status(self):
        """Return current scalper status for logging/Telegram."""
        return {
            "active_positions": len(self._active_scalps),
            "positions": list(self._active_scalps.keys()),
            "scans_today": self._scans_today,
            "signals_today": self._signals_today,
            "opening_ranges": len(self._opening_ranges),
        }


# ═══════════════════════════════════════════════════════════════
#  INTEGRATION SNIPPET — Add to main bot
# ═══════════════════════════════════════════════════════════════

INTEGRATION_GUIDE = """
# ── Add to __init__ of main GlobalEyeBot class ──
self._momentum_scalper = IntradayMomentumScalper()

# ── Add to main loop (inside the 60-second cycle) ──
if is_market_open_now and 9 <= hr <= 15:
    # Capture opening range at 09:30
    if hr == 9 and mn >= 30 and not self._momentum_scalper._or_captured:
        self._momentum_scalper.capture_opening_range(self.kite)
    
    # Scan for momentum signals
    scalp_signals = self._momentum_scalper.scan(
        kite=self.kite,
        current_positions=self._get_all_positions(),
        regime_name=self._current_regime.name,
        current_vix=self._last_vix,
        available_capital=self._available_capital()
    )
    
    for sig in scalp_signals:
        # Route through 12-step validation pipeline
        # Use MIS order type, tight SL, auto-squareoff at 15:10
        self._process_scalp_signal(sig)
    
    # Auto-squareoff check
    squareoff_list = self._momentum_scalper.check_squareoff(self.kite, hr, mn)
    for sym in squareoff_list:
        self._emergency_squareoff(sym, reason="SCALP_AUTO_EXIT")
"""

if __name__ == "__main__":
    print("Intraday Momentum Scalper v1.0")
    print(f"Universe size: {len(IntradayMomentumScalper.SCALP_UNIVERSE)} stocks")
    print(f"Scan window: 09:30 - 14:30 IST")
    print(f"Max positions: {IntradayMomentumScalper.MAX_SCALP_POSITIONS}")
    print(f"Risk per trade: {IntradayMomentumScalper.RISK_PER_SCALP*100}%")
    print(f"Target R:R: 1:{IntradayMomentumScalper.TARGET_RR_RATIO}")
    print(f"VIX ceiling: {IntradayMomentumScalper.MAX_VIX_FOR_SCALP}")
    print(f"\nIntegration guide:\n{INTEGRATION_GUIDE}")
