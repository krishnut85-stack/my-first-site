"""NSE session calendar, CAS-aware.

SEBI's **Closing Auction Session (CAS)** went live on **3 August 2026** and
changed the shape of the trading day. Every bot in this repo (and Garuda on the
droplet) used to assume one universal session, 09:15-15:30 IST. That is now
wrong in three separate ways, so all of them share this module instead of
hardcoding ``(15, 30)``.

What changed on 2026-08-03
--------------------------
* **Category I** stocks - those with F&O contracts on *both* NSE and BSE - stop
  continuous trading at **15:15** and settle via a call auction instead.
* Everything else ("Category II") still trades continuously to **15:30** and
  still closes on the old last-30-minute VWAP.
* **Equity derivatives** were extended by ten minutes and now run to **15:40**.

The auction day-end, for a Category I stock::

    15:00-15:15  continuous trading; this window's VWAP is the auction
                 REFERENCE price
    15:15-15:20  transition into the auction (no continuous trading)
    15:20-15:25  order entry / modify / cancel - limit AND market orders
    15:25-15:30  limit orders only; the exchange may stop entry at a random
                 point inside the final two minutes
    15:30-15:35  matching, trade confirmation, closing price published
    15:40        equity derivatives close

The closing price is the single price at which the maximum volume is
executable. If nothing matches, the reference price becomes the close.

Two consequences worth stating plainly, because they bite scheduled jobs:

1. **No official closing price exists before 15:35.** Any "EOD" snapshot taken
   at 15:25 or 15:30 is a pre-auction number, not the close.
2. **The index close is an auction close.** Nifty and Bank Nifty are built from
   their constituents, nearly all of which are Category I, so index F&O expiry
   settlement now reflects auction prices.

Backtests
---------
Every function takes the moment it is reasoning about and branches on
:data:`CAS_START_DATE`, so a backtest that spans 2026 gets the old timings for
old dates and the new ones from 3 August onward. Do not shortcut this by
comparing against ``date.today()``.

Nothing here places orders or touches the network; it is pure calendar
arithmetic.
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from enum import Enum
from typing import Iterable, Optional

try:                                    # stdlib on 3.9+, but tzdata can be absent
    from zoneinfo import ZoneInfo
    IST = ZoneInfo("Asia/Kolkata")
except Exception:                       # pragma: no cover - fallback for bare images
    IST = timezone(timedelta(hours=5, minutes=30), "IST")

__all__ = [
    "IST", "CAS_START_DATE", "Phase",
    "now_ist", "cas_in_effect", "is_trading_day", "phase",
    "is_cash_open", "is_derivatives_open", "in_cas_window",
    "closing_price_final", "eod_safe", "reference_window",
    "cash_close_time", "derivatives_close_time", "recommended_squareoff",
    "is_cas_security",
]

#: The day CAS went live on NSE and BSE. Before this date the legacy
#: 09:15-15:30 session applies to everything.
CAS_START_DATE = date(2026, 8, 3)

PRE_OPEN_START = time(9, 0)
MARKET_OPEN = time(9, 15)

#: The auction reference price is the VWAP of trades in this window.
REFERENCE_START = time(15, 0)

CAS_START = time(15, 15)            # continuous trading ends for CAS securities
CAS_ORDER_ENTRY = time(15, 20)      # limit + market orders
CAS_LIMIT_ONLY = time(15, 25)       # limit orders only, random cutoff
CAS_MATCHING = time(15, 30)         # matching; no new orders
CAS_END = time(15, 35)              # closing price published

NON_CAS_CLOSE = time(15, 30)        # Category II stocks, unchanged
DERIVATIVES_CLOSE = time(15, 40)    # extended by 10 minutes on 2026-08-03
LEGACY_CLOSE = time(15, 30)         # the whole market, before CAS

#: Earliest time an EOD job can assume closes are final AND derivatives are
#: done. Schedule daily reports and P&L snapshots at or after this.
EOD_SAFE = time(15, 41)


class Phase(str, Enum):
    """Where the clock is in the trading day, from one instrument's point of view."""

    CLOSED = "closed"
    PRE_OPEN = "pre_open"                  # 09:00-09:15 call auction
    CONTINUOUS = "continuous"              # normal order-book trading
    CAS_TRANSITION = "cas_transition"      # 15:15-15:20, auction opening
    CAS_ORDER_ENTRY = "cas_order_entry"    # 15:20-15:25, limit + market
    CAS_LIMIT_ONLY = "cas_limit_only"      # 15:25-15:30, limit only
    CAS_MATCHING = "cas_matching"          # 15:30-15:35, price discovery
    DERIVATIVES_ONLY = "derivatives_only"  # cash shut, F&O still trading


