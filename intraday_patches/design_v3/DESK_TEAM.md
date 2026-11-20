# GIR DESK TEAM - a large analyst desk inside GIR, one voice to the trader (20 Nov 2026, evening)

This file extends and partly replaces ANALYST.md (section 1b and the cost in section 3). Written from five panel reports:
head of desk, production engineer, AI engineer, market-intelligence lead and product designer.

Labels: [F] = taken from a GIR file. [E] = panel estimate. [G] = guess, to be checked. Every market number comes from
EVENT_MEMORY G, LINK_BOOK, OUTSIDE_WATCH or STATUS. None is new. Not investment advice. GIR never places orders.

**The trader's words (binding):**
- 20 Nov: "I need a pool of team which sits inside GIR, monitoring the Indian stock exchange, the Indian stock market, all the
  F&O shares, sectors, and outside the world, everywhere, and analyse and then tell me what to buy in the F&O shares based on
  the news, everything."
- "A senior F&O analyst is inside GIR monitoring everything and telling me what to buy."
- "Not to catch all the 2% moves - the EDGE: the knowledge, the brain should catch the correct F&O shares based on news,
  sectors, external news, internal news, companies' performance - predict before."
- 20 Nov evening: "You are still very confined. I am expecting a much larger pool of team to look for each and every
  information and news. Today was a classic example of why Bank Nifty went up because of the Anthropic AI [IPO]. Like that, a
  positive-thinking and knowledge team I need."
- He also asked: "ask the desk to confirm this will work for GIR" and "is there any change required for the webpage and mobile".
  Section 1 is the desk's confirmation. Section 6 is the web and phone answer.

---

## 1. THE VERDICT

**The desk confirms: yes, a large desk team can work for GIR - with three honest conditions on that yes.**
All five panel members agree on the design.

- **Money: the Monday desk fits $5; the full week-1 roster does NOT yet fit with room to spare.** The Monday subset is estimated
  at ~$3.84 a day + $0.30 Ask reserve = ~$4.14 (table 4.8a). The full week-1 roster (40 seats, benches sharing calls, seats
  speaking only on change) is estimated at ~$4.72 + $0.30 = ~$5.02 (table 4.8b): at the cap, not under it. So at $5 the week-1
  seats join only as far as the measured spend allows (the seat pool has its own sub-cap, 4.7); running all of them on every
  meeting is his decision (about $6 a day). **Every figure is an estimate until F29 logs real token counts; the large team
  fitting $5 is NOT PROVEN until then.** "Look at each and every item" is the cheap part: Haiku readers read every filing,
  wire, TV minute and world headline once for under $1 a day. What costs money is how often Sonnet and Opus think, so they wake
  on events and fixed meetings, not on a short clock.
- **Server: a conditional yes on the 4-CPU box.** The AI thinking happens at Anthropic; gir-desk itself builds snapshots and
  waits on the network, and the new recorders use about 3.5% of one CPU [F, F5]. But the same STATUS row F5 shows the box
  already strained on Fri 20 Nov in market hours: load ~6 on 4 CPUs at 11:20 and 15 at 12:37, dashserve and engine2 at 100%
  each, and girtrader.com/login took 3.0-3.6 s once at 11:21 (0.05-0.5 s otherwise) [F]. Most of that load was the OLD system
  (engine2, falcon, timer bursts; crypto was removed at 15:42). Market-hours load with the old system silent AND gir-desk
  added (one core of CPUQuota, snapshot.py every minute) has never been measured. **So the 4-CPU yes holds only if (a) J6
  silences the old timers and old AI desks before Monday 09:00, and (b) Monday's load watch (5.8) stays under its limits.** If
  either fails, gir-desk drops to readers + head (5.8), and the 8-core resize goes back to him with Monday's numbers.
- **Proof: none yet** (see the honest limit at the end of this section).

