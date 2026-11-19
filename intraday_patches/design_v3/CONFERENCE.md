> **OVERRIDE (the trader, 19 Nov): R49 wins over anything below - a sector's %, weight, breadth and rank come from ALL listed shares of the sector (NSE index or a free-float basket of every listed share), never from the F&O names alone. Labels like 'GIR basket n=5' must become e.g. 'all 14 listed · F&O 5'.**

# GIR v3 - TABLE CONFERENCE (binding, 19 Nov) - designers, 8 experts, 3 judges

The trader: "Instead of circling around, take a table conference and tell them what is expected. Quality first, keep 3 rounds."
Where this file settles a point, it wins over earlier votes, panel notes and designer claims. Nobody reopens a settled point.
Inputs read: votes_so_far.json (all 23 pages, every panel and judge vote), REQUIREMENTS R01-R47, SHELL.md, latest screenshots.

## 0. Why we circled (the diagnosis)
1. Pages were judged against IDs that belong to other pages (R20, R42, R43, R11 failed on Health, Help, Calendar, Reference).
2. Completeness and calm pulled in opposite directions with no rule, so designers packed everything in and then got failed for walls.
3. Each page copied a different shell, and some patched it locally, so 15 pages failed R01 / R02 / R03 for shell drift they did not cause.
4. No single illustrative day existed. TITAN was −2.48 / −2.94 / −3.10 %, charges were ₹840 / ₹420 / ₹190, and positions were open on one page and closed on another.
5. The late IDs R44-R47 arrived after most pages were built, and pages already approved were never told what still applied.

