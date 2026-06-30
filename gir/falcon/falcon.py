#!/usr/bin/env python3
"""FALCON v1 - standalone early-bird F&O paper lane. PAPER ONLY. No real orders, ever."""
# __GIR_TG_TOPIC_ROUTING__ (auto top-inject, lazy env)
try:
 import os as _o, requests as _r
 _b=_r.sessions.Session.request
 def _f(self,*a,**k):
  try:
   u=k.get('url') or (a[1] if len(a)>1 else '')
   if 'sendMessage' in str(u):
    _t=_o.environ.get('TG_THREAD_FALCON','').strip()
    d=k.get('data')
    if _t and isinstance(d,dict) and 'message_thread_id' not in d:
     d=dict(d); d['message_thread_id']=int(_t); k['data']=d
  except Exception: pass
  return _b(self,*a,**k)
 _r.sessions.Session.request=_f
except Exception: pass
# __GIR_TG_TOPIC_ROUTING_END__
import os, sys, json, time, sqlite3, datetime, traceback
from math import log, sqrt, exp, erf
BASE="/home/globalbot"; FDIR=f"{BASE}/falcon"; DB=f"{FDIR}/falcon.db"
IST=datetime.timezone(datetime.timedelta(hours=5,minutes=30))
def now(): return datetime.datetime.now(IST)
def today(): return now().strftime("%Y-%m-%d")
# ---- config ----
OI_VEL_MIN=8.0; IV_RISE_MIN=5.0; SPOT_FLAT_MAX=0.5; PREM_MAX=1.10
LOT_COST_MIN=3000; LOT_COST_MAX=12000; MAX_OPEN=2; MAX_MONTH=5; MONTH_BUDGET=25000
TARGET=1.5; DTE_EXIT=7; STALE_SESSIONS=2; STALE_MIN_GAIN=1.30; RAVEN_FRESH_S=1800
STOP=0.30  # hard stop-loss: cut a losing option once premium is 30% below entry
# ---- env autodetect ----
def env_pick(*subs):
    for k,v in os.environ.items():
        if all(s in k.upper() for s in subs) and v: return v
    return None
TG_TOK=env_pick("TELEGRAM","TOKEN") or env_pick("BOT","TOKEN"); TG_CHAT=env_pick("TELEGRAM","CHAT") or env_pick("CHAT","ID")
def tg(msg):
    try:
        import requests
        if TG_TOK and TG_CHAT: requests.post(f"https://api.telegram.org/bot{TG_TOK}/sendMessage",data={"chat_id":TG_CHAT,"text":"[FALCON] "+msg},timeout=10)
    except Exception: pass
def logln(m):
    print(m); open(f"{FDIR}/falcon.log","a").write(f"{now().isoformat()} {m}\n")
# ---- kite login: reuse RAVEN's, fallback to TOTP flow ----
def get_kite():
    sys.path.insert(0,f"{BASE}/raven")
    try:
        import kite_login as KL
        for fn in ("get_kite","login","get_session","kite_session","main"):
            f=getattr(KL,fn,None)
            if callable(f):
                k=f()
                if k and hasattr(k,"quote"): return k
    except Exception as e: logln(f"raven login reuse failed: {e}")
    import requests, pyotp
    from kiteconnect import KiteConnect
    uid=env_pick("KITE","USER") or env_pick("ZERODHA","USER"); pwd=env_pick("KITE","PASS") or env_pick("ZERODHA","PASS")
    api=env_pick("KITE","API","KEY"); sec=env_pick("KITE","API","SECRET"); totp=env_pick("TOTP") 
    s=requests.Session()
    r=s.post("https://kite.zerodha.com/api/login",data={"user_id":uid,"password":pwd}).json()
    s.post("https://kite.zerodha.com/api/twofa",data={"user_id":uid,"request_id":r["data"]["request_id"],"twofa_value":pyotp.TOTP(totp).now()})
    r=s.get(f"https://kite.zerodha.com/connect/login?v=3&api_key={api}",allow_redirects=True)
    rt=None
    for u in [h.headers.get("location","") for h in r.history]+[r.url]:
        if "request_token=" in u: rt=u.split("request_token=")[1].split("&")[0]
    k=KiteConnect(api_key=api); d=k.generate_session(rt,api_secret=sec); k.set_access_token(d["access_token"]); return k
