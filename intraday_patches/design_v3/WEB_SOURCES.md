# WEB SOURCES - outside websites, feeds and APIs worth reading, by host (20 Nov 2026)

What this is: the host-by-host list of external sites that would help the trader's CE / PE calls, beyond what GIR already
has, with a reachability test from the cloud desk session (the one that runs the Outside Watch). Read with
EXTERNAL_SOURCES_MISSING.md (ESM, the *why* and the examples) and BUILD_PLAN 1.2 (feeds F01-F31, what the server has).
This file adds the **hostnames, the feed type, who should read each one, and whether this session can reach it today**.

**Tested** 20 Nov 2026, 10:50-11:00 IST, from this session, with
`curl -s -o /dev/null -m 12 -A "Mozilla/5.0" -w "%{http_code} %{http_connect}" https://HOST/`.

| Code in the table | Meaning |
|---|---|
| `200` | answers from here now |
| `403 site` | the proxy let us through, the **site itself** refused (blocks cloud machines) |
| `000 proxy` | the session proxy refused the connection: **not on this session's allowlist yet** (nothing is known about the site itself) |

**This session's allowlist today has only 8 hosts:** www.business-standard.com, www.cnbctv18.com, www.ndtvprofit.com,
www.moneycontrol.com, economictimes.indiatimes.com, www.nseindia.com, www.bseindia.com, www.livemint.com. Of these,
**www.nseindia.com and www.ndtvprofit.com return 403 from the site** (they block cloud machines), so the Outside Watch
effectively has 6 working hosts. Every other host below returned `000 proxy`.

**Status column:** **NEW** = in neither BUILD_PLAN 1.2 nor ESM. **ESM #n** = ESM lists the need, nothing collects it yet;
this file confirms the host and feed. **F##** = the server already has (or plans) this feed; listed only because the
**Outside Watch** needs its own copy to score GIR independently.

**Labels:** [V] = confirmed on the web or by a live fetch today. [E] = expected / reported elsewhere, not tested here
(mostly because the proxy refused before the site could answer). Paid = needs the trader's yes before anything is bought.
Steps: 19:45 note, 07:15 note, 09:08 pre-open, live (09:15-15:30), scoring (15:45 audit and the Outside Watch).

---

## 0. Found while testing (act on these first)

1. **Moneycontrol RSS is dead.** `moneycontrol.com/rss/latestnews.xml` answers 200 but its newest item is 23 Apr 2024
   (lastBuildDate 26 Aug 2024) [V]. Use `moneycontrol.com/news/news-sitemap.xml` instead (newest item 10:59 IST today [V]).
   If F16 / gir-newsroom still reads the Moneycontrol RSS, it is reading nothing.
2. **Fresh feeds on hosts we already have** [V, today]: ET markets RSS `economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms`
   (10:24 IST item); Business Standard `business-standard.com/rss/markets-106.rss` (10:29); CNBC-TV18 Google-News sitemap
   `cnbctv18.com/commonfeeds/v1/cne/sitemap/google-news.xml` (10:51); Livemint `livemint.com/rss/markets` (35 items);
   BSE notices `bseindia.com/data/xml/notices.xml` (09:56 IST); Moneycontrol results calendar page (200).
3. **NSE blocks this session** (403 from the site). The Outside Watch cannot use NSE for filings or the ban list; it needs
   **api.bseindia.com** (BSE filings JSON) and **nsearchives.nseindia.com** (static CSVs) added - see block (1).
4. **CNBC Awaaz** lives on **hindi.cnbctv18.com** [V, Wikipedia], a separate host from the allowed www.cnbctv18.com.
5. **ForexLive is now investingLive** (investinglive.com, since 21 Jul 2025) [V]. Any old forexlive.com feed should move.
6. **No official RSS** for CNBC-TV18 (use the sitemap above), for FDA warning letters (page watch; the FDA 483 reading room
   does have a feed), or for FinancialJuice (free web headlines; a feed URL is not documented) [V].

---

## 1. The ranked table

