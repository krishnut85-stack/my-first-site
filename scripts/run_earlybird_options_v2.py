#!/usr/bin/env python3
"""Early Bird OPTIONS scalper v2 — make option trades on signals actually pay.

v1 bought a naked ATM option on every strong signal and bled (theta + IV crush
after a spiked-IV signal — the PRESTIGE problem). v2 fixes the structural
disadvantages and supports THREE structures (pick with --structure):

  credit  (default, recommended)  bullish -> bull-PUT credit spread
                                  bearish -> bear-CALL credit spread
        theta works FOR you; profit if the underlying just holds/moves your way.
  debit                           bullish -> bull-CALL debit spread
                                  bearish -> bear-PUT debit spread
        cheaper, defined risk, less IV/theta drag than a naked long.
  naked                           bullish -> ITM CALL ; bearish -> ITM PUT
        ~0.65-delta ITM (more intrinsic, less time-value) instead of ATM.

Shared edges on ALL structures:
  - IV FILTER: skip if the signal's IV already spiked (don't buy peak premium).
  - MOMENTUM CONFIRM: only enter if the underlying is actually moving your way
    intraday (vs prior close), not just on the OI footprint.
  - FAST EXITS: target/stop on the *position* P&L + same-day square-off (15:15).
  - liquidity gate on every leg; per-trade risk cap; max concurrent; kill switch.

PAPER ONLY: own ledger, simulated fills vs live Kite quotes. No real orders.

Usage (from /home/globalbot/my-first-site):
  python3 scripts/run_earlybird_options_v2.py --once                 # one cycle
  python3 scripts/run_earlybird_options_v2.py --structure debit --once
  python3 scripts/run_earlybird_options_v2.py --status
  python3 scripts/run_earlybird_options_v2.py                        # market loop
"""
import argparse, json, logging, re, sys, time
import datetime as dt
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from algotrade.notify import notify
from algotrade.timeutils import now_ist, is_weekday

log = logging.getLogger("earlybird_opt_v2")
BASE = Path(__file__).resolve().parent.parent
SIG_DIR = BASE / "data" / "earlybird"
STATE_BASE = BASE / "data" / "earlybird_options_v2"   # per-structure subdir so credit/debit don't collide


class CFG:
    STRUCTURE        = "credit"      # credit | debit | naked  (CLI --structure overrides)
    BOOK             = 200_000.0
    RISK_PER_TRADE   = 8_000.0       # max ₹ at risk per position (debit paid / credit max-loss)
    MAX_CONCURRENT   = 5
    MAX_ENTRIES_DAY  = 10
    MIN_SCORE        = 80
    IV_MAX_RISE      = 25.0          # skip if signal IV already rose > this % (peak premium)
    MOM_MIN          = 0.002         # underlying must be >=0.2% in your direction intraday
    SPREAD_WIDTH     = 1            # strikes between the two legs of a spread
    ITM_STEPS        = 1            # how many strikes ITM for the naked structure
    MIN_LEG_OI       = 5_000
    MIN_LEG_VOL      = 500
    SLIP             = 0.01
    MIN_DTE          = 1
    # exits (fractions of the position's defined risk/credit)
    DEBIT_TARGET     = 0.60         # +60% of debit -> take profit
    DEBIT_STOP       = 0.50         # -50% of debit -> cut
    CREDIT_TARGET    = 0.50         # capture 50% of the credit -> take profit
    CREDIT_STOP      = 1.00         # lose 1x the credit -> cut
    DAILY_LOSS_LIMIT = 8_000.0
    POLL_SECONDS     = 60
    OPEN_T           = dt.time(9, 20)
    ENTRY_CUTOFF_T   = dt.time(14, 45)
    SQUAREOFF_T      = dt.time(15, 15)

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [EBOPT2] %(levelname)s %(message)s")


# ----------------------------- Kite wiring (lazy) -----------------------------
def stock_quote(kite, sym):
    try:
        k = f"NSE:{sym}"
        q = kite.quote([k])[k]
        return float(q.get("last_price") or 0), float(q.get("ohlc", {}).get("close") or 0)
    except Exception as e:
        log.warning(f"stock quote {sym}: {e}")
        return 0.0, 0.0


