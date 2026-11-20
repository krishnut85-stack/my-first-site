# C1 - THE EVENING PREDICTION (19:45 / 22:45 / 07:15 / 09:08) - proof

Built in `v2/predict/` (new modules; no change to v2/engine or v2/engine_next). Code builds and ranks; nothing is sent.
Every version writes new rows to an append-only store (`v2/data/predict/predictions.jsonl`, `candidate_log.jsonl` = every share both sides,
`market_day_call.jsonl`), each with `made_at` to the second, inputs window, evidence IDs, trigger, cancel, expected move, grade.

## What one line carries (A6)
side (UP = CE / DOWN = PE) · share · sector · role · WHY (+) up to 3 drivers each with its other side and proof status · AGAINST (-) always ·
trigger (yesterday's high / low, 1-minute close, RVOL >= 2 on its side of VWAP) · cancel price (provisional from yesterday's close, final at 09:08
from NSE's pre-open IEP) + cancel facts · expected move (own median on past 2% days) · grade STRONG / MEDIUM / WEAK with the side's base rate,
NOT CALIBRATED · strike plan · chips (GAP TOOK, AT RISK) · NOT PROVEN label. Market-day call UP / DOWN / MIXED with probabilities.

## Step 1 - the code layer measured on 5 years of daily data BEFORE any test (`python3 -m predict.study`)
```
LAYER-1 CODE CHECK (predict/study.py) - made 2026-11-20T08:53:30+05:30
train 2022-02-09 .. 2025-11-14 · held-out after 2025-11-14 (250 sessions) · label: next session 2%+ from the open (daily high / low; tradable-leg approximation)

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

HELD-OUT CE: top 8 a day right 28.9% · base 21.2% (lift 1.37) · volatility-only list 35.8% (lift 0.81; the same 8 shares named on BOTH sides) · 2000 lines
HELD-OUT PE: top 8 a day right 34.7% · base 23.5% (lift 1.47) · volatility-only list 42.6% (lift 0.81; the same 8 shares named on BOTH sides) · 2000 lines
DIRECTION TEST (a coin = 50%): named shares that moved 2% either way went OUR way 50.2% (n=2276) · strongest direction fifth of all shares 50.5% (n=4750)
VERDICT: the list beats the base rate mostly by naming shares that move a lot; the SIDE is right 50% of the time -> NOT PROVEN. Every card carries NOT PROVEN until the live scorecard shows +8 pts over baselines for 20 days (E7).
```

Plain words: from daily data the code can say WHICH shares will move (2% either way: 50-62% of its 8 'movers' vs 33-41% of all names on the
test days below), but NOT which way: on the held-out year the side was right 50.2% of the time (a coin). So the side must come from drivers
(news, filings, broker / TV calls, block deals, knowledge chains, the pre-open) - and none of those has a measured record yet. Every line
therefore says NOT PROVEN. The market-day call is MIXED by default: neither the US close nor the NIFTY gap shifted the day type on the held-out
year (all-days base: up 19% / down 21% / mixed 61% on the open -> 15:10 +-0.5% rule).

## The grade rubric (fixed before the tests; in `predict/build.py`)
+1 move score top quarter · +1 measured daily direction top quarter for the side · +1 per agreeing driver row (unit >= 0.25, max +2) · -1 per
driver row against. STRONG >= 4, MEDIUM = 3, WEAK <= 2. Scored list = MEDIUM+ (max 8 a side). A side with fewer than 3 shows a WATCH ONLY
fold (WEAK, never rings). So a scored line needs at least one real driver on top of the measured scores. Two extra folds, both silent:
MOVERS WATCH (likely to move, side not known, both triggers) and KNOWLEDGE CHAINS (IDEA - NOT PROVEN, weight 0: none of the 474 chain rows
passes the PROVEN bar; blind test 221 of 459 = 48%).

## Point-in-time tests (each made as if on the evening before; inputs only by their first-seen time; scored on the minute store)

### 2026-11-16 - predicted on the evening of 2026-11-15 (point-in-time)

#### N19 (made 2026-11-15T19:45:00+05:30) - driver rows seen 47
```
PREDICTION N19 for 2026-11-16 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was BDL at 1.95.
  WATCH ONLY - below the bar: BDL (capital goods), CAMS (capital markets), BPCL (oil & gas)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POLICYBZR at 2.27.
  WATCH ONLY - below the bar: POLICYBZR (nbfc & finance), ENRIN (capital goods), GVT&D (capital goods)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · CE OIL PRODUCERS ONGC/OIL · CE IT INFY/COFORGE/HCLTECH/LTM · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · PE CAPITAL MARKETS MCX · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): AMBER ▲6980.00/▼6000.00, CUMMINSIND ▲4425.60/▼4240.00, ANGELONE ▲353.15/▼337.05, KALYANKJIL ▲718.05/▼685.10, MANAPPURAM ▲327.00/▼304.65, POWERINDIA ▲32250.00/▼29950.00, COROMANDEL ▲1994.30/▼1932.70, ABB ▲7120.00/▼6922.00
```
#### C22 (made 2026-11-15T22:45:00+05:30) - driver rows seen 47
```
PREDICTION C22 for 2026-11-16 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was BDL at 1.95.
  WATCH ONLY - below the bar: BDL (capital goods), CAMS (capital markets), BPCL (oil & gas)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POLICYBZR at 2.27.
  WATCH ONLY - below the bar: POLICYBZR (nbfc & finance), ENRIN (capital goods), GVT&D (capital goods)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · CE OIL PRODUCERS ONGC/OIL · CE IT INFY/COFORGE/HCLTECH/LTM · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · PE CAPITAL MARKETS MCX · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · PE CHEMICALS COROMANDEL
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): AMBER ▲6980.00/▼6000.00, CUMMINSIND ▲4425.60/▼4240.00, ANGELONE ▲353.15/▼337.05, KALYANKJIL ▲718.05/▼685.10, MANAPPURAM ▲327.00/▼304.65, POWERINDIA ▲32250.00/▼29950.00, COROMANDEL ▲1994.30/▼1932.70, ABB ▲7120.00/▼6922.00
```
#### U07 (made 2026-11-16T07:15:00+05:30) - driver rows seen 51
```
PREDICTION U07 for 2026-11-16 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was BDL at 1.95.
  WATCH ONLY - below the bar: BDL (capital goods), CAMS (capital markets), BPCL (oil & gas)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POLICYBZR at 2.27.
  WATCH ONLY - below the bar: POLICYBZR (nbfc & finance), ENRIN (capital goods), GVT&D (capital goods)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · CE IT INFY/HCLTECH/TCS/TECHM · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · CE OIL PRODUCERS ONGC/OIL · PE CAPITAL MARKETS MCX · PE REALTY DLF
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): AMBER ▲6980.00/▼6000.00, CUMMINSIND ▲4425.60/▼4240.00, ANGELONE ▲353.15/▼337.05, KALYANKJIL ▲718.05/▼685.10, MANAPPURAM ▲327.00/▼304.65, POWERINDIA ▲32250.00/▼29950.00, COROMANDEL ▲1994.30/▼1932.70, ABB ▲7120.00/▼6922.00
```
#### P09 (made 2026-11-16T09:08:00+05:30) - driver rows seen 55
```
PREDICTION P09 for 2026-11-16 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was BDL at 1.95.
  WATCH ONLY - below the bar: BDL (capital goods), CAMS (capital markets), BPCL (oil & gas)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POLICYBZR at 2.27.
  WATCH ONLY - below the bar: POLICYBZR (nbfc & finance), ENRIN (capital goods), GVT&D (capital goods)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE NBFC BAJFINANCE · PE BANKS HDFCBANK/SBIN/AXISBANK/ICICIBANK · CE IT INFY/HCLTECH/TCS/TECHM · PE METALS HINDALCO/JINDALSTEL/JSWSTEEL/NATIONALUM · PE PAINTS ASIANPAINT/PIDILITIND · CE OIL PRODUCERS ONGC/OIL · PE CAPITAL MARKETS MCX · PE REALTY DLF
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): AMBER ▲6980.00/▼6000.00, CUMMINSIND ▲4425.60/▼4240.00, ANGELONE ▲353.15/▼337.05, KALYANKJIL ▲718.05/▼685.10, MANAPPURAM ▲327.00/▼304.65, POWERINDIA ▲32250.00/▼29950.00, COROMANDEL ▲1994.30/▼1932.70, ABB ▲7120.00/▼6922.00
```
Pre-open input: not known (no NSE pre-open file for 2026-11-16)

#### Trading day (C2 state machine on the minute store)
- 09:16 FAILED CAMS ✗ PREDICTION FAILED · CAMS - I predicted UP; it is -0.5%, below the cancel 726.05 · CAPITAL MARKETS -0.4% · I was wrong on this one. No CE on it today.
- 09:46 STALE BDL BDL not triggered by 09:45 - grade down to WEAK
- 09:46 STALE BPCL BPCL not triggered by 09:45 - grade down to WEAK
- 09:46 STALE POLICYBZR POLICYBZR not triggered by 09:45 - grade down to WEAK
- 09:46 STALE ENRIN ENRIN not triggered by 09:45 - grade down to WEAK
- 09:46 STALE GVT&D GVT&D not triggered by 09:45 - grade down to WEAK
- 11:21 FAILED BPCL ✗ PREDICTION FAILED · BPCL - I predicted UP; it is -0.7%, below the cancel 302.00 · OIL & GAS -1.0% · I was wrong on this one. No CE on it today.
- 14:31 EXPIRED BDL BDL UP · 14:30 - expired, manage only
- 14:31 EXPIRED POLICYBZR POLICYBZR DOWN · 14:30 - expired, manage only
- 14:31 EXPIRED ENRIN ENRIN DOWN · 14:30 - expired, manage only
- 14:31 EXPIRED GVT&D GVT&D DOWN · 14:30 - expired, manage only
- NOT PREDICTED movers shown (+-2% with RVOL 2): 24, first: 09:17 ABB PE, 09:17 AMBER PE, 09:17 INOXWIND PE, 09:17 KALYANKJIL CE, 09:17 TMPV PE, 09:22 ATHERENERG CE, 09:23 PATANJALI PE, 09:25 KAYNES PE, 09:28 COCHINSHIP PE, 09:28 OIL PE, 09:30 WAAREEENER PE, 09:31 MAXHEALTH CE

#### Scorecard (C5)
```
MARKET CALL: MIXED - right (NIFTY open->15:10 +0.23%, real MIXED)
PREDICTED N19 · CE watch 3: right 0 (0 tradable), flat 2, wrong 1 · beat the day -12 pts · PE watch 3: right 3 (0 tradable), flat 0, wrong 0 · beat the day +70 pts
PREDICTED C22 · CE watch 3: right 0 (0 tradable), flat 2, wrong 1 · beat the day -12 pts · PE watch 3: right 3 (0 tradable), flat 0, wrong 0 · beat the day +70 pts
PREDICTED U07 · CE watch 3: right 0 (0 tradable), flat 2, wrong 1 · beat the day -12 pts · PE watch 3: right 3 (0 tradable), flat 0, wrong 0 · beat the day +70 pts
PREDICTED P09 · CE watch 3: right 0 (0 tradable), flat 2, wrong 1 · beat the day -12 pts · PE watch 3: right 3 (0 tradable), flat 0, wrong 0 · beat the day +70 pts
CONFIRMATIONS 0 (rung 0) · too late 0 · failed 2 · silent cards 0 · NOT PREDICTED movers shown 24
BASE RATE: CE 12% / PE 30% of 218 F&O names moved 2% its way · day movers CE 25 / PE 66
MOVERS WATCH (side not known): 5 of 8 moved 2% either way (62%) vs 41% of all names
KNOWLEDGE CHAINS (IDEA, weight 0): CE 11 named, 1 moved 2% its way, 4 2% against · PE 19 named, 6 its way, 2 against
MISSED 2%+ movers 91 · 3%+: KAYNES PE 11.1%, PREMIERENE PE 7.4%, AMBER PE 7.3%, LAURUSLABS PE 7.3%, INOXWIND PE 7.2%, MAXHEALTH CE 6.3%, CUMMINSIND PE 5.6%, WAAREEENER PE 5.6%, KALYANKJIL CE 5.1%, FORTIS CE 5.0%
BASELINES: yesterday's movers CE 0 / PE 2 · volatility-only 8: CE 0 / PE 5 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```
| P09 line | side | list | label | gap its way % | best its way % | worst against % | 15:10 its way % | trigger outcome |
|---|---|---|---|---|---|---|---|---|
| BDL | CE | WATCH ONLY | FLAT | 0.0 | 1.04 | 0.51 | 0.33 | - |
| CAMS | CE | WATCH ONLY | WRONG SIDE | 0.46 | 0.08 | 1.49 | -1.08 | - |
| BPCL | CE | WATCH ONLY | FLAT | 0.66 | 0.64 | 0.94 | -0.71 | - |
| POLICYBZR | PE | WATCH ONLY | BIG RIGHT | -1.35 | 3.71 | 0.13 | 3.42 | RIGHT-NOT-TRADABLE (no trigger) |
| ENRIN | PE | WATCH ONLY | BIG RIGHT | -1.09 | 2.79 | 0.26 | 2.71 | RIGHT-NOT-TRADABLE (no trigger) |
| GVT&D | PE | WATCH ONLY | BIG RIGHT | -0.45 | 3.15 | 0.0 | 2.6 | RIGHT-NOT-TRADABLE (no trigger) |


### 2026-11-18 - predicted on the evening of 2026-11-17 (point-in-time)

#### N19 (made 2026-11-17T19:45:00+05:30) - driver rows seen 71
```
PREDICTION N19 for 2026-11-18 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: ASHOKLEY (auto), KAYNES (electronics & hardware), TMPV (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: LICHSGFIN (nbfc & finance), FORCEMOT (auto), DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/JINDALSTEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE PAINTS ASIANPAINT/PIDILITIND · CE ELECTRONICS AMBER/PGEL · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE OIL MARKETERS BPCL/HINDPETRO/IOC · PE IT INFY/COFORGE/HCLTECH/LTM · CE OIL & GAS PETRONET
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): KALYANKJIL ▲714.90/▼676.20, CAMS ▲772.00/▼720.25, 360ONE ▲1220.50/▼1170.05, DELHIVERY ▲465.80/▼439.05, BANKINDIA ▲159.96/▼153.21, LAURUSLABS ▲2348.80/▼2214.80, KFINTECH ▲985.00/▼932.75, KEI ▲4020.00/▼3835.30
```
#### C22 (made 2026-11-17T22:45:00+05:30) - driver rows seen 71
```
PREDICTION C22 for 2026-11-18 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: ASHOKLEY (auto), KAYNES (electronics & hardware), TMPV (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: LICHSGFIN (nbfc & finance), FORCEMOT (auto), DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/JINDALSTEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE PAINTS ASIANPAINT/PIDILITIND · CE ELECTRONICS AMBER/PGEL · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE OIL MARKETERS BPCL/HINDPETRO/IOC · PE IT INFY/COFORGE/HCLTECH/LTM · CE OIL & GAS PETRONET
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): KALYANKJIL ▲714.90/▼676.20, CAMS ▲772.00/▼720.25, 360ONE ▲1220.50/▼1170.05, DELHIVERY ▲465.80/▼439.05, BANKINDIA ▲159.96/▼153.21, LAURUSLABS ▲2348.80/▼2214.80, KFINTECH ▲985.00/▼932.75, KEI ▲4020.00/▼3835.30
```
#### U07 (made 2026-11-18T07:15:00+05:30) - driver rows seen 52
```
PREDICTION U07 for 2026-11-18 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: ASHOKLEY (auto), KAYNES (electronics & hardware), TMPV (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: LICHSGFIN (nbfc & finance), FORCEMOT (auto), DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/VEDL · CE ELECTRONICS AMBER/DIXON/PGEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE JEWELLERS TITAN/KALYANKJIL · PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE ELECTRONICS KAYNES/SYRMA · PE OIL PRODUCERS ONGC
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): KALYANKJIL ▲714.90/▼676.20, CAMS ▲772.00/▼720.25, 360ONE ▲1220.50/▼1170.05, DELHIVERY ▲465.80/▼439.05, BANKINDIA ▲159.96/▼153.21, LAURUSLABS ▲2348.80/▼2214.80, KFINTECH ▲985.00/▼932.75, KEI ▲4020.00/▼3835.30
```
#### P09 (made 2026-11-18T09:08:00+05:30) - driver rows seen 62
```
PREDICTION P09 for 2026-11-18 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was ASHOKLEY at 2.49.
  WATCH ONLY - below the bar: ASHOKLEY (auto), KAYNES (electronics & hardware), TMPV (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was LICHSGFIN at 1.84.
  WATCH ONLY - below the bar: LICHSGFIN (nbfc & finance), FORCEMOT (auto), DIXON (electronics & hardware)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): PE METALS HINDZINC/NATIONALUM/HINDALCO/VEDL · CE ELECTRONICS AMBER/DIXON/PGEL · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · CE JEWELLERS TITAN/KALYANKJIL · PE PHARMA AUROPHARMA/CIPLA/DRREDDY/LUPIN · PE ELECTRONICS KAYNES/SYRMA · PE OIL PRODUCERS ONGC
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): KALYANKJIL ▲714.90/▼676.20, CAMS ▲772.00/▼720.25, 360ONE ▲1220.50/▼1170.05, DELHIVERY ▲465.80/▼439.05, BANKINDIA ▲159.96/▼153.21, LAURUSLABS ▲2348.80/▼2214.80, KFINTECH ▲985.00/▼932.75, KEI ▲4020.00/▼3835.30
```
Pre-open input: NSE pre-open file 2026-11-18.json (nse_t 18-Nov-2026 09:07:25)

#### Trading day (C2 state machine on the minute store)
- 09:16 FAILED ASHOKLEY ✗ PREDICTION FAILED · ASHOKLEY - I predicted UP; it is -0.7%, below the cancel 160.50 · AUTO +0.0% · I was wrong on this one. No CE on it today.
- 09:16 FAILED TMPV ✗ PREDICTION FAILED · TMPV - I predicted UP; it is -0.4%, below the cancel 259.00 · AUTO +0.0% · I was wrong on this one. No CE on it today.
- 09:16 FAILED LICHSGFIN ✗ PREDICTION FAILED · LICHSGFIN - I predicted DOWN; it is +0.7%, above the cancel 618.00 · NBFC & FINANCE -0.2% · I was wrong on this one. No PE on it today.
- 09:46 STALE KAYNES KAYNES not triggered by 09:45 - grade down to WEAK
- 09:46 STALE FORCEMOT FORCEMOT not triggered by 09:45 - grade down to WEAK
- 09:46 STALE DIXON DIXON not triggered by 09:45 - grade down to WEAK
- 10:25 CROSS, NO VOLUME DIXON DIXON crossed 12800.00 but RVOL 0.8 / VWAP ok - not a trigger yet
- 14:31 EXPIRED KAYNES KAYNES UP · 14:30 - expired, manage only
- 14:31 EXPIRED FORCEMOT FORCEMOT DOWN · 14:30 - expired, manage only
- 14:31 EXPIRED DIXON DIXON DOWN · 14:30 - expired, manage only
- NOT PREDICTED movers shown (+-2% with RVOL 2): 19, first: 09:20 ANGELONE CE, 09:23 GMRAIRPORT CE, 09:26 ASHOKLEY PE, 09:27 MANAPPURAM PE, 09:27 MUTHOOTFIN PE, 09:28 UPL PE, 09:31 GAIL CE, 09:33 PIIND PE, 09:39 POLYCAB PE, 09:43 KALYANKJIL PE, 09:44 INOXWIND PE, 09:55 IREDA CE

#### Scorecard (C5)
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 -0.60%, real DOWN)
PREDICTED N19 · CE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +25 pts · PE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +8 pts
PREDICTED C22 · CE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +25 pts · PE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +8 pts
PREDICTED U07 · CE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +25 pts · PE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +8 pts
PREDICTED P09 · CE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +25 pts · PE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +8 pts
CONFIRMATIONS 0 (rung 0) · too late 0 · failed 3 · silent cards 0 · NOT PREDICTED movers shown 18
BASE RATE: CE 9% / PE 26% of 218 F&O names moved 2% its way · day movers CE 19 / PE 56
MOVERS WATCH (side not known): 4 of 8 moved 2% either way (50%) vs 33% of all names
KNOWLEDGE CHAINS (IDEA, weight 0): CE 24 named, 1 moved 2% its way, 6 2% against · PE 32 named, 5 its way, 1 against
MISSED 2%+ movers 75 · 3%+: ANGELONE PE 5.7%, KALYANKJIL PE 5.4%, IREDA CE 5.0%, SWIGGY PE 5.0%, SAIL PE 4.4%, TITAN PE 4.2%, BSE PE 4.1%, POLYCAB PE 4.0%, NAVINFLUOR CE 3.8%, MANAPPURAM PE 3.8%
BASELINES: yesterday's movers CE 0 / PE 4 · volatility-only 8: CE 1 / PE 5 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```
| P09 line | side | list | label | gap its way % | best its way % | worst against % | 15:10 its way % | trigger outcome |
|---|---|---|---|---|---|---|---|---|
| ASHOKLEY | CE | WATCH ONLY | WRONG SIDE | -0.31 | 1.47 | 2.4 | 0.21 | - |
| KAYNES | CE | WATCH ONLY | BIG RIGHT | 0.29 | 2.55 | 0.29 | 1.11 | RIGHT-NOT-TRADABLE (no trigger) |
| TMPV | CE | WATCH ONLY | WRONG SIDE | 0.0 | 0.04 | 2.58 | -2.45 | - |
| LICHSGFIN | PE | WATCH ONLY | WRONG SIDE | 1.02 | 1.24 | 1.25 | 0.78 | - |
| FORCEMOT | PE | WATCH ONLY | FLAT | 0.23 | 1.83 | 0.33 | 1.72 | - |
| DIXON | PE | WATCH ONLY | BIG RIGHT | -0.05 | 3.68 | 0.08 | 3.39 | RIGHT-NOT-TRADABLE (no trigger) |


