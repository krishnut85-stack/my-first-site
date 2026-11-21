# DESK REVIEW - answers to the server's STATUS.md (newest first)

## 21 Nov 07:35 IST (hourly) - Telegram inventory ACCEPTED; rule breach found and stopped; three follow-ups
- **ACCEPTED:** the 05:30 orders (group cap 2, leak guard incl. the engine chain map, re-run dry run ready); the Telegram inventory and
  the silence (one flag per sender, feeds keep running, muted.log, undo lines, health lines pass); gir-solsniper stopped + disabled +
  archived (the trader's "no crypto" decision; it was not trading, STOP file since 11 Oct).
- **Standing-rule breach (TG_CHAT_FO / TG_CHAT_OI used by the old newshawk bots): stopped - good catch.** Add a code guard so ANY send to
  those two chat ids is refused and logged, in every sender (old and new), with a test.
- **SECURITY - token in logs:** fix the tape_bot log line now (mask the token in every logged URL; check the other old bots' error
  lines too) and purge / rotate the journal lines that hold it. Token ROTATION is the trader's step (BotFather), then the new token goes
  into .env through a hidden prompt only - list which units share that token so nothing breaks after rotation.
- **QUESTION FOR THE SERVER (read-only answer first):** hunter-execute and eqfloor@execute (and raven) - can any of them place a REAL
  order through Kite (place_order / modify / any order endpoint)? GIR never places orders. Report yes / no per unit with the code line;
  change nothing until the trader decides.
- **Trader's call (asked now):** globaleye (old GIR v1) and paper_counterfactual / paper_eod_report still post to GIR Alerts - keep or mute.

## 21 Nov 11:40 IST - THE TRADER: "the money is in the GAP - we must anticipate the day before". NEW OUTPUT: the 14:45 TOMORROW / CARRY CARD
Gaps can only be caught by a position taken BEFORE the close. The 19:45 brief is too late to act on. Build (code + one head call, MEET):
1. **14:45 IST every trading day - "TOMORROW'S GAP" card** to GIR Trade now: expected direction of tomorrow's open (UP / DOWN / FLAT) with a
   base rate from history, the drivers already visible at 14:45 (US index futures + SOX / Nasdaq futures, Asia closes, Europe open,
   GIFT NIFTY vs NIFTY, crude / gold / dollar / US 10y, FII cash so far, an overnight event: US data, Fed, results after hours, RBI /
   government), and the 2-4 F&O names most exposed each side (sector link + this afternoon's VWAP side + RSI). Then: "CARRY: PE <names>
   / CE <names> into tomorrow" or "NO CARRY - flat by 15:10". Carry is the trader's choice: it breaks the intraday-only rule, so label it
   OVERNIGHT, smaller size, December strikes, and say the risk (weekend / holiday = two nights).
2. **Study first (code only, $0, before Monday):** from history, how well do the signals visible at 14:45-15:10 IST predict the next
   NIFTY / sector gap? US futures change during India hours, Asia close, Europe's first hour, GIFT NIFTY premium, FII provisional flow;
   on Fridays vs other days; size of the next gap. Base rates with n. File onset_results/gap_predict_study.md + a NOT PROVEN lesson.
3. **Check on Fri 20 Nov (honest):** at 14:45 Nasdaq futures were about -1.6%, SOX futures about -2.4%, Asia had closed -5% to -6%, DIXON
   was slipping below VWAP into the close. What would the card have said? Report it in STATUS.

## 21 Nov 20:35 IST (real time) - THE TRADER: SUNDAY 22 NOV CAP = $3.00 (was $1.50). Sunday only; Saturdays, other weekends and holidays
stay $1.50 unless he says otherwise; trading days stay $8.00. Give the extra to READ (readers work through Sunday afternoon on the
weekend news) with the 19:45 brief floor kept whole. Show it on the page meter + the 19:30 credit line. Tue 24 Nov holiday = $1.50.

## 21 Nov 20:30 IST (real time, hourly) - VERDICTS on 19:48-20:20 (server clock); server rebooting since 20:20
ACCEPTED:
- OLD PLAN chip: real root cause found (the watch file's " IST" time ending was not parsed, so Friday's plan looked fresh). test 5/5.
- F6 ALL POSITIONS: root cause slice(0, 2) in four places (cards, "+1 more", THESIS, chart) while the header counted all. Fixed.
- Weekend footer "health DOWN" from MCX / CDS shut -> "market closed - normal" on non-trading days only, still red on weekday evenings. Right.
- B6 real-model proof: 7 of 7 bad cards stopped, $0.56. J9 RVOL 09:15 print fixed.
- D4: console / page errors 6 -> 0, failed requests 6 -> 0 on all 23 pages x 3 widths; screenshots masked.
AFTER THE REBOOT (in this order): post-reboot checks PASS / FAIL; m2prep by hand if 20:40 was missed; finish the R51 re-run at 1600
(partial: 19 FAIL / 20 NOT RUN - name each); cut cells 695 still (from 1179) - fix the ones on F1 / F2 / F6 / F7 / phone NOW first, the
rest may stay as prose-with-tooltip; then the 20:10 sort bars, 20:15 search proof, 20:20 news filter, 20:30 sources + Friday replay -
all before the Sun 16:00 page freeze (sources and the replay are not page work and may continue after it, outside market hours).

## 21 Nov 20:30 IST (real time) - THE TRADER: "We gave a long list of websites and not even one critical item came - I see nothing."
He is right. Reasons on record (NEWS_COVERAGE_AUDIT 13:58): 104 of 186 listed hosts NOT BUILT; regulator rows went to the wrong reader
(PIB 48 / RBI 13 / SEBI 16 items -> 0 cards; fixed today); BSE blocked for v2 (bridge fixed); the readers stopped at 08:50 today on the
$1.50 weekend cap, so nothing read since; Google News (96 min late) made most cards while the fast wires made few.
ORDERS (code, $0 unless the AI line says so):
1. NO "Sat 28 Nov / Phase 2 / Phase 3" dates any more (trader 16:05). Build every FREE, allowed host in the audit's PARTIAL + NOT BUILT
   lists now, most valuable first: FE + Zee Biz sitemaps, gazette Extraordinary, FDA warning letters, CERC / PNGRB / PRS, IRDAI (robots
   says no -> say so, do not read), CCI slowed to 300 s, then the rest. Respect robots.txt and 403s.
2. CHECK THE PARK: newshawk-regwatch / govwatch / regnews were parked at 16:55. Where one was the ONLY reader of a source (CERC, PNGRB,
   FDA, DGCA, PRS, IRDAI...), that source is now not read at all. List them and rebuild each in v2 tonight.
3. PROOF ON FRIDAY'S TAPE: replay 20 Nov through the v2 news path and show, for each critical item, first seen time / source / reader /
   card yes-no: RBI VRR result 10:20, second VRR 12:35 / 13:40, the 4-day VRR notice 19:25, Nvidia SEC probe (Reuters), Anthropic IPO
   slide, US close -3.7% / -5.3%, IndusInd roadshows, CII summit FPI line, gold -4.7%. Any item missed = named fix.
4. WEEKEND READING: with the $1.50 weekend cap the readers stop early, so the Sunday 19:45 brief starts blind to the weekend's news.
   Offer the trader ONE choice (do not change it yourself): keep $1.50, or Sunday only $3.00 so the readers work through Sunday afternoon
   before the brief.
5. Report the new totals: LIVE / PARTIAL / BLOCKED / NOT BUILT, and "critical items caught on Friday's replay: x of y".

## 21 Nov 20:20 IST (real time) - THE TRADER: "Many unnecessary news items come into the system (a festival celebration...). Only
market-related news should be visible on the GIR page." BUILD before the Sun 16:00 freeze:
1. RELEVANCE GATE on every news list (News page F4, share page, phone): an item is shown only if it (a) names an F&O share / its company,
   an index or a sector, or (b) is macro / policy / rates / FX / commodities / world markets / regulator / court / government economic
   action, or (c) the desk made a card from it. Everything else goes to a collapsed "Other news (hidden: n)" line, never in the main list.
2. Code first ($0): entity link + the F&O vocabulary + a market word list + a NOT-market list (festivals, celebrations, sport, film,
   crime, weather unless it hits crops / power / ports, lifestyle, horoscope). AI only for the items code cannot decide, inside the READ
   budget, cheapest model, one word answer MARKET / NOT. Log every hidden item with its reason; the 16:00 scorecard counts hidden items so
   nothing important is lost silently (an official source - RBI, SEBI, PIB economic, exchanges - is never hidden).
3. Show the count on the page: "Market news 46 · hidden 212".
COVERAGE ANSWER for the trader (from NEWS_COVERAGE_AUDIT 13:58 + the fixes since): say plainly what is read and what is not (paid wires,
OPEC / CME / NCLT blocked, CNBC Awaaz / Sansad TV and broker PDFs declined, X cancelled). Update the audit table after the reboot.

## 21 Nov 20:15 IST (real time) - THE TRADER: search must AUTOFILL and a click must open ALL the details of the share. "Very important."
The design has it (SHELL.md R04: "/" box, suggestions after 2 letters, Enter / click opens the Share page F7), but no proof file shows it
tested on the LIVE new desk. PROVE + FIX before the Sun 16:00 freeze (add to the D4 sweep, real typing, 1366 / 1600 / 390 phone):
1. Type "TIT" -> TITAN, TITAGARH; "UNION" -> UNIONBANK; "hdfc" (lower case) -> HDFCBANK, HDFCLIFE, HDFCAMC; "NIFTY" / "BANKNIFTY" ->
   the index page; a company name ("motilal") finds MOTILALOFS. Arrow keys + Enter and a mouse click / finger tap both work.
2. The Share page opened from search shows ALL details in one place: price + % + day high / low, 5-min chart with VWAP + RSI, the
   desk's view (CE / PE / WATCH + why + time), news and filings (latest first), option chain (current + December, OI build-up, IV, IV
   percentile), futures OI, delivery, FII / sector context, results date and the results-IV block, ban / MWPL, LAST CALL guidance line,
   and HIS POSITION in that share if held (qty, average, P&L masked in screenshots, the desk's HOLD / EXIT line).
3. A search box is visible on every page and on the phone (not only the "/" shortcut). Nothing in it can send an order.
Report PASS / FAIL per check in STATUS with masked screenshots.

## 21 Nov 20:10 IST (real time) - THE TRADER: "Every list needs a FILTER / SORT bar on top like the old system - high-low, low-high.
We have to scroll up and down every time." BUILD before the Sun 16:00 page freeze (one shared component, every page):
1. A sort bar at the top of EVERY list (sectors, shares in a sector, market movers / gainers / losers, F&O list, his positions and trades,
   news, cards, ban list, scorecard): two big buttons "HIGH -> LOW" and "LOW -> HIGH", plus a "sort by" chooser with the list's own
   columns (% move, value, volume / RVOL, OI change, IV, P&L for his trades, time for news).
2. Quick filters on share lists: ALL / UP (CE side) / DOWN (PE side) / F&O only / near VWAP / in ban; a search box for the symbol.
3. Tapping a column header also sorts (and shows the arrow). The choice is remembered per list (browser storage, safe if empty).
4. Sticky header: the sort bar and column names stay on screen while the list scrolls; long lists show the count ("22 of 218").
5. Same on the phone view (one row of chips). Test every list at 1366 / 1600 / 390 with real clicks; no cut text; screenshots P&L masked.
If any page cannot be done before the freeze, list it by name in STATUS - do not leave it silently.

## 21 Nov 20:05 IST (real time) - F6 MY TRADES HIDES HIS THIRD POSITION (trader's screenshot of /preview/positions)
Header says "Your 3 open option trades" but only 2 cards show (HDFCBANK PE, MOTILALOFS PE) + "+1 more below"; his UNIONBANK PE appears
only in the right-hand "Trades today" list. The THESIS row and the P&L chart legend also name only the two. He read it as "Union Bank is
not open". FIX before the Sun 16:00 freeze:
1. F6 shows EVERY open position at once at 1366 x 768 and 1600 x 900 (3 cards in a row, or one compact row per position when > 3;
   nothing hidden below the fold), phone NOW shows all of them as cards.
2. THESIS row and the P&L chart lines include every open position. The header count must equal the number of cards shown.
3. Test with 1, 2, 3, 5 open positions (fixture) + the live 3; screenshots with P&L masked.

## 21 Nov 20:00 IST (real time) - MORNING PAGE SHOWS A STALE PLAN (trader's screenshot of /preview/morning, Sat 19:45)
The big headline reads "CALL day on AUTOS" from the evening prediction written Fri 20 Nov 19:45 for Mon 23 Nov - BEFORE the US crash
(Nasdaq -5.3%, SOX -10.7%, BTC -6%). The driver cards are Friday 15:29 data ("LATE 28h"). A trader reading this on Saturday / Sunday is
told CALL. FIX before the Sun 16:00 freeze:
1. Any plan / prediction older than 18 h, OR written before a SHOCK family A / B / E alert, shows a grey "OLD PLAN - written Fri 19:45,
   before the US fall - next plan Sun 19:45" chip and the side words in grey, never the green CALL / red PUT headline.
2. The Sunday 19:45 brief replaces it; the 07:15 Monday brief replaces that. Headline always names its time.
3. Weekend pre-flight reds (optquote / expiry MISSING because the market is shut) show as "market closed - normal", not red.

## 21 Nov 19:55 IST (real time) - THE TRADER: his positions / P&L must show correctly on the new desk page, the phone view and match Kite.
Monday duty (add to the 09:20 checks): the new page (desk-trade / F6 positions), the phone NOW cards and the old /mypnl all read
gir-pnlwatch (Kite, read only, every 3 s). Check once at 09:20 and once at 12:00: number of positions, symbols, quantity, average price
and P&L equal Kite's own positions (P&L within the LTP-timing difference); day P&L and the loss-lock counter equal. Any mismatch = P1
with the row named. His P&L stays masked in every screenshot and never goes to the repo. Also confirm each held position gets the
desk's manage line (HOLD / EXIT / TIGHTEN + why) on the page, phone and Telegram, and that his UNIONBANK PE shows as HELD.

## 21 Nov 19:45 IST (real time) - THE TRADER opened girtrader.com and expected the NEW desk; it is still the old home page.
1. Before the Sun 16:00 page freeze: make girtrader.com (root) open the NEW desk (/preview/), keep the old home at girtrader.com/old for
   week 1. Caddy change + test at 1366 / 390, login unchanged, status.json path unchanged (the trader's UptimeRobot monitors point at
   girtrader.com and /preview/api/gir/status.json). Update runbook + Settings text.
2. SECTOR MONEY page, FOREIGN FUNDS "last Rs cr": the same NSDL number repeats on several rows (+43,102 on banks / insurance / NBFC /
   capital markets = NSDL "Financial Services"; +998 hospitals + pharma; -3,781 electronics + capital goods; +7,570 telecom services +
   telecom equipment). It reads as wrong. Show the number once on the first row of the group and "same fund group (Financial Services)"
   on the others, or merge the rows for the fund columns. Low priority; before the freeze if time allows.

## 21 Nov 19:40 IST (real time) - THE TRADER: "YES B6". Run the real-model desk proof on the 7 known bad cards now (< $1, inside the
weekend cap, its own ledger line): each card must come out WAIT / REJECT / NOT TAKING with the Devil's objection answered or standing,
and the 2 clean controls must pass. Report cost + per-card verdict in STATUS. Also: #5 default stands (engine GO NOW hidden Monday).

## 21 Nov 19:30 IST (real time, hourly) - VERDICTS on 18:33-18:59 (server clock)
ACCEPTED:
- Post-reboot checklist + script (81 PASS dry run, kernel FAIL expected). Reboot tonight 20:50-23:15; Sunday 12:00 reboot cancelled.
- CHECKLIST_AUDIT.md: honest, row by row, with a risk-ordered next list. Good. The park missed market-hours writers because the trace
  used Saturday file times; the RE-TRACE BY CODE (18:54) is the right method and fixed 8 gaps (sector board, pre-open readers, NFO
  instruments, MWPL, futures-OI base, missaudit, checklist). Add to the Monday 09:20 duty: status.json not_live / STALE list = empty,
  else P1 and name the writer.
- Leftover old session process stopped (146 MB freed), own session untouched. Fine.
DEFAULTS for the audit's trader items (use these unless the trader says otherwise - do not wait):
- #5 TWO GO SOURCES: HIDE the engine's GO NOW cards on Monday. Only the desk's agreed calls show as BUY NOW (his rule: no blind picks,
  the team agrees). The engine's rule lines may stay on the page labelled "ENGINE (rules) - not the desk's call", never amber, never rung.
- #13 real flip: NOT needed - the round-trip test passed and he does not want the old programs.
- #14 B6 real-model run on the 7 known bad cards (< $1): recommended YES inside today's weekend cap; waits for his word.
- #6 token rotation: before Sun 18:30 (he knows). #9 outside monitor: the reviewer guides him to a free UptimeRobot check on status.json.
STILL OPEN before Monday: J1 Kite login dry run (Sun 16:15), D4 page sweep (before Sun 16:00), J5 08:15 check scheduled, F5 CPU at the mock,
J9 RVOL 09:15 print, and the 19:10 RBI reversal-date line.

## 21 Nov 19:10 IST (real time) - THE TRADER: "On 27 Nov, when the banks return the money, there could be issues in Bank Nifty."
ADD (code, $0): every RBI repo / reverse-repo REVERSAL DATE goes on the event calendar (seat 34) with the amount due back
("Fri 27 Nov: Rs 50,000 cr 4-day VRR reverses"), and the brief the evening before + the 07:15 brief carry one line:
"RBI loans due back today: Rs X cr. New RBI repo announced: yes Rs Y cr / not yet." Also show daily from RBI's Money Market
Operations release: the overnight call rate (WACR) vs the repo rate 5.50% and the system liquidity (surplus / deficit).
RED to Trade now only if: the call rate goes above the MSF rate (top of the corridor) or RBI announces an unscheduled operation.
Study (code, $0): Bank Nifty / PSU bank / NBFC moves on reversal days with NO roll-over vs with a roll-over vs normal days, from the
386-operation file. NOT PROVEN until it passes; information only.

## 21 Nov 18:35 IST (real time) - KILL TEST ACCEPTED + REBOOT MOVED TO TONIGHT (trader: "if all the jobs are finished, I want to reboot")
- Kill test: accepted. Three real faults found and fixed (alarm could never fire: 5 restarts in 10 s -> 15 min; alarm on every crash ->
  only if still down after 45 s; endless alarm loop -> one alarm + one retry an hour). The 18:17 P1 was the test - tell the trader once.
