#!/bin/bash
# runall.sh - READ ONLY. Every study that is waiting, one after the other, at low priority (safe in market hours: no Kite orders, no restarts):
#   the Indian funds' page check and report (mfsec), when the money shows in the price and the clue (flowpath), which shares of the settled
#   sectors go on (pickstudy 10:00 and 09:45), the zones and the sudden break (zonestudy). Each result is kept in data/<name>.txt; a short
#   DIGEST of the lines that matter is written to data/runall.txt - send that.   cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && bash runall.sh
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; cd $D || exit 1
for f in mfsec flowpath fpisec flowtest pickstudy zonestudy sectortime; do git -C $R show $B:intraday_patches/$f.py > /tmp/_$f.py 2>/dev/null && [ -s /tmp/_$f.py ] && python3 -m py_compile /tmp/_$f.py && cp /tmp/_$f.py $D/$f.py; done
run(){ echo "=== $(TZ=Asia/Kolkata date +%H:%M) $*"; nice -n 15 python3 "$@" > /tmp/_run.txt 2>&1; echo "    done ($(wc -l < /tmp/_run.txt) lines)"; }
run mfsec.py probe;   cp /tmp/_run.txt data/mfsec_probe.txt
run fpisec.py;        # the foreign funds' report, with part 3b (bought after a fall / a rise)
run flowpath.py
if grep -q "the reader: [0-9][0-9]* industries" data/mfsec_probe.txt && ! grep -q "NOT recognised" data/mfsec_probe.txt; then run mfsec.py; else echo "    (SEBI's page was not read - mfsec skipped; its probe is in the digest)"; fi
run pickstudy.py 1000; cp data/pickstudy.txt data/pickstudy_1000.txt 2>/dev/null
run pickstudy.py 0945; cp data/pickstudy.txt data/pickstudy_0945.txt 2>/dev/null
run zonestudy.py
{
  echo "DIGEST $(TZ=Asia/Kolkata date '+%d %b %H:%M') - the lines that matter (each full result: data/<name>.txt)"
  echo; echo "── SEBI's page (mfsec probe)"; grep -E "the reader:|not there|got https|SEBI gave none|not matched" data/mfsec_probe.txt | cut -c1-200 | head -8
  echo; echo "── FOREIGN FUNDS: bought after a fall / a rise (fpisec 3b)"; sed -n '/^3b)/,/^4) NOW/p' data/fpisec.txt 2>/dev/null | grep -E "BOUGHT|SOLD|TURN|yardstick" | cut -c1-210
  echo "   the newest fortnight against each sector's 3 months:"; sed -n '/the newest fortnight (to/,/The states above/p' data/fpisec.txt 2>/dev/null | grep -E "→" | cut -c1-150 | head -24
  echo; echo "── WHEN THE MONEY SHOWS (flowpath)"; sed -n '/^1) THE PATH/,/^saved/p' data/flowpath.txt 2>/dev/null | grep -vE "^saved|^$" | cut -c1-230
  echo; echo "── INDIAN MUTUAL FUNDS (mfsec)"; sed -n '/^1) WHERE THEY ARE/,/^2) THE NET FLOW/p' data/mfsec.txt 2>/dev/null | grep -E "leaning" | cut -c1-140; sed -n '/^3) FUNDS AGAINST/,/^saved/p' data/mfsec.txt 2>/dev/null | grep -vE "^saved|^$" | cut -c1-230
  for t in 1000 0945; do echo; echo "── WHICH SHARES AT ${t:0:2}:${t:2} (pickstudy)"; grep -E "every share of the pool|✔" data/pickstudy_$t.txt 2>/dev/null | cut -c1-215; sed -n '/^WHAT PASSED/,/^saved/p' data/pickstudy_$t.txt 2>/dev/null | grep -vE "^saved" | cut -c1-260; done
  echo; echo "── THE ZONES AND THE SUDDEN BREAK (zonestudy)"; grep -E "yardstick|RSI|in the zones|most oversold|breaks its range|break bar|jolt" data/zonestudy.txt 2>/dev/null | cut -c1-225
} > data/runall.txt 2>&1
echo "=== finished $(TZ=Asia/Kolkata date +%H:%M) - the digest:  cat $D/data/runall.txt"
