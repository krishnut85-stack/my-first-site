#!/usr/bin/env python3
"""Early Bird OPTIONS paper-trader — convert scanner signals into F&O trades.

The Early Bird scanner (run_earlybird.py) is alert-only: it logs option-flow
signals to data/earlybird/signals_<date>.jsonl. This module reads the strong
ones and PAPER-trades them as bought options, to MEASURE whether the signals
actually make money.

Honest warning (see POSTMORTEM.md): buying CE/PE after a signal is what bled
the old GIR bot — you pay elevated IV late and fight theta. This build limits
that damage as much as buying-options allows:
  * BULLISH -> buy ATM CALL ; BEARISH -> buy ATM PUT, nearest expiry.
  * INTRADAY ONLY: every position is squared off the same day by SQUAREOFF_T
    (no overnight theta / IV-crush). "Sell quickly", enforced.
  * Quick target (+TARGET_PCT) / tight stop (-STOP_PCT) on the premium.
  * Liquidity gate (min OI/volume) so fills are realistic.
  * 1 lot, max concurrent, daily-loss kill switch. PAPER fills only — no real
    orders are ever sent.

Run from /home/globalbot/my-first-site (needs the Early Bird scanner running so
the signals file exists):
  python3 scripts/run_earlybird_options.py            # market-hours loop
  python3 scripts/run_earlybird_options.py --once     # one cycle (testing)
  python3 scripts/run_earlybird_options.py --status    # ledger + positions
"""
import argparse
import json
import logging
import sys
import time
import datetime as dt
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from algotrade.notify import notify
from algotrade.timeutils import now_ist, is_weekday

log = logging.getLogger("earlybird_options")
BASE = Path(__file__).resolve().parent.parent
SIG_DIR = BASE / "data" / "earlybird"
STATE_DIR = BASE / "data" / "earlybird_options"


class CFG:
    BOOK = 200_000.0
    POSITION_RS = 25_000.0      # max premium outlay per option trade
    MAX_CONCURRENT = 5
    MAX_ENTRIES_PER_DAY = 8
    MIN_SCORE = 80              # only strong signals
    TARGET_PCT = 0.25          # +25% on the option premium -> take profit
    STOP_PCT = 0.20            # -20% on the premium -> cut
    MIN_OPTION_OI = 5_000      # liquidity floor
    MIN_OPTION_VOL = 1_000
    DAILY_LOSS_LIMIT = 10_000.0
    SLIP = 0.01                # 1% slippage each side (options are wide)
    MIN_DTE = 1                # nearest expiry with at least 1 day left
    POLL_SECONDS = 60
    OPEN_T = dt.time(9, 20)
    ENTRY_CUTOFF_T = dt.time(14, 45)   # no NEW entries after this
    SQUAREOFF_T = dt.time(15, 15)      # force-close everything (intraday only)


# --------------------------------------------------------------------------- #
#  Kite helpers
# --------------------------------------------------------------------------- #
def stock_spot(kite, sym):
    try:
        k = f"NSE:{sym}"
        return float(kite.ltp([k])[k]["last_price"])
    except Exception as e:
        log.warning("spot failed %s: %s", sym, e)
        return None


def opt_quote(kite, tsym):
    key = f"NFO:{tsym}"
    try:
        q = kite.quote([key])[key]
        return {"ltp": float(q.get("last_price") or 0),
                "oi": int(q.get("oi") or 0),
                "vol": int(q.get("volume") or q.get("volume_traded") or 0)}
    except Exception as e:
        log.warning("opt quote failed %s: %s", tsym, e)
        return None


def build_chains(kite, min_dte=CFG.MIN_DTE):
    """Per underlying -> nearest-expiry ATM-resolvable chain with lot size."""
    today = now_ist().date()
    by_name = defaultdict(list)
    for inst in kite.instruments("NFO"):
        if inst.get("instrument_type") in ("CE", "PE") and inst.get("segment") == "NFO-OPT":
            by_name[inst["name"]].append(inst)
    chains = {}
    for name, opts in by_name.items():
        expiries = sorted({o["expiry"] for o in opts})
        expiry = next((e for e in expiries if (e - today).days >= min_dte), None)
        if expiry is None:
            continue
        strikes = defaultdict(dict)
        lot = 0
        for o in opts:
            if o["expiry"] == expiry:
                strikes[float(o["strike"])][o["instrument_type"]] = o["tradingsymbol"]
                lot = o.get("lot_size") or lot
        chains[name] = {"expiry": str(expiry), "dte": (expiry - today).days,
                        "lot": int(lot or 0), "strikes": dict(strikes)}
    log.info("NFO chains built: %d underlyings", len(chains))
    return chains


