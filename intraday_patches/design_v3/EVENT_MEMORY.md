# GIR - EVENT MEMORY (every story remembered with its price reaction, recalled the moment it comes back)

Written 19 Nov 2026 for the trader's question: "Paytm is buzzing now. If the news comes up again after 10 days, the server should
remember: something happened before, this news is back, the stock may go up or down." Built from three desk answers (senior F&O
trader, event quant, data architect). No live data was used: the claude-code-kite connection was down today.

**Labels.** [V] = checked in POLITICAL_CYCLE.md. [M] = desk market memory, not checked today. [E] = desk estimate. Every number
below must be recomputed from Kite minute candles and NSE bhavcopy before GIR quotes it on a card.

**The short answer.** Today GIR files a news item once and forgets it. From now on every item joins a STORY that stays open for
months. Each story keeps every past headline with what the share, its OI and its option IV did afterwards. When a new headline
fits an old story, the trader gets a STORY BACK card within 10 s (30 s for TV) showing the past reactions, how much of the last
fall has been won back, the suggested option side and a confidence. The card is a prior, never a GO NOW on its own.

**The traders' rule behind it.** A follow-up headline moves the share by (how new the fact is) x (how many people have bet again
since the last episode). Repetition alone does not shrink the move. PAYTM proves it: after -5% on 8 Oct and -7% on 13 Oct it ran
from 1,558 to 1,890, and the 19 Nov repeat fell 7-9%, as much as the first hit [V]. So GIR must store how much of the last fall
was won back, not only the dates.

## A. WHAT GIR REMEMBERS

**STORY** (one long-running theme, e.g. PAYTM-UPI_MDR):
- main share and side shares (PAYTM; MobiKwik, Pine Labs, PB Fintech weak), with which way each outcome moves each share;
- topic words ("UPI MDR", "merchant discount rate", "UPI fee", "zero MDR", "NPCI steering committee") and the body that decides
  (NPCI / FinMin / SC / SEBI);
- story state for policy stories: PENDING / DELAYED / CONFIRMED / NOTIFIED / DEAD; life status: ACTIVE, DORMANT after 5 quiet
  trading days, RESOLVED when the matter is closed (rule in force, verdict, deal closed or dropped);
- next known trigger and date (NPCI meeting, 31 Dec share-cap deadline, UP polls early 2027), linked to the POLICY CLOCK and the
  Calendar page;
- KEY LEVELS, the prices where the share turned ("1,700: TV buy call, bounce 19 Nov");
- "won back since last episode" (% of the last fall recovered), last-wake time, a centroid embedding.

**EPISODE** (one row per FACT, not per article - eight outlets carrying one "sources say" line = 1 episode with 8 sightings):
- first-seen time (earliest across all sources), the exact words (snippet up to 1,000 characters; TV = 30-60 s of transcript with
  channel and speaker), language, entities (shares, people, regulators, states);
- NOVELTY: FIRST / REPEAT-NO-NEW-FACT / NEW-FACT / DENIAL / OFFICIAL / RESOLUTION / TV-VOICE, plus "what is new vs last episode";
- EVENT TYPE from a fixed list of about 25, so episodes compare across shares: policy delay, policy confirmed / firm date,
  government denial, regulator action on one company, licence approval, result beat / miss, guidance, block deal or promoter sale,
  lock-in expiry, broker upgrade / downgrade, TV analyst buy / sell call, management interview, order win, court ruling,
  governance or fraud, fundraise / QIP, index inclusion, ban / MWPL, deal, rating;
- stance per share (+ / -), tone (-2..+2), SOURCE CLASS: OFFICIAL (circular, filing, PIB, minister on record) / ON RECORD (named
  person) / SOURCES SAY / ANALYST OPINION / SOCIAL; MIXED DAY flag (results or another big story the same day); session phase
  (overnight, pre-open, live, after 15:10); the model and version that tagged it.

