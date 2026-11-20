# C2 - THE PREDICTED TRADING-DAY SIGNAL - proof

Code: `v2/predict/monitor.py` (one state machine per 09:08 line, code only), run by `v2/predict/live.py` on live 1-minute bars and by
`v2/predict/replay.py` on the minute store. WAITING -> ARMED -> NEAR (silent) -> TRIGGERED -> CONFIRMED (ring request) -> DONE, or TOO LATE /
FAILED / STALE (09:45, grade one step down) / EXPIRED (14:30). CONFIRMED needs: the trigger crossed on a 1-minute close with RVOL >= 2 on its
side of VWAP; the whole-sector basket the same way >= 0.3% with breadth >= 60%; NIFTY not against by more than 0.2% (0.2-0.4% only for a LEADER);
grade MEDIUM+ on the scored list (WEAK / watch = NO_TRADE); inside the 5-minute FRESH window. Earliest = the close of the 09:16 bar (09:17:00);
09:17-09:30 only the 09:08 top 5 may ring (others confirmed silently); ring slots tiered A / B / C from the stored 09:08 scores, 6 per 15 min,
50 a day. TOO LATE = half the expected move done, or range used > 1.2 ATR, or 20 min (6 on a gap day) since the trigger. FAILED = a 1-minute
close past the final 09:08 cancel price -> "PREDICTION FAILED ... I was wrong on this one. No CE on it today." (silent unless he holds it).
Unpredicted F&O movers +-2% from the open with RVOL >= 2 are rows marked NOT PREDICTED (never a ring from this lane).
A BOTTOM / TOP call (C4) suspends a confirmation on the threatened side (silent card "WAIT FOR THE TEST").
What this lane does NOT do: E9 position / lock-room gates and the strike gate are the engine's (the card says so); no sound, no Telegram here -
a ring is a request marked on the row for the alert owner.

## Unit tests (synthetic bars, both sides mirrored)
```
test_classify (predict.tests.test_predict.BottomTop.test_classify) ... ok
test_not_falling_is_ordinary (predict.tests.test_predict.BottomTop.test_not_falling_is_ordinary) ... ok
test_rejected (predict.tests.test_predict.BottomTop.test_rejected) ... ok
test_stop_card_and_suspension (predict.tests.test_predict.BottomTop.test_stop_card_and_suspension) ... ok
test_bounce_needs_sector_not_falling (predict.tests.test_predict.Bounce.test_bounce_needs_sector_not_falling) ... ok
test_j3 (predict.tests.test_predict.Calendar.test_j3) ... ok
test_0917_0930_only_top5 (predict.tests.test_predict.Monitor.test_0917_0930_only_top5) ... ok
test_confirm_ce_at_0917_and_ring (predict.tests.test_predict.Monitor.test_confirm_ce_at_0917_and_ring) ... ok
test_failed (predict.tests.test_predict.Monitor.test_failed) ... ok
test_no_volume_no_trigger (predict.tests.test_predict.Monitor.test_no_volume_no_trigger) ... ok
test_not_predicted (predict.tests.test_predict.Monitor.test_not_predicted) ... ok
test_pe_mirror (predict.tests.test_predict.Monitor.test_pe_mirror) ... ok
test_ring_limit (predict.tests.test_predict.Monitor.test_ring_limit) ... ok
test_sector_against_is_silent (predict.tests.test_predict.Monitor.test_sector_against_is_silent) ... ok
test_too_late (predict.tests.test_predict.Monitor.test_too_late) ... ok
test_watch_line_never_rings (predict.tests.test_predict.Monitor.test_watch_line_never_rings) ... ok
test_fires_down_and_confirms (predict.tests.test_predict.Mover.test_fires_down_and_confirms) ... ok
test_sector_against_blocks_side (predict.tests.test_predict.Mover.test_sector_against_blocks_side) ... ok
test_filing_call_verified (predict.tests.test_predict.News.test_filing_call_verified) ... ok
test_junk_kei (predict.tests.test_predict.News.test_junk_kei) ... ok
test_market_disagrees (predict.tests.test_predict.News.test_market_disagrees) ... ok
test_merge_against_prediction (predict.tests.test_predict.News.test_merge_against_prediction) ... ok
test_price_confirm (predict.tests.test_predict.News.test_price_confirm) ... ok
test_repeat_silent (predict.tests.test_predict.News.test_repeat_silent) ... ok
test_tv_only_capped (predict.tests.test_predict.News.test_tv_only_capped) ... ok
test_extreme_ce_needs_pullback (predict.tests.test_predict.Rules20Nov.test_extreme_ce_needs_pullback) ... ok
test_thin_preopen (predict.tests.test_predict.Rules20Nov.test_thin_preopen) ... ok
test_labels (predict.tests.test_predict.Score.test_labels) ... ok

----------------------------------------------------------------------
Ran 28 tests in 0.023s

OK
```

