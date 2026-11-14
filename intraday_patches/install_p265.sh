#!/bin/bash
# PATCH 265 - 📈 MY P&L IN THE MY F&O TAB (Rama, 14 Nov: "a profit and loss chart from my sheet and your Zerodha readings - tick by tick").
#   TODAY · LIVE   GIR reads the account's F&O positions every 3 s 09:15-15:30 (READ ONLY - never an order): today's P&L as a live line, or
#                  1-min / 5-min candles · open now · booked today · day high / low · your positions
#   DAY BY DAY     a bar a day + the running total - from GIR's own readings (from Monday) and your Zerodha TRADEBOOK if you upload it
#   MY RECORD      from your Zerodha P&L statement (upload on the page): by expiry month, best shares, where it leaked, CE vs PE, cheap options, equity
#   Your numbers stay on this server (data/) - never in the code or on GitHub.
#   Tested: 13 cases + the page's code. New service gir-pnlwatch; restarts the page server - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/core.py ] && [ -f $D/dashserve.py ] && [ -f $D/home.html ] || { echo "GIR's core.py / dashserve.py / home.html not found"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
[ -f $D/pnlbook.py ] && cp $D/pnlbook.py $D/pnlbook.py.bak$TS
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl disable --now gir-pnlwatch 2>/dev/null; rm -f $U/gir-pnlwatch.service; systemctl daemon-reload; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pnlbook.py <<'PY_PB'
#!/usr/bin/env python3
"""pnlbook.py - patch 265: 📈 MY P&L for the MY F&O tab (Rama, 14 Nov: "a profit and loss chart from my sheet and your Zerodha readings - tick by tick").
  watch     (service gir-pnlwatch) every 3 s 09:15-15:30: the account's F&O positions (READ ONLY - never an order) -> today's P&L ticks
            (data/pnl_live/DAY.json) · at the close the day's total -> data/pnl_days.json (the day-by-day chart grows each day)
  get()     what the page draws: today's ticks (since a time), the open positions, the days, the statement's picture
  upload()  a CSV from the page: Zerodha's P&L statement (F&O or equity) or the tradebook (dated trades -> the days since June)
Your numbers stay on this server (data/), never in the code or on GitHub.   python3 pnlbook.py watch | show"""
import os, re, io, csv, sys, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DATA = os.path.join(BASE, "data")
LIVE = os.path.join(DATA, "pnl_live")
DAYS = os.path.join(DATA, "pnl_days.json")
ST_FO, ST_EQ, TB = os.path.join(DATA, "pnl_statement_fo.csv"), os.path.join(DATA, "pnl_statement_eq.csv"), os.path.join(DATA, "pnl_tradebook.csv")
EVERY = 3
OPT = re.compile(r"^([A-Z0-9][A-Z0-9&\-]*?)(\d{2})([A-Z]{3}|[1-9OND]\d{2})([\d.]+)(CE|PE)$")
FUT = re.compile(r"^([A-Z][A-Z0-9&\-]*?)(\d{2})([A-Z]{3})FUT$")


