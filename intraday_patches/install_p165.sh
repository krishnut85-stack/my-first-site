#!/bin/bash
# PATCH 165 - the live futures OI % (F&O MONEY, build-ups, OI alerts) starts from NSE's OFFICIAL closing OI of the last session, not Kite's
#   previous daily candle. 9 Nov 2026: GIR showed ICICIBANK +12.7% LONG BUILD-UP ₹+1,624 cr and HDFCBANK +5.7% - NSE: -3.0% and -3.6%,
#   SHORT COVERING. Kite stays only for a contract NSE's file lacks, and in the 2 days before expiry (the engine rolls to next month).
#   The NSE audit (18:40) now also keeps each future's expiry. The engine restarts now (market closed) so tomorrow it uses this.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d); TS=$(date +%m%d%H%M%S)
cp $D/flow.py $D/flow.py.bak$TS; cp $D/nseaudit.py $D/nseaudit.py.bak$TS
cat > $W/p165_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p165_patch.py - PATCH 165: the live futures OI % starts from NSE's OFFICIAL closing OI of the last session (the NSE audit's
data/nsefut_<day>.json), not Kite's previous daily candle. 9 Nov 2026: the engine showed ICICIBANK +12.7% LONG BUILD-UP (₹+1,624 cr),
HDFCBANK +5.7% - NSE's file: -3.0% and -3.6% SHORT COVERING. Kite is kept only for a contract NSE's file does not have (and in the 2
days before expiry, when the engine rolls to next month). The NSE audit now also keeps each future's expiry, so the match is exact.
Usage: python3 p165_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
NEW = '''

def nse_base(day, futs):
    """patch 165: the last session's closing OI per future from NSE's own end-of-day file -> ({underlying: oi}, the file's day)"""
    import glob
    fs = sorted(f for f in glob.glob(os.path.join(core.BASE, "data", "nsefut_*.json")) if os.path.basename(f)[7:17] < str(day)[:10])
    if not fs:
        return {}, None
    N = json.load(open(fs[-1]))
    d0 = os.path.basename(fs[-1])[7:17]
    out = {}
    for u, v in futs.items():
        x = N.get(u)
        if not x or not x[0]:
            continue
        exp = str(v[2])[:10]
        if len(x) > 3 and x[3]:
            if str(x[3])[:10] != exp:                     # NSE's near month is not the engine's contract (rolled over)
                continue
        elif (dt.date.fromisoformat(exp) - dt.date.fromisoformat(str(day)[:10])).days < 7:
            continue                                      # an older file without the expiry: only far from expiry
        out[u] = float(x[0])
    return out, d0


def oi_baseline(kite, futs, feed, day):
    """patch 165: NSE's official closing OI first; Kite's previous daily candle only for a contract NSE's file does not have"""
    try:
        kb = _kite_baseline(kite, futs, feed, day)
    except Exception as ex:
        log("OI baseline from Kite failed:", ex)
        kb = {}
    try:
        nb, d0 = nse_base(day, futs)
    except Exception as ex:
        log("OI baseline from NSE's file failed:", ex)
        nb, d0 = {}, None
    base = dict(kb)
    base.update(nb)
    off = sorted(((abs(kb[u] / nb[u] - 1) * 100, u) for u in nb if kb.get(u) and nb[u]), reverse=True)
    bad = [(p, u) for p, u in off if p > 2]
    log("OI baseline: %d from NSE's file %s, %d from Kite only; Kite's own differs from NSE by more than 2%% for %d: %s" % (
        len(nb), d0, len(base) - len(nb), len(bad), ", ".join("%s %.0f%%" % (u, p) for p, u in bad[:8])))
    try:
        json.dump({"day": str(day)[:10], "nse_file": d0, "from_nse": len(nb), "from_kite": len(base) - len(nb),
                   "kite_off": [[u, round(p, 1)] for p, u in bad[:60]]}, open(os.path.join(core.BASE, "data", "oibase_check.json"), "w"))
    except Exception:
        pass
    return base
'''
E = {
 "flow.py": [('def oi_baseline(kite, futs, feed, day):\n    """Yesterday\'s closing OI per futures contract.',
              'def _kite_baseline(kite, futs, feed, day):\n    """Yesterday\'s closing OI per futures contract.'),
             ('# ---------------------------------------------------------------- FLOW\nclass Flow(object):',
              NEW.lstrip("\n") + '\n\n# ---------------------------------------------------------------- FLOW\nclass Flow(object):')],
 "nseaudit.py": [('json.dump({s: [F[0][2], F[0][3], F[0][1]] for s, F in FUT.items() if F}',
                  'json.dump({s: [F[0][2], F[0][3], F[0][1], F[0][0]] for s, F in FUT.items() if F}')],   # + the expiry (patch 165)
}
out = {}
for fn, eds in E.items():
    p = os.path.join(D, fn); s = open(p, encoding="utf-8").read()
    if "patch 165" in s:
        print("patch 165 is already in %s" % fn); sys.exit(0)
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), fn, a[:60])); sys.exit(1)
        s = s.replace(a, b)
    if fn == "nseaudit.py":
        s = s.replace("# patch 146b: the page takes the futures' official OI from this", "# patch 146b: the page takes the futures' official OI from this (patch 165: + expiry)")
    out[p] = s