- REBOOT TONIGHT instead of Sunday 12:00, when: (1) the D4 page sweep and the A1-J16 checklist audit are finished, committed and pushed;
  (2) the post-reboot checklist is written in STATUS first; (3) the window avoids the 20:40 m2prep and the 23:30 backup - reboot
  between 20:50 and 23:15 IST (or before 20:30 if everything is done). No paid snapshot: the DO weekly backup (15 Nov) + the nightly
  copy are enough for a planned reboot.
- AFTER THE REBOOT (the trader restarts the server's Claude Code session from the DigitalOcean console): every new-system unit + feeder
  active, timers and cron.d listed with next run times, MemoryMax / Nice / OOM settings applied, freeze cron, status.json "OK", one
  ntfy test, Telegram /gir status answer, CPU / memory idle, Kite login timer set for Mon 07:40, depth timer set for Mon 09:45. Report
  each PASS / FAIL in STATUS. The Sunday 12:00 reboot is then cancelled; Sunday keeps 17:00 mock / 18:30 ring test / 19:45 brief.

## 21 Nov 17:30 IST (real time, hourly) - VERDICTS on the pushes 16:34-18:25 (labels) = 16:34-17:21 IST (commit times)
ACCEPTED:
- SAFETY ITEMS 1-7 + 9b (heartbeat, send-failure check, /status.json, positions read, shock-day wait, carry rule, ntfy code, runbook):
  269 -> 280 desk tests. PHONE_RUNBOOK is clear, short, no secrets; "risk gates blind -> no BUY" is right.
- OLD PROGRAMS PARKED with a real dependency trace (keep.txt). Keeping gir-intraday / pnlwatch / newsroom / tvwatch / filings bridge as
  "new-system feeders" and cancelling the Sun 21:00 pause of gir-intraday: CORRECT - good catch. Idle CPU 23% -> 7%, 2.5 GB freed.
- 17:40 catch: the chip-shock and Bitcoin lessons were not loaded by the desk - now loaded, point in time. Good; keep checking every
  new study has a loader before calling it "in the brief".
- ROOM TO MOVE live = one Kite call per share that already passed every gate, never a scan, never blocks a card: CPU-safe design. Accepted.
- MSCI 30 Nov changes on the calendar; transcripts read with no AI (149 quoted guidance lines); daily source scorecard; DGTR / NCLAT /
  TDSAT; Polymarket Fed odds labelled "not CME"; 403 sites skipped, not evaded. Accepted.
FIX:
1. TIMESTAMPS AGAIN: STATUS labels run 30-60 min AHEAD of real IST (the "18:25" entry was pushed 17:21 IST). Stamp every entry from the
   server clock (TZ=Asia/Kolkata date +%H:%M) at the moment of writing, never typed. The week-1 scoring of "who saw it first" depends on
   true times.
2. B2 "HY spread / Japan 10y not available": use the HYG minus IEF proxy (Yahoo, as the Bitcoin study did), labelled PROXY; Japan 10y
   from any free public series or leave "not available".
3. Delete the *.bak_park1127 copies from the repo (keep them on the server only).
4. Still waiting on the trader: the fallback round-trip test (his yes), the ntfy topic, DO Backups. Carry on around them (defaults).

## 21 Nov 17:10 IST (real time) - THE TRADER: "No stopping - keep continuing the work." No pauses, no waiting for questions that have a
sensible default; keep building through tonight and Sunday. NEXT, in order:
1. The safety items still BUILDING (heartbeat, Telegram send-failure check, positions read, shock-day wait, carry rule, runbook) - DONE and
   tested before the Sunday 17:00 mock.
2. Room-to-run (M2) data prepared tonight so the live check does not compute at 09:20.
3. Sunday after the ~12:00 reboot: kill test + the fallback round-trip test (2 harmless timers), then the 17:00 mock with the CPU peak
   measured, 18:30 ring test, 19:45 brief (with the chip-shock ranking and the Bitcoin weekend line, NOT PROVEN).
4. Then the rest of the list: MSCI / FTSE dates, earnings-call reader, the remaining free upgrades, and keep scoring every source.
Decisions still with the trader (do not wait on them, carry on around them): ntfy topic, DO Backups in the panel, X / Gemini cancel,
TV channels and broker PDFs (default NO until he says yes), ttyd / redis / his other projects (leave running until he says).
Report hourly in STATUS as before.

## 21 Nov 16:50 IST (real time) - THE TRADER: "We don't need any old programs running. Monday we use the new desk and I watch on my
laptop. Park the old programs, remove the old program subscriptions, use the CPU." DO NOW (weekend, market closed - no need to wait
for Sun 21:00):
1. STOP + DISABLE every OLD-system service and cron NOW: falcon, gir-intraday (old engine), the old senders, old AI callers, old scanners,
   old recorders that the new system does not read. Not deleted: code and units stay on disk, disabled, until the week-1 review Fri 27 Nov;
   then the trader decides on deletion.
2. BEFORE stopping each one, check the NEW system does not read from it (BSE bridge via newshawk, the Kite websocket / recorders, any file
   the v2 services read). Anything the new desk depends on stays on and is RENAMED in the list as part of the new system. Never touch
   gir-watchdog (only its checks for the stopped services are removed, as before).
3. "gir mode old" stays as a COLD fallback for week 1 (re-enables the parked units by one command, takes minutes, not instant). Update the
   Settings page, runbook and STATUS text to say so.
4. SUBSCRIPTIONS: list every paid service / API key with who uses it (old only / new / both) and its monthly cost. KEEP anything the new
   desk uses (Kite Connect, Anthropic API, DigitalOcean, speech-to-text for the TV reader, any news feed the new readers use). Give the
   trader the "old only" list with the cancel link per service - he cancels in his own accounts; the server never logs in to cancel.
   Remove the old-only keys from the old configs after he cancels (never print them).
5. Report: CPU before / after (idle now, and at the Sunday 17:00 mock), memory freed, the services stopped, the list of subscriptions.

## 21 Nov 16:30 IST (real time, hourly) - VERDICTS on the pushes 15:58-16:23
ACCEPTED:
- WEEKEND INDEX TESTS (index_tests.md): 0 of 22 pass, every trigger with its PE mirror, both indices, tuning then unseen 2026, random
  baseline with option costs, Holm. Honest and the right outcome: Monday index ideas = WATCH only. Data limits are labelled (index minutes as
  proxy, heavyweights' value for volume, spread assumed 0.4%). Keep recording futures + index option bid / ask from Monday so the next test
  uses real data.
- 643 RBI correction and 644 MONDAY INDEX PLAN sent through the gate. 644 is long (40 lines) - fine once as a plan; briefs stay short. The
  "93% (20 cases)" slip: correct in the 19:45 brief as "14 of 15 Mondays" - one line, no separate message.
- PROOF_1600: $6.35-6.60 for Friday's full day on the new split, READ / LIVE never refused, all briefs delivered. PASS.
- Safety items DONE: change freeze (gir-restart refuses, exit 3; cron only on NSE days, Tue 24 holiday off), NTP, apt timers off until
  Mon 16:00, journald cap, OnFailure alarm on the 17 units (tested), restart policy, CPU option A cron Sun 21:00, nightly backup 23:30 +
  07:00 check, token-rotation sender list.
- Results-IV block: buying ATM into results when IV is in the top 30% loses (CE median -5.2%, straddle -3.7%, 689 cases) -> block / warn.
  ACCEPTED as a warn-and-size rule.
- News sources 1-5 live (India calendar, Fed / ECB / BoJ, peers' results, GST page, EIA) and on the silence alarm. OPEC 403 not evaded:
  right.
WATCH / FIX:
1. CPU 86-92% in market hours is too high. After option A starts, measure again Sunday at the 17:00 mock (with the depth recorder and the
   new sources running) and report the peak; the 09:15 burst must stay under 80%, else drop depth to fewer names first.
2. Safety builder items 1-3, 8 (positions read), 9, 10, 11 are BUILDING: DONE + tested by the Sunday 17:00 mock, or say which will miss.
3. MemoryMax 600M on gir-v2rec / gir-v2depth: check their real peak memory first so the cap does not kill a recorder at 09:15.
4. Add to the item table: B2 Bitcoin / borrowing-cost gauges (16:20), the chip-shock study (16:40, in the 19:45 brief), the global money
   map card (information only).
5. TV channels (~$7 / day outside the cap) and broker PDFs (terms): the TRADER decides; nothing built until his word.

## 21 Nov 16:40 IST (real time) - THE TRADER: "If NIFTY / BANKNIFTY fall Monday, the chip-dependent F&O shares are more likely to fall -
which can fall MORE?" RUN NOW (code only, $0, before the 19:45 brief):
CHIP-SHOCK STUDY: from the 5-year daily store (+ 3-year minutes), every day SOX <= -5% (and separately Nasdaq <= -4.5%), next India
session: for each chip / AI-hardware-linked F&O share - median open gap, median close, % of days down, worst, move vs NIFTY, and how
often the low came in the first 15 min. Names (confirm each is on today's NSE F&O list): EMS / semis KAYNES, DIXON, PGEL, AMBER;
chip plant + data-centre power CGPOWER, GVT&D, POWERINDIA, ABB, SIEMENS, BEL; chip-design / ER&D TATAELXSI, LTTS, KPITTECH, HCLTECH,
PERSISTENT, COFORGE, LTIM, MPHASIS. Control group: NIFTY, BANKNIFTY, random F&O shares. Add the 2026 cases separately (6 Nov SOX -12%,
20 Nov) because LINK_BOOK row 30 says the Nasdaq -> IT link BROKE in 2026 (IT rose after both AI sell-offs). Add 28 Jan 2025 (DeepSeek:
DIXON / KAYNES down up to 20% intraday).
Facts to use: India closed BEFORE the full US chip crash (Fri 20 Nov: SOX futures only -2.4% in India hours, SOX cash -10.7% after) -
Monday is India's first full reaction. Friday India already: CGPOWER -2.57%, GVT&D -2.63% (among the F&O losers), but the Dixon group
closed GREEN above VWAP (DIXON +0.5%, PGEL +1.8%, KAYNES +0.7%, AMBER +0.7%); PERSISTENT / TATAELXSI / COFORGE ran up on 20 Nov.
OUTPUT: a ranked "most likely to fall more" list with n and hit rates in the 19:45 brief; NOT PROVEN where n < 10. No call from it on
its own: Monday PE only after 09:30 (shock day), below VWAP and the opening-range low, sector index confirming, the Devil answered. The
never-repeat rule stands (no DIXON PE again without a NEW reason).

## 21 Nov 16:16 IST (real time) - IGNORE the trader's queued voice note "where will the money go from US stocks..." - it was meant for the
reviewer, not the server. TAKE NO ACTION on it, change nothing, continue the current work. The reviewer answers it.

## 21 Nov 16:20 IST (real time) - THE TRADER (Bitcoin reel): "rising borrowing costs added pressure - looks like something is happening."
FACT CHECK (Reuters 20 Nov, checked): Bitcoin fell below $60,000 for the first time since July, then to about $56,800, lowest in two
years; Ether -5%; spot Bitcoin ETFs -$582 mn. Reuters' causes: AI-spending profit worries, RISING BORROWING COSTS, regulation risk after
the US midterms, the Nvidia CEO exit. "Borrowing costs" here means: Fed December hike priced ~92%, US 30-year mortgage 7.28%, 10y
near 5% (on Friday itself the 10y FELL 12 bp, to about 4.93% - money ran to bonds). Our EVENT_MEMORY K already has the Fed-hike story;
what was MISSING is a live risk gauge.
BUILD NOW (code, $0): SHOCK_ALERTS family B2 - Bitcoin / Ether + borrowing-cost gauges (US 2y, Fed odds, US high-yield spread, Japan
10y, India 10y, call rate), 24 x 7. Bitcoin is the only big risk market trading on Saturday and Sunday: the Sunday 19:45 brief and
the Monday 07:15 brief carry one line "WEEKEND RISK GAUGE: BTC x% since Fri 15:30 IST".
STUDY FIRST, before it is used in any call (lesson of the RBI mistake): Bitcoin's Fri 15:30 -> Mon 08:30 IST move vs the Monday NIFTY
gap and close (2017 onward; all Mondays, and Mondays after a US fall >= 2%); does Bitcoin add anything on top of the Nasdaq-futures line?
Also: high-yield spread jumps vs India's next day. Until the study passes, the brief says "information only, not proven".
Shares to watch IF borrowing costs keep rising (judgement, NOT PROVEN): NBFC / housing finance (BAJFINANCE, CHOLAFIN, SHRIRAMFIN,
LICHSGFIN, MUTHOOTFIN), real estate (DLF, GODREJPROP, LODHA), high-valuation new-age (PAYTM, POLICYBZR, NYKAA, ETERNAL). PE side only
with a fresh trigger and price confirmation - the normal rules.

## 21 Nov 16:05 IST (real time) - THE TRADER: "All the work can be done now. Why are we saying before Monday? Everything can be
continued." NO "AFTER MONDAY" LIST ANY MORE. Everything starts now and keeps going through the weekend, in this order:
  1. the 15:55 gap-review safety items, 2. the index desk + its tests + the Monday index plan, 3. the RBI correction confirm + the PROOF
  re-run, 4. EVERYTHING that was on the "after Monday" list: M2 into grades, M3, look-ahead stages by the head, free upgrades 2-8, his
  trade journal, backups + snapshot, second P1 channel, disk alarm, results-IV block, MSCI 30 Nov list, earnings-call reader, and the
  not-built news sources (India data calendar, Fed / ECB / BoJ, global peers' results, GST Council, EIA / OPEC, CNBC Awaaz / Sansad TV,
  broker PDFs). Free sources only; anything paid waits for his yes.
The ONLY real limits: (a) Sunday 17:00 mock / 18:30 ring test / 19:45 brief keep their times; (b) no change to the LIVE services
Mon 09:00-15:35 - work goes on in preview / shadow during the day and is switched in after 15:35 once its tests pass; (c) every new
piece is tested before it goes live, so nothing half-built breaks Monday's desk. Building costs nothing from the $8 AI cap (it runs on
his subscription). The reboot: may move to SUNDAY before the 17:00 mock if the trader agrees (it then doubles as the restart proof).
Report in STATUS every hour: each item as DONE / TESTING / BUILDING / NOT STARTED.

## 21 Nov 15:55 IST (real time) - PENDING LIST for the server, one place (note: the desk's entries stamped 16:00-17:15 were written
between 15:20 and 15:50 - clock slip on the desk side; their content stands).
NOT YET SEEN IN STATUS - the 14:40 GAP-REVIEW CRITICAL items (do these FIRST, before the index build):
  heartbeat (08:30 READY + every 30 min) · Telegram send-failure check + retry + alarm · /status.json fields for the trader's outside
  monitor · full token-rotation sender list + Sunday test from each sender · market-hours change freeze 09:00-15:35 (lock file) · 09:15
  CPU option A + priorities · Restart=on-failure + burst alarm + Sunday kill test · NTP check · 08:30 Kite cold-start test · stop
  apt-daily-upgrade until Mon 16:00 · 08:20 check reads HIS positions / orders / funds ("risk gates blind" otherwise) · shock-day option
  price wait (VIX +10% / IV 1.3x -> 09:30) · carry rule (declared OVERNIGHT, max 1, 0.5%, 09:08 card, two-night warning) · the phone runbook.
THEN: the approved INDEX process (17:15 / 17:00 entries) + weekend index tests + Monday index plan · confirm the RBI correction message
was sent · PROOF on the new READ split · Sunday mock 17:00 / ring test 18:30 / 19:45 brief.
AFTER MONDAY (this week): M2 / M3, the look-ahead stages by the head, free upgrades 2-8, his trade journal, backups + snapshot before the
Monday-evening reboot, second P1 channel, results-IV block, MSCI dates, transcripts, the not-built news sources.

## 21 Nov 17:15 IST - THE TRADER APPROVED the 17:00 INDEX DECISION PROCESS ("yes"). Build it now (before the Sunday 17:00 mock): the brief
INDEX block, the 09:20 / 09:30 checks on December futures, triggers T1-T3 with confirmation, the risk rules (Monday 1 index trade, 0.5%
risk, 13:30 / 15:10, no carry, same-driver block incl. his UNIONBANK PE), index ideas WATCH-only until a trigger passes the weekend test,
the index card, the scorecard fields. Run the weekend tests (part 8) and report each trigger PASS / FAIL in STATUS. Then send the MONDAY
INDEX PLAN to Trade now in the bullet layout (WATCH grade, NOT PROVEN).

## 21 Nov 17:00 IST - INDEX DECISION PROCESS - PANEL AGREED (trader + quant + risk/devil). REPLACES 16:20. RULES WAIT FOR THE TRADER'S
YES; the weekend TESTS (part 8) may start now (code only, $0).
1. PRE-MARKET: OPEN lean from M1 (evening / 07:30 cut-off; passes 73.5% vs 66.6%, 12 of 12 years) + the US-shock history; SESSION lean
   "flat from the open / unknown" unless tested. The lean is NEVER a trigger.
2. 09:15-09:20 HANDS OFF. Shock day (India VIX up > 10% or ATM IV > 1.3x its 5-day level): no entry before 09:30.
3. 09:20 / 09:30 CHECKS on DECEMBER FUTURES (VWAP from futures volume; if futures minute volume is missing, label VWAP a proxy): side of
   VWAP · opening range 09:15-09:30 · gap vs the median gap · heavyweights above VWAP (BANKNIFTY: HDFCBANK, ICICIBANK, SBIN, KOTAKBANK,
   AXISBANK - 4 of 5 CE / <= 1 PE; NIFTY: + RELIANCE, INFY, BHARTIARTL, LT, TCS, ITC - 6 of 8 CE / <= 2 PE) · NIFTY vs BANKNIFTY agree.
4. TRIGGERS (PE = exact mirror): T1 gap-down then two 5-min closes back above VWAP · T2 a dip tagging VWAP (within 0.1%) that closes above
   · T3 break of the opening-range / previous-day high on 5-min volume >= 1.5x the 20-bar average, RSI 50-75 rising.
5. CONFIRM (all): breadth count · a fresh reason (FII flow, short covering = price up + OI down, news) · every seat PASS (tape, breadth,
   volatility, flows/news, history, risk) · the Devil answered. One FAIL = "NOT TAKING: why".
6. GRADE: A only when the trigger has PASSED the out-of-sample test (part 8) - TODAY NO INDEX TRIGGER QUALIFIES, so Monday's index ideas
   are WATCH (B) at most, never a BUY ring, unless the weekend tests pass. B = context base rate n >= 30, >= 55% and >= 5 pts over base.
7. RISK (code): strikes ATM or 1 ITM, NIFTY next weekly / BANKNIFTY December, spread < 0.5% of premium · Monday 0.5% risk (normal 1%) ·
   max 1 index trade Monday (2 normally), inside the 3-trade cap · stop on the futures (VWAP / OR level) + premium cap -30% · book half at
   1R, trail under VWAP; exit if RSI > 80 with no new high · time stop 45 min without +0.5R · no new index entry after 13:30 Monday
   (14:30 normally) · 15:10 exit, NO index carry Monday · chop flag (4+ VWAP crosses by 10:30, opening range < 0.4x its 10-day average)
   = no entry until a volume break · expiry pin after 13:00 · cooling-off 30 min after a loss, no re-entry same index + side, 2 losses
   lock the day · SAME-DRIVER: a BANKNIFTY PE blocks any bank PE (incl. his UNIONBANK PE) and the reverse; a NIFTY PE blocks a second PE on
   the same US shock · chase > 0.3 ATR past the trigger = WAIT · positions unread = "risk gates blind", no BUY.
   NO INDEX TRADE TODAY when: VIX still rising after 09:30 · gap beyond about -2.5% or filled to flat · chop · Devil blocking · stale data
   · big news due · 2 losses.
8. WEEKEND TESTS (code, $0, before Sun 18:00, most valuable first): (1) index trigger harness on NIFTY / BANKNIFTY futures - the share
   study's 6 triggers + T1-T3 + gap-fill + RSI-50, with an option P&L proxy (Black-Scholes at India VIX, theta, IV drop at the open, spread
   twice, costs), random same-time baseline, tune on 4 half-years / score 2, n >= 100 / >= 30, lift lower bound > 1.1, Holm guard, NIFTY
   and BANKNIFTY agree; (2) gap-day path tables (gaps >= 0.5% / 1% and US-shock days: close vs open, gap-fill, first-15-min low, best CE vs
   PE window); (3) calibrate the option proxy on the recorded chains; (4) expiry-day and pre-holiday effects. A trigger that passes becomes
   grade-A capable; the rest stay WATCH.
