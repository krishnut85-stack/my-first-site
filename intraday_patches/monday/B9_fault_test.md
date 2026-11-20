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
