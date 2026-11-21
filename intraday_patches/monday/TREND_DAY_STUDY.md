# TREND-DAY STUDY - BANKNIFTY / NIFTY, hold to 15:10 with a trailing stop (2026-11-21)

The trader (22 Nov 00:35): "It missed the BANKNIFTY and NIFTY - that very big move" (Fri 20 Nov BANKNIFTY +2.49%, NIFTY +1.12%). Code only, $0, no AI. Script: v2/kb/trend_day_study.py.

## Verdict

**NOT PROVEN - no rule passed every check.** The live TREND DAY line stays grade B (READY - your call), never BUY.

Best rule on the unseen 2026 data (most checks passed, then option expectancy): **ORB_ALL NIFTY PE, exit TRAIL** - ORB + VWAP rising + breadth >= 60%.
- Unseen 2026: n 48, hit 44% vs random 37% (lift 1.186, lower bound 0.811), option return after costs +9.6% a trade (random same-time entries +0.1%), Holm p 1.0.
- Tuning 2023-25: n 110, hit 0.382 vs random 0.316, option return -0.22% (random -4.48%).
- Verdict: **NOT PROVEN** - fails: tune lift lb > 1.1, unseen lift lb > 1.1, Holm p < 0.05

THE LIVE RULE (LIVE08: >= 0.8% from the day low / high, VWAP side, heavyweights met), unseen 2026 | tuning:
- BANKNIFTY CE exit TRAIL: unseen n 48, hit 0.354 vs random 0.348, option return 1.38% (random -1.61%) | tune n 87, hit 0.356 vs 0.385, return -2.91% -> **NOT PROVEN**
- BANKNIFTY CE exit VWAP: unseen n 48, hit 0.25 vs random 0.198, option return -0.44% (random -1.68%) | tune n 87, hit 0.299 vs 0.238, return -0.98% -> **NOT PROVEN**
- BANKNIFTY PE exit TRAIL: unseen n 31, hit 0.484 vs random 0.362, option return 0.18% (random -1.6%) | tune n 88, hit 0.375 vs 0.374, return 0.71% -> **NOT PROVEN**
- BANKNIFTY PE exit VWAP: unseen n 31, hit 0.419 vs random 0.247, option return -0.65% (random -1.38%) | tune n 88, hit 0.352 vs 0.219, return 2.51% -> **NOT PROVEN**
- NIFTY CE exit TRAIL: unseen n 16, hit 0.188 vs random 0.248, option return -15.67% (random -9.98%) | tune n 42, hit 0.405 vs 0.315, return 5.45% -> **NOT PROVEN**
- NIFTY CE exit VWAP: unseen n 16, hit 0.125 vs random 0.287, option return -16.69% (random -1.99%) | tune n 42, hit 0.381 vs 0.268, return 2.5% -> **NOT PROVEN**
- NIFTY PE exit TRAIL: unseen n 26, hit 0.385 vs random 0.386, option return 5.34% (random 2.62%) | tune n 51, hit 0.392 vs 0.323, return 0.11% -> **NOT PROVEN**
- NIFTY PE exit VWAP: unseen n 26, hit 0.308 vs random 0.3, option return 0.5% (random 0.88%) | tune n 51, hit 0.373 vs 0.265, return 3.34% -> **NOT PROVEN**

## Method

DATA (labelled): index minutes NIFTY ['2023-12-18', '2026-11-20', 722], BANKNIFTY ['2023-12-18', '2026-11-20', 722] (first, last, days; hist_fresh to 19 Nov + Fri 20 Nov from girdata/minute). Index minutes have no volume: the index VWAP is the harness's VOLUME PROXY (heavyweights' traded value as weights; agreed with real futures VWAP side on 94-95% of minutes over 17 futures days, index_tests.md). Heavyweights use their own minute VWAP (BANKNIFTY HDFCBANK ICICIBANK SBIN KOTAKBANK AXISBANK, CE needs 4 of 5 above / PE <= 1; NIFTY + RELIANCE INFY BHARTIARTL LT TCS ITC, CE 6 of 8 / PE <= 2). Breadth = share of 218 F&O shares above yesterday's close. PVT BANK leadership = mean move of 4 private banks minus NIFTY (proxy; no 3-year PVT BANK minutes). RBI = a cash-injection operation >= 25,000 crore rupees that trading day (RBI operations file). FII: only Jun-Nov 2026 on the server, known after the close - descriptive only.
CHECKS at 10:00 / 10:30 / 11:00 / 11:30 (the minute bar closing then); one entry per day, side and rule = the first check that holds. EXITS: VWAP = a 5-min close back through VWAP; TRAIL = a 5-min close 0.4 x ADR20 back from the best close; both also -30% premium stop and 15:10 at the latest (NOT the 60-min target). OPTION PROXY = the index harness (Black-Scholes ATM at India VIX x 0.96 BANKNIFTY / 0.82 NIFTY, IV from the VIX open to its close, theta, NIFTY weekly / BANKNIFTY monthly, full spread 0.4% paid twice, brokerage, STT, exchange, GST, stamp). HIT = option return after costs > 0. RANDOM = the same check minute on 30 random days of the same period, same side and exit. TUNE Dec 2023 - Dec 2025, UNSEEN 2026. PASS = tune n >= 100 + lift lb > 1.1; unseen n >= 30, lift lb > 1.1, Holm p < 0.05 over 92 unseen tests (paired: option return of each fire vs its own random draws), option expectancy > 0 and above random.

