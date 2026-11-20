# DESK REVIEW - answers to the server's STATUS.md (newest first)

## 20 Nov 09:35 IST - old system STALE alert 09:28 (desk.json 6 min old, limit 5) - not urgent, the trader says
Find the cause and log it in STATUS.md (Kite rate limit on the shared key 2, CPU, disk, or the old system itself). The trader's
order: **the new system's recording and monitoring must NOT stop.** If a test job is the cause, keep it running and lighten it
instead (J2 every 5-10 s, shadow run at nice 19, December quotes every 15 min, or move polling off key 2). If the old system is
the cause on its own, note it as an old-system fault and leave it.

## 20 Nov 09:25 IST - URGENT, on after2_2026-11-18.txt: "zero lots 1036 of 1050 - no premium - not tradable (821)"
The fixed engine rang only 3 times on 18 Nov mostly because almost every card had NO PREMIUM, not because the ideas were bad. The
recorded days hold November strikes; the new rule asks for December strikes, which were not recorded -> 0 lots -> silent. So:
1. TODAY, NOW (light): add December option quotes to the J2 recorder - ATM +-2 CE and PE, December, for every F&O share (or at least
   the C1 list + the day's top 60 movers, refreshed every 15 min). Otherwise tonight's replay of today has the same hole.
2. Replays of 16 / 18 / 19 Nov: price the card from the recorded November ATM premium as a PROXY (labelled "premium: Nov proxy")
   so the lots / R:R / ring logic can be judged; report cards and rings with the proxy AND without.
3. Confirm Monday live reads December chains for all F&O shares (A5) - one check at 09:20 today on 5 shares, logged.
4. Side mix on 18 Nov (CE 100 / PE 950 GET READY) is acceptable for a down day; the up-day replay must show the mirror.

## 20 Nov ~09:30 IST - on the C1 finding (movers yes, side no, empty lists on news-thin evenings)
Good, honest test - and right to discard the 18 -> 19 Nov chain result (hindsight). Desk decisions, now PREDICTION_LOOP A6b:
1. The list is NEVER empty: code ranks movers from data alone; news / knowledge only add names or set a side.
2. Strong mover + unproven side = a MOVER line with BOTH triggers (CE above yesterday's high / OR high with RVOL >= 2; PE below
   yesterday's low / OR low with RVOL >= 2). The first trigger that fires with sector and NIFTY not against it decides the side;
   the other is cancelled. This is how the 1.4x mover edge becomes early cards without guessing the direction.
3. A side before the open only from a driver with a record: the 09:08 market-day call (3-year study: up days ~2x CE moves, down
   days ~3x PE moves - measure its side accuracy in the replays), broker / TV / trader reads with their hit rates, D-1 build-up
   if preopenstudy shows it predicts the side. Otherwise "NOT PROVEN" and B needs price.
4. E2 "10 early cards" counts MOVER lines too, once their trigger fires before half the move is done. Report MOVER lines and side
   lines separately in the replays (16, 18, 20 Nov, the up day, 27 Oct), beside the old system.
5. Re-run C1 on 16 / 18 Nov with rule 1 (code-only lists) so those days are not empty, and push the result.

## 20 Nov ~09:15 IST - preopenstudy.py is READY TO RUN (G1)
Checked by the quant (no blocking problem) and the desk; the last fix (09:20-09:45 levels graded from the naming price) is in;
190 tests pass. Run it any time over the weekend, or after 15:35 today:
`cd /home/globalbot/intraday && cp <branch>/intraday_patches/preopenstudy.py . && python3 preopenstudy.py check && python3 preopenstudy.py run`
(onsetstudy.py must sit beside it - it imports it). Push STORE/preopen_report.txt and preopen.json to intraday_patches/onset_results/.
Its section 0 sets the numbers for C1 (how many names per side, which level, which entry); the desk reads it as soon as it lands.

## 20 Nov 08:30 IST (hourly check) - on STATUS 08:11
- **B1-B5, B7: accepted as coded**, pending the proofs after the 15:35 swap (replays). Good: CONFIRMED gate removed with sector_grade
  on every card; CE/PE mirror test; one-ring rules; 09:15 print excluded from RVOL5; 0 lots with the reason.
- **B3 watch-point:** "19 Nov frames 32 -> 3 rings (AI off)" - fewer rings is right, but the pass mark (E2) also needs at least 10
  CARDS before the move a day. In the replay proof, show cards-before-the-move and rings separately; if the engine has gone too
  quiet, the evening / 09:08 prediction list (C1) must supply the early cards.
- **B6: the code reject layer is accepted** (B6_rules_proof.jsonl: 13 bad cards -> REJECT / WAIT with the exact rule, 2 clean
  controls -> CONFIRM). **Still to prove: the Opus 5.5 check itself** on the same 15 cards - push its verdict beside the rule
  verdict (after 15:35; ~15 calls, well inside the budget). Pass = it never CONFIRMS a card the rules reject, and it says WAIT /
  REJECT on at least the 8 real bad cards.
- **J2: accepted on REST quotes.** Add: after 15:35, run engine_next READ-ONLY over today's recorded frames and push the cards and
  rings it WOULD have sent, scored against today's movers - this is the first real-day test of the new engine.
- **New desk inputs since the last review:** PREDICTION_LOOP.md final (C1-C5 can start), the principle + morning TV from 07:00
  (section 00, I2), sectorlag.py (you ran it - thank you). preopenstudy.py: one grading fix still in progress - wait for the
  "ready to run" commit.

## 20 Nov 07:55 IST - on STATUS 07:38
1. **PREDICTION_LOOP.md is FINAL and pushed** (commit dee16ff) with R52-R56. C1-C5 can start. Decisions are inside it (Departures,
   decided under his order): live from Monday with the NOT PROVEN label; 09:17 earliest for predicted shares (09:17-09:30 only the
   09:08 top 5); index line on the next weekly; ONE $5 AI cap replacing every $20 in BUILD_PLAN.
2. **Websocket slots (A1 / J2 risk): the NEW system gets the websocket slots on Monday.** The silent old system must NOT hold them.
   Its comparison runs from the new recorder's data (or REST quotes), or by replaying its logic on the recorded day after 15:35 -
   your choice, whichever is safer. The fallback switch `gir mode old` must hand the slots back to the old system and `gir mode new`
   take them again - test both ways on Sunday with real reconnects (F2 / J7). Today J2 on REST every 3 s is accepted.
3. **Kite logins (J1 risk): all four keys must be logged in by the automatic login before 08:00 on Monday**, not by the old engine at
   09:04 / 09:21. Move keys 2 / 3 / 4 to the same early auto-login as key 1; Sunday dry run of all four; 08:20 check.
4. **New: TRADER_CALLS.md** (design_v3). After 15:35 today score his pre-open reads: defence F&O shares UP; DIXON and its group UP;
   the aerospace / defence share that jumped 4% on a 2.51% FII + DII bulk deal (find it in Thursday's NSE bulk / block file). From
   the 09:15 open and from Thursday's close, vs NIFTY and vs sector. His reads become a scored source ("TRADER READ") in EVENT_MEMORY.
5. **preopenstudy.py**: still being checked by the desk; it lands this afternoon. G1 waits for it.

## 20 Nov 08:30 IST - TRADER_CALLS.md now holds 33 of his past reads
After 15:35 (light job), score every row marked "TO SCORE (server)" from the minute store / NSE closes: the move from the time he
said it to that day's close and the next day's close, right side or not, vs NIFTY and vs sector. Also score today's 07:45 reads and
his 19 Nov call (consumer and auto down on 20 Nov). Push the filled table. His reads go into EVENT_MEMORY as source "TRADER READ"
with this hit rate, CE and PE kept apart (so far his PE reads have been right far more often than his CE reads).
