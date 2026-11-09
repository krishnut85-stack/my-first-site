#!/bin/bash
# PATCH 149 - 🏦 BIG MONEY · F&O SHARES + THE INDEX CHART'S FIT. The institutions' daily footprint in each F&O share is its DELIVERY (NSE's
#   file every evening): ▲ BIG HANDS BUYING = price up + delivery 1.5x+ its 20-day normal · ▼ BIG HANDS SELLING = price down, the same,
#   ranked by ₹ crore delivered above normal; named FII / DII deals in F&O shares when there are any; FII / DII cash and stock futures.
#   The NIFTY / BANKNIFTY chart: one compact toolbar, the candles kept above the breadth bars, a one-line legend.
#   instflow.py (replaced) · home.html (needs 148). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g149; mkdir -p $W
grep -q "patch 149" $D/home.html && { echo "patch 149 is already installed"; exit 1; }
grep -q "patch 148" $D/home.html || { echo "patch 148 is not installed yet - install it first"; exit 1; }
for f in home.html instflow.py; do cp $D/$f $D/$f.bak$TS; done
back() { for f in home.html instflow.py; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p149test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p149_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p149_patch.py - PATCH 149: 🏦 BIG MONEY · F&O SHARES (Rama: "not thinking like a pro trader"). The named bulk / block deals are
almost never in F&O shares (9 Nov: 78 deals, 2 in F&O, both a trading firm). The institutions' daily footprint in an F&O share is its
DELIVERY - shares taken home, not traded away the same day (NSE's sec_bhavdata_full, every evening):
  ▲ BIG HANDS BUYING   price up and the delivered quantity 1.5x+ its 20-day normal (delivery % at least normal)
  ▼ BIG HANDS SELLING  price down, the same
  ranked by the ₹ crore delivered above normal; the named FII / DII deals in F&O shares when there are any; FII / DII cash and the
  FIIs' stock futures under it. F&O shares only. instflow.py (replaced) · home.html (needs 148).
Usage: python3 p149_patch.py /home/globalbot/intraday"""
import sys, os, re

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
NEW = r'''function drawIns(){ const el=$("mk-ins"); if(!el) return; const I=(MK&&MK.inst)||{}; const DL=I.deliv||{}; const W=(I.w||{})["1"]||{};   /* patch 149 */
  const cr=v=>`₹${Math.abs(v).toLocaleString("en-IN",{maximumFractionDigits:1})} cr`;
  const dl=(L,c)=>(L||[]).length?(L||[]).slice(0,10).map(x=>`<div class="k ir" onclick="mkOpen('${esc(x.s)}')" title="delivered ${cr(x.cr)} · ${x.x}x its 20-day normal · ${x.dp}% of the volume taken into delivery (normal ${x.avg_dp}%)"><b>${esc(x.s)}</b><span class="${c}">${x.chg>0?"+":""}${x.chg.toFixed(2)}%</span><small>${cr(x.extra)} above normal · ${x.x}× · ${x.dp}% delivery</small></div>`).join(""):'<div class="dim">none</div>';
  const named=["fii_buy","fii_sell","dii_buy","dii_sell"].flatMap(k=>(W[k]||[]).map(x=>Object.assign({k},x)));
  const N=(MK&&MK.fii_nse)||{}, C=N.cash||{}, F=N.fo||{};
  MKH("mk-ins").innerHTML=`<div class="ih"><span class="dim">${DL.day?"NSE's delivery file "+esc(DL.day)+" · "+(DL.n||0)+" F&amp;O shares · each vs its own 20-day normal":"NSE's delivery file comes each evening (~18:00)"}</span></div>
    <div class="ig"><div><h4 class="pu">▲ BIG HANDS BUYING</h4><small class="dim">price up · delivery 1.5×+ normal</small>${dl(DL.acc,"pu")}</div><div><h4 class="pd">▼ BIG HANDS SELLING</h4><small class="dim">price down · delivery 1.5×+ normal</small>${dl(DL.dist,"pd")}</div></div>
    <div class="ifo">${named.length?`<b>named FII / DII deals in F&amp;O shares ${esc(W.from||"")}:</b> `+named.map(x=>`<span class="k" onclick="mkOpen('${esc(x.s)}')"><b class="${/buy/.test(x.k)?"pu":"pd"}">${x.k.slice(0,3).toUpperCase()} ${/buy/.test(x.k)?"BUY":"SELL"}</b> ${esc(x.s)} ${cr(x.cr)} <span class="dim">${esc(x.who)}</span></span>`).join(" · ")+"<br>":"named FII / DII deals in F&amp;O shares: none on the last day<br>"}${C.FII!=null?`all shares, cash ${esc(C.date||"")}: FII <b class="${C.FII>0?"pu":"pd"}">${C.FII>0?"+":"−"}${cr(C.FII)}</b> · DII <b class="${C.DII>0?"pu":"pd"}">${C.DII>0?"+":"−"}${cr(C.DII)}</b>`:""}${F.stk_fut?` · FII stock futures net <b class="${F.stk_fut.net>0?"pu":"pd"}">${F.stk_fut.net>0?"+":""}${Math.round(F.stk_fut.net).toLocaleString("en-IN")}</b> contracts`:""}</div>`; }
'''
p = os.path.join(D, "home.html")
s = open(p, encoding="utf-8").read()
if "patch 149" in s:
    print("patch 149 is already in home.html"); sys.exit(1)
a, b = s.find("function drawIns(){"), s.find("function mkFit(){")
if s.count("function drawIns(){") != 1 or not (0 < a < b):
    print("ANCHOR: drawIns not found once"); sys.exit(1)
s = s[:a] + NEW + s[b:]
h_old = '''<h3>🏦 FII · DII BY SHARE <span>where the institutions bought and sold · tap = its screen</span></h3>'''
if s.count(h_old) != 1:
    print("ANCHOR: the panel title"); sys.exit(1)
s = s.replace(h_old, '''<h3>🏦 BIG MONEY · F&amp;O SHARES <span>the institutions' footprint - delivery vs normal · named deals · tap = its screen</span></h3>''')
CHART = [   # the index chart (patch 147): one toolbar row, the candles kept above the breadth bars, a one-line legend
    ('''[["ema9","EMA 9"],["ema21","EMA 21"],["bb","BOLL"],["prev","PREV CLOSE"],["walls","FLOOR / CEILING","the option writers' walls - the options desk"],["br","BREADTH","F&O shares up minus down, every 5 min (5m, today)"]]''',
     '''[["ema9","EMA9"],["ema21","EMA21"],["bb","BB"],["prev","PREV","the previous close"],["walls","WALLS","FLOOR / CEILING - the option writers' walls (the options desk)"],["br","BREADTH","F&O shares up minus down, every 5 min (5m, today)"]]'''),
    ('''${b(IXP.type==="candle","CANDLES","ixSet('type','candle')")}''', '''${b(IXP.type==="candle","CANDLE","ixSet('type','candle')")}'''),
    ('''${b(IXTOOL==="h","─ LINE","ixTool()","click the chart to place a line")}${b(false,"✕","ixDrawSave([])","remove your lines")}${b(false,"⟲ FIT","IXC&&IXC.main.timeScale().fitContent()")}''',
     '''${b(IXTOOL==="h","─","ixTool()","draw a line: click the chart")}${b(false,"✕","ixDrawSave([])","remove your lines")}${b(false,"FIT","IXC&&IXC.main.timeScale().fitContent()")}'''),
    ('''  IXC.tb.innerHTML=ixToolbar();
  main.subscribeCrosshairMove''', '''  IXC.tb.innerHTML=ixToolbar(); el.querySelector(".pmain").style.height=Math.max(140,H-IXC.tb.offsetHeight-2)+"px";   /* patch 149: the toolbar's real height */
  main.subscribeCrosshairMove'''),
    ('''IXC.s=s;''', '''IXC.s=s; s.priceScale().applyOptions({scaleMargins:{top:0.1,bottom:(IXP.br&&IXP.tf==="5")?0.27:0.08}});   /* patch 149: the candles above the breadth bars */'''),
    ('''#focus table.oi{width:100%;''', '''#mk-nif .ixw .ptb{gap:2px 6px;padding:2px 4px;flex-wrap:wrap}#mk-nif .ixw .ptb a{padding:1px 5px;font-size:9.5px}#mk-nif .ixw .ptb span:first-child a{font-size:10px}
#mk-nif .ixw .plg{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:calc(100% - 90px);font-size:10px}   /* patch 149 */
#focus table.oi{width:100%;'''),
]
for a_, b_ in CHART:
    if s.count(a_) != 1:
        print("ANCHOR x%d (chart): %s" % (s.count(a_), a_[:80])); sys.exit(1)
    s = s.replace(a_, b_)
open(p, "w", encoding="utf-8").write(s)
print("patched: home.html")
PY_PATCH
cat > $W/instflow.py <<'PY_IF'
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


# ---------- patch 149: DELIVERY - the institutions' footprint in every F&O share (NSE's sec_bhavdata_full, every evening) ----------
DELIV_URL = "https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_%s.csv"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*",
      "Referer": "https://www.nseindia.com/"}


def parse_deliv(txt, fo):
    """-> {sym: [qty, deliv_qty, deliv_pct, close, prev_close]} the EQ series of the F&O shares"""
    out = {}
    for e in csv.DictReader(io.StringIO(txt)):
        e = {(k or "").strip().upper(): (v or "").strip() for k, v in e.items()}
        s = e.get("SYMBOL")
        if not s or e.get("SERIES") != "EQ" or (fo and s not in fo):
            continue
        try:
            f = lambda k: float(e.get(k, "").replace(",", "") or 0)
            out[s] = [f("TTL_TRD_QNTY"), f("DELIV_QTY"), f("DELIV_PER"), f("CLOSE_PRICE"), f("PREV_CLOSE")]
        except ValueError:
            continue
    return out


def deliv_fetch(now=None, get=None, days=26):
    """the delivery file of every weekday not yet kept, the last `days` days -> files saved"""
    now = now or dt.datetime.now(IST)
    fo = fo_set()
    if get is None:
        import requests
        ses = requests.Session()

        def get(u):
            r = ses.get(u, headers=UA, timeout=20)
            return r.text if r.status_code == 200 and "SYMBOL" in r.text[:200] else None
    n, d = 0, now.date()
    os.makedirs(DIR, exist_ok=True)
    for _ in range(days):
        p = os.path.join(DIR, "deliv_%s.json" % d)
        if (d.weekday() < 5 or d == dt.date(2026, 11, 8)) and not os.path.exists(p) and not (d == now.date() and now.strftime("%H:%M") < "17:30"):
            try:
                t = get(DELIV_URL % d.strftime("%d%m%Y"))
                if t:
                    json.dump({"day": str(d), "s": parse_deliv(t, fo)}, open(p, "w"))
                    n += 1
            except Exception as ex:
                print("deliv %s: %s" % (d, str(ex)[:60]))
            time.sleep(0.4)
        d -= dt.timedelta(days=1)
    return n


def deliv_signals(min_x=1.5):
    """-> {"day", "acc": [...], "dist": [...]} the last delivery day vs its 20-day normal: price up + delivery 1.5x+ = big hands
    buying (accumulation), price down + 1.5x+ = selling (distribution); ranked by ₹ crore delivered above normal"""
    files = sorted(f for f in (os.listdir(DIR) if os.path.isdir(DIR) else []) if f.startswith("deliv_"))
    if not files:
        return {}
    D = []
    for f in files[-21:]:
        try:
            D.append(json.load(open(os.path.join(DIR, f))))
        except Exception:
            pass
    if not D:
        return {}
    last, hist = D[-1], D[:-1]
    acc, dist = [], []
    for s, (q, dq, dp, cl, pc) in (last.get("s") or {}).items():
        H = [x["s"][s] for x in hist if s in (x.get("s") or {})]
        if len(H) < 5 or not (cl and pc and dq):
            continue
        avg_dq = sum(h[1] for h in H) / len(H)
        avg_dp = sum(h[2] for h in H) / len(H)
        if avg_dq <= 0:
            continue
        x = dq / avg_dq
        chg = (cl / pc - 1) * 100
        if x < min_x or dp < avg_dp * 0.9 or abs(chg) < 0.3:
            continue
        row = {"s": s, "chg": round(chg, 2), "x": round(x, 1), "dp": round(dp, 1), "avg_dp": round(avg_dp, 1),
               "cr": round(dq * cl / 1e7, 1), "extra": round((dq - avg_dq) * cl / 1e7, 1)}
        (acc if chg > 0 else dist).append(row)
    k = lambda r: -r["extra"]
    return {"day": last.get("day"), "n": len(last.get("s") or {}), "acc": sorted(acc, key=k)[:15], "dist": sorted(dist, key=k)[:15]}


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
            except Exception as ex:
                print("instflow refresh: %s" % str(ex)[:80])
            try:
                deliv_fetch()                                    # patch 149
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
    files = sorted(f for f in (os.listdir(DIR) if os.path.isdir(DIR) else []) if f.endswith(".json") and not f.startswith("deliv_"))[-30:]
    days = [f[:-5] for f in files]
    data = {}
    for f in files:
        try:
            data[f[:-5]] = json.load(open(os.path.join(DIR, f))).get("rows") or []
        except Exception:
            pass
    out = {"days": days, "w": {}}
    try:
        out["deliv"] = deliv_signals()                           # patch 149
    except Exception:
        out["deliv"] = {}
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
        print("delivery days read: %s" % deliv_fetch())
    dl = deliv_signals()
    print("== DELIVERY %s (%s F&O shares): big hands BUYING (price up, delivery 1.5x+ normal)" % (dl.get("day"), dl.get("n")))
    for r in dl.get("acc") or []:
        print("   %-12s %+.2f%%  delivered ₹%s cr (%.1fx normal, ₹%s cr extra) · %s%% delivery (normal %s%%)" % (r["s"], r["chg"], r["cr"], r["x"], r["extra"], r["dp"], r["avg_dp"]))
    print("== big hands SELLING (price down, delivery 1.5x+ normal)")
    for r in dl.get("dist") or []:
        print("   %-12s %+.2f%%  delivered ₹%s cr (%.1fx normal, ₹%s cr extra) · %s%% delivery (normal %s%%)" % (r["s"], r["chg"], r["cr"], r["x"], r["extra"], r["dp"], r["avg_dp"]))
    v = summary(now=dt.datetime.now(IST))
    for w in ("1", "5", "30"):
        W = v["w"].get(w) or {}
        print("== %s day(s) %s..%s · FII net ₹%s cr · DII net ₹%s cr" % (w, W.get("from"), W.get("to"), W.get("fii_net"), W.get("dii_net")))
        for k in ("fii_buy", "fii_sell", "dii_buy", "dii_sell"):
            print("  %-9s %s" % (k, " · ".join("%s ₹%s cr (%s)" % (x["s"], x["cr"], x["who"]) for x in W.get(k) or [])))
PY_IF
cat > $D/p149test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p149test.py - patch 149: big hands buying / selling from NSE's delivery file (made-up files, no network)"""
import os, sys, json, tempfile, shutil, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import instflow as I
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); I.BASE = T; I.DIR = os.path.join(T, "data", "instdeals")
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,?)", [(s, 1) for s in ("HINDALCO", "TCS", "PNB", "SBIN")]); c.commit(); c.close()
H = " SYMBOL, SERIES, DATE1, PREV_CLOSE, OPEN_PRICE, HIGH_PRICE, LOW_PRICE, LAST_PRICE, CLOSE_PRICE, AVG_PRICE, TTL_TRD_QNTY, TURNOVER_LACS, NO_OF_TRADES, DELIV_QTY, DELIV_PER"
def f(d, last):
    rows = [H]
    for s, pc, cl, q, dq in (("HINDALCO", 950, 961.35 if last else 950, 8e6 if last else 4e6, 4.8e6 if last else 2e6),
                              ("TCS", 3030, 3001.5 if last else 3030, 4e6 if last else 2e6, 2.6e6 if last else 1e6),
                              ("PNB", 120, 127 if last else 120, 9e7, 3e7),
                              ("SBIN", 1000, 1010, 1e7 if last else 1e7, 5e6),
                              ("SMALLCO", 10, 12, 1e6, 9e5)):
        rows.append(" %s, EQ, %s, %s, 0, 0, 0, 0, %s, 0, %d, 0, 0, %d, %.2f" % (s, d, pc, cl, q, dq, dq / q * 100))
    rows.append(" HINDALCO, BE, x, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1")
    return "\n".join(rows)
