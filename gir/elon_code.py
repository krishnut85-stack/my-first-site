#!/usr/bin/env python3
"""
elon_code.py  -  "ELON CODE": Standalone Zerodha Kite INTRADAY stock paper bot
============================================================================
A separate, self-contained paper-trading bot for CASH equities (Nifty 500),
built on INVERSION THINKING: its first job is to NOT lose, and only then to win.

  "Rather than trying to win, avoid losing."  - Charlie Munger

It does NOT depend on gir.py. It scans prices itself, and it reuses only the
bot's existing Kite login pattern + paper_trader.py for simulated fills.

STRATEGY (the one edge that actually works for you: mean reversion)
------------------------------------------------------------------
Buy WEAKNESS, never chase strength. A quality stock that dips below its day
VWAP and then STARTS TO TURN BACK UP is bought for the snap back toward VWAP.
We never buy a stock that has already run up (that is what bled the F&O lane),
and we never catch a falling knife (a stock crashing on bad news).

INVERSION / AVOID-LOSING RISK RULES (premeditatio malorum)
----------------------------------------------------------
  - HARD per-trade stop, set BEFORE entry.
  - DAILY LOSS CAP: once today's realised P&L hits the cap, STOP for the day.
  - Max concurrent positions, max trades/day, one position per symbol.
  - Falling-knife filter: skip anything down more than EQ_KNIFE_PCT on the day.
  - Long only (shorting is an extra way to lose; excluded in v1).
  - Square off everything by 15:15 IST. Nothing held overnight.
  - If nothing is a clean low-risk setup, it does NOTHING. Cash is a position.

SAFETY: DRY_RUN by default (logs WOULD-BUY/SELL, places nothing). Set
EQ_STUDY_RECORD=1 to record simulated paper trades (still never real money).

Login: same pattern as the rest of the bot - daily token file, falls back to .env.
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

# --- paths ------------------------------------------------------------------
HOME = "/home/globalbot"
EVENTS_DB = f"{HOME}/paper/events.db"
TRADES_DB = f"{HOME}/paper/trades.db"
TOKEN_FILE = f"{HOME}/data/kite_token.json"
ENV_FILE = f"{HOME}/.env"
UNIVERSE_FILE = os.environ.get("EQ_UNIVERSE_FILE", f"{HOME}/data/nifty500.txt")

STRATEGY_TAG = "ELON_CODE"

# --- timing -----------------------------------------------------------------
MARKET_OPEN = (9, 15)
MARKET_CLOSE = (15, 30)
# Square-off time (env EQ_SQUAREOFF="HH:MM"). Default 15:00 - flatten before the
# closing-rush volatility, not at 15:15.
try:
    _eqso = os.environ.get("EQ_SQUAREOFF", "15:00").strip()
    SQUARE_OFF = (int(_eqso.split(":")[0]), int(_eqso.split(":")[1]))
except Exception:
    SQUARE_OFF = (15, 0)
SQUAREOFF_REASON = f"SQUARE_OFF_{SQUARE_OFF[0]:02d}{SQUARE_OFF[1]:02d}"
NO_NEW_ENTRY_AFTER = (14, 45)    # stop opening new trades late in the day
# Skip the chaotic opening minutes: the day's low forms in the first 30 min ~27%
# of the time, and VWAP reversion is most reliable AFTER the open. (evidence-based)
NO_NEW_ENTRY_BEFORE = (9, 45)
POLL_SECONDS = int(os.environ.get("EQ_POLL_SECONDS", "60"))

# --- market-regime filter (THE biggest profit lever for mean reversion) -----
# Mean reversion works in choppy markets and bleeds in trends. So we do NOT buy
# dips when the broad market (NIFTY 50) is itself selling off hard - that is a
# market-wide knife, not a single-stock dip. (inversion: don't fight the tide.)
REGIME_INDEX = os.environ.get("EQ_REGIME_INDEX", "NSE:NIFTY 50")
REGIME_DOWN_PCT = float(os.environ.get("EQ_REGIME_DOWN_PCT", "0.75"))  # index down > this % -> block new longs

# --- mean-reversion setup knobs --------------------------------------------
# Stock must be at least this % BELOW its day VWAP to be "stretched" (a dip).
STRETCH_MIN_PCT = float(os.environ.get("EQ_STRETCH_MIN_PCT", "0.5"))
# Falling-knife guard: skip if the stock is down MORE than this % on the day
# (that is a news disaster, not a dip - inversion: avoid the obvious blow-up).
KNIFE_PCT = float(os.environ.get("EQ_KNIFE_PCT", "4.0"))
# Liquidity floor: day turnover (last * volume) must clear this (rupees).
MIN_TURNOVER = float(os.environ.get("EQ_MIN_TURNOVER", "20000000"))   # ~2 cr
# Confirmation: after arming, price must tick back UP this % off the low we saw
# before we buy (don't buy while it is still falling).
CONFIRM_PCT = float(os.environ.get("EQ_CONFIRM_PCT", "0.15"))
# Max poll cycles to wait for the turn before abandoning the setup (no trade).
ARM_MAX_CYCLES = int(os.environ.get("EQ_ARM_MAX_CYCLES", "30"))

# --- TREND FILTER (the #1 mean-reversion fix; default ON) -------------------
# Mean reversion BLEEDS when you buy dips in DOWN-trending stocks (slow knives
# that never bounce and quietly stop you out). So only dip-buy a stock still in
# an UPTREND: its latest DAILY close above its long SMA. This single change is
# exactly what turned the Phoenix lane profitable. Set EQ_TREND_FILTER=0 to
# revert to the old "buy any dip" behaviour.
TREND_FILTER = os.environ.get("EQ_TREND_FILTER", "1").strip() == "1"
TREND_SMA = int(os.environ.get("EQ_TREND_SMA", "50"))     # daily SMA for the uptrend test
TREND_HIST_BARS = int(os.environ.get("EQ_TREND_BARS", "80"))
_TREND_CACHE = {}   # sym -> (date_str, in_uptrend); one daily-bar fetch per stock/day

# --- exits ------------------------------------------------------------------
# Zerodha intraday round-trip cost is ~0.11% of the position (brokerage + STT +
# exchange + stamp + GST). So the target must clear that AND give a healthy
# reward:risk. +1.5% nets ~+1.39% after charges, vs the 0.8% stop -> ~1.6:1.
# (Income tax on intraday profit is separate: slab-rate on net annual profit.)
# A bigger target is hit less often - paper-test 1.0 vs 1.5 vs 2.0 to compare.
TARGET_PCT = float(os.environ.get("EQ_TARGET_PCT", "1.5"))   # +1.5% take-profit
STOP_PCT = float(os.environ.get("EQ_STOP_PCT", "0.8"))       # -0.8% hard stop

# --- inversion risk caps ----------------------------------------------------
# Per user: Elon takes EVERY good signal - no position-count or trades/day cap.
# A trade still needs a size to compute share qty, so PER_TRADE_NOTIONAL stays.
# The DAILY LOSS CAP is deliberately KEPT as the single remaining brake (the
# core inversion safeguard): one bad day still halts trading for the day.
PER_TRADE_NOTIONAL = float(os.environ.get("EQ_PER_TRADE_NOTIONAL", "100000"))  # rupees/position
MAX_POSITIONS = int(os.environ.get("EQ_MAX_POSITIONS", "0"))        # 0 = UNLIMITED
MAX_TRADES_PER_DAY = int(os.environ.get("EQ_MAX_TRADES_PER_DAY", "0"))  # 0 = UNLIMITED
MAX_DAILY_LOSS = float(os.environ.get("EQ_MAX_DAILY_LOSS", "20000"))   # rupees; halt for TODAY only
# NOTE: the halt is computed from TODAY's realised P&L only (date-based query),
# so when the date rolls over the loss resets to 0 and trading RESUMES next day.

# --- sector concentration cap (tail-risk insurance, not a profit booster) ----
# With unlimited positions, a sector-wide selloff could open many correlated
# longs that all lose together. Cap how many open positions share a sector.
# (inversion: don't let one sector's bad hour sink the whole day.)
SECTOR_FILE = os.environ.get("EQ_SECTOR_FILE", f"{HOME}/data/nifty500_sectors.csv")
MAX_PER_SECTOR = int(os.environ.get("EQ_MAX_PER_SECTOR", "3"))   # 0 = unlimited
SECTOR_MAP = {}   # symbol -> sector, loaded at startup from SECTOR_FILE

DRY_RUN = os.environ.get("EQ_STUDY_RECORD", "0").strip() != "1"

# Fallback universe if the Nifty 500 file is missing (liquid large caps so the
# bot still runs). Replace by dropping a full nifty500.txt at UNIVERSE_FILE.
FALLBACK_UNIVERSE = [
    "RELIANCE", "TCS", "HDFCBANK", "ICICIBANK", "INFY", "SBIN", "BHARTIARTL",
    "ITC", "LT", "KOTAKBANK", "AXISBANK", "HINDUNILVR", "BAJFINANCE", "MARUTI",
    "SUNPHARMA", "TATAMOTORS", "TATASTEEL", "WIPRO", "ONGC", "POWERGRID",
    "NTPC", "ULTRACEMCO", "TITAN", "ASIANPAINT", "HCLTECH", "ADANIPORTS",
    "COALINDIA", "JSWSTEEL", "GRASIM", "DRREDDY", "CIPLA", "BPCL", "BAJAJFINSV",
    "TECHM", "NESTLEIND", "HINDALCO", "DIVISLAB", "BRITANNIA", "EICHERMOT",
    "HEROMOTOCO", "INDUSINDBK", "M&M", "SBILIFE", "HDFCLIFE", "APOLLOHOSP",
    "TATACONSUM", "UPL", "BAJAJ-AUTO", "SHREECEM", "PIDILITIND",
]

# --- logging ----------------------------------------------------------------
logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [ELON_CODE] %(levelname)s %(message)s")
log = logging.getLogger("elon_code")


# --- .env loader ------------------------------------------------------------
def _load_env():
    try:
        from dotenv import load_dotenv
        load_dotenv(ENV_FILE)
    except Exception:
        try:
            for line in open(ENV_FILE):
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())
        except Exception as e:
            log.warning(f".env load failed: {e}")


# --- Kite login (same pattern as the rest of the bot) -----------------------
def get_kite():
    from kiteconnect import KiteConnect
    api_key = os.environ.get("KITE_API_KEY", "").strip()
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


# Kite access tokens expire DAILY. The main bot rewrites kite_token.json each
# morning; we must re-read it or our session goes stale (was: "Incorrect
# api_key or access_token" + no quotes all day). Reload whenever the file changes.
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


# --- paper_trader helpers ---------------------------------------------------
def _import_paper_helpers():
    sys.path.insert(0, f"{HOME}/paper")
    from paper_trader import (paper_place_order, get_open_paper_trades,
                              paper_record_exit)
    return paper_place_order, get_open_paper_trades, paper_record_exit


# --- universe ---------------------------------------------------------------
def load_universe():
    """One symbol per line in UNIVERSE_FILE (Nifty 500). Falls back to a built-in
    liquid list so the bot always runs. Lines starting with # are ignored."""
    syms = []
    try:
        with open(UNIVERSE_FILE) as f:
            for line in f:
                s = line.strip().upper()
                if s and not s.startswith("#"):
                    syms.append(s)
    except Exception:
        pass
    if syms:
        log.info(f"universe: {len(syms)} symbols from {UNIVERSE_FILE}")
        return syms
    log.warning(f"no universe file at {UNIVERSE_FILE} - using {len(FALLBACK_UNIVERSE)} "
                f"fallback large caps. Drop a nifty500.txt there for the full list.")
    return list(FALLBACK_UNIVERSE)