def opt_quote(kite, tsym):
    key = f"NFO:{tsym}"
    try:
        q = kite.quote([key])[key]
        return {"ltp": float(q.get("last_price") or 0),
                "oi": int(q.get("oi") or 0),
                "vol": int(q.get("volume") or q.get("volume_traded") or 0)}
    except Exception as e:
        log.warning(f"opt quote {tsym}: {e}")
        return None


def build_chains(kite, min_dte=CFG.MIN_DTE):
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
        chains[name] = {"expiry": str(expiry), "lot": int(lot or 0), "strikes": dict(strikes)}
    log.info("NFO chains: %d underlyings", len(chains))
    return chains


# ----------------------------- structure construction -------------------------
def _ladder(chain):
    return sorted(chain["strikes"])


def _nearest(ladder, target):
    return min(ladder, key=lambda k: abs(k - target)) if ladder else None


def build_legs(chain, spot, direction, structure):
    """Return [(tradingsymbol, 'BUY'|'SELL', strike, opt_type), ...] or None.

    Sign convention: BUY = long that option, SELL = short it.
    """
    ladder = _ladder(chain)
    if len(ladder) < 4:
        return None
    atm = _nearest(ladder, spot)
    i = ladder.index(atm)
    step = CFG.SPREAD_WIDTH
    def at(idx):
        return ladder[idx] if 0 <= idx < len(ladder) else None
    def leg(strike, typ, side):
        if strike is None:
            return None
        tsym = chain["strikes"].get(strike, {}).get(typ)
        return (tsym, side, strike, typ) if tsym else None

    bull = direction == "BULLISH"
    if structure == "naked":
        # ITM option: for a call, ITM = strike below spot; for a put, above.
        if bull:
            strike = at(i - CFG.ITM_STEPS); legs = [leg(strike, "CE", "BUY")]
        else:
            strike = at(i + CFG.ITM_STEPS); legs = [leg(strike, "PE", "BUY")]
    elif structure == "debit":
        if bull:  # bull-call: long ATM CE, short OTM CE (higher strike)
            legs = [leg(atm, "CE", "BUY"), leg(at(i + step), "CE", "SELL")]
        else:     # bear-put: long ATM PE, short OTM PE (lower strike)
            legs = [leg(atm, "PE", "BUY"), leg(at(i - step), "PE", "SELL")]
    elif structure == "credit":
        if bull:  # bull-put: short OTM PE (below), long further-OTM PE (protection)
            legs = [leg(at(i - step), "PE", "SELL"), leg(at(i - 2*step), "PE", "BUY")]
        else:     # bear-call: short OTM CE (above), long further-OTM CE
            legs = [leg(at(i + step), "CE", "SELL"), leg(at(i + 2*step), "CE", "BUY")]
    else:
        return None
    if any(l is None for l in legs):
        return None
    return legs


def _signed_mark(legs_with_px):
    """legs_with_px: [(side, price), ...] -> net mark (long +price, short -price)."""
    return sum((px if side == "BUY" else -px) for side, px in legs_with_px)


# ----------------------------- ledger -----------------------------------------
class Ledger:
    def __init__(self, sdir):
        self.dir = sdir
        self.dir.mkdir(parents=True, exist_ok=True)
        self.pos = self._load(self.dir / "positions.json", {})
        self.state = self._load(self.dir / "ledger.json", None) or {
            "realized_pnl": 0.0, "entries_today": 0, "day": str(now_ist().date()),
            "day_realized": 0.0, "traded_today": []}

    def _load(self, p, d):
        try:
            return json.loads(Path(p).read_text())
        except Exception:
            return d

    def save(self):
        (self.dir / "positions.json").write_text(json.dumps(self.pos, indent=2))
        (self.dir / "ledger.json").write_text(json.dumps(self.state, indent=2))

    def roll_day(self):
        today = str(now_ist().date())
        if self.state.get("day") != today:
            self.state.update(day=today, entries_today=0, day_realized=0.0, traded_today=[])
            self.save()

    def open(self, key, rec):
        self.pos[key] = rec
        self.state["entries_today"] += 1
        self.state.setdefault("traded_today", []).append(rec["under"])
        self.save()

    def close(self, key, pnl):
        self.state["realized_pnl"] += pnl
        self.state["day_realized"] = self.state.get("day_realized", 0.0) + pnl
        self.pos.pop(key, None)
        self.save()


