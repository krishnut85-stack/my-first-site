"""NSE F&O instrument utilities: expiries, lot sizes, option symbol construction.

NOTE: Exchange parameters change over time (SEBI/NSE circulars). Lot sizes and
expiry weekdays below are correct as of mid-2026 but are kept in plain dicts so
they can be updated without touching logic. Since Sep 2025 NSE index weekly
expiries are on Tuesday; only NIFTY retains a weekly expiry, other indices and
all stock derivatives are monthly.
"""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, timedelta
from enum import Enum

TUESDAY = 1  # date.weekday() convention: Monday=0

# Lot sizes for the liquid index contracts. Update from the NSE website when
# the exchange revises them.
LOT_SIZES = {
    "NIFTY": 75,
    "BANKNIFTY": 35,
    "FINNIFTY": 65,
    "MIDCPNIFTY": 140,
}

# Strike spacing used when rounding spot to the nearest tradable strike.
STRIKE_STEPS = {
    "NIFTY": 50,
    "BANKNIFTY": 100,
    "FINNIFTY": 50,
    "MIDCPNIFTY": 25,
}

# Indices that still have weekly expiries (post SEBI rationalisation).
WEEKLY_EXPIRY_INDICES = {"NIFTY"}

EXPIRY_WEEKDAY = TUESDAY

# Kite weekly-symbol month codes: Jan-Sep are 1-9, then O, N, D.
_MONTH_CODES = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "O", "N", "D"]


class OptionType(str, Enum):
    CALL = "CE"
    PUT = "PE"


@dataclass(frozen=True)
class Option:
    underlying: str
    expiry: date
    strike: int
    option_type: OptionType

    @property
    def tradingsymbol(self) -> str:
        return build_option_symbol(
            self.underlying, self.expiry, self.strike, self.option_type
        )

    @property
    def lot_size(self) -> int:
        return LOT_SIZES[self.underlying]


def next_weekday(from_date: date, weekday: int) -> date:
    """First date >= from_date that falls on the given weekday."""
    days_ahead = (weekday - from_date.weekday()) % 7
    return from_date + timedelta(days=days_ahead)


def next_weekly_expiry(from_date: date, weekday: int = EXPIRY_WEEKDAY) -> date:
    """Nearest weekly expiry on/after from_date.

    Does not adjust for trading holidays; if the exchange shifts an expiry,
    handle it in configuration.
    """
    return next_weekday(from_date, weekday)


def monthly_expiry(year: int, month: int, weekday: int = EXPIRY_WEEKDAY) -> date:
    """Last occurrence of the expiry weekday in the given month."""
    last_day = date(year, month, calendar.monthrange(year, month)[1])
    offset = (last_day.weekday() - weekday) % 7
    return last_day - timedelta(days=offset)


def next_monthly_expiry(from_date: date, weekday: int = EXPIRY_WEEKDAY) -> date:
    """Nearest monthly expiry on/after from_date."""
    exp = monthly_expiry(from_date.year, from_date.month, weekday)
    if exp >= from_date:
        return exp
    year, month = (from_date.year + 1, 1) if from_date.month == 12 else (
        from_date.year,
        from_date.month + 1,
    )
    return monthly_expiry(year, month, weekday)


def is_monthly_expiry(expiry: date) -> bool:
    return expiry == monthly_expiry(expiry.year, expiry.month, expiry.weekday())


def atm_strike(spot: float, underlying: str) -> int:
    step = STRIKE_STEPS[underlying]
    return int(round(spot / step) * step)


def build_option_symbol(
    underlying: str, expiry: date, strike: int, option_type: OptionType
) -> str:
    """Build a Zerodha/NSE-style option tradingsymbol.

    Monthly contracts: NIFTY26JUN24500CE
    Weekly contracts:  NIFTY2661624500CE  (YY + month-code + DD)
    """
    yy = expiry.strftime("%y")
    suffix = f"{strike}{option_type.value}"
    if is_monthly_expiry(expiry):
        return f"{underlying}{yy}{expiry.strftime('%b').upper()}{suffix}"
    month_code = _MONTH_CODES[expiry.month - 1]
    return f"{underlying}{yy}{month_code}{expiry.day:02d}{suffix}"


def build_future_symbol(underlying: str, expiry: date) -> str:
    """Futures tradingsymbol, e.g. NIFTY26JUNFUT (futures are always monthly)."""
    return f"{underlying}{expiry.strftime('%y')}{expiry.strftime('%b').upper()}FUT"