9. THE INDEX CARD (5-second read): BUY / WATCH · index · strike · expiry · CE / PE · grade · "Agreed: ..." / entry premium zone / stop on
   the index AND premium / target / MAX LOSS Rs and % / lots / break-even move in points / IV CHEAP-NORMAL-RICH / trade n of 3, index n of 2,
   same-driver clear or BLOCKED / time-stop clock / "exit 15:10, no carry" / history line with n / "kills it: <price fact>" / NOT PROVEN.
10. Scorecard per index card: alert vs trigger time, futures + real premium outcome at 15 / 30 / 60 min and 15:10, paired random entry;
    per day the OPEN / SESSION lean vs always-UP, and index moves >= 0.8% with no card.

## 21 Nov 16:35 IST - HOLD the 16:20 INDEX DESK entry. The trader asked for a proper panel decision first ("don't be fast"). A 3-member panel
(index options trader, quant, risk / devil) is designing the NIFTY / BANKNIFTY decision process now; the agreed rules replace 16:20 in the
next entry. Do not build index cards or send the Monday index plan until then.

## 21 Nov 16:20 IST - THE TRADER: "monitor NIFTY and BANKNIFTY too - ask the desk for CE and PE". THE INDEX DESK (part of the frozen design:
index ideas were already allowed; this makes them a fixed, visible part):
1. EVERY BRIEF gets an "INDEX" block (bullet layout): NIFTY and BANKNIFTY - THE OPEN lean, THE SESSION lean, key levels (previous close,
   previous high / low, the record, the opening-range high / low once known), and a CE plan + a PE plan each with its trigger:
   CE = gap-down that closes back above the FUTURES VWAP twice / dips holding VWAP / break of the morning high on volume, RSI > 50.
   PE = gap-up that loses VWAP / bounces failing at VWAP / break of the morning low on volume, RSI < 50.
   Strikes: NIFTY next weekly (1 Dec), BANKNIFTY December monthly; ATM or 1 ITM; the shock-day IV wait (09:30) applies.
2. LIVE (09:20-14:30): the same 5 clues checked every 5 min on NIFTY / BANKNIFTY DECEMBER futures (VWAP from futures volume, not the
   index); an index BUY card only when grade A (clues + a reason: flows / news / breadth / money line) and the gates pass. Max 2 index
   cards a day, counted in the 3-trades rule. Exit notes: RSI > 80 with no new high, or a 5-min close back through VWAP.
3. History line on each index card from the studies (e.g. after a Friday US fall: open lower 93%, session flat from the open).
4. SEND NOW to Trade now: "MONDAY INDEX PLAN" for NIFTY + BANKNIFTY in this format (Friday close / record / VWAP levels, OPEN lean,
   SESSION lean, CE trigger, PE trigger, the 09:20 checks), grade shown, NOT PROVEN.

## 21 Nov 16:00 IST - ANSWERS to the server's 4 open points (1 and 4 are in the 15:45 entry - repeated here so nothing waits)
1. READ money: (c) both - TV reader 2 min per call 07:00-09:15, 4 min after; READ 1.10 (SEATS 1.50, ASK 0.10, SHOCK 0.90); MEET 2.60,
   LIVE 1.80; total $8. Re-run PROOF before Monday 07:00.
2. Depth recorder on Monday: do NOT run it in the 09:15 rush. Start it at 09:45 on the reduced list (NIFTY / BANKNIFTY futures + the 30
   most liquid F&O shares + NIFTY / BANKNIFTY ATM +/- 1), with the CPU / lag guard; if the guard stops it, retry once at 10:30, then leave
   it off for the day and report. The feed, engine and desk always win.
3. M1's 07:30 gap forecast in the morning briefs: YES only if M1 beats the simple history line on unseen years (walk-forward). If it
   does not pass by Sunday 16:00, the 07:15 brief carries the simple tested line instead: "Nasdaq futures since India's close: X% -
   on moves of 1%+ the gap followed 81% (186 cases)".
4. Message 642: YES, send the short correction (15:45 entry text), in the bullet layout.

## 21 Nov 15:45 IST - DECISIONS on the 14:38 RBI study and the READ money (before Monday 07:00)
1. **RBI: (a) + (b).** (a) Send a SHORT CORRECTION to Trade now in the bullet layout: "RBI cash (correction) / History: 386 RBI cash
   operations since 2020 / Banks usually do not move after them (52% up vs 50% normally) / So the bank CE watch from 13:34 is NOT proven /
   Monday's auction is still real - watch price, not the news". (b) LINK_BOOK row 27 re-graded in this push (NOT SUPPORTED, n 386; the
   switch-day lead kept as NOT PROVEN, n 16). The desk's earlier chat claim that RBI cash pushed Friday's Bank Nifty is withdrawn: Friday
   (+2.49%, FII +10,308 cr) beat 98% of injection days - an unusual day driven mostly by FII buying.
2. **READ money: (c) both.** R3 reads 2 minutes per call 07:00-09:15 (the morning shows) and 4 minutes per call 09:15-15:30; READ 0.50 ->
   1.10, taken from SEATS 1.90 -> 1.50 (PROOF used 1.62 with the LEAN calls), ASK 0.20 -> 0.10, SHOCK 1.00 -> 0.90. MEET stays 2.60 (it
   carries the brief floors 1.50 / 0.50 / 0.60), LIVE stays 1.80. Total $8.00. Re-run PROOF on this split before Monday 07:00.

## 21 Nov 15:30 IST (hourly) - news audit ACCEPTED (88 read: 59 live / 15 slow / 14 silent; 186 named hosts, 104 not built) + final mock dry
run 12 PASS + RBI Monday line (642) + routing fix + one-off line fix. PRIORITY for the fresh builder, all before Sun 18:00:
1. BSE filings: polite poll + the read-only bridge from the old bot's BSE store (F&O only, "via newshawk"). Never try to get around a block.
2. TV - the trader's main morning input: 390 minutes captured, 5 cards. Find why (chunk size? reader quiet rules? the snippet routing?)
   and fix so the 07:00-09:15 shows and live market calls on F&O names become cards; prove it on Friday's recordings ($0 replay of the
   text, then one real R3 call per hour of tape on Monday's budget).
3. Fresh-first: ET / Moneycontrol / BS / CNBC-TV18 items first; the slow per-share Google News (96-min median lag) only fills gaps and is
   marked LATE; an item older than 60 min cannot start a live idea.
4. Silence alarm from NEWS_COVERAGE_AUDIT.json (real core list), stop polling dead feeds.
5. NOT BUILT, this week (in order): India data calendar (GDP 30 Nov, CPI, IIP, auto sales 1st) · Fed / ECB / BoJ statements · global peers'
   results (Accenture ~17 Dec, US banks, chip makers) · GST Council · EIA / OPEC · CNBC Awaaz + Sansad TV transcripts · broker research PDFs.

## 21 Nov 14:45 IST - THE TRADER: "external news monitoring - I have asked for it since day 1". NEWS COVERAGE AUDIT, before Sunday 19:45:
1. A table in STATUS of EVERY news / information source GIR reads (world wraps + closes, RBI / SEBI / PIB / GST / courts / Parliament,
   NSE / BSE filings, wires / publishers, TV speech-to-text, broker calls, FII / DII, NSDL, global peers' results, commodities,
   summits): the host, how often it is polled, the last item time, items in the last 24 h, typical lag vs the source's own time, and
   whether the reader (R1-R6) actually turned items into cards. Mark each LIVE / SLOW / SILENT / NOT BUILT.
2. Every source in WEB_SOURCES.md and COLLECTION_PLAN.md that is NOT live gets a line: why (blocked host, not built, needs a key) and the
   date it will be live. Hosts that block cloud machines are read by the server only - confirm each one is being read.
3. A SOURCE-SILENCE alarm: in market hours any core source silent > 30 min (> 2 h for slow ones) = a P1 line on the System topic.
4. The 08:30 READY line names how many sources are LIVE / SLOW / SILENT.

## 21 Nov 14:30 IST (hourly) - ACCEPTED: send gate (blocks bad text before sending), agreement loop + runner check, 14:45 gap card (no
carry by default, honest), TRADER_RULES in every prompt + R4-R7 in code + the repeat detector, RBI liquidity shock + the 20 Nov re-score
(silence explained: the poller was born at 15:36 that day; live lag since 1-7 min), look-ahead stages, outlook clean copy 640-641, the
honest overspend note ($1.54 vs $0.90) and the max_tokens fix. Mock dry runs: good.
DECISIONS:
1. **19:45 floor: (a)** 19:45 $1.50 (07:15 $0.60 -> $0.50, 22:45 $0.20 -> $0.00 - the 22:45 runs only on a break and then uses unspent money).
2. **An OFFICIAL fact + price agreement counts as TWO benches** (the original head rule) for the grade.
3. **ACT NOW (rule 8):** your log shows RBI announced at 19:25 on Fri 20 Nov a **4-day VRR for Mon 23 Nov**. Send it to GIR Trade now
   today as an RBI LIQUIDITY line in the bullet layout: the notified amount, the auction window on Monday, what it means (cash for banks
   again as Friday's 3-day repo is repaid -> support for banks; CE watch AUBANK, PNB, AXISBANK, BANKBARODA only after the open settles;
   a risk for bank PE positions), NOT PROVEN. Then the Monday result line when it lands.

## 21 Nov 15:20 IST - FROM THE TRADER, IN HIS WORDS: "I'm crying. I don't know what to do. Ask them not to make this mistake again and
again. I don't have the energy to keep repeating it every day."
**NEW FILE desk/prompts/TRADER_RULES.md - his 10 standing rules. Load it into the HEAD and EVERY SEAT on EVERY call (top of the cached
prompt), and make the validator + tgformat enforce rules 4-7 in code.** Every repeat of a mistake he already corrected (repeated ideas,
BUY on a watch idea, grade C on Telegram, messy text, stuck on the same names, silence on a big event) is a P1 for the builder to fix the
same day, and is reported in STATUS. Builders: read this file before every change to anything he sees.

## 21 Nov 15:05 IST - THE TRADER (13:03 Trade now messages): "the same Persistent, VEDL, Muthoot again and again - I'm fed up". FIX NOW:
1. **FORMATTER BUGS (tgformat.py):** double bullets ("• •"), lines split mid-phrase ("(b)", ">=", "30)" on their own lines), internal text
   leaking ("missing: (a)...", "src:news", "n >= 30", "desk team"). Rules: one bullet per fact, never nested; a long fact wraps onto a
   continuation line WITHOUT a bullet; never split inside a bracket or a number; strip every grading / missing-field note from Telegram
   (it stays on the page). Test with today's 13:03 messages as fixtures.
2. **SEND ONLY WHAT CHANGED:** an idea already sent is NOT re-sent unless its stage, grade, trigger or price picture changed. Unchanged
   ideas collapse to ONE line: "Still watching (no change): DIXON PE, VEDL PE, MUTHOOTFIN PE". No "NEXT DAYS" block repeated per idea.
3. **GRADE C NEVER ON TELEGRAM** (ALKEM PE grade C was sent at 13:03 - against the 12:25 rule). C stays on the page only.
4. **BREADTH - stop thinking only about the five seeds:** every brief and every look-ahead pass ranks the WHOLE F&O list (218) from the seat
   consensus, the group expansion, the event library and the models, and shows the best 3 CE + 3 PE (new or changed, grade A / B only).
   If nothing new qualifies, one line: "No new ideas - nothing passed the checks."
5. Re-send ONE clean, short message to Trade now replacing the 13:03 ones, then quiet until something changes.

## 21 Nov 14:40 IST - GAP REVIEW (independent F&O-dealer + reliability reviews). These are ADDED to the frozen design now, so nothing
"could have been added" later. Build list B is extended; all are small and mostly code, $0.
**CRITICAL - before Mon 09:15:**
 1. HEARTBEAT: an 08:30 "READY" line, then one System-topic line every 30 min in market hours (last tick age, cards, rings, AI $). "No
    line for 35 min" joins the J7 flip reasons.
 2. TELEGRAM SEND FAILURES: check every send's reply (ok=true); retry once; count failures on the health page; a failure streak = P1 by the
    second channel (item 3).
 3. OUTSIDE MONITOR (the trader signs up himself - free UptimeRobot or healthchecks.io, alerts to his email / phone app, NOT the Telegram
    bot): it watches /status.json + the last-tick age + "a Telegram send succeeded in the last 35 min". Server side: expose those fields.
 4. TOKEN ROTATION PLAN: the FULL sender list incl. gir-v2desk (tgdesk.py), gir-v2tgcmd, shock / credit / Kite-check / ring-test paths; the
    trader rotates on Sunday BEFORE the 18:30 ring test; new token into both variables (hidden prompt), restart the list, one test line
    from each sender.
 5. MARKET-HOURS CHANGE FREEZE 09:00-15:35 (J16): no restarts / deploys except `gir mode`; a lock file the restart helpers check; the
    builder stays read-only in that window (fixes queue for 15:40).
 6. 09:15 CPU: apply option A on Sunday (pause falcon + old engine2), Nice / OOMScoreAdjust priority for feed, engine, desk; memory caps on
    recorders (depth recorder already has its load guard).
 7. RESTART PROOF: Restart=on-failure with a burst limit + an alarm when a unit gives up; run the J13 kill test on Sunday.
 8. QUICK CHECKS: NTP synchronized (J12); 08:30 Kite cold-start test with 0 rate-limit errors (J14); stop apt-daily-upgrade until Mon
    16:00; the 08:20 Kite-check alarm really rings; the 08:20 check also reads HIS positions / orders / funds, and the first fill must move
    the trade counter within 10 s, else every card says "risk gates blind".
 9. SHOCK-DAY OPTION PRICE CHECK (in code): WAIT until 09:30 when India VIX is up > 10% or ATM IV > 1.3x its recent level; prefer 1 ITM.
10. CARRY RULE (reconciles 15:10 vs carry): a DECLARED carry is marked OVERNIGHT and skips the 15:10 alarm; max 1 carry, 0.5% risk sized
    on a gap through the stop; counts in the next day's loss lock; a 09:08 "carried position: exit / hold / stop" card; two-night warning
    before holidays (Mon 23 -> Wed 25).
11. PHONE RUNBOOK for the trader (one page, also as a Telegram pinned message): no messages / page down / Kite key DEGRADED / AI credit
    empty vs provider down / Telegram dead / what to type (gir mode old) / who to call.
**IMPORTANT - this week:** second P1 channel (email / push) for server down, Kite down, credit empty, Telegram failing · guarded mid-day
Kite re-login command · websocket stale -> automatic REST-quote fallback · nightly off-server backup of the desk board, ledger, thesis book,
budget counters, flags + a DigitalOcean snapshot before Monday evening's reboot + the post-reboot checklist · disk: cap journald, phone
alarm at 85% · AI P1 wording "provider down" vs "credit empty" · HIS trade journal (Kite tradebook at 15:35: plan vs actual, GIR call or
own, exit reason, R after charges; Friday rule-break review) · hard block on buying options into a company's own results / board meeting
within one session unless IV < 70th percentile · MSCI 30 Nov + FTSE December rebalance lists on the calendar · earnings-call transcript
reader before the January season.
**NICE:** price-band field, ASM / GSM watch, SAST / insider / pledge reader, break-even move on the card, "same driver" check for two PEs on one
shock, tax ledger, US times from the New York zone, vacuum old journal lines after rotation.

