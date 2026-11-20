# DESK CONTRACTS - the JSON every seat and the HEAD ANALYST must return (20 Nov 2026)

Binding sources: DESK_TEAM.md 4.4 (contracts) and 4.5 (validators), ANALYST.md 1-2 (head outputs), and the head contract already
built in `v2/analyst/brain.py` / `contract.py` (monday/ANALYST_2_brain.md). Where they differ, this file follows DESK_TEAM 4.4 and
keeps every field brain.py already reads. Every seat prompt in this folder points here. Structured outputs (`output_config.format`)
carry these schemas; code validates again after the call. GIR never places orders.

## 0. Rules for every output (validator, DESK_TEAM 4.5)
- **No numbers typed by a model.** Any figure in a text field is a placeholder that code fills from the snapshot or the knowledge
  pack: `{num:<snapshot key>}` (e.g. `{num:flows.FII.sum5_cr}`, `{num:sec.BANKS_PVT.pct}`, `{num:story.EM-G.n}`). The key scheme is
  section 6; code also lists the keys present in each call's snapshot (`snapshot_keys`), and only those may be used. Contract, lots,
  stop and target in a head output are `{code:contract}`, `{code:lots}`, `{code:stop}`, `{code:target}`. A placeholder whose key is not
  in that call's snapshot is a validation error.
- **Text fields carry no bare digits** (whitelist: FY26, Q2, December and the like). Clock times MAY be written as HH:MM ("09:45", "15:10"; changed
  20 Nov - a time is not a market number); every other number still goes through a num placeholder (section 6). Link and row references go only in id fields (`link_id`, `link_ids`, `links`, `trap_ids`).
- **Evidence ids** must be ids present in THAT call's input. Each input item already carries `source`, `first_seen` and `grade`;
  a seat that grades a source itself uses the one table in section 5.
- **Symbols** must be on today's F&O list (code list, ban shown); sector targets use the sector keys in section 4.
- **Enums** only from the lists in this file. A side that contradicts its own claims, an idea with no FACT claim, a cut-off at
  max_tokens or bad JSON = rejected. One retry with the error text, then the call is dropped and logged. A half answer is never used.
- Code adds: `card_id`, `ts`, `seat_version`, `snapshot_id`, `prompt_hash`, cost and latency (F29 log).

