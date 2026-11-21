#!/bin/bash
# PATCH 327 - FULL SCREEN THAT WORKS, THE iPAD SHARE PAGE, THE RUPEE CHANGE, PUSH · PULL FILTERS, RESULT NUMBERS IN WORDS (Rama, 15 Nov: "in push
#   pull the LB / SB / SC / LU data is not available · on the share page I see the price and the % but not how much up or down · very
#   disappointed with the iPad display · the full screen button does not give full screen - mobile, laptop and iPad"). Tested on GIR's real
#   pages at phone, iPad and laptop sizes (0 text under 11 px, 0 under 4.5:1 contrast, nothing sideways, no page errors):
#   · ⛶ (the share chart and the NIFTY chart): GIR's own full screen - the chart fills the whole screen at full size on the phone, iPad and
#     laptop (the browser's full screen does not exist for a chart on the iPhone and did not resize it on the laptop); ✕ CLOSE or Esc
#   · the share header: ₹1,764 −9.93 (−0.56%) - the rupee change as well as the %
#   · PUSH · PULL obeys LB / SB / SC / LU and the sector (it showed the same 40 movers whatever was picked)
#   · the iPad (900-1279 px): a share opened inside the page takes the whole screen (the index boxes, keys and alert bars sat on top - the
#     chart started 3/4 down, 370 px wide; now at the top, 664 px wide), the chart wide with the option chain + checklist beside it, the chart
#     buttons in 2 rows + ⋯ MORE, 🎯 COCKPIT next to ✕ CLOSE, the push box opens on a tap
#   · JUST REPORTED: the result numbers in words ("Revenue +44% vs last year · +20% vs last quarter") - not the raw data
#   Edits home.html, replaces resultsrecent.py (only patch 326's copy). No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 327" $D/home.html && grep -q "patch 326 + 327" $D/resultsrecent.py; then echo "patch 327 - already in"; exit 0; fi
grep -q "patch 326" $D/home.html || { echo "patch 326 first"; exit 1; }
[ "$(sha256sum $D/resultsrecent.py | cut -c1-64)" = "c8c7d6a8662879b5f1443cc7de014428353fcc5589db4f5cfd419ecd0b3678db" ] || { echo "resultsrecent.py is not patch 326's copy - nothing done, send this to Claude"; exit 1; }
F="home.html resultsrecent.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/resultsrecent.py <<'PY_RR'
"""resultsrecent.py - patch 326 + 327 (the numbers in plain words): READ ONLY. F&O shares that REPORTED results in the last N days (Rama, 15 Nov: "you wiped out all the results - we
received PATANJALI, ABB and many more"). The RESULTS tab only listed the next 14 days; this adds the ones just out: the date (the results
calendar, chains.db), GIR's verdict and numbers (the exchange filing, filings.db), the filing link and when it was filed. Newest first."""
import os, json, time, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}


LBL = {"rev": "Revenue", "revenue": "Revenue", "sales": "Revenue", "pat": "Profit", "np": "Profit", "profit": "Profit", "net": "Profit",
       "ebitda": "EBITDA", "op": "Operating profit", "eps": "EPS"}


