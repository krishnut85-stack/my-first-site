# GIR - THE DATA-COLLECTION PLAN (one plan for every source)

Written 18 Nov 2026 by the lead data-collection engineer, from: BRIEF.md, the five source maps in this folder
(map_exchanges_regulators, map_brokers_vendors, map_global_markets, map_news_media, map_alternative_industry) and
/home/user/my-first-site/intraday_patches/GIR_SPEC.md (DATA LIST #1-#49, EXTERNAL DATA E1-E6, S1-S4, S9, checklist A-I).

For the Claude session running ON the GIR server (/home/globalbot/intraday). GIR serves ONE trader who BUYS NSE stock CE / PE
intraday, exits by 15:10, sector-first. Every job below exists to answer one question: **which F&O shares, which side, which
strike, today, and when.** A job that feeds none of the steps in section 3 is not in this plan.

Ground rules carried from the spec:
- Trial week (from 19 Nov): no page changes. Everything here is back-end collection, recording, health and the analyst's inputs.
  New numbers reach the trader only through the analyst's notes, the decisions Telegram channel and the system (health) bot.
- No call from stale or unverified data (B6.1). Every stored number carries its source, its source timestamp and its fetch time.
- Kite login stays manual (S9). Personal use only, gentle polling, no redistribution (section 8).
- URLs, file names and times come from the maps; anything marked [verify] in a map stays [verify] here and is on the
  verify-first list (section 10), to be checked once from the Mumbai server before the fetcher is coded.

---------------------------------------------------------------------------------------------------------------------------------

## 0. Conventions used in every table

### 0.1 Step codes - which share-selection step a job feeds
| Code | Step | Time |
|---|---|---|
| N19 | 19:45 note (night watch list) | 19:45 |
| N07 | 07:15 note (overnight + final sector shortlist) | 07:15 |
| U08 | 08:45 update (China data, changes since 07:15, pre-flight) | 08:45 |
| P09 | 09:08 pre-open check | 09:00-09:08 |
| C09 | 09:20 sector confirmation (checklist C; never before 09:20) | 09:20-10:00 |
| SP | share pick inside the confirmed sector (checklist D) | 09:20-14:30 |
| OG | option gate (checklist E, S8 IV-crush filter) | before every call |
| HX | holding / exit (checklist G) | in a trade |
| SC | 15:45 scorecard and miss audit (spec trial rules, 7.2, I) | 15:45 |
| GATE | reference gate - a failure blocks the share / the day (B6.4, S7) | 08:45 and live |
| HIST | history that has no free source - recorded for IV rank, RVOL, baselines, replay | daily |

### 0.2 Collector codes - which team member (agent) owns the job
Every job has an owner so the 15:45 scorecard can say "ran / found / woke the analyst / failed" per team member (spec 2.3).
Collectors are plain code unless marked; the AI tiers of S4 only read what they store.

| Code | Team member | Collects |
|---|---|---|
| FD | Feed keeper (new line in the scorecard; code) | Kite websockets on 4 keys, REST sweeps, second feed, raw frame recorder |
| DK | Data keeper (B6 / S3 "data engineer"; code) | reference files, NSE EOD files, reconciliation, heartbeat, health report, backups |
| WP | World prices agent | GIFT, MCX, CDS, Yahoo / Stooq / CNBC, LME, Sina / AKShare, settlements, world snapshots |
| GN | Global / world news agent | economic calendar + consensus + actuals, central banks, China data, US policy, GDELT |
| NR | News reader (collectors + small model) | NSE / BSE filings, wires, publisher sitemaps, live blogs, RSS, push sources, latency record |
| PM | Policy map | SEBI, RBI, PIB / ministries, CBIC, DGTR, DGFT, gazette, courts, USFDA, Federal Register |
| TV | TV watcher | CNBC-TV18 (later CNBC Awaaz, RBI / PIB live streams) speech-to-text |
| PO | Pre-open agent | cash IEP and futures pre-open series 09:00-09:08 |
| MO | Money agent | futures OI all months, F&O bhavcopy, participant OI, block-deal windows, build-up cross-checks |
| OP | Options agent | per-strike IV / greeks / spread / depth, ATM IV history, NSE chain cross-check, expired-option history |
| SE | Sector agent (+ rotation) | sector / index minute series, breadth, equal-weight sector, movers list |
| TH | Theme agent | driver -> sector -> shares map, industry calendar, VAHAN / MoCA / IEX / Grid-India / fuel prices, today's risk strip |
| KB | Knowledge base | name table, sector map, results calendar, nightly derived history (ATR, levels, RVOL baselines) |
| AN | Senior analyst | consumer only (writes the notes); never collects |

### 0.3 Validation codes - every job runs the ones listed in its row
"Two clocks" (spec S3): a number is fresh only if BOTH the source's own timestamp is recent AND the values are still changing.
A file being rewritten is NOT freshness (see code issue 6.2-f).

| Code | Check | Failure means |
|---|---|---|
| T | Clock 1 - source timestamp present, parseable, timezone normalised, inside the job's expected window (exchange_timestamp, Last-Modified, regularMarketTime, `an_dt`, LME date, RSS pubDate) | STALE |
| C | Clock 2 - values changed vs the previous good fetch (value hash); frozen counter (price and volume unchanged 60 s in market hours = stale even if the process is alive) | STALE |
| N | Row / item count inside the expected range for this source and time of day (e.g. NSE announcements 20-200 per hour in session; 0 in 10 min at 11:00 = broken) | ERROR |
| D | Trading date inside the file = the expected trading date (fo_secban carries T+1; bhavcopies carry T); holiday master decides what "expected" is | ERROR |
| S | Schema: required columns / fields present, types parse, no unknown columns (alarm on a schema change - NSE renames without notice, e.g. UDiFF Jul 2024, combineoi 2025) | ERROR |
| E | Empty body, HTML where JSON / CSV was expected, captcha / "Request Denied" page, HTTP 200 with an error text = ERROR, never "no news" (the wrong-URL case, B6.5) | ERROR |
| X | Cross-source agreement within a stated tolerance (Kite vs NSE, Yahoo vs MCX, GIR IV vs NSE / Upstox IV) | MISMATCH (blocks the share if it is a GATE item) |
| R | Range sanity (e.g. commodity move < 15% a day, IV 5-200%, spread >= 0, price inside the circuit band) | ERROR |
| K | Contract / roll check: the same contract code as the reference price (no continuous-symbol roll jumps) | ERROR |

Every job writes one heartbeat row per run: {job, source, src_ts, fetched_at, value_hash, rows, checks_failed, error}. The 60-s
checker (S3.1) judges each row against limits that change with the clock (market hours: prices 10 s, OI 3 min, sectors 2 min,
news 15 min; night: news 2 h; EOD files: by their deadline in this timetable).

### 0.4 Storage layout (server: /home/globalbot/intraday)
| Path | What | Written when |
|---|---|---|
| `rec/raw/YYYY-MM-DD/<job>/<HHMMSS>_<source>.<ext>.gz` | Every HTTP response body + status + headers (Last-Modified, ETag) for files, JSON, RSS, pages; stored only when the body changed | at fetch, by the collector |
| `rec/ticks/YYYY-MM-DD/<key>_<conn>.frames` | Raw binary websocket frames, each prefixed with receive time in ns (Kite), and `upstox.frames` | writer thread off the live path; zstd after 15:35 |
| `rec/tv/YYYY-MM-DD/<channel>.jsonl` | Transcript snippets with chunk times (never audio / video) | live |
| `rec/instruments/YYYY-MM-DD/*.csv.gz` | Every day's Kite instrument dump and NSE contract file - KEPT FOREVER (the only map from old tokens to contracts once they expire) | 08:00-08:45 |
| `db/ref.sqlite` | instruments, contracts, lots, expiries, holidays, F&O universe, ban, MWPL (EOD + live estimate), corporate actions, name table, sector map | evening / 08:45 |
| `db/eod.sqlite` | bhav_cm, bhav_fo, delivery, deals, fii_dii, part_oi, fii_stats, index_close, fovolt, fpi_nsdl | 16:30-21:00 |
| `db/world.sqlite` | world_snap (named snapshots), world_series_5m, gift_1m, mcx_1m, cds_1m, china_fut_1m, lme, settle, cny_fix, calendar, event_actuals | per job |
| `db/news.sqlite` | items, source_seen (first-seen per source), clusters, filings (parsed), policy_pipeline, latency_daily | continuous (single writer process, not the feed) |
| `db/events.sqlite` | results_cal, court_hits, usfda, industry calendar, today's risk strip | evening / 08:30 |
| `db/opt.sqlite` | atm_iv_min, atm_iv_daily, strike_snap (09:30 / 12:00 / 14:30), chain_xcheck | after 15:35 from session files |
| `db/industry.sqlite` | vahan_mtd, moca_daily, iex_dam, grid_psp, cea_coal, fuel_prices | daily |
| `db/session/YYYY-MM-DD/*.parquet` | 1-min bars (shares, futures all months, indices, MCX, CDS), VWAP, breadth, RS, RVOL, preopen series, option strike minutes | JSONL during the session, Parquet after 15:35 |
| `db/derived.sqlite` | ATR14, levels, RVOL baselines by minute-of-day, sector betas, IV rank, realised vol | 22:00-23:30 |
| `db/health.sqlite` | heartbeat, incidents, reconcile, xcheck | continuous |
| `db/ai.sqlite`, `db/journal.sqlite`, `score/YYYY-MM-DD/` | AI calls, trades, the 15:45 scorecard inputs and manifests | continuous / 15:45 |

Rules: the feed process never touches SQL (S2); low-rate tables (news, health) go through one writer process; tick-derived tables
are loaded after 15:35. Raw ticks kept 90 days on the server and archived off-server; everything in `db/` and
`rec/instruments/` kept forever. Backups nightly (J46).

### 0.5 Polling manners (apply to every job)
One keep-alive session per host; conditional GET (If-None-Match / If-Modified-Since); gzip; jitter +-20%; exponential back-off on
401 / 403 / 429 / 5xx with a circuit breaker per host; never parallel-hammer one host; a generic, honest User-Agent for RSS /
government sites (no personal contact in it); NSE JSON: cookie warm-up on the home page, refresh cookies every 5-10 min or on
401 / 403; NSE / BSE archives: 1 request per 3-5 s per endpoint at most; Yahoo <= 1 req/s with caching; ForexFactory <= 2
requests per 5 min per file; Sina one batched request per 10 s at most; Westmetall / LME once per evening.

### 0.6 Time rules
All times IST. US / EU-linked times below are for the current winter clock (US on EST until 14 Mar 2027, Europe until 28 Mar
2027); in summer they move one hour earlier and MCX closes 23:30 instead of 23:55. The scheduler stores each release in its
source's own time zone and converts daily - no hard-coded IST for foreign events. "T" = today's trading date, "T+1" = the next
trading day from NSE's holiday master. On an NSE holiday the world jobs still run; NSE files are not expected (a missing file on a
trading day is an alarm; on a holiday it is normal).

---------------------------------------------------------------------------------------------------------------------------------

## 1. THE DAILY TIMETABLE (weekday, 15:30 -> 15:30 next day)

Columns: ID · time / frequency · job · primary -> backup · method · owner · validation · store (raw -> parsed) · feeds.