# ---- Black-Scholes IV ----
def _cdf(x): return 0.5*(1+erf(x/sqrt(2)))
def bs(S,K,T,sig,typ):
    if T<=0 or sig<=0: return max(0.0,(S-K) if typ=="CE" else (K-S))
    d1=(log(S/K)+(0.066+sig*sig/2)*T)/(sig*sqrt(T)); d2=d1-sig*sqrt(T)
    return S*_cdf(d1)-K*exp(-0.066*T)*_cdf(d2) if typ=="CE" else K*exp(-0.066*T)*_cdf(-d2)-S*_cdf(-d1)
def iv(price,S,K,T,typ):
    try:
        if price<=0 or S<=0 or T<=0: return None
        lo,hi=0.01,3.0
        for _ in range(48):
            m=(lo+hi)/2
            if bs(S,K,T,m,typ)>price: hi=m
            else: lo=m
        return round((lo+hi)/2*100,2)
    except Exception: return None
# ---- db ----
def db():
    c=sqlite3.connect(DB)
    c.executescript("""
    CREATE TABLE IF NOT EXISTS snaps(ts TEXT,d TEXT,sym TEXT,und TEXT,ltp REAL,oi INTEGER,vol INTEGER,prevc REAL,spot REAL,ivv REAL,strike REAL,typ TEXT,expiry TEXT,lot INTEGER);
    CREATE TABLE IF NOT EXISTS signals(ts TEXT,d TEXT,sym TEXT,oi_vel REAL,iv_rise REAL,spot_mv REAL,prem_r REAL,lot_cost REAL,raven INTEGER,regime INTEGER,p_oi INTEGER,p_iv INTEGER,p_prem INTEGER,p_cost INTEGER,p_raven INTEGER,p_regime INTEGER,fired INTEGER);
    CREATE TABLE IF NOT EXISTS tickets(id INTEGER PRIMARY KEY,d TEXT,sym TEXT,qty INTEGER,entry REAL,cost REAL,status TEXT,exit_px REAL,exit_ts TEXT,exit_reason TEXT,expiry TEXT,und TEXT,hi_ltp REAL);
    """); return c
# ---- helpers ----
def regime_ok():
    try:
        j=json.load(open(f"{BASE}/fno_regime_last_check.json"))
        s=json.dumps(j).upper()
        if "CHOP" in s or "RANGE" in s: return 0
        return 1
    except Exception: return 1
def raven_syms():
    out={}
    try:
        j=json.load(open(f"{BASE}/raven/raven_signals.json"))
        items=j if isinstance(j,list) else j.get("signals",list(j.values()) if isinstance(j,dict) else [])
        for it in items:
            s=json.dumps(it); 
            ts=None
            for k in ("ts","time","timestamp","seen_at"):
                if isinstance(it,dict) and it.get(k): ts=str(it[k])
            for u in open(f"{FDIR}/universe.txt").read().split():
                if u in s: out[u]=ts or today()
    except Exception: pass
    return out
