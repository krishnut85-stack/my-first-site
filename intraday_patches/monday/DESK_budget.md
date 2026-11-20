# DESK BUDGET ARITHMETIC - can the full roster run inside $5 a day? (20 Nov 20:16 IST)

Measured (not estimated) per-call costs from tonight's shadows (data/desk/shadow/*, ai_calls):
- Sonnet seat card: median **$0.042** (8.5k fresh input incl. the board, the number keys and the output-format frame; 8.6k cache write; 0.9k out).
  The first shadow at 19:29 (smaller inputs) measured $0.029.
- Haiku reader batch (up to 8 items): median **$0.002**.
- Opus (head brief, Connections): no complete answer measured yet (timeouts fixed tonight). Estimate $0.15-0.30 a call [E].
Call counts from the 18 Nov stub rehearsal (one replayed session, FAKE brains, the real schedule): R2 352, R6 356 batches before the R6
code filter, R3 113, R1 79; head 15 looks; seat 15 10; seat 31 9; meeting seats 1-3 each.

## One session day (15:40 -> 15:40), the FULL roster on its schedule
| bucket | cap | what runs | calls | cost |
|---|---|---|---|---|
| SEATS | $0.90 | 30 Sonnet seats (1-14, 16-29, 31, 37) at their meetings (mostly 19:45 + 07:15; 1, 10 also 22:45 / 09:05) + 31 hourly + sector events | about 60-70 | **$2.5-2.9** |
| READ | $1.00 | R1-R6 (R6 now only shares with a remembered story) | about 600-900 batches | **$1.2-1.8** |
| READ (shared) | | the v2 news reader while NEWSREAD_AI_OFF is not set | | **about $2.6** (20 Nov) |
| MEET | $1.50 | head briefs 19:45 / 07:15 / 09:08 (+22:45), 35 Opus x3, 36 x3 | about 10 | **$1.1-1.9** [E] |
| LIVE | $1.30 | head 8 + 2 looks, 36 on candidates, seat-15 second reads | about 25 | **$1.2-1.8** [E] |
| **total** | **$5.00** | | | **about $6-8.4 a day without the news reader, $8.6-11 with it** |

**Answer: no.** At $5 the full roster cannot run every seat at every meeting. With the J11 gate on, what happens is: SEATS goes
event-only after about 15 seat calls (70% of $0.90) and stops at about 21, so at the 19:45 meeting the world, commodity and money seats
(first in the DESK_TEAM 2.4 order) get the money and most sector seats are refused; READ is spent by the v2 news reader until its flag is set.

## What fits $5 (for the desk to choose)
1. **LEAN-MON as DESK_TEAM 4.8a wrote it:** one Global+FLOWS call (not seats 1-9 apart), 3 sector calls (not 9), Connections + Devil at the
   meetings, R1 + R3 readers, seat 15 on weight 4+, the head 8 + 2. About 20 Sonnet calls + about 300 reader batches + MEET + LIVE = about
   **$4-4.6** at the measured prices. Needs: a seat-priority order in SEATS (MINIMUM seats first) - one config list; I can add it.
2. **Full roster at ~$7-8 a day** (the trader's yes, DESK_TEAM 4.8b "WIDE"); NEWSREAD_AI_OFF set once R1-R6 run (saves ~$2.6).
3. **Cost levers, both code:** smaller seat inputs (the output-format frame alone is about 2.5k tokens of the 8.5k fresh input, the board
   list about 1.5k) - perhaps 20-30% off a seat call; a 1-hour prompt cache on each seat's fixed prefix helps only seats called twice within
   the hour (meetings are hours apart), so it saves little.

All [E] rows become measured after the first full shadow with complete Opus answers.

## THE TRADER'S DECISION (20 Nov 20:44 IST record; decided 20:28): the FULL desk, daily AI cap $8.00
- J11 hard cap **$8.00** a day (config.DAY_CAP_USD), same budget day 15:40 -> 15:40 per calendar day (desk accepted, DESK_TEAM 4.7).
- Buckets: **MEET $1.80 · LIVE $1.50 · READ $1.60 · SEATS $2.80 · ASK $0.30 = $8.00** (from the measured prices above: the full roster's
  SEATS need $2.5-2.9; READ holds R1-R6 and, until NEWSREAD_AI_OFF is set, the v2 news reader).
- Ladder: SEATS half spent or the day at 75% ($6.00) -> the meetings switch to the 5 LEAN combined calls (LEAN_COMBINED.md, the desk's $4.14 plan);
  SEATS at 70% -> seat calls event-only; the day at 90% ($7.20) -> only event calls, briefs (MEET) and LIVE; $8.00 -> code + rules only.
- Honest: with the v2 news reader still on (~$2.6 a day) READ is over its $1.60 on a busy day and R1-R6 get refused; setting the flag
  once R1-R6 pass their shadow fixes that. The page footer reads the cap from desk.meter.cap ("AI $x of $8").
