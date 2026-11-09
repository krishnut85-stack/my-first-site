#!/bin/bash
# PATCH 145b - THE INDEX % RIGHT TONIGHT. After 15:30 the page recomputes NIFTY / SENSEX / BANKNIFTY / VIX from a previous close
#   GIR can trust (the session's saved one · NIFTY's own feed close · the official daily closes) - never Kite's wrong after-close
#   figure; a sector index with no sure close shows "—". dashserve.py only. Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g145b; mkdir -p $W
grep -q "patch 145b" $D/dashserve.py && { echo "patch 145b is already installed"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/p145btest.py; systemctl restart gir-dash; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p145b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p145b_patch.py - PATCH 145b: THE INDEX % RIGHT TONIGHT, NOT TOMORROW (Rama, 9 Nov 19:58: NIFTY +15.02 (+0.06%) on GIR, Kite
+58.25 (+0.23%)). After 15:30 the engine stops reading the indices and its last picture carries Kite's wrong after-close
previous close. Outside the session the page now recomputes each index's change from a previous close it can trust:
  1. the one saved during the session (data/idx_pc.json, patch 140g)   2. NIFTY: the feed's own (charts.json - the chart's
  "prev close 24,986.4")   3. Yahoo's daily closes (the day's close vs the one before)   - else the % is left out, never wrong.
The sector indices: only from the saved previous close; else no % ("—") rather than a wrong one.
Usage: python3 p145b_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
FUNC = '''

def _in_session(now=None):
    now = now or dt.datetime.now(IST)
    return now.weekday() < 5 and "09:15" <= now.strftime("%H:%M") < "15:30"


def _saved_pc():
    try:
        j = json.load(open(os.path.join(BASE, "data", "idx_pc.json")))
        return j.get("v") or {} if j.get("day") == dt.datetime.now(IST).strftime("%Y-%m-%d") else {}
    except Exception:
        return {}


_YPC = {"t": 0.0, "v": {}}


def _yahoo_pc():
    """{name: (last, previous close)} from Yahoo's daily closes - exact (not from a rounded %), cached 10 min"""
    if time.time() - _YPC["t"] < 600:
        return _YPC["v"]
    out = {}
    try:
        import morning
        for name, sym in (("NIFTY", "^NSEI"), ("SENSEX", "^BSESN"), ("BANKNIFTY", "^NSEBANK"), ("VIX", "^INDIAVIX")):
            v = morning.fetch_cue(sym, timeout=5)
            if v and v[1]:
                out[name] = (v[1], v[1] / (1 + v[0] / 100))
    except Exception:
        pass
    _YPC.update({"t": time.time(), "v": out})
    return out


def _idx_fix(idx, now=None, yahoo=None):
    """patch 145b: outside the session, each index's % from a previous close GIR can trust (see the patch note)"""
    if _in_session(now) or not idx:
        return idx
    out = {k: dict(v) for k, v in idx.items()}
    pcs = dict(_saved_pc())
    try:
        nf = (json.load(open(os.path.join(BASE, "charts.json"))) or {}).get("NIFTY50") or {}
        cl = [c for c in (nf.get("c") or []) if c]
        if nf.get("pc") and cl and out.get("NIFTY", {}).get("last") and abs(cl[-1] / out["NIFTY"]["last"] - 1) < 0.003:
            pcs.setdefault("NIFTY", float(nf["pc"]))
    except Exception:
        pass
    Y = None
    for name, v in out.items():
        last = v.get("last")
        if not last:
            continue
        pc = pcs.get(name)
        if not pc:
            if Y is None:
                try:
                    Y = yahoo if yahoo is not None else _yahoo_pc()
                except Exception:
                    Y = {}
            y = (Y or {}).get(name)
            if y and y[0] and y[1] and abs(y[0] / last - 1) < 0.003:
                pc = y[1]
        if pc:
            v["chg"], v["pc"] = round((last / pc - 1) * 100, 2), round(pc, 2)
        else:
            v["chg"], v["pc"] = None, None
    return out


def _sidx_fix(sidx, now=None):
    """patch 145b: the sector indices outside the session: the % only from the saved previous close"""
    if _in_session(now) or not sidx:
        return sidx
    pcs = _saved_pc()
    out = {}
    for n, v in sidx.items():
        v = dict(v)
        pc = pcs.get("SEC:" + n)
        v["chg"] = round((v["last"] / pc - 1) * 100, 2) if (pc and v.get("last")) else None
        out[n] = v
    return out


def focus(sym):'''
EDITS = [
    ('''        idx = dict(idx_closed(), **idx)                          # the last closes until the engine's own quotes come (09:15)''',
     '''        idx = dict(idx_closed(), **idx)                          # the last closes until the engine's own quotes come (09:15)
    idx = _idx_fix(idx)                                          # patch 145b: never Kite's wrong after-close previous close'''),
    ('''"sidx": st.get("sidx") or {},''', '''"sidx": _sidx_fix(st.get("sidx") or {}),'''),
    ('''\n\ndef focus(sym):''', FUNC),
]
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if "patch 145b" in s:
    print("patch 145b is already in dashserve.py"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:90].replace("\n", " | "))); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: dashserve.py")
