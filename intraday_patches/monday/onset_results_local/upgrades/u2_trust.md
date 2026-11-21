# UPGRADE 2 - TRUST SCORE per source (2026-11-21)

History: old desk's scored calls 2026-11-08 to 2026-11-20 (10 days); trust learned on days to 2026-11-16, checked on the later unseen days. The v2 seats' scorecard starts Mon 23 Nov: not enough history yet for them - the scorer (v2/models/trust.py) is ready.

## by agent (14 sources) -> does not beat random yet

- unseen calls from the most-trusted third came true 51.0% (n 2560) vs the least-trusted third 48.5% (n 2232); z = 1.75
- Brier: trust 0.2494 vs flat base rate 0.2501 (base rate 48.1%)
- sources with >= 30 calls in both periods: 11, correlation of trust vs unseen hit rate 0.751

| source | trust (disc) | n disc | unseen hit | n unseen |
|---|---|---|---|---|
| rule:roof breaking - writers runnin | 0.536 | 136 | 0.685 | 146 |
| rule:big money buying futures | 0.525 | 84 | 0.675 | 114 |
| strikes | 0.497 | 2103 | 0.491 | 1579 |
| walls | 0.491 | 884 | 0.485 | 682 |
| rule:rising fast | 0.488 | 51 | 0.453 | 53 |
| auditor | 0.483 | 1913 | 0.480 | 1490 |
| futures | 0.475 | 390 | 0.499 | 849 |
| SUDDEN | 0.465 | 1101 | 0.497 | 1040 |
| rule:floor breaking - writers runni | 0.412 | 64 | 0.405 | 131 |
| rule:big money selling futures | 0.354 | 75 | 0.435 | 85 |
| reader | 0.345 | 182 | 0.402 | 127 |

## by agent+sector (248 sources) -> does not beat random yet

- unseen calls from the most-trusted third came true 49.6% (n 2184) vs the least-trusted third 48.4% (n 2131); z = 0.82
- Brier: trust 0.2506 vs flat base rate 0.2501 (base rate 48.1%)
- sources with >= 30 calls in both periods: 62, correlation of trust vs unseen hit rate -0.208

| source | trust (disc) | n disc | unseen hit | n unseen |
|---|---|---|---|---|
| strikes/auto-anc | 0.579 | 76 | 0.433 | 60 |
| walls/auto | 0.553 | 39 | 0.419 | 43 |
| walls/fmcg | 0.552 | 59 | 0.460 | 50 |
| auditor/auto-anc | 0.551 | 70 | 0.433 | 60 |
| SUDDEN/fmcg | 0.546 | 80 | 0.462 | 78 |
| walls/nbfc | 0.537 | 65 | 0.556 | 45 |
| SUDDEN/cement-infra | 0.532 | 47 | 0.469 | 49 |
| strikes/metals | 0.529 | 106 | 0.427 | 75 |
| strikes/auto | 0.528 | 108 | 0.500 | 76 |
| SUDDEN/auto | 0.527 | 59 | 0.500 | 52 |
| strikes/consumer | 0.524 | 189 | 0.521 | 142 |
| strikes/cement-infra | 0.523 | 115 | 0.440 | 91 |
| futures/banks | 0.515 | 53 | 0.519 | 81 |
| SUDDEN/chemicals | 0.511 | 38 | 0.412 | 34 |
| auditor/auto | 0.509 | 99 | 0.440 | 75 |
| auditor/consumer | 0.506 | 173 | 0.508 | 132 |
| auditor/fmcg | 0.501 | 123 | 0.471 | 102 |
| auditor/pharma | 0.501 | 119 | 0.473 | 91 |
| auditor/nbfc | 0.501 | 129 | 0.456 | 103 |
| strikes/pharma | 0.501 | 137 | 0.495 | 99 |

Caveat: calls of one day move together (one market), so z is optimistic; 10 days is a first look, not proof.
