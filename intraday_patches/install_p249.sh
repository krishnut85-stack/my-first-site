#!/bin/bash
# PATCH 249 - THE NEW RING RULES (Rama approved all four, 13 Nov evening, after the day's audit: 225 rings - one every 1.8 min, 64 in the 09:00 hour;
#   ANGELONE seen at 13:51 by a silent FIRST MOVE but rung only at 13:55 by PUSH STARTED; NAVINFLUOR's 13:52 profit-booking warning after a 13:36 P1
#   possibly held by the 30-min guard; PUSH / PULL STARTED right 7 of 27).
#   1 ⚡ FIRST MOVE with volume 5x+ rings (GIR Box Picks) · 🚨 PUSH / PULL STARTED comes without sound
#   2 PROFIT BOOKING / SHORT COVERING / LONG UNWINDING / money turned against a 🔴 P1 (within 2 h) ALWAYS rings - "⚠ against the P1 at HH:MM"
#   3 09:15-09:30: only P1, results, regulator / government (and exits, circuits, GIR's alarms) ring · the same P1 line twice in 10 min rings once
#   4 a results-window share (the special force's RESULTS list): the 👁 EVENT WATCH, P1 calls and results lines ring; the rest silent
#   Nothing is dropped - a silent alert still reaches its channel and the page, marked "🔕 no ring - why".
#   Tested: 21 cases; then the last trading day's real alerts replayed through the old and the new rules. Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/ringgov.py ] && grep -q "patch 247" $D/home.html || { echo "patches 228 and 247 first"; exit 1; }
F="alertword.py tglanes.py ringgov.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p249_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p249_patch.py - PATCH 249: THE NEW RING RULES (Rama approved all four, 13 Nov evening, after the day's audit: 225 rings, the early alerts silent,
ANGELONE heard at 13:55 though GIR saw it at 13:51, NAVINFLUOR's 13:52 profit-booking warning after a 13:36 P1 possibly silent).
  1 the EARLY alert rings, not the late one: ⚡ FIRST MOVE with volume 5x+ normal rings (GIR Box Picks); 🚨 PUSH / PULL STARTED (right 7 of 27)
    comes without sound
  2 a warning against a P1 ALWAYS rings: PROFIT BOOKING / SHORT COVERING / LONG UNWINDING / the money turned - the other way within 2 h of a
    🔴 P1 on the share - never held by the contradiction guard or the 15-min rule; "⚠ against the 🔴 P1 at 13:36 - protect it"
  3 09:15-09:30 only P1, results, regulator / government alerts (and GIR's own alarms, exits, circuits) ring - the rest arrive silently;
    the same P1 line twice within 10 min (09:16 GO JIOFIN x2) rings once
  4 a results-window share (the special force's RESULTS list) speaks with ONE voice: the 👁 EVENT WATCH, P1 calls and results lines ring;
    GIR's other alerts on it arrive silently
Nothing is dropped: a silent alert still reaches its channel and the page, marked "🔕 no ring - why". Usage: python3 p249_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []
MAIN = 'if __name__ == "__main__":'


def add(f, code, mark, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if mark in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(MAIN) == 1:
        s = s.replace(MAIN, code.rstrip("\n") + "\n\n\n" + MAIN)
    else:
        s = s.rstrip("\n") + "\n\n\n" + code
    open(p, "w", encoding="utf-8").write(s); print("  %s: %s" % (f, tag))


add("alertword.py", '''_tier249 = tier                                                    # patch 249 rule 1: the EARLY alert rings


def tier(text):
    """patch 249: a ⚡ FIRST MOVE with volume 5x+ normal rings ("move") - GIR's earliest sign of a move (ANGELONE 13:51, heard only at 13:55)"""
    t_ = _tier249(text)
    if t_ != "read":
        return t_
    try:
        L = [x for x in (text or "").split("\\n") if x.strip()]
        if L:
            op, H2, body = _head(L)
            if not op and H2.startswith("⚡ FIRST MOVE"):
                v = re.search(r"volume\\s*(\\d+(?:\\.\\d+)?)\\s*x", "\\n".join(L))
                if v and float(v.group(1)) >= 5:
                    return "move"
    except Exception:
        pass
    return t_
''', "_tier249", "rule 1: ⚡ FIRST MOVE with volume 5x+ rings")

add("tglanes.py", '''_lane249 = lane                                                    # patch 249 rule 1


def lane(text):
    """patch 249: a ringing ⚡ FIRST MOVE goes to GIR Box Picks (where PUSH STARTED used to ring)"""
    ln = _lane249(text)
    try:
        import alertword
        L = [x for x in (text or "").split("\\n") if x.strip()]
        if ln != "critical" and L and alertword._head(L)[1].startswith("⚡ FIRST MOVE") and alertword.tier(text) == "move":
            return "critical"
    except Exception:
        pass
    return ln
''', "_lane249", "rule 1: a ringing FIRST MOVE -> GIR Box Picks")

add("ringgov.py", '''# ---------------- patch 249: the new ring rules (Rama, 13 Nov evening) ----------------
P1_S, DUP_S, OPEN_A, OPEN_B, RW_S = 7200, 600, "09:15", "09:30", 600
EXIT249 = re.compile(r"PROFIT BOOKING|SHORT COVERING|LONG UNWINDING|MONEY TURNED|money turned", re.I)
PUSHPULL249 = re.compile(r"\\b(?:PUSH|PULL) STARTED\\b")
RES249 = re.compile(r"RESULTS|📑")
REG249 = re.compile(r"GOVT|REGULATOR|·\\s*REG\\b|\\bSEBI\\b|\\bRBI\\b|IRDAI|\\bPIB\\b|CABINET|MINISTRY|NIFTY SHOCK|MACRO WARNING")
_gate249 = gate


def results_window(now):
    """{sym: "results DATE"} - the special force's RESULTS shares (eventwatch.watch_list); {} when it cannot be read (then rule 4 is off)"""
    t, v = _F.get("rw", (0.0, None))
    if v is None or time.time() - t > RW_S:
        try:
            import eventwatch
            W = eventwatch.watch_list(now) or {}
            v = {s: "results %s" % (w.get("date") or "") for s, w in W.items() if w.get("agent") == "RESULTS"}
        except Exception:
            v = {}
        _F["rw"] = (time.time(), v)
    return v


def gate(text, tr, now=None, px=None, candles=None):
    """patch 249 on top of the ring rules of 228: (2) a warning against a P1 always rings · the same P1 line twice in 10 min rings once ·
    (3) 09:15-09:30 only P1 / results / regulator · (1) PUSH / PULL STARTED silent · (4) results-window shares: the special force speaks"""
    now = now or dt.datetime.now(IST)
    t, hm = now.timestamp(), now.strftime("%H:%M")
    h, sym, d = target(text)
    kind = (h.split() or ["?"])[0]
    act = tr == "act"
    p1 = (act or "🔴 TRADE ALERT" in text or bool(re.search(r"⚖ VOTE[^\\n]*✓ P1", text))) and not re.search(r"✖ P2", text)   # a P1, by the level or by its own words
    c = _db()
    try:
        c.execute("create table if not exists p1s(t real, sym text, side int)")
        if sym and d and EXIT249.search(h):                                         # rule 2
            p = c.execute("select t, side from p1s where sym=? and side=? and t>=? order by t desc limit 1", (sym, -d, t - P1_S)).fetchone()
            if p:
                c.execute("insert into rings values (?, ?, ?, ?, ?, ?)", (t, sym, d, kind, px if px is not None else _price(sym), 0)); c.commit()
                return text.rstrip("\\n") + "\\n⚠ against the 🔴 P1 at %s (%s) on %s - if you took it, protect it now" % (
                    _hm(p[0]), "▲ CE" if p[1] > 0 else "▼ PE", sym), False
        if act and sym:                                                             # the same P1 line twice
            r = c.execute("select t from rings where sym=? and side=? and kind=? and t>=? and t<=?", (sym, d, kind, t - DUP_S, t)).fetchone()
            if r:
                return _quiet(text, "a repeat of the %s at %s on %s" % (kind, _hm(r[0]), sym))
        protect = act or bool(PROTECT.search(h))
        if OPEN_A <= hm < OPEN_B and not (protect or RES249.search(h) or REG249.search(h)):   # rule 3
            return _quiet(text, "09:15-09:30 - only P1, results and regulator alerts ring (Rama, 13 Nov)")
        if not act and PUSHPULL249.search(h):                                       # rule 1
            return _quiet(text, "PUSH / PULL STARTED was right 7 of 27 (13 Nov) - the earlier ⚡ FIRST MOVE rings instead (Rama, 13 Nov)")
        if sym and not protect and not RES249.search(h) and "EVENT WATCH" not in h:   # rule 4
            rw = results_window(now)
            if sym in rw:
                return _quiet(text, "📑 a results share (%s) - the special force speaks for it (Rama, 13 Nov)" % rw[sym])
    finally:
        c.close()
    out = _gate249(text, tr, now, px, candles)
    if p1 and sym and d and not out[1] and not re.search(r"🛑|🎯|⏰|💼|EXIT", h):   # remember the P1 for rule 2
        c = _db()
        try:
            c.execute("create table if not exists p1s(t real, sym text, side int)")
            c.execute("insert into p1s values (?, ?, ?)", (t, sym, d)); c.commit()
        finally:
            c.close()
    return out
''', "_gate249", "rules 2 · 3 · 1 · 4 + the same P1 line once")

p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
OLD = '''  if(/MORNING BRIEF|TODAY'S PATTERN|MACRO WARNING/.test(H)) return "move";   /* patch 247 */'''
NEW = OLD + '''
  if(/^⚡ FIRST MOVE/.test(H)&&+((T.match(/volume\\s*(\\d+(?:\\.\\d+)?)\\s*x/)||[])[1]||0)>=5) return "move";   /* patch 249: the early alert rings */'''
if NEW in s:
    print("  home.html: the page - FIRST MOVE 5x+ rings - already in")
elif s.count(OLD) == 1:
    open(p, "w", encoding="utf-8").write(s.replace(OLD, NEW)); print("  home.html: the page - FIRST MOVE 5x+ rings")
else:
    ERR.append("home.html: the patch 247 line is not there (patch 247 first)")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 249 in")
PY_PATCH
cat > $W/p249test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p249test.py - the new ring rules on 13 Nov's real situations (made-up files, temp folder, nothing sent). python3 p249test.py DIR
(DIR: alertword.py, tglanes.py, ringgov.py after patch 249)"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "tglanes.py", "ringgov.py"):
    shutil.copy(os.path.join(SRC, f), T)
open(os.path.join(T, "eventwatch.py"), "w").write("def watch_list(now=None):\n    return {'ABB': {'agent': 'RESULTS', 'date': '2026-11-13'}, 'KAYNES': {'agent': 'EVENTS', 'date': '2026-11-10'}}\n")
json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
json.dump({}, open(os.path.join(T, "charts.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import alertword as A, tglanes as L, ringgov as G
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
at = lambda h, m, s=0: dt.datetime(2026, 11, 16, h, m, s, tzinfo=IST)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
def send(tx, now):
    out, silent = A.dress(tx) if False else (None, None)
    tr = A.tier(tx)
    if tr == "read":
        return tx, True
    return G.gate(A._dress0(tx)[0] if hasattr(A, "_dress0") else tx, tr, now=now, px=100.0, candles={})
FM8 = "⚡ FIRST MOVE ▲ ANGELONE ₹349.25 +0.8% in 63 s · 13:51:00 · volume 8x its normal minute · day +2.4%\nWATCH — not a trade yet: share price going UP → CE side"
FM3 = FM8.replace("ANGELONE", "TCS").replace("volume 8x", "volume 3x")
chk("rule 1: FIRST MOVE with volume 8x rings ('move'); with 3x it stays quiet", A.tier(FM8) == "move" and A.tier(FM3) == "read", (A.tier(FM8), A.tier(FM3)))
chk("rule 1: a ringing FIRST MOVE goes to GIR Box Picks (critical lane)", L.lane(FM8) == "critical", L.lane(FM8))
o, s = send(FM8, at(13, 51, 3))
chk("ANGELONE 13:51:03: the FIRST MOVE RINGS", s is False, o)
o, s = send("🚨 PUSH STARTED ▲ ANGELONE · 13:55\n▲ 3 pushing up", at(13, 55, 5))
chk("ANGELONE 13:55: PUSH STARTED arrives silently, says why", s is True and "7 of 27" in o, o)
o, s = send("🚨 PULL STARTED ▼ NMDC · 11:47\n▼ 2 pulling down", at(11, 47))
chk("rule 1: PULL STARTED on another share: silent too", s is True, o)
P1 = "🧩 LONG BUILD-UP ▲ NAVINFLUOR ₹10152.5 +1.9% · 13:36\n▶ BUY 10200 CE ₹244\n⚖ VOTE 5/6 ✓ P1"
o, s = G.gate(P1, "act", now=at(13, 36, 17), px=10152.5, candles={})
chk("NAVINFLUOR 13:36: the P1 rings", s is False, o)
PB = "🚨 CRITICAL · PROFIT BOOKING ▼ NAVINFLUOR · 13:51\nwas +1.9% (₹10,158) 9 min ago · now +1.4%"
o, s = G.gate(PB, "move", now=at(13, 52, 1), px=10106.0, candles={})
chk("rule 2: NAVINFLUOR 13:52 PROFIT BOOKING against the P1 RINGS (was held by the 30-min guard)", s is False and "against the 🔴 P1 at 13:36 (▲ CE)" in o, o)
G.gate("🚨 SUDDEN ▲ HINDALCO ₹951 · 12:50", "move", now=at(12, 50), px=951.0, candles={})
o, s = G.gate("🚨 CRITICAL · SHORT COVERING ▲ HINDALCO · 13:07", "move", now=at(13, 7, 3), px=950.0, candles={})
o2, s2 = G.gate("🚨 CRITICAL · SHORT COVERING ▼ HINDALCO · 13:20", "move", now=at(13, 20), px=948.0, candles={})
chk("rule 2 only for P1s: HINDALCO (no P1) follows the old rules - 13:07 rings (as on 13 Nov), 13:20 the other way is held", s is False and s2 is True, (o[-90:], o2[-90:]))
o, s = G.gate("🟢 GO · JIOFIN ▼ PE · 09:16\n▶ BUY 300 PE", "act", now=at(9, 16, 2), px=300.0, candles={})
o2, s2 = G.gate("🟢 GO · JIOFIN ▼ PE · 09:16\n▶ BUY 300 PE", "act", now=at(9, 16, 40), px=300.0, candles={})
chk("the same P1 line twice (09:16 GO JIOFIN x2): rings once", s is False and s2 is True and "repeat" in o2, (s, s2, o2[-80:]))
o, s = G.gate("🚨 SUDDEN ▲ MCX ₹3723 · 09:21", "move", now=at(9, 21), px=3723.0, candles={})
chk("rule 3: 09:21 a SUDDEN move: silent (09:15-09:30)", s is True and "09:15-09:30" in o, o)
o, s = G.gate("🚨 CRITICAL GOVT · IRDAI · 09:22\nIRDAI final rules on commission", "move", now=at(9, 22), candles={})
chk("rule 3: 09:22 a regulator line (IRDAI): rings", s is False, o)
o, s = G.gate("📰 NEWS ▲ TITAN · RESULTS · BEAT · 09:23", "move", now=at(9, 23), px=3400.0, candles={})
chk("rule 3: 09:23 a results line: rings", s is False, o)
o, s = G.gate("🧱 CIRCUIT NEAR ▲ POWERINDIA · 09:24", "move", now=at(9, 24), px=31000.0, candles={})
chk("rule 3: 09:24 a circuit (GIR always rings it): rings", s is False, o)
o, s = G.gate("🚨 SUDDEN ▲ MCX ₹3760 · 09:31", "move", now=at(9, 31), px=3760.0, candles={})
chk("rule 3: 09:31 the same kind of line: rings again as normal", s is False, o)
o, s = G.gate("🚨 SUDDEN ▲ ABB ₹7094 · 12:40", "move", now=at(12, 40), px=7094.0, candles={})
chk("rule 4: ABB (results share): GIR's generic SUDDEN arrives silently", s is True and "special force" in o, o)
o, s = G.gate("🚨 CRITICAL · 👁 EVENT WATCH ▲ ABB · 12:41\nRESULTS WATCH · results today", "move", now=at(12, 41), px=7094.0, candles={})
chk("rule 4: the special force's 👁 EVENT WATCH on ABB rings", s is False, o)
o, s = G.gate("🚨 RESULTS REACTION ▲ ABB · 18:01", "act", now=at(18, 1), px=7100.0, candles={})
chk("rule 4: RESULTS REACTION on ABB rings (always)", s is False, o)
o, s = G.gate("🚨 SUDDEN ▲ KAYNES ₹5000 · 12:45", "move", now=at(12, 45), px=5000.0, candles={})
chk("rule 4 is for RESULTS shares only: KAYNES (an EVENTS share) rings as before", s is False, o)
G._F.clear(); open(os.path.join(T, "eventwatch.py"), "w").write("raise ImportError('x')\n"); sys.modules.pop("eventwatch", None)
o, s = G.gate("🚨 SUDDEN ▲ ABB ₹7100 · 18:30", "move", now=at(18, 30), px=7100.0, candles={})
chk("the special force cannot be read: rule 4 is off (ABB rings - nothing goes quiet by mistake)", s is False, o)
P1b = "🧩 LONG BUILD-UP ▲ ENRIN ₹3150 · 14:00\n🔴 TRADE ALERT — act on it\n⚖ VOTE 5/6 ✓ P1"
G.gate(P1b, "move", now=at(14, 0), px=3150.0, candles={})
o, s = G.gate("🚨 CRITICAL · PROFIT BOOKING ▼ ENRIN · 14:10", "move", now=at(14, 10), px=3120.0, candles={})
chk("rule 2: a P1 known by its own words (🔴 TRADE ALERT / ✓ P1) even when the level says otherwise - the warning rings", s is False and "against the 🔴 P1 at 14:00" in o, o)
P2 = "🧩 LONG BUILD-UP ▲ BEL ₹420 · 14:05\n⚖ VOTE 3/6 ✖ P2"
G.gate(P2, "move", now=at(14, 5), px=420.0, candles={})
o, s = G.gate("🚨 CRITICAL · PROFIT BOOKING ▼ BEL · 14:12", "move", now=at(14, 12), px=418.0, candles={})
chk("rule 2: a call the vote turned down (✖ P2) is not a P1 - its warning follows the old rules", s is True, o)
print("NEW RING RULES test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/replay.py <<'PY_REPLAY'
#!/usr/bin/env python3
"""replay.py - one day's real alerts through the ring rules in DIR (a test copy of the ring database; nothing sent, the live rings untouched).
python3 replay.py DIR DAY DB LABEL"""
import sys, os, json, sqlite3, collections, datetime as dt
DIR, day, db, label = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.path.insert(0, DIR); os.chdir(DIR)
import alertword, ringgov
ringgov.DB = db
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
try:
    ch = json.load(open("charts.json"))
except Exception:
    ch = {}
rang, why, kinds, keep = 0, collections.Counter(), collections.Counter(), []
for t, s, tx in rows:
    tx = "\n".join(x for x in (tx or "").split("\n") if not x.startswith("🔕 no ring") and not x.startswith("⚠ against the 🔴 P1"))
    tr = alertword.tier(tx)
    if tr == "read":
        continue
    hh, mm, ss = (int(x) for x in (str(t) + ":00")[:8].split(":"))
    now = dt.datetime.fromisoformat(day).replace(hour=hh, minute=mm, second=ss, tzinfo=IST)
    h, sym, d = ringgov.target(tx)
    cc = ch.get(sym) or {}
    C = cc.get("c") or []
    i = min(len(C), ((hh * 60 + mm) - 555) // 5)
    px = C[i - 1] if 0 < i <= len(C) and C[i - 1] else None
    out, silent = ringgov.gate(tx, tr, now=now, px=px, candles=cc)
    head = out.split("\n")[0][:70]
    if silent:
        why[out.split("\n")[-1].split("no ring - ", 1)[-1][:55]] += 1
    else:
        rang += 1; kinds[(head.split() or ["?"])[0]] += 1
        if "09:15" <= str(t)[:5] <= "15:30" and ("FIRST MOVE" in head or "against the 🔴 P1" in out):
            keep.append("%s %s%s" % (str(t)[:8], head, "  ⚠ against a P1" if "against the 🔴 P1" in out else ""))
print("   %s: %d rang" % (label, rang))
print("      by kind: " + " · ".join("%s %d" % kv for kv in kinds.most_common(10)))
print("      silent, why (top): " + " · ".join("%s %d" % (k.strip(), n) for k, n in why.most_common(6)))
if keep:
    print("      early alerts / warnings against a P1 that RING now (%d), e.g.:" % len(keep))
    for x in keep[:8]:
        print("        " + x)
PY_REPLAY
DAY=$(cd $D && python3 -c "import sqlite3;c=sqlite3.connect('file:tomorrow.db?mode=ro',uri=True);print(c.execute(\"select max(day) from alerts where t between '09:15' and '15:30'\").fetchone()[0] or '')" 2>/dev/null)
echo "=== the last trading day's real alerts ($DAY) - a test copy of the ring database; nothing sent"
[ -n "$DAY" ] && (cd $D && timeout 300 python3 $W/replay.py $D "$DAY" $W/old.db "today's rules     ") 2>&1 | tail -8
python3 $W/p249_patch.py $D || back
cd $D && python3 -m py_compile alertword.py tglanes.py ringgov.py || back
echo "=== test: the new rules on 13 Nov's situations"
python3 $W/p249test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
[ -n "$DAY" ] && (cd $D && timeout 300 python3 $W/replay.py $D "$DAY" $W/new.db "with patch 249   ") 2>&1 | tail -12
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 249 done - the early alert rings, warnings against a P1 always ring, a quiet opening, one voice on results shares. Ctrl + Shift + R on GIR."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
