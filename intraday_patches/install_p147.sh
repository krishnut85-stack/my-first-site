#!/bin/bash
# PATCH 147 - NIFTY / BANKNIFTY TRADINGVIEW-STYLE CHART + F&O MONEY SORTING. The NIFTY panel becomes a real chart (the same library as
#   each share's PRO chart): NIFTY | BANKNIFTY · 1m 5m 15m 1h 1D · candles / line · EMA 9 / 21 · BOLL · PREV CLOSE · FLOOR / CEILING
#   (the option writers' walls) · BREADTH · your own lines · FIT · full screen; scroll = zoom, drag = move. Type NIFTY or BANKNIFTY in
#   the ticker = it opens there. F&O MONEY: SORT by ₹ money, OI % or price % - high to low, tap again = low to high (20 a block).
#   dashserve.py · home.html (needs 146c). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g147; mkdir -p $W
grep -q "patch 147" $D/home.html && { echo "patch 147 is already installed"; exit 1; }
grep -q "patch 146c" $D/home.html || { echo "patch 146c is not installed yet"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back() { for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p147_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p147_patch.py - PATCH 147: NIFTY / BANKNIFTY - A TRADINGVIEW-STYLE CHART (Rama: "the NIFTY chart should work like TradingView";
"for BANKNIFTY there is not enough - all you need is the search bar and the information").
The NIFTY panel on MARKET becomes a Lightweight Charts chart (the same library as each share's PRO chart):
  NIFTY | BANKNIFTY · 1m 5m 15m 1h 1D · candles / line · EMA 9 · EMA 21 · BOLL · PREV CLOSE · FLOOR / CEILING (the option writers'
  walls, the options desk) · BREADTH (F&O shares up minus down, 5-min) · ─ LINE (your lines, kept per index) · FIT · ⛶ full screen
  scroll = zoom, drag = move, the crosshair shows O H L C and the change. The last candle moves with the live price.
  history: data/h3 (the 3-year download: 5-min and daily) + today's candles (NIFTY: the engine's 5-min; both: a 1-minute record the
  page server now keeps of NIFTY and BANKNIFTY, data/ix1m.json). Typing NIFTY or BANKNIFTY in the ticker opens it (and the options
  desk follows).
Usage: python3 p147_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
SRV_FN = r'''

# ---------- patch 147: NIFTY / BANKNIFTY candles for the index chart ----------
_IX = {"day": None, "b": {}, "saved": 0.0}
_IXH = {}


def ix_tick(now=None):
    """one OHLC slot a minute for NIFTY and BANKNIFTY from the live index strip (the refresher calls it), kept in data/ix1m.json"""
    now = now or dt.datetime.now(IST)
    m = now.hour * 60 + now.minute
    if now.weekday() > 4 or not (555 <= m <= 930):
        return
    d_ = str(now.date())
    path = os.path.join(BASE, "data", "ix1m.json")
    if _IX["day"] != d_:
        _IX.update({"day": d_, "b": {}})
        try:
            j = json.load(open(path))
            if j.get("day") == d_:
                _IX["b"] = {n: {int(k): v for k, v in b.items()} for n, b in (j.get("b") or {}).items()}
        except Exception:
            pass
    idx = ((_HOME.get("v") or {}).get("idx")) or {}
    for n in ("NIFTY", "BANKNIFTY"):
        p = (idx.get(n) or {}).get("last")
        if not p:
            continue
        B = _IX["b"].setdefault(n, {})
        b = B.get(m)
        if b is None:
            B[m] = [p, p, p, p]
        else:
            b[1], b[2], b[3] = max(b[1], p), min(b[2], p), p
    if time.time() - _IX["saved"] > 30:
        _IX["saved"] = time.time()
        try:
            json.dump({"day": d_, "b": _IX["b"]}, open(path + ".tmp", "w"))
            os.replace(path + ".tmp", path)
        except Exception:
            pass


def ixhist(n, now=None):
    """-> {"n", "t","o","h","l","c" (5-min, ~60 days + today), "m1": today's 1-minute, "d": daily ~2 years, "pc"} cached 20 s"""
    n = "BANKNIFTY" if "BANK" in str(n or "").upper() else "NIFTY"
    c_ = _IXH.get(n)
    if c_ and time.time() - c_[0] < 20 and now is None:
        return c_[1]
    now = now or dt.datetime.now(IST)
    import numpy as np
    fn = "NIFTY_BANK" if n == "BANKNIFTY" else "NIFTY_50"
    t0d = int(dt.datetime(now.year, now.month, now.day, 9, 15, tzinfo=IST).timestamp())
    rows = {}
    try:
        a = np.load(os.path.join(BASE, "data", "h3", "m5", fn + ".npz"))
        cut = t0d - 70 * 86400
        for t, o, h, l, c in zip(a["ts"], a["o"], a["h"], a["l"], a["c"]):
            if t >= cut and t < t0d:
                rows[int(t)] = [float(o), float(h), float(l), float(c)]
    except Exception:
        pass
    if n == "NIFTY":
        try:
            ch = (json.load(open(os.path.join(BASE, "charts.json"))) or {}).get("NIFTY50") or {}
            st = live_obj()
            if (st.get("day") or str(now.date())) == str(now.date()):
                for i, c in enumerate(ch.get("c") or []):
                    if c is None:
                        continue
                    o, h, l = (ch.get("o") or [None])[i] if i < len(ch.get("o") or []) else c, (ch.get("h") or [None] * (i + 1))[i], (ch.get("l") or [None] * (i + 1))[i]
                    rows[t0d + 300 * i] = [float(o if o is not None else c), float(h if h is not None else c), float(l if l is not None else c), float(c)]
        except Exception:
            pass
    m1 = {"t": [], "o": [], "h": [], "l": [], "c": []}
    B = {}
    try:
        if _IX["day"] == str(now.date()):
            B = _IX["b"].get(n) or {}
        else:
            j = json.load(open(os.path.join(BASE, "data", "ix1m.json")))
            if j.get("day") == str(now.date()):
                B = {int(k): v for k, v in ((j.get("b") or {}).get(n) or {}).items()}
    except Exception:
        B = {}
    for m in sorted(B):
        o, h, l, c = B[m]
        t = t0d + (m - 555) * 60
        for k, v in zip(("t", "o", "h", "l", "c"), (t, o, h, l, c)):
            m1[k].append(v)
        b5 = t0d + ((m - 555) // 5) * 300
        if n == "BANKNIFTY" or b5 not in rows:
            r = rows.get(b5)
            if r is None or r[-1] is None:
                rows[b5] = [o, h, l, c]
            elif b5 >= t0d:
                r[1], r[2], r[3] = max(r[1], h), min(r[2], l), c
    ks = sorted(rows)
    d = {"t": [], "o": [], "h": [], "l": [], "c": []}
    try:
        a = np.load(os.path.join(BASE, "data", "h3", "day", fn + ".npz"))
        cut = t0d - 800 * 86400
        for t, o, h, l, c in zip(a["ts"], a["o"], a["h"], a["l"], a["c"]):
            if cut <= t < t0d - 33300:
                for k, v in zip(("t", "o", "h", "l", "c"), (int(t), float(o), float(h), float(l), float(c))):
                    d[k].append(v)
    except Exception:
        pass
    today = [rows[k] for k in ks if k >= t0d]
    if today:
        dt0 = t0d - 33300
        for k, v in zip(("t", "o", "h", "l", "c"), (dt0, today[0][0], max(x[1] for x in today), min(x[2] for x in today), today[-1][3])):
            d[k].append(v)
    pc = (((_HOME.get("v") or {}).get("idx") or {}).get(n) or {}).get("pc")
    if not pc:
        prev = [rows[k][3] for k in ks if k < t0d]
        pc = prev[-1] if prev else None
    v = {"n": n, "t": ks, "o": [rows[k][0] for k in ks], "h": [rows[k][1] for k in ks], "l": [rows[k][2] for k in ks], "c": [rows[k][3] for k in ks],
         "m1": m1, "d": d, "pc": pc, "t0": t0d}
    _IXH[n] = (time.time(), v)
    return v


def home_refresher():'''
JS = r'''/* patch 147: F&O MONEY sorted - by the money, OI % or price %, high to low / low to high (tap again = reverse) */
let MS={k:"cr",d:-1}; try{ MS=Object.assign(MS,JSON.parse(localStorage.getItem("gir_ms")||"{}")); }catch(e){}
function msSet(k){ if(MS.k===k) MS.d=-MS.d; else { MS.k=k; MS.d=-1; } try{ localStorage.setItem("gir_ms",JSON.stringify(MS)); }catch(e){} drawMarket.force=true; drawMarket(); drawMarket.force=false; }
function msort(xs){ const v={cr:x=>Math.abs(x.cr||0),oi:x=>x.oi??0,chg:x=>x.chg??0}[MS.k]||(x=>0); return xs.slice().sort((a,b)=>(v(a)-v(b))*MS.d); }
function msortBar(){ const b=(k,l)=>`<a class="${MS.k===k?"on":""}" onclick="msSet('${k}')">${l}${MS.k===k?(MS.d<0?" ▼ HIGH→LOW":" ▲ LOW→HIGH"):""}</a>`; return `<div class="mss">SORT ${b("cr","₹ MONEY")}${b("oi","OI %")}${b("chg","PRICE %")}<span class="dim">tap again = reverse</span></div>`; }
/* patch 147: NIFTY / BANKNIFTY - a TradingView-style chart on MARKET */
let IXN="NIFTY"; try{ IXN=localStorage.getItem("gir_ixn")||"NIFTY"; }catch(e){}
const IXP=Object.assign({tf:"5",type:"candle",ema9:1,ema21:1,bb:0,prev:1,walls:1,br:1},(()=>{ try{ return JSON.parse(localStorage.getItem("gir_ixp")||"{}"); }catch(e){ return {}; } })());
let IXD={}, IXT=0, IXC=null, IXTOOL="";
function ixSave(){ try{ localStorage.setItem("gir_ixp",JSON.stringify(IXP)); localStorage.setItem("gir_ixn",IXN); }catch(e){} }
async function ixPull(force){ if(!force&&IXD[IXN]&&Date.now()-IXT<20000) return; IXT=Date.now(); const n=IXN; const v=await getJ("ixhist?k="+encodeURIComponent(K)+"&n="+n); if(v&&v.n){ IXD[v.n]=v; if(IXC) IXC.key=""; ixDraw(); } }
function ixSet(k,v){ if(k==="n"){ IXN=v; if(typeof idxSet==="function"&&IDXT!==v){ IDXT=v; try{ localStorage.setItem("gir_idxt",v); }catch(e){} } } else if(v===undefined) IXP[k]=IXP[k]?0:1; else IXP[k]=v; ixSave(); if(IXC) IXC.key=""; if(k==="n"){ ixPull(true); if(typeof drawMarket==="function"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } } else ixDraw(); }
function ixDraws(){ try{ return JSON.parse(localStorage.getItem("gir_ixdraw_"+IXN)||"[]"); }catch(e){ return []; } }
function ixDrawSave(d){ try{ localStorage.setItem("gir_ixdraw_"+IXN,JSON.stringify(d)); }catch(e){} if(IXC) IXC.key=""; ixDraw(); }
function ixTool(){ IXTOOL=IXTOOL?"":"h"; if(IXC){ IXC.tb.innerHTML=ixToolbar(); IXC.main.applyOptions({crosshair:{mode:IXTOOL?0:1}}); } }
function ixFull(){ if(!IXC) return; if(document.fullscreenElement) document.exitFullscreen(); else if(IXC.el.requestFullscreen) IXC.el.requestFullscreen(); }
document.addEventListener("fullscreenchange",()=>{ if(IXC){ IXC.h=-1; IXC.key=""; setTimeout(ixDraw,150); } });
function ixBars(){ const d=IXD[IXN]; if(!d) return []; const mk=(m)=>((m&&m.t)||[]).map((t,i)=>({t,o:m.o[i],h:m.h[i],l:m.l[i],c:m.c[i]}));
  if(IXP.tf==="1") return mk(d.m1); if(IXP.tf==="D") return mk(d.d);
  const raw=mk(d); if(IXP.tf==="5") return raw; const span=IXP.tf==="15"?900:3600; const mp=new Map();
  for(const r of raw){ const b=day0915(r.t)+Math.floor((r.t-day0915(r.t))/span)*span; const o=mp.get(b); if(!o) mp.set(b,Object.assign({},r,{t:b})); else { o.h=Math.max(o.h,r.h); o.l=Math.min(o.l,r.l); o.c=r.c; } }
  return [...mp.values()].sort((a,b)=>a.t-b.t); }
function ixToolbar(){ const b=(on,l,f,t)=>`<a class="${on?"on":""}" onclick="${f}" ${t?`title="${t}"`:""}>${l}</a>`;
  return `<div class="ptb"><span>${["NIFTY","BANKNIFTY"].map(n=>b(IXN===n,n,`ixSet('n','${n}')`)).join("")}</span><span>${[["1","1m"],["5","5m"],["15","15m"],["60","1h"],["D","1D"]].map(([k,l])=>b(IXP.tf===k,l,`ixSet('tf','${k}')`)).join("")}</span>
    <span>${b(IXP.type==="candle","CANDLES","ixSet('type','candle')")}${b(IXP.type==="line","LINE","ixSet('type','line')")}</span>
    <span>${[["ema9","EMA 9"],["ema21","EMA 21"],["bb","BOLL"],["prev","PREV CLOSE"],["walls","FLOOR / CEILING","the option writers' walls - the options desk"],["br","BREADTH","F&O shares up minus down, every 5 min (5m, today)"]].map(([k,l,t])=>b(IXP[k],l,`ixSet('${k}')`,t)).join("")}</span>
    <span>${b(IXTOOL==="h","─ LINE","ixTool()","click the chart to place a line")}${b(false,"✕","ixDrawSave([])","remove your lines")}${b(false,"⟲ FIT","IXC&&IXC.main.timeScale().fitContent()")}${b(false,"⛶","ixFull()","full screen")}</span></div>`; }
function ixLegend(t){ if(!IXC||!IXC.B||!IXC.lg) return; const B=IXC.B; let i=B.length-1; if(t!=null){ const k=B.findIndex(b=>T_(b.t)===t); if(k>=0) i=k; } const b=B[i]; if(!b) return;
  const d=IXD[IXN]||{}; const ref=IXP.tf==="D"?(i>0?B[i-1].c:b.o):(d.pc||b.o); const ch=b.c-ref, cp=ref?ch/ref*100:0; const tl=new Date((b.t+ISTO)*1000).toISOString();
  IXC.lg.innerHTML=`<b>${IXN}</b> <span class="dim">${IXP.tf==="D"?tl.slice(0,10):tl.slice(5,10)+" "+tl.slice(11,16)} · ${({"1":"1m","5":"5m","15":"15m","60":"1h","D":"1D"})[IXP.tf]}</span> O <b>${inr(b.o)}</b> H <b>${inr(b.h)}</b> L <b>${inr(b.l)}</b> C <b class="${ch>=0?"pu":"pd"}">${inr(b.c)}</b> <span class="${ch>=0?"pu":"pd"}">${ch>=0?"+":""}${inr(+ch.toFixed(2))} (${cp>=0?"+":""}${cp.toFixed(2)}%)</span> <span class="dim">${IXP.tf==="D"?"vs the day before":"vs the previous close"}</span>`; }
function ixDraw(){ const box=$("mk-nif"); if(!box) return;
  if(!window.LightweightCharts){ if(!box.querySelector(".empty")) box.innerHTML='<div class="empty">loading the chart…</div>'; lwcLoad(()=>{ IXC=null; ixDraw(); }); return; }
  ixPull(false);
  const fs=!!document.fullscreenElement&&IXC&&document.fullscreenElement===IXC.el; const H=fs?window.innerHeight-4:Math.max(220,box.clientHeight-2); const TBH=box.clientWidth<520?82:box.clientWidth<900?58:32;
  const B=ixBars(); const d=IXD[IXN]||{}; const W=((MK&&MK.idxd)||{})[IXN]||{}; const dr=ixDraws();
  const key=JSON.stringify([IXN,IXP,B.length,B.length?B[0].t:0,dr,IXP.walls?[W.floor,W.ceil]:0,IXP.br?((MK&&MK.adv)||[]).length:0,d.pc,H]);
  if(IXC&&document.body.contains(IXC.el)&&IXC.key===key){ const L=B[B.length-1], live=((D&&D.idx)||{})[IXN]; if(L&&IXC.s&&live&&live.last&&IXP.tf!=="D"&&Date.now()/1000-L.t<(IXP.tf==="60"?3700:IXP.tf==="15"?960:IXP.tf==="1"?70:330)&&typeof mktOpenNow==="function"&&mktOpenNow()){
      L.c=live.last; L.h=Math.max(L.h,L.c); L.l=Math.min(L.l,L.c); try{ IXC.s.update(IXP.type==="line"?{time:T_(L.t),value:L.c}:{time:T_(L.t),open:L.o,high:L.h,low:L.l,close:L.c}); }catch(e){} ixLegend(null); }
    return; }
  const keepR=(IXC&&IXC.main&&IXC.n===IXN&&IXC.tf===IXP.tf)?IXC.main.timeScale().getVisibleLogicalRange():null;
  if(IXC&&IXC.main){ try{ IXC.main.remove(); }catch(e){} }
  box.innerHTML=`<div class="pro ixw" style="background:#05070a"><div class="ptbw"></div><div class="pmain" style="height:${H-TBH}px;position:relative"><div class="plg"></div></div></div>`;
  const el=box.querySelector(".ixw"); const LC=window.LightweightCharts;
  const main=LC.createChart(el.querySelector(".pmain"),{autoSize:true,layout:{background:{type:"solid",color:"#05070a"},textColor:"#8a97a8",fontSize:11,fontFamily:"JetBrains Mono, Menlo, monospace"},
    grid:{vertLines:{color:"#0f1620"},horzLines:{color:"#0f1620"}},rightPriceScale:{borderColor:"#1a2230"},timeScale:{borderColor:"#1a2230",timeVisible:IXP.tf!=="D",secondsVisible:false,rightOffset:8},
    crosshair:{mode:IXTOOL?0:1,vertLine:{color:"#ffb00088",labelBackgroundColor:"#ffb000"},horzLine:{color:"#ffb00088",labelBackgroundColor:"#ffb000"}},localization:{priceFormatter:p=>inr(+(+p).toFixed(2))}});
  IXC={el,h:H,key,n:IXN,tf:IXP.tf,main,B,tb:el.querySelector(".ptbw"),lg:el.querySelector(".plg")};
  IXC.tb.innerHTML=ixToolbar();
  main.subscribeCrosshairMove(p=>ixLegend(p&&p.time));
  main.subscribeClick(p=>{ if(!IXTOOL||!p||!p.point||!IXC.s) return; const pr=IXC.s.coordinateToPrice(p.point.y); if(pr==null) return; const dd=ixDraws(); dd.push(+(+pr).toFixed(2)); IXTOOL=""; ixDrawSave(dd); });
  if(!B.length){ IXC.lg.innerHTML=`<span class="dim">${IXP.tf==="1"?"1-minute candles are recorded from 09:15 - pick 5m for the history":"loading the history… (the 3-year download fills older days)"}</span>`; return; }
  const up="#1ed760", dn="#ff3b4a";
  const s=IXP.type==="line"?main.addLineSeries({color:"#e8eef5",lineWidth:2}):main.addCandlestickSeries({upColor:up,downColor:dn,borderUpColor:up,borderDownColor:dn,wickUpColor:up,wickDownColor:dn});
  s.setData(B.map(b=>IXP.type==="line"?{time:T_(b.t),value:b.c}:{time:T_(b.t),open:b.o,high:b.h,low:b.l,close:b.c})); IXC.s=s;
  const C=B.map(b=>b.c); const ln=(arr,color,w,st)=>{ const l=main.addLineSeries({color,lineWidth:w||1.5,lineStyle:st||0,priceLineVisible:false,lastValueVisible:false,crosshairMarkerVisible:false}); l.setData(B.map((b,i)=>arr[i]!=null?{time:T_(b.t),value:arr[i]}:{time:T_(b.t)})); };
  if(IXP.ema9) ln(ema(C,9),"#4fc3f7"); if(IXP.ema21) ln(ema(C,21),"#b388ff");
  if(IXP.bb){ const m=sma(C,20); const sd=C.map((v,i)=>{ if(i<19) return null; let a=0; for(let j=i-19;j<=i;j++) a+=(C[j]-m[i])**2; return Math.sqrt(a/20); }); ln(m.map((v,i)=>v==null?null:v+2*sd[i]),"#78909c",1,2); ln(m,"#78909c",1,1); ln(m.map((v,i)=>v==null?null:v-2*sd[i]),"#78909c",1,2); }
  const pl=(price,color,title,st)=>{ if(price) s.createPriceLine({price:+price,color,lineWidth:1,lineStyle:st==null?2:st,axisLabelVisible:true,title}); };
  if(IXP.prev&&IXP.tf!=="D") pl(d.pc,"#9aa5b1","PREV CLOSE",1);
  if(IXP.walls){ pl(W.ceil,dn,"CEILING (call writers)"); pl(W.floor,up,"FLOOR (put writers)"); }
  dr.forEach(p=>pl(p,"#ffb000","my line",0));
  if(IXP.br&&IXP.tf==="5"&&MK&&(MK.adv||[]).length&&d.t0){ const t0=d.t0; const h=main.addHistogramSeries({priceScaleId:"br",lastValueVisible:false,priceLineVisible:false}); main.priceScale("br").applyOptions({scaleMargins:{top:0.82,bottom:0}});
    h.setData(MK.adv.map((v,i)=>({time:T_(t0+300*i),value:v,color:v>=0?"#1ed76066":"#ff3b4a66"})).filter(x=>B.some(b=>T_(b.t)===x.time))); }
  if(keepR) main.timeScale().setVisibleLogicalRange(keepR); else main.timeScale().setVisibleLogicalRange({from:Math.max(0,B.length-(IXP.tf==="D"?260:IXP.tf==="1"?240:IXP.tf==="5"?160:IXP.tf==="15"?120:80)),to:B.length+4});
  ixLegend(null); }
'''
CSS = '''#mk-mon .mss{display:flex;gap:4px;padding:3px 6px;align-items:center;font-size:10px;color:var(--dim);flex-wrap:wrap;border-bottom:1px solid var(--line)}#mk-mon .mss a{padding:1px 6px;border:1px solid var(--line2);cursor:pointer;color:var(--txt);background:#000}#mk-mon .mss a.on{background:var(--amber);color:#000;border-color:var(--amber)}
.ixw .ptb{display:flex;flex-wrap:wrap;gap:3px 8px;padding:3px 6px;border-bottom:1px solid var(--line);align-items:center}.ixw .ptb span{display:inline-flex;gap:2px}
.ixw .ptb a{padding:2px 6px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;white-space:nowrap;letter-spacing:.03em}.ixw .ptb a.on{background:var(--amber);color:#000;border-color:var(--amber)}
.ixw .ptb span:first-child a{font-weight:700;font-size:11px}#mk-nif .ixw .pmain{min-height:120px}
#mk-nif .ixw .ptb{padding:3px 6px}#mk-nif .ixw .plg{position:absolute;left:6px;top:4px;z-index:3;font-size:11px;pointer-events:none;background:#05070acc;padding:1px 4px}#nifTf{display:none}   /* patch 147 */
#focus table.oi{width:100%;'''
SRV = [
    ('''key=lambda f: -abs(f.get("cr") or 0))[:6]''', '''key=lambda f: -abs(f.get("cr") or 0))[:20]   # patch 147: 20 a block - the page sorts'''),
    ('''\n\ndef home_refresher():''', SRV_FN),
    ('''        try:
            nifty_tick()                                          # patch 120: NIFTY's 1-minute candles''',
     '''        try:
            ix_tick()                                             # patch 147: NIFTY + BANKNIFTY 1-minute candles (the index chart)
        except Exception as ex:
            print("ix 1m:", str(ex)[:80])
        try:
            nifty_tick()                                          # patch 120: NIFTY's 1-minute candles'''),
    ('''            if u.path == "/hist":                     # the PRO chart's bars (patch 104)''',
     '''            if u.path == "/ixhist":                   # patch 147: NIFTY / BANKNIFTY candles for the index chart
                return self.send(200, json.dumps(ixhist((parse_qs(u.query).get("n") or ["NIFTY"])[0]), separators=(",", ":")), "application/json")
            if u.path == "/hist":                     # the PRO chart's bars (patch 104)'''),
]
PAGE = [
    ('''    const blk=(b,c)=>{ const xs=mo[b]||[]; return''', '''    const blk=(b,c)=>{ const xs=msort(mo[b]||[]).slice(0,8); return'''),
    ('''    MKH("mk-mon").innerHTML=`<div class="mn">''', '''    MKH("mk-mon").innerHTML=`${msortBar()}<div class="mn">'''),
    ('''  if(SLOW.nif&&Date.now()-SLOW.nif<5000&&!drawMarket.force&&$("mk-nif").querySelector("svg")){ nifTick(); } else {''',
     '''  if(true){ ixDraw(); } else if(SLOW.nif&&Date.now()-SLOW.nif<5000&&!drawMarket.force&&$("mk-nif").querySelector("svg")){ nifTick(); } else {   /* patch 147: the TradingView-style chart */'''),
    ('''<h3>NIFTY · F&amp;O BREADTH <span>through the day</span>''', '''<h3>NIFTY · BANKNIFTY <span>chart · scroll = zoom · drag = move · type NIFTY / BANKNIFTY in the ticker</span>'''),
    ('''  if(sym==="MARKET"||sym==="NIFTY"||sym==="NIFTY50"){ if(!SOLO) setView("market"); return; }''',
     '''  if(sym==="MARKET"){ if(!SOLO) setView("market"); return; }
  if(/^(NIFTY|NIFTY ?50|BANK ?NIFTY|NIFTY ?BANK)$/.test(sym)){ if(SOLO){ toMain("market"); return; } const n_=/BANK/.test(sym)?"BANKNIFTY":"NIFTY"; IXN=n_; IDXT=n_; try{ localStorage.setItem("gir_idxt",n_); }catch(e){} ixSave(); if(IXC) IXC.key=""; setView("market"); ixPull(true);
    setTimeout(()=>{ const q_=$("q-nif"); if(q_){ q_.scrollIntoView({block:"nearest"}); q_.classList.add("flash"); setTimeout(()=>q_.classList.remove("flash"),1600); } },250); $("q").value=""; return; }   /* patch 147 */'''),
    ('''function MKH(id){''', JS + '''function MKH(id){'''),
    ('''#focus table.oi{width:100%;''', CSS),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 147" in s:
        print("patch 147 is already in %s" % os.path.basename(p)); return None
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
python3 $W/p147_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || back
for t in p146etest.py p146btest.py p145etest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
K=$(cat $D/dash_token.txt)
for n in NIFTY BANKNIFTY; do curl -s -m 20 "http://127.0.0.1:8090/ixhist?k=$K&n=$n" | python3 -c "
import json, sys; v = json.load(sys.stdin); print('    %-9s 5-min candles %d · daily %d · today 1-min %d' % (v['n'], len(v['t']), len(v['d']['t']), len(v['m1']['t'])))" || echo "    $n: no answer"; done
echo
echo "PATCH 147 APPLIED. Reload the GIR page (Ctrl+F5). History fills as the 3-year download finishes; BANKNIFTY's own today-candles"
echo "start recording at tomorrow's open."
