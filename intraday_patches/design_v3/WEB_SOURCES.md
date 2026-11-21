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

---

## 5. REGULATORS, PARLIAMENT, GOVERNMENT, COURTS - detailed

What this is: the policy-and-regulation source map for F20 (watchers) and F21 (07:00 day policy watch list + PENDING ->
ANNOUNCED -> NOTIFIED pipeline), body by body and sub-division by sub-division, with the exact page / RSS / JSON that lists
new items. Builds on POLITICAL_CYCLE.md (POLICY CLOCK, section D calendar) and BUILD_PLAN F20 / F21.

**Tested** 20 Nov 2026, 11:00-11:30 IST, from this session, same curl as above. **The allowlist has grown since 10:50:**
all 40 hosts of block (2) now pass the proxy (sansad.in, www.sebi.gov.in, rbi.org.in, www.sci.gov.in, dipam.gov.in,
www.livelaw.in answer `200`). Every **new** host in this section returned `000 proxy` (125 of 125 tested), so the
`Reach` column says `000 proxy` unless shown otherwise. [V] = confirmed by a live fetch here or by the page itself in web
search today; [E] = path expected / seen only in secondary sources, confirm once the host is allowed.

### 5.0 Found while testing (act on these first)

1. **PIB is still unreachable even though pib.gov.in is allowed.** `pib.gov.in/...` answers `301` to
   **www.pib.gov.in**, which is `000 proxy`. Every PIB page and RSS (`RssMain.aspx`, `ViewRss.aspx`, the CCEA page) lives
   on www.pib.gov.in. Add **www.pib.gov.in** (and static.pib.gov.in for the PDFs) or PIB, Cabinet, DAC, MSP, NBS all stay dark.
2. **SEBI's RSS is empty today.** `www.sebi.gov.in/sebirss.xml` answers `200` but has **0 items** (only a channel header,
   lastBuildDate 20 Nov 10:00) [V]. Poll the listing pages instead (all `200`, newest item 19 Nov) [V]:
   What's New `sebiweb/home/HomeAction.do?doListingAll=yes`; Circulars `...doListing=yes&sid=1&ssid=7&smid=0`;
   Master circulars `sid=1&ssid=6`; Orders `sid=2&ssid=9&smid=6`; Press releases `sid=6&ssid=23&smid=0`;
   Reports / consultation papers ("Reports for Public Comments") `sid=4&ssid=38&smid=35`; Regulations `sid=1&ssid=3`;
   Public issues (DRHPs) `sid=3&ssid=15`; Informal guidance `sid=2&ssid=10`. Category filter `doListingAll=yes&cid=10`
   = Derivatives only (the F&O rule-change stream).
3. **RBI RSS is live** [V]: `rbi.org.in/pressreleases_rss.xml` newest 20 Nov 10:20 IST; `notifications_rss.xml` newest
   11 Nov; feed index `rbi.org.in/Scripts/rss.aspx` also lists `speeches_rss.xml`, `Publication_rss.xml`, `Bulletin_rss.xml`,
   `tenders_rss.xml`.
