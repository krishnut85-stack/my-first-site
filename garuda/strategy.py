"""Garuda live strategy profiles — the proven RSI-2 bounce, one per universe.

Two profiles, both running the exact settings validated across the market
segmentation (Smallcap 250 +1.27%/trade, Microcap 250 +1.82%/trade):

    entry RSI-2 < 5   ·   exit RSI-2 > 85 or 30-day hold   ·   no trend filter

Sizing note: there is deliberately NO max-position cap. This is a high-win-rate,
small-per-trade-edge strategy, so more positions = more edge captured AND the
fat-tail losers get diluted across many names. The only real limits are cash and
(for microcaps) liquidity. Each name gets ~alloc_pct of capital; the most
oversold signals are filled first, until cash runs out.
"""

from dataclasses import dataclass


@dataclass
class Profile:
    key: str
    name: str
    index_csv_url: str          # NSE constituent list (for fetching the universe)
    daily_csv: str              # local daily-bars CSV (symbol,date,close) the scanner reads
    entry_rsi: float = 5.0
    exit_rsi: float = 85.0
    max_hold: int = 30
    use_trend: bool = False
    capital: float = 1_000_000.0    # Rs 10 lakh
    alloc_pct: float = 0.02         # ~2% per name -> up to ~50 names (no hard cap)
    proven_win: float = 0.0         # validated backtest win rate (%) — shown until live trades close
    proven_ret: float = 0.0         # validated avg return per trade (%) after costs


PROFILES = {
    "smallcap": Profile(
        "smallcap", "Garuda-SC",
        "https://archives.nseindia.com/content/indices/ind_niftysmallcap250list.csv",
        "niftysmallcap250_daily.csv", proven_win=68.0, proven_ret=1.27),
    "microcap": Profile(
        "microcap", "Garuda-MC",
        "https://nsearchives.nseindia.com/content/indices/ind_niftymicrocap250_list.csv",
        "microcap_daily.csv", proven_win=71.0, proven_ret=1.82),
    "next50": Profile(
        "next50", "Garuda-N50",
        "https://archives.nseindia.com/content/indices/ind_niftynext50list.csv",
        "next50_daily.csv", proven_win=61.0, proven_ret=0.08),
}
