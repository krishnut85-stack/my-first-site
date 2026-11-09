#!/bin/bash
# PATCH 143b - 🌅 OPENING CALL uses yesterday's futures build-up only when it IS the last session's (on 9 Nov evening the daily
#   file still held 6 Nov - ASTRAL, BOSCHLTD, DATAPATTNS... came from Friday). opencall.py only - no restart (the 09:12 timer
#   starts a fresh run). Safe any time.
D=/home/globalbot/intraday
grep -q "patch 143b" $D/opencall.py && { echo "patch 143b is already installed"; exit 1; }
A='        if dd:'
[ "$(grep -c "^$A\$" $D/opencall.py)" = "1" ] || { echo "ANCHOR not found once - nothing changed"; exit 1; }
cp $D/opencall.py $D/opencall.py.bak$(date +%m%d%H%M)
sed -i "s/^        if dd:\$/        if dd and dd == d0:                                      # patch 143b: only the last session's money/" $D/opencall.py
cd $D && python3 -m py_compile opencall.py && timeout 120 python3 p143test.py > /dev/null 2>&1 && echo "    p143test.py passed" || { cp $(ls -t $D/opencall.py.bak* | head -1) $D/opencall.py; echo "ERROR - old file back"; exit 1; }
echo "    the reasons for the next open now:"
python3 -c "
import opencall, datetime as dt
C = opencall.candidates(dt.datetime.now(opencall.IST) + dt.timedelta(hours=12), opencall.fo_list())
print('      ' + ' · '.join('%s (%s)' % (s, c['kind'][0]) for s, c in sorted(C.items())))
print('      %d shares - money: %d' % (len(C), sum(1 for c in C.values() if 'money' in c['kind'])))
"
echo "PATCH 143b APPLIED."
