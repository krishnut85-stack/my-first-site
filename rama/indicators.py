"""Technical indicators. Currently: ATR (Average True Range).

ATR measures how much a stock typically moves per bar, so an ATR-based stop
adapts to each stock's volatility instead of using a flat percentage.
"""

from dataclasses import dataclass


@dataclass
class Bar:
    high: float
    low: float
    close: float


def true_range(bar: Bar, prev_close: float) -> float:
    return max(
        bar.high - bar.low,
        abs(bar.high - prev_close),
        abs(bar.low - prev_close),
    )


def atr(bars: list[Bar], period: int = 14) -> float:
    """Wilder's ATR. Returns 0.0 if there isn't enough history."""
    if len(bars) < period + 1:
        return 0.0
    trs = [true_range(bars[i], bars[i - 1].close) for i in range(1, len(bars))]
    # seed with simple average of the first `period` TRs, then smooth (Wilder)
    atr_val = sum(trs[:period]) / period
    for tr in trs[period:]:
        atr_val = (atr_val * (period - 1) + tr) / period
    return atr_val
