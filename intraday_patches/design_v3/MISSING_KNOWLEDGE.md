# MISSING KNOWLEDGE - what a top Indian F&O desk knows and does daily that GIR's plan lacks (binding gap list, 19 Nov 2026)

The trader, 19 Nov: "So the expert desk is not telling you all these ideas before I ask? They are the ones who should know the
F&O market." He is right. GIR's experts only answered when asked, and the chain engine (E2b) only fires when a driver moves. So on a
quiet day, or about rules and calendars, the desk said nothing. Most of what follows already sits in the specs as a fact, but no
job pushes it to him. Item 0 fixes that; items 1-33 are what it must push and build.

Merged from three expert answers (senior broker, prop option buyer, head of research), with repeats removed. Ranked by money made or
saved, most first. Labels: **[V]** = checked on the web on 19 Nov 2026; **[E]** = desk estimate, to be measured on GIR's own
recordings and history before it is quoted as a rate or drives a CE / PE call. Effort: **S** = under a day, **M** = 1-3 days,
**L** = a week or more.

---

## 0. DESK PUSH - a standing nightly job that tells him without being asked (the missing piece)
- **What:** every 19:45 note gets a fixed block, built by code from the calendar, the knowledge base and the regime sheet (item 20):
  "WHAT THE DESK KNOWS FOR THE NEXT 10 SESSIONS", always with five parts: (a) dates - expiries, holidays, central banks, index
  changes, data, results, lock-ins, ex-dates; (b) chain ideas (E2b) and stock setups (item 13); (c) positioning - FII tide,
  rollover, near-ban names; (d) broker and exchange rules that change tomorrow; (e) one lesson. Each line carries its CE / PE effect.
  Plus a Saturday audit, "what a 15-year desk does that GIR does not", which adds items to this file.
- **Why:** he hears it days before, not after. Today he only gets what he asks for.
- **Example:** on 19 Nov the block should already say: Mon 23 Nov = Nov expiry (Tue 24 holiday), Dec strikes only from Fri 20;
  MSCI changes at the close of Mon 30 Nov; RBI decision Fri 4 Dec 10:00 after the Oct hike.
- **Where in GIR:** new step E2c after E2b; N19 note template; Morning page; Calendar (⇧F4). The 15:45 audit scores it: any event
  that moved a share and was not in the block is a MISS.
- **Effort:** M

## 1. Fix the Nov expiry date: Mon 23 Nov, not 24 Nov
- **What:** Tue 24 Nov 2026 is an NSE holiday (Guru Nanak Jayanti) [V], so Nov stock options expire Mon 23 Nov.
  COLLECTION_PLAN.md (lines ~303, 310, 648, 661, 663, 711) still says 24 Nov. BUILD_PLAN F11, DATA, SHELL, IA and CHAIN_OF_EVENTS
  already say 23 Nov.
- **Why:** the wrong date breaks theta, expiry-week mode and the physical-settlement warning, and Fri 20 is really E-1.
- **Example:** WATCH_20NOV_demo recommends "ATM, Nov expiry" on Fri 20 Nov - weekend decay plus expiry-day margin risk, against
  rule E7.
- **Where in GIR:** correct COLLECTION_PLAN.md and WATCH_20NOV_demo; a test that the expiry date comes only from the contract
  master, never hard-coded.
- **Effort:** S

## 2. Physical settlement and broker expiry-week rules (biggest money-saver; 0 hits in the plan)
- **What:** stock options settle by physical delivery. An ITM long held to the close becomes an obligation to buy or deliver the
  full shares. Zerodha blocks a delivery margin on ITM longs from about E-4, rising to about 25% of contract value on E-1 and about
  50% on expiry day, charges near-spot OTM strikes on expiry day, can block fresh current-month buys and square off near expiry
  [V from policy page and snippets; the exact table has changed over time and support.zerodha.com was blocked here - verify].
  STT on an exercised option is 0.15% of intrinsic value; on premium 0.15% on the sell side (Budget 2026, from 1 Apr 2026) [V].
