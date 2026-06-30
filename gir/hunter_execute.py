#!/usr/bin/env python3
"""
hunter_execute.py — Daily morning order placer for GIR-HUNTER.

Runs every trading day at 09:30 IST (after scan at 08:30 IST).

Logic:
  1. Calendar gate (no-op on holidays/weekends)
  2. Load fresh watchlist (top 20 from morning scan)
  3. Read current HUNTER positions from Kite — count occupied slots
  4. Compute open slots (MAX_HUNTER_SLOTS - occupied)
  5. For each watchlist pick, fetch LIVE Kite quote:
       - today's open
       - current LTP
       - prev close
  6. Filter out picks that have already moved:
       - gap_open vs prev_close > EXECUTE_MAX_GAP_PCT  → skip (built-up)
       - LTP vs today's open > EXECUTE_MAX_INTRADAY_PCT → skip (running)
  7. Re-score the survivors with TODAY's intraday-aware composite
  8. Skip if Hunter already holds the symbol
  9. Skip if gir.py already holds it (Hunter wins NEW picks, doesn't override holds)
 10. Take top-N of survivors where N = open_slots
 11. For each: place LIMIT BUY @ LTP × 1.005, tag=HUNTER, CNC
 12. After fills, place GTT SL at entry × 0.975
 13. Append to hunter_positions.jsonl (entry_date, entry_price, qty, expected exit date)
 14. Telegram summary

Author: GIR-HUNTER v1.0
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys

# ============================================================================
# PAPER MODE (Phase 2A 2026-05-21) — every kite.place_order / place_gtt /
# modify_gtt routes through paper_trader.py when PAPER_MODE=True.
# If paper_trader import fails, PAPER_MODE defaults to False and a loud
# warning prints. Bot then behaves as before.
# ============================================================================
sys.path.insert(0, '/home/globalbot/paper')
try:
    from paper_trader import (
        PAPER_MODE,
        record_event,
        paper_place_order,
        paper_place_gtt,
        paper_modify_gtt,
        paper_cancel_gtt,
        paper_record_exit,
        paper_gemini_call,
    )
except Exception as _paper_e:
    PAPER_MODE = False
    print(f"[PAPER_TRADER IMPORT FAILED] {_paper_e} — bot in LIVE mode!", file=sys.stderr)
import time
import traceback
from dataclasses import dataclass, asdict
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

import requests
from dotenv import load_dotenv
from kiteconnect import KiteConnect

sys.path.insert(0, str(Path(__file__).parent))
from hunter_config import (
    MAX_HUNTER_SLOTS, CAPITAL_PER_SLOT, SAFETY_CAPITAL_CAP,
    ORDER_TAG, ENTRY_BUFFER_PCT, HARD_SL_PCT, GTT_LIMIT_SLACK_PCT,
    MAX_HOLD_DAYS,
    EXECUTE_MAX_GAP_PCT, EXECUTE_MAX_INTRADAY_PCT, EXECUTE_MIN_COMPOSITE,
    HUNTER_DIR, LOG_DIR, STATE_DIR, WATCHLIST_FILE, POSITIONS_LEDGER,
    ENV_FILE, KITE_TOKEN_FILE, TG_CHANNEL_TAG,
)
from market_calendar import assert_can_place_amo, is_trading_day, now_ist


# ============================================================================
# LOGGING
# ============================================================================

def _setup_logging() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / f"execute_{datetime.now().strftime('%Y%m%d')}.log"
    logger = logging.getLogger("hunter_execute")
    logger.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s")
    fh = logging.FileHandler(log_file)
    fh.setFormatter(fmt)
    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    if not logger.handlers:
        logger.addHandler(fh)
        logger.addHandler(sh)
    return logger


log = _setup_logging()


# ============================================================================
# KITE & TELEGRAM
# ============================================================================

def load_kite() -> KiteConnect:
    load_dotenv(ENV_FILE)
    api_key = os.getenv("KITE_API_KEY")
    if not api_key:
        raise RuntimeError("KITE_API_KEY missing")
    if not KITE_TOKEN_FILE.exists():
        raise RuntimeError(f"{KITE_TOKEN_FILE} missing")
    with open(KITE_TOKEN_FILE) as f:
        token_data = json.load(f)
    access_token = token_data.get("access_token", "")
    if not access_token:
        raise RuntimeError("access_token empty")
    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(access_token)
    return kite


def send_telegram(msg: str) -> None:
    load_dotenv(ENV_FILE)
    token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    chat = os.getenv("TELEGRAM_CHAT_ID", "")
    if not token or not chat:
        log.warning("Telegram skipped — creds missing")
        return
    try:
        r = requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat, "text": msg, "parse_mode": "Markdown"},
            timeout=10,
        )
        if r.status_code == 200:
            log.info("Telegram OK")
        else:
            log.warning(f"Telegram non-200: {r.status_code} {r.text[:200]}")
    except Exception as e:
        log.error(f"Telegram failed: {e}")


# ============================================================================
# DATACLASSES
# ============================================================================

@dataclass
class Pick:
    symbol: str
    composite_morning: float        # from 08:30 scan
    composite_live: float           # re-scored at 09:30 with intraday data
    last_close: float               # prev close
    today_open: float
    ltp: float
    gap_pct: float                  # (open - prev_close) / prev_close × 100
    intraday_pct: float             # (ltp - open) / open × 100
    instrument_token: int

    def passes_execute_filters(self) -> tuple[bool, str]:
        if abs(self.gap_pct) > EXECUTE_MAX_GAP_PCT:
            return (False, f"gap {self.gap_pct:+.2f}% > ±{EXECUTE_MAX_GAP_PCT}%")
        if abs(self.intraday_pct) > EXECUTE_MAX_INTRADAY_PCT:
            return (False, f"intraday {self.intraday_pct:+.2f}% > ±{EXECUTE_MAX_INTRADAY_PCT}%")
        if self.composite_live < EXECUTE_MIN_COMPOSITE:
            return (False, f"live composite {self.composite_live:.1f} < {EXECUTE_MIN_COMPOSITE}")
        return (True, "")


@dataclass
class OrderPlan:
    symbol: str
    qty: int
    entry_limit: float
    sl_trigger: float
    sl_limit: float
    capital_used: float
    instrument_token: int


# ============================================================================
# WATCHLIST + POSITION READ
# ============================================================================

def load_watchlist() -> list[dict]:
    if not WATCHLIST_FILE.exists():
        raise RuntimeError(f"{WATCHLIST_FILE} missing — run hunter_scan.py first")
    with open(WATCHLIST_FILE) as f:
        data = json.load(f)
    picks = data.get("top", [])
    if not picks:
        raise RuntimeError("watchlist 'top' is empty")
    log.info(f"Watchlist: {len(picks)} symbols (scanned {data.get('scan_date')})")
    return picks


def get_kite_position_state(kite: KiteConnect) -> tuple[set[str], set[str]]:
    """
    Returns (hunter_held_symbols, gir_held_symbols).
    Uses Kite order tag to differentiate.

    PATCH_CAP2: in paper mode, read OPEN paper positions from paper_trades DB
    instead of Kite (paper orders never reach Kite, so Kite would report none,
    causing the bot to re-buy names it already holds). Enforces: never hold the
    same share twice.
    """
    if PAPER_MODE:
        try:
            import sqlite3 as _sql
            _c = _sql.connect("/home/globalbot/paper/trades.db", timeout=2)
            _cur = _c.cursor()
            _cur.execute("SELECT symbol, strategy FROM paper_trades WHERE status='OPEN'")
            _rows = _cur.fetchall()
            _c.close()
            _h = set(); _g = set()
            for _sym, _strat in _rows:
                if not _sym:
                    continue
                if (_strat or "").lower() == "hunter":
                    _h.add(_sym)
                else:
                    _g.add(_sym)
            log.info(f"[PATCH_CAP2] paper state: HUNTER holds {len(_h)} {sorted(_h)}, gir holds {len(_g)} {sorted(_g)}")
            return (_h, _g)
        except Exception as _pe:
            log.warning(f"[PATCH_CAP2] paper position read failed, falling back to Kite: {_pe}")
    try:
        orders = kite.orders()
    except Exception as e:
        raise RuntimeError(f"kite.orders() failed: {e}")

    hunter_syms: set[str] = set()
    for o in orders:
        if o.get("tag") == ORDER_TAG and o.get("status") in ("COMPLETE", "OPEN", "TRIGGER PENDING"):
            ts = o.get("tradingsymbol")
            if ts:
                hunter_syms.add(ts)

    try:
        holdings = kite.holdings()
        positions = kite.positions().get("net", [])
    except Exception as e:
        raise RuntimeError(f"kite.holdings() failed: {e}")

    all_held: set[str] = set()
    for h in holdings:
        if int(h.get("quantity", 0)) > 0:
            all_held.add(h.get("tradingsymbol"))
    for p in positions:
        if int(p.get("quantity", 0)) > 0:
            all_held.add(p.get("tradingsymbol"))

    gir_syms = all_held - hunter_syms     # whatever isn't tagged HUNTER = gir.py
    log.info(f"Current state: HUNTER holds {len(hunter_syms)} {sorted(hunter_syms)}, "
             f"gir.py holds {len(gir_syms)} {sorted(gir_syms)}")
    return (hunter_syms, gir_syms)


# ============================================================================
# LIVE RE-SCORING
# ============================================================================

def fetch_live_quote(kite: KiteConnect, instrument_token: int, symbol: str) -> Optional[dict]:
    """Get current LTP, today's open, prev close via kite.quote()."""
    try:
        key = f"NSE:{symbol}"
        q = kite.quote([key])
        if key not in q:
            return None
        data = q[key]
        return {
            "ltp": float(data.get("last_price", 0)),
            "today_open": float(data.get("ohlc", {}).get("open", 0)),
            "prev_close": float(data.get("ohlc", {}).get("close", 0)),
            "today_high": float(data.get("ohlc", {}).get("high", 0)),
            "today_low": float(data.get("ohlc", {}).get("low", 0)),
            "volume": int(data.get("volume", 0)),
        }
    except Exception as e:
        log.debug(f"quote fetch failed for {symbol}: {e}")
        return None


