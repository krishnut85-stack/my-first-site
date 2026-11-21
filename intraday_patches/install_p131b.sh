#!/bin/bash
# PATCH 131b - THE CHART ON A LATE-STARTING DAY (on top of patch 131).
#   On the Muhurat Sunday (trading 14:20-15:30) the 5-min chart was empty: its slots run from 09:15, the candles sat in a
#   sliver at the far right, and the open (O) was blank. Now the chart starts at the first real candle, the times follow
#   (14:20, 14:50, 15:20) and O is the first real open. Normal days are unchanged.
#   home.html (exact anchors). Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g131b; mkdir -p $W
[ -f $D/girhealth.py ] || { echo "patch 131 is not installed yet - paste patch 131 first"; exit 1; }
grep -q "function chTrim" $D/home.html && { echo "patch 131b is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; rm -f $D/p131btest.py; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p131b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p131b_patch.py - PATCH 131b: THE CHART ON A LATE-STARTING DAY. The day's 5-min file has one slot per 5 min from 09:15; on the
Muhurat Sunday (trading 14:20-15:30) the first ~60 slots were empty, the candles sat in a sliver at the far right and the open
showed blank. Now the chart starts at the first real candle (time labels follow) and O = the first real open.
Usage: python3 p131b_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "home.html": [
        ('''function hhmm(i){ const m=9*60+15+i*5;''', '''/* patch 131b: a day whose trading starts late (a special session) - the chart starts at its first candle */
let HHOFF=0;
function chTrim(ch){ if(!ch||!ch.c||!ch.c.length) return ch; const f=ch.c.findIndex(x=>x!=null); if(f<=6) return Object.assign({},ch,{off:0});
  const s=a=>(a||[]).slice(f); return Object.assign({},ch,{o:s(ch.o),h:s(ch.h),l:s(ch.l),c:s(ch.c),v:s(ch.v),off:f}); }
function hhmm(i){ const m=9*60+15+(i+HHOFF)*5;'''),
        ('''function tradingView(ch,lv,opt){ opt=opt||{};''', '''function tradingView(ch,lv,opt){ opt=opt||{}; ch=chTrim(ch); HHOFF=(ch&&ch.off)||0;'''),
        ('''function candleSVG(ch,lv){ if(!ch||!(ch.c||[]).length)''', '''function candleSVG(ch,lv){ ch=chTrim(ch); HHOFF=(ch&&ch.off)||0; if(!ch||!(ch.c||[]).length)'''),
        ('''const NB=Math.min(75,Math.max(n+6,42));''', '''const NB=HHOFF?Math.max(n+1,12):Math.min(75,Math.max(n+6,42));'''),
        ('''O <b>${n?inr(ch.o[0]):"—"}</b>''', '''O <b>${n?inr(ch.o.find(x=>x!=null)):"—"}</b>'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("home.html: the chart starts at the first candle on a late-starting day")
PY_PATCH
cat > $D/p131btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p131btest.py - the chart on a late-starting day (the Muhurat Sunday): it starts at the first candle, times from 14:20."""
import os, sys, shutil, subprocess
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page trims a late-starting day's empty slots (chart, candles, the open)", "function chTrim(ch)" in pg and "ch=chTrim(ch); HHOFF=" in pg and "ch.o.find(x=>x!=null)" in pg)
node = shutil.which("node")
if node:
    a = pg.index("let HHOFF=0;"); b = pg.index("function hhmm(i)"); e = pg.index("\n", b)
    js = pg[a:e + 1] + r"""
const N=75,f=61,mk=fn=>Array.from({length:N},(_,i)=>i<f?null:fn(i));
const t=chTrim({o:mk(i=>1),h:mk(i=>2),l:mk(i=>0),c:mk(i=>1),v:mk(i=>5)}); HHOFF=t.off;
const n=chTrim({o:[1,2],h:[2,3],l:[0,1],c:[1,2],v:[1,1]});
console.log(JSON.stringify([t.off,t.c.length,hhmm(0),n.off,n.c.length]));"""
    r = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    out = r.stdout.strip()
    check("Muhurat-shaped day: starts at slot 61 = 14:20, 14 candles; a normal day untouched: %s" % (out or r.stderr[:120]), out == '[61,14,"14:20",0,2]')
else:
    print("  (node not on this machine - checked when the patch was built)")
print("\nP131B CHART TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p131b_patch.py $D || { rm -f $D/p131btest.py; echo "the anchors did not match this server's page - nothing was changed"; exit 1; }
cd $D && timeout 60 python3 p131btest.py 2>&1 | grep "OK  \|FAIL\|CHART TEST\|node"
timeout 60 python3 p131btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p129test.py p128test.py p120test.py p114test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function chTrim" || { echo "the new page is not being served"; back; }
echo
echo "PATCH 131b APPLIED. Reload the GIR page: today's charts start at 14:20 with the Muhurat candles."
