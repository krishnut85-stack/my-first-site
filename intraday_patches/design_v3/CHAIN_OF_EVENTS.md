# CHAIN OF EVENTS - the engine that tells the trader THE EVENING BEFORE (binding spec, 19 Nov 2026)

The trader, 19 Nov: "Yesterday metals were down, today Maruti was up. It is a chain of events. A senior trader would have told me
yesterday: because of this, tomorrow MARUTI and HERO can go up. Don't tell me it cannot be found." This file is binding for the
engine (it adds step **E2b** to BUILD_PLAN section 2) and for the tests (it adds to section 4). Merged from three expert answers
(senior trader, research analyst, quant).

**What GIR promises:** every evening it names, for tomorrow, which sectors and F&O shares a driver move should lift (CE) or sink
(PE), how strong the case is, the trigger, the strike and what cancels it. It then confirms or cancels at 22:45, 07:15, 09:08 and
09:20. It is a graded call with a measured record, not a guarantee. A move GIR explains only afterwards is a MISS.

**Facts checked (be honest about them):** no news report of 18-19 Nov 2026 could be opened from this session (Indian news sites
blocked, search index stops around 5 Nov). The trader's figures are taken as given. The closest earlier case, **Thu 5 Nov 2026**
(NIFTY AUTO about +3 to +4%, ASHOKLEY about +9 to +10%, MARUTI about +4.7%), was reported as driven by **Brent falling about 9%**
the day before, plus October sales, not metals. So on 18 Nov GIR must check crude, the rupee and auto positioning as well as
metals. Metals alone rarely give MARUTI +6%; two or three chains pointing the same way do.

## A. THE 18 -> 19 NOV CASE

**The chain.**
1. Driver (18 Nov): copper, aluminium and steel down all day; NIFTY METAL and cables (POLYCAB, KEI) down with fresh SHORT build-up
   (price down, OI up) = money leaving metals, not one tick.
2. Channel = COST. Raw material is about 70-75% of an automaker's sales; steel, aluminium, copper and rubber about 15-25% of sales
   (trucks highest). A sustained 5% fall in that basket is roughly +80 to +150 bp of margin on an EBITDA margin of 11-13%, i.e.
   +7 to +12% EBITDA, reaching results 1-2 quarters later. The market prices it the NEXT MORNING. (Ranges differ between the three
   experts; the knowledge base replaces them with each company's annual-report numbers.)
3. Who moves most: **ASHOKLEY** (a truck is the most steel per rupee of price, thin margins, highest beta, diesel/freight link to
   crude) -> leader. **MARUTI** (heaviest weight in NIFTY AUTO, no JLR / EV / tractor dilution; funds buying "the auto trade" hit it
   first; a +6% day in a low-beta heavyweight = fresh buyers PLUS short covering). Two-wheelers **HEROMOTOCO, TVSMOTOR, EICHERMOT,
   BAJAJ-AUTO** (steel and aluminium castings) next. **M&M** diluted by tractors and other businesses. Ancillaries: MOTHERSON
   (copper harnesses = cost; it belongs on the CE side, not in the metals PE list as test 4.1 has it - fix 4.1).
4. Other helpers GIR must check, each adding to the grade: crude down; rupee steady; autos short-heavy or oversold after 5 Nov;
   rotation out of metals (NIFTY METAL / NIFTY AUTO ratio); sales talk (VAHAN mid-month, wedding season, Nov sales on 1 Dec);
   GIFT / FII mood; any own news on MARUTI (if none: rotation + short covering).

**Expiry:** 19 Nov is 3 sessions before the November monthly expiry (Mon 23 Nov - 24 Nov is an NSE holiday; the contract master decides), so rule E7 (last 5-7 sessions) picks the **DECEMBER**
series; the November strike is shown beside it, never picked. Strikes are filled from the chain (F26) - never typed by hand.

**The notifications GIR must send (wording binding; <> = filled from data):**
- **18 Nov 19:45 - TOMORROW'S OPTION WATCH** - "CE AUTOS, grade MEDIUM. Why: copper <x>%, aluminium <x>%, steel <x>% (vs <named
  reference>, as of <time>); NIFTY METAL <x>% with short build-up in <n> names = lower input cost for automakers. CE watch:
  ASHOKLEY (leader - steel-heavy, high beta), MARUTI (index heavyweight), TVSMOTOR, HEROMOTOCO; laggards M&M, EICHERMOT, BAJAJ-AUTO;
  ancillary MOTHERSON. Strike: Dec ATM or 1 OTM CE, delta 0.45-0.6 (today: <strike> CE at <premium>). Trigger: auto pre-open
  +0.5% or more, then NIFTY AUTO CONFIRMED UP at 09:20 and the share above its 09:15-09:20 high and VWAP. PE watch (other side):
  HINDALCO, VEDL, NATIONALUM, POLYCAB, KEI. Cancels if: LME copper or aluminium rebounds 1.5%+ overnight, Brent +2%, GIFT -0.5%
  or worse. Closest past case: <date, hit rate n of N> or 'rule of thumb, not measured yet'."
