# CHECKLIST AUDIT - true status of every Monday item (A1 ... J16)

Written Sat 21 Nov 18:34 IST (server clock). Read-only audit: nothing edited, restarted or sent. Sources: MONDAY_READY.md, SERVER_ORDER_MONDAY.md,
the whole STATUS.md (entries to 18:21 supersede its item table), v2/BUILD_LOG.md, the proof files in this folder, DESK_REVIEW.md (to 17:30), and the
live server (systemctl, list-timers, file times, archive/park_1127/keep.txt + park_units.txt, the public status.json).

How to read it. DONE = built + proof exists. "DONE - live proof Mon hh:mm" = it can only be proven on the live day. SUPERSEDED = replaced by the desk
(21 Nov) or by a trader decision. The STATUS item table (rows 9-69) is out of date for: A3, A4, A6, A7, B1-B9, D3, E1-E3, F1, F3, J4, J6-J8, J11-J14.

Architecture on Monday (checked): the decision path is the DESK (gir-v2desk: head + seats, briefs, BUY NOW only on an agreed grade A, Telegram via
tgdesk to "GIR Trade now", trade lines open by code at Mon 09:15, DESK_TRADE_FROM). gir-v2engine runs "v2-engine 0.3 (B1-B9 + J9 + J10)" from
v2/engine; it has NO Telegram sender, but its calls (v2/data/calls.jsonl -> calls.feed) are the page's call cards (F1 / phone NOW). engine_next equals
the live engine except engine/ai.py (the J12 IST fix went into the live engine only), so engine_next is behind live and not used.

## Item table

