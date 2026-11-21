# GIR v2 - Data inventory

Written 18 Nov 2026. Merges the ten expert visions' data needs with GIR_SPEC.md's DATA LIST (#1-#49), EXTERNAL DATA (E1-E6) and
S1-S10. D-numbers are referenced by IA.md. "Spec #" maps each item back to the spec's DATA LIST so the server can keep filling its
HAS / PARTLY / MISSING column. Level: **B** = basic (build and prove first), **A** = advanced (after the basics have worked for 100+
trades, or when the miss audit proves the need). "Verify" means: check the current exchange / broker / vendor terms or limits before
coding; every rule of thumb here is a starting value to be replaced by GIR's own measurements.

## 1. Rules that apply to every item

### 1.1 Every number is a Fact

A Fact = {value, unit, source, source time (exchange_timestamp / publisher time / file content date - never file modification time),
first-seen time, age, state, quality flags}. States: **LIVE** (inside its limit) · **LATE** (usable, age shown) · **STALE** (blocks
anything that depends on it) · **QUIET** (an illiquid instrument on a healthy connection with no new trade; its two-sided quote may
still be fresh) · **SUSPECT** (failed a range or physics check) · **CONFLICT** (two sources disagree > 2 ticks or 0.3% for > 5 s) ·
**INCOMPLETE** (aggregate with < 90% of weight LIVE) · **CLOSED** (the market for that Fact is shut; last value shown with its time,
never as live). A per-feed progress fingerprint catches values that are re-saved but no longer change.

### 1.2 One writer per Fact

No number is written to two files by two processes. Each D-item names its owner process. Pages never fetch on their own; they read
one Server-Sent-Events store (sequence numbers, snapshot on reconnect).

### 1.3 The freshness table (the only one; Health shows it)

| Family | LIVE | STALE | Notes |
|---|---|---|---|
| Feed sentinels (2 liquid tokens per connection) | < 2 s | > 5 s (reconnect at > 3 s silent) | judges the CONNECTION |
| Decision-critical instrument (share or strike in a call / position) | quote age <= 2 s | > 5 s | GO NOW disabled "STALE 8s"; held + both Kite paths > 5 s = P1 |
| Other equity / future quote | <= 3 s | > 10 s | |
| Other option quote | <= 5 s | > 15 s | trade age separate; last trade > 2 min = QUIET |
| Futures / option OI | <= 3 min | > 6 min | build-up tags greyed when OI > 5 min old |
| Sector / breadth aggregate | coverage >= 90% of weight LIVE | < 90% = INCOMPLETE | sector cannot CONFIRM while INCOMPLETE |
| Positions / orders sync | <= 10 s | > 30 s | > 10 s with a position open = P1 |
| News source | items vs usual rate for this hour | "quiet at a busy hour" = named error | night limit 2 h |
| World drivers | per source cadence | session-aware: CLOSED is not STALE | DELAYED / DAILY labelled |
| NSE / Kite reference files | content date = today | any other date = RED, dependants blocked | never fall back to yesterday |
| status.json (the health page itself) | <= 120 s | > 120 s page turns red | |

### 1.4 Units (same on every page)

Prices at instrument tick precision; premiums in Rs; OI in lots (contracts; shares on hover); distances in ATR; time to expiry in
sessions (incl. today) and trading minutes; P&L in R first, Rs second; percentages always with their base ("% from open", "% since
15:30 IST"); notional in Rs crore; Indian digit grouping.

### 1.5 Live feed plan (four Kite keys; verify multi-app terms and current limits)

| Key | Connection | Instruments | Mode |
|---|---|---|---|
| K1 | c1 | 218 F&O shares + NIFTY, BANKNIFTY, VIX, NSE sectoral indices + sentinels | FULL |
| K1 | c2 | futures of all three months for the F&O shares (~654) | FULL |
| K1 | c3 | remaining NSE shares used for equal-weight sectors and breadth; MCX metals / energy and CDS USDINR (if the segments are enabled) | QUOTE (equities) / FULL (MCX, CDS) |
| K2 | c1-c3 | options ATM +-5 current + next month for the watch list, held and called strikes, OI-wall strikes | FULL (depth, OI, timestamps) |
| K3 | c1-c3 | options ATM +-5 current month (next month from T-5) for every other F&O share, re-centred on the future when it moves half a strike (subscribe new before unsubscribing old) | FULL |
| K4 | c1 + REST | HOT DUPLICATE of held / called strikes, their shares and all sentinels; rotating REST /quote sweep (dead-token detection) and the full-chain OI sweep every 120 s | FULL + REST |
| Vendor B (optional, A) | - | equities, current futures, pinned strikes, sentinels | live; CONFLICT check |

After every reconnect: resubscribe and set the mode again; backoff with jitter. State (VWAP, opening range, OI baselines) is
checkpointed to local disk every 60 s. Raw frames recorded off the live path. Paint batched at 2-4 Hz per cell.

## 2. The inventory

Columns: D# · item · source · frequency · freshness · used on (page / panel) · level · spec #.

### 2.1 Reference data (must be right every day)

| D# | Item | Source | Frequency | Freshness | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|---|
| D1 | Instrument master: F&O list, tokens, strikes, lot sizes, tick sizes | Kite instruments dump + NSE contract master + NSE fo_mktlots | daily 08:00-08:45; reconciled with NSE every evening and 08:30 | content date = today | everything; Pre-flight; Reference; plan card quantity check | B | 1 |
| D2 | Expiry calendar as NSE states it (holiday-shifted: Mon 23 Nov, Tue 29 Dec, Mon 25 Jan this cycle), sessions and trading minutes left | NSE contract master + D5 | daily | content date = today | day line expiry chip; chain expiry tabs; Calendar derivatives section; plan card; expiry-week / expiry-day modes | B | 2 |
| D3 | F&O ban list, MWPL % (NSE futures-equivalent, cross-exchange figure - never computed from Kite OI), near-ban, exits-ban | NSE fo_secban + combined-OI / MWPL files (verify names) | evening + 08:30 + intraday when published | file trade date checked | day line ban pill; option gate; Futures & OI MWPL monitor; Share header | B | 3 |
| D4 | Corporate actions, ex-dates, symbol changes, adjustment factors | NSE corporate actions | daily | today | history adjustment; basis distortion flags; Calendar; Share events | B | 4 |
| D5 | Holiday list and exchange session calendars (NSE, MCX, CME, LME, SHFE/DCE, NYSE, JPX) | official calendars | yearly + on circular | - | expiry shift notes; world-driver OPEN / CLOSED / HOLIDAY; phase engine | B | 5 |
| D6 | Sector map: share -> sector(s) with weights -> drivers (revenue vs cost driver), dependents; versioned with effective dates | GIR knowledge base from NSE data | monthly; audited edits outside market hours | version shown | Sectors; Desk sectors; chain rows; driver concentration gate; Reference editor | B | 6 |
| D7 | Company name table: symbol, ISIN, names, brands, parent, subsidiaries, old names, ambiguity rules; per-alias precision, quarantine | NSE + GIR | monthly + daily precision | - | news tagging; Health tag court; Reference | B | 7 |

### 2.2 Live market (09:00-15:30)

| D# | Item | Source | Frequency | Freshness | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|---|
| D8 | Share ticks: LTP, ATP / VWAP, volume, best-5 depth, last trade time, exchange timestamp | Kite WS K1c1 FULL (+ K4 duplicate for held / called) | ~1 snapshot/s | 2 s / 5 s (critical) | in-trade strip; Desk positions, members, chart; Share; every price | B | 8 |
| D9 | NIFTY, BANKNIFTY, India VIX, advance / decline | Kite WS | live | 3 s / 10 s | risk bar; Sectors context strip; day type | B | 12 |
| D10 | Official NSE sectoral indices + all NSE shares for GIR equal-weight sector % and breadth (with coverage) | Kite WS K1c1 / K1c3 + GIR | live; sector calc every 2 s; snapshots every 1 min (recorded) | coverage >= 90% | Desk sectors; Sectors; Rotation; chain rows | B | 10, 11 |
| D11 | 1-min / 5-min candles built on exchange-time buckets (gaps shown, never interpolated); Kite historical for backfill and reconciliation at minute + 20 s | GIR candle builder + Kite historical (oi=1 for futures) | live + nightly | as D8 | charts; OR; VWAP; ATR; RVOL | B | 9 |
| D12 | Futures price + OI for ALL months (current, next, far); start-of-day OI baseline = NSE bhavcopy OI reconciled with Kite (mismatch blocks the share) | Kite WS K1c2 FULL; D31 | live; OI judged per 1-min snapshot with its own "OI as of" | OI 3 / 6 min | build-up; Futures & OI; Share futures; sector confirmation check 4; in-trade OI since entry | B | 13 |
| D13 | Futures and share volume profile by time of day (20-day); proxy for the first 20 days = bhavcopy daily volume x the share's cash minute profile (stated) | GIR recordings + Kite historical (no minute history for expired contracts) | daily build | - | "volume vs normal"; RVOL; build-up tag validity | B | 14 |
| D14 | Full option chain (all strikes, two expiries; three in expiry week): OI, volume, LTP | Kite REST /quote sweep on K3/K4 (500 instruments per call) | every 120 s; ATM +-5 live via D16 | OI 3 / 6 min | chain grid OI; OI walls; Futures & OI option activity; chart OI lines | B | 15 |
| D15 | Pre-open indicative price and quantity (cash F&O shares) | NSE pre-open data (F&O category, polled gently every 30 s) cross-checked with Kite at 09:07:30 | 09:00-09:08, saved daily (no free history) | - | Morning pre-open table; 09:08 note | B | 17 |
| D16 | Option bid / ask / best-5 depth / OI / last trade time / exchange timestamp for ATM +-5 (current, next), watch, held, called and wall strikes | Kite WS K2 / K3 FULL (+ K4 duplicate for held / called) | ~1/s | 5 s / 15 s; critical 2 / 5 s | option gate; spread % (red > 1%); premium pane (mid); plan card; in-trade premium; exit depth | B | 16 |
| D17 | Second path: K4 hot duplicate (B) and vendor B ticks (A: Dhan / Upstox / Angel / Fyers free with an account, or paid - verify terms) | Kite K4; vendor B | live | CONFLICT > 2 ticks or 0.3% for > 5 s | in-trade strip ("PRICE UNKNOWN - use broker app"); Health cross-checks | B (K4) / A (vendor B) | S2, S9 |

### 2.3 Calculated by GIR (plain code, < 50 ms, no AI)

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D18 | Opening range (15 / 30 min), prev-day H/L/C, 20-day H/L, weekly H/L, VWAP | D8, D11 | daily + live | chart lines; Levels table; checklist D3 / D5 | B | 18, 22 |
| D19 | Relative strength: share vs sector and vs NIFTY since 09:15; sector RS vs NIFTY; ranks and rank changes 15M / 30M / 1H / TODAY; role LEADER / FOLLOWER / LAGGARD / DIVERGENT; share-minus-sector strip | D8, D10 | live (2 s), 1-min snapshots | Desk sectors + members; Sectors; Rotation; chart strip | B | 19 |
| D20 | RVOL at the same time of day vs 20-day | D8, D13 | live | members; chart header; checklist D2 | B | 20 |
| D21 | ATR14 (daily), range used = |move| / ATR14, room to next level in ATR, "extended" > 1.2 | D11, D18 | daily + live | members; Share; chase gate; zone | B | 21 |
| D22 | IV (bid / ask / mid), delta, gamma, theta (Rs / hour / lot), vega - Black-76 on the same-expiry future (or the synthetic forward from put-call parity), time in trading minutes, never from LTP; first prints after 09:15 not used | GIR greeks engine; risk-free rate D59 | every 2-5 s for shown strikes | chain; plan card; positions; gate delta; P&L attribution | B | 23 |
| D23 | ATM IV per share: back-fill ~2 years from NSE F&O bhavcopy settle prices (labelled "from closes"), then recorded live daily at close; IV vs 20-day average; IV rank / percentile with window, n and method; realised vol RV10 / RV20; IV / RV; near vs next ATM IV (term) | D31 + D22 | daily 15:30 + live | IV-crush gate; chain header / footer; Share history; Calendar results IV | B (back-fill + 20-day avg + term) / A (skew) | 24 |
| D24 | OI walls (strike OI >= 2.5x median of ATM +-5, >= 10% of that expiry's side OI, within 1.5 ATR; max one per side per expiry; WEAKENING = OI -10% since open + premium up + volume >= 3x) and option activity events (BUYING BURST, WALL BUILDING / WEAKENING, PAYING UP) with their record | D14, D16, D22 | 1-3 min | chart OI lines; chain walls; Futures & OI scanner; entry-room check | B (walls) / A (activity, paper-only until 100 events) | 15, S6 |
| D25 | Expected move to 15:10 (ATR14 x sqrt(fraction of session left) and IV-based), break-even premium and share move by planned exit and by 15:10, R:R after costs, theta to exit | D21, D22, D26 | per call / order | call card; plan card; chain buyer's comparison; cost gate | B | 25 |
| D26 | Charges table (brokerage, STT, exchange, SEBI fee, GST, stamp duty) versioned with effective dates and source circular + "verified on"; measured spread cost per fill | Zerodha / NSE / SEBI / Finance Act notices; Kite charges API check; D16 at fill | per order; verified weekly and after every Budget | plan card; net P&L; tax ledger | B | 26 |
| D27 | Option gate result per strike and per call (each rule with its number) | D3, D16, D22-D26, D47, D48 | live | chain gate column; members gate; call card chips; plan card checks | B | E |

### 2.4 End of day (load after 18:00, use from the next day only)

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D28 | Delivery % vs 20-day | NSE sec_bhavdata_full | daily | context only (Morning, Futures & OI context panel) | B | 28 |
| D29 | Participant-wise OI; index PCR | NSE fao_participant_oi; GIR from index chain | daily | "context - never a reason" panel only, with its date | A | 29 |
| D30 | FII / DII cash (provisional), always with its date | NSE | daily ~19:00 | 19:45 note; context chips | B | 31 |
| D31 | F&O and cash bhavcopy (UDiFF): close, settle, OI, volume per contract; 2-3 year archive back-fill | NSE archives | daily after 18:00 + one-time back-fill now | Kite cross-check; start-of-day OI; IV back-fill; rollover history; scorecard (next day) | B | 27 |
| D32 | Bulk / block deals, SAST, pledges | NSE / BSE | evening / as filed | Share red flags; 19:45 note context | B | 30 |

### 2.5 News, filings and policy (story store with three clocks)

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D33 | NSE + BSE corporate announcements (symbol-tagged; earliest wins); exchange clarifications (CLARIFIED / DENIED) | NSE / BSE announcement JSON (RSS fallback): cookie warm-up, keep-alive, conditional GET, jitter, back-off on 403 / 429 | every 3-5 s | News filings view; members news chip; unread-filing lock; Share | B | 36 |
| D34 | Filing attachments (PDF) and XBRL results; numbers extracted and sized vs TTM revenue / market cap | NSE / BSE archives + XBRL results archive | on arrival | impact score; results lines; "READING..." state | B | 36, 37 |
| D35 | Wire headlines, publisher news sitemaps, live blogs (follow-ups only); Google News / GDELT backfill and geopolitics context only (never alerts); TradingView dropped | wire sitemap (15 s); publisher sitemaps (20-30 s); live blogs (60 s) - headlines and links only, check terms | seconds | News; story source ladder | B | 39 |
| D36 | TV speech-to-text (English + Hindi) from official live streams; Telegram public news channels | ASR on 5-10 s chunks (~Rs 2-8k / month); Telegram listener (push 1-3 s) | live | News TV desk; management statements / denials | B | 40 |
| D37 | Regulators and gazette: SEBI, RBI, PIB, CBIC, DGTR, eGazette, USFDA (warning letters, import alerts), CCI | official RSS / sites | 60 s evenings, 1-5 min otherwise; RBI policy day 10 s | Calendar policy pipeline; News policy filter | B | 38 |
| D38 | Policy pipeline store (PENDING -> ANNOUNCED -> NOTIFIED, body, expected date confirmed / rumoured, shares, direction, priced-in) | small model reads D37, code tracks status | per item | Calendar; Analyst compact pipeline; 19:45 note | B | E3 |
| D39 | Story store: one event = one story; source time / first-seen / move-began; source ladder; verification; event type; direction; impact 0-5 computed in code (event type x size ratio x novelty x verification); NEW / PRICED IN (>= 0.7 ATR moved since move-began) / RETOLD / UNEXPLAINED (> 2 sigma move with no story); lead/lag; event study (+5 / +15 / +30 / +60 min, close, next open) | GIR (small model proposes type and numbers; code scores) | append-only, live | News; Desk news line; story drawer; members chip; scorecard miss audit | B | 3.4, S1 |
| D40 | X (journalists, regulators) and a paid Indian newswire | X API (credits); Cogencis / CMOTS | live | News | A (only if the miss audit proves DATA LATE) | 42, 43 |

### 2.6 World drivers (night + morning; live where licensed)

All moves measured from the Indian close (15:30 IST) with session state; event times computed from the source time zone (DST-aware).

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D41 | Brent / WTI, COMEX gold / silver / copper, US index futures, Nasdaq, SOX, DXY, US 10-year | low-cost licensed world-data API (not scraping) or clearly labelled DELAYED free source (verify terms) | snapshots 15:30, 19:45, 23:45, 07:15, 09:00; 1 min 19:00-02:30 | Morning driver board; World drivers; notes | B | 32-34 |
| D42 | MCX crude, natural gas, gold, silver, copper, zinc, aluminium; NSE CDS USD/INR futures | Kite WS K1c3 (verify segment access) | live | in-session drivers; Sectors driver line; commodity-lag flag; unscheduled-shock freeze | B | 32, 33 |
| D43 | GIFT Nifty | NSE IX collector | 1 min 06:30-09:15 | Morning; World drivers | B | 34 |
| D44 | Indian ADRs (INFY, WIT, HDB, IBN, RDY) close vs NSE close in INR | as D41 | 07:15 | Morning; IT / banks chain rows | B | 34 |
| D45 | Asia: Nikkei, Kospi, Hang Seng; China data 07:00-07:30 | as D41 + official NBS | 07:15-09:00 | Morning; 08:45 update | B | 35 |
| D46 | LME official, SGX / Dalian iron ore, SHFE rebar (marked DAILY); India 10-year (CCIL / RBI reference) | free delayed publisher / API; CCIL / FBIL | daily 07:15, 09:00; India 10y + 10:00 | Morning driver board | B | 32, 33 |

### 2.7 Events and calendars

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D47 | Event and economic calendar: tier 1-3, IST time (DST-aware), in-session flag, consensus (with source), actual, surprise score ((actual - consensus) / typical surprise), scenario -> sectors, no-entry windows; "today's risk" built 08:30 | official sites (RBI, MoSPI, BLS, BEA, Fed, NBS, BoJ, OPEC, MSCI / FTSE / NSE Indices, ECI) + free IST calendars for consensus | weekly build; 08:30; live on release (+60 s) | day line; Morning risk strip; Desk event line; Calendar; event-window state | B | 41, E1, E2 |
| D48 | Results calendar with timing (before / during / after market), board meetings, F&O inclusion / exclusion, index rebalance dates, lot revisions | NSE / BSE board-meeting notices and circulars | daily 08:00 + every 15 min | IV-crush gate; Calendar results; Share events; day line results chip | B | 37 |
| D49 | Release outcomes with surprise and automatic note ("China PMI 51.2 vs 50.5 (+1.4) -> metals bullish, medium; wait 15 min") | D47 + live | on release | Morning overnight events; Calendar; notes | B | E2 |

### 2.8 The trader, the broker account and risk

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D50 | Check-in: slept, state, uninterrupted time; arm-the-day timestamp | trader (Morning / phone) | daily 08:45-09:15 | allowance; NOT ARMED state; journal behaviour panel | B | new |
| D51 | Today's commitments in his own words (tighten-only) | trader | daily | risk bar; Morning | B | new |
| D52 | Risk charter versions (every limit, reason, date, history) and the size ladder | GIR config | on change (next session) | all gates; Settings; weekly review | B | B1 |
| D53 | Funds / margins: available cash; capital used = lower of declared and available | Kite REST (read-only) | 08:30, after each fill, 1 min | allowance; cash gate; risk box | B | 44 |
| D54 | Positions, orders (incl. resting SL-LIMIT backstops: trigger, status, modifications), trades / fills with side, strike, expiry, quantity, price | Kite REST + order postback / WS order updates (read-only) | push + 2-5 s poll while a position is open, else 30 s | in-trade strip; positions; NO STOP / NO BROKER STOP / WIDENED / FILL MISMATCH / OWN TRADE; slippage; averaging-down detection | B | 44 |
| D55 | Risk engine state: day / week / month R, losses in a row, stop-outs, peak and give-back, trades used, open risk if all stops hit, premium outstanding, sector / driver / direction concentration, cooling timer, lock reason | GIR from D52-D54 | live | risk bar; risk box; LOCKED / COOLING; plan card | B | B1 |
| D56 | Plan cards (immutable, timestamped), skip / early-exit / re-entry reasons, paper twin per GO NOW and triggered GET READY (fills at ask in, bid out, +1 tick), MFE / MAE, price 30 min after exit, P&L split (share move / theta / IV / spread; sector / share / timing / exit / option choice) | GIR + D8 / D16 tick store | per event | Positions ledger; Journal; Scorecard | B | 45, B8 |
| D57 | Journal statistics: trade count toward 100 / 200, expectancy with range, drawdowns, edge gates, risk of ruin, behaviour slices | GIR from D56 | per trade / nightly | allowance size step; Journal; Edge; Positions risk box | B | B8 |

### 2.9 Research history (GIR's own measurements)

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D58 | Share history (E4): results-reaction table, gap-fill rate by gap size, day after a 3%+ move, leader / laggard record, expiry-week behaviour, MWPL / ban history, red flags (pledge > 25% or rising, PSU, regulatory), event-type reactions; ATM spread / depth log at 09:30 / 12:00 / 14:30 (cannot be back-filled - start now); sector run times by driver (n); driver x sector sensitivity matrix (next-day gap beta, hit rate, n; n < 30 = "rule of thumb") | GIR knowledge base (monthly, batch) + recordings + D31 | daily / monthly | Share history; Rotation run clock; Morning chain rows; World drivers | B (spread log, run times) / A (sensitivity matrix) | E4, 24 |
| D59 | Basis, excess basis vs fair carry, rollover % vs same-T-n average of the last 3 expiries, roll cost; 91-day T-bill rate | Kite D12 + D31; RBI / CCIL weekly | live / weekly | Futures & OI; Share futures; Black-76 rate; ROLL tag | B | 13 |

### 2.10 Health, logs and recording

| D# | Item | Source | Frequency | Used on | Lvl | Spec |
|---|---|---|---|---|---|---|
| D60 | Heartbeat table {source, last good time, value hash, rows, errors} judged against the clock-dependent limits | every service; checker | 10 s (prices), 60 s (rest) | footer; Health grid; SAFE MODE | B | 48, S3 |
| D61 | Connection metrics: tokens, instruments per connection, sentinel lag p50 / p95, reconnects, mode = expected, dead tokens found by the sweep | feed processes | live | command-bar feed dot; Health connection map; Pre-flight | B | S2 |
| D62 | Source contracts: HTTP status, content date, rows, layout fingerprint, known-answer row, final host after redirects; expected-rate watch | contract checker | per fetch | Health; fail-loud states | B | B6.5 |
| D63 | Reconciliation Kite vs NSE (lot, expiry, strike list, tick size, prev close, start-of-day OI) -> blocked shares | reconciler | evening + 08:30 | Pre-flight; Health; members gate | B | B6.4 |
| D64 | Latency per hop: exchange -> decoder -> SSE -> painted (page glass check); event -> alert -> ack per channel | timestamps on every hop | live | Health latency; scorecard chain latency | B | S2, S3 |
| D65 | Host: clock offset (NTP, every 60 s), disk, memory, certificates, backup, yesterday's replay OK | host checks | 60 s | Pre-flight; Health | B | S3 |
| D66 | Outside dead-man ping; external uptime check of status.json; canary (synthetic story / tick every 15 min) | free external services; canary job | 1 min / 15 min | Pre-flight; Health; P1 "GIR down" | B | S3 |
| D67 | Source latency ledger (p50 / p90 publish -> first-seen per source, % first, % before the move, median lead on movers) and alias precision | GIR | live + daily | News latency board; Health source board; scorecard | B | S1.6 |
| D68 | Interaction log: page / panel views, keys, focus, time from GO NOW to decision, overrides | GIR front end | every event | Journal behaviour panel; design evaluation | B (recording starts now) | new |
| D69 | Alert log: fired, first seen (page visible and alert in view), acknowledged (where, when), action taken; audible count vs budget | AlertManager + browser visibility API + Telegram | every alert | Health alert health; scorecard alarm budget | B | B7 |
| D70 | Analyst decision store / call log (immutable versions, evidence ids with ages, leg, validity, state changes) | AI gateway + validators | per decision | Desk call card; Analyst; Scorecard; Share calls | B | 46 |
| D71 | Notes and thesis store (legs, wrong-ifs, statuses over time, word counts, inputs-as-of, next-day score) | senior analyst + rule engine | per note / per leg change | day line; Morning; Analyst | B | TRIAL |
| D72 | AI log: prompt, output, model, tokens incl. cache-read, cost, latency, validator result; budget reserved before each call; ladder 60 / 85 / 100% of $20 | AI gateway (the only holder of the API key) | per call | footer ladder chip; Health AI; Scorecard spend and cost per useful call | B | 47, S4 |
| D73 | Paper engine and baselines: random F&O share (same rules, random times), mechanical rule (biggest driver -> mapped sector -> highest-beta shares) | GIR on recorded ticks | live + nightly | Scorecard; Journal; agent keep / drop | B | B8 |
| D74 | Raw recorder: every tick frame with seen-time, REST responses, news first-seen per source, SSE events, alerts, AI calls (~1 GB/day estimated, compressed after close) | GIR writer thread off the live path | live | Replay; miss audit; scorecard time machine | B | 49 |
| D75 | Evidence store: every price snapshot or story a note / call cites, with first-seen time (no look-ahead) | GIR | per claim | Why drawer; Ask answers; scorecard | B | I |
| D76 | Telegram bots (decisions, system) message ids for edit-in-place (EXPIRED, "seen hh:mm:ss", "recovered") | Telegram Bot API | per alert | P22 | B | 4.4 |

## 3. Build order for the missing basics (follows the spec's order, extended)

1. D1-D5 and D63 (reference truth; nothing else is right without it) - incl. the contract-master expiry fix.
2. D8-D12, D16, D17 (K4 hot duplicate), D60-D61 (feed you can trust, sentinels, sweep).
3. D18-D23 (calcs; ATM IV back-fill from D31), D25-D27 (cost and gate).
4. D33, D39, D47, D48 (fastest news and the event gates).
5. D53-D55 (broker truth, locks, NO BROKER STOP), D56 (plan card, paper twin).
6. D70-D75 (decisions, notes, AI log, baselines, recorder, evidence) - recording of D23, D58 spread log, D15, D68, D69 starts NOW,
   because history cannot be back-filled later.
7. Then D13, D14, D24, D28-D32, D34-D38, D41-D46, D49-D52, D57-D59, D62, D64-D67, D76.
8. Advanced (after 100+ trades or a proven need): vendor B (D17), X and a paid wire (D40), participant OI (D29), skew and the
   sensitivity matrix (D23 / D58 parts), order-flow activity as signals (D24 activity).

## 4. Explicitly NOT used as a reason for any call

Single-share PCR, max pain, participant-wise OI (index bias only), bulk / block deals alone, delivery % alone, FII/DII, MACD /
stochastics / Fibonacci / Ichimoku, minute-RSI reversals, generic AI sentiment scores, news counts / buzz, broker targets and
upgrades, social / Telegram rumour alone, a broker's "IV percentile" of unknown method, option LTP % change vs yesterday, LTP-based IV.
