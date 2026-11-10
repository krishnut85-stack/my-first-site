#!/bin/bash
# PATCH 167b - close the old http://64.227.155.177:8090 address to the outside (the website https://girtrader.com stays the only way in).
#   167 reopened it because the page server was checked only 6 s after its restart; this waits up to 90 s and shows what it sees.
set -u
DOM=${1:-girtrader.com}; D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
code() { curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$1"; }
wait_ok() { for i in $(seq 1 18); do l=$(code http://127.0.0.1:8090/login); h=$(code https://$DOM/login); [ "$l" = "200" ] && [ "$h" = "200" ] && return 0; sleep 5; done; return 1; }
echo "== now: inside $(code http://127.0.0.1:8090/login) · website $(code https://$DOM/login) (200 = answering)"
if grep -q 'ThreadingHTTPServer(("127.0.0.1", port), H)' $D/dashserve.py; then echo "   already closed to the outside"; else
  cp $D/dashserve.py $D/dashserve.py.bak$TS
  sed -i 's/ThreadingHTTPServer(("0.0.0.0", port), H)/ThreadingHTTPServer(("127.0.0.1", port), H)   # patch 167: only through the https website/' $D/dashserve.py
  grep -q 'ThreadingHTTPServer(("127.0.0.1", port), H)' $D/dashserve.py || { echo "   the line to change was not found - nothing changed; send this to Claude"; exit 1; }
  systemctl restart gir-dash
  echo -n "== the page server restarting (up to 90 s)"
  if wait_ok; then echo; echo "   ✅ the website answers · the old :8090 address is closed to the outside"; else
    echo; echo "   ❌ inside $(code http://127.0.0.1:8090/login) · website $(code https://$DOM/login) - putting it back"
    ss -ltnp 2>/dev/null | grep 8090 | sed 's/^/     /'; journalctl -u gir-dash -n 8 --no-pager 2>/dev/null | cut -c1-180 | sed 's/^/     /'
    cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "   old file back - send this to Claude"; exit 1; fi
fi
echo "== from outside: the old address must NOT answer now"
ss -ltn 2>/dev/null | grep ":8090 " | sed 's/^/   listening on: /'
echo
echo "PATCH 167b APPLIED. GIR is at https://$DOM only."
