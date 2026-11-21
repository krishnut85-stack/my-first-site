# NEWS-TO-SECTOR ENGINE - how every outside item is studied and mapped to sectors and shares (open ideas round, 19 Nov 2026)

The trader, 19 Nov: "After this point we have to study and map, and tell which sector will benefit and which will be affected.
Whatever data we collect from outside directs some sector and some particular shares. The desk is open - open ideas to everyone."
This file merges the open ideas of six specialists (senior trader, head of research, macro strategist, policy expert, quant, AI
engineer). It sits UNDER LINK_BOOK, CHAIN_OF_EVENTS, SECTOR_LINKS and EVENT_MEMORY: those hold the known links; this engine lets
GIR map ANY item, including one it has never seen, to "sector up / down, these shares CE / PE, how strong, how fast, how sure".
Labels: [M] = date or figure from desk memory, not checked in this session (Kite connector down, no live news). Check every [M]
against NSE bhavcopy / Kite before a card quotes it. [E] = desk estimate. Nothing here is a promise; every call carries its record.

## A. THE PIPELINE - from any outside item to the call, step by step

1. **CATCH (fastest source first).** Poll primary sources directly, by page diff (hash each page every 15-60 s, alert on any new
   PDF), not only RSS or the press: India (NSE/BSE filings, PIB, eGazette, CBIC, DGTR, DGFT, RBI, SEBI, NPCI, IRDAI, TRAI, CERC,
   PNGRB, DAC, Cabinet briefing, Parliament lists, Supreme Court lists) and abroad (Truth Social, White House actions, Federal
   Register public-inspection desk, USTR, CBP CSMS, Commerce/BIS, FDA, China MOFCOM, EU Official Journal). Plus wires, TV
   speech-to-text (F17), Hindi / regional press, and the OPEN IDEA BOX (section C1). Every item gets GIR's FIRST-SEEN time.
2. **FAST PATH (under 2 s, no LLM).** About 60 phrase triggers ("Section 232", "anti-dumping", "safeguard duty", "export ban",
   "windfall", "reciprocal tariff", "sanctions", "ceasefire", "repo", "MSP"), each tied to a ready sector map, and the scenario
   trees written the evening before (C6). If the headline matches a branch, the alert fires now; the LLM refines it after.
3. **EXTRACT INTO A FIXED FRAME (cheap LLM, about 1-2 s).** actor | action | object (product, HS code, scheme, company) | old
   value -> new value | country | scope and exclusions ("branded vs generic", "new petitions only", "exempt", annex) | certainty
   rung | effective date | what is NEW versus the open story | "who loses / who wins?". Code checks it: numbers must appear in
   the text; tickers come only from the entity linker and the F&O master (closed vocabulary), never from the LLM.
4. **TURN THE FRAME INTO A SHOCK.** The frame becomes a change to named LEVERS / factors: "US tariff on India HS 61 +25 points",
   "Brent +4%", "INR -1%", "customs on bulk Scotch -50%", "RBI risk weight on unsecured loans +25". Several drivers moving at once
   are netted (crude -3% with rupee -0.8% = a smaller OMC CE).
5. **MAP THROUGH THE EXPOSURE MATRIX (code, under 10 ms).** For every F&O share: impact = exposure x shock x elasticity (fitted on
   the 5-year history, separate for risk-on / risk-off). Then push 1-2 hops through the supply-chain / group graph (weight 0.3-0.5
   per hop, proven edges only). Sector score = weighted sum of its members. Rank: the CE list and the PE list, BOTH sides, always.
6. **SIZE IN MONEY.** Rupee impact / annual PAT (and % change in FY EPS). Under 2% = sentiment, scalp at most; 3-5% = GET READY;
   over 5-10% = re-rating, trade over days. Orders: value / trailing revenue above 5% = STRONG, 1-5% MEDIUM, under 1% noise.
   Exception: a licence or business ban = 100% of that segment's profit (IIFL gold-loan ban, 4 Mar 2024, about -20% next day [M]).
7. **ADJUST FOR SURPRISE AND PRICED-IN.** Expected move x (fact minus expectation) x (1 - already priced). Priced-in = the sector's
   5-20 day run in the news direction, IV rise, OI build, news-flow count, prediction-market odds. Ratio of expected move to the
   ATM straddle: above 1 = option worth buying; under 0.5 = sell-the-news risk; under 0 = fade. Repeat of a known fact = no trade.
