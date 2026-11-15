#!/bin/bash
# PATCH 330 - ⛔ F&O BAN WATCH (Rama, 15 Nov: "KAYNES is banned from F&O - this has to be monitored, otherwise I will be penalised").
#   A share in NSE's ban list may only be CLOSED; a new position that adds open interest is fined. GIR read NSE's ban file (patch 188) but a
#   failed read quietly showed NO ban (it was empty in today's page check).
#   · banwatch.py (READ ONLY): NSE's own file with a browser's headers, every 10 min; the trade date read from the file; the last good copy kept
#     (data/ban.json); "could not be read" is said - never a quiet "none" · dashserve.py /banstate
#   · every page (GIR, a share's page, TODAY, COCKPIT, CHECKLIST - phone, iPad, laptop): a red bar "⛔ F&O BAN · Mon 16 Nov: KAYNES ... only
#     CLOSE existing positions - a new one is fined"; on a banned share's own page "⛔ KAYNES IS IN THE F&O BAN - do NOT open a new position";
#     amber when NSE's file cannot be read
#   · blocking: a banned share never shows ENTRY LIVE / ACT NOW (TODAY), its cockpit verdict is "⛔ F&O BAN - close only" (no plan), its
#     checklist row is marked, and its share-page DECISION is "⛔ F&O BAN" (no BUY CE / BUY PE)
#   Adds banwatch.py; edits dashserve.py, home.html, checklist.html; replaces today.html (only 323's) and cockpit.html (only 323's).
#   Tested: 6 + every page at 3 sizes. Restarts the dashboard. Prints NSE's ban list as GIR now reads it.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 330" $D/home.html && grep -q "patch 330" $D/dashserve.py && [ -f $D/banwatch.py ]; then echo "patch 330 - already in"; cd $D && python3 banwatch.py; exit 0; fi
grep -q "patch 329" $D/home.html || { echo "patch 329 first"; exit 1; }
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "patch 303" $D/checklist.html || { echo "dashserve's cockpit route / the checklist page not found - nothing done, send this to Claude"; exit 1; }
[ "$(sha256sum $D/today.html | cut -c1-64)" = "51c22b6e172550709e53be94e4a661538afa2502b030c373229d72f766a7b5f1" ] || { echo "today.html is not patch 323's copy - nothing done, send this to Claude"; exit 1; }
[ "$(sha256sum $D/cockpit.html | cut -c1-64)" = "957edbe1807e9f631d857e5d48c141780298986ade598744c8147c5214a1f0ff" ] || { echo "cockpit.html is not patch 323's copy - nothing done, send this to Claude"; exit 1; }
F="dashserve.py home.html checklist.html today.html cockpit.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/banwatch.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/banwatch.py <<'PY_BW'
"""banwatch.py - patch 330: READ ONLY. NSE's F&O BAN list, read so it can be trusted (Rama, 15 Nov: "KAYNES is banned from F&O - this has to be
monitored, otherwise I will be penalised"). A share in the ban (its open interest above 95% of the market-wide limit) may only be CLOSED; a new
position that adds open interest is fined by the exchange.
  · reads NSE's own file (fo_secban.csv) with a browser's headers, every 10 minutes; the trade date it is for is read from the file itself
  · keeps the last good copy (data/ban.json): if NSE does not answer, the page says "could not be read" - never a quiet "none"
  · adds the ban GIR's desk already knows
python3 banwatch.py     what GIR will show"""
import os, re, json, time, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(BASE, "data", "ban.json")
URL = "https://nsearchives.nseindia.com/content/fo/fo_secban.csv"
HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
       "Accept": "text/csv,text/plain,*/*", "Accept-Language": "en-IN,en;q=0.9", "Referer": "https://www.nseindia.com/"}
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}
MON = {m: i + 1 for i, m in enumerate(["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"])}


def parse(text):
    """-> (the trade date 'YYYY-MM-DD' or '', [symbols]) from NSE's file"""
    d = ""
    m = re.search(r"(\d{1,2})[-/ ]([A-Za-z]{3}|\d{1,2})[-/ ](\d{4})", text or "")
    if m:
        mo = MON.get(m.group(2).upper()) if m.group(2).isalpha() else int(m.group(2))
        try:
            d = str(dt.date(int(m.group(3)), mo, int(m.group(1))))
        except Exception:
            d = ""
    syms = sorted({x.group(1) for x in re.finditer(r"(?m)^\s*\d+\s*,\s*([A-Z][A-Z0-9&-]{1,19})\s*,?\s*$", text or "")})
    return d, syms


def _fetch():
    import requests
    s = requests.Session()
    try:
        s.get("https://www.nseindia.com/", headers=HDR, timeout=15)
    except Exception:
        pass
    r = s.get(URL, headers=HDR, timeout=20)
    if r.status_code != 200 or not r.text.strip():
        raise RuntimeError("NSE answered %s" % r.status_code)
    return r.text


def _desk():
    try:
        import dashserve
        return set(dashserve.desk_state().get("ban") or [])
    except Exception:
        return set()


def state(fetch=None, now=None):
    """-> {"ban": [...], "trade_date", "read_at", "ok", "err", "stale"} (cached 10 min)"""
    if fetch is None and now is None and _C["v"] is not None and time.time() - _C["t"] < 600:
        return _C["v"]
    now = now or dt.datetime.now(IST)
    v = {"ban": [], "trade_date": "", "read_at": "", "ok": False, "err": "", "src": "NSE fo_secban.csv"}
    try:
        txt = (fetch or _fetch)()
        d, syms = parse(txt)
        if not d and not syms and "ban" not in txt.lower():
            raise RuntimeError("the file did not look like NSE's ban list")
        v.update(ban=syms, trade_date=d, read_at=now.strftime("%Y-%m-%d %H:%M"), ok=True)
        try:
            os.makedirs(os.path.dirname(F), exist_ok=True)
            json.dump(v, open(F + ".tmp", "w")); os.replace(F + ".tmp", F)
        except Exception:
            pass
    except Exception as ex:
        v["err"] = str(ex)[:120]
        try:
            old = json.load(open(F))
            v.update(ban=old.get("ban") or [], trade_date=old.get("trade_date", ""), read_at=old.get("read_at", ""))
        except Exception:
            pass
    desk = _desk() if fetch is None else set()
    v["ban"] = sorted(set(v["ban"]) | desk)
    nxt = now.date()
    if now.strftime("%H:%M") >= "15:30" or now.weekday() > 4:
        nxt = nxt + dt.timedelta(days=1)
        while nxt.weekday() > 4:
            nxt = nxt + dt.timedelta(days=1)
    v["for"] = str(nxt)
    v["stale"] = bool(v["trade_date"]) and v["trade_date"] < str(now.date())
    if fetch is None:
        _C.update({"t": time.time(), "v": v})
    return v


if __name__ == "__main__":
    v = state()
    lst = ", ".join(v["ban"]) if v["ban"] else ("none" if v["ok"] else "NOT KNOWN - NSE's file could not be read")
    print("F&O BAN (NSE's file%s): %s" % (" for " + v["trade_date"] if v["trade_date"] else "", lst))
    print("  read: %s · %s%s" % (v["read_at"] or "never", "OK" if v["ok"] else "NOT READ NOW - " + v["err"], " · ⚠ the file is for an earlier day" if v["stale"] else ""))
