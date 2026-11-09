#!/bin/bash
# PATCH 145 - THE MARKET PAGE REORGANISED. A laptop: the panels 56% of the screen high each, bigger text; ⚡ EARLY at most a
#   quarter of the screen, and after the close it folds to its title (tap = open); the alert chips fold after the close (the
#   tabs stay); SECTORS: NSE's own index % first, the F&O shares' average beside it, groups of under 3 shares last.
#   home.html only. Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g145; mkdir -p $W
grep -q "patch 145" $D/home.html && { echo "patch 145 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/legend_old.txt <<'TXT_LEG'
const lx=cx+R+14, lh=Math.max(11,Math.min(16,(H-8)/S.length)); g+=S.slice().sort((a,b)=>(b.chg??-99)-(a.chg??-99)).map((x,i)=>`<g class="k" onclick="mkSec('${esc(x.name)}')"><rect x="${lx}" y="${6+i*lh}" width="9" height="${lh-3}" fill="${mkHeat(x.chg)}"/><text x="${lx+14}" y="${6+i*lh+lh-5}" fill="var(--txt)" font-size="9">${esc(x.name.toUpperCase().slice(0,14))} <tspan fill="var(--dim)">${x.n}</tspan></text><text x="${W-6}" y="${6+i*lh+lh-5}" fill="${(x.chg||0)>=0?"var(--up)":"var(--dn)"}" font-size="9" text-anchor="end">${mkPc(x.chg)}</text>${(si=>si&&si.chg!=null?`<text x="${W-50}" y="${6+i*lh+lh-5}" fill="var(--dim)" font-size="8" text-anchor="end">index ${(si.chg>=0?"+":"")+si.chg.toFixed(2)}</text>`:"")(secIdx(x.name))}</g>`).join("");
TXT_LEG
cat > $W/p145_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p145_patch.py - PATCH 145: THE MARKET PAGE, REORGANISED (Rama, 9 Nov 19:55: "the alert board occupies half the laptop, the bottom
is small small small; the alerts are not needed after the close; the sector performance is wrong").
  1. a laptop: the panels are 56% of the screen high each (the page scrolls), the text bigger (12.5 px)
  2. ⚡ EARLY: at most a quarter of the screen in market hours; after the close it folds to its title line (tap it to open)
  3. the alert bar: after the close the chips fold away (the tabs stay: a tap = the day's list)
  4. SECTORS: NSE's own index % first (bold), the F&O shares' average beside it, a group of under 3 F&O shares last and dimmed;
     on a narrow panel the ring makes room for the list
Usage: python3 p145_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
HERE = os.path.dirname(os.path.abspath(__file__))
LEG_OLD = open(os.path.join(HERE, "legend_old.txt"), encoding="utf-8").read() if os.path.exists(os.path.join(HERE, "legend_old.txt")) else None
LEG_NEW = r'''const lx=(W<430?6:cx+R+14), lh=Math.max(13,Math.min(19,(H-24)/S.length)), fs=lh>=16?11:10;      /* patch 145: NSE's index first, the F&O average beside it */
      const rk=x=>{ const si=secIdx(x.name); return (x.n<3?-1000:0)+(si&&si.chg!=null?si.chg:(x.chg??-99)); };
      if(W<430) g=`<text x="6" y="12" fill="var(--dim)" font-size="9">F&amp;O ${mkPc(av)}</text>`;
      g+=`<text x="${W-64}" y="12" fill="var(--dim)" font-size="9" text-anchor="end">NSE INDEX</text><text x="${W-6}" y="12" fill="var(--dim)" font-size="9" text-anchor="end">F&amp;O AVG</text>`;
      g+=S.slice().sort((a,b)=>rk(b)-rk(a)).map((x,i)=>{ const si=secIdx(x.name), ic=si&&si.chg!=null?si.chg:null, y0=20+i*lh, yt=y0+lh-4, few=x.n<3;
        return `<g class="k" onclick="mkSec('${esc(x.name)}')" opacity="${few?0.5:1}"><rect x="${lx}" y="${y0}" width="9" height="${lh-3}" fill="${mkHeat(ic!=null?ic:x.chg)}"/><text x="${lx+14}" y="${yt}" fill="var(--txt)" font-size="${fs}">${esc(x.name.toUpperCase().slice(0,W<430?18:14))} <tspan fill="var(--dim)">${x.n}</tspan></text><text x="${W-64}" y="${yt}" fill="${ic==null?"var(--dim)":ic>=0?"var(--up)":"var(--dn)"}" font-size="${fs}" font-weight="700" text-anchor="end">${ic==null?"—":mkPc(ic)}</text><text x="${W-6}" y="${yt}" fill="var(--dim)" font-size="${fs-1}" text-anchor="end">${mkPc(x.chg)}</text><title>${esc(x.name)}: NSE index ${ic==null?"none":mkPc(ic)} · the average of its ${x.n} F&amp;O shares ${mkPc(x.chg)}${few?" · under 3 F&O shares - listed last":""}</title></g>`; }).join("");'''
CSS = '''/* patch 145: the market page reorganised - bigger panels, ⚡ EARLY folds after the close, the alert chips fold after the close */
@media(min-width:1100px){
  #mk{height:auto;grid-template-rows:auto 56vh 56vh;font-size:12.5px}
  #mk .q h3{font-size:11.5px;padding:4px 8px}
  #q-ear{max-height:none}#q-ear .bd{max-height:25vh}
}
body.earopen #q-ear .bd{max-height:62vh !important}
#q-ear h3{cursor:pointer}
body.mclosed:not(.earopen) #q-ear .bd{display:none}
body.mclosed:not(.earopen) #q-ear h3::after{content:"▸ market closed - tap to open";color:var(--dim);margin-left:auto;font-weight:400}
body.mclosed #abar:not(.lane) .ac{display:none}
body.mclosed #abar .al::after{content:" · CLOSED - tap a tab for the day's list";font-weight:400;letter-spacing:0}
'''
JS = '''/* patch 145: after the close (and before 09:00) the EARLY board and the alert chips fold - the market panels take the room */
function mktOpenNow(){ const t=new Date(Date.now()+19800000), m=t.getUTCHours()*60+t.getUTCMinutes(), wd=t.getUTCDay(); return wd>=1&&wd<=5&&m>=540&&m<=935; }
function mktClass(){ document.body.classList.toggle("mclosed",!mktOpenNow()); }
function earToggle(){ document.body.classList.toggle("earopen"); }
mktClass(); setInterval(mktClass,60000);
{ const h_=document.querySelector("#q-ear h3"); if(h_){ h_.title="tap: open / fold the EARLY board"; h_.addEventListener("click",earToggle); } }
function drawEarly(){'''
EDITS = [
    ("    else { const R=Math.min(H/2-12,W*0.23), cx=R+10, cy=H/2, r=R*0.52;", "    else { const R=Math.min(H/2-12,W*0.23), cx=R+10, cy=H/2, r=R*(W<430?0:0.52);"),
    ("#focus table.oi{width:100%;", CSS + "#focus table.oi{width:100%;"),
    ("function drawEarly(){", JS),
]


def main():
    p = os.path.join(D, "home.html")
    s = open(p, encoding="utf-8").read()
    if "patch 145" in s:
        print("patch 145 is already in home.html"); return 1
    eds = list(EDITS) + [(LEG_OLD, LEG_NEW)]
    for a, b in eds:
        n = s.count(a) if a else 0
        if n != 1:
            print("ANCHOR %s x%d: %s" % ("missing" if n == 0 else "not unique", n, (a or "?")[:90].replace("\\n", " | ")))
            return 1
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8").write(s)
    print("patched: home.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
python3 - "$W/legend_old.txt" <<'PY_TRIM'
import sys; p = sys.argv[1]; s = open(p, encoding="utf-8").read(); open(p, "w", encoding="utf-8").write(s[:-1] if s.endswith("\n") else s)
PY_TRIM
python3 $W/p145_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && for t in p143test.py p142test.py p140ftest.py p136test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 145 APPLIED. Reload the GIR page (Ctrl+F5): bigger panels; ⚡ EARLY folded after the close (tap its title); SECTORS = NSE's index first."