8. **SET HOW FAST.** Each event type has a measured half-life: GAP (tariffs, global shocks: done in about 15 min, or by 09:45),
   SAME-DAY (regulator orders, confirmed broker / TV calls), DRIFT over days (PSU policy, PLI, defence pipeline, midcaps). Speed
   picks the strike and expiry (same-day ATM vs next month, rule E7).
9. **SET HOW SURE.** A probability, not a word: event-type base rate (shrunk for small samples) x source certainty x stage x
   materiality x surprise x price confirmation, recalibrated weekly (section D). Card shows "68% (n=41)".
10. **CHECK (section D):** second model plus red-team agent, sign check against the exposure matrix and the link book row, then
    the MARKET VOTE: first 1-5 min of the whole sector basket, breadth, leader vs laggard, OI, IV, USDINR, GIFT NIFTY.
11. **ISSUE ONE LINE, the same everywhere** (alert, note, card, Telegram):
    `<event> | rung <certainty> | new <0-1> | SECTOR UP: X (+a%) / DOWN: Y (-b%) | CE: names | PE: names | NIFTY <+/-n pts>
    | speed <half-life> | sure <p> (n=<cases>) | priced <yes/partly/no> | market vote <yes/no/pending> | cancel if: <fact>`
    The kill clause is written BEFORE entry. Overnight items go into the 19:45 / 22:45 / 07:15 notes; live items into E12 and News.
12. **FILE AND SCORE.** Filed in its EVENT_MEMORY story, scored at 15:45 (and day 2, day 5). A move of 3%+ GIR did not name in
    advance is a MISS (D6).

## B. THE KNOWLEDGE IT NEEDS

1. **EXPOSURE MATRIX (the core; biggest gap today).** One row per F&O share (~218), about 40 columns, each with source and date:
   - revenue by geography: US, EU, China, Middle East %; export %; government / defence / rural customer %; key customers;
   - export lines by HS code (US / EU split); PLI schemes held;
   - cost as % of sales: crude, gas, coal, steel, copper, aluminium, rubber, palm oil, gold, China inputs (API/KSM, magnets);
   - USD revenue vs USD cost, USD debt, net debt and floating-rate %;
   - regulator (RBI / SEBI / IRDAI / TRAI / CERC / PNGRB / NPPA), regulated-price %, states where plants and sales sit;
   - Russia-oil link, FII ownership %, MSCI / FTSE passive weight; elasticity per factor; beta to sector and NIFTY.
   Filled by LLM from annual-report segment notes, XBRL, BRSR and con-call transcripts, checked once by a person; then estimated a
   second way by rolling regression on prices. Both are kept; a disagreement is flagged.
2. **LEVER LIST (~60 named levers)** with the shares exposed to each, revenue or cost side: customs and GST slabs, APM gas, ATF,
   NPPA price hike, state excise, US tariff by HS chapter, SEBI F&O rules, RBI risk weights, MSP / FRP, windfall tax, safeguard and
   anti-dumping duties. Formula levers (APM gas = 10% of crude basket within floor/cap; ATF / LPG on the 1st; NPPA from WPI) are
   COMPUTED by GIR the evening before, so the release is a known surprise.
3. **HS-CODE BRIDGE.** India's exports by HS code and destination (DGCI&S / TradeStat, US Census; paid company-level shipment
   data such as Volza / Panjiva with the trader's yes) joined to company product lists, plus a RIVAL table per HS code (China,
   Vietnam, Bangladesh, Mexico) so "US hits a rival" becomes "India gains". F&O membership is checked: most textile and shrimp
   names are cash-only, so they are a signal, and the card maps to the F&O name with the largest exposure or to the sector index.
4. **SUPPLY-CHAIN / GROUP GRAPH.** Signed, weighted edges: supplier, customer, competitor, parent / subsidiary with % held (JLR ->
   TMPV, Novelis -> HINDALCO, Jio -> RELIANCE, Hindustan Zinc -> VEDL), lender, input, country, regulator, minister -> ministry ->
   sector. Entity aliases: "Tata", "Adani", "Reliance", "L&T" vs LTIM / LTTS, brands, schemes (Kavach, PM E-DRIVE), Hindi spellings.
