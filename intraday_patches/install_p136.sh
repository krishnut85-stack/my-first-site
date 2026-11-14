#!/bin/bash
# PATCH 136 - THE NIFTY CHART WITH THE DAY BEFORE (on top of patch 135b).
#   The MARKET screen's NIFTY chart showed only the day (the Muhurat evening: only 14:20-15:30). Now the session before comes first
#   (Fri 09:15 ...), a line marks the day change, then the day. 1D / 2D / AUTO next to 1m / 5m (AUTO: 2 days while the day has
#   under 40 candles, then 1). The TICK screen says "the market is closed" at night (it said "recording from now").
#   home.html (exact anchors). Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g136; mkdir -p $W
grep -q "patch 135b" $D/oibattle.py 2>/dev/null || { echo "patch 135b is not installed yet - paste patch 135b first"; exit 1; }
grep -q "async function pullNprev" $D/home.html && { echo "patch 136 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; rm -f $D/p136test.py; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p136_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p136_patch.py - PATCH 136: THE NIFTY CHART WITH THE DAY BEFORE. Rama: the NIFTY chart shows only the day (on the Muhurat
evening: only 14:20-15:30). Now the previous session's 5-min candles come first, a line marks the day change, the times follow
(Fri 09:15 ... | 14:20 ... 15:30). A 1D / 2D switch next to 1m / 5m; on its own (AUTO) it shows 2 days while the day has under
40 candles (before ~12:35, a special session) and 1 day after. The breadth bars stay the day's.
Usage: python3 p136_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "home.html": [
        ('''  if(f0*step>30){ const s_=a=>a.slice(f0); return {o:s_(o),h:s_(h),l:s_(l),c:s_(c),pc:NCH&&NCH.pc,N:N-f0,one,off:f0,step}; }
  return {o,h,l,c,pc:NCH&&NCH.pc,N,one,off:0,step}; }''',
         '''  let r_=(f0*step>30)?(()=>{ const s_=a=>a.slice(f0); return {o:s_(o),h:s_(h),l:s_(l),c:s_(c),pc:NCH&&NCH.pc,N:N-f0,one,off:f0,step}; })():{o,h,l,c,pc:NCH&&NCH.pc,N,one,off:0,step};
  if(!one&&NPREV&&nif2d(r_)){ const n0=NPREV.c.length;            /* patch 136: the session before, first */
    r_={o:NPREV.o.concat(r_.o),h:NPREV.h.concat(r_.h),l:NPREV.l.concat(r_.l),c:NPREV.c.concat(r_.c),pc:r_.pc,N:n0+r_.N,one,off:r_.off,step,prevN:n0,prevOff:NPREV.off,prevDay:NPREV.day}; }
  return r_; }
/* patch 136: the previous session's NIFTY 5-min candles (the stored history: the last 2 days there are -> the one before the day shown) */
let NPREV=null, NDAYS="auto"; try{ NDAYS=localStorage.getItem("gir_ndays")||"auto"; }catch(e){}
function nif2d(r){ if(NDAYS==="2") return true; if(NDAYS==="1") return false; return (r.c||[]).filter(x=>x!=null).length<40; }
function nifDays(v){ NDAYS=v; try{ localStorage.setItem("gir_ndays",v); }catch(e){} SLOW.nif=0; drawMarket(); }
async function pullNprev(){ if(NPREV&&Date.now()-NPREV.at<600000) return; const h=await getJ("hist?k="+encodeURIComponent(K)+"&sym=NIFTY50&days=3"); if(!h||!h.t||!h.t.length) return;
  const dd=t=>Math.floor((t+19800)/86400); const ds=[...new Set(h.t.map(dd))].sort((a,b)=>a-b); if(ds.length<2) return; const pd=ds[ds.length-2];
  const o=[],hi=[],lo=[],c=[]; for(let i=0;i<h.t.length;i++){ if(dd(h.t[i])!==pd) continue; const j=Math.round((h.t[i]-day0915(h.t[i]))/300); if(j<0||j>74) continue;
    while(c.length<=j){ o.push(null); hi.push(null); lo.push(null); c.push(null); } o[j]=h.o[i]; hi[j]=h.h[i]; lo[j]=h.l[i]; c[j]=h.c[i]; }
  const f=c.findIndex(x=>x!=null); if(f<0) return; const s=a=>a.slice(f);
  NPREV={o:s(o),h:s(hi),l:s(lo),c:s(c),off:f,day:["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][new Date(pd*86400000).getUTCDay()],at:Date.now()}; SLOW.nif=0; }
function nifLabels2(N_,off5){ const n0=N_.prevN, tot=N_.N, tm=m=>String(Math.floor(m/60)).padStart(2,"0")+":"+String(m%60).padStart(2,"0");
  return [0,1,2,3,4,5].map(k=>{ const i=Math.round(k*(tot-1)/5); return i<n0?(k===0?N_.prevDay+" ":"")+tm(555+(N_.prevOff+i)*5):tm(555+(off5+i-n0)*5); }); }
/* patch 136: the TICK note says when the market is closed (it said "recording from now" at night) */
function tickNote(){ const i=new Date(Date.now()+19800000), hm=i.toISOString().slice(11,16), dw=i.getUTCDay(); const open=dw>0&&dw<6&&hm>="09:15"&&hm<="15:30";
  return `<div class="legend">${open?"TICK: recording from now - the 5-min chart until the first ticks arrive":"TICK: the market is closed - ticks record from 09:15 · below: the last session's 5-min chart"}</div>`; }'''),
        ('''await Promise.all([pullNifty(), pullEarly()]);''', '''await Promise.all([pullNifty(), pullEarly(), pullNprev()]);'''),
        ('''MKH("nifTf").innerHTML=`<a class="${NTF==="1"?"on":""}" onclick="nifTf('1')">1m</a><a class="${NTF!=="1"?"on":""}" onclick="nifTf('5')">5m</a>`;''',
         '''MKH("nifTf").innerHTML=`<a class="${NTF==="1"?"on":""}" onclick="nifTf('1')">1m</a><a class="${NTF!=="1"?"on":""}" onclick="nifTf('5')">5m</a> <a class="${NDAYS==="1"?"on":""}" onclick="nifDays('1')" title="the day only">1D</a><a class="${NDAYS==="2"?"on":""}" onclick="nifDays('2')" title="the session before + the day">2D</a><a class="${NDAYS==="auto"?"on":""}" onclick="nifDays('auto')" title="2 days while the day has under 40 candles, then 1">AUTO</a>`;'''),
        ('''if(OFF5) B.splice(0,Math.min(B.length,OFF5));''',
         '''if(OFF5) B.splice(0,Math.min(B.length,OFF5)); const PN=NB_&&NB_.prevN||0; if(PN) B.unshift(...Array(PN).fill(null));   /* patch 136: the bars stay under the day's candles */'''),
        ('''const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-OFF5-1, 1));''',
         '''const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-OFF5+PN-1, 1));'''),
        ('''g+=(OFF5?nifLabels(OFF5):["09:15","10:30","11:45","13:00","14:15","15:30"]).map(''',
         '''if(PN){ const xd=L+(W-L-R)*PN/NB_.N; g+=`<line x1="${xd.toFixed(1)}" x2="${xd.toFixed(1)}" y1="${T}" y2="${H-14}" stroke="var(--amber)" stroke-dasharray="2 3" opacity=".7"/><text x="${(xd-3).toFixed(1)}" y="${T+10}" fill="var(--amber)" font-size="9" text-anchor="end">${esc(NB_.prevDay)}</text><text x="${(xd+3).toFixed(1)}" y="${T+10}" fill="var(--amber)" font-size="9">the day</text>`; }
      g+=(PN?nifLabels2(NB_,OFF5):OFF5?nifLabels(OFF5):["09:15","10:30","11:45","13:00","14:15","15:30"]).map('''),
        ('''+B.map((v,i)=>`<rect''', '''+B.map((v,i)=>v==null?"":`<rect'''),
        ('''$("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); $("oitPx").innerHTML=""; }''',
         '''$("tvbox").innerHTML=(PXM==="tick"?tickNote():"")+tv.svg; $("patl").innerHTML=pat(tv); $("oitPx").innerHTML=""; }'''),
        ('''$("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); } }''',
         '''$("tvbox").innerHTML=(PXM==="tick"?tickNote():"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); } }'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p136test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p136test.py - the NIFTY chart with the session before (Fri, then the Muhurat 14:20-15:30): 2 days while the day has under
40 candles (AUTO), 1D / 2D switch; the TICK note says when the market is closed."""
import os, sys, shutil, subprocess
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page: the session before (pullNprev), 1D / 2D / AUTO, the day line, the TICK note",
      "async function pullNprev()" in pg and "nifDays('2')" in pg and "pullNprev()]);" in pg and "function tickNote()" in pg and "the market is closed - ticks record from 09:15" in pg)
node = shutil.which("node")
if node:
    a = pg.index("function nifBars()"); b = pg.index("function nifC(")
    js = "let LQ={},QT=0,MK={},NTF='5',NCH=null,SLOW={};const localStorage={getItem:()=>null,setItem:()=>0};\n" + pg[a:b] + r"""
const mk=f=>Array.from({length:75},(_,i)=>i<f?null:25000+i);
NCH={o:mk(61),h:mk(61),l:mk(61),c:mk(61),pc:25030};
const pv=Array.from({length:75},(_,i)=>25200-i); NPREV={o:pv,h:pv,l:pv,c:pv,off:0,day:"Fri",at:Date.now()};
const a=nifBars(); NDAYS="1"; const b=nifBars(); NDAYS="auto"; NCH={o:mk(0),h:mk(0),l:mk(0),c:mk(0),pc:25030}; const c=nifBars(); NDAYS="2"; const d=nifBars();
console.log(JSON.stringify([a.prevN,a.N,a.c[0],a.c[75],nifLabels2(a,61)[0],nifLabels2(a,61)[5],b.prevN||0,b.N,c.prevN||0,d.prevN]));"""
    r = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    out = r.stdout.strip()
    check("AUTO on the Muhurat day: Fri's 75 candles + the day's 14 (Fri 09:15 ... 15:25); 1D: the day only; a full day: 1 day; 2D: always 2: %s" % (out or r.stderr[:200]),
          out == '[75,89,25200,25061,"Fri 09:15","15:25",0,14,0,75]')
else:
    print("  (node not on this machine - checked when the patch was built)")
print("\nP136 NIFTY 2 DAYS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p136_patch.py $D || { rm -f $D/p136test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && timeout 60 python3 p136test.py 2>&1 | grep "OK  \|FAIL\|P136"
timeout 60 python3 p136test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p132btest.py p131btest.py p134test.py p129test.py p128test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 136 APPLIED. Reload the GIR page: the NIFTY chart shows Friday, a line, then the Muhurat session (1D / 2D / AUTO to switch)."
