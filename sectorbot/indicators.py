"""Technical indicators. Currently: ATR (Average True Range) and RSI.

ATR measures how much a stock typically moves per bar, so an ATR-based stop
adapts to each stock's volatility instead of using a flat percentage.
RSI measures how one-sided recent moves have been (0-100); below ~30 is the
classic "oversold" zone, above ~70 "overbought".
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


def rsi(closes: list[float], period: int = 14) -> float | None:
    """Wilder's RSI on a series of closes (oldest first).

    Returns None if there isn't enough history (needs period+1 closes; more
    history makes the Wilder smoothing more faithful to charting platforms).
    """
    if len(closes) < period + 1:
        return None
    gains, losses = [], []
    for prev, cur in zip(closes, closes[1:]):
        change = cur - prev
        gains.append(max(change, 0.0))
        losses.append(max(-change, 0.0))
    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period
    for g, l in zip(gains[period:], losses[period:]):
        avg_gain = (avg_gain * (period - 1) + g) / period
        avg_loss = (avg_loss * (period - 1) + l) / period
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - 100.0 / (1.0 + rs)