def atm_option(chain, spot, direction):
    strikes = sorted(chain["strikes"])
    if not strikes:
        return None
    atm = min(strikes, key=lambda k: abs(k - spot))
    leg = "CE" if direction == "BULLISH" else "PE"
    tsym = chain["strikes"][atm].get(leg)
    return (tsym, atm, leg) if tsym else None


# --------------------------------------------------------------------------- #
#  Ledger (own paper book, persisted)
# --------------------------------------------------------------------------- #
class Ledger:
    def __init__(self):
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.pos = self._load(STATE_DIR / "positions.json", {})
        self.state = self._load(STATE_DIR / "ledger.json", None) or {
            "cash": CFG.BOOK, "realized_pnl": 0.0, "entries_today": 0,
            "day": str(now_ist().date()), "day_realized": 0.0, "traded_today": []}

    def _load(self, p, d):
        try:
            return json.loads(Path(p).read_text())
        except Exception:
            return d

    def save(self):
        (STATE_DIR / "positions.json").write_text(json.dumps(self.pos, indent=2))
        (STATE_DIR / "ledger.json").write_text(json.dumps(self.state, indent=2))

    def roll_day(self):
        today = str(now_ist().date())
        if self.state.get("day") != today:
            self.state.update(day=today, entries_today=0, day_realized=0.0,
                              traded_today=[])
            self.save()

    def can_enter(self, cost):
        if len(self.pos) >= CFG.MAX_CONCURRENT:
            return False, "max concurrent"
        if self.state["entries_today"] >= CFG.MAX_ENTRIES_PER_DAY:
            return False, "daily entry cap"
        if cost > self.state["cash"]:
            return False, "insufficient cash"
        if -self.state.get("day_realized", 0.0) >= CFG.DAILY_LOSS_LIMIT:
            return False, "daily loss limit"
        return True, "ok"

    def open(self, tsym, under, qty, premium, meta):
        self.state["cash"] -= qty * premium
        self.state["entries_today"] += 1
        self.state.setdefault("traded_today", []).append(under)
        self.pos[tsym] = {
            "tsym": tsym, "under": under, "qty": qty, "entry": premium,
            "entry_time": now_ist().isoformat(),
            "target": round(premium * (1 + CFG.TARGET_PCT), 2),
            "stop": round(premium * (1 - CFG.STOP_PCT), 2),
            "leg": meta.get("leg"), "score": meta.get("score")}
        self.save()

    def close(self, tsym, premium, reason):
        p = self.pos.get(tsym)
        if not p:
            return 0.0
        qty = p["qty"]
        pnl = (premium - p["entry"]) * qty
        self.state["cash"] += qty * premium
        self.state["realized_pnl"] += pnl
        self.state["day_realized"] = self.state.get("day_realized", 0.0) + pnl
        self.pos.pop(tsym, None)
        self.save()
        return pnl


