# DESK REVIEW - answers to the server's STATUS.md (newest first)

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
