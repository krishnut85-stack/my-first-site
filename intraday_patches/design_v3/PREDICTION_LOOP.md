# GIR PREDICTION LOOP - THE ONE SPEC (20 Nov 2026)

Evening prediction -> trading-day confirmation -> live news calls -> analyst BOTTOM / TOP calls -> scoring.
Merged by the desk chair from three desk drafts (the senior F&O dealer, the sector-first options buyer, the market-intelligence /
news desk). The server team builds from this file. Requirements R52-R56 in REQUIREMENTS.md point here.

**THE TRADER'S WORDS (20 Nov, binding):** "The study, the knowledge, AI knowledge, engage the brain, everything has to be done
together, and then it has to PREDICT: 'this will go up' the day before. And when it goes up on the trading day, then you give the
signal: 'Hey, I predicted this is going up, the sector is also going up' - something like that. And during the market, if some news
comes, you have to tell me: 'this is news, this can go up.' And if some shares in a sector are already going down and some analyst
says this is the bottom, you should tell me: 'Hey, this is the bottom, stop.'"
Earlier: find the RIGHT MOVE from the market day and the sector, CE and PE both, minus moves as much as plus moves.

**Rules for every number below.**
- `[S]` = a starting value. The source that sets the real one is named where it matters: MS = movestudy_report.txt, PS =
  preopenstudy.py (being built), EM = event memory, LS = live scoring after 30+ cases. Re-fit monthly, moving only halfway (E6 rule).
- Every number shown to him comes from code and the study / scoring files, never from the AI's memory.
- Nothing here is tied to a date or a share. Share names in examples are illustrative shapes only. Replay tests score GIR against
  what really happened in the data, never against a list of names written by hand.
- CE and PE are scored by the same code with mirror rules, everywhere. The counts may differ; the rules never do.
- GIR never places orders. "Block" in this file always means GIR stops calling something; he can still trade in Kite.

---

## 0. WHAT THE EVIDENCE FORCES (read first)

From onset_results/movestudy_report.txt (737 days, 218 shares, 127,279 share-days, about 173 shares a day on average; the store is
still MIXED, so re-read when histstore finishes):
- About **34 up and 37 down 2%+ moves a day** (from the open). 64-68% start AT 09:15 (open-drive); 87-91% have started by 09:45.
- A 2% move is a quarter done 1-2 min after its onset and **half done 19-24 min after** (no-gap: 23-24 min; gap: 6-7 min).
  Clock time of half done: about 09:38-09:44 (no gap), 09:21-09:23 (gap).
- **No intraday signal warns before the move** (BEFORE = 0-5% for every set). Every first fire of ORB5 / PDH / ORB15 loses about
  1.1-1.9% of the premium after 1.5% costs (section 5, EVERY FIRE). So **the early warning has to be the evening / 09:08 prediction.**
  Intraday signals only time the entry on a share already named.
- Two signs help timing and held out of sample: **yesterday's high / low break** (PDH: lift 1.36 CE / 1.33 PE tuning, 1.32 / 1.33
  held out) and **the volume surge** (RVOL: lift about 1.6).
- Waiting for sector CONFIRMED (E3) caught only 19% (CE) and 29% (PE) early, against 46-48% for ORB5. **Sector is a GRADE, not a gate.**
- Market day: NIFTY-up days 51.6 CE vs 25.7 PE moves a day; NIFTY-down days 24.0 CE vs 70.9 PE; mixed (448 of 737 days, 61%)
  30.6 CE vs 31.5 PE. Even on a down day there are about 24 CE moves, so the CE list is never empty by nature.
- **Base rate** (the number every prediction must beat) = the day's same-side 2%+ movers divided by that day's F&O universe,
  computed in code each day. On the study's average: about 20% CE and 22% PE per share-day; about 30% CE on NIFTY-up days and about
  41% PE on NIFTY-down days.
- The v2 review: the engine was late, PE-only, rang 132-163 times a day, and its GO NOW check approved 57 of 57 cards.

What cannot work, and what we do instead:
1. "Find it during the day before it moves" - the study rules it out. Instead: the evening list plus trigger prices.
2. "Name all 70 movers the evening before" - overnight news and flow drive many of them. The list is judged on precision and lift
   over the base rate; coverage of the day's movers is reported separately. The list is never padded to look busy.
3. The gap part of a move is not tradable for an intraday option buyer. Predictions are scored on the tradable leg (open -> 15:10,
   SECTOR_LINKS C1). A gap the predicted way is shown as "GAP TOOK x%" with a pullback trigger, never a chase.
4. An AI "predicting" from narrative alone is the v2 failure. Code builds and ranks; the AI explains, red-teams and may move a grade
   by one step. The AI's changes are scored separately against the code ranking.
5. The AI cannot be back-tested over 3 years: the model knows history up to about June 2026, so any replay before about July 2026
   leaks hindsight. The CODE layer is tested on the full 3 years; the AI layer only on days after July 2026 and live.
6. "This is the bottom" is not a fact. What is real intraday is the flow a public call causes. A bottom call is treated as a risk
   event for PE holders and a reason for GIR to stop issuing new PE calls, never as a forecast.
7. If the evening list has no edge, the whole loop has none. Until the scorecard proves lift, every card says **NOT PROVEN**.

---

## A. THE EVENING PREDICTION (19:45; checked 22:45; updated 07:15 and 09:08)

### A1. Clock
| Time | What | Who |
|---|---|---|
| 15:35-16:30 | Score the day (E). Tonight's weights come from these hit rates. | code |
| 16:30-19:15 | Read after-hours filings and results (NEWS_READING_PLAN tiers). Load bhavcopy, futures OI, FII / DII provisional, whole-sector closes (R49), US pre-market. | code + Haiku / Sonnet |
| 19:15 | CANDIDATE BUILDER: every F&O share, both sides (A2). | code |
| 19:45 | THE BRAIN (A3), then the red team, then code validation. Prediction version N19 published. | Opus, Sonnet, code |
| 22:45 | Cancel check against the US open, DXY, US10y, LME. Pushes a line ONLY if a prediction is CANCELLED or changes grade. | code |
| 07:15 | Update U07: US closes, ADRs, LME / SHFE, Brent, DXY / US10y, GIFT, Asia, overnight filings and gazette sweep (NEWS_TO_SECTOR C7). | code + Opus |
| 09:08 | Pre-open version P09 (A5). **THE LIST FREEZES AT 09:08.** | code + one Sonnet call |

Weekend / holiday: the last trading day's 19:45 list is for the next trading day (holiday-aware, e.g. NSE closed 24 Nov), with a
code re-check at the Sunday 21:00 digest and the normal 07:15 / 09:08. No Opus on non-trading days except that one 19:45 run.

### A2. Layer 1 - CODE: the candidate table (closed vocabulary: today's F&O list minus ban)
Every F&O share gets a CE score and a PE score from the same rules. Each evidence row has an ID that the card quotes.

