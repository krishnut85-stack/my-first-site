#!/usr/bin/env python3
"""
fno_paper_study.py  -  Standalone F&O signal -> paper trade collector
============================================================================
Reads scored F&O signals that gir.py writes to paper/events.db (fno_signals
table, via the FNO_PAPER_STUDY_HOOK), turns each into an ATM option paper
trade, and manages exits. Completely independent of gir.py at runtime.

Design (decided with user 2026-06-17):
  - Contract : ATM option (strike nearest spot)
  - Direction: BULLISH -> buy CE,  BEARISH -> buy PE  (long option)
  - Expiry   : nearest expiry with DTE >= FNO_MIN_DTE (15)
  - Size     : 1 lot (lot_size from kite.instruments())
  - Exit     : +30% target / -50% stop on premium, hard square-off 15:20 IST
  - Tag      : FNO_PAPER_STUDY  (V222-immune; separate from gir_fno ledger)
  - Min score: OI_SIGNAL_MIN_SCORE = 65 (matches gir.py)

SAFETY: runs in DRY_RUN mode by default. In dry-run it logs exactly what it
WOULD place but calls nothing. Flip to recording mode (env FNO_STUDY_RECORD=1) only
after one clean dry-run cycle confirms strike resolution on a real signal.

Login: copies RAVEN's pattern - reads daily token file kite_token.json,
falls back to .env. Never hardcodes secrets.
"""

import os
import sys
import time
import json
import sqlite3
import logging
from datetime import datetime, timedelta

try:
    from zoneinfo import ZoneInfo
    IST = ZoneInfo("Asia/Kolkata")
except Exception:
    IST = None

# --- paths / constants ------------------------------------------------------
HOME = "/home/globalbot"
EVENTS_DB = f"{HOME}/paper/events.db"
TRADES_DB = f"{HOME}/paper/trades.db"
TOKEN_FILE = f"{HOME}/data/kite_token.json"
ENV_FILE = f"{HOME}/.env"

OI_SIGNAL_MIN_SCORE = 65        # match gir.py
FNO_MIN_DTE = 15                # match gir.py
# RISK:REWARD - flipped from the original +30%/-50% (which needed a 62.5% win
# rate just to break even). +50%/-30% only needs 37.5% - profitable at our ~44%.
# Let winners run, cut losers fast. Env-configurable so we can keep tuning.
TARGET_PCT = float(os.environ.get("FNO_TARGET_PCT", "0.50"))   # +50% premium target
STOP_PCT = float(os.environ.get("FNO_STOP_PCT", "0.30"))       # -30% premium stop
# Fixed rupee sizing: buy ~TRADE_BUDGET worth (not a blind 1 lot, which ranged
# from tiny to 60k and caused single 17k losses). Skip options whose 1 lot
# already costs more than MAX_LOT_COST (too risky / too expensive to size).
TRADE_BUDGET = float(os.environ.get("FNO_TRADE_BUDGET", "20000"))
MAX_LOT_COST = float(os.environ.get("FNO_MAX_LOT_COST", "35000"))
# Daily loss cap (inversion safety): once today's realised loss hits this, STOP
# opening new trades for the rest of the day. Resets next day (date-based). Rupees.
# 0 = disabled. F&O is the momentum lane that bled before - this is its brake.
MAX_DAILY_LOSS = float(os.environ.get("FNO_MAX_DAILY_LOSS", "15000"))
# Cap simultaneous open positions. Day 1 flooded 24 option buys at once, all
# squared off together at a loss before the daily cap could trip. Bounding the
# count stops the batch flood. 0 = unlimited.
MAX_POSITIONS = int(os.environ.get("FNO_MAX_POSITIONS", "0"))
SQUARE_OFF = (15, 20)           # 15:20 IST square-off (market still open)
MARKET_OPEN = (9, 15)           # 09:15 IST
MARKET_CLOSE = (15, 30)         # 15:30 IST
POLL_SECONDS = 30               # signal poll + position monitor cadence
# Strategy tag is configurable so a dedicated instance (e.g. FNO_BUILDUP) can run
# our Trendlyne build-up signals in its OWN lane, separate from gir's signals.
STRATEGY_TAG = os.environ.get("FNO_STRATEGY_TAG", "FNO_PAPER_STUDY")
# Signal-source filters (pattern prefix, case-insensitive):
#   FNO_PATTERN_INCLUDE=EXCEL_  -> trade ONLY our build-up signals
#   FNO_PATTERN_EXCLUDE=EXCEL_  -> trade everything EXCEPT ours (gir's lane)
# gir's signals (PUT_WRITING/CALL_WRITING/etc.) were crowding ours out; this
# splits the two cleanly so each can be evaluated on its own.
PATTERN_INCLUDE = os.environ.get("FNO_PATTERN_INCLUDE", "").strip().upper()
PATTERN_EXCLUDE = os.environ.get("FNO_PATTERN_EXCLUDE", "").strip().upper()
# High-water-mark file: per-instance so two lanes keep independent positions.
HWM_FILE = os.environ.get("FNO_HWM_FILE", "/home/globalbot/fno_study_hwm.txt")

