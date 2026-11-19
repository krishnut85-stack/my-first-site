# GIR LINK BOOK - every driver and every sector, both sides (19 Nov 2026)

The trader, 19 Nov: "Don't think about copper. If something else is coming down, which shares will be affected because of that
sector coming down? Which sector will benefit and which sector will get affected? The links between them in detail, the past study."

This book answers that for every driver and sector the desk watches. It merges 12 expert sheets written on 19 Nov 2026: crude,
gold and silver, steel / iron ore / coal, other metals, rupee and dollar, rates, US and global, agri and monsoon, gas and power,
government policy, sector-to-sector rotation, and monthly data. Copper and aluminium -> autos, ACs and cables are NOT repeated
here: they live in design_v3/COPPER_LINKS.md. The binding companions are design_v3/SECTOR_LINKS.md (links L01-L17 and the proof
rule) and design_v3/CHAIN_OF_EVENTS.md (the chain table and the 19:45 engine, step E2b).

**How to read it**
- **CE side** = shares expected to go up (the call side). **PE side** = shares expected to go down (the put side).
- **Strength** HIGH / MEDIUM / LOW. **Lag** = when the share reacts (same day, next open, days, weeks, quarters).
  Only same-day and next-open links are intraday trades. Weeks and quarters are background tilts, never a trigger.
- **[V]** = verified: a named news source reports the figure (the source list closes each group). Most figures are intraday
  snapshots and outlets differ by 0.1-1 point, so check the NSE bhavcopy before using a figure as a beta.
- **[E]** = ESTIMATE: desk judgement, not yet checked against NSE data.
- **Every link in this book is IDEA - NOT PROVEN** until the history database passes it under the SECTOR_LINKS part C rule
  (at least 30 events, hit rate at least 58% and at least 8 points above normal, holds in both halves of the history and in
  the last 2 years). No hit rate has been measured yet. Until it is, GIR may show a link on the watch as an idea, never as
  the reason for a CE / PE call.
- **No live prices were used.** The Kite connection (claude-code-kite) timed out in every session that wrote these sheets.
- **F&O check on the day.** Before GIR names a share, confirm it is on the current NSE F&O list. Uncertain today: KALYANKJIL,
  HINDZINC, IIFL, JSL, APLAPOLLO, IEX, ADANIPOWER, ACC, DALBHARAT, NBCC, MGL, CHAMBLFERT, COROMANDEL, TORNTPOWER, NHPC, SJVN,
  IREDA, SUZLON, INOXWIND, WAAREEENER, PREMIERENE, CEATLTD, PATANJALI, M&MFIN, PNBHOUSING, KAYNES, PGEL, AMBER, WHIRLPOOL,
  DELTACORP, NAZARA, SOLARINDS, DATAPATTNS, BEML, TITAGARH, JWL, BDL, MAZDOCK, IRFC, ETERNAL, CONCOR, DELHIVERY.
  MRF options are too illiquid and high-priced: show the next name instead.
- **Ticker spellings used here:** TMPV / TMCV (was TATAMOTORS), SAMMAANCAP (was Indiabulls Housing), INDUSTOWER (was Bharti
  Infratel; some sheets wrote INDUSTOWERS), RECLTD (REC), COLPAL (Colgate), BLUESTARCO, ARE&M (was AMARAJABAT), HINDPETRO (HPCL).
- **Cash-only names (never shown as CE / PE):** SENCO, PCJEWELLER, THANGAMAYIL, CSB, Kansai, Indigo Paints, KPR Mill, Vardhman,
  Welspun Living, Gokaldas, Arvind, AWL, BCCL, Kajaria, Somany, Cera, RRKABEL, FINCABLES, EID Parry, Bajaj Hindusthan, and most
  fertiliser PSUs (RCF, FACT, GNFC, DEEPAKFERT).

**Contents**
- A. Master table (one page) - driver -> move -> CE side -> PE side -> lag -> strength
- A2. "A sector moved sharply today - who else is linked?" (the reverse lookup)
- B. The 12 groups, full sheets (cleaned): B1 Crude · B2 Gold and silver · B3 Steel, iron ore, coal · B4 Aluminium, zinc, lead,
  nickel · B5 Rupee and dollar · B6 Rates, RBI, liquidity · B7 US and global · B8 Agri and monsoon · B9 Gas, power, renewables ·
  B10 Government and regulators · B11 Sector-to-sector rotation · B12 Monthly and scheduled data
- C. When links fail - the common traps in one list
- D. The evening note templates
- E. How GIR uses the book

---

## A. MASTER TABLE

Leader first in each list. "Rev." = the same row with the sides swapped when the driver moves the other way.
All rows are IDEA - NOT PROVEN until the history database tests them.

| # | Driver / sector | Move | CE side (sectors, leaders) | PE side (sectors, leaders) | Lag | Strength |
|---|---|---|---|---|---|---|
| 1 | Brent crude | falls 2%+ day / 5%+ week | OMCs HINDPETRO, BPCL, IOC; INDIGO; autos ASHOKLEY; slower: paints ASIANPAINT, BERGEPAINT; tyres APOLLOTYRE; city gas IGL, MGL, GUJGASLTD; rupee and bonds firm | ONGC, OIL; RELIANCE (low) | same day / next open; paints, tyres 1-5 days | HIGH OMCs, INDIGO, ONGC; MED paints, tyres, autos |
| 2 | Brent crude | rises sharply (war, supply) | ONGC, OIL; war: HAL, BEL, BDL | HINDPETRO, BPCL, IOC, INDIGO, ASIANPAINT, tyres, autos, BAJFINANCE, banks, NIFTY | same day | HIGH, about 1.5x the fall [E] |
| 3 | Fuel policy | excise / retail price cut, OMCs told to absorb | - | HINDPETRO, BPCL, IOC, whatever crude does | same day | HIGH |
| 4 | Windfall tax on crude | imposed (removal: rev.) | - | ONGC, OIL, RELIANCE | same day | HIGH |
| 5 | Gold (world) | falls | jewellers TITAN, KALYANKJIL (low, weeks) | gold lenders MUTHOOTFIN, MANAPPURAM, IIFL; MCX only if volume fades | same day (gap at open) | HIGH lenders |
| 6 | Gold (world) | rises | MUTHOOTFIN, MANAPPURAM, IIFL, MCX; TITAN, KALYANKJIL (low) | jewellers on demand (weeks) | same day | HIGH lenders |
| 7 | Gold import duty | cut (hike / "don't buy gold" appeal: rev., KALYANKJIL leads) | TITAN, KALYANKJIL | MUTHOOTFIN, MANAPPURAM | same day | HIGH |
| 8 | Silver | rises (falls: rev.) | HINDZINC, VEDL, MCX | (solar, electronics: too weak to trade) | same day / next open | HIGH HINDZINC |
| 9 | China steel / SHFE HRC | falls (rises: rev., plus APLAPOLLO CE) | users autos, LT, BHEL, VOLTAS (weeks only) | SAIL, JINDALSTEL, TATASTEEL, JSWSTEEL, JSL; APLAPOLLO (inventory) | same day | HIGH steel PE |
| 10 | China stimulus / PBoC cut | announced | VEDL, SAIL, TATASTEEL, JINDALSTEL, NMDC, HINDALCO, NATIONALUM, HINDZINC | weeks later: FII heavyweights, banks ("sell India, buy China") | same day | HIGH |
| 11 | Weak China data / yuan down / China steel exports up | - | - (pharma, FMCG hold) | TATASTEEL, JSWSTEEL, SAIL, VEDL; TMPV (JLR China) | same day | HIGH metals, MED TMPV |
| 12 | Iron ore (DCE / NMDC prices) | falls (rises: rev., TATASTEEL, JINDALSTEL gain as ore owners) | JSWSTEEL (quarters only) | NMDC; steel in sympathy on the day | same day | HIGH NMDC |
| 13 | Coking coal | rises (falls: rev.) | - | JSWSTEEL, SAIL, JINDALSTEL; TATASTEEL less | next day to weeks | MED |
| 14 | Thermal coal / pet coke | falls | cement SHREECEM, DALBHARAT, AMBUJACEM, ACC, ULTRACEMCO | COALINDIA (e-auction premium) | days to weeks | MED |
| 15 | Coal or power shortage | coal up, IEX prices spike | COALINDIA, NTPC, TATAPOWER, JSWENERGY, ADANIPOWER, IEX | cement ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT | same day to weeks | HIGH COALINDIA |
| 16 | Steel import duty / safeguard / floor price | imposed | SAIL, JSWSTEEL, TATASTEEL, JSL | APLAPOLLO, steel users (low) | same day (on the recommendation) | HIGH |
| 17 | Steel / ore export duty | imposed (rollback: rev.) | users (weak, weeks) | JINDALSTEL, SAIL, TATASTEEL, JSWSTEEL, NMDC | next open | HIGH, biggest in metals |
| 18 | LME aluminium | rises (falls: rev.) | NATIONALUM, VEDL, HINDALCO | 2-wheelers, cables (quarters, no intraday) | next open | HIGH NATIONALUM |
| 19 | Alumina alone | falls, aluminium flat | - | NATIONALUM only | same day | HIGH |
| 20 | Zinc (check silver first) | rises (falls: rev.) | HINDZINC, VEDL | galvanizers (quarters) | next open | HIGH |
| 21 | Lead | falls over a month (rises 8-10%+: rev.) | ARE&M, EXIDEIND | - | weeks | MED |
| 22 | Nickel | any big move | no trade; JSL watch; "metals mood" | - | 1-2 days | LOW |
| 23 | Rupee | weakens 0.4%+ or record low (strengthens: rev.) | IT INFY, WIPRO, HCLTECH, TCS, mid IT; pharma AUROPHARMA, LUPIN, SUNPHARMA; BALKRISIND, BAJAJ-AUTO; ONGC; MUTHOOTFIN | HINDPETRO, BPCL, IOC, INDIGO; DIXON, AMBER, VOLTAS; paints; city gas; HDFCBANK, ICICIBANK, BAJFINANCE | same day | HIGH IT (if Nasdaq calm), HIGH OMCs (if crude up) |
| 24 | DXY up + US 10y up | together (down: rev.) | IT only relative | SBIN, PNB, HDFCBANK, ICICIBANK, BAJFINANCE, DLF; metals VEDL, HINDALCO, NATIONALUM, TATASTEEL | next open, lasts days | MED-HIGH |
| 25 | RBI surprise cut / India 10y down 8-10 bp+ | (expected cut = no trade) | realty GODREJPROP, DLF; NBFC BAJFINANCE, CHOLAFIN, LICHSGFIN; autos; PNB, BANKBARODA | repo-linked banks KOTAKBANK, BANDHANBNK, AUBANK (margin); cash-rich defensives lag | same day | HIGH realty, NBFC |
| 26 | RBI hike / hawkish / 10y jumps | - | relative: TCS, INFY, HINDUNILVR; deposit-rich banks over quarters | GODREJPROP, DLF, BAJFINANCE, CHOLAFIN, LICHSGFIN, PSU banks, autos | same day, confirm 10:15 | HIGH |
| 27 | RBI liquidity injection | OMO, VRR, CRR cut, swap | AUBANK, PNB, AXISBANK, BANKBARODA, BAJFINANCE, realty | - | next day | HIGH |
| 28 | RBI tightens lending rules | risk weights, LTV, gold-loan rules | - | SBICARD, BAJFINANCE, the named lenders | next day | HIGH |
| 29 | Credit event | NBFC default, CP freeze | relative: HDFCBANK, ICICIBANK, KOTAKBANK | housing finance LICHSGFIN, wholesale-funded NBFCs, SHRIRAMFIN, CHOLAFIN; lending banks INDUSINDBK, AXISBANK | same day, then 2-5 days | VERY HIGH |
| 30 | Nasdaq / US tech | +-1.5% (read the ADRs and the cause) | INFY, TECHM, WIPRO, COFORGE, PERSISTENT, MPHASIS; DIXON, KAYNES on AI-hardware days | same names on a fall | next open | MED (broken in 2026) |
| 31 | Accenture / Cognizant results | beat (miss: rev.) | Indian IT, TECHM, COFORGE | - | next open | HIGH |
| 32 | Fed | dovish surprise (hawkish: rev.) | DLF, ICICIBANK, SBIN, TATASTEEL, INFY | hawkish: banks, realty, index; rupee falls | next open, confirm 09:08 | MED |
| 33 | Global risk-off | VIX spike, carry unwind, tariff shock (relief: rev.) | relative, above VWAP only: SUNPHARMA, CIPLA, FMCG | TATASTEEL, VEDL, SAIL, SBIN, PSU banks, DLF, high-beta PSEs | same day | HIGH |
| 34 | US visa curb | H-1B fee | - | TECHM, LTIM, MPHASIS, INFY, TCS (pharma often falls too) | next open | HIGH |
| 35 | US drug tariff | - | - | SUNPHARMA (branded); AUROPHARMA, LUPIN, ZYDUSLIFE, DRREDDY, GLENMARK (generics) | next open | HIGH |
| 36 | US tariffs | on China (on India: rev., metals, exporters PE) | DIXON, KAYNES ("China+1") | - | next open | MED |
| 37 | FII flows | 5-day net sell above Rs 5,000 cr (buy: rev.) | - | HDFCBANK, ICICIBANK, RELIANCE, IT | 1-5 days | LOW (a tilt) |
| 38 | Monsoon / IMD forecast | good or upgraded (bad, El Nino: rev.) | ESCORTS, M&M, HEROMOTOCO, TVSMOTOR; DABUR, HINDUNILVR, MARICO, COLPAL, ITC; UPL, PIIND; M&MFIN | power IEX, NTPC, TATAPOWER | same day (forecast day) | HIGH tractors, MED FMCG |
| 39 | Sugar policy | export ban, ethanol cap (quota, ethanol price up: rev.) | - | BALRAMCHIN (often 2 days) | same day | HIGH |
| 40 | Palm oil / copra | up 6%+ or exporter ban (down: rev., slow) | refiners on a duty hike (PATANJALI) | GODREJCP, BRITANNIA, HINDUNILVR, MARICO | same day on a shock | MED |
| 41 | Natural rubber | falls 5%+ in a week, Brent not up (rises: rev.) | APOLLOTYRE, CEATLTD, MRF, BALKRISIND | - | days | MED |
| 42 | Fertiliser subsidy / NBS rates | cut, MRP cut (raised, priority gas: rev.) | - | COROMANDEL, CHAMBLFERT | same day | HIGH |
| 43 | Spot LNG | falls (spike, supply shock: rev., PETRONET leads) | GUJGASLTD, PETRONET, IGL, MGL, GAIL | - | same day sentiment, margins 2-8 weeks | HIGH GUJGASLTD |
| 44 | APM gas allocation | cut, price unchanged (cap, extra allocation, CNG hike: rev.) | - | IGL, MGL; GUJGASLTD less | same day | HIGH |
| 45 | Power demand | heatwave, peak record | TATAPOWER, JSWENERGY, NTPC, COALINDIA, IEX; VOLTAS, BLUESTARCO | cement only if coal is short | same / next day | MED (summer only) |
| 46 | Power demand | weak, early monsoon | - | JSWENERGY, TATAPOWER, COALINDIA, VOLTAS, BLUESTARCO (NOT IEX) | days | MED |
| 47 | CERC order on exchanges | coupling, price cap, fee cut | - | IEX | same day | HIGH |
| 48 | Solar module prices / green tenders | modules down, GST cut (import duty, ALMM: rev.) | TATAPOWER, ADANIGREEN, JSWENERGY, NHPC, SJVN, IREDA, SUZLON, INOXWIND | WAAREEENER, PREMIERENE | weeks | LOW-MED |
| 49 | Big thermal / transmission order | - | BHEL, SIEMENS, CGPOWER, POWERGRID | - | same day (BHEL 4-6%) | HIGH for BHEL |
| 50 | GST | cut (hike, sin slab: rev., ITC, gaming) | MARUTI, M&M, EICHERMOT, HEROMOTOCO, TVSMOTOR; BAJFINANCE, CHOLAFIN; cement; insurers; FMCG; VOLTAS, HAVELLS | - | next open, first hour; fades in 1-3 weeks | HIGH |
| 51 | Union budget capex | above (below: rev.) | LT, BHEL, SIEMENS, ABB; RVNL, IRFC, IRCTC, CONCOR; HAL, BEL; cement | - | same day | HIGH |
| 52 | STT / capital-gains hike, SEBI F&O curbs | - | - | BSE, ANGELONE, CDSL, MCX, KFINTECH, CAMS | same day; bounce day 2 | HIGH |
| 53 | Income-tax relief | - | TRENT, DMART, TITAN, HINDUNILVR, MARUTI, IHCL | - | same day, often fades | MED |
| 54 | Defence order / conflict | (ceasefire, peace talks: rev.) | BDL, MAZDOCK, HAL, BEL, SOLARINDS, DATAPATTNS | - | same day; 2-3 week run | HIGH |
| 55 | Telecom relief / tariff hike | (AGR ruling, dues demand: rev.; BHARTIARTL mixed) | IDEA, BHARTIARTL, INDUSTOWER | - | same day | HIGH |
| 56 | PLI scheme | new or extended (ended, payout cut: rev.) | DIXON, KAYNES, AMBER, PGEL; SONACOMS, UNOMINDA | - | same day | MED |
| 57 | Elections | strong NDA signal (hung: rev.) | RECLTD, PFC, BEL, BDL, HAL, SBIN, BANKBARODA, PNB, POWERGRID, NTPC | hung: CE relative HINDUNILVR, pharma | same day | VERY HIGH |
| 58 | Regulator action on ONE company | ban, forensic audit, business stop | rivals (weak, weeks) | that share only | minutes | HIGH, not a sector signal |
| 59 | Defensive rotation | Nifty shock day | HINDUNILVR, NESTLEIND, ITC, CIPLA, SUNPHARMA, DRREDDY | PNB, CANBK, BANKBARODA, SBIN, DLF, SAIL, BEL, HAL | same day | HIGH on shock days |
| 60 | Leader's results | beat (miss: rev.) | its peers: TCS / INFY -> IT; HDFCBANK / ICICIBANK -> private banks; MARUTI -> parts; ULTRACEMCO -> cement | - | next open | HIGH own, MED peers |
| 61 | Monthly auto sales (1st) | miss (beat: rev.) | the rival that gained share | the reporter, its peers; MOTHERSON, SONACOMS; tyres; CHOLAFIN, SHRIRAMFIN, M&MFIN | same day | HIGH own, MED peers |
| 62 | CPI vs consensus | 0.3 pp+ below (above: rev.) | SBIN, BANKBARODA, DLF, BAJFINANCE, LICHSGFIN, autos | - | next day | MED |
| 63 | ATF price (1st) | cut (hike: rev.) | INDIGO | - | same day | MED |
| 64 | Cement dealer prices | hike sticks (rollback, price war: rev.) | SHREECEM, AMBUJACEM, ULTRACEMCO, DALBHARAT, ACC | - | same day | MED |
| 65 | Index inclusion / exclusion | announced | the included share (announcement day only) | the excluded share | same day | MED |
| 66 | F&O ban / expiry week | - | no new CE / PE on a banned share; next-month strikes in the last 2-3 sessions | - | - | rule |

## A2. A SECTOR MOVED SHARPLY TODAY - WHO ELSE IS LINKED? (the reverse lookup) [E]

First ask WHY the sector moved; the driver decides the links. Then look up the driver row in table A. If no driver is behind
the move, the next-day links are weak (hit rates about 50-56%) and GIR names them as WATCH only, confirmed by 09:20 breadth.

| Sector moved | If the cause was ... | CE side to watch | PE side to watch | Group |
|---|---|---|---|---|
| METALS DOWN | commodity slump (LME, China) | autos, durables (COPPER_LINKS), cement and capital goods slowly | cables POLYCAB, KEI; NMDC; HINDZINC if silver is down | B3, B4 |
| METALS DOWN | risk-off, FII selling, yuan | nothing (users fall too) | metals, PSU banks, realty | B7 |
| METALS UP | China stimulus | NMDC, steel, aluminium | FMCG, pharma (money out); weeks later FII heavyweights | B3, B7, B11 |
| OMCs DOWN | crude up | ONGC, OIL; defence on war | INDIGO, paints, tyres, autos, banks, NIFTY | B1 |
| OMCs DOWN | fuel policy (excise, absorb) | nothing linked | OMCs only | B1, B10 |
| IT DOWN | Nasdaq / AI fear | - | EMS DIXON, KAYNES on AI-hardware selling | B7 |
| IT DOWN | US visa or tariff policy | - | pharma falls too (both US-exposed) | B7, B11 |
| IT DOWN | rupee strengthening | OMCs, INDIGO, paints, banks (FII inflow) | pharma exporters | B5 |
| PSU BANKS DOWN | political doubt / election | relative: FMCG, pharma | defence, PSEs, power, railways | B10, B11 |
| PSU BANKS DOWN | bond yields up | relative: IT, FMCG | realty, NBFCs | B6 |
| NBFCs DOWN | credit event | relative: big deposit banks | housing finance, lending banks | B6, B11 |
| NBFCs DOWN | RBI rule on unsecured credit | - | SBICARD, BAJFINANCE, the named lenders | B6, B10 |
| REALTY UP | rate cut / housing sales | cement, building materials (days to weeks) | - | B6, B11 |
| AUTOS DOWN | weak monthly sales | rival that gained share | parts, tyres, vehicle financiers | B12 |
| AUTOS UP | metals / crude / rates down | parts (MOTHERSON, SONACOMS) | - | B1, B11 |
| CEMENT DOWN | fuel cost up (coal, pet coke) | COALINDIA | - | B3, B9 |
| POWER UP | heatwave / coal shortage | COALINDIA, IEX, ACs VOLTAS, BLUESTARCO | cement if coal is short | B9 |
| DEFENCE UP 8%+ | theme day | - | next day: red-day watch on the same names | B11 |
| FMCG / PHARMA UP while Nifty falls | defensive rotation | next day, if GIFT is up: high beta PNB, DLF, TATASTEEL | FMCG, pharma lag next day | B11 |
| TELECOM: IDEA DOWN | court / funding blow | BHARTIARTL often recovers | INDUSTOWER | B10, B11 |
| CAPITAL MARKETS DOWN | SEBI / STT | - | BSE, ANGELONE, CDSL, MCX together; bounce likely day 2 | B10 |
| CITY GAS DOWN | APM allocation cut | - | IGL, MGL (GUJGASLTD less) | B9 |
| GOLD LENDERS DOWN | gold fall or RBI rule | jewellers only if it is a duty cut | MCX if volumes fade | B2 |
| SHOCK CRASH (any) | panic | market bounces next day; the hit sector bounces a day later (June 2024: PSU fell again day 2, bounced day 3) | - | B11 |

---

## B. THE GROUPS (full sheets, cleaned)

Each group: the links, the leaders, its own traps (common traps are only referenced, see C), past cases, sources.
Each group's evening note lines are in part D.

### B1. CRUDE OIL (BRENT / WTI) AND FUEL PRICES

India imports about 85-88% of its crude, so crude is the most important outside price for Indian stocks.

**1. When Brent FALLS (2%+ in a day, or 5%+ in a week)**

CE side (shares that gain):
- OMCs: HINDPETRO, BPCL, IOC. Channel: cost. Retail petrol and diesel prices barely move, so a cheaper barrel goes straight
  into marketing margin. Strength HIGH. Same day or the next open.
- Aviation: INDIGO. Channel: cost. Jet fuel (ATF) is about 35-40% of its costs [E], and ATF prices reset on the 1st of each
  month. HIGH for sentiment the same day; the earnings gain comes the next quarter.
- Paints: ASIANPAINT, BERGEPAINT (Kansai and Indigo Paints are not in F&O). Cost: about 40-55% of raw material is crude-linked
  (monomers, solvents, TiO2 processing) [E]. MEDIUM. The move builds over 1-5 days; margins follow 1-2 quarters later.
- Tyres: APOLLOTYRE, MRF, BALKRISIND, CEATLTD. Cost: synthetic rubber, carbon black and nylon cord are about 40-50% of raw
  material [E]. MEDIUM. Days to weeks.