- **Why:** even a 1-lot intraday buy can be rejected or block lakhs. ITM stock options on E-1 / E-day often trade below intrinsic
  because holders dump them - "cheap" for a trap reason [E].
- **Example:** from Fri 20 Nov, Dec series only; Nov is never picked.
- **Where in GIR:** E7 hard-blocks current-month strikes from E-4 (today it only says "prefer"); gate chip "PHYSICAL"; plan card
  shows "margin blocked Rs X"; a dated BROKER-RULES table on F11, refreshed by the Saturday regulatory watch; the 20 Nov note says
  "Monday = Nov expiry: DEC strikes only".
- **Effort:** M

## 3. Expiry-day mode for Mon 23 Nov
- **What:** a double expiry - stock monthly plus, most likely, the NIFTY weekly moved from Tue to Mon by the holiday [E - take the
  date from the contract master]. Shares pin to their biggest-OI strikes after about 13:30, physical-settlement unwinding whips
  ITM-heavy names, more chop and theta [E].
- **Why:** expiry afternoons eat option buyers' premium.
- **Example:** rule for 23 Nov: half size, A setups only, Dec series, no new entry after 14:00.
- **Where in GIR:** E0 day type EXPIRY; Morning page banner; E9 size.
- **Effort:** S

## 4. Profit lock, give-back rule and the loud "no-trade day" (the plan has only a loss lock)
- **What:** after +3R or 2 winners, only A setups at half size; if today's P&L falls 40% from its peak, stop for the day; no size
  increase during a winning streak; after a big winning day the first trade next day is 1 lot. By 10:00 the desk says "range day:
  0-1 trades" and means it [E].
- **Why:** an option buyer's best days are given back in the 13:00-15:00 chop and through overconfidence after wins.
- **Example:** a +Rs 9,000 morning turned into +Rs 2,000 by two afternoon "one more" trades - the most common prop-desk journal
  pattern [E].
- **Where in GIR:** E9 lock logic; R02 strip shows "peak today / give-back room"; E6 day type as a hero line on the Desk; journal
  tag "after-win trade".
- **Effort:** S

## 5. Weekend and holiday theta: count calendar days, not trading minutes
- **What:** GIR's Black-76 (B6.9, F26 / J77) treats Sat-Sun and holidays as zero time. Market makers mark premiums down through
  Friday afternoon and the day before a holiday, so GIR reads a false "IV falling / IV cheap" on Friday and an IV jump on Monday.
- **Why:** it explains "the share moved but my premium did not", and decides whether a Friday entry can pay.
- **Example:** a Rs 1,000 share, IV 30%, Dec ATM about Rs 38: Fri 20 to Mon 23 costs about Rs 1.5, about 4% of premium - one
  seventh of the 30% premium stop [E]. Dec options also price the Tue 24 holiday on Mon 23.
- **Where in GIR:** IV engine on calendar time with a fitted weight for weekend / holiday days; B2 "decay to planned exit" in
  calendar days; "weekend decay priced" chip on Thu / Fri cards; entries after 13:00 on Friday or a pre-holiday need a larger
  expected move; IV records tagged by weekday and time; check against NSE chain IV.
- **Effort:** M

## 6. Index / VIX kill switch
- **What:** NIFTY below VWAP and its day low with India VIX +6-8% intraday = no new CE, tighter CE stops, PE ideas only
  (thresholds [E], set by replay).
- **Why:** a good sector call still fails when the whole market turns. Today only Brent and USD/INR trigger a live freeze.
- **Example:** a risk-off afternoon after a European sell-off: the auto CE from the chain stops being taken.
- **Where in GIR:** E1 live freeze; E10 follow-ups on his open CEs.
- **Effort:** S