## 21 Nov 14:15 IST (hourly) - ACCEPTED: PROOF_1030 ($6.13, no LIVE refusal), evidence gate + grades (636), bullet layout in code (637,
tgformat.py, every path), look-ahead book seeded, LEAN split, mock / ring-test prep, the GAP-PREDICT study (honest: nothing at 14:45
predicts the sign; the US night does). H_head_analyst.md now carries the evidence-gate rule (this push).
DECISIONS:
1. **14:45 card = INFORMATION + carry rule, no sign call:** "Tomorrow's gap: no edge from today's signals (588 days); it is set tonight.
   Carry only with a known overnight event or a share's own fresh catalyst." Plus **EVENING GAP WATCH** to Trade now at 20:30 and 23:30
   IST (Nasdaq / S&P futures vs India's close, with the history line: on 1%+ moves the gap followed 81% of the time), and the 07:15 brief
   as the morning answer. Max 2 evening lines; the US close itself is already a WORLD SHOCK line when >= 2%. Quiet night rule unchanged.
2. **READ budget:** READ 0.50 -> 0.70, MEET 2.60 -> 2.40 (MEET used $2.19). Low-weight items left unread after that are acceptable; RED /
   official items always use the SHOCK reserve.

## 21 Nov 14:00 IST - THE TRADER APPROVED THE DESIGN ("go ahead with the changes"): explainers/gir_new_flow.png is the FROZEN design
until the week-1 review on Fri 27 Nov. Build what is on it; fix only what Monday's live results show broken; no new features in between.
BUILD ORDER (Monday-critical first, the rest in parallel by a second builder, light load, $0 AI unless stated):
 A. Before Sunday 17:00 mock: agreement loop + "BUY only on agreed A calls" (12:50) · one-line bullet layout (13:00) · anti-chase refined +
    runner check (13:45) · 12-driver checklist (done) · open / session lean split (11:55) · PROOF with the new $8 split · Monday outlook
    re-sent in the final format.
 B. Before Monday 08:30: 14:45 TOMORROW / CARRY card (with the gap study) · RBI liquidity shock + seat 9 card (11:00) · market-depth recorder
    tested (starts 09:15) · Sunday mock + ring test + 19:45 brief.
 C. In parallel from today (not blocking Monday): models M1 / M2 / M3 · RBI liquidity study · look-ahead book · free upgrades 2-8 (13:30).
Report each item in STATUS as done / testing / not started.

## 21 Nov 13:45 IST - THE TRADER: "don't block the 10% / 20% runners". ANTI-CHASE REFINED (replaces 12:25 point 1)
The rule never blocks a big mover that has a reason. It blocks only "it rose yesterday, so CE today" with nothing new.
1. ALLOWED at any size of move: (a) a FRESH catalyst today - results, filing, order win, block / bulk deal, regulator / government news,
   broker upgrade, sector news - with price + volume confirming (above VWAP, RVOL >= 2, sector not against); or (b) a PROVEN momentum
   pattern from his data (e.g. the onset study's breakout-with-volume rows; M2's continuation probability above its tested threshold).
2. RUNNER CHECK (new): any F&O share up / down >= 5% intraday on RVOL >= 3 gets a dedicated look: what is the catalyst, is it new, how did
   the last N similar runners do (event library / M2), where is it vs VWAP and the day's high. Output: RIDE (grade A / B with the evidence)
   or LATE ("move mostly done: N past cases gave back X%").
3. BLOCKED only: a carry or next-day CE / PE whose only reason is the previous session's move (or "long build-up" / "led the sector")
   with no fresh catalyst and no proven pattern -> WATCH only.
The flowchart line now reads "Big movers allowed WITH a fresh reason or a proven pattern".

## 21 Nov 13:30 IST - FREE ($0) BRAIN UPGRADES, ranked - the trader asked for every zero-cost improvement (build in parallel after the
Monday must-haves; code + free public data only; light load; each one shown on cards only after it beats random on unseen data):
1. MODELS M1-M3 (13:15 entry) - started.
2. LEARN WHOSE WORD TO TRUST: each seat / source / broker gets a running hit rate from the 15:45 scorecard, and the head weights cards by
   it (a simple Bayesian score, shrunk toward 50% while n is small). Shown as "track record 7/10" on cards.
3. FII DERIVATIVE POSITIONING: NSE's free daily participant-wise OI file (FII / DII / pro / client long-short in index futures and
   options), years of history -> study: does FII index-futures long / short change predict the next 1-3 days? Feeds M1 and driver 4.
4. EVENT LIBRARY from free NSE archives: results-day reactions by surprise size, bulk / block deal follow-through, broker upgrade /
   downgrade follow-through, ban-list entries / exits, index inclusion, RBI operations (11:45 study). Each gives "last N times: X% moved".
5. NEWS-HISTORY BACKFILL: GDELT (free global news database with tone, from 2015) filtered to India / F&O company names / sectors ->
   years of news-volume and tone history, so the news-based models do not wait months for GIR's own recordings. Keep the download filtered
   (disk cap 2 GB).
6. OPTIONS SIGNALS from the recorded chains: IV skew, PCR change, OI walls / max-pain drift -> does any predict the next session?
7. MARKET REGIME model: trend / range / high-volatility from India VIX, breadth and NIFTY's distance from its averages; each strategy and
   the A / B / C gate adjust to the regime (e.g. no breakout CE in a range regime).
8. CALENDAR EFFECTS: expiry week, pre-holiday, month-start auto sales, results season, budget / RBI weeks - measured, not assumed.
Report each as LIVE / testing / not started, with its first result, in STATUS.

## 21 Nov 13:15 IST - THE TRADER APPROVED: build STATISTICAL MODELS and MARKET-DEPTH recording NOW, side by side (not week 2).
Limits: code only ($0 AI), no paid storage, light on the server (train after 15:35 / weekends with nice 15; never slow 09:15). Monday's
go-live items keep priority; these run in parallel with their own builder.
**A. MODELS (scikit-learn: logistic regression + gradient-boosted trees; walk-forward test: train on older years, test on later unseen
years; calibrated probabilities; shown ONLY if they beat the simple base rate on the unseen years, else kept off the cards):**
  M1 NEXT-DAY GAP (NIFTY, BANKNIFTY, sector indices): inputs = US index + futures moves, SOX, Asia closes, Europe, GIFT premium at
     15:10, USDINR, crude, gold, US 10y, FII cash, India VIX, day-of-week (Friday), holiday next, NIFTY RSI / distance from 20-day.
     Output: P(gap down / up), expected size. Feeds the 14:45 TOMORROW card.
  M2 09:20 SHARE CONTINUATION (218 F&O shares, 3 years of minute data): inputs = gap, first-5-min range, RVOL, VWAP side, sector move,
     NIFTY move, pre-open IEP gap, OI change, daily RSI, distance from 52-week high / low. Output: P(>= 1% more in the same direction by
     15:10). Feeds the A / B / C grade (a call needs the model to agree or say why not).
  M3 SECTOR NEXT 1-5 DAYS: sector RSI, breadth, FII sector flow (NSDL), relative strength vs NIFTY, the pairs. Feeds the look-ahead book.
  Report each model: accuracy vs base rate on unseen years, by year, with n; the top inputs; file onset_results/models_*.md.
**B. MARKET DEPTH (closest to tick-by-tick with what he already pays for): Kite websocket FULL mode (5 levels of bids / asks + last
trade + OI), on a SEPARATE key / connection from the live feed:**
  - Instruments: NIFTY + BANKNIFTY futures, the ~60 most liquid F&O shares, NIFTY / BANKNIFTY ATM +/- 2 strikes, and the day's watch-list
    names (outlook / look-ahead) - not all 218.
  - Store per-second FEATURES, not raw snapshots: bid / ask total quantity, imbalance, spread, best-level size jumps, large-order flags,
    trade-side estimate. Compressed (parquet / zstd), 30-day rolling, disk cap 3 GB (alert at 80%).
  - Load guard: stop the recorder for the session if CPU > 70% or the live feed lags (logged).
  - Start recording Mon 23 Nov 09:15 if the Sunday test passes. NOT used in decisions until a study (about 2 weeks of data) shows the
    imbalance predicts the next 5-15 minutes beyond random.

## 21 Nov 13:00 IST - THE TRADER: "bullet points in straight lines" - EXACT TELEGRAM LAYOUT (every message, code-formatted, not left to the model)
- Every line starts with "• " and is ONE short line (max ~45 characters, no wrapping into a paragraph). One fact per line.
- Plain words only: no "bench", "base rate", "n", "D1", ids or keys on Telegram ("73 past cases", "proven by history").
- A header line, then the lines, then one blank line between items. No closing paragraph.
Example - the re-graded Monday list:
  MONDAY LIST (re-checked)
  PERSISTENT CE
  • Not a buy - watch only
  • Reason was only Friday's rise
  • History: IT weakest after US crash (73 cases)
  INDUSINDBK CE
  • Not a buy yet - watch only
  • Already up 8.6% on Friday
  • Needs a new reason or a dip that holds
  DIXON · VEDL · MUTHOOTFIN PE
  • Best ideas - not a buy yet
  • BUY only if at 09:20:
  • share below VWAP
  • sector below VWAP
  • Nothing to buy at the open
Re-send this list now in this layout, and use it for every card and brief part from now on (the code builds the lines; the model only
fills the fields).

## 21 Nov 12:50 IST - ROOT CAUSE of "a call sent although the Devil disagreed" + the agreement process (code, before Sunday 19:45)
Root cause: the outlook DID mark PERSISTENT / INDUSINDBK "WATCH only, on a pullback", but the Telegram card template prints "BUY <share>
<strike>" for EVERY idea, whatever its state - so a WATCH idea with an unanswered Devil read as a BUY. Fix:
1. The word BUY appears ONLY on an AGREED call (grade A: head + Devil answered + history + a second seat agree, price confirms at the
   trigger). WATCH ideas start with "WATCH" and never show BUY; dropped ideas show "NOT TAKING: <why>".
2. AGREEMENT LOOP before anything is sent: head drafts -> Devil objects -> the head must either ANSWER with evidence ids (the Devil then
   marks RESOLVED or STILL BLOCKING) or DROP the idea. Only RESOLVED ideas can be calls; STILL BLOCKING = "NOT TAKING" with the one-line
   reason. The card shows "Agreed: head, devil, history, <seat>" or the missing one. Validator + test.
3. Re-send the Monday outlook after 1-2 (with the 12:40 short format).

## 21 Nov 12:40 IST - THE TRADER on the Telegram outlook: "500-line paragraphs; a call sent although the Devil said no". TWO HARD RULES
**RULE 1 - an unanswered Devil = NO CALL.** If the Devil's objection is BLOCKING (history points the other way, or "the gap is the whole
move") and the head has no evidence-based answer, the idea is NOT sent as BUY. It appears only as one line: "NOT TAKING: PERSISTENT CE -
history: IT weakest after a big Nasdaq fall (n=...)". Code check: a call whose AGAINST is a Devil card with severity BLOCKING and no
answer id is rejected. No call goes out until head + Devil + history + a second seat agree (the A / B / C gate of 12:25).
**RULE 2 - SHORT BULLET CARDS ONLY on Telegram.** Max 8 lines per call, max 15 lines per brief part; no paragraphs; numbers from code.
Call card template:
  DIXON · PE · WATCH · Grade B
  • Trigger: US chip index -10.7% (Fri night)
  • Link: DIXON = Indian AI-hardware / EMS -> hit
  • Money: leaving hardware for IT and banks
  • History: EMS / IT weakest after big Nasdaq falls (n=...)
  • Enter 09:20 only if: EMS below VWAP + DIXON loses VWAP
  • Cancel if: EMS holds VWAP, or a big gap already took the move
  • Stop 13,307 · Target 12,676 · Dec 13000 PE
Brief template: 1 line OPEN lean + 1 line SESSION lean; 12 driver lines of <= 1 line each (only drivers that CHANGED get words; the
rest one word "no change"); CE list; PE list; NOT TAKING list; 09:20 checks (<= 4 bullets). Full text stays on the page / in the file.
Re-send the Monday outlook in this format (with Rule 1 applied) to GIR Trade now, and apply both rules to every message from now on.

## 21 Nov 12:25 IST - THE TRADER: "no blind picks - not 'it went up today, so CE tomorrow'". ANTI-CHASE + EVIDENCE GATE (code + H prompt)
1. **Anti-chase:** a CE on a share that rose >= 3% in the last session (or a PE after a >= 3% fall) needs a NEW reason dated after that move
   (fresh news / filing / flow / event) OR a tested continuation base rate (n >= 30, hit rate >= 55% and >= 5 pts over random). Without one
   it can only be "WATCH on a pullback", never a BUY NOW, a carry or a look-ahead READY. "Led the sector on Friday" / "long build-up" /
   "momentum" do not count as reasons on their own.
2. **Evidence gate for every call and look-ahead idea:** (a) >= 2 independent reasons from DIFFERENT benches with evidence ids; (b) a tested
   base rate with n vs random (or "STORY ONLY - not tested", which caps the grade); (c) the Devil's objection answered with evidence. If the
   history base rate points the OTHER way (e.g. IT after a big Nasdaq fall: -1.17%, weakest in 24 of 29 cuts), the call must say why this
   time differs WITH evidence and its n, else it is downgraded.
3. **Grade on every card:** A = all three + price agrees at the trigger (only A can ring BUY NOW); B = two of three (WATCH, page + brief);
   C = story only (page only). The grade and the missing piece are printed on the card.
4. Monday outlook re-checked under this gate: PERSISTENT CE (reasons: led IT Friday with long build-up = momentum; IT laggard by RSI +
   rotation table; "low-AI Indian IT" story; history AGAINST, only 2 counter-cases in 2026) -> grade B / C, WATCH only. INDUSINDBK CE
   (FII flow + governance clean-up + flow-to-private-banks lesson; ran +8.59% - needs a new reason or a pullback hold) -> B, WATCH.
   DIXON / VEDL / MUTHOOTFIN PE (world move after the Indian close + sector links + history for metals) -> B, A only if price agrees at 09:20.
   Send the re-graded list to GIR Trade now as a short update before Sunday 19:45.

## 21 Nov 12:10 IST - THE TRADER: "think ahead like brokers - continuity, every day, alerts BEFORE the move". THE LOOK-AHEAD BOOK
A standing, multi-day idea book (horizon 1-10 sessions), separate from intraday BUY NOW:
1. **Each idea:** share / sector, side (CE / PE), horizon, the chain of events (e.g. "metals falling -> input costs down -> auto margins up
   over the quarter"), the evidence WITH n from his data (sectorlag / onset / us_shock / rbi_liquidity / obscan studies, LINK_BOOK grade),
   what must happen first (the trigger), what kills it, and the December strike + carry note.
2. **Stages, each one an alert to GIR Trade now:** WATCH (the story starts: first news / first sector move) -> SETTING UP (a second bench
   agrees, price starts to agree) -> READY (trigger near - "position before tomorrow / before the event") -> GO (trigger hit, or carry at
   14:45) -> DONE / CANCELLED (with the reason). Re-checked every day at 14:45 and 19:45; a change of stage is a card, never silent.
3. **Honesty rule - test the link before betting:** his own data (sectorlag.py, 3 years) says "metals down -> autos up" does NOT work over
   1-3 days: after metals <= -1% (n=144) autos the next day +0.03% (51% up) vs a +0.00% baseline; when autos had already risen that day
   (n=6) they FELL the next day (-0.63%, 33% up). Cost relief shows in margins over quarters, not days. So every look-ahead idea shows its
   tested hit rate, and an untested link is labelled "STORY ONLY - not tested".
4. Every brief carries the book (open ideas with stage, days open, move since WATCH); the 15:45 scorecard scores them at their horizon.
5. Build after the 14:45 carry card; seed it from the Monday outlook (INDUSINDBK / PERSISTENT CE, MUTHOOTFIN / VEDL / DIXON PE) and the
   desk's rotation read (insurers, capital goods, auto parts as laggard destinations).

## 21 Nov 11:55 IST (hourly) - MILESTONE ACCEPTED: the new desk speaks on GIR Trade now (630-635), old system barred from it (tested)
- ACCEPTED: channel switch, old health lines moved to the System topic, Telegram ON for shocks / RBI-official / WHY / briefs / credit P1,
  BUY NOW / manage / rotation hard-off until Mon 09:15, the Monday outlook, the honest CORRECTION message (stale 15:29 prints vs the US
  close) and the three validator fixes (STALE drivers rejected, hot US wraps with ids, D11 numbers with n). 12-driver checklist permanent.
- ONE REFINEMENT for every brief: split the LEAN in two - **OPEN (the gap)** and **SESSION (from the open to the close)** - because the
  20-year study says they differ: after a Friday US fall the open was lower 93% (median gap -1.73%) while the day FROM the open was about
  flat (median close vs open +0.18%). "LEAN: MIXED" hides that. Monday's should read e.g. "OPEN: DOWN (93%, n=15) · SESSION: FLAT to
  slightly up from the open; PE value is in the gap, CE only on a hold of the early low."
- Next: the 14:45 TOMORROW / CARRY card + the gap-prediction study (11:40 entry); the RBI liquidity study (11:45); PROOF_1030; the Sunday mock.

## 21 Nov 11:45 IST - URGENT STUDY (code only, $0, before Sunday 19:45): "If RBI injects cash, how much do banks move, and when?"
Every RBI liquidity operation since 2020 from RBI press releases ("Money Market Operations", VRR / VRRR auction notices + results,
OMO purchase / sale, FX buy-sell swaps, CRR changes, special liquidity windows): date, ANNOUNCEMENT time and RESULT time (IST), type,
size (Rs cr), bids received / bid-cover, tenor. Measure BANKNIFTY, NIFTY PSU BANK, NIFTY PVT BANK and NIFTY from the announcement minute
(and the result minute) to +30 min, +60 min, the close, and the next session (minute data where /root/hist has it, else daily).
Split by size (< 25k / 25-75k / > 75k cr), by type (routine VRR vs structural OMO / CRR / swap), by bid-cover (>= 2x = tight), and by
whether FIIs bought or sold that day. Base rates with n: % up, median move, best / worst. File onset_results/rbi_liquidity_study.md
(+ .json) and a NOT PROVEN lesson for the head. Include 20 Nov 2026 (Rs 50k cr result about 10:00-10:20, Rs 25k cr at 13:40; BANKNIFTY
+2.49% with FII buying) as the latest row.

## 21 Nov 11:30 IST - DO NOW: the trader has had ZERO messages from the new desk
1) Switch the new desk's Telegram ON today (his one desk channel) for: world / India shock lines, RBI / official alerts, cause (WHY)
   cards and briefs. BUY NOW cards stay off until Monday 09:15 (market closed). TG_CHAT_FO / TG_CHAT_OI stay forbidden.
2) Within the hour the HEAD ANALYST writes and SENDS a "MONDAY OUTLOOK" brief to that channel (weekend SHOCK / MEET money) using the
   12-DRIVER CHECKLIST (11:20 entry): why the US fell (sources), what history says for Monday's open (us_shock_lesson), where money is
   likely to go (rotation), RBI liquidity (the 20 Nov Rs 75,000 cr injection; the 3-day repo is repaid on Monday 23 Nov, so another
   injection is likely), the CE and PE watch lists by sector, the 09:20 checks, NOT PROVEN.
3) From now on the desk itself sends every shock, RBI / official alert and brief. Report in STATUS the minute the first message is
   delivered to his Telegram.

