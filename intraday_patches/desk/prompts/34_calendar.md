# SEAT 34 - CALENDAR AND EVENT CLOCK (Market-internal bench - LIVE ON MONDAY; CODE ONLY - no model call. This file = the rules and card text)

## 1. ROLE
This seat is the desk's event clock, written as code: the senior dealer who opens the day by reading the calendar aloud - "expiry
today, no new entries after 14:00", "RBI at 10:00, do not buy options into the release", "TCS reports tonight, IT links are off for
two sessions", "Europe opens at 13:30" - and who keeps every other seat from walking into a known date. It writes NO-ENTRY WINDOWS,
CATALYSTS (with what each date can move, both sides) and the SERIES rule for the day. It decides nothing about direction.
It must NEVER: place or suggest an order; invent a date or time (every entry comes from the J3 exchange calendar, the economic
calendar feed F22, the results calendar or the policy clock); speak to the trader (only the HEAD does); call a scheduled event a signal.

## 2. WATCHES
- J3 exchange calendar (trading days, holidays, Muhurat), the F&O contract master (expiry dates per series, lot sizes), MWPL / ban list.
- Economic calendar F22 / I7: India (CPI about the 12th, IIP, GDP, auto sales on the 1st, GST council, RBI MPC), US (Fed, CPI, jobs, EIA
  on Wednesday about 21:00 IST), China (LPR about 07:00 IST, data), Europe (ECB, BoE; open 13:30 IST), Japan (BoJ).
- Results calendar for F&O companies and their global peers (Accenture, Cognizant, US banks, chip makers); board meetings; AGMs.
- POLICY CLOCK items with a known date (PENDING / CONFIRMED / NOTIFIED); index rebalances (NSE, MSCI Feb / May / Aug / Nov, FTSE).
- Cadence: 19:45 (tomorrow) and 07:15 (today); a live card only when a window opens or closes, or a date changes.

## 3. KNOWLEDGE (the rules code applies)
From monday/J10, LINK_BOOK row 66 and traps C4 / C8 / C11 / C12, SECTOR_LINKS B (calendar triggers), PREDICTION_LOOP B2 / B4, DESK_TEAM
2.4 / 4.7. Thresholds marked [G] are to be tuned.
- **K1 SERIES:** stock options use the NEXT month from E-4 and on expiry day (Mon 23 Nov -> DECEMBER, expiry 29 Dec); index options use
  the NEXT expiry on their own expiry day (NIFTY: the 1 Dec weekly; BANKNIFTY: 29 Dec); the expiring contract is "information only".
- **K2 EXPIRY DAY:** no new entry after 14:00; from 13:30 a price near the expiring series' biggest-OI strike = PINNING warning; weekly
  expiry distorts the index-heavy banks.
- **K3 RESULTS:** no link trade in the 2 sessions around the company's own results (C8: guidance overrides the link; IV crush after).
  A leader's results move its peers next open (LINK_BOOK row 60: TCS / INFY -> IT; HDFCBANK / ICICIBANK -> private banks).
- **K4 POLICY RELEASES:** RBI / SEBI / GST / budget at a fixed time -> no new option entry from 15 minutes before to 15 minutes after the
  release [G] (policy-day IV crush after the 10:00 release, C12); an EXPECTED decision is "sell the news" (C4).
- **K5 SESSION CLOCK (DESK_TEAM 2.4, PREDICTION_LOOP B2 / B4):** 09:15-09:20 nothing confirms; 09:45 the measured CE window; 11:00 the ring
  window ends (late rows after); 13:30 Europe; 14:30 manage only; 15:10 exit; 15:00-15:10 not flat = P1 alarm (code risk).
- **K6 HOLIDAYS / WORLD-WHILE-SHUT (C11):** a world move during an Indian holiday is traded only as the gap at the next open, not after
  10:00. China Golden Week shows 0% = closed, not flat.
- **K7 BUDGET DAY:** the AI budget day runs 15:40 to 15:40 of the next session; a weekend or holiday joins the next session's day.
- **K8 CATALYST MAP:** each date carries its LINK_BOOK rows both sides (1st auto sales: row 61; CPI: row 62; ATF on the 1st: row 63;
  index inclusion: row 65; Fed: row 32) so Connections can pre-write scenarios.

## 4. HOW IT DECIDES (code)
1. Build today's clock from J3 + contract master: trading day? expiry for which series? holiday tomorrow?
2. Apply K1-K2 -> the SERIES line and expiry windows. Apply K3 -> list of shares with results inside 2 sessions (link trades off).
3. Apply K4 -> today's release windows. Apply K5 -> the fixed session checkpoints. Apply K6 if a holiday sits next to today.
4. Attach K8 rows to each catalyst so seats see both sides; mark EXPECTED vs SURPRISE-possible from the policy clock.
5. Write one CALENDAR card at 19:45 (tomorrow) and 07:15 (today); live cards only when a window opens / closes or a date moves.

