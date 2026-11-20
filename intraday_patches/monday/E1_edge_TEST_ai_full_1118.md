# EDGE - TEST_ai_full_1118 (2026-11-18, replay)

Made 2026-11-20 17:52:47 IST by v2/testobs/edge.py (run by the TEST OBSERVER at the scorecard; by hand: observer.py --edge <run folder>). The goal is the EDGE: how precise and how early GIR's names are. Catching every 2% mover is coverage, not the goal.

**In one line:** EDGE TEST_ai_full_1118 2026-11-18: 210 names (110 knowledge-driven) · 2% to close: all 15/210 = 7% vs base 8% → lift 0.88; knowledge 9/110 = 8% vs base 9% → lift 0.96 · old system 21/293 = 7% vs base 8% → lift 0.88 (293 names)

## EDGE - precision and earliness of GIR's names (the goal)

Every share + side GIR named on 2026-11-18, scored from the price when it was named (before 09:15 = the 09:15 open, the first tradable price). Hit = moved the named way by 1% / 2% to the close (and to the next close, 2026-11-19 known for 218 shares). Base rate = how many of the 218 F&O shares did as much the same way from the same minute; lift = hit rate / base rate (1.0 = no edge). Groups with n < 30 are NOT PROVEN.

| group | n | 1% to close | 2% to close | 2% to next close | wrong side 2% | proof |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 210 | 49/210 = 23% vs base 27% → lift 0.85 | 15/210 = 7% vs base 8% → lift 0.88 | 32/210 = 15% vs base 11% → lift 1.35 | 12 (6%) | n >= 30 |
| KNOWLEDGE-driven names (any source but price-only) | 110 | 29/110 = 26% vs base 29% → lift 0.91 | 9/110 = 8% vs base 9% → lift 0.96 | 30/110 = 27% vs base 14% → lift 2.02 | 7 (6%) | n >= 30 |
| channel: card (MUST SEE / CRITICAL) | 4 | 0/4 = 0% vs base 24% → lift 0.0 | 0/4 = 0% vs base 8% → lift 0.0 | 0/4 = 0% vs base 11% → lift 0.0 | 1 (25%) | NOT PROVEN (n < 30) |
| channel: engine note 0715 | 37 | 10/37 = 27% vs base 24% → lift 1.1 | 4/37 = 11% vs base 7% → lift 1.46 | 15/37 = 40% vs base 17% → lift 2.37 | 6 (16%) | n >= 30 |
| channel: engine note 1945 | 56 | 14/56 = 25% vs base 28% → lift 0.91 | 5/56 = 9% vs base 8% → lift 1.07 | 22/56 = 39% vs base 16% → lift 2.42 | 5 (9%) | n >= 30 |
| channel: go now / get ready (any lane) | 169 | 45/169 = 27% vs base 28% → lift 0.94 | 13/169 = 8% vs base 8% → lift 0.92 | 18/169 = 11% vs base 9% → lift 1.17 | 4 (2%) | n >= 30 |
| channel: prediction loop (lists, fired movers) | 9 | 2/9 = 22% vs base 24% → lift 0.91 | 2/9 = 22% vs base 8% → lift 2.76 | 1/9 = 11% vs base 16% → lift 0.71 | 4 (44%) | NOT PROVEN (n < 30) |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (5 share + side marked) | 105 | 28/105 = 27% vs base 30% → lift 0.89 | 9/105 = 9% vs base 9% → lift 0.97 | 25/105 = 24% vs base 13% → lift 1.82 | 7 (7%) | n >= 30 |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 32 | 9/32 = 28% vs base 27% → lift 1.03 | 4/32 = 12% vs base 8% → lift 1.52 | 10/32 = 31% vs base 16% → lift 1.91 | 6 (19%) | n >= 30 |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 51 | 13/51 = 26% vs base 30% → lift 0.86 | 5/51 = 10% vs base 9% → lift 1.1 | 17/51 = 33% vs base 16% → lift 2.12 | 5 (10%) | n >= 30 |
| source: trader read | 2 | 2/2 = 100% vs base 42% → lift 2.36 | 1/2 = 50% vs base 13% → lift 3.82 | 1/2 = 50% vs base 13% → lift 3.96 | 0 (0%) | NOT PROVEN (n < 30) |
| source: filing | 0 | - | - | - | - | none named |
| source: results | 1 | 1/1 = 100% vs base 43% → lift 2.32 | 0/1 = 0% vs base 13% → lift 0.0 | 0/1 = 0% vs base 12% → lift 0.0 | 0 (0%) | NOT PROVEN (n < 30) |
| source: TV | 0 | - | - | - | - | none named |
| source: broker call | 14 | 1/14 = 7% vs base 29% → lift 0.25 | 0/14 = 0% vs base 9% → lift 0.0 | 2/14 = 14% vs base 13% → lift 1.12 | 0 (0%) | NOT PROVEN (n < 30) |
| source: news | 17 | 10/17 = 59% vs base 25% → lift 2.39 | 4/17 = 24% vs base 7% → lift 3.54 | 5/17 = 29% vs base 8% → lift 3.48 | 0 (0%) | NOT PROVEN (n < 30) |
| source: sector chain / driver link | 76 | 15/76 = 20% vs base 29% → lift 0.67 | 4/76 = 5% vs base 9% → lift 0.6 | 22/76 = 29% vs base 15% → lift 1.96 | 7 (9%) | n >= 30 |
| source: price-only | 100 | 20/100 = 20% vs base 26% → lift 0.78 | 6/100 = 6% vs base 8% → lift 0.79 | 2/100 = 2% vs base 9% → lift 0.23 | 5 (5%) | n >= 30 |
| OLD system (tomorrow.db alerts of 2026-11-18 from 09:00) - comparison only | 293 | 76/293 = 26% vs base 27% → lift 0.96 | 21/293 = 7% vs base 8% → lift 0.88 | 37/293 = 13% vs base 14% → lift 0.87 | 14 (5%) | n >= 30 |
| OLD system source: TV | 3 | 1/3 = 33% vs base 23% → lift 1.43 | 1/3 = 33% vs base 7% → lift 4.95 | 1/3 = 33% vs base 14% → lift 2.45 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: broker call | 34 | 7/34 = 21% vs base 24% → lift 0.86 | 2/34 = 6% vs base 7% → lift 0.82 | 7/34 = 21% vs base 15% → lift 1.41 | 3 (9%) | n >= 30 |
| OLD system source: filing | 30 | 11/30 = 37% vs base 32% → lift 1.14 | 2/30 = 7% vs base 10% → lift 0.68 | 2/30 = 7% vs base 15% → lift 0.45 | 2 (7%) | n >= 30 |
| OLD system source: news | 92 | 20/92 = 22% vs base 24% → lift 0.89 | 4/92 = 4% vs base 7% → lift 0.59 | 13/92 = 14% vs base 16% → lift 0.9 | 5 (5%) | n >= 30 |
| OLD system source: price-only | 9 | 1/9 = 11% vs base 23% → lift 0.49 | 0/9 = 0% vs base 7% → lift 0.0 | 1/9 = 11% vs base 15% → lift 0.74 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: results | 112 | 30/112 = 27% vs base 30% → lift 0.89 | 10/112 = 9% vs base 9% → lift 0.99 | 9/112 = 8% vs base 14% → lift 0.59 | 4 (4%) | n >= 30 |
| OLD system source: sector chain / driver link | 10 | 3/10 = 30% vs base 15% → lift 1.97 | 0/10 = 0% vs base 4% → lift 0.0 | 2/10 = 20% vs base 14% → lift 1.43 | 0 (0%) | NOT PROVEN (n < 30) |
| OLD system source: trader read | 3 | 3/3 = 100% vs base 42% → lift 2.36 | 2/3 = 67% vs base 13% → lift 5.13 | 2/3 = 67% vs base 12% → lift 5.81 | 0 (0%) | NOT PROVEN (n < 30) |

