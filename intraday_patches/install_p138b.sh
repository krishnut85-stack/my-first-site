#!/bin/bash
# PATCH 138b - THE RESULTS DATE OF EVERY F&O SHARE (on top of patch 138).
#   JIOFIN's results of 16 Oct passed the old-results check: GIR had no date for them. NSE's own list of each share's quarterly
#   results now gives it: all F&O shares once (in the background, ~5 min), and any share the gate meets without a date, on the spot.
#   newsfresh.py, p138test.py (exact anchors). Restarts gir-newsroom and gir-exchange only (the engine is not touched).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g138b; mkdir -p $W
grep -q "patch 138" $D/newsfresh.py 2>/dev/null || { echo "patch 138 is not installed yet - paste patch 138 first"; exit 1; }
grep -q "patch 138b" $D/newsfresh.py && { echo "patch 138b is already installed"; exit 1; }
F="newsfresh.py p138test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p138btest.py; systemctl restart gir-newsroom gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p138b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p138b_patch.py - PATCH 138b: THE RESULTS DATE OF EVERY F&O SHARE. JIOFIN's results of 16 Oct passed the old-results check: GIR
had no date for them (the exchange reader keeps filings only since it started). NSE's own list of each share's quarterly results
now fills data/results_dates.json - all F&O shares once (python3 newsfresh.py --results-dates), and any share the gate meets
without a date, on the spot (kept 12 h).
Usage: python3 p138b_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "newsfresh.py": [
        ('''    ts = [t for t in ts if t <= now + 3600]
    return max(ts) if ts else None''', '''    rd = _rdates()                                              # patch 138b: NSE's own list of the share's results
    e = rd.get(sym)
    if e is None or (not e.get("t") and time.time() - float(e.get("at") or 0) > 12 * 3600):
        if NSE_ASK:
            e = fetch_results_date(sym)
    if e and e.get("t"):
        ts.append(float(e["t"]))
    ts = [t for t in ts if t <= now + 3600]
    return max(ts) if ts else None


RDATES = os.path.join(BASE, "data", "results_dates.json")
NSE_ASK = True                                                  # tests switch it off
_RD = {"m": None, "v": {}}


def _rdates():
    p = os.path.join(BASE, "data", "results_dates.json")
    try:
        m = os.path.getmtime(p)
        if m != _RD["m"]:
            _RD["v"], _RD["m"] = json.load(open(p)), m
    except Exception:
        pass
    return _RD["v"]


def fetch_results_date(sym):
    """NSE's list of the share's quarterly results -> {"t": the latest filing (epoch) or None, "at": when asked}; saved"""
    e = {"t": None, "at": time.time()}
    try:
        import expect
        h = expect.nse_history(sym, 1)
        if h:
            e["t"] = float(h[0][0])
    except Exception as ex:
        e["err"] = str(ex)[:80]
    p = os.path.join(BASE, "data", "results_dates.json")
    try:
        cur = dict(_rdates())
        cur[sym] = e
        os.makedirs(os.path.dirname(p), exist_ok=True)
        json.dump(cur, open(p + ".tmp", "w")); os.replace(p + ".tmp", p)
        _RD.update({"v": cur, "m": os.path.getmtime(p)})
    except Exception:
        pass
    return e'''),
        ('''    if len(sys.argv) > 1 and sys.argv[1] == "--held":''', '''    if len(sys.argv) > 1 and sys.argv[1] == "--results-dates":     # patch 138b: every F&O share's latest results date, from NSE
        fo = sorted(fo_set())
        n = 0
        for i, s in enumerate(fo):
            e = fetch_results_date(s)
            n += 1 if e.get("t") else 0
            if i % 25 == 0:
                print("  %d / %d shares read, %d with a date" % (i + 1, len(fo), n), flush=True)
        print("results dates: %d of %d F&O shares" % (n, len(fo)))
    elif len(sys.argv) > 1 and sys.argv[1] == "--held":'''),
    ],
    "p138test.py": [
        ('''import newsfresh
IST = newsfresh.IST''', '''import newsfresh
IST = newsfresh.IST
newsfresh.NSE_ASK = False                                      # patch 138b: no NSE in the test'''),
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
cat > $D/p138btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p138btest.py - JIOFIN's results of 16 Oct: no filing in GIR's own records -> NSE's results list gives the date (a fake NSE) ->
the results story of 16 Oct is held; asked once (kept), a share NSE has nothing for passes."""
import os, sys, json, time, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import newsfresh, expect
IST = newsfresh.IST
tmp = tempfile.mkdtemp(prefix="p138b")
try:
    newsfresh.BASE = tmp; newsfresh.HELD = os.path.join(tmp, "data", "news_held.json"); os.makedirs(os.path.join(tmp, "data"))
    newsfresh._FO.update({"t": time.time(), "v": {"JIOFIN", "TCS"}}); newsfresh._RD.update({"m": None, "v": {}}); newsfresh.NSE_ASK = True
    ASKED = []
    t16 = dt.datetime(2026, 10, 16, 11, 13, tzinfo=IST).timestamp()
    expect.nse_history = lambda sym, q: (ASKED.append(sym), [(t16, {})] if sym == "JIOFIN" else [])[1]
    now = dt.datetime(2026, 11, 9, 8, 30, tzinfo=IST).timestamp()
    r = newsfresh.check("JIOFIN", "Q2FY27 Quarterly Result Announced for Jio Financial Services Ltd.", "", now - 600, now=now, live=(300.0, 1.0), page=False)
    check("JIOFIN: NSE's list says 16 Oct -> held: %s" % r[1], r[0] is False and "16 Oct (23 days ago)" in (r[1] or ""))
    r2 = newsfresh.check("JIOFIN", "Jio Financial Q2 profit flat at Rs 690 crore", "", now - 600, now=now, live=(300.0, 1.0), page=False)
    check("asked NSE once, the date kept (%s)" % ASKED, r2[0] is False and ASKED == ["JIOFIN"] and json.load(open(os.path.join(tmp, "data", "results_dates.json")))["JIOFIN"]["t"] == t16)
    r3 = newsfresh.check("TCS", "TCS Q2 profit up 9% on deal wins", "", now - 600, now=now, live=(3000.0, 1.0), page=False)
    check("a share NSE has no results for: passes (%s)" % (r3[1] or "ok"), r3[0] is True)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP138B RESULTS DATES TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p138b_patch.py $D || { rm -f $D/p138btest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile newsfresh.py p138btest.py || back
timeout 120 python3 p138btest.py 2>&1 | grep "OK  \|FAIL\|P138B"
timeout 120 python3 p138btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p138test.py p124ctest.py p118test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-newsroom gir-exchange && sleep 6
for u in gir-newsroom gir-exchange; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 138b APPLIED (the engine was not touched). JIOFIN, read now (asks NSE):"
cd $D && timeout 60 python3 -c "import newsfresh; print('  JIOFIN', newsfresh.stale_kind('JIOFIN', 'Q2FY27 Quarterly Result Announced for Jio Financial Services Ltd.') or 'PASSES')"
nohup python3 $D/newsfresh.py --results-dates > $D/data/results_dates.log 2>&1 &
echo "the results dates of all F&O shares are being read in the background (~5 min):  tail -3 $D/data/results_dates.log"
