# GIR - SECTOR LINKS (which sector moves when another sector or a driver moves)

Written 19 Nov 2026 for the trader's questions: "If one sector is down, which sector can go up tomorrow? If one sector is up,
which can go down tomorrow? If metals go up again and again, do autos go down? Is there any link between sectors, and between
a sector and other things?" Built from three desk answers (senior trader, sector strategist, quant), BUILD_PLAN 1.7 and
SHARE_DOSSIER_AND_MACRO.md. No live NSE data was used: the claude-code-kite connection timed out today.

**Labels.** [V] = verified fact or a well-documented past event. [E] = desk estimate or rule of thumb. [T] = reported by the
trader, not yet checked against NSE closing data. **Every link below is PROPOSED until the history database proves it (part C).**
A proposed link may appear on the watch as an idea; it is never the reason for a CE / PE call until it is PROVEN.

**The short answer for the trader.**
1. Yes, sectors are linked. Most links are real, but most of them work slowly, over weeks to quarters, through costs and margins.
2. "Metals up again and again -> autos down" is true over weeks to 1-2 quarters (steel is about 70% of an automaker's raw
   material basket [V, 5paisa]; aluminium, copper and platinum-group metals now matter more [V, Business Standard]). It is NOT a
   reliable next-day rule [E]. On risk-off or crude-spike days METAL and AUTO usually FALL TOGETHER [V, March 2026, 5paisa].
3. The strongest links are SAME-DAY links to fresh drivers: crude, the rupee, overnight Nasdaq, LME metals, China news, RBI,
   monthly data and results read-across. That is where an intraday option buyer has an edge.
4. "Sector A today -> sector B tomorrow" links are weak in India (quant estimate: hit rates around 50-56%) unless a driver is
   behind them. Most of a next-day move is already in the 09:15 gap, which a buyer cannot capture. So the desk names the linked
   sector the evening before and the live engine confirms it at the open; no option is carried overnight.

## A. SECTOR-TO-SECTOR LINKS

Direction: SAME = move the same way; OPPOSITE = one up, the other down. Lag: when the link shows in prices.