- Chemicals and adhesives: PIDILITIND (VAM), SRF; FMCG with plastic packaging (HINDUNILVR, GODREJCP, DABUR, COLPAL). Cost.
  LOW-MEDIUM. Weeks to quarters: a background tilt, not an intraday trigger.
- Autos, especially ASHOKLEY and 2-wheelers: cheaper diesel and petrol mean more demand; cost and sentiment. MEDIUM. Same day
  (on 5 Nov 2026 autos moved with crude).
- City gas IGL, MGL, GUJGASLTD, when LNG falls with crude: cost. MEDIUM. Days.
- Logistics CONCOR, DELHIVERY (check F&O): diesel is a cost. LOW.
- Index and rates: the rupee firms (smaller import bill and current-account deficit), the 10-year bond yield falls, private banks
  and NBFCs (HDFCBANK, BAJFINANCE) get a mild lift, NIFTY a mild risk-on lift. Rule of thumb [E]: every $10/bbl is about
  $13-15bn on the import bill and about 0.3-0.5% of GDP on the current-account deficit.

PE side (shares that lose):
- Upstream ONGC, OIL. Channel: revenue. Each $1/bbl changes ONGC's EPS by roughly 1.5-2% [E]. HIGH. Same day.
- RELIANCE: refining margins (GRM) can soften. LOW, because retail and Jio dominate the stock.
- Exporters: when the rupee strengthens, IT and pharma lose a little in rupee terms. LOW, only on a big rupee move.

**2. When Brent RISES sharply: the table flips, and the move is usually STRONGER**
- PE side: HINDPETRO, BPCL, IOC (strongest), INDIGO, ASIANPAINT, tyres, autos, NBFCs and banks (bond yields rise), broad NIFTY.
- CE side: ONGC, OIL. On war spikes also HAL, BEL, BDL (defence), sometimes gold-linked names.
- The rupee weakens, which also hurts OMCs and INDIGO (dollar costs). IT (INFY, TCS) may hold up.
- Why stronger: a crude spike usually comes with risk-off and FII selling, so the PE side moves faster and further than the CE
  side does on a crude fall. Pattern [E]: a spike gives about 1.5x the fall-day moves the other way.

**3. Leaders**
- Crude down: HINDPETRO leads (largest marketing share, smallest refining share, highest beta: +4 to +5% on a 4-5% Brent fall).
  BPCL second, IOC third (more refining, more diversified). Then INDIGO, then ASHOKLEY among autos. Paints move less, +1 to +2.5%.
- Crude up: HINDPETRO again on the PE side (-5 to -8% on war spikes), then INDIGO (-4 to -8%). On the CE side ONGC usually beats
  OIL in rupee turnover, but OIL often moves more in percent.
- Pattern across the cases below [E]: a 4-5% Brent fall gives HINDPETRO about +4-5%, BPCL +3.5%, IOC +3%, INDIGO +1.5-3%,
  paints +1-2.5%, ONGC -2 to -3%.

**4. Own traps** (common: C1, C2, C3, C5, C8, C10, C13)
- Policy beats crude: excise cuts, OMCs told to absorb part of a price cut, pre-election price freezes -> OMCs fall even when crude
  falls (4-5 Oct 2018). A windfall tax kills the ONGC CE trade (1 Jul 2022). Read the news every evening.
- Demand panic: a crude fall on recession fear (Mar 2020) drags OMCs down with the market. A crude fall with GIFT NIFTY down more
  than 0.7% is not a CE day for OMCs.
- Only a move after the Indian close (US session, 20:00-01:00 IST) is a next-day edge. Use the 07:15 Brent level, not only the close.
- Results: OMCs book inventory LOSSES when crude falls fast, and refining margins drop with crude. No link trade in the 2 days
  around an OMC's results.
- War headlines flip within hours (24 Jun 2025 ceasefire rally faded by the close). Take profits early; the 15:10 exit protects.
- LPG under-recovery and the rupee: a crude fall paired with a rupee fall of more than 0.5% halves the OMC benefit. Check USDINR.
- Paints and tyres in a weak demand quarter, or with a paint price war (Birla Opus entry 2024-26): crude relief is muted. Grade
  them MEDIUM at most.

**5. Past cases**
- 4-5 Oct 2018: excise cut plus OMCs asked to absorb Re 1/litre (the policy trap). HINDPETRO -12.2%, BPCL -10.9%, IOC -10.6% on
  the close; intraday falls up to 25-29%. HINDPETRO rebounded +14.7% on 8 Oct. [V, Business Standard]
- 14 Nov 2018: crude fell about 7% in the US the night before. HINDPETRO, BPCL, IOC rose up to 12%. [V, Business Standard]
- 2 Mar 2022 (Brent $113): ASIANPAINT -4.5%. 7 Mar 2022: Brent touched $139, a 14-year high; Sensex -1,491 points, NIFTY about
  -2.3%. [V, PTI, Business Standard]. OMC and INDIGO moves that day -3 to -6% [E].
- 1 Jul 2022: windfall tax plus fuel export duties. ONGC -13.4%, RELIANCE -7.1% on the close (-8.9% intraday). [V, PTI, Reuters]
- 6 Mar 2025: Brent fell below $70. OMCs and OIL +2-5%; paints and aviation gained. [V, Business Standard]
- 13 Jun 2025: Israel strikes Iran, Brent +7-10%. OMCs, INDIGO, paints fell; ONGC, OIL, defence rose. Sizes [E] (OMCs -2 to -4%).
- 24 Jun 2025: Israel-Iran ceasefire, Brent -3 to -5% (one source -7%). OMCs +3 to +5%, INDIGO +3.3%, ASIANPAINT +0.9 to +1.7%,
  ONGC -2.5%. Gains faded by the close. [V, Business Standard, Groww, Outlook Business]
- 3 Feb 2025: rupee weak plus LPG subsidy cut in the budget: HINDPETRO -7.6%, BPCL -5.2% (see B5). [V]
- 9 Mar 2026: crude shock (US-Iran war). Sensex about -2.9% early; BPCL, HINDPETRO, IOC down more than 8%, INDIGO -7 to -8%,
  ASIANPAINT down more than 4%. [V, Upstox, 5paisa]
- Mar 2026 (12 Mar per the source URL; the rupee sheet put it on 4 Mar - check): Brent hit $100; BPCL, HINDPETRO, IOC fell up to 4%
  that day, about -24% for the year. [V, Business Today]
- 19 Mar 2026: Brent above $112. HINDPETRO -5.4%, BPCL -4.2%, IOC -2.4%. [V, 5paisa / Free Press Journal]
- 15 Apr 2026: Brent below $95. ASIANPAINT +2.4%, BERGEPAINT +1.4%. [V, 5paisa]
- 5 Nov 2026: Brent fell below $100 (about -9% for the move). HINDPETRO +5% to Rs 385, BPCL +3.6%, IOC +3.1% [V, Free Press
  Journal]; NIFTY AUTO +3 to +4%, ASHOKLEY about +9 to +10% (October sales also helped) [E, as reported in CHAIN_OF_EVENTS].
- 15 Mar 2024: Rs 2 petrol / diesel cut: OMCs -2% to -4% [E, size not checked] (see B12).

**Sources**
- https://www.business-standard.com/article/markets/bpcl-hpcl-iocl-tank-upto-29-as-government-fuel-price-cut-118100500173_1.html
- https://www.business-standard.com/amp/article/pti-stories/oil-stocks-tank-up-to-12-118100400885_1.html
- https://www.businesstoday.in/amp/latest/story/petrol-diesel-impact-oil-companies-stocks-lose-rs-125-lakh-crore-in-last-two-trading-sessions-152931-2018-10-05
- https://www.business-standard.com/article/markets/oil-related-stocks-in-focus-hpcl-bpcl-ioc-gain-upto-12-118111400217_1.html
- https://morungexpress.com/sensex-crashes-1491-pts-as-surging-oil-pummels-global-markets
- https://business-standard.com/article/markets/sensex-nifty-drop-over-2-3-as-brent-crude-oil-touches-14-year-high-122030701576_1.html
- https://aniweb.voxturr.us/news/business/sensex-slides-778-points-crude-oil-soars-to-113-a-barrel-amid-escalating-russia-ukraine-tensions20220302163819
- https://udayavani.com/english-news/reliance-industries-stock-tumbles-over-7-pc-ongc-tanks-more-than-13-pc
- https://businessinsider.in/business/corporates/news/mukesh-ambani-anil-agarwal-lose-1-17-lakh-crore-in-a-few-hours-as-government-slaps-two-different-oil-taxes/amp_articleshow/92591441.cms
- https://www.business-standard.com/amp/markets/news/omcs-paint-aviation-stocks-gain-as-brent-crude-oil-slips-below-70-bbl-125030600224_1.html
- https://www.business-standard.com/amp/markets/capital-market-news/psu-omcs-advance-after-crude-oil-slips-125062400270_1.html
- https://groww.in/blog/sensex-and-nifty-mid-day-updates-24th-june-2025
- https://www.outlookbusiness.com/markets/omc-players-iocl-bpcl-hpcl-surge-upto-5-after-crude-prices-retreat-amid-easing-west-asia-conflict
- https://upstox.com/news/market-news/trading/sensex-crashes-over-2-000-pts-nifty-50-slips-below-23-800-amid-the-oil-price-spike-us-iran-war-om-cs-crack-over-8/article-190370
- https://www.5paisa.com/news/crude-sensitive-stocks-fall-as-oil-prices-cross-115-per-barrel
- https://www.5paisa.com/news/oil-sensitive-stocks-rally-as-crude-falls-below-95-boosting-omcs-and-aviation-shares
- https://www.freepressjournal.in/business/jk-tyre-indigo-asian-paints-hpcl-shares-surge-over-8-as-crude-oil-prices-slump
- https://www.outlookbusiness.com/markets/crude-falls-below-100-omc-aviation-tyre-stocks-rally-as-oil-sensitive-sectors-gain
- https://www.businesstoday.in/amp/markets/stocks/story/omc-stocks-bpcl-hpcl-ioc-fall-up-to-4-as-brent-hits-100-key-details-520216-2026-03-12
- Repo: SECTOR_LINKS.md (L05, L06, E2, E3), CHAIN_OF_EVENTS.md (chains 2, 3; tests D2, D3)

### B2. GOLD AND SILVER (jewellers, gold-loan NBFCs, silver users, rupee, safe-haven flows)

**Basic rule:** first ask WHY gold moved. Gold falling on a duty cut and gold falling on world selling hit jewellers in opposite
directions. Gold-loan NBFCs and HINDZINC follow the metal. Jewellers follow demand and policy more than the metal price.
F&O names: MUTHOOTFIN, MANAPPURAM, TITAN, MCX, VEDL; check KALYANKJIL, HINDZINC, IIFL. SENCO, PCJEWELLER, THANGAMAYIL, CSB are
cash only.

**1. The map**
GOLD FALLS (world selling, strong dollar, rate fears)
- PE, HIGH, same day: MUTHOOTFIN, MANAPPURAM, IIFL. Usually 0.5-1x gold's % move on big days [E]. Channel: collateral - each
  pledged gram is worth less, so lending headroom (LTV) shrinks, new loans slow and auction risk rises.
- PE, MEDIUM, same day: MCX only if trading volumes fade. A violent crash raises volume, so MCX can be CE instead.
- CE / mixed, LOW, weeks: KALYANKJIL, TITAN. Buyers come back on dips, especially in the Nov-Feb wedding season and Dhanteras.
  First reaction is often flat to slightly down ("wait for lower", some inventory loss). TITAN is mostly hedged through
  gold-on-lease; KALYANKJIL partly. 16 Nov 2026: gold -1.2%, KALYAN +3%, TITAN +1.1% [E, aggregator data].
- CE, LOW, quarters: a cheaper gold import bill shrinks the current-account deficit and supports the rupee, which helps OMCs and
  INDIGO slightly. Too slow to trade.

GOLD RISES (fear, Fed cuts, central-bank buying)
- CE, HIGH, same day: MUTHOOTFIN (leader), MANAPPURAM, IIFL.
- CE, MEDIUM, same day: MCX (bullion volume and volatility).
- CE, LOW-MEDIUM: TITAN, KALYANKJIL (each sale worth more; coin and bullion sales rise).
- PE, demand, weeks to quarters: the same jewellers. Wedding buyers cut grams or switch to recycled gold (KALYAN: recycled gold
  more than 46% of revenue in Q1 FY27).

SILVER
- Silver UP -> CE HINDZINC: HIGH, same day, roughly 0.5-1x silver's % move [E]. Silver is about 40-45% of its profit [V].
  VEDL: MEDIUM (owns about 61-64% of HZL). MCX: MEDIUM. Silver DOWN -> the reverse, PE on all three.
- Silver users (solar cells WAAREEENER / PREMIERENE, electronics): weak link, silver is a small cost. Do not trade them on silver.

RUPEE and SAFE HAVEN
- Gold in rupees = world gold x USDINR. A weak rupee lifts gold-loan collateral even with world gold flat.
- Very high gold imports widen the current-account deficit and hit the rupee: then IT and pharma CE, OMCs, INDIGO, paints PE
  (weeks). The policy answer is a duty hike or a "don't buy gold" appeal - the jewellers' biggest PE risk (13 May 2026).
- Gold spikes while India VIX rises and NIFTY falls: gold-loan CE holds up better than the index; banks, other NBFCs and
  high-beta midcaps are PE. On a deep panic day everything falls, gold lenders included.

**2. Leaders**
- Gold: MUTHOOTFIN - the purest, most liquid gold-loan book, used by FIIs as the gold proxy. MANAPPURAM is more volatile but
  noisier (Asirvad microfinance, RBI actions, the Bain stake).
- Silver: HINDZINC - the purest silver proxy, swings hard; VEDL lags.
- Policy days (duty changes, PM appeals): KALYANKJIL moves most (higher beta). SENCO moves even more but has no options. TITAN
  is defensive: smaller moves and it reverses first.

**3. Own traps** (common: C1, C3, C5, C8, C11)
- Duty cut: gold falls but jewellers RISE and gold lenders fall (23 Jul 2024). Duty hike is the reverse (13 May 2026).
- RBI rules beat the gold price: 9 Apr 2025, gold at a record, a draft gold-loan circular cut gold lenders up to 12%.
- Indian holiday: a world gold crash during a holiday hits India the next trading day (21 Oct crash, 23 Oct reaction). The
  gap-down at the open is the move; do not chase it after 10:00.
- By day 2-3 of a fall, NBFC moves shrink. In results week, gold-loan AUM and auction data matter more than the metal.
- Gold can FALL during a war scare, because rates and the dollar rise (23 Mar 2026). Do not assume "geopolitics = gold up".
- MCX on a crash day can be CE, not PE: check volume first.
- When NIFTY is down more than 1.5%, gold-loan CE fails even if gold is up.

**4. Past cases**
- 2020 gold rally ($1,500 to $2,031 by August): MUTHOOTFIN +123%, MANAPPURAM +111%, HINDZINC +58%. 12 Aug 2020, after gold
  slumped: MUTHOOTFIN -2.3%, MANAPPURAM -1.9%. [V, Business Standard]
- 23 Jul 2024, budget gold duty cut 15% -> 6%: MCX gold about -5% (over Rs 4,000 per 10g). TITAN +6.6% on the close (+4.7 to
  +7% intraday in other reports), SENCO +4.75 to +11%, KALYANKJIL +1.5 to +6% (sources differ). MUTHOOTFIN -4.31%, MANAPPURAM
  -5.83% at the close. [V, Upstox, Business Today, DNA, Bloomberg]
- 9 Apr 2025, RBI draft gold-loan norms (75% LTV cap): MUTHOOTFIN, MANAPPURAM, IIFL down up to 12% intraday; MUTHOOTFIN another
  -6% on 11 Apr. 6 Jun 2025, cap eased to 85% for loans below Rs 2.5 lakh: up to +7.7%. [V, Business Today, Business Standard]
- 21 Oct 2025: gold -6.3% (biggest one-day fall since 2013), silver -8.7%. India reacted on 23 Oct: MUTHOOTFIN down up to 5%
  (-3.4% at 13:00), MANAPPURAM -2.8%. [V, Business Today, Business Standard]
- Dec 2025 - 23 Jan 2026, silver to a record (about $99): HINDZINC +14% in 3 sessions in mid-December; record Rs 709.95 on
  23 Jan 2026, up 87% from its 52-week low; +5% that day to a 52-week high. [V, Angel One, Business Standard, Business Today]
- 8 Jan 2026: silver fell below Rs 2.5 lakh/kg; HINDZINC -6% to Rs 588, its worst day in 6 months. [V, Business Standard]
- 30 Jan - 1 Feb 2026, gold and silver crash from records (budget Sunday session; exact crash date [E]): intraday HINDZINC
  -13.5% to Rs 543.55, MUTHOOTFIN -7.6% to Rs 3,538, MANAPPURAM -6%, IIFL -4 to -5%. [V, Angel One]
- 5 Feb 2026: silver crash, HINDZINC about -7%. [V, Business Today]
- 23 Mar 2026: gold more than 24% below its January peak (US-Iran tension, rate fears): gold financiers down up to 7% intraday.
  [V, Business Today]
- 11-13 May 2026: PM appeal to skip gold for a year, then duty hike 6% -> 15% on 13 May. Appeal day: TITAN about -6 to -11%,
  KALYANKJIL about -8 to -20% intraday. 13 May: KALYANKJIL -5.6% to Rs 341.45, TITAN roughly flat. Jewellery stocks lost about
  Rs 60,000 crore in 3 days. [V, Outlook Business, Business Today]
- 18 Nov 2026: gold -2%, gold lenders lower (CHAIN_OF_EVENTS row 10). [T, check NSE]

**Sources**
- https://upstox.com/news/market-news/stocks/shares-of-gold-loan-providers-slide-as-budget-2024-cuts-custom-duty-on-bullion/article-104178
- https://upstox.com/news/market-news/stocks/titan-kalyan-jewellers-shares-rise-up-to-8-as-fm-slashes-customs-duty-mcx-gold-falls-over-5-check-details/article-104039
- https://www.businesstoday.in/markets/company-stock/story/titan-pc-jewellers-kalyan-jewellers-shares-rise-fm-sitharaman-budget-2024-speech-438359-2024-07-23
- https://bnnbloomberg.ca/investing/2024/07/23/india-cuts-gold-import-tax-in-boost-to-local-jewelry-makers
- https://www.businesstoday.in/markets/stocks/story/muthoot-iifl-finance-shares-tumble-up-to-12-as-rbi-plans-comprehensive-guidelines-on-gold-loans-471344-2025-04-09
- https://www.businesstoday.in/markets/stocks/story/muthoot-finance-shares-slip-fall-rbi-norms-gold-loans-financing-471650-2025-04-11
- https://www.business-standard.com/amp/markets/news/muthoot-fin-manappuram-gain-upto-8-ahead-of-rbi-releasing-gold-loan-norms-125060600515_1.html
- https://www.businesstoday.in/personal-finance/investment/story/gold-and-silver-prices-drop-sharply-marking-biggest-decline-since-2013-and-2021-499097-2025-10-21
- https://www.business-standard.com/amp/markets/news/muthoot-manappuram-fin-shares-fall-as-much-as-5pc-as-gold-prices-retreat-125102300450_1.html
- https://www.angelone.in/news/stocks/hindustan-zinc-share-price-soars-14-percent-in-3-days-as-silver-prices-hit-record-highs
- https://www.businesstoday.in/personal-finance/investment/story/silver-rally-drives-hindustan-zincs-record-q2-contributes-40-to-quarter-profits-498809-2025-10-17
- https://www.business-standard.com/amp/markets/news/hindustan-zinc-mcx-shares-gain-up-to-9-as-silver-prices-hit-record-high-125060600357_1.html
- https://www.business-standard.com/markets/news/hind-zinc-sees-worst-fall-in-6-months-as-silver-dips-below-rs-2-5-lakh-kg-126010800379_1.html
- https://www.businesstoday.in/markets/stocks/story/hindustan-zinc-share-price-surges-5-hits-52-week-high-on-silver-rally-512573-2026-01-23
- https://www.businesstoday.in/markets/stocks/story/hindustan-zinc-shares-fall-6-as-silver-price-drops-sharply-514705-2026-02-05
- https://www.sahi.com/blogs/hindustan-zinc-share-price-rallies-12-how-the-silver-boom-is-powering-profits
- https://www.angelone.in/news/stocks/muthoot-manappuram-finance-iifl-share-price-tumble-up-to-8-percent-amid-gold-silver-crash
- https://businesstoday.in/markets/stocks/story/gold-price-crash-muthoot-finance-manappuram-gold-financers-tumbled-up-to-7-today-521813-2026-03-23
- https://www.businesstoday.in/markets/stocks/story/kalyan-jewellers-selco-gold-among-jewellery-stocks-falling-up-to-6-today-heres-why-531181-2026-05-13
- https://www.outlookbusiness.com/markets/jewellery-stocks-crash-up-to-12-after-pm-modi-urges-citizens-to-avoid-gold-buying
- https://www.outlookbusiness.com/amp/story/markets/jewellery-stocks-in-free-fall-why-60000-cr-vanished-in-three-days
- https://hdfcsky.com/news/gold-rate-today-16-november-2026-check-gold-price-of-24k-22k-18k-in-mumbai-kolkata-delhi-other-indian-cities-as-24k-rate-falls-rs1690-per-10-gm
- https://www.business-standard.com/amp/article/news-cm/muthoot-manappuram-slump-after-gold-loses-shine-120081200482_1.html
- https://www.business-standard.com/amp/article/companies/gold-finance-mining-companies-shine-as-gold-prices-scale-new-highs-120072401410_1.html
- Repo: CHAIN_OF_EVENTS.md (row 10), SECTOR_LINKS.md (gold line)

### B3. STEEL, IRON ORE, COKING COAL, THERMAL COAL

Covers steel and its raw materials, plus coal for cement and power. The autos cost case is in CHAIN_OF_EVENTS.md.
Where to read the drivers: DCE iron ore, SHFE HRC and rebar, DCE coking coal and coke (China's night session runs about
18:30-20:30 IST, so the 20:45 note can use it); NMDC monthly price filings; Coal India e-auction premium; Newcastle and
Indonesian thermal coal; Australian coking coal (SGX or reports); DGTR and finance ministry notifications.

**1. Item by item**
A) China steel / SHFE HRC / Indian HRC
- FALLS -> PE: SAIL, JINDALSTEL, TATASTEEL, JSWSTEEL, JSL (revenue; HIGH; same day). APLAPOLLO also PE short term: its inventory
  loses value (MEDIUM; days). CE: autos (ASHOKLEY, MARUTI, TVSMOTOR), capital goods / EPC (LT, BHEL, fixed-price contracts),
  durables (VOLTAS, BLUESTARCO) - cost, LOW-MEDIUM, weeks to quarters, rarely same day.
- RISES -> CE: the same steel makers (HIGH; same day); APLAPOLLO on a steady rise (inventory gain, dealer restocking; MEDIUM;
  days). PE: autos and EPC only on a large, sustained rise (LOW; quarters). An index-level auto PE on steel almost never works
  intraday.
B) Iron ore (DCE / SGX; NMDC list prices)
- FALLS -> PE: NMDC (revenue; HIGH; same day; an NMDC price cut moves it 3-6%). Steel makers fall in sympathy on the day (ore is a
  proxy for China demand). CE (weeks to quarters only): JSWSTEEL (buys most of its ore) more than TATASTEEL and SAIL (captive ore).
- RISES -> CE: NMDC (HIGH), then TATASTEEL and JINDALSTEL (own ore, margins widen); JSWSTEEL a smaller lift.
C) Coking coal (Australian premium HCC; DCE coking coal and coke)
- FALLS -> CE: JSWSTEEL and SAIL (import about 85-90% of coking coal; cost; MEDIUM; next day to weeks). TATASTEEL less (20-25%
  captive in India), though its Europe arm benefits.
- RISES -> PE: JSWSTEEL, SAIL, JINDALSTEL (cost; MEDIUM; profit hit lands next quarter because of 1-2 months' inventory). No large
  F&O CE: COALINDIA is mostly thermal coal and BCCL is not in F&O.
D) Thermal coal (Newcastle / Indonesian) and pet coke
- FALLS -> CE: cement (power and fuel about 25-35% of cost): SHREECEM, DALBHARAT, AMBUJACEM, ACC, ULTRACEMCO (cost; MEDIUM; days to
  weeks). Imported-coal power TATAPOWER, ADANIPOWER: small benefit (mostly passed through under PPAs; LOW). PE: COALINDIA (e-auction
  premium shrinks; e-auction is about 10% of volume but a large share of profit; MEDIUM; days).