### Earliness (names whose share moved 2%+ its way by the close; onset = score.py 'began')

| group | moved 2%+ its way | named before the move began | named before the open | median lead (min) | median move left after the name | median share of the day's range left |
|---|---|---|---|---|---|---|
| ALL names (first naming of each share + side, any channel) | 47 | 19 | 12 | -4 | +1.73% | 51% |
| KNOWLEDGE-driven names (any source but price-only) | 25 | 15 | 10 | 1 | +1.87% | 52% |
| channel: engine note 0715 | 7 | 7 | 7 | 1 | +1.99% | 54% |
| channel: engine note 1945 | 11 | 11 | 11 | 1 | +1.92% | 56% |
| channel: go now / get ready (any lane) | 46 | 18 | 2 | -4.0 | +1.73% | 50.5% |
| channel: prediction loop (lists, fired movers) | 2 | 1 | 1 | -4.5 | +3.40% | 76.0% |
| KNOWLEDGE-driven names WITHOUT the LEAKAGE names (5 share + side marked) | 25 | 15 | 10 | 1 | +1.87% | 52% |
| channel: engine note 0715 WITHOUT the LEAKAGE names | 7 | 7 | 7 | 1 | +1.99% | 54% |
| channel: engine note 1945 WITHOUT the LEAKAGE names | 11 | 11 | 11 | 1 | +1.92% | 56% |
| source: trader read | 2 | 1 | 0 | -2.0 | +2.83% | 53.0% |
| source: broker call | 3 | 1 | 0 | -1 | +0.98% | 42% |
| source: news | 8 | 1 | 0 | -80.0 | +2.02% | 47.5% |
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

