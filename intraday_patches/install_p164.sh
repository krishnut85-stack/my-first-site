#!/bin/bash
# PATCH 164 - the page knows NSE HOLIDAYS (10 Nov 2026, Diwali Balipratipada): it took the holiday for a session, so
#   * F&O MONEY showed the engine's suspect Kite OI (ICICIBANK +12.7% LONG BUILD-UP ₹1,624 cr) instead of NSE's official file for the last
#     session (ICICIBANK -3.0% SHORT COVERING ₹-386 cr) - the numbers changed from last evening
#   * the NIFTY chart stamped Monday's session with Tuesday's date and made flat "candles" from stale quotes
#   * the morning index picture, the overnight-alerts window and the 15:45 news summary counted weekends only
#   Now: on an NSE holiday the page shows the last session as checked by NSE. + eventstudy.py: a share in GIR's groups that is not in the
#   F&O list (POONAWALLA) no longer stops it. gir-dash restarts (~10 s); the engine is not touched.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d); TS=$(date +%m%d%H%M%S)
cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $W/p164_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p164_patch.py - PATCH 164: the page knows NSE HOLIDAYS, not only weekends (10 Nov 2026: the page took Tuesday's holiday for a session -
F&O MONEY showed the engine's suspect Kite OI (ICICIBANK +12.7% LONG BUILD-UP) instead of NSE's official end-of-day file (-3.0% SHORT
COVERING), and the NIFTY chart stamped Monday's session with Tuesday's date). Usage: python3 p164_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
E = [
 ('    return now.weekday() < 5 and "09:15" <= now.strftime("%H:%M") < "15:30"\n',
  '    return now.weekday() < 5 and "09:15" <= now.strftime("%H:%M") < "15:30" and not _is_holiday(now.date())   # patch 164: a holiday is no session\n'),
 ('''    d = now.date()
    if now.strftime("%H:%M") < "09:15" or d.weekday() > 4:
        d -= dt.timedelta(days=1)
        while d.weekday() > 4:
            d -= dt.timedelta(days=1)
    return str(d)''',
  '''    d = now.date()
    if now.strftime("%H:%M") < "09:15" or _is_holiday(d):          # patch 164: NSE holidays too, not only weekends
        d -= dt.timedelta(days=1)
        while _is_holiday(d):
            d -= dt.timedelta(days=1)
    return str(d)'''),
 ('''            while d0.weekday() > 4:
                d0 -= dt.timedelta(days=1)''',
  '''            while _is_holiday(d0):                                   # patch 164: back over holidays too
                d0 -= dt.timedelta(days=1)'''),
 ('if now_.weekday() < 5 and hm_ >= "15:40" and idx', 'if not _is_holiday(now_.date()) and hm_ >= "15:40" and idx'),
 ('elif not _in_session(now_) and not (now_.weekday() < 5 and "15:30" <= hm_):', 'elif not _in_session(now_) and not (not _is_holiday(now_.date()) and "15:30" <= hm_):'),
 ('''    if now.weekday() > 4 or not (555 <= m <= 930):
        return
    d_ = str(now.date())
    path = os.path.join(BASE, "data", "ix1m.json")''',
  '''    if _is_holiday(now.date()) or not (555 <= m <= 930):          # patch 164: no candles on a holiday
        return
    d_ = str(now.date())
    path = os.path.join(BASE, "data", "ix1m.json")'''),
 ('    if now.weekday() >= 5 or now.strftime("%H:%M") < "15:45" or _RX["summary"] == d_:',
  '    if _is_holiday(now.date()) or now.strftime("%H:%M") < "15:45" or _RX["summary"] == d_:'),
 ('''    if st.get("day") and st["day"] != day:
        return st''',
  '''    if st.get("day") and st["day"] != day and not _is_holiday(dt.date.fromisoformat(str(st["day"])[:10])):   # patch 164: a holiday's state takes the last session's NSE figures
        return st'''),
 ('''    now = now or dt.datetime.now(IST)
    import numpy as np
    fn = "NIFTY_BANK" if n == "BANKNIFTY" else "NIFTY_50"''',
  '''    now = now or dt.datetime.now(IST)
    hol = _is_holiday(now.date())                                # patch 164: on a holiday the chart ends with the last session, at its own date
    if hol:
        _ld = dt.date.fromisoformat(_last_session_day(now))
        now = dt.datetime(_ld.year, _ld.month, _ld.day, 15, 30, tzinfo=IST)
    import numpy as np
    fn = "NIFTY_BANK" if n == "BANKNIFTY" else "NIFTY_50"'''),
 ('            if (st.get("day") or str(now.date())) == str(now.date()):', '            if hol or (st.get("day") or str(now.date())) == str(now.date()):'),
]
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if "patch 164" in s:
    print("patch 164 is already in dashserve.py"); sys.exit(0)