| # | Sector A | Sector B | Direction | Why | Lag | F&O shares side A | F&O shares side B | Label |
|---|---|---|---|---|---|---|---|---|
| L01 | METAL (steel, aluminium) | AUTO | OPPOSITE over weeks; SAME on risk-off days | metals are the main auto cost; margins move 1-2 quarters later; both are high-beta cyclicals | weeks-quarters (slow); same day = same sign | TATASTEEL, JSWSTEEL, HINDALCO, SAIL, JINDALSTEL, NATIONALUM, VEDL | MARUTI, M&M, TMPV (ex-TATAMOTORS), BAJAJ-AUTO, HEROMOTOCO, EICHERMOT, TVSMOTOR, ASHOKLEY | direction [V], next-day [E] |
| L02 | METAL | Capital goods, consumer durables | OPPOSITE | steel, copper, aluminium are input costs | weeks-quarters | as L01 | LT, SIEMENS, ABB, BHEL, VOLTAS, HAVELLS, BLUESTARCO | [V] direction, [E] size |
| L03 | Copper / aluminium producers | Cables and wires | SAME (prices fall with copper; they pass costs on with a lag) | copper is most of their cost and revenue | same day | HINDCOPPER, NATIONALUM, HINDALCO, VEDL | POLYCAB, KEI, HAVELLS | [V] |
| L04 | METAL | Mining | SAME | same China / LME driver | same day | TATASTEEL, JSWSTEEL, HINDALCO | NMDC, COALINDIA, VEDL, HINDZINC | [V] |
| L05 | Upstream oil (OIL & GAS) | Oil marketers (OMCs) | OPPOSITE | crude up = upstream earns more, OMCs pay more | same day | ONGC, OIL | BPCL, HINDPETRO, IOC | [V] |
| L06 | Upstream oil | Paints, tyres, aviation, chemicals | OPPOSITE | crude is their cost | same day | ONGC, OIL | ASIANPAINT, BERGEPAINT, MRF, APOLLOTYRE, BALKRISIND, CEAT, INDIGO, SUPREMEIND | [V] |
| L07 | AUTO | Auto parts, tyres | SAME | their customers' volumes are their sales | same day | MARUTI, M&M, TMPV, BAJAJ-AUTO | MOTHERSON, BOSCHLTD, UNOMINDA, SONACOMS, BHARATFORG, EXIDEIND, MRF, APOLLOTYRE | [V] |
| L08 | AUTO | Vehicle financiers | SAME | auto volumes = loan growth | same day to days | as L07 | BAJFINANCE, SHRIRAMFIN, CHOLAFIN, M&MFIN | [V] |
| L09 | BANK | NBFC, insurers, FIN SERVICE | SAME | rates, credit growth, FII flows | same day | HDFCBANK, ICICIBANK, KOTAKBANK, AXISBANK, SBIN | BAJFINANCE, CHOLAFIN, SBILIFE, HDFCLIFE | [V] |
| L10 | Private BANK | PSU BANK | SAME on most days; OPPOSITE as weeks of rotation | same rate driver; money rotates between them | same day = same; weeks = rotation | HDFCBANK, ICICIBANK, KOTAKBANK | SBIN, BANKBARODA, PNB, CANBK | [E] |
| L11 | REALTY | Cement, building materials, paints | SAME | housing demand = their sales | days-weeks | DLF, GODREJPROP, OBEROIRLTY, LODHA | ULTRACEMCO, AMBUJACEM, SHREECEM, DALBHARAT, ASTRAL, POLYCAB, ASIANPAINT | [V] |
| L12 | PSE / defence | PSU power, capital goods | SAME | one PSU / capex theme | same day | HAL, BEL, BHEL | NTPC, POWERGRID, LT | [V] |
| L13 | High-beta (METAL, PSU BANK, REALTY, PSE) | Defensives (FMCG, PHARMA, often IT) | OPPOSITE on risk-off days | money hides in defensives | same day | SAIL, SBIN, DLF, HAL | HINDUNILVR, NESTLEIND, ITC, SUNPHARMA, CIPLA, TCS | [E] |
| L14 | IT | BANK | sometimes OPPOSITE (weak rupee / strong US tech days) | rupee helps IT, FII selling hurts banks | same day | TCS, INFY, HCLTECH, WIPRO, TECHM, LTIM | HDFCBANK, ICICIBANK | [E] |
| L15 | Market mood / turnover | Capital-market shares | SAME | trading volumes = their revenue | same day to days | NIFTY, BANKNIFTY | BSE, CDSL, ANGELONE, MCX, KFINTECH | [V] |
| L16 | Sector leader after 3+ strong days | Laggard in the same theme | catch-up (laggard rises) | profit-taking moves into the cheaper peer | 1-5 days | e.g. private banks | e.g. PSU banks | [E] |
| L17 | Any sector after an extreme day | Same sector next day | slight mean reversion more often than follow-through | quant's view of NSE data | next day | - | - | [E] |

