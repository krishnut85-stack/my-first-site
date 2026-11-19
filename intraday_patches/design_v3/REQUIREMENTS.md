# GIR / girtrader.com - THE REQUIREMENTS CHECKLIST (v3 redesign, 19 Nov 00:30 IST)

The trader found the v2 drawings missing things he had already asked for (SENSEX / BANKNIFTY, his F&O P&L, 8 F-key pages, the old
features). This file is the ONE checklist. Every designer lists, for every ID below that applies to the page, WHERE it is met. The
judges reject a page that misses an applicable ID. Sources it was built from (read them): GIR_SPEC.md (sections 1, 4, 5, S11, S12,
TRIAL, THE CHECKLIST), LAYOUT.md (the old layout rework), complaints_18nov.md (43 complaints), the TRADER-1..7 notes at the end of
v2/IA.md. When those files say more than this list, they win.

**This list is the MINIMUM, not the limit.** Think freely and completely, without limits: add whatever a complete, professional
options-trading terminal needs that is not written here, and say what you added and why.

## A. EVERY page (desktop pages; the phone has its own version of each)
- **R01 MARKET STRIP, always visible, identical on every page:** NIFTY 50, BANKNIFTY, SENSEX (FINNIFTY, MIDCPNIFTY if room) - price,
  change, % and a tiny sparkline; INDIA VIX; GIFT Nifty; USD/INR; Brent; gold; FII / DII cash and F&O (yesterday + provisional);
  PCR (NIFTY / BANKNIFTY); A/D of F&O shares; expiry + days left; a small red BAN pill (tap = list, "only close existing positions");
  market status (pre-open / open / closed) and live time; data age.
- **R02 MY F&O P&L, always visible on every page:** today's P&L in RUPEES (realised + open, net of all charges) and in R; open
  positions n; trades n of 3; week and month P&L in rupees; the loss lock state (how much is left before the lock). Tap = MY TRADES.
- **R03 ONE tab bar,** identical on every page, built from one list (section D), no key shown twice, Shift keys unmistakable,
  F5 = "reload off" explained, clickable with the mouse / finger, plus the "/" command line.
- **R04 Search** with suggestions as you type (2-3 letters -> matching F&O shares), Enter opens the share page.
- **R05 A share name anywhere** (cards, news, movers, analyst, BIG MONEY, alerts) is clickable and opens the Share page.
- **R06 The look:** dark; share names and % at least 14-16 px; space between rows; one colour meaning (green = up / CE, red = down /
  PE, amber = GIR action / GET READY, grey = info / stale, blue = info); NOTHING overlapping or cut off at 1600x900 AND 1366x768; no
  walls of tiny text; each page has a one-line purpose at its top; the footer holds ONLY controls (key hints, health, sound) - no warning or disclaimer lines (the trader, 19 Nov: "I dont need that. Only the controls are required").
- **R07 OPTIONS FIRST** - he buys CE / PE ~90% of the time: every call shows strike, premium, bid / ask spread, depth, IV vs 20-day,
  stop and target in premium AND in share price, lots, cost. Futures are DATA (build-up, OI by month, basis), not the trade.
- **R08 Every list scrolls** with a visible bar and up / down buttons; no list hidden behind another.
- **R09 Freshness:** every number's age; stale shows grey and blocks a call; the reason is named.
- **R10 Sounds:** one sound per alert; only GO NOW, GET READY on a sector call, and his own exits (STOP / BOOK HALF / EXIT / 15:10)
  ring; a visible sound legend and on / off.

## B. The calls and the method (GIR_SPEC section 1)
- **R11 His method on the page:** rank sectors (move + build-up + driver); in a falling sector PE on the LEADERS falling with short
  build-up, the DEPENDENTS (gold loans on gold) and the LAGGARD still up / overbought (catch-down); mirror for CE. Roles shown.
- **R12 Never a bare "NOT TRADABLE":** the reason in plain words and what to do instead (better strike, wait price). Hard block ONLY
  for ban, loss lock, stale data; everything else is a warning he can still take.
