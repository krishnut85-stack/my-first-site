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
    trend_ma: int = 200         # strength only: uptrend SMA length
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
        strategy="rsi2", label="RSI-2 < 10 dip · uptrend",
        rules="Buy RSI-2 < 10 in an uptrend (> 200-DMA) · Sell RSI-2 > 85 or 30-day hold",
        use_trend=True,
        entry_rsi=10.0,   # dip-depth test: <10 gives ~same edge as <5, more trades
        proven_win=66.0, proven_ret=0.94, proven_pf=1.85),
    "microcap": Profile(
        "microcap", "Garuda-MC",
        "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv",
        "microcap_daily.csv",
        strategy="rsi2", label="RSI-2 < 10 dip · uptrend",
        rules="Buy RSI-2 < 10 in an uptrend (> 200-DMA) · Sell RSI-2 > 85 or 30-day hold",
        use_trend=True,
        entry_rsi=10.0,   # dip-depth test: <10 marginally beat <5 (+1.34% PF 2.14)
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
}