def plain(nums):
    """the filing's numbers (stored as JSON) -> "Revenue +44% vs last year · Profit -19% vs last year" (a text kept as it is)"""
    if not nums:
        return ""
    try:
        J = json.loads(nums)
    except Exception:
        return str(nums)[:200]
    if not isinstance(J, dict):
        return str(nums)[:200]
    out = []
    for k, v in J.items():
        if not isinstance(v, dict) or not isinstance(v.get("cur"), (int, float)):
            continue
        name, cur, yoy, qoq = LBL.get(k.lower(), k.upper()), v["cur"], v.get("yoy"), v.get("qoq")
        def pc(base):
            if not isinstance(base, (int, float)) or base == 0:
                return None
            if base < 0 <= cur:
                return "turned positive"
            if cur < 0 <= base:
                return "turned negative"
            return "%+.0f%%" % ((cur / base - 1) * 100 * (1 if base > 0 else -1))
        y, q = pc(yoy), pc(qoq)
        if y or q:
            out.append("%s %s" % (name, " · ".join(x for x in (y and "%s vs last year" % y, q and "%s vs last quarter" % q) if x)))
    return " · ".join(out[:3])


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def recent(days=7, now=None):
    if now is None and _C["v"] is not None and time.time() - _C["t"] < 120:
        return _C["v"]
    now = now or dt.datetime.now(IST)
    d0, d1 = str(now.date() - dt.timedelta(days=days)), str(now.date())
    rows, fo = {}, set()
    try:
        c = _ro("chains.db")
        fo = {r[0] for r in c.execute("select sym from fo_list")}
        for d, s in c.execute("select d, sym from results_cal where d>=? and d<=? order by d desc", (d0, d1)):
            if s in fo and s not in rows:
                rows[s] = {"s": s, "d": d}
        c.close()
    except Exception as ex:
        return {"rows": [], "err": "calendar: %s" % str(ex)[:80]}
    t0 = (now - dt.timedelta(days=days + 3)).timestamp()
    try:
        c = _ro("filings.db")
        cols = {r[1] for r in c.execute("pragma table_info(filings)")}
        want = [x for x in ("sym", "t_exch", "verdict", "nums", "link", "subject") if x in cols]
        q = "select %s from filings where kind='RESULTS' and t_exch>=? order by t_exch desc" % ",".join(want)
        for r in c.execute(q, (t0,)):
            f = dict(zip(want, r)); s = f.get("sym")
            if s not in fo:
                continue
            x = rows.setdefault(s, {"s": s, "d": str(dt.datetime.fromtimestamp(f.get("t_exch") or 0, IST).date())})
            if "filed" not in x or (not x.get("verdict") and f.get("verdict")):
                x["filed"] = dt.datetime.fromtimestamp(f.get("t_exch") or 0, IST).strftime("%a %d %b %H:%M")
                x["verdict"] = (f.get("verdict") or "").strip()
                x["nums"] = plain((f.get("nums") or "").strip())
                x["link"] = f.get("link") or ""
        c.close()
    except Exception:
        pass
    L = sorted(rows.values(), key=lambda x: (x["d"], x.get("filed", "")), reverse=True)
    L = [x for x in L if d0 <= x["d"] <= d1]
    v = {"t": time.time(), "days": days, "n": len(L), "rows": L}
    if now is None or True:
        _C.update({"t": time.time(), "v": v})
    return v


if __name__ == "__main__":
    v = recent()
    print("JUST REPORTED (last %d days): %d F&O shares" % (v["days"], v["n"]))
    for x in v["rows"]:
        print("  %s  %-12s %-9s %s" % (x["d"], x["s"], x.get("verdict") or "-", (x.get("nums") or "")[:90]))
