> **Superseded / extended by DESK_TEAM.md (20 Nov evening).** The desk seats (section 1b), the cost (section 3) and the build
> order are now in /home/user/my-first-site/intraday_patches/design_v3/DESK_TEAM.md. Read that first.

# GIR ANALYST - a senior F&O analyst living inside GIR (the new system's brain) - 20 Nov 2026

The trader, 20 Nov 17:45: "I want a complete new system. A senior F&O analyst is inside GIR, monitoring everything, and then telling
me what to buy." And 18:00: "Not to catch all the 2% moves - the edge: the knowledge, the brain should pick the correct F&O shares from
news, sectors, external and internal news, company performance, and predict before."

THIS FILE OVERRIDES the idea that the v2 rule engine is the product. From now on:
- **The ANALYST is the product.** It decides what to tell him and why.
- **The engine, feeds, studies and drill-down are its eyes and its calculator.** They compute every number; they do not decide.
- GIR never places orders. The analyst recommends; he decides and trades in Kite.

## 1. What he gets (the only outputs)
1. **19:45 EVENING BRIEF** (updated 22:45 only if something breaks, 07:15, 09:08): the market-day view, then **at most 5 ideas
   per side**, each as a recommendation:
   `BUY  SBIN Dec 1,000 CE (ATM) · WHY: <2-3 reasons with sources> · AGAINST: <the risk> · ENTER only if <trigger>
   · CANCEL if <condition> · STOP <share level> · TARGET <level> · SIZE <lots for 1% risk> · CONFIDENCE <grade, NOT PROVEN>`
2. **LIVE CALLS (09:15-14:30): "BUY NOW" only when a predicted idea's trigger is met**, or when new knowledge arrives
   (news, filing, TV, broker call, regulator) and the price confirms. **At most 3-4 a day**, ring once.
3. **MANAGE notes for his open trades:** "book half", "move stop", "exit - thesis broken (reason)", "15:10 exit".
4. **"WHY NOT" answers:** when a share is flying and the analyst did not call it, the page says why in one line
   ("price-only move, no reason found", "EXTREME RSI - no chase").
5. **15:45 SCORECARD:** each recommendation right or wrong, how early, the move left, and the result **by source**.
Nothing else rings. Everything the eyes see but the analyst did not pick stays on the background pages (drill-down, WATCH).

## 1b. THE DESK TEAM INSIDE GIR (the trader, 20 Nov 18:30: "a pool of team which sits inside GIR, monitoring the Indian stock
exchange, all F&O shares, sectors and the outside world, everywhere, analysing, then telling me what to buy")
Not one analyst - a live desk of AI specialists that run all day inside GIR on the server, each with a job, a cadence and a model,
reporting to ONE head analyst who alone talks to the trader. Code (the eyes) feeds every specialist the numbers; specialists write
short structured notes into a shared DESK BOARD (append-only); the head analyst reads the board and decides.
| seat | watches | cadence | model | writes |
|---|---|---|---|---|
| **Global / macro strategist** | US / Asia / Europe markets and futures, DXY, US10y, crude, metals (copper / aluminium / gold), Fed / ECB / China, GIFT | 19:45, 22:45, 07:15, 09:05, then hourly + on a >1% shock | Sonnet | market-day lean, which Indian sectors each global move helps / hurts, with the link book |
| **News & filings desk** | NSE / BSE filings, wires, publishers, regulators, Parliament, PIB, courts (WEB_SOURCES 5) | every item as it lands | Haiku reads, Sonnet confirms weight >= 3 | fact cards: NEW / REPEAT / DENIAL, shares + side, verified or not |
| **TV desk** | CNBC-TV18, ET Now, CNBC Awaaz, Sansad TV (speech-to-text) | live chunks; 07:00-09:15 the morning shows in full | Haiku | who said what on which share / sector, broker / TV calls with the voice's record |
| **Sector analysts (3 seats: financials; industrials-metals-energy-infra; consumer-IT-pharma-auto)** | whole-sector moves (R49), breadth, leaders / laggards, sector news, results calendar | every 15 min + on a sector event | Sonnet | sector view (up / down / mixed, why), the 2-3 best F&O shares each way in the sector with reasons |
| **Derivatives analyst** | futures OI build-up (all months), option chains (December), PCR, IV / IV rank, max pain, rollover, ban / MWPL, expiry effects | every 15 min | Sonnet | where fresh money is (long / short build-up), IV traps, expiry pinning, which strikes are tradable |
| **Risk manager** | his positions, lock room, trades n of 3, sector clustering, stale data, EXTREME / oversold rules | on every candidate BUY + every 5 min when he holds a trade | code + Sonnet | approve / WAIT / REJECT with the reason; manage notes (book half, exit) |
| **HEAD ANALYST (the senior F&O analyst)** | the DESK BOARD + the snapshot + the thesis book + his reads + the scorecard | every 5 min + at once on a high-weight note | **Opus 5.5** | the evening brief, BUY NOW (<= 3-4 a day), manage notes, the desk view - the ONLY voice to the trader |
Every seat's notes are scored at 15:45 like everything else (was it right, early, which source), so the head analyst learns whose
word to trust. The trader can ask any seat a question from the Desk ("ask the derivatives analyst about BANKNIFTY").

