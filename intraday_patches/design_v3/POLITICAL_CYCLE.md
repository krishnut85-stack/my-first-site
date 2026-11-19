# GIR - POLITICAL AND ELECTION CYCLE (policy delays and pre-election measures as chains)

Written 19 Nov 2026 for the trader's question: "They are delaying the UPI fee (MDR) until after the 2027 UP election, because
charging shopkeepers would cost votes. Look at the macro movement. This is what I want from the desk." Built from three desk
answers (political economy, policy analyst, senior trader) and LINK_BOOK B10 (#4, #11, #13) and CHAIN_OF_EVENTS row 24.
No live NSE data was used: the claude-code-kite connection was down today.

**Labels.** [V] = checked in a web source today. [E] = desk estimate or market memory. [T] = from the trader, not yet checked
against NSE data. Every chain below is PROPOSED until the history database proves it (SECTOR_LINKS part C rule).

**The short answer for the trader.**
1. Your reading fits history. Governments hold back unpopular fees and price hikes before big state polls and release them after
   the result (fuel freeze 2021-22, telecom hike after June 2024). The desk treats it as the right working rule.
2. But nobody official has said "election". NPCI's stated reasons are merchant pushback and the festive season. The election link
   is the press's and your reading. The desks do not fully agree on the 19 Nov reports: one confirmed FE / Business Standard
   stories that the fee may wait until after the 2027 polls; another found no such report dated 19 Nov. Treat the motive as
   likely, not proven.
3. What GIR must do: keep a POLICY CLOCK of every pending fee or price hike, flag it the evening before when an election falls
   inside its window, and have the PE plan ready before the "sources say" headline lands.

## A. THE PAYTM / UPI-FEE CASE AS A CHAIN

| Date | Event | PAYTM move | Label |
|---|---|---|---|
| 12 Jun 2025 | Finance Ministry on X calls UPI MDR reports "false, baseless" | -10% intraday (864), about -5.7% by midday; worst day in 16 months | [V] |
| mid-Sep 2026 | NPCI sets 0.4% MDR on UPI shop payments above Rs 2,000 from 15 Oct (cap Rs 300 reported, not confirmed) | up to +7%, 52-week high; MobiKwik up too | [V] |
| 8 Oct 2026 | Reuters: fee may slip "after retailer pushback" (to 1 Jan in some reports) | -7.6% to -10% intraday (one source: lower band 1,558.80), closed about -5% | [V] |
| 13 Oct 2026 | NPCI defers to "immediately after Diwali, date to be notified" | -7% intraday, then recovered to about 1,688; Pine Labs -4.8%, MobiKwik -4% | [V] |
| 8 Nov 2026 | Diwali. The "after Diwali" deadline passes with no date announced | - | [E] |
| 19 Nov 2026 | Reports: fee may wait until after the 2027 state elections | -6% to -9% intraday (1,890 -> about 1,730-1,756); MobiKwik about -8%, Pine Labs -4% to -5% | [V] / [T] |

**The chain.** Unpopular fee pending + deadline passes in silence + state polls inside the window -> "sources say delayed" ->
PE PAYTM (the only option-traded name; Pine Labs and MobiKwik have no options [check NSE]; PB Fintech moves weakly with it).
A firm date or notified rule -> CE PAYTM. A government denial gives the biggest single-day fall (Jun 2025).

**Why PAYTM falls more than the money says.** Of the 0.4%, issuer banks get about 0.28%, the app about 0.08%, the acquirer about
0.04% [V, splits differ]. Banks take 60-70% of a Rs 16,000-27,000 cr pool; SBI gains most (about Rs 2,000 cr a year [E]), too
small to move SBI or HDFCBANK. PAYTM's extra revenue is only about Rs 214 cr in FY27 [E]. The delay hurts the story, not profit.
The Supreme Court refused to stay the fee [V, one report], so the rule stands; only the start date moves.

**What GIR must catch and say, and when.**
- 19:45 on 18 Nov (the evening note): "PAYTM: event risk HIGH, downside. No CE." Reasons GIR could see: the post-Diwali deadline
  10 days past with no circular; three earlier delays or denials (Jun 2025, 8 Oct, 13 Oct); the share up 1,558 -> 1,890 since
  8 Oct on fee hopes (crowded buyers); UP polls due early 2027.
- 09:00 on 19 Nov: "No PAYTM / Pine Labs / MobiKwik CE today. PE plan ready if a 'sources' line appears."
- Honest limit: GIR could see the risk, not the day. Nothing public pointed to 19 Nov itself.
- Next likely headline: "rollout from April 2027" (CE), once UP has voted. Realistic start April-June 2027 [E].
- Side items: NPCI 30% share cap (deadline 31 Dec 2026, extended three times; hits unlisted PhonePe / Google Pay; another
  extension likely). Any RBI payment-aggregator licence news on PAYTM or Pine Labs is a same-day trade either way.

## B. THE ELECTION-CYCLE PLAYBOOK

**The rule.** When the Election Commission announces dates, the Model Code of Conduct (MCC) starts: no new schemes. So handouts
come 4-8 weeks BEFORE the announcement (for 2027 about mid-Dec 2026 to mid-Jan 2027 [E]). Anything that angers a big voter group
waits for counting: shopkeepers (MDR), drivers (fuel), households (LPG), farmers (cane, power), mobile users (tariffs). After the
result the delayed hikes come all at once.

| Measure | Winners (CE) | Losers (PE) | Timing | Past case |
|---|---|---|---|---|
| New fee on traders / consumers delayed | merchants (not listed) | PAYTM | before polls, on each "delay" story | UPI MDR 2025-26 [V] |
| Fuel price freeze / token cut | paints, INDIGO, city gas (only on a real cut) | HINDPETRO > BPCL > IOC | freeze before; hikes resume 2-3 weeks after result (then CE OMCs) | frozen 137 days Nov 2021-Mar 2022; result 10 Mar, hikes from 22 Mar, about Rs 10/L in 16 days [V] |
| LPG cylinder cut | - | oil companies | 1-4 months before polls | Rs 200 cut Aug 2023 [E]; petrol / diesel -Rs 2 Mar 2024 [E] |
| Cash for women / welfare | HEROMOTOCO, M&M, HINDUNILVR, DABUR, BRITANNIA (slow, weeks) | PSU banks slightly if state borrowing rises | before MCC | Ladli Behna 2023, Ladki Bahin 2024, Bihar 2025 [E] |
| Higher UP cane price | - | BALRAMCHIN (cost up) | Sep-Oct before polls | +Rs 25 Sep 2021 [E] |
| Cheap farm power / no tariff hike | - | PFC, RECLTD (low, discom risk) | before polls | [E] |
| Capex push, inaugurations in UP | LT, RVNL, IRCON, KEC, ULTRACEMCO, JKCEMENT | - | before MCC; rally often peaks on the EC press-conference day | [E] |
| MSP / PM-KISAN / fertiliser subsidy top-up | CHAMBLFERT, COROMANDEL, RCF, PARADEEP, PIIND, UPL, M&M, ESCORTS | - | before polls; usually priced in | [E] |
| Prohibition promise | - | UNITDSPR, RADICO | campaign | Bihar 2016 [E] |
| Stake sales paused, big PSU dividends | COALINDIA, ONGC, PSU banks (record date, low) | - | before polls | [E] |
| Mobile tariff hike held back | BHARTIARTL, IDEA, INDUSTOWER on the hike | IDEA on delay talk (highest beta) | hike 2-4 weeks after result | Jio +12-25% on 27 Jun 2024, 3 weeks after LS result [V] |
| Post-poll fiscal clean-up | - | HINDPETRO etc. | first budget after polls | LPG subsidy cut 3 Feb 2025: HINDPETRO -7.6% (LINK_BOOK) |
| Result: strong / weak BJP in UP | strong: PSU banks, defence, PFC, RECLTD | weak: same names, hard | counting day | LINK_BOOK B10-13 |

## C. PENDING POLITICALLY SENSITIVE POLICIES NOW (BOTH SIDES, SIGNALS TO WATCH)

| Policy | Now | Before polls | After polls | Shares | Signal to watch |
|---|---|---|---|---|---|
| UPI MDR | deferred, no date [V] | more "delay" stories -> PE | rollout April-June 2027 -> CE | PAYTM (Pine Labs, MobiKwik with it) | CAIT statements, NPCI steering-committee notes, FinMin / DFS on X, PIB Fact Check |
| Petrol / diesel | OMCs lose about Rs 12/L petrol, Rs 27/L diesel (Jefferies 13 Nov); crude basket $97 [V] | no hike, maybe token cut -> PE OMCs on "absorb" order | hike near end-Q1 2027 -> CE OMCs | HINDPETRO, BPCL, IOC; paints, INDIGO on a real cut | ministry statements, daily loss reports |
| LPG | loss about Rs 230 a cylinder, rising to Rs 309 Nov and Rs 370 Dec [V] | absorbed -> PE OMCs | hike -> CE OMCs | same | loss above Rs 300 with no hike |
| Mobile tariffs | 12-20% hikes expected; Airtel raised postpaid Oct 2026 [V] | quiet piecemeal hikes, prepaid unlikely | big prepaid hike -> CE | BHARTIARTL, IDEA, INDUSTOWER | telco statements, broker notes |
| UP power sell-off and tariff | politically hot [E] | delay | revived | PFC, RECLTD, TATAPOWER, TORNTPOWER | UP regulator orders, power-union strikes |
| Drug price caps | NPPA yearly revision in April [E] | rare pre-poll cap -> PE | normal April revision | ABBOTINDIA, GLAXO, MANKIND, TORNTPHARM | NPPA notices |
| Liquor excise | state budgets Feb-Mar; UP excise policy Feb-Mar [E] | usually unchanged | changes possible | UNITDSPR, RADICO | prohibition promises in manifestos |
| STT / capital gains | Budget 1 Feb 2027, inside MCC [E] | hike unlikely; personal tax relief likely -> CE consumption | - | PE BSE, ANGELONE, CDSL only if STT rises | budget leaks |
| MSP / fertiliser subsidy | Kharif rates due [E] | generous -> CE | - | CHAMBLFERT, COROMANDEL, RCF, PARADEEP, M&M, ESCORTS | cabinet notes |
| Real-money gaming | banned by Aug 2025 law [E] | only a court case moves it | - | NAZARA, DELTACORP | court listings |

## D. ELECTION AND POLICY CALENDAR, NEXT 18 MONTHS (goes into the Calendar page, BUILD_PLAN 3.14)

| When | Event | Impact | Label |
|---|---|---|---|
| 1 Dec 2026 - 4 Jan 2027 | Census counting in UP, Punjab, Goa, Uttarakhand | low | [V] |
| about 15 Dec 2026 | EC finishes state visits | low | [V] |
| mid-Dec 2026 - mid-Jan 2027 | handout window (before MCC) | medium: CE rural, capex | [E] |
| 31 Dec 2026 | NPCI 30% UPI share-cap deadline (likely extended again) | low | [V] |
| late Dec 2026 - Jan 2027 | EC announces dates for UP, Punjab, Uttarakhand, Goa, Manipur; MCC starts | high: handout window closes, PSU / infra rally often peaks | [V] "likely January" |
| 1 Feb 2027 | Union Budget (inside MCC): rural, welfare, capex lines | high | [E] |
| Feb-Mar 2027 | Voting (UP several phases, after board exams; others one phase each) | medium | [V] |
| 13-28 Mar 2027 | Terms end: Manipur 13, Goa 14, Punjab 16, Uttarakhand 28 Mar; UP 22 May | - | [V] |
| about 10-15 Mar 2027 | Counting (2022: 10 Mar; 2017: 11 Mar) | VERY HIGH trading day | [E] |
| late Mar - Jun 2027 | Payback window: fuel / LPG hikes, MDR rollout, telecom hike | high: CE OMCs, PAYTM, telcos | [E] |
| Feb-Mar 2027 / April 2027 | State excise policies / NPPA drug-price revision | low-medium | [E] |
| early 2027 or later | UP panchayat polls (court case; maybe after assembly vote) | low | [V] reports |
| Nov 2027 / Dec 2027 | Himachal Pradesh / Gujarat (dates differ by up to 3 weeks) | medium | [V] tables, dates [E] |
| Feb-Mar 2028 / by May 2028 | Tripura, Meghalaya, Nagaland / Karnataka | medium | [E] |
| any time | By-elections (none notified today; usually 6 months after a vacancy) | low | [V] |

## E. HOW A DESK TRADES POLITICAL NEWS

**Sources, fastest first.** (1) Trader and farmer groups (CAIT, BKU, SKM) protesting: days before a delay. (2) "Sources say" on
CNBC-TV18, ET Now, Reuters, ET, Moneycontrol, Business Standard, Mint, often 09:00-11:00; clips spread on X and the share moves
in 1-3 minutes. (3) Official word, same day to 5 days later: NPCI circular, FinMin / DFS on X, PIB, PIB Fact Check, an exchange
clarification request. (4) ECI press note with poll dates (MCC starts).

**Real or rumour - check in this order.** (a) Official document? Real. (b) Two or more outlets name the same forum and the same
new date? Probably real. (c) One channel, "sources", no date, company quiet? Rumour that may be denied. (d) Lower lows after 10:30?
Real money selling. VWAP reclaimed by 11:30? Market does not believe it. (e) Theme falls together (MobiKwik, Pine Labs with
PAYTM)? Whole-theme selling.

**Day 1 / day 2.** Day 1 falls 7-10% fast, then gets back 30-50% by the close. Day 2 bounces unless an official paper confirms
it (13 Oct pattern). Evening news gaps at the open: buy PE only on the first 15-minute low break (Delta Corp, 12 Jul 2023).
"Less bad than feared" fills the gap (11 Dec 2018). After a 6% shock day 2 often bounces 50% (4-5 Jun 2024). Delay stories fade
by day 2-3 unless made official. Intraday: take the day-1 move only.

**The PAYTM option trade (buy only, intraday).**
- Strike: ATM or 1 strike in-the-money PE. Never far out-of-the-money (IV jumps on news).
- Entry: first 5-minute close below the pre-news low and below VWAP; else the first failed bounce (lower high). Never buy a PE
  once the share is already down 5%+ and stretched.
- Stop: above the bounce high, or 30-35% of premium, whichever first. Target: -8 to -10% area. No new low by 12:30: exit.
- Reverse: no denial and no circular by 13:00, low held 30 minutes and VWAP reclaimed -> small CE scalp to 15:10.
- Day 2 CE only if the open holds above the day-1 low and nothing official by 10:00.
- Approval / start-date news -> CE, but it fades by the close if the cap or exemptions look wide.

**What to build.** (1) POLICY CLOCK (extends LINK_BOOK B10 #11): every pending fee, rule or deadline with its due date; AMBER when
the date passes with no circular; RED when an election falls inside the window; RED-AND-RING when a "sources" headline hits.
Feeds: NPCI circulars, PIB, FinMin on X, exchange clarifications, CNBC-TV18 / ET Now headline scrape, CAIT / BKU / SKM statements.
Mapping: MDR -> PAYTM, fuel / LPG -> OMCs, tariffs -> telecom, cane -> sugar, power -> PFC / RECLTD.
(2) New LINK_BOOK B10 row: "Pre-poll deferral | -> PE affected fintech, telco or OMC | same day, 1st hour | HIGH while MCC runs".
(3) Calendar page rows from section D, with the EC press-conference day and counting day marked VERY HIGH.

## F. FIVE REPLAY TESTS (must pass on the Replay page before the chain is trusted)

| # | Date(s) | Input GIR gets | GIR must say | Pass if |
|---|---|---|---|---|
| P1 | 18-19 Nov 2026 | post-Diwali deadline passed, 3 prior delays, run-up 1,558 -> 1,890, UP polls due | 19:45 on 18 Nov: "PAYTM event risk HIGH, no CE"; 19 Nov: PE plan fires on the first 5-min close below pre-news low and VWAP | warning given the evening before; PE entry before -5% |
| P2 | 8 Oct and 13 Oct 2026 | Reuters "sources" (8 Oct); NPCI official deferral (13 Oct) | 8 Oct: rumour-grade check then PE; 13 Oct: PE, then CE scalp after VWAP reclaim | day-1 PE caught; 13 Oct rebound flagged |
| P3 | 12 Jun 2025 | FinMin denial on X | "Government denial = biggest fall": PE PAYTM in the first hour | PE called within 15 minutes |
| P4 | 3 Nov 2021 - 22 Mar 2022 | excise cut, then flat pump prices while crude rose about 45%; UP result 10 Mar | freeze flagged as PE OMCs on "absorb" headlines; after 10 Mar: "hikes due" CE watch; 22 Mar hikes confirmed | CE watch issued before 22 Mar |
| P5 | 3-5 Jun 2024 (and 4 Dec 2023, 11 Dec 2018) | exit polls, result shock, bounce | 4 Jun: PE PSU / power after confirmation, not at the open; 5 Jun: bounce warning, no new PE; 11 Dec 2018: no PE in first 15 min | no PE in the first 15 minutes of a gap; day-2 bounce flagged |
