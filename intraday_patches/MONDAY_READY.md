# MONDAY READY - the full new system live on Mon 23 Nov 2026, everything checked by 08:30 IST

The trader's order, Fri 20 Nov: "Monday we use the new system. Monday we use the full system. Check everything before that. Monday
8:30 everything is ready. That's my order. Make a checklist. Tell them what are the things to be checked. Everything. All the
subscriptions have been given. There is no reason to delay it." Work runs 24/7 from now until Monday 08:30.

Owners: **S** = the server session (builds, runs, tests on the droplet) · **D** = the desk in the cloud session (specs, studies,
independent review of every result S pushes) · **T** = the trader (only his own decisions).
Every item ends with proof pushed to branch `ccr-67e340f1-sko8xd` under `intraday_patches/monday/` (log, table or screenshot).
An item without proof counts as NOT DONE.

Monday facts: **November stock and index options expire Mon 23 Nov (physical settlement for stocks).** GIR suggests **December
strikes only** for stocks on Monday. GIR never places orders: he trades in Kite himself.

## Safety net (keeps his order and his money safe)
- The NEW system is the one he uses and the one that rings on Monday.
- The OLD system keeps running in the background, silent (no rings, no Telegram), logging its calls, so the two can be compared
  after 15:35 and so there is a ONE-SWITCH fallback: `gir mode old` brings the old alerts back in under a minute. S tests the switch
  both ways on Sunday.
- Hard limits stay on: 50 rings a day, 6 in any 15 minutes, the AI cost cap, the loss lock, no order button anywhere.

## A. Data and feeds (S) - by Sun 18:00
- [ ] A1 Kite login works with the Monday token flow; the four Kite keys carry their jobs (BUILD_PLAN 1.3); a dry run of the 08:00
      token refresh on Sunday with the real steps, and the alarm if it fails.
- [ ] A2 Every feed F01-F31 (BUILD_PLAN 1.2) shows its source, last update and freshness; any feed that cannot be live on Monday is
      listed with what replaces it and what the page shows instead ("not known" is shown once, with the reason).
- [ ] A3 NSE daily files for Fri 20 Nov downloaded and checked (F&O bhavcopy, OI, MWPL / ban list for Monday, FII/DII, sector
      indices). The Monday ban list is loaded the moment NSE publishes it.
- [ ] A4 The minute store is up to date through Fri 20 Nov (16 / 18 / 19 / 20 Nov included) so the studies and the replays can use
      them.
- [ ] A5 December option chains load for every F&O share (strikes, bid/ask, OI, IV), and the lot sizes are the current ones.
- [ ] A6 Global feeds for the 07:15 run: US closes, ADRs (INFY, WIT, HDB, IBN), GIFT Nifty, US 10-year, the dollar index, Brent,
      copper / LME, Asian markets.
- [ ] A7 News feeds live and de-duplicated (NEWS_READING_PLAN): wires, exchange filings, TV speech-to-text if enabled; junk ticker
      matches filtered (the "KEI-01 pickup" / "Ford vs Stellantis" class of error must not reach him).
- [ ] A8 Every paid subscription he gave is connected and tested with one real call each, and listed (name, what it feeds, tested
      at). Keys are never copied or printed; `.env` is read, never copied.

## B. The engine fixes (S builds, D reviews) - by Sat 22:00
From `v2_review/INDEPENDENT_REVIEW.md` and the 3-year study `onset_results/movestudy_report.txt`:
- [ ] B1 The triage rule "(1) sector must be CONFIRMED" is REMOVED as a gate. Sector state is a grade (FORMING / CONFIRMED / NONE)
      shown on the card, never a reason to stay silent. (Study: CONFIRMED as a gate misses ~40% of moves.)
- [ ] B2 CE equal to PE: day-high break, VWAP reclaim, long build-up, yesterday's-high break and the sector-up setups exist and fire
      as often as their PE mirrors. A test on an up day shows CE calls.
- [ ] B3 One ring per share per idea: no cancel within 10 min of a ring, no re-issue within 15 min, no new GO NOW just because the
      day's low or high moved; never ring a card that the limiter or the opening hold demotes.
- [ ] B4 The entry signs from the study: volume surge (RVOL >= 2, 5-min RVOL >= 3) and yesterday's high / low break; no GO NOW once
      half of the move is done (study: half done ~20 min after it starts) unless it is a pullback entry.
- [ ] B5 Real trade plans: December ATM or 1 ITM, one strike per idea, levels checked against the current price, reward/risk from
      real levels, premium shown or "no premium - not tradable", R:R below 1 or one lot above 1R = "0 lots" with the reason.
