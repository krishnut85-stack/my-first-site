# Phone controls - rotation-drilldown-phone.html (round 3, re-run from scratch on the final build)

19 Nov: `node test_phone.js` (390 x 844, isMobile, hasTouch), run from any folder. **Every tap, swipe and rail drag is a finger**: CDP
`Input.dispatchTouchEvent` touchStart / touchMove / touchEnd, also with an 8 px contact radius. The mouse is never used, except in one
row that also checks the mouse on the rail.

**Result: PASS 46 FAIL 0** (43 round-2 rows re-run, plus 3 new: the sticky action bar, and slow-CPU timing at 4x and 6x).

## What changed in round 3
- **Copy / Pin were about 610 px below the first view.** The share sheet now has a fixed action bar at its foot, above the bottom tabs:
  **Copy 1,460 CE** (it names the contract it copies), **Pin · n/5** and **Full page ›**, each 44 px tall. It stays on screen while the sheet
  scrolls (row 26 measures it at scroll 0, 300 and the end). Copy is tapped in the first view with no scroll (row 27). On a blocked share
  the bar shows "BAN - close only" / "Copy off · 0 lots", disabled, and a tap copies nothing (rows 31-33).
- **Sheet speed on a slow phone.** Rows 44-45 throttle the CPU 4x and 6x with CDP `Emulation.setCPUThrottlingRate` and measure, in the
  page, the time from touchend to the sheet painted (2 animation frames): the sector sheet 32 / 63 ms and the share sheet 38 / 57 ms (normal CPU: 29 ms, row 13). The
  reviewer's ~430 ms included a 390 ms wait in that test, so the sheet itself is far below the 150 ms bar.
- **shot.js is strict on the phone too.** No tolerance (`scrollWidth > clientWidth` fails), every one of the 63 share sheets with its
  action bar, and every one of the 11 sector sheets at the top and at the end of its list. 0 cut.
- The chart labels are TRIG / STOP / TGT and the OR label is clear of its box border on the phone as well (the same shared chart code).

## Layout and type (shot.js)
```
ok   phone 1 Sectors list - Banks UP (tap Banks): fonts >= 13 px, no clipped text
ok   phone 2 Banks sheet - 2-line header, groups: fonts >= 13 px, no clipped text
ok   phone 3 same sheet, WAITING + BAN rows: fonts >= 13 px, no clipped text
ok   phone 4 tap ICICIBANK - share sheet (Back = list): fonts >= 13 px, no clipped text
ok   phone mini chart: no overlapping / outside text for all 63 shares
ok   phone share sheet for all 63 shares: nothing clipped (no tolerance), Copy and Pin on screen in the first view (sticky bar, 44 px)
ok   phone every sector sheet (11), top and end of the list: nothing clipped (no tolerance)
```