def load_sector_map():
    """symbol -> sector from a 'SYMBOL,Sector' file (built from the NSE Nifty 500
    list's Industry column). Symbols not in the map are left UNCAPPED (fail-open)."""
    m = {}
    try:
        with open(SECTOR_FILE) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "," not in line:
                    continue
                sym, sec = line.split(",", 1)
                sym, sec = sym.strip().upper(), sec.strip()
                if sym and sec:
                    m[sym] = sec
    except Exception:
        pass
    return m


def sector_of(sym):
    return SECTOR_MAP.get(sym, "UNKNOWN")


# --- time helpers -----------------------------------------------------------
def _ist_now():
    return datetime.now(IST) if IST else datetime.utcnow()


def _hm():
    n = _ist_now()
    return (n.hour, n.minute)


def _market_open_now():
    n = _ist_now()
    if n.weekday() >= 5:
        return False
    return MARKET_OPEN <= _hm() <= MARKET_CLOSE


def _in_squareoff_window():
    n = _ist_now()
    if n.weekday() >= 5:
        return False
    return SQUARE_OFF <= _hm() <= MARKET_CLOSE


def _entries_allowed_now():
    # only the calm mid-session window: after the open noise, before the close
    return NO_NEW_ENTRY_BEFORE <= _hm() < NO_NEW_ENTRY_AFTER


