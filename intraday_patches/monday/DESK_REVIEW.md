# DESK REVIEW - answers to the server's STATUS.md (newest first)

## 20 Nov ~15:00 IST - seriesstudy.py READY TO RUN (monthly expiry study, the trader's request)
Built, checked by an independent quant, all fixes in, 56 tests pass (planted edge found, pure noise "none does").
Run AFTER 15:35 today (or any time this weekend), light:
`cp intraday_patches/seriesstudy.py /home/globalbot/intraday/ && cd /home/globalbot/intraday && python3 seriesstudy.py check && python3 seriesstudy.py run`
(onsetstudy.py must sit beside it). Push STORE/seriesstudy_report.txt + seriesstudy.json to intraday_patches/onset_results/ (not the
trades npz). The December series starts Wed 25 Nov - the trader needs section 0 before then. Not a Monday blocker: run it after the
replays if CPU is short.

## 20 Nov 13:30 IST (hourly) - on STATUS 12:37
1. **Oversold mirror (RSI <= 20, 207 events, 86% bounced / 64% higher at day 20): desk decision - CE BOUNCE lines ALLOWED, only on
   the turn**: the share reclaims yesterday's high AND VWAP with volume (RVOL >= 2), its sector not falling, no fresh bad news
   (results / downgrade / regulator) in the last 2 sessions. Chip: "OVERSOLD RSI nn - 86% bounced within 20 days, n=207". Same
   NOT PROVEN label until it scores live. Also run `python3 obscan.py --oversold --force` (RSI <= 30, with the strong / weak market
   split the trader asked for) and push obscan_oversold_report.txt to onset_results/.
2. **YESBANK pre-open = NSE unmatched IEP: accepted** - the thin pre-open rule (09:08 list reads only matched pre-open) is right.
3. **F5 load 15 at 12:37 from NON-GIR jobs (gircrypto window2_news 68%, old engine2 68%, falcon 48%): escalated to the trader again.**
   gircrypto is his other project - pausing it in market hours on Monday needs his yes (or the 8-core resize). Prepare both options
   (a one-line pause / resume for gircrypto + falcon 09:00-15:35, and the resize plan) so either can be done Sunday in minutes.

## 20 Nov 12:15 IST - check: YES BANK "10% down in the pre-open"
The trader saw YESBANK ~10% down in the pre-open. Public quotes: previous close 17.84, open 17.68 (-0.9%), range 17.62-17.80,
-0.6% at 11:21 - no 10% fall anywhere. If GIR or its pre-open recorder (F09 / J2 09:00-09:08) showed a ~10% fall, it is a DATA FAULT:
find the source (IEP of a thin order, a stale or wrong previous close, a corporate-action adjustment) and add a sanity rule (a
pre-open move > 5% with < N trades is shown as "thin pre-open - not a price" and never feeds a card). Log the finding in STATUS.md.

## 20 Nov 12:05 IST - regulator sources that only the SERVER can read (they refuse cloud / foreign machines)
WEB_SOURCES.md section 5 tested from the desk: 56 of 75 open. These 19 must be polled FROM THE SERVER (Indian network):
NPCI (npci.org.in, www.npci.org.in - UPI circulars), www.mca.gov.in, rsdoc.nic.in, cdsco.gov.in, nppaindia.nic.in (drug prices),
grid-india.in, report.grid-india.in, sansadtv.nic.in, eparlib.sansad.in, archive.pib.gov.in, bombayhighcourt.nic.in, aptel.gov.in,
cbic-gst.gov.in, aera.gov.in, indianrailways.gov.in, gercin.org, www.tnerc.tn.gov.in; egazette.gov.in has an incomplete
certificate chain - add the missing intermediate certificate to the server's trust store (never turn verification off).
Use section 5's "FOR THE SERVER (F20 / F21)" polling plan for p_regs.py.

## 20 Nov 11:30 IST (hourly) - on STATUS 11:22
- **I2 TV: accepted** (Deepgram on both channels since 07:00:55, median 32 s). Still needed by Monday: the plain "TV ONLY -
  unverified" news line, and block junk matches (TVSMOTOR from "TV").
- **I1 filings 55 s / I3 wires 278 s / I4 world / I5 regulators 551 s: LATE - your staged fixes are accepted** (NSE cache-buster,
  60 s circulars, sitemap-first polling, Trump / FJ every 60 s, p_regs.py). Monday targets: filings <= 20 s, wires <= 60 s,
  regulators <= 120 s; measure again on Sunday's items and push the table. For p_regs.py use the regulator / Parliament map the
  desk is writing now (WEB_SOURCES.md section 5, lands this afternoon) - SEBI / RBI / PIB / sansad / TRAI / CCI / IRDAI pages.
  Fix the BSE GMT-as-IST time bug before the delay table.
- **F5 server load: escalated to the trader** (8-core resize = paid, his yes). Meanwhile on Monday: stop or slow the old timers that
  burst at the same minute (falcon, crosscheck, govwatch, raven-manage), and keep the silent old system's AI off (J11).
- **I6-I8: accepted as staged** for after 15:35.

## 20 Nov 11:10 IST - new: design_v3/WEB_SOURCES.md (95 outside sources ranked by the desk)
1. **Check F16 now:** Moneycontrol's RSS is DEAD (newest item April 2024). If gir-newsroom still reads it, switch to
   moneycontrol.com/news/news-sitemap.xml (fresh this morning). ET markets RSS, Business Standard markets RSS, CNBC-TV18 news sitemap
   and BSE notices.xml were all fresh at 11:00.
2. Its section 3 "FOR THE SERVER TO COLLECT" lists the top 15 (Trump-posts RSS, FinancialJuice free, investingLive, US Federal
   Register, CCIL 10-year ...) with method and frequency. Add the free ones over the weekend as part of I4 (not a Monday blocker);
   paid rows need the trader's yes.

## 20 Nov 10:20 IST - two points from your own 19 Nov evening report
1. **TV listening (I2):** your 19 Nov 18:10 report says "TV listener on Deepgram ... no tvstt.py process (TV listening stopped)".
   Morning TV is a MAIN input from Monday (PREDICTION_LOOP 00 / A1). Confirm in STATUS.md now: is tvstt running today, since what
   time, on which channels (CNBC-TV18, ET Now), and the last transcript line time. If it is not running, start it (light) and keep
   it running all day; log why it stopped yesterday.
2. **5-year history:** the same report says "5-year history: 218 of 218 shares complete", but the onset study read a 3-year store
   (/root/hist, 16 Nov 2023 - 13 Nov 2026). Say where the 5-year minute data is and whether /root/hist can be extended from it, so
   preopenstudy.py and sectorlag.py can run on 5 years (GIR_HIST can point to another folder).

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
