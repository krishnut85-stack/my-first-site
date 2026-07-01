# Elon Code — Strategy Research Report
*What actually works for systematic/algo trading, filtered to the Elon code's reality
(Indian markets, NRO-legal, backtestable with Kite + Trendlyne). Compiled July 2026.*

## Headline
Across a century of global data and India-specific studies, **momentum is the single
most robust, most-documented tradeable edge** — the *opposite* of the dip-buying
(mean-reversion) we tested and rejected. Our own four backtests independently
re-discovered a known fact: **mean-reversion dies in a trending/bull market, which is
exactly when momentum pays.** The 2024–26 Indian melt-up is a momentum regime. We were
digging the wrong way; the evidence says turn around.

## Evidence, ranked by robustness

### 1. Trend-following / time-series (absolute) momentum — most bulletproof
AQR's *A Century of Evidence* (67 markets, 1880–2016): time-series momentum delivered
**positive returns in every decade since 1880** and made money in **8 of the 10 worst
crises** for a 60/40 portfolio. This is the "is it above its long-term trend?" logic
(the 200-DMA overlay). Most crisis-resilient edge known.

### 2. Cross-sectional & sector momentum — strong, and proven in India
- Nifty-500 study (2015–2024): winners keep winning, losers keep lagging; effect
  strengthens at longer horizons. Momentum robust in India 2000–2013 across industries.
  QED Capital's "Momentum in India" shows long-only momentum alpha over the Nifty 500.
- **Sector rotation** = momentum applied to sectors: rank the Nifty sector indices by
  relative strength + momentum, hold the top 3–4, rotate as leadership changes.
  "Simple but profitable, and profitable *even after* transaction costs." Popular India
  framework: **RRG** (RS-Ratio + RS-Momentum; leading/improving/weakening/lagging).

### 3. Dual Momentum (Gary Antonacci) — the smart combination, with a caveat
Relative momentum (pick the strongest) + absolute momentum (hold only if it also beats
cash / its own trend, else go to cash). GEM showed **~2× Sharpe, ~30% lower drawdowns**
vs buy-and-hold. **Caveat (real):** fragile to the single 12-month lookback — results
swing by lookback choice. Fix: **blend 3/6/12-month lookbacks.**

### 4. The failure mode to design around: momentum crashes
Cross-sectional momentum crashed **−73% in 3 months in 2009** (short the losers right as
they rebounded). Proven protections: **(a) volatility targeting** (Barroso & Santa-Clara:
constant ~12% vol nearly doubled Sharpe, killed crashes); **(b) an absolute-momentum /
trend filter** (long only above trend). Time-series momentum is inherently more
crash-resistant than cross-sectional. → Our design uses a **trend gate + vol-scaling**.

### 5. Mean-reversion (Connors RSI2) — real but decayed, regime-bound
Still an equity edge, but weakened by HFT competition and **fails in trending markets** —
exactly our backtest result (great in choppy 2023, dead in 2024–26). Keep as a
**choppy-regime tool**, not the core.

### 6. Value / quality / low-vol — genuine but slow
Long-horizon factors (via Trendlyne fundamentals), can suffer multi-year droughts.
Secondary sleeve later, not the first build.

## Build shortlist (ranked) — all NRO-legal via sector ETFs / CNC
1. **🏆 Dual-momentum sector rotation** — build first
2. **Broad-index trend-following** (long Nifty-ETF above trend, else cash) — robust core / crash guard
3. **Long-only cross-sectional stock momentum** (Nifty 500, trend-filtered, vol-scaled)

### Lead design (dual-momentum sector rotation)
- **Universe:** Nifty sector + broad indices (`indices.txt`).
- **Ranking signal:** blended momentum = mean of 3/6/12-month returns (kills single-lookback fragility).
- **Absolute filter (crash guard):** hold a sector only if its 12-month return > 0 AND broad
  Nifty > 200-DMA; else that slot → cash. Bear market = sit out.
- **Holdings:** top 2–3 sectors, equal-weight (optionally vol-scaled to ~12%).
- **Rebalance:** monthly (low turnover = low cost — what killed the earlier churny versions).
- **Exits:** rotation-driven (drop when it leaves top-N) + trend gate; optional catastrophic stop. No intraday.
- **Benchmark to beat:** buy-and-hold Nifty (Sharpe + drawdown), judged out-of-sample.

## Honest caveat
Momentum is robust, not magic: multi-year droughts and sharp crashes happen (that's what the
trend gate + vol-scaling defend against). Any strategy still must pass our own out-of-sample
backtest + Monte Carlo before real money.

## Sources
- AQR — A Century of Evidence on Trend-Following: https://www.aqr.com/Insights/Research/Journal-Article/A-Century-of-Evidence-on-Trend-Following-Investing
- Quantpedia — Sector Momentum Rotational System: https://quantpedia.com/strategies/sector-momentum-rotational-system
- QED Capital — Momentum in India: https://qedcap.com/ast/uploads/2022/03/Momentum-In-India-Sep2021.pdf
- Antonacci — Dual/Absolute Momentum: https://www.optimalmomentum.com/dual-relative-absolute-momentum/
- ThinkNewfound — Fragility Case Study (Dual Momentum GEM): https://blog.thinknewfound.com/2019/01/fragility-case-study-dual-momentum-gem/
- QuantPedia — Three Methods to Fix Momentum Crashes: https://quantpedia.com/three-methods-to-fix-momentum-crashes/
- Alpha Architect — Risk of Momentum Crashes: https://alphaarchitect.com/risk-of-momentum-crashes/
- QuantifiedStrategies — Connors RSI2: https://www.quantifiedstrategies.com/rsi-2-strategy/
- RRG Sector Rotation India (GitHub): https://github.com/AdroitAnandAI/RRG-Sector-Rotation-India
