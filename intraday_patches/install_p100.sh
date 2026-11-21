#!/bin/bash
# PATCH 100 - the MARKET screen's EXPIRY and PCR (on top of patch 98). This server keeps its full option chains in chains.db
#   `chain` (there is no chain15), so the F&O DESK showed expiry None / PCR None. Now it reads `chain`.
#   dashserve.py (exact anchors). Installs p100test.py. Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g100; mkdir -p $W
grep -q "def market_chain" $D/dashserve.py || { echo "patch 98 is not installed yet - paste patch 98 first"; exit 1; }
grep -q 'out\["src"\] = tb_' $D/dashserve.py && { echo "patch 100 is already installed"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/p100test.py; systemctl restart gir-dash; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p100_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p100_patch.py - PATCH 100: the MARKET screen's expiry and PCR from the chain table this server has. Patch 98 read
chains.db chain15 (the 15-min chain readings); this server has no chain15 - its full option chains are in `chain` (the
engine's readings through the day, the same columns). Now: chain15 when it is there, else chain.
Usage: python3 p100_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
OLD = '''        d = c.execute("select max(d) from chain15").fetchone()[0]
        if d:
            by = {}
            for t, k, s in c.execute("select t, kind, sum(oi) from chain15 where d=? group by t, kind", (d,)):'''
NEW = '''        tabs_ = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
        tb_ = "chain15" if "chain15" in tabs_ else "chain"            # patch 100: the full chain readings this server keeps
        out["src"] = tb_
        d = c.execute("select max(d) from %s" % tb_).fetchone()[0]
        if d:
            by = {}
            for t, k, s in c.execute("select t, kind, sum(oi) from %s where d=? group by t, kind" % tb_, (d,)):'''
OLD2 = '''            e = c.execute("select min(exp) from chain15 where d=? and exp>=?", (d, str(today))).fetchone()[0]'''
NEW2 = '''            e = c.execute("select min(exp) from %s where d=? and exp>=?" % tb_, (d, str(today))).fetchone()[0]'''
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if s.count(OLD) != 1 or s.count(OLD2) != 1:
    print("ANCHOR dashserve.py found %d / %d times (need 1 / 1) - nothing written" % (s.count(OLD), s.count(OLD2))); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(OLD, NEW, 1).replace(OLD2, NEW2, 1))
print("p100: dashserve.py  2 edits")
PY_PATCH
cat > $D/p100test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p100test.py - the MARKET screen's expiry and PCR from `chain` when there is no chain15 (a scratch chains.db)"""
import os, sys, sqlite3, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


tmp = tempfile.mkdtemp(); dashserve.BASE = tmp
c = sqlite3.connect(os.path.join(tmp, "chains.db"))
c.execute("create table chain(d text, t text, sym text, exp text, strike real, kind text, oi real, vol real, ltp real, spot real, primary key(d, t, sym, exp, strike, kind))")
c.execute("create table fo_list(sym text primary key, lot integer, updated text)")
today = dt.datetime.now(dashserve.IST).date(); d = str(today - dt.timedelta(days=1)); exp = str(today + dt.timedelta(days=18))
for t, ce, pe in (("09:30", 1000, 800), ("11:00", 1000, 900), ("13:00", 1000, 1100)):
    c.execute("insert into chain values(?,?,?,?,?,?,?,?,?,?)", (d, t, "SBIN", exp, 800, "CE", ce, 0, 5, 800))
    c.execute("insert into chain values(?,?,?,?,?,?,?,?,?,?)", (d, t, "SBIN", exp, 800, "PE", pe, 0, 5, 800))
c.commit(); c.close()
dashserve._MK["c"] = None
m = dashserve.market_chain()
check("no chain15 -> read from `chain` (%s)" % m.get("src"), m.get("src") == "chain")
check("PCR through the day %s, now %s" % (m["pcr"], m["pcr_now"]), m["pcr"] == [["09:30", 0.8], ["11:00", 0.9], ["13:00", 1.1]] and m["pcr_now"] == 1.1)
check("expiry %s, %s days left" % (m["exp"], m["days"]), m["exp"] == exp and m["days"] == 18)
print("\nP100 CHAIN TABLE TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p100_patch.py $D || { rm -f $D/p100test.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p100test.py || back
timeout 120 python3 p100test.py 2>&1 | grep "OK  \|FAIL\|TABLE TEST"
timeout 120 python3 p100test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
timeout 300 python3 p98test.py >/dev/null 2>&1 && echo "    p98test.py passed" || { echo "p98test.py failed"; back; }
systemctl restart gir-dash && sleep 10
K=$(cat $D/dash_token.txt)
curl -s --max-time 30 "http://127.0.0.1:8090/market?k=$K" | python3 -c "
import json, sys
c = (json.load(sys.stdin).get('chain') or {})
print('    from %s: expiry %s (%s days) · PCR now %s · %d readings today · results in 7 days: %d' % (c.get('src'), c.get('exp'), c.get('days'), c.get('pcr_now'), len(c.get('pcr') or []), len(c.get('results') or [])))"
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 100 APPLIED"
echo "YOUR GIR LINK (open it on the laptop / phone):"
echo "    http://64.227.155.177:8090/?k=$K"
