# NEWS / INFORMATION SOURCE COVERAGE AUDIT

Made 2026-11-21 13:58 IST, Saturday (market closed). Read-only: no code changed, no service restarted, no Telegram, no AI calls, no outside fetches. Every number below comes from GIR's own stores, logs and code on this server. Machine copy: `NEWS_COVERAGE_AUDIT.json` (same folder).

**Weekend note.** Indian sources are naturally quiet on Saturday. "Last item" is shown as it is, but LIVE / SILENT was judged on Friday 20 Nov (the `Fri` column). Lag = GIR's first-seen time minus the source's own time, median over the last 72 h, leaving out the first poll after each start (it re-reads old items) and sources that give a date only.

**Status rules.** LIVE = works, items flowed on the last weekday, median lag <= 10 min (or the daily file arrived). SLOW = works but lag > 10 min, partial, or only via Google News. SILENT = polled, but nothing arrives when it should (blocked / dead / broken). NOT BUILT = planned, nobody reads it.

## 1. Bottom line

- Sources read today: **88 rows** (v2 + old system). **LIVE 59 · SLOW 15 · SILENT 14**, plus **20 planned sources NOT BUILT**.
- Hosts in WEB_SOURCES.md + COLLECTION_PLAN.md: **186 distinct hosts** - LIVE 34, PARTIAL 20, BLOCKED 15, DEAD 3, NOT NEEDED 10, **NOT BUILT 104** (section 6).

**Biggest gaps (most urgent first):**

1. **The desk readers R1-R6 stopped making cards at 08:50 IST today.** Every reader call since then is refused before the call: "J11: day total $4.02 would pass the $1.50 hard cap - code + rules only" (the weekend / holiday day cap in v2/analyst/config.py, WEEKEND_CAP_USD = 1.50). News keeps arriving (PIB 13:44, ET 13:40, filings 13:44) but nothing turns into a card. The old v2 news reader's AI is also off by the desk flag (NEWSREAD_AI_OFF). So on a weekend / holiday day, once $1.50 is spent, outside news reaches the desk only as raw lines. **Tue 24 Nov (NSE holiday) uses the same $1.50 cap.**
2. **BSE company filings are blocked for v2.** api.bseindia.com answers 403 to gir-v2filings since **Fri 20 Nov 16:16 IST** (60 block lines; now waiting 15 min between tries). The old newshawk-filings bot still reads page 1 of the same API (507 items in 24 h, last 13:37). It is not wired to v2, so v2 has no BSE filings since Friday afternoon. (newshawk page 2 also 403s since 16:16.) **This needs a fix or a stop-gap before Monday 09:00.**
3. **Policy items go to the wrong reader.** The snapshot types every v2 regulator row (PIB, RBI, SEBI, TRAI, Parliament, LiveLaw) as `world`, so they go to R5 (world reader), never to R4 (policy reader). R4 made **1 card** in 24 h; R5 made **0** from these rows. 48 PIB releases and 13 RBI releases were read by GIR in 24 h; **0 became cards** (v2/analyst/snapshot.py, `knowledge()`, the ext.recent kind rule).
4. **The desk's biggest card source is the slowest.** Google News per share (old newsroom scouts) gave 84 of the 251 cards, with a **median lag of 96 min** (n=2180). The fast publisher sitemaps (v2 wires: ET 1.8 min, Moneycontrol 2.6 min) gave only 17 cards, and they are typed `world` too (R5, not R2).
5. **TV gives almost nothing to the desk.** CNBC-TV18 and ET NOW were captured 390 of 390 minutes on Friday, but the TV reader R3 made **1 card**, R6 made 4.
6. **Dead or blocked feeds still polled:** Moneycontrol RSS (dead since April 2024) by three readers; CNBC.com RSS (403) and Yahoo RSS (404) by newshawk; X stream (HTTP 402, no credits) every 5 min; old macro.py RBI/SEBI RSS (0 items parsed).
7. **Trump mirror suspicious:** 1 post in 24 h vs 16 on Friday; polls succeed. Check trumpstruth.org against Truth Social by hand.
8. **Not built at all:** global peers' results, broker research reports, CNBC Awaaz, Sansad TV, Fed / BIS / central banks, EIA / OPEC, GST Council (old scraper broken), DGFT / DGTR, tribunals (NCLT / NCLAT / SAT / TDSAT), India data calendar (GDP is out 30 Nov), Telegram channels, Polymarket (section 4).
9. **Blind or unproven watchers:** e-Gazette page watch cannot see the Extraordinary list; CBIC / CDSCO / APTEL / DIPAM / CCI have produced no row since they started (pages fetch fine, so probably no news, but not proven); NSE pledge events produced no row after the first poll (suspicious).

## 2. Desk board: which sources the readers turned into cards

deskboard.db `cards` (schema: id, ts, day, seat, kind, strength, headline, snapshot_id, payload; the payload carries `item_src` / `item_kind`). All 251 cards fall between **20 Nov 19:23 and 21 Nov 08:50 IST**, so "24 h" = all of them. 0 cards since 08:50 (budget cap, gap 1).

| Reader | Cards | From (item_src: count) |
|---|---|---|
| R1 filings | 44 | NSE filings 19, BSE filings 16 (all before the block), Google News results 8, WIRE results 1 |
| R2 wires | 110 | Google News 70, WIRE (old macro RSS) 27, newsmap themes 6, Moneycontrol live blog 2, ET Now 1, ANI 1, FinancialJuice 1, RBI (bonds) 1, v2 wires CNBC-TV18 1 |
| R3 TV | 1 | TV ET NOW 1 |
| R4 policy | 1 | POLICY (old policymap) 1 |
| R5 world | 75 | FinancialJuice 30, US wrap 19, v2 wires 16, investingLive / Treasury / LME 7, 10-yr bonds 2, circulars 1 |
| R6 story | 10 | Google News 6, TV CNBC-TV18 4 |
| seats 1 / 32 / 33 / 34 | 10 | views / alerts (not reader cards) |

Sources with **0 cards** although GIR read them in the last 24 h: PIB (48 items), RBI press (13), SEBI (16), TRAI (8), Parliament, LiveLaw, insider (36), SAST (21), BSE notices (42), Supreme Court cause lists (19), White House, Federal Register (10), NSDL, index notices, page watches. The old newshawk system's sources (about 2,000 items a day) are **not wired into v2 at all** - no v2 file reads ledger.db, news_seen.db, filings_seen.db, regnews.db or x_feed.db.

## 3. Every source read today

Columns: poll = shortest interval in the code (details in the JSON `poll_note`); 24 h = items first seen in the last 24 h; Fri = items first seen on Fri 20 Nov; lag = median minutes; cards = desk cards in 24 h (`n/a` = not an input to the v2 desk, `-` = shared with another row). Core sources get a 30-min silence threshold, the rest 120 min, inside their alarm window (JSON).

### 3a. New system (v2)

