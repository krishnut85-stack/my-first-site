# D desk web - every R51 row

Run 20 Nov 2026 21:25 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v2 (meter.cap 8, meter.lean, brief.stale / stale_why / failed_slot). Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v2 shape, every text
"FIXTURE", cap 8, lean on; the live state.json never touched; the STALE rows flip that fixture's view.stale / brief.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

**144 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1366x768 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 21:12 · next look 21:23 · 4m ago MUST SEE ITC PE MAXHEALTH CE MAXHEALTH PE NTPC CE HDFCBANK CE I |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1366x768 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1366x768 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1366x768 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1366x768 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1366x768 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1366x768 | inside | PASS | footer "alth LIMITED · atr LATE 117h · desk LEAN" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1366x768 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 21:12 · next look 21:23 STALE · 4m ago MUST SEE ITC PE MAXHEALT |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | inside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 6h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | inside | PASS | MITED · atr LATE 117h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 desk (live) | 1366x768 | inside | PASS | none |
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS |  ltp · 6h · bid/ask – IV – now · – in · θ – /lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 21:10 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 6h · bid/ask – IV – now · – in · θ – /lot GIR  |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 21:11 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – not |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1366x768 | inside | PASS | none |
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1366x768 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 17:56 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1366x768 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1366x768 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1366x768 | inside | PASS | THEME NOT PROVEN FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY LEADER |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1366x768 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1366x768 | inside | PASS | analyst 07:15 · made 17:56 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1366x768 | inside | PASS | 0 / ○ Desk not running · 46 seats · $0.36 of $8 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1366x768 | inside | PASS | none |
| desk-hunt ACTION: IDEAS n chip (no wrap at 1366) | F1 ACTION (fixture) | 1366x768 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1366x768 | inside | PASS | ['18:56 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '18:56 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '18:56 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '18:56 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1366x768 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | chip IDEA 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 5 |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1366x768 | inside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.58% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 ACTION (live) | 1366x768 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1366x768 | inside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | inside | PASS | pages: 23 |
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1600x900 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 21:14 · next look 21:25 · 4m ago MUST SEE ITC PE MAXHEALTH CE MAXHEALTH PE NTPC CE HDFCBANK CE I |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1600x900 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1600x900 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1600x900 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1600x900 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1600x900 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1600x900 | inside | PASS | footer "alth LIMITED · atr LATE 117h · desk LEAN" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1600x900 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 21:14 · next look 21:25 STALE · 4m ago MUST SEE ITC PE MAXHEALT |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | inside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 6h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | inside | PASS | MITED · atr LATE 117h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | inside | PASS | none |
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS |  · bid/ask – IV – now · – at entry · θ – per lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 21:13 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 6h · bid/ask – IV – now · – at entry · θ – per |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 21:13 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – · o |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – share · 6h stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp  |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1600x900 | inside | PASS | none |
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1600x900 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 17:58 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1600x900 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1600x900 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1600x900 | inside | PASS | THEME NOT PROVEN 18:58 · CONFIRMING FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1600x900 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1600x900 | inside | PASS | analyst 07:15 · made 17:58 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1600x900 | inside | PASS | 0 / ○ Desk not running · 46 seats · $0.37 of $8 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1600x900 | inside | PASS | none |
| desk-hunt ACTION: IDEAS n chip (no wrap at 1600) | F1 ACTION (fixture) | 1600x900 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1600x900 | inside | PASS | ['18:58 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '18:58 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '18:58 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '18:58 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1600x900 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | chip IDEAS 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1600x900 | inside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.64% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1600x900 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1600x900 | inside | PASS | none |
| no sideways scroll at 1600 on every page | all pages | 1600x900 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1600x900 | inside | PASS | pages: 23 |
| NOW in a trade: the GIR block carries the head's manage note | phone (fixture) | 390x844 | inside | PASS | o the stop · 2.1% ltp 13.50 6h GIR HOLD ANALYST 21:14 · NOT PROVEN FIXTURE: thesis intact - banks breadth negative for this name EXIT LINE · |
| CALL: FROM / AGAINST / NOT PROVEN, the head's card | phone (fixture) | 390x844 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban  |
| CALL: WHY 2 lines + "more" (finger) | phone (fixture) | 390x844 | inside | PASS | 2 -> 3 lines |
| CALL: one blue CONNECTION line | phone (fixture) | 390x844 | inside | PASS | present |
| no cut text (phone CALL, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| ALERTS: the brief note (changed first, Themes max 3) | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 18:00 NOT PROVEN changed: TCS PE CANCELLED FIXTURE: banks lead on foreign buying, IT under pressure from the US |
| ALERTS brief.stale: "STALE · <why>", never blank | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 18:00 NOT PROVEN STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief is shown change |
| no cut text (phone ALERTS, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: CALL keeps the old card, no brief note | phone (live) | 390x844 | inside | PASS | brief note False |
| no sideways scroll at 390 (phone) | phone (live) | 390x844 | inside | PASS | 390 |
| page errors | phone (live) | 390x844 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 390x844 | inside | PASS | none |
| no sideways scroll at 390 on every page | all pages | 390x844 | inside | PASS | none |
| no Desk Room page or link left | all pages | 390x844 | inside | PASS | pages: 23 |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | outside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 6h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | outside | PASS | MITED · atr LATE 117h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 desk (live) | 1366x768 | outside | PASS | none |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 6h · bid/ask – IV – now · – in · θ – /lot GIR  |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1366x768 | outside | PASS | none |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1366x768 | outside | PASS | 0 / ○ Desk not running · 46 seats · $0.37 of $8 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1366x768 | outside | PASS | none |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1366x768 | outside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.43% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 ACTION (live) | 1366x768 | outside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1366x768 | outside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | outside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | outside | PASS | pages: 23 |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | outside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 6h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | outside | PASS | MITED · atr LATE 117h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | outside | PASS | none |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 6h · bid/ask – IV – now · – at entry · θ – per |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – share · 6h stop ≈22.96 prem · target 820.72 / – – room – P&L P&L curve not known 13.05 → 13.50 ltp  |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 2 |
| page errors | F6 GIR row (live) | 1600x900 | outside | PASS | none |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1600x900 | outside | PASS | 0 / ○ Desk not running · 46 seats · $0.39 of $8 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1600x900 | outside | PASS | none |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1600x900 | outside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.58% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1600x900 | outside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1600x900 | outside | PASS | none |
| no sideways scroll at 1600 on every page | all pages | 1600x900 | outside | PASS | none |
| no Desk Room page or link left | all pages | 1600x900 | outside | PASS | pages: 23 |
| head not running: CALL keeps the old card, no brief note | phone (live) | 390x844 | outside | PASS | brief note False |
| no sideways scroll at 390 (phone) | phone (live) | 390x844 | outside | PASS | 390 |
| page errors | phone (live) | 390x844 | outside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 390x844 | outside | PASS | none |
| no sideways scroll at 390 on every page | all pages | 390x844 | outside | PASS | none |
| no Desk Room page or link left | all pages | 390x844 | outside | PASS | pages: 23 |