# --------------------------------------------------------------------------- #
#  Trader
# --------------------------------------------------------------------------- #
class EarlyBirdOptions:
    def __init__(self, kite):
        self.kite = kite
        self.led = Ledger()
        self._chains = None
        self._chains_day = None

    def chains(self):
        today = now_ist().date()
        if self._chains is None or self._chains_day != today:
            self._chains = build_chains(self.kite)
            self._chains_day = today
        return self._chains

    def _signals_today(self):
        f = SIG_DIR / f"signals_{now_ist().date().isoformat()}.jsonl"
        if not f.exists():
            log.warning("no signals file yet: %s (is the Early Bird scanner running?)", f)
            return []
        out = []
        for line in f.read_text().splitlines():
            try:
                out.append(json.loads(line))
            except Exception:
                continue
        return out

    def scan_and_enter(self):
        self.led.roll_day()
        if now_ist().time() >= CFG.ENTRY_CUTOFF_T:
            return  # too late in the day to open an intraday scalp
        best = {}
        for s in self._signals_today():
            if s.get("pattern") == "EOD_RESULT":
                continue
            if s.get("direction") not in ("BULLISH", "BEARISH"):
                continue
            if int(s.get("score", 0)) < CFG.MIN_SCORE:
                continue
            sym = s.get("symbol")
            if not sym or sym in self.led.state.get("traded_today", []):
                continue
            cur = best.get(sym)
            if cur is None or s["score"] > cur["score"]:
                best[sym] = s
        chains = self.chains()
        for sym, s in sorted(best.items(), key=lambda kv: -kv[1]["score"]):
            chain = chains.get(sym)
            if not chain or not chain["lot"]:
                log.info("skip %s: no F&O chain", sym)
                continue
            spot = stock_spot(self.kite, sym) or s.get("spot")
            if not spot:
                continue
            resolved = atm_option(chain, spot, s["direction"])
            if not resolved:
                continue
            tsym, strike, leg = resolved
            if tsym in self.led.pos:
                continue
            q = opt_quote(self.kite, tsym)
            if not q or q["ltp"] <= 0:
                continue
            if q["oi"] < CFG.MIN_OPTION_OI or q["vol"] < CFG.MIN_OPTION_VOL:
                log.info("skip %s %s: illiquid (oi=%s vol=%s)", sym, tsym, q["oi"], q["vol"])
                continue
            premium = round(q["ltp"] * (1 + CFG.SLIP), 2)   # pay up (slippage)
            lot = chain["lot"]
            cost_one_lot = premium * lot
            if cost_one_lot > CFG.POSITION_RS:
                log.info("skip %s: 1 lot (₹%.0f) over per-trade cap", tsym, cost_one_lot)
                continue
            qty = lot  # 1 lot
            ok, why = self.led.can_enter(qty * premium)
            if not ok:
                log.info("skip %s: %s", tsym, why)
                if why in ("max concurrent", "daily entry cap", "daily loss limit"):
                    break
                continue
            self.led.open(tsym, sym, qty, premium, {"leg": leg, "score": s["score"]})
            notify(f"EARLYBIRD-OPT BUY {tsym} ({sym} {leg})\n"
                   f"x{qty} @ ₹{premium:.2f}  cost ₹{qty*premium:.0f}\n"
                   f"why: {s.get('pattern')} score {s['score']} | spot ₹{spot:.1f} strike {strike:g}\n"
                   f"target ₹{premium*(1+CFG.TARGET_PCT):.2f}  stop ₹{premium*(1-CFG.STOP_PCT):.2f}  "
                   f"[PAPER, intraday]")

    def manage(self):
        self.led.roll_day()
        squareoff = now_ist().time() >= CFG.SQUAREOFF_T
        for tsym in list(self.led.pos.keys()):
            p = self.led.pos[tsym]
            q = opt_quote(self.kite, tsym)
            ltp = q["ltp"] if q else None
            reason = None
            if squareoff:
                reason = "eod_squareoff"
            elif ltp is not None:
                if ltp >= p["target"]:
                    reason = "target"
                elif ltp <= p["stop"]:
                    reason = "stop"
            if reason:
                price = round((ltp if ltp is not None else p["entry"]) * (1 - CFG.SLIP), 2)
                pnl = self.led.close(tsym, price, reason)
                notify(f"EARLYBIRD-OPT SELL {tsym} ({p['under']}) x{p['qty']} @ ₹{price:.2f}  "
                       f"pnl ₹{pnl:.0f}  ({reason}) [PAPER]")
        self.led.save()

    def status(self):
        s = self.led.state
        lines = [f"EARLYBIRD-OPT ledger: cash ₹{s['cash']:.0f}  realized ₹{s['realized_pnl']:.0f}  "
                 f"open {len(self.led.pos)}  entries_today {s['entries_today']}  "
                 f"day_pnl ₹{s.get('day_realized',0.0):.0f}"]
        for tsym, p in self.led.pos.items():
            q = opt_quote(self.kite, tsym)
            ltp = q["ltp"] if q else p["entry"]
            upnl = (ltp - p["entry"]) * p["qty"]
            lines.append(f"  {tsym} ({p['under']}) x{p['qty']} @ ₹{p['entry']:.2f} "
                         f"now ₹{ltp:.2f} uPnL ₹{upnl:.0f}")
        msg = "\n".join(lines)
        log.info(msg.replace("\n", " | "))
        notify(msg)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--interval", type=int, default=CFG.POLL_SECONDS)
    args = ap.parse_args()
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s")

    from algotrade.env import load_dotenv_if_present
    from algotrade.brokers.kite_auth import auto_login
    load_dotenv_if_present()
    kite = auto_login()
    bot = EarlyBirdOptions(kite)

    if args.status:
        bot.status()
        return
    if args.once:
        bot.manage()
        bot.scan_and_enter()
        bot.status()
        return

    notify(f"EARLYBIRD-OPT online — buys ATM options on score≥{CFG.MIN_SCORE} signals, "
           f"intraday only, squares off {CFG.SQUAREOFF_T.strftime('%H:%M')} [PAPER ₹{CFG.BOOK:.0f}]")
    while True:
        try:
            now = now_ist()
            if not (is_weekday() and CFG.OPEN_T <= now.time() <= dt.time(15, 30)):
                time.sleep(300)
                continue
            bot.manage()
            bot.scan_and_enter()
        except Exception:
            log.exception("cycle failed")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
