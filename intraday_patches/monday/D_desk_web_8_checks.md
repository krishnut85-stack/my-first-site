# D desk web 8_checks - Monday item 8 - checks

Run 20 Nov 2026 20:02 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v1. Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v1 shape, every text
"FIXTURE"; the live state.json never touched; the STALE row flips that fixture's view.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
0 console errors and no sideways scroll on every page at 1366 / 1600 / 390, inside and outside; one amber fill per screen (the GO NOW card); no cut text on every changed box; masked P&L in the shots; every changed box tested by real clicks / touches (this table). NOT done here: shot.js (the drawing checker, dark and light) and "a 20 Nov replay shown through the pages" - that needs the desk's replay output, not available tonight.

## R51-style rows
**18 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| 0 console errors on every page (23 pages) | all pages | 1366x768 | inside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | inside | PASS | pages: 23 |
| 0 console errors on every page (23 pages) | all pages | 1600x900 | inside | PASS | none |
| no sideways scroll at 1600 on every page | all pages | 1600x900 | inside | PASS | none |
| no Desk Room page or link left | all pages | 1600x900 | inside | PASS | pages: 23 |
| 0 console errors on every page (23 pages) | all pages | 390x844 | inside | PASS | none |
| no sideways scroll at 390 on every page | all pages | 390x844 | inside | PASS | none |
| no Desk Room page or link left | all pages | 390x844 | inside | PASS | pages: 23 |
| 0 console errors on every page (23 pages) | all pages | 1366x768 | outside | PASS | none |
| no sideways scroll at 1366 on every page | all pages | 1366x768 | outside | PASS | none |
| no Desk Room page or link left | all pages | 1366x768 | outside | PASS | pages: 23 |
| 0 console errors on every page (23 pages) | all pages | 1600x900 | outside | PASS | none |
| no sideways scroll at 1600 on every page | all pages | 1600x900 | outside | PASS | none |
| no Desk Room page or link left | all pages | 1600x900 | outside | PASS | pages: 23 |
| 0 console errors on every page (23 pages) | all pages | 390x844 | outside | PASS | none |
| no sideways scroll at 390 on every page | all pages | 390x844 | outside | PASS | none |
| no Desk Room page or link left | all pages | 390x844 | outside | PASS | pages: 23 |
