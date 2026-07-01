#!/usr/bin/env python3
"""
elon_stocks_live.py  -  ELON Strategy 2 live/paper engine (sector-leaders, NRO)
==============================================================================
Forward-trades the two-stage "strong sector -> top 2 stocks" strategy as a real
track record. SAME selection code as the backtest (imported from elon_stocks),
so PAPER == LIVE. Flip to real orders with one switch once paper is winning.

Adds what the backtest did NOT model: a per-stock HARD STOP-LOSS, checked every
day (the mid/small-cap risk control). Principles (same as the momentum lane):
  * MONTHLY  full two-stage rebalance (top 5 sectors x 2 stocks = 10 names).
  * DAILY    risk check: (a) Nifty below 200-DMA -> sell everything to cash;
             (b) any held stock at/through its STOP -> sell it now; (c) in a
             HEALTHY market, refill freed slots with the next-best qualifying
             stock (stay invested in winners).
  * NEVER trade at night: in-session -> market order; after hours -> AMO (fills
    at the next open).

MODES:  PAPER (default; simulated fills at real LTP, own JSON ledger).
        LIVE (EQS2_LIVE=1 AND EQS2_LIVE_CONFIRM=YES): real CNC/delivery orders,
        universe-whitelist only, hard max order value, never MIS/short/F&O.
ISOLATION: own ledger + own Telegram (EQS2_TG_* ONLY). Never touches Mayura or
any other lane.

USAGE (droplet; after: cd /home/globalbot && set -a && source .env && set +a):
  python3 elon_stocks_live.py --selftest
  python3 elon_stocks_live.py --run            # one daily cycle (PAPER)
  python3 elon_stocks_live.py --status
Cron (daily ~09:20 IST = 03:50 UTC):
  50 3 * * 1-5  cd /home/globalbot && set -a && . ./.env && set +a && \
                python3 elon_stocks_live.py --run >> elon_stocks.log 2>&1
"""

import os
import sys
import json
import time
import argparse
import datetime as dt
import urllib.request
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import elon_code as E                                       # noqa: E402
from elon_momentum import _hist_chunked, stats              # noqa: E402
from elon_stocks import (StockP, load_universe, stock_scores, select_stocks,   # noqa: E402
                         _monthly_close_turnover, _regime_by_month)

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
def _today():
    return dt.datetime.now(IST).strftime("%Y-%m-%d")
def _month():
    return dt.datetime.now(IST).strftime("%Y-%m")
def _market_open_now():
    n = dt.datetime.now(IST)
    return n.weekday() < 5 and (9, 15) <= (n.hour, n.minute) <= (15, 30)

STOP_PCT = float(os.environ.get("EQS2_STOP_PCT", "12"))       # per-stock hard stop
CAPITAL = float(os.environ.get("EQS2_CAPITAL", "1000000"))
MAX_ORDER = float(os.environ.get("EQS2_MAX_ORDER", "150000"))
LEDGER_PATH = os.environ.get("EQS2_LEDGER", "/home/globalbot/elon_stocks_paper.json")
DIRPATH = os.environ.get("EQS2_DIR", "/home/globalbot/data/elon2")
LIVE = os.environ.get("EQS2_LIVE", "0").strip() == "1"
LIVE_CONFIRM = os.environ.get("EQS2_LIVE_CONFIRM", "").strip().upper() == "YES"


# --- ledger ------------------------------------------------------------------
def load_ledger(path=None):
    path = path or LEDGER_PATH
    if os.path.exists(path):
        return json.load(open(path))
    return {"mode": "PAPER", "starting_capital": CAPITAL, "cash": CAPITAL,
            "holdings": {}, "trades": [], "equity_history": [], "last_rebalance": ""}


def save_ledger(L, path=None):
    path = path or LEDGER_PATH
    L["trades"] = L["trades"][-500:]
    L["equity_history"] = L["equity_history"][-800:]
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
    except Exception:
        pass
    json.dump(L, open(path, "w"), indent=2)


# --- isolated Telegram (EQS2_TG_* ONLY) --------------------------------------
def tg(msg):
    tok = os.environ.get("EQS2_TG_BOT_TOKEN", "").strip()
    chat = os.environ.get("EQS2_TG_CHAT_ID", "").strip()
    if not (tok and chat):
        return
    data = {"chat_id": chat, "text": msg}
    thread = os.environ.get("EQS2_TG_THREAD", "").strip()
    if thread:
        data["message_thread_id"] = int(thread)
    try:
        req = urllib.request.Request(f"https://api.telegram.org/bot{tok}/sendMessage",
                                     data=urllib.parse.urlencode(data).encode())
        urllib.request.urlopen(req, timeout=15)
    except Exception as e:  # noqa: BLE001
        print(f"[stocks] telegram failed: {e}")


