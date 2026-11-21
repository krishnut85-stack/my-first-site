# Can we see tomorrow's gap at 14:45?

GIR research study, made 21 Nov 2026 11:44 IST, pure code (no AI calls). Research only - GIR places no orders. Script: v2/kb/gap_predict_study.py; raw data: /home/globalbot/girdata/ext/gap_predict_study/raw/ (Yahoo, saved untouched).

## The answer in plain words
- **No.** Over 588 India days (2024-07-04 -> 2026-11-19), nothing visible by 14:30-15:10 IST predicted the next NIFTY gap better than always guessing the usual up-gap (base 56%). Sign hit rates of the 13 signals with enough data ran from 46% to 57% (best: niy, 57% of 434 days - within noise of the base). Correlations with the next gap: -0.10 to +0.04.
- All the 14:45 signals together (NQ, DAX, Asia, NIFTY itself, crude, gold, dollar, 10y; a straight-line fit) explained 3.3% of the gap in-sample and -2.4% out-of-sample (trained on 345 days, tested on the next 230 from 2025-12-04): sign right 52% vs 52% by always guessing the majority.
- The gap is made AFTER India closes. The Nasdaq-futures move from 14:30 IST to 09:00 IST next morning - not knowable at 14:45 - explains 32% of the gap (24% out-of-sample) and gets its sign right 81% (151 of 186) when it moves 1%+.
- So 'anticipate the day before' has to mean the evening, not 14:45: by 20:30 IST the NQ move since India's close already explains 7% of the gap (sign right 60% (218 of 363) on 0.3%+ moves); by the US close 14% (69% (284 of 414)); by 09:00 IST 30% (72% (304 of 425)). See the timing table.
- Big Asia falls and 'India ignored a weak US' did NOT lead to gap-downs here: when some Asia index closed -3% or worse, the next NIFTY gap was down only 38% (21 of 55); when NQ minus NIFTY was -1 point or worse, down 37% (21 of 57). India's close had already absorbed the day; the next morning followed the US night.
- One faint exception, worth re-testing, not using: on Fridays (n=116) the 14:30 signals lined up a little with Monday's gap - NQ corr 0.202, sign hit 62% (37 of 60) vs base 57%; NIFTY at 15:10 corr 0.301; Asia corr 0.209. On US event nights (FOMC / jobs Friday, approx., n=45) NQ corr 0.284, hit 64% (18 of 28). Small samples; on other weekdays the correlations are about zero or negative.
- BANKNIFTY and NIFTY IT: same picture - NQ 14:30 corr 0.008 (BANKNIFTY) and -0.005 (IT); the NQ night (not knowable) corr 0.514 and 0.431.

## Fri 20 Nov 2026: what a 14:45 'TOMORROW'S GAP' card would have said
- Values (vs the 19 Nov US cash close; Europe vs its 19 Nov close; Asia = 20 Nov closes; NIFTY vs 19 Nov close):

| signal | 14:30 IST (60m bars) | 14:45 IST (5m bars) | 15:10 IST (5m bars) |
|---|---|---|---|
| NQ futures | -0.89 | -1.16 | -1.55 |
| ES futures | -0.36 | -0.40 | -0.66 |
| SOX futures | n/a | n/a | n/a |
| Nikkei futures | -1.61 | -1.72 | -2.31 |
| DAX | -1.71 | -1.87 | -1.99 |
| FTSE | -0.57 | -0.56 | -0.82 |
| Nikkei close | -5.06 | -5.06 | -5.06 |
| KOSPI close | -5.21 | -5.21 | -5.21 |
| Taiwan close | -6.23 | -6.23 | -6.23 |
| Hang Seng close | -1.89 | -1.89 | -1.89 |
| NIFTY at 14:30 | +0.98 | +0.98 | +0.98 |
| WTI crude | -1.70 | -1.66 | -2.30 |
| gold | -2.14 | -2.20 | -2.36 |
| dollar index | -0.02 | -0.03 | -0.08 |
| 10y note futures | +0.24 | +0.28 | +0.34 |
| USD/INR | -0.52 | -0.61 | -0.65 |