Notes. Most daily sector moves are just NIFTY beta: judge sector-vs-sector only after subtracting NIFTY. If two sectors look
linked, first check whether one driver moves both (crude falling lifts autos AND hurts ONGC: that is crude, not "energy down,
autos up"). TMPV / TMCV history starts at the Tata Motors demerger (Oct-Nov 2025): join the old TATAMOTORS series carefully.

## B. SECTOR-TO-DRIVER LINKS

Sign: (+) sector rises when the driver rises; (-) sector falls when the driver rises.

| Sector (NSE index / basket) | Drivers and sign | Lag | How the desk reads it |
|---|---|---|---|
| NIFTY AUTO | Brent (-), steel / aluminium / copper / PGM (-, slow), RBI rate cut (+), monsoon and rural demand (+), GST rates (cut +), 1st-of-month sales (+/-) | crude same day; metals 1-2 quarters; sales same day | crude fall = same-day CE idea [V: +2.8% day, Upstox]; metals = background tilt only; month-start sales and results are the big single-day triggers |
| NIFTY METAL | LME copper / aluminium, China steel / iron ore futures (+), China stimulus (+), DXY (-), Chinese steel exports (-), safeguard duty (+), risk-off (-) | overnight -> open | read LME and China at 07:15; the gap carries most of it; confirm at 09:20 from the whole sector |
| NIFTY BANK / PSU BANK | US 10y and DXY (- via FII selling), RBI cut (mixed: volume up, margin down), RBI rule changes, bank credit data, FII cash | policy day + 2-3 days | RBI and FII days only; PSU vs private is weeks of rotation, not a next-day trade |
| NIFTY FIN SERVICE / NBFC | India 10y yield (-), RBI cut (+), RBI risk-weight rules (Nov 2023 hike hit BAJFINANCE, SBICARD [V]), auto volumes (+) | same day to days | rate-sensitive; regulator orders are E12 policy shocks |
| NIFTY IT | overnight Nasdaq and US tech (+), INFY / WIPRO ADRs (+), USDINR up (+), Accenture / Cognizant results (read-across) | next open, 0-1 day | gap is set overnight; trade only if it holds above VWAP after 09:20 |
| NIFTY PHARMA | USDINR up (+), US FDA actions (stock-specific), risk-off (+, defensive) | same day | defensive on falling markets; FDA news is per share |
| NIFTY FMCG | risk-off (+), palm oil / copra (-), monsoon (+), rural demand | same day; inputs weeks | defensive leg of L13 |
| OIL & GAS / ENERGY | Brent: upstream ONGC, OIL (+); OMCs BPCL, HINDPETRO, IOC (-); fuel price policy | same day | the fastest, clearest link; always list both sides |
| NIFTY REALTY | RBI cut / yields down (+), FII mood, housing sales | policy day + days | high beta; falls hardest on risk-off |
| Cement | coal / petcoke (-), government capex and budget (+), monsoon months Jul-Sep (-) | weeks | results read-across from ULTRACEMCO |
| Capital goods / PSE / defence | budget capex (+), defence orders (+), metals (-, slow), PSU theme | event day | Budget (1 Feb) and order news |
| Cables / durables | copper / aluminium (both: revenue and cost), summer (+ VOLTAS, BLUESTARCO), housing (+) | same day for copper | copper slump = PE cables (BUILD_PLAN 1.7) |
| Paints / tyres / aviation | Brent (-), INR weak (-), natural rubber (- tyres) | same day | crude-fall CE list; crude-spike PE list |
| Gold-loan / jewellers | gold (+ MUTHOOTFIN, MANAPPURAM); TITAN, KALYANKJIL mixed (inventory gain vs weaker demand) | same day to 1 week | quote the share's gold beta from the dossier |
| Capital markets | market turnover (+), SEBI F&O rules (Nov 2024 curbs hit brokers [V]) | same day | regulator days are E12 shocks |
| Telecom | tariff hikes (+ BHARTIARTL, IDEA, INDUSTOWER), AGR / court news | event day | event-driven only |
| Agro / rural (tractors, 2-wheelers, agrochem) | IMD forecast and rainfall (+): M&M, ESCORTS, HEROMOTOCO, PIIND, UPL, DABUR | weeks-months; reacts to the forecast itself | Apr-Jun forecast days, Jun-Sep rainfall updates |

Calendar triggers (dates move with holidays): 1st = auto sales, GST, PMI; ~12th = CPI, IIP; fortnightly bank credit; results
seasons Jan / Apr / Jul / Oct (TCS opens; read-across HDFCBANK -> private banks, MARUTI -> auto parts, ULTRACEMCO -> cement);
festive Sep-Nov (autos, durables, TITAN); weddings Nov-Feb (TITAN); MSCI rebalances Feb / May / Aug / Nov; expiry days. [V]

## C. THE HISTORY DATABASE AND THE PROOF RULE

**C1. What to collect (daily, 10 years where it exists, at least 5).** Kite historical first. Anything Kite lacks is bought only
with the trader's yes, item by item, with the price shown first (same rule as BUILD_PLAN 1.7).

| Series | Source | Cost |
|---|---|---|
| OHLC of every NSE sector index (AUTO, METAL, BANK, PSU BANK, IT, PHARMA, FMCG, ENERGY, OIL & GAS, REALTY, MEDIA, FIN SERVICE, PSE, CPSE, CONSUMER DURABLES), NIFTY, BANKNIFTY, India VIX | Kite historical; niftyindices.com and NSE bhavcopy as check | have |
| OHLC + volume of every F&O share, plus GIR's own whole-sector baskets (GIR_SPEC 1.2) | Kite historical | have |
| Minute data for the open (09:15-10:00) of indices and F&O shares, so the open-to-15:10 leg can be measured | Kite (limited depth) | have; older years paid if needed |
| Futures OI, expired options / IV history | Kite (recent); vendor for older | PAID-NEW, ask first |
| Brent, LME copper / aluminium, China steel / iron ore futures, DXY, US 10y, India 10y, Nasdaq, S&P, INFY / WIPRO ADRs, gold, USDINR | MCX / CDS on Kite where listed; free official series; vendor for the rest | mostly free; ask before paying |
| FII / DII cash flows | NSE daily files | free |
| Event tags: RBI, budget, GST council, results dates, auto sales days, expiry, index rebalances, regulator orders, holidays | own calendar + news archive | free / news archive paid, ask first |

For every day and every series keep three returns: overnight gap (prev close -> 09:15), **open -> 15:10 (the only tradable leg
for him)**, close -> close. Keep sector returns both raw and minus NIFTY. Tag each day with its trigger: similar triggers repeat;
plain sector moves do not.

**C2. How each link is measured.**
1. Same-day correlation, rolling 60-day and 250-day: average, spread, how often the sign flips. A link whose sign flips often is
   not a link.
2. Lead-lag: sector B's open -> 15:10 return on D+1 against sector A's return on D, controlling for NIFTY on D, B's own return on
   D and the overnight driver moves. Robust t-stats. The last 2 years are held out and used only to test.
3. Conditional hit rate (the "similar incidents" table): when A moves at least 2% (or more than 2 standard deviations of its
   60-day volatility), what does B do on D+1? Record N events, hit rate, average and median move, worst case, and B's normal
   up-day rate. Written as: "metals fell >2% on D, autos rose on D+1 in N of M cases."
4. Driver control: regress each sector on NIFTY, Brent, USDINR, LME, yields; correlate what is left. If METAL vs AUTO vanishes,
   the real link is crude or China, and the desk names the driver, not the sector.
5. Regimes: India VIX <14 / 14-20 / >20, crude trend, FII buying vs selling, before / after COVID, the 2026 crude-and-war swings.
   A link proven in only one regime is used only in that regime.

**C3. The proof rule (binding).** A link may be a REASON in a CE / PE call only when ALL of these hold:
- at least 30 events (not clustered: March 2020 counts once per week, not per day);
- hit rate at least 58% AND at least 8 points above B's normal rate;
- average open -> 15:10 move of the chosen F&O share at least 1.2% (desk estimate of what an ATM option needs to beat theta and
  the spread; re-check with real option data once collected);
- holds in the first half, the second half and the last 2 years separately;
- survives the driver control and a false-discovery correction (about 1,300 pair tests are run; about 65 "work" by luck);
- results days, monthly-sales days and stock-specific news are removed from the event list.
Status ladder: PROPOSED -> PROVEN -> LIVE (half size, probation of 20 live trades) -> DROPPED if the live hit rate falls to the
normal rate. Every call that uses a link quotes the proof, e.g.: **"Link L05 crude -> OMC: Brent -3% days, BPCL up open -> 15:10
in 41 of 62 (66%, normal 51%), avg +1.6%, last 2 yrs 15 of 22. Closest analogue: <date>."** No proof line = the link is not used.

**C4. Re-testing.** Nightly: add the day to every table and update the counts. Monthly: full re-test of every link, status
changes reported in the evening note. Quarterly: regime review and threshold review. Any change of index constituents,
demerger or lot rule triggers a re-test of the links it touches.

## D. HOW THE DESK USES IT EVERY DAY

**19:45 - TOMORROW'S OPTION WATCH (part of the 19:45 note, BUILD_PLAN 1.7 and E2).** For every sector that moved today (|move
minus NIFTY| at least 1.5%, or a driver past its threshold), the second-order analyst writes one block:
- what moved and the trigger (or "no trigger found");
- every linked sector from tables A and B, which way, the lag, and BOTH sides (losers PE, winners CE);
- the past analogue and hit rate from C3, with the status: PROVEN (with the proof line) or **IDEA - NOT PROVEN** (no hit rate);
- slow links (L01, L02) only as "background tilt, weeks", never as tomorrow's trade;
- the F&O shares on each side with role (leader / laggard), strikes and the open trigger that would confirm.
Example (what 18 Nov should have said): "METAL -2% (copper, aluminium, steel down). Linked: AUTO CE watch - MARUTI, ASHOKLEY,
TVSMOTOR, M&M, HEROMOTOCO, EICHERMOT; PE watch cables POLYCAB, KEI and metals. Link L01 next-day: IDEA - NOT PROVEN (cost link
is slow; on risk-off days autos fall with metals). Confirm at the open."