# Indices ARE traded. NIFTY/BANKNIFTY/FINNIFTY use special spot keys and their
# own expiry rule (weekly for NIFTY). Lot size (NIFTY=65 in 2026) comes from
# kite.instruments() per contract - never hardcoded. Set FNO_STUDY_INDICES=0
# to exclude them if you later want a stock-only study.
STUDY_INDICES = os.environ.get("FNO_STUDY_INDICES", "1").strip() == "1"
INDEX_SET = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "SENSEX", "NIFTYNXT50"}
# Underlyings to skip entirely. MIDCPNIFTY's index spot is not reliably
# resolvable via a simple Kite key (known Kite quirk) - it was failing every
# spot lookup and blocking the whole cycle, so exclude it.
SKIP_UNDERLYINGS = {
    u.strip().upper() for u in
    os.environ.get("FNO_STUDY_SKIP", "MIDCPNIFTY").split(",") if u.strip()
}
# Correct spot keys (matches gir.py): plain "NSE:NIFTY" returns nothing.
INDEX_SPOT_KEY = {
    "NIFTY": "NSE:NIFTY 50",
    "BANKNIFTY": "NSE:NIFTY BANK",
    "FINNIFTY": "NSE:NIFTY FIN SERVICE",
    "MIDCPNIFTY": "NSE:NIFTY MIDCAP SELECT",
}

DRY_RUN = os.environ.get("FNO_STUDY_RECORD", "0").strip() != "1"
# PAPER-ONLY: this script ONLY ever calls paper_place_order (simulated).
# It has no path to kite.place_order. "Recording" writes to the paper DB.

# --- logging ----------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [FNO_STUDY] %(levelname)s %(message)s",
)
log = logging.getLogger("fno_study")


# --- .env loader (never hardcode secrets) -----------------------------------
def _load_env():
    try:
        from dotenv import load_dotenv
        load_dotenv(ENV_FILE)
    except Exception:
        # minimal manual parse fallback
        try:
            for line in open(ENV_FILE):
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())
        except Exception as e:
            log.warning(f".env load failed: {e}")


# --- Kite login (RAVEN KiteAdapter pattern, verbatim logic) -----------------
def get_kite():
    from kiteconnect import KiteConnect
    api_key = os.environ.get("KITE_API_KEY", "").strip()
    # TOKENFIX pattern: read daily-refreshed token file the main bot writes;
    # fall back to .env only if the file is missing.
    token = ""
    try:
        _td = json.load(open(TOKEN_FILE))
        token = (_td.get("access_token") or "").strip()
    except Exception:
        pass
    if not token:
        token = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    if not (api_key and token):
        raise RuntimeError("KITE_API_KEY / access_token missing - cannot login")
    k = KiteConnect(api_key=api_key)
    k.set_access_token(token)
    try:
        _TOKEN_MTIME[0] = os.path.getmtime(TOKEN_FILE)
    except Exception:
        pass
    return k


