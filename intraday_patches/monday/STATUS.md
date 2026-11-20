# MONDAY STATUS - the full new system live Mon 23 Nov 09:15 (READY 08:30)

One row per checklist item (MONDAY_READY.md). Proof files are in this folder. An item without proof is NOT DONE.

Last update: 09:36 IST

| item | status | note | proof | time |
|---|---|---|---|---|
| A1 Kite four keys + auto-login | NOT STARTED | desk decision: the NEW system takes the websocket slots on Monday; the silent old system compares from the new recorder's data; `gir mode old/new` hands the slots back and forth (tested Sunday with real reconnects, F2 / J7) |  | 08:33 |
| A2 Feeds F01-F31 source/freshness | NOT STARTED |  |  |  |
| A3 NSE files Fri 20 Nov + Monday ban list | NOT STARTED |  |  |  |
| A4 Minute store through Fri 20 Nov | IN PROGRESS | one-month minutes 16 Oct-19 Nov in girdata/minute; /root/hist store ends 13 Nov; Fri 20 Nov after 15:40 |  | 07:31 |
| A5 December chains + current lots | IN PROGRESS | December chains read LIVE: 10 December ATM contracts on 5 shares checked 3 ways (store, new December recorder, direct Kite quote 09:35) - bid/ask equal or a few ticks apart, OI within 0-1.5 pct (one 7.8 pct on a 51 s older reading in a fast move); gir-v2optdec records 2,160 December contracts every 15 min. OPEN: store rows have no per-row quote time (stale rows cannot be told apart) - fix with B9 after 15:35; December lots checked with J5 | A5_dec_chain_check.md | 09:36 |
| A6 Global feeds for 07:15 | NOT STARTED |  |  |  |
| A7 News feeds live + de-duplicated | NOT STARTED |  |  |  |
| A8 Paid subscriptions tested | NOT STARTED |  |  |  |
| B1 Remove CONFIRMED gate | IN PROGRESS | coded in engine_next: CONFIRMED gate removed everywhere; sector_grade on every card; AGAINST-sector stays veto (d); 84 unit tests pass; live engine untouched until the swap after 15:35 | B1_sector_grade.md | 08:11 |
| B2 CE equal to PE | IN PROGRESS | coded: share-led CE/PE setups (yesterday high/low, day high/low, ORB5, VWAP reclaim/loss + a backing sign); mirror test identical with sides swapped; 84 unit tests pass; live engine untouched until the swap after 15:35 | B2_ce_equals_pe.md | 08:11 |
| B3 One ring per idea | IN PROGRESS | coded: one ring per share/side/idea, no cancel <10 min, no re-issue <15 min, 50/day + 6/15 min, no ring on 0-lot cards; 19 Nov frames 32 -> 3 rings (AI off); 84 unit tests pass; live engine untouched until the swap after 15:35 | B3_one_ring_per_idea.md | 08:11 |
| B4 Entry signs from the study | IN PROGRESS | coded: time-of-day RVOL / RVOL5 (from 09:16), 09:15 print excluded (J9), GO NOW needs a volume sign, no GO NOW 20+ min after onset unless pullback; 84 unit tests pass; live engine untouched until the swap after 15:35 | B4_entry_signs.md | 08:11 |
| B5 Real December plans, R:R<1 = 0 lots | IN PROGRESS | coded: levels from real highs/lows/ranges/walls, R:R on share and premium after costs, 0 lots with reason (no premium / R:R<1 / 1 lot > 1R), December chain read from oc.exps; 84 unit tests pass; live engine untouched until the swap after 15:35 | B5_real_plans.md | 08:11 |
| B6 GO NOW on Opus 5.5 + reject rules | IN PROGRESS | coded: GO NOW chain Opus 5.5 first, card carries premium/bid-ask/spread/IV/delta/OI/days to expiry; reject R1-R6 + wait W1-W4 in prompt and code; 13 bad cards -> 13 WAIT/REJECT, 2 clean -> CONFIRM by the rules; AI proof run after the 15:35 swap; 84 unit tests pass; live engine untouched until the swap after 15:35 | B6_go_now_check.md, B6_rules_proof.jsonl | 08:11 |
| B7 Triage ranks | IN PROGRESS | coded: triage priority 1-10; opening cap / rate limit keep the highest; ai_lane and final_lane logged apart; 84 unit tests pass; live engine untouched until the swap after 15:35 | B7_triage_ranks.md | 08:11 |
| B8 News by company and context | IN PROGRESS | coded: newsmatch.py - company named in context only (no product codes, look-alike names, counterparties, baskets); KEI-01 / Ford-Stellantis class dropped; second reading AGREE / DIRECTION WRONG / EVIDENCE WEAK, DIRECTION WRONG blocks GO NOW; 97 unit tests pass; swap after 15:35 | B8_news_by_company.md, B8_news_drops_16-19nov.txt | 08:28 |
| B9 Fault test | IN PROGRESS | coded: AI calls time-bounded with named fallback reasons, 3 failures = AI paused 5 min (rules decide), stale quote blocks at once, dead feed writes a FEED DEAD fault; 97 unit tests pass; swap after 15:35 | B9_fault_test.md | 08:28 |
| C1 Evening prediction | IN PROGRESS | coded in v2/predict (19:45 / 22:45 / 07:15 / 09:08 versions, append-only store, CE + PE lists, market call); point-in-time tests 16/18/19 Nov done, 20 Nov after the minute pull. RISK: it picks shares that WILL MOVE (lift ~1.4 held out) but the SIDE is right only 50.2 pct - every line labelled NOT PROVEN; on quiet-news evenings it does not supply 10 early cards (desk B3 point) | C1_evening_prediction.md | 08:54 |
| C2 PREDICTED signal | IN PROGRESS | coded (v2/predict/monitor.py): one state per 09:08 line, confirm from 09:17, 09:17-09:30 only the 09:08 top 5, TOO LATE / PREDICTION FAILED / NOT PREDICTED, ring tiers 6/15 min + 50/day; live shadow run today, nothing sent; 23 unit tests; pages + timers after 15:35 | proof after 15:35 | 09:22 |
| C3 Live news call | IN PROGRESS | coded (newscall.py): NEWS -> can go UP / DOWN with NEW / REPEAT / DENIAL / OFFICIAL, VERIFIED / TV ONLY, price-confirm before any GO NOW; live shadow today; 23 unit tests; pages + timers after 15:35 | proof after 15:35 | 09:22 |
| C4 Bottom / top calls | IN PROGRESS | coded (bottomtop.py): STOP no new PE / CE, 45-min suspension, price test, the voice's record; live shadow today; 23 unit tests; pages + timers after 15:35 | proof after 15:35 | 09:22 |
| C5 Scoring after 15:35 | IN PROGRESS | with C1; first scoring after today's close |  | 08:33 |
| D1 Drill-down + cut-text fixes | IN PROGRESS | drill-down built on /preview (R51 841 PASS / 0 FAIL / 12 NOT RUN); cut text, flow box, footer, mask colour after 15:35 | ../v2_review/drilldown/R51_controls.md | 07:31 |
| D2 Prediction on Morning / Desk / phone | IN PROGRESS | with C1 (Morning, Desk, phone) |  | 08:33 |
| D3 Footer: real models + AI cost | IN PROGRESS | footer shows the engine's real AI status; GO NOW model moves to Opus 5.5 with B6 |  | 07:31 |
| D4 All 23 pages: 0 console errors, R51 0 FAIL | NOT STARTED |  |  |  |
| D5 Masked screenshots only | NOT STARTED |  |  |  |
| E1 Replays 16/18/20 Nov, Oct up day, 27 Oct | NOT STARTED |  |  |  |
| E2 Pass mark | NOT STARTED |  |  |  |
| E3 Side by side with the old system | NOT STARTED |  |  |  |
| F1 Control room / health line + alarm | NOT STARTED |  |  |  |
| F2 Fallback switch both ways | NOT STARTED |  |  |  |
| F3 Watchdog / exit monitor untouched; no FO/OI | IN PROGRESS | standing rule, checked at every change; final proof Sunday |  | 07:31 |
| F4 Ring test to his phone | NOT STARTED |  |  |  |
| F5 Logs, disk, memory, restart | NOT STARTED |  |  |  |
| G1 preopenstudy.py | NOT STARTED | desk: preopenstudy.py READY TO RUN (09:15); run after 15:35 today |  | 09:29 |
| G2 Score this week's evening watches | NOT STARTED |  |  |  |
| I1 NSE + BSE filings | IN PROGRESS | measuring 5 real items today | external_delays.md | 07:31 |
| I2 TV speech-to-text | IN PROGRESS | measuring | external_delays.md | 07:31 |
| I3 Wires and publishers | IN PROGRESS | measuring | external_delays.md | 07:31 |
| I4 World news and cues | IN PROGRESS | measuring | external_delays.md | 07:31 |
| I5 Regulators / Parliament / PIB | IN PROGRESS | measuring | external_delays.md | 07:31 |
| I6 Sector data (R49) | IN PROGRESS | measuring (3 checks vs NSE indices today) | external_delays.md | 07:31 |
| I7 Economic + results calendar | IN PROGRESS | measuring | external_delays.md | 07:31 |
| I8 Source health + silence alarm | IN PROGRESS | measuring | external_delays.md | 07:31 |
| J1 Automatic Kite login | NOT STARTED | plan: keys 2/3/4 use the same Zerodha user + TOTP as key 1's auto-login (each app has its own key/secret); built after 15:35 today - a new login during market hours could cut the old engine's live sessions; Sunday dry run of all four; Monday 08:20 check |  | 08:33 |
| J2 Today's live session read-only | IN PROGRESS | recording since 09:04:30 on key 2 by REST quote() (no websocket slot free): 665 instruments, 2 calls every 3 s, 0 errors; ~220 items/s polled, 88-101/s changed, largest gap 3.2 s; FULL fields: 5-level depth on 99.25 pct of items (all shares and futures), OI on 100 pct of futures; 09:00-09:04 from the 10-30 s snapshots (no key 2/3/4 token before the old engine's 09:04 login); ~40 MB/h; proof table by 16:00 | J2_live_readonly.md (16:00) | 09:07 |
| J3 One trading calendar (Tue 24 holiday) | NOT STARTED |  |  |  |
| J4 Fake-clock Monday 08:00 / 08:45 | NOT STARTED |  |  |  |
| J5 Monday instrument file vs Friday | NOT STARTED |  |  |  |
| J6 Silence every old sender | NOT STARTED |  |  |  |
| J7 Fallback switch safe and his | NOT STARTED |  |  |  |
| J8 Replay isolation | NOT STARTED |  |  |  |
| J9 09:00-09:30 rules | NOT STARTED |  |  |  |
| J10 Expiry-day mode | IN PROGRESS | coded: stock options December only; index options next expiry (NIFTY 1 Dec) with the expiring one info-only; expiry-week build-up from all months; PINNING flag from 13:30; 97 unit tests pass; swap after 15:35 | J10_expiry_day_mode.md | 08:28 |
| J11 AI budget split | NOT STARTED | desk decision in PREDICTION_LOOP: one $5 AI cap replaces every $20 - to be set with the engine builder (the live cap is unchanged until then) |  | 08:33 |
| J12 Clock / Asia/Kolkata | NOT STARTED |  |  |  |
| J13 Restart proof + outside uptime | NOT STARTED |  |  |  |
| J14 Rate limits at cold start | NOT STARTED |  |  |  |
| J15 His Monday routine (trader) | NOT STARTED | trader's own step Mon 08:25 |  |  |
| J16 Code freeze Sun 16:00 | NOT STARTED | Sun 16:00 |  |  |
