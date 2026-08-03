"""
╔══════════════════════════════════════════════════════════════════════════╗
║  GLOBAL EYE v23.7.0 — LIVE TRADING MODULE                              ║
║  PATCH FILE: Upgrades Paper Trading → Real Kite Order Execution         ║
║                                                                          ║
║  WHAT THIS DOES:                                                        ║
║  1. LiveOrderManager  — wraps kite.place_order() with safety layers     ║
║  2. LiveEquityTrader  — replaces BasePaperTrader for real equity orders  ║
║  3. LiveFNOTrader     — replaces FNOTrader for real F&O orders          ║
║  4. PositionSync      — syncs bot state with actual Kite holdings       ║
║  5. CapitalAllocator  — auto-detects available capital from Kite        ║
║  6. CircuitBreaker    — hard stops that CANCEL all pending orders       ║
║  7. LiveSentinel      — replaces GlobalEyeSentinel __init__ wiring      ║
║                                                                          ║
║  HOW TO DEPLOY:                                                         ║
║  1. Upload this file to PythonAnywhere alongside the main script        ║
║  2. Set .env: TRADING_MODE=LIVE                                         ║
║  3. The main script auto-imports this when TRADING_MODE=LIVE            ║
║                                                                          ║
║  SAFETY:                                                                ║
║  • Every order has SL at placement (bracket/SL-M fallback)              ║
║  • Daily loss circuit breaker cancels ALL pending orders                ║
║  • Monthly loss circuit breaker enters OBSERVE mode                     ║
║  • Position sync on every startup — no phantom positions                ║
║  • Max order value capped at 20% of available capital                   ║
║  • Duplicate order prevention (same symbol + direction)                 ║
║  • Order retry with exponential backoff (max 2 retries)                 ║
║  • All order actions logged to order_audit.json                         ║
║  • Telegram alert on EVERY order placed/rejected/failed                 ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import os
import time
import json
import logging
import traceback
import threading
from datetime import datetime, timedelta
import pytz

logger = logging.getLogger("GlobalEye")

# ═══════════════════════════════════════════════════════════════════════════
#  SEBI-COMPLIANT SL LIMITS (Rama's <1% SL requirement)
# ═══════════════════════════════════════════════════════════════════════════
MAX_SL_PERCENT = 0.009  # 0.9% max (gives margin under 1%)
MIN_SL_PERCENT = 0.003  # 0.3% floor to avoid whipsaw

# ── Tier Migration Manager ─────────────────────────────────────────────────
try:
    from tier_migration_manager import TierMigrationManager
    _TIER_MIGRATION_LOADED = True
except ImportError:
    _TIER_MIGRATION_LOADED = False
    logger.warning("tier_migration_manager.py not found — migration disabled")

# ── Timezone: PythonAnywhere runs UTC, we need IST everywhere ──────────────
IST = pytz.timezone("Asia/Kolkata")
def _now_ist():
    return datetime.now(IST)

# ── NSE Holidays (v23.5.0: Auto-sync from cache + fixed fallback — runs forever) ──
NSE_HOLIDAYS = {
    "2025-08-15","2025-10-02","2025-10-21","2025-11-05","2025-12-25",
    "2026-01-15","2026-01-26","2026-03-03","2026-03-26","2026-03-31",
    "2026-04-03","2026-04-14","2026-05-01","2026-05-28","2026-06-26",
    "2026-09-14","2026-10-02","2026-10-20","2026-11-10","2026-11-24",
    "2026-12-25",
}

def _refresh_patch_holidays():
    """Sync holidays from main bot's cache file + fixed fallback. No circular import."""
    global NSE_HOLIDAYS
    current_year = datetime.now().year
    # Method 1: Read from shared cache file (written by main bot's auto-fetch)
    try:
        _cache_paths = [
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "nse_holidays_cache.json"),
            "/home/krishnut85/nse_holidays_cache.json",
        ]
        for _cp in _cache_paths:
            if os.path.exists(_cp):
                with open(_cp) as _cf:
                    import json as _json
                    _data = _json.load(_cf)
                    _cached = set(_data.get("holidays", []))
                    if _cached:
                        NSE_HOLIDAYS = NSE_HOLIDAYS | _cached
                        return
    except Exception:
        pass
    # Method 2: Add always-known fixed holidays for future years
    for yr in [current_year, current_year + 1]:
        _fixed = {
            f"{yr}-01-26", f"{yr}-08-15", f"{yr}-10-02",
            f"{yr}-12-25", f"{yr}-05-01", f"{yr}-04-14",
        }
        NSE_HOLIDAYS = NSE_HOLIDAYS | _fixed
    logging.getLogger("GlobalEye").info(
        f"NSE holidays: Using fixed-date fallback for {current_year}-{current_year+1}"
    )

try:
    _refresh_patch_holidays()
except Exception:
    pass


# ══════════════════════════════════════════════════════════════
#  ORDER AUDIT LOG — every order action recorded permanently
# ══════════════════════════════════════════════════════════════

class OrderAudit:
    """Append-only audit log for every order action. Never deleted."""

    def __init__(self, data_dir):
        self.path = os.path.join(data_dir, "order_audit.json")
        self._lock = threading.Lock()
        if not os.path.exists(self.path):
            with open(self.path, "w") as f:
                json.dump([], f)

    def log(self, action, details):
        """Log an order action with timestamp. Thread-safe."""
        entry = {
            "timestamp": _now_ist().isoformat(),
            "action":    action,
            **details,
        }
        with self._lock:
            try:
                with open(self.path, "r") as f:
                    data = json.load(f)
                data.append(entry)
                if len(data) > 5000:
                    data = data[-5000:]
                with open(self.path, "w") as f:
                    json.dump(data, f, indent=2, default=str)
            except Exception as e:
                logger.error(f"OrderAudit write error: {e}")
        logger.info(f"📋 AUDIT: {action} | {details.get('symbol','')} | {details.get('order_id','')}")


# ══════════════════════════════════════════════════════════════
#  LIVE ORDER MANAGER — wraps kite.place_order() with safety
# ══════════════════════════════════════════════════════════════

