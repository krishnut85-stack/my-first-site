# C1 - THE EVENING PREDICTION (19:45 / 22:45 / 07:15 / 09:08) - proof (revised 20 Nov evening: A6b MOVER lines, A6c EXTREME, CE BOUNCE, thin pre-open)

Built in `v2/predict/` (new modules; v2/engine and v2/engine_next not changed). Code builds and ranks; nothing is sent. Every version
writes new rows to an append-only store (`v2/data/predict/predictions.jsonl`, `candidate_log.jsonl` = every share both sides,
`market_day_call.jsonl`) with made_at, computed_at, the inputs window, evidence IDs, trigger, cancel, expected move and grade.

## What one version carries
- **Side lines** (WILL GO UP = CE / WILL GO DOWN = PE): only when a driver row (news / broker / TV / block deal) lifts a line to MEDIUM;
  each line: sector, role, WHY with the other side of each driver, AGAINST, trigger (yesterday's high / low, 1-minute close, RVOL 2 on
  its side of VWAP), cancel price (final at 09:08 from NSE's matched pre-open price), expected move, grade with the side's base rate,
  NOT CALIBRATED, chips. WATCH ONLY fold (WEAK, never rings) when a side has fewer than 3.
- **MOVER (side open)** lines (A6b): 25 a version from the measured move score alone - the list is never empty. Both triggers (CE above
  yesterday's high / the opening-range high after a gap up; PE below yesterday's low / the opening-range low after a gap down; RVOL 2);
  the first trigger that fires with the sector and NIFTY not against it sets the side, the other is cancelled.
- **CE BOUNCE (on the turn)** lines (desk 13:30): up to 4 OVERSOLD shares, only above yesterday's high AND VWAP with RVOL 2, sector not
  falling, no fresh bad news in 2 sessions; chip with the measured record and the market state (weak / strong vs NIFTY's 50-day average).
- **EXTREME** (A6c: RSI14 >= 80 or 10%+ above the 20-day average): no CE breakout - only the VWAP pullback hold after 09:30; PE only on
  the turn; chip 'EXTREME RSI nn - 81% corrected within 20 days (median -7.6%), n=318'.
- **KNOWLEDGE CHAINS** fold: IDEA - NOT PROVEN, weight 0 (no chain row passes the PROVEN bar; blind test 221 of 459 = 48%).
- Market-day call UP / DOWN / MIXED with probabilities (always MIXED today - see the evidence); information cues (GIFT NIFTY, stale = not known).
- **Thin pre-open rule**: a pre-open row with final quantity 0, or at a price band with buy/sell < 0.05 (> 20), is dropped as 'thin
  pre-open - not a price'; P09 uses only snapshots from 09:08 on (replays of older stored files use the 09:15 open and say so).

## The evidence (why the side is NOT PROVEN)
### 1. The code layer on 5 years of daily data (`python3 -m predict.study`)
```
LAYER-1 CODE CHECK (predict/study.py) - made 2026-11-20T15:57:51+05:30
train 2022-02-09 .. 2025-11-14 · held-out after 2025-11-14 (251 sessions) · label: next session 2%+ from the open (daily high / low; tradable-leg approximation)

feature                                                       kind  w   gap(top-bottom fifth)  same sign
F01 day return                                                 dir  +0   -0.98 pts             3 of 4
F02 5-day return                                               dir  -1   -2.25 pts             4 of 4
F03 close location in the day's range                          dir  +0   +0.89 pts             3 of 4
F04 return vs its sector (relative strength)                   dir  -1   -2.88 pts             4 of 4
F05 sector median return today                                 dir  +1   +2.02 pts             4 of 4
F06 sector 3-day run                                           dir  +1   +1.64 pts             4 of 4
F07 room to the 20-day high minus room to the 20-day low (ATR) dir  +0   +0.12 pts             3 of 4
F08 volume on the day's side (RVOL x sign)                     dir  +0   -0.37 pts             3 of 4
F09 futures build-up (long +1 / short cover +0.5 / long unwind dir  +0   -0.58 pts             4 of 4
F10 ATR14 % (how much it usually moves)                        mag  +1  +46.04 pts             4 of 4
F11 RVOL at the close (day volume / 20-day median)             mag  +1  +12.51 pts             4 of 4
F12 NR7 inside / narrow day                                    mag  -1   -4.08 pts             4 of 4
F13 size of today's move (absolute day return)                 mag  +1  +22.25 pts             4 of 4
F14 size of the 5-day move (absolute)                          mag  +1  +22.68 pts             4 of 4
  (dir gap = (up rate - down rate) top fifth minus bottom fifth; mag gap = 2%-either-way rate top minus bottom)

HELD-OUT CE: top 8 a day right 28.9% · base 21.2% (lift 1.36) · volatility-only list 35.8% (lift 0.81; the same 8 shares named on BOTH sides) · 2008 lines
HELD-OUT PE: top 8 a day right 34.6% · base 23.5% (lift 1.47) · volatility-only list 42.6% (lift 0.81; the same 8 shares named on BOTH sides) · 2008 lines
DIRECTION TEST (a coin = 50%): named shares that moved 2% either way went OUR way 50.1% (n=2285) · strongest direction fifth of all shares 50.5% (n=4773)
VERDICT: the list beats the base rate mostly by naming shares that move a lot; the SIDE is right 50% of the time -> NOT PROVEN. Every card carries NOT PROVEN until the live scorecard shows +8 pts over baselines for 20 days (E7).
```
### 2. preopenstudy.py (desk G1, 3 years of minutes, tuning | held-out) - section 0 in short
| when | CE list | PE list | market read side accuracy |
|---|---|---|---|
| 19:45 | COIL AT THE EDGE: no better than random (lift 1.04) | CLOSE-STRENGTH top 10 in 3 named sectors: picks, but no better than the plain movers list (1.17 \| 1.15) | 43% \| 39% (a coin or worse) |
| 09:08 | no better than random | no better than random (1.09 \| 1.14) | 44% \| 46% |
| 09:20 | no better than random | no better than random | 43% \| 50% on the moves still to come (NEUTRAL 84% \| 79% of days); 67% \| 69% only 'from the open, includes the minutes already seen' |
| 09:30 | no better than random | no better than random | - |
| 09:45 | LAGGARD list picks (1.23 \| 1.19) but named 14 min after half the move | no better than random | - |
Sector reads hardly beat random sectors at any time. So **nothing names the side before the open better than a coin**: every side line
and every MOVER line says NOT PROVEN; the 09:20 read is NOT wired as a side driver (on the moves still to come it is a coin).
### 3. Market-day call: on the held-out year neither the US close nor the NIFTY gap moved the open -> 15:10 day type; the call stays MIXED
(all-days base up 19% / down 21% / mixed 61%). It was right on 2 of the 6 test days below (the 3 up days were all called MIXED).

## MOVER list size - set on TUNING days only (23, 26, 28, 30 Oct, 2-6, 9, 11-13, 17 Nov; point-in-time each), then tested
```
days 14 all-names 2pct-either base 45%
N= 5 lines  70 moved2%  47 (67%) fired  17 early   1/day 0.1 right   8 wrong   7 tradable   4 (right-of-fired 47%)
N= 8 lines 112 moved2%  73 (65%) fired  23 early   2/day 0.1 right  12 wrong   7 tradable   5 (right-of-fired 52%)
N=10 lines 140 moved2%  91 (65%) fired  29 early   4/day 0.3 right  15 wrong   8 tradable   8 (right-of-fired 52%)
N=12 lines 168 moved2% 105 (62%) fired  34 early   7/day 0.5 right  19 wrong   8 tradable  11 (right-of-fired 56%)
N=15 lines 210 moved2% 133 (63%) fired  46 early  11/day 0.8 right  26 wrong  10 tradable  15 (right-of-fired 57%)
N=20 lines 280 moved2% 174 (62%) fired  62 early  15/day 1.1 right  36 wrong  13 tradable  19 (right-of-fired 58%)
N=25 lines 350 moved2% 213 (61%) fired  83 early  23/day 1.6 right  51 wrong  17 tradable  25 (right-of-fired 61%)
```
TEST days (20, 16, 18, 19 Nov, 29 Oct = the October up day, 27 Oct = the last expiry day; never used to choose N):
```
days 6 all-names 2pct-either base 38%
N= 5 lines  30 moved2%  19 (63%) fired  11 early   3/day 0.5 right  10 wrong   1 tradable   4 (right-of-fired 91%)
N= 8 lines  48 moved2%  28 (58%) fired  17 early   4/day 0.7 right  13 wrong   2 tradable   4 (right-of-fired 76%)
N=10 lines  60 moved2%  35 (58%) fired  21 early   5/day 0.8 right  14 wrong   4 tradable   5 (right-of-fired 67%)
N=12 lines  72 moved2%  42 (58%) fired  24 early   5/day 0.8 right  15 wrong   5 tradable   5 (right-of-fired 62%)
N=15 lines  90 moved2%  50 (56%) fired  30 early   6/day 1.0 right  18 wrong   7 tradable   7 (right-of-fired 60%)
N=20 lines 120 moved2%  60 (50%) fired  34 early   8/day 1.3 right  19 wrong   7 tradable   9 (right-of-fired 56%)
N=25 lines 150 moved2%  76 (51%) fired  42 early   9/day 1.5 right  23 wrong  11 tradable  11 (right-of-fired 55%)
```
Read: with N = 25 the MOVER lines move 2% either way about half the time (51% vs 38% of all names on the test days); 42 fired, 23 on the
right side, 11 wrong (2 : 1); but only **1.5 early cards a day** (trigger before half the move) - far below the E2 pass mark of 10. The
pass mark is NOT met by the prediction lane; the desk's B3 watch-point stands.

## Point-in-time tests, one per day (each made as if on the evening before; inputs only by their first-seen time; scored on the minute store)
20 Nov = the requested test: made as if Thu 19 Nov 19:45 (+ 22:45 / 07:15 / 09:08), scored against 20 Nov after the close.

### 2026-11-20 - predicted on the evening of 2026-11-19 (point-in-time)

#### N19 (made 2026-11-19T19:45:00+05:30) - driver rows seen 40
```
PREDICTION N19 for 2026-11-20 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KALYANKJIL at 2.34.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best IREDA at 2.56.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE AUTOS BAJAJ-AUTO/SONACOMS/BHARATFORG · CE AVIATION INDIGO · CE NBFC BAJFINANCE · PE ELECTRONICS DIXON/AMBER/PGEL/SYRMA · PE OIL & GAS PETRONET · CE PAINTS ASIANPAINT · PE METALS HINDALCO/NATIONALUM/HINDZINC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1653.70 · OVERSOLD RSI 25 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6755.00 / PE below 6241.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1775.20 / PE below 1621.80 (RVOL 2)
  ◆ IREDA · nbfc & finance · CE above 133.60 / PE below 119.70 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 167.70 / PE below 160.96 (RVOL 2)
  ◆ VOLTAS · consumer durables · CE above 1243.70 / PE below 1131.00 (RVOL 2)
  ◆ PAYTM · nbfc & finance · CE above 1808.90 / PE below 1664.30 (RVOL 2)
  ◆ TMPV · auto · CE above 263.50 / PE below 251.50 (RVOL 2)
  ◆ EICHERMOT · auto · CE above 8072.50 / PE below 7675.00 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 220.00 / PE below 207.21 (RVOL 2)
  ◆ DELHIVERY · services · CE above 459.20 / PE below 439.20 (RVOL 2)
  ◆ HYUNDAI · auto · CE above 2235.60 / PE below 2082.60 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 285.90 / PE below 272.50 (RVOL 2)
  ◆ INOXWIND · capital goods · CE above 58.56 / PE below 56.66 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 162.90 / PE below 157.70 (RVOL 2)
  ◆ M&M · auto · CE above 3525.90 / PE below 3333.10 (RVOL 2)
  ◆ IDFCFIRSTB · banks · CE above 86.73 / PE below 82.41 (RVOL 2)
  ◆ PNB · banks · CE above 156.49 / PE below 149.75 (RVOL 2)
  ◆ POLYCAB · capital goods · CE above 7571.00 / PE below 7238.00 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2635.20 / PE below 2553.80 (RVOL 2)
  ◆ MAHABANK · banks · CE above 98.72 / PE below 95.81 (RVOL 2)
  ◆ BDL · capital goods · CE above 1043.20 / PE below 1013.35 (RVOL 2)
  ◆ BHARATFORG · auto · CE above 1734.50 / PE below 1688.00 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20497.00 / PE below 19950.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4141.50 / PE below 3985.90 (RVOL 2) · lean UP from broker - NOT PROVEN (side still decided by price)
  ◆ KALYANKJIL · consumer durables · CE above 663.00 / PE below 638.60 (RVOL 2)
```
#### C22 (made 2026-11-19T22:45:00+05:30) - driver rows seen 48
```
PREDICTION C22 for 2026-11-20 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  ▲ KALYANKJIL · consumer durables · trigger > 663.00 vol 2x · cancel < 655.71 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 22:01 · class B source · (other side) Gold near 14-month low: Muthoot Finance, Ma · against no evidence row against - and the side of the daily features is right 
  WATCH ONLY - below the bar: TITAN (consumer durables)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best IREDA at 2.56.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE AUTOS BAJAJ-AUTO/SONACOMS/BHARATFORG · CE AVIATION INDIGO · CE NBFC BAJFINANCE · PE ELECTRONICS DIXON/AMBER/PGEL/SYRMA · PE OIL & GAS PETRONET · CE PAINTS ASIANPAINT · PE METALS HINDALCO/NATIONALUM/HINDZINC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1653.70 · OVERSOLD RSI 25 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6755.00 / PE below 6241.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1775.20 / PE below 1621.80 (RVOL 2)
  ◆ IREDA · nbfc & finance · CE above 133.60 / PE below 119.70 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 167.70 / PE below 160.96 (RVOL 2)
  ◆ VOLTAS · consumer durables · CE above 1243.70 / PE below 1131.00 (RVOL 2)
  ◆ PAYTM · nbfc & finance · CE above 1808.90 / PE below 1664.30 (RVOL 2)
  ◆ TMPV · auto · CE above 263.50 / PE below 251.50 (RVOL 2)
  ◆ EICHERMOT · auto · CE above 8072.50 / PE below 7675.00 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 220.00 / PE below 207.21 (RVOL 2)
  ◆ DELHIVERY · services · CE above 459.20 / PE below 439.20 (RVOL 2)
  ◆ HYUNDAI · auto · CE above 2235.60 / PE below 2082.60 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 285.90 / PE below 272.50 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price)
  ◆ INOXWIND · capital goods · CE above 58.56 / PE below 56.66 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 162.90 / PE below 157.70 (RVOL 2)
  ◆ M&M · auto · CE above 3525.90 / PE below 3333.10 (RVOL 2)
  ◆ IDFCFIRSTB · banks · CE above 86.73 / PE below 82.41 (RVOL 2)
  ◆ PNB · banks · CE above 156.49 / PE below 149.75 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price)
  ◆ POLYCAB · capital goods · CE above 7571.00 / PE below 7238.00 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2635.20 / PE below 2553.80 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price)
  ◆ MAHABANK · banks · CE above 98.72 / PE below 95.81 (RVOL 2)
  ◆ BDL · capital goods · CE above 1043.20 / PE below 1013.35 (RVOL 2)
  ◆ BHARATFORG · auto · CE above 1734.50 / PE below 1688.00 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20497.00 / PE below 19950.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4141.50 / PE below 3985.90 (RVOL 2) · lean UP from broker - NOT PROVEN (side still decided by price)
  ◆ MARUTI · auto · CE above 13617.00 / PE below 12602.00 (RVOL 2)
```
#### U07 (made 2026-11-20T07:15:00+05:30) - driver rows seen 45
```
PREDICTION U07 for 2026-11-20 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  ▲ KALYANKJIL · consumer durables · trigger > 663.00 vol 2x · cancel < 655.71 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 22:01 · class B source · (other side) Gold near 14-month low: Muthoot Finance, Ma · against no evidence row against - and the side of the daily features is right 
  ▲ TMPV · auto · trigger > 263.50 vol 2x · cancel < 261.39 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 22:59 · class C source · Tata Motors Passenger Vehicles Posts Record ₹20,000 Cror · against return vs its sector (relative strength) = +0.017 points the other way
  ▲ WAAREEENER · capital goods · trigger > 2447.50 vol 2x · cancel < 2413.54 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 23:43 · class B source · Waaree Energies arm bags over ₹100 crore NTPC order for  · against sector 3-day run = -0.006 points the other way
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best IREDA at 2.56.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1653.70 · OVERSOLD RSI 25 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6755.00 / PE below 6241.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1775.20 / PE below 1621.80 (RVOL 2)
  ◆ IREDA · nbfc & finance · CE above 133.60 / PE below 119.70 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 167.70 / PE below 160.96 (RVOL 2)
  ◆ VOLTAS · consumer durables · CE above 1243.70 / PE below 1131.00 (RVOL 2)
  ◆ PAYTM · nbfc & finance · CE above 1808.90 / PE below 1664.30 (RVOL 2)
  ◆ EICHERMOT · auto · CE above 8072.50 / PE below 7675.00 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 220.00 / PE below 207.21 (RVOL 2)
  ◆ DELHIVERY · services · CE above 459.20 / PE below 439.20 (RVOL 2)
  ◆ HYUNDAI · auto · CE above 2235.60 / PE below 2082.60 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 285.90 / PE below 272.50 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price)
  ◆ INOXWIND · capital goods · CE above 58.56 / PE below 56.66 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price)
  ◆ BANKINDIA · banks · CE above 162.90 / PE below 157.70 (RVOL 2)
  ◆ M&M · auto · CE above 3525.90 / PE below 3333.10 (RVOL 2)
  ◆ IDFCFIRSTB · banks · CE above 86.73 / PE below 82.41 (RVOL 2)
  ◆ PNB · banks · CE above 156.49 / PE below 149.75 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price)
  ◆ POLYCAB · capital goods · CE above 7571.00 / PE below 7238.00 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2635.20 / PE below 2553.80 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price)
  ◆ MAHABANK · banks · CE above 98.72 / PE below 95.81 (RVOL 2)
  ◆ BDL · capital goods · CE above 1043.20 / PE below 1013.35 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price)
  ◆ BHARATFORG · auto · CE above 1734.50 / PE below 1688.00 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20497.00 / PE below 19950.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4141.50 / PE below 3985.90 (RVOL 2) · lean UP from broker - NOT PROVEN (side still decided by price)
  ◆ MARUTI · auto · CE above 13617.00 / PE below 12602.00 (RVOL 2)
  ◆ RVNL · construction · CE above 195.85 / PE below 187.23 (RVOL 2)
```
#### P09 (made 2026-11-20T09:08:00+05:30) - driver rows seen 77
```
PREDICTION P09 for 2026-11-20 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  ▲ WAAREEENER · capital goods · trigger > 2447.50 vol 2x · cancel < 2399.65 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 23:43 · class B source · Waaree Energies arm bags over ₹100 crore NTPC order for  · against sector 3-day run = -0.006 points the other way · ARMED - SOFT AGAINST
  ▲ KALYANKJIL · consumer durables · trigger > 663.00 vol 2x · cancel < 643.71 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 22:01 · class B source · (other side) Gold near 14-month low: Muthoot Finance, Ma · against no evidence row against - and the side of the daily features is right  · AT RISK (gap against)
  ▲ TMPV · auto · trigger > 263.50 vol 2x · cancel < 260.20 · MEDIUM (base 30%) - NOT CALIBRATED · why NEWS Thu 22:59 · class C source · Tata Motors Passenger Vehicles Posts Record ₹20,000 Cror · against return vs its sector (relative strength) = +0.017 points the other way · ARMED - SOFT AGAINST
  ▲ BANKINDIA · banks · trigger > 162.90 vol 2x · cancel < 159.22 · MEDIUM (base 30%) - NOT CALIBRATED · why TV Fri 08:20 · TV ONLY - UNVERIFIED · ON TV 08:20:55 (CNBC-TV18, Goldman): BANKINDIA BUY - · against 5-day return = +0.069 points the other way · ARMED - SOFT AGAINST
WILL GO DOWN (PE):
  ▼ MUTHOOTFIN · nbfc & finance · trigger < 2553.80 vol 2x · cancel > 2539.15 · MEDIUM (base 22%) - NOT CALIBRATED · why NEWS Thu 22:01 · class B source · Gold near 14-month low: Muthoot Finance, Manappuram, IIF · against 5-day return = -0.107 points the other way · GAP TOOK IT
  ▼ ALKEM · pharma · trigger < 5115.00 vol 2x · cancel > 5195.74 · MEDIUM (base 22%) - NOT CALIBRATED · why NEWS Fri 07:45 · class C source · Alkem Labs receives USFDA warning letter for Daman facil · against 5-day return = -0.030 points the other way · ARMED (flat)
  ▼ MANAPPURAM · nbfc & finance · trigger < 276.10 vol 2x · cancel > 275.18 · MEDIUM (base 22%) - NOT CALIBRATED · why NEWS Fri 07:39 · class C source · Manappuram Finance gold-loan Stage 2 stress reaches 5% · against 5-day return = -0.116 points the other way · GAP TOOK IT
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1653.70 · OVERSOLD RSI 25 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6755.00 / PE below 6241.00 (RVOL 2) · ARMED (both triggers)
  ◆ BLUESTARCO · consumer durables · CE above 1775.20 / PE below 1621.80 (RVOL 2) · ARMED (both triggers)
  ◆ IREDA · nbfc & finance · CE above 133.60 / PE below 119.70 (RVOL 2) · ARMED (both triggers)
  ◆ ASHOKLEY · auto · CE above 167.70 / PE below 160.96 (RVOL 2) · ARMED (both triggers)
  ◆ VOLTAS · consumer durables · CE above 1243.70 / PE below 1131.00 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ PAYTM · nbfc & finance · CE above 1808.90 / PE below 1664.30 (RVOL 2) · lean DOWN from tv - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ EICHERMOT · auto · CE above 8072.50 / PE below 7675.00 (RVOL 2) · ARMED (both triggers)
  ◆ CROMPTON · consumer durables · CE above 220.00 / PE below 207.21 (RVOL 2) · ARMED (both triggers)
  ◆ DELHIVERY · services · CE above 459.20 / PE below 439.20 (RVOL 2) · ARMED (both triggers)
  ◆ HYUNDAI · auto · CE above 2235.60 / PE below 2082.60 (RVOL 2) · ARMED (both triggers)
  ◆ BANKBARODA · banks · CE above 285.90 / PE below 272.50 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ INOXWIND · capital goods · CE above 58.56 / PE below 56.66 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ M&M · auto · CE above 3525.90 / PE below 3333.10 (RVOL 2) · ARMED (both triggers)
  ◆ IDFCFIRSTB · banks · CE above 86.73 / PE below 82.41 (RVOL 2) · ARMED (both triggers)
  ◆ PNB · banks · CE above 156.49 / PE below 149.75 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ POLYCAB · capital goods · CE above 7571.00 / PE below 7238.00 (RVOL 2) · ARMED (both triggers)
  ◆ MAHABANK · banks · CE above 98.72 / PE below 95.81 (RVOL 2) · ARMED (both triggers)
  ◆ BDL · capital goods · CE above 1043.20 / PE below 1013.35 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ BHARATFORG · auto · CE above 1734.50 / PE below 1688.00 (RVOL 2) · ARMED (both triggers)
  ◆ FORCEMOT · auto · CE above 20497.00 / PE below 19950.00 (RVOL 2) · ARMED (both triggers)
  ◆ CUMMINSIND · capital goods · CE above 4141.50 / PE below 3985.90 (RVOL 2) · lean UP from broker - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ MARUTI · auto · CE above 13617.00 / PE below 12602.00 (RVOL 2) · lean UP from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
  ◆ IRFC · nbfc & finance · CE above 84.89 / PE below 80.56 (RVOL 2) · ARMED (both triggers)
  ◆ POLICYBZR · nbfc & finance · CE above 1027.10 / PE below 970.40 (RVOL 2) · ARMED (both triggers)
  ◆ HEROMOTOCO · auto · CE above 5560.50 / PE below 5261.50 (RVOL 2) · lean DOWN from news - NOT PROVEN (side still decided by price) · ARMED (both triggers)
```
Pre-open input: NSE pre-open file preopen.json (nse_t 20-Nov-2026 09:09:34)


#### Scorecard 2026-11-20
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 +1.44%, real UP)
PREDICTED N19 · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -34 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 11 (all names 40%)
PREDICTED C22 · CE scored 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -34 pts · CE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -34 pts · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -34 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 11 (all names 40%)
PREDICTED U07 · CE scored 3: right 0 (0 tradable), flat 2, wrong 1 · beat the day -34 pts · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -34 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 11 (all names 40%)
PREDICTED P09 · CE scored 4: right 1 (0 tradable), flat 2, wrong 1 · beat the day -9 pts · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -34 pts · PE scored 3: right 0 (0 tradable), flat 1, wrong 2 · beat the day -6 pts · MOVER (side open) 25: fired 10 (early 1), right side 6 (1 tradable), wrong 0, flat 4 · moved 2% either way 10 (all names 40%)
EARLY CARDS (trigger before half the move): side lines 1 · MOVER lines 1 · total 2 (E2 pass mark 10)
CONFIRMATIONS 2 (rung 2) · too late 8 · failed 4 · silent cards 4 · NOT PREDICTED movers shown 36
BASE RATE: CE 34% / PE 6% of 218 F&O names moved 2% its way · day movers CE 75 / PE 14
KNOWLEDGE CHAINS (IDEA, weight 0): CE 3 named, 1 moved 2% its way, 0 2% against · PE 19 named, 1 its way, 7 against
MISSED 2%+ movers 82 · 3%+: INDUSINDBK CE 10.0%, COFORGE CE 7.0%, TATAELXSI CE 6.5%, CUB CE 6.2%, PERSISTENT CE 6.2%, RBLBANK CE 5.4%, LTM CE 5.2%, AXISBANK CE 5.1%, ANGELONE CE 5.0%, KALYANKJIL PE 4.9%
BASELINES: yesterday's movers CE 7 / PE 0 · volatility-only 8: CE 2 / PE 2 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

### 2026-11-16 - predicted on the evening of 2026-11-15 (point-in-time)

#### N19 (made 2026-11-15T19:45:00+05:30) - driver rows seen 47
```
PREDICTION N19 for 2026-11-16 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best BDL at 1.95.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POLICYBZR at 2.27.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · CE OIL PRODUCERS ONGC/OIL · CE IT INFY/COFORGE/HCLTECH/LTM · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · PE CAPITAL MARKETS MCX · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1741.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6980.00 / PE below 6000.00 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3222.30 / PE below 3030.20 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4464.80 / PE below 4180.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4425.60 / PE below 4240.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 353.15 / PE below 337.05 (RVOL 2)
  ◆ BDL · capital goods · CE above 1059.35 / PE below 1023.50 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 718.05 / PE below 685.10 (RVOL 2)
  ◆ MANAPPURAM · nbfc & finance · CE above 327.00 / PE below 304.65 (RVOL 2)
  ◆ POWERINDIA · capital goods · CE above 32250.00 / PE below 29950.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1112.40 / PE below 1021.40 (RVOL 2)
  ◆ COROMANDEL · chemicals · CE above 1994.30 / PE below 1932.70 (RVOL 2)
  ◆ ABB · capital goods · CE above 7120.00 / PE below 6922.00 (RVOL 2)
  ◆ ALKEM · pharma · CE above 5300.50 / PE below 5103.50 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4324.40 / PE below 4151.50 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 32640.00 / PE below 31290.00 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1195.00 / PE below 1176.00 (RVOL 2)
  ◆ ABCAPITAL · nbfc & finance · CE above 416.05 / PE below 407.05 (RVOL 2)
  ◆ MCX · capital markets · CE above 3767.40 / PE below 3595.00 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 155.25 / PE below 149.32 (RVOL 2)
  ◆ CAMS · capital markets · CE above 756.50 / PE below 726.05 (RVOL 2)
  ◆ MFSL · insurance · CE above 1401.10 / PE below 1351.90 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1958.00 / PE below 1910.00 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 175.50 / PE below 172.07 (RVOL 2)
  ◆ BPCL · oil & gas · CE above 308.50 / PE below 302.00 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 173.47 / PE below 169.06 (RVOL 2)
```
#### C22 (made 2026-11-15T22:45:00+05:30) - driver rows seen 47
```
PREDICTION C22 for 2026-11-16 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best BDL at 1.95.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POLICYBZR at 2.27.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · CE OIL PRODUCERS ONGC/OIL · CE IT INFY/COFORGE/HCLTECH/LTM · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · PE CAPITAL MARKETS MCX · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1741.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6980.00 / PE below 6000.00 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3222.30 / PE below 3030.20 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4464.80 / PE below 4180.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4425.60 / PE below 4240.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 353.15 / PE below 337.05 (RVOL 2)
  ◆ BDL · capital goods · CE above 1059.35 / PE below 1023.50 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 718.05 / PE below 685.10 (RVOL 2)
  ◆ MANAPPURAM · nbfc & finance · CE above 327.00 / PE below 304.65 (RVOL 2)
  ◆ POWERINDIA · capital goods · CE above 32250.00 / PE below 29950.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1112.40 / PE below 1021.40 (RVOL 2)
  ◆ COROMANDEL · chemicals · CE above 1994.30 / PE below 1932.70 (RVOL 2)
  ◆ ABB · capital goods · CE above 7120.00 / PE below 6922.00 (RVOL 2)
  ◆ ALKEM · pharma · CE above 5300.50 / PE below 5103.50 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4324.40 / PE below 4151.50 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 32640.00 / PE below 31290.00 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1195.00 / PE below 1176.00 (RVOL 2)
  ◆ ABCAPITAL · nbfc & finance · CE above 416.05 / PE below 407.05 (RVOL 2)
  ◆ MCX · capital markets · CE above 3767.40 / PE below 3595.00 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 155.25 / PE below 149.32 (RVOL 2)
  ◆ CAMS · capital markets · CE above 756.50 / PE below 726.05 (RVOL 2)
  ◆ MFSL · insurance · CE above 1401.10 / PE below 1351.90 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1958.00 / PE below 1910.00 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 175.50 / PE below 172.07 (RVOL 2)
  ◆ BPCL · oil & gas · CE above 308.50 / PE below 302.00 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 173.47 / PE below 169.06 (RVOL 2)
```
#### U07 (made 2026-11-16T07:15:00+05:30) - driver rows seen 51
```
PREDICTION U07 for 2026-11-16 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best BDL at 1.95.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POLICYBZR at 2.27.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · CE IT INFY/HCLTECH/TCS/TECHM · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · CE OIL PRODUCERS ONGC/OIL · PE CAPITAL MARKETS MCX · PE REALTY DLF
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1741.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6980.00 / PE below 6000.00 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3222.30 / PE below 3030.20 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4464.80 / PE below 4180.00 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4425.60 / PE below 4240.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 353.15 / PE below 337.05 (RVOL 2)
  ◆ BDL · capital goods · CE above 1059.35 / PE below 1023.50 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 718.05 / PE below 685.10 (RVOL 2)
  ◆ MANAPPURAM · nbfc & finance · CE above 327.00 / PE below 304.65 (RVOL 2)
  ◆ POWERINDIA · capital goods · CE above 32250.00 / PE below 29950.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1112.40 / PE below 1021.40 (RVOL 2)
  ◆ COROMANDEL · chemicals · CE above 1994.30 / PE below 1932.70 (RVOL 2)
  ◆ ABB · capital goods · CE above 7120.00 / PE below 6922.00 (RVOL 2)
  ◆ ALKEM · pharma · CE above 5300.50 / PE below 5103.50 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4324.40 / PE below 4151.50 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 32640.00 / PE below 31290.00 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1195.00 / PE below 1176.00 (RVOL 2)
  ◆ ABCAPITAL · nbfc & finance · CE above 416.05 / PE below 407.05 (RVOL 2)
  ◆ MCX · capital markets · CE above 3767.40 / PE below 3595.00 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 155.25 / PE below 149.32 (RVOL 2)
  ◆ CAMS · capital markets · CE above 756.50 / PE below 726.05 (RVOL 2)
  ◆ MFSL · insurance · CE above 1401.10 / PE below 1351.90 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1958.00 / PE below 1910.00 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 175.50 / PE below 172.07 (RVOL 2)
  ◆ BPCL · oil & gas · CE above 308.50 / PE below 302.00 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 173.47 / PE below 169.06 (RVOL 2)
```
#### P09 (made 2026-11-16T09:08:00+05:30) - driver rows seen 55
```
PREDICTION P09 for 2026-11-16 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best BDL at 1.95.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POLICYBZR at 2.27.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · CE IT INFY/HCLTECH/TCS/TECHM · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · CE OIL PRODUCERS ONGC/OIL · PE CAPITAL MARKETS MCX · PE REALTY DLF
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1741.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AMBER · electronics & hardware · CE above 6980.00 / PE below 6000.00 (RVOL 2) · ARMED (both triggers)
  ◆ ENRIN · capital goods · CE above 3222.30 / PE below 3030.20 (RVOL 2) · ARMED (both triggers)
  ◆ GVT&D · capital goods · CE above 4464.80 / PE below 4180.00 (RVOL 2) · ARMED (both triggers)
  ◆ CUMMINSIND · capital goods · CE above 4425.60 / PE below 4240.00 (RVOL 2) · ARMED (both triggers)
  ◆ ANGELONE · capital markets · CE above 353.15 / PE below 337.05 (RVOL 2) · ARMED (both triggers)
  ◆ BDL · capital goods · CE above 1059.35 / PE below 1023.50 (RVOL 2) · ARMED (both triggers)
  ◆ KALYANKJIL · consumer durables · CE above 718.05 / PE below 685.10 (RVOL 2) · ARMED (both triggers)
  ◆ MANAPPURAM · nbfc & finance · CE above 327.00 / PE below 304.65 (RVOL 2) · ARMED (both triggers)
  ◆ POWERINDIA · capital goods · CE above 32250.00 / PE below 29950.00 (RVOL 2) · ARMED (both triggers)
  ◆ POLICYBZR · nbfc & finance · CE above 1121.40 / PE below 1021.40 (RVOL 2) · GAP UP 1.3% - CE trigger = the opening-range high
  ◆ COROMANDEL · chemicals · CE above 1994.30 / PE below 1932.70 (RVOL 2) · ARMED (both triggers)
  ◆ ABB · capital goods · CE above 7120.00 / PE below 6922.00 (RVOL 2) · ARMED (both triggers)
  ◆ ALKEM · pharma · CE above 5300.50 / PE below 5103.50 (RVOL 2) · ARMED (both triggers)
  ◆ DATAPATTNS · electronics & hardware · CE above 4324.40 / PE below 4151.50 (RVOL 2) · ARMED (both triggers)
  ◆ PAGEIND · textiles · CE above 32640.00 / PE below 31290.00 (RVOL 2) · ARMED (both triggers)
  ◆ COCHINSHIP · capital goods · CE above 1195.00 / PE below 1176.00 (RVOL 2) · ARMED (both triggers)
  ◆ ABCAPITAL · nbfc & finance · CE above 416.05 / PE below 407.05 (RVOL 2) · ARMED (both triggers)
  ◆ MCX · capital markets · CE above 3772.60 / PE below 3595.00 (RVOL 2) · GAP UP 1.4% - CE trigger = the opening-range high
  ◆ BANKINDIA · banks · CE above 155.25 / PE below 149.32 (RVOL 2) · ARMED (both triggers)
  ◆ CAMS · capital markets · CE above 756.50 / PE below 726.05 (RVOL 2) · ARMED (both triggers)
  ◆ MFSL · insurance · CE above 1401.10 / PE below 1351.90 (RVOL 2) · ARMED (both triggers)
  ◆ ATHERENERG · auto · CE above 1958.00 / PE below 1910.00 (RVOL 2) · ARMED (both triggers)
  ◆ BANDHANBNK · banks · CE above 175.50 / PE below 172.07 (RVOL 2) · ARMED (both triggers)
  ◆ BPCL · oil & gas · CE above 308.50 / PE below 302.00 (RVOL 2) · ARMED (both triggers)
  ◆ ASHOKLEY · auto · CE above 173.47 / PE below 169.06 (RVOL 2) · ARMED (both triggers)
```
Pre-open input: 09:15 open of the minute store (= the matched pre-open price; the stored pre-open file is from before 09:08 or missing)


#### Scorecard 2026-11-16
```
MARKET CALL: MIXED - right (NIFTY open->15:10 +0.23%, real MIXED)
PREDICTED N19 · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -12 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 41%)
PREDICTED C22 · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -12 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 41%)
PREDICTED U07 · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -12 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 41%)
PREDICTED P09 · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -12 pts · MOVER (side open) 25: fired 5 (early 1), right side 3 (2 tradable), wrong 1, flat 1 · moved 2% either way 14 (all names 41%)
EARLY CARDS (trigger before half the move): side lines 0 · MOVER lines 1 · total 1 (E2 pass mark 10)
CONFIRMATIONS 2 (rung 0) · too late 3 · failed 2 · silent cards 0 · NOT PREDICTED movers shown 18
BASE RATE: CE 12% / PE 30% of 218 F&O names moved 2% its way · day movers CE 25 / PE 66
KNOWLEDGE CHAINS (IDEA, weight 0): CE 11 named, 1 moved 2% its way, 4 2% against · PE 19 named, 6 its way, 2 against
MISSED 2%+ movers 88 · 3%+: KAYNES PE 11.1%, PREMIERENE PE 7.4%, AMBER PE 7.3%, LAURUSLABS PE 7.3%, INOXWIND PE 7.2%, MAXHEALTH CE 6.3%, WAAREEENER PE 5.6%, KALYANKJIL CE 5.1%, FORTIS CE 5.0%, PATANJALI PE 4.6%
BASELINES: yesterday's movers CE 0 / PE 2 · volatility-only 8: CE 0 / PE 5 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

### 2026-11-18 - predicted on the evening of 2026-11-17 (point-in-time)

#### N19 (made 2026-11-17T19:45:00+05:30) - driver rows seen 71
```
PREDICTION N19 for 2026-11-18 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: TMPV (auto)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/JINDALSTEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE PAINTS ASIANPAINT/PIDILITIND · CE ELECTRONICS AMBER/PGEL · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE OIL MARKETERS BPCL/HINDPETRO/IOC · PE IT INFY/COFORGE/HCLTECH/LTM · CE OIL & GAS PETRONET
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1696.00 · OVERSOLD RSI 26 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ASHOKLEY · auto · CE above 172.80 / PE below 160.50 (RVOL 2)
  ◆ KAYNES · electronics & hardware · CE above 3024.60 / PE below 2850.00 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 714.90 / PE below 676.20 (RVOL 2)
  ◆ CAMS · capital markets · CE above 772.00 / PE below 720.25 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 1220.50 / PE below 1170.05 (RVOL 2)
  ◆ DELHIVERY · services · CE above 465.80 / PE below 439.05 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 159.96 / PE below 153.21 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20239.00 / PE below 19280.00 (RVOL 2)
  ◆ LAURUSLABS · pharma · CE above 2348.80 / PE below 2214.80 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 985.00 / PE below 932.75 (RVOL 2)
  ◆ KEI · capital goods · CE above 4020.00 / PE below 3835.30 (RVOL 2)
  ◆ MOTILALOFS · capital markets · CE above 1277.80 / PE below 1201.20 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1173.00 / PE below 1141.40 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4199.00 / PE below 4042.20 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1493.70 / PE below 1443.70 (RVOL 2)
  ◆ LICHSGFIN · nbfc & finance · CE above 623.30 / PE below 596.15 (RVOL 2)
  ◆ GMRAIRPORT · services · CE above 105.26 / PE below 101.50 (RVOL 2)
  ◆ AUBANK · banks · CE above 1000.00 / PE below 966.90 (RVOL 2)
  ◆ ASIANPAINT · consumer durables · CE above 2665.50 / PE below 2598.00 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31825.00 / PE below 30855.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1094.90 / PE below 1037.30 (RVOL 2)
  ◆ MAHABANK · banks · CE above 96.10 / PE below 92.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 379.15 / PE below 344.45 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3092.20 / PE below 3021.50 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 276.20 / PE below 269.46 (RVOL 2)
```
#### C22 (made 2026-11-17T22:45:00+05:30) - driver rows seen 71
```
PREDICTION C22 for 2026-11-18 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: TMPV (auto)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/JINDALSTEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE PAINTS ASIANPAINT/PIDILITIND · CE ELECTRONICS AMBER/PGEL · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE OIL MARKETERS BPCL/HINDPETRO/IOC · PE IT INFY/COFORGE/HCLTECH/LTM · CE OIL & GAS PETRONET
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1696.00 · OVERSOLD RSI 26 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ASHOKLEY · auto · CE above 172.80 / PE below 160.50 (RVOL 2)
  ◆ KAYNES · electronics & hardware · CE above 3024.60 / PE below 2850.00 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 714.90 / PE below 676.20 (RVOL 2)
  ◆ CAMS · capital markets · CE above 772.00 / PE below 720.25 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 1220.50 / PE below 1170.05 (RVOL 2)
  ◆ DELHIVERY · services · CE above 465.80 / PE below 439.05 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 159.96 / PE below 153.21 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20239.00 / PE below 19280.00 (RVOL 2)
  ◆ LAURUSLABS · pharma · CE above 2348.80 / PE below 2214.80 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 985.00 / PE below 932.75 (RVOL 2)
  ◆ KEI · capital goods · CE above 4020.00 / PE below 3835.30 (RVOL 2)
  ◆ MOTILALOFS · capital markets · CE above 1277.80 / PE below 1201.20 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1173.00 / PE below 1141.40 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4199.00 / PE below 4042.20 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1493.70 / PE below 1443.70 (RVOL 2)
  ◆ LICHSGFIN · nbfc & finance · CE above 623.30 / PE below 596.15 (RVOL 2)
  ◆ GMRAIRPORT · services · CE above 105.26 / PE below 101.50 (RVOL 2)
  ◆ AUBANK · banks · CE above 1000.00 / PE below 966.90 (RVOL 2)
  ◆ ASIANPAINT · consumer durables · CE above 2665.50 / PE below 2598.00 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31825.00 / PE below 30855.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1094.90 / PE below 1037.30 (RVOL 2)
  ◆ MAHABANK · banks · CE above 96.10 / PE below 92.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 379.15 / PE below 344.45 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3092.20 / PE below 3021.50 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 276.20 / PE below 269.46 (RVOL 2)
```
#### U07 (made 2026-11-18T07:15:00+05:30) - driver rows seen 52
```
PREDICTION U07 for 2026-11-18 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: TMPV (auto)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/VEDL · CE ELECTRONICS AMBER/DIXON/PGEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE JEWELLERS TITAN/KALYANKJIL · PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE ELECTRONICS KAYNES/SYRMA · PE OIL PRODUCERS ONGC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1696.00 · OVERSOLD RSI 26 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ASHOKLEY · auto · CE above 172.80 / PE below 160.50 (RVOL 2)
  ◆ KAYNES · electronics & hardware · CE above 3024.60 / PE below 2850.00 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 714.90 / PE below 676.20 (RVOL 2)
  ◆ CAMS · capital markets · CE above 772.00 / PE below 720.25 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 1220.50 / PE below 1170.05 (RVOL 2)
  ◆ DELHIVERY · services · CE above 465.80 / PE below 439.05 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 159.96 / PE below 153.21 (RVOL 2)
  ◆ FORCEMOT · auto · CE above 20239.00 / PE below 19280.00 (RVOL 2)
  ◆ LAURUSLABS · pharma · CE above 2348.80 / PE below 2214.80 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 985.00 / PE below 932.75 (RVOL 2)
  ◆ KEI · capital goods · CE above 4020.00 / PE below 3835.30 (RVOL 2)
  ◆ MOTILALOFS · capital markets · CE above 1277.80 / PE below 1201.20 (RVOL 2)
  ◆ COCHINSHIP · capital goods · CE above 1173.00 / PE below 1141.40 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4199.00 / PE below 4042.20 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1493.70 / PE below 1443.70 (RVOL 2)
  ◆ LICHSGFIN · nbfc & finance · CE above 623.30 / PE below 596.15 (RVOL 2)
  ◆ GMRAIRPORT · services · CE above 105.26 / PE below 101.50 (RVOL 2)
  ◆ AUBANK · banks · CE above 1000.00 / PE below 966.90 (RVOL 2)
  ◆ ASIANPAINT · consumer durables · CE above 2665.50 / PE below 2598.00 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31825.00 / PE below 30855.00 (RVOL 2)
  ◆ POLICYBZR · nbfc & finance · CE above 1094.90 / PE below 1037.30 (RVOL 2)
  ◆ MAHABANK · banks · CE above 96.10 / PE below 92.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 379.15 / PE below 344.45 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 3092.20 / PE below 3021.50 (RVOL 2)
  ◆ BANKBARODA · banks · CE above 276.20 / PE below 269.46 (RVOL 2)
```
#### P09 (made 2026-11-18T09:08:00+05:30) - driver rows seen 62
```
PREDICTION P09 for 2026-11-18 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: TMPV (auto)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/VEDL · CE ELECTRONICS AMBER/DIXON/PGEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE JEWELLERS TITAN/KALYANKJIL · PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE ELECTRONICS KAYNES/SYRMA · PE OIL PRODUCERS ONGC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ PIIND · chemicals · trigger > 1696.00 · OVERSOLD RSI 26 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ASHOKLEY · auto · CE above 172.80 / PE below 158.03 (RVOL 2) · GAP DOWN -0.3% - PE trigger = the opening-range low
  ◆ KAYNES · electronics & hardware · CE above 3024.60 / PE below 2850.00 (RVOL 2) · ARMED (both triggers)
  ◆ KALYANKJIL · consumer durables · CE above 714.90 / PE below 676.20 (RVOL 2) · ARMED (both triggers)
  ◆ CAMS · capital markets · CE above 772.00 / PE below 720.25 (RVOL 2) · ARMED (both triggers)
  ◆ 360ONE · capital markets · CE above 1220.50 / PE below 1170.05 (RVOL 2) · ARMED (both triggers)
  ◆ DELHIVERY · services · CE above 465.80 / PE below 439.05 (RVOL 2) · ARMED (both triggers)
  ◆ BANKINDIA · banks · CE above 159.96 / PE below 153.21 (RVOL 2) · ARMED (both triggers)
  ◆ FORCEMOT · auto · CE above 20239.00 / PE below 19280.00 (RVOL 2) · ARMED (both triggers)
  ◆ LAURUSLABS · pharma · CE above 2348.80 / PE below 2214.80 (RVOL 2) · ARMED (both triggers)
  ◆ KFINTECH · capital markets · CE above 985.00 / PE below 932.75 (RVOL 2) · ARMED (both triggers)
  ◆ KEI · capital goods · CE above 4020.00 / PE below 3788.10 (RVOL 2) · GAP DOWN -0.7% - PE trigger = the opening-range low
  ◆ MOTILALOFS · capital markets · CE above 1277.80 / PE below 1201.20 (RVOL 2) · ARMED (both triggers)
  ◆ COCHINSHIP · capital goods · CE above 1173.00 / PE below 1141.40 (RVOL 2) · ARMED (both triggers)
  ◆ CUMMINSIND · capital goods · CE above 4199.00 / PE below 4042.20 (RVOL 2) · ARMED (both triggers)
  ◆ ADANIENSOL · power · CE above 1508.60 / PE below 1443.70 (RVOL 2) · GAP UP 0.1% - CE trigger = the opening-range high
  ◆ LICHSGFIN · nbfc & finance · CE above 623.30 / PE below 596.15 (RVOL 2) · ARMED (both triggers)
  ◆ GMRAIRPORT · services · CE above 105.26 / PE below 101.50 (RVOL 2) · ARMED (both triggers)
  ◆ AUBANK · banks · CE above 1000.00 / PE below 966.90 (RVOL 2) · ARMED (both triggers)
  ◆ ASIANPAINT · consumer durables · CE above 2665.50 / PE below 2598.00 (RVOL 2) · ARMED (both triggers)
  ◆ PAGEIND · textiles · CE above 31825.00 / PE below 30855.00 (RVOL 2) · ARMED (both triggers)
  ◆ POLICYBZR · nbfc & finance · CE above 1094.90 / PE below 1037.30 (RVOL 2) · ARMED (both triggers)
  ◆ MAHABANK · banks · CE above 96.10 / PE below 92.00 (RVOL 2) · ARMED (both triggers)
  ◆ ANGELONE · capital markets · CE above 379.15 / PE below 344.45 (RVOL 2) · ARMED (both triggers)
  ◆ ENRIN · capital goods · CE above 3092.20 / PE below 3011.50 (RVOL 2) · GAP DOWN -0.0% - PE trigger = the opening-range low
  ◆ BANKBARODA · banks · CE above 276.20 / PE below 269.46 (RVOL 2) · ARMED (both triggers)
```
Pre-open input: 09:15 open of the minute store (= the matched pre-open price; the stored pre-open file is from before 09:08 or missing)


#### Scorecard 2026-11-18
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 -0.60%, real DOWN)
PREDICTED N19 · CE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · PE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +74 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 33%)
PREDICTED C22 · CE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · PE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +74 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 33%)
PREDICTED U07 · CE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · PE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +74 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 33%)
PREDICTED P09 · CE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · CE bounce 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -9 pts · PE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +74 pts · MOVER (side open) 25: fired 6 (early 1), right side 4 (2 tradable), wrong 1, flat 1 · moved 2% either way 12 (all names 33%)
EARLY CARDS (trigger before half the move): side lines 0 · MOVER lines 1 · total 1 (E2 pass mark 10)
CONFIRMATIONS 2 (rung 0) · too late 4 · failed 5 · silent cards 1 · NOT PREDICTED movers shown 13
BASE RATE: CE 9% / PE 26% of 218 F&O names moved 2% its way · day movers CE 19 / PE 56
KNOWLEDGE CHAINS (IDEA, weight 0): CE 24 named, 1 moved 2% its way, 6 2% against · PE 32 named, 5 its way, 1 against
MISSED 2%+ movers 71 · 3%+: ANGELONE PE 5.7%, IREDA CE 5.0%, SWIGGY PE 5.0%, SAIL PE 4.4%, TITAN PE 4.2%, BSE PE 4.1%, POLYCAB PE 4.0%, NAVINFLUOR CE 3.8%, MANAPPURAM PE 3.8%, DIXON PE 3.7%
BASELINES: yesterday's movers CE 0 / PE 4 · volatility-only 8: CE 1 / PE 5 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

### 2026-11-19 - predicted on the evening of 2026-11-18 (point-in-time)

#### N19 (made 2026-11-18T19:45:00+05:30) - driver rows seen 59
```
PREDICTION N19 for 2026-11-19 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best PIIND at 1.98.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE ELECTRONICS AMBER/DIXON/PGEL · CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE ELECTRONICS KAYNES/SYRMA
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ KAYNES · electronics & hardware · trigger > 2939.50 · OVERSOLD RSI 34 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan); this share is oversold by its 20-day average (-10.6%), not by RSI · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ MANAPPURAM · nbfc & finance · CE above 291.50 / PE below 280.45 (RVOL 2)
  ◆ INOXWIND · capital goods · CE above 59.72 / PE below 57.45 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2710.90 / PE below 2626.20 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 162.45 / PE below 156.16 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4055.90 / PE below 3965.00 (RVOL 2)
  ◆ MOTHERSON · auto · CE above 162.56 / PE below 156.75 (RVOL 2)
  ◆ RVNL · construction · CE above 195.90 / PE below 188.50 (RVOL 2)
  ◆ HINDZINC · metals & mining · CE above 540.95 / PE below 525.70 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 687.40 / PE below 645.80 (RVOL 2)
  ◆ KEI · capital goods · CE above 3838.00 / PE below 3713.40 (RVOL 2)
  ◆ PIIND · chemicals · CE above 1676.00 / PE below 1619.70 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 10295.00 / PE below 9775.50 (RVOL 2)
  ◆ POLYCAB · capital goods · CE above 7670.00 / PE below 7293.00 (RVOL 2)
  ◆ TMPV · auto · CE above 259.30 / PE below 252.20 (RVOL 2)
  ◆ BSE · capital markets · CE above 3921.40 / PE below 3708.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 361.80 / PE below 333.20 (RVOL 2)
  ◆ NATIONALUM · metals & mining · CE above 316.25 / PE below 304.20 (RVOL 2)
  ◆ HINDALCO · metals & mining · CE above 916.85 / PE below 898.15 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 170.32 / PE below 162.03 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31015.00 / PE below 30485.00 (RVOL 2)
  ◆ NAM-INDIA · capital markets · CE above 1098.00 / PE below 1043.10 (RVOL 2)
  ◆ BDL · capital goods · CE above 1031.40 / PE below 1005.20 (RVOL 2)
  ◆ CGPOWER · capital goods · CE above 807.55 / PE below 785.00 (RVOL 2)
  ◆ CAMS · capital markets · CE above 747.55 / PE below 713.00 (RVOL 2)
  ◆ TITAN · consumer durables · CE above 4881.30 / PE below 4648.10 (RVOL 2)
