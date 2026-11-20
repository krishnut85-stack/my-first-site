# TEST OBSERVER scorecard - LIVE_2026-11-20 (replayed day 2026-11-20)

Made 2026-11-20 15:50:30 IST by v2/testobs/observer.py. Run folder: `<server>/intraday/v2/data`. Done because: end of the live day (15:40 IST).

## In one line
EDGE LIVE_2026-11-20 2026-11-20: 151 names a day (82 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 1/5 20% vs 11% lift 1.76, >=2% 0/5 0% vs 3% lift 0.0 · all names >=1% 15/151 10% vs 15% lift 0.65, >=2% 6/151 4% vs 5% lift 0.73 · knowledge >=2% 4/82 5% vs 7% lift 0.71 · all names >=2% to the next close not known yet (2026-11-23 has not closed / no data) · old system >=2% 21/288 7% vs 6% lift 1.13 (288 names) || coverage (not the goal): LIVE_2026-11-20 2026-11-20: catch cards 0 / 10 / 32 / 0 · cards+WATCH 0 / 17 / 15 / 10 · old 13 / 29 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 40: in time 14, late 12, missed 14 · rings 75 (09:15-09:45 7) · AI 917 of 917 (100%), $0.178, 173 calls · flags MISSED MOVER 26, NEWS DIRECTION WRONG 40, NOISE 4

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-20, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-23 - not known yet). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 151 | 15/151 = 10% vs base 15% → lift 0.65 | 6/151 = 4% vs base 5% → lift 0.73 | not known (no next close yet) | 31 (20%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 82 | 9/82 = 11% vs base 18% → lift 0.62 | 4/82 = 5% vs base 7% → lift 0.71 | not known (no next close yet) | 19 (23%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 33 | 1/33 = 3% vs base 17% → lift 0.18 | 0/33 = 0% vs base 5% → lift 0.0 | not known (no next close yet) | 6 (18%) | n >= 30 |
| channel: engine note 1945 | 24 | 3/24 = 12% vs base 15% → lift 0.82 | 3/24 = 12% vs base 7% → lift 1.85 | not known (no next close yet) | 7 (29%) | NOT PROVEN (n < 30) |
| channel: go now / get ready (any lane) | 116 | 5/116 = 4% vs base 10% → lift 0.42 | 2/116 = 2% vs base 3% → lift 0.58 | not known (no next close yet) | 31 (27%) | n >= 30 |
| channel: news row (C3, silent) | 22 | 1/22 = 4% vs base 18% → lift 0.25 | 0/22 = 0% vs base 5% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| channel: prediction loop (lists, fired movers) | 18 | 7/18 = 39% vs base 36% → lift 1.08 | 1/18 = 6% vs base 16% → lift 0.36 | not known (no next close yet) | 1 (6%) | NOT PROVEN (n < 30) |
| source: trader read | 0 | - | - | - | - | none named |
| source: filing | 3 | 0/3 = 0% vs base 17% → lift 0.0 | 0/3 = 0% vs base 7% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: results | 7 | 1/7 = 14% vs base 46% → lift 0.31 | 0/7 = 0% vs base 21% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 1 | 1/1 = 100% vs base 54% → lift 1.85 | 0/1 = 0% vs base 27% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: broker call | 3 | 1/3 = 33% vs base 41% → lift 0.81 | 0/3 = 0% vs base 18% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 38 | 3/38 = 8% vs base 13% → lift 0.62 | 1/38 = 3% vs base 4% → lift 0.73 | not known (no next close yet) | 11 (29%) | n >= 30 |
| source: sector chain / driver link | 30 | 3/30 = 10% vs base 14% → lift 0.72 | 3/30 = 10% vs base 6% → lift 1.73 | not known (no next close yet) | 8 (27%) | n >= 30 |
| source: price-only | 69 | 6/69 = 9% vs base 12% → lift 0.7 | 2/69 = 3% vs base 4% → lift 0.76 | not known (no next close yet) | 12 (17%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-20 from 09:00) - comparison only | 288 | 50/288 = 17% vs base 18% → lift 0.97 | 21/288 = 7% vs base 6% → lift 1.13 | not known (no next close yet) | 37 (13%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 5% → lift 7.03 | 0/3 = 0% vs base 1% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 37 | 5/37 = 14% vs base 21% → lift 0.64 | 3/37 = 8% vs base 8% → lift 0.99 | not known (no next close yet) | 5 (14%) | n >= 30 |
| OLD system source: filing | 39 | 7/39 = 18% vs base 22% → lift 0.84 | 2/39 = 5% vs base 8% → lift 0.63 | not known (no next close yet) | 4 (10%) | n >= 30 |
| OLD system source: news | 139 | 21/139 = 15% vs base 15% → lift 1.01 | 11/139 = 8% vs base 5% → lift 1.48 | not known (no next close yet) | 23 (16%) | n >= 30 |
| OLD system source: price-only | 10 | 2/10 = 20% vs base 14% → lift 1.38 | 0/10 = 0% vs base 4% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 47 | 9/47 = 19% vs base 20% → lift 0.96 | 4/47 = 8% vs base 7% → lift 1.19 | not known (no next close yet) | 4 (8%) | n >= 30 |
| OLD system source: sector chain / driver link | 13 | 5/13 = 38% vs base 26% → lift 1.51 | 1/13 = 8% vs base 9% → lift 0.88 | not known (no next close yet) | 1 (8%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 20 | 7 | 5 | -2.0 | +0.69% | 23.0% |
| KNOWLEDGE-driven names (any source but price-only) | 10 | 5 | 5 | -1.0 | +1.09% | 19.5% |
| channel: card (MUST SEE / CRITICAL) | 10 | 0 | 0 | -45.0 | -0.36% | -5.0% |
| channel: engine note 1945 | 4 | 4 | 4 | 1.0 | +2.34% | 67.0% |
| channel: go now / get ready (any lane) | 17 | 2 | 0 | -3 | +0.48% | 15% |
| channel: news row (C3, silent) | 5 | 1 | 1 | -52 | -0.18% | -4% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -7.0 | +0.14% | 9.5% |
| source: filing | 2 | 0 | 0 | -4.0 | +0.26% | 6.5% |
| source: results | 1 | 0 | 0 | -9 | -0.74% | -11% |
| source: broker call | 1 | 0 | 0 | -18 | +1.50% | 24% |
| source: news | 2 | 1 | 1 | -1.0 | +0.19% | -1.5% |
| source: sector chain / driver link | 4 | 4 | 4 | 1.0 | +2.34% | 67.0% |
| source: price-only | 10 | 2 | 0 | -2.0 | +0.58% | 23.0% |
| OLD system (tomorrow.db alerts of 2026-11-20 from 09:00) - comparison only | 42 | 13 | 0 | -1.0 | +1.30% | 34.0% |
| OLD system source: TV | 1 | 0 | 0 | -132 | +1.17% | 28% |
| OLD system source: broker call | 7 | 3 | 0 | -1 | +1.44% | 32% |
| OLD system source: filing | 2 | 0 | 0 | -29.0 | +2.16% | 45.0% |
| OLD system source: news | 20 | 7 | 0 | -0.5 | +1.56% | 40.0% |
| OLD system source: price-only | 4 | 0 | 0 | -106.0 | +0.88% | 16.5% |
| OLD system source: results | 6 | 3 | 0 | 0.0 | +1.85% | 63.5% |
| OLD system source: sector chain / driver link | 2 | 0 | 0 | -182.0 | +1.03% | 28.0% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by engine rank): KALYANKJIL PE 09:20, TITAN PE 09:20, APOLLOHOSP CE 09:33, HAL PE 09:28, OIL PE 09:20 → >=1% 1/5 20% vs 11% lift 1.76 · >=2% 0/5 0% vs 3% lift 0.0 · next close >=2% not known (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 33 names a day; top-5 by engine rank: VEDL PE 09:30, JSWSTEEL PE 09:30, TATASTEEL PE 09:30, NMDC PE 09:20, HINDPETRO PE 09:26 → >=1% 0/5 0% vs 4% lift 0.0 · >=2% 0/5 0% vs 0% lift ? (NOT PROVEN (n = 5))
- engine note 1945: 24 names a day; top-5 by score / points: HINDZINC PE 21:05, NATIONALUM PE 21:05, TATASTEEL PE 21:05, HINDALCO PE 21:05, JINDALSTEL PE 21:05 → >=1% 0/5 0% vs 2% lift 0.0 · >=2% 0/5 0% vs 0% lift ? (NOT PROVEN (n = 5))
- go now / get ready (any lane): 116 names a day; top-5 by engine rank: VEDL PE 09:20, NATIONALUM PE 09:20, JSWSTEEL PE 09:20, SAIL PE 09:20, KALYANKJIL PE 09:20 → >=1% 0/5 0% vs 4% lift 0.0 · >=2% 0/5 0% vs 0% lift ? (NOT PROVEN (n = 5))
- news row (C3, silent): 22 names a day; top-5 by score / points: VEDL PE 09:00, SYRMA CE 09:20, AMBER CE 09:20, KAYNES PE 09:20, MUTHOOTFIN PE 10:08 → >=1% 1/5 20% vs 20% lift 1.01 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 18 names a day; top-5 by list order: WAAREEENER CE 07:15, KALYANKJIL CE 22:45, TMPV CE 07:15, MUTHOOTFIN PE 09:08, ALKEM PE 09:08 → >=1% 2/5 40% vs 33% lift 1.2 · >=2% 0/5 0% vs 16% lift 0.0 (NOT PROVEN (n = 5))
- ALL: 151 names a day; top-5 by engine rank: KALYANKJIL PE 09:20, TITAN PE 09:20, APOLLOHOSP CE 09:33, HAL PE 09:28, OIL PE 09:20 → >=1% 1/5 20% vs 11% lift 1.76 · >=2% 0/5 0% vs 3% lift 0.0 (NOT PROVEN (n = 5))
- OLD system: 288 names a day; top-5 by list order: ADANIENSOL PE 09:15, APLAPOLLO PE 09:15, BAJAJ-AUTO CE 09:15, BEL PE 09:15, BLUESTARCO CE 09:15 → >=1% 0/5 0% vs 23% lift 0.0 · >=2% 0/5 0% vs 11% lift 0.0 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: none (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 18 names here = 18 in its own EDGE block; 2%+ its way: 1 by 15:10 (theirs) / 1 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-20 (C_replays) (<server>/girdata/review/monday/C_replays/2026-11-20, edge.rows); engine note kb_0715.json: not in the run folder; news calls (C3): <server>/girdata/review/monday/C_replays/2026-11-20/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.


## Coverage of the movers (not the goal)
42 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 10 | 32 | 0 |
| v2 cards + WATCH | 0 | 17 | 15 | 10 |
| old system | 13 | 29 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 40 crossed 3%; in time 14, late 12, missed 14.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| INDUSINDBK | 09:51 UP | 8.59 | MISSED | LATE | first 12:29 CE nothing LOG (rules) · best no GO NOW / GET READY · last 14:30 CE nothing LOG (rules): cancelled: the GET READY call from 14:11 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| CUB | 12:01 UP | 6.25 | MISSED | LATE | first 09:16 PE GET READY WATCH (AI) · best 09:16 PE GET READY WATCH (AI) · last 14:00 CE nothing LOG (rules): cancelled: the GET READY call from 13:36 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| APOLLOHOSP | 09:27 UP | 5.29 | LATE 09:33 | BEFORE | first 09:33 CE GET READY WATCH (AI) · best 10:00 CE GET READY MUST SEE (AI) · last 14:28 PE nothing CRITICAL (rules): TV BUY call on APOLLOHOSP (Macquarie) at 14:27 - PE on it held off 60 min |
| AXISBANK | 12:02 UP | 4.72 | MISSED | BEFORE | first 12:29 CE nothing LOG (rules) · best no GO NOW / GET READY · last 14:30 CE nothing LOG (rules): cancelled: the GET READY call from 14:11 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| UNIONBANK | 12:03 UP | 4.21 | MISSED | LATE | first 09:16 PE GET READY WATCH (AI) · best 09:16 PE GET READY WATCH (AI) · last 14:30 CE nothing LOG (rules): cancelled: the GET READY call from 14:11 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| ANGELONE | 12:27 UP | 3.52 | MISSED | LATE | first 12:41 CE nothing LOG (rules) · best no GO NOW / GET READY · last 13:50 CE nothing LOG (rules): cancelled: the GET READY call from 13:49 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| KALYANKJIL | 09:17 DOWN | -3.37 | LATE 09:20 | BEFORE | first 09:20 PE GET READY MUST SEE (AI) · best 09:20 PE GET READY MUST SEE (AI) · last 13:41 PE nothing LOG (rules): cancelled: the GET READY call from 13:39 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| PNBHOUSING | 12:02 UP | 3.21 | MISSED | LATE | first 09:29 PE GET READY WATCH (AI) · best 09:29 PE GET READY WATCH (AI) · last 09:36 PE nothing LOG (rules): cancelled: the GET READY call from 09:35 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| MARUTI | 14:15 UP | 3.11 | MISSED | LATE | nothing on this share |
| HDFCBANK | 13:57 UP | 2.94 | LATE 14:45 | BEFORE | first 09:16 PE GET READY WATCH (AI) · best 09:16 PE GET READY WATCH (AI) · last 14:57 CE nothing CRITICAL (rules): TV SELL call on HDFCBANK at 14:57 - you HOLD it: bounce / drop risk, book or trail now |
| INOXWIND | 14:06 DOWN | -2.65 | MISSED | LATE | nothing on this share |
| GVT&D | 09:15 DOWN | -2.63 | MISSED | BEFORE | nothing on this share |
| GODREJPROP | 14:15 UP | 2.62 | MISSED | LATE | first 09:16 PE GET READY WATCH (AI) · best 09:16 PE GET READY WATCH (AI) · last 14:29 CE nothing LOG (rules): cancelled: the GET READY call from 14:28 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| MUTHOOTFIN | 09:15 DOWN | -2.58 | LATE 09:20 | BEFORE | first 09:20 PE GET READY WATCH (AI) · best 09:45 PE GET READY MUST SEE (AI) · last 14:30 PE nothing LOG (rules): cancelled: the GET READY call from 14:29 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| CGPOWER | 09:15 DOWN | -2.57 | LATE 09:16 | BEFORE | first 09:16 PE GET READY WATCH (AI) · best 09:16 PE GET READY WATCH (AI) · last 14:26 PE nothing LOG (rules): cancelled: the GET READY call from 14:25 no longer holds (price left the trigger zone, the sector faded, or the score f… |

## Rings (phone alarms)
75 rings; 7 of them 09:15-09:45. By hour: 08 h 4, 09 h 12, 10 h 12, 11 h 17, 12 h 8, 13 h 9, 14 h 9, 15 h 4.

## The AI
AI state: ON. AI decided 917 of 917 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 1877 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (1284 rows)
- by design: critical lane (by design) (66 rows)
 [the trader's account figures removed] ) (24 rows)
 [the trader's account figures removed] ) (19 rows)
- by design: the idea left MUST SEE (by design) (18 rows)
 [the trader's account figures removed] ) (17 rows)
 [the trader's account figures removed] ) (14 rows)
 [the trader's account figures removed] ) (12 rows)

173 AI calls, $0.178 in all; the dearest single call $0.0463; 0 errors; stop reasons {'end_turn': 173}.
Cost by kind: final $0.1227, rank $0.0023, second $0.0025, triage $0.0502. Cost by model: final-tier model $0.1227, routine-tier model $0.0549.
Latency: p50 2130 ms, p95 6071 ms, max 11114 ms over 173 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 171, wrong 515, flat 187, not known 0; average move the call's way -0.26%
- after 60 min: right 179, wrong 550, flat 144, not known 0; average move the call's way -0.3%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 0, late 177, the wrong way 35, share did not move 2% 661 (of 873 new GO NOW / GET READY decisions, 74 of them cards)

## Flags
MISSED MOVER: 26, NEWS DIRECTION WRONG: 40, NOISE: 4
- 09:15 MISSED MOVER: CGPOWER crossed -3.0% at 09:15 (-3.19% vs the previous close) with no PE call by then · the engine said nothing on CGPOWER by then
- 09:15 MISSED MOVER: GVT&D crossed -3.0% at 09:15 (-3.23% vs the previous close) with no PE call by then · the engine said nothing on GVT&D by then
- 09:15 MISSED MOVER: HINDZINC crossed -3.0% at 09:15 (-4.35% vs the previous close) with no PE call by then · the engine said nothing on HINDZINC by then
- 09:15 MISSED MOVER: MANAPPURAM crossed -3.0% at 09:15 (-3.91% vs the previous close) with no PE call by then · the engine said nothing on MANAPPURAM by then
- 09:15 MISSED MOVER: MUTHOOTFIN crossed -3.0% at 09:15 (-4.95% vs the previous close) with no PE call by then · the engine said nothing on MUTHOOTFIN by then
- 09:15 MISSED MOVER: POWERINDIA crossed -3.0% at 09:15 (-3.09% vs the previous close) with no PE call by then · the engine said nothing on POWERINDIA by then
- 09:16 MISSED MOVER: NATIONALUM crossed -3.0% at 09:16 (-3.60% vs the previous close) with no PE call by then · the engine said nothing on NATIONALUM by then
- 09:16 MISSED MOVER: VEDL crossed -3.0% at 09:16 (-3.52% vs the previous close) with no PE call by then · the engine said nothing on VEDL by then
- 09:17 MISSED MOVER: KALYANKJIL crossed -3.0% at 09:17 (-3.28% vs the previous close) with no PE call by then · the engine said nothing on KALYANKJIL by then
- 09:20 MISSED MOVER: JSWSTEEL crossed -3.0% at 09:20 (-3.28% vs the previous close) with no PE call by then · the engine said: first 09:20 PE GET READY WATCH (AI); best 09:20 PE GET READY WATCH (AI); last 09:20 PE GET READY WATCH (AI): Metals confirmed down, SB agrees, leader role, not a chase. · opening: share ideas w…
- 09:20 MISSED MOVER: SAIL crossed -3.0% at 09:20 (-3.05% vs the previous close) with no PE call by then · the engine said: first 09:20 PE GET READY WATCH (AI); best 09:20 PE GET READY WATCH (AI); last 09:20 PE GET READY WATCH (AI): Metals confirmed down, SB agrees, leader role, high-beta steel producer. · opening: shar…
- 09:27 MISSED MOVER: APOLLOHOSP crossed +3.0% at 09:27 (+3.10% vs the previous close) with no CE call by then · the engine said nothing on APOLLOHOSP by then
- 09:46 NEWS DIRECTION WRONG: BAJFINANCE PE GET READY at 09:16 was news-driven; the share went -0.83% against it in 30 min (worst -0.86%)
- 09:46 NEWS DIRECTION WRONG: DLF PE GET READY at 09:16 was news-driven; the share went -1.55% against it in 30 min (worst -1.58%)
- 09:46 NEWS DIRECTION WRONG: HDFCBANK PE GET READY at 09:16 was news-driven; the share went -0.69% against it in 30 min (worst -0.89%)
- 09:46 NEWS DIRECTION WRONG: INDIGO PE GET READY at 09:16 was news-driven; the share went -1.23% against it in 30 min (worst -1.23%)
- 09:46 NEWS DIRECTION WRONG: INFY PE GET READY at 09:16 was news-driven; the share went -0.76% against it in 30 min (worst -1.49%)
- 09:46 NEWS DIRECTION WRONG: MAZDOCK PE GET READY at 09:16 was news-driven; the share went -1.16% against it in 30 min (worst -1.16%)
- 09:48 NEWS DIRECTION WRONG: TCS CE GET READY at 09:18 was news-driven; the share went -0.85% against it in 30 min (worst -1.01%)
- 09:50 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:20 was news-driven; the share went -0.62% against it in 30 min (worst -0.77%)
- 09:51 NEWS DIRECTION WRONG: SBIN PE GET READY at 09:21 was news-driven; the share went -0.51% against it in 30 min (worst -0.51%)
- 09:51 MISSED MOVER: INDUSINDBK crossed +3.0% at 09:51 (+3.07% vs the previous close) with no CE call by then · the engine said nothing on INDUSINDBK by then
- 09:54 NEWS DIRECTION WRONG: WIPRO CE GET READY at 09:24 was news-driven; the share went -0.56% against it in 30 min (worst -0.68%)
- 09:55 NEWS DIRECTION WRONG: COFORGE CE GET READY at 09:25 was news-driven; the share went -0.74% against it in 30 min (worst -1.00%)
- 09:58 NEWS DIRECTION WRONG: BDL PE GET READY at 09:28 was news-driven; the share went -0.79% against it in 30 min (worst -0.82%)
- 09:58 NEWS DIRECTION WRONG: BHARATFORG PE GET READY at 09:28 was news-driven; the share went -1.35% against it in 30 min (worst -1.35%)
- 09:58 NEWS DIRECTION WRONG: HAL PE GET READY at 09:28 was news-driven; the share went -0.68% against it in 30 min (worst -0.68%)
- 09:58 NEWS DIRECTION WRONG: MOTHERSON PE GET READY at 09:28 was news-driven; the share went -0.73% against it in 30 min (worst -0.79%)
- 10:00 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:30 was news-driven; the share went -1.09% against it in 30 min (worst -1.22%)
- 10:01 NEWS DIRECTION WRONG: KFINTECH PE GET READY at 09:31 was news-driven; the share went -2.83% against it in 30 min (worst -2.83%)
- 10:03 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:33 was news-driven; the share went -1.04% against it in 30 min (worst -1.04%)
- 10:09 NEWS DIRECTION WRONG: PETRONET PE GET READY at 09:39 was news-driven; the share went -0.81% against it in 30 min (worst -0.81%)
- 10:10 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 09:40 was news-driven; the share went -0.59% against it in 30 min (worst -0.59%)
- 10:10 NEWS DIRECTION WRONG: IOC PE GET READY at 09:40 was news-driven; the share went -0.52% against it in 30 min (worst -0.55%)
- 10:10 NEWS DIRECTION WRONG: CAMS PE GET READY at 09:40 was news-driven; the share went -1.49% against it in 30 min (worst -2.03%)
- 10:13 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:43 was news-driven; the share went -0.70% against it in 30 min (worst -0.70%)
- 10:16 NEWS DIRECTION WRONG: IOC PE GET READY at 09:16 was news-driven; the share went -0.63% against it in 60 min (worst -0.63%)
- 10:20 NEWS DIRECTION WRONG: AMBUJACEM CE GET READY at 09:50 was news-driven; the share went -0.71% against it in 30 min (worst -0.71%)
- 10:24 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 09:24 was news-driven; the share went -0.59% against it in 60 min (worst -0.59%)
- 10:30 NEWS DIRECTION WRONG: TATASTEEL PE GET READY at 09:30 was news-driven; the share went -0.70% against it in 60 min (worst -0.70%)
- ... 30 more in flags.jsonl

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