## 1. SEAT CARD (all seats, readers included)
Every object is closed (`additionalProperties: false`), so a field that is not defined here is rejected. The common fields come first;
each seat's own block is a top-level field defined in `$defs` and tied to its seat by `dependentSchemas` (table after the schema).
```json
{
 "$schema": "https://json-schema.org/draft/2020-12/schema",
 "$id": "gir/desk/seat_card.json",
 "type": "object",
 "additionalProperties": false,
 "required": ["seat", "kind"],
 "properties": {
  "seat":      {"$ref": "#/$defs/seat_stem"},
  "kind":      {"enum": ["FACT", "VIEW", "THEME", "OBJECTION", "ALERT", "QUIET", "CANCEL"]},
  "item_id":   {"type": "string", "description": "readers and story matcher: the input item this card is about"},
  "headline":  {"type": "string", "maxLength": 200, "description": "<= 30 words for seat cards (changed 20 Nov from 25); the head's BUY NOW headline stays <= 25 words; no digits except HH:MM"},
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
  "reason":    {"type": "string", "description": "QUIET only: why silent (NO_CHANGE, REPEAT, STALE_INPUT, SIGHTING ...)"},
  "theme":     {"type": "object", "description": "THEME cards only: FULL form ($defs.theme) for 35_connections, LIGHT form ($defs.theme_lite) for every other seat and reader (allOf below)"},
  "second_read": {"$ref": "#/$defs/second_read"},
  "regimes":   {"type": "array", "items": {"$ref": "#/$defs/regime"}, "description": "32_technicals_regimes only"},
  "objection": {"$ref": "#/$defs/objection"},
  "reader":    {"type": "object", "description": "R1-R6 only; the per-reader shape is $defs.reader_R1 ... reader_R6 (allOf below)"},
  "policy_clock": {"$ref": "#/$defs/policy_clock"},
  "case":      {"$ref": "#/$defs/case"},
  "deal":      {"$ref": "#/$defs/deal"},
  "call":      {"$ref": "#/$defs/call"},
  "price_test":   {"enum": ["RUNNING", "CONFIRMED", "REJECTED", "EXPIRED", "NOT_APPLICABLE"], "description": "28: PREDICTION_LOOP D4 bottom / top price-test state, copied from code"},
  "verification": {"$ref": "#/$defs/tv_verification"},
  "story_id":  {"type": "string", "description": "29: EVENT_MEMORY story id"},
  "story_back": {"type": "boolean", "description": "29: true = this FACT is a STORY BACK"},
  "novelty":   {"$ref": "#/$defs/novelty"},
  "price_state": {"enum": ["NOT_MOVED", "PARTLY_MOVED", "ALREADY_MOVED"], "description": "29: the share's move before first sight"},
  "route":     {"type": "array", "items": {"$ref": "#/$defs/seat_stem"}, "description": "29: seats the story is routed to"},
  "buzz":      {"const": true, "description": "30: BUZZ, no fact yet"},
  "ask":       {"type": "array", "items": {"$ref": "#/$defs/seat_stem"}, "description": "30: seats asked to look for the fact"},
  "tradability": {"type": "array", "items": {"$ref": "#/$defs/tradability_row"}},
  "rule":      {"enum": ["T1_THEME_LIVE", "T2_THEME_FADING", "T2_THEME_BROKEN", "T3_SECTOR_MOVE", "T4_BASKET_SHOCK", "T5_NARROW"], "description": "33: the tape rule that fired"},
  "grade":     {"enum": ["A", "B", "C"], "description": "33: tape grade (A sector CONFIRMED, B agrees, C alone); not an evidence grade"},
  "leaders":   {"type": "array", "items": {"type": "string"}, "description": "33: F&O symbols by contribution"},
  "not_seeing": {"type": "array", "items": {"type": "string"}, "description": "33: stale or missing inputs by name"},
  "windows":   {"type": "array", "items": {"$ref": "#/$defs/window"}},
  "catalysts": {"type": "array", "items": {"$ref": "#/$defs/catalyst"}},
  "results_inside_two_sessions": {"type": "array", "items": {"type": "string"}, "description": "34: F&O symbols"},
  "analogue":  {"const": true, "description": "37: this VIEW is an analogue answer"},
  "asked_by":  {"type": "string", "description": "37: the card id that asked"},
  "rows":      {"type": "array", "items": {"$ref": "#/$defs/history_row"}},
  "count":     {"$ref": "#/$defs/history_count"},
  "read_id":   {"type": "string", "description": "38: trader_reads.json id"},
  "read":      {"$ref": "#/$defs/trader_read"},
  "verdict":   {"enum": ["AGREE", "PARTLY", "DISAGREE", "ANSWERED"], "description": "38: the desk's answer to his read (ANSWERED = a QUESTION answered)"},
  "manage":    {"enum": ["HOLD", "BOOK_HALF", "MOVE_STOP", "EXIT"], "description": "39: same enum as the HEAD manage action"},
  "position_ref": {"type": "string", "description": "39: position id"},
  "scope":     {"enum": ["day", "seat"], "description": "40"},
  "by_source": {"type": "array", "items": {"$ref": "#/$defs/score_row"}},
  "misses":    {"type": "array", "items": {"$ref": "#/$defs/miss_row"}}
 },
 "dependentSchemas": {
  "reader":       {"properties": {"seat": {"enum": ["R1", "R2", "R3", "R4", "R5", "R6"]}}},
  "theme":        {"properties": {"kind": {"const": "THEME"}}},
  "regimes":      {"properties": {"seat": {"const": "32_technicals_regimes"}}},
  "policy_clock": {"properties": {"seat": {"enum": ["11_government", "12_regulators", "14_states_elections"]}}},
  "case":         {"properties": {"seat": {"const": "13_courts"}}},
  "deal":         {"properties": {"seat": {"const": "17_corporate_actions"}}},
  "call":         {"properties": {"seat": {"const": "18_broker_calls"}}},
  "price_test":   {"properties": {"seat": {"const": "28_tv_desk"}}},
  "verification": {"properties": {"seat": {"const": "28_tv_desk"}}},
  "story_id":     {"properties": {"seat": {"const": "29_news_wires"}}},
  "story_back":   {"properties": {"seat": {"const": "29_news_wires"}}},
  "novelty":      {"properties": {"seat": {"const": "29_news_wires"}}},
  "price_state":  {"properties": {"seat": {"const": "29_news_wires"}}},
  "route":        {"properties": {"seat": {"const": "29_news_wires"}}},
  "buzz":         {"properties": {"seat": {"const": "30_social_chatter"}}},
  "ask":          {"properties": {"seat": {"const": "30_social_chatter"}}},
  "tradability":  {"properties": {"seat": {"const": "31_derivatives"}}},
  "rule":         {"properties": {"seat": {"const": "33_live_tape"}}},
  "grade":        {"properties": {"seat": {"const": "33_live_tape"}}},
  "leaders":      {"properties": {"seat": {"const": "33_live_tape"}}},
  "not_seeing":   {"properties": {"seat": {"const": "33_live_tape"}}},
  "windows":      {"properties": {"seat": {"const": "34_calendar"}}},
  "catalysts":    {"properties": {"seat": {"const": "34_calendar"}}},
  "results_inside_two_sessions": {"properties": {"seat": {"const": "34_calendar"}}},
  "analogue":     {"properties": {"seat": {"const": "37_history"}}},
  "asked_by":     {"properties": {"seat": {"const": "37_history"}}},
  "rows":         {"properties": {"seat": {"const": "37_history"}}},
  "count":        {"properties": {"seat": {"const": "37_history"}}},
  "read_id":      {"properties": {"seat": {"const": "38_trader_reads"}}},
  "read":         {"properties": {"seat": {"const": "38_trader_reads"}}},
  "verdict":      {"properties": {"seat": {"const": "38_trader_reads"}}},
  "manage":       {"properties": {"seat": {"const": "39_risk_manager"}}},
  "position_ref": {"properties": {"seat": {"const": "39_risk_manager"}}},
  "scope":        {"properties": {"seat": {"const": "40_scorekeeper"}}},
  "by_source":    {"properties": {"seat": {"const": "40_scorekeeper"}}},
  "misses":       {"properties": {"seat": {"const": "40_scorekeeper"}}}
 },
 "allOf": [
  {"if": {"properties": {"kind": {"const": "QUIET"}}}, "then": {"required": ["seat", "kind", "reason"]},
   "else": {"required": ["seat", "kind", "headline", "strength", "claims", "evidence", "new_since_last", "expires", "proof"]}},
  {"if": {"properties": {"kind": {"const": "THEME"}}}, "then": {"required": ["theme", "winners", "losers"],
    "properties": {"winners": {"$ref": "#/$defs/impact_list"}, "losers": {"$ref": "#/$defs/impact_list"}},
    "if": {"properties": {"seat": {"const": "35_connections"}}},
    "then": {"properties": {"theme": {"$ref": "#/$defs/theme"}}},
    "else": {"properties": {"theme": {"$ref": "#/$defs/theme_lite"}}}}},
  {"$comment": "POSITIVE-THINKING RULE (DESK_TEAM 2.3 rule 6): world, commodity, money and sector seats fill BOTH sides on every VIEW / ALERT / THEME",
   "if": {"required": ["seat", "kind"], "properties": {
     "seat": {"enum": ["1_us_ai_tech", "2_us_policy_rates", "3_china_north_asia", "4_europe_geopolitics", "5_em_rotation", "6_energy",
                       "7_base_metals", "8_precious_agri", "9_rupee_rates", "10_flows", "19_banks", "20_nbfc_insurance_capmkts", "21_it_ems",
                       "22_pharma_healthcare", "23_auto", "24_metals_mining", "25_oil_gas_power", "26_capgoods_infra_defence", "27_consumer"]},
     "kind": {"enum": ["VIEW", "ALERT", "THEME"]}}},
   "then": {"required": ["winners", "losers"],
            "properties": {"winners": {"$ref": "#/$defs/impact_list"}, "losers": {"$ref": "#/$defs/impact_list"}}}},
  {"if": {"required": ["second_read"]}, "then": {"properties": {"kind": {"enum": ["FACT", "VIEW", "OBJECTION"]},
    "seat": {"enum": ["15_filings_desk", "19_banks", "20_nbfc_insurance_capmkts", "21_it_ems", "22_pharma_healthcare", "23_auto",
                      "24_metals_mining", "25_oil_gas_power", "26_capgoods_infra_defence", "27_consumer", "R6"]}}}},
  {"if": {"properties": {"kind": {"const": "OBJECTION"}}}, "then": {"required": ["objection"]}},
  {"if": {"properties": {"seat": {"const": "R1"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R1"}}}},
  {"if": {"properties": {"seat": {"const": "R2"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R2"}}}},
  {"if": {"properties": {"seat": {"const": "R3"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R3"}}}},
  {"if": {"properties": {"seat": {"const": "R4"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R4"}}}},
  {"if": {"properties": {"seat": {"const": "R5"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R5"}}}},
  {"if": {"properties": {"seat": {"const": "R6"}}}, "then": {"properties": {"reader": {"$ref": "#/$defs/reader_R6"}}}}
 ],
 "$defs": {
  "seat_stem": {"enum": ["R1", "R2", "R3", "R4", "R5", "R6",
    "1_us_ai_tech", "2_us_policy_rates", "3_china_north_asia", "4_europe_geopolitics", "5_em_rotation", "6_energy", "7_base_metals",
    "8_precious_agri", "9_rupee_rates", "10_flows", "11_government", "12_regulators", "13_courts", "14_states_elections", "15_filings_desk",
    "16_results", "17_corporate_actions", "18_broker_calls", "19_banks", "20_nbfc_insurance_capmkts", "21_it_ems", "22_pharma_healthcare",
    "23_auto", "24_metals_mining", "25_oil_gas_power", "26_capgoods_infra_defence", "27_consumer", "28_tv_desk", "29_news_wires",
    "30_social_chatter", "31_derivatives", "32_technicals_regimes", "33_live_tape", "34_calendar", "35_connections", "36_devils_advocate",
    "37_history", "38_trader_reads", "39_risk_manager", "40_scorekeeper"], "description": "seat file stem; a LEAN combined call still writes one card per stem"},
  "novelty": {"enum": ["FIRST", "REPEAT-NO-NEW-FACT", "NEW-FACT", "DENIAL", "OFFICIAL"],
   "description": "NEW-FACT = a repeat story that brings a new fact (new date, forum, number or named official)"},
  "sample_rule": {"enum": ["EPISODES_ONLY", "MEDIAN_CAPPED_MEDIUM", "HIT_RATE", "NONE_FOUND"],
   "description": "EVENT_MEMORY D: n under three = EPISODES_ONLY; three to seven = MEDIAN_CAPPED_MEDIUM; eight or more = HIT_RATE"},
  "tv_verification": {"enum": ["TV ONLY - UNVERIFIED", "VERIFIED"], "description": "VERIFIED only once a document or a second outlet confirms"},
  "claim": {"type": "object", "additionalProperties": false, "required": ["text", "type", "evidence_ids"],
   "properties": {"text": {"type": "string"}, "type": {"enum": ["FACT", "INFERENCE", "JUDGEMENT"]},
                  "evidence_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}}},
  "evidence": {"type": "object", "additionalProperties": false, "required": ["id", "source", "first_seen", "grade"],
   "properties": {"id": {"type": "string"}, "source": {"type": "string"}, "first_seen": {"type": "string", "description": "copied from input"},
                  "grade": {"enum": ["OFFICIAL", "ON RECORD", "SOURCES SAY", "OPINION", "SOCIAL"], "description": "section 5 table"},
                  "quote": {"type": "string"}}},
  "impact": {"type": "object", "additionalProperties": false, "required": ["target", "side", "strength", "horizon", "why"],
   "description": "India impact: [symbol or sector key, CE/PE, strength, horizon]. target 'none' needs why = the reason none was found",
   "properties": {"target": {"type": "string", "description": "F&O symbol, sector key (section 4) or 'none'"},
                  "side": {"enum": ["CE", "PE"]}, "strength": {"type": "integer", "minimum": 1, "maximum": 5},
                  "horizon": {"$ref": "#/$defs/horizon"}, "role": {"type": "string", "description": "leader / follower / laggard / first or second order"},
                  "link_id": {"type": ["string", "null"]}, "why": {"type": "string", "minLength": 1}}},
  "impact_list": {"type": "array", "minItems": 1, "items": {"$ref": "#/$defs/impact"},
   "description": "non-empty; a side with no name is exactly ONE row with target 'none' and the reason in why",
   "if": {"contains": {"type": "object", "required": ["target"], "properties": {"target": {"const": "none"}}}},
   "then": {"maxItems": 1}},
  "idea": {"type": "object", "additionalProperties": false, "required": ["symbol", "side", "horizon", "why_ids", "against", "trigger_ref", "cancel_ref", "conviction"],
   "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "horizon": {"$ref": "#/$defs/horizon"},
                  "why_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}, "against": {"type": "string"},
                  "trigger_ref": {"$ref": "#/$defs/trigger"}, "cancel_ref": {"$ref": "#/$defs/cancel"},
                  "conviction": {"type": "string", "description": "LOW / MEDIUM, always with '- NOT PROVEN' until scored"},
                  "link_ids": {"type": "array", "items": {"type": "string"}}, "story_id": {"type": ["string", "null"]},
                  "state": {"enum": ["WATCH", "ARMED"], "default": "WATCH", "description": "a seat never writes BUY NOW"}}},
  "chain_node": {"type": "object", "additionalProperties": false, "required": ["node", "channel", "status", "evidence_ids"],
   "properties": {"node": {"type": "string"}, "channel": {"enum": ["cost", "revenue", "demand", "policy", "flow", "peer"]},
                  "link_id": {"type": ["string", "null"]}, "status": {"enum": ["SEEN", "EXPECTED", "CONFIRMED BY PRICE", "BROKEN"]},
                  "evidence_ids": {"type": "array", "items": {"type": "string"}}}},
  "theme": {"type": "object", "additionalProperties": false, "required": ["theme_id", "state", "chain", "confirm_live", "kill_if", "analogue"],
   "properties": {"theme_id": {"type": "string"}, "state": {"enum": ["NEW", "CONFIRMING", "CONFIRMED", "BROKEN", "EXPIRED"]},
     "order": {"enum": ["FIRST", "SECOND"]},
     "causes_ranked": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["cause", "evidence_ids"],
       "properties": {"cause": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"}}}}},
     "discriminator": {"type": "string", "description": "the observation that tells the ranked causes apart"},
     "chain": {"type": "array", "minItems": 2, "items": {"$ref": "#/$defs/chain_node"}},
     "scenarios": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["if", "then"],
       "properties": {"if": {"type": "string"}, "then": {"type": "string"}}}},
     "confirm_live": {"type": "string"}, "kill_if": {"type": "string"},
     "analogue": {"type": "object", "additionalProperties": false, "required": ["refs", "rule"],
       "properties": {"refs": {"type": "array", "items": {"type": "string"}}, "n": {"type": "string", "description": "placeholder"},
                      "rule": {"$ref": "#/$defs/sample_rule"}, "counter": {"type": "string"}}}}},
  "theme_lite": {"type": "object", "additionalProperties": false, "required": ["theme_id", "state", "chain", "route_to"],
   "description": "LIGHT THEME form for readers and every seat except 35: a proposed chain routed to 10 / 35; seat 35 writes the full form",
   "properties": {"theme_id": {"type": "string", "description": "a driver key or short theme name, e.g. FII_BANKS_BUYBACK, AI_CAPEX_SHOCK"},
     "state": {"enum": ["NEW", "CONFIRMING", "BROKEN"]},
     "chain": {"type": "array", "minItems": 2, "items": {"$ref": "#/$defs/chain_node"}},
     "route_to": {"type": "array", "minItems": 1, "items": {"enum": ["10_flows", "35_connections"]}}}},
  "second_read": {"type": "object", "additionalProperties": false, "required": ["for_card_id", "side", "target", "reason"],
   "description": "Independent second read. E12.4 (the one that gates BUY NOW): seat 15 (filing / news items weight 4+) or the linked sector seat 19-27 (theme ideas). R6 also writes this block for its weight-3 consistency check; code never counts an R6 verdict for buy_now.second_read. The seat is given the raw item and the target, never the first card's side or conclusion; it writes its OWN side. `verdict` is set by CODE after the call.",
   "properties": {"for_card_id": {"type": "string", "description": "the card being re-read (code passes the id; the seat sees only the raw facts)"},
     "verdict": {"enum": ["AGREE", "DISAGREE", "NO_SIDE"], "description": "CODE only: AGREE = same side as the first card, DISAGREE = the other side, NO_SIDE = side NONE. A seat never writes it."},
     "side": {"enum": ["CE", "PE", "NONE"], "description": "the seat's own independent side on the target"},
     "target": {"type": "string", "description": "F&O symbol or sector key the verdict is about"},
     "novelty": {"$ref": "#/$defs/novelty"},
     "event_type": {"type": "string", "description": "seat 15 list: order_win, result, guidance, block_or_promoter_sale, ... other"},
     "weight": {"type": "integer", "minimum": 0, "maximum": 5},
     "size_vs_company": {"enum": ["LARGE", "MEDIUM", "SMALL", "NOT_APPLICABLE"], "description": "from code's size table, never from the rupee figure"},
     "reason": {"type": "string", "description": "one line, no digits"}}},
  "regime": {"type": "object", "additionalProperties": false, "required": ["target", "zone", "line", "allowed"],
   "description": "32_technicals_regimes regime line per share or sector; zone and the count fields are code-filled",
   "properties": {"target": {"type": "string"}, "zone": {"enum": ["EXTREME", "EXTREME_BY_DISTANCE", "OVERBOUGHT", "NEUTRAL", "OVERSOLD", "DOWN_STREAK", "GAP_TOOK_IT", "LATE"]},
     "rsi": {"type": "string", "description": "placeholder {num:tech.<SYM or sector key>.rsi14}"},
     "extreme_rsi": {"type": "object", "additionalProperties": false, "description": "code-filled A6c count line, only when zone = EXTREME (RSI14 at or above eighty); never on EXTREME_BY_DISTANCE",
       "properties": {"n": {"type": "string"}, "corrected_pct": {"type": "string"}, "median_pullback_pct": {"type": "string"}}},
     "line": {"type": "string", "description": "the regime line, no digits"},
     "allowed": {"type": "array", "items": {"$ref": "#/$defs/trigger"}}}},
  "objection": {"type": "object", "additionalProperties": false, "required": ["target_card_id", "best_case_other_side", "trap_ids", "what_proves_me_wrong", "severity", "recommend"],
   "properties": {"target_card_id": {"type": "string"}, "symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]},
     "best_case_other_side": {"type": "string"}, "trap_ids": {"type": "array", "items": {"type": "string"}, "description": "LB-C1 ... LB-C19, PL-A6c ..."},
     "priced_in": {"type": "string"}, "what_proves_me_wrong": {"type": "string"},
     "severity": {"enum": ["BLOCKING", "MATERIAL", "MINOR"]}, "recommend": {"enum": ["STANDS", "PULLBACK_ONLY", "WATCH", "CANCEL"]},
     "answer_needed": {"type": "string"},
     "who_wins_if_wrong": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["target", "side", "why"],
       "properties": {"target": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "why": {"type": "string"}}}}}},
  "policy_clock": {"type": "object", "additionalProperties": false, "required": ["story", "state", "moved_from", "next_step"],
   "description": "11 / 12 / 14 and R4: the POLICY CLOCK step",
   "properties": {"story": {"type": ["string", "null"], "description": "clock id (EVENT_MEMORY story) or null for a first step"},
     "state": {"enum": ["PENDING", "DELAYED", "CONFIRMED", "NOTIFIED", "DEAD"]},
     "moved_from": {"enum": ["PENDING", "DELAYED", "CONFIRMED", "NOTIFIED", "DEAD", null]},
     "next_step": {"type": "string", "description": "plain words; a date only as a placeholder or inside a quote"}}},
  "case": {"type": "object", "additionalProperties": false, "required": ["court", "item", "stage", "parties_listed"],
   "description": "13: one matched case",
   "properties": {"court": {"enum": ["SC", "HC", "NCLT", "NCLAT", "APTEL", "SAT", "CCI", "OTHER"]}, "item": {"type": "string", "description": "as printed on the list"},
     "stage": {"enum": ["LISTED", "HEARD", "ORDER", "JUDGMENT"]}, "parties_listed": {"type": "array", "items": {"type": "string"}}}},
  "deal": {"type": "object", "additionalProperties": false, "required": ["type", "side_filed", "category_filed"],
   "description": "17: the supply / demand event as filed; size fields are placeholders",
   "properties": {"type": {"enum": ["BLOCK", "BULK", "PLEDGE", "OFS", "QIP", "LOCK_IN_EXPIRY", "INDEX_CHANGE", "FO_CHANGE", "BAN"]},
     "side_filed": {"enum": ["BUY", "SELL", null]}, "category_filed": {"enum": ["PROMOTER", "FII", "DII", "MF", "INSURER", "OTHER", null]},
     "vs_20d_volume": {"type": "string", "description": "placeholder {num:deal.vol_multiple}"}, "pct_equity": {"type": "string", "description": "placeholder {num:deal.pct_equity}"}}},
  "call": {"type": "object", "additionalProperties": false, "required": ["house", "type", "verified"],
   "description": "18: one broker / strategist call",
   "properties": {"house": {"type": "string"}, "type": {"enum": ["UPGRADE", "DOUBLE_UPGRADE", "DOWNGRADE", "INITIATION", "TARGET_ONLY", "STRATEGY_WEIGHT"]},
     "rating_from": {"type": "string"}, "rating_to": {"type": "string"}, "target_change": {"type": "string", "description": "placeholders only"},
     "verified": {"enum": ["TV_ONLY", "NOTE", "TWO_OUTLETS"]}}},
  "tradability_row": {"type": "object", "additionalProperties": false, "required": ["symbol", "contract", "state"],
   "description": "31: words only, code picks the strike",
   "properties": {"symbol": {"type": "string"}, "contract": {"enum": ["December ATM", "December one ITM"]},
     "state": {"enum": ["TRADABLE", "WAIT_FOR_CONFIRM_WINDOW", "NOT_TRADABLE"]}, "reason": {"type": "string"},
     "spread": {"type": "string", "description": "placeholder"}, "quote_age": {"type": "string", "description": "placeholder"}}},
  "window": {"type": "object", "additionalProperties": false, "required": ["from", "to", "rule"],
   "description": "34 (code-written): a no-entry or warning window",
   "properties": {"from": {"type": "string"}, "to": {"type": "string"}, "rule": {"enum": ["K2_NO_NEW_ENTRY", "K2_PINNING", "K4_RELEASE", "K5_CHECKPOINT", "K6_HOLIDAY"]}}},
  "catalyst": {"type": "object", "additionalProperties": false, "required": ["when", "what", "expected"],
   "properties": {"when": {"type": "string"}, "what": {"type": "string"}, "links": {"type": "array", "items": {"type": "string"}},
     "expected": {"type": "boolean"}, "both_sides": {"type": "string"}}},
  "history_row": {"type": "object", "additionalProperties": false, "required": ["level", "date", "what", "reaction"],
   "properties": {"level": {"enum": ["L1", "L2", "L3"]}, "date": {"type": "string", "description": "placeholder"}, "what": {"type": "string"},
     "reaction": {"type": "string", "description": "placeholder"}, "context": {"type": "string"}}},
  "history_count": {"type": "object", "additionalProperties": false, "required": ["n", "rule"],
   "properties": {"n": {"type": "string", "description": "placeholder"}, "same_way": {"type": "string", "description": "placeholder"}, "rule": {"$ref": "#/$defs/sample_rule"}}},
  "trader_read": {"type": "object", "additionalProperties": false, "required": ["words", "target", "side", "horizon", "type"],
   "properties": {"words": {"type": "string", "description": "his exact words, copied"}, "target": {"type": "string"},
     "side": {"enum": ["CE", "PE", null]}, "horizon": {"$ref": "#/$defs/horizon"}, "condition": {"type": ["string", "null"]},
     "type": {"enum": ["READ", "QUESTION"]}}},
  "score_row": {"type": "object", "additionalProperties": false, "required": ["source", "n", "right", "label"],
   "properties": {"source": {"type": "string"}, "n": {"type": "string"}, "right": {"type": "string"}, "lift": {"type": "string"},
     "label": {"enum": ["NOT PROVEN", "PROVEN"]}}},
  "miss_row": {"type": "object", "additionalProperties": false, "required": ["symbol", "side", "cause_found", "on_board_before"],
   "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "cause_found": {"type": "string"}, "on_board_before": {"type": "boolean"}}},
  "reader_R1": {"type": "object", "additionalProperties": false, "required": ["novelty", "weight", "event_type", "on_fo_list", "in_ban"],
   "properties": {"novelty": {"$ref": "#/$defs/novelty"}, "weight": {"type": "integer", "minimum": 0, "maximum": 5},
     "event_type": {"type": "string", "description": "R1 closed list"}, "on_fo_list": {"type": "boolean"}, "in_ban": {"type": "boolean"}}},
  "reader_R2": {"type": "object", "additionalProperties": false, "required": ["novelty", "source_class", "moved_before_first_seen"],
   "properties": {"novelty": {"$ref": "#/$defs/novelty"}, "source_class": {"enum": ["A", "B", "C"]},
     "sightings": {"type": "string", "description": "copied count field"}, "moved_before_first_seen": {"enum": ["yes", "no", "unknown"]}}},
  "reader_R3": {"type": "object", "additionalProperties": false, "required": ["channel", "speaker", "speaker_type", "call_kind", "novelty", "speaker_record", "verification"],
   "properties": {"channel": {"enum": ["CNBC-TV18", "ET Now", "CNBC Awaaz", "Sansad TV"]}, "speaker": {"type": "string"},
     "speaker_type": {"enum": ["CHANNEL_SOURCES", "MANAGEMENT", "OFFICIAL", "BROKER_STRATEGIST", "TV_ANALYST", "GUEST"]},
     "call_kind": {"enum": ["BROKER_CALL", "SHARE_CALL", "BOTTOM_CALL", "TOP_CALL", "MANAGEMENT", "SOURCES_SAY", "POLICY_VOICE", "FLOW_THEME"]},
     "novelty": {"enum": ["NEW", "REPEAT", "CHANGE"]}, "speaker_record": {"type": "string"}, "verification": {"$ref": "#/$defs/tv_verification"}}},
  "reader_R4": {"type": "object", "additionalProperties": false, "required": ["body", "doc_type", "doc_date_is_today", "policy_clock", "scope", "novelty", "route_to"],
   "properties": {"body": {"type": "string"}, "doc_type": {"type": "string"}, "doc_date_is_today": {"type": "boolean"},
     "policy_clock": {"$ref": "#/$defs/policy_clock"}, "scope": {"enum": ["SECTOR", "ONE_COMPANY", "MARKET"]}, "novelty": {"$ref": "#/$defs/novelty"},
     "route_to": {"type": "array", "minItems": 1, "items": {"enum": ["11_government", "12_regulators", "13_courts"]}}}},
  "reader_R5": {"type": "object", "additionalProperties": false, "required": ["driver_keys", "cause", "money_goes", "order", "session", "novelty"],
   "properties": {"driver_keys": {"type": "array", "minItems": 1, "items": {"type": "string"}}, "cause": {"type": "string"}, "money_goes": {"type": "string"},
     "order": {"enum": ["FIRST", "SECOND"]}, "session": {"enum": ["US_NIGHT", "ASIA_MORNING", "INDIA_HOURS"]},
     "side_open": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["target", "why"],
       "properties": {"target": {"type": "string"}, "why": {"type": "string"}}}},
     "novelty": {"enum": ["FIRST", "REPEAT-NO-NEW-FACT", "NEW-FACT"]}}},
  "reader_R6": {"type": "object", "additionalProperties": false, "required": ["mode"],
   "description": "MATCH mode fills the story fields; SECOND_READ mode carries mode only (the side goes in the top-level second_read block)",
   "properties": {"mode": {"enum": ["MATCH", "SECOND_READ"]}, "story_id": {"type": "string", "description": "story id or NEW"},
     "match": {"enum": ["ATTACH", "NEW_STORY", "SIGHTING"]},
     "novelty": {"enum": ["FIRST", "REPEAT-NO-NEW-FACT", "NEW-FACT", "DENIAL", "OFFICIAL", "RESOLUTION", "TV-VOICE"]},
     "episode_type": {"type": "string", "description": "EVENT_MEMORY closed list"},
     "past": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["episode_ref", "type", "reaction"],
       "properties": {"episode_ref": {"type": "string"}, "type": {"type": "string"}, "reaction": {"type": "string", "description": "placeholder"}}}},
     "sample": {"type": "object", "additionalProperties": false, "required": ["level", "n", "rule"],
       "properties": {"level": {"enum": ["L1", "L2", "L3"]}, "n": {"type": "string", "description": "placeholder"}, "rule": {"$ref": "#/$defs/sample_rule"}}},
     "won_back": {"type": "string", "description": "placeholder"}, "key_levels": {"type": "array", "items": {"type": "string"}}},
   "if": {"properties": {"mode": {"const": "MATCH"}}}, "then": {"required": ["mode", "story_id", "match", "novelty", "episode_type", "past", "sample"]}},
  "horizon": {"enum": ["TODAY", "TOMORROW", "2-5D"]},
  "trigger": {"enum": ["NOW", "OPEN_CONFIRM", "PDH_BREAK", "PDL_BREAK", "VWAP_RECLAIM", "VWAP_LOSS", "PULLBACK_VWAP",
                       "DAY_HIGH_BREAK", "DAY_LOW_BREAK"]},
  "cancel": {"type": "string", "pattern": "^[A-Z][A-Z_]*$",
   "description": "one of: CANCEL_PX, VWAP_LOST, SECTOR_VWAP_LOST, SECTOR_LAGS_NIFTY, NIFTY_AGAINST, DRIVER_REVERSED, DENIAL_OR_SCOPE, GAP_FILLED, TIME_STOP. Code accepts any upper-case code and logs a warning for one outside this list until the engine enum ships; then this becomes a strict enum."}
 }
}
```
**Seat blocks (each defined in `$defs`, allowed only on its own seat by `dependentSchemas`):**