def _today_str():
    return _ist_now().strftime("%Y-%m-%d")


# --- market data ------------------------------------------------------------
def fetch_quotes(kite, symbols):
    """Batched kite.quote() for the whole universe. Returns
    {SYM: {last, vwap, prev_close, high, low, volume}}. Invalid symbols drop out."""
    out = {}
    CHUNK = 200
    for i in range(0, len(symbols), CHUNK):
        batch = symbols[i:i + CHUNK]
        keys = [f"NSE:{s}" for s in batch]
        try:
            q = kite.quote(keys)
        except Exception as e:
            log.warning(f"quote batch failed ({len(batch)} syms): {e}")
            time.sleep(0.4)
            continue
        for s in batch:
            d = q.get(f"NSE:{s}")
            if not d:
                continue
            ohlc = d.get("ohlc") or {}
            out[s] = {
                "last": float(d.get("last_price") or 0),
                "vwap": float(d.get("average_price") or 0),
                "prev_close": float(ohlc.get("close") or 0),
                "high": float(ohlc.get("high") or 0),
                "low": float(ohlc.get("low") or 0),
                "volume": float(d.get("volume") or 0),
            }
        time.sleep(0.35)   # stay under Kite rate limit
    return out


def regime_blocks_entries(kite):
    """Market-regime filter. Returns (blocked, nifty_change_pct).
    Blocks NEW long entries when NIFTY 50 is down more than REGIME_DOWN_PCT on the
    day (a market-wide selloff). Fails OPEN (no block) if the index can't be read."""
    try:
        q = kite.quote([REGIME_INDEX])
        d = q.get(REGIME_INDEX) or {}
        last = float(d.get("last_price") or 0)
        prev = float((d.get("ohlc") or {}).get("close") or 0)
        if last <= 0 or prev <= 0:
            return False, 0.0
        chg = (last - prev) / prev * 100.0
        return (chg <= -abs(REGIME_DOWN_PCT)), chg
    except Exception as e:
        log.debug(f"regime read failed (fail-open): {e}")
        return False, 0.0


