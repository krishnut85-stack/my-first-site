# GIR v3 - the shared SHELL (every desktop page uses it verbatim)

## 0. What changed after the conference (19 Nov, CONFERENCE.md item S - binding; rebuild your page from shell.html)

1. **P&L wording.** In trade (S3 / S4): `realised ₹0 · open −₹650 net of ₹840 costs` (tooltip: costs ₹840 = charges ₹211 + est. exit
   slippage ₹629, per trade MANAPPURAM ₹125 + ₹295, HINDALCO ₹86 + ₹334). 1366: `real ₹0 · open −₹650 · costs ₹840`.
   `open 2 · at share stops −₹8,020` (tooltip: lock room ₹1,980; at the Kite backstops −₹9,090, lock room ₹910). "of ₹10,000" now lives
   only in the lock tooltip (all widths); at 1366 "loss lock" reads "lock" and the AI meter goes (the $ figure stays).
2. **Canonical day (section 4).** Week **−₹4,755 −0.95R**, month **+₹5,045 +1.01R** in S3 / S4; S1 / S2 week −₹4,105 −0.82R, month
   +₹5,695 +1.14R; S5 +₹1,282 / +₹11,082 and AI **$7.69**. Market values were already section 4 (TITAN −2.48 % in the "/" specimen stays).
   Presets: `shellwork/state.js` (`apply(top, foot, 'S2' | 'S4' | 'S5', {clock})`); S5 = `state_close19.js` (default clock 15:46:10).
3. **Colour table 1.5 as tokens + classes**, dark and light: `--lb/--sb/--sc/--lu` (+ fills), `--leader` #36C5D0, `--dep` #B79CFF,
   `--lag` #EE8AC0, `--held`, `--go`, `--up-rgb/--down-rgb` for heat rows, panel accents; classes `.sh-c` + `.sh-c-ce|pe|lb|sb|sc|lu|go|
   ready|book|exit|leader|dep|lag|held|info|stale|replay`, `.sh-heat-up|dn` (style `--m:<abs %>`), `.sh-acc-mkt|call|mine|sys` (section 3).
4. **Light theme.** `<html data-theme="light">` (or the attribute / class `th-light` on `<body>`); `data-theme="auto"` follows the OS.
   Same meanings, light values. Only Settings shows the light specimen; `v3/shell_light.png` is the shell in light.
5. **1366 clip fixed** for "P1 0 · P2 1" and the "/" placeholder: the active tab is no longer bold (the tab grid is the same width on every
   page), the "/" box may shrink to 80 px and its placeholder picks "symbol, contract, verb" / "symbol, verb" / "symbol" by its own width
   (never an ellipsis), so SOUND OFF, MUTED 9:42 and "P1 1" fit too. shot.js now checks all 22 page classes x dark / light x both sizes,
   those sound / alert states and the S2 / S4 / S5 presets: 0 cut, 0 overlap, 0 past edge.
6. **One footer health wording:** `health READY | LIMITED | DOWN · <worst item + age> · AI full | lite | off` (the Health page's words;
   "GREEN" is gone). Close: `health READY · feeds closed 15:30 · AI full`. BAN popover words per fix 16: "in ban: close only",
   "> 85 % · ban at 95 %". `shell_v3r2.html` / `.png` are rewritten as identical copies by build.js / shot.js.

Kept unchanged: geometry (162 + 22 px, main 1600 x 716 / 1366 x 584), the bands and their order, every tab / key, the 1366 drop order
otherwise, the market strip values, sounds, search, every class name a page already uses.

Files: `v3/shell.html` (the source of truth; `shell_v3r2.html` is an identical copy), `v3/shell.png` (1600 x 900), `v3/shell_1366.png`
(1366 x 768), `v3/shell_light.png` (1600 x 900, light theme). State presets: `shellwork/state.js` (S2 / S4 / S5), `shellwork/state_close19.js` (S5).
The generator is `v3/shellwork/build.js` and the screenshot / overlap check is `v3/shellwork/shot.js`. Edit the generator, never
shell.html by hand, so all 23 pages pick up the same change.
Covers REQUIREMENTS R01, R02, R03, R04, R06 (frame part), R09 (frame part), R10, R35 and the section D page list.

## 1. How a page designer uses it (five steps)

1. Copy the `<style>` block between `SHELL CSS START` and `SHELL CSS END` into your page **verbatim**, as the first CSS.
   Your own CSS comes after it. Do not redefine anything that starts with `sh-`, `--sh-`, `#sh-`, or the globals `.n`, `.up`,
   `.dn`, `kbd`, `a`, `html`, `body`.
