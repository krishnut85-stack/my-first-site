#!/bin/bash
# PATCH 342 - LIVE FUTURES BY MONTH: NOV | DEC | TOTAL IN BIG MONEY (Rama, 16 Nov 10:30: "rectify the futures build-up - I am not able to
#   predict anything" · "I need NOV and DEC separate in BIG MONEY"). GIR's engine streams only the NEAR month; in rollover week NOV OI falls
#   everywhere and the build-up read wrong (BIG MONEY ▲0 ▼0). The engine is NOT touched:
#   · futlive.py (READ ONLY) + the gir-futlive service: every 15 s in the session, 1-2 Kite quote calls for every F&O future (NOV, DEC, JAN),
#     each month against NSE's official close for THAT month (patch 338's file); Kite session from core.get_kite() - no new login, nothing ordered
#   · /futx gives that live reading while fresh (NSE's close otherwise) - futmonths.py replaced (338's + live)
#   · BIG MONEY: a NOV | DEC | TOTAL table - the build-up word on the TOTAL, ↻ ROLLOVER, futures traded ₹ today, chips with counts
#   · a share's page: FUTURES BY MONTH refreshed every 20 s, marked ● LIVE
#   Tested: 9 + 3 sizes. Adds futlive.py + gir-futlive.service; replaces futmonths.py (only 338's); edits home.html. Restarts the dashboard
#   (6 s) - the engine keeps running. Prints one live reading at the end.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 342" $D/home.html && [ -f $D/futlive.py ] && systemctl is-active --quiet gir-futlive; then echo "patch 342 - already in"; cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 60 python3 futlive.py once; exit 0; fi
grep -q "patch 341" $D/home.html || { echo "patch 341 first"; exit 1; }
grep -q "patch 338" $D/futmonths.py 2>/dev/null || { echo "futmonths.py (patch 338) not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/futmonths.py $D/futmonths.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/futmonths.py.bak$TS $D/futmonths.py; systemctl disable --now gir-futlive 2>/dev/null; rm -f /etc/systemd/system/gir-futlive.service $D/futlive.py; systemctl daemon-reload; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/futlive.py <<'PY_FL'
"""futlive.py - patch 342: READ ONLY. LIVE FUTURES BY MONTH (Rama, 16 Nov 10:30: "rectify the futures build-up - I am not able to predict
anything"). GIR's engine streams only the NEAR month; in the week before expiry traders roll NOV -> DEC, so near-month OI falls everywhere
and the build-up reads wrong (AGREE UP / DOWN stayed 0). This reader does not touch the engine:
  · every 15 s in the session: ONE or TWO Kite quote calls for every F&O future, all expiries (NOV, DEC, JAN) - far below Kite's limits
  · each month's open interest against NSE's OFFICIAL close of the last session for THAT month (data/nsefutx_<day>.json, patch 338)
  · per share: NOV / DEC / JAN ₹ crore and OI %, the TOTAL, the build-up word on the TOTAL (price = the near future vs its last close),
    ↻ ROLLOVER, the futures traded value today (volume x price, all months)
  · writes data/futlive.json (atomic). Kite session from core.get_kite() (today's login - no new login, nothing ordered, nothing sent)
python3 futlive.py once      one reading now, printed
python3 futlive.py           the loop (the gir-futlive service)"""
import os, sys, json, time, glob, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
OUT = os.path.join(BASE, "data", "futlive.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
EVERY = 15
_I = {"day": None, "map": {}}


def now_ist():
    return dt.datetime.now(IST)


def session(n):
    if n.weekday() > 4:
        return False
    try:
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return "09:15" <= n.strftime("%H:%M") <= "15:31"


def log(*a):
    print(now_ist().strftime("%H:%M:%S"), *a, flush=True)


def instruments(kite, today):
    """{underlying: [(expiry 'YYYY-MM-DD', 'NFO:TRADINGSYMBOL'), ...] nearest 3} - once a day"""
    if _I["day"] == today and _I["map"]:
        return _I["map"]
    try:
        import getdata
        rows = getdata.call(kite.instruments, "NFO")
    except Exception:
        rows = kite.instruments("NFO")
    m = {}
    for i in rows or []:
        if i.get("instrument_type") != "FUT":
            continue
        e = i.get("expiry")
        e = e.date() if isinstance(e, dt.datetime) else dt.date.fromisoformat(str(e)[:10]) if e else None
        if not e or str(e) < today:
            continue
        m.setdefault(i.get("name"), []).append((str(e), "NFO:" + i["tradingsymbol"]))
    m = {k: sorted(v)[:3] for k, v in m.items() if k}
    _I.update({"day": today, "map": m})
    return m


def base(today):
    """NSE's official close per (underlying, expiry) of the last session before today -> ({(s, exp): (oi, close)}, day)"""
    fs = sorted(f for f in glob.glob(os.path.join(BASE, "data", "nsefutx_*.json")) if os.path.basename(f)[8:18] < today)
    for f in reversed(fs):
        try:
            N = json.load(open(f))
        except Exception:
            continue
        if not N:
            continue
        out = {}
        for s, R in N.items():
            for e, px, oi, ch in R:
                out[(s, str(e)[:10])] = (oi or 0, px)
        return out, os.path.basename(f)[8:18]
    return {}, None


def word(p, o):
    if p is None or o is None or abs(o) < 0.05:
        return ""
    if p > 0:
        return "LONG BUILD-UP" if o > 0 else "SHORT COVERING"
    if p < 0:
        return "SHORT BUILD-UP" if o > 0 else "LONG UNWINDING"
    return ""


def compute(M, Q, B):
    """M = instruments map, Q = kite quote answer, B = NSE base -> rows"""
    rows = {}
    known_s = {k[0] for k in B}
    for s, L in M.items():
        ms, tv = [], 0.0
        for e, key in L:
            q = Q.get(key) or {}
            oi = float(q.get("oi") or 0)
            px = float(q.get("last_price") or 0)
            if not px and not oi:
                continue
            b = B.get((s, e))
            b_oi = float(b[0]) if b else (0.0 if s in known_s else None)   # a month NSE's file has not got (listed since): all its OI is new
            ch = (oi - b_oi) if b_oi is not None else None
            tv += float(q.get("volume") or 0) * px
            ms.append({"m": dt.date.fromisoformat(e).strftime("%b").upper(), "exp": e, "oi": oi, "chg": ch, "px": px,
                       "cr": round(ch * px / 1e7, 1) if ch is not None else None,
                       "pc": round(ch / b_oi * 100, 1) if (ch is not None and b_oi) else None, "new": b is None,
                       "prev": float(((q.get("ohlc") or {}).get("close")) or 0) or None})
        if not ms:
            continue
        known = [x for x in ms if x["chg"] is not None]
        toi = sum(x["oi"] for x in ms)
        bsum = sum((x["oi"] - x["chg"]) for x in known)
        tch = sum(x["chg"] for x in known)
        t = {"oi": toi, "chg": tch, "cr": round(sum(x["cr"] for x in known), 1), "pc": round(tch / bsum * 100, 1) if bsum else None}
        n0 = ms[0]
        pp = round((n0["px"] / n0["prev"] - 1) * 100, 2) if n0.get("prev") and n0["px"] else None
        rest = sum(x["chg"] for x in ms[1:] if x["chg"] is not None)
        roll = bool(n0["chg"] is not None and n0["chg"] < 0 and rest > 0 and abs(n0["chg"] + rest) < 0.35 * abs(n0["chg"]))
        rows[s] = {"months": ms, "total": t, "price_pc": pp, "px": n0["px"], "bu": word(pp, t["pc"]), "near_bu": word(pp, n0["pc"]),
                   "rollover": roll, "roll_pc": round(sum(x["oi"] for x in ms[1:]) / toi * 100, 1) if toi else None, "traded_cr": round(tv / 1e7, 1)}
    return rows


def once(kite, n=None):
    n = n or now_ist(); today = str(n.date())
    M = instruments(kite, today)
    B, bday = base(today)
    keys = [k for L in M.values() for _, k in L]
    Q = {}
    for i in range(0, len(keys), 450):
        part = kite.quote(keys[i:i + 450]) or {}
        Q.update(part)
        if i + 450 < len(keys):
            time.sleep(1.1)
    rows = compute(M, Q, B)
    out = {"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": today, "base_day": bday, "n": len(rows), "src": "live", "rows": rows}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, open(OUT + ".tmp", "w"), separators=(",", ":")); os.replace(OUT + ".tmp", OUT)
    return out


def get_kite():
    import core
    k = core.get_kite()
    try:
        k.timeout = 7
    except Exception:
        pass
    return k


def main():
    if sys.argv[1:2] == ["once"]:
        v = once(get_kite())
        R = v["rows"]
        nroll = sum(1 for r in R.values() if r["rollover"]); flip = sum(1 for r in R.values() if r["bu"] and r["near_bu"] and r["bu"] != r["near_bu"])
        print("LIVE FUTURES BY MONTH %s · %d shares · base NSE close %s · %d rolling over · %d where the near month alone gives the WRONG word" % (v["at"], v["n"], v["base_day"], nroll, flip))
        for s in sorted(R, key=lambda s: -abs(R[s]["total"]["cr"] or 0))[:8]:
            r = R[s]
            print("  %-11s %s · TOTAL ₹%+.1f cr → %s%s" % (s, " · ".join("%s ₹%s" % (x["m"], ("%+.1f" % x["cr"]) if x["cr"] is not None else "new") for x in r["months"]),
                  r["total"]["cr"] or 0, r["bu"] or "—", "  ↻ ROLLOVER" if r["rollover"] else ""))
        return
    k, said = None, set()
    while True:
        n = now_ist()
        if not session(n):
            time.sleep(60); continue
        try:
            if k is None:
                k = get_kite()
            t0 = time.time(); v = once(k, n)
            if "ok" not in said:
                said.add("ok"); log("live futures by month: %d shares, base %s" % (v["n"], v["base_day"]))
            time.sleep(max(3, EVERY - (time.time() - t0)))
        except Exception as ex:
            m = str(ex)[:120]
            if m not in said:
                said.add(m); log("futlive: %s" % m)
            k = None
            time.sleep(30)


if __name__ == "__main__":
    main()
PY_FL
cat > $W/futmonths.py <<'PY_FM'
"""futmonths.py - patch 338 + 342 (LIVE in the session from futlive.py, NSE's close otherwise): READ ONLY. FUTURES MONTH BY MONTH + THE TOTAL (Rama, 16 Nov: "show the futures value for NOV, for DEC separately,
and add them up - the total. Bullish / bearish works on the total too").
  why     GIR's futures ₹ crore and build-up word came from the NEAR month only. In the week before expiry traders ROLL: November OI falls,
          December OI rises by about the same - near month alone reads "money leaving / unwinding" when it only moved.
  source  NSE's own end-of-day F&O file - every expiry (the NSE audit writes data/nsefutx_<day>.json from patch 338 on); the day's price
          move from NSE's close files (data/bhav/<day>.json, the underlying's close)
  gives   per share: each month's OI, its change, ₹ crore (change x that contract's close), OI %; the TOTAL; the build-up word on the total
          (price up + OI up = LONG BUILD-UP ...); rollover % (OI in the later months); ROLLOVER when the near month's fall is matched by
          the later months' rise (the total moved less than 35% of the near month's change)
python3 futmonths.py [SYM ...]      what GIR will show"""
import os, re, sys, json, glob, time, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"k": None, "v": None}