## Every rule (unseen 2026 | tuning 2023-25)

| rule | index | side | exit | UNSEEN n / hit / random / lift (lb) / option return % (random) / Holm p | TUNE n / hit / random / option return % | verdict |
|---|---|---|---|---|---|---|
| LIVE05 | BANKNIFTY | CE | TRAIL | 78 / 0.308 / 0.345 / 0.891 (0.611) / -0.8 (-1.1) / 1.0 | 181 / 0.348 / 0.359 / -2.6 | **NOT PROVEN** |
| LIVE05 | BANKNIFTY | CE | VWAP | 78 / 0.231 / 0.227 / 1.017 (0.624) / -1.4 (-1.1) / 1.0 | 181 / 0.254 / 0.233 / -1.7 | **NOT PROVEN** |
| LIVE08 | BANKNIFTY | CE | TRAIL | 48 / 0.354 / 0.348 / 1.018 (0.637) / +1.4 (-1.6) / 1.0 | 87 / 0.356 / 0.385 / -2.9 | **NOT PROVEN** |
| LIVE08 | BANKNIFTY | CE | VWAP | 48 / 0.25 / 0.198 / 1.263 (0.68) / -0.4 (-1.7) / 1.0 | 87 / 0.299 / 0.238 / -1.0 | **NOT PROVEN** |
| LIVE08_ALL | BANKNIFTY | CE | TRAIL | 20 / 0.4 / 0.33 / 1.212 (0.574) / -0.1 (-1.4) / 1.0 | 39 / 0.256 / 0.345 / -5.9 | **NOT PROVEN** |
| LIVE08_ALL | BANKNIFTY | CE | VWAP | 20 / 0.15 / 0.203 / 0.738 (0.0) / -3.4 (-1.5) / 1.0 | 39 / 0.205 / 0.239 / -5.6 | **NOT PROVEN** |
| LIVE08_BR | BANKNIFTY | CE | TRAIL | 27 / 0.333 / 0.341 / 0.978 (0.435) / -2.5 (-1.6) / 1.0 | 58 / 0.293 / 0.347 / -5.0 | **NOT PROVEN** |
| LIVE08_BR | BANKNIFTY | CE | VWAP | 27 / 0.148 / 0.241 / 0.615 (0.148) / -4.0 (-1.3) / 1.0 | 58 / 0.241 / 0.24 / -3.4 | **NOT PROVEN** |
| LIVE08_PB | BANKNIFTY | CE | TRAIL | 37 / 0.378 / 0.352 / 1.074 (0.625) / +2.8 (-1.4) / 1.0 | 65 / 0.354 / 0.376 / -2.8 | **NOT PROVEN** |
| LIVE08_PB | BANKNIFTY | CE | VWAP | 37 / 0.243 / 0.249 / 0.978 (0.443) / +0.1 (-0.8) / 1.0 | 65 / 0.292 / 0.223 / -2.0 | **NOT PROVEN** |
| LIVE08_RBI | BANKNIFTY | CE | TRAIL | 8 / 0.375 / 0.371 / 1.011 (0.0) / +6.6 (-0.8) / 1.0 | 22 / 0.455 / 0.379 / +3.8 | **NOT PROVEN** |
| LIVE08_RBI | BANKNIFTY | CE | VWAP | 8 / 0.25 / 0.246 / 1.017 (0.0) / +4.0 (-0.0) / 1.0 | 22 / 0.409 / 0.227 / +5.1 | **NOT PROVEN** |
| LIVE08_RX | BANKNIFTY | CE | TRAIL | 45 / 0.311 / 0.319 / 0.974 (0.574) / +0.5 (-2.2) / 1.0 | 80 / 0.362 / 0.377 / -2.2 | **NOT PROVEN** |
| LIVE08_RX | BANKNIFTY | CE | VWAP | 45 / 0.222 / 0.23 / 0.965 (0.505) / -1.6 (-1.2) / 1.0 | 80 / 0.3 / 0.229 / -0.6 | **NOT PROVEN** |
| LIVE08_SL | BANKNIFTY | CE | TRAIL | 47 / 0.34 / 0.328 / 1.039 (0.64) / +1.1 (-1.4) / 1.0 | 87 / 0.345 / 0.361 / -3.2 | **NOT PROVEN** |
| LIVE08_SL | BANKNIFTY | CE | VWAP | 47 / 0.234 / 0.233 / 1.006 (0.523) / -0.8 (-1.1) / 1.0 | 87 / 0.299 / 0.242 / -1.4 | **NOT PROVEN** |
| LIVE12 | BANKNIFTY | CE | TRAIL | 8 / 0.25 / 0.354 / 0.706 (0.0) / +4.5 (-1.4) / 1.0 | 23 / 0.304 / 0.378 / -7.3 | **NOT PROVEN** |
| LIVE12 | BANKNIFTY | CE | VWAP | 8 / 0.25 / 0.208 / 1.2 (0.0) / +2.5 (-0.6) / 1.0 | 23 / 0.261 / 0.226 / -4.4 | **NOT PROVEN** |
| ORB | BANKNIFTY | CE | TRAIL | 67 / 0.328 / 0.338 / 0.971 (0.651) / -0.9 (-1.7) / 1.0 | 191 / 0.34 / 0.365 / -2.8 | **NOT PROVEN** |
| ORB | BANKNIFTY | CE | VWAP | 67 / 0.239 / 0.225 / 1.062 (0.624) / -1.4 (-1.1) / 1.0 | 191 / 0.251 / 0.249 / -2.1 | **NOT PROVEN** |
| ORB_ALL | BANKNIFTY | CE | TRAIL | 41 / 0.293 / 0.339 / 0.863 (0.466) / -4.2 (-1.2) / 1.0 | 117 / 0.316 / 0.353 / -4.6 | **NOT PROVEN** |
| ORB_ALL | BANKNIFTY | CE | VWAP | 41 / 0.146 / 0.214 / 0.684 (0.225) / -4.2 (-1.4) / 1.0 | 117 / 0.222 / 0.242 / -4.0 | **NOT PROVEN** |
| T1R | BANKNIFTY | CE | TRAIL | 20 / 0.35 / 0.32 / 1.094 (0.455) / +4.8 (-2.1) / 1.0 | 37 / 0.27 / 0.368 / -3.6 | **NOT PROVEN** |
| T1R | BANKNIFTY | CE | VWAP | 20 / 0.35 / 0.227 / 1.544 (0.662) / +5.7 (-1.8) / 1.0 | 37 / 0.216 / 0.235 / -2.1 | **NOT PROVEN** |
| LIVE05 | BANKNIFTY | PE | TRAIL | 82 / 0.476 / 0.407 / 1.17 (0.913) / +1.2 (-0.3) / 1.0 | 176 / 0.403 / 0.363 / +0.0 | **NOT PROVEN** |
| LIVE05 | BANKNIFTY | PE | VWAP | 82 / 0.305 / 0.25 / 1.22 (0.806) / -0.6 (-1.1) / 1.0 | 176 / 0.324 / 0.227 / +1.1 | **NOT PROVEN** |
| LIVE08 | BANKNIFTY | PE | TRAIL | 31 / 0.484 / 0.362 / 1.335 (0.833) / +0.2 (-1.6) / 1.0 | 88 / 0.375 / 0.374 / +0.7 | **NOT PROVEN** |
| LIVE08 | BANKNIFTY | PE | VWAP | 31 / 0.419 / 0.247 / 1.696 (0.992) / -0.7 (-1.4) / 1.0 | 88 / 0.352 / 0.219 / +2.5 | **NOT PROVEN** |
| LIVE08_ALL | BANKNIFTY | PE | TRAIL | 17 / 0.647 / 0.392 / 1.65 (1.05) / +7.0 (-0.7) / 1.0 | 48 / 0.458 / 0.351 / +4.4 | **NOT PROVEN** |
| LIVE08_ALL | BANKNIFTY | PE | VWAP | 17 / 0.588 / 0.282 / 2.083 (1.259) / +6.0 (-0.4) / 1.0 | 48 / 0.458 / 0.245 / +6.1 | **NOT PROVEN** |
| LIVE08_BR | BANKNIFTY | PE | TRAIL | 22 / 0.545 / 0.371 / 1.469 (0.89) / +4.1 (-0.6) / 1.0 | 59 / 0.424 / 0.388 / +2.8 | **NOT PROVEN** |
| LIVE08_BR | BANKNIFTY | PE | VWAP | 22 / 0.5 / 0.233 / 2.143 (1.2) / +3.5 (-1.6) / 1.0 | 59 / 0.424 / 0.232 / +5.4 | **NOT PROVEN** |
| LIVE08_PB | BANKNIFTY | PE | TRAIL | 25 / 0.56 / 0.367 / 1.527 (0.993) / +2.1 (-1.3) / 1.0 | 72 / 0.403 / 0.366 / +1.7 | **NOT PROVEN** |
| LIVE08_PB | BANKNIFTY | PE | VWAP | 25 / 0.48 / 0.227 / 2.118 (1.218) / +1.1 (-1.5) / 1.0 | 72 / 0.375 / 0.244 / +3.1 | **NOT PROVEN** |
| LIVE08_RBI | BANKNIFTY | PE | TRAIL | 11 / 0.636 / 0.345 / 1.842 (1.025) / +3.6 (-1.8) / 1.0 | 28 / 0.25 / 0.358 / -2.9 | **NOT PROVEN** |
| LIVE08_RBI | BANKNIFTY | PE | VWAP | 11 / 0.545 / 0.255 / 2.143 (0.882) / +1.4 (-0.6) / 1.0 | 28 / 0.214 / 0.204 / -0.9 | **NOT PROVEN** |
| LIVE08_RX | BANKNIFTY | PE | TRAIL | 29 / 0.517 / 0.364 / 1.42 (0.926) / +0.9 (-0.6) / 1.0 | 85 / 0.388 / 0.375 / +1.2 | **NOT PROVEN** |
| LIVE08_RX | BANKNIFTY | PE | VWAP | 29 / 0.448 / 0.259 / 1.733 (0.996) / +0.1 (-0.5) / 1.0 | 85 / 0.365 / 0.22 / +2.9 | **NOT PROVEN** |
| LIVE08_SL | BANKNIFTY | PE | TRAIL | 30 / 0.5 / 0.382 / 1.308 (0.817) / +0.7 (-0.4) / 1.0 | 87 / 0.379 / 0.379 / +1.4 | **NOT PROVEN** |
| LIVE08_SL | BANKNIFTY | PE | VWAP | 30 / 0.433 / 0.239 / 1.814 (1.062) / -0.5 (-0.8) / 1.0 | 87 / 0.356 / 0.232 / +2.6 | **NOT PROVEN** |
| LIVE12 | BANKNIFTY | PE | TRAIL | 13 / 0.615 / 0.4 / 1.538 (0.822) / +4.3 (-0.2) / 1.0 | 30 / 0.433 / 0.402 / +6.2 | **NOT PROVEN** |
| LIVE12 | BANKNIFTY | PE | VWAP | 13 / 0.538 / 0.221 / 2.442 (1.034) / +1.2 (-1.6) / 1.0 | 30 / 0.467 / 0.229 / +8.4 | **NOT PROVEN** |
| ORB | BANKNIFTY | PE | TRAIL | 67 / 0.478 / 0.374 / 1.277 (0.958) / +2.7 (-0.4) / 1.0 | 184 / 0.397 / 0.367 / -0.8 | **NOT PROVEN** |
| ORB | BANKNIFTY | PE | VWAP | 67 / 0.299 / 0.265 / 1.128 (0.701) / +0.0 (-0.5) / 1.0 | 184 / 0.299 / 0.246 / -0.1 | **NOT PROVEN** |
| ORB_ALL | BANKNIFTY | PE | TRAIL | 42 / 0.476 / 0.394 / 1.21 (0.827) / +3.5 (-0.1) / 1.0 | 97 / 0.423 / 0.357 / +1.7 | **NOT PROVEN** |
| ORB_ALL | BANKNIFTY | PE | VWAP | 42 / 0.333 / 0.247 / 1.35 (0.743) / +1.8 (-1.1) / 1.0 | 97 / 0.392 / 0.228 / +2.7 | **NOT PROVEN** |
| T1R | BANKNIFTY | PE | TRAIL | 17 / 0.471 / 0.41 / 1.148 (0.577) / +1.0 (-0.3) / 1.0 | 39 / 0.359 / 0.35 / -1.8 | **NOT PROVEN** |
| T1R | BANKNIFTY | PE | VWAP | 17 / 0.176 / 0.233 / 0.756 (0.0) / -2.4 (-0.8) / 1.0 | 39 / 0.308 / 0.244 / -0.7 | **NOT PROVEN** |
| LIVE05 | NIFTY | CE | TRAIL | 54 / 0.278 / 0.289 / 0.962 (0.554) / -9.3 (-5.4) / 1.0 | 115 / 0.391 / 0.307 / -3.0 | **NOT PROVEN** |
| LIVE05 | NIFTY | CE | VWAP | 54 / 0.241 / 0.288 / 0.835 (0.442) / -8.1 (-2.0) / 1.0 | 115 / 0.313 / 0.27 / -2.1 | **NOT PROVEN** |
| LIVE08 | NIFTY | CE | TRAIL | 16 / 0.188 / 0.248 / 0.756 (0.0) / -15.7 (-10.0) / 1.0 | 42 / 0.405 / 0.315 / +5.5 | **NOT PROVEN** |
| LIVE08 | NIFTY | CE | VWAP | 16 / 0.125 / 0.287 / 0.435 (0.0) / -16.7 (-2.0) / 1.0 | 42 / 0.381 / 0.268 / +2.5 | **NOT PROVEN** |
| LIVE08_ALL | NIFTY | CE | TRAIL | 8 / 0.125 / 0.267 / 0.469 (0.0) / -12.0 (-6.8) / 1.0 | 16 / 0.562 / 0.283 / +5.5 | **NOT PROVEN** |
| LIVE08_ALL | NIFTY | CE | VWAP | 8 / 0.125 / 0.242 / 0.517 (0.0) / -12.5 (-3.3) / 1.0 | 16 / 0.562 / 0.252 / +5.3 | **NOT PROVEN** |
| LIVE08_BR | NIFTY | CE | TRAIL | 11 / 0.182 / 0.3 / 0.606 (0.0) / -16.4 (-5.5) / 1.0 | 33 / 0.455 / 0.333 / +7.8 | **NOT PROVEN** |
| LIVE08_BR | NIFTY | CE | VWAP | 11 / 0.182 / 0.261 / 0.698 (0.0) / -15.2 (-3.5) / 1.0 | 33 / 0.424 / 0.28 / +5.0 | **NOT PROVEN** |
| LIVE08_PB | NIFTY | CE | TRAIL | 10 / 0.2 / 0.283 / 0.706 (0.0) / -12.6 (-6.5) / 1.0 | 19 / 0.526 / 0.318 / +7.7 | **NOT PROVEN** |
| LIVE08_PB | NIFTY | CE | VWAP | 10 / 0.2 / 0.32 / 0.625 (0.0) / -13.0 (-0.8) / 1.0 | 19 / 0.526 / 0.261 / +6.2 | **NOT PROVEN** |
| LIVE08_RBI | NIFTY | CE | TRAIL | n 3 | 11 / 0.455 / 0.339 / +13.4 | **NOT PROVEN** |
| LIVE08_RBI | NIFTY | CE | VWAP | n 3 | 11 / 0.364 / 0.267 / -0.7 | **NOT PROVEN** |
| LIVE08_RX | NIFTY | CE | TRAIL | 16 / 0.188 / 0.269 / 0.698 (0.0) / -15.7 (-6.7) / 1.0 | 42 / 0.405 / 0.328 / +5.3 | **NOT PROVEN** |
| LIVE08_RX | NIFTY | CE | VWAP | 16 / 0.125 / 0.298 / 0.42 (0.0) / -16.7 (-3.1) / 1.0 | 42 / 0.381 / 0.278 / +2.3 | **NOT PROVEN** |
| LIVE08_SL | NIFTY | CE | TRAIL | 16 / 0.188 / 0.244 / 0.769 (0.0) / -15.7 (-8.8) / 1.0 | 41 / 0.415 / 0.315 / +5.9 | **NOT PROVEN** |
| LIVE08_SL | NIFTY | CE | VWAP | 16 / 0.125 / 0.273 / 0.458 (0.0) / -16.7 (-3.0) / 1.0 | 41 / 0.39 / 0.267 / +3.2 | **NOT PROVEN** |
| LIVE12 | NIFTY | CE | TRAIL | 5 / 0.0 / 0.267 / 0.0 (0.0) / -24.7 (-4.9) / 1.0 | 5 / 0.4 / 0.26 / -3.8 | **NOT PROVEN** |
| LIVE12 | NIFTY | CE | VWAP | 5 / 0.0 / 0.26 / 0.0 (0.0) / -20.3 (-0.2) / 1.0 | 5 / 0.6 / 0.26 / +14.2 | **NOT PROVEN** |
| ORB | NIFTY | CE | TRAIL | 65 / 0.215 / 0.269 / 0.802 (0.426) / -12.5 (-6.8) / 1.0 | 160 / 0.356 / 0.32 / -0.9 | **NOT PROVEN** |
| ORB | NIFTY | CE | VWAP | 65 / 0.169 / 0.279 / 0.606 (0.289) / -10.7 (-2.8) / 1.0 | 160 / 0.275 / 0.279 / -0.9 | **NOT PROVEN** |
| ORB_ALL | NIFTY | CE | TRAIL | 38 / 0.184 / 0.273 / 0.675 (0.277) / -15.3 (-7.0) / 1.0 | 113 / 0.319 / 0.334 / -4.9 | **NOT PROVEN** |
| ORB_ALL | NIFTY | CE | VWAP | 38 / 0.158 / 0.263 / 0.6 (0.196) / -12.9 (-2.9) / 1.0 | 113 / 0.23 / 0.265 / -5.3 | **NOT PROVEN** |
| T1R | NIFTY | CE | TRAIL | 18 / 0.389 / 0.269 / 1.448 (0.608) / +1.3 (-7.9) / 1.0 | 20 / 0.55 / 0.328 / +5.1 | **NOT PROVEN** |
| T1R | NIFTY | CE | VWAP | 18 / 0.278 / 0.261 / 1.064 (0.392) / -0.3 (-2.1) / 1.0 | 20 / 0.4 / 0.255 / +1.4 | **NOT PROVEN** |
| LIVE05 | NIFTY | PE | TRAIL | 60 / 0.45 / 0.37 / 1.216 (0.856) / +8.9 (+1.6) / 1.0 | 122 / 0.32 / 0.335 / -3.4 | **NOT PROVEN** |
| LIVE05 | NIFTY | PE | VWAP | 60 / 0.333 / 0.288 / 1.156 (0.757) / +4.9 (+0.3) / 1.0 | 122 / 0.303 / 0.258 / -0.7 | **NOT PROVEN** |
| LIVE08 | NIFTY | PE | TRAIL | 26 / 0.385 / 0.386 / 0.997 (0.505) / +5.3 (+2.6) / 1.0 | 51 / 0.392 / 0.323 / +0.1 | **NOT PROVEN** |
| LIVE08 | NIFTY | PE | VWAP | 26 / 0.308 / 0.3 / 1.026 (0.48) / +0.5 (+0.9) / 1.0 | 51 / 0.373 / 0.265 / +3.3 | **NOT PROVEN** |
| LIVE08_ALL | NIFTY | PE | TRAIL | 13 / 0.615 / 0.387 / 1.589 (0.898) / +21.1 (+3.6) / 1.0 | 22 / 0.455 / 0.33 / +6.9 | **NOT PROVEN** |
| LIVE08_ALL | NIFTY | PE | VWAP | 13 / 0.462 / 0.297 / 1.552 (0.738) / +12.5 (+1.7) / 1.0 | 22 / 0.455 / 0.241 / +10.7 | **NOT PROVEN** |
| LIVE08_BR | NIFTY | PE | TRAIL | 20 / 0.45 / 0.368 / 1.222 (0.664) / +10.7 (+2.1) / 1.0 | 40 / 0.4 / 0.323 / +0.8 | **NOT PROVEN** |
| LIVE08_BR | NIFTY | PE | VWAP | 20 / 0.35 / 0.297 / 1.18 (0.489) / +4.1 (+0.9) / 1.0 | 40 / 0.4 / 0.263 / +4.3 | **NOT PROVEN** |
| LIVE08_PB | NIFTY | PE | TRAIL | 15 / 0.6 / 0.384 / 1.561 (0.829) / +20.4 (+0.9) / 1.0 | 29 / 0.448 / 0.301 / +3.7 | **NOT PROVEN** |
| LIVE08_PB | NIFTY | PE | VWAP | 15 / 0.467 / 0.311 / 1.5 (0.677) / +13.0 (+0.2) / 1.0 | 29 / 0.414 / 0.237 / +7.2 | **NOT PROVEN** |
| LIVE08_RBI | NIFTY | PE | TRAIL | 10 / 0.3 / 0.377 / 0.796 (0.0) / -2.0 (-0.1) / 1.0 | 15 / 0.333 / 0.362 / +6.0 | **NOT PROVEN** |
| LIVE08_RBI | NIFTY | PE | VWAP | 10 / 0.2 / 0.303 / 0.659 (0.0) / -6.6 (+1.6) / 1.0 | 15 / 0.333 / 0.289 / +5.4 | **NOT PROVEN** |
| LIVE08_RX | NIFTY | PE | TRAIL | 25 / 0.4 / 0.351 / 1.141 (0.619) / +5.9 (-0.2) / 1.0 | 51 / 0.392 / 0.333 / +0.1 | **NOT PROVEN** |
| LIVE08_RX | NIFTY | PE | VWAP | 25 / 0.32 / 0.329 / 0.972 (0.453) / +1.6 (+0.9) / 1.0 | 51 / 0.373 / 0.256 / +3.3 | **NOT PROVEN** |
| LIVE08_SL | NIFTY | PE | TRAIL | 26 / 0.385 / 0.391 / 0.984 (0.493) / +5.3 (+3.2) / 1.0 | 49 / 0.408 / 0.329 / +1.3 | **NOT PROVEN** |
| LIVE08_SL | NIFTY | PE | VWAP | 26 / 0.308 / 0.271 / 1.137 (0.508) / +0.5 (-1.3) / 1.0 | 49 / 0.388 / 0.26 / +4.2 | **NOT PROVEN** |
| LIVE12 | NIFTY | PE | TRAIL | n 3 | 12 / 0.25 / 0.283 / -10.5 | **NOT PROVEN** |
| LIVE12 | NIFTY | PE | VWAP | n 3 | 12 / 0.25 / 0.261 / -2.7 | **NOT PROVEN** |
| ORB | NIFTY | PE | TRAIL | 71 / 0.38 / 0.38 / 1.0 (0.704) / +5.2 (+1.4) / 1.0 | 183 / 0.328 / 0.332 / -3.3 | **NOT PROVEN** |
| ORB | NIFTY | PE | VWAP | 71 / 0.282 / 0.288 / 0.977 (0.627) / +2.8 (+0.1) / 1.0 | 183 / 0.246 / 0.269 / -3.2 | **NOT PROVEN** |
| ORB_ALL | NIFTY | PE | TRAIL | 48 / 0.438 / 0.369 / 1.186 (0.811) / +9.6 (+0.1) / 1.0 | 110 / 0.382 / 0.316 / -0.2 | **NOT PROVEN** |
| ORB_ALL | NIFTY | PE | VWAP | 48 / 0.271 / 0.294 / 0.92 (0.499) / +4.3 (+0.4) / 1.0 | 110 / 0.309 / 0.273 / -0.6 | **NOT PROVEN** |
| T1R | NIFTY | PE | TRAIL | 16 / 0.312 / 0.365 / 0.857 (0.33) / +2.2 (+0.7) / 1.0 | 27 / 0.222 / 0.34 / -2.4 | **NOT PROVEN** |
| T1R | NIFTY | PE | VWAP | 16 / 0.312 / 0.323 / 0.968 (0.353) / +4.8 (+2.5) / 1.0 | 27 / 0.222 / 0.269 / +2.3 | **NOT PROVEN** |

