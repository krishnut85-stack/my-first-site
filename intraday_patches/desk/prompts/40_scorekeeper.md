# SEAT 40 - SCOREKEEPER (Reasoning bench - LOGGING LIVE ON MONDAY, WEIGHTS FROM WEEK 1; CODE ONLY - this file = the rules and card text)

## 1. ROLE
This seat is the desk's scorekeeper, written as code: the head of desk who, every day at 15:45, puts every card and every idea next
to what the price really did - was it right, how early, how much move was left, was it the wrong side - and keeps the record BY
SOURCE: each seat, bench, publisher, TV voice, broker, filing type, link, story and the trader's own reads. This is the learning
capability of the desk: weak voices lose weight, strong ones gain it, and nothing is called PROVEN until the numbers say so. The desk
is judged on PRECISION and EARLINESS of its picks by source, not on how many movers it covered (PREDICTION_LOOP 00).
It must NEVER: place or suggest an order; score from anything but the minute store and NSE closes; let a cause found after a move
score that move; change a weight before the sample rules allow; speak to the trader (the HEAD sends the scorecard).

## 2. WATCHES
- Every card and decision on the DESK BOARD of the budget day (seat, kind, shares, side, horizon, time named, price at naming from the
  snapshot, evidence ids with source and grade, link ids, story id) and every head idea, BUY NOW, WAIT, CANCEL and manage note.
- The minute store and NSE bhavcopy (data cut 15:35): each named share and sector from the naming time to 15:10, the close, the next
  close; the day's F&O universe and its 2% movers each side; trader_reads.json.
- Cadence: 15:45 daily (Batch API for the Sonnet sentences of the day review); next-day close and day-5 updates on later days.

## 3. KNOWLEDGE (the rules code applies)
From DESK_TEAM 4.6 / 2.3 rule 5 / 2.4, PREDICTION_LOOP 00 and E1-E7, A6b point 5, SECTOR_LINKS C3, LINK_BOOK E step 7, CHAIN_OF_EVENTS B5.
- **S1 Labels (E1 EDGE / E2):** RIGHT = +2% its way before -1% against (by 15:10 and by the next close); BIG RIGHT = 2%+ its way from the
  open by 15:10; RIGHT-TRADABLE = trigger filled, then +1% before -0.6% within 60 min; RIGHT-NOT-TRADABLE = the gap took it or no fill;
  FLAT; WRONG SIDE = cancel first or 1% against; NOT TRIGGERED.
- **S2 Earliness and move left:** ring / naming minute vs the move's onset (BEFORE / EARLY / LATE); % of the day's move still ahead.
- **S3 Baselines (E3, CE and PE apart):** the day's same-side base rate; a random same-sector share; yesterday's movers continue;
  highest-beta shares on the day's side; the code's own top-ranked names. LIFT = ours / baseline. Nothing is "working" without lift.
- **S4 Hindsight (A6b-5):** a chain, news or reason first seen after the move never scores that move; it is logged as EXPLAINED-LATE.
- **S5 MISS (E2, LINK_BOOK E7, CHAIN B5):** every 2%+ F&O mover (headline 3%+) not named before its onset is a MISS row, searched for a
  link or story that could have fired; a link that existed but did not fire gets its threshold reviewed.
- **S6 Weights (DESK_TEAM 4.6, E4):** shrunk hit rate (hits + 10 x base) / (n + 10), prior = the day's base rate; a seat's weight moves only
  after 20+ scored cards; a source / link weight only at n 30+, and only halfway each time; at or under base after 30 = weight 0. Frozen
  into the 07:00 digest (the cache is not broken in the day).
- **S7 Labels to the trader (E7):** every side stays "NOT PROVEN (day n of 20)" until its hit rate is 8+ points above baselines (a) and
  (d) over 20 trading days; it falls back to NOT PROVEN when a rolling 20 days goes below baseline.
- **S8 Keep / drop (E13):** after 100 scored ideas a seat with lift at or under 1.0 goes on probation (event-only, prompt reworked); a seat
  must earn at least 3x its cost. New benches count only as support for their first 5 live days (DESK_TEAM 1a).
- **S9 Balance (E5):** flag SIDE BIAS when over 5 days a side's share of predictions differs by 20+ points from the market's own 2% moves.

## 4. HOW IT DECIDES (code, 15:45)
1. Freeze the board at 15:35; drop nothing (cancelled ideas are scored too - was the cancel right?).
2. Label every card idea (S1) on its horizon; attach earliness and move left (S2) and the baselines (S3).
3. Apply S4 to every reason; build the MISS list (S5) and search each miss for a link, story or source that was on the board.
4. Roll up by seat, bench, source, link, story, trader read; update shrunk rates and, where S6 allows, weights.
5. Write the scorecard card and the per-seat rows; Sonnet (Batch) writes only the plain-words sentences from these numbers.

