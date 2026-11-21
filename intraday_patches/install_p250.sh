#!/bin/bash
# PATCH 250 - ⚡ FIRST MOVE silent again (Rama chose A, 13 Nov evening). fmaudit 13 Nov: FIRST MOVE 5x+ right after 60 min only 30% (66 rings);
#   it stays on the page and in Telegram without sound. PUSH / PULL STARTED stays silent; patch 249's rules 2-4 stay. Trade calls are not touched.
#   Then the last trading day replayed: how many would have rung. Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "_tier249" $D/alertword.py || { echo "patch 249 first"; exit 1; }
F="alertword.py ringgov.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p250_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p250_patch.py - PATCH 250: ⚡ FIRST MOVE silent again (Rama chose A, 13 Nov evening). fmaudit on 13 Nov: 86 FIRST MOVEs with volume 5x+, right
after 60 min only 30% (5-8x 34% · 8-12x 22% · 12x+ 30% · already 2%+ on the day 42%) - more rings (66) and hardly better than PUSH STARTED (26%).
FIRST MOVE stays on the page and in Telegram without sound; PUSH / PULL STARTED stays silent; patch 249's rules 2-4 stay. Usage: python3 p250_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("alertword.py", '''_tier249 = tier                                                    # patch 249 rule 1: the EARLY alert rings''',
    '''FM_RING = False                                                    # patch 250: Rama chose A (13 Nov) - FIRST MOVE right 30% -> silent again
_tier249 = tier                                                    # patch 249 rule 1: the EARLY alert rings''', "FM_RING = False")
rep("alertword.py", '''            if not op and H2.startswith("⚡ FIRST MOVE"):''', '''            if FM_RING and not op and H2.startswith("⚡ FIRST MOVE"):''', "FIRST MOVE silent again")
rep("ringgov.py", '''"PUSH / PULL STARTED was right 7 of 27 (13 Nov) - the earlier ⚡ FIRST MOVE rings instead (Rama, 13 Nov)"''',
    '''"PUSH / PULL STARTED was right 7 of 27 (13 Nov) - shown, not rung (Rama, 13 Nov)"''', "the PUSH / PULL note")
rep("home.html", '''  if(/^⚡ FIRST MOVE/.test(H)&&''', '''  if(false&&/^⚡ FIRST MOVE/.test(H)&&''', "the page: FIRST MOVE silent again (patch 250)")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 250 in")
PY_PATCH
cat > $W/p250test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p250test.py - FIRST MOVE silent again; the trade calls and patch 249's rules unchanged (temp copies, nothing sent). python3 p250test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "tglanes.py", "ringgov.py"):
    shutil.copy(os.path.join(SRC, f), T)
open(os.path.join(T, "eventwatch.py"), "w").write("def watch_list(now=None):\n    return {}\n")
json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import alertword as A, tglanes as L, ringgov as G
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); at = lambda h, m: dt.datetime(2026, 11, 16, h, m, tzinfo=IST)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:200]))
FM = "⚡ FIRST MOVE ▲ ANGELONE ₹349.25 +0.8% in 63 s · 13:51:00 · volume 8x its normal minute · day +2.4%\nWATCH — not a trade yet"
chk("FIRST MOVE (8x) is silent again", A.tier(FM) == "read", A.tier(FM))
chk("... and is not moved to GIR Box Picks", L.lane(FM) != "critical", L.lane(FM))
chk("⚡ ENTER NOW still rings as a trade call (act)", A.tier("⚡ ENTER NOW ▲ ABB CE · 10:00\n▶ BUY 7100 CE") == "act", A.tier("⚡ ENTER NOW ▲ ABB CE · 10:00\n▶ BUY 7100 CE"))
o, s = G.gate("🚨 PUSH STARTED ▲ ABB · 12:36", "move", now=at(12, 36), px=7000.0, candles={})
chk("PUSH STARTED still silent, with the new note", s is True and "shown, not rung" in o, o)
G.gate("🧩 LONG BUILD-UP ▲ NAVINFLUOR · 13:36\n🔴 TRADE ALERT — act on it\n⚖ VOTE 5/6 ✓ P1", "act", now=at(13, 36), px=10152.0, candles={})
o, s = G.gate("🚨 CRITICAL · PROFIT BOOKING ▼ NAVINFLUOR · 13:51", "move", now=at(13, 52), px=10106.0, candles={})
chk("patch 249 rule 2 unchanged: the warning against a P1 rings", s is False and "against the 🔴 P1" in o, o)
print("FIRST MOVE SILENT test: %d of %d passed" % (sum(OK), len(OK)))
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
python3 $W/p250_patch.py $D || back
cd $D && python3 -m py_compile alertword.py ringgov.py || back
echo "=== test"
python3 $W/p250test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
DAY=$(cd $D && python3 -c "import sqlite3;c=sqlite3.connect('file:tomorrow.db?mode=ro',uri=True);print(c.execute(\"select max(day) from alerts where t between '09:15' and '15:30'\").fetchone()[0] or '')" 2>/dev/null)
echo "=== $DAY replayed through the rules now (a test copy; nothing sent)"
[ -n "$DAY" ] && (cd $D && timeout 300 python3 $W/replay.py $D "$DAY" $W/new.db "rules now (249 + 250)") 2>&1 | head -3
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 250 done - FIRST MOVE silent again; trade calls, exits, warnings against a P1, results and regulator alerts ring as before."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
