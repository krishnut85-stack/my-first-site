# NO DISGUISE - replacements for the three refusing hosts (built + shadow-proved 21-22 Nov night)

Rule (DESK_REVIEW 21 Nov 22:05 item 4): GIR does not disguise itself and does not evade a site's rules (robots.txt / 403).
Three hosts are still read with the browser-style User-Agent (common.HDR) and refuse a declared reader. This page shows free
replacements that **allow the declared name** (`GIR-newsreader/1.0 (+public pages only; polite polling, 1 request per 3 s per host)`),
runs them **next to** the live feeds, and compares the values. **Nothing live was switched**: alerts, pages, desk and gir-v2sources
read exactly what they read before. The decision is the trader's.

How the shadow runs: `v2/sources/p_shadow.py` (6 parts) run by `v2/sources/shadow_run.py` in **its own process** (nice 10, its own
status file `shadow_status.json`, never `status.json`), every request through `common.get` (1 request / 3 s / host, back-off on
401/403/429), declared name passed explicitly. It writes only `v2/data/ext/shadow_<name>_now.json` + `shadow_<name>.jsonl` (one
comparison line per poll vs the live file; no news rows). Started 21 Nov 23:39 IST (first runs) / 23:46 (service loop) and **left
running overnight** so the morning has more evidence. Numbers below are as of 22 Nov 00:17 IST; re-run them with
`python3 v2/sources/shadow_compare.py` (read only). Stop it: `kill $(pgrep -f '^python3 /home/globalbot/intraday/v2/sources/shadow_run.py')`.
Tests: `sources/test_shadow.py` 5/5 (fixtures only, no network, live files hash-checked); whole sources suite 38/38.

---

## 1. query1.finance.yahoo.com (robots.txt: `User-agent: *` / `Disallow: /`)

What it fed: p_gauges (BTC + ETH 5-min bars -> last / 1 h / 24 h / since India's last close; US 2y from 2YY=F; B2 shock rows:
BTC >= 5% in 24 h or >= 3% in 1 h, US 2y >= 15 bp), p_gauges MoneyMap (22 US sector / size / bond / credit funds, gold, dollar, yen,
BTC, world ETFs - daily %), p_uswrap closes (12 index / commodity closes -> us_overnight.json) and world_quotes (28 SHOCK_SYMS,
5-min bars every 5 min, families A / B / E incl. 30-min change).

### 1a. Bitcoin / Ether -> Kraken public OHLC (primary) + Coinbase Exchange candles (cross-check)

| host | robots.txt (declared name) | GET with declared name |
|---|---|---|
| api.kraken.com `/0/public/OHLC?pair=XBTUSD&interval=5` (and `=15`) | 404 = no robots file (RFC 9309: allowed) | 200, JSON, 720 bars |
| api.exchange.coinbase.com `/products/BTC-USD/candles?granularity=300` | 401 = no readable robots file | 200, JSON, 300 bars |
| api.binance.com klines | **Disallow** | (not used) |
| api.coingecko.com | **Disallow** | (not used) |

Comparison, 9 polls 23:39-00:17 IST (live = gauges_now.json, Yahoo BTC-USD):

| gauge | Kraken minus live, at the SAME bar time (n=7) | Kraken minus live, poll vs poll (n=9) | Coinbase minus live (n=9) |
|---|---|---|---|
| BTC price | -0.017% mean, max 0.068% | -$16 mean, max $50 | -$21 mean, max $72 |
| BTC 1 h % | -0.007 pts mean, max 0.08 | max 0.27 | max 0.12 |
| BTC 24 h % | -0.014 pts mean, max 0.08 | max 0.68 (polls minutes apart) | max 0.13 |
| BTC since Fri 15:30 IST % | - | -0.026 mean, max 0.08 | not available (300 bars = 25 h) |
| ETH price | -0.039% mean, max 0.091% | | |
| ETH 1 h / 24 h % (same bar) | max 0.08 / 0.11 pts | | |
| B2 shock flags (BTC) | **agree 9 / 9** (none fired either side) | | |