Ranked by money made or saved for an intraday option buyer, most first. "Who" = SERVER (live feed on the GIR server),
OUTSIDE (the Outside Watch in this cloud session), BOTH.

| # | Host | What it gives | Why it helps the trader (CE / PE, step) | Free / paid | Who | Status | Reach now |
|---|---|---|---|---|---|---|---|
| 1 | api.bseindia.com | BSE corporate announcements / board meetings / results JSON (the API behind bseindia.com) | Every filing that moves a single F&O share (CE on order wins, PE on resignations / downgrades); the Outside Watch's only filings source since NSE blocks it. Live, scoring | Free | BOTH (server has it in F15) | F15 | `000 proxy` |
| 2 | nsearchives.nseindia.com | Static CSVs: F&O ban list (T+1), bhavcopy, FII / DII, participant OI, short-selling, MTF | Scoring: did GIR call a banned share, did the move happen (closes), who was positioned. 19:45 (ban list) | Free | BOTH (server has F11-F13) | F11-F13 | `000 proxy` |
| 3 | query1.finance.yahoo.com | JSON quotes / charts: US index futures (ES, NQ), US 10-yr, DXY, Brent, WTI, gold, copper, Nikkei, Hang Seng, KOSPI, ADRs | Overnight cue for the NIFTY gap; IT on dollar / US yields; OMCs / paints / INDIGO on crude. 19:45, 07:15, 09:08, scoring of the "drivers" line. Cloud IPs sometimes get 429 rate limits [E] | Free | OUTSIDE (server has F23) | F23 | `000 proxy` |
| 4 | stooq.com | Free CSV quotes (indices, futures, FX, yields) | Second witness for #3 when Yahoo rate-limits; same uses | Free | OUTSIDE (server F23 backup) | F23 | `000 proxy` |
| 5 | trumpstruth.org | RSS mirror of Trump's Truth Social posts (`/feed`) | Tariff / drug-price / H-1B posts -> pharma, IT, textiles, OMC PE or CE at the open. 19:45, overnight, 07:15 | Free | BOTH | ESM #3 | `000 proxy` |
| 6 | www.financialjuice.com | Real-time macro / geopolitical headline squawk (free web tier delayed; Pro ~$23/mo) | Closest free substitute for X while X is off: Fed, US data, oil, war headlines in seconds -> NIFTY / BANKNIFTY direction, IT, OMCs. Overnight, 07:15, live | Free tier; Pro paid | BOTH | ESM #2 | `000 proxy` |
| 7 | investinglive.com | Ex-ForexLive: fast free macro headlines and US-data actuals with commentary (RSS existed on ForexLive; confirm on the new site) | Same as #6, free, second witness for headline timing. Overnight, 07:15 | Free (LiveBytes premium paid) | BOTH | NEW | `000 proxy` |
| 8 | www.federalregister.gov | `api/v1/public-inspection-documents/current.json` - US rules hours before publication | Section 232 / 301 tariffs, export controls -> pharma, steel / aluminium (TATASTEEL, HINDALCO, VEDL), auto parts PE. 19:45, overnight | Free | SERVER (Outside reads the headline) | ESM #10 | `000 proxy` |
| 9 | www.sebi.gov.in | `sebirss.xml` - circulars, orders, press releases [V]; daily MF flows page | Rule changes for F&O (lot sizes, expiry, STT talk) -> BSE, ANGELONE, CDSL, CAMS; orders against companies (PE). Live, 19:45 | Free | OUTSIDE (server has F20) | F20 | `000 proxy` |
| 10 | rbi.org.in | `pressreleases_rss.xml`, `notifications_rss.xml`, `speeches_rss.xml` [V]; daily money-market ops | Policy, liquidity, bank actions -> BANKNIFTY, PSU banks, NBFCs CE / PE. Live, 07:15 (liquidity line) | Free | OUTSIDE (server F20) | F20 | `000 proxy` |
| 11 | pib.gov.in | `RssMain.aspx?ModId=6&Lang=2&Regid=3` press releases [V] (other Lang / Regid values, e.g. English, to confirm on ViewRss.aspx); cabinet, DAC, ministries | Cabinet decisions, defence orders, PLI, MSP, fertiliser subsidy -> sector CE / PE. Live, 19:45 (evening releases) | Free | OUTSIDE (server F20) | F20 | `000 proxy` |
| 12 | www.ccilindia.com | `/market-watch` NDS-OM live G-sec trades (10-yr yield), MTM prices [V] | 10-yr move >= 8 bp = rate-sensitives driver: banks, NBFCs, realty CE / PE. Live, scoring | Free | BOTH | ESM #11 | `000 proxy` |
| 13 | www.fpi.nsdl.co.in | `/web/Reports/Latest.aspx` daily FPI (T+1), fortnightly sector flows, red-flag list; daily DII since Jun 2026 [V] | Which sectors foreigners are selling -> the "tide" behind each sector call; 19:45, scoring | Free | BOTH | ESM #24 | `000 proxy` |
| 14 | www.sci.gov.in | Supreme Court cause lists (out the evening before), orders | IDEA / BHARTIARTL (AGR), miners, insolvency names listed tomorrow -> 07:15 "watch item 12". 19:45, 07:15 | Free | SERVER | ESM #4 | `000 proxy` |
| 15 | www.livelaw.in | Live court threads and order reports | When a tagged case is called: first text of the ruling -> the share CE / PE live | Free (paid tier for some) | SERVER | ESM #4 | `000 proxy` |
| 16 | www.barandbench.com | Same as #15, second witness | Same | Free | SERVER | ESM #4 | `000 proxy` |
| 17 | home.treasury.gov | US Treasury daily par yield curve (XML / CSV), auction results | Scoring the US-yields driver from the source; IT and banks via US rates. 07:15, scoring | Free | BOTH | ESM #26 | `000 proxy` |
| 18 | www.cnbc.com | US market quotes and free RSS feeds (`/id/<n>/device/rss/rss.html`) | US close story and pre-market for the 07:15 note; second witness for Yahoo | Free | OUTSIDE | NEW | `000 proxy` |
| 19 | www.westmetall.com | `/en/markdaten.php` LME official cash / 3-month prices (copper, aluminium, zinc, nickel, lead, tin) [V] | Fixes F23's wrong copper / aluminium proxies (BUILD_PLAN code issue b): HINDALCO, VEDL, NATIONALUM, HINDCOPPER; cables / ACs on copper. 19:45, scoring | Free | BOTH | F23 (better source) | `000 proxy` |
| 20 | www.niftyindices.com | NSE Indices press releases (index changes, rebalances) | Rebalance-day flows into / out of named shares at the close; 19:45 calendar | Free | BOTH | ESM #7 | `000 proxy` |
| 21 | www.msci.com | Index review announcements | Same, MSCI (Nov 2026 review effective 30 Nov close) | Free | SERVER | ESM #7 | `000 proxy` |
| 22 | www.whitehouse.gov | Presidential actions (orders, proclamations, fact sheets) | Formal tariff / visa actions behind the posts in #5 -> pharma, IT, metals. Overnight | Free | BOTH | ESM #3 | `000 proxy` |
| 23 | nfs.faireconomy.media | ForexFactory calendar JSON (`ff_calendar_thisweek.json`) | Event locks for the day (US CPI, Fed); the Outside Watch checks GIR flagged them. 19:45, scoring | Free | OUTSIDE (server has F22) | F22 | `000 proxy` |
| 24 | www.federalreserve.gov | `/feeds` RSS: statements, speeches, minutes | Fed surprise -> NIFTY gap, IT, banks. Overnight, 07:15 | Free | BOTH | ESM #15 | `000 proxy` |
| 25 | feeds.a.dj.com | Dow Jones / WSJ free headline RSS (markets, world) | Free fast global headlines; body is paywalled. Overnight, 07:15 | Free headlines; WSJ paid | BOTH | NEW | `000 proxy` |
| 26 | apnews.com | AP wire, free, fast on war / disasters / US politics | Geopolitical shocks (crude, defence CE, OMC PE). Overnight | Free | BOTH | NEW | `000 proxy` |
| 27 | pulse.zerodha.com | One page that aggregates Indian business-news RSS from most outlets, no login [V] | Outside Watch: one poll to see what every outlet ran, to score whether GIR missed a story. Live, scoring | Free | OUTSIDE | NEW | `000 proxy` |
| 28 | zerodha.com | `/marketintel/bulletin/?format=xml` - RSS of exchange bulletins / circulars [V] | F&O adds / exits, ASM / GSM, lot changes without hitting NSE. 19:45 | Free | BOTH | ESM #9 (alt route) | `000 proxy` |
| 29 | t.me | Public channel web preview `t.me/s/<channel>` (server-rendered HTML, no login) [V] | Reads outlets' and journalists' public Telegram channels without the Telegram client: a no-login fallback for F18 and the Outside Watch's push source | Free | BOTH | F18 (fallback) | `000 proxy` |
| 30 | news.google.com | `rss/search?q=...` per keyword / journalist name / company | Cheap catch-all for named journalists and companies; 15-min backfill only (F16 already says out of the alert path) | Free | OUTSIDE (server F16 backfill) | F16 | `000 proxy` |
| 31 | www.etnownews.com | ET Now's site: live blogs, TV clips, live TV in market hours [V] | Morning TV is a main input: text of what ET Now said at 07:15-09:08 for the Outside Watch to score; witness for F17 | Free | BOTH | F17 (witness) | `000 proxy` |
| 32 | hindi.cnbctv18.com | CNBC Awaaz (Hindi) site, live blog / stock calls | Retail-heavy calls that move mid-cap F&O names at the open; witness for F17 | Free | BOTH | F17 (witness) | `000 proxy` |
| 33 | www.zeebiz.com | Zee Business live blogs and TV stock calls | Same as #32 (Zee Business is another big retail channel) | Free | OUTSIDE | NEW | `000 proxy` |
| 34 | www.thehindubusinessline.com | Business news RSS; strong on commodities, agri, ports | Second-tier witness on policy / commodity stories | Free | BOTH | F16 (2nd tier) | `000 proxy` |
| 35 | www.financialexpress.com | Business news RSS / sitemap | Same | Free | BOTH | F16 (2nd tier) | `000 proxy` |
| 36 | www.iexindia.com | `/market-data/day-ahead-market/market-snapshot` DAM / RTM prices [V] | IEX share and power names (NTPC, TATAPOWER, ADANIPOWER, JSWENERGY) on price spikes; ~13:00. Live, scoring | Free | BOTH | F24 | `000 proxy` |
| 37 | www.fda.gov | Warning letters page; 483 reading-room RSS; recalls | Pharma PE on a warning letter / OAI (SUNPHARMA, DRREDDY, AUROPHARMA, LUPIN, ZYDUS). Overnight, 07:15 | Free | BOTH | NEW | `000 proxy` |
| 38 | www.accessdata.fda.gov | Import alerts database (firm-level) | Import alert on an Indian plant = pharma PE next open | Free | SERVER | NEW | `000 proxy` |
| 39 | dipam.gov.in | Government OFS / disinvestment notices | PSU OFS floor price -> COALINDIA, LICI, NHPC, IRFC PE at the open. 19:45 | Free | BOTH | ESM #8 | `000 proxy` |
| 40 | gamma-api.polymarket.com | Public market odds JSON, no key [V] | Odds of Fed cut / tariff / war for the 19:45 note; scoring "was the surprise priced?" | Free | OUTSIDE | ESM #28 | `000 proxy` |
| 41 | api.elections.kalshi.com | Kalshi public market data | Same, second witness | Free | OUTSIDE | ESM #28 | `000 proxy` |
| 42 | www.eia.gov | Weekly petroleum status (Wed ~21:00 IST), STEO | Crude inventory surprise -> OMC / paints / INDIGO next open | Free | SERVER | ESM #21 | `000 proxy` |
| 43 | www.opec.org | OPEC+ statements, monthly report | Same, on meeting days | Free | SERVER | ESM #21 | `000 proxy` |
| 44 | sansad.in | Bills, business of the day | Bill listed / passed -> policy basket CE / PE. Live while Parliament sits | Free | OUTSIDE (server F20) | F20 | `000 proxy` |
| 45 | sansadtv.nic.in | Sansad TV live / recorded (YouTube handle "sansadtv") [V] | Minister answers in the House move PSU / policy names live | Free | SERVER (F17 has it) | F17 | `000 proxy` |
| 46 | www.bis.org | `cbspeeches` RSS - every central banker in one feed | BoJ / PBoC / ECB surprises before our session -> metals, IT, NIFTY | Free | SERVER | ESM #15 | `000 proxy` |
| 47 | ofac.treasury.gov | Recent actions (sanctions) | Russia-oil sanctions -> RELIANCE, OMCs. Overnight | Free | SERVER | ESM #16 | `000 proxy` |
| 48 | ustr.gov | US trade press releases (India deal, 301) | Deal signing = textiles, auto parts, pharma CE | Free | SERVER | ESM #14 | `000 proxy` |
| 49 | www.bls.gov | CPI, payrolls actuals (api.bls.gov) | US data surprise -> IT / NIFTY gap | Free | SERVER | ESM #25 | `000 proxy` |
| 50 | api.stlouisfed.org | FRED API (free key): yields, HY spreads, breakevens, DXY broad | Overnight stress gauge for the 19:45 / 07:15 regime line | Free (key) | SERVER | ESM #26 | `000 proxy` |
| 51 | fred.stlouisfed.org | FRED web / CSV download (no key) | Same, for the Outside Watch | Free | OUTSIDE | ESM #26 | `000 proxy` |
| 52 | www.sec.gov | EDGAR filings (6-K for INFY, WIT, HDB, IBN, RDY; US clients' 8-Ks) | Overnight news on Indian ADR names and IT deal wins | Free (needs a contact User-Agent per SEC rules) | SERVER | ESM #36 | `000 proxy` |
| 53 | www.trai.gov.in | Monthly subscriber press releases (PDF) [V] | BHARTIARTL / IDEA CE / PE on adds / losses (~27th-28th) | Free | BOTH | F20 / F24 | `000 proxy` |
| 54 | www.dgca.gov.in | Monthly domestic traffic and market share | INDIGO on traffic / share (mid-month) | Free | SERVER | F24 | `000 proxy` |
| 55 | vahan.parivahan.gov.in | `vahan4dashboard` registrations by maker, month to date [V] | Auto CE / PE before the 1st-of-month sales (MARUTI, M&M, TVSMOTOR, HEROMOTOCO, EICHERMOT) | Free | SERVER | F24 | `000 proxy` |
| 56 | grid-india.in | Grid-India (ex-POSOCO) reports index | Peak demand / shortage -> power names, coal | Free | SERVER | F24 | `000 proxy` |
| 57 | report.grid-india.in | Daily NLDC PSP report PDFs (path pattern from examples) [V] | Same, the actual daily file | Free | SERVER | F24 | `000 proxy` |
| 58 | www.fada.in | Monthly retail auto sales (~5th-10th) | Auto names vs SIAM / company numbers | Free | SERVER | ESM #41 | `000 proxy` |
| 59 | www.siam.in | Monthly wholesale auto data | Same | Free | SERVER | ESM #41 | `000 proxy` |
| 60 | mod.gov.in | Ministry of Defence releases (contracts mostly mirrored on PIB) | Contract signings -> HAL, BEL, BDL, MAZDOCK, BEML CE | Free | SERVER | NEW (PIB covers most) | `000 proxy` |
| 61 | www.drdo.gov.in | DRDO tests, technology transfers | Defence sentiment days | Free | SERVER | NEW | `000 proxy` |
| 62 | www.mospi.gov.in | Release calendar (CPI, IIP, GDP) | Event locks; GDP 30 Nov | Free | SERVER | ESM #23 | `000 proxy` |
| 63 | www.gstcouncil.gov.in | Meeting notices, decisions | Rate cuts / hikes -> autos, FMCG, cement, insurance | Free | SERVER | ESM #13 | `000 proxy` |
| 64 | www.mcxindia.com | MCX bhavcopy / notices | Outside Watch witness for MCX crude / metals (server gets them via Kite, F02) | Free | OUTSIDE | F02 | `000 proxy` |
| 65 | www.amfiindia.com | NAV file, monthly flows (~10th) | MF flow regime; HDFCAMC, CAMS | Free | SERVER | F24 | `000 proxy` |
| 66 | www.nseix.com | NSE IX (GIFT City) market data pages | GIFT NIFTY overnight for the Outside Watch (no Kite here); public quote page format to confirm | Free | OUTSIDE | F02 | `000 proxy` |
| 67 | trendlyne.com | Broker research-report listing, upgrades / downgrades (full access paid, no API [V in ESM]) | Morning target changes -> named share 2-5% at the open. 07:15, 09:08 | Partly free; paid | SERVER | ESM #19 | `000 proxy` |
| 68 | www.icicidirect.com | Public research PDFs, daily derivatives note | Broker calls the morning TV repeats; scoring "did GIR see it" | Free | OUTSIDE | NEW | `000 proxy` |
| 69 | www.motilaloswal.com | Public research reports / morning notes | Same | Free | OUTSIDE | NEW | `000 proxy` |
| 70 | www.kotaksecurities.com | Public research / daily notes | Same | Free | OUTSIDE | NEW | `000 proxy` |
| 71 | www.niftytrader.in | Free public OI / PCR / max-pain pages (no login) | Second witness for GIR's OI walls (F05, F08) from outside | Free | OUTSIDE | NEW | `000 proxy` |
| 72 | opstra.definedge.com | Option chain with IV / greeks, 15-min delayed on free plan [V]; real-time on Pro | Cross-check of GIR's own IV (F26) | Free (delayed) / Pro paid | OUTSIDE | NEW | `000 proxy` |
| 73 | web.sensibull.com | Option chain, OI, FII / DII derivatives views (free basics) [V] | Same; login likely needed for most views | Free basics / paid | OUTSIDE | NEW | `000 proxy` |
| 74 | ibjarates.com | IBJA gold / silver rates twice a day | TITAN, MUTHOOTFIN, MANAPPURAM, KALYANKJIL on gold moves | Free | SERVER | ESM #47 | `000 proxy` |
| 75 | ppac.gov.in | Fuel prices, demand, APM gas price | OMCs, city-gas (IGL, MGL, GUJGASLTD) | Free | SERVER | ESM #20 / F24 | `000 proxy` |
| 76 | www.ukmto.org | Shipping security advisories (Hormuz / Red Sea) | Crude spike risk -> OMC PE, upstream CE | Free | SERVER | ESM #27 | `000 proxy` |
| 77 | www.boj.or.jp | BoJ decisions (often inside our session) | Yen-carry risk days -> NIFTY | Free | SERVER | ESM #15 | `000 proxy` |
| 78 | english.news.cn | Xinhua English: State Council / Politburo readouts | China stimulus -> metals CE (TATASTEEL, HINDALCO, VEDL) | Free | SERVER | ESM #39 | `000 proxy` |
| 79 | www.scmp.com | China / HK news with RSS | Same, faster English write-ups | Free (some paywall) | SERVER | NEW | `000 proxy` |
| 80 | www.aljazeera.com | Middle East news RSS | Gulf war / Hormuz escalation overnight | Free | SERVER | NEW | `000 proxy` |
| 81 | www.chittorgarh.com | IPO / QIP / OFS calendar | Supply drain on peers; lock-in expiry dates | Free | SERVER | ESM #37 | `000 proxy` |
| 82 | eaindustry.nic.in | Core-sector data (~20th) | Cement / steel / power demand read | Free | SERVER | ESM #23 | `000 proxy` |
| 83 | www.commerce.gov.in | Monthly trade data (~15th) | Rupee, gold-import, exporters | Free | SERVER | ESM #23 | `000 proxy` |
| 84 | egazette.gov.in | Gazette notifications | Notified duty / policy changes -> sector baskets | Free | SERVER (F20 has) | F20 | `000 proxy` |
| 85 | www.dgft.gov.in | Export / import policy notices | Rice, sugar, steel export curbs -> those baskets | Free | SERVER (F20 has) | F20 | `000 proxy` |
| 86 | www.cdsco.gov.in | Drug-regulator notices | Pharma approvals / bans | Free | SERVER (F20 has) | F20 | `000 proxy` |
| 87 | www.drewry.co.uk | World Container Index (Thursdays) | Freight -> CONCOR, ADANIPORTS, exporters (background) | Free | SERVER | ESM #27 | `000 proxy` |
| 88 | results.eci.gov.in | Live counting tallies | Counting days only (2027 state polls) | Free | BOTH | ESM #31 | `000 proxy` |
| 89 | public.api.bsky.app | Bluesky public posts API (no key) | A few journalists / economists post here; low value until coverage grows | Free | OUTSIDE | NEW | `000 proxy` |
| 90 | www.reuters.com | News and sitemaps (server F16 reads the sitemap) | Fastest Indian corporate scoops; known to challenge bots (DataDome) [E] | Free headlines; full text paid | SERVER (F16) | F16 | `000 proxy` |
| 91 | www.bloomberg.com | News sitemap headlines | "Said to" block / stake-sale scoops; site blocks bots [E] | Paid ($35/mo digital) for text | SERVER | ESM #18 | `000 proxy` |
| 92 | www.youtube.com | Official live streams (CNBC-TV18, ET Now, Sansad TV, PIB / DD) | F17 audio source; YouTube asks cloud IPs to "confirm you're not a bot" when pulling streams [E] - keep stream capture on the server | Free | SERVER (F17) | F17 | `000 proxy` |
| 93 | www.investing.com | Calendar, quotes | Cloudflare bot wall on cloud machines [E]; use #3, #4, #23 instead | Free | neither | - | `000 proxy` |
| 94 | www.cmegroup.com | FedWatch odds, COMEX inventories | Useful, but bot-blocked on cloud machines [E]; use #40 for odds | Free | SERVER (try) | ESM #28 / #38 | `000 proxy` |
| 95 | www.lme.com | LME notices, stocks, warrants | Use #19 for prices; notices only on metal-shock days | Free | SERVER | ESM #38 | `000 proxy` |

**Already allowed here, keep them** (tested today): www.bseindia.com `200`, www.moneycontrol.com `200` (use the sitemap,
not the RSS), economictimes.indiatimes.com `200`, www.business-standard.com `200`, www.livemint.com `200`,
www.cnbctv18.com `200`. **Allowed but blocked by the site:** www.nseindia.com `403 site`, www.ndtvprofit.com `403 site`
(could be removed from this session's list; the server should keep reading them).

**Paid rows (need the trader's yes):** FinancialJuice Pro ~$23/mo (#6), Bloomberg digital ~$35/mo (#91), WSJ (#25, full
text), Trendlyne (#67), Opstra Pro (#72), Sensibull paid (#73), LiveLaw paid tier (#15). Prices as quoted in ESM; check
before buying.

**Count:** 95 hosts in the ranked table + 8 already-allowed hosts tested = 103 distinct hosts (www.nseindia.com and
www.ndtvprofit.com included in the 8).

---

## 2. ADD TO THIS SESSION'S ALLOWED DOMAINS

Most useful first; 40 hosts; all returned `000 proxy` today; none is known to block cloud machines. Left out on purpose:
www.reuters.com, www.bloomberg.com, www.investing.com, www.cmegroup.com, www.youtube.com (reported bot walls on cloud
machines), and hosts only the server needs. After adding, re-run the curl test: if any answers `403 site`, drop it.

```
api.bseindia.com
nsearchives.nseindia.com
query1.finance.yahoo.com
stooq.com
trumpstruth.org
www.financialjuice.com
investinglive.com
www.federalregister.gov
www.sebi.gov.in
rbi.org.in
pib.gov.in
www.ccilindia.com
www.fpi.nsdl.co.in
nfs.faireconomy.media
home.treasury.gov
www.cnbc.com
www.westmetall.com
www.niftyindices.com
www.whitehouse.gov
www.federalreserve.gov
feeds.a.dj.com
apnews.com
pulse.zerodha.com
zerodha.com
t.me
news.google.com
www.etnownews.com
hindi.cnbctv18.com
www.zeebiz.com
www.thehindubusinessline.com
www.financialexpress.com
www.sci.gov.in
www.livelaw.in
www.iexindia.com
www.fda.gov
dipam.gov.in
gamma-api.polymarket.com
sansad.in
www.eia.gov
www.bis.org
```

---

## 3. FOR THE SERVER TO COLLECT (top 15, with the collection method)

Only hosts the server does not already read (or reads from a worse source). Polling is gentle: honour robots.txt, one
request per host per interval, stop on 403 / 429 and log (standing rule: never evade a block).

```
 1. trumpstruth.org            RSS /feed, every 60 s 18:00-09:15 IST, every 5 min otherwise; keyword map tariff/drug/H-1B/India/oil
                               -> pharma, IT, textiles, OMC baskets; into News + 07:15 note.
 2. www.financialjuice.com     Free-tier headline page poll every 15-30 s overnight (or audio squawk into the tvstt STT on Pro,
                               on the trader's yes); dedupe against F16.
 3. investinglive.com          RSS if the new site keeps ForexLive's feed (confirm), else news-page poll every 60 s; US-data actuals
                               and central-bank lines -> E1 drivers.
 4. www.federalregister.gov    JSON api/v1/public-inspection-documents/current.json every 60 s 18:00-02:00; flag 232/301/tariff/
                               export-control/pharmaceutical words.
 5. www.ccilindia.com          /market-watch HTML table every 60-120 s 09:00-17:00; extract the 10-yr benchmark LTY; alert on
                               >= 8 bp intraday move -> banks / NBFC / realty.
 6. www.sci.gov.in (+ www.livelaw.in, www.barandbench.com)
                               Cause-list PDF/HTML at ~20:00 and 07:00; tag every F&O company / counterparty; when a tagged item
                               is called, poll LiveLaw / Bar & Bench live pages every 60 s.
 7. www.fpi.nsdl.co.in         /web/Reports/Latest.aspx HTML daily ~19:00 (FPI + DII), fortnightly sector file, red-flag list;
                               into the 19:45 note "tide" line.
 8. home.treasury.gov + api.stlouisfed.org
                               Treasury daily par-yield XML at ~03:30 IST; FRED API (free key) for HY spread, breakevens, broad
                               dollar at 07:00 -> world drivers with a second witness to Yahoo.
 9. www.westmetall.com         /en/markdaten.php?action=table once after the LME official (~17:30-19:00 IST); replaces the wrong
                               copper / aluminium proxies in F23.
10. dipam.gov.in               Page hash every 5 min 17:00-23:00 and 07:00-09:00; "offer for sale / floor price" -> PSU PE at open.
11. www.niftyindices.com + www.msci.com
                               Press-release page hash every 15 min; parse adds / drops and effective dates into the Calendar.
12. www.fda.gov + www.accessdata.fda.gov
                               Warning-letters page hash + 483 reading-room RSS every 15 min; import-alert search for Indian firms
                               daily; match firm names to pharma F&O list.
13. www.whitehouse.gov         /presidential-actions page hash every 2 min 18:00-09:00 (pairs with #1).
14. feeds.a.dj.com + apnews.com
                               WSJ markets/world RSS every 60 s overnight; AP top / world pages every 2 min; headline-only into
                               F16 as global witnesses.
15. gamma-api.polymarket.com   GET /markets?slug=... (no key) every 5 min for a fixed list (Fed decision, US-India deal, tariff,
                               war markets); odds into the 19:45 note.
```

Also for the server, cheap and found today: switch Moneycontrol from the dead RSS to `news/news-sitemap.xml`, and use the
CNBC-TV18 Google-News sitemap and the ET / Business Standard market RSS listed in section 0 (all fresh at 11:00 IST).