- RISES / power shortage -> CE: COALINDIA (HIGH when e-auction premiums jump), NTPC (volume), merchant power JSWENERGY, ADANIPOWER
  (via IEX prices; MEDIUM), IEX. PE: cement (MEDIUM; weeks); TATAPOWER mixed (Mundra imported-coal plant, partly offset by its
  Indonesian mines). See also B9 section 3.
E) Policy: safeguard / anti-dumping duty, MIP, export duty
- Import duty or floor price -> CE: SAIL, JSWSTEEL, TATASTEEL, JSL (policy; HIGH; same day). PE: APLAPOLLO, steel users, MSME
  exporters (LOW).
- Export duty on steel or ore -> PE: JINDALSTEL, TATASTEEL, JSWSTEEL, SAIL, NMDC (HIGH; the biggest moves in this group). Rollback -> CE.

**2. Leaders**
- Steel down: SAIL (highest beta, highest cost, PSU float) and JINDALSTEL (exports, merchant ore). TATASTEEL is the most liquid
  option and moves most on China / Europe headlines. JSWSTEEL usually moves least; it leads only on coking coal.
- Ore: NMDC alone (pure play). Thermal coal: COALINDIA. Cement on fuel: SHREECEM and DALBHARAT first (pet-coke heavy, high beta);
  ULTRACEMCO steadier.
- Policy shock: JINDALSTEL and SAIL move most (May 2022 export duty: JINDALSTEL -17% vs TATASTEEL, JSWSTEEL about -12/-13%).

**3. Own traps** (common: C1, C4, C8, C9, C11)
- On China demand days everything ferrous moves together. A JSWSTEEL CE "because ore is cheaper" loses the same day; the cost
  benefit shows only over quarters.
- APLAPOLLO goes the opposite way to the textbook on steel falls (inventory loss). Never CE on falling HRC.
- Users (autos, LT, cement) need 2+ weeks of falling prices plus results commentary. Same day, trade only the steel PE side.
- A rising Dalian while NIFTY falls 1%+ is not a CE (Sep 2021 also had profit-taking).
- A DGTR recommendation moves the stock; the final notification weeks later often does not (safeguard: recommended 19 Mar 2025,
  notified 21 Apr 2025; Nifty Metal already +10% that March).
- Golden Week and other China holidays show "0%": treat as closed, not flat.
- Results: guidance on cost per tonne overrides the commodity. Coal India pricing is mostly notified, so world coal moves matter
  only through the e-auction.
- Domestic HRC follows China with a 1-3 week lag; mills announce list-price changes around the 1st and the 15th, which move SAIL
  and JSWSTEEL 1-2%.

**4. Past cases**
- 8 Feb 2016, minimum import price on 173 steel items: steel up to +6% (TATASTEEL +2.3%, JSWSTEEL +2.1%, SAIL +1.35% intraday).
  [V, Business Standard]
- 20 Nov 2017, pet coke ban (NCR): cement stocks cracked the same day [V event, Business Standard]; size about 2-4% [E].
- 20 Sep 2021, Evergrande plus iron ore -20% in a week to below $100: BSE Metal -6.8%, TATASTEEL -9.5%, NMDC -7.7%, JSWSTEEL -7%;
  non-ferrous fell much less. [V, PTI / Business Standard]
- Q3 FY22, coking coal about +30%: JSWSTEEL standalone EBITDA per tonne -25% QoQ, net profit -39% [V, Crisil]; the stock lagged
  peers in Jan-Feb 2022 [E]. Australian HCC went from $351 (1 Jan 2022) to $594 (31 Mar 2022). [V]
- Late Feb - 3 Mar 2022, global coal shortage: COALINDIA +32% in 4 sessions, e-auction at a 100% premium [V, Business Standard];
  cement (ACC, AMBUJACEM, ULTRACEMCO) slipped up to 3% on input costs, down heavily in a month [V, Business Standard].
- 23 May 2022, export duty (50% ore, 15% steel; notified on a Saturday): Nifty Metal -7.3%, JINDALSTEL -17%, TATASTEEL -12 to -14%,
  JSWSTEEL -13%, NMDC -12.5%, SAIL -10%. [V, Business Standard, 5paisa]. Rollback 18-21 Nov 2022: steel and NMDC +2-5% [E].
- 12 Jul 2022, NMDC cut ore by Rs 500/t: NMDC -5 to -6% [V, Business Standard]. Jul 2024 cut: NMDC -3% [V, Upstox].
- 24 Sep 2024, China stimulus: TATASTEEL +4.3%, NATIONALUM +6.2%, HINDALCO +4%, JSWSTEEL only +0.6%; Nifty Metal about +3% that day
  and +8% by 30 Sep, a record. [V, PTI, Reuters]. 8 Oct 2024: follow-up disappointed, Nifty Metal -3%+ (see B7).
- 19 Mar 2025, 12% safeguard duty recommended: SAIL +3.5%, TATASTEEL and JSWSTEEL about +3%, sector up to 5%. [V, Business Today,
  Angel One]
- 2 Jan 2026, Coal India opened e-auctions to foreign buyers: COALINDIA +7% to Rs 429.5, a 52-week high. [V, Business Today]
- Mar 2026, West Asia fuel spike: COALINDIA at a 52-week high of about Rs 476 while cement margins were hit (pet coke, coal).
  [V in part, secondary sources]

**Sources**
- https://www.business-standard.com/amp/article/markets/nifty-metal-index-plunges-7-tata-steel-tanks-14-hits-52-week-low-122052300194_1.html
- https://www.business-standard.com/amp/article/markets/metal-stocks-slide-jindal-steel-cracks-over-17-amid-export-duties-122052301336_1.html
- https://5paisa.com/news/why-steel-stocks-have-corrected-sharply-on-23-may
- https://www.businesstoday.in/markets/stocks/story/sail-tata-steel-jsw-steel-shares-rise-import-safeguard-duty-468454-2025-03-19
- https://www.angelone.in/news/share-market/metal-stocks-like-sail-jsw-steel-tata-steel-rally-as-govt-imposes-12-safeguard-duty
- https://www.newsdrum.in/business/metal-stocks-in-heavy-demand-national-aluminium-surges-6-pc-tata-steel-jumps-over-4-pc-7091139
- https://itiger.com/news/2471872214
- https://www.business-standard.com/article/markets/tata-steel-stock-tanks-9-5-as-equity-markets-reel-amid-global-selloff-121092000924_1.html
- https://www.asiafinancial.com/indian-steel-stocks-down-up-to-10pc-amid-china-property-crisis
- https://www.business-standard.com/amp/article/companies/nmdc-cuts-prices-of-lump-ore-fines-by-rs-500-tonne-each-stock-falls-5-122071200730_1.html
- https://upstox.com/news/market-news/stocks/nmdc-shares-decline-over-3-after-company-reduces-iron-ore-prices/article-98914
- https://www.crisil.com/content/crisil/en/home/newsroom/press-releases/2021/11/coking-coal-price-spurt-to-pare-profitability-of-steel-makers-in-the-second-half.html
- https://business-standard.com/amp/article/markets/coal-india-surges-32-in-4-days-on-improved-outlook-stock-nears-52-wk-high-122030300276_1.html
- https://www.businesstoday.in/amp/markets/stocks/story/coal-india-stock-rises-hits-52-week-high-heres-why-509149-2026-01-02
- https://www.business-standard.com/article/companies/cement-stocks-crack-on-petcoke-ban-117112000972_1.html
- https://business-standard.com/amp/article/markets/input-cost-worries-acc-ambuja-ultratech-slip-3-down-heavily-in-a-month-122030300385_1.html
- https://www.business-standard.com/amp/article/pti-stories/steel-stocks-gain-up-to-6-pc-after-govt-sets-floor-price-116020800731_1.html
- https://www.hdfcsec.com/hsl.docs//Cement - Q2FY27 Results Preview - HSIE-202610081702347603417.pdf

### B4. ALUMINIUM, ZINC, LEAD, NICKEL (beyond the copper case)

Not repeated from COPPER_LINKS.md: copper / aluminium -> autos, ACs and cables.
How the price reaches India: LME, MCX and SHFE night trade run until about 23:30-01:00 IST, so a big metal move shows up in Indian
shares at the NEXT open. Producers sell at LME x USDINR, so a weak rupee adds to a metal rise and a strong rupee takes away from
it. Check MCX aluminium, zinc and lead at 23:30 and SHFE at 06:30.

**1. Aluminium**
- RISES -> CE: NATIONALUM (HIGH, same day; pure aluminium, also sells alumina on the open market). VEDL (HIGH; India's largest
  aluminium maker, roughly half its EBITDA from aluminium [E]). HINDALCO (MEDIUM; India aluminium gains, Novelis is a converter
  and is cushioned). PE: users - 2-wheelers (HEROMOTOCO, BAJAJ-AUTO, TVSMOTOR, EICHERMOT: castings, wheels) and cables (POLYCAB,
  KEI: aluminium conductors). Cost, LOW, 1-2 quarters. Not a same-day PE.
- FALLS -> mirror image: PE NATIONALUM > VEDL > HINDALCO, same day. The user CE is in COPPER_LINKS.
- Separate driver, ALUMINA / BAUXITE (Guinea, Brazil): moves NATIONALUM much more than the other two. Alumina falling -> PE
  NATIONALUM even when LME aluminium is flat.
- Policy drivers (same day, HIGH): China export rebates or capacity caps, US tariffs (Section 232), Indian safeguard or import
  duty (domestic producers CE).
- Leader: NATIONALUM on both sides (purest play, high-beta PSU, cheap premiums). VEDL second. HINDALCO lags (Novelis, copper).
- Packaging: aluminium is a cost for VBL (some cans; mostly PET) and FMCG / pharma foil. LOW, quarters. Background only.

**2. Zinc (with silver, which really drives HINDZINC)**
- RISES -> CE HINDZINC (HIGH, same day, revenue). Zinc is about 60-65% of revenue [E], but silver is about 40-45% of EBIT [V].
  VEDL (MEDIUM; owns about 60%+ of HZL). PE: galvanizers (TATASTEEL, JSWSTEEL coated lines, APLAPOLLO) - LOW, quarters, no trade.
- FALLS -> PE HINDZINC, then VEDL. Galvanized steel gets a slight benefit over weeks.
- RULE: check SILVER before zinc. Silver up with zinc down means HINDZINC flat to up. Since 2025 nearly every 5%+ HINDZINC move has
  followed silver [V]. Silver cases are in B2.
- Leader: HINDZINC. VEDL follows at about half the move [E].

**3. Lead**
- FALLS -> CE EXIDEIND, ARE&M. Cost: lead is about 60-80% of a battery maker's raw material [V]. Citi: each 1% move in lead changes
  EPS by about 3% [V]. MEDIUM, weeks to 1 quarter (replacement prices reset with a lag, OEM contracts are lead-linked with a
  quarterly lag). Same-day reaction is small because LME lead moves slowly.
- RISES -> PE EXIDEIND, ARE&M only on a sustained 8-10%+ move in a month. HINDZINC gets a small revenue gain (lead about 10% of
  revenue [E]).
- Leader: ARE&M usually reacts more (higher beta, telecom / UPS cost exposure [V]); EXIDEIND has better pricing power [E]. Both
  trade more on EV, lithium and results stories than on lead.

**4. Nickel**
- No F&O nickel producer. Main user JSL (stainless; check F&O). Nickel passes through an alloy surcharge: inventory gain when it
  rises, loss when it falls. LOW-MEDIUM, quarters [E]. The Indian EV battery chain has little nickel exposure.
- A spike like 2022 gives a 1-2 day sentiment push to NIFTY METAL (VEDL, HINDALCO), not an earnings link. Treat nickel as a
  "metals mood" signal, not a trade.

**5. Own traps** (common: C1, C3, C6, C7, C8, C11, C13)
- Supply overhang beats the metal: HINDZINC govt OFS 6 Nov 2024 -8% intraday [V]; Vedanta OFS Aug 2024 -8% [V]; Vedanta block
  deal Jun 2025 -6% [V]; OFS talk again in 2026 -3 to -5% [V]. In any OFS or block week, ignore zinc.
- Silver overrides zinc for HINDZINC. Alumina overrides aluminium for NATIONALUM.
- Company events beat the metal: HZL / VEDL dividends and record dates, VEDL demerger news, Novelis plant problems for HINDALCO.
- Trade only an overnight LME move that MCX or SHFE confirmed. A 1% INR gain cancels about 1% of an LME rise for producers.
- Gap opens inflate premiums: wait for the first 15-minute pullback that holds VWAP (same rule as COPPER_LINKS).

**6. Past cases**
- Apr 2013: lead fell, battery makers gained. [V, Business Standard]
- Nov-Dec 2016: lead spike plus demonetisation: EXIDEIND and ARE&M about -8%. [V, Business Standard]
- 8 Mar 2022: LME nickel more than doubled and trading was halted; China stainless futures limit-up. [V event] Indian moves: metals
  sentiment up 1-2 days, no clean single-stock link [E].
- Aug 2024: Vedanta OFS in HINDZINC, stock -8%. [V, Business Today]
- 6 Nov 2024: govt HINDZINC OFS (floor Rs 505): stock -8.1% intraday with zinc unchanged - the supply trap. [V, Business Standard]
- 18 Nov 2024: China ended its 13% export rebate on aluminium and copper; LME aluminium +8% to $2,730. NATIONALUM +8.6% (touched
  +10%), HINDALCO +3.8 to +5.7%, VEDL +3 to +4%. NATIONALUM leads. [V, Business Standard, Business Today]
- 12 Dec 2024: alumina cooled from about $820 to about $700. NATIONALUM -7% intraday, HINDALCO and VEDL far milder - the alumina-only
  driver. Another NATIONALUM -4% in early Jan 2025 [V; exact date unclear in the source].
- 2 Jun 2025: US doubled the steel / aluminium tariff to 50%. VEDL -3.35%, HINDALCO -2.5%, NATIONALUM about -2%, NIFTY METAL -1.6% at
  the low. [V, Business Standard]
- 18 Jun 2025: Vedanta block deal (76.1 million HZL shares): HINDZINC -6%. [V, Business Standard]
- 24 Oct 2025: LME aluminium above $2,850 (Century Aluminum Iceland outage, US tariffs). NATIONALUM +5.0%, HINDALCO +4.3%, VEDL
  +3.5%. [V, HDFC Sky, ScanX]
- 2026: government stake-sale talk returns, HINDZINC -3 to -5%. [V, Kotak Neo]
- 18 Nov 2026: LME aluminium -3.8% to $2,824. NATIONALUM -3%+, HINDZINC and HINDALCO lower, NIFTY METAL about -2%. [V, COPPER_LINKS sources]

**Sources**
- https://business-standard.com/markets/news/nalco-hindalco-vedanta-surge-up-to-9-as-china-cancels-export-tax-rebates-124111800259_1.html
- https://www.businesstoday.in/markets/company-stock/story/nalco-hindalco-vedanta-rally-up-10-why-these-metal-stocks-are-shining-brighter-454100-2024-11-18
- https://business-standard.com/markets/news/hindustan-zinc-share-price-falls-8-as-govt-to-sell-2-5-stake-via-ofs-124110600322_1.html
- https://www.businesstoday.in/amp/markets/stocks/story/hindustan-zinc-shares-drop-8-as-2-day-ofs-by-vedanta-kicks-off-today-heres-why-441693-2024-08-16
- https://www.business-standard.com/markets/news/hindustan-zinc-share-price-falls-6-after-76-1-million-shares-change-hands-125061800187_1.html
- https://www.kotakneo.com/news/stocks/hindustan-zinc-share-price-stock-falls-3-percent-as-government-stake-sale-expectations-return/
- https://alcircle.com/news/nalco-shares-stoop-low-under-international-alumina-pricing-influence-112798
- https://www.alcircle.com/news/nalco-vs-vedantas-shares-in-nifty-hint-at-the-international-alumina-markets-role-in-their-respective-businesses-112968
- https://www.business-standard.com/amp/markets/news/aluminium-seen-as-an-outlier-among-metals-hindalco-better-placed-124121801241_1.html
- https://www.business-standard.com/amp/markets/news/what-s-behind-2-decline-in-nifty-metal-index-today-125060200259_1.html
- https://hdfcsky.com/news/vedanta-hindalco-nalco-shares-surge-up-to-5-percent
- https://scanx.trade/stock-market-news/stocks/vedanta-hindalco-nalco-shares-surge-on-rising-aluminium-prices/22830229
- https://www.business-standard.com/article/markets/temporary-blip-for-exide-amara-raja-116120800883_1.html
- https://www.business-standard.com/article/markets/auto-battery-makers-gain-as-lead-prices-fall-113041800147_1.html
- https://www.business-standard.com/amp/article/markets/higher-lead-prices-to-weigh-on-amara-raja-exide-117111601834_1.html
- https://www.business-standard.com/amp/article/opinion/amara-raja-could-face-growth-margin-pressures-117031001142_1.html
- https://www.bloomberg.com/news/articles/2022-03-08/lme-suspends-nickel-trading-after-unprecedented-price-spike
- https://icicidirect.com/research/equity/blog/nickel-rallies-more-than-100-in-two-days
- https://www.goodreturns.in/news/metal-stocks-fall-nalco-slips-over-3-hindustan-zinc-hindalco-drop-as-copper-price-hits-near-five-1547841.html
- All names here appear in GIR's symbol lists (/home/user/my-first-site/gir/); JSL is the least certain F&O member.

### B5. RUPEE (USDINR) AND THE DOLLAR INDEX (DXY)

**A) Rupee WEAKENS (USDINR rises)**
CE side:
- IT exporters: TCS, INFY, HCLTECH, WIPRO, TECHM, LTIM, PERSISTENT, COFORGE, MPHASIS. Revenue: dollar billing becomes more rupees;
  rule of thumb, 1% weaker rupee adds about 25-30 bp to EBIT margin. HIGH on the day, only if Nasdaq and US tech are not falling.
  Same day.
- Pharma exporters: SUNPHARMA, DRREDDY, AUROPHARMA, LUPIN, ZYDUSLIFE, GLENMARK, DIVISLAB, BIOCON. Revenue (US generics), plus a
  defensive bid on risk-off days. MEDIUM. Same day to next day.
- Auto exporters and global parts: BAJAJ-AUTO (about 35-40% exports), BALKRISIND (about 80% exports), BHARATFORG, SONACOMS,
  MOTHERSON; TMPV (JLR, pound translation). MEDIUM. Same day; earnings next quarter.
- Speciality chemicals (SRF, PIIND, NAVINFLUOR, DEEPAKNTR), upstream ONGC, OIL (crude sold in dollars), gold lenders MUTHOOTFIN,
  MANAPPURAM (gold in rupees rises). LOW-MEDIUM.
- Textiles: no real F&O names. LOW (Bangladesh and Vietnam now take the share).
PE side:
- OMCs HINDPETRO, BPCL, IOC: cost (crude in dollars, regulated retail prices) plus unhedged dollar debt. Nomura: about Rs 0.50/litre
  marketing margin lost per 1% rupee fall; HINDPETRO most exposed. HIGH when crude is also rising. Same day.
- INDIGO: fuel and leases in dollars (roughly half of costs) plus translation loss on lease liabilities. HIGH. Same day.
- Importers of components and inputs: DIXON, AMBER, KAYNES, VOLTAS, BLUESTARCO, HAVELLS (compressors, chips); paints ASIANPAINT,
  BERGEPAINT, PIDILITIND; city gas IGL, MGL, GUJGASLTD (imported LNG). MEDIUM. Next day to weeks.
- Capital goods with imported content (BHEL, SIEMENS, ABB, CGPOWER): LOW-MEDIUM, mostly passed on; the bigger hit is via FII flows.
- Dollar-debt names VEDL, TATASTEEL, JSWSTEEL, the Adani group, TATAPOWER, UPL: translation loss. LOW-MEDIUM. Shows in results.
- FII-heavy banks and NBFCs HDFCBANK, ICICIBANK, KOTAKBANK, AXISBANK, BAJFINANCE: a falling rupee comes with FII selling, and RBI
  defence drains liquidity. MEDIUM-HIGH on sharp days. Same day to days.

**B) Rupee STRENGTHENS:** everything in A flips. PE: IT, pharma, BALKRISIND, BAJAJ-AUTO. CE: OMCs, INDIGO, paints, city gas,
DIXON / AMBER, banks (FII money coming in).

**C) DXY UP (broad dollar strength):** emerging-market outflows. PE: banks and Nifty heavyweights; metals (HINDALCO, VEDL,
NATIONALUM, TATASTEEL) as dollar-priced commodities fall. CE: IT only through the rupee, so weak. DXY DOWN is the reverse: metals and
banks CE, IT mildly PE. Next open, lasting days. US 10y up together with DXY up is the strongest FII-selling signal (see B7).

**Leaders**
- Rupee weak, CE: INFY and WIPRO among large IT (ADRs set the gap, high beta to the dollar); mid IT (PERSISTENT, COFORGE, MPHASIS)
  moves bigger but trends less cleanly. Pharma: AUROPHARMA, LUPIN (most US exposure).
- Rupee weak, PE: HINDPETRO (thinnest marketing buffer) and INDIGO. Rupee strong: the same two lead the CE side; INFY leads the PE side.
- DXY down, CE: VEDL, HINDALCO, NATIONALUM. DXY up, PE: the same metals plus BAJFINANCE.

**Own traps** (common: C1, C3, C8, C10, C14, C17)
- US tech or recession fear beats the rupee: July 2022, IT fell as the rupee hit record lows (estimate cuts). Check Nasdaq and
  Accenture / Cognizant news first.
- A rupee crash with FII panic drags everything down: IT only falls less (relative CE). Prefer PE on banks to CE on IT.
- On market-wide rally days IT lags (20 Sep 2019).
- RBI defends levels (68.7 in 2013, about 88 in Feb 2025, about 95 in 2026) and the move reverses intraday. Do not chase a
  record-low print after 11:00.
- Skip rupee trades in IT during the TCS-to-INFY results week.
- OMCs move on crude and government pricing more than on the rupee alone; only a rupee move of more than 0.5% in a day matters.
- A slow managed slide (0.1-0.2% a day) gives no tradable move.

**Past cases**
- 28 Aug 2013 (outside the 2015-2026 window, kept as the textbook case): rupee breached 68 for the first time (68.75 intraday).
  BSE IT +2.7%, TCS +3.7% to a record, INFY +2.0%; PSU OMCs tumbled the same day on crude plus the rupee. [V, Business Standard]
- 20-23 Sep 2019: rupee firmed after the corporate tax cut. Sensex +1,921 on 20 Sep while IT lost up to about 2% (INFY and TCS led
  the fall); BSE IT -5.6% over three sessions; INFY -8% on 23 Sep, partly on other news. [V, Business Standard] (full case in B10)
- 8 Mar 2022: rupee weak in the Ukraine shock; Nifty IT +2%, TCS and INFY led. [V, Business Standard]
- July 2022: IT fell despite record rupee lows (trap). [V, Business Today]
- 29 Sep 2022: rupee at a record 81.9 as US yields spiked; pharma and IT bought as defensives. [V, Equitymaster]
- 3 Feb 2025: rupee weak and LPG subsidy cut in the budget: HINDPETRO -7.6%, BPCL -5.2%. [V, Business Standard, Nomura]
- Feb 2025, then March 2025: rupee about 88, then RBI defence; March 2025 was the rupee's best month since 2018 (+2.4%) on FII
  inflows; banks led and IT lagged (tariffs also a cause). [E, partly verified]
- 3 Dec 2025: rupee at a lifetime low of 90.28; Nifty IT about +1% on a weak market, +6% vs Nifty +0.6% over the month before.
  [V, Angel One]
- 4 Mar 2026: rupee at a record 92.05; IT up, INFY about +2%. [V, 5paisa]. March 2026 FII outflow about Rs 1.1 lakh crore [E].
- 30 Apr 2026: rupee at a record 95.33 after Brent jumped about 7%; OMCs and INDIGO under pressure, IT relatively firm. Rupee level
  [V, secondary]; stock moves [E].