- **18 Nov 22:45 - only if the grade changes** (LME closes about 22:30 IST): "AUTO CE watch STRONGER / WEAKER: LME close copper
  <x>%, aluminium <x>%, MCX <x>%." Silent log line if unchanged.
- **19 Nov 07:15** - "AUTO CE WATCH STANDS - grade STRONG: LME close and SHFE night still down, Brent <x>%, rupee <x>%, GIFT <x>%.
  Auto futures OI on 18 Nov: short build-up in <names> = squeeze fuel. Order at the open: ASHOKLEY, MARUTI, then HERO, TVS, M&M."
  Or: "CANCELLED: copper +<x>% overnight." Always one of STANDS / CHANGED / CANCELLED against the 19:45 list.
- **19 Nov 09:08 (pre-open)** - "TRIGGER MET: MARUTI +<x>%, ASHOKLEY +<x>%, NIFTY AUTO +<x>% in pre-open, NIFTY METAL <x>%.
  GET READY: Dec <strike> CE MARUTI at <premium>, Dec <strike> CE ASHOKLEY at <premium>, no chase above <limit>." If an auto share
  gaps more than 2.5%: "already priced - enter only on the first dip to VWAP, 1 lot" (E5 trend-day rule).
- **19 Nov 09:20 - the open** - "NIFTY AUTO CONFIRMED UP since 09:20: breadth <n>/<N> (>= 70%), beats NIFTY by <x>% (>= 0.7%),
  long build-up in <n> auto futures, above VWAP." Then the normal E8 card: **GO NOW at 09:30** (entry window) on the leader that
  holds above VWAP and its opening range; laggards GO NOW only when they start to follow. Exit by 15:10.
- **Cancel at the open if:** pre-open autos flat or red; metals pre-open green; NIFTY gaps -0.7% or worse; auto breadth < 50% at
  09:20; the gap fills below the 15-minute low by 09:45; one share doing most of the move (TRAP, E3); bad own news.
- **15:45 audit:** the chain is scored (named at 19:45? confirmed? GO NOW time? CE result at 15:10). Absent at 19:45 = MISS.

## B. THE ENGINE

**B1. The chain map** (the knowledge base, data/kb/chains): one row per driver x direction x F&O share:
`chain id · driver · direction · channel · sector · share · sign (CE/PE) · size (margin bp per 1% move, or measured next-day move
per 1%) · lag (same day / next open / 2-5 days / weeks) · role (leader / follower / laggard) · source (research / measured) ·
hit rate, n, median move · last fired`. Channels: **cost** (an input gets cheaper or dearer), **revenue** (the product price),
**demand** (rates, EMIs, monsoon, sales), **policy** (duty, tax, regulator), **flow** (FII, rotation between sectors),
**peer** (a leader's result or sales moves its peers). Both sides of every driver are always present (losers AND winners).
Drivers include world prices AND **domestic sector moves**: a sector CONFIRMED down with short build-up whose driver is an input
commodity triggers its USERS as a CE watch (and the reverse).

**B2. How it is built** (this week; existing code reused first - knowledge.py, nightstudy.py, morningmkts.LINKS, themestudy.py,
histstore.py; check each before writing new code):
1. Research seed: the 25+ chains of section C, plus for every F&O auto, paint, tyre, OMC, FMCG, cement, durables, cable and
   metal share: raw material % of sales, the metal / crude / rubber mix, margin change per 1% move, contract lag (annual reports,
   broker sector notes).
2. History: 10 years daily (5 at least) of every F&O share, sector index and driver: Kite historical (shares, indices, MCX),
   **NSE F&O bhavcopies (free, daily, with OI, back to the 2000s)** - so "no free history" in BUILD_PLAN 1.5 is true for minute
   data only - plus LME official prices (Westmetall), SHFE/DCE (AKShare), Brent, USD/INR, US yields; paid series per section E.
3. Back-test every chain: event day = driver move over its threshold on 1 day OR over 3 / 5 days cumulative (the 18 Nov fall built
   through the day; -1.5% a day for 3 days must fire). Outcome = the share and sector vs NIFTY at next open, next close and days
   2-5, AND the option-buyer test: did the share move 1.5%+ its way from the open before 15:10? Record hit rate, median move, lag,
   and what made it fail (crude against, market gap down, already priced). Fewer than 15 events = "rule of thumb, not measured".
4. The trader reviews the table once (30 min) and marks the chains he trusts from experience.

**B3. How it runs (step E2b, the second-order analyst - code first, AI only writes the sentences):**
- **19:45** - every driver past its E1 threshold (1-day or 3/5-day), every NSE sector that moved 1.5%+, and every "driver moved
  but its users did not react yet" gap (S8 #8 across days) -> through both sides of the map -> merged per sector (two chains to the
  same sector add up) -> graded -> TOMORROW'S OPTION WATCH (CE list, PE list, leader / laggard, strike, trigger, cancel, analogue).
