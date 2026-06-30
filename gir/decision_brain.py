"""
decision_brain.py
=================

Central decision brain for GIR bot. Combines 11 independent signal layers
into a single GO/NO-GO decision per candidate symbol.

DESIGN GOALS (set with Rama, May 27 2026):
  1. ADDITIVE only - does not modify any existing scanner code
  2. ONE brain for equity + F&O + Hunter (different thresholds per type)
  3. Top-of-day relative ranking (not hard score threshold) - so bot
     trades the BEST candidate of the day even if scores are modest
  4. Cooldown gates to prevent same-stock-repeats (past failure mode)
  5. Fixed paper capital allocation: Equity ₹80k, F&O ₹40k, Hunter ₹60k
  6. Reads existing layer outputs from gir.py / paper events.db
  7. Logs every decision with full reason trail (for retraining weights)
  8. Conservative: target win rate 45-55%, NOT 70%

USAGE:
    from decision_brain import DecisionBrain

    brain = DecisionBrain(mode='paper')
    decision = brain.decide(candidate)
    if decision.action == 'TRADE':
        # place order with decision.qty, decision.entry, decision.stop
    else:
        # log decision.reason for analysis

INTEGRATION:
    Wire this in front of paper_trader.paper_place_order().
    Existing scan_and_trade() flow stays unchanged - just add ONE call:

        brain_decision = brain.decide(candidate)
        if brain_decision.action != 'TRADE':
            log.info(f"[BRAIN] BLOCKED {sym}: {brain_decision.reason}")
            return
        # else proceed with existing entry logic using brain_decision.qty etc.
"""

import json
import logging
import sqlite3
from dataclasses import dataclass, field, asdict
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Any, Optional
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")
log = logging.getLogger("decision_brain")

# ============================================================================
# CONFIG - all the knobs in one place
# ============================================================================

# Paper trading capital allocation (Option A - aggressive deployment)
PAPER_CAPITAL_TOTAL = 200_000
ALLOCATION = {
    "equity": 80_000,   # 40%
    "fno":    40_000,   # 20%
    "hunter": 60_000,   # 30%
    "buffer": 20_000,   # 10% (untouched)
}

# Maximum trades per day per category (forces best-of-day selection)
DAILY_TRADE_CAPS = {
    "equity": 1,
    "fno":    1,
    "hunter": 1,
}

# Score floors - if best candidate of day is below this, skip the slot
# (genuinely bad day, don't force a trade just to fill the slot)
SCORE_FLOOR = {
    "equity": 50,   # out of 100
    "fno":    55,   # F&O needs higher conviction
    "hunter": 45,   # Hunter is pre-breakout, scores naturally lower
}

# Minimum number of supporting layers (out of 11) required for any TRADE
# Below this, brain refuses entry regardless of score
MIN_SUPPORTING_LAYERS = 3   # PATCH_SCALEFIX: only 6/11 layers wired; 5 hardcoded neutral. 3 = genuine multi-layer agreement.

# Cooldown gates (in trading sessions)
SYMBOL_COOLDOWN_SESSIONS    = 5    # any prior trade on this symbol
LOSS_COOLDOWN_SESSIONS      = 10   # if last trade on symbol was a loss
SECTOR_COOLDOWN_SESSIONS    = 2    # avoid concentration in one sector

# Risk per trade (% of slot capital)
RISK_PCT_PER_TRADE = 0.02   # 2% of slot capital risk per single trade

# Daily kill switch - if portfolio MTM hits this, stop all new entries
DAILY_DRAWDOWN_KILL_PCT = 0.03   # -3% of total capital

# ============================================================================
# LAYER WEIGHTS
# ============================================================================
# These define how much each signal layer contributes to final_score.
# Sum should be ~100. Start conservative; retrain from outcomes after 30 days.
#
# Rationale (May 2026, evidence-based, not theory):
#   - Technical (price action, breakout, VCP) gets highest weight because it's
#     the most direct signal that "this is moving NOW"
#   - Delivery % and OI buildup are institutional footprints - high weight
#   - News/regime are gates (veto) more than triggers - moderate weight
#   - Sector rotation and FII/DII give context - lower weight
#   - Earnings calendar is binary (gate) - low score contribution but high veto
# ============================================================================