## 1. THE SHARED STANDARD - what "approved" means
**1.1 Vote rule.** A judge approves a page when it has **zero blockers** and the judge scores it **≥ 8.5**. A page passes with 3 of 3 approvals.
Blockers are only these: (a) clipped, overlapping or half-sliced text at 1600x900 or 1366x768; (b) a FIRST-VIEW ID (table 1.6) is missing;
(c) a number contradicts the canonical day (section 4) or its own arithmetic; (d) the shell is not the current build.js output;
(e) a news box on a non-news page (R44); (f) colour or font minimums broken (1.3 / 1.4); (g) a contradiction between two places
on the page (for example a GET READY headline over a strike the card blocks). Everything else is a **polish note**, at most 3 per judge.
Polish notes never block a page.
**1.2 No moving goalposts.** In round 2 a judge raises nothing new except a blocker. In round 3 only the blockers from round 2 are re-checked.
Expert panels are advisory. Their points reach a designer only through this file. **Shell items never count against a page.** They go
to the shell owner's list (section 2, item S).
**1.3 Calm vs complete (R45 vs the checklist).**
- FIRST VIEW = what shows at the size under test with no click. ONE CLICK = one labelled tab, chip, ▼ more, drawer, Space or F-key from the first view.
- Every page opens with a **hero**: the page's one answer in 18-22 px (a decision, a number or a verdict), at the top, readable in 3 seconds.
- At 1600: at most **6 panels** besides the hero band. Each list shows **≥ 5 whole rows** (≥ 3 at 1366). If a list cannot show that many, it becomes a tab or a drawer.
- First-view tables have **≤ 8 columns**. Extra columns (γ, vega, IVR, charges, the other expiry) go behind a labelled "all columns ›" click.
- No cell holds more than 2 lines of prose. A plan is a row of tokens (trigger · stop · target · lot · max loss), not a paragraph.
- 1366 never hides a fact with `display:none` and no cue. It shows fewer ROWS, not fewer FACTS, in the hero. Anything moved goes behind a visible chip.
**1.4 Type minimums** (both sizes; phone: 13 px for everything).
- 11 px: caps labels, ages, units, kbd and footnotes only. Never a number he acts on.
- 12 px: chip text and secondary numbers (12 px numbers are allowed in tables at 1366 only).
- 13 px: body text and numbers in tables.
- **14-16 px: every share name and its %** (R06). 18-22 px: the hero line. 24-28 px: the hero number (P&L, NOW on a position).
- Numbers are mono, tabular, right-aligned and decimal-aligned. A sign never leaves its number (nowrap on every ₹ and equation).
**1.5 Colour (R46) - fixed meanings. The checker tests for all of them.**
| thing | colour | | thing | colour |
|---|---|---|---|---|
| up / CE chip / profit | `--up` green, bold | | down / PE chip / loss | `--down` red, bold |
| LB long build-up | green fill tint .22 + green text | | SB short build-up | red fill tint .22 + red text |
| SC short covering | green OUTLINE (light green) | | LU long unwinding | red OUTLINE (light red) |
| GO NOW | strong amber FILL, dark ink (one per screen) | | GET READY | amber OUTLINE + .09 tint |
| BOOK / TRAIL on his trade | amber outline + word | | EXIT / STOP / NEAR STOP on his trade | `--danger` fill + word |
| LEADER | cyan #36C5D0 outline + tint | | DEPENDENT | lavender #B79CFF outline + tint |
| LAGGARD | pink #EE8AC0 outline + tint | | CATCH-DOWN / CATCH-UP | ▼ red / ▲ green suffix on the LAGGARD tag |
| HELD (his position) | white filled chip "HELD" | | BASKET / POLICY SHOCK, news, info | `--info` blue outline + word (NOT amber) |
| stale / blocked | grey + stripes + word | | replay | violet, replay page only |
- Heat rows: row background `--up-bg` / `--down-bg` at alpha 0.06 + 0.06 per 1 % move (max 0.24), plus a 4 px % bar from the centre line.
- Panel headers carry a 3 px left accent: blue = market data, amber = GIR calls (only while a call is live), white = his trades or risk, grey = system.
- Every page has **≥ 1 picture where a picture is faster** (section 3 names it per page). Tinted area stays under about 20 % of the page. Amber is never decoration.
- Light theme: shell tokens get a `[data-theme=light]` set (shell owner). Settings offers Dark / Light / Auto. Only Settings shows a light specimen.
**1.6 Which IDs the checker tests on which page.** The shell IDs (R01 R02 R03 R04 R10 R35) are checked ONCE on the shell, then on each page only as
"shell = current build". Every page is tested for R05 R06 R08 R09 R44 R45 R46 R47 and a one-line R41 hand-off bar. Below, F = first view and
C = one click is enough (the clicked state must appear in a delivered screenshot). **Any ID not listed for a page is N/A there; failing a page for it is void.**
A call shown as a one-line row with a link to its card is not a "call card". R14 applies only where a full card is drawn.
| page | F (first view) | C (one click) |
|---|---|---|
| morning | R29 TODAY plan, R18 drivers + global cues, R13, R34 (09:04 specimen) | R23/R24 18-Nov movers + build-up counts, R28, R19, R20 pending policy, R42 for the top watch |
| desk-hunt | R11, R12, R13, R14 GO NOW card, R17 (≥ 5 rows), R22, R32, R36, R07 | R42 (Space), R15 in ACTION, R16 Ask drawer, R19 line → F3, R23 tab |
| desk-trade | R30 his positions, R15, R07 exit line, R12 | R42 next slot, R17, R11, R26 |
| plan-card | R42, R14, R07, R12, R13 | R43, R27 one-line OI, R10 note |
| sectors | R22, R32, R23, R11, R36, heat map | R24, R25 inside the accordion, R13, R20 card when live |
| rotation | R19, R20 when live | R11, R42 for the pick |
| news | R37, R20, R21 (R44 does not apply here) | R14 card in the drawer |
| positions | R30, R15, R07, R12 | R42 next slot, R43 IV since entry, R26 |
| share | R07, R11 role, R13, R14, chart | R27, R25, R42, R43, R24, the share's stories (≤ 5 one-liners) |
| analyst | R16, R14 latest, R15 | R17, R38 cost per call |
| chain | R27, R42, R43 | R14, R12 |
| futures-oi | R24, R25, R26, R23 | R27 link, R20 via BIG MONEY |
| world | R18, R11 driver → share | R20, R21 |
| calendar | R28, R43 (event / IV-crush / expiry rules), R20 Parliament / policy pipeline | R29 tomorrow |
| journal | R30 journal, R41 review | R42 strike review, R15 review |
| reference | lots, sectors map, R20 baskets, aliases | R18 theme map |
| scorecard | R38 audit, misses | cost by model, R15 rule record |
| health | R39 | R10 delivery, R38 AI spend |
| replay | R41 a past day minute by minute | R14 calls as issued |
| settings | his rules, limits, R10, R46 theme switch | Telegram, the charges table |
| help | R31, R06 colour legend, R03 keys, "Where is…" line | every page's purpose |
| phone | R40, R01 compact, R02 line, the GO NOW card, his exits | R23/R24 MOVERS + BUILD-UP sheet |
| market | R33 chart with controls, R43 index options | R23 index movers |
**1.7 Evidence.** A designer's claim counts only if a delivered screenshot shows it. Every delivery includes the shot.js report at both sizes
(zero overlaps, zero clipped text), a drawn state for every C item claimed, and one line per applicable ID: "ID - where".