def _cr(chg, px):
    return round((chg or 0) * (px or 0) / 1e7, 1)


def _pc(oi, chg):
    try:
        return round(chg / (oi - chg) * 100, 1) if oi and oi - chg > 0 else None
    except Exception:
        return None


def word(price_pc, oi_pc):
    if price_pc is None or oi_pc is None or abs(oi_pc) < 0.05:
        return ""
    if price_pc > 0:
        return "LONG BUILD-UP" if oi_pc > 0 else "SHORT COVERING"
    if price_pc < 0:
        return "SHORT BUILD-UP" if oi_pc > 0 else "LONG UNWINDING"
    return ""


def one(rows, price_pc=None):
    """rows = [[exp, close, oi, chg], ...] (sorted by expiry) -> the month-by-month view"""
    rows = sorted([r for r in rows if r and r[0]], key=lambda r: str(r[0]))[:3]
    if not rows:
        return None
    ms = []
    for e, px, oi, ch in rows:
        try:
            m = dt.date.fromisoformat(str(e)[:10]).strftime("%b").upper()
        except Exception:
            m = str(e)[:7]
        ms.append({"m": m, "exp": str(e)[:10], "oi": oi or 0, "chg": ch or 0, "cr": _cr(ch, px), "pc": _pc(oi, ch or 0), "px": px})
    toi, tch = sum(x["oi"] for x in ms), sum(x["chg"] for x in ms)
    t = {"oi": toi, "chg": tch, "cr": round(sum(x["cr"] for x in ms), 1), "pc": _pc(toi, tch)}
    n0, rest = ms[0]["chg"], sum(x["chg"] for x in ms[1:])
    roll = bool(n0 < 0 and rest > 0 and abs(n0 + rest) < 0.35 * abs(n0))
    return {"months": ms, "total": t, "roll_pc": round(sum(x["oi"] for x in ms[1:]) / toi * 100, 1) if toi else None, "rollover": roll,
            "price_pc": price_pc, "bu": word(price_pc, t["pc"]), "near_bu": word(price_pc, ms[0]["pc"])}