# --- position / risk bookkeeping (read from paper_trades) -------------------
def _my_open_trades(get_open):
    """Open EQ_PAPER_STUDY trades as list of (trade_id, symbol, entry, qty)."""
    mine = []
    try:
        for t in get_open():
            g = (lambda k: t[k] if isinstance(t, dict) else t[k])
            try:
                if g("strategy") != STRATEGY_TAG:
                    continue
                mine.append((g("trade_id"), g("symbol"),
                             float(g("entry_price") or 0), int(g("qty") or 0)))
            except Exception:
                continue
    except Exception as e:
        log.error(f"get_open failed: {e}")
    return mine


def _today_realised_pnl_and_count():
    """(realised_pnl_today, trades_opened_today) for EQ_PAPER_STUDY, from DB.
    Used for the daily loss cap and the per-day trade cap. Date = entry date IST-ish."""
    pnl = 0.0
    count = 0
    try:
        c = sqlite3.connect(TRADES_DB, timeout=5)
        c.row_factory = sqlite3.Row
        like = _today_str() + "%"
        rows = c.execute(
            "SELECT status, COALESCE(pnl,0) pnl FROM paper_trades "
            "WHERE strategy=? AND substr(entry_ts,1,10)=?",
            (STRATEGY_TAG, _today_str())).fetchall()
        c.close()
        for r in rows:
            count += 1
            if r["status"] == "CLOSED":
                pnl += float(r["pnl"] or 0)
    except Exception as e:
        log.debug(f"daily pnl read skipped: {e}")
    return pnl, count


