#!/bin/bash
# PATCH 181 - a CRITICAL alert never drops off the page: the list kept only the 60 newest lines of the day, so by evening COCHINSHIP's
#   14:29 BIG MISS was pushed out by smaller lines. Now every critical line of the day stays + the 60 newest others.
#   gir-dash restarts (the page shows 502 for 1-3 minutes) - run it outside market hours.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35"; exit 1; fi
cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $D/p181test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p181test.py - patch 181: 1 critical line + 80 small ones -> the critical one is still on the page"""
import os, sys, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
T = tempfile.mkdtemp(); B0 = ds.BASE; ds.BASE = T
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values('2026-11-11','14:29:00','🚨','COCHINSHIP','PE',?)", ("🚨 CRITICAL RESULTS ▼ COCHINSHIP · RESULTS · BIG MISS · NSE 14:27:05\nprofit -50%",))
for i in range(80):
    c.execute("insert into alerts values('2026-11-11',?,'📰','X%d','',?)" % i, ("15:%02d:00" % (i % 60), "📰 news line %d on a share" % i))
c.commit(); c.close()
ds._tom = lambda: sqlite3.connect(os.path.join(T, "tomorrow.db"))
rows = ds.now_rows_("2026-11-11", dt.datetime(2026, 11, 11, 19, 30, tzinfo=ds.IST))
ok = any(r["s"] == "COCHINSHIP" for r in rows) and sum(1 for r in rows if r["s"] != "COCHINSHIP") == 60
print(("OK   " if ok else "FAIL ") + "COCHINSHIP's critical line kept with 80 later small lines (%d rows)" % len(rows))
ds.BASE = B0; shutil.rmtree(T)
print("P181 TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
PY_TEST
cat > $W/p181_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p181_patch.py - PATCH 181: a CRITICAL alert never drops off the page. The NOW list kept only the 60 newest lines of the day, so by
evening COCHINSHIP's 14:29 BIG MISS (the day's most important line) was pushed out by 60 smaller ones. Now: every critical line of the
day stays + the 60 newest of the rest. Usage: python3 p181_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
A = '''        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 60", (today,)):
            lines = [x for x in text.split("\\n") if x.strip()]
            out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})'''
B = '''        try:                                                     # patch 181: every CRITICAL line of the day stays, + the 60 newest others
            import tglanes as _tl
            _crit = lambda tx: _tl.lane(tx) == "critical"
        except Exception:
            _crit = lambda tx: False
        rest = 0
        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 800", (today,)):
            if not _crit(text):
                rest += 1
                if rest > 60:
                    continue
            lines = [x for x in text.split("\\n") if x.strip()]
            out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})'''
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
if "patch 181" in s:
    print("patch 181 is already in dashserve.py"); sys.exit(0)
if s.count(A) != 1:
    print("ANCHOR x%d in dashserve.py" % s.count(A)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(A, B, 1))
print("dashserve.py: critical alerts stay all day")
PY_PATCH
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; }
R=$(python3 $W/p181_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile dashserve.py || { back; echo "does not compile - old file back"; exit 1; }
timeout 120 python3 p181test.py > /tmp/p181test.log 2>&1 && echo "p181test.py passed" || { echo "TEST FAILED - old file back"; tail -3 /tmp/p181test.log; back; exit 1; }
echo -n "the page server restarting (502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "✅ the page is back" || { echo "❌ the page did not come back - old file back"; back; systemctl restart gir-dash; exit 1; }
rm -rf $W
echo "PATCH 181 APPLIED - reload girtrader.com: COCHINSHIP 14:29 is back in CRITICAL."
