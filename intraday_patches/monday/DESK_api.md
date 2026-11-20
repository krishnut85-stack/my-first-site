# DESK API - the store facts the pages read (gir-v2desk -> gir-preview -> pages) - 20 Nov 2026, v1

Writer: **gir-v2desk** (v2/analyst/service.py) writes `v2/data/desk/state.json` every ~20 s (atomic replace). Pages NEVER read the board
or the file: **gir-preview** reads it (DeskAdapter, every 5 s) and puts the keys below into the ONE store, so they arrive on
`/preview/api/state` and the SSE stream like every other Fact (`{v, src, src_ts, seen, state, why}`, API.md).
`src` = "v2/data/desk/state.json (gir-v2desk)". `src_ts` = the desk's heartbeat (or the item's own time where named).
Fact state: LIVE while the heartbeat is <= 120 s old; STALE "gir-v2desk not running (heartbeat <age> old)" after that;
MISSING "gir-v2desk has not run yet" when there is no file. Every value that is not known is null and the page shows "not known".
Nothing here is investment advice; every idea carries `proof: "NOT PROVEN"`. GIR never places an order - there is no buy action.

## Keys
| key | v | page use (DESK_TEAM 6.3 / 6.4) |
|---|---|---|
| `desk.status` | {running (bool), heartbeat_hm, mode "live", session (the session in view, YYYY-MM-DD), status "running" / "not running", why (plain words when the head is not running, e.g. "no prompt file for the head (desk/prompts/H*.md) yet - head analyst not running", "budget: WAIT: AI live budget used - rules view only ..."), ai_enabled, head_looks {shared_used, shared_cap 8, trigger_used, trigger_cap 2, extra_trigger_cap 3, last_hm, heartbeat_due_hm}, prompts {dirs, files[], contracts bool}, looks_today, last_look {hm, kind brief/live/event/trigger/heartbeat, ok, model, usd}} | footer "head looked hh:mm", Health seat row |
| `desk.view` | {text (<= 80 words, the head's desk view), lean "UP"/"DOWN"/"MIXED", hm (when written), fake (true only in a dry run), stale (bool: older than 90 min in market hours = 2 heartbeats), next_look "when woken · heartbeat by hh:mm"} | DESK VIEW strip (a: grey STALE when stale; then no BUY NOW shows) |
| `desk.buy_now` | today's BUY NOW calls, newest LAST: [{id (T:xxxx), s, side "CE"/"PE", hm, valid_till "hh:mm", plan {contract "SBIN Dec 1000 CE (ATM, exp 2026-12-29)", exp, strike, strike_kind, prem, lot, lots, entry, stop (share), t1 (share), rr, prem_entry ("no chase above"), prem_stop (premium backstop), prem_t1, trigger_text, levels_src, size_text, gates [{t, ok true/false/null, why}]}, why (the head's why-now line), why_lines [{text, ids[], sources[], seats[]}] (max 3), from_seats [ids], against (the Devil's objection headline), cancel_if, connection (the CONNECTIONS theme headline, blue line), risk_stamp "APPROVED", trade_n "n of 3", proof "NOT PROVEN"}] | BUY NOW hero card (b), phone CALL, Telegram WOULD SEND text |
| `desk.wait` | the last 5 candidates code held back: [{id, s, side, hm, why "WAIT: <reason>"}] - reasons include "WAIT: second read ...", "WAIT: no Devil objection ...", "WAIT: AI live budget used - rules view only", gate failures | BUY NOW card idle / WAIT stamp |
| `desk.ideas` | the thesis book for the session: [{id, s, side, state NEW/STANDS/CHANGED/ARMED/WAIT/CANCELLED/EXPIRED/BUY NOW, first_hm, why, against, chain, enter_if, cancel_if, conviction, source (one of the 8 EDGE names), sources[], rank, contract, entry, trigger_text, stop, t1, size, gate_wait, horizon, history [{hm, event, why}] (last 4), proof "NOT PROVEN"}] open ideas first, by rank | TODAY'S IDEAS (c), Morning brief columns |
| `desk.manage` | the last 8 manage notes: [{pos ("POS:<tradingsymbol>"), hm, action HOLD/BOOK_HALF/MOVE_STOP/EXIT, why}] (head notes + the code 15:10 note) | MANAGE line under each open position, phone NOW |
| `desk.whynot` | [{s, code PRICE_ONLY/EXTREME_RSI/NO_REASON/AGAINST_SECTOR/GATE/LATE, line, by "head"/"code"}] (max 8) | WHY NOT fold (d), members table grey line |
| `desk.brief` | the latest brief: {slot "19:45"/"22:45"/"07:15"/"09:08", session, made_hm, ok, why (when not ok), no_ai (22:45 nothing broke), line, view, lean, ideas {CE: [...], PE: [...]} each {id, s, state, line (the full BUY format line), source, sources, chain, plan, first_hm, history}} | Morning / EVENING BRIEF page, phone BRIEF CARD |
| `desk.seats` | the roster, 46 rows: [{id ("R1".."R6", "1".."40"), name, bench, tier "H"/"S"/"O"/"C", bucket, cadence, minimum (bool), status "on"/"off", why ("no prompt file in desk/prompts/ yet" / "prompt present - not switched on ..." / "code seat" / ...), prompt (sha or null)}] | DESK ROOM roster (left), Health seat rows |
| `desk.cards` | the latest card per seat today: [{id (C:xxxx), seat, hm, kind FACT/VIEW/THEME/OBJECTION/ALERT/QUIET/CANCEL, strength 1-5, headline}] | DESK ROOM centre |
| `desk.themes` | CONNECTIONS cards of the last 18 h: [{id, hm, headline, theme {chain[], state, confirms_live, kills, analogue}, winners [{name, side, role}], losers [...]}] (max 6) | THEMES lane (Morning right, Desk Room right) |
| `desk.objections` | DEVIL cards today: [{id, hm, headline, target (idea id), verdict FOR_STRONGER/AGAINST_STRONGER/BALANCED}] (max 8) | OBJECTIONS (Desk Room right), AGAINST line |
| `desk.meter` | J11: {from "15:40 YYYY-MM-DD", to, session, total, cap 5.0, step "NORMAL" / "SEATS EVENT-ONLY" / "CODE + RULES ONLY ($5 reached)", calls, buckets {MEET/LIVE/READ/SEATS/ASK: {spent, cap, room}}, by_seat {id: usd}, by_model {model: usd}, counted_extra_parts [], extra_usd} | footer "AI $x of $5 · ladder step", Health / Settings |

## Rules for the pages (from DESK_TEAM 6.2 / 6.5, restated so nothing is dressed up)
- When `desk.status.status` is "not running", the Desk / Morning / phone show the existing engine output under its OLD labels with
  "head analyst not running: <desk.status.why>" in grey. Never show engine cards as analyst calls.
- `desk.view.stale` true -> no BUY NOW card shows (the card reads WAIT).
- `desk.view.fake` true -> a dry run: show the grey label "DRY RUN - not the analyst" (never in live mode; dry runs write their own folder).
- Model names are never shown on the trader's pages (the footer may show "AI $x of $5").
- No buy key: "Copy contract" only (the contract text is `plan.contract`).

## Change log
- v1 20 Nov 2026 19:05 IST: first contract (desk state written; DeskAdapter added to gir-preview after hours).
