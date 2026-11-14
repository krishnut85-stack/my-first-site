#!/bin/bash
# PATCH 146b - AFTER THE CLOSE, NSE'S OFFICIAL NUMBERS. Indices and sector indices: NSE's own close and previous close as they are
#   (VIX showed -0.29%, NSE -5.81%; sectors 2 of 22 right). Futures: once NSE's end-of-day F&O file is read, every share's OI %,
#   build-up word and fresh ₹ cr are NSE's (Kite's live futures OI ended 9 Nov far from NSE's for 70 shares - ICICIBANK +12.7% vs
#   NSE -3.0%). dashserve.py · nseaudit.py. Restarts gir-dash only - safe any time. Re-runs the audit at the end.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g146b; mkdir -p $W
grep -q "patch 146b" $D/dashserve.py && { echo "patch 146b is already installed"; exit 1; }
[ -f $D/nseaudit.py ] || { echo "patch 146 is not installed yet"; exit 1; }
F="dashserve.py nseaudit.py"; [ -f $D/p145btest.py ] && F="$F p145btest.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p146btest.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p146b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p146b_patch.py - PATCH 146b: AFTER THE CLOSE, NSE'S OFFICIAL NUMBERS (the NSE audit of 9 Nov):
  1. the indices and the sector indices: NSE's own close and previous close, taken as they are (VIX showed -0.29%, NSE -5.81%;
     the sector indices 2 of 22 right) - before, NSE's figure was used only when GIR's last tick was within 0.3% of it
  2. the futures: once NSE's end-of-day F&O file is read (the audit saves data/nsefut_<day>.json, 18:40 and on demand), every
     share's futures OI %, its build-up word and the fresh money (₹ cr) are NSE's - Kite's live futures OI ended the day far from
     NSE's official figure for 70 of 218 shares (ICICIBANK 90.75 m vs NSE 78.07 m: GIR said LONG BUILD-UP +12.7%, NSE -3.0%)
Usage: python3 p146b_patch.py /home/globalbot/intraday  (needs 145e and 146)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
DASH = [
    ('''    pcs = dict(_saved_pc(now))
    for name, v in out.items():                                  # patch 145e: NSE's official previous close first
        n_ = _NSEI_GET(name, v.get("last"))
        if n_:
            pcs[name] = n_''',
     '''    pcs = dict(_saved_pc(now))
    for name, v in out.items():                                  # patch 146b: NSE's official close AND previous close, as they are
        x_ = _nse_indices().get(_nkey(name))
        if x_ and x_[0] and x_[1]:
            v["last"] = x_[0]
            pcs[name] = x_[1]'''),
    ('''    for n_ in sidx:                                              # patch 145e: NSE's official previous close first
        p_ = _NSEI_GET(n_, (sidx[n_] or {}).get("last"))
        if p_:
            pcs["SEC:" + n_] = p_
    out = {}''',
     '''    nse_ = _nse_indices()                                        # patch 146b: NSE's official close AND previous close, as they are
    out = {}
    for n_, v_ in sidx.items():
        x_ = nse_.get(_nkey(n_))
        if x_ and x_[0] and x_[1]:
            out[n_] = dict(v_, last=x_[0], chg=round((x_[0] / x_[1] - 1) * 100, 2))
    if len(out) == len(sidx):
        return out
    sidx = {k: v for k, v in sidx.items() if k not in out}
    done_ = out
    out = {}'''),
    ('''        v["chg"] = round((v["last"] / pc - 1) * 100, 2) if (pc and v.get("last")) else None
        out[n] = v
    return out''',
     '''        v["chg"] = round((v["last"] / pc - 1) * 100, 2) if (pc and v.get("last")) else None
        out[n] = v
    out.update(done_)
    return out'''),
    ('''        v = json.loads(raw)
    except Exception:
        v = {}
    _LO.update({"key": key, "v": v, "t": time.time()})
    return v''',
     '''        v = json.loads(raw)
    except Exception:
        v = {}
    try:
        _fut_eod(v)                                              # patch 146b: after the close, NSE's official futures OI
    except Exception:
        pass
    _LO.update({"key": key, "v": v, "t": time.time()})
    return v


def _fut_eod(st, now=None):
    """patch 146b: outside the session, once NSE's end-of-day F&O file is read (data/nsefut_<day>.json, the NSE audit), every
    share's futures OI %, build-up word and fresh money come from it - the official figures"""
    if _in_session(now) or not st or not st.get("fo_paths"):
        return st
    day = _last_session_day(now)
    if st.get("day") and st["day"] != day:
        return st
    try:
        N = json.load(open(os.path.join(BASE, "data", "nsefut_%s.json" % day)))
    except Exception:
        return st
    for f in st["fo_paths"]:
        x = N.get(f.get("s"))
        if not x or not x[0] or x[0] - x[1] <= 0:
            continue
        oi, chg_oi, fpx = x[0], x[1], x[2]
        p = f.get("chg") or 0
        f["oi"] = round(chg_oi / (oi - chg_oi) * 100, 1)
        f["cr"] = round(chg_oi * (fpx or f.get("px") or 0) / 1e7, 1)
        f["bu"] = ("LONG BUILD-UP" if f["oi"] > 0 else "SHORT COVERING") if p > 0 else ("SHORT BUILD-UP" if f["oi"] > 0 else "LONG UNWINDING") if p < 0 else f.get("bu")
        f["oi_src"] = "NSE"
    st["oi_src"] = "NSE end-of-day %s" % day
    return st'''),
]
AUDIT = [
    ('''    FUT, OPT, UND = nse_fo(day)''', '''    FUT, OPT, UND = nse_fo(day)
    try:                                                         # patch 146b: the page takes the futures' official OI from this
        json.dump({s: [F[0][2], F[0][3], F[0][1]] for s, F in FUT.items() if F}, open(os.path.join(BASE, "data", "nsefut_%s.json" % day), "w"))
    except Exception:
        pass'''),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 146b" in s:
        print("patch 146b is already in %s" % os.path.basename(p)); return None
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), os.path.basename(p), a[:90].replace("\n", " | "))); return None
        s = s.replace(a, b)
    return s