**MARKET AT FIRST SIGHT**: price, % on the day, distance from VWAP, futures OI, ATM IV, IV rank, 20-day run-up, distance from the
52-week high, days since the last episode, and the move in the 15 min BEFORE first sight (already down 3% = leaked or priced).

**REACTION** (one row per episode x share x horizon; see D). **SIGHTINGS** (every source, URL, published time, first-seen time,
delay - the BUILD_PLAN R10 / R11 data, now linked to the episode). **TV CALLS** (F17, with each analyst's score). **MATCH LOG**
(every match decision and every correction by the trader).

## B. HOW A NEW ITEM IS MATCHED

1. **Tag** (every item, at once). Dossier alias table ("Paytm", "One97", "पेटीएम", "Vijay Shekhar Sharma" -> PAYTM) and the topic
   dictionary give share keys and topic keys. Hindi (CNBC Awaaz) is covered by a multilingual embedding model (e.g.
   multilingual-e5-small, 384 numbers, about 10 ms on the CPU).
2. **Candidates**: every story of any age that shares a share or topic key; OPEN or DORMANT in the last 365 days ranks first.
3. **Score** = 0.45 embedding similarity (to the story centroid and its last 5 episodes) + 0.35 keyword overlap (full-text rank on
   the topic words) + 0.20 entity overlap. A shared circular / filing number or POLICY CLOCK item adds a bonus.
   - 0.75 or more: attach. 0.60-0.75: one cheap AI yes / no check (inside the E13 $20 / day cap). Below 0.60: open a new story,
     the trader sees "new story?" with merge / split buttons, and the analyst confirms it that night.
4. **Same fact or new fact**: cosine 0.92+ within 6 h, or the same circular number = a new SIGHTING of an existing episode, not a
   new episode. Otherwise the small model labels the novelty and the code checks it against the last episode's facts (new date,
   new forum, new number, named official = NEW-FACT).
5. **Similar events, three levels** (always searched, shown with the level):
   - L1 = same share, same story (UPI-MDR already has 5 news episodes + 1 TV-VOICE);
   - L2 = same share, same event type, other stories (PAYTM regulator negatives, e.g. Feb 2024);
   - L3 = same event type on other shares (policy delays in telecom, OMCs; denials such as Adani 2024), scaled by beta and ATR.
6. **Wake on price**: a share moving 3%+ with no new item shows "possible: PAYTM-UPI_MDR again, last item 10 days ago - searching"
   until news explains the move. Each open story keeps a keyword and TV-transcript watch.
7. **Corrections**: nightly merge of stories whose centroids are 0.85+ alike on the same share; a "wrong story" button on the News
   page. Every correction is stored and used as training data. Target: match within 10 s of first sight (30 s for TV).

## C. WHAT THE TRADER SEES WHEN A STORY COMES BACK

A STORY BACK card fires when a NEW-FACT, DENIAL, OFFICIAL or TV-VOICE episode joins a story with 2+ priced past episodes, or one
DORMANT for 3+ trading days. Example (a made-up future headline):

> STORY BACK: PAYTM - UPI merchant fee (open since Jun 2025, episode 7). NEW: "NPCI notifies 1 Apr 2027 start" (Reuters, 09:42)
> = OFFICIAL, POSITIVE, NEW FACT: yes (first firm date). Past: Sep 2026 firm date +7%, 52-week high [V]; FinMin denial 12 Jun 2025
> -10% [V]; 3 delay headlines (8 Oct, 13 Oct, 19 Nov) -7 to -10% intraday, about half undone by the close [V, recheck]. IV +4 pts
> on average [E]. Since 19 Nov: share +4%, won back 60% of the fall - buyers only partly back, move should be sizeable. Key level
> 1,700 (TV buy call 19 Nov). Already +1.2% in the 15 min before = partly priced. You hold: none.
> PLAN: CE only after the first 5-min close above the pre-news high and VWAP; ATM, buy in the first 15 min, no overnight hold
> (IV crush). Fades if the cap or exemptions look wide. CANCEL on a denial.
> CONFIDENCE: MEDIUM (L1 n=4 same way, L3 n=23) - NOT PROVEN. Confirm through E3 / E8.

