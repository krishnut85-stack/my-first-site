#!/usr/bin/env python3
# =============================================================================
#  decision_brain_executor.py  —  makes "Parliament" (decision_brain) TRADE.
#
#  The brain (decision_brain.py) is a pure GO/NO-GO judge: it scores candidates
#  across weighted layers and returns TRADE/SKIP/BLOCK, but it never finds
#  candidates or places orders. On the live tree it depends on gir.py's 6
#  scorers via collect_layers(); without a gir_instance every layer is neutral,
#  so it has been deciding on a wall of 50s and never trading.
#
#  This executor is the SELF-CONTAINED feeder + order placer (Path B):
#    1. scan a liquid universe and propose BULLISH equity candidates
#    2. compute REAL layer scores it can derive from price/market data:
#         - technical      (0-20)  trend + momentum + breakout proximity
#         - sector_rotation(0-20)  relative strength vs NIFTY
#         - regime_filter  (0-100) from regime_lite (BULL/NEUTRAL/BEAR/PANIC)
#       the remaining layers are set to honest neutral (low confidence) so they
#       neither help nor hurt — exactly as the brain's own collect_layers does.
#    3. feed candidates to the UNCHANGED brain (decide_best_of_day) — its
#       weights, score floor, >=3-supporting-layers gate, best-of-day pick,
#       2% risk sizing, cooldowns and -3% kill switch all apply as written.
#    4. place a PAPER order for each TRADE verdict (strategy tag PARLIAMENT),
#       and manage exits (4% stop / 8% target / time stop) on later cycles.
#
#  PAPER-ONLY: routes through paper.paper_trader (the same paper book Phoenix/
#  Hunter use). It never sends a real order. It is NOT the old F&O code.
#
#  Run (beside decision_brain.py, like the other lanes):
#     cd /home/globalbot && set -a && source .env && set +a && \
#         python3 decision_brain_executor.py [run|manage|status]
#       run    : scan -> brain decides -> place paper trades (post-open)
#       manage : check open PARLIAMENT trades for stop/target/time exits
#       status : print ledger + open positions
# =============================================================================

import os, sys, json, logging
from datetime import datetime, timedelta, date
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/home/globalbot")

import decision_brain  # module (to raise the per-day cap)
from decision_brain import DecisionBrain, Candidate, LayerScore  # the unchanged judge

# ----------------------------- CONFIG -----------------------------------------
GLOBAL_DIR    = "/home/globalbot"
BASE_DIR      = os.path.join(GLOBAL_DIR, "eq_floor")        # reuse the curated liquid universe
UNIVERSE_CSV  = os.path.join(BASE_DIR, "universe.csv")
EXCLUDE_CSV   = os.path.join(BASE_DIR, "exclude.csv")
LOG_PATH      = os.path.join(GLOBAL_DIR, "parliament_exec.log")

STRATEGY_TAG  = "PARLIAMENT"
SIGNAL_SOURCE = "decision_brain"

MAX_OPEN      = 5             # safety cap on concurrent PARLIAMENT paper positions
DAILY_LOSS_LIMIT = 6000.0    # working kill switch: stop new entries if today's realised PARLIAMENT loss exceeds this (the brain's own kill switch is bugged - queries a 'trades' table that doesn't exist)
TOP_N_CAND    = 15           # feed the brain the strongest N candidates
MIN_TECH      = 11.0         # 0-20; >=11 normalises to >=55 (a "supporting" technical)
MIN_PRICE     = 50.0
MIN_TURNOVER  = 50_000_000.0
HIST_BARS     = 220          # need ~200 for SMA200
RATE_SLEEP    = 0.4
TIME_LIMIT    = 15           # trading-day time stop for exits
NIFTY_TOKEN   = 256265

TG_TOKEN = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN", "")
TG_CHAT  = os.environ.get("TELEGRAM_CHAT_ID", "")

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [PARLIAMENT] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_PATH), logging.StreamHandler()])
log = logging.getLogger("parliament_exec")


def notify(msg):
    log.info(msg)
    if TG_TOKEN and TG_CHAT:
        try:
            import requests
            requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage",
                data={"chat_id": TG_CHAT, "text": f"PARLIAMENT [PAPER] {msg}"}, timeout=10)
        except Exception as e:
            log.warning(f"telegram: {e}")


