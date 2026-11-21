# GIR v2 - Information Architecture (the one merged product)

Written 18 Nov 2026 by the chief architect, merging ten expert visions (terminal designer, broker-app designer, UX researcher,
options trader, F&O dealer, OI analyst, research analyst, feed engineer, news/data engineer, risk coach) with GIR_SPEC.md.
Companion files: DATA.md (every data item) and DESIGN_SYSTEM.md (the look every page must follow).
Everything shown in mockups uses illustrative values only, marked "design mockup - illustrative values". No real person names.
Expert reviews are design input, not an approval by senior brokers; GIR never claims to be "approved".

---------------------------------------------------------------------------------------------------------------------------------

## 0. What GIR is, in one paragraph

GIR is a private, signal-only trading terminal for ONE trader who BUYS CE / PE on NSE stock options intraday, holds a few hours and
is flat by 15:10, using a sector-first method: find the driver that moved -> confirm the sector -> study every F&O share in it ->
pick the ones in position -> one call at a time -> give the trade time -> exit on plan. It is a **risk machine that lets signals
through**, not a signal machine with risk added on top. GIR never places, modifies or cancels an order. It prepares the order,
checks it, reads the fill back from Kite, warns, records and scores.

## 1. The ten principles every page obeys

1. **Attention order is fixed all day:** (1) is the data true and fresh, (2) my open risk = share vs its stop and the clock,
   (3) my limits, (4) a new call, (5) context. The biggest, brightest element on screen is always the highest item in that order
   that needs attention now (blur test: with a position open, the eye lands on "share now vs stop" within 2 seconds).
2. **Panels never move.** The clock phase and the day state change only emphasis (size of type, border, dimming), never position.
   Space is reserved for every value so nothing jumps when data loads. Lists never re-sort under the pointer / keyboard focus and
   otherwise at most every 30 s.
3. **Verdict on the surface, evidence one key away.** A verdict is at most ~12 words; reasons are max 2 bullets; the full case is one
   key (W = why) away, never hover-only.
4. **One meaning per signal.** One colour = one meaning, one tone = one urgency, one word = one action. CALL / PUT are words, never
   colours. Green / red only for price change and P&L (see DESIGN_SYSTEM.md).
5. **Every number is a Fact:** value + unit + source + source time + age + state (LIVE / LATE / STALE / QUIET / SUSPECT / CONFLICT /
   INCOMPLETE / CLOSED). A screen may only ask the trader to act on LIVE facts. Stale is grey and striped and can never hide.
6. **R before rupees.** Risk, P&L and results are in R, net of all costs; rupees are smaller. No profit potential, no "Rs at target",
   no giant MTM, no % of premium as the headline.
7. **Honest numbers or none.** n= and window on every statistic; under 30 = "too early"; an edge counts only when its lower bound is
   above zero; untriggered, expired, suppressed and wrong calls are always counted. "Unknown" and "no data" are real values.
8. **Asymmetric friction.** Safe actions (exit, tighten, skip, acknowledge) are one step. Risky actions (entry, loosening a limit,
   re-entering a stopped share, an early exit, a gate override) take a deliberate second step plus a typed reason. Exits are never
   blocked; entries ARE blocked by the hard gates.
9. **Calm by design.** No flashing, blinking, tickers, auto-scroll or pop-ups over positions / chart. Sound is rare (two tones).
   "Nothing to do" is a designed calm state with the next check time.
10. **Every panel earns its place.** It names the number it improves (named-before rate, lateness, leakage in R, slippage, rule
    breaks, ack time), gets a 2-week trial, and follows "one panel in = one out".

---------------------------------------------------------------------------------------------------------------------------------

## 2. Page map and navigation

### 2.1 All pages

