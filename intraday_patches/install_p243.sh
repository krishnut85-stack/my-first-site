#!/bin/bash
# PATCH 243 - EVERY F&O SHARE IN THE PRE-OPEN (Rama, 13 Nov 09:13: "AMBER is not showing in the list and a few more" - Kite: AMBER -2.46%,
#   INOXWIND -1.55%, BAJFINANCE -1.34%; GIR's movers had 52 of 218 shares). Before 09:15 GIR listed only shares whose live tick had arrived
#   (at 10:00 all 1,519 prices were there). NSE's pre-open price of every F&O share is already read at 09:08:15 (patch 176):
#   preopen.py saves it · the page server, 09:08-09:15, gives a share with no live tick yet NSE's pre-open price (a live tick always wins).
#   Tested: 7 cases. Restarts only the page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/preopen.py ] || { echo "the pre-open job (patch 176) is not on this server"; exit 1; }
F="preopen.py dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p243_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p243_patch.py - PATCH 243: EVERY F&O SHARE IN THE PRE-OPEN (Rama, 13 Nov 09:13: "AMBER is not showing in the list and a few more" - Kite showed
AMBER -2.46%, INOXWIND -1.55%, BAJFINANCE -1.34%; GIR's movers had 52 of 218 shares). Before 09:15 GIR listed only the shares whose live tick had
arrived; at 10:00 all of them were there. NSE's pre-open price of every F&O share is already read at 09:08:15 (patch 176, the 🌅 PRE-OPEN alert):
  preopen.py   also saves it (data/preopen_fo.json)
  dashserve    09:08-09:15 on that day, a share with no live tick yet takes NSE's pre-open price and % - a live tick always wins
Usage: python3 p243_patch.py DIR"""
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


rep("preopen.py", '''    po = nse_preopen(getj)
    if not po:
        return None, "NSE's pre-open list did not answer"''', '''    po = nse_preopen(getj)
    if not po:
        return None, "NSE's pre-open list did not answer"
    try:                                                        # patch 243: every F&O share's pre-open price for the page (09:08-09:15)
        p_ = os.path.join(base or os.path.dirname(os.path.abspath(__file__)), "data", "preopen_fo.json")
        json.dump({"d": str(now.date()), "t": now.timestamp(), "q": {s: [round(v[0], 2), round(v[2], 2)] for s, v in po.items()}}, open(p_ + ".tmp", "w"))
        os.replace(p_ + ".tmp", p_)
    except Exception as ex_:
        print("preopen_fo.json: %s" % ex_)''', "save every F&O share's pre-open price")
rep("dashserve.py", '''            _QL.update({"m": m, "v": {"t": j.get("t"), "q": {s: v for s, v in (j.get("q") or {}).items() if (not fo or s in fo or s == "NIFTY50")}}})''',
    '''            _QL.update({"m": m, "v": {"t": j.get("t"), "q": {s: v for s, v in (j.get("q") or {}).items() if (not fo or s in fo or s == "NIFTY50")}}})
            _preopen_fill(_QL["v"]["q"], fo)                    # patch 243''', "09:08-09:15: NSE's pre-open price for shares with no tick yet")
rep("dashserve.py", '''def quotes_live():''', '''def _preopen_fill(q, fo, now=None):
    """patch 243: 09:08-09:15 IST - a share with no live tick yet takes NSE's pre-open price (data/preopen_fo.json, today's, from preopen.py at
    09:08:15). A live tick always wins; after 09:15 nothing is added."""
    now = now or dt.datetime.now(IST)
    if not (dt.time(9, 8) <= now.time() < dt.time(9, 15)):
        return 0
    try:
        j = json.load(open(os.path.join(BASE, "data", "preopen_fo.json")))
    except Exception:
        return 0
    if j.get("d") != str(now.date()):
        return 0
    n = 0
    for s, v in (j.get("q") or {}).items():
        if s not in q and (not fo or s in fo) and v and v[0]:
            q[s] = [v[0], v[1]]; n += 1
    return n


def quotes_live():''', "_preopen_fill()")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 243 in")
PY_PATCH
cat > $W/p243test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p243test.py - every F&O share in the pre-open (13 Nov 09:13: AMBER, INOXWIND, BAJFINANCE missing). python3 p243test.py DIR - nothing sent"""
import os, sys, json, shutil, tempfile, types, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("preopen.py",):
    shutil.copy(os.path.join(SRC, f), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 13, 9, 8, 15, tzinfo=IST)