LAYER_WEIGHTS = {
    "technical":      18,   # breakout / VCP / momentum / Hunter scorer
    "delivery_pct":   12,   # daily delivery % - institutional accumulation
    "oi_buildup":     11,   # F&O OI buildup, primarily for F&O candidates
    "promoter_inst":  10,   # promoter buys, block/bulk deals, SAST filings
    "fii_dii_flow":    9,   # FII/DII directional bias on this name
    "news_sentiment":  9,   # Gemini / NewsBrain score on recent news
    "regime_filter":   8,   # V28 A10 - market+stock regime gate
    "earnings_window": 7,   # results pre-positioning / blackout
    "sector_rotation": 6,   # top/bottom of sector flows
    "fundamental":     5,   # Trendlyne quality / debt / growth
    "filings_signal":  5,   # NSE/BSE corporate filings catalyst
}
# Sum should equal 100
assert sum(LAYER_WEIGHTS.values()) == 100, "LAYER_WEIGHTS must sum to 100"

# Paths
PAPER_DIR  = Path("/home/globalbot/paper")
EVENTS_DB  = PAPER_DIR / "events.db"
TRADES_DB  = PAPER_DIR / "trades.db"
BRAIN_LOG  = PAPER_DIR / "logs" / f"{datetime.now(IST).strftime('%Y%m%d')}_decision_brain.log"
BRAIN_DB   = PAPER_DIR / "decision_brain.db"

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class LayerScore:
    """One signal layer's output for one candidate."""
    name: str
    score: float                 # 0-100; >50 = bullish, <50 = bearish
    supports: bool               # True if score >= 55 (clearly supportive)
    confidence: float = 1.0      # 0-1; how reliable this layer's read is
    raw: Any = None              # raw underlying value for audit

@dataclass
class Candidate:
    """Input to the brain - one symbol up for decision."""
    symbol: str
    category: str                # 'equity' | 'fno' | 'hunter'
    direction: str               # 'BULLISH' | 'BEARISH'
    ltp: float                   # last traded price
    sector: str = "UNKNOWN"
    # Layer outputs (filled in by brain by calling existing scanners)
    layers: dict[str, LayerScore] = field(default_factory=dict)
    # F&O-specific extras
    underlying: Optional[str] = None
    strike: Optional[float] = None
    expiry: Optional[str] = None
    lot_size: Optional[int] = None

@dataclass
class BrainDecision:
    """Output of the brain - what to do with this candidate."""
    symbol: str
    category: str
    action: str                  # 'TRADE' | 'SKIP' | 'BLOCK'
    final_score: float           # 0-100, weighted combination
    supporting_layers: int       # count of layers with supports=True
    qty: int = 0                 # position size (computed)
    entry: float = 0.0
    stop: float = 0.0
    target: float = 0.0
    reason: str = ""             # human-readable summary
    blockers: list[str] = field(default_factory=list)  # all veto reasons
    layer_scores: dict[str, float] = field(default_factory=dict)
    timestamp: str = ""

# ============================================================================
# DECISION BRAIN
# ============================================================================

