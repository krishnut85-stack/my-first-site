#!/bin/bash
# PATCH 146c - BULLISH / BEARISH ON EVERY BUILD-UP. F&O MONEY: LONG BUILD-UP ▲ BULLISH strong · SHORT BUILD-UP ▼ BEARISH strong ·
#   SHORT COVERING ▲ BULLISH weaker · LONG UNWINDING ▼ BEARISH weaker; the legend explains; OI BUILD-UP BY SECTOR's columns ▲ / ▼;
#   the panel names where the OI figures come from. home.html · dashserve.py. Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g146c; mkdir -p $W
grep -q "patch 146c" $D/home.html && { echo "patch 146c is already installed"; exit 1; }
for f in home.html dashserve.py; do cp $D/$f $D/$f.bak$TS; done
back() { for f in home.html dashserve.py; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p146c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p146c_patch.py - PATCH 146c: EVERY BUILD-UP SAYS BULLISH OR BEARISH (Rama, 9 Nov 20:35). F&O MONEY: each block's title -
LONG BUILD-UP ▲ BULLISH · strong, SHORT BUILD-UP ▼ BEARISH · strong, SHORT COVERING ▲ BULLISH · weaker (sellers leaving), LONG
UNWINDING ▼ BEARISH · weaker (buyers leaving); the legend says it too; OI BUILD-UP BY SECTOR's columns carry ▲ / ▼; the source of
the OI figures is named (NSE's end-of-day file after the close, Kite live in the session).
Usage: python3 p146c_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''  { const mo=M.money||{}; const blk=(b,c)=>{ const xs=mo[b]||[]; return `<div><h4 class="${c}">${b}</h4>''',
     '''  { const mo=M.money||{}; const BIAS={"LONG BUILD-UP":"▲ BULLISH · strong - fresh buying","SHORT BUILD-UP":"▼ BEARISH · strong - fresh selling","SHORT COVERING":"▲ BULLISH · weaker - sellers leaving","LONG UNWINDING":"▼ BEARISH · weaker - buyers leaving"};   /* patch 146c */
    const blk=(b,c)=>{ const xs=mo[b]||[]; return `<div><h4 class="${c}">${b} <small style="font-weight:400">${BIAS[b]}</small></h4>'''),
    ('''<div class="legend" style="padding:3px 6px">LONG BUILD-UP = price up + OI up (fresh buying) · SHORT BUILD-UP = price down + OI up (fresh selling) · SHORT COVERING = price up + OI down · LONG UNWINDING = price down + OI down</div>`; }''',
     '''<div class="legend" style="padding:3px 6px"><b class="pu">BULLISH</b>: LONG BUILD-UP (price up + OI up - fresh buying, the strong one) · SHORT COVERING (price up + OI down - sellers leaving, weaker: it can fade once they are out) · <b class="pd">BEARISH</b>: SHORT BUILD-UP (price down + OI up - fresh selling, the strong one) · LONG UNWINDING (price down + OI down - buyers leaving, weaker) · OI: ${M.oi_src?esc(M.oi_src):"Kite live (NSE's official file after 18:40)"}</div>`; }'''),
    ('''const B=[["LONG BUILD-UP","LONG BU",1],["SHORT BUILD-UP","SHORT BU",-1],["SHORT COVERING","SHORT COV",1],["LONG UNWINDING","LONG UNW",-1]];''',
     '''const B=[["LONG BUILD-UP","LONG BU ▲",1],["SHORT BUILD-UP","SHORT BU ▼",-1],["SHORT COVERING","SHORT COV ▲",1],["LONG UNWINDING","LONG UNW ▼",-1]];   /* patch 146c: ▲ bullish · ▼ bearish */'''),
]
DASH = [
    ('''"vix": ctx.get("vix"), "fiidii": ctx.get("fiidii"),''', '''"oi_src": st.get("oi_src"), "vix": ctx.get("vix"), "fiidii": ctx.get("fiidii"),'''),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 146c" in s or ('"oi_src": st.get("oi_src")' in s and p.endswith(".py")):
        print("patch 146c is already in %s" % os.path.basename(p)); return None
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), os.path.basename(p), a[:90].replace("\n", " | "))); return None
        s = s.replace(a, b)
    return s


a = apply(os.path.join(D, "home.html"), EDITS)
b = apply(os.path.join(D, "dashserve.py"), DASH)
if a is None or b is None:
    sys.exit(1)
open(os.path.join(D, "home.html"), "w", encoding="utf-8").write(a)
open(os.path.join(D, "dashserve.py"), "w", encoding="utf-8").write(b)
print("patched: home.html, dashserve.py")
PY_PATCH
python3 $W/p146c_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || back
for t in p146btest.py p145etest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 146c APPLIED. Reload the GIR page (Ctrl+F5): F&O MONEY says BULLISH / BEARISH on each block."