## 5. OUTPUT
Kinds: FACT (the day's clock and catalysts), ALERT (a window opens now, a date moved), QUIET. JSON written by code (DESK_TEAM 4.4).
```json
{"seat": "34_calendar", "kind": "FACT",
 "headline": "Expiry day for November stock and index options; December series only; no new entries after the afternoon cut-off",
 "strength": 3,
 "claims": [
  {"text": "Stock options use the December series; the November contract is information only", "type": "FACT", "evidence_ids": ["cal:contract_master:<date>"]},
  {"text": "No new entry after {num:cal.expiry.no_entry_after}; pinning warning from {num:cal.expiry.pin_from}", "type": "FACT", "evidence_ids": ["cal:j10"]},
  {"text": "The next session is a holiday, so the day after expiry has no trading", "type": "FACT", "evidence_ids": ["cal:j3:<date>"]}],
 "windows": [{"from": "{num:cal.expiry.no_entry_after}", "to": "15:10", "rule": "K2_NO_NEW_ENTRY"}, {"from": "{num:cal.expiry.pin_from}", "to": "15:30", "rule": "K2_PINNING"}],
 "catalysts": [{"when": "{num:cal.next.date}", "what": "<event>", "links": ["LB-A32"], "expected": true, "both_sides": "see LINK_BOOK row"}],
 "results_inside_two_sessions": ["<SYMBOL>"],
 "ideas": [], "winners": [], "losers": [],
 "evidence": [{"id": "cal:j3:<date>", "source": "NSE holiday list (J3)", "first_seen": "<copied>", "grade": "OFFICIAL"}],
 "new_since_last": "-", "proof": "NOT PROVEN", "expires": "15:10", "linked_card_ids": [], "links": ["LB-A66"]}
```
`proof` is only NOT PROVEN / PROVEN (CONTRACTS): an exchange calendar is OFFICIAL as an evidence `grade`, never as a `proof` value.
**One-line card texts (code fills the placeholders):**
- "SERIES: stock options {month} only; index {NIFTY next weekly | BANKNIFTY next monthly}; expiring contract = information only."
- "EXPIRY: no new entry after {num:cal.expiry.no_entry_after}; pinning watch from {num:cal.expiry.pin_from} near the biggest-OI strike."
- "RESULTS: {SYMBOL} reports {when} - link trades off for two sessions; IV high before, crush after."
- "RELEASE: {event} at {num:cal.release.time} - no new option entry {num:cal.release.gap_min} min either side; expected = sell the news."
- "CLOCK: {num:cal.checkpoint.time} {checkpoint}" (09:20 first confirm · 09:45 CE window · 11:00 ring window ends · 13:30 Europe · 14:30 manage only · 15:10 exit).

## 6. EXAMPLE (the real calendar around 20-23 Nov 2026, from monday/J10, CHAIN_OF_EVENTS A, SECTOR_MAP_20NOV, DESK_TEAM 4.7)
- **Fri 20 Nov 19:45 card (for Mon 23 Nov):** Monday is the November monthly expiry; Tue 24 Nov is an NSE holiday, so Monday's positions
  face no next day. SERIES: stock options DECEMBER only (29 Dec); NIFTY options the 1 Dec weekly; BANKNIFTY 29 Dec. No new entry after
  14:00; pinning watch from 13:30. December quotes may lag in the first 15 minutes (yesterday's until about 09:30 on 20 Nov) - expect
  "premium loading".
- **Budget day:** Fri 15:40 -> Mon 15:40 is ONE $5 AI day, including the Sunday 19:45 brief (K7).
- **Catalysts carried from the 19 Nov evening:** China LPR at 07:00 IST (a hold expected; a cut = metals CE, LINK_BOOK row 10); hawkish
  Fed minutes, a December hike about 95% priced in = EXPECTED, little edge (C4).
- **Thu 19 Nov (CHAIN_OF_EVENTS A):** three sessions before the expiry, rule E7 already chose December for the auto CE watch.

## 7. RED LINES
- A date is a window or a catalyst, never a direction signal; an EXPECTED event is "sell the news".
- December only for stock options from E-4; next expiry for index options on their expiry day.
- No new entry after 14:00 on expiry day; no link trade within 2 sessions of the company's results.
- Never invent a date or time; a missing calendar entry is shown as "not seeing <calendar>".
- A world move during an Indian holiday is the next open's gap only.
