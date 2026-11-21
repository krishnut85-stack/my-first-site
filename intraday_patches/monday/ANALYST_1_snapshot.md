# ANALYST step 1 - the DESK SNAPSHOT (v2/analyst/snapshot.py) - 20 Nov 2026 evening

Built by code only. One function for the live store and for replay frames: `build(store, now, ctx)` + `render(snap)`.
Every input is cut at `now` (Fact `src_ts` / row time <= now; a Fact from after `now` is never used). Stale or missing inputs are listed
under NOT SEEING by name, never used quietly.

## What it holds (ANALYST.md 2)
- MARKET: NIFTY / BANKNIFTY / FINNIFTY / MIDCPNIFTY / SENSEX level, % and VWAP side, VIX, F&O breadth, FII / DII cash with its date, FII index
  futures, PCR, expiry dates, world drivers with their own time and state (GIFT, Nasdaq futures, SOX, US10y, USDINR, Brent, gold, silver,
  copper, aluminium, Hang Seng).
- SECTORS: whole-sector % (R49, sec.board), % from the open, 15-min %, engine state + since, breadth (all listed shares), money flow
  (futures build-up count LB / SC / SB / LU of its F&O shares), 3 leaders and 2 laggards, the board's reason line.
- TOP MOVERS each way (15): % and % from open, RVOL, futures build-up and OI %, VWAP side, daily RSI and zone (EXTREME >= 80,
  overbought, oversold, OVERSOLD-DEEP) - RSI from the sector board, else engine daily.levels (sessions before today only).
- NEW KNOWLEDGE since the last look: news.list, news.filings, ext.recent (outside sources), tv.calls / tvcalls.jsonl, the tiered news
  reader (newsread.jsonl, weight >= 2), newsmap themes; deduplicated by headline; each tagged NEW / REPEAT / EARLIER with its mapped
  F&O shares, side, weight, source, verified or not. Ranked NEW first, then weight.
- PREDICTION LOOP candidates (C1-C4: the latest version made before `now`) - labelled INPUT, not the answer.
- THESIS BOOK (the head's open ideas), DESK BOARD (latest card per seat), HIS TRADES AND READS, RISK LEFT (trades n of 3, lock room,
  lock, day P&L, BUY NOW used n of 4, ban list).
- Evidence ids in [brackets] (MKT, SEC:, MV:, K:, P:, T:, C:, POS:, R:, DRV:) - the head must cite them; the validator rejects any other id.

## Proof
- Live store at 13:19 IST (after the close): built in 2387 ms, 18821 chars, ~5228 tokens (target < 6,000).
  Knowledge read: 918 items, 108 NEW in the last hour.
- Unit tests v2/analyst/tests/test_analyst.py: 10 pass (point in time - a news row and an index Fact from after `now` never show; a stale
  quote is left out of the movers and named; NEW / REPEAT / EARLIER; missing keys named; live and replay text identical except the mode word;
  under the token target).
- Replay frames: the same function is called by the replay harness (step 5) on the player's store.