Rules: LIVE08 = move >= 0.8% from the day low, index above VWAP, heavyweights met (THE LIVE RULE) · LIVE05 = same, move >= 0.5% · LIVE12 = same, move >= 1.2% · T1R = gap-down >= 0.3% reclaimed: above VWAP, heavyweights met, move >= 0.5% from the low · ORB = above the 09:15-09:30 range high, above VWAP, heavyweights met · LIVE08_RX = LIVE08 + day range so far >= 0.6 x ADR20 (range expansion) · LIVE08_SL = LIVE08 + VWAP rising over the last 30 min · LIVE08_BR = LIVE08 + breadth >= 60% of F&O shares up · LIVE08_PB = LIVE08 + PVT BANK leading NIFTY · LIVE08_ALL = LIVE08 + VWAP rising + breadth + PVT BANK leading · ORB_ALL = ORB + VWAP rising + breadth >= 60% · LIVE08_RBI = LIVE08 on an RBI cash-injection day

## Fri 20 Nov - what each rule said at each check time

**BANKNIFTY** (gap -0.64%, close +2.49%)

| check | day % | from low % | above VWAP | heavyweights above | breadth up | VWAP rising | PVT BANK leads | CE rules firing | PE rules | hold to 15:10, VWAP exit: index % / option % / exit | TRAIL exit: index % / option % / exit |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 10:00 | +0.23 | 0.97 | yes | 5 of 5 | 43% | yes | yes | LIVE08, LIVE05, T1R, ORB, LIVE08_RX, LIVE08_SL, LIVE08_PB, LIVE08_RBI | none | +2.16 / +76.3 / 15:10  | +2.16 / +76.3 / 15:10  |
| 10:30 | +0.17 | 0.92 | yes | 5 of 5 | 41% | yes | yes | LIVE08, LIVE05, T1R, ORB, LIVE08_RX, LIVE08_SL, LIVE08_PB, LIVE08_RBI | none | +2.22 / +78.3 / 15:10  | +2.22 / +78.3 / 15:10  |
| 11:00 | +0.49 | 1.23 | yes | 4 of 5 | 44% | yes | yes | LIVE08, LIVE05, LIVE12, T1R, ORB, LIVE08_RX, LIVE08_SL, LIVE08_PB, LIVE08_RBI | none | +1.90 / +65.2 / 15:10  | +1.90 / +65.2 / 15:10  |
| 11:30 | +0.45 | 1.19 | yes | 3 of 5 | 43% | yes | yes | none | none | +1.94 / +64.9 / 15:10  | +1.94 / +64.9 / 15:10  |