## 2. COMMON FAILURES - one agreed fix each
1. **Shell drift.** Pages copy the shell from `shellwork/build.js` output at build time. Page-scoped "SHELL 1366 FIX" blocks are deleted.
   The checker diffs the three bands against shell.html and allows only the section 6 state values to differ.
2. **Invisible scrollbars** (headless hides them). Use a DRAWN `.vsb` (10 px track `--line`, thumb `--text-3`, ≥ 3:1 contrast) plus ▲▼
   buttons and a "1-8 of 25" count, as on the scorecard r2 (accepted by all three judges).
3. **Sliced rows and fades over text.** Panel bodies snap to whole rows. The last slot is a bar "▼ 4 more: KEI · HAVELLS · …" that names
   what is hidden. Fades only over empty space. Hatching means stale or blocked only, never "more".
4. **The decision below the fold.** Card order: verdict line → trigger / stop / target (premium AND share) → THE VOTE → gate chips
   (spread, depth, IV/20d, MWPL, lock room, data age) → hold rule. Detail goes after that, behind ▼.
5. **Walls of numbers.** The strike chooser in first view = one expiry (Dec), 3 rows (ITM / ATM / OTM, GIR's pick ★), 8 columns: bid/ask,
   spread (₹/lot · ticks), depth, Δ, θ ₹/h per lot, IV/20d, OI chg, cash. Then "all columns · Nov ›".
6. **All grey.** Apply 1.5. The checker looks for coloured role tags, build-up chips, CE/PE chips, heat rows and the page's picture.
7. **News boxes outside F4.** A "why" line = time · source · headline, one line, attached to the call, share or position it explains. On a share page,
   that share's stories are one click away (≤ 5 rows). Morning shows overnight EVENTS as data rows (event · actual vs consensus · effect, ≤ 5).
8. **Numbers that disagree between pages.** Use section 4 only. Derive any other number from it with the formulas below, and show the formula in a tooltip.
9. **Arithmetic.** Vote = "n of N agree", where N = voters who voted (agents 1-3, news, money). The auditor checks and does not vote. "?" means did not vote.
   1R = ₹5,000. R:R is after costs. Break-even = "share pts needed by 15:10" (with the unit). θ in ₹ per hour per lot.
   Premiums agree with IV (ATM ≈ 0.4 × S × IV × √(days/365)).
10. **Costs.** Charges = statutory (one charges table, dated in Settings). Costs = charges + an estimated exit slippage allowance, always split.
    Example: "costs ₹420 = charges ₹125 + slippage ₹295". Open P&L is valued at bid less estimated exit costs. Realised P&L uses actual fills and charges.
11. **Half size on one lot.** Never write "half". Write "1 lot (minimum) = 0.4R, about half normal risk".
12. **Kite exit.** One order: "MODIFY SL-L → LIMIT bid − 1 tick" (fallback: 1) CANCEL 2) SELL). Never "sell then cancel".
    Show the SL-L trigger AND its limit.
13. **Lock check on every new idea.** "lock room ₹1,980 (if all stops hit) vs this max loss ₹X → n lots". If it is 0, the headline says
    BLOCKED · lock room (a hard block, R12) and not GET READY. "trade 3 of 3 = your last" is shown on the card.
14. **Timestamps later than the clock.** Nothing on a page is stamped after the shell clock. The checker greps for it.
15. **The trader's question** ("where are OI build-up and F&O movers?"). F&O MOVERS (UP / DOWN / ALL) live on F2 Sectors.
    The BUILD-UP list (LB / SB / SC / LU with counts) lives on F10. Every build-up tag on any page links to its F10 filter.
    Help gets a "Where is…" line. The phone gets a MOVERS + BUILD-UP sheet.
16. **Words.** "MWPL 86 % · ban at 95 % · in ban: close only". Hard blocks are exactly ban, loss lock and stale data. Expiry: Nov = Mon 23 Nov
    (Tue 24 holiday), Dec = Tue 29 Dec, default month = Dec. A Nov strike carries "PHYSICAL · exit ITM before expiry day".
    NIFTY lot 65, BANKNIFTY lot 30. "GO NOW" is used only for a call, never for a rotation state (write "ROT CONFIRMED 16m").
**S. Shell owner (one build.js change, then every page rebuilds):**
- P&L: "realised ₹0 · open −₹650 net of ₹840 costs" (tooltip: charges ₹211 + est. exit slippage ₹629). At 1366: "real ₹0 · open −₹650 · costs ₹840".
- "at share stops −₹8,020" (tooltip: at the Kite backstops −₹9,090). Week and month come from section 4. Fix the 1366 clip of "P1 0 · P2 1" and of the "/" placeholder.
- One footer health wording. Light tokens. Close state = section 4 S5. The "/" specimen keeps TITAN −2.48 % (correct at 11:40:30).