def now_ist() -> datetime:
    """Current time in IST, always timezone-aware."""
    return datetime.now(IST)


def _as_ist(moment: Optional[datetime]) -> datetime:
    """Normalise ``None``/naive/foreign-tz input to an IST-aware datetime."""
    if moment is None:
        return now_ist()
    if moment.tzinfo is None:
        return moment.replace(tzinfo=IST)
    return moment.astimezone(IST)


def cas_in_effect(moment: Optional[datetime] = None) -> bool:
    """Was CAS live on this date? False for anything before 2026-08-03."""
    return _as_ist(moment).date() >= CAS_START_DATE


def is_trading_day(
    moment: Optional[datetime] = None,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """Mon-Fri and not an exchange holiday.

    Holidays are injected rather than hardcoded - pass the NSE list you already
    maintain (``hunter/market_calendar.py`` has one). With no list this only
    filters weekends, which is the same behaviour the bots had before.
    """
    d = _as_ist(moment).date()
    if d.weekday() >= 5:
        return False
    return d not in set(holidays or ())


def cash_close_time(moment: Optional[datetime] = None, *, cas: bool = True) -> time:
    """When continuous cash trading stops for this security.

    ``cas=True`` means a Category I security (has F&O on both exchanges).
    """
    if not cas_in_effect(moment):
        return LEGACY_CLOSE
    return CAS_START if cas else NON_CAS_CLOSE


def derivatives_close_time(moment: Optional[datetime] = None) -> time:
    """When the equity derivatives segment stops trading."""
    return DERIVATIVES_CLOSE if cas_in_effect(moment) else LEGACY_CLOSE


def phase(
    moment: Optional[datetime] = None,
    *,
    cas: bool = True,
    holidays: Optional[Iterable[date]] = None,
) -> Phase:
    """The session phase for a cash-market security at ``moment``.

    ``cas=True`` treats it as a Category I stock (auction close); ``cas=False``
    as Category II (continuous to 15:30). For derivatives use
    :func:`is_derivatives_open` - they never enter the auction.
    """
    n = _as_ist(moment)
    if not is_trading_day(n, holidays):
        return Phase.CLOSED

    t = n.time()
    if t < PRE_OPEN_START:
        return Phase.CLOSED
    if t < MARKET_OPEN:
        return Phase.PRE_OPEN

    if not cas_in_effect(n):
        if t < LEGACY_CLOSE:
            return Phase.CONTINUOUS
        return Phase.CLOSED

    if not cas:
        if t < NON_CAS_CLOSE:
            return Phase.CONTINUOUS
        # Cash is done for this stock, but F&O keeps trading until 15:40.
        return Phase.DERIVATIVES_ONLY if t < DERIVATIVES_CLOSE else Phase.CLOSED

    if t < CAS_START:
        return Phase.CONTINUOUS
    if t < CAS_ORDER_ENTRY:
        return Phase.CAS_TRANSITION
    if t < CAS_LIMIT_ONLY:
        return Phase.CAS_ORDER_ENTRY
    if t < CAS_MATCHING:
        return Phase.CAS_LIMIT_ONLY
    if t < CAS_END:
        return Phase.CAS_MATCHING
    return Phase.DERIVATIVES_ONLY if t < DERIVATIVES_CLOSE else Phase.CLOSED


def is_cash_open(
    moment: Optional[datetime] = None,
    *,
    cas: bool = True,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """True only during *continuous* cash trading.

    Deliberately False inside the auction: quotes there are indicative, not a
    live order book, so any strategy that reads an LTP and acts on it must sit
    the window out.
    """
    return phase(moment, cas=cas, holidays=holidays) is Phase.CONTINUOUS


def in_cas_window(
    moment: Optional[datetime] = None,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """True from 15:15 to 15:35 on a CAS trading day."""
    return phase(moment, cas=True, holidays=holidays) in {
        Phase.CAS_TRANSITION,
        Phase.CAS_ORDER_ENTRY,
        Phase.CAS_LIMIT_ONLY,
        Phase.CAS_MATCHING,
    }


def is_derivatives_open(
    moment: Optional[datetime] = None,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """True while equity derivatives trade - to 15:40 since CAS, 15:30 before.

    Note the asymmetry this creates: from 15:15 the underlying cash market of a
    Category I stock is in auction while its options keep trading. Premiums in
    that window are priced off an indicative auction price, not a live spot.
    """
    n = _as_ist(moment)
    if not is_trading_day(n, holidays):
        return False
    return MARKET_OPEN <= n.time() < derivatives_close_time(n)


def closing_price_final(
    moment: Optional[datetime] = None,
    *,
    cas: bool = True,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """Has the official closing price been published yet?

    Gate every EOD snapshot on this. Before 15:35 a CAS stock has no closing
    price - only a last traded price and an indicative auction price.
    """
    n = _as_ist(moment)
    if not is_trading_day(n, holidays):
        return False
    if not cas_in_effect(n):
        return n.time() >= LEGACY_CLOSE
    return n.time() >= (CAS_END if cas else NON_CAS_CLOSE)


def eod_safe(
    moment: Optional[datetime] = None,
    holidays: Optional[Iterable[date]] = None,
) -> bool:
    """True once closes are final *and* derivatives have shut (15:41+)."""
    n = _as_ist(moment)
    if not is_trading_day(n, holidays):
        return False
    return n.time() >= (EOD_SAFE if cas_in_effect(n) else LEGACY_CLOSE)


def reference_window(moment: Optional[datetime] = None) -> tuple[datetime, datetime]:
    """The 15:00-15:15 window whose VWAP seeds the auction reference price.

    Returned as IST datetimes on ``moment``'s date, ready to hand to a
    historical-candle call. If a stock does not trade in this window the
    exchange falls back to the day's last traded price, and failing that to the
    previous close adjusted for corporate actions.
    """
    d = _as_ist(moment)
    start = d.replace(hour=REFERENCE_START.hour, minute=REFERENCE_START.minute,
                      second=0, microsecond=0)
    end = d.replace(hour=CAS_START.hour, minute=CAS_START.minute,
                    second=0, microsecond=0)
    return start, end


def recommended_squareoff(moment: Optional[datetime] = None) -> time:
    """Latest sensible intraday square-off for an options position.

    15:10 - five minutes before the underlying's cash market freezes. Squaring
    off after 15:15 means exiting an option whose underlying is in auction, and
    the old 15:20-15:30 window now sits entirely inside that blind spot.
    """
    return time(15, 10) if cas_in_effect(moment) else time(15, 20)


def is_cas_security(symbol: str, fno_underlyings: Iterable[str]) -> bool:
    """Is ``symbol`` a Category I (auction-closed) stock?

    Phase 1 covers exactly the stocks carrying F&O contracts, so derive this
    from the live F&O underlying list rather than a checked-in list that rots
    at every review. From Kite: pull ``NFO`` instruments and collect ``name``.

    Indices are not cash securities and never enter CAS themselves - though
    their closing *values* are built from constituents that do.
    """
    return symbol.strip().upper() in {s.strip().upper() for s in fno_underlyings}
