import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
ink='#1f2937'; mute='#6b7280'
C={'src':('#e0f2fe','#0369a1'),'eye':('#ecfccb','#3f6212'),'num':('#fef3c7','#92400e'),'ai':('#ede9fe','#5b21b6'),
   'gate':('#fee2e2','#991b1b'),'out':('#dcfce7','#166534'),'you':('#1f2937','#1f2937')}
fig=plt.figure(figsize=(7.4,16.2),dpi=170); ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,100); ax.set_ylim(0,220); ax.axis('off')
def box(x,y,w,h,title,lines,kind,new=False,fs=8.6):
    fc,ec=C[kind]
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.4,rounding_size=1.6',fc=fc,ec=ec,lw=1.6))
    tc='white' if kind=='you' else ec
    ax.text(x+w/2,y+h-2.6,title,ha='center',va='top',fontsize=10,fontweight='bold',color=tc)
    if new: ax.text(x+w-1.2,y+h-1.0,'NEW',ha='right',va='top',fontsize=7,fontweight='bold',color='white',
                    bbox=dict(boxstyle='round,pad=0.25',fc='#dc2626',ec='none'))
    for i,l in enumerate(lines):
        ax.text(x+2.2,y+h-7.2-i*3.55,'• '+l,ha='left',va='top',fontsize=fs,color=('white' if kind=='you' else ink))
def arrow(x1,y1,x2,y2,label=None):
    ax.annotate('',xy=(x2,y2),xytext=(x1,y1),arrowprops=dict(arrowstyle='-|>',color=mute,lw=1.6))
    if label: ax.text((x1+x2)/2+1.2,(y1+y2)/2,label,fontsize=7.5,color=mute,va='center')
ax.text(50,218,'GIR - how the new brain works',ha='center',va='top',fontsize=15,fontweight='bold',color=ink)
ax.text(50,213.2,'Top to bottom: information in  ->  thinking  ->  checks  ->  message to you',ha='center',va='top',fontsize=9,color=mute)
box(3,183,94,27,'1 · SOURCES (free feeds)',[
 'World markets + news (US, Asia, Europe, crude, gold, dollar)',
 'NSE prices, OI, option chains  +  market depth (5 levels)',
 'Company filings, results, block deals, broker calls',
 'RBI cash ops, SEBI, government, Parliament, courts',
 'TV (CNBC-TV18, ET Now) · FII / DII money flows',
 'History: 3y minute, 20y daily, years of news (GDELT)'],'src')
arrow(50,183,50,178.5)
box(3,155,45,23,'2 · EYES (code, $0)',['Feeds + recorders','VWAP, RVOL, RSI, breadth','Money flow by sector','Stale / fake price blocks'],'eye')
box(52,155,45,23,'3 · SHOCK ALARMS (code)',['World / India / share shocks','RBI + official news','24 x 7, works with no AI','-> straight to Telegram'],'eye')
arrow(25,155,25,150.5); arrow(74.5,155,74.5,150.5)
box(3,124,45,26.5,'4 · NUMBERS BRAIN ($0)',['M1 tomorrow\'s gap','M2 will the move continue','M3 sectors next 1-5 days','Event library + regime','Trust score per source'],'num',new=True)
box(52,124,45,26.5,'5 · KNOWLEDGE TEAM (AI)',['6 news readers','40 specialist seats','Connections (joins dots)','Max $8 a day','(same 40 seats - no new)'],'ai')
arrow(25,124,40,117.5); arrow(74.5,124,60,117.5)
box(3,95,94,22.5,'6 · AGREEMENT LOOP (AI)',[
 'Head analyst drafts  ->  Devil\'s advocate objects',
 'Head answers with evidence  OR  drops the idea',
 'Only agreed ideas go on · disagreement = "NOT TAKING"',
 'All 12 drivers checked every brief (none skipped)'],'ai',new=True)
arrow(50,95,50,90.5)
box(3,63,94,27.5,'7 · CHECK GATES (code - AI cannot override)',[
 'Evidence: 2 reasons + proven history + devil answered',
 'No chasing: already moved 3%? needs a NEW reason',
 'Grade:  A = BUY   ·   B = WATCH   ·   C = story only',
 'Price must agree: VWAP, sector, market, money flow',
 'Risk: lots, stop, loss / profit lock, 3 trades, 15:10 exit'],'gate',new=True)
arrow(50,63,50,58.5)
box(3,22,94,36.5,'8 · TO YOU: GIR Trade now (short bullet cards)',[
 '19:45 · 07:15 · 09:08 briefs  (open lean + session lean)',
 '14:45 "TOMORROW\'S GAP" card  ->  carry or no carry',
 'Look-ahead ideas: WATCH -> READY -> GO -> DONE',
 'BUY cards (grade A only) · WATCH · NOT TAKING',
 'Shock + RBI alerts with CE / PE names',
 'Manage notes: book half / move stop / exit',
 '15:45 scorecard: right or wrong, how early, who earned it'],'out',new=True)
arrow(50,22,50,17.5)
box(20,5,60,12.5,'YOU decide and trade in Kite',['GIR never places an order'],'you')
ax.annotate('',xy=(1.2,135),xytext=(1.2,40),arrowprops=dict(arrowstyle='-|>',color='#b45309',lw=1.4,connectionstyle='arc3,rad=0'))
ax.text(0.2,88,'scorecard teaches the brain',rotation=90,fontsize=7.2,color='#b45309',va='center')
fig.savefig('/home/user/my-first-site/intraday_patches/explainers/gir_new_flow.png',facecolor='white'); print('ok')
