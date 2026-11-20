# B7 - triage ranks, the limiter keeps the best, both lanes logged

**What changed**
- The triage answer carries a priority 1-10 per candidate (structured output). The prompt asks the AI to rank the candidates against each other.
- The opening cap (6) and the 5-min rate limit (3 new MUST SEE) keep the highest AI priority first, then the rules rank. Before, the limiter kept them in order of arrival / rules rank.
- Every card logs separately: `ai_lane` (the AI's own choice), `final_lane`, `lane_changed`, `ai_priority`, and `lane_why` naming the cap that changed it.
- A demoted card never rings (B3).

**Tests**
    test_limiter_keeps_the_ai_best_and_logs_both_lanes ... ok

The test gives 6 MUST SEE candidates whose rules rank rises as the AI priority falls. The limiter keeps the AI's top three (S0, S1, S2). The other three log ai_lane MUST SEE / final_lane WATCH / lane_changed true / "rate limit".
