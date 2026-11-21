#!/bin/bash
# PATCH 158 - 🌅 OPENING CALL and ⚡ ENTER NOW skip NSE holidays (GIR's holidays.py - NSE's own list; 10 Nov 2026 added).
#   enternow.py · opencall.py · holidays.py. Restarts gir-intraday so ENTER NOW picks it up - safe today (holiday) or outside 08:45-15:35.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g158; mkdir -p $W
grep -q "patch 158" $D/opencall.py && { echo "patch 158 is already installed"; exit 1; }
F="enternow.py opencall.py holidays.py"; for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-intraday; echo "ERROR - old files back"; exit 1; }
cat > $W/p158_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p158_patch.py - PATCH 158: 🌅 OPENING CALL and ⚡ ENTER NOW skip NSE holidays (holidays.py - NSE's own list, cached; 10 Nov 2026 added to
its built-in list). On a holiday Kite still shows the last session's prices - the 09:20 check could have read yesterday's move as today's.
Usage: python3 p158_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
F = {
 "enternow.py": [('    if ST["busy"] or now.weekday() > 4:\n        return False',
                  '    if ST["busy"] or now.weekday() > 4:\n        return False\n    try:                                                         # patch 158: an NSE holiday\n        import holidays\n        if holidays.holiday(now.date()):\n            return False\n    except Exception:\n        pass')],
 "opencall.py": [('    if now.weekday() > 4 and "--force" not in sys.argv:\n        print("weekend"); sys.exit(0)',
                  '    if now.weekday() > 4 and "--force" not in sys.argv:\n        print("weekend"); sys.exit(0)\n    try:                                                         # patch 158: an NSE holiday\n        import holidays\n        h_ = holidays.holiday(now.date())\n        if h_ and "--force" not in sys.argv:\n            print("NSE holiday: %s - nothing run" % h_); sys.exit(0)\n    except SystemExit:\n        raise\n    except Exception:\n        pass')],
 "holidays.py": [('KNOWN = {"2026-10-20": "Dussehra",', 'KNOWN = {"2026-11-10": "Diwali Balipratipada", "2026-10-20": "Dussehra",   # patch 158: + 10 Nov')],
}
out = {}
for fn, eds in F.items():
    p = os.path.join(D, fn); s = open(p, encoding="utf-8").read()
    if "patch 158" in s:
        print("patch 158 is already in %s" % fn); sys.exit(1)
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s" % (s.count(a), fn)); sys.exit(1)
        s = s.replace(a, b)
    out[p] = s
for p, s in out.items():
    open(p, "w", encoding="utf-8").write(s)
print("patched: %s" % ", ".join(sorted(F)))
PY_PATCH
python3 $W/p158_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile enternow.py opencall.py holidays.py || back
for t in p143test.py p142test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
python3 -c "import holidays, datetime as dt; d=dt.date.today(); print('    today (%s): %s' % (d, holidays.holiday(d) or 'a trading day')); n=holidays.next_trading_day(d); print('    next trading day: %s' % n)"
systemctl restart gir-intraday && sleep 10; [ "$(systemctl is-active gir-intraday)" = "active" ] || back
echo "PATCH 158 APPLIED. Holidays are skipped from now on - no manual pause needed again."
