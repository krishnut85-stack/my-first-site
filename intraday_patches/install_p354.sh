#!/bin/bash
# PATCH 354 - SECTORS AND ROTATION FROM ALL THE SECTOR'S SHARES, LIVE (Rama, 16 Nov: "sector performance is the performance of ALL its stocks - only
#   the F&O ones gives me wrong information. Healthcare is no.1 on Trendlyne and 9th in GIR. The rotation is not updating").
#   · seclive.py + gir-seclive: every share of NSE's Nifty Total Market (~750, ~95% of the market's value) in NSE's own sector (the list GIR already
#     keeps), weighted by NSE's free-float market cap (once a day), Kite prices for all of them in one request every 3 seconds (every 5 min after
#     the close) -> data/seclive.json · the 15 / 30 / 60-minute ROTATION from a per-minute record kept on the server (the same on every screen)
#   · dashserve /seclive · GIR's SECTORS box and ROTATION read it (GIR's look kept; tap a sector = its F&O shares; GIR's own numbers if it is missing)
#   The engine, the desk and the alerts are NOT touched. Restarts the dashboard only. Prints the ranking at the end - compare it with Trendlyne.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 354" $D/home.html && systemctl is-active --quiet gir-seclive; then echo "patch 354 - already in"; exit 0; fi
grep -q "patch 344" $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && [ -f $D/nsesec.py ] && [ -f $D/data/nse_sectors.json ] || { echo "patch 344 / dashserve's route / NSE's sector list not found - nothing done"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl disable --now gir-seclive 2>/dev/null; rm -f /etc/systemd/system/gir-seclive.service $D/seclive.py; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/seclive.py <<'PY_SL'
#!/usr/bin/env python3
"""seclive.py - patch 354: READ ONLY. THE SECTORS FROM ALL THEIR SHARES, LIVE (Rama, 16 Nov: "sector performance is the performance of ALL its
stocks - only the F&O ones gives me wrong information. Healthcare is no.1 on Trendlyne and 9th in GIR. The rotation is not updating").
  · the shares   every share of NSE's Nifty Total Market (about 750 - about 95% of the market's value), in NSE's OWN sector (data/nse_sectors.json,
                 the same list GIR's page already uses; Financial Services split into banks / nbfc & finance / insurance / capital markets as before)
  · the weight   each share's MARKET CAP from NSE's own daily file (mcap<date>.csv in the PR zip of NSE's archives - fetched once a day, kept in
                 data/seclive_w.json); equal weight only if NSE never answered
  · the price    Kite: every share's last price and yesterday's close in ONE request, every 3 seconds in market hours (every 5 minutes outside)
  · TODAY        a sector's % = the size-weighted average of all its shares' % since yesterday's close (like Trendlyne / NSE's indices)
  · ROTATION     the same, over the last 15 / 30 / 60 minutes - from a per-minute record kept HERE on the server (data/seclive_hist.json), so
                 every screen shows the same numbers, from 09:15, however late the page was opened
  -> data/seclive.json (the page reads it through dashserve /seclive). Orders nothing, sends nothing.
  python3 seclive.py once     one pass now, prints the ranking"""
import os, re, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "seclive.json")
WF = os.path.join(D, "data", "seclive_w.json")
HF = os.path.join(D, "data", "seclive_hist.json")
FAST_S, SLOW_S = 3, 300
WINS = (15, 30, 60)
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept": "application/json,text/html,*/*", "Accept-Language": "en-US,en;q=0.9"}


def now():
    return dt.datetime.now(IST)


def log(*a):
    print(now().strftime("%H:%M:%S"), *a, flush=True)


def market_open(n):
    if n.weekday() > 4:
        return False
    try:
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return "09:15" <= n.strftime("%H:%M") <= "15:35"


# patch 354c: three of NSE's sectors hold two different businesses that move opposite ways (16 Nov: hospitals +2%, pharma -1.2%; electronics makers
# -3.9% inside capital goods / consumer durables; telecom equipment -3.7% inside telecom) - split the way Trendlyne shows them
HOSP = set("MAXHEALTH APOLLOHOSP FORTIS NH MEDANTA ASTERDM KIMS RAINBOW LALPATHLAB METROPOLIS VIJAYA THYROCARE JLHL YATHARTH HCG SHALBY AGARWALEYE INDRAMEDCO "
           "KRSNAA SURAKSHA MEDIASSIST POLYMED".split())
HOSP_RE = re.compile(r"hospital|healthcare institute|hrudayalaya|medical sciences|path ?labs|diagnos|health care ltd|healthcare global|life line|eye ?care", re.I)
NOT_HOSP = set("SHILPAMED".split())                                         # 354d: Shilpa Medicare is a pharma company
EMS = set("KAYNES SYRMA DIXON AMBER PGEL CYIENTDLM AVALON NETWEB DATAPATTNS CENTUM ELIN".split())
EMS_RE = re.compile(r"electronics manufactur|electronic manufactur|technologies \(india\) .*ems", re.I)
TEL_SERV = set("BHARTIARTL BHARTIHEXA IDEA INDUSTOWER TATACOMM RAILTEL TTML MTNL ROUTE TANLA".split())   # 354d: Route Mobile / Tanla are services


def refine(sym, sec, name=""):
    """NSE's sector -> the finer one where one sector holds two businesses"""
    if sec == "healthcare":
        return "hospitals & diagnostics" if (sym not in NOT_HOSP and (sym in HOSP or HOSP_RE.search(name or ""))) else "pharma"
    if sym in EMS or (sec in ("capital goods", "consumer durables") and EMS_RE.search(name or "")):
        return "electronics & hardware"
    if sec == "telecom":
        return "telecom services" if sym in TEL_SERV else "telecom equipment"
    return sec


def universe():
    """{SYMBOL: GIR page sector} for every share in NSE's list, + {SYMBOL: company name}"""
    import nsesec
    j = nsesec.load_map() or {}
    nse, names = j.get("map") or {}, j.get("names") or {}
    try:
        import sectors
        hand = sectors.hand_map()
    except Exception:
        hand = {}
    out = {}
    for s in nse:
        if not nsesec.not_a_share(s):
            out[s] = refine(s, nsesec.sector_of(s, nse, hand, names), names.get(s, ""))
    return out, names


def fo_set():
    try:
        import sqlite3
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        r = {x[0] for x in c.execute("select sym from fo_list")}; c.close(); return r
    except Exception:
        return set()


def parse_mcap(text):
    """NSE's mcap<ddmmyyyy>.csv (in the daily PR zip): Trade Date, Symbol, Series, Security Name, Category, Last Trade Date, Face Value,
    Issue Size, Close Price, Market Cap(Rs.) -> {SYMBOL: market cap}"""
    import csv, io
    w = {}
    rd = csv.reader(io.StringIO(text))
    head = [h.strip().lower() for h in next(rd, [])]
    try:
        si = head.index("symbol"); mi = next(k for k, h in enumerate(head) if h.startswith("market cap"))
    except Exception:
        return w
    for row in rd:
        try:
            s = row[si].strip().upper(); v = float(row[mi].strip().replace(",", ""))
        except Exception:
            continue
        if s and v > 0:
            w[s] = max(v, w.get(s, 0.0))
    return w


def nse_weights():
    """{SYMBOL: market cap} - NSE's own daily market-cap file (mcap<ddmmyyyy>.csv inside the PR zip in NSE's archives; the newest of the
    last 8 days - in the morning that is yesterday's close). Fetched once a day, kept in data/seclive_w.json. (patch 354b: NSE's website API
    answers 403 to this server - the archive does answer.)"""
    try:
        j = json.load(open(WF))
        if j.get("day") == str(now().date()) and len(j.get("w") or {}) > 300:
            return j["w"], j.get("src", "NSE")
    except Exception:
        j = None
    try:
        import requests, io, zipfile
        s = requests.Session()
        for i in range(9):
            x = now().date() - dt.timedelta(days=i)
            for host in ("nsearchives.nseindia.com", "archives.nseindia.com"):
                try:
                    r = s.get("https://%s/archives/equities/bhavcopy/pr/PR%s.zip" % (host, x.strftime("%d%m%y")), headers=dict(UA, Accept="*/*"), timeout=25)
                    if not (r.ok and r.content[:2] == b"PK"):
                        continue
                    z = zipfile.ZipFile(io.BytesIO(r.content))
                    f = next((n for n in z.namelist() if "mcap" in n.lower()), None)
                    w = parse_mcap(z.read(f).decode("latin-1")) if f else {}
                    if len(w) > 300:
                        src = "NSE market cap %s" % x.strftime("%d %b")
                        json.dump({"day": str(now().date()), "src": src, "w": w}, open(WF + ".tmp", "w")); os.replace(WF + ".tmp", WF)
                        log("weights: %d shares - %s (%s)" % (len(w), src, f))
                        return w, src
                except Exception as ex:
                    log("weights: %s %s: %s" % (host, x, str(ex)[:60]))
    except Exception as ex:
        log("weights: NSE's archive did not answer (%s)" % str(ex)[:80])
    if j and len(j.get("w") or {}) > 300:
        return j["w"], j.get("src", "NSE") + " (kept from " + str(j.get("day")) + ")"
    return {}, "EQUAL (NSE's sizes not available)"