### 2026-11-19 - predicted on the evening of 2026-11-18 (point-in-time)

#### N19 (made 2026-11-18T19:45:00+05:30) - driver rows seen 59
```
PREDICTION N19 for 2026-11-19 (made 19:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was PIIND at 1.98.
  WATCH ONLY - below the bar: PIIND (chemicals), MANAPPURAM (nbfc & finance), MOTHERSON (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE ELECTRONICS AMBER/DIXON/PGEL · CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE ELECTRONICS KAYNES/SYRMA
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): INOXWIND ▲59.72/▼57.45, MUTHOOTFIN ▲2710.90/▼2626.20, ASHOKLEY ▲162.45/▼156.16, CUMMINSIND ▲4055.90/▼3965.00, RVNL ▲195.90/▼188.50, HINDZINC ▲540.95/▼525.70, KALYANKJIL ▲687.40/▼645.80, KEI ▲3838.00/▼3713.40
```
#### C22 (made 2026-11-18T22:45:00+05:30) - driver rows seen 59
```
PREDICTION C22 for 2026-11-19 (made 22:45) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was PIIND at 1.98.
  WATCH ONLY - below the bar: PIIND (chemicals), MANAPPURAM (nbfc & finance), MOTHERSON (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE ELECTRONICS AMBER/DIXON/PGEL · CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE ELECTRONICS KAYNES/SYRMA
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): INOXWIND ▲59.72/▼57.45, MUTHOOTFIN ▲2710.90/▼2626.20, ASHOKLEY ▲162.45/▼156.16, CUMMINSIND ▲4055.90/▼3965.00, RVNL ▲195.90/▼188.50, HINDZINC ▲540.95/▼525.70, KALYANKJIL ▲687.40/▼645.80, KEI ▲3838.00/▼3713.40
```
#### U07 (made 2026-11-19T07:15:00+05:30) - driver rows seen 60
```
PREDICTION U07 for 2026-11-19 (made 07:15) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was PIIND at 1.98.
  WATCH ONLY - below the bar: PIIND (chemicals), MANAPPURAM (nbfc & finance), MOTHERSON (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · CE ELECTRONICS AMBER/DIXON/PGEL · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE OIL & GAS PETRONET
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): INOXWIND ▲59.72/▼57.45, MUTHOOTFIN ▲2710.90/▼2626.20, ASHOKLEY ▲162.45/▼156.16, CUMMINSIND ▲4055.90/▼3965.00, RVNL ▲195.90/▼188.50, HINDZINC ▲540.95/▼525.70, KALYANKJIL ▲687.40/▼645.80, KEI ▲3838.00/▼3713.40
```
#### P09 (made 2026-11-19T09:08:00+05:30) - driver rows seen 62
```
PREDICTION P09 for 2026-11-19 (made 09:08) · market MIXED 19/21/61 (up/down/mixed, base rate - no measured tilt) · NOT PROVEN (day 0 of 20)
WILL GO UP (CE):
  No CE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was PIIND at 1.98.
  WATCH ONLY - below the bar: PIIND (chemicals), MANAPPURAM (nbfc & finance), MOTHERSON (auto)
WILL GO DOWN (PE):
  No PE prediction tonight - nothing reaches MEDIUM (needs a driver row on top of the measured scores); best was POWERINDIA at 1.87.
  WATCH ONLY - below the bar: POWERINDIA (capital goods), 360ONE (capital markets), MOTILALOFS (capital markets)
KNOWLEDGE CHAINS - IDEA, NOT PROVEN (weight 0, never rings): CE CABLES HAVELLS · PE METALS HINDZINC/NATIONALUM/TATASTEEL/HINDALCO · CE AUTOS ASHOKLEY/HEROMOTOCO/MARUTI/BAJAJ-AUTO · PE CAPITAL MARKETS MCX · CE ELECTRONICS AMBER/DIXON/PGEL · PE CABLES POLYCAB/KEI · CE AC MAKERS VOLTAS/BLUESTARCO/CROMPTON · PE OIL & GAS PETRONET
MOVERS WATCH - will likely move, side NOT known (silent, both triggers): INOXWIND ▲59.72/▼57.45, MUTHOOTFIN ▲2710.90/▼2626.20, ASHOKLEY ▲162.45/▼156.16, CUMMINSIND ▲4055.90/▼3965.00, RVNL ▲195.90/▼188.50, HINDZINC ▲540.95/▼525.70, KALYANKJIL ▲687.40/▼645.80, KEI ▲3838.00/▼3713.40
```
Pre-open input: NSE pre-open file 2026-11-19.json (nse_t 19-Nov-2026 09:07:35)