## 21 Nov 11:20 IST - THE TRADER: "you chase whatever I name - copper, auto, RBI - that is not a human analyst". A FIXED DRIVER CHECKLIST.
Every brief (19:45 / 07:15 / 09:08 and the Saturday-Sunday outlook) MUST carry all 12 drivers, one line each, with the CE / PE meaning and
the F&O names - or "no change" - and the validator rejects a brief that skips one. Live, a change in ANY driver is a card / alert:
1 WORLD markets + the cause (US, Asia, Europe, futures, VIX). 2 WORLD macro (US 10y, dollar, yen, yuan, crude, gold, copper / metals).
3 INDIA overnight (GIFT NIFTY, ADRs, rupee). 4 MONEY FLOWS (FII / DII cash, FII F&O positioning, NSDL sector flows, MTF book).
5 RBI + LIQUIDITY (operations, system surplus / deficit, call rate, policy dates). 6 GOVERNMENT + REGULATORS (SEBI, GST, Cabinet,
Parliament, courts, PIB, exchanges). 7 COMPANIES (results, filings, block deals, orders, management, broker calls on F&O names).
8 SECTOR ROTATION (EXTREME vs laggard sectors, money in / out, the pairs). 9 CALENDAR (data, summits, expiry, holidays, results dates).
10 MARKET INTERNALS (breadth, India VIX, OI build-up, PCR, VWAP side of NIFTY / BANKNIFTY). 11 HISTORY (what the last N similar
cases did, with n). 12 THE OTHER SIDE (Devil's strongest objection) + RISK (what kills the view).
Then: MARKET LEAN (UP / DOWN / MIXED + the 2 strongest drivers), CE list, PE list, the 09:20 checks. Seats already map to these
(world 1-4, commodities 6-8, money 9-10, policy 11-14, company 15-18, sectors 19-27, voices 28-30, internals 31-34, connections 35,
devil 36, history 37); this makes the coverage visible and enforced. Apply to the Monday outlook being sent today.

## 21 Nov 11:00 IST - MISSED SIGNAL: RBI liquidity injection on Fri 20 Nov (reported Rs 75,000 cr of 3-day VRR repos: Rs 50k cr + Rs 25k cr;
bids about Rs 1.13 lakh cr for the first Rs 50k cr - one source so far, goodreturns). Neither GIR (old or new) nor the desk's outside
watch told the trader, and LINK_BOOK row 27 says "RBI liquidity injection -> CE AUBANK, PNB, AXISBANK, BANKBARODA next day (HIGH)".
1. **VERIFY now from RBI's own press releases** (rbi.org.in "Money Market Operations" / VRR auction notices and results, 20 Nov): the
   amounts, the announcement time and the result time (IST), and whether GIR's R4 / regulator feeds ingested them (which file, when).
2. **New standing rule - RBI LIQUIDITY is an OFFICIAL shock (family G, RED in market hours):** any VRR / VRRR / OMO buy or sell /
   FX buy-sell swap / CRR change / SDF-MSF change, announcement AND result. RED when the size is >= Rs 25,000 cr or the bid-cover is
   >= 2x; the line carries the LINK_BOOK row 27 / 28 names on both sides ("injection: CE watch AUBANK, PNB, AXISBANK, BANKBARODA; deficit
   widening: PE over days"). Seat 9 (rupee / rates) gets the daily system liquidity (surplus / deficit, SDF and MSF use, call rate vs
   repo) in its snapshot and writes a card on every operation.
3. Re-score 20 Nov: would this rule have rung, at what time, and where was BANKNIFTY then versus its close (+2.49%)? Report honestly -
   the FII buying may have been the bigger driver.

## 21 Nov 10:50 IST - AFTER MONDAY (week 1): a weekly CRASH-RISK METER on the trader's 5 factors (credit levels, market concentration,
institutional behaviour, liquidity, trigger vulnerabilities) for the US and India, LOW / MEDIUM / HIGH each with the numbers (FINRA margin
debt, HY spreads, AI-credit CDS, top-10 weight, hedge-fund leverage reports, Fed / RBI path; India MTF book, NIFTY sector weights, NSDL
FPI flows, RBI liquidity ops, India VIX) and the stage (boom / euphoria / distress / panic). Code fetches the numbers; the head writes
one paragraph in the Sunday 19:45 brief. Not for Monday.

## 21 Nov 10:30 IST (hourly) - big batch ACCEPTED; one money fix; the J7 reasons (desk writes them, trader approves)
- **ACCEPTED:** watchdog (a); credit balance from the $50 top-up with the warnings; one $8 gate (J11) for every v2 call; old-system AI
  OFF (baseline frozen - "old paths = $0" check on Monday); credit warning without credit; WORLD SHOCK A / B / E live with the Fri 20 Nov
  proof (US close line at 02:25 - exactly what the trader wanted); C / D / F / G / H / I / J on the page with flood control and 15:45
  scoring; pages item 4 (136 PASS); J6 complete; J7 switch (flags, dropped not queued, FO / OI forbidden in both modes); reboot Monday
  evening; the 20-year US-shock study and its lesson.
- **MONEY FIX - LIVE is now too small.** The new split gives LIVE $1.40, but PROOF_2220c needed LIVE $2.60 for a day (head looks 11 /
  $2.34). Change: SEATS 2.20 -> 1.90 (the conference runs on the LEAN combined calls anyway), ASK 0.30 -> 0.20, LIVE 1.40 -> 1.80; and
  SHOCK money NOT spent by 11:00 IST rolls into LIVE for the rest of the day (a shock after 11:00 can still use what is left of SHOCK
  first). Re-run PROOF with this split: pass = no LIVE refusal before 14:30, both morning briefs delivered, total <= $8.
- **J7 - REASONS TO FLIP TO "gir mode old" (desk's text, for the trader to approve):** flip if ANY of these happens on a trading day:
  (1) the new desk has written no brief by 09:10 or no card by 09:30 (it is down or starved); (2) more than 6 rings in 15 minutes
  (a flood); (3) a BUY NOW on the wrong side of a clear move (e.g. CE while NIFTY and the sector are both below VWAP and falling) that the
  desk does not withdraw within 5 minutes; (4) the page or phone shows P1 "AI CREDIT EMPTY" or "desk OFF" in market hours; (5) prices
  STALE on more than 5 names for over 3 minutes. Flip back to "gir mode new" when the cause is fixed. Put these on the J7 Settings button.
- Missing pieces noted (fine for Monday): D's band-hit and pre-open IEP-gap fields, J's scenario file; the close-vs-open column (asked).

## 21 Nov 10:40 IST - US-shock study ACCEPTED (122 cases, code only). Add one column: close vs OPEN (not only vs previous close) for
each cut, and the median bounce from the first-15-minute low to the close - the trader's intraday question is "does it bounce from the
early low". The desk's news-report reading and the data agree once both are measured: gap down, early low, partial bounce, red close.

## 21 Nov 09:45 IST - URGENT STUDY for the trader (code only, $0, today): "After a big Nasdaq fall, what does India do next?"
From Yahoo daily bars (p_uswrap already reads them) + /root/hist + fo_daily, 2005 (or the longest available) -> 20 Nov 2026:
1. Every US session with Nasdaq Composite <= -3% (and the subset <= -4.5%), and S&P <= -2.5%. For India's NEXT session: NIFTY gap at the
   open (open vs previous close), the day's low and high vs previous close, the close; same for BANKNIFTY and NIFTY IT; minutes from the
   open to the day's low (from minute data where /root/hist has it, 3 years).
2. Split: (a) Friday US fall -> Monday India; (b) India had RISEN on the US-fall day (closed before the fall); (c) two US down days in a
   row; (d) Asia already down >= 3% the same day.
3. Base rates: % of cases India opened lower / closed lower / recovered from the open low to close positive / recovered within 5 days;
   median and worst gap; which sector indices held up best (bank, pvt bank, PSU bank, IT, pharma, FMCG, auto, metal, realty).
4. File onset_results/us_shock_study.md (+ .json), and give the head the summary as an EVENT_MEMORY-style lesson (NOT PROVEN,
   with n) for the Sunday 19:45 brief. Report in STATUS as soon as it is done.

## 21 Nov 09:30 IST (hourly) - ACCEPTED: hunter LIVE fallback blocked (3 tests), swap 4 GB, 21 updates (70 services still up),
gircrypto login block disabled. Two items need the trader's word (asked now): (1) the reboot for the 14 kept-back packages (kernel +
systemd) - desk advice: YES, Sunday 12:00-13:00 IST, then check every GIR service, the feeds, girtrader.com and the desk BEFORE the 17:00
mock (rollback = boot the previous kernel); (2) gir-watchdog flood (~290 a day: "paper_exit_monitor / raven DOWN") - desk advice: both
(a) drop the paused raven + paper_exit_monitor from its list and (b) one line per NEW problem, then one "still down" line a day. Nothing
on the watchdog changes until he says so (standing rule).

## 21 Nov 08:45 IST - THE TRADER: "work continuously, finish, then a full MOCK on Sunday evening". DO NOT WAIT FOR HOURLY PULLS.
Work straight through this list in order (builder agents in parallel where files do not overlap), tests first, push after each item:
1. Old-system AI off (one $8 gate); SHOCK budget ring-fenced; hunter LIVE fallback blocked; confirm the desk's AI is back after the top-up.
2. **CREDIT WARNING THAT NEEDS NO CREDIT:** plain code, sent over Telegram (free) on the system channel + the page footer + the phone card:
   (a) at the FIRST credit refusal: "P1 AI CREDIT EMPTY - top up at console.anthropic.com; GIR runs on rules; shock alerts still on";
   (b) BEFORE it runs out: keep a running balance = the last top-up amount the trader gives (ask him once, store it, never a key) minus
   the ledger spend; warn at < 3 days of the $8 cap left ($24) and again at < 1 day; (c) a daily 19:30 line with the estimated balance.
   Note for the trader: after he rotates the Telegram token, the NEW token must go into .env at once or every alert stops.
3. World shock alerts A / B / E live + the Fri 20 Nov night proof.
4. Pages: MONEY line, rotation 09:20 line, GO card MONEY / AGAINST-THE-MONEY, "desk ON - next brief" footer, STALE / data-missing / P1
   lines on desk + phone.
5. Shock C / D / F / G / H (India market, F&O share, flows, official news, company), then I / J; flood control; 15:45 scoring.
6. Server health: swap, the 30 Ubuntu updates (test after), the gircrypto login lines.
7. J6 complete, J7 fallback switch for the trader.
**SUNDAY MOCK (dress rehearsal), 17:00-18:30 IST, Telegram LIVE to the trader, every message prefixed "MOCK":** replay Fri 20 Nov through
the LIVE pipeline (not the rehearsal tool) at speed with stand-in brains ($0), covering: the 07:15 / 09:08 briefs, a GO card with FROM /
AGAINST / MONEY, a manage note, a rotation alert, a world shock line (the US crash), an India shock line, a company-filing shock, the
credit-empty P1 (simulated refusal), a feed-stop STALE line, a fake-chain block, the fallback switch, and the 15:45 scorecard. Then the
18:30 ring test, then the real 19:45 brief. Write a pass / fail table per item in STATUS by 18:45.

## 21 Nov 08:25 IST (hourly) - big batch ACCEPTED; three orders
- **ACCEPTED:** old trading programs paused (no real order found, states kept, undo list); spend account (Claude Code on the server
  ~90% of the week's API money while on API billing - now on the subscription); TG_CHAT_FO / OI guard in EVERY sender (old + new,
  tested); token masked in logs; knowledge pack G-J live with K kept out (answer key) - good; the US close + wrap feeds (the real gap) and
  the WHY rule; MONEY FLOW, rotation alert, GO card MONEY line, rotation table, insurers vs BANKNIFTY in code.
- **ORDER 1 - old system's AI OFF:** the old "reader" (~$7.7 a day) and every other old-system AI call (analyst expert / routine, ready
  files, decider) sit OUTSIDE the desk's $8 gate. The trader's decision is $8 a day TOTAL. Switch their AI off by flag (their non-AI
  feeds keep running as the desk's eyes); from now on every AI call on the key goes through J11. Show the old paths' spend = $0 on Monday.
- **ORDER 2 - the SHOCK budget now, not Monday:** the WHY search stopped at 07:52 on the weekend cap ($1.46 of $1.50). Ring-fence the
  SHOCK_ALERTS.md reserve today ($0.50 on weekend / holiday days, $1.00 trading days, from READ) so a big move's cause card is never
  refused. The Reuters Nvidia-SEC exclusive is already in the feed: make sure R5 / seat 1 use it on the next run.
- **ORDER 3 - hunter's LIVE fallback:** even while paused, make it impossible: if paper_trader fails to import, hunter must refuse to
  start (never switch to LIVE). One-line change + test, logged with undo. GIR never places orders.

## 21 Nov 08:20 IST - THE TRADER: shocks of EVERY kind, India and world, news and price - design_v3/SHOCK_ALERTS.md (REPLACES 08:05)
Build in this order, tests first, code-only parts need no AI credit:
1. **Today:** families A (world markets), B (world macro), E (overnight India) on the system channel; the replay proof of Fri 20 Nov
   night (show each line and time it would have sent).
2. **Before Sunday 19:45:** C (India market), D (F&O share), F (flows) detectors live on the page as AMBER / RED, Telegram after the
   ring test; G (India official news) - poll RBI, SEBI, PIB, GST Council, Supreme Court / NCLT, NSE / BSE circulars - new release ->
   R4 grades it; H (company surprise) on the 11-second filings path with R1.
3. **Before Monday 08:30:** I (world news surprise) via R5 + the economic calendar with consensus bands; J (calendar surprise) via
   seat 34 + the head; the reserved SHOCK budget ($1.00 trading / $0.50 weekend, from READ); flood control (max 8 RED a day, quiet-night
   rule, one per story, AMBER for the rest); the low-credit warning; 15:45 scoring of every shock.
Report each family as LIVE / page-only / not yet, with its test.

## 21 Nov 08:05 IST - THE TRADER: "not even once did the desk alert me that the US market fell" - a WORLD SHOCK alert that cannot fail
Why it was silent on Fri night: the API credit ran out at 01:32 IST (US close 02:30 IST), the weekend budget day was already at 90% of
$1.50 (readers event-only), and the new desk's Telegram is WOULD SEND until the Sunday ring test. Three blockers at once. Fix, today:
1. **WORLD SHOCK ALERT in CODE ($0, no AI, works with no credit):** S&P 500, Nasdaq, Dow futures / cash, Nikkei, KOSPI, Taiwan, Hang Seng,
   Brent, gold, USDINR, US 10y - a move of >= 2% (index / commodity) or >= 15 bp (10y) or >= 0.8% (USDINR) from the previous close,
   checked every 5 minutes 24 x 7, including weekends and the US session at night. It sends ONE Telegram line now (system channel,
   allowed today - this is a P1-class market fact, not a keyword news item): "WORLD SHOCK 02:30 IST: Nasdaq -5.3%, S&P -3.7%, SOX -10.7%
   - India opens Monday 09:15; desk brief to follow". One line per instrument per session, then one update if it moves another 1%.
2. **Reserved WORLD money:** $0.50 of every budget day (weekend and holiday days too, inside their caps - take it from READ) is kept
   ONLY for the world reader + head to write the CAUSE card after a WORLD SHOCK ("WHY: ..." with 2+ sources). The ladder never spends it
   on anything else.
3. **Low-credit warning:** when the API balance (or the rate of refusals) shows less than 3 days of the $8 cap left, one P1 line to the
   trader BEFORE it runs out. Check the account balance daily if an API allows; else alert on the first refusal (already built).
4. Prove it: replay Fri 20 Nov 21:00 -> Sat 03:00 IST through the shock checker (code only) and show the line it would have sent and
   when. Then switch it on.

## 21 Nov 07:50 IST - THE TRADER: (1) PAUSE the old trading programs; (2) no more rehearsal spend; (3) account for the money
1. **PAUSE raven, raven-manage, raven-preopen, hunter-scan / -manage / -execute, eqfloor@scan / -manage / -execute.** Safely, in this
   order: (a) read-only check first - any OPEN real position or pending order any of them manages (Kite positions / orders, their own
   state files)? (b) if NONE: stop + disable every unit (do not delete code or state), log each with an undo line; (c) if ANY open
   position or order exists: pause only the scan / execute units, leave its manager running, and report the position to the trader at
   once. Also report the yes / no "can it place a real order" answer per unit with the code line. GIR never places orders.
2. **The 20 Nov re-run is CANCELLED** - no more rehearsal money. Sunday 19:45 and Monday are the tests.
3. **SPEND ACCOUNT, this week (15-21 Nov), from aispend ledgers + logs, by user of the API key:** the new desk (live), rehearsals
   (FULL1-4 = $22.28), shadows / API probes, the old system's AI (v2 news reader, GO NOW / triage, old desk notes), and Claude Code on the
   server - it ran on "API Usage Billing" until the trader re-logged it onto his subscription at about 06:48 today, so its usage came out
   of the same API balance. Put the table in STATUS with totals per day; if a user is not in a ledger, say so and estimate from the
   Console usage page categories (the trader can read the Console total).

## 21 Nov 08:55 IST - THE TRADER: "keep a watch on Monday, alert me where the money is going, and tell me in the GO card"
Before Sunday 19:45 (code, $0 AI unless stated):
1. **MONEY FLOW line, live 09:15-15:10, every 5 min** on the F1 Desk + phone (existing boxes, no new page): top 3 sectors money IN and
   top 3 OUT (whole-sector %, breadth, turnover vs its 10-day normal, % of names above VWAP), plus the pairs that matter today:
   insurers vs BANKNIFTY, private vs PSU banks, IT vs ER&D / EMS, defensives (FMCG, pharma) vs NIFTY. Use the existing ROTATION
   module (official sector indices + the PSU / private bank groups). Words: "MONEY: into INSURERS, CAP GOODS · out of PSU BANKS, EMS".
2. **ROTATION ALERT, at most 2 a day, rings once:** when a sector flips - its breadth >= 60% one way, turnover >= 1.5x normal, the
   sector above (or below) VWAP, and opposite to a sector it is paired with - the head writes one line: what is moving, from where,
   why (card ids), and which F&O names to watch both sides. Not a BUY NOW; labelled NOT PROVEN.
3. **GO card (F1 BUY NOW) gets a "MONEY:" line** next to FROM / AGAINST: is the money flowing INTO this share's sector right now (yes /
   no / mixed, with the breadth and turnover numbers from code). A CE against an outflow, or a PE against an inflow, needs the
   AGAINST-THE-MONEY reason in words, like the market-VWAP rule.
4. **The head's briefs (19:45 / 07:15 / 09:08) carry a ROTATION TABLE:** the overnight cause, where FII money is likely to go
   (laggard / under-owned vs EXTREME sectors from the sector RSI table), the CE and PE candidates per sector, and the 09:20 checks
   that confirm or kill each. Test: the Sunday 19:45 brief is compared by the desk with EVENT_MEMORY section K (the desk's manual read
   of 21 Nov) - report what it matched and what it missed.

## 21 Nov 08:15 IST - naming + a rotation check for the briefs
- Use "US OVERNIGHT SUMMARY" on pages and briefs (not "US close card"); India's own 15:30 close stays "the close".
- Rotation check every brief and at 09:20: insurers (HDFCLIFE, SBILIFE, ICICIPRULI, LICI) vs BANKNIFTY. Insurers are NOT in BANKNIFTY
  (they sit in FINNIFTY). Insurers above VWAP while BANKNIFTY is below = money moving out of banks into insurers (rotation); both up =
  FII buying all financials; trade insurance through the insurers' own options, never through BANKNIFTY.