**NIFTY** (gap -0.57%, close +1.12%)

| check | day % | from low % | above VWAP | heavyweights above | breadth up | VWAP rising | PVT BANK leads | CE rules firing | PE rules | hold to 15:10, VWAP exit: index % / option % / exit | TRAIL exit: index % / option % / exit |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 10:00 | +0.04 | 0.71 | yes | 6 of 8 | 43% | yes | yes | LIVE05, T1R, ORB | none | +0.99 / +81.3 / 15:10  | +0.99 / +81.3 / 15:10  |
| 10:30 | +0.05 | 0.72 | yes | 5 of 8 | 41% | yes | yes | none | none | +0.98 / +85.5 / 15:10  | +0.98 / +85.5 / 15:10  |
| 11:00 | +0.12 | 0.79 | yes | 6 of 8 | 44% | yes | yes | LIVE05, T1R, ORB | none | +0.90 / +75.2 / 15:10  | +0.90 / +75.2 / 15:10  |
| 11:30 | +0.11 | 0.78 | yes | 4 of 8 | 43% | yes | yes | none | none | +0.92 / +77.3 / 15:10  | +0.92 / +77.3 / 15:10  |

(The 20 Nov RBI VRR result came at 10:20; the operations file dates it 20 Nov, so rbi_day = yes for the whole day in the study - live, the line names RBI only once the operation is in the file / regs feed.)