### 1A. 15:30-16:30 - the close

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J01 | 15:30:30, 15:40 | Closing snapshot of every subscribed token: LTP, OHLC, volume, OI, depth, exchange time (the official close is the 15:00-15:30 VWAP - record both) | Kite feed memory -> K4 REST `/quote` sweep (500 per call) | memory dump + REST | FD | T (exchange time >= 15:29:30), N (= subscribed count +-1%), C (volume moved since 15:00) | ticks/<d>/ -> session/<d>/close_snap.parquet | SC, HIST |
| J02 | 15:31-15:50 | Close tick files, write frame counts per connection, zstd after 15:35, checksum manifest | FD writer thread | file ops | FD | N (frames per connection vs 20-day norm +-40%), list of sentinel gaps > 3 s | ticks/<d>/*.zst + manifest.json | HIST (replay) |
| J03 | 15:35-16:05 | Minute-candle reconciliation: Kite historical 1-min for 218 shares, futures (all months), indices vs candles built from ticks | Kite historical API on K4 (3 req/s, ~760 calls) | REST | DK | N (375 bars per share), X (OHLC within 1 tick, volume +-2%), D | raw/kite_hist -> session/<d>/bars_1m.parquet (official copy) | HIST (RVOL #20, ATR #21) |
| J04 | 15:31 | Day's orders, trades, positions; exact charges | Kite `/orders`, `/trades`, `/portfolio/positions`, `POST /charges/orders` | REST | DK | N (trades = journal entries), T | raw/kite_acct -> journal.sqlite | SC (B8), HX review |
| J05 | 15:32-15:40 | Movers list: every F&O share +-2% and every sector +-1% (prev close -> close and open -> close), with the minute the move began (first minute |ret| > 2.5x its time-of-day sigma and volume > 2x) | J01 + bars | code | SE | N = F&O universe; X vs NSE index closes (J12) when they land | score/<d>/movers.json | SC |
| J06 | 15:35-15:44 | Per-source news latency for the day's clusters: t0, first-seen per source, t_move, before-move flag; "missed the move" list | news.sqlite + bars | code | NR | N (clusters > 0; a silent source is listed) | news.latency_daily | SC, source promote / demote (map_news section 10) |
| J07 | 15:40 | Each agent's day line (ran / found / woke / reached the trader / errors); AI spend by model and hour | health + ai.sqlite | code | DK | - | score/<d>/agents.json | SC |
| J08 | continuous; session 1 ends 15:40, session 2 opens 16:05 or 16:35 [verify] and runs to 02:45 | GIFT Nifty minute series (Kite gives only LTP today - store every tick + 1-min bar) | Kite `NSEIX:GIFT NIFTY` on K1 C3 -> NSE IX market-watch page every 5 min | websocket | WP | T, C (moves within 5 min while open), R (within 5% of Nifty close) | ticks -> world.gift_1m | N19, N07, U08, P09, HIST |
| J09 | 15:30-23:55 (CDS to 17:00) | MCX metals / bullion / energy and CDS currency futures keep streaming after NSE closes | Kite K1 C3 (same connection as in session) | websocket | WP | T, C, R | ticks -> world.mcx_1m, cds_1m | N19, N07, HIST |
| J10 | 16:00 on release days (CPI ~12th, IIP ~28th, GDP last working day of Feb / May / Aug / Nov, PLFS) | India macro actual vs consensus -> surprise score | mospi.gov.in release -> PIB, wires | page / PDF poll 15 s 15:58-16:20 | GN | T (dated today), S (headline parsed), X (two sources) | raw/mospi -> world.event_actuals | N19 |
| J11 | 16:30 | Health report GREEN / AMBER / RED (B6.8); RED = next session starts read-only | heartbeat table | code | DK | - | health.sqlite; system Telegram bot | all |

### 1B. 16:30-19:45 - end-of-day files and the evening news (load now, use from the next day - checklist I)

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J12 | 16:30, then every 10 min until present (alarm 21:00) | All NSE index closes `ind_close_all_DDMMYYYY.csv` | nsearchives -> Kite index closes (J01) | conditional GET | DK | D, N (>= 100 indices), S | raw -> eod.index_close | N19, sector betas, SC |
| J13 | 17:00, every 10 min until present (alarm 20:00) | CM bhavcopy (UDiFF) `BhavCopy_NSE_CM_0_0_0_YYYYMMDD_F_0000.csv.zip` | nsearchives -> BSE CM UDiFF + Kite closes | cGET zip | DK | D, N (all F&O shares present), S (UDiFF columns), X (close vs J01 +-0.05%) | eod.bhav_cm | N19, levels #22, ATR #21 |
| J14 | 17:00-18:30 every 10 min | Bulk, block and short-selling | `content/equities/bulk.csv`, `block.csv`, large-deal JSON -> BSE bulk / block pages | cGET / JSON | DK | D, N (0-300), S | eod.deals | N19 (watch list only; H: never a call on its own) |
| J15 | 17:30-19:00 every 10 min | FII / DII provisional cash | NSE `/api/fiidiiTradeReact` -> NSE FII/DII page; NSDL next morning (J66) | JSON (cookie warm-up) | DK | D, N (2 rows), R | eod.fii_dii | N19, top bar |
| J16 | 17:30-19:30 every 10 min | F&O bhavcopy (UDiFF) `BhavCopy_NSE_FO_0_0_0_YYYYMMDD_F_0000.csv.zip` | nsearchives -> Kite closes / OI from J01 | cGET zip | MO | D, N (every F&O underlying's futures + options), S, X (OI vs Kite last OI +-1%) | eod.bhav_fo | N19, build-up history #13, rollover, IV-rank cross-check |
| J17 | 18:00-20:30 every 10 min (alarm 21:00) | Next day's ban list `fo_secban_DDMMYYYY.csv` (the date is T+1) | nsearchives -> NSE ban page JSON [verify]; manual check on a broker / NiftyTrader page | cGET | DK | D (= T+1, not T), N (0-40), S (symbols all in the F&O list) | ref.ban | GATE (OG), N19 |
| J18 | 18:00-20:30 every 10 min | Combined OI / MWPL `combineoi_DDMMYYYY.zip` (+ `nseoi_`) under the 2025 FutEq rules | nsearchives -> GIR's own estimate from J16 | cGET zip | DK | D, N (~ F&O count), S (2025 column set [verify]), R (0-120%) | ref.mwpl | GATE (near-ban >= 85% blocks), N19 |
| J19 | 18:00-20:00 every 10 min | Delivery: `sec_bhavdata_full_DDMMYYYY.csv`, MTO | nsearchives | cGET | DK | D, N, S, X (close vs J13) | eod.delivery | N19 (context only - H) |
| J20 | 18:30-19:30 | Participant-wise OI and volume | `fao_participant_oi_` / `_vol_DDMMYYYY.csv` | cGET | MO | D, N, S | eod.part_oi | N19 (index bias only - H) |
| J21 | 19:00-20:30 | FII derivatives statistics `fii_stats_DD-Mon-YYYY.xls` | nsearchives | cGET | MO | D, S | eod.fii_stats | N19 |
| J22 | 18:30-20:00 | Daily volatility `FOVOLT_DDMMYYYY.csv` [verify path] | nsearchives | cGET | OP | D, N, S | eod.fovolt | OG (realised vol beside GIR's IV) |
| J23 | 19:15, retry 21:00 | LME official cash / 3-month prices and LME warehouse stocks (official prices land 18:00-18:55) | Westmetall tables -> lme.com (next-day delayed) / Investing (manual) | HTML GET once | WP | T (LME date = today), C (changed vs yesterday), R | raw -> world.lme | N19, N07 |
| J24 | 18:30-20:30 (ore, steel, coal, palm, rubber), to 22:30 (base metals), to 00:00 (gold, silver, INE crude); every 60 s | China night session: DCE iron ore, SHFE rebar / HRC / copper / aluminium / zinc / nickel, coking coal, coke, palm olein, rubber, INE crude | Sina `hq.sinajs.cn` (nf_I0, nf_RB0, nf_HC0, nf_JM0, nf_J0, nf_CU0, nf_AL0, nf_ZN0, nf_NI0, nf_P0, nf_RU0, nf_AU0, nf_SC0) via AKShare -> Eastmoney API | one batched HTTP request | WP | T (quote time within 2 min while the session is open; session calendar aware - Golden Week "0%" = CLOSED), C, R (< 10%) | raw (sampled) -> world.china_fut_1m | N19, N07 |
| J25 | 17:00-23:00: SEBI / RBI / PIB RSS every 60 s; CBIC, DGTR, DGFT, e-Gazette, DIPAM, GST Council, CCI, SEBI orders page every 15 min (to 01:00) | Evening regulator / government releases into the policy pipeline (PENDING -> ANNOUNCED -> NOTIFIED) | official RSS / "what's new" pages -> wires; the trader's X Pro lists (manual) | RSS + page diff | PM | T, E, N (expected rate by hour) | raw/policy -> news.items + news.policy_pipeline | N19, N07 (E3) |
| J26 | 15:30-21:00 (part of J60) | Results and board outcomes after the close; XBRL parsed when present | NSE / BSE filings (J60) | - | NR | as J60 | news.filings | N19 |
| J27 | 19:00 (18:00 US summer) on US data days | US data actual vs consensus (CPI, payrolls, retail sales, PPI, claims, GDP, PCE); surprise score | official BLS / BEA page -> ForexFactory JSON (once, at 19:10, inside its rate limit) / wires | poll 15 s 19:00-19:05 | GN | T, S, X | world.event_actuals | N19 |
| J28 | 18:00 and 21:00 (Sun-Fri) | Economic calendar with consensus: ForexFactory weekly JSON + official calendars (BLS / BEA ICS, FRED release dates, Fed, RBI, BoJ, NBS, S&P PMI calendar, MoSPI) | `nfs.faireconomy.media/ff_calendar_thisweek.json` -> Nasdaq.com calendar JSON [verify] / Investing (manual) | GET (<= 2 per 5 min) | GN | S, N (> 30 events per week), T (file updated today) | world.calendar | N19, N07, U08 (E1 risk strip) |
| J29 | 19:15 | World snapshot W1945: Europe, US futures (explicit contract months), ADRs pre-market, VIX, DXY, INR=X, US 10y + 2y, Brent / WTI explicit months, COMEX gold / silver / copper (witness), every MCX contract, CDS 17:00 close, GIFT, LME (J23), Sina (J24); FedWatch read by a light page fetch or by hand | Yahoo v8 chart (query1 -> query2) -> Stooq CSV, CNBC quote service; MCX / CDS from Kite | REST (<= 1 req/s, cached) | WP | T (each symbol's market time fresh for its session), C, R, K, X (two witnesses: e.g. COMEX copper vs MCX copper; flag > 0.5%) | raw/world/1915 -> world.world_snap {driver, source, contract, value, ref_value, ref_kind (settle / official / close), ref_time, chg, src_ts, witness, witness_diff} | N19 |
| J30 | 19:30, re-run 21:30 | Tomorrow's cause lists: Supreme Court, NCLT, SAT (+ named High Court cases) matched to the name table (company, subsidiaries, promoters) | sci.gov.in, nclt.gov.in, sat.gov.in -> LiveLaw / Bar & Bench | PDF GET (never captcha pages) | PM | D (list date = T+1), N | raw -> events.court_hits | N19, OG (no premium into a hearing) |
| J31 | 19:35 | Results / board-meeting calendar and con-call schedule refresh | NSE board-meetings JSON + event calendar -> BSE forthcoming results -> NSE Board_Meetings RSS | JSON | KB | N, S, D | events.results_cal | N19, OG (results gate, IV crush), N07 |
| J32 | 19:40 | Freeze inputs and write the manifest for the 19:45 note (what is present, as of when; a missing core input is named in the note, never guessed) | all of the above | code | DK | section 1J rule | score/<d>/manifest_1945.json | N19 |
| - | 19:45 | THE 19:45 NOTE (consumer) | - | - | AN | - | ai.sqlite | - |

### 1C. 19:45-05:00 - the night (US session, settlements, policy, history jobs)

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J34 | 19:45-02:45 every 5 min | World series W5: US indices, futures (explicit months), ADRs (INFY, WIT, HDB, IBN, RDY), INDA, ACN / CTSH, SOX (fallback SOXX), VIX / VX=F, DXY, INR=X, CNH, JPY, US 10y / 2y, Brent / WTI explicit months, COMEX metals | Yahoo -> Stooq / CNBC | REST | WP | T, C, R, K | world.world_series_5m | N07, HIST (sensitivities) |
| J35 | 20:00-21:00 | Evening reconciliation Kite vs NSE (B6.4): closes, OI, lot sizes, contract list, corporate actions effective T+1 | J01, J13, J16, J63 | code | DK | X; any mismatch blocks that share for T+1 and is named in the 08:45 pre-flight | health.reconcile | GATE |
| J36 | Wed 21:00 (EIA petroleum), Thu 21:00 (gas storage), Fri 23:30 (rig count) | Oil events | EIA API v2 -> ForexFactory / wires | API | GN | T, S | world.event_actuals | N07 |
| J37 | 22:00 | VAHAN month-to-date registrations by maker / fuel / class (aggregates only) | VAHAN dashboard (once, gently) -> India Data Portal monthly copy | page / Excel download | TH | D (MTD date), N (>= 20 makers), C | raw -> industry.vahan_mtd | N19 (last 3 sessions of a month), SP on the 1st, HIST |
| J38 | 22:00-23:30 | Nightly derived history: ATR14, prev-day H/L, 20-day H/L, RVOL baselines per minute of day (20 days), sector betas, equal-weight sector series, delivery vs 20-day, ATM IV daily close -> IV rank / percentile (once >= 60 days or seeded), realised vol | own db + Kite historical top-up on K4 | code | KB | N (every F&O share), R | derived.sqlite | P09, C09, SP, OG |
| J39 | 22:30-03:00 (phase 2) | History seeding: expired-option 1-min with IV and OI (ATM-relative strikes, 1-2 years, all F&O shares); spot checks | Dhan Expired Options Data API (Rs 499 / month) -> ICICI Breeze (free, 5,000 calls / day) | REST batch inside limits | OP | N, S, X (vendor IV vs GIR Black-76 on the same minute +-2 vol points) | hist/opt_expired.parquet | OG (IV rank from week 2), results-reaction table (E4.3) |
| J40 | 23:00 and 02:00 daily; Tue 19:30-Wed 03:00 every 30 min | USFDA: warning-letter page, Import Alert 66-40 firm-list diff, openFDA approvals; Data Dashboard Indian FEIs weekly | fda.gov, accessdata.fda.gov, api.fda.gov -> wires | GET / API | PM | S, N, E | raw -> events.usfda | N07 (pharma PE / CE watch) |
| J41 | 23:00, 02:00, 05:30 | US policy: Federal Register API (incl. public-inspection documents a day ahead), White House presidential actions, USTR press | federalregister.gov API -> wires | API / RSS | PM | T, N | news.items (policy) | N07 |
| J42 | 23:55 (23:30 US summer) | MCX close snapshot (reference for the morning) | Kite K1 C3 | websocket | WP | T, C | world.mcx_close | N07 |
| J43 | 00:30 / 01:00 on FOMC days | Fed statement and press conference | federalreserve.gov RSS -> wires / squawks | RSS 15 s 00:29-00:45 | GN | T | world.event_actuals | N07 |
| J44 | 01:00-01:15 | Settlements = reference prices for the next day's % moves: ICE Brent, NYMEX WTI / Henry Hub, COMEX gold / silver / copper | ICE Report Center / CME settlement pages -> Yahoo `previousClose` of the same explicit contract | GET | WP | D (settle date), R, K | world.settle | N07 (references) |
| J45 | 02:35-02:50 | US close snapshot W0245: final US indices, ADRs, sector ETFs, INDA; GIFT session-2 close | Yahoo -> Stooq | REST | WP | T (market time >= 02:30), C | world.world_snap | N07 |
| J46 | 03:00-04:30 | Housekeeping: backups of db/ and rec/instruments off the server, compress raw, disk / memory / clock / certificate checks, test-restore one file; on review nights MSCI / FTSE announcements (~03:30-04:30) | - | - | DK | disk free > 30%, backup checksum | backups | all |

### 1D. 05:00-08:00 - early morning (Asia, China, the 07:15 note)

Note on the Kite token gap: Kite tokens expire about 06:00, so Kite's GIFT Nifty feed stops between 06:00 and the trader's
login. Either the trader logs in key 1 before 07:00 (still manual, S9), or J47 fills the gap from NSE IX's page.

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J47 | GIFT session-1 open (06:30, or ~05:15 under the new hours [verify]) until Kite login; every 5 min | GIFT Nifty before Kite is logged in | NSE IX market watch -> Moneycontrol / Investing GIFT page (manual) | light GET | WP | T (page time), C | world.gift_1m (source = nseix) | N07, U08 |
| J48 | 05:30-09:00 every 5 min | Asia: Nikkei, Kospi (05:30), Taiwan, A50 (06:30), Shanghai / CSI300 / Hang Seng (07:00) | Yahoo (15-20 min delayed) -> Stooq | REST | WP | T, C | world.world_series_5m | N07, U08 |
| J49 | 06:00-06:30 on the 1st | ATF and commercial LPG revisions | iocl.com product prices -> HPCL / BPCL sites, news | GET | TH | D (effective today) | industry.fuel_prices | N07 (INDIGO, OMCs, city gas) |
| J50 | 06:30-09:15 every 30 s; 09:15-12:30 every 60 s | China day session (same Sina basket as J24) | Sina / AKShare -> Eastmoney | batched HTTP | WP | as J24 | world.china_fut_1m | N07, U08, P09, C09 (metals, steel) |
| J51 | 06:45 | USD/CNY central-parity fixing | CFETS chinamoney.com.cn -> Yahoo CNY=X, news | GET | WP | D, R | world.cny_fix | N07 |
| J52 | 06:30 (LPR, 20th), 07:00 (NBS PMI month end; CPI / PPI ~9th), 07:15 (RatingDog PMI 1st business day), 07:30 (activity data ~15-17th), ~08:30 (trade) | China data actual vs consensus | stats.gov.cn, pmi.spglobal.com, pbc.gov.cn -> ForexFactory actual, wires | poll 15 s around the minute | GN | T, S, X | world.event_actuals | N07 (if before 07:15), U08 |
| J53 | 06:45 | World snapshot W0700: as J29 plus US close (J45), settlements (J44), FedWatch, Treasury curve, LME last official, MCX close (J42), Sina day session, GIFT, CNY fix | as J29 | REST | WP | as J29 | world.world_snap | N07 |
| J54 | 06:50 | Overnight policy and news merge since 19:45 (J25, J40, J41, filings), each tagged VERIFIED (official / filing) or UNVERIFIED (media "sources") | news.sqlite | code | PM | - | news.policy_pipeline | N07 |
| J55 | 07:00 | Today's live-blog URLs (ET, Moneycontrol, CNBC-TV18, Business Standard, NDTV Profit) found from their news sitemaps | publisher sitemaps | GET | NR | N (one blog per outlet) | news.sources_today | session news polling |
| J56 | 07:00 | VAHAN second pass (previous day complete) | as J37 | - | TH | as J37 | industry.vahan_mtd | N07 |
| J57 | 07:10 | Freeze + manifest for the 07:15 note | - | code | DK | section 1J rule | score/<d>/manifest_0715.json | N07 |
| - | 07:15 | THE 07:15 NOTE (consumer) | - | - | AN | - | - | - |
| J59 | 07:00-09:15 live | TV morning: CNBC-TV18 "brokerage radar" and stocks to watch (STT); "stocks to watch" articles | TV watcher -> live blogs / Moneycontrol | STT | TV | T (chunk time), C (transcript not repeating, audio level > 0) | rec/tv -> news.items | U08, P09 (broker calls are context, never a reason on their own - H) |

### 1E. 08:00-09:15 - reference data, pre-flight, pre-open

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J61 | 08:00-08:40 every 5 min | Four Kite tokens valid (`GET /user/profile` per key); the trader logs in between ~07:00 and 08:30 | Kite | REST | DK | each key valid; P1 call to the trader if any key is not logged in at 08:40 | health | all |
| J62 | 08:00-08:45 until the file is dated today | Kite instrument dump (NFO, NSE, MCX, CDS, NSEIX, BFO): tokens, strikes, lots, expiries | `api.kite.trade/instruments` -> yesterday's dump + NSE contract file | GET | DK | D (new file; no expiry < today), N (NFO rows within +-5% of yesterday; every F&O underlying present), S, X (vs J63) | rec/instruments/<d>/ (forever) -> ref.instruments | GATE, all |
| J63 | 08:00-08:40 | NSE contract file `NSE_FO_contract_DDMMYYYY.csv.gz` [verify name], `fo_mktlots.csv`, underlying list, holiday master (weekly), FAOP / SURV / CMTR circulars since yesterday (F&O inclusions / exclusions, lot revisions, CA adjustments effective today) | nsearchives / NSE API -> community circular mirror | cGET | DK | D, S, X (lot, expiry, strike list vs Kite - a mismatch blocks that share) | ref.contracts, ref.lots, ref.holidays, ref.fo_universe | GATE (OG), U08 |
| J64 | 08:00 | Corporate actions effective today; symbol / name changes (history adjusted before use - B6.6) | NSE corporate actions JSON, `symbolchange.csv` -> BSE | JSON / cGET | DK | D, N | ref.corp_actions | GATE |
| J65 | 08:30 | Today's risk strip (E1): every event today with IST time, tier, in-session flag, sectors / shares; results today (in / after market); expiry-week flag; ban list; court hits; industry releases due (section 1I) | J28, J31, J30, J17, J63, industry calendar | code | TH | - | events.today | U08, OG, SP (sector entry locks, E5) |
| J66 | 08:30-09:00 | NSDL FPI final for the previous day; RBI money-market operations | fpi.nsdl.co.in Latest; RBI press | GET | DK | D | eod.fpi_nsdl | U08 (context) |
| J67 | 08:40 | Pre-flight (S3.7): 4 tokens, clock offset < 200 ms, disk, services green, instruments refreshed and reconciled, AI budget left, second feed connected, test alert sent and acknowledged | - | code | DK | GREEN / AMBER / RED | health; system bot | U08 |
| J68 | 08:45 | World snapshot W0845 + the 08:45 update inputs (China data, anything changed since 07:15) | as J29 | REST | WP | as J29 | world.world_snap | U08 |
| J69 | 08:45-09:00 every 60 s | Block-deal morning window (prints before the pre-open) | NSE large-deal JSON -> `block.csv` after | JSON | MO | T, N | eod.deals (window = AM) | P09 (a big discounted block is a 09:08 input) |
| J70 | 08:55 | Start all websockets, subscribe the day's lists, set FULL mode, verify per-connection counts; start the second feed | Kite K1-K4; Upstox | websocket | FD | N (subscribed = planned), T (first pre-open ticks by 09:00:10) | ticks | P09 |
| J71 | 09:00 | Commodity re-check at the MCX / CDS open (checklist A: commodities often reverse in Asian hours) - snapshot W0900 | Kite K1 C3 + Sina day session + GIFT | websocket | WP | T, C | world.world_snap | P09, C09 |
| J72 | 09:00-09:08 every 30 s; finals 09:08:30 and 09:12:30 | Pre-open: cash IEP per F&O share (key=FO), current-month futures pre-open (since 8 Dec 2025), buy / sell quantity imbalance | Kite FULL ticks / `/quote` on K1 (shares + futures) -> NSE `/api/market-data-pre-open?key=FO` | websocket + JSON | PO | T (exchange time 09:00-09:08), N (>= 200 shares with an IEP), X (Kite vs NSE IEP +-0.1%) | session/<d>/preopen.parquet | P09, HIST |
| J73 | 09:00 | Self-test (B7): feed live, test alert acknowledged | - | code | DK | - | health | - |
| - | 09:08 | THE 09:08 PRE-OPEN CHECK (consumer) | - | - | PO / AN | - | - | - |

### 1F. 09:15-15:30 - the session (scheduled jobs; the live subscriptions are in section 2)

| ID | Time / freq | Job | Primary -> backup | Method | Own | Validation | Store | Feeds |
|---|---|---|---|---|---|---|---|---|
| J75 | 09:15-15:30 live | The live feed (section 2) | Kite K1-K4 -> Upstox per instrument | websocket | FD | sentinel silence > 3 s -> reconnect; frozen 60 s; X (Kite vs Upstox > 2 ticks or 0.3% for > 5 s) | ticks | C09, SP, OG, HX |
| J76 | every minute (in memory every tick) | Minute aggregates: share / sector / index bars, VWAP, opening range (15 / 30 min), breadth per sector, equal-weight sector, RS vs sector and NIFTY since 09:15, RVOL at time of day, futures OI all months (build-up LB / SB / SC / LU), futures volume vs normal, range used / ATR, room to next level | J75 | code | SE / MO | N (every share updated in the last 2 min), X (GIR sector % vs official sector index +-0.3%) | JSONL -> session/<d>/min.parquet | C09, SP, HX |
| J77 | every minute | Per-strike option metrics: mid, spread %, depth best 5, IV (Black-76 on the same-expiry future, trading minutes, from bid / ask / mid - never LTP), delta / gamma / theta / vega; ATM IV per share | J75 | code | OP | R (IV 5-200%, spread >= 0, bid <= ask), X (vs Upstox greeks continuously, NSE IV on schedule) | JSONL -> opt/<d>/strike_1m.parquet, opt.atm_iv_min | OG, HX, HIST |
| J78 | 09:30, 12:00, 14:30 | Spread and liquidity by strike (E4.4): ATM+-5, spread %, depth quantity, contracts traded so far | J77 | code | OP | N | opt.strike_snap | OG, HIST |
| J79 | 09:30, 12:00, 14:30 for watch-list chains; every 3 min for held underlyings | NSE option-chain cross-check (one symbol per >= 4 s) | NSE option-chain JSON -> Upstox option chain | JSON | OP | T (NSE time <= 3 min old), X (OI within one update; IV +-2 vol points) | raw -> opt.chain_xcheck | OG (trust of GIR's IV), health |
| J80 | every 5 min | Live FutEq MWPL estimate for names >= 70% of MWPL (the exchange snapshots at 4 random times) | Kite futures + options OI x GIR deltas vs J18 MWPL | code | DK | R | ref.mwpl_live | OG (block >= ~85-90%) |
| J81 | 10:00 (MPC days), 10:30 (India PMI 1st-3rd, flash ~20th), 12:00 (WPI ~14th; BoJ presser), 13:00 (IEX DAM results), 13:30 (FBIL USD/INR), 14:30 (LME stocks), China credit (unscheduled 13:30-15:30), auto sales filings (1st) | In-session releases: entry locks around them (E5) and actual vs expected | official pages / RBI YouTube via STT / IEX snapshot / filings -> wires | poll 15 s around the minute | GN / TH | T, S | world.event_actuals, industry.iex_dam | SP (sector lock 10 min before to 15 min after), HX |
| J82 | 14:05-14:20 every 60 s | Afternoon block-deal window | NSE large-deal JSON | JSON | MO | T, N | eod.deals (window = PM) | HX |
| J83 | 09:30, 11:00, 13:00, 14:30 (phase 2) | Independent build-up / PCR lists | Angel SmartAPI REST | REST | MO | X vs GIR's own build-up | health.xcheck | C09 (trust) |
| J84 | every 2-3 min (phase 2, only if Akamai allows the server IP) | NSE live-analysis OI spurts / most active contracts | NSE JSON | JSON | MO | T, E | raw | C09 (second opinion) |
| J85 | every 5 s + postbacks | Positions, orders, fills | Kite K4 REST + order postback | REST / push | DK | T | journal.sqlite | HX, risk bar |

### 1G. Continuous news and filings cadence (by time band)

Push sources (Telegram, phone mirror, TV) are not polled. Every item is stored with `published_at` (as the source states it),
`fetched_at`, `first_seen_at` per source, cluster id, symbols, weight (map_news section 10). Validation for every row: E (error /
captcha / HTML page = ERROR), N (expected rate per hour per source), T (timestamp parse and time zone), dedupe hash. Store:
raw body when changed (rec/raw) -> news.sqlite. Feeds: N19 / N07 at night, SP / HX in session, SC (latency).

| Source | 09:00-15:30 | 15:30-23:00 | 23:00-06:30 | 06:30-09:00 | Own | Phase |
|---|---|---|---|---|---|---|
| J60 NSE corporate announcements JSON (cookie warm-up; RSS fallback) | 3-5 s, offset with BSE so one is hit every ~2 s | 10-15 s | 60 s | 15 s | NR | week 1 |
| J60 BSE announcements API (`AnnSubCategoryGetData` / `AnnGetData`) | 3-5 s | 10-15 s | 60 s | 15 s | NR | week 1 |
| NSE / BSE announcement RSS (fallback) | 60 s | 60 s | 5 min | 60 s | NR | week 1 |
| Attachments (PDF / XBRL) for weight >= 3 items | at once | at once | at once | at once | NR | week 1 (XBRL weeks 2-4) |
| Reuters news sitemap (replaces the dead `feeds.reuters.com` RSS) | 15-20 s | 20 s | 30-60 s | 20 s | NR | week 1 |
| Publisher news sitemaps: ET, Moneycontrol, CNBC-TV18, Business Standard, NDTV Profit | 20-30 s | 30 s | 2 min | 30 s | NR | weeks 2-4 |
| The day's live-blog JSON (J55) | 15-30 s | 60 s until closed | - | 30 s | NR | weeks 2-4 |
| Second-tier RSS (Mint, FE, BusinessLine, BT, Zee Biz) and existing publisher RSS | 60-120 s | 2 min | 10 min | 2 min | NR | week 1 (already exists) |
| SEBI / RBI / PIB RSS (+ MoD) | 60 s | 60 s | 5 min | 2 min | PM | week 1 |
| CBIC, DGTR, DGFT, e-Gazette, CCI, TRAI, CERC, IRDAI pages (diff) | 15 min | 15 min to 01:00 | 60 min | 30 min | PM | weeks 2-4 |
| NSE circulars (FAOP, SURV, CMTR, NCL) | 30 min | 18:00, 21:00 | - | 08:00 | DK | week 1 |
| Business Wire / PR Newswire / SEC EDGAR current feed (ADR names, US partners) | 60 s | 60 s | 60 s (US hours) | 2 min | NR | weeks 2-4 |
| CNBC-TV18 STT (+ CNBC Awaaz phase 2; RBI / PIB / SEBI pressers auto-started via YouTube channel RSS) | live | live to 19:00 | off | from 07:00 | TV | week 1 (exists) |
| Telegram listener (outlet / desk public channels; MTProto, own account) | push | push | push | push | NR | weeks 2-4 |
| Spare-phone push mirror (outlet apps; heartbeat every 60 s, alarm if silent > 3 min in session) | push | push | push | push | NR | weeks 2-4 |
| Google News | backfill every 15 min - OUT of the alert path; used by the 15:45 audit | 30 min | off | 30 min | NR | week 1 (demote) |
| GDELT DOC API (geopolitics: Hormuz, border, sanctions) | 15 min | 15 min | 15 min | 15 min | GN | weeks 2-4 |
| X | OFF (trader's X Pro lists on a screen); API only after credits (spec 8) | | | | NR | month 2+ |

### 1H. Weekends and NSE holidays

| When | Job | Own | Feeds |
|---|---|---|---|
| Sat 02:00 | CFTC Commitments of Traders | WP | context |
| Sat 02:35 | Friday US close snapshot (as J45) | WP | Monday N07 |
| Sat 10:00 | Weekly regulatory watch (S7.10): SEBI / NSE / Zerodha circulars on lots, expiry days, algo rules, MWPL, STT -> rule table | PM | GATE |
| Sat 10:30 | Weekly reliability report (S3.10); weekly source scorecard (promote / demote / drop, map_news section 10) | DK / NR | SC (weekly page B8) |
| Sat 11:00 | Replay test: the week's recorded frames and news through the current code (B7); test-restore of the backup | DK | proof |
| Sat 12:00-Sun | Heavy back-fills: Kite historical top-up, Dhan / Breeze expired-option history (J39), RVOL / ATR rebuild | OP / KB | HIST |
| Sat / Sun all day | News: filings every 60 s (companies file on weekends, e.g. auto sales on a 1st that falls on a weekend; tariff hikes), regulators every 5 min, publisher sitemaps every 5 min, Federal Register / USFDA as on weekdays | NR / PM | Monday N07 |
| Sat-Sun | China data released on weekends (CPI, trade some months); OPEC+ eight-country meeting (usually the first Sunday) | GN | Monday N07 |
| Sun 18:00 | Next week's calendar (ForexFactory) + 4-week calendar build (E1) | GN / TH | Monday N19 / N07 |
| Sun 20:00 | Weekend digest (all news since Friday 15:30, weekend world moves; Bitcoin only as a weekend risk gauge, optional) | GN | Monday N07 |
| Sun 21:00 | Monday's 19:45-equivalent note (the "Sunday note") | AN | Monday |
| First Saturday of the month | Name table refresh (symbol, ISIN, names, brands, parent, old names), sector map refresh (niftyindices constituent CSVs; weekly check), F&O universe review | KB | GATE, news tagging |
| NSE holiday on a weekday | World jobs run; no NSE EOD files expected; the next 07:15 note covers two days of world moves; GIFT may trade (its holidays differ); MCX evening session may open [verify] | all | next N07 |
| Muhurat trading (Diwali) | Special session recorded like any other | FD | HIST |

### 1I. Month, quarter and year events (calendar rows in events.sqlite; each one also sets an entry lock if it is in session)

| When | Event | Collection | Own | Feeds |
|---|---|---|---|---|
| 1st, ~06:00 | ATF, commercial LPG revisions | J49 | TH | N07 |
| 1st, 07:15 / 10:30 | RatingDog China PMI / HSBC India PMI (1st-3rd business days) | J52 / J81 | GN | N07 / SP lock |
| 1st, 09:00-15:00 | Monthly auto sales filings (Bajaj, TVS, Eicher, Ashok, Escorts first; M&M, Hyundai, Tata mid-day; Maruti afternoon [verify by logging]) judged against VAHAN MTD (J37) and media previews; Coal India production; tractors; NMDC | J60 filings + parser + surprise score | NR / TH | N19 (day before), SP, C09 (auto) |
| 1st | GST (GSTN), UPI (NPCI), rail freight, Mumbai registrations | calendar line only | TH | context |
| 1st-7th | IEX, Adani Ports, Angel One monthly filings; e-way bills; PPAC flash; FADA (~5th-8th); NSE active clients; NSDL / CDSL accounts | filings + calendar | TH | SP (the filing names) |
| ~7th-10th | Insurance premiums (IRDAI / Life Council), AMFI flows | calendar + news | TH | SP (insurers, AMCs) |
| ~9th-10th | China CPI / PPI (07:00); MPOB palm (10:00) | J52 / J81 | GN | N07 |
| ~12th 16:00 | India CPI | J10 | GN | N19 |
| ~14th-15th | WPI 12:00 (in session, small); trade data incl. gold imports; NSDL fortnightly sector FPI (and after month end) | J81 / calendar | GN / DK | context |
| ~15th-17th 07:30 | China activity data | J52 | GN | N07, U08 |
| ~20th | PBoC LPR (06:30-06:45); core sector 17:00; India flash PMI (~20th-23rd, 10:30) | J52 / J81 | GN | N07 / SP lock |
| ~28th 16:00 | IIP | J10 | GN | N19 |
| Last days of month | NBS PMI (07:00 on the last day); APM gas price; VAHAN month final -> expected values for the 1st | J52 / J37 | GN / TH | N19, N07 |
| Last Tuesday | Stock F&O monthly expiry (23 Nov (24 Nov is an NSE holiday) 2026, 29 Dec 2026): expiry-week mode from the Wednesday before - K3 C3 adds next-month ATM+-2 for every share, futures tokens roll, physical-settlement warning, "prefer next month" in the option gate, OI read across ALL months | J62 / section 2 | FD / OP | OG, C09 |
| Weekly | Tue: Nifty weekly expiry; Thu: Sensex weekly expiry (heavyweight distortion); Wed: Cabinet (PIB 15:00-17:00); Wed 21:00 EIA; Fri 17:00 RBI forex reserves; Fri SCFI; Thu Drewry WCI; Tue-Wed night FDA warning letters | various | various | N19 / N07 |
| Quarterly | Results season (mid-Jan-mid-Feb, mid-Apr-end-May, mid-Jul-mid-Aug, mid-Oct-mid-Nov): board-meeting calendar daily (J31), consensus captured per result from CNBC-TV18 / ET Now polls and NDTV Profit "vs estimate" lines, XBRL parsed at filing, IV build-up / crush recorded around each result, results-reaction table; quarter-start business updates (1st-10th of Jan / Apr / Jul / Oct); shareholding / pledge (by the 21st); MSCI (Feb / May / Aug / Nov) and FTSE (Mar / Jun / Sep / Dec) reviews - exit rebalance shares by 14:45 on the effective day (E5); GDP 16:00 last working day of Feb / May / Aug / Nov | J31, J60, J77, calendar | KB / NR / OP | OG, N19, SP |
| Bi-monthly | RBI MPC: 10:00 decision, ~12:00 press conference, minutes after 14 days at 17:00 - Tier-1 in session (flat 15 min before to 30 min after) | J81 + RBI YouTube STT + press-release poll 15 s | GN / TV | SP lock, HX |
| Semi-annual | Nifty index reconstitution (announced late Feb / late Aug; effective end-Mar / end-Sep), Sensex (Jun / Dec), lot-size reviews, AMFI categorisation (Jan / Jul); F&O inclusions / exclusions (irregular) | J63 circulars, niftyindices press releases | DK | GATE, HX |
| Yearly | Union Budget 1 Feb 11:00 (Tier-1 in session); Economic Survey; NSE holiday list (December) -> reload; IMD monsoon (mid-April forecast, end-May update, June onset, June-September daily rain - seasonal CORE); Muhurat trading; RBI dividend (May) | calendar + J81 + IMD page | GN / TH | all |
| Clock changes | US DST 14 Mar 2027, Europe 28 Mar 2027 (and back on 1 Nov / 25 Oct): every US / EU-linked job moves one hour; MCX close 23:55 <-> 23:30 | scheduler (0.6) | DK | all |
| Near dates [verify each] | 23 Nov (24 Nov is an NSE holiday) stock expiry (inside the trial week); 26 Nov US Thanksgiving (US closed), 27 Nov US half day; 30 Nov GDP Q2 16:00 and NBS PMI 07:00; 1 Dec (Tue) auto sales, RatingDog PMI 07:15, India PMI 10:30; MSCI November review effective about end-Nov; RBI MPC early December | calendar rows now | TH | N19 / N07 |

### 1J. Freeze points - what each note must read (manifest rule)

At each freeze the data keeper writes a manifest: every input, its as-of time, its check result. A CORE input that is missing or
stale is written in the note as "missing: X since HH:MM" - never guessed (B6.1). The analyst is not called for a note if more
than two CORE inputs are missing; the trader gets a one-line "note delayed: <inputs>" instead.

| Note | Freeze | CORE inputs (missing = named in the note) | Nice to have |
|---|---|---|---|
| 19:45 | 19:40 | W1945 (J29) incl. MCX, CDS close, GIFT session 2, LME official (J23), Sina night (J24); FII / DII (J15); ban T+1 (J17); filings and policy since 15:10 (J60, J25); results tomorrow (J31); tomorrow's calendar (J28); US data if out (J27) | bhavcopies (J13, J16) - often still landing; MWPL (J18); deals (J14); court hits (J30); participant OI (J20) |
| 07:15 | 07:10 | W0700 (J53): US close, ADRs, SOX, US 10y, DXY, USD/INR (INR=X), Brent, gold, silver, MCX close, LME, Sina day session, Nikkei, Kospi, GIFT; settlements (J44); overnight policy merge (J54); today's calendar (J28); ban re-check | FDA (J40), Federal Register (J41), CNY fix (J51), VAHAN (J56), China data if out (J52), TV radar (J59) |
| 08:45 | 08:42 | Pre-flight (J67), instruments + reconciliation (J62, J63, J35), risk strip (J65), W0845 (J68), China 07:00-07:30 data | NSDL FPI (J66), block window start (J69) |
| 09:08 | 09:08:30 | Pre-open series (J72), W0900 commodity re-check (J71), watch list from 07:15 | morning block deals (J69) |
| 09:20+ | live | section 2 live data, all fresh by S3 limits | - |
| 15:45 | 15:44 | J05, J06, J07, the analyst's call log (#46), AI spend (#47) | - |

---------------------------------------------------------------------------------------------------------------------------------

## 2. LIVE SESSION SUBSCRIPTIONS

### 2.1 Universe sizes (from the day's instrument dump - never typed in)
F&O shares ~213-220 (written below as 218); stock futures 3 months x 218 = 654; index futures NIFTY / BANKNIFTY / FINNIFTY /
MIDCPNIFTY x 3 months = 12; NSE indices (broad + all sectoral + thematic) ~100-130 [verify count] + INDIA VIX; MCX ~40 contracts
(near + next month of GOLD, GOLDM, SILVER, SILVERM, CRUDEOIL, CRUDEOILM, NATURALGAS, NATGASMINI, COPPER, ALUMINIUM, ZINC, LEAD,
NICKEL and minis) + MCX indices [verify]; CDS ~14 (USDINR, EURINR, GBPINR, JPYINR, EURUSD, GBPUSD, USDJPY, near + next);
NSEIX GIFT NIFTY (+ GIFT Bank / IT / Fin Services if Kite exposes them [verify]).

### 2.2 The four Kite keys (3 connections x up to 3,000 tokens each; keep every connection under ~2,500 for headroom)

**Every token in FULL mode** (Kite's quote mode carries no OI, no bid / ask and no exchange timestamp - the option gate would be
blind; this is the correction already written into S2 / S9).

| Key | Connection 1 | Connection 2 | Connection 3 | Tokens |
|---|---|---|---|---|
| **K1 underlyings + drivers** | 218 F&O shares (EQ) | stock futures current + next + far month (654) + 12 index futures | all NSE indices + INDIA VIX (index packets) + MCX (~40) + MCX indices + CDS (~14) + NSEIX GIFT NIFTY (~200 tokens) | ~1,100 |
| **K2 options in play** (FULL with depth) | watch-list shares (up to 50, from 19:45 / 07:15 / 09:08): ATM+-5 CE + PE current expiry (1,100) + next expiry ATM+-2 (500) | open positions' strikes + ATM+-10 of held underlyings + "next candidates" from confirmed sectors not in the watch list, ATM+-3 (<= 700) | mirror sentinels: 3 tokens from each of the other 8 Kite connections (24) + held strikes again (<= 50) | <= 2,350 |
| **K3 full chains** | ATM+-5 current expiry, CE + PE, for shares 1-109 (alphabetical) = ~2,400 | same for shares 110-218 = ~2,400 | normal weeks: ATM+-6..+-8 for the 60 most liquid shares (720) + next-month ATM+-2 for those 60 (600); expiry week (from the Wednesday before the last Tuesday): next-month ATM+-2 for ALL shares (~2,180) instead; plus a re-centring buffer (~200) | ~6,100-7,000 |
| **K4 hot standby + REST** | empty - takes over any stalled connection's whole list in < 5 s | sentinels: 2-3 liquid tokens per Kite connection on K1-K3 (~27), compared on exchange timestamp | empty - second standby | ~27 (up to 3,000 on takeover) |

Rules for every connection:
1. The callback only enqueues the raw frame with its receive time; decoding, aggregation and recording run elsewhere (S2).
2. After EVERY reconnect: resubscribe the connection's list AND set FULL mode again; log both; back-off 1-2-4-8 s with jitter, cap
   30 s. If a connection has not recovered 10 s after one reconnect, K4 C1 takes its list.
3. Stall detection: any sentinel on a connection silent > 3 s in 09:15-15:30 -> reconnect that connection (pre-open 09:00-09:08:
   shares and futures only). Frozen check: price and volume unchanged 60 s on a liquid token -> stale.
4. Re-centre strikes when spot moves half a strike interval from the centre: subscribe the new strikes first, set FULL, unsubscribe
   the old ones after the first tick; at most one re-centre per share per 2 min.
5. Token lists are rebuilt every morning from J62; an "invalid token" error is a P2 alert and the token is dropped.
6. Same token on two keys (sentinels, held strikes) must agree on exchange_timestamp within 2 s; otherwise the older one is stale.
7. Kite sends snapshots (~1 per instrument per second when something changed), not every trade; a quiet far strike sending
   nothing for minutes can be normal - liquidity, not staleness, decides (only sentinels and liquid tokens judge a connection).
8. Terms: several apps on one account are reported as allowed (Zerodha staff reply) - confirm with a support ticket before relying
   on four keys [verify]; if any use is not allowed, drop to what is allowed and move K3's far strikes to the REST sweep.

### 2.3 REST sweeps (per key; Kite limits about 1 req/s for quote endpoints, 3 req/s historical, 10 req/s others [verify])

| Key | Sweep | Rate | Purpose |
|---|---|---|---|
| K1 | `/quote/ohlc` for all shares + futures + indices (<= 1,000 per call) | every 10 s | frozen-value detection; second path for underlyings |
| K1 | `/quote` FULL for 218 shares + 218 current futures | 09:07:45 and 09:08:30 | pre-open IEP cross-check (J72) |
| K2 | `/quote` FULL on held strikes + their underlying | every 5 s | second path for the position (stop / target decisions) |
| K3 | `/quote` chain OI sweep, 500 tokens per call (~13 calls for ~6,500 chain tokens) | every 2 min (13 s of budget) | OI second path (#15); dead-token finder for chains |
| K4 | `/quote/ltp` rotating sweep of every subscribed token (1,000 per call) | ~10 s per full pass | compare last_trade_time with the websocket's last tick: silently dead tokens (the ANGELONE-stuck-at-11:00 case) |
| K4 | `/portfolio/positions`, `/orders` (+ postback push) | every 5 s | positions, fills (#44) |
| K4 | historical API | 3 req/s, mainly after 15:35 and at night | candle reconciliation (J03), back-fill, RVOL / ATR (J38) |
| K4 | `/charges/orders`, `/margins/basket` | per planned order | full trade cost (#26), cash check (S7.5) |
| K4 | `/user/profile` for all four keys | 08:00-08:40 every 5 min | token check (J61) |

### 2.4 MCX / currency / GIFT drivers (K1 C3) - why they matter
They turn checklist A's drivers into live ticks from 09:00 (MCX to 23:55, CDS to 17:00, GIFT nearly round the clock) from a feed
GIR already pays for. They make possible: the 09:00 commodity re-check, the S8 #8 "intraday commodity lag" pattern (MCX move > 1.5%
not yet followed by the linked shares), the E5 shock rules (USD/INR +-0.5% -> freeze new entries 15 min), and a live dollar proxy
(CDS EURUSD / USDJPY / GBPUSD) in session. Labels are honest: MCX CRUDEOIL tracks WTI, not Brent; MCX metals track LME 3-month x
USD/INR (thin before London opens at 13:30); MCX gold includes the rupee and import duty.

### 2.5 The independent second feed (always on)
**Upstox V3 market-data feed on the 1-year read-only Analytics Token** (no daily login, free with an account in the trader's name).
One websocket, mixed modes (caps about 2,000 ltpc / 2,000 greeks / 1,500 full when mixed [verify]):
- `ltpc`: 218 shares + 218 current-month futures + NIFTY / BANKNIFTY futures + ~20 sector indices (~460);
- `option_greeks`: watch-list ATM+-2 current expiry (~500) - Upstox's IV / greeks against GIR's Black-76;
- `full`: held strikes, their underlyings and the sentinels (<= 30);
- REST option chain (with OI, IV, greeks) for watch-list underlyings every 3 min, staggered one call per ~4 s; held underlying every
  minute.
Failover is per instrument: if Kite's last tick for a liquid token is > 3 s older than Upstox's in market hours, mark the Kite
value stale, show the Upstox value with source = U, and trigger the K4 takeover; flag any disagreement > 2 ticks or 0.3% lasting
> 5 s. Track the Analytics Token's expiry and alert 14 days before. If Upstox is not available: Angel SmartAPI or Shoonya (free,
daily login) as feed B; TrueData / GDFL (paid) only through the trigger in section 7.

### 2.6 NSE option-chain cross-check (J79)
NSE's `option-chain-equities?symbol=X` JSON (or its 2025 replacement path [verify]) is the official check of OI and IV per strike:
watch-list chains at 09:30 / 12:00 / 14:30, held underlyings every 3 min, never more than one symbol per 4 s, cookie warm-up,
stop on 403 / 429. Compare: OI within one NSE update of Kite's; NSE IV vs GIR IV within 2 vol points (a wider gap = check GIR's
future price, time to expiry in trading minutes and mid quotes). If Akamai blocks the server's IP, the Upstox chain is the
cross-check and the block is logged (never evaded).

### 2.7 Expected message rates and storage (estimates - measure on day 1; the 16:30 report then holds the real baseline)

| Connection | Tokens | Packets / s 09:15-10:00 | Packets / s midday | Bytes / s peak |
|---|---|---|---|---|
| K1 C1 shares | 218 | ~200 | ~120 | ~37 KB |
| K1 C2 futures | 666 | ~350 | ~150 | ~65 KB |
| K1 C3 indices + MCX + CDS + GIFT | ~200 | ~150 | ~120 | ~25 KB |
| K2 C1 watch-list strikes | ~1,600 | ~700 | ~300 | ~130 KB |
| K2 C2 positions + candidates | <= 700 | ~300 | ~150 | ~55 KB |
| K2 C3 sentinels | <= 50 | ~40 | ~30 | ~7 KB |
| K3 C1 / C2 chains | ~2,400 each | ~700 each | ~300 each | ~130 KB each |
| K3 C3 extra strikes / next month | 1,300-2,200 | ~300 | ~120 | ~55 KB |
| K4 C2 sentinels | ~27 | ~25 | ~20 | ~5 KB |
| Upstox (protobuf) | ~1,000 | ~500 | ~250 | ~50 KB |
| **Total** | **~10,000 Kite + ~1,000 Upstox** | **~4,000 / s** | **~1,800 / s** | **~0.7 MB/s (S2 budget: 1 MB/s)** |

REST: ~1.5 req/s across keys in session (K4's 1 req/s LTP sweep is the biggest). Recording: ~7-8 GB of raw frames per day,
~1.5-2 GB after zstd, ~40 GB a month -> 90 days on the server, older archived off-server. Decoder target: < 5 ms per frame batch;
page gateway pushes only changed fields 4-10 times a second (S2).

### 2.8 What is computed from the feed and recorded (in memory every tick, written per minute)
Share VWAP, opening range, RS vs sector and NIFTY since 09:15, RVOL at time of day (#18-#20); sector %, breadth, equal-weight vs
index, sector VWAP (#10, #11); futures build-up across all months and futures volume vs normal (#13, #14); option mid, spread %,
depth, IV and greeks (#16, #23); ATM IV per share (#24); range used / ATR, room to next level (#21, #22, OI walls from #15);
the S6 order-flow signals (recorded, not trusted until tested on 60+ days).

---------------------------------------------------------------------------------------------------------------------------------

## 3. THE SHARE-SELECTION FUNNEL (a normal day, in order)

Each question uses only data that existed at that moment (checklist I). Item numbers are GIR_SPEC's DATA LIST; J-numbers are
the jobs above.

| # | Question | When | Data that answers it | Rule that decides | Output |
|---|---|---|---|---|---|
| Q0 | May we trade today, and what is allowed? | 19:45 / 08:45 | #1-#5 (J62-J64), ban + MWPL #3 (J17, J18, J80), events #37, #41 (J28, J31, J65), health #48 (J67, J35) | B6.4 mismatch blocks a share; RED = read-only session; E5 locks (RBI, Budget, results, counting day); IV-crush filter list (S8) | allowed universe, locked windows, shares blocked with the reason |
| Q1 | Which drivers moved? | 19:45, 07:15, 08:45, 09:00 | #32-#35: W1945 / W0700 / W0845 / W0900 snapshots (J29, J53, J68, J71): Brent, MCX crude, LME (J23) + MCX copper / aluminium / zinc, silver, Dalian iron ore + SHFE steel (J24, J50), COMEX / MCX gold, Nasdaq, SOX, ADRs, US 10y / 2y, India 10y, USD/INR, DXY, CNY fix, GIFT (J08 / J47); event actuals with surprise scores (J10, J27, J52) | checklist A thresholds (Brent +-2%, copper / aluminium +-2%, zinc 1.5%, silver 3%, iron ore +-3%, gold +-1.5%, Nasdaq +-1.5%, ADR +-2%, India 10y +-10 bp, USD/INR +-0.3%, DXY +-0.5%, GIFT +-0.5%); each move stated "vs <named reference>, as of <time>", two witnesses agree within 0.5% | list of drivers past threshold, with direction and strength |
| Q2 | Which sectors will move, and which F&O shares are in them? | 19:45, 07:15, 08:45 | sector map #6 (driver -> sector -> every F&O share), filings and news #36, #38-#40 (J60, J25, J54, TV), policy pipeline (E3), results / industry calendar #37 (J31, section 1I), zone / room from derived history #21, #22 (J38), delivery / deals / FII context #28, #30, #31 | spec 1.7: every driver -> its sectors -> EVERY F&O share in them, zone (overbought / oversold / neutral), speed, room, likely gap; laggard candidates named | watch list: sectors with direction; all their F&O shares with zone and room; K2 C1 subscription list for the morning |
| Q3 | Does the pre-open agree? | 09:00-09:08 | #17 cash IEP + futures pre-open + imbalance (J72), block AM window (J69), GIFT and commodities at 09:00 (J71) | each watch-list share's gap % and pre-open volume vs the night's view; a met trigger becomes GO NOW at the open (1.8) | ready plans; shares gapping against the view flagged |
| Q4 | Is the sector confirmed? | from 09:20 (never before), to ~10:00 | #10 sector index + GIR sector %, #11 breadth, #12 NIFTY / VIX, #13 futures OI ALL months, sector VWAP, gap still there at 09:45 (J76); NSE OI spurts / Angel build-up as second opinions (J83, J84) | checklist C: RS vs NIFTY; breadth >= 70% with median move > 1%; equal-weight vs index (heavyweight trap); build-up in several shares across all months; sector index on the right side of its VWAP | "SECTOR UP / DOWN - confirmed since HH:MM · driver · news · build-up" |
| Q5 | Which shares inside it? | 09:20-14:30 | #19 RS vs sector since 09:15, #20 RVOL, #8 / #9 VWAP and opening range (#18), #21 range used / ATR14, #22 levels + OI walls from #15, #13 / #14 futures build-up and futures volume vs normal, #36 own news with timestamp and size vs revenue | checklist D1-D8 (CE only above VWAP and the OR, PE only below; range used < 0.6 ATR = room, > 1.2 = skip; room >= 0.3 ATR; RVOL > 1.5 valid, > 2.5 strong; laggard only with breadth 70%+, before 13:00); morning score weights from I | every share in position, ranked, one line each (spec 1.5) |
| Q6 | Which strike, and is the option tradable? | before every call | #15 OI by strike, #16 bid / ask / spread % / depth (FULL mode), #23 IV and greeks (J77), #24 IV rank (J38, seeded by J39), #2 expiry and days left, #3 ban / MWPL (incl. live estimate J80), #37 results / event within one session, #25 break-even vs expected move, #26 exact costs (Kite `/charges/orders`); trust from J79 cross-check | checklist E (spread <= 1-2%, ~500+ contracts before 10:00, delta 0.45-0.6, IV rank < ~50, not near ban, last 5-7 sessions -> next month) + S8 IV-crush filter + B1.7 + B2 break-even rule | GO NOW / GET READY with strike, premium, stop and target on premium and share, max loss, R:R |
| Q7 | Hold, book half or exit? | in the trade | #8 / #9 share vs VWAP and 5-min swings, sector RS, #16 / #23 premium vs what delta explains, OI wall changes #15, time since entry; #48 data age (stale with a position open = critical alert) | checklist G: valid while share and sector hold their VWAP side; book half ~+1R; trail; time stop 45-60 min; hard exit 15:10 | HOLD / BOOK HALF / EXIT |
| Q8 | Did we name the right shares in time? | 15:45 | movers list (J05), the analyst's calls (#46), news latency (J06), agents' lines and AI spend (J07, #47) | trial scorecard: named before / late / missed, the reason and the agent that failed | scorecard on the page + decisions channel |

**The proof case (18 Nov), replayed through this funnel.** Q1 at 19:45 on 17 Nov: MCX copper and LME official (J23 / J29) down
at a multi-month low, MCX / COMEX gold down, silver down, Nasdaq / SOX weak, DXY strong - all past their thresholds, with two
witnesses (today GIR read only COMEX HG=F and the illiquid ALI=F, see 6.2-c). Q2: metals -> HINDALCO, NATIONALUM, VEDL,
HINDCOPPER, SAIL; copper -> cables & wires POLYCAB, KEI (copper at a 5-month low); gold -> jewellers and gold lenders TITAN,
KALYANKJIL, MUTHOOTFIN, MANAPPURAM; PE watch list on K2 C1 by 07:15. Q3 09:08: pre-open gaps (J72) on that list. Q4 09:20:
breadth and equal-weight of the jewellers / gold-loan group and cables group negative with short build-up across months (J76).
Q5: ranked inside each group (KALYANKJIL as the laggard only under D8's conditions). Q6: spreads, IV rank, ban status from the
FULL-mode chain. The data to call these at about 09:20 is all in jobs J08, J09, J23, J24, J29, J53, J71, J72, J75-J77 -
every one of them free.

---------------------------------------------------------------------------------------------------------------------------------

## 4. RECORD FROM TODAY (no free history exists - every day not recorded is lost)

| # | Data | Why there is no free history | Job | How often | Stored in |
|---|---|---|---|---|---|
| R1 | ATM IV per share (CE / PE / straddle mid IV), plus the daily close value (median 15:00-15:25) | Kite gives no IV; vendors give only ATM-relative history (Dhan seeds the past, J39) | J77, J38 | every minute; daily value | opt.atm_iv_min, atm_iv_daily |
| R2 | Per-strike IV, spread %, depth, contracts traded (all subscribed strikes) and the E4.4 snapshots at 09:30 / 12:00 / 14:30 | spread and depth history are sold by nobody at retail | J77, J78 | minute + 3 snapshots | opt/<d>/strike_1m.parquet, opt.strike_snap |
| R3 | Raw websocket frames (every key) and Upstox frames | Kite has no tick history and no expired-contract history | J75, J02 | every frame | rec/ticks |
| R4 | Kite instrument dump and NSE contract file every day | expired tokens vanish from Kite; without them recorded ticks cannot be decoded later | J62, J63 | daily | rec/instruments (forever) |
| R5 | Pre-open series: cash IEP, futures pre-open (new since Dec 2025), buy / sell quantities, every 30 s 09:00-09:08 + finals | NSE shows only the current day | J72 | 30 s | session/<d>/preopen.parquet |
| R6 | GIFT Nifty minute series (both sessions) | Kite gives LTP only; free sites keep daily bars at best | J08, J47 | every tick / minute | world.gift_1m |
| R7 | World snapshots W1945 / W0245 / W0700 / W0845 / W0900 with named references, plus the 5-min overnight series | the "as known at 19:45" state is what the notes are judged on (checklist I) | J29, J34, J45, J53, J68, J71 | per snapshot / 5 min | world.world_snap, world_series_5m |
| R8 | MCX, CDS and China (Sina) minute series day and night | free sites keep EOD only | J09, J24, J50 | minute | world.mcx_1m, cds_1m, china_fut_1m |
| R9 | Futures OI ALL months, per share, per minute | Kite gives OI for live contracts only; NSE gives EOD only | J76 | minute | session/<d>/min.parquet |
| R10 | Per-source news delay: published_at, first_seen_at per source, cluster t0, t_move, before-move | nobody publishes it; it decides which sources live, die or get paid for | J60, J06 | every item | news.source_seen, latency_daily |
| R11 | Every news item and filing with its first-seen time (and the analyst's verdict) | needed to replay any day exactly (B7) | J60 + all news jobs | every item | news.items |
| R12 | Economic consensus as published the night before, actuals at release, surprise score | consensus revisions are not kept by free calendars | J28, J10, J27, J52 | per event | world.calendar, event_actuals |
| R13 | Results consensus per company (CNBC-TV18 / ET Now poll, NDTV Profit "vs estimate"), actual, reaction (gap, day-1 range, day-2 drift), IV before / after | no free Indian consensus API | J60 + KB parse | per result | events.results_cal, derived |
| R14 | Board-meeting announced time vs actual filing time (results in / after market) | not kept anywhere | J31, J60 | per filing | events.results_cal |
| R15 | VAHAN month-to-date by maker / fuel / class | the dashboard shows the current month; no easy history | J37, J56 | nightly + 07:00 | industry.vahan_mtd |
| R16 | MoCA daily domestic traffic (flights, passengers) | no download of history | daily job (TH, weeks 2-4) | daily | industry.moca_daily |
| R17 | Grid-India PSP (peak demand, energy, shortage) and CEA daily coal stock (critical plants count) | PDFs only, scattered | daily job (TH, weeks 2-4) | daily | industry.grid_psp, cea_coal |
| R18 | IEX DAM results (MCP, cleared volume) and month-to-date volume | web tables, no history download | J81 | daily ~13:00 | industry.iex_dam |
| R19 | Live MWPL FutEq estimate and the EOD MWPL / ban files | the 4-random-snapshot rule (Nov 2025) makes intraday history matter | J80, J18, J17 | 5 min / daily | ref.mwpl_live, mwpl, ban |
| R20 | NSE option chain snapshots (NSE's own IV) and Upstox greeks | lets GIR prove its IV calculation over time | J79, 2.5 | 3 snapshots + 3 min | opt.chain_xcheck |
| R21 | Block-deal windows (AM / PM) prints with time | the window board is live-only | J69, J82 | 60 s | eod.deals |
| R22 | Kite vs NSE mismatches and every health incident | needed for the weekly reliability report and "never again" checks | J35, heartbeat | per event | health.sqlite |
| R23 | TV transcript snippets with chunk times | needed to measure TV-first stories | J59, TV | live | rec/tv |
| R24 | FedWatch probabilities and US 2y at 19:45 / 07:15 | not kept free | J29, J53 | twice a day | world.world_snap |
| R25 | Every AI call: inputs, decision, model, tokens (incl. cache), cost, latency, validator result, outcome | GIR-only by definition | S4.9 | every call | ai.sqlite |

---------------------------------------------------------------------------------------------------------------------------------

## 5. FAILURE PLAYBOOK

Alert levels (S3.5): **P1** blocks trading - system bot + phone call, repeat every 5 min until acknowledged, escalate after 15
min; **P2** system bot message; **P3** daily digest. Alerts on state change only, always followed by "recovered". System alerts
on a separate bot from trading alerts. **Safe mode** = one global flag: affected values grey "STALE since HH:MM", no new calls go
out; positions keep their stops (exits are never blocked).

| Source | Detected by | GIR does | Degrade / backup | Safe mode | Alert |
|---|---|---|---|---|---|
| One Kite websocket connection stalls | sentinel silent > 3 s in session; frozen 60 s; K4 LTP sweep shows newer last_trade_time than the socket | reconnect + resubscribe + set FULL; if not back in 10 s, K4 C1 takes the list | per-instrument values from Upstox (source = U) meanwhile | only for shares whose underlying AND chain are both stale | P2; P1 if a held position's instrument is stale > 30 s |
| A whole Kite key fails (token invalid / logged out) | `/user/profile` error; "Incorrect access_token" in logs (the RAVEN-blind case) | move that key's three lists to K4 (and spare capacity on other keys: drop K3 C3 extras first) | Upstox for underlyings and held strikes | if the lost key was K1 (underlyings): safe mode for new calls | P1 to the trader (re-login) |
| All Kite down (Zerodha incident) | all sentinels silent; Kite status / API errors | no new calls | Upstox feed for positions and the decision display; trader trades from the broker app (S3 runbook) | YES | P1 |
| Kite REST rate limits / errors | 429 / 5xx counters | back-off; skip the sweep round; never retry in a tight loop | websocket values stand; K4 sweeps slow down | no | P3 (P2 if > 10 min) |
| Instrument dump missing, late or odd (count -5%, expiries in the past) | J62 checks | keep yesterday's list for underlyings; block options whose expiry or lot cannot be confirmed | NSE contract file + lot file (J63) as the reference; mismatch blocks that share | partial (affected shares) | P1 at 08:40 if not resolved |
| NSE EOD file missing / late / renamed (bhavcopy, ban list, MWPL) | D / N / S checks; deadline in the timetable; daily diff of NSE's daily-reports index for new / vanished names | retry every 10 min to 21:00, then at 07:00; never assume "no ban" | ban: previous day's list + MWPL near-ban rule + manual check of a public ban list by the trader; bhavcopy: Kite closes (J01) labelled UNOFFICIAL | if the ban list for T+1 is still missing at 08:45: block NEW calls on every share that was >= 80% MWPL yesterday (not the whole session) | P1 at 08:45 for the ban list; P2 otherwise |
| NSE JSON blocked by Akamai (announcements, pre-open, option chain) | 403 / 401 bursts, HTML instead of JSON (E) | stop, cool down 10-30 min, refresh cookies once; never rotate IPs to evade | announcements: BSE API + NSE RSS; pre-open: Kite quotes; option chain: Upstox chain | no | P2; P1 if both NSE and BSE filings are silent > 10 min in session |
| BSE announcements API down | E / N checks | back-off | NSE JSON + both RSS | no | P2 |
| Filing feed "quiet" (zero items 10 min at 11:00) | expected-rate watch (N) | treat as broken, not quiet: run the RSS fallback and a manual test fetch | RSS | no | P2 |
| GIFT Nifty (Kite NSEIX) | T / C on J08 | switch to NSE IX page (J47) | Moneycontrol / Investing GIFT page (manual); INDA as an overnight cross-check | no (the note says "GIFT from NSE IX page, as of") | P3 (P2 at 07:10 if no source) |
| MCX / CDS drivers | T / C on K1 C3 | reconnect as any connection | Yahoo COMEX / NYMEX (delayed 10 min - never an in-session trigger), INR=X | in-session commodity-lag signals off | P2 |
| Yahoo (world overnight) | 429, empty `result`, stale `regularMarketTime`, roll jump (K) | query1 -> query2 -> back-off | Stooq CSV, CNBC quote service; MCX / CDS when open; the note names the source used | no | P2 at 19:40 / 07:10 if a CORE driver has no source |
| Sina / AKShare (China) | E / T; session calendar | back-off | Eastmoney API; DCE / SHFE official EOD; Investing (manual) | no | P3 |
| LME (Westmetall) | T (LME date) | retry 21:00 | lme.com next-day; MCX copper / aluminium as the live proxy, labelled | no | P3 |
| ForexFactory calendar | "Request Denied" page, S | wait 5 min (respect the limit) | Nasdaq.com calendar JSON [verify]; official calendars for times; Investing (manual) | no | P2 if no calendar by 19:40 |
| Upstox second feed | T / C; token expiry date | reconnect | Angel SmartAPI / Shoonya; without a second feed the session runs Kite-only with sentinels | no (but "single feed" shown in the health report) | P2 |
| Publisher sitemaps / Reuters sitemap / live blogs | E / N (403, schema change, no new items for an unusual time) | back-off; drop to RSS | section RSS; Telegram / phone pushes | no | P3 (P2 if Reuters + 3 publishers fail together) |
| Regulator RSS (SEBI / RBI / PIB) | E / N; known evening release rates | page diff of the "what's new" page | wires + trader's X Pro lists | no | P2 in 17:00-23:00 |
| TV watcher (STT) | C (repeating transcript, audio level 0, chunk times stalled) | restart the capture | live blogs (same desk's web copy, +1-10 min) | no | P2 in session |
| Phone mirror / Telegram listener | heartbeat missing > 3 min | restart / check phone | polled sources | no | P2 |
| Clock / server | chrony offset > 200 ms; disk < 15%; memory; certificate | fix / restart; systemd watchdog pinged from inside each loop; OnFailure alert | runbook: trade from the broker app; rebuild from the tested snapshot | YES if the server is unhealthy | P1 |
| AI provider | timeouts, errors | panel "AI unavailable"; code rules and the small model keep running (S4 ladder) | lower tier | no (calls from code rules continue) | P2 |
| Alert channel (Telegram) | test alert not acknowledged at 09:00; send errors | retry; second channel when built | page alert | no | P1 at 09:00 |
| Recording (disk full, writer thread behind) | queue length, write lag | drop to recording underlyings + held strikes only; never block the live path | - | no | P2 |

---------------------------------------------------------------------------------------------------------------------------------

## 6. GAPS AND FIXES (from the five maps, de-duplicated, ranked by value for picking the right shares)

Effort: S = under a day, M = 2-5 days, L = 1-3 weeks. "Trial" = can run during the trial week with NO page change (back-end
data that reaches the trader only through the notes / decisions channel / health bot).

### 6.1 Ranked gaps

| Rank | Gap (maps that found it) | Fix | Why it picks better shares | Cost | Effort | Trial |
|---|---|---|---|---|---|---|
| 1 | Drivers not live: MCX and CDS not subscribed although paid; GIFT only a one-shot LTP (global) | K1 C3 subscriptions + GIFT / MCX / CDS minute series (J08, J09, J71) | the 18 Nov drivers (copper, gold, silver, dollar) become live, two-witnessed numbers for 19:45, 07:15 and 09:00; S8 #8 and E5 shock rules can fire | free | S | YES |
| 2 | Metals / steel drivers read from the wrong instruments: no LME, SHFE, Dalian, SGX; COMEX HG=F and the illiquid ALI=F used as "copper / aluminium" (global) | MCX metals live + LME official and stocks (Westmetall, J23) + Sina / AKShare day and night (J24, J50); HG=F only a witness; drop ALI=F | metals, steel and cables are the most world-driven F&O sectors and the 18 Nov miss | free | S-M | YES |
| 3 | Option chain blind in quote mode; no IV / greeks feed; no IV history (brokers, spec) | FULL mode on every strike (already in the spec - verify the live code sets it after every reconnect), Black-76 per strike (J77), ATM IV recorded daily (R1), spreads by strike (R2) | the option gate (spread, depth, IV rank, IV crush) can only work on FULL-mode data | free | M | YES (recording); gate use when tested |
| 4 | Filings ~3 min late, unclassified, no XBRL (exchanges, news) | NSE + BSE JSON every 3-5 s with earliest-wins dedupe; category classifier (order win, clarification / denial, USFDA, tax demand, OFS / QIP, rating); XBRL numbers (J60) | the fastest share-specific news; filings from ~3 min to ~10 s | free | M | YES (polling + classifier); XBRL weeks 2-4 |
| 5 | No event / economic calendar with consensus, actual and surprise; hand-edited `econ_events.json`; no industry / results calendar per share (global, exchanges, alternative) | J28 + J10 / J27 / J52 actuals + surprise score; results calendar J31; industry calendar (section 1I); risk strip J65 | E1 / E2 / E5 rules (event locks, never buy into an event, trade the surprise) and the 19:45 "due tomorrow" lines | free | M | YES (calendar into the notes) |
| 6 | Pre-open and pre-market tape not recorded: GIFT series, cash IEP, the new futures pre-open, the 08:45 block window (exchanges) | J72, J69, J47, R5, R6 | the 09:08 gap check needs both a series and history to judge "unusual" | free | S | YES |
| 7 | Dead and slow wire path: `feeds.reuters.com` (dead since 2020) still in `gir/gir.py`, Nitter in archive code; no sitemaps or live-blog JSON; Google News in the alert path (news) | Reuters news sitemap 15-20 s; publisher sitemaps + live blogs; RSS as fallback; Google News to backfill | wire / publisher news from ~7.5 min towards < 1-2 min | free | S (Reuters, drops) / M (sitemaps, blogs) | YES (Reuters + drops); sitemaps weeks 2-4 |
| 8 | Ban / MWPL under the 2025 FutEq rules and the Nov 2025 random-snapshot surveillance (exchanges) | EOD combineoi (J18) + ban T+1 (J17) + live FutEq estimate (J80) + near-ban forecast | a hard gate - a ban share cannot be bought; near-ban shares get stuck | free | S (files) / M (estimate) | YES (files); estimate weeks 2-4 |
| 9 | No per-source latency record and no miss audit (news) | R10 + J06 + weekly promote / demote | proves which sources earn their place; the only honest trigger for any paid wire | free | M | YES |
| 10 | Stale checks judge age by file time (code) | heartbeat with two clocks (0.3) + aggregate age = oldest input | stops calls on data that looks fresh but is not (B6.1) | free | S | YES (health side; page dot later) |
| 11 | Evening policy / docket pipeline not one structured, symbol-tagged feed (exchanges, news) | J25, J30, J40, J41, J54 into news.policy_pipeline with PENDING -> ANNOUNCED -> NOTIFIED | most next-morning sector moves start between 17:00 and 23:00 (E6) | free | M | SEBI / RBI / PIB RSS YES; scrapers weeks 2-4 |
| 12 | Single-broker live feed (brokers) | Upstox Analytics Token feed (2.5) with per-instrument failover | one Zerodha incident no longer blinds GIR; live IV cross-check | free | M | weeks 2-4 (new account; no page change needed) |
| 13 | No USFDA watcher, no pharma filing classifier (alternative, news) | J40 + USFDA terms in the filing classifier + plant -> US revenue table | pharma's biggest single-share moves (-3% to -10%) | free | M | weeks 2-4 |
| 14 | Orders not scaled by company size; defence / rail / power approvals not tracked (alternative) | order value / trailing revenue + "new vs routine"; PIB MoD / DAC releases | separates a 3-6% order from noise (checklist D7) | free | S-M | weeks 2-4 |
| 15 | No expired-option history -> IV rank, results reaction, back-tests wait months (brokers) | Dhan expired-options (Rs 499 / month) + Breeze spot checks (J39) | IV rank and the IV-crush filter from week 2 instead of month 3 | Rs 499 / month | M | weeks 2-4 (night jobs) |
| 16 | Rates / FX depth missing: US 2y, India 10y, FedWatch, CNY fixing / CNH, JPY, NDF proxy (global) | CNBC US2Y, CCIL / Investing India 10y, FedWatch light fetch, CFETS fix, Yahoo CNH / JPY, CDS USDJPY | banks / NBFC / realty / IT / rupee calls (checklist A rows) | free | S | YES |
| 17 | Industry daily series with no history (VAHAN, MoCA, Grid-India, IEX, CEA coal) (alternative) | recorders R15-R18 | the expectation half of the 1st-of-month auto-sales surprise (1 Dec is next) | free | S-M | YES (VAHAN first) |
| 18 | Only one TV channel, no Hindi, no ticker OCR, no auto-STT for RBI / PIB / SEBI pressers (news) | CNBC Awaaz STT, YouTube channel RSS to auto-start pressers, ticker-band OCR later | TV is where "sources" scoops land first | Rs 0 (local whisper) to ~Rs 2-8k / month | M | weeks 2-4 |
| 19 | No push sources (Telegram, phone notifications) (news) | Telegram listener + spare-phone mirror | removes the poll interval and CDN cache from the delay | ~Rs 300 / month (SIM) | S-M | weeks 2-4 |
| 20 | No results consensus capture (brokers, news) | store CNBC-TV18 / ET Now poll figures and NDTV Profit "vs estimate" lines per result (R13) | results-day surprise and the "habitually misses" tag | free | M | next results season |
| 21 | Secondary commodities, freight, US / EU read-across peers (coal, palm, sugar, rubber, LNG, cracks, ACN / CTSH, defence, autos) (global) | add to W snapshots (Yahoo / Sina / Investing manual) | second-order sectors (paints, FMCG, tyres, city gas, IT) | free | S | YES (Yahoo symbols) |
| 22 | Short-pressure and realised-vol context (SLB, short-sale disclosure, MTF, FOVOLT) (exchanges) | EOD loaders | squeeze risk and "is premium cheap vs realised vol" | free | S | weeks 2-4 |
| 23 | X not used (news, spec) | X Pro lists on the trader's screen now; API only after credits and an audit trigger | government / TV-desk flashes T0 | X Premium (trader) / API credits | S | trader-side only |

### 6.2 Code issues found (fix list)

| # | Issue | Where | Fix | Trial |
|---|---|---|---|---|
| a | Kite quote mode carries no OI, no bid / ask, no exchange timestamp - the option gate would be blind | spec S2 / S9 earlier draft; any feed code still calling `set_mode(quote)` for options | Already fixed in the spec (FULL for every strike). Verify in the live feed code that FULL is set on every option token AND re-set after every reconnect; log the mode per connection at 09:00 | YES |
| b | `morningmkts.py` relies on one unofficial Yahoo address (query1 / query2 are the same provider), compares with Yahoo's unnamed `previousClose`, has no holiday / session check | `intraday_patches/morningmkts.py` `quote()` | Wrap in a source chain: Yahoo -> Stooq -> CNBC quote; MCX / CDS when open; store {source, contract, reference kind and time, market time}; reject if `regularMarketTime` is older than its session allows; two witnesses per driver | YES |
| c | Wrong copper / aluminium proxies: `HG=F` is COMEX copper (US tariff premium - size wrong), `ALI=F` is the thin COMEX aluminium contract (stale last trade) | `morningmkts.py` LINKS; `knowledge.py` WORLD list | Copper / aluminium / zinc = MCX live (in its hours) + LME official (Westmetall) + SHFE via Sina in Asian hours; HG=F kept as a direction witness only; ALI=F removed | YES |
| d | Yahoo continuous-crude roll glitch (CL=F +8.33% on 30 Apr); BZ=F rolls too | `gir/gir.py` GlobalPreMarket (crude excluded since), `morningmkts.py` BZ=F / NG=F / GC=F | Explicit contract months compared with the same contract's previous settlement (J44); K check rejects a move when the contract code changed; MCX CRUDEOIL (WTI-linked, labelled) in session | YES |
| e | The old `gir/` folder still lists the dead Reuters RSS (`gir/gir.py` lines ~440-441 `feeds.reuters.com`, also `gir_v63.py`) and Nitter (`gir/archive/global_eye_new.py` ~3252 `nitter.net/*/rss`) | gir/ | Check what the live server actually runs; remove both; replace Reuters with the news sitemap and Nitter with SEBI / NSE / BSE official RSS + X Pro (manual); a dead source must fail loudly, not return "no news" (B6.5) | YES |
| f | Stale check judges age by file modification time: a file rewritten with old data looks fresh; a quiet-but-correct file looks stale | `intraday_patches/crosscheck.py` C4 / C8 (`os.path.getmtime`), `gir/watchdog.py` `log_stale_min` | Judge by the newest SOURCE timestamp inside the data (clock 1) and by values changing (clock 2), per S3.1 / S3.2; an aggregate is as old as its oldest input; keep mtime only as a "writer alive" signal | YES (health only) |
| g | `^NSEI` used as a GIFT Nifty proxy in `GlobalPreMarket`; GIFT read only once via LTP | `gir/gir.py` | Use the stored GIFT series (J08 / J47) | YES |
| h | `EconCalendar` is a hand-edited `econ_events.json` | `gir/gir.py` | J28 automatic calendar with consensus; the JSON stays only for manual additions | YES |

---------------------------------------------------------------------------------------------------------------------------------

## 7. COSTS

### 7.1 Free first (the whole core of this plan is Rs 0 extra)
Kite Connect four apps (already paid, ~Rs 500 per app per month with historical data, ~Rs 2,000 + GST [verify]); NSE / BSE
archives, JSON, RSS; NSE IX page; SEBI / RBI / PIB / ministries / CBIC / DGTR / DGFT / gazette / courts / ECI / IMD; Yahoo, Stooq,
CNBC quote, Westmetall, lme.com, Sina / AKShare, Eastmoney, CFETS, EIA, FRED, Treasury, Federal Register, USFDA / openFDA,
ForexFactory, official release calendars, GDELT; Reuters and publisher sitemaps / RSS / live blogs; Business Wire / PR Newswire /
SEC EDGAR; Telegram client API; YouTube channel RSS; Upstox Analytics Token feed; ICICI Breeze; Angel SmartAPI; VAHAN, MoCA,
Grid-India, CEA, IEX pages; local faster-whisper STT on the server's CPU.

### 7.2 Paid - the short list, each with the trigger that would justify it

| Item | Rough cost | Trigger (all measured by GIR's own scorecard / audit) | When |
|---|---|---|---|
| Dhan Data API (expired options with IV / OI, 20-depth) | Rs 499 + GST / month | buy in week 2: IV rank and results-reaction tables are needed now; cancel after the history is seeded if not used for depth | weeks 2-4 |
| Spare Android phone + SIM for the push mirror | ~Rs 300 / month (+ an old phone) | none - cheapest legal way to get every outlet's "this is big" pushes | weeks 2-4 |
| Cloud STT for Hindi / extra channels (Deepgram / Sarvam) or a small GPU box | ~Rs 2-8k / month | the miss audit shows >= 2 TV-first "sources" stories a week that GIR caught late, AND local whisper is too slow / inaccurate on Hindi | month 2 |
| X API credits | per X's current tiers [verify] | >= 3 X-first tradable moves in two weeks that every other source had later than the move start (spec 8) | month 2+ |
| Paid economic-calendar API (FMP / EODHD) | ~US$20-60 / month | ForexFactory fails > 2 times a month, or actuals arrive later than the price reaction | month 2+ |
| TradingView Essential + CME / ICE data (webhook alerts) | ~US$15-25 / month | the 19:45 / 07:15 notes need an overnight push when Brent / gold / copper cross +-2% at night | month 2+ |
| TrueData / Global Datafeeds (licensed second feed; GDFL expired tick history) | ~Rs 1.6-5k / month | the free second feed (Upstox) has > 2 incidents a month, or terms forbid its use | month 2+ |
| IBKR market data (real-time ICE Brent, LME, Asian futures) | ~US$10-30 / month | in-session Brent / LME ticks needed beyond MCX (e.g. Brent-WTI spread moves matter for OMC calls) | month 3+ |
| Fyers TBT (true trade-by-trade, 50-depth on held strikes) | Prime plan [verify] | after 100+ journalled trades, to test S6 order-flow signals | month 3+ |
| Paid USFDA 483 database (Redica / FDAzilla) | US$ thousands / year | pharma miss audit shows FDA-driven moves free sources could not catch | only on the audit |
| BigMint (Indian steel prices) | ~Rs 0.5-3 lakh / year | steel trades dominate the journal and price-hike news arrives late | only on the audit |
| Paid Indian newswire (Informist) | ~Rs 1.5-5 lakh / year | the paid-source gate: >= 3 tradable moves a week where free sources were later than the move start and the wire carries that story type (spec item 43) | only on the audit |
| Standby server in a second region | per provider | after the basics run 100+ trades (spec ADVANCED) | month 3+ |

Not worth paying for (spec + maps): Bloomberg / LSEG terminals, NSE Data & Analytics licensed feeds for one user, co-location,
satellite / AIS / app-download / web-traffic data, CMIE / Capitaline / ACE, paid "AI signal" platforms, NewsAPI-type aggregators.

---------------------------------------------------------------------------------------------------------------------------------

## 8. LEGAL RULES FOR COLLECTION (India, personal use)

1. **Personal use only.** Exchange data (Kite, NSE, BSE, MCX, NSE IX) is licensed for the account holder's own use: the GIR
   dashboard stays private behind a login, nothing goes on a public page or channel, nothing is resold or shared.
2. **No redistribution of anything collected** - articles, transcripts, paid data, exchange data, the analyst's calls (sharing
   calls with others needs SEBI RA / IA registration). Store headline + lead + link; full text only transiently for analysis.
3. **Gentle polling** as in 0.5: published machine endpoints first (APIs, RSS, sitemaps, archive files); conditional GETs; jitter;
   back-off; honour robots.txt; no parallel hammering; NSE at most one request per 3-5 s per endpoint.
4. **Never behind logins, captchas or paywalls.** No captcha solving, no login bypass, no paywall circumvention, no IP rotation to
   evade a block. If NSE / BSE block the server, move to a licensed route - do not evade.
5. **Sites whose terms forbid automated access stay manual:** Investing.com, CME FedWatch (heavy use), TradingView, LME current
   prices, Sensibull / Opstra / analytics sites, Google Trends, Flightradar24, MarineTraffic, Downdetector. Unofficial TradingView
   scrapers and the Kite `enctoken` web API are not used.
6. **X only through the official API** (or the trader's own X Pro on a screen). No scraping, no Nitter, no reseller "Twitter APIs".
   YouTube: prefer an HDMI capture of the trader's own set-top box for STT over downloading streams; keep transcript snippets only.
   Telegram: own account, public channels, no reposting. WhatsApp: phone notifications only, no automation.
7. **No unpublished price-sensitive information** (SEBI PIT Regulations 2015): nothing from private groups circulating results or
   deal documents before the filing, no "channel checks" with company employees, dealers under confidentiality, auditors or
   regulators' staff. Published media "sources say" stories are public - tagged UNVERIFIED until the company or regulator confirms.
8. **No personal data** (DPDP Act 2023): aggregates only - no VAHAN owner records, no property-registration party names, no
   profiling of private people; journalists and accounts are followed by outlet and role. User-Agents and contact strings are
   generic (no personal names / emails in requests).
9. **Tip channels are never a signal**: unregistered "stock tip" channels (SEBI finfluencer rules) count at most as a retail-crowd
   warning.
10. **Kite login stays manual**; four apps on one account only as Zerodha's terms allow (confirm by ticket [verify]); data-only use
    needs no static IP; if orders are ever sent by API, SEBI's retail algo framework applies.
11. **Paid data** is used only within its licence: no shared logins, no redistribution, automated download only where the plan
    allows it.

---------------------------------------------------------------------------------------------------------------------------------

## 9. BUILD ORDER

"TRIAL-OK" = runs during the trial week (from 19 Nov) with no page change: back-end collectors, recorders, health checks and new
inputs to the analyst's notes. Anything that changes what the page shows waits for the end of the trial.

### Phase 1 - week 1 (the trial week, 19-25 Nov; stock expiry 23 Nov (24 Nov is an NSE holiday) falls inside it)
Order inside the week: first what makes the 19:45 / 07:15 notes name the right shares, then the gate, then the recorders.

| Day | Item | Jobs | TRIAL-OK |
|---|---|---|---|
| 19 Nov (evening) | Run the verify-first list (section 10) from the Mumbai server; record real paths, publish times, columns | - | YES |
| 19 Nov | Subscribe MCX + CDS + NSEIX on K1 C3; store GIFT / MCX / CDS minute series | J08, J09, J71 | YES |
| 19-20 Nov | Fix world inputs: source chain (Yahoo -> Stooq / CNBC), explicit contracts + settlements, named references, two witnesses; MCX + Westmetall LME + Sina SHFE / DCE replace HG=F / ALI=F; US 2y, CNY fix, CNH / JPY; W1945 / W0700 / W0845 / W0900 snapshots; the 1J manifest | J23, J24, J29, J44, J45, J50-J53, J68, code issues b, c, d, g | YES |
| 19-20 Nov | Two-clock heartbeat and stale checks (health side only) | 0.3, code issue f | YES |
| 20 Nov | Verify FULL mode on every option token, re-set after reconnect; sentinels per connection; K4 standby takeover; LTP dead-token sweep | section 2, code issue a | YES |
| 20-21 Nov | Recorders start: raw frames, instrument dumps (forever), ATM IV per minute + daily, spreads by strike (09:30 / 12:00 / 14:30), pre-open series, futures OI all months | R1-R6, R9, J02, J72, J77, J78 | YES |
| 21 Nov | NSE + BSE announcement JSON at 3-5 s with earliest-wins dedupe and the category classifier (order win, clarification / denial, USFDA terms, results, OFS / QIP, tax demand) | J60 | YES |
| 21 Nov | Reuters news sitemap in; remove dead Reuters RSS and Nitter; Google News out of the alert path | code issue e | YES |
| 22-23 Nov (weekend) | Automatic calendar with consensus (ForexFactory + official), results calendar, risk strip; the near-date rows (23 Nov (24 Nov is an NSE holiday) expiry, 26-27 Nov US holiday, 30 Nov GDP / NBS PMI, 1 Dec auto sales) | J28, J31, J65, J10, J27, J52, code issue h | YES |
| 22-23 Nov | EOD loaders checked: ban T+1, combineoi (2025 columns), bhavcopies, delivery, deals, FII / DII, FOVOLT; evening Kite-vs-NSE reconciliation blocking mismatched shares | J12-J22, J35 | YES |
| 23-23 Nov (24 Nov is an NSE holiday) | Expiry-week mode for 23 Nov (24 Nov is an NSE holiday) (next-month strikes, futures roll, physical-settlement warning) | section 2, 1I | YES |
| 24-25 Nov | Per-source latency record + the 15:45 movers list and "missed the move" list into the scorecard | J05, J06, R10 | YES (scorecard text, not a page change) |
| by 30 Nov | VAHAN MTD recorder + the 1 Dec auto-sales expectation lines in the 19:45 note | J37, J56 | YES |
| all week | SEBI / RBI / PIB RSS into the policy pipeline; nightly derived history (ATR, levels, RVOL baselines) | J25 (RSS part), J38 | YES |

### Phase 2 - weeks 2-4 (26 Nov - mid Dec)
- Upstox second feed with per-instrument failover; NSE option-chain cross-check (J79); Angel build-up cross-check (J83).
- Dhan expired-options history (Rs 499) + Breeze spot checks -> IV rank / percentile, results-reaction table, IV-crush filter on
  real numbers (J39, J38).
- Publisher news sitemaps + live-blog JSON; Business Wire / PR Newswire / EDGAR; Telegram listener; spare-phone mirror.
- Policy scrapers: CBIC, DGTR, DGFT, e-Gazette, CCI / TRAI / CERC; court cause lists (J30); USFDA watcher (J40) + pharma
  classifier and plant table; Federal Register / USTR (J41); order watcher scaled by revenue; PIB MoD / DAC.
- XBRL results parsing; consensus capture for results (R13); con-call schedule.
- Live FutEq MWPL estimate (J80); SLB / short-sale / MTF loaders.
- CNBC Awaaz STT; YouTube channel RSS to auto-start RBI / PIB / SEBI pressers; RBI MPC (early Dec [verify]) as the first test.
- Industry recorders: MoCA, Grid-India PSP, CEA coal, IEX DAM (R16-R18); fuel prices on the 1st (J49).
- Page work resumes only after the trial: freshness dots driven by the two-clock heartbeat, the latency dashboard, the risk strip.

### Phase 3 - month 2 and later
- Measured sensitivities replace rule-of-thumb driver thresholds (E2: after 6-12 months; start the regressions monthly).
- Paid items only through their triggers (section 7.2): X API, cloud STT, calendar API, TradingView webhooks, TrueData / GDFL,
  IBKR, Fyers TBT for S6 order-flow tests, paid FDA database, BigMint, newswire.
- Ticker-band OCR on TV; tender-result scans (CPPP, IREPS, PFCCL / RECPDCL); Google Trends incident checks (official API only).
- Standby server in a second region; second alert channel; quarterly review of every source against the random baseline - drop any
  source that has not beaten it after 100 calls (B8).

---------------------------------------------------------------------------------------------------------------------------------

## 10. VERIFY FIRST (from the Mumbai server, once, before coding the fetcher; record status, Last-Modified, columns)

1. NSE archive patterns for the last trading day: UDiFF CM / FO bhavcopies, `fo_secban` (T+1 naming), `combineoi` columns after
   the FutEq change, `sec_bhavdata_full`, `FOVOLT` path, NSE contract-file name, MTF / SLB paths, `ind_close_all`.
2. NSE JSON from the server IP with cookie warm-up: corporate announcements, pre-open `key=FO`, option chain (old and new paths),
   FII / DII, large deals, live-analysis endpoints - note which Akamai blocks.
3. BSE announcement API parameters and attachment paths.
4. Kite: per-key websocket limits, quote / historical rate limits, whether the instrument dump needs auth, futures pre-open quotes
   09:00-09:08, MCX segment enabled, NSEIX contracts exposed (GIFT Nifty and sector futures), multi-app terms (support ticket).
5. NSE IX GIFT Nifty session hours under the 2026 change (session 1 start, session 2 16:05 vs 16:35).
6. Circulars FAOP71092 (F&O pre-open), SURV71090 (MWPL random snapshots), CMTR71394 (block windows), SEBI 29 May 2025 (FutEq /
   MWPL) and 8 Oct 2025 (block deals): exact thresholds into the rule table.
7. Sina basket symbols and the Referer requirement; AKShare function names (pin a version; run fetched-data parsing with `python -I`).
8. Westmetall table layout and update time; LME official publication window.
9. ForexFactory JSON fields, time zone and rate limit; Nasdaq.com calendar JSON.
10. Reuters news sitemap URL; each publisher's news sitemap from robots.txt; live-blog JSON patterns.
11. Upstox V3 mixed-mode caps and Analytics Token terms; Dhan expired-options parameters and price; Breeze expired-F&O depth.
12. Yahoo explicit-contract symbol formats for Brent / WTI / COMEX metals; CNBC quote symbols (US2Y, IN10Y).
13. VAHAN dashboard access pattern (no owner data, low rate); MoCA panel; Grid-India PSP URL pattern; IEX snapshot tables.
14. USFDA warning-letter page filters, Import Alert 66-40 page, openFDA endpoints.
15. Dates: 23 Nov (24 Nov is an NSE holiday) expiry, MSCI November review effective date, 30 Nov GDP, RBI MPC December dates, NSE 2027 holiday list (December).
