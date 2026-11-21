# TREND DAY LINE - REPLAY OF 2026-11-20 through the live rule (analyst/trendday.py)

Recorded minutes girdata/minute/2026-11-20: futures (November contract, own volume -> VWAP), index, heavyweights' own VWAP. Cause from the RBI operations file at that minute (regs feed off in the replay). Send = WOULD SEND (replay); live it is sheet.emit: WOULD SEND until the ring test passes.

## 10:00 IST - BANKNIFTY CE (grade B, WOULD SEND (replay))

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

## 10:38 IST - NIFTY CE (grade B, WOULD SEND (replay))

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

## The rule at each check time

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
