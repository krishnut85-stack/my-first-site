# D desk web - every R51 row

Run 21 Nov 2026 09:14 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
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
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1366x768 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 09:00 · next look 09:11 · 4m ago MUST SEE valid 09:14 	PREMIUM 1,000 CE	SHARE TRIGGER	33.00	991. |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1366x768 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows MARKETNIFTY above VWAP (+0 |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1366x768 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1366x768 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1366x768 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1366x768 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1366x768 | inside | PASS | footer " · desk ON · LEAN - next brief Sun 19:45" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1366x768 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 09:01 · next look 09:12 STALE · 3m ago MUST SEE valid 09:15 	PR |
| head running (live): no "analyst not running" chip on the card; GIR ANALYST header only on a desk BUY NOW | F1 desk (live) | 1366x768 | inside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now Cards show CRITICAL and MUST SEE call |
| footer AI word (live, head running): "desk ON ..." (next brief / mode) or the P1 line | F1 desk (live) | 1366x768 | inside | PASS |  · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1366x768 | inside | PASS | none |
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS | ltp · 18h · bid/ask – IV – now · – in · θ – /lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 08:59 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 18h · bid/ask – IV – now · – in · θ – /lot GIR |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 08:59 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – not |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | inside | PASS | NOW 846.00 VS STOP – stop – prem · target – / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – qty 1,300 |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F6 GIR row (live) | 1366x768 | inside | PASS | none |
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1366x768 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 05:44 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1366x768 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1366x768 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1366x768 | inside | PASS | THEME NOT PROVEN FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY LEADER |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1366x768 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1366x768 | inside | PASS | analyst 07:15 · made 05:44 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head running (live): PRE-FLIGHT "Desk n of N seats running · mode · $ of cap" | Morning (live) | 1366x768 | inside | PASS | 0 / ✓ Desk 44 of 46 seats running · LEAN · $1.92 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - written to fi |
| no cut text (Morning, live) | Morning (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | Morning (live) | 1366x768 | inside | PASS | none |
| desk-hunt ACTION: IDEAS n chip (no wrap at 1366) | F1 ACTION (fixture) | 1366x768 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1366x768 | inside | PASS | ['06:44 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '06:44 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '06:44 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '06:44 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1366x768 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | chip IDEA 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| head running (live): IDEAS = the head's book (rows, or "the head has no idea in its book now"); no fixture text | F1 ACTION (live) | 1366x768 | inside | PASS | the head analyst's ideas (desk.ideas): GET READY = ARMED, GO / the head has no idea in its book now / THEME silver −4.74% metals & mining CALL MIXED Hang Seng (Ch |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1366x768 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1366x768 | inside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | inside | PASS | pages: 23 |
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1600x900 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 09:03 · next look 09:14 · 3m ago MUST SEE valid 09:17 	PREMIUM 1,000 CE	SHARE TRIGGER	33.00	991. |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1600x900 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows MARKETNIFTY above VWAP (+0 |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1600x900 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1600x900 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1600x900 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1600x900 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1600x900 | inside | PASS | footer " · desk ON · LEAN - next brief Sun 19:45" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1600x900 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 09:03 · next look 09:14 STALE · 3m ago MUST SEE valid 09:17 	PR |
| head running (live): no "analyst not running" chip on the card; GIR ANALYST header only on a desk BUY NOW | F1 desk (live) | 1600x900 | inside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now Cards show CRITICAL and MUST SEE call |
| footer AI word (live, head running): "desk ON ..." (next brief / mode) or the P1 line | F1 desk (live) | 1600x900 | inside | PASS |  · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | inside | PASS | none |
| the head's manage note in the GIR row (HOLD - thesis ...) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS |  · bid/ask – IV – now · – at entry · θ – per lot GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 09:01 · NOT PROVEN KITE MODIFY SL-L → LIMIT bid − 1 tick bid – · one |
| no cut text (desk-trade GIR row, fixture) | desk-trade GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 18h · bid/ask – IV – now · – at entry · θ – pe |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| the head's manage note in the GIR row (HOLD - thesis ...) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 00 · ₹16,965 · spread – · depth – IV – → – 20d – GIR HOLD FIXTURE: thesis intact - banks breadth negative for this name GIR ANALYST 09:01 · NOT PROVEN KITE MODIFY SL-L – → LIMIT bid − 1 tick bid – · o |
| no cut text (F6 GIR row, fixture) | F6 GIR row (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | inside | PASS | NOW 846.00 VS STOP – share · 18h stop – prem · target – / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F6 GIR row (live) | 1600x900 | inside | PASS | none |
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1600x900 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 05:46 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1600x900 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1600x900 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1600x900 | inside | PASS | THEME NOT PROVEN 06:46 · CONFIRMING FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1600x900 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1600x900 | inside | PASS | analyst 07:15 · made 05:46 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head running (live): PRE-FLIGHT "Desk n of N seats running · mode · $ of cap" | Morning (live) | 1600x900 | inside | PASS | 0 / ✓ Desk 44 of 46 seats running · LEAN · $1.92 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - written to fi |
| no cut text (Morning, live) | Morning (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | Morning (live) | 1600x900 | inside | PASS | none |
| desk-hunt ACTION: IDEAS n chip (no wrap at 1600) | F1 ACTION (fixture) | 1600x900 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1600x900 | inside | PASS | ['06:47 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '06:47 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '06:47 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '06:47 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1600x900 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | chip IDEAS 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 3 |
| head running (live): IDEAS = the head's book (rows, or "the head has no idea in its book now"); no fixture text | F1 ACTION (live) | 1600x900 | inside | PASS | the head analyst's ideas (desk.ideas): GET READY = ARMED, GO / the head has no idea in its book now / THEME silver −4.74% metals & mining CALL MIXED Hang Seng (Ch |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1600x900 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1600x900 | inside | PASS | none |
| no sideways scroll at 1600 on every page | all pages | 1600x900 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1600x900 | inside | PASS | pages: 23 |
| NOW in a trade: the GIR block carries the head's manage note | phone (fixture) | 390x844 | inside | PASS | e stop not known ltp 13.50 18h GIR HOLD ANALYST 09:03 · NOT PROVEN FIXTURE: thesis intact - banks breadth negative for this name EXIT LINE · |
| CALL: FROM / AGAINST / NOT PROVEN, the head's card | phone (fixture) | 390x844 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows MARKET |
| CALL: WHY 2 lines + "more" (finger) | phone (fixture) | 390x844 | inside | PASS | 2 -> 3 lines |
| CALL: one blue CONNECTION line | phone (fixture) | 390x844 | inside | PASS | present |
| no cut text (phone CALL, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| ALERTS: the brief note (changed first, Themes max 3) | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 05:48 NOT PROVEN changed: TCS PE CANCELLED FIXTURE: banks lead on foreign buying, IT under pressure from the US |
| ALERTS brief.stale: "STALE · <why>", never blank | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 05:48 NOT PROVEN STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief is shown change |
| no cut text (phone ALERTS, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: CALL keeps the old card, no brief note | phone (live) | 390x844 | inside | PASS | brief note False |
| no sideways scroll at 390 (phone) | phone (live) | 390x844 | inside | PASS | 390 |
| page errors | phone (live) | 390x844 | inside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 390x844 | inside | PASS | none |
| no sideways scroll at 390 on every page | all pages | 390x844 | inside | PASS | none |
| no Desk Room page or link left | all pages | 390x844 | inside | PASS | pages: 23 |
| head running (live): no "analyst not running" chip on the card; GIR ANALYST header only on a desk BUY NOW | F1 desk (live) | 1366x768 | outside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now Cards show CRITICAL and MUST SEE call |
| footer AI word (live, head running): "desk ON ..." (next brief / mode) or the P1 line | F1 desk (live) | 1366x768 | outside | PASS |  · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1366x768 | outside | PASS | none |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 18h · bid/ask – IV – now · – in · θ – /lot GIR |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1366x768 | outside | PASS | NOW 846.00 VS STOP – stop – prem · target – / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask – qty 1,300 |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F6 GIR row (live) | 1366x768 | outside | PASS | none |
| head running (live): PRE-FLIGHT "Desk n of N seats running · mode · $ of cap" | Morning (live) | 1366x768 | outside | PASS | 0 / ✓ Desk 44 of 46 seats running · LEAN · $1.92 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - written to fi |
| no cut text (Morning, live) | Morning (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | Morning (live) | 1366x768 | outside | PASS | none |
| head running (live): IDEAS = the head's book (rows, or "the head has no idea in its book now"); no fixture text | F1 ACTION (live) | 1366x768 | outside | PASS | the head analyst's ideas (desk.ideas): GET READY = ARMED, GO / the head has no idea in its book now / THEME silver −4.74% metals & mining CALL MIXED Hang Seng (Ch |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1366x768 | outside | PASS | none |
| 0 console errors on every page (23 pages) | all pages | 1366x768 | outside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | outside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | outside | PASS | pages: 23 |
| head running (live): no "analyst not running" chip on the card; GIR ANALYST header only on a desk BUY NOW | F1 desk (live) | 1600x900 | outside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now Cards show CRITICAL and MUST SEE call |
| footer AI word (live, head running): "desk ON ..." (next brief / mode) or the P1 line | F1 desk (live) | 1600x900 | outside | PASS |  · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | outside | PASS | none |
| head not running: the GIR row keeps the engine follow-up | desk-trade GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – – room – P&L P&L curve not known 13.05 → 13.50 ltp · 18h · bid/ask – IV – now · – at entry · θ – pe |
| no cut text (desk-trade GIR row, live) | desk-trade GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: the GIR row keeps the engine follow-up | F6 GIR row (live) | 1600x900 | outside | PASS | NOW 846.00 VS STOP – share · 18h stop – prem · target – / – – room – P&L P&L curve not known 13.05 → 13.50 ltp · bid/ask |
| no cut text (F6 GIR row, live) | F6 GIR row (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F6 GIR row (live) | 1600x900 | outside | PASS | none |
| head running (live): PRE-FLIGHT "Desk n of N seats running · mode · $ of cap" | Morning (live) | 1600x900 | outside | PASS | 0 / ✓ Desk 44 of 46 seats running · LEAN · $1.92 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - written to fi |
| no cut text (Morning, live) | Morning (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | Morning (live) | 1600x900 | outside | PASS | none |
| head running (live): IDEAS = the head's book (rows, or "the head has no idea in its book now"); no fixture text | F1 ACTION (live) | 1600x900 | outside | PASS | the head analyst's ideas (desk.ideas): GET READY = ARMED, GO / the head has no idea in its book now / THEME silver −4.74% metals & mining CALL MIXED Hang Seng (Ch |
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
