# After a big Nasdaq fall, what does India do next?

GIR research study, made 21 Nov 2026 10:19 IST, pure code (no AI calls). Research only - GIR places no orders. Base rates from history are a guide, not a forecast.
Script: v2/kb/us_shock_study.py. Raw data: /home/globalbot/girdata/ext/us_shock_study/raw/ (Yahoo daily bars, saved untouched).

## How it is measured
- A US event day = a US session where the index closed that much below the previous US close (Nasdaq Composite <= -3%, the subset <= -4.5%; separately S&P 500 <= -2.5%).
- The US close lands after India's close, so the India session measured is the NEXT India trading day after the US date (Friday US -> Monday India; Indian holidays skipped using India's own trading days).
- All India numbers are vs India's previous close (the close before that next session): gap = open, low, high, close. 'Recovered within 5 sessions' = a close at or above that previous close on any of the next 5 India sessions, counting the next session itself.
- 'Opened lower then closed positive' is counted only over the sessions that opened lower.
- History: India daily from 2007-09-17 (Yahoo ^NSEI starts Sep 2007), so US events before that are not usable; the study window is Sep 2007 -> 20 Nov 2026.
- Events cluster (2008, 2020, 2022): many rows come from a few crisis months. The 'since 2011' row shows how much 2008-10 drives the result.

## The case now: US close of Friday 20 Nov 2026 (no India outcome yet)
- Nasdaq Composite -5.28%, S&P 500 -3.70% (Yahoo). The US day before (19 Nov): Nasdaq -2.25%, S&P -2.02% -> two US down days in a row.
- It is a Friday, so the India session to watch is Monday 23 Nov. India closed UP on 20 Nov (NIFTY +1.12%).
- Asia on 20 Nov (US date): Nikkei -5.06%, KOSPI -5.21%, Taiwan -6.23%, Hang Seng -1.89%. Asia for 23 Nov is not known yet.
- It matches all three event sets, and splits (a) Friday, (b) India up on the day, (c) two US down days.

## In plain words
- After a Nasdaq Composite fall of 3%+ (n=122 US days, Sep 2007 -> 19 Nov 2026), NIFTY's next session opened lower 81% (62 of 77) and closed lower 73% (89 of 122). Median gap -0.87%, median close -0.92%.
- The open was usually not the low: NIFTY's median low was -1.94% vs a median gap of -0.87%, so the typical session went about another 1% below its open at some point. When it opened lower, it got back above the previous close by the close only 18% (11 of 62). It closed above its own open 56% (43 of 77).
- Timing of the low (minute data only from Nov 2023, so n is small): NIFTY's low came within the first 15 minutes in 9 of 13 events (median 2 minutes after 09:15); BANKNIFTY 6 of 13 (median 15 min). In older years: not available.
- Within 5 sessions NIFTY closed back at or above the pre-event close 65% (79 of 122).
- Bigger falls (Nasdaq <= -4.5%, n=31): closed lower 77% (24 of 31), median close -1.68%. S&P 500 <= -2.5% (n=130): closed lower 73% (95 of 130), median close -0.96% - nearly the same picture as Nasdaq <= -3%.
- Friday US fall -> Monday India (Nasdaq <= -3%, n=20): closed lower 85% (17 of 20), median close -1.38%, worse than other weekdays.
- India having risen on the US-fall day did not protect it: closed lower 86% (32 of 37) vs 67% (57 of 85) when India was already down or flat.
- Sectors (Nasdaq <= -3%, common Sep 2011 window): held up best NIFTY FMCG -0.21%, NIFTY PHARMA -0.43%; worst NIFTY METAL -1.02%, NIFTY IT -1.17%. NIFTY IT had the weakest median next-session close of NIFTY / BANKNIFTY / IT in 24 of 29 event-set x split cuts with n >= 5.
- Same events from Nov 2021 only (n=31, the only window with PVT BANK): best NIFTY FMCG -0.16%, NIFTY PHARMA -0.28%; worst NIFTY REALTY -0.69%, NIFTY IT -0.98%; PVT BANK -0.42%, NIFTY 50 -0.37%.
- Small samples: the exact 20 Nov look-alike (Friday + India up + two US down days) has n=4 for Nasdaq <= -3% and n=0 for Nasdaq <= -4.5%. Do not lean on those rows.

## Headline base rates (NIFTY 50, next India session)

| event set | n | opened lower | closed lower | closed above its open | opened lower -> closed positive | back to prev close in 5 sessions | median gap | worst gap | median close |
|---|---|---|---|---|---|---|---|---|---|
| Nasdaq Composite <= -3% - all events | 122 | 81% (62 of 77) | 73% (89 of 122) | 56% (43 of 77) | 18% (11 of 62) | 65% (79 of 122) | -0.87% | -9.14% (2020-03-23) | -0.92% |
| Nasdaq Composite <= -3% - (a) Friday US fall -> next India session (Monday) | 20 | 93% (14 of 15) | 85% (17 of 20) | 53% (8 of 15) | 14% (2 of 14) | 55% (11 of 20) | -1.73% | -9.14% (2020-03-23) | -1.38% |
| Nasdaq Composite <= -3% - 20 Nov look-alike: Friday + India up + two US down days | 4 | 100% (2 of 2) | 75% (3 of 4) | 50% (1 of 2) | 0% (0 of 2) | 75% (3 of 4) | -1.87% | -3.31% (2020-05-04) | -0.18% |
| Nasdaq Composite <= -4.5% - all events | 31 | 89% (16 of 18) | 77% (24 of 31) | 56% (10 of 18) | 19% (3 of 16) | 55% (17 of 31) | -1.85% | -5.03% (2020-03-13) | -1.68% |
| Nasdaq Composite <= -4.5% - (a) Friday US fall -> next India session (Monday) | 2 | 100% (1 of 1) | 100% (2 of 2) | 100% (1 of 1) | 0% (0 of 1) | 50% (1 of 2) | -5.00% | -5.00% (2025-04-07) | -1.81% |
| Nasdaq Composite <= -4.5% - 20 Nov look-alike: Friday + India up + two US down days | 0 | | | | | | | | |
| S&P 500 <= -2.5% - all events | 130 | 82% (60 of 73) | 73% (95 of 130) | 59% (43 of 73) | 18% (11 of 60) | 63% (82 of 130) | -0.90% | -9.14% (2020-03-23) | -0.96% |
| S&P 500 <= -2.5% - (a) Friday US fall -> next India session (Monday) | 24 | 94% (15 of 16) | 92% (22 of 24) | 56% (9 of 16) | 7% (1 of 15) | 58% (14 of 24) | -1.41% | -9.14% (2020-03-23) | -1.69% |
| S&P 500 <= -2.5% - 20 Nov look-alike: Friday + India up + two US down days | 4 | 75% (3 of 4) | 75% (3 of 4) | 75% (3 of 4) | 0% (0 of 3) | 75% (3 of 4) | -0.62% | -3.31% (2020-05-04) | -0.34% |

## Nasdaq Composite <= -3% - all splits

| split | idx | n | opened lower | closed lower | closed > open | opened lower -> closed + | prev close in 5 s | median gap | worst gap | median low | median close | minutes open->low (median, n) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| all events | NIFTY | 122 | 81% (62 of 77) | 73% (89 of 122) | 56% (43 of 77) | 18% (11 of 62) | 65% (79 of 122) | -0.87 | -9.14 | -1.94 | -0.92 | 2 (n=13; low in first 15 min 9 of 13) |
|  | BANKNIFTY | 122 | 85% (104 of 122) | 69% (84 of 122) | 54% (66 of 122) | 29% (30 of 104) | 61% (74 of 122) | -1.19 | -9.87 | -2.76 | -0.91 | 15 (n=13; low in first 15 min 6 of 13) |
|  | IT | 122 | 86% (105 of 122) | 78% (95 of 122) | 48% (59 of 122) | 20% (21 of 105) | 58% (71 of 122) | -1.04 | -8.37 | -2.47 | -1.29 | 226 (n=1; low in first 15 min 0 of 1) |
| (a) Friday US fall -> next India session (Monday) | NIFTY | 20 | 93% (14 of 15) | 85% (17 of 20) | 53% (8 of 15) | 14% (2 of 14) | 55% (11 of 20) | -1.73 | -9.14 | -2.15 | -1.38 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 20 | 90% (18 of 20) | 70% (14 of 20) | 60% (12 of 20) | 33% (6 of 18) | 60% (12 of 20) | -1.67 | -9.87 | -2.73 | -1.77 | 20 (n=3; low in first 15 min 1 of 3) |
|  | IT | 20 | 95% (19 of 20) | 85% (17 of 20) | 45% (9 of 20) | 11% (2 of 19) | 40% (8 of 20) | -1.35 | -8.37 | -2.80 | -1.71 | not available |
| not a Friday | NIFTY | 102 | 77% (48 of 62) | 71% (72 of 102) | 56% (35 of 62) | 19% (9 of 48) | 67% (68 of 102) | -0.74 | -5.03 | -1.92 | -0.80 | 4.0 (n=10; low in first 15 min 7 of 10) |
|  | BANKNIFTY | 102 | 84% (86 of 102) | 69% (70 of 102) | 53% (54 of 102) | 28% (24 of 86) | 61% (62 of 102) | -1.15 | -6.37 | -2.76 | -0.83 | 8.5 (n=10; low in first 15 min 5 of 10) |
|  | IT | 102 | 84% (86 of 102) | 76% (78 of 102) | 49% (50 of 102) | 22% (19 of 86) | 62% (63 of 102) | -1.00 | -6.15 | -2.44 | -1.19 | 226 (n=1; low in first 15 min 0 of 1) |
| (b) India closed UP on the US-fall day | NIFTY | 37 | 88% (21 of 24) | 86% (32 of 37) | 50% (12 of 24) | 10% (2 of 21) | 51% (19 of 37) | -1.32 | -9.14 | -2.05 | -1.40 | 14 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 37 | 92% (34 of 37) | 78% (29 of 37) | 46% (17 of 37) | 18% (6 of 34) | 51% (19 of 37) | -1.75 | -9.87 | -2.64 | -1.76 | 0 (n=3; low in first 15 min 2 of 3) |
|  | IT | 37 | 92% (34 of 37) | 86% (32 of 37) | 32% (12 of 37) | 12% (4 of 34) | 41% (15 of 37) | -1.11 | -8.37 | -2.65 | -2.01 | 226 (n=1; low in first 15 min 0 of 1) |
| India closed down/flat on the US-fall day | NIFTY | 85 | 77% (41 of 53) | 67% (57 of 85) | 58% (31 of 53) | 22% (9 of 41) | 71% (60 of 85) | -0.75 | -5.03 | -1.82 | -0.38 | 1.5 (n=10; low in first 15 min 7 of 10) |
|  | BANKNIFTY | 85 | 82% (70 of 85) | 65% (55 of 85) | 58% (49 of 85) | 34% (24 of 70) | 65% (55 of 85) | -1.08 | -6.37 | -2.88 | -0.65 | 22.5 (n=10; low in first 15 min 4 of 10) |
|  | IT | 85 | 84% (71 of 85) | 74% (63 of 85) | 55% (47 of 85) | 24% (17 of 71) | 66% (56 of 85) | -0.99 | -6.58 | -2.40 | -1.18 | not available |
| (c) two US down days in a row | NIFTY | 61 | 81% (29 of 36) | 72% (44 of 61) | 53% (19 of 36) | 21% (6 of 29) | 69% (42 of 61) | -0.81 | -5.03 | -1.69 | -0.43 | 10.0 (n=8; low in first 15 min 5 of 8) |
|  | BANKNIFTY | 61 | 85% (52 of 61) | 66% (40 of 61) | 57% (35 of 61) | 33% (17 of 52) | 67% (41 of 61) | -1.07 | -6.37 | -2.49 | -0.64 | 11.0 (n=8; low in first 15 min 4 of 8) |
|  | IT | 61 | 84% (51 of 61) | 77% (47 of 61) | 52% (32 of 61) | 22% (11 of 51) | 59% (36 of 61) | -0.96 | -6.58 | -2.21 | -1.05 | not available |
| the US day before was up | NIFTY | 61 | 80% (33 of 41) | 74% (45 of 61) | 59% (24 of 41) | 15% (5 of 33) | 61% (37 of 61) | -0.90 | -9.14 | -2.24 | -1.00 | 1 (n=5; low in first 15 min 4 of 5) |
|  | BANKNIFTY | 61 | 85% (52 of 61) | 72% (44 of 61) | 51% (31 of 61) | 25% (13 of 52) | 54% (33 of 61) | -1.64 | -9.87 | -3.11 | -1.73 | 15 (n=5; low in first 15 min 2 of 5) |
|  | IT | 61 | 89% (54 of 61) | 79% (48 of 61) | 44% (27 of 61) | 19% (10 of 54) | 57% (35 of 61) | -1.21 | -8.37 | -2.71 | -1.67 | 226 (n=1; low in first 15 min 0 of 1) |
| (d) Asia <= -3% on India's next-session date | NIFTY | 54 | 89% (25 of 28) | 78% (42 of 54) | 50% (14 of 28) | 8% (2 of 25) | 61% (33 of 54) | -1.66 | -9.14 | -3.43 | -1.61 | 1 (n=5; low in first 15 min 5 of 5) |
|  | BANKNIFTY | 54 | 93% (50 of 54) | 76% (41 of 54) | 56% (30 of 54) | 22% (11 of 50) | 54% (29 of 54) | -2.19 | -9.87 | -3.72 | -1.79 | 30 (n=5; low in first 15 min 2 of 5) |
|  | IT | 54 | 93% (50 of 54) | 83% (45 of 54) | 43% (23 of 54) | 14% (7 of 50) | 52% (28 of 54) | -1.81 | -8.37 | -4.71 | -2.58 | 226 (n=1; low in first 15 min 0 of 1) |
| (d2) Asia <= -3% on the US date | NIFTY | 33 | 61% (11 of 18) | 55% (18 of 33) | 50% (9 of 18) | 36% (4 of 11) | 73% (24 of 33) | -0.62 | -5.03 | -2.09 | -0.27 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 33 | 76% (25 of 33) | 58% (19 of 33) | 61% (20 of 33) | 44% (11 of 25) | 70% (23 of 33) | -1.03 | -5.59 | -3.00 | -0.35 | 0 (n=3; low in first 15 min 2 of 3) |
|  | IT | 33 | 73% (24 of 33) | 67% (22 of 33) | 61% (20 of 33) | 29% (7 of 24) | 76% (25 of 33) | -0.99 | -6.15 | -2.74 | -1.23 | 226 (n=1; low in first 15 min 0 of 1) |
| events since 2011 (drops the 2008-10 cluster) | NIFTY | 77 | 81% (62 of 77) | 74% (57 of 77) | 56% (43 of 77) | 18% (11 of 62) | 64% (49 of 77) | -0.87 | -9.14 | -1.43 | -0.79 | 2 (n=13; low in first 15 min 9 of 13) |
|  | BANKNIFTY | 77 | 81% (62 of 77) | 68% (52 of 77) | 57% (44 of 77) | 27% (17 of 62) | 60% (46 of 77) | -0.98 | -9.87 | -1.69 | -0.75 | 15 (n=13; low in first 15 min 6 of 13) |
|  | IT | 77 | 86% (66 of 77) | 74% (57 of 77) | 51% (39 of 77) | 23% (15 of 66) | 53% (41 of 77) | -1.02 | -8.37 | -2.04 | -1.18 | 226 (n=1; low in first 15 min 0 of 1) |
| 20 Nov look-alike: Friday + India up + two US down days | NIFTY | 4 | 100% (2 of 2) | 75% (3 of 4) | 50% (1 of 2) | 0% (0 of 2) | 75% (3 of 4) | -1.87 | -3.31 | -0.95 | -0.18 | 19 (n=1; low in first 15 min 0 of 1) |
|  | BANKNIFTY | 4 | 100% (4 of 4) | 25% (1 of 4) | 75% (3 of 4) | 75% (3 of 4) | 75% (3 of 4) | -1.46 | -4.74 | -1.67 | +0.11 | 20 (n=1; low in first 15 min 0 of 1) |
|  | IT | 4 | 100% (4 of 4) | 100% (4 of 4) | 25% (1 of 4) | 0% (0 of 4) | 25% (1 of 4) | -0.64 | -3.28 | -2.27 | -1.82 | not available |

## Nasdaq Composite <= -4.5% - all splits