```
#### C22 (made 2026-11-18T22:45:00+05:30) - driver rows seen 59
```
PREDICTION C22 for 2026-11-19 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best PIIND at 1.98.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE ELECTRONICS AMBER/DIXON/PGEL · CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE ELECTRONICS KAYNES/SYRMA
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ KAYNES · electronics & hardware · trigger > 2939.50 · OVERSOLD RSI 34 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan); this share is oversold by its 20-day average (-10.6%), not by RSI · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ MANAPPURAM · nbfc & finance · CE above 291.50 / PE below 280.45 (RVOL 2)
  ◆ INOXWIND · capital goods · CE above 59.72 / PE below 57.45 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2710.90 / PE below 2626.20 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 162.45 / PE below 156.16 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4055.90 / PE below 3965.00 (RVOL 2)
  ◆ MOTHERSON · auto · CE above 162.56 / PE below 156.75 (RVOL 2)
  ◆ RVNL · construction · CE above 195.90 / PE below 188.50 (RVOL 2)
  ◆ HINDZINC · metals & mining · CE above 540.95 / PE below 525.70 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 687.40 / PE below 645.80 (RVOL 2)
  ◆ KEI · capital goods · CE above 3838.00 / PE below 3713.40 (RVOL 2)
  ◆ PIIND · chemicals · CE above 1676.00 / PE below 1619.70 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 10295.00 / PE below 9775.50 (RVOL 2)
  ◆ POLYCAB · capital goods · CE above 7670.00 / PE below 7293.00 (RVOL 2)
  ◆ TMPV · auto · CE above 259.30 / PE below 252.20 (RVOL 2)
  ◆ BSE · capital markets · CE above 3921.40 / PE below 3708.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 361.80 / PE below 333.20 (RVOL 2)
  ◆ NATIONALUM · metals & mining · CE above 316.25 / PE below 304.20 (RVOL 2)
  ◆ HINDALCO · metals & mining · CE above 916.85 / PE below 898.15 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 170.32 / PE below 162.03 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31015.00 / PE below 30485.00 (RVOL 2)
  ◆ NAM-INDIA · capital markets · CE above 1098.00 / PE below 1043.10 (RVOL 2)
  ◆ BDL · capital goods · CE above 1031.40 / PE below 1005.20 (RVOL 2)
  ◆ CGPOWER · capital goods · CE above 807.55 / PE below 785.00 (RVOL 2)
  ◆ CAMS · capital markets · CE above 747.55 / PE below 713.00 (RVOL 2)
  ◆ TITAN · consumer durables · CE above 4881.30 / PE below 4648.10 (RVOL 2)
