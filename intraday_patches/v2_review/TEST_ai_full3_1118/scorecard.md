# TEST OBSERVER scorecard - TEST_ai_full3_1118 (replayed day 2026-11-18)

Made 2026-11-19 21:28:16 IST by v2/testobs/observer.py. Run folder: `<server>/girdata/replay/out/TEST_ai_full3_1118`. Done because: run.json written by the player (the day's end).

## In one line
TEST_ai_full3_1118 2026-11-18: catch cards 0 / 9 / 43 / 1 · cards+WATCH 11 / 7 / 34 / 1 · old 35 / 18 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 30: in time 9, late 1, missed 20 · rings 50 (09:15-09:45 12) · AI 245 of 245 (100%), $0.180, 115 calls · flags MISSED MOVER 20, NOISE 1, NEWS DIRECTION WRONG 8

## Did it catch the movers?
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
Cost by kind: final $0.1501, second $0.0039, triage $0.0255. Cost by model: claude-fable-5-2 $0.1501, claude-haiku-5-5 $0.0294.
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
