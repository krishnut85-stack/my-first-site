# ANALYST step 2 - the HEAD ANALYST loop (v2/analyst/brain.py) - 20 Nov 2026 evening

## What is built (files under /home/globalbot/intraday/v2/analyst/)
| file | what |
|---|---|
| config.py | every setting: model chain, cadence, slots, the budget ladder, the written limits (BUY NOW 4 a day, 1 per look, 5 ideas a side, 3 trades, 60 s quotes, spread 3%, R:R 1) |
| snapshot.py | the DESK SNAPSHOT (step 1) |
| knowledge.py | the cached KNOWLEDGE PACK: measured rules copied line by line from the study reports (EXTREME overbought, oversold, timing, the pick-study verdicts incl. the 09:45 CE edge, the monthly series study), LINK_BOOK A / A2 / C, SECTOR_LINKS A / B / D, CHAIN_OF_EVENTS C, EVENT_MEMORY A-D, BROKER_CALLS routine, the trader's read record (live only). ~50 KB, ~14k tokens, sorted, no timestamps (cache-safe). Replays: rows naming a Nov 2026 date on/after the evening before are dropped and the trader's record is left out (leakage) |
| prompts.py | the frozen head instructions (cause-and-effect chains, the other side, priced in, no flip-flop, timing rules, positive-thinking rule, board rules 2.3, hard limits) + the JSON contract (structured outputs) |
| board.py | DESK BOARD: SQLite WAL, append-only tables cards / decisions / rings / looks + JSONL mirror per day. ThesisBook = the head's ideas rebuilt from the decisions (id, first named, reasons, sources, evidence, state history) |
| contract.py | CODE attaches the contract (engine E7 choose_option: December monthly for stocks from expiry week, ATM / 1 ITM, premium, lot from the NFO file), share stop / T1 (0.5 / 1.0 x daily ATR [E]), premium levels (engine prem_levels), and the HARD GATES: ban, quote age 60 s, spread, R:R, feed / read-only, loss lock, 3 trades, one bet per sector, lock room, BUY NOW cap, BUY NOW window 09:20-14:30, share quote age. A failure = "WAIT: <reason>"; for BUY NOW the premium and its quote age are REQUIRED (not known = WAIT) |
| brain.py | Analyst.look(): snapshot -> one call through engine/ai.py (structured output, raw log, model chain, named fallback) -> validators -> one retry with the errors -> thesis book -> contract / gates -> outputs (state.json for the page, ideas.jsonl for the EDGE scorer, WOULD SEND lines). Budget ladder. Wake rules. Code WHY NOT lines |
| fake.py | AI-OFF dry-run head (deterministic, labelled FAKE) to test the plumbing without the key |
| service.py | gir-v2analyst: one process, own scheduler on the NSE calendar (predict.common.job_plan), briefs, live looks, event looks, code manage note 15:00-15:10; `--once [--dry]` CLI |
| gir-v2analyst.service | the systemd unit (NOT INSTALLED - see below) |
| tests/test_analyst.py | 10 unit tests, all pass |

## The JSON contract (structured outputs; checked again in code)
desk_view, market_lean UP/DOWN/MIXED + reason ids, nothing_new, ideas_new [{s, side, horizon, why [{text, FACT/INFERENCE/JUDGEMENT, evidence_ids}],
against, chain, trigger_ref (code enum: NOW, PDH_BREAK, PDL_BREAK, VWAP_RECLAIM, VWAP_LOSS, PULLBACK_VWAP, DAY_HIGH_BREAK, DAY_LOW_BREAK,
OPEN_CONFIRM), enter_if, cancel_if, conviction, source (the 8 EDGE source names), rank}], ideas_update [STANDS/CHANGED/CANCELLED/ARMED +
reason + evidence ids], buy_now (<= 1), manage [HOLD/BOOK_HALF/MOVE_STOP/EXIT], why_not [PRICE_ONLY/EXTREME_RSI/NO_REASON/AGAINST_SECTOR/GATE/LATE], ask_seats.

## Validators (a half answer is never used)
Rejected: an evidence id not in THAT call's snapshot; a share not in the F&O store; an idea with no FACT claim; an idea already open (must be
an update); more than 5 open per side; CHANGED / CANCELLED without the evidence id that changed its mind; more than 1 buy_now; a buy_now on
an idea that is neither open nor new in the answer; a manage on a position he does not hold; ANY number in the text that is not in the
snapshot or the knowledge pack (times, FY / Q tokens and 0-12 allowed). On failure: one retry with the error list, then the look is dropped
with the reason "answer rejected by the validator after one retry: ...".
No flip-flop in code: an idea CANCELLED today is re-opened only with evidence it did not have (tested).

