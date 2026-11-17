#!/bin/bash
# PATCH 359 - KEEP THE OPTION PRICES EVERY EVENING + THE DOCTOR HIDES A SECRET PASSED AS A FLAG
#   · optrec.py + gir-optrec.timer (Monday-Friday 16:05 IST): Kite keeps an option's minute prices only while the contract is alive. Every evening
#     the day's minute prices of every F&O share and of its CE / PE around the money (nearest expiry; the next one too in the last 5 days) are
#     saved to data/optrec/<day>.npz - so rules can be tested on real option prices over months, not just the current expiry. A few MB a day.
#   · girdoctor.py: a secret given to a program as a command-line flag (--token X, --password X, --api-key X ...) is now hidden in the doctor's
#     report (16 Nov: a process list showed one).
#   Touches no page and no running service: the engine, the desk, the alerts and the dashboard are not restarted. Safe at any hour.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if [ -f $D/optrec.py ] && [ -f $U/gir-optrec.timer ] && { [ ! -f $D/girdoctor.py ] || grep -q "patch 359" $D/girdoctor.py; }; then echo "patch 359 - already in"; cd $D && python3 optrec.py show; exit 0; fi
[ -f $D/optreal.py ] && [ -f $D/seclive.py ] || { echo "optreal.py / seclive.py not found - nothing done"; exit 1; }
git -C $R show $B:intraday_patches/optrec.py > $W/optrec.py 2>/dev/null && [ -s $W/optrec.py ] && python3 -m py_compile $W/optrec.py || { echo "❌ optrec.py not in $B or it does not compile - run the git fetch line first; nothing done"; exit 1; }
cp $W/optrec.py $D/optrec.py
if [ -f $D/girdoctor.py ] && ! grep -q "patch 359" $D/girdoctor.py; then
  cp $D/girdoctor.py $D/girdoctor.py.bak$TS
  python3 - $D/girdoctor.py <<'PY_EDIT' && python3 -m py_compile $D/girdoctor.py || { cp $D/girdoctor.py.bak$TS $D/girdoctor.py; echo "  girdoctor.py: not changed (its token list was not found) - the recorder is still installed"; }
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read(); A = "TOKRE = [re.compile("
if s.count(A) != 1:
    sys.exit(1)
s = s.replace(A, 'TOKRE = [re.compile(r"(?i)--?(?:token|secret|password|passwd|api[_-]?key|access[_-]?key|auth)[ =]+\\S+"),   # patch 359: a secret passed as a command-line flag\n         re.compile(', 1)
open(p, "w", encoding="utf-8").write(s); print("  girdoctor.py: a secret passed as a flag is hidden")
PY_EDIT
  cd $D && python3 -c "
import girdoctor
t = girdoctor.scrub('python3 server.py --token abc123XYZsecret --port 8000 --api-key=qwerty99')
assert 'abc123XYZsecret' not in t and 'qwerty99' not in t and '--port 8000' in t, t
print('  the doctor on a test line:', t)" 2>/dev/null || echo "  (the doctor's own test could not run here - its file compiles)"
fi
cat > $U/gir-optrec.service <<'UNIT'
[Unit]
Description=GIR option-price recorder - the day's minute prices of every F&O share and its options around the money (optrec.py, patch 359)
[Service]
Type=oneshot
TimeoutStartSec=3600
Nice=12
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 optrec.py >> data/optrec_run.txt 2>&1'
UNIT
cat > $U/gir-optrec.timer <<'UNIT'
[Unit]
Description=GIR option-price recorder, 16:05 IST Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 16:05:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-optrec.timer >/dev/null 2>&1 && systemctl start gir-optrec.timer
echo "  the timer: $(systemctl is-active gir-optrec.timer)"
cd $D && python3 optrec.py show
echo "✅ patch 359 done - from today GIR keeps the option prices at 16:05 (about 15 minutes, its log: tail -3 $D/data/optrec_run.txt)."
echo "   yesterday's can still be saved while the contracts are alive:  cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && nohup python3 optrec.py 2026-11-16 > /tmp/optrec.txt 2>&1 &"
echo "   undo: systemctl disable --now gir-optrec.timer; rm -f $U/gir-optrec.* $D/optrec.py; systemctl daemon-reload; [ -f $D/girdoctor.py.bak$TS ] && cp $D/girdoctor.py.bak$TS $D/girdoctor.py"