## 7. Event-time IV-crush filter: before 15:10 or after the close?
- **What:** he is flat by 15:10, so a result due after today's close is not a crush risk today; IV usually rises into it during the
  day, which offsets theta [E]. The real risk is an event before 15:10 today. The current rule ("within one session" plus IV above
  the 70th percentile) blocks the good pre-event days.
- **Why:** frees good trades and keeps the dangerous ones blocked.
- **Example:** a company reporting at 16:30 on Thursday: Thursday morning is a buy day if the setup is there, not a block.
- **Where in GIR:** S8 filter and the E7 gate; prove on recorded R1 IV around every result.
- **Effort:** S

## 8. Is the option cheap? Implied move vs expected move, plus a what-if premium grid
- **What:** ATM straddle / spot = the market's implied move, scaled to today. Compare with HV10 / HV20, ATR left today and the
  setup's measured median move; buy only when the expected move is bigger. For results, compare with the median of the last 8
  results moves. Add a grid: the option's price at 11:00, 13:00 and 15:10 for a share move of +-0.5 / 1 / 1.5 / 2% and IV +-2
  points.
- **Why:** shows at a glance whether the trade can pay after theta and IV. Today only the break-even move exists.
- **Example:** E7 column "implied 1.8% / ATR-left 1.1% / setup median 1.4%" = option too dear, skip.
- **Where in GIR:** E7 strike chooser (R42) and the Plan card (Space); HV10 next to R1.
- **Effort:** M

## 9. The intraday IV clock and how IV moves with price
- **What:** stock-option IV is usually highest 09:15-09:45 and bleeds off by about 10:30 on days without an event [E]. IV usually
  falls on a slow grind up and rises on a fall; exceptions are squeezes and news gaps, where call IV jumps [E].
- **Why:** buying at the open overpays for IV even when the direction is right. A PE in a falling sector gets an IV tailwind; a CE
  on a slow rally earns less than its delta implies.
- **Example:** before 09:45 prefer 1 strike ITM or wait; ITM CE (less vega) for grinds, ATM PE for breakdowns; no CE once ATM IV is
  already +30-40%.
- **Where in GIR:** E7 "expected IV effect" line and "IV vs its own 10:30 median", learned from R1 minute IV (the plan parks skew
  under "advanced" today).
- **Effort:** M

## 10. Liquidity tiers before naming a share, and order-execution craft
- **What:** an A / B / C liquidity list from GIR's own recorded option spreads (09:30 / 12:00 / 14:30, E4 #4); C = name only, no
  strike. Execution: LIMIT orders at mid, chase at most 2 ticks then walk away; NSE has no SL-M for options and an SL-limit can be
  skipped in a fast move, so GIR's alert on the share level is the main stop, emergency exit at the bid; NRML for buys so MIS auto
  square-off and its fee do not apply [E - verify the fee].
- **Why:** a note must not name options that cannot be traded at size, and slippage is a silent cost.
- **Example:** the 20 Nov demo names CROMPTON, BLUESTARCO, SONACOMS, HINDCOPPER - options likely thin [E].
- **Where in GIR:** KB liquidity_tier applied in E2 / E2b before a name appears; plan card "LIMIT Rs X, no fill above Rs Y";
  journal records fill vs mid; Charter page.
- **Effort:** S (tiers) + S (execution)

## 11. The rate-hike chain, RBI 4 Dec and the Fed 10 Dec
- **What:** RBI raised the repo 25 bp to 5.50% on 7 Oct 2026, stance "calibrated tightening" [V, single source - verify].
  CHAIN_OF_EVENTS row 14 covers only cuts. Hawkish mirror: PE bias BAJFINANCE, CHOLAFIN, SHRIRAMFIN, LICHSGFIN (cost of funds);
  DLF, GODREJPROP, LODHA; EMI-sensitive autos; large banks with repo-linked books mixed. MPC 2-4 Dec, decision Fri 4 Dec ~10:00
  (in session) [V]. FOMC 8-9 Dec, decision about 00:30 IST Thu 10 Dec with the dot plot [V].
