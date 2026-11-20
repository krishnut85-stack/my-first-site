# LEAN COMBINED CALLS - how the Monday 23 Nov shared seat calls are assembled (20 Nov 2026)

Binding sources: DESK_TEAM.md 2.2 ("in LEAN, several seats share one call"), 4.1 (one call covers the seat's or bench's whole area),
4.2 (one shared Sonnet prefix), 4.7 (buckets and ladder), 4.8a (LEAN-MON cost rows); CONTRACTS.md sections 1 and 7. This file is for
the server build (`gir-desk` call builder) and for anyone reading a combined card on the board. It adds no seat rules: each seat's
own prompt file stays the only source of that seat's rules.

## 1. The five combined calls on Monday

| Call (`call` value) | Seat prompts concatenated, in this order | Model / effort | Runs | Bucket | 4.8a row |
|---|---|---|---|---|---|
| `GLOBAL` | 1_us_ai_tech, 2_us_policy_rates, 3_china_north_asia, 4_europe_geopolitics, 6_energy, 7_base_metals | Sonnet 5.5, low; medium when a woken world event is the reason for the call | 19:45, 07:15, and at most one woken call (22:45 night check if code wakes it, or a world shock past a 4.3 threshold) | SEATS | "Global macro + FLOWS + EM rotation" - 5 calls, $0.10 |
| `FLOWS` | 10_flows (lead), 5_em_rotation, 9_rupee_rates | Sonnet 5.5, low; medium when the five-day sum crosses the threshold either way | once after the NSE FII / DII file lands (for 19:45; code polls 17:30-21:00, the call fires once), 07:15, and on an NSDL release | SEATS | same row as GLOBAL |
| `FINANCIALS` | 19_banks, 20_nbfc_insurance_capmkts | Sonnet 5.5, low; medium on an event | 19:45, 07:15, and on an event that wakes 19 or 20 | SEATS | "Sector seats x3" - 12 calls, $0.22 |
| `INDUSTRIALS-METALS-ENERGY-INFRA` | 24_metals_mining, 25_oil_gas_power, 26_capgoods_infra_defence | as above | 19:45, 07:15, and on an event that wakes 24, 25 or 26 | SEATS | same row |
| `CONSUMER-IT-PHARMA-AUTO` | 21_it_ems, 22_pharma_healthcare, 23_auto, 27_consumer | as above | 19:45, 07:15, and on an event that wakes 21, 22, 23 or 27 | SEATS | same row |

- **Counting against 4.8a.** DESK_TEAM 4.8a writes the GLOBAL / FLOWS / EM row as "one call"; the build runs it as two calls (GLOBAL and
  FLOWS) that share that row's money and its 5 calls a day: FLOWS 2 (evening, 07:15) + GLOBAL 2 (19:45, 07:15) + 1 woken GLOBAL call.
  A further woken GLOBAL call may run while SEATS money lasts (the count is soft, the money cap is hard). The sector row is 3 calls
  x 2 meetings = 6, plus up to 6 event calls. All call counts are [E] until F29 measures them.
- **Not in any Monday call:** seat 8 (weeks 2-3; its gold line rides as a driver in seat 2's card and in seat 20's gold-lender row, and
  no 8_precious_agri card is written), seat 3's 15-minute 05:30-09:15 runs (Monday has only the meetings), seats 11-14, 16-18, 31 and 37
  (week 1 or later). Seats with their own Monday calls stay separate: 15, 28, 29, 32-36, 38-40, H and the readers.
- **Wake rules (DESK_TEAM 4.3):** an event that would wake one seat (R49 sector move 1% in 15 min, an F27 basket shock, a weight-4 fact
  on a name in its sector, a world mover past threshold) runs that seat's whole combined call. The other seats in it answer too, usually
  QUIET. The 10-minute minimum gap per sector seat applies to the combined call.

## 2. How the server builds one combined prompt
Order inside the request (DESK_TEAM 4.2 caching):
1. **Shared Sonnet prefix** (identical for every Sonnet seat call): frozen desk instructions, CONTRACTS.md sections 0, 1, 4, 5, 6, 7 ->
   cache breakpoint, 1-hour TTL.
2. **Combined-call block** (stable per call, so it caches too): the header below, then each seat prompt file IN FULL, unedited, in the
   order of the table, each wrapped as `<seat stem="10_flows"> ...file text... </seat>` -> second cache breakpoint, 1-hour TTL.
3. **Live data, last:** the union of the seats' snapshot slices (one copy of each key; `snapshot_keys` lists them), the input items
   de-duplicated by evidence id (each keeps its `source`, `first_seen`, `grade`), and each seat's own last card (for `new_since_last`).

