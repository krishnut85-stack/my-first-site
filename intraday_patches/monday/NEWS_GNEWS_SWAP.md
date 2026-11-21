# NEWS GNEWS SWAP - per-share coverage before / after (DESK_REVIEW 21 Nov 22:05 item 4)

Made 21 Nov 22:08 IST by GIR code (read only over news.db, v2/data/ext/wires.jsonl, v2/data/filings_lag.jsonl). Universe: the 218 F&O names in v2/newsread/ref/aliases.json. A share counts as covered when at least one item in the window names it. 'confirmed' = the headline really names the company (the news reader's alias table + ambiguous-name rules, server/news_gate.names_in); Google News per-share queries also return lines that only matched the query (e.g. 'Attack on Titan' for TITAN).

## What changed (21 Nov 22:05-22:11 IST) - GIR no longer fetches news.google.com

Google News robots.txt disallows generic readers; GIR does not evade a site's rules. Every place on this server that fetched
news.google.com (static scan of /home/globalbot/intraday, /home/globalbot/intraday/v2 and /home/globalbot/newshawk, then traced to the
running services and timers):

| file | what it fetched | used by (live) | change |
|---|---|---|---|
| intraday/newsroom.py google_news() | per-share search, browser User-Agent (the scouts: 5,392 items / 7 days) | gir-newsroom, gir-dash (scout_one), whydesk timer | returns [] - restarted |
| intraday/macro.py FEEDS | 13 "Google News · site:..." searches | gir-newsroom (market news loop), gir-intraday | GN entries filtered out of FEEDS (35 publisher / official feeds stay) - restarted |
| intraday/why.py google_news() | per-share search, browser UA | gir-intraday (why.lookup), gir-dash | returns [] |
| intraday/newsfresh.py google_real() | resolves a Google News article link via Google's own pages | gir-dash | returns None - restarted |
| intraday/overnight.py world() | world searches | gir-dash | returns [] - restarted |
| intraday/moverswhy.py search(), earlyteam.py (2), expect.py previews() | searches | gir-dash / parked jobs | return [] / skip |
| intraday/circuits.py news_of(), shockwatch.py gnews() | searches | tvwatch / v2 tvcalls import these modules but never call these two | return [] |
| v2/sources/p_uswrap.py FEEDS | 3 Google News US-close searches | gir-v2sources | filtered out - restarted |
| NOT changed (not running): intraday/govwatch.py, intraday/newshunt.py (parked 21 Nov 16:55), newshawk/regnews_bot.py, catalyst_ledger.py, check_sources.py | | | stay parked - must not be re-started without the same change |

**Still running old code: gir-intraday (engine2)** - it calls why.lookup -> Google News when a share moves. The fix is on disk; it takes
effect when gir-intraday restarts (left to the coordinator: the old engine can send Telegram health lines on start). A host-level block
of news.google.com was proposed and refused by the permission system - not done.

Proof so far: news.db got 7 Google News rows in the 30 min before the newsroom restart, 0 after (checked at 22:11).

**Publisher feeds added** (v2/sources/p_wires.py, generic User-Agent "GIR-newsreader/1.0", each allowed / listed in its robots.txt):
Livemint today sitemap (150 items, 13 F&O-named at test), Business Today news sitemap (268 / 31), BusinessLine companies RSS (60 / 8)
and markets RSS (60 / 6). They join what was already there: ET, CNBC-TV18 (sitemap + RSS), Business Standard (2 RSS), Moneycontrol
sitemap, Zee Business sitemap, Zerodha Pulse, plus macro.py's RSS (ET, ET Economy, Mint, BS, RBI, SEBI ...) and NSE / BSE filings.
All 12 wire parts polled OK at 22:10. **Financial Express is BLOCKED** (403 to a declared reader on every path) - not worked around.
Not read: Reuters (401 bot wall), NDTV Profit (sitemap 403). Note: the older wire parts (ET, CNBC, BS, MC) still send the
sources' default browser-style User-Agent (sources/common.py) - not changed tonight (p_wires is shared with the sources builder); flagged.

## Window: 7 days (news.db only goes back 7 days for Google News; filings from 15 Nov 07:30 IST; v2 sitemaps from 20 Nov 15:40 IST)

| path | shares covered (of 218) | items | median delay min (n) |
|---|---|---|---|
| BEFORE: Google News per-share queries (any line) | 216 | 5736 | 85.0 (5736) |
| BEFORE: Google News, headline confirms the company | 216 | 5110 | 92.9 (5110) |
| AFTER: publisher feeds only (RSS + sitemaps) | 201 | 1217 | 3.3 (1217) |
| AFTER: NSE / BSE filings only | 113 | 310 | 0.8 (310) |
| AFTER: publisher feeds + filings | 207 | 1527 | 2.2 (1527) |

Delay = seen by GIR minus the source's own publish / exchange time (Google News: t_seen - t_pub in news.db; sitemaps: lag_s; filings: lag_s; macro.py RSS: t_seen - t_pub).

Shares with a CONFIRMED Google News item but NO publisher / filing item in this window (lose all coverage): **11**

ATHERENERG, DELHIVERY, HAL, HINDPETRO, IEX, KFINTECH, LTF, SHREECEM, SONACOMS, TIINDIA, TORNTPHARM

Shares covered AFTER that Google News never had: 2 - DRREDDY, SOLARINDS

No item from either path in 7 days: 0

## Window: common window since the v2 publisher sitemaps started (20 Nov 15:40 IST, 30 h)

| path | shares covered (of 218) | items | median delay min (n) |
|---|---|---|---|
| BEFORE: Google News per-share queries (any line) | 182 | 860 | 105.5 (860) |
| BEFORE: Google News, headline confirms the company | 180 | 761 | 119.5 (761) |
| AFTER: publisher feeds only (RSS + sitemaps) | 54 | 103 | 4.1 (103) |
| AFTER: NSE / BSE filings only | 47 | 83 | 0.3 (83) |
| AFTER: publisher feeds + filings | 81 | 186 | 1.4 (186) |

Delay = seen by GIR minus the source's own publish / exchange time (Google News: t_seen - t_pub in news.db; sitemaps: lag_s; filings: lag_s; macro.py RSS: t_seen - t_pub).

Shares with a CONFIRMED Google News item but NO publisher / filing item in this window (lose all coverage): **101**

360ONE, ADANIENT, ADANIPORTS, ADANIPOWER, ALKEM, AMBER, AMBUJACEM, ANGELONE, ATHERENERG, BAJAJFINSV, BAJFINANCE, BANDHANBNK, BANKBARODA, BANKINDIA, BEL, BHARATFORG, BHARTIARTL, BIOCON, BOSCHLTD, CDSL, CGPOWER, CIPLA, CONCOR, COROMANDEL, DATAPATTNS, DELHIVERY, DLF, EICHERMOT, GAIL, GODREJCP, GODREJPROP, GRASIM, GVT&D, HAL, HDFCAMC, HDFCLIFE, HINDALCO, HINDUNILVR, HINDZINC, HYUNDAI, ICICIBANK, ICICIGI, ICICILIFE, IDFCFIRSTB, INDHOTEL, INDUSTOWER, INFY, INOXWIND, IREDA, ITC, JINDALSTEL, JSWSTEEL, JUBLFOOD, KAYNES, KEI, KFINTECH, KOTAKBANK, LAURUSLABS, LICHSGFIN, LODHA, LTF, LTM, LUPIN, M&M, MANAPPURAM, MANKIND, MAZDOCK, MOTHERSON, MPHASIS, MUTHOOTFIN, NAM-INDIA, NATIONALUM, NAVINFLUOR, NBCC, NESTLEIND, OBEROIRLTY, OIL, ONGC, PAGEIND, PAYTM, PERSISTENT, PHOENIXLTD, PIDILITIND, PIIND, PNB, PNBHOUSING, POLICYBZR, SBICARD, SBILIFE, SHREECEM, SUZLON, SWIGGY, SYRMA, TATAELXSI, TMPV, TVSMOTOR, ULTRACEMCO, UNOMINDA, UPL, VMM, WIPRO

Shares covered AFTER that Google News never had: 2 - LICI, VOLTAS

## AFTER, shares per source family (7 days)

| source | shares |
|---|---|
| publisher RSS (macro.py) | 198 |
| filing NSE | 94 |
| filing BSE | 65 |
| filing | 57 |
| publisher sitemap (v2 wires: et) | 23 |
| publisher sitemap (v2 wires: cnbctv18) | 10 |
| publisher sitemap (v2 wires: mc) | 8 |
| publisher sitemap (v2 wires: bs) | 6 |
| publisher sitemap (v2 wires: cnbctv18_rss) | 3 |

## Reading the numbers

- Over 7 days the publisher feeds + filings name 207 of 218 F&O shares (Google News: 216); median delay 2.2 min vs 92.9 min.
- The 30 h window is Friday evening + Saturday: the v2 sitemap store only exists since 20 Nov 15:40, so the AFTER column there is thin
  (81 shares); Google News per-share queries return old and weekend-padded articles for almost every share, which is why it "covers" 180.
- The 11 shares that lose all coverage over 7 days had only Google News lines - mostly slow re-posts. The four feeds added tonight
  (Mint, Business Today, BusinessLine x2) are not in these numbers yet (added 22:09); re-measure Monday 16:00 with this same script.
- Script (read only): girdata/review/monday/NEWS_GNEWS_SWAP_cov.py (python3 it > file); inputs news.db, v2/data/ext/wires.jsonl, v2/data/filings_lag.jsonl.
