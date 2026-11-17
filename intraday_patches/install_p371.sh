#!/bin/bash
# PATCH 371 - EVERY SHARE IN ITS RIGHT SECTOR (Rama, 17 Nov: "you have not done your basics - which share belongs to which sector").
#   secaudit.py on the server (10:59) checked all 743 NSE shares against NSE's own sector index lists, NSE's sector and the company's name.
#   GIR's sector for a share comes from nsesec.sector_of() - the page's F&O sectors and the sector % (seclive) both - so one list there fixes
#   both. Moved:
#     ASHOKLEY    capital goods   -> auto              NSE's Nifty Auto - a truck and bus maker
#     APLAPOLLO   capital goods   -> metals & mining   NSE's Nifty Metal - steel tubes
#     GROWW       nbfc & finance  -> capital markets   NSE's Nifty Capital Markets - a stock broker (not F&O, counts in the sector %)
#     MFSL        nbfc & finance  -> insurance         Max Financial's only business is Axis Max Life Insurance
#     IEX         capital markets -> power             Rama's earlier choice - India's power exchange trades with the power sector's news
#   (NAM-INDIA and ABSLAMC are patch 370.) Kept as they are, on purpose: AMBER / DIXON / PGEL in ELECTRONICS & HARDWARE (NSE says consumer
#   durables - GIR splits the electronics makers out, 354c) · KRN Heat EXCHANGER and ION EXCHANGE (the checker's name rule read "exchange")
#   · SUDEEPPHRM in chemicals (NSE's sector). secaudit.py is updated to know these, so a re-run shows only real disagreements.
#   Edits nsesec.py (one list, backed up). Restarts the sector reader and the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 371" $D/nsesec.py; then echo "patch 371 - already in"; exit 0; fi
grep -q "patch 370" $D/nsesec.py || { echo "patch 370 is not in yet - run install_p370.sh first; nothing done"; exit 1; }
cp $D/nsesec.py $D/nsesec.py.bak$TS
back(){ cp $D/nsesec.py.bak$TS $D/nsesec.py; systemctl restart gir-seclive gir-dash; echo "❌ old nsesec.py back - nothing changed"; exit 1; }
python3 - $D/nsesec.py <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
a = "    ind = (nse or {}).get(sym)\n"
b = ("    if sym in OVR:                                                         # patch 371: checked by secaudit.py against NSE's sector indices\n"
     "        return OVR[sym]\n" + a)
if t.count(a) != 1 or "def sector_of" not in t:
    print("❌ nsesec.py: sector_of() not as expected (%d)" % t.count(a)); sys.exit(1)
t = t.replace(a, b)
ovr = ('\n# patch 371: shares whose sector the rules got wrong - checked by secaudit.py (NSE\'s sector index lists, 17 Nov)\n'
       'OVR = {"ASHOKLEY": "auto", "APLAPOLLO": "metals & mining", "GROWW": "capital markets", "MFSL": "insurance", "IEX": "power"}\n\n')
i = t.find("\ndef sector_of")
t = t[:i] + ovr + t[i + 1:]
open(p, "w", encoding="utf-8").write(t); print("  nsesec.py: 5 shares moved to their right sector")
PY_EDIT
cd $D && python3 - <<'PY_CHECK' || back
import nsesec as N
T = {"ASHOKLEY": "auto", "APLAPOLLO": "metals & mining", "GROWW": "capital markets", "MFSL": "insurance", "IEX": "power"}
bad = [(s, N.sector_of(s, {s: "Capital Goods"}, {}, {}), v) for s, v in T.items() if N.sector_of(s, {s: "Capital Goods"}, {}, {}) != v]
if bad:
    print("  ❌", bad); raise SystemExit(1)
print("  the 5 moves checked ✓")
try:
    import seclive
    SEC, _ = seclive.universe()
    for s in ("ASHOKLEY", "APLAPOLLO", "GROWW", "MFSL", "IEX", "NAM-INDIA", "ABSLAMC", "HDFCBANK", "SBILIFE", "TATAMOTORS", "TMPV", "TATASTEEL"):
        if s in SEC:
            print("   %-10s -> %s" % (s, SEC[s]))
except Exception as ex:
    print("   (the live list was not read: %s)" % str(ex)[:80])
PY_CHECK
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 8
echo "  gir-seclive: $(systemctl is-active gir-seclive) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-seclive)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 371 done - refresh GIR (Ctrl+Shift+R). Check: cd $D && nice -n 15 python3 secaudit.py   (part 1 should list nothing)"
echo "   undo: cp $D/nsesec.py.bak$TS $D/nsesec.py; systemctl restart gir-seclive gir-dash"