| Seat | Top-level block(s) | `$defs` |
|---|---|---|
| R1-R6 | `reader` (per-reader shape picked by `seat`) | `reader_R1` ... `reader_R6` |
| 11, 12, 14 (and inside `reader_R4`) | `policy_clock` | `policy_clock` |
| 13_courts | `case` | `case` |
| 17_corporate_actions | `deal` | `deal` |
| 18_broker_calls | `call` | `call` |
| 28_tv_desk | `price_test`, `verification` | enum, `tv_verification` |
| 29_news_wires | `story_id`, `story_back`, `novelty`, `price_state`, `route` | `novelty`, enums, `seat_stem` |
| 30_social_chatter | `buzz` (always true), `ask` | `seat_stem` |
| 31_derivatives | `tradability` | `tradability_row` |
| 32_technicals_regimes | `regimes` | `regime` |
| 33_live_tape | `rule`, `grade` (tape grade A / B / C), `leaders`, `not_seeing` | enums |
| 34_calendar | `windows`, `catalysts`, `results_inside_two_sessions` | `window`, `catalyst` |
| 37_history | `analogue` (always true), `asked_by`, `rows`, `count` | `history_row`, `history_count`, `sample_rule` |
| 38_trader_reads | `read_id`, `read`, `verdict` | `trader_read` |
| 39_risk_manager | `manage`, `position_ref` | enum (same as the HEAD `manage.action`) |
| 40_scorekeeper | `scope`, `by_source`, `misses` | `score_row`, `miss_row` |
| any seat on kind OBJECTION | `objection` | `objection` |
| 15, 19-27, R6 when called as second reader | `second_read` | `second_read` |

