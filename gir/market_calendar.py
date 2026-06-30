"""
market_calendar.py — NSE trading calendar + AMO window awareness.

Critical safety helper for Hunter executor:
  - is_trading_day(d): True if NSE is open on date d
  - next_trading_day(d): returns next trading date after d
  - is_amo_window_open(): True if NSE accepts AMO submissions right now
  - assert_can_place_amo(): raises if we shouldn't place AMO right now,
    with a human-readable reason

NSE timings (all IST):
  - Regular session:   09:15 - 15:30
  - Pre-open call:     09:00 - 09:15
  - AMO accept window: 15:45 (T) - 09:00 (T+1)  (per Zerodha docs)
  - Closing call:      15:40 - 16:00 (separate)

Holiday list maintained inline. Update yearly via NSE official calendar.

Author: GIR-HUNTER v0.4
Date: May 16 2026
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo


IST = ZoneInfo("Asia/Kolkata")


# ============================================================================
# NSE HOLIDAY CALENDAR — official trading holidays
# Source: NSE India circular. Update annually.
# ============================================================================

NSE_HOLIDAYS_2026: set[date] = {
    date(2026, 1, 15),   # Municipal Corporation Elections in Maharashtra (Thu)
    date(2026, 1, 26),   # Republic Day (Mon)
    date(2026, 3, 3),    # Holi (Tue)
    date(2026, 3, 26),   # Shri Ram Navami (Thu)
    date(2026, 3, 31),   # Shri Mahavir Jayanti (Tue)
    date(2026, 4, 3),    # Good Friday (Fri) - long weekend
    date(2026, 4, 14),   # Dr. Baba Saheb Ambedkar Jayanti (Tue)
    date(2026, 5, 1),    # Maharashtra Day (Fri) - long weekend
    date(2026, 5, 28),   # Bakri Eid (Thu)
    date(2026, 6, 26),   # Moharram (Fri) - long weekend
    date(2026, 9, 14),   # Ganesh Chaturthi (Mon) - long weekend
    date(2026, 10, 2),   # Mahatma Gandhi Jayanti (Fri) - long weekend
    date(2026, 10, 20),  # Dussehra (Tue)
    date(2026, 11, 10),  # Diwali-Balipratipada (Tue)
    date(2026, 11, 24),  # Prakash Gurpurb Sri Guru Nanak Dev (Tue)
    date(2026, 12, 25),  # Christmas (Fri) - long weekend
    # Note: Nov 8, 2026 (Sun) is Diwali-Laxmi Pujan with Muhurat trading session.
    # Excluded - Sunday, Mon-Fri timers won't fire. Add date(2026, 11, 8) if needed.
}

# Combined holiday set across years we care about
NSE_HOLIDAYS: set[date] = set() | NSE_HOLIDAYS_2026


# ============================================================================
# AMO WINDOW — when Kite accepts AMO order submissions
# ============================================================================
# Zerodha accepts AMO for next trading day during:
#   - Mon-Thu evening: 15:45 to 23:59 (for next morning)
#   - Mon-Fri overnight 00:00 to 09:08 (for that morning)
#   - Friday 15:45 onwards through Monday 09:08 — wraps the weekend
#   - Excludes the live session (09:08 - 15:30) when regular orders apply

AMO_EVENING_OPEN  = time(15, 45)
AMO_MORNING_CLOSE = time(9, 8)
SESSION_OPEN      = time(9, 15)
SESSION_CLOSE     = time(15, 30)


# ============================================================================
# PUBLIC API
# ============================================================================

def now_ist() -> datetime:
    return datetime.now(IST)


def is_trading_day(d: date) -> bool:
    """True if NSE has regular equity session on date d."""
    if d.weekday() >= 5:        # 5=Sat, 6=Sun
        return False
    if d in NSE_HOLIDAYS:
        return False
    return True


def next_trading_day(d: date) -> date:
    """Returns next trading date strictly after d."""
    nxt = d + timedelta(days=1)
    while not is_trading_day(nxt):
        nxt += timedelta(days=1)
        # Safety: don't search more than 14 days
        if (nxt - d).days > 14:
            raise RuntimeError(f"No trading day found within 14 days after {d}")
    return nxt


def is_amo_window_open(now: datetime | None = None) -> tuple[bool, str]:
    """
    True if Kite is currently accepting AMO submissions.
    Returns (is_open, reason).

    AMO is open when:
      - We are NOT inside the live session (09:15 - 15:30 on a trading day)
      - The NEXT trading day exists (always true except massive holiday clusters)
    """
    n = now if now is not None else now_ist()
    today = n.date()
    t = n.time()

    # If today is a trading day and we're inside the live session, AMO closed
    if is_trading_day(today) and SESSION_OPEN <= t < SESSION_CLOSE:
        return (False, f"Live session in progress ({SESSION_OPEN}-{SESSION_CLOSE} IST). Use regular orders.")

    # Otherwise — evening, overnight, weekend, holiday — AMO accepting
    nxt = next_trading_day(today) if not is_trading_day(today) else (
        today if t < SESSION_OPEN else next_trading_day(today)
    )
    return (True, f"AMO window open. Orders will queue for next trading day: {nxt} ({nxt.strftime('%A')})")


def assert_can_place_amo(now: datetime | None = None) -> date:
    """
    Raises RuntimeError with explicit reason if we cannot place AMO now.
    Returns the date the AMO will execute against.
    """
    n = now if now is not None else now_ist()
    ok, reason = is_amo_window_open(n)
    if not ok:
        raise RuntimeError(f"AMO blocked: {reason}")

    today = n.date()
    if is_trading_day(today) and n.time() < SESSION_OPEN:
        target = today
    else:
        target = next_trading_day(today)
    return target


# ============================================================================
# SELF-TEST
# ============================================================================

if __name__ == "__main__":
    n = now_ist()
    print(f"Now (IST): {n.strftime('%Y-%m-%d %H:%M:%S %A')}")
    print(f"Today is trading day: {is_trading_day(n.date())}")
    print(f"Next trading day: {next_trading_day(n.date())}")
    ok, reason = is_amo_window_open(n)
    print(f"AMO window open: {ok}")
    print(f"Reason: {reason}")
    try:
        target = assert_can_place_amo(n)
        print(f"✓ Can place AMO. Will execute on: {target} ({target.strftime('%A')})")
    except RuntimeError as e:
        print(f"✗ {e}")
