# SERVER ORDER - the full new system live Mon 23 Nov 2026, READY 08:30 IST

**This file replaces every earlier message from the desk.** If an older message disagrees with this file, this file wins. Work 24/7
until Monday 08:30. Do not wait for the trader to repeat anything: everything needed is here or in the files named here. Pull branch
`ccr-67e340f1-sko8xd` every hour: the desk pushes its inputs there (section 4).

The trader's order (20 Nov): "Monday we use the new system. Monday we use the full system. Check everything before that. Monday
8:30 everything is ready. All the subscriptions have been given. There is no reason to delay it."

## 1. How you report (the only reporting)
- Keep ONE file, `intraday_patches/monday/STATUS.md`: one row per checklist item (A1 ... J16): item · DONE / IN PROGRESS / BLOCKED /
  NOT STARTED · proof path · time. Push it after every finished item.
- Proof goes in `intraday_patches/monday/` (log, table, screenshot). An item without proof is NOT DONE.
- BLOCKED = write the reason and exactly what the trader must do (if anything), then move to the next item. Never stop and wait.
- The desk reads every push and answers in this repo (`intraday_patches/monday/DESK_REVIEW.md`). Pull it before starting each block.

## 2. What to read (all on the branch)
1. `intraday_patches/MONDAY_READY.md` - THE CHECKLIST, sections A-J and the timeline H. Every item, its owner and deadline.
2. `intraday_patches/v2_review/INDEPENDENT_REVIEW.md` - why the engine failed and the fix list (checklist B).
3. `intraday_patches/onset_results/movestudy_report.txt` - your own 3-year study run: sections 0, 1, 5 (entry signs, timing).
4. `intraday_patches/design_v3/SECTOR_DRILLDOWN.md` (section 8 = approved, with conditions) and your own
   `intraday_patches/v2_review/drilldown/` build.
5. `intraday_patches/BUILD_PLAN.md` (feeds F01-F31, engine E0-E15) and `intraday_patches/design_v3/REQUIREMENTS.md` (R01-R51, R52+ soon).

## 3. Already done (do not redo)
- Onset study run and pushed (onset_results/). Drill-down built on /preview, R51 controls 841 PASS / 0 FAIL / 12 NOT RUN.
- Still open from the drill-down: the cut text at 1366 (fix in block B below).

## 4. Desk inputs still coming (pull hourly; build them when they land)
- `design_v3/PREDICTION_LOOP.md` + requirements R52+ (evening prediction, "PREDICTED - sector confirms" signal, live news calls,
  bottom / top STOP calls, scoring) - expected Fri afternoon. Checklist C.
- `intraday_patches/preopenstudy.py` (market day -> sectors -> shares, how early the right share and side can be named) - expected
  Fri evening. Run it as soon as it lands (`python3 preopenstudy.py check`, then `run`; weekend, no market-hours limit) and push
  `preopen_report.txt` + `preopen.json` to `intraday_patches/onset_results/`. Checklist G1.
- `intraday_patches/monday/DESK_REVIEW.md` - the desk's verdict on each of your pushes.

## 5. Order of work
**A. NOW - Fri 20 Nov, market hours** (light work only; the live page untouched 09:00-15:35; no heavy jobs)
1. J2: run the v2 feed + engine READ-ONLY on today's market as its own service: NO rings, NO Telegram. Record raw frames 09:00-09:30
   and through the day. Push by 16:00: tick rates per connection, FULL-mode proof, reconnects, the rings it WOULD have sent.
2. I1-I8: log 5 real items per external source (filings, TV, wires, world, regulators, sectors): source time -> GIR seen -> on page.
   Push `monday/external_delays.md`.
3. Start coding B1-B9 (engine fixes) and the drill-down cut text on /preview.