## 3. PUNCH LIST PER PAGE (most important first; ✓ = approved earlier, needs only these items)
**morning** (S1; r2 1 of 2 approved) - 1. Global cues row: S&P / Nasdaq / Dow close, US 10y, DXY, Nikkei / Kospi, COMEX gold −1.58 % overnight (FOMC).
2. 18 Nov F&O MOVERS (top 5 up / down) and BUILD-UP counts LB / SB / SC / LU linked to F10. The 09:04 PRE-OPEN chips UP / DOWN / ALL must work.
3. Coloured build-up tag and role tag on every watch row. One gold-bet chip across TITAN / MANAPPURAM / KALYANKJIL / MUTHOOTFIN ("1 gold PE max").
4. Prev closes and the 18 Nov record from section 4. Recheck the max-loss arithmetic. 5. At 1366, ≥ 3 whole watch rows. The BASKET pin becomes one line. Picture: driver heat board.
**desk-hunt** (S2; r2 ✓ / ✗ / ✗) - 1. Delete the NEWS panel (R44). Give the space to ACTION (≥ 5 rows at 1600, ≥ 3 at 1366, with the TITAN bounce GET READY and the FOLLOW-UP).
2. Strike chooser per fix 5. 3. Colour: role tags, LB / SB chips, red PE chip, heat rows and % bars in SECTORS and MOVERS. 4. Rebuild the shell.
Drop the 11:42 shock specimen (it lives on Sectors, Rotation and News). 5. Section 4 values: MANAPPURAM 286.10 −1.75 %, KALYANKJIL 530.30 +0.42 % → PUT 525 Dec,
MUTHOOTFIN 2,137.60, "Flat · 0 used, 3 left". 6. GO NOW card at 1366: one-line scroll hint, and keep "orders only in Kite · AI $0.04 · one chime".
Picture: a premium pane under the share chart (option mid with a bid/ask band).
**desk-trade** ✓ (r2 3 of 3) - 1. % values from section 4: TITAN −2.48 (not −2.94), MANAPPURAM −2.30, MUTHOOTFIN −1.95, KALYANKJIL −0.62. Metals breadth = "below VWAP 8/11".
2. Keyholes: the position cards collapse to a 4-line summary, with detail on ▼. ACTION shows a whole card. 3. MANAPPURAM θ ≈ −₹110/h per lot. IV "now · at entry".
Vote arithmetic per fix 9. 4. Colour per 1.5. Picture: a P&L-since-entry sparkline per position. 5. Rebuild the shell.
**plan-card** ✓ (r2 3 of 3) - 1. Keep every number. Relabel "₹420.04" as "costs ₹420 = charges ₹125 + slippage ₹295".
2. Role strip under the sector header: TITAN LEADER SB · MANAPPURAM DEP SB · KALYANKJIL LAGGARD LB · MUTHOOTFIN DEP SB. 3. Chooser per fix 5.
Checks as chips, not a paragraph. 4. At 1366, TITAN on one line with its NOW quote 135.40/135.95. 5. Picture: IV gauge (37.1 vs 20d 33.7, rank 34).
**sectors** (S4; r1 ✓ / ✓ / ✗) - 1. Make the heat map the hero picture (tinted sector rows plus % bars).
2. Basket timeline from section 4, and nothing after 11:42:40. Label the columns "52 s % / day %". 3. Jewellers gets its own % (not the copper −1.84 copy).
Copper "−0.92 % now (low −1.81 % 10:12)". 4. "GO NOW 16m PHARMA" → "ROT CONFIRMED 16m". 5. TITAN premium 135.40/135.95, "1 lot (minimum)", the lock-room line.
6. Whole rows plus .vsb. At 1366 keep the purpose line and the chips "my sectors" and "policy".
**rotation** (S4; r1 ✓ / ✓ / ✗, panel 4-4.5) - 1. Hero picture = the flow OUT → IN (arrows sized by ₹ cr) for the chosen window.
2. WINDOWS table ranked BY THAT WINDOW with ≥ 8 rows. The open accordion is capped at 4 rows. Label "today rank" and "window rank" separately.
3. The BASKET SHOCK card goes in the first view while it is live (section 4 timeline). 4. The pick shows fix 13 and "trade 3 of 3". A priced KALYANKJIL 525 PE row is visible at 1366.
5. Jewellers name on one line. Replace the "O" keycap glyph that reads as zero.
**news** (S4; r1 ✓ / ✓ / ✗) - 1. Rebuild the shell. Delete the page fix and the stray space in "−₹650 ,". 2. Drawer: the call card on top, the story under it.
3. Roles only from 1.5: "HINDALCO DEP · HELD". A lock-gate figure per row (fix 13). 4. Link the live story to the 18 Nov 17:32 SEBI MTF paper (comments to 28 Nov).
Show the CDSL "no communication from SEBI" line. 5. Colour: ▲▼ by direction, weight dots, blue POLICY chips, repeats folded ×n. Vote per fix 9.
**positions** ✓ (r1 3 of 3, predates R44-47) - 1. Week and month from section 4 (−₹4,755). The 18 Nov loss is at 11:31 (not 13:05). NEXT SLOT: "opens only after an exit".
2. Calm: each card shows 4 lines first (NOW vs STOP, P&L, GIR says, Kite line). The P&L split and greeks go behind ▼. Whole rows, .vsb.
3. Colour + picture: a P&L curve per position, ROOM bar, IV in → now gauge, coloured roles. 4. MANAPPURAM θ per fix 9. Fix the orphaned "= −" wraps.
**share** (S3; r2 senior ✓, r1 ✓ / ✗, panel 3.5-4) - 1. TITAN 3,400 PE = 135.40/135.95 at IV 31.4 % (not 104.60). R = ₹5,000 everywhere.
SB chip: "SB Dec · Nov roll". 2. In the call card's first view: THE VOTE, gate chips, the hard-blocks line, fix 13, "trade 3 of 3".
3. Overlaps: the "LH 3,414" label on the TRIG line, the news item escaping its card, the 1366 strike label over the ask. One name: TRIG.
4. Stories: one why line, plus "stories ›" (≤ 5). FUT row label "chg %". 5. Use the section 4 trigger wording (bounce, then a 5-min close < 3,414).
**analyst** (S4 11:44:20; r1 ✓ / ✓ / ✗) - 1. Rebuild the shell. 1366: the feed time column must not be cut, and the Metals filter must not wrap. 2. P&L from section 4 (at share stops −₹8,020, not −₹4,030).
3. Filter counts count calls only. The locked specimen agrees with itself (the banner and the strip). 4. Colour the decision tiles (EXIT danger, BOOK amber, GET READY outline).
Draw the Ask drawer. 5. WHY title ANGELONE as a link. Explain the TEAM column.
**calendar** (S4; r1 ✗ ✗ ✗ ✗) - 1. Rebuild the shell. 2. Replace the LIVE CALL card with ONE line: "LIVE: GET READY ANGELONE PUT 2,300 · BLOCKED lock room · F8 ›".
(R14 / R42 are N/A here, and this closes 6 conditions.) 3. Pin DROVE TODAY (FOMC → gold → the 4 shares) on top. ≥ 3 event rows at 1366.
Policy pipeline: 9 bodies as one-line rows, with only SEBI open. 4. Results: "season over (Q2 by 14 Nov, LODR) · next ~8 Jan". Remove the impossible Q2/Q3 dates.
5. BAN row: the 3 hard blocks, and MANAPPURAM 86 % "can close, cannot add" visible. 6. SEBI MTF: "paper open to 28 Nov (CONFIRMED)" and today's
"sources say" as separate rows. Picture: an event timeline with impact chips.
**help** (r1 ✓ / ✓ / ✗) - 1. Rebuild the shell at S4. 2. First-view "Where is…" line (fix 15). Find matches: build up, buildup, oi build, gainers, losers, top movers.
3. COLOURS tab = table 1.5 (build-up and role swatches, light theme). 4. Specimen call card at full height at both sizes. Vote "which five". Max loss = (13.25 − 12.10) × 3,000 + 420.
5. WORDS shows ≥ 5 rows.
**chain** ✓ (r1 3 of 3) - 1. ANGELONE 2,296.50 (not 2,386.40). Basket times from section 4 (first move 11:41:56). 2. Pictures: OI bars by strike (CE green and PE red,
mirrored), with build-up words (WRITING / UNWIND / COVER / BUYING) in the 1.5 colours. 3. Bottom row: OI SCENARIOS and UNUSUAL as 3 one-line rows each.
At 1366, YOUR TRADE not cut. 4. "1R" only means ₹5,000. Backstop risk = "max loss at backstop". Show the share-stop AND the backstop figure.
**futures-oi** (S4 11:44:20; r2 ✓ / ✓ / ✗) - 1. 1366: "lock room ₹1,980" overflows its box. Write a full purpose line. Label the build-up counts (ALL 222 vs "+20 more").
2. Values from section 4: MANAPPURAM 284.50 −2.30 %, bid 14.20 (not 9.80); HINDALCO bid 14.50; KALYANKJIL 524.80; MUTHOOTFIN 2,155.60; ANGELONE 2,296.50;
TITAN stop 3,436; alarm 11:42:08; analyst 11:42:38. 3. Put FOR YOUR OPTION above FUTURES BY MONTH. Add an LTP column. Use costs wording (fix 10). One source-count wording.
**world** (S4; r1 ✓ / ✓ / ✗) - 1. Rebuild the shell. 2. Hero picture: all 16 drivers as a one-row-each heat grid. Split COMEX $ / MCX ₹ for gold and silver. Make the crude theme visible.
3. SHOCK chips in blue (not amber). 4. ANGELONE headline: "0 lots · lock room ₹1,980 < max loss" at both sizes, with cost = ask × lot 250. 5. "IN10y" label at both sizes. Fix the HAVELLS half row. "1 lot (minimum)".
**journal** (S5; r1 ✓ / ✓ / ✗) - 1. Exits at 11:45:05 / 11:45:12. Cooling 11:45 → 12:05. ANGELONE not taken: "lock room (hard block), then cooling".
2. TITAN trade 128.60 → 160.00. IV split to 2 decimals. The leak equation sums. Vote ticks = count. "47 of 50 notes ✓ · 3 pending". Stamp duty by formula.
3. Day review: ≥ 3 NOT TAKEN rows visible at both sizes, no sliced text. 4. Pictures: the day's P&L curve and the week equity bars.
**reference** (r1 ✓ / ✗ / ✗) - 1. Contracts-log column overlap. 1366 column gaps 6-8 px. STEP / DEPTH: behind "all columns ›", never hidden silently.
2. "▲ n above" strip in scrolled states. Draw open Tata group (TMPV) and IRDAI members truthfully. 3. Baskets ordered by today's relevance: SEBI brokers (live), RBI gold loans.
4. "next weekly Mon 23 Nov (Tue 24 holiday)". Lots NIFTY 65 / BANKNIFTY 30. SEBI line "price led the news by 35 s". 5. Coloured sector swatches.
**scorecard** ✓ (r2 3 of 3) - 1. Section 4 S5: verdict +₹5,387 (+1.08R), not +₹4,355. Log rows +₹2,725 / −₹2,746 / +₹5,408 net of charges ₹298.
HINDALCO out 14.50. TITAN 128.60 → 160.00. 2. Exits 11:45:05 / 11:45:12. Cooling to 12:05. ANGELONE suppressed by the lock room. 3. θ paid ≈ ₹60, not ₹515.
4. Pictures: a TIMING latency waterfall bar and coloured verdict chips. 5. 1366: column gap, full purpose line, a named end cue, the Telegram ✓.
**health** (S4 11:44:20; r1 ✓ / ✓ / ✗) - 1. The un-acted own exit goes first in the verdict and first in EXCEPTIONS ("EXIT HINDALCO acked 11:39:52, not done · P1 call 11:44:40"),
with a "holding on purpose: reason" override. 2. Verdict counts = rows. No group head alone at a panel bottom. Gutter for the latency column.
3. Delete the page shell fix. 4. Hero verdict sentence 20 px. Status tiles in colour with words, plus a heartbeat sparkline. 5. T-bill date Wed 11 Nov.
**replay** (18 Nov + S5 "REAL TODAY"; r1 ✓ / ✓ / ✗) - 1. PRACTICE hides the future (tiles, proof column, close %). 2. 18 Nov = the Journal record (section 4). SEBI times as in the Journal.
TITAN is 18 Nov's biggest faller (TITAN −5.30 % > ANGELONE). 3. Lanes scaled to the visible window. % as of the clock. Strip "18 NOV (replayed)" in violet. AI $ marked "today".
4. One costs model. 2,450 = ATM. "paper sim: 3 of 3". At 1366, ≥ 3 feed rows.
**settings** (S4 + 16:20 evening; r1 ✓ / ✗ / ✗) - 1. APPEARANCE: Dark / Light / Auto, plus one light-theme screenshot. 2. Coloured group heads (LOCK red, GATE amber, TONES blue).
3. One charges table (STT per Finance Act 2026, verified date) plus a slippage-allowance row. NIFTY 65 / BANKNIFTY 30. 4. Evening: close-state shell, and stamps "as of close".
The ring log matches section 4. 5. A rule for SL-L limit gaps that would breach the lock. Plain whole rows instead of hatched gaps. Sticky heads must not cover labels.
**phone** (S3; r1 ✗ ✗ ✗) - 1. MOVERS + BUILD-UP sheet (chips LB / SB / SC / LU with counts), reached from the CALL theme line and the MARKET sheet.
2. 13 px minimum (.m-nm, EXP / BAN chips, role tags). 3. One stop basis on NOW / RISK / CALL. Costs wording. MWPL 86 % on the NOW card. CALL agrees with the analyst.
4. Whole rows and a visible bar. A purpose line on CALL. Build-up colours.
**market** (S4 11:42:40; r1 ✗ ✗ ✗) - 1. The chart is the hero: price pane ≥ 300 px high at 1366, with TradingView-like controls (1m/5m/15m, VWAP, OR, levels, draw, compare BANKNIFTY).
2. A headline blocked by the lock says BLOCKED (fix 13). MANAPPURAM "BOOK (1 lot)". 3. 1366: no hidden blocks. THEME on one line, so MOVERS ≥ 5 and TAPE ≥ 5 rows.
Pin the ROTATION footer. 4. Share names 14 px. Vote per fix 9. WHO MOVES sums (others −105.8). NIFTY lot 65. No ET 11:42:44 on an 11:42:40 page.

