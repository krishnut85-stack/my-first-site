# GAP PREDICT - GIFT NIFTY night close vs the Nasdaq-futures line vs the real 09:15 open (lesson rows, NOT PROVEN)

Companion to gap_predict_study.md (that file is rewritten by kb/gap_predict_study.py, so the scored rows live here).
Order: DESK_REVIEW 21 Nov 23:30 (GIFT NIFTY FACT, order 3). Rows are appended by v2/sources/p_drivers.py (gir-v2sources) at 09:20 IST
on each session after a night session: GIFT NIFTY's last night print before 06:30 (NSE IX near-month NIFTY future), the NQ line
(Nasdaq futures % since India's last 15:30 close, last seen before 07:30), NIFTY's real 09:15 open (NSE IX nifty-market-rate).
Rule under test: when GIFT traded after the US close it is the direct market price and outranks the NQ history line.

## Pending - Mon 23 Nov 2026 (set up Sat 21 Nov)
- GIFT NIFTY night close 25,836 (NSE IX, NIFTY FUT 23 Nov 2026, last print Sat 21 Nov 02:44:57 IST) = +35.4 pts / +0.14% vs NIFTY's
  Fri close 25,800.6 -> GIFT says FLAT (inside +-0.3%). Cross-check: the trader's broker app (CFD) 25,836 at Sat 02:30 IST.
- NQ line: Nasdaq futures -3.96% since India's close (25,126.5 at the Sat 03:25 IST futures close vs 26,161.25 at Fri 15:30) -> gap DOWN
  (the line's history: 80%, 148 cases). Signals DISAGREE; GIFT traded after the US close (Sat 02:30 IST), so GIFT outranks.
- Monday's NQ value at 07:15 will be recorded too (CME reopens Mon 04:30 IST).
