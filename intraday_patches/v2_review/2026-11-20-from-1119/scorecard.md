# TEST OBSERVER scorecard - 2026-11-20-from-1119 (replayed day 2026-11-20)

Made 2026-11-20 18:08:24 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/2026-11-20-from-1119`. Done because: run.json written by the player (the day's end).

## In one line
EDGE 2026-11-20-from-1119 2026-11-20: 277 names a day (92 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 0/5 0% vs 23% lift 0.0, >=2% 0/5 0% vs 8% lift 0.0 · all names >=1% 38/277 14% vs 16% lift 0.86, >=2% 11/277 4% vs 5% lift 0.78 · knowledge >=2% 3/92 3% vs 6% lift 0.59 · all names >=2% to the next close not known yet (2026-11-23 has not closed / no data) · old system >=2% 21/288 7% vs 7% lift 1.07 (288 names) || coverage (not the goal): 2026-11-20-from-1119 2026-11-20: catch cards 0 / 14 / 27 / 1 · cards+WATCH 4 / 36 / 0 / 2 · old 20 / 22 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 40: in time 40, late 0, missed 0 · rings 19 (09:15-09:45 4) · AI 1126 of 1241 (91%), $1.969, 387 calls · flags AI FALLBACK 18, COST SPIKE 1, NEWS DIRECTION WRONG 47

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-20, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-23 - not known yet). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 277 | 38/277 = 14% vs base 16% → lift 0.86 | 11/277 = 4% vs base 5% → lift 0.78 | not known (no next close yet) | 40 (14%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 92 | 16/92 = 17% vs base 16% → lift 1.12 | 3/92 = 3% vs base 6% → lift 0.59 | not known (no next close yet) | 15 (16%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 45 | 3/45 = 7% vs base 15% → lift 0.44 | 1/45 = 2% vs base 5% → lift 0.46 | not known (no next close yet) | 10 (22%) | n >= 30 |
| channel: engine note 0715 | 5 | 0/5 = 0% vs base 2% → lift 0.0 | 0/5 = 0% vs base 0% → lift ? | not known (no next close yet) | 5 (100%) | NOT PROVEN (n < 30) |
| channel: engine note 1945 | 22 | 3/22 = 14% vs base 9% → lift 1.46 | 2/22 = 9% vs base 4% → lift 2.46 | not known (no next close yet) | 7 (32%) | NOT PROVEN (n < 30) |
| channel: go now / get ready (any lane) | 257 | 29/257 = 11% vs base 14% → lift 0.79 | 9/257 = 4% vs base 4% → lift 0.84 | not known (no next close yet) | 40 (16%) | n >= 30 |
| channel: news row (C3, silent) | 22 | 1/22 = 4% vs base 18% → lift 0.25 | 0/22 = 0% vs base 5% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| channel: prediction loop (lists, fired movers) | 18 | 7/18 = 39% vs base 36% → lift 1.08 | 1/18 = 6% vs base 16% → lift 0.36 | not known (no next close yet) | 1 (6%) | NOT PROVEN (n < 30) |
| source: trader read | 0 | - | - | - | - | none named |
| source: filing | 6 | 2/6 = 33% vs base 14% → lift 2.4 | 0/6 = 0% vs base 5% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: results | 3 | 1/3 = 33% vs base 20% → lift 1.7 | 0/3 = 0% vs base 9% → lift 0.0 | not known (no next close yet) | 2 (67%) | NOT PROVEN (n < 30) |
| source: TV | 6 | 2/6 = 33% vs base 36% → lift 0.93 | 0/6 = 0% vs base 15% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: broker call | 4 | 1/4 = 25% vs base 19% → lift 1.29 | 0/4 = 0% vs base 7% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 42 | 5/42 = 12% vs base 16% → lift 0.72 | 0/42 = 0% vs base 5% → lift 0.0 | not known (no next close yet) | 7 (17%) | n >= 30 |
| source: sector chain / driver link | 31 | 5/31 = 16% vs base 10% → lift 1.63 | 3/31 = 10% vs base 3% → lift 2.89 | not known (no next close yet) | 6 (19%) | n >= 30 |
| source: price-only | 185 | 22/185 = 12% vs base 16% → lift 0.73 | 8/185 = 4% vs base 5% → lift 0.89 | not known (no next close yet) | 25 (14%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-20 from the evening before 15:30) - comparison only | 288 | 50/288 = 17% vs base 18% → lift 0.95 | 21/288 = 7% vs base 7% → lift 1.07 | not known (no next close yet) | 37 (13%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 5% → lift 7.27 | 0/3 = 0% vs base 1% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 37 | 5/37 = 14% vs base 22% → lift 0.63 | 3/37 = 8% vs base 9% → lift 0.94 | not known (no next close yet) | 5 (14%) | n >= 30 |
| OLD system source: filing | 39 | 7/39 = 18% vs base 22% → lift 0.82 | 2/39 = 5% vs base 9% → lift 0.6 | not known (no next close yet) | 4 (10%) | n >= 30 |
| OLD system source: news | 139 | 21/139 = 15% vs base 15% → lift 0.99 | 11/139 = 8% vs base 6% → lift 1.4 | not known (no next close yet) | 23 (16%) | n >= 30 |
| OLD system source: price-only | 10 | 2/10 = 20% vs base 15% → lift 1.35 | 0/10 = 0% vs base 4% → lift 0.0 | not known (no next close yet) | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 47 | 9/47 = 19% vs base 21% → lift 0.93 | 4/47 = 8% vs base 8% → lift 1.11 | not known (no next close yet) | 4 (8%) | n >= 30 |
| OLD system source: sector chain / driver link | 13 | 5/13 = 38% vs base 27% → lift 1.44 | 1/13 = 8% vs base 9% → lift 0.83 | not known (no next close yet) | 1 (8%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 41 | 13 | 4 | -7 | +1.36% | 34% |
| KNOWLEDGE-driven names (any source but price-only) | 14 | 9 | 4 | 0.0 | +1.35% | 31.0% |
| channel: card (MUST SEE / CRITICAL) | 14 | 3 | 0 | -46.0 | -0.18% | -3.5% |
| channel: engine note 1945 | 2 | 2 | 2 | 1.0 | +3.16% | 85.5% |
| channel: go now / get ready (any lane) | 40 | 11 | 0 | -14.0 | +1.30% | 32.5% |
| channel: news row (C3, silent) | 5 | 1 | 1 | -52 | -0.18% | -4% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -7.0 | +0.14% | 9.5% |
| source: filing | 4 | 3 | 0 | 0.0 | +0.42% | 7.0% |
| source: TV | 2 | 0 | 0 | -7.0 | +0.95% | 16.5% |
| source: broker call | 2 | 1 | 1 | -17.0 | +0.36% | 19.0% |
| source: news | 2 | 1 | 1 | -9.0 | +0.06% | 4.0% |
| source: sector chain / driver link | 4 | 4 | 2 | 0.5 | +2.34% | 67.0% |
| source: price-only | 27 | 4 | 0 | -31 | +1.38% | 34% |
| OLD system (tomorrow.db alerts of 2026-11-20 from the evening before 15:30) - comparison only | 42 | 13 | 0 | -1.0 | +1.30% | 34.0% |
| OLD system source: TV | 1 | 0 | 0 | -132 | +1.17% | 28% |
| OLD system source: broker call | 7 | 3 | 0 | -1 | +1.44% | 32% |
| OLD system source: filing | 2 | 0 | 0 | -29.0 | +2.16% | 45.0% |
| OLD system source: news | 20 | 7 | 0 | -0.5 | +1.56% | 40.0% |
| OLD system source: price-only | 4 | 0 | 0 | -106.0 | +0.88% | 16.5% |
| OLD system source: results | 6 | 3 | 0 | 0.0 | +1.85% | 63.5% |
| OLD system source: sector chain / driver link | 2 | 0 | 0 | -182.0 | +1.03% | 28.0% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by AI priority): APLAPOLLO PE 09:17, ENRIN PE 09:17, MANKIND CE 09:42, CAMS CE 09:58, TRENT CE 09:45 → >=1% 0/5 0% vs 23% lift 0.0 · >=2% 0/5 0% vs 8% lift 0.0 · next close >=2% not known (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 45 names a day; top-5 by AI priority: APLAPOLLO PE 09:17, ENRIN PE 09:17, CAMS CE 09:58, SAIL PE 09:17, CUB CE 12:30 → >=1% 1/5 20% vs 10% lift 2.02 · >=2% 1/5 20% vs 2% lift 8.72 (NOT PROVEN (n = 5))
- engine note 0715: 5 names a day; top-5 by score / points: HINDALCO PE 07:15, NATIONALUM PE 07:15, HINDZINC PE 07:15, POLYCAB PE 07:15, KEI PE 07:15 → >=1% 0/5 0% vs 2% lift 0.0 · >=2% 0/5 0% vs 0% lift ? (NOT PROVEN (n = 5))
- engine note 1945: 22 names a day; top-5 by score / points: AUROPHARMA PE 19:45, CIPLA PE 19:45, DRREDDY PE 19:45, LUPIN PE 19:45, SUNPHARMA PE 19:45 → >=1% 0/5 0% vs 2% lift 0.0 · >=2% 0/5 0% vs 0% lift ? (NOT PROVEN (n = 5))
- go now / get ready (any lane): 257 names a day; top-5 by AI priority: APLAPOLLO PE 09:17, ENRIN PE 09:17, MANKIND CE 09:42, CAMS CE 09:58, TRENT CE 09:45 → >=1% 0/5 0% vs 23% lift 0.0 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- news row (C3, silent): 22 names a day; top-5 by score / points: VEDL PE 09:00, SYRMA CE 09:20, AMBER CE 09:20, KAYNES PE 09:20, MUTHOOTFIN PE 10:08 → >=1% 1/5 20% vs 20% lift 1.0 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 18 names a day; top-5 by list order: WAAREEENER CE 07:15, KALYANKJIL CE 22:45, TMPV CE 07:15, MUTHOOTFIN PE 09:08, ALKEM PE 09:08 → >=1% 2/5 40% vs 33% lift 1.2 · >=2% 0/5 0% vs 16% lift 0.0 (NOT PROVEN (n = 5))
- ALL: 277 names a day; top-5 by AI priority: APLAPOLLO PE 09:17, ENRIN PE 09:17, MANKIND CE 09:42, CAMS CE 09:58, TRENT CE 09:45 → >=1% 0/5 0% vs 23% lift 0.0 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- OLD system: 288 names a day; top-5 by list order: ADANIENSOL PE 09:15, APLAPOLLO PE 09:15, BAJAJ-AUTO CE 09:15, BEL PE 09:15, BLUESTARCO CE 09:15 → >=1% 0/5 0% vs 23% lift 0.0 · >=2% 0/5 0% vs 11% lift 0.0 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: none (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 18 names here = 18 in its own EDGE block; 2%+ its way: 1 by 15:10 (theirs) / 1 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-20 (C_replays) (<server>/girdata/review/monday/C_replays/2026-11-20, edge.rows); news calls (C3): <server>/girdata/review/monday/C_replays/2026-11-20/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.


## Coverage of the movers (not the goal)
42 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 0 | 14 | 27 | 1 |
| v2 cards + WATCH | 4 | 36 | 0 | 2 |
| old system | 20 | 22 | 0 | 0 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 40 crossed 3%; in time 40, late 0, missed 0.


## Rings (phone alarms)
19 rings; 4 of them 09:15-09:45. By hour: 09 h 5, 10 h 4, 11 h 3, 12 h 3, 13 h 2, 14 h 2.

## The AI
AI state: ON. AI decided 1126 of 1241 (91%) of the GO NOW / GET READY triage rows.
Rules rows: 1033 by design (gates, cancels, critical lane), 113 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (976 rows)
- AI failure: below rank floor + AI answer had no lane for this candidate (72 rows)
- by design: critical lane (by design) (24 rows)
- by design: the idea left MUST SEE (by design) (21 rows)
- AI failure: AI answer had no lane for this candidate (17 rows)
- AI failure: below rank floor + AI error no model answered (RuntimeError: stop_reason max_tokens (text 2380 chars)) (11 rows)
- AI failure: below rank floor + AI error no model answered (RuntimeError: stop_reason max_tokens (text 2002 chars)) (6 rows)
- AI failure: below rank floor + AI error no model answered (RuntimeError: stop_reason max_tokens (text 2973 chars)) (4 rows)

387 AI calls, $1.969 in all; the dearest single call $0.0292; 20 errors; stop reasons {'end_turn': 367, 'max_tokens': 10, 'None': 10}.
Cost by kind: final $1.6949, rank $0.0021, second $0.0009, triage $0.2711. Cost by model: routine-tier model $0.2741, final-tier model $1.6949.
Latency: p50 6335 ms, p95 15046 ms, max 20436 ms over 377 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 289, wrong 485, flat 324, not known 0; average move the call's way -0.1%
- after 60 min: right 315, wrong 529, flat 254, not known 0; average move the call's way -0.13%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 19, late 270, the wrong way 26, share did not move 2% 783 (of 1098 new GO NOW / GET READY decisions, 82 of them cards)

## Flags
AI FALLBACK: 18, COST SPIKE: 1, NEWS DIRECTION WRONG: 47
- None AI FALLBACK: AI triage fell back (routine-tier model, max_tokens): stop_reason max_tokens - the engine goes on by its rules
- None AI FALLBACK: AI triage fell back (routine-tier model, None): AI error: RuntimeError: stop_reason max_tokens (text 2200 chars) - the engine goes on by its rules
- None COST SPIKE: AI spend $0.51 in 10 wall-clock minutes (over $0.50), 61 calls to 17:28:16
- 09:33 AI FALLBACK: ADANIENT PE GET READY decided by rules: below rank floor + AI answer had no lane for this candidate
- 09:33 AI FALLBACK: ASHOKLEY PE GET READY decided by rules: AI answer had no lane for this candidate
- 09:45 NEWS DIRECTION WRONG: WIPRO PE GET READY at 09:15 was news-driven; the share went -0.88% against it in 30 min (worst -1.79%)
- 09:46 NEWS DIRECTION WRONG: BHARATFORG PE GET READY at 09:16 was news-driven; the share went -0.50% against it in 30 min (worst -0.50%)
- 09:46 NEWS DIRECTION WRONG: HAL PE GET READY at 09:16 was news-driven; the share went -0.87% against it in 30 min (worst -0.94%)
- 09:46 NEWS DIRECTION WRONG: ASIANPAINT PE GET READY at 09:16 was news-driven; the share went -0.84% against it in 30 min (worst -0.84%)
- 09:46 NEWS DIRECTION WRONG: DLF PE GET READY at 09:16 was news-driven; the share went -1.47% against it in 30 min (worst -1.49%)
- 09:46 NEWS DIRECTION WRONG: HAVELLS PE GET READY at 09:16 was news-driven; the share went -1.28% against it in 30 min (worst -1.43%)
- 09:47 NEWS DIRECTION WRONG: INDIGO PE GET READY at 09:17 was news-driven; the share went -1.34% against it in 30 min (worst -1.34%)
- 09:47 NEWS DIRECTION WRONG: MAZDOCK PE GET READY at 09:17 was news-driven; the share went -1.11% against it in 30 min (worst -1.24%)
- 09:55 NEWS DIRECTION WRONG: WIPRO CE GET READY at 09:25 was news-driven; the share went -0.54% against it in 30 min (worst -0.68%)
- 09:56 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:26 was news-driven; the share went -1.14% against it in 30 min (worst -1.14%)
- 10:03 NEWS DIRECTION WRONG: BAJFINANCE PE GET READY at 09:33 was news-driven; the share went -0.60% against it in 30 min (worst -0.86%)
- 10:03 NEWS DIRECTION WRONG: COFORGE CE GET READY at 09:33 was news-driven; the share went -1.20% against it in 30 min (worst -1.41%)
- 10:03 AI FALLBACK: CROMPTON PE GET READY decided by rules: below rank floor + AI error no model answered (RuntimeError: stop_reason max_tokens (text 2002 chars))
- 10:03 AI FALLBACK: ZYDUSLIFE PE GET READY decided by rules: AI error no model answered (RuntimeError: stop_reason max_tokens (text 2002 chars))
- 10:16 NEWS DIRECTION WRONG: VEDL PE GET READY at 09:16 was news-driven; the share went -0.55% against it in 60 min (worst -0.55%)
- 10:18 NEWS DIRECTION WRONG: DABUR CE GET READY at 09:48 was news-driven; the share went -0.75% against it in 30 min (worst -0.76%)
- 10:18 NEWS DIRECTION WRONG: SONACOMS PE GET READY at 09:48 was news-driven; the share went -0.60% against it in 30 min (worst -0.82%)
- 10:25 NEWS DIRECTION WRONG: AMBUJACEM CE GET READY at 09:55 was news-driven; the share went -0.59% against it in 30 min (worst -0.99%)
- 10:26 NEWS DIRECTION WRONG: DLF CE GET READY at 09:56 was news-driven; the share went -0.68% against it in 30 min (worst -0.89%)
- 10:37 NEWS DIRECTION WRONG: HINDPETRO PE GET READY at 09:37 was news-driven; the share went -0.84% against it in 60 min (worst -1.03%)
- 10:51 NEWS DIRECTION WRONG: BPCL PE GET READY at 09:51 was news-driven; the share went -0.54% against it in 60 min (worst -0.54%)
- 10:54 NEWS DIRECTION WRONG: NTPC PE GET READY at 10:24 was news-driven; the share went -0.71% against it in 30 min (worst -0.83%)
- 11:03 NEWS DIRECTION WRONG: TATAPOWER PE GET READY at 10:03 was news-driven; the share went -0.53% against it in 60 min (worst -0.61%)
- 11:08 NEWS DIRECTION WRONG: WIPRO CE GET READY at 10:38 was news-driven; the share went -0.61% against it in 30 min (worst -0.61%)
- 11:10 NEWS DIRECTION WRONG: ONGC PE GET READY at 10:40 was news-driven; the share went -0.57% against it in 30 min (worst -0.58%)
- 11:24 NEWS DIRECTION WRONG: BANKBARODA PE GET READY at 10:24 was news-driven; the share went -0.66% against it in 60 min (worst -0.66%)
- 11:31 AI FALLBACK: DELHIVERY CE GET READY decided by rules: AI answer had no lane for this candidate (4 more such rows since the last flag)
- 11:31 AI FALLBACK: INOXWIND PE GET READY decided by rules: below rank floor + AI answer had no lane for this candidate (24 more such rows since the last flag)
- 11:45 NEWS DIRECTION WRONG: MUTHOOTFIN PE GET READY at 11:15 was news-driven; the share went -0.50% against it in 30 min (worst -0.57%)
- 11:47 NEWS DIRECTION WRONG: MAXHEALTH CE GET READY at 10:47 was news-driven; the share went -0.56% against it in 60 min (worst -0.61%)
- 11:48 AI FALLBACK: ASTRAL PE GET READY decided by rules: below rank floor + AI error no model answered (RuntimeError: stop_reason max_tokens (text 2380 chars)) (9 more such rows since the last flag)
- 11:48 AI FALLBACK: INFY CE GET READY decided by rules: AI error no model answered (RuntimeError: stop_reason max_tokens (text 2380 chars))
- 11:53 NEWS DIRECTION WRONG: MAXHEALTH CE GET READY at 11:23 was news-driven; the share went -0.70% against it in 30 min (worst -0.83%)
- 11:55 NEWS DIRECTION WRONG: LICHSGFIN PE GET READY at 11:25 was news-driven; the share went -0.71% against it in 30 min (worst -0.75%)
- 11:56 NEWS DIRECTION WRONG: PERSISTENT CE GET READY at 11:26 was news-driven; the share went -0.90% against it in 30 min (worst -1.06%)
- ... 26 more in flags.jsonl

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
