# UPGRADE 5 - GDELT news history, first result (2026-11-21)

GDELT DOC API refuses this server (HTTP 429 on every call), so the raw daily event files are used, filtered to India rows (one row a day kept, zips deleted). Days so far: ['2024-01-01', '2026-11-20', 1037]; 1006 usable sessions; discovery before 2025-10-13, unseen after.

| signal (z vs 30 days) | target (next session) | discovery n / top fifth / bottom fifth / t | unseen n / top / bottom / t | verdict |
|---|---|---|---|---|
| biz_tone | gap | 603 / 0.132 / 0.036 / 1.01 | 403 / 0.044 / -0.063 / 1.06 | does not hold |
| biz_tone | ret | 603 / 0.067 / 0.144 / -0.62 | 403 / 0.003 / -0.061 / 0.43 | does not hold |
| biz_tone | abs_ret | 603 / 0.599 / 0.715 / -1.29 | 403 / 0.638 / 0.79 / -1.61 | does not hold |
| volume | gap | 603 / 0.086 / 0.056 / 0.31 | 403 / 0.014 / -0.079 / 1.0 | does not hold |
| volume | ret | 603 / 0.123 / 0.032 / 0.78 | 403 / -0.079 / -0.038 / -0.31 | does not hold |
| volume | abs_ret | 603 / 0.637 / 0.662 / -0.31 | 403 / 0.596 / 0.722 / -1.47 | does not hold |
| conflict | gap | 603 / 0.124 / -0.001 / 1.22 | 403 / -0.011 / -0.021 / 0.09 | does not hold |
| conflict | ret | 603 / 0.143 / 0.022 / 1.07 | 403 / -0.038 / -0.085 / 0.32 | does not hold |
| conflict | abs_ret | 603 / 0.559 / 0.728 / -2.17 | 403 / 0.766 / 0.67 / 1.06 | does not hold |

Company news spike (slug in India-event URLs, z >= 3) -> next-session |move| / ATR: discovery n 968 0.603 vs 0.55 (t 2.58); unseen n 635 0.621 vs 0.581 (t 1.72) -> does not hold

Caveat: GDELT events carry no company field; the slug match on source URLs is crude (a first word of the company name).