- [ ] B6 The GO NOW check runs on Opus 5.5, is given premium, IV, spread, OI at the strike and days to expiry, has written reject
      rules, and PROVES on known bad cards that it says WAIT / REJECT. Re-checks only when something important changes.
- [ ] B7 Triage ranks candidates so the limiter keeps the best; the AI's lane and the final lane are logged separately.
- [ ] B8 News matching by company and context, not ticker text; the second reading is split into "direction wrong" / "evidence
      weak" and used, or dropped.
- [ ] B9 Fault test: an AI timeout, a 429, a truncated answer, the budget cap, a stale quote, a dead feed - each degrades to a
      clear message, never a silent stop and never a wrong ring.

## C. The prediction loop (desk spec `design_v3/PREDICTION_LOOP.md`, R52+; S builds) - by Sun 16:00
- [ ] C1 EVENING PREDICTION: Sunday 19:45 run for Monday, updated 07:15 and 09:08: "will go UP" (CE) and "will go DOWN" (PE) lists,
      each with sector, both sides of every driver, trigger, cancel, confidence, and the market-day call. Every prediction stored
      with its time.
- [ ] C2 TRADING-DAY SIGNAL: "PREDICTED last evening: X up · sector up · NIFTY up · trigger crossed with volume". Says "too late"
      when half the move is gone and "prediction failed" when it moves the other way. Unpredicted big movers still show, marked
      "not predicted".
- [ ] C3 LIVE NEWS CALL within ~1 min: "NEWS: ... -> can go UP: A, B / can go DOWN: C", source, new or old, verified or TV-only,
      price confirm rule before any GO NOW.
- [ ] C4 BOTTOM / TOP CALLS: "BOTTOM CALL by ... - STOP: no new PE, protect / book your PE" and the mirror for CE, with the price
      test and the house's hit rate.
- [ ] C5 SCORING after 15:35: every prediction, signal, news call and bottom/top call scored (right side, how early, move left,
      wrong side) and shown as a short daily scorecard.

## D. Pages (S) - by Sun 14:00
- [ ] D1 The sector drill-down on F3, F2, F1 and Morning (approved spec SECTOR_DRILLDOWN.md section 8) with the cut-text fixes:
      at 1366, no cell, chip or head ends in "..." except prose with a tooltip ("GET RE...", "BANKBARODA...", "BREADTI" fixed); the
      flow box shows real numbers, not "not known".
- [ ] D2 The evening prediction and the "PREDICTED" signal have their place on the Morning page, the Desk and the phone.
- [ ] D3 Footer and health line show the real models (GO NOW on Opus 5.5) and the real AI cost so far today.
- [ ] D4 Every page of the 23 opens without a console error at 1366, 1600 and phone 390; every control on every page passes the R51
      test (scrollbar drag, track, wheel, keys, clicks, touch, Back) - a PASS/FAIL table, 0 FAIL.
- [ ] D5 Masked screenshots only (P&L hidden, labelled "P&L hidden", not magenta); no personal or trading data in the repo.

## E. Replays - the proof (S runs, D scores independently) - Sat after B, Sun after fixes
Cost is within the AI budget (about $0.5-1 a replayed day). Each run pushes calls, AI log, flags and scorecard.
- [ ] E1 Replay 16 Nov, 18 Nov (down days), 20 Nov (today) and one October up day, from the evening before (the 19:45 prediction
      included).
- [ ] E2 PASS MARK on every replayed day:
      - cards before the move (cards he sees, not WATCH rows): at least 10 a day;
      - CE calls on the up day, PE calls on the down days;
      - 50 rings a day or fewer, 6 in any 15 minutes or fewer;
      - the GO NOW check rejects at least some cards;
      - the evening prediction lists contain a fair share of the day's real big movers on the right side (D sets the number from
        the pre-open study);
      - no ring on a wrong-side news match.
- [ ] E3 Side by side with the old system on the same days (the old system caught 22 and 35 before on 16 and 18 Nov). The new
      system must not be worse. If it is, D says so plainly to the trader on Sunday evening.

## F. Monitoring and control (S) - by Sun 18:00
- [ ] F1 Control Room / health line: every feed, every job, the AI cost, rings so far, errors - in one place, with one alarm on the
      phone if something stops.