def universe(kite):
    cache=f"{FDIR}/instr_{today()}.json"
    if os.path.exists(cache): ins=json.load(open(cache))
    else:
        ins=[{k:str(i[k]) for k in ("tradingsymbol","name","strike","expiry","instrument_type","lot_size")} for i in kite.instruments("NFO") if i["segment"]=="NFO-OPT"]
        json.dump(ins,open(cache,"w"))
        for f in os.listdir(FDIR):
            if f.startswith("instr_") and today() not in f: os.remove(f"{FDIR}/{f}")
    unds=[u.strip() for u in open(f"{FDIR}/universe.txt") if u.strip()]
    spots=kite.quote([f"NSE:{u}" for u in unds]); spot={u:spots.get(f"NSE:{u}",{}).get("last_price",0) for u in unds}
    pick=[]
    for u in unds:
        S=spot.get(u) or 0
        if S<=0: continue
        rows=[i for i in ins if i["name"]==u]
        exps=sorted({i["expiry"] for i in rows})
        exps=[e for e in exps if (datetime.datetime.strptime(e[:10],"%Y-%m-%d").date()-now().date()).days>=10]
        if not exps: continue
        e=exps[0]; rows=[i for i in rows if i["expiry"]==e]
        strikes=sorted({float(i["strike"]) for i in rows})
        if not strikes: continue
        atm=min(strikes,key=lambda x:abs(x-S)); ai=strikes.index(atm)
        sel=strikes[max(0,ai-2):ai+3]
        for i in rows:
            if float(i["strike"]) in sel: pick.append((i["tradingsymbol"],u,float(i["strike"]),i["instrument_type"],i["expiry"][:10],int(float(i["lot_size"])),S))
    return pick,spot
