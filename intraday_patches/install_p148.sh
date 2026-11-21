#!/bin/bash
# PATCH 148 - ONE SCREEN + FII / DII BY SHARE. A laptop: the market page fills the window - no page scroll, each panel scrolls inside:
#   ⚡ EARLY · the F&O DESK strip · F&O MOVERS | NIFTY/BANKNIFTY chart | SECTORS | F&O MONEY | NEWS (tall) / options desk | ROTATION |
#   🏦 FII · DII BY SHARE. FII / DII by share: NSE's bulk + block deals with the parties named - FII buying / selling, DII buying /
#   selling per F&O share, ₹ crore, last day / 5 / 30 days, who. instflow.py (new) · dashserve.py · home.html (needs 147).
#   Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g148; mkdir -p $W
grep -q "patch 148" $D/home.html && { echo "patch 148 is already installed"; exit 1; }
grep -q "patch 147" $D/home.html || { echo "patch 147 is not installed yet - install it first"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back() { for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/instflow.py $D/p148test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p148_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p148_patch.py - PATCH 148: ONE SCREEN, AND WHERE FII / DII MONEY GOES (Rama, 9 Nov: "worst design - I need to scroll to see the news;
think as an F&O trader, a Bloomberg owner"; "FII investing in which F&O share, DII where, FII leaving, DII leaving").
A laptop: the market page fills the window exactly - no page scroll; each panel scrolls inside itself.
  row 1  ⚡ EARLY (one line after the close)          row 2  F&O DESK as one strip (expiry · PCR · VIX · FII / DII · ban · results;
  rows 3-4  F&O MOVERS (both rows) · NIFTY / BANKNIFTY chart · SECTORS · F&O MONEY · NEWS / OI SCENARIOS (both rows)
            · the options desk · 🔄 ROTATION · 🏦 FII · DII BY SHARE           (OI BUILD-UP BY SECTOR and SECTORS THROUGH THE DAY off -
            F&O MONEY, SECTORS and ROTATION carry the same)
🏦 FII · DII BY SHARE (instflow.py): NSE's bulk + block deals with the parties named - FII buying / selling, DII buying / selling
per F&O share, ₹ crore, last day / 5 days / 30 days, who; the cash-market totals under it. Tap a share = its screen.
Usage: python3 p148_patch.py /home/globalbot/intraday  (needs 147)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
SRV = [
    ('''"fii_nse": _fii_nse(),''', '''"fii_nse": _fii_nse(), "inst": _inst(),'''),
    ('''\n\ndef home_refresher():''', '''

def _inst():
    """patch 148: FII / DII by share (instflow.py) - reads its files only"""
    try:
        import instflow
        return instflow.summary()
    except Exception:
        return {}


def home_refresher():'''),
    ('''        try:
            ix_tick()''', '''        try:
            import instflow; instflow.tick()                      # patch 148: NSE's bulk / block deals - FII / DII by share (its own thread)
        except Exception as ex:
            print("instflow:", str(ex)[:80])
        try:
            ix_tick()'''),
]
JS = r'''/* patch 148: 🏦 FII · DII BY SHARE + the one-screen layout */
let INSW="1"; try{ INSW=localStorage.getItem("gir_insw")||"1"; }catch(e){}
function insW(w){ INSW=w; try{ localStorage.setItem("gir_insw",w); }catch(e){} drawIns(); }
function drawIns(){ const el=$("mk-ins"); if(!el) return; const I=(MK&&MK.inst)||{}; const W=(I.w||{})[INSW]||{};
  const tabs=`<span class="ntf">${[["1","LAST DAY"],["5","5 DAYS"],["30","30 DAYS"]].map(([k,l])=>`<a class="${INSW===k?"on":""}" onclick="insW('${k}')">${l}</a>`).join("")}</span>`;
  const cr=v=>`₹${Math.abs(v).toLocaleString("en-IN",{maximumFractionDigits:1})} cr`;
  const col=(k,t,c)=>`<div><h4 class="${c}">${t}</h4>${(W[k]||[]).length?(W[k]||[]).slice(0,8).map(x=>`<div class="k ir" onclick="mkOpen('${esc(x.s)}')" title="${esc(x.who)} · ${x.n} deal(s) · bought ₹${x.buy} cr · sold ₹${x.sell} cr"><b>${esc(x.s)}</b><span class="${c}">${cr(x.cr)}</span><small>${esc(x.who)}</small></div>`).join(""):'<div class="dim">none</div>'}</div>`;
  const C=(((MK&&MK.fii_nse)||{}).cash)||{};
  MKH("mk-ins").innerHTML=`<div class="ih">${tabs}<span class="dim">${W.from?esc(W.from)+(W.to&&W.to!==W.from?" → "+esc(W.to):""):"no deals read yet (NSE's files, after the close)"}</span></div>
    <div class="ig">${col("fii_buy","FII BUYING ▲","pu")}${col("fii_sell","FII SELLING ▼","pd")}${col("dii_buy","DII BUYING ▲","pu")}${col("dii_sell","DII SELLING ▼","pd")}</div>
    <div class="ifo">${C.FII!=null?`all shares, cash market ${esc(C.date||"")}: FII <b class="${C.FII>0?"pu":"pd"}">${C.FII>0?"+":"−"}${cr(C.FII)}</b> · DII <b class="${C.DII>0?"pu":"pd"}">${C.DII>0?"+":"−"}${cr(C.DII)}</b><br>`:""}per share: the bulk / block deals NSE names (0.5%+ of a company in a day, or the block window) - most institutional trades are not named</div>`; }
function mkFit(){ const m=$("mk"); if(!m) return; if(window.innerWidth<1100||typeof VIEW==="undefined"||VIEW!=="market"){ m.style.removeProperty("height"); return; }
  const t=m.getBoundingClientRect().top+window.scrollY, tk=$("tick"); m.style.setProperty("height",Math.max(520,window.innerHeight-t-(tk?tk.offsetHeight:30)-2)+"px","important"); }
window.addEventListener("resize",mkFit); setInterval(mkFit,2000);
document.addEventListener("click",e=>{ if(e.target&&e.target.closest&&e.target.closest("#mk-dsk em, #mk-dsk.dsk0")) document.body.classList.toggle("dskopen"); });
'''
CSS = '''/* patch 148: ONE SCREEN on a laptop - no page scroll, each panel scrolls inside */
@media(min-width:1100px){
  #mk{grid-template-columns:1.05fr 1.55fr 1fr 1.15fr 1.15fr !important;grid-template-rows:auto auto minmax(0,1fr) minmax(0,1fr) !important;
      grid-template-areas:"ear ear ear ear ear" "dsk dsk dsk dsk dsk" "mov nif don mon nws" "mov idx rot ins nws" !important;overflow:hidden}
  #q-hea,#q-bus{display:none !important}
  #mk .q{height:auto !important;min-height:0}
  #q-ear .bd{max-height:16vh !important}body.earopen #q-ear .bd{max-height:45vh !important}
  #mk #q-dsk>h3{display:none !important}#q-dsk{grid-area:dsk}
  #mk-dsk{display:flex;flex-wrap:nowrap;overflow-x:auto;overflow-y:hidden}
  #mk-dsk::before{content:"F&O DESK · tap a label = open";color:var(--amber);font-weight:700;padding:3px 10px;white-space:nowrap;flex:none}
  #mk-dsk>div{flex:none;white-space:nowrap;border-bottom:0 !important;border-right:1px solid var(--line);padding:3px 10px !important}
  #mk-dsk br{display:none}#mk-dsk em{width:auto !important;margin-right:6px;cursor:pointer}#mk-dsk svg{display:none}
  body.dskopen #mk-dsk{flex-wrap:wrap;overflow:visible}body.dskopen #mk-dsk>div{white-space:normal;flex:1 1 320px}body.dskopen #mk-dsk br{display:inline}body.dskopen #mk-dsk svg{display:inline}
  #q-rot .rc{grid-template-columns:1fr}#q-rot .rg{grid-template-columns:1fr auto auto}#q-rot .rg .ix{display:none}#q-rot .rg .sh{grid-column:1/-1}
}
#q-ins{grid-area:ins}
#mk-ins .ih{display:flex;gap:8px;align-items:center;padding:3px 6px;flex-wrap:wrap;font-size:10px}#mk-ins .ntf{float:none}
#mk-ins .ig{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:var(--line)}#mk-ins .ig>div{background:var(--panel);padding:3px 6px;min-width:0}
#mk-ins h4{font-size:10px;letter-spacing:.06em;margin:2px 0}
#mk-ins .ir{display:grid;grid-template-columns:1fr auto;gap:0 6px;padding:2px 0;border-bottom:1px solid #10151d;cursor:pointer}
#mk-ins .ir small{grid-column:1/-1;color:var(--dim);font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#mk-ins .ifo{padding:3px 6px;font-size:10px;color:var(--dim);border-top:1px solid var(--line)}
#focus table.oi{width:100%;'''
PAGE = [
    ('''    <div class="q" id="q-rot">''', '''    <div class="q" id="q-ins"><h3>🏦 FII · DII BY SHARE <span>where the institutions bought and sold · tap = its screen</span></h3><div class="bd" id="mk-ins"></div></div>
    <div class="q" id="q-rot">'''),
    ('''  drawRot();   // patch 145c''', '''  drawRot(); drawIns(); mkFit();   // patch 145c · 148'''),
    ('''function MKH(id){''', JS + '''function MKH(id){'''),
    ('''#focus table.oi{width:100%;''', CSS),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 148" in s:
        print("patch 148 is already in %s" % os.path.basename(p)); return None
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), os.path.basename(p), a[:90].replace("\n", " | "))); return None
        s = s.replace(a, b)
    return s


a = apply(os.path.join(D, "dashserve.py"), SRV)
b = apply(os.path.join(D, "home.html"), PAGE)
if a is None or b is None:
    sys.exit(1)
open(os.path.join(D, "dashserve.py"), "w", encoding="utf-8").write(a)
open(os.path.join(D, "home.html"), "w", encoding="utf-8").write(b)
print("patched: dashserve.py, home.html")
PY_PATCH
cat > $D/instflow.py <<'PY_IF'
#!/usr/bin/env python3
"""instflow.py - patch 148: WHERE FII AND DII MONEY GOES, SHARE BY SHARE (Rama, 9 Nov: "FII investing in which F&O share, DII where,
FII leaving, DII leaving - critical for F&O trading"). NSE publishes no per-share FII / DII figure every day; what it does publish,
every day, is every BULK and BLOCK deal with the buyer's and the seller's NAME. This reads them, names each party:
  FII   foreign portfolio investors - Morgan Stanley, Goldman Sachs, Societe Generale, BNP, Citi, JP Morgan, Nomura, UBS, Vanguard,
        BlackRock, Singapore / Abu Dhabi / Norway funds, "... FUND", "... PTE", "(MAURITIUS)", "FPI", "ODI" ...
  DII   Indian institutions - mutual funds, LIC and the insurers, pension / provident funds, banks' treasuries
  other everyone else (promoters, HNIs, trading firms) - shown apart, never counted as FII / DII
and adds them up per F&O share: today, 5 days, 30 days - FII buying / selling, DII buying / selling, ₹ crore and the deals.
Only deals NSE reports (0.5%+ of a company's shares in a day, or the block window) - most institutional trades are not named.
Files: data/instdeals/<day>.json (one per trading day, 30 days back filled once from NSE's history).
  python3 instflow.py            the summary now        python3 instflow.py refresh    read NSE now"""
import os, re, sys, csv, io, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
DIR = os.path.join(BASE, "data", "instdeals")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
FII_RX = re.compile(r"\bFPI\b|\bODI\b|MORGAN STANLEY|GOLDMAN SACHS|SOCIETE GENERALE|BNP PARIBAS|CITIGROUP|CITIBANK|J\.?\s?P\.?\s?MORGAN|MERRILL|BOFA|"
                    r"NOMURA|\bUBS\b|\bCLSA\b|BARCLAYS|HSBC GLOBAL|VANGUARD|BLACKROCK|ISHARES|GOVERNMENT OF SINGAPORE|MONETARY AUTHORITY|ABU DHABI|"
                    r"NORGES|COPTHALL|MAURITIUS|\bPTE\b|CAYMAN|LUXEMBOURG|\bSICAV\b|\bLLC\b|\bL\.?P\.?\b|EMERGING MARKETS|DEUTSCHE BANK|"
                    r"CREDIT SUISSE|MACQUARIE|FIDELITY|FRANKLIN TEMPLETON INVESTMENT FUNDS|ABERDEEN|SCHRODER|INVESCO|WELLINGTON|T\.?\s?ROWE|"
                    r"CAPITAL GROUP|NEW WORLD FUND|SMALLCAP WORLD|GQG|JUPITER|PLUTUS|INTEGRATED CORE|VIRTU|ELARA INDIA OPPORTUNITIES|"
                    r"INDIA OPPORTUNITIES FUND|ASIA (?:PACIFIC|EQUITY)|GLOBAL (?:FUND|EQUITY|OPPORTUNIT)|INTERNATIONAL FUND|OPPORTUNITIES FUND LTD", re.I)
DII_RX = re.compile(r"MUTUAL FUND|\bMF\b|LIFE INSURANCE|GENERAL INSURANCE|INSURANCE (?:CO|COMPANY|CORPORATION)|\bLIC\b|PENSION|PROVIDENT|"
                    r"EMPLOYEES'? STATE|NPS TRUST|ASSET MANAGEMENT|AMC\b|TRUSTEE|SBI LIFE|HDFC LIFE|ICICI PRUDENTIAL|NIPPON INDIA|"
                    r"KOTAK MAHINDRA (?:MUTUAL|LIFE)|ADITYA BIRLA SUN LIFE|AXIS MUTUAL|DSP |UTI |MIRAE ASSET|TATA (?:MUTUAL|AIA)|"
                    r"BAJAJ (?:ALLIANZ|FINSERV MUTUAL)|MOTILAL OSWAL MUTUAL|EDELWEISS MUTUAL|QUANT MUTUAL|PPFAS|CANARA ROBECO|"
                    r"FRANKLIN TEMPLETON MUTUAL|INVESCO MUTUAL|SUNDARAM MUTUAL|BANDHAN MUTUAL|HSBC MUTUAL|BANK OF BARODA|STATE BANK OF INDIA", re.I)


def classify(name):
    n = str(name or "")
    if re.search(r"MUTUAL FUND|\bMF\b|INSURANCE|PENSION|PROVIDENT|TRUSTEE", n, re.I):
        return "DII"                                             # an Indian fund house's foreign-sounding scheme name is still a DII
    if FII_RX.search(n):
        return "FII"
    if DII_RX.search(n):
        return "DII"
    return "other"


def fo_set():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        v = {r[0] for r in c.execute("select sym from fo_list")}
        c.close()
        return v
    except Exception:
        return set()


def _rows_csv(text, kind):
    import fast
    out = []
    for sym, (net, lst) in fast.parse_deals(text, kind).items():
        for cli, side, q, p, k in lst:
            out.append({"s": sym, "who": cli, "side": side, "q": q, "p": p, "kind": k, "cls": classify(cli)})
    return out


def _rows_hist(data, kind):
    """NSE's historical bulk / block deals (JSON) -> {day: [rows]}; tolerant of the field names"""
    out = {}
    for e in (data.get("data") if isinstance(data, dict) else data) or []:
        if not isinstance(e, dict):
            continue
        k = {re.sub(r"[^a-z]", "", str(a).lower()): v for a, v in e.items()}
        g = lambda *ns: next((k[x] for x in k for n in ns if n in x), None)
        sym, cli, bs = g("symbol"), g("clientname", "client"), str(g("buysell", "buy") or "").upper()
        try:
            q = float(str(g("qtytrd", "quantity", "qty") or 0).replace(",", ""))
            p = float(str(g("watp", "price", "tp") or 0).replace(",", ""))
            d = dt.datetime.strptime(str(g("dtdate", "date") or "")[:11], "%d-%b-%Y").date()
        except Exception:
            continue
        if sym and bs in ("BUY", "SELL") and q > 0:
            out.setdefault(str(d), []).append({"s": str(sym).upper(), "who": str(cli or "?")[:60], "side": bs, "q": q, "p": p, "kind": kind, "cls": classify(cli)})
    return out


def save(day, rows):
    os.makedirs(DIR, exist_ok=True)
    json.dump({"day": day, "at": time.time(), "rows": rows}, open(os.path.join(DIR, day + ".json.tmp"), "w"))
    os.replace(os.path.join(DIR, day + ".json.tmp"), os.path.join(DIR, day + ".json"))


def refresh(get=None, hist=None, now=None):
    """today's bulk + block files (after the close) and, once, 30 days of NSE's history. -> rows saved today"""
    now = now or dt.datetime.now(IST)
    import fast
    get = get or (lambda u: fast._get(u))
    rows = []
    for u in fast.DEAL_URLS:
        try:
            rows += _rows_csv(get(u), "block" if "block" in u else "bulk")
        except Exception as ex:
            print("instflow %s: %s" % (u[-9:], str(ex)[:80]))
    day = None
    if rows:
        day = str(now.date()) if now.weekday() < 5 and now.strftime("%H:%M") >= "15:30" else None
        if day is None:                                          # before the close the files hold the last session's deals
            d = now.date() - dt.timedelta(days=1)
            while d.weekday() > 4:
                d -= dt.timedelta(days=1)
            day = str(d)
        save(day, rows)
    mark = os.path.join(DIR, ".backfilled")
    if not os.path.exists(mark):
        try:
            if hist is None:
                import exchange
                hist = exchange.nse_json
            fr, to = (now.date() - dt.timedelta(days=35)).strftime("%d-%m-%Y"), now.date().strftime("%d-%m-%Y")
            got = {}
            for kind in ("bulk", "block"):
                for d, rr in _rows_hist(hist("/api/historical/%s-deals?from=%s&to=%s" % (kind, fr, to)) or {}, kind).items():
                    got.setdefault(d, []).extend(rr)
            for d, rr in got.items():
                if d != day and not os.path.exists(os.path.join(DIR, d + ".json")):
                    save(d, rr)
            if got:
                os.makedirs(DIR, exist_ok=True)
                open(mark, "w").write(str(len(got)))
        except Exception as ex:
            print("instflow history: %s" % str(ex)[:100])
    return len(rows)


_S = {"t": 0.0, "v": None, "busy": False, "ran": 0.0}


def tick():
    """the page server's refresher: read NSE in a thread every 30 min from 15:45 to 21:00 and once after a start"""
    now = dt.datetime.now(IST)
    due = (_S["ran"] == 0.0) or (now.weekday() < 5 and "15:45" <= now.strftime("%H:%M") <= "21:00" and time.time() - _S["ran"] > 1800)
    if due and not _S["busy"]:
        _S["busy"], _S["ran"] = True, time.time()
        import threading

        def run():
            try:
                refresh()
                _S["t"] = 0.0
            finally:
                _S["busy"] = False
        threading.Thread(target=run, daemon=True).start()


def summary(now=None):
    """-> {"days": [...], "w": {"1": {...}, "5": {...}, "30": {...}}} each window: fii_buy / fii_sell / dii_buy / dii_sell lists
    [{"s", "cr", "n", "who"}] for F&O shares, + totals. Cached 60 s."""
    if now is None and _S["v"] is not None and time.time() - _S["t"] < 60:
        return _S["v"]
    fo = fo_set()
    files = sorted(f for f in (os.listdir(DIR) if os.path.isdir(DIR) else []) if f.endswith(".json"))[-30:]
    days = [f[:-5] for f in files]
    data = {}
    for f in files:
        try:
            data[f[:-5]] = json.load(open(os.path.join(DIR, f))).get("rows") or []
        except Exception:
            pass
    out = {"days": days, "w": {}}
    for w in (1, 5, 30):
        dd = days[-w:]
        agg = {}
        for d in dd:
            for r in data.get(d, []):
                if r["cls"] == "other" or (fo and r["s"] not in fo):
                    continue
                key = (r["s"], r["cls"])
                a = agg.setdefault(key, {"buy": 0.0, "sell": 0.0, "n": 0, "who": {}})
                v = r["q"] * r["p"] / 1e7
                a["buy" if r["side"] == "BUY" else "sell"] += v
                a["n"] += 1
                a["who"][r["who"]] = a["who"].get(r["who"], 0.0) + (v if r["side"] == "BUY" else -v)
        W = {}
        for cls in ("FII", "DII"):
            net = [(s, a["buy"] - a["sell"], a) for (s, c), a in agg.items() if c == cls]
            fmt = lambda s, n, a: {"s": s, "cr": round(n, 1), "buy": round(a["buy"], 1), "sell": round(a["sell"], 1), "n": a["n"],
                                   "who": max(a["who"].items(), key=lambda kv: abs(kv[1]))[0][:34] if a["who"] else ""}
            W[cls.lower() + "_buy"] = [fmt(*x) for x in sorted([x for x in net if x[1] > 0], key=lambda x: -x[1])[:12]]
            W[cls.lower() + "_sell"] = [fmt(*x) for x in sorted([x for x in net if x[1] < 0], key=lambda x: x[1])[:12]]
            W[cls.lower() + "_net"] = round(sum(x[1] for x in net), 1)
        W["from"], W["to"] = (dd[0] if dd else None), (dd[-1] if dd else None)
        out["w"][str(w)] = W
    if now is None:
        _S.update({"t": time.time(), "v": out})
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "refresh":
        print("rows read: %s" % refresh())
    v = summary(now=dt.datetime.now(IST))
    for w in ("1", "5", "30"):
        W = v["w"].get(w) or {}
        print("== %s day(s) %s..%s · FII net ₹%s cr · DII net ₹%s cr" % (w, W.get("from"), W.get("to"), W.get("fii_net"), W.get("dii_net")))
        for k in ("fii_buy", "fii_sell", "dii_buy", "dii_sell"):
            print("  %-9s %s" % (k, " · ".join("%s ₹%s cr (%s)" % (x["s"], x["cr"], x["who"]) for x in W.get(k) or [])))
PY_IF
cat > $D/p148test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p148test.py - patch 148: FII / DII by share from NSE's bulk + block deals (made-up files, no network)"""
import os, sys, json, tempfile, shutil, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import instflow as I
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
for name, want in (("MORGAN STANLEY ASIA (SINGAPORE) PTE.", "FII"), ("SOCIETE GENERALE - ODI", "FII"), ("GOLDMAN SACHS (SINGAPORE) PTE", "FII"),
                   ("HDFC MUTUAL FUND", "DII"), ("SBI MUTUAL FUND", "DII"), ("LIFE INSURANCE CORPORATION OF INDIA", "DII"), ("ICICI PRUDENTIAL LIFE INSURANCE", "DII"),
                   ("NIPPON INDIA MUTUAL FUND A/C NIPPON INDIA SMALL CAP", "DII"), ("RAKESH KUMAR", "other"), ("GRAVITON RESEARCH CAPITAL LLP", "other"), ("ABC PROMOTER PVT LTD", "other")):
    check("%s -> %s" % (name, want), I.classify(name) == want)
T = tempfile.mkdtemp(); I.BASE = T; I.DIR = os.path.join(T, "data", "instdeals")
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,?)", [("HINDALCO", 1), ("PNB", 1), ("TCS", 1)]); c.commit(); c.close()
BULK = """Date,Symbol,Security Name,Client Name,Buy/Sell,Quantity Traded,Trade Price / Wght. Avg. Price,Remarks
09-NOV-2026,HINDALCO,Hindalco,MORGAN STANLEY ASIA (SINGAPORE) PTE.,BUY,3000000,960.5,-
09-NOV-2026,HINDALCO,Hindalco,SBI MUTUAL FUND,SELL,1000000,961.0,-
09-NOV-2026,PNB,PNB,LIFE INSURANCE CORPORATION OF INDIA,BUY,20000000,127.0,-
09-NOV-2026,TCS,TCS,GOLDMAN SACHS (SINGAPORE) PTE,SELL,500000,3000,-
09-NOV-2026,SMALLCO,Small,MORGAN STANLEY ASIA (SINGAPORE) PTE.,BUY,100,10,-
09-NOV-2026,PNB,PNB,RAKESH KUMAR,SELL,100000,127,-
"""
HIST = {"data": [{"BD_DT_DATE": "06-NOV-2026", "BD_SYMBOL": "PNB", "BD_CLIENT_NAME": "HDFC MUTUAL FUND", "BD_BUY_SELL": "BUY", "BD_QTY_TRD": 10000000, "BD_TP_WATP": 120.0}]}
n = I.refresh(get=lambda u: BULK if "bulk" in u else "Date,Symbol,Client Name,Buy/Sell,Quantity Traded,Trade Price\n", hist=lambda p: HIST if "bulk" in p else {}, now=dt.datetime(2026, 11, 9, 18, 0, tzinfo=I.IST))
check("6 rows read, saved for 09 Nov; 06 Nov from NSE's history", n == 6 and os.path.exists(os.path.join(I.DIR, "2026-11-09.json")) and os.path.exists(os.path.join(I.DIR, "2026-11-06.json")))
v = I.summary(now=dt.datetime(2026, 11, 9, 18, 0, tzinfo=I.IST))
W1, W5 = v["w"]["1"], v["w"]["5"]
print(json.dumps(W1, indent=None)[:600])
check("today FII buying: HINDALCO ₹288.1 cr (Morgan Stanley)", W1["fii_buy"] and W1["fii_buy"][0]["s"] == "HINDALCO" and W1["fii_buy"][0]["cr"] == 288.1 and "MORGAN" in W1["fii_buy"][0]["who"])
check("today FII selling: TCS ₹-150 cr; DII buying PNB ₹254 cr (LIC), DII selling HINDALCO ₹-96.1 cr", W1["fii_sell"][0]["s"] == "TCS" and W1["fii_sell"][0]["cr"] == -150.0 and W1["dii_buy"][0]["s"] == "PNB" and W1["dii_buy"][0]["cr"] == 254.0 and W1["dii_sell"][0]["s"] == "HINDALCO")
check("5 days: DII PNB adds HDFC MF's ₹120 cr (= ₹374 cr); the non-F&O share and the individual left out", W5["dii_buy"][0]["cr"] == 374.0 and all(x["s"] != "SMALLCO" for x in W5["fii_buy"]))
shutil.rmtree(T)
print("P148 FII / DII TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p148_patch.py $D || { rm -f $D/instflow.py $D/p148test.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py instflow.py p148test.py || back
for t in p148test.py p146etest.py p146btest.py p145etest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep FAIL | head -3; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    reading NSE's bulk / block deals (up to 2 min)..."
( cd /home/globalbot && set -a && source .env && set +a && cd $D && timeout 150 python3 instflow.py refresh ) 2>&1 | head -24
echo
echo "PATCH 148 APPLIED. Reload the GIR page (Ctrl+F5) on the laptop: one screen, no scrolling; 🏦 FII · DII BY SHARE at the bottom."