## 4. THE ONE ILLUSTRATIVE DAY - Thu 19 Nov 2026 (every page uses these; anything else is derived)
**States (the shell clock decides which):** S1 PREP 08:52:10 (morning; pre-open specimen 09:04) · S2 HUNT 10:05:12 (desk-hunt, plan-card) ·
S3 IN TRADE 11:40:30 (desk-trade, positions, share, phone) · S4 SHOCK 11:42:40-11:44:20, positions STILL OPEN (sectors, rotation, news, world,
calendar, chain, futures-oi, analyst, health, settings, reference, help, market) · S5 CLOSE 15:46:10 (scorecard, journal, replay REAL TODAY).
**Market at 11:40:30 (S3 = S4):** NIFTY 24,486.20 −152.76 −0.62 % · BANKNIFTY 52,140.50 −0.21 % · SENSEX 80,412.65 −0.58 % · FINNIFTY 23,905.40 · MIDCPNIFTY 12,640.15 −1.03 % ·
VIX 14.82 +2.84 % · GIFT 24,530.5 (+44) · USD/INR 88.94 · Brent 63.84 −1.10 % · MCX gold 1,24,610 −1.62 % (COMEX −1.58 %) · copper −0.92 % now, low −1.81 % at 10:12 ·
FII −1,842 / DII +1,315 (18 Nov prov) · FII idx fut −2,110 · stk fut +640 · PCR 0.92 / 1.08 (11:39) · A/D 61 / 157 of 222 · BAN 2, > 85 % 3 (incl. MANAPPURAM 86 %).
Close: NIFTY 24,431.95 −0.84 % · BANKNIFTY 52,078.40 · SENSEX 80,212.30 · VIX 14.95 · PCR 0.88 / 1.04 · A/D 54 / 165.
**Shares** (prev close → 10:05 → 11:40 = S4 → close):
| share | role | prev | 10:05 | 11:40 / S4 | close | option used |
|---|---|---|---|---|---|---|
| TITAN | LEADER SB, EXTENDED, day's biggest F&O faller | 3,484.60 | 3,376.60 −3.10 % | 3,398.20 −2.48 % (VWAP 3,421) | −4.62 % | 3,400 PE Dec 135.40/135.95 at 11:40 (IV 31.4 %), lot 175 |
| MANAPPURAM | DEPENDENT SB, HELD | 291.20 | 286.10 −1.75 % (trigger 287.00 crossed 10:02:58) | 284.50 −2.30 % | - | 285 PE Dec, lot 3,000 |
| MUTHOOTFIN | DEPENDENT SB | 2,198.50 | 2,137.60 −2.77 % | 2,155.60 −1.95 % | - | (same driver: no 2nd gold PE) |
| KALYANKJIL | LAGGARD LB → CATCH-DOWN | 528.10 | 530.30 +0.42 % (VWAP 528.40) | 524.80 −0.62 % (trigger 5-min < 521.60) | - | 525 PE Dec (520 too wide, 1.7 %), lot 1,350 |
| HINDALCO | DEPENDENT (copper), HELD | 692.40 | - | 684.70 −1.11 % (stop 686.10) | - | 680 PE Dec, lot 1,400 |
| ANGELONE | LEADER of BROKERS basket | 2,345.70 | - | 2,296.50 −2.10 % (52 s move −2.4) | −4.31 % | 2,300 PE Dec 118.40/119.30, lot 250 |
Pharma (CE side): SUNPHARMA 1,806.40 +1.42 % LEADER LB · DIVISLAB 5,960 −0.20 % LAGGARD (catch-up) · LUPIN 2,100 CE watch · CIPLA dropped. Rotation 30M: out of IT and AUTO, into PHARMA.
**His trades (R = ₹5,000; loss lock ₹10,000):**
- #48 MANAPPURAM 285 PE: GO NOW 10:05:00, in 10:06 at 13.25 (share 286.40). Share stop 288.60 (premium ≈12.07 → −₹3,960 net). Backstop SL-L 11.90 / lim 11.40.
  T1 16.20 / 280.30 (before the 280 put wall). 11:40:30 bid 14.20 → **+₹2,430 net of ₹420 costs**. BOOK (stalled) 11:40:12. Out **11:45:12 at 14.20 → +₹2,725** (charges ₹125).