The 0.27 / 0.68 point gaps in the poll-vs-poll column come only from timing (the shadow polls a few minutes after the live one); read at the same bar time, the largest gap is 0.08 points.
Kraken is one exchange (BTC/USD on Kraken), Yahoo is an aggregate: the price level differs by about 0.02-0.07%, about 50x smaller than the 3% / 5% thresholds.
**What would be lost:** nothing material. Kraken 5-min history is 60 h, so the "since Friday close" anchor on Monday morning comes
from Kraken 15-min bars (the bar that ends at 15:30 IST; one extra request every 30 min). Proven in test_shadow.

### 1b. US 2-year -> US Treasury daily par yield curve (official, end of day)

| host | robots.txt | GET with declared name |
|---|---|---|
| home.treasury.gov `.../pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value_month=YYYYMM` | `Allow: /` | 200, XML (already read live by p_world) |
| finance.yahoo.com/quote/2YY%3DF/ | allowed | **404** (the 2YY=F page no longer exists) |
| FRED | refuses this server (earlier notes) | - |
| www.cnbc.com/quotes/US2Y | - | 403 (not used) |
| www.wsj.com / www.marketwatch.com | Disallow | 401 (not used) |

| | live (Yahoo 2YY=F) | Treasury 2-year |
|---|---|---|
| level | 4.75% | 4.63% (20 Nov close) |
| day change | -2.5 bp | **-13.0 bp** (19 -> 20 Nov) |
| last data | 13 Oct 2026, marked `stale: true` | 20 Nov 2026 |

**Finding:** the live US 2y gauge has been **stale since about 13 Oct** (2YY=F stopped trading on Yahoo), so the B2 "US 2y >= 15 bp" check
is already skipped every time (it ignores stale readings). Treasury gives a working gauge: the 20 Nov move was -13 bp, close to the threshold.
**What would be lost:** intraday. Treasury posts once a day after the US close (about 03:00-05:00 IST), so the check fires the morning after, not
during the US session. No free, allowed intraday 2-year yield was found. ZT=F (2-year note **future price**) is on the allowed
finance.yahoo.com/markets/commodities/ page and could serve as an intraday direction proxy (not built, not proven).

### 1c. US closes, money map, world quotes -> finance.yahoo.com pages (robots allows `/quote/` and `/markets/`)

