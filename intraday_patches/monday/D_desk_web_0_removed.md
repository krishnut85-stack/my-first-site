# D desk web 0_removed - Desk Room unlinked (trader 20:15 decision)

Run 20 Nov 2026 20:02 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v1. Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v1 shape, every text
"FIXTURE"; the live state.json never touched; the STALE row flips that fixture's view.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
Removed from every page and the nav, kept as files: desk-room.html, static/desk-head.js, static/desk-head.css -> v2/pages_unlinked_1120/ (not served). desk-hunt.html, morning.html, phone.html back to their .bak1901 copies (the desk-head includes gone; the edited copies kept as .bak1935). shell.js F8 tab / key back to "Analyst" / analyst. The Morning brief board, the F1 DESK VIEW strip / BUY NOW re-stack, the phone brief card and TAKEN / SKIP buttons went with it (they changed approved boxes). The earlier Desk Room shots moved to monday/superseded_desk_room_1120/. v2/desk_tg/tg_format.py kept and re-worded (format only).

## R51-style rows
**6 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| no Desk Room page or link left | all pages | 1366x768 | inside | PASS | pages: 23 |
| no Desk Room page or link left | all pages | 1600x900 | inside | PASS | pages: 23 |
| no Desk Room page or link left | all pages | 390x844 | inside | PASS | pages: 23 |
| no Desk Room page or link left | all pages | 1366x768 | outside | PASS | pages: 23 |
| no Desk Room page or link left | all pages | 1600x900 | outside | PASS | pages: 23 |
| no Desk Room page or link left | all pages | 390x844 | outside | PASS | pages: 23 |
