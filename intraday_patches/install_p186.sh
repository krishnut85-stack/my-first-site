#!/bin/bash
# PATCH 186 - URGENT before 09:15: the 18:40 NSE audit ran on the holiday (10 Nov) and saved an EMPTY NSE futures file - the newest one,
#   so today's engine would find no NSE OI start and fall back to Kite's wrong figures (patch 165), and the live check likewise.
#   Empty files are removed; the audit never saves one again; the engine and the live check skip any empty file.
#   The engine restarts now (market closed) so 09:15 starts from NSE's 9 Nov close.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0910 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35 (or: bash p186.sh now)"; exit 1; fi
echo "== 1. NSE futures files"
for f in $D/data/nsefut_*.json; do n=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$f" 2>/dev/null || echo 0)
  if [ "$n" -lt 50 ]; then rm -f "$f"; echo "   removed $(basename $f) (empty: $n shares)"; else echo "   kept    $(basename $f) ($n shares)"; fi; done
for f in flow.py livecheck.py nseaudit.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
python3 - "$D" <<'PY'
import sys, os
D = sys.argv[1]; done = []
E = {"flow.py": [('if os.path.basename(f)[7:17] < str(day)[:10])', 'if os.path.basename(f)[7:17] < str(day)[:10] and os.path.getsize(f) > 500)   # patch 186: never an empty file')],
     "livecheck.py": [('if os.path.basename(f)[7:17] < str(day))', 'if os.path.basename(f)[7:17] < str(day) and os.path.getsize(f) > 500)   # patch 186')],
     "nseaudit.py": [('        json.dump({s: [F[0][2], F[0][3], F[0][1], F[0][0]] for s, F in FUT.items() if F}', '        FUT and json.dump({s: [F[0][2], F[0][3], F[0][1], F[0][0]] for s, F in FUT.items() if F}'),
                     ('        json.dump({s: [F[0][2], F[0][3], F[0][1]] for s, F in FUT.items() if F}', '        FUT and json.dump({s: [F[0][2], F[0][3], F[0][1]] for s, F in FUT.items() if F}')]}
for fn, eds in E.items():
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    for a, b in eds:
        if a in s and b not in s:
            s = s.replace(a, b); done.append(fn)
    open(p, "w", encoding="utf-8").write(s)
print("   patched: %s" % (", ".join(sorted(set(done))) or "nothing (already)"))
PY
cd $D && python3 -m py_compile flow.py nseaudit.py && { [ ! -f livecheck.py ] || python3 -m py_compile livecheck.py; } || { for f in flow.py livecheck.py nseaudit.py; do [ -f $f.bak$TS ] && cp $f.bak$TS $f; done; echo "does not compile - old files back"; exit 1; }
echo "== 2. what the engine will start from at 09:15"
python3 - <<'PY' 2>&1 | sed 's/^/   /'
import sys, datetime as dt; sys.path.insert(0, "/home/globalbot/intraday")
import flow
futs = {s: (0, s, dt.date(2026, 11, 24)) for s in ("ICICIBANK", "COROMANDEL", "INDIANB", "RVNL", "MAHABANK")}
b, d0 = flow.nse_base("2026-11-11", futs)
print("NSE file used: %s · %d of 5 shares found: %s" % (d0, len(b), ", ".join("%s %s" % (k, int(v)) for k, v in b.items())))
import json, glob
N = json.load(open(sorted(f for f in glob.glob("/home/globalbot/intraday/data/nsefut_*.json"))[-1]))
for s in ("COROMANDEL", "INDIANB", "RVNL", "SAGILITY", "MAHABANK", "ULTRACEMCO", "JSWSTEEL", "MCX", "CUMMINSIND", "BAJFINANCE"):
    x = N.get(s); print("%-11s NSE OI %s" % (s, ("%+.2f%%" % (x[1] / (x[0] - x[1]) * 100)) if x and x[0] - x[1] > 0 else "-"))
PY
rm -f $D/oibase_$(TZ=Asia/Kolkata date +%Y-%m-%d).json
systemctl restart gir-intraday && sleep 6 && echo "== 3. engine restarted: $(systemctl is-active gir-intraday) - 09:15 starts from NSE's figures"
systemctl restart gir-dash >/dev/null 2>&1 &
echo
echo "PATCH 186 APPLIED. Send Claude a screenshot of section 2."
