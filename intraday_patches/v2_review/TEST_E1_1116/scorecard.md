# TEST OBSERVER scorecard - TEST_E1_1116 (replayed day 2026-11-16)

Made 2026-11-20 16:48:17 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_E1_1116`. Done because: run.json written by the player (the day's end).

## In one line
TEST_E1_1116 2026-11-16: catch cards 1 / 19 / 34 / 0 · cards+WATCH 3 / 44 / 6 / 1 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 29, late 5, missed 3 · rings 15 (09:15-09:45 1) · AI 723 of 723 (100%), $0.881, 359 calls · flags MISSED MOVER 8, NEWS DIRECTION WRONG 17

## Did it catch the movers?
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