2. Copy the markup between `SHELL TOP START` and `SHELL TOP END` (market strip, P&L strip, tab bar) and between
   `SHELL FOOTER START` and `SHELL FOOTER END` **verbatim**.
3. Set **one class** on `<body>`: `<body class="page-<slug>">`. That lights the right tab. Nothing else in the shell changes,
   except the values the brief's state asks for (clock, P&L, status: section 6).
4. Put all page content inside `<main id="page"></main>`. `main` is `position:fixed`, so `position:absolute` children are placed
   relative to its top-left corner (x 0 = page left, y 0 = just under the tab bar).
5. Do **not** copy the `#demo` layer or the `demo` body class (they show the search dropdown, the size label and the specimens
   in shell.png only).

Body classes (one per page, section D of REQUIREMENTS):

| class | lights | | class | lights |
|---|---|---|---|---|
| `page-morning` | ⇧F1 Morning | | `page-world` | ⇧F2 World |
| `page-desk-hunt` | F1 Desk | | `page-calendar` | ⇧F4 Calendar |
| `page-desk-trade` | F1 Desk | | `page-journal` | ⇧F6 Journal |
| `page-plan-card` | F1 Desk + Space Plan card | | `page-reference` | ⇧F7 Reference |
| `page-sectors` | F2 Sectors | | `page-scorecard` | ⇧F8 Scorecard |
| `page-rotation` | F3 Rotation | | `page-health` | ⇧F9 Health |
| `page-news` | F4 News | | `page-replay` | ⇧F10 Replay |
| `page-positions` | F6 My trades | | `page-settings` | Ctrl , Settings |
| `page-share` | F7 Share | | `page-help` | ? Help |
| `page-analyst` | F8 Analyst | | `page-market` | /NIFTY Market |
| `page-chain` | F9 Chain | | phone | own shell, section 9 |
| `page-futures-oi` | F10 Fut & OI | | | |

## 2. Geometry - the space you have

The shell has fixed heights and a fluid width. Nothing in it changes height at any width; at 1366 it drops items instead of
wrapping (section 5).

| Band | id | y (px) | Height | Holds |
|---|---|---|---|---|
| Market strip M1 | `#sh-mkt .sh-m1` | 0-44 | 44 | NIFTY 50, BANKNIFTY, SENSEX, FINNIFTY, MIDCPNIFTY (name + sparkline / price 15 px + change + %), INDIA VIX, GIFT NIFTY, market status + phase + time to 15:10, clock, data age |
| Market strip M2 | `#sh-mkt .sh-m2` | 44-80 | 36 | USD/INR, Brent, gold MCX, FII/DII cash, FII F&O, PCR NIFTY / BANKNIFTY, A/D F&O, expiry + sessions left + next month, BAN pill (pinned right) |
| MY F&O P&L | `#sh-pnl` | 80-110 | 30 | today ₹ and R, realised / open / costs, open n + ₹ at share stops, trades n of 3, week ₹, month ₹, loss lock ₹ left + meter, AI $ vs $20 |
| Tab bar | `#sh-tabs` | 110-162 | 52 (2 x 26) | GIR mark, F-KEY row, SHIFT + row, Settings / Help / Market / Plan card, "/" box, sound, legend, alert count |
| **Page content** | `main#page` | **162-878** | **716** | your page |
| Footer | `#sh-foot` | 878-900 | 22 | SEBI line, AI line, health dot, key hints, phone link, mockup label |

**Available for page content**

| Viewport | `main#page` | Panel area (12 px left / right, 8 px top / bottom, as v2) | Page coordinates of the panel area |
|---|---|---|---|
| **1600 x 900** | **1600 x 716** | **1576 x 700** | x 12-1588, y 170-870 (inside main: x 12, y 8) |
| **1366 x 768** | **1366 x 584** | **1342 x 568** | x 12-1354, y 170-738 |

- The v2 12-column grid still works at 1600: 12 x 124 px columns + 11 x 8 px gutters = 1576. Desk template: left 388 / centre 784 /
  right 388. At 1366 use 12 x 104.5 px columns (+ 11 x 8 px gutters = 1342) (or let the right column collapse to the 48 px rail, DESIGN_SYSTEM 2.2).
- v3 change from v2: the v2 frame was 140 px (command bar, risk bar, day line, situation strip, footer) with 760 px of content.
  The v3 shell is 184 px (162 top + 22 footer) and **the day line (thesis) and the situation / in-trade strip are no longer part of
  the shell**. The risk bar became the MY F&O P&L strip (R02) and the command bar became the market strip + tab bar. Pages that
  need the thesis line or the in-trade strip (Desk hunt / trade, Plan card, Positions, Share) draw them as the first rows of
  `main`: thesis line 24 px + situation / in-trade strip 40 px leaves **1576 x 636** for panels at 1600 (1342 x 504 at 1366).