- **Why:** IV in rate-sensitive names builds into 4 Dec, so buying their options on 2-3 Dec pays for crush.
- **Example:** 4 Dec: flat until 10:00 + 30 min, then trade the reaction once.
- **Where in GIR:** new row 14b in CHAIN_OF_EVENTS C and SECTOR_LINKS B, sign per share from its liability mix; replay 7 Oct 2026
  before 4 Dec; E0 lock; notes of 1-3 Dec and 9 Dec.
- **Effort:** M

## 12. Week-ahead event playbook (a PLAN per event, not just a calendar row)
- **What:** sent unasked Friday 19:45 and Sunday 20:00, refreshed nightly. For each event: who moves, which side, when IV starts
  building, the no-buy window. Next sessions (verified unless marked):
  - Fri 20 Nov: weekend theta, E-1. Mon 23 Nov: Nov expiry. Tue 24 Nov: NSE holiday. Wed 25 Nov: first Dec-only day.
  - Thu 26 Nov: US closed; Fri 27 Nov: US half day - thin overnight cues.
  - Mon 30 Nov: MSCI at the close; China PMI 07:00; Q2 GDP 16:00 (a 1 Dec gap trade).
  - Tue 1 Dec: auto sales, GST, UPI, PMIs (a second push for autos on top of the copper chain).
  - Fri 4 Dec 10:00: RBI. Thu 10 Dec ~00:30 IST: Fed. Mid-Dec: Accenture (date not confirmed).
  - Fri 25 Dec: NSE holiday; Tue 29 Dec: Dec expiry; 2nd week Jan: Q3 results (TCS first); Mon 25 Jan: Jan expiry (Tue 26
    Republic Day); Mon 1 Feb 2027: Budget (in session).
- **Why:** turns dates he never hears into planned trades and avoided traps.
- **Where in GIR:** weekly section in N19; "plan" column on Calendar (⇧F4); new event fields playbook / IV-build start / no-buy
  window; E0 locks.
- **Effort:** M

## 13. Nightly stock-setup scan across all ~200 F&O shares (ideas without a driver)
- **What:** at 18:30 from bhav_fo + R1 IV: (a) squeeze - NR7 or inside day, ATR5/ATR20 < 0.7, IV rank < 30; (b) squeeze fuel - 3+
  days of short build-up into support, OI at a 3-month high; (c) day-1 range break with OI and delivery up = day-2 candidate;
  (d) the day after a 3%+ move from the share's own history (E4 #7); (e) day-2/3 drift after results. Plus: the 15:45 audit asks
  "which scan would have named this mover", and a weekly list of big no-driver moves GIR missed.
- **Why:** the S8 patterns are only detected live today. Knowing the 5 names the night before means entering at the trigger, not
  late; the move and the IV expansion both pay.
- **Example:** "STOCK SETUPS" in TOMORROW'S OPTION WATCH, max 5, each with strike, trigger and cancel.
- **Where in GIR:** step E2c; N19; scored in the 15:45 audit (E15) and the B5 ledger like the chains.
- **Effort:** L

## 14. Rollover readout in expiry week (window open now, 19-23 Nov)
- **What:** per share and sector, rollover % and roll cost / Dec basis against the last 3 expiries, read with price: high rollover
  + rising price + paying to roll = longs carried (CE bias early Dec); high rollover + falling price + cheap roll = shorts carried
  (PE bias or squeeze fuel); low rollover after a rally = longs not committed, the move can fade. Market-wide rollover and NIFTY roll
  cost set the Dec-series tone. The data is collected (D59); no rule uses it.
- **Why:** sets the side for the first Dec-series sessions.
- **Example:** ASHOKLEY or MARUTI after +6-9% with low rollover = fade risk.
- **Where in GIR:** ROLL column with a verdict on F10; "ROLLOVER READ" in the 20-23 Nov notes; input to the E2c scan.
- **Effort:** M

