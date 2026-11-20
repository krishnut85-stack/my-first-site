# TRADER'S READS - scored (server, Fri 20 Nov 2026 after the close)

Source list: design_v3/TRADER_CALLS.md (33 rows) + his 20 Nov 07:45 reads + his 19 Nov 14:44 call. Ideas only, never orders.

## Hit rate - CE (expected up) and PE (expected down) kept apart

| | CE (up) | PE (down) |
|---|---|---|
| **Right side, main horizon** (the day's close from the time he said it; for #25 and #33 the next close, the day he named) | 10/14 = 71% | 7/18 = 39% |
| Right side, to that day's close | 10/14 = 71% | 7/18 = 39% |
| Right side, to the next day's close | 7/12 = 58% | 11/18 = 61% |
| Beat NIFTY in his direction, main horizon | 7/14 = 50% | 10/18 = 56% |
| Beat NIFTY, to that day's close | 8/14 = 57% | 8/18 = 44% |
| Beat NIFTY, to the next day's close | 6/12 = 50% | 13/18 = 72% |
| Main horizon, past reads only (before 20 Nov) | 8/12 = 67% | 7/18 = 39% |

n = scored reads with a direction. Not counted: no direction (#3, #22, #26), conditional with no clean trigger (#21), too vague (#1). A sector / group read counts once, on the median of its F&O members (R49 basis); breadth is shown beside it. The 20 Nov reads have no next-day close yet (Mon 23 Nov) - those cells are '-' and the n is smaller.

## The scored table

Move % = from the price when he said it (in market hours: that minute's price; before the open or on a holiday / weekend: the next session's open) to that day's official close, and to the next session's close. 'alt' = the same move from the previous close (gap included). vs NIFTY = move minus NIFTY over the same window; vs sector = move minus the median of the share's sector F&O members (sectors.json). Right = the move is on his side (CE up, PE down).

| # | Said (IST) | Read | CE/PE | From | Move to day close | Move to next close | alt (from prev close) day / next | NIFTY day / next | vs NIFTY day / next | Sector | vs sector day / next | Right? day / next | Counted | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | Sun 8 Nov 07:35 | DIVISLAB | CE | 11-08 open | +2.28 | +6.59 | +7.52 / +12.06 | -0.34 / -0.10 | +2.62 / +6.69 | pharma | +2.32 / +4.67 | yes / yes | yes | First tradable price after 07:35 = the 8 Nov Muhurat session open (14:20); next day = Mon 9 Nov. |
| 3 | Sun 8 Nov 20:45 / Mon 9 Nov 10:38 | DATAPATTNS | - | 11-09 10:38 | +2.10 | +2.78 | +9.97 / +10.71 | +0.54 / +1.39 | +1.56 / +1.39 | capital-goods | +1.37 / +0.59 | no direction | no | 'Keep a close watch' on the board meeting: no direction given - move shown, not counted. |
| 4 | Mon 9 Nov 08:46 | EICHERMOT | CE | 11-09 open | -0.29 | -0.77 | -0.29 / -0.77 | -0.13 / +0.71 | -0.16 / -1.48 | auto | -0.09 / -2.00 | no / no | yes | Pre-open: from the 9 Nov open (alt: from the 8 Nov Muhurat close). |
| 5 | Mon 9 Nov 11:18 | COCHINSHIP | CE | 11-09 11:18 | +2.72 | -4.28 | +3.91 / -3.18 | +0.60 / +1.45 | +2.12 / -5.73 | capital-goods | +2.25 / -6.42 | yes / no | yes |  |
| 6 | Mon 9 Nov 22:46 | GLENMARK | PE | 11-11 open | +0.27 | -0.38 | +0.23 / -0.42 | -0.33 / -0.15 | +0.60 / -0.23 | pharma | +1.19 / +1.24 | no / yes | yes | Warning 'overbought - no CE' scored as the PE side (right = it did not rise). 10 Nov was an NSE holiday, so from the 11 Nov open. |
| 7 | Tue 10 Nov 14:50 | COCHINSHIP | PE | 11-11 open | +0.17 | -0.33 | -6.82 / -7.29 | -0.33 / -0.15 | +0.50 / -0.18 | capital-goods | -0.31 / -1.05 | no / yes | yes | 10 Nov was an NSE holiday (Diwali-Balipratipada): first tradable price = 11 Nov open; alt = from the 9 Nov close (before the results). Level <= 1180: first reached 2026-11-13. |
| 8 | Wed 11 Nov 09:40 | SWIGGY | CE | 11-11 09:40 | -3.53 | -1.92 | -1.28 / +0.37 | -0.56 / -0.38 | -2.97 / -1.54 | consumer | -3.15 / -1.73 | no / no | yes |  |
| 9 | Thu 12 Nov 09:41 | DATAPATTNS | CE | 11-12 09:41 | +0.22 | +1.10 | +3.96 / +4.86 | -0.20 / -0.81 | +0.42 / +1.91 | capital-goods | +0.91 / +2.04 | yes / yes | yes | Floor 4,200: lowest price after 09:41 shown. Floor 4,200 broken on 2026-11-12. |
| 10 | Thu 12 Nov 14:32 | POLICYBZR | CE | 11-12 14:32 | +1.99 | +7.32 | +7.26 / +12.87 | +0.24 / -0.37 | +1.75 / +7.69 | consumer | +1.84 / +7.50 | yes / yes | yes |  |
| 11 | Fri 13 Nov 06:37 (again 15:24, 16:38) | POLICYBZR | CE | 11-13 open | +6.21 | +3.92 | +5.23 / +2.96 | -0.26 / +0.32 | +6.47 / +3.60 | consumer | +6.54 / +3.91 | yes / yes | yes | First words 06:37 on 13 Nov, so from the 13 Nov open; next day = Mon 16 Nov, the day he named. |
| 12 | Fri 13 Nov 11:48 | NMDC | PE | 11-13 11:48 | +0.61 | -0.66 | -0.09 / -1.35 | -0.03 / +0.56 | +0.64 / -1.22 | metals | +0.45 / +0.95 | no / yes | yes |  Level <= 65: not reached by 20 Nov. |
| 13 | Fri 13 Nov 12:33 | POWERINDIA | CE | 11-13 12:33 | -1.45 | -3.67 | +5.35 / +2.98 | +0.13 / +0.71 | -1.58 / -4.38 | capital-goods | -0.92 / -2.25 | no / no | yes |  Level >= 33000: not reached by 20 Nov. |
| 14 | Fri 13 Nov 13:00 | HINDALCO | PE | 11-13 13:00 | -0.37 | -2.51 | -1.09 / -3.22 | +0.13 / +0.71 | -0.50 / -3.22 | metals | -0.39 / -0.58 | yes / yes | yes |  |
| 15 | Fri 13 Nov 13:04-13:51 | RVNL | CE | 11-13 trigger 200.0 at 14:40 | -0.27 | -2.82 | -2.89 / -5.37 | +0.13 / +0.71 | -0.40 / -3.53 | capital-goods | -0.37 / -1.89 | no / no | yes | Conditional: CE only above 200. Counted only if 200 traded after 13:51 (checked to 20 Nov). 200 traded on 2026-11-13 (trigger 200.0 at 14:40); scored from 200. Range after, to 20 Nov: 187.23-200.14. |
| 16 | Sat 14 Nov 22:57 | PATANJALI | PE | 11-16 open | -5.72 | -4.75 | -4.82 / -3.85 | +0.34 / +0.72 | -6.06 / -5.47 | fmcg | -6.40 / -5.70 | yes / yes | yes | His condition (NIFTY down, money pulled out) not modelled: scored from the 16 Nov open. |
| 17 | Sat 14 Nov 17:46 | POLICYBZR | PE | 11-16 open | -3.46 | -6.05 | -2.15 / -4.79 | +0.34 / +0.72 | -3.80 / -6.77 | consumer | -4.17 / -6.27 | yes / yes | yes | 'Resistance at 1,100' scored as the PE side (no CE) from the 16 Nov open; 1,100 check on the close. Closed below 1,100 on 16 Nov: yes. |
| 18 | Sun 15 Nov 10:28 | TMPV | PE | 11-16 open | -3.56 | -4.74 | -8.70 / -9.81 | +0.34 / +0.72 | -3.90 / -5.46 | auto | -2.50 / -4.01 | yes / yes | yes |  |
| 19 | Sun 15 Nov 11:06 | RELIANCE | PE | 11-16 open | +0.38 | +2.04 | +0.38 / +2.04 | +0.34 / +0.72 | +0.04 / +1.32 | oil-gas | -0.03 / +1.22 | no / no | yes |  Level <= 1320: not reached by 20 Nov. |
| 20 | Mon 16 Nov 09:47 | KAYNES | CE | 11-16 09:47 | +5.32 | +1.01 | -3.47 / -7.42 | -0.11 / +0.28 | +5.43 / +0.73 | capital-goods | +5.76 / +2.36 | yes / yes | yes |  |
| 21 | Mon 16 Nov 21:47 | ABB | CE | 11-17 open | -0.03 | -1.07 | +0.41 / -0.64 | +0.44 / -0.20 | -0.47 / -0.87 | capital-goods | +0.46 / +1.04 | no / no | no | Conditional on capital goods turning up - not counted; ABB and the capital-goods median shown. Capital-goods median / ABB day %: 11-17 -0.57 / +0.41; 11-18 -1.24 / -1.04; 11-19 +1.88 / +1.46; 11-20 -0.16 / +0.01. |
| 22 | Tue 17 Nov 00:47 | IT (FII buying) | - | 11-17 open | -0.77 | -1.82 | -0.96 / -2.08 | +0.44 / -0.20 | -1.21 / -1.62 | (the basket is the sector) | - / - | no direction | no | A flow statement; he said it is not a CE / PE reason by itself - shown, not counted. |
| 22 | Tue 17 Nov 00:47 | Oil & gas (FII selling) | - | 11-17 open | -0.01 | -0.35 | +0.40 / -0.14 | +0.44 / -0.20 | -0.45 / -0.15 | (the basket is the sector) | - / - | no direction | no | As R22a - shown, not counted. |
| 23 | Tue 17 Nov 07:36 | Steel (TATASTEEL, JSWSTEEL) (n=2; on his side: 0/2 day, 2/2 next) | PE | 11-17 open | +0.59 | -0.71 | -0.30 / -1.59 | +0.44 / -0.20 | +0.15 / -0.51 | metals (without the basket) | -0.53 / +1.84 | no / yes | yes |  |
| 24 | Tue 17 Nov 09:05 | Private banks (F&O) (n=14; on his side: 2/14 day, 7/14 next) | PE | 11-17 open | +0.99 | -0.02 | +1.02 / -0.08 | +0.44 / -0.20 | +0.55 / +0.18 | banks (without the basket) | -0.66 / -2.29 | no / yes | yes |  |
| 25 | Tue 17 Nov 12:15 | ADANIENSOL | CE | 11-17 12:15 | +1.38 | +1.13 | +2.87 / +2.62 | -0.44 / -1.06 | +1.82 / +2.19 | power | +1.28 / +1.66 | yes / yes | yes | He asked about 18 Nov: the next-day close (18 Nov) is the main horizon. |
| 26 | Tue 17 Nov 12:16 | HEROMOTOCO | - | 11-17 12:16 | -0.41 | -1.83 | -0.54 / -1.96 | -0.43 / -1.06 | +0.02 / -0.77 | auto | +0.00 / +0.20 | no direction | no | Watch (OI up, price flat): no direction - shown, not counted. |
| 27 | Tue 17 Nov 12:30 | ANGELONE | PE | 11-17 12:30 | -4.80 | -7.93 | +0.45 / -2.86 | -0.39 / -1.02 | -4.41 / -6.91 | capital-mkts | -3.32 / -4.74 | yes / yes | yes | Said after the fall had started ('fell from 8 to 1 percent'). |
| 28 | Wed 18 Nov 08:13 | MANAPPURAM | PE | 11-18 open | -2.92 | -2.97 | -4.59 / -4.64 | -0.38 / +0.75 | -2.54 / -3.72 | nbfc | -1.77 / -3.12 | yes / yes | yes |  |
| 29 | Wed 18 Nov 12:20 (his trade was earlier, time not known) | TITAN | PE | 11-18 12:20 | -0.76 | +0.34 | -4.77 / -3.71 | -0.07 / +1.06 | -0.69 / -0.72 | consumer | -0.33 / -0.48 | yes / no | yes | Scored from 12:20, the time of his message; alt = from the open (his trade time is unknown). |
| 30 | Wed 18 Nov 12:20 | KALYANKJIL | PE | 11-18 12:20 | +0.42 | +2.12 | -4.80 / -3.19 | -0.07 / +1.06 | +0.49 / +1.06 | consumer | +0.85 / +1.30 | no / no | yes | Said after the share had already crossed -3% (11:40). |
| 31 | Thu 19 Nov 09:13 | UNITDSPR | PE | 11-19 open | +4.78 | +5.35 | +1.32 / +1.87 | +1.30 / +2.44 | +3.48 / +2.91 | fmcg | +3.06 / +2.94 | no / no | yes |  |
| 32 | Thu 19 Nov 12:52 | Banks (F&O) (n=22; on his side: 5/22 day, 2/22 next) | PE | 11-19 12:52 | +0.46 | +2.20 | +1.52 / +3.69 | +0.57 / +1.70 | -0.11 / +0.50 | (the basket is the sector) | - / - | no / no | yes | Asked as a question ('correct? I don't understand'); counted, as in the desk's table. |
| 33 | Thu 19 Nov 14:44 | Auto (F&O) (n=11; on his side: 1/11 day, 3/11 next) | PE | 11-19 14:44 | +0.67 | +0.74 | - | +0.18 / +1.30 | +0.49 / -0.56 | (the basket is the sector) | - / - | no / no | yes | He meant 20 Nov: the 20 Nov close (next-day column) is the one that counts for this read. |
| 33 | Thu 19 Nov 14:44 | Consumer durables / ACs (F&O) (n=9; on his side: 2/9 day, 2/9 next) | PE | 11-19 14:44 | +0.51 | +0.40 | - | +0.18 / +1.30 | +0.33 / -0.90 | consumer (without the basket) | +0.37 / -0.37 | no / no | yes | VOLTAS, BLUESTARCO, HAVELLS, CROMPTON, DIXON, AMBER, PGEL, TITAN, KALYANKJIL. Scored on the 20 Nov close. |
| 33 | Thu 19 Nov 14:44 | Metals 'come back' (F&O) (n=11; on his side: 8/11 day, 6/11 next) | CE | 11-19 14:44 | +0.28 | +0.23 | - | +0.18 / +1.30 | +0.10 / -1.07 | (the basket is the sector) | - / - | yes / yes | yes | 'It will again come back' - read as metals up after the 52-week low; implied, scored on the 20 Nov close. |
| 20N-a | Fri 20 Nov 07:45 | Defence F&O (8) (n=8; on his side: 5/8 day) | CE | 11-20 open | +0.23 | - | -0.09 / - | +1.71 / - | -1.48 / - | capital-goods (without the basket) | -0.67 / - | yes / - | yes | HAL, BEL, BDL, MAZDOCK, COCHINSHIP, SOLARINDS, DATAPATTNS, BHARATFORG (ASTRAMICRO is not F&O). Sector = capital goods without the 8. |
| 20N-b | Fri 20 Nov 07:45 | DIXON + EMS group (F&O) (n=5; on his side: 5/5 day) | CE | 11-20 open | +1.45 | - | +0.64 / - | +1.71 / - | -0.26 / - | each member vs its own sector median (without the group) | +0.91 / - | yes / - | yes | DIXON, KAYNES, PGEL, AMBER, SYRMA. |
| 20N-c | Fri 20 Nov 07:45 (photo) | AZAD | CE | 11-20 open | - | - | - / - | +1.71 / - | - / - | capital-goods | - / - | - / - | yes | AZAD (Azad Engineering, not F&O). NSE bulk deals of Wed 18 Nov: buyers Norges Bank (FII) 473,088 + ValueQuest funds 1,147,000 = 1,620,088 shares at 2,286 (the headline's 2.51% fits an equity of ~6.45 crore shares; share count not checked here); the promoter sold 3,500,000. Thu 19 Nov close 2,410.2, +3.94% (the 'jumps 4%'). Thursday's own NSE bulk / block files (19 Nov) hold no aerospace / defence share. |

## Pending
- **AZAD (20N-c)**: not F&O, so it is not in the 20 Nov minute fetch (463 F&O instruments) or the Kite daily top-up, and the NSE bhavcopy for 20 Nov was not yet posted (404 at 15:56 IST). Its row fills when the 20 Nov bhavcopy is read. Its 19 Nov jump is verified: 2,318.9 -> 2,410.2 (+3.94%).
- **Next-day column of the 20 Nov reads**: Mon 23 Nov close.

## Not scored
- **#1 (Sat 7 Nov 16:32, LTCG cut for FIIs, NIFTY ~300 points up 'a few days back')**: too vague to score - no day is named, and it is his account of a move that had already happened, not a forecast.

## Group members (the 20 Nov reads and #33)

**R33a** - Auto (F&O) from 2026-11-19 14:44

| Share | Entry | Move to day close | Move to next close |
|---|---|---|---|
| MARUTI | 13458.0 | +0.97 | +3.90 |
| M&M | 3500.6 | +0.24 | +1.37 |
| BAJAJ-AUTO | 10790.0 | +0.25 | -0.31 |
| HEROMOTOCO | 5519.0 | +0.67 | +0.02 |
| EICHERMOT | 8046.5 | +0.15 | +0.74 |
| TVSMOTOR | 4543.7 | +1.27 | +0.89 |
| ASHOKLEY | 167.2 | -0.63 | -2.21 |
| TMPV | 261.65 | +0.71 | +1.78 |
| ATHERENERG | 1909.0 | +0.83 | +1.36 |
| FORCEMOT | 20318.0 | +0.62 | -0.21 |
| HYUNDAI | 2204.0 | +0.69 | +0.38 |

**R33b** - Consumer durables / ACs (F&O) from 2026-11-19 14:44

| Share | Entry | Move to day close | Move to next close |
|---|---|---|---|
| VOLTAS | 1230.1 | +0.56 | +0.40 |
| BLUESTARCO | 1766.8 | -0.16 | +1.36 |
| HAVELLS | 1196.8 | +0.33 | +0.43 |
| CROMPTON | 218.41 | +0.73 | +2.42 |
| DIXON | 13053.0 | +0.01 | +0.05 |
| AMBER | 6723.5 | -0.39 | +0.25 |
| PGEL | 575.3 | +0.51 | +2.21 |
| TITAN | 4662.4 | +0.81 | -1.07 |
| KALYANKJIL | 655.75 | +0.80 | -2.60 |

**R33c** - Metals 'come back' (F&O) from 2026-11-19 14:44

| Share | Entry | Move to day close | Move to next close |
|---|---|---|---|
| TATASTEEL | 181.06 | -0.09 | -1.80 |
| JSWSTEEL | 1326.1 | +0.81 | +0.27 |
| HINDALCO | 903.8 | +0.69 | +2.83 |
| VEDL | 243.3 | +0.16 | -2.77 |
| JINDALSTEL | 1111.4 | +0.28 | +1.13 |
| SAIL | 164.22 | +0.13 | +0.23 |
| NMDC | 67.94 | +0.38 | +0.94 |
| NATIONALUM | 303.1 | +1.29 | +0.36 |
| HINDZINC | 526.1 | +0.55 | -0.71 |
| APLAPOLLO | 2184.8 | -1.69 | -3.65 |
| COALINDIA | 392.8 | -0.33 | -0.73 |

**N1** - Defence F&O (8) from 2026-11-20 open

| Share | Entry | Move to day close | Move to next close |
|---|---|---|---|
| HAL | 4762.1 | +0.54 | - |
| BEL | 402.75 | -0.34 | - |
| BDL | 1030.4 | +0.40 | - |
| MAZDOCK | 1842.0 | +0.05 | - |
| COCHINSHIP | 1138.2 | -1.18 | - |
| SOLARINDS | 18800.0 | -0.46 | - |
| DATAPATTNS | 4120.0 | +2.33 | - |
| BHARATFORG | 1725.1 | +1.36 | - |

**N2** - DIXON + EMS group (F&O) from 2026-11-20 open

| Share | Entry | Move to day close | Move to next close | Own sector | Sector day |
|---|---|---|---|---|---|
| DIXON | 12940.0 | +0.93 | - | consumer | +0.75 |
| KAYNES | 2870.0 | +1.45 | - | capital-goods | +0.40 |
| PGEL | 569.9 | +3.18 | - | capital-goods | +0.40 |
| AMBER | 6630.0 | +1.66 | - | consumer | +0.75 |
| SYRMA | 1500.0 | +0.93 | - | auto-anc | +0.51 |

## Data
- Closes / opens: NSE CM bhavcopy (nsearchives, downloaded after 15:35) for 5-19 Nov; 20 Nov from kite-daily. Kite daily closes matched the bhavcopy on all 218 F&O shares checked for 19 Nov.
- Intraday prices at the time he spoke: girdata/minute/<day>/<SYM>__eq.npz (bar open of that minute); NIFTY from NIFTY_50__ix.npz and its daily file.
- Bulk deals: NSE bulk.csv / block.csv (19 Nov, downloaded today) and the desk's saved NSE bulk file for 18 Nov (intraday/data/instdeals/2026-11-18.json).
- 10 Nov was an NSE holiday (Diwali-Balipratipada); 8 Nov (Sunday) was the Muhurat session.
- Sector lists: /root/hist/sectors.json, F&O members only (F&O list of 19 Nov).
