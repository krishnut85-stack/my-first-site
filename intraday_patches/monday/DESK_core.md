# DESK part (a) - the Monday MINIMUM core (gir-v2desk) - 20 Nov 2026 evening

All code is in /home/globalbot/intraday/v2/analyst/ (package name kept from the first build; the service is **gir-v2desk**).
Outputs: /home/globalbot/intraday/v2/data/desk/ (state.json for the page, deskboard.db, board_jsonl/, would_send.jsonl, ai_raw_desk.jsonl,
fii_daily.json, service.log). Nothing in the old system, gir-watchdog, paper_exit_monitor or gir-v2replay was touched.

## What is built (DESK_TEAM section -> file)
| item | where | state |
|---|---|---|
| desk service, own scheduler, one process (5.1) | service.py, gir-v2desk.service | built, NOT installed (coordinator installs) |
| DESK BOARD, SQLite WAL, append-only cards / decisions / rings / looks / ai_calls + JSONL mirror; restart rebuild (5.2, 5.7) | board.py | built, tested |
| seat card + head validators (4.4 / 4.5): evidence ids only from that call's input, F&O symbols only, trigger enum, FACT claim, winners / losers or none_reason (positive-thinking rule), headline <= 25 words, strength 1-5, **no bare digit in any text field** (whitelist FY / Q / ids; figures only as `{num:<key>}` filled by code), reader quote = exact item text, `{num:item.n<k>}` only for figures code tagged; one retry with the errors, then dropped | seats.py, brain.py, nums.py | built, tested |
| DESK SNAPSHOT (5.3) | snapshot.py | built, tested (step 1) |
| **J11 hard $5 gate** before every call: budget day 15:40 -> 15:40, buckets MEET 1.50 / LIVE 1.30 / READ 1.00 / SEATS 0.90 / ASK 0.30, total hard stop $5.00, SEATS event-only at 70%, MEET -> LIVE after 09:08, refusals logged with the reason; counts the desk's own ledger only (old-system parts listed with the reason they are not counted; v2 news reader = open decision) | gate.py, call.py, config.py | built, tested |
| scheduler / wake rules (4.3, 4.3a): head 8 shared + 2 trigger looks (+3 while LIVE money lasts), heartbeat after 45 min, 3 min between looks, 90 s between event looks; trigger = Devil then head; event = NEW weight >= 4 item on an F&O share with the price agreeing | service.py live_step / wake | built |
| HEAD: prompt from desk/prompts/H*.md (+ a code frame that only says how the answer is used), cached knowledge pack, JSON contract, thesis book, BUY NOW chain in code (gates, seat-15 second read for news / filing / TV / broker / results ideas, live tape confirmation for a theme idea, the Devil's objection cited, TV never alone), WAIT reasons, manage notes, WHY NOT (head + code) | brain.py, prompts.py, contract.py | built; OFF until H*.md lands |
| FLOWS (seat 10): FII daily figures recorded so far (NSDL custodial rows + NSE provisional strip.fii, kept daily from now in fii_daily.json), the 5-day sum rule; LOW grade in the prompt | seats.py flows_store / record_fii | built; honest gap: only 18 / 19 / 20 Nov recorded -> "5-day sum not known (3 days)" until Wed 25 |
| CONNECTIONS (35, Opus at 19:45 / 07:15 / 09:05; Sonnet re-check on a shock), DEVIL (36, meetings + every BUY NOW candidate, LIVE bucket) | seats.py | built; OFF until their prompt files land |
| R1 filings reader (Haiku, 8 items or 20 s; gir-v2filings log + news.filings + news.list filings), R2 wires, R3 TV (tv.db, one call a minute), R4 policy, R5 world, R6 story | seats.py run_reader | built; prompts R1-R6 are on the branch (not yet in preview_src) |
| seat-15 second read (independent: it never sees the reader's answer) | seats.py run_second_reads / second_read_ok | built; OFF until 15*.md lands |
| store facts / API for the pages (6.5): 13 desk.* keys | v2/server/preview.py DeskAdapter; contract DESK_api.md | LIVE in gir-preview since 19:05 (MISSING until the desk runs) |
| every other bench (part b): all 46 seats in the roster with their bench slice, cadence and bucket; on when the prompt lands + one clean shadow run | seats.py ROSTER, slice_for | built as plumbing; code seats 32 / 33 / 34 / 38 / 39 / 40 run now |
| go-live shadow check (rule 5) | shadow.py | built |
| rehearsal (18 / 19 / 20 Nov) | rehearsal.py | built; stub layer running (see DESK_rehearsal.md) |

## Seat brains
Loaded ONLY from /home/globalbot/preview_src/intraday_patches/desk/prompts/ (config.PROMPT_DIRS). That folder does not exist yet in
preview_src; 14 files (R1-R6, seats 1-8) are on the branch copy /root/intraday-push/intraday_patches/desk/prompts/, no CONTRACTS.md,
no H, 10, 15, 35, 36 yet. Until CONTRACTS.md lands the structured-output schemas are code schemas copied from the prompts' own
section-5 envelope (seat card: seat, kind, headline, strength, claims, ideas, winners / losers {target, side, strength, horizon, role,
why}, ...; reader card: item_id, reader {novelty, weight, event_type, on_fo_list, in_ban}, evidence {quote}, ...). When CONTRACTS.md
lands its schemas are used automatically (promptload.py) - the head's only if its required fields match the code (else named).

## Tests
`cd /home/globalbot/intraday/v2 && python3 -m pytest -q analyst/tests` -> 14 passed (snapshot point in time, validators incl. the
number rule, thesis book + no flip-flop, J11 buckets / ladder / hard cap / budget day / rehearsal line, ring once across restarts,
prompt loader + seat status, card and reader validators).
Dry runs: `python3 -m analyst.service --once --kind brief --slot 19:45 --dry` (own folder data/desk/dry/<stamp>, FAKE brains): the
whole 19:45 meeting (31 seats in the desk order) + the head + the brief pass validation and are written.

## UPDATE 20:12 IST (state after the 19:50 / 19:54 shadows)
- **Seat brains loaded:** all 48 files in preview_src/intraday_patches/desk/prompts (R1-R6, 1-40, H, CONTRACTS.md). The roster shows each AI seat "prompt present - not switched on in seats.json"; 30 is OFF by design (no social source). Code seats 32 / 33 / 34 / 38 / 39 / 40 run as code. The HEAD is gated the same way (seats.json "H"), so the 19:47 slot tonight wrote "head analyst not running" and spent nothing.
- **CONTRACTS.md wired** (analyst/contracts.py): full jsonschema check of every card and head answer in code; clean_card (seat = file stem, unused blocks dropped, QUIET = reason only, strengths clamped 1-5); head answers normalised to the pipeline. API side per seat family: structured outputs (every field required, no unions) for readers, seat 15 and the Devil; JSON-in-text (full schema in the system frame, parse + full check + one retry) for the generic seats, sector seats, Connections and the head - after the API's 'too many optional parameters' and 'compiled grammar too large' 400s. config.STRUCTURED_FAMILIES switches a family; unit test ApiSchemaLimits keeps every API schema at 0 optional / 0 union parameters.
- **Numbers:** every model input carries the exact {num:key} list (CONTRACTS aliases world. cmdty. fx. flows.FII.* sec.<KEY> tech. pos. story.) and the sector keys; bare digits rejected; {code:contract|lots|stop|target} filled by code.
- **BUY NOW chain (CONTRACTS 3):** gates + seat-15 second read AGREE on side and target + Devil objection cited and a BLOCKING / MATERIAL one answered + two benches or an OFFICIAL fact + a seat-33 tape card for a theme.
- **J11:** budget day 15:40 -> 15:40 of the next calendar day, $5 each (coordinator; DESK_TEAM 4.7's Fri->Mon single day overridden); weekend / holiday days in slow mode. Counted: the desk ledger + the v2 news reader on READ by time (desk decision). NEWSREAD_AI_OFF flag ready, not set.
- **Tools:** shadow.py (go-live check; --head; seat 15 tested on the shadow's own reader card), apitest.py (one cheap real call per family), rehearsal.py (summary to DESK_rehearsal_<run>.md, names scrubbed; raw stays in the excluded DESK_rehearsal/).
- **Tests:** 19 pass. Stub rehearsal 18 Nov clean (4 briefs, 911 looks, 918 FAKE calls, EDGE scored by the analyst's own rank); 19-20 Nov running.
- **Open:** no real-model answer validated yet for the JSON-in-text families (needs the coordinator's apitest run); the prompts use some keys code does not fill yet (story stats, scorecard sc.*, opt.*, deal.*, cal.*, rbi.*) - a model that uses them gets a validator retry.