for a, b in E:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:70])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("dashserve.py: holidays known in %d places" % len(E))
PY_PATCH
cat > $D/p164test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p164test.py - patch 164: the page on an NSE holiday (Tue 10 Nov 2026) - no network, made-up files"""
import os, sys, json, types, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
H = types.ModuleType("holidays")                                   # NSE's list as the page sees it (holidays.py is tested by p158)
H.holiday = lambda d: "weekend" if (dt.date.fromisoformat(d) if isinstance(d, str) else d).weekday() >= 5 else \
    ("Diwali Balipratipada" if str(d) == "2026-11-10" else None)
sys.modules["holidays"] = H
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
IST = ds.IST
hol = dt.datetime(2026, 11, 10, 12, 10, tzinfo=IST)
check("Tue 10 Nov 12:10 (holiday) is not a session; Mon 9 Nov 11:00 is", not ds._in_session(hol) and ds._in_session(dt.datetime(2026, 11, 9, 11, 0, tzinfo=IST)))
check("the last session on the holiday = Mon 9 Nov; Wed 11 Nov 08:00 -> Mon 9 Nov; Wed 10:00 -> Wed",
      ds._last_session_day(hol) == "2026-11-09" and ds._last_session_day(dt.datetime(2026, 11, 11, 8, 0, tzinfo=IST)) == "2026-11-09"
      and ds._last_session_day(dt.datetime(2026, 11, 11, 10, 0, tzinfo=IST)) == "2026-11-11")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0, S0 = ds.BASE, ds.STATE
ds.BASE = T; ds.STATE = os.path.join(T, "nostate.json")
json.dump({"ICICIBANK": [78071700, -2426900, 1590.0]}, open(os.path.join(T, "data", "nsefut_2026-11-09.json"), "w"))
st = {"day": "2026-11-10", "fo_paths": [{"s": "ICICIBANK", "chg": 1.53, "oi": 12.7, "bu": "LONG BUILD-UP", "cr": 1624}]}
ds._fut_eod(st, hol)
f = st["fo_paths"][0]
check("F&O MONEY on the holiday: NSE's Monday file -> ICICIBANK OI -3.0%%, SHORT COVERING, ₹-385.9 cr (not Kite's +12.7%% LONG BUILD-UP) (%s)" % f,
      f["oi"] == -3.0 and f["bu"] == "SHORT COVERING" and f["cr"] == -385.9 and "2026-11-09" in st.get("oi_src", ""))
st2 = {"day": "2026-11-06", "fo_paths": [{"s": "ICICIBANK", "chg": 1.0, "oi": 5.0, "bu": "LONG BUILD-UP"}]}
ds._fut_eod(st2, hol)
check("an old state from another trading day is left alone", st2["fo_paths"][0]["oi"] == 5.0)
ds._HOME["v"] = {"idx": {"NIFTY": {"last": 25044.65}, "BANKNIFTY": {"last": 59000.0}}}
ds.ix_tick(hol)
check("no NIFTY candles are made on the holiday", not os.path.exists(os.path.join(T, "data", "ix1m.json")))
json.dump({"NIFTY50": {"o": [24990.0, 25000.0], "h": [25005.0, 25010.0], "l": [24985.0, 24995.0], "c": [25000.0, 25003.65]}}, open(os.path.join(T, "charts.json"), "w"))
ds._IXH.clear()
x = ds.ixhist("NIFTY", hol)
mon, tue = dt.datetime(2026, 11, 9, 9, 15, tzinfo=IST).timestamp(), dt.datetime(2026, 11, 10, 9, 15, tzinfo=IST).timestamp()
ts = x.get("t") or []
check("the chart on the holiday ends with Monday's session at Monday's date (not stamped 10 Nov) (%s)" % [dt.datetime.fromtimestamp(t, IST).strftime("%m-%d %H:%M") for t in ts[-2:]],
      len(ts) >= 2 and mon <= ts[-1] < tue and x["c"][-1] == 25003.65)
ds.BASE, ds.STATE = B0, S0; shutil.rmtree(T)
print("P164 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "== 1. the patch"
R=$(python3 $W/p164_patch.py $D) || { echo "   $R - nothing was changed"; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile dashserve.py || { cp $D/dashserve.py.bak$TS $D/dashserve.py; echo "   does not compile - old file back"; exit 1; }
echo "== 2. the tests"
if timeout 120 python3 p164test.py > /tmp/p164test.log 2>&1; then echo "   p164test.py passed (6 checks)"; else
  echo "   TEST FAILED - old file back:"; grep FAIL /tmp/p164test.log | head -5 | sed 's/^/     /'; cp $D/dashserve.py.bak$TS $D/dashserve.py; exit 1; fi
for t in p157test.py p146btest.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "   $t passed" || echo "   $t: $(python3 $t 2>&1 | grep FAIL | head -1)"; }; done
echo "== 3. NSE's file for the last session (what F&O MONEY shows now)"
python3 - <<'PY' 2>&1 | sed 's/^/   /'
import json, os, glob
fs = sorted(glob.glob("/home/globalbot/intraday/data/nsefut_*.json"))
if not fs:
    print("no NSE end-of-day file yet - the NSE audit (18:40) makes it")
else:
    N = json.load(open(fs[-1])); print("%s: %d shares" % (os.path.basename(fs[-1]), len(N)))
    for s in ("ICICIBANK", "HDFCBANK", "DIVISLAB", "IREDA"):
        x = N.get(s)
        if x and x[0] - x[1] > 0:
            print("  %-10s futures OI %+.1f%% · ₹%+.0f cr fresh money" % (s, x[1] / (x[0] - x[1]) * 100, x[1] * x[2] / 1e7))
PY
python3 - <<'PY' 2>/dev/null && echo "   today's made-up NIFTY candles removed"
import json, sys, holidays
p = "/home/globalbot/intraday/data/ix1m.json"
j = json.load(open(p))
if holidays.holiday(j.get("day")):
    import os; os.remove(p); sys.exit(0)
sys.exit(1)
PY
echo "== 4. the page"
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] && echo "   gir-dash running - reload the page" || { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "   ERROR - old file back"; exit 1; }
if [ -f $D/eventstudy.py ] && grep -q "pc = pcm\[s\].get(k)" $D/eventstudy.py; then
  sed -i 's/pc = pcm\[s\].get(k)/pc = (pcm.get(s) or {}).get(k)/' $D/eventstudy.py && echo "   eventstudy.py: shares outside the F&O list skipped (run eventstudy.sh again)"
fi
rm -rf $W
echo
echo "PATCH 164 APPLIED. On a holiday the page now shows the last session as NSE closed it. Send Claude a screenshot of section 3 and of F&O MONEY."