def main():
    t=now()
    if t.weekday()>4 or not (t.replace(hour=9,minute=15)<=t<=t.replace(hour=15,minute=31)):
        logln("outside market hours"); return
    c=db(); kite=get_kite()
    pick,spot=universe(kite)
    syms=[f"NFO:{p[0]}" for p in pick]
    quotes={}
    for i in range(0,len(syms),450):
        quotes.update(kite.quote(syms[i:i+450])); time.sleep(0.3)
    rs=raven_syms(); reg=regime_ok(); d=today(); ts=t.isoformat()
    # snapshot + evaluate
    mo=t.strftime("%Y-%m")
    open_n=c.execute("SELECT COUNT(*) FROM tickets WHERE status='OPEN'").fetchone()[0]
    m_n,m_cost=c.execute("SELECT COUNT(*),COALESCE(SUM(cost),0) FROM tickets WHERE d LIKE ?",(mo+"%",)).fetchone()
    fired_this_run=0
    for sym,und,K,typ,exp_,lot,S0 in pick:
        q=quotes.get(f"NFO:{sym}")
        if not q: continue
        ltp=q.get("last_price") or 0; oi=q.get("oi") or 0; vol=q.get("volume") or 0
        prevc=(q.get("ohlc") or {}).get("close") or 0; S=spot.get(und) or S0
        T=max(((datetime.datetime.strptime(exp_,"%Y-%m-%d").date()-t.date()).days),1)/365.0
        ivv=iv(ltp,S,K,T,typ)
        c.execute("INSERT INTO snaps VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(ts,d,sym,und,ltp,oi,vol,prevc,S,ivv,K,typ,exp_,lot))
        base=c.execute("SELECT oi,ivv,spot FROM snaps WHERE d=? AND sym=? ORDER BY ts LIMIT 1",(d,sym)).fetchone()
        if not base or ltp<=0: continue
        b_oi,b_iv,b_spot=base
        oi_vel=((oi-b_oi)/b_oi*100) if b_oi else 0.0
        iv_rise=((ivv-b_iv)/b_iv*100) if (ivv and b_iv) else 0.0
        spot_mv=abs((S-b_spot)/b_spot*100) if b_spot else 0.0
        prem_r=(ltp/prevc) if prevc else 9.9
        cost=ltp*lot
        p=[int(oi_vel>=OI_VEL_MIN),int(iv_rise>=IV_RISE_MIN and spot_mv<=SPOT_FLAT_MAX),int(prem_r<=PREM_MAX),int(LOT_COST_MIN<=cost<=LOT_COST_MAX),int(und in rs),reg]
        fired=int(all(p) and open_n<MAX_OPEN and m_n<MAX_MONTH and m_cost+cost<=MONTH_BUDGET and fired_this_run==0)
        c.execute("INSERT INTO signals VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(ts,d,sym,round(oi_vel,2),round(iv_rise,2),round(spot_mv,2),round(prem_r,3),cost,p[4],reg,p[0],p[1],p[2],p[3],p[4],p[5],fired))
        if fired:
            c.execute("INSERT INTO tickets(d,sym,qty,entry,cost,status,expiry,und,hi_ltp) VALUES(?,?,?,?,?,?,?,?,?)",(d,sym,lot,ltp,cost,"OPEN",exp_,und,ltp))
            open_n+=1; m_n+=1; m_cost+=cost; fired_this_run=1
            tg(f"🦅 PAPER ENTRY {sym} 1 lot ({lot}) @ Rs.{ltp} cost Rs.{cost:.0f}\nOI+{oi_vel:.1f}% IV+{iv_rise:.1f}% spot {spot_mv:.2f}% prem {prem_r:.2f}x RAVEN:{und}\nSL -{STOP*100:.0f}%. Target +150%. Budget {m_n}/{MAX_MONTH}, Rs.{m_cost:.0f}/{MONTH_BUDGET}")
    # exits
    for tid,d0,sym,qty,entry,cost,exp_,und,hi in c.execute("SELECT id,d,sym,qty,entry,cost,expiry,und,hi_ltp FROM tickets WHERE status='OPEN'").fetchall():
        q=quotes.get(f"NFO:{sym}")
        if not q:
            try: q=kite.quote([f"NFO:{sym}"]).get(f"NFO:{sym}")
            except Exception: q=None
        if not q: continue
        ltp=q.get("last_price") or 0; hi=max(hi or 0,ltp)
        c.execute("UPDATE tickets SET hi_ltp=? WHERE id=?",(hi,tid))
        dte=(datetime.datetime.strptime(exp_,"%Y-%m-%d").date()-t.date()).days
        ses=len(c.execute("SELECT DISTINCT d FROM snaps WHERE d>?",(d0,)).fetchall())
        reason=None
        if ltp<=entry*(1-STOP): reason=f"STOP_-{STOP*100:.0f}%"
        elif ltp>=entry*(1+TARGET): reason=f"TARGET_+{TARGET*100:.0f}%"
        elif dte<=DTE_EXIT: reason=f"DTE_{dte}"
        elif ses>=STALE_SESSIONS and ltp<entry*STALE_MIN_GAIN: reason="STALE_NO_MOVE"
        if reason:
            pnl=(ltp-entry)*qty
            c.execute("UPDATE tickets SET status='CLOSED',exit_px=?,exit_ts=?,exit_reason=? WHERE id=?",(ltp,ts,reason,tid))
            tg(f"🦅 PAPER EXIT {sym} {entry}→{ltp} P&L Rs.{pnl:.0f} ({(ltp/entry-1)*100:.0f}%) [{reason}]")
    # EOD summary
    if t.hour==15 and t.minute>=25:
        n,f_=c.execute("SELECT COUNT(*),SUM(fired) FROM signals WHERE d=?",(d,)).fetchone()
        bl=c.execute("SELECT SUM(p_oi),SUM(p_iv),SUM(p_prem),SUM(p_cost),SUM(p_raven),SUM(p_regime) FROM signals WHERE d=?",(d,)).fetchone()
        tg(f"EOD {d}: scans={n} fired={f_ or 0}\nGate passes — OI:{bl[0]} IV:{bl[1]} prem:{bl[2]} cost:{bl[3]} RAVEN:{bl[4]} regime:{bl[5]}\n(lowest number = bottleneck)")
    c.commit(); c.close()
if __name__=="__main__":
    try: main()
    except Exception as e:
        logln(traceback.format_exc()); tg(f"ERROR: {e}")