- For a rehash the card says "REPEAT, NO NEW FACT - expect a fade by 11:30, no GO NOW" and is low priority.
- Priority HIGH if the trader holds the share (either side - it always rings when he holds the other side) or the source is
  OFFICIAL; lower for SOURCES SAY.
- A TV buy call on a falling share he holds a PE in: "TV BUY call on PAYTM at ~1,700 - bounce risk: book or trail now".
- The card feeds E12 and the vote; E3 sector confirmation and E8 price triggers still decide GO NOW.
- 19:45 evening note: every story with a catalyst inside 10 days ("PAYTM-UPI_MDR: 31 Dec NPCI share-cap deadline, UP polls 2027").

**What each follow-up usually does** (rough share of the first hit, intraday) [E]:
| Type | Usual move | How to trade |
|---|---|---|
| FIRST HIT ("sources say") | 100%; 30-50% comes back by the close | per E8 |
| REPEAT, NO NEW FACT | 0-30%, fades by 11:30 | fade only, never GO NOW |
| REPEAT, NEW FACT | 60-120%, more if buyers are crowded | as a first hit |
| DENIAL of good news | the biggest fall (12 Jun 2025 PAYTM -10% [V]) | PE |
| DENIAL of bad news | 50-100% of the fall back in 1-2 days (Adani 27 Nov 2024 [M]) | CE on the bounce |
| OFFICIAL confirms a rumour | 30-60% if believed; 100%+ if brushed off (VWAP won back) | check rumour-day VWAP |
| RESOLUTION | big only if not priced: "sell the news" or a cliff when hope dies | check won-back % |

## D. HOW REACTIONS ARE MEASURED AND HOW THE MEMORY LEARNS

- **Clock** starts at first-seen time, not publish time. News outside hours starts at the pre-open price (F09), so +5 min = 09:20.
- **Horizons**: +5, +15, +30, +60 min, 15:10 (his exit), close, next-day open gap, day 2 close, day 5.
- **Values**: share %; abnormal move = share - beta x sector - NIFTY; biggest move against and in favour; minutes to the extreme;
  BOUNCE % = (close - low) / (start - low); path shape TREND / V (half or more undone, as 13 Oct and 19 Nov) / FADE / STEP; what
  stopped the move (TV call, denial, NIFTY turn); futures OI % change and build-up type; ATM and 1-OTM CE / PE premium % on the
  stance side; ATM IV change in points at +15 and the close, IV at the next open (crush); spread % at the worst minute; VWAP won
  back yes / no; follow-through ratio (day-2 move / day-1 move, negative = reversal).
- **Confounded**: a day NIFTY moved 1.5%+ or a MIXED DAY is counted but never used alone or in averages; REHASH episodes likewise.
- **Jobs**: 15:45 writes day-1 stats from F25 minute bars and F26 IV; the next day 15:45 writes day 2; day 5 the same. Story stats
  are rebuilt each time an episode joins, per TYPE (delays compared only with delays): n, median, worst, average bounce, IV change,
  follow-through rate, and repetition fatigue (5th delay moving less than half the 1st = market getting used to it).
- **Sample-size rules**: n < 3 = show episodes only, no average; n 3-7 = rows + median, direction counts only if all but one agree,
  confidence capped at MEDIUM; n 8-19 = median, range, hit rate; n 20+, holding in both halves and the last 2 years (SECTOR_LINKS
  rule) = may reach STRONG. Pooling: estimate = (n1 x L1 median + 5 x L2/L3 median) / (n1 + 5); recency half-life 2 years.
- **Grade points** added to B4: L1 n >= 3 all one way +2, mixed -1; similar context (run-up, certainty, source class) +1;
  fatigue showing -1; a fresh contrary episode today (denial, TV call by a high-hit-rate analyst) = CANCEL.
