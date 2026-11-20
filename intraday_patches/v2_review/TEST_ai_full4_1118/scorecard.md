# TEST OBSERVER scorecard - TEST_ai_full4_1118 (replayed day 2026-11-18)

Made 2026-11-19 22:25:52 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full4_1118`. Done because: run.json written by the player (the day's end).

## In one line
TEST_ai_full4_1118 2026-11-18: catch cards 0 / 28 / 25 / 0 · cards+WATCH 13 / 34 / 5 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 25, late 1, missed 4 · rings 19 (09:15-09:45 1) · AI 1629 of 1629 (100%), $0.537, 338 calls · flags MISSED MOVER 5, COST SPIKE 1, NEWS DIRECTION WRONG 26

## Did it catch the movers?
53 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 28 | 25 | 0 |
| v2 cards + WATCH | 13 | 34 | 5 | 1 |
| old system | 35 | 18 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 30 crossed 3%; in time 25, late 1, missed 4.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| NAVINFLUOR | 11:04 UP | 4.72 | MISSED | LATE | nothing on this share |
| DIXON | 12:04 DOWN | -3.56 | MISSED | LATE | nothing on this share |
| ANGELONE | 09:20 UP | -3.29 | MISSED | LATE | first 11:24 PE GET READY WATCH (AI) · best 11:44 PE GET READY MUST SEE (AI) · last 12:53 PE nothing MUST SEE (rules): cancelled: the GET READY call from 12:46 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| SAGILITY | 10:18 UP | 2.87 | MISSED | BEFORE | nothing on this share |
| IREDA | 10:03 UP | 2.04 | LATE 11:21 | LATE | first 11:21 CE GET READY WATCH (AI) · best 11:21 CE GET READY WATCH (AI) · last 12:35 CE nothing LOG (rules): cancelled: the GET READY call from 12:27 no longer holds (price left the trigger zone, the sector faded, or the score f… |

## Rings (phone alarms)
19 rings; 1 of them 09:15-09:45. By hour: 09 h 2, 10 h 4, 11 h 5, 12 h 4, 13 h 2, 14 h 2.

## The AI
AI state: ON. AI decided 1629 of 1629 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 1058 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (1055 rows)
- by design: hard block: F&O ban (2 rows)
- by design: rule veto: (d) its sector oil & gas is rising (+0.21%) - no PE against the sector unless DI (1 rows)

338 AI calls, $0.537 in all; the dearest single call $0.0516; 0 errors; stop reasons {'end_turn': 338}.
Cost by kind: final $0.3450, rank $0.0062, second $0.0035, triage $0.1819. Cost by model: final-tier model $0.3450, routine-tier model $0.1916.
Latency: p50 3719 ms, p95 7796 ms, max 9645 ms over 338 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 422, wrong 329, flat 394, not known 0; average move the call's way 0.03%
- after 60 min: right 515, wrong 345, flat 285, not known 0; average move the call's way 0.08%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 22, late 220, the wrong way 2, share did not move 2% 901 (of 1145 new GO NOW / GET READY decisions, 122 of them cards)

## Flags
MISSED MOVER: 5, COST SPIKE: 1, NEWS DIRECTION WRONG: 26
- 09:20 MISSED MOVER: ANGELONE crossed +3.0% at 09:20 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on ANGELONE by then
- 09:39 COST SPIKE: one AI call cost $0.052 (over $0.05): final final-tier model at 21:59:55
- 09:40 NEWS DIRECTION WRONG: LUPIN CE GET READY at 09:10 was news-driven; the share went -1.01% against it in 30 min (worst -1.13%)
- 09:45 NEWS DIRECTION WRONG: SYRMA CE GET READY at 09:15 was news-driven; the share went -1.71% against it in 30 min (worst -1.90%)
- 09:45 NEWS DIRECTION WRONG: GODREJPROP PE GET READY at 09:15 was news-driven; the share went -0.64% against it in 30 min (worst -1.31%)
- 09:54 NEWS DIRECTION WRONG: CDSL CE GET READY at 09:24 was news-driven; the share went -1.52% against it in 30 min (worst -1.87%)
- 09:57 NEWS DIRECTION WRONG: BHARATFORG PE GET READY at 09:27 was news-driven; the share went -0.61% against it in 30 min (worst -0.67%)
- 10:00 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 09:30 was news-driven; the share went -1.20% against it in 30 min (worst -1.23%)
- 10:00 NEWS DIRECTION WRONG: BSE CE GET READY at 09:30 was news-driven; the share went -0.77% against it in 30 min (worst -0.95%)
- 10:03 MISSED MOVER: IREDA crossed +3.0% at 10:03 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on IREDA by then
- 10:05 NEWS DIRECTION WRONG: IRFC PE GET READY at 09:35 was news-driven; the share went -0.71% against it in 30 min (worst -0.74%)
- 10:07 NEWS DIRECTION WRONG: NTPC PE GET READY at 09:37 was news-driven; the share went -0.53% against it in 30 min (worst -0.75%)
- 10:10 NEWS DIRECTION WRONG: DLF PE GET READY at 09:40 was news-driven; the share went -1.02% against it in 30 min (worst -1.02%)
- 10:10 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but KALYANKJIL went +0.73% the thesis way (PE) in 30 min
- 10:18 MISSED MOVER: SAGILITY crossed +3.0% at 10:18 (+3.14% vs the previous close) with no CE call by then · the engine said nothing on SAGILITY by then
- 10:20 NEWS DIRECTION WRONG: SBILIFE PE GET READY at 09:50 was news-driven; the share went -0.65% against it in 30 min (worst -0.65%)
- 10:47 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but ETERNAL went +0.86% the thesis way (PE) in 60 min
- 10:51 NEWS DIRECTION WRONG: SHRIRAMFIN PE GET READY at 09:51 was news-driven; the share went -0.52% against it in 60 min (worst -0.82%)
- 11:04 MISSED MOVER: NAVINFLUOR crossed +3.0% at 11:04 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on NAVINFLUOR by then
- 11:57 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but SAIL went +0.81% the thesis way (PE) in 30 min
- 12:04 MISSED MOVER: DIXON crossed -3.0% at 12:04 (-3.02% vs the previous close) with no PE call by then · the engine said nothing on DIXON by then
- 12:33 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but HINDZINC went +0.73% the thesis way (PE) in 30 min
- 13:06 NEWS DIRECTION WRONG: ANGELONE PE GET READY at 12:36 was news-driven; the share went -0.88% against it in 30 min (worst -1.75%)
- 13:09 NEWS DIRECTION WRONG: BSE PE GET READY at 12:39 was news-driven; the share went -0.58% against it in 30 min (worst -1.00%)
- 13:12 NEWS DIRECTION WRONG: MOTILALOFS PE GET READY at 12:42 was news-driven; the share went -0.99% against it in 30 min (worst -1.13%)
- 13:17 NEWS DIRECTION WRONG: SHREECEM PE GET READY at 12:47 was news-driven; the share went -0.51% against it in 30 min (worst -0.51%)
- 13:18 NEWS DIRECTION WRONG: BSE PE GET READY at 12:48 was news-driven; the share went -1.65% against it in 30 min (worst -2.14%)
- 14:14 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 13:14 was news-driven; the share went -0.53% against it in 60 min (worst -0.53%)
- 14:19 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 13:49 was news-driven; the share went -0.92% against it in 30 min (worst -0.96%)
- 14:27 NEWS DIRECTION WRONG: 360ONE PE GET READY at 13:27 was news-driven; the share went -0.54% against it in 60 min (worst -0.84%)
- 14:40 NEWS DIRECTION WRONG: IOC PE GET READY at 13:40 was news-driven; the share went -0.61% against it in 60 min (worst -0.63%)
- 14:48 NEWS DIRECTION WRONG: ABB PE GET READY at 13:48 was news-driven; the share went -0.79% against it in 60 min (worst -0.85%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
