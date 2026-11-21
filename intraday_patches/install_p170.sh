#!/bin/bash
# PATCH 170 - the NIFTY / BANKNIFTY chart says CE / PE: "CEILING (CE)" and "FLOOR (PE)" instead of "(call writers)" / "(put writers)".
#   The WALLS button's hint: CEILING = the strike with the most CE open interest above the price, FLOOR = the most PE below.
#   The page file only - nothing restarts; reload the page.
set -u
D=/home/globalbot/intraday; F=$D/home.html; TS=$(date +%m%d%H%M%S)
[ -f $F ] || { echo "home.html not found"; exit 1; }
cp $F $F.bak$TS
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
E = [('"CEILING (call writers)"', '"CEILING (CE)"'), ('"FLOOR (put writers)"', '"FLOOR (PE)"'),
     ("FLOOR / CEILING - the option writers' walls (the options desk)", "CEILING = the strike with the most CE open interest above the price · FLOOR = the most PE below (the options desk)")]
n = 0
for a, b in E:
    if a in s:
        s = s.replace(a, b); n += 1
open(p, "w", encoding="utf-8").write(s)
print("changed %d of %d labels" % (n, len(E)))
PY
grep -q '"CEILING (CE)"' $F && grep -q '"FLOOR (PE)"' $F && echo "PATCH 170 APPLIED - reload the page: the chart reads CEILING (CE) and FLOOR (PE)." || { cp $F.bak$TS $F; echo "labels not found - nothing changed; send this to Claude"; exit 1; }