| item | TRUE status | evidence | what is left, who |
|---|---|---|---|
| A1 Kite four keys + auto-login | IN PROGRESS | gir-kitelogin / -kitecheck / -kiteretry / -kitecal timers enabled, next Mon 07:40 / 08:20 / 08:25, nothing Tue 24; key / endpoint map in J14_ratelimits.md; J1_kite_check.md 20 Nov 16:01: 4/4 profile + quote OK - but every key "reused today's token" | No fresh automatic login has ever run. RAVEN (which logged key 1 every morning) is paused since 21 Nov 07:37, so key 1 now also depends on gir-kitelogin. Sunday dry run (J1 commands, once, after 16:00) is NOT in the 18:21 Sunday duty list. Sunday duty; live proof Mon 08:20 |
| A2 Feeds F01-F31 source / freshness | IN PROGRESS | status.json 18:24 IST: LIVE 52 / CLOSED 11 / QUIET 5 / LATE 4 / STALE 1 / MISSING 2, not live = expiry, kq_mcx_cds, optquote; NEWS_COVERAGE_AUDIT.md 88 sources | No F01-F31 table with source / last update / what replaces it. The "expiry" feed's writer (gir-posguard) is parked (finding 4). Builder; live proof Mon 08:00 |
| A3 NSE files Fri 20 Nov + Monday ban list | DONE - live proof Mon 08:00 | girdata/ext/nse_fo_bhav/fo_20261120.zip, nse_cm_bhav/cm_20261120.zip; optoi_close/2026-11-20.json rebuilt from the F&O bhavcopy (44,118 contracts); desk/fii_daily.json has 20 Nov; data/ban.json trade_date 2026-11-23 read Sat 12:09 IST (banwatch inside gir-dash, kept); J4 "Friday's ban file not used as Monday's" PASS | Monday re-read by gir-dash. (The old ban_<day>.txt writer gir-desk is parked; v2 does not read it.) |
| A4 Minute store through Fri 20 Nov | DONE | girdata/minute/2026-11-16 ... 2026-11-20 (20 Nov: 464 files, eq + fut); used by the FULL2-4 rehearsals | /root/hist (3-year study store) still ends 13 Nov; 5-year minute extension not done (not in the pass condition). gir-v2kb-daily first run Mon 15:42 |
| A5 December chains + current lots | DONE - live proof Mon 09:15 | A5_dec_chain_check.md (3-way check); gir-v2optdec active (2,160 Dec contracts / 15 min); chain sanity gate v2/engine/chaincheck.py (13 tests); J5: Dec lots = Nov lots for 224 names | Chain is written by gir-v2opt from Mon 09:00 (optquote "not live" now is expected). Watch "CHAIN <SYM> STALE" 09:15-09:30 |
| A6 Global feeds for 07:15 | DONE - live proof Mon 07:15 | ext/us_overnight.json (12 closes dated 20 Nov, refreshed 18:17 IST); world_quotes (Yahoo 5-min) incl. ADRs INFY / WIT / HDB / IBN, US 10y, DXY, copper, Brent, Asia, USDINR; US-wrap feed; LME official; Japan 10y; HYG-IEF proxy | GIFT NIFTY comes from Kite key 4 (drv.gift): "not known" at 07:15 because the login is 07:40 (J1 rule). First real GIFT is in the 09:08 brief. Optional: move the login to ~07:00 |
| A7 News feeds live + de-duplicated | DONE - live proof Mon 08:30 | NEWS_COVERAGE_AUDIT (59 live / 15 slow / 14 silent) + fixes (routing to R4 / R2, fresh-first, dead feeds); readers' story-id de-dup; B8 company-in-context; SOURCE_SCORE.md 21 Nov 17:14 | READY line LIVE / SLOW / SILENT counts at 08:30 |
| A8 Paid subscriptions tested + listed | IN PROGRESS | list STATUS 16:55 (Kite x4, Anthropic, Deepgram, ET Prime, DO; Gemini key removed 18:06; X prepaid, no charge); tests scattered: Kite 4/4 20 Nov 16:01, Anthropic probe 9/9 20 Nov + live calls today, Deepgram = gir-tvwatch active (1,591 + 1,586 TV items today), ET Prime keep-alive success 15:45 IST | One table with "tested at" per subscription is missing (15 min). Builder |
| B1 CONFIRMED gate removed | SUPERSEDED (desk) - engine fix live | engine 0.3 in gir-v2engine since Fri 15:38 (engine 126 = engine_next 126 tests); desk has no CONFIRMED gate (consensus + grade) | Engine cards = page only |
| B2 CE equal to PE | SUPERSEDED (desk) - engine fix live | engine mirror test; desk: every brief must end with CE: and PE: lines (validator), side-split scoring | - |
| B3 One ring per idea | SUPERSEDED (desk) - engine fix live | engine RING_DAY_MAX 50 / RING_15_MAX 6; desk: R6 sent-ideas ledger, BUY_NOW_DAY_MAX 4, 1 per look, shocks max 8 RED a day | - |
| B4 Entry signs | SUPERSEDED (desk) - engine fix live | engine RVOL / RVOL5 / 20-min rule; desk anti-chase (fresh catalyst + VWAP + RVOL >= 2), runner check, shock-day wait to 09:30 | - |
| B5 Real December plans | SUPERSEDED (desk) - engine fix live | desk analyst/contract.py: Dec ATM / 1 ITM, R:R >= 1, quote age 60 s, lots, expiry half size | - |
| B6 GO NOW check + reject rules | SUPERSEDED (desk) - engine fix live | engine proof B6_ai_proof.md (13/13 bad cards WAIT / REJECT); desk: head + Devil agreement, grade A only, hard gates, results-IV block (tests with stand-in brains) | No real-model proof that the DESK's BUY NOW chain rejects the known bad cards (only the engine's check was proven). Builder, small spend = trader |
| B7 Triage ranks | SUPERSEDED (desk) - engine fix live | desk consensus ranking, "DROPPED FROM THIS INPUT: reason" list | - |
| B8 News by company / context | SUPERSEDED (desk) - engine fix live | engine newsmatch.py; desk readers R1-R6 with CONTRACTS | - |
| B9 Fault test | SUPERSEDED (desk) - engine fix live | engine B9_fault_test.md; desk fail-safe (test_failsafe.py), J11 gate, chain gate, quote age, three distinct P1 AI words | - |
| C1 Evening prediction | DONE - live proof Sun 19:45 | gir-v2predict-n19 timer Sun 19:45, c22 22:45, u07 Mon 07:15; desk briefs 19:45 / 07:15 / 09:08 | Desk reviews the 19:45 brief at once (Sunday) |
| C2 PREDICTED signal | DONE - live proof Mon 09:05 | C2_predicted_signal.md; LIVE timer Mon 09:05 | P09 (09:09:30) loses its pre-open input (finding 3) |
| C3 Live news call | DONE - live proof Mon 09:15 | desk shocks G / H / RBI lines; messages 642-644 sent through the send gate | - |
| C4 Bottom / top calls | DONE - live proof only if one occurs | C4_bottom_top.md | - |
| C5 Scoring after 15:35 | DONE - live proof Mon 15:50 | SCORE timer Mon 15:50; desk 15:45 scorecard | - |
| D1 Drill-down + cut text | DONE | D1_cleanup.md, R51 871 PASS / 0 FAIL | - |
| D2 Prediction on Morning / Desk / phone | DONE | D2_shots/, D_desk_web_5_morning.md | - |
| D3 Footer: models + AI cost | DONE | footer "AI $x of $cap" + desk word (D_desk_web_1_shell.md), real models (D1_cleanup.md), P1 provider lines | - |
| D4 All 23 pages, 0 console errors, R51 0 FAIL | IN PROGRESS | sweep started 18:21 IST; no D4_pages.md yet | Page freeze Sun 16:00. Builder |
| D5 Masked screenshots | DONE | masks dark grey "P&L hidden"; push_monday.sh refuses keys / P&L / *.bak | - |
| E1 Replays | SUPERSEDED | 18 / 19 / 20 Nov replayed with the new desk (FULL2-4, $22.28 total); 16 Nov, the October up day and 27 Oct not run; trader 21 Nov 07:50: no more rehearsal money, Sunday 19:45 + Monday are the tests | - |
| E2 Pass mark | SUPERSEDED (measured: NOT met) | head ideas 2 of 13 right side by >= 1% over 18-20 Nov, NO EDGE shown, knowledge snapshot not controlled (DESK_rehearsal_FULL2/3/4.md) | Monday scorecard is the test (trader's call) |
| E3 Side by side with the old system | DONE for 18-20 Nov; Monday SUPERSEDED | old system >= 2% lift 0.88 / 1.25 / ~1.0 in the rehearsal summaries | Old system parked 21 Nov 16:55 (only muted gir-intraday prices run), so no Monday side-by-side |
| F1 Control room / health + phone alarm | DONE - live proof Mon 08:30 | health rows + silence alarm; status.json public (200, 0.04 s, overall OK); ntfy second channel (test 17:50); outwatch every 2 min, 2 checks in a row; OnFailure alarm on 15 units; heartbeat from 09:30 | Truly outside monitor: see J13 |
| F2 Fallback switch both ways | IN PROGRESS | J7 round trip 18:14 (2 timers, 1.7 s / 1.8 s); key-down DEGRADED built (F2_key_degraded.md) | Flip both ways in the Sun 17:00 mock (MOCK lines only). A real phone ring each way and the full 74-unit cold start are not planned. Sunday duty |
| F3 Watchdog / exit monitor; no FO / OI | DONE | gir-watchdog.timer active, only its check list edited (raven / paper_exit_monitor on the trader's word 10:03; globaleye by the 16:50 order); paper_exit_monitor inactive (down before, not touched); FO / OI refused in code (test_forbidden.py, test_tgguard.py 5/5) | - |
| F4 Ring test to his phone | NOT STARTED (Sun 18:30) | analyst/ringtest.py ready (3 "RING TEST" lines, refuses outside 18:25-18:50, --dry) | Token rotation (trader) must finish BEFORE 18:30, with restarts, or wait until after Monday. Sunday duty + trader confirms |
| F5 Logs, disk, memory, restart | IN PROGRESS | journald capped; 85% disk alarm; disk 77% (12 GB free); RAM 16 GB, 12 GB available; swap 4 GB; Nice / OOM priorities; kill test 18:20 (1 unit back in 31 s, 3 alarm faults fixed) | Sunday ~12:00 reboot = restart proof (trader restarts Claude Code); CPU peak at the 17:00 mock (target < 80% at 09:15, 4 cores); Monday 09:15 live |
| G1 preopenstudy | DONE | ../onset_results/preopen_report.txt | - |
| G2 Score this week's evening watches | NOT STARTED | no file scores SECTOR_MAP_20NOV / WATCH_20NOV_update / WATCH_20NOV_us_night against 20 Nov (only copied into the pack 03:33) | Code only, $0. Builder |
| I1 NSE + BSE filings | IN PROGRESS | NSE 11 s median / 19 s worst after the fix (off hours); BSE answers 403 -> read-only bridge via newshawk-filings (kept); feeds/filings.py keeps only ATTACHMENTNAME | Market-hours latency measured Monday; PDF / XBRL attachments are not read. Builder (week 1) |
| I2 TV speech-to-text | DONE - live proof Mon 07:00 | CNBC-TV18 + ET Now captured; TV lines median 29 s; R3 fixes (segments 66% -> 100%), 2-min cadence 07:00-09:15 | Sansad TV / CNBC Awaaz need paid speech-to-text: trader (default NO) |
| I3 Wires and publishers | BLOCKED (target) | median 129 s vs <= 30 s; free sitemaps, fresh-first, de-dup done | <= 30 s needs a paid wire: trader (default NO) |
| I4 World news and cues | DONE (free-tier delays) | GIFT via Kite, LME official, Yahoo futures / 10y / DXY / Brent / Asia, FinancialJuice (85 items today), Polymarket Fed odds | Trump mirror gave 2 items today (possibly stale); Yahoo prices ~10 min late at source |
| I5 Regulators / Parliament / PIB | IN PROGRESS (source-limited) | RBI seen 1-7 min after its own time; PIB 2-6 min (its RSS lags); 403 / timeouts not evaded | 1-minute target not reachable on free sources |
| I6 Sector data R49 | DONE on Friday - AT RISK Monday | 3-time check vs NSE indices, mean gap 0.11-0.14 pt | sec.board's writer is parked (finding 1). Builder before Sun 16:00 |
| I7 Economic + results calendar | DONE | cal.next, india_calendar.json (official pattern, consensus "not known"), NSE board meetings, peers' results, MSCI 30 Nov | - |
| I8 Source health + silence alarm | DONE | silence alarm from NEWS_COVERAGE_AUDIT.json (test 12/12); READY dry run LIVE 28 / SLOW 2 / SILENT 0 | - |
| J1 Automatic Kite login | IN PROGRESS | as A1 | Sunday dry run (missing from the Sunday list); Mon 07:40 / 08:20 |
| J2 Friday live session read-only | DONE | J2_live_readonly.md | - |
| J3 One trading calendar | DONE | list-timers now: Sun 19:45 N19 + 22:45 C22; Mon 07:15 U07, 07:40 login, 08:20 check, 08:25 retry, 09:05 LIVE, 09:09:30 P09, 09:45 depth, 15:50 SCORE; nothing on Tue 24 | - |
| J4 Fake-clock Monday | DONE | J4_fakeclock.md 57/57 (last FAIL fixed 17:40) | - |
| J5 Monday instrument file vs Friday | IN PROGRESS | J5_instruments.md dry runs 1-2: 224 names, 0 leaving, Dec lots = Nov | Monday 08:15 live check is not scheduled (nothing calls j5_instruments.py). Monday duty or a timer |
| J6 Silence every old sender | DONE (2 gaps) | 14/14 senders muted; 74 units parked (running 0, enabled 0); 7 cron lines parked; OLD_AI_OFF flag 10:06; one 07:15 / 19:45 note | (a) The park missed writers that only run in market hours (findings 1-4). (b) "Old page sounds at /" not shown: girtrader.com "/" still serves the old home.html, which has chime / ring code |
| J7 Fallback switch safe and his | DONE | gir mode new / old / status; Settings button (82 PASS); /gir command (gir-v2tgcmd active); reasons approved; round trip 18:14 + cron bug fixed | Full cold start of 74 units never run end to end. `gir status` still says "WOULD SEND until the ring test" although trade lines open by code at Mon 09:15 (wording only) |
| J8 Replay isolation | DONE | GIR_REPLAY_NO_TG=1 drop-in on gir-v2replay; own ledger and stores | - |
| J9 09:00-09:30 rules | IN PROGRESS | engine 0.3: 09:15 print out of RVOL5 / ORB / VWAP, IEP-with-zero-quantity rule; desk: shares wait to 09:30 on a shock day, index hands off to 09:20 / 09:30, max 4 BUY NOW a day | Desk snapshot's day RVOL at 09:15-09:20 not checked for the pre-open print; IEP input gone Monday (finding 3). Builder |
| J10 Expiry-day mode | DONE | engine + desk contract.py (Dec stock series, NIFTY next weekly 1 Dec, expiring = info); J4 expiry checks PASS | - |
| J11 AI budget split | DONE - live proof Mon 15:40 | $8 gate on every v2 call; buckets MEET 2.60 / SEATS 1.50 / LIVE 1.80 / READ 1.10 / ASK 0.10 / SHOCK 0.90; floors 1.50 / 0 / 0.50 / 0.60; OLD_AI_OFF; replay ledger separate; PROOF_1600 PASS | Monday "old paths = $0" check |
| J12 Clock / Asia/Kolkata | DONE | NTP synchronized; timers Asia/Kolkata; IST fixes 17:32 | - |
| J13 Restart proof + outside uptime | IN PROGRESS | kill test 18:20 (1 unit); status.json public; outwatch runs on the same droplet | Sunday reboot restart proof; the mid-replay kill at 09:16 / 11:00 (no repeated rings) not run; a truly OUTSIDE monitor on status.json needs the trader's account (a dead droplet raises nothing today). Trader + Sunday duty |
| J14 Rate limits at cold start | DONE - live proof Mon 08:30-09:30 | J14_ratelimits.md: 0 s over any Kite limit after the spacer (model) | grep the logs for 429 Monday |
| J15 His Monday routine | NOT STARTED (trader, Mon 08:25) | - | (1) The new /preview pages have no sound player (settings.js: "The sound player is not built yet"), so "test chime" cannot pass: the rings are Telegram + ntfy - reword J15 or build a chime before the page freeze. (2) PHONE_RUNBOOK says "The page: girtrader.com" (old home page). (3) Runbook Telegram copy not sent / pinned; WHO TO CALL blank. Trader + builder |
| J16 Code freeze Sun 16:00 | NOT STARTED (Sun 16:00) | MARKET_FREEZE lock covers only 09:00-15:35 on trading days | No lock for the Sunday freeze (discipline only). Held-out replay day SUPERSEDED (no rehearsal money) |

## New findings from the server (not in STATUS)

1. **sec.board will freeze at 09:15 on Monday.** The page adapter reads data/sectorboard.json, written only by sectorboard.tick(), which is called only
   from gir-earlyteam's loop in market hours (earlyteam.py ~line 654). gir-earlyteam is PARKED. Last write: Fri 20 Nov 15:30 IST. Readers: the desk
   snapshot (sector rows; "NOT SEEING sec.board" otherwise), analyst/money.py (rotation table), the engine's breadth gate (engine/core.py 624), the
   F1 / F3 / chain pages (desk-common.js D.board). The same adapter also takes world cues from data/morning.json, whose writer (gir-desk) is parked.
   The Saturday dependency trace could not see this: these writers only run 09:15-15:30.
2. **Two decision sources on Monday.** The page's call cards come from the engine (calls.feed = v2/data/calls.jsonl, "new engine only"); Telegram
   BUY NOW comes from the desk. The engine can show GO NOW on the page while the desk says WATCH.
3. **The pre-open data is gone on Monday.** data/preopen.json is written by preopen.py (gir-preopen.timer 09:08, PARKED; otherwise only when someone
   opens the old /preopen page), and data/preopen_hist/<day>.json by gir-prerec.timer (PARKED). The P09 09:09:30 update reads them
   (predict/run.py preopen_live, minute_open_fallback=False), so it runs without IEPs; wsrec / rec record a stale file; the J9 IEP rule has no input.
4. **data/nfo_instr.json (Kite NFO contract master) is written only by posguard.py (gir-posguard.timer, PARKED).** Readers: the page's "expiry"
   feed (MISSING on status.json now), v2/sources/common.py F&O vocabulary, p_calendar, kb/watch. Monday runs on Friday's file (December lots equal,
   so low harm on Monday; wrong from the next lot change).
5. The automatic Kite login has never made a fresh login: the 20 Nov run reused tokens on all four keys. With RAVEN paused, key 1 also needs it.

## Not done, ordered by risk to Mon 08:30 (the next build list)

| # | item | why it matters | next step | who |
|---|---|---|---|---|
| 1 | J1 / A1 Kite auto-login unproven | if 07:40 fails, no prices, no chains, no GIFT, no positions read ("risk gates blind") | Run the J1 Sunday dry run (login + check, once, after 16:00) and add it to the Sunday duty list; confirm key 1 logs in through gir-kitelogin with RAVEN paused | Sunday duty |
| 2 | Finding 1: sec.board writer parked | desk sector driver, rotation table, engine breadth, sector pages blank / STALE from 09:15 | Before Sun 16:00: a kept runner that calls sectorboard.tick every 3 min 09:15-15:30 with its Telegram muted (it has GO NOW rings) and no AI, or unpark gir-earlyteam muted with OLD_AI_OFF; prove it on Friday's recorded quotes on a fake clock; add to keep.txt. Also decide the morning.json cues | builder |
| 3 | Finding 3: pre-open writers parked | 09:08 pre-open update without IEPs; J9 rule blind | Timer for preopen.py WITHOUT --send 08:59-09:20 each minute + re-enable gir-prerec (copy only); add both to keep.txt; fake-clock test | builder |
| 4 | Re-trace the park by code | findings 1, 3, 4 show the Saturday mtime trace misses market-hours writers | For each of the 74 parked units, list the files its code writes and grep v2 / the page for readers; Monday 09:20 check status.json "not_live" / STALE | builder |
| 5 | Finding 2: two GO sources | the trader may act on an engine GO NOW the desk rejected | Decide before the page freeze: label engine cards "ENGINE (rules) - not the desk's call" or hide engine GO NOW on Monday | trader decides, builder |
| 6 | F4 ring test + token rotation order | rotation after 18:30 breaks the proven sender path | Trader rotates BEFORE 18:30 (then restarts + ring test) or after Monday | trader + Sunday duty |
| 7 | J15 rings / address / runbook | the 08:25 "test chime" cannot pass; runbook points at the old home page | Reword J15 to Telegram + ntfy (or build a chime before the freeze); fix the runbook address; send + pin the runbook copy; fill WHO TO CALL | trader + builder |
| 8 | Finding 4: nfo_instr.json writer parked | expiry / lots feed and the sources' F&O vocabulary on Friday's file | Point those readers at v2/data/instr/NFO_<day>.csv (gir-v2opt) or run only posguard.instruments() at 08:00 | builder |
| 9 | J13 outside monitor + reboot proof | a dead droplet raises no alarm today | Trader sets an outside monitor on status.json; Sunday reboot + restart table | trader + Sunday duty |
| 10 | F5 CPU peak | 4 cores ran 86-92% on Friday | Measure at the 17:00 mock; drop depth names first if > 80% | Sunday duty |
| 11 | D4 page sweep | page freeze Sun 16:00 | Finish all 23 pages x 1366 / 1600 / 390 + R51, fix before 16:00 | builder |
| 12 | J5 Monday 08:15 check | not scheduled | Timer or Monday duty step | builder / Monday duty |
| 13 | F2 flip both ways for real | mock covers MOCK lines only | Optional real flip with the trader watching, or accept the mock | trader decides |
| 14 | B6 desk proof | desk BUY NOW chain proven only with stand-in brains | One real-model run on the 7 known bad cards (< $1, own line) | trader approves spend |
| 15 | A8 / A2 tables | proof format | Subscriptions "tested at" table; F01-F31 table with replacements | builder |
| 16 | J9 desk RVOL at 09:15 | pre-open print may inflate early RVOL | Check snapshot rvol source; exclude 09:15 print or label it | builder |
| 17 | G2 score the watches | owed to the desk | Code only, $0 | builder |
| 18 | I1 attachments; I3 / I5 latency | week 1 / paid | Attachments in week 1; paid wire only with the trader's yes | builder / trader |
| 19 | engine_next behind live (ai.py) | confusion only | Sync or retire engine_next | builder |