**07:15 and 09:08.** Overnight drivers (LME, Brent, Nasdaq, USDINR, China, GIFT NIFTY) confirm or cancel each watch line. If the
driver that made the link has reversed overnight, the line is cancelled.

**Live engine (09:15-10:00).** It watches the linked sector, not just the sector that moved. Confirmation (E3, never before
09:20): the WHOLE linked sector holds above VWAP (below for PE), outperforms NIFTY over the first 15-30 minutes, and breadth in
the basket agrees. A big gap that has already used up the move is "gap captured - no trade". Only then GET READY / GO NOW, exit
by 15:10, nothing carried overnight (theta and IV fall).

**15:45 audit.** Each watch line is scored: link worked / failed / cancelled correctly, and the result is added to the database.
A sector move that a link in table A or B could have predicted, but the 19:45 note did not name, is a MISS.

## E. REPLAY TESTS

| # | Case | Dates | What GIR must do | Pass test |
|---|---|---|---|---|
| E1 | METAL down -> AUTO up | 18 -> 19 Nov 2026. [T] NIFTY AUTO about +3%, MARUTI about +6% (BUILD_PLAN 4.2 also lists ASHOKLEY +9%). Not found in news searches: check against NSE closes, and check for an own trigger (sales, GST, crude, broker upgrade) | 18 Nov 19:45 note names AUTO CE watch and cables / metals PE watch, with L01 marked IDEA - NOT PROVEN; 19 Nov engine confirms AUTO from the whole sector by 09:20-09:45 | watch line present on 18 Nov; confirmation logic fires on 19 Nov minute data; the database reports how often "METAL < -2% -> AUTO up D+1" happened in 10 years, and whether 19 Nov was the link or its own news |
| E2 | Crude falls -> AUTO, paints, OMCs up; ONGC down | 2026 day "Nifty Auto +2.8% as oil drops to pre-war level" (Upstox article 195961) - find the date. Older: 9 Mar 2022, Brent fell about 13% from its peak [verify] | Brent move past threshold at 07:15 -> CE list autos, paints, OMCs, tyres, INDIGO; PE list ONGC, OIL | both sides listed before 09:15; AUTO and OMC baskets confirm by 09:30; ONGC PE line present |
| E3 | Crude spike -> METAL and AUTO fall TOGETHER (the trap) | 2026 day crude went above $100, 5paisa "auto and metal stocks fall up to 4.5%" - find the date | must NOT write "metals down -> autos CE tomorrow" as a trade when the driver is risk-off / crude | no AUTO CE GO NOW on that day or the next unless the whole AUTO sector confirms; the note names crude as the driver |
| E4 | China stimulus -> METAL up hard; slow effect on AUTO | 24-26 Sep 2024 [V event; verify index moves] | 07:15 METAL CE watch (TATASTEEL, JSWSTEEL, HINDALCO, VEDL, NMDC); AUTO only as "background tilt, weeks" | METAL confirmed same day; database records AUTO vs NIFTY over the next 1-4 weeks to test L01's slow form |
| E5 | GST cut -> AUTO, auto parts, vehicle financiers up | Sept 2025 GST Council decision (small cars 28% -> 18%) [V event]; find the first rally day and sizes | E12 policy shock -> AUTO CE plus linked L07 parts and L08 financiers on the watch | linked sectors named the same evening; MARUTI, M&M, EICHERMOT, MOTHERSON, BAJFINANCE in the lists |