# --- executors ---------------------------------------------------------------
class PaperExecutor:
    def __init__(self, L):
        self.L = L

    def buy(self, sym, qty, price, sector, reason):
        cost = qty * price
        if qty <= 0 or cost > self.L["cash"] + 1e-6:
            return False
        self.L["cash"] -= cost
        h = self.L["holdings"].get(sym)
        if h:
            tot = h["qty"] + qty
            h["avg_price"] = (h["avg_price"] * h["qty"] + price * qty) / tot
            h["qty"] = tot
            h["stop_price"] = round(h["avg_price"] * (1 - STOP_PCT / 100.0), 2)
        else:
            self.L["holdings"][sym] = {"qty": qty, "avg_price": price, "sector": sector,
                                       "entry_date": _today(),
                                       "stop_price": round(price * (1 - STOP_PCT / 100.0), 2)}
        self.L["trades"].append({"date": _today(), "side": "BUY", "sym": sym, "qty": qty,
                                 "price": round(price, 2), "reason": reason})
        return True

    def sell(self, sym, qty, price, reason):
        h = self.L["holdings"].get(sym)
        if not h or qty <= 0:
            return False
        qty = min(qty, h["qty"])
        self.L["cash"] += qty * price
        pnl = (price - h["avg_price"]) * qty
        h["qty"] -= qty
        if h["qty"] <= 0:
            del self.L["holdings"][sym]
        self.L["trades"].append({"date": _today(), "side": "SELL", "sym": sym, "qty": qty,
                                 "price": round(price, 2), "reason": reason, "pnl": round(pnl, 2)})
        return True


