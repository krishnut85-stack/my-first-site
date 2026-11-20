# B9 - fault test: each fault degrades to a clear message, never a silent stop, never a wrong ring

| fault | what happens now | where it shows |
|---|---|---|
| AI timeout | Each call is bounded (GO NOW check 45 s, triage 25 s; the SDK retries once). A read stops after its deadline (75 s / 40 s) across the chain. After 3 failed reads in a row the AI pauses 5 min (live only) and the rules decide. | triage `fallback_reason` "AI error no model answered (TimeoutError...)"; the GO NOW card "GO NOW check unavailable (...) - the written rules found no reject (rules only)"; ai_raw row per failure; "AI paused until HH:MM after 3 failed reads" |
| 429 | Same path. One SDK retry, then the next model, then rules. | the same, with "429" in the reason |
| truncated answer (max_tokens) / refusal | Treated as an error, never a half answer. Next model, then rules. | "stop_reason max_tokens" in ai_raw and the reason |
| budget cap | No call. Rules only. | "AI budget reached - rules only (...)" |
| stale quote | Hard block "stale data: sh.X STALE". A live GO NOW steps to NOTHING at once (the 30-min GO NOW hold and the 10-min no-cancel hold do not apply to hard blocks). No ring. | the card's `blocked` |
| dead feed (prices old) | NIFTY older than 90 s = read-only session: every live call blocked, no new call, no ring. | `e0_day.read_only_why` "share prices not usable: ..." |
| dead feed (store not readable) / engine error | run.py writes `fault` into engine_state.json at once: "FEED DEAD - the store could not be read: ..." or "ENGINE STEP FAILED: ...", since, count, effect. The fault clears on the next good step. | `engine_state.json` -> fault |

Even with the AI down, the written GO NOW rules (B6) still reject bad cards. That is tested: a 9% spread card becomes NOTHING with AI timeouts.

**Tests**
    test_ai_down_go_now_says_so_and_rules_still_judge ... ok
    test_breaker_stops_waiting ... /home/globalbot/intraday/aispend.py:64: ResourceWarning: unclosed file <_io.TextIOWrapper name='/home/globalbot/intraday/data/aispend.json' mode='r' encoding='UTF-8'>
    test_budget_cap_message ... ok
    test_dead_feed_read_only_and_fault_file ... ok
    test_stale_quote_blocks_no_ring ... ok
    test_timeout_429_truncated_each_named ... ok

## Stale December quote (A5 gap) and the contract's lot (J5), added 20 Nov
- **The data:** v2/data/optquote.json already holds each leg's own quote time (`ts`, when gir-v2opt fetched it) and last trade time (`ltt`), plus the contract's `lot` and `sym`. The preview adapter now passes them into every oc row leg as `q_ts`, `ltt`, `lot`, `sym`: the main series, rows2 and exps. This is a preview.py change only; optquote.py and gir-v2opt are unchanged. (Applied after 15:35 under the edit lock; see BUILD_LOG.)
- **The rule: 60 s live.**
  - A premium older than 60 s fails the QUOTE AGE gate, reading "STALE Ns: the <exp> <strike> <side> premium is N s old (limit 60 s)". The card cannot be GO NOW.
  - The GO NOW check's written rules REJECT it (R4 "the premium is STALE Ns").
  - A kept strike (one strike per idea) is checked on its own quote time.
  - With no quote time in the store (replays) the gate says the age cannot be checked and does not block.
  - Config: OPT_QUOTE_MAX_S = 60.
- **J5 lot:** the plan uses the chosen contract's own lot when the store carries it, and the card says "lot N from the <exp> contract <sym>". Otherwise it uses the share's listed lot and says the contract's own lot is not in the store. Today's instrument file (data/instr/NFO_2026-11-20.csv): December option lots equal November for all 224 names; 35 names change lot in January.
- Tests (engine_next):
    test_plan_lot_is_the_contracts_own ... ok
    test_stale_premium_blocks_go_now ... ok

## The QUOTE AGE gate on today's frames (08:58-10:28 capture, engine 0.3, rules only)
**Measured** (the chain's own fetch time oc.<S>.opt.ts; the per-leg q_ts exists only from 15:41 today):
- 823 GO NOW candidate-steps; the gate held 765, on 179 ideas.
- 09:10 held 57 age median 63495 s, max 63548 s · over 1 h (yesterday's quote): 57
- 09:20 held 236 age median 63621 s, max 63731 s · over 1 h (yesterday's quote): 190
- 09:30 held 57 age median 70 s, max 82 s · over 1 h (yesterday's quote): 0
- 09:40 held 44 age median 71 s, max 86 s · over 1 h (yesterday's quote): 0
- 09:50 held 29 age median 73 s, max 89 s · over 1 h (yesterday's quote): 0
- 10:00 held 19 age median 69 s, max 84 s · over 1 h (yesterday's quote): 0
- 10:10 held 25 age median 74 s, max 87 s · over 1 h (yesterday's quote): 0
- 10:20 held 23 age median 68 s, max 90 s · over 1 h (yesterday's quote): 0

**The finding for Monday's open:** from 09:15 to about 09:30 most December quotes in the store were still YESTERDAY's (63,300-63,700 s old). gir-v2opt's first sweep had not reached them. The gate kept the engine from using a 17-hour-old premium, but the first 15 minutes had almost no tradable GO NOW. From 09:30 the held quotes were 60-90 s old (the REST tier).

**Simulated after the priority refresh** (v2/patches/optquote_priority.txt, not applied by me - gir-v2opt is not mine to restart):
- every GO NOW / MUST SEE name is re-quoted within ~6-20 s, so the 586 held later steps clear;
- an idea's first GO NOW step can still wait one pass (~20 s): 179 such steps on these frames;
- the 09:15-09:30 yesterday-quote problem needs gir-v2opt to sweep the whole December band once before 09:15 (or at 09:15:00). That is a gir-v2opt change for its owner.

Labels: the hold counts and ages are measured; the "after" is simulated. The real after-number comes from Monday's live run.
