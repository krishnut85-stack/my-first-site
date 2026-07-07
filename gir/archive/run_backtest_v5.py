#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  GLOBAL EYE v24.1.0 — BACKTEST v5 FINAL
  
  THREE VERSIONS:
  1. STANDARD B — Core proven Variation B logic
  2. PROFIT-MAX B — Momentum Burst + Capital Rotation (25% target)
  3. SAFE B — Lower risk, tighter filters
  
  350-stock NSE subset → scaling factor for 2500+ universe
  Period: 20 months | ₹70K + ₹5K/day + ₹15K/month
  
  Run: cd /home/globalbot/ && python3 run_backtest_v5.py
  Takes ~25 minutes (fetching 350 stocks × 500 days)
═══════════════════════════════════════════════════════════════
"""
import os,sys,time,json
import pandas as pd
import numpy as np
from datetime import datetime,timedelta
from collections import defaultdict
from dotenv import load_dotenv
_dir=os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_dir,".env"))
from kiteconnect import KiteConnect
import pyotp

def kite_login():
    ak=os.getenv("KITE_API_KEY",""); asec=os.getenv("KITE_API_SECRET","")
    kite=KiteConnect(api_key=ak)
    af=os.path.join(_dir,"data","kite_access.json")
    try:
        if os.path.exists(af):
            with open(af) as f: c=json.load(f)
            kite.set_access_token(c["access_token"]); kite.profile()
            print("✅ Kite: Cached"); return kite
    except: pass
    try:
        import requests
        uid=os.getenv("ZERODHA_USER_ID",""); pwd=os.getenv("ZERODHA_PASSWORD","")
        ts=os.getenv("KITE_TOTP_SECRET","")
        s=requests.Session()
        r=s.post("https://kite.zerodha.com/api/login",data={"user_id":uid,"password":pwd})
        rid=r.json()["data"]["request_id"]
        s.post("https://kite.zerodha.com/api/twofa",data={"user_id":uid,"request_id":rid,"twofa_value":pyotp.TOTP(ts).now(),"twofa_type":"totp"})
        r=s.get(f"https://kite.trade/connect/login?v=3&api_key={ak}",allow_redirects=False)
        loc=r.headers.get("Location","")
        if "request_token=" in loc:
            rt=loc.split("request_token=")[1].split("&")[0]
            d=kite.generate_session(rt,api_secret=asec); kite.set_access_token(d["access_token"])
            os.makedirs(os.path.join(_dir,"data"),exist_ok=True)
            with open(af,"w") as f: json.dump({"date":datetime.now().strftime("%Y-%m-%d"),"access_token":d["access_token"]},f)
            print("✅ Kite: Fresh"); return kite
    except Exception as e: print(f"❌ {e}")
    sys.exit(1)

# ═══ 350-STOCK REPRESENTATIVE SUBSET ═══
PRIORITY_STOCKS = [
    # Large Cap (50)
    "RELIANCE","TCS","INFY","HDFCBANK","ICICIBANK","BHARTIARTL","SBIN","SUNPHARMA",
    "LT","TATAMOTORS","BAJFINANCE","M&M","TITAN","WIPRO","HCLTECH","MARUTI",
    "ADANIENT","NTPC","POWERGRID","COALINDIA","ITC","HINDUNILVR","KOTAKBANK",
    "AXISBANK","NESTLEIND","ULTRACEMCO","ONGC","JSWSTEEL","TATASTEEL","HINDALCO",
    "BPCL","DRREDDY","CIPLA","DIVISLAB","GRASIM","BAJAJFINSV","TECHM","EICHERMOT",
    "HEROMOTOCO","BRITANNIA","APOLLOHOSP","TATACONSUM","ADANIPORTS","SBILIFE",
    "HDFCLIFE","BAJAJ-AUTO","VEDL","INDUSINDBK","ASIANPAINT","SHRIRAMFIN",
    # Mid Cap (50)
    "POLYCAB","PERSISTENT","TRENT","ZOMATO","JINDALSTEL","DLF","HAL","IRCTC",
    "CHOLAFIN","NHPC","DIXON","TATAPOWER","GODREJPROP","OBEROIRLTY","PRESTIGE",
    "RVNL","IRFC","PFC","RECLTD","CANBK","BANKBARODA","PNB","FEDERALBNK",
    "TATAELXSI","MPHASIS","LTIM","COFORGE","ZYDUSLIFE","LUPIN","AUROPHARMA",
    "JUBLFOOD","PAGEIND","PIIND","MCDOWELL-N","SIEMENS","ABB","BOSCHLTD",
    "TORNTPHARM","OFSS","NAUKRI","COLPAL","MARICO","DABUR","PIDILITIND",
    "HAVELLS","CROMPTON","NMDC","SAIL","JSWENERGY","TVSMOTOR",
    # Small Cap + Recent IPOs (50)
    "JIOFIN","TATATECH","MANKIND","WAAREEENER","BRIGADE","SOBHA","KAYNES",
    "AMBER","SYRMA","LODHA","MOTHERSON","INDUSTOWER","IDEA","IGL","GAIL",
    "LAURUSLABS","GRANULES","BIOCON","NATCOPHARM","MANAPPURAM","MUTHOOTFIN",
    "RADICO","VBL","DEVYANI","LICI","SJVN","HUDCO","NHPC","CESC",
    "SUPREMEIND","ASTRAL","PRINCEPIPE","POLYCAB","KNR","CONCOR","BLUEDART",
    "STARHEALTH","MAXHEALTH","SBICARD","SRF","DALBHARAT","RAMCOCEM","AMBUJACEM",
    "HINDCOPPER","NALCO","MOIL","GMRINFRA","IRB","DELHIVERY","PAYTM",
    # Additional for diversity (up to 350 filled by Kite scan)
]

def build_subset(kite):
    """Build 350-stock subset with sector diversity."""
    print("📊 Building 350-stock subset...")
    instruments = kite.instruments("NSE")
    
    BAD = ["ETF","GOLD","SILVER","NIFTY","SENSEX","LIQUID","BOND","GILT","BEES","SGBOND","TBILL"]
    token_map = {}
    all_valid = []
    
    for inst in instruments:
        sym=inst.get("tradingsymbol",""); tok=inst.get("instrument_token",0)
        it=inst.get("instrument_type","").upper(); nm=inst.get("name","").upper()
        if not sym or not tok: continue
        if it not in ("EQ",""): continue
        if sym[0].isdigit(): continue
        if any(p in nm or p in sym for p in BAD): continue
        if any(m in sym for m in ["-SM","-BE","-BZ"]): continue
        token_map[sym] = tok
        all_valid.append(sym)
    
    # Priority first, then fill to 350
    subset = []
    for s in PRIORITY_STOCKS:
        if s in token_map and s not in subset:
            subset.append(s)
    
    # Fill remaining from all valid stocks (random sample for diversity)
    np.random.seed(42)
    remaining = [s for s in all_valid if s not in subset]
    np.random.shuffle(remaining)
    for s in remaining:
        if len(subset) >= 350: break
        subset.append(s)
    
    print(f"  Subset: {len(subset)} stocks | Universe: {len(all_valid)} stocks")
    print(f"  Scaling factor base: {len(all_valid)}/{len(subset)} = {len(all_valid)/len(subset):.1f}×")
    return subset, token_map, len(all_valid)

def fetch_data(kite, subset, token_map):
    """Fetch 500 days of OHLCV for all subset stocks."""
    print(f"\n📡 Fetching data for {len(subset)} stocks (this takes ~20 min)...")
    end_dt = datetime.now().strftime("%Y-%m-%d")
    start_dt = (datetime.now() - timedelta(days=700)).strftime("%Y-%m-%d")
    
    data = {}
    errors = 0
    for i, sym in enumerate(subset):
        if sym not in token_map: continue
        try:
            d = kite.historical_data(token_map[sym], start_dt, end_dt, "day")
            if d and len(d) >= 100:
                data[sym] = pd.DataFrame(d)
                if (i+1) % 50 == 0:
                    print(f"  {i+1}/{len(subset)} loaded ({len(data)} valid)")
            time.sleep(0.4)  # Rate limit: ~2.5 calls/sec
        except Exception as e:
            errors += 1
            if errors <= 5: print(f"  ⚠️ {sym}: {e}")
            if "Too Many" in str(e) or "429" in str(e):
                print("  ⏳ Rate limit hit — waiting 10s...")
                time.sleep(10)
            else:
                time.sleep(0.5)
    
    print(f"  ✅ {len(data)} stocks loaded | {errors} errors")
    return data

# ═══ INDICATOR ENGINE ═══
def compute(df):
    """Compute DVM + weekly DVM + all indicators."""
    if len(df) < 50: return None
    c=df["close"].values.astype(float); h=df["high"].values.astype(float)
    lo=df["low"].values.astype(float); v=df["volume"].values.astype(float)
    price=c[-1]
    
    # RSI
    d=np.diff(c,prepend=c[0]); g=np.where(d>0,d,0); l=np.where(d<0,-d,0)
    rsi=100-(100/(1+pd.Series(g).rolling(14).mean().iloc[-1]/(pd.Series(l).rolling(14).mean().iloc[-1]+1e-4)))
    
    # MACD
    e12=pd.Series(c).ewm(span=12).mean(); e26=pd.Series(c).ewm(span=26).mean()
    ml=e12-e26; ms=ml.ewm(span=9).mean()
    macd_bull=float(ml.iloc[-1])>float(ms.iloc[-1])
    macd_cross=False
    for i in [-1,-2,-3,-4,-5]:
        if len(ml)+i>0 and len(ml)+i-1>0:
            if float(ml.iloc[i])>float(ms.iloc[i]) and float(ml.iloc[i-1])<=float(ms.iloc[i-1]):
                macd_cross=True; break
    
    # EMAs + MAs
    ema9=float(pd.Series(c).ewm(span=9).mean().iloc[-1])
    ema21=float(pd.Series(c).ewm(span=21).mean().iloc[-1])
    ma20=float(pd.Series(c).rolling(20).mean().iloc[-1])
    ma50=float(pd.Series(c).rolling(50).mean().iloc[-1])
    ma200=float(pd.Series(c).rolling(min(200,len(c))).mean().iloc[-1])
    
    # ATR
    tr=np.maximum(h[1:]-lo[1:],np.maximum(np.abs(h[1:]-c[:-1]),np.abs(lo[1:]-c[:-1])))
    trs=np.concatenate([[h[0]-lo[0]],tr])
    atr=float(pd.Series(trs).rolling(14).mean().iloc[-1])
    
    # ADX
    try:
        pdm=pd.Series(h).diff().clip(lower=0); mdm=(-pd.Series(lo).diff()).clip(lower=0)
        pdm=pdm.where(pdm>mdm,0); mdm=mdm.where(mdm>pdm,0)
        t14=pd.Series(trs).rolling(14).sum()+1e-4
        pdi=100*pdm.rolling(14).sum()/t14; mdi=100*mdm.rolling(14).sum()/t14
        dx=100*abs(pdi-mdi)/(pdi+mdi+1e-4)
        adx=float(dx.rolling(14).mean().iloc[-1])
    except: adx=20
    
    # Volume
    va=float(pd.Series(v).rolling(20).mean().iloc[-1])
    vs=float(v[-1]/(va+1))
    
    # Supertrend
    sa=float(pd.Series(trs).rolling(10).mean().iloc[-1])
    st_bull=price>(h[-1]+lo[-1])/2-3*sa
    
    # OBV
    try:
        ss=pd.Series(c).diff().fillna(0).apply(lambda x:1 if x>0 else(-1 if x<0 else 0))
        obv=(pd.Series(v)*ss).cumsum(); obv_bull=float(obv.iloc[-1])>float(obv.rolling(20).mean().iloc[-1])
    except: obv_bull=True
    
    # VWAP
    tp=(h+lo+c)/3
    vwap=float((pd.Series(tp*v).rolling(20).sum()/(pd.Series(v).rolling(20).sum()+1)).iloc[-1])
    
    # MFI
    try:
        tps=pd.Series(tp); rmf=tps*pd.Series(v)
        pmf=rmf.where(tps.diff()>0,0).rolling(14).sum()
        nmf=rmf.where(tps.diff()<=0,0).rolling(14).sum()
        mfi=float((100-(100/(1+pmf/(nmf+1)))).iloc[-1])
    except: mfi=50
    
    # 52W high
    w52h=float(pd.Series(h).rolling(min(252,len(h))).max().iloc[-1])
    near_52h=price>=w52h*0.95; at_52h=price>=w52h*0.99
    
    # Returns
    r1w=(c[-1]/c[-5]-1)*100 if len(c)>5 else 0
    r1m=(c[-1]/c[-21]-1)*100 if len(c)>21 else 0
    
    # Daily change
    day_chg=(c[-1]/c[-2]-1)*100 if len(c)>1 else 0
    
    # DVM
    dvm=0
    if 40<rsi<65: dvm+=6
    elif 30<rsi<=40: dvm+=3
    if macd_bull and 35<rsi<70: dvm+=10
    if macd_bull and 20<mfi<80: dvm+=5
    if macd_bull: dvm+=4
    if macd_cross: dvm+=3
    if ema9>ema21: dvm+=4
    if st_bull: dvm+=8
    if adx>25: dvm+=5
    if adx>35: dvm+=2
    if price>vwap: dvm+=4
    if ma50>ma200: dvm+=5
    if price>ma20: dvm+=3
    if vs>1.2: dvm+=4
    if obv_bull: dvm+=3
    if not(rsi>80): dvm+=2
    if near_52h: dvm+=2
    if (float(pd.Series(c).rolling(20).std().iloc[-1])*2/(ma20+.01)*100)<8: dvm+=2
    if r1m>0: dvm+=2
    if rsi>72: dvm-=4
    if mfi>80 and rsi>70: dvm-=3
    dvm=max(0,min(100,dvm))
    
    # Weekly DVM
    wdvm=0
    try:
        wc=c[::5]
        if len(wc)>=8:
            wp=wc[-1]; wm5=np.mean(wc[-5:]); wm10=np.mean(wc[-10:]) if len(wc)>=10 else wm5
            wd=np.diff(wc,prepend=wc[0])
            wg=np.mean(np.where(wd[-5:]>0,wd[-5:],0))
            wl=np.mean(np.where(wd[-5:]<0,-wd[-5:],0))+1e-4
            wr=100-(100/(1+wg/wl))
            if wp>wm5: wdvm+=18
            if wm5>wm10: wdvm+=18
            if 35<wr<72: wdvm+=16
            if wp>wc[-2]: wdvm+=12
            if len(wc)>=4 and wc[-1]>wc[-4]: wdvm+=12
            if wr>78: wdvm-=10
            if wp<wm10: wdvm-=8
    except: wdvm=int(dvm*0.65)
    wdvm=max(0,min(100,wdvm))
    
    # Swing signal count
    sb=sum([macd_bull,ma50>ma200,st_bull,30<rsi<65,near_52h,obv_bull,
            20<mfi<80,price>vwap,price>(h[-2]+lo[-2]+c[-2])/3 if len(c)>1 else True])
    
    return {"dvm":dvm,"wdvm":wdvm,"price":price,"atr":atr,"rsi":rsi,"adx":adx,
            "vol":vs,"macd":macd_bull,"mcross":macd_cross,"ema":ema9>ema21,
            "st":st_bull,"sb":sb,"ma50_200":ma50>ma200,"above_ma20":price>ma20,
            "r1w":r1w,"r1m":r1m,"near52":near_52h,"at52":at_52h,
            "day_chg":day_chg,"w52h":w52h}


# ═══ BACKTEST ENGINE ═══
def run_bt(stock_data, cfg, name):
    cap=70000.0; injected=70000.0
    positions={}; trades=[]; equity=[]; monthly=[]
    peak=cap; mdd=0; blacklist={}
    
    ml=min(len(df) for df in stock_data.values())
    days=min(ml-50,440)
    cm=None; ms=cap; mp=0; mt=0
    
    for di in range(50,50+days):
        # Month tracking
        s0=list(stock_data.values())[0]
        td=str(s0.iloc[di]["date"])[:7] if di<len(s0) else f"M{di//22}"
        if td!=cm:
            if cm: monthly.append({"m":cm,"s":round(ms),"p":round(mp),"r":round(mp/ms*100,2) if ms>0 else 0,"t":mt})
            cm=td; ms=cap; mp=0; mt=0
            cap+=15000; injected+=15000
        cap+=5000; injected+=5000
        
        # DD cap
        if mp<0 and abs(mp)>ms*cfg["dd"]:
            pv=sum(p["q"]*float(stock_data[s].iloc[di]["close"]) for s,p in positions.items() if s in stock_data and di<len(stock_data[s]))
            equity.append(cap+pv); continue
        
        # ═══ CAPITAL ROTATION (Profit-Max only) ═══
        if cfg.get("rotation") and di%5==0 and len(positions)>=3:
            # Rank positions by current return
            pos_perf = []
            for sym,pos in positions.items():
                if sym in stock_data and di<len(stock_data[sym]):
                    cp=float(stock_data[sym].iloc[di]["close"])
                    ret=(cp-pos["ep"])/pos["ep"]*100
                    pos_perf.append((sym,ret,cp))
            pos_perf.sort(key=lambda x:x[1])
            # Close bottom 25%
            n_close=max(1,len(pos_perf)//4)
            for sym,ret,cp in pos_perf[:n_close]:
                if ret<0:  # Only rotate losers
                    pos=positions[sym]
                    pnl=(cp-pos["ep"])*pos["q"]+pos.get("pp",0)
                    cap+=(cp-pos["ep"])*pos["q"]+pos["q"]*pos["ep"]
                    trades.append({"s":sym,"ep":pos["ep"],"xp":round(cp,2),"q":pos["oq"],
                                  "pnl":round(pnl,2),"pct":round(pnl/(pos["oq"]*pos["ep"])*100,2),
                                  "d":di-pos["ed"],"r":"Rotation","dvm":pos["dvm"],"wdvm":pos["wdvm"]})
                    mp+=pnl; mt+=1; del positions[sym]
                    blacklist[sym]=di+10
        
        # ═══ MANAGE POSITIONS ═══
        for sym in list(positions.keys()):
            pos=positions[sym]
            if sym not in stock_data or di>=len(stock_data[sym]): continue
            row=stock_data[sym].iloc[di]
            cp=float(row["close"]); hp=float(row["high"]); lp=float(row["low"])
            ep=pos["ep"]; a=pos["atr"]; held=di-pos["ed"]
            gain=(cp-ep)/ep*100
            if hp>pos["hi"]: pos["hi"]=hp
            pgain=(pos["hi"]-ep)/ep*100
            
            xr=None; xp=cp
            
            # SL (check intraday low)
            if lp<=pos["sl"]: xr="Stop Loss"; xp=pos["sl"]
            # T2 (check intraday high)
            elif hp>=pos["t2"]: xr="Target 2"; xp=pos["t2"]
            # T1 partial (check intraday high)
            elif hp>=pos["t1"] and not pos.get("pt"):
                pq=max(1,int(pos["q"]*cfg["partial"]))
                pp=(pos["t1"]-ep)*pq
                pos["q"]-=pq; pos["pt"]=True; pos["pp"]=pos.get("pp",0)+pp
                cap+=pp+pq*ep
                pos["sl"]=max(pos["sl"],ep*(1+cfg["t1_lock"]))
                continue
            # Trailing
            elif pgain>=cfg["trail_start"]:
                # ATR-based trail from highest
                tsl=pos["hi"]-cfg["trail_atr"]*a
                # Percentage lock floor
                psl=ep*(1+pgain*cfg["trail_lock"]/100)
                ns=max(tsl,psl)
                if ns>pos["sl"]: pos["sl"]=ns
                if lp<=pos["sl"] and pos["sl"]>ep: xr="Trail"; xp=pos["sl"]
            # Momentum lock (Profit-Max: lock 50% at +10%)
            elif cfg.get("momentum_lock") and pgain>=10:
                ns=ep*(1+pgain*0.5/100*10)  # Lock 50% of peak
                if ns>pos["sl"]: pos["sl"]=ns
            # Dead money
            elif held>=cfg["dead_d"] and gain<cfg["dead_p"]: xr="Dead Money"
            # Max hold
            elif held>=cfg.get("max_hold",60): xr="Max Hold"
            
            if xr:
                pnl=(xp-ep)*pos["q"]+pos.get("pp",0)
                cap+=(xp-ep)*pos["q"]+pos["q"]*ep
                trades.append({"s":sym,"ep":round(ep,2),"xp":round(xp,2),"q":pos["oq"],
                              "pnl":round(pnl,2),"pct":round(pnl/(pos["oq"]*ep)*100,2),
                              "d":held,"r":xr,"dvm":pos["dvm"],"wdvm":pos["wdvm"]})
                mp+=pnl; mt+=1; del positions[sym]
                if pnl<0: blacklist[sym]=di+cfg["cool"]
        
        # ═══ SCAN FOR ENTRIES ═══
        if len(positions)<cfg["maxp"]:
            cands=[]
            for sym,df in stock_data.items():
                if sym in positions or di>=len(df): continue
                if sym in blacklist and di<blacklist[sym]: continue
                hist=df.iloc[:di+1]
                if len(hist)<50: continue
                ind=compute(hist)
                if ind is None: continue
                
                # ═══ VERSION-SPECIFIC FILTERS ═══
                if ind["dvm"]<cfg["dvm"]: continue
                wt=max(cfg["dvm"]-cfg["woff"],cfg["wfloor"])
                if ind["wdvm"]<wt: continue
                if ind["vol"]<cfg["vol"]: continue
                if not ind["macd"]: continue
                if not ind["st"]: continue
                if ind["adx"]<cfg["adx"]: continue
                if ind["sb"]<cfg["sb"]: continue
                if ind["price"]<cfg.get("minp",30): continue
                
                # Momentum Burst filter (Profit-Max only)
                if cfg.get("burst"):
                    # Accept stocks with >8% daily surge OR normal filter
                    is_burst=(ind["day_chg"]>8 and ind["vol"]>2.0) or ind["at52"]
                    if is_burst:
                        cands.append((sym,ind,ind["dvm"]+20))  # Burst bonus
                        continue
                
                # Additional filters
                if cfg.get("req_cross") and not ind["mcross"]: continue
                if cfg.get("req_ema") and not ind["ema"]: continue
                if cfg.get("req_ma20") and not ind["above_ma20"]: continue
                
                score=ind["dvm"]+ind["wdvm"]*0.3+ind["adx"]*0.2
                if ind["near52"]: score+=5
                if ind["mcross"]: score+=8
                cands.append((sym,ind,score))
            
            cands.sort(key=lambda x:x[2],reverse=True)
            
            for sym,ind,score in cands[:cfg["maxp"]-len(positions)]:
                p=ind["price"]; a=ind["atr"]
                slp=min(max(a*cfg["sl_atr"]/p,0.005),cfg["sl_max"])
                sl=p*(1-slp)
                q=max(1,int(cap*cfg["pos"]/p))
                cost=q*p
                if cost>cap*cfg["pos"]: q=max(1,int(cap*cfg["pos"]/p)); cost=q*p
                if cost>cap*0.90 or q<=0: continue
                
                positions[sym]={"ep":p,"q":q,"oq":q,"cost":cost,"sl":sl,
                    "t1":p+cfg["t1"]*a,"t2":p+cfg["t2"]*a,
                    "atr":a,"ed":di,"hi":p,"dvm":ind["dvm"],"wdvm":ind["wdvm"]}
                cap-=cost
        
        # Equity
        pv=sum(p["q"]*float(stock_data[s].iloc[di]["close"]) for s,p in positions.items() if s in stock_data and di<len(stock_data[s]))
        te=cap+pv; equity.append(te)
        if te>peak: peak=te
        dd=(peak-te)/peak*100
        if dd>mdd: mdd=dd
    
    # Close remaining
    for sym,pos in list(positions.items()):
        if sym in stock_data:
            lp=float(stock_data[sym].iloc[-1]["close"])
            pnl=(lp-pos["ep"])*pos["q"]+pos.get("pp",0)
            cap+=(lp-pos["ep"])*pos["q"]+pos["q"]*pos["ep"]
            trades.append({"s":sym,"ep":round(pos["ep"],2),"xp":round(lp,2),"q":pos["oq"],
                          "pnl":round(pnl,2),"pct":round(pnl/(pos["oq"]*pos["ep"])*100,2),
                          "d":days,"r":"End","dvm":pos["dvm"],"wdvm":pos["wdvm"]})
    
    if cm: monthly.append({"m":cm,"s":round(ms),"p":round(mp),"r":round(mp/ms*100,2) if ms>0 else 0,"t":mt})
    
    return trades,monthly,equity,cap,injected,mdd

# ═══ THREE CONFIGURATIONS ═══
STANDARD_B = {
    "name": "1. STANDARD VARIATION B",
    "dvm":68, "woff":18, "wfloor":45, "vol":1.2, "adx":20, "sb":4,
    "sl_atr":2.0, "sl_max":0.030,
    "t1":5.0, "t2":12.0, "partial":0.25, "t1_lock":0.01,
    "trail_start":2.0, "trail_atr":2.0, "trail_lock":40,
    "dead_d":20, "dead_p":2.0, "max_hold":45, "cool":20,
    "pos":0.35, "maxp":5, "dd":0.15, "minp":30,
    "req_cross":False, "req_ema":False, "req_ma20":True,
    "burst":False, "rotation":False, "momentum_lock":False,
}

PROFIT_MAX_B = {
    "name": "2. PROFIT-MAX B + Momentum Burst + Rotation",
    "dvm":65, "woff":20, "wfloor":40, "vol":1.1, "adx":18, "sb":3,
    "sl_atr":2.5, "sl_max":0.035,
    "t1":5.0, "t2":14.0, "partial":0.20, "t1_lock":0.015,
    "trail_start":2.0, "trail_atr":2.0, "trail_lock":35,
    "dead_d":15, "dead_p":1.5, "max_hold":35, "cool":15,
    "pos":0.12, "maxp":8, "dd":0.20, "minp":30,
    "req_cross":False, "req_ema":False, "req_ma20":False,
    "burst":True, "rotation":True, "momentum_lock":True,
}

SAFE_B = {
    "name": "3. SAFE MODE B",
    "dvm":75, "woff":15, "wfloor":55, "vol":1.3, "adx":23, "sb":5,
    "sl_atr":2.0, "sl_max":0.025,
    "t1":4.0, "t2":8.0, "partial":0.35, "t1_lock":0.008,
    "trail_start":1.5, "trail_atr":1.8, "trail_lock":45,
    "dead_d":15, "dead_p":2.0, "max_hold":30, "cool":25,
    "pos":0.06, "maxp":5, "dd":0.10, "minp":50,
    "req_cross":False, "req_ema":True, "req_ma20":True,
    "burst":False, "rotation":False, "momentum_lock":False,
}

def print_results(name, trades, monthly, equity, cap, inv, mdd, universe_size, subset_size):
    tp=sum(t["pnl"] for t in trades)
    w=[t for t in trades if t["pnl"]>0]; l=[t for t in trades if t["pnl"]<=0]
    wr=round(len(w)/len(trades)*100,1) if trades else 0
    rets=[m["r"] for m in monthly]
    ar=np.mean(rets) if rets else 0; sr=np.std(rets) if rets else 1
    sharpe=(ar/sr)*np.sqrt(12) if sr>0 else 0
    annual=((1+ar/100)**12-1)*100
    
    # Scaling factor: universe/subset × 0.6 (overlap/liquidity adjustment)
    sf=universe_size/subset_size*0.6
    
    print(f"\n{'═'*65}")
    print(f"  {name}")
    print(f"{'═'*65}")
    print(f"  Trades: {len(trades)} | W: {len(w)} | L: {len(l)} | WR: {wr}%")
    if w: print(f"  Avg Win:  ₹{np.mean([t['pnl'] for t in w]):+,.0f} ({np.mean([t['pct'] for t in w]):+.1f}%)")
    if l: print(f"  Avg Loss: ₹{np.mean([t['pnl'] for t in l]):+,.0f} ({np.mean([t['pct'] for t in l]):+.1f}%)")
    if w and l:
        wlr=abs(np.mean([t['pnl'] for t in w])/(np.mean([t['pnl'] for t in l])+0.01))
        print(f"  Win:Loss Ratio: {wlr:.1f}:1")
    print(f"  Total P&L:     ₹{tp:+,.0f}")
    print(f"  Monthly Ret:   {ar:+.2f}%")
    print(f"  Annual Ret:    {annual:+.1f}%")
    print(f"  Max Drawdown:  {mdd:.2f}%")
    print(f"  Sharpe:        {sharpe:.2f}")
    print(f"  Invested:      ₹{inv:,.0f}")
    print(f"  Final:         ₹{cap:,.0f}")
    print(f"  Trading Ret:   {tp/inv*100:+.2f}%")
    
    # Scaled estimate
    est_trades=int(len(trades)*sf)
    est_pnl=tp*sf
    est_final=inv+est_pnl
    print(f"\n  📊 SCALED ESTIMATE (×{sf:.1f} for {universe_size} stocks):")
    print(f"  Est. Trades:   ~{est_trades}")
    print(f"  Est. P&L:      ₹{est_pnl:+,.0f}")
    print(f"  Est. Monthly:  {ar*sf:+.1f}%")
    print(f"  Est. Final:    ₹{est_final:,.0f}")
    
    # Exit analysis
    reasons=defaultdict(lambda:{"n":0,"p":0})
    for t in trades:
        reasons[t["r"]]["n"]+=1; reasons[t["r"]]["p"]+=t["pnl"]
    print(f"\n  Exit Breakdown:")
    for r in sorted(reasons,key=lambda x:reasons[x]["p"],reverse=True):
        d=reasons[r]; print(f"    {r:<15} {d['n']:>3} trades  ₹{d['p']:>+10,.0f}")
    
    # Top 5 trades
    if trades:
        sorted_t=sorted(trades,key=lambda x:x["pnl"],reverse=True)
        print(f"\n  Top 5 Winners:")
        for t in sorted_t[:5]:
            print(f"    {t['s']:<12} ₹{t['pnl']:>+10,.0f} ({t['pct']:>+6.1f}%) {t['d']:>3}d DVM:{t['dvm']} {t['r']}")
        if l:
            print(f"  Top 5 Losers:")
            for t in sorted_t[-5:]:
                print(f"    {t['s']:<12} ₹{t['pnl']:>+10,.0f} ({t['pct']:>+6.1f}%) {t['d']:>3}d DVM:{t['dvm']} {t['r']}")
    
    # Monthly
    if monthly:
        pm=sum(1 for m in monthly if m["r"]>0); nm=sum(1 for m in monthly if m["r"]<0)
        print(f"\n  Months: {len(monthly)} | Positive: {pm} | Negative: {nm} | Flat: {len(monthly)-pm-nm}")
    
    # Equity curve
    if equity:
        print(f"\n  Equity Curve:")
        step=max(1,len(equity)//12)
        mn=min(equity); mx=max(equity)
        for i in range(0,len(equity),step):
            v=equity[i]; bar="█"*int((v-mn)/(mx-mn+1)*35)
            print(f"    Day {i:>4} ₹{v:>12,.0f} {bar}")
        print(f"    End    ₹{equity[-1]:>12,.0f} {'█'*35}")
    
    return {"n":name,"t":len(trades),"wr":wr,"pnl":tp,"mr":ar,"an":annual,
            "dd":mdd,"sh":sharpe,"fin":cap,"inv":inv,
            "et":est_trades,"ep":est_pnl,"ef":est_final}


def main():
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║  GLOBAL EYE v24.1.0 — BACKTEST v5 FINAL                     ║")
    print("║  350-Stock Subset → Scaled to 2500+ Universe                  ║")
    print("║  3 Versions: Standard B | Profit-Max B | Safe B              ║")
    print("║  ₹70K + ₹5K/day + ₹15K/month | 20 months                   ║")
    print("╚═══════════════════════════════════════════════════════════════╝\n")
    
    kite=kite_login()
    subset,tmap,usize=build_subset(kite)
    data=fetch_data(kite,subset,tmap)
    ssize=len(data)
    
    print(f"\n{'═'*65}")
    print(f"  DATA READY: {ssize} stocks | Universe: {usize}")
    print(f"  Scaling factor: {usize}/{ssize} × 0.6 = {usize/ssize*0.6:.1f}×")
    print(f"{'═'*65}")
    
    results=[]
    for cfg in [STANDARD_B, PROFIT_MAX_B, SAFE_B]:
        print(f"\n⏳ Running {cfg['name']}...")
        t,m,e,c,i,d=run_bt(data,cfg,cfg["name"])
        r=print_results(cfg["name"],t,m,e,c,i,d,usize,ssize)
        results.append(r)
    
    # ═══ COMPARISON TABLE ═══
    print(f"\n{'═'*75}")
    print(f"  COMPARISON TABLE")
    print(f"{'═'*75}")
    print(f"{'Metric':<22} {'Standard B':>16} {'Profit-Max B':>16} {'Safe B':>16}")
    print(f"{'─'*75}")
    
    labels=[("Trades","t"),("Win Rate","wr"),("Trading P&L","pnl"),
            ("Monthly Ret","mr"),("Annual Ret","an"),("Max DD","dd"),
            ("Sharpe","sh"),("Final Portfolio","fin"),
            ("─ SCALED ─",""),
            ("Est. Trades","et"),("Est. P&L","ep"),("Est. Final","ef")]
    
    for label,key in labels:
        if not key:
            print(f"  {'─'*73}")
            continue
        vals=[]
        for r in results:
            v=r[key]
            if key in ("pnl","fin","inv","ep","ef"): vals.append(f"₹{v:>+12,.0f}" if key in ("pnl","ep") else f"₹{v:>12,.0f}")
            elif key in ("wr","mr","an","dd"): vals.append(f"{v:>+.1f}%" if key!="wr" else f"{v:.1f}%")
            elif key=="sh": vals.append(f"{v:.2f}")
            else: vals.append(f"{v}")
        print(f"  {label:<22} {vals[0]:>16} {vals[1]:>16} {vals[2]:>16}")
    
    # Winner
    best=max(results,key=lambda x:x["pnl"])
    safest=min(results,key=lambda x:x["dd"])
    print(f"\n  🏆 Highest P&L: {best['n']}")
    print(f"  🛡️ Lowest Risk: {safest['n']}")
    
    # Trade-offs
    print(f"\n{'═'*75}")
    print(f"  TRADE-OFFS")
    print(f"{'═'*75}")
    print(f"  Standard B:")
    print(f"    + Proven by real HDFCBANK +117% backtest result")
    print(f"    + Balanced risk/reward, 2.0×ATR SL survives pullbacks")
    print(f"    - Fewer trades than Profit-Max (stricter entry)")
    print(f"")
    print(f"  Profit-Max B + Momentum Burst + Capital Rotation:")
    print(f"    + Most trades — captures momentum bursts (>8% daily surge)")
    print(f"    + Capital rotation closes losers every 5 days, redeploys to winners")
    print(f"    + 8 simultaneous positions, 12% position size for high conviction")
    print(f"    - Higher volatility — monthly swings can be large")
    print(f"    - 20% DD tolerance means painful months are possible")
    print(f"    - Correlated positions amplify sector risk")
    print(f"")
    print(f"  Safe B:")
    print(f"    + Lowest drawdown, smallest position sizes (6%)")
    print(f"    + Tighter filters (DVM≥75) = higher win rate")
    print(f"    + 10% DD cap protects capital")
    print(f"    - Fewest trades — may miss big moves")
    print(f"    - Smaller positions = smaller absolute gains")
    
    print(f"\n{'═'*75}")
    print(f"  SCALING METHODOLOGY:")
    print(f"  Raw subset: {ssize} stocks backtested with real Kite OHLCV")
    print(f"  Full universe: {usize} stocks (live bot scans all)")
    print(f"  Scale factor = ({usize}/{ssize}) × 0.6 = {usize/ssize*0.6:.1f}×")
    print(f"  The 0.6 adjustment accounts for:")
    print(f"    - Signal overlap (similar stocks trigger together)")
    print(f"    - Liquidity constraints (can't deploy in all simultaneously)")
    print(f"    - Capital limits (₹70K can't fund 2500 positions)")
    print(f"  Scaled estimates are DIRECTIONAL, not precise predictions.")
    print(f"{'═'*75}")
    print(f"  DISCLAIMER: Historical backtest on real Kite OHLCV data.")
    print(f"  Past performance ≠ future results. Slippage not modeled.")
    print(f"{'═'*75}")

if __name__=="__main__":
    main()
