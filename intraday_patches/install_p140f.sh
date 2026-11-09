#!/bin/bash
# PATCH 140f - THE PAGE, FROM RAMA'S 15:00 NOTES:
#   1. the alert row (MOVING 15:06 IRFC ...) glides slowly sideways - the mouse / a touch stops it; 20 alerts instead of 12
#   2. tapping a share opens its screen at once ("opening SYM ...") - no other page flashing first
#   3. cleaner chart marks: arrows only, one per candle, OI instead of the 🧩 (MARKS on the chart hides them)
#   4. NIFTY / SENSEX / BANKNIFTY / VIX: the POINTS too - 24,995.45 +9.05 (+0.04%)
#   5. ⚡ EARLY: the 📈 price signal says where the share is NOW, not only its first alert (BOSCHLTD said 09:44 all day)
#   6. the new 🔍 WHY alerts (patch 140) show as MOVING chips
#   home.html · dashserve.py · engine2.py (one line: yesterday's index close, for exact points).
#   Restarts gir-dash now (safe in market hours); gir-intraday only after 15:35 - until then the points are worked out from the %.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140f; mkdir -p $W
grep -q "patch 140f" $D/home.html && { echo "patch 140f is already installed"; exit 1; }
F="home.html dashserve.py engine2.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
ENG=0
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p140ftest.py; systemctl restart gir-dash; [ $ENG = 1 ] && systemctl restart gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p140f_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140f_patch.py - PATCH 140f (Rama, 9 Nov 15:00):
  1. the alert row (MOVING 14:57 ADANIPORTS ...) glides slowly sideways so every alert can be read; a touch / the mouse /
     the wheel stops it for 6 s, at the end it waits and goes back to the start. 20 chips instead of 12.
  2. opening a share no longer flashes another page first: its screen shows at once ("opening SYM ...") and fills in.
  3. the chart's alert marks are cleaner: one mark per candle, an arrow only (ACT written when it was an ACT alert),
     the OI build-up dot says OI instead of a puzzle piece. MARKS on the chart turns them off.
  4. NIFTY / SENSEX / BANKNIFTY / VIX show the POINTS as well as the %: 24,995.45  +9.05 (+0.04%).
     The engine now sends yesterday's close (exact points); until the engine restarts the page works the points out
     from the % (within a point or two).
  5. ⚡ EARLY: the 📈 price signal says where the share is NOW, not only the first alert (BOSCHLTD showed 09:44 all day);
     a share that has turned the other way (0.5%+) flips the 📈 to the new side - the BUY / WATCH count follows.
