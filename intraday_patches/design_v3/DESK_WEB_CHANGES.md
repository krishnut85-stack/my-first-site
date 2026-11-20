# GIR web + phone: what the new desk team adds, and what stays (lead designer, Fri 20 Nov 2026, evening)

The trader asked: "The last web design was okay. Are you going to change that also? Ask the design team what changes you are
going to make with the new team and what is required for the web desk."

**Answer in one line: the approved v3 design stays as it is. The desk adds words and rows inside panels that already exist. No
new page, no new F-key, no new panel, no new colour, no new sound.**

Read with: SHELL.md, IA.md, CONFERENCE.md, REQUIREMENTS.md, the approved pages in `pages/`, and DESK_TEAM.md section 6 (which
this file answers and trims). Where this file and DESK_TEAM.md section 6 disagree on the screens, this file stands. The desk's
seats, costs and build order (DESK_TEAM sections 1-5 and 7) are not changed here.

---

## 1. The rule for every addition

1. **Nothing in the shell moves.** Market strip, P&L strip, the two-row tab bar (F8 still reads "Analyst"), footer, geometry
   (162 + 22 px, 1600 x 716 / 1366 x 584), tokens, Inter / JetBrains Mono, light theme, the 1366 drop order, the 390 phone, keys,
   sounds (R10 / E14). Shell text changes are made once in `shellwork/build.js`, never by hand.
2. **Reuse, do not add.** Every desk output goes into an existing panel, card, row, tab or drawer. If it does not fit, it goes
   behind an existing click (Why / W, a row expand, the "more" fold), not into a new box.
3. **Existing colour meanings only.** CE = green chip, PE = red chip. The desk's BUY NOW is the existing **GO NOW** card: the one
   amber fill on a screen. Themes and connections use `--info` blue (`.sh-c-info`). NOT PROVEN, "not running", STALE use the grey
   `.sh-c-stale` chip. No new token.
4. **Nothing new rings.** BUY NOW takes GO NOW's chime; an ARMED idea on a sector call takes GET READY's soft tick (once, M mutes);
   manage notes / exits on his trades keep the two low notes. Themes, seat cards, WHY NOT and Ask answers never ring.
5. **Honest labels.** The head analyst speaks under the existing "GIR ANALYST" label. If the head is not running, the old engine
   output keeps its old labels with a grey "analyst not running" chip. Engine cards are never dressed up as analyst calls.
   Every desk call carries NOT PROVEN until the scorecard says otherwise.

---

## 2. Where each desk output goes (the map)

| Desk output | Goes into (existing) | Monday or later |
|---|---|---|
| Evening brief (19:45, 22:45 if changed, 07:15, 09:08) | Morning ⇧F1: TODAY'S PLAN band (headline) + TODAY / TOMORROW 19:45 table (ideas). F8: NOTES · PLAN rows (archive). Phone ALERTS note. Telegram decisions bot | **Monday** (Sunday 19:45 is the first) |
| Desk view (lean, main theme, when the head last looked) | F1 call-card header line + the THEME rows at the top of the Sectors panel (desk-hunt) / DRIVERS row (desk-trade). Phone NOW (flat) situation line | **Monday** |
| BUY NOW card (contract, why + sources, against, enter only if, cancel if, stop, target, lots) | The existing GO NOW call card on F1 (and its copies: F8 latest decision, phone CALL, Telegram). Plan card unchanged | **Monday** |
| Manage notes on his trades | The existing "GIR" row inside each position card (desk-trade), FOLLOW-UPS (F6), the GIR block on phone NOW, Telegram follow-ups | **Monday** |
| Ideas list during the day (ARMED / FIRED / STANDS / CHANGED / CANCELLED) | The existing ACTION panel rows on F1 (desk-trade already has an IDEAS filter; desk-hunt gets the same chip) | **Monday** |
| Themes / connections (e.g. AI IPO -> FII rotation -> banks) | Morning: the DRIVERS -> SECTOR -> EVERY F&O SHARE band (one card per theme). F8: THESIS & THEME tab. F1: one blue CONNECTION line inside the call card | **Monday** (plain); link states week 1 |
| "Why not" lines | F1 members table: the grey reason under the cut line. F2 drill-down: the grey NOT PREDICTED cell | Week 1 |
| Desk board (seat notes) | F8 centre panel: a second tab "DESK BOARD" beside "DECISIONS", same row component | Monday if time (first to drop); full in week 1 |
| Seat roster (who is running, cost, record) | F8 right panel: the existing TEAM · COST tab (it is already an agent table: last, woke / sent, $, 20-day record) | **Monday** (honest, most seats "not running yet") |
| Ask the desk | The existing "Ask the analyst" box / Q drawer (already on Desk, Morning, F8, Journal, Scorecard) | **Monday** as is (head answers); seat picker + TELL in week 1 |
| Coverage ("the team looked at everything") | Morning pre-flight check row ("Agents 10 of 11" -> "Desk n of 40 seats running"); F8 WHAT I AM NOT SEEING | **Monday** (seat count); read counts week 1 |