def _spot(day):
    try:
        return {s: (v or {}).get("spot") for s, v in (json.load(open(os.path.join(BASE, "data", "bhav", "%s.json" % day))).get("s") or {}).items()}
    except Exception:
        return {}


def live(max_age=90):
    """patch 342: the live reading (futlive.py, every 15 s in the session) when it is fresh, else None"""
    try:
        v = json.load(open(os.path.join(BASE, "data", "futlive.json")))
        if time.time() - float(v.get("t") or 0) <= max_age and v.get("rows"):
            v["ok"] = True
            return v
    except Exception:
        pass
    return None


def view(now=None):
    if now is None:
        lv = live()
        if lv:
            return lv
    now = now or dt.datetime.now(IST)
    fs = sorted(f for f in glob.glob(os.path.join(BASE, "data", "nsefutx_*.json")) if os.path.basename(f)[8:18] <= str(now.date()))
    if not fs:
        return {"ok": False, "err": "no month-by-month futures file yet - the NSE audit writes it each evening (18:40)", "rows": {}}
    f = fs[-1]; day = os.path.basename(f)[8:18]
    key = (f, os.path.getmtime(f))
    if _C["k"] == key:
        return _C["v"]
    try:
        N = json.load(open(f))
    except Exception as ex:
        return {"ok": False, "err": "the futures file could not be read: %s" % str(ex)[:80], "rows": {}}
    bd = sorted(os.path.basename(x)[:10] for x in glob.glob(os.path.join(BASE, "data", "bhav", "20??-??-??.json")))
    prev = [d for d in bd if d < day]
    s1, s0 = _spot(day), (_spot(prev[-1]) if prev else {})
    rows = {}
    for s, R in N.items():
        a, b = s1.get(s), s0.get(s)
        pp = round((a / b - 1) * 100, 2) if a and b else None
        v = one(R, pp)
        if v:
            rows[s] = v
    out = {"ok": True, "day": day, "prev": prev[-1] if prev else None, "rows": rows, "n": len(rows), "src": "close"}
    _C.update({"k": key, "v": out})
    return out


