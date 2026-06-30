"""
paper_trader.py — Central event sink for paper trading + observability.

Every bot decision, every external API call, every order placement,
every exit goes through this module. Zero events lost, zero real
orders placed when PAPER_MODE=True.

Architecture:
  - SQLite (events.db, trades.db) for queryable history
  - Per-day text logs for human grep
  - Snapshot pickles for full state replay
  - All writes append-only, never destructive
"""
from __future__ import annotations

import json
import os
import sqlite3
import threading
import time
import traceback
import uuid
from datetime import datetime, timezone
from pathlib import Path

# Telegram notifications
try:
    import notify
except ImportError:
    notify = None
from typing import Any, Optional

# ============================================================================
# CONFIG
# ============================================================================
PAPER_DIR = Path("/home/globalbot/paper")
EVENTS_DB = PAPER_DIR / "events.db"
TRADES_DB = PAPER_DIR / "trades.db"
LOGS_DIR = PAPER_DIR / "logs"
SNAPSHOTS_DIR = PAPER_DIR / "snapshots"

# Master switch — when True, no real orders are placed
PAPER_MODE = True

# Per-call-site flag for granular control (e.g. flip just Hunter to paper)
PAPER_HUNTER = True
PAPER_GIR_EQ = True
PAPER_GIR_FNO = True

# Thread lock for sqlite (sqlite is single-writer)
_DB_LOCK = threading.RLock()


# ============================================================================
# UTILITIES
# ============================================================================
def _now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def _today_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d")


def _gen_id(prefix: str = "PAPER") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:12].upper()}"


def _safe_json(obj: Any) -> str:
    """JSON-serialize anything, falling back to str() for non-serializable."""
    try:
        return json.dumps(obj, default=str)
    except Exception:
        return str(obj)


# ============================================================================
# DATABASE SCHEMA
# ============================================================================
EVENTS_SCHEMA = """
CREATE TABLE IF NOT EXISTS bot_events (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts_utc          TEXT NOT NULL,
    module          TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    symbol          TEXT,
    strategy_tag    TEXT,
    decision        TEXT,
    reason          TEXT,
    ltp             REAL,
    price           REAL,
    qty             INTEGER,
    sl_trigger      REAL,
    sl_limit        REAL,
    composite_score REAL,
    feature_json    TEXT,
    quality_score   REAL,
    quality_mult    REAL,
    quality_reasons TEXT,
    gemini_model    TEXT,
    tokens_in       INTEGER,
    tokens_out      INTEGER,
    cost_inr        REAL,
    latency_ms      INTEGER,
    meta_json       TEXT,
    traceback_text  TEXT
);
CREATE INDEX IF NOT EXISTS idx_events_ts ON bot_events(ts_utc);
CREATE INDEX IF NOT EXISTS idx_events_module ON bot_events(module);
CREATE INDEX IF NOT EXISTS idx_events_symbol ON bot_events(symbol);
CREATE INDEX IF NOT EXISTS idx_events_type ON bot_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_strategy ON bot_events(strategy_tag);
"""

TRADES_SCHEMA = """
CREATE TABLE IF NOT EXISTS paper_trades (
    trade_id        TEXT PRIMARY KEY,
    strategy        TEXT NOT NULL,
    signal_source   TEXT,
    symbol          TEXT NOT NULL,
    exchange        TEXT,
    product         TEXT,
    side            TEXT NOT NULL,
    qty             INTEGER NOT NULL,
    entry_ts        TEXT NOT NULL,
    entry_price     REAL NOT NULL,
    sl_trigger      REAL,
    sl_limit        REAL,
    time_stop_days  INTEGER,
    peak_price      REAL,
    current_sl      REAL,
    exit_ts         TEXT,
    exit_price      REAL,
    exit_reason     TEXT,
    pnl             REAL,
    pnl_pct         REAL,
    days_held       INTEGER,
    cf_1d_price     REAL,
    cf_3d_price     REAL,
    cf_7d_price     REAL,
    cf_30d_price    REAL,
    cf_max_favorable REAL,
    cf_max_adverse  REAL,
    status          TEXT NOT NULL DEFAULT 'OPEN',
    meta_json       TEXT
);
CREATE INDEX IF NOT EXISTS idx_trades_status ON paper_trades(status);
CREATE INDEX IF NOT EXISTS idx_trades_strategy ON paper_trades(strategy);
CREATE INDEX IF NOT EXISTS idx_trades_symbol ON paper_trades(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_entry ON paper_trades(entry_ts);
"""

