# External sources - measured delays (I1-I8), Fri 20 Nov 2026

Every delay below was measured, none was guessed: **source time** is the item's own time from the source (filing dissemination
time, the publisher's sitemap or RSS publication time, the posted time on the regulator's page, the TV speech segment).
**GIR seen** is GIR's own first-seen time from its logs and files. **Page seen** is the first moment the item reached an open page
(one local stream connection to the page server, filtered to news / ext facts). Where a source gives no time, the row says so.

**Phone:** v2 was in shadow on 20 Nov, and Telegram was not used by rule. So "on the phone" was not measured: the page time is the
delivery time.

Two windows were measured:
- **A. 09:00-15:35, before any change.** No service was touched in market hours; girtrader.com/login answered in 0.04-0.07 s all day.
- **B. 15:37-17:50, after the fixes** installed at 15:36-15:38.

Targets are shown twice: the order's target, and the desk's Monday target (filings 20 s, wires 60 s, regulators 120 s).

**Not done here: the Sunday re-measure that the desk asked for.** It is a re-run of the same tools on Sunday's items, with no code
change needed. The steps are under "How to re-measure" at the end.

## Summary (plain words)

| source | target (order / Monday) | A: before, 09:00-15:35 | B: after, 15:37-17:50 | verdict | what is left |
|---|---|---|---|---|---|
| I1 NSE filings | 15 / 20 s | GIR lag median 34 s, worst 71 s (147 filings). F&O on the page: median 45 s | median 11 s, worst 19 s (106 filings) at the evening 15 s poll; F&O on the page median 14 s | **OK** for Monday's 20 s | In market hours the poll is 4 s, so expect about 5-10 s. Not yet measured in a live session. |
| I1 BSE filings | 15 / 20 s | GIR lag median 34 s, worst 64 s (239 filings) | median 44 s, worst 70 s; **BSE answers 403 since 16:16** (backing off, up to 15 min) | **LATE + BLOCKED** | The delay is BSE's own (its API serves a list cached about 30-60 s). The 403 started at 16:16 with no change on our side. See fixes. |
| I1 exchange circulars | 15 / 20 s | NSE / BSE circulars read every 5 min. BSE times were also stamped 5.5 h early (bug) | BSE GMT bug fixed. Circulars read every 60 s 09:00-15:30 (every 5 min after) | LATE (minutes) | Monday market hours: up to about 60 s plus BSE's own lag. |
| I2 TV speech -> news line | 60 s | TV to news.map ideas: median 28 s, worst 41 s (67). No plain TV news line existed | **"TV only - unverified" lines on news.list: median 29 s, worst 36 s (21)** | **OK** | Spoken-to-text is about 15-25 s of that. YouTube's own delay behind the live broadcast cannot be measured. |
| I3 wires / publishers | 30 / 60 s | F&O stories against the publishers' own sitemap times: median 278 s (17). The RSS pubDate understates this (RSS-timed median 71 s) | fast path (sitemaps / RSS every 20-60 s): median 129 s, worst 564 s (24). ET 79 s, Moneycontrol 147 s, BS 192 s, CNBC-TV18 235 s | **LATE** (better, still 2-4 min) | The rest of the delay is how long the publishers take to put a story into their own sitemap or RSS. A paid wire is the only way under 60 s. |
| I4 world headlines | 60 s | FinancialJuice free: GIR median 69 s, worst 140 s (175). Trump: read every 5 min in the day | FinancialJuice median 58 s (88). Trump every 60 s all day. investingLive added, but its CDN serves the feed up to about 1 h stale | about OK (FinancialJuice), LATE (investingLive) | The free FinancialJuice tier is itself delayed. |
| I4 world prices | live | Yahoo futures (Brent, S&P, Nasdaq, copper, gold, DXY) are **about 600 s old at the source**. Nikkei / Kospi 900-1200 s. US 10y only in US hours. **GIFT NIFTY stale on the page 23:59-09:22** | unchanged. LME official (Westmetall, daily) and US Treasury close added | **LATE / MISSING pre-open** | GIFT pre-open is a Kite key-4 timing problem (below). Live futures need a paid feed. |
| I5 regulators / PIB / Parliament | 60 / 120 s | v2 had RBI only (every 5 min, median 540 s) and BSE / NSE circulars. **No SEBI / PIB / TRAI / CCI / sansad on the page** | new regs poller: PIB 139 s, sansad press 449 s (then set to 2 min), BSE notices 107-249 s, RBI 432 s (the old bonds path, read at start). **PIB / sansad / SEBI / TRAI / CCI now on the page** | LATE vs 60 s; PIB near the 120 s Monday target | SEBI and CCI give a date only (no time), so no delay can be measured for them. IRDAI is closed to robots. |
| I6 sectors vs NSE indices | - | checked at 10:30 / 12:30 / 14:30 | - | **OK** | 13 sectors with a direct NIFTY index: mean gap 0.11-0.14 pp, worst 0.38 pp. See I6 below. |
| I7 calendar | - | cal.next MISSING (not built) | **cal.next LIVE**: economic events with IST time, consensus and previous; F&O board meetings; NSE holidays; expiries | built | India's own data releases are not in the free calendar file. |
| I8 health + alarm | - | one row per page adapter only | **34 "src ..." rows on the Health page** with the last item time, plus **one alarm per silence** (health.alarm) | built | It caught BSE's 403 at 16:25 on its own. There is no phone ring yet (no Telegram by rule). |