| split | idx | n | opened lower | closed lower | closed > open | opened lower -> closed + | prev close in 5 s | median gap | worst gap | median low | median close | minutes open->low (median, n) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| all events | NIFTY | 31 | 89% (16 of 18) | 77% (24 of 31) | 56% (10 of 18) | 19% (3 of 16) | 55% (17 of 31) | -1.85 | -5.03 | -3.80 | -1.68 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 31 | 84% (26 of 31) | 71% (22 of 31) | 61% (19 of 31) | 31% (8 of 26) | 55% (17 of 31) | -2.19 | -6.37 | -4.22 | -1.82 | 199 (n=3; low in first 15 min 1 of 3) |
|  | IT | 31 | 87% (27 of 31) | 81% (25 of 31) | 48% (15 of 31) | 15% (4 of 27) | 52% (16 of 31) | -2.23 | -6.58 | -5.07 | -2.65 | 226 (n=1; low in first 15 min 0 of 1) |
| (a) Friday US fall -> next India session (Monday) | NIFTY | 2 | 100% (1 of 1) | 100% (2 of 2) | 100% (1 of 1) | 0% (0 of 1) | 50% (1 of 2) | -5.00 | -5.00 | -4.60 | -1.81 | 0 (n=1; low in first 15 min 1 of 1) |
|  | BANKNIFTY | 2 | 50% (1 of 2) | 100% (2 of 2) | 50% (1 of 2) | 0% (0 of 1) | 50% (1 of 2) | -1.93 | -4.21 | -6.04 | -3.44 | 199 (n=1; low in first 15 min 0 of 1) |
|  | IT | 2 | 50% (1 of 2) | 50% (1 of 2) | 100% (2 of 2) | 0% (0 of 1) | 50% (1 of 2) | -3.24 | -6.58 | -5.58 | -1.16 | not available |
| not a Friday | NIFTY | 29 | 88% (15 of 17) | 76% (22 of 29) | 53% (9 of 17) | 20% (3 of 15) | 55% (16 of 29) | -1.72 | -5.03 | -3.61 | -1.68 | 171.5 (n=2; low in first 15 min 1 of 2) |
|  | BANKNIFTY | 29 | 86% (25 of 29) | 69% (20 of 29) | 62% (18 of 29) | 32% (8 of 25) | 55% (16 of 29) | -2.19 | -6.37 | -3.90 | -1.73 | 171.5 (n=2; low in first 15 min 1 of 2) |
|  | IT | 29 | 90% (26 of 29) | 83% (24 of 29) | 45% (13 of 29) | 15% (4 of 26) | 52% (15 of 29) | -2.23 | -6.15 | -5.07 | -2.83 | 226 (n=1; low in first 15 min 0 of 1) |
| (b) India closed UP on the US-fall day | NIFTY | 5 | 75% (3 of 4) | 80% (4 of 5) | 50% (2 of 4) | 0% (0 of 3) | 20% (1 of 5) | -1.62 | -4.00 | -2.05 | -1.63 | 1 (n=1; low in first 15 min 1 of 1) |
|  | BANKNIFTY | 5 | 80% (4 of 5) | 60% (3 of 5) | 60% (3 of 5) | 25% (1 of 4) | 60% (3 of 5) | -1.88 | -4.95 | -2.50 | -1.82 | 0 (n=1; low in first 15 min 1 of 1) |
|  | IT | 5 | 80% (4 of 5) | 80% (4 of 5) | 0% (0 of 5) | 0% (0 of 4) | 40% (2 of 5) | -2.41 | -3.43 | -3.70 | -3.36 | 226 (n=1; low in first 15 min 0 of 1) |
| India closed down/flat on the US-fall day | NIFTY | 26 | 93% (13 of 14) | 77% (20 of 26) | 57% (8 of 14) | 23% (3 of 13) | 62% (16 of 26) | -2.08 | -5.03 | -3.87 | -1.83 | 171.0 (n=2; low in first 15 min 1 of 2) |
|  | BANKNIFTY | 26 | 85% (22 of 26) | 73% (19 of 26) | 62% (16 of 26) | 32% (7 of 22) | 54% (14 of 26) | -2.23 | -6.37 | -4.29 | -1.89 | 271.0 (n=2; low in first 15 min 0 of 2) |
|  | IT | 26 | 88% (23 of 26) | 81% (21 of 26) | 58% (15 of 26) | 17% (4 of 23) | 54% (14 of 26) | -2.22 | -6.58 | -5.10 | -2.58 | not available |
| (c) two US down days in a row | NIFTY | 13 | 100% (6 of 6) | 69% (9 of 13) | 83% (5 of 6) | 33% (2 of 6) | 62% (8 of 13) | -2.52 | -5.03 | -3.51 | -1.34 | 0 (n=1; low in first 15 min 1 of 1) |
|  | BANKNIFTY | 13 | 92% (12 of 13) | 62% (8 of 13) | 77% (10 of 13) | 42% (5 of 12) | 69% (9 of 13) | -2.23 | -6.37 | -4.22 | -0.35 | 199 (n=1; low in first 15 min 0 of 1) |
|  | IT | 13 | 92% (12 of 13) | 69% (9 of 13) | 69% (9 of 13) | 33% (4 of 12) | 62% (8 of 13) | -2.51 | -6.58 | -5.47 | -2.47 | not available |
| the US day before was up | NIFTY | 18 | 83% (10 of 12) | 83% (15 of 18) | 42% (5 of 12) | 10% (1 of 10) | 50% (9 of 18) | -1.82 | -4.79 | -3.87 | -1.97 | 171.5 (n=2; low in first 15 min 1 of 2) |
|  | BANKNIFTY | 18 | 78% (14 of 18) | 78% (14 of 18) | 50% (9 of 18) | 21% (3 of 14) | 44% (8 of 18) | -2.12 | -5.59 | -4.33 | -2.31 | 171.5 (n=2; low in first 15 min 1 of 2) |
|  | IT | 18 | 83% (15 of 18) | 89% (16 of 18) | 33% (6 of 18) | 0% (0 of 15) | 44% (8 of 18) | -2.17 | -4.84 | -4.46 | -2.85 | 226 (n=1; low in first 15 min 0 of 1) |
| (d) Asia <= -3% on India's next-session date | NIFTY | 18 | 90% (9 of 10) | 83% (15 of 18) | 60% (6 of 10) | 11% (1 of 9) | 61% (11 of 18) | -2.86 | -5.03 | -4.67 | -2.34 | 0.5 (n=2; low in first 15 min 2 of 2) |
|  | BANKNIFTY | 18 | 94% (17 of 18) | 78% (14 of 18) | 72% (13 of 18) | 18% (3 of 17) | 61% (11 of 18) | -3.31 | -6.37 | -4.70 | -2.23 | 99.5 (n=2; low in first 15 min 1 of 2) |
|  | IT | 18 | 94% (17 of 18) | 83% (15 of 18) | 44% (8 of 18) | 12% (2 of 17) | 56% (10 of 18) | -2.56 | -6.58 | -6.14 | -3.52 | 226 (n=1; low in first 15 min 0 of 1) |
| (d2) Asia <= -3% on the US date | NIFTY | 13 | 71% (5 of 7) | 54% (7 of 13) | 86% (6 of 7) | 40% (2 of 5) | 62% (8 of 13) | -1.12 | -5.03 | -3.51 | -0.27 | 1 (n=1; low in first 15 min 1 of 1) |
|  | BANKNIFTY | 13 | 85% (11 of 13) | 46% (6 of 13) | 85% (11 of 13) | 55% (6 of 11) | 69% (9 of 13) | -2.23 | -5.59 | -4.37 | +0.10 | 0 (n=1; low in first 15 min 1 of 1) |
|  | IT | 13 | 85% (11 of 13) | 62% (8 of 13) | 77% (10 of 13) | 36% (4 of 11) | 77% (10 of 13) | -2.51 | -6.15 | -4.88 | -1.73 | 226 (n=1; low in first 15 min 0 of 1) |
| events since 2011 (drops the 2008-10 cluster) | NIFTY | 18 | 89% (16 of 18) | 78% (14 of 18) | 56% (10 of 18) | 19% (3 of 16) | 50% (9 of 18) | -1.85 | -5.03 | -3.03 | -1.65 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 18 | 83% (15 of 18) | 72% (13 of 18) | 61% (11 of 18) | 27% (4 of 15) | 44% (8 of 18) | -1.97 | -5.59 | -3.20 | -1.77 | 199 (n=3; low in first 15 min 1 of 3) |
|  | IT | 18 | 89% (16 of 18) | 83% (15 of 18) | 44% (8 of 18) | 12% (2 of 16) | 28% (5 of 18) | -2.35 | -6.58 | -4.21 | -3.09 | 226 (n=1; low in first 15 min 0 of 1) |
| 20 Nov look-alike: Friday + India up + two US down days | | 0 | | | | | | | | | | |

## S&P 500 <= -2.5% - all splits

| split | idx | n | opened lower | closed lower | closed > open | opened lower -> closed + | prev close in 5 s | median gap | worst gap | median low | median close | minutes open->low (median, n) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| all events | NIFTY | 130 | 82% (60 of 73) | 73% (95 of 130) | 59% (43 of 73) | 18% (11 of 60) | 63% (82 of 130) | -0.90 | -9.14 | -2.03 | -0.96 | 1 (n=9; low in first 15 min 6 of 9) |
|  | BANKNIFTY | 130 | 86% (112 of 130) | 68% (88 of 130) | 52% (68 of 130) | 31% (35 of 112) | 59% (77 of 130) | -1.17 | -9.87 | -2.89 | -1.06 | 15 (n=9; low in first 15 min 4 of 9) |
|  | IT | 130 | 82% (107 of 130) | 77% (100 of 130) | 46% (60 of 130) | 18% (19 of 107) | 56% (73 of 130) | -0.99 | -8.37 | -2.45 | -1.29 | 226 (n=1; low in first 15 min 0 of 1) |
| (a) Friday US fall -> next India session (Monday) | NIFTY | 24 | 94% (15 of 16) | 92% (22 of 24) | 56% (9 of 16) | 7% (1 of 15) | 58% (14 of 24) | -1.41 | -9.14 | -2.85 | -1.69 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 24 | 92% (22 of 24) | 67% (16 of 24) | 54% (13 of 24) | 32% (7 of 22) | 62% (15 of 24) | -1.30 | -9.87 | -2.76 | -2.00 | 20 (n=3; low in first 15 min 1 of 3) |
|  | IT | 24 | 88% (21 of 24) | 88% (21 of 24) | 38% (9 of 24) | 5% (1 of 21) | 42% (10 of 24) | -1.46 | -8.37 | -3.36 | -1.89 | not available |
| not a Friday | NIFTY | 106 | 79% (45 of 57) | 69% (73 of 106) | 60% (34 of 57) | 22% (10 of 45) | 64% (68 of 106) | -0.78 | -5.03 | -1.94 | -0.92 | 1.5 (n=6; low in first 15 min 4 of 6) |
|  | BANKNIFTY | 106 | 85% (90 of 106) | 68% (72 of 106) | 52% (55 of 106) | 31% (28 of 90) | 58% (62 of 106) | -1.10 | -6.37 | -2.91 | -0.97 | 8.5 (n=6; low in first 15 min 3 of 6) |
|  | IT | 106 | 81% (86 of 106) | 75% (79 of 106) | 48% (51 of 106) | 21% (18 of 86) | 59% (63 of 106) | -0.94 | -6.15 | -2.38 | -1.13 | 226 (n=1; low in first 15 min 0 of 1) |
| (b) India closed UP on the US-fall day | NIFTY | 32 | 79% (15 of 19) | 84% (27 of 32) | 58% (11 of 19) | 0% (0 of 15) | 53% (17 of 32) | -1.52 | -9.14 | -2.09 | -1.27 | 10.0 (n=2; low in first 15 min 1 of 2) |
|  | BANKNIFTY | 32 | 91% (29 of 32) | 75% (24 of 32) | 50% (16 of 32) | 21% (6 of 29) | 50% (16 of 32) | -1.38 | -9.87 | -2.59 | -1.77 | 10.0 (n=2; low in first 15 min 1 of 2) |
|  | IT | 32 | 84% (27 of 32) | 84% (27 of 32) | 41% (13 of 32) | 7% (2 of 27) | 44% (14 of 32) | -1.10 | -8.37 | -2.73 | -1.62 | 226 (n=1; low in first 15 min 0 of 1) |
| India closed down/flat on the US-fall day | NIFTY | 98 | 83% (45 of 54) | 69% (68 of 98) | 59% (32 of 54) | 24% (11 of 45) | 66% (65 of 98) | -0.89 | -5.03 | -1.97 | -0.92 | 1 (n=7; low in first 15 min 5 of 7) |
|  | BANKNIFTY | 98 | 85% (83 of 98) | 65% (64 of 98) | 53% (52 of 98) | 35% (29 of 83) | 62% (61 of 98) | -1.10 | -6.37 | -2.96 | -0.72 | 15 (n=7; low in first 15 min 3 of 7) |
|  | IT | 98 | 82% (80 of 98) | 74% (73 of 98) | 48% (47 of 98) | 21% (17 of 80) | 60% (59 of 98) | -0.99 | -6.58 | -2.41 | -1.25 | not available |
| (c) two US down days in a row | NIFTY | 72 | 82% (37 of 45) | 72% (52 of 72) | 60% (27 of 45) | 24% (9 of 37) | 64% (46 of 72) | -0.88 | -5.03 | -1.81 | -0.92 | 9.5 (n=4; low in first 15 min 2 of 4) |
|  | BANKNIFTY | 72 | 85% (61 of 72) | 65% (47 of 72) | 53% (38 of 72) | 33% (20 of 61) | 62% (45 of 72) | -1.00 | -6.37 | -2.59 | -0.65 | 109.5 (n=4; low in first 15 min 1 of 4) |
|  | IT | 72 | 81% (58 of 72) | 72% (52 of 72) | 47% (34 of 72) | 22% (13 of 58) | 60% (43 of 72) | -0.93 | -6.58 | -2.33 | -1.09 | not available |
| the US day before was up | NIFTY | 58 | 82% (23 of 28) | 74% (43 of 58) | 57% (16 of 28) | 9% (2 of 23) | 62% (36 of 58) | -1.10 | -9.14 | -2.42 | -1.02 | 1 (n=5; low in first 15 min 4 of 5) |
|  | BANKNIFTY | 58 | 88% (51 of 58) | 71% (41 of 58) | 52% (30 of 58) | 29% (15 of 51) | 55% (32 of 58) | -1.47 | -9.87 | -3.12 | -1.73 | 0 (n=5; low in first 15 min 3 of 5) |
|  | IT | 58 | 84% (49 of 58) | 83% (48 of 58) | 45% (26 of 58) | 12% (6 of 49) | 52% (30 of 58) | -1.29 | -8.37 | -3.11 | -1.52 | 226 (n=1; low in first 15 min 0 of 1) |
| (d) Asia <= -3% on India's next-session date | NIFTY | 61 | 90% (27 of 30) | 79% (48 of 61) | 47% (14 of 30) | 7% (2 of 27) | 62% (38 of 61) | -1.57 | -9.14 | -3.16 | -1.60 | 1 (n=3; low in first 15 min 3 of 3) |
|  | BANKNIFTY | 61 | 90% (55 of 61) | 72% (44 of 61) | 51% (31 of 61) | 25% (14 of 55) | 57% (35 of 61) | -1.88 | -9.87 | -3.68 | -1.85 | 0 (n=3; low in first 15 min 2 of 3) |
|  | IT | 61 | 92% (56 of 61) | 82% (50 of 61) | 38% (23 of 61) | 14% (8 of 56) | 52% (32 of 61) | -1.71 | -8.37 | -4.54 | -2.41 | 226 (n=1; low in first 15 min 0 of 1) |
| (d2) Asia <= -3% on the US date | NIFTY | 37 | 60% (12 of 20) | 57% (21 of 37) | 45% (9 of 20) | 33% (4 of 12) | 70% (26 of 37) | -0.57 | -5.03 | -1.91 | -0.27 | 1 (n=3; low in first 15 min 2 of 3) |
|  | BANKNIFTY | 37 | 70% (26 of 37) | 59% (22 of 37) | 57% (21 of 37) | 38% (10 of 26) | 68% (25 of 37) | -0.72 | -5.59 | -3.00 | -0.35 | 0 (n=3; low in first 15 min 2 of 3) |
|  | IT | 37 | 68% (25 of 37) | 62% (23 of 37) | 59% (22 of 37) | 32% (8 of 25) | 76% (28 of 37) | -0.93 | -6.15 | -2.35 | -0.91 | 226 (n=1; low in first 15 min 0 of 1) |
| events since 2011 (drops the 2008-10 cluster) | NIFTY | 73 | 82% (60 of 73) | 75% (55 of 73) | 59% (43 of 73) | 18% (11 of 60) | 62% (45 of 73) | -0.90 | -9.14 | -1.50 | -0.89 | 1 (n=9; low in first 15 min 6 of 9) |
|  | BANKNIFTY | 73 | 84% (61 of 73) | 66% (48 of 73) | 56% (41 of 73) | 33% (20 of 61) | 59% (43 of 73) | -0.93 | -9.87 | -1.97 | -0.75 | 15 (n=9; low in first 15 min 4 of 9) |
|  | IT | 73 | 84% (61 of 73) | 73% (53 of 73) | 49% (36 of 73) | 20% (12 of 61) | 52% (38 of 73) | -1.00 | -8.37 | -2.04 | -1.17 | 226 (n=1; low in first 15 min 0 of 1) |
| 20 Nov look-alike: Friday + India up + two US down days | NIFTY | 4 | 75% (3 of 4) | 75% (3 of 4) | 75% (3 of 4) | 0% (0 of 3) | 75% (3 of 4) | -0.62 | -3.31 | -1.08 | -0.34 | 19 (n=1; low in first 15 min 0 of 1) |
|  | BANKNIFTY | 4 | 75% (3 of 4) | 25% (1 of 4) | 75% (3 of 4) | 67% (2 of 3) | 75% (3 of 4) | -0.62 | -4.74 | -0.94 | +0.18 | 20 (n=1; low in first 15 min 0 of 1) |
|  | IT | 4 | 75% (3 of 4) | 75% (3 of 4) | 25% (1 of 4) | 0% (0 of 3) | 50% (2 of 4) | -0.71 | -3.28 | -2.13 | -1.18 | not available |

## Which sectors held up best on the next session
Median next-session close vs previous close, per sector index (n differs: sector histories start 2010-2011 on Yahoo; PVT BANK only from Nov 2021).

Three windows, because the sector histories start at different dates: all data each sector has; the common window from Sep 2011 (every sector but PVT BANK, same events); and the window from Nov 2021 (all sectors incl. PVT BANK, same events, small n). Ranked by the common Sep 2011 window.