def build_pick_with_live_data(kite: KiteConnect, watchlist_entry: dict) -> Optional[Pick]:
    sym = watchlist_entry["symbol"]
    tok = watchlist_entry.get("instrument_token")
    if not tok:
        # try to resolve via kite.ltp metadata
        try:
            instr = kite.instruments("NSE")
            match = [i for i in instr if i.get("tradingsymbol") == sym
                     and i.get("instrument_type") == "EQ"]
            if not match:
                log.debug(f"no Kite token for {sym}")
                return None
            tok = match[0]["instrument_token"]
        except Exception as e:
            log.debug(f"instrument lookup failed for {sym}: {e}")
            return None

    quote = fetch_live_quote(kite, tok, sym)
    if quote is None:
        log.debug(f"no live quote for {sym}")
        return None

    prev_close = quote["prev_close"]
    today_open = quote["today_open"]
    ltp = quote["ltp"]
    if prev_close <= 0 or today_open <= 0 or ltp <= 0:
        log.debug(f"{sym}: invalid quote zeros prev_close={prev_close} open={today_open} ltp={ltp}")
        return None

    gap_pct = (today_open - prev_close) / prev_close * 100.0
    intraday_pct = (ltp - today_open) / today_open * 100.0

    # For composite_live, we'll keep the morning score and just degrade it
    # proportionally to how much the stock has already moved (movement
    # erodes "pre-breakout" status).  Simple penalty: -1 composite point
    # per 1% absolute movement (open-vs-prevclose + ltp-vs-open).
    morning = float(watchlist_entry.get("composite", 0))
    move_penalty = abs(gap_pct) + abs(intraday_pct)
    live_composite = max(0.0, morning - move_penalty)

    return Pick(
        symbol=sym,
        composite_morning=morning,
        composite_live=live_composite,
        last_close=prev_close,
        today_open=today_open,
        ltp=ltp,
        gap_pct=gap_pct,
        intraday_pct=intraday_pct,
        instrument_token=tok,
    )


