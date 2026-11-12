#!/bin/bash
# PATCH 229 - YOUR RULE rings only when it agrees with a GIR alert (Rama, 12 Nov: "ok step 1 now"; the replay: YOUR RULE 101 rings, 88 with
#   patch 228). A rule of yours rings when GIR rang on the same share, the same way, in the last 15 min ("✔ agrees with GIR's 🧩 at 10:21");
#   otherwise it comes without sound, marked 🔕 (still in Telegram and on the page). Tested: the ring-rules cases (14); then TODAY's alerts
#   replayed again (before / after). Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/ringgov.py ] || { echo "patch 228 first"; exit 1; }
cp $D/ringgov.py $D/ringgov.py.bak$TS
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
back(){ cp $D/ringgov.py.bak$TS $D/ringgov.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p229_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p229_patch.py - PATCH 229: YOUR RULE rings only when it agrees with a GIR alert (Rama, 12 Nov: "ok step 1 now" - the replay: YOUR RULE rang
101 times, 88 with patch 228's "once a share in 30 min"). A rule of yours now rings only when GIR rang on the same share, the same side (or no
side), in the last 15 min - then it says "✔ agrees with GIR's ... at HH:MM". Otherwise it comes without sound, marked 🔕. Usage: python3 p229_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "ringgov.py"); s = open(p, encoding="utf-8").read()
OLD = '''            if not last_yr:
                return ring(text)
            return _quiet(text, "your rules already rang on %s at %s (one ring in 30 min unless it agrees with a GIR alert)" % (sym, _hm(last_yr[0])))'''
NEW = '''            return _quiet(text, "your rule - it rings when it agrees with a GIR alert on %s (none the same way in the last 15 min)" % sym)   # patch 229'''
if NEW in s:
    print("  ringgov.py: YOUR RULE rings only when it agrees - already in")
elif s.count(OLD) == 1:
    s = s.replace(OLD, NEW).replace('''  2 YOUR RULE rings when it agrees with a GIR alert on the share (same side, within 15 min), or when it is the first of your rules on the
    share in 30 min''', '''  2 YOUR RULE rings only when it agrees with a GIR alert on the share (same side, within 15 min) - patch 229''')
    open(p, "w", encoding="utf-8").write(s); print("  ringgov.py: YOUR RULE rings only when it agrees")
else:
    print("❌ ringgov.py: the anchor is not there (patch 228 first)"); sys.exit(1)
print("patch 229 in")
PY_PATCH
cat > $W/p228test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p228test.py - THE RING RULES on 12 Nov's real cases (made-up files, temp folder, nothing sent).  python3 p228test.py DIR  (DIR: alertword.py, ringgov.py)"""
import os, sys, json, shutil, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "ringgov.py"):
    shutil.copy(os.path.join(D, f), T)
sys.path.insert(0, T); os.chdir(T)
import ringgov as G, alertword as A
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); DAY = dt.datetime(2026, 11, 12, tzinfo=IST)
at = lambda h, m, s=0: DAY.replace(hour=h, minute=m, second=s)
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))
def g(text, when, px=None, candles=None):
    t, silent = G.gate(text, A.tier(text), now=when, px=px, candles=candles or {})
    return t, silent
print("1 · one ring a share every 15 min")
r = [g("🚨 CRITICAL · THE REASON ▼ PAGEIND · 14:30", at(14, 30, 30), 35825), g("⚠️ SHOCK WATCH · ▼ PAGEIND · RESULTS · news 14:31", at(14, 31, 12), 35465),
     g("🧱 CIRCUIT ▼ PAGEIND ₹32915 · AT THE LOWER CIRCUIT (₹32915)", at(14, 36, 46), 32915), g("⚠️ SHOCK WATCH · ▼ PAGEIND · RESULTS · news 14:50", at(14, 50, 0), 32070)]
