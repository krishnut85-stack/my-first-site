# Laptop controls - rotation-drilldown.html (round 3, re-run from scratch on the final build)

19 Nov. From `drilldown_src/` or any other folder: `node build.js && node shot.js && node test_rules.js && node test_desk.js` (build.js and every script resolve their paths from their own folder).
Chromium headless (Playwright), viewports **1600 x 900 and 1366 x 768**, deviceScaleFactor 1. Real mouse clicks at element centres, focus only by click or Tab, real 30 s waits, no state forced.

**Result: controls PASS 204 FAIL 0 (both sizes) · rules PASS 26 FAIL 0 · layout checks (shot.js) 29 run, 0 FAIL.**

## What round 2 got wrong, and what changed
- **Cut cells at 1366.** RVOL (34 px box, 35 px text) and vs sec / RS30 (48 px box, 49 px text) ended in "…" in every share row, so the 15-min slope arrow and the RVOL rising arrow were lost (spec §3 columns 3-4). The heads "VWAP/OR" (54.2 > 54) and "wt %" (32.8 > 32) were cut, and the sector-row chip "ROT CONFIRMED 22m" was painted 4 px past its 132 px cell.
  Fix: the 1366 columns were re-cut from measured widths, with at least 2.3 px of slack in every column (table below). The heads are now "VWAP·OR" and "WT%", and the state column is 152 px. The space comes from the row padding (6/6 to 5/4 px) and the group column (86 to 83 px). The arrows stay at 1366.
- **shot.js hid them.** Its test was `scrollWidth > clientWidth + 1`, which passes a 1 px cut. It also never opened the "not F&O" fold, and it could not see a chip painted past a cell that has no overflow of its own.
  Fix: there is no tolerance now (`scrollWidth > clientWidth` fails). Every sector is opened with "+n more" AND "not F&O" open. A second pass checks that every chip, row cell, head and trade-box cell lies inside its clipping box. Prose may still end in "…" only if it has a tooltip and is not a number, head or chip. The run also covers every mock state.
- **Chip font.** The strike chips in the trade-box heads ("1,460 CE" / "1,450 CE"), "COMING UP NOW", the role chips, the state chips and "GET READY" were drawn at 11 px, at both sizes. Every chip on the page is now 12 px, and so is the trade-box head row (ATM ★ / 1 ITM). shot.js checks `#page .sh-c >= 12` and `#pb .tbx th >= 12`.
- **Rail ▲▼ were 15 x 16.** The 1 px divider took a pixel from the 16 px rail. The divider is now an inset shadow, so the buttons are 16 x 16. The test now requires width ≥ 16 (it accepted 15 before).
- **LOCKED mock contradicted the strip.** The banner said the loss lock was hit, while the strip showed TODAY ₹0 and the pane said 0 of 3 trades. The mock state now sets the strip as well: TODAY −₹10,000 −2.0R, TRADES 3 of 3, LOCKED ₹0 left, week −₹14,105, month −₹4,305. The pane says "trades 3 of 3", and the banner says "day loss lock hit: 3 losing trades = −₹10,000". HELD had the same problem and now shows TRADES 1 of 3 and open +₹1,240 on the strip as well. A new check showed that HELD cut the BANKBARODA name cell (name + HELD + role chip): the row now shows HELD in place of the role chip, and the role stays in the pane. It also showed that PRE-OPEN's "close" age (33 > 29) was cut: it now reads "prev", with a tooltip.
- **Chart polish.** The level labels are now TRIG / STOP / TGT, and the right margin grows to fit the longest label. The OR label sits inside the box when the box is tall enough, otherwise under it (or above it), never on the border, with a dark halo. shot.js fails an OR label on the border or a one-letter T / S / G label. The premium caption shortens itself when it would touch the price.

## 1366 / 1600 share-row columns: widest content over all 63 shares vs the cell (px)
| col | content | 1366 need | 1366 cell | 1600 need | 1600 cell |
|---|---|---|---|---|---|
| 1 | share · role | 142.0 | 145 | 188.4 | 190 |
| 2 | day % | 48.7 | 51 | 48.7 | 53 |
| 3 | vs sec (RS30 + slope arrow) | 47.5 | 50 | 51.5 | 55 |
| 4 | RVOL + arrow | 33.7 | 37 | 36.5 | 44 |
| 5 | VWAP·OR | 50.9 | 54 | 50.9 | 56 |
| 6 | room | 52.4 | 55 | 52.4 | 56 |
| 7 | B/U · OI% | 66.0 | 69 | 66.0 | 70 |
| 8 | WT% | 28.8 | 32 | 46.8 (bar shrinks) | 44 |
| 9 | Dec strike · prem · % | 151.3 | 154 | 160.3 | 164 |
| 10 | state / gate | 81.2 | 84 | 99.1 | 102 |
| 11 | AI | 75.1 | 78 | 81.4 | 84 |
| 12 | age | 26.4 | 29 | 26.4 | 34 |

Column heads: none cut at either size. Sector-row state chip: fits its 152 px cell at 1366.