```
#### U07 (made 2026-11-19T07:15:00+05:30) - driver rows seen 60
```
PREDICTION U07 for 2026-11-19 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best PIIND at 1.98.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · CE ELECTRONICS AMBER/DIXON/PGEL · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE OIL & GAS PETRONET
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ KAYNES · electronics & hardware · trigger > 2939.50 · OVERSOLD RSI 34 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan); this share is oversold by its 20-day average (-10.6%), not by RSI · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ MANAPPURAM · nbfc & finance · CE above 291.50 / PE below 280.45 (RVOL 2)
  ◆ INOXWIND · capital goods · CE above 59.72 / PE below 57.45 (RVOL 2)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2710.90 / PE below 2626.20 (RVOL 2)
  ◆ ASHOKLEY · auto · CE above 162.45 / PE below 156.16 (RVOL 2)
  ◆ CUMMINSIND · capital goods · CE above 4055.90 / PE below 3965.00 (RVOL 2)
  ◆ MOTHERSON · auto · CE above 162.56 / PE below 156.75 (RVOL 2)
  ◆ RVNL · construction · CE above 195.90 / PE below 188.50 (RVOL 2)
  ◆ HINDZINC · metals & mining · CE above 540.95 / PE below 525.70 (RVOL 2)
  ◆ KALYANKJIL · consumer durables · CE above 687.40 / PE below 645.80 (RVOL 2)
  ◆ KEI · capital goods · CE above 3838.00 / PE below 3713.40 (RVOL 2)
  ◆ PIIND · chemicals · CE above 1676.00 / PE below 1619.70 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 10295.00 / PE below 9775.50 (RVOL 2)
  ◆ POLYCAB · capital goods · CE above 7670.00 / PE below 7293.00 (RVOL 2)
  ◆ TMPV · auto · CE above 259.30 / PE below 252.20 (RVOL 2)
  ◆ BSE · capital markets · CE above 3921.40 / PE below 3708.00 (RVOL 2)
  ◆ ANGELONE · capital markets · CE above 361.80 / PE below 333.20 (RVOL 2)
  ◆ NATIONALUM · metals & mining · CE above 316.25 / PE below 304.20 (RVOL 2)
  ◆ HINDALCO · metals & mining · CE above 916.85 / PE below 898.15 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 170.32 / PE below 162.03 (RVOL 2)
  ◆ PAGEIND · textiles · CE above 31015.00 / PE below 30485.00 (RVOL 2)
  ◆ NAM-INDIA · capital markets · CE above 1098.00 / PE below 1043.10 (RVOL 2)
  ◆ BDL · capital goods · CE above 1031.40 / PE below 1005.20 (RVOL 2)
  ◆ CGPOWER · capital goods · CE above 807.55 / PE below 785.00 (RVOL 2)
  ◆ CAMS · capital markets · CE above 747.55 / PE below 713.00 (RVOL 2)
  ◆ TITAN · consumer durables · CE above 4881.30 / PE below 4648.10 (RVOL 2)
