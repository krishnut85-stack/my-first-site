# PART 8 - WEEKEND INDEX TESTS (DESK_REVIEW 21 Nov 17:00 / 17:15) - 2026-11-21

Code only, $0. Every trigger is tested with its exact PE mirror (trader rule 9). NOT used anywhere until the desk reads v2/models/index_triggers_passed.json.

## THE ANSWER IN PLAIN WORDS
- (1) ALL 22 index triggers FAIL (11 triggers x CE / PE, NIFTY and BANKNIFTY). Not one passed even the TUNING years (Nov 2023 - Dec 2025) on
  either index, so nothing reached the unseen 2026 test with a chance. Closest on 2026: T1 CE on NIFTY (n 46, hit 28% vs 13% random, lift lb
  1.14, option proxy +2.1%) - but BANKNIFTY disagrees (lb 0.32) and it failed tuning; VWR2 CE on NIFTY (lb 1.09). GAPHOLD: only 3-8 days
  (index gaps of 1%+ are rare). -> index_triggers_passed.json is EMPTY: every index idea stays WATCH (grade B at most), NOT PROVEN.
- A random 60-min ATM option trade at the same minute averages -1.0% to -2.2% (theta + spread twice + costs): a trigger must beat that.
- (2) Gap days: big index gaps rarely fill the same day (gap up 1%+: NIFTY 6%, BANKNIFTY 0%); gap-down days closed above the open 56-65%.
  Descriptive, not tested triggers.
- (3) Calibration: 2 recorded days of NIFTY / BANKNIFTY ATM IV: December IV = 0.82 x VIX (NIFTY), 0.96 x VIX (BANKNIFTY); near-expiry IV
  differs (expiry eve). No recorded index-option bid / ask on the server: spread assumed 0.4%, paid twice.
- (4) Expiry day / pre-holiday: no different from other days in 3 years (and no direction effect in the long calendar test).

## (1) INDEX TRIGGER HARNESS

DATA (labelled): near-month futures minutes exist for only 17 days (16 Oct - 20 Nov 2026), so the INDEX minutes are the proxy: NIFTY ['2023-12-18', '2026-11-19', 721], BANKNIFTY ['2023-12-18', '2026-11-19', 721] (start, end, days). Index minutes have no volume: VWAP and T3's volume use the heavyweights' minute traded value (VOLUME PROXY). Proxy check on the futures days - VWAP side agrees with real futures VWAP: NIFTY 0.951 of minutes (mean distance gap 0.052%), BANKNIFTY 0.938 (0.056%).
HIT = 0.35 x ADR20 its way before 0.22 x ADR20 against within 60 min (15:10 latest). OPTION PROXY = Black-Scholes ATM at India VIX (BANKNIFTY x 0.96, NIFTY x 0.82 from part 3), IV from the day's VIX open to its close, theta, -30% premium stop, full spread 0.4% paid on entry AND exit, costs. RANDOM = the same minute on 30 random days of the same period. TUNE Nov 2023 - Dec 2025, SCORE 2026 (H1 + H2 to 19 Nov). PASS = both indices: tune n >= 100 + lift lb > 1.1; score n >= 30, lift lb > 1.1, Holm p < 0.05 (over 42 score tests), option expectancy > 0.