Usage: python3 p140f_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
HOME = [
    # 1. the alert row glides
    ('''#abar .ac{flex:1;display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:3px 4px;align-items:center}''',
     '''#abar .ac{flex:1;display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:3px 4px;align-items:center}/* patch 140f */#abar .ac .ch{flex:none}'''),
    ('''list.slice(0,ALANE==="all"?12:40)''', '''list.slice(0,ALANE==="all"?20:40)'''),
    ('''setInterval(loadThree,120000); setView(VIEW);''',
     '''setInterval(loadThree,120000); aGlideInit(); setView(VIEW);'''),
    ('''function drawAlerts(force){''',
     '''/* patch 140f: the alert row glides slowly sideways (ALL only); a touch, the mouse or the wheel stops it for 6 s */
const AGL={x:null,stop:0,end:0,hov:false};
function aGlideInit(){ const B=$("abar"); if(!B||aGlideInit.on) return; aGlideInit.on=true;
  const hold=ms=>{ AGL.stop=Math.max(AGL.stop,Date.now()+ms); AGL.x=null; };
  B.addEventListener("pointerenter",e=>{ if(e.pointerType==="mouse"){ AGL.hov=true; hold(1000); } });
  B.addEventListener("pointerleave",e=>{ if(e.pointerType==="mouse"){ AGL.hov=false; hold(2000); } });
  B.addEventListener("pointerdown",()=>hold(6000)); B.addEventListener("touchstart",()=>hold(6000),{passive:true}); B.addEventListener("wheel",()=>hold(6000),{passive:true});
  setInterval(()=>{ try{ const c=B.querySelector(".ac"); const now=Date.now();
    if(!c||B.classList.contains("lane")||document.hidden||AGL.hov||now<AGL.stop) return;
    const max=c.scrollWidth-c.clientWidth; if(max<=4){ AGL.x=null; return; }
    if(AGL.end){ if(now>=AGL.end){ AGL.end=0; c.scrollLeft=0; AGL.x=0; AGL.stop=now+2500; } return; }
    if(AGL.x==null||Math.abs(c.scrollLeft-AGL.x)>3) AGL.x=c.scrollLeft;
    AGL.x=Math.min(max,AGL.x+1); c.scrollLeft=AGL.x; if(AGL.x>=max-1) AGL.end=now+3000; }catch(e){} },45); }
function drawAlerts(force){'''),
    ('''  if(k==="📰") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 117: a filing / a wire story''',
     '''  if(k==="📰") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 117: a filing / a wire story
  if(k==="🔍"&&/^🔍 WHY/.test(H)) return "move";      // patch 140f: THE MOVE EXPLAINED (patch 140) is a MOVING chip'''),
    # 2. no flash of another page while a share opens
    ('''  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;''',
     '''  { const F0=$("focus"); if(F0.hidden&&fresh){ F0.hidden=false; if(window.innerWidth<900) F0.classList.add("sheet"); else { F0.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
      F0.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">opening ${esc(sym)}'s trading screen…</div>`; } }   // patch 140f: its screen at once, no other page in between
  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;'''),
    # 3. cleaner chart marks
    ('''text:(r.kind||"")+(tr!=="watch"?" "+tr.toUpperCase():"")});''', '''text:tr==="act"?"ACT":""});'''),   # arrows only
    ('''shape:"circle",text:"🧩"});''', '''shape:"circle",text:"OI"});'''),
    ('''mk.sort((a,b)=>a.time-b.time); try{ s.setMarkers(mk); }catch(e){} }''',
     '''mk.sort((a,b)=>a.time-b.time); const mk2=[], one_={}; mk.forEach(m=>{ const k=m.time+"|"+m.shape; const o=one_[k]; if(o){ if(m.text==="ACT"){ o.text="ACT"; o.color=m.color; } return; } one_[k]=m; mk2.push(m); });   // patch 140f: one mark a candle
    try{ s.setMarkers(mk2); }catch(e){} }'''),
    # 4. the points as well as the %
    ('''<small class="${cls(x.chg)}">${pc(x.chg)}</small></div></div>`; };''',
     '''<small class="${cls(x.chg)}">${ptsOf(x)} (${pc(x.chg)})</small></div></div>`; };'''),
    ('''function idxHTML(d){''',
     '''/* patch 140f: the points as well as the % - exact from yesterday's close (pc) when the engine sends it */
function ptsOf(x){ if(!x||x.last==null) return ""; let v=null; if(x.pc) v=x.last-x.pc; else if(x.chg!=null) v=x.last-x.last/(1+x.chg/100); if(v==null||!isFinite(v)) return ""; return (v>=0?"+":"")+v.toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2}); }
function idxHTML(d){'''),
    ('''NIFTY ${ix.last!=null?inr(ix.last):""} <tspan fill="${(ix.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(ix.chg)}</tspan>''',
     '''NIFTY ${ix.last!=null?inr(ix.last):""} <tspan fill="${(ix.chg||0)>=0?"var(--up)":"var(--dn)"}">${ptsOf(ix)} ${mkPc(ix.chg)}</tspan>'''),
    ('''BANKNIFTY ${bx.last!=null?inr(bx.last):""} <tspan fill="${(bx.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(bx.chg)}</tspan>''',
     '''BANKNIFTY ${bx.last!=null?inr(bx.last):""} <tspan fill="${(bx.chg||0)>=0?"var(--up)":"var(--dn)"}">${ptsOf(bx)} ${mkPc(bx.chg)}</tspan>'''),
]
DASH = [
    ('''        if "price" not in e["sig"] and chg is not None and abs(chg) >= 1:
            e["sig"]["price"] = {"side": "CE" if chg > 0 else "PE", "lv": "%+.1f%% today" % chg, "t": "", "head": "the share %+.1f%% today" % chg, "why": ""}''',
     '''        hm_ = dt.datetime.now(IST).strftime("%H:%M") if day == today else "close"      # patch 140f: the price signal says where the share is NOW
        ps_ = e["sig"].get("price")
        if ps_ is not None and chg is not None:
            if abs(chg) >= 0.5 and ("CE" if chg > 0 else "PE") != ps_["side"]:
                e["sig"]["price"] = {"side": "CE" if chg > 0 else "PE", "lv": "turned %+.1f%%" % chg, "t": hm_, "why": "",
                                     "head": "now %+.1f%% today (%s) - it has turned from the %s alert: %s" % (chg, hm_, ps_["t"], ps_["head"][:90])}
            else:
                ps_["head"] = "now %+.1f%% today (%s) · the alert at %s: %s" % (chg, hm_, ps_["t"], ps_["head"][:110])
        if "price" not in e["sig"] and chg is not None and abs(chg) >= 1:
            e["sig"]["price"] = {"side": "CE" if chg > 0 else "PE", "lv": "%+.1f%% today" % chg, "t": hm_, "head": "the share %+.1f%% today (%s)" % (chg, hm_), "why": ""}'''),
]
ENGINE = [
    ('''                        IDX[nm_] = {"last": round(lp_, 2), "chg": round((lp_ / pc_ - 1) * 100, 2) if pc_ else None}''',
     '''                        IDX[nm_] = {"last": round(lp_, 2), "chg": round((lp_ / pc_ - 1) * 100, 2) if pc_ else None, "pc": round(pc_, 2) if pc_ else None}   # patch 140f: + yesterday's close (the points)'''),
]