**Nasdaq Composite <= -3%**

| rank | sector | median, all data (n) | closed lower | median, Sep 2011 -> (n) | closed lower | median, Nov 2021 -> (n) | closed lower |
|---|---|---|---|---|---|---|---|
| 1 | NIFTY FMCG | -0.21% (77) | 56% | -0.21% (73) | 56% | -0.16% (31) | 58% |
| 2 | NIFTY PHARMA | -0.50% (77) | 64% | -0.43% (73) | 62% | -0.28% (31) | 65% |
| 3 | NIFTY BANK | -0.91% (122) | 69% | -0.71% (73) | 66% | -0.55% (31) | 61% |
| 4 | NIFTY FIN SERVICE | -0.77% (73) | 62% | -0.77% (73) | 62% | -0.42% (31) | 55% |
| 5 | NIFTY PSU BANK | -0.83% (77) | 68% | -0.80% (73) | 66% | -0.59% (31) | 65% |
| 6 | NIFTY AUTO | -0.80% (77) | 71% | -0.80% (73) | 71% | -0.54% (31) | 74% |
| 7 | NIFTY REALTY | -0.79% (78) | 63% | -0.82% (73) | 63% | -0.69% (31) | 61% |
| 8 | NIFTY METAL | -1.02% (77) | 69% | -1.02% (73) | 68% | -0.50% (31) | 68% |
| 9 | NIFTY IT | -1.29% (122) | 78% | -1.17% (73) | 73% | -0.98% (31) | 71% |
| - | NIFTY PVT BANK | n/a (data from Nov 2021) |  | n/a (data from Nov 2021) |  | -0.42% (31) | 61% |
| ref | NIFTY 50 | -0.92% (122) | 73% | -0.50% (73) | 73% | -0.37% (31) | 77% |

**Nasdaq Composite <= -4.5%**

| rank | sector | median, all data (n) | closed lower | median, Sep 2011 -> (n) | closed lower | median, Nov 2021 -> (n) | closed lower |
|---|---|---|---|---|---|---|---|
| 1 | NIFTY FMCG | -0.28% (18) | 61% | -0.21% (15) | 60% | -0.21% (7) | 71% |
| 2 | NIFTY AUTO | -0.94% (18) | 83% | -0.96% (15) | 80% | -1.75% (7) | 86% |
| 3 | NIFTY PHARMA | -1.36% (18) | 72% | -1.44% (15) | 67% | -1.44% (7) | 71% |
| 4 | NIFTY BANK | -1.82% (31) | 71% | -1.82% (15) | 67% | -0.28% (7) | 71% |
| 5 | NIFTY FIN SERVICE | -1.88% (15) | 60% | -1.88% (15) | 60% | -0.42% (7) | 57% |
| 6 | NIFTY METAL | -1.88% (18) | 72% | -2.11% (15) | 67% | -2.11% (7) | 57% |
| 7 | NIFTY REALTY | -2.35% (18) | 72% | -2.38% (15) | 73% | -2.61% (7) | 71% |
| 8 | NIFTY PSU BANK | -1.38% (18) | 78% | -2.43% (15) | 73% | -0.52% (7) | 71% |
| 9 | NIFTY IT | -2.65% (31) | 81% | -2.51% (15) | 80% | -2.51% (7) | 71% |
| - | NIFTY PVT BANK | n/a (data from Nov 2021) |  | n/a (data from Nov 2021) |  | -0.45% (7) | 71% |
| ref | NIFTY 50 | -1.68% (31) | 77% | -1.63% (15) | 73% | -1.49% (7) | 86% |

**S&P 500 <= -2.5%**

| rank | sector | median, all data (n) | closed lower | median, Sep 2011 -> (n) | closed lower | median, Nov 2021 -> (n) | closed lower |
|---|---|---|---|---|---|---|---|
| 1 | NIFTY FMCG | -0.17% (73) | 56% | -0.21% (67) | 57% | -0.21% (23) | 61% |
| 2 | NIFTY PHARMA | -0.64% (73) | 68% | -0.48% (67) | 66% | -0.41% (23) | 70% |
| 3 | NIFTY BANK | -1.06% (130) | 68% | -0.69% (67) | 64% | -0.22% (23) | 57% |
| 4 | NIFTY FIN SERVICE | -0.82% (67) | 63% | -0.82% (67) | 63% | -0.15% (23) | 52% |
| 5 | NIFTY PSU BANK | -0.83% (73) | 71% | -0.83% (67) | 70% | -0.72% (23) | 70% |
| 6 | NIFTY AUTO | -0.75% (73) | 77% | -0.84% (67) | 78% | -0.56% (23) | 87% |
| 7 | NIFTY REALTY | -1.00% (74) | 68% | -1.02% (67) | 69% | -0.69% (23) | 61% |
| 8 | NIFTY IT | -1.29% (130) | 77% | -1.17% (67) | 70% | -1.23% (23) | 74% |
| 9 | NIFTY METAL | -1.31% (73) | 71% | -1.31% (67) | 72% | -0.43% (23) | 65% |
| - | NIFTY PVT BANK | n/a (data from Nov 2021) |  | n/a (data from Nov 2021) |  | -0.26% (23) | 57% |
| ref | NIFTY 50 | -0.96% (130) | 73% | -0.88% (67) | 73% | -0.43% (23) | 83% |

## Data: what was used, what was missing
- NIFTY daily: Kite day candles (exchange) Nov 2021 -> 20 Nov 2026, Yahoo before. Cross-check on 1240 overlapping days: largest open/high/low/close difference 0.01%, 0 days differ by more than 0.1%.
- BANKNIFTY daily: Kite day candles (exchange) Nov 2021 -> 20 Nov 2026, Yahoo before. Cross-check on 1239 overlapping days: largest open/high/low/close difference 0.013%, 0 days differ by more than 0.1%.
- IT daily: Kite day candles (exchange) Nov 2021 -> 20 Nov 2026, Yahoo before. Cross-check on 1239 overlapping days: largest open/high/low/close difference 0.0%, 0 days differ by more than 0.1%.
- NIFTY BANK: 2007-09-17 -> 2026-11-20 (Yahoo ^NSEBANK + Kite ix_NIFTY_BANK).
- NIFTY PVT BANK: 2021-11-15 -> 2026-11-20 (Kite ix_NIFTY_PVT_BANK).
- NIFTY PSU BANK: 2011-01-31 -> 2026-11-20 (Yahoo ^CNXPSUBANK + Kite ix_NIFTY_PSU_BANK).
- NIFTY IT: 2007-09-17 -> 2026-11-20 (Yahoo ^CNXIT + Kite ix_NIFTY_IT).
- NIFTY PHARMA: 2011-01-31 -> 2026-11-20 (Yahoo ^CNXPHARMA + Kite ix_NIFTY_PHARMA).
- NIFTY FMCG: 2011-01-31 -> 2026-11-20 (Yahoo ^CNXFMCG + Kite ix_NIFTY_FMCG).
- NIFTY AUTO: 2011-07-12 -> 2026-11-20 (Yahoo ^CNXAUTO + Kite ix_NIFTY_AUTO).
- NIFTY METAL: 2011-07-12 -> 2026-11-20 (Yahoo ^CNXMETAL + Kite ix_NIFTY_METAL).
- NIFTY REALTY: 2010-07-19 -> 2026-11-20 (Yahoo ^CNXREALTY + Kite ix_NIFTY_REALTY).
- NIFTY FIN SERVICE: 2011-09-07 -> 2026-11-20 (Yahoo NIFTY_FIN_SERVICE.NS + Kite ix_NIFTY_FIN_SERVICE).
- Minute data for 'minutes from the open to the day's low', NIFTY/BANKNIFTY: 2023-11-16 -> 2026-11-19 (hist_fresh) + girdata/minute 2026-10-16 -> 2026-11-20. Events outside that window say 'not available'.
- Minute data for 'minutes from the open to the day's low', NIFTY IT: girdata/minute only, 2026-10-16 -> 2026-11-20. Events outside that window say 'not available'.
- Not obtained: NIFTY PVT BANK history from Yahoo (NIFTY_PVT_BANK.NS returns 1 bar; ^NIFTYPVTBANK and NIFTYPVTBANK.NS do not exist) -> Kite daily from Nov 2021 only, so the PVT BANK n is small. ^CNXFIN also returns 1 bar; NIFTY_FIN_SERVICE.NS was used (Sep 2011 ->).
- NIFTY 50 opens before 2011 are NOT usable: in Yahoo's ^NSEI the open sits within 0.03% of the previous close on 40-66% of days in 2007-2010 (6% or less from 2011, after NSE's pre-open auction began in Oct 2010). So for NIFTY the gap, the high, 'opened lower' and 'closed above open' count only events from 2011 (that is why their 'of n' is smaller than n). NIFTY low and close are used for all years. BANKNIFTY and NIFTY IT opens look real in 2007-2010 and are kept.
- Kite's NIFTY day open is sometimes the first 09:15 print, close to the previous close, even in recent years (about 3% of days). One event row is hit: 6 Nov 2026 shows a +0.01% NIFTY gap, but the second minute was already -0.37%; it rallied to close +2.01%.
- Weekend India sessions (Muhurat, special Saturdays) are left out of the calendar. Asia indices skip their own holidays; a closed Asia market does not count toward split (d).
- Split (d) uses Asia's CLOSE on India's next-session date: Nikkei/KOSPI/Taiwan close 11:00-12:00 IST and Hang Seng 13:40 IST, so at India's open this is only partly known. (d2) uses Asia on the US date, which is known before India opens.
- The local /root/hist files are per-share F&O data (fo_daily.json, fo_*.csv.zip) and were not needed; /root/hist/min/NIFTY.npz matches hist_fresh up to 13 Nov 2026.

## Appendix: every event row

### Nasdaq Composite <= -3% (n=122)

