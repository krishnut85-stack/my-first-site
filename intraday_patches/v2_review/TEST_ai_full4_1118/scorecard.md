# TEST OBSERVER scorecard - TEST_ai_full4_1118 (replayed day 2026-11-18)

Made 2026-11-19 22:25:52 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full4_1118`. Done because: run.json written by the player (the day's end).

## In one line
EDGE TEST_ai_full4_1118 2026-11-18: 216 names a day (116 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 0/5 0% vs 16% lift 0.0, >=2% 0/5 0% vs 5% lift 0.0 · all names >=1% 49/216 23% vs 27% lift 0.85, >=2% 15/216 7% vs 8% lift 0.88 · knowledge >=2% 9/116 8% vs 8% lift 0.95 · all names >=2% to the next close 33/216 15% vs 12% lift 1.32 · old system >=2% 21/293 7% vs 8% lift 0.88 (293 names) || coverage (not the goal): TEST_ai_full4_1118 2026-11-18: catch cards 0 / 28 / 25 / 0 · cards+WATCH 13 / 34 / 5 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 25, late 1, missed 4 · rings 19 (09:15-09:45 1) · AI 1629 of 1629 (100%), $0.537, 338 calls · flags MISSED MOVER 5, COST SPIKE 1, NEWS DIRECTION WRONG 26

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-18, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-19 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 216 | 49/216 = 23% vs base 27% → lift 0.85 | 15/216 = 7% vs base 8% → lift 0.88 | 33/216 = 15% vs base 12% → lift 1.32 | 14 (6%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 116 | 29/116 = 25% vs base 28% → lift 0.9 | 9/116 = 8% vs base 8% → lift 0.95 | 31/116 = 27% vs base 14% → lift 1.91 | 9 (8%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 58 | 16/58 = 28% vs base 17% → lift 1.65 | 3/58 = 5% vs base 4% → lift 1.46 | 3/58 = 5% vs base 6% → lift 0.83 | 2 (3%) | n >= 30 |
| channel: engine note 0715 | 37 | 9/37 = 24% vs base 24% → lift 1.03 | 3/37 = 8% vs base 7% → lift 1.14 | 15/37 = 40% vs base 17% → lift 2.33 | 7 (19%) | n >= 30 |
| channel: engine note 1945 | 56 | 14/56 = 25% vs base 28% → lift 0.91 | 5/56 = 9% vs base 8% → lift 1.07 | 22/56 = 39% vs base 16% → lift 2.42 | 5 (9%) | n >= 30 |
| channel: go now / get ready (any lane) | 174 | 45/174 = 26% vs base 28% → lift 0.94 | 13/174 = 8% vs base 8% → lift 0.92 | 19/174 = 11% vs base 10% → lift 1.14 | 5 (3%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 9 | 2/9 = 22% vs base 24% → lift 0.91 | 2/9 = 22% vs base 8% → lift 2.76 | 1/9 = 11% vs base 16% → lift 0.71 | 4 (44%) | NOT PROVEN (n < 30) |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 110 | 28/110 = 26% vs base 29% → lift 0.88 | 9/110 = 8% vs base 8% → lift 0.96 | 26/110 = 24% vs base 14% → lift 1.74 | 8 (7%) | n >= 30 |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 31 | 8/31 = 26% vs base 27% → lift 0.96 | 3/31 = 10% vs base 8% → lift 1.2 | 10/31 = 32% vs base 16% → lift 1.96 | 6 (19%) | n >= 30 |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 51 | 13/51 = 26% vs base 30% → lift 0.86 | 5/51 = 10% vs base 9% → lift 1.1 | 17/51 = 33% vs base 16% → lift 2.12 | 5 (10%) | n >= 30 |
| source: trader read | 2 | 2/2 = 100% vs base 42% → lift 2.36 | 1/2 = 50% vs base 13% → lift 3.82 | 1/2 = 50% vs base 13% → lift 3.96 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 1 | 0/1 = 0% vs base 5% → lift 0.0 | 0/1 = 0% vs base 0% → lift 0.0 | 1/1 = 100% vs base 23% → lift 4.27 | 0 (0%) | NOT PROVEN (n < 30) |
| source: results | 1 | 1/1 = 100% vs base 43% → lift 2.32 | 0/1 = 0% vs base 13% → lift 0.0 | 0/1 = 0% vs base 12% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 0 | - | - | - | - | none named |
| source: broker call | 14 | 1/14 = 7% vs base 28% → lift 0.25 | 0/14 = 0% vs base 9% → lift 0.0 | 2/14 = 14% vs base 12% → lift 1.14 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 21 | 10/21 = 48% vs base 23% → lift 2.06 | 4/21 = 19% vs base 6% → lift 3.02 | 5/21 = 24% vs base 10% → lift 2.41 | 1 (5%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 77 | 15/77 = 20% vs base 29% → lift 0.68 | 4/77 = 5% vs base 9% → lift 0.61 | 22/77 = 29% vs base 15% → lift 1.86 | 8 (10%) | n >= 30 |
| source: price-only | 100 | 20/100 = 20% vs base 26% → lift 0.78 | 6/100 = 6% vs base 8% → lift 0.79 | 2/100 = 2% vs base 9% → lift 0.23 | 5 (5%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 293 | 76/293 = 26% vs base 27% → lift 0.95 | 21/293 = 7% vs base 8% → lift 0.88 | 37/293 = 13% vs base 14% → lift 0.87 | 14 (5%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 23% → lift 1.43 | 1/3 = 33% vs base 7% → lift 4.95 | 1/3 = 33% vs base 14% → lift 2.45 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 34 | 7/34 = 21% vs base 24% → lift 0.86 | 2/34 = 6% vs base 7% → lift 0.82 | 7/34 = 21% vs base 15% → lift 1.41 | 3 (9%) | n >= 30 |
| OLD system source: filing | 30 | 11/30 = 37% vs base 32% → lift 1.14 | 2/30 = 7% vs base 10% → lift 0.68 | 2/30 = 7% vs base 15% → lift 0.45 | 2 (7%) | n >= 30 |
| OLD system source: news | 92 | 20/92 = 22% vs base 24% → lift 0.89 | 4/92 = 4% vs base 7% → lift 0.59 | 13/92 = 14% vs base 16% → lift 0.91 | 5 (5%) | n >= 30 |
| OLD system source: price-only | 9 | 1/9 = 11% vs base 23% → lift 0.49 | 0/9 = 0% vs base 7% → lift 0.0 | 1/9 = 11% vs base 15% → lift 0.74 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 112 | 30/112 = 27% vs base 30% → lift 0.89 | 10/112 = 9% vs base 9% → lift 0.99 | 9/112 = 8% vs base 14% → lift 0.59 | 4 (4%) | n >= 30 |
| OLD system source: sector chain / driver link | 10 | 3/10 = 30% vs base 15% → lift 1.99 | 0/10 = 0% vs base 4% → lift 0.0 | 2/10 = 20% vs base 14% → lift 1.44 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 3 | 3/3 = 100% vs base 42% → lift 2.36 | 2/3 = 67% vs base 13% → lift 5.13 | 2/3 = 67% vs base 12% → lift 5.81 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 48 | 19 | 12 | -4.0 | +1.71% | 50.5% |
| KNOWLEDGE-driven names (any source but price-only) | 26 | 15 | 10 | 1.0 | +1.87% | 50.5% |
| channel: card (MUST SEE / CRITICAL) | 28 | 0 | 0 | -129.0 | +1.25% | 33.0% |
| channel: engine note 0715 | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 | 11 | 11 | 11 | 1 | +1.92% | 56% |
| channel: go now / get ready (any lane) | 47 | 18 | 2 | -4 | +1.73% | 50% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -4.5 | +3.40% | 76.0% |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 26 | 15 | 10 | 1.0 | +1.87% | 50.5% |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 11 | 11 | 11 | 1 | +1.92% | 56% |
| source: trader read | 2 | 1 | 0 | -2.0 | +2.83% | 53.0% |
| source: filing | 1 | 0 | 0 | -125 | -0.62% | -16% |
| source: broker call | 2 | 1 | 0 | 0.0 | +1.16% | 41.0% |
| source: news | 9 | 1 | 0 | -80 | +1.99% | 46% |
| source: sector chain / driver link | 12 | 12 | 10 | 1.5 | +1.90% | 55.0% |
| source: price-only | 22 | 4 | 2 | -9.0 | +1.37% | 50.5% |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 53 | 33 | 3 | 1 | +1.84% | 62% |
| OLD system source: TV | 1 | 0 | 0 | -20 | +5.44% | 70% |
| OLD system source: broker call | 6 | 4 | 0 | 1.5 | +1.66% | 63.0% |
| OLD system source: filing | 9 | 6 | 1 | 2 | +1.65% | 54% |
| OLD system source: news | 12 | 5 | 0 | -1.0 | +1.91% | 64.0% |
| OLD system source: results | 20 | 15 | 0 | 1.0 | +2.02% | 64.5% |
| OLD system source: sector chain / driver link | 2 | 1 | 1 | -5.5 | +1.54% | 47.0% |
| OLD system source: trader read | 3 | 2 | 1 | 1 | +3.90% | 68% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by engine rank): NMDC PE 09:26, CDSL CE 09:24, BIOCON CE 10:18, BSE CE 09:30, HINDPETRO PE 10:34 → >=1% 0/5 0% vs 16% lift 0.0 · >=2% 0/5 0% vs 5% lift 0.0 · next close >=2% 0/5 0% vs 17% lift 0.0 (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 58 names a day; top-5 by engine rank: BAJAJ-AUTO PE 10:39, HINDZINC PE 12:03, SAIL PE 11:05, HINDALCO PE 11:45, VEDL PE 11:47 → >=1% 3/5 60% vs 14% lift 4.17 · >=2% 0/5 0% vs 2% lift 0.0 (NOT PROVEN (n = 5))
- engine note 0715: 37 names a day; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, VEDL PE 09:00, AMBER CE 09:00 → >=1% 4/5 80% vs 36% lift 2.23 · >=2% 1/5 20% vs 11% lift 1.86 (NOT PROVEN (n = 5))
- engine note 1945: 56 names a day; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, JINDALSTEL PE 09:00, JSWSTEEL PE 09:00 → >=1% 4/5 80% vs 43% lift 1.86 · >=2% 0/5 0% vs 13% lift 0.0 (NOT PROVEN (n = 5))
- go now / get ready (any lane): 174 names a day; top-5 by engine rank: NMDC PE 09:26, CDSL CE 09:24, BIOCON CE 10:18, BSE CE 09:30, HINDPETRO PE 10:34 → >=1% 0/5 0% vs 16% lift 0.0 · >=2% 0/5 0% vs 5% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 9 names a day; top-5 by list order: TMPV CE 19:45, DIXON PE 19:45, PIIND CE 19:45, ASHOKLEY PE 09:19, KALYANKJIL PE 09:26 → >=1% 2/5 40% vs 26% lift 1.51 · >=2% 2/5 40% vs 8% lift 4.74 (NOT PROVEN (n = 5))
- ALL: 216 names a day; top-5 by engine rank: NMDC PE 09:26, CDSL CE 09:24, BIOCON CE 10:18, BSE CE 09:30, HINDPETRO PE 10:34 → >=1% 0/5 0% vs 16% lift 0.0 · >=2% 0/5 0% vs 5% lift 0.0 (NOT PROVEN (n = 5))
- OLD system: 293 names a day; top-5 by list order: MCX PE 09:01, ONGC PE 09:08, MANAPPURAM PE 09:08, HINDZINC PE 09:08, ADANIENSOL CE 09:15 → >=1% 3/5 60% vs 36% lift 1.67 · >=2% 1/5 20% vs 11% lift 1.86 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: AMBER CE, BLUESTARCO CE, CROMPTON CE, DIXON CE, PGEL CE, VOLTAS CE (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 9 names here = 9 in its own EDGE block; 2%+ its way: 2 by 15:10 (theirs) / 2 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-18 (C_replays) (<server>/girdata/review/monday/C_replays/2026-11-18, edge.rows); news calls (C3): <server>/girdata/review/monday/C_replays/2026-11-18/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.


## Coverage of the movers (not the goal)
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