| Source | Category | Host | Poll s | Last item (IST) | 24 h | Fri | Lag min | Cards | Status | Core |
|---|---|---|---|---|---|---|---|---|---|---|
| NSE company filings (v2) | NSE/BSE filings | www.nseindia.com | 4 | 2026-11-21 12:49 (F&O); 13:44 (any company) | 52 | 63 | 0.4 | 19 | **LIVE** | yes |
| BSE company filings (v2) | NSE/BSE filings | api.bseindia.com | 4 | 2026-11-20 16:11 (F&O); 16:15 (any) | 16 | 32 | 0.7 | 16 | **SILENT** | yes |
| NSE circulars (v2) | NSE/BSE filings (exchange rules) | www.nseindia.com | 60 | 2026-11-20 21:32 | 32 | 36 | - | 1 | **LIVE** |  |
| BSE notices (v2) | NSE/BSE filings (exchange rules) | www.bseindia.com | 60 | 2026-11-21 13:22 | 42 | 48 | 2.9 | 0 | **LIVE** |  |
| Insider trades PIT Reg 7 (NSE) | NSE/BSE filings (insider) | www.nseindia.com | 120 | 2026-11-21 13:17 | 36 | 50 | 1.2 | 0 | **LIVE** |  |
| SAST Reg 29 (NSE) | NSE/BSE filings (stake changes) | www.nseindia.com | 120 | 2026-11-20 18:34 | 21 | 21 | 1.8 | 0 | **LIVE** |  |
| Pledge events SAST Reg 31 (NSE) | NSE/BSE filings (pledge) | www.nseindia.com | 120 | 2026-11-19 15:38 (first-run rows only) | 0 | 0 | - | 0 | **SILENT (unproven)** |  |
| BSE insider feed | NSE/BSE filings (insider) | www.bseindia.com | 120 | 2026-11-20 20:47 | 4 | 5 | - | 0 | **LIVE** |  |
| Block-deal window trades (live) | deals (block) | www.nseindia.com + api.bseindia.com | 30 | 2026-11-20 14:10 | 2 | 4 | 0.2 | 0 | **LIVE** | yes |
| Bulk / block / short-sell lists (EOD) | deals (bulk/block) / FII-DII names | www.nseindia.com | 600 | 2026-11-20 18:36 | 63 | 63 | - | 0 | **LIVE** |  |
| Trump posts (Truth Social mirror) | world (US policy) | trumpstruth.org | 45 | 2026-11-20 18:35 | 1 | 16 | 1.4 | 0 | **SILENT (unproven)** | yes |
| White House presidential actions | world (US policy) | www.whitehouse.gov | 60 | 2026-11-21 08:02 | 2 | 0 | 0.5 | 0 | **LIVE** |  |
| US Federal Register public inspection | world (US policy) | www.federalregister.gov | 60 | 2026-11-20 19:16 | 10 | 10 | 1.2 | 0 | **LIVE** |  |
| FinancialJuice free headlines | wires (world macro squawk) | www.financialjuice.com | 60 | 2026-11-21 13:12 | 240 | 366 | 0.8 | 31 | **LIVE** | yes |
| investingLive headlines (ex-ForexLive) | wires (world macro) | investinglive.com | 60 | 2026-11-21 04:33 | 27 | 21 | 33.8 | 7 | **SLOW** |  |
| US Treasury par yields | world closes (rates) | home.treasury.gov | 1800 | 2026-11-21 02:30 | 2 | 1 | - | 0 | **LIVE** |  |
| LME official prices (Westmetall) | commodities | www.westmetall.com | 1800 | 2026-11-21 07:50 | 2 | 1 | - | 0 | **LIVE** |  |
| US / Asia closes + live quotes (Yahoo chart API) | world closes / commodities | query1.finance.yahoo.com | 300 | 2026-11-21 13:48 (quotes file) | - | - | - | - | **LIVE** | yes |
| US close wrap stories | world wraps / closes | news.google.com (Reuters / CNBC wraps), www.nasdaq.com, www.investing. | 300 | 2026-11-21 13:44 | 95 | 0 | 55.2 | 19 | **SLOW** | yes |
| India 10-yr G-sec yield (Trading Economics) | RBI / rates | tradingeconomics.com | 120 | 2026-11-21 09:02 | 8 | 7 | - | 3 | **LIVE** |  |
| RBI liquidity / auctions (bonds poller) | RBI | www.rbi.org.in | 300 | 2026-11-20 19:52 | 5 | 10 | 8.9 | 0 | **LIVE** |  |
| RBI press releases / notifications / speeches | RBI | www.rbi.org.in | 60 | 2026-11-20 19:52 | 13 | 13 | 6.4 | 0 | **LIVE** | yes |
| SEBI What's New + circulars listing | SEBI | www.sebi.gov.in | 60 | 2026-11-20 19:12 | 16 | 16 | - | 0 | **LIVE** | yes |
| TRAI RSS | regulators | www.trai.gov.in | 60 | 2026-11-20 18:26 | 8 | 8 | 2.8 | 0 | **LIVE** |  |
| CCI press releases | regulators | www.cci.gov.in | 60 | none since start (20 Nov 15:37) | 0 | 0 | - | 0 | **LIVE (unproven)** |  |
| PIB English releases | PIB / government | www.pib.gov.in | 60 | 2026-11-21 13:44 | 48 | 40 | 5.7 | 0 | **LIVE** | yes |
| Parliament (sansad.in JSON) | Parliament | sansad.in | 120 | 2026-11-20 16:19 | 1 | 1 | 7.3 | 0 | **LIVE** |  |
| LiveLaw court news sitemap | courts | www.livelaw.in | 120 | 2026-11-21 11:17 | 3 | 0 | 1.8 | 0 | **LIVE** |  |
| Supreme Court cause lists | courts | www.sci.gov.in + api.sci.gov.in | 1200 | 2026-11-21 05:47 | 19 | 0 | - | 0 | **LIVE** |  |
| e-Gazette (page watch) | government (gazette) | egazette.gov.in | 300 | none (seeded 20 Nov, 0 new links) | 0 | 0 | - | 0 | **SILENT (unproven)** |  |
| CBIC GST / CDSCO / APTEL (page watch) | GST / regulators / courts | cbic-gst.gov.in, cdsco.gov.in, aptel.gov.in | 900 | none (seeded 20 Nov, 0 new links) | 0 | 0 | - | 0 | **LIVE (unproven)** |  |
| AERA / GERC (page watch) | regulators (airport / state power) | aera.gov.in, gercin.org | 900 | 2026-11-21 11:05 | 17 | 6 | - | 0 | **LIVE** |  |
| Index providers (NSE Indices, BSE index, FTSE) | calendar (index changes) | www.niftyindices.com, www.bseindia.com, research.ftserussell.com | 900 | 2026-11-20 22:56 | 4 | 4 | - | 0 | **LIVE** |  |
| DIPAM OFS pages | government (OFS) | www.dipam.gov.in | 600 | none since start (19 Nov) | 0 | 0 | - | 0 | **LIVE (unproven)** |  |
| NSDL FPI daily + red-flag + fortnight | NSDL / FII | www.fpi.nsdl.co.in | 1800 | 2026-11-20 16:27 (daily); fortnight 15 Nov | 1 | 1 | - | 0 | **LIVE** |  |
| Economic week + NSE board meetings calendar | summits / calendar | nfs.faireconomy.media + www.nseindia.com | 10800 | 2026-11-21 12:03 (file made) | - | - | - | - | **LIVE** |  |
| Wires: ET news sitemap (v2) | wires / publishers | economictimes.indiatimes.com | 20 | 2026-11-21 13:40 | 47 | 21 | 1.8 | n/a | **LIVE** | yes |
| Wires: CNBC-TV18 Google-News sitemap (v2) | wires / publishers | www.cnbctv18.com | 45 | 2026-11-21 10:34 | 13 | 11 | 1.9 | n/a | **LIVE** | yes |
| Wires: CNBC-TV18 latest RSS (v2) | wires / publishers | www.cnbctv18.com | 30 | 2026-11-21 13:39 | 5 | 4 | 4.3 | n/a | **LIVE** | yes |
| Wires: Business Standard latest RSS (v2) | wires / publishers | www.business-standard.com | 30 | 2026-11-20 23:40 | 10 | 10 | 8.9 | n/a | **LIVE** | yes |
| Wires: Business Standard markets RSS (v2) | wires / publishers | www.business-standard.com | 60 | 2026-11-20 20:50 | 4 | 4 | 10.6 | n/a | **SLOW** | yes |
| Wires: Moneycontrol news sitemap (v2) | wires / publishers | www.moneycontrol.com | 60 | 2026-11-21 12:55 | 26 | 19 | 2.6 | n/a | **LIVE** | yes |
| TV analyst-call detector (v2) | TV / broker calls | (reads data/tv.db) | 10 | 2026-11-20 15:42 | 0 | 50 | - | - | **LIVE** |  |
| Broker calls register (v2, derived) | broker calls | (reads news.db, ext, tv.db, tvcalls) | - | 2026-11-21 07:19 | 6 | 24 | - | - | **SLOW** |  |