---

## 3. Laptop pages

### 3.1 F1 Desk (desk-hunt, desk-trade) - the main screen

| Page / panel | What is added | Monday or later | What stays |
|---|---|---|---|
| Call card header (GO NOW / GET READY) | "LATEST DECISION 10:05:00 · 12s ago" reads "GIR ANALYST 10:05:00 · 12s ago · next look 10:15". If the head's last look is older than 2 cadences: grey STALE chip, and the card shows "WAIT: analyst stale" instead of the amber GO NOW | **Monday** | card size, place, amber fill, countdown, keys Space / S / W, no buy button |
| Call card VOTE row | Wording only: "FROM Flows · Banks · Connections (2 benches)" and "AGAINST (Devil): month already up, RSI extreme - answered: pullback entry only". "85% weighted for" is replaced by the grey NOT PROVEN chip until seat weights exist (20+ scored cards a seat) | **Monday** | row position, height, the gate chips row |
| Call card WHY (behind W / the scroll) | Each WHY line gets seat chip + source + age (max 3). One blue `--info` CONNECTION line: "AI IPO -> FII -> banks · 1 episode · NOT PROVEN" (click = F8 theme) | **Monday** | TRIGGER / ENTRY (= enter only if), "valid till ... or prem > ... or share < ..." (= cancel if), STOP / backstop, TARGET, SIZE (= lots), HOLD rule - all already on the card |
| Sectors panel THEME rows (desk-hunt) / DRIVERS row (desk-trade) | Filled from the head's top 2 themes instead of the engine's legs; same chips (PUT / CALL, INTACT / FORMING / WEAKENING) | **Monday** | two rows, same height |
| ACTION panel (right, bottom) | The head's ideas are its rows (GET READY = ARMED, GO NOW = FIRED); a CHANGED / CANCELLED idea shows the word + reason in `--text-3`. desk-hunt gets the "IDEAS n" filter chip desk-trade already has | **Monday** | panel, filters, "noise hidden" line, 1366 behaviour (the chip must not wrap - shot.js) |
| Position cards, "GIR" row (desk-trade) | The head's manage note: "HOLD - thesis intact: banks breadth positive (Banks 10:31)" / "BOOK HALF" / "EXIT - thesis broken: reason" + "from Risk · Tape" in place of "4 of 5 agree" | **Monday** | card layout, KITE exit line, Copy, EXIT NOW ladder (15:00 / 15:05 / 15:08) |
| Members table (centre) | WHY NOT words in the existing grey reason under the cut line: "price-only move, no reason found", "EXTREME RSI - no chase" | Week 1 | table, columns, cut line |

Nothing to remove: the approved Desk already has no news line (R44). Chart, strike chooser, F&O movers, Sectors list: untouched.

### 3.2 ⇧F1 Morning - the evening brief

