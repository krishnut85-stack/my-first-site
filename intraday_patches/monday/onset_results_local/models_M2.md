# M2 09:20 SHARE CONTINUATION - walk-forward results (2026-11-21)

Rows: F&O share-days whose 09:20 price is >= 0.5% from the previous close (n 80138, 2023-12-18 to 2026-11-13, 3 years of minute bars). Train on the years before, test once on 2025 and on 2026. PASS rule as M1 (accuracy beats the base rate with p < 0.025, Brier beats it, at least half of the years). Note: rows on the same day move together, so the p-value is optimistic - the by-year results matter more.

## touch - P(>= 1% more in the 09:20 direction at any minute up to 15:10) (n 80138)

**PASS** - lr: unseen accuracy 57.1% vs base rate 49.5% (n 52110); Brier 0.2425 vs 0.2501; AUC 0.601; p 0.0000; years beaten 2/2

| year | n | train n | model acc | base acc | Brier | base Brier | AUC |
|---|---|---|---|---|---|---|---|
| 2025 (lr) | 25566 | 28028 | 58.0% | 49.4% | 0.2409 | 0.2503 | 0.612 |
| 2026 (lr) | 26544 | 53594 | 56.2% | 49.6% | 0.2440 | 0.2500 | 0.59 |
| 2025 (gbt) | 25566 | 28028 | 57.7% | 49.4% | 0.2414 | 0.2503 | 0.609 |
| 2026 (gbt) | 26544 | 53594 | 56.1% | 49.6% | 0.2444 | 0.2500 | 0.586 |

Base rate over all rows: 50.1%. By direction (unseen, lr): up n 28909 hit 49.0% acc 57.5%; down n 23201 hit 50.1% acc 56.5%.
Confident calls on unseen years: p>=0.6: n 5817, came true 64.8%; p<=0.4: n 2452, came true 31.7%.
Top inputs: atr14(+), first5_d(+), move0920(-), gap_d(+), range5(+), rvol5(+), sector_d(+), vwap_d(+)

## hold - P(15:09 close >= 1% beyond the 09:20 price in its direction) (n 80138)

**NO EDGE** - lr: unseen accuracy 75.0% vs base rate 75.0% (n 52110); Brier 0.1858 vs 0.1874; AUC 0.57; p 0.4992; years beaten 0/2

| year | n | train n | model acc | base acc | Brier | base Brier | AUC |
|---|---|---|---|---|---|---|---|
| 2025 (lr) | 25566 | 28028 | 75.1% | 75.1% | 0.1849 | 0.1869 | 0.584 |
| 2026 (lr) | 26544 | 53594 | 74.9% | 74.9% | 0.1866 | 0.1880 | 0.558 |

Base rate over all rows: 24.9%. By direction (unseen, lr): up n 28909 hit 24.4% acc 75.6%; down n 23201 hit 25.7% acc 74.3%.
Confident calls on unseen years: p>=0.6: n 0, came true -; p<=0.4: n 52093, came true 25.0%.
Top inputs: atr14(+), first5_d(+), move0920(-), rvol5(+), sector_d(+), gap_d(+), dist_52h(-), rsi_d(-)

## first - P(the 1% WITH the 09:20 move comes before the 1% against it | at least one is touched by 15:10) - the direction test (n 69432)

**PASS** - lr: unseen accuracy 51.2% vs base rate 50.1% (n 44504); Brier 0.2497 vs 0.2502; AUC 0.519; p 0.0000; years beaten 2/2

| year | n | train n | model acc | base acc | Brier | base Brier | AUC |
|---|---|---|---|---|---|---|---|
| 2025 (lr) | 21746 | 24928 | 51.3% | 50.4% | 0.2497 | 0.2502 | 0.52 |
| 2026 (lr) | 22758 | 46674 | 51.2% | 49.7% | 0.2498 | 0.2502 | 0.518 |
| 2025 (gbt) | 21746 | 24928 | 50.3% | 50.4% | 0.2511 | 0.2502 | 0.501 |
| 2026 (gbt) | 22758 | 46674 | 50.5% | 49.7% | 0.2499 | 0.2502 | 0.522 |

Base rate over all rows: 49.3%. By direction (unseen, lr): up n 24617 hit 49.6% acc 51.0%; down n 19887 hit 50.3% acc 51.5%.
Confident calls on unseen years: p>=0.6: n 0, came true -; p<=0.4: n 0, came true -.
Top inputs: first5_d(+), move0920(-), gap_d(+), range5(-), sector_d(+), rsi_d(-), nifty_d(-), dir(-)

Reading: 'touch' passing while 'first' does not would mean the edge is mostly volatility (busy shares reach 1% either way), not direction. 'first' is the direction test.

Saved: v2/models/artifacts/m2_touch.json, m2_hold.json, m2_first.json; predict.predict('m2_touch', inputs) (inputs: dir, gap_d, first5_d, range5, move0920, rvol5, vwap_d, sector_d, nifty_d, oi_chg_prev_d, rsi_d, dist_52h, dist_52l, atr14).