#### Trading day (C2 state machine on the minute store)
- 09:16 FAILED PIIND ✗ PREDICTION FAILED · PIIND - I predicted UP; it is -0.4%, below the cancel 1619.70 · CHEMICALS -0.0% · I was wrong on this one. No CE on it today.
- 09:16 FAILED MANAPPURAM ✗ PREDICTION FAILED · MANAPPURAM - I predicted UP; it is -1.2%, below the cancel 280.45 · NBFC & FINANCE -0.3% · I was wrong on this one. No CE on it today.
- 09:16 FAILED MOTHERSON ✗ PREDICTION FAILED · MOTHERSON - I predicted UP; it is -0.3%, below the cancel 156.75 · AUTO +0.3% · I was wrong on this one. No CE on it today.
- 09:17 CROSS, NO VOLUME MOTILALOFS MOTILALOFS crossed 1208.00 but RVOL 1.5 / VWAP ok - not a trigger yet
- 09:46 STALE POWERINDIA POWERINDIA not triggered by 09:45 - grade down to WEAK
- 09:46 STALE 360ONE 360ONE not triggered by 09:45 - grade down to WEAK
- 09:46 STALE MOTILALOFS MOTILALOFS not triggered by 09:45 - grade down to WEAK
- 09:47 FAILED 360ONE ✗ PREDICTION FAILED · 360ONE - I predicted DOWN; it is +0.5%, above the cancel 1215.95 · CAPITAL MARKETS +0.4% · I was wrong on this one. No PE on it today.
- 09:49 FAILED POWERINDIA ✗ PREDICTION FAILED · POWERINDIA - I predicted DOWN; it is +0.4%, above the cancel 30945.00 · CAPITAL GOODS +0.7% · I was wrong on this one. No PE on it today.
- 14:31 EXPIRED MOTILALOFS MOTILALOFS DOWN · 14:30 - expired, manage only
- NOT PREDICTED movers shown (+-2% with RVOL 2): 41, first: 09:17 BLUESTARCO CE, 09:17 VOLTAS CE, 09:19 IREDA CE, 09:19 POLICYBZR PE, 09:21 CROMPTON CE, 09:21 HYUNDAI CE, 09:21 PNBHOUSING CE, 09:22 MARUTI CE, 09:22 PGEL CE, 09:23 BDL CE, 09:23 EICHERMOT CE, 09:24 PNB CE

