# TEST OBSERVER scorecard - TEST_E1_1118 (replayed day 2026-11-18)

Made 2026-11-20 17:54:37 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_E1_1118`. Done because: scored once on demand (observer.py --once).

## In one line
EDGE TEST_E1_1118 2026-11-18: 239 names a day (94 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 1/5 20% vs 18% lift 1.13, >=2% 0/5 0% vs 6% lift 0.0 · all names >=1% 55/239 23% vs 27% lift 0.86, >=2% 18/239 8% vs 8% lift 0.93 · knowledge >=2% 7/94 7% vs 8% lift 0.96 · all names >=2% to the next close 35/239 15% vs 12% lift 1.21 · old system >=2% 21/293 7% vs 8% lift 0.88 (293 names) || coverage (not the goal): TEST_E1_1118 2026-11-18: catch cards 1 / 8 / 44 / 0 · cards+WATCH 10 / 38 / 4 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 25, late 1, missed 4 · rings 11 (09:15-09:45 0) · AI 881 of 881 (100%), $0.527, 319 calls · flags MISSED MOVER 5, NEWS DIRECTION WRONG 15

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-18, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-19 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 239 | 55/239 = 23% vs base 27% → lift 0.86 | 18/239 = 8% vs base 8% → lift 0.93 | 35/239 = 15% vs base 12% → lift 1.21 | 17 (7%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 94 | 24/94 = 26% vs base 26% → lift 0.97 | 7/94 = 7% vs base 8% → lift 0.96 | 30/94 = 32% vs base 15% → lift 2.11 | 7 (7%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 30 | 7/30 = 23% vs base 21% → lift 1.11 | 2/30 = 7% vs base 6% → lift 1.13 | 1/30 = 3% vs base 8% → lift 0.44 | 1 (3%) | n >= 30 |
| channel: engine note 0715 | 37 | 9/37 = 24% vs base 24% → lift 1.03 | 3/37 = 8% vs base 7% → lift 1.14 | 15/37 = 40% vs base 17% → lift 2.33 | 7 (19%) | n >= 30 |
| channel: engine note 1945 | 56 | 14/56 = 25% vs base 28% → lift 0.91 | 5/56 = 9% vs base 8% → lift 1.07 | 22/56 = 39% vs base 16% → lift 2.42 | 5 (9%) | n >= 30 |
| channel: go now / get ready (any lane) | 196 | 51/196 = 26% vs base 27% → lift 0.95 | 17/196 = 9% vs base 8% → lift 1.04 | 20/196 = 10% vs base 10% → lift 0.98 | 8 (4%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 9 | 2/9 = 22% vs base 24% → lift 0.91 | 2/9 = 22% vs base 8% → lift 2.76 | 1/9 = 11% vs base 16% → lift 0.71 | 4 (44%) | NOT PROVEN (n < 30) |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 88 | 23/88 = 26% vs base 28% → lift 0.95 | 7/88 = 8% vs base 8% → lift 0.98 | 25/88 = 28% vs base 15% → lift 1.94 | 6 (7%) | n >= 30 |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 31 | 8/31 = 26% vs base 27% → lift 0.96 | 3/31 = 10% vs base 8% → lift 1.2 | 10/31 = 32% vs base 16% → lift 1.96 | 6 (19%) | n >= 30 |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 51 | 13/51 = 26% vs base 30% → lift 0.86 | 5/51 = 10% vs base 9% → lift 1.1 | 17/51 = 33% vs base 16% → lift 2.12 | 5 (10%) | n >= 30 |
| source: trader read | 2 | 2/2 = 100% vs base 42% → lift 2.36 | 1/2 = 50% vs base 13% → lift 3.82 | 1/2 = 50% vs base 13% → lift 3.96 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 1 | 0/1 = 0% vs base 5% → lift 0.0 | 0/1 = 0% vs base 0% → lift 0.0 | 1/1 = 100% vs base 23% → lift 4.27 | 0 (0%) | NOT PROVEN (n < 30) |
| source: results | 1 | 1/1 = 100% vs base 43% → lift 2.32 | 0/1 = 0% vs base 13% → lift 0.0 | 0/1 = 0% vs base 12% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 0 | - | - | - | - | none named |
| source: broker call | 2 | 0/2 = 0% vs base 7% → lift 0.0 | 0/2 = 0% vs base 1% → lift 0.0 | 1/2 = 50% vs base 24% → lift 2.08 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 16 | 8/16 = 50% vs base 21% → lift 2.38 | 2/16 = 12% vs base 6% → lift 2.2 | 5/16 = 31% vs base 9% → lift 3.48 | 0 (0%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 72 | 13/72 = 18% vs base 28% → lift 0.66 | 4/72 = 6% vs base 8% → lift 0.67 | 22/72 = 31% vs base 16% → lift 1.88 | 7 (10%) | n >= 30 |
| source: price-only | 145 | 31/145 = 21% vs base 27% → lift 0.79 | 11/145 = 8% vs base 8% → lift 0.92 | 5/145 = 3% vs base 10% → lift 0.34 | 10 (7%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 293 | 76/293 = 26% vs base 27% → lift 0.96 | 21/293 = 7% vs base 8% → lift 0.88 | 37/293 = 13% vs base 14% → lift 0.87 | 14 (5%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 23% → lift 1.43 | 1/3 = 33% vs base 7% → lift 4.95 | 1/3 = 33% vs base 14% → lift 2.45 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 34 | 7/34 = 21% vs base 24% → lift 0.86 | 2/34 = 6% vs base 7% → lift 0.82 | 7/34 = 21% vs base 15% → lift 1.41 | 3 (9%) | n >= 30 |
| OLD system source: filing | 30 | 11/30 = 37% vs base 32% → lift 1.14 | 2/30 = 7% vs base 10% → lift 0.68 | 2/30 = 7% vs base 15% → lift 0.45 | 2 (7%) | n >= 30 |
| OLD system source: news | 92 | 20/92 = 22% vs base 24% → lift 0.89 | 4/92 = 4% vs base 7% → lift 0.59 | 13/92 = 14% vs base 16% → lift 0.91 | 5 (5%) | n >= 30 |
| OLD system source: price-only | 9 | 1/9 = 11% vs base 23% → lift 0.49 | 0/9 = 0% vs base 7% → lift 0.0 | 1/9 = 11% vs base 15% → lift 0.74 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 112 | 30/112 = 27% vs base 30% → lift 0.89 | 10/112 = 9% vs base 9% → lift 0.99 | 9/112 = 8% vs base 14% → lift 0.59 | 4 (4%) | n >= 30 |
| OLD system source: sector chain / driver link | 10 | 3/10 = 30% vs base 15% → lift 1.99 | 0/10 = 0% vs base 4% → lift 0.0 | 2/10 = 20% vs base 14% → lift 1.43 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 3 | 3/3 = 100% vs base 42% → lift 2.36 | 2/3 = 67% vs base 13% → lift 5.13 | 2/3 = 67% vs base 12% → lift 5.81 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 50 | 19 | 11 | -4.5 | +1.80% | 54.0% |
| KNOWLEDGE-driven names (any source but price-only) | 21 | 12 | 10 | 0 | +1.87% | 46% |
| channel: card (MUST SEE / CRITICAL) | 9 | 1 | 0 | -12 | +1.02% | 47% |
| channel: engine note 0715 | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 | 11 | 11 | 11 | 1 | +1.92% | 56% |
| channel: go now / get ready (any lane) | 49 | 14 | 0 | -5 | +1.75% | 53% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -4.5 | +3.40% | 76.0% |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 21 | 12 | 10 | 0 | +1.87% | 46% |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 11 | 11 | 11 | 1 | +1.92% | 56% |
| source: trader read | 2 | 1 | 0 | -2.0 | +2.83% | 53.0% |
| source: filing | 1 | 0 | 0 | -125 | -0.62% | -16% |
| source: broker call | 1 | 1 | 0 | 0 | +0.83% | 29% |
| source: news | 6 | 0 | 0 | -85.5 | +1.98% | 43.5% |
| source: sector chain / driver link | 11 | 10 | 10 | 1 | +1.87% | 54% |
| source: price-only | 29 | 7 | 1 | -7 | +1.66% | 58% |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 53 | 33 | 3 | 1 | +1.84% | 62% |
| OLD system source: TV | 1 | 0 | 0 | -20 | +5.44% | 70% |
| OLD system source: broker call | 6 | 4 | 0 | 1.5 | +1.66% | 63.0% |
| OLD system source: filing | 9 | 6 | 1 | 2 | +1.65% | 54% |
| OLD system source: news | 12 | 5 | 0 | -1.0 | +1.91% | 64.0% |
| OLD system source: results | 20 | 15 | 0 | 1.0 | +2.02% | 64.5% |
| OLD system source: sector chain / driver link | 2 | 1 | 1 | -5.5 | +1.54% | 47.0% |
| OLD system source: trader read | 3 | 2 | 1 | 1 | +3.90% | 68% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by AI priority): MAZDOCK PE 09:28, DMART PE 09:19, BIOCON CE 10:18, IEX CE 09:23, BSE CE 09:31 → >=1% 1/5 20% vs 18% lift 1.13 · >=2% 0/5 0% vs 6% lift 0.0 · next close >=2% 0/5 0% vs 17% lift 0.0 (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 30 names a day; top-5 by AI priority: JUBLFOOD PE 10:00, ASTRAL PE 09:30, INOXWIND PE 09:35, BAJAJ-AUTO PE 12:18, BAJFINANCE PE 11:07 → >=1% 1/5 20% vs 23% lift 0.88 · >=2% 0/5 0% vs 6% lift 0.0 (NOT PROVEN (n = 5))
- engine note 0715: 37 names a day; top-5 by score / points: HINDZINC PE 07:15, NATIONALUM PE 07:15, HINDALCO PE 07:15, VEDL PE 07:15, AMBER CE 07:15 → >=1% 4/5 80% vs 36% lift 2.23 · >=2% 1/5 20% vs 11% lift 1.86 (NOT PROVEN (n = 5))
- engine note 1945: 56 names a day; top-5 by score / points: HINDZINC PE 19:45, NATIONALUM PE 19:45, HINDALCO PE 19:45, JINDALSTEL PE 19:45, JSWSTEEL PE 19:45 → >=1% 4/5 80% vs 43% lift 1.86 · >=2% 0/5 0% vs 13% lift 0.0 (NOT PROVEN (n = 5))
- go now / get ready (any lane): 196 names a day; top-5 by AI priority: MAZDOCK PE 09:28, DMART PE 09:19, BIOCON CE 10:18, IEX CE 09:23, BSE CE 09:31 → >=1% 1/5 20% vs 18% lift 1.13 · >=2% 0/5 0% vs 6% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 9 names a day; top-5 by list order: TMPV CE 19:45, DIXON PE 19:45, PIIND CE 19:45, ASHOKLEY PE 09:19, KALYANKJIL PE 09:26 → >=1% 2/5 40% vs 26% lift 1.51 · >=2% 2/5 40% vs 8% lift 4.74 (NOT PROVEN (n = 5))
- ALL: 239 names a day; top-5 by AI priority: MAZDOCK PE 09:28, DMART PE 09:19, BIOCON CE 10:18, IEX CE 09:23, BSE CE 09:31 → >=1% 1/5 20% vs 18% lift 1.13 · >=2% 0/5 0% vs 6% lift 0.0 (NOT PROVEN (n = 5))
- OLD system: 293 names a day; top-5 by list order: MCX PE 09:01, ONGC PE 09:08, MANAPPURAM PE 09:08, HINDZINC PE 09:08, ADANIENSOL CE 09:15 → >=1% 3/5 60% vs 36% lift 1.67 · >=2% 1/5 20% vs 11% lift 1.86 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: AMBER CE, BLUESTARCO CE, CROMPTON CE, DIXON CE, PGEL CE, VOLTAS CE (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 9 names here = 9 in its own EDGE block; 2%+ its way: 2 by 15:10 (theirs) / 2 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: PARTIAL RUN: no run.json - the playback stopped at 14:01 virtual; names it would have made after that are missing (closes are still the day's); prediction-loop names: the prediction loop's point-in-time replay of 2026-11-18 (C_replays) (<server>/girdata/review/monday/C_replays/2026-11-18, edge.rows); news calls (C3): <server>/girdata/review/monday/C_replays/2026-11-18/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.


## Coverage of the movers (not the goal)
53 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 1 | 8 | 44 | 0 |
| v2 cards + WATCH | 10 | 38 | 4 | 1 |
| old system | 35 | 18 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 30 crossed 3%; in time 25, late 1, missed 4.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| NAVINFLUOR | 11:04 UP | 4.72 | MISSED | LATE | nothing on this share |
| DIXON | 12:04 DOWN | -3.56 | MISSED | LATE | nothing on this share |
| ANGELONE | 09:20 UP | -3.29 | MISSED | LATE | first 11:24 PE GET READY LOG (AI) · best 12:00 PE GET READY WATCH (AI) · last 12:53 PE nothing LOG (rules): cancelled: the GET READY call from 12:51 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| SAGILITY | 10:18 UP | 2.87 | MISSED | BEFORE | nothing on this share |
| IREDA | 10:03 UP | 2.04 | LATE 11:21 | LATE | first 11:21 CE GET READY WATCH (AI) · best 11:21 CE GET READY WATCH (AI) · last 12:35 CE nothing LOG (rules): cancelled: the GET READY call from 11:21 no longer holds (price left the trigger zone, the sector faded, or the score f… |

## Rings (phone alarms)
11 rings; 0 of them 09:15-09:45. By hour: 09 h 1, 10 h 1, 11 h 3, 12 h 2, 13 h 4.

## The AI
AI state: ON. AI decided 881 of 881 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 599 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (588 rows)
- by design: the idea left MUST SEE (by design) (2 rows)
- by design: rule veto: (d) its sector electronics & hardware is rising (+0.36%) - no PE against the sec (1 rows)
- by design: rule veto: (d) its sector capital goods is falling (-0.32%) - no CE against the sector unle (1 rows)
- by design: rule veto: (d) its sector electronics & hardware is rising (+0.24%) - no PE against the sec (1 rows)
- by design: rule veto: (d) its sector hospitals & diagnostics is rising (+0.34%) - no PE against the se (1 rows)
- by design: rule veto: (d) its sector electronics & hardware is rising (+0.30%) - no PE against the sec (1 rows)
- by design: rule veto: (d) its sector oil & gas is rising (+0.21%) - no PE against the sector unless DI (1 rows)

319 AI calls, $0.527 in all; the dearest single call $0.0275; 0 errors; stop reasons {'end_turn': 319}.
Cost by kind: final $0.2661, rank $0.0020, second $0.0020, triage $0.2571. Cost by model: routine-tier model $0.2611, final-tier model $0.2661.
Latency: p50 5390 ms, p95 9890 ms, max 16800 ms over 319 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 265, wrong 247, flat 263, not known 0; average move the call's way 0.01%
- after 60 min: right 348, wrong 229, flat 198, not known 0; average move the call's way 0.07%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 15, late 179, the wrong way 3, share did not move 2% 578 (of 775 new GO NOW / GET READY decisions, 41 of them cards)

## Flags
MISSED MOVER: 5, NEWS DIRECTION WRONG: 15
- 09:20 MISSED MOVER: ANGELONE crossed +3.0% at 09:20 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on ANGELONE by then
- 09:46 NEWS DIRECTION WRONG: DATAPATTNS CE GET READY at 09:16 was news-driven; the share went -2.02% against it in 30 min (worst -2.02%)
- 09:46 NEWS DIRECTION WRONG: SYRMA CE GET READY at 09:16 was news-driven; the share went -1.43% against it in 30 min (worst -1.90%)
- 09:56 NEWS DIRECTION WRONG: BHARATFORG PE GET READY at 09:26 was news-driven; the share went -0.57% against it in 30 min (worst -0.57%)
- 10:00 NEWS DIRECTION WRONG: MCX CE GET READY at 09:30 was news-driven; the share went -0.59% against it in 30 min (worst -0.85%)
- 10:03 MISSED MOVER: IREDA crossed +3.0% at 10:03 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on IREDA by then
- 10:05 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 09:35 was news-driven; the share went -0.68% against it in 30 min (worst -1.19%)
- 10:07 NEWS DIRECTION WRONG: NTPC PE GET READY at 09:37 was news-driven; the share went -0.53% against it in 30 min (worst -0.75%)
- 10:18 MISSED MOVER: SAGILITY crossed +3.0% at 10:18 (+3.14% vs the previous close) with no CE call by then · the engine said nothing on SAGILITY by then
- 11:04 MISSED MOVER: NAVINFLUOR crossed +3.0% at 11:04 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on NAVINFLUOR by then
- 12:04 MISSED MOVER: DIXON crossed -3.0% at 12:04 (-3.02% vs the previous close) with no PE call by then · the engine said nothing on DIXON by then
- 12:30 NEWS DIRECTION WRONG: ANGELONE PE GET READY at 12:00 was news-driven; the share went -1.22% against it in 30 min (worst -2.20%)
- 13:17 NEWS DIRECTION WRONG: MCX PE GET READY at 12:47 was news-driven; the share went -0.74% against it in 30 min (worst -0.74%)
- 13:20 NEWS DIRECTION WRONG: CDSL PE GET READY at 12:50 was news-driven; the share went -0.83% against it in 30 min (worst -0.96%)
- 13:26 NEWS DIRECTION WRONG: SYRMA CE GET READY at 12:56 was news-driven; the share went -0.50% against it in 30 min (worst -0.59%)
- 14:14 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 13:14 was news-driven; the share went -0.53% against it in 60 min (worst -0.53%)
- 14:27 NEWS DIRECTION WRONG: 360ONE PE GET READY at 13:27 was news-driven; the share went -0.54% against it in 60 min (worst -0.84%)
- 14:07 NEWS DIRECTION WRONG: KFINTECH PE GET READY at 13:37 was news-driven; the share went -0.50% against it in 30 min (worst -0.61%)
- 14:10 NEWS DIRECTION WRONG: MANAPPURAM PE GET READY at 13:40 was news-driven; the share went -0.55% against it in 30 min (worst -0.55%)
- 14:52 NEWS DIRECTION WRONG: IOC PE GET READY at 13:52 was news-driven; the share went -0.70% against it in 60 min (worst -0.79%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
