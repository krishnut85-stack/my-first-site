#!/usr/bin/env python3
# =============================================================================
#  gir_eq_floor.py  —  GIR equity sub-lane "GIR_EQ_FLOOR"  (Phoenix)
#  High-win-rate oversold-floor entry + FIXED TARGET exit (no trail).
#  Lives at /home/globalbot/gir_eq_floor.py (beside gir.py + paper/ package).
#
#  Wiring (confirmed against live tree 2026-06):
#    - session  : KiteSession.kite() from gir.py (shared saved-token)
#    - orders   : paper.paper_trader.paper_place_order / paper_record_exit
#    - state    : get_open_paper_trades()  (no private DB)
#    - budget   : OWN equal bucket FLOOR_CAPITAL, capped at FLOOR_MAX_POS
#    - exits    : OWNED HERE. paper_exit_monitor must SKIP GIR_EQ_FLOOR.
#  Paper-safe: only places real orders if PHOENIX_LIVE and GIR_PAPER_MODE!=1.
#
#  ── IMPROVEMENTS 2026-06-15 (profitability fixes) ────────────────────────────
#   1. TREND FILTER: only buy oversold dips in stocks still in an UPTREND
#      (close > long SMA). Mean-reversion longs only pay in uptrends; buying
#      oversold in downtrends = catching knives (the #1 reversion killer).
#   2. REVERSAL CONFIRMATION: require the stock to have turned up (today green /
#      close > prior close) instead of buying mid-crash.
#   3. RISK/REWARD FIX: cap the stop loss (MAX_STOP_PCT) and tighten INIT_K so
#      risk <= reward. Old: stop 2.5*ATR (~8%) vs target +5% = negative edge.
#   4. REGIME GATE: skip new entries in BEAR/PANIC (mult < 1), not just PANIC.
#   5. Shorter time stop (bounces are quick) to recycle capital.
#  All changes are config-gated; set the flags False to revert to old behaviour.
# =============================================================================

import os, re, sys, json, logging
from datetime import datetime, timedelta, date
import numpy as np
import pandas as pd
import requests

# ----------------------------- CONFIG -----------------------------------------
GLOBAL_DIR    = "/home/globalbot"
BASE_DIR      = os.path.join(GLOBAL_DIR, "eq_floor")
LOG_PATH      = os.path.join(BASE_DIR, "eq_floor.log")
UNIVERSE_CSV  = os.path.join(BASE_DIR, "universe.csv")
EXCLUDE_CSV   = os.path.join(BASE_DIR, "exclude.csv")   # ASM/GSM/ESM/T2T, refresh weekly

STRATEGY_TAG  = "GIR_EQ_FLOOR"
SIGNAL_SOURCE = "floor_reversion"
PHOENIX_LIVE  = False

# Capital / budget  — this lane gets its OWN equal bucket
FLOOR_CAPITAL   = 100_000.0   # 4th-module bucket (Rs 1,00,000)
PER_POS_ALLOC   = 0.20        # 5 positions x 20% = full bucket
FLOOR_MAX_POS   = 5           # this lane's own position cap (independent)

# Entry — oversold floor
BB_LEN, BB_SD   = 20, 2.5
RSI_LEN, RSI_OS = 14, 25
NEED_BOTH       = False
TOP_N_SIGNALS   = 8
MIN_PRICE       = 50.0
MIN_TURNOVER    = 50_000_000.0
HIST_BARS       = 220         # was 80; need >=200 for the SMA200 trend filter
RATE_SLEEP      = 0.5         # secs between Kite calls (2/sec; limit ~3/sec)

# --- NEW entry-quality filters (improvement 1 & 2) ---
TREND_FILTER    = True        # only buy oversold dips that are still in an uptrend
TREND_SMA       = 200         # long-term trend reference (falls back if short history)
NEED_REVERSAL   = True        # require the stock to have turned up (no mid-crash buys)

