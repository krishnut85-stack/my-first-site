# TEST OBSERVER scorecard - LIVE_2026-11-20 (replayed day 2026-11-20)

Made 2026-11-20 15:50:30 IST by v2/testobs/observer.py. Run folder: `<server>/intraday/v2/data`. Done because: end of the live day (15:40 IST).

## In one line
LIVE_2026-11-20 2026-11-20: catch cards 0 / 10 / 32 / 0 · cards+WATCH 0 / 17 / 15 / 10 · old 13 / 29 / 0 / 0 (before/late/missed/wrong, 2%+) · 3% movers 40: in time 14, late 12, missed 14 · rings 75 (09:15-09:45 7) · AI 917 of 917 (100%), $0.178, 173 calls · flags MISSED MOVER 26, NEWS DIRECTION WRONG 40, NOISE 4

## Did it catch the movers?
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