now = dt.datetime(2026, 11, 9, 19, 0, tzinfo=I.IST)
seen = []
def get(u):
    d = u[-12:-4]; seen.append(d)
    return f(d, d == "09112026")
n = I.deliv_fetch(now, get, days=30)
check("delivery files read for the weekdays (and the Muhurat Sunday): %d" % n, n >= 20 and "08112026" in seen and "07112026" not in seen)
v = I.deliv_signals()
print(json.dumps(v)[:500])
A, S = {r["s"]: r for r in v["acc"]}, {r["s"]: r for r in v["dist"]}
check("HINDALCO: price +1.19%%, delivery 2.4x normal -> BIG HANDS BUYING, ₹%s cr above normal" % A.get("HINDALCO", {}).get("extra"), "HINDALCO" in A and A["HINDALCO"]["x"] == 2.4)
check("TCS: price -0.94%%, delivery 2.6x -> BIG HANDS SELLING", "TCS" in S and S["TCS"]["x"] == 2.6)
check("PNB: +5.8%% but delivery at its normal -> not listed (no extra big money)", "PNB" not in A)
check("SBIN: delivery at its normal -> not listed; SMALLCO (not F&O) never", "SBIN" not in A and "SMALLCO" not in A)
shutil.rmtree(T)
print("P149 DELIVERY TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p149_patch.py $D || { rm -f $D/p149test.py; echo "nothing was changed"; exit 1; }
cp $W/instflow.py $D/instflow.py
cd $D && python3 -m py_compile instflow.py p149test.py || back
for t in p149test.py p148test.py p146etest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep FAIL | head -3; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    reading NSE's delivery files - 26 days (1-2 min)..."
( cd /home/globalbot && set -a && source .env && set +a && cd $D && timeout 240 python3 instflow.py refresh ) 2>&1 | grep -v "^  \(fii\|dii\)_\|^== [0-9]" | head -40
echo
echo "PATCH 149 APPLIED. Reload the GIR page (Ctrl+F5): 🏦 BIG MONEY · F&O SHARES at the bottom; the chart fits its panel."