PY_PATCH
cat > $D/p145btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p145btest.py - patch 145b: tonight's numbers (9 Nov): GIR showed NIFTY +0.06% / BANKNIFTY +1.11%; Kite +0.23% / +1.51%"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0 = ds.BASE; ds.BASE = T
json.dump({"NIFTY50": {"c": [25010.0, 25044.65], "pc": 24986.4}}, open(os.path.join(T, "charts.json"), "w"))
IST = ds.IST
eve = dt.datetime(2026, 11, 9, 19, 58, tzinfo=IST)
idx = {"NIFTY": {"last": 25044.65, "chg": 0.06}, "BANKNIFTY": {"last": 59741.25, "chg": 1.11}, "SENSEX": {"last": 81106.65, "chg": 0.1}, "VIX": {"last": 17.42, "chg": -0.29}}
Y = {"BANKNIFTY": (59741.25, 58850.65), "SENSEX": (81106.65, 80823.77), "VIX": (17.42, 17.47)}
f = ds._idx_fix(idx, eve, Y)
check("NIFTY: +0.23%% from the feed's 24,986.40 (%s)" % f["NIFTY"], f["NIFTY"]["chg"] == 0.23 and f["NIFTY"]["pc"] == 24986.4)
check("BANKNIFTY: +1.51%% from the daily closes (%s)" % f["BANKNIFTY"], f["BANKNIFTY"]["chg"] == 1.51 and f["BANKNIFTY"]["pc"] == 58850.65)
check("SENSEX from the daily closes (%s)" % f["SENSEX"], f["SENSEX"]["chg"] == 0.35)
check("no sure close: no %% rather than a wrong one", ds._idx_fix({"X": {"last": 10.0, "chg": 5.0}}, eve, {})["X"]["chg"] is None)
check("in the session the engine's own figures stay", ds._idx_fix(idx, eve.replace(hour=11), Y) == idx)
json.dump({"day": dt.datetime.now(IST).strftime("%Y-%m-%d"), "v": {"NIFTY": 24986.4, "SEC:NIFTY BANK": 58850.65}}, open(os.path.join(T, "data", "idx_pc.json"), "w"))
s = ds._sidx_fix({"NIFTY BANK": {"last": 59741.25, "chg": 1.11}, "NIFTY IT": {"last": 1.0, "chg": 9.0}}, eve)
check("the sector indices: NIFTY BANK +1.51%% from the saved close, NIFTY IT (none saved) no %% (%s)" % s, s["NIFTY BANK"]["chg"] == 1.51 and s["NIFTY IT"]["chg"] is None)
ds.BASE = B0; shutil.rmtree(T)
print("P145b INDEX TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p145b_patch.py $D || { rm -f $D/p145btest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p145btest.py || back
for t in p145btest.py p140ftest.py p139test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 10
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    the page now shows:"
curl -s "http://127.0.0.1:8090/home?k=$(cat $D/dash_token.txt)" | python3 -c "
import json, sys
I = json.load(sys.stdin).get('idx') or {}
for n in ('NIFTY', 'SENSEX', 'BANKNIFTY', 'VIX'):
    x = I.get(n) or {}
    pts = (x['last'] - x['pc']) if (x.get('last') and x.get('pc')) else None
    print('      %-10s %s  %s  %s' % (n, x.get('last'), ('%+.2f' % pts) if pts is not None else '', ('(%+.2f%%)' % x['chg']) if x.get('chg') is not None else '(no sure close)'))
"
echo
echo "PATCH 145b APPLIED. Reload the GIR page - compare with Kite."