Header text, sent verbatim with `{N}`, `{seat list}` and `{call}` filled by code:
```text
COMBINED CALL {call}: you are running {N} desk seats in one call - {seat list}. Each <seat> block is that seat's full prompt; follow
it as that seat, with that seat's slice, knowledge and red lines. Return ONE JSON object {"call": "{call}", "cards": [...]} holding
exactly one SEAT CARD per seat, in the order listed, each under its own "seat" stem. A seat with nothing new writes its QUIET card.
Never merge seats into one card. A card may cite only input evidence ids, never another card written in this same call. Do not
repeat one claim in two cards to make it look like two benches: two seats reading the same item still count once.
```

## 3. Shared output (one response, one card per seat)
- The answer is the CONTRACTS section 7 envelope `{"call", "cards"}`; each card is a full CONTRACTS section 1 SEAT CARD. The envelope
  checks that every seat of the call is there exactly once and no other seat is. The server sends it as `output_config.format`,
  resolved per seat as CONTRACTS section 1 explains (each card keeps its own seat blocks and the positive-thinking rule for its stem).
- Code splits `cards` and files each one under its own seat: its own `card_id`, `seat_version` (hash of that seat's prompt file), the
  shared `prompt_hash` (hash of the whole combined prompt) and `snapshot_id`. Scoring, weights (DESK_TEAM 4.6) and the board stay per
  seat stem, exactly as if the seat had run alone; the head never sees a "combined" card.
- Cost (F29): logged once per call and split to the seats - output tokens by each card's share, input tokens evenly - so the 4.6
  "earn 3x its cost" test can run per seat.
- **max_tokens 8k** for the whole answer (DESK_TEAM 4.1). A cut-off, bad JSON, a missing or doubled seat = the whole answer is
  rejected: one retry with the error text, then the call is dropped and logged, and no card from it is used (CONTRACTS section 0).
  Fallback ladder unchanged (one tier down, then rules).
- **A second read is never combined.** When code needs a sector seat as the E12.4 second reader (CONTRACTS section 1), it calls that
  one seat's prompt alone with the raw facts and the target. That call belongs to the BUY NOW chain and bills to LIVE; 4.8a has no
  separate row for it, so it is costed inside the second-read row's margin [E] until F29 measures it.

Shape example (07:15 FINANCIALS call; in this sketch seat 20 had nothing new since its evening card):
```json
{"call": "FINANCIALS", "cards": [
 {"seat": "19_banks", "kind": "VIEW",
  "headline": "Private banks CE watch only if they hold VWAP and beat NIFTY after the open settles; PSU banks extreme, no breakout",
  "strength": 2,
  "claims": [{"text": "Five-day FII sum {num:flows.FII.sum5_cr}; private bank basket {num:sec.BANKS_PVT.pct} in the last session", "type": "FACT", "evidence_ids": ["nse:fiidii:<date>"]}],
  "ideas": [],
  "winners": [{"target": "BANKS_PVT", "side": "CE", "strength": 2, "horizon": "TODAY", "role": "FII-owned leaders", "why": "flows tilt, only on a VWAP hold"}],
  "losers": [{"target": "none", "side": "PE", "strength": 1, "horizon": "TODAY", "role": "-", "why": "none found: PSU banks get a PE only on the turn, not seen yet"}],
  "evidence": [{"id": "nse:fiidii:<date>", "source": "NSE provisional FII/DII", "first_seen": "<copied>", "grade": "OFFICIAL"}],
  "against": "Lower open expected on the US fall; the bank run is already long",
  "new_since_last": "US close and Asia open weaker than at the evening card",
  "proof": "NOT PROVEN", "expires": "15:10", "linked_card_ids": ["<seat 10 card>"], "links": ["LB-A37"]},
 {"seat": "20_nbfc_insurance_capmkts", "kind": "QUIET", "reason": "NO_CHANGE"}]}
```

## 4. Budget bucket and ladder (DESK_TEAM 4.7)
- All five calls bill to **SEATS** ($0.90 sub-cap; Monday estimate $0.64 for all SEATS rows). They never spend MEET or LIVE money; only
  a single-seat second read (section 3) bills to LIVE.
- SEATS at 70% -> the combined calls run event-only (DESK_TEAM 4.7: sector, world and company seats); SEATS at 100% -> they stop until
  the next budget day (15:40). Code seats (tape, technicals, calendar, risk) keep running. The meter shows the combined calls under their `call` names.

## 5. After Monday
Each seat splits out of its combined call in week 1 after one shadow day (its prompt says so). Week-1 groupings in DESK_TEAM 4.8b differ
(world bench 1-5 in one call, commodities 6-7, money 9-10, the nine sector seats in three calls); each new grouping needs its own
`call` value and seat list added to CONTRACTS section 7 before it runs. Everything here is NOT PROVEN until F29 measures real tokens.
