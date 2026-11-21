# NEWS READING PLAN - tiered models, caching, batch, weekend / holiday schedule (19 Nov 2026)
Merged from three reviews: AI cost engineer, news-NLP engineer, senior F&O trader. Prices checked against the Claude API price
list (cached 2026-11-03): Haiku 5.5 $0.10 / $0.50 per M tokens (prompt <= 100K; above that $0.50 / $2.50), Sonnet 5.5 $2 / $10,
Opus 5.5 $4 / $20, Batch API 50% off. Fits under E13 (small / mid / top model, $20 / day hard cap). Weight 1-5 here maps to E13
materiality: weight 1-2 = 0-1, weight 3 = 2, weight 4-5 = 3. Target for news reading: **$3-5 a day, 24/7.**

## A. THE TIERS AND WHAT EACH READS
| Tier | Who | Reads | Settings |
|---|---|---|---|
| 0 | Code (free, < 1 ms) | Every item: fetch, drop junk, link entities, group duplicates, parse XBRL results numbers, fast path | - |
| 1 | Haiku 5.5, effort LOW (set it: default is medium) | Every item that survives tier 0, ONCE per story (~2,500-3,000 on a normal trading day) | JSON schema, max_tokens 400 |
| 1b | Haiku 5.5, effort MEDIUM | Deep read of weight-3 items and full articles that name an F&O stock (~300 a day) | max_tokens 600 |
| 2 | Sonnet 5.5, effort low / medium | Weight 4-5; policy and sector chains; mixed results; TV management tone; tariff / trade text; 3+ F&O names; blind second opinion (B6); every Haiku refusal | max_tokens 1,500; cap 200 calls / day |
| 3 | Opus 5.5 | 19:45 and 07:15 notes (trading days only); GO NOW check (E13: 1 per stock / 5 min, max 25 / day); weekly accuracy labels (Batch) | max_tokens 16K, effort medium |
- **Read deep and fast (tier 2 within seconds, never batched):** filings of F&O names (results, orders > 5% of yearly sales, block
  deals, promoter sale / pledge, QIP, buyback, M&A / demerger, CEO / CFO / auditor exit, SEBI / RBI orders, USFDA warning / OAI,
  rating cuts, ban-list entry MWPL > 95%); denials and clarifications (linked to the story they answer, direction flipped); policy
  (RBI MPC, SEBI F&O rules, GST Council, export / import duties, cabinet / PIB, budget, windfall tax); global (US tariff / USTR on
  India, Fed, war / sanctions, crude > 3%, US futures, GIFT Nifty gap); TV "sources say" exclusives and management interviews;
  scheduled data (auto sales on the 1st, CPI / IIP, GST collections, PMI, bank credit). Live TV analyst buy / sell calls: fast, small weight.
- **Skim (tier 1 tag only):** brokerage target changes (except up / downgrades of index heavyweights), results previews, sector
  features, live-blog repeats, non-F&O stocks, IPOs. ET Prime long reads: one overnight Batch read.
- **Ignore (dropped in code, no model):** market wraps, "stocks to watch" lists, personal finance, MF launches, opinion columns,
  crypto, technical levels on non-F&O stocks, routine filings (newspaper ads, trading-window closure, lost certificates, Reg 74(5)).

## B. FREE FILTERS AND ENTITY LINKING (tier 0)
1. **Alias table per F&O stock:** NSE symbol, BSE code, ISIN, names old and new, brands (Tanishq -> TITAN, Jio -> RELIANCE),
   subsidiaries, promoter group, CEO / CFO, main products. Aho-Corasick + rapidfuzz. Refreshed weekly from filings.
2. **Ambiguous list** (Titan, Trent, Federal, Idea, "Bank of ...", Escorts, Coal; HDFC Bank / Life / AMC; Bajaj Finance / Finserv;
   Bank of Baroda / Bank of India; Reliance Industries / Power; Tata Motors TMPV / TMCV): settled by context words; Haiku only if
   still ambiguous. TV speech-to-text names always pass through this list - the model never guesses.
3. **Filings carry the symbol** - never use AI to find it. Regex drop of routine subjects removes 50-70% of filings.
4. **Story grouping:** normalised headline SimHash + MinHash on the first 300 words (+ optional ONNX bge-small / MiniLM, 20-40 ms).
   Same entities + same event_type within 6 h = one EVENT. First item is read; later ones only raise the source count. Re-read only
   when new numbers, quotes or an official source appear (diff on numbers and quotes). Live blogs: send only the new paragraphs.
   Saves 30-40% of Haiku calls. TV repeating the morning news = repeat.