if __name__ == "__main__":
    v = view()
    if not v.get("ok"):
        print("FUTURES BY MONTH: %s" % v.get("err")); sys.exit(0)
    want = [x.upper() for x in sys.argv[1:]] or sorted(v["rows"], key=lambda s: -abs(v["rows"][s]["total"]["cr"]))[:8]
    nroll = sum(1 for r in v["rows"].values() if r["rollover"]); flip = sum(1 for r in v["rows"].values() if r["bu"] and r["near_bu"] and r["bu"] != r["near_bu"])
    print("FUTURES BY MONTH (NSE close %s): %d shares · %d rolling over · %d where the near month alone gave the WRONG build-up word" % (v["day"], v["n"], nroll, flip))
    for s in want:
        r = v["rows"].get(s)
        if not r:
            print("  %s: not in NSE's file" % s); continue
        m = " · ".join("%s ₹%+.1f cr (%s)" % (x["m"], x["cr"], ("%+.1f%%" % x["pc"]) if x["pc"] is not None else "new") for x in r["months"])
        print("  %-11s %s · TOTAL ₹%+.1f cr (%s) → %s%s%s" % (s, m, r["total"]["cr"], ("%+.1f%%" % r["total"]["pc"]) if r["total"]["pc"] is not None else "—",
              r["bu"] or "—", "  ↻ ROLLOVER" if r["rollover"] else "", ("  (near month alone said %s)" % r["near_bu"]) if r["near_bu"] and r["near_bu"] != r["bu"] else ""))