# Exit — FIXED TARGET (the win-rate engine)
TP_MODE     = "FIRST"   # FIRST = nearest of {SMA20, +TP_PCT} | MEAN | PCT
TP_PCT      = 0.05
INIT_K      = 1.5       # initial hard stop = entry - 1.5*ATR (was 2.5 -> too wide)
MAX_STOP_PCT= 0.05      # NEW: never risk more than 5% (caps the ATR stop) -> R/R ~>=1
TIME_LIMIT  = 10        # trading days (was 20; reversion bounces resolve fast)

# --- NEW regime gate (improvement 4) ---
SKIP_WEAK_REGIME = True  # skip new entries unless regime mult >= 1 (i.e. BULL/NEUTRAL)

TG_TOKEN  = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN", "")
TG_CHAT   = os.environ.get("TELEGRAM_CHAT_ID", "")

# ----------------------------- logging / telegram -----------------------------
os.makedirs(BASE_DIR, exist_ok=True)
logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [EQ_FLOOR] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_PATH), logging.StreamHandler()])
log = logging.getLogger("eq_floor")

def is_paper():
    return (not PHOENIX_LIVE) or os.environ.get("GIR_PAPER_MODE", "1") == "1"

def notify(msg):
    tag = "PAPER" if is_paper() else "LIVE"
    log.info(msg)
    if TG_TOKEN and TG_CHAT:
        try:
            requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage",
                data={"chat_id": TG_CHAT, "text": f"EQ_FLOOR [{tag}] {msg}"}, timeout=10)
        except Exception as e:
            log.warning(f"telegram: {e}")

# ----------------------------- shared layer wiring ----------------------------
def get_kite():
    # Reuse GIR's authenticated session (shared saved-token -> no second login).
    from gir import KiteSession            # ANCHOR: import side-effects watched in paper test
    return KiteSession.kite()

from paper.paper_trader import paper_place_order, paper_record_exit, get_open_paper_trades

# ----------------------------- instruments / math -----------------------------
_INSTR = {}
def load_instruments(kite):
    global _INSTR
    if _INSTR: return _INSTR
    for r in kite.instruments("NSE"):
        if r.get("segment") == "NSE" and r.get("instrument_type") == "EQ":
            _INSTR[r["tradingsymbol"]] = {"token": r["instrument_token"],
                                          "tick": float(r.get("tick_size") or 0.05)}
    return _INSTR

def round_tick(p, tick):
    tick = tick or 0.05
    return round(round(p / tick) * tick, 2)

def _rsi(s, n):
    d = s.diff(); up = d.clip(lower=0); dn = -d.clip(upper=0)
    return 100 - 100/(1 + up.ewm(alpha=1/n, adjust=False).mean()
                          / dn.ewm(alpha=1/n, adjust=False).mean().replace(0, np.nan))

def _atr(df, n):
    h,l,c = df["high"],df["low"],df["close"]; pc=c.shift(1)
    tr = pd.concat([h-l,(h-pc).abs(),(l-pc).abs()],axis=1).max(axis=1)
    return tr.ewm(alpha=1/n, adjust=False).mean()

def daily_ohlc(kite, token, bars=HIST_BARS):
    import time as _t; _t.sleep(RATE_SLEEP)
    to = datetime.now(); frm = to - timedelta(days=int(bars*1.9)+10)
    raw = kite.historical_data(token, frm, to, "day")
    if not raw: return pd.DataFrame()
    return pd.DataFrame(raw)[["date","open","high","low","close","volume"]].astype(
        {"open":float,"high":float,"low":float,"close":float,"volume":float}).reset_index(drop=True)

def passes_liquidity(df):
    if len(df) < max(BB_LEN,21) or df["close"].iloc[-1] < MIN_PRICE: return False
    return (df["close"]*df["volume"]).tail(20).mean() >= MIN_TURNOVER