```
#### P09 (made 2026-11-19T09:08:00+05:30) - driver rows seen 62
```
PREDICTION P09 for 2026-11-19 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best PIIND at 1.98.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · CE ELECTRONICS AMBER/DIXON/PGEL · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE OIL & GAS PETRONET
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ KAYNES · electronics & hardware · trigger > 2939.50 · OVERSOLD RSI 34 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan); this share is oversold by its 20-day average (-10.6%), not by RSI · strong market (NIFTY above its 50-day average): 21% kept falling (RSI <= 30 scan, n=410) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ MANAPPURAM · nbfc & finance · CE above 291.50 / PE below 280.45 (RVOL 2) · ARMED (both triggers)
  ◆ INOXWIND · capital goods · CE above 59.72 / PE below 57.45 (RVOL 2) · ARMED (both triggers)
  ◆ MUTHOOTFIN · nbfc & finance · CE above 2710.90 / PE below 2553.80 (RVOL 2) · GAP DOWN -2.0% - PE trigger = the opening-range low
  ◆ ASHOKLEY · auto · CE above 162.45 / PE below 156.16 (RVOL 2) · ARMED (both triggers)
  ◆ CUMMINSIND · capital goods · CE above 4055.90 / PE below 3965.00 (RVOL 2) · ARMED (both triggers)
  ◆ MOTHERSON · auto · CE above 162.56 / PE below 156.75 (RVOL 2) · ARMED (both triggers)
  ◆ RVNL · construction · CE above 195.90 / PE below 187.23 (RVOL 2) · GAP DOWN -0.4% - PE trigger = the opening-range low
  ◆ HINDZINC · metals & mining · CE above 540.95 / PE below 509.20 (RVOL 2) · GAP DOWN -2.3% - PE trigger = the opening-range low
  ◆ KALYANKJIL · consumer durables · CE above 687.40 / PE below 639.00 (RVOL 2) · GAP DOWN -0.8% - PE trigger = the opening-range low
  ◆ KEI · capital goods · CE above 3838.00 / PE below 3653.10 (RVOL 2) · GAP DOWN -0.9% - PE trigger = the opening-range low
  ◆ PIIND · chemicals · CE above 1676.00 / PE below 1619.70 (RVOL 2) · ARMED (both triggers)
  ◆ NAVINFLUOR · chemicals · CE above 10295.00 / PE below 9775.50 (RVOL 2) · ARMED (both triggers)
  ◆ POLYCAB · capital goods · CE above 7670.00 / PE below 7293.00 (RVOL 2) · ARMED (both triggers)
  ◆ TMPV · auto · CE above 259.30 / PE below 252.20 (RVOL 2) · ARMED (both triggers)
  ◆ BSE · capital markets · CE above 3921.40 / PE below 3708.00 (RVOL 2) · ARMED (both triggers)
  ◆ ANGELONE · capital markets · CE above 361.80 / PE below 333.20 (RVOL 2) · ARMED (both triggers)
  ◆ NATIONALUM · metals & mining · CE above 316.25 / PE below 297.55 (RVOL 2) · GAP DOWN -2.6% - PE trigger = the opening-range low
  ◆ HINDALCO · metals & mining · CE above 916.85 / PE below 879.50 (RVOL 2) · GAP DOWN -2.3% - PE trigger = the opening-range low
  ◆ SAIL · metals & mining · CE above 170.32 / PE below 161.52 (RVOL 2) · GAP DOWN -1.2% - PE trigger = the opening-range low
  ◆ PAGEIND · textiles · CE above 31015.00 / PE below 30485.00 (RVOL 2) · ARMED (both triggers)
  ◆ NAM-INDIA · capital markets · CE above 1098.00 / PE below 1035.00 (RVOL 2) · GAP DOWN -1.6% - PE trigger = the opening-range low
  ◆ BDL · capital goods · CE above 1031.40 / PE below 1005.20 (RVOL 2) · ARMED (both triggers)
  ◆ CGPOWER · capital goods · CE above 807.55 / PE below 785.00 (RVOL 2) · ARMED (both triggers)
  ◆ CAMS · capital markets · CE above 747.55 / PE below 713.00 (RVOL 2) · ARMED (both triggers)
  ◆ TITAN · consumer durables · CE above 4881.30 / PE below 4581.60 (RVOL 2) · GAP DOWN -0.3% - PE trigger = the opening-range low
