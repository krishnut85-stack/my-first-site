# THE GIR PAGE LAYOUT REWORK (17 Nov) - for the Claude session running ON the GIR server

Rama, in his words: "I don't want the big F&O ban bar at the bottom. The GIR analyst box takes the whole TRADE NOW space and I can't go back.
The sector percentage and the list need to be big. News is everywhere. When I click a sector, the popup hides the F&O movers. Think like a
website designer, a coding designer and a trading-app designer." And: "the news everywhere and the tabs which are required and not required -
check and rework." And: "Before, we had agree and disagree, like 3 voting. After the rework a few days back it all vanished."

A mockup picture was shown to Rama in chat (not in this repo). This file is the spec.

## Rules for this job
- Do the steps after 15:35 (or at the weekend); only gir-dash restarts. Keep home.html.bak<time>; one undo line.
- NOTHING IS DELETED. Every box and tab that moves keeps working; its old keyboard key still opens it. If unsure what a part does, keep it.
- Before coding: list every box, panel and tab on today's home.html (with the patch that added it) and every place news shows. Show Rama
  that list with the plan below marked against it, and wait for his OK.
- Test at laptop width (1600 x 900), at 1366 x 768, and on the phone (390 wide). Take screenshots and show them.

## 1. The top bar (one slim row, ~46 px)
GIR · NIFTY / BANKNIFTY / SENSEX / VIX (price and %) · EXPIRY + days left · PCR · FII / DII · **a small red "⛔ BAN: KAYNES" pill** (tap = the
list and "only close existing positions") · search share · 🔊 SOUNDS · ✓ CHECK · market status and data age.
The F&O DESK strip (EXPIRY, PCR, VIX, MARKET, FII / DII) moves up here. **The big red ban bar at the bottom goes.**

## 2. Three columns
| left (~330 px) | centre (rest) | right (~390 px) |
|---|---|---|
| 🧭 SECTORS - big, full height | tabs + chart (~300 px, shorter) | 🧠 GIR ANALYST - compact |
| 📈 F&O MOVERS (UP / DOWN / ALL) | ⚡ ACTION - every call, one feed | 📰 NEWS - all news, one column |

### Left: SECTORS and MOVERS
- Sector name 14 px, % 15 px bold, a bar; TODAY / 15M / 30M / 1H chips; sort and WHY / MONEY as small chips. Keep the ⚠ "one share = X% of
  the move" note and the ▲/▼ counts.
- **A click on a sector opens it in place (an accordion)** - its F&O shares with %, the build-up word, and the ⚠ note. A second click closes
  it. No popup over the movers.
- ROTATION (money going in / out) becomes a line at the top of the sector list.

### Centre: ACTION feed (replaces the scattered alert lists)
- ONE list, newest first, of every call: the analyst's calls, ⚡ BE READY, the EARLY / OPENING / FIRST MOVE / SPEED rows, NEWS SHOCK, and
  Rama's own trade's HOLD / EXIT / BOOK HALF. Chips: ALL · ACT NOW · GET READY · MY TRADES · QUIET (the quiet types of patch 387).
- Each card: label (ACT NOW red / GET READY green / EARLY / INFO grey) · ▲ CE or ▼ PE · share · time · source; then 📍 HAPPENING /
  🔮 NEXT / ✅ ACTION (NEXT_STEPS step 2) or the strike line (CE 7800 · price · 1 lot · stop); the move since the call, live.
- **⚖ THE VOTE comes back on every card** (see 5).
- The page shows a card the moment it is in the alert log (NEXT_STEPS step 1: the page first, Telegram ~5 s later).

### Right: ANALYST (small) and NEWS (one place)
- 🧠 GIR ANALYST: the one-line view, a one-line desks summary, "open the 6 notes", and ASK. **ASK and the answers open in a side drawer**
  over the right column only, with a close button - the analyst never pushes other boxes away or takes the TRADE NOW space.
- 📰 NEWS: the ONLY news list on the page. Time · share (or 🧭 MARKET / 🌍 WORLD / 🏛 POLICY) · headline · the AI's ▲/▼ tag · source.
  Chips: ALL · MY SHARES · POLICY · CRITICAL · MARKET. Repeats folded (×8). Tap = the story and the share card.

## 3. News today shows in (from Rama's laptop photos) - fold into the one NEWS column
1. the ALERTS · BIG box (top right): FOREIGN ×8, MARKET ×8, JINDALSTEL, GLENMARK ... - news lines mixed with trade alerts
2. the EARLY list: a NEWS column on every row (keep a short "news: source time" on the ACTION card; the full item lives in NEWS)
3. the OI SCENARIOS · NEWS box at the bottom (CGPOWER, GLENMARK ...)
4. the MARKET tab's news part
Check the real page for more (WHY popups, RESULTS) and list them. The trade alerts from ALERTS go to ACTION; the news lines go to NEWS.

## 4. Tabs - today 12 tabs + 5 buttons. Proposed (confirm against the real page first)
| today | plan |
|---|---|
| BOARD | keep (first tab) |
| NOW, EARLY list | into the ⚡ ACTION feed |
| F&O MONEY, BIG MONEY, F&O TAPE | one tab **MONEY** with three chips (by sector / futures by month / tape) |
| OI SCENARIOS, OPTIONS | one tab **OPTIONS & OI** with two chips (its news part goes to NEWS) |
| MARKET | its news to NEWS, its numbers to the top bar; keep the tab only if something is left |
| RESULTS | keep |
| TOMORROW, TODAY, CHECKLIST | one tab **PLAN** (today / tomorrow / checklist chips) - check what each holds first |
| MY F&O, COCKPIT | one tab **MY TRADES** - check what COCKPIT holds first |
| GUIDE | a "?" in the top bar |
| SOUNDS, CHECK | small buttons in the top bar |
Result: about 6 tabs - CHART · BOARD · MONEY · OPTIONS & OI · RESULTS · PLAN · MY TRADES. Old number keys still open the same views.

## 5. ⚖ THE VOTE - find what vanished and bring it back
Rama remembers "agree / disagree, like 3 voting" on the page before a rework a few days ago. Candidates:
- the desk's per-sector agents 1-3 and the auditor's verdict (desk.py, THE DESK) shown per sector / per share
- patch 225's "⚖ VOTE n/6 ✔ P1 · desk ✓ · ..." line inside alerts
- the EARLY rows' "4 of 4 agree" icons (still visible on 17 Nov)
Search the page backups (home.html.bak*, newest first) for the last one that had it, show Rama a screenshot of that version, and confirm
which one he means. Then show it on every ACTION card: "⚖ VOTE 4 of 5 agree · agents 1 ✓ 2 ✓ 3 ✗ · news ✓ · money ✓ · auditor: PE", and on
the sector accordion (each sector's agents and the auditor's CE / PE). Only real votes - a voter that did not vote shows "?" not ✓.

## When done
Screenshots at the three sizes, a list of what moved where, the undo line.
