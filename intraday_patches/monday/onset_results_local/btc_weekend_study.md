# Bitcoin over the weekend vs Monday's NIFTY

GIR research study, made 21 Nov 2026 16:43 IST, pure code (no AI calls). Research only. Script v2/kb/btc_weekend_study.py; raw data /home/globalbot/girdata/ext/btc_weekend_study/raw/.

## The answer in plain words
- 480 weekends (2017-01-06 -> 2026-11-13). Bitcoin from Fri 15:30 IST to Mon 08:30 IST vs Monday's NIFTY gap: correlation 0.295; when BTC moved 3%+ the gap went the same way 65% (128 of 198) (base: gap up 67% (318 of 475)).
- On top of Friday's US session (Nasdaq Composite, known after India's close): r2 for Monday's gap 0.132 with Nasdaq alone -> 0.184 with BTC added (in-sample); out-of-sample 0.223 -> 0.266; sign hit 71% -> 74%. BTC vs what Nasdaq leaves unexplained: corr 0.242.
- On top of the Nasdaq-futures line (India's Fri 15:30 close -> Mon 07:30 IST, Jul 2024 ->, n=116): r2 0.556 -> 0.557 in-sample, out-of-sample 0.374 -> 0.373; sign hit 62% -> 60%; BTC vs the residual: corr 0.043.
- Mondays after a US Friday fall of 2%+ (Nasdaq or S&P, n=39): gap down 67% (26 of 39), mean gap -0.86%. With BTC also down 3%+ over the weekend (n=12): gap down 92% (11 of 12), mean -2.27%; BTC not down 3% (n=27): gap down 56% (15 of 27), mean -0.23%.
- Credit (HY bonds; FRED's spread series could not be downloaded, so HYG minus IEF is the proxy): a credit-stress day (HYG-IEF <= -0.75% or HYG <= -1%, n=169) -> India's next gap down 69% (116 of 169), mean -0.54%, vs 33% (821 of 2485) on all days. When the S&P fell 1%+ WITH credit stress (n=127): gap down 75% (95 of 127), mean -0.70%; S&P down 1%+ WITHOUT it (n=156): 76% (118 of 156), mean -0.37%. On top of the S&P move: r2 0.215 -> 0.216 (out-of-sample 0.177 -> 0.178).
- What the Sunday 19:45 brief can see (BTC Fri 15:30 -> Sun 19:30 IST, NQ futures still shut): on top of Friday's Nasdaq, r2 in-sample 0.132 -> 0.157, out-of-sample 0.223 -> 0.238, sign hit 71% -> 71%; BTC vs residual corr 0.167.
- Verdict: Bitcoin is a stand-in for the US futures, not an extra signal. While the futures are shut (Saturday, Sunday until they reopen ~03:30-04:30 IST Monday) it adds a little on top of Friday's Nasdaq close; once the NQ-futures line exists it adds nothing (residual corr 0.043, out-of-sample r2 unchanged). So: Sunday 19:45 brief - 'WEEKEND RISK GAUGE: BTC x% since Fri 15:30 IST - information only, NOT PROVEN'; Monday 07:15 brief - lead with the NQ-futures line, BTC as a footnote. The 'US fall 2%+ AND BTC down 3%+' row (n=12) is striking but small and clustered - NOT PROVEN; this weekend is in it so far. Credit stress (ETF proxy) adds nothing on top of the S&P move.

## This weekend so far (information only)
- BTC 61579.4 -> 57900.87 (-5.97%) from Fri 20 Nov 15:30 IST to 2026-11-21T12:00:00+00:00 (Bitstamp). Friday US: Nasdaq -5.28%, S&P -3.70%.

## Buckets: BTC weekend move vs Monday's NIFTY gap

**all weekends** (n=480; corr 0.295; hit on 1%+ BTC moves 62% (219 of 355), on 3%+ 65% (128 of 198); close: corr 0.22)

| BTC move % | n | gap down | mean gap | median gap |
|---|---|---|---|---|
|  .. -5 | 45 | 44% (20 of 45) | -0.75% | +0.07% |
| -5 .. -2 | 72 | 50% (36 of 72) | -0.12% | -0.01% |
| -2 .. 2 | 205 | 31% (63 of 205) | +0.17% | +0.15% |
| 2 .. 5 | 96 | 24% (23 of 96) | +0.30% | +0.24% |
| 5 ..  | 62 | 24% (15 of 62) | +0.31% | +0.33% |

**after a US Friday fall of 2%+** (n=39; corr 0.553; hit on 1%+ BTC moves 84% (26 of 31), on 3%+ 88% (15 of 17); close: corr 0.48)

| BTC move % | n | gap down | mean gap | median gap |
|---|---|---|---|---|
|  .. -5 | 8 | 88% (7 of 8) | -2.80% | -2.05% |
| -5 .. -2 | 10 | 90% (9 of 10) | -0.89% | -0.89% |
| -2 .. 2 | 14 | 57% (8 of 14) | -0.19% | -0.10% |
| 2 .. 5 | 5 | 20% (1 of 5) | +0.43% | +0.25% |
| 5 ..  | 2 | 50% (1 of 2) | -0.85% | -0.85% |

**no US Friday fall** (n=441; corr 0.21; hit on 1%+ BTC moves 60% (193 of 324), on 3%+ 62% (113 of 181); close: corr 0.143)

| BTC move % | n | gap down | mean gap | median gap |
|---|---|---|---|---|
|  .. -5 | 37 | 35% (13 of 37) | -0.31% | +0.10% |
| -5 .. -2 | 62 | 44% (27 of 62) | +0.00% | +0.11% |
| -2 .. 2 | 191 | 29% (55 of 191) | +0.19% | +0.16% |
| 2 .. 5 | 91 | 24% (22 of 91) | +0.30% | +0.24% |
| 5 ..  | 60 | 23% (14 of 60) | +0.35% | +0.33% |

## The 'on top' tests in full
- Nasdaq Friday + BTC to Sun 19:30 IST (gap): n=474, test from 2022-12-09. Base r2 in/out 0.132 / 0.223, hit 71%; with BTC 0.157 / 0.238, hit 71%; BTC vs residual corr 0.167.
- Nasdaq Friday + BTC to Sun 19:30 IST (close): n=474, test from 2022-12-09. Base r2 in/out 0.042 / 0.112, hit 58%; with BTC 0.062 / 0.106, hit 56%; BTC vs residual corr 0.142.
- Nasdaq Composite Friday + BTC (gap): n=474, test from 2022-12-09. Base r2 in/out 0.132 / 0.223, hit 71%; with BTC 0.184 / 0.266, hit 74%; BTC vs residual corr 0.242.
- Nasdaq Friday + BTC after the US close only (gap): n=474, test from 2022-12-09. Base r2 in/out 0.132 / 0.223, hit 71%; with BTC 0.171 / 0.275, hit 74%; BTC vs residual corr 0.212.
- Nasdaq Friday + BTC (Monday close): n=474, test from 2022-12-09. Base r2 in/out 0.042 / 0.112, hit 58%; with BTC 0.075 / 0.108, hit 54%; BTC vs residual corr 0.183.
- NQ futures line + BTC (gap): n=116, test from 2025-11-28. Base r2 in/out 0.556 / 0.374, hit 62%; with BTC 0.557 / 0.373, hit 60%; BTC vs residual corr 0.043.
- NQ futures line + BTC (close): n=116, test from 2025-11-28. Base r2 in/out 0.337 / 0.252, hit 72%; with BTC 0.338 / 0.252, hit 70%; BTC vs residual corr 0.027.

## Data and limits
- BTC: Bitstamp BTC/USD hourly candles, 1 Jan 2017 -> 21 Nov 2026 (free public API). Times: Fri 15:30 IST = open of the 10:00 UTC candle; Mon 08:30 IST = close of the 02:00 UTC candle.
- NIFTY: Kite day candles from Nov 2021, Yahoo ^NSEI before. 'Monday' = the first India session after a Friday session and a weekend (a Monday holiday moves it to Tuesday).
- NQ futures line: Yahoo 60-minute bars exist only from Jul 2024, so that test has about 2 years of weekends.
- High-yield spread: fred.stlouisfed.org's CSV download timed out from this server (two tries), so the ICE BofA HY OAS was NOT used; HYG / IEF / JNK ETF closes are proxies, not the spread itself.
