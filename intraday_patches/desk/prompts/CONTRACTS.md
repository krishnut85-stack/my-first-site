# DESK CONTRACTS - the JSON every seat and the HEAD ANALYST must return (20 Nov 2026)

Binding sources: DESK_TEAM.md 4.4 (contracts) and 4.5 (validators), ANALYST.md 1-2 (head outputs), and the head contract already
built in `v2/analyst/brain.py` / `contract.py` (monday/ANALYST_2_brain.md). Where they differ, this file follows DESK_TEAM 4.4 and
keeps every field brain.py already reads. Every seat prompt in this folder points here. Structured outputs (`output_config.format`)
carry these schemas; code validates again after the call. GIR never places orders.

## 0. Rules for every output (validator, DESK_TEAM 4.5)
- **No numbers typed by a model.** Any figure in a text field is a placeholder that code fills from the snapshot or the knowledge
  pack: `{num:<snapshot key>}` (e.g. `{num:flows.FII.sum5_cr}`, `{num:sec.BANK.pct}`, `{num:story.EM-G.n}`). Contract, lots, stop and
  target in a head output are `{code:contract}`, `{code:lots}`, `{code:stop}`, `{code:target}`. A placeholder whose key is not in that
  call's snapshot is a validation error.
- **Text fields carry no bare digits** (whitelist: FY26, Q2, December and the like). Clock times are written in words ("the evening
  meeting", "after the open settles"). Link and row references go only in id fields (`link_id`, `link_ids`, `links`, `trap_ids`).
- **Evidence ids** must be ids present in THAT call's input. Each input item already carries `source`, `first_seen` and `grade`.
- **Symbols** must be on today's F&O list (code list, ban shown); sector targets use the sector keys below.
- **Enums** only from the lists in section 3. A side that contradicts its own claims, an idea with no FACT claim, a cut-off at
  max_tokens or bad JSON = rejected. One retry with the error text, then the call is dropped and logged. A half answer is never used.
- Code adds: `card_id`, `ts`, `seat_version`, `snapshot_id`, `prompt_hash`, cost and latency (F29 log).

## 1. SEAT CARD (all seats, readers included)
```json
{
 "$schema": "https://json-schema.org/draft/2020-12/schema",
 "$id": "gir/desk/seat_card.json",
 "type": "object",
 "required": ["seat", "kind"],
 "properties": {
  "seat":      {"type": "string", "description": "seat file stem, e.g. 10_flows, 35_connections, R1"},
  "kind":      {"enum": ["FACT", "VIEW", "THEME", "OBJECTION", "ALERT", "QUIET", "CANCEL"]},
  "item_id":   {"type": "string", "description": "readers and story matcher: the input item this card is about"},
  "headline":  {"type": "string", "maxLength": 200, "description": "<= 25 words, no digits"},
  "strength":  {"type": "integer", "minimum": 1, "maximum": 5},
  "claims":    {"type": "array", "items": {"$ref": "#/$defs/claim"}},
  "ideas":     {"type": "array", "items": {"$ref": "#/$defs/idea"}},
  "winners":   {"type": "array", "items": {"$ref": "#/$defs/impact"}},
  "losers":    {"type": "array", "items": {"$ref": "#/$defs/impact"}},
  "evidence":  {"type": "array", "items": {"$ref": "#/$defs/evidence"}},
  "against":   {"type": "string", "description": "the strongest point on the other side, one line"},
  "new_since_last": {"type": "string", "description": "what is NEW vs this seat's last card; empty = write QUIET instead"},
  "proof":     {"enum": ["NOT PROVEN", "PROVEN"], "default": "NOT PROVEN"},
  "expires":   {"enum": ["15:10", "NEXT_OPEN", "2D"], "description": "= expires_at"},
  "linked_card_ids": {"type": "array", "items": {"type": "string"}},
  "links":     {"type": "array", "items": {"type": "string"}, "description": "knowledge ids, see section 4"},
  "reason":    {"type": "string", "description": "QUIET only: why silent (NO_CHANGE, REPEAT, STALE_INPUT, SIGHTING, AGREE ...)"},
  "theme":     {"type": "object", "description": "THEME cards only: FULL form ($defs.theme) for 35_connections, LIGHT form ($defs.theme_lite) for every other seat and reader (allOf below)"},
  "second_read": {"$ref": "#/$defs/second_read"},
  "regimes":   {"type": "array", "items": {"$ref": "#/$defs/regime"}, "description": "32_technicals_regimes only"},
  "objection": {"$ref": "#/$defs/objection"},
  "reader":    {"type": "object", "description": "reader / story-matcher block: novelty, story_id, route_to ... (see R1-R6 prompts)"}
 },
 "allOf": [
  {"if": {"properties": {"kind": {"const": "QUIET"}}}, "then": {"required": ["seat", "kind", "reason"]},
   "else": {"required": ["seat", "kind", "headline", "strength", "claims", "evidence", "new_since_last", "expires", "proof"]}},
  {"if": {"properties": {"kind": {"const": "THEME"}}}, "then": {"required": ["theme", "winners", "losers"],
    "if": {"properties": {"seat": {"const": "35_connections"}}},
    "then": {"properties": {"theme": {"$ref": "#/$defs/theme"}}},
    "else": {"properties": {"theme": {"$ref": "#/$defs/theme_lite"}}}}},
  {"if": {"required": ["second_read"]}, "then": {"properties": {"kind": {"enum": ["FACT", "VIEW", "OBJECTION"]}}}},
  {"if": {"properties": {"kind": {"const": "OBJECTION"}}}, "then": {"required": ["objection"]}}
 ],
 "$defs": {
  "claim": {"type": "object", "required": ["text", "type", "evidence_ids"],
   "properties": {"text": {"type": "string"}, "type": {"enum": ["FACT", "INFERENCE", "JUDGEMENT"]},
                  "evidence_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}}},
  "evidence": {"type": "object", "required": ["id", "source", "first_seen", "grade"],
   "properties": {"id": {"type": "string"}, "source": {"type": "string"}, "first_seen": {"type": "string", "description": "copied from input"},
                  "grade": {"enum": ["OFFICIAL", "ON RECORD", "SOURCES SAY", "OPINION", "SOCIAL"]}, "quote": {"type": "string"}}},
  "impact": {"type": "object", "required": ["target", "side", "strength", "horizon", "why"],
   "description": "India impact: [symbol or sector, CE/PE, strength, horizon]. target 'none' needs why = the reason none was found",
   "properties": {"target": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "strength": {"type": "integer", "minimum": 1, "maximum": 5},
                  "horizon": {"$ref": "#/$defs/horizon"}, "role": {"type": "string", "description": "leader / follower / laggard / first or second order"},
                  "link_id": {"type": ["string", "null"]}, "why": {"type": "string"}}},
  "idea": {"type": "object", "required": ["symbol", "side", "horizon", "why_ids", "against", "trigger_ref", "cancel_ref", "conviction"],
   "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "horizon": {"$ref": "#/$defs/horizon"},
                  "why_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}, "against": {"type": "string"},
                  "trigger_ref": {"$ref": "#/$defs/trigger"}, "cancel_ref": {"$ref": "#/$defs/cancel"},
                  "conviction": {"type": "string", "description": "LOW / MEDIUM, always with '- NOT PROVEN' until scored"},
                  "link_ids": {"type": "array", "items": {"type": "string"}}, "story_id": {"type": ["string", "null"]},
                  "state": {"enum": ["WATCH", "ARMED"], "default": "WATCH", "description": "a seat never writes BUY NOW"}}},
  "theme": {"type": "object", "required": ["theme_id", "state", "chain", "confirm_live", "kill_if", "analogue"],
   "properties": {"theme_id": {"type": "string"}, "state": {"enum": ["NEW", "CONFIRMING", "CONFIRMED", "BROKEN", "EXPIRED"]},
     "order": {"enum": ["FIRST", "SECOND"]},
     "causes_ranked": {"type": "array", "items": {"type": "object", "properties": {"cause": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"}}}}},
     "discriminator": {"type": "string", "description": "the observation that tells the ranked causes apart"},
     "chain": {"type": "array", "minItems": 2, "items": {"type": "object", "required": ["node", "channel", "status", "evidence_ids"],
       "properties": {"node": {"type": "string"}, "channel": {"enum": ["cost", "revenue", "demand", "policy", "flow", "peer"]},
                      "link_id": {"type": ["string", "null"]}, "status": {"enum": ["SEEN", "EXPECTED", "CONFIRMED BY PRICE", "BROKEN"]},
                      "evidence_ids": {"type": "array", "items": {"type": "string"}}}}},
     "scenarios": {"type": "array", "items": {"type": "object", "properties": {"if": {"type": "string"}, "then": {"type": "string"}}}},
     "confirm_live": {"type": "string"}, "kill_if": {"type": "string"},
     "analogue": {"type": "object", "properties": {"refs": {"type": "array", "items": {"type": "string"}}, "n": {"type": "string", "description": "placeholder"},
                  "rule": {"enum": ["EPISODES_ONLY", "MEDIAN_CAPPED_MEDIUM", "HIT_RATE", "NONE_FOUND"]}, "counter": {"type": "string"}}}}},
  "theme_lite": {"type": "object", "required": ["theme_id", "state", "chain"],
   "description": "LIGHT THEME form for readers and every seat except 35: a proposed chain routed to 10 / 35; seat 35 writes the full form",
   "properties": {"theme_id": {"type": "string", "description": "a driver key or short theme name, e.g. FII_BANKS_BUYBACK, AI_CAPEX_SHOCK"},
     "state": {"enum": ["NEW", "CONFIRMING", "BROKEN"]},
     "chain": {"type": "array", "minItems": 2, "items": {"$ref": "#/$defs/theme/properties/chain/items"}},
     "route_to": {"type": "array", "items": {"enum": ["10_flows", "35_connections"]}}}},
  "second_read": {"type": "object", "required": ["for_card_id", "verdict", "side", "target", "reason"],
   "description": "E12.4 independent second read. Written by seat 15 (filing / news items weight 4+) or by the linked sector seat 19-27 (theme ideas). The reader never saw the first card's side or conclusion.",
   "properties": {"for_card_id": {"type": "string", "description": "the card being re-read (code passes the id; the seat sees only the raw facts)"},
     "verdict": {"enum": ["AGREE", "DISAGREE", "NO_SIDE"]}, "side": {"enum": ["CE", "PE", "NONE"]},
     "target": {"type": "string", "description": "F&O symbol or sector key the verdict is about"},
     "novelty": {"enum": ["FIRST", "REPEAT-NO-NEW-FACT", "REPEAT-NEW-FACT", "DENIAL", "OFFICIAL"]},
     "event_type": {"type": "string", "description": "seat 15 list: order_win, result, guidance, block_or_promoter_sale, ... other"},
     "weight": {"type": "integer", "minimum": 1, "maximum": 5},
     "size_vs_company": {"enum": ["LARGE", "MEDIUM", "SMALL", "NOT_APPLICABLE"], "description": "from code's size table, never from the rupee figure"},
     "reason": {"type": "string", "description": "one line, no digits"}}},
  "regime": {"type": "object", "required": ["target", "zone", "line", "allowed"],
   "description": "32_technicals_regimes regime line per share or sector; zone and the count fields are code-filled",
   "properties": {"target": {"type": "string"}, "zone": {"enum": ["EXTREME", "EXTREME_BY_DISTANCE", "OVERBOUGHT", "NEUTRAL", "OVERSOLD", "DOWN_STREAK", "GAP_TOOK_IT", "LATE"]},
     "rsi": {"type": "string", "description": "placeholder {num:tech.<SYM>.rsi14}"},
     "extreme_rsi": {"type": "object", "description": "code-filled A6c count line, only when zone = EXTREME (RSI14 at or above eighty)",
       "properties": {"n": {"type": "string"}, "corrected_pct": {"type": "string"}, "median_pullback_pct": {"type": "string"}}},
     "line": {"type": "string", "description": "the regime line, no digits"},
     "allowed": {"type": "array", "items": {"$ref": "#/$defs/trigger"}}}},
  "objection": {"type": "object", "required": ["target_card_id", "best_case_other_side", "trap_ids", "what_proves_me_wrong", "severity", "recommend"],
   "properties": {"target_card_id": {"type": "string"}, "symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]},
     "best_case_other_side": {"type": "string"}, "trap_ids": {"type": "array", "items": {"type": "string"}, "description": "LB-C1 ... LB-C19, PL-A6c ..."},
     "priced_in": {"type": "string"}, "what_proves_me_wrong": {"type": "string"},
     "severity": {"enum": ["BLOCKING", "MATERIAL", "MINOR"]}, "recommend": {"enum": ["STANDS", "PULLBACK_ONLY", "WATCH", "CANCEL"]},
     "answer_needed": {"type": "string"}, "who_wins_if_wrong": {"type": "array", "items": {"type": "object"}}}},
  "horizon": {"enum": ["TODAY", "TOMORROW", "2-5D"]},
  "trigger": {"enum": ["NOW", "OPEN_CONFIRM", "PDH_BREAK", "PDL_BREAK", "VWAP_RECLAIM", "VWAP_LOSS", "PULLBACK_VWAP",
                       "DAY_HIGH_BREAK", "DAY_LOW_BREAK", "ORB5_HIGH", "ORB5_LOW", "GAP_HOLD"]},
  "cancel": {"type": "string", "pattern": "^[A-Z][A-Z_]*$",
   "description": "one of: CANCEL_PX, VWAP_LOST, SECTOR_VWAP_LOST, SECTOR_LAGS_NIFTY, NIFTY_AGAINST, DRIVER_REVERSED, DENIAL_OR_SCOPE, GAP_FILLED, TIME_STOP. Code accepts any upper-case code and logs a warning for one outside this list until the engine enum ships; then this becomes a strict enum."}
 }
}
```
Notes: `winners` and `losers` are REQUIRED (non-empty, or one `target: "none"` row with the reason) for world, commodity, money,
Connections and sector seats (DESK_TEAM 2.3 rule 6). A seat never writes BUY NOW, contract, strike, lots, stop or target.
The trigger enum mirrors brain.py's code enum (NOW ... DAY_LOW_BREAK); ORB5_HIGH / ORB5_LOW / GAP_HOLD are PROPOSED and must be added
to the engine enum before a seat may use them - until then code rejects them (and seat 32's rule says a first ORB5 / PDH fire loses
after costs, so no example uses them). The cancel codes are the PROPOSED list too, so until the engine enum ships `cancel_ref` is an
upper-case code checked against the list with a warning, not a rejection; use one of the listed codes, never a placeholder.
`proof` is only NOT PROVEN or PROVEN (code sets PROVEN from the scorecard); a calendar fact or a scorecard day count goes in claims or
a seat block, never in `proof`.
**THEME forms.** Seat 35 writes the FULL `theme` (chain of two or more nodes, confirm_live, kill_if, analogue, causes_ranked). Readers
(R2, R5, R3) and every other seat may write kind THEME with the LIGHT form (`theme_id`, `state` NEW / CONFIRMING / BROKEN, a chain of
two or more nodes, `route_to`): it proposes a chain for 10 / 35 and never starts an idea by itself.
**Second read (E12.4).** When code calls a seat as the second reader it gets the raw facts and the target, never the first card's side.
It must answer (never QUIET): AGREE -> kind FACT (seat 15) or VIEW (sector seat) with `second_read.verdict` AGREE and its side;
DISAGREE -> seat 15 writes FACT, a sector seat writes OBJECTION, both with `second_read.verdict` DISAGREE; no view -> NO_SIDE.

## 2. HEAD ANALYST OUTPUT (one object per look or brief)
```json
{
 "$schema": "https://json-schema.org/draft/2020-12/schema",
 "$id": "gir/desk/head_output.json",
 "type": "object",
 "required": ["slot", "desk_view", "market_lean", "ideas_new", "ideas_update", "buy_now", "manage", "why_not", "ask_seats", "nothing_new"],
 "properties": {
  "slot":       {"enum": ["B1945", "B2245", "B0715", "B0908", "LIVE", "REVIEW1545"]},
  "desk_view":  {"type": "string", "description": "<= 80 words: lean, main theme, what would change the view"},
  "changed_since_last": {"type": "string", "description": "briefs after 19:45: what changed, first line of the brief"},
  "market_lean": {"type": "object", "required": ["lean", "reason_ids"],
    "properties": {"lean": {"enum": ["UP", "DOWN", "MIXED"]}, "driver": {"type": "string"}, "counter_driver": {"type": "string"},
                   "reason_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}}},
  "ideas_new": {"type": "array", "items": {"$ref": "#/$defs/head_idea"}, "description": "<= 5 per side across open ideas (code counts)"},
  "ideas_update": {"type": "array", "items": {"type": "object", "required": ["idea_id", "state", "reason", "evidence_ids"],
    "properties": {"idea_id": {"type": "string"}, "state": {"enum": ["STANDS", "CHANGED", "CANCELLED", "ARMED"]},
                   "reason": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"},
                   "description": "CHANGED / CANCELLED need the id that changed the head's mind"}}}},
  "buy_now": {"type": "array", "maxItems": 1, "items": {"$ref": "#/$defs/buy_now"}, "description": "<= 1 per call; 3-4 a day cap in code"},
  "manage": {"type": "array", "items": {"type": "object", "required": ["position_id", "action", "reason", "evidence_ids"],
    "properties": {"position_id": {"type": "string"}, "action": {"enum": ["HOLD", "BOOK_HALF", "MOVE_STOP", "EXIT"]},
                   "reason": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"}}}}},
  "why_not": {"type": "array", "items": {"type": "object", "required": ["symbol", "code", "line"],
    "properties": {"symbol": {"type": "string"}, "code": {"enum": ["PRICE_ONLY", "EXTREME_RSI", "NO_REASON", "AGAINST_SECTOR", "GATE", "LATE"]},
                   "line": {"type": "string"}}}},
  "ask_seats": {"type": "array", "items": {"type": "object", "properties": {"seat": {"type": "string"}, "question": {"type": "string"}}}},
  "scorecard": {"type": "object", "description": "REVIEW1545 only: per idea right / wrong / early, by seat and source; MISS list"},
  "nothing_new": {"type": "boolean"}
 },
 "$defs": {
  "claim": {"$ref": "seat_card.json#/$defs/claim"},
  "head_idea": {"type": "object",
   "required": ["symbol", "side", "horizon", "chain", "why", "against", "answer", "trigger_ref", "enter_if", "cancel_ref", "cancel_if",
                "conviction", "state", "source_card_ids", "benches", "source"],
   "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE", "MOVER"]}, "horizon": {"$ref": "seat_card.json#/$defs/horizon"},
     "chain": {"type": "string", "description": "one line, e.g. AI-capex doubt -> Asia outflow -> India FII -> private banks"},
     "why": {"type": "array", "minItems": 1, "maxItems": 3, "items": {"$ref": "#/$defs/claim"}, "description": ">= 1 FACT"},
     "against": {"type": "string", "description": "the Devil's best objection (seat 36 card id in source_card_ids)"},
     "answer": {"type": "string", "description": "the head's answer; empty means state must be WATCH"},
     "trigger_ref": {"$ref": "seat_card.json#/$defs/trigger"}, "enter_if": {"type": "string"},
     "cancel_ref": {"$ref": "seat_card.json#/$defs/cancel"}, "cancel_if": {"type": "string"},
     "scenario": {"type": "array", "items": {"type": "object", "properties": {"if": {"type": "string"}, "then": {"enum": ["STANDS", "CHANGED", "CANCELLED"]}}}},
     "analogue": {"type": "string", "description": "refs and n as placeholders; 'NOT PROVEN'"},
     "conviction": {"type": "string"}, "state": {"enum": ["WATCH", "ARMED"]},
     "source_card_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}},
     "benches": {"type": "array", "items": {"enum": ["readers", "world", "commodities", "money", "policy", "company", "sector",
                 "voices", "market-internal", "reasoning", "trader"]}, "description": "distinct benches; rule 1 needs two, or OFFICIAL + price"},
     "source": {"type": "string", "description": "one of the EDGE source names the scorer uses"}, "rank": {"type": "integer"}}},
  "buy_now": {"type": "object", "description": "only for an idea already open in the thesis book or new in this same answer",
   "required": ["idea_id", "symbol", "side", "contract", "lots", "stop", "target", "why", "against", "answer", "enter_only_if", "cancel_if",
                "benches", "source_card_ids", "second_read", "conviction"],
   "properties": {"idea_id": {"type": "string"}, "symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]},
     "contract": {"const": "{code:contract}"}, "lots": {"const": "{code:lots}"}, "stop": {"const": "{code:stop}"}, "target": {"const": "{code:target}"},
     "why": {"type": "array", "minItems": 1, "maxItems": 3, "items": {"$ref": "#/$defs/claim"}, "description": ">= 1 FACT"},
     "against": {"type": "string"}, "answer": {"type": "string", "minLength": 1},
     "enter_only_if": {"$ref": "seat_card.json#/$defs/trigger"}, "cancel_if": {"$ref": "seat_card.json#/$defs/cancel"},
     "benches": {"type": "array", "items": {"type": "string"}}, "source_card_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}},
     "second_read": {"enum": ["AGREED", "PENDING", "DISAGREED"]}, "conviction": {"type": "string"}}}
 }
}
```

## 3. What code does after the head (never the model)
- Fills `{code:contract}` (December monthly in expiry week, ATM / 1 ITM, from the live chain), `{code:lots}` (1% risk), `{code:stop}`
  and `{code:target}` (share levels), premium and quote age.
- Sets the head's `buy_now.second_read`: AGREED only when a `second_read` card for the idea's source card says AGREE on the same side
  and target; DISAGREED on DISAGREE, NO_SIDE or the other side; PENDING when none arrived (WAIT; a 25 s timeout leaves the idea ARMED /
  WATCH). The second reader is never the seat that wrote the source card.
- Gates, any failure = "WAIT: <reason>": ban / MWPL, quote age 60 s, spread, R:R, loss lock, 3 trades a day, one bet per sector, BUY NOW
  window 09:20-14:30, daily BUY NOW cap, `second_read` not AGREED, `answer` empty while a BLOCKING / MATERIAL objection is open, fewer than
  two distinct `benches` without an OFFICIAL FACT plus a price-confirm card, a theme idea without a seat 33 confirm card.
- Rendering: `BUY <contract> · WHY · AGAINST · ENTER only if · CANCEL if · STOP · TARGET · SIZE · CONFIDENCE <grade>, NOT PROVEN`.

## 4. Id conventions (for `links`, `link_ids`, `trap_ids`)
LB-A<row> LINK_BOOK master row · LB-B<group>-<n> LINK_BOOK group sheet item (LB-B7-1 Nasdaq, LB-B7-7 FII flows) · LB-C<n> trap ·
SL-L<nn> SECTOR_LINKS · CH-C<n> CHAIN_OF_EVENTS table C · EM-<story> EVENT_MEMORY story (EM-G = US AI shock -> India) ·
BC-<house> broker thread (BC-GOLDMAN) · PL-A6c / PL-A6b PREDICTION_LOOP rules · DT-G8 DESK_TEAM proposed link G8 · TR-<n> trader read ·
OR-<study>-<case> onset_results study case (OR-SLAG-E3 = sectorlag case E3, OR-OBSCAN, OR-RALLY). In LB-B<group>-<n>, <n> is the item
number or letter as the sheet prints it (LB-B11-C = PSU vs private). Master rows always carry the A: LB-A37, never LB-37.
Sector keys: BANKS_PVT, BANKS_PSU, NBFC, INSURANCE, CAPMKTS, IT, EMS, PHARMA, HEALTHCARE, AUTO, AUTO_ANC, METALS, MINING, OIL_UP, OMC,
GAS, POWER, CAPGOODS, DEFENCE, INFRA, CEMENT, REALTY, FMCG, CONSUMER, TELECOM, CHEMICALS, INDEX.