# Kite tokens expire DAILY; the main bot rewrites kite_token.json each morning.
# Re-read it whenever it changes so our session never goes stale mid-run.
_TOKEN_MTIME = [0.0]


def refresh_token(kite):
    try:
        mt = os.path.getmtime(TOKEN_FILE)
        if mt != _TOKEN_MTIME[0]:
            tok = (json.load(open(TOKEN_FILE)).get("access_token") or "").strip()
            if tok:
                kite.set_access_token(tok)
                _TOKEN_MTIME[0] = mt
                log.info("Kite access token reloaded from token file (daily refresh)")
    except Exception as e:
        log.debug(f"token refresh skipped: {e}")


# --- instrument cache -------------------------------------------------------
_NFO_CACHE = {"ts": 0, "data": None}

def _nfo_instruments(kite):
    """Cache NFO instrument dump ~30 min (it changes only at expiry roll)."""
    now = time.time()
    if _NFO_CACHE["data"] is None or (now - _NFO_CACHE["ts"]) > 1800:
        _NFO_CACHE["data"] = kite.instruments("NFO")
        _NFO_CACHE["ts"] = now
        log.info(f"NFO instruments loaded: {len(_NFO_CACHE['data'])} rows")
    return _NFO_CACHE["data"]


def _spot_ltp(kite, underlying):
    """Best-effort spot for the underlying. Indices use special NSE keys."""
    key = INDEX_SPOT_KEY.get(underlying, f"NSE:{underlying}")
    try:
        q = kite.ltp([key])
        return float(q[key]["last_price"])
    except Exception as e:
        log.warning(f"spot LTP failed for {underlying} ({key}): {e}")
        return None


def resolve_atm_option(kite, underlying, opt_type, is_index=False):
    """
    Return (tradingsymbol, lot_size, ltp) for the ATM CE/PE of `underlying`.
    Expiry rule:
      - stocks : nearest expiry with DTE >= FNO_MIN_DTE (monthly)
      - indices: nearest available expiry (NIFTY weekly is days away, not 15+)
    Lot size comes from the instrument row (NIFTY=65 in 2026), never hardcoded.
    opt_type in {'CE','PE'}. Returns None if unresolved (caller skips, never guesses).
    """
    spot = _spot_ltp(kite, underlying)
    if not spot or spot <= 0:
        return None
    insts = _nfo_instruments(kite)
    today = datetime.now(IST).date() if IST else datetime.utcnow().date()

    # candidate option rows for this underlying + type
    rows = [
        r for r in insts
        if r.get("name") == underlying
        and r.get("instrument_type") == opt_type
        and r.get("segment") == "NFO-OPT"
    ]
    if not rows:
        log.warning(f"no {opt_type} instruments for {underlying}")
        return None

    # nearest expiry with DTE >= FNO_MIN_DTE
    def _dte(r):
        exp = r.get("expiry")
        if isinstance(exp, str):
            try:
                exp = datetime.strptime(exp, "%Y-%m-%d").date()
            except Exception:
                return -1
        return (exp - today).days if exp else -1

    if is_index:
        # nearest available expiry (weekly for NIFTY), must be today or later
        valid_exp = sorted({_dte(r) for r in rows if _dte(r) >= 0})
    else:
        # stocks: nearest monthly expiry with enough room
        valid_exp = sorted({_dte(r) for r in rows if _dte(r) >= FNO_MIN_DTE})
    if not valid_exp:
        log.warning(f"{underlying}: no valid expiry found")
        return None
    target_dte = valid_exp[0]
    exp_rows = [r for r in rows if _dte(r) == target_dte]

    # ATM = strike nearest spot
    atm = min(exp_rows, key=lambda r: abs(float(r.get("strike", 0)) - spot))
    tsym = atm.get("tradingsymbol")
    lot = int(atm.get("lot_size") or 0)
    if not tsym or lot <= 0:
        log.warning(f"{underlying}: bad ATM row {atm}")
        return None

    # premium (entry price)
    try:
        q = kite.ltp([f"NFO:{tsym}"])
        ltp = float(q[f"NFO:{tsym}"]["last_price"])
    except Exception as e:
        log.warning(f"premium LTP failed {tsym}: {e}")
        return None
    if ltp <= 0:
        return None
    return (tsym, lot, ltp)


