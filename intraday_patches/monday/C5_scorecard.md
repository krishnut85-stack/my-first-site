# C5 - SCORING AFTER 15:35 - proof

Code: `v2/predict/score.py` (labels, baselines, misses, scorecard text) + `v2/predict/dayscore.py` (job SCORE at 15:50 on trading days: minute
store, else the loop's own bars). Every version (N19 / C22 / U07 / P09) scored apart, the WATCH fold apart, every confirmation / silent card /
TOO LATE / FAILED, every news call (abnormal move vs NIFTY at +5 / +15 / +30 / +60 min), every bottom / top call (HELD within 60 min), the
market call, the MOVERS and KNOWLEDGE CHAIN folds, and every 2%+ mover not predicted (headline 3%+). Labels on the open -> 15:10 leg: BIG RIGHT /
RIGHT-TRADABLE (+1% before -0.6% within 60 min of the trigger) / RIGHT-NOT-TRADABLE / FLAT / WRONG SIDE; HOW EARLY and MOVE LEFT at the trigger.
Baselines printed beside: the day's base rate, yesterday's movers, the volatility-only list. Every line ends NOT PROVEN until 20 days.

## 2026-11-20
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
EDGE (desk 18:00) 2026-11-20 · names 18 (with a reason 7, price-only 11) · base CE 1%/2%: 51%/21% · PE: 2%/1%
  TV           n  1 · its way >=1% 100% · >=2% 100% (base 21%, lift 4.84) · wrong side   0% · next close >=1%: not known · move left 2.4% · ahead of the half move 167 min
  news         n  5 · its way >=1%  20% · >=2%   0% (base  9%, lift 0.0) · wrong side  40% · next close >=1%: not known · move left 0.9% · ahead of the half move 0 min
  price-only   n 11 · its way >=1%   9% · >=2%   0% (base 21%, lift 0.0) · wrong side   0% · next close >=1%: not known · move left 1.0% · ahead of the half move -10 min
  results      n  1 · its way >=1%   0% · >=2%   0% (base 21%, lift 0.0) · wrong side   0% · next close >=1%: not known · move left 1.7% · ahead of the half move 3 min
  TOP 5 by rank: >=1% 20% · >=2% 0% (base 13%) · wrong 20%
```

## 2026-11-16
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
EDGE (desk 18:00) 2026-11-16 · names 6 (with a reason 0, price-only 6) · base CE 1%/2%: 11%/4% · PE: 40%/17%
  price-only   n  6 · its way >=1%  17% · >=2%   0% (base 15%, lift 0.0) · wrong side   0% · next close >=1%: 67% · move left 0.9% · ahead of the half move -6 min
  TOP 5 by rank: >=1% 20% · >=2% 0% (base 14%) · wrong 0%
```

## 2026-11-18
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
EDGE (desk 18:00) 2026-11-18 · names 9 (with a reason 1, price-only 8) · base CE 1%/2%: 5%/3% · PE: 45%/18%
  price-only   n  8 · its way >=1%  25% · >=2%  25% (base 12%, lift 2.05) · wrong side  38% · next close >=1%: 12% · move left 1.0% · ahead of the half move -1 min
  sector-chain n  1 · its way >=1%   0% · >=2%   0% (base  3%, lift 0.0) · wrong side 100% · next close >=1%: 100% · move left 0.0% · ahead of the half move 0 min
  TOP 5 by rank: >=1% 40% · >=2% 40% (base 12%) · wrong 40%
```

## 2026-11-19
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
EDGE (desk 18:00) 2026-11-19 · names 13 (with a reason 0, price-only 13) · base CE 1%/2%: 42%/21% · PE: 8%/0%
  price-only   n 13 · its way >=1%  23% · >=2%   0% (base 12%, lift 0.0) · wrong side   0% · next close >=1%: 38% · move left 1.0% · ahead of the half move -1 min
  TOP 5 by rank: >=1% 20% · >=2% 0% (base 5%) · wrong 0%
```

## 2026-10-29
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
EDGE (desk 18:00) 2026-10-29 · names 12 (with a reason 1, price-only 11) · base CE 1%/2%: 32%/14% · PE: 13%/3%
  price-only   n 11 · its way >=1%  18% · >=2%   9% (base 13%, lift 0.69) · wrong side   9% · next close >=1%: 18% · move left 0.8% · ahead of the half move 0 min
  sector-chain n  1 · its way >=1% 100% · >=2%   0% (base 14%, lift 0.0) · wrong side   0% · next close >=1%: 0% · move left 2.5% · ahead of the half move 0 min
  TOP 5 by rank: >=1% 20% · >=2% 0% (base 12%) · wrong 0%
```

## 2026-10-27
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
EDGE (desk 18:00) 2026-10-27 · names 10 (with a reason 0, price-only 10) · base CE 1%/2%: 38%/17% · PE: 9%/2%
  price-only   n 10 · its way >=1%  30% · >=2%  20% (base 17%, lift 1.18) · wrong side   0% · next close >=1%: 40% · move left 1.5% · ahead of the half move 4 min
  TOP 5 by rank: >=1% 40% · >=2% 40% (base 17%) · wrong 0%
```

## Tuning-day replay (14 sessions, 23 Oct-17 Nov, point-in-time each)
- CE: scored lines 0, right 0, wrong 0 · watch fold 8, right 2, wrong 6 · knowledge chains 184 named, 35 its way, 29 against
- PE: scored lines 0, right 0, wrong 0 · watch fold 5, right 2, wrong 2 · knowledge chains 240 named, 42 its way, 49 against
- MOVERS WATCH: 0 named, 0 moved 2% either way (0%) vs all names 0% on average
- market call right 10 of 14 (always MIXED - no measured tilt)

| day | drivers seen | P09 scored / watch (right-wrong) | movers 2% either way | base CE / PE | market |
|---|---|---|---|---|---|
| 2026-10-23 | 49 | CE bounce 3 (0-3); MOVER 25 (0-0) | None | 3% / 83% | DOWN |
| 2026-10-26 | 29 | CE bounce 4 (0-3); PE watch 1 (1-0); MOVER 25 (4-2) | None | 38% / 16% | MIXED |
| 2026-10-28 | 13 | CE bounce 4 (0-4); PE watch 1 (0-0); MOVER 25 (1-0) | None | 28% / 18% | MIXED |
| 2026-10-30 | 20 | CE watch 1 (0-1); CE bounce 3 (0-3); MOVER 25 (4-1) | None | 13% / 32% | UP |
| 2026-11-02 | 17 | CE bounce 4 (3-0); PE watch 1 (1-0); MOVER 25 (5-1) | None | 44% / 8% | MIXED |
| 2026-11-03 | 52 | CE bounce 2 (0-1); MOVER 25 (2-1) | None | 26% / 13% | MIXED |
| 2026-11-04 | 18 | CE watch 2 (1-1); CE bounce 2 (0-2); PE watch 1 (0-1); MOVER 25 (6-3) | None | 42% / 8% | MIXED |
| 2026-11-05 | 43 | CE watch 1 (0-1); CE bounce 2 (0-2); MOVER 25 (3-2) | None | 27% / 23% | MIXED |
| 2026-11-06 | 80 | CE watch 1 (0-1); MOVER 25 (5-0) | None | 15% / 32% | UP |
| 2026-11-09 | 89 | CE watch 2 (0-2); MOVER 25 (1-0) | None | 18% / 18% | DOWN |
| 2026-11-11 | 54 | MOVER 25 (8-1) | None | 34% / 10% | MIXED |
| 2026-11-12 | 46 | CE watch 1 (1-0); MOVER 25 (7-2) | None | 30% / 8% | MIXED |
| 2026-11-13 | 60 | CE bounce 1 (0-1); PE watch 1 (0-1); MOVER 25 (4-4) | None | 15% / 12% | MIXED |
| 2026-11-17 | 86 | CE bounce 1 (0-1); MOVER 25 (1-0) | None | 25% / 5% | MIXED |