**B. Fri after 15:35 and Saturday** (deadline Sat 22:00)
1. A3 / A4: Friday's NSE files; the minute store up to and including Fri 20 Nov.
2. B1-B9 engine fixes, in this order: B1 remove the "sector must be CONFIRMED" gate (grade only) · B2 CE equal to PE · B3 one ring
   per idea · B4 entry signs from the study (RVOL, yesterday's high / low, no GO NOW after half the move) · B5 real December plans,
   R:R < 1 = 0 lots · B6 GO NOW on Opus 5.5 with premium / IV / spread / OI / days to expiry and reject rules, proven on bad cards ·
   B7 triage ranks · B8 news by company and context · B9 fault test.
3. Drill-down cut text (D1): at 1366 nothing ends in "..." except prose with a tooltip - fix the group label "LEADER pullback
   entry i...", "BANKBARODA...", role chips "FO...", heads "BREADTI" / "TODAY ±", state cells "EXT · pullback..." / "GET RE...";
   the flow box shows real numbers, not "not known"; the footer names the real GO NOW model. Add to r51.py a check that fails any
   cell with scrollWidth > clientWidth (no tolerance) with every sector and fold open. Screenshot masks dark grey labelled
   "P&L hidden" (Playwright mask_color), not magenta.
4. J3 one trading calendar (Tue 24 Nov holiday; the Sun 19:45 prediction fires; Mon 19:45 predicts Wed 25) · J4 fake-clock run of
   the Monday 08:00 / 08:45 jobs ("yesterday" = Fri 20) · J5 Monday's instrument file vs Friday's (December lots, shares dropped) ·
   J8 replay isolation (no Telegram credentials, separate stores) · J9 09:00-09:30 rules tested on today's recorded frames ·
   J10 expiry-day mode (OI across all months, pinning flag; index options = next weekly 1 Dec by default).
5. C1-C5 prediction loop from PREDICTION_LOOP.md as soon as it lands.
6. G1 run preopenstudy.py when it lands.
7. E1 replays with the fixes in place: 16 Nov, 18 Nov, 20 Nov, one October up day and 27 Oct (last expiry day), each from the evening
   before (19:45 prediction included). Push calls, AI log, flags, scorecard. E2 pass mark, E3 side by side with the old system.

**C. Sunday** (code freeze 16:00 for the engine and pages; data / ops fixes to 18:00)
1. Fix round from the desk's review; replays again on the same days plus ONE held-out day the desk names after 16:00.
2. J1 run the automatic Kite login once for all four keys and push the result · A1-A8, F1-F5, I1-I8 (measured again on Sunday's filings and TV), J6 silence every old sender, J7 fallback switch the trader can flip
   himself (no backlog dump), J11 AI budget split, J12 clock / Asia/Kolkata, J13 restart + outside uptime check, J14 rate limits.
3. F4 ring test to his phone ~18:30: one CRITICAL, one GO NOW, one news call.
4. 19:45 the evening prediction for Monday goes out (C1).
5. 21:00 push STATUS.md complete: every item DONE with proof / NOT DONE / risk. RED items named with the fallback.

**D. Monday**
- 07:15 global run and prediction update (no Monday Kite token needed) · 08:00 every feed fresh, ban list loaded, health green ·
  before 08:00 the automatic Kite login runs for all four keys (the trader does NOT log in by hand) · 08:20 you check every key (profile + quote); a failed key retries, moves to K4 and rings him · 08:25 test chime + Telegram test ping ·
  **08:30 post READY with the health line** · 09:08 pre-open update · 09:15 live · 15:35 score the day (C5, E3) and push.

## 6. Decided defaults (do not ask the trader again)
- The new system RINGS on the live address from Mon 09:15 - his order is the switch-on. The old system runs silent beside it
  (logging only, no rings, no Telegram, small fixed AI allowance or none). Fallback `gir mode old` / `gir mode new`, also flippable by
  him from Telegram or Settings, never dumping held-back alerts.
- Stock options: December strikes only on Monday. Index options: the next weekly (1 Dec) by default; the expiring contract shown as
  information only.
- Ring limits: 50 a day, 6 in any 15 minutes. AI hard cap as configured; the old system and replays have their own counters.
- Paid data: only with his yes per item (subscriptions he already gave are approved - connect and test them).

## 7. Standing rules (unchanged)
GIR never places orders - no buy button, "Copy contract" only · `/home/globalbot/.env` read, never copied; no keys in chat or logs ·
TG_CHAT_FO and TG_CHAT_OI never used · gir-watchdog and paper_exit_monitor untouched · no personal or trading data in the repo;
masked screenshots only · NRI: commodities and currency are data only · heavy jobs outside 09:00-15:35 on trading days ·
no model names in commits.
