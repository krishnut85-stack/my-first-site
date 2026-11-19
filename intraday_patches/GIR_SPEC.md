# GIR_SPEC - what GIR must be (the single source of truth, 18 Nov)

For the Claude session running ON the GIR server (/home/globalbot/intraday). Build GIR exactly to this file. When the trader adds
something, this file is updated and you are told to re-read it.

## TRIAL - the top rule (from 19 Nov, one week)

The trader is building a fail-safe F&O trading system. It works as a chain, and every link must hold:

    DATA  ->  the ANALYST and his TEAM (the agents)  ->  GIR (the page and the alerts)  ->  the TRADER

- **Data** (prices, futures and options, sectors, world prices, news) is collected by the agents.
- **The analyst leads the team.** Each agent is a team member with one job; the analyst turns their findings into decisions.
  A weak or silent team member is the analyst's problem to report and fix.
- **GIR presents the analyst's decisions** clearly (section 5), and **the trader acts**.

On 18 Nov about $30 of AI was spent and the chain failed: the drivers moved the night before (copper at its lowest since July,
gold down, US tech selling off, a strong dollar), the sectors confirmed at 09:20, and the analyst named none of the shares in time.

**For one week, the analyst is judged on one thing only - did it tell the trader the right thing, at the right time:**
1. **19:45 and 07:15 note:** did it name the sectors and the F&O shares that actually moved the next day, before they moved?
2. **By 09:30:** did it say GO NOW (or GET READY) on the right shares, with trigger, stop and target?
3. **During the day:** did it say HOLD, BOOK HALF or EXIT at the right time on its own calls?

**Daily scorecard at 15:45, in plain words, sent to the trader** (page + the decisions Telegram channel):
- what the analyst said and when (19:45, 07:15, every GO NOW / GET READY / follow-up);
- what actually happened: every F&O share that moved 2%+, and every sector that moved 1%+;
- the score: named before the move / named late / missed - with the reason for every late or missed one, and which team
  member (agent) failed;
- each team member's day: ran or not, found what, woke the analyst or not;
- the AI spend by model, and the cost per useful call.

**During the trial: no new features and no page changes** - only fixes that make the analyst name the right shares earlier,
and the cost cap (section 6). If the scorecard does not improve within the week, change how the analyst thinks (its method and
inputs), not how the page looks.

**How the analyst writes** - like an experienced analyst at a trading desk, never a list of news:
- WHAT'S HAPPENING - the market and the drivers in two or three sentences;
- WHAT I'D DO NOW - GO NOW / GET READY · share · PE or CE · strike · trigger · stop · target · hold until, then why in one line;
- WHAT I'D AVOID - shares that have already used their room;
- WHAT WOULD CHANGE MY VIEW - and "I'll tell you at once".

**The page order (when page work resumes after the trial):** 1 Market (indices, mood in one sentence, breadth, FII/DII, PCR,
expiry, ban) · 2 Sector performance (every sector as a bar) · 3 Sector rotation (money out -> in, drivers, sector run times) ·
4 Trade plans (every share in position in each moving sector) · 5 News that matters (only news that moves F&O shares, with its
effect) · the analyst's desk note always on the right.

## THE CHECKLIST - what the analyst checks to pick the right share (from six expert reviews, 18 Nov)

GIR is used ONLY for F&O options trading: the trader BUYS CE / PE on NSE stock options, holds a few hours, exits by 15:10.
Every panel, every agent and every call serves that. The analyst works through this checklist, in this order, every day.
Expected hit rate for a good system is 55-62%, not 80%: profit comes from tradable options, cutting losers, holding winners.

**A. 19:45 and 07:15 - which sectors will move, and why** (each driver -> its sectors -> every F&O share in them)

| Driver | Sectors it moves | Threshold that matters |
|---|---|---|
| Brent crude | OMCs, paints, aviation, tyres (inverse); ONGC, OIL (with it) | +-2% (3% strong) |
| LME copper / aluminium / zinc, silver, China news | metals, Hindustan Zinc, cables & wires | +-2% (zinc 1.5%, silver 3%) |
| Dalian iron ore, China steel | steel | +-3% |
| COMEX / MCX gold | gold lenders, jewellers | +-1.5% |
| Nasdaq, SOX, Infosys / Wipro ADRs, Accenture news | IT; SOX for electronics (Dixon, Kaynes) | Nasdaq +-1.5%, ADR +-2% |
| India 10-year yield, RBI liquidity / policy | banks, NBFC, realty | +-10 bp |
| USD/INR, dollar index | IT, pharma, importers | USD/INR +-0.3%, DXY +-0.5% |
| SEBI / RBI evening circulars | capital markets, NBFC, brokers | any material circular |
| USFDA, US drug pricing / tariffs | pharma (usually one share) | warning letter / OAI = major |
| Geopolitics, European defence stocks | defence | event |
| Monthly auto sales (1st), GE Vernova / Siemens Energy | auto, capital goods | event |
| GIFT Nifty | the broad tide | +-0.5% |

Read at 19:45: Europe, US futures, US data (19:00 IST), LME official, FII/DII provisional, SEBI/RBI releases, results after the close.
Read at 07:15: US close, Nasdaq, SOX, Indian ADRs, US 10-year, DXY, USD/INR, Brent, gold, silver, LME, Dalian, SHFE, Nikkei, Kospi,
GIFT Nifty. Re-check commodities at 09:00 (they often reverse in Asian hours).

**B. 09:00-09:08 pre-open** - each F&O share's gap % and pre-open volume against the night's watch list.

**C. 09:15-10:00 - confirm the sector (never before 09:20)**
1. Sector % against NIFTY (relative strength), not just the market gap.
2. Breadth: 70%+ of the sector's F&O shares moving the same way, median move > 1%.
3. Equal-weight average vs the index: if one heavyweight does the work (HDFCBANK, INFY/TCS, RELIANCE), it is a trap.
4. Futures build-up in several shares, OI added across ALL months (expiry-week rollover fakes "long unwinding").
5. The sector index on the right side of its own VWAP; the gap still there at 09:45.

**D. Pick the share inside the confirmed sector** (rank every F&O share in it)
1. Relative strength vs the sector since 09:15 (the open, not the previous close).
2. Relative volume (RVOL) at the same time of day: > 1.5 valid, > 2.5 strong. A share lagging on low volume can stay stuck.
3. The share against VWAP and the opening range (09:15-09:30 / 09:45): CE only above both, PE only below both.
4. Range used = |move| / ATR14: under 0.6 room left; above 1.2 extended - skip (the cure for late entries).
5. Room to the next level in ATR units (previous day high/low, 20-day high/low, VWAP, option OI walls): skip if < 0.3 ATR.
6. Futures build-up in that share, all months, with futures volume >= 2x normal for the time of day.
7. Its own news: a material catalyst with a timestamp, sized against the company (order > 10% of revenue matters, < 2% ignore).
8. **The laggard** (still flat or up, overbought, in a falling sector - KALYANKJIL on 18 Nov) works ONLY when: breadth 70%+, it
   holds on the trend side of its own VWAP, its RVOL is rising, it has no news of its own, and it is before 13:00. Otherwise
   take the leader on a pullback to VWAP.

**E. The option gate - a share that fails ANY of these is dropped, not scored lower**
- bid-ask spread <= 1-2% of the premium; enough volume and depth at the strike (about 500+ contracts before 10:00);
- strike at the money or one strike in the money (delta about 0.45-0.6); days to expiry shown (last 5-7 sessions: extreme
  theta - prefer ATM or next month);
- IV rank under about 50, and never a results / event day with inflated IV (IV crush beats a correct direction);
- not in the F&O ban and below about 85% of MWPL;
- greeks and IV are computed by GIR (Kite does not supply them). Monthly stock expiry = last Tuesday: take the date from NSE.

**F. The call** - GO NOW / GET READY · share · PE or CE · strike · premium · lots · stop and target on BOTH premium and share ·
max loss in Rs · reward:risk (skip under 1.5 after costs) · IV rank · why · what makes it wrong · signal age and "no chase above
premium X" · that setup's record.

**G. During the trade**
- Valid while the share and its sector stay on the right side of VWAP and relative strength holds.
- Stop on the share (last 5-min swing or VWAP); book half at about +1R; trail the rest (2 x 5-min ATR or the last 5-min swing).
- Stalling: 3+ five-minute bars with no new high on falling volume, rejection at a key level, premium not rising with the share.
- Time stop: not +0.5R within 45-60 minutes -> exit. Hard exit 15:10.
- Exit early ONLY on the stop, the invalidation or the time stop; a manual early exit asks for a reason (journal).

**H. Mostly noise - never a reason for a call on its own:** single-share PCR, max pain, participant-wise OI (index-level only),
bulk / block deals, delivery % alone, MACD / stochastics / Fibonacci / Ichimoku, minute-chart RSI as a reversal signal, generic AI
"sentiment" scores, broker calls (fade in 1-2 days).

