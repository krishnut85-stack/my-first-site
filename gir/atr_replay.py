#!/usr/bin/env python3
"""ATR exit replay - same entries, Chandelier 2xATR exits, vs actual ledger."""
import sqlite3, datetime, math, warnings
warnings.filterwarnings("ignore")
import yfinance as yf
DB="paper/trades.db"; ATR_N=14; MULT=2.0
c=sqlite3.connect(DB)
cols=[r[1] for r in c.execute("PRAGMA table_info(paper_trades)")]
exit_col=next((x for x in ("exit_price","exit_px","exit") if x in cols),None)
q=f"SELECT symbol,strategy,qty,entry_price,substr(entry_ts,1,10),substr(exit_ts,1,10),pnl{','+exit_col if exit_col else ''} FROM paper_trades WHERE status='CLOSED' AND strategy IN ('gir_eq','hunter')"
rows=c.execute(q).fetchall()
print(f"Replaying {len(rows)} closed equity trades (gir_eq + hunter)\n")
def atr(df,i):
    trs=[]
    for j in range(max(1,i-ATR_N+1),i+1):
        h,l,pc=df['High'].iloc[j],df['Low'].iloc[j],df['Close'].iloc[j-1]
        trs.append(max(h-l,abs(h-pc),abs(l-pc)))
    return sum(trs)/len(trs) if trs else None
res=[]; skipped=[]
for r in rows:
    sym,strat,qty,ep,ed,xd,old_pnl=r[0],r[1],r[2],r[3],r[4],r[5],r[6]
    try:
        t=yf.Ticker(sym.replace("&","%26") if False else sym+".NS")
        start=(datetime.date.fromisoformat(ed)-datetime.timedelta(days=45)).isoformat()
        df=t.history(start=start,auto_adjust=False)
        if df.empty: skipped.append(sym); continue
        df.index=[d.date() for d in df.index]
        dates=list(df.index)
        ei=next((i for i,d in enumerate(dates) if d>=datetime.date.fromisoformat(ed)),None)
        if ei is None or ei<ATR_N: skipped.append(sym); continue
        a=atr(df,ei)
        if not a or a<=0: skipped.append(sym); continue
        stop=ep-MULT*a; hi=ep; new_exit=None; reason=None
        for i in range(ei,len(dates)):
            o,h,l,cl=df['Open'].iloc[i],df['High'].iloc[i],df['Low'].iloc[i],df['Close'].iloc[i]
            if i>ei and o<=stop: new_exit,reason=o,"GAP_STOP"; break
            if l<=stop: new_exit,reason=stop,"ATR_TRAIL"; break
            hi=max(hi,cl); a2=atr(df,i) or a
            stop=max(stop,hi-MULT*a2)
        if new_exit is None:
            new_exit,reason=df['Close'].iloc[-1],"STILL_OPEN_MTM"
        new_pnl=(new_exit-ep)*qty
        res.append((sym,strat,qty,ep,old_pnl,round(new_pnl,0),reason))
    except Exception as e:
        skipped.append(f"{sym}({e})")
print(f"{'SYMBOL':<14}{'STRAT':<8}{'OLD_PNL':>10}{'ATR_PNL':>10}  EXIT")
for s in sorted(res,key=lambda x:x[5]-x[4],reverse=True):
    print(f"{s[0]:<14}{s[1]:<8}{s[4]:>10.0f}{s[5]:>10.0f}  {s[6]}")
def agg(rs,label):
    if not rs: return
    old=sum(x[4] for x in rs); new=sum(x[5] for x in rs)
    ow=sum(1 for x in rs if x[4]>0); nw=sum(1 for x in rs if x[5]>0)
    print(f"\n{label}: {len(rs)} trades")
    print(f"  OLD exits: {ow}/{len(rs)} wins ({100*ow/len(rs):.0f}%)  net Rs.{old:,.0f}")
    print(f"  ATR exits: {nw}/{len(rs)} wins ({100*nw/len(rs):.0f}%)  net Rs.{new:,.0f}")
    print(f"  DIFFERENCE: Rs.{new-old:+,.0f}")
agg(res,"== ALL ==")
agg([x for x in res if x[1]=='gir_eq'],"gir_eq")
agg([x for x in res if x[1]=='hunter'],"hunter")
if skipped: print(f"\nSkipped ({len(skipped)}): {', '.join(str(s)[:30] for s in skipped[:10])}")
