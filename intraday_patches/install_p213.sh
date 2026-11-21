#!/bin/bash
# PATCH 213 - Rama, 12 Nov:
#   1 PROFIT BOOKING AT THE MOMENT IT STARTS ("not after - then it is of no use"): every 15 s, every F&O share that ran 2.5%+ (1.5%+ when GIR
#     told you to act on it). The price turns down from a FRESH high (within 10 min) and the money proves it (futures OI falling = longs
#     booking, or a volume burst, or call writers building a roof) -> 🚨 PROFIT BOOKING ▼ SYM at 8% of the move given back (12% with only a
#     roof): was / now / who is selling / book part of the CE, the stop that keeps half the move. The mirror: 🚨 SHORT COVERING ▲ (a PE).
#     🚨 CRITICAL when GIR told you to act on the share or it moved 4%+. COROMANDEL 11 Nov replayed: it rings at +8.2%, 4 min after the +9% top.
#   2 🌐 FOREIGN: a story about an Indian share's foreign parent (ABB group -> BMW robots, Siemens AG, Nestle SA, Bosch ...) is said quietly as
#     "🌐 FOREIGN - little meaning for NSE", not alerted and not dropped (no AI read spent). Infosys / Tata Motors abroad stay their news.
#   Restarts the news reader and the news hunt (seconds) - safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "def about_it" $D/newsalert.py && [ -f $D/newshunt.py ] || { echo "patches 209 and 211 first"; exit 1; }
for f in newsalert.py newshunt.py; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in newsalert.py newshunt.py; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/pbook.py; systemctl restart gir-newsroom gir-newshunt 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pbook.py <<'PY_PB'
#!/usr/bin/env python3
"""pbook.py - patch 213: PROFIT BOOKING - AT THE MOMENT IT STARTS (Rama, 12 Nov: "give me a profit booking alert - the moment the profit
booking started, not after; then it is of no use" · COROMANDEL 11 Nov: +9% on the subsidy news, the early money sold into it, +5.5% at the close).
Runs inside the news hunt (every 15 s, the live prices). For every F&O share that ran 2.5%+ today (1.5%+ when GIR told you to act on it):
  THE START   the price turns down from a FRESH high (made within the last 10 min): 8% of the day's move given back (at least 0.5%) when the
              money proves it (futures OI falling / a volume burst), 12% with only a roof forming - the first leg of a give-back, not its end
  THE PROOF   at least one of: the futures OI falling since the high (longs booking) · this 5 minutes' volume 1.5x+ the day's normal
              (real selling, not a pause) · call writers building a roof just above (the desk) · or the give-back already 20%+ of the move
  -> 🚨 PROFIT BOOKING ▼ SYM (🚨 CRITICAL when GIR told you to act on it, or the move was 4%+): was / now / how much given back in how many
     minutes · who is selling · what to do with a CE (book part, the stop that keeps half the move)
  the mirror for a fall: 🚨 SHORT COVERING ▲ SYM - the fall being bought back (book part of a PE)
  once a share a side; again only after a NEW high (low) 0.3% beyond the one it was said at, and 30 min apart"""
import os, re, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
RUN, RUN_ACT, EARLY, START, START_MIN, STRONG, FRESH_S, GAP_S = 2.5, 1.5, 0.08, 0.12, 0.5, 0.20, 600, 1800
ST = {"day": None, "s": {}}
_F = {}


def _json(name, ttl):
    t, v = _F.get(name, (0.0, None))
    if v is not None and time.time() - t < ttl:
        return v
    try:
        v = json.load(open(os.path.join(BASE, name)))
    except Exception:
        v = {}
    _F[name] = (time.time(), v)
    return v


def fut_oi(sym):
    """the futures OI % change today (the engine's live reading), None when not known"""
    f = next((x for x in _json("dash_state.json", 10).get("fo_paths") or [] if x.get("s") == sym), None)
    return f.get("oi") if f else None