```
Pre-open input: 09:15 open of the minute store (= the matched pre-open price; the stored pre-open file is from before 09:08 or missing)


#### Scorecard 2026-11-19
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 +0.66%, real UP)
PREDICTED N19 · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -33 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 38%)
PREDICTED C22 · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -33 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 38%)
PREDICTED U07 · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -33 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 38%)
PREDICTED P09 · CE bounce 1: right 0 (0 tradable), flat 1, wrong 0 · beat the day -33 pts · PE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +27 pts · MOVER (side open) 25: fired 9 (early 2), right side 3 (3 tradable), wrong 5, flat 1 · moved 2% either way 13 (all names 38%)
EARLY CARDS (trigger before half the move): side lines 0 · MOVER lines 2 · total 2 (E2 pass mark 10)
CONFIRMATIONS 2 (rung 1) · too late 6 · failed 5 · silent cards 7 · NOT PREDICTED movers shown 34
BASE RATE: CE 33% / PE 6% of 218 F&O names moved 2% its way · day movers CE 72 / PE 13
KNOWLEDGE CHAINS (IDEA, weight 0): CE 21 named, 18 moved 2% its way, 0 2% against · PE 25 named, 1 its way, 7 against
MISSED 2%+ movers 80 · 3%+: VOLTAS CE 9.1%, BLUESTARCO CE 7.8%, AMBER CE 7.7%, IREDA CE 7.7%, PAYTM PE 7.5%, MARUTI CE 7.0%, PGEL CE 6.9%, UNITDSPR CE 6.2%, HAVELLS CE 6.0%, COLPAL CE 5.5%
BASELINES: yesterday's movers CE 2 / PE 1 · volatility-only 8: CE 3 / PE 1 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

### 2026-10-29 - predicted on the evening of 2026-10-28 (point-in-time)

#### N19 (made 2026-10-28T19:45:00+05:30) - driver rows seen 7
```
PREDICTION N19 for 2026-10-29 (made 19:45) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KAYNES at 1.91.
  WATCH ONLY - below the bar: KAYNES (electronics & hardware)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KPITTECH at 1.95.
  WATCH ONLY - below the bar: PATANJALI (fmcg)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE OIL PRODUCERS ONGC/OIL · PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.85 · OVERSOLD RSI 17 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ SWIGGY · consumer services · trigger > 188.95 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 939.90 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ KEI · capital goods · trigger > 3926.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AUBANK · banks · CE above 887.50 / PE below 845.10 (RVOL 2)
  ◆ PGEL · electronics & hardware · CE above 543.00 / PE below 506.40 (RVOL 2)
  ◆ APOLLOHOSP · hospitals & diagnostics · CE above 8151.00 / PE below 7714.50 (RVOL 2)
  ◆ CUB · banks · CE above 233.70 / PE below 213.30 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4135.00 / PE below 4000.00 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1679.90 / PE below 1636.30 (RVOL 2)
  ◆ APLAPOLLO · metals & mining · CE above 2219.00 / PE below 2156.30 (RVOL 2)
  ◆ WAAREEENER · capital goods · CE above 2306.90 / PE below 2161.50 (RVOL 2)
  ◆ MAZDOCK · capital goods · CE above 1776.00 / PE below 1690.60 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 169.30 / PE below 161.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1618.50 / PE below 1504.30 (RVOL 2)
  ◆ KPITTECH · it · CE above 571.40 / PE below 514.40 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6282.00 / PE below 5976.50 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 205.29 / PE below 194.72 (RVOL 2)
  ◆ RADICO · fmcg · CE above 4296.00 / PE below 4113.00 (RVOL 2)
  ◆ BIOCON · pharma · CE above 350.70 / PE below 330.60 (RVOL 2)
  ◆ SONACOMS · auto · CE above 883.95 / PE below 850.25 (RVOL 2)
  ◆ NAUKRI · consumer services · CE above 1264.90 / PE below 1138.40 (RVOL 2)
  ◆ INFY · it · CE above 1108.40 / PE below 1078.70 (RVOL 2)
  ◆ BDL · capital goods · CE above 1012.70 / PE below 986.40 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 8634.00 / PE below 8222.00 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4119.20 / PE below 3955.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 156.98 / PE below 150.89 (RVOL 2)
  ◆ UPL · chemicals · CE above 537.95 / PE below 505.30 (RVOL 2)
  ◆ SYRMA · electronics & hardware · CE above 1592.40 / PE below 1519.00 (RVOL 2)
