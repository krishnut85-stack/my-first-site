#!/bin/bash
# PATCH 190 - F&O MONEY kept only the 20 shares with the most ₹ per build-up, so a big OI % with smaller money (COROMANDEL +13.2%,
#   MAHABANK +6.5%) never reached the page - and sorting by OI % could not bring it back. Now every share of each build-up is sent.
#   gir-dash restarts (502 for up to 2 minutes) - run it NOW (before 09:10) or after 15:35.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0910 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35"; exit 1; fi
cp $D/dashserve.py $D/dashserve.py.bak$TS
python3 - "$D/dashserve.py" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
a = 'key=lambda f: -abs(f.get("cr") or 0))[:20]   # patch 147: 20 a block - the page sorts'
if a in s:
    s = s.replace(a, 'key=lambda f: -abs(f.get("cr") or 0))   # patch 190: every share of the block - the page sorts (OI % too)')
    open(p, "w", encoding="utf-8").write(s); print("dashserve.py: every share of each build-up")
elif "patch 190" in s:
    print("already in")
else:
    print("the line was not found"); sys.exit(1)
PY
[ $? = 0 ] || { cp $D/dashserve.py.bak$TS $D/dashserve.py; exit 1; }
cd $D && python3 -m py_compile dashserve.py || { cp $D/dashserve.py.bak$TS $D/dashserve.py; echo "old file back"; exit 1; }
echo -n "the page server restarting"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "✅ the page is back - Ctrl + Shift + R, F&O MONEY, tap OI %" || { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "❌ old file back"; exit 1; }
