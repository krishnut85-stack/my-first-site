#!/usr/bin/env python3
"""Post-entry drift: what happens 1/3/5/10 days after each entry, no exits."""
import sqlite3, datetime, warnings
warnings.filterwarnings("ignore")
import yfinance as yf
c=sqlite3.connect("paper/trades.db")
rows=c.execute("SELECT symbol,strategy,entry_price,substr(entry_ts,1,10) FROM paper_trades WHERE status='CLOSED' AND strategy IN ('gir_eq','hunter')").fetchall()
print(f"Drift study: {len(rows)} entries, horizons D+1/D+3/D+5/D+10\n")
H=[1,3,5,10]; data=[]; skipped=0
for sym,strat,ep,ed in rows:
    try:
        df=yf.Ticker(sym+".NS").history(start=ed,auto_adjust=False)
        if df.empty or len(df)<2: skipped+=1; continue
        closes=list(df['Close'])
        # closes[0] is entry day; D+n = closes[n] if exists else last
        drifts=[]
        for h in H:
            px=closes[h] if h<len(closes) else closes[-1]
            drifts.append(round((px-ep)/ep*100,2))
        data.append((sym,strat,*drifts))
    except Exception: skipped+=1
print(f"{'SYMBOL':<14}{'STRAT':<8}{'D+1%':>7}{'D+3%':>7}{'D+5%':>7}{'D+10%':>7}")
for d in sorted(data,key=lambda x:x[5]):
    print(f"{d[0]:<14}{d[1]:<8}{d[2]:>7.1f}{d[3]:>7.1f}{d[4]:>7.1f}{d[5]:>7.1f}")
def agg(rs,label):
    if not rs: return
    n=len(rs)
    print(f"\n{label} ({n} entries):")
    for i,h in enumerate(H):
        vals=[r[2+i] for r in rs]
        avg=sum(vals)/n; pos=sum(1 for v in vals if v>0)
        print(f"  D+{h:<3} avg {avg:+.2f}%   positive {pos}/{n} ({100*pos/n:.0f}%)")
agg(data,"== ALL ==")
agg([d for d in data if d[1]=='gir_eq'],"gir_eq")
agg([d for d in data if d[1]=='hunter'],"hunter")
if skipped: print(f"\nSkipped: {skipped}")
print("""
READING THE VERDICT:
- Negative avg at ALL horizons -> scanners select losers. Entry logic is the disease. No exit/sizing fix exists.
- Negative D+1/D+3 but positive D+10 -> entries early-but-right; fix = wider stops + longer hold + smaller size.
- Positive D+1 fading later -> momentum is real but brief; fix = take profits fast (1-2 day swing).
- Flat everywhere -> picks are random noise; scanner adds no information.
""")