**I. Proof (the quant's rules, feeding the trial scorecard)**
- Log every signal at the moment it fires with only the data that existed then; NSE end-of-day files only from the next day.
- Score the top picks at 09:30 and 09:45 against what actually moved (all F&O shares in the denominator, not only the movers),
  against a random F&O share as the baseline; slice by sector and time window (09:15-09:45, 09:45-11:00, 11:00-13:00, 13:00-15:10).
- Split option P&L into price move, theta, IV change and spread. About 100 signals per slice before trusting a hit rate.
- Morning score to start with: relative strength vs sector x RVOL 30% · sector strength and breadth 25% · catalyst 15% · OI
  build-up 15% · gap holding (ATR-scaled) 10% · agreement with NIFTY 5%. Re-fit monthly, moving weights only halfway.

## THE PLAN - basic now, advanced later (from eight more expert reviews, 18 Nov)

**The hard truth to design for.** SEBI's studies: about 9 in 10 individual F&O traders lose; FY22-FY24 93% lost, about Rs 2 lakh
each on average; frequent small option buyers did worst; costs were about 28% of losses. A disciplined intraday option buyer wins
35-45% of trades, so the average win must be about 2x the average loss after costs; losing runs of 6-8 trades and monthly drawdowns
of 10-20% are normal; proving an edge takes about 200 trades (4-6 months) at minimum size. GIR must say plainly if the edge is not
there after 200 trades.

### BASIC - build and prove these first (mostly free)

**B1. Protections (the order matters)**
1. Daily loss lock: about -2% of capital, or after 2 losses in a row -> no new calls, no new entries for the day. Weekly stop -6%.
2. Risk-based size: each trade risks at most 1% of capital, worked out from the stop; at most 25% of capital in premium at once;
   1 lot until 100 trades are journalled.
3. No entry without a stop (on the share, and at most a 30% loss of premium) and a time stop (no move in 45-60 min -> exit).
4. At most 3 trades a day (the analyst's calls count), at most 2 open positions, never two in the same sector.
5. Cooling-off 15-20 minutes after a loss; re-entering the same share at once is flagged.
6. Entry window 09:30-14:30 (no orders 09:15-09:20); flat by 15:10.
7. Option gate (see the checklist E) plus: never buy before the share's own results, RBI policy or the Budget; never average down;
   no far out-of-the-money strikes; in expiry week prefer next month.
8. "Move already made" check and "chase zone": if the price has run more than about 0.3 ATR past the trigger (or the premium 8%
   past the planned entry) -> wait for a pullback or half size.

**B2. Before every order, show:** total cost in Rs (brokerage, STT, exchange charges, GST, stamp duty, spread - about 1-1.7% of
premium per round trip on a stock option), break-even premium, the share move needed to break even, time decay to the planned exit.
After every trade show NET P&L only. Break-even move by 15:10 must be at most half the share's expected move, or skip.

**B3. The analyst's role.** Good at: the pre-open sector map, ranking shares against their sector, filtering (ban, results,
illiquid), sizing from the stop, warning near limits, journal statistics. It NEVER: places orders, moves a stop, overrides size, or
makes calls after the loss limit. Every call states entry, stop, what proves it wrong, break-even and a time limit.

**B4. Setups, graded by the desk** (the analyst labels every call with one):
- A: sector-confirmed opening-range breakout - the share AND its sector index break the 15-min range the same way, 5-min close
  beyond it on 1.5x volume; stop mid-range; target 2R then trail; 30-90 min.
- A: first VWAP pullback on a trend day (after 10:00) - holds VWAP, takes out the pullback high; stop the swing low.
- B+: failed breakout (back inside the range within 2 candles) - buy the other side; not on trend days.
- B+: day-2 results drift - the gap holds above day-1 VWAP for 30 min; IV already collapsed, premiums cheap.
- B: sector laggard - sector down > 1.2% on a clear driver, one share still green; enter only after 10:30 when it breaks its VWAP
  AND its morning low ("overbought" alone is not an entry); stop back above VWAP; target half the gap to the sector's move. Honest
  record from the desk: wins about 40% - laggards often lag for a reason; the leader on a pullback pays more often.
- Day type by 10:00 decides which setups are allowed: trend day (pullbacks only), range day (one trade or none), gap-and-go,
  gap-and-fade, expiry week, results season, RBI / Budget day (flat until the announcement, wait 30 min, half size).

**B5. While in a trade (the coach)**
- The screen shows only the position: P&L in R (not big Rs), stop, target, a hold-until countdown. New alerts queue silently.
- Early exit before the stop / invalidation / time stop: GIR shows the plan again and offers hold / exit half and trail / exit
  anyway with a one-word reason. Nothing is blocked - only a pause.
- A 20-second plan card before every entry: setup, trigger, stop, target, hold-until, what makes it wrong.

**B6. Data you can trust (the data engineer)**
1. No call from stale or unverified data - block it, never guess.
2. Every number shows its time and source; a coloured dot: fresh / late / stale (grey). An aggregate is as old as its oldest input.
3. A websocket watchdog: if ticks stop while the socket looks connected, resubscribe (the likely cause of ANGELONE stuck at 11:00).
4. Lot sizes, expiry dates (last Tuesday, moved for holidays), the F&O list, ban list and MWPL come only from that day's NSE / Kite
   files - never typed in or computed. Kite and NSE are reconciled every evening; a mismatch blocks that share.
5. A source that returns empty or malformed data fails loudly (the wrong-URL case).
6. Corporate actions and symbol changes applied before history is used.
7. News tagged only through a name table (symbol, ISIN, official name, brands, parent, old names) with a second clue for short or
   ambiguous names; NSE / BSE announcements carry the symbol - trust that first. Tested on 300+ labelled headlines.
8. Health report at 08:45 and 16:30: GREEN / AMBER / RED; RED means the next session starts read-only.
9. Option IV and greeks computed by GIR with Black-76 on the same-expiry future, time in trading minutes, from bid / ask / mid -
   never the last traded price. Store ATM IV daily from now on to build each share's IV history.

**B7. Infrastructure (basic)**
- Kite Connect + NSE end-of-day files + the free NSE / BSE announcement feeds (fastest share news).
- Services that restart themselves; an outside heartbeat (e.g. a free dead-man check) that rings if GIR goes silent; time sync.
- A 09:00 self-test: Kite token valid, feed live, a test alert sent and acknowledged. Instrument list refreshed at 08:45.
- Record every raw price message, every news item (with first-seen time) and every AI prompt / answer -> any day can be replayed
  exactly through the same code.
- Alerts: three levels with ONE sound - critical (stop hit, stale data with a position open, 15:00 warning, loss limit; must be
  acknowledged), high (GO NOW), low (GET READY, silent, expires). Duplicate check per share + signal + 15 minutes.
- Security: keys only in .env (never in git, never printed); dashboard private behind a login; SSH keys only, firewall.

**B8. Measuring (the performance analyst)**
- 1R = (entry premium - stop premium) x quantity. Everything net of costs.
- Paper-trade EVERY GO NOW with fixed rules, so taken and skipped calls are judged equally; compare with a random baseline (same
  rules, random times, same shares). If skipped calls beat taken ones, the trader's filter is costing money.
- Split each trade into sector, share, entry timing, exit management and option choice (in R) - shows where money leaks (e.g. the
  TITAN early exit as a cost in Rs).
- "n=" on every number; under 30 = too early; an edge counts only when its lower bound is above zero.
- Keep the AI only if the profit from its calls is at least 3x its cost; drop any data source or setup that has not beaten the
  random baseline after 100 calls.
- Weekly one page: expectancy in R with its range, net P&L, drawdown, profit factor, AI vs random, skipped vs taken, costs as % of
  gross, exit-management cost, AI lateness, rule breaks and their cost - and ONE rule for next week.

**B9. Product rules**
- Main screen: sector strength + breadth, the share list for the selected sector, at most 3 call cards, positions, status bar.
- Keyboard: 1-9 sector, J/K share, O option chain, C chart, T take call, S skip (with a reason), X exit, / search, Esc close.
- A new panel must name the number it will improve, gets a 2-week trial, and is removed if it does not. One panel in = one out.
  No new feature while a basic feature has an open bug.
- Never build: option selling or multi-leg strategies, strategy builders, customisable widget grids, more than one alert sound.

### ADVANCED - only after the basics have worked for 100+ trades
- IV percentile / skew / term structure and the 0-100 "worth buying now" score on every candidate option.
- Replay mode on screen; AI accuracy by sector and time of day; a pre-market brief page; phone push for GO NOW and critical alerts.
- A second alert channel and a phone call for critical alerts.
- A standby server in a second region; a backup price feed (about Rs 3-5k / month); a paid Indian newswire (about Rs 1-3 lakh a
  year) only if the miss audit proves news is still arriving late.
- Not worth paying for: Bloomberg / Reuters terminals, co-location, tick-by-tick depth, big servers, paid "AI signal" platforms.

### Legal (India)
- GIR's calls are for the trader only. Sharing calls with others, paid or free, needs SEBI research-analyst / adviser registration.
- Exchange data is licensed for personal use - never on a public page or channel.
- GIR gives signals; the trader places orders. Do not automate the daily Kite login. If orders are ever sent by API, SEBI's
  retail algo framework applies (static IP, broker tagging).

## THE DATA LIST - every data item the experts named (fill the last column: HAS / PARTLY / MISSING)

| # | Data | Source | How often | Used for | Level | GIR status |
|---|---|---|---|---|---|---|
| **Reference (must be right every day)** |||||||
| 1 | F&O share list, lot sizes, strike list | NSE / Kite instrument file | daily 08:45 | everything | basic | |
| 2 | Expiry calendar (last Tuesday, holiday-adjusted) | NSE contract master | daily | theta, strike choice | basic | |
| 3 | F&O ban list, MWPL %, near-ban shares | NSE `fo_secban`, MWPL file | daily + intraday | option gate | basic | |
| 4 | Corporate actions (split, bonus, dividend), symbol changes | NSE files | daily | correct history, strikes | basic | |
| 5 | Holiday list | NSE | yearly | expiry, schedules | basic | |
| 6 | Sector map: every F&O share -> sector -> its drivers | GIR knowledge base | monthly | sector method | basic | |
| 7 | Company name table: symbol, ISIN, names, brands, parent, old names | NSE + GIR | monthly | news tagging | basic | |
| **Live market (09:00-15:30)** |||||||
| 8 | Share price, volume, VWAP (live ticks) | Kite websocket | live | everything | basic | |
| 9 | 1-min and 5-min candles | Kite | live | opening range, VWAP, stops | basic | |
| 10 | Sector index values (official NSE sectoral indices) + GIR's own sector % | Kite + GIR | live | sector strength | basic | |
| 11 | Sector breadth (how many shares up / down in each sector) | GIR from #8 | live | confirm sector | basic | |
| 12 | NIFTY, BANKNIFTY, India VIX, advance / decline | Kite | live | market regime, day type | basic | |
| 13 | Futures price + OI, ALL months added | Kite | live (1-3 min) | build-up (LB / SB / SC / LU) | basic | |
| 14 | Futures volume vs normal for the time of day | Kite + history | live | real move vs noise | basic | |
| 15 | Option chain: OI and change by strike, volume | Kite | 1-3 min | OI walls, buying bursts | basic | |
| 16 | Option bid / ask, spread %, depth (best 5) | Kite market depth | live | option gate, entry price | basic | |
| 17 | Pre-open prices and volume (09:00-09:08) | Kite / NSE pre-open | daily, saved every day | gaps, morning calls | basic | |
| **Calculated by GIR** |||||||
| 18 | Opening range (15 / 30 min high-low) | from #9 | daily | entries | basic | |
| 19 | Relative strength: share vs sector, share vs NIFTY, since 09:15 | from #8, #10 | live | pick the share | basic | |
| 20 | Relative volume (RVOL) vs 20-day average at the same time | from #8 + history | live | real move vs noise | basic | |
| 21 | ATR14 (daily) and range already used today | from candles | daily + live | late-entry check, room left | basic | |
| 22 | Levels: previous day high / low, 20-day high / low | from candles | daily | room to the next level | basic | |
| 23 | IV, delta, gamma, theta, vega (Black-76 on the future, trading minutes, bid / ask / mid) | GIR | live | option gate, break-even | basic | |
| 24 | ATM IV saved every day -> IV rank / percentile; realised volatility | GIR | daily | expensive or cheap premium | advanced | |
| 25 | Break-even move by 15:10 vs expected move | GIR | per call | "worth buying now" | basic | |
| 26 | Full trade cost: brokerage, STT, exchange charges, GST, stamp duty, spread | GIR | per order | net P&L, break-even | basic | |
| **End of day (load after 18:00, use from the next day)** |||||||
| 27 | Bhavcopy: close, OI, volume per contract | NSE | daily | cross-check Kite, history | basic | |
| 28 | Delivery % vs its 20-day average | NSE `sec_bhavdata_full` | daily | next-day context | basic | |
| 29 | Participant-wise OI (FII / pro / client / DII) | NSE | daily | index bias only | advanced | |
| 30 | Bulk and block deals, promoter / pledge disclosures | NSE / BSE | daily | watch list | basic | |
| 31 | FII / DII cash figures | NSE | daily | market context | basic | |
| **World and drivers (night + morning, some live)** |||||||
| 32 | Brent crude, gold, silver, LME copper / aluminium / zinc, Dalian iron ore | market data / MCX via Kite | 19:45, 07:15, 09:00, live | sector drivers | basic | |
| 33 | USD/INR, dollar index, US 10-year, India 10-year | market data | 19:45, 07:15, live | banks, IT, pharma | basic | |
| 34 | GIFT Nifty, US close, Nasdaq, SOX, Indian ADRs (INFY, WIT, HDB, IBN, RDY) | market data | 19:45, 07:15 | the open's tone, IT | basic | |
| 35 | Asian markets (Nikkei, Kospi, Hang Seng, SHFE) | market data | 07:15-09:00 | metals, risk mood | basic | |
| **News and events** |||||||
| 36 | NSE / BSE corporate announcements (filings) - fastest, carry the symbol | NSE / BSE feeds | every minute | share news | basic | |
| 37 | Results calendar with time (in or after market hours) + surprise vs estimates | NSE + news | daily | results gate, IV crush | basic | |
| 38 | Regulator actions: SEBI, RBI, USFDA, CCI | official sites + news | every minute | policy news | basic | |
| 39 | Publisher feeds and live blogs (ET, CNBC-TV18, Moneycontrol, BS, NDTV Profit, TradingView) | feeds | every minute | news | basic | |
| 40 | TV management statements | TV watcher | live | denials, clarifications | basic | |
| 41 | Macro calendar: RBI policy, US CPI / jobs / Fed, India CPI, auto sales, GST | calendars | weekly | event gate | basic | |
| 42 | X (journalists, channels) | X API | live | faster news | advanced (needs credits) | |
| 43 | Paid newswire (Cogencis / CMOTS) | paid | live | faster news | advanced (only if the miss audit proves it) | |
| **The trader's own data** |||||||
| 44 | Capital, open positions, fills (entry / exit price, time), P&L | Kite positions + GIR | live | risk bar, sizing, journal | basic | |
| 45 | Trade journal: plan card, reason, mistake tags, price 30 min after exit | GIR | per trade | weekly review | basic | |
| 46 | Every AI call: time, inputs, decision, taken / skipped, paper result | GIR | per call | AI scorecard | basic | |
| 47 | AI spend by model and hour | GIR | live | $20 cap, cost per useful call | basic | |
| **Health of the data itself** |||||||
| 48 | Age and source of every number; stale flags; Kite vs NSE mismatches | GIR | live + 08:45 / 16:30 | trust, blocking calls | basic | |
| 49 | Raw recording of every tick, news item (first-seen time) and AI answer | GIR | live | exact replay of any day | basic | |

The server fills the last column first, then builds the MISSING basic items in this order: 1-3, 8-13, 16, 18-23, 25-26, 36-37,
44, 46, 48-49, then the rest.

## EXTERNAL DATA - the world, the calendar, the policy pipeline, share histories (four more experts, 18 Nov)

**Key timing fact.** GIR trades only 09:15-15:10, so most outside news is a NEXT-MORNING trade: US data and Fed (18:00-00:30 IST),
most Indian macro (16:00), Cabinet / GST Council / SEBI board / RBI circulars / defence approvals / customs notices (evenings).
China data lands 07:00-07:30 IST (a pre-open input for metals). In-session events are few: RBI policy (10:00), auto sales (1st),
election counting day, BoJ (08:00-09:30), company filings. That is why the 19:45 and 07:15 notes matter most.

**E1. Global event calendar** - each event stored as: tier (1-3), IST time or "unscheduled", in-session yes/no, consensus,
priced-in score, scenario -> {sector: expected move}, F&O shares, source, live outcome. Shown as a 4-week calendar and a "today's
risk" strip built at 08:30. Top events (ranked): RBI MPC · India election results · Fed decision + press conference · Middle East /
Hormuz · US tariff and trade actions on India (pharma, IT / H-1B) · US CPI / payrolls · India-Pakistan / China border · OPEC+ ·
China stimulus (State Council, PBoC, Politburo, NPC) · MSCI / FTSE / Nifty rebalances and NSE F&O additions / removals · BoJ (yen
carry) · US election and executive orders · Russia-Ukraine and oil sanctions · Jackson Hole / Fed Chair · Red Sea and LME rules.
Sources: official sites (federalreserve.gov, rbi.org.in, boj.or.jp, opec.org, MSCI / FTSE / NSE Indices, ECI, USTR), free calendars
(Investing.com / ForexFactory in IST), CME FedWatch, GIFT Nifty, Brent; GDELT for geopolitical headlines.

**E2. Economic data calendar** - each release tagged PRE-OPEN, IN-SESSION or POST-CLOSE -> next-day gap, with actual vs consensus
and a surprise score ((actual - consensus) / typical surprise). Prices react to the SURPRISE, not the level. Top releases: RBI policy
· monthly auto sales (1st, 09:00-14:00 by company; VAHAN daily previews) · US CPI · China PMI (07:00-07:15) · US payrolls · Fed ·
India CPI (~12th, 16:00) · China activity and property data (~15-17th, 07:30) · IMD monsoon forecasts / onset / weekly rain (in
season) · India GDP · Budget / borrowing calendar · China CPI / PPI / credit · US PCE / retail sales · power demand / IEX · BoJ.
Mostly noise for intraday: WPI, IIP, trade, GST, core sector, forex reserves, jobless claims, EIA / API, euro / Japan data, OPEC /
IEA monthly reports, rig count. After a release, an automatic note: "China PMI 51.2 vs 50.5 (+1.4) -> metals bullish, medium; wait
15 min for the metal index to confirm". After 6-12 months, replace these rules of thumb with GIR's own measured sensitivities.

**E3. Policy pipeline** - every pending decision: deciding body, expected date (confirmed / rumoured), shares, expected direction,
how much is priced in (20-day move, IV level), status PENDING -> ANNOUNCED -> NOTIFIED (duties, anti-dumping, GST only take effect
when notified in the gazette), source link; sorted by days to decision. Top items (ranked): monthly auto sales / VAHAN · USFDA
inspection outcomes (OAI or warning letter: usually -3% to -8%) · RBI policy and circulars · defence contracts / DAC approvals ·
SEBI market rules (brokers, exchanges) · steel and metal duties / safeguards / anti-dumping · Budget (1 Feb) and its leaks · GST
Council · rail / power / road orders · OFS / disinvestment (the PSU falls toward the floor price) · fuel, ATF (1st, 06:00) and
excise · cement and steel price checks · CERC / TRAI / IRDAI orders · IT deal wins and US visa / tariff policy · gold duty and gold
imports. Fastest free sources: PIB and ministry / regulator X accounts, NSE / BSE filings, the regulators' own sites.

**E4. Share history - per F&O share, ranked by value for an intraday option buyer**
1. Its own ATM IV history, IV rank, and the IV build-up / crush around results (no free source - GIR must record it daily NOW).
2. Forward calendar of results and events (board-meeting notices).
3. Results-reaction table: gap, direction vs surprise, day-1 range, day-2 drift.
4. Spread and liquidity by strike - logged by GIR at about 09:30, 12:00, 14:30 (no free source - start NOW).
5. Leader or laggard behaviour against its sector index.
6. Gap-fill rate by gap size.
7. What it does the day after a 3%+ move.
8. Index and F&O inclusion / exclusion dates; MWPL / ban history.
9. Reactions by event type: orders, block deals, regulatory, OFS / QIP.
10. Expiry-week behaviour.
11. Results estimates and a "habitually misses guidance" tag.
12. Red flags: pledge > 25% or rising, PSU status, regulatory / controversy history.
Noise for intraday: day / month seasonality, monthly fund holdings, quarterly shareholding changes, broker targets, AGMs.
Screener + NSE cover about 95%; paid databases (Capitaline, ACE, Prowess) are overkill for this.

**E5. Event rules for an option BUYER**
- Never buy options going INTO a known event (results, RBI, Budget): IV collapses after it. Trade the reaction.
- Tier-1 event in session (RBI, counting day): flat from 15 min before to 30 min after; enter only when a 15-min candle confirms.
  Counting day: no trades before 11:00, or skip the day.
- After an overnight Tier-1 event: no entries 09:15-09:30; trade the mapped sector only if it holds its gap after the opening range.
- Unscheduled shock (Brent +-3%, USD/INR +-0.5%, a headline alert): freeze new entries 15 min, tighten stops, re-rank sectors.
- Index-rebalance shares: exit by 14:45 on the effective day (passive money moves in the closing session).
- Lock new entries in the affected sector from 10 min before an in-session release to 15 min after.

**E6. The 19:45 note** = everything after 15:10 (with sector, shares, direction, likely gap) + tomorrow's calendar with times +
pipeline items due within 3 sessions + an IV warning on any scheduled event. **The 07:15 note** = overnight US / China / global
outcomes with surprise scores, overnight gazette / PIB / regulator updates, leaks marked VERIFIED / UNVERIFIED, after-hours order
filings, today's in-session release times, and the final sector shortlist. **The 08:45 update** = China data (07:00-07:30),
any change since 07:15, and the system pre-flight result. **The 09:08 check** = which watch-list shares are gapping in the
pre-open and which morning plans are now ready. (Why these times: by 19:45 the day's after-close news, NSE end-of-day files,
FII / DII and US data at 19:00 IST are in; by 07:15 the US close, the Fed (00:30) and early Asia are in, two hours before the open.)

All times, dates and effect sizes above are expert rules of thumb from memory: verify each against the official calendar before
coding it, and replace effect sizes with GIR's own measurements as data accumulates.

## SPEED, FEED, 24x7 MONITORING, AI PIPELINE, FRONT END, ORDER FLOW, SEBI (eight more experts, 18 Nov)

### S1. News within seconds (GIR's own 6 s of processing is not the problem; the sources are)
Measured today: filings ~3 min, wire stories ~7.5 min, Google News ~63 min. Targets: filings < 15 s, wire / TV / X < 20 s,
publishers < 65 s end to end. Changes, ranked by delay cut:
1. Poll Reuters' own news sitemap / feed every 15 s (would have caught ANGELONE ~35 min earlier). Free.
2. NSE and BSE announcement JSON every 3-5 s (cookie warm-up, conditional GETs, keep-alive, jitter, back off on 403 / 429; RSS as
   fallback). Filings from ~3 min to ~10 s.
3. Live speech-to-text on the business TV channels' official live streams with keyword triggers (~Rs 2-8k / month).
4. A Telegram listener on news outlets' and journalists' public channels (push, 1-3 s, free).
5. Google News OUT of the alert path (backfill only); publisher news-sitemaps every 20-30 s instead.
6. Per-source latency dashboard: for every item store publish time, first-seen time per source and the time the price moved; rolling
   p50 / p90 per source, share first, share before the move; demote slow sources automatically; a daily "missed the move" list.
7. X lists of 50-100 journalists, regulators, PIB (needs credits). 8. Mirroring news-app notifications from a spare phone.
9. Alert first, enrich later: server -> page by push (SSE), phone by Telegram / ntfy. 10. A paid wire only after 1-9 are tuned.
Processing under 1.5 s: normalise + dedupe (hash / near-duplicate within 2 h, keep the earliest, attach later sources) -> entity
tagging from the name table (< 5 ms) -> keyword prefilter -> small fast model classifies (0.3-1 s) -> the big model only in the
background, never blocking the alert. Legal: public endpoints only, respect terms, no redistribution, gentle rates on NSE.

### S2. The live price feed (fast and never silently frozen)
- One feed process; the websocket callback only queues the raw frame (nothing slow inside it); a decoder keeps the latest tick
  per instrument in memory / Redis; a page gateway pushes only changed fields 4-10 times a second.
- Coverage within Kite limits (3 connections x 3,000 per key): 218 shares + current futures + ATM +-5 strikes CE / PE (~5,250); FULL mode
  for every option strike (Kite's quote mode carries NO open interest, NO bid / ask and NO exchange timestamp - the option gate would be
  blind; full mode for ~5,000 strikes is about 1 MB/s, well within capacity); re-centre strikes when spot moves half a strike
  (subscribe new before unsubscribing old).
- After EVERY reconnect: resubscribe each connection's list and set the mode again; backoff with jitter. Stall detection with
  2-3 liquid "sentinel" instruments per connection (> 3 s silent in market hours -> reconnect), and a rotating quote-API sweep
  (~500 / s) to find silently dead tokens. (Likely cause of the ANGELONE page stuck at 11:00.)
- Instrument list rebuilt daily; roll to new tokens at expiry; alert on an invalid subscribed token.
- A second feed vendor running all the time (Dhan / Upstox free with an account, or TrueData / GlobalDataFeeds paid); per-instrument
  failover to the fresher source; flag if the two differ > 2 ticks or 0.3% for > 5 s.
- Latency budget exchange -> screen: 0.3-1.3 s (Kite's snapshot interval is the largest part). Delay hides in database writes in
  the callback, page polling, and a busy event loop. Run on a Mumbai-region server.
- Record raw frames off the live path (writer thread -> daily file -> compress after close); never write SQL in market hours.
- Kite sends snapshots (about one per instrument per second), not every trade; an illiquid strike sending nothing can be normal.
  The close is a 15:00-15:30 VWAP, not the last tick.

### S3. 24x7 monitoring - "a service being up does not mean its data is good"
1. Heartbeat table: every service writes {source, last good time, value hash, rows, errors}; one checker every 60 s judges every
   row against limits that change with the clock (market hours: prices 10 s, OI 3 min, sectors 2 min, news 15 min; night: news 2 h).
2. Frozen values (price and volume unchanged 60 s in market hours) = stale even if the process is alive; zero rows or an empty
   body = ERROR (the wrong-URL case); value ranges; cross-source agreement; % of news mapped to no share.
3. Safe mode: one global flag - when a critical input is stale, values grey out "STALE since 11:02" and no calls go out.
4. Watched from outside: a free dead-man check pinged every minute (silence -> phone call); an external uptime monitor checking
   that /status.json is fresh, not just that the page answers.
5. Alert levels: P1 (blocks trading) Telegram + phone call, repeat every 5 min until acknowledged, escalate after 15 min; P2
   Telegram; P3 daily digest. Alert on state change only, always send "recovered". System alerts on a SEPARATE bot from trading
   alerts. Measure event-to-alert time; alert if p95 > 5 s.
6. AI spend checked BEFORE each call, plus the provider-side limit; alerts at 50 / 80 / 100%.
7. 08:45 automated pre-flight posted to Telegram: Kite token valid, clock synced, disk OK, all services green, instrument list
   refreshed, AI budget left, test alert received. Kite token checked from 08:00 every 5 min.
8. systemd watchdog pinged from INSIDE the data loop (a stuck loop gets restarted) + OnFailure alert (no silent restart loops).
9. A /status page: GREEN / AMBER / RED per component with last-good time; the page itself turns red if status.json is > 2 min old.
10. Host basics: disk, memory, clock offset, certificate expiry. Runbooks: feed dies -> safe mode, restart once, no GIR-signal
   entries until green 5 min; server dies -> trade from the broker app, rebuild from a tested snapshot; AI down -> panel says
   "unavailable", engines keep running. Weekly reliability report; every incident adds an automatic check ("never again").

### S4. AI pipeline - fast, cheap, reliable (target ~$2-4 / day, < 5 s from confirmed move to call)
1. Budget enforced in code BEFORE each call (estimate x price vs per-call / hour / day counters) with a step-down ladder: 60% of
   the day -> top model off; 85% -> mid model only for the most material items; 100% -> code rules + small model only, one alert.
   (The $5 cap failed because it only reported spending.)
2. Prompt layout for caching: frozen instructions and schema first, then the day's static context, then a cache breakpoint, then
   live data LAST. No timestamps / changing tool lists / unsorted JSON before the breakpoint; same model throughout a flow; keep
   the cache warm. Target >= 70% cache reads (today ~13%). Check cache-read tokens on every call.
3. Merge the six desks into ONE mid-model call returning all six views.
4. Plain code (no AI, < 50 ms): dedupe, symbol mapping, price / OI / IV / breadth triggers, sector confirmation, strike choice,
   levels, sizing, budget and risk gates. Small model (< 1.5 s): reads each news item ONCE -> tickers, event type, direction,
   materiality 0-3, novelty. Mid model (< 6 s): only materiality >= 2 or a code trigger. Top model (< 20 s): only a candidate that
   passed the code filters, ~15 a day, OFF the critical path - code + mid model signal, top model confirms or vetoes.
5. Structured output with a decision schema {action BUY_CE / BUY_PE / NO_TRADE, symbol, strike, expiry, entry zone, stop, target,
   invalidation, confidence, evidence ids, time-to-live}; no free-text summary; NO_TRADE is the default.
6. Validators: every price must exist in the data given; strike must be in the chain; stop / target on the right side; confidence
   below 0.6 -> NO_TRADE; reject and retry once, then drop.
7. Hash every news item so it is never read twice; merge near-duplicates in a 30-60 s window; debounce one mid-model call per share
   per 3 min; desks read stored verdicts, not raw text.
8. Timeouts per tier (2 / 8 / 25 s) with fallback one tier down or NO_TRADE; streaming; parallel calls; batch (half price) for
   end-of-day review and replays.
9. Log every call (prompt, output, model, tokens incl. cache, cost, latency, validator result, trade outcome) -> replay any day;
   every prompt / model change must pass a replay of 20-30 past days before it ships.

### S5. The web front end (professional, real time)
1. One Server-Sent Events stream (sequence numbers, snapshot on reconnect) feeding ONE store on the page; panels never fetch alone.
2. Update only the numbers that changed (fine-grained reactive components, e.g. Preact signals); never redraw a panel on a tick
   (the cause of the blinking).
3. Screen updates batched once per animation frame; each cell changes at most 4-10 times a second; long lists virtualised.
4. A freshness dot and "as of" time on every panel; stale can never hide.
5. One AlertManager and ONE SoundPlayer - the only code allowed to play sound (ends double alarms); at most 3 toasts.
6. A fixed grid for 1600x900; panels scroll inside; one overlay layer; nothing ever blocks clicks (the pre-open notice becomes a
   banner that does not take clicks).
7. TradingView Lightweight Charts: update per tick (never reload all data), VWAP line, entry / stop / target lines, the option
   premium in a second pane on the same time scale.
8. Release gate: record every stream event; replay at 1x / 10x; automated browser tests (prices update, clicks work, each alert
   plays once, no blinking); screenshots at 1600x900 and phone size; a 30-minute soak at 10x that fails on memory growth > 30 MB,
   long tasks > 100 ms or rising DOM nodes.
9. Move to the new front end ONE panel at a time behind a flag; stop patching the old page.
10. A separate phone route (/m): positions, calls, exits; large numbers; installable with push notifications. Design tokens:
   sans font for labels, tabular numbers, fixed colour meanings (green / red = price and P&L, amber = warning / action, blue = info;
   CE / PE shown by label, not colour), dark theme with readable contrast. Keys: / search, 1-9 panels, Esc, M mute, A acknowledge.

### S6. Order flow - early warning (built from Kite full-mode snapshots; test on recorded ticks before trusting)
Ranked by early-warning value:
1. Short covering at the nearest OI wall: OI down, premium up, volume > 4x.
2. Options "paying up": premium change beyond what delta / gamma / theta explain (> 1.5 ticks over 3 min) + an IV jump on one strike
   + an ATM volume surge.
3. Sector-lag catch-up: a member's return vs beta x sector return over 5 min lagging by >= 0.4% (expect catch-up in 2-10 min).
4. Futures cumulative volume delta diverging at a 15-min high / low.
5. Futures OI build-up over 3-5 min with excess basis expanding.
6. VWAP reclaim / rejection confirmed by volume delta.
7. Absorption at a large resting order in the futures book (imbalance > 0.4 and the level refills).
8. A 15-min shift in call vs put premium turnover.
Mostly noise: total buy / sell quantity level, raw depth, single block prints, "futures lead cash". Traps: the first 15 and last 30
minutes, expiry and results days, ban shares (OI frozen), ex-dividend (basis), straddles inflating both sides, lumpy OI updates.
Each signal needs 60+ days and 100+ events, walk-forward tested; drop any signal whose net edge is under 2x the option spread.

### S7. SEBI and exchange rules GIR must build in (verify current circulars - several changed in 2024-26)
1. Calls go ONLY to the owner - no groups, subscribers or public posts (giving calls to others needs SEBI RA / IA registration).
2. Ban-list gate every morning (fo_secban + MWPL; OI counted on a delta basis; ban above 95%; in ban only reduce) - block calls on
   banned or near-95% shares.
3. Expiry calendar from NSE files + holidays (stock F&O: last Tuesday, earlier if a holiday); stock F&O settles by physical delivery
   - never hold an in-the-money option into expiry; treat expiry day as a special risk mode.
4. Lot sizes and the F&O universe loaded daily (lots revised about every six months; shares added / removed each review).
5. Option premium is collected upfront: check cash before each call.
6. If GIR ever places orders: SEBI's retail algo framework applies - static IP registered with the broker, broker OAuth + 2FA,
   daily token, order rate well under 10 / s (above that needs exchange registration), kill switch, full order log, no shared keys.
   Signal-only (the trader places orders) is not an algo.
7. Dashboard behind a login, for one user; Kite / NSE data is for personal use only - no public display, no redistribution; use
   official files / APIs, never aggressive scraping.
8. Show SEBI's F&O loss disclosure (about 9 in 10 individual F&O traders lose) on the dashboard and in the GO NOW view; label AI
   calls "AI-generated, personal use".
9. A tax-ready trade ledger (F&O = business income, ITR-3; turnover = sum of absolute P&L per trade; STT) and contract notes.
10. A regulatory-watch task: check new SEBI / NSE / Zerodha circulars (lot sizes, expiry days, algo rules, MWPL, STT) every week.

### S8. Advanced patterns for an option buyer (expert estimates - log every signal 3 months before trusting any)
Defaults: ATM or 1 strike in the money; stop on the share level that proves it wrong and never more than 30% of premium; time stop
45 min; target 1.5-2R then trail on the 5-min 9 EMA. Two rules are MANDATORY parts of the engine, not patterns:
- **IV-crush filter:** block buying when the share has results / an event within one session and IV is above its 70th percentile,
  or ATM IV > 1.3x its 20-day average. (The single most valuable rule.)
- **A+ score out of 10:** daily trend / multi-day level break 2 · 60-min structure aligned 1 · 15-min setup quality 2 · sector in
  the top 3 and aligned 2 · OI confirmation 1 · IV rank < 50 and no event 1 · good time window 1. 8+ = full size, 6-7 = half, below
  6 = skip. The IV-crush filter and spread < 1% must pass regardless of score.
The 8 to add, ranked by edge and how reliably GIR can detect them:
1. Squeeze -> expansion with low IV rank: yesterday NR7 / inside day, ATR(5)/ATR(20) < 0.7, 15-min Bollinger width in its bottom
   10%, IV rank < 30; buy the first 15-min close outside the range with volume >= 1.5x and the sector agreeing; stop back inside;
   target 1.5-2x the range. 09:45-11:30 or the 13:30 break. Gains from the move AND rising IV.
2. Short-covering squeeze: 3+ days of short build-up, today price up while futures OI falls > 3%; buy CE on a VWAP reclaim or a day
   high break, 10:00-13:00.
3. First-hour reversal: a gap > 1.5% against the sector extends, fails to make a new extreme 09:45-10:30 and reclaims VWAP; stop
   beyond the day's extreme; target 50-100% gap fill.
4. Lunch compression -> 13:30 breakout: on a trend day the 11:45-13:15 range < 40% of the morning range; break 13:15-14:00 with
   volume; ATM / ITM (afternoon decay is higher).
5. Post-event IV reset, day 1: after results, gap > 3%, volume > 3x, the first 30-min range holds -> buy the break in the gap's
   direction about 09:45 (options are cheap after the IV collapse).
6. Results sympathy: after a sector leader beats strongly, buy peers whose own results are > 5 days away, first hour.
7. OI wall unwinding: the biggest call-OI strike just above price loses 10-15% OI while put OI builds below; buy a 5-min close above
   that strike; target the next OI strike (OI updates every few minutes - poll the chain every 3 min).
8. Intraday commodity lag: an MCX move > 1.5% during the session that the linked shares have not followed after 15-30 min (crude
   down -> OMCs, paints, aviation; crude up -> ONGC, OIL; copper up -> Hindalco, Vedanta, Hindustan Copper; cables are mixed -
   copper is their cost). Overnight moves are already in the open.
Filters only (not trades): pair divergence, heavyweights vs the index, fresh put writing as support, futures basis, delivery + OI.
Leave alone: index rebalancing (flows after 15:10), OFS / QIP discounts, ex-dividend, and expiry-week gamma (A+ only, half size,
never out-of-the-money). Sector rotation (rank CHANGES 09:30-10:30, breadth > 80%, buy the strongest on a VWAP pullback) and PSU
baskets (breadth > 85% by 10:00, tight time stops) are moderate.

### S9. Using the trader's four Zerodha Kite Connect API keys
- The keys are already in /home/globalbot/.env. Read them from there by VARIABLE NAME only; never print, log, copy or paste a value,
  never put one in git, a chat or a screenshot. List the variable names (not values) in the report.
- Use them to spread the live feed: each key gives up to 3 websocket connections (~3,000 instruments each). Plan: key 1 = the 218
  shares + current-month futures + indices; key 2 = option strikes ATM +-5 for the watch list and open positions (full mode with
  depth); key 3 = the rest of the option chains (FULL mode - quote mode has no OI, bid / ask or timestamp) plus a REST OI sweep every 1-3 min; key 4 = a HOT STANDBY that takes over any connection that stalls
  (and runs the rotating quote-API sweep that finds silently dead prices). Each key has its own REST rate limits - spread quote /
  historical calls across them.
- Every key needs its own daily login (access token). Keep the login manual and do not automate it around Zerodha's rules; the
  08:45 pre-flight checks all four tokens and rings the trader if any is not logged in.
- Check Zerodha's current Kite Connect terms for using several apps on one account before relying on this; if any use is not
  allowed, say so and use only what is.
- Kite gives NO IV / greeks, no option-chain endpoint, no history for expired contracts, no 20-level depth, no trade-by-trade data:
  GIR computes IV / greeks itself; an independent second feed (e.g. Upstox on its long-lived read-only analytics token) runs all the
  time; NSE's option chain is the official cross-check for IV / OI; expired-option intraday history (e.g. Dhan's or ICICI Breeze's
  historical data, needs an account in the trader's name) can fill IV rank and results-reaction tables from week one [verify terms].
- Kite Connect costs about Rs 500 / month per app with historical data (four keys ~ Rs 2,000 + GST) [verify]; API ORDER placement
  needs a static IP (data-only use does not) [verify].

### S10. The AI agents already built - kept, reorganised, and made to earn their place
Every agent stays, but in the right tier (S4), and each is scored daily (B8: keep it only if its calls earn at least 3x its cost;
drop it if it has not beaten the random baseline after 100 calls).

| Agent (built 17-18 Nov) | New role | Model / cost |
|---|---|---|
| News reader (every F&O news item) | reads each item ONCE: tickers, type, direction, materiality 0-3, novelty | small model, < 1.5 s |
| World feed / global agent | world headlines + prices -> drivers -> sectors (E1, E2 tables) | code + small model |
| Sector agent | sector confirmation (checklist C) - pure rules | plain code, no AI |
| Money agent (futures OI build-up) | build-up all months, volume vs normal | plain code, no AI |
| Pre-open agent (09:08) | gaps vs the watch list | plain code, no AI |
| Theme agent / sector board | driver -> sector -> shares ranked (checklist A-D) | plain code, no AI |
| Order-flow signals (new, S6) | the 8 early-warning signals | plain code, no AI |
| Policy map | policy pipeline (E3) | small model reads, code tracks status |
| Six desks | MERGED into ONE call returning all six views, only on materiality >= 2 or a code trigger | mid model, < 6 s |
| Senior analyst ("the expert") | confirms or vetoes a candidate that passed the code filters, writes the 19:45 and 07:15 notes; never on the critical path; ~15 calls a day | top model, < 20 s |
| Knowledge base | share histories (E4) - monthly refresh | top model monthly, batch (half price) |
| X agent | stays OFF until credits are added | - |
| Follow-up (HOLD / BOOK HALF / EXIT) | rules first (G, B5); the mid model only to explain | code + mid model |

The daily 15:45 scorecard shows each agent's line: ran or not, what it found, what it woke, what reached the trader, its cost, and
its record. An agent that ran all day and produced nothing useful is reported with the reason.

### S11. Mid-session ROTATION ALARM (three experts, 18 Nov - after the PSU-bank rotation GIR caught late)
- Why it was missed: rotation was measured mostly since the open / 09:30-10:30 (S8), not on ROLLING 15 / 30-minute windows all
  session; no same-time-of-day volume baselines; no basket-level futures / options signal; no bond-yield / rupee feed in session.
- Baskets: the sector's move, breadth and rank use ALL listed shares of the sector (the official NSE index where one exists,
  e.g. NIFTY PSU BANK with all its constituents; else a free-float weighted basket of every listed share in the sector) - see 1.2.
  The F&O universe file (PSU banks have only ~7 F&O names) decides only which shares can be TRADED; breadth is shown both ways
  ("all shares 10 / 12 · F&O 6 / 7"). Also the theme baskets (PSU defence, rail, power financiers, Adani, Tata ...). One source for every basket list.
- Every minute, 09:30-14:00, rolling 15 / 30 min: beta-adjusted relative strength vs NIFTY (PSU banks ~1.4x beta) and its RANK
  change; breadth (up and above VWAP); equal-weight vs index (one share > 60-70% of the move = not a rotation; recompute without
  the heavyweight); volume vs the 20-day median of the SAME time slot; futures LB / SC across the basket (OI summed over all months;
  ignore near-month-only SC in expiry week); call-buying bursts, call-wall unwinding, put writing, call IV rising; volume delta;
  excess basis widening; WHERE the money comes from (sectors losing 3+ ranks); 10-year yield / USD/INR moves; news match +-10 min.
- GET READY (amber): any two of - rank up 3+ in 15 min · breadth >= ~2/3 of the basket · sector volume >= 1.5x slot normal ·
  basket futures LB/SC >= 60% with volume >= 2.5x · a news match.
- GO NOW: beta-adjusted RS >= +0.6% over 30 min · breadth >= ~85% · equal-weight >= 0.8x the index · volume >= 2x · basket above
  VWAP for 2 five-minute bars · calls bought / walls unwinding in 3+ names · a source sector or news trigger named · then the share
  passes checklist D and the option gate E, the event lock E5 and the IV-crush filter. No new rotation entries after 14:00.
- CANCEL: breadth falls below ~60% or the basket drops below VWAP. One alert per basket per 30 min, only escalating; log every
  alarm (fired and failed).
- The alert states the AGE: "GO · money OUT of PVT BANKS (-4 ranks), IT (-3) INTO PSU BANKS since 11:40 (14 min) · RS +0.8% ·
  breadth 6/7 · RVOL 2.6 · 10y -5 bp · leader SBIN · laggard BANKBARODA · trigger <headline / none> · OUT: you hold INFY CE -> EXIT".
- Which share: alarm < 20 min old -> laggard catch-up only if above VWAP, own volume rising, no own news, before 13:00, spread < 1%;
  alarm > 20 min -> the leader on its first pullback to VWAP that holds. Don't chase: range used > 1.2 ATR (70-100% = pullback only,
  half size; > 100% stand aside), alarm > 45 min old, sector already +2.5% vs NIFTY, ATM premium +40% / IV > 1.3x 20-day, breadth
  falling, within 0.3 ATR of the day / previous-day high, unconfirmed headline, after 14:00. One trade per theme (two only if the
  first is booked). Open CE in the sector the money is LEAVING with the share below VWAP -> exit now.