PY_BW
cat > $W/p330test.py <<'PY_T'
#!/usr/bin/env python3
"""p330test.py - F&O BAN WATCH: NSE's ban file read and trusted (made-up file text, temp folder, nothing sent)"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(WK, "banwatch.py"), T); sys.path.insert(0, T)
import banwatch as B
B.F = os.path.join(T, "data", "ban.json"); IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
FILE = "Securities in Ban For Trade Date 16-NOV-2026:\n1,KAYNES\n2,SAMMAANCAP\n"
NOW = dt.datetime(2026, 11, 15, 20, 0, tzinfo=IST)
v = B.state(fetch=lambda: FILE, now=NOW)
chk("NSE's file read: KAYNES and SAMMAANCAP, for trade date 2026-11-16", v["ok"] and v["ban"] == ["KAYNES", "SAMMAANCAP"] and v["trade_date"] == "2026-11-16", v)
chk("on a Sunday evening the list is for Monday 16 Nov and not stale", v["for"] == "2026-11-16" and not v["stale"], v)
def boom(): raise RuntimeError("NSE answered 403")
v2 = B.state(fetch=boom, now=NOW)
chk("NSE does not answer: NOT read now (with why), the last good copy kept (KAYNES still shown)", not v2["ok"] and "403" in v2["err"] and "KAYNES" in v2["ban"], v2)
v3 = B.state(fetch=lambda: "Securities in Ban For Trade Date 17-NOV-2026:\nNIL\n", now=dt.datetime(2026, 11, 16, 20, 0, tzinfo=IST))
chk("an empty ban day (NIL) is a real 'none' - read OK, no shares", v3["ok"] and v3["ban"] == [] and v3["trade_date"] == "2026-11-17", v3)
v4 = B.state(fetch=lambda: FILE, now=dt.datetime(2026, 11, 17, 10, 0, tzinfo=IST))
chk("a file for an earlier day is flagged stale", v4["stale"], v4)
os.remove(B.F)
v5 = B.state(fetch=boom, now=NOW)
chk("never read and NSE down: not ok, no list - the page must warn, not say 'none'", not v5["ok"] and v5["ban"] == [] and v5["read_at"] == "", v5)
print("THE PATCH 330 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 330: ⛔ F&O BAN WATCH - one bar on every page (from banwatch.py / NSE's own ban file) */
#gxban{position:fixed;left:0;right:0;bottom:var(--gxbanb,0px);z-index:70;display:none;padding:8px 14px;font:700 13px/1.35 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;letter-spacing:.01em;box-shadow:0 -4px 14px rgba(0,0,0,.45)}
#gxban.red{display:block;background:#b71c1c;color:#fff}#gxban.amber{display:block;background:#7a5200;color:#fff}#gxban.big{font-size:15px;padding:12px 14px}
#gxban small{font-weight:500;opacity:.92;margin-left:6px}
body.gxban-on{padding-bottom:calc(var(--gxbanh,40px) + var(--gxbanb,0px)) !important}
.gxbanb{display:inline-block;margin-left:6px;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:#b71c1c;color:#fff;vertical-align:1px;white-space:nowrap}
</style>
<script>/* patch 330: ⛔ F&O BAN WATCH */
window.GXBAN=window.GXBAN||{set:new Set(),info:null};
function gxBanned(s){ try{ return !!s&&window.GXBAN.set.has(String(s).toUpperCase()); }catch(e){ return false; } }
(function(){ const Q=location.search; let bar=document.getElementById("gxban"); if(!bar){ bar=document.createElement("div"); bar.id="gxban"; document.body.appendChild(bar); }
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], DAY=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dl=d=>{ if(!d) return ""; const x=new Date(d+"T00:00:00Z"); return DAY[x.getUTCDay()]+" "+(+d.slice(8,10))+" "+MON[x.getUTCMonth()]; };
  function cur(){ try{ return ((typeof FOC!=="undefined"&&FOC)||new URLSearchParams(Q).get("w")||"").toUpperCase(); }catch(e){ return ""; } }
  function draw(){ const v=window.GXBAN.info; if(!v){ bar.className=""; document.body.classList.remove("gxban-on"); return; }
    const L=v.ban||[], me=cur(), mine=me&&L.includes(me);
    let cls="", h="";
    if(!v.ok&&!v.read_at){ cls="amber"; h=`⚠ NSE's F&amp;O ban list could not be read <small>${E(v.err||"")} - check nseindia.com before any F&amp;O trade</small>`; }
    else if(mine){ cls="red big"; h=`⛔ ${E(me)} IS IN THE F&amp;O BAN${v.trade_date?" ("+E(dl(v.trade_date))+")":""} - do NOT open a new position. Only close one you hold; a new position is fined by the exchange.`; }
    else if(L.length){ cls="red"; h=`⛔ F&amp;O BAN${v.trade_date?" · "+E(dl(v.trade_date)):""}: ${L.map(E).join(" · ")} <small>only CLOSE existing positions - a new one is fined${!v.ok?" · ⚠ last read "+E(v.read_at)+" (NSE not answering now)":""}${v.stale?" · ⚠ the file is for an earlier day":""}</small>`; }
    else if(!v.ok){ cls="amber"; h=`⚠ NSE's F&amp;O ban list not read now <small>last read ${E(v.read_at)} showed none - check nseindia.com before an F&amp;O trade</small>`; }
    bar.className=cls; bar.innerHTML=h; document.body.classList.toggle("gxban-on",!!cls);
    try{ const t=document.getElementById("tick"); const tb=t&&getComputedStyle(t).display!=="none"&&getComputedStyle(t).position==="fixed"?t.getBoundingClientRect().height:0; document.documentElement.style.setProperty("--gxbanb",tb+"px"); document.documentElement.style.setProperty("--gxbanh",(bar.offsetHeight||40)+"px"); }catch(e){} }
  async function pull(){ try{ const r=await fetch("banstate"+(Q||""),{cache:"no-store"}); if(r.ok){ const v=await r.json(); window.GXBAN.info=v; window.GXBAN.set=new Set((v.ban||[]).map(x=>String(x).toUpperCase())); draw();
        try{ if(typeof paint==="function") paint(); }catch(e){} try{ if(typeof paintBody==="function") paintBody(); }catch(e){} } }catch(e){} }
  window.gxBanDraw=draw; pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000); setInterval(draw,2000); })();
</script>
<script>/* patch 330: a share in the F&O ban - its DECISION says so (no BUY CE / BUY PE) */
(function(){ if(typeof ckDecision!=="function") return; const O=ckDecision;
  ckDecision=function(c){ try{ if(c&&gxBanned(c.s)) return `<div class="dec no"><b>DECISION: ⛔ F&amp;O BAN</b> <span>${String(c.s).replace(/[<>&]/g,"")} is in NSE's ban list - no new position (the exchange fines it); only close one you hold</span></div>`; }catch(e){} return O.apply(this,arguments); }; })();
</script>
ADD_H
cat > $W/checklist_add.html <<'ADD_C'
<style>/* patch 330: ⛔ F&O BAN WATCH - one bar on every page (from banwatch.py / NSE's own ban file) */
#gxban{position:fixed;left:0;right:0;bottom:var(--gxbanb,0px);z-index:70;display:none;padding:8px 14px;font:700 13px/1.35 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;letter-spacing:.01em;box-shadow:0 -4px 14px rgba(0,0,0,.45)}
#gxban.red{display:block;background:#b71c1c;color:#fff}#gxban.amber{display:block;background:#7a5200;color:#fff}#gxban.big{font-size:15px;padding:12px 14px}
#gxban small{font-weight:500;opacity:.92;margin-left:6px}
body.gxban-on{padding-bottom:calc(var(--gxbanh,40px) + var(--gxbanb,0px)) !important}
.gxbanb{display:inline-block;margin-left:6px;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:#b71c1c;color:#fff;vertical-align:1px;white-space:nowrap}
</style>
<script>/* patch 330: ⛔ F&O BAN WATCH */
window.GXBAN=window.GXBAN||{set:new Set(),info:null};
function gxBanned(s){ try{ return !!s&&window.GXBAN.set.has(String(s).toUpperCase()); }catch(e){ return false; } }
(function(){ const Q=location.search; let bar=document.getElementById("gxban"); if(!bar){ bar=document.createElement("div"); bar.id="gxban"; document.body.appendChild(bar); }
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], DAY=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dl=d=>{ if(!d) return ""; const x=new Date(d+"T00:00:00Z"); return DAY[x.getUTCDay()]+" "+(+d.slice(8,10))+" "+MON[x.getUTCMonth()]; };
  function cur(){ try{ return ((typeof FOC!=="undefined"&&FOC)||new URLSearchParams(Q).get("w")||"").toUpperCase(); }catch(e){ return ""; } }
  function draw(){ const v=window.GXBAN.info; if(!v){ bar.className=""; document.body.classList.remove("gxban-on"); return; }
    const L=v.ban||[], me=cur(), mine=me&&L.includes(me);
    let cls="", h="";
    if(!v.ok&&!v.read_at){ cls="amber"; h=`⚠ NSE's F&amp;O ban list could not be read <small>${E(v.err||"")} - check nseindia.com before any F&amp;O trade</small>`; }
    else if(mine){ cls="red big"; h=`⛔ ${E(me)} IS IN THE F&amp;O BAN${v.trade_date?" ("+E(dl(v.trade_date))+")":""} - do NOT open a new position. Only close one you hold; a new position is fined by the exchange.`; }
    else if(L.length){ cls="red"; h=`⛔ F&amp;O BAN${v.trade_date?" · "+E(dl(v.trade_date)):""}: ${L.map(E).join(" · ")} <small>only CLOSE existing positions - a new one is fined${!v.ok?" · ⚠ last read "+E(v.read_at)+" (NSE not answering now)":""}${v.stale?" · ⚠ the file is for an earlier day":""}</small>`; }
    else if(!v.ok){ cls="amber"; h=`⚠ NSE's F&amp;O ban list not read now <small>last read ${E(v.read_at)} showed none - check nseindia.com before an F&amp;O trade</small>`; }
    bar.className=cls; bar.innerHTML=h; document.body.classList.toggle("gxban-on",!!cls);
    try{ const t=document.getElementById("tick"); const tb=t&&getComputedStyle(t).display!=="none"&&getComputedStyle(t).position==="fixed"?t.getBoundingClientRect().height:0; document.documentElement.style.setProperty("--gxbanb",tb+"px"); document.documentElement.style.setProperty("--gxbanh",(bar.offsetHeight||40)+"px"); }catch(e){} }
  async function pull(){ try{ const r=await fetch("banstate"+(Q||""),{cache:"no-store"}); if(r.ok){ const v=await r.json(); window.GXBAN.info=v; window.GXBAN.set=new Set((v.ban||[]).map(x=>String(x).toUpperCase())); draw();
        try{ if(typeof paint==="function") paint(); }catch(e){} try{ if(typeof paintBody==="function") paintBody(); }catch(e){} } }catch(e){} }
  window.gxBanDraw=draw; pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000); setInterval(draw,2000); })();
</script>
<script>/* patch 330: the checklist - a share in the F&O ban is marked on its row and never "entry live" */
(function(){ if(typeof row!=="function") return; const O=row;
  row=function(x,i){ let h=O.apply(this,arguments); try{ if(x&&gxBanned(x.s)) h=h.replace('<div class="row">','<div class="row" style="border-color:#b71c1c;box-shadow:inset 3px 0 0 #b71c1c">').replace(/(<a class="name"[^>]*>[^<]*<\/a>)/,'$1<span class="gxbanb">⛔ F&amp;O BAN - close only, no new position</span>').replace(/<span class="stg s-live">[^<]*<\/span>/,'<span class="stg s-broke">⛔ BANNED</span>'); }catch(e){} return h; }; })();
</script>
ADD_C
cat > $W/today.html <<'HTML_TODAY'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Today</title>
<style>
:root{--bg:#06080c;--panel:#0c1118;--panel2:#111823;--line:#1c2532;--line2:#273244;--text:#e6edf3;--dim:#a3aebf;--mut:#8b97a9;
  --up:#26c281;--dn:#f0544f;--am:#f5a623;--blue:#4c9aff;--mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;--ui:-apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--text);font:13px/1.4 var(--ui)}
a{color:inherit;text-decoration:none}.num{font-family:var(--mono);font-variant-numeric:tabular-nums}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}.mut{color:var(--mut)}
/* top bar */
#bar{position:sticky;top:0;z-index:10;background:#080b10;border-bottom:1px solid var(--line)}
.r1{display:flex;align-items:center;gap:14px;padding:8px 14px;flex-wrap:wrap}
.brand{font:700 14px/1 var(--mono);letter-spacing:.12em;color:#1a1205;background:var(--am);padding:6px 10px;border-radius:4px}
.ttl{font:600 13px var(--ui);letter-spacing:.14em;color:var(--dim)}
.st{font:600 11px var(--mono);letter-spacing:.08em;padding:3px 8px;border-radius:3px;border:1px solid var(--line2);color:var(--dim)}
.st.live{color:var(--up);border-color:#1d5c42}.st.live::before{content:"● "}
.ix{display:flex;align-items:baseline;gap:6px;padding:0 10px;border-left:1px solid var(--line)}
.ix .n{font:600 11px var(--mono);color:var(--dim);letter-spacing:.06em}.ix .p{font:600 14px var(--mono)}
.chip{font:700 10.5px var(--mono);letter-spacing:.06em;padding:2px 6px;border-radius:3px;white-space:nowrap}
.c-RISING{background:#0d3324;color:var(--up)}.c-FALLING{background:#3a1416;color:var(--dn)}.c-SIDEWAYS{background:#3a2c10;color:var(--am)}
.nav{margin-left:auto;display:flex;gap:6px}.nav a{font:600 11px var(--mono);letter-spacing:.06em;padding:5px 9px;border:1px solid var(--line2);border-radius:4px;color:var(--dim)}
.nav a:hover{color:var(--text);border-color:var(--dim)}
.r2{display:flex;gap:18px;padding:6px 14px;border-top:1px solid var(--line);font:12px var(--mono);color:var(--dim);flex-wrap:wrap}
.r2 b{font-weight:700}.rules{margin-left:auto;color:var(--mut)}
/* layout */
main{display:grid;grid-template-columns:minmax(0,1.7fr) minmax(0,1fr);gap:12px;padding:12px 14px 30px;max-width:1500px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;min-width:0}
.hd{display:flex;align-items:center;gap:10px;padding:9px 12px;border-bottom:1px solid var(--line)}
.hd h2{margin:0;font:700 11.5px var(--mono);letter-spacing:.14em;white-space:nowrap}
#wlb{overflow-x:auto}.hd .sub{color:var(--mut);font-size:11.5px}
.hd .flt{margin-left:auto;display:flex;gap:4px}.flt a{font:600 10.5px var(--mono);letter-spacing:.06em;padding:3px 8px;border-radius:3px;color:var(--dim);cursor:pointer;border:1px solid transparent}
.flt a.on{color:var(--text);border-color:var(--line2);background:var(--panel2)}
/* patch 323: clarity - nothing under 11 px, comfortable taps */
.wf .g{flex-wrap:wrap;row-gap:4px}.wf .lb{font-size:11px !important}.wf a{font-size:11.5px !important;padding:6px 10px !important}.flt a{font-size:11px !important;padding:5px 9px !important}
th{font-size:11px !important}.sd,.sg,.chip{font-size:11px !important}.ix .n{font-size:11.5px !important}.st{font-size:11.5px !important}
/* act-now strip */
#act{grid-column:1/-1}#act .bd{display:flex;gap:8px;padding:10px 12px;overflow-x:auto}
.ac{flex:none;min-width:230px;border:1px solid #1d5c42;background:#0b1a14;border-radius:5px;padding:8px 10px}
.ac.pe{border-color:#5c1d1f;background:#1a0c0d}.ac .s{font:700 14px var(--mono)}.ac .l{font-size:12px;color:var(--dim);margin-top:2px}
.empty{padding:14px 12px;color:var(--mut);font-size:12.5px}
/* watchlist table */
table{width:100%;border-collapse:collapse}th{font:600 10.5px var(--mono);letter-spacing:.08em;color:var(--mut);text-align:left;padding:7px 8px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:middle;white-space:nowrap}tr:hover td{background:#0f1520}
td.r,th.r{text-align:right}td.c-lv,td.c-fu,td.c-en{white-space:normal;min-width:110px}td.c-lv .mut{display:block;font-size:11px}.sym{font:700 13px var(--mono)}.sym a:hover{text-decoration:underline}
.sd{font:700 10.5px var(--mono);padding:2px 6px;border-radius:3px}.sd.CE{background:#0d3324;color:var(--up)}.sd.PE{background:#3a1416;color:var(--dn)}
.sg{font:700 10.5px var(--mono);letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:var(--panel2);color:var(--dim)}
.sg.ban{background:#b71c1c;color:#fff}.sg.at{background:#3a2c10;color:var(--am)}.sg.live{background:#0d3324;color:var(--up)}.sg.target{background:#0d3324;color:var(--up)}.sg.out,.sg.broke{background:#3a1416;color:var(--dn)}
.wf{display:flex;gap:6px 14px;flex-wrap:wrap;align-items:center;padding:8px 12px;border-bottom:1px solid var(--line)}
.wf .g{display:flex;gap:3px;align-items:center}.wf .lb{font:600 10px var(--mono);letter-spacing:.08em;color:var(--mut);margin-right:3px}
.wf a{font:600 10.5px var(--mono);letter-spacing:.04em;padding:4px 8px;border-radius:3px;color:var(--dim);cursor:pointer;border:1px solid var(--line2);white-space:nowrap}
.wf a.on{color:#1a1205;background:var(--am);border-color:var(--am)}.wf a.pe.on{background:var(--dn);border-color:var(--dn);color:#fff}.wf a.ce.on{background:var(--up);border-color:var(--up);color:#04140c}
tr.grp td{font:600 10.5px var(--mono);letter-spacing:.1em;color:var(--mut);background:#0a0e14;padding:6px 10px}
/* feed */
.feed{max-height:calc(100vh - 170px);overflow-y:auto}.ev{display:grid;grid-template-columns:44px 22px minmax(0,1fr);gap:8px;padding:8px 12px;border-bottom:1px solid var(--line)}
.ev .t{font:12px var(--mono);color:var(--mut)}.ev .i{text-align:center}.ev .x{min-width:0;overflow-wrap:anywhere}.ev .x b{font-family:var(--mono)}
.ev .m{color:var(--dim);font-size:12px;margin-top:1px}.ev a.h:hover{text-decoration:underline}
.mkt{border-top:1px solid var(--line)}.mkt .hd{border-bottom:0;padding-bottom:4px}
@media(min-width:900px) and (max-width:1279px){main{grid-template-columns:1fr}.feed{max-height:none}}
/* phone */
@media(max-width:899px){
  .r1{gap:6px 8px;padding:7px 10px}.ix{padding:0;border-left:0;width:100%;flex-wrap:nowrap;white-space:nowrap;overflow:hidden}.ix .p{font-size:13px}.ix .mut{font-size:11px;overflow:hidden;text-overflow:ellipsis}
  #act .hd .sub{display:none}.nav{margin-left:0;width:100%}.nav a{flex:1;text-align:center}
  .r2{gap:10px;padding:5px 10px;font-size:11.5px}.rules{margin-left:0;width:100%}
  main{grid-template-columns:1fr;padding:8px 8px 30px;gap:8px}
  .wl table,.wl thead,.wl tbody,.wl tr,.wl td{display:block;width:100%}.wl thead{display:none}
  .wl tr{display:grid;grid-template-columns:auto auto 1fr auto;gap:4px 8px;padding:9px 10px;border-bottom:1px solid var(--line);align-items:center}
  .wl td{padding:0;border:0;white-space:normal}.wl td.c-px{grid-column:4;text-align:right}
  .wl td.c-lv,.wl td.c-vw,.wl td.c-fu,.wl td.c-en{grid-column:1/-1;font-size:12px;color:var(--dim)}
  .wl td[data-k]::before{content:attr(data-k) " ";color:var(--mut);font:600 10px var(--mono);letter-spacing:.06em}
  .wl tr.grp{display:block}.wl td.nil{display:none}
  .wf{padding:8px 10px;gap:6px 10px}.wf a{padding:5px 8px}.feed{max-height:none}
}
</style></head><body>
<div id="bar"><div class="r1"><a class="brand" href="./" id="home">GIR</a><span class="ttl">TODAY</span><span class="st" id="mst">—</span>
  <span class="ix" id="ixn"></span><span class="ix" id="ixb"></span>
  <span class="nav"><a id="lck" href="checklist">CHECKLIST</a><a id="lco" href="cockpit">COCKPIT</a><a id="lho" href="./">GIR</a></span></div>
  <div class="r2" id="cnt"></div></div>
<main>
  <section class="card" id="act"><div class="hd"><h2>ACT NOW</h2><span class="sub">entries live on your checklist - confirm on the cockpit, then trade</span></div><div class="bd" id="actb"></div></section>
  <section class="card wl"><div class="hd"><h2>WATCHLIST</h2><span class="sub" id="wls">tonight's checklist, live every 3 s</span></div><div class="wf" id="wf"></div><div id="wlb"></div></section>
  <section class="card"><div class="hd"><h2>FEED</h2><span class="flt" id="flt"></span></div><div class="feed" id="feed"></div>
    <div class="mkt"><div class="hd"><h2>MARKET HEADLINES</h2><span class="sub">latest 5</span></div><div id="mkt"></div></div></section>
</main>
<script>
/* patch 314 + 317 + 320 + 323 + 330: ◉ TODAY - one screen for the trading day: the checklist live (patch 303), the cockpit's NIFTY / 👀 / 🧱 (patch 285-299),
   GIR's alerts and news for your checklist shares only, market headlines apart. Reads only - nothing here changes GIR. */
const Q=location.search, K=new URLSearchParams(Q).get("k")||"";
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const f2=v=>v==null||isNaN(v)?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
const pc=v=>v==null||isNaN(v)?"—":(v>0?"+":"")+Number(v).toFixed(2)+"%";
const cl=v=>v>0?"up":v<0?"dn":"dim";
function hmOf(v){ if(v==null||v==="") return ""; if(typeof v==="number"){ const d=new Date((v>2e10?v:v*1000)+19800000); return d.toISOString().slice(11,16); }
  const m=String(v).match(/(\d{1,2}):(\d{2})/); return m?m[1].padStart(2,"0")+":"+m[2]:""; }
function shareURL(s){ const u=new URLSearchParams(Q); u.set("w",s); return "./?"+u.toString(); }
["lck","lco","lho","home"].forEach(id=>{ const a=document.getElementById(id); a.href=a.getAttribute("href")+Q; });
let CL=null, LV=null, CK=null, HM=null, FLT="all", WS={side:"all",stage:"all",sort:"near"};
try{ FLT=localStorage.getItem("gir_today_f")||"all"; WS=Object.assign(WS,JSON.parse(localStorage.getItem("gir_today_w")||"{}")); }catch(e){}
function setW(k,v){ WS[k]=v; try{ localStorage.setItem("gir_today_w",JSON.stringify(WS)); }catch(e){} wl(); }
const STG={wait:"WAITING",at:"AT LEVEL",live:"ENTRY LIVE",target:"TARGET",out:"STOPPED",broke:"INVALID",closed:"CLOSED",ban:"⛔ F&O BAN"};
const DONE=new Set(["target","out","broke","closed"]);
function items(){ const seen=new Set(), A=[]; if(!CL) return A;
  ["pe","ce","retest","breakout","breakdown"].forEach(k=>(CL[k]||[]).forEach(x=>{ const key=x.s+"|"+x.side; if(!seen.has(key)){ seen.add(key); A.push(x); } })); return A; }
function lvOn(){ return !!(LV&&LV.live&&CL&&LV.day>CL.day); }
function L_(x){ const l=lvOn()?LV.live[x.s+"|"+x.side]||null:null; if(typeof gxBanned==="function"&&gxBanned(x.s)) return Object.assign({},l||{},{state:"ban"}); return l; }   /* patch 330: a banned share never shows an entry */
function lvl(x){ const pe=x.side==="PE"; return x.kind==="breakdown"?x.floor:(x.kind==="breakout"||pe)?x.roof:x.floor; }
function mstat(){ const d=new Date(Date.now()+19800000), hm=d.toISOString().slice(11,16), wd=d.getUTCDay();
  const open=wd>0&&wd<6&&hm>="09:15"&&hm<"15:30"; const el=document.getElementById("mst");
  el.textContent=open?"MARKET OPEN "+hm:wd>0&&wd<6&&hm<"09:15"?"PRE-MARKET "+hm:"MARKET CLOSED"; el.className="st"+(open?" live":""); }
function bar(){ mstat();
  const ix=(id,n,x)=>{ const el=document.getElementById(id); if(!x){ el.innerHTML=`<span class="n">${n}</span><span class="mut">from 09:15</span>`; return; }
    el.innerHTML=`<span class="n">${n}</span><span class="p num">${f2(x.px)}</span><span class="chip c-${esc(x.state)}">${x.state==="RISING"?"▲":x.state==="FALLING"?"▼":"↔"} ${esc(x.state)}</span><span class="mut num">${x.since?"since "+esc(String(x.since).slice(0,5)):""}${x.p15!=null?" · 15m "+pc(x.p15):""}</span>`; };
  ix("ixn","NIFTY",CK&&CK.nifty); ix("ixb","BANKNIFTY",CK&&CK.bank);
  const A=items().map(L_).filter(Boolean), n=s=>A.filter(l=>l.state===s).length, dn=A.filter(l=>DONE.has(l.state));
  const res=dn.filter(l=>l.res!=null), w=res.filter(l=>l.res>0).length;
  document.getElementById("cnt").innerHTML=!CL?'<span>checklist not made yet - GIR makes it every market evening at 19:15</span>':
    `<span><b class="up">${n("live")}</b> ENTRY LIVE</span><span><b class="am">${n("at")}</b> AT LEVEL</span><span><b>${lvOn()?n("wait"):items().length}</b> WAITING</span><span><b>${dn.length}</b> DONE${res.length?` · ${w}/${res.length} positive`:""}</span>
     <span class="mut">${lvOn()?"live "+esc(LV.hm||""):"live stages from 09:20"} · list of ${esc(CL.day||"")}</span><span class="rules">after 09:30 · half size · stop after 2 losses · out by 15:15</span>`; }
function act(){ const A=items().filter(x=>{ const l=L_(x); return l&&l.state==="live"; }); const el=document.getElementById("actb");
  el.innerHTML=A.length?A.map(x=>{ const l=L_(x), w=lvl(x), pe=x.side==="PE", tg=l.entry_px*(1+(pe?-0.02:0.02));
    return `<a class="ac ${pe?"pe":""}" href="${shareURL(x.s)}" target="_blank"><div><span class="s">${esc(x.s)}</span> <span class="sd ${x.side}">${pe?"▼ PE":"▲ CE"}</span> <span class="num ${cl(l.move)}">${pc(l.move)}</span></div>
      <div class="l num">in ${esc(l.entry_t)} @ ${f2(l.entry_px)} · LTP ${f2(l.px)}</div><div class="l num">target ${f2(tg)} · stop: close ${pe?"above":"below"} ${w?f2(w.k):"—"}</div></a>`; }).join("")
   :`<div class="empty">${lvOn()?"No live entry right now. The watchlist shows who is at the level.":"Nothing live yet - entries appear here from 09:20 on a market day."}</div>`; }
function wl(){ const el=document.getElementById("wlb"); if(!CL){ el.innerHTML='<div class="empty">The checklist is made every market evening at 19:15.</div>'; return; }
  const pri={live:0,at:1,wait:2}; const RAW=items().map(x=>({x,l:L_(x)})), GRP={};
  RAW.forEach(o=>{ (GRP[o.x.s]=GRP[o.x.s]||[]).push(o); });           /* patch 323: one row per share - both plans when it is on both sides */
  const rk=o=>{ const s_=o.l?o.l.state:"wait"; return s_==="live"?0:s_==="at"?1:s_==="wait"?2:3; };
  const ALL=Object.values(GRP).map(g=>{ if(g.length===1) return g[0]; const a=g.slice().sort((p,q)=>rk(p)-rk(q)); return Object.assign({},a[0],{both:g}); });
  const hasS=(o,sd)=>o.both?o.both.some(b=>b.x.side===sd):o.x.side===sd;
  const dist=o=>{ const w=lvl(o.x); return o.l&&w?Math.abs(o.l.px/w.k-1)*100:w?w.dist:99; };
  const st_=o=>o.l?o.l.state:"wait", cnt=f=>ALL.filter(f).length;
  const A=ALL.filter(o=>(WS.side==="all"||hasS(o,WS.side))&&(WS.stage==="all"||st_(o)===WS.stage||(WS.stage==="done"&&DONE.has(st_(o)))));
  const by=WS.sort==="score"?(a,b)=>(b.x.score||0)-(a.x.score||0):WS.sort==="az"?(a,b)=>a.x.s.localeCompare(b.x.s):(a,b)=>dist(a)-dist(b);
  const open=A.filter(o=>!o.l||!DONE.has(o.l.state)).sort(by).sort((a,b)=>(pri[st_(a)]??2)-(pri[st_(b)]??2)), done=A.filter(o=>o.l&&DONE.has(o.l.state));
  const G=(k,L)=>L.map(([v,t,c])=>`<a class="${c||""}${WS[k]===v?" on":""}" onclick="setW('${k}','${v}')">${t}</a>`).join("");
  document.getElementById("wf").innerHTML=`<span class="g"><span class="lb">SIDE</span>${G("side",[["all","ALL "+ALL.length],["PE","▼ PE "+cnt(o=>hasS(o,"PE")),"pe"],["CE","▲ CE "+cnt(o=>hasS(o,"CE")),"ce"]])}</span>`+
    `<span class="g"><span class="lb">STAGE</span>${G("stage",[["all","ALL"],["live","LIVE "+cnt(o=>st_(o)==="live")],["at","AT LEVEL "+cnt(o=>st_(o)==="at")],["wait","WAITING "+cnt(o=>st_(o)==="wait")],["done","DONE "+cnt(o=>DONE.has(st_(o)))]])}</span>`+
    `<span class="g"><span class="lb">SORT</span>${G("sort",[["near","CLOSEST"],["score","SCORE"],["az","A-Z"]])}</span>`;
  const row=(o)=>{ const x=o.x, l=o.l, w=lvl(x), pe=x.side==="PE", st=l?l.state:"wait";
    const dist=l&&w?Math.abs(l.px/w.k-1)*100:w?w.dist:null;
    const vw=l&&l.vside!=null?`<span class="${(l.vside>0)===!pe?"up":"dn"}">${l.vside>0?"above":"below"} ${f2(l.vwap)}</span>`:'<span class="mut">—</span>';
    const fu=l&&l.kind_now?`<span class="${(l.kind_now==="SHORT BUILD-UP"||l.kind_now==="LONG UNWINDING")===pe?"up":"dn"}">${esc(l.kind_now.toLowerCase())}</span> <span class="mut num">${pc(l.doi)}</span>`:'<span class="mut">—</span>';
    const en=l&&l.entry_t?`<span class="num">${esc(l.entry_t)} @ ${f2(l.entry_px)}</span>${l.res!=null?` → <b class="num ${cl(l.res)}">${pc(l.res)}</b>`:l.move!=null?` · <span class="num ${cl(l.move)}">${pc(l.move)}</span>`:""}`:l&&l.note&&DONE.has(st)?`<span class="mut">${esc(l.note)}</span>`:'<span class="mut">—</span>';
    return `<tr><td class="sym"><a href="${shareURL(x.s)}" target="_blank">${esc(x.s)}</a></td><td>${o.both?`<span class="sd PE">PE</span> <span class="sd CE">CE</span>`:`<span class="sd ${x.side}">${x.side}</span>`}</td><td><span class="sg ${st}">${STG[st]||esc(st)}</span></td>
      <td class="r num c-px">${l?f2(l.px):f2(x.px)} <span class="${cl(l?l.chg:x.chg)}">${pc(l?l.chg:x.chg)}</span></td>
      <td class="num c-lv" data-k="LEVEL">${w?`${x.kind==="breakout"||(!x.kind&&pe)?"R":"S"} ${f2(w.k)} <span class="mut">${dist!=null?dist.toFixed(2)+"% away":""}</span>${o.both?`<span class="mut" style="display:block;font-size:11px">PE if it fails here · CE if it breaks through</span>`:""}`:'<span class="mut">no wall within 15%</span>'}</td>
      <td class="num c-vw${l&&l.vside!=null?"":" nil"}" data-k="VWAP">${vw}</td><td class="c-fu${l&&l.kind_now?"":" nil"}" data-k="FUT">${fu}</td><td class="c-en${en.includes("—")&&!(l&&(l.entry_t||l.note))?" nil":""}" data-k="ENTRY">${en}</td></tr>`; };
  el.innerHTML=`<table><thead><tr><th>SYMBOL</th><th>SIDE</th><th>STAGE</th><th class="r">LTP</th><th>LEVEL</th><th>VWAP</th><th>FUTURES</th><th>ENTRY / RESULT</th></tr></thead><tbody>
    ${open.length||done.length?"":`<tr><td colspan="8" class="empty">nothing with these filters</td></tr>`}${open.map(row).join("")}${done.length?`<tr class="grp"><td colspan="8">CLOSED TODAY · ${done.length}</td></tr>`+done.map(row).join(""):""}</tbody></table>`;
  document.getElementById("wls").textContent=`${A.length} of ${ALL.length} shares · live every 3 s`; }
function events(){ const set=new Set(items().map(x=>x.s)), E=[];
  if(lvOn()) items().forEach(x=>{ const k=x.s+"|"+x.side, l=LV.live[k], st=(LV.st||{})[k]||{}; if(!l) return; const pe=x.side==="PE", w=lvl(x);
    if(st.near_t) E.push({t:hmOf(st.near_t),i:"👀",k:"sig",s:x.s,c:"am",h:`at ${pe?"resistance":"support"} ${w?f2(w.k):""}`,m:`${x.side} setup - watch for the turn ${pe?"below":"above"} VWAP`});
    if(l.entry_t) E.push({t:l.entry_t,i:"✅",k:"sig",s:x.s,c:"up",h:`${x.side} entry live @ ${f2(l.entry_px)}`,m:l.note||""});
    if(l.done_t) E.push({t:l.done_t,i:l.state==="target"?"✔":l.state==="closed"?"⏹":"✖",k:"sig",s:x.s,c:l.state==="target"?"up":l.state==="closed"?"dim":"dn",h:`${STG[l.state]||l.state}${l.res!=null?" "+pc(l.res):""}`,m:l.note||""}); });
  ((CK&&CK.wm)||[]).forEach(x=>{ if(!x||!x.s) return; const watch=/watch/i.test(x.note||""); E.push({t:hmOf(x.t),i:watch?"👀":"🧱",k:"sig",s:x.s,c:x.dir>0?"up":"dn",
    h:`${x.dir>0?"CE":"PE"} · ${watch?"at the wall":"futures + wall"}${set.has(x.s)?"":" · not on your checklist"}`,m:[x.px!=null?"₹"+f2(x.px):"",x.doi!=null?"fut OI "+pc(x.doi):"",x.note&&!watch?x.note:""].filter(Boolean).join(" · ")}); });
  ((HM&&HM.now)||[]).forEach(r=>{ if(!r||!set.has(r.s)) return; E.push({t:hmOf(r.t),i:"🔔",k:"sig",s:r.s,c:r.side==="CE"?"up":r.side==="PE"?"dn":"dim",h:String(r.head||"").slice(0,140),m:""}); });
  ((HM&&HM.news)||[]).forEach(x=>{ if(!x||!set.has(x.s)||!x.side) return;   /* patch 320: only news with a direction (a neutral headline is usually not about the share) */ E.push({t:hmOf(x.hm||x.t),i:"📰",k:"news",s:x.s,c:x.side>0?"up":x.side<0?"dn":"dim",h:x.h||"",u:x.u||x.url||"",m:x.why||""}); });
  const seen=new Set(); return E.filter(e=>{ const k=e.t+e.s+e.h; if(seen.has(k)) return false; seen.add(k); return true; }).sort((a,b)=>String(b.t).localeCompare(String(a.t))); }
function feed(){ const E=events(), F=[["all","ALL"],["sig","SIGNALS"],["news","NEWS"]];
  document.getElementById("flt").innerHTML=F.map(f=>`<a class="${FLT===f[0]?"on":""}" onclick="setF('${f[0]}')">${f[1]} ${f[0]==="all"?E.length:E.filter(e=>e.k===f[0]).length}</a>`).join("");
  const L=E.filter(e=>FLT==="all"||e.k===FLT).slice(0,80);
  document.getElementById("feed").innerHTML=L.length?L.map(e=>`<div class="ev"><span class="t">${esc(e.t||"")}</span><span class="i">${e.i}</span><div class="x"><a href="${shareURL(e.s)}" target="_blank"><b class="${e.c}">${esc(e.s)}</b></a> ${e.u?`<a class="h" href="${esc(e.u)}" target="_blank" rel="noopener noreferrer">${esc(e.h)} ↗</a>`:esc(e.h)}${e.m?`<div class="m">${esc(e.m)}</div>`:""}</div></div>`).join("")
    :'<div class="empty">Nothing yet. Signals and news for your checklist shares appear here, newest first.</div>';
  const M=((HM&&HM.news)||[]).filter(x=>x&&(x.s==="MARKET"||!x.s)).slice(0,5);
  document.getElementById("mkt").innerHTML=M.length?M.map(x=>`<div class="ev"><span class="t">${esc(hmOf(x.hm||x.t))}</span><span class="i">🏛</span><div class="x">${x.u?`<a class="h" href="${esc(x.u)}" target="_blank" rel="noopener noreferrer">${esc(x.h)} ↗</a>`:esc(x.h||"")}${x.why?`<div class="m">${esc(x.why)}</div>`:""}</div></div>`).join(""):'<div class="empty">No market headlines yet.</div>'; }
function setF(f){ FLT=f; try{ localStorage.setItem("gir_today_f",f); }catch(e){} feed(); }
function paint(){ try{ bar(); act(); wl(); feed(); }catch(e){ console.error(e); } }
async function get(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pLive(){ const j=await get("checklistlive"+Q); if(j) LV=j; paint(); }
async function pList(){ const j=await get("checklistdata"+Q); if(j&&j.day) CL=j; paint(); }
async function pCk(){ const j=await get("cockpitdata"+Q); if(j) CK=j; }
async function pHome(){ const j=await get("home"+(K?"?k="+encodeURIComponent(K):"")); if(j) HM=j; }
pList(); pCk(); pHome().then(paint); pLive();
setInterval(()=>{ if(!document.hidden) pLive(); },3000); setInterval(()=>{ if(!document.hidden) pCk(); },5000);
setInterval(()=>{ if(!document.hidden) pHome(); },10000); setInterval(()=>{ if(!document.hidden) pList(); },300000); setInterval(mstat,30000);
</script><style>/* patch 330: ⛔ F&O BAN WATCH - one bar on every page (from banwatch.py / NSE's own ban file) */
#gxban{position:fixed;left:0;right:0;bottom:var(--gxbanb,0px);z-index:70;display:none;padding:8px 14px;font:700 13px/1.35 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;letter-spacing:.01em;box-shadow:0 -4px 14px rgba(0,0,0,.45)}
#gxban.red{display:block;background:#b71c1c;color:#fff}#gxban.amber{display:block;background:#7a5200;color:#fff}#gxban.big{font-size:15px;padding:12px 14px}
#gxban small{font-weight:500;opacity:.92;margin-left:6px}
body.gxban-on{padding-bottom:calc(var(--gxbanh,40px) + var(--gxbanb,0px)) !important}
.gxbanb{display:inline-block;margin-left:6px;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:#b71c1c;color:#fff;vertical-align:1px;white-space:nowrap}
</style>
<script>/* patch 330: ⛔ F&O BAN WATCH */
window.GXBAN=window.GXBAN||{set:new Set(),info:null};
function gxBanned(s){ try{ return !!s&&window.GXBAN.set.has(String(s).toUpperCase()); }catch(e){ return false; } }
(function(){ const Q=location.search; let bar=document.getElementById("gxban"); if(!bar){ bar=document.createElement("div"); bar.id="gxban"; document.body.appendChild(bar); }
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], DAY=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dl=d=>{ if(!d) return ""; const x=new Date(d+"T00:00:00Z"); return DAY[x.getUTCDay()]+" "+(+d.slice(8,10))+" "+MON[x.getUTCMonth()]; };
  function cur(){ try{ return ((typeof FOC!=="undefined"&&FOC)||new URLSearchParams(Q).get("w")||"").toUpperCase(); }catch(e){ return ""; } }
  function draw(){ const v=window.GXBAN.info; if(!v){ bar.className=""; document.body.classList.remove("gxban-on"); return; }
    const L=v.ban||[], me=cur(), mine=me&&L.includes(me);
    let cls="", h="";
    if(!v.ok&&!v.read_at){ cls="amber"; h=`⚠ NSE's F&amp;O ban list could not be read <small>${E(v.err||"")} - check nseindia.com before any F&amp;O trade</small>`; }
    else if(mine){ cls="red big"; h=`⛔ ${E(me)} IS IN THE F&amp;O BAN${v.trade_date?" ("+E(dl(v.trade_date))+")":""} - do NOT open a new position. Only close one you hold; a new position is fined by the exchange.`; }
    else if(L.length){ cls="red"; h=`⛔ F&amp;O BAN${v.trade_date?" · "+E(dl(v.trade_date)):""}: ${L.map(E).join(" · ")} <small>only CLOSE existing positions - a new one is fined${!v.ok?" · ⚠ last read "+E(v.read_at)+" (NSE not answering now)":""}${v.stale?" · ⚠ the file is for an earlier day":""}</small>`; }
    else if(!v.ok){ cls="amber"; h=`⚠ NSE's F&amp;O ban list not read now <small>last read ${E(v.read_at)} showed none - check nseindia.com before an F&amp;O trade</small>`; }
    bar.className=cls; bar.innerHTML=h; document.body.classList.toggle("gxban-on",!!cls);
    try{ const t=document.getElementById("tick"); const tb=t&&getComputedStyle(t).display!=="none"&&getComputedStyle(t).position==="fixed"?t.getBoundingClientRect().height:0; document.documentElement.style.setProperty("--gxbanb",tb+"px"); document.documentElement.style.setProperty("--gxbanh",(bar.offsetHeight||40)+"px"); }catch(e){} }
  async function pull(){ try{ const r=await fetch("banstate"+(Q||""),{cache:"no-store"}); if(r.ok){ const v=await r.json(); window.GXBAN.info=v; window.GXBAN.set=new Set((v.ban||[]).map(x=>String(x).toUpperCase())); draw();
        try{ if(typeof paint==="function") paint(); }catch(e){} try{ if(typeof paintBody==="function") paintBody(); }catch(e){} } }catch(e){} }
  window.gxBanDraw=draw; pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000); setInterval(draw,2000); })();
</script>
</body></html>
HTML_TODAY
cat > $W/cockpit.html <<'HTML_CK'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Cockpit</title>
<style>
:root{--bg:#06080c;--panel:#0c1118;--panel2:#111823;--line:#1c2532;--line2:#273244;--text:#e6edf3;--dim:#a3aebf;--mut:#8b97a9;
  --up:#26c281;--dn:#f0544f;--am:#f5a623;--mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;--ui:-apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--text);font:13px/1.45 var(--ui)}
a{color:inherit;text-decoration:none}.nm{font-family:var(--mono);font-variant-numeric:tabular-nums}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}.mu{color:var(--mut)}
#bar{position:sticky;top:0;z-index:10;background:#080b10;border-bottom:1px solid var(--line)}
.r1{display:flex;align-items:center;gap:12px;padding:8px 14px;flex-wrap:wrap}
.brand{font:700 14px/1 var(--mono);letter-spacing:.12em;color:#1a1205;background:var(--am);padding:6px 10px;border-radius:4px}
.ttl{font:600 13px var(--ui);letter-spacing:.14em;color:var(--dim)}
.st{font:600 11px var(--mono);letter-spacing:.06em;padding:3px 8px;border-radius:3px;border:1px solid var(--line2);color:var(--dim)}.st.live{color:var(--up);border-color:#1d5c42}.st.old{color:var(--am);border-color:#5c4410}
.ix{display:flex;align-items:baseline;gap:6px;padding:0 10px;border-left:1px solid var(--line);white-space:nowrap}
.ix .n{font:600 11px var(--mono);color:var(--dim);letter-spacing:.06em}.ix .p{font:600 14px var(--mono)}
.chip{font:700 10.5px var(--mono);letter-spacing:.06em;padding:2px 6px;border-radius:3px;white-space:nowrap}
.c-RISING{background:#0d3324;color:var(--up)}.c-FALLING{background:#3a1416;color:var(--dn)}.c-SIDEWAYS{background:#3a2c10;color:var(--am)}
.nav{margin-left:auto;display:flex;gap:6px}.nav a{font:600 11px var(--mono);letter-spacing:.06em;padding:5px 9px;border:1px solid var(--line2);border-radius:4px;color:var(--dim)}
.r2{display:flex;gap:6px 14px;padding:6px 14px;border-top:1px solid var(--line);font:12px var(--mono);color:var(--dim);flex-wrap:wrap;align-items:center}
.secs{display:flex;gap:4px;flex-wrap:wrap}.sc{font:11px var(--mono);padding:2px 6px;border-radius:3px;background:var(--panel2)}
.rules{margin-left:auto;color:var(--mut)}
main{padding:12px 14px 30px;max-width:1600px}
.sig{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-bottom:12px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;min-width:0}
.hd{display:flex;align-items:center;gap:8px;padding:8px 12px;border-bottom:1px solid var(--line)}.hd h2{margin:0;font:700 11px var(--mono);letter-spacing:.12em;white-space:nowrap}.hd .sub{color:var(--mut);font-size:11.5px}
.li{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:8px;padding:6px 12px;border-bottom:1px solid #121923;align-items:baseline}.li:last-child{border-bottom:0}
.li .s{font:700 12.5px var(--mono)}.li .m{color:var(--dim);font-size:12px;overflow-wrap:anywhere}.li .t{font:11.5px var(--mono);color:var(--mut)}
.sd{font:700 10px var(--mono);padding:2px 5px;border-radius:3px}.sd.CE{background:#0d3324;color:var(--up)}.sd.PE{background:#3a1416;color:var(--dn)}
.empty{padding:12px;color:var(--mut);font-size:12.5px}
.boxes{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:10px;margin-bottom:12px}
.bx{display:block;background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:0}.bx:hover{border-color:var(--line2)}
.bx .top{display:flex;align-items:flex-start;gap:10px;padding:10px 12px;border-bottom:1px solid var(--line)}
.bx .nmx{font:700 16px var(--mono)}.bx .px{font:600 13px var(--mono)}.bx .src{font:600 10px var(--mono);letter-spacing:.06em;color:var(--mut);margin-top:3px}
.vd{margin-left:auto;text-align:center;padding:6px 10px;border-radius:5px;font:800 12px var(--mono);letter-spacing:.04em;background:#1b222d;color:var(--dim);white-space:nowrap}
.vd small{display:block;font:600 10px var(--mono);opacity:.85;margin-top:2px}.vd.TRADE{background:#0d3324;color:var(--up)}.vd.SMALL{background:#3a2c10;color:var(--am)}.vd.SKIP{background:#3a1416;color:var(--dn)}
.ck{display:grid;grid-template-columns:16px 82px minmax(0,1fr);gap:4px 8px;padding:8px 12px;font-size:12.5px;align-items:baseline}
.ck i{font-style:normal;text-align:center;font-weight:700}.ck .k{font:600 10px var(--mono);letter-spacing:.08em;color:var(--mut)}
.pbk{margin:0 12px 8px;padding:7px 9px;border-radius:5px;background:#101722;border-left:3px solid var(--line2);font-size:12px}.pbk.hit{border-color:var(--up);background:#0d1f17}.pbk.bad{border-color:var(--dn);background:#1f0f10}
.tst{padding:0 12px 8px;font-size:12px}
.plan{margin:0 12px 12px;padding:8px 10px;border-radius:5px;background:#0d1f17;border:1px solid #1d5c42;font:600 12px var(--mono)}.plan.SMALL{background:#1f1a0d;border-color:#5c4410}
.act{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:12px}
.foot{display:flex;flex-wrap:wrap;gap:8px 18px;padding:10px 12px;font-size:12.5px}
details{padding:8px 12px}summary{cursor:pointer;font:600 11px var(--mono);letter-spacing:.08em;color:var(--dim)}ol{margin:8px 0;padding-left:22px}ol li{margin:4px 0}
@media(max-width:1100px){.sig{grid-template-columns:1fr}.act{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:899px){
  .r1{gap:6px 8px;padding:7px 10px}.ix{padding:0;border-left:0;width:100%;overflow:hidden}.ix .mu{overflow:hidden;text-overflow:ellipsis;min-width:0}.nav{margin-left:0;width:100%}.nav a{flex:1;text-align:center}
  .r2{padding:6px 10px}.rules{margin-left:0;width:100%}main{padding:8px}
  .boxes{grid-template-columns:1fr}.act{grid-template-columns:1fr}.ck{grid-template-columns:16px 70px minmax(0,1fr)}
}
</style></head><body>
<div id="bar"><div class="r1"><a class="brand" id="lb" href="./">GIR</a><span class="ttl">COCKPIT</span><span class="st" id="st">—</span>
  <span class="ix" id="ixn"></span><span class="ix" id="ixb"></span>
  <span class="nav"><a id="l1" href="today">TODAY</a><a id="l2" href="checklist">CHECKLIST</a><a id="l3" href="./">GIR</a></span></div>
  <div class="r2" id="r2"></div></div>
<main>
  <div class="sig">
    <section class="card"><div class="hd"><h2>🧱 PRIORITY</h2><span class="sub">futures + option wall + VWAP agree</span></div><div id="pri"></div></section>
    <section class="card"><div class="hd"><h2>📚 PLAYBOOK</h2><span class="sub">shares in a tested setup now</span></div><div id="pbk"></div></section>
    <section class="card"><div class="hd"><h2>📏 PUSH FOR SIZE</h2><span class="sub">new futures money vs a normal day</span></div><div id="psh"></div></section>
  </div>
  <div class="boxes" id="boxes"></div>
  <div class="act">
    <section class="card"><div class="hd"><h2>🧲 STEADY MOVES</h2></div><div id="a1"></div></section>
    <section class="card"><div class="hd"><h2>🌪 BIG MOVERS</h2></div><div id="a2"></div></section>
    <section class="card"><div class="hd"><h2>🚀 MOMENTUM ±3%</h2></div><div id="a3"></div></section>
    <section class="card"><div class="hd"><h2>⏳ MONEY LOADING</h2><span class="sub">futures in, price flat</span></div><div id="a4"></div></section>
  </div>
  <section class="card" id="ft"></section>
</main>
<script>
/* patch 321 + 323 + 330: 🎯 THE COCKPIT redesigned (323: text colours raised to a 5.4:1+ contrast) - a trader's layout (laptop and phone): the top bar (NIFTY / BANKNIFTY now), 3 signal panels, a card per
   share with a verdict badge and a scorecard, the day's activity. The same data as before (windwatch.py's cockpit.json), nothing dropped. */
const Q=location.search;
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const f2=v=>v==null||isNaN(v)?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
const pc=v=>v==null||isNaN(v)?"":(v>0?"+":"")+Number(v).toFixed(2)+"%";
const cl=v=>v>0?"up":v<0?"dn":"dim";
function shareURL(s){ const u=new URLSearchParams(Q); u.set("w",s); return "./?"+u.toString(); }
const sl=s=>`<a href="${shareURL(s)}" target="_blank">${esc(s)}</a>`;
const side=d=>`<span class="sd ${d>0?"CE":"PE"}">${d>0?"▲ CE":"▼ PE"}</span>`;
[["lb","./"],["l1","today"],["l2","checklist"],["l3","./"]].forEach(([id,h])=>{ const a=document.getElementById(id); a.href=h+Q; });
const WQ=(new URLSearchParams(Q).get("w")||"").toUpperCase();
function askNow(){ if(WQ) fetch("cockpitask"+Q,{cache:"no-store"}).catch(()=>{}); }
function ix(id,n,x){ const el=document.getElementById(id);
  if(!x){ el.innerHTML=`<span class="n">${n}</span><span class="mu">from 09:15</span>`; return; }
  el.innerHTML=`<span class="n">${n}</span><span class="p nm">${f2(x.px)}</span><span class="chip c-${esc(x.state)}">${x.state==="RISING"?"▲":x.state==="FALLING"?"▼":"↔"} ${esc(x.state)}</span>
    <span class="mu nm">since ${esc((x.since||"").slice(0,5))}${x.above_open==null?"":x.above_open?" · above open":" · below open"}${x.p15!=null?" · 15m "+pc(x.p15):""}</span>`; }
function li(d,s,m,t){ return `<div class="li">${d==null?"<span></span>":side(d)}<div><span class="s">${sl(s)}</span> <span class="m">${m||""}</span></div><span class="t">${esc(t||"")}</span></div>`; }
const EMPTY=t=>`<div class="empty">${t}</div>`;
function ckRow(c,k){ if(!c) return ""; const t=c[2]||""; const warn=/SOLO|no help|mixed|no clear|close ⚠/.test(t);
  return `<i class="${c[1]?"up":warn?"am":"dn"}">${c[1]?"✓":warn?"!":"✕"}</i><span class="k">${k}</span><span>${esc(t)}</span>`; }
function walls(w){ if(!w) return '<span class="mu">no option data yet</span>';
  const r=(w.R||[]).slice(0,2).map((x,i)=>`<span class="dn">R${i+1} ${f2(x.k)}</span> <span class="mu">${x.pct}%${x.ch!=null?" · "+(x.ch>0?"+":"")+x.ch+"% today":""}</span>`).join(" · ");
  const s=(w.S||[]).slice(0,2).map((x,i)=>`<span class="up">S${i+1} ${f2(x.k)}</span> <span class="mu">${x.pct}%${x.ch!=null?" · "+(x.ch>0?"+":"")+x.ch+"% today":""}</span>`).join(" · ");
  return (r||'<span class="mu">R —</span>')+"<br>"+(s||'<span class="mu">S —</span>'); }
function pb(p,b){ if(!p) return `<div class="pbk"><span class="mu">Playbook: waiting for prices</span></div>`;
  if(p.bad) return `<div class="pbk bad"><b class="dn">Playbook ✕</b> ${esc(p.bad)}</div>`;
  if(p.rank) return `<div class="pbk hit"><b class="up">Playbook #${p.rank} of 10</b> · ${esc(p.name)}<div class="mu">${esc(p.tested)}${p.hits&&p.hits.length>1?" · also #"+p.hits.slice(1).join(", #"):""}</div></div>`;
  const bs=p.best; return `<div class="pbk"><b>Playbook: no tested setup</b> <span class="mu">for ${esc(b.s)} ${b.side} now</span>${p.near?`<div class="am">${esc(p.near)}</div>`:""}${bs?`<div class="mu">best now: <span class="${bs.dir>0?"up":"dn"}">${esc(bs.s)} ${bs.side} #${bs.rank}</span> ${esc(bs.short)} · since ${esc(bs.since)}</div>`:""}</div>`; }
function box(b){ const C={}; (b.checks||[]).forEach(c=>C[c[0]]=c);
  const src=b.how==="your view"?"👁 YOUR VIEW":b.how==="asked from its page"?"🔎 ASKED FROM ITS PAGE":"GIR SIGNAL (🧱 / 🧲 / 🚀 / 🌪)";
  const vt={TRADE:"TRADE "+b.side,SMALL:"SMALL / WAIT",SKIP:"SKIP"}[b.verdict]||esc(b.verdict||"—");
  const iv=b.iv&&b.iv.word?` · IV ${b.iv.iv}% ${b.iv.word==="EXPENSIVE"?'<span class="am">expensive</span>':esc(b.iv.word.toLowerCase())}`:"";
  const move=b.brk==null?'<span class="mu">5-min range from 09:20</span>':b.brk?`<span class="up">broke 5-min ${b.dir>0?"high "+f2(b.f5[0]):"low "+f2(b.f5[1])}</span>`:`<span class="dn">inside 5-min ${b.dir>0?"high "+f2(b.f5&&b.f5[0]):"low "+f2(b.f5&&b.f5[1])}</span>`;
  const book=b.book==null?'<span class="mu">not known yet</span>':`<span class="${b.book_ok?"up":"dim"}">${b.book>=1?"buyers "+b.book.toFixed(1)+"× sellers":"sellers "+(1/b.book).toFixed(1)+"× buyers"}</span>`;
  return `<a class="bx" href="${shareURL(b.s)}" target="_blank"><div class="top"><div><div><span class="nmx">${esc(b.s)}</span> ${side(b.dir)} <span class="px nm">₹${f2(b.px)}</span> <span class="nm ${cl(b.chg)}">${pc(b.chg)}</span></div>
      <div class="src">${src}${b.index?` · ${esc(b.index)} ${pc(b.index_chg)}`:""}</div></div><div class="vd ${esc(b.verdict||"")}">${vt}<small>score ${b.score??"—"} / 5</small></div></div>
    <div class="ck">${ckRow(C.market,"MARKET")}${ckRow(C.bank,"BANK")}${ckRow(C.sector,"SECTOR")}${ckRow(C.futures,"FUTURES")}${ckRow(C.vwap,"VWAP")}
      <i class="mu">•</i><span class="k">ORDER BOOK</span><span>${book}</span>${ckRow(C.walls,"WALLS")}<i class="mu">•</i><span class="k">LEVELS</span><span class="nm" style="font-size:11.5px">${walls(b.walls)}</span>
      <i class="mu">•</i><span class="k">MOVE</span><span>${move}${b.vr!=null?` · volume ${b.vr}× normal`:""}${iv}</span>
      ${b.steady?`<i class="up">✓</i><span class="k">STEADY</span><span class="up">${b.steady.mv}% from open · OI +${b.steady.doi}% · ${b.dir>0?"above":"below"} VWAP ${b.steady.vmin} min</span>`:""}</div>
    ${pb(b.play,b)}
    ${(b.good&&b.good.length)||(b.warn&&b.warn.length)?`<div class="tst"><span class="mu" style="font:600 10px var(--mono);letter-spacing:.08em">TESTED 30 DAYS</span>${(b.good||[]).map(x=>`<div class="up">${esc(x)}</div>`).join("")}${(b.warn||[]).map(x=>`<div class="${String(x).startsWith("❌")?"dn":"am"}">${esc(x)}</div>`).join("")}</div>`:""}
    ${b.verdict!=="SKIP"?`<div class="plan ${esc(b.verdict||"")}">${b.strike?f2(b.strike)+" "+b.side+" ATM · ":""}SL: share ${b.dir>0?"below":"above"} ₹${f2(b.stop)} · book half ₹${f2(b.half)}${b.target?` · target ${b.dir>0?"R1":"S1"} ${f2(b.target)}`:""} · out by 15:15</div>`:""}
  </a>`; }
const BOX0=box; box=function(b){ let h=BOX0(b); try{ if(b&&gxBanned(b.s)){ h=h.replace(/<div class="vd [^"]*">[\s\S]*?<\/small><\/div>/,'<div class="vd SKIP">⛔ F&amp;O BAN<small>close only</small></div>').replace(/<div class="plan[^"]*">[\s\S]*?<\/div>/,'<div class="plan SKIP" style="background:#2a0e0e;border-color:#b71c1c">In NSE\'s F&amp;O ban - no new position (the exchange fines it); only close one you hold.</div>'); } }catch(e){} return h; };   /* patch 330 */
function lst(id,L,f,empty){ document.getElementById(id).innerHTML=(L&&L.length)?L.slice().reverse().slice(0,12).map(f).join(""):EMPTY(empty||"none yet"); }
function paint(d){ d=d||{};
  const age=Math.max(0,Math.round(Date.now()/1000-(d.t||0))), st=document.getElementById("st");
  if(!d.t){ st.textContent="NO DATA YET · FROM 09:15"; st.className="st"; } else if(age>60){ st.textContent="UPDATED "+(age<3600?Math.round(age/60)+" MIN":Math.round(age/3600)+" H")+" AGO"; st.className="st old"; } else { st.textContent="● LIVE "+(d.hm||""); st.className="st live"; }
  ix("ixn","NIFTY",d.nifty); ix("ixb","BANKNIFTY",d.bank);
  document.getElementById("r2").innerHTML=`<span>${d.mk?`<b class="nm">${d.mk[0]}</b> of ${d.mk[2]} shares rising`:"breadth from 09:15"}</span><span class="secs">${(d.sectors||[]).slice(0,12).map(x=>`<span class="sc ${cl(x[1])}">${esc(String(x[0]).replace("NIFTY ",""))} ${pc(x[1])}</span>`).join("")}</span><span class="rules">out by 15:15 · stop after 2 losses · trade the side NIFTY is going</span>`;
  document.getElementById("pri").innerHTML=(d.wm||[]).length?(d.wm||[]).slice().reverse().slice(0,8).map(x=>li(x.dir,x.s,`fut OI ${x.doi>0?"+":""}${x.doi}% · ${x.dir>0?"floor":"roof"} ${x.wall?x.wall[0]:"—"}${x.wall?` (${x.wall[3]}% away, +${Math.round(x.wall[2]||0)}% today)`:""}${x.note&&x.note!=="card sent"?" · "+esc(x.note):""}`,x.t)).join(""):EMPTY("None yet today. Rings in GIR Bigmovers when futures, the option wall and VWAP agree (09:30-14:30).");
  document.getElementById("pbk").innerHTML=(d.pb||[]).length?(d.pb||[]).slice(0,8).map(x=>li(x.dir,x.s,`#${x.rank} · ${esc(x.short)}`,x.since)).join(""):EMPTY("No share in a tested setup right now. Steady falls usually come 09:30-11:00, CE setups before 10:00.");
  document.getElementById("psh").innerHTML=(d.push_top||[]).length?(d.push_top||[]).slice(0,8).map(x=>li(x.dir,x.s,`<b class="nm">${Number(x.x).toFixed(Math.abs(x.x)>=0.1?2:3)}×</b> a normal day · ₹${Math.round(x.cr||0).toLocaleString("en-IN")} cr`,"")).join(""):EMPTY("Waiting for the futures money (from 09:15).");
  let BX=(d.boxes||[]).slice(); if(WQ){ const a=(d.ask||{})[WQ]; BX=BX.filter(b=>b.s!==WQ); BX.unshift(a||null); }
  document.getElementById("boxes").innerHTML=BX.length?BX.map(b=>b?box(b):`<div class="bx"><div class="top"><span class="nmx">${esc(WQ)}</span></div><div class="empty">Working out ${esc(WQ)}'s checks - a few seconds on a market day (from 09:15).</div></div>`).join("")
    :`<div class="card">${EMPTY("No shares on watch yet - add one with ➕ watch on the CHECKLIST page; GIR adds its own 🚀 / 🌪 movers as they come.")}</div>`;
  lst("a1",d.steady,x=>li(x.dir,x.s,`${x.mv}% · OI +${x.doi}%${x.note?" · "+esc(x.note):""}`,x.t));
  lst("a2",d.big,x=>li(x.dir,x.s,"",(x.t||"").slice(0,5)));
  lst("a3",d.mom,x=>li(x.dir,x.s,`<span class="nm ${cl(x.chg)}">${pc(x.chg)}</span>`,(x.t||"").slice(0,5)));
  lst("a4",d.load,x=>li(x.side>0?1:x.side<0?-1:null,x.s,x.side?"":'<span class="am">direction not clear</span>',""));
  const PA=d.pb_all||[], AV=d.pb_avoid||[];
  document.getElementById("ft").innerHTML=`<div class="foot"><span>🛡 <b>POSITIONS</b> ${d.pos&&d.pos.open&&d.pos.open.length?esc(d.pos.open.join(", ")):'<span class="mu">none open</span>'}</span><span>today <b class="nm">${d.pos?d.pos.losses:0}</b> losses <span class="mu">(stop after 2)</span></span></div>
    ${PA.length?`<details><summary>📚 THE FULL PLAYBOOK · 10 TESTED SETUPS (30 DAYS, NSE DATA)</summary><ol>${PA.map(x=>`<li><span class="${x[1]==="CE"?"up":"dn"}">${esc(x[2])}</span> <span class="mu">· ${esc(x[3])}</span><br><span class="dim">${esc(x[4]||"")}</span></li>`).join("")}</ol>${AV.length?`<div class="dn">Avoid: ${AV.map(esc).join(" · ")}</div>`:""}</details>`:""}`; }
async function pull(){ try{ const r=await fetch("cockpitdata"+Q,{cache:"no-store"}); if(r.ok) paint(await r.json()); }catch(e){} }
pull(); setInterval(()=>{ if(!document.hidden) pull(); },3000);
askNow(); setInterval(()=>{ if(!document.hidden) askNow(); },30000);
</script><style>/* patch 330: ⛔ F&O BAN WATCH - one bar on every page (from banwatch.py / NSE's own ban file) */
#gxban{position:fixed;left:0;right:0;bottom:var(--gxbanb,0px);z-index:70;display:none;padding:8px 14px;font:700 13px/1.35 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;letter-spacing:.01em;box-shadow:0 -4px 14px rgba(0,0,0,.45)}
#gxban.red{display:block;background:#b71c1c;color:#fff}#gxban.amber{display:block;background:#7a5200;color:#fff}#gxban.big{font-size:15px;padding:12px 14px}
#gxban small{font-weight:500;opacity:.92;margin-left:6px}
body.gxban-on{padding-bottom:calc(var(--gxbanh,40px) + var(--gxbanb,0px)) !important}
.gxbanb{display:inline-block;margin-left:6px;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:2px 7px;border-radius:3px;background:#b71c1c;color:#fff;vertical-align:1px;white-space:nowrap}
</style>
<script>/* patch 330: ⛔ F&O BAN WATCH */
window.GXBAN=window.GXBAN||{set:new Set(),info:null};
function gxBanned(s){ try{ return !!s&&window.GXBAN.set.has(String(s).toUpperCase()); }catch(e){ return false; } }
(function(){ const Q=location.search; let bar=document.getElementById("gxban"); if(!bar){ bar=document.createElement("div"); bar.id="gxban"; document.body.appendChild(bar); }
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], DAY=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dl=d=>{ if(!d) return ""; const x=new Date(d+"T00:00:00Z"); return DAY[x.getUTCDay()]+" "+(+d.slice(8,10))+" "+MON[x.getUTCMonth()]; };
  function cur(){ try{ return ((typeof FOC!=="undefined"&&FOC)||new URLSearchParams(Q).get("w")||"").toUpperCase(); }catch(e){ return ""; } }
  function draw(){ const v=window.GXBAN.info; if(!v){ bar.className=""; document.body.classList.remove("gxban-on"); return; }
    const L=v.ban||[], me=cur(), mine=me&&L.includes(me);
    let cls="", h="";
    if(!v.ok&&!v.read_at){ cls="amber"; h=`⚠ NSE's F&amp;O ban list could not be read <small>${E(v.err||"")} - check nseindia.com before any F&amp;O trade</small>`; }
    else if(mine){ cls="red big"; h=`⛔ ${E(me)} IS IN THE F&amp;O BAN${v.trade_date?" ("+E(dl(v.trade_date))+")":""} - do NOT open a new position. Only close one you hold; a new position is fined by the exchange.`; }
    else if(L.length){ cls="red"; h=`⛔ F&amp;O BAN${v.trade_date?" · "+E(dl(v.trade_date)):""}: ${L.map(E).join(" · ")} <small>only CLOSE existing positions - a new one is fined${!v.ok?" · ⚠ last read "+E(v.read_at)+" (NSE not answering now)":""}${v.stale?" · ⚠ the file is for an earlier day":""}</small>`; }
    else if(!v.ok){ cls="amber"; h=`⚠ NSE's F&amp;O ban list not read now <small>last read ${E(v.read_at)} showed none - check nseindia.com before an F&amp;O trade</small>`; }
    bar.className=cls; bar.innerHTML=h; document.body.classList.toggle("gxban-on",!!cls);
    try{ const t=document.getElementById("tick"); const tb=t&&getComputedStyle(t).display!=="none"&&getComputedStyle(t).position==="fixed"?t.getBoundingClientRect().height:0; document.documentElement.style.setProperty("--gxbanb",tb+"px"); document.documentElement.style.setProperty("--gxbanh",(bar.offsetHeight||40)+"px"); }catch(e){} }
  async function pull(){ try{ const r=await fetch("banstate"+(Q||""),{cache:"no-store"}); if(r.ok){ const v=await r.json(); window.GXBAN.info=v; window.GXBAN.set=new Set((v.ban||[]).map(x=>String(x).toUpperCase())); draw();
        try{ if(typeof paint==="function") paint(); }catch(e){} try{ if(typeof paintBody==="function") paintBody(); }catch(e){} } }catch(e){} }
  window.gxBanDraw=draw; pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000); setInterval(draw,2000); })();
</script>
</body></html>
HTML_CK
echo "=== test (made-up NSE file, nothing sent)"
python3 $W/p330test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/banwatch.py $D/banwatch.py && cp $W/today.html $D/today.html && cp $W/cockpit.html $D/cockpit.html || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 330" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/banstate":                 # patch 330: NSE's F&O ban list, as GIR read it (read only)
                try:
                    import banwatch
                    v_ = banwatch.state()
                except Exception as ex_:
                    v_ = {"ban": [], "ok": False, "err": str(ex_)[:120], "read_at": ""}
                return self.send(200, json.dumps(v_, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /banstate")
for f, a in (("home.html", "home_add.html"), ("checklist.html", "checklist_add.html")):
    h = os.path.join(D, f); t = open(h, encoding="utf-8").read()
    if "patch 330" in t:
        continue
    if t.count("</body>") != 1:
        print("❌ %s: </body> x%d - send this to Claude" % (f, t.count("</body>"))); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, a), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  %s: the ban bar" % f)
PY_EDIT
cd $D && python3 -m py_compile dashserve.py banwatch.py || back
if command -v node >/dev/null 2>&1; then
  for f in home.html checklist.html today.html cockpit.html; do
    python3 - $D/$f $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
    node --check $W/page.js 2>$W/js.err || { echo "❌ $f:"; head -5 $W/js.err; back; }
  done
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== NSE's F&O ban list, as GIR now reads it"
cd $D && timeout 60 python3 banwatch.py
echo "✅ patch 330 done - the F&O BAN on every page (red bar, banned shares blocked). Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/banwatch.py; systemctl restart gir-dash"
