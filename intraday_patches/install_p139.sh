#!/bin/bash
# PATCH 139 - THE RESULTS KEY (on top of patch 138c).
#   Every F&O share with quarterly results in the next 14 days, soonest first: the date, what the brokers expect (each broker's
#   profit number, the consensus), its last 4 results against the brokers and the next-day moves, the run-up into the results, the
#   options (the move they price in, IV percentile), the OI battle and the order book - and GIR's report on a tap.
#   resultsdesk.py (new) · dashserve.py, home.html (exact anchors). Restarts gir-dash only (safe in market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g139; mkdir -p $W
grep -q "patch 138c" $D/newsalert.py 2>/dev/null || { echo "patch 138c is not installed yet - paste patch 138c first"; exit 1; }
[ -f $D/resultsdesk.py ] && { echo "patch 139 is already installed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/resultsdesk.py $D/p139test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p139_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p139_patch.py - PATCH 139: THE RESULTS KEY (resultsdesk.py): every F&O share with results in the next 14 days - the date, what
the brokers expect, its history against the brokers and the next-day moves, the run-up, the options, the OI and the order book -
and GIR's report on a tap.
Usage: python3 p139_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "dashserve.py": [
        ('''            if u.path == "/early":                    # ⚡ EARLY (patch 119)''',
         '''            if u.path == "/results":                  # patch 139: THE RESULTS DESK
                try:
                    import resultsdesk
                    v_ = resultsdesk.desk()
                except Exception as ex_:
                    v_ = {"rows": [], "err": str(ex_)[:120]}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str), "application/json; charset=utf-8")
            if u.path == "/early":                    # ⚡ EARLY (patch 119)'''),
    ],
    "home.html": [
        ('''<a data-v="now" onclick="setView('now')"><b>1</b>NOW</a>''',
         '''<a data-v="results" onclick="setView('results')" title="F&amp;O results coming - what the brokers expect (key R)"><b>R</b>RESULTS</a><a data-v="now" onclick="setView('now')"><b>1</b>NOW</a>'''),
        ('''  <section class="p" id="now">''', '''  <section class="p" id="results"><h2>RESULTS <small id="hres">F&amp;O shares with results in the next 14 days · what the brokers expect · tap a share = GIR's report</small></h2><div id="resl"><div class="empty">loading…</div></div></section>
  <section class="p" id="now">'''),
        ('''body.one #grid>section.on, body.one #grid>#focus:not([hidden]){display:block;grid-column:1/-1 !important;grid-row:auto !important;max-height:none !important}''',
         '''body.one #grid>section.on, body.one #grid>#focus:not([hidden]){display:block;grid-column:1/-1 !important;grid-row:auto !important;max-height:none !important}
/* patch 139: THE RESULTS DESK */
#grid>section#results{display:none} body.one #grid>section#results.on{display:block}
#resl .rc{border-bottom:1px solid var(--line);padding:6px 8px;cursor:pointer}#resl .rc:hover{background:#0b0e13}#resl .rh{display:flex;flex-wrap:wrap;gap:4px 12px;align-items:baseline}
#resl .rh .dt{color:var(--amber);min-width:92px}#resl .rh b.s{font-size:13px}#resl .rh .ex{color:var(--hi)}#resl .rh .no{color:var(--dim)}
#resl .ch2{display:flex;flex-wrap:wrap;gap:2px 12px;color:var(--dim);font-size:10.5px;margin-top:2px}#resl .rep{padding:6px 10px 10px;background:#06080b;border-left:3px solid var(--amber);margin:4px 0;line-height:1.5}
#resl table{border-collapse:collapse;margin:4px 0;font-size:10.5px}#resl td{padding:1px 8px 1px 0}#resl .rf{display:flex;gap:6px;padding:6px 8px;flex-wrap:wrap}#resl .rf a{padding:1px 8px;border:1px solid var(--line2);cursor:pointer;color:var(--dim)}#resl .rf a.on{background:var(--amber);color:#000}'''),
        ('''  if(v==="news"){ pullReact();''', '''  if(v==="results"){ pullResults(); if(!RST) RST=setInterval(()=>{ if(VIEW==="results"&&!document.hidden) pullResults(); },60000); }   /* patch 139 */
  if(v==="news"){ pullReact();'''),
        ('''"9":"myfo","0":"desk"};''', '''"9":"myfo","0":"desk","r":"results","R":"results"};'''),
        ('''async function selfCheck(only){''', '''/* patch 139: THE RESULTS DESK - every F&O share with results in the next 14 days; tap = GIR's report */
let RES=null, RST=null, RSOPEN={}, RSF="all";
async function pullResults(){ const v=await getJ("results?k="+encodeURIComponent(K)); if(v){ RES=v; drawResults(); } }
function resOpen(s){ RSOPEN[s]=!RSOPEN[s]; drawResults(); }
function resF(f){ RSF=f; drawResults(); }
function drawResults(){ const el=$("resl"); if(!el) return; const J=RES||{}; let R=(J.rows||[]).filter(r=>!r.err);
  if(RSF==="b") R=R.filter(r=>r.pat); if(RSF==="w") R=R.filter(r=>r.days<=7);
  $("hres").textContent=`${(J.rows||[]).length} F&O shares with results in the next 14 days · ${J.with_brokers||0} with the brokers' numbers · tap a share = GIR's report`;
  const dl=d=>{ const x=new Date(d+"T00:00:00Z"); return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][x.getUTCDay()]+" "+d.slice(8,10)+" "+["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][x.getUTCMonth()]; };
  const wd=n=>n===0?"TODAY":n===1?"tomorrow":`in ${n} days`; const sg=v=>v==null?"—":`<span class="${v>0?"pu":v<0?"pd":""}">${v>0?"+":""}${v}%</span>`;
  const hist=r=>{ const H=r.hist||[]; const vb=H.filter(h=>h.word); if(vb.length){ const b=vb.filter(h=>/ABOVE/.test(h.word)).length, m=vb.filter(h=>/BELOW/.test(h.word)).length; return `vs brokers: beat ${b} · miss ${m} · in line ${vb.length-b-m}`; }
    const vy=H.filter(h=>h.verdict); return vy.length?`vs last year: ${vy.map(h=>h.verdict).join(" · ")}`:"no history yet"; };
  const card=r=>{ const op=RSOPEN[r.s]; const P=r.pat||{};
    let h=`<div class="rc" onclick="resOpen('${esc(r.s)}')"><div class="rh"><span class="dt">${esc(dl(r.d))} · ${wd(r.days)}</span><b class="s">${esc(r.s)}</b><span class="dim">${esc(r.q||"")}</span>${r.pat?`<span class="ex">brokers: ${esc(r.exp)} · ${P.n} broker${P.n>1?"s":""}</span>`:`<span class="no">no broker number yet</span>`}</div>
      <div class="ch2"><span>${esc(hist(r))}</span><span>week ${sg(r.wk)} · month ${sg(r.mo)}</span>${r.em?`<span>options price ±${r.em}%${r.ivp!=null?` · IV pct <b class="${r.ivp>=80?"pd":""}">${r.ivp}</b>`:""}</span>`:""}${r.battle?`<span>OI <b class="${r.battle.verdict==="BULLISH"?"pu":r.battle.verdict==="BEARISH"?"pd":"am"}">${esc(r.battle.verdict)}</b></span>`:""}${r.book?`<span>book ${esc(r.book.word.toLowerCase())}</span>`:""}</div></div>`;
    if(op){ const B=(P.brokers||[]); const H=r.hist||[];
      h+=`<div class="rep">${(r.read||[]).map(x=>"· "+esc(x)).join("<br>")}
        ${B.length?`<table><tr class="dim"><td>BROKER</td><td>PROFIT ₹ cr</td><td>YoY</td></tr>${B.map(b=>`<tr><td>${esc(b[0]||"")}</td><td>${b[1]!=null?Math.round(b[1]).toLocaleString("en-IN"):"—"}</td><td>${b[2]!=null?(b[2]>0?"+":"")+b[2]+"%":"—"}</td></tr>`).join("")}</table>`:""}
        ${H.length?`<table><tr class="dim"><td>QUARTER</td><td>PROFIT YoY</td><td>vs LAST YEAR</td><td>vs BROKERS</td><td>NEXT DAY</td><td>3 DAYS</td></tr>${H.map(x=>`<tr><td>${esc(x.q)}</td><td>${x.pat_yoy!=null?sg(Math.round(x.pat_yoy)):"—"}</td><td>${esc(x.verdict||"—")}</td><td>${esc(x.word||"—")}</td><td>${x.d1!=null?sg(x.d1):"—"}</td><td>${x.d3!=null?sg(x.d3):"—"}</td></tr>`).join("")}</table>`:""}
        <a class="k" onclick="event.stopPropagation();mkOpen('${esc(r.s)}')">→ open ${esc(r.s)}'s trading screen</a></div>`; }
    return h; };
  const f=`<div class="rf"><a class="${RSF==="all"?"on":""}" onclick="resF('all')">ALL 14 DAYS</a><a class="${RSF==="w"?"on":""}" onclick="resF('w')">THIS WEEK</a><a class="${RSF==="b"?"on":""}" onclick="resF('b')">WITH BROKERS' NUMBERS</a></div>`;
  el.innerHTML=f+(R.length?R.map(card).join(""):`<div class="empty">${J.err?esc(J.err):"no F&amp;O results in the calendar for these days"}</div>`); }
async function selfCheck(only){'''),
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
cat > $W/resultsdesk.py <<'PY_RES'
#!/usr/bin/env python3
"""resultsdesk.py - patch 139: THE RESULTS DESK. Every F&O share with quarterly results in the next 14 days, in one list, and a report
for each - what GIR knows before the numbers come:

  the date        results_cal (NSE's board meetings / the calendar GIR already keeps) · the quarter
  the brokers     their profit / revenue numbers for this quarter found in the news by the evening job (expect.py, data/expect.db):
                  the consensus (median) and each broker
  its history     the last 4 results against the brokers (BEAT / MISS / IN LINE vs estimates, else vs last year) and what the share
                  did the next day - "beat 3 of 4, next day avg +2.1%"
  the run-up      the move in the last week and month (a big run-up = a lot already in the price: a beat may not lift it, an
                  in-line result can sell off)
  the options     ATM IV, IV percentile, the move the options price in (the straddle) vs the share's typical day; after the
                  results IV collapses - a bought option needs a move bigger than the premium
  the money       THE OI BATTLE (patch 135) and the ORDER BOOK (137) now
  GIR's read      the plain sentences a trader would say, and: wait for the numbers - GIR reads them within a minute of the filing
                  (🚨 CRITICAL RESULTS when 10%+ off the brokers' number)
  page            the RESULTS key: the list, tap a share = its report      python3 resultsdesk.py [SYM]"""
import os, re, sys, json, time, sqlite3, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def _fo():
    try:
        c = _ro("chains.db"); v = {r[0]: r[1] for r in c.execute("select sym, lot from fo_list")}; c.close(); return v
    except Exception:
        return {}


def calendar(days=14, now=None):
    now = now or dt.datetime.now(IST)
    try:
        c = _ro("chains.db")
        rows = c.execute("select sym, min(d) from results_cal where d>=? and d<=? group by sym order by min(d), sym",
                         (str(now.date()), str(now.date() + dt.timedelta(days=days)))).fetchall()
        c.close()
        return rows
    except Exception:
        return []


def _closes(sym):
    try:
        c = _ro(os.path.join("data", "oistudy.db"))
        r = c.execute("select d, spot from day where sym=? and spot>0 order by d desc limit 30", (sym,)).fetchall()
        c.close()
        return r
    except Exception:
        return []


def _quote(sym):
    try:
        q = (json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}).get("q") or {}
        v = q.get(sym)
        return (v[0], v[1]) if v else (None, None)
    except Exception:
        return None, None


def _chk(sym):
    try:
        return (json.load(open(os.path.join(BASE, "checklist.json"))) or {}).get(sym) or {}
    except Exception:
        return {}


def history(sym, n=4):
    """the last n results: [{"q", "t", "verdict" (vs last year), "pat_yoy", "rev_yoy", "word" (vs brokers), "surprise", "d1", "d3"}]"""
    out = []
    try:
        c = _ro(os.path.join("data", "expect.db"))
        acts = c.execute("select q, t_filed, pat, rev, pat_yoy, rev_yoy, verdict from act where sym=? order by t_filed desc limit ?", (sym, n)).fetchall()
        for q, t, pat, rev, py, ry, v in acts:
            cm = c.execute("select surprise, word from cmp where sym=? and q=?", (sym, q)).fetchone()
            rc = c.execute("select d1, d3 from react where sym=? and q=?", (sym, q)).fetchone()
            out.append({"q": q, "t": t, "pat": pat, "rev": rev, "pat_yoy": py, "rev_yoy": ry, "verdict": v, "surprise": cm[0] if cm else None,
                        "word": cm[1] if cm else None, "d1": rc[0] if rc else None, "d3": rc[1] if rc else None})
        c.close()
    except Exception:
        pass
    return out


def one(sym, d, now=None, fo=None):
    """the report of one share whose results come on date d (YYYY-MM-DD)"""
    now = now or dt.datetime.now(IST)
    import expect
    dd = dt.date.fromisoformat(d)
    q, _qe = expect.quarter_for_filing(dd)
    r = {"s": sym, "d": d, "days": (dd - now.date()).days, "q": q, "lot": (fo or {}).get(sym)}
    pat = expect.consensus(sym, q, "pat") if q else None
    rev = expect.consensus(sym, q, "rev") if q else None
    r["pat"], r["rev"] = pat, rev
    try:
        c = _ro(os.path.join("data", "expect.db"))
        dn = c.execute("select t from done where sym=? and q=? and kind='est'", (sym, q)).fetchone()
        c.close()
        r["searched"] = bool(dn)
    except Exception:
        r["searched"] = False
    H = history(sym)
    r["hist"] = H
    px, chg = _quote(sym)
    cl = _closes(sym)
    last = px or (cl[0][1] if cl else None)
    r["px"], r["chg"] = last, chg
    r["wk"] = round((last / cl[5][1] - 1) * 100, 1) if last and len(cl) > 5 else None
    r["mo"] = round((last / cl[21][1] - 1) * 100, 1) if last and len(cl) > 21 else None
    k = _chk(sym)
    r["iv"], r["ivp"], r["em"], r["typ"] = k.get("iv"), k.get("ivp"), k.get("em"), k.get("typ")
    try:
        import oibattle
        b = oibattle.read(sym, k.get("ivp"))
        r["battle"] = {"verdict": b["verdict"], "short": b["short"], "ceil": b["ceil"], "floor": b["floor"]} if b else None
    except Exception:
        r["battle"] = None
    try:
        import bookpress
        r["book"] = bookpress.for_sym(sym)
    except Exception:
        r["book"] = None
    r["read"] = read(r)
    r["exp"] = (("₹{:,.0f} cr".format(pat["value"]) if pat.get("value") else "") + ((" (%+.0f%% YoY)" % pat["yoy"]) if pat.get("yoy") is not None else "")) if pat else ""
    return r


def read(r):
    """GIR's plain sentences"""
    L = []
    p = r.get("pat")
    when = "today" if r["days"] == 0 else "tomorrow" if r["days"] == 1 else "in %d days" % r["days"]
    if p:
        L.append("The brokers expect %s profit %s from %d broker%s%s." % (
            r["q"], ("₹{:,.0f} cr".format(p["value"]) if p.get("value") else "growth %+.0f%%" % (p.get("yoy") or 0)), p["n"], "s" if p["n"] > 1 else "",
            (" (%+.0f%% YoY)" % p["yoy"]) if (p.get("value") and p.get("yoy") is not None) else ""))
        if r.get("rev") and r["rev"].get("value"):
            L.append("Revenue expected ₹{:,.0f} cr.".format(r["rev"]["value"]))
        L.append("When the numbers come, GIR compares them with this within a minute: 10%+ above or below = a side, 20%+ = 🚨 CRITICAL.")
    else:
        L.append("No broker number found yet in the news%s - GIR will judge the result against last year only." % (" (searched)" if r.get("searched") else " (the evening job searches 7 days ahead)"))
    H = r.get("hist") or []
    if H:
        vb = [h for h in H if h.get("word")]
        if vb:
            beat = sum(1 for h in vb if "ABOVE" in (h["word"] or "")); miss = sum(1 for h in vb if "BELOW" in (h["word"] or ""))
            L.append("Against the brokers, the last %d results: beat %d · missed %d · in line %d." % (len(vb), beat, miss, len(vb) - beat - miss))
        else:
            vy = [h for h in H if h.get("verdict")]
            if vy:
                L.append("Against last year, the last %d results: %s." % (len(vy), " · ".join("%s %s" % (h["q"], h["verdict"]) for h in vy)))
        mv = [h["d1"] for h in H if h.get("d1") is not None]
        if mv:
            L.append("The next day it moved %s (avg %+.1f%%, biggest %+.1f%%)." % (" / ".join("%+.1f%%" % x for x in mv), sum(mv) / len(mv), max(mv, key=abs)))
    if r.get("wk") is not None:
        if r["wk"] >= 8 or (r.get("mo") or 0) >= 15:
            L.append("It ran up %+.1f%% in a week (%+.1f%% in a month) into the results: a lot may already be in the price - a beat may not lift it much, an in-line result can sell off." % (r["wk"], r.get("mo") or 0))
        elif r["wk"] <= -8 or (r.get("mo") or 0) <= -15:
            L.append("It fell %+.1f%% in a week (%+.1f%% in a month) into the results: low expectations - a decent result can bounce it." % (r["wk"], r.get("mo") or 0))
        else:
            L.append("Into the results: %+.1f%% in a week, %+.1f%% in a month - no big run-up." % (r["wk"], r.get("mo") or 0))
    if r.get("em"):
        s = "The options price in a ±%.1f%% move" % r["em"]
        if r.get("typ"):
            s += " (its typical day ±%.1f%%)" % r["typ"]
        if r.get("ivp") is not None:
            s += "; IV percentile %d%s" % (r["ivp"], " - EXPENSIVE" if r["ivp"] >= 80 else "")
        L.append(s + ". After the results IV falls: a bought option needs a move bigger than that, fast.")
    if r.get("battle"):
        L.append("OI now: %s." % r["battle"]["short"])
    if r.get("book"):
        L.append("Order book: %s (buyers %s%% of the orders waiting)." % (r["book"]["word"].lower(), r["book"]["buy"]))
    L.append("Best: wait for the numbers - trade the surprise against the brokers, not the guess.")
    return L


def desk(days=14, now=None):
    """-> {"t", "rows": [report per F&O share, soonest first]} (cached 60 s)"""
    if now is None and _C["v"] is not None and time.time() - _C["t"] < 60:
        return _C["v"]
    fo = _fo()
    rows = []
    for sym, d in calendar(days, now):
        if fo and sym not in fo:
            continue
        try:
            rows.append(one(sym, d, now, fo))
        except Exception as ex:
            rows.append({"s": sym, "d": d, "err": str(ex)[:80]})
    v = {"t": time.time(), "n": len(rows), "with_brokers": sum(1 for r in rows if r.get("pat")), "rows": rows}
    if now is None:
        _C.update({"t": time.time(), "v": v})
    return v


if __name__ == "__main__":
    a = [x.upper() for x in sys.argv[1:]]
    v = desk()
    print("RESULTS DESK: %d F&O shares with results in 14 days · %d with brokers' numbers" % (v["n"], v["with_brokers"]))
    for r in v["rows"]:
        if a and r["s"] not in a:
            continue
        print("%s  %-11s %s  %s" % (r["d"], r["s"], r.get("q") or "", r.get("exp") or "no broker number yet"))
        if a:
            for x in r.get("read") or []:
                print("    · " + x)
PY_RES
cat > $D/p139test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p139test.py - THE RESULTS DESK: F&O shares with results in 14 days (a non-F&O share and one 20 days out left out), soonest first;
ASHOKLEY with 3 brokers' numbers, its last 4 results vs the brokers and the next-day moves, a 22% run-up -> the report says so;
COCHINSHIP with no broker number -> says so; the page has the RESULTS key and its report. Fake files - nothing is fetched."""
import os, re, sys, json, time, sqlite3, tempfile, shutil, subprocess, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import resultsdesk, expect, oibattle, bookpress
IST = resultsdesk.IST
tmp = tempfile.mkdtemp(prefix="p139")
try:
    os.makedirs(os.path.join(tmp, "data"))
    resultsdesk.BASE = oibattle.BASE = tmp; expect.DB = os.path.join(tmp, "data", "expect.db"); bookpress.FILE = os.path.join(tmp, "data", "book.json")
    now = dt.datetime(2026, 11, 9, 10, 0, tzinfo=IST)
    D = lambda n: str(now.date() + dt.timedelta(days=n))
    c = sqlite3.connect(os.path.join(tmp, "chains.db"))
    c.execute("create table fo_list(sym text, lot int)"); c.execute("create table results_cal(d text, sym text, purpose text)")
    c.executemany("insert into fo_list values(?,?)", [("ASHOKLEY", 5000), ("COCHINSHIP", 400)])
    c.executemany("insert into results_cal values(?,?,'r')", [(D(5), "ASHOKLEY"), (D(1), "COCHINSHIP"), (D(2), "SMALLCO"), (D(20), "COCHINSHIP")])
    c.commit(); c.close()
    q, _ = expect.quarter_for_filing(now.date() + dt.timedelta(days=5))
    for b, v, y in (("Motilal Oswal", 820, 18), ("Kotak", 790, 14), ("Nomura", 860, 22)):
        expect.add_estimate("ASHOKLEY", q, b, "pat", v, y)
    e = expect.db()
    for i, (qq, w, d1) in enumerate((("Q1FY27", "12% ABOVE ESTIMATES", 3.1), ("Q4FY26", "8% BELOW ESTIMATES", -2.4), ("Q3FY26", "IN LINE WITH ESTIMATES", 0.6), ("Q2FY26", "15% ABOVE ESTIMATES", 4.0))):
        e.execute("insert into act values(?,?,?,?,?,?,?,?)", ("ASHOKLEY", qq, time.time() - (i + 1) * 90 * 86400, 700, 9000, 10, 5, "BEAT"))
        e.execute("insert into cmp values(?,?,?,?,?,?,?,?)", ("ASHOKLEY", qq, time.time(), 1, 1, 0, w, ""))
        e.execute("insert into react values(?,?,?,?,?,?)", ("ASHOKLEY", qq, 100, d1, d1 * 1.2, 0))
    e.commit(); e.close()
    o = sqlite3.connect(os.path.join(tmp, "data", "oistudy.db")); o.execute("create table day(sym text, d text, spot real)")
    for i in range(30):
        o.execute("insert into day values(?,?,?)", ("ASHOKLEY", str(now.date() - dt.timedelta(days=i)), 178.0 if i == 0 else 145.0 if i >= 5 else 160.0))
    o.commit(); o.close()
    json.dump({"ASHOKLEY": {"iv": 40, "ivp": 88, "em": 6.2, "typ": 2.1}}, open(os.path.join(tmp, "checklist.json"), "w"))
    v = resultsdesk.desk(now=now)
    check("the list: %s" % [(r["s"], r["d"]) for r in v["rows"]], [r["s"] for r in v["rows"]] == ["COCHINSHIP", "ASHOKLEY"] and v["with_brokers"] == 1)
    a = v["rows"][1]
    check("ASHOKLEY: brokers %s · 3 brokers · week %s%% · month %s%%" % (a["exp"], a["wk"], a["mo"]), a["exp"].startswith("₹820 cr (+18% YoY)") and a["pat"]["n"] == 3 and a["wk"] == 22.8)
    for x in a["read"]:
        print("     · " + x)
    rd = " ".join(a["read"])
    check("the report: the brokers' number, beat 2 · missed 1 · in line 1, the next-day moves, the run-up, the options (IV pct 88 EXPENSIVE)",
          "₹820 cr from 3 brokers" in rd and "beat 2 · missed 1 · in line 1" in rd and "+3.1%" in rd and "ran up +22.8% in a week" in rd and "EXPENSIVE" in rd and "wait for the numbers" in rd)
    cs = v["rows"][0]
    check("COCHINSHIP: no broker number -> said: %s" % cs["read"][0][:70], cs["read"][0].startswith("No broker number found yet") and cs["days"] == 1)
    pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
    check("the page: the RESULTS key (R), its list and report", 'data-v="results"' in pg and "function drawResults()" in pg and '"r":"results"' in pg and "→ open" in pg)
    ds = open(os.path.join(B, "dashserve.py"), encoding="utf-8").read()
    check("the page server: /results", 'if u.path == "/results":' in ds)
    node = shutil.which("node")
    if node:
        js = re.findall(r"<script>(.*?)</script>", pg, re.S)
        open(os.path.join(tmp, "p.js"), "w").write(js[0] if js else "")
        r = subprocess.run([node, "--check", os.path.join(tmp, "p.js")], capture_output=True, text=True, timeout=30)
        check("the page's script parses (%s)" % (r.stderr.strip().split("\n")[-1][:80] if r.returncode else "ok"), r.returncode == 0)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP139 RESULTS DESK TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p139_patch.py $D || { rm -f $D/p139test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/resultsdesk.py $D/
cd $D && python3 -m py_compile resultsdesk.py dashserve.py p139test.py || back
timeout 120 python3 p139test.py 2>&1 | grep "OK  \|FAIL\|P139"
timeout 120 python3 p139test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p137test.py p136test.py p134test.py p132test.py p129test.py p128test.py p119test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo
echo "PATCH 139 APPLIED. Reload the GIR page: the R RESULTS key. On your server now:"
cd $D && timeout 120 python3 resultsdesk.py | head -30
echo "the brokers' numbers GIR has found so far:  $(timeout 60 python3 expect.py --status 2>/dev/null | tail -1)"