## Layout and type (shot.js, both sizes, every share in the pane, every sector with both folds open, every mock state)
```
ok   1600 clipped text (no ellipsis/tooltip): 0
     1600 intended ellipsis with a tooltip: 2 · Banks .t3.ell: "background · FII cash +₹1,486 cr (18 Nov" 627>291 | .nw: "09:52 · 1h 13mET · ICICI Bank: deposits " 416>376
ok   1600 font minimums: all met
ok   1600 mini chart text overlaps: none
ok   1600 whole share rows in the first view: 12 (need 12)
ok   1600 scrollbars: track >= 10 px, up / down buttons >= 16 x 16 px
ok   1600 pane header buttons inside the panel for all 63 shares
ok   1600 mini chart: no overlapping text for all 63 shares
ok   1600 every share loaded in the pane: nothing clipped (no tolerance), all fonts met, 63 shares
ok   1600 every sector open, "+n more" and "not F&O" folds open: no cut cell (no tolerance), fonts met (1988 cells checked)
     1600 prose that ends in … with a tooltip (intended): 1 · Banks .t3.ell: "background · FII cash +₹1,486 cr (18 Nov" 627>291
ok   1600 every mockup state: nothing cut, P&L strip trades = pane trades
ok   1600 page errors: none
ok   1366 clipped text (no ellipsis/tooltip): 0
     1366 intended ellipsis with a tooltip: 2 · Banks .t3.ell: "background · FII cash +₹1,486 cr (18 Nov" 627>132 | .nw: "09:52 · 1h 13mET · ICICI Bank: deposits " 416>314
ok   1366 font minimums: all met
ok   1366 mini chart text overlaps: none
ok   1366 whole share rows in the first view: 8 (need 8)
ok   1366 scrollbars: track >= 10 px, up / down buttons >= 16 x 16 px
ok   1366 pane header buttons inside the panel for all 63 shares
ok   1366 mini chart: no overlapping text for all 63 shares
ok   1366 every share loaded in the pane: nothing clipped (no tolerance), all fonts met, 63 shares
ok   1366 every sector open, "+n more" and "not F&O" folds open: no cut cell (no tolerance), fonts met (1988 cells checked)
     1366 prose that ends in … with a tooltip (intended): 1 · Banks .t3.ell: "background · FII cash +₹1,486 cr (18 Nov" 627>132
ok   1366 every mockup state: nothing cut, P&L strip trades = pane trades
ok   1366 page errors: none
ok   phone 1 Sectors list - Banks UP (tap Banks): fonts >= 13 px, no clipped text
ok   phone 2 Banks sheet - 2-line header, groups: fonts >= 13 px, no clipped text
ok   phone 3 same sheet, WAITING + BAN rows: fonts >= 13 px, no clipped text
ok   phone 4 tap ICICIBANK - share sheet (Back = list): fonts >= 13 px, no clipped text
ok   phone mini chart: no overlapping / outside text for all 63 shares
ok   phone share sheet for all 63 shares: nothing clipped (no tolerance), Copy and Pin on screen in the first view (sticky bar, 44 px)
ok   phone every sector sheet (11), top and end of the list: nothing clipped (no tolerance)
all checks passed
```
The only "…" left is prose with a tooltip: the WHY background line (FII / Goldman, 18 Nov) and, at 1600, the second news line in the pane. No number, arrow, head or chip ends in "…".

## Rules over every member (test_rules.js: the one shared module used by the laptop and the phone)
| # | rule | what was checked | result | note |
|---|---|---|---|---|
| 1 | six groups only | every member is in COMING UP / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE | PASS |  |
| 2 | COMING UP = 4 gates and not EXTENDED | no share in COMING UP/DOWN NOW fails a gate or is extended (INFY case) | PASS | all 16 pass |
| 3 | COMING UP score on at 0.60 | every COMING UP share scores ≥ 0.60 | PASS |  |
| 4 | EXTENDED rule | EXT > 1.0 or range used > 0.8 ATR, the same flag in list, gate and pane | PASS |  |
| 5 | LAGGARD only at breadth ≥ 70% | no LAGGARD where breadth is under 70% one way | PASS | laggards: HDFCBANK (Banks 76%), OBEROIRLTY (Realty 73%), VEDL (Metals 71%), TECHM (IT 70%) |
| 6 | "no laggard" sectors | sectors under 70% show "no laggard - breadth n%" | PASS | NBFC & finance 63%, Auto 52%, Cement 54%, Power 52%, Oil & gas 60%, Pharma 66%, FMCG 65% |
| 7 | one LEADER per sector | at most one LEADER chip in a sector (Realty / FMCG had two) | PASS | SBIN · SHRIRAMFIN · GODREJPROP · HINDALCO · BAJAJ-AUTO · ULTRACEMCO · NTPC · BPCL · DRREDDY · NESTLEIND · TCS |
| 8 | LEADER group = extended or a gate fails | a leader that passes every gate and is not extended is in COMING UP (BPCL, DRREDDY, NESTLEIND) | PASS |  |
| 9 | AGAINST rule | moving the other way with RS30 ≤ −0.5 | PASS |  |
| 10 | R:R < 1 → 0 lots | no share is sized with R:R below 1 after costs (INFY 0.07, BANDHAN 0.46, YES 0.09 cases) | PASS |  |
| 11 | 1 lot > 1R → 0 lots | no share is sized when one lot risks more than 1R | PASS |  |
| 12 | WAITING / NOT TRADABLE → 0 lots | no lots while a gate fails or in ban | PASS |  |
| 13 | BAN hard block | INDUSINDBK / HINDCOPPER: 0 lots, "BAN - only close existing", not takeable (no ★, no Copy) | PASS |  |
| 14 | STALE hard block | stale share quote → 0 lots, no GO NOW | PASS |  |
| 15 | option quote age | a stale option book (LODHA 11s) blocks like a stale share | PASS | LODHA OPTION STALE 11s |
| 16 | LAGGARD shows its trigger price | every laggard has a number (TECHM "trig < OR low" case) | PASS | HDFCBANK 1016, OBEROIRLTY 1713.5, VEDL 488.2, TECHM 1511 |
| 17 | ICICIBANK arithmetic unchanged | risk ₹3,070 = 0.61R, R:R 1.31, 1 lot, 1,460 CE ask 46.60 | PASS | risk 3070 rr 1.31 · lock room allows 3 · 1R rule allows 1 → 1 lot |
| 18 | sizing wording | "lock room allows 3 · 1R rule allows 1 → 1 lot" | PASS | lock room allows 3 · 1R rule allows 1 → 1 lot |
| 19 | hysteresis on 0.60 / off 0.45 | comingUp(0.55, was) = true, (0.55, new) = false, (0.44, was) = false, (0.61, new) = true | PASS |  |
| 20 | TODAY flow = ff × (sector − NIFTY) | IT −1.76% vs NIFTY on ₹25 lakh cr = −₹44,000 cr; Banks +0.40% on ₹42 lakh cr | PASS | IT -44000 · Banks 16800 |
| 21 | 30M flow totals | OUT and IN sums shown (₹7,140 cr each) | PASS | OUT 7140 · IN 7140 |
| 22 | Banks basis = NIFTY BANK | Banks move = NIFTY BANK +1.12% (as in the strip), the all-41 basket +1.06% shown beside it | PASS |  |
| 23 | NARROW flag | F&O ≥ 75% one way while the other listed < 60% | PASS | Auto, Oil & gas |
| 24 | pending re-rank | AXISBANK ▲1 pending at load (score 0.89 > ICICI 0.86, snapshot order kept) | PASS | {"AXISBANK":1} |
| 25 | Banks WHY = no live driver | live slot holds only today: "UNEXPLAINED" + BANKNIFTY fut LB; FII / Goldman are background 18 Nov | PASS |  |
| 26 | HDFCBANK own story | no yesterday commentary as a headline ("no story of its own today") | PASS |  |
PASS 26 FAIL 0

