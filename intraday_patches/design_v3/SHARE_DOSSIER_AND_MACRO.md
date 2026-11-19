# GIR - THE SHARE DOSSIER AND THE MACRO / GLOBAL LAYER (everything beyond Kite's live prices and OI)

Written 18 Nov 2026 by the equity-research data architect. Built ONLY from finished work, nothing invented:
- data_team/: COLLECTION_PLAN.md (job ids J01-J85, recorders R1-R25, gaps 6.1, costs 7), map_exchanges_regulators.md (rows 1.x-18.x),
  map_brokers_vendors.md, map_global_markets.md (M1-M20, driver table s5), map_news_media.md, map_alternative_industry.md;
- design/v2/: DATA.md (D1-D76), IA.md (P8 Share page, P14 Calendar, P15 World, P17 Reference), the vision_*.md files (share-page
  dossiers), ideas_india.md (where a vision or map points to it);
- intraday_patches/GIR_SPEC.md: THE DATA LIST #1-#49, EXTERNAL DATA E1-E6 (E4 share history), S1, S7, method 1.1-1.9.

Anything the sources themselves mark unconfirmed stays **[verify]**. Nothing here has been fetched from the server; the spec's DATA LIST
"GIR status" column (HAS / PARTLY / MISSING) is still blank, so every "HAS" below is what the maps read from the code [verify on server].

## 0. How to read the tables

**Status** (what GIR does with the field):

| Code | Meaning |
|---|---|
| HAS | collected today (as the maps read the code) [verify on server] |
| W1 | planned for the trial week 19-25 Nov (COLLECTION_PLAN s9 phase 1; back-end only, no page change) |
| W2-4 | planned for weeks 2-4 (26 Nov - mid Dec, phase 2) |
| M2+ | month 2 or later, or only when a paid-item trigger fires (plan s7.2) |
| KB | GIR knowledge base: monthly refresh, batch / manual (spec S10: "share histories (E4) - monthly refresh, top model, batch") |
| CAL | calendar line only (date + shares in the notes), no data loader |
| REC | GIR records it itself from today - no free history exists (plan s4) |
| NOT PLANNED | a source is named in the maps / ideas, but no job in COLLECTION_PLAN collects it |
| NOISE | the spec (E4, DATA.md s4) says it is never a reason for a call |

**Cost**: FREE (public / official) · PAID-HAVE (Kite Connect, four apps, ~Rs 500 per app per month, ~Rs 2,000 + GST [verify]) ·
PAID-NEW (rough price).

**Decision steps** (plan s0.1): N19 = 19:45 note (night watch list) · N07 = 07:15 note · U08 = 08:45 update · P09 = 09:08 pre-open ·
C09 = sector confirmation from 09:20 · SP = share pick (checklist D) · OG = option gate (checklist E, IV-crush filter) · HX = hold /
exit · SC = 15:45 scorecard · GATE = a failure blocks the share · HIST = history for IV rank, RVOL, baselines, replay.

Where it is stored on the server (plan s0.4): `db/ref.sqlite` (identity, lots, ban, MWPL, corporate actions, name table, sector map),
`db/eod.sqlite` (bhavcopies, delivery, deals, FII / DII), `db/events.sqlite` (results calendar, court hits, USFDA, risk strip),
`db/news.sqlite` (items, filings, policy pipeline), `db/derived.sqlite` (ATR, levels, RVOL baselines, betas, IV rank),
`db/opt.sqlite` (ATM IV, strike snapshots), `db/world.sqlite`, `db/industry.sqlite`.

---------------------------------------------------------------------------------------------------------------------------------

## 1. THE SHARE DOSSIER - per F&O share (~213-220 shares; the list comes from the daily instrument dump, never typed in)