| US date | day | Nasdaq % | S&P % | US prev day % | India day-of NIFTY % | India date | NIFTY gap / low / high / close | BANKNIFTY gap / low / high / close | IT gap / low / high / close | NIFTY min to low | Asia on India date (min) | back in 5 s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2008-01-04 | Fri | -3.77 | -2.46 | -0.27 | +1.55 | 2008-01-07 | n/a / -1.29 / n/a / +0.08 | -2.44 / -2.78 / +2.44 / +1.54 | -0.27 / -3.03 / -0.27 / -2.86 | n/a | Taiwan -4.11 | yes |
| 2008-02-05 | Tue | -3.08 | -3.20 | -1.26 | +0.37 | 2008-02-06 | n/a / -4.14 / n/a / -2.94 | -2.43 / -3.68 / -1.51 / -2.26 | -0.03 / -5.63 / -0.03 / -5.15 | n/a | Hang Seng -5.40 | no |
| 2008-06-26 | Thu | -3.33 | -2.94 | +1.39 | +1.49 | 2008-06-27 | n/a / -4.56 / n/a / -4.15 | -3.05 / -5.97 / -3.05 / -5.47 | -1.49 / -4.88 / -1.49 / -4.56 | n/a | Taiwan -3.37 | no |
| 2008-09-04 | Thu | -3.20 | -2.99 | -0.66 | -1.25 | 2008-09-05 | n/a / -2.67 / n/a / -2.15 | -2.72 / -3.63 / -1.63 / -3.17 | -1.20 / -3.37 / -1.20 / -3.13 | n/a | Nikkei -2.75 | yes |
| 2008-09-15 | Mon | -3.60 | -4.71 | +0.14 | -3.68 | 2008-09-16 | n/a / -3.77 / n/a / +0.05 | -3.57 / -4.06 / +2.86 / +2.26 | -3.14 / -4.43 / -0.92 / -1.83 | n/a | KOSPI -6.10 | yes |
| 2008-09-17 | Wed | -4.94 | -4.71 | +1.28 | -1.64 | 2008-09-18 | n/a / -5.21 / n/a / +0.75 | -3.72 / -6.10 / +3.20 / +2.79 | -2.54 / -6.02 / +0.25 / -1.78 | n/a | Taiwan -2.74 | yes |
| 2008-09-22 | Mon | -4.17 | -3.82 | +3.40 | -0.52 | 2008-09-23 | n/a / -2.49 / n/a / -2.28 | -2.48 / -4.68 / -0.71 / -4.29 | -1.94 / -5.33 / -1.06 / -5.04 | n/a | Hang Seng -3.87 | no |
| 2008-09-29 | Mon | -9.14 | -8.81 | -0.15 | -3.39 | 2008-09-30 | n/a / -3.51 / n/a / +1.85 | -1.64 / -4.37 / +6.08 / +4.78 | -2.51 / -4.88 / +4.63 / +1.84 | n/a | Nikkei -4.12 | yes |
| 2008-10-02 | Thu | -4.48 | -4.03 | -1.07 | +0.75 | 2008-10-03 | n/a / -3.69 / n/a / -3.35 | -1.03 / -3.69 / +0.58 / -3.16 | +0.79 / -3.33 / +0.79 / -2.71 | n/a | Hang Seng -2.90 | no |
| 2008-10-06 | Mon | -4.34 | -3.85 | -1.48 | -5.66 | 2008-10-07 | n/a / -1.81 / n/a / +0.12 | +2.75 / -3.32 / +4.29 / -1.85 | +1.76 / -5.66 / +3.82 / -3.65 | n/a | Nikkei -3.03 | yes |
| 2008-10-07 | Tue | -5.80 | -5.74 | -4.34 | +0.12 | 2008-10-08 | n/a / -7.68 / n/a / -2.58 | -2.23 / -9.88 / -2.23 / -4.31 | -2.41 / -10.37 / -2.41 / -5.72 | n/a | Nikkei -9.38 | no |
| 2008-10-09 | Thu | -5.47 | -7.62 | -0.83 | -2.58 | 2008-10-10 | n/a / -8.96 / n/a / -6.65 | -6.37 / -10.73 / -2.11 / -5.45 | -1.34 / -11.68 / -1.34 / -5.56 | n/a | Nikkei -9.62 | yes |
| 2008-10-14 | Tue | -3.54 | -0.53 | +11.81 | +0.80 | 2008-10-15 | n/a / -5.52 / n/a / -5.12 | -2.26 / -4.12 / -0.49 / -2.75 | -2.03 / -6.80 / -2.03 / -5.79 | n/a | Hang Seng -4.96 | no |
| 2008-10-15 | Wed | -8.47 | -9.03 | -3.54 | -5.12 | 2008-10-16 | n/a / -7.14 / n/a / -2.07 | -3.75 / -5.15 / +2.58 / +1.04 | -4.82 / -11.00 / -2.83 / -4.61 | n/a | Nikkei -11.41 | no |
| 2008-10-21 | Tue | -4.14 | -3.08 | +3.43 | +3.59 | 2008-10-22 | n/a / -5.66 / n/a / -5.25 | -1.39 / -6.26 / -0.93 / -5.89 | -1.73 / -5.65 / -1.73 / -4.25 | n/a | Nikkei -6.79 | no |
| 2008-10-22 | Wed | -4.77 | -6.10 | -4.14 | -5.25 | 2008-10-23 | n/a / -4.83 / n/a / -3.98 | -3.75 / -4.22 / +1.85 / -3.21 | -3.64 / -5.47 / +4.52 / -1.73 | n/a | KOSPI -7.48 | no |
| 2008-10-24 | Fri | -3.23 | -3.45 | -0.73 | -12.20 | 2008-10-27 | n/a / -12.82 / n/a / -2.31 | -0.68 / -11.85 / -0.55 / -5.04 | -1.14 / -12.02 / +0.51 / -1.43 | n/a | Hang Seng -12.70 | yes |
| 2008-11-05 | Wed | -5.53 | -5.27 | +3.12 | -4.68 | 2008-11-06 | n/a / -4.50 / n/a / -3.42 | -3.35 / -4.84 / +0.31 / -3.54 | -2.14 / -5.07 / +0.29 / -3.87 | n/a | KOSPI -7.56 | yes |
| 2008-11-06 | Thu | -4.34 | -5.03 | -5.53 | -3.42 | 2008-11-07 | n/a / -1.13 / n/a / +2.78 | -0.93 / -2.74 / +3.19 / +2.10 | -1.54 / -2.18 / +3.79 / +2.44 | n/a | Nikkei -3.55 | yes |
| 2008-11-12 | Wed | -5.17 | -5.19 | -2.22 | -3.07 | 2008-11-14 | n/a / -2.45 / n/a / -1.34 | +2.49 / -1.69 / +3.75 / -0.61 | +1.86 / -3.69 / +2.62 / -2.47 | n/a | KOSPI -0.02 | no |
| 2008-11-14 | Fri | -5.00 | -4.17 | +6.50 | -1.34 | 2008-11-17 | n/a / -4.12 / n/a / -0.38 | +0.36 / -7.52 / +0.36 / -3.69 | +0.10 / -3.41 / +0.76 / +0.19 | n/a | KOSPI -0.91 | no |
| 2008-11-19 | Wed | -6.53 | -6.12 | +0.08 | -1.79 | 2008-11-20 | n/a / -5.01 / n/a / -3.11 | -3.68 / -6.18 / -1.23 / -3.47 | -2.21 / -5.13 / -1.46 / -2.87 | n/a | Nikkei -6.89 | yes |
| 2008-11-20 | Thu | -5.07 | -6.71 | -6.53 | -3.11 | 2008-11-21 | n/a / -0.52 / n/a / +5.50 | -0.08 / -0.85 / +7.10 / +5.23 | -0.99 / -1.18 / +6.08 / +5.25 | n/a | Taiwan +1.98 | yes |
| 2008-12-01 | Mon | -8.95 | -8.93 | +0.23 | -2.62 | 2008-12-02 | n/a / -4.18 / n/a / -0.94 | -3.28 / -4.98 / -0.03 / -0.61 | -3.61 / -5.24 / -2.14 / -2.65 | n/a | Nikkei -6.35 | yes |
| 2008-12-04 | Thu | -3.14 | -2.93 | +2.94 | +4.95 | 2008-12-05 | n/a / -3.11 / n/a / -2.64 | -0.08 / -3.11 / +3.71 / -2.02 | -0.91 / -4.49 / -0.91 / -3.92 | n/a | Taiwan -0.70 | yes |
| 2008-12-11 | Thu | -3.68 | -2.85 | +1.17 | -0.28 | 2008-12-12 | n/a / -3.68 / n/a / +0.04 | -2.06 / -4.04 / +1.97 / +1.26 | -1.13 / -5.35 / -1.13 / -3.60 | n/a | Nikkei -5.56 | yes |
| 2009-01-07 | Wed | -3.23 | -3.00 | +1.50 | -6.18 | 2009-01-09 | n/a / -3.77 / n/a / -1.62 | -1.86 / -2.90 / +1.45 / -1.56 | -0.52 / -2.42 / +3.55 / +1.46 | n/a | KOSPI -2.05 | no |
| 2009-01-14 | Wed | -3.67 | -3.35 | +0.50 | +3.29 | 2009-01-15 | n/a / -4.71 / n/a / -3.48 | -3.21 / -6.49 / -3.21 / -5.61 | -3.83 / -6.37 / -3.48 / -3.95 | n/a | KOSPI -6.03 | yes |
| 2009-01-20 | Tue | -5.78 | -5.28 | +1.16 | -1.74 | 2009-01-21 | n/a / -3.80 / n/a / -3.23 | -1.24 / -3.90 / -0.85 / -3.41 | -0.30 / -2.91 / -0.12 / -2.22 | n/a | Hang Seng -2.90 | yes |
| 2009-01-29 | Thu | -3.24 | -3.31 | +3.55 | -0.90 | 2009-01-30 | n/a / -1.77 / n/a / +1.80 | -1.66 / -1.76 / +2.54 / +2.17 | -0.80 / -1.68 / +1.31 / +0.94 | n/a | Nikkei -3.12 | yes |
| 2009-02-10 | Tue | -4.20 | -4.91 | -0.01 | +0.50 | 2009-02-11 | n/a / -1.94 / n/a / -0.30 | -2.00 / -2.49 / +0.16 / -0.25 | -1.17 / -1.89 / -0.73 / -1.13 | n/a | Hang Seng -2.46 | yes |
| 2009-02-17 | Tue | -4.15 | -4.56 | -0.48 | -2.74 | 2009-02-18 | n/a / -1.22 / n/a / +0.20 | -1.51 / -3.00 / +0.39 / -2.09 | -0.93 / -0.93 / +1.10 / -0.02 | n/a | Nikkei -1.45 | yes |
| 2009-02-23 | Mon | -3.71 | -3.47 | -0.11 | -1.90 | 2009-02-24 | n/a / -2.15 / n/a / -0.09 | -0.27 / -3.55 / -0.27 / -1.42 | -0.18 / -2.46 / -0.02 / -0.51 | n/a | KOSPI -3.24 | yes |
| 2009-03-02 | Mon | -3.99 | -4.66 | -0.98 | -3.22 | 2009-03-03 | n/a / -2.36 / n/a / -1.95 | -0.97 / -2.59 / +0.86 / -2.19 | +0.02 / -2.35 / +0.07 / -1.95 | n/a | Hang Seng -2.30 | no |
| 2009-03-05 | Thu | -4.00 | -4.25 | +2.48 | -2.59 | 2009-03-06 | n/a / -1.45 / n/a / +1.69 | -1.77 / -3.12 / +2.75 / +0.26 | -0.53 / -0.89 / +3.55 / +3.13 | n/a | Nikkei -3.50 | yes |
| 2009-04-20 | Mon | -3.88 | -4.28 | +0.16 | -0.22 | 2009-04-21 | n/a / -2.01 / n/a / -0.35 | -1.00 / -3.69 / -0.97 / -3.10 | +0.78 / -1.79 / +0.78 / -1.27 | n/a | Hang Seng -2.95 | yes |
| 2009-05-13 | Wed | -3.01 | -2.69 | -0.88 | -1.25 | 2009-05-14 | n/a / -2.69 / n/a / -1.15 | -1.96 / -3.50 / -0.14 / -0.52 | -1.89 / -2.49 / -0.00 / -0.49 | n/a | Hang Seng -3.04 | yes |
| 2009-06-22 | Mon | -3.35 | -3.06 | +1.09 | -1.82 | 2009-06-23 | n/a / -2.17 / n/a / +0.28 | -1.68 / -3.33 / -1.38 / -1.91 | -1.60 / -2.10 / +0.54 / -0.43 | n/a | Hang Seng -2.89 | yes |
| 2009-10-01 | Thu | -3.06 | -2.58 | -0.08 | -0.01 | 2009-10-05 | n/a / -1.80 / n/a / -1.58 | -1.07 / -2.59 / -0.81 / -2.25 | -1.15 / -1.65 / +0.57 / -1.05 | n/a | KOSPI -2.29 | no |
| 2010-05-06 | Thu | -3.44 | -3.24 | -0.91 | -0.66 | 2010-05-07 | n/a / -2.09 / n/a / -1.43 | -1.62 / -3.57 / -1.44 / -3.19 | -0.96 / -2.65 / -0.85 / -2.41 | n/a | Nikkei -3.10 | yes |
| 2010-05-20 | Thu | -4.11 | -3.90 | -0.82 | +0.57 | 2010-05-21 | n/a / -2.13 / n/a / -0.33 | -0.25 / -2.24 / +0.00 / -0.42 | -0.74 / -1.87 / -0.36 / -0.94 | n/a | Taiwan -2.51 | yes |
| 2010-06-04 | Fri | -3.64 | -3.44 | +0.96 | +0.49 | 2010-06-07 | n/a / -2.56 / n/a / -1.98 | -2.48 / -2.78 / -1.35 / -1.73 | -1.71 / -2.58 / -1.41 / -1.67 | n/a | Nikkei -3.84 | no |
| 2010-06-29 | Tue | -3.85 | -3.10 | -0.13 | -1.45 | 2010-06-30 | n/a / -0.88 / n/a / +1.07 | -0.40 / -0.85 / +1.12 / +0.89 | -0.95 / -1.64 / +0.26 / -0.10 | n/a | Nikkei -1.96 | yes |
| 2010-07-16 | Fri | -3.11 | -2.88 | -0.03 | +0.28 | 2010-07-19 | n/a / -0.60 / n/a / -0.14 | -0.12 / -0.57 / +0.65 / +0.19 | -0.69 / -1.08 / +0.35 / -0.22 | n/a | Hang Seng -0.79 | yes |
| 2010-08-11 | Wed | -3.01 | -2.82 | -1.24 | -0.73 | 2010-08-12 | n/a / -0.89 / n/a / -0.08 | -1.16 / -1.16 / +1.78 / +1.49 | -0.80 / -1.69 / -0.80 / -1.14 | n/a | KOSPI -2.07 | yes |
| 2011-08-04 | Thu | -5.08 | -4.78 | +0.89 | -1.35 | 2011-08-05 | -2.39 / -4.04 / -1.92 / -2.26 | -2.19 / -3.67 / -1.37 / -1.73 | -2.19 / -6.28 / -2.19 / -3.99 | n/a | Taiwan -5.58 | no |
| 2011-08-08 | Mon | -6.90 | -6.66 | -0.94 | -1.78 | 2011-08-09 | -3.33 / -3.36 / +0.95 / -0.89 | -2.74 / -3.04 / +1.88 / -0.35 | -4.18 / -4.56 / -1.41 / -3.53 | n/a | Hang Seng -5.66 | yes |
| 2011-08-10 | Wed | -4.09 | -4.42 | +5.29 | +1.74 | 2011-08-11 | -0.64 / -0.78 / +0.46 / -0.44 | -0.42 / -1.34 / +0.51 / -1.19 | -0.67 / -1.45 / +0.27 / -0.59 | n/a | Hang Seng -0.95 | no |
| 2011-08-18 | Thu | -5.22 | -4.46 | -0.47 | -2.22 | 2011-08-19 | -1.72 / -2.99 / -1.02 / -1.99 | -1.55 / -3.35 / -0.14 / -2.05 | -2.61 / -6.31 / -2.61 / -4.38 | n/a | KOSPI -6.22 | yes |
| 2011-09-22 | Thu | -3.25 | -3.19 | -2.01 | -4.08 | 2011-09-23 | -1.01 / -1.91 / +0.13 / -1.14 | -1.07 / -2.48 / +0.21 / -1.52 | -0.83 / -0.96 / +1.50 / -0.33 | n/a | KOSPI -5.73 | yes |
| 2011-10-03 | Mon | -3.29 | -2.85 | -2.63 | -1.90 | 2011-10-04 | -0.54 / -2.50 / +0.42 / -1.60 | -0.55 / -4.00 / +0.59 / -2.97 | -0.79 / -1.97 / +0.21 / -0.91 | n/a | Hang Seng -3.40 | yes |
| 2011-11-09 | Wed | -3.88 | -3.67 | +1.20 | -1.29 | 2011-11-11 | -1.17 / -1.51 / -0.43 / -1.00 | -0.41 / -3.36 / -0.22 / -3.13 | -4.74 / -4.74 / -0.22 / -1.03 | n/a | Nikkei +0.16 | no |
| 2014-04-10 | Thu | -3.10 | -2.09 | +1.72 | +0.00 | 2014-04-11 | -0.56 / -0.78 / -0.10 / -0.30 | -0.98 / -1.32 / -0.11 / -0.84 | -0.25 / -1.07 / +1.87 / +1.45 | n/a | Nikkei -2.38 | yes |
| 2015-08-21 | Fri | -3.52 | -3.19 | -2.82 | -0.87 | 2015-08-24 | -2.94 / -6.39 / -2.89 / -5.92 | -3.38 / -7.29 / -3.38 / -6.90 | -2.34 / -5.31 / -1.95 / -4.80 | n/a | Hang Seng -5.17 | no |
| 2015-08-24 | Mon | -3.82 | -3.94 | -3.52 | -5.92 | 2015-08-25 | +1.11 / -1.82 / +1.49 / +0.92 | +1.62 / -0.84 / +2.72 / +2.27 | +0.61 / -2.74 / +1.40 / -0.68 | n/a | Nikkei -3.96 | yes |
| 2015-09-28 | Mon | -3.04 | -2.57 | -1.01 | -0.93 | 2015-09-29 | -0.90 / -1.34 / +1.68 / +0.61 | -1.41 / -2.64 / +2.11 / +1.06 | -0.61 / -0.78 / +1.03 / +0.19 | n/a | Nikkei -4.05 | yes |
| 2016-01-07 | Thu | -3.03 | -2.37 | -1.14 | -2.23 | 2016-01-08 | +0.57 / +0.17 / +0.87 / +0.44 | +0.38 / +0.19 / +0.97 / +0.43 | +0.65 / +0.31 / +1.33 / +1.16 | n/a | Nikkei -0.39 | yes |
| 2016-01-13 | Wed | -3.41 | -2.50 | +1.03 | +0.69 | 2016-01-14 | -1.26 / -1.57 / +0.56 / -0.34 | -1.64 / -2.64 / -0.43 / -1.65 | -1.01 / -1.43 / +2.11 / +1.30 | n/a | Nikkei -2.68 | no |
| 2016-02-05 | Fri | -3.25 | -1.85 | +0.12 | +1.15 | 2016-02-08 | +0.01 / -1.68 / +0.31 / -1.36 | +0.29 / -1.33 / +1.36 / -0.76 | -0.59 / -2.36 / -0.33 / -2.01 | n/a | Nikkei +1.10 | no |
| 2016-06-24 | Fri | -4.12 | -3.59 | +1.59 | -2.20 | 2016-06-27 | -0.61 / -0.61 / +0.40 / +0.08 | -0.46 / -0.46 / +1.06 / +0.51 | -1.19 / -2.02 / -0.97 / -1.74 | n/a | Taiwan -0.21 | yes |
| 2018-02-05 | Mon | -3.78 | -4.10 | -1.96 | -0.87 | 2018-02-06 | -3.48 / -3.66 / -0.68 / -1.58 | -3.67 / -4.12 / +0.16 / -1.10 | -3.25 / -3.45 / -1.44 / -2.90 | n/a | Hang Seng -5.12 | no |
| 2018-02-08 | Thu | -3.90 | -3.75 | -0.90 | +0.96 | 2018-02-09 | -1.52 / -1.69 / -0.91 / -1.15 | -1.75 / -2.12 / -1.24 / -1.76 | -1.10 / -1.89 / -0.26 / -0.76 | n/a | Hang Seng -3.10 | no |
| 2018-10-10 | Wed | -4.08 | -3.29 | +0.03 | +1.54 | 2018-10-11 | -2.78 / -3.07 / -1.19 / -2.16 | -3.08 / -3.27 / -1.51 / -2.12 | -2.79 / -3.89 / -1.67 / -3.04 | n/a | Taiwan -6.31 | yes |
| 2018-10-24 | Wed | -4.43 | -3.09 | -0.42 | +0.77 | 2018-10-25 | -0.88 / -1.42 / -0.57 / -0.98 | -0.89 / -1.47 / -0.35 / -0.98 | -1.10 / -1.32 / +0.93 / +0.15 | n/a | Nikkei -3.72 | yes |
| 2018-11-19 | Mon | -3.03 | -1.66 | -0.15 | +0.76 | 2018-11-20 | -0.22 / -1.14 / -0.21 / -1.00 | -0.34 / -0.98 / -0.16 / -0.71 | -0.17 / -2.31 / -0.17 / -2.16 | n/a | Hang Seng -2.02 | no |
| 2018-12-04 | Tue | -3.80 | -3.24 | +1.51 | -0.13 | 2018-12-05 | -0.45 / -1.12 / -0.45 / -0.80 | -0.46 / -0.94 / -0.25 / -0.65 | -0.45 / -1.41 / +0.42 / +0.09 | n/a | Taiwan -1.65 | no |
| 2018-12-07 | Fri | -3.05 | -2.33 | +0.42 | +0.87 | 2018-12-10 | -1.73 / -2.05 / -1.26 / -1.92 | -1.96 / -1.96 / -0.97 / -1.85 | -1.21 / -2.00 / +0.41 / -1.66 | n/a | Nikkei -2.12 | yes |
| 2019-01-03 | Thu | -3.04 | -2.48 | +0.46 | -1.11 | 2019-01-04 | +0.26 / -0.41 / +0.64 / +0.52 | +0.15 / -0.13 / +1.17 / +0.87 | +0.07 / -2.54 / +0.26 / -1.23 | n/a | Nikkei -2.26 | yes |
| 2019-05-13 | Mon | -3.41 | -2.41 | +0.08 | -1.16 | 2019-05-14 | +0.03 / -0.36 / +1.31 / +0.66 | +0.21 / -0.27 / +1.39 / +0.59 | -0.08 / -1.96 / +0.07 / -1.21 | n/a | Hang Seng -1.50 | yes |
| 2019-08-05 | Mon | -3.47 | -2.98 | -1.32 | -1.23 | 2019-08-06 | -0.43 / -0.45 / +1.44 / +0.79 | -0.47 / -0.52 / +1.81 / +1.35 | -0.25 / -0.54 / +0.76 / -0.02 | n/a | KOSPI -1.51 | yes |
| 2019-08-14 | Wed | -3.02 | -2.93 | +1.95 | +0.95 | 2019-08-16 | +0.13 / -0.95 / +0.36 / +0.17 | -0.35 / -1.06 / +0.83 / +0.71 | +0.52 / -1.47 / +0.56 / -0.65 | n/a | KOSPI -0.58 | yes |
| 2020-02-24 | Mon | -3.71 | -3.35 | -1.79 | -2.08 | 2020-02-25 | +0.41 / -0.42 / +0.45 / -0.27 | +0.20 / -0.41 / +0.51 / -0.07 | +0.17 / -0.11 / +1.10 / +0.61 | n/a | Nikkei -3.34 | no |
| 2020-02-27 | Thu | -4.61 | -4.42 | +0.17 | -0.39 | 2020-02-28 | -2.16 / -3.94 / -2.14 / -3.71 | -2.27 / -3.76 / -2.06 / -3.44 | -2.47 / -6.00 / -2.08 / -5.65 | n/a | Nikkei -3.67 | no |
| 2020-03-05 | Thu | -3.10 | -3.39 | +3.85 | +0.16 | 2020-03-06 | -2.90 / -3.92 / -2.08 / -2.48 | -4.04 / -5.74 / -2.67 / -3.52 | -1.66 / -2.70 / -1.08 / -1.31 | n/a | Nikkei -2.72 | no |
| 2020-03-09 | Mon | -7.29 | -7.60 | -1.86 | -4.90 | 2020-03-11 | -1.12 / -1.12 / +0.90 / +0.07 | -0.72 / -0.86 / +1.24 / +0.10 | -2.23 / -3.36 / -0.21 / -1.17 | n/a | KOSPI -2.78 | yes |
| 2020-03-11 | Wed | -4.70 | -4.89 | +4.95 | +0.07 | 2020-03-12 | -4.00 / -9.09 / -3.99 / -8.30 | -4.95 / -11.14 / -4.77 / -9.50 | -3.43 / -9.29 / -3.06 / -8.83 | n/a | Nikkei -4.41 | no |
| 2020-03-12 | Thu | -9.43 | -9.51 | -4.70 | -8.30 | 2020-03-13 | -5.03 / -10.79 / +5.94 / +3.81 | -5.22 / -10.93 / +7.09 / +4.99 | -6.15 / -13.15 / +3.37 / +1.15 | n/a | Nikkei -6.08 | yes |
| 2020-03-16 | Mon | -12.32 | -11.98 | +9.35 | -7.61 | 2020-03-17 | +0.96 / -3.06 / +2.24 / -2.50 | +1.07 / -4.76 / +1.51 / -4.10 | +0.53 / -3.63 / +1.81 / -2.83 | n/a | Taiwan -2.86 | no |
| 2020-03-18 | Wed | -4.70 | -5.18 | +6.23 | -5.56 | 2020-03-19 | -4.79 / -7.51 / +1.26 / -2.42 | -5.59 / -9.25 / +2.21 / -2.41 | -4.84 / -6.48 / -0.47 / -3.51 | n/a | KOSPI -8.39 | yes |
| 2020-03-20 | Fri | -3.79 | -4.34 | +2.30 | +5.83 | 2020-03-23 | -9.14 / -13.29 / -6.70 / -12.98 | -9.87 / -17.36 / -7.00 / -16.73 | -8.37 / -10.15 / -6.16 / -9.58 | n/a | KOSPI -5.34 | no |
| 2020-03-27 | Fri | -3.79 | -3.37 | +5.60 | +0.22 | 2020-03-30 | -3.17 / -4.81 / -0.97 / -4.38 | -3.58 / -6.51 / -1.27 / -5.94 | -3.31 / -3.31 / +1.63 / -1.99 | n/a | Nikkei -1.57 | yes |
| 2020-04-01 | Wed | -4.41 | -4.41 | -0.95 | -4.00 | 2020-04-03 | +1.24 / -2.40 / +1.24 / -2.06 | +0.64 / -5.85 / +0.65 / -5.27 | +0.70 / -3.53 / +0.84 / -3.04 | n/a | Hang Seng -0.19 | yes |
| 2020-04-21 | Tue | -3.48 | -3.07 | -1.03 | -3.03 | 2020-04-22 | +0.50 / -0.39 / +2.54 / +2.29 | -0.53 / -1.84 / +2.05 / +1.51 | -0.12 / -0.69 / +1.70 / +1.31 | n/a | Nikkei -0.74 | yes |
| 2020-05-01 | Fri | -3.20 | -2.81 | -0.28 | +3.21 | 2020-05-04 | -3.31 / -6.01 / -3.31 / -5.74 | -4.74 / -8.78 / -4.66 / -8.32 | -3.28 / -4.85 / -2.89 / -4.64 | n/a | Hang Seng -4.18 | no |
| 2020-06-11 | Thu | -5.27 | -5.89 | +0.67 | -2.12 | 2020-06-12 | -3.61 / -3.61 / +0.95 / +0.72 | -4.85 / -4.87 / +1.08 / +0.63 | -3.38 / -3.39 / -1.21 / -1.48 | n/a | KOSPI -2.04 | yes |
| 2020-09-03 | Thu | -4.96 | -3.51 | +0.98 | -0.07 | 2020-09-04 | -1.50 / -1.94 / -0.65 / -1.68 | -1.75 / -2.78 / -0.58 / -2.21 | -1.63 / -1.83 / -0.48 / -1.50 | n/a | Hang Seng -1.25 | no |
| 2020-09-08 | Tue | -4.11 | -2.78 | -1.27 | -0.33 | 2020-09-09 | -0.87 / -1.17 / -0.17 / -0.35 | -1.13 / -2.92 / -0.83 / -2.10 | -0.72 / -1.10 / +0.24 / -0.73 | n/a | KOSPI -1.09 | yes |
| 2020-09-23 | Wed | -3.02 | -2.37 | +1.71 | -0.20 | 2020-09-24 | -1.09 / -3.07 / -1.05 / -2.93 | -1.32 / -3.65 / -1.05 / -3.41 | -0.89 / -4.50 / -0.75 / -4.20 | n/a | KOSPI -2.59 | yes |
| 2020-10-28 | Wed | -3.73 | -3.53 | +0.64 | -1.34 | 2020-10-29 | -0.82 / -1.05 / +0.12 / -0.50 | -0.70 / -1.69 / +0.44 / -0.58 | -0.69 / -1.26 / +0.72 / +0.32 | n/a | Taiwan -1.02 | yes |
| 2021-02-25 | Thu | -3.52 | -2.45 | +0.99 | +0.77 | 2021-02-26 | -1.38 / -4.17 / -1.18 / -3.76 | -2.03 / -5.17 / -1.77 / -4.78 | -1.05 / -2.65 / -0.74 / -2.30 | n/a | Nikkei -3.99 | yes |
| 2021-03-18 | Thu | -3.02 | -1.48 | +0.40 | -1.11 | 2021-03-19 | -0.60 / -1.43 / +1.58 / +1.28 | -0.79 / -1.46 / +1.47 / +0.90 | -0.39 / -1.36 / +1.24 / +0.75 | n/a | Nikkei -1.41 | yes |
| 2022-01-05 | Wed | -3.34 | -1.94 | -1.33 | +0.67 | 2022-01-06 | -0.87 / -1.50 / -0.71 / -1.00 | -1.20 / -1.69 / +0.15 / -0.55 | -1.11 / -2.21 / -1.04 / -1.55 | n/a | Nikkei -2.88 | yes |
| 2022-02-03 | Thu | -3.74 | -2.44 | +0.50 | -1.24 | 2022-02-04 | +0.17 / -0.56 / +0.33 / -0.25 | +0.30 / -1.15 / +0.69 / -0.57 | -0.21 / -1.47 / +0.39 / +0.07 | n/a | Nikkei +0.73 | yes |
| 2022-03-07 | Mon | -3.62 | -2.95 | -1.66 | -2.35 | 2022-03-08 | -0.73 / -1.21 / +1.04 / +0.95 | -1.03 / -2.18 / +1.19 / +0.87 | -0.46 / -0.46 / +3.01 / +2.69 | n/a | Taiwan -2.06 | yes |
| 2022-04-26 | Tue | -3.95 | -2.81 | +1.29 | +1.46 | 2022-04-27 | -0.74 / -1.41 / -0.52 / -0.94 | -0.93 / -1.81 / -0.63 / -1.03 | -0.47 / -1.77 / -0.47 / -0.77 | n/a | Taiwan -2.05 | yes |
| 2022-04-29 | Fri | -4.17 | -3.63 | +3.06 | -0.83 | 2022-05-02 | -1.04 / -1.08 / -0.06 / -0.20 | -1.28 / -1.30 / +0.41 / +0.21 | -0.77 / -2.16 / -0.67 / -1.53 | n/a | KOSPI -0.28 | no |
| 2022-05-05 | Thu | -4.99 | -3.56 | +3.19 | +0.03 | 2022-05-06 | -1.60 / -2.05 / -1.19 / -1.63 | -1.88 / -2.50 / -1.23 / -1.82 | -2.00 / -3.67 / -1.75 / -2.27 | n/a | Hang Seng -3.81 | no |
| 2022-05-09 | Mon | -4.29 | -3.20 | -1.40 | -0.67 | 2022-05-10 | -0.32 / -0.64 / +0.63 / -0.38 | -0.27 / -0.29 / +1.48 / +0.60 | -0.32 / -1.27 / +0.17 / -1.00 | n/a | Hang Seng -1.84 | no |
| 2022-05-11 | Wed | -3.18 | -1.65 | +0.98 | -0.45 | 2022-05-12 | -0.90 / -2.67 / -0.77 / -2.22 | -1.16 / -4.02 / -1.01 / -3.35 | -1.02 / -1.84 / +0.45 / -0.98 | n/a | Taiwan -2.43 | yes |
| 2022-05-18 | Wed | -4.73 | -4.04 | +2.76 | -0.12 | 2022-05-19 | -1.99 / -2.86 / -1.57 / -2.65 | -2.06 / -2.88 / -1.55 / -2.48 | -2.09 / -6.26 / -1.94 / -5.74 | n/a | Hang Seng -2.54 | yes |
| 2022-06-10 | Fri | -3.52 | -2.91 | -2.75 | -1.68 | 2022-06-13 | -2.00 / -3.20 / -1.95 / -2.64 | -2.19 / -3.69 / -2.06 / -3.13 | -2.39 / -4.54 / -2.30 / -4.12 | n/a | KOSPI -3.52 | no |
| 2022-06-13 | Mon | -4.68 | -3.88 | -3.52 | -2.64 | 2022-06-14 | -0.63 / -0.73 / +0.53 / -0.27 | -0.67 / -0.84 / +0.64 / -0.28 | -1.03 / -1.48 / +1.20 / +0.14 | n/a | Nikkei -1.32 | no |
| 2022-06-16 | Thu | -4.08 | -3.25 | +2.50 | -2.11 | 2022-06-17 | -0.57 / -1.15 / +0.26 / -0.44 | -0.69 / -1.00 / +0.84 / +0.39 | -0.99 / -2.71 / -0.53 / -1.49 | n/a | Nikkei -1.77 | yes |
| 2022-08-26 | Fri | -3.94 | -3.37 | +1.67 | +0.21 | 2022-08-29 | -2.11 / -2.24 / -1.02 / -1.40 | -2.25 / -2.68 / -1.51 / -1.82 | -3.64 / -4.74 / -3.20 / -3.53 | n/a | Nikkei -2.66 | yes |
| 2022-09-13 | Tue | -5.16 | -4.32 | +1.27 | +0.75 | 2022-09-14 | -1.65 / -1.65 / +0.12 / -0.37 | -1.38 / -1.43 / +1.84 / +1.30 | -3.09 / -3.70 / -2.86 / -3.36 | n/a | Nikkei -2.78 | no |
| 2022-10-07 | Fri | -3.80 | -2.80 | -0.68 | -0.10 | 2022-10-10 | -1.27 / -1.44 / -0.20 / -0.43 | -1.37 / -1.68 / +0.35 / -0.22 | -1.71 / -1.71 / +1.31 / +1.06 | n/a | Hang Seng -2.95 | no |
| 2022-10-14 | Fri | -3.08 | -2.37 | +2.23 | +1.01 | 2022-10-17 | -0.24 / -0.51 / +0.83 / +0.73 | -0.03 / -0.40 / +1.70 / +1.56 | -0.18 / -0.56 / +0.63 / +0.23 | n/a | Taiwan -1.23 | yes |
| 2022-11-02 | Wed | -3.36 | -2.50 | -0.89 | -0.34 | 2022-11-03 | -0.63 / -0.68 / +0.13 / -0.17 | -0.66 / -0.80 / +0.81 / +0.37 | -0.93 / -1.70 / -0.58 / -1.18 | n/a | Hang Seng -3.08 | yes |
| 2022-12-15 | Thu | -3.23 | -2.49 | -0.76 | -1.32 | 2022-12-16 | -0.52 / -0.87 / +0.14 / -0.79 | -0.54 / -0.96 / +0.23 / -0.64 | -0.97 / -1.60 / +0.15 / -1.33 | n/a | Nikkei -1.87 | yes |
| 2024-07-24 | Wed | -3.64 | -2.31 | -0.06 | -0.27 | 2024-07-25 | -0.75 / -0.83 / +0.05 / -0.03 | -1.08 / -1.48 / -0.61 / -0.83 | -0.76 / -1.05 / +0.21 / -0.15 | 6 | Nikkei -3.28 | yes |
| 2024-08-05 | Mon | -3.43 | -3.00 | -2.43 | -2.68 | 2024-08-06 | +0.56 / -0.40 / +1.36 / -0.26 | +0.69 / -0.86 / +1.19 / -0.69 | +0.34 / +0.30 / +2.50 / +0.49 | 333 | Hang Seng -0.31 | yes |
| 2024-09-03 | Tue | -3.26 | -2.12 | +1.13 | +0.00 | 2024-09-04 | -0.75 / -0.78 / -0.25 / -0.32 | -0.63 / -0.83 / -0.36 / -0.56 | -1.25 / -1.93 / -0.82 / -0.94 | 0 | Taiwan -4.52 | no |
| 2024-12-18 | Wed | -3.56 | -2.95 | -0.32 | -0.56 | 2024-12-19 | -1.33 / -1.36 / -0.80 / -1.02 | -1.36 / -1.68 / -0.67 / -1.08 | -2.27 / -2.40 / -0.57 / -1.26 | 0 | KOSPI -1.95 | no |
| 2025-01-27 | Mon | -3.07 | -1.46 | -0.50 | -1.14 | 2025-01-28 | +0.58 / +0.12 / +1.35 / +0.56 | +1.20 / +0.80 / +2.46 / +1.67 | +0.09 / -0.78 / +0.96 / -0.57 | 63 | Nikkei -1.39 | yes |
| 2025-03-10 | Mon | -4.00 | -2.70 | +0.70 | -0.41 | 2025-03-11 | -0.51 / -0.65 / +0.28 / +0.17 | -0.71 / -1.07 / -0.39 / -0.75 | -1.22 / -2.17 / -0.38 / -0.65 | 2 | Taiwan -1.73 | yes |
| 2025-04-03 | Thu | -5.97 | -4.84 | +0.87 | -0.35 | 2025-04-04 | -0.26 / -1.69 / -0.15 / -1.49 | +0.22 / -0.46 / +0.57 / -0.18 | -1.53 / -3.85 / -1.14 / -3.58 | 342 | Nikkei -2.75 | no |
| 2025-04-04 | Fri | -5.82 | -5.97 | -5.97 | -1.49 | 2025-04-07 | -5.00 / -5.07 / -2.84 / -3.24 | -4.21 / -4.55 / -2.09 / -3.19 | -6.58 / -7.74 / -2.02 / -2.51 | 0 | Hang Seng -13.22 | yes |
| 2025-04-10 | Thu | -4.31 | -3.46 | +12.16 | -0.61 | 2025-04-11 | +1.32 / +1.32 / +2.34 / +1.92 | +0.78 / +0.78 / +2.00 / +1.52 | +1.26 / +0.03 / +2.13 / +0.69 | 0 | Nikkei -2.96 | yes |
| 2025-04-16 | Wed | -3.07 | -2.24 | -0.05 | +0.47 | 2025-04-17 | -0.15 / -0.59 / +1.86 / +1.77 | +0.07 / -0.06 / +2.43 / +2.21 | -1.39 / -2.48 / +0.53 / +0.23 | 14 | Taiwan -0.66 | yes |
| 2025-10-10 | Fri | -3.56 | -2.71 | -0.08 | +0.41 | 2025-10-13 | -0.43 / -0.53 / -0.07 / -0.23 | -0.48 / -0.50 / +0.28 / +0.03 | -0.59 / -1.51 / -0.29 / -0.78 | 19 | Hang Seng -1.52 | yes |
| 2026-06-05 | Fri | -4.18 | -2.64 | -0.09 | -0.21 | 2026-06-08 | -1.22 / -1.27 / -0.43 / -1.04 | -1.18 / -1.20 / -0.08 / -0.79 | -1.49 / -2.04 / -0.33 / -1.23 | 1 | KOSPI -8.29 | yes |
| 2026-11-05 | Thu | -5.52 | -4.36 | +1.44 | +2.40 | 2026-11-06 | +0.01 / -0.61 / +2.01 / +2.01 | +0.07 / -0.78 / +2.27 / +2.27 | +1.32 / -0.34 / +2.37 / +0.43 | 1 | KOSPI -6.02 | yes |

