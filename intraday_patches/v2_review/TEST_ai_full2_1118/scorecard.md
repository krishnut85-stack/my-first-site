# TEST OBSERVER scorecard - TEST_ai_full2_1118 (replayed day 2026-11-18)

Made 2026-11-19 20:48:12 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full2_1118`. Done because: run.json written by the player (the day's end).

## In one line
TEST_ai_full2_1118 2026-11-18: catch cards 0 / 38 / 15 / 0 · cards+WATCH 15 / 31 / 6 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 24, late 1, missed 5 · rings 163 (09:15-09:45 17) · AI 1650 of 1650 (100%), $0.537, 301 calls · flags MISSED MOVER 6, NOISE 9, NEWS DIRECTION WRONG 21

## Did it catch the movers?
53 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 38 | 15 | 0 |
| v2 cards + WATCH | 15 | 31 | 6 | 1 |
| old system | 35 | 18 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 30 crossed 3%; in time 24, late 1, missed 5.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| NAVINFLUOR | 11:04 UP | 4.72 | MISSED | LATE | nothing on this share |
| DIXON | 12:04 DOWN | -3.56 | MISSED | LATE | nothing on this share |
| ANGELONE | 09:20 UP | -3.29 | MISSED | LATE | first 11:24 PE GET READY WATCH (AI) · best 11:50 PE GET READY MUST SEE (AI) · last 12:53 PE nothing MUST SEE (rules): cancelled: the GET READY call from 12:50 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| SAGILITY | 10:18 UP | 2.87 | MISSED | BEFORE | nothing on this share |
| CIPLA | 11:34 UP | 2.09 | LATE 14:03 | LATE | first 14:03 CE GET READY WATCH (AI) · best 14:03 CE GET READY WATCH (AI) · last 14:30 CE nothing LOG (rules): cancelled: the GET READY call from 14:23 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| IREDA | 10:03 UP | 2.04 | MISSED | LATE | nothing on this share |

## Rings (phone alarms)
163 rings; 17 of them 09:15-09:45. By hour: 09 h 22, 10 h 31, 11 h 38, 12 h 40, 13 h 22, 14 h 10.

## The AI
AI state: ON. AI decided 1650 of 1650 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 1028 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (1026 rows)
- by design: rule veto: (d) its sector oil & gas is rising (+0.21%) - no PE against the sector unless DI (1 rows)
- by design: rule veto: (g) futures OI falling (15 min -0.53%, 3 min -0.70%, day -0.25%) - no CE without (1 rows)

301 AI calls, $0.537 in all; the dearest single call $0.0304; 0 errors; stop reasons {'end_turn': 301}.
Cost by kind: final $0.4147, second $0.0038, triage $0.1185. Cost by model: claude-fable-5-2 $0.4147, claude-haiku-5-5 $0.1223.
Latency: p50 2328 ms, p95 5305 ms, max 10236 ms over 301 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 458, wrong 341, flat 450, not known 0; average move the call's way 0.03%
- after 60 min: right 559, wrong 370, flat 320, not known 0; average move the call's way 0.09%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 23, late 267, the wrong way 1, share did not move 2% 958 (of 1249 new GO NOW / GET READY decisions, 211 of them cards)

## Flags
MISSED MOVER: 6, NOISE: 9, NEWS DIRECTION WRONG: 21
- 09:20 MISSED MOVER: ANGELONE crossed +3.0% at 09:20 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on ANGELONE by then
- 09:28 NOISE: 7 rings in 15 virtual minutes (09:13-09:28), over 6
- 09:45 NEWS DIRECTION WRONG: LUPIN CE GET READY at 09:15 was news-driven; the share went -1.01% against it in 30 min (worst -1.13%)
- 09:45 NEWS DIRECTION WRONG: SYRMA CE GET READY at 09:15 was news-driven; the share went -1.71% against it in 30 min (worst -1.90%)
- 09:45 NEWS DIRECTION WRONG: GODREJPROP PE GET READY at 09:15 was news-driven; the share went -0.64% against it in 30 min (worst -1.31%)
- 09:50 NOISE: 7 rings in 15 virtual minutes (09:35-09:50), over 6
- 09:54 NEWS DIRECTION WRONG: CDSL CE GET READY at 09:24 was news-driven; the share went -1.52% against it in 30 min (worst -1.87%)
- 09:57 NEWS DIRECTION WRONG: BHARATFORG PE GET READY at 09:27 was news-driven; the share went -0.61% against it in 30 min (worst -0.67%)
- 10:00 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but HINDZINC went +0.54% the thesis way (PE) in 30 min
- 10:03 MISSED MOVER: IREDA crossed +3.0% at 10:03 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on IREDA by then
- 10:07 NEWS DIRECTION WRONG: NTPC PE GET READY at 09:37 was news-driven; the share went -0.53% against it in 30 min (worst -0.75%)
- 10:07 NEWS DIRECTION WRONG: SIEMENS PE GO NOW at 09:37 was news-driven; the share went -0.51% against it in 30 min (worst -0.83%)
- 10:10 NEWS DIRECTION WRONG: DLF PE GET READY at 09:40 was news-driven; the share went -1.02% against it in 30 min (worst -1.02%)
- 10:10 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but KALYANKJIL went +0.73% the thesis way (PE) in 30 min
- 10:15 NOISE: 7 rings in 15 virtual minutes (10:00-10:15), over 6
- 10:18 MISSED MOVER: SAGILITY crossed +3.0% at 10:18 (+3.14% vs the previous close) with no CE call by then · the engine said nothing on SAGILITY by then
- 10:35 NOISE: 7 rings in 15 virtual minutes (10:20-10:35), over 6
- 10:47 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but ETERNAL went +0.86% the thesis way (PE) in 60 min
- 10:55 NOISE: 51 rings today by 10:55, over 50 for the day
- 11:04 MISSED MOVER: NAVINFLUOR crossed +3.0% at 11:04 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on NAVINFLUOR by then
- 11:34 MISSED MOVER: CIPLA crossed +3.0% at 11:34 (+3.11% vs the previous close) with no CE call by then · the engine said nothing on CIPLA by then
- 11:55 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but SAIL went +0.90% the thesis way (PE) in 30 min
- 12:00 NOISE: 7 rings in 15 virtual minutes (11:45-12:00), over 6
- 12:04 MISSED MOVER: DIXON crossed -3.0% at 12:04 (-3.02% vs the previous close) with no PE call by then · the engine said nothing on DIXON by then
- 12:05 NOISE: 7 rings in 15 virtual minutes (11:50-12:05), over 6
- 13:06 NEWS DIRECTION WRONG: ANGELONE PE GET READY at 12:36 was news-driven; the share went -0.88% against it in 30 min (worst -1.75%)
- 13:09 NEWS DIRECTION WRONG: BSE PE GET READY at 12:39 was news-driven; the share went -0.58% against it in 30 min (worst -1.00%)
- 13:17 NEWS DIRECTION WRONG: SHREECEM PE GET READY at 12:47 was news-driven; the share went -0.51% against it in 30 min (worst -0.51%)
- 13:18 NEWS DIRECTION WRONG: BSE PE GET READY at 12:48 was news-driven; the share went -1.65% against it in 30 min (worst -2.14%)
- 13:26 NOISE: 7 rings in 15 virtual minutes (13:11-13:26), over 6
- 13:47 NOISE: 7 rings in 15 virtual minutes (13:32-13:47), over 6
- 14:14 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 13:14 was news-driven; the share went -0.53% against it in 60 min (worst -0.53%)
- 14:19 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 13:49 was news-driven; the share went -0.92% against it in 30 min (worst -0.96%)
- 14:27 NEWS DIRECTION WRONG: 360ONE PE GET READY at 13:27 was news-driven; the share went -0.54% against it in 60 min (worst -0.84%)
- 14:40 NEWS DIRECTION WRONG: IOC PE GET READY at 13:40 was news-driven; the share went -0.61% against it in 60 min (worst -0.63%)
- 14:48 NEWS DIRECTION WRONG: ABB PE GET READY at 13:48 was news-driven; the share went -0.79% against it in 60 min (worst -0.85%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