- **Learning**: every card is logged with its 15:10 result; a weekly scorecard shows recall accuracy per event type; TV analysts
  and source classes are re-scored; trader corrections retrain the matcher; embeddings are re-made overnight when the model changes.
- **Back-fill**: past episodes from Kite minute candles; option / IV history before today only from daily bhavcopy ("from closes").
  Minute option data and F17 transcripts exist only from the day recording starts - every day not recorded is lost.

## E. THE STORE, RETENTION AND DISK SIZE

One Postgres on the server (the TimescaleDB already planned) with pgvector. Tables: story, episode, sighting, market_at_first_sight,
reaction, story_stats, tv_calls, match_log. Cost: one embedding + at most one small-model call per item.

**Retention.** Kept forever: stories, episodes, sightings, tags, reactions, stats, and embeddings of items tagged to an F&O share or
policy basket. Paid articles (ET Prime etc.): headline, snippet and URL only. Free article text: compressed. TV: snippets forever,
full rolling transcripts 30 days, 60-s audio clips around triggers 1 year. Filing PDFs: F&O companies forever, others 90 days
(text only). Raw page pulls: 90 days (F30).

**Size** [E] (4,000 items a day, 1,500 tagged to F&O or policy, 20,000 sightings a day):
| Part | Per day | 5 years |
|---|---|---|
| episodes 6 MB, sightings 2.4 MB, embeddings + index 2.3 MB, reactions 1.3 MB, text indexes 4 MB | about 16 MB | about 30 GB |
| Filing PDFs (F&O names, 250 trading days) | about 60 MB | about 75 GB |
| TV audio clips (1 year rolling) | - | about 9 GB |
| **Total** | | **about 115 GB** |
Fits the 500 GB SSD / 16 GB RAM server (CHAIN_OF_EVENTS E9). The search index for 2 years (about 1.1 million items) needs < 2 GB RAM.

## F. FIRST EXAMPLE - THE PAYTM / UPI-FEE STORY, AND THE TESTS

**Seed it now** from POLITICAL_CYCLE table A, reactions recomputed from Kite candles, so the next headline gets a card:
| # | Date | Episode | Novelty / source | PAYTM reaction |
|---|---|---|---|---|
| 1 | 12 Jun 2025 | FinMin calls UPI MDR reports "false, baseless" | DENIAL of good news, OFFICIAL | -10% intraday (864), -5.7% by midday [V] |
| 2 | mid-Sep 2026 | NPCI sets 0.4% MDR above Rs 2,000 from 15 Oct | OFFICIAL, firm date | up to +7%, 52-week high [V] |
| 3 | 8 Oct 2026 | Reuters: fee may slip after retailer pushback | NEW-FACT, SOURCES SAY, delay | -7.6% to -10% intraday, close about -5% [V] |
| 4 | 13 Oct 2026 | NPCI defers to "after Diwali, date to be notified" | NEW-FACT, OFFICIAL, delay | -7% intraday, recovered to 1,688, V [V] |
| - | 8 Nov 2026 | Diwali passes, no date | non-event, story DORMANT | - [E] |
| 5 | 19 Nov 2026 | Reports: fee may wait until after 2027 polls | NEW-FACT, SOURCES SAY, delay | -6% to -9% (1,890 -> 1,730-1,756) [V/T] |
| 6 | 19 Nov 2026 | CNBC-TV18: "1,700 is a good buying price" | TV-VOICE, ANALYST OPINION | fall stopped, turned up [T]; key level 1,700 |
Before 19 Nov the share had won back the whole Oct fall (1,558 -> 1,890), which is why episode 5 hit as hard as episode 3.
Do the same for every other open POLICY CLOCK item; then back-fill 2-3 years for every F&O share (Adani, Vodafone Idea, Zee,
IndusInd first; GDELT news archive first) [M]: Adani shows a NEW story (US indictment, 21 Nov 2024, -23%) is not a repeat;
Vodafone Idea that court orders move more than relief hopes; Zee that a confirmation after a believed denial hits harder;
IndusInd that once the hole is sized, follow-ups move less.

