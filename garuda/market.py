"""Is the NSE cash market open right now? — the gate that makes paper trading
behave like live trading.

A real broker only fills orders during the session. So Garuda must only book
buys/sells when the market is actually open (IST, Mon-Fri, 09:15-15:30). Outside
that window it just holds what it has and prices it at the last trade — it never
opens or closes a position on a non-trading day.

Note: this covers weekends + session hours. It does NOT know exchange holidays
(Republic Day, Diwali, etc.) — add those to HOLIDAYS as needed.
"""

from datetime import datetime, timedelta, timezone

IST = timezone(timedelta(hours=5, minutes=30))
OPEN_MIN = 9 * 60 + 15      # 09:15
CLOSE_MIN = 15 * 60 + 30    # 15:30

# NSE trading holidays (YYYY-MM-DD). Extend each year.
HOLIDAYS = set()


def now_ist():
    return datetime.now(IST)


def is_trading_day(dt=None):
    dt = dt or now_ist()
    return dt.weekday() < 5 and dt.date().isoformat() not in HOLIDAYS


def is_market_open(dt=None):
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    mins = dt.hour * 60 + dt.minute
    return OPEN_MIN <= mins <= CLOSE_MIN


def market_status(dt=None):
    """Short human label used by the dashboard/logs."""
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return "CLOSED · WEEKEND/HOLIDAY"
    mins = dt.hour * 60 + dt.minute
    if mins < OPEN_MIN:
        return "PRE-OPEN"
    if mins <= CLOSE_MIN:
        return "MARKET OPEN"
    return "CLOSED"
