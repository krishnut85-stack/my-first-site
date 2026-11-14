#!/bin/bash
# WHY GIR'S FUTURES OI % DIFFERS FROM NSE'S - read-only. For a few shares: the baseline GIR used today (oibase_<day>.json), Kite's
#   daily candles with OI for the same contract (the last 5 days, the Muhurat Sunday included), NSE's official files (Fri 6 Nov,
#   Sun 8 Nov, Mon 9 Nov) and GIR's last live OI %.   bash diagoi.sh [ICICIBANK HDFCBANK ...]
D=/home/globalbot/intraday
cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 - "$@" <<'PY'
import sys, json, glob, os, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
import core, hist3y
S = [s.upper() for s in sys.argv[1:]] or ["ICICIBANK", "HDFCBANK", "SBIN", "MARUTI", "TATASTEEL", "HINDALCO", "LT"]
day = dt.date.today()
base = {}
for p in sorted(glob.glob("oibase_*.json"))[-3:]:
    print("baseline file:", os.path.basename(p), time_ := dt.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%d %b %H:%M"))
    if str(day) in p:
        base = json.load(open(p))
fm = {}
for p in sorted(glob.glob("futmap_*.json"))[-1:]:
    fm = json.load(open(p)); print("futures map:", os.path.basename(p))
N = {}
for d in (dt.date(2026, 11, 6), dt.date(2026, 11, 8), day):
    v = hist3y.fo_one(d)
    N[str(d)] = v if isinstance(v, dict) else {}
    print("NSE file %s: %s" % (d, ("%d futures" % len(v)) if isinstance(v, dict) else v))
st = {}
try:
    st = {f["s"]: f for f in (json.load(open("dash_state.json")).get("fo_paths") or [])}
except Exception as ex:
    print("dash_state:", ex)
k = core.get_kite()
for s in S:
    tok, ts, exp = (fm.get(s) or [None, None, None])
    print("\n== %s  contract %s (expiry %s)" % (s, ts, exp))
    print("   GIR baseline OI:     %s" % base.get(s))
    for d, v in N.items():
        x = v.get(s)
        if x:
            print("   NSE %s near future (exp %s): OI %d · change %+d (%+.1f%%)" % (d, x[4], x[1], x[2], x[2] / (x[1] - x[2]) * 100 if x[1] - x[2] else 0))
    if tok:
        try:
            for r in k.historical_data(int(tok), day - dt.timedelta(days=6), day, "day", oi=True):
                print("   Kite day candle %s: close %s · OI %s" % (str(r["date"])[:10], r["close"], r.get("oi")))
        except Exception as ex:
            print("   Kite history:", str(ex)[:100])
    f = st.get(s) or {}
    print("   GIR live: OI %% %s · price %% %s · %s" % (f.get("oi"), f.get("chg"), f.get("bu")))
PY
