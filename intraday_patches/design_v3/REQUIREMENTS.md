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
- **R50 Sector drill-down** - the trader, 19 Nov: clicking a sector anywhere opens its F&O shares (coming up / leader / laggard /
  against / not tradable); clicking a share shows its details beside the list. Full spec: SECTOR_DRILLDOWN.md.
- **R51 Every control works, and is tested** - the trader, 19 Nov: dragging a sector list's scrollbar with the mouse did not move the
  list; only the wheel worked. Every list that scrolls inside a panel has a VISIBLE scrollbar (at least 10 px) that can be dragged
  with the mouse, clicked on the track, and moved by wheel, PageUp / PageDown / Home / End and the arrow keys. No hidden scrollbars;
  no invisible layer may catch the pointer. Before any page is approved or released, EVERY control is tested by machine (Playwright)
  and by hand: each tab, F-key, button, icon, link, chip, sector row, share name, drawer, scrollbar drag, wheel, keyboard shortcut,
  Esc and Back, at 1600x900, 1366x768 and phone. The result is a table of control / action / expected / PASS or FAIL; a page with
  any FAIL is not approved.

## H. THE PREDICTION LOOP (binding, 20 Nov) - full spec: PREDICTION_LOOP.md. Where it settles a point, it wins.
- **R52 The evening prediction** - the trader, 20 Nov: "The study, the knowledge, AI knowledge, engage the brain, everything has to
  be done together, and then it has to PREDICT: 'this will go up' the day before." At 19:45 (code check 22:45, updates 07:15 and
  09:08) GIR publishes "WILL GO UP TOMORROW (CE)" and "WILL GO DOWN TOMORROW (PE)" plus the market-day call (UP / DOWN / MIXED with
  probabilities). Code scores every F&O share on BOTH sides from the study, the knowledge files, the day's news and global cues; the
  AI explains both sides of every driver, red-teams, and may move a grade one step - it never invents a ticker, price or hit rate.
  Each line shows sector, role, why (+) and against (-), trigger (yesterday's high / low with volume 2x), cancel (price and facts),
  grade with the base rate (a % only once calibrated) and strike. Both sides always shown (a WATCH ONLY fold of 3 when a side has
  fewer than 3 above the bar). Every version is stored append-only with its time; the list freezes at 09:08. Test: a replayed night
  produces both lists, every number traces to data, every stored row has made_at and version.
- **R53 The trading-day confirmation** - the trader, 20 Nov: "When it goes up on the trading day, then you give the signal: 'Hey, I
  predicted this is going up, the sector is also going up'." A predicted share rings ONCE when its trigger is crossed with RVOL >= 2,
  its whole sector moves the same way (breadth 60%) and NIFTY agrees or is flat: "PREDICTED last evening: X up · sector Y up +1.1% ·
  NIFTY up · trigger crossed with volume 2.3x". From 09:17 for predicted shares only. The card says what must hold, when it is TOO
  LATE (half the usual move done, 1.2 ATR, or 20 min) and when it FAILED - said plainly ("I was wrong"), never flipped to the other
  side by the prediction lane. Unpredicted movers show grey "NOT PREDICTED" in the drill-down and never ring through this lane. Test:
  replay rings within 5 min of the trigger, no second ring per prediction, no opposite-side ring after FAILED.
- **R54 Live news calls** - the trader, 20 Nov: "If some news comes, you have to tell me: 'this is news, this can go up.'" Within
  about a minute of the first source: "NEWS: ... -> can go UP: A, B (sector) / can go DOWN: C", with the source, NEW or OLD, VERIFIED
  or TV ONLY, and the price rule before any GO NOW (0.3 ATR its way with volume 2x inside 10 min, sector and NIFTY not against).
  Built on NEWS_TO_SECTOR_ENGINE and EVENT_MEMORY. Never rings on a ticker-text match, a repeat, or an unverified TV item. News on a
  predicted share is merged into its card ("NEWS AGREES / AGAINST my prediction"). Test: the KEI / TITAN junk items never ring;
  first-source-to-call latency is logged for every call.
- **R55 Analyst BOTTOM / TOP calls** - the trader, 20 Nov: "If some shares in a sector are already going down and some analyst says
  this is the bottom, you should tell me: 'Hey, this is the bottom, stop.'" When a TV voice, broker or strategist calls a bottom on a
  share or sector that is already falling (or a top on one already rising): "BOTTOM CALL by ... on X - STOP: no new PE here, protect /
  book your PE" (mirror: TOP CALL, no new CE). It ALWAYS rings on his held position on the threatened side; it SUSPENDS GIR's own new
  calls on that side (at most 45 min) until the price test (higher low, VWAP reclaim, short covering, breadth turning) says CONFIRMED
  or REJECTED; it never hard-blocks him (R12) and never creates the opposite trade by itself. Every voice's hit rate vs a no-call
  control is shown with its n. Test: a replayed TV bottom call shows the card within 30 s and no fresh PE ring before the test decides.
- **R56 Scoring and the daily scorecard** - the trader, 20 Nov: "...then it has to predict... I predicted this is going up." After
  15:35 every prediction (each version), confirmation, news call, bottom / top call and suspension is scored against what happened:
  right side, tradable or not, how early, move left, wrong side, missed movers - CE and PE apart, against the day's base rate and
  naive baselines, with the AI vs the code ranking. Shrunk hit rates per source and kind feed the next evening's weights. A simple
  scorecard reaches the Desk, phone and Telegram by 15:45. Rings stay within 50 a day and 6 in 15 min; AI stays within $3-5 a day
  (hard cap $5 in code). Test: every shown item has a score row next day; the scorecard flags SIDE BIAS when one side drifts 20+
  points from the market's own side mix.