**Data GIR needs:** USDINR spot and futures (NSE CDS), DXY, US 10y, INFY / WIPRO ADRs, RBI intervention headlines, daily FII cash
and futures flows.

**Sources**
- https://www.business-standard.com/amp/article/news-cm/it-stocks-buck-weak-market-trend-as-rupee-hits-record-low-113082800205_1.html
- https://www.business-standard.com/article/markets/bse-it-index-touches-12-year-high-113082800158_1.html
- https://www.business-standard.com/article/news-cm/psu-omcs-tumble-on-rising-crude-oil-prices-113082800267_1.html
- https://www.business-standard.com/amp/article/markets/bucking-the-trend-nifty-it-jumps-2-owing-to-weaker-re-tcs-infosys-shine-122030800489_1.html
- https://www.equitymaster.com/indian-share-markets/09/29/2022/SGX-Nifty-Up-170-Points-Rupee-Hits-a-New-Life-Time-Low-What-Next-for-Cement-Companies-and-Top-Buzzing-Stocks-Today
- https://www.businesstoday.in/amp/markets/company-stock/story/why-it-shares-are-falling-despite-rupee-hitting-record-lows-341614-2022-07-15
- https://www.business-standard.com/amp/article/news-cm/it-stocks-slide-on-rupee-appreciation-119092000823_1.html
- https://www.business-standard.com/amp/article/news-cm/it-stocks-slide-on-firm-rupee-119092300709_1.html
- https://www.businesstoday.in/markets/company-stock/it-sector-stocks-fall-tcs-stock-infosys-share-price-bse-tech-mahindra-sensex-nifty/story/380722.html
- https://www.business-standard.com/markets/news/crude-slips-to-3-month-low-inr-weakness-seen-pressuring-omcs-cgds-nomura-mahanagar-gas-ril-bpcl-hpcl-iocl-125091800172_1.html
- https://www.business-standard.com/markets/news/omcs-slip-up-to-7-as-no-stimulus-in-budget-bpcl-ioc-hit-52-week-lows-125020300325_1.html
- https://www.angelone.in/news/market-updates/nifty-it-gains-as-rupee-breaches-90-tech-stocks-rally-up-to-2-percent
- https://www.5paisa.com/news/nifty-it-rises-1-as-rupee-hits-record-low-infosys-gains-2
- https://www.outlookbusiness.com/markets/the-96-question-how-a-weak-rupee-is-creating-winners-and-losers-on-d-street
- https://www.bajajbroking.in/share-market-news/why-the-rupee-is-falling-in-2026-and-what-lies-ahead
- https://www.valueresearchonline.com/stories/227446/rupee-movements-really-impact-stocks-winners-losers-risks/
- https://www.businesstoday.in/markets/stocks/story/dollar-impact-wipro-persistent-and-mphasis-may-hit-hard-in-near-term-warns-kotak-475517-2025-05-09
- Repo: COPPER_LINKS.md, CHAIN_OF_EVENTS.md (rows 11, 15), SECTOR_LINKS.md (L14)

### B6. INTEREST RATES, RBI, BOND YIELDS, LIQUIDITY

**Right now (19 Nov 2026):** RBI raised the repo rate 25 bp to 5.50% on 7 Oct 2026 and changed its stance to "calibrated
tightening". The next MPC decision is about 4 Dec 2026 (meeting 2-4 Dec); 29 of 53 economists polled expect a second hike. So the
RISING-rate side of this group is the live one.

**1. The links**
A) RBI CUTS, or the India 10y yield FALLS sharply (more than 8-10 bp in a day)
- CE, strong, same day - REALTY: DLF, GODREJPROP, OBEROIRLTY, PRESTIGE, LODHA, PHOENIXLTD. Demand (cheaper home loans) and
  financing (builder debt). Highest beta.
- CE, strong, same day - NBFC / HOUSING FINANCE: BAJFINANCE, CHOLAFIN, SHRIRAMFIN, LICHSGFIN, PNBHOUSING, LTF, M&MFIN, MUTHOOTFIN,
  PFC, RECLTD, IRFC. They fund in the bond market, so lower yields cut their cost at once.
- CE, medium, same day - AUTOS: M&M, MARUTI, BAJAJ-AUTO, TVSMOTOR, EICHERMOT, HEROMOTOCO, TMPV, ASHOKLEY. Cheaper vehicle loans;
  the demand effect takes quarters, the same-day move is sentiment.
- CE, medium, same day - PSU BANKS: SBIN, BANKBARODA, PNB, CANBK, UNIONBANK. Government-bond holdings gain (treasury MTM), shown in
  next quarter's results.
- MIXED, policy day to 3 days - PRIVATE BANKS: HDFCBANK, ICICIBANK, AXISBANK, KOTAKBANK, INDUSINDBK, AUBANK, BANDHANBNK. Loans
  linked to the repo rate reprice at once, deposits slowly, so margins shrink. KOTAKBANK, BANDHANBNK and AUBANK (most repo-linked
  loans) are hurt first. A CRR cut (6 Jun 2025) puts back about 4-7 bp of margin and turns banks clearly CE.
- CE, low, quarters - HIGH-DEBT COMPANIES: ADANIENT, ADANIPORTS, ADANIGREEN, VEDL, TATAPOWER, GMRAIRPORT, IDEA, JSWSTEEL, TATASTEEL.
  Only IDEA and the Adani names react on the day.
- CE, low - CAPITAL MARKETS: BSE, CDSL, ANGELONE, MCX, HDFCAMC, NAM-INDIA, CAMS, 360ONE (risk-on mood, debt-fund flows only).
- Mixed, low - INSURERS: HDFCLIFE, SBILIFE, ICICIPRULI, LICI, ICICIGI, MFSL. ICICIGI and LICI gain on bond values; guaranteed-return
  products get harder to price. Rarely tradeable.
- Underperform (not a short): cash-rich defensives TCS, INFY, HINDUNILVR, ITC, NESTLEIND lag as money rotates.
B) RBI HIKES, or the 10y JUMPS: everything in A flips.
- PE, strong, same day: REALTY first, then NBFC and housing finance (BAJFINANCE, CHOLAFIN, LICHSGFIN, PNBHOUSING, SHRIRAMFIN), then autos.
- PE, medium, same day: PSU BANKS (bond holdings lose value; Apr-Jun 2018, 10y about 8%, large treasury losses).
- CE, medium, weeks to quarters: deposit-rich banks (SBIN, HDFCBANK, ICICIBANK) - loans reprice up before deposits, so margins widen
  in the first 2-3 quarters of a hike cycle (2022: PSU Bank among the best performers). On the hike day itself banks still fall.
- CE, relative: IT, FMCG, pharma (little debt, defensive rotation).
C) LIQUIDITY (banking-system surplus or deficit; RBI OMO / VRR / FX swap / CRR)
- RBI adds liquidity: CE banks (PSU and AUBANK most), NBFCs, realty. Strong, next day.
- Deficit widens (tax-outflow weeks, RBI selling dollars to defend the rupee): PE NBFCs and banks. Medium, over days.
D) REGULATORY TIGHTENING (risk weights, lending curbs): PE unsecured lenders, SBICARD and BAJFINANCE leading. Strong, next day.
E) CREDIT EVENTS (a lender default, commercial-paper freeze): PE wholesale-funded NBFCs and housing finance - very strong, same day,
20-60% intraday crashes. CE (relative): big deposit-rich banks HDFCBANK, ICICIBANK, KOTAKBANK as money flees to safety.

**2. Leaders**
- Cut / yields down CE: GODREJPROP and DLF (2-7% on a surprise), then LICHSGFIN, BAJFINANCE, CHOLAFIN (2-4%), then PNB and
  BANKBARODA among banks.
- Hike / yields up PE: GODREJPROP, DLF, BAJFINANCE, CHOLAFIN, then PSU banks (most leverage and most option OI move most).
- Liquidity CE: AUBANK, PNB, AXISBANK (most dependent on bulk deposits; 28 Jan 2025 PNB and AUBANK +4%+).
- Regulator PE: SBICARD, then BAJFINANCE. Credit-event PE: the weakest housing-finance and wholesale-funded names.

**3. Own traps** (common: C1, C4, C8, C10, C12, C18)
- Only a SURPRISE in size (50 bp vs 25 expected), a CRR move or a stance change gives a clean trend day. An expected cut gets sold
  (7 Feb 2025).
- Read the stance and the inflation forecast, not just the number. A cut with a hawkish stance sends yields UP (Jun 2025: neutral
  stance, 10y higher within days). A hold with a dovish tone can rally banks (8 Apr 2026, mainly on a US-Iran truce).
- Emergency cut in a crisis (27 Mar 2020) = RBI sees trouble. Do not hold banks CE into the close.
- Banks are the biggest FII holding: a domestic cut cannot beat heavy FII selling. Check FII flows and USDINR first.
- Bank results showing margin compression outweigh the rate story for 2-3 weeks.
- Realty falls hardest on risk-off even after a cut. Keep realty CE size small.
- Hike-day reversal: 7 Oct 2026, banks fell at the open and recovered intraday. Policy text lands at 10:00, the governor speaks
  about 12:00 and the move can flip then. Wait for 10:15-10:30 confirmation.
- Policy-day options carry inflated volatility (IV crush after 10:00). Prefer the next day if the move holds into 15:00.

**4. Past cases**
- 21 Sep 2018, IL&FS default / credit freeze: DHFL -60% intraday, closed -42%; Indiabulls Housing (now SAMMAANCAP) -35% intraday,
  closed -8%; BAJFINANCE and Edelweiss -10 to -30% intraday. Sensex swung about 1,500 points (fell 1,128 intraday, closed -280).
  NBFC selling continued on Monday; housing finance kept falling about 40% over a month. [V, Business Standard, Business Today]
- 27 Mar 2020, panic cut of 75 bp plus loan moratorium: bank index about +8% intraday, faded to about +0.8%. [V, Business Insider / Reuters]
- 4 May 2022, surprise off-cycle 40 bp hike plus 50 bp CRR hike: Sensex -2.3% (-1,307), Bank Nifty about -1.5%, rate-sensitive
  shares hit hardest. [V, Business Today, Business Standard]
- 16-17 Nov 2023, risk-weight hike on unsecured loans: SBICARD -5 to -7%, BAJFINANCE -2 to -3.5% (some reports up to -6% for
  BAJFINANCE, HDFCBANK, ICICIBANK), Bank Nifty about -1.3%, Fin Nifty -1%. [V, Business Today, Zee]
- 28 Jan 2025, day after the Rs 1.5 lakh cr liquidity package (OMO, VRR, $5bn swap): Bank Nifty +1.6%, Fin Services +1.9%, AXISBANK
  and HDFCBANK +3%, PNB and AUBANK +4%. [V, Business Standard]
- 7 Feb 2025, fully expected 25 bp cut (first in 5 years): banks -0.5 to -1.2% intraday, Sensex -0.3%; realty down early, +1 to
  +1.6% by the close. The priced-in trap. [V, Business Standard, ThePrint]
- 9 Apr 2025, RBI cut day: realty and PSU banks -2%, autos outperformed. [V, Business Standard]
- 6 Jun 2025, surprise 50 bp cut plus 100 bp CRR cut: Nifty Realty +3 to +5% (9% for the week), DLF +6%, GODREJPROP about +7%,
  OBEROIRLTY over +6%, BAJFINANCE +4.9%, Bank Nifty about +1.5% to a record. Banks dipped first and rallied after the CRR detail.
  [V, Angel One, Business Standard, Upstox, Business Today]
- 5 Dec 2025, 25 bp cut to 5.25%, partly expected: realty +1.2-1.5%; PSU Bank, Bank and Fin Services +1 to +1.5%. [V, Business Standard]
- 8 Apr 2026, hold at 5.25% plus US-Iran truce: Bank Nifty +5.2%, AUBANK +7.6%, UNIONBANK +7.3%, INDUSINDBK +6.9%, realty and autos
  up to 7%. The global move did most of it. [V, 5paisa, Outlook Money]
- 7 Oct 2026, 25 bp hike to 5.50%, stance "calibrated tightening": market down at the open, banks pared losses intraday. [V only from
  secondary sources: Upstox, HDFC Sky, Drishti; percentages E]

**Sources**
- https://www.business-standard.com/amp/article/markets/nbfcs-crash-here-s-why-dhfl-tanked-over-60-in-trade-today-118092100479_1.html
- https://www.business-standard.com/amp/article/markets/markets-rocked-by-crash-in-financial-stocks-sensex-swings-1-500-pts-118092100847_1.html
- https://www.business-standard.com/amp/article/pti-stories/housing-finance-firms-crash-dhfl-sinks-42-118092100736_1.html
- https://www.businesstoday.in/markets/company-stock/story/dewan-housing-finance-stock-crashes-indiabulls-housing-110280-2018-09-21
- https://businessinsider.in/finance/news/rbis-rate-cut-and-3-month-pause-on-emis-fails-to-excite-indian-stock-markets/amp_articleshow/74841755.cms
- https://businesstoday.in/markets/top-story/story/sensex-crashes-over-1400-points-as-rbi-hikes-repo-rate-by-40-bps-to-440-332272-2022-05-04
- https://www.business-standard.com/amp/article/markets/rbi-shocker-sends-market-into-a-tizzy-benchmark-indices-plunge-2-3-122050500037_1.html
- https://businesstoday.in/markets/company-stock/story/sbi-card-shares-plunge-7-as-rbi-move-on-risk-weights-to-hit-earnings-capital-adequacy-ratio-406043-2023-11-17
- https://www.businesstoday.in/markets/stock-picks/story/sbi-card-hdfc-bank-rbl-bank-kotak-bank-shares-how-rbis-raising-of-risk-weights-may-hit-stocks-406021-2023-11-17
- https://zeebiz.com/economy-infra/news-bank-nbfc-shares-fall-as-rbi-tightens-norms-on-personal-loans-265013
- https://www.business-standard.com/amp/markets/news/hdfc-bank-axis-bank-others-rise-as-rbi-announces-liquidity-measures-125012800465_1.html
- https://www.business-standard.com/markets/news/rate-sensitive-shares-trade-mixed-as-rbi-cuts-repo-rate-by-25-bps-to-6-25-125020700440_1.html
- https://theprint.in/economy/rbi-rate-cut-fails-to-cheer-markets-amid-volatility-sensex-nifty-close-in-red/2483979
- https://www.business-standard.com/markets/news/realty-psu-bank-index-down-2-auto-outperforms-after-rbi-cuts-repo-rate-125040900347_1.html
- https://www.angelone.in/news/share-market/realty-stocks-rally-dlf-godrej-surge-after-rbi-cuts-repo-rate-by-50-bps
- https://www.business-standard.com/markets/news/rate-sensitive-shares-rally-on-50-bps-repo-rate-cuts-crr-cuts-by-100-bps-125060600318_1.html
- https://upstox.com/news/market-news/trading/market-wrap-june-6-sensex-jumps-747-pts-nifty-50-tops-25-000-as-rbi-s-jumbo-rate-cut-and-100-bps-crr-cut-boost-sentiment/article-172140
- https://www.businesstoday.in/markets/stocks/story/nifty-bank-hits-record-high-after-rbi-rate-cuts-banking-financial-stocks-rally-479278-2025-06-06
- https://www.business-standard.com/amp/markets/news/auto-realty-bank-stocks-gain-after-rbi-mpc-cuts-repo-rate-by-25-bps-125120500275_1.html
- https://www.5paisa.com/news/bank-stocks-jump-up-to-8-after-rbi-maintains-repo-rate-at-525
- https://outlookmoney.com/invest/rbi-mpc-meeting-april-2026-realty-auto-bank-stocks-jump-up-to-7-percent-as-repo-rate-left-unchanged
- https://hdfcsky.com/news/rbi-hikes-repo-rate-by-25-bps-to-5-50percent-stance-shifts-to-calibrated-tightening
- https://upstox.com/news/market-news/economy/rbi-s-calibrated-tightening-explained-what-it-means-for-rates-loans-bonds-and-stocks/article-201441/
- https://www.drishtiias.com/daily-updates/daily-news-analysis/rbi-mpc-raises-repo-rate-to-5-50
- Repo: SECTOR_LINKS.md (rate rows), CHAIN_OF_EVENTS.md (row 14). PNBHOUSING's F&O status is not confirmed.

### B7. US AND GLOBAL (Nasdaq, US yields, Fed, China, risk-on / risk-off, FII flows)

Stock options, intraday, exit by 15:10.

**1. Nasdaq / US tech overnight** (revenue and sentiment; MEDIUM in 2026, used to be HIGH; next open)
- NASDAQ UP 1.5%+ -> CE: IT (INFY leader, TCS, HCLTECH, TECHM, WIPRO, LTIM; COFORGE, PERSISTENT, MPHASIS highest beta). EMS /
  electronics (DIXON, KAYNES, PGEL, AMBER) on AI-hardware days. INFY leads (ADR overnight, index weight, most liquid options);
  mid-tier IT gives the biggest % move.
- NASDAQ DOWN 1.5%+ -> PE: the same names; TECHM, WIPRO and the mid-tier fall most; DIXON, KAYNES fall hard on AI / hardware selling.
- **2026 TRAP - the link is broken.** Indian IT now trades on AI-disruption fear, not on the Nasdaq. 22 Sep 2026: Nasdaq at a record,
  Nifty IT -0.92% [V]. An AI-tool launch that LIFTS the Nasdaq can SINK Indian IT (Feb 2026, Nifty IT -5.9% [V]). Read the INFY and
  WIPRO ADRs and the CAUSE of the Nasdaq move, not its level.
- Read-across days (HIGH, next open): Accenture or Cognizant results. Mar 2026: Nifty IT +1.63%, TECHM +2.9%; Dec 2025 and Apr 2026:
  up 2-4% [V].

**2. US 10y yield and the dollar** (financing and FII flow; MEDIUM-HIGH; same day, builds over weeks)
- YIELD UP / DXY UP -> PE: private banks (HDFCBANK, ICICIBANK, AXISBANK), PSU banks (SBIN, PNB, BANKBARODA), NBFCs (BAJFINANCE,
  CHOLAFIN), realty (DLF, GODREJPROP, LODHA, PRESTIGE) - FII-owned and rate-sensitive. Metals PE (strong dollar weighs on LME).
  Relative strength: IT and pharma (weak rupee).
- YIELD DOWN / DXY DOWN -> CE: banks, realty (DLF leads), NBFCs, metals. No clean PE. IT lags.
- Leaders: SBIN and PNB on the PE side; DLF on the CE side.
- Trap: a yield fall caused by US recession fear is risk-off, not risk-on (5 Aug 2024).

**3. Fed decision** (lands about 23:30-00:00 IST; trade at the next open)
- DOVISH or a bigger cut than expected -> CE: banks, realty, metals, NBFCs, and IT on day 1 (19 Sep 2024: Nifty IT top sector +1.8%,
  MPHASIS up to +4% [V]).
- HAWKISH -> PE: banks, realty, the index; the rupee falls (19 Dec 2024: Sensex -1.2%, rupee record low 85.07 [V]). IT and pharma
  hold up but are not a clean CE.
- Trap: a fully priced decision reverses in the first hour. Trade only if GIFT NIFTY and the rupee confirm at 09:08.

**4. China data, stimulus and the yuan** (revenue and LME prices; HIGH; same day; China news usually 07:00-07:30 IST or overnight)
- STIMULUS / PBoC cut -> CE: VEDL, TATASTEEL, JSWSTEEL, JINDALSTEL, SAIL, HINDALCO, NMDC, NATIONALUM, HINDZINC. Leaders: VEDL and SAIL
  (highest beta), TATASTEEL (most liquid options). Second order, over WEEKS: FIIs rotate "sell India, buy China", PE on index
  heavyweights and banks (Oct 2024: record FII outflow about Rs 94,000 cr [V]).
- WEAK CHINA DATA, CHINESE STEEL EXPORTS UP, or YUAN DEVALUATION -> PE: metals (steel most - China dumps its surplus); TMPV (JLR China
  sales) MEDIUM. No relative CE; pharma and FMCG hold up.
- Traps: stimulus that disappoints (8 Oct 2024, Nifty Metal -3%+ [V]); rallies sold out by day 2-3; if LME and SHFE do not confirm
  at 07:15, no trade.

**5. Global risk-off / risk-on** (VIX spike, carry unwind, tariff shock; flow; HIGH; same day)
- RISK-OFF -> PE: metals (fall most: TATASTEEL, VEDL, SAIL), PSU banks, realty, high-beta PSEs. Relative CE: pharma, FMCG, sometimes
  IT - buy their CE only if the share is above VWAP, never as a blind hedge.
- RISK-ON / RELIEF -> CE: metals lead, then pharma (if the scare was tariffs), realty, PSU banks.
- Traps: on panic days EVERYTHING falls, defensives included. The relief bounce often comes on day 2-3: do not chase PE after a 3%+
  gap-down. Options are expensive when VIX spikes; buy after the first 15 minutes.

**6. US policy shocks aimed at one sector** (policy and cost; HIGH; next open)
- H-1B or visa curbs -> PE IT: TECHM leads (most US onsite staff), then LTIM, MPHASIS, INFY, TCS.
- US drug tariffs -> PE pharma: on branded / patented drugs SUNPHARMA leads (specialty US sales); on generics AUROPHARMA, LUPIN,
  ZYDUSLIFE, DRREDDY, GLENMARK. CIPLA and DIVISLAB hurt less.
- Higher US tariffs on China -> CE Indian EMS (DIXON, KAYNES), the "China+1" trade. Higher tariffs on India -> PE metals and exporters.

**7. FII flows** (published after 17:30 IST; set a tone for 1-5 days)
- Net SELL above Rs 5,000 cr -> next-day PE tilt: HDFCBANK, ICICIBANK, RELIANCE, the index, IT. DII buying often cushions by midday.
- Net BUY above Rs 5,000 cr -> CE on the same heavyweights, banks first.
- Trap: one day of flows is noise. Use the 5-day sum; a block deal can distort the total.

**Past cases** (all [V] unless marked)
- 24 Aug 2015, after the yuan devaluation: Sensex -5.94%, VEDL -15%, TATASTEEL -13%.
- Oct 2023, US 10y above 5%: Nifty -2.84% for the month, PSU Bank -6.16%.
- 5 Aug 2024, yen carry unwind plus weak US jobs: Nifty -2.68%, India VIX +61% to 23.
- 19 Sep 2024, Fed 50 bp cut: Nifty IT +1.8% (top sector), MPHASIS up to +4%.
- 24 Sep 2024, China stimulus: Nifty Metal about +3%, VEDL and TATASTEEL up to 5% (details in B3). Then Oct 2024: record FII
  selling, Nifty -6.2% for the month and -10% from the 27 Sep peak. 8 Oct 2024: Nifty Metal -3%+ on a disappointing follow-up.
- 19 Dec 2024, hawkish Fed: Sensex -1.2%, rupee record low 85.07.
- 27 Jan 2025, DeepSeek: Nifty IT -3.36%, HCLTECH, TECHM, WIPRO about -4%. 28 Jan: DIXON and KAYNES down as much as 20% intraday.
- 7 Apr 2025, US tariffs: Nifty -3.24%, Nifty Metal -6.75 to -8%, TATASTEEL -7% (-11.5% intraday), HINDALCO -7.2%.
- 11 Apr 2025, tariff pause: Nifty +1.92%, Metal +4.09%, Pharma +2.43%, HINDALCO +4.7%.
- 22 Sep 2025, H-1B $100k fee: Nifty IT -2.95% (Rs 85,500 cr wiped out), TECHM -6.5% intraday, TCS about -3%, INFY -2.6 to -3%;
  Nifty Pharma also -1.4%, 18 of 20 stocks red.
- 26 Sep 2025, 100% US tariff on branded drugs: Nifty Pharma -2.4%, SUNPHARMA about -5% intraday.
- Dec 2025, Mar 2026, Apr 2026: Accenture read-across, IT +2-4% (Mar 2026: Nifty IT +1.63%, TECHM +2.9%).
- Feb 2026, Anthropic AI tool launch: Nifty IT -5.9% in one day.
- 22 Sep 2026: Nasdaq at a record, Nifty IT -0.92%.
- Not found: any report for 18-19 Nov 2026 on Nifty IT, the Nasdaq or FII flows. Check today's moves on NSE.