class DecisionBrain:
    """
    The central decision authority. Takes a candidate, asks all 11 layers,
    combines their answers, applies risk + cooldown gates, returns one
    GO/NO-GO decision with full reasoning.
    """

    def __init__(self, mode: str = "paper", kite=None):
        """
        mode: 'paper' (uses fixed capital) or 'live' (reads kite.margins())
        kite: KiteConnect client - required for 'live' mode for margin reads
        """
        if mode not in ("paper", "live"):
            raise ValueError(f"mode must be 'paper' or 'live', got {mode}")
        self.mode = mode
        self.kite = kite
        self._ensure_brain_db()
        log.info(f"DecisionBrain initialized in {mode} mode")

    # --- public API -------------------------------------------------------

    def decide(self, candidate: Candidate) -> BrainDecision:
        """Main entry point. Given a candidate, return one decision."""
        now = datetime.now(IST)
        dec = BrainDecision(
            symbol=candidate.symbol,
            category=candidate.category,
            action="SKIP",
            final_score=0.0,
            supporting_layers=0,
            timestamp=now.isoformat(),
        )

        # ===== Stage 1: hard blockers (vetoes) =====
        block_reason = self._check_hard_blockers(candidate, now)
        if block_reason:
            dec.action = "BLOCK"
            dec.reason = block_reason
            dec.blockers.append(block_reason)
            self._log_decision(dec)
            return dec

        # ===== Stage 2: collect all 11 layer scores =====
        # Layers should already be populated by caller via collect_layers()
        # (we don't compute them inside brain to keep brain pure & testable)
        if not candidate.layers:
            dec.action = "BLOCK"
            dec.reason = "no_layers_provided"
            dec.blockers.append("no_layers_provided")
            self._log_decision(dec)
            return dec

        # ===== Stage 3: compute final score (weighted combination) =====
        final_score, supporting = self._compute_final_score(candidate)
        dec.final_score = final_score
        dec.supporting_layers = supporting
        dec.layer_scores = {n: round(s.score, 1) for n, s in candidate.layers.items()}

        # ===== Stage 4: gate on score floor & minimum supporting layers =====
        floor = SCORE_FLOOR[candidate.category]
        if final_score < floor:
            dec.action = "SKIP"
            dec.reason = f"score_below_floor ({final_score:.1f} < {floor})"
            dec.blockers.append(dec.reason)
            self._log_decision(dec)
            return dec

        if supporting < MIN_SUPPORTING_LAYERS:
            dec.action = "SKIP"
            dec.reason = (f"only_{supporting}_supporting_layers "
                          f"(need {MIN_SUPPORTING_LAYERS})")
            dec.blockers.append(dec.reason)
            self._log_decision(dec)
            return dec

        # ===== Stage 5: daily-cap & best-of-day check =====
        cap_block = self._check_daily_cap(candidate)
        if cap_block:
            dec.action = "BLOCK"
            dec.reason = cap_block
            dec.blockers.append(cap_block)
            self._log_decision(dec)
            return dec

        # ===== Stage 6: position sizing =====
        qty, entry, stop, target = self._size_position(candidate, final_score)
        if qty <= 0:
            dec.action = "SKIP"
            dec.reason = "position_size_zero (capital or lot constraint)"
            dec.blockers.append(dec.reason)
            self._log_decision(dec)
            return dec

        # ===== Stage 7: APPROVED =====
        dec.action = "TRADE"
        dec.qty = qty
        dec.entry = entry
        dec.stop = stop
        dec.target = target
        dec.reason = (f"score={final_score:.1f} supporting={supporting}/11 "
                      f"qty={qty} entry={entry} stop={stop}")
        self._log_decision(dec)
        return dec

    def decide_best_of_day(self, candidates: list[Candidate]) -> list[BrainDecision]:
        """
        When multiple candidates exist in a category, evaluate all, sort by
        final_score, and only TRADE the top one per category (subject to caps).
        The rest get SKIP with reason 'not_best_of_day'.
        Returns list of decisions in original candidate order.
        """
        # First pass: get tentative decision for each WITHOUT committing to DB
        # (we use _decide_dry which skips the daily-cap check and skips logging)
        tentative = [(c, self._decide_dry(c)) for c in candidates]

        # Group by category and find best per category
        by_cat: dict[str, list[tuple]] = {}
        for c, d in tentative:
            by_cat.setdefault(c.category, []).append((c, d))

        winners_per_cat: dict[str, str] = {}
        for cat, items in by_cat.items():
            # Only consider items that came back TRADE (passed all gates except cap)
            tradeable = [(c, d) for c, d in items if d.action == "TRADE"]
            if not tradeable:
                continue
            tradeable.sort(key=lambda x: x[1].final_score, reverse=True)
            winners_per_cat[cat] = tradeable[0][0].symbol

        # Second pass: now run real decide() ONLY on the winners
        # Everything else gets a SKIP/BLOCK that gets persisted
        final_decisions = []
        for c, d in tentative:
            if winners_per_cat.get(c.category) == c.symbol:
                # This is the winner - run real decide() which commits
                real = self.decide(c)
                final_decisions.append(real)
            else:
                # Mark as not-best-of-day and persist
                if d.action == "TRADE":
                    d.action = "SKIP"
                    winner = winners_per_cat.get(c.category, "none")
                    d.reason = (f"not_best_of_day (winner={winner}, "
                                f"my_score={d.final_score:.1f})")
                self._log_decision(d)
                final_decisions.append(d)
        return final_decisions

    def _decide_dry(self, candidate: Candidate) -> BrainDecision:
        """Internal: like decide() but doesn't check daily_cap and doesn't
        write to DB. Used by decide_best_of_day for the tentative pass."""
        now = datetime.now(IST)
        dec = BrainDecision(
            symbol=candidate.symbol,
            category=candidate.category,
            action="SKIP",
            final_score=0.0,
            supporting_layers=0,
            timestamp=now.isoformat(),
        )

        block_reason = self._check_hard_blockers(candidate, now)
        if block_reason:
            dec.action = "BLOCK"
            dec.reason = block_reason
            return dec

        if not candidate.layers:
            dec.action = "BLOCK"
            dec.reason = "no_layers_provided"
            return dec

        final_score, supporting = self._compute_final_score(candidate)
        dec.final_score = final_score
        dec.supporting_layers = supporting
        dec.layer_scores = {n: round(s.score, 1) for n, s in candidate.layers.items()}

        floor = SCORE_FLOOR[candidate.category]
        if final_score < floor:
            dec.action = "SKIP"
            dec.reason = f"score_below_floor ({final_score:.1f} < {floor})"
            return dec

        if supporting < MIN_SUPPORTING_LAYERS:
            dec.action = "SKIP"
            dec.reason = (f"only_{supporting}_supporting_layers "
                          f"(need {MIN_SUPPORTING_LAYERS})")
            return dec

        # Note: skip daily cap check here (that's for second pass)

        qty, entry, stop, target = self._size_position(candidate, final_score)
        if qty <= 0:
            dec.action = "SKIP"
            dec.reason = "position_size_zero (capital or lot constraint)"
            return dec

        dec.action = "TRADE"
        dec.qty = qty
        dec.entry = entry
        dec.stop = stop
        dec.target = target
        dec.reason = (f"score={final_score:.1f} supporting={supporting}/11 "
                      f"qty={qty} entry={entry} stop={stop}")
        return dec

    # --- internal: hard blockers (cooldowns, kill-switch, holding) -------

    def _check_hard_blockers(self, c: Candidate, now: datetime) -> Optional[str]:
        """Returns blocker reason string, or None if clear to proceed."""

        # Daily portfolio kill-switch
        if self._daily_drawdown_breached():
            return f"daily_kill_switch (>{DAILY_DRAWDOWN_KILL_PCT*100:.1f}% loss)"

        # Already holding this symbol?
        if self._is_currently_held(c.symbol):
            return "already_holding"

        # Recent trade on this symbol?
        last_trade = self._last_trade_session(c.symbol)
        if last_trade is not None and last_trade < SYMBOL_COOLDOWN_SESSIONS:
            return f"symbol_cooldown ({last_trade}/{SYMBOL_COOLDOWN_SESSIONS} sessions)"

        # Recent LOSER on this symbol?
        last_loss = self._last_loss_session(c.symbol)
        if last_loss is not None and last_loss < LOSS_COOLDOWN_SESSIONS:
            return f"loss_cooldown ({last_loss}/{LOSS_COOLDOWN_SESSIONS} sessions)"

        # Sector concentration
        recent_sector = self._sector_traded_recently(c.sector)
        if recent_sector and c.sector != "UNKNOWN":
            return (f"sector_cooldown ({c.sector} traded in last "
                    f"{SECTOR_COOLDOWN_SESSIONS} sessions)")

        return None

    def _daily_drawdown_breached(self) -> bool:
        """Did today's MTM cross the kill-switch threshold?"""
        try:
            conn = sqlite3.connect(str(TRADES_DB))
            cur = conn.cursor()
            today = datetime.now(IST).strftime("%Y-%m-%d")
            cur.execute("""
                SELECT COALESCE(SUM(realized_pnl), 0)
                FROM trades
                WHERE date(closed_at) = ?
            """, (today,))
            row = cur.fetchone()
            conn.close()
            day_pnl = row[0] if row else 0
            return day_pnl < -(PAPER_CAPITAL_TOTAL * DAILY_DRAWDOWN_KILL_PCT)
        except Exception as e:
            log.warning(f"daily_drawdown check failed: {e}")
            return False   # fail-open: if we can't check, allow trade

    def _is_currently_held(self, symbol: str) -> bool:
        """Open paper position on this symbol?"""
        try:
            conn = sqlite3.connect(str(TRADES_DB))
            cur = conn.cursor()
            cur.execute("""
                SELECT 1 FROM trades
                WHERE symbol = ? AND status = 'OPEN'
                LIMIT 1
            """, (symbol,))
            row = cur.fetchone()
            conn.close()
            return row is not None
        except Exception:
            return False

    def _last_trade_session(self, symbol: str) -> Optional[int]:
        """How many trading sessions ago was the last trade on this symbol?
        Returns None if never traded."""
        try:
            conn = sqlite3.connect(str(EVENTS_DB))
            cur = conn.cursor()
            cur.execute("""
                SELECT date(ts_utc) FROM bot_events
                WHERE symbol = ? AND decision = 'BUY'
                ORDER BY ts_utc DESC LIMIT 1
            """, (symbol,))
            row = cur.fetchone()
            conn.close()
            if not row:
                return None
            last_date = datetime.fromisoformat(row[0]).date()
            today = datetime.now(IST).date()
            return self._trading_days_between(last_date, today)
        except Exception:
            return None

    def _last_loss_session(self, symbol: str) -> Optional[int]:
        """Sessions since last LOSING trade on this symbol."""
        try:
            conn = sqlite3.connect(str(TRADES_DB))
            cur = conn.cursor()
            cur.execute("""
                SELECT date(closed_at) FROM trades
                WHERE symbol = ? AND realized_pnl < 0
                ORDER BY closed_at DESC LIMIT 1
            """, (symbol,))
            row = cur.fetchone()
            conn.close()
            if not row:
                return None
            last_loss_date = datetime.fromisoformat(row[0]).date()
            today = datetime.now(IST).date()
            return self._trading_days_between(last_loss_date, today)
        except Exception:
            return None

    def _sector_traded_recently(self, sector: str) -> bool:
        """Was anything in this sector traded in last SECTOR_COOLDOWN_SESSIONS?"""
        if sector == "UNKNOWN":
            return False
        try:
            cutoff = (datetime.now(IST) - timedelta(days=SECTOR_COOLDOWN_SESSIONS*2)).isoformat()
            conn = sqlite3.connect(str(BRAIN_DB))
            cur = conn.cursor()
            cur.execute("""
                SELECT 1 FROM brain_decisions
                WHERE action = 'TRADE' AND sector = ? AND ts_utc > ?
                LIMIT 1
            """, (sector, cutoff))
            row = cur.fetchone()
            conn.close()
            return row is not None
        except Exception:
            return False

    @staticmethod
    def _trading_days_between(d1: date, d2: date) -> int:
        """Count weekdays between two dates (good-enough approximation;
        for true NSE holiday awareness, use market_calendar.is_trading_day)."""
        if d2 < d1:
            return 0
        days = 0
        cur = d1 + timedelta(days=1)
        while cur <= d2:
            if cur.weekday() < 5:   # 0-4 = Mon-Fri
                days += 1
            cur += timedelta(days=1)
        return days

    # --- internal: scoring -----------------------------------------------

    def _compute_final_score(self, c: Candidate) -> tuple[float, int]:
        """
        Combine 11 layer scores into one final_score (0-100).
        Returns (final_score, count_of_supporting_layers).

        Method: weighted average, where each layer's contribution is
        score * weight * confidence. Supports counted separately (binary).
        """
        # PATCH_SCALEFIX: wired scorers emit 0-20 by design (summed to ~100 in
        # ExpertPanel.evaluate_*). This brain reuses them PER-LAYER, so each must be
        # normalized to 0-100 before averaging, and "supporting" recomputed on that
        # normalized scale. Fixes both gates (floor + MIN_SUPPORTING_LAYERS) at the
        # source. Scorers / evaluate_* / SCORE_FLOOR / LAYER_WEIGHTS untouched.
        _LAYER_MAX = {
            "technical": 20.0, "delivery_pct": 100.0, "oi_buildup": 20.0,
            "promoter_inst": 100.0, "fii_dii_flow": 100.0, "news_sentiment": 100.0,
            "regime_filter": 100.0, "earnings_window": 100.0, "sector_rotation": 20.0,
            "fundamental": 20.0, "filings_signal": 20.0,
        }
        weighted_sum = 0.0
        weight_total = 0.0
        supporting = 0
        for layer_name, weight in LAYER_WEIGHTS.items():
            layer = c.layers.get(layer_name)
            if layer is None:
                # Missing layer - neutral (50/100) at low confidence: neither helps nor hurts
                weighted_sum += 50.0 * weight * 0.3
                weight_total += weight * 0.3
                continue
            _mx = _LAYER_MAX.get(layer_name, 100.0)
            norm = (layer.score / _mx) * 100.0 if _mx else layer.score
            if norm < 0: norm = 0.0
            if norm > 100: norm = 100.0
            weighted_sum += norm * weight * layer.confidence
            weight_total += weight * layer.confidence
            # recompute support on normalized 0-100 scale (stale upstream bool ignored)
            if norm >= 55.0:
                supporting += 1
        final = weighted_sum / weight_total if weight_total > 0 else 0
        return round(final, 2), supporting

    # --- internal: daily cap ---------------------------------------------

    def _check_daily_cap(self, c: Candidate) -> Optional[str]:
        """Has today's TRADE cap for this category been hit?"""
        cap = DAILY_TRADE_CAPS.get(c.category, 0)
        today = datetime.now(IST).strftime("%Y-%m-%d")
        try:
            conn = sqlite3.connect(str(BRAIN_DB))
            cur = conn.cursor()
            cur.execute("""
                SELECT COUNT(*) FROM brain_decisions
                WHERE action = 'TRADE' AND category = ? AND date(ts_utc) = ?
            """, (c.category, today))
            row = cur.fetchone()
            conn.close()
            n_today = row[0] if row else 0
            if n_today >= cap:
                return f"daily_cap_reached ({n_today}/{cap} for {c.category})"
        except Exception as e:
            log.warning(f"daily_cap check failed: {e}")
        return None

    # --- internal: position sizing ---------------------------------------

    def _size_position(self, c: Candidate, score: float) -> tuple[int, float, float, float]:
        """
        Decide qty / entry / stop / target.
        Sizing is based on slot capital + risk-per-trade (% of slot).

        For EQUITY: stop = 4% below entry, target = 8% above (2:1 R)
        For F&O:    stop = 25% below premium, target = 50% above (2:1 R)
        For HUNTER: stop = at last contraction low or 6% below, target = 15% above
        """
        slot_capital = ALLOCATION[c.category]
        risk_inr = slot_capital * RISK_PCT_PER_TRADE
        entry = c.ltp

        if c.category == "equity":
            stop = round(entry * 0.96, 2)        # 4% stop
            target = round(entry * 1.08, 2)      # 8% target
            risk_per_share = entry - stop
            if risk_per_share <= 0:
                return 0, entry, stop, target
            qty_by_risk = int(risk_inr / risk_per_share)
            qty_by_cap  = int(slot_capital / entry)
            qty = max(0, min(qty_by_risk, qty_by_cap))
            return qty, entry, stop, target

        elif c.category == "fno":
            stop = round(entry * 0.75, 2)        # -25% premium
            target = round(entry * 1.50, 2)      # +50% premium
            lot_size = c.lot_size or 1
            cost_per_lot = entry * lot_size
            if cost_per_lot <= 0:
                return 0, entry, stop, target
            # Cap by slot capital first
            max_lots_by_cap = int(slot_capital / cost_per_lot)
            if max_lots_by_cap < 1:
                # Slot cannot afford even one lot - genuine skip
                return 0, entry, stop, target
            # If slot affords at least 1 lot, also respect risk limit
            risk_per_lot = (entry - stop) * lot_size
            lots_by_risk = max(1, int(risk_inr / risk_per_lot)) if risk_per_lot > 0 else 1
            lots = min(lots_by_risk, max_lots_by_cap)
            qty = lots * lot_size
            return qty, entry, stop, target

        elif c.category == "hunter":
            stop = round(entry * 0.94, 2)        # 6% stop (Hunter is patient)
            target = round(entry * 1.15, 2)      # 15% target
            risk_per_share = entry - stop
            if risk_per_share <= 0:
                return 0, entry, stop, target
            qty_by_risk = int(risk_inr / risk_per_share)
            qty_by_cap  = int(slot_capital / entry)
            qty = max(0, min(qty_by_risk, qty_by_cap))
            return qty, entry, stop, target

        return 0, entry, 0, 0

    # --- internal: persistence -------------------------------------------

    def _ensure_brain_db(self):
        """Create brain_decisions table if it doesn't exist."""
        BRAIN_DB.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(BRAIN_DB))
        conn.execute("""
            CREATE TABLE IF NOT EXISTS brain_decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts_utc TEXT NOT NULL,
                symbol TEXT NOT NULL,
                category TEXT NOT NULL,
                sector TEXT,
                action TEXT NOT NULL,
                final_score REAL,
                supporting_layers INTEGER,
                qty INTEGER,
                entry REAL,
                stop REAL,
                target REAL,
                reason TEXT,
                blockers TEXT,
                layer_scores TEXT
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_brain_symbol_ts
            ON brain_decisions(symbol, ts_utc)
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_brain_category_ts
            ON brain_decisions(category, ts_utc)
        """)
        conn.commit()
        conn.close()

    def _log_decision(self, dec: BrainDecision, force: bool = False):
        """Persist decision to SQLite + log line."""
        try:
            conn = sqlite3.connect(str(BRAIN_DB))
            conn.execute("""
                INSERT INTO brain_decisions
                (ts_utc, symbol, category, sector, action, final_score,
                 supporting_layers, qty, entry, stop, target,
                 reason, blockers, layer_scores)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                dec.timestamp, dec.symbol, dec.category, None,
                dec.action, dec.final_score, dec.supporting_layers,
                dec.qty, dec.entry, dec.stop, dec.target,
                dec.reason, json.dumps(dec.blockers),
                json.dumps(dec.layer_scores),
            ))
            conn.commit()
            conn.close()
        except Exception as e:
            log.warning(f"brain DB log failed: {e}")

        # Also append to today's log file
        try:
            BRAIN_LOG.parent.mkdir(parents=True, exist_ok=True)
            with open(BRAIN_LOG, "a") as f:
                f.write(json.dumps(asdict(dec)) + "\n")
        except Exception as e:
            log.warning(f"brain log file write failed: {e}")

        # And to stdout for real-time visibility
        emoji = {"TRADE": "✅", "SKIP": "⏭️ ", "BLOCK": "🚫"}.get(dec.action, "?")
        log.info(f"{emoji} [BRAIN] {dec.symbol} ({dec.category}) "
                 f"-> {dec.action} score={dec.final_score:.1f} "
                 f"sup={dec.supporting_layers}/11 reason={dec.reason}")


# ============================================================================
# HELPER: collect layer scores from existing scanners
# ============================================================================
# This is the ADAPTER that bridges existing gir.py / paper code to the brain.
# It calls each existing scanner and packages its output as a LayerScore.
# Implement these stubs by wiring to your real scanner functions.

def collect_layers(candidate: Candidate, gir_instance=None, kite=None) -> Candidate:
    """
    Populate candidate.layers by calling existing scanners in gir.py.

    WIRED VERSION (May 27 2026):
    These 6 scorers are CONFIRMED present in gir.py:
      score_news(self, symbol, direction, scout_data)     # line 6184
      score_fundamental(self, symbol)                     # line 6209
      score_technical(self, kite, symbol, direction)      # line 6215
      score_sector(self, symbol, direction)               # line 6254
      score_history(self, symbol)                         # line 6267
      score_option(self, option_data)                     # line 6281

    These 5 layers are NOT YET WIRED. They get neutral (50) score with
    low confidence (0.3) so they neither help nor hurt:
      - delivery_pct, oi_buildup, promoter_inst, fii_dii_flow,
        earnings_window, filings_signal
      - regime_filter

    To wire a missing layer later: write the scorer in gir.py and add the
    call here.

    NOTE: this is the ONLY place that touches existing code (via gir_instance).
    The brain itself never imports gir.py.
    """
    if gir_instance is None:
        log.warning("collect_layers called without gir_instance - all layers neutral")
        for name in LAYER_WEIGHTS:
            candidate.layers[name] = LayerScore(name=name, score=50.0, supports=False, confidence=0.3)
        return candidate

    # ========================================================================
    # WIRED LAYERS (6) - call your real gir.py scorers
    # ========================================================================

    # === Layer 1: technical (WIRED to gir.score_technical) ===
    try:
        raw = gir_instance.score_technical(kite, candidate.symbol, candidate.direction)
        score = float(raw) if raw is not None else 50.0
        candidate.layers["technical"] = LayerScore(
            name="technical", score=score, supports=score >= 60, raw=raw)
    except Exception as e:
        log.debug(f"score_technical failed for {candidate.symbol}: {e}")
        candidate.layers["technical"] = LayerScore(
            name="technical", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # === Layer 6: news_sentiment (WIRED to gir.score_news) ===
    try:
        raw = gir_instance.score_news(candidate.symbol, candidate.direction, None)
        score = float(raw) if raw is not None else 50.0
        candidate.layers["news_sentiment"] = LayerScore(
            name="news_sentiment", score=score, supports=score >= 60, raw=raw)
    except Exception as e:
        log.debug(f"score_news failed for {candidate.symbol}: {e}")
        candidate.layers["news_sentiment"] = LayerScore(
            name="news_sentiment", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # === Layer 9: sector_rotation (WIRED to gir.score_sector) ===
    try:
        raw = gir_instance.score_sector(candidate.symbol, candidate.direction)
        score = float(raw) if raw is not None else 50.0
        candidate.layers["sector_rotation"] = LayerScore(
            name="sector_rotation", score=score, supports=score >= 55, raw=raw)
    except Exception as e:
        log.debug(f"score_sector failed for {candidate.symbol}: {e}")
        candidate.layers["sector_rotation"] = LayerScore(
            name="sector_rotation", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # === Layer 10: fundamental (WIRED to gir.score_fundamental) ===
    try:
        raw = gir_instance.score_fundamental(candidate.symbol)
        score = float(raw) if raw is not None else 50.0
        candidate.layers["fundamental"] = LayerScore(
            name="fundamental", score=score, supports=score >= 55, raw=raw)
    except Exception as e:
        log.debug(f"score_fundamental failed for {candidate.symbol}: {e}")
        candidate.layers["fundamental"] = LayerScore(
            name="fundamental", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # === Layer 3: oi_buildup - PARTIAL wire to gir.score_option (F&O only) ===
    try:
        # score_option needs option_data dict; only valid for F&O candidates
        if candidate.category == "fno":
            option_data = {
                "symbol": candidate.symbol,
                "direction": candidate.direction,
                "ltp": candidate.ltp,
                "underlying": candidate.underlying,
                "strike": candidate.strike,
            }
            raw = gir_instance.score_option(option_data)
            score = float(raw) if raw is not None else 50.0
        else:
            # Not F&O - oi_buildup is neutral
            score = 50.0
            raw = None
        candidate.layers["oi_buildup"] = LayerScore(
            name="oi_buildup", score=score, supports=score >= 55,
            confidence=1.0 if candidate.category == "fno" else 0.3, raw=raw)
    except Exception as e:
        log.debug(f"score_option failed for {candidate.symbol}: {e}")
        candidate.layers["oi_buildup"] = LayerScore(
            name="oi_buildup", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # === Layer 11: filings_signal - PARTIAL wire via score_history ===
    # score_history covers recent corporate-event memory; use as proxy for
    # filings_signal until a dedicated filings scorer is added.
    try:
        raw = gir_instance.score_history(candidate.symbol)
        score = float(raw) if raw is not None else 50.0
        candidate.layers["filings_signal"] = LayerScore(
            name="filings_signal", score=score, supports=score >= 55,
            confidence=0.6, raw=raw)   # lower confidence — it's a proxy
    except Exception as e:
        log.debug(f"score_history failed for {candidate.symbol}: {e}")
        candidate.layers["filings_signal"] = LayerScore(
            name="filings_signal", score=50.0, supports=False, confidence=0.3, raw=str(e))

    # ========================================================================
    # NOT YET WIRED (5) - placeholder neutral scores
    # When you add these scorers to gir.py, replace the neutral fallback
    # with a real call (same pattern as the wired ones above).
    # ========================================================================

    # === Layer 2: delivery_pct - NEUTRAL (no scorer yet in gir.py) ===
    candidate.layers["delivery_pct"] = LayerScore(
        name="delivery_pct", score=50.0, supports=False, confidence=0.3,
        raw="not_wired")

    # === Layer 4: promoter_inst - NEUTRAL ===
    candidate.layers["promoter_inst"] = LayerScore(
        name="promoter_inst", score=50.0, supports=False, confidence=0.3,
        raw="not_wired")

    # === Layer 5: fii_dii_flow - NEUTRAL ===
    candidate.layers["fii_dii_flow"] = LayerScore(
        name="fii_dii_flow", score=50.0, supports=False, confidence=0.3,
        raw="not_wired")

    # === Layer 7: regime_filter - NEUTRAL ===
    # V28 A10 regime gate exists in gir.py but not as a clean callable.
    # Until extracted, default to neutral.
    candidate.layers["regime_filter"] = LayerScore(
        name="regime_filter", score=50.0, supports=False, confidence=0.3,
        raw="not_wired")

    # === Layer 8: earnings_window - NEUTRAL ===
    # EarningsCalendar class exists but no per-symbol window scorer yet.
    candidate.layers["earnings_window"] = LayerScore(
        name="earnings_window", score=50.0, supports=False, confidence=0.3,
        raw="not_wired")

    return candidate


# ============================================================================
# QUICK SELF-TEST (run this file directly to verify it works)
# ============================================================================

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    print("=" * 70)
    print("DecisionBrain self-test (no gir.py needed)")
    print("=" * 70)

    brain = DecisionBrain(mode="paper")

    # Build a test candidate with all 11 layers populated
    test = Candidate(
        symbol="TESTSTOCK",
        category="equity",
        direction="BULLISH",
        ltp=100.0,
        sector="IT",
    )
    # Strong supporting layers
    test.layers = {
        "technical":      LayerScore("technical", 78, True, 1.0),
        "delivery_pct":   LayerScore("delivery_pct", 72, True, 1.0),
        "oi_buildup":     LayerScore("oi_buildup", 55, True, 0.7),
        "promoter_inst":  LayerScore("promoter_inst", 80, True, 1.0),
        "fii_dii_flow":   LayerScore("fii_dii_flow", 65, True, 0.8),
        "news_sentiment": LayerScore("news_sentiment", 70, True, 0.9),
        "regime_filter":  LayerScore("regime_filter", 80, True, 1.0),
        "earnings_window":LayerScore("earnings_window", 55, True, 0.7),
        "sector_rotation":LayerScore("sector_rotation", 72, True, 0.9),
        "fundamental":    LayerScore("fundamental", 68, True, 0.8),
        "filings_signal": LayerScore("filings_signal", 60, True, 0.8),
    }
    dec = brain.decide(test)
    print(f"\nTest 1 (strong bullish): {dec.action} score={dec.final_score} "
          f"sup={dec.supporting_layers}/11 qty={dec.qty}")
    print(f"   Reason: {dec.reason}")

    # Weak candidate (most layers neutral)
    weak = Candidate(symbol="WEAKSTOCK", category="equity", direction="BULLISH",
                     ltp=200.0, sector="REALTY")
    weak.layers = {n: LayerScore(n, 45, False, 0.8) for n in LAYER_WEIGHTS}
    dec2 = brain.decide(weak)
    print(f"\nTest 2 (weak signals): {dec2.action} score={dec2.final_score} "
          f"sup={dec2.supporting_layers}/11")
    print(f"   Reason: {dec2.reason}")

    print("\n" + "=" * 70)
    print("Brain DB created at:", BRAIN_DB)
    print("Brain log will be at:", BRAIN_LOG)
    print("=" * 70)