- [ ] F2 The fallback switch `gir mode old` / `gir mode new` tested both ways on Sunday (a ring test on the phone each way).
- [ ] F3 gir-watchdog and paper_exit_monitor are NOT touched. TG_CHAT_FO and TG_CHAT_OI are never used.
- [ ] F4 A ring test to his phone on Sunday evening: one CRITICAL, one GO NOW, one news call; he confirms they arrive.
- [ ] F5 Logs rotate; disk and memory are fine for the day; a restart brings everything back without losing the day's state.

## G. Studies feeding Monday (D builds, S runs) - Sat
- [ ] G1 `preopenstudy.py` (market day -> sectors -> shares, how early the right share and side can be named) run on the 3-year
      store; the report pushed; D turns it into the prediction's numbers.
- [ ] G2 Score this week's evening watches (SECTOR_MAP_20NOV, WATCH_20NOV_update, WATCH_20NOV_us_night) against the real moves of
      20 Nov.

## I. External data - news, TV, filings, world, sectors (S) - by Sun 18:00, each with a MEASURED delay
The trader, 20 Nov: "What about the external data, the world news and the live TV monitoring, the sector data - all will be ready,
correct? Reading NSE filings." Status in BUILD_PLAN 1.2 was "partly" for all of these. Each item's proof = a table of 5 real items
from Fri 20 Nov or the weekend: published at (source time) -> seen by GIR -> on the page / phone, in seconds.
- [ ] I1 NSE + BSE filings (F15): polled every 3-5 s (was ~3 min late); attachments (PDF / XBRL) read for important filings;
      target on screen <= 15 s. Includes results, board outcomes, orders won, pledges, SAST / insider, block / bulk deals, and
      exchange circulars (F&O ban, lot changes, surveillance).
- [ ] I2 Live TV speech-to-text (F17): CNBC-TV18 and ET Now at minimum (was one channel); Sansad TV, RBI / SEBI / PIB briefings when
      live. A company or sector named on TV appears as a news line within ~60 s, marked "TV only - unverified" until a second source.
- [ ] I3 News wires and publishers (F16): dead feeds removed (old Reuters RSS, Nitter); ET, Moneycontrol, CNBC-TV18, Business
      Standard, NDTV Profit, Reuters sitemaps and today's live blogs; target <= 30 s; duplicates merged; junk ticker matches blocked.
- [ ] I4 World news and cues (F23 + EXTERNAL_SOURCES_MISSING top items): real GIFT Nifty (not ^NSEI), real LME / COMEX copper and
      aluminium (not the wrong proxies), US futures, US 10-year, dollar index, Brent, Asia; a free global headline squawk
      (FinancialJuice free tier) and Trump posts RSS; any PAID upgrade only with his yes.
- [ ] I5 Regulators / Parliament / PIB (F20): within 1 minute (was ~15 min): SEBI, RBI, IRDAI, TRAI, CCI, DGCA, PIB, sansad.in.
- [ ] I6 Sector data (F03): every listed share of every mapped sector live (R49), sector %, breadth both ways, weights; checked
      against the official NSE sector indices at 3 times on Friday (difference explained).
- [ ] I7 Economic and results calendar (F22): built (was a hand-edited file): Monday's events with times and consensus; results and
      board meetings of F&O shares for the week.
- [ ] I8 Each source shows on the Health page with its last item time; a source silent too long raises one alarm, and the page says
      which source is down instead of showing nothing.

## J. Go-live traps (found by the go-live review, 20 Nov) - these override any time above that disagrees
- [ ] J1 Kite login, one owner, one time: T logs in all four keys by Mon 08:15; S checks each key (one profile + one quote call) by
      08:20; a missing key moves its lists to K4 and rings his phone. No 07:15 job may depend on a Monday token (use Friday closes /
      non-Kite sources for the 07:15 run). (S + T, Mon 08:20)
- [ ] J2 USE TODAY'S LIVE SESSION (Fri 20 Nov, the last one before Monday): run the v2 feed + engine read-only as its own service
      (no rings), record raw frames at least 09:00-09:30 and through the day; push tick rates per connection, FULL-mode proof,
      reconnects and the rings it WOULD have sent. (S, start by 12:00, push by 16:00 today)
- [ ] J3 Tue 24 Nov is an NSE holiday: ONE trading calendar for every job. `systemctl list-timers` shows Sun 19:45 (prediction for
      Mon), Mon 07:15 / 08:00 / 08:45 / 09:08 / 15:35, and NO trading-day jobs on Tue 24; Monday 19:45 predicts for Wed 25. (S, Sat 22:00)
