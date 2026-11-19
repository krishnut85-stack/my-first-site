# TEST OBSERVER scorecard - TEST_ai_full3_1116 (replayed day 2026-11-16)

Made 2026-11-19 21:16:51 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full3_1116`. Done because: run.json written by the player (the day's end).

## In one line
TEST_ai_full3_1116 2026-11-16: catch cards 1 / 22 / 31 / 0 · cards+WATCH 1 / 30 / 23 / 0 · old 22 / 21 / 10 / 1 (before/late/missed/wrong, 2%+) · 3% movers 37: in time 16, late 7, missed 14 · rings 73 (09:15-09:45 7) · AI 414 of 414 (100%), $0.131, 172 calls · flags MISSED MOVER 21, NEWS DIRECTION WRONG 21, NOISE 6

## Did it catch the movers?
54 F&O shares moved 2%+ at the close. Counted as before / late / missed / wrong (run_report.py rules):

| who | before | late | missed | wrong |
|---|---|---|---|---|
| v2 cards (MUST SEE + CRITICAL) | 1 | 22 | 31 | 0 |
| v2 cards + WATCH | 1 | 30 | 23 | 0 |
| old system | 22 | 21 | 10 | 1 |

3%+ movers (the observer's MISSED MOVER rule - a CE / PE call that way in MUST SEE / CRITICAL or GO NOW / GET READY at or before the minute it crossed 3%): 37 crossed 3%; in time 16, late 7, missed 14.

### Top missed / late 3% movers and what the engine said

| share | crossed 3% | close % | v2 | old system (2% rule) | what the engine said |
|---|---|---|---|---|---|
| TMPV | 09:16 DOWN | -8.7 | LATE 10:47 | BEFORE | first 10:47 PE GET READY WATCH (AI) · best 12:43 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 14:24 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| LAURUSLABS | 10:34 DOWN | -8.42 | LATE 11:30 | LATE | first 11:30 PE GET READY WATCH (AI) · best 11:30 PE GET READY WATCH (AI) · last 13:01 PE nothing LOG (rules): cancelled: the GET READY call from 12:53 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| AMBER | 09:16 DOWN | -7.68 | LATE 13:41 | BEFORE | first 13:41 PE GET READY MUST SEE (AI) · best 13:41 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 13:41 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| INOXWIND | 09:16 DOWN | -7.68 | LATE 10:27 | BEFORE | first 10:27 PE GET READY MUST SEE (AI) · best 10:27 PE GET READY MUST SEE (AI) · last 14:30 PE nothing MUST SEE (rules): cancelled: the GET READY call from 12:45 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| PATANJALI | 12:08 DOWN | -4.82 | MISSED | LATE | nothing on this share |
| TATACONSUM | 12:26 UP | 3.57 | MISSED | BEFORE | nothing on this share |
| ITC | 10:16 UP | 3.54 | MISSED | LATE | nothing on this share |
| LICHSGFIN | 14:18 UP | 3.49 | MISSED | LATE | nothing on this share |
| NATIONALUM | 14:00 DOWN | -3.35 | MISSED | BEFORE | nothing on this share |
| DIVISLAB | 13:01 DOWN | -3.16 | LATE 14:21 | MISSED | first 14:21 PE GET READY WATCH (AI) · best 14:21 PE GET READY WATCH (AI) · last 14:30 PE nothing LOG (rules): cancelled: the GET READY call from 14:21 no longer holds (price left the trigger zone, the sector faded, or the score f… |
| CUMMINSIND | 10:20 DOWN | -3.11 | LATE 10:55 | BEFORE | first 10:55 PE GET READY MUST SEE (AI) · best 10:55 PE GET READY MUST SEE (AI) · last 12:52 PE nothing MUST SEE (rules): withheld: (g2) long unwinding - sellers running out, tends to bounce (PE lost 64% in 16-day test) |
| KPITTECH | 11:28 DOWN | -2.84 | MISSED | LATE | nothing on this share |
| PAYTM | 14:02 DOWN | -2.53 | MISSED | LATE | nothing on this share |
| ABB | 10:21 DOWN | -2.26 | MISSED | BEFORE | nothing on this share |
| LODHA | 10:51 DOWN | -2.23 | MISSED | LATE | nothing on this share |

## Rings (phone alarms)
73 rings; 7 of them 09:15-09:45. By hour: 09 h 11, 10 h 15, 11 h 8, 12 h 18, 13 h 12, 14 h 9.

## The AI
AI state: ON. AI decided 414 of 414 (100%) of the GO NOW / GET READY triage rows.
Rules rows: 271 by design (gates, cancels, critical lane), 0 because the AI failed or gave no lane.
- by design: cancel of an earlier idea (by design) (223 rows)
- by design: rule veto: (g2) long unwinding - sellers running out, tends to bounce (PE lost 64% in 16-da (29 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (17.61 vs VWAP 1 (3 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (145.7 vs VWAP 1 (2 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (145.45 vs VWAP  (1 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (145.35 vs VWAP  (1 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (2154.9 vs VWAP  (1 rows)
- by design: rule veto: (g) short covering below VWAP - an SC CE needs price above VWAP (304.25 vs VWAP  (1 rows)

172 AI calls, $0.131 in all; the dearest single call $0.0296; 0 errors; stop reasons {'end_turn': 172}.
Cost by kind: final $0.0869, second $0.0033, triage $0.0406. Cost by model: claude-fable-5-2 $0.0869, claude-haiku-5-5 $0.0439.
Latency: p50 1944 ms, p95 3915 ms, max 7157 ms over 172 calls.

## Were the calls right? (share move the option's way after the call; FLAT = under 0.15%)
- after 30 min: right 112, wrong 100, flat 100, not known 0; average move the call's way 0.08%
- after 60 min: right 120, wrong 109, flat 83, not known 0; average move the call's way 0.03%
- early / late on the day's 2%+ movers (whole day, score.py rule): before 3, late 127, the wrong way 0, share did not move 2% 182 (of 312 new GO NOW / GET READY decisions, 107 of them cards)

## Flags
MISSED MOVER: 21, NEWS DIRECTION WRONG: 21, NOISE: 6
- 09:16 MISSED MOVER: AMBER crossed -3.0% at 09:16 (-3.19% vs the previous close) with no PE call by then · the engine said nothing on AMBER by then
- 09:16 MISSED MOVER: EICHERMOT crossed +3.0% at 09:16 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on EICHERMOT by then
- 09:16 MISSED MOVER: INOXWIND crossed -3.0% at 09:16 (-8.15% vs the previous close) with no PE call by then · the engine said nothing on INOXWIND by then
- 09:16 MISSED MOVER: TMPV crossed -3.0% at 09:16 (-7.85% vs the previous close) with no PE call by then · the engine said nothing on TMPV by then
- 09:20 MISSED MOVER: KALYANKJIL crossed +3.0% at 09:20 (+3.13% vs the previous close) with no CE call by then · the engine said nothing on KALYANKJIL by then
- 09:25 MISSED MOVER: ATHERENERG crossed +3.0% at 09:25 (+3.03% vs the previous close) with no CE call by then · the engine said nothing on ATHERENERG by then
- 09:56 NEWS DIRECTION WRONG: SIEMENS PE GET READY at 09:26 was news-driven; the share went -0.55% against it in 30 min (worst -0.55%)
- 10:11 NEWS DIRECTION WRONG: AI second reading said the CE thesis direction was wrong, but FORTIS went +1.43% the thesis way (CE) in 30 min
- 10:13 NEWS DIRECTION WRONG: KAYNES PE GET READY at 09:43 was news-driven; the share went -3.43% against it in 30 min (worst -3.65%)
- 10:15 NEWS DIRECTION WRONG: INDUSTOWER CE GET READY at 09:45 was news-driven; the share went -0.66% against it in 30 min (worst -0.92%)
- 10:16 NEWS DIRECTION WRONG: AI second reading said the CE thesis direction was wrong, but MAXHEALTH went +0.71% the thesis way (CE) in 30 min
- 10:16 MISSED MOVER: ITC crossed +3.0% at 10:16 (+3.00% vs the previous close) with no CE call by then · the engine said nothing on ITC by then
- 10:20 MISSED MOVER: CUMMINSIND crossed -3.0% at 10:20 (-3.90% vs the previous close) with no PE call by then · the engine said nothing on CUMMINSIND by then
- 10:21 MISSED MOVER: ABB crossed -3.0% at 10:21 (-3.15% vs the previous close) with no PE call by then · the engine said nothing on ABB by then
- 10:26 NEWS DIRECTION WRONG: BIOCON CE GET READY at 09:56 was news-driven; the share went -0.50% against it in 30 min (worst -0.57%)
- 10:34 MISSED MOVER: LAURUSLABS crossed -3.0% at 10:34 (-3.21% vs the previous close) with no PE call by then · the engine said nothing on LAURUSLABS by then
- 10:39 NEWS DIRECTION WRONG: PNB CE GET READY at 09:39 was news-driven; the share went -0.75% against it in 60 min (worst -0.75%)
- 10:40 NEWS DIRECTION WRONG: AUROPHARMA CE GET READY at 09:40 was news-driven; the share went -0.66% against it in 60 min (worst -0.74%)
- 10:41 NEWS DIRECTION WRONG: SUNPHARMA CE GET READY at 09:41 was news-driven; the share went -0.75% against it in 60 min (worst -0.79%)
- 10:46 NEWS DIRECTION WRONG: ASIANPAINT CE GET READY at 09:46 was news-driven; the share went -0.65% against it in 60 min (worst -0.65%)
- 10:47 NEWS DIRECTION WRONG: BPCL CE GET READY at 10:17 was news-driven; the share went -0.57% against it in 30 min (worst -0.57%)
- 10:48 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but PREMIERENE went +1.29% the thesis way (PE) in 60 min
- 10:51 MISSED MOVER: LODHA crossed -3.0% at 10:51 (-3.01% vs the previous close) with no PE call by then · the engine said nothing on LODHA by then
- 10:51 MISSED MOVER: SUZLON crossed -3.0% at 10:51 (-3.11% vs the previous close) with no PE call by then · the engine said nothing on SUZLON by then
- 11:06 NOISE: 7 rings in 15 virtual minutes (10:51-11:06), over 6
- 11:13 NEWS DIRECTION WRONG: BPCL CE GET READY at 10:13 was news-driven; the share went -0.75% against it in 60 min (worst -0.77%)
- 11:26 NEWS DIRECTION WRONG: ASIANPAINT CE GET READY at 10:26 was news-driven; the share went -0.64% against it in 60 min (worst -0.68%)
- 11:28 MISSED MOVER: KPITTECH crossed -3.0% at 11:28 (-3.05% vs the previous close) with no PE call by then · the engine said nothing on KPITTECH by then
- 11:31 NEWS DIRECTION WRONG: AI second reading said the PE thesis direction was wrong, but SYRMA went +0.78% the thesis way (PE) in 30 min
- 12:00 NEWS DIRECTION WRONG: LAURUSLABS PE GET READY at 11:30 was news-driven; the share went -0.88% against it in 30 min (worst -1.35%)
- 12:08 MISSED MOVER: PATANJALI crossed -3.0% at 12:08 (-3.11% vs the previous close) with no PE call by then · the engine said nothing on PATANJALI by then
- 12:15 NEWS DIRECTION WRONG: TMPV PE GET READY at 11:15 was news-driven; the share went -0.53% against it in 60 min (worst -0.73%)
- 12:14 MISSED MOVER: SWIGGY crossed +3.0% at 12:14 (+3.13% vs the previous close) with no CE call by then · the engine said nothing on SWIGGY by then
- 12:26 MISSED MOVER: TATACONSUM crossed +3.0% at 12:26 (+3.06% vs the previous close) with no CE call by then · the engine said nothing on TATACONSUM by then
- 12:33 NEWS DIRECTION WRONG: NAM-INDIA PE GET READY at 12:03 was news-driven; the share went -1.09% against it in 30 min (worst -1.15%)
- 12:45 NOISE: 7 rings in 15 virtual minutes (12:30-12:45), over 6
- 12:55 NOISE: 51 rings today by 12:55, over 50 for the day
- 12:57 NOISE: 7 rings in 15 virtual minutes (12:42-12:57), over 6
- 13:01 MISSED MOVER: DIVISLAB crossed -3.0% at 13:01 (-3.17% vs the previous close) with no PE call by then · the engine said nothing on DIVISLAB by then
- 13:25 MISSED MOVER: POLICYBZR crossed -3.0% at 13:25 (-3.05% vs the previous close) with no PE call by then · the engine said nothing on POLICYBZR by then
- ... 8 more in flags.jsonl

Settings: {"noise_rings_15m": 6, "noise_rings_day": 50, "mover_pct": 3.0, "cost_one_usd": 0.05, "cost_10min_usd": 0.5, "day_cap_usd": 5.0, "run_cap_usd": 20.0, "flat_pct": 0.15}