## Sample (live store, his trades left out of this file; knowledge cut to 8 lines)
```
DESK SNAPSHOT S:dbe3d7b5db · 2026-11-20 18:49 IST · phase CLOSED (after hours) · mode live
## MARKET [MKT]
  NIFTY 25800.6 (+1.12%, above VWAP) · BANKNIFTY 64635.2 (+2.49%, above VWAP) · FINNIFTY 28871.2 (+2.02%, n/k VWAP) · MIDCPNIFTY 14305.15 (+0.70%, n/k VWAP) · SENSEX 83919.71 (+1.08%, n/k VWAP)
  VIX 17.33 (+7.57%)
  breadth 133 up / 85 down of 218 F&O shares
  FII cash 10308.0 cr (20-Nov-2026)
  DII cash -4860.0 cr (20-Nov-2026)
  FII index futures net -68247.0 contracts (change 2423.0, 2026-11-19)
  PCR nifty 1.18, banknifty 0.93
  expiry: current 2026-11-23 (1 sessions left), next 2026-12-29
  world [DRV:*]: GIFT NIFTY +0.19% (18:37, LIVE) · Nasdaq futures -1.57% (15:29, LATE) · chip index (SOX) -2.41% (15:29, LATE) · US 10-yr yield -0.28% (15:29, LATE) · the dollar (USD-INR) -0.66% (15:29, LATE) · crude (Brent) -1.83% (15:29, LATE) · gold -3.01% (15:29, LATE) · silver -4.74% (15:29, LATE) · copper -1.44% (15:29, LATE) · aluminium +0.07% (15:29, LATE) · Hang Seng (China) -3.79% (15:29, LATE)
## SECTORS (whole-sector %, best and worst first)
  [SEC:hospitals & diagnostics] +3.68% day (+2.95% from open, 15m +0.00) · CONFIRMED since 14:51 · breadth 14/15 up (all listed) · futures LB 3 SC 0 SB 0 LU 0 · lead APOLLOHOSP +5.29, MAXHEALTH +3.88, FORTIS +1.87 · lag - · news: Fortis Healthcare Sees Sharp Open Interest Surge Amid Mixed Market Signals · long build-up in 3 of 3
  [SEC:jewellers & gold loans] -2.12% day (+1.25% from open, 15m n/k) · INCOMPLETE since 15:15 · breadth 0/5 up (all listed) · futures LB 0 SC 0 SB 0 LU 0 · lead - · lag - · news: Manappuram Finance Targets 25%-30% Gold AUM Growth as Consolidated AUM Reaches ₹73,303 Crore · long build-up in 0 
  [SEC:realty] +1.94% day (+2.50% from open, 15m +0.00) · INCOMPLETE since 15:29 · breadth 11/17 up (all listed) · futures LB 6 SC 0 SB 0 LU 0 · lead GODREJPROP +2.62, DLF +2.21, PHOENIXLTD +2.14 · lag LODHA +1.33, PRESTIGE +1.51 · news: MOFSL On Lodha Developers | Shivangi Sarda, Analyst – Equity Derivatives & Technicals, Broking & Distribution. · l
  [SEC:banks] +1.90% day (+2.59% from open, 15m +0.00) · CONFIRMED since 12:29 · breadth 27/34 up (all listed) · futures LB 18 SC 0 SB 4 LU 0 · lead INDUSINDBK +8.59, CUB +6.25, AXISBANK +4.72 · lag KARURVYSYA -1.82, UJJIVANSFB -1.44 · news: HDFC Bank surges 1.6% as banking stocks rally to fresh highs · long build-up in 18 of 22
  [SEC:oil marketers, paints, airlines] +1.75% day (+2.13% from open, 15m n/k) · INCOMPLETE since 15:29 · breadth 6/7 up (all listed) · futures LB 6 SC 0 SB 0 LU 0 · lead PIDILITIND +2.50, INDIGO +2.06, BPCL +1.95 · lag ASIANPAINT +0.51, HINDPETRO +1.63 · driver: crude (Brent) -1.8% · news: Crude oil futures gain on reports of Houthi attack in Riyadh · long build-up in 6 of
  [SEC:insurance] +1.71% day (+1.84% from open, 15m +0.00) · CONFIRMED since 15:28 · breadth 8/12 up (all listed) · futures LB 7 SC 0 SB 0 LU 0 · lead ICICIGI +2.84, MFSL +2.58, HDFCLIFE +2.01 · lag BAJAJFINSV +0.37, SBILIFE +1.21 · news: ICICI Lombard General Insurance Company up 2.52% on Thursday · long build-up in 7 of 7
  [SEC:it] +1.48% day (+2.09% from open, 15m +0.00) · INCOMPLETE since 15:29 · breadth 22/39 up (all listed) · futures LB 11 SC 0 SB 2 LU 0 · lead PERSISTENT +4.15, TATAELXSI +3.36, MPHASIS +2.72 · lag OFSS -0.72, KPITTECH -0.67 · news: Nifty IT Jumps 2.7% as TCS, Tech Mahindra and HCL Tech Gain; Indian IT Stocks Buck Global AI Sell-Off · long build
  [SEC:cement & materials] +1.26% day (+1.37% from open, 15m +0.00) · INCOMPLETE since 15:29 · breadth 11/12 up (all listed) · futures LB 3 SC 0 SB 1 LU 0 · lead ULTRACEMCO +3.02, SHREECEM +1.43, AMBUJACEM +0.81 · lag GRASIM -0.24, AMBUJACEM +0.81 · driver: crude (Brent) -1.8% · news: Ambuja Cements Share Price: Jefferies sees 20% upside on volume recovery and cost cu
  [SEC:electronics & hardware] +1.01% day (+1.94% from open, 15m +0.00) · INCOMPLETE since 15:15 · breadth 5/9 up (all listed) · futures LB 5 SC 1 SB 0 LU 0 · lead DATAPATTNS +2.48, PGEL +1.81, KAYNES +0.69 · lag SYRMA -0.09, DIXON +0.51 · news: Nifty Bank Stocks Rise | All NiftyBank components ex-PNB, trading in the green, Axis Bank, Federal, ICICI, & K · l
  [SEC:oil producers] -0.91% day (+0.21% from open, 15m n/k) · CONFIRMED since 14:34 · breadth 0/2 up (all listed) · futures LB 0 SC 0 SB 0 LU 0 · lead - · lag - · news: Crude oil futures gain on reports of Houthi attack in Riyadh · long build-up in 1 of 2
  ... (sectors / movers cut for this file) ...
## NEW KNOWLEDGE (read 918 items, 108 NEW since the last look; by kind broker 1, filing 208, news 263, regulator 32, results 11, theme 60, tv 241, world 102)
  [K:e8b3fb54] 18:49 NEW NEWS w3 · wires/et · shares SHRIRAMFIN,TRENT · side DOWN · Trent loses Sensex seat to Shriram Finance in index reshuffle; changes kick in December 21
  [K:13771b55] 18:46 NEW NEWS w3 · GOOGLE NEWS · shares CUMMINSIND · side UP · Cummins India Reports Strong Demand with Data Centers Contributing 30-40% of PowerGen Sales
  [K:9b5ace5e] 18:30 NEW NEWS w3 · GOOGLE NEWS · shares MUTHOOTFIN · side DOWN · Muthoot Finance Share Price Falls 5% as Gold, Silver Crash
  [K:f0a825c5] 18:12 NEW NEWS w3 · headline · shares SHRIRAMFIN,TRENT · Shriram Finance To Enter Sensex, Trent To Exit From 21 December (unverified)
  [K:fe39b263] 17:56 NEW RESULTS w3 · GOOGLE NEWS · shares CUMMINSIND · side DOWN · Cummins India releases Q2FY27 call transcript; PBT down 28.4% on costs
  [K:598c4e8d] 17:52 NEW TV w4 · TV ET NOW (speech-to-text) · side DOWN · Regime and its terror proxies have launched attacks on hundreds of commercial vessels. We're putting an end to all of this threat once and for all, and the... Will be low
  [K:60a27258] 18:47 NEW NEWS w2 · GOOGLE NEWS · shares FORTIS · side UP · Fortis Healthcare Expands Bengaluru Hospital Network
  [K:e6872da4] 18:46 NEW NEWS w2 · GOOGLE NEWS · shares DELHIVERY · side UP · Delhivery ties up with RIDEV to deploy 150 EVs for last-mile deliveries
  ...
## THESIS BOOK (your open ideas)
## HIS TRADES AND READS
## RISK LEFT: trades n/k of 3 · lock room n/k · locked None · day P&L n/k · BUY NOW used 0 of 4 · ban KAYNES
## NOT SEEING (stale or missing inputs - do not assume them)
  - pos.open: MISSING (not in the store)
  - pos.day (P&L, trades, lock room): MISSING (not in the store)
```

## Honest limits
- After hours most share / index Facts are CLOSED - the snapshot shows them with their state; in market hours they are LIVE.
- RVOL / VWAP for replays come only where the recordings have them (18 Nov has no v2 recording: Kite minute + oihist).
- RSI zone: sector board first, else daily RSI from the history file; some shares show n/k when neither exists.
- News dedup is by headline text; two feeds that word one story differently show twice (seen: the Sensex reshuffle story, 3 rows).
