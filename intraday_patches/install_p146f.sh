#!/bin/bash
# PATCH 146f - THE PAGE NEVER WAITS FOR NSE. 146e read nseindia.com inside the page request; NSE is slow in the evening, so the market
#   panel and 146e's installer hung. Now NSE is read in the background (index list every 5 min, FII / DII every 20 min); the page
#   answers at once with what it has. Installs 146e first if it is not in. Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g146f; mkdir -p $W
grep -q "patch 146f" $D/dashserve.py && { echo "patch 146f is already installed"; exit 1; }
if ! grep -q "patch 146e" $D/dashserve.py; then
  echo "    installing 146e first"
  cd /root/sectorbot && git show origin/ccr-67e340f1-sko8xd:intraday_patches/install_p146e.sh | sed 's#^curl -s "http://127.0.0.1:8090/market#curl -s -m 15 "http://127.0.0.1:8090/market#' > /tmp/install_p146e.sh && (cd /tmp && timeout 300 bash install_p146e.sh | grep -E "passed|failed|APPLIED|ERROR|nothing")
  grep -q "patch 146e" $D/dashserve.py || { echo "146e did not go in - send this to Claude"; exit 1; }
fi
cp $D/dashserve.py $D/dashserve.py.bak$TS
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "ERROR - old file back"; exit 1; }
cat > $W/p146f_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p146f_patch.py - PATCH 146f: NSE IS READ IN THE BACKGROUND - THE PAGE NEVER WAITS FOR IT. 146e asked nseindia.com for FII / DII and
the sector indices while serving the page; NSE is slow in the evening, so the market panel (and 146e's installer) hung. Now a
background thread refreshes NSE's index list (5 min) and FII / DII (20 min, 8 s per file, 6 days back at most); a request only
reads what is already there.
Usage: python3 p146f_patch.py /home/globalbot/intraday  (needs 146e)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''    if fetch is None and time.time() - _NSEI["t"] < 300:
        return _NSEI["v"]''',
     '''    if fetch is None:                                            # patch 146f: never wait for NSE in a request
        if time.time() - _NSEI["t"] >= 300 and not _NSEI.get("busy"):
            _NSEI["busy"] = True
            _NSEI["t"] = time.time()

            def bg_():
                try:
                    import exchange
                    _nse_indices(exchange.nse_json)
                except Exception:
                    pass
                finally:
                    _NSEI["busy"] = False
            threading.Thread(target=bg_, daemon=True).start()
        return _NSEI["v"]'''),
    ('''    if get is None and _FII["v"] is not None and time.time() - _FII["t"] < 1200:
        return _FII["v"]''',
     '''    if get is None:                                              # patch 146f: never wait for NSE in a request
        if time.time() - _FII["t"] >= 1200 and not _FII.get("busy"):
            _FII["busy"] = True
            _FII["t"] = time.time()

            def get_(u):
                if u == "cash":
                    import exchange
                    return exchange.nse_json("/api/fiidiiTradeReact") or []
                import requests
                r_ = requests.get(u, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"}, timeout=8)
                return r_.text if r_.status_code == 200 else ""

            def bg_():
                try:
                    v_ = _fii_nse(get_)
                    if v_:
                        _FII["v"] = v_
                except Exception:
                    pass
                finally:
                    _FII["busy"] = False
            threading.Thread(target=bg_, daemon=True).start()
        return _FII["v"] or {}'''),
    ('''    for _ in range(10):
        if d.weekday() < 5 or d == dt.date(2026, 11, 8):''', '''    for _ in range(6):
        if d.weekday() < 5 or d == dt.date(2026, 11, 8):'''),
]
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if "patch 146f" in s:
    print("patch 146f is already in dashserve.py"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:90].replace("\n", " | "))); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: dashserve.py")
PY_PATCH
python3 $W/p146f_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || back
for t in p146etest.py p146btest.py p145etest.py p145btest.py p145dtest.py p142test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
K=$(cat $D/dash_token.txt)
curl -s -m 15 -o /dev/null "http://127.0.0.1:8090/market?k=$K"; echo "    reading NSE in the background (40 s)..."; sleep 40
curl -s -m 15 "http://127.0.0.1:8090/market?k=$K" | python3 -c "
import json, sys
M = json.load(sys.stdin)
S = M.get('sidx') or {}
print('      sectors: ' + ' · '.join('%s %s' % (n.replace('NIFTY ', ''), ('%+.2f%%' % v['chg']) if v.get('chg') is not None else '—') for n, v in sorted(S.items())))
F = M.get('fii_nse') or {}
print('      FII / DII cash: %s' % (F.get('cash') or 'still reading - it fills in by itself'))
fo = F.get('fo') or {}
print('      FII in F&O %s: ' % fo.get('date') + ' · '.join('%s net %s' % (k, int(v['net'])) for k, v in fo.items() if isinstance(v, dict)))
" || echo "      (the page answered slowly - send this to Claude)"
echo
echo "PATCH 146f APPLIED. Reload the GIR page with Ctrl+F5."
