#!/bin/bash
# PATCH 326 - RESULTS: JUST REPORTED (Rama, 15 Nov: "you wiped out all the results - we received PATANJALI, ABB and many more"). Nothing was
#   wiped: the RESULTS tab only listed the NEXT 14 days, and the Sept-quarter season ended on 14 Nov (the 5 results still to come are not F&O
#   shares). Now under the upcoming list: JUST REPORTED - every F&O share with results in the last 7 days, newest first: the date, GIR's
#   verdict (BEAT / MISS / IN LINE ... from the exchange filing), the numbers, when it was filed, the move on the day, the filing link; tap = the
#   share's page. resultsrecent.py (READ ONLY: chains.db's calendar + filings.db) · dashserve.py /resultsrecent · home.html. Also: patch 320's
#   wording cleaner never touches a script's own text again (it broke a script containing "tap = ..."). Tested: 5 + laptop / iPad / phone.
#   Restarts the dashboard (the new route).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "patch 326" $D/home.html && grep -q "patch 326" $D/dashserve.py && [ -f $D/resultsrecent.py ]; then echo "patch 326 - already in"; exit 0; fi
grep -q "patch 325" $D/home.html || { echo "patch 325 first"; exit 1; }
grep -q "function drawResults()" $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "the RESULTS page / the cockpit route not found - nothing done, send this to Claude"; exit 1; }
F="home.html dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/resultsrecent.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/resultsrecent.py <<'PY_RR'
"""resultsrecent.py - patch 326: READ ONLY. F&O shares that REPORTED results in the last N days (Rama, 15 Nov: "you wiped out all the results - we
received PATANJALI, ABB and many more"). The RESULTS tab only listed the next 14 days; this adds the ones just out: the date (the results
calendar, chains.db), GIR's verdict and numbers (the exchange filing, filings.db), the filing link and when it was filed. Newest first."""
import os, json, time, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}


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
                x["nums"] = (f.get("nums") or "").strip()[:220]
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
cat > $W/p326test.py <<'PY_T'
#!/usr/bin/env python3
"""p326test.py - JUST REPORTED: F&O shares with results in the last 7 days, GIR's verdict from the filing (made-up data, temp folder)"""
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
os.remove(os.path.join(T, "filings.db")); R._C["v"] = None
chk("no filings.db: the calendar list still comes (no verdicts)", [x["s"] for x in R.recent(7, NOW)["rows"]] == ["ALPHACO", "BETACO", "GAMMACO"])
print("THE PATCH 326 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home326.html <<'ADD_H'
<style>/* patch 326: RESULTS - JUST REPORTED (last 7 days) under the upcoming list */
.jr{margin:14px 0 4px}.jr h3{font:700 12px ui-monospace,Menlo,monospace;letter-spacing:.12em;color:#e6edf3;margin:0 0 8px;display:flex;gap:10px;align-items:baseline;flex-wrap:wrap}
.jr h3 small{font:500 12px -apple-system,"Segoe UI",Roboto,sans-serif;letter-spacing:0;color:#a3aebf}
.jr-g{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:8px}
.jr-c{background:#0c1118;border:1px solid #1c2532;border-left:3px solid #273244;border-radius:6px;padding:9px 11px;cursor:pointer;min-width:0}
.jr-c.up{border-left-color:#26c281}.jr-c.dn{border-left-color:#f0544f}.jr-c.am{border-left-color:#f5a623}
.jr-t{display:flex;gap:8px;align-items:baseline;flex-wrap:wrap}.jr-t b{font:700 14px ui-monospace,Menlo,monospace;color:#e6edf3}
.jr-v{font:700 11px ui-monospace,Menlo,monospace;padding:2px 7px;border-radius:3px;background:#1b222d;color:#a3aebf}.jr-v.up{background:#0d3324;color:#26c281}.jr-v.dn{background:#3a1416;color:#f0544f}.jr-v.am{background:#3a2c10;color:#f5a623}
.jr-px{margin-left:auto;font:600 12.5px ui-monospace,Menlo,monospace}.jr-m{color:#a3aebf;font-size:12px;margin-top:4px;overflow-wrap:anywhere}.jr-m a{color:#f5a623}
@media(max-width:899px){ .jr-g{grid-template-columns:1fr} }
</style>
<script>/* patch 326: RESULTS - F&O shares that reported in the last 7 days (the date, GIR's verdict and numbers, today's move, the filing) */
(function(){ if(typeof drawResults!=="function") return; let JR=null;
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], DAY=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dl=d=>{ const x=new Date(d+"T00:00:00Z"); return DAY[x.getUTCDay()]+" "+(+d.slice(8,10))+" "+MON[x.getUTCMonth()]; };
  const cls=v=>/BEAT|STRONG/.test(v)?"up":/MISS|WEAK|LOSS/.test(v)?"dn":v?"am":"";
  function block(){ if(!JR||!JR.rows) return "";
    const tp=s=>{ try{ return ((typeof D!=="undefined"&&D&&D.tape)||[]).find(x=>x.s===s)||null; }catch(e){ return null; } };
    const L=JR.rows; if(!L.length) return `<div class="jr"><h3>JUST REPORTED <small>no F&amp;O results in the last 7 days</small></h3></div>`;
    return `<div class="jr"><h3>JUST REPORTED <small>${L.length} F&amp;O shares in the last 7 days · newest first · tap a card to open the share</small></h3><div class="jr-g">${L.map(r=>{ const t=tp(r.s), v=r.verdict||"";
      return `<div class="jr-c ${cls(v)}" onclick="try{ mkOpen('${E(r.s)}') }catch(e){}"><div class="jr-t"><b>${E(r.s)}</b><span class="jr-v ${cls(v)}">${v?E(v):"verdict not read"}</span><span class="dim">${E(dl(r.d))}${r.filed?` · filed ${E(r.filed.replace(/^\w{3} /,""))}`:""}</span>
        ${t&&t.chg!=null?`<span class="jr-px ${t.chg>0?"pu":t.chg<0?"pd":""}">${t.chg>0?"+":""}${Number(t.chg).toFixed(2)}% on the day</span>`:""}</div>
        ${r.nums||r.link?`<div class="jr-m">${E(r.nums||"")}${r.link?` ${r.nums?"· ":""}<a href="${E(r.link)}" target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()">the filing ↗</a>`:""}</div>`:""}</div>`; }).join("")}</div></div>`; }
  const O=drawResults; drawResults=function(){ O.apply(this,arguments); try{ const el=$("resl"); if(!el) return; let b=el.querySelector(":scope>.jr"); const h=block(); if(!h) return;
    if(b) b.outerHTML=h; else el.insertAdjacentHTML("beforeend",h); const em=el.querySelector(":scope>.empty"); if(em&&/no F&O results/.test(em.textContent)) em.textContent="No F&O results in the next 14 days (the Sept-quarter season ended on 14 Nov) - the ones just out are below."; }catch(e){} };
  async function pull(){ try{ const v=await getJ("resultsrecent?k="+encodeURIComponent(K)); if(v&&v.rows){ JR=v; drawResults(); } }catch(e){} }
  pull(); setInterval(()=>{ if(!document.hidden&&typeof VIEW!=="undefined"&&VIEW==="results") pull(); },120000);
})();
</script>
ADD_H
echo "=== test (made-up data, nothing sent)"
python3 $W/p326test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/resultsrecent.py $D/resultsrecent.py || back
python3 - $D $W/home326.html <<'PY_EDIT' || back
import os, sys
D, add = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 326" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/resultsrecent":            # patch 326: F&O results in the last 7 days (read only)
                try:
                    import resultsrecent
                    v_ = resultsrecent.recent()
                except Exception as ex_:
                    v_ = {"rows": [], "err": str(ex_)[:120]}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /resultsrecent")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 326" not in t:
    OLD = "function fix(n){ const v=n.nodeValue; if(!v||v.length<6) return;"
    NEW = "function fix(n){ const pe_=n.parentNode; if(pe_&&/^(SCRIPT|STYLE|TEXTAREA)$/.test(pe_.nodeName)) return; const v=n.nodeValue; if(!v||v.length<6) return;   /* patch 326: never touch a script's own text */"
    if t.count(OLD) != 1 or t.count("</body>") != 1:
        print("❌ home.html: the cleaner x%d, </body> x%d - send this to Claude" % (t.count(OLD), t.count("</body>"))); sys.exit(1)
    t = t.replace(OLD, NEW, 1).replace("</body>", add + "\n</body>", 1)
    open(h, "w", encoding="utf-8").write(t); print("  home.html: JUST REPORTED + the cleaner fix")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py resultsrecent.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== what the RESULTS tab will show"
cd $D && python3 resultsrecent.py | head -30
echo "✅ patch 326 done - RESULTS: JUST REPORTED (the last 7 days' F&O results with GIR's verdict) under the upcoming list. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/resultsrecent.py; systemctl restart gir-dash"
