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
TOKEN_FILE = f"{HOME}/data/kite_token.json"
ENV_FILE = f"{HOME}/.env"

OI_SIGNAL_MIN_SCORE = 65        # match gir.py
FNO_MIN_DTE = 15                # match gir.py
TARGET_PCT = 0.30               # +30% premium target
STOP_PCT = 0.50                 # -50% premium stop
SQUARE_OFF = (15, 20)           # 15:20 IST square-off (market still open)
MARKET_OPEN = (9, 15)           # 09:15 IST
MARKET_CLOSE = (15, 30)         # 15:30 IST
POLL_SECONDS = 30               # signal poll + position monitor cadence
STRATEGY_TAG = "FNO_PAPER_STUDY"
# High-water-mark: only trade signals with id strictly greater than this.
# Set at startup to current max(id) so the backlog is ignored and we only
# trade signals generated from launch forward (clean forward test).
HWM_FILE = "/home/globalbot/fno_study_hwm.txt"

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


# --- Kite login: self-healing (mirrors gir.py login) ------------------------
# Strategy: (1) try today's saved token from kite_token.json and validate with
# profile(); (2) on any failure, do a full fresh TOTP login exactly like the
# main bot and write the token back. This makes the study immune to stale
# tokens - it can mint its own session and never lose a trading day.

def _today_ist_str():
    return _ist_now().strftime("%Y-%m-%d")


def _load_token_file():
    try:
        d = json.load(open(TOKEN_FILE))
        return (d.get("date") or "").strip(), (d.get("access_token") or "").strip()
    except Exception:
        return "", ""


def _save_token_file(token):
    try:
        os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
        json.dump({"date": _today_ist_str(), "access_token": token}, open(TOKEN_FILE, "w"))
    except Exception as e:
        log.warning(f"could not write token file: {e}")


def _fresh_totp_login(api_key):
    """Full TOTP login, copied from gir.py's proven flow. Returns access_token."""
    import requests, pyotp
    from kiteconnect import KiteConnect
    user_id = os.environ.get("ZERODHA_USER_ID", "").strip()
    password = os.environ.get("ZERODHA_PASSWORD", "").strip()
    totp_secret = os.environ.get("KITE_TOTP_SECRET", "").strip()
    api_secret = os.environ.get("KITE_API_SECRET", "").strip()
    if not (user_id and password and totp_secret and api_secret and api_key):
        raise RuntimeError("missing Zerodha/Kite creds in env for TOTP login")

    kite = KiteConnect(api_key=api_key)
    s = requests.Session()
    s.headers.update({"User-Agent": "Mozilla/5.0"})
    # step 1: password login -> request_id
    r1 = s.post("https://kite.zerodha.com/api/login",
                data={"user_id": user_id, "password": password}, timeout=30)
    if r1.status_code != 200:
        raise RuntimeError(f"login step1 failed: {r1.status_code}")
    request_id = r1.json().get("data", {}).get("request_id", "")
    if not request_id:
        raise RuntimeError("no request_id from step1")
    # step 2: TOTP twofa
    time.sleep(1)
    totp = pyotp.TOTP(totp_secret).now()
    r2 = s.post("https://kite.zerodha.com/api/twofa",
                data={"user_id": user_id, "request_id": request_id,
                      "twofa_value": totp, "twofa_type": "totp"},
                timeout=30, allow_redirects=True)
    final_url = r2.url
    if "request_token=" not in final_url:
        if r2.status_code == 200 and "status" in r2.text:
            r3 = s.get(kite.login_url(), allow_redirects=True, timeout=30)
            final_url = r3.url
    if "request_token=" not in final_url:
        raise RuntimeError(f"no request_token in redirect: {final_url[:100]}")
    request_token = final_url.split("request_token=")[1].split("&")[0]
    data = kite.generate_session(request_token, api_secret=api_secret)
    access_token = data.get("access_token", "")
    if not access_token:
        raise RuntimeError("no access_token from generate_session")
    return access_token


def get_kite():
    """Return an authenticated KiteConnect. Tries today's saved token, validates
    it, and on any failure mints a fresh one via TOTP and saves it."""
    from kiteconnect import KiteConnect
    api_key = os.environ.get("KITE_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("KITE_API_KEY missing")

    # (1) try saved token, but only if it's dated today
    saved_date, saved_token = _load_token_file()
    if saved_token and saved_date == _today_ist_str():
        k = KiteConnect(api_key=api_key)
        k.set_access_token(saved_token)
        try:
            who = k.profile().get("user_name", "?")
            log.info(f"Kite: reused saved token ({who})")
            return k
        except Exception:
            log.info("Kite: saved token invalid, doing fresh TOTP login")

    # (2) fresh TOTP login
    token = _fresh_totp_login(api_key)
    _save_token_file(token)
    k = KiteConnect(api_key=api_key)
    k.set_access_token(token)
    log.info(f"Kite: fresh TOTP login OK ({k.profile().get('user_name','?')})")
    return k


def _ensure_session(kite, _state={"last": 0}):
    """Validate the live session every ~5 min; if dead, re-login in place so a
    token that expired mid-run (or was stale at startup) self-heals."""
    if time.time() - _state["last"] < 300:
        return kite
    _state["last"] = time.time()
    try:
        kite.profile()
        return kite
    except Exception:
        log.warning("Kite session dead - re-logging in")
        try:
            return get_kite()
        except Exception as e:
            log.error(f"re-login failed: {e}")
            return kite  # keep old; next cycle retries


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

    sl_limit = round(premium * (1 - STOP_PCT), 2)     # -50%
    target = round(premium * (1 + TARGET_PCT), 2)     # +30%

    if DRY_RUN:
        log.info(
            f"[DRY] WOULD BUY {tsym} qty={lot} @~{premium:.2f} "
            f"(tgt {target:.2f} / sl {sl_limit:.2f}) "
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
            qty=lot,
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
                "target": target,
                "stop": sl_limit,
            },
        )
        log.info(f"PLACED {tsym} qty={lot} @{premium:.2f} id={oid} [{pattern}]")
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

            # keep the Kite session alive (re-login if token died/stale)
            kite = _ensure_session(kite)

            # 1) MANAGE EXITS FIRST (batched price call; live quotes only)
            if get_open and record_exit:
                n = manage_open_positions(kite, get_open, record_exit)
                if n:
                    log.info(f"exits this cycle: {n}")

            # 2) place new signals (id > hwm only), one per underlying+direction
            open_set = _open_underlying_dirs(get_open) if get_open else set()
            sigs, hwm = fetch_new_signals(hwm)
            if sigs:
                _set_hwm(hwm)
                log.info(f"{len(sigs)} new signal(s) score>={OI_SIGNAL_MIN_SCORE}")
                placed = 0
                for s in sigs:
                    if place_signal(kite, paper_place_order, s, open_set):
                        placed += 1
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
