#!/bin/bash
# PATCH 132b - WHAT THE SCREEN SHOWED ON THE MUHURAT EVENING (on top of patch 132).
#   - NIFTY · F&O BREADTH: on a late-starting day the chart starts at the first candle (14:20 ... 15:30), not a sliver at the right
#   - NSE INDEX column: "—" after 15:15 every day (the final screen left the sector indices out) - kept now
#   - top bar: "60 moving" was the number of alert lines -> "60 alerts" (+ the day when not today) · "upd 3s" -> "data 3s ago"
#   - F&O DESK: FII / DII read "FII +13,750 cr · DII -5,969 cr (06-Nov-2026 · cash market)"
#   - girlook.py (new): every panel's data read on the server - what it shows, what looks wrong
#   engine2.py, home.html (exact anchors). Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g132b; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p132b.sh now"; exit 1; fi
[ -f $D/bhavfull.py ] || { echo "patch 132 is not installed yet - paste patch 132 first"; exit 1; }
[ -f $D/girlook.py ] && { echo "patch 132b is already installed"; exit 1; }
F="engine2.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/girlook.py $D/p132btest.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p132b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p132b_patch.py - PATCH 132b: what Rama saw on the screen on the Muhurat evening.
  - NIFTY · F&O BREADTH: on a day that starts late the candles sat in a sliver at the right (09:15-14:15 empty) -> the chart
    starts at the first candle, the times and the breadth bars follow
  - the NSE INDEX column was "—" after 15:15 every day: the engine's after-hours / final screen left the sector indices out
  - the top bar's "60 moving" was the number of alert lines (not shares moving) -> "60 alerts" (+ the day when not today);
    "upd 3s" -> "data 3s ago"
  - F&O DESK FII / DII: "DII -5,969 · DATE 06-Nov-2026 · FII +13,750" -> "FII +13,750 cr · DII -5,969 cr (06-Nov-2026 ...)"
Usage: python3 p132b_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''            st["ticks_s"] = feed.ticks_per_s()
            dash.write(st)
        except Exception as ex:
            log("after-hours dashboard state failed:", ex)''', '''            st["ticks_s"] = feed.ticks_per_s()
            st["sidx"] = SIDX                                   # patch 132b: the NSE sector indices stay on the screen after 15:15
            dash.write(st)
        except Exception as ex:
            log("after-hours dashboard state failed:", ex)'''),
        ('''            st["oi_tape"] = feed.opt_tape_list()
        dash.write(st)
    except Exception as ex:
        log("final dashboard state failed:", ex)''', '''            st["oi_tape"] = feed.opt_tape_list()
        st["sidx"] = SIDX                                       # patch 132b: + the day's NSE sector indices on the final picture
        dash.write(st)
    except Exception as ex:
        log("final dashboard state failed:", ex)'''),
    ],
    "home.html": [
        ('''if(!c.some(x=>x!=null)) return null; return {o,h,l,c,pc:NCH&&NCH.pc,N,one}; }''',
         '''if(!c.some(x=>x!=null)) return null;
  const f0=c.findIndex(x=>x!=null);                   /* patch 132b: a day that starts late (Muhurat) - the chart starts at its first candle */
  if(f0*step>30){ const s_=a=>a.slice(f0); return {o:s_(o),h:s_(h),l:s_(l),c:s_(c),pc:NCH&&NCH.pc,N:N-f0,one,off:f0,step}; }
  return {o,h,l,c,pc:NCH&&NCH.pc,N,one,off:0,step}; }