finance.yahoo.com robots.txt (`User-agent: *`) disallows /m/, /xhr, /_td_api, /quotes/*, /quote/*/earnings/*.html and similar, and
**allows** `/quote/<sym>/` and `/markets/...`. The declared name gets 200 (finance.yahoo.com is already in DECLARED_HOSTS). The
page itself carries the price data as embedded JSON blocks (price module + 5-min spark for the page's symbol; list pages carry 20-30
quotes each). Plainly stated: this is **Yahoo's own data, read through the pages its robots.txt allows** instead of the API host it
disallows. Whether Yahoo's terms of use permit automated reading at all is a separate question; the trader should decide that too.
Other candidates checked: cdn.cboe.com delayed quotes **403** to the declared name; stooq (robots no - not touched); Google Finance
(robots Disallow); WSJ / MarketWatch (Disallow, 401); CNBC (403).

US closes (shadow_usclose, 2 runs, 32 quote pages each, every 3 h) vs live us_overnight.json (Yahoo daily bars):

| symbol | page close / prev / % | live close / prev / % | agree? |
|---|---|---|---|
| S&P 500 | 6910.39 / 7175.83 / -3.70 | same | yes |
| Nasdaq Comp | 22617.73 / 23879.2 / -5.28 | same | yes |
| Dow | 48147.33 / 49097.1 / -1.93 | 48147.33 / 49097.06 / -1.93 | yes |
| SOX | 8408.59 / 9419.72 / -10.73 | same | yes |
| Nikkei / KOSPI / Taiwan | -5.06 / -5.21 / -6.23 | same | yes |
| Hang Seng | 22410.8 / 23294.8 / **-3.79** | 22410.8 / 22841.62 / **-1.89** | prev close differs (live world_quotes.json also says -3.79: the live daily-bar series is the odd one out) |
| Brent | 89.95 / 89.44 / +0.57 | 92.57 / 91.98 / +0.64 | different contract month (live daily bars vs live world_quotes, which shows 89.95 like the page) |
| WTI | 83.41 / 82.44 / +1.18 | 83.98 / 83.21 / +0.93 | same contract-roll effect |
| gold | 3515.4 / 3685.5 / -4.62 | same | yes |
| dollar DXY | 103.84 / 103.807 / +0.03 | 103.81 / 103.90 / -0.09 | small; settlement vs last-trade close |
| money map: 19 funds (XLK ... INDA) | e.g. XLK -7.27, SMH -10.60, TLT +1.37, HYG -0.26, INDA +1.71 | **identical % on all 19 funds** | yes |
| money map: BTC-USD | +2.09 (24 h, now) | -1.53 (map at 11:10) | timing only |

World quotes (shadow_worldq, 5 polls, 3 list pages every 10 min + quote pages every 30 min for symbols that are on no list) vs live world_quotes.json: **all 28 symbols found**.
26 of the 28 match on last price and day % (S&P / Nasdaq / Dow and their futures, SOX, Nikkei, KOSPI, Taiwan, Hang Seng, Shanghai,
DAX, FTSE, US 10y, DXY, yen, Brent, gold, silver, copper, nat gas, the 4 ADRs). CNY=X differs by 0.21% (list quote 6.6623 vs live 5-min bar 6.6765) and INR=X by 0.01%.
**What would be lost:**
- the bar-based 30-min change (pct30). The shadow builds it from its own poll history, so it is empty for the first 30 min after a restart, and on a closed market it shows 0 where the live one shows the last 30 min of Friday's bars.
- cadence: 10 min in the shadow (5 min would mean 3 page reads every 5 min).
- weight: one page is about 1.1 MB, against about 10 KB for one API call. The world quotes cost 3 pages per poll (they replace 28 API calls). US closes + money map cost 32 pages, at most every 3 h (the closes change once a day).

---

## 2. api.nasdaq.com (robots.txt: `User-agent: *` / `Disallow: /`)

What it fed: p_macro Peers: earnings calendar for the 20 global peers (ACN, CTSH, EPAM, IBM, JPM, BAC, C, WFC, GS, MS, MU, NVDA,
AVGO, TSM, INTC, ORCL, FDX, NKE, XOM, CVX), 35 days ahead -> peers_calendar.json -> 'PEER RESULTS today / tomorrow' rows (R5).

Replacement: **finance.yahoo.com/quote/<peer>/** pages (allowed, declared name, 200). The page carries
`calendarEvents.earnings.earningsDate` (exact time) and `isEarningsDateEstimate`. 20 pages once a day (06:00 / 18:00 IST), about 20 MB.
Checked and not usable: finance.yahoo.com/calendar/earnings (allowed, but the table loads in the browser and is not in the page);
www.nasdaq.com earnings pages (allowed, but they read api.nasdaq.com in the browser); Zacks / MarketBeat / Earnings Whispers not tried.

| peer | live (Nasdaq) | shadow (Yahoo page) | note |
|---|---|---|---|
| ORCL | 14 Dec, after close | 14 Dec 21:00 UTC, after close | agree |
| ACN | 17 Dec, pre-market | 17 Dec 13:30 UTC, pre-market | agree |
| NKE | 17 Dec, time not given | 17 Dec 21:00 UTC, after close | shadow has the time |
| MU | **16 Dec**, time not given | **17 Dec** 21:00 UTC, after close | **disagree, needs a check** (Micron IR page) |
| AVGO | missing (the live Nasdaq request for 9 Dec failed: no 2026-12-09 key in peers_calendar.json) | **9 Dec**, after close | shadow found one the live feed missed |
| the other 15 | no date in the next 35 days | next date beyond 35 days (Jan 2027) or last quarter's date (not yet announced) | agree |

**What would be lost:** Nasdaq's EPS forecast text (`eps_fc`). The Yahoo page carries `earningsAverage`, which could be added.
Yahoo shows a peer's *next* date only, which is enough for a 35-day window.

---

## 3. api.sci.gov.in (survey 23:2x: 403 to the declared name)

What it fed: p_sci, Supreme Court cause-list PDFs (daily + advance lists), F&O company names -> sci rows + sci_tags_<date>.json.

**Retest tonight: api.sci.gov.in serves the declared name.** robots.txt answers 200 with an **empty** file (allows everything).
- 23:3x: `GET /jonew/cl/2026-11-26/M_J_1.pdf` with the declared name (and common.HDR's Accept headers) -> **200, 978,769 bytes,
  byte-identical** (`cmp`) to the file the live poller downloaded.
- shadow_sci (23:39 and 23:49 runs): www.sci.gov.in/cause-list/ (allowed, already declared) gives 15 PDF links. A 1-byte range
  request per PDF with the declared name -> **15 / 15 answered 206**, and all **15 / 15 match the live poller's size + ETag** (state/sci_done.json).
- I could not reproduce the survey's 403. A guess (not proven): it was a one-off, or it came from a different path such as the host root, which answers 200 with an empty body tonight.
- webapi.sci.gov.in (also matched by p_sci's regex) timed out from this server. It is not needed.

**What would be lost:** nothing. Same host, same files. No separate replacement source is needed: the fix is to declare the name.

---

## Switch plans (one line each; none applied)

| host | switch | undo |
|---|---|---|
| api.sci.gov.in | common.py: add `"api.sci.gov.in"` to `DECLARED_HOSTS` (under `mkdir sources/common.py.edit.lock`), then the sources suite, then `gir-restart gir-v2sources` | `cp sources/common.py.bak<HHMM>rep sources/common.py; gir-restart gir-v2sources` |
| query1 (crypto) | p_gauges.py `Gauges.read`: replace the `C.get(Y5 % yq(sym))` loop with `p_shadow.ShadowCrypto().read()`'s `btc` / `eth` (Kraken 5-min + 15-min anchor) | `cp sources/p_gauges.py.bak<HHMM>rep sources/p_gauges.py; gir-restart gir-v2sources` |
| query1 (US 2y) | p_gauges.py `Gauges.read`: `g["us2y"] = p_shadow.ShadowRates().treasury()` (daily; keep the `stale` rule: > 3 days) | same backup line |
| query1 (closes / map / world quotes) | p_uswrap.py `closes()` and p_gauges.py MoneyMap: `p_shadow.ypage(sym)`; p_uswrap.py `world_quotes()`: `ShadowWorldQ` list pages (pct30 from its own history) | `cp sources/p_uswrap.py.bak<HHMM>rep ...; cp sources/p_gauges.py.bak<HHMM>rep ...; gir-restart gir-v2sources` |
| api.nasdaq.com | p_macro.py `Peers.poll` refresh: build `days` with `p_shadow.peers_days({s: p_shadow.ypage(s) for s in PEERS}, today)` instead of `NASDAQ_EARN` | `cp sources/p_macro.py.bak<HHMM>rep sources/p_macro.py; gir-restart gir-v2sources` |
| the shadow itself | after a switch: stop shadow_run.py (command above) | restart: `setsid nohup nice -n 10 python3 v2/sources/shadow_run.py >> /home/globalbot/girdata/ext/shadow_run.log 2>&1 &` |

Suggested order: (1) api.sci.gov.in (no data change at all). (2) crypto (Kraken, matches within 0.1 pts). (3) US 2y from Treasury (the live gauge is already dead). (4) peers (check MU first). (5) closes / world quotes last, after the trader rules on reading Yahoo's pages.

---

## NSE / BSE endpoints the pollers use, tested with the DECLARED name (21 Nov 23:35-23:37 IST, one request each, 6 s apart)

Read only. Nothing was changed: these pollers still send the browser-style header. NSE APIs were called after a declared-name warm-up of the
insider page (cookies), with the pollers' own Referer / Accept. Saturday night, low load: **repeat once in market hours before
switching** (NSE / BSE bot rules may differ under load, and BSE blocked fast polling on Fri 16:16).

| endpoint (used by) | HTTP | real data? | declared UA works | robots allows |
|---|---|---|---|---|
| www.nseindia.com/companies-listing/corporate-filings-insider-trading (cookie warm-up, common.NSE_WARM) | 200 | HTML 357 KB | yes | yes (`Allow: /`, only /market-data-test disallowed) |
| NSE /api/corporate-announcements (feeds/filings.py) | 200 | JSON | yes | yes |
| NSE /api/corporates-pit-gg (p_insider) | 200 | JSON, 132 rows | yes | yes |
| NSE /api/corporate-sast-reg29 (p_insider) | 200 | JSON | yes | yes |
| NSE /api/corporate-pledgedata-sast3132 (p_insider) | 200 | JSON | yes | yes |
| NSE /api/corporate-pledgedata (p_insider) | 200 | JSON | yes | yes |
| NSE /api/corporate-board-meetings (p_calendar) | 200 | JSON | yes | yes |
| NSE /api/circulars (p_circulars) | 200 | JSON, 131 rows | yes | yes |
| NSE /api/block-deal (p_blockdeals) | 200 | JSON | yes | yes |
| NSE /api/snapshot-capital-market-largedeal (p_blockdeals) | 200 | JSON | yes | yes |
| nsearchives.nseindia.in circular PDF (p_circulars) | 200 | PDF 362 KB | yes | no robots.txt (404) = allowed |
| www.bseindia.com/corporates/ann.html (feeds warm-up / bse_bridge) | 200 | HTML | yes | no robots file (robots.txt returns the HTML home page) |
| www.bseindia.com/data/xml/notices.xml (p_circulars) | 200 | RSS | yes | same, no robots file |
| www.bseindia.com/Data/XML/InsiderTradingFeed.aspx (p_insider) | 200 | RSS, 39 items | yes | same |
| www.bseindia.com/Data/XML/IndexMediaReleaseFeed.aspx (p_indexes) | 200 | RSS, 0 items (empty, as on 19 Nov) | yes | same |
| www.bseindia.com/xml-data/corpfiling/AttachLive/<id>.pdf (filing PDFs) | 200 | PDF 526 KB | yes | same |
| api.bseindia.com HomeBulkblockDealNew (p_blockdeals) | 200 | JSON | yes | same (robots.txt returns HTML) |
| api.bseindia.com AnnSubCategoryGetData (feeds/filings.py) | 200 | JSON, 50 rows | yes, tonight (it refused gir-v2filings with 403 from Fri 16:11) | same |

---

## Files

- NEW `v2/sources/p_shadow.py`, `v2/sources/shadow_run.py`, `v2/sources/shadow_compare.py` (read only), `v2/sources/test_shadow.py`
- NEW outputs `v2/data/ext/shadow_{crypto,rates,usclose,worldq,peers,sci}{_now.json,.jsonl}`, `v2/data/ext/shadow_status.json`; log `girdata/ext/shadow_run.log`
- `v2/BUILD_LOG.md` one row (backup `.bak2347rep`). common.py, run.py, the live pollers, alerts and pages were **not** touched; gir-v2sources was **not** restarted.
