#!/bin/bash
# PATCH 363 - THE BUDGET WATCH IN THE MORNING LIST (with patch 362: the newspapers and the world) (Rama, 17 Nov: "daily Indian newspapers like Business Standard and The Hindu,
#   and worldwide newspapers - will that happen?"). GIR's market desk keeps a headline only when it names India, so the Fed, crude, US shares
#   and metal prices never reached the 🌙 OVERNIGHT list. Now the 08:35 reading also takes the headlines published since the close from:
#     the Indian business papers (The Hindu, BusinessLine, Business Standard, Financial Express) · the world's wires on India (Reuters,
#     Bloomberg, CNBC, FT, WSJ) · US markets and the Fed · commodities (crude, copper, aluminium, steel, gold) · trade and tariffs ·
#     US drug rules and visas - through Google News searches (headlines only; the papers' full text is behind their paywalls).
#   A world headline that names no Indian company is kept only where the link to a sector is direct, at most "moderate", marked "read-across".
#   · mfsec.py: SEBI's mutual-fund page stops at 2025 on SEBI's own site - an old record is no longer given to the page as "now".
#   Patch 363 adds the BUDGET watch (Rama, 17 Nov: "from yesterday the budget meeting started"): pre-budget meetings, what each industry
#   asks for and what officials signal are read too - kept only when they name a sector or a tax F&O shares depend on, rated "weak" (an
#   expectation, not a decision) or "moderate" when an official signals it, and marked "budget:". The list may hold 14 items.
#   Replaces overnight.py and mfsec.py only. No page change, nothing restarted - safe at any hour.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; W=$(mktemp -d)
[ -f $D/overnight.py ] || { echo "patch 358 (overnight.py) first - nothing done"; exit 1; }
if grep -q "patch 363" $D/overnight.py && grep -q "def load(all_=False)" $D/mfsec.py 2>/dev/null; then echo "patch 363 - already in"; else
  for f in overnight.py mfsec.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
  grep -q "patch 363" $W/overnight.py && python3 -m py_compile $W/overnight.py $W/mfsec.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
  for f in overnight.py mfsec.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak363; cp $W/$f $D/$f; done
  echo "  overnight.py and mfsec.py replaced (the old ones: *.bak363)"
fi
cd /home/globalbot && set -a && . ./.env && set +a && cd $D && python3 -c "
import datetime as dt, overnight
now = dt.datetime.now(overnight.IST); since = overnight.last_close(now); Wd = overnight.world(since)
by = {}
for t, src, h in Wd: by[src.split(' · ')[-1]] = by.get(src.split(' · ')[-1], 0) + 1
print('  the papers and the world since %s: %d headlines · %s' % (since.strftime('%d %b %H:%M'), len(Wd), ' · '.join('%s %d' % kv for kv in by.items()) or 'none came back'))
for t, src, h in sorted(Wd)[-5:]: print('    %s · %s · %s' % (t.strftime('%H:%M'), src[:30], h[:95]))
s, L = overnight.lines(now); print('  the whole morning list would read %d lines' % len(L))"
echo "✅ patch 363 done - the next list (08:35 on a market morning) includes them. To make today's again before 09:15:  cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 overnight.py make"
echo "   undo: for f in overnight.py mfsec.py; do cp $D/\$f.bak363 $D/\$f; done"