- Overlays (drawers, the alert tray, dropdowns) live inside `main`. They never cover the three shell bands or the footer (R01 /
  R02 must stay visible). The "/" dropdown and the legend popover open downward from the tab bar into `main` for that reason.
- z-index: shell bands 50, shell popovers 60. Page content should stay below 50; page drawers 40-49.

## 3. Tokens (copied in the SHELL CSS; same meanings as v2/DESIGN_SYSTEM.md section 3)

Colour = CONFERENCE 1.5, fixed meanings, generated from ONE table in build.js (`TOK`) for both themes. Pages never redefine a token.

| Token | Dark | Light | Meaning |
|---|---|---|---|
| `--bg` / `--panel` / `--panel-2` / `--panel-3` | #0B0D10 / #12151A / #181C22 / #1E232B | #ECEFF3 / #FFFFFF / #F6F7F9 / #E3E7EC | ground / panels / shell bands / hover, active tab, chips |
| `--line` / `--line-2` | #262C35 / #323A45 | #D9DEE5 / #C3CAD4 | hairlines |
| `--text` / `--text-2` / `--text-3` | #E7EAEE / #B3BAC4 / #8E97A3 | #10141A / #3B4450 / #5A6470 | text |
| `--up` / `--up-bg` / `--up-line` / `--up-rgb` | #34C47C / .12 / .60 / 52,196,124 | #08804A / .10 / .55 / 8,128,74 | up, CE chip, profit (bold) |
| `--down` / `--down-bg` / `--down-line` / `--down-rgb` | #F2615D / .12 / .60 / 242,97,93 | #C42B27 / .09 / .55 / 196,43,39 | down, PE chip, loss (bold) |
| `--lb` + `--lb-bg` | #34C47C + fill .22 | #08804A + .16 | LB long build-up: green fill + green text |
| `--sb` + `--sb-bg` | #F2615D + fill .22 | #C42B27 + .15 | SB short build-up: red fill + red text |
| `--sc` / `--sc-ink` | #8FE3B5 / #8FE3B5 | #5FC28E / #08804A | SC short covering: light-green OUTLINE |
| `--lu` / `--lu-ink` | #FF9E9A / #FF9E9A | #EE8D89 / #C42B27 | LU long unwinding: light-red OUTLINE |
| `--go` + `--action-ink` | #F5A524 + #14110A | same | GO NOW strong amber FILL, dark ink (one per screen) |
| `--action` / `-line` / `-bg` | #F5A524 / .55 / .09 | #9A5A00 / .60 / .14 | GET READY outline + .09 tint; BOOK / TRAIL outline + word |
| `--warn` | #F5A524 | #D98A00 | meter fill 75-99 % used |
| `--danger` / `-bg` / `-ink` | #FF5A52 / .14 / #1A0806 | #CC2A22 / .09 / #FFFFFF | EXIT / STOP / NEAR STOP fill + word, BAN |
| `--leader` / `--leader-bg` | #36C5D0 / .13 | #087680 / .09 | LEADER outline + tint |
| `--dep` / `--dep-bg` | #B79CFF / .13 | #6743D6 / .08 | DEPENDENT outline + tint |
| `--lag` / `--lag-bg` | #EE8AC0 / .13 | #B2367A / .08 | LAGGARD outline + tint (CATCH-DOWN ▼ red / CATCH-UP ▲ green suffix) |
| `--held` / `--held-ink` | #E7EAEE / #0B0D10 | #10141A / #FFFFFF | HELD filled chip |
| `--info` / `-bg` / `-line` | #6CB2FF / .10 / .38 | #1763BF / .08 / .42 | info, news, BASKET / POLICY SHOCK (never amber) |
| `--stale` / `--stripe` | #6B7380 / stripes .28 | #7A828E / stripes .22 | stale / blocked only (never "more") |
| `--replay` | #9B87F5 | #6A4FD6 | Replay page only |
| `--acc-mkt` / `-call` / `-mine` / `-sys` | blue / amber / white / grey | same meanings | 3 px panel header accent: market data / live GIR call / his trades or risk / system |

Contrast (checked): every text token is >= 4.4:1 on its panel in both themes (light `--leader` 4.8:1 on white); GO NOW ink 9.2:1; EXIT ink 6.3 / 5.4:1.