```
#### C22 (made 2026-10-28T22:45:00+05:30) - driver rows seen 7
```
PREDICTION C22 for 2026-10-29 (made 22:45) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KAYNES at 1.91.
  WATCH ONLY - below the bar: KAYNES (electronics & hardware)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KPITTECH at 1.95.
  WATCH ONLY - below the bar: PATANJALI (fmcg)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE OIL PRODUCERS ONGC/OIL · PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.85 · OVERSOLD RSI 17 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ SWIGGY · consumer services · trigger > 188.95 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 939.90 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ KEI · capital goods · trigger > 3926.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AUBANK · banks · CE above 887.50 / PE below 845.10 (RVOL 2)
  ◆ PGEL · electronics & hardware · CE above 543.00 / PE below 506.40 (RVOL 2)
  ◆ APOLLOHOSP · hospitals & diagnostics · CE above 8151.00 / PE below 7714.50 (RVOL 2)
  ◆ CUB · banks · CE above 233.70 / PE below 213.30 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4135.00 / PE below 4000.00 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1679.90 / PE below 1636.30 (RVOL 2)
  ◆ APLAPOLLO · metals & mining · CE above 2219.00 / PE below 2156.30 (RVOL 2)
  ◆ WAAREEENER · capital goods · CE above 2306.90 / PE below 2161.50 (RVOL 2)
  ◆ MAZDOCK · capital goods · CE above 1776.00 / PE below 1690.60 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 169.30 / PE below 161.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1618.50 / PE below 1504.30 (RVOL 2)
  ◆ KPITTECH · it · CE above 571.40 / PE below 514.40 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6282.00 / PE below 5976.50 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 205.29 / PE below 194.72 (RVOL 2)
  ◆ RADICO · fmcg · CE above 4296.00 / PE below 4113.00 (RVOL 2)
  ◆ BIOCON · pharma · CE above 350.70 / PE below 330.60 (RVOL 2)
  ◆ SONACOMS · auto · CE above 883.95 / PE below 850.25 (RVOL 2)
  ◆ NAUKRI · consumer services · CE above 1264.90 / PE below 1138.40 (RVOL 2)
  ◆ INFY · it · CE above 1108.40 / PE below 1078.70 (RVOL 2)
  ◆ BDL · capital goods · CE above 1012.70 / PE below 986.40 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 8634.00 / PE below 8222.00 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4119.20 / PE below 3955.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 156.98 / PE below 150.89 (RVOL 2)
  ◆ UPL · chemicals · CE above 537.95 / PE below 505.30 (RVOL 2)
  ◆ SYRMA · electronics & hardware · CE above 1592.40 / PE below 1519.00 (RVOL 2)
```
#### U07 (made 2026-10-29T07:15:00+05:30) - driver rows seen 20
```
PREDICTION U07 for 2026-10-29 (made 07:15) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KAYNES at 1.91.
  WATCH ONLY - below the bar: KAYNES (electronics & hardware)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KPITTECH at 1.95.
  WATCH ONLY - below the bar: PATANJALI (fmcg)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE OIL PRODUCERS ONGC · CE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL · CE FMCG GODREJCP/HINDUNILVR/DABUR · CE OIL MARKETERS BPCL/HINDPETRO/IOC · CE ELECTRONICS DIXON/KAYNES/AMBER/PGEL · PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.85 · OVERSOLD RSI 17 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ SWIGGY · consumer services · trigger > 188.95 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 939.90 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ KEI · capital goods · trigger > 3926.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AUBANK · banks · CE above 887.50 / PE below 845.10 (RVOL 2)
  ◆ PGEL · electronics & hardware · CE above 543.00 / PE below 506.40 (RVOL 2)
  ◆ APOLLOHOSP · hospitals & diagnostics · CE above 8151.00 / PE below 7714.50 (RVOL 2)
  ◆ CUB · banks · CE above 233.70 / PE below 213.30 (RVOL 2)
  ◆ GVT&D · capital goods · CE above 4135.00 / PE below 4000.00 (RVOL 2)
  ◆ ATHERENERG · auto · CE above 1679.90 / PE below 1636.30 (RVOL 2)
  ◆ APLAPOLLO · metals & mining · CE above 2219.00 / PE below 2156.30 (RVOL 2)
  ◆ WAAREEENER · capital goods · CE above 2306.90 / PE below 2161.50 (RVOL 2)
  ◆ MAZDOCK · capital goods · CE above 1776.00 / PE below 1690.60 (RVOL 2)
  ◆ SAIL · metals & mining · CE above 169.30 / PE below 161.00 (RVOL 2)
  ◆ BLUESTARCO · consumer durables · CE above 1618.50 / PE below 1504.30 (RVOL 2)
  ◆ KPITTECH · it · CE above 571.40 / PE below 514.40 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6282.00 / PE below 5976.50 (RVOL 2)
  ◆ CROMPTON · consumer durables · CE above 205.29 / PE below 194.72 (RVOL 2)
  ◆ RADICO · fmcg · CE above 4296.00 / PE below 4113.00 (RVOL 2)
  ◆ BIOCON · pharma · CE above 350.70 / PE below 330.60 (RVOL 2)
  ◆ SONACOMS · auto · CE above 883.95 / PE below 850.25 (RVOL 2)
  ◆ NAUKRI · consumer services · CE above 1264.90 / PE below 1138.40 (RVOL 2)
  ◆ INFY · it · CE above 1108.40 / PE below 1078.70 (RVOL 2)
  ◆ BDL · capital goods · CE above 1012.70 / PE below 986.40 (RVOL 2)
  ◆ NAVINFLUOR · chemicals · CE above 8634.00 / PE below 8222.00 (RVOL 2)
  ◆ DATAPATTNS · electronics & hardware · CE above 4119.20 / PE below 3955.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 156.98 / PE below 150.89 (RVOL 2)
  ◆ UPL · chemicals · CE above 537.95 / PE below 505.30 (RVOL 2)
  ◆ SYRMA · electronics & hardware · CE above 1592.40 / PE below 1519.00 (RVOL 2)