4. **Parliament has a clean public JSON API on sansad.in** (no key, answers here) [V, all fetched today]:
   - one call per day for everything the Lok Sabha issues: `https://sansad.in/api_ls/ppHome/DailyCalendar?day=D&month=M&year=YYYY&locale=en`
     (returns List of Business + revised / supplementary lists, Bulletin-I, Bulletin-II, Questions list, Synopsis URLs);
   - LS List of Business: `api_ls/business/listOfBusinessUrls?lobDay=12&lobMonth=8&lobYear=2026&locale=en` (gave LoB,
     Revised LoB, Supplementary LoB-1 PDFs); Bulletin-II (government notice of bills / business):
     `api_ls/business/bulletin2Url?bull2Day=..&bull2Month=..&bull2Year=..`; Questions list `api_ls/question/questionListUrl?quesDay=..`;
     Synopsis `api_ls/business/synopsisUrl?synDay=..`;
   - LS questions with ministry, subject, STARRED / UNSTARRED and answer PDF:
     `api_ls/question/qetFilteredQuestionsAns?loksabhaNo=18&sessionNumber=8&pageNo=1&pageSize=50&locale=en` (gave 12 Aug 2026
     Q360 "Nuclear Power Generation", Q359 "Rare Earth Elements" with PDF links);
   - **all bills, both Houses, newest first**: `api_rs/legislation/getBills?...&page=1&size=20&locale=en&sortOn=billIntroducedDate&sortBy=desc`
     (10,099 records; gives ministry, category, introduced / passed LS / passed RS / assent dates and PDFs; statuses
     Pending / Passed / Assented / Withdrawn / Lapsed...);
   - Rajya Sabha List of Business: `api_rs/business/listOfBusinessUrls?lobDay=..&lobMonth=..&lobYear=..&locale=en` (same keys);
   - session dates: `api_ls/business/getAllLoksabhaAndSession?locale=en` (18th LS, session 8 = 20 Jul-13 Aug 2026 is the
     latest; the **Winter Session 2026 is not yet in the data or announced** - reports of 15-16 Nov say "likely first week
     of December");
   - LS press releases `api_ls/public/ppr/press-release?sortOn&sortBy&locale=en` (newest 19 Nov 14:28) and notices
     `api_ls/public/updates?locale=en&page=1&size=10` (party position, resignations).
5. **Supreme Court**: the www.sci.gov.in **home page lists the latest judgments** as `view-pdf/?diary_no=...&type=j&order_date=2026-11-19`
   links [V, 19 Nov items today] - poll it. The daily cause-list PDFs live on another host, **api.sci.gov.in**
   (`api.sci.gov.in/jonew/cl/YYYY-MM-DD/F_J_1.pdf`, newest seen 18 Nov 2026) [V], which is `000 proxy`; the
   `/cause-list/` page itself is a WordPress form (admin-ajax) [V].
6. **LiveLaw**: `www.livelaw.in/feed` returns `500`; use `www.livelaw.in/news-sitemap-daily.xml` (newest 11:25 IST today) or
   `google_feeds.xml` (05:43 GMT) [V].
7. **Many ministry sites (S3WaaS platform) keep their PDFs on `cdnbbsr.s3waas.gov.in`** (e.g. MNRE ALMM orders) [V] - one host
   that unlocks attachments for several ministries.
8. **Sansad TV live** is an HLS stream on `hls.media.nic.in/hls/live/rstv/rstv.m3u8` (linked from sansad.in/ls) [V] - a
   cleaner source for F17 speech-to-text than YouTube.

### 5.1 PARLIAMENT

| Host | Exact list page / feed / JSON | What it moves (CE / PE examples) | Speed | Reach | Who |
|---|---|---|---|---|---|
| sansad.in (LS) | JSON in 5.0 #4; pages `sansad.in/ls/business/agenda` (List of Business), `/ls/legislation/bills`, `/ls/questions/questions-and-answers`, `/ls/business/provisional-calendar`, `/ls/business/papers-laid`, `/ls/committee/subjects-reports`, `/ls/debates/text-of-debates` (uncorrected debates) [V all 200] | Bill listed in LoB / Bulletin-II -> policy basket (e.g. Mines & Minerals amendment -> NMDC, VEDL, HINDZINC; Insurance laws -> LICI, HDFCLIFE, SBILIFE; telecom / shipping / power bills). A minister's written answer (FDI cap, PLI, duty) moves names in the 12:00-13:00 window when answers are laid. Committee reports (e.g. Finance committee on crypto, F&O) -> BSE, ANGELONE | LoB for tomorrow out the **evening before** (~18:00-21:00); Bulletin-II same day; answers PDF on the day; debates by evening | `302` -> 200 | BOTH |
| sansad.in (RS) | `/rs/house-business/items-of-business`, `/rs/legislation/bills`, `/rs/legislation/bills-with-committees`, `/rs/questions/questions-and-answers`, `/rs/house-business/provisional-calendar`, `/rs/debates/verbatim`, `/rs/committees/committee-meetings`, `/rs/pressRelease` [V all 200]; JSON `api_rs/business/listOfBusinessUrls`, `api_rs/business/bulletin2/years`, `api_rs/legislation/getBillStatus` [V] | Same as LS; bill "passed by RS" = last step before assent -> the day's CE / PE on the basket | same | `200` | BOTH |
| rsdoc.nic.in | Back end the RS pages call for questions / members (`rsdoc.nic.in/question/GetAllministary`, `rsdoc.nic.in/Memberweb/...`) [V in sansad.in JS] | RS starred / unstarred answers (needed for full RS question text) | on the day | `000 proxy` | SERVER |
| rsdebate.nic.in | RS debates / question archive PDFs (`rsdebate.nic.in/bitstream/...`) [V in search] | Scoring / evidence (what the minister said) | next day | `000 proxy` | SERVER |
| eparlib.sansad.in (also eparlib.nic.in) | Parliament Digital Library, LS debates 1952-2025, Q&A PDFs (`eparlib.sansad.in/handle/123456789/7`) [V] | Background, past answers on a subject (e.g. AGR, royalty) | days | `000 proxy` | SERVER |
| elibrary.sansad.in | DSpace API `elibrary.sansad.in/server/api/discover/search/objects?...sort=dc.date.issued,DESC` (called by sansad.in) [V in JS] | Newest committee reports / papers | days | `000 proxy` | SERVER |
| sansadtv.nic.in + hls.media.nic.in | `sansadtv.nic.in/show/live-recorded`; live HLS `hls.media.nic.in/hls/live/rstv/rstv.m3u8` [V] | Minister speaking in the House / Question Hour, live -> PSU / policy names (F17) | live | `000 proxy` | SERVER (F17) |
| prsindia.org | Bill track `prsindia.org/billtrack` (status: Pending / Passed / Draft), `/billtrack/category/finance-industry-and-labour`, `/billtrack/category/infrastructure-and-environment`, session track `/sessiontrack/<session>/session-alert` and `/bill-legislation`, `/policy/monthly-policy-review` [V] | Pre-session list of bills likely to be taken up (Session Alert, out ~1 week before) = F21 PENDING list; draft bills open for comment | session alert ~a week before; bill pages same / next day | `000 proxy` | BOTH |
| loksabha.nic.in, rajyasabha.nic.in, loksabhaph.nic.in | Legacy; sansad.in replaced them (other govt sites still link rajyasabha.nic.in) [E] | - | - | `000 proxy` | neither (not needed) |

### 5.2 GOVERNMENT (Cabinet, PIB, Gazette, ministries)

| Host | Exact list page / feed | What it moves | Speed | Reach | Who |
|---|---|---|---|---|---|
| www.pib.gov.in | RSS `www.pib.gov.in/RssMain.aspx?ModId=6&Lang=2&Regid=3` [V on ViewRss.aspx; English is expected at `Lang=1`, confirm]; feed index `ViewRss.aspx?reg=3`; Cabinet / CCEA `www.pib.gov.in/Content/123_8_CCEADecisions.aspx` [V]; ministry filter via archive `archive.pib.gov.in/archive2/AdvSearch.aspx` | Cabinet (usually Wednesday) / CCEA: MSP (CHAMBLFERT, COROMANDEL, sugar), NBS subsidy (Rabi 2026-27 approved 11 Nov 2026), energy-storage scheme (4 Nov: Rs 14,500 cr -> EXIDEIND, TATAPOWER, NTPC), rail / metro projects (RVNL, IRCON, RAILTEL), DAC AoNs (HAL, BEL, BDL, MAZDOCK, COCHINSHIP, BEML) | Minister's briefing ~15:00-16:30, release within minutes; evening releases 17:00-22:00 (J25) | 301 -> `000 proxy` | BOTH |
| static.pib.gov.in | PDFs / factsheets behind PIB releases [V] | same | same | `000 proxy` | SERVER |
| newsonair.gov.in | All India Radio news: Cabinet, DAC, auction launches often posted first by AIR [V in search] | second witness for PIB | minutes | `000 proxy` | BOTH |
| www.pmindia.gov.in | `news_updates` (Cabinet decisions mirrored) [V] | witness | minutes-hours | `000 proxy` | SERVER |
| egazette.gov.in | Home page lists newest Extraordinary and Weekly gazettes (Directorate of Printing) [V]; search by ministry / subject | NOTIFIED step of the pipeline: customs ADD / safeguard duty, GST rate notifications, rules (IT Rules, Electricity Rules), price orders | Extraordinary same day, often late evening | `000 proxy` | SERVER (F20) |
| financialservices.gov.in (DFS) | `financialservices.gov.in/beta/en/whats-new`, `/beta/en/press-releases` [V] | UPI MDR (15 Sep 2026 release -> PAYTM), PSU bank / insurance (LICI, GICRE, NIACL) capital, bank mergers | hours | `000 proxy` | BOTH |
| dea.gov.in (DEA) | Press releases, G-sec / sovereign gold bond notices [E] | Borrowing calendar -> banks; FDI policy | hours | `000 proxy` | SERVER |
| cbic-gst.gov.in, taxinformation.cbic.gov.in (CBIC) | `cbic-gst.gov.in/central-tax-notifications.html` (GST central tax, rate) [V]; customs tariff / ADD / safeguard notifications on taxinformation.cbic.gov.in [E] | GST rate change -> autos, FMCG, cement, insurance; ADD / safeguard on steel (TATASTEEL, JSWSTEEL, SAIL, JINDALSTEL), chemicals (SRF, NAVINFLUOR, DEEPAKNTR, AARTIIND), solar glass | often late evening | `000 proxy` | SERVER (F20) |
| incometaxindia.gov.in (CBDT) | `incometaxindia.gov.in/Pages/communications/notifications.aspx`, `/circulars.aspx` [V] | STT / buy-back / capital-gains rules -> BSE, ANGELONE, CDSL; safe-harbour rules -> IT | hours | `000 proxy` | SERVER |
| www.gstcouncil.gov.in | `www.gstcouncil.gov.in/en/press-release`, `/what-s-new` [V; 57th meeting recommendations 08-10-2026] | Council meeting outcome -> autos, cement, insurance, FMCG, online gaming (NAZARA, DELTACORP) | release same evening; date of next (58th) meeting not announced | `000 proxy` | BOTH |
| dipam.gov.in | `dipam.gov.in/disinvestmentReceiptsDtls` (OFS / stake-sale receipts), `/circular`; fastest is @SecyDIPAM on X [V] | OFS floor price the evening before -> PE on the PSU at the open (COALINDIA, LICI, NHPC, IRFC, BANKINDIA, IOB) | X post ~18:00-21:00 the day before | `200` (allowed) | BOTH |
| www.mca.gov.in | RSS index `www.mca.gov.in/content/mca/global/en/notifications-tender/rss-feeds.html` (press releases, notices and circulars) [V] | Companies Act / CSR / merger rules; inspection orders | hours | `000 proxy` | SERVER |
| www.dgft.gov.in | `www.dgft.gov.in/CP/?opt=notification`, `?opt=public-notice`, `?opt=trade-notice` [V] | Export bans / MEP on rice, sugar, onion (BALRAMCHIN for sugar), iron-ore / steel export duty (NMDC, JSWSTEEL, TATASTEEL) | often evening | `000 proxy` | SERVER (F20) |
| www.dgtr.gov.in (and dgtr.gov.in) | Initiations, final findings, sunset reviews (AD(OI)-.., AD(SSR)-..) [E path; findings seen 24-25 Sep, 23 Oct 2026 via secondary sources] | Final finding = duty likely in ~3 months (finance ministry notifies) -> CE on the domestic maker (steel pipes, aluminium foil HINDALCO, chemicals SRF / AARTIIND, solar glass), PE on users | daily during busy weeks (last working days of a quarter are heavy) | `000 proxy` | SERVER (F20) |
| www.meity.gov.in | Notifications (IT Rules amendments, e.g. AI-content rules Feb 2026), semiconductor / ECMS approvals [E] | DIXON, KAYNES, TATAELXSI (electronics / semiconductor approvals); social-media rules | hours | `000 proxy` | SERVER |
| mod.gov.in | MoD releases (DAC mostly mirrored on PIB; last DAC 26 Oct 2026 ~Rs 2.12 trn) | HAL, BEL, BDL, MAZDOCK, COCHINSHIP, BEML, SOLARINDS, DATAPATTNS CE | DAC release evening | `000 proxy` | SERVER |
| powermin.gov.in | `powermin.gov.in/en/announcements` (rules, guidelines, orders) [V] | Electricity (Amendment) Rules, fuel-cost pass-through, ISTS waiver -> NTPC, POWERGRID, TATAPOWER, ADANIPOWER, JSWENERGY, IEX, PFC, RECLTD | hours | `000 proxy` | SERVER |
| mnre.gov.in + cdnbbsr.s3waas.gov.in | ALMM List-I / II / III orders and OMs (PDFs on cdnbbsr.s3waas.gov.in) [V] | Solar makers (WAAREEENER, PREMIERENE, INOXWIND, SUZLON) | hours | `000 proxy` | SERVER |
| cea.nic.in + npp.gov.in | `cea.nic.in/notification/?lang=en`, `/monthly-installed-capacity-report/`; daily generation PDF `npp.gov.in/public-reports/cea/daily/dgr/DD-MM-YYYY/dgr1-YYYY-MM-DD.pdf` [V] | Demand / coal stock stress -> COALINDIA, NTPC, power names | daily ~morning | `000 proxy` | SERVER (F24) |
| grid-india.in, report.grid-india.in | Reports index; daily NLDC PSP PDFs (see row #56-57 above) | peak demand / shortage | daily | `000 proxy` | SERVER (F24) |
| mopng.gov.in | MoPNG releases / orders (windfall tax, APM gas, LPG) [E] | ONGC, OIL, RELIANCE, BPCL, HINDPETRO, IOC, GAIL, IGL, MGL | hours | `000 proxy` | SERVER |
| ppac.gov.in | `ppac.gov.in/archives/impnews` (Indian basket, RSP, gas price), `/prices` [V] | OMC margins, APM gas price (1st of month) -> IGL, MGL, GUJGASLTD, ONGC | daily / monthly | `000 proxy` | SERVER (F24) |
| morth.gov.in, morth.nic.in | `morth.gov.in/toll` (toll notifications), circular PDFs on morth.nic.in [V] | Toll-fee rules and HAM / EPC policy -> road EPC order flow (LT); low direct F&O impact | days | `000 proxy` | SERVER |
| nhai.gov.in, tis.nhai.gov.in | Tenders / awards, toll info system [V] | Order wins for road EPC names; toll-rate revisions 1 Apr | days | `000 proxy` | SERVER |
| indianrailways.gov.in | Railway Board freight rate circulars `indianrailways.gov.in/railwayboard/uploads/directorate/traffic_comm/...` [V] | Freight rate changes -> CONCOR, coal / cement freight; projects -> RVNL, IRCON, IRFC | days | `000 proxy` | SERVER |
| steel.gov.in | Releases, PQ answers [V] | Safeguard duty push (final 3-yr duty notified 31 Dec 2025) -> TATASTEEL, JSWSTEEL, SAIL, JINDALSTEL | days | `000 proxy` | SERVER |
| mines.gov.in | Critical-mineral auction tranches (9th tranche 5 Nov 2026, 20 blocks) [E path; facts via PIB / AIR] | NMDC, VEDL, HINDZINC, HINDCOPPER, NATIONALUM, COALINDIA | event days | `000 proxy` | SERVER |
| coal.gov.in, coal.nic.in | Nominated Authority `coal.gov.in/nominated-authority/auction-allotment`; press PDFs `coal.nic.in/sites/default/files/YYYY-MM/Press*.pdf` [V] | Commercial coal auctions (16th round 17 Sep 2026) -> COALINDIA PE / private miners CE | event days | `000 proxy` | SERVER |
| dot.gov.in | `dot.gov.in/whats-new` [V] | AGR / spectrum / bank-guarantee relief -> IDEA, BHARTIARTL, INDUSTOWER | hours | `000 proxy` | SERVER |
| www.civilaviation.gov.in | Releases / orders [V] | INDIGO, GMRAIRPORT (airport policy, ATF) | hours | `000 proxy` | SERVER |
| cdsco.gov.in | `cdsco.gov.in/opencms/opencms/en/Notifications/Public-Notices/`, `/en/Notifications/Alerts` (monthly NSQ / spurious), `/en/Notifications/Gazette-Notifications` [V] | FDC bans, NSQ alerts naming makers, approvals -> pharma PE / CE | days | `000 proxy` | SERVER (F20) |
| nppaindia.nic.in | Price notifications / ceiling-price orders (S.O. numbers) [V mention] | Price caps -> pharma (SUNPHARMA, CIPLA, LUPIN, ALKEM, TORNTPHARM, GLENMARK, ABBOTINDIA) | monthly-ish; WPI revision 1 Apr | `000 proxy` | SERVER (F20) |
| fert.gov.in | NBS rate notifications [E] (decision itself comes via Cabinet / PIB) | CHAMBLFERT, COROMANDEL (subsidy rates per tonne) | after Cabinet | `000 proxy` | SERVER |
| chemicals.gov.in | Dept of Chemicals & Petrochemicals orders (QCOs) [E] | SRF, PIDILITIND, chemicals basket | days | `000 proxy` | SERVER |
| www.fssai.gov.in | `www.fssai.gov.in/advisories.php`, `/all-whatnew.php` [V] | Labelling / ban orders -> NESTLEIND, BRITANNIA, TATACONSUM, VBL, JUBLFOOD | days | `000 proxy` | SERVER (F20) |

### 5.3 REGULATORS and their sub-divisions

| Host | Exact list page / feed | What it moves | Speed | Reach | Who |
|---|---|---|---|---|---|
| www.sebi.gov.in | Listings in 5.0 #2 (circulars, master circulars, orders, consultation papers, board meeting press releases "Key decisions taken in the SEBI Board meeting dated ..."), SEBI hearing cause list `sebiweb/home/cause-list.jsp` [V]; last board meeting 215th on 24 Sep 2026, next not announced | F&O rules (lot size, weekly expiry, position limits) -> BSE, ANGELONE, CDSL, CAMS, KFINTECH, MCX, NUVAMA; orders against companies / promoters -> PE on that share; MF rules -> HDFCAMC, NAM-INDIA, ABSLAMC | circulars any time, often 17:00-21:00; board decisions same evening | `200` | BOTH |
| rbi.org.in | RSS in 5.0 #3; MPC statement page; daily money-market ops | Policy, liquidity, bank / NBFC restrictions (business embargo = PE: e.g. NBFC gold-loan bans MUTHOOTFIN, MANAPPURAM), PCA, digital lending | real time | `200` | BOTH |
| irdai.gov.in (www.irdai.gov.in) + policyholder.gov.in | Circulars, regulations, exposure drafts on irdai.gov.in [E paths]; mirror lists `policyholder.gov.in/web/guest/circulars`, `/web/guest/exposure-drafts` [V] | LICI, HDFCLIFE, SBILIFE, ICICIPRULI, ICICIGI, POLICYBZR - commission caps, surrender value, Bima Sugam, FDI 100% | exposure drafts appear quietly, often evening; comments windows ~21-30 days (one due 23 Nov 2026) | `000 proxy` | BOTH |
| www.pfrda.org.in | `www.pfrda.org.in/web/pfrda/regulatory-framework/circulars` (active / inoperative), `/master-circulars/active-master-circulars`, exposure drafts [V] | NPS scheme rules / fund-manager fees -> HDFCAMC (pension arm), low overall | days | `000 proxy` | SERVER |
| www.ifsca.gov.in | Legal framework (circulars, regulations) `www.ifsca.gov.in/Legal/Index/...`, news `www.ifsca.gov.in/Home/NewSection` [V] | GIFT City rules (NSE IX, ship leasing) - low for F&O | days | `000 proxy` | SERVER |
| www.trai.gov.in (trai.gov.in) | `www.trai.gov.in/whats-new`, consultations `trai.gov.in/release-publication/consultation`, recommendations `trai.gov.in/release-publication/recommendation`, press releases `trai.gov.in/notifications/archived-press-release` [V] | Tariff orders, spectrum pricing recommendations (IMT auction Feb 2026), monthly subscriber data (~27th-28th) -> BHARTIARTL, IDEA, INDUSTOWER; broadcasting -> ZEEL, SUNTV | releases 16:00-20:00 | `000 proxy` | BOTH |
| cercind.gov.in | Orders `cercind.gov.in/recent_orders.html` (English page showed 2025 in cache; Hindi `recent_orders_hin.html` showed 2026 orders), RoPs `recent_rops.html`, petitions status `Current_petitions_status_active.html`, draft regulations [V] | Market coupling / trading margins -> IEX PE / CE; transmission tariff -> POWERGRID; generation tariff -> NTPC, NHPC, SJVN, TATAPOWER | order posting lags hearing by days-weeks | `000 proxy` | SERVER (F20) |
| pngrb.gov.in | `pngrb.gov.in/eng-web/site.html`; PDFs `pngrb.gov.in/pdf/public-notice/YYYYMMDD_PN.pdf`, `/pdf/orders/YYYYMMDD_TariffOrder.pdf`, `/pdf/press-note/YYYYMMDD_PR.pdf` [V] | Unified pipeline tariff -> GAIL; CGD authorisations / exclusivity -> IGL, MGL, GUJGASLTD; PETRONET | days | `000 proxy` | SERVER (F20) |
| www.cci.gov.in (cci.gov.in) | Combination orders (Section 31) `www.cci.gov.in/combination/order/details/order/<id>/0/orders-section31` [V pattern]; list page `.../combination/orders-section31` [E]; antitrust orders [E]; CCI also posts approvals on X | Deal approvals (acquirer CE / unblock), antitrust penalties (PE: e.g. tyre, cement, digital) | approvals weekly (Tue / Wed board), tweet same day | `000 proxy` | BOTH |
| ibbi.gov.in | `ibbi.gov.in/en/orders/ibbi` (orders, paginated), regulations, What's New (resolution plans, auctions) [V] | Insolvency rule changes -> lenders, ARCs; IBC timelines | days | `000 proxy` | SERVER |
| nppaindia.nic.in, cdsco.gov.in, www.fssai.gov.in | see 5.2 | | | | |
| www.dgca.gov.in | Monthly domestic traffic (Domestic Traffic / Air Traffic reports) [E path]; safety orders | INDIGO (traffic, share ~mid-month), grounding / safety orders PE | monthly ~15th-20th | `000 proxy` | SERVER (F24) |
| aera.gov.in | `aera.gov.in/tariff-orders` (paginated), `/public-notices`, `/courttribunal-orders` [V] | Airport tariff (DIAL, MIAL, Adani airports) -> GMRAIRPORT, ADANIENT | days | `000 proxy` | SERVER |
| nhai.gov.in, cea.nic.in, grid-india.in | see 5.2 | | | | |
| npci.org.in (www.npci.org.in) | UPI circulars `npci.org.in/what-we-do/upi/circular` (OC numbers), UPI steering-committee minutes, consolidated circular v1.0 (18 Sep 2026) [V] | Market-share cap deadline (31 Dec 2026), MDR, UPI features -> PAYTM (and Pine Labs / MobiKwik not F&O), banks | circular PDFs any time; often found first via news | `000 proxy` | BOTH (POLITICAL_CYCLE POLICY CLOCK) |
| www.amfiindia.com | `www.amfiindia.com/research-information/amfi-monthly` (monthly note, flows; Oct 2026 note out) [V] | HDFCAMC, NAM-INDIA, CAMS, KFINTECH; SIP flows = market tide | ~10th of month | `000 proxy` | SERVER (F24) |
| State ERCs | see 5.5 | | | | |

### 5.4 COURTS and TRIBUNALS

| Host | Exact list page / feed | What it moves | Speed | Reach | Who |
|---|---|---|---|---|---|
| www.sci.gov.in | Home page "latest judgements" `view-pdf/?diary_no=...&type=j&order_date=...` [V]; `/cause-list/`, `/daily-order-case-no/`, `/judgements-case-no/`, `/press-release/`, `/notices-and-circulars/`, `/calendar/` [V] | AGR / spectrum (IDEA, BHARTIARTL), mining royalty (NMDC, COALINDIA, VEDL), gaming (NAZARA, DELTACORP), tax (BHARTIARTL, VEDL), environment closures | judgments uploaded same day; cause list evening before | `200` | BOTH |
| api.sci.gov.in | Daily cause-list PDFs `api.sci.gov.in/jonew/cl/YYYY-MM-DD/F_J_1.pdf` (F_J_2 ...) [V] | Tag F&O names listed tomorrow (F21 watch item) | ~20:00-23:00 day before | `000 proxy` | BOTH |
| www.livelaw.in | `www.livelaw.in/news-sitemap-daily.xml` [V fresh]; live threads on the article pages | First text of a ruling within minutes | minutes | `200` | BOTH |
| www.barandbench.com | RSS `www.barandbench.com/feed` [V in search]; daily sitemaps `/sitemap/sitemap-daily-YYYY-MM-DD.xml` [V] | second witness | minutes | `000 proxy` | BOTH |
| www.scobserver.in | Supreme Court Observer case pages (tracks big pending matters) [V] | F21 PENDING court items (what is listed, what is reserved) | days | `000 proxy` | SERVER |
| delhihighcourt.nic.in | `delhihighcourt.nic.in/web/cause-lists/cause-list` (PDF cause lists incl. "Pronouncement of Judgment") [V]; new site since 21 Apr 2025 | Patent / pharma (DRREDDY, GLENMARK, ZYDUSLIFE), tax, arbitration awards (e.g. DMRC-type), telecom | cause list evening before | `000 proxy` | SERVER |
| bombayhighcourt.nic.in | Cause lists / judgments (e.g. `ordfbench.php`) [V] | Tax, corporate (SEBI-related writs), Maharashtra policy | evening before | `000 proxy` | SERVER |
| nclt.gov.in | `nclt.gov.in/order-judgement-date-wise` (captcha), `nclt.gov.in/circulars` (dated order notes), Cause List menu [V] | Insolvency admission / resolution approval -> the debtor PE / acquirer CE; lenders | orders uploaded days later; LiveLaw / IBC press faster | `000 proxy` | SERVER |
| nclat.nic.in | `nclat.nic.in/daily-order-data`; cause list PDFs `nclat.nic.in/sites/default/files/YYYY-MM/Causelist_ch_DD.MM.YYYY.pdf` [V] | IBC appeals, CCI appeals (penalty relief CE) | cause list day before | `000 proxy` | SERVER |
| greentribunal.gov.in | Cause list (benches), Judgement / Orders menu, `/important-orders` [V] | Plant closure / environment fines -> cement, chemicals, power, mining | days | `000 proxy` | SERVER |
| aptel.gov.in | Daily orders `aptel.gov.in/en/dailyorder/tab3`, cause list `aptel.gov.in/causelist/tab3`, `/en/latest-updates` (finals lists) [V] | CERC / SERC appeals: IEX coupling, discom dues, tariff -> IEX, TATAPOWER, ADANIPOWER, JSWENERGY, POWERGRID | daily | `000 proxy` | SERVER |
| satweb.sat.gov.in | Securities Appellate Tribunal: Cause List and Order menus [V] | Stay / reversal of SEBI orders -> that share CE (e.g. promoter bans) | orders same / next day | `000 proxy` | SERVER |
| tdsat.gov.in | Daily cause list PDFs `tdsat.gov.in/daily_causelist/YYYY-MM-DD_*.pdf`; orders `tdsat.gov.in/order_files/final/YYYY/Month/...pdf` [V] | Telecom / broadcasting disputes -> IDEA, BHARTIARTL, ZEEL, SUNTV | day before | `000 proxy` | SERVER |
| cestat.gov.in | `cestat.gov.in/viewcauselist`, Final Orders / Daily Orders menus, `openfile/2/<id>` [V] | Big customs / excise / service-tax demands -> the named share | days | `000 proxy` | SERVER |

### 5.5 STATES that move F&O shares

| State / host | Exact list page | What it moves | Speed | Reach | Who |
|---|---|---|---|---|---|
| Maharashtra - merc.gov.in | Orders as `merc.gov.in/wp-content/uploads/YYYY/MM/<order>.pdf` (MYT orders Mar 2025, MSEDCL review 2026) [V]; listing page [E] | TATAPOWER (Mumbai licence), ADANIENSOL (Mumbai distribution), JSWENERGY; Maharashtra excise hikes (Jun 2025: IMFL +50-60%) -> UNITDSPR, RADICO (from news, excise site not verified) | orders late Mar (tariff) + petitions | `000 proxy` | SERVER |
| Gujarat - gercin.org | `gercin.org/order/` (tariff, RE, petition orders; FY27 orders 25 Mar 2026) [V] | TORNTPOWER (Ahmedabad / Surat), ADANIPOWER, GUJGASLTD (via state gas policy) | late Mar + RE orders | `000 proxy` | SERVER |
| Tamil Nadu - www.tnerc.tn.gov.in | `www.tnerc.tn.gov.in/website/TariffOrders.aspx`, orders `/Orders/files/...pdf` [V] | Discom tariff; wind / solar (SUZLON, INOXWIND); state liquor (TASMAC) -> spirits | yearly (Jul) | `000 proxy` | SERVER |
| Uttar Pradesh - uperc.org | Tariff orders (FY27 retail tariffs retained; UPPTCL / UPSLDC orders Apr 2026 via news) [V older PDFs]; UP power privatisation (PURVANCHAL / DAKSHINANCHAL) and excise policy 2026-27 (Feb) via news / state sites | PFC, RECLTD (privatisation), TATAPOWER, TORNTPOWER (bidders); UNITDSPR, RADICO (excise) | yearly + event days | `000 proxy` | SERVER |
| Karnataka - kerc.karnataka.gov.in | KERC orders (true-up Apr 2026, solar tariff 25 Aug 2026; seen via discom / news) [E host] | BESCOM-area industry; liquor excise (state budget) -> UNITDSPR, RADICO; mining (iron ore) -> JSWSTEEL, NMDC | yearly + event | `000 proxy` | SERVER (not added: host not verified) |
| All states | Budgets (Feb-Mar), excise policies (Feb-Apr), mining auctions, power purchase / privatisation decisions | as above | POLITICAL_CYCLE section D: state excise Feb-Mar 2027 | - | OUTSIDE reads via ET / BS / Mint (already allowed) |

### 5.6 How fast each body usually publishes (for alert routing)

- **Seconds-minutes (live alert path):** RBI RSS, SEBI What's New, PIB (once www.pib.gov.in is allowed), Sansad TV, LiveLaw /
  Bar & Bench, sansad.in LoB / Bulletin-II JSON, Cabinet briefing, DIPAM secretary on X, CCI on X.
- **Same evening (19:45 note / 07:15 note):** SEBI circulars and board outcomes, TRAI, GST Council, Gazette Extraordinary,
  DGFT, DGTR findings, SC cause list (api.sci.gov.in), NCLAT / TDSAT / APTEL cause lists, NPCI circulars, DAC.
- **Days (pipeline / scoring, not alerts):** CERC / SERC orders, NCLT orders, NGT, CESTAT, CDSCO, NPPA, FSSAI, IBBI,
  AERA, PNGRB orders, ministry "what's new" pages.

---

### ADD TO ALLOWED DOMAINS (regulatory)

New hosts only (none is in block 2). Most useful first. All returned `000 proxy` today; none is known to block cloud
machines; all were seen as real hosts today (live link, page in web search, or linked from an official site). Left out on
purpose: legacy loksabha.nic.in / rajyasabha.nic.in / loksabhaph.nic.in (replaced by sansad.in), and kerc.karnataka.gov.in,
mopng.gov.in, mines.gov.in, dea.gov.in, fert.gov.in, chemicals.gov.in, www.meity.gov.in, taxinformation.cbic.gov.in,
cabsec.gov.in (real sites but not confirmed by a page today; add later if F20 needs them). After adding, re-run the curl;
drop any that answers `403 site`.

```
www.pib.gov.in
api.sci.gov.in
static.pib.gov.in
egazette.gov.in
npci.org.in
www.npci.org.in
www.trai.gov.in
trai.gov.in
irdai.gov.in
www.irdai.gov.in
www.cci.gov.in
cci.gov.in
www.barandbench.com
www.dgft.gov.in
www.dgtr.gov.in
dgtr.gov.in
cbic-gst.gov.in
www.gstcouncil.gov.in
cercind.gov.in
www.cercind.gov.in
pngrb.gov.in
newsonair.gov.in
prsindia.org
financialservices.gov.in
incometaxindia.gov.in
www.mca.gov.in
cdsco.gov.in
nppaindia.nic.in
www.fssai.gov.in
dot.gov.in
powermin.gov.in
satweb.sat.gov.in
nclat.nic.in
nclt.gov.in
aptel.gov.in
tdsat.gov.in
delhihighcourt.nic.in
bombayhighcourt.nic.in
greentribunal.gov.in
cestat.gov.in
ibbi.gov.in
www.amfiindia.com
www.dgca.gov.in
aera.gov.in
policyholder.gov.in
www.pfrda.org.in
www.ifsca.gov.in
mnre.gov.in
cdnbbsr.s3waas.gov.in
cea.nic.in
npp.gov.in
grid-india.in
report.grid-india.in
ppac.gov.in
coal.gov.in
coal.nic.in
steel.gov.in
www.civilaviation.gov.in
mod.gov.in
indianrailways.gov.in
nhai.gov.in
morth.gov.in
morth.nic.in
rsdoc.nic.in
rsdebate.nic.in
eparlib.sansad.in
elibrary.sansad.in
sansadtv.nic.in
www.pmindia.gov.in
archive.pib.gov.in
www.scobserver.in
merc.gov.in
gercin.org
www.tnerc.tn.gov.in
uperc.org
```

Count: **75 new hosts.** Server-only extra (not needed in this session): hls.media.nic.in (Sansad TV live HLS for F17).

### FOR THE SERVER (F20 / F21)

Gentle polling: one request per host per interval, honour robots.txt, back off on 403 / 429 and log (never evade a block).
"Page hash" = fetch, strip boilerplate, diff the item list, alert on new rows only.

```
EVERY 60 s (09:00-23:00 IST), RSS / JSON / small pages:
  rbi.org.in/pressreleases_rss.xml + notifications_rss.xml
  www.sebi.gov.in/sebiweb/home/HomeAction.do?doListingAll=yes   (RSS is empty - use this; also cid=10 Derivatives)
  www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3  (+ Lang=2)  once www.pib.gov.in is allowed
  www.livelaw.in/news-sitemap-daily.xml, www.barandbench.com/feed  (filter on F&O names / regulators)
  www.sci.gov.in/  home page "latest judgements" links   (court hours 10:30-16:30, then every 15 min)
WHILE PARLIAMENT SITS (Winter Session 2026 dates not announced yet; poll session list daily to detect it):
  every 2 min 10:00-20:00: sansad.in/api_ls/ppHome/DailyCalendar?day=..&month=..&year=..&locale=en (today AND tomorrow)
                           sansad.in/api_rs/business/listOfBusinessUrls?lobDay=..&lobMonth=..&lobYear=..&locale=en
  every 10 min: sansad.in/api_rs/legislation/getBills?...&sortOn=billIntroducedDate&sortBy=desc&size=20  (status changes)
                sansad.in/api_ls/question/qetFilteredQuestionsAns?loksabhaNo=18&sessionNumber=<n>&pageSize=50  (match ministries
                to the sector map: Mines, Power, Petroleum, Telecom, Finance, Civil Aviation, Steel, Coal, Defence, Railways)
  live: hls.media.nic.in/hls/live/rstv/rstv.m3u8 into the F17 speech-to-text
  daily 07:00: sansad.in/api_ls/business/getAllLoksabhaAndSession?locale=en; prsindia.org session-alert / billtrack
EVERY 5 min 09:00-23:00, page hash:
  npci.org.in/what-we-do/upi/circular        www.trai.gov.in/whats-new        www.gstcouncil.gov.in/en/press-release
  www.cci.gov.in combination orders list     dipam.gov.in (+ DIPAM secretary on X)   www.dgft.gov.in/CP/?opt=notification
  egazette.gov.in home (Extraordinary list)  cbic-gst.gov.in/central-tax-notifications.html   financialservices.gov.in/beta/en/whats-new
  irdai.gov.in circulars / exposure drafts (or policyholder.gov.in lists)
EVERY 15 min 09:00-23:00, page hash:
  www.dgtr.gov.in   cercind.gov.in/recent_orders.html (+ _hin)   pngrb.gov.in public notices / orders   powermin.gov.in/en/announcements
  dot.gov.in/whats-new   cdsco.gov.in Public-Notices + Alerts   www.fssai.gov.in/advisories.php   ibbi.gov.in/en/orders/ibbi
  aera.gov.in/tariff-orders   www.mca.gov.in RSS   incometaxindia.gov.in notifications + circulars   mnre.gov.in
  aptel.gov.in/en/latest-updates   satweb.sat.gov.in orders   nclat.nic.in/daily-order-data   newsonair.gov.in (cabinet / DAC words)
CAUSE LISTS (F21 court watch items, tag every F&O name / counterparty, then poll LiveLaw every 60 s when the item is called):
  20:00 and 23:00: api.sci.gov.in/jonew/cl/<tomorrow>/F_J_1.pdf ...   nclat.nic.in cause list PDF   tdsat.gov.in/daily_causelist
                   aptel.gov.in/causelist/tab3   delhihighcourt.nic.in/web/cause-lists/cause-list   cestat.gov.in/viewcauselist
DAILY / MONTHLY:
  08:00 cea.nic.in + npp.gov.in daily generation; ppac.gov.in/archives/impnews; 1st of month PPAC gas price
  ~10th www.amfiindia.com AMFI monthly; ~15th-20th www.dgca.gov.in traffic; ~27th-28th TRAI subscriber data
  weekly: state ERC order pages (merc.gov.in, gercin.org, www.tnerc.tn.gov.in, uperc.org); coal.gov.in / mines.gov.in auctions
F21 07:00 BUILD (and 12:00 refresh): bills in today's LS / RS List of Business + Bulletin-II; open consultation papers with
  close dates (SEBI sid=4 ssid=38, TRAI consultation, IRDAI / PFRDA exposure drafts, DGTR open cases); board / council
  meetings announced (SEBI, GST Council, RBI MPC, CCI); court items listed today; each mapped to F&O shares + direction ->
  PENDING / ANNOUNCED / NOTIFIED (Gazette) in the policy pipeline; RED when a deadline in POLITICAL_CYCLE's POLICY CLOCK passes.
```