def quotes(kite, syms):
    """{SYMBOL: (last, yesterday's close)} - Kite's ohlc, up to 1000 shares a request"""
    import getdata
    out = {}
    L = sorted(syms)
    for i in range(0, len(L), 900):
        q = getdata.call(kite.ohlc, ["NSE:" + s for s in L[i:i + 900]]) or {}
        for k, v in q.items():
            lp = float(v.get("last_price") or 0); pc = float((v.get("ohlc") or {}).get("close") or 0)
            if lp > 0 and pc > 0:
                out[k.split(":", 1)[1]] = (lp, pc)
    return out


def compute(SEC, W, Q, hist, FO, wsrc, n=None):
    """the sectors: today's % and the 15 / 30 / 60-minute rotation, size-weighted, from every share"""
    n = n or now(); mn = n.hour * 60 + n.minute
    base = {}
    for w in WINS:
        b = None
        for h in hist:
            if h["m"] <= mn - w:
                b = h
        base[w] = b
    G = {}
    for s, sec in SEC.items():
        if s not in Q:
            continue
        lp, pc = Q[s]; wt = W.get(s) or (0.0 if W else 1.0)
        if W and not wt:
            wt = 0.0
        g = G.setdefault(sec, {"a": 0.0, "w": 0.0, "n": 0, "up": 0, "dn": 0, "rows": [], "r": {k: [0.0, 0.0] for k in WINS}, "rr": {k: [] for k in WINS}, "eq": 0.0})
        c = (lp / pc - 1) * 100; g["n"] += 1; g["eq"] += c; g["up"] += c > 0; g["dn"] += c < 0
        g["rows"].append((c, s))
        if wt > 0:
            g["a"] += c * wt; g["w"] += wt
        for k in WINS:
            b = base[k]; p0 = b and b["p"].get(s)
            if p0:
                g["rr"][k].append(((lp / p0 - 1) * 100, s))
                if wt > 0:
                    g["r"][k][0] += (lp / p0 - 1) * 100 * wt; g["r"][k][1] += wt
    out = []
    for sec, g in G.items():
        if g["n"] < 2:
            continue
        chg = g["a"] / g["w"] if g["w"] else g["eq"] / g["n"]
        rows = sorted(g["rows"], reverse=True)
        out.append({"name": sec, "chg": round(chg, 2), "n": g["n"], "up": g["up"], "dn": g["dn"], "fo": sum(1 for _, s in rows if s in FO), "fos": sorted(s for _, s in rows if s in FO),   # 354e: its F&O shares - a tap on the sector lists them
                    "eqw": round(g["eq"] / g["n"], 2),
                    "rot": {str(k): (round(g["r"][k][0] / g["r"][k][1], 2) if g["r"][k][1] else None) for k in WINS},
                    "rotx": {str(k): {"up": sum(1 for c, _ in g["rr"][k] if c > 0), "dn": sum(1 for c, _ in g["rr"][k] if c < 0), "n": len(g["rr"][k]),
                                      "top": [[s, round(c, 2), s in FO] for c, s in sorted(g["rr"][k], reverse=True)[:3]],
                                      "bot": [[s, round(c, 2), s in FO] for c, s in sorted(g["rr"][k])[:3]]} for k in WINS},
                    "top": [[s, round(c, 2), s in FO] for c, s in rows[:3]], "bot": [[s, round(c, 2), s in FO] for c, s in rows[-3:][::-1]]})
    out.sort(key=lambda x: -x["chg"])
    since = {str(k): (("%02d:%02d" % divmod(base[k]["m"], 60)) if base[k] else None) for k in WINS}
    return {"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": str(n.date()), "shares": len(Q), "weights": wsrc, "since": since, "sectors": out}