**Replay tests** (add to BUILD_PLAN section 4):
1. **PAYTM 8 Oct, 13 Oct, 19 Nov 2026** with the seeded story: each time a STORY BACK card within 10 s of the first sighting,
   labelled "REPEAT, NEW FACT", showing the earlier episodes and the won-back %. On 19 Nov the TV line joins the same story as
   TV-VOICE within 30 s, 1,700 is saved as a key level, and a held PAYTM PE gets the HIGH "bounce risk" alert.
2. **Made-up "NPCI notifies MDR from 1 Apr 2027"**: joins the story as OFFICIAL / firm date, compared with Sep 2026, shown CE side
   with the confidence line. Then eight copies of one rehash headline: 1 episode, 8 sightings, counted once, card says
   "REPEAT, NO NEW FACT - expect a fade, no GO NOW".
3. **Adani 21-27 Nov 2024**: the indictment opens a NEW story (not a repeat of Hindenburg 2023, L2 match shown only as context),
   then the 27 Nov clarification is flagged as DENIAL of bad news with the expected bounce.

**Honest limits.** L1 samples are tiny (n = 4-6), so the card always shows the episodes and says NOT PROVEN until the SECTOR_LINKS
rule passes. The AI can mislabel DELAY vs FIRM; every label is shown and one click fixes it. Older TV calls exist only if
recorded, so F17 transcripts must be stored from today. Not investment advice.

Sources (internal): BUILD_PLAN.md (1.2 F09, F15-F17, F25, F26, F30; 1.5 R10 / R11; 1.7; E3, E8, E12, E13), design_v3/
POLITICAL_CYCLE.md (table A, POLICY CLOCK), CHAIN_OF_EVENTS.md (B1-B5, E9), DATA.md (D39), SECTOR_LINKS.md, LINK_BOOK.md (B10).

## G. SECOND EXAMPLE - "US AI SHOCK -> MONEY INTO INDIAN IT" (story opened 20 Nov 2026, the trader's read)
The trader, 20 Nov 10:45: "This Anthropic AI IPO listing shocked the US market tech wave. They pulled out the money and are putting
it in Indian IT. So IT is coming up. This is one of the history."
- **Episode 1, Thu 19 Nov (US) -> Fri 20 Nov (India):** Anthropic listed on Nasdaq (ANT, priced $83, opened $111.50); the S&P fell
  ~2.0%, Nasdaq ~2.3%, AMD ~-10%, 6th straight S&P loss on AI-spend worries; Nikkei -4.3%. India opened lower, metals worst
  (-1.8% to -2.5%), but **Nifty IT LED, up to +1.3-1.6% (TCS, Tech Mahindra, HCL Tech, Infosys)** - Indian IT went UP while US
  tech fell (OUTSIDE_WATCH_2026-11-20.md). FIIs bought a 14th straight session (Rs 7,411 cr on 19 Nov); November FPI buying ~$8.5bn,
  money moving out of Korea / Taiwan (AI-hardware markets) into India.
- **Possible reasons, both sides (NOT PROVEN):** (1) rotation out of AI-hardware / AI-capex names into AI-ADOPTER services (Indian IT
  sells the work, not the chips); (2) a weak rupee (dollar near a 19-month high) lifts IT exporters' earnings; (3) IT was
  oversold after 3 down days (bounce). Against: US tech weakness usually hits Indian IT next day via ADRs; the desk's 19 Nov
  evening call was IT PE - WRONG this morning (logged in the scorecard).
- **Linked keys:** AI-IPO / AI-capex shock (US), Nasdaq vs Nifty IT, INFY / WIT ADR, USD-INR, FPI flows by country, Korea / Taiwan.
- **To measure after the close (server, from its own NSE data):** Nifty IT and each IT F&O share from the 09:15 open and from Thu's
  close; IT vs NIFTY; the 20 Nov FII / DII figures; next 1 / 2 / 5 days. If IT holds up again on the next US-tech-down day, the
  link "US AI-hardware selloff -> Indian IT CE" earns its second episode; it becomes PROVEN only under the SECTOR_LINKS rule
  (enough episodes, beats the base rate). Until then the card says "STORY: US AI shock -> Indian IT up (1 episode, NOT PROVEN)".