def vol_x(sym):
    """this 5-min candle's volume vs the day's earlier candles (1.0 = normal), and the day's VWAP"""
    c = (_json("charts.json", 20) or {}).get(sym) or {}
    v = [x for x in (c.get("v") or []) if x]
    vw = c.get("vw")
    if len(v) < 4:
        return None, vw if isinstance(vw, (int, float)) else None
    base = sorted(v[:-1])[len(v[:-1]) // 2] or 1
    return v[-1] / base, (vw if isinstance(vw, (int, float)) else None)


def roof_forming(sym, side):
    wl = ((((_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(sym) or {}).get("lines") or {}).get("walls") or "")
    m = re.search(r"%s forming at ([\d.]+)" % ("roof" if side > 0 else "floor"), wl)
    return m.group(1) if m else None


def acted(day):
    """the shares GIR told you to act on today (GO, ENTER NOW, BOX PICK, TRIAL ENTRY, 🟠 OI)"""
    t, v = _F.get("_acted", (0.0, None))
    if v is not None and time.time() - t < 60:
        return v
    v = set()
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=3)
        for s, tx in c.execute("select sym, text from alerts where day=?", (day,)):
            if s and re.search(r"🟢 GO|ENTER NOW|BOX PICK|TRIAL ENTRY|🟠 OI|OPENING CALL", tx or ""):
                v.add(s)
        c.close()
    except Exception:
        pass
    _F["_acted"] = (time.time(), v)
    return v


def inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def tick(now, ltp, chg, fo=None, act=None):
    """now (IST datetime) · ltp {sym: price} · chg {sym: day %} -> [alert texts]"""
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "s": {}})
    hm = now.strftime("%H:%M")
    if not ("09:20" <= hm <= "15:25"):
        return []
    t = now.timestamp()
    act = act if act is not None else acted(day)
    out = []
    for s, px in ltp.items():
        c = chg.get(s)
        if c is None or not px or (fo and s not in fo):
            continue
        pc = px / (1 + c / 100.0)
        if s not in ST["s"]:                                       # first sight (a restart mid-day): the day's high / low so far, as old
            ch_ = (_json("charts.json", 20) or {}).get(s) or {}
            hs, ls = [x for x in (ch_.get("h") or []) if x], [x for x in (ch_.get("l") or []) if x]
            ST["s"][s] = {"hi": max([px] + hs), "t_hi": t - (FRESH_S + 1 if hs and max(hs) > px else 0), "oi_hi": None,
                          "lo": min([px] + ls), "t_lo": t - (FRESH_S + 1 if ls and min(ls) < px else 0), "oi_lo": None, "said": {}}
        st = ST["s"][s]
        for side in (1, -1):
            k_, tk = ("hi", "t_hi") if side > 0 else ("lo", "t_lo")
            if (px > st[k_]) if side > 0 else (px < st[k_]):
                st[k_], st[tk], st["oi_" + k_] = px, t, fut_oi(s)
            ext = st[k_]
            move = (ext / pc - 1) * 100 * side                     # the day's move at its best, its way
            need = RUN_ACT if s in act else RUN
            if move < need:
                continue
            said = st["said"].get(side)
            if said and ((ext <= said["at"] * 1.003) if side > 0 else (ext >= said["at"] * 0.997)):
                continue                                           # said already - again only after a new extreme 0.3% beyond
            if said and t - said["t"] < GAP_S:
                continue
            back = (ext - px) / ext * 100 * side                   # how far it came back from the extreme, %
            frac = back / move if move else 0
            if back < max(START_MIN, EARLY * move) or t - st[tk] > FRESH_S:
                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)
            proof, hard = [], False
            o0, o1 = st["oi_" + k_], fut_oi(s)
            if o0 is not None and o1 is not None and o1 < o0 - 0.3:
                proof.append("futures OI falling %+.1f%% → %+.1f%% (%s booking)" % (o0, o1, "longs" if side > 0 else "shorts")); hard = True
            vx, vw = vol_x(s)
            if vx and vx >= 1.5:
                proof.append("volume %.1fx normal this 5 min (real %s)" % (vx, "selling" if side > 0 else "buying")); hard = True
            rf = roof_forming(s, side)
            if rf:
                proof.append("%s writers building a %s at %s" % ("call" if side > 0 else "put", "roof" if side > 0 else "floor", rf))
            if frac >= STRONG:
                proof.append("already %.0f%% of the move given back" % (100 * frac))
            if not proof or (not hard and back < max(START_MIN, START * move)):
                continue                                           # the money proof (OI / volume) lets it ring at 8% given back, else 12%
            st["said"][side] = {"at": ext, "t": t}
            mins = max(1, int(round((t - st[tk]) / 60)))
            keep = pc * (1 + side * move / 200.0)                   # the stop that keeps half the move
            crit = s in act or move >= 4
            if side > 0:
                head = "🚨 %sPROFIT BOOKING ▼ %s · %s" % ("CRITICAL · " if crit else "", s, hm)
                what = "holding a CE: book part NOW, keep the rest with a stop at ₹%s (keeps half the move)%s · not a PE by itself" % (
                    inr(keep), (" · the day's VWAP ₹%s" % inr(vw)) if vw else "")
            else:
                head = "🚨 %sSHORT COVERING ▲ %s · %s" % ("CRITICAL · " if crit else "", s, hm)
                what = "holding a PE: book part NOW, keep the rest with a stop at ₹%s (keeps half the fall)%s · not a CE by itself" % (
                    inr(keep), (" · the day's VWAP ₹%s" % inr(vw)) if vw else "")
            out.append("\n".join([head,
                                  "was %+.1f%% (₹%s) %d min ago · now %+.1f%% (₹%s) · %.0f%% of the %s given back" % (
                                      move * side, inr(ext), mins, c, inr(px), 100 * frac, "rise" if side > 0 else "fall"),
                                  "who: " + " · ".join(proof),
                                  what]))
    return out
