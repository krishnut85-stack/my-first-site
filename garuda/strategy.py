"""Garuda live strategy profiles — one tuned engine per universe.

The strategy showdown (9 strategies x 3 universes, costs both sides, ranked by
avg %/trade) picked a different best-fit engine per book. These profiles run the
winners:

    Smallcap  ·  RSI-2<10 dip-buy, UPTREND-FILTERED   +0.94%/trade  PF 1.85  66% win
    Microcap  ·  RSI-2<10 dip-buy, UPTREND-FILTERED   +1.34%/trade  PF 2.14  70% win
    Next 50   ·  20-day breakout + 15% trailing stop  +1.33%/trade  PF 1.23

Entry depth: the dip-depth sweep showed RSI-2<10 captures ~the same per-trade
edge as the classic <5 while taking ~5-10% more trades (and on microcap it edged
<5 outright), so both mean-reversion books buy at RSI-2 < 10.

Why not plain RSI-2 everywhere? Because plain RSI-2 is ~break-even after costs
(+0.10% micro, +0.01% small). Adding the "only buy the dip while price is above
its 200-day average" filter (use_trend) turns the same mechanics into a real
edge — it stops catching falling knives. Next 50 are large, liquid, trending
names where dip-buying matters less and riding momentum matters more, so it runs
a different engine entirely.

Sizing note: there is deliberately NO max-position cap. These are high-win-rate,
small-per-trade-edge strategies, so more positions = more edge captured AND the
fat-tail losers get diluted across many names. The only real limits are cash and
(for microcaps) liquidity. Each name gets ~alloc_pct of capital; the strongest
signals are filled first, until cash runs out.

PAPER ONLY. proven_* are the validated backtest figures shown on the dashboard
until enough live trades close to report a real forward win rate.
"""

from dataclasses import dataclass


@dataclass
class Profile:
    key: str
    name: str
    index_csv_url: str          # NSE constituent list (for fetching the universe)
    daily_csv: str              # local daily-bars CSV (symbol,date,close) the scanner reads
    strategy: str = "rsi2"      # "rsi2" (mean-reversion) or "momentum" (breakout+trail)
    label: str = ""             # short strategy badge for the dashboard header
    rules: str = ""             # full plain-English entry/exit rules (shown on the dashboard)
    entry_rsi: float = 5.0
    exit_rsi: float = 85.0
    max_hold: int = 30
    use_trend: bool = False     # rsi2 only: require close > 200-SMA (the uptrend filter)
    breakout: int = 20          # momentum only: new N-day-high entry
    trail: float = 0.15         # momentum/strength: trailing-stop fraction off the peak
    rsi_lo: float = 55.0        # strength only: RSI-14 entry band (buy strong-not-overbought)
    rsi_hi: float = 70.0
    trend_ma: int = 200         # strength/leaders: uptrend SMA length
    mom_days: int = 63          # leaders only: momentum lookback (63 = ~3 months)
    mom_min: float = 0.25       # leaders only: min return over mom_days to buy (0.25 = +25%)
    max_units: int = 1          # scalein only: how many times to average down
    stop: float = 0.0           # scalein only: catastrophe stop (fraction below avg entry)
    hard_stop: float = 0.0      # all equity books: hard stop-loss (fraction below ENTRY);
                                # 0 = off. Cuts a loser fast, before the trailing stop
                                # (which needs a peak first) ever triggers.
    capital: float = 1_000_000.0    # Rs 10 lakh
    alloc_pct: float = 0.02         # ~2% per name -> up to ~50 names (no hard cap)
    proven_win: float = 0.0         # validated backtest win rate (%) — shown until live trades close
    proven_ret: float = 0.0         # validated avg return per trade (%) after costs
    proven_pf: float = 0.0          # validated profit factor (gross win / gross loss)