**Strict structured outputs.** Some keywords here (`if` / `then`, `dependentSchemas`, `contains`) are not accepted by strict
structured outputs. So the server builds each call's `output_config.format` from this file by resolving it for the calling seat:
the common fields, plus that seat's own blocks, its `reader_Rn` shape (readers), the THEME form it may write (`theme` for 35,
`theme_lite` otherwise) and, for the seats in the positive-thinking list, `winners` / `losers` with `minItems: 1`. Every object
keeps `additionalProperties: false`. Code then validates the answer against this full schema (the `if` / `then` rules included).

**Positive-thinking rule (DESK_TEAM 2.3 rule 6), enforced by the third `allOf` branch:** for the world, commodity, money and sector
seats (1-10, 19-27) every VIEW, ALERT and THEME card must carry non-empty `winners` AND `losers`. A side with no name found is exactly
one row `{"target": "none", "side": ..., "strength": 1, "horizon": ..., "why": "none found: <reason>"}` (`impact_list`: a "none" row
cannot sit next to real names). Every THEME card, whatever the seat (35 and the readers included), carries the same non-empty lists.
This holds for a sector seat's second-read card too: the target row on its own side, and the other side named or "none + reason".

A seat never writes BUY NOW, contract, strike, lots, stop or target.
The trigger enum mirrors brain.py's code enum exactly. ORB5_HIGH / ORB5_LOW / GAP_HOLD are PROPOSED only (NOT in the enum):
they are added to the enum the day the engine ships them - until then code rejects them. Seat 32's rule says every first ORB5 / PDH fire loses
after costs, so no example uses ORB5, PDH_BREAK or PDL_BREAK; PDH / PDL is only a timing aid on a share another bench already named,
never an allowed entry in a regime line. The cancel codes are the PROPOSED list too, so until the engine enum ships `cancel_ref` is an
upper-case code checked against the list with a warning, not a rejection; use one of the listed codes, never a placeholder.
`proof` is only NOT PROVEN or PROVEN (code sets PROVEN from the scorecard); a calendar fact or a scorecard day count goes in claims or
a seat block, never in `proof`.
**THEME forms.** Seat 35 writes the FULL `theme` (chain of two or more nodes, confirm_live, kill_if, analogue, causes_ranked). Readers
(R2, R5, R3) and every other seat may write kind THEME with the LIGHT form (`theme_id`, `state` NEW / CONFIRMING / BROKEN, a chain of
two or more nodes, `route_to`): it proposes a chain for 10 / 35 and never starts an idea by itself.
**Second read (E12.4).** When code calls a seat as the second reader it gets the raw item and the target, never the first card's side,
conclusion or card. It must answer (never QUIET) with one card carrying `second_read`: seat 15 writes kind FACT, a sector seat writes
kind VIEW, with its own `side` (CE / PE / NONE), target and one-line reason. Code then sets `second_read.verdict` (AGREE / DISAGREE /
NO_SIDE) by comparing sides. A sector seat that also finds a blocking fact (a denial, an OFS week, EXTREME RSI on a breakout) adds it as
an OBJECTION card. **R6's weight-3 check** uses the same block and the same blindness (raw item only, kind FACT, verdict by code), but
it is a consistency check on Haiku reader cards: it never stands in for the E12.4 read, and code never uses an R6 verdict to set
`buy_now.second_read` (section 3).

