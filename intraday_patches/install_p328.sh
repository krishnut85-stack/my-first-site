#!/bin/bash
# PATCH 328 - FIXES TO 327 (Rama, 15 Nov: "the price is continuously blinking on the iPad · most of the iPad tabs are not giving the information
#   · on the laptop the rupee change is still not showing · the COCKPIT · VMM button hides the other details" + the JUST REPORTED cards still raw).
#   Checked this time under constant redraws (as on the live server) at phone, iPad and laptop sizes:
#   · the share header is BUILT with the rupee change (₹1,764 −10.00 (−0.56%)) - 327 rewrote it after each redraw (the blinking), and the
#     laptop's own header was not touched; and a 🎯 COCKPIT button inside the header - the floating pill is gone (it covered the list)
#   · the iPad landscape (900-1099 px): F&O MONEY / BIG MONEY / OPTIONS show their panel (they left the whole MARKET grid on screen)
#   · the iPad upright: the MORE keys wrap; a long news link no longer pushes the NOW page sideways
#   · JUST REPORTED: the page server is RESTARTED so the numbers-in-words code runs (327 replaced the file, the running server kept the old
#     one - my mistake), and only the main lines: Revenue / Profit / EBITDA / EPS
#   Edits home.html, replaces resultsrecent.py (only patch 327's copy). Restarts the dashboard - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "patch 328" $D/home.html && grep -q "patch 326 + 327 + 328" $D/resultsrecent.py; then echo "patch 328 - already in"; exit 0; fi
grep -q "patch 327" $D/home.html || { echo "patch 327 first"; exit 1; }
[ "$(sha256sum $D/resultsrecent.py | cut -c1-64)" = "ef8bc756a7550a98d61692a67a284f5738ceffbffb1dd3752528f81579f812b0" ] || { echo "resultsrecent.py is not patch 327's copy - nothing done, send this to Claude"; exit 1; }
F="home.html resultsrecent.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/resultsrecent.py <<'PY_RR'
"""resultsrecent.py - patch 326 + 327 + 328 (the numbers in plain words, the main lines only): READ ONLY. F&O shares that REPORTED results in the last N days (Rama, 15 Nov: "you wiped out all the results - we
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
        if k.lower() not in LBL:
            continue
        name, cur, yoy, qoq = LBL[k.lower()], v["cur"], v.get("yoy"), v.get("qoq")
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
    return " · ".join(out[:3]) if out else "numbers filed - open the filing"


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
cat > $W/p328test.py <<'PY_T'
#!/usr/bin/env python3
"""p328test.py - JUST REPORTED: F&O shares with results in the last 7 days, GIR's verdict from the filing (made-up data, temp folder)"""
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
chk("only the main lines (revenue, profit) - not other income / expenses / null", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92}, "inc": null, "pat": {"cur": 970.72, "qoq": 721.54, "yoy": 245.22}, "oth": {"cur": 64.94, "yoy": 134.78}, "exp": 1}') == "Revenue +44% vs last year · +20% vs last quarter · Profit +296% vs last year · +35% vs last quarter")
os.remove(os.path.join(T, "filings.db")); R._C["v"] = None
chk("no filings.db: the calendar list still comes (no verdicts)", [x["s"] for x in R.recent(7, NOW)["rows"]] == ["ALPHACO", "BETACO", "GAMMACO"])
print("THE PATCH 328 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home328.html <<'ADD_H'
<style>/* patch 328: the share header built with the rupee change and a 🎯 COCKPIT button in it (no rewriting, no blinking); no floating cockpit pill;
   the iPad landscape's F&O MONEY / BIG MONEY / OPTIONS keys show their panel; the MORE keys wrap (nothing off the edge) */
html body #ckshare,html body #ckshare2{display:none !important}
.hd .gxck{margin-left:auto;font:700 12px/1 system-ui,sans-serif;letter-spacing:.03em;padding:7px 11px;border-radius:5px;background:#f5a623;color:#1a1205 !important;text-decoration:none;white-space:nowrap;flex:none}
.hd .gxck + a.am{margin-left:12px !important}
body.solo #soloHd .gxck{margin-left:auto;margin-right:4px}
@media(min-width:900px) and (max-width:1099px){
  body.mk-money:not(.topchart) #mk>.q,body.mk-big:not(.topchart) #mk>.q,body.mk-opts:not(.topchart) #mk>.q{display:none !important}
  body.mk-money:not(.topchart) #mk>#q-mon,body.mk-big:not(.topchart) #mk>#q-lnk,body.mk-big:not(.topchart) #mk>#q-ins,body.mk-opts:not(.topchart) #mk>#q-idx{display:flex !important;order:0 !important;height:auto !important;max-height:none !important}
  body.mk-big:not(.topchart) #mk>#q-ins{order:1 !important}
}
@media(max-width:899px){ html body.mt-more #fkeys{flex-wrap:wrap !important;overflow:visible !important;row-gap:6px} }
html body #tick{overflow:hidden !important;max-width:100vw !important;contain:paint}
html body #nowl .r,html body #nowl .l{min-width:0;overflow-wrap:anywhere;word-break:break-word}
</style>
<script>/* patch 328: helpers the share header calls while it is built */
function gxAbs(px,chg,pcs){ try{ const d=px-px/(1+chg/100); return `${d>=0?"+":"−"}${Math.abs(d).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2})} (${String(pcs).replace(/^-/,"−")})`; }catch(e){ return pcs; } }
function gxCk(s){ try{ const u=new URLSearchParams(location.search); u.set("w",s); return `<a class="gxck" href="cockpit?${u.toString()}" target="_blank" rel="noopener" onclick="event.stopPropagation()">🎯 COCKPIT</a>`; }catch(e){ return ""; } }
try{ if(typeof paint==="function") setTimeout(()=>{ try{ paint(); }catch(e){} },50); }catch(e){}
</script>
ADD_H
cat > $W/edit328.py <<'PY_E'
import sys
h = sys.argv[1]; add = open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
E = [('<span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span>',
      '<span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${(typeof gxAbs==="function"&&px!=null&&chg!=null)?gxAbs(px,chg,pc(chg)):pc(chg)}</span>'),
     ('${chainTag()}<a class="am" style="margin-left:auto" onclick="unfocus()">✕ CLOSE</a></div>',
      '${chainTag()}${typeof gxCk==="function"?gxCk(f.s):""}<a class="am" style="margin-left:auto" onclick="unfocus()">✕ CLOSE</a></div>'),
     ('function tick(){ absHdr(); tools(); ck(); }', 'function tick(){ tools(); }   /* patch 328: the header carries the rupee change and the cockpit button itself */')]
for a, b in E:
    if t.count(a) != 1:
        print("❌ home.html: an anchor found %d times: %s" % (t.count(a), a[:60])); sys.exit(1)
    t = t.replace(a, b, 1)
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
t = t.replace("</body>", add + "\n</body>", 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: patch 328")
PY_E
echo "=== test (made-up data, nothing sent)"
python3 $W/p328test.py $W > $W/t.out 2>&1; RC=$?; tail -2 $W/t.out; [ $RC -eq 0 ] || { cat $W/t.out; echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/resultsrecent.py $D/resultsrecent.py && (cd $D && python3 -m py_compile resultsrecent.py) || back
if ! grep -q "patch 328" $D/home.html; then python3 $W/edit328.py $D/home.html $W/home328.html || back; fi
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
echo "=== JUST REPORTED, as the page server now serves it"
cd $D && python3 resultsrecent.py | head -8
echo "✅ patch 328 done - no blinking, the rupee change on every screen, COCKPIT in the header, the iPad tabs, result numbers in words. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
