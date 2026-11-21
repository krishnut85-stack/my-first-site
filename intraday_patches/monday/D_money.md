# MONEY + P1 + SHOCK lines on the pages (desk 21 Nov 08:55 MONEY; the trader's list 21 Nov 08:45 item 4)

Run 21 Nov 2026 09:14 IST. /preview pages only, inside the existing boxes (DESK_WEB_CHANGES: no new page, panel, colour or sound). gir-preview not restarted.

**MONEY R51: 136 PASS** (inside 109 PASS · outside 27 PASS), at 1366x768 / 1600x900 (mouse, hover for the numbers) and 390x844 (CDP finger taps).

## Keys read (gir-preview store; shapes from v2/analyst/money.py + service.money_step)
- **desk.money:** {line "MONEY: into A, B · out of C, D", sectors [per-sector lines: avg %, breadth, turnover Nx normal, % above VWAP], pairs [{pair, a, b, read, note}], ts, hm}. It is `[]` until the first 09:15 reading.
- **desk.rotation_0920:** {hm, pairs, line}. It is `[]` until 09:20.
- **desk.buy_now[]:** .money ("MONEY: into <sector> now: yes / no / mixed (...)"), .against_money ("AGAINST THE MONEY: <reason>" or null), .market, .against_market.

## What the trader sees
- **F1 Desk:** the MONEY strip is new rows in the existing Sectors panel head, under ROTATION:
  - **The MONEY line:** "MONEY in INSURANCE +1 · out BANKS +1" plus its time. Hover shows the full line and every sector's avg %, breadth, turnover "vs its normal" and % above VWAP.
  - **The 4 pairs** as compact chips: INS>BNF, PVT<PSU, IT<ER&D, DEF=NIFTY. Hover shows each pair's numbers and read, and that insurers sit in FINNIFTY, not BANKNIFTY.
  - **The 09:20 line:** "09:20 insurers vs BNF: money banks → insurers"; hover shows all four checks.
  - **No data yet:** "MONEY not yet (from 09:15)" and "09:20 rotation check: not yet".
  - **Outside market hours:** the last value with its time, plus the day when it is not today.
- **Phone NOW:** the MONEY line (full sector names, "last hh:mm" when closed) is the first line, above the prediction block. predict-board.js now places its block after it.
- **GO card (F1 BUY NOW card + phone CALL), under FROM / AGAINST:**
  - MARKET: the existing index-vs-VWAP witness, never shown on a page before.
  - MONEY: "into banks now: **no** (-0.62%, breadth 22% up / 72% down, turnover 1.8x vs its normal)", with yes / no / mixed in the existing up / down / grey colours.
  - "AGAINST THE MONEY: <reason>" and "AGAINST THE MARKET: <reason>", each with a red label.
- **Rotation alert:** the head's one line after a code ROTATION ALERT.
  - **F1:** a "ROTATION hh:mm · not a BUY NOW · NOT PROVEN" row with the line under it.
  - **Phone:** a line under MONEY on NOW, and a note in ALERTS in the brief's style.
- **Fixed along the way:**
  - The F1 ROTATION row printed "null" since 08:07 today: the 15M / 30M / 1H windows carry pct null. It now reads "no % in this window".
  - The phone CALL card's labels ran into their text ("FROMFLOWS"); they now get the desk's label style.

## Item 4 additions (P1, SHOCK, desk word, STALE)
- **Footer "desk ON - next brief <day hh:mm>":** the builder's 02:34 shell.js change, reading desk.meter.next_brief. The phone NOW card now shows the same words (GIR.aiWord from shell.js), e.g. "desk ON · LEAN - next brief Sun 19:45".
- **P1 lines:**
  - **Footer:** shows the desk's own P1 line first (desk.meter.p1: string or list, e.g. "P1 AI CREDIT EMPTY - top up at console.anthropic.com; GIR runs on rules; shock alerts still on"), then the gate's step "P1 AI provider refused: credit - AI OFF, rules only (next probe hh:mm)". It is shown in red and fits at 1366.
  - **Phone NOW card:** every P1 line, first and in red. The page also reads desk.meter.credit.line, for the coming balance warnings.