- **R13 Trend day:** an extended leader (TITAN, 18 Nov's biggest faller) stays LEADER: "EXTENDED - enter on the bounce to VWAP / first
  lower high, half size" with that price as the trigger.
- **R14 Every call card:** GO NOW / GET READY · CE / PE · share · strike · trigger · stop · target · how long to hold · "don't exit
  before the stop or the target unless GIR says EXIT" · age · source · THE VOTE ("4 of 5 agree · agents 1 ✓ 2 ✓ 3 ✗ · news ✓ ·
  money ✓ · auditor PE", weighted by hit rate, "?" for a voter that did not vote, vote-against shown).
- **R15 Follow-up on every open call:** BOOK HALF at the first target or when the move stalls, EXIT on reversal, with the reason.
  Only his own trades get EXIT messages.
- **R16 Analyst:** the latest decision in big text, on top, never blinking, never stuck on an old brief; every output ends in an
  action per share (GO NOW / GET READY / HOLD / BOOK / EXIT / nothing to do); ASK in a side drawer that pushes nothing away.
- **R17 ONE ACTION feed** of every call; chips with counts that match the list; an empty chip says why, never looks like a crash;
  noise types (EARLY "first 15 min noisy", RUNNING) hidden.
- **R18 THEME:** driver -> sector -> every share (gold, silver, steel, copper, aluminium, crude, rupee, yields), e.g. gold down ->
  TITAN, KALYANKJIL, MANAPPURAM, MUTHOOTFIN.
- **R19 ROTATION** (S11): 15M / 30M / 1H / TODAY with real details inside; money out of X into Y; GET READY / GO NOW / CANCEL with
  the age.
- **R20 BASKET SHOCK and POLICY SHOCK** (S12, ANGELONE 18 Nov): 3+ shares of a policy basket moving together -> "news not found yet";
  Parliament / Cabinet / SEBI / RBI / IRDAI / CERC news with the source and the seconds since the first source; "sources say / no
  decision yet / denial" stories.
- **R21 TV and live blogs:** management statements on TV ("not affecting us"), CNBC-TV18 / ET / Moneycontrol live-blog entries.

## C. Every OLD girtrader feature has a home (LAYOUT.md, complaints) - list where each one went
**The trader, 19 Nov: "don't go by the old layout." The old page is NOT a design to copy - its look and arrangement are
replaced by this new design. Only its FEATURES (the data and functions below) must survive, wherever they fit best.**
- **R22** Sector click opens IN PLACE (accordion) with live numbers at once; never covers F&O MOVERS.
- **R23** F&O MOVERS (UP / DOWN / ALL).
- **R24** LONG BUILD-UP: LB / SB / SC / LU filters and alerts.
- **R25** FUTURES by month (near / next / far): price, OI, OI change, basis, rollover.
- **R26** F&O MONEY, BIG MONEY, F&O TAPE.
- **R27** OI SCENARIOS and the OPTIONS / option chain per share (strike order, walls, OI change, IV, spreads).
- **R28** RESULTS (today and the calendar).
- **R29** PLAN: TOMORROW / TODAY / CHECKLIST.
- **R30** MY F&O and COCKPIT -> MY TRADES: positions, live P&L, their exits, the trade journal.
- **R31** GUIDE -> "?" help.  **R32** BOARD.  **R33** NIFTY / BANKNIFTY trading screen (chart with TradingView-like controls).
- **R34** PRE-OPEN view 09:00-09:08 that never covers or blocks the page.
- **R35** The small BAN pill (no big ban bar at the bottom).  **R36** "ALL SECTORS" filter that really filters the page.
- **R37** ONE NEWS list: time · share / MARKET / WORLD / POLICY · headline · AI ▲/▼ and weight 1-5 · source; chips ALL / MY SHARES /
  POLICY / CRITICAL / MARKET; repeats folded (×8).
- **R38** COST: AI spend today vs $20 by model; the 15:45 audit (the misses table, each agent's report, cost per useful call).
- **R39** HEALTH: every service and feed, data age, Kite keys login state, heartbeat alarms.
- **R40** PHONE (390 wide): tabs, no overlapping text, MY TRADES P&L, the GO NOW card, his exits, the market strip.

## E. THE COMPLETE OPTION-BUYER PACKAGE (the whole system is built for options trading)
- **R41 The full trade cycle, page by page:** PREPARE (morning, world, calendar) -> FIND (sectors, rotation, theme, news, basket
  shock) -> CHOOSE THE SHARE (roles) -> CHOOSE THE STRIKE AND EXPIRY -> PLAN (stop / target in premium and share price, size, cost)
  -> ENTER (the Kite line; GIR never places orders) -> MANAGE (follow-ups, trail, BOOK HALF, time stop, 15:10) -> EXIT -> JOURNAL and
  REVIEW (scorecard, misses, mistakes, rules kept). Every step has its page and the hand-off to the next is one key or click.
- **R42 Strike chooser on every call:** ATM / 1 ITM / 1 OTM (this expiry and next) side by side - premium, delta, theta per hour,
  gamma, vega, IV vs 20-day and IV rank, bid / ask spread, depth, OI and OI change, distance to the nearest wall, the share move
  needed to break even by 15:10, lot size, cash needed, charges - with GIR's pick and why.
- **R43 Options analytics:** greeks; IV, IV rank and IV crush risk before results / events; per-share PCR and max pain; OI change by
  strike; unusual option activity (sudden CE / PE bursts in one strike); expiry-week rules (faster theta, physical settlement of
  in-the-money stock options - exit before expiry day); index options (NIFTY / BANKNIFTY) for the days he trades them; margin and
  charges; a liquidity filter that suggests the better strike instead of rejecting the share.

## D. THE PAGES - every one must be drawn (keys from v2/IA.md 2.2)
| key | page | slug |
|---|---|---|
| Shift F1 | Morning & pre-flight (+ PRE-OPEN 09:00-09:08) | morning |
| F1 | Desk - hunting | desk-hunt |
| F1 | Desk - in a trade | desk-trade |
| Space on a call | Plan card | plan-card |
| F2 | Sectors (board, accordion, F&O movers) | sectors |
| F3 | Rotation | rotation |
| F4 | News (one list) | news |
| F6 | Positions & Risk = MY TRADES (P&L, exits) | positions |
| F7 | Share (chart, levels, chain, futures, news, WHY) | share |
| F8 | Analyst | analyst |
| F9 | Option chain + OI scenarios | chain |
| F10 | Futures & OI + MONEY (LB/SB/SC/LU, futures by month, F&O money, BIG MONEY, tape) | futures-oi |
| Shift F2 | World drivers + THEME | world |
| Shift F4 | Calendar (results, events, ex-dates, expiry, Parliament business) | calendar |
| Shift F6 | Journal (every trade, notes, mistakes, rules kept) | journal |
| Shift F7 | Reference (F&O list, lots, sectors map, policy baskets, aliases) | reference |
| Shift F8 | Calls & Scorecard (15:45 audit, misses, cost) | scorecard |
| Shift F9 | Health | health |
| Shift F10 | Replay (any past day, minute by minute) | replay |
| Ctrl + , | Charter & Settings (his rules, sounds, Telegram, limits) | settings |
| ? | Help (every page's purpose, keys, colours) | help |
| - | Phone (four screens) | phone |
| - | MARKET: NIFTY / BANKNIFTY trading screen | market |

## F. CLEAN AND PROFESSIONAL - the trader, 19 Nov morning (judges: reject a page that breaks this)
- **R44 No news noise.** "The old layout is mostly news noise. I want a clean and professional layout." News lives on the F4 NEWS
  page (and the phone's news tab). Other pages show news ONLY as one short "why" line on the call or share it explains (time ·
  source · headline, one line). No news tickers, no scrolling headline bands, no repeated headlines, no news boxes on the Desk.
- **R45 Calm and clean:** each page shows only what its job needs, the most important thing biggest; fewer, larger panels; space
  between rows; no wall of tiny numbers; secondary detail behind a click (expand / drawer / Why). A professional trader should read
  the page's answer in 3 seconds. Density is not completeness: everything required must be reachable, not all on screen at once.
- **R46 Colour and visual life** - the trader, 19 Nov after seeing every page: "All looks black and white." Clean must not mean
  grey. Use colour with meaning so the page reads at a glance: tinted green / red row backgrounds and bars for up / down
  (sector heat map, % bars, OI build-up colours LB green, SB red, SC light green, LU light red), CE in green and PE in red chips,
  the GO NOW card in strong amber, GET READY in softer amber, roles as coloured tags (LEADER, DEPENDENT, LAGGARD, CATCH-DOWN),
  P&L in bold green / red, coloured section headers and accents, charts, gauges and small visuals instead of plain number
  tables wherever a picture is faster (sector heat map, rotation flow arrows, IV gauge, OI bars by strike, P&L curve). Keep the
  colour meanings fixed and readable (contrast), keep it professional - Bloomberg / modern broker app, not a toy. Offer a light
  theme as well as dark in Settings.
- **R47 World-class finish** - the trader, 19 Nov morning: "The design should be such that every pixel is clean and everyone is
  surprised by the design, the information and the clean data." Judge every page as a top professional trader would on first
  sight: pixel-perfect alignment (columns line up, equal spacing, no stray borders, no clipped or overlapping text, no squeezed
  boxes), crisp typography, one consistent style across all pages, the right information in the right order, and data shown
  cleanly (aligned numbers, units, ages, no clutter). A page that is merely "complete" but not impressive is not approved.

## G. TABLE CONFERENCE (binding) - read CONFERENCE.md before designing or judging; where it settles a point, it wins.
- **R48 No wasted or untidy empty space** - the trader, 19 Nov: "All the empty spaces should be organised properly." Every panel
  fills its area cleanly: no big blank holes, no half-empty boxes next to crammed ones, no ragged panel bottoms. Panels align to
  one grid, share edges and heights, and balance across the page. Space between items is even and intentional (a breathing gap,
  not a leftover hole). If a panel has little to show, it is made smaller and the space given to the panel that needs it.
- **R49 Sector weight from the WHOLE sector** - the trader, 19 Nov: the sector's %, weight, breadth and rank come from EVERY listed
  share in the sector (official NSE sectoral index where it exists; otherwise a free-float weighted basket of all listed shares in
  that sector), NOT only its F&O shares. Pages must label the basis ("NIFTY METAL index" / "all 14 listed jewellers, free-float
  weighted"), show breadth over all shares (e.g. "breadth 11 / 14 all shares · F&O 3 / 4"), and flag "NARROW - F&O-only move" when
  only the F&O names move. Only the trade list (CE / PE plans) is limited to F&O shares.
