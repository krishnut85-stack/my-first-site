"""IST time helpers.

The trading server runs on UTC (DigitalOcean default), so naive
datetime.now() is 5.5 hours behind the market. Everything time-of-day
related must go through these helpers.
"""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")


def now_ist() -> datetime:
    return datetime.now(IST)


def is_weekday(d: datetime | None = None) -> bool:
    return (d or now_ist()).weekday() < 5
