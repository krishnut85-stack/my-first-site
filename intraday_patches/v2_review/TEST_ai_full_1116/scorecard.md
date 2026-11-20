# TEST OBSERVER scorecard - TEST_ai_full_1116 (replayed day 2026-11-16)

Made 2026-11-19 20:19:43 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full_1116`. Done because: run.json written by the player (the day's end).

## In one line
EDGE TEST_ai_full_1116 2026-11-16: 128 names a day (74 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 1/5 20% vs 14% lift 1.48, >=2% 1/5 20% vs 3% lift 6.06 · all names >=1% 21/128 16% vs 18% lift 0.93, >=2% 10/128 8% vs 6% lift 1.26 · knowledge >=2% 6/74 8% vs 8% lift 1.03 · all names >=2% to the next close 18/128 14% vs 13% lift 1.05 · old system >=2% 16/167 10% vs 7% lift 1.43 (167 names) || coverage (not the goal): TEST_ai_full_1116 2026-11-16: catch cards 0 / 6 / 48 / 0 · cards+WATCH 3 / 33 / 17 / 1 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 21, late 4, missed 12 · rings 12 (09:15-09:45 1) · AI 800 of 800 (100%), $0.221, 84 calls · flags MISSED MOVER 15, NEWS DIRECTION WRONG 29

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-16, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-17 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 128 | 21/128 = 16% vs base 18% → lift 0.93 | 10/128 = 8% vs base 6% → lift 1.26 | 18/128 = 14% vs base 13% → lift 1.05 | 2 (2%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 74 | 13/74 = 18% vs base 21% → lift 0.84 | 6/74 = 8% vs base 8% → lift 1.03 | 10/74 = 14% vs base 16% → lift 0.86 | 1 (1%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 9 | 2/9 = 22% vs base 7% → lift 3.25 | 1/9 = 11% vs base 2% → lift 6.61 | 1/9 = 11% vs base 7% → lift 1.57 | 0 (0%) | NOT PROVEN (n < 30) |
| channel: engine note 0715 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: engine note 1945 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: go now / get ready (any lane) | 108 | 19/108 = 18% vs base 16% → lift 1.07 | 8/108 = 7% vs base 5% → lift 1.41 | 17/108 = 16% vs base 12% → lift 1.31 | 2 (2%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 6 | 0/6 = 0% vs base 19% → lift 0.0 | 0/6 = 0% vs base 7% → lift 0.0 | 2/6 = 33% vs base 14% → lift 2.33 | 0 (0%) | NOT PROVEN (n < 30) |
| source: trader read | 2 | 1/2 = 50% vs base 15% → lift 3.41 | 0/2 = 0% vs base 5% → lift 0.0 | 1/2 = 50% vs base 11% → lift 4.64 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 1 | 0/1 = 0% vs base 27% → lift 0.0 | 0/1 = 0% vs base 10% → lift 0.0 | 0/1 = 0% vs base 17% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: results | 4 | 1/4 = 25% vs base 22% → lift 1.14 | 0/4 = 0% vs base 8% → lift 0.0 | 0/4 = 0% vs base 15% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 1 | 0/1 = 0% vs base 5% → lift 0.0 | 0/1 = 0% vs base 2% → lift 0.0 | 0/1 = 0% vs base 5% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: broker call | 5 | 1/5 = 20% vs base 22% → lift 0.92 | 0/5 = 0% vs base 7% → lift 0.0 | 2/5 = 40% vs base 15% → lift 2.64 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 19 | 0/19 = 0% vs base 16% → lift 0.0 | 0/19 = 0% vs base 5% → lift 0.0 | 2/19 = 10% vs base 12% → lift 0.86 | 0 (0%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 42 | 10/42 = 24% vs base 24% → lift 1.01 | 6/42 = 14% vs base 10% → lift 1.51 | 5/42 = 12% vs base 18% → lift 0.66 | 1 (2%) | n >= 30 |
| source: price-only | 54 | 8/54 = 15% vs base 13% → lift 1.12 | 4/54 = 7% vs base 4% → lift 1.89 | 8/54 = 15% vs base 10% → lift 1.47 | 1 (2%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-16 from 09:00) - comparison only | 167 | 39/167 = 23% vs base 18% → lift 1.32 | 16/167 = 10% vs base 7% → lift 1.43 | 27/167 = 16% vs base 15% → lift 1.09 | 15 (9%) | n >= 30 |
| OLD system source: broker call | 20 | 3/20 = 15% vs base 18% → lift 0.86 | 0/20 = 0% vs base 7% → lift 0.0 | 3/20 = 15% vs base 15% → lift 0.97 | 2 (10%) | NOT PROVEN (n < 30) |
| OLD system source: filing | 5 | 2/5 = 40% vs base 16% → lift 2.52 | 1/5 = 20% vs base 5% → lift 3.76 | 2/5 = 40% vs base 12% → lift 3.21 | 1 (20%) | NOT PROVEN (n < 30) |
| OLD system source: news | 60 | 16/60 = 27% vs base 18% → lift 1.53 | 7/60 = 12% vs base 7% → lift 1.75 | 5/60 = 8% vs base 15% → lift 0.55 | 5 (8%) | n >= 30 |
| OLD system source: price-only | 28 | 6/28 = 21% vs base 21% → lift 1.01 | 3/28 = 11% vs base 8% → lift 1.33 | 5/28 = 18% vs base 15% → lift 1.18 | 2 (7%) | NOT PROVEN (n < 30) |
| OLD system source: results | 27 | 6/27 = 22% vs base 21% → lift 1.08 | 3/27 = 11% vs base 8% → lift 1.4 | 4/27 = 15% vs base 16% → lift 0.93 | 4 (15%) | NOT PROVEN (n < 30) |
| OLD system source: sector chain / driver link | 23 | 3/23 = 13% vs base 10% → lift 1.29 | 0/23 = 0% vs base 3% → lift 0.0 | 5/23 = 22% vs base 11% → lift 1.93 | 1 (4%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 4 | 3/4 = 75% vs base 26% → lift 2.86 | 2/4 = 50% vs base 10% → lift 5.13 | 3/4 = 75% vs base 19% → lift 3.94 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 36 | 11 | 9 | -11.0 | +1.14% | 30.0% |
| KNOWLEDGE-driven names (any source but price-only) | 16 | 10 | 9 | 1.0 | +1.86% | 45.0% |
| channel: card (MUST SEE / CRITICAL) | 6 | 0 | 0 | -234.0 | +0.60% | 11.0% |
| channel: engine note 0715 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: engine note 1945 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: go now / get ready (any lane) | 36 | 6 | 0 | -11.0 | +1.14% | 30.0% |
| channel: prediction loop (lists, fired movers) | 2 | 0 | 0 | -24.0 | -0.05% | -0.5% |
| source: trader read | 2 | 0 | 0 | -49.5 | +0.96% | 20.0% |
| source: results | 2 | 0 | 0 | -6.0 | +0.74% | 22.0% |
| source: broker call | 2 | 0 | 0 | -18.0 | +1.21% | 34.0% |
| source: news | 1 | 1 | 0 | 0 | +0.10% | 3% |
| source: sector chain / driver link | 9 | 9 | 9 | 1 | +2.53% | 59% |
| source: price-only | 20 | 1 | 0 | -51.5 | +0.76% | 20.5% |
| OLD system (tomorrow.db alerts of 2026-11-16 from 09:00) - comparison only | 43 | 12 | 0 | -1 | +1.44% | 45% |
| OLD system source: broker call | 4 | 3 | 0 | 1.5 | +1.11% | 36.5% |
| OLD system source: filing | 1 | 0 | 0 | -2 | +3.50% | 71% |
| OLD system source: news | 20 | 5 | 0 | -7.0 | +1.66% | 52.0% |
| OLD system source: price-only | 6 | 1 | 0 | -2.5 | +2.87% | 68.0% |
| OLD system source: results | 7 | 2 | 0 | 0 | +1.38% | 26% |
| OLD system source: sector chain / driver link | 2 | 0 | 0 | -147.0 | -0.06% | -0.5% |
| OLD system source: trader read | 3 | 1 | 0 | 0 | +1.00% | 25% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by engine rank): LT PE 10:43, KEI PE 10:12, HCLTECH PE 13:53, MAXHEALTH CE 09:46, POLYCAB PE 10:16 → >=1% 1/5 20% vs 14% lift 1.48 · >=2% 1/5 20% vs 3% lift 6.06 · next close >=2% 3/5 60% vs 10% lift 6.0 (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 9 names a day; top-5 by engine rank: NATIONALUM PE 14:01, LTM PE 13:54, SAIL PE 13:25, TMPV PE 12:55, HINDALCO PE 10:37 → >=1% 1/5 20% vs 4% lift 4.84 · >=2% 0/5 0% vs 1% lift 0.0 (NOT PROVEN (n = 5))
- engine note 0715: 33 names a day; top-5 by score / points: BAJFINANCE PE 09:00, HDFCBANK PE 09:00, SBIN PE 09:00, AXISBANK PE 09:00, ICICIBANK PE 09:00 → >=1% 0/5 0% vs 30% lift 0.0 · >=2% 0/5 0% vs 12% lift 0.0 (NOT PROVEN (n = 5))
- engine note 1945: 33 names a day; top-5 by score / points: BAJFINANCE PE 09:00, HDFCBANK PE 09:00, SBIN PE 09:00, AXISBANK PE 09:00, ICICIBANK PE 09:00 → >=1% 0/5 0% vs 30% lift 0.0 · >=2% 0/5 0% vs 12% lift 0.0 (NOT PROVEN (n = 5))
- go now / get ready (any lane): 108 names a day; top-5 by engine rank: BAJFINANCE PE 10:52, LT PE 10:43, KEI PE 10:12, JSWSTEEL PE 09:23, HCLTECH PE 13:53 → >=1% 0/5 0% vs 13% lift 0.0 · >=2% 0/5 0% vs 4% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 6 names a day; top-5 by list order: PIIND CE 19:45, CUMMINSIND PE 10:41, MANAPPURAM PE 09:18, ABB PE 09:26, COCHINSHIP PE 09:18 → >=1% 0/5 0% vs 21% lift 0.0 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- ALL: 128 names a day; top-5 by engine rank: LT PE 10:43, KEI PE 10:12, HCLTECH PE 13:53, MAXHEALTH CE 09:46, POLYCAB PE 10:16 → >=1% 1/5 20% vs 14% lift 1.48 · >=2% 1/5 20% vs 3% lift 6.06 (NOT PROVEN (n = 5))
- OLD system: 167 names a day; top-5 by list order: NATIONALUM PE 09:16, AXISBANK CE 09:16, PNB CE 09:16, TMPV PE 09:16, ABB PE 09:16 → >=1% 1/5 20% vs 24% lift 0.84 · >=2% 0/5 0% vs 10% lift 0.0 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: none (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 6 names here = 6 in its own EDGE block; 2%+ its way: 0 by 15:10 (theirs) / 0 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-16 (C_replays) (<server>/girdata/review/monday/C_replays/2026-11-16, edge.rows); news calls (C3): <server>/girdata/review/monday/C_replays/2026-11-16/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.


## Coverage of the movers (not the goal)
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