**Shared colour classes** (in the SHELL CSS; use them, do not restyle them): `.sh-c` = 20 px chip, 12 px bold, plus one of
`.sh-c-ce` `.sh-c-pe` `.sh-c-lb` `.sh-c-sb` `.sh-c-sc` `.sh-c-lu` `.sh-c-go` `.sh-c-ready` `.sh-c-book` (BOOK / TRAIL) `.sh-c-exit`
(EXIT / STOP / NEAR STOP) `.sh-c-leader` `.sh-c-dep` `.sh-c-lag` (suffix `<span class="dn">▼ CATCH-DOWN</span>` / `<span class="up">▲ CATCH-UP</span>`)
`.sh-c-held` `.sh-c-info` `.sh-c-stale` `.sh-c-replay`. Heat rows: `.sh-heat-up` / `.sh-heat-dn` with `style="--m:2.48"` (absolute %) give
alpha .06 + .06 per 1 % (max .24); draw the 4 px % bar from the centre line yourself. Panel headers: `.sh-acc-mkt|call|mine|sys`.
P&L figures: `.n.up` / `.n.dn` + `font-weight:700`. Specimen: the colour table in shell.png / shell_light.png.

**Light theme:** `<html data-theme="light">` (or `data-theme="light"` / class `th-light` on `<body>`); `data-theme="auto"` follows
`prefers-color-scheme`. Settings' Dark / Light / Auto sets that attribute. A page that hard-codes a colour must give it a light value too.

Type: `--sans` = Inter, "Segoe UI", system-ui; `--mono` = "JetBrains Mono", "DejaVu Sans Mono", Consolas (both installed locally,
no downloads). Class `.n` = mono + tabular numbers + -0.02em. Sizes used by the shell: 11 px (labels in caps, ages, kbd - the
minimum), 12 px (secondary numbers, phase), 13 px (tab labels, strip values, %), 15 px (index prices, clock), 16 px (today's
P&L). Nothing in the shell is below 11 px (checked by shot.js).

Geometry: `--sh-mkt:80px; --sh-pnl:30px; --sh-tabs:52px; --sh-top:162px; --sh-foot:22px; --sh-gut:12px`. Position page bands
from these (e.g. `top:calc(var(--sh-top) + 8px)`), never from typed numbers.

Shared helpers: `.sh-lb` (11 px caps label), `.sh-age` (11 px mono age), `.sh-dot` (8 px freshness dot), `.sh-meter` (+ `.warn`),
`.sh-stale` (stale stripes on any strip item), `.sh-ban` (the red pill). Pages may reuse them read-only.

## 4. What is in each band (and why)

**R01 Market strip.** Every index tile is a link to the MARKET screen (`market.html#NIFTY` ...). Tile = name + 44 x 14 sparkline
since 09:15 (1 px `--text-2`, last-point dot, no fill) / price 15 px mono / change in points / ▲▼ and signed %. VIX up shows green
by the colour rule (price up). GIFT NIFTY shows its premium to NIFTY spot. FII / DII: in market hours yesterday's NSE provisional
cash figure ("18 Nov prov"); after ~18:00 today's provisional replaces it and yesterday's final moves to the tooltip. FII F&O =
index futures net (stock futures beside it at 1600). Flows, PCR and A/D are neutral text (not green / red: they are not price
changes). Expiry comes from the contract master: `Mon 23 Nov · 3 sessions left` (sessions incl. today) with `next 29 Dec`
above it; in expiry week the label itself is the neutral chip `EXPIRY WEEK` (tooltip: next month is the default strike month,
ITM stock options are physically settled - exit before expiry day); tooltip "moved from Tue 24 Nov (holiday)"; it links to Calendar. The status block: `OPEN` chip (PRE-OPEN / OPEN /
CLOSED), the phase word and the time to 15:10, the exchange clock 15 px, the freshness dot and the strip's data age.

**R35 BAN pill.** Small, pinned at the right end of M2: `--danger` outline + tint + the word ("BAN 2"), ">85% 3" beside it. Tap =
a popover under the pill (specimen in shell.png): each banned share with "MWPL 97% · in ban: close only" (fix 16 words; the tooltip
spells out "only close existing positions"), then the shares above 85% MWPL under "> 85% · ban at 95%" (MANAPPURAM 86%). No big ban bar anywhere.