## Every control (test_desk.js): 204 rows across 1600 and 1366
| # | size | control | what was done | expected | result | note |
|---|---|---|---|---|---|---|
| 1 | 1600 | open list layout | Banks open at load | next sector row below the block, no member row overprints another | PASS | pushed=true overlaps=0 |
| 2 | 1600 | row cap + "+n more" bar | count whole share rows in the first view | ≥ 12 whole rows, then a full-width bar naming the hidden shares | PASS | visible=12 · bar "▾ +2 more: AUBANK · YESBANK" |
| 3 | 1600 | scrollbar size (R51) | measure the drawn list and pane rails | visible track and thumb ≥ 10 px wide, ▲▼ buttons ≥ 16 x 16 px | PASS | wb: track 12 thumb 12 ▲ 16x16 ▼ 16x16 · pb: track 12 thumb 12 ▲ 16x16 ▼ 16x16 |
| 4 | 1600 | no cut number, arrow, head or chip | open all 11 sectors with "+n more" and "not F&O" open; every row cell, column head and chip: scrollWidth vs clientWidth with NO tolerance | nothing ends in "…" or is painted past its cell (RVOL ▲, vs sec ↗, VWAP·OR, WT%, ROT CONFIRMED 22m) | PASS | 2515 cells · 0 cut |
| 5 | 1600 | chip text ≥ 12 px (CONFERENCE 1.4) | getComputedStyle on every chip on the page (strike chips in rows and the trade box, COMING UP NOW, role, state) | none under 12 px | PASS | 1,460 CE 12px · 1,250 CE 12px · 275 CE 12px · 990 CE 12px |
| 6 | 1600 | chart level labels | read the mini chart labels for ICICIBANK | TRIG / STOP / TGT (no lone T that reads as target) | PASS | TGT 1,475.0 · TRIG 1,463.5 · STOP 1,456.0 |
| 7 | 1600 | sticky sector line | scroll the list 120 px | the sector line stays pinned at the top of the list | PASS | offset 0.0 px |
| 8 | 1600 | share row click (row centre) | mouse click at the centre of the AXISBANK row | loads AXISBANK in the pane, the page does not leave | PASS | sel AXISBANK · rotation-drilldown.html |
| 9 | 1600 | every visible share name | click each visible share name in turn | the pane loads each share; the list stays | PASS | ICICIBANK AXISBANK BANKBARODA SBIN HDFCBANK CANBK PNB KOTAKBANK FEDERALBNK IDFCFIRSTB BANDHANBNK INDUSINDBK |
| 10 | 1600 | pane share name - single click | single click on the big share name in the pane | nothing happens (double-click or Enter = F7) | PASS | rotation-drilldown.html |
| 11 | 1600 | J through the whole list | click the first row, press J 13 times | reaches all 14 shares, opening "+n more" when J reaches a hidden one; the pane follows | PASS | AXISBANK → ICICIBANK → BANKBARODA → SBIN → HDFCBANK → CANBK → PNB → KOTAKBANK → FEDERALBNK → IDFCFIRSTB → AUBANK → YESBANK → BANDHANBNK → INDUSINDBK |
| 12 | 1600 | K back up | press K 12 times | back to the 2nd share (ICICIBANK), the pane follows | PASS | ICICIBANK |
| 13 | 1600 | ↓ / ↑ (focus in the list) | click a row, press ↓ then ↑ | next share, then back | PASS | BANKBARODA → ICICIBANK |
| 14 | 1600 | J / K after a click in the pane | click in the share pane, press J, K, then ↓ ↓ | J / K still move share to share; ↓ scrolls the pane, not the list | PASS | focus pb · ICICIBANK J BANKBARODA · K ICICIBANK · pane 0→80 |
| 15 | 1600 | list scrollbar - slow drag | mouse down on the thumb, drag 60 px down in 12 steps, release; then back up | the list follows the thumb both ways | PASS | 0 → 360 → 244 |
| 16 | 1600 | list scrollbar - fast drag | one-step 120 px jerk on the thumb | the list jumps with the thumb | PASS | 244 → 360 |
| 17 | 1600 | list scrollbar - past the end, off the rail | drag the thumb 900 px down and 160 px sideways off the rail, release, move on | stops at the maximum; release ends the drag | PASS | → 360 (max 360) · after release 360 |
| 18 | 1600 | list scrollbar - past the top | drag the thumb 900 px up and off the rail | stops at 0 | PASS | → 0 |
| 19 | 1600 | list scrollbar - track click | click the track below the thumb, then above it | pages down, then up | PASS | 0 → 360 → 0 |
| 20 | 1600 | list scrollbar - ▲ ▼ buttons | click ▼ then ▲ | scrolls 52 px each way | PASS | 0 → 52 → 0 |
| 21 | 1600 | list - mouse wheel | wheel down over the list, wheel up over the scrollbar | scrolls both ways | PASS | 0 → 240 → 120 |
| 22 | 1600 | list - PageDown / End / PageUp / Home | click a share row (focus by click), press each key | pages, ends, pages back, home | PASS | focus wb · 120 → 360 → 360 → 0 → 0 |
| 23 | 1600 | thumb size follows the content | collapse "+n more", collapse the not-F&O line | thumb height = track × visible / total each time | PASS | 240.5/240.6 · 256.1/256.1 · 272.4/272.4 |
| 24 | 1600 | pane scrollbar - drag, past end, track, ▲▼ | drag the pane thumb 82 px, then 900 px down off the rail, click the track top, ▼, ▲ | pane follows; stops at max; pages up; ±52 | PASS | 0 → 138 → 379 (max 379) → 0 → 52 → 0 |
| 25 | 1600 | pane - wheel and keys | wheel over the pane; click in it, Home, PageDown, End | scrolls; keys act on the pane | PASS | 0 → 300 · 0 → 379 → 379 |
| 26 | 1600 | W why + Esc | press W, then Esc | Why drawer opens (sector: today UNEXPLAINED, background 18 Nov), Esc closes it | PASS |  |
| 27 | 1600 | Space plan card + Esc | press Space, then Esc | plan card opens and closes | PASS |  |
| 28 | 1600 | P pin (toggle) | press P twice | pinned 1/5 with a PIN tag, then unpinned 0/5 | PASS | ICICIBANK pinned to the Desk watchlist (1/5) |
| 29 | 1600 | O → option chain, Back | press o, then browser Back | opens chain.html; Back returns to Banks / ICICIBANK, same scroll, focus in the list | PASS | went to chain.html#ICICIBANK-1460CE-29DEC · back: Banks / ICICIBANK y=30 |
| 30 | 1600 | Enter → F7, Back | press Enter, then browser Back | opens share.html; Back returns to Banks / ICICIBANK, same scroll, focus in the list | PASS | went to share.html#ICICIBANK · back: Banks / ICICIBANK y=30 |
| 31 | 1600 | pane button Enter F7 | click it, then Back | opens share.html#ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to share.html#ICICIBANK |
| 32 | 1600 | pane button O chain | click it, then Back | opens chain.html#ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to chain.html#ICICIBANK-1460CE-29DEC |
| 33 | 1600 | pane build-up chip LB › (F10) | click it, then Back | opens futures-oi.html#bu=LB&s=ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to futures-oi.html#bu=LB&s=ICICIBANK |
| 34 | 1600 | double-click a share row → F7, Back | double-click AXISBANK, then Back | share.html#AXISBANK; Back → Banks / AXISBANK | PASS | share.html#AXISBANK |
| 35 | 1600 | double-click the pane share name → F7 | double-click the big name in the pane, then Back | share.html#AXISBANK | PASS | share.html#AXISBANK |
| 36 | 1600 | O / W with no share selected | Esc (clear the share), press O, then W | a hint "pick a share first", no navigation | PASS | pick a share first - click a row or press J |
| 37 | 1600 | Enter on a focused chip | click 30M, Tab to the 1H chip, press Enter (ICICIBANK selected) | switches the flow window to 1H; does not open F7 | PASS | focused 1H · range 10:05-11:05 |
| 38 | 1600 | Space on a focused chip | click TABLE, Tab to RUN CLOCK, press Space | switches to the run-clock view; the Plan card does not open | PASS | focused RUN CLOCK |
| 39 | 1600 | keyboard to a sector row + Enter | click the panel title, Tab to the first sector row, ↓, Enter; ↓ ↓, Enter | opens the focused sector each time, one open at a time | PASS | Tab×4 → Banks · ↓ NBFC & finance Enter → NBFC & finance · ↓↓ Metals Enter → Metals |
| 40 | 1600 | keys 1-9 | press 3, then 1 | Realty opens, then Banks | PASS |  |
| 41 | 1600 | Esc step by step | Why open → Esc ×3 | closes Why → clears the share (compare table) → closes the list | PASS |  |
| 42 | 1600 | re-rank on pointer leave (early) | hover the list 2.5 s after load, move the pointer out | the pending order (AXISBANK ▲1) applies at once on leave | PASS | AXISBANK ICICIBANK BANKBARODA |
| 43 | 1600 | re-rank after 30 s (pointer outside) | load, keep the pointer outside the list for 31.5 s | still pending at 25 s; applied by the 30 s timer | PASS | at 25 s chip=true · at 31.5 s AXISBANK ICICIBANK |
| 44 | 1600 | order holds under the pointer | keep the pointer on the list for 35 s, then leave | order unchanged and chip shown for 35 s; applies on leave | PASS | 35 s: ICICIBANK AXISBANK · after leave: AXISBANK ICICIBANK |
| 45 | 1600 | order holds under keyboard focus | Tab into the list, pointer outside for 31.5 s, then click elsewhere | not applied while focus is in the list; applies when focus leaves | PASS | focus wb (Tab×3) · 31.5 s: ICICIBANK · after: AXISBANK |
| 46 | 1600 | live ticks in fixed-width cells | watch the open list for 10.5 s | numbers change; every cell keeps its width | PASS | day % changed: true · widths equal: true |
| 47 | 1600 | rank change under the pointer | pointer resting on AXISBANK when ICICIBANK's score rises (simulated tick) | ▲1 and the chip show, the order and the row under the pointer do not move; applies on leave | PASS | during: AXISBANK ICICIBANK (under pointer AXISBANK, mark ▲1) · after leave: ICICIBANK AXISBANK |
| 48 | 1600 | "re-ranked · R apply" chip | click the chip | AXISBANK moves above ICICIBANK | PASS |  |
| 49 | 1600 | R key | press R | pending order applies | PASS |  |
| 50 | 1600 | group names | read every group label in the DOM | COMING UP NOW / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE; no "GATE OPEN" | PASS | COMING UP NOW · LEADER · LAGGARD · WAITING · AGAINST (1) · NOT TRADABLE |
| 51 | 1600 | NEW entrant at the bottom | read the COMING UP group | BANKBARODA (NEW 11:01) is the last row of its group with a NEW chip | PASS |  |
| 52 | 1600 | no laggard below 70% | open NBFC & finance (breadth 63%) | "no laggard - breadth 63% one way, below the 70% rule" | PASS |  |
| 53 | 1600 | NARROW flag | open Auto | NARROW chip on the sector line and the row | PASS |  |
| 54 | 1600 | basis › | click basis › on Auto | popup states NIFTY AUTO, all 46 listed, NARROW - F&O-only move | PASS |  |
| 55 | 1600 | falling sector mirror | open IT | COMING DOWN NOW with PE strikes; WHY names its source | PASS |  |
| 56 | 1600 | BAN hard block (pane) | select INDUSINDBK | banner "BAN - only close existing", no trigger/stop/target, no ★, Copy disabled | PASS |  |
| 57 | 1600 | STALE hard block | select AUBANK | banner STALE 12s, trade box greyed with its age, 0 lots, Copy disabled | PASS |  |
| 58 | 1600 | MWPL 80-90% amber + WAITING 0 lots | select IDFCFIRSTB | amber "MWPL 86% · near ban"; "0 lots · waiting - RS15 −0.10 fails" | PASS |  |
| 59 | 1600 | MWPL ≥ 90% red + ex-date | select PNB | red "MWPL 91% · near ban"; ex-date chip | PASS |  |
| 60 | 1600 | RESULTS - IV crush chip | select FEDERALBNK | "RESULTS 20 Nov 15:45 - IV crush" | PASS |  |
| 61 | 1600 | LAGGARD own trigger | select HDFCBANK | trigger 1,016.0 shown; "no story of its own today" | PASS |  |
| 62 | 1600 | EXTENDED leader | select SBIN | row "EXT→974.5"; pane "pullback to VWAP 974.5 / first higher low" | PASS |  |
| 63 | 1600 | Copy on a blocked share | click the disabled Copy button on INDUSINDBK (BAN), then AUBANK (STALE) | nothing is copied | PASS | ["",""] |
| 64 | 1600 | option quote stale | select LODHA (1,210 CE quote 11 s old) | row "OPT 11s", banner "OPTION STALE 11s", 0 lots | PASS |  |
| 65 | 1600 | R:R < 1 → 0 lots | select DLF (R:R 0.89) | "0 lots · R:R 0.89 after costs - not worth it" in red, no ★, Copy off | PASS |  |
| 66 | 1600 | state: forming | mock ▾ → forming, ICICIBANK selected | groups read FORMING, banner, 0 lots | PASS |  |
| 67 | 1600 | state: manage | mock ▾ → manage, ICICIBANK selected | banner "manage only - no new entries", 0 lots, 15:10 in 0h 30m | PASS |  |
| 68 | 1600 | state: locked | mock ▾ → locked, ICICIBANK selected | banner "LOCKED · 3 losing trades = −₹10,000", Copy disabled; the P&L strip agrees: TODAY −₹10,000, TRADES 3 of 3, lock ₹0 left; pane "trades 3 of 3" | PASS |  |
| 69 | 1600 | state: held | mock ▾ → held, ICICIBANK selected | BANKBARODA HELD chip; "you already hold this sector"; strip and pane both "trades 1 of 3" | PASS |  |
| 70 | 1600 | state: preopen | mock ▾ → preopen, ICICIBANK selected | Morning variant "PRE-OPEN - NOT LIVE", 0 lots | PASS |  |
| 71 | 1600 | state: live | mock ▾ → live, ICICIBANK selected | back to live: no banner, 1 lot | PASS |  |
| 72 | 1600 | Back keeps the expanded list | "+6 more" → FEDERALBNK, scroll 200, O, Back, then J | 14 rows, FEDERALBNK selected in list and pane, same scroll, J → next share | PASS | rows 14 · sel FEDERALBNK · pane FEDERALBNK · y 200 · J → IDFCFIRSTB |
| 73 | 1600 | window chip 15M | click it | flow range 10:50-11:05 | PASS | 10:50-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.082% vs NIFTY = −₹2,050 cr · click = open ITFMCG: free-f |
| 74 | 1600 | window chip 1H | click it | flow range 10:05-11:05 | PASS | 10:05-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.278% vs NIFTY = −₹6,940 cr · click = open ITFMCG: free-f |
| 75 | 1600 | window chip TODAY | click it | flow range 09:15-11:05; IT −₹44,000 cr (ff × (sector − NIFTY)) | PASS | 09:15-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −1.760% vs NIFTY = −₹44,000 cr · click = open ITFMCG: free- |
| 76 | 1600 | window chip 30M | click it | flow range 10:35-11:05 | PASS | 10:35-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.165% vs NIFTY = −₹4,120 cr · click = open ITFMCG: free-f |
| 77 | 1600 | flow labels (30M) | click the centre of every sector label in the picture | opens that sector | PASS | IT→IT · FMCG→FMCG · Banks→Banks · NBFC→NBFC & finance |
| 78 | 1600 | flow ribbons (30M) | click every sector ribbon (thinnest included) on the ribbon itself | opens that ribbon's sector; "others" names its sectors | PASS | 5 ribbons · IT→IT (25px) · FMCG→FMCG (14px) · others→toast (8px) · Banks→Banks (36px) · NBFC & finance→NBFC & finance (9px) |
| 79 | 1600 | flow labels (TODAY) | click the centre of every sector label in the picture | opens that sector | PASS | IT→IT · FMCG→FMCG · Banks→Banks · Realty→Realty |
| 80 | 1600 | flow ribbons (TODAY) | click every sector ribbon (thinnest included) on the ribbon itself | opens that ribbon's sector; "others" names its sectors | PASS | 6 ribbons · IT→IT (18px) · FMCG→FMCG (9px) · others→toast (21px) · Banks→Banks (21px) · Realty→Realty (19px) · others→toast (17px) |
| 81 | 1600 | headline word | click IT in the hero line | opens IT | PASS |  |
| 82 | 1600 | "moving, not this rotation" | click Realty | opens Realty | PASS |  |
| 83 | 1600 | new-entrant chip | click BAJFINANCE | opens NBFC and loads BAJFINANCE | PASS |  |
| 84 | 1600 | compare table row | Esc, click the first share in the compare table | loads it | PASS |  |
| 85 | 1600 | RUN CLOCK + run row | click RUN CLOCK, then the IT row | run rows shown; IT opens in the table view | PASS | 7 run rows |
| 86 | 1600 | "27 more listed, not F&O" | click it, click again | shows the context list (no strikes), hides it | PASS |  |
| 87 | 1600 | "+n more" bar | click it, then "show fewer" | all 14 rows, then back to the cap | PASS | 14 → 12 |
| 88 | 1600 | basis › (Banks) | click basis › | NIFTY BANK +1.12% is the move; all-41 basket +1.06% for reference | PASS |  |
| 89 | 1600 | pane button W why | click it, then ✕ | opens and closes | PASS |  |
| 90 | 1600 | pane button P pin | click twice | 1/5 then 0/5 | PASS |  |
| 91 | 1600 | Copy contract | click it (ICICIBANK, 1 lot) | "copied: ICICIBANK 29DEC 1460 CE" | PASS |  |
| 92 | 1600 | ALL SECTORS chip | click it | toast "11 listed" | PASS |  |
| 93 | 1600 | pinned chip | click it | lists the pins or says none | PASS |  |
| 94 | 1600 | tab F2 Sectors | click it, then Back | opens sectors.html | PASS | sectors.html |
| 95 | 1600 | tab F7 Share | click it, then Back | opens share.html | PASS | share.html |
| 96 | 1600 | tab ⇧F1 Morning | click it, then Back | opens morning.html | PASS | morning.html |
| 97 | 1600 | tab F3 Rotation | click it, then Back | opens rotation.html | PASS | rotation.html |
| 98 | 1600 | P&L strip → F6 | click it, then Back | opens positions.html | PASS | positions.html |
| 99 | 1600 | footer health link | click it, then Back | opens health.html | PASS | health.html |
| 100 | 1600 | cycle bar SHARE | click it, then Back | opens share.html#ICICIBANK | PASS | share.html#ICICIBANK |
| 101 | 1600 | cycle bar STRIKE | click it, then Back | opens chain.html#ICICIBANK | PASS | chain.html#ICICIBANK-1460CE |
| 102 | 1600 | page errors | console / page errors during all of the above | none | PASS |  |
| 103 | 1366 | open list layout | Banks open at load | next sector row below the block, no member row overprints another | PASS | pushed=true overlaps=0 |
| 104 | 1366 | row cap + "+n more" bar | count whole share rows in the first view | ≥ 8 whole rows, then a full-width bar naming the hidden shares | PASS | visible=8 · bar "▾ +6 more: PNB · KOTAKBANK · FEDERALBNK · IDFCFIRSTB · AUBANK · YESBANK" |
| 105 | 1366 | scrollbar size (R51) | measure the drawn list and pane rails | visible track and thumb ≥ 10 px wide, ▲▼ buttons ≥ 16 x 16 px | PASS | wb: track 12 thumb 12 ▲ 16x16 ▼ 16x16 · pb: track 12 thumb 12 ▲ 16x16 ▼ 16x16 |
| 106 | 1366 | no cut number, arrow, head or chip | open all 11 sectors with "+n more" and "not F&O" open; every row cell, column head and chip: scrollWidth vs clientWidth with NO tolerance | nothing ends in "…" or is painted past its cell (RVOL ▲, vs sec ↗, VWAP·OR, WT%, ROT CONFIRMED 22m) | PASS | 2515 cells · 0 cut |
| 107 | 1366 | chip text ≥ 12 px (CONFERENCE 1.4) | getComputedStyle on every chip on the page (strike chips in rows and the trade box, COMING UP NOW, role, state) | none under 12 px | PASS | 1,460 CE 12px · 1,250 CE 12px · 275 CE 12px · 990 CE 12px |
| 108 | 1366 | chart level labels | read the mini chart labels for ICICIBANK | TRIG / STOP / TGT (no lone T that reads as target) | PASS | TGT 1,475.0 · TRIG 1,463.5 · STOP 1,456.0 |
| 109 | 1366 | sticky sector line | scroll the list 120 px | the sector line stays pinned at the top of the list | PASS | offset 0.0 px |
| 110 | 1366 | share row click (row centre) | mouse click at the centre of the AXISBANK row | loads AXISBANK in the pane, the page does not leave | PASS | sel AXISBANK · rotation-drilldown.html |
| 111 | 1366 | every visible share name | click each visible share name in turn | the pane loads each share; the list stays | PASS | ICICIBANK AXISBANK BANKBARODA SBIN HDFCBANK CANBK BANDHANBNK INDUSINDBK |
| 112 | 1366 | pane share name - single click | single click on the big share name in the pane | nothing happens (double-click or Enter = F7) | PASS | rotation-drilldown.html |
| 113 | 1366 | J through the whole list | click the first row, press J 13 times | reaches all 14 shares, opening "+n more" when J reaches a hidden one; the pane follows | PASS | AXISBANK → ICICIBANK → BANKBARODA → SBIN → HDFCBANK → CANBK → PNB → KOTAKBANK → FEDERALBNK → IDFCFIRSTB → AUBANK → YESBANK → BANDHANBNK → INDUSINDBK |
| 114 | 1366 | K back up | press K 12 times | back to the 2nd share (ICICIBANK), the pane follows | PASS | ICICIBANK |
| 115 | 1366 | ↓ / ↑ (focus in the list) | click a row, press ↓ then ↑ | next share, then back | PASS | BANKBARODA → ICICIBANK |
| 116 | 1366 | J / K after a click in the pane | click in the share pane, press J, K, then ↓ ↓ | J / K still move share to share; ↓ scrolls the pane, not the list | PASS | focus pb · ICICIBANK J BANKBARODA · K ICICIBANK · pane 0→80 |
| 117 | 1366 | list scrollbar - slow drag | mouse down on the thumb, drag 60 px down in 12 steps, release; then back up | the list follows the thumb both ways | PASS | 0 → 395 → 254 |
| 118 | 1366 | list scrollbar - fast drag | one-step 120 px jerk on the thumb | the list jumps with the thumb | PASS | 254 → 395 |
| 119 | 1366 | list scrollbar - past the end, off the rail | drag the thumb 900 px down and 160 px sideways off the rail, release, move on | stops at the maximum; release ends the drag | PASS | → 395 (max 395) · after release 395 |
| 120 | 1366 | list scrollbar - past the top | drag the thumb 900 px up and off the rail | stops at 0 | PASS | → 0 |
| 121 | 1366 | list scrollbar - track click | click the track below the thumb, then above it | pages down, then up | PASS | 0 → 317 → 0 |
| 122 | 1366 | list scrollbar - ▲ ▼ buttons | click ▼ then ▲ | scrolls 52 px each way | PASS | 0 → 52 → 0 |
| 123 | 1366 | list - mouse wheel | wheel down over the list, wheel up over the scrollbar | scrolls both ways | PASS | 0 → 240 → 120 |
| 124 | 1366 | list - PageDown / End / PageUp / Home | click a share row (focus by click), press each key | pages, ends, pages back, home | PASS | focus wb · 120 → 395 → 395 → 78 → 0 |
| 125 | 1366 | thumb size follows the content | collapse "+n more", collapse the not-F&O line | thumb height = track × visible / total each time | PASS | 149.8/149.8 · 183.8/183.8 · 198.8/198.8 |
| 126 | 1366 | pane scrollbar - drag, past end, track, ▲▼ | drag the pane thumb 82 px, then 900 px down off the rail, click the track top, ▼, ▲ | pane follows; stops at max; pages up; ±52 | PASS | 0 → 167 → 458 (max 458) → 1 → 53 → 1 |
| 127 | 1366 | pane - wheel and keys | wheel over the pane; click in it, Home, PageDown, End | scrolls; keys act on the pane | PASS | 1 → 301 · 0 → 457 → 458 |
| 128 | 1366 | W why + Esc | press W, then Esc | Why drawer opens (sector: today UNEXPLAINED, background 18 Nov), Esc closes it | PASS |  |
| 129 | 1366 | Space plan card + Esc | press Space, then Esc | plan card opens and closes | PASS |  |
| 130 | 1366 | P pin (toggle) | press P twice | pinned 1/5 with a PIN tag, then unpinned 0/5 | PASS | ICICIBANK pinned to the Desk watchlist (1/5) |
| 131 | 1366 | O → option chain, Back | press o, then browser Back | opens chain.html; Back returns to Banks / ICICIBANK, same scroll, focus in the list | PASS | went to chain.html#ICICIBANK-1460CE-29DEC · back: Banks / ICICIBANK y=30 |
| 132 | 1366 | Enter → F7, Back | press Enter, then browser Back | opens share.html; Back returns to Banks / ICICIBANK, same scroll, focus in the list | PASS | went to share.html#ICICIBANK · back: Banks / ICICIBANK y=30 |
| 133 | 1366 | pane button Enter F7 | click it, then Back | opens share.html#ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to share.html#ICICIBANK |
| 134 | 1366 | pane button O chain | click it, then Back | opens chain.html#ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to chain.html#ICICIBANK-1460CE-29DEC |
| 135 | 1366 | pane build-up chip LB › (F10) | click it, then Back | opens futures-oi.html#bu=LB&s=ICICIBANK; Back returns to Banks / ICICIBANK | PASS | went to futures-oi.html#bu=LB&s=ICICIBANK |
| 136 | 1366 | double-click a share row → F7, Back | double-click AXISBANK, then Back | share.html#AXISBANK; Back → Banks / AXISBANK | PASS | share.html#AXISBANK |
| 137 | 1366 | double-click the pane share name → F7 | double-click the big name in the pane, then Back | share.html#AXISBANK | PASS | share.html#AXISBANK |
| 138 | 1366 | O / W with no share selected | Esc (clear the share), press O, then W | a hint "pick a share first", no navigation | PASS | pick a share first - click a row or press J |
| 139 | 1366 | Enter on a focused chip | click 30M, Tab to the 1H chip, press Enter (ICICIBANK selected) | switches the flow window to 1H; does not open F7 | PASS | focused 1H · range 10:05-11:05 |
| 140 | 1366 | Space on a focused chip | click TABLE, Tab to RUN CLOCK, press Space | switches to the run-clock view; the Plan card does not open | PASS | focused RUN CLOCK |
| 141 | 1366 | keyboard to a sector row + Enter | click the panel title, Tab to the first sector row, ↓, Enter; ↓ ↓, Enter | opens the focused sector each time, one open at a time | PASS | Tab×4 → Banks · ↓ NBFC & finance Enter → NBFC & finance · ↓↓ Metals Enter → Metals |
| 142 | 1366 | keys 1-9 | press 3, then 1 | Realty opens, then Banks | PASS |  |
| 143 | 1366 | Esc step by step | Why open → Esc ×3 | closes Why → clears the share (compare table) → closes the list | PASS |  |
| 144 | 1366 | re-rank on pointer leave (early) | hover the list 2.5 s after load, move the pointer out | the pending order (AXISBANK ▲1) applies at once on leave | PASS | AXISBANK ICICIBANK BANKBARODA |
| 145 | 1366 | re-rank after 30 s (pointer outside) | load, keep the pointer outside the list for 31.5 s | still pending at 25 s; applied by the 30 s timer | PASS | at 25 s chip=true · at 31.5 s AXISBANK ICICIBANK |
| 146 | 1366 | order holds under the pointer | keep the pointer on the list for 35 s, then leave | order unchanged and chip shown for 35 s; applies on leave | PASS | 35 s: ICICIBANK AXISBANK · after leave: AXISBANK ICICIBANK |
| 147 | 1366 | order holds under keyboard focus | Tab into the list, pointer outside for 31.5 s, then click elsewhere | not applied while focus is in the list; applies when focus leaves | PASS | focus wb (Tab×3) · 31.5 s: ICICIBANK · after: AXISBANK |
| 148 | 1366 | live ticks in fixed-width cells | watch the open list for 10.5 s | numbers change; every cell keeps its width | PASS | day % changed: true · widths equal: true |
| 149 | 1366 | rank change under the pointer | pointer resting on AXISBANK when ICICIBANK's score rises (simulated tick) | ▲1 and the chip show, the order and the row under the pointer do not move; applies on leave | PASS | during: AXISBANK ICICIBANK (under pointer AXISBANK, mark ▲1) · after leave: ICICIBANK AXISBANK |
| 150 | 1366 | "re-ranked · R apply" chip | click the chip | AXISBANK moves above ICICIBANK | PASS |  |
| 151 | 1366 | R key | press R | pending order applies | PASS |  |
| 152 | 1366 | group names | read every group label in the DOM | COMING UP NOW / LEADER / LAGGARD / WAITING / AGAINST / NOT TRADABLE; no "GATE OPEN" | PASS | COMING UP NOW · LEADER · LAGGARD · WAITING · AGAINST (1) · NOT TRADABLE |
| 153 | 1366 | NEW entrant at the bottom | read the COMING UP group | BANKBARODA (NEW 11:01) is the last row of its group with a NEW chip | PASS |  |
| 154 | 1366 | no laggard below 70% | open NBFC & finance (breadth 63%) | "no laggard - breadth 63% one way, below the 70% rule" | PASS |  |
| 155 | 1366 | NARROW flag | open Auto | NARROW chip on the sector line and the row | PASS |  |
| 156 | 1366 | basis › | click basis › on Auto | popup states NIFTY AUTO, all 46 listed, NARROW - F&O-only move | PASS |  |
| 157 | 1366 | falling sector mirror | open IT | COMING DOWN NOW with PE strikes; WHY names its source | PASS |  |
| 158 | 1366 | BAN hard block (pane) | select INDUSINDBK | banner "BAN - only close existing", no trigger/stop/target, no ★, Copy disabled | PASS |  |
| 159 | 1366 | STALE hard block | select AUBANK | banner STALE 12s, trade box greyed with its age, 0 lots, Copy disabled | PASS |  |
| 160 | 1366 | MWPL 80-90% amber + WAITING 0 lots | select IDFCFIRSTB | amber "MWPL 86% · near ban"; "0 lots · waiting - RS15 −0.10 fails" | PASS |  |
| 161 | 1366 | MWPL ≥ 90% red + ex-date | select PNB | red "MWPL 91% · near ban"; ex-date chip | PASS |  |
| 162 | 1366 | RESULTS - IV crush chip | select FEDERALBNK | "RESULTS 20 Nov 15:45 - IV crush" | PASS |  |
| 163 | 1366 | LAGGARD own trigger | select HDFCBANK | trigger 1,016.0 shown; "no story of its own today" | PASS |  |
| 164 | 1366 | EXTENDED leader | select SBIN | row "EXT→974.5"; pane "pullback to VWAP 974.5 / first higher low" | PASS |  |
| 165 | 1366 | Copy on a blocked share | click the disabled Copy button on INDUSINDBK (BAN), then AUBANK (STALE) | nothing is copied | PASS | ["",""] |
| 166 | 1366 | option quote stale | select LODHA (1,210 CE quote 11 s old) | row "OPT 11s", banner "OPTION STALE 11s", 0 lots | PASS |  |
| 167 | 1366 | R:R < 1 → 0 lots | select DLF (R:R 0.89) | "0 lots · R:R 0.89 after costs - not worth it" in red, no ★, Copy off | PASS |  |
| 168 | 1366 | state: forming | mock ▾ → forming, ICICIBANK selected | groups read FORMING, banner, 0 lots | PASS |  |
| 169 | 1366 | state: manage | mock ▾ → manage, ICICIBANK selected | banner "manage only - no new entries", 0 lots, 15:10 in 0h 30m | PASS |  |
| 170 | 1366 | state: locked | mock ▾ → locked, ICICIBANK selected | banner "LOCKED · 3 losing trades = −₹10,000", Copy disabled; the P&L strip agrees: TODAY −₹10,000, TRADES 3 of 3, lock ₹0 left; pane "trades 3 of 3" | PASS |  |
| 171 | 1366 | state: held | mock ▾ → held, ICICIBANK selected | BANKBARODA HELD chip; "you already hold this sector"; strip and pane both "trades 1 of 3" | PASS |  |
| 172 | 1366 | state: preopen | mock ▾ → preopen, ICICIBANK selected | Morning variant "PRE-OPEN - NOT LIVE", 0 lots | PASS |  |
| 173 | 1366 | state: live | mock ▾ → live, ICICIBANK selected | back to live: no banner, 1 lot | PASS |  |
| 174 | 1366 | Back keeps the expanded list | "+6 more" → FEDERALBNK, scroll 200, O, Back, then J | 14 rows, FEDERALBNK selected in list and pane, same scroll, J → next share | PASS | rows 14 · sel FEDERALBNK · pane FEDERALBNK · y 200 · J → IDFCFIRSTB |
| 175 | 1366 | window chip 15M | click it | flow range 10:50-11:05 | PASS | 10:50-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.082% vs NIFTY = −₹2,050 cr · click = open ITFMCG: free-f |
| 176 | 1366 | window chip 1H | click it | flow range 10:05-11:05 | PASS | 10:05-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.278% vs NIFTY = −₹6,940 cr · click = open ITFMCG: free-f |
| 177 | 1366 | window chip TODAY | click it | flow range 09:15-11:05; IT −₹44,000 cr (ff × (sector − NIFTY)) | PASS | 09:15-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −1.760% vs NIFTY = −₹44,000 cr · click = open ITFMCG: free- |
| 178 | 1366 | window chip 30M | click it | flow range 10:35-11:05 | PASS | 10:35-11:05 / IT: free-float mcap ₹25 lakh cr (all listed) × −0.165% vs NIFTY = −₹4,120 cr · click = open ITFMCG: free-f |
| 179 | 1366 | flow labels (30M) | click the centre of every sector label in the picture | opens that sector | PASS | IT→IT · FMCG→FMCG · Banks→Banks · NBFC→NBFC & finance |
| 180 | 1366 | flow ribbons (30M) | click every sector ribbon (thinnest included) on the ribbon itself | opens that ribbon's sector; "others" names its sectors | PASS | 5 ribbons · IT→IT (19px) · FMCG→FMCG (10px) · others→toast (8px) · Banks→Banks (28px) · NBFC & finance→NBFC & finance (7px) |
| 181 | 1366 | flow labels (TODAY) | click the centre of every sector label in the picture | opens that sector | PASS | IT→IT · FMCG→FMCG · Banks→Banks · Realty→Realty |
| 182 | 1366 | flow ribbons (TODAY) | click every sector ribbon (thinnest included) on the ribbon itself | opens that ribbon's sector; "others" names its sectors | PASS | 6 ribbons · IT→IT (14px) · FMCG→FMCG (7px) · others→toast (16px) · Banks→Banks (16px) · Realty→Realty (14px) · others→toast (12px) |
| 183 | 1366 | headline word | click IT in the hero line | opens IT | PASS |  |
| 184 | 1366 | "moving, not this rotation" | click Realty | opens Realty | PASS |  |
| 185 | 1366 | new-entrant chip | click BAJFINANCE | opens NBFC and loads BAJFINANCE | PASS |  |
| 186 | 1366 | compare table row | Esc, click the first share in the compare table | loads it | PASS |  |
| 187 | 1366 | RUN CLOCK + run row | click RUN CLOCK, then the IT row | run rows shown; IT opens in the table view | PASS | 7 run rows |
| 188 | 1366 | "27 more listed, not F&O" | click it, click again | shows the context list (no strikes), hides it | PASS |  |
| 189 | 1366 | "+n more" bar | click it, then "show fewer" | all 14 rows, then back to the cap | PASS | 14 → 8 |
| 190 | 1366 | basis › (Banks) | click basis › | NIFTY BANK +1.12% is the move; all-41 basket +1.06% for reference | PASS |  |
| 191 | 1366 | pane button W why | click it, then ✕ | opens and closes | PASS |  |
| 192 | 1366 | pane button P pin | click twice | 1/5 then 0/5 | PASS |  |
| 193 | 1366 | Copy contract | click it (ICICIBANK, 1 lot) | "copied: ICICIBANK 29DEC 1460 CE" | PASS |  |
| 194 | 1366 | ALL SECTORS chip | click it | toast "11 listed" | PASS |  |
| 195 | 1366 | pinned chip | click it | lists the pins or says none | PASS |  |
| 196 | 1366 | tab F2 Sectors | click it, then Back | opens sectors.html | PASS | sectors.html |
| 197 | 1366 | tab F7 Share | click it, then Back | opens share.html | PASS | share.html |
| 198 | 1366 | tab ⇧F1 Morning | click it, then Back | opens morning.html | PASS | morning.html |
| 199 | 1366 | tab F3 Rotation | click it, then Back | opens rotation.html | PASS | rotation.html |
| 200 | 1366 | P&L strip → F6 | click it, then Back | opens positions.html | PASS | positions.html |
| 201 | 1366 | footer health link | click it, then Back | opens health.html | PASS | health.html |
| 202 | 1366 | cycle bar SHARE | click it, then Back | opens share.html#ICICIBANK | PASS | share.html#ICICIBANK |
| 203 | 1366 | cycle bar STRIKE | click it, then Back | opens chain.html#ICICIBANK | PASS | chain.html#ICICIBANK-1460CE |
| 204 | 1366 | page errors | console / page errors during all of the above | none | PASS |  |
PASS 204 FAIL 0