- **TREND-DAY EXCEPTION (the trader, 18 Nov: TITAN fell the most that day while the drawings marked it "extended - not
  tradable"):** when the driver and the sector are confirmed and the share has fresh build-up in the call's direction and is
  making lower highs below VWAP (higher lows above VWAP for CE), "extended" is a WARNING, never a block: the call becomes
  "enter on the bounce to VWAP / the first lower high, half size". Replay 18 Nov TITAN, KALYANKJIL, MANAPPURAM, SAIL to set
  the numbers; the no-chase limits above are starting values only.
- Proof: replay the mid-November PSU-bank day from GIR's recordings (find the day): when the rotation began, when GET READY / GO NOW
  would have fired, which shares and strikes, against what happened. Thresholds are starting values - pool all sectors, 60+ days,
  100+ events, walk-forward, before trusting them.

### S12. POLICY SHOCK DURING MARKET HOURS - Parliament, Cabinet, regulators (the trader, 18 Nov)
Why: a bill passed or a regulator order in the middle of the session moves named shares at once (CERC market coupling -> IEX fell
about 29% in one day [verify the date]; IRDAI commission caps -> PB Fintech (POLICYBZR) and the insurers). Today GIR has almost no
feed for this: the plan polls these sites every 15 min from weeks 2-4 (COLLECTION_PLAN line 257). That is too slow.
- **Sources, in the order the news arrives:**
  1. LIVE (0 min): Sansad TV Lok Sabha / Rajya Sabha streams, PIB / DD News / ministry press briefings (YouTube), turned to text
     live (speech-to-text) and searched for watched words; minister, ministry, PIB and regulator X accounts.
  2. WIRES (0-3 min): ANI / PTI X, Reuters India (sitemap every 15 s), TV tickers (CNBC-TV18, ET Now), ET / Moneycontrol live blogs.
  3. OFFICIAL (0-15 min): the regulator sites checked for changes every 1-2 min in market hours - IRDAI, CERC, SEBI, RBI, TRAI,
     CCI, PFRDA, CDSCO, NPPA, FSSAI, DGCA, DGFT, DGTR, CBIC; sansad.in bills and "business of the day"; e-Gazette; PIB releases.
     Every 15 min outside market hours.
  4. FILINGS: the company's own NSE / BSE reply ("impact on us") every 3-5 s (already in the plan).
- **The day's watch list (07:00):** which bills are listed in Lok Sabha / Rajya Sabha today, open consultation papers and draft
  regulations, regulator board meetings, court hearings - each mapped to its F&O shares and the direction. During a Parliament
  session this is checked every morning.
- **The policy map (built once, kept up to date):** regulator / ministry / bill -> F&O shares -> likely direction. Examples:
  IRDAI (commission, bancassurance, FDI) -> POLICYBZR, SBILIFE, HDFCLIFE, ICICIPRULI, ICICIGI, LICI; CERC (market coupling,
  trading margin) -> IEX, power traders; SEBI (F&O rules, MTF, margins) -> ANGELONE, BSE, CDSL, MCX, MOTILALOFS, 360ONE;
  RBI -> banks / NBFCs; NPCI (UPI MDR, market-share caps, circulars) -> PAYTM, banks with big UPI books; TRAI -> BHARTIARTL, IDEA, INDUSTOWER; NPPA -> pharma; DGCA -> INDIGO; duties (CBIC / DGTR / DGFT) -> liquor (bulk Scotch duty = input cost for UNITDSPR, RADICO: a HIGHER duty or a denied FTA rate is NEGATIVE), metals,
  chemicals, autos.
- **How it rings:** a hit on a watched word from a LIVE or WIRE source wakes the analyst at once with the mapped shares - GET READY
  (unconfirmed, quote the source and the time); GO NOW only after a second source or the official page / gazette. Denials,
  "no decision yet", "considering" and clarifications wake the analyst too (the 18 Nov SEBI-MTF miss). The reading of the
  direction is checked by a second model (the 18 Nov MCX margin mistake: lower margins = more trading = good for MCX).
- **Most SEBI / RBI news breaks as a "sources say" story** (TV reporter, wire, X) long before the regulator's site, e.g. 18 Nov
  "SEBI mulls MTF limits" -> ANGELONE fell at once. So the TV reporters' and wires' X accounts (the X API account, when credits are
  added) and the CNBC-TV18 / ET Now live speech-to-text are the first line, not the regulator pages.
- **BASKET SHOCK - the price is often the fastest news:** from the live ticks, 3+ shares of one policy basket (e.g. brokers ANGELONE,
  BSE, CDSL, MCX, MOTILALOFS) moving the same way 1%+ inside 60 s on a volume burst -> alarm within ~10 s "BROKERS falling together -
  news not found yet" -> search every source for the cause -> GET READY with the headline once found. Never a GO NOW on price alone.
- **Speed targets (first source -> GIR page):** basket shock 10 s; X / TV text 15-30 s; wires 30 s; regulator site 60-120 s.
  Measured every day in the 15:45 audit (the first-source time vs. GIR's time vs. when the share began to move).
- **Proof:** replay past policy days from the recordings and news archives (IEX market coupling, the IRDAI commission news, SEBI
  F&O rules): the time the first source had it vs. the time GIR would call, and the share's move in that gap.

## THE WEBSITE - girtrader.com
- GIR's web front end is **girtrader.com** (served by gir-dash on the GIR server). Every page in this file is a page of girtrader.com.
- Private, one user: behind the login (the site password is never shown, copied or sent in any chat); HTTPS only; not indexed by
  search engines (noindex, robots disallow); never embedded or shared publicly (exchange-data licence and SEBI rules - see S7).
- Addresses: girtrader.com (the live trading screen) · girtrader.com/old (the previous page, kept one click away until the new one
  is approved) · girtrader.com/preview (the new design, live data, for the trader to try BEFORE it replaces the main page) ·
  girtrader.com/m (the phone app - installable, push notifications need HTTPS) · girtrader.com/status (GREEN / AMBER / RED health,
  S3) · girtrader.com/shots (screenshots for the trader's review, behind the login).
- New designs go to /preview first, are tested (S5 release gate, 30-minute soak), and replace the main page only with the trader's
  "switch on"; /old stays as the fallback.

## 0. How to work and report (no shortcuts)

- Read the WHOLE file before starting. Every numbered item is a requirement, not a suggestion.
- Keep a checklist table: item number -> done / not done -> what you changed -> screenshot or test output. Update it after each item.
- **Never report "complete" until every item is done and tested.** If an item cannot be done, say so plainly with the reason.
- Test every change on real recorded data (replay a past day) before switching it on, and check the page at 1600x900, 1366x768 and
  phone width (390). Keep a backup of every file you change and one undo line per change.
- Page changes are tested for 30 minutes on replayed data before they go live. No page change during market hours (09:00-15:35 on
  weekdays) unless the trader says "now".
- Standing rules: never use TG_CHAT_FO or TG_CHAT_OI; never print or copy .env; do not touch gir-watchdog or paper_exit_monitor;
  no made-up data (if GIR does not know, it says so); F&O shares only for calls (sector measures use all NSE shares).
- When the trader asks a question, answer it first, each part separately, before doing more work.

## 1. The method - this is GIR's brain (every sector, both directions)

The trader's method, in his words: "It's sector-driven. Find which sector goes up or down from the macro, Indian and market news,
study every share in it, pick the ones in position, tell me GO NOW, and give it time."

1.1 **Know the map.** Every F&O share, its sector, and what drives that sector:
    banks - rates, RBI, bond yields · IT - the rupee, US markets · metals - global metal prices, China · oil & gas, paints - crude ·
    jewellers, gold loans - gold · cables & wires - copper · auto - monthly sales, input costs · pharma - US FDA, the rupee ·
    realty - rates · capital markets - SEBI · FMCG - rural demand, input costs · and so on for every sector. Use the knowledge base.
1.2 **Step 1 - confirm the sector's direction:** a steady move one way from the open to about 10:00 (not a spike); the futures
    build-up agrees (short build-up down, long build-up up); the news confirms (CNBC-TV18, Economic Times, Moneycontrol, or the
    driver itself). Then: "SECTOR DOWN / UP - confirmed since HH:MM · driver · news · build-up".
    **The sector's move, weight and rank come from the WHOLE sector - every listed share in it, not only its F&O shares** (the
    trader, 19 Nov). Use the official NSE sectoral / thematic index where one exists (NIFTY METAL, PHARMA, PSU BANK, IT, AUTO,
    REALTY, FMCG, ENERGY, MEDIA, CAPITAL MARKETS ...: free-float weighted, all constituents). Where none exists (gold loans,
    jewellers, cables & wires, brokers ...), build a free-float market-cap weighted basket of ALL listed shares in that sector from
    the cash market (Kite quotes; the non-F&O names need only price and volume). Breadth (advancers / decliners) is counted over all
    of the sector's shares too, and the "one share = X% of the move" warning uses those weights. Only the TRADE list is limited to
    the sector's F&O shares (options exist only there). A sector moved by a few F&O names while the rest of the sector is flat is
    marked "NARROW - F&O-only move", not confirmed.
1.3 **Step 2 - list every F&O share in that sector**, each with: zone (overbought / oversold / neutral: daily and 5-min RSI, distance
    from the 20-day high and low), speed (beta to the sector, usual day range), size (large / mid / small cap), already moved today,
    room left to the next support or resistance (option floor / roof, 20-day low / high), futures money (fresh shorts / longs).
1.4 **Step 3 - rank them by potential.**
    - Falling sector -> PE. First: the overbought share still holding up (the laggard - it catches down), fast-moving, with room to
      fall and fresh shorts. Then the leaders falling with short build-up, and the dependents (gold -> jewellers and gold loans).
    - Rising sector -> CE. First: the oversold share still lagging (it catches up), fast-moving, with room to rise and fresh longs.
      Then the leaders and dependents.
    - Skip shares that have already used their room. **No "top 3" limit** - every share in position is listed.
1.5 **Step 4 - one line per share:** GET READY / GO NOW · PE or CE · strike (at or near the money, this expiry) · trigger · stop ·
    target · hold until. GET READY when the price nears the trigger; GO NOW when the price confirms. The trader decides to buy or sell.
1.6 **Step 5 - patience and follow-up.** Every call says how long to hold. Follow-ups only when something changes: BOOK HALF when the
    move stalls or hits the target, EXIT on a real reversal, the 15:10 exit for what is left. No exit messages for trades the trader
    did not take.
1.7 **Evening (19:45) and 07:15 watch list.** For every driver that moved (gold, silver, copper, steel and iron ore, aluminium, crude,
    the rupee, US markets, bond yields, China, big Indian and world news): which sectors are likely up or down today and why, every
    F&O share they affect, its zone, and which are most likely to move next. Example: "Gold down -> watch PE: TITAN, KALYANKJIL,
    MANAPPURAM, MUTHOOTFIN... KALYANKJIL overbought and still holding - likely to catch down, PE below X".
1.8 **09:08 pre-open:** check the pre-open prices against the watch list; a met trigger becomes GO NOW at the open.
1.9 **Every analyst output ends in an action per share** - GO NOW / GET READY / HOLD / BOOK HALF / EXIT / nothing to do. Never just a
    list of news. A summary like "fresh shorts in jewellers, metals, cables; pharma long build-up" must come with the calls.

### Proof case - 18 Nov (the test every change must pass)
Gold -2%, copper -4%, silver -3%; CNBC-TV18 discussed gold, steel and copper all morning. The sector run said "09:51 METALS & MINING
down"; the sector board (built later) shows "JEWELLERS & GOLD LOANS DOWN - confirmed since 09:20" and "CABLES & WIRES DOWN - confirmed
since 09:20". Shares: KALYANKJIL (overbought, held near -2%, then -5%), TITAN -5.3%, MANAPPURAM -4.6%, MUTHOOTFIN -4%, POLYCAB -5.1%
(copper 5-month low), SAIL -4.4%, NATIONALUM -3.7%, MOTHERSON -4.4%; pharma the only real long build-up. On the day GIR gave no GO NOW
on any of them. **The finished system, replayed on 18 Nov from 09:15, must call these at about 09:20, with the time, price and result
at the close for each, against the old alerts' late list (OPENING 6-11 min late, FIRST MOVE 12-63 min late).**

## 2. The agents - each must feed the analyst, and each must be accounted for

2.1 Agents: news reader, global / world news, world prices, sector, sector rotation, money (futures OI build-up), options (sudden PE /
    CE buying in one strike), pre-open, theme (driver -> sector -> shares), TV watcher, X (off until credits are added).
2.2 Each agent wakes the analyst when it finds something; the analyst answers with an action (1.9).
2.3 Daily (15:45) report per agent: did it run, what did it find, did it wake the analyst, what reached the trader. An agent that ran
    all day and produced nothing is reported, with the reason.
2.4 Must wake the analyst at once, with the shares and direction: a driver moving sharply; a sector confirming (1.2); clarifications,
    denials and "no decision yet" (e.g. SEBI on the MTF limit -> brokers and exchanges); management on TV ("not affecting us");
    broker calls in live blogs (upgrade / downgrade / target price); results and promoter actions.

## 3. News

3.1 Read every new entry of the CNBC-TV18, Economic Times and Moneycontrol live blogs every minute, plus every feed already set up
    (wires, NSE filings, publisher feeds, Google News, the world feed).
3.2 Every F&O share knows its other names (brands, parent, subsidiaries, old names - Zomato -> ETERNAL). Sector stories map to their
    shares (gold loans -> MUTHOOTFIN, MANAPPURAM). No wrong tags (word clashes such as "Force" -> FORCEMOT, "Nippon" -> NAM-INDIA).
3.3 Read correctly: lower commodity margins = more trading = good for MCX; promoter selling, block deals, "below estimates" and
    guidance cuts outweigh a big headline number; "minimal impact" / "priced in" is not a sell signal; a fine is weighed against the
    company's size (a small fine never rings); old news retold is old news.
3.4 Every news item gets a weight 1-5 using the company's size; only 4-5 can ring; night weight-3 stories get conditional calls for
    the morning.
3.5 Weigh votes by each voter's measured hit rate; a voter with no edge counts zero; show "vote against" on a card when it is.
3.6 No duplicates. One news list on the page.

## 4. Alarms and notifications

4.1 **One sound per alert** - the old alarm layer is switched off underneath the new one.
4.2 **Only these ring:** GO NOW, GET READY on a sector call, and the trader's own exits (STOP, BOOK HALF, EXIT, 15:10). Everything
    else is silent on the page (INFO). No PROFIT BOOKING / MOVING / EARLY / RUNNING / "WATCH, not a trade yet" / briefs as alerts.
4.3 Sounds by meaning: CE = notes up, PE = notes down, GET READY = soft chime, EXIT / STOP = low tone, BOOK HALF = bright chime,
    15:10 = gong, GIR DOWN = three beeps.
4.4 Telegram: one decisions channel (GO NOW, GET READY, the trader's exits). Every other topic is off by default. Held "no ring"
    lines go to the page only.
4.5 Browser "ALERT" tabs do not open by themselves unless the trader turns them on.
4.6 The page shows an alert before Telegram (about 5 s earlier).

## 5. The page - organised in tabs, nothing lost, clean look

5.1 **Top bar, always visible:** NIFTY, BANKNIFTY, SENSEX, VIX, expiry and days left, PCR, FII / DII, the ban pill, search with
    suggestions as you type, sounds on/off, live time and data age, AI spend today.
5.2 **Tabs** (each with a one-line purpose at its top):
    1. **SECTOR BOARD** (opens first) - falling sectors with PE plans on the left, rising sectors with CE plans on the right; each
       sector: confirmed or not, since when, driver, news, build-up; all its F&O shares with role, zone, speed, size, room, money and
       plan (section 1). **The GIR ANALYST's latest decision in big text beside the board.**
    2. **SECTOR ROTATION** - where the money is moving (15M / 30M / 1H / TODAY), sectors gaining and losing, the sector run times,
       with real details inside.
    3. **ANALYST** - every decision today, newest first, each ending in an action, with its follow-ups; ASK in a side drawer; the
       19:45 and 07:15 watch lists.
    4. **MY TRADES** - positions, live P&L, their exits.
    5. **NEWS** - one list: time, share, headline, the AI's direction and weight, source; filters (all / my shares / policy /
       critical / market).
    6. **MONEY & OI** - F&O money, BIG MONEY, futures by month, long / short build-up (LB / SB / SC / LU), option chains, OI scenarios.
    7. **MARKET** - NIFTY / BANKNIFTY chart, F&O movers, results, the EARLY list, the F&O tape.
5.3 **Every feature of the old page is kept** in one of the tabs. Give a table: old place -> new tab, for the trader's approval
    before switching. The old page stays at /old.
5.4 **Must work:** a share name anywhere opens that share's own page (chart, levels, option chain, futures, WHY) with a LIVE price and
    chart; sector click opens in place with live numbers at once; the analyst box shows the latest decision on top and does not blink;
    the PRE-OPEN screen never blocks the page; the ALL SECTORS dropdown filters the page; every list scrolls with a visible bar and
    up / down buttons.
5.5 **The look - a professional trading app:** dark background; big clear text (share names and % at least 14-16 px); space between
    rows; one colour meaning (green = up / CE, red = down / PE, amber = GET READY, grey = info); no walls of tiny text, no boxes
    squeezed together, nothing overlapping or cut off; the sector board and the analyst's latest decision biggest and at the top.
    Show a screenshot of the new layout before switching it on.

## 6. Cost - $20 a day, used wisely, never silent

6.1 Hard cap in the code: **$20 a day** (set by the trader, 18 Nov: start at $20), split across 24 hours (about $5 night and morning prep, $12 market hours, $3 reserve for big
    news). It must really stop at the cap (on 18 Nov it spent $27.24 against a $5 cap - find and fix why).
6.2 Models: Fable only for the final GO NOW check and the 07:15 sector plan; Sonnet for the board's reasoning and follow-ups; Haiku
    for reading every news item. Prompt caching on every call (target 80%+ cached); send only the facts each call needs.
6.3 When the cap is reached: the board keeps making calls from the numbers, Haiku keeps reading, one message to the trader.
6.4 Show the spend on the page, and daily at 15:45: spend by model and by hour, and what it bought (calls made, right or wrong,
    cost per useful call).

## 7. Daily checks

7.1 07:15 - the watch list (1.7). 09:08 - the pre-open check (1.8). 10:00 - the number checker on live data.
7.2 15:45 - the miss audit: every F&O share that moved 2%+, when the move began, whether GIR called it before (and which agent), and
    why not if it did not; the agents' report (2.3); the cost report (6.4); the calls' results.
7.3 Heartbeat: ring when any GIR service stops or data goes stale (prices > 2 min, sector / analyst / desk data > 5 min in market
    hours), once per problem and again on recovery.

## 8. Open decisions for the trader (remind, do not act)

- The X agent: switch on only after X credits are added (X search reaches back 7 days).
- gir-watchdog fails every 5 minutes because paper_exit_monitor is off.
