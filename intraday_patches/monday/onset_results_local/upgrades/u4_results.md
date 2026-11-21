# UPGRADE 4 - RESULTS-DAY REACTIONS (event library) - 2026-11-21

2665 reactions on 217 F&O shares (NSE board meetings with results, Nov 2023 - Nov 2026). Reaction = close before the meeting -> close of the first session after it. Typical reaction: median 1.09 x ATR, mean |move| 3.92%, 24% of reactions >= 2 ATR.

- SIZE: shares with big past reactions -> big next reactions? discovery (first half vs second half before Jul 2025): corr 0.155, t 2.72; UNSEEN (after Jul 2025, 210 shares): corr 0.209, top third 1.69 ATR vs bottom third 1.3 ATR, t 4.29 -> **HOLDS (size)**
- DIRECTION: past mostly-up shares -> next up 0.536; past mostly-down -> next up 0.458 (corr 0.162): no direction line is given.

Library: v2/models/artifacts/results_reactions.json; card line via checks.results_history(sym) - 'last N results: moves ...' (facts).