| ID | Page | Key | Used when | Designed this round (slug) |
|---|---|---|---|---|
| P0 | Global frame (on every page) | - | always | inside every design |
| P1 | Morning & Pre-flight | Shift+F1 | 19:45 -> 09:15 (default page 07:00-09:15) | `morning` |
| P2 | Desk (home) | F1 | 09:15-15:10 (default page) | `desk-hunt`, `desk-trade` |
| P3 | Plan card + ticket (drawer) | Space | before every entry; on any off-plan fill | `plan-card` (Desk with the drawer open) |
| P4 | Sectors (sector board) | F2 | 09:15-15:10; study | `sectors` |
| P5 | Rotation | F3 | 09:30-15:10 | not this round (components from `sectors`) |
| P6 | News (wire) | F4 | any time | `news` |
| P7 | Positions & Risk | F6 | in a trade; end of day | `positions` |
| P8 | Share page | F7 / Enter on any symbol | any time | `share` |
| P9 | Analyst & Notes | F8 | any time | `analyst` |
| P10 | Option chain (buyer's chain) | F9 / O | strike choice | `chain` |
| P11 | Futures & OI | F10 | 09:15-15:10 | `futures-oi` |
| P12 | Calls & Scorecard | Shift+F8 | 15:45; evenings | `scorecard` |
| P13 | Journal, Weekly review & Edge | Shift+F6 | after 15:10 only (performance greyed 09:15-15:10) | not this round |
| P14 | Calendar & Policy | Shift+F4 | evenings, mornings | not this round (its today strip is on `morning`) |
| P15 | World drivers & sensitivities | Shift+F2 | 19:45 -> 09:15; research | not this round (drivers board lives on `morning`) |
| P16 | Data health & monitoring (/status) | Shift+F9 | always; opens itself on RED | `health` |
| P17 | Reference data | Shift+F7 | 08:45 check; read-only | not this round |
| P18 | Risk charter & Settings | Ctrl+, | outside market hours | not this round |
| P19 | Replay & Practice | Shift+F10 | after 15:35 and weekends only | not this round (it is the Desk + REPLAY watermark) |
| P20 | Help & legend | ? | any time | not this round |
| P21 | Phone (/m) | - | away from the laptop | `phone` |
| P22 | Telegram (2 bots) | - | channel, not a page | - |

### 2.2 Keyboard (one keymap, no conflicts)

- **Pages:** F1 Desk · F2 Sectors · F3 Rotation · F4 News · F6 Positions & Risk · F7 Share · F8 Analyst · F9 Option chain ·
  F10 Futures & OI. Shift+F1 Morning · Shift+F2 World drivers · Shift+F4 Calendar · Shift+F6 Journal · Shift+F7 Reference ·
  Shift+F8 Calls & Scorecard · Shift+F9 Health · Shift+F10 Replay · Ctrl+, Charter & Settings · ? Help.
- **F5, F11, F12 are never page keys.** F5 is captured and does nothing (a reload mid-trade must never happen by accident); reload is
  Ctrl+Shift+R, which asks for confirmation while a position is open. F11 / F12 stay with the browser. GIR runs as an installed app
  window (PWA) so the function keys reach the page; every page is also reachable from the "/" command line and by clicking its tab.
- **Command line "/":** a symbol (`TITAN`), a contract (`HINDALCO 680 PE`), verbs (`TITAN OC` chain, `TITAN FUT` futures,
  `METALS` sector, `GOLD` driver, `LOG TITAN` calls on it, `NEWS TITAN`, `STATUS`), free text searches news. It never sends anything.
- **On lists:** 1-9 select sector (Desk, Sectors) · J / K or arrows move the focused row · Enter open the share page · O option
  chain of the focused share · C cycle chart 1 / 5 / 15-min (5-min default) · W why / evidence drawer · Esc close a drawer.
- **On calls:** Space open the plan card of the primary call · S skip (asks a one-word reason) · there is no buy key.
- **On positions:** X opens the exit coach for the focused position (needs Enter) · Shift+X shows the exit-all instructions (needs
  Enter). Neither sends an order.
- **Alerts:** A then Enter acknowledges the top alert (any single key never acknowledges a P1) · M mutes P2 for 10 minutes
  (countdown shown; P1 can never be muted from the page).
- No single key causes an irreversible action. The keymap is read-only during market hours.

### 2.3 How pages link

- Every share symbol anywhere is a link to its Share page (P8); every sector name is a link to Sectors (P4) with that sector open;
  every contract opens the Option chain (P10) on that strike; every call id opens its entry in Calls & Scorecard (P12); every story
  chip opens the story drawer (News P6); every freshness dot opens that component on Health (P16).
- The thesis line (frame) links to Analyst (P9). The risk bar links to Positions & Risk (P7). The day line's event countdown links to
  Calendar (P14). Expiry chip -> Calendar's derivatives section. Ban pill -> Futures & OI MWPL monitor.
- Drawers (one overlay layer, right side, never over positions, the in-trade strip or the chart price axis): Plan card (P3),
  Why / evidence, Story, Ask the analyst, Exit coach. Only one drawer at a time.
- Page defaults by clock: 07:00-09:15 opens Morning; 09:15-15:10 opens Desk; 15:10-17:00 opens Positions & Risk then Scorecard at 15:45;
  night opens Analyst (notes). A RED health component opens Health once (the trader can leave it).

---------------------------------------------------------------------------------------------------------------------------------

## 3. The clock: phases and day states

### 3.1 Phases (set by the exchange clock taken from the feed sentinels' exchange timestamps, NTP as fallback)

| Phase | Time (IST) | What is allowed | Emphasis |
|---|---|---|---|
| NIGHT | 17:00-07:00 | notes (19:45, silent 23:45 night delta), research pages | Analyst, Calendar, World drivers |
| PREP | 07:00-09:00 | 07:15 note, pre-flight at 08:45, arm the day | Morning page |
| PRE-OPEN | 09:00-09:15 | pre-open table 09:00-09:08, 09:08 check; options have no pre-open | Morning pre-open table |
| OBSERVE | 09:15-09:30 | no orders 09:15-09:20; GET READY allowed from 09:20 once a sector confirms; GO NOW disabled ("from 09:30") | sectors, opening range forming |
| ENTRY | 09:30-14:00 | GO NOW possible if every gate passes | Desk call card |
| LATE ENTRY | 14:00-14:30 | GO NOW only if break-even fits the minutes left to the planned exit | call card shows minutes left |
| MANAGE ONLY | 14:30-15:00 | no new entries; 14:45 position rows amber | positions; call card reads "MANAGE EXITS - no new calls" |
| EXIT NOW | 15:00-15:10 | 15:00 banner + P1; 15:05 rows red with exit at bid; 15:08 full-width EXIT ALL with mm:ss; 15:10 flat check repeats until acknowledged | in-trade strip, exit ladder |
| CLOSED / REVIEW | 15:10-17:00 | "MARKET CLOSED - as of 15:30" on every live number after 15:30; 15:45 scorecard | Positions & Risk, Scorecard |

Countdowns are written as durations ("5h 05m", in the last 15 minutes "mm:ss"), never as a clock-looking "5:05".

### 3.2 Day states (overlay on the phase; highest priority wins the emphasis)

Priority: **SAFE MODE > NO STOP / NO BROKER STOP / FILL MISMATCH > NEAR STOP > EXIT NOW > LOCKED > READ-ONLY > NOT ARMED >
EVENT WINDOW > COOLING > IN TRADE > HUNT (flat) > NOTHING TO DO**. REPLAY is a separate mode that can never be confused with live.

| State | Trigger | What the screen does |
|---|---|---|
| SAFE MODE | a critical family (prices, options, positions sync) stale beyond its limit | every dependent value grey-striped "STALE since hh:mm"; no calls; positions say "price STALE - check Kite"; if both Kite paths for a held instrument are > 5 s: P1. After recovery, no GIR-signal entries until GREEN for 5 min. |
| NO STOP | a Kite position with no recorded share stop (incl. an OWN TRADE) | the only state that blocks clicks: a full-width bar over the content asking for the share stop and reason; counts toward the 3 trades. |
| NO BROKER STOP | no resting SL-LIMIT at the premium backstop 60 s after a fill, or the order was widened | P1, red bar in the in-trade strip; logged as a breach if it persists. |
| FILL MISMATCH | Kite fill differs from the plan (side, strike, expiry, quantity) | P1 "MISMATCH: you bought CALL, plan was PUT". |
| NEAR STOP | < 30% of the stop distance left | danger border on that position, P1 once; any GO NOW dims to outline. |
| LOCKED | -2% day, 2 losses in a row, 2 full stop-outs in the day, give-back (peak >= +2R falls by 50%), weekly -6%, or the one-way "I'm done today" | call card replaced by "LOCKED - <reason> - until 09:00 next session" with no dismiss; plan card and ticket removed; calls continue as paper (greyed in the log); a prompt with the steps to switch on Zerodha's own F&O kill switch. Exits stay fully usable. |
| READ-ONLY | pre-flight RED | data visible, no calls, positions still managed; banner names the failed component. |
| NOT ARMED | the day's pre-flight + check-in not done | calls arrive as WATCH only (no plan card). |
| EVENT WINDOW | from 10 min before to 15 min after an in-session release (affected sectors); Tier-1 15 min before to 30 min after (all); unscheduled shock (MCX crude +-3%, USD/INR +-0.5%, impact-5 macro story) = 15-min freeze | affected call cards read "EVENT WINDOW - until hh:mm"; shaded on the day line timeline. |
| COOLING | 20 min after a losing exit | risk-bar timer; GO NOW shown as WATCH; plan card disabled with the timer. |
| IN TRADE | >= 1 open position | in-trade strip carries the largest type; new calls queue silently except on the held share; news collapses to one line. |
| HUNT | flat, ENTRY phase | call card is the focus. |
| NOTHING TO DO | flat, no call passes the gates | calm grey card: "No setup passes the gates. Watching METALS (breadth 6/11, needs 8), TITAN (needs 5-min close < X). Next sector check 10:45." No amber. |
| REPLAY | Replay page | hatched violet border, "REPLAY 18 Nov 10:42 - not live" watermark, no sound, no Telegram, no push; disabled 09:00-15:35 on trading days. |

Special day modes (set at 08:30 from the calendar): **EXPIRY WEEK** (from T-5 sessions: next month is the default strike month if it
passes the gate; ROLL instead of LU/SC where rollover explains it), **EXPIRY DAY** (no new current-month entries; near-month ITM
still open after 14:30 = P1; physical settlement), **RBI / BUDGET / COUNTING DAY** (flat 15 min before to 30 min after, half size;
counting day none before 11:00), **REBALANCE DAY** (affected shares exit by 14:45), **AFTER AN OVERNIGHT TIER-1 EVENT** (no entries
09:15-09:30).

---------------------------------------------------------------------------------------------------------------------------------

## 4. P0 - Global frame (every page, 1600x900)

Total frame height 140 px; content area 760 px (see DESIGN_SYSTEM.md for exact geometry).

| Strip | Height | Shows | Data |
|---|---|---|---|
| Command bar | 28 | GIR mark · page tabs with keys · "/" command line · phase chip with the two countdowns ("ENTRY · 4h 25m to 14:30 · 5h 05m to 15:10") · feed dot + worst critical age + "4 keys · 12 conn" · exchange clock hh:mm:ss IST · day-state chip (NORMAL / COOLING mm:ss / LOCKED / SAFE MODE since hh:mm / READ-ONLY / NOT ARMED / REPLAY) · unacknowledged-alert count · mute state | exchange clock from sentinels; heartbeat table; rule engine |
| Risk bar | 28 | Day net in R (Rs small) · loss used meter vs the day lock (amber at 75%, LOCKED at 100%) · trades "1 of 3" · open "1 of 2" · open risk if all stops hit (R) · premium outstanding % of capital · week R vs -6% · cooling timer · NIFTY value + 30-min sparkline + tick age · India VIX · the week's ONE rule | Kite positions/orders/funds (read-only), risk engine, Kite index ticks, journal |
| Day line | 24 | **Thesis** "THESIS 07:15 v1" with one chip per leg (e.g. "Gold -> jewellers & gold loans PUT · INTACT", "Copper -> cables, metals PUT · WEAKENING 10:52", "Pharma CALL · INTACT") + unread-note badge · **today items** at the right: next in-session event with countdown and its no-entry window · stock expiry "Mon 23 Nov · 3 sessions incl. today · EXPIRY WEEK" (from the contract master, with "moved from Tue 24 Nov - holiday" on hover/legend) · ban pill "BAN 2 · >85% 3" · results today for watch-list shares | analyst thesis store, event store, NSE contract master, fo_secban / MWPL |
| Situation / in-trade strip | 40 (always reserved) | **Flat:** a calm situation sentence written by code from a template ("Flat · 2 of 3 trades left · METALS forming 3 of 5 · next sector check 10:45"). **Holding:** one segment per position (two positions = two halves), nearest to its stop first: share, CALL/PUT word, strike, share NOW (tick age) vs share STOP (GOVERNS) as the largest text, distance % and in ATR, Rs to stop per lot, target, premium bid/ask vs backstop, broker stop OK / NAKED, time-stop countdown, minutes to 15:10, thesis chip, P&L in R as the smallest field. Danger border + "NEAR STOP" when < 30% of the stop distance is left. | Kite ticks via two paths (K2 pinned + K4 hot duplicate), Kite positions/orders, plan card |
| Status line (footer) | 20 | SEBI line "About 9 in 10 individual F&O traders lose money (SEBI study)" · "AI-generated, personal use only" · health summary (worst component) · AI ladder level (full / mid only / rules only) · key hints · in mockups "design mockup - illustrative values" | health checker, AI gateway |

The alert tray (max 3 toasts) sits in the bottom of the right column of the content area, above the footer. It never covers the
in-trade strip, positions, exit controls or the chart's price axis. Hard states (NO STOP, LOCKED replacement card, 15:08 EXIT ALL,
READ-ONLY / SAFE MODE banners) are the only full-width elements.