Each replay is added to BUILD_PLAN section 4 tests once the dates are fixed from the history database.

## Sources
- 5paisa, steel ~70% of auto raw materials: https://5paisa.com/news/lower-steel-prices-lend-a-helping-hand-to-automobiles
- Business Standard, aluminium / copper / PGM costs: https://www.business-standard.com/industry/auto/rising-input-costs-squeeze-margins-auto-component-makers-125122600580_1.html
- Upstox, Nifty Auto +2.8% as oil drops: https://upstox.com/news/market-news/stocks/nifty-auto-jumps-2-8-maruti-suzuki-uno-minda-mahindra-other-auto-stocks-lead-gains-as-oil-drops-to-pre-war-level/article-195961/
- 5paisa, autos and metals fall together on crude: https://www.5paisa.com/news/auto-and-metal-stocks-fall-up-to-45-as-crude-oil-surge-weighs-on-market
- Kotak Neo, auto rally of 5 Nov 2026: https://www.kotakneo.com/news/stocks/auto-stocks-rally-ashok-leyland-maruti-tata-motors-m-m/
- Business Standard, autos at highs after GST (Sep 2025): https://www.business-standard.com/markets/news/what-s-driving-maruti-suzuki-eicher-motors-ashok-leland-to-hit-new-highs-125092300193_1.html
- Mukherjee & Misra (2005), NSE lead-lag: https://econwpa.ub.uni-muenchen.de/econ-wp/fin/papers/0504/0504020.pdf
- Diebold-Yilmaz spillovers across 16 NSE sectors: DOI 10.1080/10293523.2024.2344939
- Data: niftyindices.com historical data, NSE bhavcopy, India VIX history, Kite historical API.