# --- exits ------------------------------------------------------------------
def manage_exits(quotes, get_open, record_exit):
    """Close open EQ trades on target / stop / 15:15 square-off."""
    squareoff = _in_squareoff_window()
    closed = 0
    for tid, sym, entry, qty in _my_open_trades(get_open):
        if entry <= 0:
            continue
        q = quotes.get(sym)
        ltp = q["last"] if q else 0
        if not ltp or ltp <= 0:
            if squareoff:
                pass  # fall through to square-off using last known? skip if no price
            continue
        target_px = entry * (1 + TARGET_PCT / 100.0)
        stop_px = entry * (1 - STOP_PCT / 100.0)
        reason = exit_px = None
        if ltp >= target_px:
            reason, exit_px = "TARGET", round(target_px, 2)
        elif ltp <= stop_px:
            reason, exit_px = "STOP", round(stop_px, 2)
        elif squareoff:
            reason, exit_px = SQUAREOFF_REASON, round(ltp, 2)
        if not reason:
            continue
        if DRY_RUN:
            log.info(f"[DRY] WOULD SELL {sym} qty={qty} @{exit_px} reason={reason} "
                     f"(entry {entry:.2f}, ltp {ltp:.2f})")
            closed += 1
            continue
        try:
            record_exit(trade_id=tid, exit_price=exit_px, exit_reason=reason)
            log.info(f"SOLD {sym} qty={qty} @{exit_px} reason={reason} (entry {entry:.2f})")
            closed += 1
        except Exception as e:
            log.error(f"record_exit failed {sym}: {e}")
    return closed


# --- entry: arm + confirm (the mean-reversion pullback) ---------------------
# ARMED[sym] = dict(low_seen, vwap, cycles)
ARMED = {}


def scan_and_arm(quotes, open_syms):
    """Find quality stocks stretched BELOW VWAP and not crashing, and arm them.
    Arming != buying; we still wait for the turn (confirm) in eval_armed()."""
    for sym, q in quotes.items():
        if sym in open_syms or sym in ARMED:
            continue
        last, vwap, prev = q["last"], q["vwap"], q["prev_close"]
        if last <= 0 or vwap <= 0 or prev <= 0:
            continue
        day_change = (last - prev) / prev * 100.0
        below_vwap = (vwap - last) / vwap * 100.0
        turnover = last * q["volume"]
        # mean-reversion dip: red on the day, stretched below VWAP, liquid,
        # but NOT a falling knife (down more than KNIFE_PCT = news blow-up).
        if (below_vwap >= STRETCH_MIN_PCT and day_change <= 0
                and day_change >= -KNIFE_PCT and turnover >= MIN_TURNOVER):
            ARMED[sym] = {"low_seen": min(last, q["low"] or last),
                          "vwap": vwap, "cycles": 0}
            log.info(f"[ARM] {sym} last={last:.2f} vwap={vwap:.2f} "
                     f"({below_vwap:.2f}% below, day {day_change:+.2f}%) - waiting for turn")


