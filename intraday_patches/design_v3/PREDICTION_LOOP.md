# GIR PREDICTION LOOP - THE ONE SPEC (20 Nov 2026)

Evening prediction -> trading-day confirmation -> live news calls -> analyst BOTTOM / TOP calls -> scoring.
Merged by the desk chair from three desk drafts (the senior F&O dealer, the sector-first options buyer, the market-intelligence /
news desk). The server team builds from this file. Requirements R52-R56 in REQUIREMENTS.md point here.
Revised 20 Nov after the desk review: sounds strictly R10 / E14 (F2), AI cost re-built from NEWS_READING_PLAN's figures (G), news
speed targets = BUILD_PLAN E12.5 (C1), full R14 / E8 card fields and E9 gates (B2-B3), one RVOL (section 0), CE / PE mirrors written
out (D3, D4, D5), the 09:17 departure completed, MS day-type figures marked not comparable (A4). Departures are listed at the end.

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

## 00. THE PRINCIPLE (the trader, 20 Nov - binding)
GIR does NOT copy or chase another system's alerts. The old system is only a yardstick for the after-close score; the new system never
reads the old system's calls and never "reacts fast because the old one reacted". It PREDICTS from real data and knowledge: the
evening prediction (19:45), updated through the night (22:45) and in the morning (07:15) with world cues and overnight news, and above
all from the MORNING TV - CNBC-TV18 live and ET Now pre-market and pre-open (07:00-09:15) - then the 09:08 pre-open. On the trading
day the signal is "I predicted this, and now the sector and price confirm it".

THE GOAL (the trader, 20 Nov 18:00): "Not to catch all the 2% moves - the EDGE: the knowledge, the brain should catch the CORRECT
F&O shares based on news, sectors, external and internal news, company performance, and PREDICT BEFORE." GIR is judged on the
PRECISION and EARLINESS of its reasoned picks, by source - not on how many movers it covers. Fewer, right, early, explained.

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
  held out) and **the volume surge** (RVOL: lift about 1.6 - 1.67 / 1.56 in the verdict table).
