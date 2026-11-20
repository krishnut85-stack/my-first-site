# MONTHLY F&O PLAN - holding options into the monthly expiry (2-6 weeks) - desk draft, 20 Nov 2026, NOT YET PROVEN

The trader, 20 Nov: "For the F&O shares, how about a longer holding - targeting the monthly expiry? How to invest? Does the desk have
a strategy?" Two desk experts answered: the options specialist (the plan) and the quant (the study that must prove it first).
GIR never places orders; he decides and trades in Kite. December series: expiry Tue 29 Dec 2026 - exit / roll by Tue 22 Dec.

## A. The plan (options specialist)
1. When: a clear trend in a leading sector, IV normal / low, no results inside the hold (Q3 results start mid-January), no ex-date
   inside the hold for calls, never an EXTREME-overbought share. Never hold stock options into expiry week (physical delivery).
2. What: ATM or 1-2 ITM (delta ~0.6-0.7), no cheap OTM; December now, January for entries after ~15 Dec; DEBIT SPREADS to cut time
   decay. Illustrative: M&M at 3,000 - buy Dec 3,000 CE 120, sell Dec 3,150 CE 55, net 65: max loss 65, max profit 85, breakeven
   3,065 (a naked 3,000 CE breaks even ~3,120 at expiry). Multiply by the lot shown in Kite.
3. Which: top 3 sectors by 1-month relative strength; CE = rollover above the share's own average + long build-up in the first 3
   days of the series, entered on a pullback to the 20-day average; PE = relative weakness in lagging sectors + short build-up.
   Check results / ex-dates first.
4. Rules: entry when the share closes back above the previous day's high after a pullback; stop on the share below the pullback low
   (daily close); target the prior swing high or ~75% of the spread's maximum; time stop 7-8 trading days; risk <= 1% of capital
   per trade; <= 3 open positions, never two in one sector. Today's backdrop (NIFTY +14.8% from 8 Oct, FIIs buying, RBI hiking):
   smaller size, keep one PE idea.
5. GIR adds: a SERIES PLAN card on the first trading day of each series (sector ranks, rollover, early build-up, CE / PE watch list,
   results / ex-dates, exit date) and a weekly review of each open position (stop, target, time stop).

## B. The proof first - seriesstudy.py (quant design; to be built and run on the 3-year store)
- Calendar from onsetstudy.expiry_flags (last Thursday to Aug 2025, last Tuesday from Sep 2025, holiday = the day before), checked
  against fo_daily OI drops; ~36 series; exit at the close of expiry-week Monday; nothing held into expiry week.
- Signals at the close of day 1 / 2 / 3 of a series, CE and PE mirrored: build-up (price x OI sign), rollover proxy terciles, the
  sector's previous-series rank and breadth, RSI regime (EXTREME / normal / oversold), distance from the 20 / 50-day averages,
  NIFTY vs its 50-day average; each alone, pairs, triples (count of sets tried is reported).
- Outcome: share move to exit, max adverse move, option proxy (0.5 x move - sqrt(t) decay of an ATM premium from 20-day realised
  vol), debit-spread proxy (capped +80%, floored -100%). Survivorship warning (today's 218 shares).
- Baselines: all shares same side and day, top sector only, random matched picks (10,000 draws); tuning vs held-out last 6 months;
  bootstrap by month. PASS = lift interval above 1.0, holds in held-out and in 5 of 6 half-years, >= 2 trades a month; CE and PE
  judged separately. Section 0 in plain words: the set that beats random (or "none does"), trades a month, hit rate, median move,
  median spread result, worst trade and worst month.
- UNTIL MEASURED, DO NOT: buy naked monthly CE / PE on build-up, rollover or sector calls; hold into expiry week; treat EXTREME RSI
  as a PE trigger or oversold as a CE trigger; size up or average down; trust one day's OI label. The proxy cannot see IV changes,
  so even a pass is optimistic.