| Page / panel | What is added | Monday or later | What stays |
|---|---|---|---|
| TODAY'S PLAN band | The head's brief headline ("Tomorrow leans UP · banks CE on a pullback · metals PE") with "analyst 19:45 · v3 07:15"; one 13 px line "changed since 19:45: IT PE cancelled · banks CE stands". Band height unchanged (at 1366 the line sits behind a ▸) | **Monday** | band, NOT ARMED / GET READY chips on the right |
| TODAY / TOMORROW 19:45 table | The head's ideas, at most 5 a side, CE and PE both shown (R52). Click a row = 3 lines under it: WHY (with seat + source), AGAINST (Devil), CANCEL IF. Status cell shows STANDS / CHANGED 07:15 / CANCELLED (grey, struck) | **Monday** | columns (option, trigger, stop, target, max loss, status), the "N more shares · below line" fold |
| DRIVERS -> SECTOR -> EVERY F&O SHARE band | Each card can be a desk theme, e.g. "FII +₹7,411 cr · 14th day -> Private banks -> HDFCBANK · ICICIBANK · AXISBANK CE" with a blue THEME chip and NOT PROVEN. Winners and losers both listed with the existing CE / PE chips (the positive-thinking rule). More than 3 = the band's existing ‹ › | **Monday** | card component, 3 visible, roles and chips |
| PRE-FLIGHT checks row "Agents 10 of 11" | Reads "Desk 6 of 40 seats running · LEAN · $ of $5". Week 1 adds "read since 15:45: n filings · n news · n TV min · n world" | **Monday** (count) / week 1 (read counts) | check list, ARM THE DAY |
| GLOBAL CUES tiles | NSDL sector flow and Korea / Taiwan foreign flow as tile sublines (Kospi tile exists) | Week 1, only when the feeds are live (G2 / G3) | tile grid |

### 3.3 F8 Analyst - where the size of the team shows (instead of a new "Desk Room")

| Page / panel | What is added | Monday or later | What stays |
|---|---|---|---|
| Latest decision band | Nothing new: it already shows the head's latest call, model, cost | - | as approved |
| Left: THESIS & THEME tab | Lists the desk's themes as its existing leg cards (chain, "07:15 set › 09:20 confirmed › now INTACT", wrong-if, names). Adds "1 episode · NOT PROVEN". Week 1: each link SEEN / EXPECTED / CONFIRMED BY PRICE / BROKEN in that same timeline line, and one AGAINST line (answered / unanswered) | **Monday** (plain) / week 1 (link states, objections) | card component, WRONG IF, ONE BET lines |
| Left: WHAT WOKE ME tab | Each row names the seat that woke the head (seat chip) | **Monday** | row format |
| Centre: "DECISIONS" header | Becomes a tab pair "DECISIONS · DESK BOARD", like the left and right columns already are. DESK BOARD = latest card per seat, same row component: time · seat chip · claim · CE / PE chips · source + age · "adopted -> idea #" or "not adopted: reason". Week 1: bench / seat / sector / CE / PE / my-held filters in the existing filter-chip row, and a "history" toggle | Monday if time (first to drop) / week 1 full | Decisions feed, its filters |
| Right: TEAM · COST tab | Becomes the seat roster: same columns (last, woke / sent, $, 20-day vs base), grouped by bench, scrolls (40+ rows, no layout change); status dot running / quiet / paused by budget / feed stale / "not running yet". Header "$4.10 of $20" reads "of $5" | **Monday** | tab, columns |
| Right: NOTES · PLAN tab | Note rows use the desk's times (19:45 / 22:45 / 07:15 / 09:08 / 15:45; 23:45 becomes 22:45). Week 1: "minutes ›" in a note's expand lists which seats spoke | **Monday** (times) / week 1 (minutes) | rows, read / unread |
| WHAT I AM NOT SEEING | Lists silent seats and stale new sources the same way as stale feeds | Week 1 | list |
| "Ask the analyst" box (Q) | Answered by the head from stored facts, saved to the board, labelled "a view, not a call", cost shown (already). Week 1: seat picker (default: head routes) and "TELL the desk" (his read stored as TRADER READ and scored) | **Monday** as is / week 1 picker + TELL | box, drawer over one column only |

### 3.4 Other pages (small, mostly week 1)