### Nasdaq Composite <= -4.5% (n=31)

| US date | day | Nasdaq % | S&P % | US prev day % | India day-of NIFTY % | India date | NIFTY gap / low / high / close | BANKNIFTY gap / low / high / close | IT gap / low / high / close | NIFTY min to low | Asia on India date (min) | back in 5 s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2008-09-17 | Wed | -4.94 | -4.71 | +1.28 | -1.64 | 2008-09-18 | n/a / -5.21 / n/a / +0.75 | -3.72 / -6.10 / +3.20 / +2.79 | -2.54 / -6.02 / +0.25 / -1.78 | n/a | Taiwan -2.74 | yes |
| 2008-09-29 | Mon | -9.14 | -8.81 | -0.15 | -3.39 | 2008-09-30 | n/a / -3.51 / n/a / +1.85 | -1.64 / -4.37 / +6.08 / +4.78 | -2.51 / -4.88 / +4.63 / +1.84 | n/a | Nikkei -4.12 | yes |
| 2008-10-07 | Tue | -5.80 | -5.74 | -4.34 | +0.12 | 2008-10-08 | n/a / -7.68 / n/a / -2.58 | -2.23 / -9.88 / -2.23 / -4.31 | -2.41 / -10.37 / -2.41 / -5.72 | n/a | Nikkei -9.38 | no |
| 2008-10-09 | Thu | -5.47 | -7.62 | -0.83 | -2.58 | 2008-10-10 | n/a / -8.96 / n/a / -6.65 | -6.37 / -10.73 / -2.11 / -5.45 | -1.34 / -11.68 / -1.34 / -5.56 | n/a | Nikkei -9.62 | yes |
| 2008-10-15 | Wed | -8.47 | -9.03 | -3.54 | -5.12 | 2008-10-16 | n/a / -7.14 / n/a / -2.07 | -3.75 / -5.15 / +2.58 / +1.04 | -4.82 / -11.00 / -2.83 / -4.61 | n/a | Nikkei -11.41 | no |
| 2008-10-22 | Wed | -4.77 | -6.10 | -4.14 | -5.25 | 2008-10-23 | n/a / -4.83 / n/a / -3.98 | -3.75 / -4.22 / +1.85 / -3.21 | -3.64 / -5.47 / +4.52 / -1.73 | n/a | KOSPI -7.48 | no |
| 2008-11-05 | Wed | -5.53 | -5.27 | +3.12 | -4.68 | 2008-11-06 | n/a / -4.50 / n/a / -3.42 | -3.35 / -4.84 / +0.31 / -3.54 | -2.14 / -5.07 / +0.29 / -3.87 | n/a | KOSPI -7.56 | yes |
| 2008-11-12 | Wed | -5.17 | -5.19 | -2.22 | -3.07 | 2008-11-14 | n/a / -2.45 / n/a / -1.34 | +2.49 / -1.69 / +3.75 / -0.61 | +1.86 / -3.69 / +2.62 / -2.47 | n/a | KOSPI -0.02 | no |
| 2008-11-14 | Fri | -5.00 | -4.17 | +6.50 | -1.34 | 2008-11-17 | n/a / -4.12 / n/a / -0.38 | +0.36 / -7.52 / +0.36 / -3.69 | +0.10 / -3.41 / +0.76 / +0.19 | n/a | KOSPI -0.91 | no |
| 2008-11-19 | Wed | -6.53 | -6.12 | +0.08 | -1.79 | 2008-11-20 | n/a / -5.01 / n/a / -3.11 | -3.68 / -6.18 / -1.23 / -3.47 | -2.21 / -5.13 / -1.46 / -2.87 | n/a | Nikkei -6.89 | yes |
| 2008-11-20 | Thu | -5.07 | -6.71 | -6.53 | -3.11 | 2008-11-21 | n/a / -0.52 / n/a / +5.50 | -0.08 / -0.85 / +7.10 / +5.23 | -0.99 / -1.18 / +6.08 / +5.25 | n/a | Taiwan +1.98 | yes |
| 2008-12-01 | Mon | -8.95 | -8.93 | +0.23 | -2.62 | 2008-12-02 | n/a / -4.18 / n/a / -0.94 | -3.28 / -4.98 / -0.03 / -0.61 | -3.61 / -5.24 / -2.14 / -2.65 | n/a | Nikkei -6.35 | yes |
| 2009-01-20 | Tue | -5.78 | -5.28 | +1.16 | -1.74 | 2009-01-21 | n/a / -3.80 / n/a / -3.23 | -1.24 / -3.90 / -0.85 / -3.41 | -0.30 / -2.91 / -0.12 / -2.22 | n/a | Hang Seng -2.90 | yes |
| 2011-08-04 | Thu | -5.08 | -4.78 | +0.89 | -1.35 | 2011-08-05 | -2.39 / -4.04 / -1.92 / -2.26 | -2.19 / -3.67 / -1.37 / -1.73 | -2.19 / -6.28 / -2.19 / -3.99 | n/a | Taiwan -5.58 | no |
| 2011-08-08 | Mon | -6.90 | -6.66 | -0.94 | -1.78 | 2011-08-09 | -3.33 / -3.36 / +0.95 / -0.89 | -2.74 / -3.04 / +1.88 / -0.35 | -4.18 / -4.56 / -1.41 / -3.53 | n/a | Hang Seng -5.66 | yes |
| 2011-08-18 | Thu | -5.22 | -4.46 | -0.47 | -2.22 | 2011-08-19 | -1.72 / -2.99 / -1.02 / -1.99 | -1.55 / -3.35 / -0.14 / -2.05 | -2.61 / -6.31 / -2.61 / -4.38 | n/a | KOSPI -6.22 | yes |
| 2020-02-27 | Thu | -4.61 | -4.42 | +0.17 | -0.39 | 2020-02-28 | -2.16 / -3.94 / -2.14 / -3.71 | -2.27 / -3.76 / -2.06 / -3.44 | -2.47 / -6.00 / -2.08 / -5.65 | n/a | Nikkei -3.67 | no |
| 2020-03-09 | Mon | -7.29 | -7.60 | -1.86 | -4.90 | 2020-03-11 | -1.12 / -1.12 / +0.90 / +0.07 | -0.72 / -0.86 / +1.24 / +0.10 | -2.23 / -3.36 / -0.21 / -1.17 | n/a | KOSPI -2.78 | yes |
| 2020-03-11 | Wed | -4.70 | -4.89 | +4.95 | +0.07 | 2020-03-12 | -4.00 / -9.09 / -3.99 / -8.30 | -4.95 / -11.14 / -4.77 / -9.50 | -3.43 / -9.29 / -3.06 / -8.83 | n/a | Nikkei -4.41 | no |
| 2020-03-12 | Thu | -9.43 | -9.51 | -4.70 | -8.30 | 2020-03-13 | -5.03 / -10.79 / +5.94 / +3.81 | -5.22 / -10.93 / +7.09 / +4.99 | -6.15 / -13.15 / +3.37 / +1.15 | n/a | Nikkei -6.08 | yes |
| 2020-03-16 | Mon | -12.32 | -11.98 | +9.35 | -7.61 | 2020-03-17 | +0.96 / -3.06 / +2.24 / -2.50 | +1.07 / -4.76 / +1.51 / -4.10 | +0.53 / -3.63 / +1.81 / -2.83 | n/a | Taiwan -2.86 | no |
| 2020-03-18 | Wed | -4.70 | -5.18 | +6.23 | -5.56 | 2020-03-19 | -4.79 / -7.51 / +1.26 / -2.42 | -5.59 / -9.25 / +2.21 / -2.41 | -4.84 / -6.48 / -0.47 / -3.51 | n/a | KOSPI -8.39 | yes |
| 2020-06-11 | Thu | -5.27 | -5.89 | +0.67 | -2.12 | 2020-06-12 | -3.61 / -3.61 / +0.95 / +0.72 | -4.85 / -4.87 / +1.08 / +0.63 | -3.38 / -3.39 / -1.21 / -1.48 | n/a | KOSPI -2.04 | yes |
| 2020-09-03 | Thu | -4.96 | -3.51 | +0.98 | -0.07 | 2020-09-04 | -1.50 / -1.94 / -0.65 / -1.68 | -1.75 / -2.78 / -0.58 / -2.21 | -1.63 / -1.83 / -0.48 / -1.50 | n/a | Hang Seng -1.25 | no |
| 2022-05-05 | Thu | -4.99 | -3.56 | +3.19 | +0.03 | 2022-05-06 | -1.60 / -2.05 / -1.19 / -1.63 | -1.88 / -2.50 / -1.23 / -1.82 | -2.00 / -3.67 / -1.75 / -2.27 | n/a | Hang Seng -3.81 | no |
| 2022-05-18 | Wed | -4.73 | -4.04 | +2.76 | -0.12 | 2022-05-19 | -1.99 / -2.86 / -1.57 / -2.65 | -2.06 / -2.88 / -1.55 / -2.48 | -2.09 / -6.26 / -1.94 / -5.74 | n/a | Hang Seng -2.54 | yes |
| 2022-06-13 | Mon | -4.68 | -3.88 | -3.52 | -2.64 | 2022-06-14 | -0.63 / -0.73 / +0.53 / -0.27 | -0.67 / -0.84 / +0.64 / -0.28 | -1.03 / -1.48 / +1.20 / +0.14 | n/a | Nikkei -1.32 | no |
| 2022-09-13 | Tue | -5.16 | -4.32 | +1.27 | +0.75 | 2022-09-14 | -1.65 / -1.65 / +0.12 / -0.37 | -1.38 / -1.43 / +1.84 / +1.30 | -3.09 / -3.70 / -2.86 / -3.36 | n/a | Nikkei -2.78 | no |
| 2025-04-03 | Thu | -5.97 | -4.84 | +0.87 | -0.35 | 2025-04-04 | -0.26 / -1.69 / -0.15 / -1.49 | +0.22 / -0.46 / +0.57 / -0.18 | -1.53 / -3.85 / -1.14 / -3.58 | 342 | Nikkei -2.75 | no |
| 2025-04-04 | Fri | -5.82 | -5.97 | -5.97 | -1.49 | 2025-04-07 | -5.00 / -5.07 / -2.84 / -3.24 | -4.21 / -4.55 / -2.09 / -3.19 | -6.58 / -7.74 / -2.02 / -2.51 | 0 | Hang Seng -13.22 | yes |
| 2026-11-05 | Thu | -5.52 | -4.36 | +1.44 | +2.40 | 2026-11-06 | +0.01 / -0.61 / +2.01 / +2.01 | +0.07 / -0.78 / +2.27 / +2.27 | +1.32 / -0.34 / +2.37 / +0.43 | 1 | KOSPI -6.02 | yes |