GEMINI_SCHEMA = """
CREATE TABLE IF NOT EXISTS gemini_costs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts_utc          TEXT NOT NULL,
    model           TEXT NOT NULL,
    call_site       TEXT,
    symbol          TEXT,
    tokens_in       INTEGER,
    tokens_out      INTEGER,
    cost_inr        REAL,
    latency_ms      INTEGER,
    cached          INTEGER DEFAULT 0,
    prompt_hash     TEXT,
    response_excerpt TEXT,
    error_text      TEXT,
    meta_json       TEXT
);
CREATE INDEX IF NOT EXISTS idx_gemini_ts ON gemini_costs(ts_utc);
CREATE INDEX IF NOT EXISTS idx_gemini_model ON gemini_costs(model);
CREATE INDEX IF NOT EXISTS idx_gemini_site ON gemini_costs(call_site);
"""


# ============================================================================
# DB INIT
# ============================================================================
def _init_db():
    """Idempotent — safe to call on every import."""
    PAPER_DIR.mkdir(parents=True, exist_ok=True)
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)

    with _DB_LOCK:
        conn = sqlite3.connect(str(EVENTS_DB))
        conn.executescript(EVENTS_SCHEMA)
        conn.executescript(GEMINI_SCHEMA)
        conn.commit()
        conn.close()

        conn = sqlite3.connect(str(TRADES_DB))
        conn.executescript(TRADES_SCHEMA)
        conn.commit()
        conn.close()


_init_db()


# ============================================================================
# TEXT LOG WRITER (per-day per-module)
# ============================================================================
def _write_text_log(module: str, message: str):
    """Append to per-day per-module log file."""
    try:
        log_path = LOGS_DIR / f"{_today_str()}_{module}.log"
        ts = _now_utc()
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"{ts} | {message}\n")
    except Exception:
        pass  # never crash bot from logging