- **Same story, banks leg (20 Nov close):** BANKNIFTY +2.49% to a record 64,635 (low ~62,599). Ranked causes (desk, sources): FII money
  out of AI-heavy Asia (Kospi / Taiwan -6-7%) into Indian banks - financials took Rs 43,102 cr of FII money in the first half of
  November (BS 13:55), "FIIs buying back the banks they sold to fund the AI trade" (Geojit); private-bank earnings upgrades (Motilal:
  ~22% a year FY26-28) and IndusInd's Q2 turnaround (+8.6%, best day since Feb 2021); rate-hike margin argument (judgement only);
  expiry short covering NOT confirmed (no 20 Nov OI found). Against: RSI extreme, breadth 1,582 up / 2,456 down, VIX +8%, month +16-17%
  (biggest since Nov 2020). Measure: next 1 / 2 / 5 days, and whether 62,600-63,000 holds on Mon 23 Nov (expiry).

## H. STORY OPENED 20 Nov 2026 (the trader's photo, 19:42): "Remove STT on the cash market?" - Anand Rathi's pitch, CII Summit 2026
- What it is: an OPINION by a broker group's founder at an industry summit (Business Today clip), not a government proposal.
  POLICY CLOCK: not even PENDING - a pre-budget wish (Union Budget due Feb 2027). Self-interest: brokers gain if it happens.
- If it ever moved up the clock (Finance Ministry / budget signal): CE side - brokers and market infrastructure (ANGELONE,
  MOTILALOFS, ANANDRATHI, 360ONE, BSE, CDSL, CAMS, KFINTECH - check each is in F&O that day); no clear PE side (government revenue,
  not a listed company). Past episodes: STT / LTCG changes moved capital-market shares on budget day itself, not on summit talk.
- Desk handling: THEME card, WATCH, strength 1, horizon = budget; never a BUY NOW on a speech (no lone voice, OPINION grade).
  Note: ANANDRATHI was already overbought (RSI 70.6) in the 19 Nov scan. Re-score if any official line follows.
- **The whole CII Financing Summit 2026 (CII-DFS, Mumbai, 19-20 Nov; ended 20 Nov) - desk read:** the one real trigger to watch is
  SEBI's FPI consultation paper ("very soon"; FPI KYC review moves to every 2 / 8 years from 1 Dec; 5-day onboarding; SEBI-RBI
  common form) - if it lands: CE tilt CDSL, BSE, CAMS, KFINTECH, HDFCAMC; banks / NIFTY indirectly via FPI flows. Opinion only:
  the STT pitch, CEA Nageswaran's warning on F&O speculation (93% of individual F&O traders lost money - small PE tilt on BSE /
  ANGELONE toward the Budget), DIPAM, SEBI WTM Murty, NHB. IRDAI: two working groups in ~10 days (watch PBFINTECH / ICICIGI).
  Bank of Maharashtra: up to US$175 mn overseas borrowing by 31 Dec (MAHABANK is in the F&O list - the analyst's "not in F&O" was
  wrong). "AIF exits easier" was NOT confirmed by any report. Nothing is a Monday trigger; do not chase CE on the speeches.

## I. RBI MPC 4 Dec 2026 - desk pre-read (20 Nov evening; facts from search results, re-check before the day)
- Set-up: 7 Oct hike to 5.50% (first since Feb 2023), stance "calibrated tightening", Governor: only "hike or pause". October CPI 6.09%
  (above the 6% band top; food 8.94%), WPI 12.29%. 10y about 7.34% (7.25% on 7 Oct). Liquidity in surplus (SDF use ~Rs 1.55 lakh cr,
  13 Nov). Rupee ~94.2. Brent ~$92.6 (from >$104 on 8 Oct). Credit 19.3% vs deposits 16.8%. Q2 NIMs fell at HDFCBANK / ICICIBANK /
  AXISBANK; SBIN NIM up. Repo-linked loans: private ~89%, PSU ~51%. Polls lean to a 25 bp hike in December.