sys.path.insert(0, T); os.chdir(T)
import preopen as P
NSE = {"data": [{"metadata": {"symbol": s, "iep": iep, "previousClose": pc, "pChange": g, "finalQuantity": 1000}} for s, iep, pc, g in
       (("AMBER", 6056.0, 6209.0, -2.46), ("INOXWIND", 64.5, 65.52, -1.55), ("BAJFINANCE", 1100.0, 1115.0, -1.34), ("IDEA", 12.61, 12.97, -2.77))]}
try:
    P.build(NOW, getj=lambda path: NSE, base=T)
except Exception as ex:
    print("  (build after saving: %s)" % str(ex)[:80])
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:200]))
j = json.load(open(os.path.join(T, "data", "preopen_fo.json")))
chk("09:08:15: NSE's pre-open price of every F&O share saved (4 shares, AMBER -2.46%)", j["d"] == "2026-11-13" and len(j["q"]) == 4 and j["q"]["AMBER"] == [6056.0, -2.46], j)
src = open(os.path.join(SRC, "dashserve.py"), encoding="utf-8").read()
a = src.index("def _preopen_fill"); b = src.index("def quotes_live")
ns = {"dt": dt, "os": os, "json": json, "IST": IST, "BASE": T}
exec(src[a:b], ns); fill = ns["_preopen_fill"]
fo = {"AMBER", "INOXWIND", "BAJFINANCE", "IDEA", "NMDC"}
q = {"IDEA": [12.6, -2.85], "NMDC": [69.86, -1.7]}
n = fill(q, fo, NOW.replace(minute=13))
chk("09:13: AMBER, INOXWIND, BAJFINANCE added from NSE's pre-open (3)", n == 3 and q["AMBER"] == [6056.0, -2.46] and q["INOXWIND"] == [64.5, -1.55], q)
chk("... IDEA keeps its live tick (-2.85), not NSE's (-2.77)", q["IDEA"] == [12.6, -2.85], q["IDEA"])
q2 = {"IDEA": [12.66, -2.39]}
chk("10:00: nothing added (the live ticks only)", fill(q2, fo, NOW.replace(hour=10, minute=0)) == 0 and list(q2) == ["IDEA"], q2)
q3 = {}
chk("09:05 (before the auction ends): nothing added", fill(q3, fo, NOW.replace(minute=5)) == 0)
q4 = {}
chk("next trading day 09:10: yesterday's file not used", fill(q4, fo, NOW + dt.timedelta(days=3, minutes=2)) == 0)
q5 = {}
chk("not an F&O share: not added", fill(q5, {"AMBER"}, NOW.replace(minute=10)) == 1 and list(q5) == ["AMBER"], q5)
print("PRE-OPEN FILL test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p243_patch.py $D || back
cd $D && python3 -m py_compile preopen.py dashserve.py || back
echo "=== test: the pre-open fill"
python3 $W/p243test.py $D || back
echo "=== NSE's pre-open list today, read once (nothing sent):"
cd $D && timeout 60 python3 -c "
import sys, json, datetime as dt; sys.path.insert(0, '$D')
import preopen
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); now = dt.datetime.now(IST)
po = preopen.nse_preopen()
print('   NSE answered with %d F&O shares%s' % (len(po), (' · e.g. ' + ' · '.join('%s %+.2f%%' % (s, po[s][2]) for s in ('AMBER', 'INOXWIND', 'BAJFINANCE') if s in po)) if po else ' - it may not answer outside the morning; the 09:08 job will fill it'))
" 2>&1 | tail -2
systemctl restart gir-dash 2>/dev/null; sleep 4; echo "  gir-dash: $(systemctl is-active gir-dash)"
echo "✅ patch 243 done - from the next trading day, 09:08-09:15 every F&O share shows its pre-open price."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
