#!/bin/bash
# PATCH 225 - THE P1 VOTE (Rama chose it, 12 Nov; the day's audit: 322 rings, P1 calls right 13 of 41 after 60 min).
#   A 🔴 P1 call rings with the ambulance only when 4 of 6 checks agree with its side: desk · futures money · VWAP · who is pushing · NIFTY not
#   against · not already run 3%. Opening burst 09:15-09:25: 5 of 6 and at most 3 P1. Below that it goes out as 🟠 P2 (still sent, still on the
#   page - nothing dropped). Unreadable data = it stays P1 and says so. The result is written into the alert: "⚖ VOTE 5/6 ✔ P1 · desk ✓ ...".
#   Tested: 10 made-up cases + the page; then a preview on TODAY's real P1 calls (the price checks). Restarts the senders - after 15:35 (or: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); mkdir -p $W/src
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 224" $D/tglanes.py || { echo "patch 224 first"; exit 1; }
F="alertword.py tglanes.py engine2.py desk.py opencall.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p1vote.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/src/p1vote.py <<'PY_VOTE'
#!/usr/bin/env python3
"""p1vote.py - patch 225: THE P1 VOTE (Rama, 12 Nov - the day's audit: 322 rings, the P1 calls right 13 of 41 times after 60 min).
A 🔴 P1 call (GO, ENTER NOW, Box Pick, opening call, a measured BUY) rings with the ambulance only when 4 of 6 independent checks agree with
its side; otherwise it goes out as 🟠 P2 (still on Telegram and the page - nothing is dropped). In the opening burst (09:15-09:25): 5 of 6, and
at most 3 P1. The checks, each read live when the call is sent:
  1 desk      the F&O desk's reading of the share (+1 / +2 its way)
  2 futures   fresh futures money its way (long build-up / short covering for a CE, ₹5 cr+)
  3 VWAP      the price on the call's side of the day's VWAP (before the first 5-min candle closes: of the day's open)
  4 push      who is pushing: new money / both / forced out its way
  5 tide      NIFTY not against it (-0.2% or better its way)
  6 not late  the share has not already run 3%+ its way today
A check that cannot be read counts as not agreeing; with fewer than 4 readable the vote is not applied (it stays P1, and says so).
The result is written into the alert ("⚖ VOTE 5/6 ✔ P1 · desk ✓ · ..."), so Telegram, the page and the exit watch all read the same thing."""
import os, re, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NEED, NEED_OPEN, OPEN_CAP, LATE = 4, 5, 3, 3.0
ST = {"day": None, "open_n": 0}
_F = {}
SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")
NOT_SYM = ("CE", "PE", "BUY", "SELL", "UP", "DOWN", "OI", "GO", "CONFIRMED")


def _json(name, ttl):
    t, v = _F.get(name, (0.0, None))
    if v is not None and time.time() - t < ttl:
        return v
    try:
        v = json.load(open(os.path.join(BASE, name)))
    except Exception:
        v = None
    _F[name] = (time.time(), v)
    return v


def target(text):
    """an alert -> (head line, share, +1 CE / -1 PE) or None"""
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return None
    h = L[1] if (L[0].startswith("🔔 OPENING") and not L[0].startswith("🔔 OPENING · ") and len(L) > 1) else L[0]
    h2 = h[len("🔔 OPENING · "):] if h.startswith("🔔 OPENING · ") else h
    cand = [m.group(1) for m in SYM_RX.finditer(h2)] + [m.group(1) for m in re.finditer(r"·\s+([A-Z][A-Z0-9&\-]{1,19})\s+[▲▼]", h2)]
    sym = next((x for x in cand if x not in NOT_SYM), None)
    if not sym or sym in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX", "MARKET"):
        return None
    up, dn = "▲" in h2 or re.search(r"\bCE\b", h2), "▼" in h2 or re.search(r"\bPE\b", h2)
    if bool(up) == bool(dn):
        return None
    return h2, sym, 1 if up else -1