PY_PB
cat > $D/p213test.py <<'PY_T1'
#!/usr/bin/env python3
"""p213test.py - patch 213's own test: PROFIT BOOKING replayed (made-up prices like COROMANDEL on 11 Nov) - nothing sent. python3 p213test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(SRC, "pbook.py"), T)
sys.path.insert(0, T)
import pbook as P
P.BASE = T
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
D0 = dt.datetime(2026, 11, 11, 14, 0, tzinfo=IST)
OK = []
def chk(n, c, g=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(g)[:500]))
def run(path, oi_path=None, act=(), vol=None, minutes=40):
    """path(m) -> day % at minute m after 14:00 ; oi_path(m) -> futures OI %"""
    P.ST.update({"day": None, "s": {}}); P._F.clear()
    out = []
    for i in range(0, minutes * 4 + 1):
        now = D0 + dt.timedelta(seconds=15 * i); m = i / 4.0
        c = path(m); px = 1880 * (1 + c / 100)
        json.dump({"fo_paths": [{"s": "COROMANDEL", "oi": oi_path(m) if oi_path else 6.0}]}, open(os.path.join(T, "dash_state.json"), "w"))
        json.dump({"COROMANDEL": {"v": vol(m) if vol else [100] * 20, "vw": 1985.0}}, open(os.path.join(T, "charts.json"), "w"))
        P._F.clear()
        for msg in P.tick(now, {"COROMANDEL": px}, {"COROMANDEL": c}, act=set(act)):
            out.append((now.strftime("%H:%M:%S"), c, msg))
    return out
# 1 · COROMANDEL: +5% at 14:00 -> +9% at 14:24 -> the early money sells: +7.5% by 14:32, futures OI falling from 14:25
up = lambda m: 5 + 4 * min(m, 24) / 24 if m <= 24 else 9 - 1.5 * min(m - 24, 8) / 8
oi = lambda m: 6.0 if m <= 25 else 6.0 - 0.15 * (m - 25)
o = run(up, oi, act=["COROMANDEL"])
chk("COROMANDEL: 🚨 CRITICAL · PROFIT BOOKING ▼ (GIR said act on it)", o and o[0][2].startswith("🚨 CRITICAL · PROFIT BOOKING ▼ COROMANDEL"), o)
chk("… at the START: within 5 min of the +9% high, while it is still +8.2% or higher", o and o[0][0] <= "14:29:00" and o[0][1] >= 8.2, o[:1])
chk("… says who is selling: futures OI falling (longs booking)", o and "futures OI falling" in o[0][2] and "longs booking" in o[0][2], o[:1])
chk("… and what to do: book part of the CE, the stop that keeps half the move", o and "book part NOW" in o[0][2] and "stop at ₹" in o[0][2], o[:1])
chk("… said once (not every 15 s)", len(o) == 1, [x[0] for x in o])
# 2 · a pause without proof (OI steady, normal volume, a small dip) -> nothing
pause = lambda m: 5 + 4 * min(m, 24) / 24 if m <= 24 else 9 - 0.9 * min(m - 24, 3) / 3
o = run(pause)
chk("a 0.9% pause off the high, OI steady, normal volume: no alert (not booking yet)", o == [], o)
# 3 · no proof from OI but a volume burst -> alert
o = run(up, None, vol=lambda m: [100] * 19 + ([260] if m > 25 else [100]))
chk("the same give-back with 2.6x volume (OI unknown): alert, proof = volume", o and "volume 2.6x" in o[0][2], o)
# 4 · a slow drift hours after the high (stale) -> nothing
slow = lambda m: 9 - 2.0 * m / 40
o = run(slow, lambda m: 6.0 - 0.05 * m)
chk("a slow drift from an old high: no alert (that is not the start)", o == [], o)
# 5 · a share up only 1.8% that GIR did not call: not watched
small = lambda m: 1.0 + 0.8 * min(m, 20) / 20 if m <= 20 else 1.8 - 0.6 * (m - 20) / 10
o = run(small, lambda m: 6.0 - 0.1 * m)
chk("a 1.8% mover GIR did not call: not watched", o == [], o)
# 6 · the mirror: a fall being bought back (short covering)
down = lambda m: -4 - 3 * min(m, 20) / 20 if m <= 20 else -7 + 1.6 * min(m - 20, 8) / 8
o = run(down, lambda m: 5.0 if m <= 21 else 5.0 - 0.2 * (m - 21))
chk("the mirror: -7% then bought back -> 🚨 CRITICAL · SHORT COVERING ▲ (book part of a PE)", o and "SHORT COVERING ▲ COROMANDEL" in o[0][2] and "holding a PE" in o[0][2], o)
shutil.rmtree(T, ignore_errors=True)
print("PROFIT BOOKING test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T1
cat > $D/p213atest.py <<'PY_T2'
#!/usr/bin/env python3
"""p213atest.py - patch 213a: which stories are the share's, which are 🌐 FOREIGN, which are not about it (no network). python3 p213atest.py DIR"""
import os, sys
sys.path.insert(0, os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "."))
import newsalert as N
C = [("foreign", "ABB", "ABB India Ltd", "BMW orders more than 1,700 ABB robots for next-generation vehicle production", "roboticsandautomationnews.com"),
     (True, "ABB", "ABB India Ltd", "ABB India bags Rs 500 crore order from Indian Railways", "ET"),
     (True, "ABB", "ABB India Ltd", "ABB shares rally 5% on strong Q3", "Moneycontrol"),
     ("foreign", "SIEMENS", "Siemens Ltd", "Siemens to cut 5,000 jobs in Germany", "reuters.com"),
     (True, "SIEMENS", "Siemens Ltd", "Siemens Ltd wins metro order in Mumbai", "PTI"),
     ("foreign", "NESTLEIND", "Nestle India Ltd", "Nestle CEO outlines global turnaround plan", "ft.com"),
     (True, "NESTLEIND", "Nestle India Ltd", "Nestle India Q2 profit rises", "Business Standard"),
     (False, "CAMS", "Computer Age Management Services Ltd", "Colorado justices to weigh insurer penalties, parole officer body cams", "coloradopolitics.com"),
     (True, "INFY", "Infosys Ltd", "Infosys wins deal with UK retailer", "computerweekly.com"),
     (True, "TATAMOTORS", "Tata Motors Ltd", "Tata Motors' JLR sales fall 12% in China", "reuters.com"),
     (True, "CAMS", "Computer Age Management Services Ltd", "CAMS shares jump 6% after SEBI nod", "Moneycontrol"),
     (False, "OIL", "Oil India Ltd", "Oil prices climb as OPEC cuts output", "reuters.com")]
