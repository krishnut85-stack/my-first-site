"""Is the NSE cash market open right now? — the gate that makes paper trading
behave like live trading.

A real broker only fills orders during the session. So Garuda must only book
buys/sells when the market is actually open (IST, Mon-Fri, 09:15-15:30). Outside
that window it just holds what it has and prices it at the last trade — it never
opens or closes a position on a non-trading day.

It also honours NSE trading holidays: fixed national holidays are seeded below,
and the movable/religious ones (Holi, Diwali, Eid, Good Friday, ...) — which
shift every year — are read from a plain `nse_holidays.txt` (one YYYY-MM-DD per
line) if present, so you paste NSE's official annual circular in without a code
change. Source: nseindia.com -> Resources -> Holidays -> Trading.
"""

from datetime import datetime, timedelta, timezone
from pathlib import Path

IST = timezone(timedelta(hours=5, minutes=30))
OPEN_MIN = 9 * 60 + 15      # 09:15
CLOSE_MIN = 15 * 60 + 30    # 15:30

# Fixed-date NSE national holidays (these don't move year to year). The movable
# religious holidays change annually — put the full official list in
# nse_holidays.txt and it's merged in below.
_FIXED_HOLIDAYS = {
    "2026-01-26",  # Republic Day
    "2026-04-03",  # Good Friday
    "2026-05-01",  # Maharashtra Day
    "2026-08-15",  # Independence Day
    "2026-10-02",  # Gandhi Jayanti
    "2026-12-25",  # Christmas
}


def _load_holiday_file() -> set:
    """Merge dates from an optional nse_holidays.txt (one YYYY-MM-DD per line)."""
    out = set()
    bases = [Path.cwd()]
    try:
        from . import config
        bases += [config.BASE_DIR, config.BASE_DIR.parent]
    except Exception:  # noqa: BLE001
        pass
    for base in bases:
        p = Path(base) / "nse_holidays.txt"
        if p.exists():
            for line in p.read_text().splitlines():
                s = line.strip()[:10]
                if len(s) == 10 and s[4] == "-" and s[7] == "-":
                    out.add(s)
            break
    return out


# NSE trading holidays (YYYY-MM-DD): fixed national days + the pasted official list.
HOLIDAYS = _FIXED_HOLIDAYS | _load_holiday_file()


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
    if dt.weekday() >= 5:
        return "CLOSED · WEEKEND"
    if dt.date().isoformat() in HOLIDAYS:
        return "CLOSED · NSE HOLIDAY"
    mins = dt.hour * 60 + dt.minute
    if mins < OPEN_MIN:
        return "PRE-OPEN"
    if mins <= CLOSE_MIN:
        return "MARKET OPEN"
    return "CLOSED"