## 2. HEAD ANALYST OUTPUT (one object per look or brief)
```json
{
 "$schema": "https://json-schema.org/draft/2020-12/schema",
 "$id": "gir/desk/head_output.json",
 "type": "object",
 "additionalProperties": false,
 "required": ["slot", "desk_view", "market_lean", "ideas_new", "ideas_update", "buy_now", "manage", "why_not", "ask_seats", "nothing_new"],
 "properties": {
  "slot":       {"enum": ["B1945", "B2245", "B0715", "B0908", "LIVE", "REVIEW1545"]},
  "desk_view":  {"type": "string", "description": "<= 80 words: lean, main theme, what would change the view"},
  "changed_since_last": {"type": "string", "description": "briefs after 19:45: what changed, first line of the brief"},
  "market_lean": {"type": "object", "additionalProperties": false, "required": ["lean", "reason_ids"],
    "properties": {"lean": {"enum": ["UP", "DOWN", "MIXED"]}, "driver": {"type": "string"}, "counter_driver": {"type": "string"},
                   "reason_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}}}},
  "ideas_new": {"type": "array", "items": {"$ref": "#/$defs/head_idea"}, "description": "<= 5 per side across open ideas (code counts)"},
  "ideas_update": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["idea_id", "state", "reason", "evidence_ids"],
    "properties": {"idea_id": {"type": "string"}, "state": {"enum": ["STANDS", "CHANGED", "CANCELLED", "ARMED"]},
                   "reason": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"},
                   "description": "CHANGED / CANCELLED need the id that changed the head's mind"}}}},
  "buy_now": {"type": "array", "maxItems": 1, "items": {"$ref": "#/$defs/buy_now"}, "description": "<= 1 per call; 3-4 a day cap in code"},
  "manage": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["position_id", "action", "reason", "evidence_ids"],
    "properties": {"position_id": {"type": "string"}, "action": {"enum": ["HOLD", "BOOK_HALF", "MOVE_STOP", "EXIT"]},
                   "reason": {"type": "string"}, "evidence_ids": {"type": "array", "items": {"type": "string"}}}}},
  "why_not": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["symbol", "code", "line"],
    "properties": {"symbol": {"type": "string"}, "code": {"enum": ["PRICE_ONLY", "EXTREME_RSI", "NO_REASON", "AGAINST_SECTOR", "GATE", "LATE"]},
                   "line": {"type": "string"}}}},
  "ask_seats": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["seat", "question"],
    "properties": {"seat": {"$ref": "seat_card.json#/$defs/seat_stem"}, "question": {"type": "string"}}}},
  "scorecard": {"type": "object", "additionalProperties": false, "required": ["ideas", "misses"],
    "description": "REVIEW1545 only: per idea right / wrong / early, by seat and source; MISS list (numbers stay in code's scorecard card, seat 40)",
    "properties": {
     "ideas": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["idea_id", "result", "seats", "source"],
       "properties": {"idea_id": {"type": "string"}, "result": {"enum": ["RIGHT", "WRONG", "EARLY", "NO_MOVE", "CANCELLED_RIGHT", "CANCELLED_WRONG"]},
                      "seats": {"type": "array", "items": {"$ref": "seat_card.json#/$defs/seat_stem"}}, "source": {"type": "string"}, "line": {"type": "string"}}}},
     "misses": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["symbol", "side", "cause"],
       "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]}, "cause": {"type": "string"}, "link_id": {"type": ["string", "null"]}}}}}},
  "nothing_new": {"type": "boolean"}
 },
 "$defs": {
  "claim": {"$ref": "seat_card.json#/$defs/claim"},
  "head_idea": {"type": "object", "additionalProperties": false,
   "required": ["symbol", "side", "horizon", "chain", "why", "against", "answer", "trigger_ref", "enter_if", "cancel_ref", "cancel_if",
                "conviction", "state", "source_card_ids", "benches", "source"],
   "properties": {"symbol": {"type": "string"}, "side": {"enum": ["CE", "PE", "MOVER"]}, "horizon": {"$ref": "seat_card.json#/$defs/horizon"},
     "chain": {"type": "string", "description": "one line, e.g. AI-capex doubt -> Asia outflow -> India FII -> private banks"},
     "why": {"type": "array", "minItems": 1, "maxItems": 3, "items": {"$ref": "#/$defs/claim"}, "description": ">= 1 FACT"},
     "against": {"type": "string", "description": "the Devil's best objection (its seat 36 card id goes in source_card_ids)"},
     "answer": {"type": "string", "description": "the head's answer; empty means state must be WATCH"},
     "trigger_ref": {"$ref": "seat_card.json#/$defs/trigger"}, "enter_if": {"type": "string"},
     "cancel_ref": {"$ref": "seat_card.json#/$defs/cancel"}, "cancel_if": {"type": "string"},
     "scenario": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["if", "then"],
       "properties": {"if": {"type": "string"}, "then": {"enum": ["STANDS", "CHANGED", "CANCELLED"]}}}},
     "analogue": {"type": "string", "description": "refs and n as placeholders; 'NOT PROVEN'"},
     "conviction": {"type": "string"}, "state": {"enum": ["WATCH", "ARMED"]},
     "source_card_ids": {"type": "array", "minItems": 1, "items": {"type": "string"}, "description": "includes the seat 36 card id behind `against`"},
     "benches": {"type": "array", "items": {"$ref": "#/$defs/bench"}, "description": "distinct supporting benches; rule 1 needs two, or OFFICIAL + price"},
     "source": {"type": "string", "description": "one of the EDGE source names the scorer uses"}, "rank": {"type": "integer"}}},
  "bench": {"enum": ["readers", "world", "commodities", "money", "policy", "company", "sector", "voices", "market-internal", "reasoning", "trader"]},
  "buy_now": {"type": "object", "additionalProperties": false, "description": "only for an idea already open in the thesis book or new in this same answer",
   "required": ["idea_id", "symbol", "side", "contract", "lots", "stop", "target", "why", "against", "answer", "enter_only_if", "cancel_if",
                "benches", "source_card_ids", "second_read", "conviction"],
   "properties": {"idea_id": {"type": "string"}, "symbol": {"type": "string"}, "side": {"enum": ["CE", "PE"]},
     "contract": {"const": "{code:contract}"}, "lots": {"const": "{code:lots}"}, "stop": {"const": "{code:stop}"}, "target": {"const": "{code:target}"},
     "why": {"type": "array", "minItems": 1, "maxItems": 3, "items": {"$ref": "#/$defs/claim"}, "description": ">= 1 FACT"},
     "against": {"type": "string", "description": "the Devil's objection; its seat 36 card id must be in source_card_ids (code checks)"},
     "answer": {"type": "string", "minLength": 1},
     "enter_only_if": {"$ref": "seat_card.json#/$defs/trigger"}, "cancel_if": {"$ref": "seat_card.json#/$defs/cancel"},
     "benches": {"type": "array", "items": {"$ref": "#/$defs/bench"}}, "source_card_ids": {"type": "array", "minItems": 2, "items": {"type": "string"}},
     "second_read": {"enum": ["AGREED", "PENDING", "DISAGREED"]}, "conviction": {"type": "string"}}}
 }
}
```
`against` on a head idea or a BUY NOW is the Devil's objection, and the seat 36 card id that holds it is in `source_card_ids` (rule 2
must be traceable); code checks that a seat 36 card for the idea is listed before a BUY NOW leaves.