ok = 0
for exp, s, nm, h, src in C:
    r = N.about_it(s, h, src, nm); ok += (r == exp)
    print("  %s %-8s %-10s %s (%s)" % ("✅" if r == exp else "❌", {True: "its news", "foreign": "🌐 FOREIGN", False: "dropped"}.get(r, r), s, h[:58], src))
print("FOREIGN test: %d of %d passed" % (ok, len(C)))
sys.exit(0 if ok == len(C) else 1)
PY_T2
cat > $W/p213a_patch.py <<'PY_A'
#!/usr/bin/env python3
"""p213a_patch.py - PATCH 213a: a story about the share's FOREIGN side is said as 🌐 FOREIGN, not dropped and not alerted (Rama, 12 Nov: "ABB
robotics - BMW orders 1,700 robots - I think it is not for Indian NSE ... if it is foreign related, with no meaning for NSE, tell me it is
foreign related"). A story about the foreign PARENT of an Indian subsidiary (ABB, Siemens, Bosch, Nestle, Cummins, Abbott, Colgate, Oracle, Hitachi, Whirlpool ...) -> one quiet line:
  🌐 FOREIGN · ABB · roboticsandautomationnews.com 22:40
  BMW orders more than 1,700 ABB robots ...
  about the ABB group abroad, not ABB India (the NSE share) - little meaning for NSE
No AI read is spent on it. A story not about the company at all ("body cams" for CAMS) is still dropped. Usage: python3 p213a_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "newsalert.py"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  newsalert.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  newsalert.py: %s" % tag)


rep('''    try:
        import newshunt as NH
        tl = h.lower()
        india = bool(NH.INDIA_RX.search(tl)) or bool(NH.INDIAN_PUB.search(src or ""))
        if NH.FOREIGN_RX.search(tl) and not NH.INDIA_RX.search(tl):
            return False
        if not india and not by_name:
            return False                                        # a foreign site, no India in it, only a symbol-like word: not it
    except Exception:
        pass
    return True''', '''    try:                                                        # patch 213a: named, but foreign -> "foreign" (said, not alerted)
        import newshunt as NH
        tl = h.lower()
        in_words = bool(NH.INDIA_RX.search(tl))
        india = in_words or bool(NH.INDIAN_PUB.search(src or ""))
        if sym in MNC and not in_words and not re.search(r"\\bindia\\b|\\bltd\\b", tl) and not NH.INDIAN_PUB.search(src or ""):
            return "foreign"                                    # the foreign parent's news (ABB group, Siemens AG, Nestle SA ...)
        if by_name:
            return True                                         # an Indian company by its name - its deals abroad are its news (Infosys in the UK)
        if (NH.FOREIGN_RX.search(tl) and not in_words) or not india:
            return "foreign"                                    # only a ticker-like word, another country / a foreign site
    except Exception:
        pass
    return True''', "named but foreign -> FOREIGN")
rep('''_NM211 = {"t": 0.0, "v": {}}''', '''_NM211 = {"t": 0.0, "v": {}}
MNC = {"ABB": "the ABB group", "SIEMENS": "Siemens AG", "BOSCHLTD": "the Bosch group", "NESTLEIND": "Nestle SA", "CUMMINSIND": "Cummins Inc",   # patch 213a
       "ABBOTINDIA": "Abbott (US)", "COLPAL": "Colgate-Palmolive (US)", "OFSS": "Oracle (US)", "POWERINDIA": "Hitachi Energy", "WHIRLPOOL": "Whirlpool (US)",
       "HONAUT": "Honeywell (US)", "SCHAEFFLER": "the Schaeffler group", "BAYERCROP": "Bayer AG", "GLAXO": "GSK", "PFIZER": "Pfizer (US)",
       "LINDEINDIA": "Linde plc", "SKFINDIA": "SKF (Sweden)", "TIMKEN": "Timken (US)", "3MINDIA": "3M (US)", "PGHH": "Procter & Gamble (US)",
       "GILLETTE": "Procter & Gamble (US)", "CASTROLIND": "BP / Castrol", "KANSAINER": "Kansai Paint (Japan)", "MARUTI": "Suzuki (Japan)"}''', "the foreign parents")
rep('''        if not about_it(sym, h, src, name):                    # patch 211b: "body cams" is not CAMS, a Colorado court is not Indian news
            print("news reader: not about %s - %s (%s)" % (sym, h[:90], src), flush=True)
            return None''', '''        ab = about_it(sym, h, src, name)                       # patch 211b: "body cams" is not CAMS, a Colorado court is not Indian news
        if ab == "foreign":                                     # patch 213a: named, but foreign - said as such, quietly, no AI read
            hm_ = dt.datetime.fromtimestamp(t or time.time(), IST).strftime("%H:%M")
            who = ("about %s abroad, not %s (the NSE share)" % (MNC[sym], sym)) if sym in MNC else "a foreign story (another country, not Indian news)"
            txt = "\\n".join(x for x in ["🌐 FOREIGN · %s · %s %s" % (sym, src or "-", hm_), h, "%s - little meaning for NSE: %s" % (who, sym), link] if x)
            with _L:
                _S["sent"].append((sym, h, time.time()))
            _send(txt)
            return txt
        if not ab:
            print("news reader: not about %s - %s (%s)" % (sym, h[:90], src), flush=True)
            return None''', "FOREIGN said quietly")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("newsalert.py: patch 213a in")
PY_A
cat > $W/p213b_patch.py <<'PY_B'
#!/usr/bin/env python3
"""p213b_patch.py - PATCH 213b: the news hunt (every 15 s) also runs PROFIT BOOKING (pbook.py). Usage: python3 p213b_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "newshunt.py"); s = open(p, encoding="utf-8").read()
old = '''        for m in msgs:
            try:
                self.send(m)'''