- **22:45** - LME close and MCX late session: one line only if a grade changes.
- **07:15** - LME close, SHFE night, COMEX, Brent, rupee, GIFT, overnight news: STANDS / CHANGED / CANCELLED per item.
- **09:00 / 09:08** - SHFE/Dalian day open (06:30 IST) re-check, pre-open (F09) vs the triggers: GET READY with strikes worked out.
- **09:20 onward (live)** - E3 confirms the sector from the whole sector; E8 gives GO NOW; in session, a driver move > 1.5% not
  yet followed by its shares after 15-30 min is a commodity-lag idea (E1).
- One sound per alert; the evening and 07:15 notes are messages, not alarms.

**B4. How it scores confidence (points; shown as the grade with its reasons):**
| Test | Points |
|---|---|
| Driver size vs its own normal (60-day): >= 1.5 sigma / >= 2.5 sigma | +1 / +2 |
| Linked drivers move together (copper + aluminium + steel) | +1 |
| Persistence: closed near the day's extreme, or 3-day move the same way | +1 |
| Domestic proof: the losing sector CONFIRMED with short build-up today | +1 |
| The winners have NOT priced it yet (flat or down today) / already up 2%+ today | +1 / -1 |
| Overnight confirms (LME close, SHFE night) / reverses past the cancel level | +1 / CANCEL |
| Each other driver aligned (crude, rupee, GIFT, FII) / against | +1 each (max +2) / -1 each |
| Winners' futures short-heavy over 3 days (squeeze fuel) | +1 |
| Supporting news / contrary news | +1 / -2 |
| Measured hit rate >= 60% (n >= 15) / below 45% | +1 / -2 |
Grade: 0-2 = no line · 3-4 WEAK (watch only) · 5-6 MEDIUM (GET READY at the open if triggered) · 7+ STRONG. 18 Nov as described
scores about 5 at 19:45 (size, three metals, all-day fall, metals short build-up, autos not yet up) and 6-7 at 07:15 with the LME
close and crude - to be re-scored from the recorded numbers in the replay.

**B5. How it learns:** every chain that fires is a row in the chain ledger (date, inputs, grade, shares named, strike, 22:45 /
07:15 / 09:08 status, next-day result, CE/PE result by 15:10). At 15:45 every F&O share 3%+ and sector 1.5%+ that GIR did not name
the evening before is searched against the map for a driver that moved in the 1-3 days before: a chain that existed but did not
fire -> its threshold is fixed; no chain -> a new candidate is added and back-tested that night. Hit rates per chain are updated
nightly and quoted in every note; a chain under 45% after 20 fires is demoted to "info only". Weekly: best and worst chains to the
trader.