```
#### P09 (made 2026-10-29T09:08:00+05:30) - driver rows seen 20
```
PREDICTION P09 for 2026-10-29 (made 09:08) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KAYNES at 1.91.
  WATCH ONLY - below the bar: KAYNES (electronics & hardware)
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best KPITTECH at 1.95.
  WATCH ONLY - below the bar: PATANJALI (fmcg)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE OIL PRODUCERS ONGC · CE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL · CE FMCG GODREJCP/HINDUNILVR/DABUR · CE OIL MARKETERS BPCL/HINDPETRO/IOC · CE ELECTRONICS DIXON/KAYNES/AMBER/PGEL · PE METALS HINDALCO/NATIONALUM/HINDZINC · PE CABLES POLYCAB/KEI
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.85 · OVERSOLD RSI 17 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ SWIGGY · consumer services · trigger > 188.95 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 939.90 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ KEI · capital goods · trigger > 3926.00 · OVERSOLD RSI 28 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ AUBANK · banks · CE above 887.50 / PE below 845.10 (RVOL 2) · ARMED (both triggers)
  ◆ PGEL · electronics & hardware · CE above 543.00 / PE below 506.40 (RVOL 2) · ARMED (both triggers)
  ◆ APOLLOHOSP · hospitals & diagnostics · CE above 8164.50 / PE below 7714.50 (RVOL 2) · GAP UP 0.2% - CE trigger = the opening-range high
  ◆ CUB · banks · CE above 233.70 / PE below 213.30 (RVOL 2) · ARMED (both triggers)
  ◆ GVT&D · capital goods · CE above 4135.00 / PE below 4000.00 (RVOL 2) · ARMED (both triggers)
  ◆ ATHERENERG · auto · CE above 1679.90 / PE below 1636.30 (RVOL 2) · ARMED (both triggers)
  ◆ APLAPOLLO · metals & mining · CE above 2219.00 / PE below 2156.30 (RVOL 2) · ARMED (both triggers)
  ◆ WAAREEENER · capital goods · CE above 2306.90 / PE below 2161.50 (RVOL 2) · ARMED (both triggers)
  ◆ MAZDOCK · capital goods · CE above 1776.00 / PE below 1690.60 (RVOL 2) · ARMED (both triggers)
  ◆ SAIL · metals & mining · CE above 169.30 / PE below 161.00 (RVOL 2) · ARMED (both triggers)
  ◆ BLUESTARCO · consumer durables · CE above 1618.50 / PE below 1504.30 (RVOL 2) · ARMED (both triggers)
  ◆ KPITTECH · it · CE above 571.40 / PE below 514.40 (RVOL 2) · ARMED (both triggers)
  ◆ AMBER · electronics & hardware · CE above 6282.00 / PE below 5976.50 (RVOL 2) · ARMED (both triggers)
  ◆ CROMPTON · consumer durables · CE above 205.29 / PE below 194.72 (RVOL 2) · ARMED (both triggers)
  ◆ RADICO · fmcg · CE above 4296.00 / PE below 4113.00 (RVOL 2) · ARMED (both triggers)
  ◆ BIOCON · pharma · CE above 353.85 / PE below 330.60 (RVOL 2) · GAP UP 0.2% - CE trigger = the opening-range high
  ◆ SONACOMS · auto · CE above 883.95 / PE below 850.25 (RVOL 2) · ARMED (both triggers)
  ◆ NAUKRI · consumer services · CE above 1264.90 / PE below 1138.40 (RVOL 2) · ARMED (both triggers)
  ◆ INFY · it · CE above 1108.40 / PE below 1078.70 (RVOL 2) · ARMED (both triggers)
  ◆ BDL · capital goods · CE above 1012.70 / PE below 986.40 (RVOL 2) · ARMED (both triggers)
  ◆ NAVINFLUOR · chemicals · CE above 8634.00 / PE below 8222.00 (RVOL 2) · ARMED (both triggers)
  ◆ DATAPATTNS · electronics & hardware · CE above 4119.20 / PE below 3955.10 (RVOL 2) · ARMED (both triggers)
  ◆ BANDHANBNK · banks · CE above 156.98 / PE below 150.89 (RVOL 2) · ARMED (both triggers)
  ◆ UPL · chemicals · CE above 537.95 / PE below 505.30 (RVOL 2) · ARMED (both triggers)
  ◆ SYRMA · electronics & hardware · CE above 1592.40 / PE below 1519.00 (RVOL 2) · ARMED (both triggers)
```
Pre-open input: 09:15 open of the minute store (= the matched pre-open price; the stored pre-open file is from before 09:08 or missing)


#### Scorecard 2026-10-29
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 +0.66%, real UP)
PREDICTED N19 · CE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +72 pts · CE bounce 4: right 1 (0 tradable), flat 0, wrong 3 · beat the day -3 pts · PE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -8 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 36%)
PREDICTED C22 · CE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +72 pts · CE bounce 4: right 1 (0 tradable), flat 0, wrong 3 · beat the day -3 pts · PE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -8 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 36%)
PREDICTED U07 · CE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +72 pts · CE bounce 4: right 1 (0 tradable), flat 0, wrong 3 · beat the day -3 pts · PE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -8 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 13 (all names 36%)
PREDICTED P09 · CE watch 1: right 1 (0 tradable), flat 0, wrong 0 · beat the day +72 pts · CE bounce 4: right 1 (0 tradable), flat 0, wrong 3 · beat the day -3 pts · PE watch 1: right 0 (0 tradable), flat 0, wrong 1 · beat the day -8 pts · MOVER (side open) 25: fired 6 (early 1), right side 3 (1 tradable), wrong 2, flat 1 · moved 2% either way 13 (all names 36%)
EARLY CARDS (trigger before half the move): side lines 0 · MOVER lines 1 · total 1 (E2 pass mark 10)
CONFIRMATIONS 0 (rung 0) · too late 6 · failed 5 · silent cards 0 · NOT PREDICTED movers shown 25
BASE RATE: CE 28% / PE 8% of 218 F&O names moved 2% its way · day movers CE 62 / PE 18
KNOWLEDGE CHAINS (IDEA, weight 0): CE 2 named, 0 moved 2% its way, 0 2% against · PE 5 named, 0 its way, 1 against
MISSED 2%+ movers 75 · 3%+: PNBHOUSING PE 6.8%, ADANIENT CE 4.8%, CUB CE 4.7%, JSWENERGY CE 4.6%, UNITDSPR CE 4.6%, POWERGRID CE 4.5%, MANAPPURAM CE 4.3%, ADANIENSOL CE 4.2%, CDSL CE 4.1%, ETERNAL CE 4.0%
BASELINES: yesterday's movers CE 3 / PE 2 · volatility-only 8: CE 2 / PE 0 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

### 2026-10-27 - predicted on the evening of 2026-10-26 (point-in-time)

#### N19 (made 2026-10-26T19:45:00+05:30) - driver rows seen 43
```
PREDICTION N19 for 2026-10-27 (made 19:45) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best AUBANK at 2.01.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ATHERENERG at 2.11.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE FMCG HINDUNILVR/NESTLEIND/ITC · PE PHARMA CIPLA/SUNPHARMA · CE OIL PRODUCERS OIL · CE CHEMICALS COROMANDEL · PE CAPITAL MARKETS MCX · CE JEWELLERS TITAN/KALYANKJIL · CE METALS TATASTEEL/HINDALCO/JINDALSTEL/JSWSTEEL · PE OIL MARKETERS BPCL/HINDPETRO/IOC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.92 · OVERSOLD RSI 18 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ DIXON · electronics & hardware · trigger > 11278.00 · OVERSOLD RSI 21 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 934.70 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ INOXWIND · capital goods · trigger > 59.50 · OVERSOLD RSI 27 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ATHERENERG · auto · CE above 1623.00 / PE below 1345.70 (RVOL 2)
  ◆ AUBANK · banks · CE above 899.30 / PE below 845.40 (RVOL 2)
  ◆ KEI · capital goods · CE above 3912.00 / PE below 3685.20 (RVOL 2)
  ◆ CUB · banks · CE above 219.80 / PE below 206.80 (RVOL 2)
  ◆ UJJIVANSFB · banks · CE above 58.00 / PE below 54.44 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 999.00 / PE below 972.10 (RVOL 2)
  ◆ SWIGGY · consumer services · CE above 191.55 / PE below 174.20 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6015.00 / PE below 5863.00 (RVOL 2)
  ◆ SHRIRAMFIN · nbfc & finance · CE above 836.00 / PE below 810.20 (RVOL 2)
  ◆ ADANIGREEN · power · CE above 1250.00 / PE below 1175.00 (RVOL 2)
  ◆ ABB · capital goods · CE above 6357.50 / PE below 6064.00 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1260.80 / PE below 1207.50 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 129.73 / PE below 123.64 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 829.80 / PE below 784.00 (RVOL 2)
  ◆ SUPREMEIND · capital goods · CE above 3512.50 / PE below 3244.30 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 2763.90 / PE below 2630.40 (RVOL 2)
  ◆ ADANIPOWER · power · CE above 186.60 / PE below 177.74 (RVOL 2)
  ◆ HAVELLS · consumer durables · CE above 1037.70 / PE below 1005.80 (RVOL 2)
  ◆ IDEA · telecom services · CE above 12.01 / PE below 11.21 (RVOL 2)
  ◆ COFORGE · it · CE above 1997.60 / PE below 1812.20 (RVOL 2)
  ◆ COLPAL · fmcg · CE above 1638.20 / PE below 1587.60 (RVOL 2)
  ◆ LODHA · realty · CE above 980.00 / PE below 937.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 151.63 / PE below 143.69 (RVOL 2)
  ◆ DRREDDY · pharma · CE above 1319.00 / PE below 1224.00 (RVOL 2)
  ◆ AMBUJACEM · cement & materials · CE above 373.90 / PE below 349.50 (RVOL 2)
```
#### C22 (made 2026-10-26T22:45:00+05:30) - driver rows seen 43
```
PREDICTION C22 for 2026-10-27 (made 22:45) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best AUBANK at 2.01.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ATHERENERG at 2.11.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE FMCG HINDUNILVR/NESTLEIND/ITC · PE PHARMA CIPLA/SUNPHARMA · CE OIL PRODUCERS OIL · CE CHEMICALS COROMANDEL · PE CAPITAL MARKETS MCX · CE JEWELLERS TITAN/KALYANKJIL · CE METALS TATASTEEL/HINDALCO/JINDALSTEL/JSWSTEEL · PE OIL MARKETERS BPCL/HINDPETRO/IOC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.92 · OVERSOLD RSI 18 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ DIXON · electronics & hardware · trigger > 11278.00 · OVERSOLD RSI 21 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 934.70 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ INOXWIND · capital goods · trigger > 59.50 · OVERSOLD RSI 27 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ATHERENERG · auto · CE above 1623.00 / PE below 1345.70 (RVOL 2)
  ◆ AUBANK · banks · CE above 899.30 / PE below 845.40 (RVOL 2)
  ◆ KEI · capital goods · CE above 3912.00 / PE below 3685.20 (RVOL 2)
  ◆ CUB · banks · CE above 219.80 / PE below 206.80 (RVOL 2)
  ◆ UJJIVANSFB · banks · CE above 58.00 / PE below 54.44 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 999.00 / PE below 972.10 (RVOL 2)
  ◆ SWIGGY · consumer services · CE above 191.55 / PE below 174.20 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6015.00 / PE below 5863.00 (RVOL 2)
  ◆ SHRIRAMFIN · nbfc & finance · CE above 836.00 / PE below 810.20 (RVOL 2)
  ◆ ADANIGREEN · power · CE above 1250.00 / PE below 1175.00 (RVOL 2)
  ◆ ABB · capital goods · CE above 6357.50 / PE below 6064.00 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1260.80 / PE below 1207.50 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 129.73 / PE below 123.64 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 829.80 / PE below 784.00 (RVOL 2)
  ◆ SUPREMEIND · capital goods · CE above 3512.50 / PE below 3244.30 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 2763.90 / PE below 2630.40 (RVOL 2)
  ◆ ADANIPOWER · power · CE above 186.60 / PE below 177.74 (RVOL 2)
  ◆ HAVELLS · consumer durables · CE above 1037.70 / PE below 1005.80 (RVOL 2)
  ◆ IDEA · telecom services · CE above 12.01 / PE below 11.21 (RVOL 2)
  ◆ COFORGE · it · CE above 1997.60 / PE below 1812.20 (RVOL 2)
  ◆ COLPAL · fmcg · CE above 1638.20 / PE below 1587.60 (RVOL 2)
  ◆ LODHA · realty · CE above 980.00 / PE below 937.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 151.63 / PE below 143.69 (RVOL 2)
  ◆ DRREDDY · pharma · CE above 1319.00 / PE below 1224.00 (RVOL 2)
  ◆ AMBUJACEM · cement & materials · CE above 373.90 / PE below 349.50 (RVOL 2)
