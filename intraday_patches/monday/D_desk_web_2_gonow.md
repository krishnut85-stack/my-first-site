# D desk web 2_gonow - Monday item 2 - the F1 call card = the head's BUY NOW

Run 20 Nov 2026 20:02 IST. Design: design_v3/DESK_WEB_CHANGES.md (replaces DESK_TEAM 6; the approved v3 boxes stay, the desk adds words and rows inside them).
Data: the desk.* facts of DESK_api.md v1. Real input only (mouse / keyboard / wheel at 1366x768 and 1600x900; CDP finger touches at 390x844).
Two data states: **fixture** = a TEST COPY of gir-preview on 127.0.0.1:8103 reading a fixture desk state.json (DESK_api v1 shape, every text
"FIXTURE"; the live state.json never touched; the STALE row flips that fixture's view.stale) - inside only; **live** = the real store, inside
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
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1366x768 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 19:49 · next look 20:00 · 4m ago MUST SEE ITC PE MAXHEALTH CE MAXHEALTH PE NTPC CE HDFCBANK CE I |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1366x768 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1366x768 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1366x768 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1366x768 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1366x768 | inside | PASS | none |
| shell: P&L strip "AI $ of $5", footer AI word = desk mode | F1 desk (fixture) | 1366x768 | inside | PASS | footer "alth LIMITED · atr LATE 116h · desk LEAN" · strip AI "AI $1.84 of $5" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1366x768 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 19:50 · next look 20:01 STALE · 4m ago MUST SEE ITC PE MAXHEALT |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | inside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 5h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | inside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 desk (live) | 1366x768 | inside | PASS | none |
| GO NOW card = the head's BUY NOW: GIR ANALYST header + next look | F1 desk (fixture) | 1600x900 | inside | PASS | GO NOW · SBIN CALL 1,000 29 DEC GIR ANALYST 19:51 · next look 20:02 · 4m ago MUST SEE ITC PE MAXHEALTH CE MAXHEALTH PE NTPC CE HDFCBANK CE I |
| FROM (seats) + AGAINST (Devil) + NOT PROVEN in place of the weight | F1 desk (fixture) | 1600x900 | inside | PASS | FROMFLOWS (India) · Banks · CONNECTIONS / THEMESNOT PROVEN AGAINST(Devil) FIXTURE: banks already priced the flows ✓ ban ✓ quote age HOLD2 lo |
| WHY with seat chip + source (max 3) and one blue CONNECTION line | F1 desk (fixture) | 1600x900 | inside | PASS | why lines 3 · seat chips 3 · connection True |
| CONNECTION opens the theme on F8 | F1 desk (fixture) | 1600x900 | inside | PASS | analyst#theme -> analyst#theme |
| one amber fill (the GO NOW card) | F1 desk (fixture) | 1600x900 | inside | PASS | ['cg-h'] |
| no buy / order button on the card | F1 desk (fixture) | 1600x900 | inside | PASS | none |
| shell: P&L strip "AI $ of $5", footer AI word = desk mode | F1 desk (fixture) | 1600x900 | inside | PASS | footer "alth LIMITED · atr LATE 116h · desk LEAN" · strip AI "AI $1.84 of $5" |
| no cut text (F1 GO NOW card, fixture) | F1 desk (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| STALE: grey STALE chip, the card reads "WAIT: analyst stale" (no amber GO NOW) | F1 desk (fixture) | 1600x900 | inside | PASS | WAIT: analyst stale · SBIN CALL 1,000 29 DEC GIR ANALYST 19:52 · next look 20:03 STALE · 3m ago MUST SEE ITC PE MAXHEALT |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | inside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 5h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | inside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | inside | PASS | none |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1366x768 | outside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 5h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1366x768 | outside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 1 |
| page errors | F1 desk (live) | 1366x768 | outside | PASS | none |
| head not running: the engine card under its old labels + grey "analyst not running" | F1 desk (live) | 1600x900 | outside | PASS | CRITICAL · ITC PUT NOTHING LATEST DECISION 15:16 · 5h ago · TV analyst call CRITICAL◉ analyst not running engine call be |
| footer AI word: desk OFF while the head is not running | F1 desk (live) | 1600x900 | outside | PASS | MITED · atr LATE 116h · desk OFF · head analyst not running (starting) |
| no cut text (F1, live) | F1 desk (live) | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip allowed: 0 |
| page errors | F1 desk (live) | 1600x900 | outside | PASS | none |