| trigger | side | NIFTY score: n / hit / random / lift (lb) / Holm p / option exp % | BANKNIFTY score: same | tune n N / B | lift lb tune N / B | indices agree | verdict |
|---|---|---|---|---|---|---|---|
| ORB5 | CE | 103 / 0.1553 / 0.1673 / 0.928 (0.528) / 1.0 / -0.32 | 96 / 0.1458 / 0.1865 / 0.782 (0.436) / 1.0 / -0.95 | 262 / 256 | 0.625 / 0.618 | no | **FAIL** |
| ORB5 | PE | 109 / 0.1835 / 0.1722 / 1.066 (0.652) / 1.0 / -5.3 | 97 / 0.1753 / 0.1708 / 1.026 (0.607) / 1.0 / -2.63 | 305 / 275 | 0.696 / 0.655 | no | **FAIL** |
| ORB15 | CE | 112 / 0.125 / 0.1372 / 0.911 (0.506) / 1.0 / -2.32 | 99 / 0.1111 / 0.1448 / 0.767 (0.353) / 1.0 / -1.09 | 265 / 257 | 0.57 / 0.654 | no | **FAIL** |
| ORB15 | PE | 108 / 0.1389 / 0.1414 / 0.983 (0.548) / 1.0 / -4.57 | 94 / 0.1383 / 0.144 / 0.961 (0.496) / 1.0 / -2.47 | 283 / 266 | 0.691 / 0.799 | no | **FAIL** |
| PDH | CE | 76 / 0.1316 / 0.1531 / 0.86 (0.381) / 1.0 / -2.16 | 77 / 0.1039 / 0.1636 / 0.635 (0.244) / 1.0 / -1.45 | 185 / 205 | 0.689 / 0.728 | no | **FAIL** |
| PDH | PE | 71 / 0.1831 / 0.1559 / 1.175 (0.638) / 1.0 / 1.07 | 73 / 0.1918 / 0.1342 / 1.429 (0.764) / 1.0 / -1.8 | 182 / 188 | 0.86 / 0.906 | no | **FAIL** |
| DHB | CE | 102 / 0.0784 / 0.0984 / 0.797 (0.295) / 1.0 / -3.57 | 108 / 0.1204 / 0.1198 / 1.005 (0.493) / 1.0 / -1.0 | 255 / 238 | 0.648 / 0.76 | no | **FAIL** |
| DHB | PE | 115 / 0.1739 / 0.1203 / 1.446 (0.876) / 1.0 / -2.04 | 100 / 0.14 / 0.117 / 1.197 (0.605) / 1.0 / -0.96 | 271 / 227 | 0.825 / 0.917 | no | **FAIL** |
| VWR2 | CE | 166 / 0.1807 / 0.1139 / 1.587 (1.086) / 0.5782 / 0.06 | 183 / 0.1421 / 0.1118 / 1.27 (0.836) / 1.0 / -1.38 | 400 / 404 | 1.056 / 0.977 | no | **FAIL** |
| VWR2 | PE | 174 / 0.1264 / 0.1239 / 1.02 (0.631) / 1.0 / -1.62 | 186 / 0.1452 / 0.1116 / 1.3 (0.872) / 1.0 / -0.92 | 388 / 399 | 1.028 / 0.891 | no | **FAIL** |
| GAPHOLD | CE | n 3 | 6 / 0.1667 / 0.2111 / 0.789 (0.0) / 1.0 / -3.11 | 5 / 4 | 0.0 / None | no | **FAIL** |
| GAPHOLD | PE | n 4 | 8 / 0.25 / 0.1958 / 1.277 (0.0) / 1.0 / 1.16 | 1 / 2 | None / None | no | **FAIL** |
| T1 | CE | 46 / 0.2826 / 0.1341 / 2.108 (1.135) / 0.5366 / 2.1 | 52 / 0.1538 / 0.1808 / 0.851 (0.32) / 1.0 / -0.87 | 66 / 79 | 0.564 / 0.334 | no | **FAIL** |
| T1 | PE | 43 / 0.2093 / 0.1442 / 1.452 (0.702) / 1.0 / -2.23 | 48 / 0.1875 / 0.1562 / 1.2 (0.529) / 1.0 / -3.85 | 107 / 105 | 0.631 / 0.673 | no | **FAIL** |
| T2 | CE | 186 / 0.1344 / 0.1165 / 1.154 (0.755) / 1.0 / -2.39 | 180 / 0.1444 / 0.1222 / 1.182 (0.77) / 1.0 / -1.63 | 410 / 406 | 0.79 / 0.677 | no | **FAIL** |
| T2 | PE | 178 / 0.1124 / 0.1358 / 0.828 (0.496) / 1.0 / -3.68 | 178 / 0.1124 / 0.1331 / 0.844 (0.514) / 1.0 / -1.14 | 408 / 411 | 0.782 / 0.777 | no | **FAIL** |
| T3 | CE | 33 / 0.1818 / 0.096 / 1.895 (0.652) / 1.0 / -3.67 | 46 / 0.1522 / 0.1065 / 1.429 (0.539) / 1.0 / -1.13 | 69 / 95 | 0.973 / 0.638 | no | **FAIL** |
| T3 | PE | 29 / 0.1379 / 0.1241 / 1.111 (0.261) / 1.0 / -4.7 | 28 / 0.2143 / 0.1012 / 2.118 (0.706) / 1.0 / 3.28 | 76 / 80 | 0.33 / 0.478 | no | **FAIL** |
| GAPFILL | CE | 26 / 0.1538 / 0.1295 / 1.188 (0.268) / 1.0 / -5.24 | 30 / 0.2 / 0.1644 / 1.216 (0.414) / 1.0 / 0.32 | 49 / 61 | 0.388 / 0.543 | no | **FAIL** |
| GAPFILL | PE | 23 / 0.1304 / 0.1449 / 0.9 (0.0) / 1.0 / -4.47 | 25 / 0.16 / 0.152 / 1.053 (0.254) / 1.0 / -3.46 | 79 / 75 | 0.727 / 0.703 | no | **FAIL** |
| RSI50 | CE | 136 / 0.0956 / 0.088 / 1.086 (0.555) / 1.0 / -1.2 | 138 / 0.1087 / 0.1046 / 1.039 (0.561) / 1.0 / -0.81 | 316 / 345 | 0.651 / 0.756 | no | **FAIL** |
| RSI50 | PE | 140 / 0.1357 / 0.1202 / 1.129 (0.675) / 1.0 / -0.54 | 151 / 0.0993 / 0.1121 / 0.886 (0.508) / 1.0 / -2.26 | 339 / 339 | 1.094 / 0.877 | no | **FAIL** |