```
#### U07 (made 2026-10-27T07:15:00+05:30) - driver rows seen 35
```
PREDICTION U07 for 2026-10-27 (made 07:15) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best AUBANK at 2.01.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ATHERENERG at 2.11.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE FMCG HINDUNILVR/NESTLEIND/ITC · PE PHARMA CIPLA/SUNPHARMA · CE OIL PRODUCERS OIL · CE CHEMICALS COROMANDEL · PE CAPITAL MARKETS MCX · CE JEWELLERS TITAN/KALYANKJIL · CE METALS TATASTEEL/HINDALCO/JINDALSTEL/JSWSTEEL · PE OIL MARKETERS BPCL/HINDPETRO/IOC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.92 · OVERSOLD RSI 18 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ DIXON · electronics & hardware · trigger > 11278.00 · OVERSOLD RSI 21 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 934.70 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ INOXWIND · capital goods · trigger > 59.50 · OVERSOLD RSI 27 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ATHERENERG · auto · CE above 1623.00 / PE below 1345.70 (RVOL 2)
  ◆ AUBANK · banks · CE above 899.30 / PE below 845.40 (RVOL 2)
  ◆ KEI · capital goods · CE above 3912.00 / PE below 3685.20 (RVOL 2)
  ◆ CUB · banks · CE above 219.80 / PE below 206.80 (RVOL 2)
  ◆ UJJIVANSFB · banks · CE above 58.00 / PE below 54.44 (RVOL 2)
  ◆ 360ONE · capital markets · CE above 999.00 / PE below 972.10 (RVOL 2)
  ◆ SWIGGY · consumer services · CE above 191.55 / PE below 174.20 (RVOL 2)
  ◆ AMBER · electronics & hardware · CE above 6015.00 / PE below 5863.00 (RVOL 2)
  ◆ SHRIRAMFIN · nbfc & finance · CE above 836.00 / PE below 810.20 (RVOL 2)
  ◆ ADANIGREEN · power · CE above 1250.00 / PE below 1175.00 (RVOL 2)
  ◆ ABB · capital goods · CE above 6357.50 / PE below 6064.00 (RVOL 2)
  ◆ ADANIENSOL · power · CE above 1260.80 / PE below 1207.50 (RVOL 2)
  ◆ BANKINDIA · banks · CE above 129.73 / PE below 123.64 (RVOL 2)
  ◆ KFINTECH · capital markets · CE above 829.80 / PE below 784.00 (RVOL 2)
  ◆ SUPREMEIND · capital goods · CE above 3512.50 / PE below 3244.30 (RVOL 2)
  ◆ ENRIN · capital goods · CE above 2763.90 / PE below 2630.40 (RVOL 2)
  ◆ ADANIPOWER · power · CE above 186.60 / PE below 177.74 (RVOL 2)
  ◆ HAVELLS · consumer durables · CE above 1037.70 / PE below 1005.80 (RVOL 2)
  ◆ IDEA · telecom services · CE above 12.01 / PE below 11.21 (RVOL 2)
  ◆ COFORGE · it · CE above 1997.60 / PE below 1812.20 (RVOL 2)
  ◆ COLPAL · fmcg · CE above 1638.20 / PE below 1587.60 (RVOL 2)
  ◆ LODHA · realty · CE above 980.00 / PE below 937.10 (RVOL 2)
  ◆ BANDHANBNK · banks · CE above 151.63 / PE below 143.69 (RVOL 2)
  ◆ DRREDDY · pharma · CE above 1319.00 / PE below 1224.00 (RVOL 2)
  ◆ AMBUJACEM · cement & materials · CE above 373.90 / PE below 349.50 (RVOL 2)
```
#### P09 (made 2026-10-27T09:08:00+05:30) - driver rows seen 35
```
PREDICTION P09 for 2026-10-27 (made 09:08) · market MIXED 18/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best AUBANK at 2.01.
WILL GO DOWN (PE):
  No PE side line tonight - no driver with a record sets a side (A6b); the MOVER lines below carry both triggers. Best ATHERENERG at 2.11.
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE FMCG HINDUNILVR/NESTLEIND/ITC · PE PHARMA CIPLA/SUNPHARMA · CE OIL PRODUCERS OIL · CE CHEMICALS COROMANDEL · PE CAPITAL MARKETS MCX · CE JEWELLERS TITAN/KALYANKJIL · CE METALS TATASTEEL/HINDALCO/JINDALSTEL/JSWSTEEL · PE OIL MARKETERS BPCL/HINDPETRO/IOC
CE BOUNCE (on the turn) - oversold, only above yesterday's high AND VWAP with RVOL 2, sector not falling, NOT PROVEN:
  ↺ YESBANK · banks · trigger > 15.92 · OVERSOLD RSI 18 - 86% bounced within 20 days, n=207 · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ DIXON · electronics & hardware · trigger > 11278.00 · OVERSOLD RSI 21 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ NAM-INDIA · capital markets · trigger > 934.70 · OVERSOLD RSI 24 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
  ↺ INOXWIND · capital goods · trigger > 59.50 · OVERSOLD RSI 27 - 87% bounced within 20 days, n=1,842 (the RSI <= 30 scan) · weak market (NIFTY below its 50-day average): only 10% kept falling (RSI <= 30 scan, n=1,432) · NOT PROVEN
MOVER (side open) - will likely move, the first trigger decides the side, NOT PROVEN:
  ◆ ATHERENERG · auto · CE above 1623.00 / PE below 1345.70 (RVOL 2) · ARMED (both triggers)
  ◆ AUBANK · banks · CE above 899.30 / PE below 845.40 (RVOL 2) · ARMED (both triggers)
  ◆ KEI · capital goods · CE above 3912.00 / PE below 3685.20 (RVOL 2) · ARMED (both triggers)
  ◆ CUB · banks · CE above 219.80 / PE below 206.80 (RVOL 2) · ARMED (both triggers)
  ◆ UJJIVANSFB · banks · CE above 58.00 / PE below 54.44 (RVOL 2) · ARMED (both triggers)
  ◆ 360ONE · capital markets · CE above 999.00 / PE below 972.10 (RVOL 2) · ARMED (both triggers)
  ◆ SWIGGY · consumer services · CE above 191.55 / PE below 174.20 (RVOL 2) · ARMED (both triggers)
  ◆ AMBER · electronics & hardware · CE above 6015.00 / PE below 5863.00 (RVOL 2) · ARMED (both triggers)
  ◆ SHRIRAMFIN · nbfc & finance · CE above 836.00 / PE below 810.20 (RVOL 2) · ARMED (both triggers)
  ◆ ADANIGREEN · power · CE above 1250.00 / PE below 1175.00 (RVOL 2) · ARMED (both triggers)
  ◆ ABB · capital goods · CE above 6479.50 / PE below 6064.00 (RVOL 2) · GAP UP 0.2% - CE trigger = the opening-range high
  ◆ ADANIENSOL · power · CE above 1277.60 / PE below 1207.50 (RVOL 2) · GAP UP 0.5% - CE trigger = the opening-range high
  ◆ BANKINDIA · banks · CE above 129.73 / PE below 123.64 (RVOL 2) · ARMED (both triggers)
  ◆ KFINTECH · capital markets · CE above 864.00 / PE below 784.00 (RVOL 2) · GAP UP 2.6% - CE trigger = the opening-range high
  ◆ SUPREMEIND · capital goods · CE above 3512.50 / PE below 3244.30 (RVOL 2) · ARMED (both triggers)
  ◆ ENRIN · capital goods · CE above 2809.70 / PE below 2630.40 (RVOL 2) · GAP UP 0.6% - CE trigger = the opening-range high
  ◆ ADANIPOWER · power · CE above 186.60 / PE below 177.74 (RVOL 2) · ARMED (both triggers)
  ◆ HAVELLS · consumer durables · CE above 1037.70 / PE below 1005.80 (RVOL 2) · ARMED (both triggers)
  ◆ IDEA · telecom services · CE above 12.01 / PE below 11.21 (RVOL 2) · ARMED (both triggers)
  ◆ COFORGE · it · CE above 1997.60 / PE below 1812.20 (RVOL 2) · ARMED (both triggers)
  ◆ COLPAL · fmcg · CE above 1638.20 / PE below 1587.60 (RVOL 2) · ARMED (both triggers)
  ◆ LODHA · realty · CE above 980.00 / PE below 937.10 (RVOL 2) · ARMED (both triggers)
  ◆ BANDHANBNK · banks · CE above 151.66 / PE below 143.69 (RVOL 2) · GAP UP 0.5% - CE trigger = the opening-range high
  ◆ DRREDDY · pharma · CE above 1319.00 / PE below 1224.00 (RVOL 2) · ARMED (both triggers)
  ◆ AMBUJACEM · cement & materials · CE above 373.90 / PE below 349.50 (RVOL 2) · ARMED (both triggers)
```
Pre-open input: 09:15 open of the minute store (= the matched pre-open price; the stored pre-open file is from before 09:08 or missing)


#### Scorecard 2026-10-27
```
MARKET CALL: MIXED - right (NIFTY open->15:10 +0.09%, real MIXED)
PREDICTED N19 · CE bounce 4: right 2 (0 tradable), flat 1, wrong 1 · beat the day +17 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 38%)
PREDICTED C22 · CE bounce 4: right 2 (0 tradable), flat 1, wrong 1 · beat the day +17 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 38%)
PREDICTED U07 · CE bounce 4: right 2 (0 tradable), flat 1, wrong 1 · beat the day +17 pts · MOVER (side open) 25: fired 0 (early 0), right side 0 (0 tradable), wrong 0, flat 0 · moved 2% either way 14 (all names 38%)
PREDICTED P09 · CE bounce 4: right 2 (0 tradable), flat 1, wrong 1 · beat the day +17 pts · MOVER (side open) 25: fired 6 (early 3), right side 4 (2 tradable), wrong 2, flat 0 · moved 2% either way 14 (all names 38%)
EARLY CARDS (trigger before half the move): side lines 0 · MOVER lines 3 · total 3 (E2 pass mark 10)
CONFIRMATIONS 1 (rung 0) · too late 5 · failed 2 · silent cards 0 · NOT PREDICTED movers shown 34
BASE RATE: CE 33% / PE 6% of 218 F&O names moved 2% its way · day movers CE 71 / PE 12
KNOWLEDGE CHAINS (IDEA, weight 0): CE 18 named, 5 moved 2% its way, 1 2% against · PE 25 named, 2 its way, 4 against
MISSED 2%+ movers 78 · 3%+: DATAPATTNS CE 8.4%, PGEL CE 7.7%, SONACOMS CE 7.4%, MANKIND CE 6.9%, GVT&D CE 5.4%, MOTILALOFS CE 5.1%, APLAPOLLO CE 5.0%, CUB CE 5.0%, AMBUJACEM PE 4.8%, MAHABANK CE 4.5%
BASELINES: yesterday's movers CE 4 / PE 1 · volatility-only 8: CE 5 / PE 0 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```

## Beside the old system
The desk's yardstick (MONDAY_READY E3): the old system caught 22 (16 Nov) and 35 (18 Nov) movers before the move. On the same
days the prediction lane's early cards were 1 and 1 (MOVER lines; no side line fired early). Definitions differ (the old count is any
card before the move, intraday ones included; ours is only the evening / 09:08 lines), but on this yardstick the new lane alone is WORSE.

## Honest verdict
- The code can name shares that will move (about 1.4x the base rate held-out); it cannot name the side before the open, and neither
  can the pre-open study's lists or market reads. Every line is NOT PROVEN.
- Side lines appear only with a driver; on 20 Nov (a strong up day: 57 CE movers, 4 PE) the 09:08 side lines were poor (CE 4: 1 right,
  1 wrong; PE 3: 0 right, 2 wrong), while the MOVER lines set by price were right 6 / wrong 0 of 10 fired.
- The knowledge chains named the 19 Nov AC / auto / electronics rally the evening before, but those chains were written after it (the KB
  marks them LEAKAGE); A6b rule 5 - not counted.
- 16 / 18 Nov re-run with rule 1: the lists are no longer empty (25 MOVER lines each; 14 and 12 of them moved 2% either way).

## Not known in these runs (said once, with the reason)
- Option premium at 19:45 (no option quotes in the point-in-time inputs); GIFT / US futures history (none stored); ban / MWPL on past
  days (only today's NSE ban file is kept); the v2 news reader exists only from 19 Nov 19:13 (16 / 18 / 19 Nov and October had no news
  drivers); reader rows can be appended after their first-seen time, so a replay can see a few more rows than live did (20 Nov P09:
  77 driver rows in the replay vs 71 live at 09:08).
- The written-reasons step (brain + red team) is coded but not run here: this shell has no model key; it ships OFF.

Files: v2/predict/*.py · weights v2/data/predict/weights.json · tests v2/predict/tests/test_predict.py (28 pass)
