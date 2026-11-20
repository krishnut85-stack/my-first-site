# D desk web 6_action - Monday item 6 - F1 ACTION panel + THEME rows (and desk-trade IDEAS / DRIVERS)

Run 20 Nov 2026 21:25 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v2 (meter.cap 8, meter.lean, brief.stale / stale_why / failed_slot). Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v2 shape, every text
"FIXTURE", cap 8, lean on; the live state.json never touched; the STALE rows flip that fixture's view.stale / brief.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
static/desk-hunt.js (backups .bak2048 / .bak2104 / .bak2115): ACTION gets one more chip "IDEAS n" = the head's book (desk.ideas); its rows use the existing row style: GO NOW = FIRED / BUY NOW, GET READY = ARMED, dead ideas show "cancelled: <reason>"; head not running -> "IDEAS 0" whose tooltip and list say "head analyst not running - no desk ideas". THEME rows on top of the Sectors panel = the head's top 2 themes (short headline, side chip, CONF / NEW), else the engine's legs as before. desk-hunt-v2.css (.bak2052): the ACTION chip row was already tight at 1366 and the extra chip made it wrap - chips made compact at 700-1499 px and 1500+ px (measured 390/390 px at 1366, 458/458 at 1600, no wrap). static/desk-trade.js (.bak2048): the IDEAS chip count and list = the head's book; the DRIVERS row's theme parts = the head's top 2 themes. Also: the F1 call card keeps its scroll position when the same call re-renders (a link click at 1600 used to land on another line). Fixed during tests (21:04): that scroll patch had put a comment in front of the ACTION render call, which emptied the ACTION panel; split onto its own line. Fixed after the first outside run (21:15, .bak2115): at 1600 outside the engine feed (calls.feed) was not in yet and the ACTION panel early return wiped the IDEAS chip too - the IDEAS chip and list now show whether or not the engine feed is in.

## R51-style rows
**24 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| desk-hunt ACTION: IDEAS n chip (no wrap at 1366) | F1 ACTION (fixture) | 1366x768 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1366x768 | inside | PASS | ['18:56 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '18:56 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '18:56 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '18:56 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1366x768 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | chip IDEA 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 5 |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1366x768 | inside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.58% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 ACTION (live) | 1366x768 | inside | PASS | none |
| desk-hunt ACTION: IDEAS n chip (no wrap at 1600) | F1 ACTION (fixture) | 1600x900 | inside | PASS | IDEA 4 · fits True · row 26px |
| IDEAS = the head's ideas: GO NOW = FIRED / BUY NOW, GET READY = ARMED, CANCELLED with its reason | F1 ACTION (fixture) | 1600x900 | inside | PASS | ['18:58 GO NOW SBIN CALL ENTER only if FIXTURE: a pullback to ', '18:58 GET READY ICICIBANK CALL ENTER only if FIXTURE: a 1-mi', '18:58 STANDS INFY PUT ENTER only if FIXTURE: back below VWAP', '18:58 CANCELLED TCS PUT cancelled: FIXTURE: IT held VWAP for'] |
| THEME rows on top of the Sectors panel = the head's themes | F1 ACTION (fixture) | 1600x900 | inside | PASS | THEME FIXTURE: AI IPO -> FII ro… CALL CONF |
| no cut text (F1 ACTION + THEME, fixture) | F1 ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| desk-trade: IDEAS chip = the head's book; DRIVERS row = the head's themes | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | chip IDEAS 4 · rows 4 · drivers THEME FIXTURE: AI IPO -> FII rotation -… → SBIN CE, HDFCBANK CE, INFY PE / ROTAT |
| no cut text (desk-trade ACTION + DRIVERS, fixture) | desk-trade ACTION (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 4 |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1600x900 | inside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.64% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1600x900 | inside | PASS | none |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1366x768 | outside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.43% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 ACTION (live) | 1366x768 | outside | PASS | none |
| head not running: IDEAS 0 says so; THEME rows keep the engine legs | F1 ACTION (live) | 1600x900 | outside | PASS | head analyst not running - no desk ideas / head analyst not running - no desk ideas / THEME SILVER (MCX, data only) −5.58% no sector - silver −4.7 |
| no cut text (F1 ACTION, live) | F1 ACTION (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 ACTION (live) | 1600x900 | outside | PASS | none |
