# BUILD PLAN - the new girtrader.com (data -> decision engine -> pages)

For the Claude session running ON the GIR server (/home/globalbot/intraday). Written 19 Nov 2026.

The trader, 19 Nov: **"It's not only the tab. It's the information which gets updated and the information collected to decide
which F&O option to buy."** So the new girtrader.com is built in three layers, in this order, and no layer is skipped:

    LAYER 1  DATA        collected, timestamped twice, checked, recorded       (section 1)
    LAYER 2  DECISION    the trader's method turned into code + a little AI    (section 2)
    LAYER 3  PAGES       23 pages + the shell, every box fed by layers 1 and 2 (section 3)

The trader buys NSE stock options (CE / PE) intraday, sector-first, holds a few hours, exits by 15:10. Every feed, every rule and
every box below exists to answer one question: **which F&O share, which side, which strike, now, and when to get out.**

**Source files (read them; where they say more than this plan, they win, in this order):**

| File (in the trader's repo, branch ccr-67e340f1-sko8xd) | What it settles |
|---|---|
| intraday_patches/GIR_SPEC.md | the single source of truth: TRIAL, CHECKLIST A-I, THE PLAN (B1-B9), DATA LIST #1-#49, E1-E6, S1-S12, sections 0-8 |
| intraday_patches/design_v3/REQUIREMENTS.md | R01-R49, the page list and keys |
| intraday_patches/design_v3/CONFERENCE.md | the binding design agreement: type sizes, colours, the page-by-ID table (1.6), the illustrative day (section 4) |
| intraday_patches/design_v3/SHELL.md + shell html | the three shared bands (market strip, P&L strip, tab bar) and the footer |
| intraday_patches/design_v3/<slug>_final*.html (else the newest <slug>_v3r*.html) | the drawing of each page - build each box exactly as drawn |
| intraday_patches/design_v3/COLLECTION_PLAN.md, SHARE_DOSSIER_AND_MACRO.md, DATA.md, IA.md | jobs J01-J85, recorders R1-R25, data items D1-D76, page links and keys |
| intraday_patches/LAYOUT.md, EARLY_TEAM.md, complaints_18nov.md | old features that must survive; the 46 complaints (each must be answered by the build) |

The drawings use the illustrative day of CONFERENCE section 4 (Thu 19 Nov, states S1-S5). On the server every value comes from
live or recorded data - **never copy a number from a drawing into code.**

---------------------------------------------------------------------------------------------------------------------------------

## 0. HOW TO WORK

### 0.6 The trader's directions, 19 Nov (these win over anything below)
- **Kite is the market-data feed - no second broker account** (no Upstox / Angel / Shoonya / Dhan feed). **Paid data and services
  ARE allowed and expected** - the trader: "I am ready to pay. Without paying you get nothing." Buy what gives speed and depth from
  outside: paid news / wire access and subscriptions (Economic Times / ET Prime, Business Standard, Moneycontrol Pro or similar),
  X API credits, live TV speech-to-text, an economic calendar with consensus, results consensus, expired-option and IV history,
  corporate data (shareholding, pledges, deals) where free sources are slow. For each paid item: what it gives, cost per month,
  and the trader's yes before buying (list them in the first evening report). F07 (a second broker feed) and F18 (spare-phone
  Telegram listener) stay out unless he asks; F08 NSE chain check stays as a sanity check.
- **He trades OPTIONS (~90%).** Futures are never suggested as a trade. Futures data (build-up, OI by month) is used only as a
  signal for the option call. Every call, page and message speaks in options: strike, premium, spread, stop / target in premium
  and share price.
- **News he cannot watch himself must reach him:** everything CNBC-TV18 says, continuously (live speech-to-text from the free
  official stream) and the Economic Times (website, live blog, markets pages - with a paid subscription for full access), plus Moneycontrol, Business
  Standard, NDTV Profit and ET Now - paid subscriptions where they give full or faster access.
- **The analyst must KNOW, like a senior F&O broker** - and say it WELL IN ADVANCE: for each F&O share (business, drivers, peers,
  group, results, how it reacts to each kind of news), for each sector (what moves it, how it reacts to each driver and event), and
  for NIFTY / BANKNIFTY / FINNIFTY (which sectors and heavyweights move the index, by how much). Built as the KNOWLEDGE BASE (1.7)
  and used by the 19:45 / 07:15 notes and every live call: "if X happens, these sectors and shares move this way, NIFTY by about Y".
- **Information is wealth:** the earlier he knows, the better - every news item, filing, TV statement and driver move must be
  mapped to shares, sectors and the index within seconds, and reach him only when it matters (one sound, no noise).
- A perfect web page AND a perfect phone app.

### 0.1 Start now, on /preview, without touching the live system

| Rule | What it means in practice |
|---|---|
| Build on **girtrader.com/preview**, starting IMMEDIATELY | New code lives in `/home/globalbot/intraday/v2/` (new folder). A new service `gir-preview` serves it on its own port (pick a free one with `ss -ltn`, e.g. 8100). It READS the live data files; it never writes to a file a live service writes. |
| Until 15:35 today, reach /preview by an SSH tunnel to that port | Adding the `/preview` path to girtrader.com needs one change to gir-dash (dashserve.py route or the web-server proxy) - do it after 15:35, with a backup and an undo line. Same login as the live page; `noindex`, robots disallow. |
| **09:00-15:35 on weekdays: never restart or change a live service or the live page** | Live = gir-dash, gir-analyst, gir-newsroom, gir-seclive, gir-intraday, gir-policymap, gir-ready, gir-overnight, gir-crosscheck, every gir-* unit and every timer. In market hours you may: read files, write NEW files under v2/, run read-only tests and replays, start / restart gir-preview and other NEW v2 services that only read. |
| Live restarts only after 15:35 (or at the weekend) | Each change to a live file: `cp file file.bak<YYYYMMDD-HHMM>` first, then the change, then a test, then ONE undo line printed and logged. |
| **Nothing is deleted** | The current page moves to **girtrader.com/old** at switch-on and stays there. Old files, services, data and backups stay. A replaced service is stopped and disabled, never removed. |
| **Switch-on only by the trader** | /preview replaces the live page only when the trader writes "switch on". Before that, show him: the old-feature table (section 3.24), the test results (section 4), screenshots at 1600x900, 1366x768 and 390 wide. |
| Shadow mode until switch-on | The new decision engine (layer 2) runs alongside the old one, writes its calls to `v2/data/calls.jsonl`, and is scored in the 15:45 audit side by side with the old analyst. It sends **nothing** to Telegram and rings nothing on the live page. /preview opens with sound OFF (so the trader never hears two alarms); he can turn it on. |
| Trial week (from 19 Nov) | The live page does not change during the trial. /preview is a separate address, so building it is allowed; fixes that make the live analyst name the right shares earlier may still go live after 15:35. |

### 0.2 Standing rules (unchanged, never broken)

- Never use TG_CHAT_FO or TG_CHAT_OI. Decisions go only to the one decisions channel; system alerts only to the system bot.
- Never print, log, copy, paste or commit `/home/globalbot/.env` or any value in it. Read keys by VARIABLE NAME only. A report may
  list variable NAMES, never values. The site password is never shown or sent anywhere.
- Do not touch gir-watchdog or paper_exit_monitor (an open decision for the trader - remind, do not act).
- No made-up data. If GIR does not know, the box says "not known" / "missing since HH:MM" in grey. No call from stale data.
- AI cap **$20 / day**, enforced in code BEFORE each call (section 2.12). The new engine's AI spend counts inside the same $20.
- F&O shares only for calls; sector measures use ALL listed shares (GIR_SPEC 1.2, R49).
- GIR never places orders. Kite login stays manual for all four keys.
- When the trader asks a question, answer it first, each part separately, before more work.

### 0.3 Every step is logged the same way

Keep `v2/BUILD_LOG.md` on the server (a checklist, not a report to anyone else): step id -> done / not done -> files changed ->
test output or screenshot path -> the undo line. Never write "complete" for a step whose test has not passed. If a step cannot be
done, write why. Undo line format, always one line:
`undo: systemctl stop gir-preview; cp /home/globalbot/intraday/dashserve.py.bak20261119-1540 /home/globalbot/intraday/dashserve.py; systemctl restart gir-dash`

### 0.4 Evening report (every day, after 18:00, to the trader)

Plain words, short: what was built today (step ids), what was tested and the result, what is live in shadow, what is blocked
and why, tomorrow's steps, AI spend today. Screenshots of /preview pages finished today. Nothing else.

### 0.5 Architecture of v2
Feeds -> v2 collectors (one writer per fact, a heartbeat row per run) -> live state in memory + minute files (no SQL in market hours)
-> v2 engine (plain code, < 50 ms per tick batch) -> AI gateway (only holder of the AI keys, budget checked first) -> calls store
(immutable, timestamped) -> ONE Server-Sent-Events stream (sequence numbers, snapshot on reconnect) -> ONE store in the page -> 23
pages. The websocket callback only queues raw frames; the page updates only changed numbers, once per animation frame; ONE
SoundPlayer. At first v2 may READ the live outputs (data/seclive.json, data/analyst.json, data/ban.json ...) through adapters that add
the two clocks; each adapter is later replaced by its v2 collector, one feed at a time.

---------------------------------------------------------------------------------------------------------------------------------

## 1. LAYER 1 - DATA: collection and freshness

### 1.1 Freshness: two clocks on every number (fix the C4 bug first)

A number is FRESH only if **both** clocks agree:
- **Clock 1 - source time:** the timestamp inside the data (Kite exchange_timestamp, filing `an_dt`, RSS pubDate, Yahoo
  regularMarketTime, LME date, file content date) is inside the feed's limit.
- **Clock 2 - still changing:** the value hash changed vs the previous good fetch; price AND volume unchanged 60 s on a liquid
  instrument in market hours = STALE even if the process is alive.

**The C4 bug:** `crosscheck.py` C4 / C8 (and `gir/watchdog.py log_stale_min`) judge age by `os.path.getmtime` - a file rewritten
with old data looks fresh; a quiet but correct file looks stale. Fix: judge by clock 1 + clock 2; keep mtime only as "writer
alive". An aggregate (a sector, a call) is as old as its OLDEST input.

Every collector writes one heartbeat row per run: `{job, source, src_ts, fetched_at, value_hash, rows, checks_failed, error}`.
A 60-s checker judges each row against limits that change with the clock. States: LIVE · LATE · STALE · QUIET (illiquid strike on a
healthy connection) · SUSPECT (range check failed) · CONFLICT (two sources > 2 ticks or 0.3% for > 5 s) · INCOMPLETE (sector with
< 90% of its weight LIVE - cannot CONFIRM) · CLOSED (market shut - last value with its time, never shown as live).

| Family | LIVE | STALE (blocks dependent calls) |
|---|---|---|
| Feed sentinels (2-3 liquid tokens per connection) | < 2 s | > 5 s (reconnect at > 3 s silent) |
| Share / strike in a call or open position | quote age <= 2 s | > 5 s ("GO NOW disabled - STALE 8s"); held + both paths > 5 s = P1 |
| Other share / future quote · other option quote | <= 3 s · <= 5 s | > 10 s · > 15 s |
| Futures / option OI | <= 3 min | > 6 min (build-up tags grey after 5 min) |
| Sector / breadth aggregate | >= 90% of weight LIVE | < 90% = INCOMPLETE |
| Positions / orders sync | <= 10 s | > 30 s (> 10 s with a position open = P1) |
| Filings / news sources | items vs the usual rate for that hour | zero items in 10 min at 11:00 = BROKEN, not quiet |
| World drivers | per source cadence, session-aware | CLOSED is not STALE; DELAYED / DAILY labelled |
| Reference files | content date = today | any other date = RED, dependants blocked |
| /status.json (health page) | <= 120 s | > 120 s the page turns red |

### 1.2 The feeds and jobs (F01-F31) - every one with source, timing, use, freshness, failover, status

