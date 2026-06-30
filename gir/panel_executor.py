#!/usr/bin/env python3
"""PANEL EXECUTOR v1.0 — morning execution of last evening's panel signals.
Pool-aware, dedup-guarded, AI-advisory-logged. PAPER ONLY (paper_place_order).
Spec: -4% hard SL, 20-day time stop, CNC, Rs.15K/trade, max 5 open PANEL trades."""
import os, sys, json, sqlite3, datetime as dt
import panel
sys.path.insert(0, "/home/globalbot/paper")
from paper_trader import paper_place_order

PANEL_CAPITAL_PER_TRADE = 50000.0
PANEL_MAX_OPEN = 10
PANEL_DEDICATED_POOL = 500000.0   # PARLIAMENT: 10 x 50K (user-allocated 2026-06-12)
MAX_GAP_STOCK = 0.03              # skip stock if LTP moved >3% from signal close
MAX_GAP_NIFTY = -0.015            # skip day if NIFTY gaps below -1.5%
SL_PCT = 0.04
TIME_STOP_DAYS = 20
POOL_TOTAL_FALLBACK = 1594478.0

def pool_available():
    con = sqlite3.connect("/home/globalbot/paper/trades.db", timeout=5)
    try:
        dep = con.execute("SELECT COALESCE(SUM(amount),0) FROM paper_capital_ledger").fetchone()[0]
        pnl = con.execute("SELECT COALESCE(SUM(pnl),0) FROM paper_trades WHERE status='CLOSED'").fetchone()[0]
        used = con.execute("SELECT COALESCE(SUM(qty*entry_price),0) FROM paper_trades WHERE status='OPEN'").fetchone()[0]
        total = (dep + pnl) if (dep + pnl) > 0 else POOL_TOTAL_FALLBACK
        return max(0.0, total - used)
    finally:
        con.close()

def open_panel_state():
    con = sqlite3.connect("/home/globalbot/paper/trades.db", timeout=5)
    try:
        rows = con.execute("SELECT symbol FROM paper_trades WHERE status='OPEN' "
                           "AND UPPER(strategy) LIKE 'PANEL%'").fetchall()
        return {r[0] for r in rows}
    finally:
        con.close()

def main():
    # NSE calendar guard (Hunter's market_calendar)
    try:
        sys.path.insert(0, "/home/globalbot/hunter")
        import market_calendar as _mc
        _today = dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).date()
        if not _mc.is_trading_day(_today):
            print(f"[PX] {_today} is not an NSE trading day - standing down"); raise SystemExit(0)
        print(f"[PX] calendar check OK: {_today} is a trading day")
    except SystemExit:
        raise
    except Exception as _e:
        print(f"[PX] calendar check unavailable ({_e}) - proceeding (timers already skip weekends)")
    con = sqlite3.connect(panel.DB_PATH)
    rid, ts = con.execute("SELECT run_id, ts FROM runs ORDER BY run_id DESC LIMIT 1").fetchone()
    age_h = (dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))) -
             dt.datetime.fromisoformat(ts)).total_seconds() / 3600
    if age_h > 20:
        print(f"[PX] latest run #{rid} is {age_h:.0f}h old — stale, refusing to execute"); raise SystemExit(0)
    sigs = con.execute("SELECT symbol, signal FROM results WHERE run_id=? AND signal>0 "
                       "ORDER BY mean DESC", (rid,)).fetchall()
    ai = {r[0]: (r[1], r[2]) for r in con.execute(
        "SELECT symbol, verdict, conviction FROM ai_verdicts WHERE run_id=?", (rid,))}
    con.close()
    if not sigs:
        print(f"[PX] run #{rid}: no signals. Done."); return
    held = open_panel_state()
    slots = PANEL_MAX_OPEN - len(held)
    avail = pool_available()
    conp = sqlite3.connect("/home/globalbot/paper/trades.db", timeout=5)
    panel_used = conp.execute("SELECT COALESCE(SUM(qty*entry_price),0) FROM paper_trades "
                              "WHERE status='OPEN' AND UPPER(strategy) LIKE 'PANEL%'").fetchone()[0]
    conp.close()
    avail = min(avail, PANEL_DEDICATED_POOL - panel_used)
    import pickle
    _cache = pickle.load(open(panel.CACHE + "/hist.pkl", "rb"))
    sig_close = {s: d["c"][-1] for s, d in _cache.items() if s != "__NIFTY__"}
    nif_close = _cache.get("__NIFTY__", {}).get("c")
    print(f"[PX] run #{rid}: {len(sigs)} signals | open PANEL {len(held)}/{PANEL_MAX_OPEN} | pool avail Rs.{avail:,.0f}")
    if slots <= 0:
        print("[PX] no free PANEL slots. Done."); return
    kite = panel.kite_login()
    try:
        nif_ltp = kite.ltp("NSE:NIFTY 50")["NSE:NIFTY 50"]["last_price"]
        gap = nif_ltp / nif_close[-1] - 1
        if nif_close is not None and gap < MAX_GAP_NIFTY:
            print(f"[PX] NIFTY gapped {gap*100:+.2f}% overnight -> guard, no entries today"); raise SystemExit(0)
        print(f"[PX] NIFTY gap check OK ({gap*100:+.2f}%)")
    except SystemExit:
        raise
    except Exception as e:
        print(f"[PX] NIFTY gap check unavailable ({e}), stock-level guards only")
    placed = 0
    for sym, sig in sigs:
        if placed >= slots: break
        if sym in held:
            print(f"[PX] {sym}: already open, skip"); continue
        if PANEL_CAPITAL_PER_TRADE > avail * 0.98:
            print(f"[PX] pool gate: need {PANEL_CAPITAL_PER_TRADE:.0f}, avail {avail:.0f}. Stop."); break
        try:
            ltp = kite.ltp(f"NSE:{sym}")[f"NSE:{sym}"]["last_price"]
        except Exception as e:
            print(f"[PX] {sym}: LTP failed ({e}), skip"); continue
        _sc = sig_close.get(sym)
        if _sc and abs(ltp / _sc - 1) > MAX_GAP_STOCK:
            print(f"[PX] {sym}: gapped {(ltp/_sc-1)*100:+.1f}% vs signal close, skip"); continue
        qty = int(PANEL_CAPITAL_PER_TRADE // ltp)
        if qty < 1:
            print(f"[PX] {sym}: price {ltp} too high for slot, skip"); continue
        verdict, conv = ai.get(sym, ("NONE", -1))
        strat = "PANEL_A" if sig == 1 else "PANEL_B"
        oid = paper_place_order(
            strategy=strat, signal_source=f"panel_run_{rid}", symbol=sym,
            exchange="NSE", product="CNC", side="BUY", qty=qty, price=float(ltp),
            order_type="LIMIT", tag="PANEL",
            sl_trigger=round(ltp * (1 - SL_PCT), 2), sl_limit=round(ltp * (1 - SL_PCT - 0.005), 2),
            time_stop_days=TIME_STOP_DAYS,
            meta={"pattern": "DIP" if sig == 1 else "BREAKOUT", "ai_verdict": verdict,
                  "ai_conviction": conv, "fn": "panel_executor.main"})
        avail -= qty * ltp
        placed += 1
        print(f"[PX] PLACED {strat} {sym} qty={qty} @ {ltp} SL {ltp*(1-SL_PCT):.2f} "
              f"t-stop {TIME_STOP_DAYS}d | AI: {verdict}/{conv} | {oid}")
    print(f"[PX] done: {placed} placed")

if __name__ == "__main__":
    main()
