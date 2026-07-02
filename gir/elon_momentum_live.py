#!/usr/bin/env python3
"""
elon_momentum_live.py  -  ELON MOMENTUM live/paper engine (NRO delivery, ETFs)
==============================================================================
Runs the proven dual-momentum sector-rotation strategy as a real forward
track record. SAME decision code as the backtest (imported from elon_momentum),
so PAPER == LIVE. Flip to real orders with ONE switch once paper is winning.

TWO CLOCKS (research-backed):
  * RANK/REBALANCE = MONTHLY  -> where the momentum edge lives; daily re-ranking
    just adds turnover/whipsaw for worse net returns.
  * RISK CHECK     = DAILY     -> so a crash isn't ignored until month-end. Every
    day: if the market breaks its 200-DMA, or a held sector's 12m momentum turns
    negative, EXIT that position to CASH immediately (don't wait to rebalance).

MODES:
  PAPER (default): simulated fills at the real ETF LTP; a persistent JSON ledger
    tracks cash/holdings/trades/equity. NO real orders.
  LIVE (EQM_LIVE=1 AND EQM_LIVE_CONFIRM=YES): places real CNC (delivery) orders
    on the ETF whitelist only, with a hard max order value. Never MIS / short /
    F&O. Same logic as paper.

ISOLATION: own ledger file, own config, own Telegram (EQM_TG_* vars ONLY) --
it never touches Mayura's or any other lane's Telegram routing or files.

USAGE (on the droplet, after: cd /home/globalbot && set -a && source .env && set +a):
  python3 elon_momentum_live.py --selftest     # offline engine tests (no Kite)
  python3 elon_momentum_live.py --run          # one daily cycle (PAPER)
  python3 elon_momentum_live.py --status        # scorecard: paper equity vs Nifty
Cron (daily ~09:20 IST, in-session so paper fills at LIVE prices == live orders):
  50 3 * * 1-5  cd /home/globalbot && set -a && . ./.env && set +a && \
                python3 elon_momentum_live.py --run >> elon_momentum.log 2>&1
  # 09:20 IST = 03:50 UTC. (Never trades at night: after-hours live runs queue AMOs
  # that execute at the next open.)
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
from elon_momentum import (MomP, momentum_scores, select_weights, best_defensive,  # noqa: E402
                           _hist_chunked, _monthly_from_daily, _regime_by_month)

_DEFENSIVE = MomP().defensive           # gold / gilt / liquid safe-harbour ETFs

IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
def _today():
    return dt.datetime.now(IST).strftime("%Y-%m-%d")
def _month():
    return dt.datetime.now(IST).strftime("%Y-%m")
def _market_open_now():
    n = dt.datetime.now(IST)
    return n.weekday() < 5 and (9, 15) <= (n.hour, n.minute) <= (15, 30)

# --- sector index -> tradeable NSE ETF (DELIVERY/CNC, NRO-legal) --------------
# Only genuinely liquid ETFs. Sectors without a liquid ETF are simply not traded
# live (flagged). VERIFY each symbol + its live liquidity on Kite before going
# live; expand this map as liquid ETFs appear (or use sector futures via F&O).
ETF_MAP = {
    "NIFTY 50":       "NIFTYBEES",
    "NIFTY NEXT 50":  "JUNIORBEES",
    "NIFTY BANK":     "BANKBEES",
    "NIFTY IT":       "ITBEES",
    "NIFTY PHARMA":   "PHARMABEES",
    "NIFTY PSU BANK": "PSUBNKBEES",
}
TRADEABLE_SECTORS = list(ETF_MAP.keys())
ETF_WHITELIST = set(ETF_MAP.values()) | set(_DEFENSIVE)   # equity + defensive ETFs

LEDGER_PATH = os.environ.get("EQM_LEDGER", "/home/globalbot/elon_momentum_paper.json")
START_CAPITAL = float(os.environ.get("EQM_CAPITAL", "1000000"))   # Rs 10L paper
MAX_ORDER = float(os.environ.get("EQM_MAX_ORDER", "100000"))      # live safety cap/order
LIVE = os.environ.get("EQM_LIVE", "0").strip() == "1"
LIVE_CONFIRM = os.environ.get("EQM_LIVE_CONFIRM", "").strip().upper() == "YES"


# --- persistent ledger -------------------------------------------------------
def load_ledger(path=None):
    path = path or LEDGER_PATH
    if os.path.exists(path):
        return json.load(open(path))
    return {"mode": "PAPER", "starting_capital": START_CAPITAL, "cash": START_CAPITAL,
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


# --- Telegram (ISOLATED: EQM_TG_* only; never touches other lanes) -----------
def tg(msg):
    tok = os.environ.get("EQM_TG_BOT_TOKEN", "").strip()
    chat = os.environ.get("EQM_TG_CHAT_ID", "").strip()
    if not (tok and chat):
        return
    data = {"chat_id": chat, "text": msg}
    thread = os.environ.get("EQM_TG_THREAD", "").strip()
    if thread:
        data["message_thread_id"] = int(thread)
    try:
        req = urllib.request.Request(f"https://api.telegram.org/bot{tok}/sendMessage",
                                     data=urllib.parse.urlencode(data).encode())
        urllib.request.urlopen(req, timeout=15)
    except Exception as e:  # noqa: BLE001
        print(f"[momentum] telegram send failed: {e}")


# --- executors (same interface; paper vs live) -------------------------------
class PaperExecutor:
    def __init__(self, L):
        self.L = L

    def buy(self, etf, qty, price, sector, reason):
        cost = qty * price
        if qty <= 0 or cost > self.L["cash"] + 1e-6:
            return False
        self.L["cash"] -= cost
        h = self.L["holdings"].get(etf)
        if h:
            tot = h["qty"] + qty
            h["avg_price"] = (h["avg_price"] * h["qty"] + price * qty) / tot
            h["qty"] = tot
        else:
            self.L["holdings"][etf] = {"qty": qty, "avg_price": price,
                                       "sector": sector, "entry_date": _today()}
        self.L["trades"].append({"date": _today(), "side": "BUY", "etf": etf, "qty": qty,
                                 "price": round(price, 2), "reason": reason})
        return True

    def sell(self, etf, qty, price, reason):
        h = self.L["holdings"].get(etf)
        if not h or qty <= 0:
            return False
        qty = min(qty, h["qty"])
        self.L["cash"] += qty * price
        pnl = (price - h["avg_price"]) * qty
        h["qty"] -= qty
        if h["qty"] <= 0:
            del self.L["holdings"][etf]
        self.L["trades"].append({"date": _today(), "side": "SELL", "etf": etf, "qty": qty,
                                 "price": round(price, 2), "reason": reason, "pnl": round(pnl, 2)})
        return True


class LiveExecutor(PaperExecutor):
    """Places REAL CNC orders, then mirrors the fill into the ledger. Guarded:
    whitelist-only, delivery-only, hard max order value, double-gated by
    EQM_LIVE=1 + EQM_LIVE_CONFIRM=YES."""
    def __init__(self, L, kite):
        super().__init__(L)
        self.kite = kite

    def _place(self, etf, qty, side):
        if etf not in ETF_WHITELIST:
            print(f"[LIVE] REFUSED {etf}: not in ETF whitelist"); return False
        # NEVER trade at night: in-session -> regular market order (fills now);
        # outside market hours -> AMO, which the broker executes at the NEXT open.
        variety = self.kite.VARIETY_REGULAR if _market_open_now() else self.kite.VARIETY_AMO
        try:
            self.kite.place_order(
                variety=variety, exchange="NSE", tradingsymbol=etf,
                transaction_type=side, quantity=int(qty),
                product=self.kite.PRODUCT_CNC, order_type=self.kite.ORDER_TYPE_MARKET)
            print(f"[LIVE] {side} {etf} x{qty} ({variety})")
            return True
        except Exception as e:  # noqa: BLE001
            print(f"[LIVE] order failed {side} {etf} x{qty}: {e}"); return False

    def buy(self, etf, qty, price, sector, reason):
        if qty * price > MAX_ORDER:
            qty = int(MAX_ORDER // price)          # clamp to the safety cap
        if qty <= 0:
            return False
        if not self._place(etf, qty, "BUY"):
            return False
        return super().buy(etf, qty, price, sector, reason)

    def sell(self, etf, qty, price, reason):
        h = self.L["holdings"].get(etf)
        if not h:
            return False
        if not self._place(etf, min(qty, h["qty"]), "SELL"):
            return False
        return super().sell(etf, qty, price, reason)


# --- decision (pure; unit-tested) --------------------------------------------
def decide_targets(held_sectors, scores, abs_moms, regime_now, is_rebalance, P):
    """Which sectors to hold after this cycle.
      - market unhealthy (Nifty below 200-DMA) -> CASH (sell all; don't catch
        knives by reinvesting into a market-wide selloff).
      - rebalance day -> full top-N dual-momentum selection.
      - normal day, market HEALTHY -> keep holdings whose 12m momentum is still
        > 0, and if that frees a slot, REFILL it with the next-best qualifying
        sector (stay fully invested in the winners; Q3)."""
    if not regime_now:
        return set()
    if is_rebalance:
        return set(select_weights(scores, abs_moms, True, P).keys())
    keep = {s for s in held_sectors if abs_moms.get(s, -1) > 0}   # survivors
    if len(keep) < P.top_n:                                        # a slot broke down -> refill
        for s in sorted(scores, key=scores.get, reverse=True):
            if len(keep) >= P.top_n:
                break
            if abs_moms.get(s, -1) > 0:
                keep.add(s)
    return keep


def build_weights(targets, monthly, months, i, ltp, P):
    """Equity weights (top-N equal), then route the REMAINING weight to the
    strongest DEFENSIVE asset (gold/gilt/liquid) instead of idle cash. Returns
    ({etf: weight}, {etf: label})."""
    weights, labels = {}, {}
    for s in targets:
        etf = ETF_MAP.get(s)
        if etf:
            weights[etf] = 1.0 / max(P.top_n, 1)
            labels[etf] = s
    cash_w = 1.0 - sum(weights.values())
    if cash_w > 0.02:
        dpick = best_defensive(monthly, months, i, P)     # gold/gilt/liquid by momentum
        if dpick and ltp.get(dpick):
            weights[dpick] = weights.get(dpick, 0) + cash_w
            labels[dpick] = "DEFENSIVE"
    return weights, labels


def _rebalance(weights, labels, L, ltp, executor, reason):
    """Rebalance the book to {etf: weight}: sell anything not targeted (incl. a
    defensive ETF no longer picked), then buy underweight names toward target."""
    for etf in list(L["holdings"]):
        if etf not in weights and ltp.get(etf):
            executor.sell(etf, L["holdings"][etf]["qty"], ltp[etf], reason)
    equity = L["cash"] + sum(L["holdings"][e]["qty"] * ltp.get(e, 0) for e in L["holdings"])
    for etf, w in weights.items():
        p = ltp.get(etf)
        if not p:
            continue
        cur = L["holdings"].get(etf, {}).get("qty", 0) * p
        qty = int((w * equity - cur) // p)
        if qty > 0:
            executor.buy(etf, qty, p, labels.get(etf, "?"), reason)


# --- one daily cycle ---------------------------------------------------------
def run_cycle(P):
    E._load_env()
    try:
        kite = E.get_kite()
    except Exception as e:
        print(f"[momentum] Kite login failed: {e}\n  -> source /home/globalbot/.env first.")
        return
    L = load_ledger()
    live = LIVE and LIVE_CONFIRM
    L["mode"] = "LIVE" if live else "PAPER"
    executor = LiveExecutor(L, kite) if live else PaperExecutor(L)

    # 1) data: monthly closes for the tradeable sectors + Nifty; daily regime; ETF LTPs
    to = dt.datetime.now()
    frm = to - dt.timedelta(days=520)               # ~14mo warms up the 12m lookback
    syms = list(dict.fromkeys(TRADEABLE_SECTORS + [P.benchmark] + list(P.defensive)))
    monthly, nifty_daily = {}, []
    for s in syms:
        try:
            tok = E._TOKENS.get(s) or kite.ltp([f"NSE:{s}"]).get(f"NSE:{s}", {}).get("instrument_token")
            if not tok:
                continue
            bars = _hist_chunked(kite, tok, frm, to, "day")
            monthly[s] = _monthly_from_daily(bars)
            if s == P.benchmark:
                nifty_daily = bars
            time.sleep(0.25)
        except Exception as e:
            print(f"  {s}: history failed ({e})")
    if not monthly or not nifty_daily:
        print("[momentum] insufficient data this cycle."); return
    # ETF LTPs (real, used for fills in paper AND live)
    etfs = list(ETF_WHITELIST)
    try:
        q = kite.ltp([f"NSE:{e}" for e in etfs])
        ltp = {e: float(q.get(f"NSE:{e}", {}).get("last_price") or 0) for e in etfs}
    except Exception as e:
        print(f"[momentum] ETF LTP fetch failed ({e})"); return

    # 2) signals: monthly momentum ranking + DAILY regime (latest close vs 200-DMA)
    months = sorted({m for c in monthly.values() for m in c})
    i = len(months) - 1
    scores, abs_moms = momentum_scores(monthly, months, i, P)
    # regime on the last COMPLETED daily close (drop today's still-forming bar)
    nclose = [b["close"] for b in nifty_daily if str(b["date"])[:10] != _today()]
    regime_now = (len(nclose) > 200 and nclose[-1] > sum(nclose[-200:]) / 200) if P.use_regime else True
    if not _market_open_now():
        print("[momentum] NOTE: market closed — paper fills use last price; live "
              "orders would queue as AMO for the next open. Best run ~09:20 IST.")

    held_sectors = {h["sector"] for h in L["holdings"].values()}
    is_rebalance = L.get("last_rebalance") != _month()
    reason = ("REBALANCE" if (is_rebalance and regime_now)
              else "RISK-OFF (regime)" if not regime_now else "risk-check")
    targets = decide_targets(held_sectors, scores, abs_moms, regime_now, is_rebalance, P)

    # 3) execute: equity targets + defensive sleeve for the rest (never idle cash)
    before = {e: dict(h) for e, h in L["holdings"].items()}
    weights, labels = build_weights(targets, monthly, months, i, ltp, P)
    _rebalance(weights, labels, L, ltp, executor, reason)
    if is_rebalance and regime_now:
        L["last_rebalance"] = _month()

    # 4) mark-to-market + record equity (with Nifty level for the scorecard)
    equity = L["cash"] + sum(L["holdings"][e]["qty"] * ltp.get(e, 0) for e in L["holdings"])
    L["equity_history"].append({"date": _today(), "equity": round(equity, 2),
                                "nifty": round(nclose[-1], 2)})
    save_ledger(L)

    # 5) report + isolated Telegram (holdings now include the defensive sleeve)
    hold_str = ", ".join(f"{e}({h.get('sector','?')})" for e, h in sorted(L["holdings"].items())) or "CASH"
    ret = (equity / L["starting_capital"] - 1) * 100
    changed = before != L["holdings"]
    regtxt = "UP" if regime_now else "DOWN → defensive (gold/gilt/liquid)"
    msg = (f"🚀 ELON MOMENTUM [{L['mode']}] {_today()}\n"
           f"Regime: {regtxt} | {reason}\n"
           f"Hold: {hold_str}\n"
           f"Equity Rs {equity:,.0f} ({ret:+.2f}%) | Cash Rs {L['cash']:,.0f}")
    print("\n" + msg + "\n")
    if changed or is_rebalance or not regime_now:
        tg(msg)                                     # only ping on action / rebalance / risk-off


# --- scorecard (offline; reads the ledger) -----------------------------------
def status():
    L = load_ledger()
    eh = L["equity_history"]
    start = L["starting_capital"]
    eq = eh[-1]["equity"] if eh else L["cash"]
    print("\n" + "=" * 64)
    print(f"  ELON MOMENTUM · SCORECARD  [{L.get('mode','PAPER')}]")
    print("=" * 64)
    print(f"  Starting capital : Rs {start:,.0f}")
    print(f"  Equity (last)    : Rs {eq:,.0f}   ({(eq/start-1)*100:+.2f}%)")
    print(f"  Cash             : Rs {L['cash']:,.0f}")
    if len(eh) >= 2 and eh[0].get("nifty") and eh[-1].get("nifty"):
        strat = eq / start - 1
        nif = eh[-1]["nifty"] / eh[0]["nifty"] - 1
        edge = (strat - nif) * 100
        print(f"  Since inception  : strategy {strat*100:+.2f}%  vs  Nifty {nif*100:+.2f}%  "
              f"(edge {edge:+.2f}%)")
        v = ("WINNING vs the index — keep paper-running; consider going live when the"
             " edge holds a few months." if strat > nif and strat > 0
             else "NOT beating the index yet — keep it PAPER. Do not go live.")
        print(f"  Verdict          : {v}")
    print("-" * 64)
    print(f"  Holdings ({len(L['holdings'])}):")
    for etf, h in L["holdings"].items():
        print(f"    {etf:12} qty {h['qty']:>5}  entry {h['avg_price']:>9.2f}  ({h['sector']})")
    print(f"  Recent trades:")
    for t in L["trades"][-8:]:
        pnl = f"  P&L {t['pnl']:+,.0f}" if "pnl" in t else ""
        print(f"    {t['date']}  {t['side']:4} {t['etf']:12} x{t['qty']:<4} @ {t['price']:>8.2f}  "
              f"[{t.get('reason','')}]{pnl}")
    print("=" * 64)
    print(f"  Ledger: {LEDGER_PATH}   Mode: {L.get('mode','PAPER')} "
          f"(live requires EQM_LIVE=1 AND EQM_LIVE_CONFIRM=YES)\n")


# --- offline self-test (no Kite) ---------------------------------------------
def selftest():
    P = MomP(); P.top_n = 2
    ok = True

    # ledger + PaperExecutor: buy two, sell one.
    L = {"mode": "PAPER", "starting_capital": 1_000_000, "cash": 1_000_000,
         "holdings": {}, "trades": [], "equity_history": [], "last_rebalance": ""}
    ex = PaperExecutor(L)
    ex.buy("ITBEES", 1000, 40.0, "NIFTY IT", "t")
    ex.buy("BANKBEES", 500, 50.0, "NIFTY BANK", "t")
    ok1 = abs(L["cash"] - (1_000_000 - 40000 - 25000)) < 1e-6 and len(L["holdings"]) == 2
    ex.sell("ITBEES", 1000, 44.0, "t")             # +4/unit -> +4000 pnl
    ok1 = ok1 and "ITBEES" not in L["holdings"] and L["trades"][-1]["pnl"] == 4000.0
    print(f"  [1] paper ledger buy/sell + P&L      : {'PASS' if ok1 else 'FAIL'}")
    ok &= ok1

    # decide_targets: regime OFF -> cash.
    t2 = decide_targets({"NIFTY IT"}, {"NIFTY IT": 0.2}, {"NIFTY IT": 0.2}, False, True, P)
    ok2 = t2 == set()
    print(f"  [2] regime OFF -> target CASH        : {'PASS' if ok2 else 'FAIL'} ({t2})")
    ok &= ok2

    # decide_targets: rebalance day -> top-N by momentum, abs>0 only.
    scores = {"NIFTY IT": 0.30, "NIFTY BANK": 0.20, "NIFTY PHARMA": 0.10, "NIFTY PSU BANK": -0.05}
    absm = {"NIFTY IT": 0.30, "NIFTY BANK": 0.20, "NIFTY PHARMA": -0.10, "NIFTY PSU BANK": 0.05}
    t3 = decide_targets(set(), scores, absm, True, True, P)   # top2 = IT, BANK (both abs>0)
    ok3 = t3 == {"NIFTY IT", "NIFTY BANK"}
    print(f"  [3] rebalance -> top-N, abs>0 only   : {'PASS' if ok3 else 'FAIL'} ({t3})")
    ok &= ok3

    # decide_targets: non-rebalance day. Held PHARMA broke down (abs<0) in a
    # HEALTHY market -> sell it AND refill the slot with the next-best (BANK). (Q3)
    t4 = decide_targets({"NIFTY IT", "NIFTY PHARMA"}, scores, absm, True, False, P)
    ok4 = t4 == {"NIFTY IT", "NIFTY BANK"}
    print(f"  [4] risk exit + REFILL with next-best: {'PASS' if ok4 else 'FAIL'} ({t4})")
    ok &= ok4

    # build_weights + _rebalance: buys the equity ETFs (full equity, no cash left).
    L2 = {"cash": 1_000_000, "holdings": {}, "trades": [], "starting_capital": 1_000_000}
    ltp = {"ITBEES": 40.0, "BANKBEES": 50.0}
    w2, lab2 = build_weights({"NIFTY IT", "NIFTY BANK"}, {}, [], 0, ltp, P)
    _rebalance(w2, lab2, L2, ltp, PaperExecutor(L2), "t")
    ok5 = set(L2["holdings"]) == {"ITBEES", "BANKBEES"} and L2["cash"] < 1_000_000
    print(f"  [5] rebalance buys the equity ETFs   : {'PASS' if ok5 else 'FAIL'} "
          f"(holds {set(L2['holdings'])})")
    ok &= ok5

    # DEFENSIVE SLEEVE: regime off (no equity targets) + gold rising -> book goes
    # into GOLDBEES, NOT idle cash.
    mm = [f"20{y:02d}-{mo:02d}" for y in range(23, 25) for mo in range(1, 13)]
    monthly = {"GOLDBEES": {m: round(100 * (1.03 ** i), 3) for i, m in enumerate(mm)},
               "LIQUIDBEES": {m: round(100 * (1.005 ** i), 3) for i, m in enumerate(mm)}}
    Pd = MomP(); Pd.top_n = 2
    w3, lab3 = build_weights(set(), monthly, mm, len(mm) - 1, {"GOLDBEES": 60.0, "LIQUIDBEES": 100.0}, Pd)
    L3 = {"cash": 1_000_000, "holdings": {}, "trades": [], "starting_capital": 1_000_000}
    _rebalance(w3, lab3, L3, {"GOLDBEES": 60.0, "LIQUIDBEES": 100.0}, PaperExecutor(L3), "risk-off")
    ok_def = "GOLDBEES" in L3["holdings"]
    print(f"  [D] risk-off -> DEFENSIVE (gold), not cash: {'PASS' if ok_def else 'FAIL'} "
          f"(holds {set(L3['holdings'])})")
    ok &= ok_def

    # live is OFF unless explicitly enabled.
    ok6 = not (LIVE and LIVE_CONFIRM)
    print(f"  [6] LIVE off by default              : {'PASS' if ok6 else 'FAIL'}")
    ok &= ok6

    print("\n" + ("✓ ALL SELF-TESTS PASSED — live/paper engine verified offline."
                  if ok else "✗ SELF-TEST FAILURES."))
    return ok


def main():
    ap = argparse.ArgumentParser(description="Elon Momentum live/paper engine (NRO ETFs).")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--run", action="store_true", help="one daily cycle (paper unless EQM_LIVE)")
    ap.add_argument("--status", action="store_true", help="scorecard from the ledger")
    args = ap.parse_args()
    if args.selftest:
        sys.exit(0 if selftest() else 1)
    if args.status:
        status(); return
    if args.run:
        if LIVE and LIVE_CONFIRM:
            print("⚠️  EQM_LIVE=1 & confirmed — REAL delivery orders may be placed.")
        run_cycle(MomP())
        return
    print("Use --selftest, --run, or --status.")


if __name__ == "__main__":
    main()