chk("PAGEIND: the first rings, the next in 15 min arrive silently (🔕 says why), 🧱 CIRCUIT always rings, 14:50 rings again", [x[1] for x in r] == [False, True, False, True] and "🔕 no ring - PAGEIND rang at 14:30" in r[1][0], [x[1] for x in r])
print("2 · ALWAYS RING")
t, s = g("🚨 CRITICAL · RESULTS REACTION ▼ PAGEIND · 14:31\n▶ BUY PE (at the money) - ▼ DOWN → PE · stop: a close over ₹36,500", at(14, 31, 30), 35000)
chk("🚨 RESULTS REACTION rings even 1 min after a PAGEIND ring", not s, t)
t, s = g("🚨 CRITICAL · 🛑 EXIT - STOP · PAGEIND PE · 14:32\nwhy: ...", at(14, 32), 35000)
chk("🛑 EXIT rings even 2 min after", not s)
t1, s1 = g("🟢 GO · SWIGGY ▲ CE · 10:00\nBUY: 300 CE ₹8", at(10, 0), 300); t2, s2 = g("⚡ ENTER NOW ▲ SWIGGY CE · ₹301 · 10:02\n▶ BUY 300 CE ₹8.5", at(10, 2), 301)
chk("P1 calls ring every time (SWIGGY 10:00 and 10:02)", not s1 and not s2)
t, s = g("📄 MARKET NEWS · MARKET · The Times of India 04:32", at(10, 5))
chk("a market-wide alert (no share) rings as before", not s)
print("3 · YOUR RULE rings only when it agrees with a GIR alert (patch 229)")
y1 = g('📒 YOUR RULE "roof breaking - writers running" · SBILIFE ₹1805.3 +2.2% · 10:00\n→ CE', at(10, 0), 1805.3)
y2 = g('📒 YOUR RULE "big money buying futures" · SBILIFE ₹1808 +2.4% · 10:10\n→ CE', at(10, 10), 1808)
p2 = g("🚨 CRITICAL · PUSH STARTED ▲ SBILIFE · 10:16", at(10, 16), 1812)
y3 = g('📒 YOUR RULE "roof breaking - writers running" · SBILIFE ₹1815 +2.8% · 10:20\n→ CE', at(10, 20), 1815)
chk("a YOUR RULE on SBILIFE with no GIR alert there: silent (patch 229 - it rings only when it agrees)", y1[1] and "it rings when it agrees with a GIR alert on SBILIFE" in y1[0], y1)
chk("the second 10 min later: silent too", y2[1], y2)
chk("... GIR's own alert on SBILIFE at 10:16 rings (nothing rang there before)", not p2[1], p2)
p3 = g("🧩 LONG BUILD-UP ▲ SBILIFE ₹1816 +2.9% · 10:21\n▶ WATCH CE 1820", at(10, 21), 1816)
G_ = G._db(); G_.execute("insert into rings values (?, 'SBILIFE', 1, '🧩', 1816, 0)", (at(10, 21).timestamp(),)); G_.commit(); G_.close()   # a GIR alert on SBILIFE rang (e.g. P2 critical)
y4 = g('📒 YOUR RULE "big money buying futures" · SBILIFE ₹1818 +3.0% · 10:24\n→ CE', at(10, 24), 1818)
chk("a YOUR RULE that agrees with a GIR alert on SBILIFE (▲, 3 min before) rings, with '✔ agrees with'", not y4[1] and "✔ agrees with GIR's" in y4[0], y4)
print("4 · the contradiction guard")
b1 = g("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS · NSE 13:54", at(13, 46), 1063.95)
flat = {"o": [1064.0] * 35, "c": [1063.0] * 35}
b2 = g('📒 YOUR RULE "rising fast" ▲ BDL ₹1063.95 · 13:55\n→ CE', at(13, 55), 1063.95, flat)
chk("BDL ▼ at 13:46 then ▲ at 13:55, no candle confirms: silent (🔕 the other way within 30 min)", b2[1] and "the other way within 30 min of the ▼ at 13:46 on BDL" in b2[0], b2)
h1 = g("🚀 RUNNING ▼ HAL ₹4000 -1.5% · 13:25", at(13, 25), 4000.0)
turn = {"o": [3990.0] * 34 + [4005.0], "c": [3990.0] * 34 + [4030.0]}          # the 13:45 candle (index 34) closed green, +0.75% from 4000
h2 = g("🚀 RUNNING ▲ HAL ₹4032 +0.8% · 13:50", at(13, 50), 4032.0, turn)
chk("HAL ▼ at 13:25 then ▲ at 13:50 with a green 5-min candle +0.75%: rings with ⚠ REVERSAL", not h2[1] and "⚠ REVERSAL - at 13:25 you got ▼ on HAL" in h2[0], h2)
print("5 · through alertword.dress (what every sender calls)")
chk("the share is read right from real heads (▼ BDL · RESULTS · BIG MISS -> BDL)", G.target("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS")[1:] == ("BDL", -1), G.target("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS"))
x1 = A.dress("🚨 CRITICAL · PUSH STARTED ▲ TESTSYM · now"); x2 = A.dress("⚠️ SHOCK WATCH · ▲ TESTSYM · ORDER · news now")
chk("dress: the first rings, a repeat seconds later is silent and marked 🔕", x1[1] is False and x2[1] is True and "🔕 no ring" in x2[0], (x1[1], x2[1]))
q = A.dress("🔍 WHY ▲ BAJFINANCE +2.7% · CLEAR")
chk("dress: a quiet line stays quiet (as before)", q[1] is True and "🔕" not in q[0], q)
print("RING RULES test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p229_patch.py $D || back
cd $D && python3 -m py_compile ringgov.py || back
echo "=== test: the ring rules (YOUR RULE now rings only when it agrees)"
python3 $W/p228test.py $D || back
echo "=== TODAY's real alerts replayed through the ring rules (a test copy - the live rings are not touched)"
cd $D && python3 - "$(TZ=Asia/Kolkata date +%F)" "$W/replay.db" <<'PY'
import sys, json, sqlite3, collections, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
import alertword, ringgov
day, ringgov.DB = sys.argv[1], sys.argv[2]
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
ch = json.load(open("charts.json"))
before, after, keep, held = collections.Counter(), collections.Counter(), [], []
kb, ka = collections.Counter(), collections.Counter()
rev = 0
for t, s, tx in rows:
    tx = tx or ""
    tr = alertword.tier(tx)
    if tr == "read":
        continue
    h, sym, d = ringgov.target(tx)
    k = (tx.split() or ["?"])[0]
    before[sym or "-"] += 1; kb[k] += 1
    hh, mm, ss = (int(x) for x in (str(t) + ":00")[:8].split(":"))
    now = dt.datetime.fromisoformat(day).replace(hour=hh, minute=mm, second=ss, tzinfo=IST)
    cc = ch.get(sym) or {}
    C = cc.get("c") or []
    i = min(len(C), ((hh * 60 + mm) - 555) // 5)
    px = C[i - 1] if 0 < i <= len(C) and C[i - 1] else None
    out, silent = ringgov.gate(tx, tr, now=now, px=px, candles=cc)
    if silent:
        held.append((str(t)[:5], out.split("\n")[0][:60], out.split("\n")[-1][2:80]))
    else:
        after[sym or "-"] += 1; ka[k] += 1
        rev += "⚠ REVERSAL" in out
nb, na = sum(before.values()), sum(after.values())
print("   rang today: %d  ->  with the rules: %d  (%d arrive silently, marked 🔕) · %d REVERSAL rings" % (nb, na, nb - na, rev))
print("   by kind (before -> after): " + " · ".join("%s %d->%d" % (k, n, ka[k]) for k, n in kb.most_common(10)))
print("   the busiest shares (before -> after): " + " · ".join("%s %d->%d" % (s, n, after[s]) for s, n in before.most_common(10) if s != "-"))
prot = sum(1 for t, s, tx in rows if alertword.tier(tx or "") == "act" or ringgov.PROTECT.search(ringgov.target(tx or "")[0]))
print("   always ringing (P1, results reaction, exits, GIR alarms): %d - none of them held" % prot)
print("   a few that would have come silently:")
for x in held[:10]:
    print("     %s %-60s %s" % x)
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 229 done - your rules ring only when GIR agrees on the share; the rest arrive silently (🔕)."
echo "   undo: cp $D/ringgov.py.bak$TS $D/ringgov.py; systemctl restart $SV"