- **SHOCK lines (SHOCK_ALERTS.md):** the page reads `desk.shocks` [{story, level "RED"/"AMBER", family, hm, line, why}], newest last.
  - One line per story (the latest read wins), RED first, at most 2 lines.
  - Chips: RED = "SHOCK hh:mm" in the existing danger colour; AMBER = "shock hh:mm" in the existing warn colour.
  - The cause (WHY), the family and RED / AMBER are in the tooltip.
  - F1: rows above MONEY in the Sectors head. Phone: NOW card lines (with "n more" in a tooltip).
- **STALE:** the MONEY row gets a grey STALE chip when the desk facts are STALE (heartbeat old) or, in market hours, the line is over 10 min old. The footer then says "desk OFF · <why>".
- **NOT published yet, for the desk builder:**
  - `shocks` in v2/data/desk/state.json, plus `"desk.shocks": "shocks"` in gir-preview's DeskAdapter KEYS (a server change and restart that I did not make; the test copy has it).
  - The credit line as `meter.p1` (or `meter.credit.line`).

## Ask for the desk builder (not needed for Monday)
desk.view carries no marker for "written after a ROTATION ALERT". The page labels it when desk.status.last_look.kind is "event", the view's hm equals that look's hm, and the line names a rotation or money moving. If the builder adds `view.kind = "rotation"` (or the look's slot "hh:mm rotation"), the page already prefers it and the label becomes exact.

## Fixture (inside only)
A test copy of gir-preview on 127.0.0.1:8104 (current preview.py; its DeskAdapter reads deskfix/state.json, never the live file). The fixture holds:
- desk.money and desk.rotation_0920 in money.py's exact shapes;
- money / against_money / market on the SBIN BUY NOW;
- flag files for "no money yet", "no against_money" and "rotation alert".
The live store has desk.money = [] today (Saturday), so live rows check "not yet (from 09:15)".

## Other suites re-run on the final code
- **desk-web R51:** inside 102 PASS · outside 42 PASS.

## Undo
`cd v2/pages/static && cp -p desk-fill.js.bak0810 desk-fill.js && cp -p desk-hunt.js.bak0810 desk-hunt.js && cp -p phone.js.bak0810 phone.js && cp -p shell.css.bak0810 shell.css && cp -p desk-common.js.bak0811 desk-common.js && cp -p predict-board.js.bak0814 predict-board.js` (pages only, no restart).

Shots (P&L masked grey "P&L hidden"): girdata/review/monday/D_money_shots/ (inside, fixture + live) and D_money_shots/outside/.

## R51-style rows
| control | page | viewport | where | result | evidence |
|---|---|---|---|---|---|
| MONEY row: into / out of (first sector + "+n") and its time | F1 MONEY (fixture) | 1366x768 | inside | PASS | l1 df-mny/MONEY in INSURANCE +1 · out BANKS +1 08:55 |
| hover the MONEY line: the full line + per sector avg %, breadth, turnover "vs its normal", % above VWAP | F1 MONEY (fixture) | 1366x768 | inside | PASS | MONEY: into INSURANCE, CAPITAL GOODS · out of BANKS, IT / IN  insurance +1.12%, breadth 75% up, turnover 1.6x vs its normal, 75% above VWAP / IN  capital goods +0.84%, breadth 70% up, turnover 1.3x vs |
| hover a pair chip: its numbers (insurers vs BANKNIFTY: % / above VWAP / BANKNIFTY vs VWAP / the read / FINNIFTY note) | F1 MONEY (fixture) | 1366x768 | inside | PASS | INS>BNF -> insurers vs BANKNIFTY: insurers +1.12%, 75% above VWAP · BANKNIFTY below VWAP (-0.30%) → money moving from banks to insurers (insurers are NOT in BANKNIFTY (the |
| the 4 pairs as compact chips | F1 MONEY (fixture) | 1366x768 | inside | PASS | ['INS>BNF', 'PVT<PSU', 'IT<ER&D', 'DEF=NIFTY'] |
| the 09:20 rotation line (insurers vs BANKNIFTY) + all 4 checks on hover | F1 MONEY (fixture) | 1366x768 | inside | PASS | 09:20 insurers vs BNF: money banks → insurers · insurers vs BANKNIFTY: money moving from banks to insurers / insurers vs BANKNIFTY: insurers +1.12%, 75% above VWAP · BA |
| ROTATION window click still works, the MONEY rows stay | F1 MONEY (fixture) | 1366x768 | inside | PASS | ['1H ▾', True] |
| no cut text (F1 MONEY fixture) | F1 MONEY (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| GO card: MONEY line next to FROM / AGAINST (into this sector now: yes / no / mixed, breadth, turnover vs its normal) | F1 MONEY (fixture) | 1366x768 | inside | PASS | [['cl wrapl df-money', 'MONEYinto banks now: no (-0.62%, breadth 22% up / 72% down, turnover 1.8x vs its normal)', 'rgb(142, 151, 163)', 'df-mf df-mf-no']] |
| GO card: "AGAINST THE MONEY: <reason>" in the AGAINST-THE-MARKET style (red label) | F1 MONEY (fixture) | 1366x768 | inside | PASS | [['cl wrapl df-agm', 'AGAINST THE MONEYFIXTURE: SBIN Q2 beat, weight 4 - a stock-specific reason against the bank outflow', 'rgb(255, 90, 82)', '']] |
| GO card: the MARKET witness line (index vs VWAP), its note on hover | F1 MONEY (fixture) | 1366x768 | inside | PASS | ['MARKETNIFTY above VWAP (+0.41%) · BANKNIFTY below VWAP (-0.30%)'] |
| no cut text (F1 GO card MONEY) | F1 MONEY (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| no against_money -> no AGAINST THE MONEY line, MONEY stays | F1 MONEY (fixture) | 1366x768 | inside | PASS | [True, 0] |
| ROTATION ALERT: the head's one line, labelled ROTATION hh:mm · not a BUY NOW · NOT PROVEN | F1 MONEY (fixture) | 1366x768 | inside | PASS | ROTATION 08:56 not a BUY NOW NOT PROVEN / FIXTURE rotation: money out of BANKS into INSURANCE (breadth 72% down, turnover 1.8x) - wa |
| no cut text (F1 rotation alert) | F1 MONEY (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| an ordinary desk view is not labelled a rotation alert | F1 MONEY (fixture) | 1366x768 | inside | PASS | False |
| no MONEY yet: "MONEY not yet (from 09:15)" and "09:20 rotation check: not yet" | F1 MONEY (fixture) | 1366x768 | inside | PASS | ['MONEY not yet (from 09:15)', '09:20 rotation check: not yet'] |
| 0 page errors | F1 MONEY (fixture) | 1366x768 | inside | PASS | none |
| no sideways scroll | F1 MONEY (fixture) | 1366x768 | inside | PASS | 1366 px |
| footer: "desk ON · LEAN - next brief Sun 19:45" (desk.meter.next_brief) | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | health DOWN · optquote MISSING · desk ON · LEAN - next brief Sun 19:45 |
| P1: the desk's "P1 AI CREDIT EMPTY ..." line in the footer, red, not cut | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | ['health DOWN · optquote MISSING · P1 AI CREDIT EMPTY - top up at console.anthropic.com; GIR runs on rules; shock alerts still on', 'rgb(255, 90, 82)', True] |
| SHOCK lines on F1: one line per story (the latest WORLD read), RED first then AMBER, the cause on hover | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | ['SHOCK 08:52 WORLD · Nasdaq -5.3%, S&P -3.7%, SOX -10.7% · India opens ', 'shock 08:46 INDIA · BANKNIFTY -0.8% in 15 min · FIXTURE'] |
| hover a SHOCK line: the full line + WHY + family + RED / AMBER | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | WORLD · Nasdaq -5.3%, S&P -3.7%, SOX -10.7% · India opens Mon 09:15 · watch PE: DIXON, KAYNES · FIXTURE / WHY: FIXTURE - SEC probe of a mega-cap chip maker (3 s |
| no cut text (F1 SHOCK lines) | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip: 2 |
| STALE: the desk heartbeat old -> MONEY row STALE chip; footer "desk OFF · <why>" | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | ['MONEY in INSURANCE +1 · out BANKS +1 08:56 STALE', 'health DOWN · optquote MISSING · desk OFF · gir-v2desk not running (heartbeat 303 s old)'] |
| 0 page errors | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | none |
| no sideways scroll | desk word / P1 / SHOCK (fixture) | 1366x768 | inside | PASS | 1366 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 1366x768 | inside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 1366x768 | inside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 1366x768 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 1366x768 | inside | PASS | none |
| no sideways scroll | F1 MONEY | 1366x768 | inside | PASS | 1366 px |
| live footer: "desk ON - next brief <day hh:mm>" (or a mode / the P1 line / desk OFF with its reason) | desk word / P1 (live) | 1366x768 | inside | PASS | ealth DOWN · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| 0 page errors | desk word / P1 (live) | 1366x768 | inside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 1366x768 | inside | PASS | 1366 px |
| MONEY row: into / out of (first sector + "+n") and its time | F1 MONEY (fixture) | 1600x900 | inside | PASS | l1 df-mny/MONEY in INSURANCE +1 · out BANKS +1 08:57 |
| hover the MONEY line: the full line + per sector avg %, breadth, turnover "vs its normal", % above VWAP | F1 MONEY (fixture) | 1600x900 | inside | PASS | MONEY: into INSURANCE, CAPITAL GOODS · out of BANKS, IT / IN  insurance +1.12%, breadth 75% up, turnover 1.6x vs its normal, 75% above VWAP / IN  capital goods +0.84%, breadth 70% up, turnover 1.3x vs |
| hover a pair chip: its numbers (insurers vs BANKNIFTY: % / above VWAP / BANKNIFTY vs VWAP / the read / FINNIFTY note) | F1 MONEY (fixture) | 1600x900 | inside | PASS | INS>BNF -> insurers vs BANKNIFTY: insurers +1.12%, 75% above VWAP · BANKNIFTY below VWAP (-0.30%) → money moving from banks to insurers (insurers are NOT in BANKNIFTY (the |
| the 4 pairs as compact chips | F1 MONEY (fixture) | 1600x900 | inside | PASS | ['INS>BNF', 'PVT<PSU', 'IT<ER&D', 'DEF=NIFTY'] |
| the 09:20 rotation line (insurers vs BANKNIFTY) + all 4 checks on hover | F1 MONEY (fixture) | 1600x900 | inside | PASS | 09:20 insurers vs BNF: money banks → insurers · insurers vs BANKNIFTY: money moving from banks to insurers / insurers vs BANKNIFTY: insurers +1.12%, 75% above VWAP · BA |
| ROTATION window click still works, the MONEY rows stay | F1 MONEY (fixture) | 1600x900 | inside | PASS | ['1H ▾', True] |
| no cut text (F1 MONEY fixture) | F1 MONEY (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| GO card: MONEY line next to FROM / AGAINST (into this sector now: yes / no / mixed, breadth, turnover vs its normal) | F1 MONEY (fixture) | 1600x900 | inside | PASS | [['cl wrapl df-money', 'MONEYinto banks now: no (-0.62%, breadth 22% up / 72% down, turnover 1.8x vs its normal)', 'rgb(142, 151, 163)', 'df-mf df-mf-no']] |
| GO card: "AGAINST THE MONEY: <reason>" in the AGAINST-THE-MARKET style (red label) | F1 MONEY (fixture) | 1600x900 | inside | PASS | [['cl wrapl df-agm', 'AGAINST THE MONEYFIXTURE: SBIN Q2 beat, weight 4 - a stock-specific reason against the bank outflow', 'rgb(255, 90, 82)', '']] |
| GO card: the MARKET witness line (index vs VWAP), its note on hover | F1 MONEY (fixture) | 1600x900 | inside | PASS | ['MARKETNIFTY above VWAP (+0.41%) · BANKNIFTY below VWAP (-0.30%)'] |
| no cut text (F1 GO card MONEY) | F1 MONEY (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| no against_money -> no AGAINST THE MONEY line, MONEY stays | F1 MONEY (fixture) | 1600x900 | inside | PASS | [True, 0] |
| ROTATION ALERT: the head's one line, labelled ROTATION hh:mm · not a BUY NOW · NOT PROVEN | F1 MONEY (fixture) | 1600x900 | inside | PASS | ROTATION 08:58 not a BUY NOW NOT PROVEN / FIXTURE rotation: money out of BANKS into INSURANCE (breadth 72% down, turnover 1.8x) - wa |
| no cut text (F1 rotation alert) | F1 MONEY (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| an ordinary desk view is not labelled a rotation alert | F1 MONEY (fixture) | 1600x900 | inside | PASS | False |
| no MONEY yet: "MONEY not yet (from 09:15)" and "09:20 rotation check: not yet" | F1 MONEY (fixture) | 1600x900 | inside | PASS | ['MONEY not yet (from 09:15)', '09:20 rotation check: not yet'] |
| 0 page errors | F1 MONEY (fixture) | 1600x900 | inside | PASS | none |
| no sideways scroll | F1 MONEY (fixture) | 1600x900 | inside | PASS | 1600 px |
| footer: "desk ON · LEAN - next brief Sun 19:45" (desk.meter.next_brief) | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | health DOWN · optquote MISSING · desk ON · LEAN - next brief Sun 19:45 |
| P1: the desk's "P1 AI CREDIT EMPTY ..." line in the footer, red, not cut | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | ['health DOWN · optquote MISSING · P1 AI CREDIT EMPTY - top up at console.anthropic.com; GIR runs on rules; shock alerts still on', 'rgb(255, 90, 82)', True] |
| SHOCK lines on F1: one line per story (the latest WORLD read), RED first then AMBER, the cause on hover | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | ['SHOCK 08:54 WORLD · Nasdaq -5.3%, S&P -3.7%, SOX -10.7% · India opens ', 'shock 08:48 INDIA · BANKNIFTY -0.8% in 15 min · FIXTURE'] |
| hover a SHOCK line: the full line + WHY + family + RED / AMBER | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | WORLD · Nasdaq -5.3%, S&P -3.7%, SOX -10.7% · India opens Mon 09:15 · watch PE: DIXON, KAYNES · FIXTURE / WHY: FIXTURE - SEC probe of a mega-cap chip maker (3 s |
| no cut text (F1 SHOCK lines) | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip: 1 |
| STALE: the desk heartbeat old -> MONEY row STALE chip; footer "desk OFF · <why>" | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | ['MONEY in INSURANCE +1 · out BANKS +1 08:58 STALE', 'health DOWN · optquote MISSING · desk OFF · gir-v2desk not running (heartbeat 304 s old)'] |
| 0 page errors | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | none |
| no sideways scroll | desk word / P1 / SHOCK (fixture) | 1600x900 | inside | PASS | 1600 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 1600x900 | inside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 1600x900 | inside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 1600x900 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 1600x900 | inside | PASS | none |
| no sideways scroll | F1 MONEY | 1600x900 | inside | PASS | 1600 px |
| live footer: "desk ON - next brief <day hh:mm>" (or a mode / the P1 line / desk OFF with its reason) | desk word / P1 (live) | 1600x900 | inside | PASS | ealth DOWN · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| 0 page errors | desk word / P1 (live) | 1600x900 | inside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 1600x900 | inside | PASS | 1600 px |
| MONEY row: into / out of (first sector + "+n") and its time | F1 MONEY (fixture) | 390x844 | inside | PASS | l1 df-mny/MONEY in INSURANCE +1 · out BANKS +1 08:59 |
| the 4 pairs as compact chips | F1 MONEY (fixture) | 390x844 | inside | PASS | ['INS>BNF', 'PVT<PSU', 'IT<ER&D', 'DEF=NIFTY'] |
| the 09:20 rotation line (insurers vs BANKNIFTY) + all 4 checks on hover | F1 MONEY (fixture) | 390x844 | inside | PASS | 09:20 insurers vs BNF: money banks → insurers · insurers vs BANKNIFTY: money moving from banks to insurers / insurers vs BANKNIFTY: insurers +1.12%, 75% above VWAP · BA |
| ROTATION window click still works, the MONEY rows stay | F1 MONEY (fixture) | 390x844 | inside | PASS | ['1H ▾', True] |
| no cut text (F1 MONEY fixture) | F1 MONEY (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| GO card: MONEY line next to FROM / AGAINST (into this sector now: yes / no / mixed, breadth, turnover vs its normal) | F1 MONEY (fixture) | 390x844 | inside | PASS | [['cl wrapl df-money', 'MONEYinto banks now: no (-0.62%, breadth 22% up / 72% down, turnover 1.8x vs its normal)', 'rgb(142, 151, 163)', 'df-mf df-mf-no']] |
| GO card: "AGAINST THE MONEY: <reason>" in the AGAINST-THE-MARKET style (red label) | F1 MONEY (fixture) | 390x844 | inside | PASS | [['cl wrapl df-agm', 'AGAINST THE MONEYFIXTURE: SBIN Q2 beat, weight 4 - a stock-specific reason against the bank outflow', 'rgb(255, 90, 82)', '']] |
| GO card: the MARKET witness line (index vs VWAP), its note on hover | F1 MONEY (fixture) | 390x844 | inside | PASS | ['MARKETNIFTY above VWAP (+0.41%) · BANKNIFTY below VWAP (-0.30%)'] |
| no cut text (F1 GO card MONEY) | F1 MONEY (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| no against_money -> no AGAINST THE MONEY line, MONEY stays | F1 MONEY (fixture) | 390x844 | inside | PASS | [True, 0] |
| ROTATION ALERT: the head's one line, labelled ROTATION hh:mm · not a BUY NOW · NOT PROVEN | F1 MONEY (fixture) | 390x844 | inside | PASS | ROTATION 09:00 not a BUY NOW NOT PROVEN / FIXTURE rotation: money out of BANKS into INSURANCE (breadth 72% down, turnover 1.8x) - wa |
| no cut text (F1 rotation alert) | F1 MONEY (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| an ordinary desk view is not labelled a rotation alert | F1 MONEY (fixture) | 390x844 | inside | PASS | False |
| no MONEY yet: "MONEY not yet (from 09:15)" and "09:20 rotation check: not yet" | F1 MONEY (fixture) | 390x844 | inside | PASS | ['MONEY not yet (from 09:15)', '09:20 rotation check: not yet'] |
| 0 page errors | F1 MONEY (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | F1 MONEY (fixture) | 390x844 | inside | PASS | 390 px |
| phone NOW shows the same desk word as the footer: "desk ON · LEAN - next brief Sun 19:45" | desk word / P1 / SHOCK (fixture) | 390x844 | inside | PASS | ['desk ON · LEAN - next brief Sun 19:45', 'MONEY into INSURANCE, CAPITAL GOODS · out of BANKS, IT · last 08:59'] |
| phone NOW card: P1 lines first (red), then one SHOCK line per story (RED first), then MONEY | desk word / P1 / SHOCK (fixture) | 390x844 | inside | PASS | ['P1 AI CREDIT EMPTY - top up at console.anthropic.com; GIR ru', 'P1 AI provider refused: credit - AI OFF, rules only (next pr', 'SHOCK 08:56 WORLD · Nasdaq -5.3%, S&P -3.7%, SOX -10.7% · In', 'shock 08:50 INDIA · BANKNIFTY -0.8% in 15 min · FIXTURE', 'MONEY into INSURANCE, CAPITAL GOODS · out of BA |
| no cut text (phone P1 + SHOCK) | desk word / P1 / SHOCK (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | desk word / P1 / SHOCK (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | desk word / P1 / SHOCK (fixture) | 390x844 | inside | PASS | 390 px |
| NOW: desk word then the MONEY line at the top (above the prediction block), full sector names + "last hh:mm" when closed | phone MONEY (fixture) | 390x844 | inside | PASS | ['ln df-now df-dw df-top/desk ON · LEAN - next brief Sun 19:45', 'ln df-now df-mnow df-top/MONEY into INSURANCE, CAPITAL GOODS · out of BANKS, IT · last 09:00', 'pb-phone/TODAY · PREDICTION NOT PROVEN (day 0 of 20) - the code layer names shares that move, the s', 'pur/NOW · your open trades, nearest |
| CALL (finger): MONEY line + AGAINST THE MONEY on the head's card | phone MONEY (fixture) | 390x844 | inside | PASS | ['MONEYinto banks now: no (-0.62%, breadth 22% up / 72% down, turnover 1.8x vs its normal)', 'AGAINST THE MONEYFIXTURE: SBIN Q2 beat, weight 4 - a stock-specific reason against the bank outflow'] |
| no cut text (phone CALL MONEY) | phone MONEY (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| ALERTS (finger): the rotation alert as a head line, NOT PROVEN | phone MONEY (fixture) | 390x844 | inside | PASS | ROTATION GIR ANALYST 09:01 NOT PROVEN FIXTURE rotation: money out of BANKS into INSURANCE (breadth 72% down, turnover 1.8x) - watch HDFCLIFE |
| no cut text (phone ALERTS rotation) | phone MONEY (fixture) | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| NOW: the rotation alert line under MONEY (NOT PROVEN) | phone MONEY (fixture) | 390x844 | inside | PASS | ['ROTATION 09:01 FIXTURE rotation: money out of BANKS into INSURANCE (breadth 72% down, turnover 1.8x) - watch HDFCLIFE / SBILIFE CE, HDFCBANK / AXISBANK PE NOT PROVEN'] |
| NOW, no MONEY yet: "MONEY not yet (from 09:15)" | phone MONEY (fixture) | 390x844 | inside | PASS | MONEY not yet (from 09:15) |
| 0 page errors | phone MONEY (fixture) | 390x844 | inside | PASS | none |
| no sideways scroll | phone MONEY (fixture) | 390x844 | inside | PASS | 390 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 390x844 | inside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 390x844 | inside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 390x844 | inside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 390x844 | inside | PASS | none |
| no sideways scroll | F1 MONEY | 390x844 | inside | PASS | 390 px |
| live phone NOW: the desk word (or P1) and MONEY at the top | desk word / P1 (live) | 390x844 | inside | PASS | ['desk ON · rules only ($1.5 reached) - next brief Sun 19:45', 'MONEY not yet (from 09:15)'] |
| 0 page errors | desk word / P1 (live) | 390x844 | inside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 390x844 | inside | PASS | 390 px |
| live: NOW opens with the desk word + the MONEY line ("not yet (from 09:15)" or the last value with its time), above the prediction | phone MONEY | 390x844 | inside | PASS | ['ln df-now df-dw df-top/desk ON · rules only ($1.5 reached) - next brief Sun 19:45', 'ln df-now df-mnow df-top/MONEY not yet (from 09:15)', 'pb-phone/TODAY · PREDICTION NOT PROVEN (day 0 of 20) - the code layer names shares that move, the s'] |
| 0 page errors | phone MONEY | 390x844 | inside | PASS | none |
| no sideways scroll | phone MONEY | 390x844 | inside | PASS | 390 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 1366x768 | outside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 1366x768 | outside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 1366x768 | outside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 1366x768 | outside | PASS | none |
| no sideways scroll | F1 MONEY | 1366x768 | outside | PASS | 1366 px |
| live footer: "desk ON - next brief <day hh:mm>" (or a mode / the P1 line / desk OFF with its reason) | desk word / P1 (live) | 1366x768 | outside | PASS | ealth DOWN · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| 0 page errors | desk word / P1 (live) | 1366x768 | outside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 1366x768 | outside | PASS | 1366 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 1600x900 | outside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 1600x900 | outside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 1600x900 | outside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 1600x900 | outside | PASS | none |
| no sideways scroll | F1 MONEY | 1600x900 | outside | PASS | 1600 px |
| live footer: "desk ON - next brief <day hh:mm>" (or a mode / the P1 line / desk OFF with its reason) | desk word / P1 (live) | 1600x900 | outside | PASS | ealth DOWN · optquote MISSING · desk ON · rules only ($1.5 reached) - next brief Sun 19:45 |
| 0 page errors | desk word / P1 (live) | 1600x900 | outside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 1600x900 | outside | PASS | 1600 px |
| live: the MONEY row ("not yet (from 09:15)" or the last value with its time) + the 09:20 row | F1 MONEY | 390x844 | outside | PASS | l1 df-mny/MONEY not yet (from 09:15) / l1 df-r920/09:20 rotation check: not yet |
| live: the ROTATION row never prints "null" | F1 MONEY | 390x844 | outside | PASS | l1/ROTATION 30M ▾ no % in this window F3 › / l1 df-mny/MONEY not yet (from 09:15) |
| no cut text (F1 MONEY live) | F1 MONEY | 390x844 | outside | PASS | 0 cut cells · prose with a tooltip: 0 |
| 0 page errors | F1 MONEY | 390x844 | outside | PASS | none |
| no sideways scroll | F1 MONEY | 390x844 | outside | PASS | 390 px |
| live phone NOW: the desk word (or P1) and MONEY at the top | desk word / P1 (live) | 390x844 | outside | PASS | ['desk ON · rules only ($1.5 reached) - next brief Sun 19:45', 'MONEY not yet (from 09:15)'] |
| 0 page errors | desk word / P1 (live) | 390x844 | outside | PASS | none |
| no sideways scroll | desk word / P1 (live) | 390x844 | outside | PASS | 390 px |
| live: NOW opens with the desk word + the MONEY line ("not yet (from 09:15)" or the last value with its time), above the prediction | phone MONEY | 390x844 | outside | PASS | ['ln df-now df-dw df-top/desk ON · rules only ($1.5 reached) - next brief Sun 19:45', 'ln df-now df-mnow df-top/MONEY not yet (from 09:15)', 'pb-phone/TODAY · PREDICTION NOT PROVEN (day 0 of 20) - the code layer names shares that move, the s'] |
| 0 page errors | phone MONEY | 390x844 | outside | PASS | none |
| no sideways scroll | phone MONEY | 390x844 | outside | PASS | 390 px |