5. **SECTOR MAP AND INDEX MAP** (BUILD_PLAN 1.7): members with weights, so every sector call also prints NIFTY / BANKNIFTY points.
6. **PAST REACTIONS.** A 5-year timestamped news archive (paid), each headline labelled with the abnormal return of mapped shares
   (net of NIFTY and sector beta) at +5 min, +30 min, close, day 2, day 5, measured from GIR's first-seen time. Gives an event-study
   card per event type (median size, hit rate, half-life, reversal rate) and the 20 nearest past items for any new item.
7. **SOURCE TABLES.** Per source: certainty weight (official 1.0 > minister on record 0.8 > "sources say" 0.5 > social 0.2),
   denial rate by outlet and topic, median lead time to the price move, release-time histogram per body (SEBI / RBI evenings,
   CBIC late night or Saturday). Per speaker: how often their words became policy.
8. **EXTERNAL DECISION CALENDAR** (feeds MISSING_KNOWLEDGE item 0): US tariff deadlines and pause expiries, Section 232 openings,
   court rulings, EU CBAM steps, OPEC+, Fed / RBI / ECB, GST Council, Cabinet Wednesdays, DGTR 3-month notification windows, BIS QCO
   and ALMM deadlines (with their base rate of extension), Parliament sessions, SC "judgments tomorrow" lists, state polls, summits.

## C. THE BEST IDEAS, MERGED (no repeats; each with an example)

1. **THE DESK IS OPEN - IDEA BOX ON THE SERVER.** A page and a Telegram command where anyone (the trader, friends, TV analysts,
   broker notes, the six AI experts, GIR itself) posts an idea in one line, e.g. "gold up -> MUTHOOTFIN CE next day" or "when Trump
   talks tariffs, pharma falls". GIR turns it into a frame + basket, backtests it that night on the 5-year history with the
   SECTOR_LINKS proof rule, paper-trades it 20 sessions, and shows it as IDEA - NOT PROVEN / PROMISING / PROVEN / REJECTED with n,
   hit rate, median move and lag. Proven ideas join the Link Book with their proof line. Credit and hit rate go to the author;
   ideas compete on results, not on who said them. Weekly table: top new ideas, promoted, dropped. Nothing is thrown away.
2. **EXPOSURE MATRIX = ANY NEWS, NOT ONLY KNOWN NEWS** (all six experts). Example: "US tariff on India -35 points" becomes US-revenue
   shock +1, and the ranked CE list falls out at once, even for an event no chain was written for.
3. **HS-CODE TRADE MAPPER for "Trump meets Modi".** Parse the annex or fact sheet to HS lines, look up India's export value, map
   to companies, write BOTH sides: exporters CE vs domestic firms losing protection PE (a duty cut on a competing import is negative
   for the domestic producer). Example [M]: 50% US tariff from 27 Aug 2025 hit textiles, shrimp, gems, auto parts (SONACOMS,
   BHARATFORG, MOTHERSON); pharma and smartphones exempt (relative CE DIXON). Feb 2026 deal to about 18%: NIFTY gapped up about
   2.5-3% and the same names rallied [M]. Hidden winners: a tariff that weakens the rupee is CE for IT and pharma exporters.
4. **READ THE SCOPE BEFORE THE SIGN.** Example [M]: 25 Sep 2025 100% tariff on branded / patented drugs; generics were outside it,
   so the first-hour PE on NIFTY PHARMA was the wrong read. Rule: wait for the scope line, or issue at half size "scope unknown".
5. **STAGE LADDER: TRADE THE RUNG, NOT THE TOPIC.** "sources" < consultation / draft < Cabinet / Council approval < gazette <
   effective date. Each rung up is a fresh, smaller trade; a repeat is no trade; a denial resets it. Example [M]: GST 2.0 speech 15
   Aug 2025 -> autos gapped 18 Aug (MARUTI about +8%); Council 3 Sep and effect 22 Sep added much less. SEBI F&O curbs: paper 30 Jul,
   board 30 Sep, circular 1 Oct 2024 [M]. Auto-diff draft vs final: softer = relief CE, harsher = second PE leg.
6. **SCENARIO TREES THE EVENING BEFORE** every scheduled or rumoured event (Trump-Modi, RBI, Fed, GST Council, OPEC+, Budget,
   tariff deadlines): 3-5 branches with probability (prediction markets, CME FedWatch, implied move), CE / PE lists, strikes,
   premium limit. When the headline lands GIR only picks the branch, under 5 s. A jump in the odds is itself news.