## 3. What code does after the head (never the model)
- Fills `{code:contract}` (December monthly in expiry week, ATM / 1 ITM, from the live chain), `{code:lots}` (1% risk), `{code:stop}`
  and `{code:target}` (share levels), premium and quote age.
- Sets `second_read.verdict` on the second reader's card, then the head's `buy_now.second_read`: AGREED only when a `second_read` card
  from seat 15 (news / filing) or the linked sector seat 19-27 (theme) for the idea's source card has verdict AGREE on the same target;
  DISAGREED on DISAGREE, NO_SIDE or the other side; PENDING when none arrived (WAIT; a 25 s timeout leaves the idea ARMED / WATCH).
  The second reader is never the seat that wrote the source card. An R6 `second_read` card (weight-3 check) is shown on the board
  and, on DISAGREE, marks the reader card disputed; it never sets `buy_now.second_read`.
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

## 5. Source grades (the one table every prompt uses for `evidence.grade`)
| Grade | What gets it | Examples |
|---|---|---|
| OFFICIAL | the document or data itself, from the body that owns it | exchange filing, circular, gazette, PIB / RBI / SEBI release, court order or cause list, NSE / NSDL file, exchange prices, code's own snapshot, scorecard and calendar |
| ON RECORD | a NAMED person speaking for themselves or their body, in print or on air; a press report of an official file not yet seen | minister, regulator chief, CEO / management on TV, named official or dealer quoted on a wire, the trader's own read; "BS citing NSDL data" until the NSDL file is seen (then OFFICIAL) |
| SOURCES SAY | unnamed sources, whoever carries them | "officials said", "people familiar", a **TV channel exclusive** ("sources tell CNBC-TV18"), "RBI seen intervening", "deal likely" on one wire |
| OPINION | a view, not a fact, from a named house or voice | broker or strategist note, rating or target (published or not; a published note is still OPINION, marked VERIFIED), a **broker or analyst on air**, a TV anchor's or guest's market recap, "markets expect", a newspaper column |
| SOCIAL | social media and chat channels only | Telegram public channels, X / Twitter posts, forums, WhatsApp forwards |

