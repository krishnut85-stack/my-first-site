# J5 - Monday's instrument file against Friday's (tool: v2/engine/tools/j5_instruments.py)

**Tool:** `python3 engine/tools/j5_instruments.py OLD.csv NEW.csv --day 2026-11-23 [--fetch NEW.csv]`. `--fetch` downloads Kite's public contract list; no login, no key. It reports:
- contracts by type;
- F&O names leaving / joining;
- the expiries with days to expiry;
- the next stock series' lot changes against the old file and against the current series;
- the plan-card lot (the next series' option lot).

**Engine side:**
- The plan uses the chosen contract's own lot from the option quote rows (gir-v2opt reads the same instrument master). The card says "lot N from the 2026-12-29 contract <sym>".
- Without that, it falls back to the share's listed lot and says so.
- Test: B9StaleOptionQuote.test_plan_lot_is_the_contracts_own.

## Dry run 1 - Thu 19 Nov file vs Fri 20 Nov file (20 Nov, before the close)
```
J5 instrument check - old /home/globalbot/intraday/v2/data/instr/NFO_2026-11-19.csv · new /home/globalbot/intraday/v2/data/instr/NFO_2026-11-20.csv · day 2026-11-23
contracts by type: old {'FUT': 667, 'CE': 22415, 'PE': 22632} · new {'FUT': 667, 'CE': 21943, 'PE': 22175}
F&O names: old 224 · new 224 · leaving 0 [] · joining 0 []
expiries in the new file (days to expiry from 2026-11-23): 2026-11-23 (0 d), 2026-12-01 (8 d), 2026-12-08 (15 d), 2026-12-15 (22 d), 2026-12-22 (29 d), 2026-12-29 (36 d), 2027-01-25 (63 d), 2027-03-30 (127 d), 2027-06-29 (218 d), 2027-09-28 (309 d), 2027-12-28 (400 d), 2028-06-27 (582 d)
the next stock series: 2026-12 · its lot changed vs the old file: 0 []
its lot differs from the current series: 0 []
plan-card lot = the next series' option lot, e.g. 360ONE 500, ABB 125, ABCAPITAL 1550, ADANIENSOL 675, ADANIENT 309, ADANIGREEN 600, ADANIPORTS 475, ADANIPOWER 3550, ALKEM 125, AMBER 100, AMBUJACEM 1200, ANANDRATHI 250
```
Reading:
- No share leaves or joins.
- The December option lots equal November for all 224 names, and none changed between the two files. 35 names change lot in January (e.g. APOLLOHOSP 125 -> 75, CHOLAFIN 625 -> 300).
- Days to expiry from Mon 23 Nov: November 0 (expiry day), NIFTY weekly 1 Dec 8, December monthly 29 Dec 36.

## Saturday dry run - Friday's file vs a fresh download
To do on Sat 21 Nov (outside market hours): `--fetch girdata/review/monday/instr/NFO_2026-11-21.csv` against v2/data/instr/NFO_2026-11-20.csv. Results are appended here.

## Monday 08:15 live check
Run on Monday's 08:00 file (v2/data/instr/NFO_2026-11-23.csv, written by gir-v2opt at its first pass) against Friday's. The plan-card lots must equal the file's December lot. Results are appended here.