| Page | What is added | Monday or later | What stays |
|---|---|---|---|
| Shell P&L strip | "AI $4.10 of $20" reads "of $5" (meter scale), all 23 pages via build.js | **Monday** | everything else in the strip |
| Shell footer | The existing AI word "AI full / lite / off" becomes the desk mode: "desk FULL / LEAN / OFF" (LEAN on Monday) | **Monday** | footer = controls only (trader, 19 Nov) |
| F6 My trades | FOLLOW-UPS rows carry the head's manage notes (same text as the desk-trade GIR row) | **Monday** | page |
| ⇧F9 Health | One row: "gir-desk · head last look hh:mm · budget step ($4.25 / $4.60 / $5) · mode". Week 1: one row per seat and per new source (KRX, TWSE, NSDL, ETF, tech feeds, CDS) in the existing tables | **Monday** (one row) / week 1 | page |
| ⇧F8 Scorecard | Head calls are scored as GIR calls (already). Week 1: SEATS and SOURCES as views in its existing filter row | Week 1 | page |
| F2 Sectors / drill-down | WHY NOT reason in the grey NOT PREDICTED cell; a blue desk-note chip on a sector a theme names | Week 1 | page |
| F4 News | THEME / FLOW filter chip (the lines B8 drops) and "used in idea #" tag on a row | Week 1 | page |
| F7 Share | The desk's cards on this share as rows under THE VOTE / GIR CALL | Week 1 | page |
| ⇧F2 World | Already designed (world.html). The world seats' latest cards become the rows of "THE WORLD SAYS" | Week 1 (world seats start week 1) | page |
| ? Help | One entry: FROM / AGAINST / NOT PROVEN / blue CONNECTION / desk modes | Week 1 | page |
| F3 Rotation | A FLOWS view in its existing TABLE / LADDER / RUN CLOCK / ALARMS tab row, only when NSDL / KRX feeds are live | Later | page purpose (rotation, not a flows page) |
| Ctrl , Settings | Budget ladder view and seat on / off (outside market hours); until then seats are switched in `seats.yaml` on the server | Later | page |
| ⇧F10 Replay | Replays F8 from the stored board (no drawing change) | Later | page |
| Plan card, F9 Chain, F10 Fut & OI, ⇧F4 Calendar, ⇧F6 Journal, ⇧F7 Reference, /NIFTY Market | Nothing | - | untouched |

---

## 4. Section 6 items we push back on (they change the approved look more than needed)

| DESK_TEAM 6 proposed | Our answer | Why |
|---|---|---|
| A new "DESK ROOM" page replacing Analyst & Notes, new 3-column layout, tab renamed | **No.** F8 Analyst keeps its name and layout; it gains one centre tab (DESK BOARD) and its TEAM · COST tab becomes the seat roster | F8 already has the latest decision, themes, what woke me, decisions feed, notes, team / cost table, not-seeing list and Ask. A rename changes the tab grid on all 23 pages |
| Morning renamed "EVENING BRIEF and MORNING"; C1 table moved into a closed fold; new right-column THEMES lane, FLOWS box, COVERAGE line | **No.** The name and panels stay. The head fills the TODAY / TOMORROW 19:45 table and the TODAY'S PLAN band; themes go into the existing DRIVERS band; coverage is the pre-flight row; flows are the M2 strip (FII / DII, FII F&O already there) + cue tiles in week 1 | The approved Morning already has every slot. The "price lists are no better than random" point is met by content (the head's list replaces the price-ranked one; the rest stays under the existing "below line" fold), not by a new layout |
| Desk right column re-stacked: DESK VIEW strip, TODAY'S IDEAS replacing PREDICTED TODAY, WHY NOT fold, news line removed | **No re-stack.** Desk view = the call-card header line + Sectors THEME rows; ideas = the ACTION panel rows + IDEAS chip; WHY NOT = the members table cut line (week 1). The news line is already gone in the approved Desk | The call card keeps its full height; R45 / R48 balance was approved |
| COVERAGE MAP grid (a new visual) | **No.** One count line + WHAT I AM NOT SEEING + Health rows | New visual, not needed to prove coverage |
| World drivers P15 "design now (was not designed)" | **Not needed.** It is designed and approved (world.html); only its rows get desk cards | - |
| Rotation becomes the flows page | **No.** At most a FLOWS view in its existing tab row, later, when the feeds exist | Changes an approved page's purpose |
| Footer "AI $x of $5 · Opus / Sonnet / Haiku · desk FULL / LEAN / EVENTS ONLY · head looked hh:mm" | **No.** Only the existing AI word changes (desk FULL / LEAN / OFF). $ is in the P&L strip; "head looked" is on the call card | The trader cut the footer to controls only on 19 Nov; 1366 fit |
| Phone: DESK tab, TAKEN / SKIP buttons, theme chips that open chain cards, folding RISK into NOW | **Not Monday; his choice later.** The 4-tab bar (NOW · CALL · RISK · ALERTS) and the approved buttons stay | The phone is approved as a small product: no board, no news |
| Settings budget ladder and seat on / off | Later (server file meanwhile) | Not needed to trade Monday |
| The word on the card: "BUY NOW" | **Keep "GO NOW"** (it already means "buy this option now"; GIR only buys options). If he wants the words "BUY NOW", it is a one-word text change, same colour and place - his choice, not Monday | "GO NOW" is in the sound legend, filters, phone badge, Telegram and Help on every page |