5. **Source classes:** A (exchange, SEBI, RBI, PIB, ministries, White House / USTR / Fed, Reuters flashes): headline is enough to
   act, full text read after. B (ET incl. Prime, BS, Mint, Moneycontrol, NDTV Profit): full text. C (live blogs, TV talk, "sources
   say"): weight capped at 3 until an A or B source confirms within 30 min.
6. **Fast path (no AI, < 1 s):** a filing for order win / result / pledge / block deal + a size rule (value as % of market cap)
   wakes the engine at once; Haiku's reading follows to confirm. Results: XBRL numbers vs consensus compared in code (standalone vs
   consolidated, QoQ vs YoY, crore vs lakh checked in code); the model reads only commentary, exceptional items, guidance.

## C. CACHING AND BATCH DESIGN
- **Prefix order (frozen all day):** output schema + instructions -> F&O universe, aliases, sectors, exposure map (rebuilt nightly)
  -> [Sonnet / Opus only: link book, chain of events] -> cache breakpoint -> today's event memory, positions, the item. Never edit
  the prefix in the day (any change re-bills everything after it); no timestamps or unsorted JSON before the breakpoint.
- **Haiku gets a lean prefix of 10-20K tokens** plus, uncached, only the link-book / exposure-map lines of the matched entities.
  Haiku prompts stay far under 100K (price x5 above that). Full knowledge files go to Sonnet and Opus only; each model has its own cache.
- **TTL:** market hours 5 min (items every few seconds keep it warm). Night, weekend, holiday: 1 h (writes 2x, about $0.07 / day),
  or group sparse items every 5-10 min. Check `cache_read_input_tokens` daily; target >= 70-80% cache reads (E13).
- **Structured output** (output_config.format), fixed lists only: symbols (from F&O list), sector, index, direction (up / down /
  mixed / none), weight 1-5, novelty (new / repeat / update), event_type, horizon (minutes / day / multi-day), confidence, evidence
  (a short quote). Code checks the quote is really in the text, else the reading is rejected. No temperature on Haiku 5.5.
- **Batch API (50% off, minutes to hours):** nightly knowledge rebuild, ET Prime long reads, end-of-day tagging audit, weekend
  low-weight backlog, replays / back-tests, weekly accuracy labels. **Never** live items, GO NOW or the 19:45 / 07:15 notes.
- **Loop guards:** item hash, never sent twice; model output never re-enters the input queue; calls per minute > 3x normal = pause
  and alert; daily dollar count in code from the token counts of every reply (not estimates).

## D. SCHEDULE (IST; polling RSS / pages is free - only model reads cost money)
| Window | Exchange filings | Class A wires | Class B sites | TV speech-to-text | Models |
|---|---|---|---|---|---|
| Trading day 07:30-16:30 | 3-5 s | 30-60 s | 1 min (live blogs 30-60 s) | ON, both channels 08:00-16:00 | all tiers |
| Trading day 16:30-22:00 | 5-10 s | 1 min | 2-5 min | OFF (ON for a scheduled interview) | all tiers; 19:45 Opus note |
| Night 22:00-07:30 | 60 s | 1-2 min | 10 min | OFF | tiers 1-2; 07:15 Opus note |
| Sat / Sun | 60 s (Sat 11:00-20:00: 5 s for companies with a board meeting) | 2-3 min all day | headlines 20-30 min; full text only if F&O name / policy word | OFF | tiers 1-2; low weight via Batch |
| NSE holiday (weekday) | 60 s | 1-2 min; global markets at full rate; GIFT Nifty = live gap gauge | 20-30 min | OFF | tiers 1-2; 19:45 note only if next day trades |
- US data and Fed stay live every weekday evening / night (18:00, 19:30, 23:30 IST). Friday 15:30-22:00 = normal weekday mode. Sunday 19:00 back to full mode; Sunday 21:00 **Sonnet** weekend digest (all weight 3+)
  feeds Monday's 07:15 Opus note. **No Opus notes on Saturday or Sunday.** Saturday results of big banks: read in full on Saturday.
- Calendar = full mode: Budget (even on Saturday), Muhurat trading, special live sessions, RBI policy days.
- **NEVER SKIPPED, any day:** Haiku reads every item that passes tier 0; class A wires at <= 3 min; denials linked to their story;
  ban list; second opinion on weight 4-5 and negation items. **Escalation alarm** (skips the slow schedule, full weekday mode at
  once, TV auto-ON, trader alerted): a class A hit on war / strike / sanction / tariff / trade deal / RBI / SEBI / GST Council /
  rate / ban / default / crash / results of an F&O stock; 3+ sources on one entity within 15 min; GIFT Nifty or US futures > 1.5%.

