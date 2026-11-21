# A6c - the EXTREME overbought rule (PREDICTION_LOOP; obscan 3 years, n=318: after daily RSI(14) >= 80, 81% corrected within 20 days, median -7.6%)

- Daily RSI(14) (Wilder) and the 20-day average come from girdata/history daily closes before the day (engine/daily.py).
- The desk's /root/hist/rallyscan.csv is a cross-check: its rsi14 is used when it is for the previous session, and the higher of the two counts.
- On 218 shares the two agree within 0.95 points on average; the worst is MARICO 76.5 vs 67.0 with the same last close (the scan probably uses an adjusted series).
- At or above 80 today: PNB (87.7 scan / 86.4 history), SBIN (82.9 / 81.5), MAHABANK (80.2 / 77.2).
- **Rules at RSI >= 80:**
  - no fresh CE GO NOW on a breakout, only a pullback entry ("a hold at VWAP / the 20-day average with volume");
  - a PE only on the turn: yesterday's low broken, below VWAP, volume, sector weakening (the card lists what is still missing).
- **Card and GO NOW check:** "EXTREME RSI nn - 81% corrected within 20 days (median -7.6%), n=318" (fields extreme_rsi, rsi_daily).

Tests:
    test_no_fresh_ce_breakout_on_extreme ... ok
    test_pe_only_on_the_turn ... ok
