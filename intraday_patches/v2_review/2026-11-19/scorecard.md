# TEST OBSERVER scorecard - 2026-11-19 (replayed day 2026-11-19)

Made 2026-11-19 21:01:26 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/2026-11-19`. Done because: run.json written by the player (the day's end).

## In one line
2026-11-19 2026-11-19: catch cards 0 / 1 / 56 / 0 · cards+WATCH 5 / 2 / 46 / 4 · old 26 / 20 / 8 / 3 (before/late/missed/wrong, 2%+) · 3% movers 46: in time 7, late 4, missed 35 · rings 14 (09:15-09:45 13) · AI 0 of 135 (0%), $0.000, 0 calls · flags MISSED MOVER 17, NOISE 1, NEWS DIRECTION WRONG 12

## Did it catch the movers?
57 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 1 | 56 | 0 |
| v2 cards + WATCH | 5 | 2 | 46 | 4 |
| old system | 26 | 20 | 8 | 3 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 46 crossed 3%; in time 7, late 4, missed 35.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| VOLTAS | 09:17 UP | 9.03 | MISSED | BEFORE | nothing on this share |
| BLUESTARCO | 09:18 UP | 8.77 | MISSED | BEFORE | nothing on this share |
| PAYTM | 09:16 DOWN | -8.68 | LATE 09:16 | BEFORE | first 09:16 PE GET READY WATCH (rules) · best 09:16 PE GET READY WATCH (rules) · last 09:32 PE nothing ? (rules): cancelled: the GET READY call from 09:27 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| IREDA | 09:25 UP | 8.35 | MISSED | BEFORE | nothing on this share |
| MARUTI | 09:36 UP | 7.58 | MISSED | BEFORE | nothing on this share |
| AMBER | 09:54 UP | 7.38 | MISSED | LATE | nothing on this share |
| PGEL | 09:22 UP | 7.24 | LATE 09:22 | BEFORE | first 09:22 CE GET READY WATCH (rules) · best 09:25 CE GET READY MUST SEE (rules) · last 09:34 CE nothing LOG (rules): withheld: (g) futures OI falling (15 min -0.07%, 3 min -0.34%, day -0.27%) - no CE without fresh longs |
| CROMPTON | 09:21 UP | 6.13 | MISSED | BEFORE | nothing on this share |
| HYUNDAI | 10:12 UP | 5.8 | MISSED | BEFORE | first 09:10 PE GET READY WATCH (rules) · best 09:10 PE GET READY WATCH (rules) · last 09:16 PE nothing ? (rules): cancelled: the GET READY call from 09:10 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| HAVELLS | 10:40 UP | 5.33 | MISSED | LATE | nothing on this share |
| COLPAL | 09:47 UP | 5.22 | MISSED | BEFORE | nothing on this share |
| MOTHERSON | 10:20 UP | 5.21 | MISSED | LATE | first 09:10 PE GET READY WATCH (rules) · best 09:10 PE GET READY WATCH (rules) · last 09:16 PE nothing ? (rules): cancelled: the GET READY call from 09:10 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| EICHERMOT | 09:49 UP | 4.66 | MISSED | BEFORE | nothing on this share |
| M&M | 09:59 UP | 4.46 | MISSED | LATE | nothing on this share |
| IDFCFIRSTB | 09:44 UP | 4.37 | MISSED | LATE | nothing on this share |

## Rings (phone alarms)
14 rings; 13 of them 09:15-09:45. By hour: 09 h 14.

## The AI
AI state: not known. AI decided 0 of 135 (0%) of the GO NOW / GET READY triage rows.
Rules rows: 0 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- not given: None (236 rows)

0 AI calls, $0.000 in all; the dearest single call $0.0000; 0 errors; stop reasons {}.
Cost by kind: . Cost by model: .
Latency: not known: latency not logged (the ai_raw rows of this run carry no 'ms' field).

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 38, wrong 62, flat 21, not known 0; average move the call's way -0.35%
- after 60 min: right 40, wrong 66, flat 15, not known 0; average move the call's way -0.38%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 5, late 7, the wrong way 8, share did not move 2% 101 (of 121 new GO NOW / GET READY decisions, 8 of them cards)

## Flags
MISSED MOVER: 17, NOISE: 1, NEWS DIRECTION WRONG: 12
- 09:16 MISSED MOVER: PAYTM crossed -3.0% at 09:16 (-6.03% vs the previous close) with no PE call by then · the engine said: first 09:16 PE GET READY WATCH (rules); best 09:16 PE GET READY WATCH (rules); last 09:16 PE GET READY WATCH (rules): opening flood window: held for the 09:20 sector picture
- 09:17 NOISE: 7 rings in 15 virtual minutes (09:02-09:17), over 6
- 09:17 MISSED MOVER: VOLTAS crossed +3.0% at 09:17 (+3.38% vs the previous close) with no CE call by then · the engine said nothing on VOLTAS by then
- 09:18 MISSED MOVER: BLUESTARCO crossed +3.0% at 09:18 (+3.59% vs the previous close) with no CE call by then · the engine said nothing on BLUESTARCO by then
- 09:19 MISSED MOVER: POLICYBZR crossed -3.0% at 09:19 (-3.56% vs the previous close) with no PE call by then · the engine said nothing on POLICYBZR by then
- 09:21 MISSED MOVER: CROMPTON crossed +3.0% at 09:21 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on CROMPTON by then
- 09:22 MISSED MOVER: PGEL crossed +3.0% at 09:22 (+3.34% vs the previous close) with no CE call by then · the engine said: first 09:22 CE GET READY WATCH (rules); best 09:25 CE GET READY MUST SEE (rules); last 09:25 CE GET READY MUST SEE (rules): ELECTRONICS & HARDWARE UP - confirmed since 09:25 · names: PGEL CE (GET R…
- 09:24 MISSED MOVER: UNITDSPR crossed -3.0% at 09:24 (-3.08% vs the previous close) with no PE call by then · the engine said nothing on UNITDSPR by then
- 09:25 MISSED MOVER: IREDA crossed +3.0% at 09:25 (+3.12% vs the previous close) with no CE call by then · the engine said nothing on IREDA by then
- 09:36 MISSED MOVER: MARUTI crossed +3.0% at 09:36 (+3.02% vs the previous close) with no CE call by then · the engine said nothing on MARUTI by then
- 09:40 NEWS DIRECTION WRONG: MOTHERSON PE GET READY at 09:10 was news-driven; the share went -2.47% against it in 30 min (worst -2.60%)
- 09:44 MISSED MOVER: IDFCFIRSTB crossed +3.0% at 09:44 (+3.02% vs the previous close) with no CE call by then · the engine said nothing on IDFCFIRSTB by then
- 09:46 NEWS DIRECTION WRONG: LTM PE GET READY at 09:16 was news-driven; the share went -0.67% against it in 30 min (worst -0.75%)
- 09:46 NEWS DIRECTION WRONG: RADICO PE GET READY at 09:16 was news-driven; the share went -1.48% against it in 30 min (worst -1.48%)
- 09:47 MISSED MOVER: COLPAL crossed +3.0% at 09:47 (+3.09% vs the previous close) with no CE call by then · the engine said nothing on COLPAL by then
- 09:46 MISSED MOVER: PIDILITIND crossed +3.0% at 09:46 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on PIDILITIND by then
- 09:46 MISSED MOVER: PNB crossed +3.0% at 09:46 (+3.10% vs the previous close) with no CE call by then · the engine said nothing on PNB by then
- 09:50 NEWS DIRECTION WRONG: ANGELONE PE GET READY at 09:20 was news-driven; the share went -1.36% against it in 30 min (worst -1.61%)
- 09:49 MISSED MOVER: EICHERMOT crossed +3.0% at 09:49 (+3.04% vs the previous close) with no CE call by then · the engine said nothing on EICHERMOT by then
- 09:52 NEWS DIRECTION WRONG: CAMS PE GET READY at 09:22 was news-driven; the share went -0.55% against it in 30 min (worst -0.57%)
- 09:54 MISSED MOVER: AMBER crossed +3.0% at 09:54 (+3.04% vs the previous close) with no CE call by then · the engine said nothing on AMBER by then
- 09:59 MISSED MOVER: M&M crossed +3.0% at 09:59 (+3.12% vs the previous close) with no CE call by then · the engine said nothing on M&M by then
- 10:02 NEWS DIRECTION WRONG: INFY PE GO NOW at 09:32 was news-driven; the share went -0.51% against it in 30 min (worst -0.68%)
- 10:02 MISSED MOVER: SYRMA crossed +3.0% at 10:02 (+3.08% vs the previous close) with no CE call by then · the engine said nothing on SYRMA by then
- 10:08 NEWS DIRECTION WRONG: MOTILALOFS PE GET READY at 09:38 was news-driven; the share went -1.07% against it in 30 min (worst -2.01%)
- 10:40 NEWS DIRECTION WRONG: UNITDSPR PE GET READY at 09:40 was news-driven; the share went -0.92% against it in 60 min (worst -1.02%)
- 10:53 NEWS DIRECTION WRONG: WIPRO PE GO NOW at 09:53 was news-driven; the share went -0.60% against it in 60 min (worst -0.60%)
- 10:28 NEWS DIRECTION WRONG: MAZDOCK CE GET READY at 09:58 was news-driven; the share went -0.63% against it in 30 min (worst -0.77%)
- 11:04 NEWS DIRECTION WRONG: HCLTECH PE GO NOW at 10:04 was news-driven; the share went -0.99% against it in 60 min (worst -1.23%)
- 11:05 NEWS DIRECTION WRONG: TCS PE GO NOW at 10:05 was news-driven; the share went -0.73% against it in 60 min (worst -0.85%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
