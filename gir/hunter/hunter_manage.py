#!/usr/bin/env python3
"""
hunter_manage.py — Daily afternoon position manager for GIR-HUNTER.

Runs every trading day at 16:00 IST (after market close).

EXIT RULES (final spec, v1.1):
  1. Initial GTT SL placed at entry × (1 - 2.5%) when position is first detected
     as filled. SL only moves UP from here — never down.

  2. Every day, for each open Hunter position:
       a. Compute today's "peak" from Kite OHLC (high since entry, persisted
          in the ledger)
       b. Compute new_trail = peak × (1 - TRAIL_OFFSET_PCT/100)
       c. If new_trail > current_sl: ratchet SL up to new_trail
          (cancel old GTT, place new GTT at new_trail)
       d. Else: leave SL where it is

  3. Day-5 close (5 trading days since entry): force MARKET SELL AMO for tomorrow.

  4. SL exits happen automatically via GTT (intraday) — manage.py just detects
     them and updates the ledger.

State persisted in hunter_positions.jsonl:
  - peak_since_entry: highest LTP seen since entry
  - current_sl: latest GTT trigger price
  - gtt_id: latest GTT trigger id (for cancellation on ratchet)
  - status: PLACED | FILLED | PROTECTED | EXIT_TIMEOUT_QUEUED | CLOSED_NATURAL

Author: GIR-HUNTER v1.1
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time

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
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta, date
from pathlib import Path
from typing import Optional

import requests
from dotenv import load_dotenv
from kiteconnect import KiteConnect

sys.path.insert(0, str(Path(__file__).parent))
from hunter_config import (
    MAX_HUNTER_SLOTS, ORDER_TAG, HARD_SL_PCT, GTT_LIMIT_SLACK_PCT,
    TRAIL_OFFSET_PCT, MAX_HOLD_DAYS,
    HUNTER_DIR, LOG_DIR, STATE_DIR, POSITIONS_LEDGER,
    ENV_FILE, KITE_TOKEN_FILE, TG_CHANNEL_TAG,
)
from market_calendar import is_trading_day, now_ist


def _setup_logging() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / f"manage_{datetime.now().strftime('%Y%m%d')}.log"
    logger = logging.getLogger("hunter_manage")
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


def load_kite() -> KiteConnect:
    load_dotenv(ENV_FILE)
    api_key = os.getenv("KITE_API_KEY")
    if not KITE_TOKEN_FILE.exists():
        raise RuntimeError(f"{KITE_TOKEN_FILE} missing")
    with open(KITE_TOKEN_FILE) as f:
        token_data = json.load(f)
    access_token = token_data.get("access_token", "")
    if not api_key or not access_token:
        raise RuntimeError("Kite creds missing")
    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(access_token)
    return kite


def send_telegram(msg: str) -> None:
    load_dotenv(ENV_FILE)
    token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    chat = os.getenv("TELEGRAM_CHAT_ID", "")
    if not token or not chat:
        return
    try:
        requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat, "text": msg, "parse_mode": "Markdown"},
            timeout=10,
        )
    except Exception as e:
        log.error(f"Telegram failed: {e}")


def read_ledger() -> list[dict]:
    if not POSITIONS_LEDGER.exists():
        return []
    out = []
    with open(POSITIONS_LEDGER) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    log.warning(f"bad ledger line: {line[:80]}")
    return out


def write_ledger(records: list[dict]) -> None:
    tmp = POSITIONS_LEDGER.with_suffix(".tmp")
    with open(tmp, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    tmp.replace(POSITIONS_LEDGER)


def is_open_status(status: str) -> bool:
    # V213: added FILLED_PROTECTED (the actual status written by hunter_execute
    # after BUY fills + GTT placement). Old singular forms kept for backcompat.
    return status in ("PLACED", "FILLED", "PROTECTED", "FILLED_PROTECTED")


@dataclass
class LivePosition:
    symbol: str
    qty: int
    avg_price: float
    ltp: float
    today_high: float
    pnl_abs: float
    pnl_pct: float
    gtt_id: Optional[int]
    gtt_trigger_price: Optional[float]


def fetch_hunter_live_state(
    kite: KiteConnect, symbols: set[str]
) -> dict[str, LivePosition]:
    out: dict[str, LivePosition] = {}
    if not symbols:
        return out

    try:
        holdings = kite.holdings()
    except Exception as e:
        log.error(f"holdings fetch failed: {e}")
        return out

    # v1.2 BUG#3 FIX: kite.holdings() does NOT return day_high.
    # Fetch ohlc via kite.quote() so trail SL ratchets on intraday high.
    day_high_by_sym: dict[str, float] = {}
    try:
        keys = [f"NSE:{s}" for s in symbols]
        if keys:
            q = kite.quote(keys)
            for k, v in q.items():
                sym = k.replace("NSE:", "")
                ohlc = (v or {}).get("ohlc") or {}
                hi = float(ohlc.get("high", 0) or 0)
                if hi > 0:
                    day_high_by_sym[sym] = hi
    except Exception as e:
        log.warning(f"quote fetch for day_high failed: {e} — falling back to LTP")

    gtt_by_sym: dict[str, tuple[int, float]] = {}
    try:
        for g in kite.get_gtts():
            if g.get("status") != "active":
                continue
            cond = g.get("condition", {}) or {}
            sym = cond.get("tradingsymbol")
            triggers = cond.get("trigger_values") or []
            gid = g.get("id")
            if sym and gid and triggers:
                trig = float(triggers[0])
                if sym not in gtt_by_sym or trig > gtt_by_sym[sym][1]:
                    gtt_by_sym[sym] = (int(gid), trig)
    except Exception as e:
        log.warning(f"GTT fetch failed: {e}")

    # V214 FIX: also consult kite.positions().net — freshly bought CNC stocks
    # (still in T+1 settlement window) show up there, not yet in holdings.
    # Without this fix, manage marked them GONE → CLOSED_NATURAL incorrectly.
    positions_net = []
    try:
        positions_net = kite.positions().get("net", []) or []
    except Exception as _e_pos:
        log.warning(f"positions fetch failed (continuing with holdings only): {_e_pos}")

    # Build unified symbol→record map. Holdings wins if duplicate (T+1 settled).
    _live_by_sym: dict[str, dict] = {}
    for p in positions_net:
        sym = p.get("tradingsymbol")
        if sym in symbols and int(p.get("quantity", 0)) > 0:
            _live_by_sym[sym] = {
                "tradingsymbol": sym,
                "quantity": int(p.get("quantity", 0)),
                "average_price": float(p.get("average_price", 0) or 0),
                "last_price": float(p.get("last_price", 0) or 0),
                "_source": "positions_net",
            }
    for h in holdings:
        sym = h.get("tradingsymbol")
        if sym in symbols and int(h.get("quantity", 0)) > 0:
            # holdings takes priority — overwrite any positions_net entry
            _live_by_sym[sym] = {
                "tradingsymbol": sym,
                "quantity": int(h.get("quantity", 0)),
                "average_price": float(h.get("average_price", 0) or 0),
                "last_price": float(h.get("last_price", 0) or 0),
                "_source": "holdings",
            }

    for h in _live_by_sym.values():
        sym = h.get("tradingsymbol")
        if sym not in symbols:
            continue
        qty = int(h.get("quantity", 0))
        if qty <= 0:
            continue
        avg = float(h.get("average_price", 0))
        ltp = float(h.get("last_price", 0))
        day_high = day_high_by_sym.get(sym, ltp)
        if day_high <= 0:
            day_high = ltp
        pnl_abs = (ltp - avg) * qty
        pnl_pct = (ltp - avg) / avg * 100 if avg > 0 else 0.0
        gtt = gtt_by_sym.get(sym)
        gtt_id = gtt[0] if gtt else None
        gtt_trig = gtt[1] if gtt else None
        out[sym] = LivePosition(
            symbol=sym, qty=qty, avg_price=avg, ltp=ltp,
            today_high=day_high, pnl_abs=pnl_abs, pnl_pct=pnl_pct,
            gtt_id=gtt_id, gtt_trigger_price=gtt_trig,
        )
    return out


def days_held(entry_date_str: str, today: date) -> int:
    try:
        entry_d = date.fromisoformat(entry_date_str)
    except Exception:
        return 0
    days = 0
    cur = entry_d
    while cur < today:
        cur = cur + timedelta(days=1)
        if is_trading_day(cur):
            days += 1
    return days


def round_tick(p: float, tick: float = 0.05) -> float:
    return round(round(p / tick) * tick, 2)


def cancel_gtt(kite: KiteConnect, trigger_id: int, dry_run: bool) -> bool:
    log.info(f"[{'DRY' if dry_run else 'LIVE'}] Cancel GTT {trigger_id}")
    if PAPER_MODE:
        paper_cancel_gtt(
            strategy="hunter",
            trigger_id=str(trigger_id),
            reason="hunter_manage.cancel_gtt",
        )
        return True
    if dry_run:
        return True
    try:
        kite.delete_gtt(trigger_id=trigger_id)
        return True
    except Exception as e:
        log.error(f"GTT cancel failed for {trigger_id}: {e}")
        return False


def place_gtt_sl(
    kite: KiteConnect, sym: str, qty: int, trigger: float,
    ltp: float, dry_run: bool
) -> Optional[int]:
    limit = round_tick(trigger * (1 - GTT_LIMIT_SLACK_PCT / 100))
    trigger = round_tick(trigger)
    log.info(f"[{'DRY' if dry_run else 'LIVE'}] GTT SL {sym} qty={qty} "
             f"trig=₹{trigger} limit=₹{limit}")
    if PAPER_MODE:
        paper_place_gtt(
            strategy="hunter",
            symbol=sym,
            exchange="NSE",
            trigger_value=float(trigger),
            limit_price=float(limit),
            qty=int(qty),
            transaction_type="SELL",
            product="CNC",
            meta={"trigger_type": "single", "fn": "hunter_manage.place_gtt_sl", "ltp": float(ltp)},
        )
        return -1
    if dry_run:
        return -1
    try:
        tid = kite.place_gtt(
            trigger_type=kite.GTT_TYPE_SINGLE,
            tradingsymbol=sym,
            exchange=kite.EXCHANGE_NSE,
            trigger_values=[trigger],
            last_price=ltp,
            orders=[{
                "transaction_type": kite.TRANSACTION_TYPE_SELL,
                "quantity": qty,
                "order_type": kite.ORDER_TYPE_LIMIT,
                "product": kite.PRODUCT_CNC,
                "price": limit,
            }],
        )
        log.info(f"   ✓ GTT trigger_id={tid}")
        return tid
    except Exception as e:
        log.error(f"   ✗ GTT failed: {e}")
        return None


def place_market_sell_amo(
    kite: KiteConnect, symbol: str, qty: int, dry_run: bool
) -> Optional[str]:
    log.info(f"[{'DRY' if dry_run else 'LIVE'}] AMO MARKET SELL {symbol} qty={qty}")
    if PAPER_MODE:
        paper_place_order(
            strategy="hunter",
            signal_source="hunter_day5_exit",
            symbol=symbol,
            exchange="NSE",
            product="CNC",
            side="SELL",
            qty=int(qty),
            price=0.0,
            order_type="MARKET",
            tag="HUNTER_EXIT",
            meta={"variety": "AMO", "fn": "hunter_manage.place_market_sell_amo"},
        )
        return f"PAPER-EXIT-{symbol}"
    if dry_run:
        return f"DRY-EXIT-{symbol}"
    try:
        oid = kite.place_order(
            variety=kite.VARIETY_AMO,
            exchange=kite.EXCHANGE_NSE,
            tradingsymbol=symbol,
            transaction_type=kite.TRANSACTION_TYPE_SELL,
            quantity=qty,
            product=kite.PRODUCT_CNC,
            order_type=kite.ORDER_TYPE_MARKET,
            validity=kite.VALIDITY_DAY,
            tag=ORDER_TAG,
        )
        log.info(f"   ✓ exit order_id={oid}")
        return oid
    except Exception as e:
        log.error(f"   ✗ exit failed: {e}")
        return None


def compute_initial_sl(avg_price: float) -> float:
    return round_tick(avg_price * (1 - HARD_SL_PCT / 100))


def compute_trail_sl(peak: float, entry: float = 0.0) -> float:
    """
    V212 ADAPTIVE: trail offset varies by profit zone.
    Falls back to fixed TRAIL_OFFSET_PCT if entry not provided (backward compat).
    """
    if entry > 0:
        profit_pct = ((peak - entry) / entry) * 100
        offset_pct = compute_adaptive_trail_offset(profit_pct)
    else:
        offset_pct = TRAIL_OFFSET_PCT
    return round_tick(peak * (1 - offset_pct / 100))


def ratchet_decision(record: dict, pos: LivePosition) -> tuple[Optional[float], str]:
    """
    Decide whether to ratchet SL up.

    Rules:
      - peak_since_entry = max(prior_peak, ltp, today_high)
      - new_trail        = peak × (1 - 3%)
      - initial_floor    = avg × (1 - 2.5%)
      - candidate_sl     = max(new_trail, initial_floor, current_sl)
      - If candidate_sl > current_sl → ratchet
      - Else → hold
    """
    avg = pos.avg_price
    initial_floor = compute_initial_sl(avg)
    current_sl = float(record.get("current_sl") or initial_floor)
    prev_peak = float(record.get("peak_since_entry") or avg)

    new_peak = max(prev_peak, pos.ltp, pos.today_high or pos.ltp)
    record["peak_since_entry"] = new_peak

    trail_sl = compute_trail_sl(new_peak, entry=record.get("entry_price", 0.0))
    candidate = max(trail_sl, initial_floor, current_sl)

    if candidate > current_sl + 0.01:
        return (candidate,
                f"peak ₹{new_peak:.2f} → trail ₹{trail_sl:.2f} | "
                f"floor ₹{initial_floor:.2f} | candidate ₹{candidate:.2f} > "
                f"current ₹{current_sl:.2f} → RATCHET")
    return (None,
            f"peak ₹{new_peak:.2f} | candidate ₹{candidate:.2f} ≤ "
            f"current ₹{current_sl:.2f} → HOLD")


def run(dry_run: bool = True, skip_calendar: bool = False) -> int:
    log.info("=" * 60)
    log.info(f"HUNTER MANAGE v1.1 — mode={'DRY-RUN' if dry_run else 'LIVE'}")
    log.info("=" * 60)

    now = now_ist()
    today = now.date()
    log.info(f"Now (IST): {now.strftime('%Y-%m-%d %H:%M:%S %A')}")

    if not skip_calendar and not is_trading_day(today):
        log.info("Not a trading day. Exiting cleanly.")
        return 0

    kite = load_kite()
    log.info("Kite OK")

    records = read_ledger()
    open_records = [r for r in records if is_open_status(r.get("status", ""))]
    log.info(f"Ledger: {len(records)} total, {len(open_records)} open")
    if not open_records:
        log.info("No open positions to manage.")
        send_telegram(
            f"📊 *{TG_CHANNEL_TAG}* — manage @ {now.strftime('%H:%M IST')}\n"
            f"_No open positions._"
        )
        return 0

    open_syms = {r["symbol"] for r in open_records}
    live = fetch_hunter_live_state(kite, open_syms)
    log.info(f"Kite confirms {len(live)} of {len(open_syms)} positions still held")

    actions: list[str] = []
    total_pnl_open = 0.0

    for r in open_records:
        sym = r["symbol"]
        pos = live.get(sym)

        if pos is None:
            log.info(f"  {sym}: GONE from Kite → CLOSED_NATURAL")
            r["status"] = "CLOSED_NATURAL"
            r["closed_date_ist"] = today.isoformat()
            actions.append(f"`{sym}` exited (SL or manual)")
            continue

        total_pnl_open += pos.pnl_abs
        held = days_held(r.get("entry_date_ist", today.isoformat()), today)

        log.info(f"  {sym}: qty={pos.qty} avg=₹{pos.avg_price:.2f} ltp=₹{pos.ltp:.2f} "
                 f"high=₹{pos.today_high:.2f} P&L ₹{pos.pnl_abs:+.0f} "
                 f"({pos.pnl_pct:+.2f}%) held={held}d "
                 f"gtt={'yes' if pos.gtt_id else 'NO'}")

        if held >= MAX_HOLD_DAYS:
            if pos.gtt_id:
                cancel_gtt(kite, pos.gtt_id, dry_run)
            oid = place_market_sell_amo(kite, sym, pos.qty, dry_run)
            if oid:
                r["status"] = "EXIT_TIMEOUT_QUEUED"
                r["exit_order_id"] = oid
                r["exit_reason"] = f"timeout {held}d @ {pos.pnl_pct:+.2f}%"
                actions.append(f"`{sym}` Day-{held} timeout exit "
                               f"({pos.pnl_pct:+.2f}%)")
            continue

        new_sl, reason = ratchet_decision(r, pos)
        log.info(f"     {reason}")

        if new_sl is None:
            if not pos.gtt_id:
                initial = compute_initial_sl(pos.avg_price)
                tid = place_gtt_sl(kite, sym, pos.qty, initial, pos.ltp, dry_run)
                if tid:
                    r["status"] = "PROTECTED"
                    r["gtt_id"] = tid
                    r["current_sl"] = initial
                    actions.append(f"`{sym}` initial GTT @ ₹{initial:.2f}")
            continue

        if pos.gtt_id:
            if not cancel_gtt(kite, pos.gtt_id, dry_run):
                log.warning(f"  {sym}: old GTT cancel failed, skipping ratchet")
                continue
        tid = place_gtt_sl(kite, sym, pos.qty, new_sl, pos.ltp, dry_run)
        if tid:
            r["status"] = "PROTECTED"
            r["gtt_id"] = tid
            r["current_sl"] = new_sl
            actions.append(f"`{sym}` SL → ₹{new_sl:.2f} "
                           f"(peak ₹{r['peak_since_entry']:.2f})")

    if not dry_run:
        write_ledger(records)
        log.info("Ledger written")

    surviving = [r for r in open_records if is_open_status(r.get("status", ""))]
    lines = [f"📊 *{TG_CHANNEL_TAG}* — manage @ {now.strftime('%a %H:%M IST')}",
             "",
             f"Open positions: {len(surviving)} / {MAX_HUNTER_SLOTS}",
             f"Open P&L: ₹{total_pnl_open:+.0f}",
             ""]
    if actions:
        lines.append("*Today's actions:*")
        for a in actions:
            lines.append(f"• {a}")
    else:
        lines.append("_No actions today — all SLs intact, no Day-5 timeouts._")
    lines.append("")
    lines.append(f"_Mode: {'DRY-RUN' if dry_run else 'LIVE'}_")
    send_telegram("\n".join(lines))

    log.info("=" * 60)
    log.info(f"MANAGE complete. {len(actions)} action(s).")
    log.info("=" * 60)
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Daily Hunter manager v1.1")
    parser.add_argument("--live", action="store_true", help="Place real orders")
    parser.add_argument("--skip-calendar", action="store_true",
                        help="Override calendar gate (for testing)")
    args = parser.parse_args()
    sys.exit(run(dry_run=not args.live, skip_calendar=args.skip_calendar))