for p, s in out.items():
    open(p, "w", encoding="utf-8").write(s)
print("flow.py: the OI baseline from NSE's file · nseaudit.py: + each future's expiry")
PY_PATCH
cat > $D/p165test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p165test.py - patch 165: the live futures OI starts from NSE's official close (made-up files, no Kite)"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flow
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0 = flow.core.BASE; flow.core.BASE = T
# NSE's file for Mon 9 Nov (no expiry kept yet - the old format) and an older one
json.dump({"ICICIBANK": [78071700, -2426900, 1590.0], "HDFCBANK": [150000000, -5600000, 1000.0]}, open(os.path.join(T, "data", "nsefut_2026-11-09.json"), "w"))
json.dump({"ICICIBANK": [1, 0, 1.0]}, open(os.path.join(T, "data", "nsefut_2026-11-06.json"), "w"))
futs = {"ICICIBANK": (1, "ICICIBANK26NOVFUT", dt.date(2026, 11, 24)), "HDFCBANK": (2, "HDFCBANK26NOVFUT", dt.date(2026, 11, 24)),
        "SBIN": (3, "SBIN26NOVFUT", dt.date(2026, 11, 24))}
flow._kite_baseline = lambda k, f, fe, d: {"ICICIBANK": 69270000.0, "HDFCBANK": 147660000.0, "SBIN": 90000000.0}   # Kite's (wrong) previous candle
b = flow.oi_baseline(None, futs, None, "2026-11-11")
check("Wed 11 Nov: ICICIBANK starts from NSE's Monday close 78,071,700 (not Kite's 69,270,000)", b["ICICIBANK"] == 78071700.0)
check("a share NSE's file does not have keeps Kite's figure (SBIN)", b["SBIN"] == 90000000.0)
c = json.load(open(os.path.join(T, "data", "oibase_check.json")))
check("the check file names where Kite was off (ICICIBANK ~11%%) (%s)" % c, c["nse_file"] == "2026-11-09" and c["from_nse"] == 2 and c["kite_off"][0][0] == "ICICIBANK")
live = 78071700 * 0.97
check("so a 3% fall in OI reads -3.0% (Kite's start made it +9.3%)", round((live / b["ICICIBANK"] - 1) * 100, 1) == -3.0)
b2 = flow.oi_baseline(None, {"ICICIBANK": (1, "ICICIBANK26NOVFUT", dt.date(2026, 11, 13))}, None, "2026-11-11")
check("2 days before expiry with an old file (no expiry in it): Kite's figure, not NSE's near month", b2["ICICIBANK"] == 69270000.0)
json.dump({"ICICIBANK": [5000000, 100000, 1600.0, "2026-11-24"]}, open(os.path.join(T, "data", "nsefut_2026-11-23.json"), "w"))
b3 = flow.oi_baseline(None, {"ICICIBANK": (1, "ICICIBANK26DECFUT", dt.date(2026, 12, 29))}, None, "2026-11-24")
check("rolled to December while NSE's file is November's: Kite's figure", b3["ICICIBANK"] == 69270000.0)
b4 = flow.oi_baseline(None, {"ICICIBANK": (1, "ICICIBANK26NOVFUT", dt.date(2026, 11, 24))}, None, "2026-11-24")
check("the same contract (expiry kept in the file): NSE's figure", b4["ICICIBANK"] == 5000000.0)
flow.core.BASE = B0; shutil.rmtree(T)
print("P165 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
back() { cp $D/flow.py.bak$TS $D/flow.py; cp $D/nseaudit.py.bak$TS $D/nseaudit.py; }
echo "== 1. the patch"
R=$(python3 $W/p165_patch.py $D) || { echo "   $R - nothing was changed"; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile flow.py nseaudit.py || { back; echo "   does not compile - old files back"; exit 1; }
echo "== 2. the test"
if timeout 120 python3 p165test.py > /tmp/p165test.log 2>&1; then echo "   p165test.py passed (7 checks)"; else
  echo "   TEST FAILED - old files back:"; grep FAIL /tmp/p165test.log | head -5 | sed 's/^/     /'; back; exit 1; fi
echo "== 3. the engine"
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then
  echo "   market hours - the engine is NOT restarted now; it takes the new start at its next restart (after 15:35: systemctl restart gir-intraday)"
else
  systemctl restart gir-intraday && sleep 6 && [ "$(systemctl is-active gir-intraday)" = "active" ] && echo "   gir-intraday restarted - tomorrow's futures OI starts from NSE's figures" \
    || { back; systemctl restart gir-intraday; echo "   ERROR - the engine did not come up; old files back"; exit 1; }
fi
rm -rf $W
echo
echo "PATCH 165 APPLIED. Tomorrow after 09:20, to see where Kite and NSE disagreed:  cat $D/data/oibase_check.json"
