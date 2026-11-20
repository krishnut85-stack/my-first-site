# TEST OBSERVER scorecard - TEST_E1_1116 (replayed day 2026-11-16)

Made 2026-11-20 16:48:17 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_E1_1116`. Done because: run.json written by the player (the day's end).

## In one line
EDGE TEST_E1_1116 2026-11-16: 201 names (60 knowledge-driven) · 2% to close: all 13/201 = 6% vs base 6% → lift 1.15; knowledge 6/60 = 10% vs base 8% → lift 1.25 · old system 16/167 = 10% vs base 7% → lift 1.42 (167 names) || coverage (not the goal): TEST_E1_1116 2026-11-16: catch cards 1 / 19 / 34 / 0 · cards+WATCH 3 / 44 / 6 / 1 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 29, late 5, missed 3 · rings 15 (09:15-09:45 1) · AI 723 of 723 (100%), $0.881, 359 calls · flags MISSED MOVER 8, NEWS DIRECTION WRONG 17

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-16, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-17 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 201 | 36/201 = 18% vs base 16% → lift 1.12 | 13/201 = 6% vs base 6% → lift 1.15 | 26/201 = 13% vs base 13% → lift 1.03 | 11 (6%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 60 | 12/60 = 20% vs base 20% → lift 0.98 | 6/60 = 10% vs base 8% → lift 1.25 | 9/60 = 15% vs base 16% → lift 0.94 | 4 (7%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 38 | 11/38 = 29% vs base 12% → lift 2.39 | 4/38 = 10% vs base 4% → lift 2.87 | 5/38 = 13% vs base 11% → lift 1.25 | 2 (5%) | n >= 30 |
| channel: engine note 0715 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: engine note 1945 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: go now / get ready (any lane) | 182 | 34/182 = 19% vs base 15% → lift 1.23 | 11/182 = 6% vs base 5% → lift 1.2 | 25/182 = 14% vs base 12% → lift 1.16 | 11 (6%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 6 | 0/6 = 0% vs base 19% → lift 0.0 | 0/6 = 0% vs base 7% → lift 0.0 | 2/6 = 33% vs base 14% → lift 2.33 | 0 (0%) | NOT PROVEN (n < 30) |
| source: trader read | 2 | 1/2 = 50% vs base 23% → lift 2.16 | 0/2 = 0% vs base 6% → lift 0.0 | 2/2 = 100% vs base 16% → lift 6.32 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 0 | - | - | - | - | none named |
| source: results | 2 | 0/2 = 0% vs base 18% → lift 0.0 | 0/2 = 0% vs base 6% → lift 0.0 | 0/2 = 0% vs base 14% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 3 | 0/3 = 0% vs base 8% → lift 0.0 | 0/3 = 0% vs base 3% → lift 0.0 | 0/3 = 0% vs base 7% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: broker call | 3 | 0/3 = 0% vs base 13% → lift 0.0 | 0/3 = 0% vs base 5% → lift 0.0 | 0/3 = 0% vs base 11% → lift 0.0 | 1 (33%) | NOT PROVEN (n < 30) |
| source: news | 13 | 1/13 = 8% vs base 13% → lift 0.61 | 0/13 = 0% vs base 4% → lift 0.0 | 2/13 = 15% vs base 11% → lift 1.44 | 2 (15%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 37 | 10/37 = 27% vs base 25% → lift 1.1 | 6/37 = 16% vs base 10% → lift 1.59 | 5/37 = 14% vs base 19% → lift 0.71 | 1 (3%) | n >= 30 |
| source: price-only | 141 | 24/141 = 17% vs base 14% → lift 1.21 | 7/141 = 5% vs base 5% → lift 1.08 | 17/141 = 12% vs base 11% → lift 1.08 | 7 (5%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-16 from the evening before 15:30) - comparison only | 167 | 39/167 = 23% vs base 18% → lift 1.31 | 16/167 = 10% vs base 7% → lift 1.42 | 27/167 = 16% vs base 15% → lift 1.1 | 15 (9%) | n >= 30 |
| OLD system source: broker call | 20 | 3/20 = 15% vs base 18% → lift 0.86 | 0/20 = 0% vs base 7% → lift 0.0 | 3/20 = 15% vs base 15% → lift 0.97 | 2 (10%) | NOT PROVEN (n < 30) |
| OLD system source: filing | 5 | 2/5 = 40% vs base 16% → lift 2.53 | 1/5 = 20% vs base 5% → lift 3.69 | 2/5 = 40% vs base 12% → lift 3.41 | 1 (20%) | NOT PROVEN (n < 30) |
| OLD system source: news | 60 | 16/60 = 27% vs base 18% → lift 1.5 | 7/60 = 12% vs base 7% → lift 1.73 | 5/60 = 8% vs base 15% → lift 0.55 | 5 (8%) | n >= 30 |
| OLD system source: price-only | 28 | 6/28 = 21% vs base 21% → lift 1.0 | 3/28 = 11% vs base 8% → lift 1.32 | 5/28 = 18% vs base 15% → lift 1.18 | 2 (7%) | NOT PROVEN (n < 30) |
| OLD system source: results | 27 | 6/27 = 22% vs base 21% → lift 1.08 | 3/27 = 11% vs base 8% → lift 1.37 | 4/27 = 15% vs base 16% → lift 0.94 | 4 (15%) | NOT PROVEN (n < 30) |
| OLD system source: sector chain / driver link | 23 | 3/23 = 13% vs base 10% → lift 1.28 | 0/23 = 0% vs base 3% → lift 0.0 | 5/23 = 22% vs base 11% → lift 1.93 | 1 (4%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 4 | 3/4 = 75% vs base 26% → lift 2.86 | 2/4 = 50% vs base 10% → lift 5.07 | 3/4 = 75% vs base 19% → lift 3.94 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 47 | 10 | 9 | -17 | +1.24% | 34% |
| KNOWLEDGE-driven names (any source but price-only) | 13 | 9 | 9 | 1 | +1.92% | 51% |
| channel: card (MUST SEE / CRITICAL) | 20 | 1 | 0 | -68.0 | +0.89% | 17.0% |
| channel: engine note 0715 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: engine note 1945 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: go now / get ready (any lane) | 47 | 4 | 0 | -17 | +1.24% | 34% |
| channel: prediction loop (lists, fired movers) | 2 | 0 | 0 | -24.0 | -0.05% | -0.5% |
| source: trader read | 2 | 0 | 0 | -51.0 | +1.16% | 17.0% |
| source: results | 1 | 0 | 0 | -2 | -0.32% | -3% |
| source: sector chain / driver link | 10 | 9 | 9 | 1.0 | +2.40% | 55.5% |
| source: price-only | 34 | 1 | 0 | -30.0 | +1.15% | 33.5% |
| OLD system (tomorrow.db alerts of 2026-11-16 from the evening before 15:30) - comparison only | 43 | 12 | 0 | -1 | +1.44% | 45% |
| OLD system source: broker call | 4 | 3 | 0 | 1.5 | +1.11% | 36.5% |
| OLD system source: filing | 1 | 0 | 0 | -2 | +3.50% | 71% |
| OLD system source: news | 20 | 5 | 0 | -7.0 | +1.66% | 52.0% |
| OLD system source: price-only | 6 | 1 | 0 | -2.5 | +2.87% | 68.0% |
| OLD system source: results | 7 | 2 | 0 | 0 | +1.38% | 26% |
| OLD system source: sector chain / driver link | 2 | 0 | 0 | -147.0 | -0.06% | -0.5% |
| OLD system source: trader read | 3 | 1 | 0 | 0 | +1.00% | 25% |

### Names a day and the TOP-5

- card (MUST SEE / CRITICAL): 38 names; top-5 by AI priority: SBIN CE 09:30, ASIANPAINT CE 09:17, PREMIERENE PE 10:32, KARURVYSYA CE 09:19, MAXHEALTH CE 09:45 → 3 of 5 moved 1%+ its way, 2 moved 2%+ (NOT PROVEN (n = 5))
- engine note 0715: 33 names; top-5 by score / points: BAJFINANCE PE 07:15, HDFCBANK PE 07:15, SBIN PE 07:15, AXISBANK PE 07:15, ICICIBANK PE 07:15 → 0 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- engine note 1945: 33 names; top-5 by score / points: BAJFINANCE PE 19:45, HDFCBANK PE 19:45, SBIN PE 19:45, AXISBANK PE 19:45, ICICIBANK PE 19:45 → 0 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- go now / get ready (any lane): 182 names; top-5 by AI priority: SBIN CE 09:30, ASIANPAINT CE 09:17, KARURVYSYA CE 09:19, BHARTIARTL CE 09:33, EICHERMOT CE 09:18 → 1 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 6 names; top-5 by list order: PIIND CE 19:45, CUMMINSIND PE 10:41, MANAPPURAM PE 09:18, ABB PE 09:26, COCHINSHIP PE 09:18 → 0 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- ALL: 201 names; top-5 by AI priority: SBIN CE 09:30, ASIANPAINT CE 09:17, KARURVYSYA CE 09:19, BHARTIARTL CE 09:33, EICHERMOT CE 09:18 → 1 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- OLD system: 167 names; top-5 by list order: NATIONALUM PE 09:16, AXISBANK CE 09:16, PNB CE 09:16, TMPV PE 09:16, ABB PE 09:16 → 1 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))

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
| v2 cards (MUST SEE + CRITICAL) | 1 | 19 | 34 | 0 |
| v2 cards + WATCH | 3 | 44 | 6 | 1 |
| old system | 22 | 21 | 10 | 1 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 37 crossed 3%; in time 29, late 5, missed 3.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| TMPV | 09:16 DOWN | -8.7 | LATE 10:10 | BEFORE | first 10:10 PE GET READY MUST SEE (AI) · best 10:10 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 10:50 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| AMBER | 09:16 DOWN | -7.68 | LATE 09:17 | BEFORE | first 09:17 PE GET READY WATCH (AI) · best 14:21 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 14:21 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| INOXWIND | 09:16 DOWN | -7.68 | LATE 09:18 | BEFORE | first 09:18 PE GET READY LOG (AI) · best 11:24 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 13:31 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| PATANJALI | 12:08 DOWN | -4.82 | MISSED | LATE | nothing on this share |
| TATACONSUM | 12:26 UP | 3.57 | MISSED | BEFORE | nothing on this share |
| ITC | 10:16 UP | 3.54 | LATE 10:17 | LATE | first 10:17 CE GET READY MUST SEE (AI) · best 10:17 CE GET READY MUST SEE (AI) · last 14:30 CE nothing MUST SEE (rules): cancelled: the GET READY call from 14:20 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| KALYANKJIL | 09:20 UP | 1.6 | MISSED | not a 2% mover at the close | nothing on this share |
| EICHERMOT | 09:16 UP | -0.67 | LATE 09:18 | not a 2% mover at the close | first 09:18 CE GET READY MUST SEE (AI) · best 09:18 CE GET READY MUST SEE (AI) · last 09:20 CE nothing MUST SEE (rules): cancelled: the GET READY call from 09:18 no longer holds (price left the trigger zone, the sector faded, or the score f… |

## Rings (phone alarms)
15 rings; 1 of them 09:15-09:45. By hour: 09 h 2, 10 h 3, 11 h 4, 12 h 2, 13 h 3, 14 h 1.

## The AI
AI state: ON. AI decided 723 of 723 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 496 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (456 rows)
- by design: the idea left MUST SEE (by design) (3 rows)
- by design: rule veto: (d) its sector consumer services is falling (-0.21%) - no CE against the sector  (3 rows)
- by design: rule veto: (d) its sector nbfc & finance is falling (-0.25%) - no CE against the sector unl (2 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (17.61 vs VWAP 1 (2 rows)
- by design: rule veto: (d) its sector pharma is falling (-0.26%) - no CE against the sector unless DIVE (2 rows)
- by design: rule veto: (g) short covering before 09:30 - the SC CE window is 09:30-11:00 (1 rows)
- by design: rule veto: (d) its sector chemicals is falling (-0.29%) - no CE against the sector unless D (1 rows)

359 AI calls, $0.881 in all; the dearest single call $0.0291; 0 errors; stop reasons {'end_turn': 359}.
Cost by kind: final $0.6734, rank $0.0021, second $0.0019, triage $0.2039. Cost by model: routine-tier model $0.2079, final-tier model $0.6734.
Latency: p50 4172 ms, p95 9686 ms, max 15376 ms over 359 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 201, wrong 178, flat 182, not known 0; average move the call's way 0.05%
- after 60 min: right 219, wrong 198, flat 144, not known 0; average move the call's way 0.07%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 7, late 154, the wrong way 4, share did not move 2% 396 (of 561 new GO NOW / GET READY decisions, 49 of them cards)

## Flags
MISSED MOVER: 8, NEWS DIRECTION WRONG: 17
- 09:16 MISSED MOVER: AMBER crossed -3.0% at 09:16 (-3.19% vs the previous close) with no PE call by then · the engine said nothing on AMBER by then
- 09:16 MISSED MOVER: EICHERMOT crossed +3.0% at 09:16 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on EICHERMOT by then
- 09:16 MISSED MOVER: INOXWIND crossed -3.0% at 09:16 (-8.15% vs the previous close) with no PE call by then · the engine said nothing on INOXWIND by then
- 09:16 MISSED MOVER: TMPV crossed -3.0% at 09:16 (-7.85% vs the previous close) with no PE call by then · the engine said nothing on TMPV by then
- 09:20 MISSED MOVER: KALYANKJIL crossed +3.0% at 09:20 (+3.13% vs the previous close) with no CE call by then · the engine said nothing on KALYANKJIL by then
- 09:48 NEWS DIRECTION WRONG: EICHERMOT CE GET READY at 09:18 was news-driven; the share went -1.89% against it in 30 min (worst -2.32%)
- 09:49 NEWS DIRECTION WRONG: MOTILALOFS CE GET READY at 09:19 was news-driven; the share went -0.65% against it in 30 min (worst -1.03%)
- 10:09 NEWS DIRECTION WRONG: DIVISLAB CE GET READY at 09:39 was news-driven; the share went -1.30% against it in 30 min (worst -1.30%)
- 10:16 MISSED MOVER: ITC crossed +3.0% at 10:16 (+3.00% vs the previous close) with no CE call by then · the engine said: first 10:17 CE GET READY MUST SEE (AI); best 10:17 CE GET READY MUST SEE (AI); last 10:17 CE GET READY MUST SEE (AI): First VWAP pullback in a share above VWAP with fresh long build-up agreeing on C…
- 10:22 NEWS DIRECTION WRONG: YESBANK CE GO NOW at 09:52 was news-driven; the share went -0.62% against it in 30 min (worst -0.73%)
- 10:39 NEWS DIRECTION WRONG: AUROPHARMA CE GO NOW at 09:39 was news-driven; the share went -0.60% against it in 60 min (worst -0.65%)
- 10:39 NEWS DIRECTION WRONG: BIOCON CE GET READY at 09:39 was news-driven; the share went -0.57% against it in 60 min (worst -0.64%)
- 10:47 NEWS DIRECTION WRONG: BPCL CE GET READY at 10:17 was news-driven; the share went -0.57% against it in 30 min (worst -0.57%)
- 10:49 NEWS DIRECTION WRONG: SONACOMS CE GET READY at 09:49 was news-driven; the share went -1.47% against it in 60 min (worst -1.62%)
- 10:51 NEWS DIRECTION WRONG: SBIN CE GET READY at 09:51 was news-driven; the share went -0.62% against it in 60 min (worst -0.83%)
- 10:53 NEWS DIRECTION WRONG: HINDPETRO CE GET READY at 10:23 was news-driven; the share went -0.57% against it in 30 min (worst -0.57%)
- 11:13 NEWS DIRECTION WRONG: KAYNES PE GET READY at 10:13 was news-driven; the share went -1.30% against it in 60 min (worst -1.72%)
- 11:44 NEWS DIRECTION WRONG: DIVISLAB PE GET READY at 11:14 was news-driven; the share went -0.52% against it in 30 min (worst -0.73%)
- 11:49 NEWS DIRECTION WRONG: LAURUSLABS PE GET READY at 11:19 was news-driven; the share went -0.87% against it in 30 min (worst -1.09%)
- 11:54 NEWS DIRECTION WRONG: INOXWIND PE GET READY at 11:24 was news-driven; the share went -1.61% against it in 30 min (worst -1.63%)
- 12:08 MISSED MOVER: PATANJALI crossed -3.0% at 12:08 (-3.11% vs the previous close) with no PE call by then · the engine said nothing on PATANJALI by then
- 12:26 MISSED MOVER: TATACONSUM crossed +3.0% at 12:26 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on TATACONSUM by then
- 13:21 NEWS DIRECTION WRONG: COFORGE PE GET READY at 12:51 was news-driven; the share went -0.51% against it in 30 min (worst -0.92%)
- 13:51 NEWS DIRECTION WRONG: VBL CE GET READY at 12:51 was news-driven; the share went -0.80% against it in 60 min (worst -0.80%)
- 14:31 NEWS DIRECTION WRONG: INOXWIND PE GET READY at 13:31 was news-driven; the share went -0.51% against it in 60 min (worst -0.64%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