### Cost of the full desk (honest)
- Head analyst on Opus every 5 minutes: about $2-3 a day.
- Six Sonnet seats every 15 minutes + events: about $2.5-4 a day.
- Haiku reading news / TV: about $0.5-1 a day.
- **The full desk is about $5-8 a day**, above his $3-5 rule. Paid AI above $5 needs his yes.
- **A lean desk fits $5:** the head analyst every 10 minutes, the sector seats every 30 minutes, and macro / derivatives at the
  fixed times plus on events.
- The budget ladder (section 3) applies either way.

## 2. How it thinks (one agent, every few minutes, with memory)
- **Model:** Opus 5.5 for the analyst. Haiku only for reading and sorting raw news / TV chunks into facts.
- **Every 5 minutes in market hours**, and **at once on a high-weight event** (filing, regulator, broker call, TV call on an F&O
  share, a sector shock), it gets one compact **DESK SNAPSHOT** built by code. All numbers come from code, never typed by the AI:
  - market: NIFTY / BANKNIFTY level, % and VWAP side, VIX, breadth, FII / DII so far, GIFT / US futures / DXY / US10y / crude / copper / gold;
  - sectors: the whole-sector % (R49), breadth and money flow, with the leaders and laggards;
  - the movers that matter: top 15 each way with RVOL, OI build-up, VWAP side and RSI zone (EXTREME / oversold);
  - **new knowledge since the last look:** news, filings, TV lines, broker calls, regulator items, each tagged NEW / REPEAT with its
    mapped shares;
  - **its own open ideas** (the thesis book) with their trigger / cancel state;
  - **his open trades and his reads** (TRADER READ), and the risk left today (lock room, trades n of 3).
- **Its standing knowledge** is prompt-cached:
  - LINK_BOOK, SECTOR_LINKS, CHAIN_OF_EVENTS, EVENT_MEMORY, BROKER_CALLS, TRADER_CALLS;
  - the measured rules:
    - EXTREME overbought (81% correct within 20 days; no breakout CE);
    - oversold (86% bounce; CE only on the turn);
    - timing (two-thirds of moves start at 09:15; half done in ~20 min);
    - the 09:45 CE edge;
    - expiry and December rules;
  - the source hit rates from the scorecard. Sources with a poor record carry less weight.
- **It answers in a fixed JSON form** (validated by code): new ideas, updated ideas (STANDS / CHANGED / CANCELLED with reason), BUY
  NOW calls, manage notes, and one paragraph "desk view". Code then attaches the contract (December ATM / 1 ITM from the live
  chain), the lots, the stop and target levels, and runs the hard gates: ban, stale quote, spread, R:R, loss lock, 3 trades a day,
  never two in one sector. A gate failure turns BUY NOW into "WAIT: <reason>".
- **Thesis book:** every idea has an id, the time first named, its reasons and sources, and its state history. The analyst must
  say what changed its mind. No flip-flopping without a reason.

## 3. Cost (his $3-5 a day)
- Opus every 5 minutes: ~75 looks. With the standing knowledge cached, about 3-5k fresh tokens in and ~800 out each, that is
  roughly 2-4 cents a look, **about $2-3 a day**. Add event looks (~20), the evening and morning briefs (~$0.5) and the Haiku news
  reading (~$0.5-1).
- **Hard cap $5,** with a ladder: past $4.25 the 5-minute look becomes 10-minute; at $5 only event looks run.

## 4. Proof before he trusts it (same yardstick for everything: precision + earliness by source)
- **Replay** 18, 19 and 20 Nov with the recorded news / TV / filings (the reader has run since 19 Nov evening; TV since 19 Nov) and
  the recorded prices: the analyst sees only what existed at each minute. Score its ideas:
  - right side (>= 1% / >= 2%, by the close and the next close) vs the day's base rate of random F&O shares;
  - named before the move, and the move left;
  - wrong-side rate;
  - by source;
  - the top-5 hit rate.
- **Monday live:** it runs and its EVENING BRIEF and BUY NOW calls go to him (his order), each labelled NOT PROVEN with its
  source. The old system's alerts stay as the safety net per his A / B / C choice. Scored at 15:45 every day.

## 5. What the server builds, in order (weekend)
1. `v2/analyst/snapshot.py`: the DESK SNAPSHOT from the existing feeds, stores, engine features, news / TV / filings readers and
   the prediction store (C1-C5). Pure code, tested.
2. `v2/analyst/brain.py`: the Opus loop (5-minute + event), the cached knowledge pack, the JSON contract, the validators, the thesis
   book store (append-only), the budget ladder.
3. `v2/analyst/brief.py`: the 19:45 / 22:45 / 07:15 / 09:08 brief, which reuses C1's candidate table as INPUT, not as the answer.
4. Pages: an **ANALYST** panel on the Desk (the desk view + ideas + BUY NOW + manage notes), the Morning brief page, the phone
   card, and Telegram for BUY NOW / manage only.
5. Replay harness for 18 / 19 / 20 Nov and the precision scorecard.
6. Sunday 19:45: the first real evening brief for Monday.
The v2 engine work already done (B1-B9, C1-C5, quote freshness, one ring per idea, gates, expiry mode) is reused as the analyst's
eyes and gates. Nothing is thrown away; the brain sits on top of it.