## A. Market hours 09:00-15:35 (before the fixes)

Window 2026-11-20 09:00-15:35 IST, made 2026-11-20T17:41:46+05:30

### I1 filings (NSE + BSE) - order target <= 15 s, desk Monday target <= 20 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | NSE filing | HYUNDAI - Analysts/Institutional Investor Meet/Con. Call Updates | 09:51:08 | 09:51:24 | 09:51:28 | 17 | 3 | 20 | LATE | OK |
| 2 | BSE filing | HYUNDAI - Hyundai Motor India Ltd - 544274 - Announcement under Regulation 30 (L | 09:51:36 | 09:52:35 | 09:52:37 | 59 | 2 | 61 | LATE | LATE |
| 3 | NSE filing | GODREJCP - General Updates | 12:49:55 | 12:50:14 | 12:50:17 | 19 | 3 | 22 | LATE | LATE |
| 4 | NSE filing | KAYNES - Analysts/Institutional Investor Meet/Con. Call Updates | 15:27:22 | 15:27:53 | 15:27:57 | 32 | 3 | 35 | LATE | LATE |
| 5 | BSE filing | KAYNES - Kaynes Technology India Ltd - 543664 - Announcement under Regulation 3 | 15:32:05 | 15:33:05 | 15:33:07 | 60 | 2 | 62 | LATE | LATE |

5 items: median **35 s**, worst **62 s**.

### I3 wires / publishers - order target <= 30 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | wire NDTV Profit | MAXHEALTH - MCX, Max Healthcare, CarTrade, Dr Lal Among UBS' 8 Midcap Bets. The 45% Upside C | 08:18:10 | 09:02:29 | 09:02:36 | 2659 | 7 | 2666 | LATE | LATE |
| 2 | wire Business Standard | HDFCBANK - Nifty Bank hits new high; HDFC Bank, ICICI Bank rally up to 21% in November | 12:08:49 | 12:20:51 | 12:20:55 | 723 | 3 | 726 | LATE | LATE |
| 3 | wire CNBC-TV18 | AMBUJACEM - Ambuja Cements Share Price: Jefferies sees 20% upside on volume recovery and cos | 12:28:10 | 12:29:25 | 12:29:38 | 76 | 12 | 88 | LATE | LATE |
| 4 | wire (market headline) Moneycontrol Live Blog | Markets@1 / Sensex up 775 points, Nifty above 25700 / The Sensex was up 775.26 points or 0 | 13:08:21 | 13:09:33 | 13:09:39 | 72 | 6 | 78 | LATE | LATE |
| 5 | wire ET | TRENT - Trent eyes 200 stores annually, MD P Venkatesalu says offline expansion is "cons | 15:04:37 | 15:05:27 | 15:05:33 | 51 | 5 | 56 | LATE | OK |

5 items: median **88 s**, worst **2666 s**.
- DEAD / MISSING: feed returns 0 items or an error: Google News · Financial Express, RBI

### I2 TV speech-to-text - order target <= 60 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | TV CNBC-TV18 (speech-to-text) | Adding. I think the biggest delta has come from foreign long only who  -> TECHM,COFORGE,INFY,TCS | 09:14:13-09:14:27 (spoken in this 10 s segment) | 09:14:37 | 09:14:47 | 22 | 10 | 32 | OK | OK |
| 2 | TV CNBC-TV18 (speech-to-text) | In the burst scenario, it goes to 30% from here down. Still, it will b -> SBICARD,BAJFINANCE,MUTHOOTFIN,MANAPPURAM | 10:19:24-10:19:38 (spoken in this 10 s segment) | 10:19:45 | 10:19:50 | 19 | 5 | 24 | OK | OK |
| 3 | TV CNBC-TV18 (speech-to-text) | It's a little more because of the expected MSCI rebalancing by the end -> COFORGE | 11:36:05-11:36:19 (spoken in this 10 s segment) | 11:36:22 | 11:36:24 | 15 | 2 | 17 | OK | OK |
| 4 | TV CNBC-TV18 (speech-to-text) | Month lows onto this 1, and zinc is trading at a 4 month lows as well. -> HINDZINC,VEDL,MUTHOOTFIN,MANAPPURAM | 12:54:04-12:54:18 (spoken in this 10 s segment) | 12:54:28 | 12:54:44 | 22 | 16 | 38 | OK | OK |
| 5 | TV CNBC-TV18 (speech-to-text) | Right? So this is a bit of a counter move to that. Exactly. In fact, i -> INFY,TCS,SBIN,HDFCBANK | 14:40:04-14:40:18 (spoken in this 10 s segment) | 14:40:26 | 14:40:41 | 20 | 15 | 35 | OK | OK |

5 items: median **32 s**, worst **38 s**.

### I4 world news + cues - order target <= 60 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | FinancialJuice free RSS | China's Xi meets Australian prime minister: state media | 07:43:39 | 07:44:28 | 07:44:30 | 49 | 2 | 51 | OK | OK |
| 2 | FinancialJuice free RSS | UK Core Retail Sales MoM Actual 0.9% (Forecast 0.1%, Previous -0.7%) | 12:30:02 | 12:30:29 | 12:30:36 | 27 | 7 | 34 | OK | OK |
| 3 | FinancialJuice free RSS | ECB's Pereira: Key question is whether energy price pressures spread to rest of economy. | 15:16:47 | 15:18:29 | 15:18:30 | 102 | 1 | 103 | LATE | LATE |

5 items: median **51 s**, worst **103 s**.

### I5 regulators / Parliament / PIB - order target <= 60 s, desk Monday target <= 120 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | exchange circular (v2 circulars) | BSE notice: Review of Margin Framework for Commodity Derivatives Segment (time corrected: BSE's GMT had been read as IST) | 09:30:21 | 09:33:18 | 09:33:31 | 177 | 13 | 190 | LATE | LATE |
| 2 | exchange circular (v2 circulars) | BSE notice: SUVIDHAA INFOSERVE LIMITED - Extension of Rights issue up to Monday, November  (time corrected: BSE's GMT had been read as IST) | 11:30:47 | 11:33:18 | 11:33:35 | 151 | 17 | 168 | LATE | LATE |
| 3 | exchange circular (v2 circulars) | BSE notice: Suspension of Trading in T-bills/Government Securities (time corrected: BSE's GMT had been read as IST) | 13:08:54 | 13:13:18 | 13:13:37 | 264 | 19 | 283 | LATE | LATE |
| 4 | RBI press release (v2 bonds, RSS) | RBI: Result of the Second 3-day Variable Rate Repo (VRR) auction held on November 20, 2026 | 13:40:00 | 13:43:56 | 13:43:59 | 236 | 3 | 239 | LATE | LATE |
| 5 | exchange circular (v2 circulars) | BSE notice: Change of Name on account of Amalgamation (time corrected: BSE's GMT had been read as IST) | 14:47:48 | 14:48:22 | 14:48:40 | 34 | 18 | 52 | OK | OK |

5 items: median **190 s**, worst **283 s**.
- DEAD / MISSING: no v2 poller (page shows nothing) for: SEBI, IRDAI, TRAI, CCI, DGCA, PIB, sansad.in - only the OLD regwatch / govwatch (every 2 min, Telegram, no page)
- DEAD / MISSING: SEBI RSS sebirss.xml returns 0 items (checked 20 Nov 07:40)

**Notes for window A:**
- **I3, why the RSS times understate the delay.** Against the publisher's own news-sitemap time, CNBC-TV18 articles reached GIR in a
  median 272 s and Business Standard in 533 s. GIR's RSS-timed figure (median 71 s) looks better only because the RSS pubDate is
  often later than the real publication time.
- **I3, dead and broken feeds:**
  - Moneycontrol latestnews.xml / business.xml: the newest item is from 2024 (dead).
  - ET markets RSS is cached 2-10 min (Cache-Control max-age 128 / 580).
  - NDTV Profit via feedburner was about 30-45 min stale.
  - Reuters returns 401 to bots. NDTV Profit's sitemap returns 403.
  - RBI and SEBI RSS give 0 items in the old macro.py.
  - Google News adds 1-80 h (median 78 min).
- **I1, the NSE announcements RSS** (nsearchives) was tried as a second path. It is slower (median 179 s), so it is not used.
- **I2, tvcalls junk.** Before the fix it wrote calls such as "TVSMOTOR SELL" from "...pharmaceutical product is selling...", and
  matches from the other channel. There were 44 tvcalls rows in market hours.

## B. After the fixes 15:37-17:50

Window 2026-11-20 15:37-17:50 IST, made 2026-11-20T17:41:32+05:30

### I1 filings (NSE + BSE) - order target <= 15 s, desk Monday target <= 20 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | NSE filing | ABCAPITAL - Shareholders meeting | 15:41:50 | 15:41:55 | 15:41:59 | 5 | 4 | 9 | OK | OK |
| 2 | BSE filing | FEDERALBNK - Federal Bank Ltd - 500469 - Announcement under Regulation 30 (LODR)-An | 15:44:40 | 15:45:43 | 15:45:45 | 63 | 2 | 65 | LATE | LATE |
| 3 | BSE filing | WAAREEENER - Waaree Energies Ltd - 544277 - Execution Of Power Purchase Agreement B | 16:10:51 | 16:11:34 | 16:11:37 | 43 | 3 | 46 | LATE | LATE |
| 4 | NSE filing | INDUSINDBK - General Updates | 16:46:45 | 16:46:53 | 16:46:56 | 8 | 3 | 11 | OK | OK |
| 5 | NSE filing | TITAN - Analysts/Institutional Investor Meet/Con. Call Updates | 17:36:07 | 17:36:18 | 17:36:20 | 12 | 2 | 13 | OK | OK |

5 items: median **13 s**, worst **65 s**.

### I3 wires / publishers - order target <= 30 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | fast path cnbctv18 | HDFCBANK - HDFC Bank changes BizBlack Metal rewards: How much must cardholders spend to ear | 15:31:19 | 15:40:27 | 15:40:30 | 548 | 3 | 551 | LATE | LATE |
| 2 | fast path cnbctv18 | market - Rupee could strengthen to 92 against dollar, may test 91 if RBI does not interve | 16:02:51 | 16:07:57 | 16:07:58 | 306 | 1 | 307 | LATE | LATE |
| 3 | fast path et | market - SEBI explores its own AI model, plans framework to boost bond trading; Simplifie | 16:41:58 | 16:43:24 | 16:43:29 | 86 | 5 | 91 | LATE | LATE |
| 4 | fast path mc | market - Rupee surges 76 paise to seven-month high of 92.68 against US dollar on equity i | 16:42:57 | 16:43:55 | 16:43:59 | 58 | 4 | 62 | LATE | LATE |
| 5 | fast path bs | market - RBI clarifies ₹10 lakh EDF threshold applies to each inward remittance | 17:17:11 | 17:19:10 | 17:19:14 | 119 | 4 | 123 | LATE | LATE |

5 items: median **123 s**, worst **551 s**.

### I2 TV speech-to-text - order target <= 60 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | TV line (news.list) | HDFCBANK -  TV CNBC-TV18: Some upside from here. Absolutely. And I know that pain that Ni | 15:41:38-15:41:52 (spoken in this 10 s segment) | - | 15:42:04 | - | - | 24 | OK | OK |
| 2 | TV line (news.list) | MOTILALOFS -  TV CNBC-TV18: A bunch of people, right, looking at what they are, and these a | 15:46:30-15:46:44 (spoken in this 10 s segment) | - | 15:47:08 | - | - | 36 | OK | OK |
| 3 | TV line (news.list) | AXISBANK -  TV CNBC-TV18: Banks at 20%. So between 20 to 40% is the kind of rally we've s | 15:54:01-15:54:15 (spoken in this 10 s segment) | - | 15:54:38 | - | - | 35 | OK | OK |
| 4 | TV line (news.list) | IREDA -  TV CNBC-TV18: Through the course of the week. The other big winners in the br | 16:10:09-16:10:23 (spoken in this 10 s segment) | - | 16:10:32 | - | - | 21 | OK | OK |
| 5 | TV line (news.list) | INDIGO -  TV CNBC-TV18: Nonpayment of penalty imposed by DGC in May this year. 7th conc | 16:23:51-16:24:05 (spoken in this 10 s segment) | - | 16:24:27 | - | - | 34 | OK | OK |

5 items: median **34 s**, worst **36 s**.

### I4 world news + cues - order target <= 60 s, desk Monday target <= 60 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | FinancialJuice free RSS | China's Xi meets Australian prime minister: state media | 07:43:39 | 07:44:28 | 07:44:30 | 49 | 2 | 51 | OK | OK |
| 2 | FinancialJuice free RSS | Yemen's Houthis: Saudi Arabia's Shugaiq power plant will be targeted in coming hours in re | 17:28:18 | 17:29:11 | 17:29:16 | 53 | 5 | 58 | OK | OK |
| 3 | investingLive RSS (v2 world) | investingLive: Is Nvidia stock a buy or sell? My opinion and 'buy the dip' trade plan | 16:38:35 | 17:33:19 | 17:33:20 | 3284 | 1 | 3285 | LATE | LATE |

5 items: median **58 s**, worst **3285 s**.

### I5 regulators / Parliament / PIB - order target <= 60 s, desk Monday target <= 120 s

| # | source | item | source time | GIR seen | page seen | GIR lag s | page after GIR s | delay s | vs order | vs Monday |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | RBI press release (v2 bonds, RSS) | RBI: Government Stock - Full Auction Results | 15:30:00 | 15:37:04 | 15:37:12 | 424 | 8 | 432 | LATE | LATE |
| 2 | pib (v2 regs) | PIB: 16th Round of Commercial Coal Mine Auctions Draws Overwhelming Response; 85 Bids Rece | 16:23:00 | 16:25:04 | 16:25:19 | 124 | 15 | 139 | LATE | LATE |
| 3 | exchange circular (v2 circulars) | BSE notice: Discontinuation of Market Making for SME Scrip | 17:07:58 | 17:12:01 | 17:12:07 | 243 | 6 | 249 | LATE | LATE |
| 4 | exchange circular (v2 circulars) | BSE notice: Listing of New Securities of Virtuoso Optoelectronics Limited. | 17:24:48 | 17:27:08 | 17:27:11 | 140 | 3 | 143 | LATE | LATE |
| 5 | exchange circular (v2 circulars) | BSE notice: Enabling of SMART Switch Feature under BANDHAN NIFTY COMMODITIES INDEX FUND -  | 17:35:27 | 17:37:11 | 17:37:14 | 104 | 3 | 107 | LATE | OK |

5 items: median **143 s**, worst **432 s**.
- DEAD / MISSING: SEBI RSS sebirss.xml returns 0 items (checked 20 Nov 07:40)

## I6 - sector data vs the official NSE sector indices (3 checks)

GIR's sectors are built from **every listed share** of each mapped sector (R49): 26 sectors, size-weighted by NSE market cap of 19 Nov,
with an equal-weight figure and breadth (up / down) beside it. Each check compared them with ONE NSE /api/allIndices read taken at
the same minute. Files: `probe/sector_1030.json`, `sector_1230.json`, `sector_1430.json`.

| check | GIR time / NSE time | 13 sectors with a direct NIFTY index: mean gap, worst gap, same direction | 9 sectors on a proxy index: mean gap, worst |
|---|---|---|---|
| 10:30 | 10:30:07 / NSE stamp 10:28 | 0.13 pp, worst 0.36 pp (IT 2.54 vs 2.90), same direction 13 of 13 | 0.77 pp, worst 2.50 (hospitals 2.89 vs NIFTY HEALTHCARE 0.39) |
| 12:30 | 12:30:12 / 12:28 | 0.14 pp, worst 0.38 pp, same direction 11 of 13 (capital markets +0.37 vs -0.01; chemicals -0.16 vs +0.02, both near zero) | 0.79 pp, worst 2.66 (hospitals) |
| 14:30 | 14:30:13 / 14:28 | 0.11 pp, worst 0.33 pp, same direction 12 of 13 | 0.88 pp, worst 2.85 (hospitals) |

**Why they differ:**
1. **Members.** GIR uses every listed share in the sector, for example 39 IT shares against NIFTY IT's 10, and 34 banks against
   NIFTY BANK's 12-14. Breadth differs for the same reason: GIR 25 up / 14 down in IT against the index's 10 / 0.
2. **Weights.** GIR uses full market cap (NSE, 19 Nov). NSE uses free-float market cap with caps (for example 33% / 62% in NIFTY BANK).
3. **Proxy indices.** There is no official index for hospitals (NIFTY HEALTHCARE includes pharma), telecom services (NIFTY MIDSMALL IT &
   TELECOM is mostly IT), insurance, capital goods or services. Those gaps are about definitions, not errors.
4. **Timing.** NSE's allIndices stamp was 2 minutes behind each read.

Electronics, textiles, telecom equipment and utilities have no NSE index to compare with.

## I7 - calendar (cal.next)

**Built and live since 15:37** (gir-v2sources calendar poller, rebuilt every 3 h, then cal.next on the page). Sources:
- the public weekly economic calendar file (faireconomy): time in IST, consensus, previous, impact;
- NSE board meetings for the next 9 days (F&O shares, plus every results row);
- NSE holidays (**Tue 24 Nov**) and expiries from the contract file (stock monthly 23 Nov and 29 Dec; NIFTY weekly 1 Dec).

Shown today: 9 rows, including INDIANB and ENRIN board meetings, the 24 Nov holiday and today's US / UK / EU events.

**Limits:**
- Monday's economic events appear when the weekly file switches on Sunday (its week starts Sunday, US time).
- India's own releases (CPI, IIP, GDP, PMI, RBI) are not in that file. A hand list `v2/data/ext/calendar_india.json` is read if
  present; without it the page shows "not known" with the reason.
- NSE gives board meetings as a date only, with no time.
- Results season is over: only 1 F&O board meeting falls in the week (INDIANB, 20 Nov).

## I8 - Health page and the silent-source alarm

**Built and live since 15:37.** health.feeds now carries one `src <name>` row per outside source (34 rows today):
- filings NSE, filings BSE;
- each gir-v2sources poller (16);
- each wire publisher (12);
- each TV channel (2);
- the news reader and newsmap.

Each row shows the last item time, the last good poll and the reason when it is not LIVE. A source past its silence limit turns
STALE / DOWN, and the Health page verdict names it.

**health.alarm** keeps ONE alarm per silence: logged once, and cleared with a "BACK" line when the source speaks again.

**Real test:** at 16:25 it raised "src filings BSE STALE: no good read for 10 min (HTTP 403)" on its own.

**Known small issues, fixable at the next permitted gir-preview restart:**
- a poller in back-off right after a service restart alarms once (FinancialJuice answered 429 to two restarts 2 minutes apart);
- the same TV reading can show twice on news.list when the news reader read it twice.

## Fixes - installed today (15:36-15:38 IST, v2 services only, each with a backup and an undo line in v2/BUILD_LOG.md)

**I1 filings (gir-v2filings)**
- NSE announcements are read with a changing query parameter. The plain URL is served from Akamai's cache (Server-Timing "cdn-cache
  HIT", about 40 s old); with the parameter it is a cache MISS, so we get the current list. The rate stays the same (4 s in market
  hours, 15 s in the evening).
- Result: NSE median 34 s before, 11 s after.

**I1 circulars (gir-v2sources)**
- Circulars read every 60 s in 09:00-15:30 (was every 5 min).
- BSE notices.xml time is now read as the real GMT. It used to be taken as IST, so 09:30 IST notices were stamped 04:00.

**I2 TV**
- news.list now carries "TV only - unverified" lines. A line appears only when the name matcher and the news reader agree on the
  company, or the reader gives weight 3 or more.
- gir-v2tvcalls:
  - context is kept per channel;
  - the share must be named in the same or the previous 10 s piece;
  - the naming must pass the company-in-context rules in engine_next/newsmatch.py (N1-N6);
  - BSE / MCX need "Ltd / shares / stock" next to the name;
  - "selling", "buying", "sell-off" and "buyback" are not calls.
- On a replay of 1.2 days the new rules gave 10 calls; the junk class (TVSMOTOR from "selling", cross-channel subjects, the BSE
  exchange as a word) is gone.

**I3 publishers - new fast path p_wires (gir-v2sources)**
- ET news sitemap every 20 s (ETag).
- CNBC-TV18 news sitemap every 45 s, plus its latest RSS every 30 s.
- Business Standard latest and markets RSS (ETag).
- **Moneycontrol news-sitemap.xml every 60 s, in place of the dead Moneycontrol RSS.**
- Rows that name an F&O share also go to news.list.
- Not changed: **the OLD system's macro.py still reads the dead Moneycontrol RSS** (old system untouched by rule; it goes silent on
  Monday).

**I4 world**
- Trump / White House every 60 s all day (was every 5 min in the day).
- FinancialJuice every 60 s (was 120 s).
- New p_world poller: investingLive RSS, US Treasury par yields (official close) and the LME official cash / 3-month prices via
  Westmetall. These are the real LME prices; the page's "copper" so far was COMEX HG=F, about 10 min delayed.

**I5 regulators - new p_regs (desk map WEB_SOURCES.md section 5)**
- RBI press / notifications RSS every 60 s; speeches every 5 min.
- SEBI What's New and circulars listings every 60 s (date only).
- TRAI RSS (posted time).
- CCI press-release JSON (time taken from the PDF's upload stamp).
- PIB English RSS. Without `&reg=3`, PIB redirects to Hindi. Each new release page is read once for its posted time.
- sansad.in: press releases every 2 min, bills every 10 min (one row per status step), sitting-day check every 6 h, daily calendar
  every 2 min on sitting days only. Parliament is not sitting; the Winter Session is not in the data yet.
- LiveLaw news sitemap (court news naming an F&O share or a regulator / tax / tariff matter).
- Recruitment, tender and workshop notices are tagged ADMIN and kept off the page.

**I5 page-hash watcher p_pagewatch**
- egazette home (5 min), CBIC GST, CDSCO notices and alerts, APTEL, AERA (15 min), GERC (6 h).
- egazette, APTEL, AERA and GERC send an incomplete TLS chain. Their missing intermediates were taken from the certificates' own AIA
  links:
  - Let's Encrypt YR1;
  - ISRG Root YR cross-signed by ISRG Root X1;
  - Sectigo DV R36.
- They are added to a **private bundle** `v2/sources/certs/regs_bundle.pem` (certifi plus these 3), used only by this poller. Every
  chain was checked with `openssl verify -verify_hostname` (OK). **Verification is never off; the system trust store was not
  touched.**

**I7 / I8 (gir-preview, one restart, under the edit lock)**
- cal.next.
- 34 Health source rows plus health.alarm.
- ext.* read every 5 s, only when a file changed (was 20 s).
- news.map read every 5 s (was 15 s).
- TV, regulator and fast-path lines on news.list.

## Fixes - still needed (not done; owner / decision named)

1. **BSE filings 403 (I1).** BSE's API has answered 403 to this server since 16:16. Nothing on our side changed for BSE; the
   back-off is working (30 s doubling up to 15 min). Re-check on Sunday:
   - if it persists, keep the back-off;
   - use BSE's own notices / RSS for circulars;
   - do NOT evade the block.

   BSE's normal delay (about 30-60 s at the source) cannot be fixed from our side.
2. **GIFT NIFTY pre-open (I4 / J1).** gir-v2kq quotes GIFT only from 08:59, and key 4's token file was written at **09:22** today.
   So the page had no fresh GIFT from 23:59 to 09:22, which covers the whole pre-open and the 07:15 run. Needed:
   - quote GIFT from the key that logs in first;
   - quote it from 06:30, not 08:59;
   - J1 must log key 4 in before 08:00.

   This is for the J1 / engine owner; not changed here.
3. **Wires under 60 s (I3).** Sitemaps cut the delay roughly in half (ET 79 s is the best). The rest is the publishers' own publishing
   delay. Paid options, **only with the trader's yes (none subscribed):**
   - PTI news feed (the Indian wire the publishers take first): quote needed;
   - Reuters Connect: quote needed;
   - X API credits (journalists, regulators, TV reporters in seconds): up to about Rs 9,250 a month at the 900-posts-a-day cap
     (v2/PAID.md row 7).

   ET Prime is already signed in. Moneycontrol Pro (about Rs 42 a month) and Business Standard digital (about Rs 167-225) give full
   articles, not speed (PAID.md rows 4-6).
4. **Live world futures (I4).** The free Yahoo data is about 10 min behind for CME / ICE (Brent, S&P, Nasdaq, copper, gold, DXY) and
   15-20 min for Nikkei / Kospi. Paid options, only with his yes:
   - COMEX via Databento: about $179-199 a month plus a CME licence of about $35 a device, about Rs 20,000-22,000 (PAID.md row 10);
   - ICE Brent: exchange fees of $100-445 per user a month plus vendor fees;
   - a delayed or end-of-day vendor feed instead: written quote needed;
   - FinancialJuice Pro squawk (live headlines): price to confirm on financialjuice.com (not checked today).

   MCX copper / aluminium / crude in Kite (data only, Rs 0, PAID.md row 3) are already live in MCX hours; they are the real-time
   metals and crude path.
5. **PIB / RBI under 60 s (I5).** PIB's RSS itself lags about 2-6 min (posted 16:19, in the RSS by about 16:25). RBI is fine at 60 s
   now; the 432 s item came from the old 5-min bonds path at start-up. The Monday target of 120 s is reachable for RBI; PIB is
   borderline.
6. **Hosts that cannot be read from this server** (desk list of 19, tested 20 Nov):

   | host | why |
   |---|---|
   | www.npci.org.in, www.mca.gov.in, indianrailways.gov.in | 403 (not evaded) |
   | nppaindia.nic.in | no DNS |
   | bombayhighcourt.nic.in, eparlib.sansad.in, sansadtv.nic.in | connection time-out |
   | www.tnerc.tn.gov.in | **certificate expired 22 Oct 2026**: not trusted, not bypassed |
   | irdai.gov.in, policyholder.gov.in | robots.txt "Disallow: /" for every robot |
   | cdsco.gov.in, aptel.gov.in, aera.gov.in, gercin.org, cbic-gst.gov.in, rsdoc.nic.in, archive.pib.gov.in, grid-india.in | reachable: the first five are polled; rsdoc only matters while Parliament sits; archive.pib is covered by the PIB RSS; grid-india is daily data (F24), not news |

   egazette's Extraordinary list sits behind ASP.NET postbacks (no rows to a plain GET); only its home notices are watched.
7. **investingLive** is behind a CDN that serves its RSS up to about 1 h stale (s-maxage 300, stale-while-revalidate 3600). It is kept
   as a witness only, not as a fast source.
8. **CNBC-TV18 sitemap** lagged about 9 min on 2 items; its RSS was added beside it at 16:26 (measure on Sunday).

## How to re-measure (Sunday or any day)

```
cd /home/globalbot/girdata/review/monday/probe
for s in pageprobe filewatch worldwatch sitemapwatch; do PROBE_STOP=22:30 nohup setsid nice -n 15 python3 $s.py >> $s.err 2>&1 < /dev/null & done
# later:
python3 analyze.py --day 2026-11-22 --from 07:00 --to 22:00 --out out --tag sunday && python3 render.py out/external_delays_sunday.json
```

All probes are read-only. pageprobe opens ONE local stream connection to the page. Tools and raw files are in
`girdata/review/monday/probe/` (not pushed).
