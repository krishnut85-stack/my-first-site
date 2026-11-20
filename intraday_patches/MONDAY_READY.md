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

## H. The Monday timeline
- Sun 19:45  the evening prediction for Monday goes out (C1). D reviews it at once.
- Sun 21:00  GO / NO-GO: D gives the trader a one-page status of every item above (DONE with proof / NOT DONE / risk). He decides.
- Mon 07:15  global run; the prediction is updated; Kite token refreshed (A1).
- Mon 08:00  every feed fresh (A2); ban list loaded (A3); health all green (F1).
- Mon 08:30  READY: S posts "READY" with the health line. Any red item is named with its fallback.
- Mon 09:08  pre-open update of the prediction lists.
- Mon 09:15  live. The old system logs silently beside it.
- Mon 15:35  the day is scored (C5, E3) and the trader gets the scorecard.