Removed from the always-visible bar (spec 5.1 overruled, see section 10): SENSEX (duplicates NIFTY), PCR (noise per H), FII/DII
(yesterday's end-of-day figure), AI spend (moved to the footer ladder chip and Health).

---------------------------------------------------------------------------------------------------------------------------------

## 5. Pages, panels and their data

Phase behaviour is given per page; "Data" names the DATA.md items (D-numbers).

### P1 Morning & Pre-flight (Shift+F1) - BASIC, the page the trial is judged on

Purpose: turn the night into a falsifiable thesis, a shortlist and the day's allowance, decided while calm; prove the system works
before any call can go out. Layout: left 388 (pre-flight + allowance), centre 784 (drivers -> chain rows -> watch list), right 388
(notes + today's risk strip + pre-open).

| Panel | Shows | Data |
|---|---|---|
| Pre-flight (08:45, re-runs on any RED) | 4 Kite tokens with each key's role; 12 connections with instrument counts and sentinel age; instrument list date and count vs yesterday; NSE files loaded with their own content dates (contract master, lots, ban, MWPL, holidays, corporate actions); Kite vs NSE mismatches (shares BLOCKED today); clock offset ms; disk / memory; AI budget left; test alert acknowledged on laptop AND phone; outside dead-man last ping. Verdict READY (GREEN) / LIMITED: <named limitation> (AMBER, shown all day in the footer) / READ-ONLY (RED). | D1-D7, D60-D66 |
| Check-in and allowance (10 s) | Slept well y/n; state calm / tired / upset / anxious; uninterrupted 09:15-15:10 y/n. Capital (lower of declared and Kite available), 1R in Rs, day lock in Rs, trades allowed (low readiness suggests 1 trade or a STAND-DOWN day - a suggestion), size step ("1 lot · trade 37 of 100"), week and month drawdown vs limits. Today's commitments in the trader's own words (max trades, max loss, sectors I will trade); they can only be tightened later and show in the risk bar. Button: ARM THE DAY. | D50-D53, D57 |
| Driver board | One row per driver: last, move **since our 15:30 IST close**, z-score vs its 20-day vol, checklist-A threshold and crossed / not, the market's own session state (OPEN / CLOSED / HOLIDAY with local time), source + age (DELAYED / DAILY labelled), mapped sectors. Below-threshold rows greyed. | D40-D46 |
| Chain rows (the thesis legs) | "Copper -1.8% (z -2.1) 06:55 -> Cables & wires (measured beta 0.6, n=48, or 'rule of thumb, unmeasured') -> POLYCAB, KEI, HAVELLS -> PUT watch". A link that does not follow later turns grey with DIVERGENCE. Priced-in check: the sector's 1-day / 5-day move vs its typical reaction. | D40-D46, D19, D58 |
| Overnight events and filings | US / China / India releases with actual vs consensus and surprise score; regulator / gazette / PIB items; after-hours filings sized against revenue; leaks VERIFIED / UNVERIFIED | D47-D49, D33-D39 |
| Watch list (max 8 armed ideas) | Share, CALL/PUT, leg, trigger, invalidation (one wrong-if), range used / ATR, room in ATR, IV vs own 20-day (and rank with n and method), results date, ban / MWPL, option-gate preview at yesterday's close spread, status waiting / ready / fired / dead | analyst store, D21-D27 |
| Notes | 19:45 (max 250 words), 23:45 night delta (silent, stored), 07:15 (max 150, leads with "changed since 19:45"), 08:45 and 09:08 (max 3 lines; "no change" allowed). Format WHAT'S HAPPENING / WHAT I'D DO NOW / WHAT I'D AVOID / WHAT WOULD CHANGE MY VIEW. Unread badge; a non-blocking banner if unread at 09:15; "inputs as of" per driver; a missing input is named in line one. | analyst |
| Today's risk strip | 09:00-15:30 timeline: in-session events (tier, sectors, shaded no-entry windows), results today (before / during / after market), ex-dates, ban entries/exits, rebalance shares, expiry status | D47-D49, D3-D5 |
| Pre-open table (09:00-09:08, then frozen) | Every F&O share (watch list first): indicative open, gap %, gap in ATR, pre-open volume vs its 20-day pre-open average, agrees with the night / not, "plan ready" / "gap too large" | D15 |

Phases: NIGHT shows the 19:45 note on top; PREP centres the drivers and watch list; at 08:45 the pre-flight panel expands; PRE-OPEN
promotes the pre-open table; from 09:15 the page goes read-only reference (the Desk becomes the default).

### P2 Desk (F1) - the only screen needed 09:15-15:10

Fixed grid in the 760 px content area: **left 388** (Positions over Sectors ranked), **centre 784** (members of the selected sector
over the chart), **right 388** (call card, queued calls and watch rows, one news/event line, alert tray). Hunting and holding are
the same grid; only emphasis changes.

| Panel | Shows | Data |
|---|---|---|
| Positions (left top, fixed 322 px in every state - amended 18 Nov to match desk-hunt v2 and desk-trade v2, so Sectors start at the same y; holding: one shared column header, one block per position, the NEAR STOP block carries the manual exit line) | Flat: one line "Flat · 2 of 3 trades left · today -0.4R" + today's closed trades (one line each). Holding, nearest to stop first, fixed column order: share, CALL/PUT, expiry + sessions, strike, lots, entry, premium bid (tick age), share now, share STOP (GOVERNS) + distance %, Rs to stop / lot, premium BACKSTOP + broker order OK / NAKED, target, time held, time-stop countdown, spread % (red > 1%), theta Rs/h, OI at strike + change + plain-word activity, originating call + leg status, verdict text HOLD / MOVE STOP TO BE / TRAIL / BOOK HALF (only >= 2 lots) / EXIT + reason. OWN TRADE tag for a position matching no call. | D54-D56, D8-D12, D22-D25 |
| Sectors ranked (left, rest of column) | 10-14 rows by relative strength vs NIFTY since 09:15: rank + 15-min rank-change arrow, % from open, RS, breadth bar "9/11" with coverage, equal-weight vs index trap flag, VWAP side, CONFIRMED hh:mm / FORMING 3 of 5 / FAILED / INCOMPLETE (coverage < 90%), driver chip with its live move, "you hold here" marker, "extended - pullbacks only" marker; index source "NSE index" or "GIR basket n=4". Keys 1-9 select. | D9, D10, D19-D21, D42 |
| Members of the selected sector (centre top, 230 px, scrolls inside) | EVERY F&O share in it (no top-3 cut), ranked by checklist D: % from open, RS vs sector, RVOL same time of day, VWAP / OR side, range used / ATR (> 1.2 dimmed "extended"), room to next level in ATR, futures build-up all months + futures volume vs normal, own-news chip (type, impact, age, NEW / PRICED IN / UNREAD), role LEADER / FOLLOWER / LAGGARD / DIVERGENT, option gate TRADABLE / NOT TRADABLE: reason, plan status. A visible cut line: above = passes all gates, below = grey with the failing reason. | D8-D12, D19-D24, D33 |
| Chart (centre, one chart only) | Header: price + tick age, % from open and prev close, RVOL, range used, sector, share-minus-sector %. 5-min candles (C cycles 1 / 15), VWAP, shaded opening range, prev-day H/L, 20-day H/L when within 1 ATR, the qualifying call / put OI walls as faint lines, volume, trigger / WRONG IF (= share stop) / target lines labelled at the axis, GO NOW and entry markers, news markers F (first seen) and M (move began). Premium pane (30%) on the same time axis: option MID with bid/ask band, own VWAP, entry, backstop, no-chase line, "target above scale" arrow, divergence flag ("share new low, premium not new high"). Thin strip: share % minus sector % since 09:15. | D8, D11, D12, D18-D22, D33 |
| Call card (right, one primary) | **GO NOW** (filled amber, the only filled amber on screen) or **GET READY** (amber outline, never an action button). Read order: (1) GO NOW · SHARE · PUT · 285 · Tue 29 Dec (expiry + sessions left) (2) valid till 10:13 or premium > 13.90 or 0.3 ATR past trigger - counting down; "price then -> now" (3) two columns PREMIUM | SHARE: entry zone / trigger "crossed 10:02:58", stop (SHARE GOVERNS / premium BACKSTOP), target, no-chase (4) one WRONG IF line = the share stop (drawn on the chart) (5) 1 lot (from the 1% rule), max loss Rs and R, round-trip cost Rs, break-even premium, share move needed by 15:10 vs expected move, R:R after costs, theta to planned exit, hold-until + time stop (6) gate chips: SPREAD 0.8% · DEPTH OK · DELTA 0.52 · IV 1.1x 20d · NO EVENT · MWPL 41% · 27 SESSIONS (7) BECAUSE (2 bullets with evidence ids) + leg + "vote against" if a measured voter disagrees (8) setup label (A / B+ / B) and "today: 2 hit · 1 miss · 1 expired" (no win rate, no confidence) (9) actions: Plan card (Space), Skip (S + reason), Why (W). No buy button. Below the primary: max 2 queued calls as one-line rows ("1 call waiting"). Follow-ups on a taken call appear as timestamped lines under it. | analyst decision schema (D70), gates, D23-D27 |
| Watch rows (right, below) | Armed conditions: share, CALL/PUT, trigger, distance to trigger (ATR and %), wrong-if, status waiting / armed / fired / expired / dead / NO GO (reason) | analyst store + ticks |
| News / event line (right bottom) | Flat: up to 3 stories filtered to held / watch / active sectors (impact 4-5). In a trade: one line only; a story on the held share is pinned. Next in-session event with its no-entry window. | D33-D39, D47 |

Phase behaviour: OBSERVE - call card shows GET READY or "GO NOW from 09:30", opening range shading grows; ENTRY - normal;
LATE ENTRY - call card shows "minutes left vs break-even"; MANAGE ONLY - call card reads "MANAGE EXITS - no new calls", watch rows
grey; EXIT NOW - the 15:00/15:05/15:08 ladder (rows amber at 14:45, red at 15:05 with "exit at bid", 15:08 full-width EXIT ALL
instructions "sell 1 lot HINDALCO 680 PE at limit bid-1 tick in Kite" with mm:ss); CLOSED - "MARKET CLOSED - as of 15:30" banner, all
values greyed. States: LOCKED replaces the call card; COOLING shows the timer on the card; SAFE MODE stripes everything; NEAR STOP
dims the GO NOW to outline and puts the danger border on the position; NOTHING TO DO is the calm grey card.

### P3 Plan card + ticket (drawer, Space) - the last cold moment

Opens over the right column only (388 px wide, full content height). Required before a call can be recorded as taken; also opens
automatically within seconds of any off-plan fill (then it asks for the stop and reason, and the position is an OWN TRADE).

| Section | Shows |
|---|---|
| Plan | setup, trigger, governing share stop = wrong-if (one number), premium backstop (max 30% loss), target, hold-until, the setup's time stop; the trader TYPES the side (C / P - a mismatch with the call stops it), types the lots (empty by default, max allowed shown), confirms "stop on the share at X". |
| Money | risk in Rs and R; itemised costs (brokerage, STT, exchange, SEBI fee, GST, stamp duty, measured spread) with the charges table's "verified on" date; break-even premium; share move to break even by the planned exit and by 15:10 vs expected move; theta to exit; R:R after costs. |
| Checks | every hard gate as a line with its number; a failure disables Confirm and names the gate ("NO GO: spread 1.4%"); concentration (sector, DRIVER, direction); chase vs trigger in ATR; cooling timer; re-entry flag ("stopped out of TITAN 18 min ago - reason?"); readiness from check-in. |
| Soft prompt | "What would make you exit early?" (one line, stored). |
| Ticket | exact Kite trading symbol, expiry in words + sessions left, quantity = lots x lot size, LIMIT price (ask + 1-2 ticks), and the broker backstop to place: SL-LIMIT trigger / limit at the premium backstop; copy buttons. Optional "Open in Kite" via Kite's own pre-filled order link where permitted (verify Kite Publisher terms); the trader confirms in Kite. No order ever leaves GIR. |
| After confirm | immutable timestamped plan, paper twin started, GIR watches for the Kite fill (side / strike / expiry / qty match within seconds; no fill in 3 min = logged as skipped) and for the resting backstop order (within 60 s or NO BROKER STOP). Slippage recorded. |

### P4 Sectors (F2) - the method on one page

Purpose: decide which sector is really moving, why, and list every F&O share in it with a plan line.

| Panel | Shows | Data |
|---|---|---|
| Context strip (top, 28 px) | NIFTY / BANKNIFTY vs VWAP, A/D, VIX, day type (TREND / RANGE / GAP-AND-GO / GAP-AND-FADE / EXPIRY / RESULTS / EVENT, set by 10:00) and the setups it allows; index PCR and yesterday's FII/DII in a small "context - never a reason" chip with their dates | D9, D29, D30 |
| Falling (PUT plans) - left half / Rising (CALL plans) - right half | Sector cards sorted by RS; neutral sectors collapsed below. Each card: analyst's one-line decision; status WATCH / CONFIRMING / CONFIRMED since hh:mm (never before 09:20) / FADING / FAILED / INCOMPLETE; the five checklist-C checks as ticks with the time each became true (RS vs NIFTY; breadth >= 70% with median > 1% and n shown, or with n < 5 all members on one side; equal-weight vs index; build-up agreeing in >= 3 shares across all months; sector VWAP side + gap holding at 09:45); driver chip with live move since 15:30; driving story with impact and time, or UNEXPLAINED; run time vs typical (n). | D10, D11, D13, D19, D40, D33 |
| Members table inside each card | EVERY F&O share: role, range used / ATR, room in ATR, RS vs sector, RVOL, VWAP / OR side, build-up all months, own news, ATM spread, IV vs 20-day, gate, plan line (GO NOW / GET READY / AVOID - used its room / no plan); DIVERGENCE tag with the D8 laggard conditions as ticks. Leader on a VWAP pullback ranks first; a laggard only when all D8 conditions pass, labelled B. | D8-D24 |
| Driver live line (bottom) | MCX / currency moves since 09:15 and INTRADAY COMMODITY LAG flags (S8 #8) | D42 |

Phase: OBSERVE shows "forming" progress; from 10:00 the day-type chip locks; after 14:30 plan lines read "manage only".

### P5 Rotation (F3) - not designed this round

Rank ladder (bump chart of each sector's RS rank in 15-min steps from 09:15, 09:30-10:30 changes highlighted); window table
15M / 30M / 1H / TODAY with breadth; money out -> in pairs (with breadth > 80% flag and the explaining driver or "no cause found");
sector money flow = notional all-month futures OI added per sector (Rs crore) split LB / SB / SC / LU vs the sector's own normal;
sector run clock "Metals down since 09:20, 1h 22m, typical 2h 10m (n=31)"; breadth small multiples; run log ("confirmed 09:22 ·
weakening 11:40 (breadth 6/12) · failed 12:15"). Data: D10, D11, D13, D19, D58.

### P6 News (F4)

| Panel | Shows | Data |
|---|---|---|
| Story list (left 2/3) | Stories (one event = one story, merged within 2 h): three clocks - source time, first-seen, move-began; shares / sector; event type; direction; impact 0-5 computed in code (only 4-5 ring); verification OFFICIAL / REPORTED / UNVERIFIED / DENIED / CLARIFIED; source count + best tier; lead/lag ("price moved 6 min before we saw it"); move since first seen in ATR vs sector; NEW / PRICED IN (with its number) / RETOLD / UNEXPLAINED; linked call. Filters: positions / watch list / active sectors / filings / policy / world / results / all. Never auto-scrolls: "3 new" bar the trader pulls in. | D33-D39 |
| Story drawer | source ladder (who first, who confirmed, times), original link, extracted numbers and size ratio, 1-min chart of share and sector from 30 min before first-seen with F / M markers, analyst verdict | D33-D39, D8 |
| Filings sub-view | NSE + BSE announcements, category, parsed attachment numbers, XBRL results lines vs last year/quarter ("vs consensus" only with a licensed consensus), READING... while a filing is unparsed (this holds GO NOW on that share) | D33, D34 |
| Source latency board (right) | p50 / p90 publish -> first-seen per source, % first, % before the move, demoted sources, today's "arrived after the move" list | D39, D67 |

### P7 Positions & Risk (F6)

| Panel | Shows | Data |
|---|---|---|
| Open positions (full) | Desk rows, larger, plus: delta, theta Rs/h, IV now vs at entry, MFE / MAE, live P&L split in R (share move / theta / IV / spread), plan vs actual, broker SL order (trigger, status OK / NAKED / WIDENED), exit depth at the bid for my quantity, physical-settlement flag in expiry week, chart thumbnail, originating call + thesis | D54-D56, D22-D25 |
| Exit coach (X) | shows the plan again; HOLD / MOVE STOP TO BE / TRAIL / EXIT HALF (>= 2 lots) / EXIT ANYWAY + one-word reason; the exit itself is written as instructions for Kite ("sell 1 lot at limit bid-1 tick"); never blocks | plan card |
| Risk box | day loss used vs lock, losses in a row, trades used, open risk if all stops hit (x1.2 slippage allowance on thin strikes) vs Rs to lock, premium outstanding vs cap, week / month drawdown vs ladder, sector / DRIVER / direction concentration, cooling timer, cash available vs premium needed; size calculator ("1 lot = 1.19R -> SKIP, or a tighter share stop is not allowed; capital needed Rs X") | D53, D55, D57 |
| Exit timeline | each position's time stop, 14:30 / 14:45 / 15:00 / 15:05 / 15:08 / 15:10 marks, events touching its sector | D47, plan |
| Today's ledger + orders | closed trades: plan vs did, exit reason (stop / target / trail / time stop / invalidation / manual early / 15:10 / OFF-PLAN), R and Rs net, costs column, slippage in ticks, price 30 min after exit, early-exit cost in R; orders today with type (LIMIT / SL-LIMIT only), rejections with reasons | D54, D56, D26 |

### P8 Share page (F7, or Enter on any symbol)

Live trade view on top, research dossier below (scrolls inside the lower panel only).

| Panel | Shows | Data |
|---|---|---|
| Header | price + quote age + source badge, % from prev close and from open, sector + its status, role, ATR14, range used, RVOL, VWAP side, lot size (today), expiries with sessions left, results date / timing, ex-date, ban / MWPL % with 5-day trend, F&O inclusion status, event chips | D1-D5, D8, D19-D21, D48 |
| Chart + premium pane + RS strip | identical component to the Desk | as Desk |
| Checklist D | pass / fail with the number for D1-D8 (incl. the laggard conditions) | GIR calcs |
| Levels | prev-day H/L/C, 20-day H/L, weekly H/L, OR H/L, VWAP, qualifying OI walls - each with distance in ATR | D18, D20, D21, D14 |
| Futures by contract | current / next / far: price, basis and excess basis vs fair carry, OI (lots), OI change since open and vs prev close, volume vs normal, build-up tag per month and COMBINED, rollover % from T-5 with "ROLL - not unwinding" | D12, D13, D59 |
| Option snapshot | ATM-1 / ATM / ATM+1 for this and next expiry: bid/ask, spread %, depth at bid in lots for my quantity, IV, delta, theta Rs/h/lot, Rs per 1% share move, gate | D14, D16, D22 |
| News, filings, events | stories with first-seen and move since; filings; next results / board meeting / ex-date / index change | D33-D38, D48 |
| History (E4) | ATM IV series (back-filled from NSE F&O bhavcopy "from closes", then live) with IV rank, window, n and method; IV build/crush around the last 8 results; results-reaction table; gap-fill rate by gap size; day after a 3%+ move; leader/laggard record; expiry-week behaviour; ATM spread/depth at 09:30/12:00/14:30; MWPL/ban history; red flags (pledge, PSU, regulatory) - each with n | D23, D24, D31, D32, D58 |
| Calls and my record | every GIR call on this share (incl. untriggered / expired) with paper R and n; MY trades on it with mistake tags ("you exited early here 3 of 4 times") | D70-D73 |

### P9 Analyst & Notes (F8)

| Panel | Shows |
|---|---|
| Thesis timeline | each leg's status over time (INTACT 07:15 -> WEAKENING 10:52 -> BROKEN 11:40), its wrong-if and the moment it hit; when a leg breaks, its GET READY lines die and positions under it get a rules-based HOLD / EXIT follow-up |
| Decisions stream | GO NOW / GET READY / HOLD / BOOK HALF / MOVE STOP / EXIT / NO TRADE newest first, each ending in an action; follow-ups as timestamped lines under the original; versions "revised 10:42" with the old struck through (immutable); expired / untriggered greyed but visible; evidence ids with their ages; model tier |
| What would change my view | monitored conditions with live status ("copper turns positive: now -1.2%, not met") |
| What I am not seeing | inputs currently STALE / INCOMPLETE the analyst could not use |
| Notes archive | 19:45 / 23:45 / 07:15 / 08:45 / 09:08 / 10:00 day type / 12:30 midday / 14:30 manage-only, any date, with next-day score, word count vs limit, version |
| Ask drawer | free questions; answers built only from stored facts with evidence ids and ages; cost shown before sending; while in a trade only questions about that position's plan |
| Team strip | per agent: last run, items found, woke the analyst, reached the trader, cost today, 20-day record vs baseline; silent agents shown with the reason |

### P10 Option chain - the buyer's chain (F9 / O)

Improves on the broker chain (LTP % vs yesterday, OI in lakhs, PCR, max pain, "IV percentile 61 High" of unknown method,
"5 Days" in calendar days) for an intraday BUYER.

| Panel | Shows | Data |
|---|---|---|
| Header | share price + age, same-expiry FUTURE price (the pricing base) and basis, lot size, MWPL %, results date, ATM IV now and change since open, IV vs 20-day average, IV rank with window/n/method (or "building, n=12"), IV / RV10, crush flag; "physical settlement - never hold ITM into expiry" | D1, D2, D12, D22, D23 |
| Expiry tabs | from the contract master only: "Mon 23 Nov · 3 sessions incl. today · moved from Tue 24 Nov (holiday) · EXPIRY WEEK" / "Tue 29 Dec · 27 sessions" / "Mon 25 Jan · moved from Tue 26 Jan (holiday)"; trading minutes on hover; in expiry week the next month opens by default | D2, D5 |
| Strike grid ATM +-5 (re-centred on the future) | CALL side left, strike centre, PUT side right. Per side: gate chip with reason code (TRADABLE / SPRD / THIN / IV / BAN / EVT / FAR / SIZE), bid, ask, MID (main price), spread % (red > 1%), depth at best 5 in lots vs my quantity, volume vs normal for the time, OI in lots + change since 09:15 (toggle 15 min / vs prev close) with a bar, plain-word activity (CALL WRITING / CALL BUYING / COVERING / UNWINDING with implied share direction), IV from mid, delta, theta Rs/h/lot, premium change since 09:15, quote age and last-trade age (QUIET > 2 min). ATM by the forward, spot drawn as a line between strikes, ITM shaded, suggested strikes (delta 0.45-0.6, ATM / 1 ITM) outlined, far OTM dimmed "not allowed", CALL WALL / PUT WALL only when the size rules are met. | D14, D16, D22, D23 |
| Selected strike / buyer's comparison | ATM this month vs ATM next month vs 1-ITM: premium per lot = max loss, delta and Rs per 1% move, theta to 15:10 per lot, IV -2 pt effect per lot, break-even share price at 15:10 vs expected move, exit capacity at my quantity, 1R at the standard backstop and % capital, one-line verdict; 5-min premium chart with VWAP; "Add to plan" (no order) | D22, D25, D26 |
| Footer | ATM IV, IV rank (n, method) or "not reliable, n=23", expected move to 15:10, ATM break-even move incl. costs, nearest OI walls with 15/60-min change, chain freshness "OI as of 10:42:10 (sweep) · quotes live · 186/190 strikes fresh"; PCR and max pain hidden behind a "context - not a signal" toggle | D14, D23 |
| Closed state | after 15:30 "MARKET CLOSED - as of 15:30 - official close may differ"; everything greyed |

### P11 Futures & OI (F10)

| Panel | Shows | Data |
|---|---|---|
| Build-up quadrant | every F&O share as a point: x = futures % today, y = COMBINED all-month OI %; quadrants LB / SB / SC / LU (neutral labels); filter by sector; click opens the share | D12, D13 |
| Build-up table (virtualised, ~200 rows) | share, sector, price %, OI change per month and combined (lots and %, % only if base >= 100 lots else "thin"), notional Rs crore, z-score vs its 20 days, conviction |dOI|/volume, futures volume vs normal for the time, tags 15m / 60m / since open (a tag needs price + OI + volume >= 1.5x thresholds, else "-"), tag start time, basis / excess basis change, rollover % vs usual (from T-5) with ROLL, MWPL band, OI as of | D12, D13, D59 |
| MWPL & ban monitor | in ban (tags hidden), 80-95% with 5-day trend, likely ban tomorrow > 90%, exits ban today (squeeze watch), file time | D3 |
| Sector roll-up | count of names per tag per sector; net notional OI added | GIR |
| Option activity (experimental) | BUYING BURST / WALL WEAKENING / WALL BUILDING / PAYING UP events with time, strike, lots, premium and IV change; each with its record (n, vs random) or "untested - paper only"; "estimated from 1-s snapshots" | D14, D16 |
| Context - never a reason for a call | participant-wise index OI, FII/DII cash, delivery % vs 20-day, index PCR - each with its file date | D28-D30 |

### P12 Calls & Scorecard (Shift+F8) - the trial's instrument

| Panel | Shows |
|---|---|
| 15:45 scorecard (also sent as Telegram text) | what the analyst said and when (19:45, 07:15, every GO NOW / GET READY / follow-up); every F&O share that moved 2%+ and every sector 1%+, with move-began time from GIR's own candles and the achievable ATM option move after the earliest valid entry; named BEFORE (a 09:20 GET READY with trigger counts) / LATE (minutes) / MISSED / NAMED-AND-WRONG, with cause class (DATA LATE / DATA MISSED / TAG MISSED / READ WRONG / GATED - good miss / ANALYST LATE / NO CAUSE) and the agent at fault; pre-09:30 moves are not GO NOW misses; recall AND precision (shares named vs a random set of the same size); lead time; each agent's day; AI spend by model and cost per useful call; audible alerts vs the budget of 6 |
| Call log (immutable) | every call incl. untriggered, expired, vetoed, suppressed (locked / cooling / stale - greyed): time, version, data age at issue, send and ack time per channel, price then and +15 / +30 / +60 min / close, taken / skipped (reason) / paper, paper result in R net (fills at ask in, bid out, +1 tick), real result; filters by setup, sector, leg, time window, day type, DTE, IV bucket |
| Headline record | "20 sessions: 31 calls incl. 6 untriggered, 3 expired · direction right 58% (n=31, range 40-74%) · +0.9R/call paper net (range -0.1 to +1.8)" vs RANDOM and MECHANICAL baselines (biggest driver -> mapped sector -> highest-beta shares) |
| Calibration | stated H / M / L confidence vs realised hit rate with n - the only place confidence appears |
| Miss audit timeline | per missed mover: driver moved -> first story (source, first-seen) -> sector confirmed -> call issued -> alert delivered -> acknowledged |
| Agent ledger | per agent: ran, inputs fresh %, found, woke, reached the trader, cost, record vs baseline, keep / probation / drop (3x cost rule, 100-call baseline rule) |
| OI / order-flow signal record | per signal type: hit rate next 60 min vs random, n, lower bound; greyed if not beating random after 100 |

### P13 Journal, Weekly review & Edge (Shift+F6) - after 15:10 only

Trade review card (plan vs did; EARNED / GOOD LOSS / LUCKY (counted as a rule break) / LESSON; mistake tags chased / early exit /
no broker stop / moved stop / averaged / outside window / revenge; ghost trade if the plan had been followed; chart snapshots; price
30 min after exit; stories live at entry). Day review 16:00 (process score, rule breaks and their cost in R, urges logged vs acted,
readiness vs outcome; a no-trade day counts as clean). Weekly one page (expectancy in R with range, net P&L, drawdown, profit factor,
win rate with n and avg win / avg loss, AI vs random vs mechanical, taken vs skipped, costs % of gross, exit-management cost, AI
lateness, source-lateness cost, rule breaks and cost, behaviour panel: time GO NOW -> decision, results when tired vs calm, trades
13:00-14:30 vs morning, re-entries after stops, median ack time; ONE rule for next week chosen from 3 suggestions - it then shows in
the risk bar). Leakage waterfall in R (sector choice, share choice, entry timing, option choice, exit management, costs). Edge page
(equity curve in R with size-step markers, MAE / MFE scatter, longest losing run vs expected, risk of ruin; edge gates "trade 47 of
200": at 50 adherence >= 90%?, at 100 expectancy lower bound > 0?, at 200 EDGE PROVEN / NOT PROVEN with plain advice). Monthly review
(size ladder step, charter proposals). Tax ledger (turnover = sum of absolute P&L, STT, charges, contract-note reconciliation, ITR-3
CSV). The edge and performance views are greyed 09:15-15:10.

### P14 Calendar & Policy (Shift+F4)

| Panel | Shows | Data |
|---|---|---|
| Today's risk timeline | 09:00-15:30 with events, tier, sectors, shaded no-entry windows (the same object as the day line and Morning strip) | D47 |
| 4-week calendar | Tier 1-3 events, IST time computed from the source time zone (DST-aware), PRE-OPEN / IN-SESSION / POST-CLOSE, consensus (with source), actual, surprise score, scenario -> sectors, shares, IV warning | D47, D49 |
| Results calendar | every F&O share: date from the board-meeting notice, before / during / after market, IV vs 20-day, IV-crush gate status, sympathy peers with results > 5 days away | D48, D23 |
| Policy pipeline | item, deciding body, expected date CONFIRMED / RUMOURED, shares, direction, priced-in (20-day move, IV), PENDING -> ANNOUNCED -> NOTIFIED with gazette link, days to decision | D37, D38 |
| Derivatives & exchange calendar | expiries from the contract master with holiday reasons ("Tue 24 Nov holiday -> Mon 23 Nov"; "Tue 26 Jan -> Mon 25 Jan"), new series, lot revisions, F&O additions/exclusions, rebalances, ex-dates inside series, ban entries/exits, holidays, special sessions | D2-D5 |

### P15 World drivers & sensitivities (Shift+F2) - not designed this round

Driver board as on Morning plus: overnight tape 15:30 -> 09:15 (US data with surprise, Fed, China 07:00-07:30, LME official, OPEC+,
ADR closes vs NSE close in INR); Asia open strip (Nikkei, Kospi, Hang Seng, SHFE/DCE daily, GIFT Nifty vs NIFTY close); the
driver x sector sensitivity matrix (next-day gap beta, same-direction hit rate, n, last update; n < 30 grey "rule of thumb");
decoupling flags ("metals ignored copper 4 of last 6 days"); release surprise table.

### P16 Data health & monitoring (Shift+F9, /status)

| Panel | Shows |
|---|---|
| Component grid | READY / LIMITED / DOWN (spec GREEN / AMBER / RED) with last-good time and reason: 4 Kite tokens; 12 connections (instruments, sentinel lag p50/p95, reconnects, mode = expected); quote sweep (dead tokens found); positions/orders sync; broker-stop checker; candle builder; chain sweep; greeks; sector engine; build-up; world feeds (session-aware); each news source; AI tiers; Telegram bots; SSE gateway; recorder; host (disk, memory, clock offset, certificates). The page turns itself red if status.json is older than 2 min. |
| Freshness limits table | the one table of limits by phase (see DESIGN_SYSTEM.md / DATA.md) |
| Source contracts | each file/API: last fetch, HTTP status, content date, rows, layout fingerprint, known-answer row present, final host |
| Expected-rate watch | items in the last 15 min vs usual for this time of day per source (catches "quiet = dead") |
| Cross-checks | Kite vs vendor B (if enabled), candles vs Kite historical, stream vs REST sweep, put-call parity forward vs future, sector index vs GIR basket, IV range 5-200 |
| Reconciliation | Kite vs NSE mismatches (lot, expiry, strike list, tick size, prev close, start-of-day OI vs bhavcopy) and shares blocked |
| Latency | exchange -> decoder -> SSE -> painted (glass check) p50/p95; event -> alert -> ack p50/p95 per channel |
| Alert health | audible alerts today vs budget 6 (and max 1 per 10 min), chattering alerts, unacknowledged P1s, median ack time, canary (synthetic story / tick every 15 min) age at page and Telegram |
| AI budget | spend by model and hour vs the $20 cap, ladder step (60 / 85 / 100%), cache-read %, validator rejects, latency per tier |
| Reports and incidents | 08:45 and 16:30 reports; safe-mode log; incidents with the "never again" check added; recorder bytes and gaps per stream |

### P17 Reference (Shift+F7) - read-only except the two editors

Universe (sector, lot, tick size, strike count, expiries per share), ban / MWPL with trend, corporate actions and adjustment factors,
holidays; sector map (versioned with effective dates, multiple weighted memberships, revenue vs cost drivers - copper is a COST for
cables) and the name table (symbol, ISIN, names, brands, parent, old names, ambiguity rules, per-alias precision, quarantined
aliases). Edits only outside market hours, logged.

### P18 Risk charter & Settings (Ctrl+,)

Every limit with value, reason, date and history; the size ladder; loosening = typed reason, effective next session, at most once a
week, never 09:00-15:35; tightening is immediate; 2 lock breaches in a month auto-tighten to 2 trades a day next month. Kill-switch
steps for Zerodha; broker-stop policy (SL-LIMIT at the backstop, limit offset ticks). Charges table with "last verified" date.
Alerts: P1 cannot be switched off; voice label on/off; Telegram routing (decisions vs system); phone push. Kite keys: status only,
never values. Collectors view-only in market hours. No setting can disable stale blocking, the loss lock or the 15:10 exit.

### P19 Replay & Practice (Shift+F10)

Any recorded day at 1x / 10x / 60x through the same code with only the data known at each moment; the 18 Nov proof case as a fixed
test (calls by about 09:20 on KALYANKJIL, TITAN, MANAPPURAM, MUTHOOTFIN, POLYCAB, SAIL, NATIONALUM, MOTHERSON); change gate (a prompt
or model change replays 20-30 days, compared on recall / precision / R); practice mode (the trader trades the replay under the same
gates, paper only). Always the REPLAY state (hatched violet border, watermark, no sound / Telegram / push); disabled 09:00-15:35 on
trading days.

### P20 Help & legend (?)

Every abbreviation (LB / SB / SC / LU, RVOL, ATR, R, RS, OR, MWPL, DTE), every colour, both tones, every state and every key;
tooltips appear on keyboard focus as well as hover.

### P21 Phone (/m) - a separate product, not a squeezed desktop

Four screens (bottom tab bar): **NOW** (in-trade line per position with share vs stop as the largest text, Rs to stop, broker stop
OK / NAKED, time stop, minutes to 15:10, thesis chip, verdict, the exit plan with the exact SL-LIMIT / limit price and a deep link to
the Kite app; when flat, the risk bar and the situation sentence) · **CALL** (the current call card in full, read-only: entry zone,
both stops, wrong-if, validity countdown, gate chips, STALE / LOCKED / COOLING states; the plan card in compact form, required if he
enters from the phone, otherwise the fill becomes an OWN TRADE with NO STOP) · **RISK** (risk bar, lock state, events in the next 2 h,
"I'm done today") · **ALERTS** (P1 list to acknowledge with a 0.6 s hold, alert history, health dot, the 07:15 note readable in 30 s
and the 15:45 scorecard). No charts beyond a sparkline, no news feed, no chain. Targets >= 48 px. Push: P1 always (distinct vibration),
GO NOW as WATCH with share, CALL/PUT, strike, trigger, wrong-if, valid-till; lock-screen text complete without opening ("STOP NEAR ·
TATASTEEL 151.9 · stop 151.8").

### P22 Telegram (two bots)

**Decisions bot:** GO NOW (as WATCH with entry, wrong-if, valid till hh:mm or premium <= X; edited to EXPIRED when it lapses),
follow-ups on TAKEN positions (BOOK HALF / MOVE STOP / EXIT / TIME STOP), 15:00 / 15:05 / 15:08, loss lock, notes, 15:45 scorecard.
**System bot:** P1 / P2 health alerts, always "recovered", P3 daily digest. An acknowledgement on the page edits the message to
"seen hh:mm:ss". Calls go only to the owner.

---------------------------------------------------------------------------------------------------------------------------------

## 6. Discipline rules enforced by the screens

### 6.1 Hard gates (GIR blocks the call / plan card; the trader is told which gate and its number)

1. **Data:** any input of the call older than its limit -> no call; GO NOW disabled "STALE 8s"; SAFE MODE on a critical family.
   Calls are built only from Facts (the AI gateway rejects any price, strike or level not in the facts it was given). A Kite vs NSE
   reference mismatch (or a Kite vs vendor-B CONFLICT) blocks that share. Pre-flight RED = READ-ONLY. Day NOT ARMED = WATCH only.
   An unparsed filing on the share holds GO NOW (READING FILING...).
2. **Locks:** day -2% net, 2 losses in a row, 2 full stop-outs in a day, give-back (peak >= +2R loses 50%), weekly -6%, "I'm done
   today" -> LOCKED, no dismiss, until 09:00 next session (weekly: until Monday). Monthly ladder (proposal, see 9): -10% half size /
   paper at 1 lot, -15% paper-only 5 sessions, -20% stop and method review.
3. **Size:** risk per trade <= 1% of capital from the governing stop incl. costs; 1 lot until 100 journalled trades; if 1 lot
   exceeds 1R -> SKIP with the capital needed (never tighten the stop to fit, never a cheaper far-OTM substitute). Never increase lots
   within a day after a loss.
4. **Exposure:** max 3 trades a day (incl. off-plan fills), max 2 open, never two positions on the same SECTOR or the same DRIVER
   (jewellers PUT + gold-loans PUT = one gold bet); premium outstanding <= the charter cap; premium + charges <= cash.
5. **Time:** no orders 09:15-09:20; GO NOW only 09:30-14:30 (14:00-14:30 only if break-even fits the minutes left); 14:30 no new
   entries; flat by 15:10.
6. **Option gate** (fail = NOT TRADABLE: reason - dropped, not scored lower): spread <= max(1 tick, 1% of mid) and <= 3 ticks;
   premium >= Rs 3; best-5 bid depth >= 4x my quantity; strike volume >= ~500 contracts by 10:00 (time-scaled); delta 0.45-0.65
   (ATM or 1 ITM; never far OTM); not in ban, MWPL < 85% (80-85% amber, half size; exits-ban day no PUT before 10:30); no results /
   board meeting / RBI / Budget within one session or the holding window; IV-crush filter (event within one session AND IV > 70th
   percentile, or ATM IV > 1.3x its 20-day average; while live IV history n < 60, IV / RV10 > 1.5 also blocks); last 2 sessions of
   the near month: no new near-month position; from T-5 the next month is the default if it passes this gate.
7. **Cost:** break-even share move by 15:10 (all costs + spread) <= half the remaining expected move; R:R >= 1.5 after costs.
8. **Chase:** share > 0.3 ATR past the trigger or premium > 8% above the planned entry -> "wait for pullback" (no amber); a GO NOW
   expires at the first of: 10 minutes, the no-chase premium, 0.3 ATR past trigger - on the page, Telegram and phone.
9. **Event windows** and day modes per section 3.2.
10. **Day type** (set by 10:00) decides which setups may reach GO NOW; a disallowed setup never does.
11. **No stop, no trade:** every position needs a governing share stop (= the one wrong-if) and a broker SL-LIMIT at the premium
    backstop (<= 30% premium loss) within 60 s of the fill; otherwise NO STOP (blocks the screen) / NO BROKER STOP (P1).
12. **Cooling:** 20 minutes after a losing exit, the plan card is disabled with the timer; GO NOW calls are suppressed and logged
    greyed.
13. **Thesis state** (added 18 Nov after the desk-trade review): a leg WEAKENING or BROKEN, or the call's sector FADING / FAILED,
    cannot produce GO NOW; the call shows as WATCH with the reason ("gate 13: leg 2 weakening"). A tightening, so it applies at once
    (6.3). Calls that fired before it are kept and scored with the leg state at fire time.

### 6.2 Soft rules (a pause, a reason, a log - never a block)

- Early exit before stop / invalidation / time stop -> exit coach (plan again, choices, one-word reason).
- Skipping a GO NOW asks a one-word reason. Re-entering a stopped share within 30 min asks a reason and is counted.
- Stops only tighten: a widening modify at the broker is detected and logged as a breach (and the backstop shows WIDENED).
- Averaging down is detected, flagged red and logged as a rule break.
- Low readiness at check-in suggests 1 trade or a stand-down day.
- At +1R with 1 lot: move the stop to break-even after costs and trail; BOOK HALF only when quantity >= 2 lots.
- Time stop belongs to the setup and is written on the plan card (default: not +0.5R within 45 min -> EXIT verdict + P2).
- Concentration in the same direction across correlated sectors warns.

### 6.3 Editing the rules

Limits tighten immediately; loosen only from the next session with a typed reason (never 09:00-15:35, at most once a week), with old
and new side by side; all changes appear in the weekly review. Size changes only through the monthly review's size ladder
(paper -> 1 lot -> 2 lots -> 1.25% risk), one step per month, never after a big win.

---------------------------------------------------------------------------------------------------------------------------------

## 7. The alerts model

- **One AlertManager, one SoundPlayer, two tones** (plus an optional spoken label for P1, through the same SoundPlayer).
- **P1 CRITICAL** (repeating low tone every 60 s until acknowledged with A+Enter or a click on the alert; phone push with distinct
  vibration; Telegram; phone call after 5 min unacknowledged with a position open): stop near / hit, NO STOP, NO BROKER STOP, FILL
  MISMATCH, stale data with a position open, positions sync > 10 s with a position open, 15:00 / 15:05 / 15:08 / 15:10 not flat,
  loss lock reached, EXPIRY-DAY ITM still open, GIR down (dead-man).
- **P2 ACTION** (one chime, once): GO NOW; follow-ups on a TAKEN position (BOOK HALF, MOVE STOP, EXIT on a broken leg, TIME STOP).
- **P3 SILENT** (page only, expires): GET READY, HOLD, sector confirmations, notes, news (impact 4-5 shows, never rings unless on a
  held share where it is P2), system info. GET READY never rings (spec 4.2 overruled).
- Alarm rule: an alert that does not demand a specific action by a specific time is silent information. Alarm budget: at most 6
  audible P2 per session outside the trader's own positions and at most 1 per 10 min; going over is reported in the scorecard as a
  design defect. Dedupe per share + signal + 15 min.
- All channels are sent in parallel (spec 4.6 "page 5 s before Telegram" overruled). Every alert carries "data age at send".
- An acknowledgement anywhere clears the page, phone and Telegram. M mutes P2 / P3 for 10 min only (countdown); P1 cannot be muted
  from the page; with a position open the critical tone cannot be muted at all.
- Toasts: max 3, in the alert tray (right column bottom), never over positions, the in-trade strip, exit controls or the chart's
  price axis. No browser tab opens by itself. In a trade, new calls queue silently except calls on the held share.
- REPLAY never makes sound or sends anything.

---------------------------------------------------------------------------------------------------------------------------------

## 8. The call lifecycle (the spine every page shows a view of)

WATCH -> GET READY (silent; from 09:20 once the sector confirms) -> GO NOW (with validity) -> TAKEN (plan card + matched Kite fill) /
SKIPPED (reason) / EXPIRED / SUPPRESSED (lock, cooling, stale, event) -> IN TRADE -> MOVE STOP / BOOK HALF / TRAIL -> EXITED (reason)
-> JOURNALLED -> SCORED (paper twin + real). Every state change is timestamped and immutable; a change is a new version with a reason.
The analyst's decision schema: {action BUY_CE / BUY_PE / NO_TRADE (default), symbol, strike, expiry (from the contract master), entry
zone, no-chase, share stop (= wrong-if), premium backstop, target, hold-until, time stop, setup, leg, evidence ids, confidence
(recorded, not shown on the card), valid-till}. Validators reject any price not in the given facts, a strike not in the chain, a stop
on the wrong side, two wrong-ifs, a missing leg or validity.

---------------------------------------------------------------------------------------------------------------------------------

## 9. Open decisions for the trader (GIR reminds, does not act)

1. Premium outstanding cap: the spec says 25% of capital; the risk coach recommends 10% (two 1%-risk positions use about 7%). GIR
   shows the meter against the charter value; default proposal 10%, hard ceiling 25%.
2. Monthly drawdown ladder (-10 / -15 / -20%) and the give-back lock are new protections - approve or not.
3. Safety fixes during the trial week (stale greying, broker-stop check, expiry from the contract master, rollover-aware build-up,
   the lock) are not "features"; recording (ATM IV, spreads, pre-open, interaction and alert logs) is not a page change. Allow them
   from 19 Nov?
4. Kite Connect terms for four apps on one account, and Kite's pre-filled order link (Publisher) - verify before relying on them.
5. Vendor B (a second free broker feed) - open an account or not.
6. A low-cost licensed world-data API for night drivers (instead of scraping) - approve a small budget or keep delayed free sources.

---------------------------------------------------------------------------------------------------------------------------------

## 10. Disagreements settled (expert vs expert, expert vs spec)

| # | Disagreement | Decision | Reason |
|---|---|---|---|
| 1 | Expiry "last Tuesday" (spec E, B6.4, S7.3) vs contract master; design C/D printed "Tue 24 Nov" | Expiry, lots, strikes, ban, MWPL and holidays come ONLY from that day's NSE / Kite files; "last Tuesday" must not exist in code. Shown as weekday + date + sessions left (incl. today) + holiday shift note; trading minutes on hover. | 23 Nov 2026 and 25 Jan 2027 are holiday-shifted Mondays; a rule would be wrong for two of three expiries on screen. |
| 2 | Calendar days ("23 Nov (5 days)") vs sessions | Sessions (and trading minutes) are the theta clock everywhere; calendar days never shown alone. | On Thu 19 Nov, 23 Nov is 3 sessions incl. today; theta and the T-5 rule run on sessions. |
| 3 | Sounds: seven by meaning (4.3) vs one (B7, B9, S5.5) vs two (terminal, trader, dealer) vs three (broker, UX, risk coach) | Two tones: CRITICAL (repeating until ack) and ACTION (once). Optional spoken label on P1. Everything else silent. | Direction by pitch cannot be parsed under stress; one tone cannot separate "act" from "danger"; three tones blur into each other. |
| 4 | GET READY rings (4.2) | Silent. | It is not actionable; ringing it doubles the alarm rate and trains dismissal before the GO NOW that matters. |
| 5 | CE green / PE red (5.5) vs labels (S5.10) | CALL / PUT as words; green/red only for price change and P&L; P&L colour follows the trader's money. | A winning PUT would otherwise be red. |
| 6 | Top bar 5.1 (SENSEX, PCR, FII/DII, AI spend) | Removed from the bar; replaced by the risk bar and day line. PCR / FII/DII live in labelled "context - never a reason" chips (Sectors, Futures & OI, Morning) with their dates; AI spend in the footer ladder chip and Health. | SENSEX duplicates NIFTY; PCR is noise per H; FII/DII is yesterday's EOD; AI spend is not a trading decision. |
| 7 | Keys: 1-9 = sectors (B9) vs 1-9 = panels (S5.10); F-keys collide with the browser (F5 reload); trader wanted 0-9 for pages | F1-F4, F6-F10 pages + Shift+F-keys; F5 captured and inert; F11/F12 untouched; 1-9 = sectors; "/" command line for everything. | F5 must never reload mid-trade; function keys are the terminal convention; digits stay for the method's first step. |
| 8 | Space -> Enter order ticket / any send button vs signal-only (S7.6, Legal) | No order ever leaves GIR. Plan card -> ticket copy (+ Kite's own pre-filled link if allowed) -> trader confirms in Kite -> fill read back automatically. | Signal-only is not an algo under SEBI; sending orders would bring the retail algo framework. |
| 9 | "I took it" button (trader) vs reading fills from Kite (dealer, UX) | Fills read from Kite (postbacks + 5 s poll); the plan card is the intent; a fill with no plan = OWN TRADE + NO STOP; mismatch = P1. | The broker is the source of truth for money; a manual button gets forgotten. |
| 10 | Stop lives only in GIR (spec) vs broker-side stop (trader, dealer, risk coach) | Share stop governs (GIR alarm); a broker SL-LIMIT at the premium backstop must rest within 60 s, else NO BROKER STOP (P1). GIR does not translate the share stop into the broker order every minute. | A laptop / GIR failure (the ANGELONE freeze class) must not leave a position naked; SL-M is generally not available on options (verify). |
| 11 | "Nothing is blocked - only a pause" (B5) vs a real loss lock (B1) | Exits are never blocked; entries are hard-blocked by the listed gates (6.1); everything else is a pause (6.2). LOCKED has no dismiss and prompts Zerodha's kill switch. | GIR cannot block Kite, so the lock is made real by the kill switch, reconciliation and the breach log. |
| 12 | Loss lock "2 losses in a row" vs "2 full stop-outs in a day", give-back rule, monthly ladder | Keep the spec's rule and add 2 stop-outs in a day and give-back (50% of a >= +2R peak); monthly ladder proposed (open decision). | Loss-win-loss slips through "in a row"; give-back is the classic tilt day. |
| 13 | "Never two in the same sector" vs "never two on the same driver" | Both: same sector or same driver is blocked. | Jewellers PUT + gold loans PUT is one gold bet. |
| 14 | 1 lot until 100 trades vs 1% risk | If 1 lot exceeds 1R incl. costs -> SKIP and show the capital needed; never tighten the stop or go far OTM to fit; at step 1, A+ score 6-7 also = SKIP. | One lot cannot be split; the rule protects him by rejecting trades. |
| 15 | "Book half at +1R" with 1 lot | At 1 lot: move the stop to break-even after costs and trail; BOOK HALF only at >= 2 lots. | A single lot is indivisible. |
| 16 | Premium cap 25% (spec) vs 10% (risk coach) | Meter shown vs the charter value; 10% proposed, 25% ceiling; trader decides (open decision 1). | With 1% risk and a 30% backstop, two positions use ~7%; 25% never binds. |
| 17 | Phone: exits only (UX, dealer, OI, risk) vs full plan (broker designer, trader) | Phone shows the full call card read-only (he executes in the Kite app anyway) and a compact plan card; GO NOW pushes arrive as WATCH; no charts, chain or news. | Hiding information does not stop phone entries; showing gates and locks does. |
| 18 | Desk layout (positions left vs right; members where) | Left: positions over sectors; centre: members over one chart; right: call card, queue, watch, news, alert tray. In-trade strip in the frame on every page. | Matches 7 of 10 visions; open risk top-left and pinned on every page; the call reads in the eye's last stop. |
| 19 | 5.2 "analyst's latest decision in big text first" vs open risk first | With a position open the in-trade strip is the largest type and the call card dims; the decision is big only when flat. | Open risk outranks opportunity. |
| 20 | Spec 5.2 seven tabs (incl. MARKET with the F&O tape and EARLY list) | Replaced by the page map in 2.1; the tape and EARLY list are dropped (they invite chasing); movers fold into Sectors. Every old feature must name the number it improves (5.3 vs B9 "one in = one out"). | Option chain, Futures & OI, Calendar, Health, Scorecard, Journal and Reference had no home. |
| 21 | Rotation separate (most) vs merged into Sectors (trader) | Separate page F3; Sectors carries a compact rank-change arrow per row. | The bump chart and money flow need space; the board must stay readable. |
| 22 | "No top-3 limit" (1.4) vs "max 3 call cards" (B9) | Both: Sectors and the Desk members table list every share (with a cut line); the Desk shows one primary call + max 2 queued rows. | Study surfaces are exhaustive; decision surfaces are single. |
| 23 | Laggard first (1.4) vs B4 (laggard wins ~40%) | Leader on a VWAP pullback ranks first; the laggard only when all five D8 conditions pass, labelled B. | The desk's measured record. |
| 24 | "Zone" by daily / 5-min RSI (1.3) vs H (RSI noise) | Zone = range used (|move| / ATR14) + distance to 20-day high/low in ATR. | Consistent with checklist D4 / D5 and H. |
| 25 | News confirms the sector (1.2) vs price confirms (news engineer) | Price, breadth, build-up and the driver confirm; news is the "why"; a confirmed move with no story is UNEXPLAINED, not held back. | Media lag would have delayed the 09:20 calls of 18 Nov. |
| 26 | Proof case wants calls ~09:20 vs entry from 09:30 | 09:20 GET READY with trigger scores "named before"; GO NOW only from 09:30; pre-09:30 moves are not GO NOW misses. | Keeps the trial fair and the entry window intact. |
| 27 | Importance scales: weight 1-5 (3.4), materiality 0-3 (S4), H/M/L | One impact scale 0-5 computed in code (model proposes event type and numbers; code sizes against the company); only 4-5 ring (on held shares); night 3 = conditional morning plan. | One vocabulary; the model never scores directly. |
| 28 | Broker calls in live blogs wake the analyst (2.4) vs H | INFO only; never wake, never evidence ("context, fade risk"). | H: broker calls fade in 1-2 days. |
| 29 | Live blogs every minute as core (3.1) | Kept for follow-ups and TV quotes; the alert path is filings (3-5 s), wires (15 s), TV speech-to-text, Telegram channels. | Live blogs are mostly retold news. |
| 30 | Staleness: S3 10 s vs 7.3 "2 min" vs designs 60 s vs 5 s | One freshness table (DESIGN_SYSTEM.md 6 / DATA.md 1.3): decision-critical instruments LIVE <= 2 s, LATE 2-5 s, STALE > 5 s; two ages per instrument (quote age, trade age); QUIET separate from STALE. | 7.3's 2 min is far too loose; Kite sends snapshots only on change, so an illiquid strike can be quiet on a healthy feed. |
| 31 | "An aggregate is as old as its oldest input" (B6.2) vs coverage | Sector / breadth figures need >= 90% of weight LIVE (shown as coverage); age = oldest counted input; below 90% = INCOMPLETE (never confirmed). | One quiet illiquid member must not make a sector stale. |
| 32 | Kite quote mode for the chain (S2) | FULL mode for every option GIR shows (quote mode has no OI, bid/ask or timestamps); full-chain OI by REST quote sweep every 120 s. | The option gate needs bid/ask; capacity is ample across 4 keys (verify limits). |
| 33 | Key 4 as cold standby (S9) | Hot duplicate of held / called strikes, their shares and the sentinels + the dead-token sweep; vendor B as an optional third path. | Two live paths on the instruments that carry open risk. |
| 34 | 4-10 updates/s per cell (S2, S5) vs Kite's ~1 snapshot/s | Paint batched at 2-4 Hz (max 4-10/s per cell kept as a ceiling); effort spent on measuring exchange-to-paint latency. | Kite cannot deliver more; repainting faster only adds noise. |
| 35 | IV history "no free source" (E4.1) / IV rank under 50 (basic gate) vs no history yet | Back-fill ~2 years of ATM IV from NSE F&O bhavcopy settle prices now (labelled "from closes"), record live daily from now; the gate's primary test is IV vs 20-day average x1.3 + event; rank shown with window, n and method; the broker's percentile is never used. | The gate works from week one, honestly labelled. |
| 36 | Term structure ADVANCED vs needed in expiry week | Near vs next ATM IV comparison is BASIC (chain buyer's comparison); full skew stays advanced. | The trial starts at T-3 of the November series. |
| 37 | "In expiry week prefer next month" vs thin next-month options | From T-5 the next month is the default only if it passes the gate; otherwise current-month ATM/ITM with a shorter time stop, or skip; never a new near-month position on the last 2 sessions. | Thin next-month stock options fail the spread gate. |
| 38 | Build-up without thresholds (C4, D6) | Tags need |price| >= 0.30% (or 0.15 x ATR14%), |OI| >= 1.0% / 15 min (0.6% / 2.0% since open), futures volume >= 1.5x normal, conviction > 0.05; all-month OI; ROLL in expiry week; OI older than 5 min greys the tag. Starting values re-fit monthly. | Otherwise every share gets a tag every minute. |
| 39 | Option-side build-up labels | Plain words on options (CALL WRITING / CALL BUYING / COVERING / UNWINDING + implied share direction); LB / SB / SC / LU only on futures. | A put "long build-up" is bearish. |
| 40 | Spread "1-2%" (E) | <= max(1 tick, 1% of mid) and <= 3 ticks; red display above 1%; premium >= Rs 3; depth >= 4x quantity. | Tick-aware for cheap premiums. |
| 41 | Hit-rate targets 55-62% (checklist) vs 35-45% (plan) | Two defined numbers: call direction hit rate and trade win rate after stops and costs; judged on expectancy in R with its range. | They measure different things. |
| 42 | Scorecard counts only named before / late / missed | Adds named-and-wrong, precision vs a random set of the same size, untriggered / expired, lead time, cause classes, achievable option move, mechanical baseline, alarm budget. | Otherwise the analyst learns to name everything. |
| 43 | "That setup's record" on the call (F) vs nothing beside the buy | Record only in the Why drawer with n (n < 30 "too early"); card face shows only "today: hit / miss / expired"; confidence only in the scorecard's calibration. | Automation bias; a record beside the buy reads as a promise. |
| 44 | TRIAL "no page changes" vs the scorecard page and safety fixes | The 15:45 scorecard (Telegram text + read-only page) is the trial's own instrument; recording starts now; safety fixes listed as open decision 3. | The spec itself requires the scorecard on the page. |
| 45 | Pre-market brief ADVANCED vs the trial's core | Morning page is BASIC. | The trial is judged on the 19:45 / 07:15 notes. |
| 46 | Minimum type 11 px (brief) vs 12 px (UX) vs 14-16 px names (5.5) | 11 px only for metadata (as-of, source, footer); 12 px minimum for any number a decision depends on; 13 px table numbers; 14 px share names; 20 px verdict; 26 px in-trade share-vs-stop. | Density at 1600x900 with legibility where it counts. |
| 47 | Pre-open primary source | NSE pre-open data (cross-checked with Kite) 09:00-09:08, saved daily; first option prints after 09:15 not used for IV or triggers. | Derivatives have no pre-open. |
| 48 | World driver moves "% today" vs since our close | Since 15:30 IST, with session state OPEN / CLOSED / HOLIDAY and z-score; times computed from source time zones (DST-aware). | Avoids double-counting moves priced the previous afternoon; hard-coded IST times are winter-only. |
| 49 | Brent / LME / Dalian / GIFT Nifty sources | MCX via Kite = live in-session proxies (shock freeze on MCX crude +-3%); licensed low-cost API or clearly labelled delayed source at night; LME / iron ore marked DAILY; GIFT Nifty via NSE IX collector. | They are not live on Kite. |
| 50 | Results "surprise vs estimates" (#37) | "vs last year / quarter" labelled, unless a licensed consensus is bought. | No reliable free consensus for most F&O shares. |
| 51 | TradingView as a news source (#39), Google News in the alert path | Dropped / backfill only. | Redistributed provider news; ~63 min late. |
| 52 | Thesis object (research analyst) not in the spec | Added: thesis with legs and INTACT / WEAKENING / BROKEN statuses on the day line; calls cite their leg; positions inherit leg status. | Lets the trader see a dead thesis without reading. |
| 53 | Notes schedule thin intraday | Add 10:00 day type, 12:30 midday, 14:30 manage-only line, silent 23:45 night delta; 07:15 leads with "changed since 19:45". | Scored like the others. |
| 54 | Validity window: 3 min (risk coach) vs 10 min | 10-minute cap, or the no-chase premium, or 0.3 ATR past trigger, whichever first. | Majority of visions; enough to act through Kite. |
| 55 | Arming the day (risk coach) - new | Adopted as a hard rule inside GIR: until pre-flight + 10-s check-in are done, calls are WATCH only. | Decide cold, act hot. |
| 56 | Interaction / alert logging (UX) not in the spec | Recorded from day one (no page change); feeds the behaviour panel and alarm budget. | The spec measures prices and AI but never the human. |
| 57 | Performance visible all day vs hidden | Edge / performance views greyed 09:15-15:10; the risk bar keeps day R small. | Big P&L during the session drives tilt. |
| 58 | 1366x768 and Windows 125% scaling | Desk at 1366 width collapses the right column to a tab rail (call card always visible as a 1-line summary); tested also at 1280x720 effective. | Real laptops differ from the design canvas. |

---
## TRADER FEEDBACK, 18 Nov evening (from the trader himself - every page designer, reviewer and the gaps check must answer it)
Answer both points in your responses (as "TRADER-1" and "TRADER-2": accepted / accepted with change / rejected, with the reason).

**TRADER-1 - the page tabs / F-keys are wrong on the drawings he saw.** On the Morning page the tab bar shows "F1" twice (Morning F1
and Desk F1 - the Shift of Shift+F1 is lost or too small to see), and the other F numbers are not in order: Morning shows no F3 and
no F7, every page jumps from F4 to F6, and the tab bars differ from page to page. He reads this as a mistake. Fix: ONE tab bar, the
same on every page, built from one list; no key shown twice; Shift keys written so they cannot be misread (e.g. "Shift F1" or a
separate row); if F5 stays free (browser reload), say why in the tab bar's "?" help or renumber so there is no unexplained gap.
Also weigh: Indian broker terminals (NEST / ODIN-style) use F1 = BUY and F2 = SELL - is copying F-keys for pages a habit risk for
a trader who also uses a broker terminal? And laptop F-keys often need the Fn key; the phone has none. Say what you recommend.

**TRADER-2 - the ANGELONE case must be covered.** 18 Nov: a "SEBI mulls MTF limits" story (TV reporter / wire / X, not SEBI's
own site) - ANGELONE fell at once; GIR said nothing. Show where this kind of incident appears on the pages: (a) BASKET SHOCK -
3+ shares of one policy basket (brokers: ANGELONE, BSE, CDSL, MCX, MOTILALOFS) moving the same way 1%+ inside 60 s on a volume
burst -> alarm within ~10 s "BROKERS falling together - news not found yet", GET READY only, never GO NOW on price alone;
(b) the cause found (X / TV speech-to-text / wire / regulator page) with the source and the seconds since the first source;
(c) "sources say / considering / no decision yet / denial" stories treated as news that wakes the analyst. See GIR_SPEC S12.

**TRADER-3 - he trades OPTIONS, about 90% of the time** (buys CE / PE on NSE stock options, intraday, exits by 15:10). Futures are
read as DATA (build-up, OI by month, basis), not as the trade. Every page must lead with the option: the strike, premium,
spread, depth, IV, the stop and target in premium AND share price. Do not design as if he trades the share or the future.

**TRADER-4 - "NOT TRADABLE" confused him.** On the Desk drawing TITAN shows "NOT TRADABLE - extended 1.38 ATR > 1.2" and
KALYANKJIL "x SPRD 1.6% - option gate: spread > 1%". By his method KALYANKJIL is exactly the share he wants (the laggard still
up / overbought in a falling sector = PE catch-down) and TITAN is a leader falling with short build-up. So: (a) never a bare
"NOT TRADABLE" - say the reason in plain words and what to do instead: "TOO LATE - already moved 1.4x its normal day; wait for a
bounce to VWAP" / "WIDE SPREAD 1.6% = Rs 900 lost on entry; try the 1,060 PE (spread 0.6%) or wait"; (b) the laggard / catch-down
share is a named role with its own trigger (GET READY - catch-down), not filtered out; (c) a block is only for hard rules (ban,
loss lock, stale data); everything else is a WARNING he can still take.

Tomorrow (19 Nov) he starts his trial on GIR. These drawings are not live yet - finish the design properly; it will be built
after his approval.

**TRADER-5 - TITAN was the share that FELL THE MOST on 18 Nov.** The drawings mark it "NOT TRADABLE - extended 1.38 ATR > 1.2".
That rule would have kept him out of the day's best PE. On a trend day (driver confirmed - gold down; sector confirmed; fresh
short build-up in the share's futures; price below VWAP making lower highs) an extended share keeps going. So "extended" must NOT
block: show "EXTENDED - enter on the bounce to VWAP / the first lower high, half size" with that price as the trigger, and
keep it at the top of the sector's list as the LEADER. Show on the Desk / Sectors / Share pages how TITAN on 18 Nov would look.

**TRADER-6 - the index readings and critical market data are missing from the drawings.** The top bar shows only NIFTY. On EVERY
page, always visible, one fixed market strip: NIFTY 50, BANKNIFTY, SENSEX (and FINNIFTY / MIDCPNIFTY if room) - price, change,
% and a tiny sparkline; INDIA VIX; GIFT Nifty (pre-open and night); USD/INR; Brent; gold; FII / DII cash and F&O (yesterday +
provisional); PCR (NIFTY / BANKNIFTY); A/D of F&O shares; expiry + days left; the BAN pill; market status and data age.
(The old LAYOUT.md top bar had NIFTY / BANKNIFTY / SENSEX / VIX / EXPIRY / PCR / FII-DII / BAN - nothing from it may be lost.)

**TRADER-7 - he wants to see a drawing of EVERY F-key page.** Drawn so far: Morning (Shift F1), Desk (F1, hunt + trade + plan
card), Sectors (F2), News (F4), Positions (F6), Share (F7), Analyst (F8), Chain (F9), Futures & OI (F10), Calls & Scorecard
(Shift F8), Health (Shift F9), Phone. NOT drawn yet: F3 Rotation, Shift F2 World drivers, Shift F4 Calendar, Shift F6 Journal,
Shift F7 Reference, Shift F10 Replay, Ctrl+, Charter & Settings, ? Help. Every one must be designed, reviewed and voted like
the others, with the same tab bar and the same market strip.