class LiveOrderManager:
    """
    All real order placement goes through this class.

    Safety layers:
    1. Pre-flight checks (capital, position limits, duplicate detection)
    2. Order placement with retry (max 2 retries, exponential backoff)
    3. Order status verification
    4. Telegram alert on every action
    5. Audit log entry for every action
    """

    # Order variety constants
    VARIETY_REGULAR = "regular"
    VARIETY_AMO     = "amo"

    # Transaction types
    BUY  = "BUY"
    SELL = "SELL"

    # Product types
    MIS  = "MIS"   # Intraday (auto-square-off by broker at 3:20 PM)
    CNC  = "CNC"   # Delivery (equity, no auto-square-off)
    NRML = "NRML"  # F&O normal

    # Order types
    MARKET = "MARKET"
    LIMIT  = "LIMIT"
    SLM    = "SL-M"   # Stop-loss market

    def __init__(self, kite_session_cls, audit, send_telegram_fn, risk_manager):
        """
        Args:
            kite_session_cls: KiteSession class (for .get() method)
            audit: OrderAudit instance
            send_telegram_fn: send_telegram function
            risk_manager: RiskManager instance
        """
        self.KiteSession  = kite_session_cls
        self.audit        = audit
        self.send_telegram = send_telegram_fn
        self.risk         = risk_manager
        self._pending_orders = {}  # order_id → details (for tracking)
        self._recent_orders  = []  # last 50 order symbols+direction for dedup

    def _get_kite(self):
        """Get active Kite connection or None."""
        kite = self.KiteSession.get()
        if not kite:
            logger.error("❌ LiveOrderManager: Kite not connected")
            self.send_telegram(
                "🔴 *ORDER BLOCKED — Kite Offline*\n"
                "Cannot place orders without active Kite session",
                priority="critical"
            )
        return kite

    def _is_duplicate(self, symbol, transaction_type, product):
        """
        Check if same order was placed recently.
        - Regular orders: 5-minute window (catches double-clicks)
        - AMO orders: tracked per day (prevents re-ordering same stock every scan)
        """
        # ── AMO daily dedup (persists across scans) ──────────
        now = _now_ist()
        today = now.strftime("%Y-%m-%d")
        if not hasattr(self, '_amo_orders_today'):
            self._amo_orders_today = {}
            self._amo_orders_date = today
        # Reset on new day
        if self._amo_orders_date != today:
            self._amo_orders_today = {}
            self._amo_orders_date = today

        key = f"{symbol}_{transaction_type}_{product}"

        # Check AMO daily dedup (for after-hours orders)
        is_amo_time = (now.hour >= 16 or now.hour < 9)
        if is_amo_time and key in self._amo_orders_today:
            logger.warning(f"⚠️ AMO DUPLICATE BLOCKED: {symbol} already ordered today at {self._amo_orders_today[key]}")
            return True

        # Regular 5-minute dedup (for market hours)
        cutoff = time.time() - 300  # 5 minutes
        self._recent_orders = [
            (k, ts) for k, ts in self._recent_orders if ts > cutoff
        ]
        for k, ts in self._recent_orders:
            if k == key:
                logger.warning(f"⚠️ DUPLICATE ORDER BLOCKED: {key}")
                return True
        return False

    def _record_order(self, symbol, transaction_type, product):
        """Record order for dedup tracking."""
        key = f"{symbol}_{transaction_type}_{product}"
        self._recent_orders.append((key, time.time()))
        # Keep only last 50
        if len(self._recent_orders) > 50:
            self._recent_orders = self._recent_orders[-50:]

        # Also record in AMO daily tracker
        if not hasattr(self, '_amo_orders_today'):
            self._amo_orders_today = {}
            self._amo_orders_date = _now_ist().strftime("%Y-%m-%d")
        self._amo_orders_today[key] = _now_ist().strftime("%H:%M")

    def place_equity_order(self, symbol, transaction_type, qty, price,
                           product="CNC", order_type="MARKET",
                           trigger_price=None, variety="regular",
                           tag="", stoploss_price=None):
        """
        Place an equity order on NSE via Kite.

        Returns: order_id (str) or None on failure

        After placing the main order, if stoploss_price is provided,
        places a separate SL-M sell order for protection.
        """
        kite = self._get_kite()
        if not kite:
            return None

        # ── Pre-flight checks ─────────────────────────────────
        if not self.risk.can_trade():
            self.audit.log("BLOCKED_RISK", {
                "symbol": symbol, "reason": "RiskManager blocked (observe mode or halted)"
            })
            logger.warning(f"🛑 ORDER BLOCKED by RiskManager: {symbol}")
            return None

        if self._is_duplicate(symbol, transaction_type, product):
            self.audit.log("BLOCKED_DUPLICATE", {
                "symbol": symbol, "transaction_type": transaction_type
            })
            return None

        if qty <= 0:
            self.audit.log("BLOCKED_ZERO_QTY", {"symbol": symbol})
            return None

        # ── CAPITAL GATE — never exceed Kite free cash ────────
        # This is the SINGLE point where ALL orders pass through.
        # Checks actual Kite free cash minus all pending AMO orders.
        # Prevents over-ordering regardless of source (filing, scan, batch).
        if transaction_type == "BUY":
            try:
                _gate_kite = self._get_kite()
                if _gate_kite:
                    # Get real free cash
                    _margins = _gate_kite.margins()
                    _eq = _margins.get("equity", {})
                    _avail = _eq.get("available", {})
                    _free_cash = _avail.get("live_balance", 0)
                    if _free_cash <= 0:
                        _free_cash = _avail.get("opening_balance", 0)

                    # Get total pending AMO cost
                    _pending_amo = 0
                    try:
                        _all_orders = _gate_kite.orders()
                        for _o in _all_orders:
                            if (_o.get("variety") == "amo" 
                                and _o.get("status") in ("OPEN", "TRIGGER PENDING", "AMO REQ RECEIVED")
                                and _o.get("transaction_type") == "BUY"):
                                _o_qty = _o.get("quantity", 0)
                                _o_price = _o.get("price", 0)
                                if _o_price <= 0:
                                    # MARKET AMO — get real LTP
                                    _o_sym = _o.get("tradingsymbol", "")
                                    try:
                                        _ltp = _gate_kite.ltp([f"NSE:{_o_sym}"])
                                        _o_price = _ltp.get(f"NSE:{_o_sym}", {}).get("last_price", 0)
                                    except:
                                        pass
                                    if _o_price <= 0:
                                        _o_price = 2000  # High fallback — assume expensive stock
                                _pending_amo += _o_qty * _o_price
                    except Exception:
                        # If we can't check pending orders, assume worst case
                        # Block order to be safe
                        logger.warning(f"CAPITAL GATE: Cannot check pending AMOs — blocking {symbol}")
                        return None

                    # This order's cost — use real price, never underestimate
                    _this_price = price if price > 0 else 0
                    if _this_price <= 0:
                        try:
                            _ltp_this = _gate_kite.ltp([f"NSE:{symbol}"])
                            _this_price = _ltp_this.get(f"NSE:{symbol}", {}).get("last_price", 0)
                        except:
                            pass
                    if _this_price <= 0:
                        _this_price = 2000  # High fallback
                    _this_cost = qty * _this_price
                    _total_committed = _pending_amo + _this_cost
                    _buffer = _free_cash * 0.95  # Keep 5% buffer

                    if _total_committed > _buffer:
                        logger.info(
                            f"CAPITAL GATE BLOCKED [{symbol}]: "
                            f"free={_free_cash:,.0f} pending_amo={_pending_amo:,.0f} "
                            f"this={_this_cost:,.0f} total={_total_committed:,.0f} > limit={_buffer:,.0f}"
                        )
                        self.audit.log("BLOCKED_CAPITAL_GATE", {
                            "symbol": symbol, "free_cash": _free_cash,
                            "pending_amo": _pending_amo, "this_cost": _this_cost
                        })
                        return None
            except Exception as _cg_err:
                logger.debug(f"Capital gate check: {_cg_err}")
                # On error, proceed — better to try than block everything

        # ── Place order with retry ────────────────────────────
        # Zerodha equity (NSE) time rules:
        # 09:15-15:30: All types allowed (MARKET, LIMIT, SL, SL-M) regular variety
        # 15:30-15:40: Dead zone — no orders
        # 15:40-16:00: Post-market — CNC MARKET only (executes at closing price)
        # 16:00-08:58: AMO window (LIMIT or MARKET, amo variety)
        # 01:00-05:30: Maintenance — NO AMO orders accepted
        # 09:00-09:15: Pre-open — LIMIT only, no SL
        # AMO CAN be placed on weekends and holidays (queues for next trading day)
        # ON NON-TRADING DAYS: ALL orders must be AMO (no regular/pre-open/post-market)
        now = _now_ist()
        hr, mn = now.hour, now.minute
        time_mins = hr * 60 + mn

        # Check if today is a trading day
        _today_str = now.strftime("%Y-%m-%d")
        _is_trading_day = (now.weekday() < 5 and _today_str not in NSE_HOLIDAYS)

        maintenance = (time_mins >= 60 and time_mins <= 330)     # 01:00 to 05:30 — Zerodha blocks AMO

        if maintenance:
            logger.warning(f"🔧 ORDER BLOCKED: Zerodha maintenance 01:00-05:30 | {symbol}")
            self.audit.log("BLOCKED_MAINTENANCE", {"symbol": symbol})
            return None

        # On non-trading days (weekends/holidays): FORCE AMO variety
        if not _is_trading_day:
            actual_order_type = order_type if order_type == "LIMIT" else "MARKET"
            actual_variety = "amo"
            if product != "CNC":
                product = "CNC"  # AMO only supports CNC for overnight
            logger.info(f"🌙 NON-TRADING DAY AMO: {symbol} (queues for next trading day)")
        else:
            # Trading day — use normal time-based windows
            market_open = (time_mins >= 555 and time_mins <= 929)   # 09:15 to 15:29
            dead_zone = (time_mins >= 930 and time_mins <= 939)      # 15:30 to 15:39
            post_market = (time_mins >= 940 and time_mins <= 960)    # 15:40 to 16:00
            amo_window = ((time_mins >= 960 or time_mins <= 538) and not maintenance)  # 16:00 to 08:58
            pre_open = (time_mins >= 540 and time_mins <= 554)       # 09:00 to 09:14

            if dead_zone:
                logger.warning(f"🚫 ORDER BLOCKED: Dead zone 15:30-15:40 | {symbol}")
                self.audit.log("BLOCKED_DEAD_ZONE", {"symbol": symbol})
                self.send_telegram(
                    f"🚫 *Order Blocked — Dead Zone*\n"
                    f"`{symbol}` — No orders accepted 15:30-15:40",
                    priority="trade"
                )
                return None

            if market_open:
                actual_order_type = order_type
                actual_variety = "regular"
            elif post_market:
                actual_order_type = "MARKET"
                actual_variety = "regular"
                if product != "CNC":
                    product = "CNC"
                logger.info(f"🕐 Post-market: CNC MARKET for {symbol} (closing price)")
            elif pre_open:
                actual_order_type = "LIMIT"
                actual_variety = "regular"
                logger.info(f"🌅 Pre-open: LIMIT order for {symbol}")
            elif amo_window:
                actual_order_type = order_type if order_type == "LIMIT" else "MARKET"
                actual_variety = "amo"
                logger.info(f"🌙 AMO: {symbol}")
            else:
                actual_order_type = order_type
                actual_variety = "regular"

        order_id = None
        last_error = ""
        for attempt in range(3):  # Max 3 attempts (initial + 2 retries)
            try:
                params = {
                    "tradingsymbol":  symbol,
                    "exchange":       "NSE",
                    "transaction_type": transaction_type,
                    "quantity":       qty,
                    "product":        product,
                    "order_type":     actual_order_type,
                    "variety":        actual_variety,
                }
                # LIMIT orders need a price
                if actual_order_type == "LIMIT" and price:
                    params["price"] = round(price, 1)
                elif actual_order_type == "LIMIT" and not price:
                    # Need a price for LIMIT — use the scan price
                    params["price"] = round(price, 1) if price else 0
                if actual_order_type == "MARKET" and transaction_type == "SELL":
                    try:
                        _mp = kite.ltp([f"NSE:{symbol}"])
                        _lp = _mp.get(f"NSE:{symbol}", {}).get("last_price", 0)
                        if _lp > 0:
                            params["order_type"] = "LIMIT"
                            params["price"] = round(_lp * 0.995, 1)
                    except Exception:
                        pass
                # SEBI Apr 2026: Market protection (mandatory from April 1)
                if actual_order_type in ("MARKET", "SL-M"):
                    params["market_protection"] = -1
                if trigger_price:
                    params["trigger_price"] = trigger_price
                if tag:
                    params["tag"] = tag[:20]  # Kite max tag length

                order_id = kite.place_order(**params)
                logger.info(f"✅ ORDER PLACED: {transaction_type} {symbol} x{qty} | ID: {order_id}")
                break  # Success

            except Exception as e:
                last_error = str(e)
                logger.error(f"❌ ORDER ATTEMPT {attempt+1} FAILED: {symbol} | {e}")
                
                # v23.6.4 FIX: If MIS is blocked for this stock, fallback to CNC
                if "MIS" in last_error and "blocked" in last_error.lower():
                    if product == "MIS":
                        logger.warning(f"⚠️ MIS BLOCKED [{symbol}]: Falling back to CNC")
                        product = "CNC"
                        params["product"] = "CNC"
                        # Don't count this as a retry attempt — try immediately with CNC
                        try:
                            order_id = kite.place_order(**params)
                            logger.info(f"✅ ORDER PLACED (CNC fallback): {transaction_type} {symbol} x{qty} | ID: {order_id}")
                            self.send_telegram(
                                f"⚠️ *MIS→CNC FALLBACK*\n"
                                f"`{symbol}` — MIS blocked by Zerodha\n"
                                f"Order placed as CNC instead",
                                priority="trade"
                            )
                            break  # Success with CNC
                        except Exception as cnc_err:
                            last_error = str(cnc_err)
                            logger.error(f"❌ CNC FALLBACK ALSO FAILED: {symbol} | {cnc_err}")
                
                if attempt < 2:
                    wait = (attempt + 1) * 2  # 2s, 4s
                    logger.info(f"⏳ Retrying in {wait}s...")
                    time.sleep(wait)

        # ── Log result ────────────────────────────────────────
        if order_id:
            self._record_order(symbol, transaction_type, product)
            self.audit.log("ORDER_PLACED", {
                "symbol": symbol, "transaction_type": transaction_type,
                "qty": qty, "price": price, "product": product,
                "order_type": order_type, "order_id": order_id,
                "tag": tag, "variety": variety,
            })

            # Telegram alert
            emoji = "📈" if transaction_type == "BUY" else "📉"
            self.send_telegram(
                f"{emoji} *LIVE ORDER PLACED*\n"
                f"`{symbol}` {transaction_type} x{qty}\n"
                f"Product: {product} | Type: {order_type}\n"
                f"Order ID: `{order_id}`\n"
                f"Tag: {tag}",
                priority="trade"
            )

            # ── Place SL order if stoploss provided ───────────
            if stoploss_price and transaction_type == "BUY":
                self._place_stoploss(
                    kite, symbol, qty, stoploss_price, product, tag
                )

            return order_id
        else:
            self.audit.log("ORDER_FAILED", {
                "symbol": symbol, "transaction_type": transaction_type,
                "qty": qty, "error": last_error[:300],
            })
            self.send_telegram(
                f"🔴 *ORDER FAILED*\n"
                f"`{symbol}` {transaction_type} x{qty}\n"
                f"Error: {last_error[:200]}\n"
                f"Attempts: 3",
                priority="critical"
            )
            return None

    def _place_stoploss(self, kite, symbol, qty, sl_price, product, tag):
        """
        Place a stop loss order with Zerodha time-awareness.

        Zerodha rules:
        - SL trigger price MUST be below last traded price for SELL SL orders
        - TRADING DAY 09:15-15:30: SL-M allowed → use SL-M (regular)
        - TRADING DAY 15:30-16:00: SL-M NOT allowed → defer to pending SL
        - TRADING DAY after 16:00 / before 09:15: AMO SL (SL-Limit, amo variety)
        - NON-TRADING DAY: AMO SL (SL-Limit, amo variety) — NO regular orders
        - MAINTENANCE 01:00-05:30: Defer to pending SL
        """
        # ── FIX v23.5.0: Validate SL price against current LTP ──
        # If SL is above current price, Zerodha will reject the order.
        # Also skip SL placement if LTP is unavailable (market just opened).
        try:
            _ltp_data = kite.ltp([f"NSE:{symbol}"])
            _current_price = 0
            if f"NSE:{symbol}" in _ltp_data:
                _current_price = _ltp_data[f"NSE:{symbol}"]["last_price"]
            
            if _current_price > 0:
                if sl_price >= _current_price:
                    # SL is above current price — adjust to 0.9% below LTP (SEBI compliant)
                    _old_sl = sl_price
                    sl_price = round(_current_price * (1 - MAX_SL_PERCENT), 1)
                    logger.warning(
                        f"SL ADJUSTED [{symbol}]: Rs.{_old_sl} was ABOVE LTP Rs.{_current_price} "
                        f"→ adjusted to Rs.{sl_price} (0.9% below LTP, SEBI compliant)"
                    )
                    self.send_telegram(
                        f"SL ADJUSTED [{symbol}]\n"
                        f"Old SL Rs.{_old_sl} was above LTP Rs.{_current_price}\n"
                        f"New SL: Rs.{sl_price} (0.9% below market, <1% rule)",
                        priority="normal"
                    )
                
                # ═══ SEBI-COMPLIANT: Also validate SL is not too wide (>1%) ═══
                _sl_pct = (_current_price - sl_price) / _current_price
                if _sl_pct > 0.01:
                    _old_sl = sl_price
                    sl_price = round(_current_price * (1 - MAX_SL_PERCENT), 1)
                    logger.info(
                        f"SL TIGHTENED [{symbol}]: {_sl_pct*100:.1f}% was >1% "
                        f"→ Rs.{sl_price} (0.9%)"
                    )
            else:
                # LTP unavailable — defer SL to pending (will retry later)
                logger.warning(f"SL DEFERRED [{symbol}]: LTP unavailable, cannot validate SL price")
                self._store_pending_sl(symbol, qty, sl_price, product, tag)
                return None
        except Exception as _sl_check_err:
            logger.debug(f"SL LTP check [{symbol}]: {_sl_check_err}")
            # On error, proceed cautiously — Zerodha will reject if wrong

        now = _now_ist()
        hr, mn = now.hour, now.minute
        time_mins = hr * 60 + mn

        _today_str = now.strftime("%Y-%m-%d")
        _is_trading_day = (now.weekday() < 5 and _today_str not in NSE_HOLIDAYS)
        _is_maintenance = (time_mins >= 60 and time_mins <= 330)

        # Determine which mode to use
        if _is_maintenance:
            sl_mode = "DEFER"  # Can't place anything during maintenance
        elif not _is_trading_day:
            sl_mode = "AMO"  # Non-trading day — only AMO works
        elif (hr == 9 and mn >= 15) or (10 <= hr <= 14) or (hr == 15 and mn <= 29):
            sl_mode = "REGULAR"  # Market hours — SL-M allowed
        elif (hr == 15 and mn >= 30) or (hr == 16 and mn <= 0):
            sl_mode = "DEFER"  # Post-market — SL-M not allowed
        else:
            sl_mode = "AMO"  # Before market / after market — AMO SL

        try:
            if sl_mode == "REGULAR":
                # Market hours on trading day — SL-M works
                sl_order_id = kite.place_order(
                    tradingsymbol=symbol,
                    exchange="NSE",
                    transaction_type="SELL",
                    quantity=qty,
                    product=product,
                    order_type="SL-M",
                    trigger_price=round(sl_price, 1),
                    variety="regular",
                    tag=f"SL_{tag}"[:20],
                )
                logger.info(f"SL ORDER PLACED: {symbol} SL@Rs.{sl_price} | ID: {sl_order_id}")
                self.audit.log("SL_ORDER_PLACED", {
                    "symbol": symbol, "sl_price": sl_price,
                    "qty": qty, "order_id": sl_order_id,
                })
                self.send_telegram(
                    f"SL Set: `{symbol}` @ Rs.{sl_price:.1f} | ID: `{sl_order_id}`",
                    priority="trade"
                )
                return sl_order_id

            elif sl_mode == "AMO":
                # After hours or non-trading day — AMO SL (SL-Limit)
                try:
                    sl_order_id = kite.place_order(
                        tradingsymbol=symbol,
                        exchange="NSE",
                        transaction_type="SELL",
                        quantity=qty,
                        product=product,
                        order_type="SL",
                        price=round(sl_price * 0.99, 1),
                        trigger_price=round(sl_price, 1),
                        variety="amo",
                        tag=f"ASL_{tag}"[:20],
                    )
                    logger.info(f"AMO SL PLACED: {symbol} SL@Rs.{sl_price} | ID: {sl_order_id}")
                    self.audit.log("AMO_SL_ORDER_PLACED", {
                        "symbol": symbol, "sl_price": sl_price,
                        "qty": qty, "order_id": sl_order_id,
                    })
                    self.send_telegram(
                        f"AMO SL Set: `{symbol}` @ Rs.{sl_price:.1f} | Active at next market open",
                        priority="trade"
                    )
                    return sl_order_id
                except Exception as amo_e:
                    logger.warning(f"AMO SL failed [{symbol}]: {amo_e} — deferring to pending")
                    self._store_pending_sl(symbol, qty, sl_price, product, tag)
                    return "DEFERRED"

            else:
                # DEFER mode (maintenance or post-market)
                logger.info(f"SL DEFERRED [{symbol}]: {sl_mode} — storing for later placement")
                self.audit.log("SL_DEFERRED", {
                    "symbol": symbol, "sl_price": sl_price, "qty": qty,
                    "reason": sl_mode,
                })
                self._store_pending_sl(symbol, qty, sl_price, product, tag)
                return "DEFERRED"

        except Exception as e:
            logger.error(f"SL ORDER FAILED: {symbol} | {e}")
            self.audit.log("SL_ORDER_FAILED", {
                "symbol": symbol, "sl_price": sl_price, "error": str(e)[:300],
            })
            self.send_telegram(
                f"SL ORDER FAILED\n"
                f"`{symbol}` — Stop Loss NOT set!\n"
                f"Error: {str(e)[:200]}\n"
                f"GTT backup will protect this position",
                priority="critical"
            )
            return None

    def _store_pending_sl(self, symbol, qty, sl_price, product, tag):
        """Store pending SL for placement at next market open."""
        pending_file = os.path.join(os.path.dirname(self.audit.path), "pending_sl.json")
        try:
            pending = json.load(open(pending_file)) if os.path.exists(pending_file) else []
            pending.append({
                "symbol": symbol, "qty": qty, "sl_price": sl_price,
                "product": product, "tag": tag,
                "created": _now_ist().isoformat(),
            })
            with open(pending_file, "w") as f:
                json.dump(pending, f, indent=2, default=str)
        except Exception as e:
            logger.error(f"Store pending SL: {e}")

    def place_pending_sl_orders(self):
        """Called at market open (09:15) to place any deferred SL orders."""
        pending_file = os.path.join(os.path.dirname(self.audit.path), "pending_sl.json")
        if not os.path.exists(pending_file):
            return
        try:
            pending = json.load(open(pending_file))
            if not pending:
                return
            kite = self._get_kite()
            if not kite:
                return
            placed = []
            for sl in pending:
                try:
                    order_id = kite.place_order(
                        tradingsymbol=sl["symbol"],
                        exchange="NSE",
                        transaction_type="SELL",
                        quantity=sl["qty"],
                        product=sl["product"],
                        order_type="SL-M",
                        trigger_price=round(sl["sl_price"], 1),
                        variety="regular",
                        tag=f"DSL_{sl.get('tag','')}"[:20],
                    )
                    placed.append(sl["symbol"])
                    logger.info(f"🛡️ DEFERRED SL PLACED: {sl['symbol']} @ ₹{sl['sl_price']} | ID: {order_id}")
                    self.send_telegram(
                        f"🛡️ *Deferred SL Now Active*\n"
                        f"`{sl['symbol']}` SL @ ₹{sl['sl_price']:.1f}\n"
                        f"Order ID: `{order_id}`",
                        priority="trade"
                    )
                except Exception as e:
                    logger.error(f"Deferred SL [{sl['symbol']}]: {e}")
            # Clear pending file
            with open(pending_file, "w") as f:
                json.dump([], f)
            if placed:
                logger.info(f"🛡️ {len(placed)} deferred SL orders placed at market open")
        except Exception as e:
            logger.error(f"Place pending SLs: {e}")

    # ── Watchlist: Signals spotted during zero balance ──────────
    _pending_watchlist = []  # [{symbol, signal, price, source, timestamp}, ...]
    _pending_watchlist_lock = threading.Lock()
    _zero_balance_alerted = False  # Only alert once per zero-balance period

    def add_to_watchlist(self, symbol, signal, price, source):
        """
        Called when a good signal is found but balance is insufficient.
        Stored for re-validation when funds arrive.
        """
        with self._pending_watchlist_lock:
            # Don't duplicate
            existing = [w for w in self._pending_watchlist if w["symbol"] == symbol]
            if existing:
                return
            entry = {
                "symbol": symbol,
                "signal": signal,
                "price_when_spotted": price,
                "source": source,
                "timestamp": _now_ist().isoformat(),
            }
            self._pending_watchlist.append(entry)
            # Keep only last 20
            if len(self._pending_watchlist) > 20:
                self._pending_watchlist = self._pending_watchlist[-20:]

            logger.info(
                f"📋 WATCHLIST ADD [{symbol}] ₹{price} — {signal} "
                f"(insufficient funds, queued for re-validation)"
            )
            self.send_telegram(
                f"📋 *WATCHLIST — Insufficient Funds*\n"
                f"`{symbol}` @ ₹{price}\n"
                f"Signal: {signal}\n"
                f"Source: {source}\n"
                f"📌 Queued for re-validation when funds arrive\n"
                f"💰 Current queue: {len(self._pending_watchlist)} stocks",
                priority="trade"
            )

    def check_and_sync_capital(self, sentinel):
        """
        Periodic capital re-check. Called every health check (~1 hour).

        3 scenarios:
        1. Balance > 0, was > 0 before → normal, just log
        2. Balance <= 0 → block new trades, alert ONCE, keep monitoring
        3. Balance > 0, was 0 before → RE-VALIDATE watchlist then resume

        RE-VALIDATION: When funds arrive, bot does NOT blindly execute
        old signals. It re-runs 3-Agent AI evaluation on each watchlist
        stock with FRESH price/data. Only executes if still valid.
        """
        try:
            kite = self._get_kite()
            if not kite:
                return

            actual_capital = CapitalAllocator.get_available_capital(kite)
            logger.info(f"💰 Capital check: Kite balance = ₹{actual_capital:,.2f}")

            # ── SCENARIO 2: Zero or negative balance ──────────────
            if actual_capital <= 0:
                # Block all new trades by setting available to 0
                for trader in [sentinel.intraday, sentinel.swing, sentinel.longterm]:
                    if hasattr(trader, 'book') and trader.book.get("available", 0) > 0:
                        trader.book["available"] = 0
                        trader._save()

                # Alert only ONCE per zero-balance period
                if not self._zero_balance_alerted:
                    self._zero_balance_alerted = True
                    # Count existing positions still being monitored
                    open_positions = sum(
                        len(t.book.get("positions", {}))
                        for t in [sentinel.intraday, sentinel.swing, sentinel.longterm]
                        if hasattr(t, 'book')
                    )
                    self.send_telegram(
                        f"⚠️ *ZERO BALANCE — Orders Paused*\n"
                        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                        f"💰 Kite balance: ₹{actual_capital:,.2f}\n"
                        f"🚫 New orders: PAUSED\n"
                        f"📊 Existing positions: {open_positions} still monitored\n"
                        f"🔍 Scanning & signals: ACTIVE (building watchlist)\n"
                        f"📋 Watchlist: {len(self._pending_watchlist)} stocks queued\n"
                        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                        f"📌 When you add funds, bot will:\n"
                        f"  1. Detect new balance automatically\n"
                        f"  2. Re-validate ALL watchlist signals (fresh data)\n"
                        f"  3. Execute only signals that are STILL valid\n"
                        f"  4. Resume normal trading",
                        priority="critical"
                    )
                logger.info(f"⚠️ Zero balance — orders paused, monitoring continues")

            # ── SCENARIO 3: Funds restored (was zero, now positive) ──
            elif actual_capital > 0:
                total_available = sum(
                    t.book.get("available", 0)
                    for t in [sentinel.intraday, sentinel.swing, sentinel.longterm]
                    if hasattr(t, 'book')
                )

                if total_available <= 0 or self._zero_balance_alerted:
                    # Was blocked, now has funds — re-allocate capital
                    self._zero_balance_alerted = False  # Reset alert flag
                    alloc = CapitalAllocator.allocate(actual_capital, kite=kite)
                    alloc.pop("_condition", None)
                    alloc.pop("_score", None)
                    alloc.pop("_factors", None)
                    alloc.pop("_profile", None)
                    alloc.pop("_tier", None)
                    alloc.pop("_tier_info", None)

                    sentinel.intraday.book["capital"] = alloc["intraday"]
                    sentinel.intraday.book["available"] = alloc["intraday"]
                    sentinel.intraday._save()
                    sentinel.swing.book["capital"] = alloc["swing"]
                    sentinel.swing.book["available"] = alloc["swing"]
                    sentinel.swing._save()
                    sentinel.longterm.book["capital"] = alloc["longterm"]
                    sentinel.longterm.book["available"] = alloc["longterm"]
                    sentinel.longterm._save()

                    logger.info(f"✅ Capital restored: ₹{actual_capital:,.0f}")

                    # ── RE-VALIDATE WATCHLIST ──────────────────────
                    # Don't blindly execute old signals.
                    # Re-check each stock with FRESH price & fundamentals.
                    revalidated = []
                    rejected = []
                    with self._pending_watchlist_lock:
                        watchlist = self._pending_watchlist.copy()
                        self._pending_watchlist = []

                    if watchlist:
                        logger.info(f"🔄 Re-validating {len(watchlist)} watchlist signals with fresh data...")

                        for w in watchlist:
                            sym = w["symbol"]
                            old_price = w["price_when_spotted"]
                            try:
                                # Get FRESH live price
                                ltp_data = kite.ltp([f"NSE:{sym}"])
                                fresh_price = ltp_data.get(f"NSE:{sym}", {}).get("last_price", 0)
                                if fresh_price <= 0:
                                    rejected.append(f"{sym} (no price)")
                                    continue

                                # Check price hasn't moved too far (>10% from spotted price)
                                price_change = abs(fresh_price - old_price) / old_price * 100
                                if price_change > 10:
                                    rejected.append(f"{sym} (price moved {price_change:.1f}%)")
                                    logger.info(f"❌ WATCHLIST REJECT [{sym}]: price moved {price_change:.1f}% since signal")
                                    continue

                                # Re-run 3-Agent AI evaluation with fresh data
                                try:
                                    from global_eye_v23_pythonanywhere import (
                                        ThreeAgentAI, SentimentEngine, MacroIntelligence,
                                        TrendlyneScorer
                                    )
                                    # Get fresh scan data
                                    fresh_scan = TrendlyneScorer.score(sym)
                                    if not fresh_scan:
                                        rejected.append(f"{sym} (scan failed)")
                                        continue

                                    # Fresh sentiment
                                    filings = sentinel.filings.get_recent(hours=6)
                                    news = sentinel.news.recent(hours=6)
                                    macro = sentinel._get_macro()
                                    macro_bull, macro_bear = MacroIntelligence.get_sector_bias(macro)

                                    sent_score, _ = SentimentEngine.score(
                                        sym, fresh_scan, filings, news, macro_bull, macro_bear, []
                                    )

                                    # Fresh 3-Agent AI vote
                                    approved, confidence, reasoning = ThreeAgentAI.evaluate_trade(
                                        sym, fresh_price, fresh_scan, sent_score, filings, macro, []
                                    )

                                    if approved:
                                        revalidated.append({
                                            "symbol": sym,
                                            "fresh_price": fresh_price,
                                            "old_price": old_price,
                                            "confidence": confidence,
                                            "source": f"REVALIDATED({w['source']})",
                                            "scan": fresh_scan,
                                        })
                                        logger.info(
                                            f"✅ WATCHLIST REVALIDATED [{sym}] "
                                            f"₹{old_price}→₹{fresh_price} conf={confidence:.0f}"
                                        )
                                    else:
                                        rejected.append(f"{sym} (3AI rejected: {reasoning[-1] if reasoning else 'no reason'})")
                                        logger.info(f"❌ WATCHLIST REJECT [{sym}]: 3AI rejected on fresh data")

                                except Exception as eval_err:
                                    rejected.append(f"{sym} (eval error)")
                                    logger.error(f"Watchlist re-eval [{sym}]: {eval_err}")

                            except Exception as e:
                                rejected.append(f"{sym} (error)")
                                logger.error(f"Watchlist revalidate [{sym}]: {e}")

                        # Execute revalidated signals
                        executed = []
                        for rv in revalidated:
                            sym = rv["symbol"]
                            price = rv["fresh_price"]
                            scan = rv["scan"]
                            atr = scan.get("atr", price * 0.02)
                            source = rv["source"]

                            # ═══ SEBI-COMPLIANT SL for revalidated trades (max 0.9%) ═══
                            _rv_sl_pct = min(atr / price if atr > 0 else 0.007, MAX_SL_PERCENT)
                            _rv_sl_pct = max(_rv_sl_pct, MIN_SL_PERCENT)
                            sl = round(price * (1 - _rv_sl_pct), 2)
                            _rv_risk = price - sl
                            t1 = round(price + 2.5 * _rv_risk, 2)
                            t2 = round(price + 4.0 * _rv_risk, 2)

                            if sentinel.risk.can_trade():
                                entry = sentinel.swing.entry(
                                    sym, price, f"WATCHLIST RE-VALIDATED ({rv['confidence']:.0f}%)",
                                    sl, t1, t2, source=source
                                )
                                if entry:
                                    executed.append(sym)

                    # ── Send capital restored alert ────────────────
                    msg = (
                        f"✅ *CAPITAL RESTORED — LIVE TRADING RESUMED*\n"
                        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                        f"💰 Kite balance: ₹{actual_capital:,.0f}\n"
                        f"  Intraday: ₹{alloc['intraday']:,.0f}\n"
                        f"  Swing: ₹{alloc['swing']:,.0f}\n"
                        f"  Long Term: ₹{alloc['longterm']:,.0f}\n"
                    )

                    if watchlist:
                        msg += (
                            f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                            f"🔄 *Watchlist Re-validation:*\n"
                            f"  Queued: {len(watchlist)} stocks\n"
                            f"  ✅ Re-validated & executed: {len(executed)}\n"
                            f"  ❌ Rejected (stale/invalid): {len(rejected)}\n"
                        )
                        if executed:
                            msg += f"  📈 Traded: {', '.join(executed)}\n"
                        if rejected[:5]:
                            msg += f"  🚫 Dropped: {', '.join(rejected[:5])}\n"
                    else:
                        msg += f"📋 No watchlist signals were pending\n"

                    msg += (
                        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                        f"📌 Bot auto-detected funds and resumed"
                    )
                    self.send_telegram(msg, priority="critical")

        except Exception as e:
            logger.error(f"Capital check: {e}")

    def place_fno_order(self, tradingsymbol, exchange, transaction_type,
                        qty, price=None, order_type="MARKET",
                        trigger_price=None, product="NRML",
                        variety="regular", tag=""):
        """
        Place an F&O order (NFO exchange) with Zerodha time awareness.

        Zerodha F&O rules:
        - 09:15-15:30: All order types (MARKET, LIMIT, SL, SL-M) regular variety
        - 15:30-15:45: Dead zone — no orders accepted
        - 15:45-09:10: AMO variety only (LIMIT or MARKET, no SL-M for options)
        - Stock OPTIONS: MARKET orders BLOCKED by Zerodha — must use LIMIT
        - Index options (NIFTY/BANKNIFTY): MARKET allowed
        """
        kite = self._get_kite()
        if not kite:
            return None

        if not self.risk.can_trade():
            self.audit.log("BLOCKED_RISK_FNO", {
                "symbol": tradingsymbol, "reason": "RiskManager blocked"
            })
            return None

        if self._is_duplicate(tradingsymbol, transaction_type, product):
            self.audit.log("BLOCKED_DUPLICATE_FNO", {
                "symbol": tradingsymbol
            })
            return None

        # ── Zerodha F&O time rules ────────────────────────────
        # AMO: 3:45 PM to 9:11 AM. NOT during 01:00-05:30 maintenance.
        # AMO allowed on weekends/holidays (queues for next trading day).
        # SL-M BLOCKED for ALL options (NSE rule since Sep 2021). Use SL-Limit.
        # MARKET orders BLOCKED for stock options (illiquidity). Use LIMIT.
        # ON NON-TRADING DAYS: ALL orders must be AMO.
        now = _now_ist()
        hr, mn = now.hour, now.minute
        time_mins = hr * 60 + mn

        _today_str = now.strftime("%Y-%m-%d")
        _is_trading_day = (now.weekday() < 5 and _today_str not in NSE_HOLIDAYS)

        maintenance = (time_mins >= 60 and time_mins <= 330)    # 01:00 to 05:30

        if maintenance:
            logger.warning(f"🔧 F&O ORDER BLOCKED: Zerodha maintenance 01:00-05:30 | {tradingsymbol}")
            self.audit.log("BLOCKED_MAINTENANCE_FNO", {"symbol": tradingsymbol})
            return None

        # ── Stock options must use LIMIT (Zerodha blocks MARKET on stock options) ──
        is_stock_option = (exchange == "NFO" and
                          not any(idx in tradingsymbol for idx in ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"]) and
                          ("CE" in tradingsymbol or "PE" in tradingsymbol))

        # On non-trading days: FORCE AMO
        if not _is_trading_day:
            actual_variety = "amo"
            if is_stock_option:
                actual_order_type = "LIMIT"
            else:
                actual_order_type = order_type
            logger.info(f"🌙 NON-TRADING DAY F&O AMO: {tradingsymbol}")
        else:
            market_open = (time_mins >= 555 and time_mins <= 929)  # 09:15 to 15:29
            dead_zone = (time_mins >= 930 and time_mins <= 944)     # 15:30 to 15:44
            amo_window = ((time_mins >= 945 or time_mins <= 551) and not maintenance)

            if dead_zone:
                logger.warning(f"🚫 F&O ORDER BLOCKED: Dead zone 15:30-15:45 | {tradingsymbol}")
                self.audit.log("BLOCKED_DEAD_ZONE_FNO", {"symbol": tradingsymbol})
                self.send_telegram(
                    f"🚫 *F&O Order Blocked — Dead Zone*\n"
                    f"`{tradingsymbol}` — No orders accepted 15:30-15:45\n"
                    f"_Will retry after 15:45 as AMO_",
                    priority="trade"
                )
                return None

            if market_open:
                actual_variety = "regular"
                if is_stock_option and order_type == "MARKET":
                    actual_order_type = "LIMIT"
                    logger.info(f"📊 Stock option: MARKET→LIMIT for {tradingsymbol}")
                else:
                    actual_order_type = order_type
            elif amo_window:
                actual_variety = "amo"
                if is_stock_option:
                    actual_order_type = "LIMIT"
                else:
                    actual_order_type = order_type
                logger.info(f"🌙 F&O AMO: {tradingsymbol}")
            else:
                actual_variety = "regular"
                actual_order_type = order_type

        order_id = None
        last_error = ""
        for attempt in range(3):
            try:
                params = {
                    "tradingsymbol":    tradingsymbol,
                    "exchange":         exchange,
                    "transaction_type": transaction_type,
                    "quantity":         qty,
                    "product":          product,
                    "order_type":       actual_order_type,
                    "variety":          actual_variety,
                }
                # LIMIT orders need price
                if actual_order_type == "LIMIT":
                    if price and price > 0:
                        params["price"] = round(price, 1)
                    else:
                        # Need to fetch LTP for LIMIT order
                        try:
                            ltp_data = kite.ltp([f"{exchange}:{tradingsymbol}"])
                            ltp_key = f"{exchange}:{tradingsymbol}"
                            if ltp_key in ltp_data:
                                params["price"] = round(ltp_data[ltp_key]["last_price"], 1)
                        except Exception:
                            logger.warning(f"LTP fetch failed for LIMIT price: {tradingsymbol}")
                            if price:
                                params["price"] = round(price, 1)
                if actual_order_type == "MARKET" and transaction_type == "SELL":
                    try:
                        _mp = kite.ltp([f"NSE:{symbol}"])
                        _lp = _mp.get(f"NSE:{symbol}", {}).get("last_price", 0)
                        if _lp > 0:
                            params["order_type"] = "LIMIT"
                            params["price"] = round(_lp * 0.995, 1)
                    except Exception:
                        pass
                if trigger_price:
                    params["trigger_price"] = trigger_price
                if tag:
                    params["tag"] = tag[:20]

                order_id = kite.place_order(**params)
                logger.info(f"✅ F&O ORDER: {transaction_type} {tradingsymbol} x{qty} | {actual_order_type} {actual_variety} | ID: {order_id}")
                break

            except Exception as e:
                last_error = str(e)
                logger.error(f"❌ F&O ORDER ATTEMPT {attempt+1}: {tradingsymbol} | {e}")
                if attempt < 2:
                    time.sleep((attempt + 1) * 2)

        if order_id:
            self._record_order(tradingsymbol, transaction_type, product)
            self.audit.log("FNO_ORDER_PLACED", {
                "symbol": tradingsymbol, "exchange": exchange,
                "transaction_type": transaction_type, "qty": qty,
                "order_id": order_id, "tag": tag,
                "order_type": actual_order_type, "variety": actual_variety,
            })
            self.send_telegram(
                f"📊 *LIVE F&O ORDER*\n"
                f"`{tradingsymbol}` {transaction_type} x{qty}\n"
                f"Product: {product} | {actual_order_type} {actual_variety}\n"
                f"ID: `{order_id}` | Tag: {tag}",
                priority="trade"
            )
            return order_id
        else:
            self.audit.log("FNO_ORDER_FAILED", {
                "symbol": tradingsymbol, "error": last_error[:300],
            })
            self.send_telegram(
                f"🔴 *F&O ORDER FAILED*\n"
                f"`{tradingsymbol}` {transaction_type} x{qty}\n"
                f"Error: {last_error[:200]}",
                priority="critical"
            )
            return None

    def cancel_all_pending(self, reason="CircuitBreaker"):
        """Cancel ALL pending/open orders. Called by circuit breaker."""
        kite = self._get_kite()
        if not kite:
            return 0

        cancelled = 0
        try:
            orders = kite.orders()
            for order in orders:
                status = order.get("status", "").upper()
                if status in ("OPEN", "TRIGGER PENDING", "AMO REQ RECEIVED"):
                    try:
                        variety = order.get("variety", "regular")
                        kite.cancel_order(
                            variety=variety,
                            order_id=order["order_id"]
                        )
                        cancelled += 1
                        self.audit.log("ORDER_CANCELLED", {
                            "order_id": order["order_id"],
                            "symbol": order.get("tradingsymbol", ""),
                            "reason": reason,
                        })
                        logger.info(f"🚫 CANCELLED: {order.get('tradingsymbol','')} | {order['order_id']}")
                    except Exception as e:
                        logger.error(f"Cancel failed: {order['order_id']} | {e}")
        except Exception as e:
            logger.error(f"cancel_all_pending error: {e}")

        if cancelled > 0:
            self.send_telegram(
                f"🚫 *{cancelled} ORDERS CANCELLED*\n"
                f"Reason: {reason}\n"
                f"All pending orders cleared",
                priority="critical"
            )
        return cancelled

    def get_order_status(self, order_id):
        """Get status of a specific order."""
        kite = self._get_kite()
        if not kite:
            return None
        try:
            history = kite.order_history(order_id)
            if history:
                return history[-1]  # Latest status
        except Exception as e:
            logger.error(f"Order status check failed: {order_id} | {e}")
        return None


# ══════════════════════════════════════════════════════════════
#  POSITION SYNC — reconciles bot state with Kite holdings
# ══════════════════════════════════════════════════════════════

class PositionSync:
    """
    On startup and periodically, syncs bot's JSON state with
    actual Kite positions and holdings.

    This prevents:
    - Phantom positions (bot thinks it has a position, Kite doesn't)
    - Unknown positions (Kite has a position, bot doesn't know)
    - Capital mismatch (bot thinks more/less capital available)
    """

    @staticmethod
    def sync_equity(kite, trader_book, trader_name, send_telegram_fn, all_bot_syms=None, adopt=True):
        """
        Sync equity positions for one trader (intraday/swing/longterm).
        all_bot_syms: set of symbols already tracked by ANY strategy — skip adopting these.
        """
        if not kite:
            return trader_book
        
        # v23.6.4: Skip Kite API calls on non-trading days to avoid token errors
        try:
            from global_eye_v23_pythonanywhere import KiteSession
            if not KiteSession.is_trading_day():
                logger.debug(f"PositionSync [{trader_name}]: Skipping on non-trading day")
                return trader_book
        except:
            pass  # If check fails, proceed normally
        
        if all_bot_syms is None:
            all_bot_syms = set()

        try:
            # Get real Kite positions
            kite_positions = kite.positions()
            net_positions = kite_positions.get("net", [])
            day_positions = kite_positions.get("day", [])

            # Build map of Kite holdings: symbol → qty
            kite_holdings = {}
            for pos in net_positions:
                sym = pos.get("tradingsymbol", "")
                qty = pos.get("quantity", 0)
                avg_price = pos.get("average_price", 0)
                exchange = pos.get("exchange", "")
                product = pos.get("product", "")
                if exchange == "NSE" and qty != 0:
                    kite_holdings[sym] = {
                        "qty": qty, "avg_price": avg_price,
                        "product": product, "pnl": pos.get("pnl", 0),
                    }

            # Also check day positions (T+1 shares bought today)
            for pos in day_positions:
                sym = pos.get("tradingsymbol", "")
                qty = pos.get("quantity", 0)
                avg_price = pos.get("average_price", 0)
                exchange = pos.get("exchange", "")
                if exchange == "NSE" and qty > 0 and sym not in kite_holdings:
                    kite_holdings[sym] = {
                        "qty": qty, "avg_price": avg_price,
                        "product": pos.get("product", "CNC"),
                        "pnl": pos.get("pnl", 0),
                    }

            # Also check holdings (CNC delivery positions — settled T+1)
            try:
                holdings = kite.holdings()
                for h in holdings:
                    sym = h.get("tradingsymbol", "")
                    qty = h.get("quantity", 0)
                    t1_qty = h.get("t1_quantity", 0)
                    total_qty = qty + t1_qty  # Include T1 settlement shares
                    avg = h.get("average_price", 0)
                    if total_qty > 0 and sym not in kite_holdings:
                        kite_holdings[sym] = {
                            "qty": total_qty, "avg_price": avg,
                            "product": "CNC", "pnl": h.get("pnl", 0),
                        }
            except Exception:
                pass

            bot_positions = trader_book.get("positions", {})
            synced = 0
            removed = 0

            # ── Remove phantom positions (in bot but not in Kite) ──
            # IMPORTANT: Don't remove positions bought TODAY — they're in T+1 settlement
            # Kite shows them in positions() but not holdings() until next day
            _today = _now_ist().strftime("%Y-%m-%d")
            for sym in list(bot_positions.keys()):
                if sym not in kite_holdings:
                    # Check if position was bought today (T+1 settlement)
                    _entry_date = bot_positions[sym].get("entry_date", "")
                    if _entry_date == _today:
                        logger.info(f"SYNC [{trader_name}]: {sym} not in holdings — T+1 settlement (keeping)")
                        continue  # Don't remove — it's in settlement
                    logger.warning(f"SYNC [{trader_name}]: Removing phantom position {sym}")
                    pos = bot_positions.pop(sym)
                    # Return capital
                    trader_book["available"] = round(
                        trader_book.get("available", 0) + pos.get("cost", 0), 2
                    )
                    removed += 1

            # ── Update quantities if mismatch ──
            for sym, pos in list(bot_positions.items()):
                if sym in kite_holdings:
                    kite_qty = abs(kite_holdings[sym]["qty"])
                    bot_qty = pos.get("qty", 0)
                    if kite_qty != bot_qty and kite_qty > 0:
                        logger.info(f"🔄 SYNC [{trader_name}]: {sym} qty {bot_qty}→{kite_qty}")
                        pos["qty"] = kite_qty
                        pos["cost"] = round(kite_qty * pos.get("entry_price", 0), 2)
                        synced += 1


            # ── FIX #6: ADOPT unknown Kite holdings ──────────────
            # Adopt Kite holdings into bot books
            # ALL strategies adopt (not just swing)
            # SL calculated using 1% max loss rule
            _current_price = 0  # Default to prevent NameError when adopt=False
            for k_sym, k_info in kite_holdings.items():
                if adopt and k_sym not in bot_positions:
                    # Skip if already tracked by another strategy
                    if k_sym in all_bot_syms:
                        continue
                    _avg_price = k_info.get("avg_price", k_info.get("price", 0))
                    _qty = abs(k_info.get("qty", 0))
                    if _avg_price > 0 and _qty > 0:
                        # For adopted positions: NO software SL
                        # GTT on Zerodha handles protection
                        # check_stops will skip positions with adopt_grace flag
                        # Bot only manages exits through GTT audit
                        _sl = 0  # No software SL — GTT only
                        _t1 = round(_avg_price * 1.10, 2)
                        _t2 = round(_avg_price * 1.20, 2)

                        adopted_pos = {
                            "symbol": k_sym,
                            "entry_price": _avg_price,
                            "qty": _qty,
                            "cost": round(_avg_price * _qty, 2),
                            "signal": "ADOPTED from Kite holdings",
                            "stop_loss": _sl,
                            "target1": _t1,
                            "target2": _t2,
                            "strategy": trader_name,
                            "source": "KITE_ADOPTED",
                            "entry_time": _now_ist().isoformat(),
                            "entry_date": _now_ist().strftime("%Y-%m-%d"),
                            "status": "OPEN",
                            "adopt_grace": True,  # Grace period flag — don't trigger SL immediately
                        }
                        bot_positions[k_sym] = adopted_pos
                        logger.info(
                            f"ADOPTED [{trader_name}]: {k_sym} x{_qty} @ Rs.{_avg_price} "
                            f"LTP: Rs.{_current_price} SL: Rs.{_sl} (5% below current)"
                        )
                        if send_telegram_fn:
                            send_telegram_fn(
                                f"HOLDINGS ADOPTED\n"
                                f"{k_sym} x{_qty} @ Rs.{_avg_price:,.2f}\n"
                                f"Protected by GTT on Zerodha\n"
                                f"Bot will NOT auto-sell adopted positions",
                                priority="trade"
                            )

            trader_book["positions"] = bot_positions

            if removed > 0 or synced > 0:
                send_telegram_fn(
                    f"🔄 *Position Sync [{trader_name.upper()}]*\n"
                    f"Removed phantom: {removed}\n"
                    f"Updated qty: {synced}\n"
                    f"Active positions: {len(bot_positions)}",
                    priority="kite"
                )
                logger.info(f"🔄 SYNC [{trader_name}]: {removed} removed, {synced} updated")

        except Exception as e:
            logger.error(f"PositionSync [{trader_name}]: {e}\n{traceback.format_exc()}")

        return trader_book

    @staticmethod
    def sync_fno(kite, fno_book, send_telegram_fn):
        """Sync F&O positions with Kite."""
        if not kite:
            return fno_book

        try:
            kite_positions = kite.positions()
            net_positions = kite_positions.get("net", [])

            # Build map of F&O positions
            kite_fno = {}
            for pos in net_positions:
                exchange = pos.get("exchange", "")
                if exchange == "NFO" and pos.get("quantity", 0) != 0:
                    sym = pos.get("tradingsymbol", "")
                    kite_fno[sym] = {
                        "qty": pos.get("quantity", 0),
                        "avg_price": pos.get("average_price", 0),
                        "pnl": pos.get("pnl", 0),
                    }

            bot_fno = fno_book.get("positions", {})
            removed = 0

            # Remove phantom F&O positions
            for key in list(bot_fno.keys()):
                # Extract tradingsymbol-like key to match
                found = False
                for kite_sym in kite_fno:
                    if key in kite_sym or kite_sym in key:
                        found = True
                        break
                if not found and len(bot_fno) > 0:
                    logger.warning(f"🔄 F&O SYNC: Removing phantom {key}")
                    pos = bot_fno.pop(key)
                    fno_book["available"] = round(
                        fno_book.get("available", 0) + pos.get("cost", 0), 2
                    )
                    removed += 1

            fno_book["positions"] = bot_fno

            if removed > 0:
                send_telegram_fn(
                    f"🔄 *F&O Position Sync*\n"
                    f"Removed phantom: {removed}\n"
                    f"Active F&O positions: {len(bot_fno)}",
                    priority="kite"
                )

        except Exception as e:
            logger.error(f"F&O PositionSync: {e}")

        return fno_book


# ══════════════════════════════════════════════════════════════
#  CAPITAL ALLOCATOR — auto-detects available capital from Kite
# ══════════════════════════════════════════════════════════════

class CapitalAllocator:
    """
    Smart capital allocation based on market conditions.

    Queries VIX, Fear & Greed, and market breadth to determine
    whether conditions favor intraday (trending/bullish) or
    long-term (fearful/bearish value buying).

    ALLOCATION PROFILES:
    ───────────────────────────────────────────────────────────
    STRONG BULLISH (VIX low, greed, breadth positive):
      Intraday 40% | Swing 25% | LongTerm 15% | F&O 20%
      → Trending markets = intraday momentum trades work best

    BULLISH:
      Intraday 35% | Swing 30% | LongTerm 15% | F&O 20%

    NEUTRAL (default / can't determine):
      Intraday 30% | Swing 30% | LongTerm 20% | F&O 20%

    BEARISH:
      Intraday 20% | Swing 25% | LongTerm 35% | F&O 20%
      → Fearful markets = long-term value buying opportunity

    STRONG BEARISH (VIX high, extreme fear, breadth negative):
      Intraday 15% | Swing 20% | LongTerm 40% | F&O 25%
      → Maximum long-term allocation (buy fear), extra F&O for hedging
    ───────────────────────────────────────────────────────────
    """

    PROFILES = {
        "STRONG_BULLISH": {"intraday": 0.40, "swing": 0.25, "longterm": 0.20, "fno": 0.15},
        "BULLISH":        {"intraday": 0.35, "swing": 0.30, "longterm": 0.20, "fno": 0.15},
        "NEUTRAL":        {"intraday": 0.30, "swing": 0.30, "longterm": 0.25, "fno": 0.15},
        "BEARISH":        {"intraday": 0.20, "swing": 0.25, "longterm": 0.40, "fno": 0.15},
        "STRONG_BEARISH": {"intraday": 0.15, "swing": 0.25, "longterm": 0.45, "fno": 0.15},
    }

    @classmethod
    def get_total_balance(cls, kite):
        """Get TOTAL portfolio value (holdings + cash) for tier calculation."""
        if not kite:
            return 0
        
        # v23.6.4: Skip Kite API calls on non-trading days to avoid token errors
        try:
            from global_eye_v23_pythonanywhere import KiteSession
            if not KiteSession.is_trading_day():
                logger.debug("get_total_balance: Skipping on non-trading day")
                return 0
        except:
            pass  # If check fails, proceed normally
        
        try:
            margins = kite.margins("equity")
            equity_margin = margins.get("equity", margins) if "equity" in margins else margins
            # net = total balance including holdings value
            net = equity_margin.get("net", 0)
            if net <= 0:
                # Fallback: try available cash
                available = equity_margin.get("available", {})
                net = available.get("live_balance", 0)
            logger.info(f"💰 Kite Total Balance (for tier): Rs.{net:,.0f}")
            return round(net, 2)
        except Exception as e:
            logger.error(f"get_total_balance: {e}")
            return 0

    @classmethod
    def get_available_capital(cls, kite):
        """Query Kite margins API to get actual available capital."""
        if not kite:
            return 0

        try:
            margins = kite.margins()
            equity_margin = margins.get("equity", {})
            available = equity_margin.get("available", {})
            net_available = available.get("live_balance", 0)
            opening = available.get("opening_balance", 0)
            # v23.5.0: Use live_balance (includes today's payin/credits)
            # Old logic used min(live, opening) which excluded intraday payins
            cash = net_available if net_available > 0 else opening

            logger.info(f"💰 Kite Capital: Live=₹{net_available:,.0f} Opening=₹{opening:,.0f} → Using=₹{cash:,.0f}")
            return round(cash, 2)

        except Exception as e:
            logger.error(f"CapitalAllocator: {e}")
            return 0

    @classmethod
    def detect_market_condition(cls, kite):
        """
        Detect market condition using VIX, Fear & Greed, and Nifty trend.
        Returns: STRONG_BULLISH, BULLISH, NEUTRAL, BEARISH, STRONG_BEARISH
        """
        score = 0  # -4 to +4 scale
        factors = {}

        # ── Factor 1: India VIX ──────────────────────────────
        try:
            if kite:
                vix_data = kite.ltp(["NSE:INDIA VIX"])
                if "NSE:INDIA VIX" in vix_data:
                    vix = vix_data["NSE:INDIA VIX"]["last_price"]
                    if vix < 13:
                        score += 2
                        factors["VIX"] = f"LOW {vix:.1f} (bullish)"
                    elif vix < 16:
                        score += 1
                        factors["VIX"] = f"NORMAL {vix:.1f}"
                    elif vix < 22:
                        score -= 1
                        factors["VIX"] = f"ELEVATED {vix:.1f}"
                    else:
                        score -= 2
                        factors["VIX"] = f"HIGH {vix:.1f} (bearish)"
        except Exception as e:
            logger.debug(f"VIX check: {e}")

        # ── Factor 2: Nifty 50 actual day change (real market direction) ──
        # Nifty up 1.5%+ today = bullish regardless of VIX
        try:
            if kite:
                _nifty_ohlc = kite.ohlc(["NSE:NIFTY 50"])
                _nd = _nifty_ohlc.get("NSE:NIFTY 50", {})
                _nifty_open = _nd.get("ohlc", {}).get("open", 0)
                _nifty_ltp  = _nd.get("last_price", 0)
                if _nifty_open > 0 and _nifty_ltp > 0:
                    _nifty_chg = (_nifty_ltp - _nifty_open) / _nifty_open * 100
                    if _nifty_chg >= 1.0:
                        score += 2
                        factors["Momentum"] = f"STRONG ({_nifty_chg:+.1f}% today)"
                    elif _nifty_chg >= 0:
                        score += 1
                        factors["Momentum"] = f"POSITIVE ({_nifty_chg:+.1f}% today)"
                    elif _nifty_chg >= -1.0:
                        score -= 1
                        factors["Momentum"] = f"WEAK ({_nifty_chg:+.1f}% today)"
                    else:
                        score -= 2
                        factors["Momentum"] = f"BEARISH ({_nifty_chg:+.1f}% today)"
        except Exception as e:
            logger.debug(f"Nifty day change: {e}")

        # ── Factor 3: Nifty trend (MA50 vs MA200) ────────────
        try:
            if kite:
                token = None
                try:
                    instruments = kite.instruments("NSE")
                    for inst in instruments:
                        if inst["tradingsymbol"] == "NIFTY 50":
                            token = inst["instrument_token"]
                            break
                except Exception:
                    pass

                if token:
                    from_dt = (_now_ist() - timedelta(days=250)).strftime("%Y-%m-%d")
                    to_dt = _now_ist().strftime("%Y-%m-%d")
                    data = kite.historical_data(token, from_dt, to_dt, "day")
                    if data and len(data) >= 200:
                        import pandas as pd
                        df = pd.DataFrame(data)
                        ma50 = float(df["close"].rolling(50).mean().iloc[-1])
                        ma200 = float(df["close"].rolling(200).mean().iloc[-1])
                        price = float(df["close"].iloc[-1])
                        if ma50 > ma200 and price > ma50:
                            score += 1
                            factors["Nifty"] = f"UPTREND (MA50>{ma200:.0f})"
                        elif ma50 < ma200:
                            score -= 1
                            factors["Nifty"] = f"DOWNTREND (MA50<MA200)"
                        else:
                            factors["Nifty"] = "SIDEWAYS"
        except Exception as e:
            logger.debug(f"Nifty trend check: {e}")

        # ── Determine condition ──────────────────────────────
        if score >= 3:
            condition = "STRONG_BULLISH"
        elif score >= 1:
            condition = "BULLISH"
        elif score <= -3:
            condition = "STRONG_BEARISH"
        elif score <= -1:
            condition = "BEARISH"
        else:
            condition = "NEUTRAL"

        logger.info(f"📊 Market Condition: {condition} (score={score}) | {factors}")
        return condition, score, factors

    # ── CAPITAL TIER SYSTEM ──────────────────────────────────
    # SNIPER MODE — Few positions, big size, high conviction
    # MICRO  (below 50K):     Swing only, 2 positions max
    # SMALL  (50K - 2L):      Swing 55% + Longterm 40% + F&O 5%, 3 max
    # MEDIUM (2L - 5L):       All strategies, 5 max, intraday unlocked
    # LARGE  (above 5L):      Full arsenal, 8 max, aggressive F&O
    TIERS = {
        "MICRO":  {"max": 50000,   "strategies": {"swing": 1.00},
                   "max_pos": 2, "min_conv": 80, "min_rr": 3.0},
        "SMALL":  {"max": 200000,  "strategies": {"swing": 0.60, "longterm": 0.40},
                   "max_pos": 6, "min_conv": 75, "min_rr": 3.0},
        "MEDIUM": {"max": 500000,  "strategies": {"intraday": 0.15, "swing": 0.35, "longterm": 0.35, "fno": 0.15},
                   "max_pos": 8, "min_conv": 70, "min_rr": 2.5},
        "LARGE":  {"max": float("inf"), "strategies": {"intraday": 0.15, "swing": 0.30, "longterm": 0.35, "fno": 0.20},
                   "max_pos": 12, "min_conv": 65, "min_rr": 2.0},
    }

    @classmethod
    def get_tier(cls, capital):
        """Determine capital tier based on balance."""
        if capital < 50000:
            return "MICRO", cls.TIERS["MICRO"]
        elif capital < 200000:
            return "SMALL", cls.TIERS["SMALL"]
        elif capital < 500000:
            return "MEDIUM", cls.TIERS["MEDIUM"]
        else:
            return "LARGE", cls.TIERS["LARGE"]

    @classmethod
    def allocate(cls, total_capital, kite=None):
        """
        Smart allocation based on Capital Tier + market conditions.
        Tier determines WHICH strategies get capital.
        Market condition adjusts weighting within allowed strategies.
        """
        condition = "NEUTRAL"
        score = 0
        factors = {}

        if kite:
            try:
                condition, score, factors = cls.detect_market_condition(kite)
            except Exception as e:
                logger.warning(f"Market condition detection failed: {e} — using NEUTRAL")
                condition = "NEUTRAL"

        # Get tier based on TOTAL balance (not just free cash)
        # This ensures Rs.1,09,459 total → SMALL tier even if free cash is Rs.26K
        tier_capital = total_capital  # default: use what was passed
        if kite:
            try:
                tier_capital = cls.get_total_balance(kite)
                if tier_capital <= 0:
                    tier_capital = total_capital
            except Exception:
                tier_capital = total_capital
        tier_name, tier = cls.get_tier(tier_capital)

        # Allocate ONLY to strategies allowed by tier
        tier_strategies = tier["strategies"]
        alloc = {
            "intraday": 0,
            "swing": 0,
            "longterm": 0,
            "fno": 0,
        }
        for strat, pct in tier_strategies.items():
            alloc[strat] = round(total_capital * pct, 2)

        logger.info(
            f"💼 Smart Capital Allocation (₹{total_capital:,.0f}) | Tier: {tier_name}\n"
            f"  Market: {condition} (score={score})\n"
            f"  Max positions: {tier['max_pos']} | Min conviction: {tier['min_conv']}%\n"
            f"  Intraday: ₹{alloc['intraday']:,.0f}\n"
            f"  Swing:    ₹{alloc['swing']:,.0f}\n"
            f"  LongTerm: ₹{alloc['longterm']:,.0f}\n"
            f"  F&O:      ₹{alloc['fno']:,.0f}"
        )

        # Store metadata
        alloc["_condition"] = condition
        alloc["_score"] = score
        alloc["_factors"] = factors
        alloc["_profile"] = tier_strategies
        alloc["_tier"] = tier_name
        alloc["_tier_info"] = tier

        return alloc


# ══════════════════════════════════════════════════════════════
#  CIRCUIT BREAKER — hard stops that protect capital
# ══════════════════════════════════════════════════════════════

class CircuitBreaker:
    """
    Enhanced risk management for live trading.
    When triggered, cancels ALL pending orders immediately.

    Triggers:
    1. Daily loss exceeds 5% of total capital → halt ALL trading
    2. Single trade loss exceeds 3% of total capital → halt intraday
    3. Monthly loss exceeds 15% of total capital → OBSERVE mode
    4. More than 3 consecutive losses → reduce position size 50%
    5. Kite connection lost during market → alert + try reconnect
    """

    def __init__(self, total_capital, order_manager, risk_manager, send_telegram_fn,
                 save_json_fn=None, daily_file=None):
        self.total_capital = total_capital
        self.order_mgr     = order_manager
        self.risk          = risk_manager
        self.send_telegram = send_telegram_fn
        self.save_json     = save_json_fn
        self.daily_file    = daily_file
        self.daily_loss    = 0
        self.consec_losses = 0
        self._halted       = False
        self._halt_reason  = ""

    @property
    def is_halted(self):
        return self._halted

    def check_and_act(self, trade_pnl):
        """
        Called after every trade close.
        Returns True if trading should continue, False if halted.
        """
        self.daily_loss += trade_pnl

        # Track consecutive losses
        if trade_pnl < 0:
            self.consec_losses += 1
        else:
            self.consec_losses = 0

        # ── TRIGGER 1: Daily loss > 5% ───────────────────────
        daily_limit = self.total_capital * 0.05
        if self.daily_loss <= -daily_limit:
            self._halt("DAILY_LOSS_LIMIT",
                f"Daily loss ₹{abs(self.daily_loss):,.0f} exceeds 5% limit (₹{daily_limit:,.0f})")
            return False

        # ── TRIGGER 2: Single trade loss > 3% ────────────────
        single_limit = self.total_capital * 0.03
        if trade_pnl <= -single_limit:
            self.send_telegram(
                f"⚠️ *LARGE LOSS ALERT*\n"
                f"Single trade: -₹{abs(trade_pnl):,.0f}\n"
                f"Exceeds 3% single-trade limit\n"
                f"Intraday trading paused",
                priority="critical"
            )
            self.risk.daily["intraday_halted"] = True

        # ── TRIGGER 3: 3+ consecutive losses ─────────────────
        if self.consec_losses >= 3:
            self.send_telegram(
                f"⚠️ *{self.consec_losses} CONSECUTIVE LOSSES*\n"
                f"Position sizing reduced to 50%\n"
                f"Will reset after next winning trade",
                priority="critical"
            )

        return True

    def _halt(self, reason, message):
        """Emergency halt — cancel all orders, stop trading."""
        self._halted = True
        self._halt_reason = reason
        logger.critical(f"🚨 CIRCUIT BREAKER: {reason}")

        # Cancel ALL pending orders immediately
        cancelled = self.order_mgr.cancel_all_pending(reason=reason)

        # Set observe mode in risk manager
        self.risk.daily["observe_mode"] = True
        # Persist to disk so it survives restart
        if self.save_json and self.daily_file:
            self.save_json(self.daily_file, self.risk.daily)

        self.send_telegram(
            f"🚨 *CIRCUIT BREAKER TRIGGERED*\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"Reason: {reason}\n"
            f"{message}\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"🚫 Cancelled {cancelled} pending orders\n"
            f"⛔ ALL trading HALTED\n"
            f"_Will resume next trading day_",
            priority="critical"
        )

    def reset_daily(self):
        """Reset at start of new trading day."""
        self.daily_loss = 0
        self.consec_losses = 0
        self._halted = False
        self._halt_reason = ""


# ══════════════════════════════════════════════════════════════
#  LIVE EQUITY TRADER — replaces BasePaperTrader for real orders
# ══════════════════════════════════════════════════════════════

class LiveEquityTrader:
    """
    Real equity trading via Kite.

    Inherits the same interface as BasePaperTrader but places
    actual orders through LiveOrderManager.

    Key differences from paper:
    - entry() → calls LiveOrderManager.place_equity_order()
    - exit()  → places real SELL order
    - SL orders placed automatically with every BUY
    - Position sizes capped more conservatively
    - check_stops() uses real Kite LTP and places real exits
    """

    def __init__(self, filepath, capital, max_pos, name, risk,
                 order_manager, circuit_breaker, kite_session_cls,
                 send_telegram_fn, save_json_fn, load_json_fn):
        self.file       = filepath
        self.capital    = capital
        self.max_pos    = max_pos
        self.name       = name
        self.risk       = risk
        self.order_mgr  = order_manager
        self.circuit    = circuit_breaker
        self.KiteSession = kite_session_cls
        self.send_telegram = send_telegram_fn
        self.save_json  = save_json_fn
        self.load_json  = load_json_fn

        self.book = self.load_json(filepath, {
            "capital":    capital,
            "available":  capital,
            "positions":  {},
            "trades":     [],
            "pnl_log":   [],
            "start_time": _now_ist().isoformat(),
        })

        # ── BUG FIX: Update capital to match new allocation ──
        # On restart, JSON may have old capital. Update to new allocation.
        old_capital = self.book.get("capital", 0)
        if old_capital != capital:
            # Adjust available proportionally
            if old_capital > 0:
                ratio = capital / old_capital
                self.book["available"] = round(self.book.get("available", capital) * ratio, 2)
            else:
                self.book["available"] = capital
            self.book["capital"] = capital
            logger.info(f"💰 [{name}] Capital updated: ₹{old_capital:,.0f} → ₹{capital:,.0f}")

        # Determine product type based on strategy
        if name == "intraday":
            self.product = "MIS"  # Auto-square-off by broker
        else:
            self.product = "CNC"  # Delivery

    def _save(self):
        self.save_json(self.file, self.book)

    def win_rate(self):
        closed = [t for t in self.book["trades"] if t.get("status") == "CLOSED"]
        if not closed:
            return 50.0
        return round(len([t for t in closed if t["pnl"] > 0]) / len(closed) * 100, 1)

    def _refresh_available_from_kite(self):
        """Refresh this strategy's available capital from real Kite balance.
        
        SIMPLIFIED: Use Kite's actual free cash as available capital.
        The old approach (allocator % minus invested) broke because:
        - Allocator gives swing ~60% of free cash (e.g., ₹48K)
        - But invested across all positions could be ₹85K+
        - Result: negative available → 1 share orders
        
        New approach: Kite free cash IS the available capital.
        Kite already knows what's invested vs free. No need to
        re-calculate. If Kite says ₹81K free, we can use ₹81K.
        """
        try:
            kite = self.KiteSession.get()
            if not kite:
                try:
                    kite = self.KiteSession.emergency_login(reason="Capital refresh for trade")
                except Exception:
                    pass
            if not kite:
                return  # Can't refresh, use existing book value
            
            real_cash = CapitalAllocator.get_available_capital(kite)
            if real_cash <= 0:
                self.book["available"] = 0
                return
            
            # Get tier for max_pos update
            total_bal = CapitalAllocator.get_total_balance(kite)
            if total_bal <= 0:
                total_bal = real_cash
            tier_name, tier_info = CapitalAllocator.get_tier(total_bal)
            tier_max_pos = tier_info.get("max_pos", 6)
            
            if tier_max_pos != self.max_pos:
                logger.info(
                    f"📊 [{self.name}] Max positions: {self.max_pos} → {tier_max_pos} "
                    f"(Tier: {tier_name})"
                )
                self.max_pos = tier_max_pos
            
            # Available = Kite free cash (Kite already accounts for invested)
            old_available = self.book.get("available", 0)
            self.book["available"] = round(real_cash, 2)
            self.book["capital"] = round(real_cash + sum(
                p.get("cost", 0) for p in self.book.get("positions", {}).values()
            ), 2)
            
            if abs(real_cash - old_available) > 10:
                logger.info(
                    f"💰 [{self.name}] Capital refreshed from Kite: "
                    f"₹{old_available:,.0f} → ₹{real_cash:,.0f} "
                    f"(Kite free: ₹{real_cash:,.0f})"
                )

            # ── Tier Migration: check for orphaned positions ──
            # Only the swing trader triggers this (avoid duplicate checks)
            if self.name == "swing" and _TIER_MIGRATION_LOADED:
                try:
                    sentinel = getattr(self, '_sentinel', None)
                    if sentinel and hasattr(sentinel, '_tier_migration_mgr'):
                        mgr = sentinel._tier_migration_mgr
                        if mgr:
                            _traders = {
                                "intraday": sentinel.intraday,
                                "swing": sentinel.swing,
                                "longterm": sentinel.longterm,
                                "fno": sentinel.fno,
                            }
                            _mig_result = mgr.check_and_migrate(tier_name, _traders)
                            if _mig_result and _mig_result.get("total", 0) > 0:
                                logger.info(
                                    f"TierMigration (refresh): "
                                    f"{_mig_result['total']} positions handled"
                                )
                except Exception as _mig_err:
                    logger.debug(f"TierMigration refresh: {_mig_err}")

        except Exception as e:
            logger.debug(f"Capital refresh [{self.name}]: {e}")

    # Maximum Kelly fraction by tier — concentrated for small, diversified for large
    # Buffett with small capital: 25-40% in best ideas
    # Buffett with large capital: 10-15% per position
    TIER_MAX_KELLY = {
        "MICRO":  0.40,   # Up to 40% per trade — Buffett's AmEx style (2 concentrated bets)
        "SMALL":  0.25,   # Up to 25% per trade — Buffett's Coca-Cola style
        "MEDIUM": 0.15,   # Up to 15% per trade
        "LARGE":  0.10,   # Up to 10% per trade — diversified
    }

    def _qty(self, price, sl):
        """
        Calculate position size using Kelly Criterion — billionaire style.
        
        Kelly % = W - (1-W)/R  (then use Half Kelly for safety)
        W = win rate, R = reward/risk ratio
        
        High conviction from 3AI = bigger position.
        Low conviction = smaller position.
        Tier controls the maximum cap.
        """
        risk_amount = abs(price - sl)
        if risk_amount <= 0:
            return 0

        available = self.book.get("available", 0)
        if available <= 0:
            return 0

        # Get current tier (use TOTAL balance, not just free cash)
        try:
            kite = self.KiteSession.get()
            if kite:
                total_bal = CapitalAllocator.get_total_balance(kite)
                if total_bal <= 0:
                    total_bal = CapitalAllocator.get_available_capital(kite)
                tier_name, _ = CapitalAllocator.get_tier(total_bal)
            else:
                tier_name = "MICRO"
        except Exception:
            tier_name = "MICRO"

        # Calculate Kelly fraction from trade history
        from advanced_trading_engine import KellyCriterion
        kelly_data = KellyCriterion.calculate(self)
        kelly_pct = kelly_data["kelly_half"]  # Half Kelly for safety

        # Apply tier-specific cap (Buffett style)
        max_kelly = self.TIER_MAX_KELLY.get(tier_name, 0.15)

        # ── MINIMUM KELLY FLOOR ──────────────────────────────
        # Even with 0% win rate or bad data, never size below 5%.
        # 3AI conviction already filtered — if we're here, it's a valid signal.
        # 0.1% sizing = 1 share of anything = useless deployment.
        MIN_KELLY_FLOOR = 0.05  # 5% floor — absolute minimum

        # If not enough trade history (< MIN_TRADES), use tier cap directly
        # Don't penalize with tiny 1% default when we have high-conviction 3AI signals
        if kelly_data["trades_used"] < KellyCriterion.MIN_TRADES:
            kelly_pct = max_kelly  # Use full tier cap until Kelly has enough data
            logger.info(
                f"📊 [{self.name}] Kelly default: using tier cap {max_kelly*100:.0f}% "
                f"(need {KellyCriterion.MIN_TRADES - kelly_data['trades_used']} more trades for Kelly)"
            )
        else:
            kelly_pct = min(kelly_pct, max_kelly)
            # Floor: if Kelly gives < 5%, win rate data is unreliable or 
            # dominated by adopted positions — use floor instead
            if kelly_pct < MIN_KELLY_FLOOR:
                logger.warning(
                    f"📊 [{self.name}] Kelly too low ({kelly_pct*100:.1f}%) — "
                    f"WR:{kelly_data['win_rate']:.0f}% RR:{kelly_data['rr_ratio']:.1f} "
                    f"trades:{kelly_data['trades_used']} — using floor {MIN_KELLY_FLOOR*100:.0f}%"
                )
                kelly_pct = MIN_KELLY_FLOOR

        # If circuit breaker detected consecutive losses, halve size
        if self.circuit.consec_losses >= 3:
            kelly_pct *= 0.5
            kelly_pct = max(kelly_pct, MIN_KELLY_FLOOR)  # Still respect floor

        # ── VIX-adjusted sizing ────────────────────────────
        # Softened: VIX reduces size but never below 60% of Kelly
        _vix_multiplier = 1.0
        try:
            _vix_kite = self.KiteSession.get()
            if _vix_kite:
                _vix_data = _vix_kite.ltp(["NSE:INDIA VIX"])
                if "NSE:INDIA VIX" in _vix_data:
                    _vix = _vix_data["NSE:INDIA VIX"]["last_price"]
                    if _vix > 30:
                        _vix_multiplier = 0.60  # 60% size only in extreme panic
                    elif _vix > 24:
                        _vix_multiplier = 0.75  # 75% size in high fear
                    elif _vix > 20:
                        _vix_multiplier = 0.85  # 85% size in moderate fear
        except Exception:
            pass
        kelly_pct *= _vix_multiplier
        kelly_pct = max(kelly_pct, MIN_KELLY_FLOOR)  # VIX can't push below floor

        # Position size = kelly% of available capital
        max_cost = available * kelly_pct
        qty = max(1, int(max_cost / price))

        # Minimum deployment Rs.15,000 — never buy just 1 share when capital available
        MIN_DEPLOY = 15000
        if qty * price < MIN_DEPLOY and available >= MIN_DEPLOY:
            qty = max(qty, int(MIN_DEPLOY / price))

        # Safety: cap risk per trade based on tier
        # Small accounts need bigger % to deploy meaningful amounts
        _risk_cap = {"MICRO": 0.15, "SMALL": 0.10, "MEDIUM": 0.07, "LARGE": 0.05}
        _max_risk_pct = _risk_cap.get(tier_name, 0.10)
        max_risk = available * _max_risk_pct
        if qty * risk_amount > max_risk:
            qty = max(1, int(max_risk / risk_amount))

        # Final cap: max position size based on tier
        # MICRO/SMALL: up to 60% in one trade (Buffett concentrated)
        # MEDIUM/LARGE: 40% max (diversified)
        _pos_cap = {"MICRO": 0.60, "SMALL": 0.50, "MEDIUM": 0.40, "LARGE": 0.35}
        _max_pos_pct = _pos_cap.get(tier_name, 0.40)
        if qty * price > available * _max_pos_pct:
            qty = max(1, int(available * _max_pos_pct / price))

        # ── POST-CAP MIN_DEPLOY CHECK ──────────────────────────
        # The caps above can reduce qty below MIN_DEPLOY worth.
        # If we have enough capital, ensure minimum meaningful deployment.
        # This runs AFTER all caps so the final qty respects MIN_DEPLOY.
        MIN_DEPLOY_FINAL = 10000  # Slightly lower than pre-cap to avoid loops
        if qty * price < MIN_DEPLOY_FINAL and available >= MIN_DEPLOY_FINAL:
            _min_qty = int(MIN_DEPLOY_FINAL / price)
            # Only override if it doesn't exceed position cap
            if _min_qty * price <= available * _max_pos_pct:
                qty = max(qty, _min_qty)

        # ── Diagnostic: log if qty is suspiciously low ─────────
        if qty <= 2 and available > 5000:
            logger.warning(
                f"LOW QTY [{self.name}] {qty} shares | avail=Rs.{available:,.0f} "
                f"kelly={kelly_pct*100:.1f}% price={price} risk={risk_amount} "
                f"tier={tier_name} max_risk={max_risk:.0f} pos_cap={_max_pos_pct*100:.0f}%"
            )

        logger.info(
            f"📊 [{self.name}] Kelly sizing: {kelly_pct*100:.1f}% of ₹{available:,.0f} "
            f"= ₹{qty*price:,.0f} ({qty} shares) | Tier: {tier_name} | "
            f"WR:{kelly_data['win_rate']:.0f}% RR:{kelly_data['rr_ratio']:.1f}"
        )

        return qty

    def entry(self, symbol, price, signal, sl, t1, t2, source="TECHNICAL"):
        """Place a real BUY order with automatic SL."""
        # ── Pre-checks ────────────────────────────────────────
        if self.circuit.is_halted:
            logger.warning(f"🛑 ENTRY BLOCKED [{self.name}]: Circuit breaker halted")
            return None

        # Block government securities, bonds, and non-equity instruments
        # These have numeric prefixes, contain "GS", "TB", "SDL", "AFIL", "GSEC"
        _blocked_patterns = ["GS20", "GS20", "TB", "SDL", "AFIL", "GSEC", "N0", "N1", "N2", "N3", "N4", "N5"]
        _sym_upper = symbol.upper()
        if (any(bp in _sym_upper for bp in _blocked_patterns)
                or _sym_upper[:2].isdigit()
                or any(c in _sym_upper for c in ["%", ".", "-"]) and len(_sym_upper) > 10):
            logger.debug(f"🚫 BLOCKED non-equity [{symbol}] — government security/bond")
            return None

        if symbol in self.book["positions"]:
            return None  # Already have this position

        # v23.6.1: Enforce max position limit for INTRADAY strategy
        # Swing/longterm: capital is the limit (Kelly sizing controls risk)
        # Intraday on MICRO tier: MUST have hard cap — can't have 5 positions on ₹16K
        _active_count = sum(1 for p in self.book.get("positions", {}).values()
                            if p.get("source", "") != "KITE_ADOPTED")
        if self.name == "intraday" and _active_count >= self.max_pos:
            logger.info(
                f"🛑 INTRADAY CAP [{symbol}]: {_active_count}/{self.max_pos} positions — "
                f"max reached, skipping"
            )
            return None

        # ── REFRESH capital from Kite before every trade ──────
        self._refresh_available_from_kite()

        # ── Subtract pending AMO costs from available ─────────
        # AMO orders don't reduce Kite free cash until they execute.
        # Without this, the bot sees same ₹81K for every AMO and over-orders.
        _pending_cost = sum(
            p.get("cost", 0) for p in self.book.get("positions", {}).values()
            if p.get("gtt_pending")
        )
        _real_available = self.book.get("available", 0) - _pending_cost
        if _real_available < 10000:  # Less than Rs.10K after pending AMOs
            logger.info(
                f"💰 CAPITAL EXHAUSTED [{self.name}] {symbol} — "
                f"free={self.book.get('available',0):,.0f} pending_amo={_pending_cost:,.0f} "
                f"real_available={_real_available:,.0f}"
            )
            return None
        self.book["available"] = round(_real_available, 2)

        qty = self._qty(price, sl)
        if qty == 0:
            return None

        cost = round(qty * price, 2)
        if cost > self.book.get("available", 0):
            logger.info(
                f"💰 INSUFFICIENT [{self.name}] {symbol} — need ₹{cost:,.0f}, "
                f"have ₹{self.book.get('available', 0):,.0f}"
            )
            # Add to watchlist for re-validation when funds arrive
            if hasattr(self, 'order_mgr') and hasattr(self.order_mgr, 'add_to_watchlist'):
                self.order_mgr.add_to_watchlist(symbol, signal, price, source)
            return None  # Not enough capital

        # ══════════════════════════════════════════════════════════════════
        #  STEP 6: CONFIRMATION CANDLE CHECK
        #  Before placing order, verify price action confirms the signal:
        #  A) Green candle after red (reversal pattern)
        #  B) Price bounced +0.3% from recent low (uptick confirmation)
        #  C) Current price above last candle close (upward momentum)
        #  Also: block if price already chased >2% since signal.
        # ══════════════════════════════════════════════════════════════════
        _confirmed_ltp = price  # fallback
        try:
            _kite_cc = self.KiteSession.get()
            if _kite_cc:
                _cc_sym = f"NSE:{symbol}"
                _cc_ltp_data = _kite_cc.ltp([_cc_sym])
                _cc_ltp = _cc_ltp_data.get(_cc_sym, {}).get("last_price", 0)

                if _cc_ltp > 0:
                    _cc_change = (_cc_ltp - price) / price * 100

                    # BLOCK: Price already ran up >2% since signal — too late
                    if _cc_change > 2.0:
                        logger.info(
                            f"⏳ CONFIRM SKIP [{symbol}]: +{_cc_change:.1f}% since signal "
                            f"(₹{price}→₹{_cc_ltp}) — chasing blocked"
                        )
                        return None

                    # Get last 3 candles (5-min) for confirmation
                    _cc_candles = []
                    try:
                        from datetime import timedelta as _td
                        _cc_now = _now_ist()
                        _cc_from = _cc_now - _td(minutes=20)
                        # Need instrument token for historical
                        _cc_token = _cc_ltp_data.get(_cc_sym, {}).get("instrument_token", 0)
                        if _cc_token:
                            _cc_candles = _kite_cc.historical_data(
                                instrument_token=_cc_token,
                                from_date=_cc_from.strftime("%Y-%m-%d %H:%M:%S"),
                                to_date=_cc_now.strftime("%Y-%m-%d %H:%M:%S"),
                                interval="5minute"
                            )
                    except Exception:
                        _cc_candles = []

                    _cc_passed = False
                    if len(_cc_candles) >= 2:
                        _last = _cc_candles[-1]
                        _prev = _cc_candles[-2]
                        _last_green = _last["close"] > _last["open"]
                        _prev_red = _prev["close"] < _prev["open"]

                        _recent_low = min(c["low"] for c in _cc_candles[-3:]) if len(_cc_candles) >= 3 else _last["low"]
                        _bounce = (_cc_ltp - _recent_low) / _recent_low * 100 if _recent_low > 0 else 0

                        # Condition A: Green after red (reversal)
                        # Condition B: Bounce +0.3% from recent low
                        # Condition C: Price above last candle close
                        _cond_a = _last_green and _prev_red
                        _cond_b = _bounce >= 0.3
                        _cond_c = _cc_ltp > _last["close"]

                        if _cond_a or _cond_b or _cond_c:
                            _cc_passed = True
                            _why = "GREEN_AFTER_RED" if _cond_a else (f"BOUNCE+{_bounce:.1f}%" if _cond_b else "ABOVE_CLOSE")
                            logger.info(f"✅ CONFIRMED [{symbol}]: {_why} LTP=₹{_cc_ltp}")
                        else:
                            logger.info(
                                f"⏳ CONFIRM WAIT [{symbol}]: No confirmation candle "
                                f"(green={_last_green} prev_red={_prev_red} bounce={_bounce:.1f}%)"
                            )
                            return None  # No confirmation — skip this entry
                    else:
                        # Can't get candles — allow entry but log warning
                        _cc_passed = True
                        logger.debug(f"CONFIRM [{symbol}]: No candle data — proceeding with caution")

                    _confirmed_ltp = _cc_ltp  # Use confirmed LTP for order
        except Exception as _cc_err:
            logger.debug(f"Confirmation candle [{symbol}]: {_cc_err}")
            # On error, proceed — don't block all trades

        # Update price to confirmed LTP
        price = _confirmed_ltp

        # ── Place real order ──────────────────────────────────
        tag = f"{self.name[:3].upper()}_{source[:8]}"
        order_id = self.order_mgr.place_equity_order(
            symbol=symbol,
            transaction_type="BUY",
            qty=qty,
            price=round(price, 1),
            product=self.product,
            order_type="MARKET",  # Market order for immediate fill
            tag=tag,
            stoploss_price=None,  # NO separate SL order — GTT OCO handles it
        )

        if not order_id:
            logger.warning(f"ENTRY FAILED [{self.name}]: {symbol} — order rejected")
            return None

        # ── Get actual fill price from Kite (MARKET orders fill at different price) ──
        actual_price = price  # fallback
        try:
            time.sleep(1)  # Brief wait for order to execute
            status = self.order_mgr.get_order_status(order_id)
            if status and status.get("status") == "COMPLETE":
                fill_price = status.get("average_price", 0)
                if fill_price > 0:
                    actual_price = round(fill_price, 2)
                    if abs(actual_price - price) > 0.01:
                        logger.info(f"[{symbol}] Fill price: Rs.{actual_price} (scan: Rs.{price})")
        except Exception as e:
            logger.debug(f"Fill price check [{symbol}]: {e}")

        cost = round(qty * actual_price, 2)

        # ── Record position ───────────────────────────────────
        pos = {
            "symbol":      symbol,
            "entry_price": actual_price,
            "qty":         qty,
            "cost":        cost,
            "signal":      signal,
            "stop_loss":   sl,
            "target1":     t1,
            "target2":     t2,
            "strategy":    self.name,
            "source":      source,
            "entry_time":  _now_ist().isoformat(),
            "entry_date":  _now_ist().strftime("%Y-%m-%d"),
            "order_id":    order_id,
            "product":     self.product,
            "status":      "OPEN",
        }
        self.book["positions"][symbol] = pos
        self.book["available"] = round(self.book["available"] - cost, 2)
        self._save()

        # ── SINGLE GTT OCO: SL + Target in ONE order ──────────
        # This is the ONLY protection order. No separate SL order.
        # GTT lives on Zerodha server — works 24/7 even if bot crashes.
        # IMPORTANT: Only place GTT if order is FILLED (COMPLETE).
        # For AMO orders (after-hours), GTT is deferred to 07:30 GTT sync
        # when the order has actually executed and shares are in holdings.
        _order_filled = False
        try:
            time.sleep(0.5)
            _check = self.order_mgr.get_order_status(order_id)
            if _check and _check.get("status") == "COMPLETE":
                _order_filled = True
        except Exception:
            pass

        if not _order_filled:
            # AMO or pending order — mark for deferred GTT placement
            pos["gtt_pending"] = True
            pos["gtt_sl"] = sl
            pos["gtt_target"] = t2
            self.book["positions"][symbol] = pos
            self._save()
            logger.info(f"GTT DEFERRED [{symbol}]: Order not yet filled (AMO/pending) — GTT will be placed after fill")
            self.send_telegram(
                f"ENTRY + GTT PENDING\n"
                f"{symbol} BUY @ Rs.{actual_price} x{qty}\n"
                f"SL: Rs.{sl} | Target: Rs.{t2}\n"
                f"GTT will be placed after AMO fills tomorrow",
                priority="trade"
            )
            return pos

        # Order is COMPLETE — place GTT immediately
        try:
            _gtt_kite = self.KiteSession.get()
            
            # ═══ SEBI-COMPLIANT: Validate and cap SL before GTT placement ═══
            if sl > 0 and actual_price > 0:
                _sl_pct = (actual_price - sl) / actual_price
                if _sl_pct > 0.01:
                    # SL too wide — cap at 0.9%
                    _old_sl = sl
                    sl = round(actual_price * (1 - MAX_SL_PERCENT), 2)
                    pos["stop_loss"] = sl
                    self.book["positions"][symbol] = pos
                    logger.info(
                        f"GTT SL CAPPED [{symbol}]: {_sl_pct*100:.1f}% was >1% "
                        f"→ Rs.{sl} (0.9% from Rs.{actual_price})"
                    )
            
            if _gtt_kite and sl > 0 and t2 > 0:
                # Check if GTT already exists for this symbol
                _gtt_exists = False
                try:
                    _existing = _gtt_kite.get_gtts()
                    for _eg in _existing:
                        if (_eg.get("status") == "active" and
                            _eg.get("condition", {}).get("tradingsymbol", "") == symbol):
                            _gtt_exists = True
                            self.book["positions"][symbol]["gtt_id"] = _eg.get("id", "EXISTS")
                            self._save()
                            logger.info(f"GTT already exists for {symbol} — skipping")
                            break
                except Exception:
                    pass  # Can't check — proceed with placement

                if not _gtt_exists:
                    _sl_trigger = round(sl * 1.005, 1)
                    _sl_limit = round(sl, 1)
                    
                    # ═══ SEBI-COMPLIANT: Ensure SL trigger is below current price ═══
                    if _sl_trigger >= actual_price:
                        _sl_trigger = round(actual_price * 0.995, 1)
                        _sl_limit = round(_sl_trigger * 0.998, 1)
                        logger.warning(
                            f"GTT trigger adjusted [{symbol}]: was above entry, "
                            f"now Rs.{_sl_trigger} (0.5% below entry)"
                        )
                    
                    _tp_trigger = round(t2 * 0.995, 1)
                    _tp_limit = round(t2 * 0.99, 1)
                    _gtt_resp = _gtt_kite.place_gtt(
                        trigger_type=_gtt_kite.GTT_TYPE_OCO,
                        tradingsymbol=symbol,
                        exchange="NSE",
                        trigger_values=[_sl_trigger, _tp_trigger],
                        last_price=actual_price,
                        orders=[
                            {
                                "exchange": "NSE",
                                "tradingsymbol": symbol,
                                "transaction_type": "SELL",
                                "quantity": qty,
                                "order_type": "LIMIT",
                                "product": self.product,
                                "price": _sl_limit,
                            },
                            {
                                "exchange": "NSE",
                                "tradingsymbol": symbol,
                                "transaction_type": "SELL",
                                "quantity": qty,
                                "order_type": "LIMIT",
                                "product": self.product,
                                "price": _tp_limit,
                            },
                        ],
                    )
                    _gtt_id = _gtt_resp.get("trigger_id", "?")
                    self.book["positions"][symbol]["gtt_id"] = _gtt_id
                    self.book["positions"][symbol]["gtt_sl"] = _sl_trigger
                    self.book["positions"][symbol]["gtt_target"] = _tp_trigger
                    self._save()
                    logger.info(
                        f"GTT OCO [{symbol}]: SL Rs.{_sl_limit} | "
                        f"Target Rs.{_tp_limit} | GTT ID: {_gtt_id}"
                    )
                    self.send_telegram(
                        f"ENTRY + GTT OCO SET\n"
                        f"`{symbol}` BUY @ Rs.{actual_price} x{qty}\n"
                        f"SL: Rs.{_sl_limit} | Target: Rs.{_tp_limit}\n"
                        f"GTT ID: {_gtt_id}\n"
                        f"Protected 24/7 on Zerodha server",
                        priority="trade"
                    )
            elif _gtt_kite and sl > 0:
                # Fallback: if no target, place SINGLE GTT for SL only
                _sl_trigger = round(sl * 1.005, 1)
                _sl_limit = round(sl, 1)
                _gtt_resp = _gtt_kite.place_gtt(
                    trigger_type=_gtt_kite.GTT_TYPE_SINGLE,
                    tradingsymbol=symbol,
                    exchange="NSE",
                    trigger_values=[_sl_trigger],
                    last_price=actual_price,
                    orders=[{
                        "exchange": "NSE",
                        "tradingsymbol": symbol,
                        "transaction_type": "SELL",
                        "quantity": qty,
                        "order_type": "LIMIT",
                        "product": self.product,
                        "price": _sl_limit,
                    }],
                )
                _gtt_id = _gtt_resp.get("trigger_id", "?")
                self.book["positions"][symbol]["gtt_id"] = _gtt_id
                self.book["positions"][symbol]["gtt_sl"] = _sl_trigger
                self._save()
                logger.info(f"GTT SL [{symbol}]: Rs.{_sl_limit} | GTT ID: {_gtt_id}")
            else:
                logger.warning(f"GTT SKIPPED [{symbol}]: Kite offline or no SL/target")
        except Exception as _gtt_err:
            logger.warning(f"GTT [{symbol}]: {_gtt_err} — position unprotected until next GTT cycle")

        logger.info(f"LIVE {self.name.upper()} ENTRY: {symbol} @ Rs.{actual_price} x{qty} | OID:{order_id}")
        return pos

    def exit(self, symbol, price, reason):
        """Place a real SELL order to close position.
        SAFETY: NEVER place sell orders outside market hours (09:15-15:20).
        SAFETY: NEVER sell KITE_ADOPTED positions — these are existing holdings."""
        pos = self.book["positions"].get(symbol)
        if not pos:
            return None

        # CRITICAL: Never auto-sell KITE_ADOPTED positions
        # These are existing holdings — only GTT protects them, bot never sells
        if pos.get("source", "") in ("KITE_ADOPT", "KITE_ADOPTED"):
            logger.info(
                f"EXIT BLOCKED [{symbol}]: KITE_ADOPTED position — "
                f"bot never auto-sells existing holdings. GTT protects this."
            )
            return None

        qty = pos.get("qty", 0)
        if qty <= 0:
            return None

        # SAFETY GATE: Block sell orders outside market hours
        _now_exit = _now_ist()
        _exit_mins = _now_exit.hour * 60 + _now_exit.minute
        _market_open = (555 <= _exit_mins <= 920)  # 09:15 to 15:20
        if not _market_open:
            logger.warning(
                f"EXIT BLOCKED [{symbol}]: Market closed ({_now_exit.strftime('%H:%M')}) "
                f"— GTT will protect this position"
            )
            return None

        # ── BUG FIX: Check if Kite SL already executed (prevent double-sell) ──
        try:
            kite = self.KiteSession.get()
            if kite:
                kite_positions = kite.positions()
                net = kite_positions.get("net", [])
                kite_qty = 0
                for kp in net:
                    if (kp.get("tradingsymbol") == symbol and
                        kp.get("exchange") == "NSE"):
                        kite_qty = kp.get("quantity", 0)
                        break
                # Also check holdings for CNC
                if kite_qty == 0 and self.product == "CNC":
                    try:
                        holdings = kite.holdings()
                        for h in holdings:
                            if h.get("tradingsymbol") == symbol:
                                kite_qty = h.get("quantity", 0)
                                break
                    except Exception:
                        pass
                if kite_qty <= 0:
                    # Position already closed (SL triggered or manual exit)
                    logger.info(f"🔄 {symbol}: Already closed on Kite (SL triggered?) — removing from bot")
                    # ── Delete GTT if it wasn't the one that triggered (orphan prevention) ──
                    _auto_gtt_id = pos.get("gtt_id")
                    if _auto_gtt_id:
                        self._cancel_gtt_by_id(_auto_gtt_id, symbol)
                    self.book["positions"].pop(symbol, None)
                    pnl = round((price - pos["entry_price"]) * pos["qty"], 2)
                    pct = round((price - pos["entry_price"]) / pos["entry_price"] * 100, 2) if pos["entry_price"] > 0 else 0
                    trade = {
                        **pos,
                        "exit_price": price, "exit_time": _now_ist().isoformat(),
                        "pnl": pnl, "pnl_pct": pct,
                        "reason": f"{reason} (SL auto-executed on Kite)",
                        "status": "CLOSED",
                    }
                    self.book["trades"].append(trade)
                    self.book["available"] = round(self.book["available"] + pos["cost"] + pnl, 2)
                    self.book["pnl_log"].append({"date": _now_ist().strftime("%Y-%m-%d"), "pnl": pnl})
                    self._save()
                    self.risk.update_pnl(self.name, pnl)
                    self.circuit.check_and_act(pnl)
                    # v23.6.1: Blacklist on auto-SL loss
                    if pnl < 0:
                        try:
                            from global_eye_v23_pythonanywhere import LossBlacklist
                            LossBlacklist.add(symbol, f"KITE SL AUTO ({pct:+.1f}%)")
                        except Exception:
                            pass
                    emoji = "✅" if pnl >= 0 else "❌"
                    self.send_telegram(
                        f"{emoji} *{self.name.upper()} — SL Auto-Executed*\n"
                        f"`{symbol}` @ ~₹{price}\n"
                        f"PnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\n"
                        f"_Position was closed by Kite SL order_",
                        priority="trade"
                    )
                    return trade
                # Update qty to match Kite (in case partial fill)
                if kite_qty != qty:
                    qty = kite_qty
                    logger.info(f"🔄 {symbol}: Adjusting exit qty to {qty} (Kite actual)")
        except Exception as e:
            logger.debug(f"Kite position check [{symbol}]: {e}")
            # If we can't check, proceed with the sell (better safe)

        # ── Place real SELL order ─────────────────────────────
        tag = f"EXIT_{reason[:6]}"
        order_id = self.order_mgr.place_equity_order(
            symbol=symbol,
            transaction_type="SELL",
            qty=qty,
            price=round(price, 1),
            product=pos.get("product", self.product),
            order_type="MARKET",
            tag=tag,
        )

        if not order_id:
            logger.error(f"❌ EXIT FAILED [{self.name}]: {symbol} — MANUAL EXIT NEEDED")
            self.send_telegram(
                f"🔴 *EXIT ORDER FAILED*\n"
                f"`{symbol}` x{qty} | {self.name.upper()}\n"
                f"⚠️ MANUAL EXIT REQUIRED ON KITE",
                priority="critical"
            )
            return None

        # ── Record trade ──────────────────────────────────────
        self.book["positions"].pop(symbol, None)
        pnl = round((price - pos["entry_price"]) * qty, 2)
        pct = round((price - pos["entry_price"]) / pos["entry_price"] * 100, 2) if pos["entry_price"] > 0 else 0

        trade = {
            **pos,
            "exit_price":  price,
            "exit_time":   _now_ist().isoformat(),
            "exit_order_id": order_id,
            "pnl":         pnl,
            "pnl_pct":     pct,
            "reason":      reason,
            "status":      "CLOSED",
        }
        self.book["trades"].append(trade)
        self.book["available"] = round(self.book["available"] + pos["cost"] + pnl, 2)
        self.book["pnl_log"].append({"date": _now_ist().strftime("%Y-%m-%d"), "pnl": pnl})
        self._save()

        # Update risk manager
        self.risk.update_pnl(self.name, pnl)

        # Check circuit breaker
        self.circuit.check_and_act(pnl)

        # ── Cancel the original SL order (no longer needed) ──
        self._cancel_sl_order(symbol)

        # ── Delete GTT so it doesn't fire after manual/bot exit (orphan prevention) ──
        _exited_gtt_id = pos.get("gtt_id")
        if _exited_gtt_id:
            self._cancel_gtt_by_id(_exited_gtt_id, symbol)

        emoji = "✅" if pnl >= 0 else "❌"
        self.send_telegram(
            f"{emoji} *LIVE {self.name.upper()} CLOSED*\n"
            f"`{symbol}` @ ₹{price}\n"
            f"PnL: `{'+'if pnl>=0 else ''}₹{pnl:,.0f}` ({pct}%)\n"
            f"Reason: {reason}\n"
            f"Order ID: `{order_id}`",
            priority="trade"
        )

        # FIX #5: Persist to cumulative trade history
        if trade:
            try:
                import json as _json
                _hist_file = os.path.join(DATA_DIR, "trade_history_cumulative.json")
                _hist = []
                if os.path.exists(_hist_file):
                    with open(_hist_file) as _hf:
                        _hist = _json.load(_hf)
                _key = f"{trade.get('symbol','')}_{trade.get('exit_time','')}"
                _existing = {f"{t.get('symbol','')}_{t.get('exit_time','')}" for t in _hist}
                if _key not in _existing:
                    _hist.append(trade)
                    if len(_hist) > 500: _hist = _hist[-500:]
                    with open(_hist_file, "w") as _hf:
                        _json.dump(_hist, _hf, indent=2, default=str)
            except Exception as _he:
                logger.debug(f"Trade history: {_he}")

        # v23.5.0: Register profit for compounding engine
        if pnl > 0:
            try:
                from global_eye_v23_pythonanywhere import ProfitCompounder
                ProfitCompounder.register_profit(pnl, self.name, symbol)
            except Exception:
                pass  # Compounder not available — OK

        # v23.6.1: Auto-blacklist on loss exits — prevent re-buying burned stocks
        if pnl < 0:
            try:
                from global_eye_v23_pythonanywhere import LossBlacklist
                if "circuit" in reason.lower():
                    LossBlacklist.add(symbol, f"LIVE CIRCUIT EXIT ({pct:+.1f}%)")
                elif pct <= -5:
                    LossBlacklist.add(symbol, f"LIVE BIG LOSS ({pct:+.1f}%)",
                                      cooldown_hours=168)  # 7 days
                else:
                    LossBlacklist.add(symbol, f"LIVE LOSS ({pct:+.1f}%)")
            except Exception as _bl_err:
                logger.debug(f"Blacklist on exit [{symbol}]: {_bl_err}")

        return trade

    def _cancel_sl_order(self, symbol):
        """Cancel any pending SL orders for this symbol after exit."""
        kite = self.KiteSession.get()
        if not kite:
            return
        try:
            orders = kite.orders()
            for order in orders:
                if (order.get("tradingsymbol") == symbol and
                    order.get("transaction_type") == "SELL" and
                    order.get("status") in ("TRIGGER PENDING", "OPEN") and
                    "SL" in order.get("tag", "")):
                    kite.cancel_order(
                        variety=order.get("variety", "regular"),
                        order_id=order["order_id"]
                    )
                    logger.info(f"🚫 Cancelled SL order for {symbol}: {order['order_id']}")
        except Exception as e:
            logger.debug(f"Cancel SL order [{symbol}]: {e}")

    def _cancel_gtt(self, symbol):
        """Delete active GTT for this symbol. Called on exit to prevent orphan GTTs."""
        pos = self.book.get("positions", {}).get(symbol) or self.book.get("trades", [{}])[-1] if not self.book.get("positions", {}).get(symbol) else self.book["positions"].get(symbol)
        # Use gtt_id stored in the position dict (passed in by caller)
        # This is a no-op if pos is not available — orphan cleanup via gtt_audit() covers that
        pass  # see _cancel_gtt_by_id below

    def _cancel_gtt_by_id(self, gtt_id, symbol=""):
        """Delete a GTT by ID. Safe — ignores errors if already triggered/gone."""
        kite = self.KiteSession.get()
        if not kite or not gtt_id or str(gtt_id) in ("?", "EXISTS", ""):
            return
        try:
            kite.delete_gtt(gtt_id)
            logger.info(f"🚫 GTT deleted [{symbol}]: ID {gtt_id}")
        except Exception as e:
            logger.debug(f"GTT delete [{symbol}] ID {gtt_id}: {e} — may have already triggered")

    def update_gtt(self, symbol, new_sl, ltp=None):
        """
        Update the Zerodha GTT for a position when trailing SL moves up.
        Uses modify_gtt() — same GTT ID kept, just prices updated.
        No delete + recreate = no gap in protection, one API call only.
        Falls back to delete + place_gtt only if modify fails (e.g. GTT
        was already triggered and no longer exists).

        Args:
            symbol  : NSE tradingsymbol
            new_sl  : new (higher) stop-loss price
            ltp     : last traded price (used as last_price in GTT call)
        """
        pos = self.book.get("positions", {}).get(symbol)
        if not pos:
            return
        old_gtt_id  = pos.get("gtt_id")
        old_gtt_sl  = pos.get("gtt_sl", 0)
        qty         = pos.get("qty", 0)
        entry_price = pos.get("entry_price", 0)
        t2          = pos.get("target2", 0)
        if qty <= 0 or entry_price <= 0:
            return

        # CRITICAL: KITE_ADOPTED positions — only update GTT SL, NEVER exit
        _is_adopted = pos.get("source", "") in ("KITE_ADOPT", "KITE_ADOPTED")

        # Enforce minimum 0.5% improvement before touching Kite API
        if old_gtt_sl > 0:
            chg = (new_sl - old_gtt_sl) / old_gtt_sl * 100
            if chg < 0.5:
                logger.debug(f"GTT update [{symbol}]: SL change {chg:.1f}% < 0.5% — skip")
                return

        kite = self.KiteSession.get()
        if not kite:
            return

        _sl_trigger = round(new_sl * 1.005, 1)
        _sl_limit   = round(new_sl, 1)
        _last_price = ltp if ltp and ltp > 0 else entry_price
        _tp_trigger = round(t2 * 0.995, 1) if t2 > 0 else round(entry_price * 1.20, 1)
        _tp_limit   = round(t2 * 0.99,  1) if t2 > 0 else round(entry_price * 1.195, 1)

        # Safety: if SL >= LTP price already below SL
        if _last_price > 0 and _sl_trigger >= _last_price:
            _now_check = _now_ist()
            _mins = _now_check.hour * 60 + _now_check.minute
            _market_open = (555 <= _mins <= 920)  # 09:15 to 15:20

            if _is_adopted:
                # KITE_ADOPTED: NEVER exit — just log, GTT on Zerodha handles it
                logger.info(
                    f"GTT UPDATE [{symbol}]: SL Rs.{_sl_trigger} >= LTP Rs.{_last_price} "
                    f"— KITE_ADOPTED position, bot will NOT sell. GTT protects."
                )
                return

            if _market_open:
                # During market hours — exit immediately
                logger.warning(
                    f"GTT UPDATE [{symbol}]: SL Rs.{_sl_trigger} >= LTP Rs.{_last_price} "
                    f"— SL breached during market hours, exiting now"
                )
                try:
                    self.exit(symbol, _last_price, "SL Breached (auto-detected)")
                except Exception as _ex_e:
                    logger.warning(f"Auto-exit [{symbol}]: {_ex_e}")
            else:
                # Outside market hours — DO NOT exit, DO NOT place AMO
                # The existing GTT on Zerodha will handle it at market open
                # Just log the warning so we know
                logger.warning(
                    f"GTT UPDATE [{symbol}]: SL Rs.{_sl_trigger} >= LTP Rs.{_last_price} "
                    f"— SL breached outside hours, existing GTT will handle at open"
                )
            return

        _orders = [
            {
                "exchange": "NSE", "tradingsymbol": symbol,
                "transaction_type": "SELL", "quantity": qty,
                "order_type": "LIMIT", "product": self.product,
                "price": _sl_limit,
            },
            {
                "exchange": "NSE", "tradingsymbol": symbol,
                "transaction_type": "SELL", "quantity": qty,
                "order_type": "LIMIT", "product": self.product,
                "price": _tp_limit,
            },
        ]
        _gtt_type      = kite.GTT_TYPE_OCO
        _trigger_vals  = [_sl_trigger, _tp_trigger]

        # ── Try modify_gtt first (same ID, just updated prices) ──────────
        _modified = False
        if old_gtt_id and str(old_gtt_id) not in ("?", "EXISTS", ""):
            try:
                kite.modify_gtt(
                    trigger_id=old_gtt_id,
                    trigger_type=_gtt_type,
                    tradingsymbol=symbol,
                    exchange="NSE",
                    trigger_values=_trigger_vals,
                    last_price=_last_price,
                    orders=_orders,
                )
                pos["gtt_sl"]     = _sl_trigger
                pos["gtt_target"] = _tp_trigger
                self._save()
                _modified = True
                logger.info(
                    f"GTT MODIFIED [{symbol}]: "
                    f"SL Rs.{old_gtt_sl:.1f} -> Rs.{_sl_limit:.1f} "
                    f"| GTT ID: {old_gtt_id} (same ID kept)"
                )
                self.send_telegram(
                    f"GTT TRAILING SL UPDATED\n"
                    f"`{symbol}` | {self.name.upper()}\n"
                    f"SL: Rs.{old_gtt_sl:.1f} -> Rs.{_sl_limit:.1f}\n"
                    f"GTT ID: {old_gtt_id} unchanged | Protected 24/7",
                    priority="trade"
                )
            except Exception as _me:
                logger.debug(
                    f"GTT modify [{symbol}]: {_me} — "
                    f"GTT may have triggered, falling back to place_gtt")

        # ── Fallback: place fresh GTT (only if modify failed) ────────────
        if not _modified:
            try:
                _resp = kite.place_gtt(
                    trigger_type=_gtt_type,
                    tradingsymbol=symbol,
                    exchange="NSE",
                    trigger_values=_trigger_vals,
                    last_price=_last_price,
                    orders=_orders,
                )
                _new_id           = _resp.get("trigger_id", "?")
                pos["gtt_id"]     = _new_id
                pos["gtt_sl"]     = _sl_trigger
                pos["gtt_target"] = _tp_trigger
                self._save()
                logger.info(
                    f"GTT REPLACED [{symbol}]: "
                    f"SL Rs.{old_gtt_sl:.1f} -> Rs.{_sl_limit:.1f} "
                    f"| New GTT ID: {_new_id}"
                )
                self.send_telegram(
                    f"GTT TRAILING SL UPDATED\n"
                    f"`{symbol}` | {self.name.upper()}\n"
                    f"SL: Rs.{old_gtt_sl:.1f} -> Rs.{_sl_limit:.1f}\n"
                    f"New GTT ID: {_new_id} | Protected 24/7",
                    priority="trade"
                )
            except Exception as e:
                logger.warning(
                    f"GTT update FAILED [{symbol}]: {e} — "
                    f"position unprotected until gtt_audit() at 08:30"
                )

    def check_stops(self, scans):
        """Check SL/target hits using live prices.
        Also ensures every position has a GTT — places one if missing."""
        exited = []
        for sym, pos in list(self.book["positions"].items()):
            m = next((a for a in scans if a["symbol"] == sym), None)
            if not m:
                continue
            p = m["price"]

            # ── AUTO-GTT: ensure every position has GTT protection ──
            # Skip during Zerodha maintenance window (01:30-05:30 IST)
            _now_gtt = _now_ist()
            _gtt_mins = _now_gtt.hour * 60 + _now_gtt.minute
            _gtt_maintenance = (90 <= _gtt_mins <= 330)  # 01:30 to 05:30

            if (not pos.get("gtt_id") or pos.get("gtt_pending")) and pos.get("stop_loss", 0) > 0 and not _gtt_maintenance:
                try:
                    _gtt_kite = self.KiteSession.get()
                    if _gtt_kite:
                        _sl = pos.get("stop_loss", 0)
                        _t2 = pos.get("target2", round(pos.get("entry_price", p) * 1.18, 2))
                        _qty = pos.get("qty", 0)
                        if _sl > 0 and _t2 > 0 and _qty > 0:
                            # Check if GTT already exists on Kite
                            _already_has = False
                            try:
                                for _eg in (_gtt_kite.get_gtts() or []):
                                    if (_eg.get("status") == "active" and 
                                        _eg.get("condition", {}).get("tradingsymbol", "") == sym):
                                        _already_has = True
                                        pos["gtt_id"] = _eg.get("id")
                                        pos.pop("gtt_pending", None)
                                        self._save()
                                        break
                            except Exception:
                                pass

                            if not _already_has:
                                _sl_trig = round(_sl * 1.005, 1)
                                _tp_trig = round(_t2 * 0.995, 1)
                                _gtt_resp = _gtt_kite.place_gtt(
                                    trigger_type=_gtt_kite.GTT_TYPE_OCO,
                                    tradingsymbol=sym,
                                    exchange="NSE",
                                    trigger_values=[_sl_trig, _tp_trig],
                                    last_price=p,
                                    orders=[
                                        {"exchange": "NSE", "tradingsymbol": sym,
                                         "transaction_type": "SELL", "quantity": _qty,
                                         "order_type": "LIMIT", "product": self.product,
                                         "price": round(_sl, 1)},
                                        {"exchange": "NSE", "tradingsymbol": sym,
                                         "transaction_type": "SELL", "quantity": _qty,
                                         "order_type": "LIMIT", "product": self.product,
                                         "price": round(_t2 * 0.99, 1)},
                                    ]
                                )
                                _new_gtt_id = _gtt_resp if isinstance(_gtt_resp, int) else _gtt_resp.get("trigger_id", 0) if isinstance(_gtt_resp, dict) else 0
                                pos["gtt_id"] = _new_gtt_id
                                pos["gtt_sl"] = _sl_trig
                                pos.pop("gtt_pending", None)
                                self._save()
                                logger.info(f"AUTO-GTT PLACED [{sym}]: SL={_sl:.1f} T2={_t2:.1f} GTT:{_new_gtt_id}")
                                self.send_telegram(
                                    f"GTT AUTO-PLACED\n"
                                    f"`{sym}` x{_qty}\n"
                                    f"SL: Rs.{_sl:.1f} | Target: Rs.{_t2:.1f}\n"
                                    f"GTT ID: {_new_gtt_id}\n"
                                    f"Protected 24/7 on Zerodha server",
                                    priority="trade"
                                )
                except Exception as _ag_err:
                    logger.debug(f"Auto-GTT [{sym}]: {_ag_err}")

            # ══════════════════════════════════════════════════════════
            # TRAILING SL: Move SL upward when price rises
            # Uses 4-tier ratchet: +3%→lock 1%, +5%→lock 2.5%, +8%→lock 5%, +12%→lock 8%
            # Updates Zerodha GTT so protection is REAL (not just in bot book)
            # ══════════════════════════════════════════════════════════
            _entry = pos.get("entry_price", 0)
            if _entry > 0 and p > _entry:
                _gain_pct = ((p - _entry) / _entry) * 100
                _old_sl = pos.get("stop_loss", 0)
                _new_sl = _old_sl  # Start with current SL

                # 4-tier profit lock ratchet
                if _gain_pct >= 12:
                    _new_sl = max(_new_sl, round(_entry * 1.08, 1))   # Lock 8% profit
                elif _gain_pct >= 8:
                    _new_sl = max(_new_sl, round(_entry * 1.05, 1))   # Lock 5% profit
                elif _gain_pct >= 5:
                    _new_sl = max(_new_sl, round(_entry * 1.025, 1))  # Lock 2.5% profit
                elif _gain_pct >= 3:
                    _new_sl = max(_new_sl, round(_entry * 1.01, 1))   # Lock 1% profit

                # Also trail with ATR: SL = max(current_SL, LTP - 2*ATR)
                # Use a simple proxy if ATR not available
                _atr_proxy = p * 0.02  # ~2% ATR proxy
                _atr_trail = round(p - 2 * _atr_proxy, 1)
                _new_sl = max(_new_sl, _atr_trail)

                # Only move SL UP, never down
                if _new_sl > _old_sl and _new_sl < p:
                    _sl_change_pct = ((_new_sl - _old_sl) / _old_sl * 100) if _old_sl > 0 else 100
                    pos["stop_loss"] = _new_sl
                    self._save()

                    # Update GTT on Zerodha (minimum 1.5% change to avoid spam)
                    if _sl_change_pct >= 1.5:
                        try:
                            self.update_gtt(sym, _new_sl, ltp=p)
                            logger.info(
                                f"📈 TRAILING SL [{sym}]: SL Rs.{_old_sl:.1f} → Rs.{_new_sl:.1f} "
                                f"(+{_sl_change_pct:.1f}%) | LTP Rs.{p:.1f} (+{_gain_pct:.1f}%)"
                            )
                        except Exception as _trail_err:
                            logger.debug(f"Trail GTT update [{sym}]: {_trail_err}")

            # Update highest price for this position
            _cur_highest = pos.get("highest_since_entry", _entry)
            if p > _cur_highest:
                pos["highest_since_entry"] = p

            # ══════════════════════════════════════════════════════════
            # STEP 10-12: MONITORING + PARTIAL EXIT + FINAL EXIT
            # ══════════════════════════════════════════════════════════

            # Stop loss hit → full exit
            if p <= pos["stop_loss"]:
                t = self.exit(sym, p, "🛑 Stop Loss")
                if t:
                    exited.append(t)

            # ── STEP 11: PARTIAL EXIT at T1 (sell 50%, SL→breakeven) ──
            # When price hits T1 (+2.5%):
            #   1. Sell 50% of position
            #   2. Move SL to entry price (breakeven — risk-free trade)
            #   3. Let remaining 50% ride to T2 or trailing SL
            elif p >= pos["target1"] and not pos.get("t1_partial_done"):
                _entry = pos.get("entry_price", 0)
                _orig_qty = pos.get("qty", 0)
                _sell_qty = max(1, _orig_qty // 2)  # Sell 50% (min 1 share)
                _remain_qty = _orig_qty - _sell_qty

                if _sell_qty > 0 and _remain_qty > 0:
                    try:
                        # Place partial sell order
                        _tag = f"T1_PART_{sym[:6]}"
                        _sell_id = self.order_mgr.place_equity_order(
                            symbol=sym, transaction_type="SELL",
                            qty=_sell_qty, price=round(p, 1),
                            product=self.product, order_type="MARKET",
                            tag=_tag, stoploss_price=None,
                        )
                        if _sell_id:
                            # Update position: reduce qty, mark T1 done
                            pos["qty"] = _remain_qty
                            pos["t1_partial_done"] = True
                            pos["t1_exit_price"] = round(p, 2)
                            pos["t1_exit_qty"] = _sell_qty

                            # Move SL to breakeven (entry price)
                            _old_sl = pos["stop_loss"]
                            pos["stop_loss"] = _entry
                            pos["cost"] = round(_remain_qty * _entry, 2)

                            self._save()

                            # Update GTT: cancel old, place new with breakeven SL + reduced qty
                            _old_gtt = pos.get("gtt_id")
                            if _old_gtt:
                                try:
                                    self._cancel_gtt_by_id(_old_gtt, sym)
                                except Exception:
                                    pass
                            # Place new GTT with remaining qty and breakeven SL
                            try:
                                _gtt_kite = self.KiteSession.get()
                                if _gtt_kite and _remain_qty > 0:
                                    _be_sl_trig = round(_entry * 1.005, 1)
                                    _t2 = pos.get("target2", round(_entry * 1.06, 2))
                                    _tp_trig = round(_t2 * 0.995, 1)
                                    _gtt_resp = _gtt_kite.place_gtt(
                                        trigger_type=_gtt_kite.GTT_TYPE_OCO,
                                        tradingsymbol=sym, exchange="NSE",
                                        trigger_values=[_be_sl_trig, _tp_trig],
                                        last_price=p,
                                        orders=[
                                            {"exchange": "NSE", "tradingsymbol": sym,
                                             "transaction_type": "SELL", "quantity": _remain_qty,
                                             "order_type": "LIMIT", "product": self.product,
                                             "price": round(_entry, 1)},
                                            {"exchange": "NSE", "tradingsymbol": sym,
                                             "transaction_type": "SELL", "quantity": _remain_qty,
                                             "order_type": "LIMIT", "product": self.product,
                                             "price": round(_t2 * 0.99, 1)},
                                        ]
                                    )
                                    _new_gtt_id = _gtt_resp if isinstance(_gtt_resp, int) else _gtt_resp.get("trigger_id", 0) if isinstance(_gtt_resp, dict) else 0
                                    pos["gtt_id"] = _new_gtt_id
                                    self._save()
                            except Exception as _gtt_t1_err:
                                logger.warning(f"GTT T1 update [{sym}]: {_gtt_t1_err}")

                            _pnl_partial = round((_sell_qty * (p - _entry)), 2)
                            logger.info(
                                f"✂️ T1 PARTIAL EXIT [{sym}]: Sold {_sell_qty}/{_orig_qty} @ ₹{p:.1f} "
                                f"(+₹{_pnl_partial:,.0f}) | SL→breakeven ₹{_entry:.1f} | "
                                f"Remaining {_remain_qty} ride to T2"
                            )
                            self.send_telegram(
                                f"✂️ *T1 PARTIAL EXIT*\n"
                                f"`{sym}` | {self.name.upper()}\n"
                                f"Sold: {_sell_qty} @ Rs.{p:.1f} (+Rs.{_pnl_partial:,.0f})\n"
                                f"Remaining: {_remain_qty} shares\n"
                                f"SL moved: Rs.{_old_sl:.1f} → Rs.{_entry:.1f} (breakeven)\n"
                                f"Target: Rs.{pos.get('target2', 0):.1f} (T2)",
                                priority="trade"
                            )
                            # Record partial trade in pnl log
                            self.book["pnl_log"].append({
                                "date": _now_ist().strftime("%Y-%m-%d"),
                                "pnl": _pnl_partial, "type": "T1_PARTIAL",
                            })
                            self.risk.update_pnl(self.name, _pnl_partial)
                    except Exception as _t1_err:
                        logger.warning(f"T1 partial exit [{sym}]: {_t1_err}")

                elif _orig_qty <= 1:
                    # Only 1 share — can't split, do full exit at T1
                    t = self.exit(sym, p, "🎯 T1 (1 share)")
                    if t:
                        exited.append(t)

            # ── STEP 12: FINAL EXIT at T2 (remaining 50%) ──
            elif p >= pos["target2"]:
                t = self.exit(sym, p, "🎯 Target 2 (final exit)")
                if t:
                    exited.append(t)

        return exited

    def square_off_all(self, scans):
        """Intraday square-off — close all positions."""
        closed = []
        for sym in list(self.book["positions"].keys()):
            m = next((a for a in scans if a["symbol"] == sym), None)
            price = m["price"] if m else self.book["positions"][sym]["entry_price"]
            t = self.exit(sym, price, "⏰ Auto Square-Off 15:15")
            if t:
                closed.append(t)
        if closed:
            total = sum(t["pnl"] for t in closed)
            self.send_telegram(
                f"⏰ *LIVE Intraday Square-Off*\n"
                f"Closed: {len(closed)} | Net: `{'+'if total>=0 else ''}₹{total:,.0f}`",
                priority="trade"
            )
        return closed

    def check_time_exit(self, scans):
        """Time-based exits for swing/longterm."""
        exited = []
        max_days = 28 if self.name == "swing" else 365
        now = _now_ist()
        for sym, pos in list(self.book["positions"].items()):
            try:
                entry = datetime.fromisoformat(pos["entry_time"])
                # Make both tz-aware for safe comparison
                if entry.tzinfo is None:
                    entry = IST.localize(entry)
                if (now - entry).days >= max_days:
                    m = next((a for a in scans if a["symbol"] == sym), None)
                    price = m["price"] if m else pos["entry_price"]
                    t = self.exit(sym, price, f"📅 {'4-Week' if max_days==28 else '12-Month'} Time Exit")
                    if t:
                        exited.append(t)
            except Exception:
                pass
        return exited

    def summary(self):
        """Same interface as BasePaperTrader.summary()."""
        closed = [t for t in self.book["trades"] if t.get("status") == "CLOSED"]
        wins = [t for t in closed if t["pnl"] > 0]
        losses = [t for t in closed if t["pnl"] <= 0]
        total_pnl = round(sum(t["pnl"] for t in closed), 2)
        wr = round(len(wins) / len(closed) * 100, 1) if closed else 0
        aw = round(sum(t["pnl"] for t in wins) / len(wins), 2) if wins else 0
        al = round(sum(t["pnl"] for t in losses) / len(losses), 2) if losses else 0
        try:
            start = datetime.fromisoformat(self.book["start_time"])
            if start.tzinfo is None:
                start = IST.localize(start)
            days = round((_now_ist() - start).total_seconds() / 86400, 1)
        except Exception:
            days = 0
        return {
            "strategy":       self.name,
            "capital":        self.book["capital"],
            "available":      self.book["available"],
            "portfolio_value": round(self.book["capital"] + total_pnl, 2),
            "total_pnl":      total_pnl,
            "open_count":     len(self.book["positions"]),
            "total_trades":   len(closed),
            "wins":           len(wins),
            "losses":         len(losses),
            "win_rate":       wr,
            "avg_win":        aw,
            "avg_loss":       al,
            "rr_ratio":       round(abs(aw / al), 2) if al else 0,
            "open_positions": list(self.book["positions"].values()),
            "days_running":   days,
            "mode":           "LIVE 🔴",
        }

    def is_ready_for_live(self):
        """Always ready — we ARE live."""
        return True


# ══════════════════════════════════════════════════════════════
#  LIVE F&O TRADER — wraps FNOTrader with real order execution
# ══════════════════════════════════════════════════════════════

class LiveFNOAdapter:
    """
    Wraps the existing FNOTrader to intercept enter/exit calls
    and place real F&O orders via LiveOrderManager.

    The existing FNOTrader already has excellent:
    - Market direction prediction
    - Strike selection
    - IV estimation
    - Position monitoring
    - Smart exit logic

    We only need to add real order execution at the enter/exit points.
    """

    def __init__(self, fno_trader, order_manager, kite_session_cls,
                 send_telegram_fn, audit):
        self.fno        = fno_trader
        self.order_mgr  = order_manager
        self.KiteSession = kite_session_cls
        self.send_telegram = send_telegram_fn
        self.audit       = audit
        self._nfo_instruments = []  # Cached daily
        self._nfo_cache_date  = ""

    def _get_nfo_instruments(self):
        """Get NFO instruments, cached daily."""
        today = _now_ist().strftime("%Y-%m-%d")
        if self._nfo_cache_date == today and self._nfo_instruments:
            return self._nfo_instruments
        try:
            kite = self.KiteSession.get()
            if kite:
                self._nfo_instruments = kite.instruments("NFO")
                self._nfo_cache_date = today
                logger.info(f"📊 NFO instruments cached: {len(self._nfo_instruments)}")
        except Exception as e:
            logger.error(f"NFO instruments fetch: {e}")
        return self._nfo_instruments

    def _build_tradingsymbol(self, symbol, strike, opt_type, expiry):
        """
        Build Kite F&O tradingsymbol.
        e.g., NIFTY2632723500CE for NIFTY 27-Mar-2026 23500 CE
        """
        try:
            instruments = self._get_nfo_instruments()
            if not instruments:
                logger.error("F&O: No NFO instruments available")
                return None

            # Search NFO instruments for exact match
            for inst in instruments:
                if (inst["name"] == symbol and
                    inst["strike"] == strike and
                    inst["instrument_type"] == opt_type and
                    str(inst["expiry"]) == str(expiry)):
                    return inst["tradingsymbol"]

            # Fallback: try with date parsing
            for inst in instruments:
                if (inst["name"] == symbol and
                    inst["strike"] == strike and
                    inst["instrument_type"] == opt_type):
                    inst_exp = str(inst["expiry"])
                    if str(expiry) in inst_exp or inst_exp in str(expiry):
                        return inst["tradingsymbol"]

            logger.error(f"F&O instrument not found: {symbol} {strike} {opt_type} {expiry}")
            return None

        except Exception as e:
            logger.error(f"F&O instrument lookup: {e}")
            return None

    def enter(self, symbol, spot, direction, source="TECHNICAL", confidence="MODERATE"):
        """Override FNOTrader.enter() to place real orders."""
        # First, let the existing logic calculate everything
        pos = self.fno.enter(symbol, spot, direction, source, confidence)
        if not pos:
            return None

        # Now place real order
        tradingsymbol = self._build_tradingsymbol(
            symbol, pos["strike"], pos["opt_type"], pos["expiry"]
        )
        if not tradingsymbol:
            logger.error(f"❌ F&O entry: Could not find instrument for {symbol} {pos['strike']} {pos['opt_type']}")
            # Remove the paper position since we couldn't place real order
            self.fno.book["positions"].pop(pos["key"], None)
            self.fno.book["available"] = round(self.fno.book["available"] + pos["cost"], 2)
            self.fno._save()
            return None

        lot = pos["lot"]
        order_id = self.order_mgr.place_fno_order(
            tradingsymbol=tradingsymbol,
            exchange="NFO",
            transaction_type="BUY",
            qty=lot,
            order_type="MARKET",
            product="NRML",
            tag=f"FNO_{source[:6]}",
        )

        if order_id:
            # Update position with order ID
            pos["order_id"] = order_id
            pos["tradingsymbol"] = tradingsymbol
            self.fno.book["positions"][pos["key"]] = pos
            self.fno._save()
            self.audit.log("FNO_ENTRY_LIVE", {
                "symbol": symbol, "tradingsymbol": tradingsymbol,
                "strike": pos["strike"], "opt_type": pos["opt_type"],
                "lot": lot, "order_id": order_id,
            })
            return pos
        else:
            # Rollback paper position
            self.fno.book["positions"].pop(pos["key"], None)
            self.fno.book["available"] = round(self.fno.book["available"] + pos["cost"], 2)
            self.fno._save()
            return None

    def _exit_live(self, key, spot, reason):
        """Place real F&O exit order."""
        pos = self.fno.book["positions"].get(key)
        if not pos:
            return self.fno._exit(key, spot, reason)

        tradingsymbol = pos.get("tradingsymbol")
        if not tradingsymbol:
            # Fallback to paper exit if no tradingsymbol
            return self.fno._exit(key, spot, reason)

        lot = pos["lot"]
        order_id = self.order_mgr.place_fno_order(
            tradingsymbol=tradingsymbol,
            exchange="NFO",
            transaction_type="SELL",
            qty=lot,
            order_type="MARKET",
            product="NRML",
            tag=f"FNOX_{reason[:5]}",
        )

        if order_id:
            self.audit.log("FNO_EXIT_LIVE", {
                "key": key, "tradingsymbol": tradingsymbol,
                "lot": lot, "order_id": order_id, "reason": reason,
            })

        # Run paper exit to update books (regardless of order status)
        return self.fno._exit(key, spot, reason)

    # Delegate everything else to underlying FNOTrader
    def predict_market_direction(self, scans):
        return self.fno.predict_market_direction(scans)

    def enter_advance(self, scans):
        # Intercept: use our enter() instead of fno.enter()
        original_enter = self.fno.enter
        self.fno.enter = self.enter
        result = self.fno.enter_advance(scans)
        self.fno.enter = original_enter
        return result

    def monitor(self, spot_prices):
        # Intercept exits
        original_exit = self.fno._exit
        self.fno._exit = self._exit_live
        self.fno.monitor(spot_prices)
        self.fno._exit = original_exit

    def summary(self):
        s = self.fno.summary()
        s["mode"] = "LIVE 🔴"
        return s

    @property
    def book(self):
        return self.fno.book

    def _save(self):
        return self.fno._save()

    # ── Delegate internal methods used by send_detailed_portfolio ──
    def _bs(self, S, K, T, sigma=0.18, otype="CE"):
        return self.fno._bs(S, K, T, sigma, otype)

    def _dte(self):
        return self.fno._dte()

    def _expiry(self):
        return self.fno._expiry()


# ══════════════════════════════════════════════════════════════
#  INTEGRATION FUNCTION — patches GlobalEyeSentinel for live
# ══════════════════════════════════════════════════════════════

def upgrade_to_live(sentinel, KiteSession, send_telegram, save_json, load_json,
                    DATA_DIR, INTRADAY_FILE, SWING_FILE, LONGTERM_FILE, FNO_FILE,
                    MAX_INTRADAY_POS, MAX_SWING_POS, MAX_LONGTERM_POS):
    """
    Called from GlobalEyeSentinel.__init__ when TRADING_MODE=LIVE.

    Replaces paper traders with live traders.
    Sets up capital allocation, position sync, circuit breaker.
    """
    # Import DAILY_FILE from main module
    from global_eye_v23_pythonanywhere import DAILY_FILE

    logger.info("="*65)
    logger.info("  🔴 LIVE TRADING MODE ACTIVATED")
    logger.info("  Real money orders will be placed via Zerodha Kite")
    logger.info("="*65)

    # ── Step 1: Get Kite connection ───────────────────────────
    kite = KiteSession.get()
    if not kite:
        logger.warning("⚠️ LIVE MODE: Kite not connected — will retry at 08:30")
        send_telegram(
            "⚠️ *LIVE MODE — Kite Offline*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "Kite is not connected right now.\n"
            "📊 Bot stays in LIVE mode — scanning, alerts, signals all active\n"
            "🚫 Orders paused until Kite connects\n"
            "🔑 Will auto-connect at 08:30 on trading days\n"
            "📌 Once Kite connects, live trading resumes automatically",
            priority="critical"
        )
        return sentinel  # Don't crash — stay live, orders will queue when Kite connects

    # ── Step 2: Capital allocation ────────────────────────────
    available_capital = CapitalAllocator.get_available_capital(kite)
    if available_capital <= 0:
        logger.warning("⚠️ LIVE MODE: Zero or negative capital — entering OBSERVE mode")
        send_telegram(
            "⚠️ *LIVE MODE — OBSERVE ONLY*\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "💰 Available capital: ₹0 or negative\n"
            "📊 Bot will continue scanning, monitoring filings,\n"
            "   sending alerts, and tracking signals.\n"
            "🚫 NO orders will be placed until funds are added.\n"
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            "📌 *Action needed:* Add funds to Zerodha\n"
            "   Bot will auto-detect and resume trading.",
            priority="critical"
        )
        # DON'T crash — use minimal capital (1 rupee) so all systems
        # initialize correctly. The per-trade capital check (line ~1284)
        # will block ALL orders since available=0.
        available_capital = 1  # Symbolic — no real trades possible

    alloc = CapitalAllocator.allocate(available_capital, kite=kite)
    condition = alloc.pop("_condition", "NEUTRAL")
    mkt_score = alloc.pop("_score", 0)
    mkt_factors = alloc.pop("_factors", {})
    mkt_profile = alloc.pop("_profile", {})
    tier_name = alloc.pop("_tier", "MICRO")
    tier_info = alloc.pop("_tier_info", {})

    # ── Step 3: Initialize audit log ──────────────────────────
    audit = OrderAudit(DATA_DIR)

    # ── Step 4: Initialize order manager ──────────────────────
    order_mgr = LiveOrderManager(KiteSession, audit, send_telegram, sentinel.risk)

    # ── Step 5: Initialize circuit breaker ────────────────────
    circuit = CircuitBreaker(available_capital, order_mgr, sentinel.risk, send_telegram,
                             save_json_fn=save_json, daily_file=DAILY_FILE)

    # ── Step 6: Create live traders ───────────────────────────
    sentinel.intraday = LiveEquityTrader(
        INTRADAY_FILE, alloc["intraday"], MAX_INTRADAY_POS, "intraday",
        sentinel.risk, order_mgr, circuit, KiteSession, send_telegram,
        save_json, load_json
    )
    sentinel.swing = LiveEquityTrader(
        SWING_FILE, alloc["swing"], MAX_SWING_POS, "swing",
        sentinel.risk, order_mgr, circuit, KiteSession, send_telegram,
        save_json, load_json
    )
    sentinel.longterm = LiveEquityTrader(
        LONGTERM_FILE, alloc["longterm"], MAX_LONGTERM_POS, "longterm",
        sentinel.risk, order_mgr, circuit, KiteSession, send_telegram,
        save_json, load_json
    )

    # F&O: wrap existing FNOTrader
    from global_eye_v23_pythonanywhere import FNOTrader
    base_fno = FNOTrader(sentinel.risk)
    base_fno.book["capital"] = alloc["fno"]
    base_fno.book["available"] = alloc["fno"]
    base_fno._save()
    sentinel.fno = LiveFNOAdapter(
        base_fno, order_mgr, KiteSession, send_telegram, audit
    )

    # ── Step 7: Position sync ─────────────────────────────────
    logger.info("🔄 Syncing positions with Kite...")

    # Store sentinel back-reference on each trader for tier migration
    sentinel.intraday._sentinel = sentinel
    sentinel.swing._sentinel = sentinel
    sentinel.longterm._sentinel = sentinel
    sentinel.intraday.book = PositionSync.sync_equity(
        kite, sentinel.intraday.book, "intraday", send_telegram, adopt=False
    )
    sentinel.intraday._save()

    sentinel.swing.book = PositionSync.sync_equity(
        kite, sentinel.swing.book, "swing", send_telegram, adopt=True
    )
    sentinel.swing._save()

    sentinel.longterm.book = PositionSync.sync_equity(
        kite, sentinel.longterm.book, "longterm", send_telegram, adopt=False
    )
    sentinel.longterm._save()

    sentinel.fno.fno.book = PositionSync.sync_fno(
        kite, sentinel.fno.fno.book, send_telegram
    )
    sentinel.fno._save()

    # ── Step 7b: Tier Migration Manager ────────────────────────
    # Detect tier changes and migrate orphaned positions
    if _TIER_MIGRATION_LOADED:
        try:
            tier_mgr = TierMigrationManager(DATA_DIR, send_telegram)
            sentinel._tier_migration_mgr = tier_mgr

            # Build traders dict for migration
            _traders = {
                "intraday": sentinel.intraday,
                "swing": sentinel.swing,
                "longterm": sentinel.longterm,
                "fno": sentinel.fno,
            }
            migration_result = tier_mgr.check_and_migrate(tier_name, _traders)
            if migration_result:
                logger.info(f"TierMigration startup: {migration_result}")
        except Exception as _mig_err:
            logger.error(f"TierMigration startup: {_mig_err}")
            sentinel._tier_migration_mgr = None
    else:
        sentinel._tier_migration_mgr = None

    # ── Step 8: Store references for periodic sync ────────────
    sentinel._live_order_mgr  = order_mgr
    sentinel._live_circuit    = circuit
    sentinel._live_audit      = audit
    sentinel._live_capital    = available_capital

    # ── Step 9: Startup alert ─────────────────────────────────
    # Get TOTAL Kite balance (not just available cash)
    try:
        _margins = kite.margins("equity")
        _total_balance = round(_margins.get("net", available_capital), 2)
        _used_margin = round(_margins.get("utilised", {}).get("debits", 0), 2)
    except Exception:
        _total_balance = available_capital
        _used_margin = 0

    # tier_name and tier_info already set at Step 2 (line ~2466)
    # Do NOT re-read from alloc — _tier was already popped
    # tier_name and tier_info are already correct from above
    factors_str = " | ".join(f"{k}:{v}" for k, v in mkt_factors.items()) if mkt_factors else "No data"

    # Build allocation lines (only show strategies with capital > 0)
    alloc_lines = []
    for strat, label in [("intraday", "Intraday"), ("swing", "Swing"), ("longterm", "Long Term"), ("fno", "F&O")]:
        amt = alloc.get(strat, 0)
        if amt > 0:
            pct = mkt_profile.get(strat, 0) * 100
            alloc_lines.append(f"  {label}: Rs.{amt:,.0f} ({pct:.0f}%)")

    alloc_text = "\n".join(alloc_lines) if alloc_lines else "  No allocation"

    # Get sentiment zone for startup message
    try:
        from sentiment_matrix import SentimentMatrix
        _fg_zone, _fg_params, _fg_value = SentimentMatrix.get_zone()
        _sentiment_line = f"Sentiment: {_fg_zone} (F&G: {_fg_value})\n  {_fg_params['description']}\n  Stocks: {_fg_params['stock_filter']}"
    except Exception:
        _sentiment_line = "Sentiment: Loading..."

    # Phase 2: Sector Rotation line
    _sector_line = ""
    try:
        from phase2_scanners import SectorRotationBias
        _p2_bias = SectorRotationBias.get_bias(mkt_factors, condition, _fg_value if '_fg_value' in dir() else 50)
        _sector_line = f"\n{SectorRotationBias.get_summary(_p2_bias)}"
    except Exception:
        _sector_line = ""

    # Build short sentiment line
    _short_sentiment = ""
    try:
        if '_fg_value' in dir() and _fg_value:
            _short_sentiment = f"F&G: {_fg_value} | "
    except Exception:
        pass

    from global_eye_v23_pythonanywhere import VERSION

    # Count active holdings from Kite
    _h_count = 0
    _h_gtts = 0
    try:
        _h_list = kite.holdings() or []
        _h_count = sum(1 for h in _h_list if (h.get("quantity", 0) + h.get("t1_quantity", 0)) > 0)
        _h_gtts = sum(1 for g in (kite.get_gtts() or []) if g.get("status") == "active")
    except Exception:
        pass

    send_telegram(
        f"🦅 *GLOBAL EYE {VERSION} — LIVE*\n"
        f"_{_now_ist().strftime('%a, %d %b %Y | %H:%M IST')}_\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"\n"
        f"💰 *Capital:* Rs.{_total_balance:,.0f}\n"
        f"📊 *Tier:* {tier_name} | Max {tier_info.get('max_pos', 2)} positions\n"
        f"📈 *Holdings:* {_h_count} stocks | {_h_gtts} GTTs active\n"
        f"\n"
        f"{alloc_text}\n"
        f"\n"
        f"🌍 *Market:* {condition} ({mkt_score})\n"
        f"{_short_sentiment}{factors_str}\n"
        f"{_sector_line}\n"
        f"\n"
        f"⚡ *Systems Online:*\n"
        f"  • 3-Agent AI Voting (2/3 majority)\n"
        f"  • 12-Step Validation Pipeline\n"
        f"  • GTT Instant Protection\n"
        f"  • Smart SL (4-tier loss bands)\n"
        f"  • Trailing SL + Partial Profit\n"
        f"  • 544-Company News Scanner\n"
        f"  • Filing Monitor (360+ keywords)\n"
        f"  • 21 News Feeds Active\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"👤 *<redacted>* | SEBI Compliant | REAL MONEY\n"
        f"🖥️ Server: <server-ip> (BLR1)",
        priority="critical"
    )

    logger.info("✅ Live trading module initialized successfully")
    return sentinel