def _in_uptrend(kite, sym):
    """Only dip-buy a stock still trending UP: its latest DAILY close above its
    TREND_SMA-day average. Cached once per stock per day to limit Kite calls.
    Fail-OPEN (returns True) if it can't be determined, so a data hiccup never
    silently blocks the whole strategy."""
    if not TREND_FILTER:
        return True
    today = _today_str()
    cached = _TREND_CACHE.get(sym)
    if cached and cached[0] == today:
        return cached[1]
    ok = True
    try:
        import datetime as _dt
        q = kite.ltp([f"NSE:{sym}"]).get(f"NSE:{sym}", {})
        tok = q.get("instrument_token")
        if tok:
            to = _dt.datetime.now()
            frm = to - _dt.timedelta(days=TREND_HIST_BARS * 2 + 10)
            bars = kite.historical_data(tok, frm, to, "day")
            closes = [b["close"] for b in bars]
            if len(closes) >= TREND_SMA:
                sma = sum(closes[-TREND_SMA:]) / TREND_SMA
                ok = closes[-1] > sma
    except Exception as e:  # noqa: BLE001
        log.debug(f"trend check {sym}: {e}")
        ok = True
    _TREND_CACHE[sym] = (today, ok)
    return ok


def eval_armed(kite, quotes, place_order, get_open, halted):
    """Buy an armed stock once it ticks back UP off its low (the turn), if risk
    caps allow. Drop it if it keeps falling, rallies past VWAP, or times out."""
    if not ARMED:
        return 0
    placed = 0
    open_trades = _my_open_trades(get_open)
    open_syms = {t[1] for t in open_trades}
    n_open = len(open_trades)
    realised, n_today = _today_realised_pnl_and_count()
    # how many open positions sit in each sector right now (for the cap)
    sector_counts = {}
    for _t in open_trades:
        _sec = sector_of(_t[1])
        if _sec != "UNKNOWN":
            sector_counts[_sec] = sector_counts.get(_sec, 0) + 1

    for sym in list(ARMED.keys()):
        a = ARMED[sym]
        a["cycles"] += 1
        q = quotes.get(sym)
        if not q or q["last"] <= 0:
            if a["cycles"] >= ARM_MAX_CYCLES:
                del ARMED[sym]
            continue
        last, vwap = q["last"], q["vwap"]
        a["low_seen"] = min(a["low_seen"], last)
        prev = q["prev_close"]
        day_change = (last - prev) / prev * 100.0 if prev else 0

        # abandon conditions (no trade)
        if day_change < -KNIFE_PCT:
            log.info(f"[ARM] {sym} broke down ({day_change:+.2f}%) - abandon (knife)")
            del ARMED[sym]; continue
        if last >= vwap:
            log.info(f"[ARM] {sym} reclaimed VWAP before turn - abandon (no edge left)")
            del ARMED[sym]; continue
        if a["cycles"] >= ARM_MAX_CYCLES:
            log.info(f"[ARM] {sym} no turn in {ARM_MAX_CYCLES} cycles - abandon")
            del ARMED[sym]; continue

        # confirmation: ticked back up off the low, still below VWAP (room to revert)
        turned = last >= a["low_seen"] * (1 + CONFIRM_PCT / 100.0)
        if not turned:
            continue

        # TREND FILTER (the fix): only dip-buy stocks still in an uptrend - don't
        # catch knives in downtrends (the #1 mean-reversion killer).
        if not _in_uptrend(kite, sym):
            log.info(f"[ARM] {sym} below {TREND_SMA}-DMA (downtrend) - abandon (no knife-catching)")
            del ARMED[sym]; continue

        # ---- risk gates (inversion: refuse the trade if any cap is hit) ----
        if halted:
            continue
        if sym in open_syms:
            del ARMED[sym]; continue
        if MAX_POSITIONS > 0 and n_open >= MAX_POSITIONS:
            continue  # keep armed; a slot may free up (only if a cap is set)
        if MAX_TRADES_PER_DAY > 0 and n_today >= MAX_TRADES_PER_DAY:
            log.info(f"[RISK] daily trade cap {MAX_TRADES_PER_DAY} hit - no new entries")
            continue
        sec = sector_of(sym)
        if (MAX_PER_SECTOR > 0 and sec != "UNKNOWN"
                and sector_counts.get(sec, 0) >= MAX_PER_SECTOR):
            log.info(f"[RISK] sector '{sec}' already has {MAX_PER_SECTOR} positions "
                     f"- skip {sym} (avoid correlated bets)")
            continue  # keep armed; a slot may free up when one closes
        if not _entries_allowed_now():
            del ARMED[sym]; continue

        qty = max(1, int(PER_TRADE_NOTIONAL / last))
        entry = round(last, 2)
        stop_px = round(entry * (1 - STOP_PCT / 100.0), 2)
        target_px = round(entry * (1 + TARGET_PCT / 100.0), 2)

        if sec != "UNKNOWN":
            sector_counts[sec] = sector_counts.get(sec, 0) + 1   # reserve the slot

        if DRY_RUN:
            log.info(f"[DRY] WOULD BUY {sym} qty={qty} @~{entry} "
                     f"(tgt {target_px} / sl {stop_px}) turned off low {a['low_seen']:.2f}")
            del ARMED[sym]
            placed += 1; n_open += 1; n_today += 1
            continue
        try:
            oid = place_order(
                strategy=STRATEGY_TAG, signal_source="MEANREV_PULLBACK",
                symbol=sym, exchange="NSE", product="MIS", side="BUY",
                qty=qty, price=entry, order_type="MARKET", tag=STRATEGY_TAG,
                sl_trigger=stop_px, sl_limit=stop_px, time_stop_days=0,
                meta={"study": "equity_meanrev", "vwap": round(vwap, 2),
                      "target": target_px, "stop": stop_px,
                      "low_seen": round(a["low_seen"], 2), "entry_mode": "PULLBACK"})
            log.info(f"BOUGHT {sym} qty={qty} @{entry} id={oid} (tgt {target_px}/sl {stop_px})")
            del ARMED[sym]
            placed += 1; n_open += 1; n_today += 1
        except Exception as e:
            log.error(f"place failed {sym}: {e}")
            del ARMED[sym]
    return placed