#### Scorecard (C5)
```
MARKET CALL: MIXED - wrong (NIFTY open->15:10 +0.66%, real UP)
PREDICTED N19 · CE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +0 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts
PREDICTED C22 · CE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +0 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts
PREDICTED U07 · CE watch 3: right 1 (0 tradable), flat 1, wrong 1 · beat the day +0 pts · PE watch 3: right 1 (0 tradable), flat 2, wrong 0 · beat the day +27 pts
PREDICTED P09 · CE watch 3: right 0 (0 tradable), flat 0, wrong 3 · beat the day -33 pts · PE watch 3: right 1 (0 tradable), flat 0, wrong 2 · beat the day +27 pts
CONFIRMATIONS 0 (rung 0) · too late 0 · failed 5 · silent cards 0 · NOT PREDICTED movers shown 41
BASE RATE: CE 33% / PE 6% of 218 F&O names moved 2% its way · day movers CE 72 / PE 13
MOVERS WATCH (side not known): 5 of 8 moved 2% either way (62%) vs 38% of all names
KNOWLEDGE CHAINS (IDEA, weight 0): CE 21 named, 18 moved 2% its way, 0 2% against · PE 25 named, 1 its way, 7 against
MISSED 2%+ movers 85 · 3%+: VOLTAS CE 9.1%, BLUESTARCO CE 7.8%, AMBER CE 7.7%, IREDA CE 7.7%, PAYTM PE 7.5%, MARUTI CE 7.0%, PGEL CE 6.9%, UNITDSPR CE 6.2%, HAVELLS CE 6.0%, COLPAL CE 5.5%
BASELINES: yesterday's movers CE 2 / PE 1 · volatility-only 8: CE 3 / PE 1 right
NOT PROVEN until 20 trading days show +8 pts over baselines (E7)
```
| P09 line | side | list | label | gap its way % | best its way % | worst against % | 15:10 its way % | trigger outcome |
|---|---|---|---|---|---|---|---|---|
| PIIND | CE | WATCH ONLY | WRONG SIDE | 0.0 | 1.83 | 0.71 | 0.95 | - |
| MANAPPURAM | CE | WATCH ONLY | WRONG SIDE | -0.85 | 1.03 | 1.6 | 0.8 | - |
| MOTHERSON | CE | WATCH ONLY | WRONG SIDE | -0.15 | 4.3 | 0.48 | 3.72 | - |
| POWERINDIA | PE | WATCH ONLY | WRONG SIDE | -0.0 | 0.94 | 0.83 | 0.16 | - |
| 360ONE | PE | WATCH ONLY | WRONG SIDE | 0.09 | 1.15 | 0.59 | 0.9 | - |
| MOTILALOFS | PE | WATCH ONLY | BIG RIGHT | 0.24 | 3.08 | 0.0 | 1.53 | RIGHT-NOT-TRADABLE (no trigger) |


