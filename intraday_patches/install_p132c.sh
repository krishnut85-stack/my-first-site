#!/bin/bash
# PATCH 132c - ⚡ EARLY: F&O SHARES ONLY (on top of patch 132b).
#   The ⚡ EARLY board listed 1002 shares (every share with a news line in the day's log) - now only NSE's F&O shares.
#   girlook: a strike NSE opened after the last close is "new" on the page, not a fault.
#   dashserve.py, girlook.py (exact anchors), p119test.py (its sample F&O list). Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g132c; mkdir -p $W
[ -f $D/girlook.py ] || { echo "patch 132b is not installed yet - paste patch 132b first"; exit 1; }
grep -q "patch 132c" $D/dashserve.py && { echo "patch 132c is already installed"; exit 1; }
F="dashserve.py girlook.py p119test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p132ctest.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p132c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p132c_patch.py - PATCH 132c: ⚡ EARLY listed 1002 shares (every share with a news line in the day's log) -> only NSE's F&O
shares (the list the engine reads from Kite every day); girlook: a strike NSE did not list at the last close is "new", not a fault.
Usage: python3 p132c_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "dashserve.py": [
        ('''    by = {}
    for t, kind, sym, side, text in rows:
        if not sym or sym == "MARKET" or side not in ("CE", "PE"):
            continue''', '''    by = {}
    try:
        fo_ = fo_set()                                          # patch 132c: F&O shares only (it listed 1002 shares)
    except Exception:
        fo_ = set()
    for t, kind, sym, side, text in rows:
        if not sym or sym == "MARKET" or side not in ("CE", "PE"):
            continue
        if fo_ and sym not in fo_:
            continue'''),
    ],
    "p119test.py": [
        ('''    c.executemany("insert into fo_list values(?,?)", [("ASTRAL", 425), ("COROMANDEL", 700)])''',
         '''    c.executemany("insert into fo_list values(?,?)", [("ASTRAL", 425), ("COROMANDEL", 700), ("TITAN", 175), ("LUPIN", 425), ("DIXON", 50), ("NBCC", 6500)])   # patch 132c: EARLY lists F&O shares only'''),
    ],
    "girlook.py": [
        ('''    say(bool(rows_) and len(miss) <= 2, "OI BUILD-UP / chain",''', '''    say(bool(rows_) and (len(miss) <= 2 or bool(o.get("prev_full"))), "OI BUILD-UP / chain",'''),
        ('''"" if sidx else " - the column shows — (fixed in 132b: kept after 15:30)"''', '''"" if sidx else " - the column shows — (132b keeps them after 15:30: from the next session's close)"'''),
        ('''        "yes" if o.get("prev_full") else "no"))''', '''        "yes (a strike not in it = NSE opened it since: the page shows 'new')" if o.get("prev_full") else "no"))'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p132ctest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p132ctest.py - ⚡ EARLY lists NSE's F&O shares only (a news line on a share outside F&O stays out)."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import dashserve
IST = dashserve.IST
tmp = tempfile.mkdtemp(prefix="p132c")
base0 = dashserve.BASE
try:
    dashserve.BASE = tmp
    today = dt.datetime.now(IST).strftime("%Y-%m-%d")
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    c.executemany("insert into alerts values(?,?,?,?,?,?)", [
        (today, "09:16:05", "🚨", "ASTRAL", "PE", "🚨 CRITICAL NEWS ▼ ASTRAL · REG · Reuters 09:16\nUSFDA warning letter\nthe reader (x): a warning letter · CRITICAL · sure 92%"),
        (today, "09:20:00", "🚨", "SMALLCO", "PE", "🚨 CRITICAL NEWS ▼ SMALLCO · REG · x 09:20\nraid\nthe reader (x): a raid · CRITICAL · sure 95%"),
        (today, "10:00:00", "📰", "TINYLTD", "CE", "📰 NEWS ▲ TINYLTD · ORDER · x 10:00\norder\nthe reader (x): an order · IMPORTANT · sure 80%")])
    c.commit(); c.close()
    c = sqlite3.connect(os.path.join(tmp, "chains.db"))
    c.execute("create table fo_list(sym text, lot int)"); c.execute("insert into fo_list values('ASTRAL', 425)"); c.commit(); c.close()
    dashserve.live_obj = lambda: {"fo_paths": []}
    dashserve.quotes_live = lambda: {"t": time.time(), "q": {}}
    dashserve._FOS.update({"t": 0.0, "v": None})                 # the F&O list read fresh from this test's chains.db
    E = dashserve.early(fresh=True)
    got = sorted(r["s"] for r in E.get("rows") or [])
    check("EARLY: ASTRAL (F&O) in, SMALLCO / TINYLTD (not F&O) out: %s" % got, got == ["ASTRAL"])
finally:
    dashserve.BASE = base0
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP132C F&O ONLY TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p132c_patch.py $D || { rm -f $D/p132ctest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py girlook.py p132ctest.py || back
timeout 60 python3 p132ctest.py 2>&1 | grep "OK  \|FAIL\|P132C"
timeout 60 python3 p132ctest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p119test.py p132btest.py p132test.py p129test.py p120test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo
echo "PATCH 132c APPLIED. Reload the GIR page. The report again:"
echo
cd $D && timeout 120 python3 girlook.py DIVISLAB 2>&1 | grep -v "^  OK    key:"