# --- main loop --------------------------------------------------------------
def main():
    _load_env()
    log.info(f"=== ELON CODE (inversion mean-reversion equity bot) starting ===")
    log.info(f"DRY_RUN={DRY_RUN} (set EQ_STUDY_RECORD=1 to record simulated trades)")
    _pos = MAX_POSITIONS if MAX_POSITIONS > 0 else "UNLIMITED"
    _tpd = MAX_TRADES_PER_DAY if MAX_TRADES_PER_DAY > 0 else "UNLIMITED"
    log.info(f"RISK: notional/trade={PER_TRADE_NOTIONAL} max_pos={_pos} "
             f"max_trades/day={_tpd} daily_loss_cap={MAX_DAILY_LOSS} (only brake) "
             f"target={TARGET_PCT}% stop={STOP_PCT}%")
    log.info(f"SETUP: buy dips >= {STRETCH_MIN_PCT}% below VWAP, skip knives > {KNIFE_PCT}% down, "
             f"confirm +{CONFIRM_PCT}% off low. Long only, intraday, square-off "
             f"{SQUARE_OFF[0]:02d}:{SQUARE_OFF[1]:02d}.")
    log.info(f"TREND FILTER: {'ON' if TREND_FILTER else 'OFF'} - "
             + (f"only dip-buy stocks ABOVE their {TREND_SMA}-DMA (no knife-catching in downtrends)"
                if TREND_FILTER else "buying ANY dip (old behaviour)"))
    log.info(f"FILTERS: regime=skip new longs when {REGIME_INDEX} down > {REGIME_DOWN_PCT}% | "
             f"entry window {NO_NEW_ENTRY_BEFORE[0]:02d}:{NO_NEW_ENTRY_BEFORE[1]:02d}-"
             f"{NO_NEW_ENTRY_AFTER[0]:02d}:{NO_NEW_ENTRY_AFTER[1]:02d} (skip opening noise) | "
             f"max {MAX_PER_SECTOR} positions/sector")

    try:
        kite = get_kite()
        log.info("Kite session established")
    except Exception as e:
        log.error(f"Kite login failed: {e}")
        sys.exit(1)

    place_order = get_open = record_exit = None
    if not DRY_RUN:
        try:
            place_order, get_open, record_exit = _import_paper_helpers()
            log.info("paper_trader helpers imported")
        except Exception as e:
            log.error(f"cannot import paper_trader: {e}")
            sys.exit(1)
    else:
        try:
            place_order, get_open, record_exit = _import_paper_helpers()
        except Exception:
            place_order = get_open = record_exit = None

    universe = load_universe()
    SECTOR_MAP.update(load_sector_map())
    if SECTOR_MAP:
        _nsec = len(set(SECTOR_MAP.values()))
        log.info(f"sector map: {len(SECTOR_MAP)} symbols across {_nsec} sectors "
                 f"(cap {MAX_PER_SECTOR}/sector) from {SECTOR_FILE}")
    else:
        log.warning(f"no sector map at {SECTOR_FILE} - sector cap DISABLED (all uncapped). "
                    f"Generate it to enable the cap.")
    halt_logged_day = None
    last_idle_msg = 0

    while True:
        try:
            if not _market_open_now():
                ARMED.clear()
                if time.time() - last_idle_msg > 600:
                    log.info("market closed - idle (09:15-15:30 IST Mon-Fri only)")
                    last_idle_msg = time.time()
                time.sleep(POLL_SECONDS)
                continue

            refresh_token(kite)   # pick up the daily-refreshed Kite token
            quotes = fetch_quotes(kite, universe)
            if not quotes:
                log.warning("no quotes this cycle")
                time.sleep(POLL_SECONDS)
                continue

            # 1) EXITS first (target/stop/square-off)
            if get_open and record_exit:
                manage_exits(quotes, get_open, record_exit)

            # 2) daily loss cap (inversion: stop the bad day before it compounds)
            halted = False
            if get_open:
                realised, n_today = _today_realised_pnl_and_count()
                if realised <= -abs(MAX_DAILY_LOSS):
                    halted = True
                    if halt_logged_day != _today_str():
                        log.warning(f"[RISK] daily loss cap hit (realised {realised:.0f} "
                                    f"<= -{MAX_DAILY_LOSS:.0f}) - NO new entries today")
                        halt_logged_day = _today_str()

            # 2b) market-regime filter: don't buy dips into a market-wide selloff
            regime_block, nifty_chg = regime_blocks_entries(kite)
            if regime_block:
                log.info(f"[REGIME] NIFTY 50 {nifty_chg:+.2f}% (<= -{REGIME_DOWN_PCT}%) "
                         f"- market selling off, no new longs this cycle")
                ARMED.clear()   # don't sit on stale dips during a downtrend

            # entries are blocked by either the loss cap OR a risk-off market
            entry_block = halted or regime_block

            # 3) buy armed setups that confirmed the turn
            open_syms = {t[1] for t in _my_open_trades(get_open)} if get_open else set()
            eval_armed(kite, quotes, place_order, get_open, entry_block)

            # 4) scan for new dips to arm (every good signal; no position cap unless set)
            if (not entry_block and _entries_allowed_now()
                    and (MAX_POSITIONS <= 0 or len(open_syms) < MAX_POSITIONS)):
                scan_and_arm(quotes, open_syms)

        except Exception as e:
            log.error(f"loop error: {e}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
