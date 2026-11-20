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