# --- paper placement (reuse the bot's own paper_trader) ---------------------
def _import_paper_trader():
    sys.path.insert(0, f"{HOME}/paper")
    from paper_trader import paper_place_order
    return paper_place_order


def _import_exit_helpers():
    """get_open_paper_trades() + paper_record_exit() from the bot's module."""
    sys.path.insert(0, f"{HOME}/paper")
    from paper_trader import get_open_paper_trades, paper_record_exit
    return get_open_paper_trades, paper_record_exit


def _ist_now():
    return datetime.now(IST) if IST else datetime.utcnow()


def _market_open_now():
    """True only Mon-Fri between 09:15 and 15:30 IST. Prevents trading and
    exit-checks on stale/frozen quotes outside market hours."""
    now = _ist_now()
    if now.weekday() >= 5:          # 5=Sat, 6=Sun
        return False
    hm = (now.hour, now.minute)
    return MARKET_OPEN <= hm <= MARKET_CLOSE


def _in_squareoff_window():
    """True between 15:20 and 15:30 IST - square off while quotes are still live."""
    now = _ist_now()
    if now.weekday() >= 5:
        return False
    hm = (now.hour, now.minute)
    return SQUARE_OFF <= hm <= MARKET_CLOSE


def _today_realised_pnl():
    """Today's realised P&L for FNO_PAPER_STUDY (closed trades, IST date). Drives
    the daily loss cap; resets automatically when the date rolls over."""
    try:
        today = _ist_now().strftime("%Y-%m-%d")
        c = sqlite3.connect(TRADES_DB, timeout=5)
        row = c.execute(
            "SELECT COALESCE(SUM(pnl),0) FROM paper_trades "
            "WHERE strategy=? AND status='CLOSED' AND substr(entry_ts,1,10)=?",
            (STRATEGY_TAG, today)).fetchone()
        c.close()
        return float(row[0] or 0)
    except Exception as e:
        log.debug(f"daily pnl read skipped: {e}")
        return 0.0


def _get_hwm():
    """Read the signal-id high-water-mark; signals at/below this are ignored."""
    try:
        return int(open(HWM_FILE).read().strip())
    except Exception:
        return None


def _set_hwm(value):
    try:
        open(HWM_FILE, "w").write(str(int(value)))
    except Exception as e:
        log.warning(f"could not write HWM: {e}")


def _init_hwm():
    """On first run, set HWM = current max(id) in fno_signals so the entire
    existing backlog is ignored and we only trade NEW signals from now on.
    If HWM already exists, keep it (survives restarts)."""
    existing = _get_hwm()
    if existing is not None:
        log.info(f"HWM exists: only trading signals with id > {existing}")
        return existing
    try:
        c = sqlite3.connect(EVENTS_DB, timeout=5)
        row = c.execute("SELECT COALESCE(MAX(id),0) FROM fno_signals").fetchone()
        c.close()
        hwm = int(row[0] or 0)
    except Exception:
        hwm = 0
    _set_hwm(hwm)
    log.info(f"HWM initialised at {hwm}: backlog ignored, trading forward only")
    return hwm


def _batch_ltp(kite, symbols):
    """Fetch LTP for many NFO symbols in batched calls (Kite allows ~500/call).
    Returns {tradingsymbol: last_price}. One call replaces hundreds."""
    out = {}
    uniq = list({s for s in symbols if s})
    CHUNK = 200
    for i in range(0, len(uniq), CHUNK):
        batch = uniq[i:i + CHUNK]
        keys = [f"NFO:{s}" for s in batch]
        try:
            q = kite.ltp(keys)
            for s in batch:
                k = f"NFO:{s}"
                if k in q and q[k].get("last_price"):
                    out[s] = float(q[k]["last_price"])
        except Exception as e:
            log.warning(f"batch LTP failed ({len(batch)} syms): {e}")
        time.sleep(0.35)  # gentle pause between batches, stays under rate limit
    return out