Evidence sources:
1. **Chains / links** - CHAIN_OF_EVENTS B4 grade points per driver -> sector -> share; LINK_BOOK and SECTOR_LINKS rows that fired
   today, run through BOTH sides (losers PE, winners CE). PROVEN rows (SECTOR_LINKS C3: 30+ events, 58%+, 8 points over normal) carry
   their measured weight. IDEA rows carry weight 0, are shown as "IDEA - NOT PROVEN" (LINK_BOOK E4).
2. **News of the day** - NEWS_TO_SECTOR_ENGINE items: exposure x shock, minus priced-in.
3. **Stories** - EVENT_MEMORY open stories with a catalyst inside 1 session, STORY BACK, firm dates, denials.
   Results tomorrow are NOT a prediction: they are flagged "results - IV-crush risk" (E7).
4. **Broker / TV calls** of the day with a NEW stance (BROKER_CALLS: a change, not a repeat), weighted by the house's / voice's
   shrunk hit rate.
5. **After-hours filings** of F&O names: orders of 5%+ of revenue, block deals, pledges, regulator orders.
6. **Sector** - today's whole-sector move vs NIFTY (R49), close near its extreme, 3-day run, breadth, futures build-up across the
   basket. Whether a sector continues or reverses next day is MEASURED by PS, never assumed.
7. **The share's own state** - close in the top / bottom 20% of its range (within 0.25 ATR of the high / low), distance in ATR to
   yesterday's and the 20-day high / low, RVOL today, NR7 / inside day, EXTENDED (range used > 1.2 ATR), 1- and 5-day RS vs sector,
   futures build-up over all months (LB / SB / SC / LU), delivery %, OI change.
8. **Global witnesses** - ADRs, US / Asian peers, LME / SHFE / Brent / gold, USDINR NDF, GIFT: the expected gap per sector
   (NEWS_TO_SECTOR C8). Live at 19:45, final at 07:15.
9. **Gates, not scores** - ban, MWPL 85%+, expiry-week rules, event locks (E0).

Score per share s and side d (log-odds):
`score(s,d) = log-odds of base(d | market-day call) + sum over sources of w_source x strength`
- `base(d | day type)` comes from MS / PS per day type, weighted by the market-day call's probabilities (A4).
- `w_source` = the shrunk lift of that source from E4. Until PS supplies measured weights: equal-weighted z-scores, no hand tuning.
- A source with n >= 30 and no edge has w = 0 (E8: "a voter with no edge counts zero").
- Two drivers on one share are NETTED (input vs output cost, etc.), never voted.

Output: the top 15 per side [S] go to the brain, plus every share in a sector past its threshold. **Every candidate's score is
stored, including the unpublished ones**, so scoring has no selection bias.

Calibration: until PS reports, a probability is not shown. Once PS gives a held-out table (code layer only), the card shows that
probability labelled "study". After 100 scored lines per side and 30 live days, an isotonic map per side, re-fitted weekly, replaces it.

### A3. Layer 2 - THE BRAIN (Opus 5.5, effort high, one call at 19:45; effort medium at 07:15)
Input: the candidate table with feature rows and data ages; only the knowledge rows the candidates touch (link book, sector links,
chains, event-memory cards, broker calls); the day's news digest as stored verdicts (not raw text); the market-day inputs (GIFT, US
futures, FII / DII, VIX, breadth trend); the hit-rate table from E (per source, kind, sector, CE and PE separately).

Its jobs:
1. Write WHY with **both sides of every driver** ("copper -1.8%: PE cables / metals - CE autos / durables"; BUILD_PLAN 1.7).
2. Run LINK_BOOK C traps and NEWS_TO_SECTOR C4 "scope before sign"; name the trap number.
3. Move a candidate's grade by AT MOST one step, with a quoted reason; or VETO it with a quoted fact.
4. PROPOSE a share outside the candidates only with an evidence ID that code verifies. A proposal is shown as IDEA in the watch
   fold, never in the scored list.
5. Write the market-day paragraph (strongest driver and strongest counter-driver) and the sector calls.
It never invents a ticker, never writes a price, never picks a strike (E7 code does).

**Red team (Sonnet 5.5, one call):** argues the other side of each line - input or output cost? priced in? scope? crowded? who wins
if this is bad? A sign disagreement drops the line to the watch fold. Its strongest point becomes the card's AGAINST line.

**Layer 3 - code validators:** ticker in today's F&O list; every number exists in the data; trigger and cancel on the right side;
grade inside the rubric; any hit rate quoted equals the table value; same-sector / same-driver concentration shown; both sides
present. Reject and retry once, then drop the line.

### A4. The market-day call (UP / DOWN / MIXED with probabilities)
- Defined on the tradable leg: UP = NIFTY open -> 15:10 >= +0.5%, DOWN <= -0.5%, else MIXED [S, PS re-defines].
- Code baseline from GIFT vs prior close, US close and futures, ADRs, DXY / US10y, Brent, Asia open, FII flow, VIX, breadth trend.
  Opus writes the reason. Shown with the GIFT gap estimate and its range.
- Default MIXED unless p(up) or p(down) >= 0.5 [S]. MIXED is 61% of days, so the call must beat "always mixed" and shows its record
  ("market call right 14 of 22").
- The call TILTS the base rate (A2) and therefore the list mix. It never zeroes a side.
- 09:08 re-call from the pre-open index; PS measures how much better 09:08 names the day.

### A5. Updates - each writes a NEW row (STANDS / CHANGED / CANCELLED / ADDED); rows are never edited
- **22:45 (code):** cancel facts checked against the US open. Telegram only on CANCELLED or a grade change.
- **07:15 (code re-score, then Opus medium):** each line STANDS / CHANGED (new level or grade) / CANCELLED (reason); up to 2 new
  lines per side, marked "NEW 07:15"; the market-day call re-stated.
- **09:08 (code + one Sonnet call, no Opus - there are 7 minutes):** pre-open IEP gap, imbalance and pre-open volume vs its 20-day
  median, per predicted share (F09):
  - GAP AGREES (0.3% to 1.0% or 0.6 ATR its way [S, PS]) = ARMED: "watch 09:17". A small gap (under 0.3% either way) is ARMED too.
  - GAP TOOK IT (over that, its way) = "GAP TOOK x% (about y% of the usual move)". Trigger becomes the opening-range hold (A6);
    otherwise a pullback to VWAP only.
  - GAP AGAINST (1%+ or 0.6 ATR the other way [S]) = AT RISK: no entry until it reclaims yesterday's close. Not auto-cancelled;
    PS measures how often these recover. CANCELLED if 09:20 trades beyond the cancel price.
  - The Sonnet call writes each line's REJECT RULES as code-checkable conditions (premium cap, spread, IV vs 20-day, distance to the
    nearest wall, break-even move) - used by B instead of a live AI veto (G).
  - One summary ring at 09:08: "ARMED: 4 UP / 3 DOWN · market MIXED".
- **After 09:08 a prediction never changes side, trigger or cancel for the day.** Only its STATE moves (B). Nothing is added to
  "predicted" during the day; a new idea is a news call (C) or a drill-down mover marked NOT PREDICTED.

