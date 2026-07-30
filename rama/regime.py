"""Market-regime filter: is the broad market trending up or down?

A momentum strategy makes money in up-trends and bleeds in down-trends. This
module answers one question — "is the index above its long moving average?" —
which the engine uses to decide whether to open NEW positions.

Design choices:
  • FAIL-OPEN. If we can't determine the trend (no Kite history, offline,
    synthetic prices), we return `default` (True = allow trading). The bot must
    never freeze just because a data fetch hiccupped.
  • Only meaningful on REAL data. In synthetic/paper-data mode there is no real
    index, so we don't pretend to gate on a fabricated trend.
"""

from . import config
from .datasource import PaperDataSource


def market_in_uptrend(ds, default: bool = True) -> bool:
    """True if `config.REGIME_INDEX` is at/above its `config.REGIME_SMA`-day
    average (an up-trend). Returns `default` when the trend is unknowable."""
    # Synthetic prices have no real index to judge -> don't fake a regime.
    if isinstance(ds, PaperDataSource):
        return default
    try:
        bars = ds.history(config.REGIME_INDEX, config.REGIME_SMA + 10)
    except Exception:  # noqa: BLE001
        return default
    closes = [b.close for b in bars if b.close and b.close > 0]
    if len(closes) < config.REGIME_SMA:
        return default  # not enough history to be sure -> allow trading
    sma = sum(closes[-config.REGIME_SMA:]) / config.REGIME_SMA
    return closes[-1] >= sma