# ============================================================================
# ORDER PLANNING & PLACEMENT
# ============================================================================

def build_plan(pick: Pick, tick: float = 0.05) -> Optional[OrderPlan]:
    def rt(p: float) -> float:
        return round(round(p / tick) * tick, 2)

    entry = rt(pick.ltp * (1 + ENTRY_BUFFER_PCT / 100))
    qty = int(CAPITAL_PER_SLOT // entry)
    if qty < 1:
        log.warning(f"{pick.symbol}: capital ₹{CAPITAL_PER_SLOT} insufficient for price ₹{entry}")
        return None

    sl_trigger = rt(entry * (1 - HARD_SL_PCT / 100))
    sl_limit = rt(sl_trigger * (1 - GTT_LIMIT_SLACK_PCT / 100))
    capital_used = qty * entry
    return OrderPlan(
        symbol=pick.symbol,
        qty=qty,
        entry_limit=entry,
        sl_trigger=sl_trigger,
        sl_limit=sl_limit,
        capital_used=capital_used,
        instrument_token=pick.instrument_token,
    )


def place_buy(kite: KiteConnect, plan: OrderPlan, dry_run: bool) -> Optional[str]:
    # === BRAIN GATE (added 2026-05-27) =====================================
    # Decision brain - cooldowns + daily cap + drawdown kill for Hunter.
    try:
        import sys
        if "/home/globalbot/paper" not in sys.path:
            sys.path.insert(0, "/home/globalbot/paper")
        from decision_brain import DecisionBrain, Candidate, LayerScore, LAYER_WEIGHTS
        if not hasattr(place_buy, "_brain"):
            place_buy._brain = DecisionBrain(mode="paper")
        _bcand = Candidate(
            symbol=plan.symbol, category="hunter", direction="BULLISH",
            ltp=float(getattr(plan, "entry_limit", 0) or 0), sector="UNKNOWN",
        )
        _hscore = float(getattr(plan, "score", 65) or 65)
        for _n in LAYER_WEIGHTS:
            _bcand.layers[_n] = LayerScore(name=_n, score=_hscore,
                                           supports=_hscore >= 55,
                                           confidence=0.7)
        _bdec = place_buy._brain.decide(_bcand)
        if _bdec.action != "TRADE":
            log.info(f"[BRAIN-HUNTER] BLOCKED {plan.symbol}: {_bdec.reason}")
            return None
        log.info(f"[BRAIN-HUNTER] APPROVED {plan.symbol}: {_bdec.reason}")
    except Exception as _be:
        log.warning(f"[BRAIN-HUNTER] error for {plan.symbol}: {_be}")
    # === END BRAIN GATE ====================================================

    log.info(f"[{'DRY' if dry_run else 'LIVE'}] BUY LIMIT {plan.symbol} qty={plan.qty} "
             f"limit=₹{plan.entry_limit} cap=₹{plan.capital_used:.0f}")
    if PAPER_MODE:
        paper_place_order(
            strategy="hunter",
            signal_source="hunter_live_buy",
            symbol=plan.symbol,
            exchange="NSE",
            product="CNC",
            side="BUY",
            qty=int(plan.qty),
            price=float(plan.entry_limit),
            order_type="LIMIT",
            tag="HUNTER",
            sl_trigger=float(plan.sl_trigger),
            sl_limit=float(plan.sl_limit),
            time_stop_days=5,
            meta={"variety": "REGULAR", "capital_used": float(plan.capital_used), "fn": "hunter_execute.place_buy"},
        )
        return f"PAPER-{plan.symbol}-{int(time.time())}"
    if dry_run:
        return f"DRY-{plan.symbol}-{int(time.time())}"
    try:
        oid = kite.place_order(
            variety=kite.VARIETY_REGULAR,
            exchange=kite.EXCHANGE_NSE,
            tradingsymbol=plan.symbol,
            transaction_type=kite.TRANSACTION_TYPE_BUY,
            quantity=plan.qty,
            product=kite.PRODUCT_CNC,
            order_type=kite.ORDER_TYPE_LIMIT,
            price=plan.entry_limit,
            validity=kite.VALIDITY_DAY,
            tag=ORDER_TAG,
        )
        log.info(f"   ✓ order_id={oid}")
        return oid
    except Exception as e:
        log.error(f"   ✗ place_order failed: {e}")
        return None


def place_gtt_sl(kite: KiteConnect, plan: OrderPlan, dry_run: bool) -> Optional[int]:
    log.info(f"[{'DRY' if dry_run else 'LIVE'}] GTT SL {plan.symbol} qty={plan.qty} "
             f"trig=₹{plan.sl_trigger} limit=₹{plan.sl_limit}")
    if PAPER_MODE:
        paper_place_gtt(
            strategy="hunter",
            symbol=plan.symbol,
            exchange="NSE",
            trigger_value=float(plan.sl_trigger),
            limit_price=float(plan.sl_limit),
            qty=int(plan.qty),
            transaction_type="SELL",
            product="CNC",
            meta={"trigger_type": "single", "fn": "hunter_execute.place_gtt_sl"},
        )
        return -1
    if dry_run:
        return -1
    try:
        last = kite.ltp([f"NSE:{plan.symbol}"])[f"NSE:{plan.symbol}"]["last_price"]
        tid = kite.place_gtt(
            trigger_type=kite.GTT_TYPE_SINGLE,
            tradingsymbol=plan.symbol,
            exchange=kite.EXCHANGE_NSE,
            trigger_values=[plan.sl_trigger],
            last_price=last,
            orders=[{
                "transaction_type": kite.TRANSACTION_TYPE_SELL,
                "quantity": plan.qty,
                "order_type": kite.ORDER_TYPE_LIMIT,
                "product": kite.PRODUCT_CNC,
                "price": plan.sl_limit,
            }],
        )
        log.info(f"   ✓ GTT trigger_id={tid}")
        return tid
    except Exception as e:
        log.error(f"   ✗ GTT failed: {e}")
        return None


def append_position_ledger(plan: OrderPlan, order_id: str, gtt_id: Optional[int]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    rec = {
        "entry_utc": datetime.now(timezone.utc).isoformat(),
        "entry_date_ist": now_ist().date().isoformat(),
        "symbol": plan.symbol,
        "qty": plan.qty,
        "entry_limit": plan.entry_limit,
        "sl_trigger": plan.sl_trigger,
        "sl_limit": plan.sl_limit,
        "capital_used": plan.capital_used,
        "order_id": order_id,
        "gtt_id": gtt_id,
        "status": "PLACED",
    }
    with open(POSITIONS_LEDGER, "a") as f:
        f.write(json.dumps(rec) + "\n")
    log.info(f"Ledger += {plan.symbol}")


# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================

def run(dry_run: bool = True, skip_calendar: bool = False) -> int:
    log.info("=" * 60)
    log.info(f"HUNTER EXECUTE — mode={'DRY-RUN' if dry_run else 'LIVE'}")
    log.info("=" * 60)

    now = now_ist()
    log.info(f"Now (IST): {now.strftime('%Y-%m-%d %H:%M:%S %A')}")

    # 1. Calendar — must be a trading day
    if not skip_calendar:
        if not is_trading_day(now.date()):
            log.info(f"Not a trading day. Exiting cleanly.")
            return 0

    # 2. Kite
    kite = load_kite()
    log.info("Kite OK")
    import sys as _rg_sys, os as _rg_os  # [RG1] shared regime gate
    _rg_sys.path.insert(0, _rg_os.path.expanduser('/home/globalbot'))
    import regime_lite
    _rg = regime_lite.get_regime(kite)
    log.info(f"REGIME: {_rg['regime']} x{_rg['mult']} ({_rg['reason']})")
    if _rg['mult'] <= 0:
        log.info('PANIC regime - no new entries today.')
        return 0

    # 3. Watchlist
    watchlist = load_watchlist()

    # 4. Current state
    hunter_held, gir_held = get_kite_position_state(kite)
    open_slots = MAX_HUNTER_SLOTS - len(hunter_held)
    if _rg['mult'] < 1.0 and open_slots > 1:  # [RG1] BEAR: max 1 new entry/day
        log.info(f'REGIME {_rg["regime"]}: capping new entries to 1 (was {open_slots})')
        open_slots = 1
    log.info(f"Hunter slots: {len(hunter_held)} occupied / {MAX_HUNTER_SLOTS} max → "
             f"{open_slots} open")
    if open_slots <= 0:
        log.info("No open slots. Nothing to do today.")
        return 0

    # 5. Build picks with live data, apply filters
    log.info("-" * 60)
    log.info("Re-scoring watchlist with LIVE intraday data...")
    log.info("-" * 60)
    survivors: list[Pick] = []
    for entry in watchlist:
        sym = entry["symbol"]
        if sym in hunter_held:
            log.info(f"  SKIP {sym}: already in Hunter positions")
            continue
        if sym in gir_held:
            log.info(f"  SKIP {sym}: held by gir.py (conflict, Hunter defers on existing)")
            continue
        pick = build_pick_with_live_data(kite, entry)
        if pick is None:
            log.info(f"  SKIP {sym}: no live quote available")
            continue
        ok, reason = pick.passes_execute_filters()
        if not ok:
            log.info(f"  FILTER {sym}: {reason}  "
                     f"(gap={pick.gap_pct:+.2f}% intraday={pick.intraday_pct:+.2f}% "
                     f"live_score={pick.composite_live:.1f})")
            continue
        survivors.append(pick)
        log.info(f"  PASS {sym}: gap={pick.gap_pct:+.2f}% intra={pick.intraday_pct:+.2f}% "
                 f"morning={pick.composite_morning:.1f} live={pick.composite_live:.1f}")
        time.sleep(0.1)  # gentle rate-limit on quote()

    if not survivors:
        log.warning("No watchlist symbols passed execute-time filters today.")
        send_telegram(f"🎯 *{TG_CHANNEL_TAG}* — No qualifying picks today.\n"
                      f"All watchlist symbols either already moved or in conflict.")
        return 0

    # 6. Rank survivors by live composite, take top open_slots
    survivors.sort(key=lambda p: p.composite_live, reverse=True)
    chosen = survivors[:open_slots]
    log.info(f"Chosen: {[(p.symbol, round(p.composite_live, 1)) for p in chosen]}")

    # 7. Build plans
    plans = [pl for pl in (build_plan(p) for p in chosen) if pl is not None]
    total_cap = sum(pl.capital_used for pl in plans)
    if total_cap > SAFETY_CAPITAL_CAP:
        log.error(f"Total capital ₹{total_cap:.0f} > safety cap ₹{SAFETY_CAPITAL_CAP}")
        return 2
    log.info(f"Plans built: {len(plans)} orders, total capital ₹{total_cap:.0f}")

    # 8. Place orders
    log.info("-" * 60)
    log.info("Placing orders...")
    log.info("-" * 60)
    placed: list[tuple[OrderPlan, str, Optional[int]]] = []
    for pl in plans:
        oid = place_buy(kite, pl, dry_run)
        if not oid:
            continue
        # Note: GTT SL is placed AFTER fill in the manage cycle, not here.
        # Reason: if BUY hasn't filled, we have no qty to sell on SL.
        # hunter_manage.py at next 16:00 IST will check fills and place GTTs.
        placed.append((pl, oid, None))
        append_position_ledger(pl, oid, None)
        time.sleep(0.4)

    # 9. Telegram summary
    if placed:
        lines = [f"🎯 *{TG_CHANNEL_TAG}* — Orders placed",
                 f"_{now.strftime('%a %d-%b %H:%M IST')}_",
                 ""]
        for pl, oid, _ in placed:
            lines.append(f"`{pl.symbol:<13s}  qty {pl.qty:>3d}  @ ₹{pl.entry_limit:.2f}  "
                         f"SL ₹{pl.sl_trigger:.2f}`")
        lines.append("")
        lines.append(f"_Mode: {'DRY-RUN' if dry_run else 'LIVE'}_")
        send_telegram("\n".join(lines))

    log.info("=" * 60)
    log.info(f"EXECUTE complete: {len(placed)} order(s) placed.")
    log.info("=" * 60)
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Daily Hunter order placer")
    parser.add_argument("--live", action="store_true", help="Place real orders")
    parser.add_argument("--skip-calendar", action="store_true",
                        help="Override calendar gate (for testing)")
    args = parser.parse_args()
    sys.exit(run(dry_run=not args.live, skip_calendar=args.skip_calendar))