def load_hist(day):
    try:
        j = json.load(open(HF))
        if j.get("day") == day:
            return j.get("h") or []
    except Exception:
        pass
    return []


def save(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path + ".tmp", "w"), ensure_ascii=False, separators=(",", ":")); os.replace(path + ".tmp", path)


def get_kite():
    import core
    k = core.get_kite()
    try:
        k.timeout = 7
    except Exception:
        pass
    return k


def main():
    once = sys.argv[1:2] == ["once"]
    kite = None; SEC = {}; W = {}; wsrc = ""; FO = set(); day = None; hist = []; last_min = None
    while True:
        n = now(); live = market_open(n)
        try:
            if day != str(n.date()) or not SEC:
                day = str(n.date()); SEC, _ = universe(); FO = fo_set(); W, wsrc = nse_weights(); hist = load_hist(day)
                log("%d shares in %d sectors · weights: %s" % (len(SEC), len(set(SEC.values())), wsrc))
            if kite is None:
                kite = get_kite()
            Q = quotes(kite, SEC)
            mn = n.hour * 60 + n.minute
            if live and mn != last_min and Q:                                 # the per-minute record for ROTATION
                last_min = mn; hist.append({"m": mn, "p": {s: v[0] for s, v in Q.items()}}); hist = [h for h in hist if h["m"] >= mn - 75]
                save({"day": day, "h": hist}, HF)
            V = compute(SEC, W, Q, hist, FO, wsrc, n); V["live"] = live
            save(V, OUT)
            if once:
                print("SECTORS from %d shares · weights: %s · %s" % (V["shares"], V["weights"], V["at"]))
                for x in V["sectors"]:
                    print("  %-24s %+6.2f%%  (%3d shares, %2d F&O · %3d up %3d down · equal-weight %+.2f%%)  best %s %+.1f%%  worst %s %+.1f%%" % (
                        x["name"], x["chg"], x["n"], x["fo"], x["up"], x["dn"], x["eqw"], x["top"][0][0], x["top"][0][1], x["bot"][0][0], x["bot"][0][1]))
                for g in ("hospitals & diagnostics", "electronics & hardware", "telecom services", "telecom equipment"):   # patch 354c: who is in the new groups
                    m = sorted(s for s, v in SEC.items() if v == g); line = "  = %s (%d):" % (g, len(m))
                    for s in m:
                        if len(line) + len(s) > 66:
                            print(line); line = "     "
                        line += " " + s + ("*" if s in FO else "")
                    print(line)
                print("  (* = F&O)")
                return
        except Exception as ex:
            log("seclive: %s" % str(ex)[:160])
            if "token" in str(ex).lower():
                kite = None
            if once:
                return
            time.sleep(20)
        time.sleep(FAST_S if live else SLOW_S)