### 3b. Old system still running (Telegram muted)

| Source | Category | Host | Poll s | Last item (IST) | 24 h | Fri | Lag min | Cards | Status | Core |
|---|---|---|---|---|---|---|---|---|---|---|
| TV CNBC-TV18 speech-to-text | TV speech-to-text | www.youtube.com (yt-dlp) + api.deepgram.com | 10 | 2026-11-21 13:37 | 3640 | 5024 | 0.2 | 4 | **LIVE** | yes |
| TV ET NOW speech-to-text | TV speech-to-text | www.youtube.com + api.deepgram.com | 10 | 2026-11-21 13:37 | 3637 | 5019 | 0.2 | 1 | **LIVE** | yes |
| NSE announcements (old exchange.py) | NSE/BSE filings | www.nseindia.com + nsearchives.nseindia.com | 15 | 2026-11-21 12:49 | 52 | 63 | 0.7 | n/a | **LIVE** |  |
| Google News per share (newsroom scouts) | wires (aggregator) | news.google.com | 6 | 2026-11-21 13:25 (seen 13:33) | 671 | 774 | 95.9 | 84 | **SLOW** | yes |
| Old macro.py direct RSS: ET (5 feeds) | wires / publishers | economictimes.indiatimes.com | 60 | 2026-11-21 11:21 | 2 | 3 | 19.4 | - | **SLOW** |  |
| Old macro.py: Moneycontrol RSS (4 feeds) | wires / publishers | www.moneycontrol.com | 60 | never stored | 0 | 0 | - | 0 | **SILENT** |  |
| Old macro.py: live blogs (MC, CNBC-TV18, ET) | wires / broker calls | www.moneycontrol.com, www.cnbctv18.com, economictimes.indiatimes.com | 60 | 2026-11-20 16:01 | 21 | 109 | 1.0 | 2 | **LIVE** | yes |
| Old macro.py: CNBC-TV18 / Mint / BusinessLine / ET Now / TradingView RSS | wires / publishers | www.cnbctv18.com, www.livemint.com, www.thehindubusinessline.com, www. | 60 | 2026-11-21 12:56 | 22 | 39 | 4.6 | 1 | **LIVE** |  |
| Old macro.py: BS / NDTV Profit / Business Today RSS | wires / publishers | www.business-standard.com, feeds.feedburner.com (NDTV Profit), www.bus | 60 | 2026-11-21 13:08 | 13 | 23 | 11.6 | - | **SLOW** |  |
| Old macro.py: The Hindu Business + TOI Business RSS | wires / publishers | www.thehindu.com, timesofindia.indiatimes.com | 60 | never stored | 0 | 0 | - | 0 | **SILENT** |  |
| Old macro.py: Google News searches (13 feeds) | wires (aggregator) / world | news.google.com | 60 | 2026-11-21 13:36 | 79 | 77 | 6.1 | - | **LIVE** |  |
| Old macro.py: RBI + SEBI RSS | RBI / SEBI | www.rbi.org.in, www.sebi.gov.in | 120 | not measurable | - | - | - | 0 | **SILENT (unmeasured)** |  |
| Old govwatch (PIB / RBI / SEBI / IRDAI) | PIB / RBI / SEBI / regulators | pib.gov.in, rbi.org.in, sebi.gov.in, irdai.gov.in, news.google.com | 600 | last alert 2026-11-21 11:30 | - | - | - | n/a | **LIVE (unmeasured)** |  |
| Old regwatch (30 regulator pages) | regulators | irdai, sebi, rbi, cci, fda.gov, trai, enforcementdirectorate, cercind, | 120 | last alert ~2026-11-20 15:11 | - | - | - | n/a | **LIVE (unmeasured)** |  |
| Old shockwatch (Google News shock words) | regulators / governance | news.google.com | 300 | last alert 2026-11-21 13:05 | - | - | - | n/a | **SLOW (unmeasured)** |  |
| Old earlyteam world news (12 Google News queries) | world / summits / commodities | news.google.com | 600 | 2026-11-21 13:10 | 400 | 255 | - | n/a | **SLOW** |  |
| Old earlyteam Yahoo prices | world closes / commodities | query1/query2.finance.yahoo.com | 300 | 2026-11-21 13:35 | 284 | 122 | - | n/a | **LIVE** |  |
| Old overnight Google News (papers, world wires, commodities) | world wraps / commodities | news.google.com | - | 2026-11-20 08:35 (list) | 0 | 21 | - | n/a | **LIVE (unmeasured)** |  |
| Old newshunt (sector jump -> reason) | wires / policy (Google News) | news.google.com (+ macro RSS) | 60 | 2026-11-20 15:37 | 2 | 67 | 47.5 | n/a | **SLOW** |  |
| Old policymap (policy stories -> shares) | regulators (derived) | (reads macro.json) | 30 | 2026-11-19 18:11 | 0 | 0 | 41.2 | 1 | **SILENT** |  |
| Old moverswhy (why the big movers moved) | wires (Google News) | news.google.com | 900 | 2026-11-20 15:15 | 0 | 20 | - | n/a | **SILENT** |  |
| Old expect.py (brokers' numbers for results) | broker calls | news.google.com + publisher pages | - | newest number published 2026-11-11 | 0 | 0 | - | n/a | **SILENT** |  |
| FII / DII cash (NSE provisional) | FII / DII | www.nseindia.com /api/fiidiiTradeReact | 1200 | data for 20 Nov (desk copy seen 20 Nov 19:23) | - | 1 | - | - | **LIVE** |  |
| FII / DII F&O participant OI + delivery + MWPL | FII / DII | nsearchives.nseindia.com | - | trade date 2026-11-20 | - | 1 | - | - | **LIVE** |  |
| Named FII / DII deals (bulk / block CSV) | FII / DII / deals | nsearchives.nseindia.com | - | trade date 2026-11-20 | - | 1 | - | n/a | **LIVE** |  |
| NSDL FPI by sector (fortnightly) | NSDL | www.fpi.nsdl.co.in | - | fortnight ending 2026-11-15 | 0 | 0 | - | - | **LIVE** |  |
| Results calendar (NSE event calendar, BSE fallback) | summits / calendar | www.nseindia.com, api.bseindia.com | - | fetched 2026-11-20 09:09 | - | 1 | - | - | **LIVE** |  |
| Article bodies (Google link -> publisher page) | wires (full text) | news.google.com + publisher hosts | - | 2026-11-21 13:36 | 473 | 682 | - | - | **LIVE** |  |
| newshawk: NSE announcements RSS | NSE/BSE filings | nsearchives.nseindia.com | 90 | 2026-11-21 12:52 | 24 | 28 | 0.5 | n/a | **LIVE** |  |
| newshawk: ET / Mint / BS / Livemint RSS | wires / publishers | economictimes.indiatimes.com, www.livemint.com, www.business-standard. | 90 | 2026-11-21 12:35 | 16 | 36 | 10.0 | n/a | **SLOW** |  |
| newshawk: Moneycontrol RSS (3 feeds) | wires / publishers | www.moneycontrol.com | 90 | never (0 rows since 3 Oct) | 0 | 0 | - | n/a | **SILENT** |  |
| newshawk: Google News (Nifty, Reuters markets, regulators, drafts, courts, healthcare) | wires / regulators / courts (aggregator) | news.google.com | 90 | 2026-11-21 12:23 | 93 | 102 | 12.5 | n/a | **SLOW** |  |
| newshawk: RBI / SEBI RSS (+ regwatch) | RBI / SEBI | www.rbi.org.in, www.sebi.gov.in | 90 | 2026-11-20 19:53 | 38 | 43 | - | n/a | **LIVE (unmeasured)** |  |
| newshawk: CNBC Top / Finance RSS | world wraps | www.cnbc.com | 90 | 2026-11-15 18:30 | 0 | 0 | - | n/a | **SILENT** |  |
| newshawk: Yahoo Finance RSS | world wraps | finance.yahoo.com | 90 | never | 0 | 0 | - | n/a | **SILENT** |  |
| newshawk: MarketWatch top stories RSS | world wraps | feeds.content.dowjones.io | 90 | 2026-11-21 01:33 | 2 | 0 | 2.5 | n/a | **LIVE** |  |
| newshawk: Investing.com news RSS | world wraps / commodities | www.investing.com | 90 | 2026-11-21 04:42 | 20 | 16 | 7.4 | n/a | **LIVE** |  |
| newshawk-regwatch: PIB / IRDAI / RBI notifications / CCI / TRAI / GST Council / DGCA | PIB / regulators | pib.gov.in, irdai.gov.in, www.rbi.org.in, www.cci.gov.in, www.trai.gov | 120 | PIB 2026-11-21 13:05; IRDAI 20 Nov 20:05; CCI 10 Nov; TRAI 17 Nov; GST 9 Oct; DGCA 13 Nov | 66 | 68 | - | n/a | **SLOW** |  |
| newshawk-regwatch + regnews: Google News regulator / court / USFDA queries | regulators / courts / USFDA | news.google.com | 240 | 2026-11-21 13:37 | 1149 | 1458 | - | n/a | **SLOW** |  |
| newshawk-filings: BSE announcements API | NSE/BSE filings | api.bseindia.com | 180 | 2026-11-21 13:37 | 507 | 630 | - | n/a | **SLOW** |  |
| newshawk-whales: NSE bulk / block CSV | deals | nsearchives.nseindia.com | 300 | 2026-11-20 18:36 | 112 | 112 | - | n/a | **LIVE** |  |
| newshawk-ahead: F&O ban list + NSE RSS daily | NSE (ban list / calendar) | nsearchives.nseindia.com | - | ran 2026-11-21 07:45 | 1 | 1 | - | n/a | **LIVE** |  |
| newshawk-xstream: X filtered stream (TV + govt + wires accounts) | X / social | api.x.com | 300 | 2026-10-29 16:50 | 0 | 0 | - | n/a | **SILENT** |  |
| newshawk ledger refill / radar / evening / preopen | calendar / backfill | news.google.com, www.nseindia.com | - | refill 2026-11-20 20:04; preopen 20 Nov 09:10 | 6 | 11 | - | n/a | **LIVE (unmeasured)** |  |

**Notes on rows (one line each where it matters):**

- **NSE company filings (v2)** - NSE blocks cloud machines; this server reads it fine. 352 filings (all companies) in 24 h. Lag: exchange dissemination time vs first seen, n=124; all companies 0.38 min (n=743).
- **BSE company filings (v2)** - BLOCKED: api.bseindia.com answers HTTP 403 to v2 since Fri 20 Nov 16:16 IST (60 block lines, now backing off 15 min each time). The old newshawk-filings bot still gets page 1 from the same host (507 items in 24 h), so the block is client-specific, not a full IP ban. Lag: n=85, before the block.
- **NSE circulars (v2)** - Saturday quiet is normal (no NSE circulars on weekends).
- **Pledge events SAST Reg 31 (NSE)** - No new pledge event since the first poll on 19 Nov, including all of Friday. May be the F&O-only filter, may be a broken path; needs a look. pledge_fo.json (the full table) was rewritten 21 Nov 08:52 IST.
- **Block-deal window trades (live)** - BSE half may now hit the same 403 as v2 filings (not seen yet: the BSE block began after Friday's windows). Lag: n=4.
- **Trump posts (Truth Social mirror)** - Polls succeed (status OK, one 429 at 08:52) but only 1 post in the last 24 h vs 16 on Friday; 19 h without a post is unusual. Cannot tell without a live fetch whether the mirror is stale or there were no posts. Check the mirror against truthsocial.com by hand. Lag: n=29.
- **US Federal Register public inspection** - Weekend quiet is normal (no US filings on Saturday). Lag: n=20; trade-word filter.
- **investingLive headlines (ex-ForexLive)** -  Lag: n=25, p90 55; the feed itself publishes late.
- **US / Asia closes + live quotes (Yahoo chart API)** - 28 quotes (S&P, Nasdaq, Dow, SOX, Nikkei, KOSPI, Taiwan, HSI, Brent, WTI, gold, DXY ...). Added 21 Nov 07:49 IST.
- **US close wrap stories** - Built 21 Nov 07:49 after the US close of Fri 20 Nov never reached GIR. Reuters and CNBC only through Google News (cnbc.com 403, Reuters no RSS). Lag: Nasdaq.com 55 min (n=5); Google News Reuters wrap 771 min and US-markets search 1190 min (catch-up of old stories at start); MarketWatch and ET US-stocks gave 0 rows; Moneycontrol international RSS is dead (newest item Apr 2024).
- **India 10-yr G-sec yield (Trading Economics)** - CCIL (the official NDS-OM source) blocks this server (403); TE is a stand-in.
- **RBI press releases / notifications / speeches** - Notifications RSS newest item is 11 Nov (no new rows since start); speeches 0 rows. Saturday quiet is normal. Lag: n=5.
- **SEBI What's New + circulars listing** - SEBI's own RSS has 0 items; the listing pages are used.
- **CCI press releases** - Polls parse (status ok) but 4 x HTTP 429 in 2 days; no new release since start; the old newshawk CCI scrape has nothing since 10 Nov either, so probably just no releases.
- **Parliament (sansad.in JSON)** - Parliament is not sitting (Winter Session not yet in sansad.in data). Lag: n=1.
- **e-Gazette (page watch)** - Blind: the home page shows only 10 links; the Extraordinary list sits behind an ASP.NET postback that a plain GET does not reach.
- **CBIC GST / CDSCO / APTEL (page watch)** - All three fetch OK (79 / 53+53 / 9 links) but no new link since the seed; cannot prove they would catch one.
- **AERA / GERC (page watch)** - AERA read timed out at 13:4x today (retries).
- **Index providers (NSE Indices, BSE index, FTSE)** - MSCI answers a bot challenge (blocked); MSCI dates kept by hand.
- **DIPAM OFS pages** - Polls OK; no new link since the seed, so ofs.jsonl does not exist yet. Exchange OFS notices also come through the circulars poller.
- **Economic week + NSE board meetings calendar** - 126 econ rows, 25 board meetings. India data (CPI / IIP / GDP / PMI) missing: no calendar_india.json hand list.
- **Wires: Business Standard latest RSS (v2)** -  Saturday: no market-word story since Fri 23:40 (the old system's BS feeds agree). Lag: n=9; rows only for F&O names or market words.
- **Wires: Business Standard markets RSS (v2)** -  Lag: n=3; rows only for F&O names or market words.
- **Wires: Moneycontrol news sitemap (v2)** - HTTP 403 to this server 00:00-07:00 IST on 21 Nov (16 refusals), fine again after 07:00. Lag: n=24; rows only for F&O names or market words.
- **TV analyst-call detector (v2)** - Weekend: no calls (expected).
- **Broker calls register (v2, derived)** - 254 calls in 72 threads; 3-day sources: TV 15, ET/MC wires 12, Google News 5. No direct broker research feed exists (see not-live list).
- **TV CNBC-TV18 speech-to-text** - Fri 09:00-15:30: 389.7 of 390 min captured. Listening on Saturday because the v2 news reader set an escalation at 12:49 IST. Lag: estimate: 10-s segment + Deepgram ~1.8 s; no broadcast time exists.
- **TV ET NOW speech-to-text** - Fri 09:00-15:30: 390 of 390 min. Lag: estimate (as above).
- **NSE announcements (old exchange.py)** - Duplicate of the v2 NSE feed; BSE not read by design. Lag: n=207.
- **Google News per share (newsroom scouts)** - The desk's biggest card source, and the slowest: median 1.6 h after publication. 191 HTTP 429 since Fri 00:00. Lag: n=2180 (Google's own pubDate vs first seen).
- **Old macro.py direct RSS: ET (5 feeds)** - ET RSS is cached 2-10 min; the v2 sitemap reader is faster. Lag: n=4 (F&O-named subset).
- **Old macro.py: Moneycontrol RSS (4 feeds)** - DEAD feed (newest item April 2024) still polled every 60 s by macro.py, newshunt and newshawk. Replace with the sitemap (v2 already does).
- **Old macro.py: live blogs (MC, CNBC-TV18, ET)** - Market-day only (no Saturday blogs; CNBC blog link 404 today). ET's blog is slow. Lag: MC 1.0 (n=188), CNBC 0.8 (n=47), ET 65.6 (n=31).
- **Old macro.py: BS / NDTV Profit / Business Today RSS** -  Lag: BS 10.4, NDTV Profit 37.9, Business Today 11.6.
- **Old macro.py: The Hindu Business + TOI Business RSS** - Answer HTTP 200 (60 and 20 items) but no F&O-named row has ever been stored.
- **Old macro.py: Google News searches (13 feeds)** - site:zeebiz returns 0 items; FE and ET Auto 1 each. Lag: n=235.
- **Old macro.py: RBI + SEBI RSS** - HTTP 200 but 0 items parsed for both (SEBI RSS is empty; RBI parse fails). v2 p_regs covers both.
- **Old govwatch (PIB / RBI / SEBI / IRDAI)** - Reads irdai.gov.in although its robots.txt says Disallow: / (v2 skips IRDAI for that reason).
- **Old regwatch (30 regulator pages)** - The only reader of fda.gov, cercind, pngrb, ED and prsindia; health cannot be measured.
- **Old shockwatch (Google News shock words)** - 
- **Old earlyteam world news (12 Google News queries)** - APEC, Trump-Xi, US-China, Fed, tariffs, OPEC, rupee, chips, Middle East. Cap reached (400).
- **Old overnight Google News (papers, world wires, commodities)** - Its AI step is behind the OLD_AI_OFF flag since 21 Nov 10:06.
- **Old newshunt (sector jump -> reason)** -  Lag: n=67.
- **Old policymap (policy stories -> shares)** - No output since 19 Nov 18:18: each share needs an AI read and the old AI is off. Lag: older rows.
- **Old moverswhy (why the big movers moved)** - All 20 rows of the last run say 'error' (AI read failed); the fetch itself runs.
- **Old expect.py (brokers' numbers for results)** - 0 broker numbers found in the last 7 days.
- **Article bodies (Google link -> publisher page)** - 299 of 473 with text in 24 h.
- **newshawk: NSE announcements RSS** - NSE board-meeting / insider RSS also read; Results / Buyback / Circulars RSS never stored a row. Lag: n=64 (F&O-named).
- **newshawk: ET / Mint / BS / Livemint RSS** -  Lag: ET 17.5, ET stocks 27.9, Mint 3.0, BS 10.0 (F&O-named).
- **newshawk: Moneycontrol RSS (3 feeds)** - Dead feed, still polled.
- **newshawk: Google News (Nifty, Reuters markets, regulators, drafts, courts, healthcare)** - ~120 HTTP 429 in 72 h across these queries. Lag: Nifty 10.5, Reuters 15.2, regulators 12.5, drafts 36.0, SC 9.2, healthcare 14.8; NCLT query only re-surfaces old items.
- **newshawk: CNBC Top / Finance RSS** - BLOCKED: HTTP 403 on every try (100+ failures).
- **newshawk: Yahoo Finance RSS** - DEAD: HTTP 404 (180 failures).
- **newshawk: MarketWatch top stories RSS** - 10 read timeouts in 72 h. Lag: n=8.
- **newshawk: Investing.com news RSS** - investing.com is said to block cloud machines; this RSS still answers here (quotes pages 403 per p_bonds). Lag: n=51.
- **newshawk-regwatch: PIB / IRDAI / RBI notifications / CCI / TRAI / GST Council / DGCA** - PIB fine; CCI/DGCA/TRAI timeouts and 5xx; GST Council scraper likely broken (nothing for 6 weeks).
- **newshawk-regwatch + regnews: Google News regulator / court / USFDA queries** - ~450 HTTP 429 in 72 h (regnews alone); neither bot honours the shared Google cool-down.
- **newshawk-filings: BSE announcements API** - Page 2 answers 403 since Fri 16:16 (same moment v2 was blocked); only the newest ~50 per cycle are read. The ONLY live BSE filings reader on the server right now.
- **newshawk-xstream: X filtered stream (TV + govt + wires accounts)** - DEAD: HTTP 402 CreditsDepleted every 5 min; the X account has no API credits (old xagent also off for the same reason).

## 4. Planned sources NOT BUILT (nobody reads them)

| Source | Category | Host(s) | Why | Suggested date |
|---|---|---|---|---|
| Global peers' results (US / Asia peers of Indian F&O names: Accenture, Cognizant, TSMC, Nvidia, steel / pharma peers) | global peers' results | SEC EDGAR / company IR / Nasdaq earnings calendar | not built; only ADR prices (Yahoo) and US wrap stories | Sat 28 Nov |
| Broker research reports (target / rating changes, morning notes) | broker calls | trendlyne.com, icicidirect.com, motilaloswal.com, kotaksecurities.com | not built; broker calls only from TV text and headlines (v2 broker_calls.json) | Trendlyne needs the trader's yes (paid); public PDFs Phase 2 (by 12 Dec) |
| CNBC Awaaz speech-to-text | TV speech-to-text | hindi.cnbctv18.com / YouTube | not built (only CNBC-TV18 and ET NOW are transcribed) | Phase 2 (by 12 Dec); adds Deepgram cost - trader's yes |
| Sansad TV live speech-to-text | TV / Parliament | hls.media.nic.in | not built (sansadtv.nic.in times out from here; the HLS host was never tried) | before the Winter Session starts (early Dec) |
| RBI / PIB / SEBI press conferences live (YouTube auto-start) | TV / regulators | youtube.com channel RSS | not built | Phase 2 (by 12 Dec); before the 5 Dec RBI policy if possible |
| Telegram public channels listener / t.me preview | wires (push) | t.me | not built | Phase 2 (by 12 Dec) |
| Reuters direct (sitemap) | wires | www.reuters.com | blocked: 401 bot wall; Reuters only via Google News (slow) | not planned (do not evade); keep Google News |
| Bloomberg headlines | wires | www.bloomberg.com | bot-blocked; only Google News site: queries | needs the trader's yes (paid ~$35/mo) |
| Federal Reserve statements / speeches RSS | world (central banks) | www.federalreserve.gov | not built | Tue 24 Nov (add to p_world) |
| BIS central-banker speeches RSS / BoJ / PBoC | world (central banks) | www.bis.org, www.boj.or.jp, pbc.gov.cn | not built | Sat 28 Nov |
| EIA weekly petroleum / OPEC statements | commodities | www.eia.gov, www.opec.org | not built live (EIA only in a history script) | Sat 28 Nov |
| GST Council decisions | GST | www.gstcouncil.gov.in | not built in v2; old newshawk scraper broken (nothing for 6 weeks) | Tue 24 Nov (page watch) |
| DGFT / DGTR notices (export curbs, anti-dumping) | government | www.dgft.gov.in, www.dgtr.gov.in | not built (DGTR only via Google News in newshawk) | Sat 28 Nov |
| Tribunals: NCLT / NCLAT / SAT / TDSAT / NGT / CESTAT / Delhi HC cause lists | courts | nclt.gov.in, nclat.nic.in, satweb.sat.gov.in, tdsat.gov.in, greentribunal.gov.in, cestat.gov.in, delhihighcourt.nic.in | not built (NCLT has a captcha) | Phase 2 (by 12 Dec) |
| India data calendar (CPI / IIP / GDP / PMI release times) | summits / calendar | www.mospi.gov.in, pmi.spglobal.com | not built: calendar_india.json hand list missing (GDP is due 30 Nov) | Tue 24 Nov (hand list), MOSPI page watch Sat 28 Nov |
| ET Prime article reader | wires (paywalled) | economictimes.indiatimes.com (ET Prime) | login is kept alive (gir-v2etprime, LIVE at 07:15) but no reader uses the session for articles | decide: build or stop the keep-alive (Sat 28 Nov) |
| Prediction-market odds (Fed, tariffs, war) | world | gamma-api.polymarket.com, api.elections.kalshi.com | not built: needs a fixed market list from the desk | Sat 28 Nov, after the desk gives the list |
| GDELT geopolitics feed | world | api.gdeltproject.org | only a study script; no live feed | Phase 2 (by 12 Dec) |
| SEC EDGAR / Business Wire / PR Newswire (ADR names, US clients) | global peers / wires | www.sec.gov, businesswire.com, prnewswire.com | not built (SEC needs a contact User-Agent) | Phase 2 (by 12 Dec) |
| X (Twitter) accounts: TV, government, DIPAM, CCI | X / social | api.x.com | both readers off: HTTP 402, no API credits | needs the trader's yes (buy credits) |

## 5. Hosts known to block cloud machines - is this server reading them?

| Host | Blocks cloud machines? (WEB_SOURCES) | Read by this server? | Last item (IST) |
|---|---|---|---|
| www.nseindia.com | yes (403 site) | yes - v2 filings, circulars, insider, block deals; old exchange.py | 21 Nov 12:49 (F&O filing); 13:44 any company |
| nsearchives.nseindia.com | needs allowlisting | yes - newshawk NSE RSS, whales bulk/block CSV, archive files | 21 Nov 12:52 |
| api.bseindia.com | needs allowlisting | PARTLY - v2 blocked (403 since 20 Nov 16:16); newshawk page 1 only | v2: 20 Nov 16:15 · newshawk: 21 Nov 13:37 |
| www.ndtvprofit.com | yes (403 site) | sitemap 403 here too; NDTV Profit read via feeds.feedburner.com | 21 Nov 13:08 (feedburner) |
| www.reuters.com | yes (DataDome) | NO - 401 bot wall; only through Google News | Google News Reuters wrap 21 Nov 09:59 |
| www.bloomberg.com | yes | NO - only Google News site: queries | - |
| www.investing.com | yes (Cloudflare) | news RSS yes (newshawk, uswrap); quote pages 403 | 21 Nov 04:42 (RSS) |
| www.youtube.com | yes (bot check) | yes - TV capture via yt-dlp with cookies | 21 Nov 13:37 |
| query1.finance.yahoo.com | sometimes 429 | yes - v2 world quotes, old earlyteam | 21 Nov 13:48 |
| www.ccilindia.com | - | NO - 403 Akamai here too (Trading Economics instead) | - |
| www.msci.com | - | NO - bot challenge here too | - |
| www.cnbc.com | - | NO - 403 here (newshawk 100+ failures) | 15 Nov 18:30 |
| www.cmegroup.com | yes | not tried | - |

## 6. Every host in WEB_SOURCES.md / COLLECTION_PLAN.md that is NOT live

Found by pulling every hostname out of the two files (`/home/globalbot/preview_src/intraday_patches/design_v3/`), then checking which GIR code reads it and whether its store has fresh items. LIVE hosts (34): aera.gov.in, api.sci.gov.in, bseindia.com, business-standard.com, cnbctv18.com, dipam.gov.in, economictimes.indiatimes.com, etnownews.com, federalregister.gov, financialjuice.com, fpi.nsdl.co.in, gercin.org, home.treasury.gov, investinglive.com, livelaw.in, livemint.com, moneycontrol.com, nasdaq.com, news.google.com, nfs.faireconomy.media, niftyindices.com, nsearchives.nseindia.com, nseindia.com, pib.gov.in, query1.finance.yahoo.com, rbi.org.in, sansad.in, sci.gov.in, sebi.gov.in, thehindubusinessline.com, trai.gov.in, westmetall.com, whitehouse.gov, youtube.com.

Dates: *Tue 24 Nov* = NSE holiday, a small addition to an existing v2 poller; *Sat 28 Nov* = a new small poller or page watch; *Phase 2 (by 12 Dec)* and *Phase 3 (Jan 2027)* follow COLLECTION_PLAN section 9; *needs the trader's yes* = paid, key or sign-up; *not planned* = blocked / robots / legacy (never evade a block).

### PARTIAL (20)

- `api.bseindia.com` - v2 filings BLOCKED (403 since Fri 16:16); old newshawk-filings reads page 1 only (13:37 today). **When:** fix now: ask why BSE refuses v2's client (headers / cookie); until then wire newshawk's BSE rows into v2 - before Mon 23 Nov 09:00.
- `aptel.gov.in` - v2 pagewatch polls OK, 0 new links since 20 Nov (unproven). **When:** check on the next weekday.
- `cbic-gst.gov.in` - v2 pagewatch polls OK (79 links), 0 new since 20 Nov (unproven). **When:** check on the next weekday.
- `cci.gov.in` - v2 p_regs parses but 429s and 0 rows since start; probably no releases. **When:** Tue 24 Nov (NSE holiday - small add to an existing poller) (slow it to 300 s to stop the 429s).
- `cdsco.gov.in` - v2 pagewatch polls OK (53+53 links), 0 new since 20 Nov (unproven). **When:** check on the next weekday.
- `cercind.gov.in` - old regwatch.py only (health not measurable); newshawk CERC via Google News. **When:** Sat 28 Nov (new small poller / page watch) (v2 page watch).
- `dgca.gov.in` - old regwatch.py + newshawk scrape (5xx errors, nothing since 13 Nov); v2 skips (script-only portal). **When:** Phase 3 (Jan 2027).
- `dgtr.gov.in` - only Google News in newshawk. **When:** Sat 28 Nov (new small poller / page watch).
- `egazette.gov.in` - v2 pagewatch is blind: the Extraordinary list needs an ASP.NET postback. **When:** Sat 28 Nov (new small poller / page watch) (form post or another listing page).
- `fda.gov` - old regwatch.py only (FDA press RSS 404 for v2); USFDA via Google News in newshawk. **When:** Sat 28 Nov (new small poller / page watch) (warning-letter page watch in v2).
- `financialexpress.com` - only a Google News site: query (1 item in 24 h). **When:** Sat 28 Nov (new small poller / page watch) (FE sitemap / RSS).
- `fssai.gov.in` - only Google News in newshawk. **When:** Phase 3 (Jan 2027).
- `gstcouncil.gov.in` - old newshawk scraper broken (nothing since 9 Oct); v2 none. **When:** Tue 24 Nov (NSE holiday - small add to an existing poller) (page watch).
- `investing.com` - newshawk news RSS answers (04:42 today) and uswrap wraps; quote pages 403. **When:** not planned for quotes.
- `irdai.gov.in` - robots.txt Disallow: / - v2 respects it; the OLD govwatch and newshawk-regwatch still read it (last 20 Nov 20:05). **When:** decide (Sat 28 Nov): stop the old readers or get a written OK; use PIB / news meanwhile.
- `ndtvprofit.com` - sitemap 403 to this server; the feedburner RSS is read (13:08 today, ~38 min late). **When:** not planned for the sitemap.
- `pngrb.gov.in` - old regwatch.py only (unmeasured). **When:** Sat 28 Nov (new small poller / page watch).
- `prsindia.org` - old regwatch.py only (v2 has a parser but it is not in the poll list). **When:** before the Winter Session (early Dec).
- `trumpstruth.org` - v2 p_trump polls OK but only 1 post in 24 h vs 16 Friday - check the mirror. **When:** check by hand before Sun 19:45.
- `zeebiz.com` - only a Google News site: query that returns 0 items. **When:** Sat 28 Nov (new small poller / page watch).

### BLOCKED (15)

- `bloomberg.com` - bot wall; Google News site: only. **When:** needs the trader's yes.
- `bombayhighcourt.nic.in` - times out from this server. **When:** Phase 2 (by 12 Dec) (retry).
- `ccilindia.com` - 403 Akamai on every path; Trading Economics used instead. **When:** not planned (keep TE; do not evade).
- `cmegroup.com` - bot-blocked on cloud machines (plan); not tried. **When:** not planned.
- `cnbc.com` - 403 to this server (newshawk 100+ failures); CNBC wraps via Google News only. **When:** not planned.
- `eparlib.sansad.in` - times out from this server. **When:** not planned.
- `indianrailways.gov.in` - 403 to this server. **When:** not planned.
- `mca.gov.in` - 403 to this server. **When:** not planned.
- `msci.com` - bot challenge; MSCI dates kept by hand. **When:** not planned.
- `npci.org.in` - 403 to this server. **When:** not planned.
- `nppaindia.nic.in` - no DNS from this server; old regwatch.py still lists it. **When:** not planned.
- `policyholder.gov.in` - robots Disallow: /. **When:** not planned.
- `reuters.com` - 401 bot wall; via Google News only. **When:** not planned.
- `sansadtv.nic.in` - times out from this server; use hls.media.nic.in. **When:** before the Winter Session (early Dec).
- `tnerc.tn.gov.in` - certificate expired 22 Oct 2026. **When:** not planned until the site fixes it.

### DEAD (3)

- `feeds.a.dj.com` - WSJ RSS frozen since Jan 2025; MarketWatch via feeds.content.dowjones.io is read instead. **When:** not planned.
- `feeds.reuters.com` - Reuters RSS retired. **When:** not planned.
- `nitter.net` - X mirror (not used). **When:** not planned.

### NOT BUILT (104)

- `accessdata.fda.gov` - FDA import alerts not read. **When:** Sat 28 Nov (new small poller / page watch).
- `aljazeera.com` - Middle East RSS not read. **When:** Sat 28 Nov (new small poller / page watch).
- `amfiindia.com` - AMFI monthly flows not read. **When:** Phase 3 (Jan 2027).
- `api.bls.gov` - US CPI / payroll actuals: only via FinancialJuice / investingLive headlines. **When:** Phase 2 (by 12 Dec).
- `api.elections.kalshi.com` - needs a market list. **When:** Sat 28 Nov (new small poller / page watch).
- `api.fda.gov` - openFDA not read. **When:** Phase 2 (by 12 Dec).
- `api.stlouisfed.org` - FRED needs a free key (sign-up not done). **When:** needs the trader's yes (sign-up for a free key).
- `apnews.com` - AP wire not read. **When:** Sat 28 Nov (new small poller / page watch).
- `barandbench.com` - only in a check script; LiveLaw is read instead. **When:** Sat 28 Nov (new small poller / page watch).
- `bis.org` - central-banker speeches RSS. **When:** Sat 28 Nov (new small poller / page watch).
- `bls.gov` - as api.bls.gov. **When:** Phase 2 (by 12 Dec).
- `boj.or.jp` - BoJ decisions. **When:** Sat 28 Nov (new small poller / page watch).
- `cabsec.gov.in` - not confirmed by the plan either. **When:** Phase 3 (Jan 2027).
- `cdnbbsr.s3waas.gov.in` - ministry PDF host. **When:** Phase 3 (Jan 2027).
- `cea.nic.in` - power demand / generation. **When:** Phase 3 (Jan 2027).
- `cestat.gov.in` - cause lists. **When:** Phase 2 (by 12 Dec).
- `chemicals.gov.in` - QCO orders. **When:** Phase 3 (Jan 2027).
- `chinamoney.com.cn` - China rates (plan WP job). **When:** Phase 2 (by 12 Dec).
- `chittorgarh.com` - IPO / QIP calendar. **When:** Phase 3 (Jan 2027).
- `civilaviation.gov.in` - releases. **When:** Phase 3 (Jan 2027).
- `coal.gov.in` - coal auctions. **When:** Phase 3 (Jan 2027).
- `coal.nic.in` - coal press PDFs. **When:** Phase 3 (Jan 2027).
- `commerce.gov.in` - monthly trade data. **When:** Phase 3 (Jan 2027).
- `dea.gov.in` - borrowing calendar. **When:** Phase 3 (Jan 2027).
- `delhihighcourt.nic.in` - cause lists. **When:** Phase 2 (by 12 Dec).
- `dgft.gov.in` - export / import notices. **When:** Sat 28 Nov (new small poller / page watch).
- `dot.gov.in` - telecom what's new. **When:** Sat 28 Nov (new small poller / page watch).
- `drdo.gov.in` - low value. **When:** Phase 3 (Jan 2027).
- `drewry.co.uk` - freight index. **When:** Phase 3 (Jan 2027).
- `eaindustry.nic.in` - core-sector data. **When:** Phase 3 (Jan 2027).
- `eia.gov` - weekly petroleum status: only a history script (kb/fetch_free.py), no live read. **When:** Sat 28 Nov (new small poller / page watch).
- `elibrary.sansad.in` - committee reports. **When:** Phase 3 (Jan 2027).
- `english.news.cn` - Xinhua readouts. **When:** Sat 28 Nov (new small poller / page watch).
- `fada.in` - monthly retail auto sales. **When:** Phase 3 (Jan 2027).
- `federalreserve.gov` - Fed RSS. **When:** Tue 24 Nov (NSE holiday - small add to an existing poller).
- `fert.gov.in` - NBS rates. **When:** Phase 3 (Jan 2027).
- `financialservices.gov.in` - DFS what's new. **When:** Sat 28 Nov (new small poller / page watch).
- `fred.stlouisfed.org` - FRED CSV not read. **When:** Phase 2 (by 12 Dec).
- `gamma-api.polymarket.com` - needs the desk's market list. **When:** Sat 28 Nov (new small poller / page watch).
- `greentribunal.gov.in` - NGT orders. **When:** Phase 2 (by 12 Dec).
- `grid-india.in` - power reports. **When:** Phase 3 (Jan 2027).
- `hindi.cnbctv18.com` - CNBC Awaaz. **When:** Phase 2 (by 12 Dec).
- `hls.media.nic.in` - Sansad TV HLS for speech-to-text. **When:** before the Winter Session (early Dec).
- `hq.sinajs.cn` - China quotes (plan WP job). **When:** Phase 2 (by 12 Dec).
- `ibbi.gov.in` - IBC orders. **When:** Phase 3 (Jan 2027).
- `ibjarates.com` - gold / silver rates. **When:** Phase 3 (Jan 2027).
- `icicidirect.com` - public research PDFs. **When:** Phase 2 (by 12 Dec).
- `iexindia.com` - power exchange prices. **When:** Sat 28 Nov (new small poller / page watch).
- `ifsca.gov.in` - GIFT City rules (low value). **When:** Phase 3 (Jan 2027).
- `incometaxindia.gov.in` - CBDT notifications. **When:** Sat 28 Nov (new small poller / page watch).
- `iocl.com` - fuel price page (plan J49). **When:** Phase 3 (Jan 2027).
- `kerc.karnataka.gov.in` - host not verified. **When:** Phase 3 (Jan 2027).
- `kotaksecurities.com` - public research. **When:** Phase 2 (by 12 Dec).
- `meity.gov.in` - IT rules / semiconductor approvals. **When:** Phase 3 (Jan 2027).
- `merc.gov.in` - Maharashtra power orders. **When:** Phase 3 (Jan 2027).
- `mines.gov.in` - auction tranches. **When:** Phase 3 (Jan 2027).
- `mnre.gov.in` - ALMM orders. **When:** Phase 3 (Jan 2027).
- `mod.gov.in` - mostly mirrored on PIB (read). **When:** Phase 3 (Jan 2027).
- `mopng.gov.in` - windfall tax / gas price orders. **When:** Phase 3 (Jan 2027).
- `morth.gov.in` - low F&O impact. **When:** Phase 3 (Jan 2027).
- `morth.nic.in` - low F&O impact. **When:** Phase 3 (Jan 2027).
- `mospi.gov.in` - release calendar (GDP 30 Nov). **When:** Sat 28 Nov (new small poller / page watch).
- `motilaloswal.com` - public research. **When:** Phase 2 (by 12 Dec).
- `nclat.nic.in` - cause lists. **When:** Phase 2 (by 12 Dec).
- `nclt.gov.in` - captcha on orders. **When:** Phase 2 (by 12 Dec).
- `newsonair.gov.in` - AIR (second witness for PIB). **When:** Sat 28 Nov (new small poller / page watch).
- `nhai.gov.in` - tenders. **When:** Phase 3 (Jan 2027).
- `niftytrader.in` - OI witness for the Outside Watch. **When:** Phase 3 (Jan 2027).
- `npp.gov.in` - daily generation PDF. **When:** Phase 3 (Jan 2027).
- `ofac.treasury.gov` - sanctions actions. **When:** Sat 28 Nov (new small poller / page watch).
- `opec.org` - OPEC+ statements. **When:** Sat 28 Nov (new small poller / page watch).
- `opstra.definedge.com` - IV witness (login for real time). **When:** Phase 3 (Jan 2027).
- `pbc.gov.cn` - PBoC. **When:** Sat 28 Nov (new small poller / page watch).
- `pfrda.org.in` - low value. **When:** Phase 3 (Jan 2027).
- `pmi.spglobal.com` - PMI release times. **When:** Sat 28 Nov (new small poller / page watch).
- `powermin.gov.in` - announcements. **When:** Sat 28 Nov (new small poller / page watch).
- `ppac.gov.in` - fuel prices / gas price. **When:** Phase 3 (Jan 2027).
- `public.api.bsky.app` - low value. **When:** Phase 3 (Jan 2027).
- `pulse.zerodha.com` - news aggregator (Outside Watch). **When:** Phase 3 (Jan 2027).
- `report.grid-india.in` - daily PSP PDFs. **When:** Phase 3 (Jan 2027).
- `results.eci.gov.in` - counting days only. **When:** Phase 3 (Jan 2027).
- `rsdebate.nic.in` - debate archive. **When:** Phase 3 (Jan 2027).
- `rsdoc.nic.in` - RS questions back end. **When:** Phase 3 (Jan 2027).
- `sat.gov.in` - SAT orders. **When:** Phase 2 (by 12 Dec).
- `satweb.sat.gov.in` - SAT orders. **When:** Phase 2 (by 12 Dec).
- `scmp.com` - China news RSS. **When:** Sat 28 Nov (new small poller / page watch).
- `scobserver.in` - pending SC matters. **When:** Phase 3 (Jan 2027).
- `sec.gov` - EDGAR (needs a contact User-Agent). **When:** Phase 2 (by 12 Dec).
- `siam.in` - monthly auto data. **When:** Phase 3 (Jan 2027).
- `static.pib.gov.in` - PDF host behind PIB releases. **When:** Phase 3 (Jan 2027).
- `stats.gov.cn` - China data releases. **When:** Phase 2 (by 12 Dec).
- `steel.gov.in` - releases. **When:** Phase 3 (Jan 2027).
- `stooq.com` - only in the old morning.py (not running); Yahoo is read. **When:** Phase 3 (Jan 2027).
- `t.me` - public channel preview. **When:** Phase 2 (by 12 Dec).
- `taxinformation.cbic.gov.in` - customs / ADD notifications. **When:** Sat 28 Nov (new small poller / page watch).
- `tdsat.gov.in` - cause lists. **When:** Phase 2 (by 12 Dec).
- `tis.nhai.gov.in` - toll info. **When:** Phase 3 (Jan 2027).
- `trendlyne.com` - broker reports (paid). **When:** needs the trader's yes.
- `ukmto.org` - shipping security advisories. **When:** Sat 28 Nov (new small poller / page watch).
- `uperc.org` - UP power orders. **When:** Phase 3 (Jan 2027).
- `ustr.gov` - US trade releases. **When:** Sat 28 Nov (new small poller / page watch).
- `vahan.parivahan.gov.in` - registrations (dashboard). **When:** Phase 3 (Jan 2027).
- `web.sensibull.com` - login likely. **When:** Phase 3 (Jan 2027).
- `zerodha.com` - bulletin RSS (exchange circulars are read directly). **When:** Phase 3 (Jan 2027).

### NOT NEEDED (10)

- `archive.pib.gov.in` - archive search; live PIB RSS is read. **When:** not planned.
- `eparlib.nic.in` - archive. **When:** not planned.
- `forexlive.com` - renamed investinglive.com (read). **When:** not planned.
- `lme.com` - Westmetall gives LME official prices (read). **When:** not planned.
- `loksabha.nic.in` - legacy, replaced by sansad.in. **When:** not planned.
- `loksabhaph.nic.in` - legacy. **When:** not planned.
- `mcxindia.com` - MCX comes through Kite. **When:** not planned.
- `nseix.com` - GIFT NIFTY comes through Kite. **When:** not planned.
- `pmindia.gov.in` - Cabinet mirrored on PIB (read). **When:** not planned.
- `rajyasabha.nic.in` - legacy. **When:** not planned.

## 7. What I could not measure, and why

- Lag for sources that store one time only: BSE filings in newshawk (BSE time not kept), NSE circulars / SEBI / NSE index notices / NSDL / block lists (date only), page watches (pages give no time), regwatch / regnews / govwatch / shockwatch (seen-sets without times), X (tweet time only), Yahoo quotes (quote time not kept).
- TV lag: there is no broadcast timestamp; ~0.2 min is the 10-s segment plus Deepgram's ~1.8 s. Audio is not kept.
- Per-feed counts for the old macro.py RSS and newshawk feeds: their stores keep only headlines that name an F&O company (news.db WIRE, ledger.db live_news), so 24 h counts there are lower bounds. v2 wires rows are also filtered (F&O names or market words).
- Whether a quiet feed is empty or broken (Moneycontrol RSS, NSE results/buyback RSS, RBI notifications, CCI, DIPAM, CBIC, CDSCO, APTEL, Trump mirror, pledge events): proving it needs a live fetch, which this audit did not do.
- Reader cards per v2 wires part (ET vs CNBC vs Moneycontrol): the card payload says `wires` only.
- FinancialJuice delay vs the paid squawk, and investingLive's late publishing: measured only against each feed's own timestamp.
- Journal retention is ~3.5 days, so error histories before 17-18 Nov (e.g. when the X credits ran out) are not available; last X post stored is 29 Oct.
- Store times are IST from the code's own clocks; the server clock is UTC (systemd timer times above were converted).

## 8. For the source-silence alarm

Each JSON row has `status`, `core`, `silent_threshold_min` (30 core / 120 others), `alarm_window_ist` and `last_item_ist`. Suggested use: alarm when now - last item > threshold **inside** the window and on a trading day; skip rows with `proven: false` until a first real item is seen; for daily / dated sources (NSDL, cause lists, FII/DII, calendars) alarm on "today's file missing by its usual time" instead of minutes. The cleanest per-source health already on disk: `v2/data/ext/status.json` (state, last_ok, last_item per v2 poller), `v2/data/filings_state.json` (per exchange status / back-off), tv.db (latest ts per channel).