## Honest verdict on the tests
- 16 / 18 / 19 Nov: the scored lists were EMPTY at every version - the v2 news reader only started on 19 Nov 19:13, so those evenings had
  only broker calls (houses with small records, weight near 0), TV calls and block deals as drivers. The WATCH ONLY folds were mixed
  (see each scorecard). The MOVERS WATCH beat the all-names rate every day. The market call was MIXED each day (right on 16 Nov only).
- The knowledge chains named the 19 Nov AC / electronics / auto rally the evening before (CE 18 of 21 moved 2% its way) - but those chains
  were written / tuned on 18-19 Nov (the KB labels them LEAKAGE), so this is in-sample and proves nothing. On 16 and 18 Nov the chains were
  poor (CE 1 of 11 and 1 of 24 its way). Weight stays 0 until a chain passes the PROVEN bar.
- 20 Nov (made Thu 19:45, updated 07:15 / 09:08 with the overnight news) has real driver rows; it is scored after today's minute pull.
- Cards before the move (desk B3 watch-point): the prediction lane alone gives 0-8 scored lines a day; on quiet-news evenings it gives
  none. It does NOT by itself supply 10 early cards a day.

## Not known in these runs (said once, with the reason)
- option premium at the 19:45 close: option quotes are not in the point-in-time inputs (the strike plan says ATM / 1 ITM December).
- GIFT NIFTY / US futures history: no stored history, so the 22:45 cancel check and the market call cannot use them in tests; live they come
  from the 5-second quote file (GIFT NIFTY) and are shown as information with 'no measured tilt'.
- ban / MWPL on past days (only today's NSE ban file is kept).
- The written-reasons layer (the evening brain + red team) is coded as an optional step but NOT run here: this shell has no model key.

Files: v2/predict/{common,features,study,drivers,build,minute,monitor,score,replay}.py · weights v2/data/predict/weights.json