- Scenarios (opinion): plain 25 bp hike ~55% (mostly priced: dip then recover, NO TRADE on the day); hawkish hold ~30%; hold + liquidity
  / softer tone ~8% (CE PNB, AUBANK, BANKBARODA next day, row 27); surprise ~7% (50 bp -> PE GODREJPROP, DLF, BAJFINANCE, CHOLAFIN; a cut
  = trouble, C18).
- Over 1-4 weeks after a hike: repo-linked private / small banks gain margin (KOTAKBANK, AUBANK, IDFCFIRSTB, BANDHANBNK, ICICIBANK,
  HDFCBANK), SBIN over weeks; NBFC / HFC and realty lose; non-SBIN PSU banks soft on bond losses.
- Rules: no position before 10:00; enter 10:15-10:30 only with price agreement; 12:00 press conference can flip it; IV falls after the
  release - do not buy on 3 Dec to hold into it. Bank Nifty is stretched (+~13% in Nov): pullback entries only (desk judgement; A6c's
  81% count is measured on shares, not the index).
- Watch: 30 Nov GDP (strong = hike more likely), daily liquidity / call rate, 10y (7.45% hawkish line, 7.15% dovish), Brent > $100,
  rupee 95, FX reserves 27 Nov / 4 Dec; then Fed 10 Dec 00:30 IST and CPI 14 Dec. Follow-up: score each scenario line on 4 Dec.

## J. 20 Nov 2026 - two knowable stories the desk's rehearsal missed (lesson for the head and seats 7, 8, 19, 20)
- GOLD at a 2026 low BEFORE the open (spot about -1.9% by 08:27 IST; MCX gold later -4.7%, silver -6.3%): the whole gold-linked group
  fell all day - KALYANKJIL (about -5.8% at the low, -3.37% close), IIFL FINANCE, MCX (-3.02%), MUTHOOTFIN (-2.58%), TITAN, MANAPPURAM.
  A PE group, valid even on an up day (whole-sector move + news). Watch first at the 07:15 / 09:08 briefs.
- FII money into banks + Bank Nifty record: the CE leaders were PRIVATE banks (INDUSINDBK about +10%, AXISBANK +5%, HDFCBANK +2.7%);
  PSU banks were flat to soft (BANKBARODA +0.38%, PNB +0.31%). Rule B11: flow news -> private names first; policy news -> PSU names.
- Follow-up: score whether the 09:08 brief names these on a re-run (DESK_REVIEW 21 Nov 01:35).