class LiveExecutor(PaperExecutor):
    def __init__(self, L, kite, whitelist):
        super().__init__(L)
        self.kite = kite
        self.whitelist = whitelist

    def _place(self, sym, qty, side):
        if sym not in self.whitelist:
            print(f"[LIVE] REFUSED {sym}: not in universe whitelist"); return False
        variety = self.kite.VARIETY_REGULAR if _market_open_now() else self.kite.VARIETY_AMO
        try:
            self.kite.place_order(variety=variety, exchange="NSE", tradingsymbol=sym,
                                  transaction_type=side, quantity=int(qty),
                                  product=self.kite.PRODUCT_CNC,
                                  order_type=self.kite.ORDER_TYPE_MARKET)
            print(f"[LIVE] {side} {sym} x{qty} ({variety})")
            return True
        except Exception as e:  # noqa: BLE001
            print(f"[LIVE] order failed {side} {sym} x{qty}: {e}"); return False

    def buy(self, sym, qty, price, sector, reason):
        if qty * price > MAX_ORDER:
            qty = int(MAX_ORDER // price)
        if qty <= 0 or not self._place(sym, qty, "BUY"):
            return False
        return super().buy(sym, qty, price, sector, reason)

    def sell(self, sym, qty, price, reason):
        h = self.L["holdings"].get(sym)
        if not h or not self._place(sym, min(qty, h["qty"]), "SELL"):
            return False
        return super().sell(sym, qty, price, reason)


# --- decision (pure; unit-tested). Stops are handled separately, before this. -
def decide_targets(held, scores, absm, turnover_m, sector_map, regime_now, is_rebalance, P):
    if not regime_now:
        return []
    full = select_stocks(scores, absm, turnover_m, sector_map, regime_now, P)  # today's ideal 10
    if is_rebalance:
        return full
    target = P.top_sectors * P.per_sector
    keep = [s for s in held if absm.get(s, -1) > 0]        # survivors stay
    for s in full:                                          # refill freed slots with today's best
        if len(keep) >= target:
            break
        if s not in keep:
            keep.append(s)
    return keep[:target]


# --- one daily cycle ---------------------------------------------------------
def run_cycle(P):
    E._load_env()
    sector_map = load_universe(DIRPATH)
    if not sector_map:
        print(f"[stocks] no universe in {DIRPATH}."); return
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[stocks] Kite login failed: {e}"); return
    L = load_ledger()
    live = LIVE and LIVE_CONFIRM
    L["mode"] = "LIVE" if live else "PAPER"
    executor = LiveExecutor(L, kite, set(sector_map)) if live else PaperExecutor(L)

    # data: universe monthly close + turnover, Nifty regime (heavy monthly fetch)
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=int(os.environ.get("EQS2_DAYS", "700")) + 400)
    syms = list(sector_map) + [P.benchmark]
    monthly, turnover, nifty_daily = {}, {}, []
    print(f"[stocks] fetching {len(syms)} symbols...")
    for n, s in enumerate(syms, 1):
        try:
            tok = E._TOKENS.get(s) or kite.ltp([f"NSE:{s}"]).get(f"NSE:{s}", {}).get("instrument_token")
            if not tok:
                continue
            bars = _hist_chunked(kite, tok, frm, to, "day")
            if not bars:
                continue
            monthly[s], turnover[s] = _monthly_close_turnover(bars)
            if s == P.benchmark:
                nifty_daily = bars
            time.sleep(0.22)
        except Exception as e:
            print(f"  {s}: {e}")
        if n % 100 == 0:
            print(f"  ...{n}/{len(syms)}")
    if not monthly or not nifty_daily:
        print("[stocks] insufficient data."); return

    # live LTPs for fills + stop checks (one batched call)
    uni = list(sector_map)
    ltp = {}
    for i in range(0, len(uni), 250):
        chunk = uni[i:i + 250]
        try:
            q = kite.ltp([f"NSE:{s}" for s in chunk])
            for s in chunk:
                ltp[s] = float(q.get(f"NSE:{s}", {}).get("last_price") or 0)
        except Exception:
            pass

    months = sorted({m for c in monthly.values() for m in c})
    i = len(months) - 1
    scores, absm = stock_scores(monthly, months, i, P, [s for s in sector_map])
    turnover_m = {s: turnover.get(s, {}).get(months[i], 0) for s in scores}
    nclose = [b["close"] for b in nifty_daily if str(b["date"])[:10] != _today()]
    regime_now = (len(nclose) > 200 and nclose[-1] > sum(nclose[-200:]) / 200) if P.use_regime else True
    if not _market_open_now():
        print("[stocks] NOTE: market closed — paper fills use last price; live queues AMO. "
              "Best run ~09:20 IST.")

    # STOP-LOSS pass (daily, price-based) -- runs regardless of momentum
    for sym in list(L["holdings"]):
        p = ltp.get(sym, 0)
        stop = L["holdings"][sym].get("stop_price", 0)
        if p and stop and p <= stop:
            executor.sell(sym, L["holdings"][sym]["qty"], p, f"STOP_{STOP_PCT:.0f}%")

    held = list(L["holdings"])
    is_rebalance = L.get("last_rebalance") != _month()
    reason = ("REBALANCE" if (is_rebalance and regime_now)
              else "RISK-OFF" if not regime_now else "risk-check")
    targets = decide_targets(held, scores, absm, turnover_m, sector_map, regime_now, is_rebalance, P)

    # execute: sell non-targets, then buy targets toward equal weight
    for sym in [s for s in L["holdings"] if s not in targets]:
        if ltp.get(sym):
            executor.sell(sym, L["holdings"][sym]["qty"], ltp[sym], reason)
    slots = P.top_sectors * P.per_sector
    equity = L["cash"] + sum(L["holdings"][s]["qty"] * ltp.get(s, 0) for s in L["holdings"])
    per = equity / slots if slots else 0
    for sym in targets:
        p = ltp.get(sym, 0)
        if not p:
            continue
        cur = L["holdings"].get(sym, {}).get("qty", 0) * p
        qty = int((per - cur) // p)
        if qty > 0:
            executor.buy(sym, qty, p, sector_map.get(sym, "?"), reason)
    if is_rebalance and regime_now:
        L["last_rebalance"] = _month()

    equity = L["cash"] + sum(L["holdings"][s]["qty"] * ltp.get(s, 0) for s in L["holdings"])
    L["equity_history"].append({"date": _today(), "equity": round(equity, 2),
                                "nifty": round(nclose[-1], 2) if nclose else 0})
    save_ledger(L)

    names = ", ".join(sorted(L["holdings"])) or "CASH"
    ret = (equity / L["starting_capital"] - 1) * 100
    msg = (f"📈 ELON STOCKS [{L['mode']}] {_today()}\n"
           f"Regime: {'UP' if regime_now else 'DOWN → cash'} | {reason}\n"
           f"Hold ({len(L['holdings'])}): {names}\n"
           f"Equity Rs {equity:,.0f} ({ret:+.2f}%) | Cash Rs {L['cash']:,.0f}")
    print("\n" + msg + "\n")
    tg(msg)


def status():
    L = load_ledger()
    eh = L["equity_history"]
    start = L["starting_capital"]
    eq = eh[-1]["equity"] if eh else L["cash"]
    print("\n" + "=" * 66)
    print(f"  ELON STRATEGY 2 (STOCKS) · SCORECARD  [{L.get('mode','PAPER')}]")
    print("=" * 66)
    print(f"  Starting : Rs {start:,.0f}    Equity : Rs {eq:,.0f}  ({(eq/start-1)*100:+.2f}%)")
    print(f"  Cash     : Rs {L['cash']:,.0f}")
    if len(eh) >= 2 and eh[0].get("nifty") and eh[-1].get("nifty"):
        s = eq / start - 1
        nif = eh[-1]["nifty"] / eh[0]["nifty"] - 1
        print(f"  Since inception: strategy {s*100:+.2f}%  vs  Nifty {nif*100:+.2f}%  "
              f"(edge {(s-nif)*100:+.2f}%)")
        print(f"  Verdict  : {'WINNING vs index — keep paper-running.' if s > nif and s > 0 else 'NOT beating index yet — keep PAPER.'}")
    print("-" * 66)
    print(f"  Holdings ({len(L['holdings'])}):")
    for sym, h in L["holdings"].items():
        print(f"    {sym:12} qty {h['qty']:>5}  entry {h['avg_price']:>8.2f}  stop {h.get('stop_price',0):>8.2f}  ({h['sector']})")
    for t in L["trades"][-8:]:
        pnl = f"  P&L {t['pnl']:+,.0f}" if "pnl" in t else ""
        print(f"    {t['date']} {t['side']:4} {t['sym']:12} x{t['qty']:<4} @ {t['price']:>8.2f} [{t.get('reason','')}]{pnl}")
    print("=" * 66)
    print(f"  Ledger: {LEDGER_PATH}   (live: EQS2_LIVE=1 AND EQS2_LIVE_CONFIRM=YES)\n")


# --- offline self-test -------------------------------------------------------
def selftest():
    P = StockP(); P.top_sectors = 1; P.per_sector = 2; P.min_turnover = 0
    ok = True

    L = {"mode": "PAPER", "starting_capital": 1_000_000, "cash": 1_000_000,
         "holdings": {}, "trades": [], "equity_history": [], "last_rebalance": ""}
    ex = PaperExecutor(L)
    ex.buy("TATAELXSI", 100, 100.0, "IT", "t")
    ok1 = L["holdings"]["TATAELXSI"]["stop_price"] == round(100 * (1 - STOP_PCT / 100), 2)
    ex.sell("TATAELXSI", 100, 110.0, "t")
    ok1 = ok1 and L["trades"][-1]["pnl"] == 1000.0 and "TATAELXSI" not in L["holdings"]
    print(f"  [1] ledger buy sets stop, sell books P&L : {'PASS' if ok1 else 'FAIL'}")
    ok &= ok1

    scores = {"A1": 0.3, "A2": 0.25, "A3": 0.05, "B1": 0.02}
    absm = {k: 0.2 for k in scores}
    smap = {"A1": "SECA", "A2": "SECA", "A3": "SECA", "B1": "SECB"}
    turn = {k: 1e9 for k in scores}
    t2 = decide_targets([], scores, absm, turn, smap, False, True, P)   # regime off -> cash
    ok2 = t2 == []
    print(f"  [2] regime OFF -> cash                   : {'PASS' if ok2 else 'FAIL'} ({t2})")
    ok &= ok2

    t3 = decide_targets([], scores, absm, turn, smap, True, True, P)    # rebalance -> A1,A2
    ok3 = set(t3) == {"A1", "A2"}
    print(f"  [3] rebalance -> strong sector's 2 stocks: {'PASS' if ok3 else 'FAIL'} ({t3})")
    ok &= ok3

    # normal day, one holding broke down (abs<0) -> refill from best.
    absm4 = dict(absm); absm4["A2"] = -0.1
    t4 = decide_targets(["A1", "A2"], scores, absm4, turn, smap, True, False, P)
    ok4 = "A2" not in t4 and "A1" in t4 and len(t4) == 2   # A2 dropped, refilled (A3)
    print(f"  [4] normal day: drop broken + refill     : {'PASS' if ok4 else 'FAIL'} ({t4})")
    ok &= ok4

    ok5 = not (LIVE and LIVE_CONFIRM)
    print(f"  [5] LIVE off by default                  : {'PASS' if ok5 else 'FAIL'}")
    ok &= ok5

    print("\n" + ("✓ ALL SELF-TESTS PASSED — Strategy 2 live engine verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Elon Strategy 2 live/paper (sector-leaders, NRO).")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--status", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    if args.status:
        status(); return
    if args.run:
        if LIVE and LIVE_CONFIRM:
            print("⚠️  EQS2_LIVE=1 & confirmed — REAL delivery orders may be placed.")
        run_cycle(StockP()); return
    print("Use --selftest, --run, or --status.")


if __name__ == "__main__":
    main()