def manage_open_positions(kite, get_open, record_exit):
    """
    Close OPEN FNO_PAPER_STUDY trades on target/stop/square-off.
    Uses ONE batched LTP call for all positions (not one-per-trade) to avoid
    Kite rate-limiting, which was starving exits.
    """
    try:
        opens = get_open()
    except Exception as e:
        log.error(f"get_open_paper_trades failed: {e}")
        return 0

    # square-off only inside the live 15:20-15:30 window (quotes still real).
    # After 15:30 the monitor does not run at all (see main loop), so no
    # position is ever closed on a stale/frozen quote.
    squareoff = _in_squareoff_window()

    # collect our open positions first
    mine = []
    for t in opens:
        g = (lambda k: t[k] if isinstance(t, dict) else t[k])
        try:
            if g("strategy") != STRATEGY_TAG:
                continue
            tid = g("trade_id")
            tsym = g("symbol")
            entry = float(g("entry_price") or 0)
            if entry <= 0 or not tsym:
                continue
            mine.append((tid, tsym, entry))
        except Exception:
            continue

    if not mine:
        return 0

    # ONE batched price fetch for everything
    prices = _batch_ltp(kite, [m[1] for m in mine])

    closed = 0
    for tid, tsym, entry in mine:
        ltp = prices.get(tsym)
        if not ltp or ltp <= 0:
            continue
        if ltp > entry * 5 or ltp < entry * 0.05:
            continue  # reject bad/stale quote silently (no log spam at this volume)

        target_px = entry * (1 + TARGET_PCT)
        stop_px = entry * (1 - STOP_PCT)
        reason = None
        exit_px = ltp
        if ltp >= target_px:
            reason, exit_px = "TARGET", round(target_px, 2)
        elif ltp <= stop_px:
            reason, exit_px = "STOP", round(stop_px, 2)
        elif squareoff:
            reason, exit_px = "SQUARE_OFF_1520", round(ltp, 2)

        if not reason:
            continue

        if DRY_RUN:
            log.info(f"[DRY] WOULD CLOSE {tsym} id={tid} @{exit_px:.2f} "
                     f"reason={reason} (entry {entry:.2f}, ltp {ltp:.2f})")
            closed += 1
            continue
        try:
            record_exit(trade_id=tid, exit_price=exit_px, exit_reason=reason)
            log.info(f"CLOSED {tsym} id={tid} @{exit_px:.2f} reason={reason} (ltp {ltp:.2f})")
            closed += 1
        except Exception as e:
            log.error(f"record_exit failed {tsym} id={tid}: {e}")
    return closed


def _count_open_positions(get_open):
    """Number of OPEN FNO_PAPER_STUDY positions right now (for the position cap)."""
    n = 0
    if not get_open:
        return 0
    try:
        for t in get_open():
            g = (lambda k: t[k] if isinstance(t, dict) else t[k])
            if g("strategy") == STRATEGY_TAG:
                n += 1
    except Exception:
        pass
    return n


def _open_underlying_dirs(get_open):
    """Return set of (UNDERLYING, DIRECTION) that currently have an OPEN
    FNO_PAPER_STUDY position. Used to enforce ONE position per underlying+
    direction at a time (no stacking the same signal repeatedly)."""
    s = set()
    if not get_open:
        return s
    try:
        for t in get_open():
            g = (lambda k: t[k] if isinstance(t, dict) else t[k])
            if g("strategy") != STRATEGY_TAG:
                continue
            meta = g("meta_json") if "meta_json" in (t.keys() if isinstance(t, dict) else t.keys()) else ""
            und = direc = ""
            try:
                m = json.loads(meta) if meta else {}
                und = (m.get("underlying") or "").upper()
                direc = (m.get("direction") or "").upper()
            except Exception:
                pass
            if und and direc:
                s.add((und, direc))
    except Exception as e:
        log.warning(f"open-set build failed: {e}")
    return s


