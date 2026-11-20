# D desk web 2_gonow - Monday item 2 - the F1 call card = the head's BUY NOW

Run 21 Nov 2026 01:36 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v2 (meter.cap 8, meter.lean, brief.stale / stale_why / failed_slot). Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v2 shape, every text
"FIXTURE", cap 8, lean on; the live state.json never touched; the STALE rows flip that fixture's view.stale / brief.stale) - inside only; **live** = the real store, inside
127.0.0.1:8100 and outside girtrader.com/preview through the login: tonight gir-v2desk reports status "starting", so every live box must keep
the engine's output under its old labels with the grey "analyst not running" chip. No-cut check on every changed box (scrollWidth >
clientWidth fails unless prose with a tooltip). Shots: girdata/review/monday/D_desk_web_shots/ (fixture inside, outside/ live), P&L masked
dark grey with "P&L hidden".

## What changed
static/desk-fill.js (one place for the desk's words) + desk-hunt.js: when the head is live and desk.buy_now has a valid row, it takes the GO NOW card (same size, place, amber fill, keys, no buy button): header "GIR ANALYST hh:mm · next look hh:mm"; STALE (desk.view.stale) -> grey STALE chip and the card reads "WAIT: analyst stale" (grey, no amber); VOTE row -> FROM (seat names) + NOT PROVEN chip and AGAINST (Devil); WHY lines with seat chips + sources (max 3); CANCEL IF; one blue CONNECTION line that opens F8 (analyst#theme). Levels come only from the plan code attached (entry / stop / t1 / premiums / lots / gates). Head not running -> the engine card exactly as before plus one grey line "analyst not running · engine call below · old labels".

## R51-style rows
**34 PASS**

| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1366x768 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 01:23 · next look 01:34 · 3m ago MUST SEE valid 01:37 	PREMIUM 1,000 CE	SHARE TRIGGER	33.00	991. |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1366x768 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1366x768 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1366x768 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1366x768 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1366x768 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1366x768 | inside | PASS | footer "alth DOWN · optquote MISSING · desk LEAN" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1366x768 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 01:23 · next look 01:34 STALE · 4m ago MUST SEE valid 01:37 	PR |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | inside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now analyst not running no engine card ei |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | inside | PASS | WN · optquote MISSING · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1366x768 | inside | PASS | none |
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1600x900 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 01:25 · next look 01:36 · 4m ago MUST SEE valid 01:39 	PREMIUM 1,000 CE	SHARE TRIGGER	33.00	991. |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1600x900 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1600x900 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1600x900 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1600x900 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1600x900 | inside | PASS | none |
| shell: P&L strip "AI $ of $<meter.cap>" (8), footer desk mode LEAN (meter.lean) | F1 desk (fixture) | 1600x900 | inside | PASS | footer "alth DOWN · optquote MISSING · desk LEAN" · strip AI "AI $1.84 of $8" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1600x900 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 01:25 · next look 01:36 STALE · 4m ago MUST SEE valid 01:39 	PR |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | inside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now analyst not running no engine card ei |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | inside | PASS | WN · optquote MISSING · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | inside | PASS | none |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | outside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now analyst not running no engine card ei |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | outside | PASS | WN · optquote MISSING · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1366x768 | outside | PASS | none |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | outside | PASS | NO CARD watch 0 · log 0 not shown LATEST DECISION no CRITICAL or MUST SEE call now analyst not running no engine card ei |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | outside | PASS | WN · optquote MISSING · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | outside | PASS | none |