# ----------------------------- shared wiring (same as Phoenix) ----------------
def get_kite():
    from gir import KiteSession
    return KiteSession.kite()

from paper.paper_trader import paper_place_order, paper_record_exit, get_open_paper_trades


# ----------------------------- instruments / math -----------------------------
_INSTR = {}
def load_instruments(kite):
    global _INSTR
    if _INSTR:
        return _INSTR
    for r in kite.instruments("NSE"):
        if r.get("segment") == "NSE" and r.get("instrument_type") == "EQ":
            _INSTR[r["tradingsymbol"]] = {"token": r["instrument_token"],
                                          "tick": float(r.get("tick_size") or 0.05)}
    return _INSTR


def _rsi(s, n=14):
    d = s.diff(); up = d.clip(lower=0); dn = -d.clip(upper=0)
    return 100 - 100/(1 + up.ewm(alpha=1/n, adjust=False).mean()
                          / dn.ewm(alpha=1/n, adjust=False).mean().replace(0, np.nan))


def daily_ohlc(kite, token, bars=HIST_BARS):
    import time as _t; _t.sleep(RATE_SLEEP)
    to = datetime.now(); frm = to - timedelta(days=int(bars*1.9)+10)
    raw = kite.historical_data(token, frm, to, "day")
    if not raw:
        return pd.DataFrame()
    return pd.DataFrame(raw)[["open","high","low","close","volume"]].astype(float).reset_index(drop=True)


def load_list(path):
    if not os.path.exists(path):
        return set()
    with open(path) as f:
        return {ln.strip().upper() for ln in f if ln.strip() and not ln.startswith("#")}


# ----------------------------- REAL layer scorers -----------------------------
def technical_score(df):
    """0-20 trend + momentum + breakout-proximity (bullish). Higher = stronger."""
    c = df["close"]
    if len(c) < 50:
        return 0.0
    sma20 = c.rolling(20).mean().iloc[-1]
    sma50 = c.rolling(50).mean().iloc[-1]
    sma200 = c.rolling(200).mean().iloc[-1] if len(c) >= 200 else None
    rsi = float(_rsi(c).iloc[-1])
    hi20 = c.iloc[-20:].max()
    px = c.iloc[-1]
    s = 0.0
    if sma200 is not None and px > sma200:  s += 6
    if px > sma50:                          s += 5
    if px > sma20:                          s += 4
    if 50 <= rsi <= 70:                     s += 3
    elif 45 <= rsi < 75:                    s += 1.5
    if px >= hi20 * 0.97:                   s += 2   # near 20-day breakout
    return float(min(20.0, s))


def sector_rotation_score(df, nifty_close):
    """0-20 relative strength of the stock vs NIFTY over 20 sessions. 10 = neutral."""
    c = df["close"]
    if len(c) < 21 or nifty_close is None or len(nifty_close) < 21:
        return 10.0
    stock_ret = c.iloc[-1] / c.iloc[-21] - 1
    nifty_ret = nifty_close[-1] / nifty_close[-21] - 1
    rs_pp = (stock_ret - nifty_ret) * 100.0
    return float(min(20.0, max(0.0, 10.0 + rs_pp)))   # +10pp outperformance -> 20


def regime_score(kite):
    """0-100 from the shared regime gate. Returns (score, label)."""
    try:
        import regime_lite
        rg = regime_lite.get_regime(kite)
        label = rg.get("regime", "NEUTRAL")
        return {"BULL": 75.0, "NEUTRAL": 55.0, "BEAR": 30.0, "PANIC": 5.0}.get(label, 50.0), label
    except Exception as e:
        log.warning(f"regime_lite unavailable ({e}) -> neutral")
        return 50.0, "NEUTRAL"