## 2026-11-20 replay (point-in-time, minute store)
event counts: AGAINST PREDICTION 3, CONFIRMED 2, CROSS, NO VOLUME 1, EXPIRED 13, FAILED 4, GAP TOOK IT 2, LATE AFTER RING 2, MOVER EXPIRED 15, MOVER SIDE SET 10, NOT PREDICTED 36, RECLAIMED 3, SILENT CARD 4, STALE 3, TOO LATE 8, TRIGGERED 1
- 09:17 FAILED ✗ PREDICTION FAILED · KALYANKJIL - I predicted UP; it is -1.4%, below the cancel 643.71 · CONSUMER DURABLES +0.6% · I was wrong on this one. No CE on it today.
- 09:18 RECLAIMED TMPV back across yesterday's close 263.50 its way - trigger live
- 09:18 TRIGGERED TMPV trigger 263.50 crossed with volume 2.6x
- 09:18 SILENT CARD PREDICTED last evening: TMPV UP · sector AUTO up +0.1% (breadth 13/17) · NIFTY +0.3% · trigger 263.50 crossed 09:18 with volume 2.6x · move left ~59% of usual · FRESH till 09:23 · not a GO NOW: sector not with it (grade C) - silent
- 09:18 GAP TOOK IT MUTHOOTFIN GAP TOOK 3.8% - trigger becomes the first-3-minute low 2480.00, GAP-HOLD below 2553.80
- 09:18 GAP TOOK IT MANAPPURAM GAP TOOK 3.5% - trigger becomes the first-3-minute low 270.50, GAP-HOLD below 276.10
- 09:18 MOVER SIDE SET ◆ MOVER CROMPTON fired UP: above 220.00 with volume 3.9x · sector CONSUMER DURABLES +0.6% · the PE trigger is cancelled · NOT PROVEN
- 09:18 TOO LATE ◐ TOO LATE · CROMPTON +1.7% of the usual ~2.8% done - pullback only: VWAP 218.88 / first higher low, 1 lot
- 09:19 RECLAIMED WAAREEENER back across yesterday's close 2433.00 its way - trigger live
- 09:19 TOO LATE ◐ TOO LATE · TMPV +1.6% of the usual ~2.6% done - pullback only: VWAP 263.51 / first higher low, 1 lot
- 09:19 FAILED ✗ PREDICTION FAILED · MANAPPURAM - I predicted DOWN; it is +1.0%, above the cancel 275.18 · NBFC & FINANCE +0.4% · I was wrong on this one. No PE on it today.
- 09:20 FAILED ✗ PREDICTION FAILED · PIIND - I predicted UP; it is -0.8%, below the cancel 1616.96 · CHEMICALS +0.2% · I was wrong on this one. No CE on it today.
- 09:31 FAILED ✗ PREDICTION FAILED · MUTHOOTFIN - I predicted DOWN; it is +0.9%, above the cancel 2539.15 · NBFC & FINANCE +0.1% · I was wrong on this one. No PE on it today.
- 09:31 MOVER SIDE SET ◆ MOVER VOLTAS fired UP: above 1243.32 with volume 4.2x · sector CONSUMER DURABLES +0.2% · the PE trigger is cancelled · NOT PROVEN
- 09:31 SILENT CARD MOVER (side open, set by price): VOLTAS UP · sector CONSUMER DURABLES up +0.2% (breadth 5/7) · NIFTY +0.3% · trigger 1243.32 crossed 09:31 with volume 4.2x · move left ~65% of usual · FRESH till 09:36 · not a GO NOW: sector not with it (gra
- 09:31 MOVER SIDE SET ◆ MOVER MARUTI fired UP: above 13687.37 with volume 4.2x · sector AUTO +0.0% · the PE trigger is cancelled · NOT PROVEN
- 09:31 TOO LATE ◐ TOO LATE · MARUTI +1.5% of the usual ~2.6% done - pullback only: VWAP 13687.37 / first higher low, 1 lot
- 09:32 MOVER SIDE SET ◆ MOVER BANKBARODA fired UP: above 284.43 with volume 2.2x · sector BANKS +0.0% · the PE trigger is cancelled · NOT PROVEN
- 09:32 SILENT CARD MOVER (side open, set by price): BANKBARODA UP · sector BANKS up +0.0% (breadth 8/22) · NIFTY +0.3% · trigger 284.43 crossed 09:32 with volume 2.2x · move left ~55% of usual · FRESH till 09:37 · not a GO NOW: sector not with it (grade C) - 
- 09:33 TOO LATE ◐ TOO LATE · BANKBARODA +1.4% of the usual ~2.4% done - pullback only: VWAP 284.44 / first higher low, 1 lot
- 09:37 SILENT CARD MOVER (side open, set by price): VOLTAS UP · sector CONSUMER DURABLES up +0.1% (breadth 5/7) · NIFTY +0.4% · trigger 1243.32 crossed 09:31 with volume 4.3x · move left ~67% of usual · FRESH till 09:36 · not a GO NOW: sector not with it (gra
- 09:43 MOVER SIDE SET ◆ MOVER IREDA fired UP: above 130.50 with volume 12.1x · sector NBFC & FINANCE +0.4% · the PE trigger is cancelled · NOT PROVEN
- 09:43 TOO LATE ◐ TOO LATE · IREDA +2.0% of the usual ~3.4% done - pullback only: VWAP 130.50 / first higher low, 1 lot
- 09:46 STALE WAAREEENER not triggered by 09:45 - grade down to WEAK
- 09:46 STALE ALKEM not triggered by 09:45 - grade down to WEAK
- NOT PREDICTED rows: 39 - first 10: 09:17 GVT&D PE; 09:20 APLAPOLLO PE; 09:20 JSWSTEEL PE; 09:20 TATASTEEL PE; 09:22 COFORGE CE; 09:23 INDUSINDBK CE; 09:24 LTM CE; 09:24 MPHASIS CE; 09:25 ANGELONE CE; 09:26 APOLLOHOSP CE

## 2026-11-16 replay (point-in-time, minute store)
event counts: CONFIRMED 2, EXPIRED 4, FAILED 2, LATE AFTER RING 2, MOVER EXPIRED 20, MOVER SIDE SET 5, NOT PREDICTED 18, TOO LATE 3
- 09:18 MOVER SIDE SET ◆ MOVER MANAPPURAM fired DOWN: below 304.65 with volume 3.2x · sector NBFC & FINANCE -0.7% · the CE trigger is cancelled · NOT PROVEN
- 09:18 CONFIRMED ✓ MOVER (side open, set by price): MANAPPURAM DOWN · sector NBFC & FINANCE down -0.7% (breadth 43/52) · NIFTY +0.1% · trigger 304.65 crossed 09:18 with volume 3.2x · move left ~62% of usual · FRESH till 09:23 · grade B · MOVER · silent: 09:
- 09:18 MOVER SIDE SET ◆ MOVER COCHINSHIP fired DOWN: below 1176.00 with volume 3.2x · sector CAPITAL GOODS -1.5% · the CE trigger is cancelled · NOT PROVEN
- 09:18 CONFIRMED ✓ MOVER (side open, set by price): COCHINSHIP DOWN · sector CAPITAL GOODS down -1.5% (breadth 107/112) · NIFTY +0.1% · trigger 1176.00 crossed 09:18 with volume 3.2x · move left ~55% of usual · FRESH till 09:23 · grade B · MOVER · silent: 0
- 09:18 FAILED ✗ PREDICTION FAILED · PIIND - I predicted UP; it is -0.8%, below the cancel 1702.50 · CHEMICALS -0.8% · I was wrong on this one. No CE on it today.
- 09:25 LATE AFTER RING COCHINSHIP half the move done - no new entry; manage only
- 09:26 MOVER SIDE SET ◆ MOVER ABB fired DOWN: below 6922.00 with volume 6.8x · sector CAPITAL GOODS -1.5% · the CE trigger is cancelled · NOT PROVEN
- 09:26 TOO LATE ◐ TOO LATE · ABB -3.0% of the usual ~2.7% done - pullback only: VWAP 6954.31 / first lower high, 1 lot
- 09:37 LATE AFTER RING MANAPPURAM half the move done - no new entry; manage only
- 10:41 MOVER SIDE SET ◆ MOVER CUMMINSIND fired DOWN: below 4240.00 with volume 2.5x · sector CAPITAL GOODS -1.7% · the CE trigger is cancelled · NOT PROVEN
- 10:41 TOO LATE ◐ TOO LATE · CUMMINSIND -3.8% of the usual ~3.0% done - pullback only: VWAP 4288.14 / first lower high, 1 lot
- 10:41 MOVER SIDE SET ◆ MOVER ASHOKLEY fired DOWN: below 169.06 with volume 2.4x · sector AUTO -0.4% · the CE trigger is cancelled · NOT PROVEN
- 10:41 TOO LATE ◐ TOO LATE · ASHOKLEY -1.6% of the usual ~2.9% done - pullback only: VWAP 170.07 / first lower high, 1 lot
- 11:01 MOVER EXPIRED ◆ MOVER AMBER - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER ENRIN - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER GVT&D - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER ANGELONE - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER BDL - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER KALYANKJIL - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER POWERINDIA - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER POLICYBZR - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER COROMANDEL - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER ALKEM - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER DATAPATTNS - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER PAGEIND - neither trigger fired by 11:00
- NOT PREDICTED rows: 18 - first 10: 09:17 INOXWIND PE; 09:17 TMPV PE; 09:23 PATANJALI PE; 09:25 KAYNES PE; 09:28 OIL PE; 09:30 WAAREEENER PE; 09:31 MAXHEALTH CE; 09:48 MANKIND CE; 09:51 ITC CE; 09:59 FORTIS CE

## 2026-11-18 replay (point-in-time, minute store)
event counts: AGAINST PREDICTION 1, CONFIRMED 2, CROSS, NO VOLUME 1, EXPIRED 4, FAILED 5, LATE AFTER RING 2, MOVER EXPIRED 19, MOVER SIDE SET 6, NOT PREDICTED 13, SILENT CARD 1, STALE 1, TOO LATE 4
- 09:16 FAILED ✗ PREDICTION FAILED · TMPV - I predicted UP; it is -0.4%, below the cancel 259.00 · AUTO +0.0% · I was wrong on this one. No CE on it today.
- 09:16 FAILED ✗ PREDICTION FAILED · PIIND - I predicted UP; it is -0.8%, below the cancel 1667.60 · CHEMICALS -0.0% · I was wrong on this one. No CE on it today.
- 09:18 MOVER SIDE SET ◆ MOVER PAGEIND fired DOWN: below 30855.00 with volume 4.3x · sector TEXTILES -0.4% · the CE trigger is cancelled · NOT PROVEN
- 09:18 CONFIRMED ✓ MOVER (side open, set by price): PAGEIND DOWN · sector TEXTILES down -0.4% (breadth 8/12) · NIFTY +0.1% · trigger 30855.00 crossed 09:18 with volume 4.3x · move left ~76% of usual · FRESH till 09:23 · grade B · MOVER · silent: 09:17-09:30
- 09:19 MOVER SIDE SET ◆ MOVER ASHOKLEY fired DOWN: below 158.03 with volume 2.7x · sector AUTO -0.1% · the CE trigger is cancelled · NOT PROVEN
- 09:19 SILENT CARD MOVER (side open, set by price): ASHOKLEY DOWN · sector AUTO down -0.1% (breadth 30/50) · NIFTY +0.0% · trigger 158.03 crossed 09:19 with volume 2.7x · move left ~54% of usual · FRESH till 09:24 · not a GO NOW: sector not with it (grade C) 
- 09:21 TOO LATE ◐ TOO LATE · ASHOKLEY -1.5% of the usual ~2.9% done - pullback only: VWAP 158.65 / first lower high, 1 lot
- 09:23 MOVER SIDE SET ◆ MOVER ADANIENSOL fired UP: above 1508.60 with volume 3.3x · sector POWER +0.6% · the PE trigger is cancelled · NOT PROVEN
- 09:23 TOO LATE ◐ TOO LATE · ADANIENSOL +1.6% of the usual ~3.1% done - pullback only: VWAP 1503.74 / first higher low, 1 lot
- 09:26 MOVER SIDE SET ◆ MOVER KALYANKJIL fired DOWN: below 676.20 with volume 2.6x · sector CONSUMER DURABLES -0.4% · the CE trigger is cancelled · NOT PROVEN
- 09:26 TOO LATE ◐ TOO LATE · KALYANKJIL -1.9% of the usual ~3.0% done - pullback only: VWAP 680.71 / first lower high, 1 lot
- 09:27 MOVER SIDE SET ◆ MOVER CUMMINSIND fired DOWN: below 4042.20 with volume 2.4x · sector CAPITAL GOODS -0.4% · the CE trigger is cancelled · NOT PROVEN
- 09:27 CONFIRMED ✓ MOVER (side open, set by price): CUMMINSIND DOWN · sector CAPITAL GOODS down -0.4% (breadth 78/112) · NIFTY -0.0% · trigger 4042.20 crossed 09:27 with volume 2.4x · move left ~53% of usual · FRESH till 09:32 · grade B · MOVER · silent: 09
- 09:29 LATE AFTER RING CUMMINSIND half the move done - no new entry; manage only
- 09:31 MOVER SIDE SET ◆ MOVER ANGELONE fired UP: above 359.16 with volume 8.2x · sector CAPITAL MARKETS +0.7% · the PE trigger is cancelled · NOT PROVEN
- 09:31 TOO LATE ◐ TOO LATE · ANGELONE +2.4% of the usual ~3.1% done - pullback only: VWAP 359.16 / first higher low, 1 lot
- 09:38 LATE AFTER RING PAGEIND half the move done - no new entry; manage only
- 09:46 STALE DIXON not triggered by 09:45 - grade down to WEAK
- 10:25 CROSS, NO VOLUME DIXON crossed 12800.00 but RVOL 0.8 / VWAP ok - not a trigger yet
- 11:01 MOVER EXPIRED ◆ MOVER KAYNES - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER CAMS - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER 360ONE - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER DELHIVERY - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER BANKINDIA - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER FORCEMOT - neither trigger fired by 11:00
- NOT PREDICTED rows: 14 - first 10: 09:27 MANAPPURAM PE; 09:27 MUTHOOTFIN PE; 09:28 UPL PE; 09:31 GAIL CE; 09:33 PIIND PE; 09:39 POLYCAB PE; 09:44 INOXWIND PE; 09:55 IREDA CE; 09:57 SAGILITY CE; 10:21 TITAN PE

## 2026-11-19 replay (point-in-time, minute store)
event counts: CONFIRMED 2, CROSS, NO VOLUME 1, EXPIRED 7, FAILED 5, LATE AFTER RING 2, MOVER EXPIRED 16, MOVER SIDE SET 9, NOT PREDICTED 34, SILENT CARD 7, STALE 4, TOO LATE 6
- 09:17 CROSS, NO VOLUME MOTILALOFS crossed 1208.00 but RVOL 1.5 / VWAP ok - not a trigger yet
- 09:17 MOVER SIDE SET ◆ MOVER MANAPPURAM fired DOWN: below 280.45 with volume 3.1x · sector NBFC & FINANCE -0.3% · the CE trigger is cancelled · NOT PROVEN
- 09:17 SILENT CARD MOVER (side open, set by price): MANAPPURAM DOWN · sector NBFC & FINANCE down -0.3% (breadth 30/52) · NIFTY +0.1% · trigger 280.45 crossed 09:17 with volume 3.1x · move left ~61% of usual · FRESH till 09:22 · not a GO NOW: sector not with i
- 09:17 MOVER SIDE SET ◆ MOVER PIIND fired DOWN: below 1619.70 with volume 2.1x · sector CHEMICALS -0.2% · the CE trigger is cancelled · NOT PROVEN
- 09:17 SILENT CARD MOVER (side open, set by price): PIIND DOWN · sector CHEMICALS down -0.2% (breadth 32/44) · NIFTY +0.1% · trigger 1619.70 crossed 09:17 with volume 2.1x · move left ~84% of usual · FRESH till 09:22 · not a GO NOW: sector not with it (grade 
- 09:19 SILENT CARD MOVER (side open, set by price): MANAPPURAM DOWN · sector NBFC & FINANCE down -0.2% (breadth 26/52) · NIFTY +0.2% · trigger 280.45 crossed 09:17 with volume 3.2x · move left ~64% of usual · FRESH till 09:22 · not a GO NOW: sector not with i
- 09:19 SILENT CARD MOVER (side open, set by price): PIIND DOWN · sector CHEMICALS down -0.1% (breadth 25/44) · NIFTY +0.2% · trigger 1619.70 crossed 09:17 with volume 1.8x · move left ~85% of usual · FRESH till 09:22 · not a GO NOW: sector not with it (grade 
- 09:19 MOVER SIDE SET ◆ MOVER BDL fired UP: above 1031.40 with volume 2.1x · sector CAPITAL GOODS +0.1% · the PE trigger is cancelled · NOT PROVEN
- 09:19 TOO LATE ◐ TOO LATE · BDL +1.9% of the usual ~3.2% done - pullback only: VWAP 1024.93 / first higher low, 1 lot
- 09:20 SILENT CARD MOVER (side open, set by price): MANAPPURAM DOWN · sector NBFC & FINANCE down -0.3% (breadth 29/52) · NIFTY +0.0% · trigger 280.45 crossed 09:17 with volume 3.5x · move left ~81% of usual · FRESH till 09:22 · not a GO NOW: sector not with i
- 09:20 SILENT CARD MOVER (side open, set by price): PIIND DOWN · sector CHEMICALS down -0.2% (breadth 27/44) · NIFTY +0.0% · trigger 1619.70 crossed 09:17 with volume 1.9x · move left ~82% of usual · FRESH till 09:22 · not a GO NOW: sector not with it (grade 
- 09:21 CONFIRMED ✓ MOVER (side open, set by price): MANAPPURAM DOWN · sector NBFC & FINANCE down -0.4% (breadth 32/52) · NIFTY -0.0% · trigger 280.45 crossed 09:17 with volume 3.9x · move left ~76% of usual · FRESH till 09:22 · grade B · MOVER · silent: 09:
- 09:22 MOVER SIDE SET ◆ MOVER TITAN fired DOWN: below 4581.60 with volume 5.1x · sector CONSUMER DURABLES -0.1% · the CE trigger is cancelled · NOT PROVEN
- 09:22 TOO LATE ◐ TOO LATE · TITAN -1.5% of the usual ~2.5% done - pullback only: VWAP 4607.42 / first lower high, 1 lot
- 09:23 SILENT CARD MOVER (side open, set by price): PIIND DOWN · sector CHEMICALS down -0.2% (breadth 32/44) · NIFTY -0.1% · trigger 1619.70 crossed 09:17 with volume 1.2x · move left ~91% of usual · FRESH till 09:22 · not a GO NOW: sector not with it (grade 
- 09:34 MOVER SIDE SET ◆ MOVER ASHOKLEY fired UP: above 162.45 with volume 2.1x · sector AUTO +0.8% · the PE trigger is cancelled · NOT PROVEN
- 09:34 TOO LATE ◐ TOO LATE · ASHOKLEY +2.0% of the usual ~3.0% done - pullback only: VWAP 163.28 / first higher low, 1 lot
- 09:37 LATE AFTER RING MANAPPURAM half the move done - no new entry; manage only
- 09:45 MOVER SIDE SET ◆ MOVER PAGEIND fired UP: above 31015.00 with volume 2.0x · sector TEXTILES +1.9% · the PE trigger is cancelled · NOT PROVEN
- 09:45 CONFIRMED ✓ MOVER (side open, set by price): PAGEIND UP · sector TEXTILES up +1.9% (breadth 11/12) · NIFTY +0.2% · trigger 31015.00 crossed 09:45 with volume 2.0x · move left ~59% of usual · FRESH till 09:50 · grade B · MOVER · GO NOW · NOT PROVEN (d **[RING]**
- 09:46 STALE POWERINDIA not triggered by 09:45 - grade down to WEAK
- 09:46 STALE 360ONE not triggered by 09:45 - grade down to WEAK
- 09:46 STALE MOTILALOFS not triggered by 09:45 - grade down to WEAK
- 09:46 STALE KAYNES not triggered by 09:45 - grade down to BOUNCE
- 09:47 FAILED ✗ PREDICTION FAILED · 360ONE - I predicted DOWN; it is +0.5%, above the cancel 1215.95 · CAPITAL MARKETS +0.4% · I was wrong on this one. No PE on it today.
- NOT PREDICTED rows: 34 - first 10: 09:17 BLUESTARCO CE; 09:17 VOLTAS CE; 09:19 IREDA CE; 09:19 POLICYBZR PE; 09:21 CROMPTON CE; 09:21 HYUNDAI CE; 09:21 PNBHOUSING CE; 09:22 MARUTI CE; 09:22 PGEL CE; 09:23 EICHERMOT CE

## 2026-10-29 replay (point-in-time, minute store)
event counts: CROSS, NO VOLUME 1, EXPIRED 7, FAILED 5, MOVER EXPIRED 19, MOVER SIDE SET 6, NOT PREDICTED 25, STALE 5, TOO LATE 6
- 09:17 CROSS, NO VOLUME NAM-INDIA crossed 939.90 but RVOL 0.5 / VWAP ok - not a trigger yet
- 09:19 MOVER SIDE SET ◆ MOVER SYRMA fired UP: above 1592.40 with volume 2.3x · sector ELECTRONICS & HARDWARE +0.7% · the PE trigger is cancelled · NOT PROVEN
- 09:19 TOO LATE ◐ TOO LATE · SYRMA +2.0% of the usual ~3.3% done - pullback only: VWAP 1591.56 / first higher low, 1 lot
- 09:20 FAILED ✗ PREDICTION FAILED · SWIGGY - I predicted UP; it is -0.8%, below the cancel 183.05 · CONSUMER SERVICES -0.4% · I was wrong on this one. No CE on it today.
- 09:27 MOVER SIDE SET ◆ MOVER PGEL fired UP: above 543.00 with volume 4.5x · sector ELECTRONICS & HARDWARE +1.4% · the PE trigger is cancelled · NOT PROVEN
- 09:27 TOO LATE ◐ TOO LATE · PGEL +2.0% of the usual ~3.1% done - pullback only: VWAP 541.20 / first higher low, 1 lot
- 09:29 MOVER SIDE SET ◆ MOVER APLAPOLLO fired UP: above 2219.00 with volume 5.5x · sector METALS & MINING +0.2% · the PE trigger is cancelled · NOT PROVEN
- 09:29 TOO LATE ◐ TOO LATE · APLAPOLLO +3.4% of the usual ~2.7% done - pullback only: VWAP 2201.17 / first higher low, 1 lot
- 09:32 MOVER SIDE SET ◆ MOVER BIOCON fired UP: above 353.85 with volume 5.0x · sector PHARMA +0.3% · the PE trigger is cancelled · NOT PROVEN
- 09:32 TOO LATE ◐ TOO LATE · BIOCON +1.5% of the usual ~2.5% done - pullback only: VWAP 352.61 / first higher low, 1 lot
- 09:38 MOVER SIDE SET ◆ MOVER BANDHANBNK fired UP: above 156.98 with volume 7.3x · sector BANKS +0.4% · the PE trigger is cancelled · NOT PROVEN
- 09:38 TOO LATE ◐ TOO LATE · BANDHANBNK +2.0% of the usual ~3.0% done - pullback only: VWAP 156.45 / first higher low, 1 lot
- 09:46 STALE KAYNES not triggered by 09:45 - grade down to WEAK
- 09:46 STALE PATANJALI not triggered by 09:45 - grade down to WEAK
- 09:46 STALE YESBANK not triggered by 09:45 - grade down to BOUNCE
- 09:46 STALE NAM-INDIA not triggered by 09:45 - grade down to BOUNCE
- 09:46 STALE KEI not triggered by 09:45 - grade down to BOUNCE
- 09:47 FAILED ✗ PREDICTION FAILED · YESBANK - I predicted UP; it is -0.6%, below the cancel 15.53 · BANKS +0.4% · I was wrong on this one. No CE on it today.
- 09:47 FAILED ✗ PREDICTION FAILED · KEI - I predicted UP; it is -0.2%, below the cancel 3844.70 · CAPITAL GOODS -0.3% · I was wrong on this one. No CE on it today.
- 10:10 MOVER SIDE SET ◆ MOVER UPL fired UP: above 537.95 with volume 2.0x · sector CHEMICALS +0.3% · the PE trigger is cancelled · NOT PROVEN
- 10:10 TOO LATE ◐ TOO LATE · UPL +2.9% of the usual ~2.8% done - pullback only: VWAP 540.58 / first higher low, 1 lot
- 11:01 MOVER EXPIRED ◆ MOVER AUBANK - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER APOLLOHOSP - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER CUB - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER GVT&D - neither trigger fired by 11:00
- NOT PREDICTED rows: 25 - first 10: 09:17 FORCEMOT CE; 09:17 HYUNDAI CE; 09:17 TVSMOTOR PE; 09:17 UNITDSPR CE; 09:18 PNBHOUSING PE; 09:23 JSWENERGY CE; 09:27 RECLTD CE; 09:29 VOLTAS CE; 09:30 CDSL CE; 09:30 TRENT PE

## 2026-10-27 replay (point-in-time, minute store)
event counts: CONFIRMED 1, CROSS, NO VOLUME 3, EXPIRED 7, FAILED 2, LATE AFTER RING 1, LATE TRIGGER 1, MOVER EXPIRED 19, MOVER SIDE SET 6, NOT PREDICTED 34, STALE 3, TOO LATE 5
- 09:17 MOVER SIDE SET ◆ MOVER ATHERENERG fired UP: above 1623.00 with volume 21.9x · sector AUTO +0.5% · the PE trigger is cancelled · NOT PROVEN
- 09:17 TOO LATE ◐ TOO LATE · ATHERENERG +1.8% of the usual ~3.5% done - pullback only: VWAP 1622.92 / first higher low, 1 lot
- 09:17 MOVER SIDE SET ◆ MOVER ADANIGREEN fired UP: above 1250.00 with volume 2.1x · sector POWER +0.6% · the PE trigger is cancelled · NOT PROVEN
- 09:17 CONFIRMED ✓ MOVER (side open, set by price): ADANIGREEN UP · sector POWER up +0.6% (breadth 23/24) · NIFTY -0.1% · trigger 1250.00 crossed 09:17 with volume 2.1x · move left ~68% of usual · FRESH till 09:22 · grade B · MOVER · silent: 09:17-09:30 onl
- 09:20 FAILED ✗ PREDICTION FAILED · YESBANK - I predicted UP; it is -0.9%, below the cancel 15.84 · BANKS +0.4% · I was wrong on this one. No CE on it today.
- 09:21 LATE AFTER RING ADANIGREEN half the move done - no new entry; manage only
- 09:23 MOVER SIDE SET ◆ MOVER SHRIRAMFIN fired UP: above 836.00 with volume 3.1x · sector NBFC & FINANCE +0.3% · the PE trigger is cancelled · NOT PROVEN
- 09:23 TOO LATE ◐ TOO LATE · SHRIRAMFIN +1.5% of the usual ~2.7% done - pullback only: VWAP 833.13 / first higher low, 1 lot
- 09:26 MOVER SIDE SET ◆ MOVER KFINTECH fired UP: above 864.00 with volume 19.9x · sector CAPITAL MARKETS +0.5% · the PE trigger is cancelled · NOT PROVEN
- 09:26 TOO LATE ◐ TOO LATE · KFINTECH +4.7% of the usual ~3.1% done - pullback only: VWAP 846.85 / first higher low, 1 lot
- 09:27 MOVER SIDE SET ◆ MOVER AMBER fired UP: above 6015.00 with volume 2.5x · sector ELECTRONICS & HARDWARE +1.4% · the PE trigger is cancelled · NOT PROVEN
- 09:27 TOO LATE ◐ TOO LATE · AMBER +2.4% of the usual ~2.7% done - pullback only: VWAP 5956.65 / first higher low, 1 lot
- 09:27 MOVER SIDE SET ◆ MOVER BANKINDIA fired UP: above 129.73 with volume 2.6x · sector BANKS +0.6% · the PE trigger is cancelled · NOT PROVEN
- 09:27 TOO LATE ◐ TOO LATE · BANKINDIA +2.5% of the usual ~2.7% done - pullback only: VWAP 128.93 / first higher low, 1 lot
- 09:28 CROSS, NO VOLUME NAM-INDIA crossed 934.70 but RVOL 0.9 / VWAP ok - not a trigger yet
- 09:29 CROSS, NO VOLUME INOXWIND crossed 59.50 but RVOL 1.3 / VWAP ok - not a trigger yet
- 09:46 STALE DIXON not triggered by 09:45 - grade down to BOUNCE
- 09:46 STALE NAM-INDIA not triggered by 09:45 - grade down to BOUNCE
- 09:46 STALE INOXWIND not triggered by 09:45 - grade down to BOUNCE
- 11:01 MOVER EXPIRED ◆ MOVER AUBANK - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER KEI - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER CUB - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER UJJIVANSFB - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER 360ONE - neither trigger fired by 11:00
- 11:01 MOVER EXPIRED ◆ MOVER SWIGGY - neither trigger fired by 11:00
- NOT PREDICTED rows: 34 - first 10: 09:17 MAHABANK CE; 09:17 SONACOMS CE; 09:18 DATAPATTNS CE; 09:19 MANKIND CE; 09:20 RECLTD PE; 09:24 APLAPOLLO CE; 09:29 PGEL CE; 09:30 BHARATFORG CE; 09:30 PAYTM PE; 09:31 DIVISLAB CE

## Fri 20 Nov LIVE shadow run of the loop (live.py on the day's live quotes; nothing sent)
event counts: AGAINST PREDICTION 2, EXPIRED 1, FAILED 5, NEAR 2, NOT PREDICTED 39, SILENT CARD 2, STALE 1, TOO LATE 1, TRIGGERED 2
- 09:21 FAILED ✗ PREDICTION FAILED · KALYANKJIL - I predicted UP; it is -1.8%, below the cancel 643.81 · CONSUMER DURABLES +0.4% · I was wrong on this one. No CE on it today.
- 09:21 TRIGGERED TMPV trigger 263.40 crossed with volume 3.0x
- 09:21 TOO LATE ◐ TOO LATE · TMPV +1.4% of the usual ~2.6% done - pullback only: VWAP 263.69 / first higher low, 1 lot
- 09:24 FAILED ✗ PREDICTION FAILED · KALYANKJIL - I predicted UP; it is -0.0%, below the cancel 643.81 · CONSUMER DURABLES +0.0% · I was wrong on this one. No CE on it today.
- 09:24 TRIGGERED TMPV trigger 263.40 crossed with volume 4.0x
- 09:24 SILENT CARD PREDICTED last evening: TMPV UP · sector AUTO up -0.0% (breadth 5/17) · NIFTY +0.0% · trigger 263.40 crossed 09:24 with volume 4.0x · move left ~100% of usual · FRESH till 09:29 · not a GO NOW: sector not with it (grade C) - silent
- 09:29 FAILED ✗ PREDICTION FAILED · MANAPPURAM - I predicted DOWN; it is +0.2%, above the cancel 276.14 · NBFC & FINANCE -0.1% · I was wrong on this one. No PE on it today.
- 09:31 SILENT CARD PREDICTED last evening: TMPV UP · sector AUTO up -0.1% (breadth 7/17) · NIFTY +0.0% · trigger 263.40 crossed 09:25 with volume 6.0x · move left ~92% of usual · FRESH till 09:30 · not a GO NOW: sector not with it (grade C) - silent; past the
- 09:33 FAILED ✗ PREDICTION FAILED · MUTHOOTFIN - I predicted DOWN; it is +0.7%, above the cancel 2544.80 · NBFC & FINANCE -0.1% · I was wrong on this one. No PE on it today.
- 09:46 STALE ALKEM not triggered by 09:45 - grade down to WEAK
- 11:05 FAILED ✗ PREDICTION FAILED · RVNL - I predicted UP; it is -0.7%, below the cancel 191.75 · CONSTRUCTION -0.0% · I was wrong on this one. No CE on it today.
- 14:31 EXPIRED ALKEM DOWN · 14:30 - expired, manage only

## Tuning-day replay (14 sessions, 23 Oct-17 Nov, point-in-time each)
confirmed 16 (rung 4) · too late 64 · failed 39 · NOT PREDICTED rows 504

Honest note (B7): the confirmation adds no edge of its own; its value depends on the evening list beating the base rate - NOT PROVEN.
