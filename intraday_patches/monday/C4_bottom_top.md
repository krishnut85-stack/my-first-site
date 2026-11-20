# C4 - BOTTOM / TOP CALLS - proof

Code: `v2/predict/bottomtop.py`. Sources: TV speech-to-text calls (v2/tv tvcalls.jsonl), the reader's rows (TV, wires, live blogs, broker
notes). Phrase filter (bottom is in / worst is over / selling overdone / oversold / accumulate at these levels ... and the TOP mirror) +
the ALREADY falling / rising test (share -2% from the open or -5% over 5 days; sector -1.5% with 70% breadth; mirror for TOP). Otherwise it is
an ordinary TV / broker call. The card: "BOTTOM CALL by <voice> (<channel>, hh:mm, TV ONLY | VERIFIED) on X at ~p after -6% today - STOP: no
new PE here. [You hold X PE: protect / book half.] Price test till hh:mm: higher low · VWAP p · short covering · breadth. This voice: <record>".
Effects: GIR's own new calls on the threatened side suspended up to 45 min (the C2 monitor shows WAIT FOR THE TEST); a held position on the
threatened side gets the ring request (exit family); never a hard block on him; never a counter-side call by itself. Price test every minute:
CONFIRMED = VWAP reclaim + 2 more; REJECTED = 0.3% below the call low while below VWAP; else EXPIRED at 45 min. Futures OI by the minute and
option premium / IV are not in this lane's live feed -> those two tests say 'not known'. Each call is an episode (HELD = no new low beyond
0.3% and +1% within 60 min) for the voice's record (n < 3 'new voice, no record'; < 8 NOT PROVEN).
Replay test 5 (PAYTM 19 Nov bottom call on TV): NOT RUNNABLE - the 19 Nov market-hours TV transcripts in tv.db carry no PAYTM / bottom words
(the call was not captured by speech-to-text that day), and the reader did not exist before 19 Nov 19:13. Covered by the unit test instead.

## 2026-11-20 replay: 2 bottom / top items
- 10:44 ORDINARY APOLLOHOSP: BOTTOM view by Macquarie on APOLLOHOSP - not already falling, so an ordinary TV / broker call
- 12:12 ORDINARY hospitals & diagnostics: BOTTOM view by unnamed voice on hospitals & diagnostics - not already falling, so an ordinary TV / broker call

## 2026-11-16 replay: 0 bottom / top items

## 2026-11-18 replay: 0 bottom / top items

## 2026-11-19 replay: 0 bottom / top items

## 2026-10-29 replay: 0 bottom / top items

## 2026-10-27 replay: 0 bottom / top items

## Fri 20 Nov LIVE shadow run: 3 bottom / top items
- 10:43 ORDINARY APOLLOHOSP: BOTTOM view by Macquarie on APOLLOHOSP - not already falling, so an ordinary TV / broker call
- 12:11 ORDINARY hospitals & diagnostics: BOTTOM view by unnamed voice on hospitals & diagnostics - not already falling, so an ordinary TV / broker call
- 14:36 ORDINARY MAXHEALTH: BOTTOM view by unnamed voice on MAXHEALTH - not already falling, so an ordinary TV / broker call
