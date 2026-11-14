#!/bin/bash
# PATCH 125c - RESULTS PDFS WITHOUT A UNIT ARE READ (on top of patch 125b).
#   Tata Steel's 7 Nov PDF printed "64,973.97" with no "₹ crore": GIR read the right numbers but took them as rupees
#   (revenue ₹0 cr) and threw them away. Now the unit is worked out from the size, and the line says it was assumed.
#   Also: pre-tax profit alone is no longer labelled "EBITDA margin". Then re-reads the last 3 days of unread results.
#   exchange.py (exact anchors). Restarts gir-exchange.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g125c; mkdir -p $W
grep -q "CRITICAL RESULTS" $D/exchange.py 2>/dev/null || { echo "patch 125b is not installed yet - paste patch 125b first"; exit 1; }
grep -q "patch 125c" $D/exchange.py && { echo "patch 125c is already installed"; exit 1; }
cp $D/exchange.py $D/exchange.py.bak$TS
back() { cp $D/exchange.py.bak$TS $D/exchange.py; rm -f $D/p125ctest.py; systemctl restart gir-exchange; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p125c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p125c_patch.py - PATCH 125c: a results PDF that does not print its unit (TATA STEEL 7 Nov: "64,973.97") was read as
rupees -> "revenue ₹0.0 cr" -> the sanity check threw the right numbers away. Now the unit is worked out from the size:
10 - 4,00,000 = ₹ crore (no listed company sells more than ₹4 lakh cr a quarter), up to 4 crore = ₹ lakh; the line says so.
Usage: python3 p125c_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "exchange.py": [
        ('''    unit = res.get("unit", "?")
''', '''    unit = res.get("unit", "?")
    guessed = False
    if unit not in ("lakh", "crore", "million") and rev.get("cur") is not None:     # patch 125c: the PDF did not print its unit
        r0 = abs(rev["cur"])
        if 10 <= r0 <= 400000:
            unit, guessed = "crore", True
        elif 400000 < r0 <= 4e7:
            unit, guessed = "lakh", True
'''),
        ('''    if pbx is None:
        return None
    return pbx + (fin or 0) + (dep or 0)
''', '''    if pbx is None or (fin is None and dep is None):   # patch 125c: pre-tax profit alone is not EBITDA (TATA STEEL read "EBITDA 7.9%", the real one ~16%)
        return None
    return pbx + (fin or 0) + (dep or 0)
'''),
        ('''    basis = pat.get("basis") or rev.get("basis") or ""
''', '''    basis = (pat.get("basis") or rev.get("basis") or "") + (" · ₹ %s assumed - the PDF did not say" % unit if guessed else "")   # patch 125c
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
print("exchange.py: a results table without its unit is read (₹ crore / lakh from the size)")
PY_PATCH
cat > $D/p125ctest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p125ctest.py - TATA STEEL's 7 Nov results PDF printed no unit: the numbers are read, not thrown away. Sample numbers only."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import exchange
T = {"src": "pdf", "unit": "?", "basis": None, "rev": {"cur": 64973.97, "qoq": 60411.78, "yoy": 58216.04, "basis": "consolidated"},
     "pat": {"cur": 3699.59, "qoq": 2385.24, "yoy": 3183.09, "basis": "consolidated"}, "opp": None, "pbx": {"cur": 5106.47, "qoq": 4183.01, "yoy": 4642.88, "basis": "consolidated"}}
v, side, line = exchange.judge(T)
check("TATA STEEL (no unit on the PDF): %s %+d · %s" % (v, side, line[:150]), v == "BEAT" and side == 1 and "₹64,974 cr" in line and "₹3,700 cr" in line and "crore assumed" in line)
L = dict(T, rev={"cur": 6497397.0, "yoy": 5821604.0, "qoq": 6041178.0}, pat={"cur": 369959.0, "yoy": 318309.0, "qoq": 238524.0}, pbx=None)
v2, s2, line2 = exchange.judge(L)
check("the same table in ₹ lakh: read as lakh (₹64,974 cr): %s" % line2[:80], v2 == "BEAT" and "₹64,974 cr" in line2 and "lakh assumed" in line2)
X = dict(T, rev={"cur": 0.5, "yoy": 0.4, "qoq": 0.45}, pat={"cur": 0.1, "yoy": 0.08, "qoq": 0.09}, pbx=None)
check("pre-tax profit alone is not called EBITDA: %s" % line[line.find("YoY ·", 60):][:60], "EBITDA" not in line)
check("a wrong line off a PDF (revenue 0.5) still fails the sanity check", exchange.judge(X)[0] == "NUMBERS NOT READ")
C = dict(T, unit="crore", basis=None)
check("a table that says ₹ crore is read as before (no 'assumed')", "assumed" not in exchange.judge(C)[2])
print("\nP125C UNIT TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p125c_patch.py $D || { rm -f $D/p125ctest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile exchange.py p125ctest.py || back
timeout 120 python3 p125ctest.py 2>&1 | grep "OK  \|FAIL\|UNIT TEST"
timeout 120 python3 p125ctest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p125btest.py p118test.py p124test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-exchange && sleep 10
[ "$(systemctl is-active gir-exchange)" = "active" ] || { echo "gir-exchange did not come back"; back; }
echo
echo "PATCH 125c APPLIED. Re-reading the results of the last 3 days that were not read:"
cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 exchange.py --reread 3 --failed 2>&1 | grep -v "^20[0-9][0-9]-"
python3 - <<'PY'
import exchange
for s in ("TATASTEEL", "COROMANDEL", "GODFRYPHLP"):
    r = exchange.results_read(s, 24 * 4)
    if r:
        print("  %-11s %-17s %s" % (s, ("BIG " if (r.get("read") or {}).get("big") else "") + r["verdict"] + (" ▲" if r["side"] > 0 else " ▼" if r["side"] < 0 else ""), r["line"][:150]))
PY
