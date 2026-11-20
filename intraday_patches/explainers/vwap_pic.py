import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ink, mute, vw, ce, pe, fast, slow = '#1f2937', '#6b7280', '#2563eb', '#15803d', '#b91c1c', '#d97706', '#7c3aed'
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11, 'axes.edgecolor': '#cbd5e1', 'axes.labelcolor': ink,
                     'xtick.color': mute, 'ytick.color': mute})
# ---- intraday story (illustration) ----
t = np.arange(76)                      # 5-min bars 09:15 .. 15:30
key = [(0,100.0),(6,98.9),(10,99.4),(14,100.6),(30,102.6),(44,103.2),(54,102.4),(60,100.6),(66,99.8),(75,99.4)]
price = np.interp(t, [k for k,_ in key], [v for _,v in key])
rng = np.random.default_rng(3); price = price + rng.normal(0, .12, len(t)); price[0] = 100
vol = np.where(t < 12, 3.0, 1.0) * (1 + .4*np.sin(t/5)**2)
vwap = np.cumsum(price*vol)/np.cumsum(vol)
lab = {0:'09:15',9:'10:00',21:'11:00',33:'12:00',45:'13:00',57:'14:00',69:'15:00',75:'15:30'}
fig = plt.figure(figsize=(7.2, 12.6), dpi=170)
gs = fig.add_gridspec(3, 1, height_ratios=[5.2, .1, 4.2], hspace=.32)
a = fig.add_subplot(gs[0]); b = fig.add_subplot(gs[2])
a.fill_between(t, price, vwap, where=price >= vwap, color=ce, alpha=.16, interpolate=True, lw=0)
a.fill_between(t, price, vwap, where=price < vwap, color=pe, alpha=.16, interpolate=True, lw=0)
a.plot(t, price, color=ink, lw=2, label='Share price')
a.plot(t, vwap, color=vw, lw=2.6, label='VWAP (average price paid today)')
a.set_xticks(list(lab)); a.set_xticklabels(list(lab.values()), fontsize=9)
a.set_ylabel('Price (Rs)'); a.grid(axis='y', color='#e5e7eb'); a.set_xlim(0, 75)
for s in ('top','right'): a.spines[s].set_visible(False)
a.set_title('1 · VWAP: who is winning TODAY?', loc='left', fontsize=15, fontweight='bold', color=ink, pad=34)
a.text(0, 1.04, 'One line. Starts fresh at 09:15 every day. Illustration, not real data.', transform=a.transAxes, color=mute, fontsize=10)
ix = int(np.argmax((t > 10) & (price > vwap)))
a.annotate('VWAP RECLAIM\nprice climbs back above\n-> buyers take control\n-> a CE now AGREES', xy=(t[ix], price[ix]), xytext=(12, 98.75), va='top',
           fontsize=10, color=ce, fontweight='bold', arrowprops=dict(arrowstyle='->', color=ce, lw=1.5))
jx = int(np.argmax((t > 40) & (price < vwap)))
a.annotate('VWAP LOST\nprice falls below\n-> sellers take control\n-> GIR: "exit / book the CE"\n-> a PE now AGREES', xy=(t[jx], price[jx]), xytext=(45, 98.75), va='top',
           fontsize=10, color=pe, fontweight='bold', arrowprops=dict(arrowstyle='->', color=pe, lw=1.5))
a.text(30, 101.2, 'GREEN AREA = above VWAP\nbuyers in profit', color=ce, fontsize=10, ha='center')
a.text(4.5, 100.45, 'RED AREA =\nbelow VWAP', color=pe, fontsize=9, ha='center')
a.legend(loc='upper left', frameon=False, fontsize=9.5); a.set_ylim(96.6, 103.9)
a.text(1.0, -0.16, 'How VWAP is worked out: 1,000 shares at Rs 100 + 3,000 at Rs 102 + 2,000 at Rs 101\n'
       '= Rs 6,08,000 for 6,000 shares -> VWAP = Rs 101.33 (the average buyer\'s price today)',
       transform=a.transAxes, ha='right', fontsize=9, color=ink, bbox=dict(boxstyle='round,pad=.5', fc='#f1f5f9', ec='#cbd5e1'))
# ---- crossover lag (daily) ----
d = np.arange(90)
p = np.interp(d, [0,35,45,70,89], [110,96,97,118,121]) + rng.normal(0, .7, 90)
ema = lambda x, n: np.array([x[:i+1][-n:].mean() for i in range(len(x))])
f9, s21 = ema(p, 9), ema(p, 21)
b.plot(d, p, color=ink, lw=1.6, label='Share price (daily closes)')
b.plot(d, f9, color=fast, lw=2.2, label='Fast average (green line on your chart)')
b.plot(d, s21, color=slow, lw=2.2, label='Slow average (red line on your chart)')
start = 40; cross = int(np.argmax((d > 40) & (f9 > s21)))
b.axvline(start, color=ce, ls='--', lw=1.3); b.axvline(cross, color=mute, ls=':', lw=1.5)
b.annotate('The rise STARTS here', xy=(start, p[start]), xytext=(14, 90.5), fontsize=10, color=ce, fontweight='bold',
           arrowprops=dict(arrowstyle='->', color=ce, lw=1.4))
gone = (p[cross]-p[start])/(p[-1]-p[start])*100
b.annotate(f'Lines CROSS only here\n(about {gone:.0f}% of the rise\nalready gone)', xy=(cross, f9[cross]), xytext=(cross+5, 92.5), va='top',
           fontsize=10, color=ink, fontweight='bold', arrowprops=dict(arrowstyle='->', color=ink, lw=1.4))
b.set_title('2 · Green line crossing red line = a CROSSOVER (not VWAP)', loc='left', fontsize=13.5, fontweight='bold', color=ink, pad=34)
b.text(0, 1.04, 'Averages of PAST prices, so the cross always comes late. A share does NOT need it to go up.', transform=b.transAxes, color=mute, fontsize=10)
b.set_xlabel('Days'); b.set_ylabel('Price (Rs)'); b.grid(axis='y', color='#e5e7eb'); b.set_xlim(0, 89)
for s in ('top','right'): b.spines[s].set_visible(False)
b.legend(loc='upper left', frameon=False, fontsize=9.5); b.set_ylim(86, 126)
fig.text(.5, .015, 'GIR: the REASON to buy comes from the desk (news, sector, flows, last evening\'s prediction).\n'
         'VWAP only checks that TODAY\'S PRICE AGREES: CE above VWAP, PE below VWAP.', ha='center', fontsize=10.5, color=ink, fontweight='bold')
fig.savefig('vwap_explained.png', bbox_inches='tight', facecolor='white'); print('ok', cross, round(gone))