## 15. Block deals, QIPs, OFS and stake-sale term sheets
- **What:** promoter / PE term sheets ("x% at floor price, y% discount") leak 19:00-23:00; the deal crosses in the 08:45-09:00
  block window; the share opens near the floor, then often recovers [E]. The plan calls these noise.
- **Why:** avoids a CE straight into a supply open, and gives a later absorption trade.
- **Example:** ITC, 28 May 2025: BAT sold 2.5% at Rs 413 (4.8% discount); ITC opened -4.8%, later only -1.15% [V].
- **Where in GIR:** watched words "term sheet / floor price / block deal" in the news parser and E12; risk flag in the 19:45 and
  07:15 notes ("no CE this morning"); J69 08:45 window check; new setup "block absorption" (CE only after a VWAP reclaim, 10:00 or
  later; PE only if it opens above the floor and breaks it) - log 3 months before trusting it.
- **Effort:** M

## 16. MSCI Nov 2026 review and passive flows generally
- **What:** effective at the close of Mon 30 Nov. Added LICI, COFORGE, ADANIGREEN, MEESHO; removed PIIND [V]. About $2 bn of passive
  flow; estimates COFORGE ~$630m, LICI ~$468m, ADANIGREEN ~$348m in, PIIND ~$119m out [V press, secondary - verify]. Pattern: drift
  into the date, reversal the day after [E]. Rank by inflow / 20-day average volume (over 2-3 days' volume is big).
- **Why:** the flow trades in the closing session after his 15:10 exit, so his trades are the run-up and the 1 Dec reversal; the
  close also distorts that day's RVOL, OI and VWAP.
- **Example:** PIIND PE drift 25-30 Nov on a weak tape; never hold through 30 Nov; 1 Dec reversal idea. Check each name's F&O
  status.
- **Where in GIR:** event rows with estimated passive flow; E0 "rebalance day" flag and the existing 14:45 lock; RVOL / OI
  baselines exclude rebalance days; "INDEX FLOW" tag on the Share page; notes from 25 Nov ("watch / no chase").
- **Effort:** S

## 17. FII positioning as the day's tide, and who holds the free float
- **What:** FII index-futures long ratio and its daily change, FII net change in stock-futures OI, NSDL fortnightly sector FPI
  flows. Extreme short (long under ~15-20%) has often come before short-covering rallies [E]. On heavy FII-selling days high-FII
  names fall hardest; MF / retail-heavy names get the SIP bid on dips [E]. The plan files participant OI (J20) and fii_stats (J21)
  as noise.
- **Why:** sets the bias for heavyweight CE / PE and shows which side is crowded. Never a call on its own.
- **Example:** 28 Oct 2026: FIIs only 11.7% long in index futures (35,808 long vs 270,850 short) [V]; by 9 Nov shorts ~73% and
  falling, FPIs buying $5.68 bn in Nov [V].
- **Where in GIR:** one "tide" line in N19 and the Morning page; E0 day expectation; E6 rank feature on flow days from dossier
  shareholding; tested in the scorecard.
- **Effort:** S

## 18. Near-ban as an idea source, not only a gate
- **What:** a share at 85-95% of MWPL after a sharp move has crowded positions and is often a next-day mover. In ban OI can only
  fall, so moves come from covering (sharp CE on reversal); on ban exit fresh positions return and spreads normalise. An option in
  a share that may enter ban tomorrow can be hard to exit.
- **Why:** both an idea list and a trap warning.
- **Example:** N19 line "near-ban / entering / leaving" with the direction of the build-up.
- **Where in GIR:** daily MWPL feed into E1 ideas; E7 note "may enter ban".
- **Effort:** S

## 19. Index weekly expiry distorts heavyweights
- **What:** NIFTY weekly (Tue) and SENSEX weekly (Thu) gamma pins or jerks RELIANCE, HDFCBANK, ICICIBANK, INFY, TCS, BHARTIARTL, LT,
  SBIN in the last 90-120 minutes [E]. The calendar row exists; no engine rule does.
- **Why:** a heavyweight stock-option entry on those afternoons fights index gamma.
- **Example:** rule: no fresh stock-option entry in those names after 13:30-13:45 on those days (or wider stops), and keep
  heavyweight-led moves out of sector confirmation.
- **Where in GIR:** E0 per-share tag; E3 equal-weight check; E9.
- **Effort:** S

## 20. Regime sheet and VIX rules (weekly, with a nightly delta)
- **What:** records India VIX band (about 15-17 this week [V]), FII cash and futures trend, rate cycle, crude band, inflation (WPI
  near 12% per reports [V, single source]), NIFTY trend, and which setups paid over the last 20 sessions (breakout vs fade, leaders
  vs laggards). VIX rules [E]: under ~12 cheap premiums but small moves - require RVOL > 2 and fewer trades; rising with NIFTY =
  fragile; over ~18-20 rich premiums and wide spreads - ITM (delta ~0.6), half size, faster targets.
- **Why:** a chain's hit rate changes with the regime; cheap-input chains fail on risk-off / FII-selling days (Oct 2024 case).
- **Where in GIR:** data/kb/regime.json; B4 grade +1 / -1 for regime fit; E0 "option-price regime"; E6 / E7 size and delta; hero
  line on the Morning page.
- **Effort:** M

## 21. Monthly numbers: expected vs actual (the bar to beat, written the evening before)
- **What:** auto sales (VAHAN month-to-date), UPI (PAYTM), DGCA traffic (INDIGO), insurance premiums (SBILIFE, HDFCLIFE, ICICIPRULI,
  LICI), AMFI flows (HDFCAMC, NAM-INDIA, CAMS), demat adds (CDSL, ANGELONE), IEX volume, coal offtake, quarter-start business
  updates (HDFCBANK, BAJFINANCE, TITAN, DMART; 1-7 Jan). Most are only a calendar line today.
- **Why:** the print becomes a trade, not news.
- **Example:** 30 Nov note: "due tomorrow: Nov auto sales, bar = X from VAHAN".
- **Where in GIR:** E1 surprise score per company number; "due tomorrow, bar = X" line in N19.
- **Effort:** M

## 22. Corporate actions in option prices
- **What:** on the ex-dividend date the share drops by the dividend - a free move for PE, a drag on CE. Special dividends and
  demergers adjust strikes and lots.
- **Example:** big payers COALINDIA, ONGC, ITC, VEDL.
- **Where in GIR:** ex-date list in N19; E7 warning.
- **Effort:** S

## 23. Group and parent contagion, governance shocks
- **What:** baskets that move together - Adani group; TMPV with JLR; HINDALCO with Novelis; BAJFINANCE with BAJAJFINSV; M&M with
  M&MFIN. Shocks: auditor resignation, rating downgrade, raids, a foreign indictment.
- **Example:** Adani names fell about 20%+ on 21 Nov 2024 [E]; the JLR cyberattack (Sep 2025) hit the parent [E].
- **Where in GIR:** E12 basket-shock baskets and the event playbook (regulator-only today).
- **Effort:** M

## 24. Charges, lots and pre-open confirmations
- **What:** STT on options 0.15% of premium (sell side), futures 0.05%, from 1 Apr 2026 [V] - the charges table (D26) must use it.
  NSE revised lot sizes for 9 stocks from 28 Oct 2026 (circular 134/2026) [V] - lots only from the contract file. F&O futures
  pre-open 09:00-09:15 since 8 Dec 2025 [V] - already J72; keep it as a step-B input.
- **Where in GIR:** D26 charges table; contract master; Charter & Settings.
- **Effort:** S

## 25. Time-of-day habits
- **What:** Europe opens 13:30 IST in winter (since 25 Oct) and often turns metals, IT and the index 13:30-14:15 [E]; US index
  futures move IT during the session; stock-option liquidity thins after 14:45; Friday afternoon and the day before a holiday: ITM
  only, or skip.
- **Where in GIR:** E1 live drivers; E8 entry window; S8 #4 window - measured from recordings first.
- **Effort:** S

## 26. Seasonal liquidity
- **What:** 15 Dec advance tax and the 20th GST outflow tighten money-market rates - weighs on banks and NBFCs that week [E];
  20 Dec-2 Jan foreign desks away - wider spreads, fewer trend days, more theta bleed: cut trade count, require breadth 80%+ [E].
- **Where in GIR:** Calendar rows; regime sheet; E0 size.
- **Effort:** S

## 27. Lock-in expiries
- **What:** about 116 companies unlock between 9 Nov 2026 and 26 Feb 2027 (about $35 bn; e.g. Jio Platforms 25 Nov) [V, Nuvama via
  press]. Supply overhang on unlock day for new-age F&O names. SHARE_DOSSIER marks this "NOT PLANNED".
- **Where in GIR:** Calendar rows and the item-0 block; act only on F&O names.
- **Effort:** S

## 28. Price-hike calendar (the revenue channel)
- **What:** steel mills' monthly list prices; cement dealer checks in the first week; January auto price hikes, usually announced
  Nov-Dec [E]; paints, tyres, telecom tariffs.
- **Where in GIR:** chain-map revenue rows; watched words "price hike / cut" mapped to shares.
- **Effort:** M

## 29. Global peers' results read-across
- **What:** Accenture and Micron in Dec (verify dates) for IT and EMS; JLR retail and Novelis; ArcelorMittal and Alcoa in Jan for
  metals.
- **Where in GIR:** Calendar; chain row 26 widened to global peers; read in the 07:15 note.
- **Effort:** S

## 30. Refining cracks / GRMs and OMC marketing margins as a chain
- **What:** Brent alone misses days when Brent is flat but diesel cracks jump (RELIANCE and refiners gain) or OMC margins shrink.
  The data is already a secondary W1 item.
- **Where in GIR:** new chain-table row; E1 threshold; World page.
- **Effort:** M

## 31. Big broker rating changes: measure them, do not dismiss them
- **What:** a double downgrade or a 20%+ target change by a major foreign house moves large caps 2-5% at the open [E]. Log house,
  change, gap and first-hour path; let the record decide trade or fade.
- **Where in GIR:** J59 parser to the events table; a 15:45 study.
- **Effort:** M

## 32. A reliability score for each reporter
- **What:** every reporter or handle breaking "sources say" stories gets a record - confirmed within 48 h or denied. A scoop from a
  reporter right 90% of the time reaches GET READY faster.
- **Where in GIR:** E12 step 2; knowledge base.
- **Effort:** M

## 33. Live con-call listening (results season from mid-Jan)
- **What:** guidance words on the management call often reverse the first move on the numbers and drive day-2 drift (setup B+).
  Get call schedules and webcast links from filings; speech-to-text on F&O names in market hours; watch "guidance / margin / order
  book".
- **Where in GIR:** J60 + the existing TV speech-to-text pipeline; E12 wake; Share page; day-2 setup.
- **Effort:** L

---

**Facts checked on the web (19 Nov 2026):** NSE 24 Nov holiday; Budget 2026 STT rates; MSCI Nov 2026 names and date; RBI MPC 2-4 Dec
and the Oct hike (single source); FOMC 8-9 Dec; GDP on 30 Nov; Nuvama lock-in count; FII positioning figures; ITC block deal; lot
revision of 28 Oct 2026; F&O pre-open. Zerodha physical-settlement figures come from search snippets and the policy page as quoted;
the experts' figures differ slightly (25% of contract value vs a 25% / 50% ladder), so verify before relying on them.
Everything marked [E] is desk experience to be measured on GIR's history before it is quoted as a rate. Not investment advice.