- #49 HINDALCO 680 PE: in 11:02 at 16.40 (share 680.90). Stop 686.10 (≈13.80 → −₹4,060). 11:40:30 bid 14.50 → **−₹3,080 net of ₹420 costs**. EXIT 11:39:40, acked 11:39:52,
  not done → P1 call 11:44:40 → out **11:45:05 at 14.50 → −₹2,746** (charges ₹86). Cooling 11:45 → 12:05.
- #50 TITAN 3,400 PE: GO NOW 12:29:04 (bounce to VWAP 3,421, then a 5-min close < 3,414). In 128.60. Stop 3,436 share, target 3,356 (before the 3,350 wall).
  Out 13:52 at 160.00 → **+₹5,408** (gross 5,495, charges ₹87).
- ANGELONE 2,300 PE: GET READY 11:42:38, GO NOW 11:43:05 → **SUPPRESSED (lock room ₹1,980 < max loss: 0 lots)**; after the exits, cooling → skipped. "SEBI: no decision yet" 12:40:15.
- KALYANKJIL 525 PE, SUNPHARMA 1,840 CE, DIVISLAB 6,000 CE: suppressed or skipped (paper only).
**Basket shock timeline:** first move 11:41:56 · BASKET SHOCK card 11:42:08 (+12 s, "news not found yet") · 2,300 PE burst 11:42:20 · CNBC-TV18 "SEBI mulls MTF limits -
sources" 11:42:31 (+35 s, 1st source) · GET READY ANGELONE 11:42:38 (soft tick once) · ET live blog 11:42:44 (2nd outlet, echoes CNBC) · GO NOW → suppressed 11:43:05.
**P&L strip by state:**
| state | today | breakdown | open · at share stops | trades | week | month | lock left | AI |
|---|---|---|---|---|---|---|---|---|
| S1 / S2 | ₹0 0.0R | realised ₹0 · open ₹0 | 0 · ₹0 | 0 of 3 | −₹4,105 −0.82R | +₹5,695 +1.14R | ₹10,000 | $1.20 / $2.35 |
| S3 / S4 | −₹650 −0.1R | realised ₹0 · open −₹650 net of ₹840 costs (charges ₹211 + slippage ₹629) | 2 · −₹8,020 (lock room ₹1,980) | 2 of 3 | −₹4,755 −0.95R | +₹5,045 +1.01R | ₹9,350 | $4.10 |
| S5 | +₹5,387 +1.08R | realised +₹5,387 · open ₹0 · charges ₹298 | 0 · ₹0 | 3 of 3 | +₹1,282 +0.26R | +₹11,082 +2.22R | ₹10,000 | $7.69 |
**18 Nov (Wed) record:** #46 TITAN 3,650 PE −₹1,350 · #47 ANGELONE 2,450 CE −₹3,400 (SEBI MTF story, stop 11:31) → LOCKED 11:31 (2 losses in a row). TITAN −5.30 % = 18 Nov's biggest faller.
**Rounds left:** A (now) - every page applies its punch list and section 4, and the shell owner lands S first. B - judges list blockers only.
C - only round-B blockers are re-checked, and the vote is final.
**Outlook:** positions, chain, scorecard, desk-trade and plan-card pass in A if the listed items land (they are mechanical).
Futures-oi, sectors, news, help, world, analyst, health and journal are likely to pass in A or B. Desk-hunt, morning, rotation, share, replay, reference and settings need A plus B.
Calendar, market and phone carry the most work but have a clear path by C.
