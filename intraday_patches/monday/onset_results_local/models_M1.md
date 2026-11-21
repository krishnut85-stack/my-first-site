# M1 NEXT-DAY GAP - walk-forward results (2026-11-21)

Target: P(next session opens above today's close). Train on older years only, test once on each later unseen year, Platt-calibrated.
PASS = on the unseen years pooled: accuracy beats the base rate (training years' majority side) with one-sided p < 0.025, Brier beats the base rate's, and it beats the base rate in at least half of the years. Else: OFF the cards, predict() says "no edge".
Best of logistic regression (lr) / gradient-boosted trees (gbt) shown; both are in models_M1.json.

## Summary

| set | decision time | n days | model | unseen acc | base rate | Brier vs base | p | years beaten | verdict |
|---|---|---|---|---|---|---|---|---|---|
| NIFTY_daily | 14:45 IST | 4131 | lr | 66.6% (n 2931) | 66.6% | 0.2256 vs 0.2241 | 0.5074 | 0/12 | **no edge** |
| NIFTY_daily | evening / 07:30 IST | 4131 | lr | 73.5% (n 2931) | 66.6% | 0.1816 vs 0.2241 | 0.0000 | 12/12 | **PASS** |
| BANKNIFTY_daily | 14:45 IST | 4147 | lr | 62.0% (n 2937) | 62.0% | 0.2369 vs 0.2364 | 0.5073 | 0/12 | **no edge** |
| BANKNIFTY_daily | evening / 07:30 IST | 4147 | gbt | 69.6% (n 2937) | 62.0% | 0.1973 vs 0.2364 | 0.0000 | 12/12 | **PASS** |
| NIFTY_kite | 14:45 IST | 1224 | lr | 61.0% (n 963) | 61.0% | 0.2405 vs 0.2398 | 0.5130 | 0/4 | **no edge** |
| NIFTY_kite | evening / 07:30 IST | 1224 | gbt | 69.3% (n 963) | 61.0% | 0.1983 vs 0.2398 | 0.0000 | 4/4 | **PASS** |
| BANKNIFTY_kite | 14:45 IST | 1224 | lr | 56.7% (n 963) | 56.7% | 0.2482 vs 0.2472 | 0.5122 | 0/4 | **no edge** |
| BANKNIFTY_kite | evening / 07:30 IST | 1224 | gbt | 65.6% (n 963) | 56.7% | 0.2181 vs 0.2472 | 0.0000 | 4/4 | **PASS** |
| IT_kite | 14:45 IST | 1224 | lr | 58.9% (n 963) | 58.9% | 0.2441 vs 0.2441 | 0.5130 | 0/4 | **no edge** |
| IT_kite | evening / 07:30 IST | 1224 | gbt | 68.7% (n 963) | 58.9% | 0.2059 vs 0.2441 | 0.0000 | 4/4 | **PASS** |
| PVT_BANK_kite | 14:45 IST | 1224 | lr | 55.9% (n 963) | 55.9% | 0.2494 vs 0.2482 | 0.5127 | 0/4 | **no edge** |
| PVT_BANK_kite | evening / 07:30 IST | 1224 | gbt | 64.4% (n 963) | 55.9% | 0.2178 vs 0.2482 | 0.0000 | 4/4 | **PASS** |
| PSU_BANK_kite | 14:45 IST | 1224 | lr | 70.9% (n 963) | 70.9% | 0.2119 vs 0.2113 | 0.5145 | 0/4 | **no edge** |
| PSU_BANK_kite | evening / 07:30 IST | 1224 | lr | 72.4% (n 963) | 70.9% | 0.1892 vs 0.2113 | 0.1693 | 3/4 | **no edge** |
| FIN_SERVICE_kite | 14:45 IST | 1224 | lr | 56.2% (n 963) | 56.2% | 0.2484 vs 0.2474 | 0.5124 | 0/4 | **no edge** |
| FIN_SERVICE_kite | evening / 07:30 IST | 1224 | gbt | 66.7% (n 963) | 56.2% | 0.2120 vs 0.2474 | 0.0000 | 4/4 | **PASS** |
| PHARMA_kite | 14:45 IST | 1224 | lr | 70.4% (n 963) | 70.4% | 0.2117 vs 0.2108 | 0.5140 | 0/4 | **no edge** |
| PHARMA_kite | evening / 07:30 IST | 1224 | lr | 74.6% (n 963) | 70.4% | 0.1835 vs 0.2108 | 0.0026 | 4/4 | **PASS** |
| FMCG_kite | 14:45 IST | 1224 | lr | 67.8% (n 963) | 67.8% | 0.2232 vs 0.2211 | 0.5137 | 0/4 | **no edge** |
| FMCG_kite | evening / 07:30 IST | 1224 | lr | 71.0% (n 963) | 67.8% | 0.1992 vs 0.2211 | 0.0177 | 4/4 | **PASS** |
| AUTO_kite | 14:45 IST | 1224 | lr | 69.2% (n 963) | 69.2% | 0.2199 vs 0.2177 | 0.5142 | 0/4 | **no edge** |
| AUTO_kite | evening / 07:30 IST | 1224 | gbt | 72.9% (n 963) | 69.2% | 0.1874 vs 0.2177 | 0.0066 | 4/4 | **PASS** |
| METAL_kite | 14:45 IST | 1224 | lr | 70.6% (n 963) | 70.6% | 0.2131 vs 0.2126 | 0.5141 | 0/4 | **no edge** |
| METAL_kite | evening / 07:30 IST | 1224 | gbt | 74.2% (n 963) | 70.6% | 0.1802 vs 0.2126 | 0.0073 | 4/4 | **PASS** |
| REALTY_kite | 14:45 IST | 1224 | lr | 68.7% (n 963) | 68.7% | 0.2189 vs 0.2177 | 0.5135 | 0/4 | **no edge** |
| REALTY_kite | evening / 07:30 IST | 1224 | gbt | 73.2% (n 963) | 68.7% | 0.1874 vs 0.2177 | 0.0016 | 4/4 | **PASS** |
| ENERGY_kite | 14:45 IST | 1224 | lr | 71.3% (n 963) | 71.3% | 0.2101 vs 0.2083 | 0.5141 | 0/4 | **no edge** |
| ENERGY_kite | evening / 07:30 IST | 1224 | lr | 74.4% (n 963) | 71.3% | 0.1778 vs 0.2083 | 0.0211 | 4/4 | **PASS** |
| NIFTY_intraday | 14:45 IST | 588 | lr | 52.7% (n 465) | 53.5% | 0.2518 vs 0.2531 | 0.6624 | 0/2 | **no edge** |
| NIFTY_intraday | evening / 07:30 IST | 588 | lr | 68.6% (n 465) | 53.5% | 0.2068 vs 0.2531 | 0.0000 | 2/2 | **PASS** |
| BANKNIFTY_intraday | 14:45 IST | 588 | gbt | 54.4% (n 465) | 50.5% | 0.2460 vs 0.2503 | 0.0524 | 2/2 | **no edge** |
| BANKNIFTY_intraday | evening / 07:30 IST | 588 | lr | 66.0% (n 465) | 50.5% | 0.2182 vs 0.2503 | 0.0000 | 2/2 | **PASS** |

## By unseen year (chosen model)

**NIFTY_daily 1445** (lr, data 2010-02-03 to 2026-11-19)  
year: 2015 n244 66% vs 66% · 2016 n244 68% vs 68% · 2017 n248 75% vs 75% · 2018 n245 71% vs 71% · 2019 n241 71% vs 71% · 2020 n250 71% vs 71% · 2021 n248 72% vs 72% · 2022 n248 60% vs 60% · 2023 n246 68% vs 68% · 2024 n249 66% vs 66% · 2025 n249 59% vs 59% · 2026 n219 49% vs 49%  
top inputs: rsi14_prev(+), dist20_prev(-), ndx_prev(-), asia_min_D(+), asia_D(-), usdinr_prev(-)  
expected size (ridge): MAE 0.36 / 0.36 / 0.23 / 0.33 / 0.25 / 0.77 / 0.39 / 0.56 / 0.26 / 0.30 / 0.29 / 0.46 vs naive 0.35 / 0.36 / 0.23 / 0.33 / 0.25 / 0.76 / 0.38 / 0.56 / 0.25 / 0.30 / 0.29 / 0.46 (pct points) by year

**NIFTY_daily 0730** (lr, data 2010-02-03 to 2026-11-19)  
year: 2015 n244 72% vs 66% · 2016 n244 72% vs 68% · 2017 n248 78% vs 75% · 2018 n245 77% vs 71% · 2019 n241 74% vs 71% · 2020 n250 78% vs 71% · 2021 n248 77% vs 72% · 2022 n248 80% vs 60% · 2023 n246 78% vs 68% · 2024 n249 70% vs 66% · 2025 n249 66% vs 59% · 2026 n219 58% vs 49%  
top inputs: spx_night(+), rsi14_D(+), rsi14_prev(-), asia_D(-), spx_prev(+), ndx_night(+)  
expected size (ridge): MAE 0.28 / 0.31 / 0.22 / 0.28 / 0.26 / 0.66 / 0.33 / 0.38 / 0.21 / 0.28 / 0.30 / 0.40 vs naive 0.35 / 0.36 / 0.23 / 0.33 / 0.25 / 0.76 / 0.38 / 0.56 / 0.25 / 0.30 / 0.29 / 0.46 (pct points) by year

**BANKNIFTY_daily 1445** (lr, data 2010-02-03 to 2026-11-19)  
year: 2015 n246 60% vs 60% · 2016 n246 64% vs 64% · 2017 n248 72% vs 72% · 2018 n246 62% vs 62% · 2019 n242 68% vs 68% · 2020 n250 66% vs 66% · 2021 n248 66% vs 66% · 2022 n248 58% vs 58% · 2023 n246 66% vs 66% · 2024 n249 58% vs 58% · 2025 n249 53% vs 53% · 2026 n219 48% vs 48%  
top inputs: dist20_prev(-), rsi14_prev(+), nights(+), asia_min_D(+), asia_D(-), friday(-)  
expected size (ridge): MAE 0.47 / 0.48 / 0.29 / 0.39 / 0.33 / 1.03 / 0.52 / 0.65 / 0.33 / 0.37 / 0.33 / 0.50 vs naive 0.47 / 0.48 / 0.29 / 0.39 / 0.32 / 1.01 / 0.52 / 0.65 / 0.32 / 0.37 / 0.33 / 0.50 (pct points) by year

**BANKNIFTY_daily 0730** (gbt, data 2010-02-03 to 2026-11-19)  
year: 2015 n246 73% vs 60% · 2016 n246 69% vs 64% · 2017 n248 73% vs 72% · 2018 n246 70% vs 62% · 2019 n242 70% vs 68% · 2020 n250 76% vs 66% · 2021 n248 72% vs 66% · 2022 n248 77% vs 58% · 2023 n246 74% vs 66% · 2024 n249 61% vs 58% · 2025 n249 61% vs 53% · 2026 n219 58% vs 48%  
top inputs: spx_night, ndx_night, asia_D, us10y_night, asia_min_D, idx_D_ret  
expected size (ridge): MAE 0.40 / 0.44 / 0.28 / 0.37 / 0.34 / 0.88 / 0.43 / 0.48 / 0.28 / 0.37 / 0.37 / 0.46 vs naive 0.47 / 0.48 / 0.29 / 0.39 / 0.32 / 1.01 / 0.52 / 0.65 / 0.32 / 0.37 / 0.33 / 0.50 (pct points) by year

**NIFTY_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 68% vs 68% · 2024 n249 66% vs 66% · 2025 n249 59% vs 59% · 2026 n219 49% vs 49%  
top inputs: asia_D(-), asia_min_D(+), usdinr_prev(-), spx_prev(-), friday(-), nights(+)  
expected size (ridge): MAE 0.29 / 0.31 / 0.30 / 0.47 vs naive 0.26 / 0.30 / 0.28 / 0.45 (pct points) by year

**NIFTY_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 75% vs 68% · 2024 n249 70% vs 66% · 2025 n249 66% vs 59% · 2026 n219 65% vs 49%  
top inputs: spx_night, asia_D, ndx_night, idx_D_ret, idx_prev_ret, us10y_night  
expected size (ridge): MAE 0.24 / 0.29 / 0.28 / 0.39 vs naive 0.26 / 0.30 / 0.28 / 0.45 (pct points) by year

**BANKNIFTY_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 66% vs 66% · 2024 n249 58% vs 58% · 2025 n249 53% vs 53% · 2026 n219 48% vs 48%  
top inputs: nights(+), friday(-), asia_D(-), spx_prev(-), gap_D(+), rsi14_prev(-)  
expected size (ridge): MAE 0.37 / 0.37 / 0.33 / 0.51 vs naive 0.34 / 0.37 / 0.32 / 0.49 (pct points) by year

**BANKNIFTY_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 76% vs 66% · 2024 n249 61% vs 58% · 2025 n249 61% vs 53% · 2026 n219 64% vs 48%  
top inputs: spx_night, idx_D_ret, asia_D, us10y_night, wti_prev, asia_min_D  
expected size (ridge): MAE 0.31 / 0.37 / 0.33 / 0.46 vs naive 0.34 / 0.37 / 0.32 / 0.49 (pct points) by year

**IT_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 65% vs 65% · 2024 n249 61% vs 61% · 2025 n249 58% vs 58% · 2026 n219 50% vs 50%  
top inputs: dist20_prev(+), rsi14_prev(-), friday(-), asia_D(-), idx_prev_ret(-), gold_prev(-)  
expected size (ridge): MAE 0.40 / 0.46 / 0.47 / 0.77 vs naive 0.36 / 0.43 / 0.46 / 0.75 (pct points) by year

**IT_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 78% vs 65% · 2024 n249 70% vs 61% · 2025 n249 65% vs 58% · 2026 n219 61% vs 50%  
top inputs: spx_night, asia_D, ndx_night, asia_min_D, usdinr_prev, us10y_night  
expected size (ridge): MAE 0.30 / 0.41 / 0.42 / 0.71 vs naive 0.36 / 0.43 / 0.46 / 0.75 (pct points) by year

**PVT_BANK_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 65% vs 65% · 2024 n249 57% vs 57% · 2025 n249 53% vs 53% · 2026 n219 48% vs 48%  
top inputs: asia_D(-), gap_D(+), friday(-), spx_prev(-), nights(+), dxy_prev(+)  
expected size (ridge): MAE 0.38 / 0.37 / 0.34 / 0.52 vs naive 0.34 / 0.36 / 0.33 / 0.51 (pct points) by year

**PVT_BANK_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 74% vs 65% · 2024 n249 59% vs 57% · 2025 n249 62% vs 53% · 2026 n219 63% vs 48%  
top inputs: spx_night, wti_prev, idx_D_ret, asia_D, us10y_night, asia_min_D  
expected size (ridge): MAE 0.31 / 0.37 / 0.35 / 0.47 vs naive 0.34 / 0.36 / 0.33 / 0.51 (pct points) by year

**PSU_BANK_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 77% vs 77% · 2024 n249 75% vs 75% · 2025 n249 73% vs 73% · 2026 n219 57% vs 57%  
top inputs: rsi14_prev(+), dist20_prev(-), spx_prev(-), friday(-), asia_D(-), asia_min_D(+)  
expected size (ridge): MAE 0.40 / 0.40 / 0.35 / 0.55 vs naive 0.34 / 0.39 / 0.33 / 0.53 (pct points) by year

**PSU_BANK_kite 0730** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 80% vs 77% · 2024 n249 74% vs 75% · 2025 n249 75% vs 73% · 2026 n219 60% vs 57%  
top inputs: spx_night(+), rsi14_D(+), asia_D(-), dist20_D(-), vix_prev(-), us10y_night(-)  
expected size (ridge): MAE 0.33 / 0.38 / 0.36 / 0.47 vs naive 0.34 / 0.39 / 0.33 / 0.53 (pct points) by year

**FIN_SERVICE_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 64% vs 64% · 2024 n249 59% vs 59% · 2025 n249 53% vs 53% · 2026 n219 48% vs 48%  
top inputs: nights(+), friday(-), spx_prev(-), gap_D(+), gold_prev(-), asia_D(-)  
expected size (ridge): MAE 0.37 / 0.36 / 0.33 / 0.52 vs naive 0.33 / 0.36 / 0.32 / 0.51 (pct points) by year

**FIN_SERVICE_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 74% vs 64% · 2024 n249 64% vs 59% · 2025 n249 61% vs 53% · 2026 n219 68% vs 48%  
top inputs: spx_night, idx_D_ret, us10y_night, asia_D, idx_prev_ret, asia_min_D  
expected size (ridge): MAE 0.32 / 0.36 / 0.33 / 0.46 vs naive 0.33 / 0.36 / 0.32 / 0.51 (pct points) by year

**PHARMA_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 75% vs 75% · 2024 n249 77% vs 77% · 2025 n249 69% vs 69% · 2026 n219 59% vs 59%  
top inputs: spx_prev(-), gap_D(+), gold_prev(-), friday(-), ndx_prev(+), asia_D(-)  
expected size (ridge): MAE 0.21 / 0.26 / 0.29 / 0.33 vs naive 0.20 / 0.26 / 0.29 / 0.32 (pct points) by year

**PHARMA_kite 0730** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 79% vs 75% · 2024 n249 79% vs 77% · 2025 n249 73% vs 69% · 2026 n219 66% vs 59%  
top inputs: spx_night(+), asia_D(-), idx_D_ret(+), vix_prev(-), gold_prev(-), vix_D(+)  
expected size (ridge): MAE 0.19 / 0.23 / 0.28 / 0.31 vs naive 0.20 / 0.26 / 0.29 / 0.32 (pct points) by year

**FMCG_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 75% vs 75% · 2024 n249 72% vs 72% · 2025 n249 65% vs 65% · 2026 n219 58% vs 58%  
top inputs: rsi14_prev(+), dist20_prev(-), gold_prev(-), ndx_prev(-), idx_prev_ret(-), spx_prev(+)  
expected size (ridge): MAE 0.21 / 0.25 / 0.26 / 0.34 vs naive 0.19 / 0.24 / 0.25 / 0.33 (pct points) by year

**FMCG_kite 0730** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 78% vs 75% · 2024 n249 74% vs 72% · 2025 n249 69% vs 65% · 2026 n219 62% vs 58%  
top inputs: spx_night(+), rsi14_D(+), vix_prev(-), vix_D(+), spx_prev(+), ndx_prev(-)  
expected size (ridge): MAE 0.19 / 0.24 / 0.26 / 0.29 vs naive 0.19 / 0.24 / 0.25 / 0.33 (pct points) by year

**AUTO_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 81% vs 81% · 2024 n249 70% vs 70% · 2025 n249 67% vs 67% · 2026 n219 57% vs 57%  
top inputs: rsi14_prev(+), ndx_prev(-), asia_D(-), dist20_prev(-), dxy_prev(-), gap_D(+)  
expected size (ridge): MAE 0.27 / 0.33 / 0.36 / 0.54 vs naive 0.24 / 0.33 / 0.35 / 0.53 (pct points) by year

**AUTO_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 85% vs 81% · 2024 n249 73% vs 70% · 2025 n249 71% vs 67% · 2026 n219 62% vs 57%  
top inputs: spx_night, asia_D, ndx_night, idx_D_ret, dist20_D, wti_night  
expected size (ridge): MAE 0.22 / 0.30 / 0.36 / 0.46 vs naive 0.24 / 0.33 / 0.35 / 0.53 (pct points) by year

**METAL_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 77% vs 77% · 2024 n249 77% vs 77% · 2025 n249 68% vs 68% · 2026 n219 59% vs 59%  
top inputs: rsi14_prev(+), asia_min_D(+), spx_prev(-), dist20_prev(-), friday(-), vix_prev(-)  
expected size (ridge): MAE 0.42 / 0.41 / 0.41 / 0.58 vs naive 0.38 / 0.40 / 0.41 / 0.57 (pct points) by year

**METAL_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 82% vs 77% · 2024 n249 78% vs 77% · 2025 n249 72% vs 68% · 2026 n219 64% vs 59%  
top inputs: spx_night, ndx_night, idx_prev_ret, rsi14_D, asia_D, us10y_night  
expected size (ridge): MAE 0.32 / 0.36 / 0.39 / 0.51 vs naive 0.38 / 0.40 / 0.41 / 0.57 (pct points) by year

**REALTY_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 75% vs 75% · 2024 n249 73% vs 73% · 2025 n249 72% vs 72% · 2026 n219 53% vs 53%  
top inputs: rsi14_prev(+), dist20_prev(-), spx_prev(-), gap_D(+), us10y_prev(-), asia_min_D(+)  
expected size (ridge): MAE 0.31 / 0.46 / 0.40 / 0.56 vs naive 0.26 / 0.46 / 0.39 / 0.53 (pct points) by year

**REALTY_kite 0730** (gbt, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 80% vs 75% · 2024 n249 76% vs 73% · 2025 n249 74% vs 72% · 2026 n219 62% vs 53%  
top inputs: spx_night, ndx_night, idx_D_ret, rsi14_D, ndx_prev, us10y_night  
expected size (ridge): MAE 0.28 / 0.41 / 0.38 / 0.48 vs naive 0.26 / 0.46 / 0.39 / 0.53 (pct points) by year

**ENERGY_kite 1445** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 75% vs 75% · 2024 n249 73% vs 73% · 2025 n249 76% vs 76% · 2026 n219 61% vs 61%  
top inputs: spx_prev(-), rsi14_prev(+), vix_prev(-), gap_D(+), ndx_prev(+), usdinr_prev(-)  
expected size (ridge): MAE 0.35 / 0.37 / 0.33 / 0.38 vs naive 0.32 / 0.38 / 0.32 / 0.37 (pct points) by year

**ENERGY_kite 0730** (lr, data 2021-12-15 to 2026-11-19)  
year: 2023 n246 76% vs 75% · 2024 n249 74% vs 73% · 2025 n249 80% vs 76% · 2026 n219 66% vs 61%  
top inputs: spx_night(+), vix_prev(-), rsi14_D(+), vix_D(+), spx_prev(-), idx_D_ret(+)  
expected size (ridge): MAE 0.31 / 0.34 / 0.31 / 0.32 vs naive 0.32 / 0.38 / 0.32 / 0.37 (pct points) by year

**NIFTY_intraday 1445** (lr, data 2024-07-04 to 2026-11-19)  
year: 2025 n248 58% vs 59% · 2026 n217 47% vs 47%  
top inputs: asia(-), nights(+), idx_1445(+), niy(+), friday(-), asia_min(+)  
expected size (ridge): MAE 0.49 vs naive 0.46 (pct points) by year

**NIFTY_intraday 0730** (lr, data 2024-07-04 to 2026-11-19)  
year: 2025 n248 68% vs 59% · 2026 n217 70% vs 47%  
top inputs: es_eve(+), sox_eve(-), asia(-), gc_eve(+), cl_eve(-), dxy_eve(-)  
expected size (ridge): MAE 0.41 vs naive 0.46 (pct points) by year

**BANKNIFTY_intraday 1445** (gbt, data 2024-07-04 to 2026-11-19)  
year: 2025 n248 54% vs 52% · 2026 n217 55% vs 48%  
top inputs: nifty1430, asia, inr, zn, asia_min, niy  
expected size (ridge): MAE 0.54 vs naive 0.50 (pct points) by year

**BANKNIFTY_intraday 0730** (lr, data 2024-07-04 to 2026-11-19)  
year: 2025 n248 65% vs 52% · 2026 n217 68% vs 48%  
top inputs: es_eve(+), niy_eve(+), friday(-), sox_eve(-), nights(+), cl_eve(-)  
expected size (ridge): MAE 0.46 vs naive 0.50 (pct points) by year

## Notes

- 14:45 inputs: the intraday set uses the futures / Europe / FX values at 14:30 IST (Yahoo 60m bars end on the UTC hour); NIFTY / BANKNIFTY at 14:45 from minute data. The daily sets use only values final before 14:45 (Asia closes, previous US session, drivers' previous day, India's D-1 state).
- 07:30 inputs add the US session(s) between India's close and the next open, India's own day move, drivers on those dates; the intraday set adds NQ / ES / SOX / Nikkei futures, gold, crude, USDINR, 10y from 15:30 IST to 07:30 IST.
- daily NIFTY / BANKNIFTY before 15 Nov 2021 use Yahoo ^NSEI / ^NSEBANK day bars (opens checked: only 25 of 4,175 equal the previous close).
- Model choice (lr vs gbt) is made on the same unseen years; the p-value threshold is halved for that.
- Saved: v2/models/artifacts/m1_<set>_<time>.json; call v2/models/predict.py predict('M1', ...).