- [ ] J4 After the weekend "yesterday" = Fri 20: run the 08:00 and 08:45 jobs with the clock faked to Mon 23 08:00 and push the output:
      no Friday file marked RED, ban file accepted, previous-day high / low / gap / OI change / RVOL baselines from Fri 20,
      Monday ex-dates handled (no false gap-down PE). (S, Sat 22:00)
- [ ] J5 Monday's share list from Monday's 08:00 instrument file: compare with Friday's (counts, December lot changes, shares leaving
      F&O dropped); plan-card lots = the file's December lot; days to expiry from the contract file. (S, dry run Sat 22:00, live Mon 08:15)
- [ ] J6 Silence EVERY old sender: old morning / evening note timers (gir-overnight, gir-ready, 19:40 / 19:45 notes), old page
      sounds at "/", plus a list of what gir-watchdog and paper_exit_monitor send (they stay untouched). One 07:15 note, one 19:45
      note, never two. (S, Sun 18:00)
- [ ] J7 The fallback switch is safe and his: flipping it never dumps held-back alerts; he can flip it himself (Telegram command or a
      Settings button); written reasons to flip (no card 15 min after 09:15, more than 6 rings in 15 min, a wrong-side ring).
      (S builds, D writes reasons, T approves, Sun 18:00)
- [ ] J8 Replays can never reach his phone or the live day: no Telegram credentials, no sound, separate calls store / limiter /
      counters / scorecard; proof = a replay run with an empty sent-messages log. (S, Sat 22:00)
- [ ] J9 09:00-09:30 rules: the 09:15 print carries the pre-open volume (RVOL5 would fire everywhere) - exclude it from RVOL5,
      high/low, VWAP seeding; decide which evening GET READY triggers may ring at 09:15 (at most 6, ranked, not first-come);
      test on today's recorded 09:00-09:30 frames. (D writes the rule, S builds, Sat 22:00)
- [ ] J10 EXPIRY-DAY MODE for Monday: stock options expire (December strikes only); index expiry choice for index options is the
      TRADER'S decision; build-up read from OI across all months (rollover makes near-month OI collapse); pinning to big-OI strikes
      from ~13:30 flagged; add the last expiry day (27 Oct) to the E1 replays. (D spec, T decides index expiry, S builds, Sat 22:00)
- [ ] J11 AI budget: the silent old system gets a small fixed allowance or no AI; replays have their own counter; the day resets on
      the India date; proof that the old system cannot use up the new one's budget (the Opus GO NOW must not be switched off at 60%).
      (S, Sun 18:00)
- [ ] J12 Clock and time zone: clock offset < 100 ms (NTP); every v2 timer and day boundary on Asia/Kolkata. (S, Sun 18:00)
- [ ] J13 Restart proof: kill the engine and the page stream mid-replay at 09:16 and 11:00 - no repeated rings; limiter, AI spend
      and loss lock carry on; page reconnects; no crash-loop flood. Sunday-night restart starts Monday's counters clean. Plus an
      OUTSIDE uptime check on /status.json and last-tick age, tested Sunday by stopping the heartbeat. (S, Sun 18:00)
- [ ] J14 Rate limits at cold start: a request budget per key (Kite, NSE, Telegram); proof = peak requests/s from a cold start at
      08:30 with zero 429 / 403. (S, Sun 18:00)
- [ ] J15 His Monday routine (T): logins by 08:15; at 08:25 open the page on laptop and phone, click once (browsers block sound until
      a click), hear the test chime, receive the Telegram test ping; phone not on Do Not Disturb, channel not muted, battery saver
      not stopping Telegram. He writes "switch on" for the new system by Sun 21:00 (the new system rings on the live address).
- [ ] J16 Code freeze Sun 16:00. D picks one held-out replay day only after the freeze. After GO at 21:00 nothing changes before
      Mon 15:35 except through the fallback switch.

## H. The Monday timeline
- Sun 19:45  the evening prediction for Monday goes out (C1). D reviews it at once.
- Sun 21:00  GO / NO-GO: D gives the trader a one-page status of every item above (DONE with proof / NOT DONE / risk). He decides.
- Mon 07:15  global run; the prediction is updated; Kite token refreshed (A1).
- Mon 08:00  every feed fresh (A2); ban list loaded (A3); health all green (F1).
- Mon 08:30  READY: S posts "READY" with the health line. Any red item is named with its fallback.
- Mon 09:08  pre-open update of the prediction lists.
- Mon 09:15  live. The old system logs silently beside it.
- Mon 15:35  the day is scored (C5, E3) and the trader gets the scorecard.