## What this means for the desk

- The live TREND DAY line (LIVE08) runs from Mon 23 Nov as grade B: READY - your call, never BUY, max 2 a day per index, WOULD SEND until the ring test passes.
- Grade A only for a rule in v2/models/trend_day_passed.json, and only through the index-desk agreement (every check PASS, the Devil answered).
- Lesson file: v2/data/trend_day_lesson.json. Every line is scored at 15:45 (v2/data/desk/trendday_lines.jsonl) and has its own section in the Friday week-1 scorecard.

## LIVE RULE REPLAY OF 2026-11-20 through the live rule (analyst/trendday.py)

Recorded minutes girdata/minute/2026-11-20: futures (November contract, own volume -> VWAP), index, heavyweights' own VWAP. Cause from the RBI operations file at that minute (regs feed off in the replay). Send = WOULD SEND (replay); live it is sheet.emit: WOULD SEND until the ring test passes.

### 10:00 IST - BANKNIFTY CE (grade B, WOULD SEND (replay))

```
BANKNIFTY TREND DAY · CE SIDE
• +1.0% from the day low
• 5 of 5 banks above VWAP
• Cause: PVT BANK leads NIFTY
• READY - your call
• Dec ATM CE
• Stop: futures VWAP 62,936
• Grade B - not proven
```