Agreed with section 6 as written: CE green / PE red; one amber fill; connections in blue; no confidence grade on the card (NOT
PROVEN + source record instead); AI cap shown as $5; sounds unchanged; no news feed on the Desk or phone; seats never ring.

---

## 5. Phone (/m, 390 x 844) - the minimum

| Screen | What is added | Monday or later | What stays |
|---|---|---|---|
| NOW (in a trade) | The GIR block in each position card carries the head's manage note + "from Risk · Tape" | **Monday** | card, share vs stop, exit line, Copy exit line, Open Kite app |
| NOW (flat) | The situation line reads the desk view: "Desk: lean PE · 2 ideas armed · next look 10:15 · brief ›" (link to the note in ALERTS) | **Monday** | layout |
| CALL | Same wording as the laptop card: FROM (seats), AGAINST (Devil), grey NOT PROVEN chip in place of the weight; WHY 2 lines + "more"; one blue CONNECTION line | **Monday** | ANALYST · LATEST card, call card fields, buttons |
| RISK | Nothing | - | untouched |
| ALERTS | The brief (19:45 / 22:45 / 07:15 / 09:08) is the existing note "readable in 30 s", with "changed since" first and "Themes" (max 3 lines). Theme state changes listed silently | **Monday** | list, filters, 0.6 s hold to acknowledge |
| Push | BUY NOW = the GO NOW push, full lock-screen text: "GO NOW · SBIN Dec 1000 CE · prem <= X till 10:42 · stop SBIN Y · 2 lots · why: FII buying banks · NOT PROVEN". Manage notes on taken trades = existing follow-up push. Brief = silent push only if something changed | **Monday** | P1 / P2 rules, tones |
| Tab bar | Nothing. No DESK tab, no board, no news, no Ask on the phone for now | Later (his choice) | NOW · CALL · RISK · ALERTS |

## 6. Telegram - the minimum

| Bot | What is added | Monday or later | What stays |
|---|---|---|---|
| Decisions bot | GO NOW (= BUY NOW) message adds two lines: "from: Flows + Banks · against: month already up · NOT PROVEN". Manage notes as the existing follow-ups. The brief per meeting (19:45, 22:45 if changed, 07:15, 09:08) with a "Themes" section of max 3 lines | **Monday** | edited to EXPIRED / "seen hh:mm:ss", owner only |
| Decisions bot, 15:45 scorecard | Week 1: one line per seat / source that earned or cost a call | Week 1 | the existing scorecard message |
| System bot | "head analyst silent > 2 cadences", "filings seat silent", "flows seat silent", "budget step reached $4.25 / $4.60 / $5" | **Monday** | P1 / P2 health, "recovered", P3 digest |

No themes, seat cards, Ask answers or news go to Telegram on their own. Nothing new rings.

---

## 7. The Monday list (by Mon 23 Nov 08:30) and the cut line

