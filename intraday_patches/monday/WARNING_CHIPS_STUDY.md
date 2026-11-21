# WARNING CHIPS STUDY - opening trap, VWAP cross quality, low-volume drift, failed break (2026-11-21)

The trader (BLUESTARCO 19-20 Nov): "how to know it will fall at the open, then rise again with fewer buyers - can we get warnings?" Code only, $0, no AI. Script v2/kb/chips_study.py; the chip functions are the live desk's (analyst/chips.py).

## Verdict

- **TRAP: NOT PROVEN - stays 'information'** - unseen 2026 n 73, difference -1.82 option-return points (the warning's direction > 0), Holm p 0.8995; tuning n 290, -0.71, p 0.6026.
- **VWAP: TESTED WARNING** - unseen 2026 n 31731, difference +0.34 option-return points (the warning's direction > 0), Holm p 0.0001; tuning n 64607, +0.46, p 0.0000.
- **DRIFT: TESTED WARNING** - unseen 2026 n 34430, difference +0.29 option-return points (the warning's direction > 0), Holm p 0.0004; tuning n 74159, +0.29, p 0.0000.
- **FAILED: NOT PROVEN - stays 'information'** - unseen 2026 n 50598, difference -0.04 option-return points (the warning's direction > 0), Holm p 0.8995; tuning n 116137, -0.29, p 0.0000.

Chips that pass are listed in v2/models/chips_passed.json; the live chip then says 'tested warning' instead of 'information'. Every chip stays a WARNING (never an entry on its own).

## Method

DATA: 3-year minute store (hist_fresh), 218 F&O shares, 2023-12-18 -> 2026-11-19. Own minute VWAP per share-day (resets at 09:15). RVOL baseline = the 20 previous sessions' mean volume of the same minute. OPTION PROXY (labelled): Black-Scholes ATM, IV = 20-day realised vol x 1.1, ~15 sessions to expiry, -30% premium stop, hold 60 min / 15:10, spread 1% paid twice, STT / exchange / GST (brokerage per lot left out). RANDOM = same share, same minute and side on 5 random days of the same period. TUNE Dec 2023 - Dec 2025, UNSEEN 2026; Holm over the 4 primary tests (fixed before the run, listed in the script header).

## TUNING 2023-25

**1 OPENING TRAP** (gap >= 2% after a >= 5% day, same direction) vs CONTROL (gap >= 2%, no big day before):

| group | n | faded by 09:30 | faded by 09:45 | first-30-min depth (median, gap side) | lost VWAP before 10:00 | of those, reclaimed by 11:00 | option: buy 09:16 | option: buy 09:45 | open-to-close (gap side) |
|---|---|---|---|---|---|---|---|---|---|
| trap | 290 | 61% | 58% | -0.37% | 92% | 89% | -4.73% | -5.43% | -1.48% |
| control | 3897 | 65% | 66% | -0.47% | 96% | 90% | -3.54% | -2.99% | -0.76% |

**2 VWAP CROSS quality** (first weak / strong cross per share-day and direction, 09:45-14:10; option bought in the cross direction):

| cross | n | option return mean | random same-minute | share of wins |
|---|---|---|---|---|
| weak (< 0.7x) | 117327 | -2.50% | -2.32% | 34% |
| strong (>= 1.5x) | 64607 | -2.03% | -2.37% | 36% |

**3 LOW-VOLUME DRIFT** vs buying the same side IN VOLUME (30-min RVOL >= 1.2), first per share-day, 10:15-14:10:

| state | n | option return mean | random same-minute | share of wins |
|---|---|---|---|---|
| drift (RVOL < 0.7, range shrinking) | 94170 | -2.25% | -2.33% | 35% |
| in volume | 74159 | -1.96% | -2.34% | 37% |

**4 FAILED BREAK** (new day high / low back inside within 2 five-min candles on falling volume):

| n | option: buy the BREAK side | random same-minute | option: buy the FADE side | 60-min move, break side | share of wins (break side) |
|---|---|---|---|---|---|
| 116137 | -1.97% | -2.26% | -2.54% | +0.02% | 38% |

## UNSEEN 2026

**1 OPENING TRAP** (gap >= 2% after a >= 5% day, same direction) vs CONTROL (gap >= 2%, no big day before):

| group | n | faded by 09:30 | faded by 09:45 | first-30-min depth (median, gap side) | lost VWAP before 10:00 | of those, reclaimed by 11:00 | option: buy 09:16 | option: buy 09:45 | open-to-close (gap side) |
|---|---|---|---|---|---|---|---|---|---|
| trap | 73 | 49% | 47% | -0.17% | 94% | 87% | +0.73% | -1.09% | +0.12% |
| control | 2307 | 57% | 57% | -0.20% | 95% | 88% | -2.06% | -1.07% | -0.20% |

**2 VWAP CROSS quality** (first weak / strong cross per share-day and direction, 09:45-14:10; option bought in the cross direction):

| cross | n | option return mean | random same-minute | share of wins |
|---|---|---|---|---|
| weak (< 0.7x) | 51259 | -2.42% | -2.36% | 34% |
| strong (>= 1.5x) | 31731 | -2.08% | -2.41% | 37% |

**3 LOW-VOLUME DRIFT** vs buying the same side IN VOLUME (30-min RVOL >= 1.2), first per share-day, 10:15-14:10:

| state | n | option return mean | random same-minute | share of wins |
|---|---|---|---|---|
| drift (RVOL < 0.7, range shrinking) | 41098 | -2.44% | -2.30% | 34% |
| in volume | 34430 | -2.15% | -2.39% | 37% |

**4 FAILED BREAK** (new day high / low back inside within 2 five-min candles on falling volume):

| n | option: buy the BREAK side | random same-minute | option: buy the FADE side | 60-min move, break side | share of wins (break side) |
|---|---|---|---|---|---|
| 50598 | -2.25% | -2.29% | -2.35% | +0.00% | 37% |

## BLUESTARCO 19-20 Nov (the trader's case)

- 2026-11-19: VWAP at 09:40 - VWAP lost 09:40 on 4.2x volume / Strong volume behind it
- 2026-11-19: VWAP at 09:45 - VWAP reclaimed 09:45 on 8.5x volume / Strong volume behind it
- 2026-11-19: FAILED at 09:55 - New day high at 09:50 failed / Back inside by 09:55, volume falling
- 2026-11-19: FAILED at 10:05 - New day high at 10:00 failed / Back inside by 10:05, volume falling
- 2026-11-19: FAILED at 11:35 - New day high at 11:30 failed / Back inside by 11:35, volume falling
- 2026-11-19: FAILED at 12:00 - New day high at 11:55 failed / Back inside by 12:00, volume falling
- 2026-11-19: FAILED at 12:10 - New day high at 12:05 failed / Back inside by 12:10, volume falling
- 2026-11-19: FAILED at 13:00 - New day high at 12:55 failed / Back inside by 13:00, volume falling
- 2026-11-19: FAILED at 13:20 - New day high at 13:15 failed / Back inside by 13:20, volume falling
- 2026-11-19: FAILED at 13:50 - New day high at 13:40 failed / Back inside by 13:50, volume falling
- 2026-11-19: FAILED at 14:10 - New day high at 14:05 failed / Back inside by 14:10, volume falling
- 2026-11-19: FAILED at 14:35 - New day high at 14:30 failed / Back inside by 14:35, volume falling
- 2026-11-19: yesterday +0.1%, gap +0.3%
- 2026-11-20: FAILED at 09:50 - New day low at 09:45 failed / Back inside by 09:50, volume falling
- 2026-11-20: VWAP at 10:10 - VWAP reclaimed 10:10 on 1.6x volume / Strong volume behind it
- 2026-11-20: VWAP at 10:20 - VWAP lost 10:20 on 1.7x volume / Strong volume behind it
- 2026-11-20: VWAP at 10:45 - VWAP reclaimed 10:45 on 1.1x volume
- 2026-11-20: VWAP at 10:55 - VWAP lost 10:55 on 0.5x volume / Weak - never an entry
- 2026-11-20: VWAP at 11:00 - VWAP reclaimed 11:00 on 3.9x volume / Strong volume behind it
- 2026-11-20: VWAP at 11:40 - VWAP lost 11:40 on 0.9x volume
- 2026-11-20: DRIFT at 12:05 - Below VWAP on thin volume / No conviction / Time decay eats option premium / Avoid buying options now
- 2026-11-20: DRIFT at 12:10 - Below VWAP on thin volume / No conviction / Time decay eats option premium / Avoid buying options now
- 2026-11-20: VWAP at 12:15 - VWAP reclaimed 12:15 on 0.5x volume / Weak - never an entry
- 2026-11-20: DRIFT at 12:15 - Below VWAP on thin volume / No conviction / Time decay eats option premium / Avoid buying options now
- 2026-11-20: VWAP at 12:30 - VWAP lost 12:30 on 0.3x volume / Weak - never an entry
- 2026-11-20: VWAP at 12:35 - VWAP reclaimed 12:35 on 0.1x volume / Weak - never an entry
- 2026-11-20: VWAP at 14:00 - VWAP lost 14:00 on 2.3x volume / Strong volume behind it
- 2026-11-20: VWAP at 14:15 - VWAP reclaimed 14:15 on 1.3x volume
- 2026-11-20: VWAP at 14:20 - VWAP lost 14:20 on 0.5x volume / Weak - never an entry
- 2026-11-20: VWAP at 14:25 - VWAP reclaimed 14:25 on 0.9x volume
- 2026-11-20: yesterday +9.6%, gap -0.7%

## Notes for the desk

- The opening-trap rule as written needs a gap >= 2%: BLUESTARCO on 20 Nov opened FLAT after +9.6% (minute closes), so the trap chip would NOT have shown - the failed new low (09:45-09:50) and the thin afternoon VWAP reclaims are the chips that fired. A wider 'after a >= 5% day, any open' variant is a trader decision (not built).
- PASS means the WARNING holds (a weak cross / a drift does worse than a strong cross / buying in volume). Every group still loses money on average on the option proxy after costs (about -2% a trade for a 60-min ATM buy) - a strong cross is NOT an entry signal; the live strong-cross chip stays 'information'.
- FAILED BREAK: in the tuning years buying the break side after a 'failed' break did BETTER than random (-1.97% vs -2.26%) - the chip's warning is not supported; it stays 'information'.
- Option proxy only (no recorded stock-option minutes for 3 years); 1% spread each way is a guess for liquid F&O names - wider on thin ones.
- Share page: the session VWAP resets at 09:15 each day - the jump at the day boundary is the reset, not a signal (a note under the chart).