**Sources**
- https://www.domain-b.com/investments/markets/general/20150824_markets.html
- https://www.business-standard.com/amp/article/news-cm/metal-mining-stocks-tumble-after-slide-in-global-industrial-metal-prices-115082400171_1.html
- https://newsroom.greenportfolio.co/blog/market-in-october-nifty-50-records-largest-monthly-drop-in-cy23-35-stocks-in-the-red/
- https://www.business-standard.com/amp/markets/stock-market-news/fear-gripped-equity-investors-lose-rs-15-trillion-sensex-nifty-fall-2-7-124080501212_1.html
- https://business-standard.com/markets/news/why-did-mphasis-nifty-it-gain-up-to-4-after-us-fed-cut-rates-by-50-bps-124091900198_1.html
- https://www.outlookbusiness.com/markets/chinas-economic-stimulus-fuels-optimism-for-indian-metal-firms-amid-investor-confidence
- https://www.businesstoday.in/markets/story/ndmc-tata-steel-jspl-jsw-steel-sail-these-metal-stocks-cracked-up-to-8-today-heres-why-449155-2024-10-08
- https://www.wionews.com/business-economy/fpis-pull-out-record-rs-94000-crore-from-equities-in-october-on-attractive-china-valuation-773125
- https://m.thewire.in/article/economy/fpi-outflow-indian-markets-october
- https://www.business-standard.com/amp/finance/news/rupee-breaches-85-usd-to-hit-new-low-after-hawkish-us-fed-outlook-124121900399_1.html
- https://www.angelone.in/news/market-updates/deepseek-saga-how-it-impacted-indian-ai-and-it-stocks
- https://informistmedia.com/EquityWire/25058/india-stocks-review-nifty-50-ends-below-23000-chinese-ai-model-spooks-it-cos
- https://www.angelone.in/news/market-updates/closing-bell-april-07-2025
- https://www.business-standard.com/amp/markets/news/sensex-posts-worst-fall-in-10-months-tanks-2-226-pts-on-trump-tariff-woes-125040700713_1.html
- https://www.business-standard.com/markets/news/sensex-rejoices-on-trump-tariff-halt-jumps-1-300-pts-metals-pharma-lead-125041100749_1.html
- https://upstox.com/news/market-news/stocks/nifty-50-rises-nearly-2-on-90-day-tariff-pause-how-it-metals-auto-and-other-sectors-are-performing/article-159870
- https://www.business-standard.com/amp/markets/news/it-stocks-biggest-drop-six-months-h1b-fee-125092201155_1.html
- https://www.brecorder.com/news/amp/40383970
- https://www.khaleejtimes.com/business/markets/indian-it-stocks-3-slide-on-us-visa-crackdown-risks
- https://www.business-standard.com/markets/news/trump-hits-pharma-with-100-tariff-on-drug-imports-analysts-decode-impact-125092600157_1.html
- https://upstox.com/news/market-news/stocks/sun-pharma-lupin-zydus-life-pharma-stocks-in-focus-as-trump-announces-100-tariff-on-pharma-products-check-details/article-181986
- https://www.moneylife.in/article/nifty-it-plunges-587-percentage-as-anthropics-ai-triggers-brutal-selloff/79573.html
- https://www.indmoney.com/blog/stocks/why-sensex-fell-september-22-2026-recap
- https://www.motilaloswal.com/news/stocks/119764
- https://www.angelone.in/news/stocks/it-stocks-rally-up-to-4-percent-as-accenture-boosts-growth-outlook-infosys-tcs-coforge-gain
- F&O status of KAYNES, PGEL and AMBER to be checked on the current NSE list.

### B8. AGRI AND RURAL (monsoon, crops, sugar, edible oil, rubber, cotton, fertiliser subsidy)

**1. Monsoon** (IMD April forecast, late-May update, June onset, weekly rain Jun-Sep; demand via farm income, plus policy via food
inflation and then RBI)
- GOOD / UPGRADE -> CE: ESCORTS, M&M (tractors), HEROMOTOCO, TVSMOTOR, DABUR, HINDUNILVR, MARICO, COLPAL, ITC, UPL, PIIND,
  CHAMBLFERT / COROMANDEL, M&MFIN, SHRIRAMFIN. Second order: food inflation falls, rate cuts get likelier -> banks, autos, realty.
  PE: power (IEX, TATAPOWER, NTPC: less heat, more hydro). HIGH on the forecast day for tractors, MEDIUM for FMCG. Same day on the
  forecast; real demand shows 1-2 quarters later.
- BAD / DOWNGRADE / EL NINO -> PE on the same list; CE IEX, NTPC, TATAPOWER (heat, power demand). Rate-sensitive shares weaken over
  weeks (cuts pushed back). Floods in Jul-Aug slow cement, paints and auto dispatches for weeks (LOW).
- Leaders: ESCORTS (pure tractor, highest rain beta), M&M (farm is a big share of standalone profit), HEROMOTOCO (most rural
  2-wheeler maker), DABUR (most rural FMCG). HINDUNILVR moves least.

**2. Crop prices / MSP** (kharif MSP in June, wheat and rice prices, export bans; farm income vs input cost)
- UP -> CE tractors and 2-wheelers (weeks to quarters, LOW-MEDIUM), ITC (agri exports). PE: BRITANNIA, NESTLEIND (wheat, milk, sugar
  cost; weeks); a CPI scare hits banks and rate-sensitive shares. Export bans (wheat May 2022, rice Jul 2023): the exporter falls, the
  domestic user gains a little; few F&O names exposed.
- DOWN (farm distress, as in 2017-19): the rural demand trade turns PE over months; food companies get small margin relief.

**3. Sugar** (sugar price, ethanol price, export quota or ban, diversion rules; only F&O name BALRAMCHIN)
- Sugar price up / export allowed / ethanol price up -> CE BALRAMCHIN (revenue, HIGH, same day). PE (LOW, weeks): BRITANNIA,
  NESTLEIND, VBL, TATACONSUM.
- Export ban / diversion cap / stock limits / imports eased -> PE BALRAMCHIN (policy, HIGH, same day; often 2 days in a row).

**4. Edible oil** (palm on BMD / DCE, soy, copra; India import duty; Indonesia rules; MPOB data around the 10th; about 20-40% of
material cost for soaps and biscuits)
- PALM / COPRA UP or an exporter ban -> PE: GODREJCP (soaps), HINDUNILVR, BRITANNIA, MARICO (copra), JUBLFOOD (low). MEDIUM, same day
  on a shock; margins 1-2 quarters later.
- PALM DOWN -> CE on the same list, slowly: a margin tailwind over weeks, rarely a one-day trade.
- India duty hike -> CE refiners (PATANJALI; AWL not F&O), slightly negative for FMCG. Duty cut -> reverse.
- Leaders: GODREJCP and BRITANNIA move most; HINDUNILVR is cushioned (uses PFAD).

