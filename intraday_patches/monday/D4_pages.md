# D4 - all 23 pages: console errors, failed requests, cut text, R51 controls

Run 21 Nov 20:00 IST (Sat 21 Nov 2026, market closed). Pages served from disk by a test stub (127.0.0.1:8198) whose /preview/api/* answers are ONE copy of the real gir-preview answers (fetched once, then cached), so the 23 pages x 3 widths put no load on the live server; POSTs (ask / GIR MODE) answered by the stub, never forwarded. Chromium with real (not hidden) scrollbars, deviceScaleFactor 1, one browser, nice 10.

- **console errors / page errors / failed requests**: Playwright console type error, pageerror, requestfailed, any response >= 400.
- **cut cells**: every visible element with text whose scrollWidth > clientWidth, no tolerance, innermost only, every `<details>` open. Not counted: a scroll box (overflow auto / scroll, or inside one) and prose of 4+ words whose tooltip carries the text (the trader's rule). The drill-down (sectors / folds opened) has its own cut check in the drill-down R51 (girdata/review/drilldown).
- **R51**: generic real-input sweep (scratchpad d4/r51all.py): every list that scrolls inside a panel - bar visible >= 10 px, pointer reaches the bar, thumb drag, track click, wheel, PageDown / End / Home / PageUp (phone: finger swipe up / down); every control (links, buttons, tabs, chips, rows with a pointer cursor, max 25 per page, 2 per kind) - pointer reaches it, a click / tap does something, a link opens a page that answers, Back returns, Esc closes what opened. Shell (tabs, F-keys, / search, Esc, Back) once per width on desk-hunt. NOCHANGE = the click changed nothing visible (listed below, checked by hand). NOT RUN = cap reached, or the control was off screen / re-drawn.

## Totals

| | before (first sweep 18:23) | after |
|---|---|---|
| console + page errors | 6 | 0 |
| failed requests | 6 | 0 |
| cut cells | 1179 | 695 |
| R51 rows | - | 2011 PASS · 39 FAIL · 72 NOT RUN · 97 NOCHANGE |

Before: the 2 console errors + 2 failed requests per width on Replay were the stub following the 301 of /preview/replay itself (fixed in the stub, not a page fault); every other page had 0. Before the bar fix the first R51 trial (analyst, desk-trade at 1366) had 4 FAIL on drawn bars (8 px, not draggable) - fixed for every page in shell.js.

## Every page and width

| page | width | console errors | failed requests | cut cells | R51 PASS | R51 FAIL | NOT RUN | NOCHANGE |
|---|---|---|---|---|---|---|---|---|
| analyst | 1366x768 | 0 → 0 | 0 → 0 | 11 → 1 | 57 | 0 | 1 | 0 |
| analyst | 1600x900 | 0 → 0 | 0 → 0 | 7 → 0 | 0 | 0 | 0 | 0 |
| analyst | 390x844 phone | 0 → 0 | 0 → 0 | 9 → 0 | 47 | 0 | 1 | 1 |
| calendar | 1366x768 | 0 → 0 | 0 → 0 | 9 → 9 | 55 | 0 | 1 | 3 |
| calendar | 1600x900 | 0 → 0 | 0 → 0 | 5 → 6 | 0 | 0 | 0 | 0 |
| calendar | 390x844 phone | 0 → 0 | 0 → 0 | 12 → 48 | 39 | 2 | 1 | 2 |
| chain | 1366x768 | 0 → 0 | 0 → 0 | 7 → 16 | 54 | 0 | 2 | 4 |
| chain | 1600x900 | 0 → 0 | 0 → 0 | 7 → 12 | 0 | 0 | 0 | 0 |
| chain | 390x844 phone | 0 → 0 | 0 → 0 | 39 → 48 | 44 | 0 | 2 | 4 |
| desk-hunt | 1366x768 | 0 → 0 | 0 → 0 | 16 → 12 | 51 | 0 | 2 | 1 |
| desk-hunt | 1600x900 | 0 → 0 | 0 → 0 | 58 → 56 | 0 | 0 | 0 | 0 |
| desk-hunt | 390x844 phone | 0 → 0 | 0 → 0 | 42 → 43 | 47 | 0 | 2 | 0 |
| desk-trade | 1366x768 | 0 → 0 | 0 → 0 | 15 → 6 | 49 | 0 | 1 | 0 |
| desk-trade | 1600x900 | 0 → 0 | 0 → 0 | 12 → 4 | 0 | 0 | 0 | 0 |
| desk-trade | 390x844 phone | 0 → 0 | 0 → 0 | 24 → 2 | 45 | 0 | 1 | 0 |
| futures-oi | 1366x768 | 0 → 0 | 0 → 0 | 35 → 35 | 53 | 0 | 1 | 0 |
| futures-oi | 1600x900 | 0 → 0 | 0 → 0 | 7 → 6 | 0 | 0 | 0 | 0 |
| futures-oi | 390x844 phone | 0 → 0 | 0 → 0 | 261 → 49 | 47 | 0 | 1 | 0 |
| health | 1366x768 | 0 → 0 | 0 → 0 | 13 → 11 | 32 | 0 | 2 | 5 |
| health | 1600x900 | 0 → 0 | 0 → 0 | 4 → 2 | 0 | 0 | 0 | 0 |
| health | 390x844 phone | 0 → 0 | 0 → 0 | 3 → 1 | 26 | 0 | 2 | 5 |
| help | 1366x768 | 0 → 0 | 0 → 0 | 2 → 1 | 63 | 0 | 1 | 0 |
| help | 1600x900 | 0 → 0 | 0 → 0 | 4 → 3 | 0 | 0 | 0 | 0 |
| help | 390x844 phone | 0 → 0 | 0 → 0 | 12 → 6 | 49 | 0 | 1 | 0 |
| journal | 1366x768 | 0 → 0 | 0 → 0 | 2 → 0 | 46 | 0 | 2 | 6 |
| journal | 1600x900 | 0 → 0 | 0 → 0 | 2 → 0 | 0 | 0 | 0 | 0 |
| journal | 390x844 phone | 0 → 0 | 0 → 0 | 1 → 0 | 23 | 0 | 2 | 9 |
| market | 1366x768 | 0 → 0 | 0 → 0 | 2 → 2 | 34 | 0 | 1 | 4 |
| market | 1600x900 | 0 → 0 | 0 → 0 | 2 → 2 | 0 | 0 | 0 | 0 |
| market | 390x844 phone | 0 → 0 | 0 → 0 | 3 → 2 | 25 | 0 | 0 | 4 |
| morning | 1366x768 | 0 → 0 | 0 → 0 | 8 → 5 | 48 | 0 | 1 | 0 |
| morning | 1600x900 | 0 → 0 | 0 → 0 | 20 → 18 | 0 | 0 | 0 | 0 |
| morning | 390x844 phone | 0 → 0 | 0 → 0 | 24 → 18 | 42 | 0 | 1 | 0 |
| news | 1366x768 | 0 → 0 | 0 → 0 | 3 → 4 | 46 | 0 | 3 | 0 |
| news | 1600x900 | 0 → 0 | 0 → 0 | 2 → 1 | 0 | 0 | 0 | 0 |
| news | 390x844 phone | 0 → 0 | 0 → 0 | 6 → 4 | 32 | 0 | 3 | 0 |
| phone | 1366x768 | 0 → 0 | 0 → 0 | 11 → 0 | 31 | 1 | 0 | 4 |
| phone | 1600x900 | 0 → 0 | 0 → 0 | 10 → 0 | 0 | 0 | 0 | 0 |
| phone | 390x844 phone | 0 → 0 | 0 → 0 | 11 → 0 | 30 | 0 | 0 | 4 |
| plan-card | 1366x768 | 0 → 0 | 0 → 0 | 7 → 6 | 23 | 0 | 0 | 2 |
| plan-card | 1600x900 | 0 → 0 | 0 → 0 | 2 → 2 | 0 | 0 | 0 | 0 |
| plan-card | 390x844 phone | 0 → 0 | 0 → 0 | 5 → 4 | 14 | 0 | 0 | 2 |
| positions | 1366x768 | 0 → 0 | 0 → 0 | 11 → 7 | 49 | 0 | 1 | 0 |
| positions | 1600x900 | 0 → 0 | 0 → 0 | 8 → 3 | 0 | 0 | 0 | 0 |
| positions | 390x844 phone | 0 → 0 | 0 → 0 | 7 → 3 | 45 | 0 | 1 | 0 |
| reference | 1366x768 | 0 → 0 | 0 → 0 | 46 → 8 | 58 | 0 | 5 | 3 |
| reference | 1600x900 | 0 → 0 | 0 → 0 | 3 → 3 | 0 | 0 | 0 | 0 |
| reference | 390x844 phone | 0 → 0 | 0 → 0 | 20 → 1 | 39 | 0 | 5 | 3 |
| replay | 1366x768 | 2 → 0 | 2 → 0 | 3 → 2 | 6 | 28 | 5 | 0 |
| replay | 1600x900 | 2 → 0 | 2 → 0 | 3 → 1 | 0 | 0 | 0 | 0 |
| replay | 390x844 phone | 2 → 0 | 2 → 0 | 4 → 2 | 30 | 8 | 4 | 1 |
| rotation | 1366x768 | 0 → 0 | 0 → 0 | 7 → 9 | 49 | 0 | 2 | 1 |
| rotation | 1600x900 | 0 → 0 | 0 → 0 | 2 → 4 | 0 | 0 | 0 | 0 |
| rotation | 390x844 phone | 0 → 0 | 0 → 0 | 13 → 11 | 38 | 0 | 2 | 1 |
| scorecard | 1366x768 | 0 → 0 | 0 → 0 | 10 → 7 | 50 | 0 | 2 | 3 |
| scorecard | 1600x900 | 0 → 0 | 0 → 0 | 7 → 5 | 0 | 0 | 0 | 0 |
| scorecard | 390x844 phone | 0 → 0 | 0 → 0 | 48 → 2 | 40 | 0 | 2 | 2 |
| sectors | 1366x768 | 0 → 0 | 0 → 0 | 10 → 8 | 57 | 0 | 1 | 5 |
| sectors | 1600x900 | 0 → 0 | 0 → 0 | 14 → 23 | 0 | 0 | 0 | 0 |
| sectors | 390x844 phone | 0 → 0 | 0 → 0 | 32 → 28 | 40 | 0 | 2 | 6 |
| settings | 1366x768 | 0 → 0 | 0 → 0 | 10 → 5 | 42 | 0 | 1 | 2 |
| settings | 1600x900 | 0 → 0 | 0 → 0 | 5 → 3 | 0 | 0 | 0 | 0 |
| settings | 390x844 phone | 0 → 0 | 0 → 0 | 7 → 4 | 31 | 0 | 2 | 4 |
| share | 1366x768 | 0 → 0 | 0 → 0 | 0 → 0 | 24 | 0 | 0 | 0 |
| share | 1600x900 | 0 → 0 | 0 → 0 | 0 → 0 | 0 | 0 | 0 | 0 |
| share | 390x844 phone | 0 → 0 | 0 → 0 | 2 → 1 | 13 | 0 | 0 | 0 |
| world | 1366x768 | 0 → 0 | 0 → 0 | 70 → 43 | 59 | 0 | 1 | 1 |
| world | 1600x900 | 0 → 0 | 0 → 0 | 45 → 26 | 0 | 0 | 0 | 0 |
| world | 390x844 phone | 0 → 0 | 0 → 0 | 57 → 41 | 36 | 0 | 1 | 1 |
| shell (tabs, F-keys, search) on desk-hunt | 1366x768 | - | - | - | 93 | 0 | 0 | 2 |
| shell (tabs, F-keys, search) on desk-hunt | 390x844 phone | - | - | - | 60 | 0 | 0 | 2 |

## R51 FAIL rows

| page | width | control | evidence |
|---|---|---|---|
| calendar | 390 | a.lk "HOSPITALS & DIAGNOSTICS" -> sectors#hospitals%20%26%20diagnostics - pointer reaches it | covered by A.lk |
| calendar | 390 | div.er "09:45 Realty +1.94% Realty +1." - pointer reaches it | covered by MAIN#page. |
| replay | 390 | input "2026-11-13" - pointer reaches it | covered by B. |
| replay | 390 | input "2026-11-16" - pointer reaches it | covered by A.sh-tab |
| replay | 390 | button "START" - no error | HTTP 423 :8198/preview/replay/api/ctl?cmd=start&days=2026-11-19&from=D-1&speed=5&night=60; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 390 | button.dy "20" - no error | HTTP 423 198/preview/replay/api/ctl?cmd=start&days=2026-11-20&from=09:00&to=15:45&speed=5; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 390 | button.dy "19" - no error | HTTP 423 198/preview/replay/api/ctl?cmd=start&days=2026-11-19&from=09:00&to=15:45&speed=5; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 390 | button.rp-b "1x" - no error | HTTP 423 http://127.0.0.1:8198/preview/replay/api/ctl?cmd=speed&speed=1; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 390 | button.rp-b "5x" - no error | HTTP 423 http://127.0.0.1:8198/preview/replay/api/ctl?cmd=speed&speed=5; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 390 | a.lk "F1 Desk ›" -> desk-hunt - no error | HTTP 404 http://127.0.0.1:8198/preview/replay/api/predict; console: Failed to load resource: the server responded with a status of 404 (Not Found) |
| phone | 1366 | list #b-now (390x502, 502 of 6470 px) - visible bar >= 10 px | no drawn bar found and the native bar is 0 px (scrollbar-width auto) |
| replay | 1366 | list #ybody (286x74, 74 of 200 px) - pointer reaches the bar thumb | top element at the thumb: DIV.inline (pointer-events auto) |
| replay | 1366 | list #ybody (286x74, 74 of 200 px) - mouse drag of the thumb | 0 -> 0 |
| replay | 1366 | list #ybody (286x74, 74 of 200 px) - click on the track below the thumb | 0 -> 0 |
| replay | 1366 | list #ybody (286x74, 74 of 200 px) - mouse wheel down / up | 0 -> 0 -> 0 |
| replay | 1366 | input "2026-11-13" - pointer reaches it | covered by SPAN.sh-pt sh-brk sh-n1366 |
| replay | 1366 | input "2026-11-16" - pointer reaches it | covered by SPAN.nk |
| replay | 1366 | button "START" - no error | HTTP 423 :8198/preview/replay/api/ctl?cmd=start&days=2026-11-19&from=D-1&speed=5&night=60; console: Failed to load resource: the server responded with a status of 423 (Locked) |
| replay | 1366 | a "PREP ⇧F1" -> morning - pointer reaches it | covered by DIV#grp-days.days |
| replay | 1366 | a "FIND F2" -> sectors - pointer reaches it | covered by SMALL. |
| replay | 1366 | a "STRIKE F9" -> chain - pointer reaches it | covered by SMALL. |
| replay | 1366 | a "MANAGE F6" -> positions - pointer reaches it | covered by SMALL. |
| replay | 1366 | a "JOURNAL ⇧F6" -> journal - pointer reaches it | covered by SMALL. |
| replay | 1366 | a "AUDIT ⇧F8" -> scorecard - pointer reaches it | covered by SMALL. |
| replay | 1366 | a.on "REPLAY ⇧F10" -> replay - pointer reaches it | covered by DIV#grp-days.days |
| replay | 1366 | a.rp-real "REAL DAY not known –R" -> positions - pointer reaches it | covered by DIV#grp-idle.inline |
| replay | 1366 | button.on "WATCH" - pointer reaches it | covered by DIV#grp-idle.inline |
| replay | 1366 | button "PRACTICE P" - pointer reaches it | covered by DIV#grp-idle.inline |
| replay | 1366 | button.dy "19" - pointer reaches it | covered by LABEL. |
| replay | 1366 | button.rp-b "⏮" - pointer reaches it | covered by SELECT#grp-speed. |
| replay | 1366 | button.rp-b "▶ PLAY" - pointer reaches it | covered by LABEL. |
| replay | 1366 | button.rp-b "1x" - pointer reaches it | covered by SELECT#grp-night. |
| replay | 1366 | button.rp-b "5x" - pointer reaches it | covered by DIV.row |
| replay | 1366 | button.on "DAY" - pointer reaches it | covered by BUTTON#grp-start. |
| replay | 1366 | button "09:00-12:30" - pointer reaches it | covered by BUTTON#grp-start. |
| replay | 1366 | button.rp-j "09:15" - pointer reaches it | covered by BUTTON#grp-start. |
| replay | 1366 | a.lk "movers now ›" -> sectors#movers - pointer reaches it | covered by P.note |
| replay | 1366 | button "▲" - pointer reaches it | covered by P.note |
| replay | 1366 | button "▼" - pointer reaches it | covered by P.note |

## NOCHANGE rows (the click changed nothing visible - reviewed)

| page | width | control |
|---|---|---|
| chain | 1366 | tr.itmc "– 166.00 72k– 1,040 68k– 0.05" |
| chain | 1366 | tr.itmc "– 150.00 1.34L– 1,060 71k– 0.0" |
| chain | 1366 | tr.itmp "– 6.75 1.04L0 1,220 38k+1k 15." |
| chain | 1366 | tr.itmp "– 2.65 79k0 1,240 1,5000 237.0" |
| desk-hunt | 1366 | a.st "STRIKE" -> desk-hunt |
| shell | 1366 | a.sh-mark "GIR" -> desk-hunt |
| shell | 1366 | span.sh-tab "F5 off no reload" |
| market | 1366 | div.or "−20.6 66.5 25,500 179.8 +107.6" |
| market | 1366 | div.or "−9.9 18.5 25,550 54.3 +46.0" |
| market | 1366 | div.or "+54.8 105.8 25,800 47.5 +43.3" |
| market | 1366 | div.or "−0.9 149.7 26,000 19.0 +5.2" |
| plan-card | 1366 | kbd "W" |
| plan-card | 1366 | kbd "S" |
| reference | 1366 | span.chip ">85% 3" |
| reference | 1366 | div.scw "▾ Index options 5 NIFTY 65 · B" |
| reference | 1366 | div.scw "CRUDE (BRENT) −1.83% PAST BZ=F" |
| rotation | 1366 | span.sdx "HOSPITALS & DIAGNOSTICS" |
| scorecard | 1366 | button "MISSES FIRST" |
| scorecard | 1366 | span.ud "▲ ▼" |
| scorecard | 1366 | button.chip "LATE –" |
| sectors | 1366 | b.sb2 "▲" |
| sectors | 1366 | span.chip "GO NOW 0" |
| sectors | 1366 | span.chip "BLOCKED –" |
| sectors | 1366 | span.chip "– left" |
| sectors | 1366 | span.sbtn "▲" |
| settings | 1366 | div.r "Charter rules not known his ru" |
| settings | 1366 | div.r "Backstops fit room LOCK not kn" |
| world | 1366 | span.sbtn "scroll up" |
| analyst | 390 | span.sbtn "scroll up" |
| calendar | 390 | div.dg "DROVE TODAY pinned · % all lis" |
| calendar | 390 | a.lk2 "F10 ›" -> futures-oi#buildup |
| chain | 390 | tr.itmc "– 166.00 72k– 1,040 68k– 0.05" |
| chain | 390 | tr.itmc "– 150.00 1.34L– 1,060 71k– 0.0" |
| chain | 390 | tr.itmp "– 6.75 1.04L0 1,220 38k+1k 15." |
| chain | 390 | tr.itmp "– 2.65 79k0 1,240 1,5000 237.0" |
| shell | 390 | a.sh-mark "GIR" -> desk-hunt |
| shell | 390 | span.sh-tab "F5 off no reload" |
| health | 390 | div.hv-s "06:38 MARKET MARKET NEWS ▼ MAR" |
| health | 390 | div.hv-rail "" |
| health | 390 | div.hv-rail "" |
| health | 390 | span.hv-chip "LOG 1" |
| health | 390 | span.hv-chip "RINGS –/6" |
| journal | 390 | div.dv "NOT TAKEN · 0 GO NOW CALLS UNT" |
| journal | 390 | div.dv "BLOCKSnone calls GIR held back" |
| journal | 390 | div.dv "GIR EXITSEXIT 0 · BOOK HALF 0 " |
| journal | 390 | div.wf "The R lost at each step (secto" |
| journal | 390 | div.rule "THE ONE RULE this week: not kn" |
| journal | 390 | div.wk-t "(own-trade text hidden)" |
| journal | 390 | div.bh "GIR'S 15:45 AUDIT 2026-11-20 1" |
| journal | 390 | div.bh "BEHAVIOUR GO NOW → your decisi" |
| journal | 390 | div.tl-old "(own-trade text hidden)" |
| market | 390 | div.or "−20.6 66.5 25,500 179.8 +107.6" |
| market | 390 | div.or "−9.9 18.5 25,550 54.3 +46.0" |
| market | 390 | div.or "+54.8 105.8 25,800 47.5 +43.3" |
| market | 390 | div.or "−0.9 149.7 26,000 19.0 +5.2" |
| phone | 390 | div.hero "no exit waiting GIR follows yo" |
| phone | 390 | div.card "(own-trade text hidden)" |
| phone | 390 | div.sec "THE 15:10 LADDER rings as MY E" |
| phone | 390 | a.m-pnl "(own-trade text hidden)" |
| plan-card | 390 | kbd "W" |
| plan-card | 390 | kbd "S" |
| reference | 390 | span.chip ">85% 3" |
| reference | 390 | div.scw "▾ Index options 5 NIFTY 65 · B" |
| reference | 390 | div.scw "CRUDE (BRENT) −1.83% PAST BZ=F" |
| replay | 390 | button.dy "19" |
| rotation | 390 | span.sdx "HOSPITALS & DIAGNOSTICS" |
| scorecard | 390 | button "MISSES FIRST" |
| scorecard | 390 | button.chip "LATE –" |
| sectors | 390 | b.sb2 "▲" |
| sectors | 390 | span.chip "GO NOW 0" |
| sectors | 390 | span.chip "BLOCKED –" |
| sectors | 390 | span.chip "– left" |
| sectors | 390 | span.sbtn "▲" |
| sectors | 390 | span.sbtn "▼" |
| settings | 390 | div.r "Charter rules not known his ru" |
| settings | 390 | div.r "Backstops fit room LOCK not kn" |
| settings | 390 | div.tn "1 GO NOW ▶ TEST one bright chi" |
| settings | 390 | div.tn "2 GET READY sector ▶ TEST one " |
| world | 390 | span.sbtn "scroll up" |
| journal | 1366 | div.dv "NOT TAKEN · 0 GO NOW CALLS UNT" |
| journal | 1366 | div.dv "BLOCKSnone calls GIR held back" |
| journal | 1366 | div.dv "GIR EXITSEXIT 0 · BOOK HALF 0 " |
| journal | 1366 | div.wf "The R lost at each step (secto" |
| journal | 1366 | div.rule "THE ONE RULE this week: not kn" |
| journal | 1366 | div.wk-t "(own-trade text hidden)" |
| phone | 1366 | div.hero "no exit waiting GIR follows yo" |
| phone | 1366 | div.card "(own-trade text hidden)" |
| phone | 1366 | div.sec "THE 15:10 LADDER rings as MY E" |
| phone | 1366 | a.m-pnl "(own-trade text hidden)" |
| health | 1366 | div.hv-s "06:38 MARKET MARKET NEWS ▼ MAR" |
| health | 1366 | div.hv-rail "" |
| health | 1366 | div.hv-rail "" |
| health | 1366 | span.hv-chip "LOG 1" |
| health | 1366 | span.hv-chip "RINGS –/6" |
| calendar | 1366 | div.dg "DROVE TODAY pinned · % all lis" |
| calendar | 1366 | a.lk2 "F10 ›" -> futures-oi#buildup |
| calendar | 1366 | div.er "09:45 Realty +1.94% Realty +1." |

## Cut cells left (after)

| page | where | widths | n | example |
|---|---|---|---|---|
| desk-hunt | `div.mvr > span.sc` | 1600 | 44 | consumer durables (115 of 66 px) |
| futures-oi | `div.grp > span.gb` | 1366,1600,390 | 43 | BASIS 15 listed shares, market-cap weigh (594 of 508 px) |
| desk-hunt | `span.sd > span.ellip` | 1366,1600,390 | 25 | US 10-yr yield (84 of 59 px) |
| world | `div.mx > span.sn` | 1366,1600,390 | 18 | Electronics & hardware (158 of 82 px) |
| world | `span.sn > a.sl` | 1366,1600,390 | 18 | Electronics & hardware (178 of 102 px) |
| chain | `span.gb > span.nar` | 1366,1600 | 16 | NARROW (287 of 263 px) |
| morning | `div.mr > span.sc2` | 1600,390 | 16 | consumer durables (115 of 58 px) |
| sectors | `div.srow > span.stc` | 390 | 13 | CONF 09:20 (97 of 88 px) |
| futures-oi | `div.brow > a.sym` | 390 | 12 | BANKBARODA (111 of 106 px) |
| world | `#mxh > span` | 1366,1600,390 | 12 | Brent −1.8 (31 of 27 px) |
| chain | `td.oi > span.oc.n` | 390 | 11 | 0 (301 of 297 px) |
| world | `div.ti > span.dv` | 1366,1600,390 | 11 | HOSPITALS & DI (112 of 58 px) |
| sectors | `div.srow > span.rk` | 390 | 10 | 10 ▸ (25 of 18 px) |
| desk-hunt | `div.srow > span.br.ellip` | 390 | 9 | 27/34F&O 20/22 (102 of 89 px) |
| desk-hunt | `span.br > i` | 390 | 9 | F&O 20/22 (289 of 276 px) |
| chain | `tr.itmc > td.oi.c` | 390 | 8 | 72k– (77 of 67 px) |
| chain | `tr.itmc > td.oi.p` | 390 | 8 | 68k– (77 of 67 px) |
| futures-oi | `span.gr > span.t3` | 1366,390 | 8 | CE #8 (565 of 543 px) |
| calendar | `div.bd > div.l2` | 390 | 7 | NSE holiday list (1403 of 382 px) |
| morning | `div.bl > a.s` | 1366,1600,390 | 7 | MANAPPURAM (115 of 110 px) |
| rotation | `td.nmc > div.n1` | 390 | 7 | ▸ Telecom services (135 of 102 px) |
| sectors | `div.mv > span.msc` | 1600 | 7 | Hospitals & diagnostics (140 of 74 px) |
| world | `span.p > span.t2` | 390 | 7 | no drv (149 of 106 px) |
| chain | `span.ed > b.n` | 1366,390 | 6 | 4.76L (470 of 442 px) |
| chain | `tr.itmp > td.oi.c` | 390 | 6 | 1.04L0 (77 of 67 px) |
| desk-hunt | `tr > th` | 390 | 6 | CE STRIKE (76 of 56 px) |
| sectors | `span.ht > em` | 1366,1600,390 | 6 | Hospitals & diagnostics (129 of 62 px) |
| sectors | `span.stc > span.nar` | 1600 | 6 | NARROW (1198 of 1175 px) |
| calendar | `div.dr2 > span.tx` | 390 | 5 | next index expiry: NIFTY 23 Nov · BANKNI (1016 of 382 px) |
| scorecard | `tr > th` | 1366,1600,390 | 5 | BEGAN (51 of 47 px) |
| sectors | `span.nar > span.w1600` | 1600 | 5 | · DATAPATTNS (1192 of 1175 px) |
| world | `div.grp > span.bt` | 1366 | 5 | CONFIRMED 12:00 (988 of 963 px) |
| world | `div.ln > span.k` | 1366,1600,390 | 5 | LATEST (48 of 42 px) |
| world | `div.ti > span.sc2` | 390 | 5 | Realty +1.94 (82 of 50 px) |
| calendar | `div.l1 > span.nm` | 390 | 4 | ENRIN board meeting - Board Meeting Inti (431 of 382 px) |
| chain | `div.gh > span.gn` | 1366,1600 | 4 | HOSPITALS & DIAGNOSTICS (181 of 167 px) |
| desk-hunt | `a.tl > span.sx` | 1366,1600,390 | 4 | metals & mining (103 of 85 px) |
| futures-oi | `div.grp > span.nar` | 390 | 4 | NARROW · F&O-only (432 of 371 px) |
| morning | `div.cd1 > b.dv` | 1366,1600 | 4 | US 10-yr yield (111 of 110 px) |
| positions | `div.rkh > span` | 1366,1600,390 | 4 | BOTH POSITIONS AT… (144 of 128 px) |
| rotation | `div.fs > span.t3` | 1366,1600 | 4 | CONFIRMED (800 of 794 px) |
| calendar | `div.lane > span.ph2.ex` | 1366,1600,390 | 3 | EXIT (34 of 16 px) |
| calendar | `div.ln > span` | 390 | 3 | you (500 of 382 px) |
| calendar | `div.ln > span.bl` | 1366,1600,390 | 3 | IV CRUSH (72 of 64 px) |
| calendar | `span > b.yo` | 390 | 3 | can close, cannot add (500 of 382 px) |
| calendar | `span.tm > span.tz` | 1366,1600,390 | 3 | Mon 23 Nov (64 of 54 px) |
| calendar | `span.u > a.lk` | 390 | 3 | APOLLOHOSP (462 of 382 px) |
| chain | `tr.itmc > td.k.lk` | 1366,1600,390 | 3 | 1,160ROOF (81 of 71 px) |
| chain | `tr.itmp > td.oi.p` | 390 | 3 | 38k+1k (77 of 67 px) |
| desk-hunt | `div.mhd > span.r` | 1366,1600,390 | 3 | USED·ROOM (79 of 70 px) |
| desk-hunt | `tr > td` | 390 | 3 | ltp 13.45 (63 of 56 px) |
| desk-hunt | `tr > td.k` | 390 | 3 | 810ITM (62 of 56 px) |
| futures-oi | `#bmap > span.lu` | 1366,1600,390 | 3 | LU 3 (20 of 10 px) |
| futures-oi | `#bmap > span.sc` | 1366,1600,390 | 3 | SC 4 (22 of 13 px) |
| futures-oi | `div.fr > span.fn` | 1366,1600,390 | 3 | Telecom services (115 of 100 px) |
| futures-oi | `span.gr > span.gm.n` | 390 | 3 | (own-trade text hidden) (423 of 371 px) |
| futures-oi | `span.gr > span.t2` | 1366,390 | 3 | LB 5/6 (554 of 543 px) |
| health | `div.hv-lr > span.hv-mono` | 1366,1600,390 | 3 | 0 client(s), seq 2457 (70 of 50 px) |
| morning | `div.shr > a.s` | 1600 | 3 | OBEROIRLTY (97 of 94 px) |
| news | `div.lr > span` | 1366,390 | 3 | economictimes.indiatimes.com · APLAPOLLO (227 of 191 px) |
| news | `div.lr > span.n.r` | 1366,1600,390 | 3 | +50137 s (61 of 50 px) |
| plan-card | `#cPrem > span.k` | 1366,1600,390 | 3 | PREMIUM (63 of 56 px) |
| plan-card | `div.r > span.k` | 1366,1600,390 | 3 | BACKSTOP (71 of 64 px) |
| positions | `div.rk > span.rkn` | 1366,1600 | 3 | Kite backstops (trigger) (140 of 128 px) |
| reference | `#uvh > span` | 1366,390 | 3 | (own-trade text hidden) (67 of 60 px) |
| reference | `div.ph > span.age` | 1366,1600 | 3 | quotes_live.json (673 of 579 px) |
| rotation | `#anl > span.t3.ellip` | 1366,1600,390 | 3 | · 16:44 checked the news, the policy map (551 of 348 px) |
| rotation | `td.nmc > div.n2` | 390 | 3 | OUT sec.rot only (107 of 102 px) |
| rotation | `tr.sr > td` | 1366 | 3 | bid/ask (40 of 36 px) |
| settings | `div.lrw > span.lkl` | 1366,1600,390 | 3 | (own-trade text hidden) (109 of 70 px) |
| world | `div.dgrid > span.nm` | 1366 | 3 | Hang Seng (73 of 66 px) |
| world | `div.r1 > span.ltp` | 1366 | 3 | 25,475.00 (67 of 60 px) |
| world | `div.ti > span.rk` | 1366,1600,390 | 3 | 12 (13 of 10 px) |
| calendar | `#drb > div.dg.sec` | 390 | 2 | results (1024 of 382 px) |
| calendar | `#pg > nav#cyc.cyc` | 1366,1600 | 2 | TRADE CYCLE PREPARE ⇧F1 ⇧F2 ⇧F4 › FIND F (1413 of 1340 px) |
| calendar | `div.er > div.sl.sh-heat-up` | 1366,1600 | 2 | Oil marketers, paints, airlines +1.75% d (606 of 484 px) |
| calendar | `div.lane > span.ph2.man` | 1366,390 | 2 | MANAGE (51 of 49 px) |
| calendar | `div.lane > span.ph2.obs` | 1366,390 | 2 | OBS (25 of 24 px) |
| chain | `td.k > span.kt.roof` | 1366,390 | 2 | ROOF (665 of 660 px) |
| desk-trade | `#chP > header.ph.sh-acc-mine` | 1366,1600 | 2 | HDFCBANK 820 PE MOTILALOFS 1,160 PE UNIO (638 of 495 px) |
| desk-trade | `#mkHead > span` | 1366,390 | 2 | BUILD-UP (64 of 56 px) |
| desk-trade | `#mkHead > span.r_` | 1366,390 | 2 | BREADTH ALL (91 of 80 px) |
| futures-oi | `#bub > div.grp` | 1366,390 | 2 | (own-trade text hidden) (597 of 530 px) |
| health | `div.hv-r > span.fx` | 1366 | 2 | gir-v2opt (Kite key 3 REST quote, Black- (296 of 287 px) |
| health | `div.hv-tile > div.tl` | 1366 | 2 | KITE KEYS CHECK (126 of 123 px) |
| health | `div.hv-tile > div.tv` | 1366,1600 | 2 | 55/76 kq_mcx_cds MISSING (164 of 123 px) |
| health | `span.hv-ud > button` | 1366 | 2 | ▼ (686 of 680 px) |
| help | `span.l1 > kbd.k` | 390 | 2 | F4 (256 of 252 px) |
| help | `span.l1 > kbd.ks` | 390 | 2 | ⇧F2 (150 of 128 px) |
| market | `#grMine > span.sh-c.sh-c-pe` | 1366,1600 | 2 | (own-trade text hidden) (1426 of 1354 px) |
| morning | `div.mh > span` | 1600,390 | 2 | BUILD-UP · OI (90 of 88 px) |
| morning | `span.tbs > button.tb` | 1366,390 | 2 | VIEW (1356 of 1354 px) |
| news | `span > b` | 1366,390 | 2 | economictimes.indiatimes.com (1168 of 1132 px) |
| plan-card | `#cBec > span.k` | 1366,390 | 2 | BECAUSE (60 of 56 px) |
| plan-card | `tr > td` | 1366,390 | 2 | NO-CHASE (69 of 66 px) |
| positions | `div.nn > span.sh-lb` | 1366,390 | 2 | BLOCKS (53 of 52 px) |
| positions | `div.rkh > span.r_` | 1366,390 | 2 | (own-trade text hidden) (56 of 54 px) |
| reference | `b > span.n` | 1366 | 2 | 3 F&O (277 of 253 px) |
| replay | `div.ybtn > a` | 1366,1600 | 2 | ⇧F6 Journal › (1416 of 1353 px) |
| rotation | `span.pa > span.mr` | 1366,1600 | 2 | all shown (419 of 384 px) |
| scorecard | `div.tile > div.l` | 1366 | 2 | IN THE NOTES (93 of 92 px) |
| scorecard | `div.tile > div.s` | 1366,1600 | 2 | named before – (94 of 92 px) |
| sectors | `#board > div#tbar` | 1366,1600 | 2 | ALL SECTORS 26 ▾ HOSPITALS & DIAGNOSTICS (692 of 662 px) |
| sectors | `#tbar > span.t3.tbn` | 1366,1600 | 2 | = F&O-only move (1030 of 1006 px) |
| sectors | `div.cst > a.xp` | 1366,390 | 2 | chain F9 › (1398 of 1353 px) |
| sectors | `span.snm > b` | 390 | 2 | Hospitals & diagnostics (186 of 159 px) |
| settings | `div.lrw > span.am.dn` | 1366,390 | 2 | (own-trade text hidden) (63 of 62 px) |
| settings | `nav.cyc > a` | 1366,1600 | 2 | REVIEW (1386 of 1354 px) |
| world | `#tmap > div.tbar` | 1366,1600 | 2 | ALL 26 ▾ GO NOW 0 READY 0 BLOCKED 0 mine (622 of 594 px) |
| world | `div.shd > span` | 1366 | 2 | stop sh/prem (86 of 84 px) |
| world | `div.tbar > span.chip.buc` | 1366,1600 | 2 | LU (995 of 973 px) |
| world | `span.an > span.wide` | 1600 | 2 | Hang Seng (1233 of 1220 px) |
| world | `span.br > span.c.nar` | 1366,1600 | 2 | NARROW (785 of 779 px) |
| world | `span.nm > i` | 1600,390 | 2 | CDS · data (161 of 113 px) |
| world | `span.sc2 > span.n.up` | 390 | 2 | +1.94 (193 of 161 px) |
| world | `span.sh-heat-dn > span.an` | 1600 | 2 | Hang Seng (67 of 54 px) |
| analyst | `span.sl > a.t2` | 1366 | 1 | World ⇧F2 › (365 of 329 px) |
| calendar | `#cyc > a` | 1600 | 1 | ⇧F8 (1606 of 1588 px) |
| calendar | `#cyc > span.st` | 1366 | 1 | REVIEW (1386 of 1354 px) |
| calendar | `#evb > div.dg.drv` | 390 | 1 | Drove today (1411 of 382 px) |
| calendar | `#evb > div.dg.today` | 390 | 1 | Sat 21 Nov (1411 of 382 px) |
| calendar | `#plb > div.wlr` | 390 | 1 | Parliament, regulators, open papers, cou (1746 of 382 px) |
| calendar | `#plb > div.wlr.stg-l` | 390 | 1 | → → (1746 of 382 px) |
| calendar | `#pol > div.scw` | 390 | 1 | ALL staged pipeline not known – MARKET P (1747 of 372 px) |
| calendar | `div.bd > div.r2` | 390 | 1 | today (1016 of 382 px) |
| calendar | `div.lane > span.ph2.late` | 390 | 1 | LATE (26 of 23 px) |
| calendar | `div.lane > span.ph2.ovn` | 390 | 1 | overnight (48 of 36 px) |
| calendar | `div.lane > span.ph2.pre` | 390 | 1 | PRE (17 of 11 px) |
| calendar | `div.ln > a.lk` | 390 | 1 | LICI (395 of 382 px) |
| calendar | `div.r1 > span.q` | 390 | 1 | Is Vishal Mega Mart (NSEI:VMM) Overvalue (575 of 382 px) |
| calendar | `span.br > b` | 390 | 1 | 14/15 (389 of 382 px) |
| calendar | `span.nm > span.pc.up` | 1366 | 1 | +1.75% (510 of 503 px) |
| calendar | `span.pin > span.imp.up` | 390 | 1 | ▲ +3.68% (397 of 367 px) |
| calendar | `span.sg > span.br` | 390 | 1 | all · F&O (469 of 382 px) |
| calendar | `span.u > a.sh-c.sh-c-lb` | 390 | 1 | LB (393 of 382 px) |
| calendar | `span.u > span.pc.up` | 390 | 1 | +2.12% (394 of 382 px) |
| chain | `#lst > div.ph` | 1366 | 1 | CHAINS ALL ▾ HOSPITALS & DIAGNOSTICS ▾ B (258 of 250 px) |
| chain | `#sceM > span.nk` | 390 | 1 | not known (377 of 375 px) |
| chain | `#unuM > span.nk` | 1600 | 1 | not known (931 of 922 px) |
| chain | `div.rd > a.hlink` | 390 | 1 | chain › (407 of 371 px) |
| chain | `div.rd > b.n.dn` | 390 | 1 | (own-trade text hidden) (389 of 371 px) |
| chain | `span.pa > span.sbtn` | 1366 | 1 | ▼ (265 of 263 px) |
| chain | `tr > th.c.r` | 1600 | 1 | SPREAD / LOT (99 of 98 px) |
| chain | `tr.sel > td.oi.c` | 390 | 1 | 1.59L0 (77 of 67 px) |
| chain | `tr.sel > td.oi.p` | 390 | 1 | 58k0 (77 of 67 px) |
| desk-hunt | `#action > div#actChips.chips` | 390 | 1 | ALL 0 CRIT 0 GO 0 READY 0 MY 0 WATCH 0 T (439 of 372 px) |
| desk-hunt | `div.mrw > div.two` | 1600 | 1 | APOLLOHOSP lot 125 (114 of 112 px) |
| desk-hunt | `div.shd > span` | 1366 | 1 | SECTOR · BASIS (102 of 99 px) |
| desk-hunt | `span.chip > span.n` | 390 | 1 | 0 (387 of 382 px) |
| desk-hunt | `span.sb > button` | 1600 | 1 | ▼ (401 of 396 px) |
| desk-trade | `#acP > header.ph.sh-acc-call` | 1600 | 1 | ACTION ALL 0 MINE 0 BLOCKED 0 IDEAS 0 WA (490 of 386 px) |
| desk-trade | `#alP > footer.lf` | 1366 | 1 | 1-1 of 1 P1 · P2 unacked – · A + Enter a (349 of 330 px) |
| desk-trade | `button.chip > span.w` | 1600 | 1 | WATCH (1598 of 1588 px) |
| desk-trade | `span.tf > button` | 1366 | 1 | 1m (511 of 509 px) |
| desk-trade | `span.tf > button.on` | 1600 | 1 | VWAP (616 of 598 px) |
| desk-trade | `span.ud > button` | 1366 | 1 | ▼ (1372 of 1354 px) |
| futures-oi | `#mTabs > span#tCrit.tcrit.t3` | 1366 | 1 | needs money.big (103 of 99 px) |
| futures-oi | `#mvBar > span.fl` | 1600 | 1 | MOVERS (57 of 52 px) |
| futures-oi | `div.fr > span.fv2.up` | 390 | 1 | (own-trade text hidden) (55 of 54 px) |
| futures-oi | `div.ftr > span.mo` | 1366 | 1 | Nov ★ 23 (63 of 54 px) |
| futures-oi | `div.ph > span#fbmLot.t3.phs` | 1366 | 1 | lot 650 (42 of 29 px) |
| futures-oi | `span.sc > b.n` | 1600 | 1 | 4 (547 of 541 px) |
| health | `#hv > section#hvTL.hv-tl` | 1366 | 1 | TEST LOG 2026-11-20-from-1119-v2.stopped (1544 of 1340 px) |
| health | `div.hv-vt > div#hvV2.hv-v2` | 1366 | 1 | 55 of 76 feeds LIVE · down kq_mcx_cds, o (813 of 762 px) |
| health | `div.tv > span.nk` | 1366 | 1 | –/6 (1355 of 1353 px) |
| help | `#tabs > button.tab` | 390 | 1 | Old → now (385 of 381 px) |
| help | `#wl > button.wi.f` | 1600 | 1 | more (1356 of 1278 px) |
| help | `a.st > span.l1` | 390 | 1 | 7MANAGE F1 F6 (112 of 105 px) |
| help | `button.wi > b` | 1600 | 1 | OLD → NOW (1347 of 1278 px) |
| help | `div.roww > nav#wl.wl` | 1600 | 1 | F&O MOVERS up / down / all → F2 Sectors  (1249 of 1171 px) |
| help | `span.hint > a.lk` | 1366 | 1 | no orders › (257 of 239 px) |
| market | `#chart > header.ph.tb` | 390 | 1 | NIFTY 50 ▾ 1m 3m 5m 15m 1h D VWAP OR EMA (375 of 372 px) |
| market | `#ovs > button` | 390 | 1 | vs BANKNIFTY (384 of 382 px) |
| market | `span.why > a` | 1366 | 1 | hospitals & diagnostics (752 of 689 px) |
| market | `span.why > span.up` | 1600 | 1 | +3.68% (912 of 901 px) |
| morning | `#blw > span.stl` | 1600 | 1 | gold (1152 of 1148 px) |
| morning | `#p-drv > div#blw.blw` | 1600 | 1 | OTHER DRIVERS · 6 copper LATE aluminium  (920 of 794 px) |
| morning | `button.tb > span.sh-age` | 390 | 1 | 2/6 (384 of 382 px) |
| morning | `div.mr > a.s` | 390 | 1 | APOLLOHOSP (106 of 100 px) |
| morning | `span.cu > span.cn` | 1600 | 1 | NASDAQ FUT (85 of 83 px) |
| morning | `span.h-lb > span.sh-lb` | 390 | 1 | Today's plan (681 of 390 px) |
| morning | `span.stl > span.sh-c.sh-c-stale` | 1600 | 1 | LATE (1152 of 1148 px) |
| news | `div.lh > span.c` | 1366 | 1 | AI · WT (49 of 46 px) |
| plan-card | `#tk3 > div.ex` | 1366 | 1 | exit = one order: MODIFY SL-L → LIMIT bi (329 of 310 px) |
| plan-card | `div.ex > b` | 1366 | 1 | MODIFY SL-L → LIMIT bid − 1 tick (1364 of 1345 px) |
| positions | `#chP > header.ph.sh-acc-mine` | 1366 | 1 | (own-trade text hidden) (498 of 493 px) |
| positions | `span.age > span.n` | 1366 | 1 | 28h (511 of 507 px) |
| reference | `#cyc > span.st` | 1366 | 1 | REVIEW (1390 of 1354 px) |
| reference | `#pg > nav#cyc.cyc` | 1366 | 1 | TRADE CYCLE PREPARE ⇧F1 ⇧F2 ⇧F4 › FIND F (1416 of 1340 px) |
| reference | `#uvage > span` | 1600 | 1 | 15:30:53 (710 of 667 px) |
| reference | `div.cb > span.bkcap.wide` | 1600 | 1 | moving drivers first (1147 of 1127 px) |
| replay | `div > span.ybig` | 1366 | 1 | not known (84 of 82 px) |
| replay | `div.lrow > span.lab` | 390 | 1 | BANKNIFTY – (157 of 132 px) |
| replay | `tr > th` | 390 | 1 | GIR TODAY (79 of 75 px) |
| rotation | `div.fs > span.nm.up` | 1366 | 1 | +1.75% (810 of 794 px) |
| rotation | `tr > th` | 1366 | 1 | strike (39 of 36 px) |
| scorecard | `#ak > span.nk` | 1366 | 1 | verdict – (1308 of 1295 px) |
| scorecard | `div.sub > span.age.w1600` | 1600 | 1 | as of 15:30 (729 of 711 px) |
| scorecard | `div.tile > div.v` | 1366 | 1 | $3.06 of $20 (94 of 93 px) |
| scorecard | `span.ud > button` | 1600 | 1 | ▲ (1600 of 1587 px) |
| scorecard | `span.w1600 > a.sym` | 1600 | 1 | MOTILALOFS (618 of 616 px) |
| sectors | `#rot > a.mini` | 1600 | 1 | F3 › (1190 of 1175 px) |
| sectors | `div.h2 > b.n` | 1366 | 1 | 3/3 (532 of 518 px) |
| sectors | `span > b` | 1366 | 1 | HOSPITALS & DIAGNOSTICS (1053 of 1006 px) |
| sectors | `span.ht > b.n` | 1366 | 1 | (own-trade text hidden) (64 of 62 px) |
| settings | `a > kbd` | 1600 | 1 | ⇧F6 (1616 of 1588 px) |
| settings | `a.tile > span.l` | 390 | 1 | ROOM AT STOPS (110 of 103 px) |
| settings | `a.tile > span.v` | 390 | 1 | OFF this browser (111 of 103 px) |
| settings | `div.chips > button` | 1366 | 1 | VOTE (1363 of 1353 px) |
| settings | `span.ud > button` | 1366 | 1 | ▼ (1015 of 1007 px) |
| share | `#call > footer#callF.pf` | 390 | 1 | Plan card Space Chain F9 Ring R Ask Q or (451 of 372 px) |
| world | `div.h1 > span.pl.dn` | 390 | 1 | (own-trade text hidden) (389 of 375 px) |
| world | `div.ti > span.dv.t3` | 1366 | 1 | +3 more (59 of 58 px) |
| world | `span.rt > a.lk` | 390 | 1 | F6 › (390 of 375 px) |
| world | `span.sc2 > span.t3` | 390 | 1 | context only (195 of 161 px) |

## Check on the real server

One gentle pass on the real gir-preview (127.0.0.1:8100, 1366x768, all 23 pages, 20:0x IST): 0 console errors, 0 failed requests on every page.

## What is left, and why

- **Replay playback page (/preview/replay/, served by gir-v2replay) - 36 of the R51 FAIL rows.** Not a page file: (1) `v2/replay/inject.html` puts its "No replay running - press Start" box (#grp-idle.inline, 476 px high, z-index 50) at the top of the body, but the replay page has a fixed layout, so the box lies OVER the page's own top rows (trade cycle links, WATCH / PRACTICE, days, PLAY, speed, YOUR DAY list) instead of pushing them down. Proposed fix for the replay owner: in inline mode make the box `position:fixed; top:var(--sh-top)` with a smaller padding, and set `#page.style.top` to sh-top + the box height while it shows (back to '' when a run starts). (2) START / day / speed buttons: the replay server answers 423 "ON HOLD: the replay is held until the trader calls it" (by design while the hold is on); the browser logs every 4xx as a console error - to be silent the server would answer 200 {ok:false}. In this test the stub never forwarded a playback command after 19:33; one START click at 19:29 reached the real replay server and was refused 423 ("nothing was started"; state IDLE checked). (3) `/preview/replay/api/predict` is 404 on the replay server (the PREDICTED chip asks for it on the replay copy of F1).
  The live-store Replay page (/preview/replay.html) has 0 console errors / 0 failed requests at all widths.
- **Calendar at 390 (2 rows):** the timeline pins overlap each other at phone width (a neighbour pin's link lies on top); at 1366 / 1600 fixed (pins pass the pointer through except their links).
- **Phone page opened on a desktop (1366), 1 row:** the NOW list has no visible bar for a mouse (native bar hidden by phone.css); on the phone itself the finger swipe passes.
- **Cut cells left (695, was 1179 with the same strict check):** mostly short sector / driver names in fixed narrow columns (F1 movers sector column at 1600, sector-row driver names, World theme names, Morning / Sectors mover sectors, F10 group BASIS lines at 1366, chain OI cells at 390). Each needs a layout choice (a wider column takes width from another, or the name wraps to 2 lines and the row grows) - named in the table above, not changed blind before the freeze.
- **R51 at 1600:** the generic sweep at 1600 was still running when this report was written (1366 + 390 complete); the drill-down R51 at 1600 passed on 20 Nov.
- NOCHANGE rows were reviewed: already-selected tabs, ▲ at the top of a list, chain strike rows (data rows with a data-k attribute, no click action by design), chips that filter to the same empty list on a closed-market Saturday.

## Engine GO cards (coordinator 21 Nov, desk 19:30 / 19:40)

One switch, `v2/pages/static/store.js` line 45: `const ENGINE_GO = 'hide';` ('hide' Monday default / 'label' / 'show' = old). In 'hide' the engine's GO NOW / BUY cards are removed from calls.feed, calls.* and an.latest before any page sees them; its other rule lines (GET READY, sector-board share calls) show "ENGINE (rules)" in muted grey, tooltip "ENGINE (rules) - not the desk's call", never amber, never GO / BUY wording. Only the desk's agreed calls (desk.* BUY NOW) say BUY NOW. No page sound or ring code exists. Check (fixture engine GO NOW + GET READY rows on the test stub, every page at 1366 and 390): 46 / 46 PASS - the GO NOW row appears nowhere, the GET READY row is grey "ENGINE (rules)", no GO / BUY / amber on any engine row, 0 page errors.

## Also done (coordinator 19:45)

- Settings top bar and the shell footer: "Old page (week 1): girtrader.com/old" (normal link to /old). No /preview page links to "/" expecting the old page.
- SECTOR MONEY (girtrader.com/old): NSDL's one number per fund group shown once, on the group's first row; the other rows show one muted cell "same fund group (Financial Services)" with the tooltip "NSDL reports one number for the whole fund group ...". Checked signed in at 1366 / 390: 0 cut cells, 0 page errors.

Screenshots: D4_shots/ (every page at 1366 and 390; the P&L strip, every rupee amount, the trader's own trades / positions / journal panels and any model name masked dark grey by Playwright, labelled "P&L hidden").