def _neutral_layers():
    """Honest neutral for the layers we can't derive, at the brain's own scales."""
    return {
        # 0-100 scale -> 50 is neutral
        "delivery_pct":    LayerScore("delivery_pct", 50.0, False, 0.3, "not_derived"),
        "promoter_inst":   LayerScore("promoter_inst", 50.0, False, 0.3, "not_derived"),
        "fii_dii_flow":    LayerScore("fii_dii_flow", 50.0, False, 0.3, "not_derived"),
        "news_sentiment":  LayerScore("news_sentiment", 50.0, False, 0.3, "not_derived"),
        "earnings_window": LayerScore("earnings_window", 50.0, False, 0.3, "not_derived"),
        # 0-20 scale -> 10 normalises to 50 (neutral)
        "oi_buildup":      LayerScore("oi_buildup", 10.0, False, 0.3, "not_derived"),
        "fundamental":     LayerScore("fundamental", 10.0, False, 0.3, "not_derived"),
        "filings_signal":  LayerScore("filings_signal", 10.0, False, 0.3, "not_derived"),
    }


# ----------------------------- open-position helpers --------------------------
def _parliament_open(trades):
    return [t for t in trades if (t.get("strategy") or "").upper() == STRATEGY_TAG]
def _held_symbols(trades):
    return {t["symbol"] for t in _parliament_open(trades)}

def _today_realized_pnl():
    """Sum of today's CLOSED PARLIAMENT pnl (exit_ts is UTC). Working kill switch."""
    import sqlite3
    from datetime import timezone
    try:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        conn = sqlite3.connect("/home/globalbot/paper/trades.db")
        v = conn.execute(
            "SELECT COALESCE(SUM(pnl),0) FROM paper_trades "
            "WHERE UPPER(strategy)=? AND status='CLOSED' AND substr(exit_ts,1,10)=?",
            (STRATEGY_TAG, today)).fetchone()[0]
        conn.close()
        return float(v or 0)
    except Exception as e:
        log.warning(f"daily pnl check failed: {e}")
        return 0.0


# ============================== run (scan -> decide -> trade) ==================
def cmd_run():
    kite = get_kite(); instr = load_instruments(kite)
    universe = load_list(UNIVERSE_CSV) or set(instr); exclude = load_list(EXCLUDE_CSV)

    # market context once
    try:
        nraw = kite.historical_data(NIFTY_TOKEN, datetime.now()-timedelta(days=60), datetime.now(), "day")
        nifty_close = [float(b["close"]) for b in nraw] if nraw else None
    except Exception:
        nifty_close = None
    rg_score, rg_label = regime_score(kite)
    notify(f"run: regime {rg_label} (layer score {rg_score:.0f}/100)")

    day_pnl = _today_realized_pnl()
    if day_pnl <= -DAILY_LOSS_LIMIT:
        notify(f"run: KILL SWITCH - today's realised PnL ₹{day_pnl:.0f} <= -₹{DAILY_LOSS_LIMIT:.0f}, "
               f"no new entries"); cmd_manage(kite); return

    trades = get_open_paper_trades()
    held = _held_symbols(trades)
    if len(_parliament_open(trades)) >= MAX_OPEN:
        notify(f"run: at max open ({MAX_OPEN}) - managing only"); cmd_manage(kite); return

    # build candidates with REAL layers
    cands = []
    for sym in sorted(universe):
        if sym in exclude or sym not in instr or sym in held:
            continue
        try:
            df = daily_ohlc(kite, instr[sym]["token"])
            if len(df) < 50 or df["close"].iloc[-1] < MIN_PRICE:
                continue
            if (df["close"]*df["volume"]).tail(20).mean() < MIN_TURNOVER:
                continue
            if df["close"].iloc[-1] <= df["close"].rolling(50).mean().iloc[-1]:
                continue   # only propose names in an uptrend (long-only)
            tech = technical_score(df)
            if tech < MIN_TECH:
                continue
            sect = sector_rotation_score(df, nifty_close)
            ltp = float(df["close"].iloc[-1])
            c = Candidate(symbol=sym, category="equity", direction="BULLISH",
                          ltp=ltp, sector="UNKNOWN")
            c.layers = {
                "technical":       LayerScore("technical", tech, tech >= 11, 1.0),
                "sector_rotation": LayerScore("sector_rotation", sect, sect >= 11, 1.0),
                "regime_filter":   LayerScore("regime_filter", rg_score, rg_score >= 55, 1.0),
            }
            c.layers.update(_neutral_layers())
            cands.append((c, tech))
        except Exception as e:
            log.debug(f"scan {sym}: {e}")

    cands.sort(key=lambda x: -x[1])
    cands = [c for c, _ in cands[:TOP_N_CAND]]
    notify(f"run: {len(cands)} candidates fed to the brain")
    if not cands:
        return

    # Take up to MAX_OPEN of the day's strongest names (not just best-of-day=1).
    # Raise the brain's per-day cap to match so _check_daily_cap allows up to
    # MAX_OPEN equity TRADEs/day (cumulative across runs -> no over-trading).
    decision_brain.DAILY_TRADE_CAPS["equity"] = MAX_OPEN
    brain = DecisionBrain(mode="paper", kite=kite)
    slots = MAX_OPEN - len(_parliament_open(get_open_paper_trades()))
    placed = trade_verdicts = 0
    for c in cands:                       # cands sorted strongest-first
        if slots <= 0:
            break
        d = brain.decide(c)              # commits decision + counts toward daily cap
        if d.action != "TRADE":
            continue
        trade_verdicts += 1
        try:
            oid = paper_place_order(
                strategy=STRATEGY_TAG, signal_source=SIGNAL_SOURCE,
                symbol=d.symbol, exchange="NSE", product="CNC", side="BUY",
                qty=d.qty, price=round(d.entry, 2), order_type="MARKET",
                sl_trigger=round(d.stop, 2), sl_limit=round(d.stop*0.998, 2),
                time_stop_days=TIME_LIMIT,
                meta={"target": round(d.target, 2), "brain_score": d.final_score,
                      "supporting": d.supporting_layers, "exit_style": "brain_fixed"})
            slots -= 1; placed += 1
            rr = (d.target-d.entry)/max(d.entry-d.stop, 1e-9)
            notify(f"BUY {d.symbol} x{d.qty} @ {d.entry:.2f} | stop {d.stop:.2f} "
                   f"target {d.target:.2f} | R/R {rr:.1f} | score {d.final_score:.0f} "
                   f"sup {d.supporting_layers}/11 | {oid}")
        except Exception as e:
            log.warning(f"place {d.symbol}: {e}")
    notify(f"run: placed {placed} (TRADE verdicts {trade_verdicts}, slots left {max(slots,0)})")
    cmd_manage(kite)