## 21 Nov 07:40 IST - THE TRADER: "you are not reading the news - the biggest flaw". US Fri 20 Nov: S&P -3.11%, Nasdaq -4.67%
GIR's own world reader (R5) and world seats must say WHY a big world move happened - every time. Orders:
1. **Now that credit is back:** run R5 + seats 1 / 2 on the US close of Fri 20 Nov (the AI was refused overnight) and show their cards in
   STATUS: the named cause(s) with sources, what fell / rose, and the India chain. If R5 found no cause, say which sources it read
   and why they were empty - that is a feed gap to fix (Reuters / CNBC / MarketWatch / Investing.com US market-wrap pages, the
   Nasdaq.com close wrap, the Indian outlets' "US markets" stories).
2. **Standing rule - "NO CAUSE" is not an answer for a big move:** on any world move >= 1.5% (S&P, Nasdaq, Nikkei, KOSPI, Taiwan, Hang
   Seng, crude, gold, DXY) the world reader keeps searching its feeds every 15 minutes until it has a named cause from 2+ sources, or
   writes the best LIKELY cause marked LIKELY with its sources. The head's brief must carry "WHY: <cause>" for the overnight move.
3. **"US OVERNIGHT SUMMARY" (renamed from "US close card" - the trader: India's close is 15:30, the US close is a different thing)**
   ready by 03:30 IST every US trading night: the US market closes at 16:00 New York = 02:30 IST (Nov-Mar) / 01:30 IST (Mar-Nov): index moves, cause, sector moves, breadth, VIX,
   10y, dollar, gold, oil, and the India chain (who gains / loses). On weekends it waits for the Monday 07:15 brief.
4. **Rotation, not just direction:** when FII money is expected to come in, the brief must name WHERE it goes - weighting laggard,
   under-owned sectors over EXTREME ones (banks are EXTREME after the November run) - using rallyscan / sector RSI and NSDL flows.
The desk's own manual read of the cause and the rotation lands in EVENT_MEMORY section K within the hour.

## 21 Nov 07:25 IST - THE TRADER CONFIRMS: keep the $8 daily AI cap (trading days), $1.50 weekend / holiday; continue as planned
Review after week 1 (Fri 27 Nov) on the EDGE scorecard: if the desk's calls are not worth it, step down to the ~$3-4 option (readers on
free rules, AI only for briefs + BUY NOW checks) or off. Report the week's spend by bucket with the week-1 summary.

## 21 Nov 07:10 IST - THE TRADER: the OLD system floods Telegram all night (rules / keyword only, no AI) - inventory + silence NOW
His Telegram at 06:54 Sat: GIR Market News 472 unread (05:47 "URGENT - GNews Regulators"), GIR F&O Live 281 (04:47 "URGENT -
Investing.com"), GIR Regulator Watch 72, GIR Whales & Filings 205, GIR Live (system + "My Stock Alerts: ESCALATION"), GIR Trade now
110 (DIGEST), GIR Ledger, GIR Box Picks. Market shut, yet "URGENT" lines at 04:47 / 05:47.
1. **Inventory (read-only, today):** every process / timer that sends Telegram: unit name, the chat it sends to (by env-var NAME,
   never the value), messages in the last 24 h, rule or AI. Put the table in STATUS.
2. **STANDING RULE CHECK:** TG_CHAT_FO and TG_CHAT_OI must never be used. Is "GIR F&O Live" (or any channel above) TG_CHAT_FO or
   TG_CHAT_OI? If yes, that sender breaks the rule - stop it now and report.
3. **Bring J6 forward and widen it - TODAY (weekend, market closed):** silence the old NEWS broadcast senders (Market News, F&O Live,
   Regulator Watch, Whales & Filings, Box Picks, the old Trade-now digests and "My Stock Alerts" escalations). Keep only: system P1
   alerts (one line each, GIR Live / system bot), the weekly Ledger export, and gir-watchdog / paper_exit_monitor untouched (list what
   they send). Their feeds and stores keep running as the desk's EYES - only the Telegram sends stop. One flag per sender, logged, with
   an undo line.
4. **From Monday:** the new desk speaks on ONE channel only (BUY NOW, manage notes, the 07:15 / 09:08 / 19:45 brief headline);
   Telegram stays WOULD SEND until the Sunday 18:30 ring test passes. No "URGENT" from keyword rules ever again - urgency comes only
   from the head analyst or a P1 system fault.

## 21 Nov 07:00 IST - THE TRADER TOPPED UP the Anthropic API credit; Claude Code on the server now uses his subscription
- The builder (Claude Code on the server) re-logged in on the trader's Claude subscription (Ultra) at about 06:48 - it no longer
  spends the API credit. GIR's own ANTHROPIC_API_KEY (.env) is separate and now has credit again.
- **Confirm in STATUS:** the fail-safe probe cleared ("P1 cleared" line) in gir-v2desk, gir-v2engine and the news reader; one real
  minimal call per family passes; the weekend day's readers resume within the $1.50 ladder. No restarts needed if the probe clears.
- **Weekend list from the trader (after hours, test after each step):** swap at 95% (find users, stop leftover rehearsal processes,
  clear safely), disk 68%, the 30 Ubuntu updates incl. 4 security, remove the old gircrypto login lines.
- The 20 Nov fair re-run (leak guard) still waits for the trader's yes / no.

## 21 Nov 05:30 IST (hourly) - 04:35 orders ACCEPTED; cap 2; the leak guard makes a FAIR 20 Nov re-run possible again
- **ACCEPTED:** MCX in the gold group; reader benches by story and source type; group cap with the liquidity source labelled; the
  REPLAY-LEAK GUARD (knowsnap.py: knowledge files from the commit before D-1 15:40, dated lines stripped from prompts, replay FAILS on
  any later date, --allow-leak labels it) - exactly right; FULL2-4 relabelled "knowledge snapshot NOT controlled".
- **Group cap: 2 members per group card** (+ any member named directly). Aim ~40 names.
- **20 Nov re-run, revised desk view:** with knowsnap the re-run no longer sees 20 Nov outcomes (0 hits) and uses the OLD row 5 and no
  20 Nov lessons. So it is a FAIR test of the CODE fixes (routing, consensus + not_picked, light morning briefs, retry reserve, group
  expansion) - not of the lessons. Still the trader's choice ($2.5 above the $24, needs the credit top-up). If he says yes: run it
  with knowsnap, no --allow-leak, side-split score + post-mortem with consensus picked / not picked.

## 21 Nov 04:35 IST (hourly) - answers to 03:38; a REPLAY-LEAK finding that changes the 20 Nov re-run advice
- **ACCEPTED:** knowledge reload (pack, seats, reader prefixes, engine chains.json - row 5 PE side now MUTHOOTFIN, MANAPPURAM,
  KALYANKJIL, TITAN, MCX); the lesson; ranking (a) + (b) + (c); the honest 20 Nov check; the 03:42 backup correction (regenerated
  original + undo line) - fine, thanks for saying so.
- **Your 3 questions:**
  1. **Gold-linked group:** add MCX (F&O; already on row 5's PE side). IIFL is not in F&O - leave it out of the option groups (it stays
     a data-only witness on cards).
  2. **Readers as benches:** reader cards count as ONE bench per distinct story (R6 story id), and at most TWO reader benches in
     total, only when the stories differ AND come from different source types (filing / wire / TV). Six cards on one story = one bench.
  3. **Group-expansion cap: YES.** Per group card, only the top 3 members by option liquidity (December ATM volume + OI) enter the
     ranking, plus any member a card names directly; the rest show "via group X - not ranked". Keeps the list near 40.
- **REPLAY LEAK (new, important for every future replay):** the seat / head prompt EXAMPLES now contain 20 Nov outcomes (e.g. 19_banks.md
  section 6: the Bank Nifty record close, INDUSINDBK +8.59%, private vs PSU), written from SECTOR_MAP_20NOV / OUTSIDE_WATCH. A replay of
  20 Nov (or earlier) with these prompts can "know" the answer - it can only inflate the score. So:
  - FULL3's NO EDGE stands (if anything it was flattered).
  - Any re-run of 20 Nov is NOT a fair test. Desk advice to the trader changes to (b): skip it; Sunday 19:45 and Monday are the
    first fair tests of the fixes.
  - Rule for all replays from now: the replay loads prompts / packs / lessons / LINK_BOOK as they stood BEFORE the replayed day's
    15:40 the evening before (git snapshot by date), or strips example blocks dated on / after the replayed day. The replay summary
    states the knowledge snapshot it used. Add a check that fails the replay if any loaded text names a date >= the replayed day.

## 21 Nov 03:35 IST (hourly) - routing + consensus ACCEPTED; ranking decision: (a) + (b) + (c) group expansion; a knowledge fix
- **ACCEPTED:** footer wording + meter fix; ROUTING (session-window board, every strength >= 3 card since the last look, "DROPPED FROM
  THIS INPUT: <reason>", test); SEAT CONSENSUS list + validator; post-mortems with consensus picked / not picked; the honest finding.
- **Prompt files changed in this push (load them):** CONTRACTS.md head output gets `not_picked` exactly in your shape (optional in the
  schema; code enforces it for the top 5); H_head_analyst.md step 2 now carries the consensus rule and "read LESSONS first".
- **RANKING DECISION - all three:**
  (a) **Strong single source ranks with bench count:** an OFFICIAL card, a weight-4+ card, or a LESSON match counts as two benches;
      such names are flagged "single source" and take at most 2 of the top 5.
  (b) **Lessons reach seats 7 / 8 / 19 / 20** (done) - so more benches name the group next time.
  (c) **GROUP EXPANSION (the main gap, why MCX / TITAN / IIFL were absent and INDUSINDBK was #31):** a card whose target is a group or
      sector (e.g. "gold lenders", "jewellers", BANKS_PVT, "gold-linked") counts for EACH F&O member of that group (SECTOR_LINKS /
      sectors.json / LINK_BOOK row members), at half weight per member, so a group story lifts its members up the list. List the
      expansion source on each line. Re-run the 20 Nov fake-brain consensus check with (a) + (c) and show where INDUSINDBK, AXISBANK,
      KALYANKJIL (PE), MUTHOOTFIN, MANAPPURAM, IIFL, MCX, TITAN rank at 07:15 and 09:08.
- **KNOWLEDGE FIX (why KALYANKJIL showed as CE):** LINK_BOOK row 5 said jewellers CE when gold falls. Corrected in this push: jewellers
  CE only over WEEKS; on a SHARP gold fall (-2% or a multi-month low before the open) jewellers fall the SAME DAY with the lenders
  (20 Nov: KALYANKJIL -3.37%, TITAN -1.70%; MCX fell with the group). Marked one episode, NOT PROVEN. Reload the link book and add the
  same line to event_lessons.json.

## 21 Nov 02:30 IST (hourly) - RED: API credit exhausted (trader told); post-mortem shows the HEAD is the bottleneck
- **ACCEPTED:** FAIL-SAFE on credit / auth refusal (pause 10 min, one probe per 10 min, one P1 line, STALE brief, no BUY NOW) - exactly
  right; chart bars + "data missing" (198 PASS); FULL4 19 Nov (0 of 4 head ideas; small sample); series closed at $22.28 inside $24;
  post-mortems 18 / 19 / 20 Nov; lessons in event_lessons.json marked NOT PROVEN; the 01:34 25-second incident (no calls, fixed).
- **Footer wording:** fix to "desk ON - next brief <day hh:mm>" between briefs; "desk OFF" only when it is off.
- **THE POST-MORTEM'S MAIN FINDING (20 Nov):** 11 of the top 20 movers were named by seat / reader cards and no head idea followed
  (INDUSINDBK +8.59% had 4 cards; KALYANKJIL 5 cards); 5 more were named by cards that never reached a head look's input. The seats
  see the stories - the HEAD and the ROUTING lose them. Orders, code first, before Sunday 19:45:
  1. **ROUTING:** find why 5 cards never reached a head input (cut by size, by age, by the snapshot key list?) and fix; a test that
     every card from the last look window with strength >= 3 is in the head's input or listed as "dropped: <reason>".
  2. **SEAT CONSENSUS LIST, built by code, top of every head input:** shares named by 2+ cards on the same side (or one OFFICIAL card
     plus price agreement), ranked by the number of benches, total strength and freshness. Head rule (H prompt + validator): every
     one of the top 5 consensus names must appear in the answer as an idea (any state, WATCH allowed) OR in a "not picked: <reason>"
     list. Code rejects an answer that silently drops one. This is the desk's own rule "two benches agree", made enforceable.
  3. **Add the same check to the post-mortem:** consensus names picked / not picked, so we can see if 1-2 fix the bottleneck.
- **20 Nov morning re-run:** the trader's money decision (asked now). If he says (a), run it AFTER 1-2 are in, so it tests them.

## 21 Nov 01:35 IST (hourly) - FULL3 (20 Nov, real brains): NO EDGE shown - accepted as an honest result; the POST-MORTEM is next
- **ACCEPTED:** FULL3 run and its honest score; the FULL3 lessons (keys / enums stripped, over-limit ideas dropped not the answer, a head
  retry reserve per brief); PROOF_F3; the scorer audit (naming minute -> close, pre-09:15 names from the previous close, NSE bhavcopy
  closes, NSE-equal bases, 5-share test) and the re-score; the rebuilt 19 Nov observer file and the separate rehearsal folder;
  MARKET vs VWAP (index day VWAP as the proxy, said on the card; tests incl. the gold group).
- **Bare counts: ALLOW** whole numbers 0-99 as counts in text ("3 cards", "19 items") - never with %, a decimal, Rs or a level word next
  to it. Prices / % / levels stay {num:key}.
- **19:45 floor: (a)** 19:45 $1.20, 22:45 $0.20.
- **THE MISS, read by the desk (20 Nov):**
  - The two biggest knowable stories were (1) GOLD at a 2026 low before the open (spot -1.9% by 08:27 IST, pre-open reports) -> PE on
    the gold-linked group (Kalyan -5.8% at the low, IIFL Finance, MCX, Muthoot, Titan, Manappuram); (2) FII money into banks -> CE on
    PRIVATE banks (IndusInd +10%, Axis +5%, HDFC Bank +2.7%). The head named PSU banks (BANKBARODA, PNB: flat) and TCS PE (wrong side).
  - Seat 19's own rule B11 says FII-flow news moves PRIVATE names more, PSU names on policy: the head did not apply it.
  - The 09:08 brief - the one that would have seen the overnight gold fall - was LOST (rejected answers). So the edge was never tested
    at the moment it mattered.
- **ORDERS (code first, then a small re-run inside the $24):**
  1. **POST-MORTEM table, code only, every replayed day:** the day's top 10 movers each side (NSE, >= 2%): did any seat card or reader
     card name it, when, with what reason and source; did the head see that card; why it was not picked (or picked late). Plus each
     head idea with its reasons and source card ids. File DESK_postmortem_<date>.md. This is how the desk learns - it feeds the
     scorecard weights and EVENT_MEMORY.
  2. **20 Nov MORNING RE-RUN with every fix in** (state from the 19:45 brief, then 22:45, 07:15, 09:08 and live to 11:00), side-split
     score from the naming minute. If FULL4 (19 Nov, partial recordings) has spent under $3 now, stop it and use its money for this;
     otherwise let it finish and run this with what is left. The $24 total stays a hard stop.
  3. **Head prompt, knowledge pack:** add the 20 Nov lesson to EVENT_MEMORY (gold-low -> gold-linked PE group; FII-into-banks ->
     private banks first, rule B11), so the head and seats 19 / 20 / 7 / 8 see it as a past episode.

## 21 Nov 00:30 IST (hourly) - verdicts on 23:36-00:02
- **KALYANKJIL vs NSE bhavcopy (17-20 Nov all agree): ACCEPTED.** The "no intraday bars" line = PAGE bug (levelChart never fetched
  ch.<SYM>): fix ACCEPTED as planned - bars from ch.<SYM>, a real gap says "data missing <from>-<to>". Must be live before Monday.
- **Recording gaps (18 Nov none; 19 Nov from 11:40):** FULL4 (19 Nov) must take 09:15-11:39 prices from the history minute store; if it
  cannot, score 19 Nov from 11:40 only and say so in the summary.
- **Weekend / holiday split (READ 1.00 / MEET 0.50 / seats on events / LIVE + ASK 0 inside $1.50): ACCEPTED** - your call was right.
- **23:35 fixes + PROOF_2220c: ACCEPTED.** Both morning briefs delivered, first LIVE refusal 14:38 (manage-only time), $6.96 of $8.
  Morning briefs at $0.58 (target 0.50 / 0.40 missed only because Connections had new weight-3+ items): accepted - within the floors.
  Watch on FULL3: head live looks cost ~$0.21 each (11 looks $2.34) - if FULL3 confirms, trim the live-look snapshot to the keys the
  look needs (section 6, snapshot_keys) before Wednesday; not a Monday blocker.
- **Retry fix (refused heartbeat no longer retries every minute; seat rejected twice = quiet 30 min): ACCEPTED.**
- **CE / PE (CE: and PE: lines required in every brief; side-split scoring; mirror test): ACCEPTED.**
- **DECISION - market futures vs VWAP: (b) witness line, NOT a hard block, plus one rule.** A BUY NOW against the index's VWAP side
  (CE while NIFTY / BANKNIFTY futures are below VWAP, or PE while above) is allowed only with a stock-specific reason - a weight-3+
  news / filing item or a whole-sector move - and the card says "AGAINST THE MARKET: <reason>". (20 Nov MCX PE on an up day was right
  because gold crashed and the whole gold-linked group fell.) Measure both sides after Monday on the replays before any hard block.

## 20 Nov 23:35 IST (hourly) - FULL2 (18 Nov) and PROOF_2220 verdicts - the new money rules still FAIL a Monday-shaped day
- **FULL2 18 Nov: ACCEPTED as a run** (mostly price-only day by design; small sample; NOT PROVEN). It also confirms the old split fails.
- **PROOF_2220 (Monday-shaped day on the 22:20 rules, fake brains): NOT ACCEPTABLE for Monday.** The 09:08 brief was REFUSED at 09:10
  ($0.43 left), SEATS went event-only at 09:16 and the LIVE bucket was FULL at 11:38 - no BUY NOW checks after 11:38 on a real day.
  Fixes, tonight, tests first:
  a. **Lighter morning briefs.** 07:15 and 09:08 re-check the OPEN ideas only (STANDS / CHANGED / CANCELLED with the overnight or
     pre-open delta). Connections runs only if a NEW weight-3+ item arrived since the last brief; the Devil only on a NEW idea,
     never on a repeat. Targets: 07:15 <= $0.50, 09:08 <= $0.40 (the 09:08 brief is a confirm / kill list, not a new meeting).
  b. **Floors are hard reservations:** a brief may use its own floor plus what EARLIER briefs left, never a later brief's floor.
  c. **Re-split the $8:** READ 1.20 -> 0.80 (it used $0.53), LIVE 1.70 -> 2.10. MEET 2.60, SEATS 2.20, ASK 0.30 unchanged.
  d. **Find the LIVE spend by caller** (head looks, second reads, seat wakes) and stop waste: seat 31 made 7 calls with 1 ok. Rule:
     a seat rejected twice in a row goes QUIET for 30 minutes (logged), so retries cannot drain LIVE.
  e. Run PROOF again with a-d: pass = 07:15 and 09:08 briefs both delivered, no LIVE refusal before 14:30, total <= $8.
- **FULL3 (20 Nov, real brains, 22:20 rules) is the real test** - its cost per brief and LIVE by hour decide the final split; report
  them with the EDGE score split by side (CE / PE), as asked at 23:10.

## 20 Nov 23:40 IST - KALYANKJIL settled: the trader checked Kite - the 19 Nov daily candle is GREEN (up). The page was right.
- Items 1-2 of the 23:30 entry drop to LOW priority: one code-only bhavcopy check of all 218 shares for 18-20 Nov after the
  rehearsal, mismatches listed in STATUS (no rush).
- Item 3 stays BEFORE MONDAY: why KALYANKJIL had no minute bars on 19 Nov, which other F&O shares had gaps on 18-20 Nov, and the rule
  that a share with missing data shows "data missing", never a % from an old price.

## 20 Nov 23:30 IST - THE TRADER disputes a price: "KALYANKJIL was negative on 19 Nov, the page showed +1.69% (661.00)"
Our own files: daily store 19 Nov close 661.0 (rallyscan.csv); 17 Nov evening levels ~700 (CE above 718.05 / PE below 685.10);
OUTSIDE_WATCH 20 Nov: 638.70 at -3.37% today (= 661 base). So the store implies 18 Nov close ~650 (about -7% on 18 Nov) and 19 Nov
+1.69%. Prove it against the exchange, tonight, code only:
1. NSE CM bhavcopy for 17, 18, 19, 20 Nov: KALYANKJIL OPEN / HIGH / LOW / CLOSE / PREVCLOSE, and the % each day. Compare with the
   store and with what the page showed on 19 Nov evening (661.00, +1.69%).
2. If the store differs from NSE by more than 0.1% on any day: find why (wrong previous close, a stale quote, a missed day) and check
   ALL 218 shares the same way for 18-20 Nov; list every mismatch.
3. The 19 Nov page said "no intraday bars in the store for KALYANKJIL": why were its minute bars missing, and which other F&O shares
   had no bars on 18-20 Nov? A share without bars must show "data missing", never a % from an old price.
Report in STATUS with the four days' NSE numbers.

## 20 Nov 23:10 IST - THE TRADER: "work both CE and PE" - check the PE side is really produced
The design is two-sided (head: up to 5 ideas PER SIDE; VWAP_LOSS / PDL_BREAK / DAY_LOW_BREAK triggers; seats fill winners AND losers).
Prove it in the output:
1. **Rehearsal summaries (FULL2-4) split everything by side:** ideas named, BUY NOW, hits, earliness and wrong-side rate - CE and PE
   separately, each against its own base rate (random F&O shares that rose >= 1% / >= 2% vs fell >= 1% / >= 2% that day).
2. **Every brief carries a PE line even on an up day:** the best PE candidates (shares below VWAP in the weakest sectors, with a
   reason) or "no PE today: <reason>". Same for CE on a down day. Code checks the line is present.
3. **Live:** a share that closes two 5-minute candles below VWAP with volume, in a weak sector with NIFTY / BANKNIFTY futures also
   below VWAP, is a PE candidate exactly as the mirror case is a CE candidate - same gates, same ring rules.

## 20 Nov 23:00 IST - answers to 22:48 (weekend readers, rehearsal rules)
- **22:20 money rules live (tests 56/56, the heavy-19:45 test, PROOF_2220 running): ACCEPTED.**
- **FULL3 (20 Nov) and FULL4 (19 Nov) on the LIVE 22:20 rules: YES - correct.** FULL2 (18 Nov) on the old split shows the old
  problem; FULL3/4 answer "does Monday's desk reach the afternoon on $8".
- **Weekend readers: (a).** On weekend and holiday budget days, one batch per reader every 20 minutes (not 5), all day. At about
  $0.025 an hour that is ~$0.60 a day, leaving room in the $1.50 for one head check on a real break. Keep the 22:46 night check.
  Nothing goes unread for hours. From Sun 15:40 (Monday's $8 day) the readers return to every 5 minutes.

## 20 Nov 22:28 IST (hourly) - verdicts on 22:00-22:18
- **Chain sanity gate (chaincheck.py, page + engine + desk, 13 tests incl. the 20 Nov fake chain): ACCEPTED.** Your skip of the 50%
  check after a full-exchange rebuild: accepted. Monday 09:15-09:30 watch: a chain past 180 s must show STALE with its reason on the
  page (never vanish silently); if more than 5 names go STALE at once, that is a FEED problem - log it as one P1 line, not 5 alarms.
- **E9 latched (tests a/b/c + both + floor setting, engine and engine_next; the desk keeps its own latch): ACCEPTED.**
- **OI base fix: ACCEPTED.** **STUB_CAD rehearsal (fake brains, $0):** plumbing proof only - accepted as such; its EDGE line is not a score.
- **FULL2 running (15-minute replay tick, $20.36): ACCEPTED.** Run order after 18 Nov: 20 Nov, then 19 Nov (22:10 entry).
- **Waiting on you:** apply the 22:20 desk decision to the LIVE desk tonight (Connections once per brief; 19:45 conference on the 5
  LEAN_COMBINED calls; unchanged seats not called; brief floors 19:45 $1.10 / 22:45 $0.30 / 07:15 $0.60 / 09:08 $0.60; buckets MEET 2.60
  / SEATS 2.20 / LIVE 1.70 / READ 1.20 / ASK 0.30; weekend and holiday days $1.50). Prove it with one test budget day in STATUS.
- **Still open for Monday:** J6 silence the old senders (Sunday), Kite auto-login dry run, the ring test, Sunday 19:45 first brief.

## 20 Nov 22:20 IST - DESK DECISION on the brief / seat money (FULL1 run 1 numbers): BOTH, plus two code rules
1. **Connections runs ONCE per brief** (twice was waste; a second run only if its first card was rejected - that is the retry).
2. **The 19:45 conference uses the LEAN_COMBINED calls (5 combined calls), not ~27 single seat calls.** Single seat calls are for
   live events in the day. A seat whose inputs have not changed since its last card is NOT called (it stays QUIET by code, $0).
3. **Each brief has its own protected floor:** 19:45 up to $1.10, 22:45 $0.30 (only on a break), 07:15 $0.60, 09:08 $0.60. The 19:45
   can never spend the 07:15 / 09:08 money.
4. **New split of the $8 (J11 buckets):** MEET (briefs) 2.60 · SEATS 2.20 · LIVE (BUY NOW checks, live looks, second reads) 1.70 ·
   READ 1.20 (night readers cost $0.33 for 177 calls - READ was too big) · ASK 0.30 = $8.00.
5. **Weekend days get a small cap:** Fri 15:40 -> Sat 15:40 and Sat 15:40 -> Sun 15:40 = $1.50 each (readers in slow mode only; no
   seats unless a weight-5 event). Sun 15:40 -> Mon 15:40 is Monday's full $8 (it holds the Sunday 19:45 brief). Holiday Tue 24 = $1.50.
- Apply 1-5 in the live desk tonight (tests first). The running rehearsal keeps today's split, as you said - it shows the problem.
- **Rehearsal order:** run 2 started at 22:00 in the 18 -> 19 -> 20 order. After 18 Nov finishes, run **20 Nov next**, then 19 Nov
  with what is left: 20 Nov is the only fully recorded day and must not be the one cut.

## 20 Nov 22:10 IST - data checks ACCEPTED; rehearsal restart ORDER
- **Data checks 1-3: ACCEPTED** (only the 3 repaired files + 2 normal logs touched; 0 flat-100 IV rows left, 52 removed; the rebuilt
  base covers all 9,812 contracts; a missing contract shows "not known", never 0). Gate, latched E9 and the 15-minute replay cadence:
  accept when the builder's tests pass.
- **FULL1 restart - run the days NEWEST FIRST: 20 Nov, then 19 Nov, then 18 Nov.** The desk's edge is knowledge, and the recordings
  it needs started on 19 Nov (TV from 19 Nov, the news reader from the 19 Nov evening). 20 Nov is the only fully recorded day, 19 Nov
  is partial, 18 Nov is mostly price-only. If the $20.36 runs out, it must be 18 Nov that is cut, not 20 Nov. In the summary, mark
  each day's EDGE score with what was recorded that day (news / TV / filings: full, partial, none), so a weak 18 Nov is read correctly.
- Same yardstick as always: precision and earliness of the named picks vs the day's random F&O base rate, by source; top-5 hit
  rate; wrong-side rate; cost per day; the hour the $8 ladder would have stepped down live.

## 20 Nov 21:55 IST - on the 21:48 DATA REPAIR (test overwrote 3 live files) and the E9 question
- **Repair: ACCEPTED - well caught.** OI base from NSE's official 20 Nov F&O bhavcopy, fake IV rows out, fake chain out, test isolated,
  originals quarantined with an undo line. Four checks before Monday, please, each one line in STATUS:
  1. **Full damage list:** every file under the live data folders modified between 17:03 and 17:10 today (find -newermt). Confirm
     nothing else (quotes store, fo_daily, premium recordings, the desk board) was touched; restore from quarantine / source if so.
  2. **IV rows by VALUE, not only by time:** you stripped rows after 15:45; a fake row stamped inside market hours would survive.
     Also drop any row for the test's 5 symbols whose prices were the test's flat 100, whatever its time. Show the counts.
  3. **The 22 contracts** in Thursday's base but not in the bhavcopy: Monday's OI change for them shows "n/a", never 0 or a huge %.
  4. **A permanent CHAIN SANITY GATE in code** (the real lesson): a chain is INVALID - not shown, not given to the desk, flagged
     STALE on the page - if its ATM strike is more than 3% from the live spot / future, if more than half its premiums are equal, or if
     it is older than 3 minutes in market hours. Same gate for the OI base (contract count < 50% of the previous day's = INVALID).
     Plus your new rule: every test redirects all outputs and asserts the live files are unchanged.
- **E9 give-back - the desk's 21:28 wording was WRONG; corrected rule:**
  - The give-back lock is LATCHED: once the day's peak reached the floor (setting, default five thousand rupees) and he has given back
    the set share of it, the PROFIT LOCK fires and STAYS on for the rest of the day, even if the day then turns negative.
  - If the peak reached the floor and the day falls from it straight into the red between two checks (a fast drop), the give-back
    lock fires at once, latched, with the reason "peak given back".
  - Peak below the floor: no give-back lock; only the LOSS lock at its own limit.
  - The LOSS lock is independent; if both fire, the page shows both. Label from what fired, never from the sign of the day.
  - Unit tests: (a) small peak then loss -> LOSS only at its limit; (b) big peak, give-back hit while positive, day ends negative ->
    PROFIT LOCK stays; (c) big peak, one-step drop into the red -> PROFIT LOCK fires at once. GIR only blocks BUY NOW; he decides.
- **Rehearsal cost (FULL1, $3.59 after the first 18 Nov brief):** keep the $24 hard stop - do not raise it. So all three days fit:
  in the REPLAY only, run the live looks event-driven plus every 15 minutes (not every 5), keep every brief (19:45 / 22:45 / 07:15 /
  09:08) and every BUY NOW check in full. The EDGE yardstick scores the named picks and their earliness; it does not need 5-minute
  looks. Report the cost per replayed day and the hour the $8 ladder would have stepped down live - that number tells us whether
  Monday's full desk reaches the afternoon on $8.

## 20 Nov 21:28 IST (hourly) - MILESTONE: desk fully on (39 seats, head PASS), FULL1 rehearsal running - verdicts
- **ACCEPTED:** the go-live shadow (head brief PASS 21:10, 35 / 37 seats PASS, readers R1-R6 PASS), 21 and 31 re-tested PASS, seats.json
  39 on (8 / 30 out by plan), Telegram WOULD SEND only. The $8 cap with LEAN_COMBINED as the automatic step-down and the $24 rehearsal
  line (both the trader's own choices at 20:28 / 20:55) - DESK_TEAM 4.7 / 4.8 numbers are now his $8, not $5. v2 news reader AI OFF by
  flag (R1-R6 replace it): accepted. Web items 1-3, 5, 6 on /preview, 144 PASS: accepted; item 7 (F8 tabs) may wait.
- **Your 4 questions - answered, and CONTRACTS.md fixed in this push (all 55 examples still validate):**
  1. **Clock times:** ALLOW HH:MM as text ("09:45", "15:10") - CONTRACTS section 0 changed. Every other number still needs a key.
     Make the one-line nums.py change.
  2. **Headline length:** seat cards up to 30 words (CONTRACTS + R3 / R4 / R6 changed). The head's BUY NOW headline stays 25 (phone card).
  3. **Trigger enum (your 21:03 note):** you were right, CONTRACTS contradicted itself. ORB5_HIGH / ORB5_LOW / GAP_HOLD are REMOVED from
     the enum; it now equals brain.py's code enum. Keep sending the head the exact allowed list.
  4. **Index ideas (BANKNIFTY):** ALLOW index options (SERVER_ORDER 6). NIFTY on its own expiry day -> the next weekly; BANKNIFTY has
     monthly only -> December (29 Dec). Same gates (spread, stale quote, R:R, lots for 1% risk).
- **E9 give-back (21:03): NOT intended - fix.** (SUPERSEDED by the 21:55 entry: the lock is latched.) Give-back ("PROFIT LOCK") applies only when the day's peak P&L reached a floor
  (default Rs 5,000, a setting he can change); below the floor, or once the day P&L is negative, only the LOSS lock rules apply and the
  label says LOSS, never PROFIT. Add a unit test for "small peak then loss". Do not print his P&L amounts in STATUS (public repo) -
  write "peak below floor, day negative" instead.
- **FULL1 rehearsal:** fine as running (recordings only, own ledger, hard stop at the $24 line). Report DESK_rehearsal_FULL1.md with the
  EDGE scorecard (precision and earliness by source, top-5 hit rate, wrong-side rate, vs the day's random base rate) and the cost per day.
- **Still open for Monday:** J6 silence the old senders (Sunday), Kite auto-login dry run, the ring test, the Sunday 19:45 first brief.

## 20 Nov 20:28 IST (hourly) - verdicts
(Clock note: the four entries below were first stamped 21:15-22:00 by mistake; corrected to their real times 20:12-20:24.)
- **J11 budget days split per calendar day (your 19:49 change): ACCEPTED.** Each 15:40 -> 15:40 day has its own $5 and buckets;
  Sun 15:40 -> Mon 15:40 = Monday's day; weekend days in slow mode; Tue 24 = holiday day. DESK_TEAM 4.7 updated to match.
- **Head gated until the prompts are reviewed: ACCEPTED** - the prompts are now reviewed and READY (20:12 entry). Un-gate the head
  once the LEAN shadow passes.
- **20:13 shadow (probe 7/7, 10 PASS): fixes accepted as sent;** the answers are in the 20:24 entry (lean shape, separate test cap,
  timeouts, no-digit keys, seat 8 out). No newer push since 20:13 - next: the LEAN shadow, then the $15 rehearsal.
- **Still open for Monday (MONDAY_READY):** J6 silence the old senders (Sunday), the Kite auto-login dry run, the ring test, the
  Sunday 19:45 first brief, the minimal page items 1-4 and 8 (DESK_WEB_CHANGES).

## 20 Nov 20:24 IST - on the 20:13 shadow (probe 7/7, shadow 10 PASS) and your question "does the 40-seat roster fit $5?"
- **Answer: NO, 40 separate seat calls do not fit $5 - by design.** Monday runs the LEAN desk: LEAN_COMBINED.md = 5 combined calls
  (GLOBAL seats 1-4, 6, 7; FLOWS with 5 and 9; FINANCIALS; INDUSTRIALS-METALS-ENERGY-INFRA; CONSUMER-IT-PHARMA-AUTO) on the SEATS
  bucket, plus the readers (READ), 35 + 36 + head (MEET), second reads (LIVE). The other seats are prompts only on Monday; they join
  one at a time in week 1 (desk_cost.py: lean Monday ~$4.14). Re-run the shadow in the LEAN shape, not 40 single calls.
- **Shadow / rehearsal money is NOT the day's $5.** Run shadows and the rehearsal under a separate TEST cap (the $15 one-off covers
  the rehearsal; shadows tonight ~$1-2 count against it). Never let a test fill Monday's SEATS bucket.
- **Timeouts:** Connections 80 s and head brief 355 s - use streaming with a 600 s ceiling for the 19:45 / 07:15 briefs and 180 s for
  35, and trim the snapshot to the keys the call needs (CONTRACTS section 6, `snapshot_keys`). A brief that times out falls back to
  the last good brief, labelled STALE, never to nothing.
- **No-digit rule on seats 9-11:** rates / rupee / policy seats must still write {num:<key>}; if a needed number has no key, add the
  key to the snapshot (section 6) - do not relax the rule. Retry once quoting the offending words.
- **Seat 8:** writes no card on Monday (gold rides in seats 2 and 20, LEAN_COMBINED) - drop it from the shadow.
- **Readers:** JSON-in-text on every path (batch too), validated in code - correct.
- When the lean shadow passes: run the $15 rehearsal on 18 / 19 / 20 Nov and score it on EDGE.

## 20 Nov 20:20 IST - NEW STANDING SOURCE: summits and meetings (design_v3/SUMMITS.md)
The trader: "All these summits and meetings are very critical to study the market news and trend." Summits (chambers, sector bodies,
broker investor conferences, company days, regulators / ministers on a stage, RBI MPC / SEBI board / GST Council, global meetings)
are now a standing desk source: calendar before, live reading on the day, EVENT_MEMORY after, scored by speaker type and line type.
Seat prompts 34 / 35 / 37 updated. SUMMIT_CALENDAR.md (dates + past statements with sources) lands next.
**Order: AFTER Monday's must-haves (shadow pass, rehearsal, J6).** Then build SUMMITS.md section 6: the `summits` table (1), the
stream URL per event in the STT recorder (2), the reader tags (3), the scorecard grouping (4), and the one-off backfill pricing of
the past statements after 15:35 (5, code only, no AI cost). No new page.

## 20 Nov 20:16 IST - on the 19:58 shadow ("compiled grammar too large") - with the READY prompts
- **Your second fix is right: do NOT send the full CONTRACTS schema to the API.** Per call, send only a SMALL API schema: the seat card
  core (seat, kind, headline, strength, claims, winners, losers, evidence, new_since_last, expires, proof, linked_card_ids, links) plus
  that ONE seat's own block from `$defs` - no `allOf` / `if` / `then`, no other seats' blocks, keep `enum`s short. If one family is
  still too big, use JSON-in-text for it (no structured output) and validate in code. The FULL CONTRACTS schema (now closed, with the
  winners / losers rule) always runs in code after the call - that is the real gate.
- **Combined calls (LEAN_COMBINED.md):** the API schema is the envelope with one slot per seat, each slot = core + that seat's block.
  Test one real call per family (readers, world, sector, devil, head) before the next shadow, as you planned.
- **R2 / R5 'proof':** the fixed reader examples all carry `"proof": "NOT PROVEN"`; with the small schema make `proof` required
  with that one default value, or let code fill it if missing (it is never the model's decision).
- **Devil 36 invented card id:** 36_devils_advocate.md now says target_card_id is copied from the input only, else QUIET. Keep the
  validator rejecting unknown ids. Also give 36 the head DRAFT ids in its input (it objected to "banks_theme_draft" because no id
  existed for the draft it was shown).
- **Bare digits in text:** keep rejecting, but on the retry quote the offending words back to the model ("27, 34") so it fixes them.
- Seat 15 "no reader card": run the readers first in the same shadow, as your note says. Then the $15 rehearsal.

## 20 Nov 20:12 IST - SEAT PROMPTS READY: switch the AI seats on (intraday_patches/desk/prompts/)
All 12 reviewer problems are fixed. CONTRACTS.md now has three schemas (seat card, head output, combined-call envelope), all objects
closed. Every one of the 55 example cards in the prompts validates (jsonschema Draft 2020-12, 0 errors), and 13 deliberately broken
cards are rejected as expected. Wire these, in order:
1. **CONTRACTS.md:** load the three schemas. Strict structured outputs reject `if`/`then`/`dependentSchemas`, so build a FLATTENED
   per-seat schema at load time (the seat -> block table is in CONTRACTS) and keep the full schema as the code validator after the call.
2. **Winners / losers rule:** seats 1-10 and 19-27 must name winners AND losers on every VIEW / ALERT / THEME; a side with no name is one
   `target: "none"` row with a reason. Reject and retry once, then QUIET.
3. **Placeholders:** the snapshot builder emits exactly the keys in CONTRACTS section 6 and passes the present ones as `snapshot_keys`.
   A `{num:...}` key outside that list = reject the card.
4. **R6 story matcher:** gets the raw item + target ONLY, never the first reader's card. Code sets the verdict. R6 never stands in for
   the BUY NOW second read (seat 15 or the linked sector seat does that; a single-seat second read bills to LIVE).
5. **LEAN_COMBINED.md:** the five Monday combined calls (GLOBAL seats 1-4, 6, 7; FLOWS carrying 5 and 9; FINANCIALS;
   INDUSTRIALS-METALS-ENERGY-INFRA; CONSUMER-IT-PHARMA-AUTO), SEATS bucket, the prompt order for caching, the envelope schema, the
   failure handling and the budget ladder. Seat 8 writes no card on Monday (gold rides in seats 2 and 20).
6. **Source grades:** one table, CONTRACTS section 5 (TV exclusive = SOURCES SAY, broker on air = OPINION, SOCIAL = social posts only).
Then run the rehearsal of the NEW desk on recorded 18 / 19 / 20 Nov ($15 one-off, approved) and score it on EDGE. Report in STATUS.md.

## 20 Nov 20:30 IST - all seat prompts written: intraday_patches/desk/prompts/ (48 files)
R1-R6 readers, seats 1-40, H_head_analyst.md, CONTRACTS.md. The reviewer passed the content but found contract gaps (positive-
thinking rule not enforced in the schema; per-seat blocks not defined; R6 second-read independence; small rule fixes) - the fix
is in progress and adds LEAN_COMBINED.md (how the Monday combined calls are assembled). Start wiring the loader and the
validators to these files now; switch the AI seats on when the fixed CONTRACTS.md lands (next push, marked READY).

## 20 Nov 19:30 IST (hourly) - on gir-v2desk running + core plumbing
- **Accepted:** snapshot, J11 gate with buckets, SQLite board, validators, head scheduler with Devil-before-head and the second-read
  chain in code, 46-seat roster, gir-v2desk installed and running with code seats 32 / 33 (Telegram OFF). Good work.
- **Open decision - does the v2 news reader (~$2.6 / day) count in the $5? Desk decision: YES, everything AI counts in his $5,
  and the v2 news reader is REPLACED by the desk's own readers R1-R6 (Haiku, designed at under $1 a day for all items) as soon as
  they run.** Until then it runs on the READ bucket and the seat buckets are trimmed to fit; once R1-R6 are live, switch the v2
  reader's AI off (its non-AI fetching stays as the eyes). No new money is needed.
- **Pages: do NOT build a "Desk Room" page** - design_v3/DESK_WEB_CHANGES.md (20:15 entry) is the page rule: the desk speaks through
  the existing F1 GO NOW card, desk-trade GIR row, Morning brief band / ideas table, F8 tabs and the Ask box.
- **Seat prompts:** landing in intraday_patches/desk/prompts/ now (14+ files so far; the reviewer pass follows). Wire the AI seats
  as each file lands; switch a seat on only after its prompt has passed the reviewer (CONTRACTS.md lands with the head prompt).

## 20 Nov 20:15 IST - WEB / PHONE for the new desk: design_v3/DESK_WEB_CHANGES.md REPLACES DESK_TEAM.md section 6
The trader: the approved v3 design stays. No new "Desk Room" page, no redesign. The desk speaks through the existing boxes
(F1 GO NOW card = the head's BUY NOW with FROM / AGAINST / NOT PROVEN; desk-trade GIR row = manage notes; Morning plan band +
19:45 ideas table = the evening brief; F8 Analyst tabs = themes + seat roster; the existing Ask box). Build its Monday list in its
order (1-4 and 8 are the minimum, then 5, then 6; 7 drops first). The rest waits for week 1.

## 20 Nov 19:45 IST - the desk is building the BRAIN CONTENT now: intraday_patches/desk/prompts/
One prompt file per seat (R1-R6, 1-40, H head analyst) + CONTRACTS.md (seat card + head output JSON schemas), written by senior
desk builders and checked against DESK_TEAM.md - lands tonight. Server: keep building the plumbing (snapshot done; board, gate,
scheduler, head loop); load the seat prompts from that folder, do not write your own. The old v2 engine replays are NOT the
test of the new desk - the only rehearsal is the new desk on recorded 18 / 19 / 20 Nov after it is built.

## 20 Nov 19:30 IST - THE TRADER APPROVES the one-off ~$15 rehearsal (full Opus layer) - order of work
"15 dollar. Ok." The rehearsal runs only AFTER the new desk is built - it cannot replay a desk that does not exist yet:
1. Saturday: build the core, then the benches (19:20 entry).
2. Saturday night: REHEARSAL - run the new desk on the recorded 18 / 19 / 20 Nov news, TV, filings and prices, minute by minute,
   each seat seeing only what existed then; full Opus head layer allowed, one-off cap $15 on its own budget line (not the daily $5).
   Score on the EDGE yardstick (top-5 hit rate, named before, wrong side, by seat / source). Push the scorecard.
3. Sunday: fix what the rehearsal shows; shadow run on Sunday's live news; 19:45 the first real evening brief for Monday.

## 20 Nov 19:20 IST - THE TRADER: "BUILD EVERYTHING FROM NOW" (overrides the phased plan in DESK_TEAM.md section 7)
Build ALL 40 seats / 10 benches this weekend, not one bench a day in week 1. Order of work: the MINIMUM first (head, flows,
connections, devil, filings reader, second read, desk board, snapshot, J11 gate) so Monday has a working core even if time runs
out, then every other bench in the section 7 order, then the web Desk Room + phone + Telegram changes (section 6).
Go-live rule for Monday: every seat that is built AND has run once in shadow on Sunday's news (cards valid, no errors, inside
its budget bucket) is live; a seat that is not ready stays off and is listed in STATUS.md - no seat is dropped from the build.
The replay test is the NEW desk on recorded days (18 / 19 / 20 Nov news, TV, filings, prices), not the old desk: run its free
layers (stub + Haiku); the full Opus layer (~$15 one-off) waits for the trader's yes.
Budget: keep the J11 hard gate at $5 a day until the trader raises it; at $5 the seat-pool sub-cap trims the busiest seats first
(DESK_TEAM 4.7). Report on Sunday noon what is built, what is live, and the measured cost per seat.

## 20 Nov 19:00 IST - DESK_TEAM.md is FINAL (panel + checker ok): build the Monday MINIMUM desk this weekend
Read design_v3/DESK_TEAM.md (verdict section 1, overrides 1a, seats 2.2, AI + budget 4.1-4.8, architecture 5, web / phone 6, build
order 7 with the cut line and drop order) and design_v3/desk_cost.py. Monday MINIMUM: gir-desk service + SQLite DESK BOARD +
validators + snapshot.py + HEAD + FLOWS (5-day-sum rule, LOW grade) + CONNECTIONS + DEVIL + R1 filings reader + seat-15 second read,
web items per 6.5. Binding: no seat goes live before J11 (one hard $5 gate in code, sub-buckets per 4.7); J6 silences the old
timers and the old AI desks before Mon 09:00; load watch per 5.8 with the fallback (readers + head only). Tell the trader by
SUNDAY NOON honestly whether the MINIMUM or the fallback ("head analyst not running") will be live Monday.
Open for the trader (asked by the desk): the one-off ~$15 replay spend; whether BUY NOW rings Monday NOT PROVEN; GET READY tick;
week-1 $5 vs ~$6. Until he answers: his order stands, the $15 replay waits, the free replay layers run.

## 20 Nov 18:30 IST (hourly) - on the EDGE scorecard (E1_edge_SUMMARY.md) and I1-I8
- **EDGE scorecard: accepted as the yardstick.** Honest reading: across all runs no group has a proven edge yet (n small); "all
  names" sits at the base rate (lift 0.73-1.88) because 100-280 names a day is a list, not a pick. Add to every run, per the
  trader's 18:00 rule: (a) the TOP-5 names of the day by the analyst's / engine's own rank, their hit rate and lift; (b) the >= 1%
  hit as well as >= 2%; (c) the next-close result; (d) names per day. The desk team (DESK_TEAM.md, landing tonight) will be judged
  on (a) first.
- **20 Nov unseen replay: 0 GO NOW, triage truncation + cost** - accepted that the fixes are sent; push the re-run.
- **I1 filings 11 s and I2 TV 29 s: MET.** Wires / regulators / world still late - keep going; Sunday re-measure.
- **D1 + D5 (871 PASS / 0 FAIL, masked shots): accepted.**

## 20 Nov 18:15 IST - TOP PRIORITY FROM THE TRADER: build the GIR ANALYST (design_v3/ANALYST.md)
"I want a complete new system - a senior F&O analyst inside GIR monitoring everything and telling me what to buy."
ANALYST.md makes the ANALYST the product (Opus 5.5 every 5 min + on events, a code-built DESK SNAPSHOT, cached knowledge pack, JSON
contract + code gates, thesis book, <= 5 ideas a side in the evening brief, <= 3-4 BUY NOW a day, manage notes, scored by
precision + earliness by source, $5 cap). Everything built so far becomes its eyes and gates. Weekend order is in its section 5;
it goes AHEAD of the remaining engine replays. Replays of 18 / 19 / 20 Nov are run on the ANALYST with the new yardstick.

## 20 Nov 18:00 IST - THE TRADER CORRECTS THE GOAL (supersedes the 17:35 entry's fixes 1, 2 and 4)
The trader: "My intention is not to catch all the 2% moves. My intention is the EDGE - the knowledge, the brain should catch the
CORRECT F&O shares based on the news, sectors, external news, internal news, companies' performance. It has to PREDICT BEFORE."
So the yardstick is PRECISION and EARLINESS of knowledge-driven picks, not coverage of every mover:
- DROP 17:35 fix 1 (forcing every 2% mover into a card) and fix 2 (gap-and-go cards). WATCH may hold price-only movers; that is fine.
  Cards are for ideas with a REASON (news, filing, TV / broker call, sector driver, results, his read) and a prediction made before.
- KEEP fix 3 (no cancel churn) and keep rings low.
- NEW SCORING for every replay and live day (replaces "cards before the move >= 10"):
  1. PRECISION: of the shares GIR named (19:45 / 07:15 / 09:08 lists + news calls + cards), how many moved the predicted way
     (>= 1% and >= 2%) by the close and by the next close - against the base rate of random F&O shares that day.
  2. EARLINESS: named before the move started (minutes ahead), and the move left after the name.
  3. WRONG-SIDE rate (named CE, it fell 2%+; named PE, it rose 2%+).
  4. BY SOURCE: news / filing / TV / broker / sector chain / results / trader read / price-only - each with its own hit rate, so the
     brain learns which knowledge earns trust.
  5. A few strong names a day beat many weak ones: report how many names a day and the hit rate of the top 5.
  Old system: scored the same way on what it named (for comparison only, not as the target).
- Re-score TEST_E1_1116 on this yardstick and push it; run the rest of E1 the same way.

## 20 Nov 17:35 IST - RED: E1 replay of 16 Nov (TEST_E1_1116) - the fixed engine still misses most movers
Cards (MUST SEE + CRITICAL) on the 54 F&O shares that moved 2%+: before 1 / late 19 / MISSED 34 / wrong 0 - old system 22 / 21 / 10 / 1.
Cards + WATCH: 3 / 44 / 6 / 1 - so the engine SEES most movers but leaves them in WATCH (the trader never sees WATCH). Rings 15 (good),
calls right 201 / wrong 178 at 30 min (near a coin flip), 456 cancel rows. This fails E2 / E3. Fix before the other replays count:
1. COVERAGE: a share moving 2%+ with its sector (or on its own news) must reach a CARD (MUST SEE), never stay in WATCH. Lane = rules
   first (move size, sector agreement, RVOL, news), the AI may only ADD reasons or downgrade on a named reject rule (B6), not demote by
   default. Log every demotion with its reason.
2. OPENING MOVERS (TMPV, AMBER, INOXWIND, EICHERMOT crossed 3% at 09:16): the 09:08 list's MOVER lines (A6b, both triggers) and a
   GAP-AND-GO card at 09:16-09:20 for any F&O share gapping 2%+ with pre-open volume and its sector the same way (side = the gap's
   way; PE if it holds below the opening range low, CE if above the high). The old system catches these at 09:16.
3. CANCELS: 456 cancel rows - an idea is cancelled only on its written cancel condition (price beyond the cancel level, thesis
   broken), not on lane churn. A cancelled card does not come back the same day unless a new trigger fires (B3).
4. SAME YARDSTICK: score new and old with the SAME rule (the observer's strict BEFORE / the gap-open minute 09:15 for both) and
   print both rows; keep the old run_report number beside it labelled "looser rule".
5. Re-run 16 Nov first with 1-4, push the scorecard, then 18 Nov, 29 Oct, 27 Oct, 20 Nov. The pass mark (E2) stands.

## 20 Nov 16:30 IST (hourly) - on STATUS 16:11
- **Engine 0.3 in the live shadow: accepted** (TV hold-offs and thesis cancels no longer ring; repeated news never re-rings; today's
  08:58-10:28 frames 15 -> 8 rings). Rings are now well inside 50 / 6 - the test that matters next is E2: CARDS before the move
  (incl. MOVER lines), not rings. Report cards and rings separately in every replay.
- **B9 December quote-age at 09:15: accepted as found, fix agreed.** Saturday: (1) gir-v2opt full December sweep starting 09:15:00 -
  card strikes first (the 09:08 list's ATM / 1-ITM), then all F&O ATM +-2; (2) show "premium loading" (not STALE red) for the first
  minutes so the page does not look broken; (3) measure on Monday 09:15-09:20 how long until 90% of the 09:08 list has a fresh
  December quote, and log it. Index options (NIFTY / BANKNIFTY next weekly / monthly) are liquid - put them first.

## 20 Nov 16:40 IST - on J1 (four-key auto-login) and the RAVEN guard
- **J1: accepted.** 07:40 staggered logins, skip-if-valid, 2 retries, never 09:00-15:35, stop-all on a wrong password, 08:20 profile +
  quote check, NSE calendar (no Tue 24), Friday test passed with no login. Two additions before Sunday's dry run:
  (a) a wrong-password stop or any 08:20 failure must reach his phone at once (after Sunday's ring test wires it) with the words
  "Kite key n failed: <reason> - GIR is running without it"; (b) retries for a failed key at 08:25, 08:35 and 08:45, then stop.
- **Key failover (open risk): desk decision for Monday** - no automatic move of key 3's option feed. If a key fails: the page marks
  the feeds on that key "DEGRADED - key n down", the engine treats those quotes as STALE (no GO NOW on them, per the stale rule),
  and the phone alarm says so. Full failover is a week-1 item, not a Monday blocker.
- **RAVEN guard: accepted** (backup + undo line logged). Also: (1) check today's logs - did RAVEN's 10:17 re-login drop any key-1
  connection (old engine, recorders)? Log the answer; (2) put "RAVEN service restarted with the guard" in Sunday's checklist with a
  proof line, so Monday never runs the old RAVEN code.

## 20 Nov 15:35 IST - THE TRADER'S DECISION on F5 server load: REMOVE CRYPTO
The trader: "I am not trading in crypto, so you can remove the crypto trading. I am only doing NSE options trading."
After 15:35 today:
1. List every crypto unit, timer and cron entry (gircrypto*, window2_news and anything else crypto-only) with what each does.
2. Check nothing GIR uses depends on them (shared files, .env entries, Telegram channels, ports, the dashboard). Report any link.
3. STOP and DISABLE all of them (systemctl disable --now; remove their cron lines). Do NOT delete their code or data: move them to
   an archive folder (e.g. /home/globalbot/archive/crypto_2026-11-20/) so it can be restored; disk space can be freed later on his word.
4. Never touch gir-watchdog or paper_exit_monitor; do not copy .env; keys stay where they are (he can revoke exchange API keys himself).
5. Measure the load after (load average at 15:45 and the CPU of the remaining jobs) and log it in STATUS.md F5. The 8-core resize is
   NOT approved; falcon / old timers stay, handled by J6 on Monday.

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
