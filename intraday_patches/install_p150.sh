#!/bin/bash
# PATCH 150 - THE TERMINAL REDESIGN (the approved mockup). A calmer ink-blue terminal, big index tiles, panels as cards, a condensed
#   face for labels and IBM Plex Mono for every number; TRADE NOW rail on the left (⚡ ENTER NOW / 🌅 OPENING CALL cards, then
#   IMPORTANT with a stripe per level, overnight kept); F&O MONEY as the price x OI quadrant with 🟢/🔴 CASH when NSE's delivery
#   agrees; SECTORS as bars; MOVERS with bars; one laptop screen, the phone in one column. home.html only (needs 149).
#   Restarts gir-dash only - safe any time. Undo: the installer keeps home.html.bak<time>.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150; mkdir -p $W
grep -q "patch 150" $D/home.html && { echo "patch 150 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p150_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150_patch.py - PATCH 150: THE TERMINAL REDESIGN (the approved mockup, 9 Nov). Keeps every requirement: the alert BEFORE the move,
TRADE NOW apart from the rest, overnight alerts kept, F&O shares only, NSE-checked numbers, the NIFTY / BANKNIFTY chart, rotation,
big money, news without scrolling - one laptop screen, the phone stacked.
  look      a calmer ink-blue palette, panels as cards, a condensed face for labels and IBM Plex Mono for every number; the index
            tiles big (value, points, %); colour only for meaning - green up, red down, amber = act
  TRADE NOW the left rail: ⚡ ENTER NOW / 🌅 OPENING CALL / your rules (act) as cards - time, share, BUY CE / PE, the ticket;
            then IMPORTANT (moving / critical) with a stripe per level, newest first, overnight ones kept; tap = the share
  MONEY     F&O futures money as the price x OI quadrant (short covering | long build-up / long unwinding | short build-up), each
            share with ₹ cr, OI %, price %, and 🟢 / 🔴 CASH when NSE's delivery agrees (big hands in the cash market too)
  SECTORS   diverging bars (NSE's index, else F&O avg), tap = its shares        MOVERS  each % with a bar of its size
  laptop    "act nif nif mov" / "act mon don nws" / "ins idx rot nws" - one screen
Usage: python3 p150_patch.py /home/globalbot/intraday  (needs 149)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
FONTS = '''<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Semi+Condensed:wght@500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap">'''
CSS = r'''
/* ============ patch 150: THE TERMINAL REDESIGN ============ */
:root{--bg:#0A0F1A;--panel:#0F1626;--panel2:#141D31;--line:#1F2B44;--line2:#2A3956;--dim:#7D8BA5;--txt:#D9E0EC;--hi:#F4F7FB;--amber:#F2A93B;--amber2:#F7C46C;
  --up:#2FD07F;--dn:#FF5C61;--ce:#2FD07F;--pe:#FF5C61;--upbg:rgba(47,208,127,.13);--dnbg:rgba(255,92,97,.13);--ambg:rgba(242,169,59,.13);
  --mono:"IBM Plex Mono","JetBrains Mono",Menlo,Consolas,monospace;--ui:"Barlow Semi Condensed","Arial Narrow",system-ui,sans-serif}
body{background:var(--bg)}
#top{background:var(--bg);border-bottom:1px solid var(--line)}
#idx{gap:8px;padding:8px;border-bottom:0}
#idx .brand{border-radius:6px;font:700 20px/1 var(--ui);letter-spacing:.08em;padding:0 16px;background:var(--amber);color:#1a1205}
#idx .ix{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:6px 14px;min-width:168px}
#idx .ix b{font:600 11px/1 var(--ui);letter-spacing:.14em;color:var(--dim)}
#idx .ix span{font:500 20px/1.15 var(--mono)}#idx .ix small{display:block;margin:1px 0 0;font:500 12px/1.2 var(--mono)}
#idx .st{font:500 12px var(--ui);letter-spacing:.06em}
#cmd input,#cmd select{background:var(--panel);border-color:var(--line2);border-radius:5px;color:var(--amber2)}#cmd button{border-radius:5px}
#fkeys a{border-radius:5px;font-family:var(--ui);letter-spacing:.08em;font-weight:600}
body.one #grid>section#market.on{background:var(--bg)}
#mk{background:var(--bg);gap:8px;padding:8px;font:12.5px/1.35 var(--ui)}
#mk .q{background:var(--panel);border:1px solid var(--line);border-radius:7px}
#mk .q h3{background:transparent;border-bottom:0;padding:9px 12px 5px;font:700 12.5px/1 var(--ui);letter-spacing:.12em;color:var(--txt);text-transform:uppercase}
#mk .q h3 span{font:500 11.5px/1 var(--ui);letter-spacing:.02em;color:var(--dim);text-transform:none}
#mk .q .bd{padding:0 8px 6px}
#mk .num,#mk td.r,#mk .r{font-family:var(--mono);font-variant-numeric:tabular-nums}
#mk b{font-weight:700}
.pu{color:var(--up)}.pd{color:var(--dn)}
/* TRADE NOW rail */
#q-act{border-color:var(--amber) !important;background:linear-gradient(180deg,var(--ambg),transparent 140px),var(--panel) !important}
#q-act h3{color:var(--amber) !important}
#mk-act .tn{display:grid;grid-template-columns:auto 1fr auto;gap:2px 8px;padding:8px 10px;margin:0 0 6px;border-radius:6px;background:var(--panel2);border:1px solid var(--line);cursor:pointer}
#mk-act .tn .t{font:500 11px/1.2 var(--mono);color:var(--dim);align-self:center}
#mk-act .tn b{font:700 15px/1.1 var(--ui);letter-spacing:.03em;align-self:center}
#mk-act .tn .sd{font:700 11px/1 var(--ui);letter-spacing:.08em;padding:4px 8px;border-radius:4px;align-self:center}
#mk-act .tn .sd.ce{background:var(--upbg);color:var(--up)}#mk-act .tn .sd.pe{background:var(--dnbg);color:var(--dn)}
#mk-act .tn small{grid-column:1/-1;color:var(--dim);font-size:12px;line-height:1.3}
#mk-act .tn0{padding:8px 10px;margin-bottom:6px;border-radius:6px;background:var(--panel2);color:var(--dim);font-size:13px;line-height:1.4}
#mk-act h4{margin:8px 2px 2px;font:700 12px/1 var(--ui);letter-spacing:.12em;color:var(--txt)}#mk-act h4 small{font-weight:500;letter-spacing:0;color:var(--dim)}
#mk-act .im{display:grid;grid-template-columns:4px 40px 1fr;gap:0 8px;padding:6px 0;border-bottom:1px solid var(--line);cursor:pointer}
#mk-act .im i{border-radius:2px;background:var(--amber)}#mk-act .im i.c{background:var(--dn)}
#mk-act .im .t{font:500 11.5px/1.45 var(--mono);color:var(--dim)}#mk-act .im p{margin:1px 0 0;color:var(--dim);font-size:12px;line-height:1.3}
#mk-act .im:hover,#mk-act .tn:hover{background:#17223a}
/* F&O MONEY quadrant */
#mk-mon .qd{display:grid;grid-template-columns:1fr 1fr;gap:6px}
#mk-mon .qb{border-radius:6px;padding:6px 8px;border:1px solid var(--line);background:var(--panel2);min-width:0}
#mk-mon .qb.bull{box-shadow:inset 0 2px 0 var(--up)}#mk-mon .qb.bear{box-shadow:inset 0 -2px 0 var(--dn)}
#mk-mon .qb h5{margin:0 0 3px;font:700 11.5px/1.1 var(--ui);letter-spacing:.08em;display:flex;justify-content:space-between;gap:6px}
#mk-mon .qb h5 small{font-weight:600;letter-spacing:.03em;color:var(--dim)}
#mk-mon .qr{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:6px;font-size:12.5px;padding:1.5px 0;white-space:nowrap;cursor:pointer}#mk-mon .qr:hover{background:#17223a}
#mk-mon .qr b{overflow:hidden;text-overflow:ellipsis}#mk-mon .qr .m{font:500 11.5px var(--mono);color:var(--dim)}#mk-mon .qr .p{font:500 12px var(--mono)}
#mk-mon .cash{font:700 9px/1 var(--ui);letter-spacing:.04em;padding:2px 3px;border-radius:3px;margin-left:3px;vertical-align:1px}
#mk-mon .cash.u{background:var(--upbg);color:var(--up)}#mk-mon .cash.d{background:var(--dnbg);color:var(--dn)}
#mk-mon .ax{display:flex;justify-content:space-between;color:var(--dim);font-size:10.5px;letter-spacing:.05em;padding:4px 2px 0}
#mk-mon .mss{border-bottom:0;padding:0 0 6px}
/* SECTORS bars */
#mk-don .sb{display:grid;grid-template-columns:minmax(0,128px) 1fr 60px;gap:8px;align-items:center;font-size:12.5px;padding:2.5px 2px;cursor:pointer;border-radius:3px}
#mk-don .sb:hover{background:var(--panel2)}#mk-don .sb span:first-child{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#mk-don .sb small{color:var(--dim)}#mk-don .sb i{font-style:normal;font-size:9px;color:var(--dim);margin-left:4px}
#mk-don .sb.few{opacity:.55}
#mk-don .tr{position:relative;height:12px}#mk-don .tr::before{content:"";position:absolute;left:50%;top:-3px;bottom:-3px;width:1px;background:var(--line2)}
#mk-don .fl{position:absolute;top:1px;height:10px;border-radius:2px}#mk-don .fl.u{background:var(--up)}#mk-don .fl.d{background:var(--dn)}
#mk-don .sb b{text-align:right;font:500 12px var(--mono)}
#mk #nifTf{display:none !important}
body.mclosed:not(.earopen) #mk #q-ear{height:auto !important;min-height:0}
@media(max-width:1099px){#mk #q-act,#mk #q-ins,#mk #q-rot,#mk #q-dsk{grid-area:auto !important}#mk{grid-template-columns:minmax(0,1fr) !important;grid-template-areas:none !important}}
@media(min-width:1100px){
  #q-act{grid-area:act}
  #mk{grid-template-columns:280px minmax(0,1fr) minmax(0,1fr) 330px !important;grid-template-rows:auto auto minmax(0,1.1fr) minmax(0,1fr) minmax(0,1fr) !important;
      grid-template-areas:"ear ear ear ear" "dsk dsk dsk dsk" "act nif nif mov" "act mon don nws" "ins idx rot nws" !important}
  body.vmk #abar .ac{display:none}
  #mk-dsk{background:transparent}#q-dsk{border-radius:7px}
}
'''
JS = r'''/* patch 150: TRADE NOW rail · the F&O MONEY quadrant */
function drawAct(){ const el=$("mk-act"); if(!el) return; const rows=((D&&D.now)||[]).filter(r=>r.s);
  const act=rows.filter(r=>alertTier(r)==="act"), mv=rows.filter(r=>alertTier(r)==="move");
  const night=typeof aNight==="function"&&aNight();
  const card=r=>{ const up=r.side==="CE",dn=r.side==="PE"; return `<div class="tn" onclick="focusOn('${esc(r.s)}')"><span class="t">${esc(r.t)}${r.prev?`<br>${esc(r.prev)}`:""}</span><b>${esc(r.s)}</b><span class="sd ${up?"ce":dn?"pe":""}">${up?"BUY CE":dn?"BUY PE":"—"}</span><small>${esc(String(alertTicket(r)||r.head||"")).slice(0,150)}</small></div>`; };
  const imp=r=>{ const up=r.side==="CE",dn=r.side==="PE"; return `<div class="im" onclick="focusOn('${esc(r.s)}')"><i class="${alertLane(r)==="critical"?"c":""}"></i><span class="t">${esc(r.t)}</span><div><b>${esc(r.s)}</b> <span class="${up?"pu":dn?"pd":"dim"}">${up?"▲ CE":dn?"▼ PE":""}</span><p>${esc((h_=>{ const k_=h_.indexOf(r.s); return (k_>=0?h_.slice(k_+r.s.length):h_).replace(/^[\s·:\-–]+/,""); })(String(r.head||"")).slice(0,110))}</p></div></div>`; };
  const res=((((MK&&MK.chain)||{}).results)||[]).slice(0,6).map(r=>esc(r.s)+" "+esc((r.d||"").slice(5))).join(" · ");
  MKH("mk-act").innerHTML=`${act.length?act.slice(0,6).map(card).join(""):`<div class="tn0">${night?"Nothing to act on now. Next: <b>🌅 OPENING CALL 09:12</b>":"Nothing to act on yet. A <b>⚡ ENTER NOW</b> or <b>🌅 OPENING CALL</b> lands here, ringing."}${res?`<br><small>results: ${res}</small>`:""}</div>`}
    <h4>IMPORTANT <small>${mv.length} · newest first · tap = its screen</small></h4>${mv.length?mv.slice(0,40).map(imp).join(""):'<div class="dim" style="padding:4px 2px">nothing moving yet</div>'}`; }
function monQuad(M){ const mo=M.money||{}; const DL=((MK&&MK.inst)||{}).deliv||{}; const acc=new Set((DL.acc||[]).map(x=>x.s)), dis=new Set((DL.dist||[]).map(x=>x.s));
  const box=(b,k,bias)=>{ const xs=msort(mo[b]||[]).slice(0,6); return `<div class="qb ${k}"><h5 class="${k==="bull"?"pu":"pd"}">${b}<small>${bias}</small></h5>${xs.length?xs.map(x=>{ const c=(k==="bull"&&acc.has(x.s))?'<span class="cash u" title="NSE delivery: big hands bought in the cash market too">🟢 CASH</span>':(k==="bear"&&dis.has(x.s))?'<span class="cash d" title="NSE delivery: big hands sold in the cash market too">🔴 CASH</span>':"";
      return `<div class="qr" onclick="mkOpen('${esc(x.s)}')" title="${esc(x.s)} · ₹${Math.abs(Math.round(x.cr||0))} cr futures money · OI ${x.oi>0?"+":""}${x.oi}% · price ${mkPc(x.chg)}"><b>${esc(x.s)}${c}</b><span class="m ${(x.oi||0)>0?"pu":"pd"}">${x.oi>0?"+":""}${x.oi??"—"}%</span><span class="p ${cls(x.chg)}">${mkPc(x.chg)}</span></div>`; }).join(""):'<div class="dim">none</div>'}</div>`; };
  return `${msortBar()}<div class="qd">${box("SHORT COVERING","bull","▲ bullish · weaker")}${box("LONG BUILD-UP","bull","▲ bullish · strong")}${box("LONG UNWINDING","bear","▼ bearish · weaker")}${box("SHORT BUILD-UP","bear","▼ bearish · strong")}</div>
    <div class="ax"><span>◀ OI falling</span><span>OI % · price % · 🟢/🔴 CASH = big hands agree</span><span>OI rising ▶</span></div><div class="dim" style="font-size:10.5px;padding:2px">OI: ${M.oi_src?esc(M.oi_src):"Kite live (NSE's official file after 18:40)"}</div>`; }
'''
SECT = r'''  // SECTORS (patch 150): diverging bars - NSE's index, else its F&O shares' average
  { const S=(M.sectors&&M.sectors.length?M.sectors:(SECS||[]).map(x=>({name:x.name,n:(x.syms||[]).length,chg:x.chg}))).filter(x=>x.n);
    const R=S.map(x=>{ const si=secIdx(x.name); const ic=si&&si.chg!=null?si.chg:null; return {name:x.name,n:x.n,v:ic!=null?ic:x.chg,f:ic==null}; }).filter(x=>x.v!=null).sort((a,b)=>((b.n>=3)-(a.n>=3))||(b.v-a.v));
    const mx=Math.max(1,...R.map(x=>Math.abs(x.v)));
    MKH("mk-don").innerHTML=R.length?R.map(x=>{ const w=Math.min(50,Math.abs(x.v)/mx*50); return `<div class="sb${x.n<3?" few":""}" onclick="mkSec('${esc(x.name)}')" title="${esc(x.name)} · ${x.n} F&amp;O shares · ${x.f?"no NSE index - its F&amp;O shares' average":"NSE's index"}"><span>${esc(x.name.toUpperCase())} <small>${x.n}</small>${x.f?"<i>F&amp;O</i>":""}</span><span class="tr"><span class="fl ${x.v>=0?"u":"d"}" style="${x.v>=0?"left":"right"}:50%;width:${w.toFixed(1)}%"></span></span><b class="${x.v>=0?"pu":"pd"}">${x.v>0?"+":""}${x.v.toFixed(2)}%</b></div>`; }).join(""):'<div class="empty">no sectors yet</div>'; }
'''


def main():
    p = os.path.join(D, "home.html")
    s = open(p, encoding="utf-8").read()
    if "patch 150" in s:
        print("patch 150 is already in home.html"); return 1
    if "patch 149" not in s:
        print("patch 149 is not installed yet"); return 1
    a = s.find('    MKH("mk-mon").innerHTML=`${msortBar()}<div class="mn">')
    b = s.find('`; }', a) + 4
    if s.count('    MKH("mk-mon").innerHTML=`${msortBar()}<div class="mn">') != 1 or b < 4:
        print("ANCHOR: F&O MONEY"); return 1
    s = s[:a] + '    MKH("mk-mon").innerHTML=monQuad(M); }   /* patch 150: the quadrant */' + s[b:]
    a, b = s.find("  // SECTOR DONUT"), s.find("  // F&O MONEY: the shares with the most fresh futures money, per build-up")
    if not (0 < a < b) or s.count("  // SECTOR DONUT") != 1:
        print("ANCHOR: SECTOR DONUT"); return 1
    s = s[:a] + SECT + s[b:]
    EDITS = [
        ('</style></head><body>', CSS + '</style>' + FONTS + '</head><body>'),
        ('<td class="r ${cls(r.chg)}${qfl(r.s)}">${mkPc(r.chg)}</td>',
         '<td class="r ${cls(r.chg)}${qfl(r.s)}" style="background:linear-gradient(to left,${r.chg>=0?"rgba(47,208,127,.18)":"rgba(255,92,97,.18)"} ${Math.min(100,Math.abs(r.chg)/9*100).toFixed(0)}%,transparent 0)">${mkPc(r.chg)}</td>'),
        ('    <div class="q" id="q-mov">', '    <div class="q" id="q-act"><h3>TRADE NOW <span>act now · rings loud · overnight kept</span></h3><div class="bd" id="mk-act"></div></div>\n    <div class="q" id="q-mov">'),
        ('drawRot(); drawIns(); mkFit();   // patch 145c · 148', 'drawRot(); drawIns(); drawAct(); mkFit(); document.body.classList.toggle("vmk",VIEW==="market");   // patch 145c · 148 · 150'),
        ('function MKH(id){', JS + 'function MKH(id){'),
    ]
    for x, y in EDITS:
        if s.count(x) != 1:
            print("ANCHOR x%d: %s" % (s.count(x), x[:80])); return 1
        s = s.replace(x, y)
    open(p, "w", encoding="utf-8").write(s)
    print("patched: home.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
python3 $W/p150_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && for t in p149test.py p148test.py p146etest.py p145dtest.py p143test.py p142test.py p140ftest.py p129test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 150 APPLIED. Reload the GIR page with Ctrl+F5 (laptop: press F11 for full screen - more room for every panel)."
echo "To go back to the old look: cp $D/home.html.bak$TS $D/home.html && systemctl restart gir-dash"