7. **OVERNIGHT GAZETTE SWEEP 06:30-08:45 + US CLOCK.** The 07:15 note lists every notification since 19:45, already mapped.
   Examples [M]: windfall tax scrapped late 2 Dec 2024 -> RELIANCE / ONGC up next morning; H-1B $100k fee Fri 19 Sep 2025 (US
   evening) -> NIFTY IT about -3% Mon 22 Sep, a whole weekend of warning (later clarified "new petitions only").
8. **OVERSEAS WITNESSES / SHADOW PRICES before 09:15.** Regress each sector's gap on ADRs (INFY, WIT, HDB, IBN, RDY), GIFT NIFTY,
   USDINR NDF, Korea / Japan peers at 05:30 (Hyundai, Toyota for auto parts), ASX miners, SHFE night / Dalian, US peers' results
   (Accenture for IT). The 07:15 note says "expected gap AUTO +0.9% +/- 0.4"; shares whose real gap falls short are the trade.
9. **FOREIGN TWIN AS THE PRIOR.** The same kind of news hit another market first (a US deal with Japan, Korea, Vietnam, UK): its
   sector reaction is GIR's starting estimate. Example [M]: US-UK deal 8 May 2025, UK cars 27.5% -> 10% reached TMPV via JLR.
10. **COMPETITOR-COUNTRY READ-ACROSS.** A tariff on India's rivals is CE for India. Example [M]: 2 Apr 2025, Vietnam and Bangladesh
    got higher tariffs than India, Indian textiles briefly rose.
11. **PRICE IS THE JUDGE AND THE RADAR.** No confirmation in 5 min = down one grade. In reverse: OTM CE / PE volume 5x, IV or OI
    jump, or sector breadth spike with NO news = "PRICE BEFORE NEWS / SOMETHING COMING": search every source now. A big pre-move
    15-60 min before the headline = leaked or priced: lower the grade.
12. **PUNISHED COMPANY: PE it, CE its competitor.** Example [M]: Kotak barred from new digital customers 24 Apr 2024, -11% next day;
    IIFL gold-loan ban -> CE MUTHOOTFIN, MANAPPURAM. Same for US FDA warning letters / import alerts on a plant.
13. **SPEAKER PRIORS.** Score each minister and official by how often words became policy. Example [M]: Gadkari floated extra GST
    on diesel vehicles 12 Sep 2023, autos -2 to -4% intraday, recovered within the hour after his clarification. Low-conversion
    speaker = fade trade only. DENIAL WATCH: a denial is its own event (UPI MDR "baseless", Jun 2025, PAYTM -10% [M]).