def main():
    out = {}
    for fn, eds in (("home.html", HOME), ("dashserve.py", DASH), ("engine2.py", ENGINE)):
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        if "patch 140f" in s:
            print("patch 140f is already in %s" % fn); return 1
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: home.html, dashserve.py, engine2.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p140ftest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p140ftest.py - patch 140f: the ⚡ EARLY price signal says where the share is now (stub data, nothing live touched)"""
import os, sys, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ok = True
def check(name, good):
    global ok
    print(("PASS " if good else "FAIL ") + name); ok = ok and bool(good)
today = dt.datetime.now(ds.IST).strftime("%Y-%m-%d")
def mk():
    c = sqlite3.connect(":memory:")
    c.execute("create table alerts(day, t, kind, sym, side, text)")
    c.execute("insert into alerts values(?,?,?,?,?,?)", (today, "09:44:26", "🚀", "BOSCHLTD", "PE", "🚀 RUNNING ▼ BOSCHLTD ₹49250 -3.1% · 09:44:26"))
    c.execute("insert into alerts values(?,?,?,?,?,?)", (today, "10:02:00", "🚀", "TATASTEEL", "PE", "🚀 RUNNING ▼ TATASTEEL ₹182 -3.0% · 10:02:00"))
    return c
Q = {"q": {"BOSCHLTD": [50100.0, 0.9], "TATASTEEL": [181.0, -2.1]}}
ds._tom = mk; ds.live_obj = lambda: {}; ds.quotes_live = lambda: Q; ds.fo_set = lambda: {"BOSCHLTD", "TATASTEEL"}
ds._strike = lambda *a: None; ds._bars = lambda s: []; ds._px_at = lambda *a: None; ds._score_update = lambda c: None; ds._record = lambda: []
v = ds.early(fresh=True)
R = {r["s"]: r for r in v["rows"]}
b, t = (R.get("BOSCHLTD") or {}).get("sig", {}).get("price") or {}, (R.get("TATASTEEL") or {}).get("sig", {}).get("price") or {}
check("BOSCHLTD fell at 09:44 and is +0.9%% now: the 📈 turns ▲ and says so (%s)" % b.get("head"), b.get("side") == "CE" and "turned" in (b.get("head") or "") and "09:44" in (b.get("head") or ""))
check("TATASTEEL still down: the 📈 stays ▼ and says now -2.1%% (%s)" % t.get("head"), t.get("side") == "PE" and "now -2.1%" in (t.get("head") or ""))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p140f_patch.py $D || { rm -f $D/p140ftest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py engine2.py p140ftest.py || back
for t in p140ftest.py p139test.py p136test.py p129test.py p128test.py p120test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then
  echo "    market hours: the engine is NOT restarted - exact points from its next restart (patch 140 restarts it after 15:35)"
else
  ENG=1; systemctl restart gir-intraday && sleep 10
  [ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
  echo "    gir-intraday restarted - exact index points"
fi
echo
echo "PATCH 140f APPLIED. Reload the GIR page: the alert row glides, shares open at once, the index boxes show points,"
echo "⚡ EARLY's 📈 says where each share is now."