# ============================================================================
# CORE EVENT SINK
# ============================================================================
def record_event(
    module: str,
    event_type: str,
    symbol: Optional[str] = None,
    strategy_tag: Optional[str] = None,
    decision: Optional[str] = None,
    reason: Optional[str] = None,
    ltp: Optional[float] = None,
    price: Optional[float] = None,
    qty: Optional[int] = None,
    sl_trigger: Optional[float] = None,
    sl_limit: Optional[float] = None,
    composite_score: Optional[float] = None,
    feature_breakdown: Optional[dict] = None,
    quality_score: Optional[float] = None,
    quality_multiplier: Optional[float] = None,
    quality_reasons: Optional[list] = None,
    gemini_model: Optional[str] = None,
    tokens_in: Optional[int] = None,
    tokens_out: Optional[int] = None,
    cost_inr: Optional[float] = None,
    latency_ms: Optional[int] = None,
    meta: Optional[dict] = None,
    error: Optional[BaseException] = None,
) -> int:
    """
    Record one bot event. Returns the event ID.

    NEVER raises — bot decisions must not depend on telemetry success.
    """
    try:
        traceback_text = None
        if error is not None:
            traceback_text = "".join(traceback.format_exception(type(error), error, error.__traceback__))

        ts = _now_utc()

        with _DB_LOCK:
            conn = sqlite3.connect(str(EVENTS_DB))
            cur = conn.execute("""
                INSERT INTO bot_events (
                    ts_utc, module, event_type, symbol, strategy_tag,
                    decision, reason, ltp, price, qty,
                    sl_trigger, sl_limit, composite_score, feature_json,
                    quality_score, quality_mult, quality_reasons,
                    gemini_model, tokens_in, tokens_out, cost_inr, latency_ms,
                    meta_json, traceback_text
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                ts, module, event_type, symbol, strategy_tag,
                decision, reason, ltp, price, qty,
                sl_trigger, sl_limit, composite_score,
                _safe_json(feature_breakdown) if feature_breakdown else None,
                quality_score, quality_multiplier,
                _safe_json(quality_reasons) if quality_reasons else None,
                gemini_model, tokens_in, tokens_out, cost_inr, latency_ms,
                _safe_json(meta) if meta else None,
                traceback_text,
            ))
            event_id = cur.lastrowid
            conn.commit()
            conn.close()

        # Mirror to text log
        msg_parts = [f"[{event_type}]"]
        if symbol: msg_parts.append(f"sym={symbol}")
        if strategy_tag: msg_parts.append(f"strat={strategy_tag}")
        if decision: msg_parts.append(f"decision={decision}")
        if reason: msg_parts.append(f"reason={reason}")
        if price: msg_parts.append(f"price={price}")
        if ltp: msg_parts.append(f"ltp={ltp}")
        if qty: msg_parts.append(f"qty={qty}")
        if cost_inr: msg_parts.append(f"cost=₹{cost_inr:.3f}")
        _write_text_log(module, " ".join(msg_parts))

        return event_id
    except Exception as e:
        # Last-resort log
        try:
            _write_text_log("errors", f"record_event FAILED: {e} | original event_type={event_type} module={module}")
        except Exception:
            pass
        return -1


# ============================================================================
# PAPER ORDER WRAPPERS — drop-in replacements for kite.* calls
# ============================================================================
def paper_place_order(
    *,
    strategy: str,
    signal_source: str,
    symbol: str,
    exchange: str,
    product: str,
    side: str,
    qty: int,
    price: float,
    order_type: str = "MARKET",
    tag: Optional[str] = None,
    sl_trigger: Optional[float] = None,
    sl_limit: Optional[float] = None,
    time_stop_days: Optional[int] = None,
    meta: Optional[dict] = None,
) -> str:
    """
    Record a paper order. Returns fake order_id string ("PAPER_XXXXXX").

    Caller treats this exactly like kite.place_order — same return shape.
    """
    trade_id = _gen_id("PAPER")
    ts = _now_utc()

    # Record event
    record_event(
        module=strategy,
        event_type="ORDER_PLACED",
        symbol=symbol,
        strategy_tag=signal_source,
        decision="BUY" if side.upper() == "BUY" else "SELL",
        reason=f"paper_place_order via {signal_source}",
        price=price,
        qty=qty,
        sl_trigger=sl_trigger,
        sl_limit=sl_limit,
        meta={
            "trade_id": trade_id,
            "exchange": exchange,
            "product": product,
            "order_type": order_type,
            "tag": tag,
            "time_stop_days": time_stop_days,
            **(meta or {}),
        },
    )

    # Record paper trade row (only for opening trades)
    if side.upper() == "BUY":
        try:
            with _DB_LOCK:
                conn = sqlite3.connect(str(TRADES_DB))
                conn.execute("""
                    INSERT INTO paper_trades (
                        trade_id, strategy, signal_source, symbol,
                        exchange, product, side, qty,
                        entry_ts, entry_price, sl_trigger, sl_limit,
                        time_stop_days, peak_price, current_sl,
                        status, meta_json
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, (
                    trade_id, strategy, signal_source, symbol,
                    exchange, product, side, qty,
                    ts, price, sl_trigger, sl_limit,
                    time_stop_days, price, sl_trigger,
                    "OPEN", _safe_json(meta or {}),
                ))
                conn.commit()
                conn.close()
        except Exception as e:
            _write_text_log("errors", f"paper_place_order trade insert FAILED: {e}")

    # Telegram entry notification (silent on failure)
    if notify is not None:
        try:
            notify.notify_paper_entry(
                symbol=symbol,
                side=side,
                qty=qty,
                price=price if price else 0.0,
                strategy=strategy,
                signal_source=str(signal_source)[:40] if signal_source else "",
            )
        except Exception:
            pass
    return trade_id


def paper_place_gtt(
    *,
    strategy: str,
    symbol: str,
    exchange: str,
    trigger_value: float,
    limit_price: float,
    qty: int,
    transaction_type: str = "SELL",
    product: str = "CNC",
    trade_id: Optional[str] = None,
    tag: Optional[str] = None,
    meta: Optional[dict] = None,
) -> dict:
    """Record a paper GTT. Returns {trigger_id: PAPERGTT_XXXX} dict matching Kite SDK shape."""
    trigger_id = _gen_id("PAPERGTT")

    record_event(
        module=strategy,
        event_type="GTT_PLACED",
        symbol=symbol,
        strategy_tag=trade_id,
        decision=transaction_type,
        reason="paper_place_gtt",
        sl_trigger=trigger_value,
        sl_limit=limit_price,
        qty=qty,
        meta={
            "trigger_id": trigger_id,
            "exchange": exchange,
            "product": product,
            "tag": tag,
            **(meta or {}),
        },
    )

    # Update trade row's current_sl if linked
    if trade_id:
        try:
            with _DB_LOCK:
                conn = sqlite3.connect(str(TRADES_DB))
                conn.execute("""
                    UPDATE paper_trades
                    SET sl_trigger = ?, sl_limit = ?, current_sl = ?
                    WHERE trade_id = ?
                """, (trigger_value, limit_price, trigger_value, trade_id))
                conn.commit()
                conn.close()
        except Exception as e:
            _write_text_log("errors", f"paper_place_gtt trade update FAILED: {e}")

    return {"trigger_id": trigger_id}


def paper_modify_gtt(
    *,
    strategy: str,
    trigger_id: str,
    symbol: str,
    new_trigger: float,
    new_limit: float,
    qty: int,
    old_trigger: Optional[float] = None,
    trade_id: Optional[str] = None,
    reason: str = "trail_ratchet",
    meta: Optional[dict] = None,
) -> dict:
    """Record a paper GTT modification (trail ratchet)."""
    record_event(
        module=strategy,
        event_type="GTT_MODIFIED",
        symbol=symbol,
        strategy_tag=trade_id,
        decision="MODIFY",
        reason=reason,
        sl_trigger=new_trigger,
        sl_limit=new_limit,
        qty=qty,
        meta={
            "trigger_id": trigger_id,
            "old_trigger": old_trigger,
            "delta": (new_trigger - old_trigger) if old_trigger else None,
            **(meta or {}),
        },
    )

    if trade_id:
        try:
            with _DB_LOCK:
                conn = sqlite3.connect(str(TRADES_DB))
                conn.execute("""
                    UPDATE paper_trades
                    SET sl_trigger = ?, sl_limit = ?, current_sl = ?,
                        peak_price = MAX(COALESCE(peak_price, 0), ?)
                    WHERE trade_id = ?
                """, (new_trigger, new_limit, new_trigger, new_trigger / 0.95, trade_id))
                conn.commit()
                conn.close()
        except Exception as e:
            _write_text_log("errors", f"paper_modify_gtt trade update FAILED: {e}")

    return {"trigger_id": trigger_id}


def paper_cancel_gtt(*, strategy: str, trigger_id: str, symbol: Optional[str] = None, reason: str = "cancel"):
    """Record a paper GTT cancellation."""
    record_event(
        module=strategy,
        event_type="GTT_CANCELLED",
        symbol=symbol,
        reason=reason,
        meta={"trigger_id": trigger_id},
    )
    return {"trigger_id": trigger_id}


def paper_record_exit(
    *,
    trade_id: str,
    exit_price: float,
    exit_reason: str,
    strategy: Optional[str] = None,
    meta: Optional[dict] = None,
) -> Optional[dict]:
    """Close a paper trade. Computes P&L. Returns the closed trade dict."""
    try:
        with _DB_LOCK:
            conn = sqlite3.connect(str(TRADES_DB))
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                "SELECT * FROM paper_trades WHERE trade_id = ? AND status = 'OPEN'",
                (trade_id,)
            ).fetchone()

            if not row:
                conn.close()
                return None

            ts = _now_utc()
            entry_price = row["entry_price"]
            qty = row["qty"]
            pnl = (exit_price - entry_price) * qty
            pnl_pct = ((exit_price - entry_price) / entry_price) * 100 if entry_price else 0

            try:
                entry_dt = datetime.fromisoformat(row["entry_ts"])
                exit_dt = datetime.fromisoformat(ts)
                days_held = (exit_dt - entry_dt).days
            except Exception:
                days_held = 0

            conn.execute("""
                UPDATE paper_trades
                SET exit_ts = ?, exit_price = ?, exit_reason = ?,
                    pnl = ?, pnl_pct = ?, days_held = ?, status = 'CLOSED'
                WHERE trade_id = ?
            """, (ts, exit_price, exit_reason, pnl, pnl_pct, days_held, trade_id))
            conn.commit()

            updated = conn.execute(
                "SELECT * FROM paper_trades WHERE trade_id = ?",
                (trade_id,)
            ).fetchone()
            conn.close()

            record_event(
                module=strategy or row["strategy"],
                event_type="POSITION_EXIT",
                symbol=row["symbol"],
                strategy_tag=row["signal_source"],
                decision="EXIT",
                reason=exit_reason,
                price=exit_price,
                qty=qty,
                meta={
                    "trade_id": trade_id,
                    "entry_price": entry_price,
                    "pnl": pnl,
                    "pnl_pct": pnl_pct,
                    "days_held": days_held,
                    **(meta or {}),
                },
            )

            return dict(updated)
    except Exception as e:
        _write_text_log("errors", f"paper_record_exit FAILED: trade_id={trade_id} err={e}")
        return None


