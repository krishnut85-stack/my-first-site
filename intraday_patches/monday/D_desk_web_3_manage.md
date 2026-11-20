# D desk web 3_manage - Monday item 3 - manage notes in the GIR rows (desk-trade, F6, phone NOW; Telegram follow-ups)

Run 20 Nov 2026 20:02 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v1. Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v1 shape, every text
"FIXTURE"; the live state.json never touched; the STALE row flips that fixture's view.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
desk-trade.js and positions.js: the GIR row of a position shows the head's latest manage note for it (desk.manage, matched on POS:<tradingsymbol>): action chip + the why + "GIR ANALYST hh:mm · NOT PROVEN"; otherwise the engine follow-up as before. phone.js: the GIR block of each position card on NOW the same. Telegram follow-ups: the existing follow-up message carries the same words (tg_format.manage).

## R51-style rows
**29 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS |  ltp · 4h · bid/ask – IV – now · – in · θ – /lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 19:48 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 4h · bid/ask – IV – now · – in · θ – /lot GIR  |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 19:48 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – not |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1366x768 | inside | PASS | none |
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS |  · bid/ask – IV – now · – at entry · θ – per lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 19:50 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 4h · bid/ask – IV – now · – at entry · θ – per |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 19:50 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – · o |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – share · 4h stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp  |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1600x900 | inside | PASS | none |
| NOW in a trade: the GIR block carries the head's manage note | phone (fixture) | 390x844 | inside | PASS | o the stop · 2.1% ltp 13.50 4h GIR HOLD ANALYST 19:51 · NOT PROVEN FIXTURE: thesis intact - banks breadth negative for this name EXIT LINE · |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 4h · bid/ask – IV – now · – in · θ – /lot GIR  |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1366x768 | outside | PASS | none |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 4h · bid/ask – IV – now · – at entry · θ – per |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – share · 4h stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp  |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1600x900 | outside | PASS | none |
