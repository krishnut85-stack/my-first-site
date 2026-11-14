#!/bin/bash
# PATCH 130c - ONLY F&O SHARES RING (on top of patch 130b).
#   In the Muhurat session GIR rang 🚀 RUNNING for FINCABLES, BBOX, SHYAMMETL, VEDPOWER - not F&O shares. The tick agents'
#   F&O filter was left empty by the mid-session start, and empty meant "every share". Now every RUNNING / SPEED /
#   FIRST MOVE / ORDER BOOK line is checked against the F&O list right before it is sent, and the filter is set first.
#   engine2.py (exact anchors). In a session the engine is restarted only with:  bash install_p130c.sh now
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g130c; mkdir -p $W
grep -q "patch 130b" $D/engine2.py 2>/dev/null || { echo "patch 130b is not installed yet - paste patch 130b first"; exit 1; }
grep -q "def _fo_ok" $D/engine2.py && { echo "patch 130c is already installed"; exit 1; }
cp $D/engine2.py $D/engine2.py.bak$TS
back() { cp $D/engine2.py.bak$TS $D/engine2.py; rm -f $D/p130ctest.py; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p130c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p130c_patch.py - PATCH 130c: ONLY F&O SHARES RING. In the Muhurat session (8 Nov 2026) GIR rang 🚀 RUNNING for FINCABLES,
BBOX, SHYAMMETL, VEDPOWER - not F&O. The tick agents filter on an F&O list set at start-up, and an EMPTY list meant "every
share"; the mid-session start left it empty. Now (1) the list is set first, on its own; (2) every RUNNING / SPEED / FIRST MOVE /
ORDER BOOK line is checked against the F&O list (chains.db fo_list) right before it is sent.
Usage: python3 p130c_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''
def first_move_sender(feed):
''', '''
_FOK = {"t": 0.0, "s": set()}


def _fo_ok(sym):
    """patch 130c: only F&O shares ring (the F&O list, re-read every 10 min; no list readable at all -> as before)"""
    if time.time() - _FOK["t"] > 600 or not _FOK["s"]:
        try:
            c_ = chains.db(); s_ = {r[0] for r in c_.execute("select sym from fo_list")}; c_.close()
            if s_:
                _FOK["s"] = s_
            _FOK["t"] = time.time()
        except Exception as ex:
            log("F&O list: %s" % str(ex)[:80])
    return (sym in _FOK["s"]) if _FOK["s"] else True


def first_move_sender(feed):
'''),
        ('''                tg_gate("firstmove", s_, side_, txt_, exempt=True, dup_s=1200)''',
         '''                if _fo_ok(s_):                                  # patch 130c: F&O shares only
                    tg_gate("firstmove", s_, side_, txt_, exempt=True, dup_s=1200)'''),
        ('''                tg_gate(("run%d" % int(step_)) if kind_ == "step" else "speed", s_, side_, surge_text(rec_, hm_), exempt=True, dup_s=86400 if kind_ == "step" else 900)''',
         '''                if _fo_ok(s_):                                  # patch 130c: F&O shares only
                    tg_gate(("run%d" % int(step_)) if kind_ == "step" else "speed", s_, side_, surge_text(rec_, hm_), exempt=True, dup_s=86400 if kind_ == "step" else 900)'''),
        ('''                tg_gate("book", s_, side_, txt_, exempt=True, dup_s=1200)''',
         '''                if _fo_ok(s_):                                  # patch 130c: F&O shares only
                    tg_gate("book", s_, side_, txt_, exempt=True, dup_s=1200)'''),
        ('''        try:
            feed.vnorm = engine.first_move_norms(feed.syms)
            feed.fo_idx = {feed.pos[s_] for s_ in _fo if s_ in feed.pos}
''', '''        try:                                               # patch 130c: the F&O filter first, on its own (an empty one = every share)
            _fo_ok("")
            feed.fo_idx = {feed.pos[s_] for s_ in (_FOK["s"] or set(_fo)) if s_ in feed.pos}
        except Exception as ex:
            log("F&O filter: %s" % str(ex)[:80])
        try:
            feed.vnorm = engine.first_move_norms(feed.syms)
'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("engine2.py: only F&O shares ring (RUNNING · SPEED · FIRST MOVE · ORDER BOOK)")
PY_PATCH
cat > $D/p130ctest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p130ctest.py - only F&O shares ring: FINCABLES / BBOX (not F&O) are held, YESBANK (F&O) goes. Fake files only."""
import os, sys, sqlite3, tempfile, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import engine2, chains
tmp = tempfile.mkdtemp(prefix="p130c")
try:
    p = os.path.join(tmp, "chains.db")
    c = sqlite3.connect(p); c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,1)", [("YESBANK",), ("SIEMENS",)]); c.commit(); c.close()
    chains.db = lambda: sqlite3.connect(p)
    engine2._FOK.update({"t": 0.0, "s": set()})
    check("YESBANK, SIEMENS (F&O) ring; FINCABLES, BBOX, SHYAMMETL, VEDPOWER (not F&O) do not",
          engine2._fo_ok("YESBANK") and engine2._fo_ok("SIEMENS") and not any(engine2._fo_ok(s) for s in ("FINCABLES", "BBOX", "SHYAMMETL", "VEDPOWER")))
    chains.db = lambda: (_ for _ in ()).throw(RuntimeError("locked"))
    engine2._FOK["t"] = 0.0
    check("the list cannot be re-read for a moment: the last good list still holds", engine2._fo_ok("YESBANK") and not engine2._fo_ok("FINCABLES"))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
check("RUNNING / SPEED, FIRST MOVE and ORDER BOOK lines all pass the F&O check before they are sent", src.count("if _fo_ok(s_):") == 3)
print("\nP130C F&O ONLY TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p130c_patch.py $D || { rm -f $D/p130ctest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py p130ctest.py || back
timeout 60 python3 p130ctest.py 2>&1 | grep "OK  \|FAIL\|ONLY TEST"
timeout 60 python3 p130ctest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p130btest.py p130test.py p88test.py p114test.py p124test.py p80test.py p119test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo
INSESSION=$(cd $D && python3 -c "
import sessions, datetime as dt
n = dt.datetime.now(sessions.IST); s = sessions.session(n.date())
print(1 if s and sessions.at(n.date(), s['open']) - dt.timedelta(minutes=40) <= n <= sessions.at(n.date(), s['close']) + dt.timedelta(minutes=10) else 0)")
if [ "$INSESSION" = "1" ] && [ "$1" != "now" ]; then
  echo "PATCH 130c APPLIED. A session is running - the engine is left alone; the F&O-only rule starts with its next run."
  echo "To apply it right now (the engine is back live in ~2-3 min):  systemctl restart gir-intraday"
else
  systemctl restart gir-intraday && sleep 10
  [ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
  echo "PATCH 130c APPLIED. The engine restarted - only F&O shares ring now."
fi
