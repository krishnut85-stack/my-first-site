# SUMMITS AND MEETINGS - a standing source for the desk (20 Nov 2026)

The trader, 20 Nov 20:18: "All these summits and meetings are very critical to study the market news and trend."
Until now a summit reached the desk only if a wire or TV line happened to carry it (the CII Financing Summit read on 20 Nov was done
by hand). From now on summits and meetings are a STANDING SOURCE: put on a calendar before the day, read live on the day, logged
after it, and scored like every other source.
The calendar of dates is in SUMMIT_CALENDAR.md (researched with sources; refreshed every Sunday).

## 1. What counts (the summit families)
| family | examples | why it matters |
|---|---|---|
| Regulators and government on a stage | RBI governor, SEBI chief, IRDAI, PFRDA, Finance / Commerce / Defence / Power ministers, CEA, NITI | official intent comes out at summits weeks before the circular (SEBI FPI paper "very soon", CII 20 Nov) |
| Fixed official meetings | RBI MPC, SEBI board, GST Council, Cabinet, Parliament sessions, pre-Budget meetings | decisions with a date - the strongest kind |
| Indian chambers and media summits | CII, FICCI, ASSOCHAM, PHDCCI, HT Leadership, Times Network ET Conclave, CNBC-TV18 / ET events | where ministers and CEOs speak on the record |
| Sector bodies | NASSCOM, SIAM / FADA, IBA, COAI, ISMA, CREDAI, defence expos, RE-Invest, SEMICON India | demand and policy for one sector |
| Broker investor conferences | Motilal Oswal, Kotak, CLSA India Forum, JM, Jefferies, Nomura, Morgan Stanley, Goldman, UBS, BofA, Nuvama | managements talk to big funds; "comfortable with guidance" / "demand softening" lines leak the same day |
| Company days | capital-market / analyst days, AGMs, EGMs | guidance, capex, demergers |
| Global | FOMC, ECB, BoJ, OPEC+, China work conference, AI / chip events (AWS re:Invent, chip results days), G20, COP, trade talks | sets the world tone; AI capex moves Indian IT and banks (20 Nov Bank Nifty) |

## 2. Before the day (the calendar - seat 34, code)
- Every summit goes on the event clock with: time (IST), who speaks, the topics, and the PRE-WRITTEN SCENARIOS both ways
  ("if the SEBI chief gives a date for the FPI paper -> CE CDSL / BSE / CAMS; if he talks of curbing F&O -> PE BSE / ANGELONE").
- Connections (35) writes the scenarios at the 19:45 conference the evening before; History (37) adds what the same speaker or the same
  event did last time.
- A fixed-time official decision (MPC, GST Council, SEBI board) gets the K4 no-entry window. A speech does not.

## 3. On the day (live reading)
- Sources in order of speed: the event's own live stream (YouTube / PIB / RBI / SEBI webcasts) through the server's speech-to-text
  (same pipe as the TV recorder), then CNBC-TV18 / ET Now live, then wires and live blogs, then PIB / press releases.
- The readers tag each line: SPEAKER, OFFICIAL DECISION / OFFICIAL INTENT WITH A DATE / OFFICIAL INTENT, NO DATE / OPINION / WISH-LIST,
  NEW or REPEAT (said before?), and the shares and side.
- The policy bench (R4, seats 11-14) owns official speakers; the company bench and sector seats own CEOs; Voices (R3, 28) owns TV
  coverage of the event.
- Weight rule (same as all news): an OFFICIAL DECISION + price agreement can become an ALERT; OFFICIAL INTENT WITH A DATE goes on the
  POLICY CLOCK and enters as WATCH; OPINION and WISH-LIST stay FACT cards ("Anand Rathi wants STT removed" never becomes a trade).
  A lone speech never rings BUY NOW without the price confirming (the head rules stand).

## 4. After the day (memory)
- Each summit gets an EVENT_MEMORY entry like section H (CII, 20 Nov): speaker -> what was said -> official or opinion -> F&O read ->
  the follow-up date to check (paper due, meeting date, budget).
- Every follow-up is tracked until it comes true, changes or fades. The head analyst sees the open items in the snapshot.

## 5. Scoring (does a summit line move shares?)
- Every summit line that named a share or sector is scored like any source: the named shares' move at 15:10 the same day, next close,
  5 days and 20 days, against the sector and against random F&O shares of the same day.
- The score is kept by SPEAKER TYPE (regulator / minister / CEA / CEO / broker / chamber) and by LINE TYPE (decision / dated intent /
  undated intent / opinion). After a few weeks the desk knows, from his own data, which summit lines are worth acting on.
- Backfill: SUMMIT_CALENDAR.md part B lists past summit statements (2025-26) with dates. The server prices each from its 3-year
  daily / minute store, so the scorecard starts with a history instead of from zero.

## 6. What the server builds (small, in this order; after Monday's must-haves)
1. A `summits` table (date, time IST, event, family, speakers, topics, stream URL, scenarios) loaded from SUMMIT_CALENDAR.md and
   refreshed every Sunday; seat 34 reads it into the clock.
2. The STT recorder accepts a stream URL per event (YouTube / webcast) for the listed time window, with the same speech-to-text and
   reader path as TV. Hosts that block cloud machines are read by the server only (WEB_SOURCES section 5).
3. Reader tags SPEAKER and the line types above (fields already in CONTRACTS: novelty, source grade; the speaker goes in evidence).
4. The scorecard groups summit cards by speaker type and line type.
5. The backfill pricing of part B (one-off, after 15:35; code only, no AI cost).
No new page: summits show on the existing Calendar list and in the 19:45 brief; a summit line that matters reaches him through the
normal head analyst card.