if __name__ == "__main__":
    main()
PY_SL
cat > $W/home_add.html <<'ADD_354'
<style>/* patch 354 + 354e: SECTORS and ROTATION from ALL the sector's NSE shares, size-weighted, from the server (seclive.py) */
#mk-don .gxl{font:600 11px ui-monospace,Menlo,monospace;color:#8fc3ff;margin-left:8px;white-space:nowrap}
#mk-don .sb .gxn{font:600 11px ui-monospace,Menlo,monospace;color:#a3aebf;margin-left:6px;white-space:nowrap}
#mk-don .sb .gxf{font-size:10px;color:#8b97a9;margin-left:4px}
#mk-don .sb .gxn b{font:600 11px ui-monospace,Menlo,monospace}   /* patch 354e: ▲ up count green, ▼ down count red */
#mk-rot .gxl{font:600 11px ui-monospace,Menlo,monospace;color:#8fc3ff;margin-left:8px}
#mk-rot .rg .sh i{font-style:normal;font-size:9px;color:#8b97a9;margin-left:1px}
</style>
<script>/* patch 354 (Rama, 16 Nov: "sector performance is the performance of ALL its stocks - only the F&O ones gives me wrong information. Healthcare is
   no.1 on Trendlyne and 9th in GIR. The rotation is not updating"). GIR's SECTORS box and ROTATION were built from the ~218 F&O shares only, and the
   15M / 30M / 1H rotation from what THIS page had seen since it was opened. Now both read the server's seclive.py: every share of NSE's Nifty Total
   Market (~750) in NSE's own sector, weighted by NSE's free-float market cap, Kite prices every 3 seconds; the 15 / 30 / 60-minute record is kept on
   the server, so every screen shows the same numbers from 09:15. The box keeps GIR's look; tap a sector = its F&O shares, as before.
   If the server's numbers are missing or old, the boxes fall back to GIR's own (nothing goes blank). */
