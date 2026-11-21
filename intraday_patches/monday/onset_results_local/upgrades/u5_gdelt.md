# UPGRADE 5 - GDELT news history, first result (2026-11-21)

GDELT DOC API refuses this server (HTTP 429 on every call), so the raw daily event files are used, filtered to India rows (one row a day kept, zips deleted). Days so far: ['2025-07-22', '2026-11-20', 487]; 456 usable sessions; discovery before 2026-05-21, unseen after.

| signal (z vs 30 days) | target (next session) | discovery n / top fifth / bottom fifth / t | unseen n / top / bottom / t | verdict |
|---|---|---|---|---|
| biz_tone | gap | 273 / 0.124 / -0.146 / 2.09 | 183 / -0.057 / 0.11 / -1.48 | does not hold |
| biz_tone | ret | 273 / 0.177 / -0.117 / 1.69 | 183 / -0.151 / 0.1 / -1.31 | does not hold |
| biz_tone | abs_ret | 273 / 0.574 / 0.766 / -1.62 | 183 / 0.604 / 0.703 / -0.86 | does not hold |
| volume | gap | 273 / -0.003 / -0.108 / 0.99 | 183 / 0.052 / 0.123 / -0.59 | does not hold |
| volume | ret | 273 / -0.065 / 0.011 / -0.49 | 183 / -0.034 / 0.054 / -0.47 | does not hold |
| volume | abs_ret | 273 / 0.514 / 0.685 / -1.71 | 183 / 0.704 / 0.585 / 1.08 | does not hold |
| conflict | gap | 273 / -0.003 / -0.119 / 0.8 | 183 / -0.072 / 0.167 / -2.06 | does not hold |
| conflict | ret | 273 / 0.025 / -0.086 / 0.61 | 183 / -0.179 / 0.069 / -1.39 | does not hold |
| conflict | abs_ret | 273 / 0.796 / 0.645 / 1.28 | 183 / 0.642 / 0.611 / 0.29 | does not hold |

Company news spike (slug in India-event URLs, z >= 3) -> next-session |move| / ATR: discovery n 430 0.641 vs 0.57 (t 2.37); unseen n 301 0.603 vs 0.587 (t 0.46) -> does not hold

Caveat: GDELT events carry no company field; the slug match on source URLs is crude (a first word of the company name).
