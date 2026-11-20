# D desk web 5_morning - Monday item 5 - Morning: the head's brief in the approved boxes

Run 21 Nov 2026 01:36 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v2 (meter.cap 8, meter.lean, brief.stale / stale_why / failed_slot). Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v2 shape, every text
"FIXTURE", cap 8, lean on; the live state.json never touched; the STALE rows flip that fixture's view.stale / brief.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
static/morning.js + morning.html (desk-fill.js include; backups .bak2048), words from desk-fill.js (heroHtml / planRows / themeCards / preflightRow / staleLine). TODAY'S PLAN band: the head's brief headline (desk.brief) in the band text; the age line "analyst <slot> · made hh:mm" + a "▸ changed" mark whose tooltip lists what changed since the last slot. 19:45 table: a "GIR ANALYST · BRIEF <slot>" group on top with the head's ideas (max 5, CE and PE both, the same 7 cells as the engine rows; CANCELLED rows struck with the reason); a row click opens WHY / AGAINST (Devil) / CANCEL IF under the row, a second click closes it; the engine rows stay under it. DRIVERS band: the head's themes as its cards (THEME chip, NOT PROVEN, winners CE / losers PE, existing card style) + the macro card. PRE-FLIGHT: one more check row "Desk n of N seats running · FULL / LEAN / EVENTS ONLY · $x of $<cap>" (or "Desk not running · N seats"). brief.stale (DESK_api v2): the band age line and the table group read "STALE · <stale_why>" in grey - the last good brief stays, never blank; the phone ALERTS brief note carries the same label (row in D_desk_web_4_phone_tg). Head not running: the old band and table exactly as before. No new box, colour or sound.

## R51-style rows
**26 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1366x768 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 22:06 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1366x768 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1366x768 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1366x768 | inside | PASS | THEME NOT PROVEN FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY LEADER |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1366x768 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1366x768 | inside | PASS | analyst 07:15 · made 22:07 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1366x768 | inside | PASS | 0 / ○ Desk not running · 46 seats · $1.35 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1366x768 | inside | PASS | none |
| TODAY'S PLAN band: the head's headline + analyst slot / made + changed since | Morning (fixture) | 1600x900 | inside | PASS | leans UP · FIXTURE: banks lead on foreign buying, IT under pressure fr / analyst 07:15 · made 22:08 · ▸ changed / FIXTURE: banks lead on foreign buying, IT under pressure from the US s |
| 19:45 table: the head's ideas first, CE and PE both, CANCELLED struck | Morning (fixture) | 1600x900 | inside | PASS | 4 rows · "GIR ANALYST · BRIEF 07:15 2 CE · 2 PE NOT PROVEN" · 1 struck |
| row click: WHY / AGAINST (Devil) / CANCEL IF under the row, click again closes | Morning (fixture) | 1600x900 | inside | PASS | WHY FIXTURE: FII net buyers in banks five sessions running (NSDL, tape) AGAINST (Devil) FIXTURE: RSI near 75 - late entr |
| DRIVERS band: desk themes as its cards (THEME chip, NOT PROVEN, winners CE and losers PE) | Morning (fixture) | 1600x900 | inside | PASS | THEME NOT PROVEN 23:08 · CONFIRMING FIXTURE: AI IPO -> FII rotation -> banks CE SBIN LEADER CE HDFCBANK FOLLOWER PE INFY |
| PRE-FLIGHT: "Desk n of N seats running · mode · $ of cap" | Morning (fixture) | 1600x900 | inside | PASS | ✓ Desk 7 of 9 seats running · LEAN · $1.84 of $8 |
| no cut text (Morning, fixture) | Morning (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| brief.stale: "STALE · <why>" on the band and the table, never blank | Morning (fixture) | 1600x900 | inside | PASS | analyst 07:15 · made 22:09 · STALE · FIXTURE: the 09:08 brief failed (head timeo / STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief i |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1600x900 | inside | PASS | 0 / ○ Desk not running · 46 seats · $1.35 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1600x900 | inside | PASS | none |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1366x768 | outside | PASS | 0 / ○ Desk not running · 46 seats · $1.35 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1366x768 | outside | PASS | none |
| head not running: the old band and table, PRE-FLIGHT says the desk is not running | Morning (live) | 1600x900 | outside | PASS | 0 / ○ Desk not running · 46 seats · $1.35 of $1.5 / 19:45 watch 2026-11-20 20:49 IST · for 23 Nov · SHADOW - wri |
| no cut text (Morning, live) | Morning (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | Morning (live) | 1600x900 | outside | PASS | none |