# ============================== manage (exits) ================================
def cmd_manage(kite=None):
    kite = kite or get_kite()
    for t in _parliament_open(get_open_paper_trades()):
        sym = t["symbol"]
        try:
            meta = t.get("meta_json") or t.get("meta") or {}
            if isinstance(meta, str):
                meta = json.loads(meta or "{}")
            target = float(meta.get("target")); stop = float(t["sl_trigger"]); entry = float(t["entry_price"])
            held = int(np.busday_count(datetime.fromisoformat(t["entry_ts"]).date(), date.today()))
            q = kite.quote([f"NSE:{sym}"]).get(f"NSE:{sym}", {})
            ltp = float(q.get("last_price") or 0)
            if not ltp:
                continue
            reason = ("STOP" if ltp <= stop else "TARGET" if ltp >= target
                      else f"TIME({held}d)" if held >= TIME_LIMIT else None)
            if reason:
                paper_record_exit(trade_id=t["trade_id"], exit_price=ltp,
                                  exit_reason=reason, strategy=STRATEGY_TAG)
                notify(f"SELL {sym} @ {ltp:.2f} | {reason} | "
                       f"PnL {(ltp-entry)*int(t['qty']):,.0f}")
        except Exception as e:
            log.warning(f"manage {sym}: {e}")


def cmd_status():
    trades = _parliament_open(get_open_paper_trades())
    notify(f"status: {len(trades)} open PARLIAMENT positions")
    for t in trades:
        log.info(f"  {t['symbol']} x{t['qty']} @ {t['entry_price']}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    log.info(f"PARLIAMENT executor cmd={cmd}")
    {"run": cmd_run, "manage": lambda: cmd_manage(), "status": cmd_status}.get(
        cmd, lambda: (print("usage: decision_brain_executor.py [run|manage|status]"),
                      sys.exit(1)))()


if __name__ == "__main__":
    main()