# ----------------------------- trader -----------------------------------------
class EBOptions2:
    def __init__(self, kite, structure):
        self.kite = kite
        self.structure = structure
        self.led = Ledger(STATE_BASE / structure)
        self._chains = None
        self._day = None

    def chains(self):
        today = now_ist().date()
        if self._chains is None or self._day != today:
            self._chains = build_chains(self.kite)
            self._day = today
        return self._chains

    def _signals(self):
        f = SIG_DIR / f"signals_{now_ist().date().isoformat()}.jsonl"
        if not f.exists():
            log.warning("no signals file: %s", f)
            return []
        out = []
        for line in f.read_text().splitlines():
            try:
                out.append(json.loads(line))
            except Exception:
                pass
        return out

    @staticmethod
    def _iv_rise(sig):
        m = re.search(r"IV\s*([+-]?\d+)%", sig.get("detail", ""))
        return float(m.group(1)) if m else None

    def _momentum_ok(self, sym, direction):
        ltp, prev = stock_quote(self.kite, sym)
        if not ltp or not prev:
            return False, ltp
        chg = ltp / prev - 1
        ok = chg >= CFG.MOM_MIN if direction == "BULLISH" else chg <= -CFG.MOM_MIN
        return ok, ltp

    # ---------- entry ----------
    def scan_and_enter(self):
        self.led.roll_day()
        if now_ist().time() >= CFG.ENTRY_CUTOFF_T:
            return
        if self.led.state.get("day_realized", 0.0) <= -CFG.DAILY_LOSS_LIMIT:
            notify(f"v2: kill switch (day PnL ₹{self.led.state['day_realized']:.0f}) - no entries")
            return
        if self.led.state["entries_today"] >= CFG.MAX_ENTRIES_DAY or len(self.led.pos) >= CFG.MAX_CONCURRENT:
            return
        best = {}
        for s in self._signals():
            if s.get("pattern") == "EOD_RESULT" or s.get("direction") not in ("BULLISH", "BEARISH"):
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
            if len(self.led.pos) >= CFG.MAX_CONCURRENT:
                break
            # IV filter — don't buy peak premium
            ivr = self._iv_rise(s)
            if ivr is not None and ivr > CFG.IV_MAX_RISE:
                log.info("skip %s: IV already +%.0f%% (> %.0f) - peak premium", sym, ivr, CFG.IV_MAX_RISE)
                continue
            chain = chains.get(sym)
            if not chain or not chain["lot"]:
                continue
            # momentum confirmation on the underlying
            ok, spot = self._momentum_ok(sym, s["direction"])
            if not ok:
                log.info("skip %s: no intraday %s confirmation", sym, s["direction"])
                continue
            legs = build_legs(chain, spot, s["direction"], self.structure)
            if not legs:
                continue
            self._try_open(sym, s, chain, legs)

    def _try_open(self, sym, s, chain, legs):
        lot = chain["lot"]
        priced = []  # (tsym, side, strike, typ, fill_px)
        for tsym, side, strike, typ in legs:
            q = opt_quote(self.kite, tsym)
            if not q or q["ltp"] <= 0:
                return
            if q["oi"] < CFG.MIN_LEG_OI or q["vol"] < CFG.MIN_LEG_VOL:
                log.info("skip %s: leg %s illiquid (oi=%s vol=%s)", sym, tsym, q["oi"], q["vol"])
                return
            # slippage: pay up when buying, receive less when selling
            fill = q["ltp"] * (1 + CFG.SLIP) if side == "BUY" else q["ltp"] * (1 - CFG.SLIP)
            priced.append((tsym, side, strike, typ, round(fill, 2)))

        entry_mark = _signed_mark([(side, px) for _, side, _, _, px in priced])  # per unit
        is_credit = self.structure == "credit"
        # define risk + targets
        if is_credit:
            net_credit = -entry_mark            # mark is negative (credit received)
            if net_credit <= 0:
                return
            width = abs(priced[0][2] - priced[1][2])
            max_loss_unit = max(width - net_credit, 0.01)
            risk_rs = max_loss_unit * lot
            target_pnl = CFG.CREDIT_TARGET * net_credit * lot
            stop_pnl   = -CFG.CREDIT_STOP   * net_credit * lot
            cost_note  = f"credit ₹{net_credit*lot:.0f}"
        else:
            net_debit = entry_mark              # mark positive (debit paid)
            if net_debit <= 0:
                return
            risk_rs = net_debit * lot
            target_pnl = CFG.DEBIT_TARGET * net_debit * lot
            stop_pnl   = -CFG.DEBIT_STOP   * net_debit * lot
            cost_note  = f"debit ₹{net_debit*lot:.0f}"

        if risk_rs > CFG.RISK_PER_TRADE:
            log.info("skip %s: risk ₹%.0f > cap ₹%.0f", sym, risk_rs, CFG.RISK_PER_TRADE)
            return

        key = f"{sym}_{self.structure}_{now_ist().strftime('%H%M%S')}"
        self.led.open(key, {
            "under": sym, "structure": self.structure, "direction": s["direction"],
            "lot": lot, "legs": [{"tsym": t, "side": sd, "strike": st, "typ": tp, "entry": px}
                                 for t, sd, st, tp, px in priced],
            "entry_mark": entry_mark, "target_pnl": round(target_pnl, 0),
            "stop_pnl": round(stop_pnl, 0), "entry_time": now_ist().isoformat(),
            "score": s["score"]})
        legdesc = " / ".join(f"{sd} {tp}{st:g}" for _, sd, st, tp, _ in priced)
        notify(f"EBOPT2 OPEN {sym} [{self.structure}] {legdesc}\n"
               f"{cost_note} risk ₹{risk_rs:.0f} | target ₹{target_pnl:.0f} stop ₹{stop_pnl:.0f}\n"
               f"why {s.get('pattern')} score {s['score']} [PAPER, intraday]")

    # ---------- manage ----------
    def manage(self):
        self.led.roll_day()
        squareoff = now_ist().time() >= CFG.SQUAREOFF_T
        for key in list(self.led.pos.keys()):
            p = self.led.pos[key]
            marks = []
            ok = True
            for lg in p["legs"]:
                q = opt_quote(self.kite, lg["tsym"])
                if not q or q["ltp"] <= 0:
                    ok = False; break
                exitpx = q["ltp"] * (1 - CFG.SLIP) if lg["side"] == "BUY" else q["ltp"] * (1 + CFG.SLIP)
                marks.append((lg["side"], exitpx))
            if not ok:
                continue
            cur_mark = _signed_mark(marks)
            pnl = (cur_mark - p["entry_mark"]) * p["lot"]
            reason = None
            if squareoff:
                reason = "eod"
            elif pnl >= p["target_pnl"]:
                reason = "target"
            elif pnl <= p["stop_pnl"]:
                reason = "stop"
            if reason:
                self.led.close(key, pnl)
                notify(f"EBOPT2 CLOSE {p['under']} [{p['structure']}] PnL ₹{pnl:.0f} ({reason}) [PAPER]")

    def status(self):
        s = self.led.state
        lines = [f"EBOPT2 [{self.structure}] ledger: realized ₹{s['realized_pnl']:.0f} "
                 f"open {len(self.led.pos)} entries_today {s['entries_today']} "
                 f"day ₹{s.get('day_realized',0.0):.0f}"]
        for key, p in self.led.pos.items():
            lines.append(f"  {p['under']} [{p['structure']}] {p['direction']} "
                         f"x{p['lot']} target ₹{p['target_pnl']:.0f} stop ₹{p['stop_pnl']:.0f}")
        notify("\n".join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--structure", choices=["credit", "debit", "naked"], default=CFG.STRUCTURE)
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--interval", type=int, default=CFG.POLL_SECONDS)
    args = ap.parse_args()

    from algotrade.env import load_dotenv_if_present
    from algotrade.brokers.kite_auth import auto_login
    load_dotenv_if_present()
    kite = auto_login()
    bot = EBOptions2(kite, args.structure)

    if args.status:
        bot.status(); return
    if args.once:
        bot.manage(); bot.scan_and_enter(); bot.status(); return

    notify(f"EBOPT2 online [{args.structure}] — IV-filtered, momentum-confirmed, "
           f"intraday spreads on score≥{CFG.MIN_SCORE} signals [PAPER]")
    while True:
        try:
            now = now_ist()
            if not (is_weekday() and CFG.OPEN_T <= now.time() <= dt.time(15, 30)):
                time.sleep(300); continue
            bot.manage(); bot.scan_and_enter()
        except Exception:
            log.exception("cycle failed")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