Gate: clean · longest line 29 · futures 63140.0 vs VWAP 62936.4 · score: held to 15:10 2.22%, with the VWAP stop 2.22% (exit 15:10), best 2.39%

### 10:38 IST - NIFTY CE (grade B, WOULD SEND (replay))

```
NIFTY TREND DAY · CE SIDE
• +0.8% from the day low
• 6 of 8 heavyweights above VWAP
• Cause: RBI cash
• READY - your call
• Next weekly ATM CE
• Stop: futures VWAP 25,450
• Grade B - not proven
```

Gate: clean · longest line 32 · futures 25518.4 vs VWAP 25449.5 · score: held to 15:10 0.99%, with the VWAP stop 0.99% (exit 15:10), best 1.14%

### The rule at each check time

| time | index | from low % | from high % | futures vs VWAP | heavyweights above | rule |
|---|---|---|---|---|---|---|
| 10:00 | BANKNIFTY | 0.97 | 0.13 | above | 5 of 5 | CE |
| 10:30 | BANKNIFTY | 0.92 | 0.19 | above | 5 of 5 | CE |
| 11:00 | BANKNIFTY | 1.23 | 0.08 | above | 4 of 5 | CE |
| 11:30 | BANKNIFTY | 1.19 | 0.17 | above | 3 of 5 | - |
| 12:00 | BANKNIFTY | 1.92 | 0.07 | above | 5 of 5 | CE |
| 12:30 | BANKNIFTY | 2.51 | 0.04 | above | 5 of 5 | CE |
| 13:00 | BANKNIFTY | 2.67 | 0.28 | above | 5 of 5 | CE |
| 14:00 | BANKNIFTY | 2.98 | 0.03 | above | 5 of 5 | CE |
| 10:00 | NIFTY | 0.71 | 0.08 | above | 6 of 8 | - |
| 10:30 | NIFTY | 0.72 | 0.07 | above | 5 of 8 | - |
| 11:00 | NIFTY | 0.79 | 0.1 | above | 6 of 8 | - |
| 11:30 | NIFTY | 0.78 | 0.12 | above | 4 of 8 | - |
| 12:00 | NIFTY | 1.08 | 0.03 | above | 7 of 8 | CE |
| 12:30 | NIFTY | 1.39 | 0.02 | above | 8 of 8 | CE |
| 13:00 | NIFTY | 1.42 | 0.16 | above | 6 of 8 | CE |
| 14:00 | NIFTY | 1.58 | 0.01 | above | 6 of 8 | CE |