### S&P 500 <= -2.5% (n=130)

| US date | day | Nasdaq % | S&P % | US prev day % | India day-of NIFTY % | India date | NIFTY gap / low / high / close | BANKNIFTY gap / low / high / close | IT gap / low / high / close | NIFTY min to low | Asia on India date (min) | back in 5 s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2007-10-19 | Fri | -2.65 | -2.56 | -0.08 | -2.54 | 2007-10-22 | n/a / -2.77 / n/a / -0.60 | -0.67 / -1.81 / +2.67 / +1.94 | -1.43 / -2.34 / -0.72 / -1.78 | n/a | Hang Seng -3.70 | yes |
| 2007-11-01 | Thu | -2.25 | -2.64 | +1.20 | -0.58 | 2007-11-02 | n/a / -2.59 / n/a / +1.12 | -2.67 / -3.27 / +4.48 / +3.94 | -1.37 / -2.03 / +0.15 / -0.14 | n/a | Taiwan -3.39 | yes |
| 2007-11-07 | Wed | -2.70 | -2.94 | +1.20 | -0.07 | 2007-11-08 | n/a / -2.35 / n/a / -1.45 | +0.01 / -3.01 / +0.01 / -2.35 | -0.40 / -1.78 / -0.40 / -1.11 | n/a | Taiwan -3.90 | yes |
| 2007-12-11 | Tue | -2.45 | -2.53 | +0.75 | +2.29 | 2007-12-12 | n/a / -1.51 / n/a / +1.02 | -1.38 / -1.98 / -0.04 / -0.34 | -0.79 / -2.56 / -0.48 / -0.69 | n/a | Hang Seng -2.41 | yes |
| 2008-01-17 | Thu | -1.99 | -2.91 | -0.56 | -0.38 | 2008-01-18 | n/a / -3.99 / n/a / -3.52 | -0.91 / -5.97 / -0.45 / -5.08 | +0.03 / -2.33 / +0.18 / -1.89 | n/a | Hang Seng +0.35 | no |
| 2008-02-05 | Tue | -3.08 | -3.20 | -1.05 | +0.37 | 2008-02-06 | n/a / -4.14 / n/a / -2.94 | -2.43 / -3.68 / -1.51 / -2.26 | -0.03 / -5.63 / -0.03 / -5.15 | n/a | Hang Seng -5.40 | no |
| 2008-02-29 | Fri | -2.58 | -2.71 | -0.89 | -1.17 | 2008-03-03 | n/a / -5.50 / n/a / -5.18 | -2.62 / -7.87 / -2.62 / -7.38 | -1.32 / -4.78 / -1.19 / -4.00 | n/a | Nikkei -4.49 | no |
| 2008-06-06 | Fri | -2.96 | -3.09 | +1.95 | -1.05 | 2008-06-09 | n/a / -4.67 / n/a / -2.74 | -2.92 / -5.49 / -2.48 / -3.11 | -1.65 / -5.50 / -1.65 / -4.64 | n/a | Nikkei -2.13 | no |
| 2008-06-26 | Thu | -3.33 | -2.94 | +0.58 | +1.49 | 2008-06-27 | n/a / -4.56 / n/a / -4.15 | -3.05 / -5.97 / -3.05 / -5.47 | -1.49 / -4.88 / -1.49 / -4.56 | n/a | Taiwan -3.37 | no |
| 2008-09-04 | Thu | -3.20 | -2.99 | -0.20 | -1.25 | 2008-09-05 | n/a / -2.67 / n/a / -2.15 | -2.72 / -3.63 / -1.63 / -3.17 | -1.20 / -3.37 / -1.20 / -3.13 | n/a | Nikkei -2.75 | yes |
| 2008-09-09 | Tue | -2.64 | -3.41 | +2.05 | -0.30 | 2008-09-10 | n/a / -1.93 / n/a / -1.53 | -0.62 / -1.75 / +0.68 / -0.21 | +0.02 / -0.79 / +0.89 / -0.57 | n/a | Hang Seng -2.40 | no |
| 2008-09-15 | Mon | -3.60 | -4.71 | +0.21 | -3.68 | 2008-09-16 | n/a / -3.77 / n/a / +0.05 | -3.57 / -4.06 / +2.86 / +2.26 | -3.14 / -4.43 / -0.92 / -1.83 | n/a | KOSPI -6.10 | yes |
| 2008-09-17 | Wed | -4.94 | -4.71 | +1.75 | -1.64 | 2008-09-18 | n/a / -5.21 / n/a / +0.75 | -3.72 / -6.10 / +3.20 / +2.79 | -2.54 / -6.02 / +0.25 / -1.78 | n/a | Taiwan -2.74 | yes |
| 2008-09-22 | Mon | -4.17 | -3.82 | +4.03 | -0.52 | 2008-09-23 | n/a / -2.49 / n/a / -2.28 | -2.48 / -4.68 / -0.71 / -4.29 | -1.94 / -5.33 / -1.06 / -5.04 | n/a | Hang Seng -3.87 | no |
| 2008-09-29 | Mon | -9.14 | -8.81 | +0.34 | -3.39 | 2008-09-30 | n/a / -3.51 / n/a / +1.85 | -1.64 / -4.37 / +6.08 / +4.78 | -2.51 / -4.88 / +4.63 / +1.84 | n/a | Nikkei -4.12 | yes |
| 2008-10-02 | Thu | -4.48 | -4.03 | -0.45 | +0.75 | 2008-10-03 | n/a / -3.69 / n/a / -3.35 | -1.03 / -3.69 / +0.58 / -3.16 | +0.79 / -3.33 / +0.79 / -2.71 | n/a | Hang Seng -2.90 | no |
| 2008-10-06 | Mon | -4.34 | -3.85 | -1.35 | -5.66 | 2008-10-07 | n/a / -1.81 / n/a / +0.12 | +2.75 / -3.32 / +4.29 / -1.85 | +1.76 / -5.66 / +3.82 / -3.65 | n/a | Nikkei -3.03 | yes |
| 2008-10-07 | Tue | -5.80 | -5.74 | -3.85 | +0.12 | 2008-10-08 | n/a / -7.68 / n/a / -2.58 | -2.23 / -9.88 / -2.23 / -4.31 | -2.41 / -10.37 / -2.41 / -5.72 | n/a | Nikkei -9.38 | no |
| 2008-10-09 | Thu | -5.47 | -7.62 | -1.13 | -2.58 | 2008-10-10 | n/a / -8.96 / n/a / -6.65 | -6.37 / -10.73 / -2.11 / -5.45 | -1.34 / -11.68 / -1.34 / -5.56 | n/a | Nikkei -9.62 | yes |
| 2008-10-15 | Wed | -8.47 | -9.03 | -0.53 | -5.12 | 2008-10-16 | n/a / -7.14 / n/a / -2.07 | -3.75 / -5.15 / +2.58 / +1.04 | -4.82 / -11.00 / -2.83 / -4.61 | n/a | Nikkei -11.41 | no |
| 2008-10-21 | Tue | -4.14 | -3.08 | +4.77 | +3.59 | 2008-10-22 | n/a / -5.66 / n/a / -5.25 | -1.39 / -6.26 / -0.93 / -5.89 | -1.73 / -5.65 / -1.73 / -4.25 | n/a | Nikkei -6.79 | no |
| 2008-10-22 | Wed | -4.77 | -6.10 | -3.08 | -5.25 | 2008-10-23 | n/a / -4.83 / n/a / -3.98 | -3.75 / -4.22 / +1.85 / -3.21 | -3.64 / -5.47 / +4.52 / -1.73 | n/a | KOSPI -7.48 | no |
| 2008-10-24 | Fri | -3.23 | -3.45 | +1.26 | -12.20 | 2008-10-27 | n/a / -12.82 / n/a / -2.31 | -0.68 / -11.85 / -0.55 / -5.04 | -1.14 / -12.02 / +0.51 / -1.43 | n/a | Hang Seng -12.70 | yes |
| 2008-10-27 | Mon | -2.97 | -3.18 | -3.45 | -2.31 | 2008-10-29 | n/a / +4.27 / n/a / +6.85 | +8.77 / +3.50 / +8.95 / +4.58 | +8.59 / +4.94 / +10.07 / +7.07 | n/a | KOSPI -3.02 | yes |
| 2008-11-05 | Wed | -5.53 | -5.27 | +4.08 | -4.68 | 2008-11-06 | n/a / -4.50 / n/a / -3.42 | -3.35 / -4.84 / +0.31 / -3.54 | -2.14 / -5.07 / +0.29 / -3.87 | n/a | KOSPI -7.56 | yes |
| 2008-11-06 | Thu | -4.34 | -5.03 | -5.27 | -3.42 | 2008-11-07 | n/a / -1.13 / n/a / +2.78 | -0.93 / -2.74 / +3.19 / +2.10 | -1.54 / -2.18 / +3.79 / +2.44 | n/a | Nikkei -3.55 | yes |
| 2008-11-12 | Wed | -5.17 | -5.19 | -2.20 | -3.07 | 2008-11-14 | n/a / -2.45 / n/a / -1.34 | +2.49 / -1.69 / +3.75 / -0.61 | +1.86 / -3.69 / +2.62 / -2.47 | n/a | KOSPI -0.02 | no |
| 2008-11-14 | Fri | -5.00 | -4.17 | +6.92 | -1.34 | 2008-11-17 | n/a / -4.12 / n/a / -0.38 | +0.36 / -7.52 / +0.36 / -3.69 | +0.10 / -3.41 / +0.76 / +0.19 | n/a | KOSPI -0.91 | no |
| 2008-11-17 | Mon | -2.29 | -2.58 | -4.17 | -0.38 | 2008-11-18 | n/a / -4.83 / n/a / -4.16 | -1.56 / -5.73 / -1.56 / -4.37 | -0.96 / -6.04 / -0.96 / -5.42 | n/a | Hang Seng -4.54 | no |
| 2008-11-19 | Wed | -6.53 | -6.12 | +0.98 | -1.79 | 2008-11-20 | n/a / -5.01 / n/a / -3.11 | -3.68 / -6.18 / -1.23 / -3.47 | -2.21 / -5.13 / -1.46 / -2.87 | n/a | Nikkei -6.89 | yes |
| 2008-11-20 | Thu | -5.07 | -6.71 | -6.12 | -3.11 | 2008-11-21 | n/a / -0.52 / n/a / +5.50 | -0.08 / -0.85 / +7.10 / +5.23 | -0.99 / -1.18 / +6.08 / +5.25 | n/a | Taiwan +1.98 | yes |
| 2008-12-01 | Mon | -8.95 | -8.93 | +0.96 | -2.62 | 2008-12-02 | n/a / -4.18 / n/a / -0.94 | -3.28 / -4.98 / -0.03 / -0.61 | -3.61 / -5.24 / -2.14 / -2.65 | n/a | Nikkei -6.35 | yes |
| 2008-12-04 | Thu | -3.14 | -2.93 | +2.58 | +4.95 | 2008-12-05 | n/a / -3.11 / n/a / -2.64 | -0.08 / -3.11 / +3.71 / -2.02 | -0.91 / -4.49 / -0.91 / -3.92 | n/a | Taiwan -0.70 | yes |
| 2008-12-11 | Thu | -3.68 | -2.85 | +1.19 | -0.28 | 2008-12-12 | n/a / -3.68 / n/a / +0.04 | -2.06 / -4.04 / +1.97 / +1.26 | -1.13 / -5.35 / -1.13 / -3.60 | n/a | Nikkei -5.56 | yes |
| 2009-01-07 | Wed | -3.23 | -3.00 | +0.78 | -6.18 | 2009-01-09 | n/a / -3.77 / n/a / -1.62 | -1.86 / -2.90 / +1.45 / -1.56 | -0.52 / -2.42 / +3.55 / +1.46 | n/a | KOSPI -2.05 | no |
| 2009-01-14 | Wed | -3.67 | -3.35 | +0.18 | +3.29 | 2009-01-15 | n/a / -4.71 / n/a / -3.48 | -3.21 / -6.49 / -3.21 / -5.61 | -3.83 / -6.37 / -3.48 / -3.95 | n/a | KOSPI -6.03 | yes |
| 2009-01-20 | Tue | -5.78 | -5.28 | +0.76 | -1.74 | 2009-01-21 | n/a / -3.80 / n/a / -3.23 | -1.24 / -3.90 / -0.85 / -3.41 | -0.30 / -2.91 / -0.12 / -2.22 | n/a | Hang Seng -2.90 | yes |
| 2009-01-29 | Thu | -3.24 | -3.31 | +3.36 | -0.90 | 2009-01-30 | n/a / -1.77 / n/a / +1.80 | -1.66 / -1.76 / +2.54 / +2.17 | -0.80 / -1.68 / +1.31 / +0.94 | n/a | Nikkei -3.12 | yes |
| 2009-02-10 | Tue | -4.20 | -4.91 | +0.15 | +0.50 | 2009-02-11 | n/a / -1.94 / n/a / -0.30 | -2.00 / -2.49 / +0.16 / -0.25 | -1.17 / -1.89 / -0.73 / -1.13 | n/a | Hang Seng -2.46 | yes |
| 2009-02-17 | Tue | -4.15 | -4.56 | -1.00 | -2.74 | 2009-02-18 | n/a / -1.22 / n/a / +0.20 | -1.51 / -3.00 / +0.39 / -2.09 | -0.93 / -0.93 / +1.10 / -0.02 | n/a | Nikkei -1.45 | yes |
| 2009-02-23 | Mon | -3.71 | -3.47 | -1.14 | -1.90 | 2009-02-24 | n/a / -2.15 / n/a / -0.09 | -0.27 / -3.55 / -0.27 / -1.42 | -0.18 / -2.46 / -0.02 / -0.51 | n/a | KOSPI -3.24 | yes |
| 2009-03-02 | Mon | -3.99 | -4.66 | -2.36 | -3.22 | 2009-03-03 | n/a / -2.36 / n/a / -1.95 | -0.97 / -2.59 / +0.86 / -2.19 | +0.02 / -2.35 / +0.07 / -1.95 | n/a | Hang Seng -2.30 | no |
| 2009-03-05 | Thu | -4.00 | -4.25 | +2.38 | -2.59 | 2009-03-06 | n/a / -1.45 / n/a / +1.69 | -1.77 / -3.12 / +2.75 / +0.26 | -0.53 / -0.89 / +3.55 / +3.13 | n/a | Nikkei -3.50 | yes |
| 2009-03-30 | Mon | -2.81 | -3.48 | -2.03 | -4.20 | 2009-03-31 | n/a / -0.39 / n/a / +1.44 | +0.89 / -4.07 / +4.40 / +2.42 | +1.26 / +0.57 / +3.01 / +2.26 | n/a | Nikkei -1.54 | yes |
| 2009-04-20 | Mon | -3.88 | -4.28 | +0.50 | -0.22 | 2009-04-21 | n/a / -2.01 / n/a / -0.35 | -1.00 / -3.69 / -0.97 / -3.10 | +0.78 / -1.79 / +0.78 / -1.27 | n/a | Hang Seng -2.95 | yes |
| 2009-05-13 | Wed | -3.01 | -2.69 | -0.10 | -1.25 | 2009-05-14 | n/a / -2.69 / n/a / -1.15 | -1.96 / -3.50 / -0.14 / -0.52 | -1.89 / -2.49 / -0.00 / -0.49 | n/a | Hang Seng -3.04 | yes |
| 2009-06-22 | Mon | -3.35 | -3.06 | +0.31 | -1.82 | 2009-06-23 | n/a / -2.17 / n/a / +0.28 | -1.68 / -3.33 / -1.38 / -1.91 | -1.60 / -2.10 / +0.54 / -0.43 | n/a | Hang Seng -2.89 | yes |
| 2009-07-02 | Thu | -2.67 | -2.91 | +0.44 | +0.18 | 2009-07-03 | n/a / -1.15 / n/a / +1.73 | -0.72 / -1.07 / +2.55 / +2.27 | -0.15 / -1.48 / +0.75 / +0.31 | n/a | Nikkei -0.61 | yes |
| 2009-10-01 | Thu | -3.06 | -2.58 | -0.33 | -0.01 | 2009-10-05 | n/a / -1.80 / n/a / -1.58 | -1.07 / -2.59 / -0.81 / -2.25 | -1.15 / -1.65 / +0.57 / -1.05 | n/a | KOSPI -2.29 | no |
| 2009-10-30 | Fri | -2.50 | -2.81 | +2.25 | -0.82 | 2009-11-03 | n/a / -3.68 / n/a / -3.14 | -0.79 / -2.74 / +0.81 / -2.17 | +0.24 / -4.37 / +0.40 / -3.94 | n/a | Hang Seng -1.76 | yes |
| 2010-02-04 | Thu | -2.99 | -3.11 | -0.55 | -1.75 | 2010-02-05 | n/a / -3.16 / n/a / -2.61 | -1.79 / -3.79 / -1.79 / -2.93 | -1.89 / -2.95 / -0.99 / -2.09 | n/a | Taiwan -4.30 | no |
| 2010-05-06 | Thu | -3.44 | -3.24 | -0.66 | -0.66 | 2010-05-07 | n/a / -2.09 / n/a / -1.43 | -1.62 / -3.57 / -1.44 / -3.19 | -0.96 / -2.65 / -0.85 / -2.41 | n/a | Nikkei -3.10 | yes |
| 2010-05-20 | Thu | -4.11 | -3.90 | -0.51 | +0.57 | 2010-05-21 | n/a / -2.13 / n/a / -0.33 | -0.25 / -2.24 / +0.00 / -0.42 | -0.74 / -1.87 / -0.36 / -0.94 | n/a | Taiwan -2.51 | yes |
| 2010-06-04 | Fri | -3.64 | -3.44 | +0.41 | +0.49 | 2010-06-07 | n/a / -2.56 / n/a / -1.98 | -2.48 / -2.78 / -1.35 / -1.73 | -1.71 / -2.58 / -1.41 / -1.67 | n/a | Nikkei -3.84 | no |
| 2010-06-29 | Tue | -3.85 | -3.10 | -0.20 | -1.45 | 2010-06-30 | n/a / -0.88 / n/a / +1.07 | -0.40 / -0.85 / +1.12 / +0.89 | -0.95 / -1.64 / +0.26 / -0.10 | n/a | Nikkei -1.96 | yes |
| 2010-07-16 | Fri | -3.11 | -2.88 | +0.12 | +0.28 | 2010-07-19 | n/a / -0.60 / n/a / -0.14 | -0.12 / -0.57 / +0.65 / +0.19 | -0.69 / -1.08 / +0.35 / -0.22 | n/a | Hang Seng -0.79 | yes |
| 2010-08-11 | Wed | -3.01 | -2.82 | -0.60 | -0.73 | 2010-08-12 | n/a / -0.89 / n/a / -0.08 | -1.16 / -1.16 / +1.78 / +1.49 | -0.80 / -1.69 / -0.80 / -1.14 | n/a | KOSPI -2.07 | yes |
| 2011-08-02 | Tue | -2.75 | -2.56 | -0.41 | -1.09 | 2011-08-03 | -1.00 / -1.42 / -0.62 / -0.95 | -0.89 / -1.84 / -0.53 / -0.97 | -0.68 / -1.66 / -0.68 / -0.92 | n/a | KOSPI -2.59 | no |
| 2011-08-04 | Thu | -5.08 | -4.78 | +0.50 | -1.35 | 2011-08-05 | -2.39 / -4.04 / -1.92 / -2.26 | -2.19 / -3.67 / -1.37 / -1.73 | -2.19 / -6.28 / -2.19 / -3.99 | n/a | Taiwan -5.58 | no |
| 2011-08-08 | Mon | -6.90 | -6.66 | -0.06 | -1.78 | 2011-08-09 | -3.33 / -3.36 / +0.95 / -0.89 | -2.74 / -3.04 / +1.88 / -0.35 | -4.18 / -4.56 / -1.41 / -3.53 | n/a | Hang Seng -5.66 | yes |
| 2011-08-10 | Wed | -4.09 | -4.42 | +4.74 | +1.74 | 2011-08-11 | -0.64 / -0.78 / +0.46 / -0.44 | -0.42 / -1.34 / +0.51 / -1.19 | -0.67 / -1.45 / +0.27 / -0.59 | n/a | Hang Seng -0.95 | no |
| 2011-08-18 | Thu | -5.22 | -4.46 | +0.09 | -2.22 | 2011-08-19 | -1.72 / -2.99 / -1.02 / -1.99 | -1.55 / -3.35 / -0.14 / -2.05 | -2.61 / -6.31 / -2.61 / -4.38 | n/a | KOSPI -6.22 | yes |
| 2011-09-02 | Fri | -2.58 | -2.53 | -1.19 | +0.78 | 2011-09-05 | -0.82 / -1.50 / -0.19 / -0.45 | -0.76 / -1.38 / +0.51 / +0.34 | -0.84 / -2.76 / -0.84 / -1.57 | n/a | KOSPI -4.39 | yes |
| 2011-09-09 | Fri | -2.42 | -2.67 | -1.06 | -1.82 | 2011-09-12 | -1.54 / -2.93 / -1.46 / -2.23 | -1.32 / -3.43 / -1.32 / -2.93 | -2.25 / -3.73 / -2.25 / -3.40 | n/a | Hang Seng -4.21 | yes |
| 2011-09-21 | Wed | -2.01 | -2.94 | -0.17 | -0.14 | 2011-09-22 | -1.54 / -4.39 / -1.43 / -4.08 | -1.74 / -4.42 / -1.74 / -4.11 | -1.86 / -4.59 / -1.25 / -3.95 | n/a | Hang Seng -4.85 | no |
| 2011-09-22 | Thu | -3.25 | -3.19 | -2.94 | -4.08 | 2011-09-23 | -1.01 / -1.91 / +0.13 / -1.14 | -1.07 / -2.48 / +0.21 / -1.52 | -0.83 / -0.96 / +1.50 / -0.33 | n/a | KOSPI -5.73 | yes |
| 2011-10-03 | Mon | -3.29 | -2.85 | -2.50 | -1.90 | 2011-10-04 | -0.54 / -2.50 / +0.42 / -1.60 | -0.55 / -4.00 / +0.59 / -2.97 | -0.79 / -1.97 / +0.21 / -0.91 | n/a | Hang Seng -3.40 | yes |
| 2011-11-01 | Tue | -2.89 | -2.79 | -2.47 | -1.29 | 2011-11-02 | -0.78 / -1.01 / +0.80 / +0.01 | -0.85 / -0.97 / +0.68 / -0.42 | -0.55 / -0.56 / +0.68 / +0.10 | n/a | Nikkei -2.21 | yes |
| 2011-11-09 | Wed | -3.88 | -3.67 | +1.17 | -1.29 | 2011-11-11 | -1.17 / -1.51 / -0.43 / -1.00 | -0.41 / -3.36 / -0.22 / -3.13 | -4.74 / -4.74 / -0.22 / -1.03 | n/a | Nikkei +0.16 | no |
| 2013-06-20 | Thu | -2.28 | -2.50 | -1.39 | -2.86 | 2013-06-21 | -0.28 / -0.69 / +0.53 / +0.21 | -0.46 / -1.45 / +0.39 / -0.31 | +0.10 / +0.10 / +1.73 / +1.46 | n/a | KOSPI -1.49 | yes |
| 2015-08-21 | Fri | -3.52 | -3.19 | -2.11 | -0.87 | 2015-08-24 | -2.94 / -6.39 / -2.89 / -5.92 | -3.38 / -7.29 / -3.38 / -6.90 | -2.34 / -5.31 / -1.95 / -4.80 | n/a | Hang Seng -5.17 | no |
| 2015-08-24 | Mon | -3.82 | -3.94 | -3.19 | -5.92 | 2015-08-25 | +1.11 / -1.82 / +1.49 / +0.92 | +1.62 / -0.84 / +2.72 / +2.27 | +0.61 / -2.74 / +1.40 / -0.68 | n/a | Nikkei -3.96 | yes |
| 2015-09-01 | Tue | -2.94 | -2.96 | -0.84 | -2.33 | 2015-09-02 | +0.91 / -1.11 / +0.99 / -0.88 | +1.05 / -1.89 / +1.11 / -1.68 | +0.76 / +0.30 / +2.40 / +1.12 | n/a | Hang Seng -1.18 | yes |
| 2015-09-28 | Mon | -3.04 | -2.57 | -0.05 | -0.93 | 2015-09-29 | -0.90 / -1.34 / +1.68 / +0.61 | -1.41 / -2.64 / +2.11 / +1.06 | -0.61 / -0.78 / +1.03 / +0.19 | n/a | Nikkei -4.05 | yes |
| 2016-06-24 | Fri | -4.12 | -3.59 | +1.34 | -2.20 | 2016-06-27 | -0.61 / -0.61 / +0.40 / +0.08 | -0.46 / -0.46 / +1.06 / +0.51 | -1.19 / -2.02 / -0.97 / -1.74 | n/a | Taiwan -0.21 | yes |
| 2018-02-05 | Mon | -3.78 | -4.10 | -2.12 | -0.87 | 2018-02-06 | -3.48 / -3.66 / -0.68 / -1.58 | -3.67 / -4.12 / +0.16 / -1.10 | -3.25 / -3.45 / -1.44 / -2.90 | n/a | Hang Seng -5.12 | no |
| 2018-02-08 | Thu | -3.90 | -3.75 | -0.50 | +0.96 | 2018-02-09 | -1.52 / -1.69 / -0.91 / -1.15 | -1.75 / -2.12 / -1.24 / -1.76 | -1.10 / -1.89 / -0.26 / -0.76 | n/a | Hang Seng -3.10 | no |
| 2018-03-22 | Thu | -2.43 | -2.52 | -0.18 | -0.40 | 2018-03-23 | -1.44 / -1.61 / -0.86 / -1.15 | -1.47 / -2.22 / -1.43 / -1.95 | -1.58 / -1.67 / +0.60 / +0.41 | n/a | Nikkei -4.51 | yes |
| 2018-10-10 | Wed | -4.08 | -3.29 | -0.14 | +1.54 | 2018-10-11 | -2.78 / -3.07 / -1.19 / -2.16 | -3.08 / -3.27 / -1.51 / -2.12 | -2.79 / -3.89 / -1.67 / -3.04 | n/a | Taiwan -6.31 | yes |
| 2018-10-24 | Wed | -4.43 | -3.09 | -0.55 | +0.77 | 2018-10-25 | -0.88 / -1.42 / -0.57 / -0.98 | -0.89 / -1.47 / -0.35 / -0.98 | -1.10 / -1.32 / +0.93 / +0.15 | n/a | Nikkei -3.72 | yes |
| 2018-12-04 | Tue | -3.80 | -3.24 | +1.09 | -0.13 | 2018-12-05 | -0.45 / -1.12 / -0.45 / -0.80 | -0.46 / -0.94 / -0.25 / -0.65 | -0.45 / -1.41 / +0.42 / +0.09 | n/a | Taiwan -1.65 | no |
| 2018-12-24 | Mon | -2.21 | -2.71 | -2.06 | -0.84 | 2018-12-26 | -0.26 / -1.21 / +0.79 / +0.62 | -0.30 / -1.15 / +1.18 / +1.02 | -0.13 / -1.61 / -0.13 / -0.62 | n/a | KOSPI -1.31 | yes |
| 2019-08-05 | Mon | -3.47 | -2.98 | -0.73 | -1.23 | 2019-08-06 | -0.43 / -0.45 / +1.44 / +0.79 | -0.47 / -0.52 / +1.81 / +1.35 | -0.25 / -0.54 / +0.76 / -0.02 | n/a | KOSPI -1.51 | yes |
| 2019-08-14 | Wed | -3.02 | -2.93 | +1.51 | +0.95 | 2019-08-16 | +0.13 / -0.95 / +0.36 / +0.17 | -0.35 / -1.06 / +0.83 / +0.71 | +0.52 / -1.47 / +0.56 / -0.65 | n/a | KOSPI -0.58 | yes |
| 2019-08-23 | Fri | -3.00 | -2.59 | -0.05 | +0.82 | 2019-08-26 | +1.58 / -0.67 / +2.22 / +2.11 | +2.62 / -0.37 / +3.85 / +3.68 | +0.05 / -1.19 / +0.67 / +0.47 | n/a | Nikkei -2.17 | yes |
| 2020-02-24 | Mon | -3.71 | -3.35 | -1.05 | -2.08 | 2020-02-25 | +0.41 / -0.42 / +0.45 / -0.27 | +0.20 / -0.41 / +0.51 / -0.07 | +0.17 / -0.11 / +1.10 / +0.61 | n/a | Nikkei -3.34 | no |
| 2020-02-25 | Tue | -2.77 | -3.03 | -3.35 | -0.27 | 2020-02-26 | -0.50 / -1.34 / -0.12 / -1.01 | -0.50 / -0.99 / +0.27 / -0.41 | -0.39 / -1.60 / -0.14 / -1.39 | n/a | KOSPI -1.28 | no |
| 2020-02-27 | Thu | -4.61 | -4.42 | -0.38 | -0.39 | 2020-02-28 | -2.16 / -3.94 / -2.14 / -3.71 | -2.27 / -3.76 / -2.06 / -3.44 | -2.47 / -6.00 / -2.08 / -5.65 | n/a | Nikkei -3.67 | no |
| 2020-03-03 | Tue | -2.99 | -2.81 | +4.60 | +1.53 | 2020-03-04 | +0.43 / -1.96 / +0.47 / -0.46 | +0.26 / -3.61 / +0.33 / -1.79 | +0.65 / -0.70 / +1.25 / +0.90 | n/a | Hang Seng -0.24 | no |
| 2020-03-05 | Thu | -3.10 | -3.39 | +4.22 | +0.16 | 2020-03-06 | -2.90 / -3.92 / -2.08 / -2.48 | -4.04 / -5.74 / -2.67 / -3.52 | -1.66 / -2.70 / -1.08 / -1.31 | n/a | Nikkei -2.72 | no |
| 2020-03-09 | Mon | -7.29 | -7.60 | -1.71 | -4.90 | 2020-03-11 | -1.12 / -1.12 / +0.90 / +0.07 | -0.72 / -0.86 / +1.24 / +0.10 | -2.23 / -3.36 / -0.21 / -1.17 | n/a | KOSPI -2.78 | yes |
| 2020-03-11 | Wed | -4.70 | -4.89 | +4.94 | +0.07 | 2020-03-12 | -4.00 / -9.09 / -3.99 / -8.30 | -4.95 / -11.14 / -4.77 / -9.50 | -3.43 / -9.29 / -3.06 / -8.83 | n/a | Nikkei -4.41 | no |
| 2020-03-12 | Thu | -9.43 | -9.51 | -4.89 | -8.30 | 2020-03-13 | -5.03 / -10.79 / +5.94 / +3.81 | -5.22 / -10.93 / +7.09 / +4.99 | -6.15 / -13.15 / +3.37 / +1.15 | n/a | Nikkei -6.08 | yes |
| 2020-03-16 | Mon | -12.32 | -11.98 | +9.29 | -7.61 | 2020-03-17 | +0.96 / -3.06 / +2.24 / -2.50 | +1.07 / -4.76 / +1.51 / -4.10 | +0.53 / -3.63 / +1.81 / -2.83 | n/a | Taiwan -2.86 | no |
| 2020-03-18 | Wed | -4.70 | -5.18 | +6.00 | -5.56 | 2020-03-19 | -4.79 / -7.51 / +1.26 / -2.42 | -5.59 / -9.25 / +2.21 / -2.41 | -4.84 / -6.48 / -0.47 / -3.51 | n/a | KOSPI -8.39 | yes |
| 2020-03-20 | Fri | -3.79 | -4.34 | +0.47 | +5.83 | 2020-03-23 | -9.14 / -13.29 / -6.70 / -12.98 | -9.87 / -17.36 / -7.00 / -16.73 | -8.37 / -10.15 / -6.16 / -9.58 | n/a | KOSPI -5.34 | no |
| 2020-03-23 | Mon | -0.27 | -2.93 | -4.34 | -12.98 | 2020-03-24 | +3.13 / -1.30 / +5.61 / +2.51 | +4.66 / -4.74 / +5.46 / +1.12 | -0.18 / -0.18 / +7.82 / +6.13 | n/a | Taiwan +4.45 | yes |
| 2020-03-27 | Fri | -3.79 | -3.37 | +6.24 | +0.22 | 2020-03-30 | -3.17 / -4.81 / -0.97 / -4.38 | -3.58 / -6.51 / -1.27 / -5.94 | -3.31 / -3.31 / +1.63 / -1.99 | n/a | Nikkei -1.57 | yes |
| 2020-04-01 | Wed | -4.41 | -4.41 | -1.60 | -4.00 | 2020-04-03 | +1.24 / -2.40 / +1.24 / -2.06 | +0.64 / -5.85 / +0.65 / -5.27 | +0.70 / -3.53 / +0.84 / -3.04 | n/a | Hang Seng -0.19 | yes |
| 2020-04-21 | Tue | -3.48 | -3.07 | -1.79 | -3.03 | 2020-04-22 | +0.50 / -0.39 / +2.54 / +2.29 | -0.53 / -1.84 / +2.05 / +1.51 | -0.12 / -0.69 / +1.70 / +1.31 | n/a | Nikkei -0.74 | yes |
| 2020-05-01 | Fri | -3.20 | -2.81 | -0.92 | +3.21 | 2020-05-04 | -3.31 / -6.01 / -3.31 / -5.74 | -4.74 / -8.78 / -4.66 / -8.32 | -3.28 / -4.85 / -2.89 / -4.64 | n/a | Hang Seng -4.18 | no |
| 2020-06-11 | Thu | -5.27 | -5.89 | -0.53 | -2.12 | 2020-06-12 | -3.61 / -3.61 / +0.95 / +0.72 | -4.85 / -4.87 / +1.08 / +0.63 | -3.38 / -3.39 / -1.21 / -1.48 | n/a | KOSPI -2.04 | yes |
| 2020-06-24 | Wed | -2.19 | -2.59 | +0.43 | -1.58 | 2020-06-25 | -0.68 / -1.08 / +0.55 / -0.16 | -0.97 / -2.34 / +1.29 / +0.37 | -0.65 / -1.36 / +0.06 / -1.17 | n/a | KOSPI -2.27 | yes |
| 2020-09-03 | Thu | -4.96 | -3.51 | +1.54 | -0.07 | 2020-09-04 | -1.50 / -1.94 / -0.65 / -1.68 | -1.75 / -2.78 / -0.58 / -2.21 | -1.63 / -1.83 / -0.48 / -1.50 | n/a | Hang Seng -1.25 | no |
| 2020-09-08 | Tue | -4.11 | -2.78 | -0.81 | -0.33 | 2020-09-09 | -0.87 / -1.17 / -0.17 / -0.35 | -1.13 / -2.92 / -0.83 / -2.10 | -0.72 / -1.10 / +0.24 / -0.73 | n/a | KOSPI -1.09 | yes |
| 2020-10-28 | Wed | -3.73 | -3.53 | -0.30 | -1.34 | 2020-10-29 | -0.82 / -1.05 / +0.12 / -0.50 | -0.70 / -1.69 / +0.44 / -0.58 | -0.69 / -1.26 / +0.72 / +0.32 | n/a | Taiwan -1.02 | yes |
| 2021-01-27 | Wed | -2.61 | -2.57 | -0.15 | -1.91 | 2021-01-28 | -1.12 / -1.82 / -0.50 / -1.07 | -1.56 / -1.97 / +0.59 / +0.24 | -0.87 / -2.42 / -0.22 / -2.18 | n/a | Hang Seng -2.55 | yes |
| 2022-03-07 | Mon | -3.62 | -2.95 | -0.79 | -2.35 | 2022-03-08 | -0.73 / -1.21 / +1.04 / +0.95 | -1.03 / -2.18 / +1.19 / +0.87 | -0.46 / -0.46 / +3.01 / +2.69 | n/a | Taiwan -2.06 | yes |
| 2022-04-22 | Fri | -2.55 | -2.77 | -1.48 | -1.27 | 2022-04-25 | -0.95 / -1.65 / -0.69 / -1.27 | -0.70 / -1.48 / +0.63 / +0.10 | -1.00 / -2.43 / -0.91 / -2.11 | n/a | Hang Seng -3.73 | yes |
| 2022-04-26 | Tue | -3.95 | -2.81 | +0.57 | +1.46 | 2022-04-27 | -0.74 / -1.41 / -0.52 / -0.94 | -0.93 / -1.81 / -0.63 / -1.03 | -0.47 / -1.77 / -0.47 / -0.77 | n/a | Taiwan -2.05 | yes |
| 2022-04-29 | Fri | -4.17 | -3.63 | +2.47 | -0.83 | 2022-05-02 | -1.04 / -1.08 / -0.06 / -0.20 | -1.28 / -1.30 / +0.41 / +0.21 | -0.77 / -2.16 / -0.67 / -1.53 | n/a | KOSPI -0.28 | no |
| 2022-05-05 | Thu | -4.99 | -3.56 | +2.99 | +0.03 | 2022-05-06 | -1.60 / -2.05 / -1.19 / -1.63 | -1.88 / -2.50 / -1.23 / -1.82 | -2.00 / -3.67 / -1.75 / -2.27 | n/a | Hang Seng -3.81 | no |
| 2022-05-09 | Mon | -4.29 | -3.20 | -0.57 | -0.67 | 2022-05-10 | -0.32 / -0.64 / +0.63 / -0.38 | -0.27 / -0.29 / +1.48 / +0.60 | -0.32 / -1.27 / +0.17 / -1.00 | n/a | Hang Seng -1.84 | no |
| 2022-05-18 | Wed | -4.73 | -4.04 | +2.02 | -0.12 | 2022-05-19 | -1.99 / -2.86 / -1.57 / -2.65 | -2.06 / -2.88 / -1.55 / -2.48 | -2.09 / -6.26 / -1.94 / -5.74 | n/a | Hang Seng -2.54 | yes |
| 2022-06-10 | Fri | -3.52 | -2.91 | -2.38 | -1.68 | 2022-06-13 | -2.00 / -3.20 / -1.95 / -2.64 | -2.19 / -3.69 / -2.06 / -3.13 | -2.39 / -4.54 / -2.30 / -4.12 | n/a | KOSPI -3.52 | no |
| 2022-06-13 | Mon | -4.68 | -3.88 | -2.91 | -2.64 | 2022-06-14 | -0.63 / -0.73 / +0.53 / -0.27 | -0.67 / -0.84 / +0.64 / -0.28 | -1.03 / -1.48 / +1.20 / +0.14 | n/a | Nikkei -1.32 | no |
| 2022-06-16 | Thu | -4.08 | -3.25 | +1.46 | -2.11 | 2022-06-17 | -0.57 / -1.15 / +0.26 / -0.44 | -0.69 / -1.00 / +0.84 / +0.39 | -0.99 / -2.71 / -0.53 / -1.49 | n/a | Nikkei -1.77 | yes |
| 2022-08-26 | Fri | -3.94 | -3.37 | +1.41 | +0.21 | 2022-08-29 | -2.11 / -2.24 / -1.02 / -1.40 | -2.25 / -2.68 / -1.51 / -1.82 | -3.64 / -4.74 / -3.20 / -3.53 | n/a | Nikkei -2.66 | yes |
| 2022-09-13 | Tue | -5.16 | -4.32 | +1.06 | +0.75 | 2022-09-14 | -1.65 / -1.65 / +0.12 / -0.37 | -1.38 / -1.43 / +1.84 / +1.30 | -3.09 / -3.70 / -2.86 / -3.36 | n/a | Nikkei -2.78 | no |
| 2022-10-07 | Fri | -3.80 | -2.80 | -1.02 | -0.10 | 2022-10-10 | -1.27 / -1.44 / -0.20 / -0.43 | -1.37 / -1.68 / +0.35 / -0.22 | -1.71 / -1.71 / +1.31 / +1.06 | n/a | Hang Seng -2.95 | no |
| 2022-11-02 | Wed | -3.36 | -2.50 | -0.41 | -0.34 | 2022-11-03 | -0.63 / -0.68 / +0.13 / -0.17 | -0.66 / -0.80 / +0.81 / +0.37 | -0.93 / -1.70 / -0.58 / -1.18 | n/a | Hang Seng -3.08 | yes |
| 2024-08-05 | Mon | -3.43 | -3.00 | -1.84 | -2.68 | 2024-08-06 | +0.56 / -0.40 / +1.36 / -0.26 | +0.69 / -0.86 / +1.19 / -0.69 | +0.34 / +0.30 / +2.50 / +0.49 | 333 | Hang Seng -0.31 | yes |
| 2024-12-18 | Wed | -3.56 | -2.95 | -0.39 | -0.56 | 2024-12-19 | -1.33 / -1.36 / -0.80 / -1.02 | -1.36 / -1.68 / -0.67 / -1.08 | -2.27 / -2.40 / -0.57 / -1.26 | 0 | KOSPI -1.95 | no |
| 2025-03-10 | Mon | -4.00 | -2.70 | +0.55 | -0.41 | 2025-03-11 | -0.51 / -0.65 / +0.28 / +0.17 | -0.71 / -1.07 / -0.39 / -0.75 | -1.22 / -2.17 / -0.38 / -0.65 | 2 | Taiwan -1.73 | yes |
| 2025-04-03 | Thu | -5.97 | -4.84 | +0.67 | -0.35 | 2025-04-04 | -0.26 / -1.69 / -0.15 / -1.49 | +0.22 / -0.46 / +0.57 / -0.18 | -1.53 / -3.85 / -1.14 / -3.58 | 342 | Nikkei -2.75 | no |
| 2025-04-04 | Fri | -5.82 | -5.97 | -4.84 | -1.49 | 2025-04-07 | -5.00 / -5.07 / -2.84 / -3.24 | -4.21 / -4.55 / -2.09 / -3.19 | -6.58 / -7.74 / -2.02 / -2.51 | 0 | Hang Seng -13.22 | yes |
| 2025-04-10 | Thu | -4.31 | -3.46 | +9.52 | -0.61 | 2025-04-11 | +1.32 / +1.32 / +2.34 / +1.92 | +0.78 / +0.78 / +2.00 / +1.52 | +1.26 / +0.03 / +2.13 / +0.69 | 0 | Nikkei -2.96 | yes |
| 2025-10-10 | Fri | -3.56 | -2.71 | -0.28 | +0.41 | 2025-10-13 | -0.43 / -0.53 / -0.07 / -0.23 | -0.48 / -0.50 / +0.28 / +0.03 | -0.59 / -1.51 / -0.29 / -0.78 | 19 | Hang Seng -1.52 | yes |
| 2026-06-05 | Fri | -4.18 | -2.64 | +0.41 | -0.21 | 2026-06-08 | -1.22 / -1.27 / -0.43 / -1.04 | -1.18 / -1.20 / -0.08 / -0.79 | -1.49 / -2.04 / -0.33 / -1.23 | 1 | KOSPI -8.29 | yes |
| 2026-11-05 | Thu | -5.52 | -4.36 | +1.58 | +2.40 | 2026-11-06 | +0.01 / -0.61 / +2.01 / +2.01 | +0.07 / -0.78 / +2.27 / +2.27 | +1.32 / -0.34 / +2.37 / +0.43 | 1 | KOSPI -6.02 | yes |

### Next case (no India outcome yet)

| US date | day | Nasdaq % | S&P % | Nasdaq prev day % | India day-of NIFTY % | India date |
|---|---|---|---|---|---|---|
| 2026-11-20 | Fri | -5.28 | -3.70 | -2.25 | +1.12 | next India session (Mon 23 Nov 2026) - not happened |
