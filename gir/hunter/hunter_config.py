"""
hunter_config.py — Single source of truth for all Hunter constants.

Imported by hunter_scan, hunter_execute, hunter_manage so any change
propagates correctly across the daily pipeline.
"""

from __future__ import annotations
from pathlib import Path


# ============================================================================
# CAPITAL & SLOTS
# ============================================================================

MAX_HUNTER_SLOTS       = 5              # V209: was 4, 5x5x5 rebalance (concurrent HUNTER positions)
CAPITAL_PER_SLOT       = 8_000.0        # V209: was 10_000, slot-size reduced for 5-slot expansion (₹8k per slot)
TOTAL_HUNTER_CAPITAL   = 40_000.0       # V209: unchanged (5 × 8_000 = 40_000); MAX_HUNTER_SLOTS × CAPITAL_PER_SLOT
SAFETY_CAPITAL_CAP     = 45_000.0       # hard refuse if computed > this


# ============================================================================
# ORDER PARAMETERS
# ============================================================================

ORDER_TAG              = "HUNTER"       # Kite tag, distinguishes from gir.py
ENTRY_BUFFER_PCT       = 0.5            # limit = LTP × (1 + 0.005) — tight
HARD_SL_PCT            = 6.0   # P3 2026-05-21: 2.5 -> 6.0
GTT_LIMIT_SLACK_PCT    = 0.2            # SL limit = trigger × (1 - 0.002)

# Trailing SL discipline (replaces fixed TP)
# Logic: every new peak ratchets SL up to (peak × (1 - TRAIL_OFFSET_PCT/100)).
# SL only moves UP, never down. Exit happens when price hits the trailed SL
# (via GTT) or on Day-5 timeout.
TRAIL_OFFSET_PCT       = 3.0            # SL stays 3% below peak
MAX_HOLD_DAYS          = 10              # V218: was 5, extended to 10 for accumulation window (2026-05-20)


# ============================================================================
# EXECUTE-TIME FILTERS  (applied to watchlist picks at 09:30 IST)
# ============================================================================

# Skip pick if today's open has already moved more than this (in either direction)
# vs yesterday's close. Built-up stocks fail this gate.
EXECUTE_MAX_GAP_PCT    = 2.0

# Skip pick if current LTP at execution time is more than this from today's open
# (catches mid-morning runners that opened flat then spiked)
EXECUTE_MAX_INTRADAY_PCT = 1.5

# Re-score gate: pick must still have composite >= this at execute time
EXECUTE_MIN_COMPOSITE  = 60.0


# ============================================================================
# SCAN PARAMETERS
# ============================================================================

SCAN_HISTORICAL_DAYS   = 90
SCAN_TOP_N             = 20             # how many picks to publish/store
SCAN_MIN_PRICE         = 50.0
SCAN_MIN_TURNOVER      = 20_000_000     # ₹2cr daily turnover
KITE_RATE_SLEEP        = 0.35           # 3 req/sec under Kite's historical limit
NIFTY_TOKEN            = 256265


# ============================================================================
# PATHS
# ============================================================================

HUNTER_DIR             = Path("/home/globalbot/hunter")
LOG_DIR                = HUNTER_DIR / "logs"
STATE_DIR              = HUNTER_DIR / "state"
WATCHLIST_FILE         = STATE_DIR / "watchlist_today.json"
PAPER_BOOK             = STATE_DIR / "paper_book.jsonl"
POSITIONS_LEDGER       = STATE_DIR / "hunter_positions.jsonl"   # append-only

ENV_FILE               = "/home/globalbot/.env"
KITE_TOKEN_FILE        = Path("/home/globalbot/data/kite_token.json")
TRENDLYNE_CSV          = Path("/home/globalbot/trendlyne_data/trendlyne_all_stocks.csv")


# ============================================================================
# CHANNELS  (Telegram — load token/chat from .env at runtime)
# ============================================================================

TG_CHANNEL_TAG         = "GIR-HUNTER"

# ============================================================================
# V211 — CONSTANTS ADDED 2026-05-18 to fix ImportError in hunter_execute.py
# ============================================================================

PROFIT_TARGET_PCT              = 15.0   # V212: was 5.0 — momentum stocks need room
INITIAL_SL_PCT                 = 6.0   # P3 2026-05-21: 2.5 -> 6.0

# ============================================================================
# V212 — ADAPTIVE TRAIL (2026-05-18)
# Pattern B: trail offset varies by profit zone
# Replaces fixed TRAIL_OFFSET_PCT — but TRAIL_OFFSET_PCT kept as fallback
# ============================================================================

# Tier boundaries (profit % from entry) and their trail offsets
TRAIL_TIER_1_MAX     = 3.0    # 0%   to +3%:  tight stop, kill bad entries fast
TRAIL_TIER_1_OFFSET  = 5.0   # P3: 2.5 -> 5.0
TRAIL_TIER_2_MAX     = 7.0    # +3%  to +7%:  give it room past breakeven
TRAIL_TIER_2_OFFSET  = 5.0   # P3: 4.0 -> 5.0
TRAIL_TIER_3_MAX     = 12.0   # +7%  to +12%: full breathing room for momentum
TRAIL_TIER_3_OFFSET  = 5.0

TRAIL_TIER_4_MAX     = 15.0   # +12% to +15%: tighten near target, lock gains
TRAIL_TIER_4_OFFSET  = 4.0   # P3: 3.0 -> 4.0
# Note: profit >= TRAIL_TIER_4_MAX (15%) triggers MARKET exit elsewhere


def compute_adaptive_trail_offset(profit_pct: float) -> float:
    """
    Return trail offset % based on current profit zone.
    Higher profit zones → wider trail (give room) until near target → tighten.
    """
    if profit_pct < TRAIL_TIER_1_MAX:
        return TRAIL_TIER_1_OFFSET
    elif profit_pct < TRAIL_TIER_2_MAX:
        return TRAIL_TIER_2_OFFSET
    elif profit_pct < TRAIL_TIER_3_MAX:
        return TRAIL_TIER_3_OFFSET
    else:
        return TRAIL_TIER_4_OFFSET