def _record_outcome(sym, pattern, direction, score, status, reason, tsym="", premium=0.0):
    """Record EVERY signal's outcome (PLACED or SKIPPED + why) so the table
    can answer 'which traded, which failed, and why'."""
    try:
        c = sqlite3.connect(EVENTS_DB, timeout=3)
        c.execute("CREATE TABLE IF NOT EXISTS fno_outcomes ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT, ts_utc TEXT, symbol TEXT, "
                  "pattern TEXT, direction TEXT, score REAL, option_symbol TEXT, "
                  "premium REAL, status TEXT, reason TEXT)")
        c.execute("INSERT INTO fno_outcomes "
                  "(ts_utc,symbol,pattern,direction,score,option_symbol,premium,status,reason) "
                  "VALUES (?,?,?,?,?,?,?,?,?)",
                  (datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S'),
                   sym, pattern, direction, score, tsym, premium, status, reason))
        c.commit(); c.close()
    except Exception as e:
        log.debug(f"outcome record skipped: {e}")


def place_signal(kite, paper_place_order, sig, open_set=None):
    """sig is a dict row from fno_signals. Returns True if placed/dry-logged.
    open_set: set of (UNDERLYING,DIRECTION) already open - skip if present."""
    sym = sig["symbol"]
    direction = (sig["direction"] or "").upper()
    score = sig["score"]
    pattern = sig["pattern"]

    # signal-source filter: keep this lane to only the patterns it owns
    pu = str(pattern or "").upper()
    if PATTERN_INCLUDE and not pu.startswith(PATTERN_INCLUDE):
        return False   # silently skip (other lane's signal); HWM still advances
    if PATTERN_EXCLUDE and pu.startswith(PATTERN_EXCLUDE):
        return False

    # hard skip: underlyings whose spot/ATM can't be resolved reliably
    if sym.upper() in SKIP_UNDERLYINGS:
        _record_outcome(sym, pattern, direction, score, "SKIPPED", "excluded_underlying")
        return False

    opt_type = "CE" if direction == "BULLISH" else "PE" if direction == "BEARISH" else None
    if opt_type is None:
        _record_outcome(sym, pattern, direction, score, "SKIPPED", "non_directional")
        return False

    if sym in INDEX_SET and not STUDY_INDICES:
        _record_outcome(sym, pattern, direction, score, "SKIPPED", "index_excluded")
        return False
    is_index = sym in INDEX_SET

    # ONE position per underlying+direction: skip if already holding one open
    if open_set is not None and (sym.upper(), direction) in open_set:
        _record_outcome(sym, pattern, direction, score, "SKIPPED", "already_open")
        return False

    resolved = resolve_atm_option(kite, sym, opt_type, is_index=is_index)
    if not resolved:
        _record_outcome(sym, pattern, direction, score, "SKIPPED", f"{opt_type}_unresolved")
        return False
    tsym, lot, premium = resolved

    # fixed rupee sizing: skip if one lot is too expensive, else buy ~TRADE_BUDGET
    lot_cost = premium * lot
    if lot_cost > MAX_LOT_COST:
        _record_outcome(sym, pattern, direction, score, "SKIPPED",
                        f"lot_cost_{int(lot_cost)}_over_max", tsym, premium)
        return False
    n_lots = max(1, round(TRADE_BUDGET / lot_cost)) if lot_cost > 0 else 1
    qty = n_lots * lot

    sl_limit = round(premium * (1 - STOP_PCT), 2)     # -30%
    target = round(premium * (1 + TARGET_PCT), 2)     # +50%

    if DRY_RUN:
        log.info(
            f"[DRY] WOULD BUY {tsym} qty={qty} ({n_lots}lot) @~{premium:.2f} "
            f"~Rs{int(qty*premium)} (tgt {target:.2f} / sl {sl_limit:.2f}) "
            f"sig={sym}/{pattern}/{direction}/score={score}"
        )
        return True

    try:
        oid = paper_place_order(
            strategy=STRATEGY_TAG,
            signal_source=f"{pattern}/{direction}",
            symbol=tsym,
            exchange="NFO",
            product="MIS",          # intraday; squared off same day
            side="BUY",
            qty=qty,
            price=premium,
            order_type="MARKET",
            tag=STRATEGY_TAG,
            sl_trigger=sl_limit,
            sl_limit=sl_limit,
            time_stop_days=0,       # 0 = intraday, square-off handled by us
            meta={
                "study": "fno_paper",
                "underlying": sym,
                "signal_type": pattern,
                "direction": direction,
                "score": score,
                "entry_premium": premium,
                "lots": n_lots,
                "notional": round(qty * premium, 2),
                "target": target,
                "stop": sl_limit,
            },
        )
        log.info(f"PLACED {tsym} qty={qty} ({n_lots}lot) @{premium:.2f} "
                 f"~Rs{int(qty*premium)} id={oid} [{pattern}]")
        _record_outcome(sym, pattern, direction, score, "PLACED", "ok", tsym, premium)
        return True
    except Exception as e:
        log.error(f"place failed {sym}/{tsym}: {e}")
        _record_outcome(sym, pattern, direction, score, "FAILED", str(e)[:80], tsym, premium)
        return False