Trigger definitions: ORB5 = opening 5-min range break (09:20-10:00) · ORB15 = opening 15-min range break (09:30-10:45) · PDH = yesterday's high break (CE) / low break (PE), a fresh cross · DHB = day-high (low) break, the old extreme 15+ min old, from 09:30 · VWR2 = VWAP reclaim (loss): 10 of 15 bars on the wrong side, then 2 closes over · GAPHOLD = gap of 1%+ held at 09:30 · T1 = gap-down (up) >= 0.3%, then two 5-min closes back above (below) VWAP · T2 = a 5-min dip tagging VWAP within 0.1% that closes above (PE: a rally tagging it that closes below), after 3 bars on that side · T3 = 5-min close breaking the opening-range (09:15-09:30) high or yesterday's high on volume >= 1.5x the 20-bar average, RSI 50-75 rising (PE: low, RSI 25-50 falling) · GAPFILL = gap-down (up) >= 0.3%: price crosses back through half the gap (betting on the fill) · RSI50 = 5-min RSI(14) crosses 50 upward with price above VWAP (PE: downward, below VWAP)

Option-proxy expectancy of the RANDOM same-time entries (score, NIFTY CE / PE): see the json (random_exp_pct) - it shows what the costs + theta take from any 60-min ATM option trade.

**PASSED: NONE** -> v2/models/index_triggers_passed.json. The rest stay WATCH (grade B at most).

## (2) GAP-DAY PATH TABLES (index minutes, Nov 2023 - Nov 2026)

**NIFTY**

| day type | n (2023-25 / 2026) | close vs open | close above open | gap filled same day | first-15-min low (median) | first-15-min high | best CE window | best PE window |
|---|---|---|---|---|---|---|---|---|
| gap up >= 0.5% | 66 (38 / 28) | +0.03% | 55% | 18% | -0.21% | +0.12% | 11:00-13:00 (+0.03%, up 50%) | 09:15-09:30 (-0.07%, up 47%) |
| gap up >= 1% | 18 (9 / 9) | -0.04% | 44% | 6% | -0.29% | +0.12% | 11:00-13:00 (+0.09%, up 55%) | 09:15-09:30 (-0.16%, up 50%) |
| gap down <= -0.5% | 56 (26 / 30) | +0.07% | 61% | 20% | -0.15% | +0.24% | 13:00-14:30 (+0.04%, up 50%) | 14:30-15:10 (-0.01%, up 44%) |
| gap down <= -1% | 16 (7 / 9) | +0.16% | 56% | 6% | -0.09% | +0.42% | 09:15-09:30 (+0.20%, up 68%) | 11:00-13:00 (-0.12%, up 56%) |
| US-shock day (Nasdaq <= -2% the US session before) | 41 (28 / 13) | +0.10% | 58% | 44% | -0.14% | +0.23% | 11:00-13:00 (+0.06%, up 51%) | 10:00-11:00 (-0.04%, up 51%) |
| all days | 721 (503 / 218) | -0.02% | 48% | 66% | -0.17% | +0.13% | 09:30-10:00 (+0.01%, up 51%) | 09:15-09:30 (-0.02%, up 46%) |

