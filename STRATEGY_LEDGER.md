# GARUDA STRATEGY LEDGER

The complete census of every strategy idea this project has examined —
what was checked, what the evidence said, and what is still in the queue.
Nothing is decided "fast": an idea only moves UP this ledger by passing a
backtest with untouched TEST data, and only becomes a book after that.
An idea only moves OUT by being honestly falsified — and it stays listed,
so we never re-argue it from memory.

Updated: 2026-07-15

---

## ✅ VALIDATED AND LIVE — the 11 books + 1 guest (paper only)

| # | Strategy | How it was proven | Status |
|---|----------|-------------------|--------|
| 1 | Smallcap RSI-2 dip, patient exit (25% trail/180d) | DIP EXAM + DIP RACE (₹27.2L vs ₹15.1L) | live book |
| 2 | Microcap RSI-2 dip, quick exit | strategy showdown (70% win, PF 2.14) | live book |
| 3 | Next50 20-day breakout + 15% trail | strategy showdown | live book |
| 4 | Strength swing (RSI-14 55–70 + 200-DMA) | 10-strategy showdown (+5.94%/t) | live book |
| 5 | Momentum leaders (3-mo +25%, 20% trail) | momentum showdown (+7.80%/t) | live book |
| 6 | Scale-in average-down (Connors TPS) | showdown (73% win, PF 3.39) | live book |
| 7 | 52-week-high breakout | DOUBLE validated (LAB + 1056-combo grid, TEST +1.92%/t) | live book |
| 8 | Crash bounce (-8% week above 50-DMA) | DISCOVER + exit sweep + rupee sim (+41.8% CAGR) | live book |
| 9 | CHAKRA monthly top-20 momentum rotation, 189d | tournament winner + CHAKRA EXAM (TEST +19.3%) | live book |
| 10 | QMOM annual quality+momentum rotation | SCREEN LAB winner (4/4 years, avg spread +19.5%/yr) | live book — forward trial to July 2027 |
| 11 | Nifty Iron Condor (weekly options) | modelled premium, defined risk | live book |
| 12 | Swaminatha — exchange-filing news trades | Mayura's record (separate bot) | read-only tab |

## 🏅 VALIDATED BUT NOT USED (kept on the shelf, not forgotten)

| Strategy | Evidence | Why shelved |
|----------|----------|-------------|
| Turn-of-month (SANKRANTI) | +0.41%/t on TEST | edge real but small; seat went to CHAKRA |
| Quality overlay as entry filter | +2%/yr (smallcaps), +4.8%/yr at the 40% bar | needs its own gauntlet before touching the dip books |
| TURNAROUND screen (loss→profit) | 3/3 years, +4.7%/yr, 83% win, ~17 names | thin cohorts; candidate for a small satellite study |
| ACCEL screen (profit growth accelerating) | 3/3 years, +9.4%/yr | strongest untried upgrade: the QUARTERLY version (queue #1) |

## ❌ HONESTLY FALSIFIED (checked and killed by data — never re-argued from memory)

| Strategy | Where it died |
|----------|---------------|
| Volatility squeeze | falsified 4 separate times (LAB + DISCOVER) |
| SARATHI breadth/regime gate on the fleet | failed its backtest outright |
| CONVICTION panic-depth position sizing | tournament loser |
| TRIVENI signal-confluence | tournament loser |
| VIJAYA hot-hand engine switching | tournament loser |
| EKALAVYA per-stock self-learner | tournament loser |
| Leader pullback (buy leaders' dips) | LAB verdict negative |
| Quick-exit mean reversion (RSI-85/30d) in current regime | DIP EXAM: negative on unseen data |
| Multibagger price precursors (100%/70% CAGR hunts) | train 28–42% vs test 3–8% — regime, not signal |
| External breakout framework v1 | 0.57% CAGR, starved (0.45 avg positions) |
| External breakout v2 (loosened) | 9.35% CAGR vs 24.6% B&H — deployment fixed, still lost |
| Minervini-style breakout entries (this window) | LAB study: stops ate it |
| Long-horizon CAGR ranking (1y/2y/3y "buy the CAGR leaders") | CAGR EXAM: TRAIN loved it, TEST killed it (1y: −7.1%) |
| STEADY15 consistency screen | 1/2 years, +1.2%/yr — noise |
| Rebalanced multi-book blends beating CHAKRA solo | combo study: best blend matched, none beat |
| Buying the morning's top gainers / movers | MOVERS lift study weak + user's own observation |
| Buying Instagram/finfluencer tips | not testable AND structurally last-in-line — treated as exit liquidity, not entry signal |

## 🔬 EXAMS BUILT, AWAITING THEIR RUN (on the droplet now)

| Strategy | Exam | Command |
|----------|------|---------|
| LOWVOL — low-volatility anomaly (boring beats wild) | lab_edges | `python3 -m garuda.lab_edges --csv strength_history.csv --lists smallcap_list.csv micro.csv next50_list.csv --mcap marketcap.csv` |
| LEADLAG — industry giant ignites → buy the siblings | lab_edges | same command (both print together) |

## 📋 THE QUEUE — ideas identified, not yet checked (in order)

1. **Quarterly earnings hunt** (ACCEL every quarter, hold 3 months) — needs the
   `qtr_wide1-6.csv` Trendlyne export (Net Profit Qtr + 1–7 Qtr Ago, Revenue Qtr + history).
2. **Weekly vs monthly CHAKRA cadence exam** — data already on droplet; build next.
3. **NSE announcements EVENT radar** (order wins / expansions, same-day) — needs the
   feed probe: `curl -s -A "Mozilla/5.0" "https://nsearchives.nseindia.com/content/RSS/Online_announcements.xml" | head -40`
4. **Volume-confirmed breakout** — needs volume history (yfinance guest script).
5. **Sector-relative crash** (stock panics, its industry doesn't) — refinement of book #8.
6. **Quality filter gauntlet** on the smallcap/microcap books (from the shelf above).
7. **Survivor-free cross-validation** of QMOM/CHAKRA at backtestindia.com (18y, delisted stocks included).
8. **Index-rebalance effect** — parked: historical constituent-change data is hard to get honestly.

## ⛔ NOT CHECKABLE (no honest data exists — will not pretend)

FII/DII flow strategies · delivery-% history · broker/DVM scores in the past ·
Instagram/Telegram tip performance · anything needing point-in-time data nobody kept.

---

**House rules that govern this ledger**
1. Backtest before building. 2. TRAIN chooses, untouched TEST judges.
3. Thin cohorts never carry a headline. 4. Survivorship: spreads honest, absolutes flattered.
5. A falsified idea stays listed. 6. A validated idea earns paper first, always.