new = '''        if q and live:                                          # patch 213: PROFIT BOOKING - the moment it starts
            try:
                import pbook
                msgs += pbook.tick(now, q, day_mv, fo=fo_set())
            except Exception as ex:
                log("profit booking: %s" % str(ex)[:80])
        for m in msgs:
            try:
                self.send(m)'''
if "import pbook" in s:
    print("  newshunt.py: profit booking - already in"); sys.exit(0)
if s.count(old) != 1:
    print("❌ newshunt.py: anchor found %d times" % s.count(old)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  newshunt.py: profit booking runs every 15 s")
PY_B
cd $D && python3 -m py_compile pbook.py || back
echo "=== 1 · profit booking - COROMANDEL 11 Nov replayed (made-up prices - nothing sent)"
timeout 60 python3 p213test.py $D > /tmp/p213a.out 2>&1; R=$?; cat /tmp/p213a.out; [ $R = 0 ] || back
python3 $W/p213b_patch.py $D || back
python3 -m py_compile newshunt.py || back
echo "=== 2 · 🌐 FOREIGN - which stories are the share's"
python3 $W/p213a_patch.py $D || back
python3 -m py_compile newsalert.py || back
timeout 60 python3 p213atest.py $D > /tmp/p213b.out 2>&1; R=$?; cat /tmp/p213b.out; [ $R = 0 ] || back
for s in gir-newsroom gir-newshunt; do systemctl restart $s; done
sleep 5; for s in gir-newsroom gir-newshunt; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 213 done. From 09:20: 🚨 PROFIT BOOKING / SHORT COVERING the moment it starts · 🌐 FOREIGN said quietly."
echo "   watch it: grep -i 'profit\|short cover' /home/globalbot/intraday/data/newshunt.log | tail"
echo "   undo: for f in newsalert.py newshunt.py; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/pbook.py; systemctl restart gir-newsroom gir-newshunt"
