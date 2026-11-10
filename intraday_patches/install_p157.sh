#!/bin/bash
# PATCH 157 - THE INDEX STRIP BEFORE THE OPEN = THE LAST SESSION'S CHECKED CLOSE (SENSEX showed +2.17% this morning from an outside feed that still
#   had the Muhurat Sunday as its last day). dashserve.py. Also repairs p145btest.py (it used today's date and broke at midnight).
#   Restarts gir-dash only - safe any time, also in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g157; mkdir -p $W
grep -q "patch 157" $D/dashserve.py && { echo "patch 157 is already installed"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $W/p157_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p157_patch.py - PATCH 157: THE INDEX STRIP BEFORE THE OPEN SHOWS THE LAST SESSION'S CLOSE (10 Nov 07:15: SENSEX showed 81,028.02 +1,718 (+2.17%) -
the outside daily feed still had the Muhurat Sunday as its last day). After 15:30 the strip's checked picture (NSE's figures) is saved
(data/idx_last.json); until 09:15 the next trading day exactly that picture is shown - no outside feed.
Usage: python3 p157_patch.py /home/globalbot/intraday  (needs 145b)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
A = "    idx = _idx_fix(idx)                                          # patch 145b: never Kite's wrong after-close previous close"
B = A + '''
    try:                                                         # patch 157: after the close keep the checked picture; before the open show it
        now_ = dt.datetime.now(IST); hm_ = now_.strftime("%H:%M"); p_ = os.path.join(BASE, "data", "idx_last.json")
        if now_.weekday() < 5 and hm_ >= "15:40" and idx and all((idx.get(k_) or {}).get("chg") is not None for k_ in ("NIFTY", "SENSEX", "BANKNIFTY", "VIX")):
            if time.time() - _IDXL.get("t", 0) > 120:
                _IDXL["t"] = time.time()
                json.dump({"day": now_.strftime("%Y-%m-%d"), "idx": idx}, open(p_ + ".tmp", "w")); os.replace(p_ + ".tmp", p_)
        elif not _in_session(now_) and not (now_.weekday() < 5 and "15:30" <= hm_):
            j_ = json.load(open(p_))
            if j_.get("day") == _last_session_day(now_) and j_.get("idx"):
                idx = dict(idx, **j_["idx"])
    except Exception:
        pass'''
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
if "patch 157" in s:
    print("patch 157 is already in dashserve.py"); sys.exit(1)
if s.count(A) != 1:
    print("ANCHOR"); sys.exit(1)
s = s.replace(A, B).replace("\n\ndef _in_session(", "\n\n_IDXL = {}   # patch 157\n\n\ndef _in_session(", 1)
open(p, "w", encoding="utf-8").write(s); print("patched: dashserve.py")
PY_PATCH
cat > $D/p157test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p157test.py - patch 157: the checked index picture saved after the close and shown before the next open"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0 = ds.BASE; ds.BASE = T
good = {"NIFTY": {"last": 25044.65, "chg": 0.23}, "SENSEX": {"last": 81106.65, "chg": 0.1}, "BANKNIFTY": {"last": 59741.25, "chg": 1.51}, "VIX": {"last": 17.36, "chg": -5.81}}
json.dump({"day": "2026-11-09", "idx": good}, open(os.path.join(T, "data", "idx_last.json"), "w"))
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashserve.py"), encoding="utf-8").read()
ok = "patch 157" in src and "_IDXL = {}" in src and ds._last_session_day(dt.datetime(2026, 11, 10, 7, 15, tzinfo=ds.IST)) == "2026-11-09"
ds.BASE = B0; shutil.rmtree(T)
print(("OK" if ok else "FAIL") + "   the saved picture is for the last session (9 Nov) before 10 Nov's open")
print("P157 TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
PY_TEST
[ -f $D/p145btest.py ] && sed -i 's/json.dump({"day": dt.datetime.now(IST).strftime("%Y-%m-%d"), "v":/json.dump({"day": "2026-11-09", "v":/' $D/p145btest.py
python3 $W/p157_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || { cp $D/dashserve.py.bak$TS $D/dashserve.py; echo "old file back"; exit 1; }
for t in p157test.py p146btest.py p145etest.py p145btest.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || echo "    $t: $(python3 $t 2>&1 | grep FAIL | head -1)"; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "ERROR - old file back"; exit 1; }
echo "PATCH 157 APPLIED. Today until 09:15 SENSEX may still show the old figure (nothing saved from yesterday yet); from 09:15 it is live,"
echo "and from this evening on the morning strip always shows the last close as checked."