14. **COURTS, PARLIAMENT, CABINET as scheduled events.** SC "judgments tomorrow" and live display board ("IDEA AGR is item 2 away
    in Court 1"); Lok Sabha List of Business (online gaming bill 20 Aug 2025, NAZARA fell [M]); Cabinet Wednesday briefing at a
    15 s poll (MSP in June, sugarcane FRP, PLI, DAC approvals -> HAL, BEL, BDL, MAZDOCK).
15. **GEOPOLITICAL ESCALATION LADDER** (rhetoric < strikes / sanctions < shipping or airspace < oil supply loss < ceasefire, which
    reverses all), with a measured fade time per rung. Examples [M]: Op Sindoor 7 May 2025 -> defence CE, INDIGO PE, ceasefire gave
    NIFTY about +3.7% on 12 May; Israel-Iran 13 Jun 2025 -> Brent up, PE OMCs / paints / aviation, CE ONGC / OIL; reversed 24 Jun.
16. **CHINA MODULE.** Stimulus = metals CE but FII rotation out of India (24 Sep 2024, then about Rs 94k cr FII selling in Oct [M]);
    rare-earth controls 4 Apr / 9 Oct 2025 = PE risk for EV / auto parts (SONACOMS; Bajaj warned Jun 2025 [M]); "anti-involution"
    cuts = steel, solar, chemicals CE; US-China detente = China+1 names (DIXON) PE. MOFCOM lands live in Indian market hours.
17. **CROWDING MULTIPLIER.** Same news moves a crowded side harder: bad news on crowded longs = strong PE; good news on a short-heavy
    name = squeeze (MARUTI 19 Nov). Read OI build-up, PCR, FII index long-short, delivery %, near-ban status.
18. **STATE AND REGIONAL SOURCES, translated by LLM.** Liquor excise (UNITDSPR, RADICO), stamp duty (DLF, GODREJPROP, LODHA),
    mining royalty (NMDC, VEDL), UP / Maharashtra sugar prices, discom tariffs; Lokmat, Eenadu, Dainik Bhaskar break them first.
19. **ALTERNATIVE DATA before the official number**, each with an "expected vs actual" bar the evening before: Grid-India demand
    and IEX prices (power), VAHAN registrations (autos), DGCA / daily air traffic (INDIGO), BigMint steel and coal (steel users),
    SCFI / Drewry / Baltic freight (exporters), IMD heat and rain (VOLTAS, power), Google Trends and app ranks (PAYTM, ETERNAL,
    NYKAA), GST e-way bills, China customs data (7th-10th), RBI weekly credit growth (banks). Tanker tracking for Russian crude.
20. **CENTRAL-BANK TEXT DIFF IN 5 s** (FOMC, RBI, ECB): word-by-word vs last statement, hawk / dove score, mapped to PSU banks,
    private banks, NBFCs, realty, autos, then the rupee, then IT. Press conference scored sentence by sentence.
21. **FII FLOW CHANNEL.** DXY, US real yields, EM ETF flows and China give an FII-flow forecast, applied first to the sectors FIIs
    own most (NSDL fortnightly data): private banks, IT, large-cap autos. MSCI / FTSE passive dates on the calendar.
22. **ONE AI ANALYST PER SECTOR.** 20+ agents each hold their sector dossier and exposure rows; every item goes to all of them
    (cheap model for triage, strong model only above a weight); each returns sign, size, speed, confidence, quoted evidence. The
    head-of-research step combines the votes and resolves conflicts (IT: rupee CE vs H-1B PE).
23. **NOVEL EVENT = LIVE TEST.** No chain or analogue: the LLM proposes 2-3 chains marked IDEA - NOT PROVEN, GIR tracks those
    baskets' relative returns at once, the market grades them in 15 min, the result goes to the ledger. Theme heat index (news
    z-score x basket strength) lowers trigger levels for rising themes (defence after 7 May 2025) and raises them for fading ones.

## D. HOW IT IS CHECKED, AND HOW IT LEARNS

1. **LLM EXTRACTS, CODE DECIDES.** The LLM fills the frame and must cite the exposure fact it used; arithmetic, sign and strike are
   code. Two models extract; any disagreement on sign = WATCH only and goes to a "check" queue. The LLM never picks the strike.
2. **RED TEAM ON EVERY CE / PE GET READY.** A separate agent argues the other side (input or output? already priced? scope wrong?
   crowded? which shares WIN if this is bad?) and quotes traps C1-C19. Embedding search pulls the 3 closest past events with their
   measured reactions. Debate (bull, bear, quant judge) only for impact MEDIUM or higher, inside the $20/day cap.
