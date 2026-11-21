# R51 controls test - SECTOR DRILL-DOWN (R50) on the real /preview pages

Run 20 Nov 2026 17:48 IST. Real input only: mouse clicks, drags of scrollbar thumbs and wheel, keyboard on the desk (1366x768 and 1600x900, deviceScaleFactor 1);
finger touches on the phone (390x844, hasTouch + isMobile, CDP touchStart / touchMove / touchEnd). No forced states: the page state is only read to check what the input did.
Inside = http://127.0.0.1:8100/preview/... ; outside = https://girtrader.com/preview/... through the login (cookie made by sitelogin, never printed).
Data = the live store with the close of the day of the run (market closed). NOT RUN = the control needs a live market state that does not exist tonight (named in the row).

**Totals:** 12 NOT RUN · 871 PASS

| where | result | n |
|---|---|---|
| inside | NOT RUN | 6 |
| inside | PASS | 447 |
| outside | NOT RUN | 6 |
| outside | PASS | 424 |

## FAIL rows (0)

none

## Notes (D1 re-run, 20 Nov after the close)
- One clean pass of the whole suite after the last change: inside 1366 / 1600 / 390, the rules port, outside 1366 / 1600 / 390, then the screenshots. gir-preview was restarted under the edit lock before each run (its memory grows about 10 MB per page load and is not given back; it was OOM-killed twice earlier this evening during the tests).
- NEW check (D1): "no cut text" - every cell of the drill-down, the share pane and the host sector lists (F3 table head and rows, F2 board rows, F1 sector rows, Morning cards, the flow line) with scrollWidth > clientWidth FAILS, no tolerance. It runs with no sector open, then with EVERY sector opened by a real click, its "+n more" and its not-F&O fold opened and a share loaded in the pane, at 1366 and 1600, inside and outside. Allowed: prose with a tooltip (4+ words with a title, e.g. the WHY line and the basis text). 16 rows, all PASS.
- Flake, reported: the first outside phone run (17:22) stopped at its first finger tap on the F3 Banks row - the tap left the page (the page under the finger was no longer a drill page), so that run recorded 1 FAIL and no other phone rows. A fresh outside phone run at 17:47 gave 52 / 52 PASS and is the one in this table. Inside, every phone run of the final pass passed.
- NOT RUN (x3 per desk viewport and side): re-rank chip / NEW / live ticks (no ticks after the close), STALE (no stale quote now), LOCKED (lock not hit). Their rules pass in the rules rows (what-if mode live).
- Data tonight: the December chain (oc.<SYM>.rows2) is in the store for only 17 of 220 chains, so most rows show "Dec n/k" and the list names the gap once; Copy then reads "Copy contract · 0 lots" (disabled, size shown) and O opens the chain on the share (never a November strike). The tests accept that only when no share of the sector has a December contract.
- Screenshots: shots/ (outside, logged in). The MY F&O P&L strip: every value box masked dark grey by Playwright (mask + mask_color #2b3038), one label "P&L hidden".

## Every row

| # | control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|---|
| 1 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 205 -> 1 (max 612) |
| 2 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | inside | PASS | 1 -> 410 |
| 3 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1366x768 | inside | PASS | top 612 of max 612 (a page that snaps to whole rows may stop one row short) |
| 4 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1366x768 | inside | PASS | top 0 |
| 5 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 267 -> 159 |
| 6 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1366x768 | inside | PASS | 159 -> 272 -> 170 |
| 7 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | inside | PASS | -> 370 -> 170 |
| 8 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 9 | F3 table row click opens the sector | F3 rotation | 1366x768 | inside | PASS | open banks in 13 ms (from the cached store) |
| 10 | opens under 100 ms | F3 rotation | 1366x768 | inside | PASS | 13 ms |
| 11 | the open list pushes the rows below (no overprint) | F3 rotation | 1366x768 | inside | PASS | list bottom 774 · next sector row top 780 |
| 12 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1366x768 | inside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 13 | every visible share name - click loads the pane, the list stays | F3 rotation | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 14 | J through the whole list (pane follows) | F3 rotation | 1366x768 | inside | PASS | J x7 -> FEDERALBNK (last row FEDERALBNK) |
| 15 | K back up | F3 rotation | 1366x768 | inside | PASS | K x7 -> INDUSINDBK |
| 16 | ↓ / ↑ move share to share | F3 rotation | 1366x768 | inside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 17 | J / K after a click in the pane | F3 rotation | 1366x768 | inside | PASS | J BANDHANBNK · K INDUSINDBK |
| 18 | pane share name - single click | F3 rotation | 1366x768 | inside | PASS | still INDUSINDBK on rotation#sd=banks&r=INDUSINDBK&y=70 |
| 19 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 288 -> 0 (max 649) |
| 20 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | inside | PASS | 0 -> 577 |
| 21 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1366x768 | inside | PASS | top 649 of max 649 (a page that snaps to whole rows may stop one row short) |
| 22 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1366x768 | inside | PASS | top 0 |
| 23 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 193 -> 0 |
| 24 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 25 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | inside | PASS | -> 200 -> 0 |
| 26 | pane scrollbar - thumb visible | F3 rotation | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 27 | W why + Esc | F3 rotation | 1366x768 | inside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 28 | Space plan card + Esc | F3 rotation | 1366x768 | inside | PASS | open True · after Esc False |
| 29 | pane button W why, then ✕ | F3 rotation | 1366x768 | inside | PASS | open True · closed True |
| 30 | pane button Space plan, then ✕ | F3 rotation | 1366x768 | inside | PASS | open True |
| 31 | P pin (toggle) | F3 rotation | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 32 | Pin toast sits above the action bar, below the share name | F3 rotation | 1366x768 | inside | PASS | toast 583-648 · action bar top 654 · name bottom 439 |
| 33 | Pin button (action bar) | F3 rotation | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 34 | Copy contract | F3 rotation | 1366x768 | inside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 35 | Copy button shows the size | F3 rotation | 1366x768 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 36 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 37 | December strikes only (rows + trade box) | F3 rotation | 1366x768 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 38 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1366x768 | inside | PASS | sector line True · pane True |
| 39 | ATM ★ only on a strike he could take | F3 rotation | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 40 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 41 | no repeated dashes; the reason shown once | F3 rotation | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 42 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1366x768 | inside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[418, 487], [387, 447], [387, 407], [387, 367], [387, 327], [387, 287]] |
| 43 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | inside | PASS | 240 -> 467 -> 240 (max 954) |
| 44 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | inside | PASS | 240 -> 694 |
| 45 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1366x768 | inside | PASS | top 929 of max 954 (a page that snaps to whole rows may stop one row short) |
| 46 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1366x768 | inside | PASS | top 0 |
| 47 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 339 -> 213 |
| 48 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | inside | PASS | -> 413 -> 213 |
| 49 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 50 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1366x768 | inside | PASS | rows 8 -> 22 -> 8 |
| 51 | basis › (the basis in full, R49) | F3 rotation | 1366x768 | inside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 52 | "n more listed, not F&O" fold line | F3 rotation | 1366x768 | inside | PASS | "▸ 12 more listed, not F&O · ▲7 ▼5 · wt 5% · context only, no strike" -> open, then closed |
| 53 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1366x768 | inside | PASS | went share?s=ICICIBANK · back: open banks, row ICICIBANK, expanded True |
| 54 | after Back, J still moves | F3 rotation | 1366x768 | inside | PASS | ICICIBANK -> BANKINDIA |
| 55 | O opens the option chain at the December strike; Back | F3 rotation | 1366x768 | inside | PASS | chain?s=BANKINDIA · back on BANKINDIA (no December contract in the store for any share of this sector now: the chain opens on the share, never a November strike) |
| 56 | double-click the pane share name -> F7, Back | F3 rotation | 1366x768 | inside | PASS | share?s=BANKINDIA |
| 57 | Enter on a share row -> F7 | F3 rotation | 1366x768 | inside | PASS | share?s=BANKINDIA |
| 58 | Esc closes step by step | F3 rotation | 1366x768 | inside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 59 | O / W with no share selected | F3 rotation | 1366x768 | inside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 60 | keys 1-9 pick a sector | F3 rotation | 1366x768 | inside | PASS | 3 -> cement & materials (row 3 = cement & materials) · 1 -> hospitals & diagnostics (row 1 = hospitals & diagnostics) |
| 61 | Tab to a sector row + Enter opens it | F3 rotation | 1366x768 | inside | PASS | focused hospitals & diagnostics after 2 Tab · open hospitals & diagnostics |
| 62 | R key (apply re-rank) | F3 rotation | 1366x768 | inside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 63 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1366x768 | inside | NOT RUN | needs live ticks: the market is closed (the store holds the close of today); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 64 | money-flow band: a sector name opens it in the table below | F3 rotation | 1366x768 | inside | PASS | clicked hospitals & diagnostics -> open hospitals & diagnostics, list visible True |
| 65 | "moving, but not this rotation" row opens that sector | F3 rotation | 1366x768 | inside | PASS | clicked realty -> open realty |
| 66 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1366x768 | inside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 67 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1366x768 | inside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 68 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1366x768 | inside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 69 | up-side shown: a rising sector shows CE strikes on its groups (a falling one PE) | F3 rotation | 1366x768 | inside | PASS | hospitals & diagnostics dir 1 · every row CE: True |
| 70 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F3 rotation | 1366x768 | inside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 242 |
| 71 | page errors | F3 rotation | 1366x768 | inside | PASS | none |
| 72 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | inside | PASS | 44 -> 298 -> 44 (max 754) |
| 73 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | inside | PASS | 44 -> 552 |
| 74 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | inside | PASS | top 754 of max 754 (a page that snaps to whole rows may stop one row short) |
| 75 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | inside | PASS | top 0 |
| 76 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 308 -> 0 |
| 77 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | inside | PASS | -> 200 -> 0 |
| 78 | F2 board scrollbar - thumb visible | F2 sectors | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 79 | F2 board row click opens the sector in place | F2 sectors | 1366x768 | inside | PASS | open auto · list bottom 640 · next row top 646 |
| 80 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1366x768 | inside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 81 | every visible share name - click loads the pane, the list stays | F2 sectors | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 82 | J through the whole list (pane follows) | F2 sectors | 1366x768 | inside | PASS | J x7 -> BOSCHLTD (last row BOSCHLTD) |
| 83 | K back up | F2 sectors | 1366x768 | inside | PASS | K x7 -> MARUTI |
| 84 | ↓ / ↑ move share to share | F2 sectors | 1366x768 | inside | PASS | ↓ BHARATFORG · ↑ MARUTI |
| 85 | J / K after a click in the pane | F2 sectors | 1366x768 | inside | PASS | J BHARATFORG · K MARUTI |
| 86 | pane share name - single click | F2 sectors | 1366x768 | inside | PASS | still MARUTI on sectors#sd=auto&r=MARUTI&y=840 |
| 87 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 154 -> 0 (max 529) |
| 88 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | inside | PASS | 0 -> 308 |
| 89 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | inside | PASS | top 529 of max 529 (a page that snaps to whole rows may stop one row short) |
| 90 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | inside | PASS | top 0 |
| 91 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 355 -> 0 |
| 92 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 93 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | inside | PASS | -> 200 -> 0 |
| 94 | pane scrollbar - thumb visible | F2 sectors | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 95 | W why + Esc | F2 sectors | 1366x768 | inside | PASS | open True · after Esc open False · share still MARUTI |
| 96 | Space plan card + Esc | F2 sectors | 1366x768 | inside | PASS | open True · after Esc False |
| 97 | pane button W why, then ✕ | F2 sectors | 1366x768 | inside | PASS | open True · closed True |
| 98 | pane button Space plan, then ✕ | F2 sectors | 1366x768 | inside | PASS | open True |
| 99 | P pin (toggle) | F2 sectors | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 100 | Pin toast sits above the action bar, below the share name | F2 sectors | 1366x768 | inside | PASS | toast 599-647 · action bar top 653 · name bottom 287 |
| 101 | Pin button (action bar) | F2 sectors | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 102 | Copy contract (clipboard only) | F2 sectors | 1366x768 | inside | PASS | clipboard "TMPV26DEC270CE" · button "Copy 270 CE · 0 lots" · toast "Copied TMPV26DEC270CE · 0 lots - you place the order in Kite" |
| 103 | Copy button shows the size | F2 sectors | 1366x768 | inside | PASS | Copy 270 CE · 0 lots |
| 104 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 105 | December strikes only (rows + trade box) | F2 sectors | 1366x768 | inside | PASS | 1 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False · December chain gap named once in the list |
| 106 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1366x768 | inside | PASS | sector line True · pane True |
| 107 | ATM ★ only on a strike he could take | F2 sectors | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 108 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 109 | no repeated dashes; the reason shown once | F2 sectors | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 110 | F2 heat-map tile opens that sector in the board | F2 sectors | 1366x768 | inside | PASS | tile hospitals & diagnostics -> open hospitals & diagnostics · in view True |
| 111 | F2: the share pane sits in the right column | F2 sectors | 1366x768 | inside | PASS | pane host #call |
| 112 | F2 keys 1-9 | F2 sectors | 1366x768 | inside | PASS | 2 -> banks (row 2 = banks) |
| 113 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F2 sectors | 1366x768 | inside | PASS | 19 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 212 |
| 114 | page errors | F2 sectors | 1366x768 | inside | PASS | none |
| 115 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1366x768 | inside | PASS | chip banks -> open banks |
| 116 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1366x768 | inside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 117 | every visible share name - click loads the pane, the list stays | F1 desk | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 118 | J through the whole list (pane follows) | F1 desk | 1366x768 | inside | PASS | J x7 -> FEDERALBNK (last row FEDERALBNK) |
| 119 | K back up | F1 desk | 1366x768 | inside | PASS | K x7 -> INDUSINDBK |
| 120 | ↓ / ↑ move share to share | F1 desk | 1366x768 | inside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 121 | J / K after a click in the pane | F1 desk | 1366x768 | inside | PASS | J BANDHANBNK · K INDUSINDBK |
| 122 | pane share name - single click | F1 desk | 1366x768 | inside | PASS | still INDUSINDBK on desk-hunt#sd=banks&r=INDUSINDBK&y=0 |
| 123 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 121 -> 0 (max 354) |
| 124 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1366x768 | inside | PASS | 0 -> 241 |
| 125 | pane scrollbar - drag past the end, off the rail | F1 desk | 1366x768 | inside | PASS | top 354 of max 354 (a page that snaps to whole rows may stop one row short) |
| 126 | pane scrollbar - drag past the top, off the rail | F1 desk | 1366x768 | inside | PASS | top 0 |
| 127 | pane scrollbar - track click below, then above the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 354 -> 0 |
| 128 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 129 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | inside | PASS | -> 200 -> 0 |
| 130 | pane scrollbar - thumb visible | F1 desk | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 131 | W why + Esc | F1 desk | 1366x768 | inside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 132 | Space plan card + Esc | F1 desk | 1366x768 | inside | PASS | open True · after Esc False |
| 133 | pane button W why, then ✕ | F1 desk | 1366x768 | inside | PASS | open True · closed True |
| 134 | pane button Space plan, then ✕ | F1 desk | 1366x768 | inside | PASS | open True |
| 135 | P pin (toggle) | F1 desk | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 136 | Pin toast sits above the action bar, below the share name | F1 desk | 1366x768 | inside | PASS | toast 629-677 · action bar top 683 · name bottom 289 |
| 137 | Pin button (action bar) | F1 desk | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 138 | Copy contract | F1 desk | 1366x768 | inside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 139 | Copy button shows the size | F1 desk | 1366x768 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 140 | signal only: no order / buy button, the Kite line shown | F1 desk | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 141 | December strikes only (rows + trade box) | F1 desk | 1366x768 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 142 | "Expiry week · physical settlement - December only" warning | F1 desk | 1366x768 | inside | PASS | sector line True · pane True |
| 143 | ATM ★ only on a strike he could take | F1 desk | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 144 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 145 | no repeated dashes; the reason shown once | F1 desk | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 146 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 99 -> 0 (max 287) |
| 147 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1366x768 | inside | PASS | 0 -> 198 |
| 148 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1366x768 | inside | PASS | top 287 of max 287 (a page that snaps to whole rows may stop one row short) |
| 149 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1366x768 | inside | PASS | top 0 |
| 150 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 287 -> 0 |
| 151 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 152 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | inside | PASS | -> 200 -> 0 |
| 153 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 154 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F1 desk | 1366x768 | inside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 755 |
| 155 | F1 Esc closes back to the Desk | F1 desk | 1366x768 | inside | PASS | open None · members panel back |
| 156 | page errors | F1 desk | 1366x768 | inside | PASS | none |
| 157 | Morning sector card opens the same component | Morning | 1366x768 | inside | PASS | card realty -> open realty |
| 158 | Morning: "pre-open - not live" (after 15:30 "closed - not live") with the session date | Morning | 1366x768 | inside | PASS | ['closed - not live · 20 Nov 15:30 close', True, True] |
| 159 | every visible share name - click loads the pane, the list stays | Morning | 1366x768 | inside | PASS | 6 names clicked, wrong: [] · list visible: True |
| 160 | J through the whole list (pane follows) | Morning | 1366x768 | inside | PASS | J x5 -> LODHA (last row LODHA) |
| 161 | K back up | Morning | 1366x768 | inside | PASS | K x5 -> GODREJPROP |
| 162 | ↓ / ↑ move share to share | Morning | 1366x768 | inside | PASS | ↓ DLF · ↑ GODREJPROP |
| 163 | J / K after a click in the pane | Morning | 1366x768 | inside | PASS | J DLF · K GODREJPROP |
| 164 | pane share name - single click | Morning | 1366x768 | inside | PASS | still GODREJPROP on morning#sd=realty&r=GODREJPROP&y=0 |
| 165 | pane scrollbar - slow mouse drag of the thumb | Morning | 1366x768 | inside | PASS | 0 -> 190 -> 0 (max 570) |
| 166 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1366x768 | inside | PASS | 0 -> 380 |
| 167 | pane scrollbar - drag past the end, off the rail | Morning | 1366x768 | inside | PASS | top 570 of max 570 (a page that snaps to whole rows may stop one row short) |
| 168 | pane scrollbar - drag past the top, off the rail | Morning | 1366x768 | inside | PASS | top 0 |
| 169 | pane scrollbar - track click below, then above the thumb | Morning | 1366x768 | inside | PASS | 0 -> 282 -> 0 |
| 170 | pane scrollbar - ▼ then ▲ buttons | Morning | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 171 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1366x768 | inside | PASS | -> 200 -> 0 |
| 172 | pane scrollbar - thumb visible | Morning | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 173 | W why + Esc | Morning | 1366x768 | inside | PASS | open True · after Esc open False · share still GODREJPROP |
| 174 | Space plan card + Esc | Morning | 1366x768 | inside | PASS | open True · after Esc False |
| 175 | pane button W why, then ✕ | Morning | 1366x768 | inside | PASS | open True · closed True |
| 176 | pane button Space plan, then ✕ | Morning | 1366x768 | inside | PASS | open True |
| 177 | P pin (toggle) | Morning | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 178 | Pin toast sits above the action bar, below the share name | Morning | 1366x768 | inside | PASS | toast 582-647 · action bar top 653 · name bottom 368 |
| 179 | Pin button (action bar) | Morning | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 180 | Copy contract | Morning | 1366x768 | inside | PASS | Copy off for GODREJPROP (oc.GODREJPROP.rows2 (the next-month chain) not in the store) - disabled |
| 181 | Copy button shows the size | Morning | 1366x768 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 182 | signal only: no order / buy button, the Kite line shown | Morning | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 183 | December strikes only (rows + trade box) | Morning | 1366x768 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 184 | "Expiry week · physical settlement - December only" warning | Morning | 1366x768 | inside | PASS | sector line True · pane True |
| 185 | ATM ★ only on a strike he could take | Morning | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 186 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 187 | no repeated dashes; the reason shown once | Morning | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 188 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | Morning | 1366x768 | inside | PASS | 3 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 3 |
| 189 | page errors | Morning | 1366x768 | inside | PASS | none |
| 190 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 156 -> 0 (max 592) |
| 191 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 0 -> 313 |
| 192 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 578 of max 592 (a page that snaps to whole rows may stop one row short) |
| 193 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 194 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 283 -> 147 |
| 195 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1600x900 | inside | PASS | 147 -> 259 -> 148 |
| 196 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 348 -> 148 |
| 197 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 198 | F3 table row click opens the sector | F3 rotation | 1600x900 | inside | PASS | open banks in 14 ms (from the cached store) |
| 199 | opens under 100 ms | F3 rotation | 1600x900 | inside | PASS | 14 ms |
| 200 | the open list pushes the rows below (no overprint) | F3 rotation | 1600x900 | inside | PASS | list bottom 855 · next sector row top 861 |
| 201 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1600x900 | inside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 202 | every visible share name - click loads the pane, the list stays | F3 rotation | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 203 | J through the whole list (pane follows) | F3 rotation | 1600x900 | inside | PASS | J x11 -> BANKINDIA (last row BANKINDIA) |
| 204 | K back up | F3 rotation | 1600x900 | inside | PASS | K x11 -> INDUSINDBK |
| 205 | ↓ / ↑ move share to share | F3 rotation | 1600x900 | inside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 206 | J / K after a click in the pane | F3 rotation | 1600x900 | inside | PASS | J BANDHANBNK · K INDUSINDBK |
| 207 | pane share name - single click | F3 rotation | 1600x900 | inside | PASS | still INDUSINDBK on rotation#sd=banks&r=INDUSINDBK&y=76 |
| 208 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 128 -> 0 (max 378) |
| 209 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 0 -> 256 |
| 210 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 378 of max 378 (a page that snaps to whole rows may stop one row short) |
| 211 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 212 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 356 -> 1 |
| 213 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1600x900 | inside | PASS | 1 -> 67 -> 1 |
| 214 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 201 -> 1 |
| 215 | pane scrollbar - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 216 | W why + Esc | F3 rotation | 1600x900 | inside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 217 | Space plan card + Esc | F3 rotation | 1600x900 | inside | PASS | open True · after Esc False |
| 218 | pane button W why, then ✕ | F3 rotation | 1600x900 | inside | PASS | open True · closed True |
| 219 | pane button Space plan, then ✕ | F3 rotation | 1600x900 | inside | PASS | open True |
| 220 | P pin (toggle) | F3 rotation | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 221 | Pin toast sits above the action bar, below the share name | F3 rotation | 1600x900 | inside | PASS | toast 761-809 · action bar top 815 · name bottom 419 |
| 222 | Pin button (action bar) | F3 rotation | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 223 | Copy contract | F3 rotation | 1600x900 | inside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 224 | Copy button shows the size | F3 rotation | 1600x900 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 225 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 226 | December strikes only (rows + trade box) | F3 rotation | 1600x900 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 227 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1600x900 | inside | PASS | sector line True · pane True |
| 228 | ATM ★ only on a strike he could take | F3 rotation | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 229 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 230 | no repeated dashes; the reason shown once | F3 rotation | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 231 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1600x900 | inside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[424, 493], [387, 453], [387, 413], [387, 373], [387, 333], [387, 293]] |
| 232 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 240 -> 425 -> 240 (max 981) |
| 233 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 240 -> 609 |
| 234 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 957 of max 981 (a page that snaps to whole rows may stop one row short) |
| 235 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 236 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 390 -> 235 |
| 237 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 435 -> 235 |
| 238 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 239 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1600x900 | inside | PASS | rows 12 -> 22 -> 12 |
| 240 | basis › (the basis in full, R49) | F3 rotation | 1600x900 | inside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 241 | "n more listed, not F&O" fold line | F3 rotation | 1600x900 | inside | PASS | "▸ 12 more listed, not F&O · ▲7 ▼5 · wt 5% · context only, no strike" -> open, then closed |
| 242 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1600x900 | inside | PASS | went share?s=ICICIBANK · back: open banks, row ICICIBANK, expanded True |
| 243 | after Back, J still moves | F3 rotation | 1600x900 | inside | PASS | ICICIBANK -> BANKINDIA |
| 244 | O opens the option chain at the December strike; Back | F3 rotation | 1600x900 | inside | PASS | chain?s=BANKINDIA · back on BANKINDIA (no December contract in the store for any share of this sector now: the chain opens on the share, never a November strike) |
| 245 | double-click the pane share name -> F7, Back | F3 rotation | 1600x900 | inside | PASS | share?s=BANKINDIA |
| 246 | Enter on a share row -> F7 | F3 rotation | 1600x900 | inside | PASS | share?s=BANKINDIA |
| 247 | Esc closes step by step | F3 rotation | 1600x900 | inside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 248 | O / W with no share selected | F3 rotation | 1600x900 | inside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 249 | keys 1-9 pick a sector | F3 rotation | 1600x900 | inside | PASS | 3 -> cement & materials (row 3 = cement & materials) · 1 -> hospitals & diagnostics (row 1 = hospitals & diagnostics) |
| 250 | Tab to a sector row + Enter opens it | F3 rotation | 1600x900 | inside | PASS | focused hospitals & diagnostics after 3 Tab · open hospitals & diagnostics |
| 251 | R key (apply re-rank) | F3 rotation | 1600x900 | inside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 252 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1600x900 | inside | NOT RUN | needs live ticks: the market is closed (the store holds the close of today); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 253 | money-flow band: a sector name opens it in the table below | F3 rotation | 1600x900 | inside | PASS | clicked hospitals & diagnostics -> open hospitals & diagnostics, list visible True |
| 254 | "moving, but not this rotation" row opens that sector | F3 rotation | 1600x900 | inside | PASS | clicked realty -> open realty |
| 255 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1600x900 | inside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 256 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1600x900 | inside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 257 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1600x900 | inside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 258 | up-side shown: a rising sector shows CE strikes on its groups (a falling one PE) | F3 rotation | 1600x900 | inside | PASS | hospitals & diagnostics dir 1 · every row CE: True |
| 259 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F3 rotation | 1600x900 | inside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 187 |
| 260 | page errors | F3 rotation | 1600x900 | inside | PASS | none |
| 261 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | inside | PASS | 44 -> 203 -> 43 (max 622) |
| 262 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | inside | PASS | 43 -> 363 |
| 263 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | inside | PASS | top 589 of max 622 (a page that snaps to whole rows may stop one row short) |
| 264 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | inside | PASS | top 0 |
| 265 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 559 -> 0 |
| 266 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | inside | PASS | -> 200 -> 0 |
| 267 | F2 board scrollbar - thumb visible | F2 sectors | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 268 | F2 board row click opens the sector in place | F2 sectors | 1600x900 | inside | PASS | open auto · list bottom 776 · next row top 782 |
| 269 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1600x900 | inside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 270 | every visible share name - click loads the pane, the list stays | F2 sectors | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 271 | J through the whole list (pane follows) | F2 sectors | 1600x900 | inside | PASS | J x11 -> HEROMOTOCO (last row HEROMOTOCO) |
| 272 | K back up | F2 sectors | 1600x900 | inside | PASS | K x11 -> MARUTI |
| 273 | ↓ / ↑ move share to share | F2 sectors | 1600x900 | inside | PASS | ↓ BHARATFORG · ↑ MARUTI |
| 274 | J / K after a click in the pane | F2 sectors | 1600x900 | inside | PASS | J BHARATFORG · K MARUTI |
| 275 | pane share name - single click | F2 sectors | 1600x900 | inside | PASS | still MARUTI on sectors#sd=auto&r=MARUTI&y=785 |
| 276 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 102 -> 0 (max 308) |
| 277 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | inside | PASS | 0 -> 203 |
| 278 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | inside | PASS | top 308 of max 308 (a page that snaps to whole rows may stop one row short) |
| 279 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | inside | PASS | top 0 |
| 280 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 308 -> 0 |
| 281 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 282 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | inside | PASS | -> 200 -> 0 |
| 283 | pane scrollbar - thumb visible | F2 sectors | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 284 | W why + Esc | F2 sectors | 1600x900 | inside | PASS | open True · after Esc open False · share still MARUTI |
| 285 | Space plan card + Esc | F2 sectors | 1600x900 | inside | PASS | open True · after Esc False |
| 286 | pane button W why, then ✕ | F2 sectors | 1600x900 | inside | PASS | open True · closed True |
| 287 | pane button Space plan, then ✕ | F2 sectors | 1600x900 | inside | PASS | open True |
| 288 | P pin (toggle) | F2 sectors | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 289 | Pin toast sits above the action bar, below the share name | F2 sectors | 1600x900 | inside | PASS | toast 760-808 · action bar top 814 · name bottom 288 |
| 290 | Pin button (action bar) | F2 sectors | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 291 | Copy contract (clipboard only) | F2 sectors | 1600x900 | inside | PASS | clipboard "TMPV26DEC270CE" · button "Copy 270 CE · 0 lots" · toast "Copied TMPV26DEC270CE · 0 lots - you place the order in Kite" |
| 292 | Copy button shows the size | F2 sectors | 1600x900 | inside | PASS | Copy 270 CE · 0 lots |
| 293 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 294 | December strikes only (rows + trade box) | F2 sectors | 1600x900 | inside | PASS | 1 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False · December chain gap named once in the list |
| 295 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1600x900 | inside | PASS | sector line True · pane True |
| 296 | ATM ★ only on a strike he could take | F2 sectors | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 297 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 298 | no repeated dashes; the reason shown once | F2 sectors | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 299 | F2 heat-map tile opens that sector in the board | F2 sectors | 1600x900 | inside | PASS | tile hospitals & diagnostics -> open hospitals & diagnostics · in view True |
| 300 | F2: the share pane sits in the right column | F2 sectors | 1600x900 | inside | PASS | pane host #call |
| 301 | F2 keys 1-9 | F2 sectors | 1600x900 | inside | PASS | 2 -> banks (row 2 = banks) |
| 302 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F2 sectors | 1600x900 | inside | PASS | 19 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 353 |
| 303 | page errors | F2 sectors | 1600x900 | inside | PASS | none |
| 304 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1600x900 | inside | PASS | chip banks -> open banks |
| 305 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1600x900 | inside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 306 | every visible share name - click loads the pane, the list stays | F1 desk | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 307 | J through the whole list (pane follows) | F1 desk | 1600x900 | inside | PASS | J x11 -> BANKINDIA (last row BANKINDIA) |
| 308 | K back up | F1 desk | 1600x900 | inside | PASS | K x11 -> INDUSINDBK |
| 309 | ↓ / ↑ move share to share | F1 desk | 1600x900 | inside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 310 | J / K after a click in the pane | F1 desk | 1600x900 | inside | PASS | J BANDHANBNK · K INDUSINDBK |
| 311 | pane share name - single click | F1 desk | 1600x900 | inside | PASS | still INDUSINDBK on desk-hunt#sd=banks&r=INDUSINDBK&y=0 |
| 312 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 88 -> 0 (max 207) |
| 313 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1600x900 | inside | PASS | 0 -> 176 |
| 314 | pane scrollbar - drag past the end, off the rail | F1 desk | 1600x900 | inside | PASS | top 207 of max 207 (a page that snaps to whole rows may stop one row short) |
| 315 | pane scrollbar - drag past the top, off the rail | F1 desk | 1600x900 | inside | PASS | top 0 |
| 316 | pane scrollbar - track click below, then above the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 207 -> 0 |
| 317 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 318 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | inside | PASS | -> 200 -> 0 |
| 319 | pane scrollbar - thumb visible | F1 desk | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 320 | W why + Esc | F1 desk | 1600x900 | inside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 321 | Space plan card + Esc | F1 desk | 1600x900 | inside | PASS | open True · after Esc False |
| 322 | pane button W why, then ✕ | F1 desk | 1600x900 | inside | PASS | open True · closed True |
| 323 | pane button Space plan, then ✕ | F1 desk | 1600x900 | inside | PASS | open True |
| 324 | P pin (toggle) | F1 desk | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 325 | Pin toast sits above the action bar, below the share name | F1 desk | 1600x900 | inside | PASS | toast 761-809 · action bar top 815 · name bottom 268 |
| 326 | Pin button (action bar) | F1 desk | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 327 | Copy contract | F1 desk | 1600x900 | inside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 328 | Copy button shows the size | F1 desk | 1600x900 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 329 | signal only: no order / buy button, the Kite line shown | F1 desk | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 330 | December strikes only (rows + trade box) | F1 desk | 1600x900 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 331 | "Expiry week · physical settlement - December only" warning | F1 desk | 1600x900 | inside | PASS | sector line True · pane True |
| 332 | ATM ★ only on a strike he could take | F1 desk | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 333 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 334 | no repeated dashes; the reason shown once | F1 desk | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 335 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 79 -> 0 (max 159) |
| 336 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1600x900 | inside | PASS | 0 -> 158 |
| 337 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1600x900 | inside | PASS | top 159 of max 159 (a page that snaps to whole rows may stop one row short) |
| 338 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1600x900 | inside | PASS | top 0 |
| 339 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 159 -> 0 |
| 340 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 341 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | inside | PASS | -> 159 -> 0 |
| 342 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 343 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F1 desk | 1600x900 | inside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 728 |
| 344 | F1 Esc closes back to the Desk | F1 desk | 1600x900 | inside | PASS | open None · members panel back |
| 345 | page errors | F1 desk | 1600x900 | inside | PASS | none |
| 346 | Morning sector card opens the same component | Morning | 1600x900 | inside | PASS | card realty -> open realty |
| 347 | Morning: "pre-open - not live" (after 15:30 "closed - not live") with the session date | Morning | 1600x900 | inside | PASS | ['closed - not live · 20 Nov 15:30 close', True, True] |
| 348 | every visible share name - click loads the pane, the list stays | Morning | 1600x900 | inside | PASS | 6 names clicked, wrong: [] · list visible: True |
| 349 | J through the whole list (pane follows) | Morning | 1600x900 | inside | PASS | J x5 -> LODHA (last row LODHA) |
| 350 | K back up | Morning | 1600x900 | inside | PASS | K x5 -> GODREJPROP |
| 351 | ↓ / ↑ move share to share | Morning | 1600x900 | inside | PASS | ↓ DLF · ↑ GODREJPROP |
| 352 | J / K after a click in the pane | Morning | 1600x900 | inside | PASS | J DLF · K GODREJPROP |
| 353 | pane share name - single click | Morning | 1600x900 | inside | PASS | still GODREJPROP on morning#sd=realty&r=GODREJPROP&y=0 |
| 354 | pane scrollbar - slow mouse drag of the thumb | Morning | 1600x900 | inside | PASS | 0 -> 154 -> 0 (max 439) |
| 355 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1600x900 | inside | PASS | 0 -> 308 |
| 356 | pane scrollbar - drag past the end, off the rail | Morning | 1600x900 | inside | PASS | top 439 of max 439 (a page that snaps to whole rows may stop one row short) |
| 357 | pane scrollbar - drag past the top, off the rail | Morning | 1600x900 | inside | PASS | top 0 |
| 358 | pane scrollbar - track click below, then above the thumb | Morning | 1600x900 | inside | PASS | 0 -> 302 -> 0 |
| 359 | pane scrollbar - ▼ then ▲ buttons | Morning | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 360 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1600x900 | inside | PASS | -> 200 -> 0 |
| 361 | pane scrollbar - thumb visible | Morning | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 362 | W why + Esc | Morning | 1600x900 | inside | PASS | open True · after Esc open False · share still GODREJPROP |
| 363 | Space plan card + Esc | Morning | 1600x900 | inside | PASS | open True · after Esc False |
| 364 | pane button W why, then ✕ | Morning | 1600x900 | inside | PASS | open True · closed True |
| 365 | pane button Space plan, then ✕ | Morning | 1600x900 | inside | PASS | open True |
| 366 | P pin (toggle) | Morning | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 367 | Pin toast sits above the action bar, below the share name | Morning | 1600x900 | inside | PASS | toast 760-808 · action bar top 814 · name bottom 477 |
| 368 | Pin button (action bar) | Morning | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 369 | Copy contract | Morning | 1600x900 | inside | PASS | Copy off for GODREJPROP (oc.GODREJPROP.rows2 (the next-month chain) not in the store) - disabled |
| 370 | Copy button shows the size | Morning | 1600x900 | inside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 371 | signal only: no order / buy button, the Kite line shown | Morning | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 372 | December strikes only (rows + trade box) | Morning | 1600x900 | inside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 373 | "Expiry week · physical settlement - December only" warning | Morning | 1600x900 | inside | PASS | sector line True · pane True |
| 374 | ATM ★ only on a strike he could take | Morning | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 375 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 376 | no repeated dashes; the reason shown once | Morning | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 377 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | Morning | 1600x900 | inside | PASS | 3 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 3 |
| 378 | page errors | Morning | 1600x900 | inside | PASS | none |
| 379 | tap a sector row opens the full-screen list sheet | F3 rotation | 390x844 | inside | PASS | open banks · built in 35 ms · tap-to-sheet 117 ms |
| 380 | sheet header (sector line) <= 2 lines + WHY | F3 rotation | 390x844 | inside | PASS | line 1 46 px, whole header 179 px |
| 381 | sheet rail size (touch target >= 24, track and thumb >= 10) | F3 rotation | 390x844 | inside | PASS | target 26 · track 13 · thumb 13 px |
| 382 | list sheet - finger swipe | F3 rotation | 390x844 | inside | PASS | 0 -> 446 -> 189 |
| 383 | list sheet - rail thumb, finger drag | F3 rotation | 390x844 | inside | PASS | 189 -> 415 · share opened: None |
| 384 | list sheet - rail drag, 8 px contact | F3 rotation | 390x844 | inside | PASS | 415 -> 189 |
| 385 | list sheet - rail drag at its right edge | F3 rotation | 390x844 | inside | PASS | 189 -> 377 |
| 386 | list sheet - rail track tap | F3 rotation | 390x844 | inside | PASS | 377 -> 311 |
| 387 | list sheet - rail, mouse drag (one mouse check) | F3 rotation | 390x844 | inside | PASS | 311 -> 462 |
| 388 | fast flick, then a tap still opens the row | F3 rotation | 390x844 | inside | PASS | flick then tap BANKINDIA -> share sheet True (BANKINDIA) |
| 389 | "n more listed, not F&O" (finger) | F3 rotation | 390x844 | inside | PASS | open True · closed True |
| 390 | basis › (finger) | F3 rotation | 390x844 | inside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 391 | tap a share opens the share sheet | F3 rotation | 390x844 | inside | PASS | INDUSINDBK -> sheet True |
| 392 | share sheet - finger swipe | F3 rotation | 390x844 | inside | PASS | 0 -> 113 |
| 393 | share sheet - action bar sticky, shows the size | F3 rotation | 390x844 | inside | PASS | bar 733-844 at scroll 0 and 733-844 after the swipe · "Copy contract · 0 lots" |
| 394 | share sheet - rail thumb, finger drag | F3 rotation | 390x844 | inside | PASS | 0 -> 113 |
| 395 | share sheet - rail track tap | F3 rotation | 390x844 | inside | PASS | 113 -> 47 |
| 396 | WHY › (share sheet) | F3 rotation | 390x844 | inside | PASS | open True · closed True |
| 397 | Copy contract (finger, first view) | F3 rotation | 390x844 | inside | PASS | Copy off: oc.INDUSINDBK.rows2 (the next-month chain) not in the store |
| 398 | Pin (toggle, n/5) (finger) | F3 rotation | 390x844 | inside | PASS | 0 -> 1 -> 0 |
| 399 | Pin toast above the action bar, not over the share name | F3 rotation | 390x844 | inside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 400 | ‹ Sector (Back button on the share sheet) | F3 rotation | 390x844 | inside | PASS | list sheet True · share sheet False |
| 401 | device / browser Back (share sheet -> list) | F3 rotation | 390x844 | inside | PASS | list True · share False |
| 402 | device / browser Back (list -> page) | F3 rotation | 390x844 | inside | PASS | sheet False · open None |
| 403 | ‹ Sectors (Back button on the list sheet) | F3 rotation | 390x844 | inside | PASS | sheet closed True |
| 404 | page errors | F3 rotation | 390x844 | inside | PASS | none |
| 405 | tap a sector row opens the full-screen list sheet | F2 sectors | 390x844 | inside | PASS | open banks · built in 26 ms · tap-to-sheet 97 ms |
| 406 | sheet header (sector line) <= 2 lines + WHY | F2 sectors | 390x844 | inside | PASS | line 1 46 px, whole header 179 px |
| 407 | sheet rail size (touch target >= 24, track and thumb >= 10) | F2 sectors | 390x844 | inside | PASS | target 26 · track 13 · thumb 13 px |
| 408 | list sheet - finger swipe | F2 sectors | 390x844 | inside | PASS | 0 -> 425 -> 171 |
| 409 | list sheet - rail thumb, finger drag | F2 sectors | 390x844 | inside | PASS | 171 -> 397 · share opened: None |
| 410 | list sheet - rail drag, 8 px contact | F2 sectors | 390x844 | inside | PASS | 397 -> 171 |
| 411 | list sheet - rail drag at its right edge | F2 sectors | 390x844 | inside | PASS | 171 -> 359 |
| 412 | list sheet - rail track tap | F2 sectors | 390x844 | inside | PASS | 359 -> 293 |
| 413 | list sheet - rail, mouse drag (one mouse check) | F2 sectors | 390x844 | inside | PASS | 293 -> 444 |
| 414 | fast flick, then a tap still opens the row | F2 sectors | 390x844 | inside | PASS | flick then tap BANKINDIA -> share sheet True (BANKINDIA) |
| 415 | "n more listed, not F&O" (finger) | F2 sectors | 390x844 | inside | PASS | open True · closed True |
| 416 | basis › (finger) | F2 sectors | 390x844 | inside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 417 | tap a share opens the share sheet | F2 sectors | 390x844 | inside | PASS | INDUSINDBK -> sheet True |
| 418 | share sheet - finger swipe | F2 sectors | 390x844 | inside | PASS | 0 -> 70 |
| 419 | share sheet - action bar sticky, shows the size | F2 sectors | 390x844 | inside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy contract · 0 lots" |
| 420 | share sheet - rail thumb, finger drag | F2 sectors | 390x844 | inside | PASS | 0 -> 70 |
| 421 | share sheet - rail track tap | F2 sectors | 390x844 | inside | PASS | 70 -> 4 |
| 422 | WHY › (share sheet) | F2 sectors | 390x844 | inside | PASS | open True · closed True |
| 423 | Copy contract (finger, first view) | F2 sectors | 390x844 | inside | PASS | Copy off: oc.INDUSINDBK.rows2 (the next-month chain) not in the store |
| 424 | Pin (toggle, n/5) (finger) | F2 sectors | 390x844 | inside | PASS | 0 -> 1 -> 0 |
| 425 | Pin toast above the action bar, not over the share name | F2 sectors | 390x844 | inside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 426 | ‹ Sector (Back button on the share sheet) | F2 sectors | 390x844 | inside | PASS | list sheet True · share sheet False |
| 427 | device / browser Back (share sheet -> list) | F2 sectors | 390x844 | inside | PASS | list True · share False |
| 428 | device / browser Back (list -> page) | F2 sectors | 390x844 | inside | PASS | sheet False · open None |
| 429 | ‹ Sectors (Back button on the list sheet) | F2 sectors | 390x844 | inside | PASS | sheet closed True |
| 430 | page errors | F2 sectors | 390x844 | inside | PASS | none |
| 431 | six groups only | shared module (F3 page) | rules | inside | PASS | 226 members in 26 sectors · bad:  |
| 432 | COMING UP = 4 gates and not EXTENDED | shared module (F3 page) | rules | inside | PASS | MFSL ADANIPOWER NATIONALUM INOXWIND |
| 433 | COMING UP score (on 0.60 / off 0.45) | shared module (F3 page) | rules | inside | PASS |  |
| 434 | EXTENDED rule | shared module (F3 page) | rules | inside | PASS | 40 extended |
| 435 | LAGGARD only at breadth >= 70% | shared module (F3 page) | rules | inside | PASS | laggards: BANDHANBNK ABB SUPREMEIND ASTRAL |
| 436 | "no laggard" sectors | shared module (F3 page) | rules | inside | PASS | realty 65%, it 56%, electronics & hardware 56%, insurance 67%, nbfc & finance 42%, services 38%, consumer services 44%, capital markets 56%, fmcg 39%, power 33%, metals & mining 64%, telecom services 25%, oil & gas 58%, construction 61%, pharma 45%, auto 38%, consumer durables 62%, chemicals 32% |
| 437 | one LEADER per sector | shared module (F3 page) | rules | inside | PASS |  |
| 438 | LEADER group = extended or a gate fails | shared module (F3 page) | rules | inside | PASS |  |
| 439 | AGAINST rule | shared module (F3 page) | rules | inside | PASS | UJJIVANSFB KARURVYSYA OFSS KPITTECH SYRMA GRASIM SHRIRAMFIN RECLTD MUTHOOTFIN MANAPPURAM IRFC LTF JIOFIN CONCOR ETERNAL DMART SWIGGY NAM-INDIA MOTILALOFS MCX ITC GODFRYPHLP HINDUNILVR GODREJCP COLPAL NTPC IEX NMDC HINDALCO JINDALSTEL INDUSTOWER OIL COALINDIA GAIL PETRONET ONGC NBCC CIPLA ZYDUSLIFE AUROPHARMA LAURUSLABS SUNPHARMA DRREDDY BAJAJ-AUTO TIINDIA FORCEMOT ASHOKLEY SONACOMS ASIANPAINT BLUESTARCO HAVELLS CROMPTON SOLARINDS NAVINFLUOR PIIND SUZLON KEI POLYCAB BDL WAAREEENER HAL PREMIERENE |
| 440 | LAGGARD shows its trigger price | shared module (F3 page) | rules | inside | PASS |  |
| 441 | CE on a rising sector, PE on a falling one (AGAINST flips) | shared module (F3 page) | rules | inside | PASS |  |
| 442 | December strikes only | shared module (F3 page) | rules | inside | PASS | not December: none · no December chain: APOLLOHOSP MAXHEALTH FORTIS INDUSINDBK BANDHANBNK CUB AXISBANK HDFCBANK UNIONBANK KOTAKBANK FEDERALBNK RBLBANK CANBK ICICIBANK BANKINDIA MAHABANK IDFCFIRSTB BANKBARODA YESBANK SBIN INDIANB PNB AUBANK UJJIVANSFB KARURVYSYA GODREJPROP DLF PHOENIXLTD OBEROIRLTY PRESTIGE LODHA PIDILITIND INDIGO BPCL IOC HINDPETRO ASIANPAINT PERSISTENT TATAELXSI MPHASIS COFORGE LTM TCS TECHM WIPRO HCLTECH SAGILITY INFY OFSS KPITTECH DATAPATTNS PGEL AMBER DIXON SYRMA KAYNES MFSL ICICIGI HDFCLIFE LICI SBILIFE ICICILIFE BAJAJFINSV ULTRACEMCO SHREECEM AMBUJACEM GRASIM HAVELLS POLYCAB KEI PNBHOUSING IREDA BAJFINANCE SBICARD LICHSGFIN PAYTM POLICYBZR CHOLAFIN PFC SHRIRAMFIN RECLTD IRFC LTF JIOFIN INDIGO GMRAIRPORT DELHIVERY CONCOR INDHOTEL NYKAA NAUKRI TRENT JUBLFOOD VMM ETERNAL DMART SWIGGY ANGELONE CAMS CDSL BSE HDFCAMC ANANDRATHI KFINTECH NAM-INDIA MOTILALOFS MCX VBL NESTLEIND TATACONSUM BRITANNIA DABUR UNITDSPR PATANJALI RADICO MARICO ITC GODFRYPHLP HINDUNILVR GODREJCP COLPAL POWERGRID NHPC TATAPOWER JSWENERGY NTPC IEX NATIONALUM VEDL APLAPOLLO HINDZINC TATASTEEL SAIL JSWSTEEL NMDC HINDALCO JINDALSTEL BHARTIARTL IDEA INDUSTOWER BPCL IOC HINDPETRO RELIANCE OIL COALINDIA GAIL PETRONET ONGC LT NBCC TORNTPHARM MANKIND GLENMARK LUPIN BIOCON DIVISLAB CIPLA ZYDUSLIFE AUROPHARMA LAURUSLABS SUNPHARMA DRREDDY MARUTI BHARATFORG M&M EICHERMOT MOTHERSON ATHERENERG BOSCHLTD UNOMINDA HYUNDAI TVSMOTOR HEROMOTOCO BAJAJ-AUTO TIINDIA FORCEMOT ASHOKLEY SONACOMS TITAN ASIANPAINT BLUESTARCO HAVELLS CROMPTON PIDILITIND COROMANDEL UPL SRF SOLARINDS NAVINFLUOR PIIND INOXWIND SUPREMEIND ASTRAL CGPOWER ENRIN GVT&D POWERINDIA COCHINSHIP SIEMENS CUMMINSIND MAZDOCK BEL BHEL SUZLON KEI POLYCAB BDL WAAREEENER HAL PREMIERENE |
| 443 | pre-open now: 0 lots everywhere | shared module (F3 page) | rules | inside | PASS | 0 lots · closed - not live |
| 444 | BAN hard block | shared module (F3 page) | rules | inside | PASS | KAYNES nt BAN - only close existing |
| 445 | STALE hard block | shared module (F3 page) | rules | inside | PASS | 0 stale now |
| 446 | what-if live: R:R < 1 after costs -> 0 lots | shared module (F3 page) | rules | inside | PASS | 12 plans held at 0 lots by R:R |
| 447 | what-if live: one lot above 1R -> 0 lots | shared module (F3 page) | rules | inside | PASS | 0 plans held at 0 lots by 1R |
| 448 | what-if live: WAITING / NOT TRADABLE -> 0 lots | shared module (F3 page) | rules | inside | PASS |  |
| 449 | what-if live: the star / takeable follows the lots | shared module (F3 page) | rules | inside | PASS | none takeable |
| 450 | what-if live: lots fit the lock room | shared module (F3 page) | rules | inside | PASS |  |
| 451 | what-if: LOCKED blocks every new trade | shared module (F3 page) | rules | inside | PASS | 226 plans · LOCKED - no new trades today |
| 452 | non-F&O fold counts from all listed | shared module (F3 page) | rules | inside | PASS | hospitals & diagnostics 12 · banks 12 · realty 11 · oil marketers, paints, airlines 1 · it 26 · electronics & hardware 3 |
| 453 | basis named (R49) | shared module (F3 page) | rules | inside | PASS | whole sector: 15 listed shares · whole sector: 34 listed shares |
| 454 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 205 -> 1 (max 612) |
| 455 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 1 -> 410 |
| 456 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 612 of max 612 (a page that snaps to whole rows may stop one row short) |
| 457 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 458 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 267 -> 159 |
| 459 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1366x768 | outside | PASS | 159 -> 272 -> 170 |
| 460 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 370 -> 170 |
| 461 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 462 | F3 table row click opens the sector | F3 rotation | 1366x768 | outside | PASS | open banks in 13 ms (from the cached store) |
| 463 | opens under 100 ms | F3 rotation | 1366x768 | outside | PASS | 13 ms |
| 464 | the open list pushes the rows below (no overprint) | F3 rotation | 1366x768 | outside | PASS | list bottom 774 · next sector row top 780 |
| 465 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1366x768 | outside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 466 | every visible share name - click loads the pane, the list stays | F3 rotation | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 467 | J through the whole list (pane follows) | F3 rotation | 1366x768 | outside | PASS | J x7 -> FEDERALBNK (last row FEDERALBNK) |
| 468 | K back up | F3 rotation | 1366x768 | outside | PASS | K x7 -> INDUSINDBK |
| 469 | ↓ / ↑ move share to share | F3 rotation | 1366x768 | outside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 470 | J / K after a click in the pane | F3 rotation | 1366x768 | outside | PASS | J BANDHANBNK · K INDUSINDBK |
| 471 | pane share name - single click | F3 rotation | 1366x768 | outside | PASS | still INDUSINDBK on rotation#sd=banks&r=INDUSINDBK&y=70 |
| 472 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 288 -> 0 (max 649) |
| 473 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 0 -> 577 |
| 474 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 649 of max 649 (a page that snaps to whole rows may stop one row short) |
| 475 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 476 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 193 -> 0 |
| 477 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 478 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 200 -> 0 |
| 479 | pane scrollbar - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 480 | W why + Esc | F3 rotation | 1366x768 | outside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 481 | Space plan card + Esc | F3 rotation | 1366x768 | outside | PASS | open True · after Esc False |
| 482 | pane button W why, then ✕ | F3 rotation | 1366x768 | outside | PASS | open True · closed True |
| 483 | pane button Space plan, then ✕ | F3 rotation | 1366x768 | outside | PASS | open True |
| 484 | P pin (toggle) | F3 rotation | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 485 | Pin toast sits above the action bar, below the share name | F3 rotation | 1366x768 | outside | PASS | toast 583-648 · action bar top 654 · name bottom 439 |
| 486 | Pin button (action bar) | F3 rotation | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 487 | Copy contract | F3 rotation | 1366x768 | outside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 488 | Copy button shows the size | F3 rotation | 1366x768 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 489 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 490 | December strikes only (rows + trade box) | F3 rotation | 1366x768 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 491 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1366x768 | outside | PASS | sector line True · pane True |
| 492 | ATM ★ only on a strike he could take | F3 rotation | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 493 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 494 | no repeated dashes; the reason shown once | F3 rotation | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 495 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1366x768 | outside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[418, 487], [387, 447], [387, 407], [387, 367], [387, 327], [387, 287]] |
| 496 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 240 -> 467 -> 240 (max 954) |
| 497 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 240 -> 694 |
| 498 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 929 of max 954 (a page that snaps to whole rows may stop one row short) |
| 499 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 500 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 339 -> 213 |
| 501 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 413 -> 213 |
| 502 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 503 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1366x768 | outside | PASS | rows 8 -> 22 -> 8 |
| 504 | basis › (the basis in full, R49) | F3 rotation | 1366x768 | outside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 505 | "n more listed, not F&O" fold line | F3 rotation | 1366x768 | outside | PASS | "▸ 12 more listed, not F&O · ▲7 ▼5 · wt 5% · context only, no strike" -> open, then closed |
| 506 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1366x768 | outside | PASS | went share?s=ICICIBANK · back: open banks, row ICICIBANK, expanded True |
| 507 | after Back, J still moves | F3 rotation | 1366x768 | outside | PASS | ICICIBANK -> BANKINDIA |
| 508 | O opens the option chain at the December strike; Back | F3 rotation | 1366x768 | outside | PASS | chain?s=BANKINDIA · back on BANKINDIA (no December contract in the store for any share of this sector now: the chain opens on the share, never a November strike) |
| 509 | double-click the pane share name -> F7, Back | F3 rotation | 1366x768 | outside | PASS | share?s=BANKINDIA |
| 510 | Enter on a share row -> F7 | F3 rotation | 1366x768 | outside | PASS | share?s=BANKINDIA |
| 511 | Esc closes step by step | F3 rotation | 1366x768 | outside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 512 | O / W with no share selected | F3 rotation | 1366x768 | outside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 513 | keys 1-9 pick a sector | F3 rotation | 1366x768 | outside | PASS | 3 -> cement & materials (row 3 = cement & materials) · 1 -> hospitals & diagnostics (row 1 = hospitals & diagnostics) |
| 514 | Tab to a sector row + Enter opens it | F3 rotation | 1366x768 | outside | PASS | focused hospitals & diagnostics after 2 Tab · open hospitals & diagnostics |
| 515 | R key (apply re-rank) | F3 rotation | 1366x768 | outside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 516 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1366x768 | outside | NOT RUN | needs live ticks: the market is closed (the store holds the close of today); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 517 | money-flow band: a sector name opens it in the table below | F3 rotation | 1366x768 | outside | PASS | clicked hospitals & diagnostics -> open hospitals & diagnostics, list visible True |
| 518 | "moving, but not this rotation" row opens that sector | F3 rotation | 1366x768 | outside | PASS | clicked realty -> open realty |
| 519 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1366x768 | outside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 520 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1366x768 | outside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 521 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1366x768 | outside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 522 | up-side shown: a rising sector shows CE strikes on its groups (a falling one PE) | F3 rotation | 1366x768 | outside | PASS | hospitals & diagnostics dir 1 · every row CE: True |
| 523 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F3 rotation | 1366x768 | outside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 242 |
| 524 | page errors | F3 rotation | 1366x768 | outside | PASS | none |
| 525 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | outside | PASS | 44 -> 298 -> 44 (max 754) |
| 526 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | outside | PASS | 44 -> 552 |
| 527 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | outside | PASS | top 734 of max 754 (a page that snaps to whole rows may stop one row short) |
| 528 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | outside | PASS | top 0 |
| 529 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 308 -> 0 |
| 530 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | outside | PASS | -> 200 -> 0 |
| 531 | F2 board scrollbar - thumb visible | F2 sectors | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 532 | F2 board row click opens the sector in place | F2 sectors | 1366x768 | outside | PASS | open auto · list bottom 640 · next row top 646 |
| 533 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1366x768 | outside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 534 | every visible share name - click loads the pane, the list stays | F2 sectors | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 535 | J through the whole list (pane follows) | F2 sectors | 1366x768 | outside | PASS | J x7 -> BOSCHLTD (last row BOSCHLTD) |
| 536 | K back up | F2 sectors | 1366x768 | outside | PASS | K x7 -> MARUTI |
| 537 | ↓ / ↑ move share to share | F2 sectors | 1366x768 | outside | PASS | ↓ BHARATFORG · ↑ MARUTI |
| 538 | J / K after a click in the pane | F2 sectors | 1366x768 | outside | PASS | J BHARATFORG · K MARUTI |
| 539 | pane share name - single click | F2 sectors | 1366x768 | outside | PASS | still MARUTI on sectors#sd=auto&r=MARUTI&y=840 |
| 540 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 154 -> 0 (max 529) |
| 541 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | outside | PASS | 0 -> 308 |
| 542 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | outside | PASS | top 529 of max 529 (a page that snaps to whole rows may stop one row short) |
| 543 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | outside | PASS | top 0 |
| 544 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 355 -> 0 |
| 545 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 546 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | outside | PASS | -> 200 -> 0 |
| 547 | pane scrollbar - thumb visible | F2 sectors | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 548 | W why + Esc | F2 sectors | 1366x768 | outside | PASS | open True · after Esc open False · share still MARUTI |
| 549 | Space plan card + Esc | F2 sectors | 1366x768 | outside | PASS | open True · after Esc False |
| 550 | pane button W why, then ✕ | F2 sectors | 1366x768 | outside | PASS | open True · closed True |
| 551 | pane button Space plan, then ✕ | F2 sectors | 1366x768 | outside | PASS | open True |
| 552 | P pin (toggle) | F2 sectors | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 553 | Pin toast sits above the action bar, below the share name | F2 sectors | 1366x768 | outside | PASS | toast 599-647 · action bar top 653 · name bottom 287 |
| 554 | Pin button (action bar) | F2 sectors | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 555 | Copy contract (clipboard only) | F2 sectors | 1366x768 | outside | PASS | clipboard "TMPV26DEC270CE" · button "Copy 270 CE · 0 lots" · toast "Copied TMPV26DEC270CE · 0 lots - you place the order in Kite" |
| 556 | Copy button shows the size | F2 sectors | 1366x768 | outside | PASS | Copy 270 CE · 0 lots |
| 557 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 558 | December strikes only (rows + trade box) | F2 sectors | 1366x768 | outside | PASS | 1 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False · December chain gap named once in the list |
| 559 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1366x768 | outside | PASS | sector line True · pane True |
| 560 | ATM ★ only on a strike he could take | F2 sectors | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 561 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 562 | no repeated dashes; the reason shown once | F2 sectors | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 563 | F2 heat-map tile opens that sector in the board | F2 sectors | 1366x768 | outside | PASS | tile hospitals & diagnostics -> open hospitals & diagnostics · in view True |
| 564 | F2: the share pane sits in the right column | F2 sectors | 1366x768 | outside | PASS | pane host #call |
| 565 | F2 keys 1-9 | F2 sectors | 1366x768 | outside | PASS | 2 -> banks (row 2 = banks) |
| 566 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F2 sectors | 1366x768 | outside | PASS | 19 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 212 |
| 567 | page errors | F2 sectors | 1366x768 | outside | PASS | none |
| 568 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1366x768 | outside | PASS | chip banks -> open banks |
| 569 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1366x768 | outside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 570 | every visible share name - click loads the pane, the list stays | F1 desk | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 571 | J through the whole list (pane follows) | F1 desk | 1366x768 | outside | PASS | J x7 -> FEDERALBNK (last row FEDERALBNK) |
| 572 | K back up | F1 desk | 1366x768 | outside | PASS | K x7 -> INDUSINDBK |
| 573 | ↓ / ↑ move share to share | F1 desk | 1366x768 | outside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 574 | J / K after a click in the pane | F1 desk | 1366x768 | outside | PASS | J BANDHANBNK · K INDUSINDBK |
| 575 | pane share name - single click | F1 desk | 1366x768 | outside | PASS | still INDUSINDBK on desk-hunt#sd=banks&r=INDUSINDBK&y=0 |
| 576 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 121 -> 0 (max 354) |
| 577 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1366x768 | outside | PASS | 0 -> 241 |
| 578 | pane scrollbar - drag past the end, off the rail | F1 desk | 1366x768 | outside | PASS | top 354 of max 354 (a page that snaps to whole rows may stop one row short) |
| 579 | pane scrollbar - drag past the top, off the rail | F1 desk | 1366x768 | outside | PASS | top 0 |
| 580 | pane scrollbar - track click below, then above the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 354 -> 0 |
| 581 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 582 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | outside | PASS | -> 200 -> 0 |
| 583 | pane scrollbar - thumb visible | F1 desk | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 584 | W why + Esc | F1 desk | 1366x768 | outside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 585 | Space plan card + Esc | F1 desk | 1366x768 | outside | PASS | open True · after Esc False |
| 586 | pane button W why, then ✕ | F1 desk | 1366x768 | outside | PASS | open True · closed True |
| 587 | pane button Space plan, then ✕ | F1 desk | 1366x768 | outside | PASS | open True |
| 588 | P pin (toggle) | F1 desk | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 589 | Pin toast sits above the action bar, below the share name | F1 desk | 1366x768 | outside | PASS | toast 629-677 · action bar top 683 · name bottom 289 |
| 590 | Pin button (action bar) | F1 desk | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 591 | Copy contract | F1 desk | 1366x768 | outside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 592 | Copy button shows the size | F1 desk | 1366x768 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 593 | signal only: no order / buy button, the Kite line shown | F1 desk | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 594 | December strikes only (rows + trade box) | F1 desk | 1366x768 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 595 | "Expiry week · physical settlement - December only" warning | F1 desk | 1366x768 | outside | PASS | sector line True · pane True |
| 596 | ATM ★ only on a strike he could take | F1 desk | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 597 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 598 | no repeated dashes; the reason shown once | F1 desk | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 599 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 99 -> 0 (max 287) |
| 600 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1366x768 | outside | PASS | 0 -> 198 |
| 601 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1366x768 | outside | PASS | top 287 of max 287 (a page that snaps to whole rows may stop one row short) |
| 602 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1366x768 | outside | PASS | top 0 |
| 603 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 287 -> 0 |
| 604 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 605 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | outside | PASS | -> 200 -> 0 |
| 606 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 607 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F1 desk | 1366x768 | outside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 755 |
| 608 | F1 Esc closes back to the Desk | F1 desk | 1366x768 | outside | PASS | open None · members panel back |
| 609 | page errors | F1 desk | 1366x768 | outside | PASS | none |
| 610 | Morning sector card opens the same component | Morning | 1366x768 | outside | PASS | card realty -> open realty |
| 611 | Morning: "pre-open - not live" (after 15:30 "closed - not live") with the session date | Morning | 1366x768 | outside | PASS | ['closed - not live · 20 Nov 15:30 close', True, True] |
| 612 | every visible share name - click loads the pane, the list stays | Morning | 1366x768 | outside | PASS | 6 names clicked, wrong: [] · list visible: True |
| 613 | J through the whole list (pane follows) | Morning | 1366x768 | outside | PASS | J x5 -> LODHA (last row LODHA) |
| 614 | K back up | Morning | 1366x768 | outside | PASS | K x5 -> GODREJPROP |
| 615 | ↓ / ↑ move share to share | Morning | 1366x768 | outside | PASS | ↓ DLF · ↑ GODREJPROP |
| 616 | J / K after a click in the pane | Morning | 1366x768 | outside | PASS | J DLF · K GODREJPROP |
| 617 | pane share name - single click | Morning | 1366x768 | outside | PASS | still GODREJPROP on morning#sd=realty&r=GODREJPROP&y=0 |
| 618 | pane scrollbar - slow mouse drag of the thumb | Morning | 1366x768 | outside | PASS | 0 -> 190 -> 0 (max 570) |
| 619 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1366x768 | outside | PASS | 0 -> 380 |
| 620 | pane scrollbar - drag past the end, off the rail | Morning | 1366x768 | outside | PASS | top 570 of max 570 (a page that snaps to whole rows may stop one row short) |
| 621 | pane scrollbar - drag past the top, off the rail | Morning | 1366x768 | outside | PASS | top 0 |
| 622 | pane scrollbar - track click below, then above the thumb | Morning | 1366x768 | outside | PASS | 0 -> 282 -> 0 |
| 623 | pane scrollbar - ▼ then ▲ buttons | Morning | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 624 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1366x768 | outside | PASS | -> 200 -> 0 |
| 625 | pane scrollbar - thumb visible | Morning | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 626 | W why + Esc | Morning | 1366x768 | outside | PASS | open True · after Esc open False · share still GODREJPROP |
| 627 | Space plan card + Esc | Morning | 1366x768 | outside | PASS | open True · after Esc False |
| 628 | pane button W why, then ✕ | Morning | 1366x768 | outside | PASS | open True · closed True |
| 629 | pane button Space plan, then ✕ | Morning | 1366x768 | outside | PASS | open True |
| 630 | P pin (toggle) | Morning | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 631 | Pin toast sits above the action bar, below the share name | Morning | 1366x768 | outside | PASS | toast 582-647 · action bar top 653 · name bottom 368 |
| 632 | Pin button (action bar) | Morning | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 633 | Copy contract | Morning | 1366x768 | outside | PASS | Copy off for GODREJPROP (oc.GODREJPROP.rows2 (the next-month chain) not in the store) - disabled |
| 634 | Copy button shows the size | Morning | 1366x768 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 635 | signal only: no order / buy button, the Kite line shown | Morning | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 636 | December strikes only (rows + trade box) | Morning | 1366x768 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 637 | "Expiry week · physical settlement - December only" warning | Morning | 1366x768 | outside | PASS | sector line True · pane True |
| 638 | ATM ★ only on a strike he could take | Morning | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 639 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 640 | no repeated dashes; the reason shown once | Morning | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 641 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | Morning | 1366x768 | outside | PASS | 3 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 3 |
| 642 | page errors | Morning | 1366x768 | outside | PASS | none |
| 643 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 156 -> 0 (max 592) |
| 644 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 0 -> 313 |
| 645 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 578 of max 592 (a page that snaps to whole rows may stop one row short) |
| 646 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 647 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 283 -> 147 |
| 648 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1600x900 | outside | PASS | 147 -> 259 -> 148 |
| 649 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 348 -> 148 |
| 650 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 651 | F3 table row click opens the sector | F3 rotation | 1600x900 | outside | PASS | open banks in 22 ms (from the cached store) |
| 652 | opens under 100 ms | F3 rotation | 1600x900 | outside | PASS | 22 ms |
| 653 | the open list pushes the rows below (no overprint) | F3 rotation | 1600x900 | outside | PASS | list bottom 855 · next sector row top 861 |
| 654 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1600x900 | outside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 655 | every visible share name - click loads the pane, the list stays | F3 rotation | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 656 | J through the whole list (pane follows) | F3 rotation | 1600x900 | outside | PASS | J x11 -> BANKINDIA (last row BANKINDIA) |
| 657 | K back up | F3 rotation | 1600x900 | outside | PASS | K x11 -> INDUSINDBK |
| 658 | ↓ / ↑ move share to share | F3 rotation | 1600x900 | outside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 659 | J / K after a click in the pane | F3 rotation | 1600x900 | outside | PASS | J BANDHANBNK · K INDUSINDBK |
| 660 | pane share name - single click | F3 rotation | 1600x900 | outside | PASS | still INDUSINDBK on rotation#sd=banks&r=INDUSINDBK&y=76 |
| 661 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 128 -> 0 (max 378) |
| 662 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 0 -> 256 |
| 663 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 378 of max 378 (a page that snaps to whole rows may stop one row short) |
| 664 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 665 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 356 -> 1 |
| 666 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1600x900 | outside | PASS | 1 -> 67 -> 1 |
| 667 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 201 -> 1 |
| 668 | pane scrollbar - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 669 | W why + Esc | F3 rotation | 1600x900 | outside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 670 | Space plan card + Esc | F3 rotation | 1600x900 | outside | PASS | open True · after Esc False |
| 671 | pane button W why, then ✕ | F3 rotation | 1600x900 | outside | PASS | open True · closed True |
| 672 | pane button Space plan, then ✕ | F3 rotation | 1600x900 | outside | PASS | open True |
| 673 | P pin (toggle) | F3 rotation | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 674 | Pin toast sits above the action bar, below the share name | F3 rotation | 1600x900 | outside | PASS | toast 761-809 · action bar top 815 · name bottom 419 |
| 675 | Pin button (action bar) | F3 rotation | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 676 | Copy contract | F3 rotation | 1600x900 | outside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 677 | Copy button shows the size | F3 rotation | 1600x900 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 678 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 679 | December strikes only (rows + trade box) | F3 rotation | 1600x900 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 680 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1600x900 | outside | PASS | sector line True · pane True |
| 681 | ATM ★ only on a strike he could take | F3 rotation | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 682 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 683 | no repeated dashes; the reason shown once | F3 rotation | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 684 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1600x900 | outside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[424, 493], [387, 453], [387, 413], [387, 373], [387, 333], [387, 293]] |
| 685 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 240 -> 425 -> 240 (max 981) |
| 686 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 240 -> 609 |
| 687 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 957 of max 981 (a page that snaps to whole rows may stop one row short) |
| 688 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 689 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 390 -> 235 |
| 690 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 435 -> 235 |
| 691 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 692 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1600x900 | outside | PASS | rows 12 -> 22 -> 12 |
| 693 | basis › (the basis in full, R49) | F3 rotation | 1600x900 | outside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 694 | "n more listed, not F&O" fold line | F3 rotation | 1600x900 | outside | PASS | "▸ 12 more listed, not F&O · ▲7 ▼5 · wt 5% · context only, no strike" -> open, then closed |
| 695 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1600x900 | outside | PASS | went share?s=ICICIBANK · back: open banks, row ICICIBANK, expanded True |
| 696 | after Back, J still moves | F3 rotation | 1600x900 | outside | PASS | ICICIBANK -> BANKINDIA |
| 697 | O opens the option chain at the December strike; Back | F3 rotation | 1600x900 | outside | PASS | chain?s=BANKINDIA · back on BANKINDIA (no December contract in the store for any share of this sector now: the chain opens on the share, never a November strike) |
| 698 | double-click the pane share name -> F7, Back | F3 rotation | 1600x900 | outside | PASS | share?s=BANKINDIA |
| 699 | Enter on a share row -> F7 | F3 rotation | 1600x900 | outside | PASS | share?s=BANKINDIA |
| 700 | Esc closes step by step | F3 rotation | 1600x900 | outside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 701 | O / W with no share selected | F3 rotation | 1600x900 | outside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 702 | keys 1-9 pick a sector | F3 rotation | 1600x900 | outside | PASS | 3 -> cement & materials (row 3 = cement & materials) · 1 -> hospitals & diagnostics (row 1 = hospitals & diagnostics) |
| 703 | Tab to a sector row + Enter opens it | F3 rotation | 1600x900 | outside | PASS | focused hospitals & diagnostics after 3 Tab · open hospitals & diagnostics |
| 704 | R key (apply re-rank) | F3 rotation | 1600x900 | outside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 705 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1600x900 | outside | NOT RUN | needs live ticks: the market is closed (the store holds the close of today); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 706 | money-flow band: a sector name opens it in the table below | F3 rotation | 1600x900 | outside | PASS | clicked hospitals & diagnostics -> open hospitals & diagnostics, list visible True |
| 707 | "moving, but not this rotation" row opens that sector | F3 rotation | 1600x900 | outside | PASS | clicked realty -> open realty |
| 708 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1600x900 | outside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 709 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1600x900 | outside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 710 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1600x900 | outside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 711 | up-side shown: a rising sector shows CE strikes on its groups (a falling one PE) | F3 rotation | 1600x900 | outside | PASS | hospitals & diagnostics dir 1 · every row CE: True |
| 712 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F3 rotation | 1600x900 | outside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 187 |
| 713 | page errors | F3 rotation | 1600x900 | outside | PASS | none |
| 714 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | outside | PASS | 44 -> 203 -> 43 (max 622) |
| 715 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | outside | PASS | 43 -> 363 |
| 716 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | outside | PASS | top 621 of max 622 (a page that snaps to whole rows may stop one row short) |
| 717 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | outside | PASS | top 0 |
| 718 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 559 -> 0 |
| 719 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | outside | PASS | -> 200 -> 0 |
| 720 | F2 board scrollbar - thumb visible | F2 sectors | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 721 | F2 board row click opens the sector in place | F2 sectors | 1600x900 | outside | PASS | open auto · list bottom 776 · next row top 782 |
| 722 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1600x900 | outside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 723 | every visible share name - click loads the pane, the list stays | F2 sectors | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 724 | J through the whole list (pane follows) | F2 sectors | 1600x900 | outside | PASS | J x11 -> HEROMOTOCO (last row HEROMOTOCO) |
| 725 | K back up | F2 sectors | 1600x900 | outside | PASS | K x11 -> MARUTI |
| 726 | ↓ / ↑ move share to share | F2 sectors | 1600x900 | outside | PASS | ↓ BHARATFORG · ↑ MARUTI |
| 727 | J / K after a click in the pane | F2 sectors | 1600x900 | outside | PASS | J BHARATFORG · K MARUTI |
| 728 | pane share name - single click | F2 sectors | 1600x900 | outside | PASS | still MARUTI on sectors#sd=auto&r=MARUTI&y=785 |
| 729 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 100 -> 0 (max 289) |
| 730 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | outside | PASS | 0 -> 199 |
| 731 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | outside | PASS | top 289 of max 289 (a page that snaps to whole rows may stop one row short) |
| 732 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | outside | PASS | top 0 |
| 733 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 289 -> 0 |
| 734 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 735 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | outside | PASS | -> 200 -> 0 |
| 736 | pane scrollbar - thumb visible | F2 sectors | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 737 | W why + Esc | F2 sectors | 1600x900 | outside | PASS | open True · after Esc open False · share still MARUTI |
| 738 | Space plan card + Esc | F2 sectors | 1600x900 | outside | PASS | open True · after Esc False |
| 739 | pane button W why, then ✕ | F2 sectors | 1600x900 | outside | PASS | open True · closed True |
| 740 | pane button Space plan, then ✕ | F2 sectors | 1600x900 | outside | PASS | open True |
| 741 | P pin (toggle) | F2 sectors | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 742 | Pin toast sits above the action bar, below the share name | F2 sectors | 1600x900 | outside | PASS | toast 760-808 · action bar top 814 · name bottom 288 |
| 743 | Pin button (action bar) | F2 sectors | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 744 | Copy contract (clipboard only) | F2 sectors | 1600x900 | outside | PASS | clipboard "TMPV26DEC270CE" · button "Copy 270 CE · 0 lots" · toast "Copied TMPV26DEC270CE · 0 lots - you place the order in Kite" |
| 745 | Copy button shows the size | F2 sectors | 1600x900 | outside | PASS | Copy 270 CE · 0 lots |
| 746 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 747 | December strikes only (rows + trade box) | F2 sectors | 1600x900 | outside | PASS | 1 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False · December chain gap named once in the list |
| 748 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1600x900 | outside | PASS | sector line True · pane True |
| 749 | ATM ★ only on a strike he could take | F2 sectors | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 750 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 751 | no repeated dashes; the reason shown once | F2 sectors | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 752 | F2 heat-map tile opens that sector in the board | F2 sectors | 1600x900 | outside | PASS | tile hospitals & diagnostics -> open hospitals & diagnostics · in view True |
| 753 | F2: the share pane sits in the right column | F2 sectors | 1600x900 | outside | PASS | pane host #call |
| 754 | F2 keys 1-9 | F2 sectors | 1600x900 | outside | PASS | 2 -> banks (row 2 = banks) |
| 755 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F2 sectors | 1600x900 | outside | PASS | 19 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 353 |
| 756 | page errors | F2 sectors | 1600x900 | outside | PASS | none |
| 757 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1600x900 | outside | PASS | chip banks -> open banks |
| 758 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1600x900 | outside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 759 | every visible share name - click loads the pane, the list stays | F1 desk | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 760 | J through the whole list (pane follows) | F1 desk | 1600x900 | outside | PASS | J x11 -> BANKINDIA (last row BANKINDIA) |
| 761 | K back up | F1 desk | 1600x900 | outside | PASS | K x11 -> INDUSINDBK |
| 762 | ↓ / ↑ move share to share | F1 desk | 1600x900 | outside | PASS | ↓ BANDHANBNK · ↑ INDUSINDBK |
| 763 | J / K after a click in the pane | F1 desk | 1600x900 | outside | PASS | J BANDHANBNK · K INDUSINDBK |
| 764 | pane share name - single click | F1 desk | 1600x900 | outside | PASS | still INDUSINDBK on desk-hunt#sd=banks&r=INDUSINDBK&y=0 |
| 765 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 88 -> 0 (max 207) |
| 766 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1600x900 | outside | PASS | 0 -> 176 |
| 767 | pane scrollbar - drag past the end, off the rail | F1 desk | 1600x900 | outside | PASS | top 207 of max 207 (a page that snaps to whole rows may stop one row short) |
| 768 | pane scrollbar - drag past the top, off the rail | F1 desk | 1600x900 | outside | PASS | top 0 |
| 769 | pane scrollbar - track click below, then above the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 207 -> 0 |
| 770 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 771 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | outside | PASS | -> 200 -> 0 |
| 772 | pane scrollbar - thumb visible | F1 desk | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 773 | W why + Esc | F1 desk | 1600x900 | outside | PASS | open True · after Esc open False · share still INDUSINDBK |
| 774 | Space plan card + Esc | F1 desk | 1600x900 | outside | PASS | open True · after Esc False |
| 775 | pane button W why, then ✕ | F1 desk | 1600x900 | outside | PASS | open True · closed True |
| 776 | pane button Space plan, then ✕ | F1 desk | 1600x900 | outside | PASS | open True |
| 777 | P pin (toggle) | F1 desk | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 778 | Pin toast sits above the action bar, below the share name | F1 desk | 1600x900 | outside | PASS | toast 761-809 · action bar top 815 · name bottom 268 |
| 779 | Pin button (action bar) | F1 desk | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 780 | Copy contract | F1 desk | 1600x900 | outside | PASS | Copy off for INDUSINDBK (oc.INDUSINDBK.rows2 (the next-month chain) not in the store) - disabled |
| 781 | Copy button shows the size | F1 desk | 1600x900 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 782 | signal only: no order / buy button, the Kite line shown | F1 desk | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 783 | December strikes only (rows + trade box) | F1 desk | 1600x900 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 784 | "Expiry week · physical settlement - December only" warning | F1 desk | 1600x900 | outside | PASS | sector line True · pane True |
| 785 | ATM ★ only on a strike he could take | F1 desk | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 786 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 787 | no repeated dashes; the reason shown once | F1 desk | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 788 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 79 -> 0 (max 159) |
| 789 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1600x900 | outside | PASS | 0 -> 158 |
| 790 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1600x900 | outside | PASS | top 159 of max 159 (a page that snaps to whole rows may stop one row short) |
| 791 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1600x900 | outside | PASS | top 0 |
| 792 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 159 -> 0 |
| 793 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 794 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | outside | PASS | -> 159 -> 0 |
| 795 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 796 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | F1 desk | 1600x900 | outside | PASS | 26 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 728 |
| 797 | F1 Esc closes back to the Desk | F1 desk | 1600x900 | outside | PASS | open None · members panel back |
| 798 | page errors | F1 desk | 1600x900 | outside | PASS | none |
| 799 | Morning sector card opens the same component | Morning | 1600x900 | outside | PASS | card realty -> open realty |
| 800 | Morning: "pre-open - not live" (after 15:30 "closed - not live") with the session date | Morning | 1600x900 | outside | PASS | ['closed - not live · 20 Nov 15:30 close', True, True] |
| 801 | every visible share name - click loads the pane, the list stays | Morning | 1600x900 | outside | PASS | 6 names clicked, wrong: [] · list visible: True |
| 802 | J through the whole list (pane follows) | Morning | 1600x900 | outside | PASS | J x5 -> LODHA (last row LODHA) |
| 803 | K back up | Morning | 1600x900 | outside | PASS | K x5 -> GODREJPROP |
| 804 | ↓ / ↑ move share to share | Morning | 1600x900 | outside | PASS | ↓ DLF · ↑ GODREJPROP |
| 805 | J / K after a click in the pane | Morning | 1600x900 | outside | PASS | J DLF · K GODREJPROP |
| 806 | pane share name - single click | Morning | 1600x900 | outside | PASS | still GODREJPROP on morning#sd=realty&r=GODREJPROP&y=0 |
| 807 | pane scrollbar - slow mouse drag of the thumb | Morning | 1600x900 | outside | PASS | 0 -> 154 -> 0 (max 439) |
| 808 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1600x900 | outside | PASS | 0 -> 308 |
| 809 | pane scrollbar - drag past the end, off the rail | Morning | 1600x900 | outside | PASS | top 439 of max 439 (a page that snaps to whole rows may stop one row short) |
| 810 | pane scrollbar - drag past the top, off the rail | Morning | 1600x900 | outside | PASS | top 0 |
| 811 | pane scrollbar - track click below, then above the thumb | Morning | 1600x900 | outside | PASS | 0 -> 302 -> 0 |
| 812 | pane scrollbar - ▼ then ▲ buttons | Morning | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 813 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1600x900 | outside | PASS | -> 200 -> 0 |
| 814 | pane scrollbar - thumb visible | Morning | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 815 | W why + Esc | Morning | 1600x900 | outside | PASS | open True · after Esc open False · share still GODREJPROP |
| 816 | Space plan card + Esc | Morning | 1600x900 | outside | PASS | open True · after Esc False |
| 817 | pane button W why, then ✕ | Morning | 1600x900 | outside | PASS | open True · closed True |
| 818 | pane button Space plan, then ✕ | Morning | 1600x900 | outside | PASS | open True |
| 819 | P pin (toggle) | Morning | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 820 | Pin toast sits above the action bar, below the share name | Morning | 1600x900 | outside | PASS | toast 760-808 · action bar top 814 · name bottom 477 |
| 821 | Pin button (action bar) | Morning | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 822 | Copy contract | Morning | 1600x900 | outside | PASS | Copy off for GODREJPROP (oc.GODREJPROP.rows2 (the next-month chain) not in the store) - disabled |
| 823 | Copy button shows the size | Morning | 1600x900 | outside | PASS | Copy contract · 0 lots (no December contract in the store for any share of this sector today - Copy off, size still shown) |
| 824 | signal only: no order / buy button, the Kite line shown | Morning | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 825 | December strikes only (rows + trade box) | Morning | 1600x900 | outside | PASS | 0 strike chips, 0 not December · trade box "TRADE BOX · December (December only)" · November date shown: False · December chain gap named once in the list |
| 826 | "Expiry week · physical settlement - December only" warning | Morning | 1600x900 | outside | PASS | sector line True · pane True |
| 827 | ATM ★ only on a strike he could take | Morning | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 828 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 829 | no repeated dashes; the reason shown once | Morning | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 830 | no cut text: every cell scrollWidth <= clientWidth (every sector + every fold open) | Morning | 1600x900 | outside | PASS | 3 sectors opened by click, more + not-F&O folds open, a share in the pane · cut cells: 0 · prose with a tooltip allowed: 3 |
| 831 | page errors | Morning | 1600x900 | outside | PASS | none |
| 832 | tap a sector row opens the full-screen list sheet | F3 rotation | 390x844 | outside | PASS | open banks · built in 26 ms · tap-to-sheet 107 ms |
| 833 | sheet header (sector line) <= 2 lines + WHY | F3 rotation | 390x844 | outside | PASS | line 1 46 px, whole header 179 px |
| 834 | sheet rail size (touch target >= 24, track and thumb >= 10) | F3 rotation | 390x844 | outside | PASS | target 26 · track 13 · thumb 13 px |
| 835 | list sheet - finger swipe | F3 rotation | 390x844 | outside | PASS | 0 -> 434 -> 193 |
| 836 | list sheet - rail thumb, finger drag | F3 rotation | 390x844 | outside | PASS | 193 -> 419 · share opened: None |
| 837 | list sheet - rail drag, 8 px contact | F3 rotation | 390x844 | outside | PASS | 419 -> 193 |
| 838 | list sheet - rail drag at its right edge | F3 rotation | 390x844 | outside | PASS | 193 -> 381 |
| 839 | list sheet - rail track tap | F3 rotation | 390x844 | outside | PASS | 381 -> 315 |
| 840 | list sheet - rail, mouse drag (one mouse check) | F3 rotation | 390x844 | outside | PASS | 315 -> 466 |
| 841 | fast flick, then a tap still opens the row | F3 rotation | 390x844 | outside | PASS | flick then tap BANKINDIA -> share sheet True (BANKINDIA) |
| 842 | "n more listed, not F&O" (finger) | F3 rotation | 390x844 | outside | PASS | open True · closed True |
| 843 | basis › (finger) | F3 rotation | 390x844 | outside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 844 | tap a share opens the share sheet | F3 rotation | 390x844 | outside | PASS | INDUSINDBK -> sheet True |
| 845 | share sheet - finger swipe | F3 rotation | 390x844 | outside | PASS | 0 -> 113 |
| 846 | share sheet - action bar sticky, shows the size | F3 rotation | 390x844 | outside | PASS | bar 733-844 at scroll 0 and 733-844 after the swipe · "Copy contract · 0 lots" |
| 847 | share sheet - rail thumb, finger drag | F3 rotation | 390x844 | outside | PASS | 0 -> 113 |
| 848 | share sheet - rail track tap | F3 rotation | 390x844 | outside | PASS | 113 -> 47 |
| 849 | WHY › (share sheet) | F3 rotation | 390x844 | outside | PASS | open True · closed True |
| 850 | Copy contract (finger, first view) | F3 rotation | 390x844 | outside | PASS | Copy off: oc.INDUSINDBK.rows2 (the next-month chain) not in the store |
| 851 | Pin (toggle, n/5) (finger) | F3 rotation | 390x844 | outside | PASS | 0 -> 1 -> 0 |
| 852 | Pin toast above the action bar, not over the share name | F3 rotation | 390x844 | outside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 853 | ‹ Sector (Back button on the share sheet) | F3 rotation | 390x844 | outside | PASS | list sheet True · share sheet False |
| 854 | device / browser Back (share sheet -> list) | F3 rotation | 390x844 | outside | PASS | list True · share False |
| 855 | device / browser Back (list -> page) | F3 rotation | 390x844 | outside | PASS | sheet False · open None |
| 856 | ‹ Sectors (Back button on the list sheet) | F3 rotation | 390x844 | outside | PASS | sheet closed True |
| 857 | page errors | F3 rotation | 390x844 | outside | PASS | none |
| 858 | tap a sector row opens the full-screen list sheet | F2 sectors | 390x844 | outside | PASS | open banks · built in 22 ms · tap-to-sheet 100 ms |
| 859 | sheet header (sector line) <= 2 lines + WHY | F2 sectors | 390x844 | outside | PASS | line 1 46 px, whole header 179 px |
| 860 | sheet rail size (touch target >= 24, track and thumb >= 10) | F2 sectors | 390x844 | outside | PASS | target 26 · track 13 · thumb 13 px |
| 861 | list sheet - finger swipe | F2 sectors | 390x844 | outside | PASS | 0 -> 443 -> 169 |
| 862 | list sheet - rail thumb, finger drag | F2 sectors | 390x844 | outside | PASS | 169 -> 395 · share opened: None |
| 863 | list sheet - rail drag, 8 px contact | F2 sectors | 390x844 | outside | PASS | 395 -> 169 |
| 864 | list sheet - rail drag at its right edge | F2 sectors | 390x844 | outside | PASS | 169 -> 357 |
| 865 | list sheet - rail track tap | F2 sectors | 390x844 | outside | PASS | 357 -> 291 |
| 866 | list sheet - rail, mouse drag (one mouse check) | F2 sectors | 390x844 | outside | PASS | 291 -> 442 |
| 867 | fast flick, then a tap still opens the row | F2 sectors | 390x844 | outside | PASS | flick then tap BANKINDIA -> share sheet True (BANKINDIA) |
| 868 | "n more listed, not F&O" (finger) | F2 sectors | 390x844 | outside | PASS | open True · closed True |
| 869 | basis › (finger) | F2 sectors | 390x844 | outside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 870 | tap a share opens the share sheet | F2 sectors | 390x844 | outside | PASS | INDUSINDBK -> sheet True |
| 871 | share sheet - finger swipe | F2 sectors | 390x844 | outside | PASS | 0 -> 70 |
| 872 | share sheet - action bar sticky, shows the size | F2 sectors | 390x844 | outside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy contract · 0 lots" |
| 873 | share sheet - rail thumb, finger drag | F2 sectors | 390x844 | outside | PASS | 0 -> 70 |
| 874 | share sheet - rail track tap | F2 sectors | 390x844 | outside | PASS | 70 -> 4 |
| 875 | WHY › (share sheet) | F2 sectors | 390x844 | outside | PASS | open True · closed True |
| 876 | Copy contract (finger, first view) | F2 sectors | 390x844 | outside | PASS | Copy off: oc.INDUSINDBK.rows2 (the next-month chain) not in the store |
| 877 | Pin (toggle, n/5) (finger) | F2 sectors | 390x844 | outside | PASS | 0 -> 1 -> 0 |
| 878 | Pin toast above the action bar, not over the share name | F2 sectors | 390x844 | outside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 879 | ‹ Sector (Back button on the share sheet) | F2 sectors | 390x844 | outside | PASS | list sheet True · share sheet False |
| 880 | device / browser Back (share sheet -> list) | F2 sectors | 390x844 | outside | PASS | list True · share False |
| 881 | device / browser Back (list -> page) | F2 sectors | 390x844 | outside | PASS | sheet False · open None |
| 882 | ‹ Sectors (Back button on the list sheet) | F2 sectors | 390x844 | outside | PASS | sheet closed True |
| 883 | page errors | F2 sectors | 390x844 | outside | PASS | none |