Rules: nothing said on TV is graded SOCIAL - TV is ON RECORD (named official or management), SOURCES SAY (channel exclusive) or OPINION
(broker, analyst, anchor, guest). "Brokers said" with no named house is not a broker call (QUIET). SOURCES SAY, OPINION and SOCIAL may
support a claim but are never an idea's only FACT, and never drive a BUY NOW alone (DESK_TEAM 2.3 rule 4).

## 6. Placeholder keys (`{num:<namespace>.<KEY>.<field>}`) - what the snapshot builder must emit
One scheme everywhere. `<KEY>` is an F&O symbol, a sector key (section 4), or a fixed name listed below; `<field>` is from the list.
The snapshot builder (`v2/analyst/snapshot.py`) emits exactly these names, passes the present ones as `snapshot_keys`, and the
validator rejects any other key. Examples in the prompts use only keys from this table.

| Namespace | `<KEY>` | Fields | Example |
|---|---|---|---|
| `flows` | FII, DII | today_cr, sum5_cr, month_cr, streak, streak_a, streak_b (two outlets' counts) | `{num:flows.FII.sum5_cr}` |
| `idx` | NIFTY, BANKNIFTY, GIFT, INDIAVIX | pct, pct_open, level | `{num:idx.NIFTY.pct_open}` |
| `mkt` | breadth | adv, dec | `{num:mkt.breadth.adv}` |
| `sec` | sector key (BANKS_PVT, IT, METALS ...) | pct, pct_open, pct15, preopen_pct, breadth_up, below_vwap, n (members), rs30, down_days, shock_n | `{num:sec.BANKS_PVT.pct}` |
| `px` | F&O symbol | pct, pct_open, preopen_pct, pct_15m_before | `{num:px.CYIENT.pct_open}` |
| `tech` | F&O symbol or sector key | rsi14, vs20d_pct | `{num:tech.PNB.rsi14}` |
| `oi` | F&O symbol or sector key | total_chg_pct | `{num:oi.BANKS_PVT.total_chg_pct}` |
| `opt` | F&O symbol, then contract (dec_atm, dec_itm1) | spread_pct, age_s | `{num:opt.AXISBANK.dec_atm.spread_pct}` |
| `world` | NASDAQ, SP500, AI_BASKET, ADR_INFY, ADR_WIT, ADR_HDB, ADR_IBN, KOSPI, TAIEX, NIKKEI, HANGSENG, VIX, US10Y, FEDFUT | pct, level, dec_hike_prob (FEDFUT) | `{num:world.KOSPI.pct}` |
| `cmdty` | BRENT, WTI, GOLD, SILVER, LME_CU, LME_AL, SHFE_CU | pct, pct5d, level | `{num:cmdty.BRENT.pct5d}` |
| `fx` | USDINR, DXY | pct, last, level | `{num:fx.USDINR.pct}` |
| `rbi` | vrr, vrrr | notified_cr, bids_cr | `{num:rbi.vrr.bids_cr}` |
| `item` | - | n1, n2 ... nK: the numbers code tagged in the input item, in order | `{num:item.n1}` |
| `deal` | - | shares, vol_multiple, pct_equity, discount_pct | `{num:deal.vol_multiple}` |
| `cal` | expiry, release, checkpoint, next | no_entry_after, pin_from, time, gap_min, date | `{num:cal.expiry.pin_from}` |
| `story` | EVENT_MEMORY story id (EM-G, PAYTM-UPI_MDR) | n, same, won_back_pct, level1 ... levelK, ep<k>.date, ep<k>.close_pct, ep<k>.intraday_pct, ep<k>.banknifty_close_pct | `{num:story.EM-G.n}` |
| `pos` | - (the position in the call) | r_now, minutes, stop, target, lots, lock_room, trade_n, rr, spread_pct | `{num:pos.r_now}` |
| `tr` | ce, pe (the trader's reads) | hits, n | `{num:tr.ce.hits}` |
| `sc` | day fields, or a seat / source name | day: right, n, ce_right, ce_n, ce_base, pe_right, pe_n, pe_base, early, ce_lift_pts, pe_lift_pts, miss3, miss_top, day_n, right20_pct, base20_pct; per seat / source: n, right, lift, cards, reached_head, cost | `{num:sc.10_flows.right}` |

A share's own move is `px.<SYMBOL>`, never `sec.<SYMBOL>`; a basket that is not a sector key (gold lenders, jewellers) is named
through its leader's `px` key until code adds the basket.

## 7. LEAN combined calls (Monday 23 Nov) - one response, one card per seat
LEAN_COMBINED.md says which seat prompts each combined call concatenates. The answer is one object holding exactly one SEAT CARD per
seat in the call (QUIET for a seat with nothing new), each card under its own seat stem, so scoring, weights and the board stay per seat.
```json
{
 "$schema": "https://json-schema.org/draft/2020-12/schema",
 "$id": "gir/desk/lean_combined.json",
 "type": "object",
 "additionalProperties": false,
 "required": ["call", "cards"],
 "properties": {
  "call":  {"enum": ["GLOBAL", "FLOWS", "FINANCIALS", "INDUSTRIALS-METALS-ENERGY-INFRA", "CONSUMER-IT-PHARMA-AUTO"]},
  "cards": {"type": "array", "items": {"$ref": "seat_card.json"}}
 },
 "allOf": [
  {"if": {"properties": {"call": {"const": "GLOBAL"}}},
   "then": {"properties": {"cards": {"minItems": 6, "maxItems": 6,
     "items": {"properties": {"seat": {"enum": ["1_us_ai_tech", "2_us_policy_rates", "3_china_north_asia", "4_europe_geopolitics", "6_energy", "7_base_metals"]}}},
     "allOf": [{"contains": {"properties": {"seat": {"const": "1_us_ai_tech"}}}}, {"contains": {"properties": {"seat": {"const": "2_us_policy_rates"}}}}, {"contains": {"properties": {"seat": {"const": "3_china_north_asia"}}}}, {"contains": {"properties": {"seat": {"const": "4_europe_geopolitics"}}}}, {"contains": {"properties": {"seat": {"const": "6_energy"}}}}, {"contains": {"properties": {"seat": {"const": "7_base_metals"}}}}]}}}},
  {"if": {"properties": {"call": {"const": "FLOWS"}}},
   "then": {"properties": {"cards": {"minItems": 3, "maxItems": 3,
     "items": {"properties": {"seat": {"enum": ["10_flows", "5_em_rotation", "9_rupee_rates"]}}},
     "allOf": [{"contains": {"properties": {"seat": {"const": "10_flows"}}}}, {"contains": {"properties": {"seat": {"const": "5_em_rotation"}}}}, {"contains": {"properties": {"seat": {"const": "9_rupee_rates"}}}}]}}}},
  {"if": {"properties": {"call": {"const": "FINANCIALS"}}},
   "then": {"properties": {"cards": {"minItems": 2, "maxItems": 2,
     "items": {"properties": {"seat": {"enum": ["19_banks", "20_nbfc_insurance_capmkts"]}}},
     "allOf": [{"contains": {"properties": {"seat": {"const": "19_banks"}}}}, {"contains": {"properties": {"seat": {"const": "20_nbfc_insurance_capmkts"}}}}]}}}},
  {"if": {"properties": {"call": {"const": "INDUSTRIALS-METALS-ENERGY-INFRA"}}},
   "then": {"properties": {"cards": {"minItems": 3, "maxItems": 3,
     "items": {"properties": {"seat": {"enum": ["24_metals_mining", "25_oil_gas_power", "26_capgoods_infra_defence"]}}},
     "allOf": [{"contains": {"properties": {"seat": {"const": "24_metals_mining"}}}}, {"contains": {"properties": {"seat": {"const": "25_oil_gas_power"}}}}, {"contains": {"properties": {"seat": {"const": "26_capgoods_infra_defence"}}}}]}}}},
  {"if": {"properties": {"call": {"const": "CONSUMER-IT-PHARMA-AUTO"}}},
   "then": {"properties": {"cards": {"minItems": 4, "maxItems": 4,
     "items": {"properties": {"seat": {"enum": ["21_it_ems", "22_pharma_healthcare", "23_auto", "27_consumer"]}}},
     "allOf": [{"contains": {"properties": {"seat": {"const": "21_it_ems"}}}}, {"contains": {"properties": {"seat": {"const": "22_pharma_healthcare"}}}}, {"contains": {"properties": {"seat": {"const": "23_auto"}}}}, {"contains": {"properties": {"seat": {"const": "27_consumer"}}}}]}}}}
 ]
}
```
The server sends the combined call's prompt (LEAN_COMBINED.md) with this envelope as its `output_config.format` (resolved per seat as
in section 1); code splits `cards` and files each card under its own seat. A missing seat, a seat twice or a seat from another call =
the whole answer is rejected (one retry, then dropped and logged, section 0).