**R02 MY F&O P&L.** The whole strip is a link to F6 MY TRADES (title chip "MY F&O P&L ›"). Today's figure is rupees net of
costs (realised + open), 16 px, with R beside it. Costs = charges (statutory, the ONE dated charges table in Settings › Charges) +
an estimated exit slippage allowance, always split (CONFERENCE fix 10). Open P&L is valued at the bid less estimated exit costs;
realised P&L uses actual fills and charges. Breakdown in trade: "realised ₹0 · open −₹650 net of ₹840 costs" (tooltip: charges ₹211 +
est. exit slippage ₹629; MANAPPURAM +₹2,430 net of ₹420 = ₹125 + ₹295, HINDALCO −₹3,080 net of ₹420 = ₹86 + ₹334); after the close
(all realised): "realised +₹5,387 · open ₹0 · charges ₹298". Then open n and "at share stops −₹8,020" (today's net if every open position
hit its SHARE stop now; tooltip: −1.6R, lock room ₹1,980, and at the Kite backstops −₹9,090, lock room ₹910); trades n of 3; week and
month in rupees (+R, net of costs, today included); loss lock = rupees left before the day lock with a meter (blue < 75 %, amber 75-99 %, at 100 % the `LOCKED until 09:00 Fri` chip replaces
the meter, `--lock` style); AI spend today vs $20 with a meter.

**R03 Tab bar - ONE list.** Row 1 "F-KEY": F1 Desk · F2 Sectors · F3 Rotation · F4 News · F5 off · F6 My trades · F7 Share · F8
Analyst · F9 Chain · F10 Fut & OI. Row 2 "SHIFT +": ⇧F1 Morning · ⇧F2 World · ⇧F3 not used · ⇧F4 Calendar · (F5 off spans both
rows) · ⇧F6 Journal · ⇧F7 Reference · ⇧F8 Scorecard · ⇧F9 Health · ⇧F10 Replay. Each F-key's Shift page sits directly under it.
Shift keycaps are **filled** (light key, dark ink, "⇧F1") under a bordered "SHIFT +" row label, plain keycaps are outlined - so
"F1" and "⇧F1" cannot be confused at a glance, and no key text appears twice. The F5 cell is striped, its key struck through:
"F5 off · reload blocked" (tooltip + Help: a reload mid-trade could drop live prices; reload = Ctrl+Shift+R, which asks first while
a position is open). The free ⇧F3 cell says "not used" so the gap is explained. Right block: `Ctrl ,` Settings · `?` Help ·
`/NIFTY` Market (no F-key: section D gives it none; also any index tile) · `Space` Plan card (a drawer on a call). Row 2: the "/"
box, SOUND ON / OFF, ♪ LEGEND, unacknowledged alerts "P1 0 · P2 1". Desk hunt / in trade are one tab (F1). The active tab = `--panel-3` + 2 px `--text` underline + `--text` label, NOT bold (conference: same grid width on every page). The phone is linked
from the footer ("phone /m"). Every tab is an `<a href="<slug>.html">`, so the 23 drawings link to each other when clicked.

**R04 Search ("/").** Typing 2+ letters opens suggestions under the box (into `main`, 480 px wide, right-aligned to the box):
header "2 F&O shares match "TIT"", one 44 px row per F&O share (symbol 15 px with the typed letters underlined, company + sector
+ lot, price, %), the first row selected; then verb chips (TITAN OC · TITAN FUT · NEWS TITAN · LOG TITAN · search news for "TIT");
footer ↑ ↓ choose · Enter open the share page · Tab complete · Esc close. Enter opens the Share page (F7) of the selected row.
Max 6 share rows; an F&O share in ban shows the BAN pill in its row. Nothing in the box ever sends an order.

**R10 Sounds.** SOUND ON / OFF toggles GO NOW and GET READY tones; MY EXIT tones cannot be muted while a position is open (the
button then reads "ON · exits locked on"). M mutes GO NOW / GET READY for 10 min (countdown replaces "ON"). ♪ LEGEND opens the
legend under the button: (1) GO NOW - one bright chime, once; (2) GET READY on a sector call - one soft low tick, once; (3) MY EXIT
(STOP · BOOK HALF · EXIT · 15:10) - two low notes, repeats every 60 s until A + Enter, own trades only. Everything else is silent;
the sound never says the direction; Replay is silent. One sound per alert (the old + new double alarm cannot happen: one player).

**Footer.** "About 9 in 10 individual F&O traders lose money (SEBI study)" (12 px, `--text-2`) · "AI-generated, personal use
only" · health in ONE wording: `health READY · worst K3 1.2s · AI full` - the word is READY / LIMITED / DOWN (the Health page's
words), then the worst item with its age (or "4 limited (K3)", "K1 c1 silent 14s", "feeds closed 15:30"), then AI full / lite / off;
dot `--info` for READY, `--stale` for LIMITED or closed, `--danger` for DOWN (links to Health) · key hints (/ search, ? help, Space plan card, Esc close,
A + Enter ack, M mute) · phone /m · "design mockup - illustrative values" (right).

## 5. The 1366 rule (also written in the shell.html comment)

