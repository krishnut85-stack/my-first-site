# NEWS REPLAY - Friday 20 Nov 2026 through the v2 news path

Made Sat 21 Nov 2026 ~21:50 IST (DESK_REVIEW 21 Nov 20:30, order 3). Machine copy: `NEWS_REPLAY_20NOV.json` (same folder).
Script: `v2/replay/newspath_replay.py` (run: `GIR_REPLAY_NO_TG=1 nice -n 15 python3 replay/newspath_replay.py --out <folder>`).

**$0, silent:** no AI module is imported, every outside network connection is refused for the whole run, it refuses to start without
`GIR_REPLAY_NO_TG=1` (the replay isolation flag gir-v2replay uses), and it only reads recorded stores (v2 ext/*.jsonl, news.db,
newsread.jsonl, filings.jsonl, tv.db, the live deskboard). The v2 path is the live code: `analyst.snapshot.knowledge()` on the store as it
stood at that minute (ext.recent = newest 150, news.list + news_gate, newsread / filings) and the readers' `READ_KINDS` from
`analyst/seats.py`. "Live" columns are what the real desk did on Friday's tape (deskboard `looks` / `cards`). **The desk only started at
Fri 20 Nov 19:23 IST**, so nothing before 19:23 could get a live card on Friday.

## Bottom line

- **Critical items caught on Friday's replay: 10 of 10** - every item was in GIR within 3-11 minutes of the event, and today's v2 path
  hands each one to the right reader inside its catch-by window (RBI -> R4 policy, world -> R5, Indian wires -> R2, TV -> R3).
  Before tonight's fix 1 (below), the 3 daytime RBI items went to the **wrong** reader (R5 world) - that part was 7 of 10.
- **What the live desk actually carded on Friday's tape: 5 of 10, none in time** (2 h to 11 h late: the desk started at 19:23, then the
  weekend slow mode and the $1.50 ladder). 5 got no card at all: VRR result 10:20, second VRR result 13:40, the 4-day VRR notice,
  the Nvidia SEC probe headline, the IndusInd roadshows.
- The **code alerts** (shocknews, $0) fire on all 4 RBI items: RED x3, AMBER x1. On Friday regs started only at 15:37, so the REDs came at
  15:37; with regs now polling RBI every 60 s they come within ~1-2 minutes of the release. (Telegram for these is held until the
  Sunday ring test - unchanged.)

## The table

| # | Item (the trader's list) | Event (IST) | First seen in GIR | Source -> reader (today's path) | Live desk read it? | Live card? | Verdict / named fix |
|---|---|---|---|---|---|---|---|
| 1 | RBI VRR result 10:20 | Fri 10:20 | Fri 10:28 (+9 min) | v2 bonds (RBI RSS, 5 min) -> **R4** (was R5 before fix 1); regs copy 15:37; code alert RED (15:37) | R2 at 22:09 (backlog) | **no** | caught by the path + code alert; no card -> **F2** (R4 calls RBI ops PROCEDURAL) |
| 2 | Second VRR notice 12:35 | Fri 12:35 | Fri 12:43 (+9 min) | bonds -> **R4** (was R5); code alert RED "unscheduled operation" (15:37) | R2 at 22:47 | **yes**, R2 22:47 (10 h late) | late only because the desk was not running |
| 3 | Second VRR result 13:40 | Fri 13:40 | Fri 13:43 (+4 min) | bonds -> **R4** (was R5); code alert RED (15:37) | never read on its own | **no** | **F2** |
| 4 | 4-day VRR notice 19:25 | Fri 19:25 | Fri 19:32 (+7 min) | regs -> **R4**; bonds copy -> R5 (merged into R4 now); code alert AMBER 19:32 | R4 21:16: QUIET (PROCEDURAL / NO_FO_LINK); R5 21:41: "NOT_WORLD_DRIVER: domestic liquidity notice" | **no** | **F1 (done) + F2** |
| 5 | Nvidia SEC probe (Reuters) | Sat 00:40 | Sat 00:46 (+6 min) FinancialJuice; investingLive 01:33; Reuters exclusive via US wrap 07:49 | fjuice -> **R5** | the 00:46 headline was **never read** that night ("budget: day at 90% of $1.50 - event calls only"); R5 reads at 08:52-09:10 refused (hard cap); first read Sat 19:38 | **no** card names the SEC probe (R5 08:36 "Nvidia's losing streak..." from the wraps, 8 h later) | **F3** |
| 6 | Anthropic IPO slide | Fri 19:30 | Fri 19:33 (+3 min) investingLive | world -> **R5** | R5 21:41 (one batch rejected by the validator at 21:37) | **yes**, R5 21:41 (2 h 08 late) | late: start-up backlog -> **F4** |
| 7 | US close S&P -3.7% / Nasdaq -5.3% | Sat 02:30 | Sat 02:35 (+5 min) FinancialJuice "S&P 500, Dow close in correction territory"; numbers 04:33 investingLive; summary 08:06 | fjuice / world -> **R5** | not read until 08:06 (ladder) | **yes**, R5 07:59 (5 h 24 late) | **F3** |
| 8 | IndusInd roadshows | Fri 07:00 | Fri 07:11 (+11 min) Google News "engages 8 funds in Chennai meet after Singapore roadshow"; WIRE 19:10 "to join Macquarie investor meetings in Sydney" | news.list -> **R2** | **never read** (07:11 before the desk; 19:10 lost in the start-up backlog) | **no** | **F4** |
| 9 | CII summit FPI line (SEBI chairman) | Fri 11:30 | Fri 11:33 (+3 min) CNBC-TV18 live blog; ANI 12:24; ET 17:37 | newsread / wires -> **R2** (the live-blog copy had reader weight 1 and is dropped; the ET Now copy at 11:45 goes through) | R4 / R5 / R2 from 21:08 | **yes**, R4 21:08 / R2 22:31 (desk not running at 11:33) | late only because the desk was not running |
| 10 | Gold -4.7% | Fri 10:15 | Fri 10:20 (+5 min) WIRE "Kalyan Jewellers falls as gold slumps"; WIRE 11:19 "gold, silver crash"; CNBC-TV18 12:52 "gold down around 4.7%" | news.list -> **R2**; TV -> **R3** | R5 21:41, R2 22:52 | **yes**, R5 21:08 / R2 22:52 | late only because the desk was not running |

## Named fixes

- **F1 - DONE 21:45 IST** (analyst/snapshot.py .bak2144src, test_newspath.py, desk suite 315/315, gir-v2desk restarted): the bonds
  poller's RBI releases (VRR / VRRR results and notices) were typed `world` -> the world reader R5, which called the 4-day VRR notice
  "NOT_WORLD_DRIVER". They now go to the policy reader R4 and merge with the regs copy (one read, not two). Replay after the fix: items
  1-3 reach R4 at 10:28 / 12:43 / 13:43.
- **F2 - for the desk (R4 prompt / card rule; not changed by me):** R4 marked the RBI liquidity operations PROCEDURAL / NO_FO_LINK, so no
  card. Proposed rule: an RBI liquidity operation >= Rs 25,000 cr, or an unscheduled / second operation, is a FACT card naming the bank
  basket (the same threshold the code alert already uses for RED).
- **F3 - for the desk (spend rule inside the cap; the cap itself is not touched):** on the weekend budget day the ladder went to "event
  calls only" at 90% of $1.50, so R5 never read the 00:46 Nvidia SEC headline or the 02:35 US-close line; cards came 5-8 h later from the
  US wraps. Proposed: a hot world headline (EXCLUSIVE / SEC / probe / investigation naming a top US mega-cap, or a US index close move of
  2% or more) counts as an event read past the ladder; and the code alert (shocknews family I) shows such a FinancialJuice headline as
  AMBER instead of hiding keyword-only FinancialJuice lines. (Sunday 22 Nov is already $3.00 - set by the trader.)
- **F4 - for the desk (reader batching):** at desk start (Fri 19:23) the weekend slow mode (from Fri 15:40: one R2 batch of 6 items per
  20 minutes) never drained the day's backlog - the IndusInd 19:10 item was never read and the Anthropic card waited 2 h. Proposed: slow
  mode only after the evening brief, plus one backlog drain when the desk starts. (On a normal weekday the desk runs all day and reads
  every 20 s, so items 1-3 and 8-10 would have reached a reader within minutes.)

## Not in the table
- New sources built tonight (FDA, CERC, e-Gazette Extraordinary, Zee Business, odds ...) did not exist on Friday, so they cannot be in a
  replay of Friday's tape; their live status is in `NEWS_COVERAGE_AUDIT.md` (refresh block at the top).
- Card matching is by headline words within 16 h of first sight, checked by hand for each row above.