- **ONE RVOL in this file (the study's definition, MS line 1347):** RVOL = the share's volume SO FAR TODAY divided by a normal
  day's volume by the same minute (20-day median of cumulative volume to that minute), counted only while price is on its side of
  VWAP (CE above, PE below). "RVOL >= 2" / "volume 2x" anywhere below means exactly this. **RVOL5** is a different signal (MS line
  1401: the last 5 minutes' volume vs normal for that minute, on its side of VWAP; lift 1.38 / 1.30, weaker) and is named RVOL5
  wherever it is used (news price-confirm C5, bottom-rejected D4). No other volume ratio is used for a trigger.
- Waiting for sector CONFIRMED (E3) caught only 19% (CE) and 29% (PE) early, against 46-48% for ORB5. **Sector is a GRADE, not a gate.**
- Market day: NIFTY-up days 51.6 CE vs 25.7 PE moves a day; NIFTY-down days 24.0 CE vs 70.9 PE; mixed (448 of 737 days, 61%)
  30.6 CE vs 31.5 PE. Even on a down day there are about 24 CE moves, so the CE list is never empty by nature.
  **NOT COMPARABLE with A4:** movestudy_report.txt never states its NIFTY up / down / mixed rule, so these day-type counts, the 61%
  and the day-type base rates below are shown as "MS, rule unstated" and are NOT used as A4's base rates or as the bar the market
  call must beat until PS recomputes them on the A4 definition (open -> 15:10, +/-0.5%). Code uses the PS table once it exists;
  before that, the market call's tilt (A2) uses the all-days base rate only.
- **Base rate** (the number every prediction must beat) = the day's same-side 2%+ movers divided by that day's F&O universe,
  computed in code each day. On the study's average: about 20% CE and 22% PE per share-day; about 30% CE on NIFTY-up days and about
  41% PE on NIFTY-down days (the last two: MS day rule unstated - not comparable, see above).
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
| 07:00-09:15 | **MORNING TV - a main input, not a side feed** (the trader, 20 Nov: "In the morning, very important, CNBC TV and ET... they give you the update and pre-open. Yesterday I found out Paytm from there only."): CNBC-TV18 live (pre-market shows, stocks in focus, buzzing stocks, analyst picks, the pre-open segment 09:00-09:15) and ET Now, through F17 speech-to-text, plus ET Prime's morning pieces. Every share or sector named with a view becomes a row: voice, channel, time, words, side, NEW or REPEAT. Rows are added to the candidate table as a TV input with the voice's own hit rate (D5), shown in the 07:15 / 09:08 updates as "ON TV 08:12 (CNBC-TV18, <voice>): PAYTM - <view>", and can ADD a line at 09:08 (marked "ADDED 09:08 - TV") if price and pre-open agree. | F17 + Haiku per chunk, code |
| 09:08 | Pre-open version P09 (A5): includes the morning TV rows and the pre-open TV segment. **THE LIST FREEZES AT 09:08.** | code + one Sonnet call |

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
   yesterday's and the 20-day high / low, RVOL at the close (section 0 definition), NR7 / inside day, EXTENDED (range used > 1.2 ATR), 1- and 5-day RS vs sector,
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
- Default MIXED unless p(up) or p(down) >= 0.5 [S]. The call must beat "always mixed" and shows its record ("market call right 14
  of 22"). How often MIXED happens on THIS definition is not known yet: MS's "mixed 448 of 737 days (61%)" uses an unstated NIFTY
  rule and is NOT comparable; PS question 5 recomputes the day-type frequencies and base rates on the A4 definition, and only those
  feed `base(d | day type)`.
- The call TILTS the base rate (A2) and therefore the list mix. It never zeroes a side.
- 09:08 re-call from the pre-open index; PS measures how much better 09:08 names the day.

### A5. Updates - each writes a NEW row (STANDS / CHANGED / CANCELLED / ADDED); rows are never edited
- **22:45 (code):** cancel facts checked against the US open. Telegram only on CANCELLED or a grade change.
- **07:15 (code re-score, then Opus medium):** each line STANDS / CHANGED (new level or grade) / CANCELLED (reason); up to 2 new
  lines per side, marked "NEW 07:15"; the market-day call re-stated.
- **09:08 (code + one Sonnet call, no Opus - there are 7 minutes):** pre-open IEP gap, imbalance and pre-open volume vs its 20-day
  median, per predicted share (F09):
  - ONE gap table, by the IEP gap g in % measured IN THE PREDICTED DIRECTION (+ = its way, - = against). The % test is the only
    test (ATR is shown beside it, never used to decide); band edges are [S] and re-fitted by preopenstudy. Bands do not overlap:
    | g | state | what it means |
    |---|---|---|
    | g >= +1.0% | GAP TOOK IT | "GAP TOOK x% (about y% of the usual move)". Trigger becomes the opening-range hold (A6); otherwise a pullback to VWAP only. |
    | +0.3% <= g < +1.0% | ARMED (gap agrees) | "watch 09:17", trigger as written. |
    | -0.3% < g < +0.3% | ARMED (flat) | trigger as written. |
    | -1.0% < g <= -0.3% | ARMED - SOFT AGAINST | trigger as written, AND price must first trade back across yesterday's close its way. |
    | g <= -1.0% | AT RISK (gap against) | no entry until it reclaims yesterday's close. Not auto-cancelled; PS measures how often these recover. |
    PE is the exact mirror (its way = down). CANCELLED in every band if a 1-minute close from 09:15 is beyond cancel_px (A6).
  - The Sonnet call writes each line's REJECT RULES as code-checkable conditions (premium cap, spread, IV vs 20-day, distance to the
    nearest wall, break-even move) - used by B instead of a live AI veto (G).
  - One summary at 09:08: "ARMED: 4 UP / 3 DOWN · market MIXED" - on the page and as a Telegram message, **SILENT** (no sound: R10 /
    E14 do not list it). A soft tick here is an option he may switch on (Departures list), default OFF.
- **After 09:08 a prediction never changes side, trigger or cancel for the day.** Only its STATE moves (B). Nothing is added to
  "predicted" during the day; a new idea is a news call (C) or a drill-down mover marked NOT PREDICTED.

### A6. One prediction line (stored and shown)
- **Side** UP = CE / DOWN = PE · **share** · **sector** (whole-sector basis) · **role** LEADER / DEPENDENT / LAGGARD (E4).
- **WHY (+):** at most 3 drivers, each with its counter-driver, proof status (PROVEN Lxx n= / NOT PROVEN) and source ID.
- **AGAINST (-):** the strongest counter-evidence, always written (from the red team).
- **TRIGGER (code):** CE = first 1-minute close above yesterday's high with RVOL >= 2.0 (section 0 definition: day's volume so far
  2x a normal day's by this minute, price above VWAP) [S, MS / PS]. PE = mirror on yesterday's low (price below VWAP). On GAP TOOK
  IT: the high (CE) / low (PE) of the first 3 minutes [S], held, RVOL >= 2.0, with a GAP-HOLD line (CE must not fall back below
  yesterday's high; PE must not climb back above yesterday's low).
- **CANCEL (machine-readable, any one is enough):** a PRICE, cancel_px, made FINAL at P09 (09:08) from the pre-open equilibrium
  price (IEP, which becomes NSE's open): CE cancel_px = the HIGHER (nearer) of yesterday's low and IEP -0.8% [S, PS]; PE cancel_px =
  the LOWER (nearer) of yesterday's high and IEP +0.8%. N19 (19:45) and U07 (07:15) store a PROVISIONAL cancel_px using yesterday's
  close in place of the IEP, marked provisional; B5 FAILED and A5 use only the final P09 value - plus FACTS: an overnight driver reversing past its threshold, a denial or scope change, a contrary broker
  stance change, GIFT against by more than 0.8% for beta > 1 shares [S].
- **EXPECTED MOVE:** the share's own median base -> peak on its past 2%-move days (MS: about 3.3% CE / 3.2% PE across shares);
  fallback 1.0 x ATR14 %. Used for TOO LATE.
- **CONFIDENCE:** a grade STRONG / MEDIUM / WEAK always, with the side's base rate beside it. A probability only when calibrated
  (A2): "41% (base 20%, study n=180) MEDIUM". Never a % from the AI. Before calibration: "MEDIUM (base 20%) - NOT CALIBRATED".
- **STRIKE** per E7 (ATM / 1 ITM, current or next month in the last sessions), "premium at the 19:45 close", premium limit.
- **Chips:** results tomorrow (IV crush), ban, MWPL, AT RISK, GAP TOOK.
- The market-day call and the sector call it belongs to; made_at; version.

### A6b. MOVER lines - when the side is not proven (desk decision 20 Nov, from the C1 test)
The C1 test (16 / 18 / 19 Nov, as-of data) showed the code CAN name tomorrow's movers (held-out lift about 1.4x random) but CANNOT
yet name the side (50.2%, a coin flip), and that a news-thin evening gives an empty list. So:
1. **The list is never empty.** Code ranks movers from data alone (yesterday's range / volume / build-up, ATR compression, distance to
   yesterday's high / low, sector state); news and knowledge only ADD to it or set a side. No news reader = still a list.
2. **A share whose mover score is strong but whose side is unproven becomes a MOVER line with BOTH triggers:** CE above yesterday's
   high (or the opening-range high on a gap) with RVOL >= 2, PE below yesterday's low (or the opening-range low) with RVOL >= 2.
   The first trigger that fires with the sector and NIFTY not against it decides the side; the other trigger is then cancelled.
   Card: "MOVER (side open): X · CE above 1,234 / PE below 1,198 · sector Y · NOT PROVEN". This turns "will move" into a tradable
   early card without guessing the direction.
3. **A side is set before the open only by a driver with its own record:** the market-day call at 09:08 (the 3-year study: NIFTY-up
   days give about 2x more CE moves, NIFTY-down days about 3x more PE moves), a broker / TV / trader read with its hit rate (D5,
   TRADER_CALLS), yesterday's futures build-up when preopenstudy shows it predicts the side. Until a driver is proven, its line
   says "side from <driver> - NOT PROVEN" and B still needs the price to confirm.
4. **The early-card count (E2 pass mark) counts MOVER lines and side lines alike** once their trigger fires before half the move
   is done (B4). Scored per kind: MOVER lines vs side lines vs the old system.
5. Hindsight check stays: a knowledge chain added after a move never scores that move (the 18 Nov -> 19 Nov AC / auto /
   electronics result is not counted).

### A6c. EXTREME overbought / oversold rule (from obscan.py, 3 years, 318 events; the trader's challenge 20 Nov)
After a daily RSI(14) >= 80: 81% corrected within 20 trading days (a 5%+ pullback from a high close, or a close below the 20-day
average); median worst pullback -7.6% (worst cases -20% to -26%); yet 62% were higher at day 20 (median +3%) - the trend often
resumes after a shake-out, and the 19% that ran on (e.g. GLENMARK Jun 2025, +29.9% in 20 days) still corrected later.
So: (1) an EXTREME share never gets a fresh CE GO NOW on a breakout - only a pullback entry (hold at VWAP / the 20-day average
with volume); (2) it may get a PE line, but only on the turn (yesterday's low broken, below VWAP, volume, sector weakening);
(3) the card shows "EXTREME RSI nn - 81% corrected within 20 days (median -7.6%), n=318". The mirror (RSI <= 20) is measured
the same way before it is used for CE bounce lines.

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
1. **SHARE:** the trigger crossed the predicted way (1-minute close), RVOL >= 2.0 (section 0 definition) [S, MS].
2. **SECTOR THE SAME WAY** (R49 whole-sector basket): sector % from the open the same sign and at least 0.3% [S], breadth over all
   listed shares >= 60% the same way [S]. Grade A when the sector is E3 CONFIRMED; grade B when it only agrees (FORMING). Never
   waits for E3. The share moving alone = grade C: a silent card "moving, sector not with it", no ring.
3. **MARKET DAY AGREES:** NIFTY % from the open the same sign, or flat within ±0.2% [S]. 0.2-0.4% against: rings only for a LEADER,
   marked "AGAINST NIFTY". More than 0.4% against: silent card "share + sector agree, NIFTY against".
4. **GATES (all of E7, E8's validators and E9, checked in code; any failure = silent card with the reason in plain words, R12):**
   - not banned; data fresh (R09); the 09:08 reject rules pass; the E7 strike gate passes - or the better strike is named ("spread
     3% - take the 1 ITM / wait for 09:20"). No tradable strike at all = "no tradable strike - X", no ring.
   - **E9 risk rules**, read from his live positions and fills (F10, every 5 s): lock room > 0 and lots from the lock room >= 1;
     not LOCKED (daily loss lock / 2 losses in a row); **at most 3 trades today and 2 open positions**; **never a second position in
     the same sector or on the same driver** (an open PSU-bank CE blocks a second PSU-bank CE; one gold PE max); **cooling-off 15-20
     min after a loss** [S, E9]; **chase zone** - price more than 0.3 ATR past the trigger or premium 8% past the planned entry =
     "WAIT FOR PULLBACK to `<p>`", no ring (the ring may come later on the pullback if still FRESH, B4).
   - R:R after costs >= 1.5 (E8), with stop never more than 30% of premium.
   - **E8's "confidence < 0.6 -> NO_TRADE" validator, mapped to grades:** the AI's own confidence is never used (A6). Before
     calibration: grade WEAK (including a line that dropped to WEAK through STALE, B2 ring window, or a news / broker downgrade) =
     NO_TRADE; MEDIUM and STRONG pass. After calibration (A2): p_cal below the A7 bar (1.6x the side's base rate) = NO_TRADE. An
     absolute 0.6 on a 20% base event would block nearly every line, so this mapping is listed under Departures.

**Earliest ring: the close of the 09:16 bar (09:17:00).** The 09:15 candle includes the pre-open. This departs on purpose, for
PREDICTED shares only, from:
- BUILD_PLAN E3 ("never before 09:20") and E8 ("no orders 09:15-09:20, entry window 09:30");
- GIR_SPEC line 352 ("after an overnight Tier-1 event: no entries 09:15-09:30; trade the mapped sector only if it holds its gap
  after the opening range") - proposed instead: a predicted share on such a day may ring from 09:17 only if its 09:08 state is ARMED
  (not AT RISK, not GAP TOOK IT) and its GAP-HOLD line holds; the sector's gap-hold is checked on the R49 basket, not after the
  opening range;
- GIR_SPEC line 87 ("CE only above VWAP and the opening range 09:15-09:30 / 09:45, PE only below both") - proposed instead: before
  09:30 the card needs only the VWAP side (share AND sector basket) plus yesterday's high / low trigger; from 09:30 the opening-range
  side applies in full as GIR_SPEC writes it.
Why: by 09:38-09:44 the median 2% move is already half done, and on gap days by about 09:21 (MS). E3 stays the definition of sector
CONFIRMED (a grade). Unpredicted ideas keep E8's window and both GIR_SPEC rules. If PS shows 09:17-09:20 option spreads make it
untradable, revert. **Needs his yes. Until he says yes, predicted shares follow the existing windows (no ring before 09:30; after
an overnight Tier-1 event the GIR_SPEC rule as written), and 09:17-09:30 confirmations are shown silently and scored.**

**Ring window:** 09:17-11:00 [S, MS: 87-91% of onsets by 09:45]. Not triggered by 09:45 = STALE (grade drops one step, may still
ring). After 11:00 a trigger cross is a silent "late trigger" row. 14:30 = EXPIRED, manage only (E8).

### B3. The card (once per prediction per day)
Line 1, his words:
"PREDICTED last evening: `<SHARE>` UP · sector `<SECTOR>` up +1.1% (breadth 9/12, FORMING) · NIFTY up +0.4% · trigger `<price>`
crossed 09:17 with volume 2.3x · move left ~70% of usual · FRESH till 09:22"
Line 2 onward - every field R14 / E8 require on a call card, in E8's order (CONFERENCE fix 4):
- verdict GO NOW · CE / PE · share · strike · expiry · premium limit ("Dec `<strike>` CE ≤ ₹x, no chase above ₹y") · spread 0.9%;
- trigger · stop · target on BOTH premium and share price (T1 before the wall; Kite backstop SL-L trigger and limit);
- **THE VOTE** (R14 / E8): "4 of 5 agree · sector ✓ (grade B) · news ✓ · money ✓ (futures LB) · chain L05 ✓ · brain ? · against:
  `<red-team point>`" - voters are the A2 evidence sources that voted on this line plus the live sector and money (futures) reads,
  each weighted by its E4 shrunk hit rate (a voter with no edge counts zero), "?" for a voter that did not vote, a vote against
  always shown; the red team is the auditor - it checks and does not vote (E8);
- gate chips (spread, depth, IV / 20d, MWPL, lock room, data age);
- MUST HOLD above VWAP `<p>` with the sector above its VWAP · TOO LATE after `<p>` · FAILS below `<cancel>`;
- hold until (time stop 45-60 min without +0.5R; hard exit 15:10) and "don't exit before the stop or the target unless GIR says
  EXIT";
- **lots from the lock room** ("lock room ₹1,980 vs max loss ₹X -> n lots"; 0 = BLOCKED, no ring) · max loss in ₹ · R:R after costs
  (charges + slippage);
- why (one line, from the stored prediction row) and what makes it wrong (cancel price and facts) · signal age · source (prediction
  version N19 / U07 / P09);
- **that setup's record** from E4: "PREDICTED + CONFIRMED, CE, grade B: 9 of 21 right-tradable · base 20% · NOT PROVEN" (n and
  NOT PROVEN always shown);
- AI line (G), filled in about 20 s after the ring, never delaying it.
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
the prediction picking better than the base rate. Hence the NOT PROVEN label in E7.

---

## C. LIVE NEWS CALLS ("this is news, this can go up")

### C1. Pipeline (reuse, not new) - 09:00-15:10
NEWS_TO_SECTOR_ENGINE A1-A12 and NEWS_READING_PLAN tiers: CATCH with first-seen time -> FAST PATH (< 2 s: phrase triggers and the
evening's scenario trees) -> Haiku frame (1-2 s) -> entity linker -> exposure matrix / link book, both sides, netted (code) -> Sonnet
for weight 4-5 and every negation / denial, with the blind second direction check (E12.4) -> EVENT_MEMORY match NEW / REPEAT /
NEW-FACT / DENIAL / OFFICIAL plus past reactions (within 10 s; 30 s for TV).

**Speed targets, first source -> card on the page (BUILD_PLAN E12.5 adopted as written; EVENT_MEMORY and the replay tests agree):**
| Source class | First source -> card | Story match (EVENT_MEMORY) | Why this is reachable |
|---|---|---|---|
| Exchange filings (F15) | **< 15 s** | 10 s | polled every 3-5 s; filing carries the symbol; fast path < 1 s; Haiku 1-2 s; Sonnet second opinion 2-5 s (NRP F) |
| Basket shock, price first (F27) | **10 s** after the 3rd share crosses | - | code only |
| Wires / class A flashes (F16) | **30 s** | 10 s | sitemaps every 15-20 s |
| X / TV text (F17 speech-to-text, F19) | **15-30 s from the spoken words** | 30 s | transcript chunks + phrase filter + Haiku; the Sonnet check runs AFTER the card is up and only changes its label |
| Regulator sites (F20) | **60-120 s** | 10 s after catch | polled every 1-2 min (RSS 60 s) - the polling sets the floor |
- TV pass marks: a BOTTOM / TOP card within **30 s** of the words (R55, replay test 5); a TV BROKER CALL card within 30 s as the
  target and **60 s as the fail line** (BROKER_CALLS replay 19 Nov 12:44). The stricter 30 s is the build target for both.
- The card can appear before the second opinion finishes; it shows "CHECKING" and cannot become a GO NOW until the check agrees
  (C3). The GO NOW itself also waits for the C5 price confirm (up to 10 min); latency is scored to the CARD, the GO NOW delay is
  scored separately.
- Every call logs the waterfall (first source -> caught -> read -> card -> Telegram) per class, in the 15:45 audit (E12.5 / E15).
  A class whose p95 misses its target two days running is a P2 health item.

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
`<C>` (`<sector>`) · story back: 3rd time, past median +1.8% (n=5, NOT PROVEN) · GO NOW only if `<A>` > `<price>` with RVOL5 3x
within 10 min · cancel if: denial / scope narrower"
- Labels always shown: NEW / REPEAT / DENIAL / OFFICIAL; VERIFIED (class A, or two independent sources) / UNVERIFIED - TV ONLY /
  SOURCES SAY; the source and seconds since the first source.
- Touches a PREDICTED share: merged into that card, not a second card. "NEWS AGREES with my 19:45 prediction" (grade up, no extra
  ring if already rung) or "NEWS AGAINST my prediction: X - in doubt; cancel if Y" (silent on a share he does not hold - the
  prediction's state changes on the page and in Telegram; if he HOLDS that side it is an exit-family warning, "PROTECT / BOOK HALF",
  under E10 / E14).
- **Sound, strictly by R10 / E14 and E12:** a news call is a GET READY until the C5 price confirm makes it a GO NOW. It sounds the
  soft tick ONCE only when it is a GET READY on a sector / basket call (E12.1 basket shock with the cause found, or E12.2 watched
  words on a mapped body naming a sector / basket) - "GET READY on a sector call" is the only GET READY R10 lets ring. A news GET
  READY on a single share is a silent card. A confirmed news GO NOW sounds the bright chime once. Nothing else in C sounds.

### C5. Price confirm before any GO NOW [S, EM / LS]
Within 10 minutes of first sight, the named share must:
- move its way by at least 0.3 x ATR14 (about 0.5% on a typical F&O share) from the first-seen price, with **RVOL5 >= 3** (MS line
  1401: last 5 minutes' volume 3x normal for this minute, on its side of VWAP). RVOL5, not RVOL, because a mid-day news burst does
  not lift the whole day's cumulative ratio for many minutes; RVOL5's lift (1.38 / 1.30 on all shares) is measured on breakouts,
  not on news, so the level is [S, EM / LS];
- be on the right side of VWAP;
- with its whole-sector basket not against and NIFTY not against by more than 0.3%.
Then:
- UNVERIFIED: also needs a second independent source or the official document (E12.2). TV-only is never GO NOW.
- Moves 0.5% the other way within 5 minutes: "MARKET DISAGREES - no trade", closed.
- A move of more than 1 ATR (or 1.5%) in the 15 minutes BEFORE first sight: "already moved before the news - priced / leaked",
  one grade down, LATE rules apply.
- Text says up but price, breadth and IV say down in the first 3-5 minutes: no trade ("sell the news").
- No confirmation in 10 minutes: the call expires silently and is scored as a NEWS call, not a trade.
- A confirmed news GO NOW passes every B2.4 gate (E7 strike gate, E8 validators, E9 trade / position / sector / cooling-off / chase
  rules, lock room) and the live Opus check (G) before it rings. When the G ladder has switched the Opus check off, it rings on the
  code gates plus the C3 Haiku + Sonnet agreement, and the card says "AI check off - budget". The card carries the full B3 field
  list (THE VOTE, the setup's record - here the news event type's record - and lots from the lock room).
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
book half"), on the phone too. It is a warning; GIR never exits for him. It rings AS a BOOK HALF exit alert under E14 exactly: two
low notes, repeated every 60 s until A + Enter, never muted while the position is open - no new sound, no changed repeat rule.
Follow-up E10: PROTECT (stop to cost) / BOOK HALF; EXIT the rest if the test CONFIRMS the bottom. Why: these are his own exits,
which R10 / E14 already let ring; missing a bounce on an open PE
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
**Mirror, same thresholds:** a DOWNGRADE after a rally makes a CE prediction on that share drop one grade, or CANCELLED on a stance
change by a house with hit rate >= 55% at n >= 8 [S, EM]. Card: "downgrade - gap-down may bounce; no CE until the first 30 min
decide".

**(d) Strategist sector view:** a warning line only; lowers that side's evening grade by one step for 1 day. No suspension.

**(e) It NEVER creates a CE by itself** (nor a PE from a top call). A counter-side idea exists only after D4 CONFIRMED, as a GET READY,
and only for a voice or kind that is PROVEN (D5). No flip-flopping.

### D4. The price test (code, every minute, up to 45 minutes after the call; TOP is the mirror: LOWER HIGH, VWAP LOSS, LONG UNWINDING (OI down while price falls off the high; nearby CE OI unwinding), BREADTH TURNING down, CE premium falling with ATM IV flat; TOP REJECTED = a 5-minute close 0.3% above the call-time high with RVOL5 >= 1.5 while above VWAP)
1. HIGHER LOW: no new low for 15 minutes and a 5-minute swing low above the call-time low.
2. VWAP RECLAIM: a 5-minute close above VWAP (if VWAP is more than 2 ATR away, the last 15-minute swing high instead).
3. SHORT COVERING: futures OI down at least 1% over all months while price rises off the low; nearby PE OI unwinding.
4. BREADTH TURNING: the sector's members above their 15-minute low go from under 30% to over 60%, or the basket is 0.5% off its low.
5. PE PREMIUM falling while ATM IV is flat (sellers leaving, not IV crush); NIFTY not making a new low.

Verdicts (one silent line each; a ring only if he holds the side at risk):
- **BOTTOM CONFIRMED** = VWAP reclaim + at least 2 more. Suspension stays for the day.
- **BOTTOM REJECTED** = a 5-minute close 0.3% (or 0.3 ATR) below the call-time low with RVOL5 >= 1.5 [S, EM] while below VWAP. "BOTTOM CALL
  REJECTED by price - PE ideas back on." Suspension lifts.
- Neither in 45 minutes: "CALL EXPIRED - NOT PROVEN". Suspension lifts; the warning stays on the card.

### D5. The house's own hit rate (EVENT_MEMORY TV CALLS / broker threads)
- Each call stored as an EPISODE: kind (live / note / strategist) x BOTTOM / TOP x voice / house x side.
- BOTTOM HELD = no new low beyond the call low by 0.3% AND +1% (or +0.5 ATR) from the call price within 60 min.
- TOP HELD (mirror) = no new high beyond the call high by 0.3% AND -1% (or -0.5 ATR) from the call price within 60 min.
- Both also scored at 15:10, day 2 and day 5; NOT HELD is everything else.
- Measured AGAINST A CONTROL: falls of the same size, same kind of day, no call, from the same minute store. Falling shares bounce
  often anyway; the voice must beat that.
- The price test's own verdict is scored too (is the test or the voice better?).
- Sample rules (EVENT_MEMORY D): n < 3 = "new voice, no record"; 3-7 = counts only, capped MEDIUM; 8-19 = hit rate; 20+ in both halves
  = STRONG.
- After n >= 20 [S]: a voice at or below the control drops to INFO ONLY (told, no suspension). A voice 10+ points above the control
  may also open a counter-side GET READY ("CE on the bounce, half size") - only after BOTTOM CONFIRMED, never a GO NOW on its own.

**Dependency:** TV voices need speech-to-text (Deepgram, about $5-7 a trading day, outside the AI budget; see Departures item 9).
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
- "NEWS CALLS 5: right at 30 min 3/5 · first source -> card p95: filings 11 s (target 15) · wires 26 s (30) · TV 24 s (30) · junk 0"
- "BOTTOM / TOP 2: PAYTM bottom HELD (PE protected) · METALS bottom REJECTED · PE blocked 1 (would have lost -0.9%)"
- "MISSED 3%+ movers 9 (CE 5 / PE 4), biggest `<SHARE>` -4.1% (not predicted, `<story>`) · RINGS 12 (peak 4 in 15 min) · AI $4.20 (ladder: none)"
- "20-day: predictions 34% right vs 20% base, 22% yesterday's movers · AI vs code rank +4 pts (n=180) · NOT PROVEN until day 20"

### E7. Live from day 1, labelled until proven (the trader's order, 20 Nov: "Monday we use the full system")
From Mon 23 Nov the confirmation signals, news calls, bottom / top calls and the 19:45 / 07:15 / 09:08 / FAILED / scorecard
messages are LIVE: on the page, on Telegram and with the R10 / E14 sounds. This supersedes BUILD_PLAN 0.1's /preview shadow mode
("nothing rings until he writes 'switch on'"): his order is the switch-on. Every ring carries "NOT PROVEN (day n of 20)" for its side
until that side's prediction hit rate is at least 8 points above baselines (a) and (d) over 20 trading days; then the label becomes
"PROVEN CE / PE". If a side falls below baseline over any rolling 20 days, its label goes back to NOT PROVEN and the desk tells him.
The old system runs silent beside it for comparison, with the fallback switch (MONDAY_READY J7).

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

**What may sound at all - R10 / E14 exactly, no additions:** GO NOW (bright chime, once), GET READY on a sector call (soft tick,
once), his own exits STOP / BOOK HALF / EXIT / 15:10 (two low notes, repeated every 60 s until A + Enter, never muted while a
position is open). In this loop that means:
- **Exit family (never counted, never dropped, E14 repeat rule unchanged):** his own exits; a BOTTOM / TOP call on a held position
  (it rings as BOOK HALF / PROTECT, D3a); FAILED on a held position (E10); NEWS AGAINST a prediction on a side he holds.
- **GO NOW (bright chime):** PREDICTED + CONFIRMED (B2, grade A / B, MEDIUM+); a price-confirmed news GO NOW (C5); other engine GO
  NOWs (E8).
- **GET READY on a sector call (soft tick):** a news call on a sector / basket (E12.1 cause found, E12.2 mapped body); rotation GET
  READY (E11).
- **Silent (page row + Telegram where F1 says so):** the 09:08 ARMED summary; news calls on a single share before the price confirm;
  NEWS AGAINST a prediction he does not hold; a BOTTOM / TOP call that only suspends a live predicted call (the suspended card shows
  "BOTTOM CALL - WAIT FOR THE TEST"); unpredicted movers, NEAR, LATE, FAILED (not held), REPEAT news, TV-only items, strategist views.
  Three of these may get the soft tick ONLY if he says yes (Departures list); default OFF.

**Counting and the live slot rule (a ring cannot be taken back, so it is decided at request time from scores fixed BEFORE the
open - never by order of arrival):**
- Counted rings = every GO NOW and GET READY sound. Exit-family sounds are never counted. The silent 09:08 summary is not a ring and
  does not count; if he switches its optional tick on, it counts as a tier-C ring in every rolling window containing 09:08.
- Every requested ring gets a TIER from values already stored at 09:08 (P09) or fixed by the item's class:
  - **Tier A:** a confirmation whose line is in the P09 top 3 by stored code score (both sides ranked together); a VERIFIED impact-5
    news GO NOW.
  - **Tier B:** any other scored-list confirmation (grade A / B, MEDIUM+); an impact-4 news GO NOW on a predicted or held share.
  - **Tier C:** GET READY ticks on a sector call; other engine GO NOWs.
- With n = counted rings in the trailing 15 minutes (rolling): tier C rings only if n <= 3; tier B only if n <= 4; tier A if n <= 5.
  So the 6th slot of any 15 minutes is always kept for tier A, and two slots are always kept from tier C for GO NOWs. A request
  that fails the test becomes a silent card "held back (ring limit)" and is scored (E1).
- **09:17-09:30:** only confirmations whose lines are in the P09 top 5 by stored score are eligible to ring at all (the list is
  fixed at 09:08, so it is known before the first trigger); the others light up in the lane. With the slot rule this caps the
  opening at 6 rings, including any optional 09:08 tick.
- Day ceiling: after 40 counted rings only tier A rings; at 50 nothing counted rings.

Expected per day [S, LS]: confirmations 3-8 · news GO NOW 0-4 · sector GET READY 0-3 · other engine GO NOWs under a cap of 10 · his
exits (incl. bottom / top protect) as they happen. Typical counted total under 20.

Conflict to settle with him: IA.md section 7 (at most 6 audible P2 a session, 1 per 10 min) is stricter than his 50 / 6. This spec
takes his 50 / 6 as the ceiling and IA's quiet target as the goal; the scorecard reports actual rings either way.

### F3. How each looks (one line each; green = CE / up, red = PE / down, amber = action, grey = info / failed / not predicted)
- Prediction: "▲ CE · `<SHARE>` · `<SECTOR>` LEADER · > `<yday high>` vol 2x · cancel < `<p>` · MEDIUM (base 20%) · why `<driver>` (+, PROVEN L05 n=34) · against `<counter>` · market MIXED 40/35/25"
- 09:08: "ARMED 4 UP / 3 DOWN · `<A>` gap +0.6% agrees · `<B>` GAP TOOK 3.1%: pullback only · market MIXED"
- Confirmation: "✓ PREDICTED last evening · `<SHARE>` UP · `<SECTOR>` +1.1% (9/12) · NIFTY +0.4% · `<trigger>` crossed 09:17 vol 2.3x · left ~70% · too late > `<p>` · fail < `<p>`"
- Too late: "◐ TOO LATE · `<SHARE>` +1.9% of ~3.4% done · pullback only: VWAP `<p>`"
- Failed: "✗ PREDICTION FAILED · `<SHARE>` predicted UP, now -1.3% < cancel `<p>` · I was wrong · no CE today"
- Not predicted: "• NOT PREDICTED · `<SHARE>` -2.4% · `<SECTOR>` -1.2% · `<story>` · LATE · drill-down ›"
- News: "NEWS 11:42 · `<source>` 38 s · NEW · VERIFIED → UP `<A>`, `<B>` (`<sector>`) · DOWN `<C>` · GO NOW only if `<A>` > `<p>` RVOL5 3x in 10 min · cancel: denial"
- Bottom: "BOTTOM CALL · `<voice>`, `<channel>` 11:05, TV ONLY · `<SHARE>` ~`<p>` after -7% · STOP: no new PE · your PE: protect `<p>` / book half · test VWAP `<p>` · voice 6/11 (NOT PROVEN)"
- Top: "TOP CALL · `<voice>` · `<SHARE>` ~`<p>` after +6% · STOP: no new CE · your CE: protect / book · test: lower high + VWAP loss"
- Scorecard: "UP 6: 3 right · DOWN 5: 3 right · beat the day CE +11 / PE +6 · rings 12 · missed 9 · AI $4.20"

---

## G. AI COST (prices cached 3 Nov 2026: Haiku 5.5 $0.10 / $0.50, Sonnet 5.5 $2 / $10, Opus 5.5 $4 / $20 per M tokens; cache reads Sonnet $0.10, Opus $0.20; Batch -50%)

CODE does: candidates, scores, triggers, 22:45 and 09:08 checks, the confirmation watcher, price tests, rings, scoring. **No AI on the
critical path of a ring.** News reading is costed from NEWS_READING_PLAN (NRP) section E's own per-call figures, not re-estimated.

| Job | Model | Calls a day | $ a day (approx.) |
|---|---|---|---|
| 19:45 brain (~70-80K in: frozen knowledge prefix + candidate packet; ~10-15K out with thinking; effort high set explicitly) | Opus 5.5 | 1 (+1 retry) | 0.55-0.70 |
| 19:45 red team (~30K in, ~4K out) | Sonnet 5.5 | 1 | 0.10 |
| 22:45 cancel check | code (Sonnet sentence only on a change) | 0-1 | 0.02 |
| 07:15 update (~40-50K in, ~8K out, effort medium; 11 h after 19:45, so no shared cache) | Opus 5.5 | 1 | 0.35 |
| 09:08 reject rules + one sentence | Sonnet 5.5, effort low | 1 | 0.05 |
| *Prediction runs subtotal (reserved $1.25, below)* | | | *1.07-1.22* |
| News tier 1: every item once after code grouping, effort low (NRP: ~2,500-2,700 x $0.0003) | Haiku 5.5 | ~2,500-2,700 | 0.75-0.81 |
| News tier 1b: deep reads of weight-3 items and full F&O articles, effort medium (NRP: ~300 x $0.002) | Haiku 5.5 | ~300 | 0.60 |
| News tier 2 (NRP: ~70 calls incl. the blind second opinion = $1.3, ~$0.019 a call). Of these, **PROTECTED** (~25-35 calls, ~$0.50-0.65): the blind second opinion on weight 4-5, every negation / denial item, every Haiku refusal. **DISCRETIONARY** (~35-45 calls, ~$0.65-0.85): policy / sector chains, mixed results, TV management tone, 3+ F&O names. Bottom / top verification (stance, level, kind) is a tier-2 read inside these 70 - no separate line | Sonnet 5.5 | ~70 | 1.30 |
| Live GO NOW check: before a news GO NOW rings; after a confirmation ring as the "AI: agrees / WAIT - reason" line (tier A first, F2). Gets premium, IV, spread, OI at the strike, days to expiry, explicit reject rules (review fix 5); 1-hour cache; ~$0.05 a call | Opus 5.5, effort medium, **cap 4** | 0-4 | 0-0.20 |
| Batch (NRP: nightly knowledge rebuild, ET Prime long reads, end-of-day tagging audit) plus scorecard sentences and nightly labels (story novelty, TV-voice tagging) | Sonnet / Haiku via Batch | ~200 | 0.30 |
| Confirmations, LATE / FAILED, price tests, scoring | code | 0 | 0 |
| **Normal trading day** | | | **about $4.0-4.4** (headroom $0.6-1.0) |
| First 2 weeks (tuning): + NRP's Sonnet re-read of a random 10% of Haiku items (~$0.3); NRP warns $5-6 a day until grouping and filters are tuned | | | **$4.3-4.7 planned; $5-6 possible -> the ladder trims** |

**Hard cap $5.00 per budget day** (16:00 to 15:59 next day, so the 19:45 and 07:15 runs count against the day they serve), checked in
code BEFORE each call (estimate x price vs per-call / hour / day counters, then the true cost from each reply's token counts, NRP C)
plus the provider-side limit.

**Reserves.** $1.25 is held for the 19:45 + 07:15 + 09:08 runs; no news spend between 16:00 and 19:45 can touch it. The evening brain
never drops - it is the edge. A floor of $0.40 is held for the PROTECTED Sonnet set and Haiku: discretionary spend stops at $4.60.

**Ladder (replaces the earlier $3.50 / $4.50 rungs, which a normal NRP-costed day would have tripped):**
- **$4.25** -> Opus live checks stop for the day (cards say "AI check off - budget"; code reject rules and the C3 Haiku + Sonnet
  agreement still gate); tier 1b deep reads only for F&O filings and items naming a held or predicted share (others stay on Haiku
  low); in the first 2 weeks the re-read sample drops from 10% to 5%.
- **$4.60** -> DISCRETIONARY Sonnet reads go to Haiku medium (NRP's own $9-rung rule, moved here); the PROTECTED set continues.
- **$5.00** -> code + Haiku low only; one message to him. A protected item arriving after this gets no second opinion and is treated
  under NRP F / E12.4's safe form: "NOT CHECKED - budget", no wake, never a GO NOW; it rings only if it touches a held position
  (exit family, D3a / F2).

**Priority of NRP's "never skipped" second opinion (NRP D):** it keeps priority over every other in-session spend. The earlier
40-call cap on it is WITHDRAWN; it has no count cap below NRP's 200 calls a day (kept only as the runaway guard); neither the $4.25
nor the $4.60 rung touches it; only the $5.00 hard stop ends it, and then the safe form above applies (no second opinion = no call).

**Heavy news day (Budget, war, results peak; NRP: 8,000 items + 1,000 deep, Sonnet 200, uncapped $25-40).** Under $5: prediction runs
$1.1-1.2 (spent before the session) + Haiku low on every item (never skipped) ~$2.4 + deep reads after $4.25 only for F&O filings /
held / predicted shares ~$0.3-0.4 + PROTECTED Sonnet ~$0.6-1.0 (~30-50 calls) = about $4.6-5.0; discretionary Sonnet and the Opus
checks are cut early in the day. Late protected items may hit the hard stop and run UNCHECKED (no GO NOW). Raising the cap for a
named heavy day is his decision (Departures).

**NRP rules this spec overrides (stated so nobody builds both):**
1. NRP E's news ladder ($6 / $9 / $12 / $20) and the E13 $20 whole-system frame -> superseded by the $4.25 / $4.60 / $5.00 ladder.
2. NRP A tier 3 "GO NOW check 1 per stock / 5 min, max 25 a day" and NRP E's "~5 GO NOW" -> cap 4, off at $4.25.
3. NRP's "$3-5 a day for news reading" target -> news reading gets about $2.7 (Haiku $1.4 + Sonnet $1.3) inside the whole-system $5.
4. NRP E's heavy-day "$12-13 capped" -> $5 capped with the cuts above.
5. NRP A's Sonnet "cap 200 calls / day" -> kept as the runaway guard only; dollars do the budgeting.
6. NRP E's Opus "2 notes + ~5 GO NOW = $1.4" -> re-costed from token sizes: notes $0.90-1.05 + checks up to $0.20.
**Kept unchanged:** every NRP D NEVER SKIPPED rule (until the $5.00 stop, then the safe form), NRP E's weekend ($0.6-1) and NSE-holiday
($1.5-2, 19:45 note only if the next day trades) costs, the first-2-weeks re-read, loop guards, caching and Batch rules (NRP C).

- Month: ~21 trading days x ~$4.2 + ~9 weekend days x $0.8 + 1-2 holidays + weekly audit (~$4) = **about $100-110 for Claude**
  (NRP's $120-135 carried a ~$20 heavy-day reserve; here heavy days are capped at $5).
- Caching: frozen prefix (schema, F&O universe, aliases, exposure map, link book, chain table) before the breakpoint; live data last;
  no timestamps or unsorted JSON before it. Target 70-80% cache reads on live calls.
- The old E13 $20 cap and the 18 Nov $27 overspend are superseded by his $3-5.
- The v2 GO NOW check took 77-89% of the cost and approved 57 of 57 cards. Here it is capped at 4, off the critical path for
  predicted lines (code reject rules from 09:08 decide), and must show REJECT / WAIT on known bad cards in the replay before it ships.
- **Not AI money, each needs his yes:** TV speech-to-text (Deepgram, about $5-7 a trading day; cheaper: CNBC-TV18 all day + ET Now only
  09:00-10:30 and 14:30-15:30, about $2 less). D and TV news calls depend on it. The paid news archive for back-testing C.

---

## WHAT preopenstudy.py MUST ANSWER BEFORE ANYTHING RINGS LIVE
1. The lift of a 19:45 code list over the base rate, per side and per kind of reason (chain, sector follow-through, share state,
   story, broker), on held-out months.
2. Whether 07:15 and 09:08 improve it, and how much the pre-open gap alone explains.
3. Whether PDH + RVOL (section 0 definition) has higher lift on PREDICTED shares than on all shares; this sets the trigger, RVOL
   level and cancel level.
4. How often a predicted move is taken by the gap vs left for open -> 15:10.
5. Day-type frequencies and base rates on the A4 tradable-leg definition (replacing MS's NIFTY-day figures, whose rule is unstated),
   and how often the 19:45 / 09:08 market-day call is right.
6. The confirmation window, the too-late fraction and the move left after a confirmation, CE and PE separately; whether 09:17-09:20
   option spreads are tradable.

## BUILD ORDER AND TESTS
1. The prediction tables and the scorer (E) first. Without them nothing can be judged.
2. The code candidate table, back-tested on the 3-year store against the base rate and baselines (no AI).
3. The AI layer, tested only on days after July 2026 and live, against the code ranking.
4. Before Monday: replays of 16, 18, 20 Nov, an October up day and 27 Oct (SERVER_ORDER_MONDAY E1); after Monday a 20-30 day replay with frozen as-of knowledge runs in the background; live from Monday with the NOT PROVEN label (E7).
5. Replay checks, all scored from data, never from a hand list: 18 Nov (down day) and 19 Nov (up day) - both CE and PE lists present,
   confirmations within 5 min of the trigger, 50 rings or fewer a day and 6 or fewer in 15 min; 20 Nov (US fall night); 19 Nov PAYTM
   TV call - BOTTOM card within 30 s of the words, PE suspended, test run; 18 Nov KAYNES - no fresh PE ring after a 9% fall without
   the test; 19 Nov 12:44 Goldman - broker call card within 30 s of the words (60 s = fail, BROKER_CALLS), UNVERIFIED, no GO NOW
   before price confirms; KEI / TITAN junk - no ring; every replayed news card within its C1 class target (filings < 15 s, wires
   30 s, TV 15-30 s, basket shock 10 s, regulator 60-120 s); the ring log shows only R10 / E14 sounds, exit-family alerts repeating
   until acknowledged, and no rolling 15 minutes with more than 6 counted rings; the AI cost log for the replayed days fits the G
   ladder (no rung tripped on a normal day).
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
| Live AI GO NOW check | Opus veto on confirmations, max 10 | none for predicted (09:08 code rules); Opus for news only | Opus after the ring, max 8 | Code reject rules from 09:08 gate predicted rings; Opus (cap 4, off at the $4.25 rung) before news GO NOW and as an after-ring note. Speed, the rubber-stamp finding, and the NRP-costed budget (G). |
| Misses | 3%+ | 3%+ | 2%+ | All 2%+ listed for the miss hunt; headline counts 3%+. |
| Side bias flag | ratio outside 0.5-2 | - | > 70% one side vs 40-60% market | 20+ point gap vs the market's own side mix over 5 days. |
| Ring priority / count | under 25 | confirmation A before news | target 10-15 | Target 10-15, ceiling 50 / 6; only R10 / E14 sounds; tiered live slot rule from P09 scores in F2. |
| Shadow before live | 30-day NOT PROVEN label | ring live per side after 20 days at +8 pts | 2 weeks shadow | Shadow first; live per side at +8 pts over baselines after 20 days, or earlier with NOT PROVEN by his choice. |

**Departures from existing specs - DECIDED 20 Nov by the desk under his order ("Monday the full system; don't make me repeat").**
He can change any of these at any time; until he does, they stand as written here.
1. **09:17 earliest confirmation for PREDICTED shares (B2): YES.** Overrides BUILD_PLAN E3 (E3 stays the grade definition), E8's
   09:30 entry window and GIR_SPEC line 87 (before 09:30 only the VWAP side is required). Why: the study (half the median move done by
   09:38-09:44, 09:21 on gap days). EXCEPTION kept: on a day after an overnight Tier-1 event GIR_SPEC line 352 holds (no entries
   09:15-09:30). From 09:17 to 09:30 only the 09:08 top 5 may ring (F2).
2. **E8's "confidence < 0.6 -> NO_TRADE" mapped to grades (B2.4): YES.** WEAK = NO_TRADE before calibration; after calibration
   p_cal below 1.6x the side's base rate.
3. **Code reject rules on predicted lines; the Opus 5.5 GO NOW check on non-predicted and news GO NOWs, capped at 4 a day: YES.**
   (SERVER_ORDER B6 "GO NOW on Opus 5.5 that can say no" applies to exactly those.) Why: the 57-of-57 rubber stamp and the $3-5 budget.
4. **G's $5 hard cap and ladder: YES.** It supersedes every "$20" in BUILD_PLAN (0.2, E13, 3.0 P&L strip meter, 3.10, the Sun 22 Nov
   step) and NRP's $6 / $9 / $12 / $20 ladder - the server builds ONE cap. A $6 cap for the first 10 trading days is allowed while the
   news filters are tuned.
5. **D suspends GIR's own new calls on the threatened side after a bottom / top call: YES** (his trading is never blocked; R12 holds).
6. **F2: his 50 / 6 is the ceiling: YES**, IA.md section 7's quiet target stays the goal.
7. **Extra soft ticks: OFF** (a: 09:08 ARMED summary, b: NEWS AGAINST on a share he does not hold, c: bottom / top suspending a live
   predicted call). He can switch any of them on in Settings.
8. **Index options:** the A4 market-day call also produces one NIFTY and one BANKNIFTY line (UP = CE / DOWN = PE) with the same
   trigger (yesterday's high / low with breadth on its side), cancel, B-style confirmation and E scoring; Monday suggests the NEXT
   weekly (1 Dec), the expiring contract shown as information.
9. **Paid TV speech-to-text (Deepgram):** use it if it is among the subscriptions he has already given; otherwise TV stays on the
   existing tvwatch and the Sunday status names it once as the only open paid item.
**Not departures (now aligned):** news speed targets are BUILD_PLAN E12.5 as written (C1); the confirmation and news cards carry
every R14 / E8 field and the E9 rules (B3, B2.4, C5); one RVOL definition from the study (section 0).