**The engineer's conditions are binding:**
(1) the desk runs as its own service that the safety gates never wait for; (2) one hard $5 budget gate sits in code before
every AI call (J11 is NOT STARTED, and on 18 Nov a "$5 cap" let $27.24 through [F]) - no seat goes live before it; (3) the old
system's AI desks (deskteam.py, analyst.py) are OFF on Monday; (4) seats speak only when something changes; (5) world items that
name no Indian company are no longer thrown away (today's B8 rule would have dropped the Anthropic story); (6) Monday 23 Nov
goes live with a lean desk only, labelled NOT PROVEN - the rest joins one bench at a time in weeks 1-3. Honest limit: much of
today's Bank Nifty reason was published during the move (Geojit line 11:02, NSDL sector fact 13:55 [F]). On days like today the
desk will often explain early rather than predict before. Price data alone cannot do it either: at 19:45 and 09:08 the price
lists are "no better than random"; only the 09:45 CE list has an edge [F, preopen_report section 0]. So the edge must come from
knowledge, and it is NOT PROVEN until the scorecard says so.

### 1a. What this file overrides (BUILD_PLAN E12.4 / E13 / E14, SHELL R10, ANALYST.md)
Where this file and BUILD_PLAN.md or SHELL.md disagree, the table says which one stands and why. Anything not listed here keeps
BUILD_PLAN / SHELL as written.

| Rule | BUILD_PLAN / SHELL says | This file says | Why |
|---|---|---|---|
| **E13 replay before shipping** | every prompt or model change passes a replay of 20-30 past days first | **Cannot be met yet:** recorded news / filings reading exists only from 19 Nov evening and TV text from 19 Nov [F, ANALYST.md 4], so at most 3 days (18-20 Nov, 18 Nov without news) can be replayed. Replaced, until 20 recorded trading days exist (about mid-December [G]), by: (1) the 3-day point-in-time replay before Monday (section 7); (2) every new seat or prompt change runs at least 1 trading day in SHADOW with its cards scored before it goes live; (3) a new bench's cards count only as support, never as one of the "two benches" for a BUY NOW (2.3 rule 1), for its first 5 live days; (4) every change is replayed over ALL recorded days so far, growing to 20-30; from the 20th recorded day E13 applies as written. Code seats (tape, technicals, calendar) keep being replayed on the years of minute data as today. | Only recorded days can be replayed; the gap is filled with shadow days and a lower vote weight, and the gap is labelled NOT PROVEN, not hidden. |
| **E13 timeouts** | 2 / 8 / 25 s (small / mid / top) | Haiku ~5 s, Sonnet ~25 s, Opus ~45 s (5.6) | Haiku reads 8 items per call, not one; Opus 5.5 thinking cannot be switched off and B9 already allows 45 s. Fallback ladder unchanged (one tier down, then rules). |
| **E13 schema** | the model returns strike, expiry, entry zone, stop, target | the model returns share, side, reasons and evidence ids only; **code** fills contract, lots, stop, target (4.4, 4.5) | ANALYST.md "no invented numbers": a model that types a level can invent one; code takes it from the snapshot. |
| **E13 budget** | $20 / day hard cap; ladder 60% top model off / 85% / 100% | one $5 hard cap (J11, STATUS desk decision) with protected sub-budgets and a budget day of 15:40-15:40 (4.7) | the 18 Nov $27.24 overspend; the trader's $3-5 rule. |
| **E12.4 second direction check** | every direction that can lead to a call is read twice by an independent model; if they disagree, GET READY at most | **Kept, and made explicit:** the head may START a look on a Haiku card while the Sonnet second read runs, but code holds any BUY NOW as "WAIT: second read" until a second model that did not see the first answer agrees on the side (news / filing: seat 15; theme: the linked sector seat). Disagree or 25 s timeout -> the idea stays ARMED / WATCH with the disagreement shown. The Devil is not the second read (it argues against by design). | 4.3 previously said "in parallel" without saying whether a BUY NOW could go out first. It cannot. |
| **E14 / SHELL R10 sounds** | GO NOW one chime; GET READY on a sector call one soft tick, once; own exits two low notes | **Kept as written.** BUY NOW takes GO NOW's chime; an ARMED idea of the head on a sector call takes GET READY's one soft tick, once (M mutes it 10 min, R10); exits unchanged. Themes, seat cards, Ask answers never ring. | An earlier draft said GET READY never rings; that changed his spec without asking. Silencing the tick is offered to him as a choice (section 7, item 5), not done. |
| **ANALYST.md sections 1b and 3** | 3 sector seats; "Opus every 5 minutes for $2-3" | the seat table (2.2); Opus on events + heartbeat (4.1) | cost of Opus thinking (4.1). |
| **ANALYST.md section 4 (his Monday order)** | BUY NOW goes to him on Monday, NOT PROVEN | **NOT changed by this file without his answer:** see section 7 and item 5 of "What each owner must confirm" - the replay condition is a question to him, not a decision. | his order. |

---

## 2. THE TEAM

### 2.1 How it works on one page
- **Eyes (code):** feeds F01-F31 plus the new feeds in section 3. Code computes every number. No seat ever types a price.
- **Readers (Haiku):** read every new item exactly once (code removes duplicates by hash first) and write a FACT CARD.
- **Seats (mostly Sonnet):** each thinks about one area, reads its slice of the snapshot and writes short cards to the
  **DESK BOARD** (an append-only table, one row per card).
- **CONNECTIONS / THEMES seat:** reads the whole board and writes THEMES: chains of cause and effect that end in Indian F&O
  shares, CE and PE.
- **DEVIL'S ADVOCATE:** writes the best OBJECTION against every theme and every BUY NOW candidate.
- **HEAD ANALYST (Opus 5.5): the ONLY voice to the trader.** Evening brief, at most 5 ideas per side, BUY NOW at most 3-4 a
  day, manage notes, WHY NOT, the scorecard (ANALYST.md section 1, unchanged). It reads the board, not raw feeds.
- **Code gates after the head:** ban, quote age 60 s, spread, R:R, loss lock, 3 trades a day, one per sector. Code attaches
  the December contract (ATM / 1 ITM), lots, stop and target. A failed gate turns BUY NOW into "WAIT: reason".

A seat is not a program. A seat is a prompt, a slice of the snapshot, a schedule and an output form. All seats run inside one
service (section 5).

### 2.2 The seat table
Tiers: C = code · H = Haiku 5.5 · S = Sonnet 5.5 · O = Opus 5.5. "Meetings" = 19:45, 22:45, 07:15, 09:05, 15:45.
"Mon" = live on Monday 23 Nov; "W1" = week 1; "W2-3" = weeks 2-3. In LEAN, several seats share one call (noted).

**Readers (the wide eyes)**

| # | Seat | Watches | Cadence | Model | Writes to the DESK BOARD | When |
|---|---|---|---|---|---|---|
| R1 | Filings reader | NSE + BSE announcements and attachments (F15) | each item, batch of 8 or 20 s | H | FACT card: shares, NEW / REPEAT / DENIAL, side, weight 0-5 | Mon |
| R2 | Wires reader | Reuters / publisher sitemaps, live blogs (F16) | each item | H | FACT card; **THEME card for market / strategy lines B8 drops** | Mon (theme path W1) |
| R3 | TV reader | CNBC-TV18, ET Now (since 07:00); later Awaaz, Sansad TV | one call a minute | H | who said what, speaker record; "TV only - unverified" | Mon |
| R4 | Policy reader | regulators, PIB, Parliament, courts (F20 / F21) | each item | H | FACT with POLICY CLOCK state | Mon |
| R5 | World reader | FinancialJuice, Trump posts, US / Asia company news, tech / AI press, ADRs, EDGAR | each item | H | FACT / THEME card with driver keys (e.g. AI_CAPEX_SHOCK) | W1 |
| R6 | Story matcher | new items vs EVENT_MEMORY; second read on weight-3 items | each item | H | STORY BACK card | W1 |

**World bench**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 1 | US markets and AI / tech | S&P / Nasdaq futures, big tech, the AI-hardware basket, US IPOs, INFY / WIT / HDB / IBN ADRs, US VIX | meetings; 20:00-02:30 IST on a 1% index or 5% AI-name move | S | VIEW: what moved and **the cause**, Indian sectors on each side | W1 (inside Global on Mon) |
| 2 | US policy and rates | Fed, US yields, US data vs consensus, White House, USTR, tariffs, H-1B | meetings + each release | S | rates / DXY tone; policy PE lists | W1 |
| 3 | China and North Asia | China data, CNY, Hang Seng, Nikkei / BoJ, **Kospi, Taiwan, foreign net buy / sell in Korea and Taiwan** | 05:30-09:15 every 15 min, meetings | S | metals read; AI-hardware Asia money in / out | W1 |
| 4 | Europe, Middle East, geopolitics | ECB / BoE, Europe open 13:30, Gulf / Hormuz, OFAC, wars | meetings, 13:30, events | S | ALERT on shock; risk-on / risk-off | W1 |
| 5 | EM money rotation | FPI flows India vs Korea / Taiwan / China, MSCI / FTSE weights, broker EM over / underweights | 19:45, 07:15, on a strategy headline | S | "money leaves X for India", India's FII-heavy names | Mon (inside FLOWS) |

**Commodities bench** (one Global call in LEAN)

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 6 | Energy | Brent / WTI, gas, OPEC, EIA (Wed ~21:00), Indian fuel prices | meetings, events | S | OMC / upstream / paints / airlines sides | W1 |
| 7 | Base metals and steel | LME, copper / aluminium / zinc, iron ore, China steel | meetings | S | metals / cables / auto-cost sides | W1 |
| 8 | Precious metals and agri | gold / silver, IBJA, sugar, edible oil, monsoon | 19:45, 07:15 | S | gold-loan NBFCs, FMCG, sugar | W2-3 |

**Money bench**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 9 | Rupee, rates, liquidity | USDINR, DXY, RBI liquidity, 10y G-sec, OIS | meetings + 8 bp / 0.3% moves | S | banks / NBFC / realty tilt; IT / pharma rupee leg | W1 |
| 10 | **FLOWS (India)** | FII / DII cash (~17:30), participant OI, NSDL daily + **fortnightly sector flows**, AMFI, block deals, ETF units | 17:30-21:00 until data lands; 07:15; NSDL on release | S | VIEW with LINK_BOOK B7-7 rule (net buy > Rs 5,000 cr = banks first), streak, sectors FIIs bought | **Mon** |

**India policy bench**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 11 | Government and Parliament | PIB, Cabinet, gazette, sansad.in, GST council | each item; 07:00 watch | S | FACT + POLICY CLOCK (PENDING / CONFIRMED / NOTIFIED) + baskets | W1 |
| 12 | Regulators | RBI, SEBI, IRDAI, TRAI, CCI, NPCI, CERC, DGCA, CDSCO, NPPA | each item | S | FACT + F&O shares and side | W1 |
| 13 | Courts and tribunals | SC / HC cause lists, NCLT / NCLAT / APTEL, LiveLaw | 19:45 (tomorrow's list), live when called | S | "case listed today"; order | W1 |
| 14 | States and elections | state power / mining / excise, poll calendar | 19:45, events | S | VIEW | W2-3 |

**Company bench**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 15 | Filings desk | R1 cards weight 4+ | each item, 20 s target | S | NEW / REPEAT / DENIAL / OFFICIAL, sized vs revenue | Mon (as News confirm) |
| 16 | Results, guidance, calls | results, guidance, concalls, **global peer read-across** (Accenture, US banks, chips) | results days live, 19:45, 07:15 | S | beat / miss; read-across | W1 |
| 17 | Corporate actions and deals | block / bulk, pledges, OFS / QIP, lock-ins, rebalances, F&O adds, ban / MWPL | 19:45, 07:15, live on block deal | S | flow size vs average volume | W1 |
| 18 | Broker and analyst calls | upgrades / downgrades, morning notes, strategist lines | 07:00-09:05 every 10 min | S | VIEW with the broker's record; support only | W2-3 |

**Sector bench** (3 seats Monday as ANALYST.md has them; 9 from week 1)

Each watches the whole-sector move (R49), breadth, leaders / laggards, sector news and every linked driver in LINK_BOOK /
SECTOR_LINKS. Cadence: 19:45 and 07:15 on Sonnet; live on events (F27 basket shock, R49 move of 1% in 15 min). Writes a
sector VIEW and the 2-3 best F&O shares each way, with role and trigger.

| # | Seat | Notes |
|---|---|---|
| 19 | Banks (private and PSU) | FII ownership and flows, rates, asset quality |
| 20 | NBFCs, insurers, capital markets | rates, credit scares, SEBI rules |
| 21 | IT services and EMS | cause of the US tech move, ADRs, rupee, deals; EMS / AI-hardware link (DIXON, KAYNES) |
| 22 | Pharma and healthcare | US FDA, tariffs, rupee |
| 23 | Auto and ancillaries | VAHAN, monthly sales, metal costs |
| 24 | Metals and mining | works with seats 3 and 7 |
| 25 | Oil and gas, power, renewables | works with seat 6, IEX, coal |
| 26 | Capital goods, infra, defence, rail, cement, realty | orders, capex, DAC, rates |
| 27 | Consumer: FMCG, retail, telecom, media | demand, GST, tariffs |

**Voices and market-internal benches**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 28 | TV desk | R3 lines, speaker records | live | H/S | context, bounce risk; never alone | Mon |
| 29 | News and wires | R2 cards into stories | each item | H | FACT / STORY BACK | Mon |
| 30 | Social and chatter | t.me/s public channels; X only when paid (F19 OFF) | W2-4 | H | "BUZZ, no fact yet"; never a reason to buy | W2-3 |
| 31 | Derivatives | OI all months, December chains, IV, PCR, rollover, FII index positions | hourly in session + 1 meeting (LEAN, from W1) | S | where fresh money is; IV traps; strikes | W1 (data exists) |
| 32 | Technicals and regimes | RSI regimes, levels, onset timing, 09:45 CE edge | meetings | C+S | regime line ("EXTREME - pullback entry only") | Mon (code) |
| 33 | Live tape | R49 sector %, breadth, RVOL, VWAP side, relative strength vs NIFTY, F27 | every 5 min, code first | C | ALERT "sector X holds VWAP on a red NIFTY" = **live proof of a theme** | Mon (code) |
| 34 | Calendar and event clock | econ calendar, results dates, expiry, holidays, MPC / Fed | 19:45, 07:15 | C | no-entry windows, catalysts | Mon (code) |

**Reasoning bench (the brain of the team)**

| # | Seat | Watches | Cadence | Model | Writes | When |
|---|---|---|---|---|---|---|
| 35 | **CONNECTIONS / THEMES** | the whole board, LINK_BOOK, SECTOR_LINKS, CHAIN_OF_EVENTS, EVENT_MEMORY | 19:45, 07:15, 09:05; plus on a world shock (2+ drivers or a strength-4 world / money / policy card); FULL adds 22:45 and hourly | O (fixed times) | THEME card: the chain; **India winners CE and losers PE**, each with a role; first vs second order; what confirms live, what kills it; past analogue; state NEW / CONFIRMING / CONFIRMED / BROKEN; episode count | **Mon** |
| 36 | **DEVIL'S ADVOCATE** | every theme and idea, LINK_BOOK C ("when links fail"), scorecard, RSI / breadth / VIX | every meeting + every BUY NOW candidate | S | OBJECTION: best case for the other side, the trap that applies, what is priced in, what would prove it wrong | **Mon** |
| 37 | History / event memory | EVENT_MEMORY, SECTOR_LINKS proof rule | on demand | C+S | analogues; NOT PROVEN until enough episodes | W1 |
| 38 | Trader's reads | his spoken / typed reads (trader_reads.json) | within minutes of a read | C+H | evidence for and against; his record (CE 10 of 14, PE 7 of 18, small n [F]) | Mon |
| 39 | Risk manager | positions, lock room, exits | every minute (code); Sonnet note on stop / target / thesis change | C+S | APPROVED or WAIT; manage notes to the head | Mon (code) |
| 40 | Scorekeeper | every card | 15:45 | C | scores by seat, bench and source; trust weights | Mon (logging), W1 (weights) |
| **H** | **HEAD ANALYST** | board summary, top notes, DESK SNAPSHOT, thesis book, trader reads, positions | briefs 19:45 / 07:15 / 09:08 (22:45 only if changed); live **when woken** + heartbeat; 15:45 | O | the brief, ideas, BUY NOW, manage, WHY NOT - **the only voice** | **Mon** |

Model choice for CONNECTIONS: the head of desk proposed Sonnet; the AI engineer proposed Opus and costed it (3 calls a day in
LEAN, $0.44). **Settled: Opus at the fixed times, Sonnet for any extra live re-check.** It shares the head's cached prefix.


> **FLOWS rule (checker fix, 20 Nov):** LINK_BOOK section 7 - one day of FII flows is noise; the FLOWS seat uses the **5-day sum** (net buy above Rs 5,000 cr over 5 days -> banks / heavyweights CE tilt) and grades it **LOW (a tilt, never a trigger)** per LINK_BOOK row 37. The 19 Nov call still holds: a 14-session buying streak puts the 5-day sum far above Rs 5,000 cr.

### 2.3 Rules for the head when it uses the board
1. **Two benches must agree.** Two seats reading the same article count once. Or: one OFFICIAL fact plus price confirmation.
2. **Every idea carries the Devil's best objection and the answer.** An unanswered objection turns the idea into WATCH.
3. **Themes enter as WATCH.** A theme's names become BUY NOW only on live confirmation: the linked sector holds VWAP, beats
   NIFTY over 15-30 minutes, breadth agrees (SECTOR_LINKS D). The 09:45 CE edge and the EXTREME-RSI rule (no breakout CE) stay.
4. **No lone voice.** TV, social and "sources say" cards never drive a BUY NOW alone.
5. **Weights come from the scorecard,** and move only after 20+ scored cards per seat.
6. **The positive-thinking rule (his 20 Nov ask).** Every negative world shock must get a line: "Where does the money go? Who in
   India gains?" Macro, Connections and sector seats must fill BOTH winners and losers, or write "none found + reason". This is
   in the JSON contract, not left to chance.

### 2.4 The meeting rhythm (IST; winter: US 20:00-02:30, Asia opens 05:30-07:00, Europe 13:30)
- **15:45 REVIEW.** Scorekeeper scores the day by seat and source. Connections writes "what happened and why" for the biggest
  sector moves; a move a link could have predicted but nobody named is logged as a MISS. Day reviews go via the Batch API
  (half price).
- **17:30-19:30 collection.** FII / DII, bhavcopy, participant OI, deals, results, NSDL, US pre-market, Europe.
- **19:45 EVENING CONFERENCE.** Order: World -> Commodities -> Money (Flows first) -> Policy -> Company -> Sectors ->
  Derivatives / technicals -> Connections proposes themes -> Devil objects -> History adds analogues -> **Head writes the
  EVENING BRIEF** (market view, at most 5 ideas per side, each with WHY (seats), AGAINST (Devil), trigger, cancel, NOT PROVEN).
- **22:45 NIGHT CHECK** (silent unless something changes). US open, big listings, shocks. Connections re-checks themes. The
  head updates only if a theme changed state or an idea was cancelled.
- **07:15 MORNING MEETING.** US close, Asia live (seat 3 from 05:30), GIFT, ADRs, overnight filings, first TV, broker notes.
  Connections confirms or kills each theme. Devil second pass. Head brief leads with "changed since 19:45".
- **09:05 PRE-OPEN HUDDLE.** Pre-open under the J9 thin rule (nothing before ~09:08 counts). Head writes the 09:08 list: ideas
  STAND / CHANGED / CANCELLED, each with the live confirmation it waits for.
- **LIVE 09:15-15:10.** Readers work as items land. Tape every 5 min (code). Sector seats on events. Head wakes on a confirmed
  strength-4+ card with price agreeing, on an idea's trigger, or on its heartbeat. Checkpoints: 09:20 (no confirmation before),
  09:45 (the measured CE window), 10:30, 13:30 (Europe; seat 4), 14:30 (manage only), 15:10 (exit).

### 2.5 The 20 Nov worked example: AI IPO -> FII rotation -> banks / IT

**This is hindsight.** The honest test is the replay harness (section 7), where each seat sees only what existed at that
minute. Every [G] time must be checked there. We do NOT claim this team would have caught it.

**Thu 19 Nov, 17:30-19:45**
- **FLOWS (10):** FII net buy Rs 7,411 cr, 14th straight session [F] (MC says 8th - settle it). LINK_BOOK B7-7 fires:
  "net BUY above Rs 5,000 cr -> CE on the heavyweights, banks first, 1-5 days". Card: BANKS CE, strength 3. If NSDL's 1-15 Nov
  sector file was already out [G], it adds "financials took Rs 43,102 cr of FII money in the first half of November" [F, BS].
- **EM ROTATION (5):** about $8.5 bn of November FPI buying into India [F] while money leaves Korea / Taiwan [F]. Card: "India = the low-AI
  market inside EM".
- **US / AI (1):** Anthropic priced at $83 for its Nasdaq listing that night [F]; S&P on a losing streak on AI-spend worries [F]. Card:
  "AI-capex doubt; tonight's listing is the event".
- **CONNECTIONS (35), first theme:** "AI-capex doubt -> money out of AI hardware (US chips, Korea, Taiwan) -> into India ->
  private banks first (HDFCBANK, ICICIBANK, AXISBANK, KOTAKBANK), IT services second if the rupee helps." State NEW, NOT PROVEN.
- **DEVIL (36) against the desk's real 19 Nov call, IT PE (which was WRONG [F]):** "LINK_BOOK B7 2026 trap: Nasdaq down no
  longer means Indian IT down - read the CAUSE. If the US fall is AI hardware / AI capex, Indian IT sells AI services, not chips.
  IT is oversold after 3 down days." Result: IT PE downgraded to WATCH both ways.
- **DEVIL against banks CE:** month already up; RSI EXTREME. Result: banks CE only on a pullback or VWAP reclaim, never chased
  at the open.

**22:45 night check**
- **US (1):** ANT opened at $111.50 against its $83 price [F]; US tech falling; AMD heavy.
- **CONNECTIONS:** theme -> CONFIRMING. [G]: money chases the new listing and sells other AI names.
- **Head:** brief updated: IT PE cancelled (WATCH both ways); banks CE stands with its entry rule.

**Fri 20 Nov, 07:15**
- **US (1):** S&P about -2.0%, Nasdaq about -2.3%, AMD about -10%, 6th straight S&P loss [F].
- **ASIA (3):** Nikkei -4.3% [F]; Kospi / Taiwan sharply lower (exact figure's period to check [G]).
- **METALS (7 / 24):** risk-off -> metals PE. This would have been right: metals were the worst, -1.8% to -2.5% [F].
- **Head 07:15 brief:** lower open; PE watch on metals; CE watch on private banks (flows theme) and IT (AI-adopter case), both
  ONLY if they hold VWAP and beat NIFTY after 09:20 on a weak market. Relative strength against a red tape is the proof the
  money is really moving.

**Live**
- **TAPE (33) + IT (21):** Nifty IT led, up to +1.3-1.6% (TCS, Tech Mahindra, HCL Tech, Infosys) while US tech fell [F]. Card:
  "IT holds above VWAP on a red NIFTY = theme live". Fits the 09:45 CE window. Exact minutes [G].
- **TRADER READS (38):** his 10:45 read ("money out of US tech into Indian IT") [F] matched to the theme within minutes, with his
  record attached.
- **BANKS (19) + TAPE:** BANKNIFTY recovered about 600 points by 09:57, made records from 11:31 [F], closed at a record 64,635,
  +2.49% [F]. The head's BUY NOW on a private-bank December ATM CE waits for the sector to hold VWAP and beat NIFTY. Code attaches
  contract, lots and gates.
- **THEME path (R2 -> 10 / 35):** Geojit's "FIIs are buying back the banks they sold to fund the AI trade" via the MC live blog
  at 11:02 [F]. Today B8 rule N5 treats this as "not company news". With the new theme path it confirms the chain.
- **RESULTS (16):** IndusInd Q2 turnaround, +8.6% [F] - an extra bank leg.
- **DERIVATIVES (31):** expiry short covering NOT confirmed (no 20 Nov OI found) [F]. Said openly.
- **DEVIL, live:** breadth 1,582 up / 2,456 down, VIX +8% [F]. Narrow rally: stay with leaders, no laggard chases.

**15:45 score:** banks CE theme right; IT PE wrong (the Devil's objection is what would have stopped it); metals PE right.
EVENT_MEMORY G gets episode 1. It stays NOT PROVEN.

**What 20 Nov teaches the build**
1. The banks call was reachable on 19 Nov evening from data GIR already collects (FII / DII + a LINK_BOOK rule), once a FLOWS
   seat and a CONNECTIONS seat read it.
2. The IT call needed reasoning about the cause (Devil + Connections), not a price rule.
3. It fails without: (a) the theme path for items B8 drops; (b) Korea / Taiwan foreign flows; (c) NSDL sector flows; (d) a
   tech / AI source list.
4. **Data conflict to settle before scoring:** EVENT_MEMORY G says "weak rupee (dollar near a 19-month high)"; OUTSIDE_WATCH
   (MC 12:24, ET 13:20) says "rupee at a 7-month high". These point opposite ways in LINK_BOOK row 23. Check the NSE CDS close.

---

## 3. COVERAGE: every source -> seat

"Have" = in BUILD_PLAN F01-F31 or measured in STATUS / external_delays. Speed: S0 <= 10 s, S1 <= 60 s, S2 <= 5 min,
S3 before the meetings, S4 scheduled.

| Area | Source | Seat | Have? | Free? | Speed |
|---|---|---|---|---|---|
| Exchange | ticks, futures, indices, VIX | sectors, 31, 33, head | F01 partly | Kite (paid) | S0 |
| Exchange | December chains | 31 | F04 / F05 partly; store every 15 min; 09:15 sweep built, not proven | Kite | S0-S1 |
| Exchange | R49 whole-sector baskets | sectors, 33 | F03 partly; I6 OK | Kite | S0 |
| Exchange | basket shock (3+ shares in 60 s) | all | **F27 NO** | code | S0 |
| Exchange | ban / MWPL | 39, 17 | F12 partly | free | 08:45 |
| Exchange | bhavcopy, bulk / block, participant OI | 10, 17 | F13 partly (EOD) | free | S3 |
| Exchange | GIFT NIFTY | 1-5 | F02 (fixed by 07:40 login) | Kite | S0 |
| Exchange | **USD/INR live (NSE CDS)** | 9, 10 | **NO - "CDS not subscribed"** | his decision | S1 - key gap |
| Exchange | MCX crude / metals live | 6, 7 | NO - not subscribed | his decision | S1 |
| Exchange | index rebalances (NSE, MSCI, FTSE) | 17, 5 | NO | free | S3 |
| Company | NSE announcements | R1, 15 | F15, 11 s median (after hours) | free | S0 |
| Company | BSE announcements | R1, 15 | F15, 44 s; **403 since 16:16 Fri** | free | S1 - fix |
| Company | results XBRL | 16 | F15 partly | free | S0 |
| Company | consensus estimates | 16 | NO | paid | S3 |
| Company | concall audio / transcripts | 16 | NO | free (STT costs) | S1 / S3 |
| Company | pledges, insider / SAST | 17 | raw only, no reader | free | S3 |
| Company | broker public notes (ICICIdirect, Motilal, Kotak) | 18, 35 | NO (WEB #68-70 outside) | free | S3 |
| Company | Trendlyne | 18 | NO | paid (his yes) | S3 |
| Company | **strategist theme lines (e.g. Geojit)** | 35, 10 | arrive in live blogs; **dropped by B8 N5** | free | S1 - key gap |
| Policy | SEBI, RBI, TRAI, CCI, PIB | R4, 11, 12 | F20 partly; PIB 139 s, RBI 432 s | free | S1 |
| Policy | IRDAI, CERC, CDSCO, NPPA, NPCI, DGCA... | R4, 12 | partly; NPCI 403, NPPA no DNS, IRDAI robots forbid (do not bypass) | free | S1-S2 |
| Policy | sansad.in, Sansad TV | R4, 11 | partly; 449 s; timeouts | free | S1 |
| Policy | DIPAM OFS, GST Council | 11, 17 | NO | free | S3 |
| Policy | SC cause lists, LiveLaw, NCLT | 13 | partly | free | S3 / S1 |
| Policy | day policy watch (F21) | 11 | NO (build) | code | 07:00 |
| Money | NSE provisional FII / DII | 10 | F13 partly | free | S3 |
| Money | **NSDL FPI daily + fortnightly sector flows** | 10, 5 | **NO** (WEB #13) | free | S3 - key gap |
| Money | offshore ETF units (INDA, EPI, FLIN, EWY, EWT) | 5, 10 | NO (new) | free CSVs | S3 |
| Money | AMFI, SEBI MF flows | 10 | NO | free | S4 |
| Money | 10y G-sec live (CCIL) | 9 | NO | free | S2 |
| Money | VAHAN, MOSPI, Grid-India, IEX | 23, 25 | F24 NO | free | S4 |
| World | US futures, DXY, US10y, Brent, Nikkei / HSI / Kospi | 1-7 | F23 via Yahoo, **600-1,200 s old** | free (live = paid) | S2 |
| World | **Korea / Taiwan foreign net buy / sell (KRX, TWSE)** | 3, 5 | **NO, in no list** | free [G] | S2 (lands in our session [G]) - key gap |
| World | US data, Fed, Treasury | 2 | calendar F22 / I7 live; BLS / Fed / FRED NO | free | S1 |
| World | Federal Register, White House, USTR, OFAC | 2, 4 | Trump posts yes (60 s); rest NO | free | S2 |
| World | ECB / BoE / BoJ / PBoC | 2-4 | NO | free | S2 |
| World | China CNY, Dalian / SHFE | 3, 7 | F23 partly | free | S2 |
| World | **tech / AI industry news** (AI labs, chips, hyperscaler capex), US IPO calendar | R5, 1, 21 | **NO - all new** | free | S2 - key gap |
| World | US results of Indian IT clients (Accenture, Cognizant) | 16, 21 | NO | free | S3 |
| Wires | Reuters sitemap | R2 | F16 partly | free | S1 |
| Wires | ET, MC, BS, CNBC, Mint sitemaps; live blogs | R2 | F16; **129 s median vs 60 s target** | free | S2 realistic |
| Wires | FinancialJuice | R5 | I4: 58 s | free (Pro ~$23 / mo, his yes) | S1 |
| Wires | PTI / Reuters paid wire | R2 | NO; the only way under 60 s (I3) | paid (his yes) | S1 |
| TV | CNBC-TV18, ET Now STT | R3, 28 | F17 / I2: 29 s | Deepgram (running) | S1 |
| TV | Awaaz, Zee Biz, BT, Sansad TV | R3 | NO | more Deepgram minutes | S1 |
| Commodities | LME (Westmetall) | 7 | added | free | S3 |
| Commodities | EIA, OPEC, IBJA, PPAC, UKMTO | 6, 8, 4 | NO | free | S1-S3 |
| Social | Telegram public channels | 30 | F18 NO (t.me/s fallback) | free | S1 |
| Social | X lists | 30 | F19 OFF | paid | S1 |
| Memory | trader reads, EVENT_MEMORY, LINK_BOOK, SECTOR_LINKS, scorecard | 35-38, head | have | - | - |

**The gaps that matter (in build order)**
- **G1 Theme path (code + Haiku, no new source).** Every live-blog, TV and wire line that B8 drops as "basket / strategy / no
  single company" goes to Connections and Flows, tagged THEME. B8 stays as it is for share news votes. Single most important
  change for a 20 Nov kind of day.
- **G2 NSDL FPI daily, fortnightly by sector, daily DII.** Free. Held the "financials Rs 43,102 cr" fact we saw only at 13:55.
- **G3 Korea / Taiwan foreign flows and closes (KRX, TWSE).** Free [G]. Publish times and server reachability untested.
- **G4 Tech / AI source list + world reader.** Free. Anthropic, AMD and Nvidia are on no source list today.
- **G5 Offshore ETF units** (INDA / EPI / FLIN / EWY / EWT). Free issuer CSVs. Shows rotation in units, not words.
- **G6 Live USD/INR (NSE CDS on Kite).** His decision. Settles the rupee conflict and drives LINK_BOOK row 23 live.
- **G7 Broker / strategist morning notes before 07:15.** Free (WEB #68-70 moved to the server).
- **G8 LINK_BOOK link (PROPOSED):** "AI-capex / AI-hardware selloff abroad -> FPI rotation from Korea / Taiwan -> India private
  banks + IT services CE; AI-hardware-linked EMS and metals PE". 1 episode, NOT PROVEN, 19 Nov IT PE as counter-example. Next test:
  the next US-tech-down day. Also add Korea / Taiwan flows to MISSING_KNOWLEDGE.
- **G9 FII-in-session proxy [G].** FII-heavy large caps rising together on volume + rupee firming + index-futures OI build-up.
  Score against the 17:30 provisional figure for 20 days before it may vote.
- Standing gaps: BSE 403, wires LATE (129 s), world prices 10-20 min old, F27 not built.

**His decisions (paid or personal):** CDS / MCX segments; FinancialJuice Pro (~$23 / mo); PTI / Reuters wire; Trendlyne;
X credits; Telegram spare phone; more Deepgram channels; EPFR.

---

## 4. AI DESIGN AND COST

### 4.1 Tiers
- **Haiku 5.5 readers:** effort low; thinking may be disabled (`thinking: {type: "disabled"}` is accepted on Haiku 5.5 only
  at effort high or below, so fine at low); JSON via structured outputs; micro-batch (8 items or 20 s); TV one call a minute for
  both channels. Prompts kept under 100K tokens because Haiku 5.5's $0.10 / $0.50 price applies only up to 100K ($0.50 / $2.50
  above). The claim that Haiku 5.5 "counts about 30% more tokens than older models" has no source [G]: measure with
  count_tokens on real reader prompts before Sunday.
- **Sonnet 5.5 seats:** routine notes at effort low (adaptive thinking, the default); effort medium only for event notes.
  **Do not send `thinking: {type: "disabled"}` to Sonnet 5.5 - it returns a 400.** Where a route must have thinking off, send
  `thinking: {type: "between_tools"}` (no other thinking field; only at effort high or below; effort cannot change
  mid-conversation with it). One call covers the seat's (or bench's) whole area, never one call per share.
- **Opus 5.5 (head + Connections):** **thinking cannot be switched off and is billed as output ($20 / M).** Effort low for live
  looks, medium for briefs and Connections. max_tokens 16k for Opus, 8k for seats (the 20 Nov replay had answers cut at
  max_tokens, 9% rules fallback [F]).
- **Correction to ANALYST.md section 3:** "Opus every 5 minutes for $2-3" is too low because of thinking. Estimate about $6.6 a
  day for that part alone [E]. So in LEAN the head is **woken by events plus a heartbeat every 45-60 min**, capped at 10 live
  calls (rules in 4.3a). A 10-minute clock is FULL only (needs his yes).
- API notes: forced tool_choice errors on Opus / Sonnet 5.5 - use structured outputs (output_config.format) and validate in code
  anyway. On stop_reason "refusal": fallback on Opus / Sonnet; Haiku retries once on Sonnet or drops and logs. Fast mode on Opus
  (2.5x faster, 2x price) only for event looks and only with his yes.

### 4.2 Caching
- One shared Opus prefix for head + Connections, in this order: frozen instructions + JSON schema -> KNOWLEDGE DIGEST (measured
  rules, a one-line-per-link LINK INDEX of the 160 KB LINK_BOOK, SECTOR_LINKS proof lines, open stories, seat weights frozen at
  07:00) -> breakpoint with **1-hour TTL** -> today's static context (brief, thesis book) -> second breakpoint -> live data LAST.
- One shared Sonnet prefix for all seats; seat text after the breakpoint. The default 5-minute cache would expire between seat
  runs, so use the 1-hour cache on the standing block.
- Never send the full ~310 KB of knowledge files. Code retrieves only the matching LINK_BOOK / EVENT_MEMORY entries by driver key.
- Digest built nightly, sorted JSON, no timestamps before the breakpoint. Check cache_read_input_tokens on every call.
  Target 70-80% cache reads (about 13% today [F, E13]).
- Batch API (half price) for nightly work: day reviews, digest refresh, story matching, the replay's Haiku layer.

### 4.3 Wake rules (code; several within 60 s merge into one call)
- Fact card weight >= 4 on an F&O share -> its sector seat + news confirm -> head only if confirmed AND price agrees.
- World mover past a threshold -> macro / world seat; 2+ drivers or a big shock -> Connections. Thresholds [G] to tune: Nasdaq
  futures ±1%, Kospi / Taiwan ±2%, Brent ±2%, DXY ±0.5%.
- R49 sector move >= 1% in 15 min or rotation alarm (E11) -> that sector seat.
- An idea's trigger met (code) -> Devil + head -> BUY NOW or WAIT.
- Open position -> code every minute; Sonnet note only on stop / target / thesis change.
- Minimum gaps: sector seat 10 min (except weight 5); head 3 min; at most one head event look per 60-90 s, one queued follow-up.
- On weight 4-5 items, the head may wake on the Haiku card while Sonnet confirms in parallel; it still needs price agreement,
  and **no BUY NOW leaves code until the Sonnet second read agrees on the side** (E12.4, section 1a). Until then the card reads
  "WAIT: second read"; on disagreement or a 25 s timeout the idea stays ARMED / WATCH and shows the disagreement.

### 4.3a Head live-call cap (LEAN)
- 10 live head looks per session (09:15-15:10): **8 shared looks** (events and heartbeats) + **2 trigger slots** that only an
  idea's trigger (BUY NOW candidate) or a manage note on his own open trade may use.
- **A heartbeat fires only if the head has not looked in the last 45-60 min.** Event looks reset the heartbeat clock, so a busy
  morning uses the shared looks on events and the heartbeats simply do not happen; a quiet day uses them as heartbeats.
- **When all 10 are spent and a trigger fires:** if the protected LIVE money (4.7) still has room, the head gets up to 3 extra
  trigger looks (the count cap is soft, the money cap is hard). If LIVE money is spent, the card reads "WAIT: AI live budget
  used - rules view only" and no BUY NOW is issued; code still manages his open trade (stop / target / 15:10) and rings exits
  as always. Never a BUY NOW without a head look.
- Minimum gap 3 min between head looks; at most one event look per 60-90 s with one queued follow-up (unchanged).

### 4.4 Contracts (structured outputs, checked again in code)
**SEAT CARD:** `{seat, kind: FACT|VIEW|THEME|OBJECTION|ALERT|QUIET|CANCEL, headline (<=25 words), strength 1-5,
claims: [{text, type: FACT|INFERENCE|JUDGEMENT, evidence_ids}], ideas: [{symbol, side CE|PE, horizon TODAY|TOMORROW|2-5D, why_ids,
against, trigger_ref (engine enum: PDH_BREAK, VWAP_RECLAIM, ORB5...), cancel_ref, conviction, link_ids, story_id}],
winners: [...], losers: [...] (required for world / Connections / sector seats; "none" needs a reason), new_since_last,
expires: 15:10|NEXT_OPEN|2D, linked_card_ids}`. Evidence ids carry source, first-seen time and grade (OFFICIAL / ON RECORD /
SOURCES SAY / OPINION / SOCIAL). Code adds card id, time, seat version, snapshot id.

**HEAD:** `{desk_view (<=80 words), market_lean UP|DOWN|MIXED + reason_ids, ideas_new (<=5 per side) with why / against /
trigger_ref / cancel_ref / source card ids, ideas_update (STANDS|CHANGED|CANCELLED + reason), buy_now (<=1 per call; daily cap in
code), manage (HOLD|BOOK_HALF|MOVE_STOP|EXIT), why_not (PRICE_ONLY|EXTREME_RSI|NO_REASON|AGAINST_SECTOR|GATE|LATE - LATE added 20 Nov in desk/prompts/CONTRACTS.md
for a move already half done, PREDICTION_LOOP B4), ask_seats, nothing_new}`. The full JSON schemas, the light THEME form for
non-35 seats and the E12.4 `second_read` block live in desk/prompts/CONTRACTS.md.

### 4.5 Validators (no invented numbers)
- The AI never types a number. Numbers appear only as placeholders such as `{num:sec.BANK.pct}` that code fills from the snapshot.
- Rejected: any bare digit in text (short whitelist: FY26, Q2, December); any evidence id not in THAT call's input; any symbol
  outside the F&O list; any trigger outside the enum; a side that contradicts its claims; an idea with no FACT claim; max_tokens
  cut-offs; bad JSON.
- On failure: one retry with the error text, then drop and log. A half answer is never used.
- B8's DIRECTION WRONG block and the B6 rule line stay in front of every BUY NOW.
- Pass bar: zero unsourced numbers shipped; at least 99% valid JSON after one retry.

### 4.6 Scoring feedback
- At 15:45 every card and idea is scored with the E1 EDGE definitions: right = +2% its way before -1% against (by 15:10 and by
  next close); earliness; move left; wrong side; lift vs random shares of the same day and side; top-5 hit rate.
- Kept per SOURCE: each publisher, TV voice, broker, filing type, link id, story, SEAT and TRADER READ.
- Weight = shrunk hit rate (hits + a) / (n + a + b), prior = the day's base rate. Small n stays near base rate and shows NOT PROVEN.
- Weights frozen into the 07:00 digest so the cache is not broken in the day.
- Keep / drop (E13): after 100 scored ideas a seat with lift <= 1.0 goes on probation (event-only, prompt reworked). A seat must
  earn at least 3x its cost.

### 4.7 Budget day, protected sub-budgets and ladder (checked in code BEFORE every call, plus a spend limit on the Anthropic console)
- **The budget day runs 15:40 to 15:40 of the next trading session** (after the 15:10 exit and the close). It opens with the
  15:45 review, then the 19:45 conference, 22:45, 07:15, 09:05 and the live session. **Changed 20 Nov (server J11, accepted by the
  desk): every calendar day is its own 15:40 -> 15:40 budget day with its own $5 and buckets.** Sun 15:40 -> Mon 15:40 is Monday's
  day (it holds the Sunday 19:45 brief); Fri -> Sat and Sat -> Sun are weekend days (readers in slow mode, one batch per 5 min, the
  seats event-only); Mon -> Tue is the holiday day (Tue 24). Weekend news reading can no longer eat Monday's money. The console spend limit is set as a monthly ceiling (about 21 x $5 + margin) because the console does not know our day.
- **The $5 is split into sub-budgets; no bucket may spend another bucket's money:**

| Bucket | What it pays for | Sub-cap | Monday est. | Week-1 est. |
|---|---|---|---|---|
| MEET (protected) | 19:45 / 07:15 / 09:05 CONNECTIONS (Opus) + DEVIL at those meetings + head briefs 19:45 / 07:15 / 09:08 + 15:45 scorecard + the Opus 1-hour cache write; one 22:45 head update fits in the margin | $1.50 | $1.34 | $1.34 |
| LIVE (protected) | head live looks (4.3a), DEVIL on each BUY NOW candidate, the second read (seat 15) on weight 4+ items, the Opus 5-minute cache write | $1.30 | $1.15 | $1.15 |
| READ | Haiku readers R1-R6, trader-reads Haiku part | $1.00 | $0.70 | $0.92 |
| SEATS | every other Sonnet seat or bench call + Sonnet / Haiku cache writes | $0.90 | $0.64 | $1.31 (trimmed to $0.90) |
| ASK | Ask-the-desk answers (his call on the size) | $0.30 | - | - |
| **Total** | | **$5.00** | **$3.84 + $0.30 = $4.14** | **$4.72 + $0.30 = $5.02** |

- Protected means: when SEATS or READ run out, MEET and LIVE are untouched, so the 19:45 / 07:15 / 09:05 Connections + Devil +
  head briefs (the runs that would have caught 20 Nov) always run, and the live BUY NOW chain still has money at 14:00. After
  09:08 unspent MEET money may move to LIVE. Nothing carries over to the next budget day.
- **Ladder (applies per bucket, so a normal day never degrades itself):**
  - SEATS at 70% -> sector, world, derivatives and company seats event-only; at 100% -> seats stop until the next budget day
    (code seats - tape, technicals, calendar, risk - keep running; they cost nothing).
  - READ at 100% -> readers take items by weight; low-weight items are marked UNREAD and logged ("what I am not seeing").
  - LIVE at 100% -> "WAIT: AI live budget used - rules view only"; no new BUY NOW; exits and stops are code and still ring.
  - MEET at 100% -> the next brief is the code summary with "head analyst over budget" in grey.
  - Total $5 reached (any mix) -> code + rules only; one message to him.
- Footer meter shows $ spent by Opus / Sonnet / Haiku, each bucket and the ladder step.
- Week 1 at $5: the SEATS cap means the full roster runs at reduced cadence (event-only once 70% is used). Running every
  week-1 seat on every meeting needs about $6 a day (his yes) - and only after F29 shows the real numbers.

### 4.8 LEAN cost tables (all token sizes and call counts [E] until F29 measures them)
Calculator in the repo: `intraday_patches/design_v3/desk_cost.py` (re-run it with F29's real median tokens per seat).

**4.8a LEAN-MON - the Monday 23 Nov subset**

| Seat | Model | Calls / day | $ / day | Bucket |
|---|---|---|---|---|
| R1 filings reader (~1,200 items, 8 per call) | H | 150 | 0.20 | READ |
| R2 wires / blogs reader (~1,500) | H | 190 | 0.26 | READ |
| R3 TV reader (2 channels, 1 call a minute) | H | 510 | 0.19 | READ |
| R4 policy reader (~300) | H | 40 | 0.05 | READ |
| 38 trader reads (Haiku part) | H | 10 | 0.005 | READ |
| 35 CONNECTIONS 19:45 / 07:15 / 09:05 | O | 3 | 0.44 | MEET |
| 36 DEVIL at the 3 meetings | S | 3 | 0.06 | MEET |
| HEAD briefs 19:45 / 07:15 / 09:08 | O | 3 | 0.50 | MEET |
| HEAD 15:45 scorecard | O | 1 | 0.10 | MEET |
| HEAD live looks (8 shared + 2 trigger, 4.3a) | O | 10 | 0.74 | LIVE |
| 36 DEVIL on BUY NOW candidates (up to 4) | S | 4 | 0.06 | LIVE |
| 15 second read / news confirm (weight >= 4) | S | 15 | 0.19 | LIVE |
| 35 CONNECTIONS Sonnet re-check on a world shock | S | 2 | 0.05 | SEATS |
| Global macro + FLOWS + EM rotation (one call) | S | 5 | 0.10 | SEATS |
| Sector seats x3 (19:45, 07:15 + events) | S | 12 | 0.22 | SEATS |
| 39 risk notes (when holding) | S | 6 | 0.07 | SEATS |
| 36 DEVIL 22:45 / 15:45 if a theme moved | S | 2 | 0.04 | SEATS |
| Cache writes (Opus 1 h + 5 min, Sonnet, Haiku) | - | - | 0.55 | MEET / LIVE / SEATS |
| **TOTAL** | | **~970** | **~$3.84** (Opus 2.18 · Sonnet 0.94 · Haiku 0.72) | + ASK $0.30 = **$4.14** |

Compared with the earlier draft ($4.86): sector seats moved from hourly to meetings + events, the derivatives seat (31) moves
to week 1 (it was not on the Monday list), Devil is costed for meetings AND candidates (7-9 calls, not 6), trader reads and
Connections' Sonnet re-checks are added. Derivatives data still shows on the pages (code).

**4.8b LEAN-W1 - the full week-1 roster (benches share one call; seats speak only on change)**

| Seat / bench | Model | Calls / day | $ / day | Bucket |
|---|---|---|---|---|
| Readers R1-R4 + trader reads (as 4.8a) | H | 900 | 0.70 | READ |
| R5 world reader (~800) | H | 100 | 0.14 | READ |
| R6 story matcher + second read | H | 200 | 0.08 | READ |
| Protected MEET + LIVE rows (as 4.8a, incl. their cache writes) | O / S | 39 | 2.49 | MEET / LIVE |
| 35 CONNECTIONS Sonnet re-check | S | 2 | 0.05 | SEATS |
| World bench 1-5 (19:45, 22:45 only if changed, 07:15 + shocks) | S | 5 | 0.19 | SEATS |
| Commodities 6-7 (one call, meetings) | S | 2 | 0.04 | SEATS |
| Money 9-10 (once after FII data lands, 07:15) | S | 3 | 0.07 | SEATS |
| Policy 11-13 (each weight >= 3 item) | S | 5 | 0.09 | SEATS |
| Company 16-17 (results, deals; events) | S | 6 | 0.10 | SEATS |
| Sector bench: 9 seats in 3 calls x 2 meetings | S | 6 | 0.22 | SEATS |
| Sector seat on events (R49 / F27) | S | 6 | 0.11 | SEATS |
| 31 derivatives (hourly in session + 1) | S | 7 | 0.14 | SEATS |
| 37 history (on demand) | S | 2 | 0.03 | SEATS |
| 39 risk notes + 36 DEVIL theme re-checks | S | 8 | 0.11 | SEATS |
| Sonnet / Haiku cache writes | - | - | 0.16 | SEATS |
| **TOTAL** | | **~1,290** | **~$4.72** (Opus 2.18 · Sonnet 1.62 · Haiku 0.93) | + ASK $0.30 = **$5.02** |

**Plain statement:** the large team fits $5 on Monday's subset (with ~$0.86 headroom). The full week-1 roster is AT the cap, not
under it: at $5 the SEATS sub-cap trims it to meetings + events, or he says yes to about $6. Either way it is NOT PROVEN until
F29 measures real tokens; Opus thinking and cache expiry could push every row up (Honest limits).
The head-of-desk's 40-seat lean estimate ($4.3-5.5) and the intel lead's ($5-6) agree with this: both reach or pass the cap.
**WIDE middle option (~$7.3, his yes):** head 16 live calls, sector seats every 30 min, a separate FLOWS seat, Sonnet confirm on
weight-3 items.

### 4.9 FULL cost table (needs his yes)

| Seat | Model | Calls / day | $ / day |
|---|---|---|---|
| Readers (1.5x items, 4 TV channels) + story matcher | H | ~2,075 | 1.53 |
| News confirm (weight >= 3) | S | 80 | 1.04 |
| World / macro (hourly + night) | S | 24 | 0.55 |
| FLOWS | S | 12 | 0.28 |
| Sector seats (6 costed; 9 in the seat table) every 15 min + events | S | 168 | 3.70 |
| Derivatives (every 15 min) | S | 28 | 0.70 |
| Results | S | 20 | 0.38 |
| Policy | S | 20 | 0.38 |
| Who gains (beneficiary) | S | 25 | 0.50 |
| DEVIL'S ADVOCATE | S | 20 | 0.38 |
| Risk | S | 20 | 0.24 |
| CONNECTIONS | O | 14 | 2.04 |
| HEAD briefs | O | 4 | 0.74 |
| HEAD every 5 min + events | O | 75 | 6.60 |
| HEAD scorecard | O | 1 | 0.13 |
| Cache writes | - | - | 1.05 |
| **TOTAL** | | | **~$20 a day ≈ $420 a month** |

In FULL a third of the money is the head every 5 minutes. FULL comes from the earlier panel calculator (same prices and token
guesses); the LEAN tables come from `intraday_patches/design_v3/desk_cost.py`. Change its guesses once F29 has real token
counts. Prices used: Opus 5.5 $4 / $20 per M (cache read $0.20); Sonnet 5.5 $2 / $10 ($0.10); Haiku 5.5 $0.10 / $0.50 under
100K-token prompts (cache read [G]); Batch API half price.

---

## 5. ARCHITECTURE ON THE REAL SERVER

### 5.1 Process model
- **One long-running service, `gir-desk`** (systemd, Restart=always, RestartSec=5). Inside: one asyncio scheduler, every seat a
  task, one shared AsyncAnthropic client. Not one cron job per seat (each start reloads the SDK and data, and loses state).
- **Separate from the engine.** Engine 0.3 (gates, rings, plan cards) keeps its own loop. Desk and engine talk only through the
  DESK BOARD. On Friday the OLD desk stalled 09:22-09:32:50 inside its own AI calls and the page went STALE [F, STATUS 10:34].
  That must never happen to the gates.
- Fixed-time briefs are slots in the same scheduler, Asia/Kolkata, J3 calendar (no Tue 24). J12 (clock) is NOT STARTED.
- Priority: nice 10, CPUQuota ~100% (one core). Engine, recorders, dash and SSE come first. No replays, Playwright or studies
  09:00-15:35.
- Never two runs of the same seat at once: if still running, skip and log "skipped - still running".
- Old system's deskteam.py (six Sonnet desks every 3 min) and analyst.py (Fable 5.2, $8 / $40 per M) OFF on Monday (J6 / J11).
  Their prompts may be reused as starting text.

### 5.2 DESK BOARD store
- SQLite in WAL mode, `v2/data/deskboard.db`, local disk, **one writer (gir-desk)**. Engine, SSE server and pages open it
  read-only (they need write access to the folder for the WAL files).
- A few hundred to a few thousand rows a day. The "no SQL in market hours" rule was for the tick path; the board is not on it.
- Append-only tables: `cards` (id, ts, seat, kind, strength, snapshot_id, payload_json, evidence_ids), `decisions` (head ideas,
  BUY NOW, manage, STANDS / CHANGED / CANCELLED history), `rings` (ledger, so a restart never re-rings), `ai_calls` (F29 log).
- A JSONL mirror per day for replay and audit.
- Pages never read the board directly: the SSE server tails it by id and pushes desk.view / desk.decision / desk.card events into
  the ONE store.
- The EVENT_MEMORY Postgres + pgvector store is later, not Monday.
- `seats.yaml`: one row per seat (watches, cadence, tier, call cap, $ cap, on / off). Seats switch on / off outside market hours only.

### 5.3 Snapshot builder (`v2/analyst/snapshot.py`)
- Pure code, built once a minute and on an event, shared by every seat. Seats never read feeds themselves.
- Reads: minute store, seclive / R49, December chain store, optquote with per-leg q_ts, B8 cards, I2 TV lines, I1 filings, I5
  regulators, C1-C5, trader reads, positions, lock room, and the board summary.
- Every input carries its age (source time and value still changing). Stale inputs are listed by name ("what I am not seeing"),
  never quietly used.
- Board summary (code, no AI, ~2.5k tokens): one line per sector, ideas grouped by share with seats agreeing / disagreeing,
  conflicts flagged, what is new since the reader's last look, seat weights.
- Each seat gets its slice (derivatives gets OI and chains, not news). Kept, compressed, per head look, so any decision replays
  exactly. Build time [G] well under 1 s; test on the 20 Nov frames before Sunday 16:00.

### 5.4 Rate limits
- **Anthropic: one gate in front of every call (this is J11):** budget check before the call (estimated tokens x price vs
  per-call, per-hour and per-day counters on disk); semaphore ~4 in flight [G]; priority queue (head event look and risk check on
  a BUY first -> head scheduled looks -> seat events -> seat schedules -> Haiku bulk last). Under backlog low-weight items are
  marked UNREAD and logged. On 429: wait for retry-after, drop one tier, then rules only.
- **Kite: seats NEVER call Kite.** All Kite traffic stays with the recorders (4 keys, the 09:15 sweep at 1 call per 1.1 s).
  "Ask a seat" reads stores only. J14 is NOT STARTED.
- **NSE / BSE:** the desk adds no calls. New sources are polite pollers in code (stop on 403 / 429, never evade).

### 5.5 Latency (item first published -> phone)
- Measured source delays [F]: NSE filings 11 s median (after hours), TV 29 s, BSE 44 s, wires 129 s, PIB 139 s, Parliament
  449 s, world prices 600-1,200 s.
- Guesses to confirm Monday: Haiku 1-3 s, Sonnet 5-20 s, Opus 15-45 s (B9 allows 45 s), gates < 1 s, Telegram ~5 s after the page.
- Targets, measured daily at 15:45: filing or TV line -> head decision on the page median <= 90 s, p90 <= 150 s; wires and
  regulators: source delay + 60 s (under 60 s total needs a paid wire - his yes).

### 5.6 Failures: AI never blocks the gates
- The engine reads the head's latest decision with its age. If the last look is older than ~12 min, the footer says
  "AI lite" / "AI off" and the engine runs rules only (the B9 rules-only path exists and is tested).
- Time limits: Haiku ~5 s, Sonnet ~25 s, Opus ~45 s. Ladder: one retry -> one tier down -> rules. After 3 failures in a row the AI
  pauses 5 min (B9).
- Budget at the cap: no call, rules only, one message to the trader.
- The AI names shares, sides, reasons and evidence ids only. Code does contract, lots, stop, target and gates.

### 5.7 Restart
- No state only in memory. On start gir-desk rebuilds from the board: thesis book, each seat's last card id, today's spend from
  ai_calls, the ring ledger.
- Each slot has a key (seat + slot time): a restart never runs a slot twice and never re-rings a BUY NOW.
- No planned restarts 09:00-15:35. A crash loop (5 in 10 min) stops the service and raises a P2 alarm on Health; the engine
  carries on rules-only. J13 (restart proof) must include gir-desk.

### 5.8 Logging (for scoring)
- Every AI call (F29): seat, model, effort, prompt hash, snapshot_id, evidence ids, output JSON, tokens in / out / cache read /
  cache write, cost, latency, validator result, fallback reason, request id.
- Every card and decision records shares, side, time named and price at naming (from the snapshot), so C5 can score each seat
  and source.
- Load watch Monday (the condition on the 4-CPU yes, section 1): pidstat every 60 s, load, /login time, gir-desk CPU and
  snapshot.py build time; baseline = Fri 20 Nov F5 (load 6-15, dashserve and engine2 at 100%, /login 3.0-3.6 s once). If load
  stays above 4 for 10+ min or /login goes over 1 s, gir-desk first drops to readers + head (seats paused), then the 8-core
  resize goes to him with the numbers. (The 4 / 10 min / 1 s limits are a policy, not a measured number.)

---

## 6. WEB PAGE AND MOBILE CHANGES

**Yes, both need changes.** The idea: a large team behind one calm voice. The main views (Desk and phone) show only what the head
analyst decided. The size of the team shows on one page, the DESK ROOM, with proof of what the desk read. That answers "you are
still very confined".

### 6.1 What stays
- The shell: market strip, P&L strip, tab bar, footer, tokens, 1366 rule, 390 phone, masked P&L in screenshots, 0 console errors.
- CE = green chip (--up), PE = red chip (--down), equal width, side by side. BUY NOW = the --go amber fill, the only amber fill
  on a screen (it takes GO NOW's slot). Connections, chains and shocks use --info blue, never amber.
- Background pages stay as evidence: Sectors (F2), drill-down, Rotation (F3), News (F4), Share (F7), Chain (F9), Futures & OI (F10).
- No news feed on the Desk or the phone. News reaches the main view only as a WHY line inside an analyst card.

### 6.2 Conflicts settled
- **Confidence grade:** none on the card. It shows the source record ("TV desk 3 of 7, too early") and a grey NOT PROVEN chip
  until n >= 30 and the lower bound beats the base rate.
- **What rings (E14 / SHELL R10 kept, section 1a):** BUY NOW (GO NOW's chime), an ARMED idea of the head on a sector call
  (GET READY's one soft tick, once, mutable with M), manage notes / exits on his own trades and the existing P1 alarms. Themes,
  seat cards and Ask answers never ring. Whether to silence the soft tick is his choice (section 7, item 5).
- **AI cap shown:** $5 (J11), not $20.
- **Desk Room centre:** latest card per seat by default (no endless stream); a seat click or a "stream" toggle shows history.

### 6.3 Web screens
**DESK (F1).** Left and centre stay. Changes:
- Under each open position: a MANAGE line ("HOLD - thesis intact: banks breadth positive [Sector-Fin 10:31]", "BOOK HALF",
  "EXIT - thesis broken: <reason>", "15:10 exit in 22 min").
- Members table: a grey WHY NOT line on any share moving with no call ("price-only move", "EXTREME RSI - no chase").
- Right column, top to bottom:
  a. **DESK VIEW strip**, 2 lines: the head's lean and main theme, "looked 10:31 · next look". If older than 2 cadences [G] it
     turns grey STALE, and no BUY NOW can show (the card reads WAIT).
  b. **BUY NOW card** (hero, one at a time): side chip, share, December contract, valid till; ENTER zone; STOP (= wrong-if) and
     premium backstop; TARGET; R:R after costs; LOTS (1% risk), trade n of 3; WHY (max 3 lines, each with seat chip, source chip,
     age); **FROM: seats / benches**; **AGAINST (Devil): 1 line**; CANCEL IF; **CONNECTION: 1 blue line** that opens the chain
     ("AI-IPO -> FII -> banks, 1 episode, NOT PROVEN"); "3 for · 1 against"; risk stamp APPROVED / WAIT. Keys unchanged (Space,
     S, W). No buy key. Idle: "Nothing to buy now · 2 ideas armed · next look hh:mm".
  c. **TODAY'S IDEAS** replaces PREDICTED TODAY: CE and PE halves; each row with contract, ENTER only if, distance to trigger,
     state ARMED / FIRED / STANDS / CHANGED / CANCELLED with reason. Silent.
  d. WHY NOT fold (closed): top 5 movers the desk did not call.
  e. Alert tray unchanged. The news line at the bottom is removed.

**MORNING (Shift F1) -> EVENING BRIEF and MORNING** (default page 19:45-09:15).
- Centre: brief headline (2-3 lines) and "what changed since 19:45" as a diff at 22:45 / 07:15 / 09:08. Ideas: at most 5 per side,
  CE and PE columns, each with WHY + sources, AGAINST, ENTER if, CANCEL if, stop / target / lots, version history.
- The C1 price table moves into a closed fold "candidates the desk looked at" - price lists before the open are mostly no better
  than random, so they must not look like the answer.
- Right: **THEMES / CONNECTIONS lane** (overnight world -> India, winners and losers side by side = the positive-thinking rule);
  "what would change the view" (met / not met); a FLOWS box (FII / DII dated, NSDL sector flows, Korea / Taiwan flows, ETF units,
  rupee - as feeds arrive); a COVERAGE line from code ("desk read overnight: n filings · n news · n TV minutes · n world markets").

**DESK ROOM (F8, replaces Analyst & Notes).** Where the size of the team shows.
- Left: **SEAT ROSTER**, grouped by bench. Each row: status dot (running / quiet / paused by budget / feed stale, with reason),
  last card age, cards today, cards that reached the head / became a call, $ today, 20-day record ("too early" under 30). Must
  scale to 40+ seats with no layout change.
- Centre: **DESK BOARD** - latest card per seat: claim, shares with CE / PE chips, sources with ages, NEW / REPEAT / DENIAL,
  verified or not. Filters: bench, seat, sector, symbol, kind, CE / PE, my held; strength 3+ by default. Head marks "adopted ->
  idea #" or "not adopted: reason". Tabs for meeting minutes 19:45 / 22:45 / 07:15 / 09:05 / 15:45. Thesis book and archive kept.
- Right: **THEMES** (chain cards: node -> node -> F&O names; each link SEEN / EXPECTED / CONFIRMED BY PRICE / BROKEN; episode count;
  adopted or not) and **OBJECTIONS** (answered / unanswered per idea). ASK THE DESK drawer. COVERAGE MAP: grid of everything
  watched, each cell with last-seen age, grey if stale - the visible proof "the team looked at everything".

**Other pages (small additions):**
- P15 World drivers (Shift F2): **design now** (was "not designed"). US / AI basket, Asia with Korea / Taiwan flows, Europe /
  Middle East, EM rotation; the world seats' latest cards on top.
- P5 / F3 Rotation: becomes the flows page (FII / DII, FII index positions, NSDL sector flows, rotation map) + "cause from the desk".
- F4 News: THEME / FLOW filter (the lines B8 drops) and a "seat verdict / used in idea #" column.
- F7 Share page: "desk notes on this share". F6 Positions: manage notes. Sectors / drill-down: WHY NOT + desk-note chip.
- Health (Shift F9): one row per seat (alive, last card, silent reason, calls, $) and per new source (KRX, TWSE, NSDL, ETF CSVs,
  tech feeds, CDS) with the silence alarm; the ladder state.
- Scorecard (Shift F8): SEATS and SOURCES tabs (precision, earliness, wrong side, lift, cost per useful call; TRADER READ included).
- Footer: "AI $x of $5 · Opus / Sonnet / Haiku · desk FULL / LEAN / EVENTS ONLY · head looked hh:mm".
- Settings: budget ladder and seat on / off (outside market hours). Replay (Shift F10) replays the Desk Room too.

**ASK THE DESK / TELL THE DESK** (laptop "/" line, drawer on F1 / F8, phone DESK tab)
- Seat selector (default: head routes it). Cost shown before sending ("about 2 cents · $0.40 left in reserve"). Answer only from
  stored facts with evidence ids, labelled "a view, not a call". Saved to the board.
- TELL THE DESK: he types his read; stored as TRADER READ, sent to the right seat, scored like any source.
- An answer never rings and never becomes a buy by itself.

### 6.4 Phone (/m, 390 x 844)
Still a separate, small product: no board, no news feed.
- **NOW** - in a trade: unchanged + the MANAGE line. Flat: a BRIEF CARD readable in 30 s (headline, one "DESK VIEW" line, at most
  2-3 THEME chips that open a read-only chain card with CE / PE names, one row per idea); "what changed" first from 07:15 / 09:08.
- **CALL / BUY** - the BUY NOW card read-only, same fields as the laptop; WHY 2 lines + "more"; FROM seats; AGAINST. Buttons:
  Kite deep link (he places the order), TAKEN (compact plan card), SKIP with one word.
- **ALERTS** - unchanged; holds the 19:45 / 07:15 / 09:08 notes and the 15:45 scorecard. Theme state changes are listed silently.
- **His choice (not Monday):** a DESK tab (desk view, 1-2 theme cards, ask a seat with preset questions and dictation), and folding
  RISK into NOW. Also his choice: a "top 3 stories" list.

**What rings on the phone**
- Rings P2, one chime: BUY NOW (max 4 a day in code; full lock-screen text "BUY NOW · SBIN Dec 1000 CE · prem <= X till 10:42 ·
  stop SBIN Y · 2 lots · why: FII buying banks"); MANAGE on his taken trades.
- Rings P1 (unchanged): stop near / hit, NO STOP, 15:00-15:10 not flat, loss lock, stale data with a position, GIR down, Kite key down.
- Silent push: the brief and the 22:45 / 07:15 / 09:08 updates only if something changed.
- Page only (E14 / R10): an ARMED idea on a sector call gives one soft tick on the laptop page; on the phone it is a silent push.
- In-app only: other idea changes on shares he does not hold, seat cards, themes, WHY NOT, ask answers, news.
- **Open decision for him:** "ring on basket / policy shock" (the ANGELONE case; he asked for an alarm on 18 Nov). Default silent blue.

**Telegram:** decisions bot = BUY NOW, manage, exits, the brief per meeting with a "Themes" section (max 3), 15:45 scorecard
summary. A theme never rings. System bot adds "seat silent" only for critical seats (filings, flows, head).

### 6.5 Built first for Monday (in order; each degrades honestly)
1. Desk F1: BUY NOW card fed by the head (reuse the GO NOW component), DESK VIEW strip + STALE rule, TODAY'S IDEAS, MANAGE line,
   FROM / AGAINST / CONNECTION lines, remove the news line.
2. Morning: EVENING BRIEF board (CE / PE columns, versions, themes lane); C1 table into the fold. Sunday 19:45 is the first real brief.
3. Phone: brief card on NOW, CALL with FROM / AGAINST / NOT PROVEN, BUY NOW and MANAGE push; Telegram the same. Seats can never ring.
4. Desk Room v0 (F8): read-only roster with honest status (most seats "not running" Monday), latest card per seat, themes as a
   plain list.
5. Footer AI $ of $5 and desk mode.
6. Checks before 08:30: 0 console errors on all 23 pages; no sideways scroll at 1366 and 390; one amber fill per screen; masked
   P&L; a 20 Nov replay through the new pages, scored.
- If snapshot.py / brain.py / brief.py are not live, items 1-3 show the existing engine output under the old labels with "head
  analyst not running" in grey. **Do not dress engine cards up as analyst calls.**

---

## 7. BUILD ORDER (honest)

**State today [F, STATUS]:** J11 budget, J12 clock, J13 restart proof, J14 rate limits, J16 freeze (Sun 16:00), J6 old senders:
all NOT STARTED. snapshot.py, brain.py, brief.py, the desk pages and the replay harness have no status row. 15+ Monday items are
open. So Monday is a lean desk.

### By Mon 23 Nov 08:30 - minimum viable desk (expiry day; Tue 24 holiday)
Prerequisites (nothing goes live without them):
1. J11: one hard $5 gate in code before every call + console spend limit. J6: old AI desks OFF. J12 clock.
2. `gir-desk` service, DESK BOARD (SQLite WAL), `seats.yaml`, card validator, ai_calls log, ring ledger, restart rebuild.
3. snapshot.py + board summary.

Seats live, with a CUT LINE (about 1.5 days remain before the Sun 16:00 freeze, and STATUS still has A1, A2, A3, A6, A7, D4,
E3, F1, F4, J4, J7, J8, J13 and J14 open besides J6, J11, J12):
- **MINIMUM (Monday does not get a desk without all of these):** HEAD ANALYST (Opus: briefs Sun 19:45, Mon 07:15, 09:08; live
  per 4.3a; manage notes) + **FLOWS** + **CONNECTIONS** + **DEVIL'S ADVOCATE** (the three seats that would have caught 20 Nov,
  prompt-only on existing data) + **R1 filings reader** + its **second read (seat 15)**, which E12.4 needs before any
  filing-led BUY NOW. Code risk gates (existing) are always on.
- **THEN, in this order, as time allows:** (1) R3 TV + R2 wires readers (their news ideas also go through seat 15); (2) 3 sector
  seats (event-led); (3) Global macro (world / EM rotation folded into FLOWS until then); (4) R4 policy reader; (5) code seats:
  tape, technicals / regimes, calendar, scorekeeper logging; (6) trader-reads Haiku part; (7) Sonnet risk notes.
- **If the weekend runs short, drop from the bottom up:** Sonnet risk notes -> trader-reads Haiku (his reads are still stored
  and scored by code) -> code seats not yet built (the engine's existing tape / regime output stays on the page) -> policy
  reader -> Global macro -> sector seats -> TV / wires readers. Never drop a MINIMUM seat to save a lower one; if a MINIMUM seat
  is not ready, the analyst runs on the page only, with no ring, and says which seat is missing.
- With only the MINIMUM, BUY NOW can come only from filings, flows or a confirmed theme; news / TV-led BUY NOW are off (no reader).
- Web cut line, same rule: MINIMUM = 6.5 items 1 (BUY NOW card), 3 (phone + Telegram), 5 (footer) and 6 (checks); then 2
  (Evening brief board - until then the Sunday brief shows in the existing Morning page); Desk Room v0 (item 4) drops first.

Proof:
- Replay 18 / 19 / 20 Nov with point-in-time data (knowledge pack as of the evening before; EVENT_MEMORY G excluded from the
  19 -> 20 run). Steps: stub models (free) -> Haiku layer (~$1-3, Batch halves it) -> Sonnet + Opus on stored cards (~$15 for three
  days [G]; **one-off test spend above the daily rule, needs his yes**) -> 20 Nov head run 2-3 times for stability.
- Pass bar: precision above base rate; named before the move; few wrong-side picks; zero unsourced numbers; cost extrapolates to
  <= $5; latency inside timeouts. Report whether Connections names banks / IT CE by 07:15 / 09:08 on 20 Nov - either way.
- **His Monday order (ANALYST.md 4) is that BUY NOW goes to him, labelled NOT PROVEN. The desk asks him, it does not decide:**
  the desk recommends that BUY NOW rings on Monday only if the replay has run and been scored by Sun 16:00, and the Sonnet +
  Opus layer of that replay needs the one-off ~$15 he has not yet approved. So the chain is: **no yes to the $15 -> no full
  replay -> by the desk's recommendation, no Monday ring** (the analyst would show on the page only, the old system staying the
  safety net per his A / B / C choice). He may instead keep his order as given: BUY NOW rings Monday, NOT PROVEN, with only the
  free stub + Haiku replay layers run. Both options are in item 5 below; until he answers, his order stands.

Web / phone: section 6.5 items 1-6.

### Week 1 (Wed 25 - Mon 30), one bench a day, each after a day in shadow with its cards scored (the interim rule that replaces E13's 20-30 day replay, section 1a; a new bench counts only as support for its first 5 live days)
- Theme path G1 (B8 dropped lines -> Connections / Flows), feeds G2 NSDL, G3 KRX / TWSE, G4 tech / AI list + world reader,
  G5 ETF units; first check each is reachable from the server.
- World seats 1-5 split out; commodities 6-7; 9 sector seats; policy 11-13; results 16; deals 17; derivatives 31; history 37.
- Seat weights from the scorecard; Kite key failover (F2). At $5 the week-1 roster runs inside the SEATS sub-cap (4.7, 4.8b);
  every seat on every meeting needs about $6 (his yes, after F29 numbers).
- Web: Desk Room full (roster, filters, minutes, themes, objections, coverage map), World drivers P15, Rotation / flows page,
  Health seat and source rows, Scorecard SEATS / SOURCES tabs, Ask / Tell the desk (laptop first), WHY NOT in drill-down, basket-
  shock ring setting. Add G8 to LINK_BOOK as PROPOSED.

### Later (weeks 2-4)
- Broker seat with public notes (G7); social seat (t.me/s); concall reading; seats 8 and 14; story recall cards.
- EVENT_MEMORY Postgres + pgvector; faster regulator / Parliament watchers; FII-in-session proxy (G9) after 20 days of scoring.
- Seats on probation or dropped by the E13 rule.
- His decisions: CDS / MCX, paid wire, FJ Pro, Trendlyne, X, more TV channels, WIDE or FULL budget, fast mode, the phone DESK tab.
- The 8-core resize only if Monday's measured market-hours load needs it.

### What each owner must confirm (he asked the desk to confirm)
1. Server builder: KRX / TWSE / NSDL / ETF CSVs reachable from the server, and when each publishes (times are guesses).
2. Engine builder: B8-dropped items can be routed as THEME without touching share-news votes.
3. Cost owner: the Monday seats fit the J11 single $5 cap with the sub-budgets (4.7), measured on the replay and on Monday's
   F29 log; the budget day (15:40-15:40) is the one J11 uses; `desk_cost.py` re-run with real tokens by Wed 25.
3a. Server builder: J6 silences the old timers and old AI desks before Mon 09:00, and Monday's load watch (5.8) is reported -
   the 4-CPU yes depends on both.
4. Replay owner: 20 Nov replayed with the new sources, scored by source, before anything is labelled more than NOT PROVEN.
5. The trader:
   - **The Monday ring.** (a) Is the one-off ~$15 replay spend OK? (b) If not: does BUY NOW still ring on Monday, NOT PROVEN,
     as he ordered (only the free replay layers run), or page only until the replay is done? No yes to the $15 means no full
     replay before Monday; the desk will not drop his order without his answer.
   - Keep the GET READY soft tick on an ARMED idea (E14 / R10, default) or silence it.
   - Week 1 at $5 with seats trimmed, or about $6 for the full roster (after F29 numbers); Ask reserve size ($0.30 default).
   - CDS / MCX; basket-shock ring; phone DESK tab; the 8-core resize if Monday's load watch fails.

### Honest limits
- One day of evidence. The 20 Nov chain is one episode; knowledge-led picks have been few (0-7 a day, C5). Nothing is PROVEN.
- Cost is not measured. Opus thinking and cache expiry could double the estimates; the J11 gate and the console limit are the fence.
- Free news is late (wires 129 s). World prices are 10-20 min old. BSE answers 403.
- The first 15 minutes Monday: December quotes may lag (yesterday's until ~09:30 on 20 Nov [F]); expect "premium loading" and no
  early BUY NOW.
- Possible leakage in the knowledge files (E1 note). Every call carries NOT PROVEN until the scorecard says otherwise.