function nifLabels(off5){ const a=555+off5*5, b=930; return [0,1,2,3,4,5].map(k=>{ const m=Math.round((a+(b-a)*k/5)/5)*5; return String(Math.floor(m/60)).padStart(2,"0")+":"+String(m%60).padStart(2,"0"); }); }'''),
        ('''const NB_=nifBars(); if(!NB_) NSC=null;''',
         '''const NB_=nifBars(); if(!NB_) NSC=null; const OFF5=NB_&&NB_.off?Math.round(NB_.off*NB_.step/5):0; if(OFF5) B.splice(0,Math.min(B.length,OFF5));'''),
        ('''const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-1, 1));''',
         '''const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-OFF5-1, 1));'''),
        ('''g+=["09:15","10:30","11:45","13:00","14:15","15:30"].map(''',
         '''g+=(OFF5?nifLabels(OFF5):["09:15","10:30","11:45","13:00","14:15","15:30"]).map('''),
        ('''<span>${(d.now||[]).length} moving</span><span id="ago"></span>''',
         '''<span title="alert lines of ${esc(d.day||"the day")} on the NOW list (each one went to Telegram) - not the number of shares moving">${(d.now||[]).length} alerts${d.day&&d.day!==new Date(Date.now()+19800000).toISOString().slice(0,10)?" ("+esc(String(d.day).slice(5))+")":""}</span><span id="ago" title="seconds since this page last got new data from the server"></span>'''),
        ('''a.textContent=`upd ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s`;''',
         '''a.textContent=`data ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s ago`;'''),
        ('''    const fd=M.fiidii; const fdt=fd==null?"not read":typeof fd==="object"?Object.entries(fd).slice(0,4).map(([k,v])=>`${esc(k).toUpperCase()} <b class="${(+v||0)>=0?"pu":"pd"}">${typeof v==="number"?(v>0?"+":"")+inr(Math.round(v)):esc(String(v))}</b>`).join(" · "):esc(String(fd));''',
         '''    const fd=M.fiidii; const fdt=fd==null?"not read":typeof fd==="object"?(()=>{ const g_=k=>{ const e=Object.entries(fd).find(([a])=>a.toUpperCase()===k); return e?e[1]:null; };   /* patch 132b: FII first, the date apart */
      const one=k=>{ const v=g_(k); return v==null?"":`${k} <b class="${(+v||0)>=0?"pu":"pd"}">${typeof v==="number"?(v>0?"+":"")+inr(Math.round(v))+" cr":esc(String(v))}</b>`; }; const dd=g_("DATE");
      return [one("FII"),one("DII")].filter(Boolean).join(" · ")+` <span class="dim">${dd?esc(String(dd))+" · ":""}cash market, ₹ crore · + bought, − sold</span>`; })():esc(String(fd));'''),
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
cat > $W/girlook.py <<'PY_LOOK'
#!/usr/bin/env python3
"""girlook.py - patch 132b: GIR LOOKED AT, PANEL BY PANEL, FROM THE SERVER. Reads every data feed the GIR page draws from
(the same answers your browser gets) and says, per panel, what it shows and what looks wrong - empty, old, from the
wrong day. Read-only: nothing is changed, nothing is sent. The page token is read from dash_token.txt, never printed.

  python3 girlook.py              the report
  python3 girlook.py DIVISLAB     + that share's screens (chart, OI, checklist, events)"""
import os, sys, json, time, subprocess, urllib.request, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
URL = "http://127.0.0.1:8090/"
BAD = []


def get(path):
    tok = open(os.path.join(BASE, "dash_token.txt")).read().strip()
    sep = "&" if "?" in path else "?"
    try:
        return json.load(urllib.request.urlopen(URL + path + sep + "k=" + tok, timeout=30))
    except Exception as ex:
        return {"_err": str(ex)[:100]}


def say(ok, panel, text):
    if not ok:
        BAD.append(panel)
    print("  %s %-24s %s" % ("OK   " if ok else "CHECK", panel, text))


def nn(a):
    return [i for i, v in enumerate(a or []) if v is not None]


def slot(i, step=5):
    m = 9 * 60 + 15 + i * step
    return "%02d:%02d" % (m // 60, m % 60)


def main():
    now = dt.datetime.now(IST)
    today = str(now.date())
    try:
        import sessions
        ses = sessions.session(now.date())
    except Exception:
        ses = None
    print("GIR LOOK · %s IST · today: %s" % (now.strftime("%a %d %b %H:%M"), ("%s %s-%s" % (ses["name"], ses["open"], ses["close"])) if ses else "no session (closed)"))
    print("\n1. services")
    for u in ("gir-intraday", "gir-dash", "gir-desk", "gir-exchange", "gir-newsroom"):
        try:
            r = subprocess.run(["systemctl", "is-active", u], capture_output=True, text=True, timeout=10).stdout.strip()
        except Exception:
            r = "?"
        say(r == "active", u, r)

    print("\n2. the top bar and the alerts (/home)")
    D = get("home")
    if D.get("_err"):
        say(False, "page server", "no answer: %s" % D["_err"]); return
    day = D.get("day") or "?"
    say(True, "engine's day", "%s%s" % (day, "" if day == today else " (the last session - today has not started / no session today)"))
    rows = D.get("now") or []
    say(True, "NOW list", "%d alert lines of %s (the top bar's 'N moving' = this count) · newest %s · oldest %s" % (
        len(rows), day, rows[0].get("t") if rows else "-", rows[-1].get("t") if rows else "-"))
    late = [r for r in rows if str(r.get("t") or "") > "15:30"]
    if late:
        say(True, "after-close alerts", "%d (news after 15:30, e.g. %s %s)" % (len(late), late[0].get("t"), late[0].get("s")))
    idx = D.get("idx") or {}
    say(bool(idx.get("NIFTY")), "NIFTY / VIX strip", " · ".join("%s %s %s%%" % (k, (v or {}).get("last"), (v or {}).get("chg")) for k, v in idx.items()) or "empty")
    say(True, "ban", ", ".join(D.get("ban") or []) or "none")

    print("\n3. MARKET screen (/market)")
    M = get("market")
    if M.get("_err"):
        say(False, "market", M["_err"])
    else:
        secs = M.get("sectors") or []
        say(len(secs) >= 10, "SECTORS donut", "%d sectors, %d with a %% today" % (len(secs), sum(1 for x in secs if x.get("chg") is not None)))
        ser = [len(x.get("series") or []) for x in secs]
        say(bool(ser) and max(ser) > 0, "SECTORS THROUGH DAY", "%s columns (one per 30 min)" % (max(ser) if ser else 0))
        sidx = M.get("sidx") or {}
        say(len(sidx) >= 10, "NSE INDEX column", "%d NSE sector indices%s" % (len(sidx), "" if sidx else " - the column shows — (fixed in 132b: kept after 15:30)"))
        n1 = M.get("n1") or {}
        f1 = nn(n1.get("c"))
        say(bool(f1), "NIFTY 1-min", ("%d bars, %s-%s, day %s" % (len(f1), slot(f1[0], 1), slot(f1[-1], 1), n1.get("day"))) if f1 else "no 1-min bars")
        adv = M.get("adv") or []
        say(len(adv) > 1, "F&O BREADTH bars", "%d (one per 5 min)" % len(adv))
        say((M.get("fo_up") or 0) + (M.get("fo_dn") or 0) > 100, "F&O up / down", "%s up · %s down" % (M.get("fo_up"), M.get("fo_dn")))
        C = M.get("chain") or {}
        say(bool(C.get("exp")), "DESK expiry", "%s · %s days left" % (C.get("exp"), C.get("days")))
        say(C.get("pcr_now") is not None, "DESK PCR", "%s (%d readings today)" % (C.get("pcr_now"), len(C.get("pcr") or [])))
        say(M.get("fiidii") is not None, "DESK FII / DII", json.dumps(M.get("fiidii"), ensure_ascii=False)[:120])
        say(True, "DESK results", ", ".join("%s %s" % (r.get("s"), r.get("d")) for r in (C.get("results") or [])[:8]) or "none in 7 days")
        bu = M.get("bu_cnt") or {}
        say(True, "OI BUILD-UP BY SECTOR", "%d sectors with a futures build-up" % len(bu))
        mon = M.get("money") or {}
        say(bool(mon), "F&O MONEY", " · ".join("%s %d" % (k, len(v or [])) for k, v in mon.items()) or "empty")
    ch = get("chart?sym=NIFTY50")
    f = nn(ch.get("c"))
    say(bool(f), "NIFTY 5-min chart", ("%d candles %s-%s · prev close %s%s" % (len(f), slot(f[0]), slot(f[-1]), ch.get("pc"),
                                                                             " · starts late: the chart now begins at the first candle (132b)" if f and f[0] > 6 else "")) if f else "no candles (the page falls back to the last session's)")

    print("\n4. ⚡ EARLY · 📊 NEWS REACTION · function keys")
    E = get("early")
    er = E.get("rows") or []
    say(not E.get("_err"), "⚡ EARLY", "%s · %d shares · %d BUY" % (E.get("day") or ("today" if E.get("today") else "?"), len(er), sum(1 for r in er if r.get("verdict") == "BUY")))
    R = get("react")
    say(not R.get("_err"), "📊 NEWS REACTION", "%d lines" % len(R.get("rows") or R.get("items") or []) if isinstance(R, dict) else "?")
    P = get("panels")
    if not P.get("_err"):
        for k, v in P.items():
            if isinstance(v, (list, dict)):
                n = len(v.get("rows") or v) if isinstance(v, dict) else len(v)
                say(True, "key: %s" % k[:18], "%d items" % n)

    sym = (sys.argv[1] if len(sys.argv) > 1 else "").upper()
    if not sym:
        top = sorted((r for r in rows if r.get("s")), key=lambda r: r.get("t") or "", reverse=True)
        sym = top[0]["s"] if top else "RELIANCE"
    print("\n5. one share's screens: %s" % sym)
    c5 = get("chart?sym=" + sym)
    f = nn(c5.get("c"))
    say(bool(f), "CHART 5-min", ("%d candles %s-%s" % (len(f), slot(f[0]), slot(f[-1]))) if f else "none")
    h = get("hist?sym=%s&days=30" % sym)
    say(bool(h.get("t") or h.get("c") or h.get("bars")), "PRO chart (30 days)", "%d bars" % len(h.get("t") or h.get("c") or h.get("bars") or []))
    o = get("oi?sym=" + sym)
    rows_ = o.get("rows") or {}
    pv = o.get("prev") or {}
    miss = [k for k in rows_ if k not in pv]
    say(bool(rows_) and len(miss) <= 2, "OI BUILD-UP / chain", "%d strikes, day %s, expiry %s · last close known for %d (from %s)%s · NSE's full file: %s" % (
        len(rows_), o.get("day"), o.get("exp"), len(pv), o.get("prev_d"), (" · no close for %s" % ", ".join(sorted(miss, key=float)[:6])) if miss else "",
        "yes" if o.get("prev_full") else "no"))
    k = get("chk?sym=" + sym)
    say(bool(k.get("s")), "CHECKLIST", "CE %s · PE %s · results in %s · from %s" % ((k.get("CE") or {}).get("verdict"), (k.get("PE") or {}).get("verdict"), k.get("results_in"), k.get("src")))
    say(True, "COMPANY EVENTS", "; ".join("%s %s" % (e.get("when"), e.get("kind")) for e in (k.get("ev") or [])) or "none on the list")

    print("\n6. files behind it")
    try:
        import bhavfull
        fs = sorted(x for x in os.listdir(bhavfull.DIR) if x[:4].isdigit()) if os.path.isdir(bhavfull.DIR) else []
        say(bool(fs), "NSE end-of-day files", ", ".join(x[:10] for x in fs[-4:]) or "none yet")
    except Exception as ex:
        say(False, "NSE end-of-day files", str(ex)[:80])
    try:
        import events
        up = [e for e in events.all_events() if e["d"] >= today]
        say(True, "company events", "%d from today on%s" % (len(up), (" · next: %s %s %s %s" % (up and sorted(up, key=lambda e: (e["d"], e.get("t") or "99"))[0]["d"],
                                                                                              sorted(up, key=lambda e: (e["d"], e.get("t") or "99"))[0].get("t") or "",
                                                                                              sorted(up, key=lambda e: (e["d"], e.get("t") or "99"))[0]["s"],
                                                                                              sorted(up, key=lambda e: (e["d"], e.get("t") or "99"))[0]["kind"])) if up else ""))
    except Exception as ex:
        say(False, "company events", str(ex)[:80])
    try:
        st = os.path.getmtime(os.path.join(BASE, "dash_state.json"))
        say(True, "engine state file", "written %d s ago" % (time.time() - st))
    except Exception:
        say(False, "engine state file", "missing")
    print("\n%s" % ("ALL PANELS HAVE DATA" if not BAD else "TO CHECK: %s" % ", ".join(BAD)))


if __name__ == "__main__":
    main()
PY_LOOK
cat > $D/p132btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p132btest.py - the NIFTY chart on a late-starting day starts at its first candle (times follow); the NSE sector indices
stay on the final screen; the top bar says "alerts"; FII / DII read FII first with the date apart; girlook.py is there."""
import os, sys, shutil, subprocess
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
en = open(os.path.join(B, "engine2.py"), encoding="utf-8").read()
check("engine: the sector indices on the after-hours and the final screen", en.count('st["sidx"] = SIDX') == 3)
check("top bar: 'N alerts' (+ the day when not today) and 'data Ns ago'", "} alerts${d.day&&" in pg and "} moving</span>" not in pg and "s ago`;" in pg)
check("F&O DESK: FII first, ₹ crore, the date apart", 'one("FII"),one("DII")' in pg and "cash market, ₹ crore" in pg)
check("girlook.py is there", os.path.exists(os.path.join(B, "girlook.py")))
node = shutil.which("node")
if node:
    a = pg.index("function nifBars()"); b = pg.index("function nifC(")
    js = "let LQ={},QT=0,MK={},NTF='5',NCH=null;\n" + pg[a:b] + r"""
const mk=(f)=>Array.from({length:75},(_,i)=>i<f?null:25000+i);
NCH={o:mk(61),h:mk(61),l:mk(61),c:mk(61),pc:25030}; const m=nifBars();
NCH={o:mk(0).slice(0,40),h:mk(0).slice(0,40),l:mk(0).slice(0,40),c:mk(0).slice(0,40),pc:25030}; const n=nifBars();
console.log(JSON.stringify([m.off,m.c.length,m.N,nifLabels(Math.round(m.off*m.step/5)),n.off,n.c.length,n.N]));"""
    r = subprocess.run([node, "-e", js], capture_output=True, text=True, timeout=30)
    out = r.stdout.strip()
    check("Muhurat-shaped NIFTY day: starts at slot 61, 14 candles of 14, times 14:20 ... 15:30; a normal day untouched: %s" % (out or r.stderr[:160]),
          out == '[61,14,14,["14:20","14:35","14:50","15:00","15:15","15:30"],0,40,75]')
else:
    print("  (node not on this machine - checked when the patch was built)")
print("\nP132B SCREEN TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p132b_patch.py $D || { rm -f $D/p132btest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/girlook.py $D/
cd $D && python3 -m py_compile engine2.py girlook.py p132btest.py || back
timeout 60 python3 p132btest.py 2>&1 | grep "OK  \|FAIL\|P132B"
timeout 60 python3 p132btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p132test.py p131btest.py p130test.py p130btest.py p130ctest.py p129test.py p128test.py p120test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 132b APPLIED. Reload the GIR page. Every panel's data as the server sees it now:"
echo
cd $D && timeout 120 python3 girlook.py DIVISLAB
