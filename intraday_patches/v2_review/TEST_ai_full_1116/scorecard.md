# TEST OBSERVER scorecard - TEST_ai_full_1116 (replayed day 2026-11-16)

Made 2026-11-19 20:19:43 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full_1116`. Done because: run.json written by the player (the day's end).

## In one line
TEST_ai_full_1116 2026-11-16: catch cards 0 / 6 / 48 / 0 · cards+WATCH 3 / 33 / 17 / 1 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 21, late 4, missed 12 · rings 12 (09:15-09:45 1) · AI 800 of 800 (100%), $0.221, 84 calls · flags MISSED MOVER 15, NEWS DIRECTION WRONG 29

## Did it catch the movers?
54 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 6 | 48 | 0 |
| v2 cards + WATCH | 3 | 33 | 17 | 1 |
| old system | 22 | 21 | 10 | 1 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 37 crossed 3%; in time 21, late 4, missed 12.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| TMPV | 09:16 DOWN | -8.7 | LATE 10:47 | BEFORE | first 10:47 PE GET READY WATCH (AI) · best 12:55 PE GO NOW MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 14:24 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| LAURUSLABS | 10:34 DOWN | -8.42 | LATE 11:30 | LATE | first 11:30 PE GET READY WATCH (AI) · best 11:30 PE GET READY WATCH (AI) · last 11:31 PE nothing LOG (rules): cancelled: the GET READY call from 11:30 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| INOXWIND | 09:16 DOWN | -7.68 | LATE 09:18 | BEFORE | first 09:18 PE GET READY WATCH (AI) · best 09:18 PE GET READY WATCH (AI) · last 14:30 PE nothing LOG (rules): cancelled: the GET READY call from 12:45 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| MAXHEALTH | 09:38 UP | 6.63 | LATE 09:46 | BEFORE | first 09:46 CE GET READY MUST SEE (AI) · best 09:46 CE GET READY MUST SEE (AI) · last 10:51 CE nothing MUST SEE (rules): cancelled: the GET READY call from 10:36 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| FORTIS | 10:04 UP | 5.13 | MISSED | LATE | nothing on this share |
| PATANJALI | 12:08 DOWN | -4.82 | MISSED | LATE | nothing on this share |
| TATACONSUM | 12:26 UP | 3.57 | MISSED | BEFORE | nothing on this share |
| ITC | 10:16 UP | 3.54 | MISSED | LATE | nothing on this share |
| LICHSGFIN | 14:18 UP | 3.49 | MISSED | LATE | nothing on this share |
| YESBANK | 14:58 UP | 3.44 | MISSED | LATE | nothing on this share |
| APOLLOHOSP | 13:38 UP | 2.87 | MISSED | LATE | nothing on this share |
| BHARTIARTL | 09:42 UP | 2.26 | MISSED | BEFORE | nothing on this share |
| SWIGGY | 12:14 UP | 2.14 | MISSED | LATE | nothing on this share |
| KALYANKJIL | 09:20 UP | 1.6 | MISSED | not a 2% mover at the close | nothing on this share |
| EICHERMOT | 09:16 UP | -0.67 | MISSED | not a 2% mover at the close | nothing on this share |

## Rings (phone alarms)
12 rings; 1 of them 09:15-09:45. By hour: 09 h 2, 10 h 2, 12 h 1, 13 h 5, 14 h 2.

## The AI
AI state: ON. AI decided 800 of 800 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 521 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (519 rows)
- by design: rule veto: (g) futures OI falling (15 min -0.73%, 3 min -0.55%, day -0.06%) - no CE without (1 rows)
- by design: rule veto: (g) futures OI falling (15 min -0.06%, 3 min -0.43%, day -0.24%) - no CE without (1 rows)

84 AI calls, $0.221 in all; the dearest single call $0.0316; 0 errors; stop reasons {'end_turn': 84}.
Cost by kind: final $0.1996, second $0.0040, triage $0.0174. Cost by model: final-tier model $0.1996, routine-tier model $0.0215.
Latency: not known: latency not logged (the ai_raw rows of this run carry no 'ms' field).

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 223, wrong 167, flat 162, not known 0; average move the call's way 0.05%
- after 60 min: right 253, wrong 147, flat 152, not known 0; average move the call's way 0.14%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 6, late 161, the wrong way 6, share did not move 2% 379 (of 552 new GO NOW / GET READY decisions, 20 of them cards)

## Flags
MISSED MOVER: 15, NEWS DIRECTION WRONG: 29
- 09:16 MISSED MOVER: EICHERMOT crossed +3.0% at 09:16 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on EICHERMOT by then
- 09:16 MISSED MOVER: INOXWIND crossed -3.0% at 09:16 (-8.15% vs the previous close) with no PE call by then · the engine said nothing on INOXWIND by then
- 09:16 MISSED MOVER: TMPV crossed -3.0% at 09:16 (-7.85% vs the previous close) with no PE call by then · the engine said nothing on TMPV by then
- 09:20 MISSED MOVER: KALYANKJIL crossed +3.0% at 09:20 (+3.13% vs the previous close) with no CE call by then · the engine said nothing on KALYANKJIL by then
- 09:25 MISSED MOVER: ATHERENERG crossed +3.0% at 09:25 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on ATHERENERG by then
- 09:38 MISSED MOVER: MAXHEALTH crossed +3.0% at 09:38 (+3.11% vs the previous close) with no CE call by then · the engine said nothing on MAXHEALTH by then
- 09:42 MISSED MOVER: BHARTIARTL crossed +3.0% at 09:42 (+3.01% vs the previous close) with no CE call by then · the engine said nothing on BHARTIARTL by then
- 09:46 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 09:16 was news-driven; the share went -0.88% against it in 30 min (worst -0.88%)
- 09:46 NEWS DIRECTION WRONG: MUTHOOTFIN PE GET READY at 09:16 was news-driven; the share went -0.50% against it in 30 min (worst -0.58%)
- 09:53 NEWS DIRECTION WRONG: NTPC PE GET READY at 09:23 was news-driven; the share went -0.66% against it in 30 min (worst -0.66%)
- 09:55 NEWS DIRECTION WRONG: INOXWIND PE GET READY at 09:25 was news-driven; the share went -1.65% against it in 30 min (worst -2.00%)
- 09:56 NEWS DIRECTION WRONG: SIEMENS PE GET READY at 09:26 was news-driven; the share went -0.55% against it in 30 min (worst -0.55%)
- 09:57 NEWS DIRECTION WRONG: IEX PE GET READY at 09:27 was news-driven; the share went -0.73% against it in 30 min (worst -1.10%)
- 09:57 NEWS DIRECTION WRONG: JIOFIN PE GET READY at 09:27 was news-driven; the share went -0.98% against it in 30 min (worst -1.14%)
- 10:04 MISSED MOVER: FORTIS crossed +3.0% at 10:04 (+3.00% vs the previous close) with no CE call by then · the engine said nothing on FORTIS by then
- 10:15 NEWS DIRECTION WRONG: INDUSTOWER CE GET READY at 09:45 was news-driven; the share went -0.66% against it in 30 min (worst -0.92%)
- 10:16 NEWS DIRECTION WRONG: AI second reading said the CE thesis direction was wrong, but MAXHEALTH went +0.71% the thesis way (CE) in 30 min
- 10:16 MISSED MOVER: ITC crossed +3.0% at 10:16 (+3.00% vs the previous close) with no CE call by then · the engine said nothing on ITC by then
- 10:30 NEWS DIRECTION WRONG: DIXON PE GET READY at 09:30 was news-driven; the share went -0.68% against it in 60 min (worst -1.05%)
- 10:34 MISSED MOVER: LAURUSLABS crossed -3.0% at 10:34 (-3.21% vs the previous close) with no PE call by then · the engine said nothing on LAURUSLABS by then
- 10:38 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but SIEMENS went +1.05% the thesis way (PE) in 60 min
- 10:38 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but AMBER went +1.50% the thesis way (PE) in 30 min
- 10:38 NEWS DIRECTION WRONG: KAYNES PE GET READY at 10:08 was news-driven; the share went -1.60% against it in 30 min (worst -1.96%)
- 10:42 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but POWERINDIA went +0.77% the thesis way (PE) in 60 min
- 10:46 NEWS DIRECTION WRONG: ASIANPAINT CE GET READY at 09:46 was news-driven; the share went -0.65% against it in 60 min (worst -0.65%)
- 10:48 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but PREMIERENE went +1.29% the thesis way (PE) in 60 min
- 11:26 NEWS DIRECTION WRONG: ASIANPAINT CE GET READY at 10:26 was news-driven; the share went -0.64% against it in 60 min (worst -0.68%)
- 11:31 NEWS DIRECTION WRONG: ANGELONE PE GET READY at 10:31 was news-driven; the share went -0.62% against it in 60 min (worst -0.69%)
- 11:43 NEWS DIRECTION WRONG: CAMS PE GET READY at 11:13 was news-driven; the share went -0.57% against it in 30 min (worst -0.91%)
- 11:44 NEWS DIRECTION WRONG: DIVISLAB PE GET READY at 11:14 was news-driven; the share went -0.52% against it in 30 min (worst -0.73%)
- 12:00 NEWS DIRECTION WRONG: LAURUSLABS PE GET READY at 11:30 was news-driven; the share went -0.88% against it in 30 min (worst -1.35%)
- 12:05 NEWS DIRECTION WRONG: NMDC PE GO NOW at 11:05 was news-driven; the share went -0.66% against it in 60 min (worst -0.66%)
- 12:09 NEWS DIRECTION WRONG: MOTILALOFS PE GET READY at 11:09 was news-driven; the share went -0.71% against it in 60 min (worst -0.71%)
- 12:08 MISSED MOVER: PATANJALI crossed -3.0% at 12:08 (-3.11% vs the previous close) with no PE call by then · the engine said nothing on PATANJALI by then
- 12:15 NEWS DIRECTION WRONG: TMPV PE GET READY at 11:15 was news-driven; the share went -0.53% against it in 60 min (worst -0.73%)
- 12:14 MISSED MOVER: SWIGGY crossed +3.0% at 12:14 (+3.13% vs the previous close) with no CE call by then · the engine said nothing on SWIGGY by then
- 12:26 MISSED MOVER: TATACONSUM crossed +3.0% at 12:26 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on TATACONSUM by then
- 12:33 NEWS DIRECTION WRONG: NAM-INDIA PE GET READY at 12:03 was news-driven; the share went -1.09% against it in 30 min (worst -1.15%)
- 12:49 NEWS DIRECTION WRONG: TATAPOWER PE GET READY at 12:19 was news-driven; the share went -0.70% against it in 30 min (worst -0.74%)
- 13:19 NEWS DIRECTION WRONG: ADANIGREEN PE GET READY at 12:19 was news-driven; the share went -0.66% against it in 60 min (worst -0.66%)
- ... 4 more in flags.jsonl

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
