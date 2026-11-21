# EDGE - TEST_ai_full3_1116 (2026-11-16, replay)

Made 2026-11-20 18:38:10 IST by v2/testobs/edge.py (run by the TEST OBSERVER at the scorecard; by hand: observer.py --edge <run folder>). The goal is the EDGE: how precise and how early GIR's names are. Catching every 2% mover is coverage, not the goal.

**In one line:** EDGE TEST_ai_full3_1116 2026-11-16: 109 names a day (55 knowledge-driven) · TOP-5 by the engine's own rank (no analyst ideas in this run): >=1% 0/5 0% vs 6% lift 0.0, >=2% 0/5 0% vs 1% lift 0.0 · all names >=1% 21/109 19% vs 16% lift 1.21, >=2% 12/109 11% vs 6% lift 1.88 · knowledge >=2% 7/55 13% vs 8% lift 1.6 · all names >=2% to the next close 17/109 16% vs 12% lift 1.24 · old system >=2% 16/167 10% vs 7% lift 1.43 (167 names)

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-16, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-17 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 109 | 21/109 = 19% vs base 16% → lift 1.21 | 12/109 = 11% vs base 6% → lift 1.88 | 17/109 = 16% vs base 12% → lift 1.24 | 3 (3%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 55 | 13/55 = 24% vs base 20% → lift 1.17 | 7/55 = 13% vs base 8% → lift 1.6 | 8/55 = 14% vs base 16% → lift 0.93 | 0 (0%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 47 | 9/47 = 19% vs base 10% → lift 1.96 | 5/47 = 11% vs base 3% → lift 3.99 | 7/47 = 15% vs base 8% → lift 1.78 | 0 (0%) | n >= 30 |
| channel: engine note 0715 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: engine note 1945 | 33 | 10/33 = 30% vs base 25% → lift 1.19 | 6/33 = 18% vs base 11% → lift 1.7 | 5/33 = 15% vs base 20% → lift 0.77 | 0 (0%) | n >= 30 |
| channel: go now / get ready (any lane) | 80 | 15/80 = 19% vs base 12% → lift 1.56 | 9/80 = 11% vs base 4% → lift 2.94 | 13/80 = 16% vs base 10% → lift 1.71 | 3 (4%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 6 | 0/6 = 0% vs base 19% → lift 0.0 | 0/6 = 0% vs base 7% → lift 0.0 | 2/6 = 33% vs base 14% → lift 2.33 | 0 (0%) | NOT PROVEN (n < 30) |
| source: trader read | 1 | 0/1 = 0% vs base 7% → lift 0.0 | 0/1 = 0% vs base 3% → lift 0.0 | 0/1 = 0% vs base 6% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 0 | - | - | - | - | none named |
| source: results | 3 | 0/3 = 0% vs base 15% → lift 0.0 | 0/3 = 0% vs base 5% → lift 0.0 | 0/3 = 0% vs base 12% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 0 | - | - | - | - | none named |
| source: broker call | 2 | 2/2 = 100% vs base 25% → lift 3.96 | 1/2 = 50% vs base 9% → lift 5.74 | 2/2 = 100% vs base 17% → lift 5.81 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 12 | 0/12 = 0% vs base 10% → lift 0.0 | 0/12 = 0% vs base 3% → lift 0.0 | 1/12 = 8% vs base 8% → lift 1.02 | 0 (0%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 37 | 11/37 = 30% vs base 24% → lift 1.25 | 6/37 = 16% vs base 10% → lift 1.64 | 5/37 = 14% vs base 18% → lift 0.73 | 0 (0%) | n >= 30 |
| source: price-only | 54 | 8/54 = 15% vs base 12% → lift 1.27 | 5/54 = 9% vs base 4% → lift 2.48 | 9/54 = 17% vs base 9% → lift 1.77 | 3 (6%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-16 from 09:00) - comparison only | 167 | 39/167 = 23% vs base 18% → lift 1.3 | 16/167 = 10% vs base 7% → lift 1.43 | 27/167 = 16% vs base 15% → lift 1.09 | 15 (9%) | n >= 30 |
| OLD system source: broker call | 20 | 3/20 = 15% vs base 18% → lift 0.84 | 0/20 = 0% vs base 7% → lift 0.0 | 3/20 = 15% vs base 16% → lift 0.96 | 2 (10%) | NOT PROVEN (n < 30) |
| OLD system source: filing | 5 | 2/5 = 40% vs base 16% → lift 2.58 | 1/5 = 20% vs base 5% → lift 3.89 | 2/5 = 40% vs base 12% → lift 3.3 | 1 (20%) | NOT PROVEN (n < 30) |
| OLD system source: news | 60 | 16/60 = 27% vs base 18% → lift 1.5 | 7/60 = 12% vs base 7% → lift 1.74 | 5/60 = 8% vs base 15% → lift 0.55 | 5 (8%) | n >= 30 |
| OLD system source: price-only | 28 | 6/28 = 21% vs base 22% → lift 0.99 | 3/28 = 11% vs base 8% → lift 1.31 | 5/28 = 18% vs base 15% → lift 1.17 | 2 (7%) | NOT PROVEN (n < 30) |
| OLD system source: results | 27 | 6/27 = 22% vs base 21% → lift 1.08 | 3/27 = 11% vs base 8% → lift 1.39 | 4/27 = 15% vs base 16% → lift 0.93 | 4 (15%) | NOT PROVEN (n < 30) |
| OLD system source: sector chain / driver link | 23 | 3/23 = 13% vs base 10% → lift 1.27 | 0/23 = 0% vs base 3% → lift 0.0 | 5/23 = 22% vs base 11% → lift 1.93 | 1 (4%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 4 | 3/4 = 75% vs base 26% → lift 2.86 | 2/4 = 50% vs base 10% → lift 5.07 | 3/4 = 75% vs base 19% → lift 3.94 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 34 | 9 | 9 | -24.0 | +1.20% | 35.0% |
| KNOWLEDGE-driven names (any source but price-only) | 15 | 9 | 9 | 1 | +1.92% | 51% |
| channel: card (MUST SEE / CRITICAL) | 23 | 1 | 0 | -95 | +0.46% | 9% |
| channel: engine note 0715 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: engine note 1945 | 9 | 9 | 9 | 1 | +2.53% | 59% |
| channel: go now / get ready (any lane) | 31 | 2 | 0 | -47 | +0.68% | 20% |
| channel: prediction loop (lists, fired movers) | 2 | 0 | 0 | -24.0 | -0.05% | -0.5% |
| source: trader read | 1 | 0 | 0 | -91 | +0.61% | 7% |
| source: results | 2 | 0 | 0 | -43.5 | -1.13% | -16.5% |
| source: broker call | 2 | 0 | 0 | -20.5 | +3.66% | 53.5% |
| source: news | 1 | 0 | 0 | -130 | -0.53% | -16% |
| source: sector chain / driver link | 9 | 9 | 9 | 1 | +2.53% | 59% |
| source: price-only | 19 | 0 | 0 | -42 | +0.68% | 21% |
| OLD system (tomorrow.db alerts of 2026-11-16 from 09:00) - comparison only | 43 | 12 | 0 | -1 | +1.44% | 45% |
| OLD system source: broker call | 4 | 3 | 0 | 1.5 | +1.11% | 36.5% |
| OLD system source: filing | 1 | 0 | 0 | -2 | +3.50% | 71% |
| OLD system source: news | 20 | 5 | 0 | -7.0 | +1.66% | 52.0% |
| OLD system source: price-only | 6 | 1 | 0 | -2.5 | +2.87% | 68.0% |
| OLD system source: results | 7 | 2 | 0 | 0 | +1.38% | 26% |
| OLD system source: sector chain / driver link | 2 | 0 | 0 | -147.0 | -0.06% | -0.5% |
| OLD system source: trader read | 3 | 1 | 0 | 0 | +1.00% | 25% |

### Names a day and the TOP-5

- **THE DAY'S TOP-5 (the engine's own rank (no analyst ideas in this run), by engine rank): MUTHOOTFIN PE 11:26, MOTILALOFS PE 14:08, TCS PE 14:23, KEI PE 10:21, JIOFIN PE 12:24 → >=1% 0/5 0% vs 6% lift 0.0 · >=2% 0/5 0% vs 1% lift 0.0 · next close >=2% 1/5 20% vs 6% lift 3.25 (NOT PROVEN (n = 5))**
- card (MUST SEE / CRITICAL): 47 names a day; top-5 by engine rank: VEDL PE 10:52, KAYNES PE 09:24, PGEL PE 09:30, AMBER PE 13:41, SAIL PE 13:45 → >=1% 2/5 40% vs 12% lift 3.21 · >=2% 2/5 40% vs 4% lift 9.08 (NOT PROVEN (n = 5))
- engine note 0715: 33 names a day; top-5 by score / points: BAJFINANCE PE 09:00, HDFCBANK PE 09:00, SBIN PE 09:00, AXISBANK PE 09:00, ICICIBANK PE 09:00 → >=1% 0/5 0% vs 30% lift 0.0 · >=2% 0/5 0% vs 12% lift 0.0 (NOT PROVEN (n = 5))
- engine note 1945: 33 names a day; top-5 by score / points: BAJFINANCE PE 09:00, HDFCBANK PE 09:00, SBIN PE 09:00, AXISBANK PE 09:00, ICICIBANK PE 09:00 → >=1% 0/5 0% vs 30% lift 0.0 · >=2% 0/5 0% vs 12% lift 0.0 (NOT PROVEN (n = 5))
- go now / get ready (any lane): 80 names a day; top-5 by engine rank: VEDL PE 10:52, AMBER PE 13:41, JINDALSTEL PE 11:18, MUTHOOTFIN PE 11:26, SYRMA PE 11:01 → >=1% 0/5 0% vs 6% lift 0.0 · >=2% 0/5 0% vs 2% lift 0.0 (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 6 names a day; top-5 by list order: PIIND CE 19:45, CUMMINSIND PE 10:41, MANAPPURAM PE 09:18, ABB PE 09:26, COCHINSHIP PE 09:18 → >=1% 0/5 0% vs 21% lift 0.0 · >=2% 0/5 0% vs 8% lift 0.0 (NOT PROVEN (n = 5))
- ALL: 109 names a day; top-5 by engine rank: MUTHOOTFIN PE 11:26, MOTILALOFS PE 14:08, TCS PE 14:23, KEI PE 10:21, JIOFIN PE 12:24 → >=1% 0/5 0% vs 6% lift 0.0 · >=2% 0/5 0% vs 1% lift 0.0 (NOT PROVEN (n = 5))
- OLD system: 167 names a day; top-5 by list order: NATIONALUM PE 09:16, AXISBANK CE 09:16, PNB CE 09:16, TMPV PE 09:16, ABB PE 09:16 → >=1% 1/5 20% vs 24% lift 0.84 · >=2% 0/5 0% vs 10% lift 0.0 (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: none (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 6 names here = 6 in its own EDGE block; 2%+ its way: 0 by 15:10 (theirs) / 0 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-16 (C_replays) (/home/globalbot/girdata/review/monday/C_replays/2026-11-16, edge.rows); news calls (C3): /home/globalbot/girdata/review/monday/C_replays/2026-11-16/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.

## Coverage of the movers (not the goal)

TEST_ai_full3_1116 2026-11-16: catch cards 1 / 22 / 31 / 0 · cards+WATCH 1 / 30 / 23 / 0 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 16, late 7, missed 14 · rings 73 (09:15-09:45 7) · AI 414 of 414 (100%), $0.131, 172 calls · flags MISSED MOVER 21, NEWS DIRECTION WRONG 21, NOISE 6

## Caveats

- Groups with n < 30 are NOT PROVEN; a lift of 0 or a top-5 on 5 names says nothing on its own.
- Engine note / knowledge names: the KB (v2/kb/chains.json, LINK_BOOK, COPPER_LINKS) was partly written after these days; X19 and links_extra (added 19 Nov) are marked LEAKAGE and the note's lift is shown with and without them when present. the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction-loop names are the prediction builder's own (C_replays / v2/data/predict scorecard edge rows: MOVER only once its trigger fired, named at that minute; its source and rank as given). It scores to 15:10; this file to the close.
- Prices: GIR's minute series (Kite minute > optrec > oihist > recorder) and the Kite daily closes (girdata/history); a missing input says 'not known'.
