# Chip shock: which F&O shares fall more in India the next day?

GIR research study, made 21 Nov 2026 16:37 IST, pure code (no AI calls). Research only - GIR places no orders. Script v2/kb/chip_shock_study.py.
History from Kite daily candles, 2021-11-15 -> 20 Nov 2026 (the 5-year store); minutes from Nov 2023. Everything below is a base rate, NOT PROVEN; n < 10 is marked.

## In plain words
- On India's next session after a SOX fall of 5%+ (n=33 US days), NIFTY's median close was -0.34% and it closed down 67% of the time. The typical F&O share did worse than NIFTY (median of all other F&O shares: -0.33 points vs NIFTY), so 'lagging NIFTY' alone is common on these days; the list below shows which chip names lagged MORE than the typical share.
- Fell MORE, whole history (median close minus NIFTY's, points): KPITTECH -1.36 (lagged 79%, n=33); KAYNES -1.26 (lagged 60%, n=25); TATAELXSI -0.96 (lagged 79%, n=33); LTIM -0.92 (lagged 64%, n=33); POWERINDIA -0.86 (lagged 64%, n=33).
- In 2026 only (n=12 events): CGPOWER -2.50 (lagged 67%, n=12); POWERINDIA -1.97 (lagged 75%, n=12); GVT&D -1.73 (lagged 75%, n=12); KAYNES -1.62 (lagged 75%, n=12); KPITTECH -1.31 (lagged 92%, n=12); PGEL -1.19 (lagged 83%, n=12). Least in 2026: PERSISTENT +0.23 (lagged 33%, n=12); COFORGE +0.33 (lagged 33%, n=12); DIXON +0.37 (lagged 33%, n=12); HCLTECH +0.39 (lagged 33%, n=12).
- The 2026 shift: the data-centre power names (CGPOWER, GVT&D, POWERINDIA, SIEMENS) and the EMS names KAYNES / PGEL lagged NIFTY more in 2026 than before; the IT-services names (COFORGE, PERSISTENT, MPHASIS, HCLTECH) and DIXON lagged less. That fits LINK_BOOK row 30 (the Nasdaq -> IT link weakened in 2026). 12 events - a pattern, NOT PROVEN.
- The low usually did NOT come in the first 15 minutes for these shares (minute data, Nov 2023 ->): e.g. KAYNES 11 of 25, DIXON 14 of 25, CGPOWER 9 of 25, TATAELXSI 3 of 25. Falls tended to extend during the day.
- Nasdaq <= -4.5% days are only 7 events (every row NOT PROVEN): NIFTY median -1.49%; KAYNES, COFORGE, LTIM and MPHASIS fell most vs NIFTY; ABB, BEL and SIEMENS held up.
- No call from this list alone. The desk rule stands: Monday PE only after 09:30, below VWAP and the opening-range low, sector confirming.

## Facts for Monday 23 Nov
- Fri 20 Nov US close: SOX (PHLX Semiconductor) -10.73%, Nasdaq Composite -5.28% (Yahoo). India had closed before most of that move: Yahoo's SOX futures had no trades in India hours that day, so the desk's '-2.4% in India hours' cannot be checked here; NQ futures were -1.16% at 14:45 IST. Monday is India's first full reaction.
- Friday 20 Nov in India (close vs 19 Nov close; VWAP from Kite spot minutes 09:15-15:14). Checked against the desk's note: CGPOWER -2.69% here (desk -2.57%), GVT&D -2.63% (desk -2.63%); DIXON +0.05% and below VWAP here (desk: +0.5%, above VWAP); PGEL +1.69%, KAYNES +0.74%, AMBER +0.64% closed above VWAP as the desk said.

| share | close | above VWAP? |
|---|---|---|
| KAYNES | +0.74% | yes |
| DIXON | +0.05% | no |
| PGEL | +1.69% | yes |
| AMBER | +0.64% | yes |
| CGPOWER | -2.69% | no |
| GVT&D | -2.63% | yes |
| POWERINDIA | -2.00% | yes |
| ABB | +0.01% | no |
| SIEMENS | +0.03% | yes |
| BEL | -0.69% | no |
| TATAELXSI | +3.49% | no |
| KPITTECH | -0.48% | no |
| HCLTECH | +0.58% | no |
| PERSISTENT | +3.56% | no |
| COFORGE | +2.51% | no |
| LTIM | +1.91% | no |
| MPHASIS | +1.99% | no |
| NIFTY | +1.12% | n/a |
| BANKNIFTY | +2.49% | n/a |
| NIFTY_IT | +1.30% | n/a |

## The ranked list: SOX <= -5% days, India's next session (n = 33 events: 21 before 2026, 12 in 2026)
Ranked by the median of (share's close vs previous close) minus (NIFTY's) - most negative = fell MORE than NIFTY. 'Lagged NIFTY' = share of events it closed below NIFTY. F&O percentile = where that median sits among all 201 other F&O shares (0 = worst).

| rank | share | group | n | median gap | median low | median close | median vs NIFTY | lagged NIFTY | closed down | worst (date) | low in first 15 min | F&O percentile | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | KPITTECH | chip design / ER&D | 33 | -0.55% | -3.03% | -1.11% | -1.36 | 79% | 82% | -7.67% (2026-07-30) | 6 of 25 | 2 | measured - NOT PROVEN |
| 2 | KAYNES | EMS / semis | 25 | -0.13% | -3.13% | -1.59% | -1.26 | 60% | 64% | -11.52% (2025-01-28) | 11 of 25 | 3 | measured - NOT PROVEN |
| 3 | TATAELXSI | chip design / ER&D | 33 | -0.26% | -1.70% | -1.05% | -0.96 | 79% | 82% | -5.70% (2022-05-10) | 3 of 25 | 6 | measured - NOT PROVEN |
| 4 | LTIM (LTM) | chip design / ER&D | 33 | -0.39% | -1.99% | -1.23% | -0.92 | 64% | 67% | -5.27% (2022-05-19) | 9 of 25 | 7 | measured - NOT PROVEN |
| 5 | POWERINDIA | chip plant + data-centre power | 33 | -0.43% | -3.28% | -1.46% | -0.86 | 64% | 73% | -11.98% (2025-01-28) | 6 of 25 | 9 | measured - NOT PROVEN |
| 6 | MPHASIS | chip design / ER&D | 33 | -0.47% | -2.09% | -0.63% | -0.85 | 67% | 58% | -7.16% (2022-05-19) | 8 of 25 | 9 | measured - NOT PROVEN |
| 7 | GVT&D | chip plant + data-centre power | 33 | -0.62% | -3.80% | -1.49% | -0.77 | 58% | 61% | -8.74% (2026-07-03) | 10 of 25 | 16 | measured - NOT PROVEN |
| 8 | DIXON | EMS / semis | 33 | -0.28% | -2.31% | -0.71% | -0.63 | 55% | 64% | -5.48% (2025-01-28) | 14 of 25 | 23 | measured - NOT PROVEN |
| 9 | SIEMENS | chip plant + data-centre power | 32 | +0.00% | -2.34% | -1.29% | -0.62 | 59% | 62% | -6.11% (2025-04-04) | 8 of 24 | 23 | measured - NOT PROVEN |
| 10 | BEL | chip plant + data-centre power | 33 | -0.24% | -1.71% | -0.68% | -0.60 | 58% | 58% | -5.30% (2026-09-15) | 13 of 25 | 26 | measured - NOT PROVEN |
| 11 | PERSISTENT | chip design / ER&D | 33 | -0.75% | -1.88% | -0.79% | -0.54 | 58% | 67% | -11.22% (2026-06-29) | 8 of 25 | 34 | measured - NOT PROVEN |
| 12 | ABB | chip plant + data-centre power | 33 | -0.36% | -2.62% | -1.10% | -0.51 | 55% | 64% | -5.02% (2026-10-23) | 11 of 25 | 38 | measured - NOT PROVEN |
| 13 | AMBER | EMS / semis | 33 | -0.03% | -2.67% | -0.74% | -0.47 | 61% | 64% | -6.73% (2025-04-07) | 12 of 25 | 40 | measured - NOT PROVEN |
| 14 | PGEL | EMS / semis | 33 | -0.14% | -3.25% | -0.41% | -0.33 | 64% | 61% | -11.41% (2025-01-28) | 8 of 25 | 51 | measured - NOT PROVEN |
| 15 | COFORGE | chip design / ER&D | 33 | -0.43% | -2.26% | -0.43% | -0.32 | 61% | 67% | -7.68% (2025-04-04) | 9 of 25 | 52 | measured - NOT PROVEN |
| 16 | CGPOWER | chip plant + data-centre power | 33 | -0.79% | -2.69% | -1.34% | -0.07 | 55% | 61% | -6.97% (2026-07-03) | 9 of 25 | 75 | measured - NOT PROVEN |
| 17 | HCLTECH | chip design / ER&D | 33 | -0.73% | -1.38% | -0.05% | +0.03 | 48% | 52% | -5.99% (2022-05-19) | 13 of 25 | 82 | measured - NOT PROVEN |
| - | LTTS | chip design / ER&D | 0 | | | | | | | | | | not on the F&O list |

Controls on the same days:

| control | n | median gap | median close | closed down | worst |
|---|---|---|---|---|---|
| NIFTY | 33 | -0.32% | -0.34% | 67% | -3.24% (2025-04-07) |
| BANKNIFTY | 33 | -0.38% | -0.18% | 58% | -3.19% (2025-04-07) |
| NIFTY_IT | 33 | -0.58% | -0.78% | 64% | -5.74% (2022-05-19) |
| all other F&O shares (201): median of each share's median | | | -0.60% (vs NIFTY -0.33) | 64% | |
| random 20 F&O shares (seed 42) | | | -0.80% (vs NIFTY -0.38) | 68.5% | |

The 10 F&O shares that fell most vs NIFTY on these days (n >= 10), for comparison: ENRIN -2.72 (n=14), IDEA -1.80 (n=33), SYRMA -1.55 (n=28), NATIONALUM -1.43 (n=33), INOXWIND -1.41 (n=33), BSE -1.27 (n=33), ANGELONE -1.25 (n=33), TMPV -1.24 (n=33), BLUESTARCO -1.16 (n=33), VOLTAS -1.16 (n=33).

## Before 2026 vs 2026 (LINK_BOOK row 30: the Nasdaq -> IT link broke in 2026)

| share | before 2026: n, median vs NIFTY, lagged | 2026: n, median vs NIFTY, lagged |
|---|---|---|
| KPITTECH | 21, -1.47, 71% | 12, -1.31, 92% |
| KAYNES | 13, +0.36, 46% | 12, -1.62, 75% |
| TATAELXSI | 21, -0.96, 76% | 12, -0.86, 83% |
| LTIM | 21, -0.99, 67% | 12, -0.43, 58% |
| POWERINDIA | 21, -0.57, 57% | 12, -1.97, 75% |
| MPHASIS | 21, -1.62, 76% | 12, +0.01, 50% |
| GVT&D | 21, +0.76, 48% | 12, -1.73, 75% |
| DIXON | 21, -0.92, 67% | 12, +0.37, 33% |
| SIEMENS | 20, -0.15, 50% | 12, -0.98, 75% |
| BEL | 21, -0.60, 57% | 12, -0.57, 58% |
| PERSISTENT | 21, -0.65, 71% | 12, +0.23, 33% |
| ABB | 21, -0.51, 57% | 12, -0.26, 50% |
| AMBER | 21, -0.47, 57% | 12, -0.45, 67% |
| PGEL | 21, -0.15, 52% | 12, -1.19, 83% |
| COFORGE | 21, -2.00, 76% | 12, +0.33, 33% |
| CGPOWER | 21, +0.25, 48% | 12, -2.50, 67% |
| HCLTECH | 21, -0.20, 57% | 12, +0.39, 33% |
| NIFTY_IT | 21, -0.64, 76% | 12, +0.03, 50% |
| BANKNIFTY | 21, +0.20, 33% | 12, -0.28, 58% |

SOX <= -5% events used (US date -> India date, SOX %, Nasdaq %): 2022-05-05 -> 2022-05-06 (-5.00 / -4.99); 2022-05-09 -> 2022-05-10 (-5.13 / -4.29); 2022-05-18 -> 2022-05-19 (-5.17 / -4.73); 2022-06-13 -> 2022-06-14 (-5.61 / -4.68); 2022-06-16 -> 2022-06-17 (-6.24 / -4.08); 2022-08-26 -> 2022-08-29 (-5.81 / -3.94); 2022-09-13 -> 2022-09-14 (-6.18 / -5.16); 2022-10-07 -> 2022-10-10 (-6.06 / -3.80); 2024-07-17 -> 2024-07-18 (-6.81 / -2.77); 2024-07-24 -> 2024-07-25 (-5.41 / -3.64); 2024-08-01 -> 2024-08-02 (-7.14 / -2.30); 2024-08-02 -> 2024-08-05 (-5.18 / -2.43); 2024-09-03 -> 2024-09-04 (-7.75 / -3.26); 2024-10-15 -> 2024-10-16 (-5.28 / -1.01); 2025-01-27 -> 2025-01-28 (-9.15 / -3.07); 2025-02-27 -> 2025-02-28 (-6.09 / -2.78); 2025-04-03 -> 2025-04-04 (-9.88 / -5.97); 2025-04-04 -> 2025-04-07 (-7.60 / -5.82); 2025-04-10 -> 2025-04-11 (-7.97 / -4.31); 2025-10-10 -> 2025-10-13 (-6.32 / -3.56); 2025-12-12 -> 2025-12-15 (-5.10 / -1.69); 2026-06-05 -> 2026-06-08 (-10.26 / -4.18); 2026-06-16 -> 2026-06-17 (-5.71 / -1.15); 2026-06-23 -> 2026-06-24 (-7.87 / -2.21); 2026-06-26 -> 2026-06-29 (-5.29 / -0.24); 2026-07-01 -> 2026-07-02 (-6.27 / -0.66); 2026-07-02 -> 2026-07-03 (-5.44 / -0.80); 2026-07-29 -> 2026-07-30 (-5.33 / -1.74); 2026-09-14 -> 2026-09-15 (-5.86 / -0.56); 2026-10-22 -> 2026-10-23 (-6.72 / -2.60); 2026-10-30 -> 2026-11-02 (-7.20 / -2.86); 2026-11-05 -> 2026-11-06 (-12.25 / -5.52); 2026-11-16 -> 2026-11-17 (-5.28 / -2.49).

## Same table for Nasdaq <= -4.5% days (n = 7 events)

| rank | share | n | median gap | median close | median vs NIFTY | lagged NIFTY | closed down | worst (date) | low in first 15 min | status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | KAYNES | 3 | -0.99% | -4.53% | -3.82 | 100% | 100% | -6.18% (2025-04-04) | 1 of 3 | NOT PROVEN (n < 10) |
| 2 | COFORGE | 7 | -2.94% | -4.05% | -3.44 | 100% | 100% | -7.68% (2025-04-04) | 0 of 3 | NOT PROVEN (n < 10) |
| 3 | LTIM | 7 | -1.79% | -3.34% | -2.62 | 71% | 86% | -5.27% (2022-05-19) | 1 of 3 | NOT PROVEN (n < 10) |
| 4 | MPHASIS | 7 | -2.55% | -2.98% | -2.45 | 86% | 71% | -7.16% (2022-05-19) | 0 of 3 | NOT PROVEN (n < 10) |
| 5 | PGEL | 7 | -1.95% | -0.97% | -2.39 | 57% | 71% | -6.96% (2025-04-04) | 1 of 3 | NOT PROVEN (n < 10) |
| 6 | PERSISTENT | 7 | -2.67% | -2.24% | -2.34 | 71% | 86% | -6.25% (2022-05-19) | 1 of 3 | NOT PROVEN (n < 10) |
| 7 | GVT&D | 7 | -2.77% | -3.06% | -1.89 | 71% | 71% | -7.63% (2025-04-07) | 1 of 3 | NOT PROVEN (n < 10) |
| 8 | KPITTECH | 7 | -2.59% | -2.72% | -1.89 | 71% | 86% | -6.37% (2025-04-04) | 1 of 3 | NOT PROVEN (n < 10) |
| 9 | AMBER | 7 | -0.97% | -2.76% | -1.77 | 86% | 100% | -6.73% (2025-04-07) | 1 of 3 | NOT PROVEN (n < 10) |
| 10 | TATAELXSI | 7 | -2.08% | -2.09% | -1.55 | 86% | 100% | -4.91% (2025-04-07) | 0 of 3 | NOT PROVEN (n < 10) |
| 11 | HCLTECH | 7 | -1.73% | -2.45% | -1.35 | 86% | 71% | -5.99% (2022-05-19) | 1 of 3 | NOT PROVEN (n < 10) |
| 12 | CGPOWER | 7 | -2.08% | -2.77% | -1.14 | 71% | 71% | -6.62% (2025-04-04) | 1 of 3 | NOT PROVEN (n < 10) |
| 13 | DIXON | 7 | -2.14% | -2.20% | -1.11 | 71% | 86% | -4.43% (2025-04-07) | 2 of 3 | NOT PROVEN (n < 10) |
| 14 | POWERINDIA | 7 | -1.96% | -2.05% | -0.81 | 71% | 86% | -4.94% (2025-04-07) | 1 of 3 | NOT PROVEN (n < 10) |
| 15 | ABB | 7 | -1.46% | -0.69% | +0.19 | 43% | 71% | -4.34% (2025-04-04) | 2 of 3 | NOT PROVEN (n < 10) |
| 16 | BEL | 7 | -1.15% | -2.38% | +0.27 | 43% | 57% | -2.87% (2022-05-06) | 2 of 3 | NOT PROVEN (n < 10) |
| 17 | SIEMENS | 6 | -1.12% | -0.79% | +0.67 | 33% | 50% | -6.11% (2025-04-04) | 1 of 2 | NOT PROVEN (n < 10) |
| ctrl | NIFTY | 7 | -1.60% | -1.49% | | | 86% | -3.24% (2025-04-07) | | |
| ctrl | BANKNIFTY | 7 | -1.38% | -0.28% | | | 71% | -3.19% (2025-04-07) | | |
| ctrl | NIFTY_IT | 7 | -2.00% | -2.51% | | | 71% | -5.74% (2022-05-19) | | |

Events: 2022-05-05 -> 2022-05-06 (SOX -5.00 / Nasdaq -4.99); 2022-05-18 -> 2022-05-19 (SOX -5.17 / Nasdaq -4.73); 2022-06-13 -> 2022-06-14 (SOX -5.61 / Nasdaq -4.68); 2022-09-13 -> 2022-09-14 (SOX -6.18 / Nasdaq -5.16); 2025-04-03 -> 2025-04-04 (SOX -9.88 / Nasdaq -5.97); 2025-04-04 -> 2025-04-07 (SOX -7.60 / Nasdaq -5.82); 2026-11-05 -> 2026-11-06 (SOX -12.25 / Nasdaq -5.52).

## Single cases
**DeepSeek, India Mon 27 Jan 2025 (same day, BEFORE the US fell; SOX -9.15% that night)** - gap / low / close vs previous close:

| share | gap | low | close |
|---|---|---|---|
| KAYNES | -1.57% | -8.06% | -6.40% |
| DIXON | -2.15% | -2.76% | -0.98% |
| PGEL | -3.97% | -7.16% | -2.68% |
| AMBER | -0.69% | -5.86% | -4.90% |
| CGPOWER | -0.42% | -5.25% | -4.04% |
| GVT&D | -1.04% | -5.00% | -5.00% |
| POWERINDIA | +0.00% | -5.05% | -4.20% |
| ABB | -1.28% | -2.75% | -1.55% |
| SIEMENS | -0.33% | -3.40% | -1.57% |
| BEL | -1.17% | -3.09% | -2.67% |
| TATAELXSI | -0.83% | -3.84% | -3.40% |
| KPITTECH | -1.73% | -3.49% | -1.62% |
| HCLTECH | -1.00% | -4.77% | -4.51% |
| PERSISTENT | -0.97% | -5.39% | -4.71% |
| COFORGE | -1.52% | -5.25% | -4.68% |
| LTIM | -2.38% | -6.30% | -5.21% |
| MPHASIS | -1.53% | -2.70% | -2.40% |
| NIFTY | -0.66% | -1.32% | -1.14% |
| BANKNIFTY | -1.01% | -1.08% | -0.63% |
| NIFTY_IT | -1.23% | -3.59% | -3.36% |

**DeepSeek, India Tue 28 Jan 2025 (the next session after the US fall)** - gap / low / close vs previous close:

| share | gap | low | close |
|---|---|---|---|
| KAYNES | -7.92% | -20.00% | -11.52% |
| DIXON | -0.22% | -6.62% | -5.48% |
| PGEL | +0.14% | -17.76% | -11.41% |
| AMBER | +0.13% | -8.40% | +0.63% |
| CGPOWER | +0.60% | -13.05% | -3.44% |
| GVT&D | -1.50% | -5.00% | -5.00% |
| POWERINDIA | -0.11% | -19.49% | -11.98% |
| ABB | +0.27% | -2.86% | -1.39% |
| SIEMENS | +2.52% | -3.24% | -1.78% |
| BEL | +0.21% | -3.90% | -1.79% |
| TATAELXSI | -0.10% | -1.27% | -0.50% |
| KPITTECH | -0.81% | -3.96% | -3.26% |
| HCLTECH | +0.00% | -1.22% | -1.09% |
| PERSISTENT | -1.01% | -3.13% | -2.49% |
| COFORGE | -0.43% | -4.15% | -3.44% |
| LTIM | -0.63% | -1.33% | -0.36% |
| MPHASIS | -0.42% | -2.39% | -1.82% |
| NIFTY | +0.58% | +0.12% | +0.56% |
| BANKNIFTY | +1.20% | +0.80% | +1.67% |
| NIFTY_IT | +0.09% | -0.78% | -0.57% |

**Fri 6 Nov 2026** (US 5 Nov: SOX -12.25%, Nasdaq -5.52%) - gap / low / close / vs NIFTY:

| share | gap | low | close | vs NIFTY | low minute |
|---|---|---|---|---|---|
| KAYNES | -0.99% | -2.51% | -1.81% | -3.82 | 105 |
| DIXON | -0.84% | -1.63% | +0.07% | -1.94 | 11 |
| PGEL | -0.76% | -3.76% | -0.55% | -2.56 | 90 |
| AMBER | -0.73% | -3.60% | -2.76% | -4.77 | 126 |
| CGPOWER | -2.99% | -9.28% | -4.43% | -6.44 | 87 |
| GVT&D | -3.50% | -6.33% | -3.06% | -5.07 | 47 |
| POWERINDIA | -4.26% | -5.27% | -1.42% | -3.43 | 47 |
| ABB | -2.01% | -3.02% | +2.20% | +0.19 | 1 |
| SIEMENS | -0.93% | -3.69% | +3.73% | +1.72 | 3 |
| BEL | -1.29% | -2.43% | +0.23% | -1.78 | 12 |
| TATAELXSI | +0.57% | -2.09% | -1.66% | -3.67 | 230 |
| KPITTECH | +0.96% | -0.85% | +0.12% | -1.89 | 293 |
| HCLTECH | +1.20% | -0.24% | +0.66% | -1.35 | 316 |
| PERSISTENT | +1.07% | -1.25% | -0.92% | -2.93 | 359 |
| COFORGE | +1.01% | -1.11% | -0.14% | -2.15 | 212 |
| LTIM | +2.44% | -1.65% | -1.25% | -3.26 | 302 |
| MPHASIS | +4.59% | +0.40% | +0.40% | -1.61 | 358 |
| NIFTY | +0.01% | -0.61% | +2.01% | +0.00 | n/a |
| BANKNIFTY | +0.07% | -0.78% | +2.27% | +0.26 | n/a |
| NIFTY_IT | +1.32% | -0.34% | +0.43% | -1.58 | n/a |

**Mon 23 Nov 2026** (US 20 Nov: SOX -10.73%, Nasdaq -5.28%): the next case - no India outcome yet.

## Data and limits
- F&O list: NSE F&O bhavcopy of 20 Nov 2026 (218 share futures). Not on it: LTTS. LTIM trades as LTM there (LTIMindtree) and is measured as LTM.
- Shares listed or added later have fewer events (n differs by share). SIEMENS 7 Apr 2025 is dropped (Siemens Energy demerger, not adjusted in the Kite candles).
- 'Low in the first 15 minutes' uses Kite spot minutes (Nov 2023 ->), which stop at 15:14; a low in 15:15-15:29 would be missed.
- Some worst days are price-band limits (e.g. GVT&D -5.00% on 27-28 Jan 2025 = its 5% band), so the true selling was larger; some worst days may include company news.
- Events cluster (2022, Jul-Aug 2024, Apr 2025, Jun-Jul 2026, Oct-Nov 2026): neighbouring events are not independent.
- The ranking is by history only. The desk rule stands: no call from this list on its own (Monday PE only after 09:30, below VWAP and the opening-range low, sector confirming).