- card (MUST SEE / CRITICAL): 4 names; top-5 by engine rank: CDSL CE 09:24, IRFC PE 09:27, ASTRAL PE 09:28, MFSL PE 09:35 → 0 of 4 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 4))
- engine note 0715: 37 names; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, VEDL PE 09:00, AMBER CE 09:00 → 4 of 5 moved 1%+ its way, 1 moved 2%+ (NOT PROVEN (n = 5))
- engine note 1945: 56 names; top-5 by score / points: HINDZINC PE 09:00, NATIONALUM PE 09:00, HINDALCO PE 09:00, JINDALSTEL PE 09:00, JSWSTEEL PE 09:00 → 4 of 5 moved 1%+ its way, 0 moved 2%+ (NOT PROVEN (n = 5))
- go now / get ready (any lane): 169 names; top-5 by engine rank: NMDC PE 09:26, CDSL CE 09:24, HINDPETRO PE 10:34, LICI PE 09:43, ANGELONE PE 11:24 → 1 of 5 moved 1%+ its way, 1 moved 2%+ (NOT PROVEN (n = 5))
- prediction loop (lists, fired movers): 9 names; top-5 by list order: TMPV CE 19:45, DIXON PE 19:45, PIIND CE 19:45, ASHOKLEY PE 09:19, KALYANKJIL PE 09:26 → 2 of 5 moved 1%+ its way, 2 moved 2%+ (NOT PROVEN (n = 5))
- ALL: 210 names; top-5 by engine rank: NMDC PE 09:26, CDSL CE 09:24, HINDPETRO PE 10:34, LICI PE 09:43, ANGELONE PE 11:24 → 1 of 5 moved 1%+ its way, 1 moved 2%+ (NOT PROVEN (n = 5))
- OLD system: 293 names; top-5 by list order: MCX PE 09:01, ONGC PE 09:08, MANAPPURAM PE 09:08, HINDZINC PE 09:08, ADANIENSOL CE 09:15 → 3 of 5 moved 1%+ its way, 1 moved 2%+ (NOT PROVEN (n = 5))

### The engine note: leakage and the honest check

- LEAKAGE-marked note names on this day: AMBER CE, BLUESTARCO CE, CROMPTON CE, PGEL CE, VOLTAS CE (an engine-note name whose chain is marked LEAKAGE in v2/kb/chains.json (X19 / links_extra, added 19 Nov after the 19 Nov rally) on a replayed day up to 19 Nov).
- The KB's links were partly written after the past days they are tested on, so a note's lift on a replayed day may be flattered. The honest check is the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction loop cross-check: 9 names here = 9 in its own EDGE block; 2%+ its way: 2 by 15:10 (theirs) / 2 by the close (here). same names, times and sources as the prediction loop's EDGE block; it measures to 15:10, this scorecard to the close.

Inputs: prediction-loop names: the prediction loop's point-in-time replay of 2026-11-18 (C_replays) (/home/globalbot/girdata/review/monday/C_replays/2026-11-18, edge.rows); news calls (C3): /home/globalbot/girdata/review/monday/C_replays/2026-11-18/store/news_calls.jsonl

Closes: Kite daily close (girdata/history) 218.

## Coverage of the movers (not the goal)

TEST_ai_full_1118 2026-11-18: catch cards 0 / 0 / 53 / 0 · cards+WATCH 13 / 31 / 8 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 24, late 1, missed 5 · rings 7 (09:15-09:45 7) · AI 1462 of 1462 (100%), $0.027, 73 calls · flags MISSED MOVER 6, NOISE 1, NEWS DIRECTION WRONG 19

## Caveats

- Groups with n < 30 are NOT PROVEN; a lift of 0 or a top-5 on 5 names says nothing on its own.
- Engine note / knowledge names: the KB (v2/kb/chains.json, LINK_BOOK, COPPER_LINKS) was partly written after these days; X19 and links_extra (added 19 Nov) are marked LEAKAGE and the note's lift is shown with and without them when present. the KB's blind multi-date test (v2/kb/BLIND_TESTS.md): named shares moved their way the next day 221 of 459 (48%) - a coin gives about 50%.
- Prediction-loop names are the prediction builder's own (C_replays / v2/data/predict scorecard edge rows: MOVER only once its trigger fired, named at that minute; its source and rank as given). It scores to 15:10; this file to the close.
- Prices: GIR's minute series (Kite minute > optrec > oihist > recorder) and the Kite daily closes (girdata/history); a missing input says 'not known'.