3. **CONFLICT RULES.** (a) Statistical sign must agree with the exposure-matrix sign, else no call. (b) Two drivers on one share are
   netted in the matrix, not voted. (c) Text says up, first 3-5 min of price, breadth, IV say down -> trust the price ("sell the
   news"): no trade or the other side. (d) Official text beats "sources"; a later rung beats an earlier one; a denial resets.
   (e) Big expected move but money still for 5 min -> already known or not believed: down one grade.
4. **FALSE-LINK CONTROLS on top of the SECTOR_LINKS proof rule.** Placebo days (real hit rate must beat the placebo's 95th
   percentile); Benjamini-Hochberg false-discovery control (~48,000 tests means ~2,400 lucky links at 5%); remove NIFTY, sector,
   crude, INR first; shrink small samples (5 of 6 shown as about 64% with its range); walk-forward only; restart history at breaks
   (TMPV demerger). Keep a paper book of EVERY idea, including suppressed ones, to avoid selection bias.
5. **CALIBRATED CONFIDENCE.** Every call logged with its probability. Weekly Brier score and reliability chart per event type,
   source, speaker and analyst; isotonic recalibration. If "70%" calls do not land 65-75% over 100 calls, GIR lowers the number
   automatically; a badly calibrated type is demoted to IDEA - NOT PROVEN. Size ranges by conformal intervals ("+1.2% to +3.0%").
6. **MISS HUNT, nightly.** Every F&O share that moved 3%+ with no GIR alert: find the earliest source that had it, add that source
   or link the same week, replay. Nightly "what would have moved" replay: feed the day's news with timestamps but WITHOUT prices,
   record the calls, compare with real minute moves; misses go to the gap list; weights and half-lives retuned weekly.
7. **SCORE GIR AGAINST A HUMAN DESK.** Lead time = when the price move started minus GIR's alert, benchmarked to the CNBC-TV18
   ticker; precision of sector calls at 30 min and close; kill-clause obeyed or not (15:45 audit). Weekly, so "earlier and more
   correct" is a number. Effort goes to sources with the largest "edge window" (seconds before NIFTY reacts).

## E. WHAT TO BUILD WHEN

**Before Monday (23 Nov)** - the parts that make the 18 -> 19 Nov case and a tariff case work by hand-checked rules:
- event frame schema + closed vocabulary (F&O master, aliases, sectors, HS chapters, regulators); fast-path phrase triggers (~60);
- exposure matrix v0 for the ~40 names in the metals, autos, IT, pharma, OMC, textiles / auto-parts and defence rows (cost of
  metals / crude, US revenue %, export %), each cell with source and date, marked v0;
- the one-line output format and kill clause on every card; "IDEA - NOT PROVEN" label on anything without a proof line;
- OPEN IDEA BOX v0: a server page + Telegram command that stores ideas with author and time and shows them on the Desk and in
  the evening report (backtest comes in week 1); seed it with this file's section C;
- overnight gazette / US-clock sweep feeding the 07:15 note (PIB, eGazette, CBIC, Federal Register public inspection, White House);
- replay tests R1 and R2 below.
**Week 1:** full exposure matrix for all ~218 shares (LLM fill + human check); HS-code bridge and rival table; scenario trees for
every calendar event; priced-in meter; materiality normaliser; market-vote check; idea-box backtest overnight; miss hunt; tests R3-R5.
**Later (weeks 2-6):** regression-estimated exposures; 5-year labelled news archive (paid) with KNN and event-study cards; one agent
per sector; calibration and Brier charts; supply-chain graph 2 hops; courts / Parliament / state / regional-language feeds;
alternative data bars; central-bank text diff; prediction-market odds; FII flow channel; score-vs-human-desk report.
**Paid items need the trader's yes, each with its price:** news archive, HS-code shipment data, BigMint, Kpler / Vortexa, regional
news API, court cause-list feed.

## F. REPLAY TESTS (must pass; inputs rebuilt from daily data are labelled so - never passed by hand)

| # | Date / case | Input GIR must see | Pass if GIR says |
|---|---|---|---|
| R1 | 18 -> 19 Nov 2026, metals down -> autos up | copper, aluminium, steel down on 18 Nov; NIFTY METAL and cables short build-up | 18 Nov 19:45: SECTOR DOWN metals / cables (PE POLYCAB, KEI, HINDALCO, VEDL), SECTOR UP autos (CE ASHOKLEY, MARUTI, HEROMOTOCO, TVSMOTOR, M&M, EICHERMOT) from the cost column of the exposure matrix, with NIFTY points, speed "next open", Dec strikes, kill clause; crude / rupee also checked (CHAIN_OF_EVENTS D1). |
| R2 | 27 Aug 2025 [M], US tariff on India to 50% (order 6 Aug) | White House order / CBP CSMS HS lists, overnight | PE auto parts (SONACOMS, BHARATFORG, MOTHERSON), textiles / shrimp / gems flagged cash-only and mapped to the nearest F&O name or index; pharma and smartphones EXEMPT (relative CE DIXON); rupee-weak CE IT named as the hidden winner; speed GAP. |
| R3 | Feb 2026 [M], Trump-Modi deal, tariff to about 18% | deal fact sheet / Truth Social post | scenario-tree branch "deal" matched in under 5 s; CE the same exporters as R2 reversed; PE domestic sellers of goods India opens to US imports; priced-in meter run against the exporters' run-up; NIFTY gap up estimated. |
| R4 | 25-26 Sep 2025 [M], 100% US tariff on branded / patented pharma | Truth Social post, US evening | scope rule fires: "branded only - generics outside"; call issued at half size "scope unknown" or as WATCH, NOT a full PE on NIFTY PHARMA; recovery of generic names expected. |
| R5 | 19-22 Sep 2025 [M], H-1B $100k fee | proclamation Fri 19 Sep US evening; weekend clarification "new petitions only" | 07:15 Mon 22 Sep note: PE IT (INFY, TCS, WIPRO, HCLTECH...), ADR moves quoted, size cut after the scope clarification, speed GAP, kill clause; counted as found 2 days early, not a miss. |
