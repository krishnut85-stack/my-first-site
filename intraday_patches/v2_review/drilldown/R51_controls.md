# R51 controls test - SECTOR DRILL-DOWN (R50) on the real /preview pages

Run 20 Nov 2026 05:57 IST. Real input only: mouse clicks, drags of scrollbar thumbs and wheel, keyboard on the desk (1366x768 and 1600x900, deviceScaleFactor 1);
finger touches on the phone (390x844, hasTouch + isMobile, CDP touchStart / touchMove / touchEnd). No forced states: the page state is only read to check what the input did.
Inside = http://127.0.0.1:8100/preview/... ; outside = https://girtrader.com/preview/... through the login (cookie made by sitelogin, never printed).
Data = the live store with the 19 Nov close (market closed). NOT RUN = the control needs a live market state that does not exist tonight (named in the row).

**Totals:** 12 NOT RUN · 841 PASS

| where | result | n |
|---|---|---|
| inside | NOT RUN | 6 |
| inside | PASS | 432 |
| outside | NOT RUN | 6 |
| outside | PASS | 409 |

## FAIL rows (0)

none


## Notes
- Runs merged into this table: inside desk 1366 + 1600 (one full run), the F1 1600 rows and the phone rows re-run after test-script fixes; outside desk 1366 + 1600 (one full run), the F2 1600 rows and the phone rows re-run. Earlier FAILs fixed on the way: F3 bar dead to the mouse (shell.css .trk pointer-events:none) -> fixed; F2 rows under 12 at 1600 (page snapped its box to its own rows) -> fixed; phone taps lost after a fling, and the ghost click on the sheet that just opened -> taps route on a short pointerup / touchend (spec 8.2); basis pop-up hidden behind the phone sheet -> fixed.
- "rules" rows = port of test_rules.js over all 230 F&O members of the 26 board sectors through the same shared module. The what-if rows run the same plan() with mode "live" and test 1R values (2,000 / 5,000 / 10,000) on the real 29 Dec quotes, because tonight every plan is blocked "pre-open - not live"; nothing of this is shown on a page.
- NOT RUN (x2 per desk viewport): re-rank chip / NEW / live ticks (no ticks, market closed), STALE (no stale quote in the store), LOCKED (lock not hit) - each rule is covered in the rules rows.
- Not built (spec 6, ranked extras): one-key price alert (6.3), compare 2-3 shares (6.5), leader premium mini-chart (6.7), new-entrants strip (6.8), list-snapshot logging for the journal / scorecard (5).
- Screenshots: shots/ (outside, logged in). The MY F&O P&L strip is masked on the desk shots; no login value, cookie or name appears.

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
| 9 | F3 table row click opens the sector | F3 rotation | 1366x768 | inside | PASS | open banks in 9 ms (from the cached store) |
| 10 | opens under 100 ms | F3 rotation | 1366x768 | inside | PASS | 9 ms |
| 11 | the open list pushes the rows below (no overprint) | F3 rotation | 1366x768 | inside | PASS | list bottom 721 · next sector row top 727 |
| 12 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1366x768 | inside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 13 | every visible share name - click loads the pane, the list stays | F3 rotation | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 14 | J through the whole list (pane follows) | F3 rotation | 1366x768 | inside | PASS | J x7 -> SBIN (last row SBIN) |
| 15 | K back up | F3 rotation | 1366x768 | inside | PASS | K x7 -> IDFCFIRSTB |
| 16 | ↓ / ↑ move share to share | F3 rotation | 1366x768 | inside | PASS | ↓ PNB · ↑ IDFCFIRSTB |
| 17 | J / K after a click in the pane | F3 rotation | 1366x768 | inside | PASS | J PNB · K IDFCFIRSTB |
| 18 | pane share name - single click | F3 rotation | 1366x768 | inside | PASS | still IDFCFIRSTB on rotation#sd=banks&r=IDFCFIRSTB&y=206 |
| 19 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 282 -> 0 (max 705) |
| 20 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | inside | PASS | 0 -> 564 |
| 21 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1366x768 | inside | PASS | top 705 of max 705 (a page that snaps to whole rows may stop one row short) |
| 22 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1366x768 | inside | PASS | top 0 |
| 23 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 211 -> 0 |
| 24 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 25 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | inside | PASS | -> 200 -> 0 |
| 26 | pane scrollbar - thumb visible | F3 rotation | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 27 | W why + Esc | F3 rotation | 1366x768 | inside | PASS | open True · after Esc open False · share still IDFCFIRSTB |
| 28 | Space plan card + Esc | F3 rotation | 1366x768 | inside | PASS | open True · after Esc False |
| 29 | pane button W why, then ✕ | F3 rotation | 1366x768 | inside | PASS | open True · closed True |
| 30 | pane button Space plan, then ✕ | F3 rotation | 1366x768 | inside | PASS | open True |
| 31 | P pin (toggle) | F3 rotation | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 32 | Pin toast sits above the action bar, below the share name | F3 rotation | 1366x768 | inside | PASS | toast 600-648 · action bar top 654 · name bottom 419 |
| 33 | Pin button (action bar) | F3 rotation | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 34 | Copy contract (clipboard only) | F3 rotation | 1366x768 | inside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · button "Copy 86 CE · 0 lots" · toast "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in Kite" |
| 35 | Copy button shows the size | F3 rotation | 1366x768 | inside | PASS | Copy 86 CE · 0 lots |
| 36 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 37 | December strikes only (rows + trade box) | F3 rotation | 1366x768 | inside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 38 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1366x768 | inside | PASS | sector line True · pane True |
| 39 | ATM ★ only on a strike he could take | F3 rotation | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 40 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 41 | no repeated dashes; the reason shown once | F3 rotation | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 42 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1366x768 | inside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[468, 537], [428, 497], [388, 457], [387, 417], [387, 377], [387, 337]] |
| 43 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | inside | PASS | 326 -> 544 -> 326 (max 905) |
| 44 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | inside | PASS | 326 -> 762 |
| 45 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1366x768 | inside | PASS | top 877 of max 905 (a page that snaps to whole rows may stop one row short) |
| 46 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1366x768 | inside | PASS | top 0 |
| 47 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1366x768 | inside | PASS | 0 -> 337 -> 205 |
| 48 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | inside | PASS | -> 405 -> 205 |
| 49 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 50 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1366x768 | inside | PASS | rows 8 -> 22 -> 8 |
| 51 | basis › (the basis in full, R49) | F3 rotation | 1366x768 | inside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 52 | "n more listed, not F&O" fold line | F3 rotation | 1366x768 | inside | PASS | "▸ 12 more listed, not F&O · ▲8 ▼4 · wt 5% · context only, no strike" -> open, then closed |
| 53 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1366x768 | inside | PASS | went share?s=AXISBANK · back: open banks, row AXISBANK, expanded True |
| 54 | after Back, J still moves | F3 rotation | 1366x768 | inside | PASS | AXISBANK -> INDUSINDBK |
| 55 | O opens the option chain at the December strike; Back | F3 rotation | 1366x768 | inside | PASS | chain?s=INDUSINDBK&exp=2026-12-29&k=920&side=CE · back on INDUSINDBK |
| 56 | double-click the pane share name -> F7, Back | F3 rotation | 1366x768 | inside | PASS | share?s=INDUSINDBK |
| 57 | Enter on a share row -> F7 | F3 rotation | 1366x768 | inside | PASS | share?s=INDUSINDBK |
| 58 | Esc closes step by step | F3 rotation | 1366x768 | inside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 59 | O / W with no share selected | F3 rotation | 1366x768 | inside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 60 | keys 1-9 pick a sector | F3 rotation | 1366x768 | inside | PASS | 3 -> fmcg (row 3 = fmcg) · 1 -> auto (row 1 = auto) |
| 61 | Tab to a sector row + Enter opens it | F3 rotation | 1366x768 | inside | PASS | focused auto after 2 Tab · open auto |
| 62 | R key (apply re-rank) | F3 rotation | 1366x768 | inside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 63 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1366x768 | inside | NOT RUN | needs live ticks: the market is closed (store holds the 19 Nov close); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 64 | money-flow band: a sector name opens it in the table below | F3 rotation | 1366x768 | inside | PASS | clicked it -> open it, list visible True |
| 65 | "moving, but not this rotation" row opens that sector | F3 rotation | 1366x768 | inside | PASS | clicked consumer durables -> open consumer durables |
| 66 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1366x768 | inside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 67 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1366x768 | inside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 68 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1366x768 | inside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 69 | up-side shown: a rising sector shows CE strikes on its groups | F3 rotation | 1366x768 | inside | PASS | electronics & hardware dir 1 · every row CE: True |
| 70 | page errors | F3 rotation | 1366x768 | inside | PASS | none |
| 71 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 266 -> 0 (max 798) |
| 72 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | inside | PASS | 0 -> 532 |
| 73 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | inside | PASS | top 798 of max 798 (a page that snaps to whole rows may stop one row short) |
| 74 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | inside | PASS | top 0 |
| 75 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 308 -> 0 |
| 76 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | inside | PASS | -> 200 -> 0 |
| 77 | F2 board scrollbar - thumb visible | F2 sectors | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 78 | F2 board row click opens the sector in place | F2 sectors | 1366x768 | inside | PASS | open auto · list bottom 564 · next row top 570 |
| 79 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1366x768 | inside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 80 | every visible share name - click loads the pane, the list stays | F2 sectors | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 81 | J through the whole list (pane follows) | F2 sectors | 1366x768 | inside | PASS | J x7 -> MOTHERSON (last row MOTHERSON) |
| 82 | K back up | F2 sectors | 1366x768 | inside | PASS | K x7 -> M&M |
| 83 | ↓ / ↑ move share to share | F2 sectors | 1366x768 | inside | PASS | ↓ MARUTI · ↑ M&M |
| 84 | J / K after a click in the pane | F2 sectors | 1366x768 | inside | PASS | J MARUTI · K M&M |
| 85 | pane share name - single click | F2 sectors | 1366x768 | inside | PASS | still M&M on sectors#sd=auto&r=M%26M&y=180 |
| 86 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 150 -> 0 (max 508) |
| 87 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | inside | PASS | 0 -> 300 |
| 88 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | inside | PASS | top 508 of max 508 (a page that snaps to whole rows may stop one row short) |
| 89 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | inside | PASS | top 0 |
| 90 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | inside | PASS | 0 -> 355 -> 0 |
| 91 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 92 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | inside | PASS | -> 200 -> 0 |
| 93 | pane scrollbar - thumb visible | F2 sectors | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 94 | W why + Esc | F2 sectors | 1366x768 | inside | PASS | open True · after Esc open False · share still M&M |
| 95 | Space plan card + Esc | F2 sectors | 1366x768 | inside | PASS | open True · after Esc False |
| 96 | pane button W why, then ✕ | F2 sectors | 1366x768 | inside | PASS | open True · closed True |
| 97 | pane button Space plan, then ✕ | F2 sectors | 1366x768 | inside | PASS | open True |
| 98 | P pin (toggle) | F2 sectors | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 99 | Pin toast sits above the action bar, below the share name | F2 sectors | 1366x768 | inside | PASS | toast 599-647 · action bar top 653 · name bottom 287 |
| 100 | Pin button (action bar) | F2 sectors | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 101 | Copy contract (clipboard only) | F2 sectors | 1366x768 | inside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 102 | Copy button shows the size | F2 sectors | 1366x768 | inside | PASS | Copy 3,500 CE · 0 lots |
| 103 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 104 | December strikes only (rows + trade box) | F2 sectors | 1366x768 | inside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 105 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1366x768 | inside | PASS | sector line True · pane True |
| 106 | ATM ★ only on a strike he could take | F2 sectors | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 107 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 108 | no repeated dashes; the reason shown once | F2 sectors | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 109 | F2 heat-map tile opens that sector in the board | F2 sectors | 1366x768 | inside | PASS | tile consumer durables -> open consumer durables · in view True |
| 110 | F2: the share pane sits in the right column | F2 sectors | 1366x768 | inside | PASS | pane host #call |
| 111 | F2 keys 1-9 | F2 sectors | 1366x768 | inside | PASS | 2 -> cables & wires (row 2 = cables & wires) |
| 112 | page errors | F2 sectors | 1366x768 | inside | PASS | none |
| 113 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1366x768 | inside | PASS | chip auto -> open auto |
| 114 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1366x768 | inside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 115 | every visible share name - click loads the pane, the list stays | F1 desk | 1366x768 | inside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 116 | J through the whole list (pane follows) | F1 desk | 1366x768 | inside | PASS | J x7 -> MOTHERSON (last row MOTHERSON) |
| 117 | K back up | F1 desk | 1366x768 | inside | PASS | K x7 -> M&M |
| 118 | ↓ / ↑ move share to share | F1 desk | 1366x768 | inside | PASS | ↓ MARUTI · ↑ M&M |
| 119 | J / K after a click in the pane | F1 desk | 1366x768 | inside | PASS | J MARUTI · K M&M |
| 120 | pane share name - single click | F1 desk | 1366x768 | inside | PASS | still M&M on desk-hunt#sd=auto&r=M%26M&y=0 |
| 121 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 132 -> 0 (max 430) |
| 122 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1366x768 | inside | PASS | 0 -> 265 |
| 123 | pane scrollbar - drag past the end, off the rail | F1 desk | 1366x768 | inside | PASS | top 430 of max 430 (a page that snaps to whole rows may stop one row short) |
| 124 | pane scrollbar - drag past the top, off the rail | F1 desk | 1366x768 | inside | PASS | top 0 |
| 125 | pane scrollbar - track click below, then above the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 376 -> 0 |
| 126 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 127 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | inside | PASS | -> 200 -> 0 |
| 128 | pane scrollbar - thumb visible | F1 desk | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 129 | W why + Esc | F1 desk | 1366x768 | inside | PASS | open True · after Esc open False · share still M&M |
| 130 | Space plan card + Esc | F1 desk | 1366x768 | inside | PASS | open True · after Esc False |
| 131 | pane button W why, then ✕ | F1 desk | 1366x768 | inside | PASS | open True · closed True |
| 132 | pane button Space plan, then ✕ | F1 desk | 1366x768 | inside | PASS | open True |
| 133 | P pin (toggle) | F1 desk | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 134 | Pin toast sits above the action bar, below the share name | F1 desk | 1366x768 | inside | PASS | toast 629-677 · action bar top 683 · name bottom 289 |
| 135 | Pin button (action bar) | F1 desk | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 136 | Copy contract (clipboard only) | F1 desk | 1366x768 | inside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 137 | Copy button shows the size | F1 desk | 1366x768 | inside | PASS | Copy 3,500 CE · 0 lots |
| 138 | signal only: no order / buy button, the Kite line shown | F1 desk | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 139 | December strikes only (rows + trade box) | F1 desk | 1366x768 | inside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 140 | "Expiry week · physical settlement - December only" warning | F1 desk | 1366x768 | inside | PASS | sector line True · pane True |
| 141 | ATM ★ only on a strike he could take | F1 desk | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 142 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 143 | no repeated dashes; the reason shown once | F1 desk | 1366x768 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 144 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 33 -> 0 (max 33) |
| 145 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1366x768 | inside | PASS | 0 -> 33 |
| 146 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1366x768 | inside | PASS | top 33 of max 33 (a page that snaps to whole rows may stop one row short) |
| 147 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1366x768 | inside | PASS | top 0 |
| 148 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1366x768 | inside | PASS | 0 -> 33 -> 0 |
| 149 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1366x768 | inside | PASS | 0 -> 33 -> 0 |
| 150 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | inside | PASS | -> 33 -> 0 |
| 151 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 152 | F1 Esc closes back to the Desk | F1 desk | 1366x768 | inside | PASS | open None · members panel back |
| 153 | page errors | F1 desk | 1366x768 | inside | PASS | none |
| 154 | Morning sector card opens the same component | Morning | 1366x768 | inside | PASS | card cables & wires -> open cables & wires |
| 155 | Morning: "pre-open - not live" with the session date (not shown as today) | Morning | 1366x768 | inside | PASS | ['pre-open - not live · 19 Nov 15:30 close', True, True] |
| 156 | every visible share name - click loads the pane, the list stays | Morning | 1366x768 | inside | PASS | 3 names clicked, wrong: [] · list visible: True |
| 157 | J through the whole list (pane follows) | Morning | 1366x768 | inside | PASS | J x2 -> KEI (last row KEI) |
| 158 | K back up | Morning | 1366x768 | inside | PASS | K x2 -> HAVELLS |
| 159 | ↓ / ↑ move share to share | Morning | 1366x768 | inside | PASS | ↓ POLYCAB · ↑ HAVELLS |
| 160 | J / K after a click in the pane | Morning | 1366x768 | inside | PASS | J POLYCAB · K HAVELLS |
| 161 | pane share name - single click | Morning | 1366x768 | inside | PASS | still HAVELLS on morning#sd=cables%20%26%20wires&r=HAVELL |
| 162 | pane scrollbar - slow mouse drag of the thumb | Morning | 1366x768 | inside | PASS | 0 -> 185 -> 0 (max 588) |
| 163 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1366x768 | inside | PASS | 0 -> 369 |
| 164 | pane scrollbar - drag past the end, off the rail | Morning | 1366x768 | inside | PASS | top 588 of max 588 (a page that snaps to whole rows may stop one row short) |
| 165 | pane scrollbar - drag past the top, off the rail | Morning | 1366x768 | inside | PASS | top 0 |
| 166 | pane scrollbar - track click below, then above the thumb | Morning | 1366x768 | inside | PASS | 0 -> 300 -> 0 |
| 167 | pane scrollbar - ▼ then ▲ buttons | Morning | 1366x768 | inside | PASS | 0 -> 66 -> 0 |
| 168 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1366x768 | inside | PASS | -> 200 -> 0 |
| 169 | pane scrollbar - thumb visible | Morning | 1366x768 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 170 | W why + Esc | Morning | 1366x768 | inside | PASS | open True · after Esc open False · share still HAVELLS |
| 171 | Space plan card + Esc | Morning | 1366x768 | inside | PASS | open True · after Esc False |
| 172 | pane button W why, then ✕ | Morning | 1366x768 | inside | PASS | open True · closed True |
| 173 | pane button Space plan, then ✕ | Morning | 1366x768 | inside | PASS | open True |
| 174 | P pin (toggle) | Morning | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 175 | Pin toast sits above the action bar, below the share name | Morning | 1366x768 | inside | PASS | toast 599-647 · action bar top 653 · name bottom 348 |
| 176 | Pin button (action bar) | Morning | 1366x768 | inside | PASS | pins 0 -> 1 -> 0 |
| 177 | Copy contract (clipboard only) | Morning | 1366x768 | inside | PASS | clipboard "HAVELLS26DEC1200CE" · button "Copy 1,200 CE · 0 lots" · toast "Copied HAVELLS26DEC1200CE · 0 lots - you place the order in Kite" |
| 178 | Copy button shows the size | Morning | 1366x768 | inside | PASS | Copy 1,200 CE · 0 lots |
| 179 | signal only: no order / buy button, the Kite line shown | Morning | 1366x768 | inside | PASS | line shown True · order-like buttons [] |
| 180 | December strikes only (rows + trade box) | Morning | 1366x768 | inside | PASS | 3 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 181 | "Expiry week · physical settlement - December only" warning | Morning | 1366x768 | inside | PASS | sector line True · pane True |
| 182 | ATM ★ only on a strike he could take | Morning | 1366x768 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 183 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1366x768 | inside | PASS | checked rows · mismatches [] |
| 184 | no repeated dashes; the reason shown once | Morning | 1366x768 | inside | PASS | 0 lone dashes · "not known" x2 in the list |
| 185 | page errors | Morning | 1366x768 | inside | PASS | none |
| 186 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 156 -> 0 (max 592) |
| 187 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 0 -> 313 |
| 188 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 578 of max 592 (a page that snaps to whole rows may stop one row short) |
| 189 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 190 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 283 -> 147 |
| 191 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1600x900 | inside | PASS | 147 -> 259 -> 148 |
| 192 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 348 -> 148 |
| 193 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 194 | F3 table row click opens the sector | F3 rotation | 1600x900 | inside | PASS | open banks in 12 ms (from the cached store) |
| 195 | opens under 100 ms | F3 rotation | 1600x900 | inside | PASS | 12 ms |
| 196 | the open list pushes the rows below (no overprint) | F3 rotation | 1600x900 | inside | PASS | list bottom 817 · next sector row top 823 |
| 197 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1600x900 | inside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 198 | every visible share name - click loads the pane, the list stays | F3 rotation | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 199 | J through the whole list (pane follows) | F3 rotation | 1600x900 | inside | PASS | J x11 -> INDUSINDBK (last row INDUSINDBK) |
| 200 | K back up | F3 rotation | 1600x900 | inside | PASS | K x11 -> IDFCFIRSTB |
| 201 | ↓ / ↑ move share to share | F3 rotation | 1600x900 | inside | PASS | ↓ PNB · ↑ IDFCFIRSTB |
| 202 | J / K after a click in the pane | F3 rotation | 1600x900 | inside | PASS | J PNB · K IDFCFIRSTB |
| 203 | pane share name - single click | F3 rotation | 1600x900 | inside | PASS | still IDFCFIRSTB on rotation#sd=banks&r=IDFCFIRSTB&y=224 |
| 204 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 148 -> 0 (max 492) |
| 205 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 0 -> 295 |
| 206 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 492 of max 492 (a page that snaps to whole rows may stop one row short) |
| 207 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 208 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 356 -> 1 |
| 209 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1600x900 | inside | PASS | 1 -> 67 -> 1 |
| 210 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 201 -> 1 |
| 211 | pane scrollbar - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 212 | W why + Esc | F3 rotation | 1600x900 | inside | PASS | open True · after Esc open False · share still IDFCFIRSTB |
| 213 | Space plan card + Esc | F3 rotation | 1600x900 | inside | PASS | open True · after Esc False |
| 214 | pane button W why, then ✕ | F3 rotation | 1600x900 | inside | PASS | open True · closed True |
| 215 | pane button Space plan, then ✕ | F3 rotation | 1600x900 | inside | PASS | open True |
| 216 | P pin (toggle) | F3 rotation | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 217 | Pin toast sits above the action bar, below the share name | F3 rotation | 1600x900 | inside | PASS | toast 761-809 · action bar top 815 · name bottom 419 |
| 218 | Pin button (action bar) | F3 rotation | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 219 | Copy contract (clipboard only) | F3 rotation | 1600x900 | inside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · button "Copy 86 CE · 0 lots" · toast "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in Kite" |
| 220 | Copy button shows the size | F3 rotation | 1600x900 | inside | PASS | Copy 86 CE · 0 lots |
| 221 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 222 | December strikes only (rows + trade box) | F3 rotation | 1600x900 | inside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 223 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1600x900 | inside | PASS | sector line True · pane True |
| 224 | ATM ★ only on a strike he could take | F3 rotation | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 225 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 226 | no repeated dashes; the reason shown once | F3 rotation | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 227 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1600x900 | inside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[468, 537], [428, 497], [388, 457], [387, 417], [387, 377], [387, 337]] |
| 228 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | inside | PASS | 344 -> 524 -> 345 (max 937) |
| 229 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | inside | PASS | 345 -> 703 |
| 230 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1600x900 | inside | PASS | top 919 of max 937 (a page that snaps to whole rows may stop one row short) |
| 231 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1600x900 | inside | PASS | top 0 |
| 232 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1600x900 | inside | PASS | 0 -> 378 -> 224 |
| 233 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | inside | PASS | -> 424 -> 224 |
| 234 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 235 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1600x900 | inside | PASS | rows 12 -> 22 -> 12 |
| 236 | basis › (the basis in full, R49) | F3 rotation | 1600x900 | inside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 237 | "n more listed, not F&O" fold line | F3 rotation | 1600x900 | inside | PASS | "▸ 12 more listed, not F&O · ▲8 ▼4 · wt 5% · context only, no strike" -> open, then closed |
| 238 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1600x900 | inside | PASS | went share?s=AXISBANK · back: open banks, row AXISBANK, expanded True |
| 239 | after Back, J still moves | F3 rotation | 1600x900 | inside | PASS | AXISBANK -> INDUSINDBK |
| 240 | O opens the option chain at the December strike; Back | F3 rotation | 1600x900 | inside | PASS | chain?s=INDUSINDBK&exp=2026-12-29&k=920&side=CE · back on INDUSINDBK |
| 241 | double-click the pane share name -> F7, Back | F3 rotation | 1600x900 | inside | PASS | share?s=INDUSINDBK |
| 242 | Enter on a share row -> F7 | F3 rotation | 1600x900 | inside | PASS | share?s=INDUSINDBK |
| 243 | Esc closes step by step | F3 rotation | 1600x900 | inside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 244 | O / W with no share selected | F3 rotation | 1600x900 | inside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 245 | keys 1-9 pick a sector | F3 rotation | 1600x900 | inside | PASS | 3 -> fmcg (row 3 = fmcg) · 1 -> auto (row 1 = auto) |
| 246 | Tab to a sector row + Enter opens it | F3 rotation | 1600x900 | inside | PASS | focused auto after 3 Tab · open auto |
| 247 | R key (apply re-rank) | F3 rotation | 1600x900 | inside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 248 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1600x900 | inside | NOT RUN | needs live ticks: the market is closed (store holds the 19 Nov close); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 249 | money-flow band: a sector name opens it in the table below | F3 rotation | 1600x900 | inside | PASS | clicked it -> open it, list visible True |
| 250 | "moving, but not this rotation" row opens that sector | F3 rotation | 1600x900 | inside | PASS | clicked consumer durables -> open consumer durables |
| 251 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1600x900 | inside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 252 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1600x900 | inside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 253 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1600x900 | inside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 254 | up-side shown: a rising sector shows CE strikes on its groups | F3 rotation | 1600x900 | inside | PASS | electronics & hardware dir 1 · every row CE: True |
| 255 | page errors | F3 rotation | 1600x900 | inside | PASS | none |
| 256 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 167 -> 0 (max 666) |
| 257 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | inside | PASS | 0 -> 334 |
| 258 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | inside | PASS | top 666 of max 666 (a page that snaps to whole rows may stop one row short) |
| 259 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | inside | PASS | top 0 |
| 260 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 559 -> 0 |
| 261 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | inside | PASS | -> 200 -> 0 |
| 262 | F2 board scrollbar - thumb visible | F2 sectors | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 263 | F2 board row click opens the sector in place | F2 sectors | 1600x900 | inside | PASS | open auto · list bottom 661 · next row top 667 |
| 264 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1600x900 | inside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 265 | every visible share name - click loads the pane, the list stays | F2 sectors | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 266 | J through the whole list (pane follows) | F2 sectors | 1600x900 | inside | PASS | J x11 -> ASHOKLEY (last row ASHOKLEY) |
| 267 | K back up | F2 sectors | 1600x900 | inside | PASS | K x11 -> M&M |
| 268 | ↓ / ↑ move share to share | F2 sectors | 1600x900 | inside | PASS | ↓ MARUTI · ↑ M&M |
| 269 | J / K after a click in the pane | F2 sectors | 1600x900 | inside | PASS | J MARUTI · K M&M |
| 270 | pane share name - single click | F2 sectors | 1600x900 | inside | PASS | still M&M on sectors#sd=auto&r=M%26M&y=180 |
| 271 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 106 -> 0 (max 343) |
| 272 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | inside | PASS | 0 -> 212 |
| 273 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | inside | PASS | top 343 of max 343 (a page that snaps to whole rows may stop one row short) |
| 274 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | inside | PASS | top 0 |
| 275 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | inside | PASS | 0 -> 343 -> 0 |
| 276 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 277 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | inside | PASS | -> 200 -> 0 |
| 278 | pane scrollbar - thumb visible | F2 sectors | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 279 | W why + Esc | F2 sectors | 1600x900 | inside | PASS | open True · after Esc open False · share still M&M |
| 280 | Space plan card + Esc | F2 sectors | 1600x900 | inside | PASS | open True · after Esc False |
| 281 | pane button W why, then ✕ | F2 sectors | 1600x900 | inside | PASS | open True · closed True |
| 282 | pane button Space plan, then ✕ | F2 sectors | 1600x900 | inside | PASS | open True |
| 283 | P pin (toggle) | F2 sectors | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 284 | Pin toast sits above the action bar, below the share name | F2 sectors | 1600x900 | inside | PASS | toast 760-808 · action bar top 814 · name bottom 288 |
| 285 | Pin button (action bar) | F2 sectors | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 286 | Copy contract (clipboard only) | F2 sectors | 1600x900 | inside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 287 | Copy button shows the size | F2 sectors | 1600x900 | inside | PASS | Copy 3,500 CE · 0 lots |
| 288 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 289 | December strikes only (rows + trade box) | F2 sectors | 1600x900 | inside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 290 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1600x900 | inside | PASS | sector line True · pane True |
| 291 | ATM ★ only on a strike he could take | F2 sectors | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 292 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 293 | no repeated dashes; the reason shown once | F2 sectors | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 294 | F2 heat-map tile opens that sector in the board | F2 sectors | 1600x900 | inside | PASS | tile consumer durables -> open consumer durables · in view True |
| 295 | F2: the share pane sits in the right column | F2 sectors | 1600x900 | inside | PASS | pane host #call |
| 296 | F2 keys 1-9 | F2 sectors | 1600x900 | inside | PASS | 2 -> cables & wires (row 2 = cables & wires) |
| 297 | page errors | F2 sectors | 1600x900 | inside | PASS | none |
| 298 | Morning sector card opens the same component | Morning | 1600x900 | inside | PASS | card cables & wires -> open cables & wires |
| 299 | Morning: "pre-open - not live" with the session date (not shown as today) | Morning | 1600x900 | inside | PASS | ['pre-open - not live · 19 Nov 15:30 close', True, True] |
| 300 | every visible share name - click loads the pane, the list stays | Morning | 1600x900 | inside | PASS | 3 names clicked, wrong: [] · list visible: True |
| 301 | J through the whole list (pane follows) | Morning | 1600x900 | inside | PASS | J x2 -> KEI (last row KEI) |
| 302 | K back up | Morning | 1600x900 | inside | PASS | K x2 -> HAVELLS |
| 303 | ↓ / ↑ move share to share | Morning | 1600x900 | inside | PASS | ↓ POLYCAB · ↑ HAVELLS |
| 304 | J / K after a click in the pane | Morning | 1600x900 | inside | PASS | J POLYCAB · K HAVELLS |
| 305 | pane share name - single click | Morning | 1600x900 | inside | PASS | still HAVELLS on morning#sd=cables%20%26%20wires&r=HAVELL |
| 306 | pane scrollbar - slow mouse drag of the thumb | Morning | 1600x900 | inside | PASS | 0 -> 176 -> 0 (max 551) |
| 307 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1600x900 | inside | PASS | 0 -> 352 |
| 308 | pane scrollbar - drag past the end, off the rail | Morning | 1600x900 | inside | PASS | top 551 of max 551 (a page that snaps to whole rows may stop one row short) |
| 309 | pane scrollbar - drag past the top, off the rail | Morning | 1600x900 | inside | PASS | top 0 |
| 310 | pane scrollbar - track click below, then above the thumb | Morning | 1600x900 | inside | PASS | 0 -> 302 -> 0 |
| 311 | pane scrollbar - ▼ then ▲ buttons | Morning | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 312 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1600x900 | inside | PASS | -> 200 -> 0 |
| 313 | pane scrollbar - thumb visible | Morning | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 314 | W why + Esc | Morning | 1600x900 | inside | PASS | open True · after Esc open False · share still HAVELLS |
| 315 | Space plan card + Esc | Morning | 1600x900 | inside | PASS | open True · after Esc False |
| 316 | pane button W why, then ✕ | Morning | 1600x900 | inside | PASS | open True · closed True |
| 317 | pane button Space plan, then ✕ | Morning | 1600x900 | inside | PASS | open True |
| 318 | P pin (toggle) | Morning | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 319 | Pin toast sits above the action bar, below the share name | Morning | 1600x900 | inside | PASS | toast 760-808 · action bar top 814 · name bottom 477 |
| 320 | Pin button (action bar) | Morning | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 321 | Copy contract (clipboard only) | Morning | 1600x900 | inside | PASS | clipboard "HAVELLS26DEC1200CE" · button "Copy 1,200 CE · 0 lots" · toast "Copied HAVELLS26DEC1200CE · 0 lots - you place the order in Kite" |
| 322 | Copy button shows the size | Morning | 1600x900 | inside | PASS | Copy 1,200 CE · 0 lots |
| 323 | signal only: no order / buy button, the Kite line shown | Morning | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 324 | December strikes only (rows + trade box) | Morning | 1600x900 | inside | PASS | 3 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 325 | "Expiry week · physical settlement - December only" warning | Morning | 1600x900 | inside | PASS | sector line True · pane True |
| 326 | ATM ★ only on a strike he could take | Morning | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 327 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 328 | no repeated dashes; the reason shown once | Morning | 1600x900 | inside | PASS | 0 lone dashes · "not known" x2 in the list |
| 329 | page errors | Morning | 1600x900 | inside | PASS | none |
| 330 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1600x900 | inside | PASS | chip auto -> open auto |
| 331 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1600x900 | inside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 332 | every visible share name - click loads the pane, the list stays | F1 desk | 1600x900 | inside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 333 | J through the whole list (pane follows) | F1 desk | 1600x900 | inside | PASS | J x11 -> ASHOKLEY (last row ASHOKLEY) |
| 334 | K back up | F1 desk | 1600x900 | inside | PASS | K x11 -> M&M |
| 335 | ↓ / ↑ move share to share | F1 desk | 1600x900 | inside | PASS | ↓ MARUTI · ↑ M&M |
| 336 | J / K after a click in the pane | F1 desk | 1600x900 | inside | PASS | J MARUTI · K M&M |
| 337 | pane share name - single click | F1 desk | 1600x900 | inside | PASS | still M&M on desk-hunt#sd=auto&r=M%26M&y=0 |
| 338 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 93 -> 0 (max 246) |
| 339 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1600x900 | inside | PASS | 0 -> 186 |
| 340 | pane scrollbar - drag past the end, off the rail | F1 desk | 1600x900 | inside | PASS | top 246 of max 246 (a page that snaps to whole rows may stop one row short) |
| 341 | pane scrollbar - drag past the top, off the rail | F1 desk | 1600x900 | inside | PASS | top 0 |
| 342 | pane scrollbar - track click below, then above the thumb | F1 desk | 1600x900 | inside | PASS | 0 -> 246 -> 0 |
| 343 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1600x900 | inside | PASS | 0 -> 66 -> 0 |
| 344 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | inside | PASS | -> 200 -> 0 |
| 345 | pane scrollbar - thumb visible | F1 desk | 1600x900 | inside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 346 | W why + Esc | F1 desk | 1600x900 | inside | PASS | open True · after Esc open False · share still M&M |
| 347 | Space plan card + Esc | F1 desk | 1600x900 | inside | PASS | open True · after Esc False |
| 348 | pane button W why, then ✕ | F1 desk | 1600x900 | inside | PASS | open True · closed True |
| 349 | pane button Space plan, then ✕ | F1 desk | 1600x900 | inside | PASS | open True |
| 350 | P pin (toggle) | F1 desk | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 351 | Pin toast sits above the action bar, below the share name | F1 desk | 1600x900 | inside | PASS | toast 761-809 · action bar top 815 · name bottom 268 |
| 352 | Pin button (action bar) | F1 desk | 1600x900 | inside | PASS | pins 0 -> 1 -> 0 |
| 353 | Copy contract (clipboard only) | F1 desk | 1600x900 | inside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 354 | Copy button shows the size | F1 desk | 1600x900 | inside | PASS | Copy 3,500 CE · 0 lots |
| 355 | signal only: no order / buy button, the Kite line shown | F1 desk | 1600x900 | inside | PASS | line shown True · order-like buttons [] |
| 356 | December strikes only (rows + trade box) | F1 desk | 1600x900 | inside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 357 | "Expiry week · physical settlement - December only" warning | F1 desk | 1600x900 | inside | PASS | sector line True · pane True |
| 358 | ATM ★ only on a strike he could take | F1 desk | 1600x900 | inside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 359 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1600x900 | inside | PASS | checked rows · mismatches [] |
| 360 | no repeated dashes; the reason shown once | F1 desk | 1600x900 | inside | PASS | 0 lone dashes · "not known" x1 in the list |
| 361 | F1 sector list scrollbar (dock) | F1 desk | 1600x900 | inside | PASS | every row fits at this size (all 17 F&O rows + the not-F&O line shown): the drawn bar shows a full 624 px thumb of 624, 11 px wide - nothing to drag |
| 362 | F1 Esc closes back to the Desk | F1 desk | 1600x900 | inside | PASS | open None · members panel back |
| 363 | page errors | F1 desk | 1600x900 | inside | PASS | none |
| 364 | tap a sector row opens the full-screen list sheet | F3 rotation | 390x844 | inside | PASS | open banks · built in 31 ms · tap-to-sheet 128 ms |
| 365 | sheet header (sector line) <= 2 lines + WHY | F3 rotation | 390x844 | inside | PASS | line 1 46 px, whole header 179 px |
| 366 | sheet rail size (touch target >= 24, track and thumb >= 10) | F3 rotation | 390x844 | inside | PASS | target 26 · track 13 · thumb 13 px |
| 367 | list sheet - finger swipe | F3 rotation | 390x844 | inside | PASS | 0 -> 447 -> 191 |
| 368 | list sheet - rail thumb, finger drag | F3 rotation | 390x844 | inside | PASS | 191 -> 403 · share opened: None |
| 369 | list sheet - rail drag, 8 px contact | F3 rotation | 390x844 | inside | PASS | 403 -> 191 |
| 370 | list sheet - rail drag at its right edge | F3 rotation | 390x844 | inside | PASS | 191 -> 368 |
| 371 | list sheet - rail track tap | F3 rotation | 390x844 | inside | PASS | 368 -> 302 |
| 372 | list sheet - rail, mouse drag (one mouse check) | F3 rotation | 390x844 | inside | PASS | 302 -> 443 |
| 373 | fast flick, then a tap still opens the row | F3 rotation | 390x844 | inside | PASS | flick then tap KOTAKBANK -> share sheet True (KOTAKBANK) |
| 374 | "n more listed, not F&O" (finger) | F3 rotation | 390x844 | inside | PASS | open True · closed True |
| 375 | basis › (finger) | F3 rotation | 390x844 | inside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 376 | tap a share opens the share sheet | F3 rotation | 390x844 | inside | PASS | IDFCFIRSTB -> sheet True |
| 377 | share sheet - finger swipe | F3 rotation | 390x844 | inside | PASS | 0 -> 184 |
| 378 | share sheet - action bar sticky, shows the size | F3 rotation | 390x844 | inside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy 86 CE · 0 lots" |
| 379 | share sheet - rail thumb, finger drag | F3 rotation | 390x844 | inside | PASS | 0 -> 185 |
| 380 | share sheet - rail track tap | F3 rotation | 390x844 | inside | PASS | 185 -> 119 |
| 381 | WHY › (share sheet) | F3 rotation | 390x844 | inside | PASS | open True · closed True |
| 382 | Copy contract (finger, first view) | F3 rotation | 390x844 | inside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in" |
| 383 | Pin (toggle, n/5) (finger) | F3 rotation | 390x844 | inside | PASS | 0 -> 1 -> 0 |
| 384 | Pin toast above the action bar, not over the share name | F3 rotation | 390x844 | inside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 385 | ‹ Sector (Back button on the share sheet) | F3 rotation | 390x844 | inside | PASS | list sheet True · share sheet False |
| 386 | device / browser Back (share sheet -> list) | F3 rotation | 390x844 | inside | PASS | list True · share False |
| 387 | device / browser Back (list -> page) | F3 rotation | 390x844 | inside | PASS | sheet False · open None |
| 388 | ‹ Sectors (Back button on the list sheet) | F3 rotation | 390x844 | inside | PASS | sheet closed True |
| 389 | page errors | F3 rotation | 390x844 | inside | PASS | none |
| 390 | tap a sector row opens the full-screen list sheet | F2 sectors | 390x844 | inside | PASS | open auto · built in 21 ms · tap-to-sheet 82 ms |
| 391 | sheet header (sector line) <= 2 lines + WHY | F2 sectors | 390x844 | inside | PASS | line 1 46 px, whole header 179 px |
| 392 | sheet rail size (touch target >= 24, track and thumb >= 10) | F2 sectors | 390x844 | inside | PASS | target 26 · track 13 · thumb 13 px |
| 393 | list sheet - finger swipe | F2 sectors | 390x844 | inside | PASS | 0 -> 299 -> 51 |
| 394 | list sheet - rail thumb, finger drag | F2 sectors | 390x844 | inside | PASS | 51 -> 228 · share opened: None |
| 395 | list sheet - rail drag, 8 px contact | F2 sectors | 390x844 | inside | PASS | 228 -> 51 |
| 396 | list sheet - rail drag at its right edge | F2 sectors | 390x844 | inside | PASS | 51 -> 198 |
| 397 | list sheet - rail track tap | F2 sectors | 390x844 | inside | PASS | 198 -> 132 |
| 398 | list sheet - rail, mouse drag (one mouse check) | F2 sectors | 390x844 | inside | PASS | 132 -> 250 |
| 399 | fast flick, then a tap still opens the row | F2 sectors | 390x844 | inside | PASS | flick then tap TVSMOTOR -> share sheet True (TVSMOTOR) |
| 400 | "n more listed, not F&O" (finger) | F2 sectors | 390x844 | inside | PASS | open True · closed True |
| 401 | basis › (finger) | F2 sectors | 390x844 | inside | PASS | basis (R49) whole sector: 50 listed shares, market-cap weighted (NSE m |
| 402 | tap a share opens the share sheet | F2 sectors | 390x844 | inside | PASS | M&M -> sheet True |
| 403 | share sheet - finger swipe | F2 sectors | 390x844 | inside | PASS | 0 -> 165 |
| 404 | share sheet - action bar sticky, shows the size | F2 sectors | 390x844 | inside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy 3,500 CE · 0 lots" |
| 405 | share sheet - rail thumb, finger drag | F2 sectors | 390x844 | inside | PASS | 0 -> 166 |
| 406 | share sheet - rail track tap | F2 sectors | 390x844 | inside | PASS | 166 -> 100 |
| 407 | WHY › (share sheet) | F2 sectors | 390x844 | inside | PASS | open True · closed True |
| 408 | Copy contract (finger, first view) | F2 sectors | 390x844 | inside | PASS | clipboard "M&M26DEC3500CE" · "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 409 | Pin (toggle, n/5) (finger) | F2 sectors | 390x844 | inside | PASS | 0 -> 1 -> 0 |
| 410 | Pin toast above the action bar, not over the share name | F2 sectors | 390x844 | inside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 411 | ‹ Sector (Back button on the share sheet) | F2 sectors | 390x844 | inside | PASS | list sheet True · share sheet False |
| 412 | device / browser Back (share sheet -> list) | F2 sectors | 390x844 | inside | PASS | list True · share False |
| 413 | device / browser Back (list -> page) | F2 sectors | 390x844 | inside | PASS | sheet False · open None |
| 414 | ‹ Sectors (Back button on the list sheet) | F2 sectors | 390x844 | inside | PASS | sheet closed True |
| 415 | page errors | F2 sectors | 390x844 | inside | PASS | none |
| 416 | six groups only | shared module (F3 page) | rules | inside | PASS | 230 members in 26 sectors · bad:  |
| 417 | COMING UP = 4 gates and not EXTENDED | shared module (F3 page) | rules | inside | PASS | M&M HINDALCO DELHIVERY |
| 418 | COMING UP score (on 0.60 / off 0.45) | shared module (F3 page) | rules | inside | PASS |  |
| 419 | EXTENDED rule | shared module (F3 page) | rules | inside | PASS | 57 extended |
| 420 | LAGGARD only at breadth >= 70% | shared module (F3 page) | rules | inside | PASS | laggards: DATAPATTNS NAUKRI ETERNAL JUBLFOOD GODREJPROP PRESTIGE |
| 421 | "no laggard" sectors | shared module (F3 page) | rules | inside | PASS | construction 52%, nbfc & finance 52%, capital goods 69%, jewellers & gold loans 60%, metals & mining 68%, chemicals 55%, hospitals & diagnostics 53%, services 50%, oil producers 50%, capital markets 50%, pharma 68%, telecom services 63%, it 59% |
| 422 | one LEADER per sector | shared module (F3 page) | rules | inside | PASS |  |
| 423 | LEADER group = extended or a gate fails | shared module (F3 page) | rules | inside | PASS |  |
| 424 | AGAINST rule | shared module (F3 page) | rules | inside | PASS | RADICO VBL KARURVYSYA UJJIVANSFB MANAPPURAM MUTHOOTFIN POLICYBZR PAYTM BAJFINANCE PREMIERENE COCHINSHIP INOXWIND POWERINDIA ADANIENSOL MUTHOOTFIN NATIONALUM VEDL APLAPOLLO MFSL NAVINFLUOR ONGC INDIGO APOLLOHOSP GMRAIRPORT INDIGO CDSL MCX HDFCAMC LAURUSLABS ALKEM GLENMARK BHARTIARTL KPITTECH PERSISTENT TATAELXSI OFSS |
| 425 | LAGGARD shows its trigger price | shared module (F3 page) | rules | inside | PASS |  |
| 426 | CE on a rising sector, PE on a falling one (AGAINST flips) | shared module (F3 page) | rules | inside | PASS |  |
| 427 | December strikes only | shared module (F3 page) | rules | inside | PASS | not December: none · no December chain: IREDA IEX |
| 428 | pre-open now: 0 lots everywhere | shared module (F3 page) | rules | inside | PASS | 0 lots · pre-open - not live |
| 429 | BAN hard block | shared module (F3 page) | rules | inside | PASS | KAYNES nt BAN - only close existing |
| 430 | STALE hard block | shared module (F3 page) | rules | inside | PASS | 0 stale now |
| 431 | what-if live: R:R < 1 after costs -> 0 lots | shared module (F3 page) | rules | inside | PASS | 96 plans held at 0 lots by R:R |
| 432 | what-if live: one lot above 1R -> 0 lots | shared module (F3 page) | rules | inside | PASS | 16 plans held at 0 lots by 1R |
| 433 | what-if live: WAITING / NOT TRADABLE -> 0 lots | shared module (F3 page) | rules | inside | PASS |  |
| 434 | what-if live: the star / takeable follows the lots | shared module (F3 page) | rules | inside | PASS | VBL 3 @1R 2000 · VEDL 4 @1R 2000 · VOLTAS 1 @1R 5000 · MARUTI 1 @1R 5000 · VBL 8 @1R 5000 · MUTHOOTFIN 1 @1R 5000 · POWERINDIA 1 @1R 5000 · MUTHOOTFIN 1 @1R 5000 |
| 435 | what-if live: lots fit the lock room | shared module (F3 page) | rules | inside | PASS |  |
| 436 | what-if: LOCKED blocks every new trade | shared module (F3 page) | rules | inside | PASS | 230 plans · LOCKED - no new trades today |
| 437 | non-F&O fold counts from all listed | shared module (F3 page) | rules | inside | PASS | consumer durables 30 · cables & wires 1 · electronics & hardware 3 · auto 33 · construction 20 · fmcg 30 |
| 438 | basis named (R49) | shared module (F3 page) | rules | inside | PASS | whole sector: 37 listed shares · driver group: its 4 named memb |
| 439 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 205 -> 1 (max 612) |
| 440 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 1 -> 410 |
| 441 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 612 of max 612 (a page that snaps to whole rows may stop one row short) |
| 442 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 443 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 267 -> 159 |
| 444 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1366x768 | outside | PASS | 159 -> 272 -> 170 |
| 445 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 370 -> 170 |
| 446 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 447 | F3 table row click opens the sector | F3 rotation | 1366x768 | outside | PASS | open banks in 8 ms (from the cached store) |
| 448 | opens under 100 ms | F3 rotation | 1366x768 | outside | PASS | 8 ms |
| 449 | the open list pushes the rows below (no overprint) | F3 rotation | 1366x768 | outside | PASS | list bottom 721 · next sector row top 727 |
| 450 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1366x768 | outside | PASS | 8 whole rows (need 8) of 22 members · +n more bar: True |
| 451 | every visible share name - click loads the pane, the list stays | F3 rotation | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 452 | J through the whole list (pane follows) | F3 rotation | 1366x768 | outside | PASS | J x7 -> SBIN (last row SBIN) |
| 453 | K back up | F3 rotation | 1366x768 | outside | PASS | K x7 -> IDFCFIRSTB |
| 454 | ↓ / ↑ move share to share | F3 rotation | 1366x768 | outside | PASS | ↓ PNB · ↑ IDFCFIRSTB |
| 455 | J / K after a click in the pane | F3 rotation | 1366x768 | outside | PASS | J PNB · K IDFCFIRSTB |
| 456 | pane share name - single click | F3 rotation | 1366x768 | outside | PASS | still IDFCFIRSTB on rotation#sd=banks&r=IDFCFIRSTB&y=206 |
| 457 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 282 -> 0 (max 705) |
| 458 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 0 -> 564 |
| 459 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 705 of max 705 (a page that snaps to whole rows may stop one row short) |
| 460 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 461 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 211 -> 0 |
| 462 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 463 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 200 -> 0 |
| 464 | pane scrollbar - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 465 | W why + Esc | F3 rotation | 1366x768 | outside | PASS | open True · after Esc open False · share still IDFCFIRSTB |
| 466 | Space plan card + Esc | F3 rotation | 1366x768 | outside | PASS | open True · after Esc False |
| 467 | pane button W why, then ✕ | F3 rotation | 1366x768 | outside | PASS | open True · closed True |
| 468 | pane button Space plan, then ✕ | F3 rotation | 1366x768 | outside | PASS | open True |
| 469 | P pin (toggle) | F3 rotation | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 470 | Pin toast sits above the action bar, below the share name | F3 rotation | 1366x768 | outside | PASS | toast 600-648 · action bar top 654 · name bottom 419 |
| 471 | Pin button (action bar) | F3 rotation | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 472 | Copy contract (clipboard only) | F3 rotation | 1366x768 | outside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · button "Copy 86 CE · 0 lots" · toast "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in Kite" |
| 473 | Copy button shows the size | F3 rotation | 1366x768 | outside | PASS | Copy 86 CE · 0 lots |
| 474 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 475 | December strikes only (rows + trade box) | F3 rotation | 1366x768 | outside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 476 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1366x768 | outside | PASS | sector line True · pane True |
| 477 | ATM ★ only on a strike he could take | F3 rotation | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 478 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 479 | no repeated dashes; the reason shown once | F3 rotation | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 480 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1366x768 | outside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[468, 537], [428, 497], [388, 457], [387, 417], [387, 377], [387, 337]] |
| 481 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1366x768 | outside | PASS | 326 -> 544 -> 326 (max 905) |
| 482 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1366x768 | outside | PASS | 326 -> 762 |
| 483 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1366x768 | outside | PASS | top 877 of max 905 (a page that snaps to whole rows may stop one row short) |
| 484 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1366x768 | outside | PASS | top 0 |
| 485 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1366x768 | outside | PASS | 0 -> 337 -> 205 |
| 486 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1366x768 | outside | PASS | -> 405 -> 205 |
| 487 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 488 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1366x768 | outside | PASS | rows 8 -> 22 -> 8 |
| 489 | basis › (the basis in full, R49) | F3 rotation | 1366x768 | outside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 490 | "n more listed, not F&O" fold line | F3 rotation | 1366x768 | outside | PASS | "▸ 12 more listed, not F&O · ▲8 ▼4 · wt 5% · context only, no strike" -> open, then closed |
| 491 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1366x768 | outside | PASS | went share?s=AXISBANK · back: open banks, row AXISBANK, expanded True |
| 492 | after Back, J still moves | F3 rotation | 1366x768 | outside | PASS | AXISBANK -> INDUSINDBK |
| 493 | O opens the option chain at the December strike; Back | F3 rotation | 1366x768 | outside | PASS | chain?s=INDUSINDBK&exp=2026-12-29&k=920&side=CE · back on INDUSINDBK |
| 494 | double-click the pane share name -> F7, Back | F3 rotation | 1366x768 | outside | PASS | share?s=INDUSINDBK |
| 495 | Enter on a share row -> F7 | F3 rotation | 1366x768 | outside | PASS | share?s=INDUSINDBK |
| 496 | Esc closes step by step | F3 rotation | 1366x768 | outside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 497 | O / W with no share selected | F3 rotation | 1366x768 | outside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 498 | keys 1-9 pick a sector | F3 rotation | 1366x768 | outside | PASS | 3 -> fmcg (row 3 = fmcg) · 1 -> auto (row 1 = auto) |
| 499 | Tab to a sector row + Enter opens it | F3 rotation | 1366x768 | outside | PASS | focused auto after 2 Tab · open auto |
| 500 | R key (apply re-rank) | F3 rotation | 1366x768 | outside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 501 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1366x768 | outside | NOT RUN | needs live ticks: the market is closed (store holds the 19 Nov close); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 502 | money-flow band: a sector name opens it in the table below | F3 rotation | 1366x768 | outside | PASS | clicked it -> open it, list visible True |
| 503 | "moving, but not this rotation" row opens that sector | F3 rotation | 1366x768 | outside | PASS | clicked consumer durables -> open consumer durables |
| 504 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1366x768 | outside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 505 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1366x768 | outside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 506 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1366x768 | outside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 507 | up-side shown: a rising sector shows CE strikes on its groups | F3 rotation | 1366x768 | outside | PASS | electronics & hardware dir 1 · every row CE: True |
| 508 | page errors | F3 rotation | 1366x768 | outside | PASS | none |
| 509 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 266 -> 0 (max 798) |
| 510 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | outside | PASS | 0 -> 532 |
| 511 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | outside | PASS | top 798 of max 798 (a page that snaps to whole rows may stop one row short) |
| 512 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | outside | PASS | top 0 |
| 513 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 308 -> 0 |
| 514 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | outside | PASS | -> 200 -> 0 |
| 515 | F2 board scrollbar - thumb visible | F2 sectors | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 516 | F2 board row click opens the sector in place | F2 sectors | 1366x768 | outside | PASS | open auto · list bottom 564 · next row top 570 |
| 517 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1366x768 | outside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 518 | every visible share name - click loads the pane, the list stays | F2 sectors | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 519 | J through the whole list (pane follows) | F2 sectors | 1366x768 | outside | PASS | J x7 -> MOTHERSON (last row MOTHERSON) |
| 520 | K back up | F2 sectors | 1366x768 | outside | PASS | K x7 -> M&M |
| 521 | ↓ / ↑ move share to share | F2 sectors | 1366x768 | outside | PASS | ↓ MARUTI · ↑ M&M |
| 522 | J / K after a click in the pane | F2 sectors | 1366x768 | outside | PASS | J MARUTI · K M&M |
| 523 | pane share name - single click | F2 sectors | 1366x768 | outside | PASS | still M&M on sectors#sd=auto&r=M%26M&y=180 |
| 524 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 150 -> 0 (max 508) |
| 525 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1366x768 | outside | PASS | 0 -> 300 |
| 526 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1366x768 | outside | PASS | top 508 of max 508 (a page that snaps to whole rows may stop one row short) |
| 527 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1366x768 | outside | PASS | top 0 |
| 528 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1366x768 | outside | PASS | 0 -> 355 -> 0 |
| 529 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 530 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1366x768 | outside | PASS | -> 200 -> 0 |
| 531 | pane scrollbar - thumb visible | F2 sectors | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 532 | W why + Esc | F2 sectors | 1366x768 | outside | PASS | open True · after Esc open False · share still M&M |
| 533 | Space plan card + Esc | F2 sectors | 1366x768 | outside | PASS | open True · after Esc False |
| 534 | pane button W why, then ✕ | F2 sectors | 1366x768 | outside | PASS | open True · closed True |
| 535 | pane button Space plan, then ✕ | F2 sectors | 1366x768 | outside | PASS | open True |
| 536 | P pin (toggle) | F2 sectors | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 537 | Pin toast sits above the action bar, below the share name | F2 sectors | 1366x768 | outside | PASS | toast 599-647 · action bar top 653 · name bottom 287 |
| 538 | Pin button (action bar) | F2 sectors | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 539 | Copy contract (clipboard only) | F2 sectors | 1366x768 | outside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 540 | Copy button shows the size | F2 sectors | 1366x768 | outside | PASS | Copy 3,500 CE · 0 lots |
| 541 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 542 | December strikes only (rows + trade box) | F2 sectors | 1366x768 | outside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 543 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1366x768 | outside | PASS | sector line True · pane True |
| 544 | ATM ★ only on a strike he could take | F2 sectors | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 545 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 546 | no repeated dashes; the reason shown once | F2 sectors | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 547 | F2 heat-map tile opens that sector in the board | F2 sectors | 1366x768 | outside | PASS | tile consumer durables -> open consumer durables · in view True |
| 548 | F2: the share pane sits in the right column | F2 sectors | 1366x768 | outside | PASS | pane host #call |
| 549 | F2 keys 1-9 | F2 sectors | 1366x768 | outside | PASS | 2 -> cables & wires (row 2 = cables & wires) |
| 550 | page errors | F2 sectors | 1366x768 | outside | PASS | none |
| 551 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1366x768 | outside | PASS | chip auto -> open auto |
| 552 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1366x768 | outside | PASS | 8 whole rows (need 8) of 17 members · +n more bar: True |
| 553 | every visible share name - click loads the pane, the list stays | F1 desk | 1366x768 | outside | PASS | 8 names clicked, wrong: [] · list visible: True |
| 554 | J through the whole list (pane follows) | F1 desk | 1366x768 | outside | PASS | J x7 -> MOTHERSON (last row MOTHERSON) |
| 555 | K back up | F1 desk | 1366x768 | outside | PASS | K x7 -> M&M |
| 556 | ↓ / ↑ move share to share | F1 desk | 1366x768 | outside | PASS | ↓ MARUTI · ↑ M&M |
| 557 | J / K after a click in the pane | F1 desk | 1366x768 | outside | PASS | J MARUTI · K M&M |
| 558 | pane share name - single click | F1 desk | 1366x768 | outside | PASS | still M&M on desk-hunt#sd=auto&r=M%26M&y=0 |
| 559 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 132 -> 0 (max 430) |
| 560 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1366x768 | outside | PASS | 0 -> 265 |
| 561 | pane scrollbar - drag past the end, off the rail | F1 desk | 1366x768 | outside | PASS | top 430 of max 430 (a page that snaps to whole rows may stop one row short) |
| 562 | pane scrollbar - drag past the top, off the rail | F1 desk | 1366x768 | outside | PASS | top 0 |
| 563 | pane scrollbar - track click below, then above the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 376 -> 0 |
| 564 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 565 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | outside | PASS | -> 200 -> 0 |
| 566 | pane scrollbar - thumb visible | F1 desk | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 567 | W why + Esc | F1 desk | 1366x768 | outside | PASS | open True · after Esc open False · share still M&M |
| 568 | Space plan card + Esc | F1 desk | 1366x768 | outside | PASS | open True · after Esc False |
| 569 | pane button W why, then ✕ | F1 desk | 1366x768 | outside | PASS | open True · closed True |
| 570 | pane button Space plan, then ✕ | F1 desk | 1366x768 | outside | PASS | open True |
| 571 | P pin (toggle) | F1 desk | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 572 | Pin toast sits above the action bar, below the share name | F1 desk | 1366x768 | outside | PASS | toast 629-677 · action bar top 683 · name bottom 289 |
| 573 | Pin button (action bar) | F1 desk | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 574 | Copy contract (clipboard only) | F1 desk | 1366x768 | outside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 575 | Copy button shows the size | F1 desk | 1366x768 | outside | PASS | Copy 3,500 CE · 0 lots |
| 576 | signal only: no order / buy button, the Kite line shown | F1 desk | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 577 | December strikes only (rows + trade box) | F1 desk | 1366x768 | outside | PASS | 8 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 578 | "Expiry week · physical settlement - December only" warning | F1 desk | 1366x768 | outside | PASS | sector line True · pane True |
| 579 | ATM ★ only on a strike he could take | F1 desk | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 580 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 581 | no repeated dashes; the reason shown once | F1 desk | 1366x768 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 582 | F1 sector list scrollbar (dock) - slow mouse drag of the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 33 -> 0 (max 33) |
| 583 | F1 sector list scrollbar (dock) - fast drag (one 120 px jerk) | F1 desk | 1366x768 | outside | PASS | 0 -> 33 |
| 584 | F1 sector list scrollbar (dock) - drag past the end, off the rail | F1 desk | 1366x768 | outside | PASS | top 33 of max 33 (a page that snaps to whole rows may stop one row short) |
| 585 | F1 sector list scrollbar (dock) - drag past the top, off the rail | F1 desk | 1366x768 | outside | PASS | top 0 |
| 586 | F1 sector list scrollbar (dock) - track click below, then above the thumb | F1 desk | 1366x768 | outside | PASS | 0 -> 33 -> 0 |
| 587 | F1 sector list scrollbar (dock) - ▼ then ▲ buttons | F1 desk | 1366x768 | outside | PASS | 0 -> 33 -> 0 |
| 588 | F1 sector list scrollbar (dock) - mouse wheel over the list, then over the bar | F1 desk | 1366x768 | outside | PASS | -> 33 -> 0 |
| 589 | F1 sector list scrollbar (dock) - thumb visible | F1 desk | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 590 | F1 Esc closes back to the Desk | F1 desk | 1366x768 | outside | PASS | open None · members panel back |
| 591 | page errors | F1 desk | 1366x768 | outside | PASS | none |
| 592 | Morning sector card opens the same component | Morning | 1366x768 | outside | PASS | card cables & wires -> open cables & wires |
| 593 | Morning: "pre-open - not live" with the session date (not shown as today) | Morning | 1366x768 | outside | PASS | ['pre-open - not live · 19 Nov 15:30 close', True, True] |
| 594 | every visible share name - click loads the pane, the list stays | Morning | 1366x768 | outside | PASS | 3 names clicked, wrong: [] · list visible: True |
| 595 | J through the whole list (pane follows) | Morning | 1366x768 | outside | PASS | J x2 -> KEI (last row KEI) |
| 596 | K back up | Morning | 1366x768 | outside | PASS | K x2 -> HAVELLS |
| 597 | ↓ / ↑ move share to share | Morning | 1366x768 | outside | PASS | ↓ POLYCAB · ↑ HAVELLS |
| 598 | J / K after a click in the pane | Morning | 1366x768 | outside | PASS | J POLYCAB · K HAVELLS |
| 599 | pane share name - single click | Morning | 1366x768 | outside | PASS | still HAVELLS on morning#sd=cables%20%26%20wires&r=HAVELL |
| 600 | pane scrollbar - slow mouse drag of the thumb | Morning | 1366x768 | outside | PASS | 0 -> 185 -> 0 (max 588) |
| 601 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1366x768 | outside | PASS | 0 -> 369 |
| 602 | pane scrollbar - drag past the end, off the rail | Morning | 1366x768 | outside | PASS | top 588 of max 588 (a page that snaps to whole rows may stop one row short) |
| 603 | pane scrollbar - drag past the top, off the rail | Morning | 1366x768 | outside | PASS | top 0 |
| 604 | pane scrollbar - track click below, then above the thumb | Morning | 1366x768 | outside | PASS | 0 -> 300 -> 0 |
| 605 | pane scrollbar - ▼ then ▲ buttons | Morning | 1366x768 | outside | PASS | 0 -> 66 -> 0 |
| 606 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1366x768 | outside | PASS | -> 200 -> 0 |
| 607 | pane scrollbar - thumb visible | Morning | 1366x768 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 608 | W why + Esc | Morning | 1366x768 | outside | PASS | open True · after Esc open False · share still HAVELLS |
| 609 | Space plan card + Esc | Morning | 1366x768 | outside | PASS | open True · after Esc False |
| 610 | pane button W why, then ✕ | Morning | 1366x768 | outside | PASS | open True · closed True |
| 611 | pane button Space plan, then ✕ | Morning | 1366x768 | outside | PASS | open True |
| 612 | P pin (toggle) | Morning | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 613 | Pin toast sits above the action bar, below the share name | Morning | 1366x768 | outside | PASS | toast 599-647 · action bar top 653 · name bottom 348 |
| 614 | Pin button (action bar) | Morning | 1366x768 | outside | PASS | pins 0 -> 1 -> 0 |
| 615 | Copy contract (clipboard only) | Morning | 1366x768 | outside | PASS | clipboard "HAVELLS26DEC1200CE" · button "Copy 1,200 CE · 0 lots" · toast "Copied HAVELLS26DEC1200CE · 0 lots - you place the order in Kite" |
| 616 | Copy button shows the size | Morning | 1366x768 | outside | PASS | Copy 1,200 CE · 0 lots |
| 617 | signal only: no order / buy button, the Kite line shown | Morning | 1366x768 | outside | PASS | line shown True · order-like buttons [] |
| 618 | December strikes only (rows + trade box) | Morning | 1366x768 | outside | PASS | 3 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 619 | "Expiry week · physical settlement - December only" warning | Morning | 1366x768 | outside | PASS | sector line True · pane True |
| 620 | ATM ★ only on a strike he could take | Morning | 1366x768 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 621 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1366x768 | outside | PASS | checked rows · mismatches [] |
| 622 | no repeated dashes; the reason shown once | Morning | 1366x768 | outside | PASS | 0 lone dashes · "not known" x2 in the list |
| 623 | page errors | Morning | 1366x768 | outside | PASS | none |
| 624 | F3 sector-list scrollbar (no sector open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 156 -> 0 (max 592) |
| 625 | F3 sector-list scrollbar (no sector open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 0 -> 313 |
| 626 | F3 sector-list scrollbar (no sector open) - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 578 of max 592 (a page that snaps to whole rows may stop one row short) |
| 627 | F3 sector-list scrollbar (no sector open) - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 628 | F3 sector-list scrollbar (no sector open) - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 283 -> 147 |
| 629 | F3 sector-list scrollbar (no sector open) - ▼ then ▲ buttons | F3 rotation | 1600x900 | outside | PASS | 147 -> 259 -> 148 |
| 630 | F3 sector-list scrollbar (no sector open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 348 -> 148 |
| 631 | F3 sector-list scrollbar (no sector open) - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 632 | F3 table row click opens the sector | F3 rotation | 1600x900 | outside | PASS | open banks in 12 ms (from the cached store) |
| 633 | opens under 100 ms | F3 rotation | 1600x900 | outside | PASS | 12 ms |
| 634 | the open list pushes the rows below (no overprint) | F3 rotation | 1600x900 | outside | PASS | list bottom 817 · next sector row top 823 |
| 635 | row cap: whole share rows in the first view + "+n more" | F3 rotation | 1600x900 | outside | PASS | 12 whole rows (need 12) of 22 members · +n more bar: True |
| 636 | every visible share name - click loads the pane, the list stays | F3 rotation | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 637 | J through the whole list (pane follows) | F3 rotation | 1600x900 | outside | PASS | J x11 -> INDUSINDBK (last row INDUSINDBK) |
| 638 | K back up | F3 rotation | 1600x900 | outside | PASS | K x11 -> IDFCFIRSTB |
| 639 | ↓ / ↑ move share to share | F3 rotation | 1600x900 | outside | PASS | ↓ PNB · ↑ IDFCFIRSTB |
| 640 | J / K after a click in the pane | F3 rotation | 1600x900 | outside | PASS | J PNB · K IDFCFIRSTB |
| 641 | pane share name - single click | F3 rotation | 1600x900 | outside | PASS | still IDFCFIRSTB on rotation#sd=banks&r=IDFCFIRSTB&y=224 |
| 642 | pane scrollbar - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 148 -> 0 (max 492) |
| 643 | pane scrollbar - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 0 -> 295 |
| 644 | pane scrollbar - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 492 of max 492 (a page that snaps to whole rows may stop one row short) |
| 645 | pane scrollbar - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 646 | pane scrollbar - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 356 -> 1 |
| 647 | pane scrollbar - ▼ then ▲ buttons | F3 rotation | 1600x900 | outside | PASS | 1 -> 67 -> 1 |
| 648 | pane scrollbar - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 201 -> 1 |
| 649 | pane scrollbar - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 650 | W why + Esc | F3 rotation | 1600x900 | outside | PASS | open True · after Esc open False · share still IDFCFIRSTB |
| 651 | Space plan card + Esc | F3 rotation | 1600x900 | outside | PASS | open True · after Esc False |
| 652 | pane button W why, then ✕ | F3 rotation | 1600x900 | outside | PASS | open True · closed True |
| 653 | pane button Space plan, then ✕ | F3 rotation | 1600x900 | outside | PASS | open True |
| 654 | P pin (toggle) | F3 rotation | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 655 | Pin toast sits above the action bar, below the share name | F3 rotation | 1600x900 | outside | PASS | toast 761-809 · action bar top 815 · name bottom 419 |
| 656 | Pin button (action bar) | F3 rotation | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 657 | Copy contract (clipboard only) | F3 rotation | 1600x900 | outside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · button "Copy 86 CE · 0 lots" · toast "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in Kite" |
| 658 | Copy button shows the size | F3 rotation | 1600x900 | outside | PASS | Copy 86 CE · 0 lots |
| 659 | signal only: no order / buy button, the Kite line shown | F3 rotation | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 660 | December strikes only (rows + trade box) | F3 rotation | 1600x900 | outside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 661 | "Expiry week · physical settlement - December only" warning | F3 rotation | 1600x900 | outside | PASS | sector line True · pane True |
| 662 | ATM ★ only on a strike he could take | F3 rotation | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 663 | EXTENDED: one rule in the group, the gate cell and the pane | F3 rotation | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 664 | no repeated dashes; the reason shown once | F3 rotation | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 665 | sector line stays pinned at the top while the list scrolls | F3 rotation | 1600x900 | outside | PASS | pin line (list top under the sticky table head) 387 · [line y, first row y] after each 40 px wheel [[468, 537], [428, 497], [388, 457], [387, 417], [387, 377], [387, 337]] |
| 666 | F3 sector-list scrollbar (Banks open) - slow mouse drag of the thumb | F3 rotation | 1600x900 | outside | PASS | 344 -> 524 -> 345 (max 937) |
| 667 | F3 sector-list scrollbar (Banks open) - fast drag (one 120 px jerk) | F3 rotation | 1600x900 | outside | PASS | 345 -> 703 |
| 668 | F3 sector-list scrollbar (Banks open) - drag past the end, off the rail | F3 rotation | 1600x900 | outside | PASS | top 919 of max 937 (a page that snaps to whole rows may stop one row short) |
| 669 | F3 sector-list scrollbar (Banks open) - drag past the top, off the rail | F3 rotation | 1600x900 | outside | PASS | top 0 |
| 670 | F3 sector-list scrollbar (Banks open) - track click below, then above the thumb | F3 rotation | 1600x900 | outside | PASS | 0 -> 378 -> 224 |
| 671 | F3 sector-list scrollbar (Banks open) - mouse wheel over the list, then over the bar | F3 rotation | 1600x900 | outside | PASS | -> 424 -> 224 |
| 672 | F3 sector-list scrollbar (Banks open) - thumb visible | F3 rotation | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 673 | "+n more ▾" then "show fewer ▴" | F3 rotation | 1600x900 | outside | PASS | rows 12 -> 22 -> 12 |
| 674 | basis › (the basis in full, R49) | F3 rotation | 1600x900 | outside | PASS | "basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE market cap 19 Nov) br" · closed True |
| 675 | "n more listed, not F&O" fold line | F3 rotation | 1600x900 | outside | PASS | "▸ 12 more listed, not F&O · ▲8 ▼4 · wt 5% · context only, no strike" -> open, then closed |
| 676 | double-click a share row -> F7, Back returns to the same sector, list, row | F3 rotation | 1600x900 | outside | PASS | went share?s=AXISBANK · back: open banks, row AXISBANK, expanded True |
| 677 | after Back, J still moves | F3 rotation | 1600x900 | outside | PASS | AXISBANK -> INDUSINDBK |
| 678 | O opens the option chain at the December strike; Back | F3 rotation | 1600x900 | outside | PASS | chain?s=INDUSINDBK&exp=2026-12-29&k=920&side=CE · back on INDUSINDBK |
| 679 | double-click the pane share name -> F7, Back | F3 rotation | 1600x900 | outside | PASS | share?s=INDUSINDBK |
| 680 | Enter on a share row -> F7 | F3 rotation | 1600x900 | outside | PASS | share?s=INDUSINDBK |
| 681 | Esc closes step by step | F3 rotation | 1600x900 | outside | PASS | why w -> Esc drawer closed -> Esc share cleared -> Esc list collapsed -> Esc open None |
| 682 | O / W with no share selected | F3 rotation | 1600x900 | outside | PASS | url unchanged True · toast "pick a share first (click a row)" |
| 683 | keys 1-9 pick a sector | F3 rotation | 1600x900 | outside | PASS | 3 -> fmcg (row 3 = fmcg) · 1 -> auto (row 1 = auto) |
| 684 | Tab to a sector row + Enter opens it | F3 rotation | 1600x900 | outside | PASS | focused auto after 3 Tab · open auto |
| 685 | R key (apply re-rank) | F3 rotation | 1600x900 | outside | PASS | order unchanged with no new ranks (market closed, no ticks) |
| 686 | "re-ranked · R to apply" chip, ▲n / ▼n, NEW entrant, live ticks | F3 rotation | 1600x900 | outside | NOT RUN | needs live ticks: the market is closed (store holds the 19 Nov close); code path in sector-drill.js listHtml (frozen order under pointer / focus, 30 s, pointer leave, R) |
| 687 | money-flow band: a sector name opens it in the table below | F3 rotation | 1600x900 | outside | PASS | clicked it -> open it, list visible True |
| 688 | "moving, but not this rotation" row opens that sector | F3 rotation | 1600x900 | outside | PASS | clicked consumer durables -> open consumer durables |
| 689 | BAN: NOT TRADABLE, plan dimmed, Copy disabled | F3 rotation | 1600x900 | outside | PASS | KAYNES (electronics & hardware): group nt · Copy disabled True · "BAN - only close existing" True · plan opacity 0.45 · clipboard untouched True |
| 690 | STALE quote: Copy disabled, "STALE ns", no GO NOW | F3 rotation | 1600x900 | outside | NOT RUN | 0 stale share quotes in the store now (closed market: quotes are CLOSED, not STALE); rule checked in the rules table |
| 691 | LOCKED: plan dimmed + reason on a second line | F3 rotation | 1600x900 | outside | NOT RUN | pos.day.lock.locked = False today; rule checked in the rules table |
| 692 | up-side shown: a rising sector shows CE strikes on its groups | F3 rotation | 1600x900 | outside | PASS | electronics & hardware dir 1 · every row CE: True |
| 693 | page errors | F3 rotation | 1600x900 | outside | PASS | none |
| 694 | F1 Desk sector chip opens the sector (same component) | F1 desk | 1600x900 | outside | PASS | chip auto -> open auto |
| 695 | row cap: whole share rows in the first view + "+n more" | F1 desk | 1600x900 | outside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 696 | every visible share name - click loads the pane, the list stays | F1 desk | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 697 | J through the whole list (pane follows) | F1 desk | 1600x900 | outside | PASS | J x11 -> ASHOKLEY (last row ASHOKLEY) |
| 698 | K back up | F1 desk | 1600x900 | outside | PASS | K x11 -> M&M |
| 699 | ↓ / ↑ move share to share | F1 desk | 1600x900 | outside | PASS | ↓ MARUTI · ↑ M&M |
| 700 | J / K after a click in the pane | F1 desk | 1600x900 | outside | PASS | J MARUTI · K M&M |
| 701 | pane share name - single click | F1 desk | 1600x900 | outside | PASS | still M&M on desk-hunt#sd=auto&r=M%26M&y=0 |
| 702 | pane scrollbar - slow mouse drag of the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 93 -> 0 (max 246) |
| 703 | pane scrollbar - fast drag (one 120 px jerk) | F1 desk | 1600x900 | outside | PASS | 0 -> 186 |
| 704 | pane scrollbar - drag past the end, off the rail | F1 desk | 1600x900 | outside | PASS | top 246 of max 246 (a page that snaps to whole rows may stop one row short) |
| 705 | pane scrollbar - drag past the top, off the rail | F1 desk | 1600x900 | outside | PASS | top 0 |
| 706 | pane scrollbar - track click below, then above the thumb | F1 desk | 1600x900 | outside | PASS | 0 -> 246 -> 0 |
| 707 | pane scrollbar - ▼ then ▲ buttons | F1 desk | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 708 | pane scrollbar - mouse wheel over the list, then over the bar | F1 desk | 1600x900 | outside | PASS | -> 200 -> 0 |
| 709 | pane scrollbar - thumb visible | F1 desk | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 710 | W why + Esc | F1 desk | 1600x900 | outside | PASS | open True · after Esc open False · share still M&M |
| 711 | Space plan card + Esc | F1 desk | 1600x900 | outside | PASS | open True · after Esc False |
| 712 | pane button W why, then ✕ | F1 desk | 1600x900 | outside | PASS | open True · closed True |
| 713 | pane button Space plan, then ✕ | F1 desk | 1600x900 | outside | PASS | open True |
| 714 | P pin (toggle) | F1 desk | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 715 | Pin toast sits above the action bar, below the share name | F1 desk | 1600x900 | outside | PASS | toast 761-809 · action bar top 815 · name bottom 268 |
| 716 | Pin button (action bar) | F1 desk | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 717 | Copy contract (clipboard only) | F1 desk | 1600x900 | outside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 718 | Copy button shows the size | F1 desk | 1600x900 | outside | PASS | Copy 3,500 CE · 0 lots |
| 719 | signal only: no order / buy button, the Kite line shown | F1 desk | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 720 | December strikes only (rows + trade box) | F1 desk | 1600x900 | outside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 721 | "Expiry week · physical settlement - December only" warning | F1 desk | 1600x900 | outside | PASS | sector line True · pane True |
| 722 | ATM ★ only on a strike he could take | F1 desk | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 723 | EXTENDED: one rule in the group, the gate cell and the pane | F1 desk | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 724 | no repeated dashes; the reason shown once | F1 desk | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 725 | F1 sector list scrollbar (dock) | F1 desk | 1600x900 | outside | PASS | every row fits at this size (all 17 F&O rows + the not-F&O line shown): the drawn bar shows a full 624 px thumb of 624, 11 px wide - nothing to drag |
| 726 | F1 Esc closes back to the Desk | F1 desk | 1600x900 | outside | PASS | open None · members panel back |
| 727 | page errors | F1 desk | 1600x900 | outside | PASS | none |
| 728 | Morning sector card opens the same component | Morning | 1600x900 | outside | PASS | card cables & wires -> open cables & wires |
| 729 | Morning: "pre-open - not live" with the session date (not shown as today) | Morning | 1600x900 | outside | PASS | ['pre-open - not live · 19 Nov 15:30 close', True, True] |
| 730 | every visible share name - click loads the pane, the list stays | Morning | 1600x900 | outside | PASS | 3 names clicked, wrong: [] · list visible: True |
| 731 | J through the whole list (pane follows) | Morning | 1600x900 | outside | PASS | J x2 -> KEI (last row KEI) |
| 732 | K back up | Morning | 1600x900 | outside | PASS | K x2 -> HAVELLS |
| 733 | ↓ / ↑ move share to share | Morning | 1600x900 | outside | PASS | ↓ POLYCAB · ↑ HAVELLS |
| 734 | J / K after a click in the pane | Morning | 1600x900 | outside | PASS | J POLYCAB · K HAVELLS |
| 735 | pane share name - single click | Morning | 1600x900 | outside | PASS | still HAVELLS on morning#sd=cables%20%26%20wires&r=HAVELL |
| 736 | pane scrollbar - slow mouse drag of the thumb | Morning | 1600x900 | outside | PASS | 0 -> 176 -> 0 (max 551) |
| 737 | pane scrollbar - fast drag (one 120 px jerk) | Morning | 1600x900 | outside | PASS | 0 -> 352 |
| 738 | pane scrollbar - drag past the end, off the rail | Morning | 1600x900 | outside | PASS | top 551 of max 551 (a page that snaps to whole rows may stop one row short) |
| 739 | pane scrollbar - drag past the top, off the rail | Morning | 1600x900 | outside | PASS | top 0 |
| 740 | pane scrollbar - track click below, then above the thumb | Morning | 1600x900 | outside | PASS | 0 -> 302 -> 0 |
| 741 | pane scrollbar - ▼ then ▲ buttons | Morning | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 742 | pane scrollbar - mouse wheel over the list, then over the bar | Morning | 1600x900 | outside | PASS | -> 200 -> 0 |
| 743 | pane scrollbar - thumb visible | Morning | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(107, 118, 134) |
| 744 | W why + Esc | Morning | 1600x900 | outside | PASS | open True · after Esc open False · share still HAVELLS |
| 745 | Space plan card + Esc | Morning | 1600x900 | outside | PASS | open True · after Esc False |
| 746 | pane button W why, then ✕ | Morning | 1600x900 | outside | PASS | open True · closed True |
| 747 | pane button Space plan, then ✕ | Morning | 1600x900 | outside | PASS | open True |
| 748 | P pin (toggle) | Morning | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 749 | Pin toast sits above the action bar, below the share name | Morning | 1600x900 | outside | PASS | toast 760-808 · action bar top 814 · name bottom 477 |
| 750 | Pin button (action bar) | Morning | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 751 | Copy contract (clipboard only) | Morning | 1600x900 | outside | PASS | clipboard "HAVELLS26DEC1200CE" · button "Copy 1,200 CE · 0 lots" · toast "Copied HAVELLS26DEC1200CE · 0 lots - you place the order in Kite" |
| 752 | Copy button shows the size | Morning | 1600x900 | outside | PASS | Copy 1,200 CE · 0 lots |
| 753 | signal only: no order / buy button, the Kite line shown | Morning | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 754 | December strikes only (rows + trade box) | Morning | 1600x900 | outside | PASS | 3 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 755 | "Expiry week · physical settlement - December only" warning | Morning | 1600x900 | outside | PASS | sector line True · pane True |
| 756 | ATM ★ only on a strike he could take | Morning | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 757 | EXTENDED: one rule in the group, the gate cell and the pane | Morning | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 758 | no repeated dashes; the reason shown once | Morning | 1600x900 | outside | PASS | 0 lone dashes · "not known" x2 in the list |
| 759 | page errors | Morning | 1600x900 | outside | PASS | none |
| 760 | F2 board scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 167 -> 0 (max 666) |
| 761 | F2 board scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | outside | PASS | 0 -> 334 |
| 762 | F2 board scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | outside | PASS | top 666 of max 666 (a page that snaps to whole rows may stop one row short) |
| 763 | F2 board scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | outside | PASS | top 0 |
| 764 | F2 board scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 559 -> 0 |
| 765 | F2 board scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | outside | PASS | -> 200 -> 0 |
| 766 | F2 board scrollbar - thumb visible | F2 sectors | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(142, 151, 163) |
| 767 | F2 board row click opens the sector in place | F2 sectors | 1600x900 | outside | PASS | open auto · list bottom 661 · next row top 667 |
| 768 | row cap: whole share rows in the first view + "+n more" | F2 sectors | 1600x900 | outside | PASS | 12 whole rows (need 12) of 17 members · +n more bar: True |
| 769 | every visible share name - click loads the pane, the list stays | F2 sectors | 1600x900 | outside | PASS | 12 names clicked, wrong: [] · list visible: True |
| 770 | J through the whole list (pane follows) | F2 sectors | 1600x900 | outside | PASS | J x11 -> ASHOKLEY (last row ASHOKLEY) |
| 771 | K back up | F2 sectors | 1600x900 | outside | PASS | K x11 -> M&M |
| 772 | ↓ / ↑ move share to share | F2 sectors | 1600x900 | outside | PASS | ↓ MARUTI · ↑ M&M |
| 773 | J / K after a click in the pane | F2 sectors | 1600x900 | outside | PASS | J MARUTI · K M&M |
| 774 | pane share name - single click | F2 sectors | 1600x900 | outside | PASS | still M&M on sectors#sd=auto&r=M%26M&y=180 |
| 775 | pane scrollbar - slow mouse drag of the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 106 -> 0 (max 343) |
| 776 | pane scrollbar - fast drag (one 120 px jerk) | F2 sectors | 1600x900 | outside | PASS | 0 -> 212 |
| 777 | pane scrollbar - drag past the end, off the rail | F2 sectors | 1600x900 | outside | PASS | top 343 of max 343 (a page that snaps to whole rows may stop one row short) |
| 778 | pane scrollbar - drag past the top, off the rail | F2 sectors | 1600x900 | outside | PASS | top 0 |
| 779 | pane scrollbar - track click below, then above the thumb | F2 sectors | 1600x900 | outside | PASS | 0 -> 343 -> 0 |
| 780 | pane scrollbar - ▼ then ▲ buttons | F2 sectors | 1600x900 | outside | PASS | 0 -> 66 -> 0 |
| 781 | pane scrollbar - mouse wheel over the list, then over the bar | F2 sectors | 1600x900 | outside | PASS | -> 200 -> 0 |
| 782 | pane scrollbar - thumb visible | F2 sectors | 1600x900 | outside | PASS | thumb 11 px wide, colour rgb(138, 150, 168) |
| 783 | W why + Esc | F2 sectors | 1600x900 | outside | PASS | open True · after Esc open False · share still M&M |
| 784 | Space plan card + Esc | F2 sectors | 1600x900 | outside | PASS | open True · after Esc False |
| 785 | pane button W why, then ✕ | F2 sectors | 1600x900 | outside | PASS | open True · closed True |
| 786 | pane button Space plan, then ✕ | F2 sectors | 1600x900 | outside | PASS | open True |
| 787 | P pin (toggle) | F2 sectors | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 788 | Pin toast sits above the action bar, below the share name | F2 sectors | 1600x900 | outside | PASS | toast 760-808 · action bar top 814 · name bottom 288 |
| 789 | Pin button (action bar) | F2 sectors | 1600x900 | outside | PASS | pins 0 -> 1 -> 0 |
| 790 | Copy contract (clipboard only) | F2 sectors | 1600x900 | outside | PASS | clipboard "M&M26DEC3500CE" · button "Copy 3,500 CE · 0 lots" · toast "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 791 | Copy button shows the size | F2 sectors | 1600x900 | outside | PASS | Copy 3,500 CE · 0 lots |
| 792 | signal only: no order / buy button, the Kite line shown | F2 sectors | 1600x900 | outside | PASS | line shown True · order-like buttons [] |
| 793 | December strikes only (rows + trade box) | F2 sectors | 1600x900 | outside | PASS | 12 strike chips, 0 not December · trade box "TRADE BOX · 2026-12-29 (December only)" · November date shown: False |
| 794 | "Expiry week · physical settlement - December only" warning | F2 sectors | 1600x900 | outside | PASS | sector line True · pane True |
| 795 | ATM ★ only on a strike he could take | F2 sectors | 1600x900 | outside | PASS | mismatches [] · takeable now 0 (market closed: pre-open block, 0 lots everywhere) |
| 796 | EXTENDED: one rule in the group, the gate cell and the pane | F2 sectors | 1600x900 | outside | PASS | checked rows · mismatches [] |
| 797 | no repeated dashes; the reason shown once | F2 sectors | 1600x900 | outside | PASS | 0 lone dashes · "not known" x1 in the list |
| 798 | F2 heat-map tile opens that sector in the board | F2 sectors | 1600x900 | outside | PASS | tile consumer durables -> open consumer durables · in view True |
| 799 | F2: the share pane sits in the right column | F2 sectors | 1600x900 | outside | PASS | pane host #call |
| 800 | F2 keys 1-9 | F2 sectors | 1600x900 | outside | PASS | 2 -> cables & wires (row 2 = cables & wires) |
| 801 | page errors | F2 sectors | 1600x900 | outside | PASS | none |
| 802 | tap a sector row opens the full-screen list sheet | F3 rotation | 390x844 | outside | PASS | open banks · built in 24 ms · tap-to-sheet 110 ms |
| 803 | sheet header (sector line) <= 2 lines + WHY | F3 rotation | 390x844 | outside | PASS | line 1 46 px, whole header 179 px |
| 804 | sheet rail size (touch target >= 24, track and thumb >= 10) | F3 rotation | 390x844 | outside | PASS | target 26 · track 13 · thumb 13 px |
| 805 | list sheet - finger swipe | F3 rotation | 390x844 | outside | PASS | 0 -> 446 -> 190 |
| 806 | list sheet - rail thumb, finger drag | F3 rotation | 390x844 | outside | PASS | 190 -> 402 · share opened: None |
| 807 | list sheet - rail drag, 8 px contact | F3 rotation | 390x844 | outside | PASS | 402 -> 190 |
| 808 | list sheet - rail drag at its right edge | F3 rotation | 390x844 | outside | PASS | 190 -> 367 |
| 809 | list sheet - rail track tap | F3 rotation | 390x844 | outside | PASS | 367 -> 301 |
| 810 | list sheet - rail, mouse drag (one mouse check) | F3 rotation | 390x844 | outside | PASS | 301 -> 442 |
| 811 | fast flick, then a tap still opens the row | F3 rotation | 390x844 | outside | PASS | flick then tap KOTAKBANK -> share sheet True (KOTAKBANK) |
| 812 | "n more listed, not F&O" (finger) | F3 rotation | 390x844 | outside | PASS | open True · closed True |
| 813 | basis › (finger) | F3 rotation | 390x844 | outside | PASS | basis (R49) whole sector: 34 listed shares, market-cap weighted (NSE m |
| 814 | tap a share opens the share sheet | F3 rotation | 390x844 | outside | PASS | IDFCFIRSTB -> sheet True |
| 815 | share sheet - finger swipe | F3 rotation | 390x844 | outside | PASS | 0 -> 184 |
| 816 | share sheet - action bar sticky, shows the size | F3 rotation | 390x844 | outside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy 86 CE · 0 lots" |
| 817 | share sheet - rail thumb, finger drag | F3 rotation | 390x844 | outside | PASS | 0 -> 185 |
| 818 | share sheet - rail track tap | F3 rotation | 390x844 | outside | PASS | 185 -> 119 |
| 819 | WHY › (share sheet) | F3 rotation | 390x844 | outside | PASS | open True · closed True |
| 820 | Copy contract (finger, first view) | F3 rotation | 390x844 | outside | PASS | clipboard "IDFCFIRSTB26DEC86CE" · "Copied IDFCFIRSTB26DEC86CE · 0 lots - you place the order in" |
| 821 | Pin (toggle, n/5) (finger) | F3 rotation | 390x844 | outside | PASS | 0 -> 1 -> 0 |
| 822 | Pin toast above the action bar, not over the share name | F3 rotation | 390x844 | outside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 823 | ‹ Sector (Back button on the share sheet) | F3 rotation | 390x844 | outside | PASS | list sheet True · share sheet False |
| 824 | device / browser Back (share sheet -> list) | F3 rotation | 390x844 | outside | PASS | list True · share False |
| 825 | device / browser Back (list -> page) | F3 rotation | 390x844 | outside | PASS | sheet False · open None |
| 826 | ‹ Sectors (Back button on the list sheet) | F3 rotation | 390x844 | outside | PASS | sheet closed True |
| 827 | page errors | F3 rotation | 390x844 | outside | PASS | none |
| 828 | tap a sector row opens the full-screen list sheet | F2 sectors | 390x844 | outside | PASS | open auto · built in 21 ms · tap-to-sheet 88 ms |
| 829 | sheet header (sector line) <= 2 lines + WHY | F2 sectors | 390x844 | outside | PASS | line 1 46 px, whole header 179 px |
| 830 | sheet rail size (touch target >= 24, track and thumb >= 10) | F2 sectors | 390x844 | outside | PASS | target 26 · track 13 · thumb 13 px |
| 831 | list sheet - finger swipe | F2 sectors | 390x844 | outside | PASS | 0 -> 299 -> 46 |
| 832 | list sheet - rail thumb, finger drag | F2 sectors | 390x844 | outside | PASS | 46 -> 223 · share opened: None |
| 833 | list sheet - rail drag, 8 px contact | F2 sectors | 390x844 | outside | PASS | 223 -> 46 |
| 834 | list sheet - rail drag at its right edge | F2 sectors | 390x844 | outside | PASS | 46 -> 193 |
| 835 | list sheet - rail track tap | F2 sectors | 390x844 | outside | PASS | 193 -> 127 |
| 836 | list sheet - rail, mouse drag (one mouse check) | F2 sectors | 390x844 | outside | PASS | 127 -> 245 |
| 837 | fast flick, then a tap still opens the row | F2 sectors | 390x844 | outside | PASS | flick then tap TVSMOTOR -> share sheet True (TVSMOTOR) |
| 838 | "n more listed, not F&O" (finger) | F2 sectors | 390x844 | outside | PASS | open True · closed True |
| 839 | basis › (finger) | F2 sectors | 390x844 | outside | PASS | basis (R49) whole sector: 50 listed shares, market-cap weighted (NSE m |
| 840 | tap a share opens the share sheet | F2 sectors | 390x844 | outside | PASS | M&M -> sheet True |
| 841 | share sheet - finger swipe | F2 sectors | 390x844 | outside | PASS | 0 -> 165 |
| 842 | share sheet - action bar sticky, shows the size | F2 sectors | 390x844 | outside | PASS | bar 776-844 at scroll 0 and 776-844 after the swipe · "Copy 3,500 CE · 0 lots" |
| 843 | share sheet - rail thumb, finger drag | F2 sectors | 390x844 | outside | PASS | 0 -> 166 |
| 844 | share sheet - rail track tap | F2 sectors | 390x844 | outside | PASS | 166 -> 100 |
| 845 | WHY › (share sheet) | F2 sectors | 390x844 | outside | PASS | open True · closed True |
| 846 | Copy contract (finger, first view) | F2 sectors | 390x844 | outside | PASS | clipboard "M&M26DEC3500CE" · "Copied M&M26DEC3500CE · 0 lots - you place the order in Kite" |
| 847 | Pin (toggle, n/5) (finger) | F2 sectors | 390x844 | outside | PASS | 0 -> 1 -> 0 |
| 848 | Pin toast above the action bar, not over the share name | F2 sectors | 390x844 | outside | PASS | toast 679-727 · bar top 733 · name bottom 76 |
| 849 | ‹ Sector (Back button on the share sheet) | F2 sectors | 390x844 | outside | PASS | list sheet True · share sheet False |
| 850 | device / browser Back (share sheet -> list) | F2 sectors | 390x844 | outside | PASS | list True · share False |
| 851 | device / browser Back (list -> page) | F2 sectors | 390x844 | outside | PASS | sheet False · open None |
| 852 | ‹ Sectors (Back button on the list sheet) | F2 sectors | 390x844 | outside | PASS | sheet closed True |
| 853 | page errors | F2 sectors | 390x844 | outside | PASS | none |