## E. COST (Claude only, per day; Deepgram is a separate line)
| Day | Haiku (low + medium) | Sonnet | Opus | Batch | Total | Alarm if above |
|---|---|---|---|---|---|---|
| Normal trading day | ~2,700 x $0.0003 + 300 deep x $0.002 = $1.4 | ~70 calls (incl. 2nd opinion) = $1.3 | 2 notes + ~5 GO NOW = $1.4 | $0.3 | **$4-5** | $6 |
| Heavy news day (Budget, war, results peak) | ~8,000 + 1,000 deep = $4.4 | 200 (capped) = $4 | 2 notes + 25 GO NOW = $3.8 | $0.5 | **$12-13 capped** (uncapped $25-40) | ladder below |
| Saturday / Sunday | ~800 = $0.3 (+ $0.07 1 h cache) | ~10 + Sun digest = $0.3 | none | $0.1-0.3 | **$0.6-1** | $2 |
| NSE holiday | ~1,500 = $0.6 | ~20 = $0.4 | 19:45 note if next day trades = $0.4 | - | **$1.5-2** | $3 |
- Month: ~21 trading days x $4.5 + ~9 weekend days x $0.8 + 1-2 holidays + weekly audit ($4) + heavy-day reserve (~$20) =
  **about $120-135 for Claude.** First 2 weeks expect $5-6 a day until grouping and filters are tuned.
- **Deepgram TV speech-to-text (not Claude):** 2 channels x ~450 min = ~900 min a trading day; at $0.005-0.008 / min (check live
  price before buying) = **$5-7 a trading day, ~$110-145 a month**; ~$0 on weekends and holidays (TV off). Option in G.
- **News-reading ladder (inside the E13 $20 whole-system cap):** $6 -> Telegram to trader + evening report line; $9 -> Sonnet only
  for weight 5 and negation / denial items, others to Haiku medium; $12 -> news reading on Haiku low + code fast path only; $20
  whole system -> E13 ladder (code rules + small model only, one message). Console monthly limit $250 as backstop; alarm at $150
  month-to-date. Runaway alarm: calls / min > 3x normal or one source > 2x its daily item count.

## F. ACCURACY CHECKS - AND HOW THE PLAN CHANGES IF ACCURACY IS LOW
- **Live, free:** evidence-quote check; link-book rule check (e.g. "crude up" must not tag OMCs up); blind Sonnet second opinion on
  weight 4-5 and on every item with not / no / denies / rules out / clarifies - if Haiku and Sonnet disagree on direction, nothing
  wakes; flagged to Opus or the trader. Second opinion adds 2-5 s; clear filings use the fast path.
- **First 2 weeks (shadow):** Sonnet re-reads a random 10% of Haiku items (~$0.3 / day) to measure agreement per event_type.
- **Weekly (Sunday, Batch):** 150 items - 60 random, 50 high weight, 40 that tier 0 DROPPED (to find misses). Opus labels them
  (~$1 / week); the trader checks 20. Free label: did the share / index move the tagged way within 30 and 60 min?
- **Missed-story audit:** every F&O share that moved > 3% with no item behind it; every big next-morning headline never tagged.
- **Targets:** entity precision >= 95%, recall >= 90%; direction >= 85% on weight 4-5; weight within +-1 >= 80%; wake precision
  >= 70%; p95 publish-to-wake < 15 s for class A; zero missed weight-5 stories.
- **If low:** wrong entities -> fix aliases / ambiguous list, never more model. Haiku direction low on an event_type -> that type
  goes to Haiku medium, then Sonnet if still low (cost rises ~$0.5-1 / day per type, logged). Misses in dropped items -> loosen that
  regex. Low wake precision -> require class A / B confirmation or raise the weight bar. Weekend misses -> add the keyword to the
  escalation alarm. Every prompt / model / routing change passes a 20-30 day replay before it ships (E13).

## G. BETTER ALTERNATIVES - CHOSEN OR NOT
| Alternative | Decision | Why |
|---|---|---|
| Group stories + regex + XBRL in code before any model | **Chosen** | Biggest saving (30-70% of calls) and more accurate on numbers |
| Haiku medium for most deep reads, Sonnet only where judgment is needed | **Chosen** | Keeps Sonnet at ~70 calls / day |
| Small ONNX embeddings, rapidfuzz, SimHash on the server | **Chosen** | Free, 20-40 ms, light on the 4 cores |
| Batch for weekend backlog, audits, rebuilds | **Chosen** | 50% off where minutes of delay do not matter |
| One model for everything (Sonnet low effort on every item) | Not chosen; run once as a replay benchmark | ~$15-20 / day; cascade measured against it |
| Local 7-8B model on the server | Not chosen | 20-50 tokens/s on 4 cores; would starve the trading engine |
| FinBERT-style sentiment | Not chosen | No options direction or sector chains; saves cents |
| Batch for live items | Not chosen | Replies take minutes to hours |
| Opus notes on weekends | Not chosen | Easiest saving; Sunday Sonnet digest feeds Monday 07:15 |
| TV: CNBC-TV18 full hours, ET Now only 09:00-10:30, 14:30-15:30 + breaking | **Trader to decide** | Cuts Deepgram about a third (~$2 a day); small risk of missing an ET Now exclusive |