## K. Fri 20 Nov 2026 US close - a second, bigger AI sell-off day (for the Sunday 19:45 and Monday 07:15 / 09:08 briefs)
- US close Fri 20 Nov (trader's app, 16:30 EST): S&P 500 6,974.97 (-3.11%), Nasdaq Composite 22,796.78 (-4.67%), Dow 48,444.77 (-1.41%);
  NYSE breadth 398 up / 1,924 down. Cause NOT confirmed by a source yet (AI / chip valuation again is the likely story: Thu 19 Nov
  S&P about -2%, Nasdaq about -2.3%, AMD about -10%; 5 Nov Nasdaq-100 -6.36% on AI data-centre doubts).
- The one past episode this week (section G): after Thursday's US AI fall, India on Fri 20 Nov opened lower (NIFTY about -0.66%), then
  money rotated INTO India - private banks led, Bank Nifty a record, IT / ER&D ROSE. The desk's "IT PE" call that night was WRONG.
  n = 1 - NOT PROVEN; a -4.7% Nasdaq day plus a weekend is bigger than that episode.
- Monday 23 Nov is EXPIRY (stocks: December strikes; NIFTY: next weekly) and Tuesday 24 Nov is a holiday.
- Watch before deciding: US futures (open Sunday evening US time), KOSPI / Taiwan at their Monday open, GIFT NIFTY from about 06:30 IST,
  the FII figure for 20 Nov, morning TV. The briefs decide; no pre-set side. Two-thirds of moves start at 09:15 - wait for 09:20.
- **K update 21 Nov 08:00 IST - the desk's read (search-result text; sources in DESK_REVIEW / chat):**
  - Wire closes (AP / UPI / CNBC): S&P 6,910.39 (-3.70%), Nasdaq 22,617.73 (-5.28%), Dow 48,147.33 (-1.93%); Nasdaq-100 -5.6% (about
    -19.8% from high); SOX -10.7%. S&P 7 straight down days, -8.6% on the week. (The trader's app showed CFD prices at 16:30 EST.)
  - Causes reported: (1) Reuters: SEC staff examining Nvidia's accounting - NVDA about -14% (10-Q already delayed; board probe);
    (2) Anthropic IPO (listed 19 Nov) sold off about 9-13% on day 2; (3) Fed December hike odds high after hot CPI; (4) Nvidia CEO
    exit (12 Nov) + chip export licence rules, AMD short report; (5) Trump threat of a tax on AI data centres built abroad.
  - Cross-asset: US 10y about 4.93% (down), VIX 30-40, gold about -2.8% (-9% on the week, not a haven), copper worst week since Apr
    2025, oil soft. Asia Fri: Taiex -6.2%, KOSPI -5.2%, Nikkei about -5% - while India ROSE (+1.1%, Bank Nifty +2.49%) = rotation into India.
  - Rotation read (rallyscan to 19 Nov): PSU banks EXTREME (avg RSI 78.3; PNB 87.7, SBIN 82.9, MAHABANK 80.2); private banks stretched,
    not EXTREME on 19 Nov; but NSDL: financials took Rs 43,102 cr of the record Rs 84,291 cr FPI buying in 1H Nov. Laggard
    destinations ranked: insurers / NBFC (HDFCLIFE, SBILIFE, SHRIRAMFIN), capital goods & defence (BEL, HAL, BHEL), auto ancillaries
    (MOTHERSON, BOSCHLTD), power utilities / telecom (NTPC, POWERGRID, INDUSTOWER); defensives (FMCG, pharma) if FIIs turn sellers.
  - PE candidates: semis / EMS (DIXON, KAYNES, CGPOWER), power T&D data-centre trade (GVT&D, CGPOWER), ER&D / mid IT that ran on
    20 Nov (PERSISTENT, TATAELXSI, COFORGE), metals (HINDALCO, VEDL, HINDCOPPER, NATIONALUM), gold lenders (MUTHOOTFIN, MANAPPURAM).
    IT majors mixed. All NOT PROVEN; Monday's GIFT NIFTY, KOSPI / Taiwan open, the 20 Nov FII figure and 09:20 sector VWAP decide.
- **K financials 21 Nov 08:40 IST:** INDUSINDBK +8.59% on 20 Nov (biggest day in 5+ years, above Rs 1,000, OI +15.7%): reported drivers =
  foreign-fund roadshows (Morgan Stanley Singapore 18-19 Nov, CLSA Chennai 19 Nov, exchange filing) + bank-sector traction + a better
  Q2 FY27. A "loan recovery" story (trader's read) NOT found in sources - ask the trader for his source. Insurers ranked HDFCLIFE (Oct
  individual business +16%, -26.8% from high), SBILIFE, ICICIGI; insurance = catch-up idea, no trigger yet. Laggard private banks:
  AUBANK, BANDHANBNK, RBLBANK. RBI hike (4 Dec) hurts NBFC / HFC (CHOLAFIN, BAJFINANCE, SHRIRAMFIN, LICHSGFIN). NOT PROVEN.