**5. Natural rubber** (Kerala RSS4, Bangkok TSR20, SHFE / SGX; raw material about 60-65% of tyre sales, rubber about 40% of that)
- DOWN -> CE: APOLLOTYRE (leader: liquid, high beta), CEATLTD, MRF (premiums too large to trade), BALKRISIND (follows Europe farm
  demand and EUR more than rubber). UP -> PE the same list. MEDIUM. Shares react within days; margins follow a quarter later (2-3
  months' inventory). Crude moves tyres too (synthetic rubber, carbon black): check Brent first.

**6. Cotton** (ICE cotton, Shankar-6 per candy, 11% import duty, US tariffs; thin F&O exposure)
- UP -> PE spinners (KPR, Vardhman, Welspun: not F&O); PAGEIND a little (cost, weeks). DOWN / import duty waived -> spinners CE. A US
  tariff or demand shock beats cotton every time. Background tilt for PAGEIND and TRENT only.

**7. Fertiliser subsidy / NBS rates / global urea, DAP, ammonia, LNG** (policy and working capital)
- Subsidy cut / NBS rates cut / forced MRP cut / delayed payments -> PE COROMANDEL, CHAMBLFERT (HIGH, same day). Higher NBS rates,
  higher subsidy or a GST cut on inputs -> CE.
- Global DAP / ammonia up with no NBS revision -> PE COROMANDEL (weeks). LNG down -> CHAMBLFERT mild CE. More in B9 section 6.
- Agrochem (UPL, PIIND) follows Brazil, China prices and channel stock more than Indian rain.

**Own traps** (common: C1, C3, C8, C10, C12, C15)
- On risk-off days FMCG goes UP as a hiding place even on bad input news. Never take an FMCG PE on palm news when Nifty is down more
  than 1%.
- Skymet comes before IMD (2023: Skymet 94% on 10 Apr, IMD 96% on 11 Apr, so IMD day was a relief). Skymet's April calls average
  about 4.6% too low. Trade the surprise against Skymet, not the headline.
- Policy shocks often reverse (Indonesia ban lifted within weeks): take the day-1 move, do not hold.
- July-August weekly rain is noise; only a cumulative deficit beyond -10% counts.

**Past cases**
- 2 Jun 2015: IMD cut its forecast to 88%; monsoon-dependent shares slipped [V direction, Business Standard]; M&M and HEROMOTOCO
  about -2 to -3% [E].
- 13 Apr 2016: IMD forecast an above-normal monsoon; M&M +4.67% to Rs 1,298.70, autos jumped. [V, Business Standard]
- 5 Jul 2016: government cut non-urea fertiliser prices; COROMANDEL about -11 to -14% intraday, state-run makers fell less. [V, Business Standard]
- 25 Apr 2022: Indonesia palm export ban; HINDUNILVR, BRITANNIA, GODREJCP, MARICO -4 to -6.5% intraday, GODREJCP -6% to Rs 749.5
  [V, Zeebiz, Business Standard]. Ban lifted 23 May 2022 and most of the fall came back [E].
- Jan-Aug 2022: cotton at a record (about Rs 95,000-1.15 lakh per candy); KPR, Welspun, Vardhman down up to 45% for the year (not F&O). [V, Business Standard]
- 7-8 Dec 2023: ban on cane juice for ethanol; sugar shares -3 to -7% on day 1, BALRAMCHIN and peers down up to 15% in 2 days.
  [V, Business Today, Business Standard]
- 1 Feb 2026 budget: fertiliser subsidy Rs 1.70 lakh cr vs Rs 1.86 lakh cr revised estimate [V, Whalesbook]; share move mild, under 3% [E].
- 13 Apr 2026: IMD forecast 92% of LPA (El Nino); tractors and 2-wheelers flagged at risk [V, Business Today]; ESCORTS / M&M about
  -2 to -3% over 2 days [E, check bhavcopy].
- May 2026: sugar export ban to 30 Sep; sugar shares -2 to -6%, BALRAMCHIN about -2 to -3%. [V, Outlook Business]
- 19 Oct 2026: sugar diversion for ethanol cut to zero for 2026-27; BALRAMCHIN -2.3 to -4%, EID Parry -3%, Bajaj Hindusthan -7.4%.
  [V, Business Today]

**Sources**
- https://www.business-standard.com/amp/article/news-cm/m-m-surges-after-imd-forecasts-good-monsoon-116041300161_1.html
- https://www.business-standard.com/amp/article/markets/monsoon-dependent-stocks-slip-on-imd-forecast-115060300392_1.html
- https://www.businesstoday.in/markets/stocks/story/below-normal-monsoon-stocks-likely-to-be-impacted-as-el-nino-odds-rise-525774-2026-04-15
- https://www.kitco.com/news/off-the-wire/2023-04-10/update-1-india-likely-get-below-normal-monsoon-rains-2023-skymet
- https://www.business-standard.com/india-news/forecast-for-a-below-normal-monsoon-added-risk-to-economy-report-123041100307_1.html
- https://zeebiz.com/market-news/news-hul-britannia-godrej-consumer-products-tumble-up-to-65-after-indonesia-announces-to-ban-palm-oil-exports-183446
- https://business-standard.com/article/markets/hul-britannia-marico-dip-up-to-6-as-indonesia-bans-palm-oil-exports-122042500202_1.html
- https://zeebiz.com/companies/news-indonesia-palm-oil-export-ban-why-hul-godrej-consumer-unlikely-to-have-larger-impact-edelweiss-decodes-183860
- https://www.businesstoday.in/markets/company-stock/story/sugar-stocks-plunged-up-to-7-today-heres-why-408530-2023-12-07
- https://business-standard.com/markets/news/sugar-shares-extend-fall-balrampur-dhampur-praj-slip-up-to-15-in-2-days-123120800501_1.html
- https://www.outlookbusiness.com/markets/sugar-stocks-sink-up-to-6-after-govt-halts-exports-till-september
- https://www.businesstoday.in/markets/stocks/story/balrampur-chini-eid-parry-dalmia-bharat-shree-renuka-sugars-sugar-stocks-fall-today-562355-2026-10-19
- https://www.business-standard.com/article/markets/fertiliser-shares-dip-as-government-cuts-retail-prices-of-non-urea-fertilisers-116070500174_1.html
- https://www.whalesbook.com/news/English/economy/Indias-Budget-Tightens-Fertilizer-Subsidies-Eyes-Reform/697f66c147db7081af63bab4
- https://www.business-standard.com/amp/article/markets/high-cotton-prices-to-spoil-apparel-stocks-outlook-in-near-term-analysts-122082600424_1.html
- https://upstox.com/news/market-news/stocks/marico-patanjali-foods-awl-agri-business-godrej-agro-fmcg-shares-in-focus-on-this-government-order/article-173052
- https://www.globaldata.com/media/consumer/edible-oil-import-duty-increase-likely-wide-ranging-effects-food-sector-india-says-globaldata/
- https://www.autocarpro.in/news/indian-tyre-makers-face-fy27-margin-pressure-and-higher-capex-outlay-report-133783
- https://www.business-standard.com/article/markets/tyre-stocks-surge-ceat-mrf-up-over-6-116091900690_1.html (19 Sep 2016 tyre rally; source only, the move's cause is not recorded in the sheet)
- Repo: SECTOR_LINKS.md (FMCG, tyres, agro / rural rows), CHAIN_OF_EVENTS.md (chains 18, 19, 27)

### B9. GAS / LNG, POWER DEMAND AND IEX, RENEWABLES, COAL SUPPLY, POWER EQUIPMENT, FERTILISERS, CERAMICS

No ceramics share trades in F&O, so GUJGASLTD stands in for them.

**1. Natural gas / LNG** (Asian spot LNG, plus the government APM gas price and allocation)
- LNG FALLS -> CE: GUJGASLTD (HIGH; cost and volume - industrial buyers, mainly Morbi tile units, come back from propane), PETRONET
  (MEDIUM; terminals run fuller), IGL / MGL (MEDIUM; margin), GAIL (LOW-MEDIUM; transmission volume). PE: hardly any F&O share
  (ONGC / OIL APM price follows crude, not LNG). Same day for sentiment, 2-8 weeks for margins.
- LNG RISES / supply shock -> PE: PETRONET (HIGH, volume loss), GUJGASLTD (HIGH, Qatar and spot cargoes), MGL, IGL, GAIL. CE: ONGC /
  OIL only if crude rises too. Same day.
- POLICY beats price. APM allocation cut (cheap domestic gas) -> PE IGL > MGL > GUJGASLTD. Price cap or extra allocation -> CE IGL,
  MGL. CNG price hikes when petrol / crude rise -> CE IGL, MGL (margin protected; CNG still about 49% cheaper than petrol). Same day.
- Leaders: IGL on policy (most APM gas for CNG); PETRONET / GUJGASLTD on LNG supply shocks; GUJGASLTD on the Morbi propane switch.

**2. Power demand and IEX prices**
- DEMAND / PRICES RISE (heatwave, coal shortage) -> CE: TATAPOWER (HIGH; merchant sales plus Mundra), JSWENERGY (HIGH; merchant),
  NTPC (MEDIUM; plant load), COALINDIA (MEDIUM; offtake, e-auction premium), IEX (MEDIUM; volume), TORNTPOWER; VOLTAS / BLUESTARCO on
  heatwaves (COPPER_LINKS). PE: energy-heavy users without own plants, HINDALCO and cement (LOW). Same / next day; results the quarter.
- DEMAND FALLS (early or long monsoon, weak industry; FY26 demand only about +0.5-1%) -> PE: JSWENERGY (highest merchant share),
  TATAPOWER, NTPC, COALINDIA (HIGH: Q2 FY26 profit -30%). Trap: when exchange prices are low, IEX volume often RISES - no IEX puts on
  weak demand alone.
- IEX is driven by its regulator CERC more than demand. Bad for IEX: market coupling, price caps (cut from Rs 20 to Rs 12/unit in
  April 2022), fee cuts. Hits the same day and hard.

**3. Coal supply**
- SHORTAGE / imported coal UP -> CE COALINDIA (HIGH), NTPC, TATAPOWER, JSWENERGY, IEX. PE cement (fuel 25-30% of cost): ULTRACEMCO,
  AMBUJACEM, SHREECEM, DALBHARAT (MEDIUM, days to weeks); HINDALCO (LOW).
- GLUT / e-auction premiums FALL -> PE COALINDIA (same day on an e-auction price cut). CE cement, margins helped 1-2 quarters later.
  Merchant thermal power gains slightly.

**4. Renewables**
- Module prices FALL / GST cut / green tenders -> CE TATAPOWER, ADANIGREEN, JSWENERGY, NHPC / SJVN, IREDA (loan growth), SUZLON /
  INOXWIND (wind orders). PE module makers WAAREEENER / PREMIERENE (prices squeezed). Weeks.
- Protection for Indian makers (ALMM for cells, anti-dumping duty) -> CE WAAREEENER, PREMIERENE; PE developers (capex rises).
- Daytime solar glut pushes daylight exchange prices down -> PE merchant thermal, JSWENERGY; IEX volume holds up.
- The Adani names move on their own news more than on sector links.

**5. Power equipment** (BHEL, SIEMENS, ABB, CGPOWER, POWERGRID, POLYCAB, KEI)
- A peak-demand record or shortage leads to government capex (thermal plan 80+ GW by 2032, transmission): CE BHEL (HIGH, often the only
  bidder in thermal tenders), then SIEMENS / ABB / CGPOWER, POWERGRID. Weeks to quarters; one big order moves BHEL 4-6% the same day.
- Weak demand or tender delays -> PE BHEL first (it carries the most hope). Copper cost: see COPPER_LINKS.

**6. Fertilisers** (CHAMBLFERT, COROMANDEL; RCF, FACT, GNFC, DEEPAKFERT mostly not F&O)
- Urea gas cost passes through the subsidy, so a gas price move alone is LOW impact. Real channels: gas supply cut or priority
  allocation (HIGH, same day); subsidy budget or NBS rate rise (CE, same day); ammonia / phosphoric acid / LNG prices for complex
  fertilisers (COROMANDEL PE when they rise, results quarter); monsoon (CE, weeks).

**7. Ceramics** (Kajaria, Somany, Cera: no F&O)
- Gas UP hurts tile margins over 1-2 quarters, and Morbi units switch to propane, which cuts GUJGASLTD volume. Trade GUJGASLTD: put
  when propane is clearly cheaper than its gas, call when LNG becomes cheaper than propane.

**Own traps** (common: C1, C3, C5, C8, C14)
- On event days beta beats the link: 4 Jun 2024 (election result) power shares fell up to 19% whatever the demand picture.
- Heatwave stories run out after 1-2 days (record highs came on 3 May 2024, before the late-May demand peak).
- Pass-through: CNG / PNG prices are raised 2-6 weeks later; urea gas cost is subsidised; regulated plants (NTPC, POWERGRID) earn
  assured returns, so price spikes reach only merchant sellers.
- IEX: no calls on volume while a CERC order is pending.
- Results season: Morbi volumes, Coal India e-auction premiums and merchant realisations override price signals.
- FII selling in PSUs drags NTPC, COALINDIA, BHEL and GAIL down together.
- Gas policy can turn either way: 3 Apr 2023 IGL / MGL fell up to 6% when gas prices were left unchanged, then rallied on 10 Apr 2023.

**Past cases**
1. Sep-Oct 2021 coal crisis: 115 of 135 plants critically short, exchange power hit Rs 20/unit. Over 30 days COALINDIA +35%, NTPC +25%,
   TATAPOWER +37%. [V, Beroe, Acuite] Cement fell [E].
2. 30 Nov 2022: Kirit Parikh committee proposed a $4-6.5 price band; IGL / MGL up to +4%. [V, Business Standard]
3. Q1-Q2 FY23 gas spike: gross margins at listed tile makers fell 319-569 bp; Somany's gas cost rose to Rs 64/scm (+100%). [V, ICICI Direct, Baroda research]
4. 3 Apr 2023: gas price left unchanged, IGL / MGL down up to 6%. 10 Apr 2023: the cap adopted; MGL at a 52-week high, IGL +2%, ONGC
   gained. [V, Business Standard]
5. FY24: BHEL won thermal orders worth Rs 52,000 cr (9.6 GW). 1 Jan 2024: +6% on news of a Rs 19,422 cr NLC order. [V, Business Standard]
6. 21 Mar 2024: CGPOWER, Cummins, Thermax, Hitachi Energy rallied up to 9% to records. [V headline only; the driver is not recorded in the sheet]
7. 3 May 2024 heatwave (peak demand about 230-250 GW): NTPC and TATAPOWER at record highs on 3 May, POWERGRID on 22 May. [V, Business Standard]
8. 4 Jun 2024: election result, power shares down up to 19% (Adani Green, Adani Energy top losers). [V, Business Standard] (full case in B10)
9. 17-18 Oct 2024: APM allocation for CNG cut about 20%; IGL / MGL -12 to -15%, GUJGASLTD barely moved. [V, Business Today]
10. 18 Nov 2024: second APM cut; IGL -18.9% to Rs 329.25, MGL about -19 to -20% intraday, GUJGASLTD -6%. [V, Business Standard]
11. 4 Jul 2025: "short-term hurdles for power stocks as monsoon stumbles" (early monsoon, weak demand). [V headline only; no share sizes]
12. 24 Jul 2025: CERC approved market coupling; IEX -10% at the open, -23 to -30% intraday (low Rs 131.5), another -8% on 28 Jul.
    [V, Business Standard, Business Today]
13. FY26 weak demand: Coal India Q2 profit -30% (29 Oct 2025, stock -2%); JSWENERGY / TORNTPOWER touched lows earlier in 2025; Coal
    India -4.8% to Rs 432 on an e-auction price cut. [V, Reuters via MiningWeekly, Kotak via Business Today, Free Press Journal]
14. 4 Mar 2026: Ras Laffan (Qatar) strike, spot LNG near $25; PETRONET -10 to -12%, GAIL, GSPL, MGL, GUJGASLTD down up to 6%.
    16 Jun 2026: Qatar announced a restart; PETRONET and GAIL rose. [V, Business Today, Angel One]
15. 10 Mar 2026: government gas priority order for fertiliser plants; FACT +11.4%, RCF +6.6%, CHAMBLFERT +5.7%. Centre also planned to
    double the subsidy budget in the West Asia crisis. [V, Business Today, Bajaj Broking]
16. 27 Apr 2026: heatwave; AC makers and power stocks up to +6% (see B12). [V, Business Standard]
17. 26 May 2026: CNG raised Rs 2/kg (fourth hike) on crude; IGL about +6%, MGL +3%. [V, Business Today]

**Sources**
- https://www.business-standard.com/amp/markets/news/mgl-igl-plunge-up-to-20-on-further-reduction-in-domestic-gas-allocation-124111800191_1.html
- https://www.businesstoday.in/amp/markets/stocks/story/why-mgl-igl-shares-plunged-12-15-but-gujarat-gas-stock-stayed-unfazed-450581-2024-10-18
- https://www.business-standard.com/amp/article/markets/igl-mgl-gain-up-to-4-post-kirit-parikh-panel-gas-pricing-recommendations-122113000585_1.html
- https://www.business-standard.com/amp/markets/news/oil-gas-shares-in-focus-mgl-hits-52-week-high-ongc-igl-jump-up-to-3-123041000204_1.html
- https://www.business-standard.com/markets/news/city-gas-distribution-shares-trade-weak-mgl-igl-fall-up-to-6-123040300282_1.html
- https://www.businesstoday.in/markets/stocks/story/petronet-lng-shares-plunge-12-gail-gspl-mgl-gujarat-gas-drop-up-to-6-heres-why-519081-2026-03-04
- https://www.angelone.in/news/stocks/petronet-lng-and-gail-share-prices-gain-as-qatar-plans-to-ramp-up-lng-production
- https://www.businesstoday.in/markets/stocks/story/igl-shares-jump-after-cng-price-hike-in-delhi-ncr-mgl-also-gain-key-details-533284-2026-05-26
- https://www.business-standard.com/amp/markets/news/iex-share-price-tanks-15-per-cent-brokerages-decode-what-cerc-s-nod-to-market-coupling-mean-125072400265_1.html
- https://www.businesstoday.in/markets/stocks/story/iex-shares-136-lakh-retail-investors-lose-rs-1450-crore-as-stock-crashes-28-486107-2025-07-24
- https://indianinfrastructure.com/2022/04/12/cerc-caps-spot-power-price-at-rs-12-per-unit/
- https://www.beroeinc.com/article/power-crisis-in-india/
- https://www.acuite.in/Coal-Crisis_Oct-21
- https://www.business-standard.com/amp/markets/news/investors-harness-northern-india-s-sizzle-for-power-stock-pursuit-124052600394_1.html
- https://www.business-standard.com/markets/news/power-stocks-dip-up-to-19-on-june-4-adani-green-adani-energy-top-losers-124060400457_1.html
- https://www.miningweekly.com/article/coal-indias-q2-profit-misses-view-on-tepid-demand-lower-e-auction-premiums-2025-10-29
- https://www.freepressjournal.in/business/coal-india-share-price-slides-nearly-5-to-43235-as-price-cut-dampens-sentiment-amid-rising-costs
- https://www.businesstoday.in/markets/stocks/story/tata-power-ntpc-nhpc-jsw-energy-shares-why-kotak-retains-sell-on-these-utilities-504939-2025-12-04
- https://www.business-standard.com/amp/markets/news/short-term-hurdles-for-power-stocks-as-monsoon-stumbles-125070400084_1.html
- https://www.businesstoday.in/markets/stocks/story/fact-rashtriya-chemicals-chambal-fertilisers-gnfc-deepak-fertilisers-shares-jump-heres-why-519844-2026-03-10
- https://www.bajajbroking.in/share-market-news/fertiliser-stocks-rally-as-centre-plans-to-double-subsidy-budget-amid-west-asia-crisis
- https://www.business-standard.com/amp/article/companies/no-walkover-for-tile-makers-staring-at-higher-competition-gas-prices-122091100493_1.html
- https://www.icicidirect.com/mailimages/IDirect_SomanyCeramics_Q2FY23.pdf
- https://www.bqprime.com/amp/business/gujarat-gas-shares-fall-after-jefferies-downgrade-it-to-underperform
- https://nsearchives.nseindia.com/corporate/GUJGASLTD_28012026185906_1538SECTranscriptQ3FY26.pdf
- https://themachinemaker.com/news/bhel-prospects-improve-as-coal-fired-power-orders-surge/
- https://www.business-standard.com/markets/news/bhel-surges-6-on-buzz-of-winning-worth-rs-19-422-cr-order-from-nlc-india-124010100129_1.html
- https://www.business-standard.com/amp/markets/news/cg-power-cummins-thermax-hitachi-energy-rally-up-to-9-hit-record-highs-124032100563_1.html

### B10. GOVERNMENT AND REGULATORS (GST, duties, PLI, budget, defence, railways, SEBI, RBI, IRDAI, TRAI, NPCI, CERC, elections)

Not repeated here: copper links, the UNITDSPR Scotch duty case (19 Nov 2026) and MCX on 18 Nov (all in CHAIN_OF_EVENTS.md).

**How policy links differ from commodity links.** A policy link hits on the day it is announced, the size is known at once, and it
affects few shares - the strongest single-day link in this book, unless the market expected it. The share hit directly moves 5-20%;
linked sectors 1-4%, usually the same day, sometimes at the next open (weekend or after-hours notices). Most news comes after the
close (Finance Ministry notices, RBI circulars, GST Council late evening), so the move is in the 09:15 gap. Trade the follow-through
only if the 09:15-09:30 range breaks in the same direction as the news.

**1. GST rate change** (Council meeting; notice 1-3 weeks before it takes effect)
- CUT: CE autos (MARUTI, HEROMOTOCO, TVSMOTOR, EICHERMOT, M&M), vehicle financiers (BAJFINANCE, CHOLAFIN, SHRIRAMFIN, M&MFIN), cement
  (ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT), insurers when policies are exempt (HDFCLIFE, SBILIFE, ICICIPRULI, ICICIGI, LICI,
  POLICYBZR), FMCG and durables (HINDUNILVR, BRITANNIA, NESTLEIND, DABUR, VOLTAS, BLUESTARCO, HAVELLS). Demand. HIGH. Same day / next
  open; fades within 1-3 weeks once priced in.
- HIKE / new levy / 40% sin slab: PE on the share hit - ITC on tobacco, large bikes; DELTACORP and NAZARA (check F&O) on 28% GST for
  online gaming (Jul-Aug 2023) [E]. HIGH, same day. No CE side (except ITC's hotels / FMCG story over months).
- Leaders: M&M led the 2025 cut (tractors, SUVs and small cars all covered); MARUTI leads a small-car-only cut (largest share of the
  28% -> 18% basket) but lagged in 2025 because the move was expected; EICHERMOT, HEROMOTOCO, TVSMOTOR on 2-wheelers.
- GST collections (1st of the month): LOW, broad mood only, no sector trade.

**2. Import / export duties, anti-dumping, safeguard, windfall, excise** (Finance Ministry or DGTR notices, often Friday / Saturday)
- Export duty on a product: PE its producers (revenue, HIGH, next open). Steel May 2022: TATASTEEL, JSWSTEEL, JINDALSTEL, SAIL.
  Windfall tax Jul 2022: ONGC, OIL, RELIANCE. CE domestic users, weakly (LOW, weeks): autos and capital goods on cheaper steel.
- Export duty removed: CE the same names (Nov 2022 steel rollback +2-4% [E]).
- Import duty cut on a FINISHED good: CE domestic sellers; PE lenders secured on it. Gold Jul 2024: CE TITAN, KALYANKJIL; PE
  MUTHOOTFIN, MANAPPURAM. HIGH, same day. (Details B2.)
- Anti-dumping / safeguard duty on imports: CE domestic producers. Steel safeguard 2025: TATASTEEL, JSWSTEEL, SAIL +1-3% (B3 has +3%
  to +3.5%). Chemicals: SRF, DEEPAKNTR, AARTIIND. Solar glass and modules. PE users of the product, weakly.
- Excise on cigarettes: PE ITC (1 Jan 2026, -9.7%). The budget sin-tax line on 1 Feb works the same way.
- Leader: the most exposed and most indebted name moves most (JINDALSTEL -17% in May 2022; ONGC -13% vs RELIANCE -7% in Jul 2022).

**3. PLI / customs on components** (cabinet decisions, budget)
- New scheme or extension: CE electronics makers (DIXON, AMBER, KAYNES, PGEL), autos and EV parts (SONACOMS, UNOMINDA, TVSMOTOR, M&M),
  pharma APIs. Cost / subsidy. MEDIUM, same day; 3-8% moves common in DIXON and KAYNES.
- Payout cut, scheme ending, or a duty cut on finished phones and goods: PE DIXON and the EMS names. Customs cuts on components: CE.

**4. Union budget** (1 Feb; interim in election years)
- Capex above expectations: CE LT, BHEL, SIEMENS, ABB, cement, RVNL, IRFC, IRCTC, CONCOR, NBCC, HAL, BEL. Flat or below: PE the same.
- Income-tax relief: CE consumption (TRENT, DMART, TITAN, HINDUNILVR, MARUTI, IHCL). MEDIUM; often fades by the close.
- STT / capital-gains hike: PE capital markets (BSE, ANGELONE, CDSL, MCX, KFINTECH, CAMS) and the market. Jul 2024 STT hike: BSE and
  ANGELONE fell sharply [E]. Feb 2026: see cases.
- Fiscal deficit lower than expected: CE PSU banks (bond gains). LOW.
- Leader: whichever share the pre-budget run-up favoured most falls hardest on a miss ("buy the rumour, sell the budget").

**5. Defence orders / conflict / policy** (DAC approvals, MoD contracts, border events)
- Large order, DAC approval, import-ban list, conflict: CE HAL, BEL, BDL, MAZDOCK, BHEL, SOLARINDS, DATAPATTNS. Revenue (years of
  visibility). HIGH for the named share, MEDIUM for the group. Same day; after a conflict, a 2-3 week rally (May 2025).
- Ceasefire, peace talks, order slippage, a pre-election PSU sell-off: PE the same names; steep, as they trade at 50-70x earnings.
- Leader: BDL and MAZDOCK move most (small float, highest beta); HAL and BEL move less but have the deepest options (BEL is the best
  vehicle).

**6. Railway capex / fares / orders**
- Capex up, tender wins (Vande Bharat, Kavach): CE RVNL, IRFC, IRCTC, CONCOR, BEML, TITAGARH, JWL. MEDIUM, same day; retail-driven
  moves of 5-10%. Capex flat: PE the same (Feb 2025). A fare hike is CE for IRCTC only (LOW).
- Leader: RVNL (highest beta, retail-heavy). IRFC follows the PSU theme rather than orders.

**7. SEBI rules** (board meetings, circulars, consultation papers - read the sign for each share)
- Curbs on F&O (lot size, expiries, margins, STT): PE ANGELONE, BSE, 5PAISA, CDSL, NUVAMA. Oct-Nov 2024 curbs: ANGELONE and BSE -5 to
  -10% in days [E]. One rule can be CE for one exchange and PE for the other (expiry-day shifts between NSE and BSE).
- Relief (eased curbs, new products, MF fee cuts rolled back): CE the same, plus HDFCAMC, NAM-INDIA, CAMS, KFINTECH. An MF expense-ratio
  cut is PE for the AMCs.
- Action against one company: PE that share only; competitors a small CE. Minutes. Not a sector link.

**8. RBI** (policy days, circulars, actions against a bank or NBFC) - rates and liquidity are in B6
- Tightening rules (risk weights, LTV, unsecured lending, gold-loan rules): PE the targeted lenders (Nov 2023: SBICARD, BAJFINANCE;
  Apr 2025: gold lenders). CE: lenders that gain share, weakly (PSU banks, secured lenders).
- Action against one entity (business ban): PE that share (PAYTM, Feb 2024). CE rivals weakly, with a lag of weeks.
- Leader: the lender most exposed to the product. Read the circular, not the headline.

**9. IRDAI and insurance tax**
- Surrender-value, commission or product rules that hurt margins: PE life insurers (HDFCLIFE, SBILIFE, ICICIPRULI, LICI, MFSL). MEDIUM,
  same day. Relief or GST exemption: CE the same, plus POLICYBZR. A higher FDI cap: CE (LOW).
- Insurers otherwise move with banks at about half the size; own triggers are policy and monthly premium data (B11).

**10. TRAI / DoT / telecom** (tariff orders, AGR rulings, spectrum dues, relief packages)
- Relief, dues frozen, tariff hike: CE IDEA (most leveraged, 10-20% moves), BHARTIARTL, INDUSTOWER (tower rent depends on IDEA
  surviving). HIGH, same day.
- Adverse court ruling or dues demand: PE IDEA and INDUSTOWER. BHARTIARTL often dips then RECOVERS (consolidation view; mixed sign).

**11. NPCI** (UPI market-share cap, MDR rules)
- MDR allowed on UPI, or the cap deferred: CE PAYTM, and PB Fintech for its payments arm. Cap enforced, new-user ban: PE PAYTM.
  MEDIUM-HIGH, same day.

**12. CERC / power ministry**
- Market coupling (Jul 2025): PE IEX (B9). Power tariff increases, ISTS waivers, storage mandates: CE NTPC, POWERGRID, TATAPOWER,
  ADANIGREEN, JSWENERGY, NHPC (MEDIUM). Coal price or supply orders: COALINDIA.

**13. Elections** (exit polls, counting days, state results)
- Stable / BJP-majority signal: CE PSU banks, PSEs, defence, power, railways, capex (SBIN, BANKBARODA, PNB, CANBK, POWERGRID, NTPC, HAL,
  BEL, RECLTD, PFC).
- Hung / weaker result: PE the same names, hard. Defensives (FMCG, pharma, IT) hold up better.
- Welfare-heavy state results: CE FMCG and rural names (2-wheelers, tractors); PE PSU banks if fiscal worries rise (LOW).
- Leaders: RECLTD / PFC and BEL / BDL (most "Modi-trade" crowding); among large caps SBIN, POWERGRID, NTPC.

**Own traps** (common: C1, C4, C8, C10, C11, C12, C16)
- Already priced in: the GST cut was flagged on 15 Aug 2025 and decided 3 Sep; most of the auto move came at the 18 Aug open.
- Consultation papers move shares; the final rule is often softer and shares bounce (SEBI papers, IRDAI drafts; BSE +4% the day after
  the Feb 2026 STT hike).
- Results can land with the order (IEX reported Q1 the same day as the CERC order).
- Defence, railway and PSU rallies are retail-heavy and reverse quickly when the theme cools.
- Circuit-hit names (PAYTM, IDEA, IEX): premiums and IV blow out; trade the linked share instead.

**Past cases**
- 20 Sep 2019, corporate tax cut 30% -> 22%: Sensex +5.32% (+1,921, best day in 10 years); HEROMOTOCO +12.5%, MARUTI +10.9%, INDUSINDBK
  +10.7%, BAJFINANCE +10.2%, SBIN +10.1%. IT and pharma lagged or opened red (low tax rates already, plus a firm rupee - B5).
  [V, Business Standard, Equitymaster]
- 24 Oct 2019, AGR verdict: IDEA -23% (sources -13 to -23%); BHARTIARTL down as much as -10% intraday, closed +3%; Bharti Infratel (now
  INDUSTOWER) down as much as -10%, top Nifty loser. [V, Business Standard, BloombergQuint]
- 16 Sep 2021, telecom relief package: IDEA +15-20% (+72% in 10 days), INDUSTOWER +10%, BHARTIARTL +5% at the intraday high.
  [V, Business Standard, Investing.com]
- 23 May 2022, steel export duty (details in B3): Nifty Metal -7%, JINDALSTEL -17%, JSWSTEEL -13%, TATASTEEL -12%, SAIL -10%. [V]
- 1 Jul 2022, windfall tax: ONGC -13.4%, RELIANCE -7.1% (details in B1). [V]
- Jul-Aug 2023: 28% GST on online gaming; DELTACORP, NAZARA hit [E].
- 17 Nov 2023, RBI risk-weight hike: SBICARD -5 to -7%, BAJFINANCE -2 to -3.5% (details in B6). [V]
- 1-5 Feb 2024, RBI action on Paytm Payments Bank: PAYTM -20%, -20%, -10% (about -42% in 3 days, about Rs 20,500 cr lost). [V, Business Standard]
- 3 Jun 2024, exit polls: Nifty PSU Bank +8.4%, BANKBARODA +12%, POWERGRID +9%; PSUs up over 12%. [V, Business Today, Deccan Herald]
- 4 Jun 2024, counting: Nifty -5.93% (about -6%); PSU Bank -10.5% to -15% (sources differ); BEL about -19%, HAL -14%; NTPC, SBIN,
  POWERGRID, LT -6 to -15%; power shares down up to 19%. FMCG green, HINDUNILVR the top gainer. 5 Jun: Nifty +3.2% but PSU names kept
  falling. 6 Jun: PSU Bank +2.9%, Realty +4.7%. [V, Business Standard, Upstox, Outlook Money, Liquide, 5paisa]
- 27-28 Jun 2024, telecom tariff hikes (Jio 12-25%, Airtel 10-21%): BHARTIARTL +5% to a record, INDUSTOWER +4.3% to a 52-week high,
  IDEA at a 52-week high. [V, Business Standard, Zee]
- Jul 2024, STT hike: BSE, ANGELONE fell sharply [E]. Oct-Nov 2024 SEBI F&O curbs: ANGELONE, BSE -5 to -10% in days [E].
- 23 Jul 2024, gold duty cut (details in B2): TITAN +6.6% close, KALYANKJIL +6%, MUTHOOTFIN -4.3%, MANAPPURAM -5.8%. [V]
- 1 Feb 2025, budget capex flat: RVNL, IRFC, IRCON -5 to -8% that day, up to -15% over 2 sessions; HAL, BHEL, BEL also bled. [V, Upstox, Business Today]
- 19 Mar 2025, steel safeguard recommended (details in B3). [V]
- 7-13 May 2025, Operation Sindoor: Nifty India Defence +4.5% in a day; BDL, BEL, HAL +3 to +12% (13 May); from launch to about 19 May
  BEL +26.5%, BDL +34.5%, HAL +12.1%; defence shares added Rs 1.2 lakh crore in 12 sessions. [V, Outlook Money, Free Press Journal, ThePrint, Business Standard]
- 24 Jul 2025, CERC market coupling: IEX -10% at the open, -23 to -30% intraday, another -8% on 28 Jul (details in B9). [V]
- 15 Aug - 4 Sep 2025, GST 2.0: PM's speech 15 Aug, auto rally at the 18 Aug open; Council decision 3 Sep (from 22 Sep). On 4 Sep M&M
  +7.8% intraday, closed +5.96%; EICHERMOT +5.4% intraday, closed +1.1%; HEROMOTOCO +3.6% intraday, closed +0.1%; TVSMOTOR +4.2%
  intraday; MARUTI and BAJAJ-AUTO under +1%; ESCORTS-led auto stocks up to +14%. Insurers and cement also rallied. [V, Outlook Business,
  Business Standard, Business Today]
- 1 Jan 2026, cigarette excise: ITC -9.7% on the close (steepest since Mar 2020), about Rs 45,000 cr of market value lost. [V, Business Standard, Business Today]
- 1 Feb 2026, STT hike on F&O: BSE -8% on the close (-15% intraday), ANGELONE -8.6%; Nifty's worst budget day since 2020; BSE +4% the
  next day. [V, Angel One, Business Standard, Outlook Money]
- 19 Nov 2026: UNITDSPR bulk Scotch duty case - see CHAIN_OF_EVENTS.md.

**Sources**
- https://www.business-standard.com/markets/news/markets-fm-hikes-stt-on-fo-trades-surprise-move-126020100888_1.html
- https://www.angelone.in/news/stocks/bse-share-price-plunges-15-percent-after-budget-2026-stt-hike
- https://www.outlookmoney.com/invest/stock-market-today-nifty-50-sensex-see-worst-budget-day-fall-in-six-years-as-stt-hike-weighs-on-sentiment
- https://www.business-standard.com/amp/markets/news/itc-godfrey-phillips-vst-industries-tobacco-stocks-mixed-as-additional-excise-duty-effective-from-feb-1-126010100147_1.html
- https://www.businesstoday.in/markets/stocks/story/excise-duty-impact-itc-shares-slip-to-lowest-levels-since-feb-2023-rs-45k-cr-m-cap-gone-509011-2026-01-01
- https://upstox.com/news/election-results/latest-updates/defence-stocks-like-bel-hal-dip-11percent-amid-election-uncertainty/article-92582
- https://www.outlookmoney.com/invest/india-elections-2024-investors-lose-around-rs-30-lakh-crore-markets-down-nearly-6
- https://www.businesstoday.in/markets/company-stock/story/bob-sbi-canara-central-bank-other-psb-shares-rally-as-pm-modi-seen-retaining-power-431981-2024-06-03
- https://www.deccanherald.com/business/markets/public-sector-units-stocks-rally-over-12-after-exit-polls-predict-victory-for-pm-modis-ruling-party-3049510
- https://www.business-standard.com/markets/news/stock-market-live-updates-june-4-sensex-nifty-lok-sabha-election-results-2024-psu-stocks-nse-124060400081_1.html
- https://blog.liquide.life/post-market-summary-4th-june-2024/
- https://5paisa.com/news/psu-stock-slump-continues
- https://www.business-standard.com/markets/news/stock-market-live-updates-june-6-gift-nifty-sensex-nse-bse-nifty50-nasdaq-124060600068_1.html
- https://businesstoday.in/amp/markets/company-stock/story/reliance-industries-shares-fall-taxes-on-crude-oil-gains-339954-2022-07-01
- https://www.business-standard.com/amp/markets/news/paytm-plunges-42-in-3-days-erodes-nearly-rs-20-500-crore-in-market-value-124020500190_1.html
- https://upstox.com/news/market-news/stocks/rvnl-irfc-irctc-and-other-railway-stocks-tumble-up-to-7-as-budget-2025-falls-short-of-market-expectations/article-143887
- https://www.businesstoday.in/markets/stocks/story/rvnl-hal-bhel-ircon-bel-irfc-railways-defence-capex-stock-bleed-today-heres-why-463052-2025-02-01
- https://www.business-standard.com/markets/news/fmcg-auto-how-will-various-sectors-be-impacted-from-gst-rationalisation-125090400126_1.html
- https://www.outlookbusiness.com/amp/story/markets/mm-jumps-6-other-auto-stocks-end-marginally-higher-after-sharp-intra-day-rally-on-gst-reforms
- https://www.business-standard.com/amp/markets/news/auto-stocks-rally-on-gst-2-0-emkay-sees-m-m-maruti-as-top-beneficiaries-125090400225_1.html
- https://www.businesstoday.in/markets/stocks/story/gst-cut-impact-escorts-mm-eicher-lead-auto-stocks-rally-gain-up-to-14-top-picks-492459-2025-09-04
- https://www.outlookmoney.com/invest/defence-stocks-bdl-hal-bel-share-price-rally-up-to-12-per-cent-as-pm-modi-calls-for-made-in-india-equipment
- https://www.freepressjournal.in/business/defence-stocks-soar-in-market-rally-12-lakh-crore-added-in-12-days
- https://theprint.in/?p=2654430
- https://www.business-standard.com/markets/news/defence-stocks-extend-rally-bel-bdl-solar-mazagon-dock-record-new-highs-125051600332_1.html
- https://business-standard.com/amp/article/pti-stories/friday-blockbuster-sensex-rockets-1-921-pts-on-fm-s-tax-booster-investor-wealth-soars-rs-6-8-lk-cr-119092000899_1.html
- https://equitymaster.com/indian-share-markets/09/20/2019/Sensex-Ends-1921-Points-Higher-Banking-and-Auto-Stocks-Witness-Huge-Buying
- https://www.business-standard.com/amp/article/markets/markets-clock-best-day-in-10-yrs-after-sharp-slash-in-corporate-tax-rates-119092000901_1.html
- https://www.business-standard.com/amp/article/news-cm/shares-further-extend-gains-it-stocks-lag-119092000609_1.html
- https://www.business-standard.com/article/markets/airtel-voda-idea-tumble-up-to-20-as-sc-rejects-telcos-definition-of-agr-119102400729_1.html
- https://www.bloombergquint.com/markets/agr-dues-verdict-bharti-airtel-stock-rallies-vodafone-idea-tumbles
- https://www.business-standard.com/amp/article/markets/voda-idea-zooms-15-as-govt-grants-relief-stock-zooms-72-in-10-days-121091600210_1.html
- https://www.business-standard.com/amp/markets/news/tariff-hike-impact-airtel-soars-5-hits-new-high-ril-mcap-tops-rs-21-trn-124062800161_1.html
- https://zeebiz.com/markets/stocks/news-telecom-stocks-tariff-hike-bharti-airtel-all-time-high-vodafone-idea-indus-towers-52-week-high-tata-communications-bharti-hexacom-share-price-bse-nse-clsa-jp-morgan-target-298644
- Gold duty, steel duty, IEX, risk weights: sources in B2, B3, B9, B6.

### B11. SECTOR-TO-SECTOR ROTATION (links that no single commodity drives)

Adds to SECTOR_LINKS L09-L17 and does not repeat them.

**1. Links** (pair: trigger -> CE side / PE side | channel | strength | lag)
A. BANK <-> NBFC <-> INSURERS
- Rate CUT or yields falling: NBFCs gain most (cheaper funding), then realty and autos, then banks (more loans, thinner margins). CE:
  BAJFINANCE, CHOLAFIN, SHRIRAMFIN, LICHSGFIN, DLF, GODREJPROP. Rate HIKE, yields rising, RBI tightening credit: PE the same plus
  SBICARD. Financing / policy. HIGH. Same day. (Details B6.)
- NBFC CREDIT SCARE (default, mutual funds dumping NBFC paper, liquidity freeze): NBFCs and housing finance hit hardest, then their
  lending banks (INDUSINDBK, AXISBANK); big PSU and large private banks hurt least. HIGH. Same day, then 2-5 days of follow-through.
- INSURERS (SBILIFE, HDFCLIFE, ICICIPRULI, ICICIGI) move with banks at about half the size; own triggers are policy (GST, product rules)
  and monthly premium data. MEDIUM. Same day.
B. DEFENSIVES (FMCG, pharma, sometimes IT) vs CYCLICALS (PSU banks, metals, realty, PSE / defence)
- Risk-off or a political shock -> CE HINDUNILVR, NESTLEIND, ITC, CIPLA, SUNPHARMA, DRREDDY / PE PNB, CANBK, BANKBARODA, SBIN, DLF, SAIL,
  BEL, HAL. Risk-on or growth policy (budget, tax cut) -> the reverse. Flows and beta. HIGH on shock days, LOW on normal days. Same day.
- IT is defensive ONLY when the rupee is weak and the Nasdaq strong. On a US policy shock (visas, tariffs) IT and pharma FALL TOGETHER.
C. PSU vs PRIVATE. Policy or political news, PSU capex, bank recapitalisation -> PSU names move 2-3x as much (PNB, CANBK, BANKBARODA,
   UNIONBANK, BHEL, NTPC, PFC, RECLTD). Asset-quality news or FII flows -> private names move more (HDFCBANK, ICICIBANK, AXISBANK).
   Same day for news; rotation between the two takes weeks (L10).
D. CAPITAL GOODS <-> CEMENT <-> REALTY
- Budget capex up or infra orders -> CE LT, BHEL, SIEMENS, ABB, CGPOWER, then cement (ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT).
  MEDIUM, same day to weeks.
- Rate cut or strong housing sales -> CE realty first (GODREJPROP, OBEROIRLTY, DLF, LODHA, PRESTIGE), then cement and building
  materials. MEDIUM, days to weeks.
- Capex cut or weak order book -> PE capital goods first; cement follows weeks later (volumes).
E. TELECOM <-> TOWERS. Tariff hike -> CE BHARTIARTL, IDEA, INDUSTOWER (tenants stronger). Bad news for Vodafone Idea (AGR, funding) ->
   PE IDEA, then INDUSTOWER (Vi is its biggest tenant risk); BHARTIARTL often dips and then RECOVERS (market share). HIGH, same day.
F. FMCG vs DISCRETIONARY. Rural demand, good monsoon, GST / tax cut on mass goods -> CE FMCG plus 2-wheelers (HEROMOTOCO). Urban boom or
   income-tax relief -> CE TITAN, TRENT, DMART, ETERNAL, autos. Shock day -> FMCG up while discretionary is down. MEDIUM (low single-day
   % for FMCG). Same day for shocks, quarters for demand.
G. DEFENCE <-> PSU. War or border event, export orders, a big DAC approval -> CE BEL, HAL, BDL, MAZDOCK; wider PSEs (NTPC, BHEL) join only
   if the whole PSU theme is bid. Political doubt -> PE defence and all PSEs together. HIGH, same day; runs for days, then reverses sharply.
H. NEXT DAY - "one sector up today, which one is down tomorrow" (all [E]; weak unless a driver sits behind it)
- (a) After a shock crash the market bounces next day, but the hit bucket bounces a day LATER (June 2024: PSU fell again on day 2,
  bounced on day 3).
- (b) After a policy day (budget, RBI) the winner often sees profit-taking on day 2; the laggard in the same theme catches up
  (private bank -> PSU bank, DLF -> GODREJPROP).
- (c) If defensives led a falling-Nifty day and Nifty then turns up, high beta leads next day (PSU banks, metals, realty) and FMCG /
  pharma lag.
- (d) A defence or PSE theme day of +8% or more is followed by a red day more often than by another +5% day.
- Hit rates are about 50-56% (SECTOR_LINKS). Use these only to name the WATCH; the 09:20 sector breadth must confirm before any CE / PE.
I. METALS RALLY -> money out of HINDUNILVR, NESTLEIND, pharma the same day (CHAIN_OF_EVENTS row 29; no date found yet).

**2. Leaders**
- Rates: BAJFINANCE and the realty names. SBICARD on any consumer-credit rule.
- NBFC scare: housing finance leads down (LICHSGFIN), then SHRIRAMFIN, CHOLAFIN.
- PSU banks: PNB, CANBK, BANKBARODA swing more than SBIN (lower price, higher beta, more retail and F&O froth).
- Defensive bid: CIPLA, DRREDDY, SUNPHARMA move most in %; HINDUNILVR leads FMCG but moves only 1-5%.
- IT: mid-tier (LTIM, PERSISTENT, COFORGE) swings most on the Nasdaq; TCS and INFY lead on visa or deal news.
- Telecom: IDEA, then INDUSTOWER. Defence: BDL, MAZDOCK in %; BEL the best option chain. Capital goods: BHEL most, LT least but cleanest.

**3. Own traps** (common: C1, C4, C8, C10, C12, C17, C19)
- A broad panic sells everything, defensives included (March 2020 week 3: pharma fell too, only less).
- One big result (HDFCBANK, TCS) overrides the rotation for the whole sector that day.
- Theme stocks (defence, PSE, railways) are momentum trades: one profit-booking day erases 3 days of link.
- A Vodafone Idea court or funding headline can reverse within minutes.

**4. Past cases** (cases told in full elsewhere: DHFL 21 Sep 2018 -> B6; tax cut 20 Sep 2019, AGR 24 Oct 2019, elections Jun 2024,
tariff hike Jun 2024, Operation Sindoor May 2025 -> B10; risk weights Nov 2023, RBI 6 Jun 2025 -> B6; H-1B 22 Sep 2025 -> B7)
- Nov 2016, demonetisation: Bank Nifty +3.5% on 10 Nov (deposit story); BSE Realty -17% from 8 Nov to 26 Dec. [V, Business Standard]
- Early March 2020, COVID: Nifty Pharma +8.1% in 3 sessions to 5 Mar while Nifty fell 2.6%. From the 23 Mar low to 30 Jun: CIPLA +67%,
  SUNPHARMA +44%, DRREDDY +41%. [V, Business Standard, ETV Bharat]
- 1 Feb 2021, budget (bad bank, capex): Bank Nifty +8.26%, PSU Bank +7.8%, Fin Service +7.6%, Auto +4.2%; ICICIBANK and INDUSINDBK
  over +10%. [V, Business Standard, Upstox]

**Sources**
- https://www.business-standard.com/amp/article/economy-policy/one-year-of-demonetisation-short-lived-scare-for-stock-markets-117110700022_1.html
- https://www.business-standard.com/article/markets/sensex-surges-around-400-points-nifty-above-8550-116111000480_1.html
- https://www.business-standard.com/article/news-cm/nifty-slips-below-11-300-pharma-stocks-in-demand-120030400323_1.html
- https://etvbharat.com/english/business/markets/pharma-stocks-gained-55-percent-since-lockdown/na20200702060120595
- https://www.business-standard.com/amp/article/markets/nifty-bank-hits-fresh-high-post-budget-boost-charts-suggest-further-upside-121020100996_1.html
- https://upstox.com/market-talk/market-recap-for-1-february-2021/
- Other cases: sources in B6, B7, B10.

### B12. MONTHLY AND SCHEDULED DATA

Does not repeat the copper / aluminium chains or SECTOR_LINKS L01-L16.

**1. The links**
1. Auto sales (1st of the month, during market hours; VAHAN registrations mid-month give an early read)
   - MISS -> PE the reporter, then its segment peers; PE auto parts (MOTHERSON, SONACOMS, BOSCHLTD, UNOMINDA, BHARATFORG, EXIDEIND),
     tyres (MRF, APOLLOTYRE), vehicle financiers (CHOLAFIN, SHRIRAMFIN, M&MFIN). No sector benefits; a rival (HYUNDAI) can gain share.
   - BEAT -> CE the reporter, then parts and financiers. Revenue / demand. HIGH for the reporter, MEDIUM for peers. Same day.
2. GST collections (1st): LOW, mood only. GST RATE decisions are the big policy link (B10 section 1).
3. CPI (about the 12th, 16:00 IST, so it moves the NEXT day) and WPI (about the 14th)
   - CPI BELOW consensus -> CE rate sensitives: banks (HDFCBANK, ICICIBANK, SBIN), NBFCs (BAJFINANCE, LICHSGFIN, CHOLAFIN), realty (DLF,
     GODREJPROP, LODHA), autos. ABOVE -> PE the same; FMCG and pharma hold up. Financing. MEDIUM, only on a beat or miss of 0.3 pp or
     more [E]. Next day.
   - High WPI / input inflation -> margin worry for FMCG and paints. LOW, weeks.
   - CPI food spike -> PE rate-sensitive banks and autos for days (RBI cut delayed).
4. PMI (1st-3rd), IIP and core sector (end-month / about the 12th): LOW. Weak core data on cement, steel, power or coal -> mild PE tilt
   on ULTRACEMCO, TATASTEEL, NTPC, COALINDIA; strong -> mild CE. Supporting evidence only, never the trigger.
5. Fuel prices
   - ATF (revised on the 1st): CUT -> CE INDIGO; HIKE -> PE INDIGO. Cost. MEDIUM. Same day.
   - Petrol / diesel retail CUT -> PE OMCs (BPCL, HINDPETRO, IOC: margin squeeze), mild CE autos and paints. Excise hike with no retail
     change -> PE OMCs. MEDIUM. Next open. Commercial LPG change -> LOW.
6. Cement prices (dealer checks early and mid-month, broker notes)
   - Hike that sticks -> CE ULTRACEMCO, SHREECEM, AMBUJACEM, DALBHARAT, ACC. Rollback / price war (new capacity, monsoon Jul-Sep) -> PE
     the same. MEDIUM. Same day. Realty and contractors barely hurt.
7. Airline traffic (DGCA, about the 3rd week): LOW; only a market-share shock moves INDIGO. Crude and ATF matter more.
8. Power demand (daily grid data; peak records Apr-Jun): record / heatwave -> CE NTPC, TATAPOWER, JSWENERGY, NHPC, POWERGRID, IEX,
   COALINDIA, VOLTAS, BLUESTARCO, HAVELLS. Early monsoon / weak demand -> PE VOLTAS, BLUESTARCO (and IEX on prices, but see B9: its
   volume can rise). MEDIUM in summer, LOW otherwise.
9. Results season (Jan / Apr / Jul / Oct): leader MISS -> PE peers; BEAT -> CE peers. Pairs: TCS / INFY -> IT; HDFCBANK / ICICIBANK ->
   private banks; MARUTI -> parts; ULTRACEMCO -> cement; a big OMC -> the other two. HIGH for the stock, MEDIUM for peers. Next open.
10. Index rebalancing (NIFTY semi-annual Mar / Sep, announced about 4 weeks before; MSCI Feb / May / Aug / Nov, effective at the close on
    the last trading day of the month): INCLUSION -> CE on announcement; EXCLUSION -> PE on announcement. MEDIUM on announcement, LOW on
    the effective day - that flow lands in the closing auction after 15:10, which this trader cannot use.
11. F&O expiry (stock options monthly, last Tuesday; NIFTY weekly on Tuesday): price pins near the biggest open-interest strikes and
    time value melts. Avoid near-month options in the last 2-3 sessions (rule E7: next month). MEDIUM.
12. F&O ban (open interest at 95% of the market-wide limit; lifts below 80%; measured on futures-equivalent OI from 8 Dec 2025 [V]):
    GIR must NOT propose a fresh CE / PE on a banned share. Stocks often enter the ban after heavy short build-up, so watch for a
    short-covering spike when it lifts [E]. Exclusion from the F&O list (SEBI review) -> PE tilt [E].

**2. Leaders**
- Auto sales: whoever surprises most against the poll (BAJAJ-AUTO about -8% on 1 Oct 2026). On a broad miss, HEROMOTOCO, TVSMOTOR,
  BAJAJ-AUTO and EICHERMOT move more than MARUTI [E].
- GST cut: M&M led; EICHERMOT led 2-wheelers; MARUTI lagged (expected) [V].
- CPI: PSU banks and realty (high beta); BAJFINANCE among NBFCs [E].
- Cement hike: SHREECEM and AMBUJACEM rise more than ULTRACEMCO in % [E].
- Power: TATAPOWER and IEX most responsive; NTPC, POWERGRID steadier [E].
- Results: INFY is about 29% of NIFTY IT and drives the read-across [V]; WIPRO, TECHM, LTIM move more in % [E].

**3. Own traps** (common: C1, C4, C8, C12)
- Crude or risk-off overrides the data: strong August sales, yet NIFTY AUTO fell about 2% when crude spiked [V, 5paisa].
- GST cut day 4 Sep 2025: big intraday gains, much smaller closes (B10). Trade the first 30-60 minutes; do not hold to the close.
- Rebalancing is sell-the-news: HDFCBANK -3.5% on MSCI partial inclusion (Aug 2024) [V]; Zomato and JFS only +1.5% and +1.4% on their
  first NIFTY day [V] - the move comes on the announcement.
- Never buy a CE / PE on a stock in the 1-2 sessions before its own results (IV crush) [E].
- Summer power stories are mostly priced in (analysts said so in Apr 2026) [V].

**4. Past cases**
- 13 May 2016: CPI above expectations; Sensex -301, banks, autos, realty sold. [V, Business Standard]
- 11 Jul 2022: TCS -4.7%, NIFTY IT -3%. [V, Business Standard]
- 17 Apr 2023: INFY -11% intraday, NIFTY IT -8% intraday. [V, Business Standard]
- 15 Mar 2024: Rs 2 petrol / diesel cut; OMCs -2 to -4% [E, size not checked].
- 3 Apr 2024: Rs 10-15/bag cement hike; top five cement stocks +1 to +3%. [V, CemNet]
- 2 Aug 2024: weak July sales; NIFTY AUTO -2%; MARUTI, TATAMOTORS (now TMPV), EICHERMOT -3.5 to -5% intraday. [V, Business Standard, Upstox]
- 13 Aug 2024: MSCI partial inclusion; HDFCBANK -3.5%. [V, Business Standard]
- 3 Oct 2024: September PV sales slowed, CV sales fell; NIFTY AUTO -3%. [V, Business Standard]
- 11 Dec 2024: cement dealers raised prices; ACC +1.9%, AMBUJACEM +1.8%, SHREECEM +1.8%, sector up to 4.5% intraday. [V, Business Standard]
- 9 Apr 2025 (RBI cut day): realty and PSU banks -2%, autos outperformed (B6). [V]
- 11 Jul 2025: TCS miss; NIFTY IT -2%, INFY -3.3%. [V, Angel One]
- 4 Sep 2025: GST 2.0 decision (B10). [V]
- 27 Apr 2026: heatwave; AC makers and power stocks up to +6%. [V, Business Standard]
- 1 Oct 2026 (September sales; year inferred from the TMPV name): BAJAJ-AUTO about -8% (5.38 lakh units vs a 5.79 lakh poll); MARUTI
  -2.5%, EICHERMOT -2.9%, TMPV -1.6%; Hyundai +1.2%. [V, 5paisa]
- Zomato and JFS NIFTY inclusion: +1.5% and +1.4% on the first day. [V, 5paisa]

**Sources**
- https://www.business-standard.com/amp/markets/news/auto-index-skids-2-on-tepid-july-sales-maruti-tamo-eicher-slip-up-to-5-124080200472_1.html
- https://upstox.com/news/market-news/trading/nifty-auto-falls-2-over-weak-july-auto-sales-maruti-suzuki-shares-down-4/article-107124
- https://www.business-standard.com/amp/markets/news/nifty-auto-skids-3-as-sept-passenger-vehicle-sales-slow-cv-sales-fall-124100300621_1.html
- https://www.5paisa.com/blog/bajaj-auto-shares-crash-nearly-8-as-september-sales-disappoint-mm-maruti-also-fall
- https://www.5paisa.com/index.php/blog/nifty-auto-crude-oil-surge
- https://www.business-standard.com/amp/markets/news/cement-shares-in-action-heidelberg-ultratech-shree-nuvoco-zoom-up-to-4-124121100247_1.html
- https://cemnet.com/News/story/176758/indian-cement-stocks-boosted-3-due-to-increasing-bag-prices.html
- https://www.business-standard.com/amp/article/markets/rising-cpi-inflation-dashes-rate-cut-hope-sensex-ends-301-points-lower-116051300621_1.html
- https://www.angelone.in/news/why-it-stocks-are-falling-on-july-11-2025-nifty-it-down-2-percent-as-tcs-results-disappoint
- https://www.business-standard.com/markets/news/nifty-it-index-plunges-8-on-revenue-growth-concerns-123041700191_1.html
- https://bsppd.business-standard.com/article/markets/tcs-slips-4-on-weak-margins-in-june-quarter-it-shares-follow-suit-122071100158_1.html
- https://www.business-standard.com/markets/news/ac-makers-power-stocks-rise-up-6-on-demand-surge-amid-severe-heatwave-126042700457_1.html
- https://www.business-standard.com/markets/news/india-narrows-gap-with-china-after-latest-msci-rejig-3-bn-inflows-seen-124081301818_1.html
- https://5paisa.com/news/zomato-jio-financial-services-join-nifty-50-key-stocks-see-inflows-and-outflows
- https://www.indiainfoline.com/knowledge-center/derivatives/why-are-stocks-banned-in-f-and-o
- https://www.angelone.in/news/stocks/nifty-weekly-expiry-bandhan-bank-kaynes-technology-and-sammaan-capital-under-f-and-o-ban-on-december-9-2025
- GST 2.0 and RBI sources: B10, B6.

---

## C. WHEN LINKS FAIL - the common traps in one list

GIR checks every link against this list before it goes on the evening note. A link that hits a trap is downgraded or cancelled,
and the note says which trap.

- **C1. Risk-off and FII-selling days.** Producers and users fall together; only the producer PE side works, the user CE fails.
  Metals fall whatever the commodity does. Gold-loan CE fails when NIFTY is down more than 1.5%. FMCG goes UP as a hiding place, so
  never take an FMCG PE on input news when Nifty is down more than 1%. Do not buy any "beneficiary" CE when Nifty is below -1% by
  09:30. Banks are the biggest FII holding: no domestic good news beats heavy FII cash selling. Check GIFT NIFTY, US futures, FII
  flows and USDINR first.
- **C2. Demand panic disguised as cost relief.** A commodity falling because the world fears recession (Mar 2020 crude; 5 Aug 2024
  US yields) is risk-off, not a cost gift. A crude fall with GIFT NIFTY down more than 0.7% is not an OMC CE day.
- **C3. Already in the price.** A move during Indian hours is in the price by 15:30. Only an overnight move (US session 20:00-01:00
  IST; LME / MCX / SHFE confirmed at 23:30 and 06:30) is a next-day edge. Use the 07:15 levels. Moves shrink by day 2-3 of a fall.
  Heatwave stories run out after 1-2 days.
- **C4. Expected news = sell the news.** An expected RBI cut (7 Feb 2025), the GST cut flagged on 15 Aug and decided on 3 Sep 2025,
  a DGTR recommendation before its notification, a fully priced Fed decision, an index inclusion on its effective day. If the sector
  ran more than 5% in the 5 days before, mark it PRICED IN. Only a SURPRISE in size or a new element (CRR cut, stance change) gives
  a clean trend day.
- **C5. Policy beats price.** Excise cuts and OMC "absorb" orders (4-5 Oct 2018), windfall tax (1 Jul 2022), gold duty changes
  (23 Jul 2024, 13 May 2026), RBI gold-loan rules (9 Apr 2025), APM gas allocation (Oct-Nov 2024), CERC orders (24 Jul 2025), gas
  price decisions either way (3 and 10 Apr 2023). Read the news every evening before trusting a price link.
- **C6. Supply overhang beats the commodity.** Government OFS or promoter block deals (HINDZINC: Aug 2024, 6 Nov 2024, Jun 2025,
  2026 talk). In an OFS or block week, ignore the metal.
- **C7. Another driver owns the share.** Silver over zinc (HINDZINC); alumina over aluminium (NATIONALUM); AI-disruption fear over
  the Nasdaq (Indian IT in 2026); US tech or recession fear over the rupee (IT, July 2022); retail and Jio over refining (RELIANCE);
  Europe farm demand and EUR over rubber (BALKRISIND); crude before rubber (tyres); a US tariff over cotton; Brazil and China over
  Indian rain (agrochem); EV and lithium stories over lead (batteries); own news for the Adani names; a paint price war over crude.
- **C8. Results season and IV crush.** The company's guidance overrides the link within days. No link trade in the 2 sessions
  around the company's own results (OMC inventory losses; rupee trades in IT in the TCS-to-INFY week; bank margin compression for
  2-3 weeks after cuts). Option IV is high before results and collapses after: a buyer can be right on direction and still lose.
- **C9. Cost links are slow.** Users (autos, LT, cement, paints, FMCG, tyres) rarely rally intraday on a raw-material fall; they need
  2+ weeks of lower prices plus results commentary. Same day, trade the producer side. A JSWSTEEL CE "because ore is cheaper" loses
  on China days. APLAPOLLO moves opposite to the textbook (inventory). Cement follows capital goods only weeks later.
- **C10. Fast reversals.** War headlines (24 Jun 2025 faded by the close); policy shocks reversed (Indonesia palm ban lifted
  23 May 2022; RBI gold-loan cap eased 6 Jun 2025); hike-day reversal (7 Oct 2026); consultation papers softened (BSE +4% the day
  after 1 Feb 2026); RBI defending the rupee (do not chase a record-low print after 11:00); Vodafone Idea headlines within minutes;
  theme stocks where one profit-booking day erases 3 days. Take the day-1 move and keep the 15:10 exit.
- **C11. Gaps and holidays.** Never chase a gap of 10% or more on day 1, or a PE after a 3%+ gap-down (relief often comes on day
  2-3). Wait for the 09:30 range break, a 10:15 retest, or the first 15-minute pullback that holds VWAP. A world move during an Indian
  holiday is traded as the gap at the open only, not after 10:00. China holidays (Golden Week) show "0%": closed, not flat.
- **C12. Option mechanics.** Policy-day IV crush after the 10:00 release; options expensive when VIX spikes (buy after the first
  15 minutes); circuit-hit names (PAYTM, IDEA, IEX) have blown-out premiums - trade the linked share; MRF and other high-priced names
  are illiquid - show the next name; near-month options decay in the last 2-3 sessions (use next month, rule E7); weekly-expiry days
  distort the index-heavy banks; a share in the F&O ban gets no new CE / PE.
- **C13. The rupee offsets the move.** A crude fall paired with a rupee fall of more than 0.5% halves the OMC benefit. A 1% rupee
  gain cancels about 1% of an LME rise for metal producers.
- **C14. Hedging and pass-through blunt small moves.** OMC hedges (only a rupee move of more than 0.5% matters), TITAN's gold-on-lease,
  regulated utilities on assured returns (NTPC, POWERGRID), the urea gas subsidy, CNG / PNG price pass-through 2-6 weeks later, price
  variation clauses for capital goods, AMBER / PGEL contracts with brands.
- **C15. Noisy data.** One day of FII flows (use the 5-day sum; a block deal distorts it); a single week of July-August rain (only a
  cumulative deficit beyond -10% counts); Skymet before IMD (trade the surprise against Skymet; its April calls average about 4.6%
  too low); PMI, IIP and core sector (never a trigger).
- **C16. One company is not a sector.** A SEBI or RBI action against one company (PAYTM, a single lender) hits that share; peers
  barely move.
- **C17. "IT and pharma are safe" is not always true.** On a US policy shock (visas, drug tariffs) IT and pharma FALL TOGETHER
  (22 Sep 2025). In a market-wide rally IT lags (20 Sep 2019). IT is defensive only when the rupee is weak and the Nasdaq is calm.
- **C18. Panic policy means trouble.** An emergency rate cut in a crisis (27 Mar 2020: bank index +8% intraday, +0.8% at the close):
  do not hold banks CE into the close.
- **C19. "Sector A today -> sector B tomorrow" is weak.** Without a driver behind it the hit rate is about 50-56% and most of the move
  is in the 09:15 gap. Name it as WATCH only; 09:20 sector breadth must confirm.

---

## D. THE EVENING NOTE TEMPLATES

**Clock.** 19:45 main note (TOMORROW'S OPTION WATCH). 20:45 add-on for China (DCE / SHFE night session, about 18:30-20:30 IST).
22:45 re-check only if a grade changes (US open, Brent, Fed nights). 23:30 MCX metals confirmation. 06:30 SHFE. 07:15 update
(Brent, GIFT NIFTY, ADRs, LME / SHFE, China news) - STANDS / CHANGED / CANCELLED. 09:08 pre-open check. 09:20 whole-sector
breadth confirmation (never before). Exit by 15:10. No option is carried overnight.

**The standard line (every note uses it):**
"<Driver> <move> (<level>) -> TOMORROW CE: <leader>, <others> / PE: <leader>, <others>. Linked: <sector>. Strength <H/M/L>,
lag <same day / next open>. Past case: <date, what moved> (hit rate <x of y> or 'not measured - IDEA - NOT PROVEN').
Cancel if: <conditions>. Trap: <C-number>."

**Thresholds for writing a line** (all [E] until the history database sets them)
| Driver | Watch line | Strong |
|---|---|---|
| Brent | +-2% | +-3% (STRONG); +-5% = shock, whole-market check first |
| Rupee | 0.4% or a record print | 0.6%+ |
| DXY | 0.8% | with US 10y up |
| LME / MCX metals | 2.5% overnight, MCX confirmed at 23:30 | - |
| Dalian ore / SHFE HRC | 2.5% | 4% |
| Gold / silver | not set - to be set from the history database | - |
| India 10y | 8-10 bp | 15 bp+ |
| US 10y | 10 bp | 15 bp+ |
| Nasdaq | 1.5% (with the ADRs) | 2%+ |
| FII flows | Rs 5,000 cr on the 5-day sum | - |
| CPI | 0.3 pp vs consensus | - |
| Palm oil | 6% in 2 days | exporter ban |
| Rubber | 5% in a week (Brent not up) | - |
| July rain | cumulative deficit beyond -10% | - |
| NSE sector | 1.5%+ in the day (CHAIN_OF_EVENTS) | - |

**D1. Crude (B1)**
- "Brent fell N% (to $X), rupee steady, GIFT flat or up, no policy news -> TOMORROW CE: HINDPETRO, BPCL, IOC, INDIGO, ASHOKLEY; watch
  ASIANPAINT, APOLLOTYRE / PE: ONGC, OIL. Cancel if Brent is back up 1.5%+ by 07:15, GIFT is down more than 0.7% (demand panic), an
  excise or price-cut headline appears, or an OMC reports within 2 days."
- "Brent rose N% (war or supply shock) -> TOMORROW PE: HINDPETRO, BPCL, INDIGO, ASIANPAINT, BAJFINANCE; NIFTY weak / CE: ONGC, OIL, HAL,
  BEL. Cancel on a ceasefire or de-escalation headline overnight, or if Brent gives back half the move by 07:15."
- "Government cuts fuel prices or excise, or asks OMCs to absorb -> TOMORROW PE: HINDPETRO, BPCL, IOC, whatever crude does. New windfall
  tax -> PE: ONGC, OIL, RELIANCE."

**D2. Gold and silver (B2)**
- "Gold fell N% (world selling) -> TOMORROW PE: MUTHOOTFIN, MANAPPURAM (gap at open; skip if NIFTY is strongly green). CE: none.
  Jewellers: no trade."
- "Gold rose N% -> TOMORROW CE: MUTHOOTFIN, MANAPPURAM, MCX. If NIFTY falls more than 1%: PE on banks and midcaps, gold-loan CE only."
- "Silver fell / rose N% -> TOMORROW PE / CE: HINDZINC (leader), VEDL, MCX."
- "Gold duty CUT -> TOMORROW CE: TITAN, KALYANKJIL / PE: MUTHOOTFIN, MANAPPURAM."
- "Gold duty HIKE / 'don't buy gold' appeal -> TOMORROW PE: KALYANKJIL (leader), TITAN (milder, reverses first)."
- "India was shut when gold moved -> trade the gap at the open only."

**D3. Steel, iron ore, coal (B3) - sent at 20:45, after the China night session**
- "Dalian iron ore -4%, SHFE HRC -2.5% -> TOMORROW PE: NMDC (leader), SAIL, JINDALSTEL, TATASTEEL; no CE on autos (weeks, not tomorrow).
  Not if NIFTY gaps up strongly."
- "Iron ore / HRC +3% on China stimulus -> TOMORROW CE: TATASTEEL, JINDALSTEL, SAIL, NMDC; JSWSTEEL laggard."
- "Coking coal +5% this week -> TOMORROW PE bias: JSWSTEEL, SAIL (import-heavy); TATASTEEL less hurt."
- "Newcastle coal / pet coke -5% -> CE watch cement: SHREECEM, DALBHARAT, AMBUJACEM (days to weeks); COALINDIA PE if the e-auction premium
  is falling."
- "Power shortage / coal +5%, IEX prices spiking -> CE: COALINDIA, JSWENERGY, ADANIPOWER, IEX; PE: cement."
- "Govt notifies steel export duty -> TOMORROW PE: JINDALSTEL, NMDC, TATASTEEL, JSWSTEEL. Import duty / safeguard -> CE: SAIL, JSWSTEEL,
  TATASTEEL (check it is not already priced in from the DGTR recommendation)."

**D4. Aluminium, zinc, lead, nickel (B4) - send when the move is 2.5%+ overnight and MCX confirms at 23:30**
- "LME aluminium +N% -> TOMORROW CE: NATIONALUM (leader), VEDL, HINDALCO / PE: none same-day (autos, cables = slow cost tilt). Cancel if
  SHFE fades more than 1.5% by 06:30 or the rupee gains 0.5%."
- "LME aluminium -N% -> TOMORROW PE: NATIONALUM (leader), VEDL, HINDALCO / CE: autos, ACs per COPPER_LINKS."
- "Alumina -N% (aluminium flat) -> TOMORROW PE: NATIONALUM only. Skip VEDL and HINDALCO."
- "Zinc +N%, silver +M% -> TOMORROW CE: HINDZINC (leader), VEDL. If silver is down, downgrade to WATCH. If OFS or block news is live, SKIP."
- "Zinc / silver -N% -> TOMORROW PE: HINDZINC (leader), VEDL / CE: none."
- "Lead -N% over the month -> SWING tilt CE: ARE&M, EXIDEIND (weeks, not intraday). Lead +N% sustained -> PE tilt, same names."
- "Nickel +/-N% -> NO TRADE. Metals mood only. JSL watch."

**D5. Rupee and dollar (B5) - send when the move is 0.4%+ or a record print by 19:45; reconfirm at 07:15 with GIFT NIFTY, Nasdaq, ADRs**
- "RUPEE FELL 0.6% to <x> (record low) -> TOMORROW CE: INFY, WIPRO, HCLTECH, AUROPHARMA, BALKRISIND / PE: HINDPETRO, BPCL, INDIGO, DIXON.
  Cancel IT CE if Nasdaq is down more than 1% or the INFY ADR is red."
- "RUPEE ROSE 0.6% to <x> (FII inflow / RBI) -> TOMORROW CE: HINDPETRO, INDIGO, HDFCBANK, ASIANPAINT / PE: INFY, TCS, AUROPHARMA."
- "DXY UP 0.8% plus US 10y UP -> TOMORROW PE: HDFCBANK, BAJFINANCE, VEDL, HINDALCO / CE: none clean; IT only relative."
- "DXY DOWN 0.8% -> TOMORROW CE: VEDL, HINDALCO, NATIONALUM, ICICIBANK / PE: weak IT names (watch only)."

**D6. Rates, RBI, liquidity (B6)**
- "RBI cut 50 bp vs 25 expected (+CRR cut) -> TOMORROW CE: GODREJPROP, DLF, LICHSGFIN, BAJFINANCE, PNB / PE: none (avoid IT CE). Only if
  Nifty Realty closed more than 2% up and USDINR is stable."
- "RBI cut 25 bp as expected -> TOMORROW: no fresh rate trade (priced in). Watch the stance and inflation forecast. Repo-linked private
  banks (KOTAKBANK, BANDHANBNK) are PE candidates on margin worry."
- "RBI hiked / stance turned hawkish -> TOMORROW PE: GODREJPROP, DLF, BAJFINANCE, CHOLAFIN, LICHSGFIN / CE (relative): TCS, INFY,
  HINDUNILVR. No bank PE if banks recovered by 15:00 (7 Oct 2026 pattern)."
- "India 10y up 10 bp+ today (to X%) -> TOMORROW PE: realty, NBFCs, PSU banks (bond losses) / CE: IT, FMCG. First check whether the US
  10y or crude caused it."
- "RBI liquidity injection (OMO / VRR / CRR / swap) -> TOMORROW CE: AUBANK, PNB, AXISBANK, BANKBARODA, BAJFINANCE."
- "RBI tightened lending rules (risk weights / unsecured loans) -> TOMORROW PE: SBICARD, BAJFINANCE, the named lenders / CE: none.
  Read the circular."
- "Lender or commercial-paper default -> TOMORROW PE: wholesale-funded NBFCs and housing finance (LICHSGFIN, SHRIRAMFIN) / CE (relative):
  HDFCBANK, ICICIBANK, KOTAKBANK. No CE on the hit names until the selling stops. Defensives only if Nifty breaks."

**D7. US and global (B7)**
- "Nasdaq -2%, INFY ADR -3% -> TOMORROW PE: INFY (leader), TECHM, WIPRO, COFORGE; EMS PE: DIXON, KAYNES. Cancel if the ADRs recover by
  07:15. Check the CAUSE: an AI-tool launch can lift the Nasdaq and sink Indian IT."
- "Accenture / Cognizant beat -> TOMORROW CE: TECHM, INFY, COFORGE."
- "US 10y +15 bp, DXY up, rupee weak -> PE: SBIN (leader), PNB, DLF, BAJFINANCE / relative strength: INFY, SUNPHARMA."
- "Fed dovish surprise -> CE: DLF (leader), ICICIBANK, SBIN, TATASTEEL, INFY. Confirm with GIFT NIFTY and the rupee at 09:08."
- "China stimulus / PBoC cut -> CE: VEDL (leader), TATASTEEL, SAIL, NMDC, HINDALCO. Cancel if SHFE / LME are flat at 07:15."
- "Weak China data / yuan down -> PE: TATASTEEL (leader), JSWSTEEL, SAIL, VEDL, TMPV."
- "Global risk-off (VIX up, Nasdaq -3%) -> PE: TATASTEEL, VEDL, SBIN, DLF / relative CE only if above VWAP: SUNPHARMA, CIPLA. Do not
  chase a 3%+ gap."
- "US visa curb -> PE: TECHM (leader), LTIM, INFY." / "US drug tariff -> PE: SUNPHARMA (branded) or AUROPHARMA, LUPIN (generics)."
- "FII net sell above Rs 5,000 cr (5-day sum negative) -> PE tilt: HDFCBANK, ICICIBANK, RELIANCE. A tilt only, not a trigger."

**D8. Agri and monsoon (B8)**
- "IMD monsoon forecast 92% (below normal) -> TOMORROW PE: ESCORTS, M&M, HEROMOTOCO, DABUR / CE: IEX, NTPC. Skip if Skymet already said lower."
- "IMD forecast 105% (above normal) -> TOMORROW CE: ESCORTS, M&M, HEROMOTOCO, DABUR, UPL / PE: none."
- "Palm oil +6% in 2 days (or an exporter ban) -> TOMORROW PE: GODREJCP, BRITANNIA, MARICO / CE: none. Void if Nifty is risk-off."
- "Palm oil -8% in a week -> tilt CE: GODREJCP, BRITANNIA (weeks, not a day trade)."
- "Govt sugar export ban / ethanol cap -> TOMORROW PE: BALRAMCHIN (expect a 2-day move) / CE: none."
- "Sugar export quota / ethanol price hike -> TOMORROW CE: BALRAMCHIN."
- "Rubber -5% in a week (Brent not up) -> CE: APOLLOTYRE, CEATLTD / PE: none. Rubber +5% -> PE the same names."
- "Fertiliser subsidy cut / NBS rates cut / MRP cut -> TOMORROW PE: COROMANDEL, CHAMBLFERT."
- "July rain deficit beyond -10% (cumulative) -> tilt PE: ESCORTS, M&M, HEROMOTOCO, DABUR; CE: IEX."
- "CPI food inflation spike -> PE: rate-sensitive banks and autos for days (RBI cut delayed)."

**D9. Gas, power, renewables (B9)**
- "Spot LNG -N% -> TOMORROW CE: GUJGASLTD, PETRONET, IGL / MGL; PE: none. Watch Morbi propane vs gas price." (LNG +N% or a supply shock:
  PE PETRONET, GUJGASLTD, MGL.)
- "APM gas allocation cut / gas price unchanged -> TOMORROW PE: IGL, MGL (GUJGASLTD less). Price cap or extra allocation -> CE: IGL, MGL."
- "CNG hike / crude +N% -> TOMORROW CE: IGL, MGL; PE: OMCs (SECTOR_LINKS L05)."
- "Peak demand record / heatwave / IEX price +N% -> TOMORROW CE: TATAPOWER, JSWENERGY, NTPC, COALINDIA; PE: cement only if coal is short."
- "Monsoon early / demand weak / IEX price -N% -> TOMORROW PE: JSWENERGY, TATAPOWER, COALINDIA; NOT IEX (volume may rise)."
- "CERC order on exchanges (coupling, cap, fees) -> TOMORROW PE: IEX. Skip calls."
- "Coal shortage / imported coal +N% -> TOMORROW CE: COALINDIA, NTPC, TATAPOWER; PE: ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT."
- "Coal India e-auction premium down / price cut -> TOMORROW PE: COALINDIA; CE (slow): cement."
- "Module prices down / GST cut / green tender -> CE: TATAPOWER, ADANIGREEN, SUZLON; PE: WAAREEENER, PREMIERENE. Duty on imports -> reverse."
- "Big thermal or transmission order -> TOMORROW CE: BHEL (then SIEMENS, CGPOWER, POWERGRID)."
- "Gas supply cut to fertiliser plants -> PE: CHAMBLFERT. Subsidy rise / priority gas -> CE: CHAMBLFERT, COROMANDEL."

**D10. Government and regulators (B10) - news after the close; the move is in the 09:15 gap, trade only a 09:30 range break**
- "GST cut on <item> -> TOMORROW CE: M&M, MARUTI, EICHERMOT, HEROMOTOCO, TVSMOTOR, BAJFINANCE (+ VOLTAS / BLUESTARCO if durables are
  included) - first hour only / PE: none. If autos ran more than 5% this week, mark PRICED IN. Confirm at 09:30."
- "Export duty on <product> -> TOMORROW PE: <producers, e.g. JINDALSTEL, JSWSTEEL, TATASTEEL> / CE (weak, weeks): autos, capital goods.
  Expect a gap; trade only a break of the 09:30 range."
- "Gold duty cut -> TOMORROW CE: TITAN, KALYANKJIL / PE: MUTHOOTFIN, MANAPPURAM."
- "Budget capex flat -> TOMORROW PE: RVNL, IRFC, BEL, BHEL, LT / CE: consumption names if income-tax relief was given."
- "STT / F&O curb -> TOMORROW PE: BSE, ANGELONE, CDSL, MCX. High IV; prefer the second-day share. A bounce is likely on day 2."
- "RBI tightens <product> -> TOMORROW PE: <most exposed, e.g. SBICARD, BAJFINANCE> / CE: none. Read the circular."
- "Big defence order / conflict -> TOMORROW CE: BDL, MAZDOCK, HAL, BEL. Ceasefire or peace headline = PE on the same names."
- "Telecom relief / tariff hike -> TOMORROW CE: IDEA, INDUSTOWER, BHARTIARTL."
- "CERC order on <topic> -> TOMORROW PE / CE: IEX (read the sign) / power names NTPC, POWERGRID, TATAPOWER."
- "Exit poll strong NDA -> TOMORROW CE: SBIN, BANKBARODA, POWERGRID, RECLTD, PFC, HAL, BEL / PE: none. Hung signal -> PE on the same
  list; CE: HINDUNILVR and pharma as relative strength."
- Template: "<Regulator> <action> on <item> -> TOMORROW CE: <direct beneficiaries> / PE: <direct losers>. Linked: <sector>. Strength
  <H/M/L>. Trap: <priced in / rumour / circuit>."

**D11. Sector-to-sector (B11) - the 09:20 confirmation is always required**
- "RBI cut bigger than expected / 10y fell N bp -> TOMORROW CE: BAJFINANCE, CHOLAFIN, GODREJPROP, DLF / PE: none. Watch banks for
  sell-the-news."
- "Nifty fell N% on a political or global shock -> TOMORROW CE (if the gap is up): HINDUNILVR, CIPLA, SUNPHARMA / PE: PNB, CANBK, BEL,
  HAL. A PSU bounce is more likely on day 3 than day 2."
- "Budget or capex surprise -> TOMORROW CE: LT, BHEL, SIEMENS, then ULTRACEMCO / PE: the day-1 runaway if it closed more than 6% up
  (profit-taking)."
- "Tariff hike announced -> TOMORROW CE: BHARTIARTL, INDUSTOWER, IDEA. Vi court or funding blow -> PE: IDEA, INDUSTOWER; BHARTIARTL
  watch only."
- "Defence event or big order, BEL / BDL up N% -> TOMORROW CE only if theme breadth holds at 09:20 / PE watch after any +8% day."
- "US visa or tariff hit on services -> TOMORROW PE: TCS, INFY, LTIM, plus AUROPHARMA, LUPIN (US-exposed). Do NOT treat IT or pharma as
  the hiding place."
- "Defensives led a falling Nifty today -> TOMORROW: if GIFT NIFTY is up, CE high beta (PNB, DLF, TATASTEEL) / FMCG and pharma lag."

**D12. Monthly data (B12)**
- "AUTO SALES: <CO> missed by N% (sold X vs poll Y) -> TOMORROW PE: <CO>, its segment peers, MOTHERSON / SONACOMS; CE: none (or the
  rival that gained share). Skip if Brent is up more than 2% or VIX is up."