def _load(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def _save(p, v):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(v, open(p + ".tmp", "w"), separators=(",", ":"), default=str); os.replace(p + ".tmp", p)


def fo(P):
    return [p for p in (P or []) if p.get("exchange") in ("NFO", "BFO")]


def reading(P):
    """positions -> (today's P&L, open now, booked today, rows)"""
    P = fo(P)
    day = sum(float(p.get("m2m") if p.get("m2m") is not None else (p.get("pnl") or 0)) for p in P)
    opn = sum(float(p.get("unrealised") if p.get("unrealised") is not None else ((p.get("pnl") or 0) if p.get("quantity") else 0)) for p in P if p.get("quantity"))
    rows = [{"ts": p.get("tradingsymbol"), "q": int(p.get("quantity") or 0), "avg": round(float(p.get("average_price") or 0), 2),
             "ltp": round(float(p.get("last_price") or 0), 2), "pnl": round(float(p.get("pnl") or 0)), "m2m": round(float(p.get("m2m") or 0))} for p in P]
    return round(day), round(opn), round(day - opn), rows


def record(now, P):
    """one tick into today's file; at 15:30+ the day's total into the days"""
    d = str(now.date())
    p = os.path.join(LIVE, d + ".json")
    j = _load(p, {"t": [], "v": [], "o": []})
    day, opn, _bk, rows = reading(P)
    j["t"].append(int(now.timestamp())); j["v"].append(day); j["o"].append(opn)
    j["rows"], j["at"] = rows, now.strftime("%H:%M:%S")
    _save(p, j)
    if now.strftime("%H:%M") >= "15:30":
        D = _load(DAYS, {}); D[d] = day; _save(DAYS, D)
    return day


def watch():
    kite, last_err = None, 0
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            kite = None; time.sleep(20); continue
        try:
            if kite is None:
                import core
                kite = core.get_kite()
            record(now, kite.positions().get("net") or [])
        except Exception as ex:
            kite = None
            if time.time() - last_err > 300:
                print("%s %s" % (hm, str(ex)[:120]), flush=True); last_err = time.time()
            time.sleep(10)
        time.sleep(EVERY)


# ---------------- the statement / the tradebook ----------------
def _rows(raw):
    return list(csv.reader(io.StringIO(raw)))


def kind_of(raw):
    head = raw[:4000].lower()
    if "trade_date" in head and "trade_type" in head:
        return "tradebook"
    if "p&l statement for f&o" in head or "p&l statement for futures" in head:
        return "fo"
    if "p&l statement for equity" in head:
        return "eq"
    return None


def statement(raw):
    """Zerodha's P&L statement -> {summary, contracts: [(symbol, realised)]}"""
    R = _rows(raw); summ, out, hdr = {}, [], None
    for r in R:
        c = [x.strip() for x in r]
        if len(c) > 2 and c[1] in ("Charges", "Other Credit & Debit", "Realized P&L", "Unrealized P&L") and hdr is None:
            try:
                summ[c[1]] = float(c[2])
            except ValueError:
                pass
        if len(c) > 6 and c[1] == "Symbol":
            hdr = c; continue
        if hdr and len(c) > 6 and c[1]:
            try:
                out.append((c[1], float(c[hdr.index("Realized P&L")] or 0), float(c[hdr.index("Unrealized P&L")] or 0) if "Unrealized P&L" in hdr else 0.0,
                            float(c[hdr.index("Buy Value")] or 0) if "Buy Value" in hdr else 0.0))
            except (ValueError, IndexError):
                continue
    return summ, out


def picture_fo(raw):
    summ, C = statement(raw)
    if not C:
        return None
    months, shares, side = {}, {}, {"CE": [0, 0, 0.0], "PE": [0, 0, 0.0], "FUT": [0, 0, 0.0]}
    small = [0, 0.0]
    for s, r, u, buy in C:
        m = OPT.match(s) or FUT.match(s)
        if not m:
            continue
        und, mon = m.group(1), m.group(3)
        k = m.group(5) if OPT.match(s) else "FUT"
        months[mon] = months.get(mon, 0.0) + r
        shares[und] = shares.get(und, 0.0) + r
        side[k][0] += 1; side[k][1] += r > 0; side[k][2] += r
        if 0 < buy < 30000:
            small[0] += 1; small[1] += r
    order = {m: i for i, m in enumerate("JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC".split())}
    W = [r for _s, r, _u, _b in C if r > 0]; L = [r for _s, r, _u, _b in C if r < 0]
    sh = sorted(shares.items(), key=lambda x: -x[1])
    return {"realised": round(summ.get("Realized P&L", sum(r for _s, r, _u, _b in C))), "charges": round(summ.get("Charges", 0)),
            "net": round(summ.get("Realized P&L", 0) - summ.get("Charges", 0) + summ.get("Other Credit & Debit", 0)),
            "n": len(C), "won": len(W), "avg_win": round(sum(W) / len(W)) if W else 0, "avg_loss": round(sum(L) / len(L)) if L else 0,
            "months": [[m, round(v)] for m, v in sorted(months.items(), key=lambda x: order.get(x[0], 99))],
            "best": [[s, round(v)] for s, v in sh[:6] if v > 0], "worst": [[s, round(v)] for s, v in sh[::-1][:6] if v < 0],
            "side": {k: [v[0], v[1], round(v[2])] for k, v in side.items() if v[0]}, "small": [small[0], round(small[1])]}


def picture_eq(raw):
    summ, C = statement(raw)
    if not C and not summ:
        return None
    return {"realised": round(summ.get("Realized P&L", 0)), "unrealised": round(summ.get("Unrealized P&L", 0)), "charges": round(summ.get("Charges", 0)),
            "trades": [[s, round(r)] for s, r, _u, _b in C if r], "holdings": [[s, round(u)] for s, _r, u, _b in C if u]}


def tradebook_days(raw):
    """Zerodha's tradebook -> {day: realised P&L} (first in, first out per contract; before charges)"""
    rd = csv.DictReader(io.StringIO(raw))
    T = []
    for r in rd:
        r = {(k or "").strip().lower(): (v or "").strip() for k, v in r.items()}
        try:
            T.append((r.get("order_execution_time") or r.get("trade_date"), r["trade_date"][:10], r["symbol"], r["trade_type"].lower(), float(r["quantity"]), float(r["price"])))
        except (KeyError, ValueError):
            continue
    T.sort()
    book, days = {}, {}
    for _t, d, s, side, q, px in T:
        lots = book.setdefault(s, [])                                   # [(signed qty, price)] open, first in first out
        sg = 1 if side == "buy" else -1
        while q > 1e-9 and lots and (lots[0][0] > 0) != (sg > 0):
            oq, op = lots[0]; m = min(q, abs(oq))
            days[d] = days.get(d, 0.0) + (px - op) * m * (1 if oq > 0 else -1)
            q -= m
            lots[0] = (oq - m * (1 if oq > 0 else -1), op)
            if abs(lots[0][0]) < 1e-9:
                lots.pop(0)
        if q > 1e-9:
            lots.append((sg * q, px))
    return {d: round(v) for d, v in sorted(days.items())}


def upload(raw):
    raw = raw.decode("utf-8-sig", "replace") if isinstance(raw, (bytes, bytearray)) else raw
    k = kind_of(raw)
    if k is None:
        raise ValueError("not a Zerodha P&L statement or tradebook (CSV from Console - Reports)")
    p = {"fo": ST_FO, "eq": ST_EQ, "tradebook": TB}[k]
    os.makedirs(DATA, exist_ok=True)
    open(p, "w", encoding="utf-8").write(raw)
    if k == "fo":
        x = picture_fo(raw); return {"saved": "F&O P&L statement", "contracts": x["n"] if x else 0}
    if k == "eq":
        return {"saved": "equity P&L statement"}
    return {"saved": "tradebook", "days": len(tradebook_days(raw))}


def _read(p):
    try:
        return open(p, encoding="utf-8").read()
    except Exception:
        return None


def get(since=0, now=None):
    now = now or dt.datetime.now(IST)
    d = str(now.date())
    j = _load(os.path.join(LIVE, d + ".json"), None)
    if j is None:                                                      # before the open / a holiday: the last day recorded
        fs = sorted(f for f in (os.listdir(LIVE) if os.path.isdir(LIVE) else []) if f.endswith(".json"))
        if fs:
            j = _load(os.path.join(LIVE, fs[-1]), None); d = fs[-1][:-5]
    out = {"day": d, "t": [], "v": [], "o": [], "rows": [], "at": None}
    if j:
        i = 0
        if since:
            while i < len(j["t"]) and j["t"][i] <= since:
                i += 1
        out.update({"t": j["t"][i:], "v": j["v"][i:], "o": j["o"][i:], "rows": j.get("rows") or [], "at": j.get("at"), "n": len(j["t"])})
        if j["v"]:
            out.update({"now": j["v"][-1], "open": j["o"][-1], "hi": max(j["v"]), "lo": min(j["v"])})
    if since:
        return out
    days = {}
    tb = _read(TB)
    if tb:
        days.update(tradebook_days(tb))
    days.update({k: v for k, v in _load(DAYS, {}).items()})            # GIR's own readings win
    out["days"] = sorted(days.items())
    f, e = _read(ST_FO), _read(ST_EQ)
    out["fo"] = picture_fo(f) if f else None
    out["eq"] = picture_eq(e) if e else None
    out["live"] = os.path.isdir(LIVE)
    return out


if __name__ == "__main__":
    if sys.argv[1:2] == ["watch"]:
        watch()
    else:
        print(json.dumps(get(), indent=1, default=str)[:3000])
PY_PB
cat > $W/p265_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p265_patch.py - patch 265: 📈 MY P&L in the MY F&O tab - dashserve.py (/mypnl GET + POST) and home.html (the chart).  python3 p265_patch.py DIR JSFILE CSSFILE"""
import os, sys
D, JS, CSS = sys.argv[1], open(sys.argv[2], encoding="utf-8").read(), open(sys.argv[3], encoding="utf-8").read()
def edit(f, pairs):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if "patch 265" in s:
        print("  %s: patch 265 - already in" % f); return
    for old, new, tag in pairs:
        if s.count(old) != 1:
            print("❌ %s: anchor for '%s' found %d times" % (f, tag, s.count(old))); sys.exit(1)
        s = s.replace(old, new); print("  %s: %s" % (f, tag))
    open(p, "w", encoding="utf-8").write(s)
G = '''            if u.path == "/panels":                   # the function keys PICKS · TOMORROW · MY F&O · DESK P&L (patch 89)'''
edit("dashserve.py", [
    (G, '''            if u.path == "/mypnl":                    # patch 265: MY P&L - today's ticks from the account, the days, the statement
                import pnlbook
                s_ = (parse_qs(u.query).get("since") or ["0"])[0]
                return self.send(200, json.dumps(pnlbook.get(int(float(s_ or 0))), ensure_ascii=False, default=str), "application/json; charset=utf-8")
''' + G, "GET /mypnl"),
    ('''            n = int(self.headers.get("Content-Length") or 0)''', '''            if u.path == "/mypnl":                    # patch 265: a Zerodha CSV from the page (kept in data/, never on GitHub)
                import pnlbook
                n_ = int(self.headers.get("Content-Length") or 0)
                if n_ > 5000000:
                    return self.send(413, "the file is too big (5 MB)", "text/plain")
                return self.send(200, json.dumps(pnlbook.upload(self.rfile.read(n_))), "application/json; charset=utf-8")
            n = int(self.headers.get("Content-Length") or 0)''', "POST /mypnl (the upload)")])
edit("home.html", [
    ("</style>", CSS + "\n</style>", "the chart's look"),
    ('<h2>MY F&amp;O <small>your real trades · net after charges</small></h2><div id="mfl">',
     '<h2>MY F&amp;O <small>your real trades · net after charges</small></h2><div id="mfpnl"><!-- patch 265 --></div><div id="mfl">', "the chart's place"),
    ("let MFCAP=0;   /* patch 174 */", JS + "\nlet MFCAP=0;   /* patch 174 */", "the chart: TODAY · LIVE · DAY BY DAY · MY RECORD")])
print("patch 265 in")
PY_PATCH
cat > $W/page265.js <<'PY_JS265'
/* ---------- patch 265: 📈 MY P&L - live from the Zerodha account (pnlbook.py), tick by tick ---------- */
let PNL={tab:"today",mode:"line",d:null,last:0,ch:null,box:null,key:"",busy:false};
try{ const s_=JSON.parse(localStorage.getItem("gir_pnl")||"{}"); if(s_.tab) PNL.tab=s_.tab; if(s_.mode) PNL.mode=s_.mode; }catch(e){}
const pnlR=v=>v==null?"—":(v<0?"−₹":"₹")+Math.abs(Math.round(v)).toLocaleString("en-IN");
const pnlC=v=>v>0?"pu":v<0?"pd":"";
async function pnlPull(full){ if(PNL.busy) return; PNL.busy=true;
  try{ const inc=!full&&PNL.d&&PNL.last; const r=await fetch("mypnl?k="+encodeURIComponent(K)+(inc?"&since="+PNL.last:""),{cache:"no-store"}); if(!r.ok) return; const j=await r.json();
    if(!inc||!PNL.d||j.day!==PNL.d.day){ PNL.d=j; }
    else{ ["t","v","o"].forEach(k=>{ PNL.d[k]=PNL.d[k].concat(j[k]||[]); }); ["rows","at","now","open","hi","lo","n"].forEach(k=>{ if(j[k]!==undefined) PNL.d[k]=j[k]; }); }
    PNL.last=PNL.d.t.length?PNL.d.t[PNL.d.t.length-1]:0; pnlDraw(); }catch(e){} finally{ PNL.busy=false; } }
function pnlSet(k,v){ PNL[k]=v; try{ localStorage.setItem("gir_pnl",JSON.stringify({tab:PNL.tab,mode:PNL.mode})); }catch(e){} PNL.key=""; pnlDraw(); }
function pnlBars(data){ const out=[]; const step=PNL.mode==="c5"?300:60; let cur=null;
  for(let i=0;i<data.t.length;i++){ const b=Math.floor(data.t[i]/step)*step, v=data.v[i];
    if(!cur||cur.time!==b+19800){ if(cur) out.push(cur); cur={time:b+19800,open:v,high:v,low:v,close:v}; } else { cur.high=Math.max(cur.high,v); cur.low=Math.min(cur.low,v); cur.close=v; } }
  if(cur) out.push(cur); return out; }
function pnlChart(box,h){ if(!window.LightweightCharts){ lwcLoad(()=>{ PNL.key=""; pnlDraw(); }); return null; }
  if(PNL.ch&&PNL.box===box&&document.body.contains(box.firstChild)) return PNL.ch;
  if(PNL.ch){ try{ PNL.ch.remove(); }catch(e){} }
  box.innerHTML=""; PNL.box=box;
  const dk=document.documentElement.dataset.theme!=="light";
  const wd=box.clientWidth||($("mfpnl")||{}).clientWidth||window.innerWidth-40;
  PNL.ch=LightweightCharts.createChart(box,{width:wd,height:h,layout:{background:{color:"transparent"},textColor:dk?"#b8c2d6":"#333"},
    grid:{vertLines:{color:"rgba(128,128,128,.12)"},horzLines:{color:"rgba(128,128,128,.12)"}},rightPriceScale:{borderVisible:false},timeScale:{timeVisible:true,secondsVisible:false,borderVisible:false,minBarSpacing:0.05},
    localization:{priceFormatter:p=>(p<0?"−₹":"₹")+Math.abs(Math.round(p)).toLocaleString("en-IN")}});
  PNL.s={};
  if(window.ResizeObserver){ if(PNL.ro) PNL.ro.disconnect(); PNL.ro=new ResizeObserver(()=>{ try{ if(PNL.ch&&box.clientWidth) PNL.ch.applyOptions({width:box.clientWidth}); }catch(e){} }); PNL.ro.observe(box); }
  return PNL.ch; }
const pnlName=ts=>{ const m=/^([A-Z0-9&\-]+?)(\d{2})([A-Z]{3}|[1-9OND]\d{2})([\d.]+)(CE|PE)$/.exec(ts||""); return m?`${m[1]} ${m[4]} ${m[5]}`:(ts||""); };
function pnlDraw(){ const W=$("mfpnl"); if(!W) return; const D=PNL.d;
  const tb=(k,l)=>`<a class="${PNL.tab===k?"on":""}" onclick="pnlSet('tab','${k}')">${l}</a>`, md=(k,l)=>`<a class="${PNL.mode===k?"on":""}" onclick="pnlSet('mode','${k}')">${l}</a>`;
  const key=PNL.tab+"|"+PNL.mode+"|"+(D?D.day:"");
  if(PNL.key!==key){ PNL.key=key; if(PNL.ch){ try{ PNL.ch.remove(); }catch(e){} PNL.ch=null; }
    W.innerHTML=`<div class="pnh"><b>📈 MY P&amp;L</b><span class="pnt">${tb("today","TODAY · LIVE")}${tb("days","DAY BY DAY")}${tb("record","MY RECORD")}</span><span class="pnt" id="pnmd"></span><span class="dim" id="pnat"></span></div>
      <div id="pnk" class="kp"></div><div id="pnc" class="pnc"></div><div id="pnx"></div>`; }
  $("pnmd").innerHTML=PNL.tab==="today"?md("line","LINE")+md("c1","CANDLE 1m")+md("c5","CANDLE 5m"):"";
  if(!D){ $("pnk").innerHTML='<div class="empty">reading your account…</div>'; return; }
  if(PNL.tab==="today"){
    $("pnat").textContent=D.at?`${D.day===new Date().toLocaleDateString("en-CA",{timeZone:"Asia/Kolkata"})?"live":"last session "+D.day} · ${D.at} · every 3 s from Zerodha (read only)`:"from 09:15 on a trading day";
    $("pnk").innerHTML=`<div><small>TODAY</small><b class="${pnlC(D.now)}" style="font-size:1.5em">${pnlR(D.now)}</b></div><div><small>OPEN NOW</small><b class="${pnlC(D.open)}">${pnlR(D.open)}</b></div><div><small>BOOKED TODAY</small><b class="${pnlC((D.now||0)-(D.open||0))}">${pnlR(D.now!=null?(D.now-(D.open||0)):null)}</b></div><div><small>DAY HIGH · LOW</small><b><span class="pu">${pnlR(D.hi)}</span> · <span class="pd">${pnlR(D.lo)}</span></b></div>`;
    const box=$("pnc");
    if(!D.t.length){ if(PNL.ch){ try{ PNL.ch.remove(); }catch(e){} PNL.ch=null; } box.innerHTML='<div class="empty">no reading yet today - the line starts at 09:15 (GIR reads your Zerodha account every 3 seconds, read only)</div>'; }
    else{ const ch=pnlChart(box,260); if(ch){ const up=(D.now||0)>=0;
      if(!PNL.s.main){ PNL.s.main=PNL.mode==="line"?ch.addLineSeries({color:up?"#26a69a":"#ef5350",lineWidth:2,priceLineVisible:true}):ch.addCandlestickSeries({upColor:"#26a69a",downColor:"#ef5350",borderVisible:false,wickUpColor:"#26a69a",wickDownColor:"#ef5350"});
        PNL.s.main.createPriceLine({price:0,color:"rgba(160,160,160,.7)",lineWidth:1,lineStyle:2,axisLabelVisible:true,title:"0"}); PNL.s.n=0; }
      if(PNL.mode==="line"){ PNL.s.main.applyOptions({color:up?"#26a69a":"#ef5350"});
        if(PNL.s.n&&PNL.s.n<=D.t.length){ for(let i=PNL.s.n;i<D.t.length;i++) PNL.s.main.update({time:D.t[i]+19800,value:D.v[i]}); }
        else{ PNL.s.main.setData(D.t.map((t,i)=>({time:t+19800,value:D.v[i]}))); ch.timeScale().fitContent(); } PNL.s.n=D.t.length; }
      else{ PNL.s.main.setData(pnlBars(D)); if(!PNL.s.n){ ch.timeScale().fitContent(); } PNL.s.n=D.t.length; } } }
    const rows=(D.rows||[]).filter(r=>r.q||r.m2m);
    $("pnx").innerHTML=rows.length?`<div class="hd2">YOUR F&amp;O POSITIONS · from Zerodha</div>`+rows.map(r=>`<div class="r"><div class="sy"><b>${esc(pnlName(r.ts))}</b><small>${r.q?r.q+" qty open":"closed today"}</small></div><div><div class="do ${r.pnl>0?"up":r.pnl<0?"dn":""}">bought ₹${r.avg} → now ₹${r.ltp} · P&amp;L ${pnlR(r.pnl)}</div><div class="why">today ${pnlR(r.m2m)}</div></div></div>`).join(""):"";
  }
  else if(PNL.tab==="days"){
    const ds=D.days||[]; let cum=0; const pts=ds.map(([d,v])=>{ cum+=v; return {d,v,cum}; });
    const wn=ds.filter(x=>x[1]>0).length;
    $("pnat").textContent=ds.length?`${ds[0][0]} → ${ds[ds.length-1][0]} · before charges`:"";
    $("pnk").innerHTML=ds.length?`<div><small>DAYS · GREEN</small><b>${ds.length} · ${wn} (${Math.round(wn/ds.length*100)}%)</b></div><div><small>TOTAL</small><b class="${pnlC(cum)}">${pnlR(cum)}</b></div><div><small>BEST DAY</small><b class="pu">${pnlR(Math.max(...ds.map(x=>x[1])))}</b></div><div><small>WORST DAY</small><b class="pd">${pnlR(Math.min(...ds.map(x=>x[1])))}</b></div>`:"";
    const box=$("pnc");
    if(!ds.length){ box.innerHTML='<div class="empty">the days fill up from your first live day - or upload your Zerodha TRADEBOOK (Console → Reports → Tradebook → F&amp;O → CSV) under MY RECORD to see every day since June</div>'; }
    else{ const ch=pnlChart(box,260); if(ch&&!PNL.s.h){ PNL.s.h=ch.addHistogramSeries({priceScaleId:"right"}); PNL.s.c=ch.addLineSeries({color:"#f0b429",lineWidth:2,priceScaleId:"left"});
      ch.applyOptions({leftPriceScale:{visible:true,borderVisible:false}}); PNL.s.h.setData(pts.map(p=>({time:p.d,value:p.v,color:p.v>=0?"rgba(38,166,154,.85)":"rgba(239,83,80,.85)"})));
      PNL.s.c.setData(pts.map(p=>({time:p.d,value:p.cum}))); ch.timeScale().fitContent(); } }
    $("pnx").innerHTML=ds.length?`<div class="why" style="padding:4px 8px">bars = each day (right scale) · gold line = the running total (left scale)</div>`:"";
  }
  else{
    $("pnat").textContent="from the statement you uploaded (Zerodha Console)"; const F=D.fo, E=D.eq;
    if(PNL.ch){ try{ PNL.ch.remove(); }catch(e){} PNL.ch=null; }
    const bar=(l,v,mx)=>`<div class="pnb"><span>${esc(l)}</span><i style="width:${Math.max(2,Math.abs(v)/mx*100)}%;background:${v>=0?"var(--up)":"var(--dn)"}"></i><b class="${pnlC(v)}">${pnlR(v)}</b></div>`;
    $("pnk").innerHTML=F?`<div><small>F&amp;O REALISED</small><b class="${pnlC(F.realised)}">${pnlR(F.realised)}</b></div><div><small>CHARGES</small><b class="pd">${pnlR(-F.charges)}</b><small>${F.realised>0?Math.round(F.charges/F.realised*100)+"% of the profit":""}</small></div><div><small>NET</small><b class="${pnlC(F.net)}">${pnlR(F.net)}</b></div><div><small>WON · AVG WIN · AVG LOSS</small><b>${F.won}/${F.n} · <span class="pu">${pnlR(F.avg_win)}</span> · <span class="pd">${pnlR(F.avg_loss)}</span></b></div>`:"";
    let h="";
    if(F){ const mx=Math.max(1,...F.months.map(m=>Math.abs(m[1])),...F.best.map(m=>Math.abs(m[1])),...F.worst.map(m=>Math.abs(m[1])));
      h+=`<div class="hd2">BY EXPIRY MONTH</div>`+F.months.map(m=>bar(m[0],m[1],mx)).join("");
      h+=`<div class="hd2">YOUR BEST SHARES</div>`+F.best.map(m=>bar(m[0],m[1],mx)).join("");
      h+=`<div class="hd2">WHERE IT LEAKED</div>`+F.worst.map(m=>bar(m[0],m[1],mx)).join("");
      const sd=F.side||{}; h+=`<div class="hd2">CE vs PE</div>`+Object.keys(sd).map(k=>`<div class="r"><div class="sy"><b>${k}</b><small>${sd[k][0]} contracts · ${sd[k][1]} won</small></div><div><div class="do ${sd[k][2]>=0?"up":"dn"}">${pnlR(sd[k][2])}</div></div></div>`).join("");
      if(F.small&&F.small[0]) h+=`<div class="r"><div class="sy"><b>CHEAP OPTIONS</b><small>bought under ₹30,000</small></div><div><div class="do ${F.small[1]>=0?"up":"dn"}">${F.small[0]} contracts · ${pnlR(F.small[1])}</div><div class="why">mostly far out of the money - the POSITION GUARD warns on these</div></div></div>`; }
    if(E){ h+=`<div class="hd2">EQUITY</div><div class="r"><div class="sy"><b>SHORT TRADES</b><small>${(E.trades||[]).length} shares</small></div><div><div class="do ${E.realised>=0?"up":"dn"}">realised ${pnlR(E.realised)}</div></div></div><div class="r"><div class="sy"><b>HOLDINGS</b><small>${(E.holdings||[]).length} shares</small></div><div><div class="do ${E.unrealised>=0?"up":"dn"}">open ${pnlR(E.unrealised)}</div><div class="why">${(E.holdings||[]).map(x=>esc(x[0])+" "+pnlR(x[1])).join(" · ")}</div></div></div>`; }
    h+=`<div class="pnu"><b>UPLOAD</b> a CSV from Zerodha Console → Reports: <b>P&amp;L</b> (F&amp;O or Equity) or <b>Tradebook</b> (F&amp;O, the dates → DAY BY DAY) <input type="file" accept=".csv,text/csv" onchange="pnlUp(this)"> <span id="pnum" class="dim"></span><div class="dim">it stays on your GIR server - never on GitHub</div></div>`;
    $("pnc").innerHTML=""; $("pnx").innerHTML=h||'<div class="empty">upload your statement below</div>'+h;
  } }
async function pnlUp(inp){ const f=inp.files&&inp.files[0]; if(!f) return; const m=$("pnum"); m.textContent="uploading…";
  try{ const r=await fetch("mypnl?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"text/csv"},body:await f.text()}); const t=await r.text();
    if(!r.ok) throw new Error(t); const j=JSON.parse(t); m.textContent=`saved ✓ ${j.saved}${j.days?" · "+j.days+" days":""}${j.contracts?" · "+j.contracts+" contracts":""}`; PNL.key=""; pnlPull(true); }catch(e){ m.textContent="not saved: "+e.message; } }
window.addEventListener("resize",()=>{ if(PNL.ch&&PNL.box) try{ PNL.ch.applyOptions({width:PNL.box.clientWidth}); }catch(e){} });
setInterval(()=>{ if(VIEW==="myfo"&&!document.hidden) pnlPull(!PNL.d); },3000);
setTimeout(()=>{ if(VIEW==="myfo") pnlPull(true); },800);
PY_JS265
cat > $W/page265.css <<'PY_CSS265'
/* patch 265: MY P&L */
#mfpnl{border-bottom:1px solid var(--ln,#2a3346);margin-bottom:6px}
#mfpnl .pnh{display:flex;flex-wrap:wrap;gap:8px;align-items:center;padding:6px 8px}
#mfpnl .pnt a{display:inline-block;padding:2px 8px;margin-right:4px;border:1px solid var(--ln,#2a3346);border-radius:3px;cursor:pointer;font-size:.8em}
#mfpnl .pnt a.on{background:var(--ac,#f0b429);color:#000;border-color:transparent}
#mfpnl .pnc{padding:0 4px}
#mfpnl .pnc:empty{display:none}
#mfpnl .pnb{display:grid;grid-template-columns:110px 1fr 100px;gap:8px;align-items:center;padding:3px 8px;font-size:.85em}
#mfpnl .pnb i{display:block;height:12px;border-radius:2px;opacity:.85}
#mfpnl .pnb b{text-align:right}
#mfpnl .pnu{padding:8px;font-size:.85em;border-top:1px dashed var(--ln,#2a3346);margin-top:6px}
@media (max-width:600px){ #mfpnl .pnb{grid-template-columns:80px 1fr 80px} }
PY_CSS265
cat > $W/p265test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p265test.py - MY P&L on made-up positions and files (temp copy, nothing read from Zerodha).  python3 p265test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "pnlbook.py"), T)
sys.path.insert(0, T); os.chdir(T)
import pnlbook as P
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
mon = lambda h, m, s=0: dt.datetime(2026, 11, 16, h, m, s, tzinfo=IST)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
pos = lambda ts, q, avg, ltp, m2m, un=None: {"tradingsymbol": ts, "exchange": "NFO", "quantity": q, "average_price": avg, "last_price": ltp,
                                             "pnl": (ltp - avg) * q if q else m2m, "m2m": m2m, "unrealised": (ltp - avg) * q if un is None else un}
P1 = [pos("POLICYBZR26NOV1100CE", 3850, 48.3, 50.0, 6545.0), {"tradingsymbol": "INFY", "exchange": "NSE", "quantity": 10, "m2m": 99999}]
P.record(mon(9, 15, 3), P1)
P.record(mon(9, 15, 6), [pos("POLICYBZR26NOV1100CE", 3850, 48.3, 51.0, 10395.0)])
P.record(mon(9, 15, 9), [pos("POLICYBZR26NOV1100CE", 3850, 48.3, 47.0, -5005.0), pos("GRASIM26NOV3100CE", 0, 60.0, 0, -12000.0, 0)])
g = P.get(0, mon(9, 16))
chk("today's ticks every 3 s: 3 readings, F&O only (the equity row is not counted)", g["t"] and len(g["t"]) == 3 and g["v"] == [6545, 10395, -17005], g["v"])
chk("now / open / high / low: -₹17,005 · open -₹5,005 · high ₹10,395 · low -₹17,005", g["now"] == -17005 and g["open"] == -5005 and g["hi"] == 10395 and g["lo"] == -17005, g)
chk("the positions for the page (open and closed today)", len(g["rows"]) == 2 and g["rows"][0]["ts"] == "POLICYBZR26NOV1100CE", g["rows"])
s = P.get(g["t"][1], mon(9, 16))
chk("the page asks only for the new ticks (since)", s["v"] == [-17005] and "days" not in s, s)
P.record(mon(15, 30, 1), [pos("POLICYBZR26NOV1100CE", 0, 48.3, 0, 21000.0, 0)])
chk("15:30: the day's total into the days", json.load(open(P.DAYS)) == {"2026-11-16": 21000}, open(P.DAYS).read())
fo = """,,
,Client ID,XX0000,,,
,P&L Statement for F&O from 2026-06-01 to 2026-11-14,,,
,Summary,,
,Charges,1000,,
,Other Credit & Debit,0,,
,Realized P&L,25000,,
,Unrealized P&L,0,,
,Symbol,ISIN,Quantity,Buy Value,Sell Value,Realized P&L,Realized P&L Pct.,Previous Closing Price,Open Quantity,Open Quantity Type,Open Value,Unrealized P&L,Unrealized P&L Pct.
,AAA26NOV100CE,,100,50000,80000,30000,60,0,0,,0,0,0
,BBB26OCT200PE,,100,20000,15000,-5000,-25,0,0,,0,0,0
,360ONE26NOV940PE,,100,9000,9000,0,0,0,0,,0,0,0
,CCC26NOV50FUT,,100,90000,90000,0,0,0,0,,0,0,0
"""
r = P.upload(fo.encode())
x = P.picture_fo(open(P.ST_FO).read())
chk("upload: an F&O P&L statement is recognised and kept in data/", r["saved"] == "F&O P&L statement" and os.path.exists(P.ST_FO), r)
chk("its picture: realised ₹25,000 · charges ₹1,000 · net ₹24,000 · OCT -₹5,000 · NOV +₹30,000", x["realised"] == 25000 and x["net"] == 24000 and ["OCT", -5000] in x["months"] and ["NOV", 30000] in x["months"], x)
chk("... best / worst shares, CE vs PE, cheap options (under ₹30,000) · a share starting with a digit (360ONE) is read", x["best"][0] == ["AAA", 30000] and x["worst"][0] == ["BBB", -5000]
    and x["side"]["CE"] == [1, 1, 30000] and x["side"]["PE"][0] == 2 and x["small"] == [2, -5000], x)
tb = "symbol,isin,trade_date,exchange,segment,series,trade_type,auction,quantity,price,trade_id,order_id,order_execution_time,expiry_date\n" \
     "AAA26NOV100CE,,2026-11-10,NSE,FO,,buy,false,100,50,1,1,2026-11-10T10:00:00,2026-11-24\n" \
     "AAA26NOV100CE,,2026-11-10,NSE,FO,,sell,false,50,70,2,2,2026-11-10T11:00:00,2026-11-24\n" \
     "AAA26NOV100CE,,2026-11-11,NSE,FO,,sell,false,50,40,3,3,2026-11-11T10:00:00,2026-11-24\n" \
     "BBB26NOV200PE,,2026-11-11,NSE,FO,,buy,false,10,100,4,4,2026-11-11T12:00:00,2026-11-24\n" \
     "BBB26NOV200PE,,2026-11-11,NSE,FO,,sell,false,10,130,5,5,2026-11-11T13:00:00,2026-11-24\n"
r = P.upload(tb)
chk("upload: a tradebook -> the days (first in, first out): 10 Nov +₹1,000 · 11 Nov -₹500 +₹300", r["saved"] == "tradebook" and P.tradebook_days(tb) == {"2026-11-10": 1000, "2026-11-11": -200}, P.tradebook_days(tb))
g = P.get(0, mon(16, 0))
chk("DAY BY DAY: the tradebook's days + GIR's own reading of 16 Nov", g["days"] == [("2026-11-10", 1000), ("2026-11-11", -200), ("2026-11-16", 21000)], g["days"])
try:
    P.upload("hello,world\n1,2\n"); bad = False
except ValueError:
    bad = True
chk("any other file is refused", bad)
g = P.get(0, dt.datetime(2026, 11, 17, 8, 0, tzinfo=IST))
chk("before the open: the last session's line is shown", g["day"] == "2026-11-16" and len(g["t"]) == 4, (g["day"], len(g["t"])))
src = open("pnlbook.py").read()
chk("read only: no order calls in the code", not any(w in src for w in ("place_order", "modify_order", "cancel_order")))
print("MY P&L test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p265_patch.py $D $W/page265.js $W/page265.css || back
cd $D && python3 -m py_compile pnlbook.py dashserve.py || back
echo "=== test"
python3 $W/p265test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
mkdir -p $D/data/pnl_live; chown -R --reference=$D $D/pnlbook.py $D/data/pnl_live 2>/dev/null
cat > $U/gir-pnlwatch.service <<'UNIT'
[Unit]
Description=GIR MY P&L - reads the account's F&O P&L every 3 s in market hours (read only)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && exec python3 -u pnlbook.py watch >> data/pnlwatch.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-pnlwatch >/dev/null 2>&1 || back
systemctl restart gir-dash; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-pnlwatch: $(systemctl is-active gir-pnlwatch)"
echo "✅ patch 265 done - GIR → 9 MY F&O → 📈 MY P&L (Ctrl + Shift + R once). Live from Monday 09:15."
echo "   MY RECORD → UPLOAD: your P&L statement (F&O, Equity) and the F&O Tradebook from Zerodha Console → Reports, as CSV."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-pnlwatch; systemctl restart gir-dash"