### A6. One prediction line (stored and shown)
- **Side** UP = CE / DOWN = PE · **share** · **sector** (whole-sector basis) · **role** LEADER / DEPENDENT / LAGGARD (E4).
- **WHY (+):** at most 3 drivers, each with its counter-driver, proof status (PROVEN Lxx n= / NOT PROVEN) and source ID.
- **AGAINST (-):** the strongest counter-evidence, always written (from the red team).
- **TRIGGER (code):** CE = first 1-minute close above yesterday's high with RVOL at the same time of day >= 2.0 [S, MS / PS].
  PE = mirror on yesterday's low. On GAP TOOK IT: the high (CE) / low (PE) of the first 3 minutes [S], held, RVOL >= 2.0, with a
  GAP-HOLD line (CE must not fall back below yesterday's high; PE mirror).
- **CANCEL (machine-readable, any one is enough):** a PRICE written before the open - CE: the nearer of yesterday's low and open
  -0.8% [S, PS]; PE mirror - plus FACTS: an overnight driver reversing past its threshold, a denial or scope change, a contrary broker
  stance change, GIFT against by more than 0.8% for beta > 1 shares [S].
- **EXPECTED MOVE:** the share's own median base -> peak on its past 2%-move days (MS: about 3.3% CE / 3.2% PE across shares);
  fallback 1.0 x ATR14 %. Used for TOO LATE.
- **CONFIDENCE:** a grade STRONG / MEDIUM / WEAK always, with the side's base rate beside it. A probability only when calibrated
  (A2): "41% (base 20%, study n=180) MEDIUM". Never a % from the AI. Before calibration: "MEDIUM (base 20%) - NOT CALIBRATED".
- **STRIKE** per E7 (ATM / 1 ITM, current or next month in the last sessions), "premium at the 19:45 close", premium limit.
- **Chips:** results tomorrow (IV crush), ban, MWPL, AT RISK, GAP TOOK.
- The market-day call and the sector call it belongs to; made_at; version.

### A7. List size (both sides always computed and shown)
- Up to 8 lines per side [S, PS] in the scored list: only lines with probability >= 1.6x the side's base rate (once calibrated) or
  grade MEDIUM+ (before), ordered by score.
- If a side has fewer than 3 such lines, the best 3 of that side are shown in a **WATCH ONLY - below the bar** fold, labelled WEAK.
  They are scored separately and never ring. An empty scored side says why: "No CE prediction tonight - nothing beats the base
  rate; best was X at 0.24." This keeps both sides visible every day (the v2 PE-only failure) without padding the scored list.

### A8. Storage (append-only, replayable; BUILD_PLAN 0.3)
- `prediction(id, trade_date, version N19/C22/U07/P09, made_at to the second, side, symbol, sector, role, market_call, market_p_up/
  down/mixed, score, code_rank, grade, p_cal, p_source, base_rate, expected_move, trigger_rule, trigger_px, volume_rule,
  cancel_px, cancel_facts_json, strike_plan, why_json[], against_json[] (each: feature id, value, weight, proof id or NOT_PROVEN,
  source id), ai_grade_change and its quote, reject_rules_json, model, prompt_ver, inputs_hash, data_ages_json)`.
- `prediction_event(pred_id, ts, status, price, sector_pct, nifty_pct, rvol, note)` - statuses STANDS / CHANGED / CANCELLED / ADDED /
  ARMED / AT_RISK / NEAR / TRIGGERED / CONFIRMED / LATE / FAILED / STALE / EXPIRED / DONE.
- `candidate_log` - every scored share, both sides, every version.
- `market_day_call(version, made_at, p_up, p_down, p_mixed, drivers)`.
- No look-ahead: scoring uses only data after made_at. Every version is scored on its own (does 07:15 / 09:08 add anything?).
- "Ask the desk": the Analyst page answers "why is X predicted?" from these stored rows, never from a fresh AI guess.

---

## B. THE TRADING-DAY CONFIRMATION SIGNAL ("I predicted this is going up, the sector is also going up")

### B1. One state machine per prediction, code only (no AI on the critical path)
WAITING -> ARMED (09:08) -> NEAR (within 0.3 ATR of the trigger, silent) -> TRIGGERED -> **CONFIRMED (ring)** -> DONE.
Or LATE, FAILED, CANCELLED, STALE, EXPIRED. Checked on every 1-minute close, plus a tick check for the trigger cross.

### B2. CONFIRMED needs ALL four, on a closed 1-minute bar
1. **SHARE:** the trigger crossed the predicted way (1-minute close), RVOL at the same minute >= 2.0 [S, MS].
2. **SECTOR THE SAME WAY** (R49 whole-sector basket): sector % from the open the same sign and at least 0.3% [S], breadth over all
   listed shares >= 60% the same way [S]. Grade A when the sector is E3 CONFIRMED; grade B when it only agrees (FORMING). Never
   waits for E3. The share moving alone = grade C: a silent card "moving, sector not with it", no ring.
3. **MARKET DAY AGREES:** NIFTY % from the open the same sign, or flat within ±0.2% [S]. 0.2-0.4% against: rings only for a LEADER,
   marked "AGAINST NIFTY". More than 0.4% against: silent card "share + sector agree, NIFTY against".
4. **GATES:** not banned, data fresh (R09), lock room > 0 (E9), the 09:08 reject rules pass, the E7 strike gate passes - or the
   better strike is named ("spread 3% - take the 1 ITM / wait for 09:20"). No tradable strike at all = "no tradable strike - X",
   no ring.

**Earliest ring: the close of the 09:16 bar (09:17:00).** The 09:15 candle includes the pre-open. This departs on purpose from
BUILD_PLAN E3 ("never before 09:20") and E8 ("no orders 09:15-09:20, entry window 09:30"), for PREDICTED shares only: by 09:38-09:44
the median 2% move is already half done, and on gap days by about 09:21. E3 stays the definition of sector CONFIRMED (a grade).
Unpredicted ideas keep E8's window. If PS shows 09:17-09:20 option spreads make it untradable, revert. **Needs his yes.**

**Ring window:** 09:17-11:00 [S, MS: 87-91% of onsets by 09:45]. Not triggered by 09:45 = STALE (grade drops one step, may still
ring). After 11:00 a trigger cross is a silent "late trigger" row. 14:30 = EXPIRED, manage only (E8).

### B3. The card (once per prediction per day)
Line 1, his words:
"PREDICTED last evening: `<SHARE>` UP · sector `<SECTOR>` up +1.1% (breadth 9/12, FORMING) · NIFTY up +0.4% · trigger `<price>`
crossed 09:17 with volume 2.3x · move left ~70% of usual · FRESH till 09:22"
Line 2 (R14 / E8 fields): MUST HOLD above VWAP `<p>` with the sector above its VWAP · TOO LATE after `<p>` · FAILS below `<cancel>` ·
Dec `<strike>` CE ≤ ₹x, spread 0.9% · stop / target in premium AND share price · hold until · exit by 15:10 · AI line (G), filled in
about 20 s after the ring, never delaying it.
PE is the exact mirror ("PREDICTED last evening: `<SHARE>` DOWN · sector `<S>` down -1.3% ...").

### B4. TOO LATE ("half the move gone")
- FRESH for 5 minutes after the trigger [S, MS reaction budget 0-5 min].
- LATE when ANY: the move from the day's base its way >= 0.5 x EXPECTED MOVE; range used > 1.2 ATR (E5); 20 minutes since the
  trigger (6 minutes on a gap day) [S, MS / PS].
- Late before CONFIRMED: no ring. The card says "TOO LATE: +1.9% of the usual ~3.4% done - pullback only: VWAP `<p>` / first higher
  low (CE), first lower high (PE), 1 lot".
- Late after CONFIRMED: the card updates silently "half the move done - no new entry; manage only". No second ring.
- The E5 trend-day exception still applies: a LEADER stays LEADER with a pullback trigger.

### B5. FAILED, said plainly - no flip-flopping
- FAILED when a 1-minute close crosses the cancel price, or a cancel fact lands.
- Text: "PREDICTION FAILED: `<SHARE>` - I predicted UP; it is -1.2%, below the cancel `<p>` · `<SECTOR>` -0.6%. I was wrong on this
  one. No CE on it today."
- Silent on page and phone, plus one Telegram line. It RINGS only if he holds the share (then E10 exit logic, his trades only).
- After FAILED the prediction lane NEVER issues the opposite side on that share that day. The opposite side can appear only through
  C (news) or D (bottom / top) with their OWN reason, labelled "this reverses my 19:45 prediction"; through the drill-down or other
  engine lanes not before 30 minutes [S] and labelled NOT PREDICTED.
- One ring per prediction per day; no cancel within 10 minutes of a ring; no re-issue within 15 minutes (review fix 1).

### B6. Unpredicted big movers still appear
Every F&O share ±2% from the open with RVOL >= 2, or in COMING UP NOW, shows in the sector drill-down (R50 / SECTOR_DRILLDOWN) and the
Desk lane with a chip: "PRED ▲ 19:45" / "PRED ▼ 09:08" or grey **NOT PREDICTED**, the reason found (news / story / UNEXPLAINED) and
the same LATE rule. Unpredicted movers never ring through B; their path to a ring is news (C), rotation (E11) or basket shock (E12),
each with its own reason. Every unpredicted mover is a MISS row in E.

### B7. Honest note
The confirmation adds no edge of its own: a bare breakout ring loses money after costs (MS section 5). Its value depends entirely on
the prediction picking better than the base rate. Hence the shadow rule in E7.

---

## C. LIVE NEWS CALLS ("this is news, this can go up")

### C1. Pipeline (reuse, not new) - 09:00-15:10
NEWS_TO_SECTOR_ENGINE A1-A12 and NEWS_READING_PLAN tiers: CATCH with first-seen time -> FAST PATH (< 2 s: phrase triggers and the
evening's scenario trees) -> Haiku frame (1-2 s) -> entity linker -> exposure matrix / link book, both sides, netted (code) -> Sonnet
for weight 4-5 and every negation / denial, with the blind second direction check (E12.4) -> EVENT_MEMORY match NEW / REPEAT /
NEW-FACT / DENIAL / OFFICIAL plus past reactions (within 10 s; 30 s for TV).
Target from first source to call: <= 60 s for filings, regulator pages and wires; 60-90 s for TV. Latency is measured every day.

### C2. Junk guard - never ring on a ticker match
- Tickers ONLY from the filing symbol, the alias table, or the ambiguous-name list settled by context words (NEWS_READING_PLAN B2),
  plus a Haiku yes / no "is this item about listed company X?" with a quote that code checks is in the text.
- A headline about a non-Indian product or company named like a ticker is dropped and logged as junk. The KEI ("Toyota's KEI-01
  pickup") and TITAN ("Ford vs Stellantis") cases are regression tests.

### C3. When a news call is made (all must hold; otherwise a silent News-page row)
- Impact 4-5 computed in CODE against company size (E12 table: an order over 5-10% of revenue; a small fine never). Not the model's word.
- NEW, NEW-FACT, DENIAL or OFFICIAL. A REPEAT with no new fact never makes a call ("repeat - fade only").
- At least one F&O share or sector mapped with a known sign.
- Haiku and Sonnet directions agree. If not, the card shows the disagreement and it is never a GO NOW.
- TV-only / "sources say" is capped at weight 3 (silent "TV ONLY - UNVERIFIED") unless it touches a share he holds or a live prediction.

### C4. The call - one line, both sides
"NEWS 11:42 · `<source>` (class A, 38 s after first source) · NEW · VERIFIED -> can go UP: `<A>`, `<B>` (`<sector>`) / can go DOWN:
`<C>` (`<sector>`) · story back: 3rd time, past median +1.8% (n=5, NOT PROVEN) · GO NOW only if `<A>` > `<price>` with vol 2x within
10 min · cancel if: denial / scope narrower"
- Labels always shown: NEW / REPEAT / DENIAL / OFFICIAL; VERIFIED (class A, or two independent sources) / UNVERIFIED - TV ONLY /
  SOURCES SAY; the source and seconds since the first source.
- Touches a PREDICTED share: merged into that card, not a second card. "NEWS AGREES with my 19:45 prediction" (grade up, no extra
  ring if already rung) or "NEWS AGAINST my prediction: X - in doubt; cancel if Y" (this one may ring: it protects him).

### C5. Price confirm before any GO NOW [S, EM / LS]
Within 10 minutes of first sight, the named share must:
- move its way by at least 0.3 x ATR14 (about 0.5% on a typical F&O share) from the first-seen price, with 1-minute RVOL >= 2;
- be on the right side of VWAP;
- with its whole-sector basket not against and NIFTY not against by more than 0.3%.
Then:
- UNVERIFIED: also needs a second independent source or the official document (E12.2). TV-only is never GO NOW.
- Moves 0.5% the other way within 5 minutes: "MARKET DISAGREES - no trade", closed.
- A move of more than 1 ATR (or 1.5%) in the 15 minutes BEFORE first sight: "already moved before the news - priced / leaked",
  one grade down, LATE rules apply.
- Text says up but price, breadth and IV say down in the first 3-5 minutes: no trade ("sell the news").
- No confirmation in 10 minutes: the call expires silently and is scored as a NEWS call, not a trade.
- A confirmed news GO NOW passes the E7 / E9 gates and the live Opus check (G) before it rings.
- Basket shock first (E12.1, price before news): the blue card "falling together - news not found yet", never a GO NOW on price alone.

---

## D. ANALYST "BOTTOM" / "TOP" CALLS ("Hey, this is the bottom, stop")

### D1. What counts - three kinds, treated differently
- **LIVE VOICE:** a TV / live-blog analyst or fund manager naming an F&O share or sector (F17 speech-to-text, CNBC-TV18 / ET Now /
  CNBC Awaaz; wires; live blogs; known analysts on X). Effect: minutes to hours.
- **BROKER NOTE:** a rating or target CHANGE after a fall (upgrade, "risk-reward turns favourable") or after a rally (downgrade).
  Effect: next open, often fading in the first 30-60 min if nothing new (BROKER_CALLS thread per house).
- **STRATEGIST SECTOR VIEW:** "metals have bottomed", "IT looks toppish". Effect: weeks. Background tilt only.

Phrases (code filter first, then Haiku classifies share or sector, BOTTOM / TOP / plain BUY / SELL, level quoted, speaker, evidence
quote; code checks the quote and the entity):
- BOTTOM: "bottom is in / bottomed out", "worst is over", "best price to start buying", "accumulate at these levels", "value
  buying", "selling overdone", "support at X will hold", "oversold, bounce due", "capitulation"; Hindi equivalents on Awaaz.
- TOP: "topped out", "book profits", "overbought", "overheated / frothy", "sell on rise", "avoid fresh buying", "rally done",
  "target achieved, exit".

It is a BOTTOM call only when the share or sector is ALREADY FALLING [S, EM]: share down 2%+ from the open or -1.5 ATR, or 5%+ over
3-5 days; sector basket down 1.5%+ today with breadth 70%+ down, or 4%+ over 3 days. TOP is the mirror (rising). Otherwise it is an
ordinary TV / broker call (BROKER_CALLS / F17 scoring path).

### D2. The alert, his words kept
"BOTTOM CALL by `<voice>` (`<channel / house>`, 12:05, TV ONLY | VERIFIED) on `<SHARE>` at ~`<price>` after -6% today - **STOP: no new
PE here.** You hold `<SHARE>` PE: protect at `<level>` / book half. Price test till 12:50: higher low · VWAP `<p>` · short covering ·
breadth. This voice: 6 of 10 held (NOT PROVEN if n < 8)."
- Mirror: "TOP CALL by ... on `<SHARE>` - **STOP: no new CE here.** You hold CE: protect / book."
- Sector: "BOTTOM CALL on METALS (`<house>` note) - STOP: no new PE in metals for now."
- The word is always written "STOP: no new PE / CE" so it is never confused with his stop-loss alert (R10).

### D3. What the call is allowed to change - decision and why
**(a) His open position on that share, or in that sector on the threatened side: ALWAYS a ring** ("protect / trail to `<level>` /
book half"), on the phone too. It is a warning; GIR never exits for him. Follow-up E10: PROTECT (stop to cost) / BOOK HALF; EXIT the
rest if the test CONFIRMS the bottom. Why: these are his own exits, which R10 / E14 already let ring; missing a bounce on an open PE
costs more than a false alarm (the review's KAYNES PE after a 9% fall lost -4.99% in 60 minutes; PAYTM 19 Nov stopped falling the
moment the TV call came).

**(b) GIR's own NEW calls on the threatened side** (new PE after a bottom call, new CE after a top call) on that share: SUSPENDED
until the price test decides, at most 45 minutes [S]. A sector call suspends that sector's LEADERS too. The card stays visible with
"BOTTOM CALL - WAIT FOR THE TEST"; its rings are suppressed. A predicted PE not yet confirmed waits; one already CONFIRMED gets the
protect warning.
- Why suspend, not only warn: ringing a fresh PE into a publicly called bottom is the exact v2 failure. An entry right after a big
  fall is already late by the study (half the move gone ~20 min after onset) and faces the highest bounce risk, so skipping it costs
  little whether or not the analyst is right.
- Why not a hard block: R12 allows hard blocks ONLY for ban, loss lock and stale data; a voice with no measured record (n = 0 today)
  must not override his judgment. He can still trade in Kite - GIR simply does not call it.

**(c) Broker note before the open:** at 07:15 / 09:08 a PE prediction on that share drops one grade, or is CANCELLED when the note is
a stance change by a house with hit rate >= 55% at n >= 8 [S, EM]. Card: "upgrade - gap-up may fade; no PE until the first 30 min decide".

**(d) Strategist sector view:** a warning line only; lowers that side's evening grade by one step for 1 day. No suspension.

**(e) It NEVER creates a CE by itself** (nor a PE from a top call). A counter-side idea exists only after D4 CONFIRMED, as a GET READY,
and only for a voice or kind that is PROVEN (D5). No flip-flopping.

### D4. The price test (code, every minute, up to 45 minutes after the call; TOP is the mirror)
1. HIGHER LOW: no new low for 15 minutes and a 5-minute swing low above the call-time low.
2. VWAP RECLAIM: a 5-minute close above VWAP (if VWAP is more than 2 ATR away, the last 15-minute swing high instead).
3. SHORT COVERING: futures OI down at least 1% over all months while price rises off the low; nearby PE OI unwinding.
4. BREADTH TURNING: the sector's members above their 15-minute low go from under 30% to over 60%, or the basket is 0.5% off its low.
5. PE PREMIUM falling while ATM IV is flat (sellers leaving, not IV crush); NIFTY not making a new low.

Verdicts (one silent line each; a ring only if he holds the side at risk):
- **BOTTOM CONFIRMED** = VWAP reclaim + at least 2 more. Suspension stays for the day.
- **BOTTOM REJECTED** = a 5-minute close 0.3% (or 0.3 ATR) below the call-time low with RVOL >= 1.5 while below VWAP. "BOTTOM CALL
  REJECTED by price - PE ideas back on." Suspension lifts.
- Neither in 45 minutes: "CALL EXPIRED - NOT PROVEN". Suspension lifts; the warning stays on the card.

### D5. The house's own hit rate (EVENT_MEMORY TV CALLS / broker threads)
- Each call stored as an EPISODE: kind (live / note / strategist) x BOTTOM / TOP x voice / house x side.
- HELD = no new low beyond the call low by 0.3% AND +1% (or +0.5 ATR) from the call price within 60 min; also scored at 15:10, day 2, day 5.
- Measured AGAINST A CONTROL: falls of the same size, same kind of day, no call, from the same minute store. Falling shares bounce
  often anyway; the voice must beat that.
- The price test's own verdict is scored too (is the test or the voice better?).
- Sample rules (EVENT_MEMORY D): n < 3 = "new voice, no record"; 3-7 = counts only, capped MEDIUM; 8-19 = hit rate; 20+ in both halves
  = STRONG.
- After n >= 20 [S]: a voice at or below the control drops to INFO ONLY (told, no suspension). A voice 10+ points above the control
  may also open a counter-side GET READY ("CE on the bounce, half size") - only after BOTTOM CONFIRMED, never a GO NOW on its own.

**Dependency:** TV voices need speech-to-text (Deepgram, about $5-7 a trading day, outside the AI budget, paid - needs his yes).
Without it D works only from wires, live blogs and broker notes.

---

## E. SCORING (data cut 15:35; scorecard by 15:45; code only, Sonnet writes the plain-words sentences)

### E1. What is scored
Every prediction line, every version separately (N19, U07, P09) including CANCELLED lines (was the cancel right?) and the WATCH-ONLY
fold; every confirmation ring and silent card; every LATE / FAILED message; every news call; every BOTTOM / TOP call and its test
verdict; every suspension (the PE it blocked, scored as if taken); every rate-limiter demotion, logged by requested and final lane
(review fix 6). Every item from the moment it was shown, on the tradable leg, windows ending 15:10.

### E2. Labels [S], all minute-bar based
- **BIG RIGHT:** 2%+ its way from the open by 15:10.
- **RIGHT-TRADABLE:** the trigger filled, then +1% its way before -0.6% against within 60 min (the study's HIT60). Option proxy
  after 1.5% and 3% costs beside it ("proxy" until recorded premiums exist - record option minutes from today).
- **RIGHT-NOT-TRADABLE:** the gap took it, or the trigger never filled while the share moved its way.
- **FLAT:** neither. **WRONG SIDE:** the cancel hit first, or 1% against from the open. **NOT TRIGGERED:** day move still recorded.
- **HOW EARLY:** ring minute vs the move's onset / breakout (MS: BEFORE / EARLY / LATE). **MOVE LEFT:** % of the day's move still
  ahead at the ring, and MFE60.
- **News calls:** direction right at +5 / +15 / +30 / +60 min on the abnormal move (share - beta x sector - NIFTY); seconds from first
  source; VERIFIED or not; price-confirmed or not; junk mappings counted.
- **Bottom / top:** HELD / REJECTED vs the control; the PE premium saved or lost from the call to 15:10.
- **MISS:** every 2%+ F&O mover (from the open) not predicted and not called; the headline counts 3%+. Each is searched for a chain or
  news that should have fired (CHAIN_OF_EVENTS B5).

### E3. Baselines, printed next to every hit rate (CE and PE separately)
(a) the day's same-side base rate ("beat the day by +x pts", so a falling day does not flatter PE); (b) a random same-sector,
same-side share; (c) "yesterday's top movers continue" and "yesterday's strongest / weakest sector"; (d) market-day only: the
highest-beta shares on the day's side; (e) the code's own top-ranked names (the AI vs code test). LIFT = ours / baseline. Nothing is
called "working" without lift.

### E4. Hit-rate store (feeds tonight's brain)
- By kind x side x source: each link-book row, chain, sector link, story type, broker house, TV voice, news event type, source class,
  model and prompt version, version time, market-day type, and the AI grade change vs the code rank.
- Shrunk: (hits + 10 x base) / (n + 10) [S]. Shown with n, for 20 days, 60 days and all time.
- Code turns a source's shrunk lift into its A2 weight. A weight changes only when n >= 30 and only halfway (E6). At or under base
  after 30 cases = weight 0.
- Weekly calibration (Brier, buckets vs actual). Confidence stays "NOT CALIBRATED" until 30 scored days and 100+ lines per side.
- If the AI's grade changes do not beat the code ranking after 30 adjusted cases, the AI stops changing grades and only writes.

### E5. CE / PE balance audit (daily)
Counts of predictions, rings, rights and misses per side. Flag **SIDE BIAS** when, over 5 days, a side's share of predictions or
rings differs by more than 20 points from that side's share of the market's own 2% moves. Flag any day with fewer than 3 lines
(scored + watch fold) on either side.

### E6. The daily scorecard he sees (15:45: Desk card, phone Today screen, one Telegram message; full on Shift F8)
Illustrative values, CE and PE always on separate lines:
- "MARKET CALL: DOWN - right"
- "PREDICTED last evening · UP 6: right 3 (2 tradable), flat 1, wrong 2 · DOWN 5: right 3, wrong 2 · beat the day CE +11 pts, PE +6 · 07:15 changes helped 2 / hurt 1"
- "CONFIRMATIONS rung 7: early 4, late 2, failed 1 (said so at 10:02) · move left after ring median 1.4%"
- "NEWS CALLS 5: right at 30 min 3/5 · median 41 s from first source · junk 0"
- "BOTTOM / TOP 2: PAYTM bottom HELD (PE protected) · METALS bottom REJECTED · PE blocked 1 (would have lost -0.9%)"
- "MISSED 3%+ movers 9 (CE 5 / PE 4), biggest `<SHARE>` -4.1% (not predicted, `<story>`) · RINGS 12 (peak 4 in 15 min) · AI $3.70"
- "20-day: predictions 34% right vs 20% base, 22% yesterday's movers · AI vs code rank +4 pts (n=180) · NOT PROVEN until day 20"

### E7. Shadow first
From the first live day, predictions and confirmations show on screen in SHADOW (scored, no ring). The confirmation ring goes live
PER SIDE only when 20 trading days show that side's prediction hit rate at least 8 points above baselines (a) and (d) (the
SECTOR_LINKS proof spirit). If he wants rings sooner, they carry "NOT PROVEN" and he decides.

---

## F. ON THE SCREEN AND THE PHONE

### F1. Where each thing lives
| Item | Desktop | Phone (R40) | Telegram |
|---|---|---|---|
| A. Evening prediction | Morning (Shift F1): THE PREDICTION board - market-day call on top, two equal columns UP (CE) green left / DOWN (PE) red right, 19:45 / 22:45 / 07:15 / 09:08 chips per line, the 09:00-09:08 pre-open gap column (R34) | TODAY tab | 19:45, 07:15, 09:08 (messages, not alarms); 22:45 only on a cancel |
| A. Predicted today | Desk (F1): "PREDICTED TODAY" lane on top, one row per line with its live state chip | TODAY tab | - |
| B. Confirmation | Desk: amber hero card + one row in the ONE ACTION feed (R17); the lane row turns amber | CALLS tab | yes, ~5 s after the page |
| B. LATE / FAILED | grey line in the same lane row | TODAY tab | FAILED line |
| B6. Not predicted | Sectors F2 / Rotation F3 drill-down: chips PRED ▲ / PRED ▼ / NOT PREDICTED on every share row | - | - |
| C. News call | News F4: call cards pinned on top, story drawer (EVENT_MEMORY); one-line row in the ACTION feed (R44: no news box on the Desk) | CALLS + NEWS tabs | verified calls |
| D. Bottom / top | ACTION feed row; F7 Share header; F6 Positions row of the held trade, pinned | NOW / MY TRADES tab, pinned | yes |
| E. Scorecard | 15:45 card on the Desk; full on Shift F8 (PREDICTIONS tab first: rows, misses, per-source table, calibration, after-cost proxy) | TODAY tab | 15:45 |
| Why / Ask the desk | Analyst F8: the brain's reasons, both sides, for and against; ASK "why is X predicted?" from stored rows | - | - |
| History | Share F7: the share's prediction history and the record of the voices that called it | - | - |

### F2. Rings - his ceiling 50 a day and 6 in any 15 minutes; target a median of 10-15
One AlertManager owns every ring; a demoted card never rings; a ring queued more than 3 minutes is delivered silently (no late
ring); the log keeps the requested lane, the final lane and "held back (ring limit)".
Priority when a 15-minute window is full (lower ones become silent cards, chosen by score, never by order of arrival):
1. His own exits - STOP / BOOK HALF / EXIT / 15:10 (never counted, never dropped).
2. BOTTOM / TOP on a held position; FAILED on a held position.
3. PREDICTED + CONFIRMED, grade A / B, STRONG / MEDIUM first. At most one per prediction a day. In 09:17-09:30 only the top 6 by
   score ring; the rest light up in the lane.
4. NEWS CALL: impact 5 VERIFIED and price-confirmed, or impact 4 on a predicted or held share; NEWS AGAINST a prediction.
5. BOTTOM / TOP that suspends a live predicted call.
6. The 09:08 ARMED summary (one soft tick).
Everything else is silent: unpredicted movers, NEAR, LATE, FAILED (not held), REPEAT news, TV-only items, strategist views.

Expected per day [S, LS]: 09:08 summary 1 · confirmations 3-8 · news 0-6 · bottom / top 0-3 · his exits as they happen · other engine
GO NOWs under a cap of 10. Typical total under 20.

Sounds (R10 / E14, one per type, no new sound families): a confirmation IS the GO NOW for a predicted share - the bright chime once;
news call and the 09:08 summary - one soft tick (the GET READY sound); bottom / top on a held position - two low notes once (his exit
family; his stop-loss alarm keeps its own repeat). Nothing else sounds.

Conflict to settle with him: IA.md section 7 (at most 6 audible P2 a session, 1 per 10 min) is stricter than his 50 / 6. This spec
takes his 50 / 6 as the ceiling and IA's quiet target as the goal; the scorecard reports actual rings either way.

### F3. How each looks (one line each; green = CE / up, red = PE / down, amber = action, grey = info / failed / not predicted)
- Prediction: "▲ CE · `<SHARE>` · `<SECTOR>` LEADER · > `<yday high>` vol 2x · cancel < `<p>` · MEDIUM (base 20%) · why `<driver>` (+, PROVEN L05 n=34) · against `<counter>` · market MIXED 40/35/25"
- 09:08: "ARMED 4 UP / 3 DOWN · `<A>` gap +0.6% agrees · `<B>` GAP TOOK 3.1%: pullback only · market MIXED"
- Confirmation: "✓ PREDICTED last evening · `<SHARE>` UP · `<SECTOR>` +1.1% (9/12) · NIFTY +0.4% · `<trigger>` crossed 09:17 vol 2.3x · left ~70% · too late > `<p>` · fail < `<p>`"
- Too late: "◐ TOO LATE · `<SHARE>` +1.9% of ~3.4% done · pullback only: VWAP `<p>`"
- Failed: "✗ PREDICTION FAILED · `<SHARE>` predicted UP, now -1.3% < cancel `<p>` · I was wrong · no CE today"
- Not predicted: "• NOT PREDICTED · `<SHARE>` -2.4% · `<SECTOR>` -1.2% · `<story>` · LATE · drill-down ›"
- News: "NEWS 11:42 · `<source>` 38 s · NEW · VERIFIED → UP `<A>`, `<B>` (`<sector>`) · DOWN `<C>` · GO NOW only if `<A>` > `<p>` vol 2x in 10 min · cancel: denial"
- Bottom: "BOTTOM CALL · `<voice>`, `<channel>` 11:05, TV ONLY · `<SHARE>` ~`<p>` after -7% · STOP: no new PE · your PE: protect `<p>` / book half · test VWAP `<p>` · voice 6/11 (NOT PROVEN)"
- Top: "TOP CALL · `<voice>` · `<SHARE>` ~`<p>` after +6% · STOP: no new CE · your CE: protect / book · test: lower high + VWAP loss"
- Scorecard: "UP 6: 3 right · DOWN 5: 3 right · beat the day CE +11 / PE +6 · rings 12 · missed 9 · AI $3.70"

---

## G. AI COST (prices cached 3 Nov 2026: Haiku 5.5 $0.10 / $0.50, Sonnet 5.5 $2 / $10, Opus 5.5 $4 / $20 per M tokens; cache reads Sonnet $0.10, Opus $0.20; Batch -50%)

CODE does: candidates, scores, triggers, 22:45 and 09:08 checks, the confirmation watcher, price tests, rings, scoring. **No AI on the
critical path of a ring.**

| Job | Model | Calls a day | $ a day (approx.) |
|---|---|---|---|
| 19:45 brain (~70-80K in: frozen knowledge prefix + candidate packet; ~10-15K out with thinking; effort high set explicitly) | Opus 5.5 | 1 (+1 retry) | 0.55-0.70 |
| 19:45 red team | Sonnet 5.5 | 1 | 0.10 |
| 22:45 cancel check | code (Sonnet sentence only on a change) | 0-1 | 0.02 |
| 07:15 update (~40-50K in, ~8K out, effort medium; 11 h after 19:45, so no shared cache) | Opus 5.5 | 1 | 0.35 |
| 09:08 reject rules + one sentence | Sonnet 5.5, effort low | 1 | 0.05 |
| News reading, every item once after code grouping (tiers 1 / 1b); bottom / top phrase tagging inside it | Haiku 5.5 | ~2,500 + ~300 deep | 0.90-1.10 |
| Weight 4-5 frames, denials, blind second direction check | Sonnet 5.5, cap 40 | 15-40 | 0.40-1.00 |
| Bottom / top verify (stance, level, kind) | Sonnet 5.5 | 5-15 | 0.25 |
| Live GO NOW check: before a news GO NOW rings; after a confirmation ring as the "AI: agrees / WAIT - reason" line (top by score). Gets premium, IV, spread, OI at the strike, days to expiry, explicit reject rules (review fix 5); 1-hour cache | Opus 5.5, effort medium, cap 8 | 0-8 | 0-0.40 |
| Scorecard sentences; nightly labels (story novelty, TV-voice tagging) | Sonnet / Haiku via Batch | ~200 | 0.10-0.20 |
| Confirmations, LATE / FAILED, price tests, scoring | code | 0 | 0 |
| **Normal trading day** | | | **about $2.7-4.0** |

- **Hard cap $5.00 per budget day** (16:00 to 15:59 next day, so the 19:45 and 07:15 runs count against the day they serve), checked in
  code BEFORE each call (estimate x price vs per-call / hour / day counters) plus the provider-side limit.
- **Ladder:** $3.50 -> GO NOW checks only for the 4 highest-score confirmations; $4.50 -> Sonnet only for impact-5 and denial items, no
  more Opus that day; $5.00 -> code + Haiku only, one message to him. Heavy news days are capped, not uncapped.
- The evening brain never drops - it is the edge. $1.00 of the cap is reserved for the 19:45 + 07:15 runs.
- Caching: frozen prefix (schema, F&O universe, aliases, exposure map, link book, chain table) before the breakpoint; live data last;
  no timestamps or unsorted JSON before it. Target 70-80% cache reads on live calls.
- Non-trading days: Haiku triage plus the one 19:45 run, about $0.5-1.
- The old E13 $20 cap and the 18 Nov $27 overspend are superseded by his $3-5.
- The v2 GO NOW check took 77-89% of the cost and approved 57 of 57 cards. Here it is capped at 8, off the critical path for
  predicted lines (code reject rules from 09:08 decide), and must show REJECT / WAIT on known bad cards in the replay before it ships.
- **Not AI money, each needs his yes:** TV speech-to-text (Deepgram, about $5-7 a trading day; cheaper: CNBC-TV18 all day + ET Now only
  09:00-10:30 and 14:30-15:30, about $2 less). D and TV news calls depend on it. The paid news archive for back-testing C.

---

## WHAT preopenstudy.py MUST ANSWER BEFORE ANYTHING RINGS LIVE
1. The lift of a 19:45 code list over the base rate, per side and per kind of reason (chain, sector follow-through, share state,
   story, broker), on held-out months.
2. Whether 07:15 and 09:08 improve it, and how much the pre-open gap alone explains.
3. Whether PDH + RVOL has higher lift on PREDICTED shares than on all shares; this sets the trigger, RVOL level and cancel level.
4. How often a predicted move is taken by the gap vs left for open -> 15:10.
5. Day-type base rates on the tradable-leg definition, and how often the 09:08 market-day call is right.
6. The confirmation window, the too-late fraction and the move left after a confirmation, CE and PE separately; whether 09:17-09:20
   option spreads are tradable.

## BUILD ORDER AND TESTS
1. The prediction tables and the scorer (E) first. Without them nothing can be judged.
2. The code candidate table, back-tested on the 3-year store against the base rate and baselines (no AI).
3. The AI layer, tested only on days after July 2026 and live, against the code ranking.
4. A 20-30 day replay with frozen as-of knowledge, then 2 weeks of live shadow (E7).
5. Replay checks, all scored from data, never from a hand list: 18 Nov (down day) and 19 Nov (up day) - both CE and PE lists present,
   confirmations within 5 min of the trigger, 50 rings or fewer a day and 6 or fewer in 15 min; 20 Nov (US fall night); 19 Nov PAYTM
   TV call - BOTTOM card within 30 s of the words, PE suspended, test run; 18 Nov KAYNES - no fresh PE ring after a 9% fall without
   the test; 19 Nov 12:44 Goldman - broker call raised, UNVERIFIED, no GO NOW before price confirms; KEI / TITAN junk - no ring.
6. Pass marks (from the review): cards before the move on the replayed days; CE present on up days; rings within the limits; the AI
   check rejects some cards; the after-cost proxy result is not negative.

---

## AGREED / DISAGREED (what the three desks said, and what this spec chose)
**All three agreed:** the prediction must exist by 19:45 / 09:08 because no intraday signal warns; code builds and ranks, the AI
explains and cannot invent tickers or prices; trigger = yesterday's high / low with RVOL >= 2; sector is a grade, not a gate; one ring
per prediction, FAILED said plainly, no opposite side from the prediction lane; unpredicted movers shown as NOT PREDICTED; bottom /
top calls ring on held positions and never hard-block him; scoring per source with shrinkage against baselines; PREDICTED shares may
confirm before E8's 09:30 window.

**Where they differed:**
| Point | Dealer (1) | Options buyer (2) | News desk (3) | Chosen and why |
|---|---|---|---|---|
| List size | min 3 a side, always | max 5, may be empty | 0-8, threshold, no quota | Up to 8 above the bar; if fewer than 3, a WATCH ONLY fold of 3 WEAK lines, scored apart, never ringing. Keeps both sides visible (v2 PE-only) without padding the scored list. |
| Base rate | ~20% | 15.5% CE / 17% PE | 16-18% | Computed daily from the day's universe. Draft 2 divided by 218 shares; the study averages ~173 a day, giving ~20% CE / 22% PE. |
| AI role | picks 3-8 from top 40 | drop / reorder / regrade one step; propose as IDEA | one grade step or veto with a fact | One step or veto with a quoted fact; proposals only as IDEA. Scored vs the code rank; dropped to writing-only if no gain in 30 cases. |
| 07:15 model | Sonnet | Opus | Opus | Opus (effort medium): overnight US / ADR news carries much of the call; fits the budget. |
| 22:45 | none | code cancel check | only on a grade change | Code check; Telegram only on cancel / grade change. |
| Confidence | probability marked UNCALIBRATED | grade only until calibrated | probability vs base with n | Grade always; a % only from the PS held-out table (code layer) or live calibration. An uncalibrated % misleads. |
| Gap handling | gap 0.3-2.5% armed, over = pullback | 0.3% = gap through | 1.0% / 0.6 ATR = gap took | 0.3%-1.0% (or 0.6 ATR) armed; above = GAP TOOK IT with opening-range trigger [S, PS]. |
| Cancel price | written price + fact | machine list | yday low or -0.8% from open | Nearer of yesterday's low and open -0.8% (CE; PE mirror), plus fact cancels. |
| Sector rule | +0.3% from open, breadth 60% | 0.3% from prior close, breadth 50% | same sign, breadth 60%, above its VWAP | 0.3% from the OPEN (the tradable leg), breadth 60%; A / B grades by E3. |
| NIFTY rule | not against > 0.3% | same sign; ±0.2% on mixed | same sign / ±0.2%; > 0.4% against silent | ±0.2% passes; 0.2-0.4% against only for LEADERs; > 0.4% silent. |
| Too late | half the move or 20 min (6 gap) | 50% of expected or 1.2 ATR | same as 2 | Any of the three; 5-min FRESH window. |
| Ring window / expiry | not set | STALE 09:45, EXPIRED 11:00 | ring 09:16-11:00, EXPIRED 14:30 | Ring 09:17-11:00; STALE 09:45 (grade down); EXPIRED 14:30. |
| News confirm window | 5 min, 0.5% | 15 min, 0.5% / 0.3 ATR | 5 min, 0.5 x 15-min range; expire 10 | 10 min, 0.3 ATR (~0.5%), VWAP side, sector and NIFTY not against. |
| Bottom test verdict | 3 of 5 | 3 of 5 | VWAP + 2 more | VWAP reclaim + 2 more: VWAP is the clearest single proof of buyers back. |
| What a bottom call changes | soft block of rings | suspend GIR PE calls ≤ 45 min | suspend; sector suspends leaders; broker / strategist rules | Draft 3 in full (it includes 1 and 2). |
| Strong voice | > 60% may open mirror WATCH | 10 pts over control | PROVEN only | 10 pts over the no-call control at n >= 20: falling shares bounce anyway, so an absolute 60% means little. |
| Live AI GO NOW check | Opus veto on confirmations, max 10 | none for predicted (09:08 code rules); Opus for news only | Opus after the ring, max 8 | Code reject rules from 09:08 gate predicted rings; Opus (cap 8) before news GO NOW and as an after-ring note. Speed and the rubber-stamp finding. |
| Misses | 3%+ | 3%+ | 2%+ | All 2%+ listed for the miss hunt; headline counts 3%+. |
| Side bias flag | ratio outside 0.5-2 | - | > 70% one side vs 40-60% market | 20+ point gap vs the market's own side mix over 5 days. |
| Ring priority / count | under 25 | confirmation A before news | target 10-15 | Target 10-15, ceiling 50 / 6; merged priority list in F2. |
| Shadow before live | 30-day NOT PROVEN label | ring live per side after 20 days at +8 pts | 2 weeks shadow | Shadow first; live per side at +8 pts over baselines after 20 days, or earlier with NOT PROVEN by his choice. |

**Departures from existing specs (need his yes):** B2 confirms PREDICTED shares from 09:17 (E3 says 09:20 for sector CONFIRMED, E8
says 09:30) - the study's timing; G replaces the live Opus check on predicted lines with code reject rules - the review's rubber-stamp
finding and his $3-5 budget; D suspends GIR's own calls after a bottom / top call - not his trading, so R12 holds; F2 adopts his 50 / 6
as the ceiling over IA.md section 7's stricter budget, with IA's quiet target as the goal.