## 5. OUTPUT
Kinds: FACT (the day's scorecard), FACT per seat (`scope: "seat"`). JSON written by code; text sentences fill placeholders only.
```json
{"seat": "40_scorekeeper", "kind": "FACT", "scope": "day",
 "headline": "Banks CE theme right and early; the desk's evening IT put wrong; metals put right; hospitals were a miss with a broker cause",
 "strength": 3,
 "claims": [
  {"text": "Ideas right {num:sc.right} of {num:sc.n}; CE beat the day by {num:sc.ce_lift_pts}, PE by {num:sc.pe_lift_pts}", "type": "FACT", "evidence_ids": ["score:<date>"]},
  {"text": "Misses of three percent or more: {num:sc.miss3}, biggest {num:sc.miss_top}", "type": "FACT", "evidence_ids": ["score:<date>"]},
  {"text": "Scored day {num:sc.day_n} of the twenty-day window; nothing is PROVEN before day twenty", "type": "FACT", "evidence_ids": ["score:<date>"]}],
 "by_source": [{"source": "10_flows", "n": "{num:sc.flows.n}", "right": "{num:sc.flows.right}", "lift": "{num:sc.flows.lift}", "label": "NOT PROVEN"}],
 "misses": [{"symbol": "APOLLOHOSP", "side": "CE", "cause_found": "broker upgrade on TV and wires", "on_board_before": false}],
 "ideas": [], "winners": [], "losers": [],
 "evidence": [{"id": "score:<date>", "source": "GIR minute store + NSE bhavcopy", "first_seen": "<copied>", "grade": "OFFICIAL"}],
 "new_since_last": "-", "proof": "NOT PROVEN", "expires": "NEXT_OPEN", "linked_card_ids": [], "links": []}
```
`proof` is only NOT PROVEN / PROVEN (CONTRACTS); the day count of the twenty-day window goes in a claim, never in `proof`.
**One-line card texts (code fills the placeholders):**
- "TODAY: right {num:r} of {num:n} · CE {num:ce_r}/{num:ce_n} (base {num:ce_base}) · PE {num:pe_r}/{num:pe_n} (base {num:pe_base}) · early {num:early}."
- "BEST SOURCE: {source} {num:r}/{num:n} · WORST: {source} {num:r}/{num:n} · MISSED 3%+ {num:k} (biggest {SYMBOL} {num:pct}, {cause})."
- "20-DAY: right {num:pct} vs base {num:base} · NOT PROVEN until day 20." · Seat row: "{seat} · cards {num:n} · reached the head {num:h} ·
  right {num:r} · lift {num:l} · $ {num:cost} · {too early | weight moved | probation}."

## 6. EXAMPLE (Fri 20 Nov 2026 15:45, from DESK_TEAM 2.5, SECTOR_MAP_20NOV, monday/OUTSIDE_WATCH_2026-11-20.md, TRADER_CALLS_scored)
- **Banks CE theme (FLOWS + CONNECTIONS, named 19 Nov evening):** BANKNIFTY record close 64,635, +2.49%; Pvt Bank +3.01% -> RIGHT, named
  before the move. **IT PE (the desk's 19 Nov call):** WRONG SIDE - IT led early. **Metals PE:** RIGHT (worst sector, -1.8% to -2.5%).
- **Gold lenders PE watch** (SECTOR_MAP 19 Nov evening, odds 25/30/45): KALYANKJIL -5.89% at 11:05, MUTHOOT and MANAPPURAM down -> right side;
  the watch counts only for the names and side it actually listed.
- **MISS:** APOLLOHOSP +6% to a record on a Macquarie upgrade (TV / wires from 09:11) - not on the evening list; logged with its cause
  for the broker seat (18). **EXPLAINED-LATE:** Geojit's flow line (11:02) and the NSDL financials fact (13:55) support the theme but
  score nothing as predictions (S4).
- **Trader reads:** DIXON group CE 5 of 5 up; defence CE 5 of 8 up but under NIFTY - both scored into his record.
- **Memory:** EVENT_MEMORY G gets episode 1; every label stays NOT PROVEN (day 1 of 20 once live).

## 7. RED LINES
- Precision and earliness by source - never "how many movers we covered"; never pad the list to look busy.
- A reason seen after the move never scores it; cancelled ideas are scored too.
- No weight moves before 20 scored cards per seat (30 per source / link), and only halfway.
- Always print the baselines and n beside a hit rate; no lift = not working.
- Score only from the minute store and NSE closes; never from a seat's own claim.
