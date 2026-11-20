# D desk web 1_shell - Monday item 1 - shell values: P&L strip "AI $ of $5", footer AI word = desk mode

Run 20 Nov 2026 20:02 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v1. Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v1 shape, every text
"FIXTURE"; the live state.json never touched; the STALE row flips that fixture's view.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
static/shell.js: the P&L strip AI cap and spend come from desk.meter (cap 5.0, total) once gir-v2desk writes it (until then the old ai.spend $20 line); the footer AI word becomes "desk LEAN" / "desk EVENTS ONLY" / "desk OFF · $5 reached - rules only" from desk.status + desk.meter.step, and "desk OFF · head analyst not running (<status>)" while the head is not running; no model names. Note: the contract has no FULL / LEAN flag; LEAN is shown while the meter step is NORMAL (Monday is LEAN per DESK_TEAM). Done in shell.js (the live shell), not shellwork/build.js (the drawing builder).

## R51-style rows
**6 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| shell: P&L strip "AI $ of $5", footer AI word = desk mode | F1 desk (fixture) | 1366x768 | inside | PASS | footer "alth LIMITED · atr LATE 116h · desk LEAN" · strip AI "AI $1.84 of $5" |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | inside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| shell: P&L strip "AI $ of $5", footer AI word = desk mode | F1 desk (fixture) | 1600x900 | inside | PASS | footer "alth LIMITED · atr LATE 116h · desk LEAN" · strip AI "AI $1.84 of $5" |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | inside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | outside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | outside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
