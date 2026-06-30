#!/usr/bin/env python3
"""
GIR-HUNTER Executor — places live orders for top-3 Hunter picks.

Capital: ₹30,000 across 3 slots (₹10k each)
Order tag: "HUNTER" (distinguishes from gir.py orders in Kite)
Strategy:
  - AMO orders placed Sunday night for Monday open
  - Limit price = Friday close + 1.5% (allows quiet open fills, blocks gap-up chase)
  - 5-day max hold (managed by hunter_manager.py, separate)
  - 2.5% hard SL via GTT immediately after fill

CRITICAL SAFETY GATES:
  1. Refuses to run if Hunter already has 3+ open positions
  2. Refuses to run if total Hunter exposure exceeds ₹35k (capital cap)
  3. Refuses if any of the 3 picks are already in gir.py positions (conflict)
  4. Dry-run mode by default — must pass --live to actually place orders
  5. AMO mode only outside market hours (08:00 - 09:08 IST Sunday/weekday-eve)

Author: GIR-HUNTER v0.3 (executor)
Date: May 16 2026
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
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from kiteconnect import KiteConnect

# v0.4 — calendar awareness
sys.path.insert(0, str(Path(__file__).parent))
from market_calendar import assert_can_place_amo, is_trading_day, now_ist  # noqa: E402


# ============================================================================
# CONFIG
# ============================================================================

HUNTER_DIR        = Path("/home/globalbot/hunter")
STATE_DIR         = HUNTER_DIR / "state"
WATCHLIST_TODAY   = STATE_DIR / "watchlist_today.json"
LOG_DIR           = HUNTER_DIR / "logs"

ENV_FILE          = "/home/globalbot/.env"
KITE_TOKEN_FILE   = Path("/home/globalbot/data/kite_token.json")

ORDER_TAG         = "HUNTER"        # 20-char Kite limit, this is 6 chars
CAPITAL_PER_SLOT  = 10_000.0        # ₹10k per stock
MAX_SLOTS         = 3
MAX_TOTAL_EXPOSURE = 35_000.0       # safety cap (slightly above 3×10k)
ENTRY_BUFFER_PCT  = 1.5             # limit price = close × 1.015
HARD_SL_PCT       = 2.5             # GTT SL = entry × 0.975
MAX_GAP_UP_PCT    = 5.0             # reject pick if it gapped >5% before we even place AMO


# ============================================================================
# LOGGING
# ============================================================================

def _setup_logging() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / f"executor_{datetime.now().strftime('%Y%m%d')}.log"
    logger = logging.getLogger("hunter_executor")
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
# KITE LOAD (mirrors hunter.py / gir.py)
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


# ============================================================================
# DATACLASSES
# ============================================================================

@dataclass
class HunterPick:
    symbol: str
    last_close: float
    composite: float
    rank: int

    @classmethod
    def from_watchlist_entry(cls, entry: dict, rank: int) -> "HunterPick":
        return cls(
            symbol=entry["symbol"],
            last_close=float(entry["last_close"]),
            composite=float(entry["composite"]),
            rank=rank,
        )


@dataclass
class OrderPlan:
    symbol: str
    qty: int
    entry_limit: float
    sl_trigger: float
    sl_limit: float
    capital_used: float


# ============================================================================
# WATCHLIST LOADER
# ============================================================================

def load_watchlist(top_n: int = MAX_SLOTS) -> list[HunterPick]:
    if not WATCHLIST_TODAY.exists():
        raise RuntimeError(f"{WATCHLIST_TODAY} missing — run hunter.py first")
    with open(WATCHLIST_TODAY) as f:
        data = json.load(f)
    picks_raw = data.get("top", [])[:top_n]
    if not picks_raw:
        raise RuntimeError("watchlist_today.json has empty 'top' array")
    return [HunterPick.from_watchlist_entry(p, rank=i + 1) for i, p in enumerate(picks_raw)]


# ============================================================================
# SAFETY CHECKS
# ============================================================================

def safety_check_existing_hunter_positions(kite: KiteConnect) -> tuple[int, float]:
    """
    Count existing HUNTER-tagged positions and their total exposure.
    Returns (n_positions, total_value).
    """
    try:
        orders = kite.orders()
    except Exception as e:
        raise RuntimeError(f"Cannot fetch orders for safety check: {e}")

    hunter_syms = set()
    for o in orders:
        if o.get("tag") == ORDER_TAG and o.get("status") in ("COMPLETE", "OPEN", "TRIGGER PENDING"):
            hunter_syms.add(o.get("tradingsymbol"))

    if not hunter_syms:
        return (0, 0.0)

    try:
        positions = kite.positions().get("net", [])
        holdings = kite.holdings()
    except Exception as e:
        raise RuntimeError(f"Cannot fetch positions/holdings: {e}")

    total_value = 0.0
    count = 0
    for h in holdings:
        if h.get("tradingsymbol") in hunter_syms and int(h.get("quantity", 0)) > 0:
            total_value += float(h.get("quantity", 0)) * float(h.get("average_price", 0))
            count += 1
    for p in positions:
        if p.get("tradingsymbol") in hunter_syms and int(p.get("quantity", 0)) > 0:
            total_value += float(p.get("quantity", 0)) * float(p.get("average_price", 0))
            count += 1

    return (count, total_value)


def safety_check_gir_conflicts(kite: KiteConnect, picks: list[HunterPick]) -> list[str]:
    """
    Return list of Hunter pick symbols that are already in gir.py's positions.
    These will be SKIPPED (Hunter wins conflict but only for NEW positions).
    Actually: if gir.py already owns it, that's a tie-going-to-incumbent scenario.
    Per Rama's decision: Hunter wins on NEW picks; existing gir.py holds are not
    overridden (we don't want to double-position the same stock).
    """
    try:
        holdings = kite.holdings()
        positions = kite.positions().get("net", [])
    except Exception as e:
        raise RuntimeError(f"Cannot fetch holdings for conflict check: {e}")

    gir_syms = set()
    for h in holdings:
        if int(h.get("quantity", 0)) > 0:
            gir_syms.add(h.get("tradingsymbol"))
    for p in positions:
        if int(p.get("quantity", 0)) > 0:
            gir_syms.add(p.get("tradingsymbol"))

    conflicts = [p.symbol for p in picks if p.symbol in gir_syms]
    return conflicts


def safety_check_funds(kite: KiteConnect, required: float) -> tuple[bool, float]:
    """Verify available cash margin covers required capital."""
    try:
        try:
            import gir as _gir
            if getattr(_gir, "PAPER_MODE", False):
                _pa = _gir._paper_available()
                if _pa is not None:
                    log.info(f"[PATCH_CAP1] Hunter paper available (shared cap) = Rs.{_pa:.0f}")
                    return (_pa >= required, _pa)
        except Exception as _ce:
            log.warning(f"[PATCH_CAP1] paper-avail fallback: {_ce}")
        margins = kite.margins(segment="equity")
        available = float(margins.get("available", {}).get("live_balance", 0))
        return (available >= required, available)
    except Exception as e:
        log.error(f"margin fetch failed: {e}")
        return (False, 0.0)


# ============================================================================
# ORDER PLANNING
# ============================================================================

def build_order_plan(pick: HunterPick, tick_size: float = 0.05) -> OrderPlan:
    """
    Compute qty, entry limit, SL trigger/limit for a single pick.
    Limit = close × 1.015 (1.5% buffer, blocks chase)
    Qty   = floor(capital / limit)
    SL trigger = entry × 0.975 (2.5% below)
    SL limit   = trigger × 0.998 (small slack for fill on hit)
    """
    def round_tick(p: float) -> float:
        return round(round(p / tick_size) * tick_size, 2)

    entry_limit = round_tick(pick.last_close * (1 + ENTRY_BUFFER_PCT / 100))
    qty = int(CAPITAL_PER_SLOT // entry_limit)
    if qty < 1:
        raise ValueError(f"{pick.symbol}: capital ₹{CAPITAL_PER_SLOT} too small for price ₹{entry_limit}")

    sl_trigger = round_tick(entry_limit * (1 - HARD_SL_PCT / 100))
    sl_limit   = round_tick(sl_trigger * 0.998)
    capital_used = qty * entry_limit

    return OrderPlan(
        symbol=pick.symbol,
        qty=qty,
        entry_limit=entry_limit,
        sl_trigger=sl_trigger,
        sl_limit=sl_limit,
        capital_used=capital_used,
    )


# ============================================================================
# ORDER PLACEMENT
# ============================================================================

def place_buy_amo(kite: KiteConnect, plan: OrderPlan, dry_run: bool) -> Optional[str]:
    """Place AMO BUY LIMIT order tagged HUNTER. Returns order_id or None."""
    # === BRAIN GATE (added 2026-05-27) =====================================
    # Decision brain - cooldowns + daily cap + drawdown kill for Hunter.
    try:
        import sys
        if "/home/globalbot/paper" not in sys.path:
            sys.path.insert(0, "/home/globalbot/paper")
        from decision_brain import DecisionBrain, Candidate, LayerScore, LAYER_WEIGHTS
        if not hasattr(place_buy_amo, "_brain"):
            place_buy_amo._brain = DecisionBrain(mode="paper")
        _bcand = Candidate(
            symbol=plan.symbol, category="hunter", direction="BULLISH",
            ltp=float(getattr(plan, "entry_limit", 0) or 0), sector="UNKNOWN",
        )
        _hscore = float(getattr(plan, "score", 65) or 65)
        for _n in LAYER_WEIGHTS:
            _bcand.layers[_n] = LayerScore(name=_n, score=_hscore,
                                           supports=_hscore >= 55,
                                           confidence=0.7)
        _bdec = place_buy_amo._brain.decide(_bcand)
        if _bdec.action != "TRADE":
            log.info(f"[BRAIN-HUNTER] BLOCKED {plan.symbol}: {_bdec.reason}")
            return None
        log.info(f"[BRAIN-HUNTER] APPROVED {plan.symbol}: {_bdec.reason}")
    except Exception as _be:
        log.warning(f"[BRAIN-HUNTER] error for {plan.symbol}: {_be}")
    # === END BRAIN GATE ====================================================

    params = dict(
        variety=kite.VARIETY_AMO,
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
    log.info(f"[{'DRY' if dry_run else 'LIVE'}] AMO BUY {plan.symbol} qty={plan.qty} "
             f"limit=₹{plan.entry_limit} capital=₹{plan.capital_used:.0f}")
    if PAPER_MODE:
        paper_place_order(
            strategy="hunter",
            signal_source="hunter_amo_buy",
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
            meta={"variety": "AMO", "capital_used": float(plan.capital_used), "fn": "executor.place_buy_amo"},
        )
        return f"PAPER-{plan.symbol}-{int(time.time())}"
    if dry_run:
        return f"DRY-{plan.symbol}-{int(time.time())}"
    try:
        order_id = kite.place_order(**params)
        log.info(f"   ✓ order_id={order_id}")
        return order_id
    except Exception as e:
        log.error(f"   ✗ AMO place failed for {plan.symbol}: {e}")
        return None


def place_gtt_sl(kite: KiteConnect, plan: OrderPlan, dry_run: bool) -> Optional[int]:
    """
    Place SINGLE-type GTT for SL after entry fills.
    Per gir.py convention: SINGLE-type, trigger_values=[sl_trigger], limit_price=sl_limit.
    This runs AFTER the AMO fills next morning — called by hunter_manager.py.
    Returns trigger_id or None.
    """
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
            meta={"trigger_type": "single", "fn": "executor.place_gtt_sl"},
        )
        return -1
    if dry_run:
        return -1
    try:
        last_price = kite.ltp([f"NSE:{plan.symbol}"])[f"NSE:{plan.symbol}"]["last_price"]
        trigger_id = kite.place_gtt(
            trigger_type=kite.GTT_TYPE_SINGLE,
            tradingsymbol=plan.symbol,
            exchange=kite.EXCHANGE_NSE,
            trigger_values=[plan.sl_trigger],
            last_price=last_price,
            orders=[{
                "transaction_type": kite.TRANSACTION_TYPE_SELL,
                "quantity": plan.qty,
                "order_type": kite.ORDER_TYPE_LIMIT,
                "product": kite.PRODUCT_CNC,
                "price": plan.sl_limit,
            }],
        )
        log.info(f"   ✓ GTT trigger_id={trigger_id}")
        return trigger_id
    except Exception as e:
        log.error(f"   ✗ GTT place failed for {plan.symbol}: {e}")
        return None


# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================

def run(dry_run: bool = True, place_sl_now: bool = False, skip_fund_check: bool = False) -> int:
    log.info("=" * 60)
    log.info(f"HUNTER EXECUTOR starting — mode={'DRY-RUN' if dry_run else 'LIVE'}")
    log.info("=" * 60)

    # v0.4 — Calendar gate: refuse if AMO window closed
    now = now_ist()
    log.info(f"Now (IST): {now.strftime('%Y-%m-%d %H:%M:%S %A')}")
    try:
        target_day = assert_can_place_amo(now)
        log.info(f"AMO target trading day: {target_day} ({target_day.strftime('%A')})")
    except RuntimeError as e:
        log.error(str(e))
        return 1

    # On non-trading days Kite live_balance reads 0 — auto-skip fund check
    if not is_trading_day(now.date()):
        log.warning("Non-trading day: Kite margins will show ₹0 (funds settle Monday).")
        log.warning("Auto-enabling --skip-fund-check for AMO placement on non-trading day.")
        skip_fund_check = True

    kite = load_kite()
    log.info("Kite OK")

    # 1. Load watchlist
    picks = load_watchlist(top_n=MAX_SLOTS)
    log.info(f"Top-{MAX_SLOTS} watchlist picks:")
    for p in picks:
        log.info(f"  #{p.rank} {p.symbol:<14s} composite={p.composite:5.1f} close=₹{p.last_close}")

    # 2. Safety: existing Hunter positions
    existing_n, existing_val = safety_check_existing_hunter_positions(kite)
    log.info(f"Existing HUNTER positions: {existing_n}, value ₹{existing_val:.0f}")
    available_slots = MAX_SLOTS - existing_n
    if available_slots <= 0:
        log.warning(f"Already at MAX_SLOTS={MAX_SLOTS}. Nothing to do.")
        return 0
    picks = picks[:available_slots]
    log.info(f"Will place {len(picks)} new order(s)")

    # 3. Build plans
    plans = [build_order_plan(p) for p in picks]
    total_capital = sum(pl.capital_used for pl in plans) + existing_val
    log.info(f"Planned new capital ₹{sum(pl.capital_used for pl in plans):.0f}  "
             f"total Hunter exposure after fills ≈ ₹{total_capital:.0f}")
    if total_capital > MAX_TOTAL_EXPOSURE:
        log.error(f"Total exposure ₹{total_capital:.0f} > MAX_TOTAL_EXPOSURE ₹{MAX_TOTAL_EXPOSURE}")
        return 2

    # 4. Safety: gir.py conflicts
    conflicts = safety_check_gir_conflicts(kite, picks)
    if conflicts:
        log.warning(f"Conflict with gir.py existing positions: {conflicts} — these will be SKIPPED")
        plans = [pl for pl in plans if pl.symbol not in conflicts]
        if not plans:
            log.warning("All picks conflict with gir.py — nothing left to place")
            return 0

    # 5. Safety: funds (skippable on non-trading days)
    required = sum(pl.capital_used for pl in plans)
    if skip_fund_check:
        log.warning(f"Fund check SKIPPED (non-trading-day mode). Required ₹{required:.0f}")
        log.warning("Funds will be validated by Kite at AMO submission and Monday morning.")
    else:
        ok, available = safety_check_funds(kite, required)
        log.info(f"Funds required ₹{required:.0f}  available ₹{available:.0f}")
        if not ok:
            log.error(f"Insufficient funds")
            return 3

    # 6. Place orders
    log.info("-" * 60)
    log.info(f"Placing {len(plans)} AMO BUY order(s)...")
    log.info("-" * 60)
    placed_orders = []
    for pl in plans:
        order_id = place_buy_amo(kite, pl, dry_run)
        if order_id:
            placed_orders.append((pl, order_id))
        time.sleep(0.5)

    # 7. Optionally place GTT SL (only after fills happen — usually next morning)
    if place_sl_now:
        log.info("Placing GTT SLs immediately (use only after AMO fills)")
        for pl, _ in placed_orders:
            place_gtt_sl(kite, pl, dry_run)
            time.sleep(0.5)

    # 8. Persist order log
    out = {
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "mode": "dry-run" if dry_run else "live",
        "orders": [
            {
                "symbol": pl.symbol,
                "qty": pl.qty,
                "entry_limit": pl.entry_limit,
                "sl_trigger": pl.sl_trigger,
                "sl_limit": pl.sl_limit,
                "capital_used": pl.capital_used,
                "order_id": oid,
            }
            for pl, oid in placed_orders
        ],
    }
    out_file = STATE_DIR / f"executor_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    with open(out_file, "w") as f:
        json.dump(out, f, indent=2)
    log.info(f"Order log written: {out_file}")

    log.info("=" * 60)
    log.info(f"EXECUTOR complete. Placed {len(placed_orders)} order(s).")
    log.info("=" * 60)
    return 0


# ============================================================================
# CLI
# ============================================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Hunter live executor")
    parser.add_argument("--live", action="store_true",
                        help="Actually place orders (default: dry-run)")
    parser.add_argument("--place-sl-now", action="store_true",
                        help="Also place GTT SLs now (use only after AMO has filled)")
    parser.add_argument("--skip-fund-check", action="store_true",
                        help="Skip Kite live_balance check (auto-enabled on non-trading days)")
    args = parser.parse_args()
    sys.exit(run(dry_run=not args.live, place_sl_now=args.place_sl_now,
                 skip_fund_check=args.skip_fund_check))