(function(){
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let SL=null, busy=false;
  const E=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const pc=v=>v==null?"—":(v>0?"+":"")+(+v).toFixed(2)+"%";
  const cl=v=>v>0?"pu":v<0?"pd":"dim";
  function fresh(){ return !!(SL&&SL.sectors&&SL.sectors.length&&(Date.now()/1000-(+SL.t||0))<(SL.live?30:1200)); }
  window.gxSecLive=()=>fresh()?SL:null;
  async function pull(){ if(busy) return; busy=true;
    try{ const r=await fetch("seclive?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ const v=await r.json(); if(v&&v.sectors) SL=v; } }catch(e){}
    busy=false; paint(); }
  const has=n=>((typeof SECS!=="undefined"&&SECS)||[]).some(x=>String(x.name)===n);
  /* patch 354e: GIR's F&O sector list (the F&O MOVERS filter, its dropdown, the phone's sector grid) takes the SAME groups as this box - each sector's
     F&O shares from the server - so a tap on TELECOM SERVICES / ELECTRONICS & HARDWARE / HOSPITALS lists its F&O shares */
  function regroup(){ try{ if(!fresh()||typeof SECS==="undefined"||!Array.isArray(SECS)||SECS.__gx) return; if(!SL.sectors.some(x=>(x.fos||[]).length)) return;
      const by={}; SECS.forEach(x=>{ by[String(x.name)]=x; });
      const L=SL.sectors.filter(x=>(x.fos||[]).length).map(x=>Object.assign({},by[x.name]||{},{name:x.name,syms:x.fos.slice(),n:x.fos.length,chg:x.chg}));
      L.sort((a,b)=>a.name.localeCompare(b.name)); if(L.length>=5) SECS=L; }catch(e){} }
  function rechg(){ try{ if(!fresh()||typeof SECS==="undefined") return; const m={}; SL.sectors.forEach(x=>{ m[x.name]=x.chg; }); (SECS||[]).forEach(x=>{ if(m[x.name]!=null) x.chg=m[x.name]; }); }catch(e){} }
  function paintSec(){ const el=document.getElementById("mk-don"); if(!el||!fresh()) return;
    const so=(typeof SSORT!=="undefined")?SSORT:"dn";
    const R=SL.sectors.slice().sort((a,b)=>so==="az"?a.name.localeCompare(b.name):so==="up"?a.chg-b.chg:b.chg-a.chg);
    const mx=Math.max(1,...R.map(x=>Math.abs(x.chg)));
    const up=R.filter(x=>x.chg>0).length, dn=R.filter(x=>x.chg<0).length;
    const mv=L=>L.map(t=>t[0]+" "+pc(t[1])+(t[2]?" (F&O)":"")).join(", ");
    el.innerHTML=`<div class="ssb">SORT <a class="${so!=="az"?"on":""}" onclick="ssSet(SSORT==='dn'?'up':'dn')">% ${so==="up"?"▲ LOW→HIGH":"▼ HIGH→LOW"}</a><a class="${so==="az"?"on":""}" onclick="ssSet('az')">A–Z</a>`+
      `<span class="dim"><b class="pu">▲ ${up}</b> · <b class="pd">▼ ${dn}</b> · ${R.length} sectors</span><span class="gxl" title="every share of NSE's Nifty Total Market in NSE's own sector, weighted by ${E(SL.weights)}">ALL ${SL.shares} · WEIGHTED · ${E(SL.at)}</span></div>`+
      '<div class="sbc">'+R.map(x=>{ const w=Math.max(3,Math.abs(x.chg)/mx*100); const go=(x.fos||[]).length||has(x.name)?`mkSec('${E(x.name)}')`:"";
        return `<div class="sb" ${go?`onclick="${go}"`:""} title="${E(x.name.toUpperCase())}: ${pc(x.chg)} - all its ${x.n} NSE shares, size-weighted (a plain average would say ${pc(x.eqw)}) · ${x.up} up, ${x.dn} down · ${x.fo} of them F&O${x.fo?"":" (nothing to trade here - information only)"} · best: ${E(mv(x.top))} · worst: ${E(mv(x.bot))}">`+
          `<span>${E(x.name.toUpperCase())} <span class="gxn"><b class="pu">▲${x.up}</b> <b class="pd">▼${x.dn}</b></span><span class="gxf">· ${x.fo} F&amp;O</span></span>`+
          `<span class="tr"><span class="fl ${x.chg>=0?"u":"d"}" style="width:${w.toFixed(1)}%"></span></span><b class="${x.chg>=0?"pu":"pd"}">${pc(x.chg)}</b></div>`; }).join("")+'</div>';
    const h=document.querySelector("#q-don h3 span"); if(h&&!/ALL its NSE/.test(h.textContent)) h.textContent="% today = ALL its NSE shares, size-weighted · tap = its F&O shares"; }
  function paintRot(){ const el=document.getElementById("mk-rot"); if(!el||!fresh()) return;
    const RWk=(typeof RW!=="undefined")?String(RW):"day"; const win=RWk==="day"?null:RWk;
    const thr={"day":0.8,"60":0.5,"30":0.35,"15":0.25}[RWk]||0.8;
    const G=SL.sectors.map(x=>{ const v=win?(x.rot||{})[win]:x.chg, d=win?((x.rotx||{})[win]||{}):{up:x.up,dn:x.dn,n:x.n,top:x.top,bot:x.bot};
      return {n:x.name.toUpperCase(),v,up:d.n?d.up/d.n:0,dn:d.n?d.dn/d.n:0,nn:d.n||0,nu:d.up||0,nd:d.dn||0,top:d.top||[],bot:d.bot||[],fo:x.fo,name:x.name}; }).filter(g=>g.v!=null).sort((a,b)=>b.v-a.v);
    const since=win?(SL.since||{})[win]:null;
    const tb=`<div class="rt">${[["15","15M"],["30","30M"],["60","1H"],["day","TODAY"]].map(([k,t])=>`<a class="${RWk===k?"on":""}" onclick="rwSet('${k}')">${t}</a>`).join("")}`+
      `<small>${win?(since?"since "+since:"the server has not watched "+win+" minutes yet today"):"since yesterday's close"}</small><span class="gxl">ALL ${SL.shares} NSE SHARES · SIZE-WEIGHTED · ${SL.live?"LIVE ":""}${E(SL.at)}</span></div>`;
    if(!G.length){ el.innerHTML=tb+`<div class="empty">${win?"the "+win+"-minute record starts after 09:15 + "+win+" minutes":"no prices yet"}</div>`; return; }
    const ins=G.filter(g=>g.v>=thr&&g.up>=0.7), outs=G.filter(g=>g.v<=-thr&&g.dn>=0.7).reverse();
    const f=v=>`<span class="${cl(v)}">${pc(v)}</span>`, top=G[0], bot=G[G.length-1];
    const st=(ins.length&&outs.length)?`<b class="on">🔄 ROTATION ON</b> money into <b>${ins.slice(0,3).map(g=>E(g.n)).join(" · ")}</b> ← out of <b>${outs.slice(0,3).map(g=>E(g.n)).join(" · ")}</b>`
      :`no rotation by the rule now <small class="dim">(one sector +${thr}% with 70% of its shares up while another is −${thr}% with 70% down)</small> · strongest <b>${E(top.n)}</b> ${f(top.v)} ${Math.round(top.up*100)}% up · weakest <b>${E(bot.n)}</b> ${f(bot.v)} ${Math.round(bot.dn*100)}% down`;
    const sh=L=>L.map(t=>`<a onclick="mkOpen('${E(t[0])}')">${E(t[0])} ${f(t[1])}${t[2]?"<i>F&amp;O</i>":""}</a>`).join(" ");
    const row=(g,side)=>`<div class="rg" title="${E(g.n)}: ${g.nu} of ${g.nn} shares up, ${g.nd} down · all its NSE shares, size-weighted"><span class="nm">${E(g.n)}</span>${f(g.v)}<small>${side>0?g.nu:g.nd} of ${g.nn} ${side>0?"up":"down"}</small><small class="ix">${g.fo} F&amp;O</small>`+
      `<span class="sh">${side>0?"leading: "+sh(g.top.filter(t=>t[1]>0)):"weakest: "+sh(g.bot.filter(t=>t[1]<0))}</span></div>`;
    const L=G.filter(g=>g.v>0), S=G.filter(g=>g.v<0).reverse();
    el.innerHTML=tb+`<div class="rs">${st}</div><div class="rc"><div><h4 class="pu">▲ MONEY GOING IN ${win?"(last "+win+" min)":"(today)"}</h4>${L.slice(0,8).map(g=>row(g,1)).join("")||'<small class="dim">none up</small>'}</div>`+
      `<div><h4 class="pd">▼ MONEY GOING OUT ${win?"(last "+win+" min)":"(today)"}</h4>${S.slice(0,8).map(g=>row(g,-1)).join("")||'<small class="dim">none down</small>'}</div></div>`+
      `<div class="ra">every share of NSE's Nifty Total Market (${SL.shares}) in NSE's own sector, weighted by ${E(SL.weights)} · the server keeps the minute-by-minute record, so the laptop, the iPad and the phone show the same</div>`; }
  function paint(){ try{ if(typeof VIEW!=="undefined"&&VIEW!=="market") return; paintSec(); paintRot(); }catch(e){} }
  if(typeof drawMarket==="function"){ const O=drawMarket; drawMarket=function(){ regroup(); const r=O.apply(this,arguments); rechg(); paint(); return r; };
    Object.keys(O).forEach(k=>{ try{ drawMarket[k]=O[k]; }catch(e){} }); Object.defineProperty(drawMarket,"force",{get(){ return O.force; },set(v){ O.force=v; }}); }
  if(typeof drawSecs==="function"&&typeof secHTML==="function"){ const O=drawSecs; drawSecs=function(){ regroup(); const r=O.apply(this,arguments);
      try{ if(fresh()){ rechg(); const g=document.getElementById("secg"); if(g) g.innerHTML=secHTML(SECS); } }catch(e){} return r; }; }
  if(typeof drawRot==="function"){ const O=drawRot; drawRot=function(){ const r=O.apply(this,arguments); try{ paintRot(); }catch(e){} return r; }; }
  setInterval(()=>{ if(!document.hidden&&typeof VIEW!=="undefined"&&VIEW==="market") pull(); },2000);
  setTimeout(pull,800); })();
</script>
ADD_354
python3 -m py_compile $W/seclive.py || { echo "❌ did not compile - nothing changed"; exit 1; }
cp $W/seclive.py $D/seclive.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 354" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/seclive":                  # patch 354: the sectors from ALL their NSE shares, size-weighted (read only)
                try:
                    v_ = json.load(open(os.path.join(BASE, "data", "seclive.json")))
                except Exception:
                    v_ = {"sectors": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /seclive")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 354" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: SECTORS + ROTATION read /seclive")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
echo "=== one pass now: every NSE share, NSE's sizes, Kite's prices (about 30 s)"
bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd /home/globalbot/intraday && timeout 180 python3 seclive.py once' 2>&1 | cut -c1-190
[ -s $D/data/seclive.json ] || { echo "❌ seclive.py wrote nothing - see the lines above"; back; }
cat > /etc/systemd/system/gir-seclive.service <<'UNIT'
[Unit]
Description=GIR sectors from all their NSE shares, size-weighted, live (patch 354)
After=network-online.target gir-dash.service
[Service]
Type=simple
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd /home/globalbot/intraday && exec python3 -u seclive.py >> data/seclive.log 2>&1'
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-seclive >/dev/null 2>&1 || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-seclive: $(systemctl is-active gir-seclive)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-seclive)" = "active" ] || back
echo "✅ patch 354 done - refresh GIR (Ctrl+Shift+R): SECTORS and ROTATION now come from ALL the sector's NSE shares, size-weighted."
echo "   undo: systemctl disable --now gir-seclive; rm /etc/systemd/system/gir-seclive.service; for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
