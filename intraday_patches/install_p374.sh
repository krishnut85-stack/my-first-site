#!/bin/bash
# PATCH 374 - A DIFFERENT ALARM FOR EACH KIND OF ALERT ON THE GIR PAGE (Rama, 17 Nov 12:46: "all giving me the same audible alarm" · "I need
#   a different alarm in the GIR panel"). Nothing is muted - every alert that rang still rings; it now SOUNDS like what it is:
#     🟢 BUY CE      three notes going UP, twice              🔴 BUY PE      three notes going DOWN, twice
#     ✅ BOOK HALF   a bright two-bell "ka-ching"             ❌ EXIT / STOP  a low "bwaa-bwaa"
#     ⏹ 15:10 EXIT  one low gong                              🔺🔻 SECTOR    quick wood-block taps (high = up, low = down)
#     🚨 CRITICAL    the nee-naw (patch 224, as before)        other trade alerts (ENTER NOW, opening call ...) the ambulance (224)
#   · the page's ring rule (patch 224) is kept as it is; it now also remembers WHICH alert decided the ring, and the sound follows that alert
#   · the 👀 box's own chime (patch 351) is dropped - the alert list's ring plays the right sound for the same alert (no double sound)
#   · 🔊 SOUNDS beside 🔊 P1 / 🔊 CRITICAL: a small panel to hear each sound once and learn them
#   · ⤢ BIG on the ALERTS box: the list opens large down the right side, every alert in full (no "↳ fo…"); again or Esc puts it back
#   · a PROFIT BOOKING warning ("book part NOW") plays the BOOK HALF sound, not the nee-naw
#   · the 👀 box says when the day's 12 heads-up are used ("12 of 12 used by 09:50 - no new shares today; their exits still ring")
#   Uses the page's own sound switch and volume (ASND / AVOL). Page only - the phone (Telegram) is not changed. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 374" $D/home.html; then echo "patch 374 - already in"; exit 0; fi
grep -q "patch 224" $D/home.html && grep -q "patch 351" $D/home.html && grep -q "function alarm(kind)" $D/home.html || { echo "patches 224 / 351 (the page's sounds, the 👀 box) not found - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/snd.html <<'SND'
<style>/* patch 374: 🔊 SOUNDS panel */
#gxsnd{position:fixed;top:60px;right:14px;z-index:9100;display:none;width:min(420px,calc(100vw - 28px));background:#0b1522;border:1px solid #2b5a8a;border-radius:10px;box-shadow:0 10px 40px rgba(0,0,0,.6);color:#e6edf3;font:12.5px/1.5 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxsnd.on{display:block}#gxsnd .hd{display:flex;align-items:center;padding:8px 12px;background:#0f2238;border-bottom:1px solid #1b3048;border-radius:10px 10px 0 0}
#gxsnd .hd b{font:800 13px ui-monospace,Menlo,monospace;color:#f0b429}#gxsnd .hd a{margin-left:auto;cursor:pointer;padding:0 8px;border:1px solid #2b5a8a;border-radius:6px}
#gxsnd .r{display:flex;align-items:center;gap:10px;padding:6px 12px;border-bottom:1px solid #12233a}#gxsnd .r button{flex:none;cursor:pointer;background:#13263d;color:#e6edf3;border:1px solid #2b5a8a;border-radius:6px;padding:2px 9px;font:700 12px ui-monospace,Menlo,monospace}
#gxsnd .r span{color:#c9d4e3}#gxsnd .ft{padding:7px 12px;color:#8b97a9;font-size:11.5px}
#gxhu .gxcap374{padding:6px 10px;border-top:1px solid #22190a;font-size:11.5px;color:#f0b429}
#abar.gxbig{position:fixed!important;top:54px;right:10px;width:min(640px,50vw)!important;height:calc(100vh - 66px)!important;max-height:none!important;z-index:8700;overflow:auto!important;background:#0b1320;border:2px solid #f0544f;border-radius:10px;box-shadow:0 12px 44px rgba(0,0,0,.7);font-size:13.5px}
#abar.gxbig *{white-space:normal!important}#abar.gxbig .dgl,#abar.gxbig .dg{max-height:none!important;height:auto!important}
#abar .gxbigb{float:right;margin-left:8px;padding:0 8px;border:1px solid #fff6;border-radius:5px;cursor:pointer;font:800 11px ui-monospace,Menlo,monospace;color:#fff;background:#0004}
@media (max-width:900px){#abar.gxbig{left:5px;right:5px;width:auto!important;top:50px}}
</style>
<script>/* patch 374: a different alarm for each kind of alert - through the page's own sound switch and volume (ASND / AVOL, patch 224) */
(function(){
  const ok=()=>{ try{ return typeof ASND==="undefined"||(ASND&&AVOL>0); }catch(e){ return true; } };
  function ctx(){ try{ if(typeof acUnlock==="function") acUnlock(); }catch(e){} try{ if(typeof AC!=="undefined"&&AC) return AC; }catch(e){}
    window.__gxAC=window.__gxAC||new (window.AudioContext||window.webkitAudioContext)(); return window.__gxAC; }
  function out(A){ try{ if(typeof amaster==="function"){ const m=amaster(); if(m&&m._g&&typeof AVOL!=="undefined") m._g.gain.value=2.4*AVOL; return m; } }catch(e){} return A.destination; }
  function n(A,t,f,dur,vol,type,f2){ const o=A.createOscillator(), g=A.createGain(); o.type=type||"triangle"; o.frequency.setValueAtTime(f,t); if(f2) o.frequency.exponentialRampToValueAtTime(f2,t+dur);
    o.connect(g); g.connect(out(A)); g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(vol,t+0.012); g.gain.exponentialRampToValueAtTime(0.0001,t+dur); o.start(t); o.stop(t+dur+0.02); }
  const S={
    buyce:(A,t)=>{ for(let r=0;r<2;r++) [1047,1319,1568].forEach((f,i)=>n(A,t+r*0.75+i*0.16,f,0.22,0.9,"triangle")); },
    buype:(A,t)=>{ for(let r=0;r<2;r++) [1568,1319,1047].forEach((f,i)=>n(A,t+r*0.75+i*0.16,f,0.22,0.9,"triangle")); },
    half:(A,t)=>{ [[2093,0],[2637,0.12],[2093,0.42],[2637,0.54]].forEach(([f,d])=>{ n(A,t+d,f,0.5,0.7,"sine"); n(A,t+d,f*2.01,0.3,0.25,"sine"); }); },
    stop:(A,t)=>{ n(A,t,220,0.45,0.9,"sawtooth",150); n(A,t+0.55,196,0.6,0.9,"sawtooth",130); },
    close:(A,t)=>{ n(A,t,330,1.6,0.9,"sine"); n(A,t,495,1.2,0.35,"sine"); },
    secup:(A,t)=>{ for(let i=0;i<4;i++) n(A,t+i*0.11,1400,0.06,0.9,"square"); },
    secdn:(A,t)=>{ for(let i=0;i<4;i++) n(A,t+i*0.11,700,0.07,0.9,"square"); } };
  function play(k){ if(!ok()) return false; try{ const A=ctx(); if(A.state==="suspended") A.resume(); S[k](A,A.currentTime+0.03); return true; }catch(e){ return false; } }
  window.gxPlay=play;
  /* which sound: from the alert that decided the ring (GXRH, set by the ring rule) */
  function kindOf(h){ h=String(h||"");
    if(/BOOK HALF|HALF OUT|PROFIT BOOKING|book part/i.test(h)) return "half";   /* a profit-booking warning = "book part" */
    if(/15:10|TIME EXIT|⏹/.test(h)) return "close";
    if(/❌|🛑|EXIT ALL|STOP HIT|stop - OUT|\bOUT\b.*stop/i.test(h)) return "stop";
    if(/🔺|🔻|SECTOR/.test(h)&&!/🟢|🔴|BUY/.test(h)) return /🔻|DOWN/.test(h)?"secdn":"secup";
    if(/🟢|BUY CE|\bCE\b.*BUY|HEADS-UP.*\bCE\b/.test(h)) return "buyce";
    if(/🔴|BUY PE|\bPE\b.*BUY|HEADS-UP.*\bPE\b/.test(h)) return "buype";
    return null; }
  window.gxAlarm=function(kind){ const k=kindOf(window.GXRH); window.GXRH="";
    if(k&&(kind==="act"||kind==="move"||k==="half"||k==="stop"||k==="close")&&play(k)) return;   /* 🚨 critical keeps its nee-naw */
    try{ alarm(kind); }catch(e){} };
  /* 🔊 SOUNDS panel */
  const L=[["buyce","🟢 BUY CE - a new call to buy a CE"],["buype","🔴 BUY PE - a new call to buy a PE"],["half","✅ BOOK HALF - book half, the stop moves to entry"],
           ["stop","❌ EXIT / STOP - the stop is hit, exit all"],["close","⏹ 15:10 - exit what is left"],["secup","🔺 SECTOR UP - a whole sector moving up"],
           ["secdn","🔻 SECTOR DOWN - a whole sector moving down"],["crit","🚨 CRITICAL - news, results, regulator (nee-naw)"],["act","other trade alerts - ENTER NOW, opening call (ambulance)"]];
  window.gxSounds=function(){ let el=document.getElementById("gxsnd"); if(!el){ el=document.createElement("div"); el.id="gxsnd";
      el.innerHTML='<div class="hd"><b>🔊 GIR SOUNDS</b><a data-x="1">✕</a></div>'+L.map(([k,t])=>`<div class="r"><button data-k="${k}">▶</button><span>${t}</span></div>`).join("")+
        '<div class="ft">the page\'s sound switch and volume apply · the phone (Telegram) plays its own channel sound</div>';
      el.addEventListener("click",e=>{ const b=e.target.closest("button[data-k]"); if(b){ const k=b.dataset.k; if(S[k]) play(k); else try{ alarm(k); }catch(_){} return; } if(e.target.dataset.x) el.classList.remove("on"); });
      document.body.appendChild(el); }
    el.classList.toggle("on"); };
  function link(){ if(document.querySelector(".gxsndk")) return; const p1=[...document.querySelectorAll('a[onclick="alarm(\'crit\')"]')][0];
    const a=document.createElement("a"); a.className="gxsndk"; a.textContent="🔊 SOUNDS"; a.title="hear each GIR alarm"; a.style.cursor="pointer"; a.addEventListener("click",e=>{ e.preventDefault(); window.gxSounds(); });
    if(p1&&p1.parentNode){ p1.after(a); } else { const fk=document.getElementById("fkeys"); if(fk) fk.appendChild(a); } }
  /* the 👀 box: say when the day's 12 heads-up are used */
  let HU=null;
  async function pull(){ if(document.hidden) return; try{ const r=await fetch("headsup?k="+encodeURIComponent((new URLSearchParams(location.search)).get("k")||""),{cache:"no-store"}); if(r.ok) HU=await r.json(); }catch(e){} cap(); }
  function cap(){ const el=document.getElementById("gxhu"); if(!el||!HU) return; const today=new Date(Date.now()+19800000).toISOString().slice(0,10); if(HU.day!==today) return;
    const M=Object.values(HU.mon||{}).filter(m=>(m.kind||"👀")==="👀").sort((a,b)=>String(a.t).localeCompare(String(b.t)));
    let c=el.querySelector(".gxcap374"); if(M.length<12){ if(c) c.remove(); return; }
    const txt=`today's 12 heads-up were used by ${M[11].t} (the limit the replay was scored with) - no new shares today; their exits still ring · sector alerts go on`;
    if(!c){ c=document.createElement("div"); c.className="gxcap374"; el.appendChild(c); } if(c.textContent!==txt) c.textContent=txt; }
  /* ⤢ BIG: the ALERTS box (patch 374) - a large, readable list down the right side; again (or Esc) puts it back */
  let BIG=false; try{ BIG=localStorage.getItem("gir_abar_big")==="1"; }catch(e){}
  function big(on){ BIG=on; const a=document.getElementById("abar"); if(a) a.classList.toggle("gxbig",on); try{ localStorage.setItem("gir_abar_big",on?"1":"0"); }catch(e){} bigb(); }
  function bigb(){ const a=document.getElementById("abar"), h=a&&a.querySelector(".al"); if(!h) return; if(a.classList.contains("gxbig")!==BIG) a.classList.toggle("gxbig",BIG);
    let b=h.querySelector(".gxbigb"); if(!b){ b=document.createElement("span"); b.className="gxbigb"; b.addEventListener("click",e=>{ e.stopPropagation(); e.preventDefault(); big(!BIG); }); h.appendChild(b); }
    const t=BIG?"✕ SMALL":"⤢ BIG"; if(b.textContent!==t){ b.textContent=t; b.title=BIG?"put the alerts back in their box (Esc)":"open the alerts as a big readable list"; } }
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"&&BIG) big(false); });
  new MutationObserver(()=>{ try{ cap(); link(); bigb(); }catch(e){} }).observe(document.body,{childList:true,subtree:true});
  setTimeout(()=>{ link(); pull(); },2500); setInterval(pull,30000);
})();
</script>
SND
python3 - $D/home.html $W/snd.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
E = (
 # the ring rule: remember the alert that decided the ring
 ('''ring=Math.max(ring,(tr==="act"||/🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT/.test(r.head||""))?3:(/CIRCUIT/.test(r.head||"")||/CRITICAL/.test(r.head||"")||alertLane(r)==="critical")?2:1);''',
  '''{ const lv374=(tr==="act"||/🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT/.test(r.head||""))?3:(/CIRCUIT/.test(r.head||"")||/CRITICAL/.test(r.head||"")||alertLane(r)==="critical")?2:1;
  if(lv374>ring){ try{ window.GXRH=(r.head||"")+" "+String(r.text||r.body||r.t||"").slice(0,300)+" "+String((r.lines||[]).join(" ")).slice(0,300); }catch(e){} }   /* patch 374: which alert decided the ring */
  ring=Math.max(ring,lv374); }'''),
 # the ring: the sound follows that alert
 ('''if(ring){ alarm(ring===3?"act":ring===2?"crit":"move");''',
  '''if(ring){ (window.gxAlarm||alarm)(ring===3?"act":ring===2?"crit":"move");   /* patch 374: the sound of that kind of alert */'''),
 # the 👀 box's own chime goes - the list's ring plays the right sound for the same alert
 ('''if(seen&&[...keys].some(k=>!seen.has(k))) chime(); seen=keys; draw();''',
  '''seen=keys; draw();   /* patch 374: no chime here - the alert list's ring plays the sound of that alert */'''))
for a, b in E:
    if t.count(a) != 1:
        print("❌ home.html: %r found %d times - nothing changed" % (a[:70], t.count(a))); sys.exit(1)
    t = t.replace(a, b)
i = t.rfind("</body>")
if i < 0:
    print("❌ home.html: </body> not found"); sys.exit(1)
t = t[:i] + open(sys.argv[2], encoding="utf-8").read() + t[i:]
open(p, "w", encoding="utf-8").write(t); print("  home.html: a different alarm for each kind of alert · 🔊 SOUNDS · the 👀 box's limit line")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 374 done - refresh GIR (Ctrl+Shift+R) and press 🔊 SOUNDS (beside 🔊 P1 / 🔊 CRITICAL) to hear each alarm once."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash"