## C. THE CHAIN TABLE (both directions; reverse the sides when the driver moves the other way)
| # | Driver | Channel | PE side | CE side | Lag | Past date |
|---|---|---|---|---|---|---|
| 1 | Copper / aluminium / steel DOWN | cost | HINDALCO, VEDL, NATIONALUM, POLYCAB, KEI, HINDCOPPER | ASHOKLEY, MARUTI, TVSMOTOR, HEROMOTOCO, M&M, EICHERMOT, BAJAJ-AUTO, MOTHERSON, VOLTAS | next open, days | 18 -> 19 Nov 2026 |
| 2 | Brent DOWN (up = reverse) | cost | ONGC, OIL | BPCL, HPCL, IOC, ASIANPAINT, BERGEPAINT, INDIGO, APOLLOTYRE, MRF, ASHOKLEY | next open; paints/tyres days | 5 Nov 2026 (reported); 24 Jun 2025 (verify) |
| 3 | Brent UP sharply / war | cost, flow | BPCL, HPCL, IOC, INDIGO, ASIANPAINT, tyres | ONGC, OIL, HAL, BEL | same day | 13 Jun 2025 |
| 4 | Iron ore / China steel DOWN | revenue / cost | NMDC, TATASTEEL, JSWSTEEL, SAIL, JINDALSTEL | autos, capital goods | next day | find a date |
| 5 | China stimulus / Dalian UP | revenue | (metal users) | TATASTEEL, JSWSTEEL, JINDALSTEL, SAIL, NMDC, HINDALCO, VEDL | same morning | 24 Sep 2024 |
| 6 | Coking coal UP | cost | TATASTEEL, JSWSTEEL, SAIL | COALINDIA | days | find a date |
| 7 | Copper UP sharply | revenue / cost | POLYCAB, KEI, HAVELLS, VOLTAS | HINDCOPPER, VEDL, HINDALCO | same / next day | 8-9 Jul 2025 (US copper tariff; verify) |
| 8 | Aluminium UP | revenue / cost | autos, packaging | NATIONALUM, HINDALCO, VEDL | next day | find a date |
| 9 | Zinc / silver UP | revenue | - | HINDZINC, VEDL | same / next day | find a date |
| 10 | Gold UP (down = reverse, 18 Nov) | collateral / cost | TITAN, KALYANKJIL (sharp rise) | MUTHOOTFIN, MANAPPURAM | same / next day | 18 Nov 2026 (gold -2%) |
| 11 | Rupee WEAK | revenue / cost | BPCL, HPCL, IOC, dollar-debt names | INFY, TCS, HCLTECH, WIPRO, TECHM, pharma exporters | same day | find a date |
| 12 | Nasdaq / INFY-WIT ADR DOWN 2%+ | peer, flow | INFY, TCS, HCLTECH, WIPRO, TECHM, LTIM, MPHASIS | - | next open | find a date |
| 13 | SOX / US electronics UP | peer | - | DIXON, KAYNES | next open | find a date |
| 14 | India 10y DOWN / RBI cut | demand | - | HDFCBANK, ICICIBANK, PSU banks, BAJFINANCE, LICHSGFIN, DLF, GODREJPROP, autos | same day | 6 Jun 2025 (RBI -50 bp + CRR cut) |
| 15 | US 10y / DXY UP | flow (FII selling) | private banks, heavyweights | IT (rupee side) | next day, days | find a date |
| 16 | Gas / LNG DOWN | cost | ONGC (gas price) | IGL, MGL, GUJGASLTD, fertilisers | days | find a date |
| 17 | Pet coke / coal DOWN | cost | COALINDIA | ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT | days-weeks | find a date |
| 18 | Natural rubber DOWN | cost | - | MRF, APOLLOTYRE, BALKRISIND, CEATLTD | days | find a date |
| 19 | Crude derivatives / palm oil DOWN | cost | - | HINDUNILVR, GODREJCP, DABUR, PIDILITIND, ASIANPAINT | days-weeks | find a date |
| 20 | PVC / chemicals DOWN | cost | - | ASTRAL, SUPREMEIND, PIDILITIND | days | find a date |
| 21 | GST / tax cut on a product | policy, demand | - | MARUTI, HEROMOTOCO, TVSMOTOR, BAJAJ-AUTO (GST on vehicles) | next open | 15 -> 18 Aug 2025 (PM's GST reform speech) |
| 22 | Duty on an INPUT (e.g. bulk Scotch) | cost, policy | UNITDSPR, RADICO | - | same day | 19 Nov 2026 (UNITDSPR) |
| 23 | Anti-dumping / safeguard duty on imports | policy | (importing users) | TATASTEEL, JSWSTEEL, SAIL | same day | find a date |
| 24 | Regulator order (SEBI margins, MTF, NPCI) | policy | ANGELONE, BSE, CDSL, MCX, PAYTM (read the sign per share) | per share (MCX 18 Nov = CE) | minutes | 18 Nov 2026 |
| 25 | Monthly auto sales beat (1st) / VAHAN | peer, demand | weak reporter | the leader's peers, MOTHERSON, SONACOMS | same / next day | 1st of any month |
| 26 | Leader's results beat (TCS, HDFCBANK) | peer | - | laggard peers | next day | find a date |
| 27 | Monsoon / IMD good | demand | - | M&M, ESCORTS, HEROMOTOCO, HINDUNILVR, fertilisers | days-weeks | find a date |
| 28 | US FDA approval / warning | revenue | the warned company | its rivals (other way) | same day | find a date |
| 29 | Big metals rally | flow | HINDUNILVR, NESTLEIND, pharma (money out) | metals | same day | find a date |
Every "find a date" is filled from the 10-year back-test before the chain is quoted with a hit rate; "verify" dates are checked
against Kite daily data first, and a wrong date is corrected, not kept.

## D. REPLAY TESTS - must pass before Monday 23 Nov 08:30 (run Sat 21, dress rehearsal Sun 22 20:00)
Same v2 code as live, only data that existed at each minute. Old dates have no minute recordings: those replays test the EVENING
and 07:15 NOTES from daily data (right sectors, right side, right shares, before the open) and are labelled "daily data".
| # | Case | Pass criteria |
|---|---|---|
| D1 | **18 -> 19 Nov 2026 autos CE** (binding) | 18 Nov 19:45 note names CE AUTOS with ASHOKLEY and MARUTI as leaders, HERO / TVS / M&M / EICHER, Dec strikes, trigger and cancel lines, grade MEDIUM or better; PE side names metals / cables; 07:15 says STANDS; 09:08 GET READY with strikes; NIFTY AUTO CONFIRMED at 09:20; GO NOW on the leader by 09:30-09:35; 15:45 audit scores it. If 18 Nov evening inputs were not recorded, rebuild them from daily data and label the test so - never pass it by hand. |
| D2 | 4 -> 5 Nov 2026, Brent about -9% (reported) | 4 Nov evening note: CE OMCs, paints, INDIGO, autos/ASHOKLEY; PE ONGC, OIL. Check the facts in Kite daily data first. |
| D3 | 13 Jun 2025, Brent spike (Israel-Iran) | 07:15 note: PE OMCs, INDIGO, paints; CE ONGC, OIL, defence. |
| D4 | 24 Sep 2024, China stimulus | 07:15 / 08:45 note: CE metals (TATASTEEL, JSWSTEEL, HINDALCO, VEDL, NMDC). |
| D5 | Fri 15 Aug 2025 GST reform speech -> Mon 18 Aug | weekend / 07:15 note: CE MARUTI and two-wheelers (policy chain), before the open. |
Pass for D2-D5 = right side on at least 80% of the named shares and no share named on the wrong side. Any failure is fixed in the
map or the thresholds and the whole set is re-run.

## E. WHAT THE TRADER MUST PROVIDE (each with cost per month and his yes before buying - first evening report)
1. **MCX and CDS live data on Kite** (F02 says paid but not subscribed) - metals, crude and rupee at 19:45 and at 22:45.
2. **Kite Connect with historical data** on at least one key - 10 years daily, continuous MCX futures.
3. **Indian steel prices: BigMint (SteelMint) subscription** - HRC, TMT, iron ore, coking coal, daily. No free source exists.
4. **A global futures feed** (e.g. Databento or Barchart) - COMEX copper / gold, ICE Brent, SGX iron ore and TSR20 rubber, live and
   history; SHFE / Dalian through AKShare (free) first, a paid China feed only if it lags.
5. **LME data:** Westmetall official prices (free) for history; LME close daily; a paid LME licence only if the free close is late.
6. **Expired options / IV history and older intraday F&O** (e.g. Global Datafeeds or TrueData - get quotes): option back-tests.
7. **Company cost data for 10 years** (Screener premium, Trendlyne or CMIE Prowess - quotes): raw material % of sales per company.
8. **Paid news already approved in BUILD_PLAN 0.6** (ET Prime, Moneycontrol Pro, Business Standard) plus a news archive for
   back-tests (GDELT free first).
9. **Server room:** a database (TimescaleDB / Postgres) with about 500 GB SSD and 16 GB RAM, and a nightly back-test job slot
   (can be a second small VPS so it never slows the live engine).
10. **30 minutes of his time** to review the chain table (B2 step 4), and his yes or no on each item above.
