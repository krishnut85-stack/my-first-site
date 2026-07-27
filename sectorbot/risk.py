"""Per-position risk management: decides when to exit.

Combines four exit rules (all configurable in config.py):
  1. Hard stop-loss      — fixed % below entry
  2. Hard take-profit    — fixed % above entry
  3. Trailing stop       — after a profit threshold, trail the peak by a %
                           (this both locks profit and protects gains)
  4. ATR stop            — volatility-adaptive stop below entry

The first rule that triggers wins. Whichever stop is highest (tightest) is the
one that protects you, so we exit if price breaches ANY active stop.
"""

from dataclasses import dataclass, field

from . import config


@dataclass
class PositionState:
    symbol: str
    entry_price: float
    qty: int
    atr: float = 0.0                  # ATR at entry (0 if unavailable)
    peak_price: float = field(default=0.0)

    def __post_init__(self):
        if self.peak_price == 0.0:
            self.peak_price = self.entry_price

    def update_peak(self, ltp: float) -> None:
        self.peak_price = max(self.peak_price, ltp)


def decide_exit(state: PositionState, ltp: float) -> tuple[bool, str]:
    """Return (should_exit, reason) for the current price."""
    state.update_peak(ltp)
    entry = state.entry_price
    change = (ltp - entry) / entry
    gain_from_entry = change

    # 1. hard stop-loss
    if change <= -config.STOP_LOSS_PCT:
        return True, f"stop-loss {change:+.1%}"

    # 2. hard take-profit
    if change >= config.TAKE_PROFIT_PCT:
        return True, f"take-profit {change:+.1%}"

    # 3. trailing stop (arms only after enough profit -> locks gains).
    # DEFENSIVE MODE: on a hostile morning (Market Weather DOWN/STRONG DOWN)
    # the give tightens for the day — winners surrender less of their peak
    # before booking. Still price-driven: a stock holding firm is untouched.
    if config.USE_TRAILING_STOP:
        peak_gain = (state.peak_price - entry) / entry
        if peak_gain >= config.TRAILING_ACTIVATE_PCT:
            give = config.TRAILING_SL_PCT * getattr(config, "WEATHER_TRAIL_FACTOR", 1.0)
            drop_from_peak = (state.peak_price - ltp) / state.peak_price
            if drop_from_peak >= give:
                locked = (ltp - entry) / entry
                tag = " · defensive" if give < config.TRAILING_SL_PCT else ""
                return True, f"trailing-stop (locked {locked:+.1%}{tag})"

    # 4. ATR stop
    if config.USE_ATR_STOP and state.atr > 0:
        atr_stop_price = entry - config.ATR_MULT * state.atr
        if ltp <= atr_stop_price:
            return True, f"ATR-stop ({config.ATR_MULT}x ATR, {gain_from_entry:+.1%})"

    return False, ""