- SOX futures: Yahoo's SOX=F has no trades in Asia/India hours on 20 Nov (and on all but 37 of 588 days), so the desk's '-2.4%' cannot be checked here.
- NQ futures were -0.89% at 14:30, -1.16% at 14:45, -1.55% at 15:10 (the desk's '-1.6%' matches 15:10). Asia closed -1.9% to -6.2% (average -4.60%). NIFTY was UP (+0.98% at 14:30, closed +1.12%).
- Base rates that matched at 14:30 (next NIFTY gap; sample 2024-07-04 -> 2026-11-19):

| rule that matched | n | next gap down | next gap <= -0.5% | mean gap | next close down | mean next close |
|---|---|---|---|---|---|---|
| NQ futures <= -0.5% at 14:30 | 88 | 50% (44 of 88) | 17% (15 of 88) | -0.03% | 44% (39 of 88) | +0.08% |
| some Asia index closed <= -3% | 55 | 38% (21 of 55) | 15% (8 of 55) | +0.20% | 36% (20 of 55) | +0.37% |
| Asia average <= -1% | 87 | 40% (35 of 87) | 13% (11 of 87) | +0.09% | 47% (41 of 87) | +0.15% |
| NQ <= -0.5% AND NIFTY up at 15:10 | 28 | 50% (14 of 28) | 14% (4 of 28) | -0.04% | 39% (11 of 28) | +0.21% |
| NQ minus NIFTY(15:10) <= -1 point | 57 | 37% (21 of 57) | 11% (6 of 57) | +0.11% | 40% (23 of 57) | +0.22% |
| NQ <= -0.5% AND DAX <= -0.5% | 49 | 49% (24 of 49) | 18% (9 of 49) | -0.06% | 41% (20 of 49) | +0.10% |
| NQ futures <= -1% at 14:30 (matched only on the 14:45 value, NQ -1.16%) | 39 | 46% (18 of 39) | 15% (6 of 39) | +0.12% | 38% (15 of 39) | +0.18% |
| NQ <= -1% AND Asia average <= -1% (matched only on the 14:45 value, NQ -1.16%) | 23 | 48% (11 of 23) | 22% (5 of 23) | +0.16% | 43% (10 of 23) | +0.25% |
| NQ <= -1% AND some Asia index <= -3% (matched only on the 14:45 value, NQ -1.16%) | 17 | 35% (6 of 17) | 24% (4 of 17) | +0.32% | 35% (6 of 17) | +0.42% |
| NQ <= -1% AND NIFTY up at 15:10 (India ignoring the US) (matched only on the 14:45 value, NQ -1.16%) | 11 | 27% (3 of 11) | 9% (1 of 11) | +0.18% | 18% (2 of 11) | +0.58% |
| NQ <= -1% AND Asia avg <= -1% AND NIFTY up at 15:10 (the 20 Nov shape) (matched only on the 14:45 value, NQ -1.16%) | 6 | 33% (2 of 6) | 17% (1 of 6) | +0.17% | 17% (1 of 6) | +0.89% |
| (all days, for comparison) | 588 | 43% (255 of 588) | 10% (56 of 588) | +0.03% | 49% (291 of 588) | +0.01% |

- An honest 14:45 card: 'History gives no edge on the sign tomorrow from these signals: in the matching cases the next gap was down about half the time or less (see table, n = 6-88). The gap will be set by the US session tonight - watch NQ futures from 19:00-20:30 IST.' It should not have said 'gap down'.
- What happened after 14:45 (known now, not at 14:45): NQ futures kept falling into the US session; by Friday's US close they were -5.50% vs the 19 Nov close (Nasdaq Composite -5.28%). That move is exactly the 'not knowable' part. Monday 23 Nov's outcome is not known yet.

## Base: what the next gap usually is
NIFTY, 588 days: gap up 55% (325 of 588), down 43% (255 of 588); mean gap +0.03%, mean size 0.35%; gap <= -0.5% 10% (56 of 588); next close down 49% (291 of 588).
BANKNIFTY: gap up 51% (298 of 588), down 47% (278 of 588); mean size 0.38%.
IT: gap up 55% (325 of 588), down 44% (261 of 588); mean size 0.57%.

## Each signal vs the next NIFTY gap
Hit = the gap went the signal's expected way (prior direction in the label), counting days where the signal moved at least the small / big threshold. Base = always guessing the majority sign (56%).

| signal | n | corr (Pearson / Spearman) | hit, small move | hit, big move | buckets: gap down % (n) / mean gap, low -> high |
|---|---|---|---|---|---|
| Nasdaq 100 futures (NQ=F), prev US close -> 14:30 IST (small 0.3%, big 1%) | 587 | 0.015 / 0.076 | 55% (172 of 313) | 52% (44 of 85) | <= -1: 46% (39) / +0.12; -1 .. -0.3: 45% (93) / -0.06; -0.3 .. +0.3: 45% (270) / +0.02; +0.3 .. +1: 37% (139) / +0.08; >= +1: 43% (46) / +0.04 |
| S&P 500 futures (ES=F), prev US close -> 14:30 IST (small 0.3%, big 1%) | 587 | 0.027 / 0.106 | 56% (126 of 224) | 44% (18 of 41) | <= -1: 42% (19) / +0.06; -1 .. -0.3: 48% (83) / -0.03; -0.3 .. +0.3: 44% (361) / +0.03; +0.3 .. +1: 33% (102) / +0.10; >= +1: 55% (22) / -0.06 |
| Semiconductor futures (SOX=F), prev US close -> 14:30 IST (small 0.5%, big 2%) | 37 | 0.288 / -0.037 | 38% (3 of 8) | 100% (1 of 1) | <= -2: - (0) / n/a; -2 .. -0.5: 0% (3) / +0.32; -0.5 .. +0.5: 62% (29) / -0.09; +0.5 .. +2: 50% (4) / +0.84; >= +2: 0% (1) / +1.53 |
| Nikkei futures (NIY=F), prev US close -> 14:30 IST (small 0.3%, big 1%) | 587 | 0.025 / 0.076 | 57% (247 of 434) | 55% (117 of 213) | <= -1: 51% (95) / -0.06; -1 .. -0.3: 53% (117) / -0.00; -0.3 .. +0.3: 38% (147) / +0.07; +0.3 .. +1: 35% (110) / +0.10; >= +1: 42% (118) / +0.01 |
| Asia close on D, average of Nikkei / KOSPI / Taiwan / Hang Seng (small 0.3%, big 1%) | 586 | -0.087 / -0.073 | 49% (215 of 438) | 46% (97 of 209) | <= -1: 40% (87) / +0.09; -1 .. -0.3: 41% (97) / +0.00; -0.3 .. +0.3: 44% (144) / +0.04; +0.3 .. +1: 40% (134) / +0.04; >= +1: 50% (124) / -0.03 |
| DAX, prev close -> 14:30 IST (small 0.3%, big 1%) | 577 | -0.009 / 0.024 | 53% (187 of 351) | 49% (46 of 93) | <= -1: 45% (42) / -0.03; -1 .. -0.3: 46% (113) / -0.01; -0.3 .. +0.3: 44% (220) / +0.05; +0.3 .. +1: 40% (151) / +0.05; >= +1: 47% (51) / +0.00 |
| FTSE 100, prev close -> 14:30 IST (small 0.3%, big 1%) | 574 | -0.018 / 0.035 | 55% (155 of 280) | 38% (14 of 37) | <= -1: 30% (20) / -0.01; -1 .. -0.3: 51% (102) / +0.01; -0.3 .. +0.3: 44% (291) / +0.02; +0.3 .. +1: 38% (144) / +0.08; >= +1: 53% (17) / -0.08 |
| NIFTY itself, prev close -> 15:10 IST (momentum prior) (small 0.3%, big 1%) | 587 | 0.036 / 0.077 | 55% (215 of 388) | 55% (63 of 114) | <= -1: 48% (58) / -0.05; -1 .. -0.3: 47% (134) / -0.01; -0.3 .. +0.3: 46% (193) / +0.02; +0.3 .. +1: 38% (145) / +0.09; >= +1: 37% (57) / +0.07 |
| NQ futures minus NIFTY (both to ~14:30/15:10): US weaker than India -> down (small 0.5%, big 1%) | 586 | -0.02 / -0.015 | 49% (147 of 301) | 50% (67 of 134) | <= -1: 37% (57) / +0.11; -1 .. -0.5: 45% (83) / +0.02; -0.5 .. +0.5: 43% (280) / +0.03; +0.5 .. +1: 49% (88) / -0.05; >= +1: 41% (78) / +0.07 |
| WTI crude (CL=F), prev US close -> 14:30 IST (up = bad) (small 1%, big 2%) | 587 | -0.047 / -0.101 | 50% (102 of 203) | 53% (47 of 88) | <= -2: 46% (39) / +0.09; -2 .. -1: 54% (61) / -0.01; -1 .. +1: 39% (381) / +0.05; +1 .. +2: 49% (55) / +0.06; >= +2: 51% (51) / -0.13 |
| Gold (GC=F), prev US close -> 14:30 IST (up = risk-off) (small 0.5%, big 1.5%) | 587 | -0.03 / 0.008 | 46% (128 of 278) | 42% (22 of 52) | <= -1.5: 50% (20) / +0.18; -1.5 .. -0.5: 47% (104) / -0.06; -0.5 .. +0.5: 43% (305) / +0.04; +0.5 .. +1.5: 42% (123) / +0.06; >= +1.5: 37% (35) / -0.01 |
| Dollar index, prev US close -> 14:30 IST (up = bad) (small 0.2%, big 0.5%) | 587 | -0.099 / -0.051 | 57% (97 of 171) | 50% (14 of 28) | <= -0.5: 33% (18) / +0.26; -0.5 .. -0.2: 34% (79) / +0.13; -0.2 .. +0.2: 45% (414) / +0.01; +0.2 .. +0.5: 48% (66) / -0.06; >= +0.5: 20% (10) / +0.07 |
| US 10y note futures price (ZN=F; up = yields down = good) (small 0.15%, big 0.4%) | 587 | 0.002 / 0.043 | 52% (93 of 179) | 47% (8 of 17) | <= -0.4: 33% (6) / +0.39; -0.4 .. -0.15: 48% (85) / -0.06; -0.15 .. +0.15: 42% (406) / +0.04; +0.15 .. +0.4: 44% (79) / +0.07; >= +0.4: 45% (11) / -0.31 |
| USD/INR, prev US close -> 14:30 IST (up = rupee weaker = bad) (small 0.1%, big 0.3%) | 588 | -0.051 / -0.066 | 50% (166 of 334) | 48% (58 of 120) | <= -0.3: 47% (36) / +0.08; -0.3 .. -0.1: 46% (67) / +0.07; -0.1 .. +0.1: 38% (247) / +0.08; +0.1 .. +0.3: 48% (153) / -0.07; >= +0.3: 47% (85) / -0.00 |
| NOT KNOWABLE at 14:45: NQ futures 14:30 IST D -> 09:00 IST D+1 (small 0.3%, big 1%) | 575 | 0.561 / 0.484 | 72% (311 of 431) | 81% (151 of 186) | <= -1: 74% (89) / -0.44; -1 .. -0.3: 55% (110) / -0.11; -0.3 .. +0.3: 51% (139) / +0.05; +0.3 .. +1: 28% (137) / +0.10; >= +1: 14% (100) / +0.46 |
| NOT KNOWABLE at 14:45: Nasdaq Composite close on US date D (small 0.3%, big 1%) | 569 | 0.361 / 0.384 | 69% (292 of 425) | 76% (157 of 207) | <= -1: 68% (95) / -0.34; -1 .. -0.3: 54% (95) / -0.05; -0.3 .. +0.3: 48% (139) / +0.05; +0.3 .. +1: 34% (127) / +0.10; >= +1: 19% (113) / +0.29 |

## When does the gap become knowable? (NQ futures move since India's 15:30 close vs the next NIFTY gap)

| NQ change from 15:30 IST to | n | corr | share of gap explained (r squared) | sign hit, 0.3%+ move | sign hit, 1%+ move |
|---|---|---|---|---|---|
| 18:30 IST | 568 | 0.173 | 0.03 | 63% (109 of 174) | 73% (11 of 15) |
| 20:30 IST (about 30-90 min after the US open) | 569 | 0.269 | 0.072 | 60% (218 of 363) | 70% (56 of 80) |
| 23:30 IST | 573 | 0.319 | 0.102 | 66% (271 of 409) | 74% (108 of 146) |
| US cash close (16:00 New York) | 573 | 0.372 | 0.138 | 69% (284 of 414) | 73% (115 of 157) |
| 07:30 IST next day | 575 | 0.541 | 0.293 | 72% (312 of 434) | 78% (144 of 184) |
| 09:00 IST next day | 575 | 0.552 | 0.305 | 72% (304 of 425) | 81% (149 of 184) |

## Simple combinations (next NIFTY gap; BANKNIFTY and IT in the JSON)

| rule at 14:30 IST | n | next gap down | gap <= -0.5% | mean gap | median gap | next close down | mean next close |
|---|---|---|---|---|---|---|---|
| NQ futures <= -1% at 14:30 | 39 | 46% (18 of 39) | 15% (6 of 39) | +0.12% | +0.12% | 38% (15 of 39) | +0.18% |
| NQ futures >= +1% at 14:30 | 46 | 43% (20 of 46) | 7% (3 of 46) | +0.04% | +0.03% | 63% (29 of 46) | -0.08% |
| NQ futures <= -0.5% at 14:30 | 88 | 50% (44 of 88) | 17% (15 of 88) | -0.03% | +0.00% | 44% (39 of 88) | +0.08% |
| NQ <= -1% AND Asia average <= -1% | 23 | 48% (11 of 23) | 22% (5 of 23) | +0.16% | +0.12% | 43% (10 of 23) | +0.25% |
| NQ <= -1% AND some Asia index <= -3% | 17 | 35% (6 of 17) | 24% (4 of 17) | +0.32% | +0.24% | 35% (6 of 17) | +0.42% |
| some Asia index closed <= -3% | 55 | 38% (21 of 55) | 15% (8 of 55) | +0.20% | +0.15% | 36% (20 of 55) | +0.37% |
| Asia average <= -1% | 87 | 40% (35 of 87) | 13% (11 of 87) | +0.09% | +0.09% | 47% (41 of 87) | +0.15% |
| Asia average >= +1% | 124 | 50% (62 of 124) | 9% (11 of 124) | -0.03% | -0.01% | 52% (64 of 124) | -0.07% |
| NQ <= -1% AND NIFTY up at 15:10 (India ignoring the US) | 11 | 27% (3 of 11) | 9% (1 of 11) | +0.18% | +0.28% | 18% (2 of 11) | +0.58% |
| NQ <= -0.5% AND NIFTY up at 15:10 | 28 | 50% (14 of 28) | 14% (4 of 28) | -0.04% | -0.01% | 39% (11 of 28) | +0.21% |
| NQ minus NIFTY(15:10) <= -1 point | 57 | 37% (21 of 57) | 11% (6 of 57) | +0.11% | +0.12% | 40% (23 of 57) | +0.22% |
| NQ minus NIFTY(15:10) >= +1 point | 78 | 41% (32 of 78) | 9% (7 of 78) | +0.07% | +0.06% | 45% (35 of 78) | +0.13% |
| NQ <= -0.5% AND DAX <= -0.5% | 49 | 49% (24 of 49) | 18% (9 of 49) | -0.06% | +0.02% | 41% (20 of 49) | +0.10% |
| NQ >= +0.5% AND DAX >= +0.5% | 54 | 44% (24 of 54) | 9% (5 of 54) | -0.05% | +0.03% | 65% (35 of 54) | -0.22% |
| SOX futures <= -2% (only days it traded in Asia hours) | 0 | n/a | n/a | n/a% | n/a% | n/a | n/a% |
| NQ <= -1% AND Asia avg <= -1% AND NIFTY up at 15:10 (the 20 Nov shape) | 6 | 33% (2 of 6) | 17% (1 of 6) | +0.17% | +0.29% | 17% (1 of 6) | +0.89% |
| (all days) | 588 | 43% (255 of 588) | 10% (56 of 588) | +0.03% | +0.04% | 49% (291 of 588) | +0.01% |

## Splits

| split | n | gap down (base) | NQ 14:30: corr / hit small / hit big | Asia: corr / hit small | NIFTY 15:10: corr / hit small | NQ night (not knowable): corr / hit big | NQ <= -1%: n, gap down |
|---|---|---|---|---|---|---|---|
| Friday (two nights + weekend) | 116 | 42% (49 of 116) | 0.202 / 62% (37 of 60) / 64% (9 of 14) | 0.209 / 57% (49 of 86) | 0.301 / 57% (47 of 83) | 0.776 / 95% (36 of 38) | 9, 56% (5 of 9) |
| other days | 472 | 44% (206 of 472) | -0.044 / 53% (135 of 253) / 49% (35 of 71) | -0.215 / 47% (166 of 352) | -0.08 / 55% (168 of 305) | 0.468 / 78% (115 of 148) | 30, 43% (13 of 30) |
| US event night (FOMC day or first-Friday jobs report, approx.) | 45 | 44% (20 of 45) | 0.284 / 64% (18 of 28) / 86% (6 of 7) | 0.17 / 52% (16 of 31) | 0.392 / 54% (14 of 26) | 0.865 / 93% (14 of 15) | 4, 75% (3 of 4) |
| FOMC decision night | 19 | 47% (9 of 19) | -0.04 / 40% (4 of 10) / 100% (1 of 1) | -0.394 / 36% (4 of 11) | -0.129 / 46% (6 of 13) | 0.555 / 86% (6 of 7) | 0, n/a |
| no listed event | 543 | 43% (235 of 543) | -0.009 / 54% (154 of 285) / 49% (38 of 78) | -0.129 / 49% (199 of 407) | -0.004 / 56% (201 of 362) | 0.487 / 80% (137 of 171) | 35, 43% (15 of 35) |
| next gap 0.5%+ either way | 112 | 50% (56 of 112) | -0.001 / 57% (41 of 72) / 50% (10 of 20) | -0.125 / 45% (39 of 86) | 0.044 / 54% (45 of 83) | 0.713 / 95% (61 of 64) | 13, 46% (6 of 13) |
| next gap under 0.5% | 476 | 42% (199 of 476) | 0.04 / 54% (131 of 241) / 52% (34 of 65) | -0.064 / 50% (176 of 352) | 0.041 / 56% (170 of 305) | 0.31 / 74% (90 of 122) | 26, 46% (12 of 26) |
| first half of the sample | 294 | 38% (112 of 294) | 0.015 / 58% (84 of 144) / 46% (16 of 35) | 0.009 / 52% (102 of 195) | 0.135 / 57% (105 of 183) | 0.662 / 80% (76 of 95) | 16, 38% (6 of 16) |
| second half of the sample | 294 | 49% (143 of 294) | 0.016 / 52% (88 of 169) / 56% (28 of 50) | -0.14 / 47% (113 of 243) | -0.044 / 54% (110 of 205) | 0.481 / 82% (75 of 91) | 23, 52% (12 of 23) |

## Sectors
Median next gap per index when the 14:30 signal fired (n = days).

| rule | n | NIFTY | BANKNIFTY | IT | pvt_bank | psu_bank | fin_service | pharma | fmcg | auto | metal | realty | energy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| NQ futures <= -1% at 14:30 | 39 | +0.12% | +0.05% | +0.09% | +0.04% | +0.18% | +0.06% | +0.13% | +0.11% | +0.02% | +0.18% | +0.00% | +0.09% |
| NQ futures >= +1% at 14:30 | 46 | +0.03% | +0.00% | +0.00% | -0.03% | +0.18% | +0.02% | +0.14% | +0.04% | +0.15% | +0.12% | +0.21% | +0.17% |
| NQ futures <= -0.5% at 14:30 | 88 | +0.00% | -0.00% | +0.07% | +0.02% | +0.13% | -0.01% | +0.04% | +0.07% | +0.01% | +0.11% | +0.01% | +0.08% |
| Asia average <= -1% | 87 | +0.09% | +0.02% | +0.27% | +0.01% | +0.15% | +0.01% | +0.06% | +0.06% | +0.11% | +0.05% | +0.08% | +0.12% |
| Asia average >= +1% | 124 | -0.01% | -0.01% | -0.01% | -0.03% | +0.13% | +0.02% | +0.13% | +0.08% | +0.05% | +0.17% | +0.18% | +0.12% |
| corr of next gap with NQ 14:30 | | 0.015 | 0.008 | -0.005 | 0.013 | 0.015 | 0.017 | 0.044 | 0.038 | 0.039 | 0.045 | 0.05 | 0.042 |

## Longer history: Asia close vs the next NIFTY gap (daily bars, 2011-01-04 -> 2026-11-19, n=3894)
- Asia average close on D: corr -0.047 with the next gap; hit 53% (1412 of 2669) on 0.3%+ moves, 47% (466 of 988) on 1%+ moves (base: gap up 64% (2494 of 3894)).
- Asia average <= -1%: next gap down 33% (159 of 482), mean +0.14%. Some Asia index <= -3%: next gap down 33% (53 of 163), mean +0.20%.
- For comparison, the US night (Nasdaq Composite on US date D, not knowable at 14:45): corr 0.463, hit 82% (1029 of 1251) on 1%+ moves.

## Checks
- Gap measure: the exchange day open (Kite). On 36 days the open sat within 0.02% of the previous close (a known first-print quirk); on 9 of them the 09:15 minute close was 0.2%+ away. Re-running the NQ signal on the 09:15-close gap: corr -0.017, hit 50% (156 of 314) (small) - same conclusion.
- 14:30 vs later: on the last 46 days with 5m bars (from 2026-09-15), NQ at 14:30 and 14:45 differed by a median 0.07 percentage points, 14:30 vs 15:10 by 0.07. Hit at 14:30 44% (12 of 27), at 15:10 50% (15 of 30) - no better late in the day (tiny n).
- Straight-line fits (gap on signals), first 60% of days to train, last 40% to test:
  - known_at_1445: n=575, r2 in-sample 0.033, out-of-sample -0.024, test sign hit 52% vs majority 52%; strong calls (|pred| >= 0.3%) n=4 hit 75%.
  - nq_only: n=587, r2 in-sample 0.0, out-of-sample 0.0, test sign hit 49% vs majority 51%; strong calls (|pred| >= 0.3%) n=0 hit n/a%.
  - known_plus_night: n=565, r2 in-sample 0.351, out-of-sample 0.231, test sign hit 63% vs majority 51%; strong calls (|pred| >= 0.3%) n=61 hit 77%.
  - night_only: n=575, r2 in-sample 0.315, out-of-sample 0.244, test sign hit 62% vs majority 50%; strong calls (|pred| >= 0.3%) n=62 hit 82%.

## Data: used, missing, timing
- Sample: India days 2024-07-04 -> 2026-11-19 (n=588), limited by Yahoo's 60-minute history for futures (from 1 Jul 2024). Targets: Kite exchange day candles to 20 Nov 2026.
- Timing: every '14:30' value is the close of the 60-minute bar ending 14:30 IST - the last hourly value before 15:10. Futures, FX and commodities: from the 16:00 New York close of the last US session before D. Europe: from its previous close (DAX/FTSE open 13:30 IST in winter, 12:30 IST in summer). Asia: own close on D (by 13:40 IST). NIFTY: minute data at 14:30 / 15:10. 5-minute bars (60 days) give 14:45 / 15:10 values. Nothing after 15:10 IST is used as a signal.
- SOX futures (SOX=F): almost no trades in Asia/India hours on Yahoo - a value exists on only 37 of 588 days. Not usable; the desk's SOX number is from another source.
- GIFT NIFTY premium: NO history on the server (GIR only keeps the live quote since 19 Nov 2026). Not tested. It could be fetched as Kite minute candles (NSEIX token 291849) by fetch_kite.py - not done here (no Kite calls in this study).
- FII provisional cash flow: only one day on the server (20 Nov 2026, desk/fii_daily.json). Not tested.
- US events: FOMC dates from the Fed's published calendars (hand list); jobs report = first Friday of the month (approximate; the late-2025 US shutdown delays are not modelled). US CPI dates and US / India results nights: not available, not tested.
- US 10y: the yield index (^TNX) only trades in US hours, so the 10y note future (ZN=F, price) is used instead; price up = yield down.
- Coverage of each signal (days with a value): nq 587, es 587, sox 37, niy 587, asia 586, dax 577, ftse 574, nifty1510 587, div 586, cl 587, gc 587, dxy 587, zn 587, inr 588, ym 587, bz 587, stoxx 569, nq_night 575, ixic_night 569.