Below 1500 px wide the shell never wraps and never changes height; it drops, lowest priority first:
1. index tiles drop the point change (price, % and sparkline stay);
2. the P&L breakdown is SHORTENED, not dropped: "real ₹0 · open −₹650 · costs ₹840" (after the close "real +₹5,387 · open ₹0 ·
   chg ₹298"); "loss lock" -> "lock"; the AI meter goes (the $ of $20 stays); meters 48 -> 34 px, strip items padding 7 -> 5 px,
   gap 5 -> 4 px ("of ₹10,000" is in the lock tooltip at every width since the conference build);
3. M2 SHORTENS "stk fut +640" to "stk +640" and "(Tue 24 holiday)" to "(Tue 24 hol)" (r2 sync); it drops the ">85% 3" note and
   the BAN hint "tap = list" (BAN popover / tooltip);
4. tab bar: the Plan card tab goes (Space plan card stays in the footer); tab labels 13 -> 12 px; "SOUND ON" -> speaker + "ON";
   the "/" box narrows (min 80 px; its placeholder shows "symbol, verb" or "symbol" by its own width, never an ellipsis), the dropdown
   keeps 480 px; row-2 gaps 6 -> 5 px and button padding 7 -> 5 px (room for MUTED 9:42 and "P1 1 · P2 1");
5. footer drops the "A + Enter ack" and "M mute" hints.

Never dropped: all five indices with price, % and sparkline, VIX, GIFT, USD/INR, Brent, gold, FII/DII cash, FII index AND stock futures (r2 sync), the expiry holiday note (r2 sync),
both PCRs, A/D, expiry + sessions left + next month, BAN pill, status + phase + time to 15:10 + clock + data age, every age stamp,
today's P&L ₹ + R, realised / open / costs (short form at 1366), open n + ₹ at share stops, trades n of 3, week and month ₹, rupees left before the lock, AI spend, every page
tab with its key, the F5 explanation, Settings, Help, Market, "/", sound on/off, legend, alert count, SEBI line, AI line, health
dot, phone link, mockup label. Verified: shot.js reports no element cut off, outside the viewport or overlapping at both sizes.

## 6. States designers change in the shell (values only, markup unchanged)

| State | What to change |
|---|---|
| Your page's time | `.sh-clock` text, `.sh-phase` (ENTRY / OBSERVE / LATE ENTRY / MANAGE ONLY / EXIT NOW / PREP / REVIEW) and its countdown, PCR as-of |
| S2 HUNT 10:05:12 (desk-hunt, plan-card) - `state.js` 'S2' | clock 10:05:12 · ENTRY · 5h 05m to 15:10 · today ₹0 0.0R (`--text`) · "realised ₹0 · open ₹0" (1366 "real ₹0 · open ₹0") · open 0 · at share stops ₹0 · trades 0 of 3 · week −₹4,105 −0.82R · month +₹5,695 +1.14R · lock ₹10,000 left (meter 0 %) · AI $2.35 · PCR 10:04 |
| S3 IN TRADE 11:40:30 (desk-trade, positions, share) = the shell.html default | today −₹650 −0.1R (MANAPPURAM +₹2,430 + HINDALCO −₹3,080, each net of ₹420 costs) · "realised ₹0 · open −₹650 net of ₹840 costs" (charges ₹211 + slippage ₹629) · open 2 · at share stops −₹8,020 (HINDALCO −₹4,060 + MANAPPURAM −₹3,960; lock room ₹1,980; backstops −₹9,090) · trades 2 of 3 · week −₹4,755 −0.95R · month +₹5,045 +1.01R · lock ₹9,350 left · AI $4.10 · P1 0 · P2 1 |
| S4 SHOCK 11:42:40-11:44:20 - `state.js` 'S4' {clock} | the S3 values (positions still open, section 4: S3 = S4) with your clock and its countdown (11:42:40 -> 3h 27m, 11:44:20 -> 3h 26m) |
| S1 PREP 08:52:10 (morning) | status chip `CLOSED`, phase "PREP · pre-open in 8m"; index prices = previous close in `--text-3` with "as of 15:30 18 Nov"; GIFT live; P&L as S2 (₹0, 0 of 3, week −₹4,105 −0.82R, month +₹5,695 +1.14R, lock ₹10,000); AI $1.20 |
| 09:00-09:15 | chip `PRE-OPEN`, phase "PRE-OPEN · open in 6m"; indices show the pre-open price |
| After 15:30 (scorecard 15:46) | chip `CLOSED` in `--text-3` / `--line-2`, phase "REVIEW", values `--text-3` "as of 15:30" (no stripes) |
| S5 CLOSE - after 15:30 on 19 Nov, THE day (journal, scorecard 15:46, replay "REAL TODAY", calendar / morning "yesterday") | use `shellwork/state_close19.js` (`apply(top, foot, {clock})`, default 15:46:10) or `state.js` 'S5', never hand-typed values: today **+₹5,387 +1.08R** (#48 MANAPPURAM +₹2,725 · #49 HINDALCO −₹2,746 · #50 TITAN +₹5,408) · "realised +₹5,387 · open ₹0 · charges ₹298" (₹125 + ₹86 + ₹87; 1366 "real · open · chg") · open 0 · at share stops ₹0 · trades 3 of 3 · week **+₹1,282 +0.26R** · month **+₹11,082 +2.22R** · lock ₹10,000 left, meter 0 % (last lock 18 Nov 11:31, 2 losses in a row) · AI **$7.69** · P1 0 · P2 0 · PCR 15:30 0.88 / 1.04 · A/D 54 / 165 · NIFTY 24,431.95 −0.84 % · VIX 14.95 · 2 sessions left · CLOSED · REVIEW · footer "health READY · feeds closed 15:30 · AI full" |
| Theme | `<html data-theme="light">` or `"auto"` (Settings only shows the light specimen; every page must still read in light) |
| Health | footer `health READY|LIMITED|DOWN · <worst item + age> · AI full|lite|off`, dot `--info` / `--stale` / `--danger` |
| Stale item | add `sh-stale` to that tile and put `STALE 12s` in its `.sh-age` (specimen in shell.png). Stale index with a position open: also the P&L strip's open figure gets `sh-stale` |
| Lock near / locked | `.sh-meter` gets `warn` from 75 % used; at 100 % replace the meter + "left" with the LOCKED chip (specimen) |
| Sound off | button text "SOUND OFF" (`--text-3`); muted for 10 min: "MUTED 9:42" (1366: speaker + "OFF" / "MUTED 9:42"; both fit, checked) |
| Alerts | "P1 1" in `--danger` text with the word P1; the browser title gets "● P1" |
| Replay | add a 3 px hatched `--replay` page border inside `main` and "REPLAY 18 Nov 10:42 - not live" as the status chip text; P&L strip shows the replayed day |

## 7. TRADER-1 (keys) - the shell's answer: accepted with change

ONE list from REQUIREMENTS section D, one tab bar on every page, no key shown twice, Shift pages in their own row under the same
F-key with filled ⇧ keycaps, F5 explained in the tab itself, the ⇧F3 gap labelled. Broker-terminal habit (NEST / ODIN F1 = BUY,
F2 = SELL): GIR never sends an order, so a wrong F-key in GIR can only change the page; the risk is the reverse habit in a broker
terminal. He trades through Kite (web and app), whose order keys are not F-keys, so we keep F-keys for pages and say so in ? Help.
Laptop Fn: GIR runs as an installed app window (PWA) so F-keys reach it; Help shows how to set Fn-lock; every tab is also a mouse
click and every page is reachable from "/" (e.g. `/SECTORS`). The phone has no F-keys: bottom tab bar (section 9).

## 8. Checklist - where each shell requirement is met

| ID | Where in the shell |
|---|---|
| R01 | `#sh-mkt`: M1 five indices with price, change, %, sparkline; VIX; GIFT; status + clock + data age. M2: USD/INR, Brent, gold, FII/DII cash + F&O (18 Nov prov), PCR NIFTY / BANKNIFTY, A/D, expiry + sessions left + next 29 Dec, BAN |
| R02 | `#sh-pnl`: today ₹ (realised + open, net of costs = charges + est. slippage, split) + R, open n + ₹ at share stops, trades n of 3, week ₹, month ₹, loss lock ₹ left + meter, AI $ vs $20; tap = F6 |
| R03 | `#sh-tabs`: one list, two rows, filled ⇧ keycaps, F5 explained, clickable `<a>`s, "/" command line; active tab by one body class |
| R04 | "/" box suggestions as you type (TIT -> TITAN, TITAGARH), Enter opens the share page |
| R06 | dark, one colour meaning, 11 px minimum, index prices 15 px, nothing cut off at 1600 x 900 and 1366 x 768 (shot.js), SEBI footer; each page adds its own one-line purpose at the top of `main` |
| R09 | data age in the status block, an age on every slow item (Brent 1m, PCR 11:39, FII 18 Nov), `.sh-stale` pattern |
| R10 | SOUND ON / OFF, ♪ LEGEND popover (three tones, which alerts ring), alert count |
| R35 | small red BAN pill, tap = list with "only close existing positions" |

## 9. The phone version of the strips (390 x 844 CSS px, one column, no F-keys)

Canvas per v2: OS status area y 0-44 (not ours). Type minimum 13 px, numbers mono tabular, tap targets >= 48 px (the visual element
may be smaller; its hit area is padded to 48).

**Compact market strip - y 44-100 (56 px), `--panel-2`, two lines, 12 px side padding (366 px usable).**
- Line A, 30 px: `NIFTY 24,486.20 ▼−0.62%` · `BANKNIFTY 52,140.50 ▼−0.21%` - names 12 px caps `--text-2`, prices 14 px mono 600,
  % 13 px mono green / red. Two halves of 177 px with a 12 px gap; no point change, no sparkline.
- Line B, 26 px: `SENSEX ▼−0.58%` · `VIX 14.82 ▲` · `BAN 2` pill · right-aligned `OPEN 11:40:30 ● 0.4s` (13 px; chip text
  12 px). If anything is stale, the right end shows the STALE chip instead of the age.
- Tap anywhere on the strip (48 px hit area) = full-screen sheet "MARKET": every R01 item as a list of 48 px rows (FINNIFTY,
  MIDCPNIFTY, GIFT, USD/INR, Brent, gold, FII/DII cash + F&O, PCR NIFTY / BANKNIFTY, A/D, expiry + next month, the BAN list with
  "only close existing positions"), each with its age; sparklines 64 x 20 only here. Close = a 48 px "✕" top right.

**P&L line - y 100-144 (44 px), `--panel`, 1 px `--line-2` bottom border, two lines.**
- Line 1, 24 px: `MY F&O P&L` (12 px caps) · `TODAY −₹650` (17 px mono 700, red) · `−0.1R` (13 px) · `›` at the right.
- Line 2, 18 px: `open 2 · trades 2 of 3 · lock ₹9,350 left · week −₹4,755` (13 px, `--text-2`, numbers `--text`). Month and
  AI spend live on the RISK screen. LOCKED replaces "lock ₹9,350 left" with the LOCKED chip.
- Tap = NOW (his positions and exits = MY TRADES on the phone); tap on the lock words = RISK.

**Content - y 144-780 (636 px)**, one column, scrolls inside; the two strips above never scroll away.

**Bottom tab bar - y 780-844 (64 px), `--panel-2`, 1 px `--line-2` top border.** Four tabs of 97.5 x 64 px: NOW · CALL · RISK ·
ALERTS (v2 P21). Each: a 20 px line icon above a 13 px label; active = `--text` + 2 px `--text` bar at the top of the tab,
others `--text-2`. Badges (12 px, 18 px high): NOW "2" (open positions, neutral); CALL "GO" amber outline while a GO NOW is live
(never filled); RISK "LOCKED" `--lock` style when locked; ALERTS "P1 1" `--danger` outline + word while a P1 is unacknowledged.
In the installed PWA `env(safe-area-inset-bottom)` is added under the 64 px (the mockup draws none). No "/" box on the phone (no
chain, news or charts there - v2 P21); a share name opens a read-only share card. Sounds on the phone = push notifications with the
same three tones; SOUND ON / OFF and the sound legend sit on the ALERTS screen. The SEBI line and "AI-generated, personal use only"
are on the CALL screen; "design mockup - illustrative values" at the bottom of the four-screen canvas.

## 10. What the shell adds beyond the checklist (REQUIREMENTS: "the MINIMUM, not the limit")

- **Rupees at share stops** in the P&L strip (`open 2 · at share stops −₹8,020`, Kite backstops −₹9,090 in the tooltip): an option buyer's worst case right now, next to the rupees
  left before the lock, so he sees at a glance whether both stops hitting would lock the day. It replaces v2's "open risk" in R.
- **Phase + time to 15:10** in the status block (`ENTRY · 3h 30m to 15:10`): his exit deadline is on every page, not only the Desk.
- **EXPIRY WEEK chip** on the expiry tile (R43 expiry-week rules: faster theta, next month as default, physical settlement).
- **GIFT NIFTY premium to spot**, **A/D out of the whole F&O list** ("of 222") and **ages on every slow number** (Brent 1m, PCR
  11:39, FII 18 Nov prov), so nothing looks live that is not (R09).
- **Every tab, index tile, the expiry tile, the BAN pill and the P&L strip are links**, so the drawings click through like the
  product (R05 spirit for the frame).
- **Unacknowledged alert count** "P1 0 · P2 1" beside the sound controls (a P1 is never only a sound).
- **Shift+F3 shown as "not used"** and **F5 as "off · reload blocked"** in the bar itself, so no gap is unexplained (TRADER-1).

**Footer change (the trader, 19 Nov):** the SEBI line and "AI-generated, personal use only" are REMOVED - "I don't need that. Only
the controls are required." The footer holds only the health dot and the key hints. Designer notes (size labels such as
"main#page 1600 x 716", SPECIMEN boxes, "design mockup - illustrative values") exist only on drawings, never on the real site.
