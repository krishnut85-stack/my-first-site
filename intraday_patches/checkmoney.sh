#!/bin/bash
# CHECK F&O MONEY AGAINST NSE - every share on the F&O MONEY panel: GIR's futures OI change vs NSE's official end-of-day F&O file
#   (the near-month future's OI and its change, published every evening after ~18:00) and the build-up word each one gives.
#   Reads only - nothing changed.   bash checkmoney.sh [YYYY-MM-DD]
D=/home/globalbot/intraday
[ -f $D/hist3y.py ] || { echo "hist3y.py (patch 144) is needed - it reads NSE's file"; exit 1; }
cd $D && python3 - "${1:-}" <<'PY'
import sys, json, urllib.request, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
import hist3y
day = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else dt.date.today()
nse = hist3y.fo_one(day)
if isinstance(nse, str) or not nse:
    print("NSE's F&O file for %s: %s (it comes after ~18:00)" % (day, nse)); sys.exit(1)
k = open("dash_token.txt").read().strip()
M = json.load(urllib.request.urlopen("http://127.0.0.1:8090/market?k=" + k, timeout=30))
money = M.get("money") or {}
W = {1: {1: "LONG BUILD-UP", -1: "SHORT COVERING"}, -1: {1: "SHORT BUILD-UP", -1: "LONG UNWINDING"}}
n = ok = 0
print("NSE's file %s · %d futures\n%-12s %-15s %9s %9s %8s  %s" % (day, len(nse), "SHARE", "GIR SAYS", "GIR OI%", "NSE OI%", "PRICE%", "CHECK"))
for bu, rows in money.items():
    for r in rows:
        s = r.get("s"); v = nse.get(s)
        if not v:
            print("%-12s %-15s %9s %9s %8s  not in NSE's file" % (s, bu[:15], r.get("oi"), "-", r.get("chg"))); continue
        foi, fch = v[1], v[2]
        nse_oi = fch / (foi - fch) * 100 if foi - fch > 0 else 0.0
        px = r.get("chg") or 0
        word = W[1 if px > 0 else -1][1 if nse_oi > 0 else -1]
        same_oi = abs((r.get("oi") or 0) - nse_oi) <= max(1.5, abs(nse_oi) * 0.25)
        good = same_oi and word == bu
        n += 1; ok += good
        print("%-12s %-15s %8.1f%% %8.1f%% %7.2f%%  %s" % (s, bu[:15], r.get("oi") or 0, nse_oi, px, "✓" if good else "✗ NSE says %s%s" % (word, "" if same_oi else ", OI differs")))
print("\n%d of %d rows agree with NSE's official file" % (ok, n))
PY
