# D desk web 4_phone_tg - Monday item 4 - phone + Telegram

Run 20 Nov 2026 21:25 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v2 (meter.cap 8, meter.lean, brief.stale / stale_why / failed_slot). Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v2 shape, every text
"FIXTURE", cap 8, lean on; the live state.json never touched; the STALE rows flip that fixture's view.stale / brief.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
phone.js: CALL = the head's card with FROM / AGAINST / NOT PROVEN in place of the weight, WHY 2 lines + "more", one blue CONNECTION line; NOW (flat) desk line "Desk: lean X · n ideas armed · next look · brief ›"; ALERTS: the brief as the existing note (changed first, CE / PE names, Themes max 3). Tab bar unchanged, no DESK tab, no TAKEN / SKIP. Telegram (v2/desk_tg/tg_format.py, format only - WOULD SEND until the Sunday ring test, never TG_CHAT_FO / OI): go_now() = the GO NOW message + "from: Flows + Banks · against: ... · NOT PROVEN"; brief() with a Themes section max 3; manage(); system() lines (head silent > 2 cadences, seat silent, budget step reached). The decisions / system bots themselves belong to the desk service ring ledger.

## R51-style rows
**14 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| NOW in a trade: the GIR block carries the head's manage note | phone (fixture) | 390x844 | inside | PASS | o the stop · 2.1% ltp 13.50 6h GIR HOLD ANALYST 21:14 · NOT PROVEN FIXTURE: thesis intact - banks breadth negative for this name EXIT LINE · |
| CALL: FROM / AGAINST / NOT PROVEN, the head's card | phone (fixture) | 390x844 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban  |
| CALL: WHY 2 lines + "more" (finger) | phone (fixture) | 390x844 | inside | PASS | 2 -> 3 lines |
| CALL: one blue CONNECTION line | phone (fixture) | 390x844 | inside | PASS | present |
| no cut text (phone CALL, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| ALERTS: the brief note (changed first, Themes max 3) | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 18:00 NOT PROVEN changed: TCS PE CANCELLED FIXTURE: banks lead on foreign buying, IT under pressure from the US |
| ALERTS brief.stale: "STALE · <why>", never blank | phone (fixture) | 390x844 | inside | PASS | BRIEF 07:15 for 2026-11-23 · 18:00 NOT PROVEN STALE STALE · FIXTURE: the 09:08 brief failed (head timeout) - the 07:15 brief is shown change |
| no cut text (phone ALERTS, fixture) | phone (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| head not running: CALL keeps the old card, no brief note | phone (live) | 390x844 | inside | PASS | brief note False |
| no sideways scroll at 390 (phone) | phone (live) | 390x844 | inside | PASS | 390 |
| page errors | phone (live) | 390x844 | inside | PASS | none |
| head not running: CALL keeps the old card, no brief note | phone (live) | 390x844 | outside | PASS | brief note False |
| no sideways scroll at 390 (phone) | phone (live) | 390x844 | outside | PASS | 390 |
| page errors | phone (live) | 390x844 | outside | PASS | none |