T145 = os.path.join(D, "p145btest.py")                          # its own test: no network (NSE's live list would change its numbers)
if os.path.exists(T145):
    t_ = open(T145, encoding="utf-8").read()
    if "_NSEI.update" not in t_ and t_.count("import dashserve as ds\n") == 1:
        open(T145, "w", encoding="utf-8").write(t_.replace("import dashserve as ds\n", "import dashserve as ds\nds._NSEI.update({\"t\": 9e18, \"v\": {}})   # patch 146b: no network in the test\n"))
a = apply(os.path.join(D, "dashserve.py"), DASH)
b = apply(os.path.join(D, "nseaudit.py"), AUDIT)
if a is None or b is None:
    sys.exit(1)
open(os.path.join(D, "dashserve.py"), "w", encoding="utf-8").write(a)
open(os.path.join(D, "nseaudit.py"), "w", encoding="utf-8").write(b)
print("patched: dashserve.py, nseaudit.py")
PY_PATCH
cat > $D/p146btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p146btest.py - patch 146b: after the close NSE's official numbers (no network - NSE's list and file are made up here)"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
IST = ds.IST
eve = dt.datetime(2026, 11, 9, 20, 30, tzinfo=IST)
ds._NSEI.update({"t": 9e18, "v": {"NIFTY50": (25044.65, 24986.4), "NIFTYBANK": (59741.25, 58850.65), "INDIAVIX": (17.36, 18.43), "NIFTYIT": (36000.0, 36444.6), "NIFTYPSUBANK": (8800.0, 8483.4)}})
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0 = ds.BASE; ds.BASE = T
f = ds._idx_fix({"NIFTY": {"last": 25044.65, "chg": 0.06}, "VIX": {"last": 17.42, "chg": -0.29}}, eve, {})
check("VIX: NSE's close 17.36 and -5.81%% (GIR showed 17.42 -0.29%%) (%s)" % f["VIX"], f["VIX"]["last"] == 17.36 and f["VIX"]["chg"] == -5.81)
s = ds._sidx_fix({"NIFTY IT": {"last": 35900.0, "chg": None}, "NIFTY PSU BANK": {"last": 8790.0, "chg": 3.6}, "NIFTY XYZ": {"last": 1.0, "chg": 9.0}}, eve)
check("sectors: NIFTY IT -1.22%%, PSU BANK +3.73%% from NSE as they are; one NSE does not list: no %% (%s)" % s, s["NIFTY IT"]["chg"] == -1.22 and s["NIFTY PSU BANK"]["chg"] == 3.73 and s["NIFTY XYZ"]["chg"] is None)
json.dump({"ICICIBANK": [78071700, -2426900, 1590.0], "SBIN": [91862250, -2640000, 1045.0]}, open(os.path.join(T, "data", "nsefut_2026-11-09.json"), "w"))
st = {"day": "2026-11-09", "fo_paths": [{"s": "ICICIBANK", "chg": 1.53, "oi": 12.7, "bu": "LONG BUILD-UP", "cr": 1624}, {"s": "SBIN", "chg": 2.56, "oi": 3.4, "bu": "LONG BUILD-UP", "cr": 338}, {"s": "XYZ", "chg": 1, "oi": 5, "bu": "LONG BUILD-UP"}]}
ds._fut_eod(st, eve)
F = {x["s"]: x for x in st["fo_paths"]}
check("ICICIBANK: NSE's OI -3.0%% -> SHORT COVERING, ₹-385.9 cr (%s)" % F["ICICIBANK"], F["ICICIBANK"]["oi"] == -3.0 and F["ICICIBANK"]["bu"] == "SHORT COVERING" and F["ICICIBANK"]["cr"] == -385.9)
check("SBIN: -2.8%% -> SHORT COVERING; a share not in NSE's file untouched", F["SBIN"]["oi"] == -2.8 and F["SBIN"]["bu"] == "SHORT COVERING" and F["XYZ"]["oi"] == 5)
st2 = {"day": "2026-11-09", "fo_paths": [{"s": "ICICIBANK", "chg": 1.53, "oi": 12.7, "bu": "LONG BUILD-UP"}]}
ds._fut_eod(st2, eve.replace(hour=11))
check("in the session the live figures stay", st2["fo_paths"][0]["oi"] == 12.7)
ds.BASE = B0; shutil.rmtree(T)
print("P146b TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p146b_patch.py $D || { rm -f $D/p146btest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py nseaudit.py p146btest.py || back
for t in p146btest.py p146test.py p145etest.py p145btest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep FAIL | head -3; back; }; }; done
systemctl restart gir-dash && sleep 10
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    the audit again (it saves NSE's futures file for the page):"
echo
( cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 nseaudit.py --no-tg ) | head -12
sleep 65; echo; echo "    and once more, with the page now on NSE's futures figures:"
( cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 nseaudit.py ) | grep -E "^(✅|❌|❔|ℹ️)"
echo
echo "PATCH 146b APPLIED. Reload the GIR page (Ctrl+F5)."