### 1(a) Identity and company profile

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Symbol, ISIN, name, series, listing date, face value | NSE `nsearchives.nseindia.com/content/equities/EQUITY_L.csv` (map 3.15) | monthly name-table refresh (first Saturday); daily for changes | FREE | KB / W1 | key for every join; news tagging (#7) |
| Symbol / name changes | NSE `content/equities/symbolchange.csv`, `namechange.csv` [verify] (3.16); job J64 08:00 | daily 08:00 | FREE | W1 | history adjusted before use (B6.6); old names kept for tagging |
| Brands, parent, subsidiaries, promoters, old names, aliases, ambiguity rules, per-alias precision | GIR name table D7 (NSE + GIR); BSE scrip code mapped via ISIN | monthly + daily alias precision | FREE | KB (exists in part [verify]) | tags filings, news, court cause lists (J30) and policy items to the share |
| Sector(s) with weights, versioned with effective dates | GIR sector map D6, built from niftyindices constituent CSVs `niftyindices.com/IndexConstituent/ind_nifty<sector>list.csv` (5.1: members, industry, ISIN) | weekly check, monthly refresh, edits only outside market hours | FREE | KB (knowledge.py exists; weights / versions planned D6) | spec 1.1-1.3: driver -> sector -> EVERY F&O share in it; sector confirmation C09 |
| Industry / sub-industry | niftyindices CSV "industry" column; GIR custom sectors (jewellers, gold loans, cables & wires, OMCs, capital-market stocks, PSU banks, defence ...) | weekly / monthly | FREE | KB | finer sub-industry classification is not named in any map [verify if needed] |
| Weight in its sector index (leader vs laggard) | niftyindices monthly factsheets PDF (5.2) | monthly | FREE | NOT PLANNED as a loader | equal-weight vs index (heavyweight trap, checklist C); leader / laggard role |
| Index memberships (Nifty 50, Bank Nifty, sector, thematic, Sensex, Bankex) | niftyindices CSVs (5.1); BSE Index Services `bseindices.com` [verify] (5.5) | weekly | FREE | KB | Nifty Tuesday / Sensex Thursday expiry distortion of heavyweights (ideas_india #14, "after") |
| Business group / theme basket (Adani, Tata, Bajaj, Vedanta, Reliance; PSU defence, PSU rail, PSU financiers, new-age internet, capital-market plays, EMS, CGD) | KB table of company names; promoter group from NSE shareholding filings "promoter and promoter group" (ideas_india #2) | monthly; filtered daily by the F&O list | FREE | NOT PLANNED (idea, TRIAL-OK) | group headline -> every member; basket treated like a sector (breadth, VWAP, build-up) |
| PSU status | government holding in the shareholding pattern (ideas_india #2); E4.12 red flag | quarterly | FREE | KB | PSU baskets; OFS drag toward the floor price (E3); red-flag card |
| Size (large / mid / small cap) | AMFI market-cap categorisation `amfiindia.com` (12.6), half-yearly Jan / Jul | half-yearly | FREE | CAL (ADVANCED) | spec 1.3 "size"; recategorisation shifts fund flows |
| Business description, products, segments | annual reports / investor presentations via filings (4.14); Screener; Tijori segment KPIs (paid, manual) | monthly batch | FREE / Tijori ~Rs 2-3k / yr [verify] | KB (ADVANCED) | sizing news (order value vs revenue); building the driver map |
| Drivers (what moves it; revenue driver vs cost driver - copper is a COST for cables) | D6 sector map + driver table (map_global_markets s5); measured sensitivities later (D58 A, E2) | monthly; measured after 6-12 months | FREE | KB now; measured M2+ | Q1-Q2 of the funnel: which drivers moved -> which shares |
| Domestic peers | members of the same GIR sector / basket (spec 1.3); results-sympathy peers (S8.6; IA P14 "peers with results > 5 days away") | with the sector map | FREE | KB | rank every share in the sector; sympathy trade after a leader's results |
| F&O membership, F&O since, inclusion / exclusion | NSE underlying list page (1.4); FAOP circulars (1.7) via J63 08:00-08:40 | daily | FREE | W1 | GATE; E4.8 history; HX (exits) |
| Lot size, tick size, strike list / interval | Kite instrument dump `api.kite.trade/instruments` (J62) + `NSE_FO_contract_DDMMYYYY.csv.gz` [verify name] + `content/fo/fo_mktlots.csv` (J63); lot revisions (1.8) | daily 08:00-08:45; dumps kept forever (R4) | PAID-HAVE / FREE | HAS (dump) / W1 (reconcile) | GATE: Kite vs NSE mismatch blocks the share; quantity on the plan card |
| Expiries, sessions and trading minutes left | NSE contract master + holiday master `/api/holiday-master?type=trading` (D2, 1.5) - never computed | daily | FREE | W1 | theta, expiry-week mode, physical-settlement warning (S7.3). Conflict: plan says stock expiry 24 Nov; DATA.md / research vision say Mon 23 Nov (holiday-shifted) [verify from the contract master] |
| Ban, MWPL %, near-ban, exits-ban | `archives/fo/sec_ban/fo_secban_DDMMYYYY.csv` (date = T+1, J17 18:00-20:30); `archives/nsccl/mwpl/combineoi_DDMMYYYY.zip` (J18, 2025 FutEq columns [verify]); live estimate J80 every 5 min for names >= 70% | evening + 08:45 + 5 min live | FREE | W1 (files) / W2-4 (live estimate) | GATE: > 85% no new calls, >= 95% ban (only reduce), exit < 80% = squeeze risk (vision_oi-analyst 2.5) |
| Surveillance stage (ASM / GSM / ESM) | NSE `/api/reportASM`, `/api/reportGSM` [verify] (3.10) | daily | FREE | NOT PLANNED (ADVANCED) | higher margins after spikes |
| FPI headroom vs sectoral cap | NSDL / CDSL FPI Monitor (5.7, 12.3) | daily | FREE | NOT PLANNED (ADVANCED) | caps MSCI weight (banks, insurance, defence) |

### 1(b) Fundamentals and results

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Next results date and board-meeting purpose (results, fund raise, dividend, buyback, split / bonus) | NSE `/api/corporate-board-meetings?index=equities`, `/api/event-calendar`; BSE `corporates/Forth_Results.aspx` / `api/Corpforthresults/w` [verify]; NSE `Board_Meetings.xml` RSS (4.3) - job J31 19:35 | daily 19:35 (+ every 15 min in D48) | FREE | W1 (22-23 Nov) | OG results gate: never buy options INTO results (IV crush, E5); N19 "due tomorrow"; LODR gives >= 2 working days' notice |
| Results timing (before / during / after market) and announced-vs-actual time | board-meeting notice + filing time; R14 records both per filing | per result | FREE | REC | after-15:30 results = day still tradable intraday; in-session results = event lock (ideas_india #4). NSE calendar often lacks the time of day |
| Results numbers: revenue, EBITDA / operating profit, PAT, EPS, standalone / consolidated | NSE / BSE announcement (J60, 3-5 s) + PDF; XBRL `nsearchives.nseindia.com/corporate/xbrl/...xml`; NSE `/api/corporates-financial-results?period=Quarterly`, `/api/results-comparision?symbol=X`; BSE `Comp_Resultsnew.aspx` (4.4) | seconds after filing | FREE | HAS (filing, ~3 min today) / W1 (3-5 s) / W2-4 (XBRL parse) | SP / HX: "PAT +x% YoY" in seconds without OCR |
| Consensus estimates | CNBC-TV18 results poll (day before / morning); ET Now poll; NDTV Profit "vs Bloomberg estimate" lines - all via the news feeds; Trendlyne Forecaster; Moneycontrol estimates tab; MarketScreener; broker preview PDFs (brokers map s7) | per result | FREE (polls) / Trendlyne paid [verify price] | REC R13 from the next results season (mid-Jan); Trendlyne NOT PLANNED | surprise score = what the market reacts to; "habitually misses" tag (E4.11). No free Indian consensus API exists |
| Results reaction (gap, direction vs surprise, day-1 range, day-2 drift; IV build-up and crush) | GIR from bars + R13 + ATM IV (R1); seeded from Dhan expired-options history (J39) | per result | FREE / Dhan Rs 499 / mo | REC + W2-4 seed | E4.3 table on the Share page; IV-crush filter (S8) |
| Guidance and management commentary | con-call schedule (filing category "Analysts / Institutional Investor Meet / Con. Call Updates", 4.11); transcripts on IR pages (LODR: audio 24 h, transcript 5 working days), Trendlyne / Screener / Tijori collections; TV management statements (CNBC-TV18 STT) | per event | FREE | con-call schedule W2-4; TV STT HAS; live con-call listener NOT PLANNED (ideas_india #15) | an in-session con-call = event risk (OG); denials / clarifications (HX); E4.11 tag |
| Monthly / quarterly operating numbers (auto sales on the 1st, Coal India, NMDC, IEX, Adani Ports, Angel One, insurance premiums, AMFI flows, quarter-start business updates) | company filings via J60 + calendar rows (plan 1I) + expectation series (VAHAN J37 / J56, MoCA, IEX) | monthly / quarterly | FREE | W1 (VAHAN by 30 Nov) / CAL | surprise vs expectation (alt map s2); never buy into the release, trade the reaction after 5-15 min |
| Multi-year P&L, balance sheet, cash flow, ratios, margin and debt history | Screener.in `screener.in/company/SYMBOL/` - Excel export per company (logged in), no API; scraping discouraged | monthly, manual | FREE / Premium ~Rs 4,999 / yr [verify] | KB (manual); no scheduled job | context and E4 red flags only - not an intraday trigger (E4: "Screener + NSE cover about 95%") |
| Segment / operating KPIs (volumes, realisations, store counts) | Tijori Finance `tijorifinance.com` (no API) | quarterly, manual | ~Rs 2-3k / yr [verify] | NOT PLANNED as a job | building the sector -> driver map (#6) |
| Latest-quarter margins | computed from XBRL at filing (operating profit / revenue) | per result | FREE | W2-4 | results read in SP / HX |
| Debt and credit quality | Screener balance sheet; rating actions on CRISIL `crisilratings.com`, ICRA `icra.in`, CARE `careratings.com`, India Ratings `indiaratings.co.in` (agency site often first; filing within 24 h) (4.10); MCA21 charges (4.15) | per event | FREE | rating via J60 classifier category W1; agency sites NOT PLANNED (ADVANCED); MCA NOT PLANNED | NBFC downgrades move the share (watch list) |
| Export / FX / commodity sensitivity | D6 revenue-vs-cost driver flags; driver table (global map s5: rupee weak -> IT, pharma up; OMCs, INDIGO down ...); pharma plant -> US-revenue table from annual reports (one-time) | monthly; table one-time | FREE | KB; plant table W2-4 (with USFDA watcher); measured sensitivity matrix M2+ | which shares a driver move hits and how hard; n < 30 shown as "rule of thumb" |
| Order wins sized by company | filing text (order value) / trailing revenue and market cap (D34), "new vs routine" | per filing | FREE | W2-4 | checklist D7: a 3-6% order vs noise |
| Tax demands, auditor exits, plant shutdowns, fund-raise | filing categories via the J60 classifier (order win, clarification / denial, USFDA, tax demand, OFS / QIP, rating, results) | per filing | FREE | W1 | SP / HX direction |
| Annual reports, investor presentations | filings (4.14), company IR pages | yearly / quarterly | FREE | KB (ADVANCED) | knowledge base, not live |

### 1(c) Ownership and investments

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Shareholding pattern (promoter / FII / DII / public %, promoter-group names) | NSE `/api/corporate-share-holdings-master?index=equities`; XBRL per filing; BSE shareholding pages (4.6); filed within 21 days of quarter end | quarterly (by the 21st) | FREE | CAL only (plan 1I "shareholding / pledge by the 21st"); no loader | baskets, PSU status, FPI headroom. E4: quarterly changes are NOISE for intraday |
| Promoter pledge / encumbrance (SAST Reg 31) | NSE `/api/corporate-pledgedata?index=equities` [verify]; filings "Disclosure of encumbrance" (4.1); BSE "Pledge" section; Screener shows pledge | as filed (within 2 trading days) | FREE | D32 "as filed" in DATA.md; arrives via J60 filings; no dedicated job, not in the J60 classifier list [verify] | red flag E4.12: pledge > 25% or rising; invocation = sharp fall |
| Insider trades (SEBI PIT Reg 7: promoter / director buys, sells, mode) | NSE `/api/corporates-pit?index=equities&from_date=&to_date=`; BSE `corporates/Insider_Trading_new.aspx` (4.8) | same day | FREE | NOT PLANNED (map tier USEFUL) | promoter open-market buying = watch-list input (N19) |
| Substantial acquisitions (SAST Reg 29: crossing 5%, every 2%) | NSE `/api/corporate-sast-reg29?index=equities` [verify]; BSE SAST page (4.9) | as filed | FREE | D32 lists SAST; no job | stake builds, open-offer triggers (N19) |
| FII / DII holding per share | only through the quarterly shareholding pattern (above) | quarterly | FREE | CAL | NOISE intraday |
| FII / DII cash flow (market level, not per share) | NSE `/api/fiidiiTradeReact` (J15 17:30-19:00); NSDL FPI daily `fpi.nsdl.co.in/web/Reports/Latest.aspx` (J66 08:30); NSDL fortnightly sector-wise FPI (12.2) | daily / fortnightly | FREE | HAS (confirm) / W1 / CAL | N19 context, top bar; never a reason (DATA.md s4) |
| Mutual-fund holdings | AMC monthly portfolio disclosures on each AMC site, by the 10th (12.7) | monthly | FREE | NOT PLANNED - NOISE (E4) | - |
| Mutual-fund flows (AMFI) | `amfiindia.com/research-information/amfi-monthly` ~8th-10th (12.5) | monthly | FREE | CAL | only for AMC / registrar shares (HDFCAMC, NAM-INDIA, CAMS, KFINTECH [verify F&O]) |
| Bulk deals | `nsearchives.nseindia.com/content/equities/bulk.csv`; JSON `/api/snapshot-capital-market-largedeal`; BSE `bulk_deals.aspx` (3.4, 7.3) - J14 | daily 17:00-18:30 | FREE | W1 | N19 watch list only; never a call on its own (H) |
| Block deals, both windows | `content/equities/block.csv` + large-deal JSON; live windows 08:45-09:00 (J69, every 60 s) and 14:05-14:20 (J82); +-3% band, min Rs 25 crore since ~7 Dec 2025 (SEBI 8 Oct 2025, NSE CMTR71394) [verify] | live in window + EOD | FREE | W1 (REC R21 - window board is live-only) | P09: a big discounted block before the pre-open is a 09:08 input; HX in the afternoon window |
| Short-selling disclosure | large-deal JSON short-selling tab; `content/equities/shortselling/...` [verify] (3.6) | daily | FREE | W2-4 (plan 6.1 #22) | short-pressure / squeeze risk (ideas_india #10) |
| SLB borrow fee, open positions | NSE SLBM bhavcopy "All Reports - SLB" [verify] (3.7) | daily | FREE | W2-4 | rising borrow fee = shorts under pressure around results / expiry |
| Margin-trading (MTF) funded quantity | `content/equities/mrg_trading_DDMMYY.zip` [verify] (3.8) | T+1 | FREE | W2-4 (ADVANCED) | leveraged retail longs = forced-selling risk |
| OFS (floor price, size, non-retail day T, retail T+1) | NSE `market-data/offer-for-sale` [verify] (3.17); seller's notice filed T-1 after 17:00; DIPAM `dipam.gov.in`, X @SecyDIPAM (13.8) | per event | FREE | W1 (J60 classifier OFS / QIP; DIPAM page in J25) | PSU falls toward the floor (E3); floor = a level for stop / target (ideas_india #6) |
| QIP (floor price) | filing after the close; NSE `/api/ipo-current-issue`, `/api/all-upcoming-issues` [verify] (3.18) | per event | FREE | W1 (classifier) | QIP floor is a magnet |
| Block term-sheet leaks ("X to sell 3%, floor Rs Y") | news feed tagged by name table + keywords (ideas_india #6) | evening before | FREE | NOT PLANNED as the "supply table"; stories arrive UNVERIFIED in news | 07:15 line "BLOCK 08:45 - size, floor, x ADV"; VERIFIED only after the print |
| Lock-in expiries (anchor 30 / 90 days, pre-IPO 6 months) | IPO RHP / allotment date, entered once per IPO (ideas_india #6) | per IPO | FREE | NOT PLANNED | supply overhang on new-age F&O names |
| Index inclusion / exclusion / reweighting | niftyindices `press-release` (5.3), NSE circulars (J63); BSE indices (5.5); MSCI / FTSE announcements ~03:30-04:30 IST (J46 on review nights) (5.6) | per review | FREE | W1 (circulars) / CAL | E5: exit index-rebalance shares by 14:45 on the effective day; passive-flow estimates only from broker notes |
| Delivery % vs 20-day | `products/content/sec_bhavdata_full_DDMMYYYY.csv` (J19 18:00-20:00); MTO backup (3.3) | daily | FREE | HAS (confirm) | N19 context only - never a reason alone |

### 1(d) Corporate actions and calendar

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Dividends, splits, bonuses, rights, buybacks: ex-date, record date, purpose | NSE `/api/corporates-corporateActions?index=equities` (+ `Corporate_action.xml` RSS); BSE `corporates/corporates_act.html` (4.5) - J64 08:00 "effective today"; J35 20:00-21:00 "effective T+1" | daily | FREE | W1 | GATE; history adjusted before use (B6.6); ex-dates distort gaps and basis (`DIV` flag - basis not read as sentiment) |
| F&O contract adjustments (new strikes, lots, symbols after split / bonus / special dividend / demerger) | NSE FAOP circulars "Adjustment of Futures and Options contracts in the security X", 1-5 days before ex-date (1.9) - J63 | per event | FREE | W1 | without it the chain looks broken on ex-date; strike / OI history jumps |
| Demergers and symbol successions (e.g. TMPV ex-TATAMOTORS since 24 Oct 2025, per global map) | FAOP circulars + `symbolchange.csv` | per event | FREE | W1 | history joined across the change |
| Board meetings (all purposes) | as 1(b) results calendar (4.3), J31 | daily | FREE | W1 | buyback / split / fund-raise on the calendar |
| AGM, postal-ballot results, trading-window closure | filing categories (4.13) | per event | FREE | NOT PLANNED - NOISE (E4: AGMs) | occasionally a merger / RPT vote |
| Con-call dates and times | filings (4.11) + Trendlyne / Moneycontrol calendars | per event | FREE | W2-4 | in-session call = event risk |
| Monthly / quarterly drumbeat dates (auto sales 1st, Q-start updates 1st-10th, insurance ~7th-15th, AMFI ~8th-10th) | plan section 1I, alt map 3.17 | monthly | FREE | CAL (W1 for 1 Dec auto sales) | N19 "due tomorrow" line; SP after the filing |
| Derivatives calendar per share (expiries with holiday reasons, new series, lot revisions, F&O add / drop, ex-dates inside a series, ban entries / exits) | D2-D5 (contract master, circulars, ban files) shown on IA P14 | daily | FREE | W1 | expiry-week mode from the Wednesday before; "prefer next month" in the last 5-7 sessions |
| Today's risk strip (results today in / after market, ex-dates, ban, court hits, industry releases) | J65 08:30 from J28, J31, J17, J63, J30 | daily 08:30 | FREE | W1 | sector / share entry locks (E5) |

### 1(e) Technical history

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Daily OHLC, volume, value, trades (official close) | NSE CM bhavcopy UDiFF `content/cm/BhavCopy_NSE_CM_0_0_0_YYYYMMDD_F_0000.csv.zip` (J13, 17:00 until present); BSE UDiFF backup | daily | FREE | HAS | levels (#22), ATR (#21), gaps; official close = 15:00-15:30 VWAP (record both) |
| 1-minute candles (several years) | Kite historical API (K4, 3 req/s): 2-year bootstrap at night (brokers 9.3); daily reconciliation vs tick-built bars J03 15:35-16:05 | daily + one-time back-fill | PAID-HAVE | W1 | RVOL baselines, opening range, back-tests |
| Raw tick frames (replay) | Kite websocket frames + Upstox frames (R3), 90 days on server then archived | live | PAID-HAVE / FREE | W1 | exact replay of any day (B7) |
| ATR14, prev-day H / L / C, 20-day H / L, weekly H / L | GIR nightly derived job J38 22:00-23:30 -> `derived.sqlite` | nightly | FREE | W1 | range used (< 0.6 ATR = room, > 1.2 = skip), room to the next level >= 0.3 ATR (checklist D) |
| RVOL baselines by minute of day (20 days) | J38 from own bars; proxy for first 20 days = bhavcopy volume x the share's minute profile (D13) | nightly | FREE | W1 | RVOL > 1.5 valid, > 2.5 strong |
| Relative strength vs sector and NIFTY; ranks; role LEADER / FOLLOWER / LAGGARD / DIVERGENT | live from Kite ticks (J76, D19); 1-min snapshots recorded | live; history recorded | PAID-HAVE | W1 | the share pick (Q5); laggard only with breadth >= 70% and before 13:00 (D8) |
| Leader / laggard record vs sector | D58 from recordings | monthly (KB batch) | FREE | KB / REC | E4.5; rank leader-on-pullback first (research vision) |
| Sector betas, equal-weight sector series | J38; NSE index closes `content/indices/ind_close_all_DDMMYYYY.csv` (J12); niftyindices historical back-fill (5.4) | nightly | FREE | W1 | speed (beta) in spec 1.3; GIR sector % vs official index cross-check |
| Gap-fill rate by gap size; day after a 3%+ move; expiry-week behaviour | D58 from bhavcopy + bars | monthly | FREE | KB | E4.6, E4.7, E4.10 on the Share page (with n) |
| Pre-open series (cash IEP, futures pre-open since 8 Dec 2025, buy / sell imbalance) | Kite FULL quotes + NSE `/api/market-data-pre-open?key=FO` (J72, every 30 s 09:00-09:08) | daily | FREE / PAID-HAVE | W1 (REC R5) | 09:08 gap check vs the night's view; "unusual" needs history |
| ATM IV per share (CE / PE / straddle mid), daily close value; IV rank / percentile; IV vs 20-day; near vs next term | GIR Black-76 on the same-expiry future (J77) recorded per minute (R1); daily value J38; back-fill ~2 years from NSE F&O bhavcopy settle prices, labelled "from closes" (D23); Dhan Expired Options Data API + ICICI Breeze spot checks (J39) | minute + daily | FREE / Dhan Rs 499 / mo + GST | REC W1; seed W2-4 | OG: IV rank < ~50; IV-crush filter (S8); never LTP-based IV |
| Realised volatility RV10 / RV20, IV / RV; NSE daily volatility | J38; `archives/nsccl/volt/FOVOLT_DDMMYYYY.csv` [verify path] (J22) | daily | FREE | W1 | is premium cheap vs realised vol (OG) |
| Spread %, depth, contracts traded by strike at 09:30 / 12:00 / 14:30 | GIR snapshots J78 (R2) | 3 times a day | FREE | REC W1 | E4.4 liquidity history - sold by nobody at retail |
| Results reactions | see 1(b) | per result | FREE | REC | E4.3 |
| Measured driver -> share sensitivity (next-day gap beta, hit rate, n) | GIR regressions (E2, D58 advanced, IA P15) | monthly from month 2; meaningful after 6-12 months | FREE | M2+ | replaces rule-of-thumb thresholds |
| Manual IV-history sanity check | Opstra, Sensibull (no API; automated pulls break terms) | weekly audit | FREE / ~Rs 400-1,300 / mo [verify] | manual | check GIR's IV rank until its own history is long |

### 1(f) Derivatives history

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Close, settle, OI, volume per contract (futures + options) | NSE F&O bhavcopy UDiFF `content/fo/BhavCopy_NSE_FO_0_0_0_YYYYMMDD_F_0000.csv.zip` (J16 17:30-19:30); 2-3 year archive back-fill (D31) | daily | FREE | W1 (+ back-fill) | start-of-day OI baseline (mismatch with Kite blocks the share), rollover history, IV back-fill |
| Futures OI all months, per minute; build-up tag LB / SB / SC / LU per month and combined; ROLL tag in expiry week | Kite FULL ticks (J76) recorded (R9) | minute | PAID-HAVE | REC W1 | sector confirmation (build-up in several shares across all months); share pick |
| Rollover %, vs the same T-n average of the last 3 expiries; roll cost vs fair carry; basis and excess basis | D59 from Kite + stored bhavcopies; 91-day T-bill rate (RBI / CCIL weekly) | live / weekly | FREE | W1 | context for the next-month trade, not a trigger (vision_oi-analyst 2.3-2.4) |
| Ban and MWPL history; intraday FutEq estimate | J17, J18, J80 recorded (R19) | daily + 5 min | FREE | REC W1 / W2-4 | E4.8; ban-entry / ban-exit predictor (ideas_india #3) |
| Option OI by strike, OI walls (WALL BUILDING / WEAKENING) | K3 FULL chains + REST `/quote` OI sweep every 2 min (D14, D24); NSE `/api/option-chain-equities?symbol=X` cross-check (J79, R20) | 1-3 min; snapshots recorded | PAID-HAVE / FREE | W1 / W2-4 (NSE cross-check) | room to the next level; option gate |
| Expired-option intraday history (1-min, IV, OI, ATM-relative strikes) | Dhan Expired Options Data (up to 5 years); ICICI Breeze (free, ~3 years [verify]) (J39) | night batch | Rs 499 / mo + GST; Breeze free | W2-4 | IV rank from week 2 instead of month 3; results-reaction table; back-tests |
| Delivery % vs 20-day | J19 | daily | FREE | HAS (confirm) | context only |
| Participant-wise OI and volume; FII derivatives stats | `content/nsccl/fao_participant_oi_DDMMYYYY.csv`, `_vol_` (J20); `content/fo/fii_stats_DD-Mon-YYYY.xls` (J21) | daily | FREE | W1 | index bias only - never a stock reason |
| Short-sale, SLB, MTF | see 1(c) | daily | FREE | W2-4 | squeeze risk |
| Independent build-up / OI spurts (second opinion) | Angel SmartAPI REST (J83); NSE live-analysis JSON (J84, only if Akamai allows) | 2-3 min / 4 times a day | FREE | W2-4 | trust check of GIR's own build-up |
| Price-band hitters of cash-only theme stocks | `/api/live-analysis-price-band-hitter`, `content/equities/sec_list.csv` (3.9) | live | FREE | NOT PLANNED (ideas_india #7 "after") | early sector confirmation |

### 1(g) News and filings

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Every exchange filing (symbol-tagged, earliest wins) | NSE `/api/corporate-announcements?index=equities` (cookie warm-up); BSE `api.bseindia.com/BseIndiaAPI/api/AnnSubCategoryGetData/w` / `AnnGetData/w`; RSS fallbacks `nsearchives.nseindia.com/content/RSS/Online_announcements.xml`, BSE `notices.xml` [verify] (J60) | 3-5 s in session (NSE and BSE offset ~2 s), 10-15 s evening, 60 s night | FREE | HAS (~3 min) -> W1 (target ~10 s) | fastest share-specific news (S1); unread-filing lock |
| Attachments (PDF) and XBRL numbers | `nsearchives.nseindia.com/corporate/...pdf`, BSE `xml-data/corpfiling/AttachLive/<id>.pdf`; XBRL archive | on arrival, weight >= 3 items | FREE | W1 (PDF) / W2-4 (XBRL) | sizing (value vs TTM revenue / market cap) |
| Filing category (order win, clarification / denial, USFDA, tax demand, OFS / QIP, rating, results) | J60 classifier (small model reads once; code scores) | per filing | FREE (+ AI cost) | W1 | event type -> direction; a denial wakes the "clarification" rule (HX) |
| Exchange clarifications and rumour verification | "Clarification sought" + company replies (4.12); SEBI rumour rule for top 100 / 250 [verify] | per event | FREE | W1 | CLARIFIED / DENIED tag; basket-wide for group stories |
| SEBI orders, circulars, board outcomes | `sebi.gov.in/sebirss.xml`; orders page (10.1-10.4) - J25 RSS 60 s evenings, orders page every 15 min | 60 s / 15 min | FREE | W1 (RSS) / W2-4 (pages) | company / promoter bans; broker / exchange rules move BSE, MCX, CDSL, ANGELONE |
| RBI penalties / licence actions on a bank or NBFC | `rbi.org.in/pressreleases_rss.xml`, `notifications_rss.xml` (11.1, 11.12) | 60 s | FREE | HAS (RSS in GIR) / W1 | bank / NBFC share news |
| CCI, TRAI, CERC, IRDAI, NPPA / CDSCO, DGCA orders | regulator sites, page diff (2C) | 15 min | FREE | W2-4 | sector / share regulation |
| Court and tribunal hearings tomorrow (SC, NCLT, NCLAT, SAT, named HC cases) | `sci.gov.in`, `nclt.gov.in`, `sat.gov.in` cause-list PDFs matched to the name table (J30 19:30, 21:30); LiveLaw / Bar & Bench | nightly | FREE | W2-4 | no premium into a hearing (OG); binary days (IDEA, Adani, telecom, cement) |
| USFDA: warning letters, Import Alert 66-40 firm-list diff, approvals, inspections (OAI / VAI / 483) | fda.gov warning-letter page (posted mostly Tue US time = Tue night IST); `accessdata.fda.gov/cms_ia/importalert_189.html`; openFDA `api.fda.gov/drug/drugsfda.json`; FDA Data Dashboard (weekly) (J40 23:00 and 02:00; Tue 19:30-Wed 03:00 every 30 min) + pharma filing classifier (483, OAI, VAI, EIR, warning letter, import alert) | nightly / per filing | FREE (paid 483 DBs only on audit) | W2-4 | N07 pharma PE / CE watch: OAI / warning letter -3% to -10%; zero observations +1-4% |
| Defence approvals and contracts (MoD, DAC / CCS) | PIB defence releases, `mod.gov.in`, X @SpokespersonMoD (13.11) + order filings scaled by revenue | per event | FREE | W2-4 | HAL, BEL, BDL, MAZDOCK, COCHINSHIP ... 2-6% moves |
| Tender results (CPPP, GeM, IREPS, PFCCL / RECPDCL) | portals (alt map 3.8) | daily | FREE | M2+ (ADVANCED) | night list for rail / power EPC names |
| Wire stories | Reuters news sitemap `reuters.com/arc/outboundfeeds/news-sitemap/?outputType=xml` [verify] (15-20 s); old `feeds.reuters.com` RSS is dead since 2020 and must be removed | 15-20 s | FREE | W1 | scoops ("sources say") tagged UNVERIFIED |
| Publisher news sitemaps and daily live blogs (ET, Moneycontrol, CNBC-TV18, Business Standard, NDTV Profit) | each publisher's news sitemap from robots.txt [verify]; live-blog URLs found daily at 07:00 (J55) | 20-30 s | FREE | W2-4 (section RSS HAS) | follow-ups; "stocks to watch" |
| Second-tier publisher RSS (Mint, FE, BusinessLine, BT, Zee Biz, Trendlyne stock news) | existing RSS list in GIR | 60-120 s | FREE | HAS | coverage |
| TV (management interviews, "sources" scoops, brokerage radar) | CNBC-TV18 speech-to-text (exists); CNBC Awaaz phase 2; RBI / PIB / SEBI pressers auto-started via YouTube channel RSS | live | FREE (local whisper) to Rs 2-8k / mo | HAS (CNBC-TV18) / W2-4 | denials, clarifications; broker calls = context / fade only (H) |
| Push sources | Telegram listener (public outlet / desk channels, own account); spare-phone mirror of outlet app pushes | push | FREE / ~Rs 300 / mo SIM | W2-4 | removes poll-interval delay |
| X (journalists, ministries, squawks) | trader's X Pro lists on a screen; API only after credits and an audit trigger | live | X Premium / API credits | trader-side now; M2+ | T0 for government flashes |
| Business Wire / PR Newswire / SEC EDGAR (ADR names, US partners and customers) | `sec.gov/cgi-bin/browse-edgar?action=getcurrent` (Atom; generic User-Agent contact), Business Wire / PR Newswire RSS | 60 s | FREE | W2-4 | ADR results (INFY, WIT, HDB, IBN, RDY) at T0; partner 8-Ks |
| Broker upgrades / downgrades | TV "brokerage radar" 07:30-09:30, live blogs, Moneycontrol / ET articles | morning | FREE | HAS (TV) | NOISE as a reason: context / fade only (DATA.md s4) |
| Story record per share: one event = one story; source time, first-seen, move-began; source ladder; VERIFIED / UNVERIFIED; event type; direction; impact computed in code; **NEW / PRICED IN (>= 0.7 ATR moved since move-began) / RETOLD / UNEXPLAINED (> 2 sigma move with no story)**; event study +5 / +15 / +30 / +60 min, close, next open | GIR story store D39 (small model proposes type and numbers; code scores) | append-only, live | FREE (+ AI cost) | W1 (classifier) / W2-4 | the news line and "priced-in" tag on every share; scale conflict: S4 materiality 0-3 vs D39 impact 0-5 [verify which] |
| Per-source delay (published_at, first-seen per source, before-the-move flag) | R10, J06 15:35-15:44 | every item | FREE | REC W1 | promote / demote sources; the only honest trigger for a paid wire |
| Google News, GDELT | Google News RSS (backfill only, out of the alert path); GDELT DOC API (geopolitics) | 15-30 min | FREE | HAS (demote) / W2-4 | 15:45 miss audit; geopolitical tone |

### 1(h) Links (drivers, sector chain, global peers / ADRs)

| Field | Source (exact) | Refresh | Cost | Status | How it is used in a decision |
|---|---|---|---|---|---|
| Driver -> sector -> share chain (with direction and revenue vs cost sign) | D6 sector map + global map s5 table, e.g. gold down -> TITAN, KALYANKJIL, MUTHOOTFIN, MANAPPURAM; copper -> HINDCOPPER, HINDALCO, VEDL (up) and KEI, POLYCAB, HAVELLS (cost); Brent up -> ONGC, OIL up / BPCL, HINDPETRO, IOC, INDIGO, paints, tyres down; USD/INR up -> IT, pharma up | monthly | FREE | KB | 19:45 / 07:15 watch lists: every F&O share each moved driver touches (spec 1.7) |
| The share's own driver prices (live, in session) | MCX metals / bullion / energy and CDS USDINR, EURUSD, USDJPY, GBPUSD on Kite K1 C3 (J09) - not subscribed today although paid | live 09:00-23:55 (CDS to 17:00) | PAID-HAVE | W1 (19 Nov) | 09:00 commodity re-check; S8 #8 commodity-lag pattern; E5 USD/INR shock freeze |
| Indian ADRs (INFY, WIT, HDB, IBN, RDY) - ADR premium vs NSE close in INR | Yahoo v8 chart -> Stooq / CNBC (J29, J34, J45, J53; D44) | 19:15, every 5 min 19:45-02:45, 02:35 close | FREE | HAS (morningmkts.py, single source) -> W1 (source chain) | overnight fair value for those shares (+-2% threshold, checklist A) |
| London GDRs (RIGD, SBID, LTOD, MHID, AXB, GAID, TTST [verify which still trade]) | lse.co.uk / londonstockexchange.com delayed | 13:30-22:00 | FREE | NOT PLANNED (ADVANCED) | react to post-close Indian news |
| US / European listed peers per sector: IT - ACN, CTSH, EPAM, GLOB, IGV; pharma - XLV, TEVA, VTRS; metals - FCX, BHP, RIO, VALE, AA, NUE, CLF; autos - Stoxx 600 Autos, VW, Stellantis (-> TMPV / JLR, MOTHERSON, BHARATFORG, SONACOMS); defence - Rheinmetall, BAE; wind / solar - Vestas, FSLR, TAN; banks - XLF, KBE | Yahoo (global map 3.2) | snapshots 19:15 / 07:00 | FREE | ACN / CTSH in J34 (W1); the rest = gap #21 "add to W snapshots" (W1, Yahoo symbols) | read-across to the Indian sector at the open |
| Global peers' results calendar (Accenture ~17:15 IST pre-US-open in Mar / Jun / Sep / Dec; Cognizant, EPAM, Capgemini; JLR; Teva / Viatris / Sandoz; PACCAR / Daimler Truck / Volvo; ArcelorMittal / Nucor; Freeport / BHP / Rio; GE Vernova / Siemens Energy; Apple supply chain; Novo / Lilly) | company IR calendars + free earnings calendars + news (ideas_india #12) | monthly table | FREE | NOT PLANNED as a job (idea, TRIAL-OK) | 19:45 line "Accenture tonight - IT read-across at the open"; 07:15 outcome |
| Sector chain baskets and groups | ideas_india #2 | monthly | FREE | NOT PLANNED | see 1(a) |
| Results-sympathy peers | S8.6; IA P14 | per results season | FREE | KB | buy peers whose own results are > 5 days away, first hour |
| China / LME chain for metals and steel | Westmetall LME official + stocks (J23 19:15); Sina `hq.sinajs.cn` via AKShare: DCE iron ore, SHFE rebar / HRC / copper / aluminium / zinc / nickel, coking coal, coke, palm olein, rubber, INE crude (J24 night, J50 day) | evening; every 60 s / 30 s in session | FREE | W1 | replaces the wrong proxies HG=F / ALI=F (plan 6.2-c) |

---------------------------------------------------------------------------------------------------------------------------------

## 2. THE MACRO AND GLOBAL LAYER

Key timing fact (spec E): GIR trades 09:15-15:10, so most outside news is a NEXT-MORNING trade. In-session events are few: RBI policy
10:00, India PMI 10:30, BoJ, WPI 12:00, IEX 13:00, China credit (unscheduled), auto sales on the 1st, counting day, company filings.
Each in-session release locks new entries in the affected sector from 10 min before to 15 min after (E5); Tier-1 (RBI, counting day,
Budget): flat from 15 min before to 30 min after.

### 2A. Indian macro, rates and money

| Item | Source (exact) | IST timing | Cost | Status | Feeds which sectors / shares |
|---|---|---|---|---|---|
| RBI MPC decision, statement, press conference, minutes | `rbi.org.in` (MPC schedule; press release poll 15 s); RBI YouTube via STT (J81) | 10:00 decision; ~12:00 presser; minutes 14 days later 17:00; bi-monthly (early Dec [verify]) | FREE | W1 (calendar) / W2-4 (STT) | banks, NBFCs, HFCs, realty, autos; Tier-1 lock in session |
| RBI press releases, notifications, circulars, penalties | `pressreleases_rss.xml`, `notifications_rss.xml` (J25) | 60 s, evenings busiest | FREE | HAS / W1 | banks, NBFCs (rules, penalties) |
| Money-market operations / liquidity; forex reserves; WSS; G-sec / T-bill auctions | RBI press releases (J66 08:30-09:00); Fri 17:00 reserves | daily / weekly | FREE | W1 / CAL | banks context; 91-day T-bill = Black-76 rate (D59) |
| India 10-year yield | CCIL NDS-OM / Investing IN10Y (manual); FBIL EOD; Stooq `10iny.b`; CNBC `IN10Y` [verify] | live / EOD | FREE | W1 (plan gap #16) | +-10 bp threshold: PSU banks, NBFCs, HFCs, realty |
| USD/INR | Kite CDS USDINR (09:00-17:00); Yahoo INR=X (24 h, overnight NDF proxy); FBIL reference 13:30 | live / 13:30 | PAID-HAVE / FREE | W1 | rupee weak: IT, pharma up; OMCs, INDIGO, banks down; +-0.5% = freeze 15 min (E5) |
| CPI | MoSPI release `mospi.gov.in` -> PIB, wires; poll 15 s 15:58-16:20 (J10) | ~12th, 16:00 | FREE | W1 | N19; rates-sensitive sectors |
| IIP, GDP, PLFS | MoSPI (J10); eSankhyiki API [verify] | IIP ~28th 16:00; GDP last working day of Feb / May / Aug / Nov 16:00 (next: 30 Nov) | FREE | W1 | N19 |
| WPI, core sector | Office of the Economic Adviser `eaindustry.nic.in` | WPI ~14th 12:00 (in session, small); core ~20th 17:00 | FREE | CAL / J81 | context |
| HSBC India PMI (manufacturing, services, flash) | `pmi.spglobal.com/Public/ReleaseCalendar` | 1st-3rd business day 10:30; flash ~20th-23rd 10:30 (in session) | FREE | W1 (J81 lock) | sector lock 10 min before to 15 min after |
| Trade data (incl. gold imports), GST, e-way bills, UPI, CGA | commerce.gov.in (~15th); GSTN / PIB (1st); NPCI; cga.nic.in | monthly | FREE | CAL | gold imports -> TITAN / jewellers; mostly NOISE intraday (E2) |
| FII / DII provisional cash; NSDL FPI daily and fortnightly by sector | NSE `/api/fiidiiTradeReact` (J15); `fpi.nsdl.co.in` (J66, 12.2) | 17:30-19:00; 08:30 next day; fortnightly | FREE | HAS (confirm) / W1 | market context only |
| Union Budget, Economic Survey | `indiabudget.gov.in` | 1 Feb 11:00 (Tier-1 in session); Survey the day before | FREE | CAL | all sectors; leaks into the policy pipeline |
| Cabinet and ministry decisions | PIB RSS `pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3` [verify ids] (J25 60 s); PIB X handles (manual) | Wed Cabinet 15:00-17:00; evenings | FREE | W1 | sector named in the decision |
| Policy pipeline (PENDING -> ANNOUNCED -> NOTIFIED): customs / ADD / safeguard, anti-dumping, trade notices, gazette, GST Council, disinvestment, competition, telecom, power, insurance | CBIC `taxinformation.cbic.gov.in`, DGTR `dgtr.gov.in`, DGFT `dgft.gov.in`, `egazette.gov.in`, `gstcouncil.gov.in`, `dipam.gov.in`, `cci.gov.in`, TRAI, CERC, IRDAI (J25 every 15 min to 01:00; J54 06:50 merge with VERIFIED / UNVERIFIED) | evenings mostly | FREE | W1 (SEBI / RBI / PIB RSS) / W2-4 (scrapers) | metals, chemicals (duties), steel, PSUs (OFS), telecom, power, insurers; E3 ranking |
| Fuel and gas prices | IOCL / HPCL / BPCL sites (J49 06:00-06:30 on the 1st: ATF, commercial LPG); PPAC `ppac.gov.in` (APM gas month end) | 1st; month end | FREE | W2-4 | INDIGO, OMCs, IGL, MGL, GUJGASLTD |
| Industry expectation series | VAHAN dashboard (J37 22:00, J56 07:00); MoCA daily traffic; Grid-India PSP; CEA coal stock; IEX DAM (J81 ~13:00) | daily | FREE | W1 (VAHAN) / W2-4 (rest) | autos (1st-of-month surprise), INDIGO, power, COALINDIA, IEX |
| Monsoon, sowing, reservoirs | IMD `mausam.imd.gov.in`; agriwelfare.gov.in; CWC (Thu) | Apr-Sep (seasonal CORE) | FREE | CAL | fertiliser, agrochem, tractors, two-wheelers, rural FMCG, power |
| Elections | ECI `eci.gov.in`, `results.eci.gov.in` | counting day 30-60 s | FREE | CAL | Tier-1: no trades before 11:00 or skip the day |
| Parliament questions / bills | `sansad.in` (13.9) | session days | FREE | NOT PLANNED | policy context |
| Weekly regulatory watch (lots, expiry days, algo rules, MWPL, STT) | SEBI / NSE / Zerodha circulars | Sat 10:00 | FREE | W1 | GATE rule table (S7.10) |

### 2B. Global markets and sectors

| Item | Source (exact) | IST timing | Cost | Status | Feeds which sectors / shares |
|---|---|---|---|---|---|
| GIFT Nifty (stored series) | Kite `NSEIX:GIFT NIFTY` (J08) -> NSE IX market watch `nseix.com` (J47 before Kite login) | sessions 06:30 (or ~05:15 [verify]) - 15:40 and 16:05 / 16:35 [verify] - 02:45 | PAID-HAVE / FREE | HAS (one-shot LTP) -> W1 (series) | the open's tone, every sector's gap |
| US indices and index futures (explicit contract months) | Yahoo v8 chart `query1.finance.yahoo.com/v8/finance/chart/{SYM}` (^GSPC, ^IXIC, ^DJI, ^SOX / SOXX, ^RUT; ES, NQ, YM, RTY) -> Stooq CSV, CNBC quote service | J29 19:15, J34 every 5 min 19:45-02:45, J45 close 02:35-02:50 | FREE (unofficial, personal use) | HAS (single source) -> W1 (source chain, two witnesses) | Nasdaq +-1.5% -> IT; SOX -> DIXON, KAYNES; whole-market tone |
| US sector ETFs | Yahoo XLF, XLE, XLV (in code), SOXX, IGV, KBE, TAN | as above | FREE | HAS (XLF, XLE, XLV) / W1 | banks (weak), energy, pharma, IT, solar |
| India ETFs abroad | Yahoo INDA, EPI, INDY, SMIN, NFTY | 20:00-02:30 | FREE | W1 (INDA) | foreign money on India overnight |
| Europe indices and sectors | Yahoo ^STOXX50E, ^STOXX, ^GDAXI, ^FTSE; Stoxx 600 Autos / Aerospace & Defence [verify symbols] | W1945 snapshot | FREE | W1 | autos (JLR read-across), defence |
| Asia | Yahoo (15-20 min delayed) Nikkei, Kospi (05:30), Taiwan, A50 (06:30), Shanghai / CSI 300 / Hang Seng (07:00) -> Stooq (J48 every 5 min 05:30-09:00); SGX A50, HKEX night, OSE night (ADVANCED) | 05:30-09:00 | FREE | HAS (^N225, ^HSI, ^KS11, 000001.SS) -> W1 | metals (China), risk mood, yen carry |
| Volatility | Yahoo ^VIX, VX=F, ^MOVE, ^OVX + Kite India VIX | snapshots | FREE | W1 | VIX up = whole market down, option premiums up (OG) |
| Crude oil | Brent: Yahoo BZ=F explicit month + ICE settlement page (J44 01:00-01:15); WTI: Kite MCX CRUDEOIL live (WTI-linked, labelled) | live / settlement | FREE / PAID-HAVE | HAS (BZ=F, roll glitches) -> W1 | Brent +-2%: ONGC, OIL up; OMCs, INDIGO, paints, tyres, cement down; +-3% = shock freeze |
| Refining cracks, LNG | computed from BZ=F / HO=F / RB=F; Investing JKM / TTF (manual); PPAC APM | weekly / daily | FREE | W1 (secondary, gap #21) | RELIANCE, OMCs (GRM); PETRONET, GAIL, IGL, MGL, GUJGASLTD |
| Gold, silver | Kite MCX GOLD / SILVER live; COMEX GC=F / SI=F as witness | live | PAID-HAVE / FREE | W1 | gold +-1.5%: MUTHOOTFIN, MANAPPURAM, TITAN, KALYANKJIL; silver 3%: HINDZINC, VEDL |
| Base metals | Kite MCX COPPER / ALUMINIUM / ZINC / LEAD / NICKEL live; LME official + warehouse stocks via Westmetall (J23 19:15, retry 21:00); lme.com next day; HG=F only a witness, ALI=F dropped | live / evening | PAID-HAVE / FREE | W1 | HINDALCO, NATIONALUM, VEDL, HINDCOPPER, HINDZINC; cables (cost) |
| China futures | Sina `hq.sinajs.cn` via AKShare (nf_I0, nf_RB0, nf_HC0, nf_JM0, nf_J0, nf_CU0, nf_AL0, nf_ZN0, nf_NI0, nf_P0, nf_RU0, nf_AU0, nf_SC0) -> Eastmoney; DCE / SHFE official EOD | night 18:30-00:00 (J24); day 06:30-12:30 (J50) | FREE | W1 | iron ore +-3% / steel: TATASTEEL, JSWSTEEL, SAIL, JINDALSTEL, NMDC, APLAPOLLO |
| Coal, palm oil, sugar, rubber, freight | Investing / Trading Economics Newcastle (manual); Sina DCE palm olein, Bursa; Yahoo SB=F; Rubber Board India; BDRY, SCFI `sse.net.cn`, Drewry WCI | daily / weekly | FREE | W1 (Yahoo symbols, gap #21) / manual | COALINDIA, power, cement; FMCG; BALRAMCHIN; tyres; CONCOR, exporters |
| Dollar and Asian FX | Yahoo DX-Y.NYB, CNY=X, CNH=X, JPY=X; CFETS USD/CNY fixing `chinamoney.com.cn` (J51 06:45); Kite CDS EURUSD / USDJPY / GBPUSD in session | overnight / 06:45 / live | FREE / PAID-HAVE | W1 | DXY +-0.5%: metals, whole market; weak CNY fix: steel, chemicals; sharp JPY strength: whole market |
| US yields and Fed path | Yahoo ^TNX; CNBC quote `US2Y` (Yahoo lacks a 2y); FRED DGS10 / DGS2 (EOD); CME FedWatch light fetch at 19:45 / 07:15 (heavy use forbidden) (R24) | snapshots | FREE | W1 | banks, NBFCs, realty, IT valuation |
| Settlements as reference prices | ICE Report Center / CME settlement pages (J44) | 01:00-01:15 | FREE | W1 | every "% move vs <named reference>" in the 07:15 note |
| Positioning | CFTC Commitments of Traders | Sat 02:00 | FREE | W1 (weekend) | context |
| Crypto (weekend risk gauge only) | Binance public websocket / Yahoo BTC-USD | weekend | FREE | optional | context |

### 2C. World events calendar

| Item | Source (exact) | IST timing (winter clock; one hour earlier from US DST 14 Mar 2027 / Europe 28 Mar 2027) | Cost | Status | Feeds which sectors / shares |
|---|---|---|---|---|---|
| Economic calendar with consensus | ForexFactory `nfs.faireconomy.media/ff_calendar_thisweek.json` (no INR; <= 2 requests per 5 min) (J28 18:00 and 21:00 Sun-Fri; Sun 18:00 next week + 4-week build); official calendars for times (BLS / BEA ICS, FRED release dates, Fed, RBI, BoJ, NBS, S&P PMI, MoSPI); Nasdaq.com calendar JSON [verify] backup; Investing / Trading Economics manual | weekly + twice daily | FREE (paid FMP / EODHD US$20-60 / mo only on trigger) | W1 (replaces hand-edited `econ_events.json`) | E1 / E2 risk strip, event locks, surprise scores |
| US data (CPI, payrolls, retail sales, PPI, claims, GDP, PCE) actual vs consensus | BLS / BEA pages -> ForexFactory JSON once at 19:10 -> wires (J27) | 19:00 (18:00 summer) | FREE | W1 | next-morning: IT, banks, metals, whole market |
| FOMC statement and presser; Fed speakers | `federalreserve.gov` RSS 15 s (J43) | 00:30 / 01:00 | FREE | W1 | whole market, NBFCs, realty, IT |
| ECB, BoE, BoJ, PBoC LPR, RBA | central-bank sites; `cbrates.com` aggregator | ECB 18:45; BoE 17:30; BoJ decision 08:00-09:30, presser 12:00 (in session); LPR 20th 06:30; RBA 09:00 | FREE | W1 (calendar) | BoJ: yen carry, whole market |
| China data | `stats.gov.cn/english` (NBS PMI last day 07:00; CPI / PPI ~9th 07:00; activity ~15-17th 07:30); `pmi.spglobal.com` (RatingDog PMI 1st business day 07:15); customs (~08:30); credit TSF / loans unscheduled 13:30-15:30 in session (J52) | pre-open mostly | FREE | W1 | metals, steel, chemicals - "wait 15 min for the metal index to confirm" (E2) |
| Oil events | EIA API v2 (J36: Wed 21:00 petroleum, Thu 21:00 gas storage, Fri 23:30 rig count); OPEC+ eight-country meeting (usually first Sunday); OPEC MOMR, IEA OMR | weekly / monthly | FREE | W1 / CAL | ONGC, OIL, OMCs, INDIGO, paints |
| US trade / tariff actions | Federal Register API `federalregister.gov/api/v1` (public-inspection documents a day ahead); whitehouse.gov presidential actions; USTR press; Commerce s232 (J41 23:00, 02:00, 05:30) | night | FREE | W2-4 | pharma (tariffs), IT (H-1B / visa), steel / aluminium, textiles |
| USFDA | see 1(g) J40 | Tue night IST peak | FREE | W2-4 | pharma |
| Index rebalances | MSCI quarterly (Feb / May / Aug / Nov; announcements ~03:30-04:30 IST; Nov 2026 effective about end-Nov [verify]); FTSE (Mar / Jun / Sep / Dec); Nifty semi-annual (effective end-Mar / end-Sep); Sensex (Jun / Dec) | per review | FREE | W1 (J46 on review nights) / CAL | exit rebalance shares by 14:45 on the effective day |
| Geopolitics (Hormuz, India-Pakistan / China border, sanctions, Red Sea, Russia-Ukraine) | GDELT DOC API `api.gdeltproject.org/api/v2/doc/doc` every 15 min; wires; squawk accounts on X (manual: @DeItaone, @FirstSquawk, @LiveSquawk, @financialjuice) | continuous | FREE | W2-4 | oil, defence, whole market; unscheduled shock rules (E5) |
| Global peers' results (Accenture etc.) | see 1(h) - ideas_india #12 | per quarter | FREE | NOT PLANNED as a calendar job | IT, pharma, autos, metals, capital goods, electronics, INDIGO |
| Softs / agri | USDA WASDE ~10th-12th 22:30; MPOB palm ~10th 10:00 | monthly | FREE | WASDE: listed in the global map only; MPOB: CAL | edible-oil users, FMCG |
| Market holidays and sessions (NSE, MCX, CME, LME, SHFE / DCE incl. Golden Week, NYSE, JPX) | official calendars (D5); near dates: US Thanksgiving 26 Nov (closed), 27 Nov half day | yearly + circulars | FREE | W1 | CLOSED is not STALE; a two-day 07:15 note after a holiday |

---------------------------------------------------------------------------------------------------------------------------------

## 3. SHORT SUMMARY FOR THE TRADER

1. Per share, beyond Kite's live price and OI, GIR keeps a dossier in eight parts: identity, results, ownership, corporate actions, price history, derivatives history, news, and links to world drivers.
2. Identity: name, ISIN, aliases, sector and drivers, lot size, expiry, ban / MWPL. Sources: NSE files, Nifty index constituent lists, Kite's instrument file. Checked every morning (08:00-08:45). A Kite vs NSE mismatch blocks that share for the day.
3. Results: the date and purpose come from NSE / BSE board-meeting notices, refreshed nightly at 19:35. The numbers come from the exchange filing within seconds; XBRL parsing comes in weeks 2-4. Rule: never buy options into results.
4. Consensus has no free API. GIR will store the CNBC-TV18 / ET Now polls and NDTV Profit "vs estimate" lines for each result, starting next results season (mid-Jan). Guidance comes from con-calls and transcripts. Long-term financials are a manual Screener check, not a feed.
5. Ownership: bulk and block deals are loaded every evening, and both block windows (08:45 and 14:05) are watched live. OFS / QIP floors and index rebalance dates come from filings and circulars. Delivery % and FII / DII figures are context only, never a reason for a trade.
6. Corporate actions (dividend, split, bonus, buyback, demerger) come from NSE's corporate-actions feed and FAOP adjustment circulars, checked daily at 08:00 and 20:00. History is adjusted before use.
7. Price history: NSE bhavcopy and Kite minute candles. ATR14, levels, RVOL baselines and sector betas are rebuilt every night at 22:00. Gap-fill, leader / laggard and results-reaction records are refreshed monthly.
8. IV history has no free source. GIR records ATM IV every minute from now and back-fills about 2 years from NSE F&O bhavcopy closes. Dhan (Rs 499 a month) seeds true intraday IV in weeks 2-4. Spreads by strike are logged at 09:30, 12:00 and 14:30.
9. Derivatives history: F&O bhavcopy every evening (OI, rollover, basis), futures OI across all months every minute, and the ban list (dated T+1) with MWPL each evening. A live MWPL estimate comes in weeks 2-4. A share at 85% or more of MWPL gets no new calls.
10. News: NSE and BSE filings polled every 3-5 s (about 3 minutes late today). Then come Reuters, publisher sitemaps and live blogs, CNBC-TV18 speech-to-text, and regulators (SEBI, RBI, PIB, USFDA, courts). Each story is tagged with direction, VERIFIED / UNVERIFIED and NEW / PRICED IN.
11. Macro: RBI (10:00), MoSPI data at 16:00 (CPI, GDP, IIP), India PMI at 10:30, PIB Cabinet decisions, and the evening policy pipeline (duties, gazette, OFS). Each is mapped to sectors and gets an entry lock when it lands in session.
12. World: GIFT Nifty, US / Europe / Asia indices, ADRs, VIX, yields, DXY / CNY / JPY, Brent and settlements, LME, China futures, and MCX / currency futures live. Snapshots at 19:15, 07:00, 08:45 and 09:00, every move stated against a named reference.
13. Calendars: ForexFactory consensus plus official calendars give a surprise score for each event: US data at 19:00, Fed at 00:30, China at 07:00-07:30, BoJ in session, MSCI / Nifty rebalances.
14. Cost: about Rs 2,000 a month + GST for the four Kite apps you already pay for [verify]. Everything else in the core plan is free. The first new paid item is Dhan at Rs 499 a month (weeks 2-4) plus about Rs 300 a month for a spare-phone SIM. Anything else needs a measured trigger first: cloud speech-to-text Rs 2-8k a month, a calendar API US$20-60, TradingView US$15-25, a paid newswire Rs 1.5-5 lakh a year.
15. Today's weak spots: MCX and currency futures are paid for but not subscribed. Metals are read from the wrong proxies (COMEX HG=F and the thin ALI=F). World data has one unofficial source (Yahoo). The economic calendar is hand-edited. The Reuters RSS in the code is dead. Google News sits in the alert path. All of these are trial-week fixes.
16. Not yet collected, most important first: (1) results consensus and surprise (R13, from mid-Jan) and results time of day; (2) IV rank history until Dhan or 60 days of recording; (3) a structured pledge / insider (PIT) / SAST loader - today only raw filings, so the red-flag card "pledge > 25% or rising" has no feeder; (4) the group / PSU basket table and a "supply" table (block term-sheets, OFS / QIP floors, lock-in expiries); (5) a calendar of global peers' results (Accenture, JLR, Teva ...). Also missing: live con-call listening, sector-index weights, and measured driver sensitivities (after 6-12 months).
17. Deliberately not collected (no use for intraday): mutual-fund portfolio holdings, quarterly shareholding changes, AGMs, broker targets, paid databases (Capitaline, ACE, Prowess, Bloomberg).
18. To verify before relying on it: NSE endpoints from the server IP (Akamai), the combineoi 2025 columns, the GIFT session hours, Kite's multi-app terms and price, and the November stock expiry (24 Nov in the plan vs Mon 23 Nov in DATA.md - the contract master decides).
