# TEST OBSERVER scorecard - TEST_ai_full3_1118 (replayed day 2026-11-18)

Made 2026-11-19 21:28:16 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full3_1118`. Done because: run.json written by the player (the day's end).

## In one line
EDGE TEST_ai_full3_1118 2026-11-18: 124 names a day (84 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 0/5 0% vs 13% lift 0.0, >=2% 0/5 0% vs 3% lift 0.0 · all names >=1% 26/124 21% vs 27% lift 0.78, >=2% 10/124 8% vs 8% lift 1.0 · knowledge >=2% 6/84 7% vs 8% lift 0.89 · all names >=2% to the next close 25/124 20% vs 14% lift 1.43 · old system >=2% 21/293 7% vs 8% lift 0.88 (293 names) || coverage (not the goal): TEST_ai_full3_1118 2026-11-18: catch cards 0 / 9 / 43 / 1 · cards+WATCH 11 / 7 / 34 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 9, late 1, missed 20 · rings 50 (09:15-09:45 12) · AI 245 of 245 (100%), $0.180, 115 calls · flags MISSED MOVER 20, NOISE 1, NEWS DIRECTION WRONG 8

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-18, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-19 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 124 | 26/124 = 21% vs base 27% → lift 0.78 | 10/124 = 8% vs base 8% → lift 1.0 | 25/124 = 20% vs base 14% → lift 1.43 | 12 (10%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 84 | 18/84 = 21% vs base 27% → lift 0.8 | 6/84 = 7% vs base 8% → lift 0.89 | 24/84 = 29% vs base 16% → lift 1.82 | 9 (11%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 25 | 4/25 = 16% vs base 17% → lift 0.93 | 1/25 = 4% vs base 4% → lift 0.99 | 1/25 = 4% vs base 6% → lift 0.64 | 1 (4%) | NOT PROVEN (n < 30) |
| channel: engine note 0715 | 37 | 9/37 = 24% vs base 24% → lift 1.03 | 3/37 = 8% vs base 7% → lift 1.14 | 15/37 = 40% vs base 17% → lift 2.33 | 7 (19%) | n >= 30 |
| channel: engine note 1945 | 56 | 14/56 = 25% vs base 28% → lift 0.91 | 5/56 = 9% vs base 8% → lift 1.07 | 22/56 = 39% vs base 16% → lift 2.42 | 5 (9%) | n >= 30 |
| channel: go now / get ready (any lane) | 63 | 17/63 = 27% vs base 28% → lift 0.98 | 5/63 = 8% vs base 8% → lift 1.0 | 10/63 = 16% vs base 11% → lift 1.39 | 2 (3%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 9 | 2/9 = 22% vs base 24% → lift 0.91 | 2/9 = 22% vs base 8% → lift 2.76 | 1/9 = 11% vs base 16% → lift 0.71 | 4 (44%) | NOT PROVEN (n < 30) |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 78 | 17/78 = 22% vs base 28% → lift 0.77 | 6/78 = 8% vs base 8% → lift 0.91 | 19/78 = 24% vs base 15% → lift 1.6 | 8 (10%) | n >= 30 |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 31 | 8/31 = 26% vs base 27% → lift 0.96 | 3/31 = 10% vs base 8% → lift 1.2 | 10/31 = 32% vs base 16% → lift 1.96 | 6 (19%) | n >= 30 |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 51 | 13/51 = 26% vs base 30% → lift 0.86 | 5/51 = 10% vs base 9% → lift 1.1 | 17/51 = 33% vs base 16% → lift 2.12 | 5 (10%) | n >= 30 |
| source: trader read | 0 | - | - | - | - | none named |
| source: filing | 0 | - | - | - | - | none named |
| source: results | 1 | 1/1 = 100% vs base 43% → lift 2.32 | 0/1 = 0% vs base 13% → lift 0.0 | 0/1 = 0% vs base 12% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 0 | - | - | - | - | none named |
| source: broker call | 6 | 0/6 = 0% vs base 25% → lift 0.0 | 0/6 = 0% vs base 8% → lift 0.0 | 2/6 = 33% vs base 17% → lift 1.96 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 8 | 2/8 = 25% vs base 15% → lift 1.63 | 1/8 = 12% vs base 4% → lift 3.03 | 0/8 = 0% vs base 14% → lift 0.0 | 2 (25%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 69 | 15/69 = 22% vs base 28% → lift 0.77 | 5/69 = 7% vs base 8% → lift 0.86 | 22/69 = 32% vs base 16% → lift 2.02 | 7 (10%) | n >= 30 |
| source: price-only | 40 | 8/40 = 20% vs base 27% → lift 0.73 | 4/40 = 10% vs base 8% → lift 1.23 | 1/40 = 2% vs base 11% → lift 0.24 | 3 (8%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 293 | 76/293 = 26% vs base 27% → lift 0.96 | 21/293 = 7% vs base 8% → lift 0.88 | 37/293 = 13% vs base 14% → lift 0.87 | 14 (5%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 23% → lift 1.43 | 1/3 = 33% vs base 7% → lift 4.95 | 1/3 = 33% vs base 14% → lift 2.45 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 34 | 7/34 = 21% vs base 24% → lift 0.86 | 2/34 = 6% vs base 7% → lift 0.82 | 7/34 = 21% vs base 15% → lift 1.41 | 3 (9%) | n >= 30 |
| OLD system source: filing | 30 | 11/30 = 37% vs base 32% → lift 1.14 | 2/30 = 7% vs base 10% → lift 0.68 | 2/30 = 7% vs base 15% → lift 0.45 | 2 (7%) | n >= 30 |
| OLD system source: news | 92 | 20/92 = 22% vs base 24% → lift 0.9 | 4/92 = 4% vs base 7% → lift 0.59 | 13/92 = 14% vs base 16% → lift 0.91 | 5 (5%) | n >= 30 |
| OLD system source: price-only | 9 | 1/9 = 11% vs base 22% → lift 0.5 | 0/9 = 0% vs base 7% → lift 0.0 | 1/9 = 11% vs base 15% → lift 0.75 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 112 | 30/112 = 27% vs base 30% → lift 0.89 | 10/112 = 9% vs base 9% → lift 0.99 | 9/112 = 8% vs base 14% → lift 0.59 | 4 (4%) | n >= 30 |
| OLD system source: sector chain / driver link | 10 | 3/10 = 30% vs base 15% → lift 2.04 | 0/10 = 0% vs base 4% → lift 0.0 | 2/10 = 20% vs base 14% → lift 1.47 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 3 | 3/3 = 100% vs base 42% → lift 2.36 | 2/3 = 67% vs base 13% → lift 5.13 | 2/3 = 67% vs base 12% → lift 5.81 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 25 | 17 | 12 | 1 | +1.80% | 54% |
| KNOWLEDGE-driven names (any source but price-only) | 14 | 14 | 10 | 1.0 | +1.90% | 55.0% |
| channel: card (MUST SEE / CRITICAL) | 9 | 0 | 0 | -19 | +0.82% | 19% |
| channel: engine note 0715 | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 | 11 | 11 | 11 | 1 | +1.92% | 56% |
| channel: go now / get ready (any lane) | 19 | 12 | 2 | 1 | +1.57% | 43% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -4.5 | +3.40% | 76.0% |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (6 share + side marked) | 14 | 14 | 10 | 1.0 | +1.90% | 55.0% |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 6 | 6 | 6 | 1.5 | +1.96% | 48.5% |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 11 | 11 | 11 | 1 | +1.92% | 56% |
| source: broker call | 1 | 1 | 0 | 1 | +0.83% | 29% |
| source: news | 1 | 1 | 0 | 1 | +3.01% | 65% |
| source: sector chain / driver link | 12 | 12 | 10 | 1.5 | +1.90% | 55.0% |
| source: price-only | 11 | 3 | 2 | -10 | +1.41% | 51% |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 53 | 33 | 3 | 1 | +1.84% | 62% |
| OLD system source: TV | 1 | 0 | 0 | -20 | +5.44% | 70% |
| OLD system source: broker call | 6 | 4 | 0 | 1.5 | +1.66% | 63.0% |
| OLD system source: filing | 9 | 6 | 1 | 2 | +1.65% | 54% |
| OLD system source: news | 12 | 5 | 0 | -1.0 | +1.91% | 64.0% |
| OLD system source: results | 20 | 15 | 0 | 1.0 | +2.02% | 64.5% |
| OLD system source: sector chain / driver link | 2 | 1 | 1 | -5.5 | +1.54% | 47.0% |
| OLD system source: trader read | 3 | 2 | 1 | 1 | +3.90% | 68% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by engine rank): BAJAJ-AUTO PE 09:59, IOC PE 13:23, SBILIFE PE 12:36, CDSL CE 09:24, HINDPETRO PE 10:46 → >=1% 0/5 0% vs 13% lift 0.0 · >=2% 0/5 0% vs 3% lift 0.0 · next close >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 25 names a day; top-5 by engine rank: BAJAJ-AUTO PE 09:59, MUTHOOTFIN PE 09:35, BAJFINANCE PE 12:56, IOC PE 13:23, SBILIFE PE 12:36 → >=1% 0/5 0% vs 15% lift 0.0 · >=2% 0/5 0% vs 3% lift 0.0 (NOT PROVEN (n = 5))
- engine note 0715: 37 names a day; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, VEDL PE 09:00, AMBER CE 09:00 → >=1% 4/5 80% vs 36% lift 2.23 · >=2% 1/5 20% vs 11% lift 1.86 (NOT PROVEN (n = 5))
- engine note 1945: 56 names a day; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, JINDALSTEL PE 09:00, JSWSTEEL PE 09:00 → >=1% 4/5 80% vs 43% lift 1.86 · >=2% 0/5 0% vs 13% lift 0.0 (NOT PROVEN (n = 5))
- go now / get ready (any lane): 63 names a day; top-5 by engine rank: BAJAJ-AUTO PE 09:59, IOC PE 13:23, SBILIFE PE 12:36, CDSL CE 09:24, HINDPETRO PE 10:46 → >=1% 0/5 0% vs 13% lift 0.0 · >=2% 0/5 0% vs 3% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 9 names a day; top-5 by list order: TMPV CE 19:45, DIXON PE 19:45, PIIND CE 19:45, ASHOKLEY PE 09:19, KALYANKJIL PE 09:26 → >=1% 2/5 40% vs 26% lift 1.51 · >=2% 2/5 40% vs 8% lift 4.74 (NOT PROVEN (n = 5))
- ALL: 124 names a day; top-5 by engine rank: BAJAJ-AUTO PE 09:59, IOC PE 13:23, SBILIFE PE 12:36, CDSL CE 09:24, HINDPETRO PE 10:46 → >=1% 0/5 0% vs 13% lift 0.0 · >=2% 0/5 0% vs 3% lift 0.0 (NOT PROVEN (n = 5))
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
| v2 cards (MUST SEE + CRITICAL) | 0 | 9 | 43 | 1 |
| v2 cards + WATCH | 11 | 7 | 34 | 1 |
| old system | 35 | 18 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 30 crossed 3%; in time 9, late 1, missed 20.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| TITAN | 10:15 DOWN | -5.3 | MISSED | BEFORE | nothing on this share |
| POLYCAB | 11:07 DOWN | -5.12 | MISSED | BEFORE | nothing on this share |
| KALYANKJIL | 11:40 DOWN | -4.8 | MISSED | LATE | nothing on this share |
| NAVINFLUOR | 11:04 UP | 4.72 | MISSED | LATE | nothing on this share |
| MANAPPURAM | 09:17 DOWN | -4.59 | MISSED | BEFORE | nothing on this share |
| SAIL | 09:41 DOWN | -4.27 | MISSED | BEFORE | nothing on this share |
| SWIGGY | 11:36 DOWN | -4.25 | MISSED | BEFORE | nothing on this share |
| CAMS | 13:42 DOWN | -3.76 | MISSED | LATE | nothing on this share |
| DIXON | 12:04 DOWN | -3.56 | MISSED | LATE | nothing on this share |
| KFINTECH | 11:59 DOWN | -3.34 | MISSED | LATE | nothing on this share |
| RVNL | 11:59 DOWN | -3.32 | MISSED | LATE | nothing on this share |
| ANGELONE | 09:20 UP | -3.29 | MISSED | LATE | nothing on this share |
| KEI | 14:08 DOWN | -3.27 | MISSED | BEFORE | nothing on this share |
| JINDALSTEL | 15:29 DOWN | -3.03 | MISSED | BEFORE | nothing on this share |
| HAVELLS | 12:49 DOWN | -2.98 | MISSED | BEFORE | nothing on this share |

## Rings (phone alarms)
50 rings; 12 of them 09:15-09:45. By hour: 09 h 14, 10 h 9, 11 h 9, 12 h 7, 13 h 6, 14 h 5.

## The AI
AI state: ON. AI decided 245 of 245 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 174 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (124 rows)
- by design: rule veto: (g2) long unwinding - sellers running out, tends to bounce (PE lost 64% in 16-da (45 rows)
- by design: rule veto: (g) short covering after 11:00 - fades (16-day test: SC CE gave the move back by (3 rows)
- by design: hard block: F&O ban (2 rows)

115 AI calls, $0.179 in all; the dearest single call $0.0398; 0 errors; stop reasons {'end_turn': 115}.
Cost by kind: final $0.1501, second $0.0039, triage $0.0255. Cost by model: final-tier model $0.1501, routine-tier model $0.0294.
Latency: p50 1761 ms, p95 3996 ms, max 7334 ms over 115 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 82, wrong 59, flat 54, not known 0; average move the call's way 0.05%
- after 60 min: right 90, wrong 62, flat 43, not known 0; average move the call's way 0.07%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 13, late 38, the wrong way 2, share did not move 2% 142 (of 195 new GO NOW / GET READY decisions, 71 of them cards)

## Flags
MISSED MOVER: 20, NOISE: 1, NEWS DIRECTION WRONG: 8
- 09:17 MISSED MOVER: MANAPPURAM crossed -3.0% at 09:17 (-3.14% vs the previous close) with no PE call by then · the engine said nothing on MANAPPURAM by then
- 09:20 MISSED MOVER: ANGELONE crossed +3.0% at 09:20 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on ANGELONE by then
- 09:35 NOISE: 7 rings in 15 virtual minutes (09:20-09:35), over 6
- 09:41 MISSED MOVER: SAIL crossed -3.0% at 09:41 (-3.06% vs the previous close) with no PE call by then · the engine said nothing on SAIL by then
- 09:40 NEWS DIRECTION WRONG: LUPIN CE GET READY at 09:10 was news-driven; the share went -1.01% against it in 30 min (worst -1.13%)
- 09:45 NEWS DIRECTION WRONG: SYRMA CE GET READY at 09:15 was news-driven; the share went -1.71% against it in 30 min (worst -1.90%)
- 09:45 NEWS DIRECTION WRONG: GODREJPROP PE GET READY at 09:15 was news-driven; the share went -0.64% against it in 30 min (worst -1.31%)
- 09:54 NEWS DIRECTION WRONG: CDSL CE GET READY at 09:24 was news-driven; the share went -1.52% against it in 30 min (worst -1.87%)
- 10:00 NEWS DIRECTION WRONG: BSE CE GET READY at 09:30 was news-driven; the share went -0.77% against it in 30 min (worst -0.95%)
- 10:03 MISSED MOVER: IREDA crossed +3.0% at 10:03 (+3.20% vs the previous close) with no CE call by then · the engine said nothing on IREDA by then
- 10:12 NEWS DIRECTION WRONG: INDHOTEL PE GET READY at 09:42 was news-driven; the share went -0.51% against it in 30 min (worst -0.57%)
- 10:15 MISSED MOVER: TITAN crossed -3.0% at 10:15 (-3.01% vs the previous close) with no PE call by then · the engine said nothing on TITAN by then
- 10:18 MISSED MOVER: SAGILITY crossed +3.0% at 10:18 (+3.14% vs the previous close) with no CE call by then · the engine said nothing on SAGILITY by then
- 11:04 MISSED MOVER: NAVINFLUOR crossed +3.0% at 11:04 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on NAVINFLUOR by then
- 11:07 MISSED MOVER: POLYCAB crossed -3.0% at 11:07 (-3.04% vs the previous close) with no PE call by then · the engine said nothing on POLYCAB by then
- 11:34 MISSED MOVER: CIPLA crossed +3.0% at 11:34 (+3.11% vs the previous close) with no CE call by then · the engine said nothing on CIPLA by then
- 11:36 MISSED MOVER: SWIGGY crossed -3.0% at 11:36 (-3.03% vs the previous close) with no PE call by then · the engine said nothing on SWIGGY by then
- 11:40 MISSED MOVER: KALYANKJIL crossed -3.0% at 11:40 (-3.17% vs the previous close) with no PE call by then · the engine said nothing on KALYANKJIL by then
- 11:55 MISSED MOVER: PIIND crossed -3.0% at 11:55 (-3.01% vs the previous close) with no PE call by then · the engine said nothing on PIIND by then
- 11:59 MISSED MOVER: KFINTECH crossed -3.0% at 11:59 (-3.05% vs the previous close) with no PE call by then · the engine said nothing on KFINTECH by then
- 11:59 MISSED MOVER: RVNL crossed -3.0% at 11:59 (-3.01% vs the previous close) with no PE call by then · the engine said nothing on RVNL by then
- 12:03 MISSED MOVER: ADANIGREEN crossed -3.0% at 12:03 (-3.00% vs the previous close) with no PE call by then · the engine said nothing on ADANIGREEN by then
- 12:04 MISSED MOVER: DIXON crossed -3.0% at 12:04 (-3.02% vs the previous close) with no PE call by then · the engine said nothing on DIXON by then
- 12:46 MISSED MOVER: BSE crossed -3.0% at 12:46 (-3.02% vs the previous close) with no PE call by then (it had a CE the other way from 09:30) · the engine said: first 09:30 CE GET READY MUST SEE (AI); best 09:30 CE GET READY MUST SEE (AI); last 09:33 CE nothing MUST SEE (rules): cancelled: the GO NOW call from 09:31 no…
- 12:49 MISSED MOVER: HAVELLS crossed -3.0% at 12:49 (-3.07% vs the previous close) with no PE call by then · the engine said nothing on HAVELLS by then
- 13:42 MISSED MOVER: CAMS crossed -3.0% at 13:42 (-3.04% vs the previous close) with no PE call by then · the engine said nothing on CAMS by then
- 14:08 MISSED MOVER: KEI crossed -3.0% at 14:08 (-3.08% vs the previous close) with no PE call by then · the engine said nothing on KEI by then
- 14:14 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 13:14 was news-driven; the share went -0.53% against it in 60 min (worst -0.53%)
- 14:40 NEWS DIRECTION WRONG: IOC PE GET READY at 13:40 was news-driven; the share went -0.61% against it in 60 min (worst -0.63%)

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