## Every control (test_phone.js)
| # | control | what was done | expected | result | note |
|---|---|---|---|---|---|
| 1 | rail size | measure the sector-list rail | touch target ≥ 24 px; visible track and thumb ≥ 10 px | PASS | target 28 · track 12 · thumb 12 px |
| 2 | sector list - finger swipe | touch-drag up 300 px, then down | scrolls with the finger both ways | PASS | 0 → 106 → 0 |
| 3 | sector list - rail thumb, finger drag | touchStart on the thumb centre, 20 touchMoves 150 px down, touchEnd | the list scrolls; no sector opens | PASS | 0 → 106 · sheet open: false |
| 4 | sector list - rail drag, 8 px contact | same drag up with an 8 px touch radius | scrolls back; no row steals the touch | PASS | 106 → 0 |
| 5 | sector list - rail drag at its right edge | finger drag on the outer edge of the rail (x = rail right − 3) | still scrolls | PASS | 0 → 106 |
| 6 | sector list - rail track tap | tap the track below the thumb, then above it | pages down (0.9 screen, or to the end), then up; no neighbouring sector opens | PASS | 0 → 106 (max 106) → 0 · sheet opened: false |
| 7 | sector list - tap on the thumb | tap the thumb itself | nothing opens | PASS |  |
| 8 | sector list - rail, mouse drag | mouse down on the thumb, drag 110 px | scrolls (mouse works too) | PASS | 0 → 106 |
| 9 | window chip 30M ▾ | tap it 4 times | cycles 1H → TODAY → 15M → 30M, the flow line follows | PASS | 1H ▾ mcap vs NIFTY −₹12,300 → +₹12,300 cr · 10:05-11:05 / TODAY ▾ OUT of IT · FMCG → INTO BANKS · REALTY / 15M ▾ |
| 10 | engine PE / CE chip | tap it | explains the PE bias and the CE guarantee | PASS |  |
| 11 | BAN 2 chip | tap it, then ✕ | lists INDUSINDBK 96% and HINDCOPPER 97%, "only close existing" | PASS | ✕ · F&O ban today (2) · INDUSINDBK MWPL 96% (Banks) · HINDCOPPER MWPL 97% (Metals) · In ban: only close existing positions. Ban at 95% MWPL. |
| 12 | tap a sector (Banks) | tap the Banks row | full-screen sheet with all 14 F&O shares | PASS | 14 shares in groups |
| 13 | sheet opens fast | time from touchend to the painted sheet | ≤ 100 ms (no slide transition) | PASS | 15 ms to open · 29 ms to paint |
| 14 | sheet header ≤ 2 lines + WHY | measure the header and the whole share rows in view | header ≈ 3 short lines; ≥ 5 whole share rows visible | PASS | header 99 px · 7 whole rows |
| 15 | Banks sheet - rail size | measure | target ≥ 24 px, track/thumb ≥ 10 px | PASS | 28 / 12 / 12 px |
| 16 | Banks sheet - finger swipe | touch-drag up 350 px, then down 200 | scrolls both ways | PASS | 0 → 448 → 218 |
| 17 | Banks sheet - rail thumb, finger drag | touchStart on the thumb, drag 120 px down | the list scrolls; no share sheet opens | PASS | 218 → 451 |
| 18 | Banks sheet - rail track tap | tap the track above the thumb | pages up; no group header or share opens | PASS | 451 → 0 |
| 19 | WHY › (sector sheet) | tap WHY ›, tap again | shows today UNEXPLAINED + live futures, background 18 Nov, run clock, basis, expiry wording; hides | PASS | WHY UNEXPLAINED · live: BANKNIFTY fut LB · OI +6.2% since 10:05 · background · FII cash +₹1,486 cr (18 Nov prov) · Goldman: India banks to OW (CNBC-TV18, 18 Nov |
| 20 | "27 more listed, not F&O" | tap it, tap again | shows the context list (no strikes), hides it | PASS | J&KBANK +2.14% KARURVYSYA +1.86% CUB +1.62% DCBBANK +1.40% SOUTHBANK +0.92% UJJIVANSFB −0. |
| 21 | tap a share (ICICIBANK) | tap the ICICIBANK row | share sheet: Dec 1,460 CE trade box with quote age, expiry wording, levels, 1 lot, mini chart | PASS |  |
| 22 | share sheet - finger swipe | touch-drag up 320 px | scrolls | PASS | 0 → 393 |
| 23 | share sheet - rail thumb, finger drag | drag the thumb 160 px down | scrolls; nothing else reacts | PASS | 393 → 621 |
| 24 | share sheet - rail track tap | tap the track above the thumb | pages up | PASS | 621 → 167 |
| 25 | WHY › (share sheet) | tap "WHY ICICIBANK is moving ›" | sector why + the share's top news with its age | PASS | Sector: UNEXPLAINED · live: BANKNIFTY fut LB · OI +6.2% since 10:05 · background · FII cash +₹1,486 cr (18 Nov prov) · G |
| 26 | share sheet - action bar (sticky) | open ICICIBANK, measure Copy / Pin / Full page at scroll 0, 300 and the end | all three on screen above the tabs at every scroll, ≥ 44 px tall - no scrolling to copy | PASS | top 111 · mid 111 · end 111 |
| 27 | Copy contract | tap "Copy 1,460 CE" in the first view (no scroll) | "copied: ICICIBANK 29DEC 1460 CE" | PASS | copied: ICICIBANK 29DEC 1460 CE |
| 28 | Pin (toggle, n/5) | tap Pin, tap again | pinned 1/5 with a PIN tag (sheet + list row), then unpinned 0/5 | PASS | ICICIBANK pinned · 1/5 on the Desk watchlist / Unpin · 1/5/true/true / ICICIBANK unpinned · 0/5 on the Desk watchlist / Pin · 0/5/false |
| 29 | ‹ Banks (Back button) | tap Back on the share sheet | the Banks list again, same scroll, ICICIBANK still marked | PASS | y 120 · sel ICICIBANK |
| 30 | device / browser Back (share) | at list y = 120 tap the first visible share (BANKBARODA; its sheet starts at the top), then browser Back | back to the list, same scroll, that share marked | PASS | sheet top 0 · list y 120 · sel BANKBARODA |
| 31 | BAN share (phone) | tap INDUSINDBK | first line "BAN - only close existing · MWPL 96%", no plan rows, no ★, Copy disabled; tapping Copy copies nothing | PASS |  |
| 32 | STALE share (phone) | tap AUBANK | first line STALE 12s, greyed trade box, Copy disabled | PASS |  |
| 33 | WAITING share (phone) | tap YESBANK | first line "0 lots · waiting - RS30 −0.12 fails" | PASS |  |
| 34 | ‹ Sectors (Back button) | tap Back on the Banks sheet | the sector list | PASS |  |
| 35 | no laggard below 70% (phone) | tap NBFC & finance | "LAGGARD · none - breadth 63% one way, below the 70% rule" | PASS |  |
| 36 | tap a falling sector (IT) | tap IT | mirrored: COMING DOWN NOW with PE strikes | PASS |  |
| 37 | INFY (falling, COMING DOWN NOW) | tap INFY | group and sheet agree: not extended, 1,500 PE, R:R ≥ 1, lots shown | PASS |  |
| 38 | Full page › link | tap "Full page ›" on INFY | share.html#INFY | PASS | share.html#INFY |
| 39 | device / browser Back (sector) | browser Back from the IT sheet | the sector list | PASS |  |
| 40 | MY F&O P&L row | tap it | RISK screen (P&L curve, net of costs) | PASS | phone.html#risk |
| 41 | bottom tab NOW | tap it | phone.html#now | PASS | phone.html#now |
| 42 | bottom tab RISK | tap it | phone.html#risk | PASS | phone.html#risk |
| 43 | bottom tab ALERTS | tap it | phone.html#alerts | PASS | phone.html#alerts |
| 44 | slow CPU 4x - sheets open fast | CPU throttled 4x: tap Banks, then tap ICICIBANK; touchend → sheet painted (2 frames) | sector sheet ≤ 150 ms, share sheet ≤ 150 ms | PASS | sector sheet 32 ms · share sheet 38 ms |
| 45 | slow CPU 6x - sheets open fast | CPU throttled 6x: tap Banks, then tap ICICIBANK; touchend → sheet painted (2 frames) | sector sheet ≤ 150 ms, share sheet ≤ 150 ms | PASS | sector sheet 63 ms · share sheet 57 ms |
| 46 | page errors | errors during all of the above | none | PASS |  |
PASS 46 FAIL 0