- "CPI X% vs Y% expected (cool) -> TOMORROW CE: SBIN, BANKBARODA, DLF, BAJFINANCE / PE: none. Hot -> PE the same list."
- "ATF cut N% -> TOMORROW CE: INDIGO. Retail fuel cut Rs N -> PE: BPCL, HINDPETRO, IOC."
- "CEMENT dealers +Rs N/bag -> TOMORROW CE: SHREECEM, AMBUJACEM, ULTRACEMCO, DALBHARAT / PE: none (rollback -> PE the same)."
- "POWER peak record N GW -> TOMORROW CE: TATAPOWER, IEX, NTPC, VOLTAS. Early monsoon -> PE: VOLTAS, BLUESTARCO."
- "RESULTS: <LEADER> missed -> TOMORROW PE: <peers>; no CE / PE on stocks reporting within 2 sessions (IV crush)."
- "INDEX: <STOCK> added to NIFTY / MSCI -> TOMORROW CE watch at the open only; effective day = no trade (flow after 15:10)."
- "EXPIRY in N sessions -> use NEXT-month strikes. BAN list: <stocks> - no new CE / PE."

---

## E. HOW GIR USES THE BOOK

**Every evening at 19:45** (the second-order analyst, step E2b of CHAIN_OF_EVENTS.md):
1. **List what moved sharply today.** Every driver past its threshold (table in D; 1-day or 3/5-day), every NSE sector that moved
   1.5%+, every policy or regulator headline after the close, every scheduled data release, and every "driver moved, users not yet
   reacted" gap.