**BANKNIFTY**

| day type | n (2023-25 / 2026) | close vs open | close above open | gap filled same day | first-15-min low (median) | first-15-min high | best CE window | best PE window |
|---|---|---|---|---|---|---|---|---|
| gap up >= 0.5% | 89 (61 / 28) | +0.00% | 46% | 35% | -0.34% | +0.15% | 11:00-13:00 (+0.04%, up 42%) | 09:15-09:30 (-0.08%, up 43%) |
| gap up >= 1% | 24 (12 / 12) | +0.29% | 62% | 0% | -0.40% | +0.21% | 13:00-14:30 (+0.17%, up 75%) | 09:15-09:30 (-0.13%, up 41%) |
| gap down <= -0.5% | 77 (42 / 35) | +0.10% | 64% | 35% | -0.18% | +0.34% | 09:15-09:30 (+0.07%, up 59%) | 14:30-15:10 (-0.03%, up 42%) |
| gap down <= -1% | 23 (11 / 12) | +0.12% | 65% | 13% | -0.16% | +0.48% | 09:15-09:30 (+0.21%, up 65%) | 11:00-13:00 (-0.10%, up 47%) |
| US-shock day (Nasdaq <= -2% the US session before) | 41 (28 / 13) | +0.11% | 63% | 56% | -0.17% | +0.31% | 11:00-13:00 (+0.13%, up 58%) | 10:00-11:00 (-0.06%, up 41%) |
| all days | 721 (503 / 218) | +0.03% | 49% | 70% | -0.21% | +0.21% | 13:00-14:30 (+0.01%, up 48%) | 10:00-11:00 (+0.00%, up 51%) |

Path tables are descriptive (all years together): a 'best window' is where the average move was, not a tested trigger.

## (3) OPTION-PROXY CALIBRATION

Recorded index option data on the server: atmiv rows 1925 on ['2026-11-19', '2026-11-20'] (NIFTY / BANKNIFTY ATM IV + straddle). IV / India VIX: {"BANKNIFTY near": {"n": 366, "median": 1.222}, "BANKNIFTY Dec": {"n": 366, "median": 0.956}, "NIFTY near": {"n": 732, "median": 0.898}, "NIFTY Dec": {"n": 366, "median": 0.823}}. Real straddle / Black-Scholes straddle at VIX: {"BANKNIFTY near": {"n": 366, "median": 1.383}, "BANKNIFTY Dec": {"n": 366, "median": 1.076}, "NIFTY near": {"n": 732, "median": 1.016}, "NIFTY Dec": {"n": 366, "median": 0.927}}. no recorded bid / ask for NIFTY / BANKNIFTY options on the server (opt_dec = stock options); spread kept at 0.4% of the premium, paid twice. chainlive.db pins: no NIFTY / BANKNIFTY rows.
Two days is a first calibration only; the IV ratios used in (1) come from it.

## (4) EXPIRY DAY + PRE-HOLIDAY (index minutes)

**NIFTY**: monthly expiry day: n 36, close vs prev +0.02% (abs 0.53), open-to-close +0.13%, after 13:00 +0.10% (abs 0.27), range 0.98% · day before an NSE holiday: n 47, close vs prev -0.12% (abs 0.51), open-to-close +0.03%, after 13:00 -0.04% (abs 0.31), range 0.99% · other days: n 642, close vs prev +0.04% (abs 0.63), open-to-close -0.03%, after 13:00 +0.00% (abs 0.27), range 0.98%

**BANKNIFTY**: monthly expiry day: n 36, close vs prev -0.04% (abs 0.63), open-to-close +0.11%, after 13:00 +0.07% (abs 0.35), range 1.22% · day before an NSE holiday: n 47, close vs prev -0.09% (abs 0.60), open-to-close +0.10%, after 13:00 -0.01% (abs 0.36), range 1.26% · other days: n 642, close vs prev +0.05% (abs 0.73), open-to-close +0.01%, after 13:00 +0.02% (abs 0.31), range 1.20%

Descriptive only (3 years); the long-history calendar test is upgrades/u8_calendar.md (expiry / pre-holiday direction: nothing holds).

Note for the desk: the OPEN lean uses the simple NQ line (M1 failed against it - models_M1.md), not M1.
