#!/bin/bash
# PATCH 185 - F&O MOVERS: CHG % = the biggest move first, also on ▼ DOWN / SB / LU · the DESK sort and the DESK P&L tab off · BIG MONEY:
#   the counts on its tab + filters (ALL · ▲ AGREE UP · ▼ AGREE DOWN · MIXED · FUTURES ONLY) · PICKS / TOMORROW say which session they
#   come from · a delivery file dated on an NSE holiday is not counted. gir-dash restarts (502 for 1-3 minutes) - outside market hours.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35"; exit 1; fi
for f in home.html moneylink.py instflow.py; do cp $D/$f $D/$f.bak$TS; done
cat > $W/p185_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p185_patch.py - PATCH 185 (Rama, 10 Nov evening):
  * F&O MOVERS: CHG % ▼ = the BIGGEST move first, also on ▼ DOWN / SB / LU (the down list showed -0.01% first, the -5% fall last)
  * the DESK sort and the 0 DESK P&L tab off (GIR's old paper rules - they lost ₹82,793 in 18 days; the data is kept)
  * BIG MONEY: the counts on its tab (B BIG MONEY ▲15 ▼9) + filters ALL · ▲ AGREE UP · ▼ AGREE DOWN · MIXED · FUTURES ONLY
  * PICKS / TOMORROW say which session they come from - before the open they are the last session's lists, a watch list only
  * delivery: a file dated on an NSE holiday (10 Nov) is not counted as a day
Usage: python3 p185_patch.py /home/globalbot/intraday"""
import sys, os, re
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
CSS = """
/* patch 185 */
#fkeys a[data-v="desk"]{display:none !important}
#mk-lnk .lf{display:flex;gap:4px;padding:4px 8px;flex-wrap:wrap}#mk-lnk .lf a{cursor:pointer;padding:3px 9px;border:1px solid var(--line2);border-radius:4px;font:600 11px var(--ui);background:var(--panel2);color:var(--txt)}
#mk-lnk .lf a.on{background:var(--amber);color:#1a1205;border-color:var(--amber)}
.stale{margin:6px 8px;padding:7px 11px;border:1px solid #7a5600;background:#1d1500;border-radius:6px;color:var(--amber2,#f7c46c);font:600 12.5px/1.4 var(--ui)}
</style>"""
JS = r"""
/* patch 185: BIG MONEY filters + counts on the tab; PICKS / TOMORROW say which session they come from */
try{ if(WS.k==="v"){ WS.k="chg"; WS.dir=-1; wsSave(); } }catch(e){}   /* the DESK sort is gone */
let LNKF="all"; try{ LNKF=localStorage.getItem("gir_lnkf")||"all"; }catch(e){}
function lnkF(v){ LNKF=v; try{ localStorage.setItem("gir_lnkf",v); }catch(e){} drawLink(); }
{ const dl0_=drawLink; drawLink=function(){ if(!LNK) return; const all=LNK.rows||[];
    const pick={all:()=>all, up:()=>all.filter(x=>x.word==="ALL AGREE ▲"), dn:()=>all.filter(x=>x.word==="ALL AGREE ▼"), mix:()=>all.filter(x=>x.word==="MIXED"), fut:()=>all.filter(x=>/^FUTURES/.test(x.word))};
    const n={up:pick.up().length, dn:pick.dn().length, mix:pick.mix().length, fut:pick.fut().length, all:all.length};
    const keep=LNK.rows; LNK.rows=(pick[LNKF]||pick.all)(); dl0_(); LNK.rows=keep;
    const el=$("mk-lnk"); if(el){ const f=document.createElement("div"); f.className="lf";
      f.innerHTML=[["all","ALL "+n.all],["up","▲ AGREE UP "+n.up],["dn","▼ AGREE DOWN "+n.dn],["mix","MIXED "+n.mix],["fut","FUTURES ONLY "+n.fut]].map(([k,l])=>`<a class="${LNKF===k?"on":""}" onclick="lnkF('${k}')">${l}</a>`).join("");
      el.insertBefore(f,el.querySelector("table")); }
    const tb=document.querySelector('#fkeys a[data-v="mk-big"]'); if(tb) tb.innerHTML=`<b>B</b>BIG MONEY <span class="pu">▲${n.up}</span> <span class="pd">▼${n.dn}</span>`; }; }
setTimeout(()=>{ try{ LNKT=0; pullLink(); }catch(e){} },1500);
function sessNote(){ const today=new Date(Date.now()+19800000).toISOString().slice(0,10), day=(D&&D.day)||"", open=typeof mktOpenNow==="function"&&mktOpenNow();
  if(open&&day===today) return ""; const d=day?day.slice(8,10)+"-"+day.slice(5,7):"the last session";
  return `<div class="stale">⏪ From the session of ${esc(d)} (the last close) - not today's. F&amp;O prices change at the open: a WATCH list only. The 🌅 09:08 pre-open, the 09:20 OPENING CALL and live alerts decide.</div>`; }
{ const dp0_=drawPanels; drawPanels=function(){ dp0_(); const s=sessNote(); for(const id of ["pkl","tml"]){ const el=$(id); if(!el) continue; const old=el.querySelector(":scope > .stale"); if(old) old.remove(); if(s) el.insertAdjacentHTML("afterbegin",s); } }; }
"""
A_JS = 'window.addEventListener("load",()=>setTimeout(topChart,50));'
E_SORT = ('const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);',
          'const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg==null?-1e18:Math.abs(r.chg), foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);   /* patch 185: CHG % = the biggest move first, up or down */')
E_DESK = ('${btn("foi","OI %")}${btn("v","DESK")}', '${btn("foi","OI %")}')
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
msg = []
if "patch 185" not in t:
    if "patch 184" not in t or t.count(A_JS) != 1:
        print("patch 184 is not in home.html - install it first"); sys.exit(1)
    for a, b in (E_SORT, E_DESK):
        if t.count(a) < 1:
            print("ANCHOR x%d: %s" % (t.count(a), a[:50])); sys.exit(1)
        t = t.replace(a, b)
    t = t.replace('try{ WS=Object.assign(', 'try{ WS=Object.assign(', 1)
    t = t.replace("</style>", CSS, 1).replace(A_JS, A_JS + JS, 1)
    t = t.replace("try{ WS=Object.assign(", "try{ WS=Object.assign(", 1)
    open(h, "w", encoding="utf-8").write(t); msg.append("home.html")
# delivery: never count a file dated on an NSE holiday
HOL = '''

def _hol_day(d):                                                # patch 185: a delivery file dated on an NSE holiday is not a day
    try:
        import holidays, datetime as _d
        return bool(holidays.holiday(_d.date.fromisoformat(str(d)[:10])))
    except Exception:
        return False
'''
for fn, a, b in (("moneylink.py", '            D.append(json.load(open(os.path.join(I.DIR, f))))', '            j_ = json.load(open(os.path.join(I.DIR, f)))\n            if not _hol_day(j_.get("day")):\n                D.append(j_)'),
                 ("instflow.py", '            D.append(json.load(open(os.path.join(DIR, f))))', '            j_ = json.load(open(os.path.join(DIR, f)))\n            if not _hol_day(j_.get("day")):\n                D.append(j_)')):
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    if "patch 185" in s:
        continue
    if s.count(a) != 1:
        print("ANCHOR x%d in %s" % (s.count(a), fn)); sys.exit(1)
    s = s.replace(a, b) + HOL
    open(p, "w", encoding="utf-8").write(s); msg.append(fn)
print("patched: %s" % (", ".join(msg) or "nothing new"))
PY_PATCH
back() { for f in home.html moneylink.py instflow.py; do cp $D/$f.bak$TS $D/$f; done; }
R=$(python3 $W/p185_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile moneylink.py instflow.py dashserve.py || { back; echo "does not compile - old files back"; exit 1; }
timeout 60 python3 p184test.py > /tmp/p184test.log 2>&1 && echo "p184test.py passed" || { echo "TEST FAILED - old files back"; back; exit 1; }
echo -n "the page server restarting (502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "✅ the page is back" || { echo "❌ the page did not come back - old files back"; back; systemctl restart gir-dash; exit 1; }
rm -rf $W
echo "PATCH 185 APPLIED - Ctrl + Shift + R on girtrader.com."