2. **Look up BOTH sides for each one.** Here (table A, table A2 and the group in B), and in COPPER_LINKS.md, CHAIN_OF_EVENTS.md (chain
   table C) and SECTOR_LINKS.md (L01-L17, part B). Write the CE side AND the PE side, with the leader first. A move with only one side
   written is incomplete.
3. **Run the traps (part C).** Downgrade or cancel each line that hits a trap and name the trap number.
4. **Quote the past case and its hit rate.** Each line names the closest dated case from this book ("like 24 Jun 2025: Brent -3 to -5%,
   OMCs +3 to +5%, INDIGO +3.3%") and the hit rate from the history database ("followed through 7 of 9 times"). Until the database
   has tested the link, the line says **"IDEA - NOT PROVEN"** and "hit rate: not measured". An unproven link may sit on the WATCH; it
   is never the reason for a CE / PE call.
5. **Grade and send** (WEAK / MEDIUM / STRONG) as TOMORROW'S OPTION WATCH, using the standard line in D, with the strike per rule E7
   (next month in the last 2-3 sessions), trigger and cancel conditions.
6. **Re-check** at 22:45 (only if a grade changes), 07:15 and 09:08 (STANDS / CHANGED / CANCELLED); confirm with whole-sector breadth at
   09:20; exit by 15:10.
7. **Log and score.** Every link fired or missed is logged. The 15:45 scorecard counts a move GIR explained only after it happened as a
   MISS, and adds the day to the history database so the hit rate updates.

**Proving the links on the 5-10 year history database** (SECTOR_LINKS part C rule: at least 30 events, hit rate at least 58% and at
least 8 points above normal, holds in both halves and in the last 2 years; the proof line is quoted on the call)
- Test every row of table A in both directions, with the lag stated in the row (same day, next open, days).
- Check every [E] size and every [V] intraday figure in this book against the NSE bhavcopy (closing prices) before it becomes a beta.
- Fill the open "find a date" rows of CHAIN_OF_EVENTS chain table C with the dates found in this book:
  row 4 iron ore / China steel down - 20 Sep 2021; row 5 China stimulus - 24 Sep 2024 (and the 8 Oct 2024 failure); row 6 coking coal
  up - Q3 FY22 (Australian HCC $351 -> $594, Jan-Mar 2022); row 8 aluminium up - 18 Nov 2024, 24 Oct 2025; row 9 zinc / silver up -
  mid-Dec 2025, 23 Jan 2026; row 11 rupee weak - 28 Aug 2013, 8 Mar 2022, 3 Dec 2025, 4 Mar 2026; row 12 Nasdaq / IT down - 27 Jan 2025
  (DeepSeek), Feb 2026; row 15 US 10y / DXY up - Oct 2023, 19 Dec 2024; row 16 gas / LNG (up, the reverse side) - 4 Mar 2026; row 17
  coal / pet coke - 20 Nov 2017 (ban), Mar 2022 and Mar 2026 (up, reverse side); row 19 palm oil (up, reverse side) - 25 Apr 2022; row
  23 safeguard / import duty - 8 Feb 2016, 19 Mar 2025; row 26 leader results (misses, reverse side) - 11 Jul 2022, 17 Apr 2023,
  11 Jul 2025; row 27 monsoon good - 13 Apr 2016. Still without a date: rows 13, 18, 20, 28, 29.
- Ticker history matters in the test: TATAMOTORS -> TMPV / TMCV, AMARAJABAT -> ARE&M, Bharti Infratel -> INDUSTOWER, Indiabulls
  Housing -> SAMMAANCAP, Zomato -> ETERNAL. Map old symbols before counting events.
- Re-check the F&O list every morning; drop or swap any name that left it.

**Open items for the trader**
- The Kite connection (claude-code-kite) timed out on 19 Nov; no number in this book was checked against Kite or NSE data. Reconnect
  before the history database is built.
- The 30 Jan - 1 Feb 2026 bullion-crash date, the 12 Mar 2026 vs 4 Mar 2026 date for the "Brent $100, OMCs -4%" day, and every [E]
  figure need a check before GIR quotes them.