PROFILES = {
    "smallcap": Profile(
        "smallcap", "Garuda-SC",
        "https://archives.nseindia.com/content/indices/ind_niftysmallcap250list.csv",
        "niftysmallcap250_daily.csv",
        strategy="rsi2", label="RSI-2 < 10 dip · uptrend · 20% stop",
        rules="Buy RSI-2 < 10 in an uptrend (> 200-DMA) · Sell RSI-2 > 85, 30-day hold, "
              "or a 20% catastrophe stop-loss",
        use_trend=True,
        entry_rsi=10.0,   # dip-depth test: <10 gives ~same edge as <5, more trades
        # stop-loss sweep on the ACTUAL niftysmallcap250 universe: 20% is identical
        # to no-stop (+671% total, 67% win, worst -16%) — it never triggers on these
        # quality names, so it costs nothing, but it leaves a hard floor for a tail
        # disaster (the broader NSE set had -45% names a crash/fraud could produce).
        # A tighter 15% stop was a small drag (+665%) for no worst-case gain.
        hard_stop=0.20,
        proven_win=66.0, proven_ret=0.94, proven_pf=1.85),
    "microcap": Profile(
        "microcap", "Garuda-MC",
        "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv",
        "microcap_daily.csv",
        strategy="rsi2", label="RSI-2 < 10 dip · uptrend · 20% stop",
        rules="Buy RSI-2 < 10 in an uptrend (> 200-DMA) · Sell RSI-2 > 85, 30-day hold, "
              "or a 20% catastrophe stop-loss",
        use_trend=True,
        entry_rsi=10.0,   # dip-depth test: <10 marginally beat <5 (+1.34% PF 2.14)
        hard_stop=0.20,   # same free catastrophe floor as smallcap (validated on the sweep)
        proven_win=70.0, proven_ret=1.34, proven_pf=2.14),
    "next50": Profile(
        "next50", "Garuda-N50",
        "https://archives.nseindia.com/content/indices/ind_niftynext50list.csv",
        "next50_daily.csv",
        strategy="momentum", label="Momentum · 20d breakout + 15% trail",
        rules="Buy a fresh 20-day high · Sell on a 15% trailing stop or 120-day hold",
        breakout=20, trail=0.15, max_hold=120,
        # momentum wins less often but wins bigger; win% is the backtest estimate
        # (pending an exact droplet re-run) — ret & PF are the figures from the run.
        proven_win=44.0, proven_ret=1.33, proven_pf=1.23),
    # 4th book — the whole-NSE STRENGTH swing. The 10-strategy showdown on 3,697
    # liquid NSE stocks crowned it the clear winner: +5.94%/trade, PF 2.95 (2005
    # trades). It BUYS STRENGTH (RSI-14 55-70 in an uptrend) and lets it run on a
    # 12% trailing stop — the engine that catches the momentum runners the RSI-2
    # dip books structurally miss. Universe: the top ~1,500 liquid NSE names.
    # NOTE: trend-following, so the fat +5.94% partly reflects a bull regime;
    # expect thinner returns (and more whipsaw) in choppy/bear markets. PAPER.
    "strength": Profile(
        "strength", "Garuda-STR",
        "",                                  # no index — built as top-1500-by-mcap list
        "strength_daily.csv",
        strategy="strength", label="Strength swing · RSI-14 55-70 + 200-DMA",
        rules="Buy RSI-14 in 55-70 above the 200-DMA (buy strength) · Sell on a 12% "
              "trailing stop or 90-day hold",
        rsi_lo=55.0, rsi_hi=70.0, trend_ma=200, trail=0.12, max_hold=90,
        proven_win=55.0, proven_ret=5.94, proven_pf=2.95),
    # 5th book — MOMENTUM LEADERS. The momentum-catcher showdown on 3,697 liquid
    # NSE stocks crowned it the best engine yet: +7.80%/trade, PF 3.37 (1035
    # trades). Buys the stocks that are actually GOING UP (up >25% over ~3 months
    # and still above their 200-DMA) and lets them run on a WIDE 20% trailing
    # stop. Shares the strength universe (top ~1,500 NSE) — no extra data fetch.
    # NOTE: trend-following, so +7.80% partly reflects a bull regime; expect
    # thinner returns and whipsaw in choppy/bear markets. PAPER.
    "leaders": Profile(
        "leaders", "Garuda-LDR",
        "",                                  # shares strength's top-1500 universe
        "strength_daily.csv",                # reuse strength's daily bars — no extra fetch
        strategy="leaders", label="Momentum leaders · 3-mo >25% + 20% trail",
        rules="Buy stocks up >25% over ~3 months and above their 200-DMA (the leaders) · "
              "Sell on a 20% trailing stop or 180-day hold",
        trend_ma=200, mom_days=63, mom_min=0.25, trail=0.20, max_hold=180,
        proven_win=58.0, proven_ret=7.80, proven_pf=3.37),
    # 6th book — SCALE-IN (Connors-TPS average-down), the HIGH-WIN-RATE engine.
    # On 3,697 liquid NSE stocks: 73% win, +1.19%/trade, PF 3.39 (4 units). Buys
    # the RSI-2 dip in an uptrend and AVERAGES DOWN up to 4 units as it falls, so
    # a small bounce exits most trades green (RSI-2 > 50). Capped at 4 units +
    # a 60-day time stop + a 25% catastrophe stop so one falling knife can't
    # wreck it. Shares the strength universe (top ~1,500 NSE). PAPER.
    "scalein": Profile(
        "scalein", "Garuda-SCL",
        "",                                  # shares strength's top-1500 universe
        "strength_daily.csv",                # reuse strength's daily bars — no extra fetch
        strategy="scalein", label="Scale-in · RSI-2 dip, average-down (high win%)",
        rules="Buy RSI-2 < 10 in an uptrend and average down up to 4× as it falls · "
              "Sell the averaged position on RSI-2 > 50, a 60-day hold, or a 25% stop",
        entry_rsi=10.0, exit_rsi=50.0, trend_ma=200, max_hold=60, max_units=4, stop=0.25,
        proven_win=73.0, proven_ret=1.19, proven_pf=3.39),
    # 8th book — 52-WEEK HIGH, the first LAB-DISCOVERED book. DOUBLE-validated:
    # the curated walk-forward LAB promoted it (OOS +1.93%/trade, PF 1.32) AND
    # the reverse grid search (1056 combos, TRAIN/SELECT/TEST windows)
    # independently rediscovered the same rule as its #1 finisher — on the
    # untouched TEST window: +1.92%/trade, PF 1.31, 1461 trades, 42% win. The
    # anomaly: investors anchor to old highs and under-react as they're
    # reclaimed, so the breakout drifts. Low win rate + wide patient exit =
    # the winners pay for the losers. PAPER.
    "hi52": Profile(
        "hi52", "Garuda-52H",
        "",                                  # shares strength's top-1500 universe
        "strength_daily.csv",                # reuse strength's daily bars — no extra fetch
        strategy="hi52", label="52-week high · 2% band cross + 15% trail",
        rules="Buy the cross into 2% of the 52-week high (fresh entry only, no "
              "re-entry while it sits in the band) · Sell on a 15% trailing stop "
              "or a 120-day hold",
        trail=0.15, max_hold=120,
        proven_win=42.0, proven_ret=1.92, proven_pf=1.31),
    # 9th book — CRASH BOUNCE, the LAB's best portfolio. Validated three ways:
    # DISCOVER found the entry (TEST +1.81%/t with the old exit), the exit sweep
    # picked 25%/180d on TRAIN and it HELD on untouched TEST (+2.25%/t, 1491
    # trades), and the rupee simulation crowned it: Rs 10L -> Rs 66.5L in ~5.5y
    # (+41.8% CAGR) with a SMALLER worst drawdown (27.9%) than the tighter exit.
    # The anomaly: fear overshoots — a hard week on a stock still above its
    # 50-DMA is usually panic, not death. Wins only ~46% of trades; the wide
    # patient exit lets the recoveries pay for the duds. Expect losing years
    # (2025 was -13% in the backtest) — that is the price of the CAGR. PAPER.
    "crash": Profile(
        "crash", "Garuda-CRSH",
        "",                                  # shares strength's top-1500 universe
        "strength_daily.csv",                # reuse strength's daily bars — no extra fetch
        strategy="crash", label="Crash bounce · -8% week over 50-DMA + 25% trail",
        rules="Buy a stock down 8%+ over 5 days while still above its 50-DMA "
              "(panic, not death) · Sell on a 25% trailing stop or a 180-day hold",
        trail=0.25, max_hold=180,
        proven_win=46.0, proven_ret=2.25, proven_pf=0.0),
    # 10th book — CHAKRA (monthly momentum rotation), winner of the seat-10
    # TOURNAMENT. On the untouched TEST window (the hostile Nov-2024..Jul-2026
    # stretch) it made +24.5% CAGR with a 23.2% drawdown while the champion
    # crash book went FLAT (-0.5%, 30.2% DD) — and its full-period run was
    # Rs 10L -> Rs 52.8L (+35.9% CAGR). The engine: relentless monthly rotation
    # into the top-20 momentum leaders (6-month return) above their 200-DMA,
    # equal weight, always invested — and implicitly defensive: in a broad bear,
    # few names sit above their 200-DMA, so the wheel holds more cash. PAPER.
    "chakra": Profile(
        "chakra", "Garuda-CHK",
        "",                                  # shares strength's top-1500 universe
        "strength_daily.csv",                # reuse strength's daily bars — no extra fetch
        strategy="chakra", label="Chakra · monthly top-20 momentum rotation",
        rules="On the first trading day of each month, rotate the whole book "
              "into the top-20 six-month momentum leaders above their 200-DMA, "
              "equal weight · always invested · untouched until the next turn "
              "of the wheel",
        mom_days=126, trend_ma=200, max_units=20, alloc_pct=0.05,
        proven_win=0.0, proven_ret=0.0, proven_pf=0.0),   # rotation has no per-trade
}                                                         # stats — live record only