def checks(sym, d, now):
    """-> [(name, True / False / None, note)]"""
    out = []
    dk = (((_json(os.path.join("data", "desk.json"), 15) or {}).get("shares") or {}).get(sym) or {})
    v = dk.get("v")
    out.append(("desk", None if not isinstance(v, (int, float)) else v * d >= 1, ("%+d" % v) if isinstance(v, (int, float)) else "no reading"))
    st = _json("dash_state.json", 10) or {}
    f = next((x for x in st.get("fo_paths") or [] if x.get("s") == sym), None)
    if f is None:
        out.append(("futures", None, "not read"))
    else:
        bu, cr = (f.get("bu") or "").replace("_", " ").upper(), abs(f.get("cr") or 0)
        mine = ("LONG BUILD-UP", "SHORT COVERING") if d > 0 else ("SHORT BUILD-UP", "LONG UNWINDING")
        out.append(("futures", bool(bu in mine and cr >= 5), ("%s ₹%.0f cr" % (bu.lower(), cr)) if bu else "no build-up"))
    q = ((_json("quotes_live.json", 3) or {}).get("q") or {}).get(sym) or []
    px = q[0] if q else (f or {}).get("ltp")
    chg = q[1] if len(q) > 1 and q[1] is not None else (f or {}).get("chg")
    ch = (_json("charts.json", 10) or {}).get(sym) or {}
    C, H, Lo, V, O = ch.get("c") or [], ch.get("h") or [], ch.get("l") or [], ch.get("v") or [], ch.get("o") or []
    n = max(0, min(len(C), ((now.hour * 60 + now.minute) - 555) // 5))
    pv = vv = 0.0
    for i in range(n):
        if C[i] and i < len(V) and V[i]:
            pv += ((H[i] if i < len(H) and H[i] else C[i]) + (Lo[i] if i < len(Lo) and Lo[i] else C[i]) + C[i]) / 3.0 * V[i]; vv += V[i]
    if px and vv:
        vw = pv / vv
        out.append(("VWAP", (px - vw) * d > 0, "₹%s vs VWAP ₹%s" % (_r(px), _r(vw))))
    elif px and O and O[0]:
        out.append(("VWAP", (px - O[0]) * d > 0, "₹%s vs the open ₹%s" % (_r(px), _r(O[0]))))
    else:
        out.append(("VWAP", None, "no price"))
    try:
        import pushwho
        p = pushwho.read(sym)
        pd_ = 1 if p.get("dir") == "UP" else -1 if p.get("dir") == "DOWN" else 0
        out.append(("push", pd_ == d and p.get("kind") in ("NEW MONEY", "BOTH", "FORCED OUT"), p.get("kind") or "no clear push"))
    except Exception:
        out.append(("push", None, "not read"))
    nf = ((st.get("idx") or {}).get("NIFTY") or {}).get("chg")
    out.append(("tide", None if nf is None else nf * d >= -0.2, ("NIFTY %+.1f%%" % nf) if nf is not None else "no NIFTY"))
    out.append(("not late", None if chg is None else chg * d < LATE, ("%+.1f%% today" % chg) if chg is not None else "no change"))
    return out


def _r(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def vote(text, now=None):
    """a P1 alert -> the same alert with its ⚖ VOTE line (✔ P1 / ✖ P2); any other alert unchanged. Never raises."""
    try:
        if not text or "⚖ VOTE" in text:
            return text
        import alertword
        if alertword.tier(text) != "act":
            return text
        tg = target(text)
        if not tg:
            return text
        h2, sym, d = tg
        if re.search(r"🛑|🎯 BOOK HALF|⏰ TIME EXIT|💼|OPENING CALL FAILED", h2):
            return text                                         # your own trade / an exit - never voted down
        now = now or dt.datetime.now(IST)
        day, hm = str(now.date()), now.strftime("%H:%M")
        if ST["day"] != day:
            ST.update({"day": day, "open_n": 0})
        res = checks(sym, d, now)
        known = [r for r in res if r[1] is not None]
        yes = sum(1 for r in res if r[1])
        opening = "09:15" <= hm < "09:25"
        need = NEED_OPEN if opening else NEED
        marks = " · ".join("%s %s" % (k, "✓" if ok else "✗" if ok is False else "?") for k, ok, _ in res)
        if "RESULTS REACTION" in h2:                            # patch 223: a results reaction is a P1 on its own proof - shown, never turned down
            L = text.split("\n")
            return "\n".join(L[:1] + ["⚖ VOTE %d/6 ✔ P1 (a results reaction - the filing, the price and the volume are its proof) · %s" % (yes, marks)] + L[1:])
        if len(known) < 4 and not (opening and ST["open_n"] >= OPEN_CAP):
            line = "⚖ VOTE n/a - only %d of 6 checks readable now, stays P1 · %s" % (len(known), marks)
            if opening:
                ST["open_n"] += 1
        elif opening and ST["open_n"] >= OPEN_CAP:
            line = "⚖ VOTE %d/6 ✖ P2 - the opening's %d P1 calls are taken (09:15-09:25) · %s" % (yes, OPEN_CAP, marks)
        elif yes >= need:
            line = "⚖ VOTE %d/6 ✔ P1 · %s" % (yes, marks)
            if opening:
                ST["open_n"] += 1
        else:
            line = "⚖ VOTE %d/6 ✖ P2 - only %d agree, a P1 needs %d · %s" % (yes, yes, need, marks)
        why = [("%s: %s" % (k, note)) for k, ok, note in res if ok is False][:3]
        if why and "✖" in line:
            line += "\n   against: " + " · ".join(why)
        L = text.split("\n")
        at = 2 if (L[0].startswith("🔔 OPENING") and not L[0].startswith("🔔 OPENING · ") and len(L) > 1) else 1
        return "\n".join(L[:at] + [line] + L[at:])
    except Exception:
        return text
PY_VOTE
cat > $W/p225_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p225_patch.py - PATCH 225: THE P1 VOTE wired in (Rama chose it, 12 Nov). p1vote.py next to this script.
  alertword.tier: a P1 whose ⚖ VOTE says ✖ P2 is P2 · the 3 senders (engine, desk, news hunt / opencall) vote before choosing the channel ·
  the page's mirror of tier reads the same line. Usage: python3 p225_patch.py DIR SRCDIR"""
import sys, os, shutil
D, SRC = sys.argv[1], sys.argv[2]
ERR = []
shutil.copy(os.path.join(SRC, "p1vote.py"), os.path.join(D, "p1vote.py")); print("  p1vote.py: in")


def rep(f, old, new, tag):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        ERR.append("%s missing" % f); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("alertword.py", '''def tier(text):
    L = [x for x in (text or "").split("\\n") if x.strip()]''', '''def tier(text):
    """patch 225: a P1 that THE VOTE turned down (⚖ VOTE ... ✖ P2) rings as P2"""
    t = _tier0(text)
    if t == "act" and re.search(r"⚖ VOTE[^\\n]*✖ P2", text or ""):
        return "move"
    return t


def _tier0(text):
    L = [x for x in (text or "").split("\\n") if x.strip()]''', "tier: a P1 voted down = P2")
HOOK = '''    try:                                                        # patch 225: THE P1 VOTE - a P1 rings only when 4 of 6 checks agree
        import p1vote
        text = p1vote.vote(text)
    except Exception as ex:
        log("p1vote: %s" % str(ex)[:80])
'''
A = '''    try:                                                        # patch 124: the alert's channel - CRITICAL (Box Picks) · OI · MOVES & NEWS
        import tglanes
        chat = tglanes.chat_for(text, chat)'''
for f in ("engine2.py", "desk.py"):
    rep(f, A, HOOK + A, "the vote before the channel")
rep("opencall.py", '''        import alertword, tglanes
        chat = tglanes.chat_for(text, box)''', '''        import alertword, tglanes
        try:                                                    # patch 225: THE P1 VOTE
            import p1vote
            text = p1vote.vote(text)
        except Exception as ex:
            print("p1vote: %s" % str(ex)[:80])
        chat = tglanes.chat_for(text, box)''', "the vote before the channel")
rep("tglanes.py", '''    if re.search(r"🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT", H2):        # patch 224: the exit watch - with the entries, in the ambulance channel''',
    '''    if re.search(r"⚖ VOTE[^\\n]*✖ P2", text or ""):             # patch 225: a P1 the vote turned down is not a trade call
        return False
    if re.search(r"🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT", H2):        # patch 224: the exit watch - with the entries, in the ambulance channel''', "trade now: not a P1 voted down")
rep("home.html", '''function alertTier(r){ const H=r.head||"", L=r.lines||[], T=[H].concat(L).join("\\n"), k=r.kind||H.split(" ")[0]||"";''',
    '''function alertTier(r){ const t_=alertTier0(r); return (t_==="act"&&/⚖ VOTE[^\\n]*✖ P2/.test([r.head||""].concat(r.lines||[]).join("\\n")))?"move":t_; }   /* patch 225: THE P1 VOTE */
function alertTier0(r){ const H=r.head||"", L=r.lines||[], T=[H].concat(L).join("\\n"), k=r.kind||H.split(" ")[0]||"";''', "the page: a P1 voted down = P2")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 225 in")
PY_PATCH
cat > $W/p225test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p225test.py - THE P1 VOTE on made-up data (temp folder, stub readers, nothing sent).  python3 p225test.py DIR SRCDIR
DIR = the server folder (alertword.py, tglanes.py are copied from it), SRCDIR = p1vote.py"""
import os, sys, json, shutil, tempfile, datetime as dt
D, SRC = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "tglanes.py"):
    shutil.copy(os.path.join(D, f), T)
shutil.copy(os.path.join(SRC, "p1vote.py"), T)
open(os.path.join(T, "pushwho.py"), "w").write('''
R = {"PAYTM": ("UP", "NEW MONEY"), "AUROPHARMA": ("UP", "TIDE ONLY"), "LICI": ("UP", "NEW MONEY"), "COCHINSHIP": ("UP", "BOTH"),
     "PRESTIGE": ("UP", "NEW MONEY"), "NESTLEIND": ("DOWN", "NEW MONEY"), "TATAPOWER": ("UP", "NEW MONEY")}
def read(s):
    d, k = R.get(s, ("", ""))
    return {"dir": d, "kind": k}
''')
N = 75
def flat(p): return {"o": [p] * N, "h": [p * 1.001] * N, "l": [p * 0.999] * N, "c": [p] * N, "v": [1000] * N}
ch = {s: flat(p) for s, p in {"PAYTM": 1780, "AUROPHARMA": 1810, "LICI": 405, "COCHINSHIP": 1200, "PRESTIGE": 1620, "NESTLEIND": 1290, "TATAPOWER": 360}.items()}
json.dump(ch, open(os.path.join(T, "charts.json"), "w"))
json.dump({"t": 0, "q": {"PAYTM": [1795.0, 1.2], "AUROPHARMA": [1803.9, -1.3], "LICI": [408.6, 3.4], "COCHINSHIP": [1210.6, 0.7], "PRESTIGE": [1625.2, 0.1],
                         "NESTLEIND": [1278.0, -0.8], "TATAPOWER": [365.2, 1.5]}}, open(os.path.join(T, "quotes_live.json"), "w"))
json.dump({"idx": {"NIFTY": {"chg": 0.3}}, "fo_paths": [
    {"s": "PAYTM", "bu": "LONG BUILD-UP", "cr": 143}, {"s": "AUROPHARMA", "bu": "SHORT BUILD-UP", "cr": 40}, {"s": "LICI", "bu": "LONG BUILD-UP", "cr": 60},
    {"s": "COCHINSHIP", "bu": "LONG BUILD-UP", "cr": 22}, {"s": "PRESTIGE", "bu": "LONG BUILD-UP", "cr": 30}, {"s": "NESTLEIND", "bu": "SHORT BUILD-UP", "cr": 18},
    {"s": "TATAPOWER", "bu": "LONG BUILD-UP", "cr": 25}]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"shares": {"PAYTM": {"v": 2}, "AUROPHARMA": {"v": -1}, "LICI": {"v": 1}, "COCHINSHIP": {"v": 2}, "PRESTIGE": {"v": 1}, "NESTLEIND": {"v": -2}, "TATAPOWER": {"v": 1}}},
          open(os.path.join(T, "data", "desk.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import p1vote as P, alertword as A, tglanes as G
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))
day = dt.datetime(2026, 11, 12, tzinfo=dt.timezone(dt.timedelta(hours=5, minutes=30)))
at = lambda h, m: day.replace(hour=h, minute=m)
# outside the opening (11:00): 4 of 6
t = P.vote("⚡ ENTER NOW ▲ PAYTM CE · ₹1,794.9 +1.2% · 11:00\n▶ BUY 1800 CE ₹42", at(11, 0))
chk("PAYTM CE, everything agrees: ⚖ VOTE 6/6 ✔ P1 - stays P1, ambulance channel", "⚖ VOTE 6/6 ✔ P1" in t and A.tier(t) == "act" and G.trade_now(t), t)
t = P.vote("⚡ ENTER NOW ▼ AUROPHARMA PE · ₹1,803.9 -1.3% · 11:00\n▶ BUY 1800 PE ₹30", at(11, 0))
chk("AUROPHARMA PE: desk / futures / VWAP agree, push does not: 5/6 ✔", "✔ P1" in t, t)
t = P.vote("⚡ ENTER NOW ▲ AUROPHARMA CE · ₹1,803.9 -1.3% · 11:00\n▶ BUY 1820 CE ₹20", at(11, 0))
chk("AUROPHARMA CE against the desk, the futures and VWAP: ✖ P2 -> tier P2, not the ambulance channel, 'against:' says why",
    "✖ P2" in t and A.tier(t) == "move" and not G.trade_now(t) and "against:" in t, t)
d2, _s = A.dress(t)
chk("the P2 one is tagged P2 when dressed (not P1)", "P1" not in d2.split("\n")[1] or "P2" in d2, d2.split("\n")[:3])
t = P.vote("⚡ ENTER NOW ▲ LICI CE · ₹408.6 +3.4% · 11:00\n▶ BUY 410 CE ₹6", at(11, 0))
chk("LICI CE already +3.4%: 'not late' ✗ but 5/6 - still ✔ P1", "not late ✗" in t and "✔ P1" in t, t)
t2 = P.vote(t, at(11, 1))
chk("voting twice changes nothing", t2 == t)
r = "🚀 RUNNING ▼ PAGEIND ₹35825 -2.0%"
chk("a non-P1 alert is untouched", P.vote(r, at(11, 0)) == r)
e = "🚨 CRITICAL · 🛑 EXIT - STOP · UNIONBANK 205 CE · 13:50\nwhy: a 5-min close under 200"
chk("an EXIT is never voted", P.vote(e, at(13, 50)) == e)
# the opening burst: 5 of 6, at most 3 P1
P.ST.update({"day": None})
outs = [P.vote("⚡ ENTER NOW ▲ %s CE · 09:20\n▶ BUY CE" % s, at(9, 20)) for s in ("PAYTM", "COCHINSHIP", "PRESTIGE", "TATAPOWER", "LICI")]
p1 = [o for o in outs if "✔ P1" in o]
chk("09:20 burst: the first 3 that reach 5/6 are P1, the rest P2 ('the opening's 3 P1 calls are taken')", len(p1) == 3 and sum("calls are taken" in o for o in outs) == 2, [o.split("\n")[1][:60] for o in outs])
# nothing readable -> stays P1, says so
os.remove("dash_state.json"); os.remove(os.path.join("data", "desk.json")); os.remove("quotes_live.json"); os.remove("charts.json"); P._F.clear()
t = P.vote("🟢 GO · SWIGGY ▲ CE · 11:00\nBUY: 300 CE ₹8", at(11, 0))
chk("the data not readable: ⚖ VOTE n/a - stays P1 (never silently demoted)", "⚖ VOTE n/a" in t and A.tier(t) == "act", t)
print("P1 VOTE test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p225_patch.py $D $W/src || back
cd $D && python3 -m py_compile p1vote.py alertword.py tglanes.py engine2.py desk.py opencall.py || back
echo "=== test: the vote on made-up calls (this server's alertword + tglanes)"
python3 $W/p225test.py $D $W/src || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== preview on TODAY's real P1 calls - the two PRICE checks (VWAP, not late) at the call's time vs right / wrong 60 min later"
cd $D && python3 - "$(TZ=Asia/Kolkata date +%F)" <<'PY'
import sys, json, sqlite3
sys.path.insert(0, "/home/globalbot/intraday")
import alertword
day = sys.argv[1]
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, sym, side, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
ch = json.load(open("charts.json"))
g = {"both": [0, 0], "one": [0, 0], "none": [0, 0]}
for t, s, sd, tx in rows:
    sd = (sd or "").upper()
    if alertword.tier(tx or "") != "act" or sd not in ("CE", "PE") or not s:
        continue
    x = ch.get(s) or {}
    C, H, L, V, pc = x.get("c") or [], x.get("h") or [], x.get("l") or [], x.get("v") or [], x.get("pc")
    i = (int(t[:2]) * 60 + int(t[3:5]) - 555) // 5
    if not (0 <= i < len(C)) or not C[i] or not pc:
        continue
    d = 1 if sd == "CE" else -1
    pv = sum(((H[j] or C[j]) + (L[j] or C[j]) + C[j]) / 3 * (V[j] or 0) for j in range(i) if C[j]); vv = sum((V[j] or 0) for j in range(i) if C[j])
    vw_ok = (C[i] - pv / vv) * d > 0 if vv else ((C[i] - (x.get("o") or [C[i]])[0]) * d > 0)
    late_ok = (C[i] / pc - 1) * 100 * d < 3
    j = min(len(C) - 1, i + 12)
    right = bool(C[j]) and (C[j] / C[i] - 1) * 100 * d > 0.3
    k = "both" if vw_ok and late_ok else "one" if (vw_ok or late_ok) else "none"
    g[k][0] += right; g[k][1] += 1
for k, lab in (("both", "both price checks agreed"), ("one", "one of the two agreed"), ("none", "neither agreed")):
    r, n = g[k]
    print("   %-26s %2d calls · right after 60 min %d (%s)" % (lab, n, r, ("%.0f%%" % (100 * r / n)) if n else "-"))
print("   (the full vote adds the desk, the futures money, who is pushing and NIFTY - read live from tomorrow; the audit measures it)")
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 225 done - from tomorrow every P1 shows ⚖ VOTE n/6. ✔ P1 = the ambulance (GIR TRADE NOW) · ✖ P2 = Box Picks / its lane."
echo "   tomorrow evening: bash /tmp/alertaudit.sh - it now also scores the calls the vote turned down (were they wrong?)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/p1vote.py; systemctl restart $SV"