## Never silent
Every look that does not run writes a looks row with its reason + an ai_raw row (engine/ai.py note_fallback): "budget: ...", "no model key
in this process / GIR_AI_OFF - head analyst not running", "model call failed: ...", "answer rejected ...". A fallback model answer is named
in the VIEW row ("answered by <model> (first choice failed)"). When the head is not running the page shows "head analyst not running:
<reason>" and NO idea is made from the engine (DESK_TEAM 6.5: do not dress engine cards up as analyst calls).

## Budget ladder (desk: ONE $5 a day for the whole live AI)
Checked in code BEFORE every call against GIR's ledger (intraday/aispend.py, every part, India date): under $4.25 normal (live look every
5 min); $4.25-5.00 every 10 min; at $5.00 event looks only; HARD STOP at $5.50 (an event reserve of $0.50 - THIS IS MY CHOICE, the desk
must confirm or set it to $0.00). Ledger unreadable = no look. Replays count their own per-replayed-day ledger (engine/ai.py replay mode).
Tested (test_ladder).

### What aispend.py caps TODAY and what must change (NOT changed by me)
- `aispend.budget_for()` returns **$20.00** from 19 Nov (BUILD_PLAN 0.2); `GIR_AI_BUDGET` env overrides; slices 12.5% / 60% / 12.5% + 15% reserve.
- engine/ai.py (the v2 engine's GO NOW check) is fenced only by that $20.
- Today's ledger at 18:40: **$6.64** - v2 news reader $2.60, ready files $1.54, decider $0.99 + final $0.73, old readers ~$0.34, v2 engine analyst $0.18.
- For ONE $5 cap: (1) set budget_for to 5.0 (or GIR_AI_BUDGET=5 in every AI service's environment); (2) switch the old system's AI parts
  off (J6 / J11: decider, ready files, readers, headline map); (3) decide whether the v2 news reader (~$2.6 a day alone) sits inside the $5
  - if it does, the head gets little; my ladder counts every part (config.LEDGER_PARTS = None) until the desk says otherwise.
- Today the head would not run at all (spent $6.64 > the $5.50 stop) - the right behaviour under the cap, said on the page.

### Honest cost projection (estimate [E], not measured - the key is not in my session)
One live look: ~15.5k cached system tokens (rules + knowledge), ~5.5k fresh snapshot tokens, ~3k out incl. low-effort thinking.
Opus prices in aispend ($4 / $20 per M, cache read $0.20, write $5): ~$0.085 a warm look, ~$0.16 when the 5-minute cache has expired.
Every 5 minutes 09:15-15:10 = 72 looks = **$6-11 a day for the head alone - over the $5 cap.** The ladder holds the cap (it slows to 10 min at
$4.25 and stops at $5), so in practice the head would run normally until about midday and then thin out. DESK_TEAM 4.1 (LEAN) proposes
events + a 45-60 min heartbeat instead (~$0.7 a day). It is ONE number (config.LOOK_EVERY_MIN). I kept the coordinator's 5 minutes.

## Not installed (permission)
Installing /etc/systemd/system/gir-v2analyst.service (it sources /home/globalbot/.env like gir-v2engine) was refused to my session by the
permission system. For the coordinator, after hours:
```
cp /home/globalbot/intraday/v2/analyst/gir-v2analyst.service /etc/systemd/system/ && systemctl daemon-reload && systemctl enable --now gir-v2analyst
curl -s -o /dev/null -w '%{time_total}\n' https://girtrader.com/login        # < 1 s
tail -f /home/globalbot/intraday/v2/data/analyst/service.log
# undo: systemctl disable --now gir-v2analyst; rm /etc/systemd/system/gir-v2analyst.service; systemctl daemon-reload
```
If started tonight: the 19:45 / 22:45 slots run for Monday's session but today's spend is over the stop, so they write "head analyst not
running: budget ..." (no AI money). Saturday runs nothing. Sunday 19:47 is the first real evening brief for Monday.

## Proof
- `python3 -m pytest -q analyst/tests` (from v2/): 10 passed.
- Dry runs (FAKE head, no AI): `python3 -m analyst.service --once --kind brief --slot 19:45 --dry` on the live store -> 4 ideas validated,
  contracts attached (e.g. "Dec 4100 CE (ATM, exp 2026-12-29)" from the December chain), gates evaluated, brief written to
  v2/data/analyst/dry/<stamp>/ (never the live board).

## Honest limits
- Not one real model answer yet: the prompt / schema have never met the model. The first real call (coordinator, with the key) may hit
  validator retries - the number rule is strict on purpose.
- Stop / T1 are a plain ATR rule [E]; the engine's richer _plan_share levels are not reused (they need the engine's minute memory).
- One-bet-per-sector uses his open positions' sectors; the engine's driver overlap is not used.
- The 1-hour cache TTL (DESK_TEAM 4.2) is not used: engine/ai.py sends the default 5-minute cache; changing it means editing the live engine's ai.py.