"Exists?" = what the repo's install scripts suggest; **verify on the server** before relying on it (list the running units with
`systemctl list-units 'gir-*'` and the files each writes). Step codes: N19 = 19:45 note, N07 = 07:15 note, U08 = 08:45 update,
P09 = 09:08 pre-open, C09 = sector confirmation from 09:20, SP = share pick, OG = option gate, HX = hold / exit, SC = 15:45 audit.
J- and R- numbers are COLLECTION_PLAN's jobs and recorders.

| ID | Feed / job | Source -> backup | Market hours (09:00-15:30) | Outside | Feeds (engine step -> pages) | Freshness check | Failover | Exists? |
|---|---|---|---|---|---|---|---|---|
| F01 | **K1 underlyings**: 218 F&O shares (EQ) + stock futures near / next / far (654) + index futures | Kite WS key 1, FULL mode | ticks ~1/s per instrument | closed | E3-E10 -> every page | exchange_timestamp + frozen 60 s; sentinels per connection | K4 takeover < 5 s; Upstox per instrument (source = U) | partly (gir-intraday / gir-futlive) - verify keys, modes, months |
| F02 | **K1 C3 drivers**: all NSE indices + VIX, MCX ~40 contracts, CDS ~14, NSEIX GIFT NIFTY (J08, J09, J71) | Kite WS key 1 | live from 09:00 | MCX to 23:55, CDS to 17:00, GIFT nearly 24 h | E1, E11 (in-session commodity lag, shock freeze) -> strip, World, Morning | T + C per contract; witness vs Yahoo / LME | Yahoo delayed (labelled, never an in-session trigger) | NO (MCX / CDS paid but not subscribed) - build |
| F03 | **Whole-sector baskets**: every listed share of every mapped sector, cash quotes (price, volume, VWAP) | Kite WS (FULL, for exchange time) on spare K1 / K4 capacity; overflow via K4 REST `/quote` sweep every 10-15 s | live | closed | E3 sector %, weight, breadth, rank (R49) -> Sectors, Desk, Rotation, Morning | per-member clock 1; sector = INCOMPLETE if < 90% weight LIVE | REST sweep; official NSE index tick for indexed sectors | partly: seclive.py (patch 354) already builds sectors from all shares - verify its source and reuse its basket lists |
| F04 | **K2 option strikes in play**: watch list (up to 50 shares) ATM +-5 CE + PE this expiry + next ATM +-2; held strikes + ATM +-10; next candidates | Kite WS key 2, **FULL with depth** | live | closed | E7 strike chooser, E10 follow-ups -> Plan card, Desk, Positions, Chain | exchange_timestamp; bid <= ask; IV 5-200% | K4 duplicate of held / called strikes | verify (likely quote mode today) |
| F05 | **K3 full chains**: ATM +-5 this expiry for all F&O shares (two connections); ATM +-6..8 + next month for the 60 most liquid; expiry week: next month ATM +-2 for all | Kite WS key 3 FULL + REST `/quote` OI sweep every 2 min | live | closed | E7, OI walls, S6 activity -> Chain, Futures & OI | OI <= 3 min; strike QUIET is not stale | REST sweep; Upstox chain | build |
| F06 | **K4 hot standby + REST**: empty C1 (takes any stalled list), sentinels C2, LTP dead-token sweep (~10 s per pass), positions / orders every 5 s, `/charges/orders`, `/margins/basket`, historical, token checks | Kite key 4 | live | historical + reconciliation after 15:35 | health, E9 cash / charges, J03 candles | sweep last_trade_time vs socket's last tick | - | build |
| F07 | **Second feed**: shares + current futures + ~20 sector indices (ltpc), watch-list ATM +-2 greeks, held strikes full; REST chain every 3 min | Upstox analytics token (needs an account in the trader's name - his decision) -> Angel / Shoonya | live | - | CONFLICT check, IV cross-check | > 3 s older than Kite on a liquid token -> Kite marked stale | - | NO - weeks 2-4 |
| F08 | NSE option-chain cross-check (J79) | NSE JSON (one symbol per >= 4 s, cookie warm-up) -> Upstox chain | 09:30 / 12:00 / 14:30 watch list; held underlying every 3 min | - | trust of GIR's IV (E7) -> Health | NSE time <= 3 min; OI within one update; IV +-2 vol pts | stop on 403 / 429, log, never evade | build |
| F09 | Pre-open (J72): cash IEP for F&O shares, futures pre-open, buy / sell imbalance | Kite FULL / `/quote` -> NSE pre-open JSON | 09:00-09:08 every 30 s; finals 09:08:30, 09:12:30 | - | E2 09:08 check -> Morning pre-open view, Desk | exchange time 09:00-09:08; >= 200 shares | NSE JSON | partly (gir-preopen) - verify it is recorded (R5) |
| F10 | Positions, orders, fills, funds (J04, J85) | Kite K4 REST every 5 s + order postback | live | 15:31 final + charges | E9 lock, E10 follow-ups -> P&L strip, Positions, Journal | <= 10 s | second key | partly (gir-pnlwatch) - verify |
| F11 | Reference: instrument dump (all segments), NSE contract file, lots, expiry calendar (contract master decides - Nov = Mon 23 Nov if Tue 24 is a holiday), holidays, corporate actions, symbol changes (J61-J64) | Kite instruments + nsearchives | refresh 08:00-08:45 | evening reconcile 20:00 (J35) | E0 day gate -> strip expiry, Reference, Calendar | content date = today; Kite vs NSE mismatch blocks that share | yesterday's list for underlyings only; options blocked if lot / expiry unconfirmed | partly - verify; recording forever (R4) is new |
| F12 | Ban list (T+1), combined OI / MWPL (2025 FutEq rules), live MWPL estimate every 5 min (J17, J18, J80) | nsearchives -> GIR estimate | estimate every 5 min | 18:00-20:30 every 10 min | E0 / E7 gate (ban = hard block; >= 85% warning) -> BAN pill, Plan card | file date = T+1 | if T+1 ban file missing at 08:45: block NEW calls on shares >= 80% MWPL yesterday | partly (data/ban.json) - verify date check |
| F13 | EOD files: index closes, CM / FO bhavcopy (UDiFF), deals, FII / DII, delivery, participant OI, FII stats, FOVOLT (J12-J16, J19-J22) | nsearchives -> Kite closes (labelled UNOFFICIAL) | - | 16:30-21:00, every 10 min until present | N19, start-of-day OI, IV back-fill -> strip FII / DII, Futures & OI | D / N / S checks; never "assume none" | retry to 21:00 then 07:00 | partly - verify |
| F14 | Nightly derived history (J38): ATR14, prev-day / 20-day H/L, RVOL baselines per minute of day, sector betas, IV rank; expired-option seeding (J39, paid item - trader's decision) | own store + Kite historical on K4 | - | 22:00-23:30 | E4 zone / room, E6 rank, E7 IV rank | N = every F&O share | - | partly (histstore.py) - verify |
| F15 | **NSE + BSE filings every 3-5 s** (J60), offset so one exchange is hit every ~2 s; attachments (PDF / XBRL) fetched at once for weight >= 3 | NSE announcements JSON + BSE API -> both RSS | 3-5 s | 10-15 s to 23:00, 60 s night, 15 s from 06:30, 60 s weekends | E12 news, own-news check (D7) -> News, call "why" lines | item rate vs hour; HTML / captcha = ERROR | RSS; P1 if both silent > 10 min in session | partly (gir-exchange?) - verify speed (today ~3 min late) |
| F16 | Wires and publishers: Reuters news sitemap every 15-20 s; ET, Moneycontrol, CNBC-TV18, Business Standard, NDTV Profit sitemaps every 20-30 s; **today's live blogs every 15-30 s** (J55 finds the URLs at 07:00); second-tier RSS 60-120 s; Google News only as 15-min backfill (out of the alert path) | publishers -> RSS | as listed | 20 s-2 min | E12 -> News | E / N per source | RSS; Telegram / phone push | partly (gir-newsroom, gir-newshunt) - remove dead Reuters RSS and Nitter (code issue e) |
| F17 | **TV / live speech-to-text**: CNBC-TV18, ET Now (+ CNBC Awaaz, BT TV), Sansad TV Lok Sabha / Rajya Sabha, PIB / DD News / ministry briefings, RBI / SEBI pressers, live event speeches (e.g. WFE meeting, exchange and regulator heads) via the official streams; keyword triggers; transcript snippets only | official live streams (or capture of the trader's own set-top box) | live | 07:00-19:00 for business TV; Parliament while sitting | E12 (management statements, "sources say", denials) -> News TV rows, call why line | chunk times moving, audio level > 0, transcript not repeating | live blogs (same desk, +1-10 min) | partly (gir-tvwatch: one channel) - extend |
| F18 | Push sources: Telegram listener on outlets' / journalists' public channels; spare-phone notification mirror | Telegram client API; phone | push 1-3 s | push | E12 -> News | heartbeat every 60 s; silent > 3 min = P2 | polled sources | NO - weeks 2-4 (phone + SIM = trader's decision) |
| F19 | X lists (journalists, regulators, PIB, TV reporters) | X API | OFF until credits (trader's decision) | - | E12 | - | TV STT + wires | NO |
| F20 | **Regulator / Parliament / NPCI watchers (S12)**: IRDAI, CERC, SEBI, RBI, TRAI, CCI, PFRDA, CDSCO, NPPA, FSSAI, DGCA, DGFT, DGTR, CBIC, **NPCI circulars**, sansad.in bills + business of the day, e-Gazette, PIB releases; SEBI / RBI / PIB RSS 60 s | official sites (change detection) -> wires | **every 1-2 min** (RSS 60 s) | every 15 min to 01:00, then 60 min | E12 policy shock; policy pipeline -> News POLICY, Calendar, Morning | page hash + parse; E / N checks | wires; trader's X lists by hand | partly (gir-govwatch, gir-policymap) - today ~15 min: speed up |
| F21 | Day policy watch list (07:00) + policy pipeline (PENDING -> ANNOUNCED -> NOTIFIED): bills listed today, open consultation papers, regulator board meetings, court hearings (J30), each -> F&O shares + direction | F20 + sansad.in + cause lists | refresh 07:00, 12:00 | 17:00-23:00 evening releases (J25) | E12, N19 / N07 -> Calendar, Morning | dated today | - | build |
| F22 | Calendars: economic with consensus (J28), event actuals + surprise score (J10, J27, J52, J81), results / board meetings (J31), risk strip at 08:30 (J65) | ForexFactory JSON + official calendars; NSE / BSE board meetings | in-session releases polled 15 s around the minute | 18:00, 21:00, 19:35 | E0 event locks, E7 IV-crush / results gate -> Calendar, Morning, strip | file updated today; > 30 events / week | Nasdaq calendar; official pages | NO (hand-edited econ_events.json - code issue h) - build |
| F23 | **World drivers**: snapshots W1945 / W0245 / W0700 / W0845 / W0900 (J29, J45, J53, J68, J71), 5-min overnight series (J34), settlements (J44), LME official (J23), China futures day + night (J24, J50), CNY fix (J51), Asia (J48); every move "vs a named reference, as of time", two witnesses | Yahoo -> Stooq / CNBC quote; MCX / CDS live; Westmetall; Sina / AKShare | MCX / CDS / GIFT live (F02); China every 60 s | per snapshot / 5 min | E1 drivers -> World, Morning, strip | T (market time), C, K (same contract), witness diff > 0.5% flagged | per source chain | partly (morningmkts.py, overnight.py) - fix code issues b, c, d, g (wrong copper / aluminium proxies, roll glitches, ^NSEI as GIFT) |
| F24 | Industry recorders: VAHAN month-to-date (before 1 Dec auto sales), MoCA, Grid-India, CEA coal, IEX DAM, fuel prices on the 1st | official pages, gently | IEX ~13:00 | nightly / 07:00 | E2 (1st-of-month surprise) -> Calendar | dated | - | NO - VAHAN first |
| F25 | **Minute aggregates** (J76): bars, VWAP, opening range, breadth, equal-weight vs index, RS vs sector and NIFTY, RVOL, futures OI all months + build-up LB / SB / SC / LU, range used / ATR, room to next level | computed from F01-F05 in memory every tick; written per minute | live | Parquet after 15:35 | E3-E10 | every share updated in the last 2 min; GIR sector % vs official index +-0.3% | - | partly (seclive, secmoney, futlive) - verify; rebuild in v2 engine |
| F26 | **Option metrics per strike** (J77, J78): mid, spread %, depth best 5, IV and greeks by Black-76 on the same-expiry future, trading minutes, from bid / ask / mid (never LTP); ATM IV per share each minute; spread snapshots 09:30 / 12:00 / 14:30 | computed from F04 / F05 | every minute | daily ATM IV close | E7, E10 -> Chain, Plan card, Share | R checks; vs Upstox / NSE IV | - | NO - build (Kite gives no IV) |
| F27 | **Basket-shock detector** (data side of S12): 3+ shares of one policy basket moving the same way 1%+ inside 60 s on a volume burst | computed on ticks of F01 / F03, in memory | live, target alarm <= 10 s after the 3rd share crosses | - | E12 -> Sectors, Rotation, News, Analyst, Desk alert | depends on F01 sentinels | - | NO - build |
| F28 | Health: heartbeat checker (60 s), safe mode flag, 08:45 pre-flight (4 Kite tokens, clock, disk, instruments, AI budget, test alert), 09:00 self-test, outside dead-man ping, /status page, Kite token checks from 08:00 | own | 60 s | 08:45, 16:30 reports | all -> Health, footer, every freshness dot | - | P1 phone call / P2 system bot | partly (gir-crosscheck, gir-watchdog - do not touch watchdog) - build v2 checker |
| F29 | AI log + spend: every call with prompt, output, tier, tokens incl. cache reads, cost, latency, validator result, outcome | AI gateway | per call | per call | E13 -> P&L strip AI meter, Scorecard, Health | - | - | partly - verify where the 18 Nov $27 overspend escaped the cap |
| F30 | Raw recorder: every websocket frame with receive time (all keys), every HTTP body that changed, every news item with first-seen time per source, every SSE event, alert and AI call | writer thread off the live path | live | zstd after 15:35; 90 days ticks on server, db forever | replay (section 4) | frames per connection vs norm | drop to underlyings + held strikes if behind | partly - verify |
| F31 | Journal, plan cards, paper twin of every GO NOW / triggered GET READY, price 30 min after exit, P&L split | own | per trade | 16:00 build | E15 -> Journal, Scorecard, Positions | - | - | partly - build in v2 |

### 1.3 The four Kite keys (S9) - who carries what

Every token in **FULL mode** (Kite's quote mode carries no OI, no bid / ask and no exchange timestamp - the option gate would be
blind). After EVERY reconnect: resubscribe the connection's list AND set FULL again, and log both. Keep each connection under
~2,500 tokens. Check Zerodha's current terms for four apps on one account before relying on all four; if a use is not allowed,
drop to what is allowed and move K3's far strikes to the REST sweep.

| Key | Role | C1 | C2 | C3 |
|---|---|---|---|---|
| K1 | underlyings + drivers | 218 F&O shares + whole-sector basket members (non-F&O, as many as fit; rest by K4 REST) | stock futures, 3 months (654) + 12 index futures | all NSE indices + VIX, MCX, CDS, NSEIX GIFT |
| K2 | options in play, FULL with depth | watch-list ATM +-5 this expiry + next ATM +-2 | held strikes + ATM +-10 of held underlyings + next candidates | sentinels mirror (3 from each other connection) + held strikes again |
| K3 | full chains, FULL | ATM +-5 for shares 1-109 | ATM +-5 for shares 110-218 | extra strikes / next month (expiry week: next month ATM +-2 for all) + re-centring buffer |
| K4 | hot standby + all REST | empty: takes over any stalled list in < 5 s | sentinels for K1-K3 | empty: second standby |

Stall detection: a sentinel silent > 3 s in 09:15-15:30 -> reconnect that connection; not back in 10 s -> K4 takes the list. Re-centre
strikes when spot moves half a strike: subscribe the new ones first, set FULL, unsubscribe the old after their first tick. An
"invalid token" is a P2 alert. Every key needs its own manual daily login; the 08:40 pre-flight rings the trader if any key is not
logged in.

### 1.4 Whole-sector baskets (GIR_SPEC 1.2, R49 - the trader's override, 19 Nov)

- **One basket file** for every sector, theme and policy basket (sectors, theme baskets such as PSU defence, rail, power
  financiers, Adani, Tata; the S12 policy baskets). Versioned with effective dates; refreshed the first Saturday of each month and
  on every NSE index change. Start from seclive.py's lists (verify) and niftyindices constituent files.
- **Where an official NSE sectoral / thematic index exists** (NIFTY METAL, PHARMA, PSU BANK, IT, AUTO, REALTY, FMCG, ENERGY, MEDIA,
  CAPITAL MARKETS ...): sector % = the index tick; breadth and the "one share = X% of the move" warning use its constituents and
  their official free-float weights.
- **Where none exists** (jewellers, gold loans, cables & wires, brokers ...): a free-float market-cap weighted basket of ALL listed
  shares in that sector from cash quotes (non-F&O names need only price, volume and time). Free-float weight = shares outstanding x
  free-float factor (from the latest shareholding pattern) x price; refreshed quarterly, price live.
- Breadth is shown both ways: "all shares 11 / 14 · F&O 3 / 4". Label the basis on every page: "NIFTY METAL index" or
  "all 14 listed jewellers, free-float weighted". A move made only by the F&O names while the rest is flat = **NARROW - F&O-only
  move**, never CONFIRMED. Only the TRADE list is limited to F&O shares.
- The final Sectors drawing labels the basis ("all 14 listed · free-float") and the NARROW flag; older drawings that say "% =
  equal-weight" are superseded. Keep the equal-weight figure beside the weighted % (checklist C3: the heavyweight trap).

### 1.5 Record from today (no free history exists - every day not recorded is lost)

Start these in the first days, before any page work, writing to new files only: R1 ATM IV per share every minute + daily close;
R2 per-strike IV / spread / depth + 09:30 / 12:00 / 14:30 snapshots; R3 raw frames of every key; R4 every day's instrument dump and
NSE contract file (kept forever); R5 pre-open series; R6 GIFT minute series; R7 world snapshots with named references; R8 MCX / CDS /
China minute series; R9 futures OI all months per minute; R10 per-source news delay (published, first-seen per source, move began);
R11 every news item with first-seen time; R12 economic consensus the night before + actual; R13 results consensus per company (from
the next season); R14 board-meeting time vs filing time; R15 VAHAN month-to-date; R16-R18 MoCA, Grid-India, CEA coal, IEX DAM;
R19 live MWPL estimate; R20 NSE chain snapshots; R21 block-deal windows; R22 Kite vs NSE mismatches and incidents; R23 TV
transcript snippets; R24 FedWatch and US 2y twice a day; R25 every AI call. Plus **whole-sector basket minute series** (new) and
**every basket-shock / rotation alarm, fired and failed** (new).

### 1.6 Failure playbook (short; COLLECTION_PLAN section 5 has the full table)

Safe mode = one global flag: affected values grey "STALE since HH:MM", no new calls; open positions keep their stops (exits are
never blocked). P1 = system bot + phone call, repeat every 5 min until acknowledged; P2 = system bot; P3 = daily digest; always a
"recovered" message. One Kite connection stalls -> reconnect, then K4. A key logged out -> its lists to K4, P1 to the trader. All of
Kite down -> no new calls, positions from the second feed, trade from the broker app. NSE JSON blocked -> BSE + RSS, cool down,
never evade. Ban file missing at 08:45 -> block new calls on yesterday's >= 80% MWPL names. AI down -> "AI unavailable"; code rules
keep running.

---------------------------------------------------------------------------------------------------------------------------------

### 1.7 The KNOWLEDGE BASE - what the senior analyst knows (built this week, kept up to date)
| Part | What it holds | Source (paid where better / own) | Used by |
|---|---|---|---|
| Share dossier (every F&O share) | business, segments, group, peers, drivers with sensitivity (e.g. gold -1% -> MANAPPURAM about -x%), results dates and history of reactions, promoter / pledge / big holders, typical day range, beta to sector and NIFTY, other names / aliases | NSE / BSE filings and shareholding, annual reports, own price history, SHARE_DOSSIER_AND_MACRO.md | every call, Share page, notes |
| Sector map (every sector) | members (ALL listed shares, weights), drivers and how each moves the sector, event -> reaction table (rate cut, crude +5%, rupee, duty change, regulator order ...), lead / lag between members | own history (replays), NSE indices, GIR_SPEC 1.1 | E2-E6, Sectors, Rotation, World |
| Index map | NIFTY / BANKNIFTY / FINNIFTY / MIDCPNIFTY weights, each sector's and heavyweight's contribution in points, how each driver moves the index | NSE index factsheets, own minute data | strip, Market page, notes ("NIFTY about -0.4% if ...") |
| Event playbook | every past event type with what moved, how much, how fast (MCX margins, bulk Scotch duty, NPCI, SEBI MTF, IRDAI caps, CERC coupling, results, RBI ...) - the regression tests of E12 | replays of recorded days, news archive | E12 direction check, notes, Calendar |
**Both sides of every driver (19 Nov lesson):** a driver move has LOSERS and WINNERS. Copper / aluminium slumping overnight is PE
for cables and metals (POLYCAB, KEI, HINDALCO, VEDL) AND CE for the users of those metals - autos (MARUTI +6%, ASHOKLEY +9%, TVSMOTOR,
HEROMOTOCO, M&M, EICHERMOT up 3-5%, NIFTY AUTO +3% on 19 Nov), consumer durables, cable users. Same for crude (OMCs, paints, tyres,
aviation win when it falls), the rupee (IT wins when it weakens), gold (jewellers' margins vs gold-loan books). The sector map holds
the beneficiary side for every driver, and the 07:15 note lists both: "copper -1.8%: PE cables / metals · CE autos".
**Tell him THE EVENING BEFORE (the trader, 19 Nov: "this information I needed from the desk yesterday").** On 18 Nov metals
fell all day; the 19:45 note on 18 Nov had to say: "Metals down (copper, aluminium, steel) = lower input cost for automakers ->
TOMORROW: CE watch on autos - MARUTI, HEROMOTOCO, TVSMOTOR, M&M, ASHOKLEY, EICHERMOT (leader / laggard, strikes, triggers);
PE watch on cables / metals". Every evening the SECOND-ORDER analyst (a role in E2, not optional) runs every driver that moved
today through both sides of the sector map (losers AND winners) and writes "TOMORROW'S OPTION WATCH" with CE and PE lists, the
strike, the trigger and the reason, confirmed or cancelled by the 07:15 update and the 09:08 pre-open. A move GIR explains only
after it happened counts as a MISS in the 15:45 audit.
**The history database (the trader, 19 Nov: "collect all the database - how the market behaved for 5, 10 years").** Build a
10-year (at least 5-year) daily history for every F&O share, every sector index and basket, NIFTY / BANKNIFTY, and every driver
(LME / COMEX / MCX metals, crude, gold, silver, USD/INR, DXY, US 10y, US indices, China futures), plus futures OI where available,
results dates and reactions, policy and event dates. Kite historical first; buy what Kite lacks (older OI, expired options / IV
history, global series, a news archive) with the trader's yes per item. From it the knowledge base learns, for every chain:
how often it followed through next day and next week, the typical size and lag, and what made it fail - and every evening note
quotes the closest past analogue ("like 12 Mar 2024: copper -4%, autos +2.1% next day, followed through 7 of 9 times").
**TV analyst calls move prices (the trader, 19 Nov):** PAYTM was falling (~1,700) when an analyst on CNBC-TV18 said "this is the
best price to start buying"; the fall stopped at once and the share turned up. The TV speech-to-text (F17) must catch every
buy / sell / target / "accumulate" / "avoid" call on an F&O share and act within 30 s: (1) if the trader HOLDS the other side
(here a PAYTM PE) -> HIGH alert "TV BUY call on PAYTM at ~1,700 - bounce risk: book or trail now"; (2) if a falling share
gets a TV buy call -> "watch for a bounce: PE GO NOW cancelled"; (3) every TV analyst is scored: how often the share moved
their way in the next 30 min / day, so a call from a high-hit-rate voice weighs more. Replay test: 19 Nov PAYTM TV call ->
GIR alert within 30 s of the words.
Updated nightly from the day's recording; every call quotes the knowledge it used ("why: gold -1.6%, MANAPPURAM beta 1.3 to gold").
**SECTOR LINKS - binding spec in design_v3/SECTOR_LINKS.md; links used only when proven on the history database.** It holds the
sector-to-sector table (L01-L17), the sector-to-driver table, the proof rule (at least 30 events, hit rate at least 58% and 8 points
above normal, holds in both halves and the last 2 years, proof line quoted on the call), the 19:45 TOMORROW'S OPTION WATCH format
(unproven links shown as "IDEA - NOT PROVEN", confirmed live at the open) and replay tests E1-E5 (18 -> 19 Nov metals -> autos first).
**CHAIN-OF-EVENTS ENGINE - binding spec in design_v3/CHAIN_OF_EVENTS.md; the 18 -> 19 Nov autos CE replay must pass before
Monday.** It adds step E2b (the second-order analyst): every evening each driver past threshold (1-day or 3/5-day), each NSE sector
that moved 1.5%+ and each "driver moved, users not yet reacted" gap runs through both sides of the chain map, is graded (WEAK /
MEDIUM / STRONG) and goes out as TOMORROW'S OPTION WATCH at 19:45 (CE / PE lists, Dec-or-current strike per E7, trigger, cancel),
re-checked at 22:45 (only if the grade changes), 07:15 and 09:08 (STANDS / CHANGED / CANCELLED); every chain fired or missed is
logged and its hit rate quoted. Also fix test 4.1: MOTHERSON is an auto-parts maker (copper = cost), not a metals PE.
MISSING KNOWLEDGE - the desk's own gap list, built in with the rest: design_v3/MISSING_KNOWLEDGE.md.
LINK BOOK - every driver and sector, both sides: design_v3/LINK_BOOK.md (to be proven on the history database).
POLITICAL AND ELECTION CYCLE - design_v3/POLITICAL_CYCLE.md: policy delays and pre-election measures as chains, with the election calendar in the Calendar page.

## 2. LAYER 2 - THE DECISION ENGINE

The trader's method, in his words: *"It's sector-driven. Find which sector goes up or down from the macro, Indian and market news,
study every share in it, pick the ones in position, tell me GO NOW, and give it time."* The engine is **plain code first** (fast,
free, testable); AI reads news and confirms or vetoes, never sits on the critical path. Every step logs its inputs with their ages,
so any call can be replayed exactly. Steps E0-E15:

### E0. Gate the day (19:45, 08:45, live)
Allowed universe = F&O list from today's files (F11) minus ban (hard block) minus Kite-vs-NSE mismatches; >= 85% MWPL = warning;
event locks from F22 (RBI, Budget, results within one session, counting day; in-session release: lock the sector 10 min before to
15 min after); health RED at 08:45 = read-only session; expiry-week mode (next month default, physical settlement warning on
in-the-money stock options, exit before expiry day).

### E1. Drivers (19:45, 07:15, 08:45, 09:00, live)
From F02 / F23. Checklist A thresholds: Brent +-2% (3% strong) · LME copper / aluminium +-2%, zinc 1.5%, silver 3% · Dalian iron ore
+-3% · gold +-1.5% · Nasdaq +-1.5%, ADR +-2%, SOX for electronics · India 10y +-10 bp · USD/INR +-0.3%, DXY +-0.5% · GIFT +-0.5% ·
SEBI / RBI circulars, USFDA, geopolitics, monthly auto sales = events. Each move stated "vs <named reference>, as of <time>", two
witnesses within 0.5%. Re-check commodities at 09:00 (they often reverse in Asian hours). In session: an MCX move > 1.5% not yet
followed by the linked shares after 15-30 min = commodity-lag idea (S8 #8); Brent +-3% or USD/INR +-0.5% = freeze new entries 15 min.

### E2. Driver -> sector -> every F&O share (the watch lists)
Sector map (knowledge base): driver -> sectors -> every F&O share, with revenue-vs-cost sign (copper is a COST for cables; bulk
Scotch is a COST for liquor makers). Output at 19:45 and 07:15: sectors likely up / down and why, every F&O share in them with zone
(overbought / oversold / neutral), speed, room, likely gap, and the laggard candidates named ("gold down -> PE watch TITAN,
KALYANKJIL, MANAPPURAM, MUTHOOTFIN; KALYANKJIL overbought and still holding - likely to catch down, PE below X"). 08:45 adds China
data and changes since 07:15. 09:08 compares the pre-open (F09) with the list: a met trigger becomes GO NOW at the open (still
subject to the 09:30 entry window). The watch list is also K2 C1's subscription list.

### E3. Confirm the sector - from the WHOLE sector (never before 09:20)
From F03 / F25. All must hold: (1) sector % vs NIFTY (relative strength), beta-adjusted; (2) breadth >= 70% over ALL listed shares
of the sector moving the same way, median move > 1%; (3) equal-weight vs index - one share doing > 60-70% of the move = TRAP;
(4) futures build-up in several F&O names, OI summed over ALL months (expiry-week rollover fakes long unwinding); (5) sector on the
right side of its own VWAP, gap still there at 09:45; (6) not NARROW (F&O names moving while the rest is flat). Output: "SECTOR
DOWN - confirmed since 09:20 · driver · news · build-up · basis: all 14 listed, free-float". States: WATCH -> FORMING -> CONFIRMED
-> FADING / CANCELLED, each with its time. INCOMPLETE data (< 90% weight LIVE) cannot confirm.

### E4. Every F&O share in the confirmed sector, with its ROLE (no "top 3" limit)
For each F&O share: zone (daily and 5-min RSI, distance from 20-day high / low), speed (beta to sector, usual day range), size,
moved today, range used (|move| / ATR14), room to the next level in ATR (prev-day / 20-day high-low, VWAP, option OI walls), RVOL at
the same time of day, futures money (fresh longs / shorts, all months), its own news.

| Role | Definition (falling sector -> PE; mirror for a rising sector -> CE) | Default entry |
|---|---|---|
| LEADER | falling with the sector or faster, short build-up, below VWAP and the opening range | on breakout; if EXTENDED, the trend-day rule E5 |
| DEPENDENT | moves because of the same driver (gold loans and jewellers on gold, cables on copper), following the sector | with the sector, after confirmation |
| LAGGARD (CATCH-DOWN ▼ / CATCH-UP ▲) | still flat or up / overbought while the sector falls | ONLY when breadth >= 70%, it holds on the trend side of its own VWAP, its RVOL is rising, no news of its own, before 13:00; trigger = break of its VWAP AND its morning low (after 10:30 per setup B). Otherwise take the leader on a pullback |
| DIVERGENT | moving AGAINST the sector on its own news | not part of the sector call; judged alone on its news (E12) |
| HELD | the trader's own position | follow-ups only (E10) |

### E5. Trend-day exception (the TITAN lesson, S11 / R13)
When the driver AND the sector are confirmed, and the share has fresh build-up in the call's direction AND is making lower highs below
VWAP (higher lows above VWAP for CE), "extended" (range used > 1.2 ATR) is a WARNING, never a block: the share stays LEADER at the top
of its sector and the call becomes **"EXTENDED - enter on the bounce to VWAP / the first lower high, 1 lot (minimum)"** with that
price as the trigger (e.g. bounce to VWAP, then a 5-min close below the bounce low). Hard blocks are ONLY: ban, loss lock, stale
data. Never a bare "NOT TRADABLE": every warning says the reason in plain words and what to do instead (better strike, wait price).
Replay 18 Nov to set the numbers; the no-chase limits are starting values.

### E6. Rank
Morning score (checklist I, starting weights, re-fit monthly moving only halfway): RS vs sector x RVOL 30% · sector strength and
breadth 25% · catalyst 15% · OI build-up 15% · gap holding (ATR-scaled) 10% · agreement with NIFTY 5%. A+ score out of 10 (S8) for
size: 8+ = normal size, 6-7 = reduced, below 6 = skip. Setup label on every idea (B4): opening-range breakout, first VWAP pullback,
failed breakout, day-2 results drift, sector laggard, rotation, policy shock. Day type by 10:00 decides which setups are allowed.

### E7. The strike chooser (R42) and the option gate (checklist E)
For every call: ATM / 1 ITM / 1 OTM, this expiry AND next, side by side - premium (bid / ask / mid), delta, theta per hour per lot,
gamma, vega, IV vs 20-day and IV rank, spread (Rs per lot and ticks), depth, OI and OI change, distance to the nearest wall, share
move needed to break even by 15:10, lot size, cash needed, charges (one dated table) - and **GIR's pick and why**. Gate: spread <=
1-2% of premium; ~500+ contracts traded before 10:00; delta about 0.45-0.6; IV rank < ~50; IV-crush filter (block when results /
event within one session and IV > its 70th percentile or ATM IV > 1.3x its 20-day); not in ban; last 5-7 sessions -> prefer next month.
A strike that fails liquidity is replaced by the better strike ("spread 1.6% on 520 PE -> take the 525 PE, 0.7%"), not dropped.
Break-even move by 15:10 must be at most half the share's expected move. IV / greeks from F26 only.

### E8. The call: GET READY / GO NOW, with the vote
- **GET READY** when the price nears the trigger (or an unconfirmed policy / basket event, E12). **GO NOW** when the price confirms,
  every gate passes, inputs are fresh, entry window 09:30-14:30 (no orders 09:15-09:20; no new rotation entries after 14:00).
- Card fields (R14, CONFERENCE fix 4 order): verdict line -> share · CE / PE · strike · expiry · premium limit ("no chase above X") ->
  trigger · stop · target on BOTH premium and share (T1 before the wall; stop on the share level that proves it wrong and never more
  than 30% of premium; Kite backstop SL-L trigger and limit) -> THE VOTE -> gate chips (spread, depth, IV/20d, MWPL, lock room, data age)
  -> hold until (time stop 45-60 min without +0.5R; hard exit 15:10) and "don't exit before the stop or the target unless GIR says EXIT"
  -> lots from the lock room (fix 13: "lock room Rs 1,980 vs max loss Rs X -> n lots"; 0 = BLOCKED) -> max loss in Rs, R:R after costs
  (skip under 1.5), costs split as charges + slippage -> why (one line) and what makes it wrong -> signal age -> that setup's record.
- **THE VOTE** (spec 3.5, R14): voters = sector agents 1-3, news, money (futures). "n of N agree" where N = voters who voted; each
  voter weighted by its measured hit rate (a voter with no edge counts zero; "?" = did not vote); the auditor checks and does not vote;
  a vote against is shown. A conflict (e.g. 18 Nov HINDZINC PE vs an "extreme bullish" auditor) is shown on the card, never hidden.
- Validators before anything is shown: every price exists in the data given; the strike is in the chain; stop / target on the right
  side; confidence < 0.6 -> NO_TRADE; reject and retry once, then drop. NO_TRADE is the default.

### E9. Risk, size and the loss lock (B1)
1R = (entry premium - stop premium) x quantity; each trade risks <= 1% of capital; 1 lot until 100 trades are journalled ("1 lot
(minimum) = 0.4R, about half normal risk" - never the word "half" on one lot). Daily loss lock about -2% of capital or 2 losses in a
row -> no new calls for the day (LOCKED until 09:00 next session); weekly stop -6%. At most 3 trades a day, 2 open positions, never two
in the same sector or on the same driver ("one gold PE max"). Cooling-off 15-20 min after a loss. Chase zone: price > 0.3 ATR past the
trigger or premium 8% past the planned entry -> wait for a pullback. Cash check before each call (premium is paid upfront). The engine
never places orders, moves a stop or overrides size.

### E10. Follow-ups on the trader's own trades only (G, B5)
HOLD while the share and its sector stay on the right side of VWAP and RS holds. **BOOK HALF** at about +1R / T1 or when the move
stalls (3+ five-minute bars with no new extreme on falling volume, rejection at a key level, premium not rising with the share).
Trail the rest (2 x 5-min ATR or the last 5-min swing). **EXIT** on the stop, the invalidation, a real reversal, or the time stop.
15:00 warning, 15:10 hard exit. A rotation OUT of the held position's sector with the share on the wrong side of VWAP -> EXIT now.
Kite line on every exit: "MODIFY SL-L -> LIMIT bid - 1 tick" (fallback: cancel, then sell). An exit not done in Kite within 2 min ->
P1 call. No exit messages for trades the trader did not take. A manual early exit asks for a one-word reason (journal).

### E11. Rotation alarm (S11) - every minute 09:30-14:00, rolling 15 / 30 min windows
Per basket (whole sector, R49): beta-adjusted RS vs NIFTY and its RANK change; breadth (up and above VWAP); equal-weight vs index
(recompute without the heavyweight); volume vs the 20-day median of the SAME time slot; futures LB / SC across the basket (OI over all
months; ignore near-month-only SC in expiry week); call-buying bursts, wall unwinding, put writing, call IV rising; excess basis;
WHERE the money comes from (sectors losing 3+ ranks); 10y yield / USD/INR moves; news match +-10 min.
- **GET READY (amber outline):** any two of: rank up 3+ in 15 min · breadth >= ~2/3 · sector volume >= 1.5x slot normal · basket
  futures LB / SC >= 60% with volume >= 2.5x · a news match.
- **ROT CONFIRMED (age shown; never written "GO NOW" - that word is only for a call):** beta-adj RS >= +0.6% over 30 min · breadth
  >= ~85% · equal-weight >= 0.8x the index · volume >= 2x · basket above VWAP for 2 five-minute bars · calls bought / walls unwinding in
  3+ names · a source sector or news named. Then the share must pass E4-E9 to become a GO NOW call.
- **CANCEL:** breadth < ~60% or basket below VWAP. One alert per basket per 30 min, only escalating; every alarm logged (fired and failed).
- Which share: alarm < 20 min old -> laggard catch-up (above VWAP, own volume rising, no own news, before 13:00, spread < 1%); > 20 min
  -> the leader on its first pullback to VWAP that holds. Don't chase: range used > 1.2 ATR (70-100% = pullback only, reduced size;
  > 100% stand aside) - EXCEPT the trend-day rule E5; alarm > 45 min old; sector already +2.5% vs NIFTY; ATM premium +40% or IV > 1.3x
  20-day; breadth falling; within 0.3 ATR of the day / previous-day high; unconfirmed headline; after 14:00. One trade per theme.
- Alert text states the age: "ROT CONFIRMED · money OUT of PVT BANKS (-4 ranks), IT (-3) INTO PSU BANKS since 11:40 (14 min) · RS
  +0.8% · breadth all 10 / 12 · F&O 6 / 7 · RVOL 2.6 · 10y -5 bp · leader SBIN · laggard BANKBARODA · OUT: you hold INFY CE -> EXIT".

### E12. Policy shock and basket shock (S12) - with the second direction check
1. **Basket shock (price first, F27):** 3+ shares of one policy basket (e.g. brokers ANGELONE, BSE, CDSL, MCX, MOTILALOFS) moving the
   same way 1%+ inside 60 s on a volume burst -> within ~10 s a blue card "BROKERS falling together - news not found yet" -> search
   every source (F15-F20) for the cause -> GET READY with the headline once found. **Never a GO NOW on price alone.**
2. **Watched words from LIVE / WIRE sources** (F17 TV text, F19 X, F16 wires, live blogs) on a mapped body (IRDAI, CERC, SEBI, RBI,
   NPCI, TRAI, NPPA, DGCA, CBIC / DGTR / DGFT, Parliament bills) -> wake the analyst at once with the mapped shares -> GET READY
   (UNVERIFIED, quote the source and the seconds since the first source). GO NOW only after a second independent source or the
   official page / gazette / filing. "Sources say", "considering", "no decision yet", denials and clarifications wake the analyst
   too (the 18 Nov SEBI-MTF miss; CDSL "no communication from SEBI").
3. **Read the real document before naming a cause.** For a share moving on company news, fetch and read the actual NSE / BSE filing
   attachment (F15) before any call, and name what it says (PAYTM 19 Nov: the trader says the cause was a restructuring of the
   payments business into a separate entity, not a UPI MDR story - verify from the filing). Old news retold is old news.
4. **Second direction check (a second, independent model reading):** every policy / news direction that can lead to a call is read
   twice; if the two disagree, the item stays GET READY at most and the card shows the disagreement. The policy map stores the SIGN
   of each driver per share (revenue vs cost). Known traps, each kept as a regression test:

| Case | Wrong reading | Right reading | Rule stored |
|---|---|---|---|
| MCX, 18 Nov 09:01 | SEBI lowers commodity margins -> PE | lower margins = more trading = GOOD for MCX | margins / limits on trading volume: lower = positive for exchanges / brokers |
| UNITDSPR, 19 Nov pre-market | Scotch duty news -> POSITIVE | bulk Scotch (~80% of India's Scotch imports) is the blending INPUT: higher duty or a denied FTA rate = COST = NEGATIVE (RADICO too) | duties on inputs are negative; duties on competing imports are positive |
| PAYTM, 19 Nov pre-market | guessed UPI MDR | read the filing: restructuring of the payments business into a separate entity (verify) | no cause without the document; NPCI circulars watched (F20) |
| ANGELONE, 18 Nov | nothing said | "SEBI mulls MTF limits - sources" = negative for brokers; basket shock first | "sources say" stories wake the analyst; basket shock -> GET READY |
| Fines / small orders | rang | weigh against company size (order > 10% of revenue matters, < 2% ignore; a small fine never rings) | weight 1-5 by size; only 4-5 ring |

5. Speed targets (first source -> page), measured daily in the 15:45 audit: basket shock 10 s · X / TV text 15-30 s · wires 30 s ·
   regulator site 60-120 s · filings < 15 s.

### E13. AI routing and cost - $20 / day hard cap (spec 6, S4)
- Tiers (no model names in config text shown to the trader): **small model** reads every news item ONCE (< 1.5 s: tickers, event
  type, direction, materiality 0-3, novelty); **mid model** only for materiality >= 2 or a code trigger: the ONE merged desk call
  returning all six desk views, the board's reasoning, follow-up explanations, the second direction check; **top model** only for the
  final GO NOW check on a candidate that passed the code filters and for the 07:15 sector plan (and the 19:45 note) - about 15 calls a
  day, never on the critical path (code + mid model signal, top model confirms or vetoes).
- Budget checked in code BEFORE each call (estimate x price vs per-call / hour / day counters) plus the provider-side limit.
  Split: about $5 night and morning prep, $12 market hours, $3 reserve for big news. Ladder: 60% of the day -> top model off;
  85% -> mid model only for the most material items; 100% -> code rules + small model only, one message to the trader. Find and fix
  why 18 Nov spent $27.24 against a $5 cap (it only reported spending).
- Prompt caching on every call: frozen instructions and schema first, then the day's static context, cache breakpoint, live data
  LAST; no timestamps or unsorted JSON before the breakpoint; target >= 70-80% cache reads (today ~13%). Hash every news item so it is
  never read twice; one mid-model call per share per 3 min; desks read stored verdicts, not raw text.
- Structured output schema `{action BUY_CE / BUY_PE / NO_TRADE, symbol, strike, expiry, entry zone, stop, target, invalidation,
  confidence, evidence ids, time-to-live}`. Timeouts per tier 2 / 8 / 25 s with fallback one tier down or NO_TRADE.
- Every prompt or model change must pass a replay of 20-30 past days before it ships. Keep any agent only if its calls earn >= 3x
  its cost; drop it if it has not beaten the random baseline after 100 calls.

### E14. Alerts, sounds, Telegram (spec 4, R10)
Only these ring: GO NOW (one bright chime, once), GET READY on a sector call (one soft tick, once), the trader's own exits STOP /
BOOK HALF / EXIT / 15:10 (two low notes, repeat every 60 s until A + Enter; never muted while a position is open). Everything else is
silent on the page. ONE AlertManager and ONE SoundPlayer (the old alarm layer is switched off underneath at switch-on - never two
sounds). Page first, Telegram about 5 s later, decisions channel only. Duplicate check per share + signal + 15 min.

### E15. The 15:45 scorecard and paper engine (TRIAL, I, B8)
What the analyst said and when (19:45, 07:15, every GO NOW / GET READY / follow-up) vs what happened (every F&O share 2%+, every
sector 1%+, with the minute each move began); named before / late / missed with the reason and which agent failed; each agent's day
(ran / found / woke / reached the trader / cost); AI spend by tier and hour; cost per useful call; latency waterfall per event
(first source -> GIR -> page -> Telegram). Paper twin of every GO NOW and triggered GET READY (ask in, bid out, + 1 tick) vs a random
baseline. **During shadow mode the old and the new engine are scored side by side.** Sent to the page and the decisions channel.

---------------------------------------------------------------------------------------------------------------------------------

## 3. LAYER 3 - THE PAGES (23 pages + the shell)

Each page is built exactly as its drawing (`design_v3/<slug>_final*.html`, else the newest `<slug>_v3r*.html`): same boxes, same
order, same colours (CONFERENCE 1.5), same type sizes (1.4), whole rows and drawn scrollbars, a hero line on top, at most 6 panels at
1600. "F / C" = the IDs that must be visible in the first view / one click away (CONFERENCE 1.6). Data = layer-1 feed ids; calc =
layer-2 step ids. Status: **BUILD** = new box; data marked (exists?) must be verified on the server first. Every share name links to
its Share page; every build-up tag links to its F10 filter; every freshness dot links to Health. Every page reads the ONE SSE store (never fetches alone); each value
arrives as a Fact `{value, unit, source, src_ts, first_seen, state}` and shows its age; STALE is grey with the reason (R09).

### 3.0 The shell (every page: market strip R01, P&L strip R02, tab bar R03, search R04, BAN pill R35, sounds R10, footer)
| Box | Data | Calc | Status |
|---|---|---|---|
| Market strip: NIFTY, BANKNIFTY, SENSEX, FINNIFTY, MIDCPNIFTY (price, change, %, sparkline), VIX, GIFT (premium to spot), USD/INR, Brent, gold, FII / DII cash + F&O (dated), PCR NIFTY / BANKNIFTY, A/D of F&O shares, expiry + sessions left, market status, clock, data age | F01, F02, F13 (FII / DII), F05 (index PCR), F11 (expiry), F23 | strip age = oldest input; CLOSED states | BUILD (values partly exist in the old top bar) |
| BAN pill + popover ("MWPL 97% · in ban: close only"; "> 85% · ban at 95%") | F12 | E0 | BUILD |
| MY F&O P&L strip: today Rs net of costs (realised + open at bid less exit costs) and R, "at share stops", trades n of 3, week / month, loss-lock meter and LOCKED chip, AI spend vs $20 meter | F10, F31, F29 | E9 lock room, costs = charges + slippage | BUILD |
| Tab bar (one list: F1-F10 row, SHIFT + row with filled keycaps, F5 "off · reload blocked", Ctrl , Settings, ? Help, /NIFTY Market, Space Plan card) | - | - | BUILD (from SHELL.md / shell html) |
| "/" search with suggestions after 2 letters, verb chips (OC, FUT, NEWS, LOG), Enter = Share page | F11 | - | BUILD (complaints 1, 20, 25) |
| Sound ON / OFF, legend, M mute, unacknowledged P1 / P2 count | E14 | - | BUILD |
| Footer: key hints, health word (READY / LIMITED / DOWN + worst item), phone link - controls only, no disclaimer lines (R06) | F28 | - | BUILD |

### 3.1 Morning & pre-flight (⇧F1) - F: R29 TODAY plan, R18 drivers, R13, R34 (09:04 pre-open) · C: R23 / R24 movers + build-up, R28, R19, R20, R42
| Box | Data | Calc | Status |
|---|---|---|---|
| Hero: today's plan ("PUT day on gold and copper · first call X below Y · NOT ARMED · n steps left") | F23, F22, F15-F21 | E1, E2 (07:15 note), arm-the-day state | BUILD |
| Pre-flight: ARM n / 18 checks (4 Kite tokens, clock, instruments + reconcile, ban T+1, second feed, AI budget, test alert) | F28, F11, F12 | J67 pre-flight | BUILD (v2 checker) |
| My risk: capital, lock, week, trades allowed, commitments | F10, F31 | E9 | BUILD |
| Today · the market: risk strip (events with IST times, in-session locks, expiry week, results today) | F22, F21 | E0 | BUILD |
| Theme · driver -> sector -> every F&O share (heat board: n of 12 drivers crossed since 15:30 close) | F02, F23 | E1, E2 | BUILD |
| Watch list · call plan (every share with role tag, build-up tag, trigger, GET READY / WATCH, MWPL / spread / event warnings, "1 gold PE max") | F14, F25, F12 | E2, E4, E5, E7, E9 | BUILD |
| GIR analyst · plan (07:15 note, ASK) / MOVERS (yesterday's movers + LB / SB / SC / LU counts) / PRE-OPEN (09:00-09:08 table with UP / DOWN / ALL chips, never covers the page) / STRIKE (chooser for the top watch) | F29, F13, F09, F04 | E2, E7, E15 | BUILD |

### 3.2 Desk - hunting (F1) - F: R11, R12, R13, R14 GO NOW card, R17, R22, R32, R36, R07 · C: R42, R15, R16, R19, R23
| Box | Data | Calc | Status |
|---|---|---|---|
| Hero: the one option to buy now (GO NOW share · PUT strike · premium limit · age · "Flat · 0 used, 3 left"), R41 hand-off bar PREP › FIND › SHARE + STRIKE › PLAN › KITE › MANAGE › REVIEW, ALL SECTORS filter | F04, F10 | E8, E9 | BUILD |
| Sectors (ranked, heat rows + % bars, click opens in place = accordion; theme line; rotation line -> F3) | F03, F25 | E3, E11 | BUILD (seclive data exists - verify) |
| F&O movers / Build-up / Money tabs | F01, F25 | E4 build-up | BUILD |
| Members of the selected sector (every F&O share: role tag, % day, RS vs sector, VWAP side, range used, futures tag, plan line; "one gold bet at a time") | F01, F25, F14 | E4, E5, E6 | BUILD |
| Chart (1 / 5 / 15 min, VWAP, OR, levels) + premium pane (option mid with bid / ask band) + strike chooser (3 rows, 8 columns, GIR pick ★, "all columns · Nov ›") | F01, F04, F26 | E7 | BUILD (TradingView Lightweight Charts, per-tick update) |
| GO NOW call card (verdict, trigger / stop / target premium + share, THE VOTE, gate chips, hold rule, lock room) | F04, F26, F10, F29 | E8, E9 | BUILD |
| Action (ONE feed of every call; chips ALL / GO NOW / READY / FOLLOW / MY TRADES / POLICY with counts that match; empty chip says why; EARLY / RUNNING hidden; ≥ 5 rows; "BASKETS n armed" line) + Ask drawer | calls store, F27 | E8, E10, E12, E13 | BUILD |

### 3.3 Desk - in a trade (F1, positions open) - F: R30, R15, R07 exit line, R12 · C: R42 next slot, R17, R11, R26
| Box | Data | Calc | Status |
|---|---|---|---|
| Position tabs + chart of the held share with premium pane, STOP / T1 / wall / time-stop lines, P&L-since-entry sparkline | F01, F04 (K2 + K4 pinned), F10 | E10 | BUILD |
| Sectors / F&O movers (held sector marked HELD; roles; EXTENDED and warning lines in words) | F03, F25 | E3-E5 | BUILD |
| GIR Analyst · latest (one decision per held position + next idea; never blinking; ASK) | calls store, F29 | E10, E13 | BUILD (complaints 18, 41) |
| Alerts (MINE / POLICY / CRIT / MKT / ALL; P1 / P2 with ack state) | E14 log | E14 | BUILD |
| Action (MINE EXIT / BOOK first, then GET READY rows with strike chooser) + Call card on Space | calls store | E8, E10 | BUILD |

### 3.4 Plan card (Space on a call) - F: R42, R14, R07, R12, R13 · C: R43, R27, R10
| Box | Data | Calc | Status |
|---|---|---|---|
| 1 Verdict: GO NOW · share · PUT · strike · expiry · valid-till · premium and share limits · ages (analyst source, quote) · follow-ups (yours only) | F04, F01 | E8 | BUILD |
| 2 Strike chooser (ITM / ATM ★ / OTM, both expiries; bid / ask, spread, depth, Δ, θ / hr, γ, vega, IV x 20d, IV rank, OI, OI chg, premium at wall, B/E by 15:10) + IV gauge | F04, F05, F26, F14 | E7 | BUILD |
| Sector header + role strip (TITAN LEADER SB · MANAPPURAM DEP SB · KALYANKJIL LAGGARD LB ...) + theme + rotation line | F03, F25 | E3, E4, E5, E11 | BUILD |
| 3 Money: at stop, IV -2 vega risk, R:R net, worst fill, exit side depth, paid vs cap, B/E, theta to 15:10, costs = charges + slippage | F26, F06 (charges), F10 | E9 | BUILD |
| 4 Checks: hard blocks (BAN, LOCK, DATA age) · warnings (MWPL, spread, event, chase) · passed n | F12, F22, F28 | E0, E7, E9 | BUILD |
| 5 Plan + ticket: you type it, then RECORD (side, lots, stop, early-exit-if); the Kite line (BUY in Kite · NFO · MIS · 1 lot; backstop SL-L trigger + limit) | F31 | E9 | BUILD (GIR never sends the order) |

### 3.5 Sectors (F2) - F: R22, R32, R23, R11, R36, heat map · C: R24, R25 in the accordion, R13, R20 when live
| Box | Data | Calc | Status |
|---|---|---|---|
| The board says (hero): day type + leading sectors with driver, "gold -1.62% -> sector -1.84% · 4/4 down · SB 3/4 · #1 of 22", the top call | F02, F03, F25 | E1, E3, E8 | BUILD |
| Your trades first (EXIT / BOOK lines with the Kite line) | F10 | E10 | BUILD |
| BASKET SHOCK card (blue, live only: "BROKERS falling together", per-share 52 s % / day %, PE burst, first source + seconds) | F27, F15-F20 | E12 | BUILD |
| F&O movers (UP / DOWN / ALL with counts, B/U chips LB / SB / SC / LU, sector of each) -> F10 | F01, F25 | E4 | BUILD (old feature R23) |
| SECTOR BOARD: heat map of every sector (falling / rising / neutral, my sectors, policy chips); basis label (index / "all 14 listed, free-float"), breadth both ways, NARROW flag; rotation 15M / 30M / 1H / TODAY line; accordion with every F&O share (role, %, RS, VWAP, used, futures by month inside: price, OI, OI chg, basis, b/u) | F03, F01, F25 | E3, E4, E11 | BUILD (seclive exists - verify weights per R49) |
| Call card for the pick (GET READY ★ LEADER EXTENDED: bounce trigger, ARMS at ..., chooser, R:R, max loss, lots, lock room) | F04, F26 | E5, E7, E8, E9 | BUILD |

### 3.6 Rotation (F3) - F: R19, R20 when live · C: R11, R42 for the pick
| Box | Data | Calc | Status |
|---|---|---|---|
| Hero picture: flow OUT -> IN (arrows sized by Rs cr) for the chosen window | F03, F25 (futures money) | E11 | BUILD |
| BASKET SHOCK card (live only) | F27 | E12 | BUILD |
| Falling side · PE (sectors losing, their F&O movers) / rising side | F03, F25 | E11 | BUILD |
| Windows table ranked by the chosen window (RS 15M / 30M / 1H / TODAY, today rank vs window rank, day %, breadth, RVOL, OI Rs cr · B/U, state · age); views TABLE / LADDER / RUN CLOCK / ALARMS log | F03, F25 | E11 | BUILD (secsurge / sectortime exist as studies - verify) |
| The pick (laggard or leader by alarm age, chooser both expiries, lock room, "trade n of 3") | F04, F26 | E11, E7, E9 | BUILD |

### 3.7 News (F4) - F: R37, R20, R21 · C: R14 card in the drawer
| Box | Data | Calc | Status |
|---|---|---|---|
| One news list: time · share / MARKET / WORLD / POLICY · headline · AI ▲▼ + weight 1-5 · source · VERIFIED / UNVERIFIED · NEW / PRICED IN; chips ALL / MY SHARES / POLICY / CRITICAL / MARKET; repeats folded ×n | F15, F16, F17, F18, F20 | E12 tagging (name table), small-model read, weight by size | BUILD (gir-newsroom data exists - verify one store, dedupe) |
| Story drawer: the call card on top (with chooser), the story, its sources ladder with seconds since first source, the shares it maps to (role, day %, since, B/U), the second direction check result | F15-F20, F04 | E12, E8 | BUILD |
| Sources: speed and health per source (last, p50, p90, first %, before-move %, items vs usual, state) | F28, R10 | J06 latency | BUILD |

### 3.8 Positions & risk = MY TRADES (F6) - F: R30, R15, R07, R12 · C: R42 next slot, R43 IV since entry, R26
| Box | Data | Calc | Status |
|---|---|---|---|
| My open trades, nearest stop first: 4-line card (NOW vs STOP, P&L Rs + R, GIR says, the Kite line), ▼ P&L split and greeks, ROOM bar, P&L curve, IV in -> now gauge | F10, F04 (K2 + K4), F26 | E10, E9 | BUILD (gir-pnlwatch exists - verify) |
| Risk & P&L now (realised, open, at share stops, at backstops, lock room, trades used, cooling timer) | F10, F31 | E9 | BUILD |
| Next slot · strike ("opens only after an exit") | F04, F26 | E7, E9 | BUILD |
| Ledger · week (net Rs by day, today hatched = open) | F31 | E15 | BUILD |

### 3.9 Share (F7, Enter on any share) - F: R07, R11 role, R13, R14, chart · C: R27, R25, R42, R43, R24, stories (<= 5)
| Box | Data | Calc | Status |
|---|---|---|---|
| Call card for this share (premium + share columns, STOP governs, THE VOTE, gate chips, hard-blocks line, lock room) | F04, F26 | E8, E9 | BUILD |
| Chart 1 / 5 / 15 min with VWAP, OR, levels, PLAN lines, premium pane, vs NIFTY, draw | F01, F04 | E10 lines | BUILD |
| Strike chooser (both expiries, all gate columns, per-row gate result) | F04, F05, F26 | E7 | BUILD |
| Theme · sector (n / n down, SB count, role in sector) | F03, F25 | E3, E4 | BUILD |
| Dossier tabs: futures by month (near / next / far, STALE shown) · levels around now · OI change by strike (CE / PE lots) · calls · my record · WHY (checklist D with numbers) · history E4 (results reaction, gap fill, leader / laggard record) · stories (one why line + "stories ›") | F01, F05, F14, F15, F31 | E4, E6, E15 | BUILD (knowledge base exists - verify) |

### 3.10 Analyst (F8) - F: R16, R14 latest, R15 · C: R17, R38 cost per call
| Box | Data | Calc | Status |
|---|---|---|---|
| Hero: LATEST DECISION in big text (what woke me, the action per share, sound state), never blinking, never an old brief on top | calls store, F29 | E8, E10, E12, E13 | BUILD (gir-analyst exists - fix stuck / blinking) |
| Thesis & theme / What woke me -> what I did (every wake with its source and the action or "nothing to do"); rotation state (not a call) | calls store, F27, F15-F20 | E11, E12 | BUILD |
| Decisions · ONE action feed (newest first, chips with true counts, EARLY / RUNNING hidden, expandable card with chooser) | calls store | E8, E10 | BUILD |
| Notes · plan (19:45, 07:15, 08:45, 09:08 notes with "missing: X since HH:MM" lines) | manifests J32 / J57 | E2 | BUILD |
| Team · agents + X OFF (last run, woke / sent, $, 20-day record vs baseline) · cost vs $20 · Ask drawer | F28, F29 | E13, E15 | BUILD |

### 3.11 Option chain + OI scenarios (F9) - F: R27, R42, R43 · C: R14, R12
| Box | Data | Calc | Status |
|---|---|---|---|
| Chains list (ALL SECTORS filter) and expiry tabs (Nov expiry week / Dec default / Jan, sessions left, OI time and next update) | F11, F05 | E0 expiry mode | BUILD |
| Buyer's chain: CE | strike | PE, today's side highlighted; OI and change, activity word (WRITING / UNWIND / COVER / BUYING), spread, mid, bid / ask, depth, volume, Δ, θ Rs/h; walls; STALE strikes greyed "not offered"; OI bars by strike (mirrored) | F04, F05, F26 | E7, wall rule (D24) | BUILD |
| OI scenarios (share / all F&O, 3 one-line rows) and Unusual option activity (all F&O, 3 rows) | F05, F26 | S6 signals (recorded, labelled untested) | BUILD (old feature R27) |
| Your trade (held strike, HOLD state, share stop and backstop figures) | F10, F04 | E10 | BUILD |
| Strike chooser for the live calls | F04, F26 | E7 | BUILD |

### 3.12 Futures & OI + MONEY (F10) - F: R24, R25, R26, R23 · C: R27 link, R20 via BIG MONEY
| Box | Data | Calc | Status |
|---|---|---|---|
| You hold (held share's futures line) | F10, F01 | E10 | BUILD |
| Build-up: ALL / LB / SB / SC / LU / ROLL / no tag / stale / ban with counts; window SINCE OPEN / 60M / 15M; views BY SECTOR / MOVERS / MAP; OI all months in Rs cr | F01 (futures 3 months), F25 | E4 build-up over all months | BUILD (old feature: LONG BUILD-UP filters and alerts) |
| For your option (CARD / STRIKES: premium, spread, depth, OI Δ, B/E 15:10, cash / lot, greeks, IV, charges) | F04, F26 | E7 | BUILD |
| Futures by month · share (near / next / far: price, OI, OI chg, basis, rollover) | F01, F13 | basis, excess basis, rollover vs last 3 expiries | BUILD (old FUTURES tab) |
| Money: F&O MONEY · BIG MONEY · TAPE · MWPL | F01, F12, F25 | secmoney logic (verify) | BUILD (old features R26) |

### 3.13 World drivers + THEME (⇧F2) - F: R18, R11 driver -> share · C: R20, R21
| Box | Data | Calc | Status |
|---|---|---|---|
| World drivers heat grid (all 16-18 drivers: COMEX $ and MCX Rs split, move vs named reference, sigma, live / closed) | F02, F23 | E1 | BUILD (morningmkts / overnight partly - fix proxies) |
| Sensitivity β (same-day, 120 sessions, n shown) | F14, F23 | regression nightly | BUILD |
| THEME · driver -> sector -> every F&O share (β, % done / to go) | F02, F03, F25 | E2, E3, E4 | BUILD |
| Call card for the theme pick (blue SHOCK chips, lock room) | F04, F26 | E5, E7, E8 | BUILD |
| Other markets · events (next 5, overnight) | F23, F22 | E1 | BUILD |

### 3.14 Calendar (⇧F4) - F: R28, R43 event / IV-crush / expiry rules, R20 Parliament / policy pipeline · C: R29 tomorrow
| Box | Data | Calc | Status |
|---|---|---|---|
| Hero line + "LIVE: GET READY ... · BLOCKED lock room · F8 ›" (one line, not a card) | calls store | E8 | BUILD |
| Today's risk timeline (overnight / PRE / OBSERVE / ENTRY / LATE / MANAGE with impact chips) | F22 | E0 locks | BUILD |
| Events · 4 weeks (pinned "drove today", today, tomorrow, expiry moved for the holiday, Parliament session) | F22, F11 | E0 | BUILD |
| Policy pipeline (bodies as one-line rows: PENDING / ANNOUNCED / NOTIFIED, "paper open to 28 Nov (CONFIRMED)" vs today's "sources say") | F20, F21 | E12 | BUILD |
| Derivatives · results (results season state, ex-dates, F&O inclusions, BAN row with the 3 hard blocks, MWPL 86% "can close, cannot add") | F22, F11, F12 | E0, E7 IV crush | BUILD |

### 3.15 Journal (⇧F6) - F: R30 journal, R41 review · C: R42 strike review, R15 review
| Box | Data | Calc | Status |
|---|---|---|---|
| Every trade (Kite fills, plan vs did) | F10, F31 | - | BUILD |
| Trade review (plan vs did per field: strike, premium, Δ, θ, IV, spread, OI, wall, B/E, cash, by exit) | F31, F26 | E15 P&L split | BUILD |
| Day review (taken / NOT TAKEN with reasons, rules kept) | F31, calls store | E15 | BUILD |
| Where the R leaked (sector, share, entry timing, exit management, option choice) | F31 | B8 split | BUILD |
| Week / Edge / Month · tax (win rate, avg win / loss, profit factor, losing run, drawdown, risk of ruin, n=, by role; tax-ready ledger) | F31 | B8 | BUILD |

### 3.16 Reference (⇧F7) - F: lots, sectors map, R20 baskets, aliases · C: R18 theme map
| Box | Data | Calc | Status |
|---|---|---|---|
| F&O list · sector map (find; lots, tick, MWPL, sector, basis of each sector) | F11, F12, basket file | - | BUILD |
| Theme map (driver -> sector -> share, % same-way days, n) | F14 | E2 | BUILD |
| Contracts · corporate actions · log (every share) | F11 | - | BUILD |
| Baskets (9 policy S12, 6 rotation S11; members; ordered by today's relevance) | basket file | E11, E12 | BUILD |
| Other names (test a word: aliases, brands, parent, old names, word-clash rules) | name table | E12 tagging | BUILD (knowledge base partly) |

### 3.17 Calls & Scorecard (⇧F8) - F: R38 audit, misses · C: cost by tier, R15 rule record
| Box | Data | Calc | Status |
|---|---|---|---|
| Verdict of the day (trial day n of 5; Rs and R) | F31, calls store | E15 | BUILD |
| The score (all F&O shares in the denominator; grey when n < 30) | F01, calls store | E15 | BUILD |
| Rules & blocks kept | F31 | E9 | BUILD |
| What moved 2%+, misses first (share, role · B/U, move, ATM, began, verdict · lead, result · cause) | J05 movers, calls store | E15 | BUILD |
| Call log (immutable; TAKEN / SUPPRESSED / SKIPPED / EXPIRED / CANCELLED / VETOED; filters by setup, theme, time window) + call card as issued | calls store | E8 | BUILD |
| Miss audit (latency waterfall vs S12 targets) | R10, F27, F30 | E12, E15 | BUILD |
| Agents (fresh, found today, woke -> reached, cost, keep / probation) + AI cost | F28, F29 | E13 | BUILD |

### 3.18 Health (⇧F9, /status) - F: R39 · C: R10 delivery, R38 AI spend
| Box | Data | Calc | Status |
|---|---|---|---|
| Verdict (READY / LIMITED / DOWN counts) + un-acted own exits first ("EXIT ... NOT DONE · P1 call") with "holding on purpose: reason" override | F28, F10, E14 log | S3 checker | BUILD |
| Your positions' data (bid / ask, premium age on 2 paths, share age, SL-L, said -> delivered -> done in Kite) | F04, F06, F10 | - | BUILD |
| Exceptions (problems now, worst first) · INCIDENTS (open, failover) · NEVER AGAIN (rule added per incident) | F28 | safe mode | BUILD |
| Kite keys · 12 connections (login, token, per-connection p95 lag, takeovers) | F01-F06 | - | BUILD |
| Services (all, LIMITED, DOWN; market engines with their lists, e.g. movers count = strip A/D; trade engines) | F28 heartbeat | - | BUILD |
| Alerts · sounds (rings used, still ring, delivery per channel) | E14 log | - | BUILD |
| Latency (per event: where the seconds went - market vs GIR: tick arrival, batch wait, burst confirm, build, push) | F30, R10 | - | BUILD |
| Checks · sources: flagged now (stream vs REST sweep, spread blow-outs, P&L = Kite positions, Kite vs NSE); NEWS (items vs usual, regulators, X not enabled) · FILES | F06, F08, F13, F15-F22 | - | BUILD (crosscheck.py exists - after the C4 fix) |

### 3.19 Replay (⇧F10) - F: R41 a past day minute by minute · C: R14 calls as issued
| Box | Data | Calc | Status |
|---|---|---|---|
| Minute-by-minute lanes (sectors, shares, shock, events), cursor | F30 recordings | same v2 code as live | BUILD |
| Proof case (GIR today vs GIR that day; each call alone, paper) | F30, calls store | E15 | BUILD |
| At the cursor: CARD / STRIKES / SHOCK / MOVERS · OI | F30 | E3-E12 | BUILD |
| Your day (the trader's own trades that day, CHANGE GATE) | F31 | - | BUILD |
| Action feed at the cursor (PRACTICE mode hides the future) | F30 | - | BUILD |

### 3.20 Charter & Settings (Ctrl ,) - F: his rules, limits, R10, R46 theme switch · C: Telegram, charges table
| Box | Data | Calc | Status |
|---|---|---|---|
| My rules · history (in his words, versions) | rules store | - | BUILD |
| Limits · loss lock (1R, lock, weekly stop, trades / day, open positions) | rules store | E9 | BUILD |
| Option gate · stop · costs (gate numbers; one dated charges table + slippage row; AI tiers with calls / $ / cache) | rules store, F29 | E7, E13 | BUILD |
| Sound · Telegram · calls (ring log, shock thresholds by sigma, Telegram channel on / off) | E14 | - | BUILD |
| Appearance: Dark / Light / Auto | - | - | BUILD |

### 3.21 Help (?) - F: R31, R06 colour legend, R03 keys, "Where is…" line · C: every page's purpose
| Box | Data | Calc | Status |
|---|---|---|---|
| Pages (same list as the tab bar) with purposes; "Where is…" finder (build up, gainers, losers, top movers ...) | static | - | BUILD |
| Read a call card (frozen specimen, every number checks) | static | - | BUILD |
| The day's phases (PREP, PRE-OPEN, OBSERVE, ENTRY, ...) and words | static | - | BUILD |
| Colour key (CONFERENCE table 1.5) | static | - | BUILD |

### 3.22 Phone (/m, 390 wide) - F: R40, R01 compact, R02 line, GO NOW card, his exits · C: R23 / R24 MOVERS + BUILD-UP sheet
| Box | Data | Calc | Status |
|---|---|---|---|
| NOW - open trades, nearest stop first | F10, F04 | E10 | BUILD |
| CALL - the calls, read-only (chooser, if-every-stop-hits line) | calls store, F26 | E8 | BUILD |
| RISK - what can still be lost, expiry, BAN, next 2 h, market | F10, F12, F22 | E9 | BUILD |
| ALERTS - what rang and why (seen here = seen everywhere) | E14 log | - | BUILD |
| MOVERS + BUILD-UP sheet | F25 | E4 | BUILD |

### 3.23 MARKET - NIFTY / BANKNIFTY screen (/NIFTY) - F: R33 chart with controls, R43 index options · C: R23 index movers
| Box | Data | Calc | Status |
|---|---|---|---|
| Chart hero (1m / 5m / 15m, VWAP, OR, levels, draw, compare BANKNIFTY) | F01 | - | BUILD |
| Who moves (index contribution by share, sums correct) | F01, index weights | contribution | BUILD |
| NIFTY / BANKNIFTY options (weekly / monthly) | F05 (index chains: add to K3), F26 | E7 | BUILD (index chains not in the plan yet - add) |
| Index strike chooser ("index-option day: NO / YES" with the reason) | F04, F26 | E7 | BUILD |
| F&O movers · build-up · F&O tape (KEY / BIG Rs / UNUSUAL / TV) | F01, F25 | E4 | BUILD |

### 3.24 Old features that must survive (LAYOUT.md, complaints) - show this table to the trader before switch-on
| Old feature | New home |
|---|---|
| BOARD / sector board, sector click | F2 Sectors (accordion in place), F1 Desk |
| F&O MOVERS UP / DOWN / ALL | F2 Sectors, F1 Desk tab, phone sheet |
| LONG BUILD-UP LB / SB / SC / LU filters and alerts | F10 Build-up (every build-up tag links there) |
| FUTURES by month | F10 Futures by month, F7 Share dossier |
| F&O MONEY, BIG MONEY, F&O TAPE | F10 Money; tape also on MARKET |
| OI SCENARIOS, OPTIONS | F9 Chain |
| RESULTS | ⇧F4 Calendar |
| PLAN: TOMORROW / TODAY / CHECKLIST | ⇧F1 Morning, F8 Analyst notes |
| MY F&O, COCKPIT | F6 Positions (MY TRADES), P&L strip |
| GUIDE | ? Help |
| NIFTY / BANKNIFTY chart | MARKET screen |
| PRE-OPEN | ⇧F1 Morning (never blocks the page) |
| BAN bar | BAN pill in the strip |
| ALL SECTORS dropdown | filter on Desk, Sectors, Chain (really filters) |
| NEWS (everywhere) | F4 News only; elsewhere a one-line "why" |
| THE VOTE | every call card |
| GIR ANALYST box, ASK | F8 Analyst, Desk latest line, Ask drawer |
| SOUNDS, CHECK | shell sound button; F9 Health checks |
| Every old keyboard key | still opens the same view (map them in Help) |

The server must first list every box, panel and tab on today's home.html (with the patch that added it) and add any missing row.

---------------------------------------------------------------------------------------------------------------------------------

## 4. TESTS

All tests run on the recordings (F30) and news archives through the SAME v2 code as live, using only data that existed at each
minute (no look-ahead). Each test writes a table: share · what GIR said · time · price · result at the close · pass / fail.
**If a recording for a day is missing or partial, say so and test on what exists - never fill gaps by hand.**

### 4.1 Replay 18 Nov (the proof case - every engine change must pass it)

Facts of the day: gold -2%, copper -4% (5-month low), silver -3%, US tech weak, strong dollar; JEWELLERS & GOLD LOANS and CABLES &
WIRES confirmed DOWN at 09:20; metals down; pharma the only real long build-up. Old system: no GO NOW on any of these; OPENING alerts
6-11 min late, FIRST MOVE 12-63 min late.

| Share / event | Pass criteria |
|---|---|
| 17 Nov 19:45 and 18 Nov 07:15 notes | drivers past threshold (copper, gold, silver, DXY, Nasdaq / SOX) with two witnesses; watch list names TITAN, KALYANKJIL, MANAPPURAM, MUTHOOTFIN (gold), POLYCAB, KEI (copper), SAIL, NATIONALUM, HINDALCO (metals) as PE candidates; KALYANKJIL flagged as the overbought laggard |
| Sector confirmation | JEWELLERS & GOLD LOANS and CABLES & WIRES CONFIRMED by 09:21 at the latest, from whole-sector data, with breadth both ways and basis labels; none confirmed before 09:20 |
| TITAN (-5.3%, day's biggest F&O faller) | GET READY by ~09:25 as LEADER; when extended, the trend-day call "enter on the bounce to VWAP / first lower high, 1 lot" with a price trigger - never "not tradable"; GO NOW when the bounce fails |
| MANAPPURAM (-4.6%) | GET READY at 09:20, GO NOW by ~09:30 (DEPENDENT, short build-up); then BOOK HALF when the move stalled (complaint 32: -3.84% by 09:30, then no further fall for a long time - GIR said nothing) |
| KALYANKJIL (held near -2%, then -5%) | named LAGGARD CATCH-DOWN by 09:30 with its trigger (VWAP and morning low); GO NOW only when the D8 conditions hold; time logged vs the fall |
| SAIL (-4.4%), NATIONALUM, MOTHERSON | metals / steel PE GET READY by ~09:30 with triggers; GO NOW when confirmed |
| POLYCAB (-5.1%) | cables PE named at 09:20 confirmation; GO NOW well before the old 11:23 ACT NOW |
| ANGELONE basket shock (SEBI MTF "sources" story) | BASKET SHOCK card <= 10 s after the 3rd broker share crossed 1% in 60 s; GET READY with the headline <= 30 s after the first source (TV / wire); "no decision yet" / denial lines wake the analyst; no GO NOW on price alone; read exact times from the recording and report each gap |
| MCX 09:01 (lower commodity margins) | direction POSITIVE for MCX after the second check; the old PE reading would have been blocked |
| Rules | no exits for trades not taken; the one-gold-bet rule; loss lock after 2 losses; one sound per alert; every output ends in an action per share |
| Cost | the replay's AI spend under the day budget, cache reads >= 70% |

### 4.2 Replay 19 Nov (trial day 1) - incl. AUTO CE: the 18 Nov 19:45 note must already name autos CE for 19 Nov; then copper / aluminium slump overnight -> NIFTY AUTO CE call by 09:20 (MARUTI, ASHOKLEY, TVSMOTOR, M&M)

| Case | Pass criteria |
|---|---|
| PAYTM (-5% pre-market) | the cause named from the actual filing / news (the trader says: restructuring of the payments business into a separate entity) with the document's time; report whether it was in GIR before 09:00 and what the old system called; no call against the reading; NPCI watcher in place |
| UNITDSPR (fell pre-market, second only to PAYTM) | direction NEGATIVE (bulk Scotch duty = input cost) after the second direction check; the old POSITIVE reading shown as caught; any PE only after price confirmation from 09:20; no CE |
| Live event speeches (WFE meeting, 17-19 Nov) | TV / live-stream text captured with times; any market-moving line mapped to shares (exchanges, brokers) |
| The rest of the day | every F&O share 2%+ and sector 1%+ listed with the minute the move began, scored named before / late / missed |

### 4.3 The 15:45 audit test (every trading day from the first day of shadow mode)
The scorecard (E15) is produced at 15:45 for BOTH engines: what each said and when, every 2%+ F&O mover and 1%+ sector, before / late /
missed with the reason and the agent, latency per S12 target, agents' lines, AI spend by tier and hour, cost per useful call. Pass:
it is complete by 15:50, every mover is accounted for, and the numbers match the recordings. The new engine is switched on only when
its scorecard beats the old one on the replayed days AND on at least three live shadow days (the trader decides).

### 4.4 Page release gate (S5.8, before the trader is asked to switch on)
Automated browser tests on recorded streams at 1x and 10x: prices update, clicks and keys work, every share name opens its Share page,
each alert plays once (one SoundPlayer), nothing blinks, no overlap or clipped text at 1600x900, 1366x768 and 390 wide; a 30-minute soak
at 10x fails on memory growth > 30 MB, long tasks > 100 ms or rising DOM nodes. Screenshots of every page at the three sizes go to
/shots for the trader.

---------------------------------------------------------------------------------------------------------------------------------

## 5. BUILD ORDER - LIVE TEST ON MONDAY 23 NOV (the trader's deadline)

The trader, 19 Nov: "I want it by Monday to test in the live world." So the whole trading system - data, engine and pages - must
run LIVE on girtrader.com/preview from **Mon 23 Nov 08:30**, with real Kite data, real calls and its own sound. Work in parallel
(data, engine and pages at the same time, not one after the other), day and night, weekend included. Steps that change a LIVE
service still wait for 15:35 on weekdays (any time at the weekend). Every step: its test passes, its undo line is logged,
BUILD_LOG.md is updated, and a short progress note goes to the trader each evening (and Sunday noon).

| When | Steps (in parallel) | Must pass |
|---|---|---|
| **Thu 19 Nov, now** | S1 inventory · S2 v2/ + gir-preview + shell · S3 verify-first list · start S6 Desk (hunt + trade) and the Plan card on /preview with adapter data | /preview shell + Desk load through the tunnel; strip values = live page |
| Thu 19, after 15:35 | S4 /preview route behind login + C4 two-clock fix · S5 recorders R1-R6, R9 | /preview reachable; recorders writing |
| **Fri 20 Nov** (market hours: /preview only) | finish **Desk + Plan card**; **Sectors** (whole-sector baskets F03), **Positions / My trades**, **Phone** on /preview; engine E0-E10 coded in v2 | the pages match their drawings at 3 sizes with live values |
| Fri 20, after 15:35 | S7 Kite FULL mode + MCX / CDS / GIFT + K4 standby · S8 world inputs fixed · S9 four-key feed starts | Friday evening MCX ticks; FULL re-set after reconnect |
| **Sat 21 Nov** | S9 four-key feed complete · S10 engine E0-E10 + Black-76 greeks · S11 filings 3-5 s, live blogs, Reuters sitemap · pages **Option chain, Futures & OI, Share, Scorecard** | **replay 18 Nov passes** (TITAN, KALYANKJIL, MANAPPURAM, SAIL, POLYCAB on time); PAYTM cause read from the filing |
| **Sun 22 Nov** | S12 rotation alarm, basket shock, policy watchers (NPCI, sansad.in, regulators), second direction check, AI gateway with the $20 cap · S14 calendar / expiry-week mode · pages **Morning, Rotation, News, Analyst, World, Calendar, MARKET, Health** · then Journal, Reference, Replay, Settings, Help | ANGELONE shock <= 10 s, UNITDSPR NEGATIVE, MCX POSITIVE in replay; budget stops at the cap |
| **Sun 22, 20:00** | DRESS REHEARSAL: replay 18 + 19 Nov end to end on /preview at 10x; release gate 4.4 on every finished page; screenshots to /shots; the old-feature table (3.24); progress note to the trader | all pass; any unfinished page named with its finish time |
| **Mon 23 Nov 08:30 - LIVE TEST** | the new system runs LIVE on /preview: morning page, calls, sounds, follow-ups, 15:45 scorecard. At 08:45 ask the trader WHICH system rings and sends Telegram today (never both - one sound per alert); the other runs silent. The old page stays on / . | calls on time; scorecard for both systems by 15:50 |
| Mon 23 - Tue 24 | fix what the live day shows; any page that slipped (only the non-trading ones may: Journal, Reference, Replay, Settings, Help) | - |
| **When the trader says "switch on"** (after 15:35 or a weekend) | S20 girtrader.com serves v2; old page to /old (kept); old alarm layer off underneath; Telegram decisions channel from v2 | live page = v2; /old works; one sound per alert |

Must be ready for Monday no matter what: data feeds + engine + Desk, Plan card, Sectors, My trades, Option chain, Futures & OI,
Phone, Scorecard. If anything else slips, say so on Sunday 20:00 with its finish time - never ship an untested number.

---------------------------------------------------------------------------------------------------------------------------------

## 6. THE ONE PASTE LINE (for the trader to give the server)

> Read intraday_patches/BUILD_PLAN.md and the design files in intraday_patches/design_v3/ from GitHub branch ccr-67e340f1-sko8xd of my repo, then start building the new girtrader.com now on /preview - data, decision engine and pages in parallel, day and night through the weekend - so it runs LIVE on /preview for my test on Monday 23 Nov from 08:30. Live services and the live page restart only after 15:35, nothing is deleted, only I say "switch on", and report your progress to me every evening.