def _in_uptrend(df):
    """Improvement 1: oversold dip only counts if the stock is still trending up.
    Uses SMA200 when available, else the longest SMA the history allows (>=50)."""
    c = df["close"]
    win = TREND_SMA if len(c) >= TREND_SMA else max(50, len(c) // 2)
    if len(c) < win + 1:
        return True  # too little history to judge -> don't block (fail-open)
    return float(c.iloc[-1]) > float(c.rolling(win).mean().iloc[-1])

def _has_turned_up(df):
    """Improvement 2: require a bounce (today closes up vs prior, or green candle)."""
    c, o = df["close"], df["open"]
    if len(c) < 2:
        return True
    return float(c.iloc[-1]) > float(c.iloc[-2]) or float(c.iloc[-1]) > float(o.iloc[-1])

# ----------------------------- shared-bucket helpers --------------------------
def _floor_open(trades):
    return [t for t in trades if (t.get("strategy") or "").upper() == STRATEGY_TAG]
def _deployed(trades):
    return sum(float(t["entry_price"])*int(t["qty"]) for t in _floor_open(trades))
def _is_open(trades, sym):
    return any(t["symbol"] == sym for t in _floor_open(trades))
def _hunter_held(trades):
    return {t["symbol"] for t in trades if (t.get("strategy") or "").upper().startswith("HUNTER")}

def load_list(path):
    if not os.path.exists(path): return set()
    with open(path) as f:
        return {ln.strip().upper() for ln in f if ln.strip() and not ln.startswith("#")}

# ============================== scan ==========================================
def cmd_scan():
    kite = get_kite(); instr = load_instruments(kite)
    universe = load_list(UNIVERSE_CSV) or set(instr); exclude = load_list(EXCLUDE_CSV)
    hits = []
    knives = trendless = notturned = 0
    for sym in sorted(universe):
        if sym in exclude or sym not in instr: continue
        try:
            df = daily_ohlc(kite, instr[sym]["token"])
            if not passes_liquidity(df): continue
            basis = df["close"].rolling(BB_LEN).mean()
            lower = (basis - BB_SD*df["close"].rolling(BB_LEN).std()).iloc[-1]
            r = _rsi(df["close"], RSI_LEN).iloc[-1]
            touch = df["low"].iloc[-1] <= lower or df["close"].iloc[-1] <= lower
            oversold = (touch and r < RSI_OS) if NEED_BOTH else (touch or r < RSI_OS)
            if not oversold:
                continue
            # --- NEW quality gates ---
            if TREND_FILTER and not _in_uptrend(df):
                trendless += 1; continue          # don't buy oversold downtrends
            if NEED_REVERSAL and not _has_turned_up(df):
                notturned += 1; continue           # don't buy mid-crash
            hits.append({"symbol": sym, "rsi": float(r)})
        except Exception as e: log.warning(f"scan {sym}: {e}")
    hits.sort(key=lambda x: x["rsi"]); hits = hits[:TOP_N_SIGNALS]
    with open(os.path.join(BASE_DIR, f"signals_{date.today().isoformat()}.json"), "w") as f:
        json.dump(hits, f)
    notify("scan: " + (", ".join(f"{h['symbol']}(rsi{h['rsi']:.0f})" for h in hits) if hits else "0")
           + f"  [filtered: trendless {trendless}, not-turned {notturned}]")

# ============================== execute =======================================
def cmd_execute():
    kite = get_kite(); instr = load_instruments(kite)
    sigpath = os.path.join(BASE_DIR, f"signals_{date.today().isoformat()}.json")
    if not os.path.exists(sigpath): notify("execute: no signals file"); return
    sigs = json.load(open(sigpath))
    import regime_lite  # [RG1] shared regime gate
    _rg = regime_lite.get_regime(kite)
    notify(f"execute: regime {_rg['regime']} x{_rg['mult']} ({_rg['reason']})")
    if _rg['mult'] <= 0:
        notify('execute: PANIC regime - no new entries today'); return
    if SKIP_WEAK_REGIME and _rg['mult'] < 1.0:
        notify(f"execute: weak regime ({_rg['regime']}) - skipping mean-reversion longs today"); return
    trades = get_open_paper_trades()
    floor_n, deployed = len(_floor_open(trades)), _deployed(trades)
    blocked = _hunter_held(trades)
    placed = 0
    for s in sigs:
        sym = s["symbol"]
        if floor_n >= FLOOR_MAX_POS:
            notify(f"execute: lane full ({floor_n}/{FLOOR_MAX_POS})"); break
        if sym not in instr or _is_open(trades, sym) or sym in blocked: continue
        try:
            df = daily_ohlc(kite, instr[sym]["token"]); tick = instr[sym]["tick"]
            a   = float(_atr(df, 14).iloc[-1])
            sma = float(df["close"].rolling(BB_LEN).mean().iloc[-1])
            q   = kite.quote([f"NSE:{sym}"]).get(f"NSE:{sym}", {})
            ltp = float(q.get("last_price") or df["close"].iloc[-1])
            # Improvement 3: cap the stop so risk <= ~MAX_STOP_PCT (was a wide 2.5*ATR)
            atr_stop = ltp - INIT_K*a
            cap_stop = ltp*(1 - MAX_STOP_PCT)
            stop = round_tick(max(atr_stop, cap_stop), tick)
            if ltp <= stop: continue
            pct_t = ltp*(1+TP_PCT)
            target = (sma if (TP_MODE=="MEAN" and sma>ltp) else pct_t if TP_MODE=="PCT"
                      else min([pct_t] + ([sma] if sma>ltp else [])))
            # Improvement 3 (cont): ensure reward is at least the risk (>=1:1 R/R)
            target = max(target, ltp + (ltp - stop))
            target = round_tick(target, tick)
            free   = max(0.0, FLOOR_CAPITAL - deployed)
            budget = min(PER_POS_ALLOC*FLOOR_CAPITAL, free) * _rg['mult']  # [RG1]
            qty = int(budget // ltp)
            if qty <= 0: continue
            oid = paper_place_order(
                strategy=STRATEGY_TAG, signal_source=SIGNAL_SOURCE,
                symbol=sym, exchange="NSE", product="CNC", side="BUY",
                qty=qty, price=round_tick(ltp, tick), order_type="MARKET",
                sl_trigger=stop, sl_limit=round_tick(stop*0.998, tick),
                time_stop_days=TIME_LIMIT,
                meta={"target": target, "exit_style": "fixed_target", "sma20": round(sma,2)})
            deployed += qty*ltp; floor_n += 1; placed += 1
            rr = (target-ltp)/max(ltp-stop, 1e-9)
            notify(f"BUY {sym} x{qty} @ {ltp:.2f} | stop {stop:.2f} | target {target:.2f} "
                   f"| R/R {rr:.2f} | {oid}")
        except Exception as e: log.warning(f"execute {sym}: {e}")
    notify(f"execute: opened {placed}")

# ============================== manage (owns floor exits) =====================
def cmd_manage():
    kite = get_kite()
    for t in _floor_open(get_open_paper_trades()):
        sym = t["symbol"]
        try:
            meta = t.get("meta_json") or t.get("meta") or {}
            if isinstance(meta, str): meta = json.loads(meta or "{}")
            target = float(meta.get("target")); stop = float(t["sl_trigger"]); entry = float(t["entry_price"])
            held = int(np.busday_count(datetime.fromisoformat(t["entry_ts"]).date(), date.today()))
            q = kite.quote([f"NSE:{sym}"]).get(f"NSE:{sym}", {})
            ltp = float(q.get("last_price") or 0)
            if not ltp: continue
            reason = ("STOP" if ltp <= stop else "TARGET" if ltp >= target
                      else f"TIME({held}d)" if held >= TIME_LIMIT else None)
            if reason:
                paper_record_exit(trade_id=t["trade_id"], exit_price=ltp,
                                  exit_reason=reason, strategy=STRATEGY_TAG)
                notify(f"SELL {sym} @ {ltp:.2f} | {reason} | PnL {(ltp-entry)*int(t['qty']):,.0f}")
        except Exception as e: log.warning(f"manage {sym}: {e}")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    log.info(f"EQ_FLOOR cmd={cmd} paper={is_paper()}")
    {"scan":cmd_scan, "execute":cmd_execute, "manage":cmd_manage}.get(
        cmd, lambda: (print("usage: gir_eq_floor.py [scan|execute|manage]"), sys.exit(1)))()

if __name__ == "__main__":
    main()