Required (in this order; each degrades honestly to the old labels with "analyst not running" if the head is not live):
1. **Shell values:** P&L strip "AI $ of $5"; footer AI word = desk mode (LEAN). Via build.js, all 23 pages.
2. **F1 call card (= BUY NOW):** GIR ANALYST header with "next look", STALE -> WAIT rule, FROM / AGAINST lines, NOT PROVEN chip
   instead of the weight, WHY with seat + source + age, one blue CONNECTION line.
3. **Manage notes:** desk-trade GIR row, F6 FOLLOW-UPS, phone NOW GIR block, Telegram follow-ups.
4. **Phone + Telegram:** CALL wording, NOW desk line, ALERTS brief note, push text; decisions bot from / against / NOT PROVEN +
   brief with Themes; system bot silence and budget-step lines.
5. **Morning:** TODAY'S PLAN headline + "changed since"; TODAY / TOMORROW 19:45 table = the head's ideas with the WHY / AGAINST /
   CANCEL IF row expand; DRIVERS band cards as themes; pre-flight "Desk n of 40 seats running".
6. **F1 ACTION panel + THEME rows:** the head's ideas as rows, IDEAS chip on desk-hunt; THEME / DRIVERS rows from the head.
7. **F8:** THESIS & THEME = themes; WHAT WOKE ME seat chips; TEAM · COST = honest roster (of $5); note times 22:45; Ask box answered
   by the head. **Health:** the one gir-desk row.
8. **Checks before 08:30:** 0 console errors on all 23 pages; shot.js 0 cut / 0 overlap / 0 past edge at 1600 and 1366, dark and
   light; no sideways scroll at 1366 and 390; one amber fill per screen; masked P&L in screenshots; every new chip, tab, row
   expand and link tested by Playwright and by hand (R51 table); a 20 Nov replay shown through the pages.

Cut line if the weekend runs short (same rule as DESK_TEAM 7): items 1-4 and 8 are the minimum. Then 5, then 6. Item 7 and the
F8 DESK BOARD tab drop first; until then the Sunday brief shows in Morning's existing note and table.

**Week 1 (Wed 25 - Mon 30):** F8 DESK BOARD tab with filters and history; theme link states and objections; minutes; WHAT I AM NOT
SEEING for seats; Ask seat picker + TELL the desk; WHY NOT on the Desk cut line and the drill-down; Morning read counts and flow
tiles (when G2 / G3 are live); World rows; News THEME / FLOW filter; Share desk rows; Health seat and source rows; Scorecard
SEATS / SOURCES; Help entry; Telegram scorecard seat lines.

**Later / his choice:** Rotation FLOWS view; Settings ladder and seat switches; phone DESK tab and Ask from the phone; the
basket-shock ring; the words "BUY NOW" on the card; Replay of the board.

**Untouched, all the way:** the shell geometry and bands, tokens, fonts, light theme, keys, sounds, the 23 page layouts, the Plan
card, Chain, Futures & OI, Calendar, Journal, Reference, Market, and the phone's four screens and tab bar.

---

## 8. Answer to the trader

The design stays; these are the only additions. The v3 web terminal and phone you approved keep every page, panel, colour, font,
key and sound. The new desk does not get a new page; it speaks through the boxes you already have: the GO NOW card on F1 becomes
the head analyst's BUY NOW and gains two short lines (FROM which desk seats, AGAINST what the devil's advocate says) and a NOT
PROVEN tag; the "GIR" line under each open trade carries his manage note; the Morning page's plan band and ideas table carry the
evening brief (at most 5 ideas a side, each with why, against, enter only if, cancel if, stop, target, lots); the Morning drivers
band and the F8 Analyst page show the themes such as "AI IPO -> FII money -> banks"; F8's team table becomes the list of seats
with what each costs; and the "Ask the analyst" box you already have answers for the desk. On the phone and Telegram the same
call simply shows "from / against / NOT PROVEN", and the brief arrives in Alerts; nothing new rings. For Monday we only change
words and rows inside existing boxes; the desk board tab, "why not" lines and seat scores follow in week 1.