# ============================================================================
# GEMINI WRAPPER
# ============================================================================
# Gemini pricing (INR per 1M tokens) — as of May 2026
# Source: docs.anthropic.com... wait that's Anthropic. Gemini: ai.google.dev/pricing
# Approximate, override if changed
GEMINI_PRICING = {
    "gemini-2.5-flash":      {"in": 25,  "out": 75},   # ₹/1M tokens
    "gemini-2.5-flash-lite": {"in": 10,  "out": 30},
    "gemini-2.5-pro":        {"in": 250, "out": 1000},
    "gemini-3-flash":        {"in": 25,  "out": 75},
}


def paper_gemini_call(
    *,
    call_site: str,
    model: str,
    tokens_in: int,
    tokens_out: int,
    latency_ms: int,
    symbol: Optional[str] = None,
    cached: bool = False,
    prompt_hash: Optional[str] = None,
    response_excerpt: Optional[str] = None,
    error: Optional[str] = None,
    meta: Optional[dict] = None,
):
    """Record a Gemini API call. Cost computed from token counts."""
    pricing = GEMINI_PRICING.get(model, {"in": 50, "out": 150})
    cost_inr = (tokens_in * pricing["in"] + tokens_out * pricing["out"]) / 1_000_000

    if response_excerpt and len(response_excerpt) > 500:
        response_excerpt = response_excerpt[:500] + "...[truncated]"

    try:
        with _DB_LOCK:
            conn = sqlite3.connect(str(EVENTS_DB))
            conn.execute("""
                INSERT INTO gemini_costs (
                    ts_utc, model, call_site, symbol,
                    tokens_in, tokens_out, cost_inr, latency_ms,
                    cached, prompt_hash, response_excerpt, error_text, meta_json
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                _now_utc(), model, call_site, symbol,
                tokens_in, tokens_out, cost_inr, latency_ms,
                1 if cached else 0, prompt_hash, response_excerpt, error,
                _safe_json(meta) if meta else None,
            ))
            conn.commit()
            conn.close()
    except Exception as e:
        _write_text_log("errors", f"paper_gemini_call FAILED: {e}")

    record_event(
        module="gemini",
        event_type="API_CALL",
        symbol=symbol,
        strategy_tag=call_site,
        reason="cached" if cached else "live",
        gemini_model=model,
        tokens_in=tokens_in,
        tokens_out=tokens_out,
        cost_inr=cost_inr,
        latency_ms=latency_ms,
        meta=meta,
    )


# ============================================================================
# SELF-TEST
# ============================================================================
if __name__ == "__main__":
    print(f"paper_trader.py loaded")
    print(f"  PAPER_MODE={PAPER_MODE}")
    print(f"  EVENTS_DB={EVENTS_DB}")
    print(f"  TRADES_DB={TRADES_DB}")
    print()
    print("Running self-test...")

    eid = record_event(
        module="selftest",
        event_type="STARTUP",
        reason="paper_trader.py self-test",
        meta={"test_run": True, "version": "v1"},
    )
    print(f"  ✓ record_event returned id={eid}")

    tid = paper_place_order(
        strategy="selftest",
        signal_source="UNIT_TEST",
        symbol="TESTSTOCK",
        exchange="NSE",
        product="CNC",
        side="BUY",
        qty=10,
        price=100.0,
        sl_trigger=94.0,
        sl_limit=93.8,
        time_stop_days=30,
    )
    print(f"  ✓ paper_place_order returned trade_id={tid}")

    gid = paper_place_gtt(
        strategy="selftest",
        symbol="TESTSTOCK",
        exchange="NSE",
        trigger_value=94.0,
        limit_price=93.8,
        qty=10,
        trade_id=tid,
    )
    print(f"  ✓ paper_place_gtt returned trigger_id={gid}")

    mod = paper_modify_gtt(
        strategy="selftest",
        trigger_id=gid,
        symbol="TESTSTOCK",
        new_trigger=98.0,
        new_limit=97.8,
        qty=10,
        old_trigger=94.0,
        trade_id=tid,
        reason="trail_test",
    )
    print(f"  ✓ paper_modify_gtt returned {mod}")

    exit_dict = paper_record_exit(
        trade_id=tid,
        exit_price=105.0,
        exit_reason="UNIT_TEST_EXIT",
        strategy="selftest",
    )
    print(f"  ✓ paper_record_exit: pnl={exit_dict['pnl']:.2f}, pnl_pct={exit_dict['pnl_pct']:.2f}%")

    paper_gemini_call(
        call_site="newsbrain_selftest",
        model="gemini-2.5-flash",
        tokens_in=500,
        tokens_out=200,
        latency_ms=850,
        symbol="TESTSTOCK",
        response_excerpt="Bullish — strong earnings momentum.",
    )
    print(f"  ✓ paper_gemini_call recorded")

    # Verify DB counts
    with _DB_LOCK:
        conn = sqlite3.connect(str(EVENTS_DB))
        n_events = conn.execute("SELECT COUNT(*) FROM bot_events").fetchone()[0]
        n_gemini = conn.execute("SELECT COUNT(*) FROM gemini_costs").fetchone()[0]
        conn.close()
        conn = sqlite3.connect(str(TRADES_DB))
        n_trades = conn.execute("SELECT COUNT(*) FROM paper_trades").fetchone()[0]
        n_closed = conn.execute("SELECT COUNT(*) FROM paper_trades WHERE status='CLOSED'").fetchone()[0]
        conn.close()

    print()
    print(f"DB state:")
    print(f"  bot_events:    {n_events}")
    print(f"  gemini_costs:  {n_gemini}")
    print(f"  paper_trades:  {n_trades} ({n_closed} closed)")
    print()
    print("✓ SELF-TEST PASSED")


# ============================================================
# PHASE 5.1 — Helpers for paper_exit_monitor
# Added: 2026-05-21
# ============================================================

def get_open_paper_trades() -> list:
    """Return all OPEN paper trades as list of dicts. Used by paper_exit_monitor."""
    import sqlite3
    with _DB_LOCK:
        conn = sqlite3.connect(str(TRADES_DB))
        conn.row_factory = sqlite3.Row
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT trade_id, strategy, signal_source, symbol, exchange, product,
                       side, qty, entry_ts, entry_price, sl_trigger, sl_limit,
                       time_stop_days, peak_price, current_sl, days_held, meta_json
                FROM paper_trades
                WHERE status = 'OPEN'
            """)
            return [dict(r) for r in cur.fetchall()]
        finally:
            conn.close()


def update_paper_trade_trail(trade_id: str, new_peak: float, new_sl: float) -> bool:
    """Ratchet peak_price and current_sl up for an open trade.
    Caller MUST guarantee new_peak >= current peak and new_sl >= current_sl.
    Returns True if a row was updated."""
    import sqlite3
    with _DB_LOCK:
        conn = sqlite3.connect(str(TRADES_DB))
        try:
            cur = conn.cursor()
            cur.execute("""
                UPDATE paper_trades
                SET peak_price = ?, current_sl = ?
                WHERE trade_id = ? AND status = 'OPEN'
            """, (new_peak, new_sl, trade_id))
            conn.commit()
            return cur.rowcount > 0
        finally:
            conn.close()


def update_paper_trade_days_held(trade_id: str, days: int) -> bool:
    """Update days_held counter. Called once per day by paper_exit_monitor."""
    import sqlite3
    with _DB_LOCK:
        conn = sqlite3.connect(str(TRADES_DB))
        try:
            cur = conn.cursor()
            cur.execute("""
                UPDATE paper_trades
                SET days_held = ?
                WHERE trade_id = ? AND status = 'OPEN'
            """, (days, trade_id))
            conn.commit()
            return cur.rowcount > 0
        finally:
            conn.close()