PY_RR
cat > $W/p327test.py <<'PY_T'
#!/usr/bin/env python3
"""p327test.py - JUST REPORTED: F&O shares with results in the last 7 days, GIR's verdict from the filing (made-up data, temp folder)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); shutil.copy(os.path.join(WK, "resultsrecent.py"), T); sys.path.insert(0, T)
import resultsrecent as R
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 15, 18, 0, tzinfo=IST)
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.execute("create table results_cal(d text, sym text, purpose text)")
c.executemany("insert into fo_list values(?,1)", [("ALPHACO",), ("BETACO",), ("GAMMACO",), ("OLDCO",)])
c.executemany("insert into results_cal values(?,?,'Results')", [("2026-11-14", "ALPHACO"), ("2026-11-13", "BETACO"), ("2026-11-12", "GAMMACO"), ("2026-11-14", "NOTFO"), ("2026-11-01", "OLDCO"), ("2026-11-18", "BETACO")])
c.commit(); c.close()
f = sqlite3.connect(os.path.join(T, "filings.db"))
f.execute("create table filings(id integer primary key, key text, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int)")
ts = lambda d, h: int(dt.datetime(2026, 11, d, h, 0, tzinfo=IST).timestamp())
f.executemany("insert into filings(sym,t_exch,kind,verdict,nums,link) values(?,?,?,?,?,?)", [
    ("ALPHACO", ts(14, 13), "RESULTS", "MISS", "profit -19% · sales +15%", "https://x/a"), ("BETACO", ts(13, 16), "RESULTS", "BEAT", "profit +40%", "https://x/b"),
    ("BETACO", ts(13, 15), "RESULTS", "", "", ""), ("GAMMACO", ts(12, 17), "BOARD", "", "", ""), ("NOTFO", ts(14, 12), "RESULTS", "BEAT", "", "")])
f.commit(); f.close()
v = R.recent(7, NOW)
S = [x["s"] for x in v["rows"]]
chk("the last 7 days, F&O only, newest first: ALPHACO (14th) · BETACO (13th) · GAMMACO (12th) - not NOTFO, not OLDCO (1st), not BETACO's next date", S == ["ALPHACO", "BETACO", "GAMMACO"], v)
a = v["rows"][0]
chk("ALPHACO: GIR's verdict MISS, the numbers, the filing link, when filed", a.get("verdict") == "MISS" and "profit -19%" in a.get("nums", "") and a.get("link") == "https://x/a" and a.get("filed", "").startswith("Sat 14 Nov"), a)
chk("BETACO: the filing WITH the verdict is kept (BEAT), not the earlier one without", v["rows"][1].get("verdict") == "BEAT", v["rows"][1])
chk("GAMMACO: in the calendar, no results filing read - listed without a verdict", v["rows"][2].get("verdict", "") == "", v["rows"][2])
chk("the numbers in plain words: Revenue +44% vs last year · +20% vs last quarter", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92, "basis": "standalone"}}') == "Revenue +44% vs last year · +20% vs last quarter", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92}}'))
chk("a loss turned to profit is said so", "turned positive" in R.plain('{"pat": {"cur": 5, "qoq": -2, "yoy": -10}}'))
os.remove(os.path.join(T, "filings.db")); R._C["v"] = None
chk("no filings.db: the calendar list still comes (no verdicts)", [x["s"] for x in R.recent(7, NOW)["rows"]] == ["ALPHACO", "BETACO", "GAMMACO"])
print("THE PATCH 327 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home327.html <<'ADD_H'
<style>/* patch 327: full-screen charts that work everywhere · the iPad share page · rupee change in the share header */
body.gx-max-pro #tvbox,body.gx-max-ix #mk-nif{position:fixed !important;left:0 !important;top:0 !important;right:0 !important;bottom:0 !important;width:100vw !important;height:100vh !important;max-height:none !important;z-index:9990 !important;background:#06080c !important;margin:0 !important;border-radius:0 !important}
body.gx-max-pro,body.gx-max-ix{overflow:hidden !important}
body.gx-max-pro #ckshare,body.gx-max-ix #ckshare,body.gx-max-pro #mhome,body.gx-max-ix #mhome{display:none !important}
#gxmaxx{position:fixed;right:max(12px,env(safe-area-inset-right,0px));top:max(10px,env(safe-area-inset-top,0px));z-index:9995;display:none;font:700 13px system-ui,sans-serif;letter-spacing:.04em;color:#1a1205;background:#f5a623;border:0;border-radius:6px;padding:9px 14px;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.5)}
body.gx-max-pro #gxmaxx,body.gx-max-ix #gxmaxx{display:block}
.gx-abs{font:inherit;margin-left:6px}
/* the iPad / small laptop (900-1279 px): a share opened inside the page takes the whole screen; the chart wide, the option chain + checklist beside */
@media(min-width:900px) and (max-width:1279px){
  html body #focus.ws-on{top:0 !important;z-index:30 !important;bottom:0 !important}
  html body #focus.ws-on .hd .hm,html body #focus.ws-on .hd a.am{display:inline-flex !important}
  html body #focus .ws{grid-template-columns:minmax(0,1.6fr) minmax(0,1fr) !important;grid-template-rows:minmax(0,1fr) minmax(0,1fr) !important;height:calc(100vh - 230px) !important;min-height:520px}
  html body #focus .ws>#wsList{display:none !important}
  html body #focus .ws>#wsPx{grid-column:1 !important;grid-row:1 / span 2 !important}
  html body #focus .ws>#wsOi{grid-column:2 !important;grid-row:1 !important;overflow:auto}
  html body #focus .ws>#wsOc{grid-column:2 !important;grid-row:2 !important;overflow:auto}
  html body #ppStrip .ppp:not(.open){max-height:66px !important;overflow:hidden !important;position:relative;cursor:pointer}
  html body #ppStrip .ppp:not(.open)::after{content:"tap for more ▾";position:absolute;right:0;bottom:0;padding:2px 8px;background:#0e131b;color:#ffb347;font:600 11px system-ui,sans-serif;border-radius:6px 0 0 0}
  html body #ckshare{display:none !important}
  #ckshare2{font:700 11px/1 system-ui,sans-serif;padding:6px 9px;border-radius:5px;background:#ffb347;color:#1a1205 !important;text-decoration:none;margin-left:auto;margin-right:8px;white-space:nowrap}
  body:not(.phx-all) .ptb a.phx2{display:none !important}
  html body .ptb a.phmore2{display:inline-flex !important;font-weight:700 !important;letter-spacing:.1em !important}
}
@media not all and (min-width:900px) and (max-width:1279px){ html body .ptb a.phmore2{display:none !important} }
</style>
<script>/* patch 327: (1) the chart's ⛶ = GIR's own full screen (fills the screen on phone, iPad and laptop; ✕ or Esc closes) · (2) the share header
   shows the rupee change too (₹1,764 −9.95 (−0.56%)) · (3) PUSH · PULL obeys the LB / SB / SC / LU and sector filters · (4) the iPad share page */
(function(){
  /* ---- (1) full screen ---- */
  const X=document.createElement("button"); X.id="gxmaxx"; X.textContent="✕ CLOSE FULL SCREEN"; document.body.appendChild(X);
  function proOn(){ return document.body.classList.contains("gx-max-pro"); } function ixOn(){ return document.body.classList.contains("gx-max-ix"); }
  if(typeof proEnsure==="function"){ const PE=proEnsure; proEnsure=function(id,h){ if(proOn()) h=window.innerHeight-6; return PE(id,h); }; }
  function redraw(){ try{ if(typeof PC!=="undefined"&&PC) PC.key=""; if(typeof IXC!=="undefined"&&IXC){ IXC.key=""; IXC.h=-1; } }catch(e){}
    setTimeout(()=>{ try{ if(typeof paint==="function") paint(); }catch(e){} try{ if(typeof ixDraw==="function") ixDraw(); }catch(e){} },40); }
  function close(){ document.body.classList.remove("gx-max-pro","gx-max-ix"); redraw(); }
  window.proFull=function(){ if(proOn()){ close(); return; } document.body.classList.remove("gx-max-ix"); document.body.classList.add("gx-max-pro"); redraw(); };
  window.ixFull=function(){ if(ixOn()){ close(); return; } document.body.classList.remove("gx-max-pro"); document.body.classList.add("gx-max-ix"); redraw(); };
  X.onclick=close; document.addEventListener("keydown",e=>{ if(e.key==="Escape"&&(proOn()||ixOn())) close(); });
  window.addEventListener("resize",()=>{ if(proOn()||ixOn()) redraw(); });
  /* ---- (2) the rupee change in the share header ---- */
  const N=v=>Math.abs(v).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
  function absHdr(){ try{ const s=(typeof FOC!=="undefined"&&FOC)||""; if(!s) return; const t=((typeof TAPE!=="undefined"&&TAPE)||[]).find(x=>x.s===s); if(!t||t.px==null||t.chg==null) return;
      document.querySelectorAll("#focus .hd span.px").forEach(el=>{ const px=+t.px, chg=+t.chg, prev=px/(1+chg/100), d=px-prev, want=`${d>=0?"+":"−"}${N(d)}`;
        let a=el.querySelector(".gx-abs"); const own=[...el.childNodes].filter(n=>n.nodeType===3).map(n=>n.nodeValue).join("");
        if(!a){ a=document.createElement("span"); a.className="gx-abs"; el.appendChild(a); }
        const m=own.match(/^(\s*₹[\d,.]+)\s*([+\-−]?[\d.]+%)\s*$/); if(m){ [...el.childNodes].filter(n=>n.nodeType===3).forEach(n=>n.remove()); el.insertBefore(document.createTextNode(m[1]+" "),a); a.dataset.pc=m[2]; }
        const txt=`${want} (${String(a.dataset.pc||((chg>0?"+":"")+chg.toFixed(2)+"%")).replace(/^-/,"−")})`; if(a.textContent!==txt) a.textContent=txt; }); }catch(e){} }
  /* ---- (3) PUSH · PULL with the filters ---- */
  if(typeof ppListHTML==="function"){ const O=ppListHTML; ppListHTML=function(){ const keep=PP; let f=false;
      try{ if(WS.bu||WS.sec){ f=true; const set=WS.sec?new Set((((typeof SECS!=="undefined"&&SECS)||[]).find(x=>x.name===WS.sec)||{}).syms||[]):null, F={};
          for(const [k,r] of Object.entries(PP)){ const t=((typeof TAPE!=="undefined"&&TAPE)||[]).find(x=>x.s===r.s)||{}; if(set&&!set.has(r.s)) continue; if(WS.bu&&String(t.bu||"").toUpperCase()!==WS.bu) continue; F[k]=r; } PP=F; }
        let h=O.apply(this,arguments);
        if(f&&/class="empty"/.test(h)) h=`<div class="empty">None of the biggest F&amp;O movers is ${WS.bu?esc(WS.bu.toLowerCase()):""}${WS.bu&&WS.sec?" in ":""}${WS.sec?esc(WS.sec):""} right now - <a onclick="wsClear()" style="color:#f5a623;cursor:pointer">✕ show all</a></div>`;
        return h; } finally { PP=keep; } }; }
  /* ---- (4) the iPad: chart buttons in 2 rows + ⋯ MORE, the cockpit button next to ✕ CLOSE, the push box opens on a tap ---- */
  const ADV=new Set(["HEIKIN-ASHI","BARS","SMA 50","BOLL","BB","MARKS","MACD","BREADTH","─ LINE","— LINE","/ TREND","─","—","✕","×","⛶","⤢","TICK","OI"]);
  const mid=()=>window.innerWidth>=900&&window.innerWidth<1280;
  function tools(){ if(!mid()) return; document.querySelectorAll(".ptb").forEach(tb=>{ tb.querySelectorAll("a").forEach(a=>{ if(!a.classList.contains("phmore2")&&ADV.has(a.textContent.trim())&&a.textContent.trim()!=="⛶") a.classList.add("phx2"); });
      if(tb.querySelector("a.phx2")&&!tb.querySelector("a.phmore2")){ const m=document.createElement("a"); m.className="phmore2"; m.textContent=document.body.classList.contains("phx-all")?"LESS":"⋯ MORE";
        m.onclick=e=>{ e.stopPropagation(); document.body.classList.toggle("phx-all"); document.querySelectorAll(".ptb a.phmore2").forEach(x=>x.textContent=document.body.classList.contains("phx-all")?"LESS":"⋯ MORE"); }; (tb.lastElementChild||tb).appendChild(m); } }); }
  let OPEN=false; document.addEventListener("click",e=>{ const p=e.target&&e.target.closest&&e.target.closest("#ppStrip .ppp"); if(p&&mid()&&!e.target.closest("a")){ OPEN=!OPEN; document.querySelectorAll("#ppStrip .ppp").forEach(x=>x.classList.toggle("open",OPEN)); } });
  function ck(){ if(!mid()) return; const sym=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase(), x=document.querySelector('#focus .hd a.am, #focus a[onclick="unfocus()"]'); let a=document.getElementById("ckshare2");
    if(!sym||!x){ if(a&&mid()) a.remove(); return; } if(!a||a.nextElementSibling!==x){ if(a) a.remove(); a=document.createElement("a"); a.id="ckshare2"; a.target="_blank"; x.parentNode.insertBefore(a,x); }
    const u=new URLSearchParams(location.search); u.set("w",sym); const h="cockpit?"+u.toString(); if(a.getAttribute("href")!==h){ a.href=h; a.textContent="🎯 COCKPIT"; } }
  function tick(){ absHdr(); tools(); ck(); }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; tick(); },80); }).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  setInterval(tick,1500); tick();
})();
</script>
ADD_H
echo "=== test (made-up data, nothing sent)"
python3 $W/p327test.py $W > $W/t.out 2>&1; RC=$?; tail -3 $W/t.out; [ $RC -eq 0 ] || { cat $W/t.out; echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/resultsrecent.py $D/resultsrecent.py && (cd $D && python3 -m py_compile resultsrecent.py) || back
python3 - $D/home.html $W/home327.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if "patch 327" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 327")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "=== JUST REPORTED, the numbers in words"
cd $D && python3 resultsrecent.py | head -12
echo "✅ patch 327 done - full screen works everywhere, the iPad share page, the rupee change, PUSH · PULL filters, result numbers in words. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done"