# --- signal reader ----------------------------------------------------------
def fetch_new_signals(hwm):
    """Read fno_signals with id > hwm and score >= min; mark them consumed and
    advance the hwm so the backlog is never re-processed and nothing trades
    twice. Returns (rows, new_hwm)."""
    try:
        c = sqlite3.connect(EVENTS_DB, timeout=5)
        c.row_factory = sqlite3.Row
        c.execute("CREATE TABLE IF NOT EXISTS fno_signals ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT, ts_utc TEXT, symbol TEXT, "
                  "direction TEXT, pattern TEXT, score REAL, spot_change_pct REAL, "
                  "ce_oi_change_pct REAL, pe_oi_change_pct REAL, mode TEXT, "
                  "consumed INTEGER DEFAULT 0)")
        rows = c.execute(
            "SELECT * FROM fno_signals WHERE id>? AND score>=? "
            "ORDER BY id ASC LIMIT 100", (hwm, OI_SIGNAL_MIN_SCORE)
        ).fetchall()
        c.close()
        new_hwm = rows[-1]["id"] if rows else hwm
        return [dict(r) for r in rows], new_hwm
    except Exception as e:
        log.error(f"fetch_new_signals failed: {e}")
        return [], hwm


# --- main loop --------------------------------------------------------------
def main():
    _load_env()
    log.info(f"FNO paper study starting. DRY_RUN={DRY_RUN} "
             f"(set FNO_STUDY_RECORD=1 to RECORD paper trades (still simulated, never real))")
    _lane = (f"INCLUDE={PATTERN_INCLUDE}" if PATTERN_INCLUDE else
             f"EXCLUDE={PATTERN_EXCLUDE}" if PATTERN_EXCLUDE else "ALL signals")
    log.info(f"LANE: tag={STRATEGY_TAG} | source filter={_lane} | hwm={HWM_FILE}")
    log.info(f"daily loss cap: {MAX_DAILY_LOSS:.0f} rupees (0=off) - halts new trades "
             f"for the day if hit, resumes next day. Set FNO_MAX_DAILY_LOSS to change.")
    log.info(f"max simultaneous positions: {MAX_POSITIONS if MAX_POSITIONS>0 else 'UNLIMITED'} "
             f"(set FNO_MAX_POSITIONS to bound the batch)")
    log.info(f"R:R = +{TARGET_PCT*100:.0f}% target / -{STOP_PCT*100:.0f}% stop "
             f"(break-even win rate {STOP_PCT/(STOP_PCT+TARGET_PCT)*100:.0f}%) | "
             f"size ~Rs{TRADE_BUDGET:.0f}/trade, skip if 1 lot > Rs{MAX_LOT_COST:.0f}")
    try:
        kite = get_kite()
        log.info("Kite session established")
    except Exception as e:
        log.error(f"Kite login failed: {e}")
        sys.exit(1)

    paper_place_order = None
    get_open = record_exit = None
    if not DRY_RUN:
        try:
            paper_place_order = _import_paper_trader()
            get_open, record_exit = _import_exit_helpers()
            log.info("paper_trader place + exit helpers imported")
        except Exception as e:
            log.error(f"cannot import paper_trader helpers: {e}")
            sys.exit(1)
    else:
        # In dry-run we still try to import the open-trades reader so the
        # monitor can show WOULD-CLOSE lines if any positions exist.
        try:
            get_open, record_exit = _import_exit_helpers()
        except Exception:
            get_open = record_exit = None

    # high-water-mark: ignore the entire existing backlog, trade forward only
    hwm = _init_hwm()

    last_closed_msg = 0
    halt_logged_day = None
    while True:
        try:
            if not _market_open_now():
                # outside market hours: do nothing (no stale-quote exits, no
                # entries). Log once every ~10 min so the log isn't silent.
                if time.time() - last_closed_msg > 600:
                    log.info("market closed - idle (no trading/exits outside 09:15-15:30 IST Mon-Fri)")
                    last_closed_msg = time.time()
                time.sleep(POLL_SECONDS)
                continue

            refresh_token(kite)   # pick up the daily-refreshed Kite token

            # 1) MANAGE EXITS FIRST (batched price call; live quotes only)
            if get_open and record_exit:
                n = manage_open_positions(kite, get_open, record_exit)
                if n:
                    log.info(f"exits this cycle: {n}")

            # 2) daily loss cap (inversion: stop the bad day before it compounds)
            halted = False
            if get_open and MAX_DAILY_LOSS > 0:
                realised = _today_realised_pnl()
                if realised <= -abs(MAX_DAILY_LOSS):
                    halted = True
                    today = _ist_now().strftime("%Y-%m-%d")
                    if halt_logged_day != today:
                        log.warning(f"[RISK] daily loss cap hit (realised {realised:.0f} "
                                    f"<= -{MAX_DAILY_LOSS:.0f}) - NO new trades today")
                        halt_logged_day = today

            # 3) place new signals (id > hwm only), one per underlying+direction
            open_set = _open_underlying_dirs(get_open) if get_open else set()
            sigs, hwm = fetch_new_signals(hwm)
            if sigs:
                # advance HWM either way so signals seen during a halt are NOT
                # re-traded tomorrow when the cap resets (they'd be stale).
                _set_hwm(hwm)
                if halted:
                    log.info(f"[RISK] dropping {len(sigs)} signal(s) - daily loss cap active")
                    for s in sigs:
                        _record_outcome(s["symbol"], s["pattern"], s["direction"],
                                        s["score"], "SKIPPED", "daily_loss_halt")
                else:
                    log.info(f"{len(sigs)} new signal(s) score>={OI_SIGNAL_MIN_SCORE}")
                    open_count = _count_open_positions(get_open)
                    placed = 0
                    for s in sigs:
                        if MAX_POSITIONS > 0 and open_count >= MAX_POSITIONS:
                            log.info(f"[RISK] max positions {MAX_POSITIONS} reached "
                                     f"- skipping remaining signals this cycle")
                            break
                        if place_signal(kite, paper_place_order, s, open_set):
                            placed += 1
                            open_count += 1
                            # add to open_set immediately so a duplicate in the
                            # same batch is also skipped
                            open_set.add((str(s["symbol"]).upper(),
                                          (s["direction"] or "").upper()))
                    log.info(f"cycle: {placed}/{len(sigs)} actioned")
        except Exception as e:
            log.error(f"loop error: {e}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