PY_FM
cat > $W/p342test.py <<'PY_T'
#!/usr/bin/env python3
"""p342test.py - LIVE FUTURES BY MONTH: a fake Kite (made-up quotes), a made-up NSE close file, temp folder - nothing real is called"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(WK, "futlive.py"), T); shutil.copy(os.path.join(WK, "futmonths.py"), T); sys.path.insert(0, T)
import futlive as L, futmonths as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
json.dump({"ZZROLL": [["2026-11-23", 100.0, 4000000, 0], ["2026-12-28", 101.0, 3000000, 0]],
           "ZZSHORT": [["2026-11-23", 200.0, 5000000, 0], ["2026-12-28", 202.0, 1000000, 0]],
           "ZZNEW": [["2026-11-23", 50.0, 1000000, 0]]}, open(os.path.join(T, "data", "nsefutx_2026-11-13.json"), "w"))
json.dump({}, open(os.path.join(T, "data", "nsefutx_2026-11-15.json"), "w"))          # an empty file (as this morning) is skipped
class K:
    calls = 0
    def instruments(self, ex):
        R = []
        for n, e, ts in (("ZZROLL", "2026-11-23", "ZZROLL26NOVFUT"), ("ZZROLL", "2026-12-28", "ZZROLL26DECFUT"), ("ZZSHORT", "2026-11-23", "ZZS26NOVFUT"),
                         ("ZZSHORT", "2026-12-28", "ZZS26DECFUT"), ("ZZNEW", "2026-11-23", "ZZN26NOVFUT"), ("ZZNEW", "2027-01-25", "ZZN27JANFUT"), ("OLD", "2026-10-27", "OLD26OCTFUT")):
            R.append({"instrument_type": "FUT", "name": n, "expiry": dt.date.fromisoformat(e), "tradingsymbol": ts})
        R.append({"instrument_type": "CE", "name": "ZZROLL", "expiry": dt.date(2026, 11, 23), "tradingsymbol": "X"})
        return R
    def quote(self, keys):
        K.calls += 1
        Q = {"NFO:ZZROLL26NOVFUT": {"oi": 3000000, "last_price": 101.0, "volume": 2000000, "ohlc": {"close": 100.0}},       # NOV -10 L, DEC +10 L: a roll
             "NFO:ZZROLL26DECFUT": {"oi": 4000000, "last_price": 102.0, "volume": 1000000, "ohlc": {"close": 101.0}},
             "NFO:ZZS26NOVFUT": {"oi": 5500000, "last_price": 190.0, "volume": 3000000, "ohlc": {"close": 200.0}},          # price -5%, OI up both months
             "NFO:ZZS26DECFUT": {"oi": 1300000, "last_price": 192.0, "volume": 500000, "ohlc": {"close": 202.0}},
             "NFO:ZZN26NOVFUT": {"oi": 1100000, "last_price": 51.0, "volume": 10000, "ohlc": {"close": 50.0}},
             "NFO:ZZN27JANFUT": {"oi": 20000, "last_price": 52.0, "volume": 100, "ohlc": {"close": 0}}}
        return {k: Q[k] for k in keys if k in Q}
L.OUT = os.path.join(T, "data", "futlive.json"); L.BASE = T; M.BASE = T
v = L.once(K(), dt.datetime(2026, 11, 16, 10, 40, tzinfo=IST)); R = v["rows"]
chk("3 shares read in ONE quote call, base = NSE close 2026-11-13 (the empty file skipped), old expiries left out", v["n"] == 3 and K.calls == 1 and v["base_day"] == "2026-11-13" and "OLD" not in R, (v["n"], K.calls, v["base_day"]))
r = R["ZZROLL"]
chk("ZZROLL: NOV ₹-10.1 cr (-25%%), DEC ₹+10.2 cr (+33.3%%), TOTAL ₹+0.1 cr - ↻ ROLLOVER", [m["cr"] for m in r["months"]] == [-10.1, 10.2] and r["total"]["cr"] == 0.1 and r["rollover"], r)
chk("ZZROLL: price +1%% (near future vs its last close); near month alone says SHORT COVERING, the total does not", r["price_pc"] == 1.0 and r["near_bu"] == "SHORT COVERING" and r["bu"] == "", r)
s = R["ZZSHORT"]
chk("ZZSHORT: price -5%%, NOV +5 L, DEC +3 L -> TOTAL OI +13.3%% -> SHORT BUILD-UP, not a roll", s["bu"] == "SHORT BUILD-UP" and s["total"]["pc"] == round(800000 / 6000000 * 100, 1) and not s["rollover"], s)
chk("ZZSHORT: futures traded today ₹%s cr (volume x price, both months)" % s["traded_cr"], s["traded_cr"] == round((3000000 * 190 + 500000 * 192) / 1e7, 1), s)
n = R["ZZNEW"]
chk("ZZNEW: JAN was not listed at NSE's close -> all its OI is new (₹+0.1 cr), marked new; TOTAL ₹+0.6 cr, OI +12%%", n["months"][1]["new"] and n["months"][1]["chg"] == 20000 and n["total"]["cr"] == 0.6 and n["total"]["pc"] == 12.0, n)
fv = M.view()
chk("the page's feed (/futx) gives the LIVE reading while it is fresh", fv.get("src") == "live" and fv["n"] == 3, fv.get("src"))
j = json.load(open(L.OUT)); j["t"] -= 300; json.dump(j, open(L.OUT, "w")); M._C["k"] = None
chk("a reading older than 90 s is not shown as live (falls back to NSE's close)", M.view().get("src") == "close", M.view().get("src"))
chk("in the session 09:15-15:31 on a weekday only", L.session(dt.datetime(2026, 11, 16, 9, 20, tzinfo=IST)) and not L.session(dt.datetime(2026, 11, 16, 15, 40, tzinfo=IST)) and not L.session(dt.datetime(2026, 11, 21, 10, 0, tzinfo=IST)))
print("THE PATCH 342 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 342: LIVE futures by month - a NOV | DEC | TOTAL table in BIG MONEY, the share page's line live */
#gxfl{margin:8px 10px 10px;border:1px solid #273244;border-radius:8px;background:#0b1017;color:#e6edf3;font:12.5px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxfl .h{display:flex;flex-wrap:wrap;align-items:center;gap:6px 12px;padding:9px 12px;border-bottom:1px solid #1c2532}
#gxfl .h b.t{font:800 12.5px ui-monospace,Menlo,monospace;letter-spacing:.08em;color:#f5a623}
#gxfl .tag{font:600 11.5px ui-monospace,Menlo,monospace;padding:2px 8px;border-radius:4px;border:1px solid #273244;color:#c9d1dc;white-space:nowrap}
#gxfl .tag.live{color:#4fd69c;border-color:#1d5c42}#gxfl .tag.old{color:#ffd58a;border-color:#6b5418}
#gxfl .ch{display:flex;flex-wrap:wrap;gap:6px;padding:8px 12px;border-bottom:1px solid #1c2532}
#gxfl .ch a{font:700 11.5px ui-monospace,Menlo,monospace;letter-spacing:.03em;padding:5px 10px;border:1px solid #2a3546;border-radius:5px;color:#c9d1dc;cursor:pointer;white-space:nowrap}
#gxfl .ch a.on{background:#f5a623;border-color:#f5a623;color:#1a1205}
#gxfl .ch a.LB:not(.on){color:#4fd69c}#gxfl .ch a.SB:not(.on){color:#f58a86}#gxfl .ch a.SC:not(.on){color:#7fd3f0}#gxfl .ch a.LU:not(.on){color:#ffc35c}#gxfl .ch a.RO:not(.on){color:#ffd58a}
#gxfl .sc{max-height:360px;overflow:auto;-webkit-overflow-scrolling:touch}
#gxfl table{width:100%;border-collapse:collapse;font:12.5px ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums}
#gxfl th{position:sticky;top:0;z-index:1;background:#0e141d;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.05em;color:#8b97a9;text-align:right;padding:7px 8px;border-bottom:1px solid #1c2532;white-space:nowrap}
#gxfl th:first-child,#gxfl td:first-child{text-align:left}
#gxfl td{padding:6px 8px;text-align:right;border-bottom:1px solid #121923;white-space:nowrap}
#gxfl tr.r{cursor:pointer}#gxfl tr.r:hover td{background:#0f1520}
#gxfl td .s{font-weight:700;color:#e6edf3}#gxfl td small{font-size:11px;color:#a3aebf;margin-left:4px}
#gxfl .up{color:#26c281}#gxfl .dn{color:#f0544f}#gxfl .mu{color:#a3aebf}
#gxfl .w{font:800 11px ui-monospace,Menlo,monospace;padding:2px 7px;border-radius:3px;white-space:nowrap}
#gxfl .w.LB{background:#0d3324;color:#4fd69c}#gxfl .w.SB{background:#3a1416;color:#f58a86}#gxfl .w.SC{background:#0d2a33;color:#7fd3f0}#gxfl .w.LU{background:#3a2c10;color:#ffc35c}
#gxfl .ro{font:700 11px ui-monospace,Menlo,monospace;color:#ffd58a;margin-left:6px}
#gxfl .more{padding:8px 12px;text-align:center;color:#f5a623;font:700 12px ui-monospace,Menlo,monospace;cursor:pointer}
#gxfl .leg{padding:7px 12px;font-size:11.5px;color:#a3aebf;border-top:1px solid #1c2532}
@media(max-width:899px){ #gxfl{margin:8px 0}#gxfl td,#gxfl th{padding:6px 5px}#gxfl td.tv,#gxfl th.tv{display:none} }
</style>
<script>/* patch 342: LIVE FUTURES BY MONTH. /futx gives futlive.py's reading (every 15 s, every month against NSE's close of that month) while it is
   fresh, NSE's close otherwise. BIG MONEY: a NOV | DEC | TOTAL table (the build-up word on the TOTAL, ↻ ROLLOVER, futures traded ₹ today);
   a share's page: its FUTURES BY MONTH line refreshed every 20 s, marked LIVE. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], WD=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dw=s=>{ const m=String(s||"").match(/(\d{4})-(\d{2})-(\d{2})/); return m?WD[new Date(Date.UTC(+m[1],+m[2]-1,+m[3])).getUTCDay()]+" "+(+m[3])+" "+MON[+m[2]-1]:""; };
  const CR=v=>v==null?"new":(v>0?"+":v<0?"−":"")+"₹"+Math.abs(v).toLocaleString("en-IN",{maximumFractionDigits:Math.abs(v)>=100?0:1})+" cr";
  const PC=v=>v==null?"new":(v>0?"+":v<0?"−":"")+Math.abs(v).toFixed(1)+"%";
  const C=v=>v>0?"up":v<0?"dn":"mu";
  const AB={"LONG BUILD-UP":"LB","SHORT BUILD-UP":"SB","SHORT COVERING":"SC","LONG UNWINDING":"LU"};
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let V=null, busy=false, F="ALL", ALL=false, T=0;
  async function pull(){ if(busy) return; busy=true; T=Date.now();
    try{ const r=await fetch("futx?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ V=await r.json(); draw(); } }catch(e){} busy=false; }
  const isLive=()=>V&&V.src==="live";
  function stamp(){ return isLive()?`<span class="tag live">● LIVE ${E(V.at||"")} · vs NSE close ${E(dw(V.base_day))}</span>`:(V&&V.day?`<span class="tag old">NSE close ${E(dw(V.day))} - not live (live in the session)</span>`:""); }
  /* ---- BIG MONEY table ---- */
  window.gxFlSet=function(f){ F=f; ALL=false; draw(); }; window.gxFlAll=function(){ ALL=true; draw(); };
  window.gxFlGo=function(s){ try{ if(typeof mkOpen==="function") mkOpen(s); }catch(e){} };
  function table(){ const R=Object.entries((V&&V.rows)||{}).map(([s,r])=>Object.assign({s},r));
    const cnt=k=>k==="ALL"?R.length:k==="RO"?R.filter(r=>r.rollover).length:R.filter(r=>AB[r.bu]===k).length;
    const L=R.filter(r=>F==="ALL"||(F==="RO"?r.rollover:AB[r.bu]===F)).sort((a,b)=>Math.abs(b.total.cr||0)-Math.abs(a.total.cr||0));
    const n=ALL?L.length:Math.min(L.length,30);
    const chips=[["ALL","ALL"],["LB","▲ LONG BUILD-UP"],["SB","▼ SHORT BUILD-UP"],["SC","SHORT COVERING"],["LU","LONG UNWINDING"],["RO","↻ ROLLOVER"]].map(([k,l])=>`<a class="${k} ${F===k?"on":""}" onclick="gxFlSet('${k}')">${l} ${cnt(k)}</a>`).join("");
    const mcol=(r,i)=>{ const m=r.months[i]; return m?`<span class="${C(m.cr)}">${CR(m.cr)}</span><small>${E(m.m)} ${PC(m.pc)}</small>`:'<span class="mu">—</span>'; };
    const rows=L.slice(0,n).map(r=>`<tr class="r" onclick="gxFlGo('${E(r.s).replace(/'/g,"")}')"><td><span class="s">${E(r.s)}</span>${r.rollover?'<span class="ro">↻</span>':""}</td>
      <td class="${C(r.price_pc)}">${r.price_pc!=null?(r.price_pc>0?"+":"")+r.price_pc.toFixed(2)+"%":"—"}</td><td>${mcol(r,0)}</td><td>${mcol(r,1)}</td>
      <td><b class="${C(r.total.cr)}">${CR(r.total.cr)}</b><small>${PC(r.total.pc)}</small></td><td>${r.bu?`<span class="w ${AB[r.bu]}">${E(r.bu)}</span>`:'<span class="mu">—</span>'}</td>
      <td class="tv mu">${r.traded_cr!=null?"₹"+Math.round(r.traded_cr).toLocaleString("en-IN")+" cr":"—"}</td></tr>`).join("");
    return `<div class="h"><b class="t">FUTURES BY MONTH · NOV | DEC | TOTAL</b>${stamp()}<span class="mu" style="font-size:11.5px">the build-up word is on the TOTAL (all months) - in rollover week the near month alone misleads</span></div>
      <div class="ch">${chips}</div><div class="sc"><table><thead><tr><th>SHARE</th><th>PRICE</th><th>NEAR MONTH ₹ (OI %)</th><th>NEXT MONTH ₹ (OI %)</th><th>TOTAL ₹ (OI %)</th><th>BUILD-UP (TOTAL)</th><th class="tv">FUT TRADED TODAY</th></tr></thead>
      <tbody>${rows||'<tr><td colspan="7" class="mu" style="text-align:center;padding:14px">none right now</td></tr>'}</tbody></table>${L.length>n?`<div class="more" onclick="gxFlAll()">show all ${L.length} ▾</div>`:""}</div>
      <div class="leg">₹ cr = the change in futures open interest x the price since NSE's close · ↻ = rollover (the near month's fall matched by the next month's rise - positions moved, not closed) · tap a share to open it</div>`; }
  function drawTable(){ const q=document.getElementById("q-lnk"); if(!q||!V||!V.ok) return;
    let el=document.getElementById("gxfl"); const anchor=document.getElementById("btbar")||q.querySelector("h3");
    if(!el){ el=document.createElement("div"); el.id="gxfl"; (anchor&&anchor.parentElement===q?anchor:q.firstElementChild||q).after(el); }
    const sc=el.querySelector(".sc"), keep=sc?sc.scrollTop:0; el.innerHTML=table(); const sc2=el.querySelector(".sc"); if(sc2) sc2.scrollTop=keep; }
  /* ---- the share page's line, live ---- */
  function drawLine(){ if(!isLive()) return; const s=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase(); const el=document.getElementById("gxfx"), r=V.rows&&V.rows[s]; if(!el||!r) return;
    const ms=r.months.map(x=>`<span class="m">${E(x.m)} <b class="${C(x.cr)}">${CR(x.cr)}</b> <span class="mu">(${PC(x.pc)})</span></span>`).join(""), t=r.total, w=r.bu, a=AB[w]||"";
    el.innerHTML=`<span class="h">FUTURES BY MONTH</span>${ms}<span class="t">TOTAL <b class="${C(t.cr)}">${CR(t.cr)}</b> <span class="mu">(${PC(t.pc)})</span></span>
      ${r.rollover?`<span class="r">↻ ROLLOVER - ${E(r.months[0].m)} positions moved to ${E((r.months[1]||{}).m||"next month")}, not closed</span>${w?`<span class="d">net: ${E(w.toLowerCase())} ${PC(t.pc)} (small)</span>`:""}`:(w?`<span class="w ${a}">→ ${E(w)}</span>`:"")}
      <span class="d" style="color:#4fd69c">● LIVE ${E(V.at||"")}</span><span class="d">vs NSE close ${E(dw(V.base_day))}${r.price_pc!=null?" · price "+(r.price_pc>0?"+":"")+r.price_pc+"%":""}${r.traded_cr!=null?" · futures traded ₹"+Math.round(r.traded_cr).toLocaleString("en-IN")+" cr":""}</span>`;
    el.dataset.k=s+"|"+V.day; }
  function draw(){ try{ drawTable(); drawLine(); }catch(e){} }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; if(V&&!document.getElementById("gxfl")&&document.getElementById("q-lnk")) drawTable(); if(isLive()){ const el=document.getElementById("gxfx"); if(el&&!/LIVE/.test(el.textContent)) drawLine(); } },200); }).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  setInterval(()=>{ if(!document.hidden&&(isLive()||Date.now()-T>300000)) pull(); },20000); pull(); })();
</script>
ADD_H
echo "=== test (a fake Kite, made-up NSE file, nothing real called)"
python3 $W/p342test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
python3 -m py_compile $W/futlive.py $W/futmonths.py || { echo "❌ did not compile - nothing changed"; exit 1; }
cp $W/futlive.py $D/futlive.py && cp $W/futmonths.py $D/futmonths.py || back
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if "patch 342" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: NOV | DEC | TOTAL in BIG MONEY, the share line live")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cat > /etc/systemd/system/gir-futlive.service <<'UNIT'
[Unit]
Description=GIR live futures by month (NOV DEC JAN vs NSE close) - read only, patch 342
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd /home/globalbot/intraday && exec python3 -u futlive.py >> data/futlive.log 2>&1'
Restart=always
RestartSec=20
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-futlive >/dev/null 2>&1 || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-futlive: $(systemctl is-active gir-futlive)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-futlive)" = "active" ] || back
echo "=== one LIVE reading now (Kite, every F&O future, vs NSE's close)"
( cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 90 python3 futlive.py once ) 2>&1 | tail -10
echo "✅ patch 342 done - refresh GIR: BIG MONEY shows NOV | DEC | TOTAL live; a share's FUTURES BY MONTH says ● LIVE."
echo "   undo: systemctl disable --now gir-futlive; rm /etc/systemd/system/gir-futlive.service; cp $D/home.html.bak$TS $D/home.html; cp $D/futmonths.py.bak$TS $D/futmonths.py; systemctl restart gir-dash"
