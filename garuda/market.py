"""Is the NSE market open right now? — the gate that makes paper trading
behave like live trading.

A real broker only fills orders during the session. So Garuda must only book
buys/sells when the market is actually open (IST, Mon-Fri) and price everything
else at the last trade — it never opens or closes a position on a non-trading
day.

It also honours NSE trading holidays: fixed national holidays are seeded below,
and the movable/religious ones (Holi, Diwali, Eid, Good Friday, ...) — which
shift every year — are read from a plain `nse_holidays.txt` (one YYYY-MM-DD per
line) if present, so you paste NSE's official annual circular in without a code
change. Source: nseindia.com -> Resources -> Holidays -> Trading.

The Closing Auction Session (from 2026-08-03)
---------------------------------------------
SEBI replaced the old "close = last 30 minutes' VWAP" rule with a call auction,
and the single 09:15-15:30 session became three overlapping ones:

* **Category I** stocks — those carrying F&O contracts — stop continuous
  trading at **15:15** and settle in an auction that publishes the close at
  **15:35**.
* **Category II** (everything else, which is most of Garuda's small- and
  micro-cap universe) still trades continuously to **15:30** on the old VWAP
  close.
* **Equity derivatives** were extended and now run to **15:40**.

The auction day-end for a Category I stock::

    15:00-15:15  continuous trading; this window's VWAP is the auction
                 REFERENCE price
    15:15-15:20  transition into the auction (no continuous trading)
    15:20-15:25  order entry / modify / cancel — limit AND market orders
    15:25-15:30  limit orders only; entry may stop at a random point in the
                 final two minutes
    15:30-15:35  matching; the closing price is published
    15:40        equity derivatives close

Two consequences worth stating plainly, because they are easy to get wrong:

1. **There is no official closing price before 15:35.** Anything snapshotted at
   15:25 or 15:30 is a pre-auction number.
2. **Quotes inside the auction are indicative, not a live order book.** Garuda
   must not fill a Category I name against them, which is why
   :func:`is_market_open` takes a symbol.

Every check branches on :data:`CAS_START_DATE` rather than "today", so a
backtest spanning the changeover gets the old timings before 3 August and the
new ones after.
"""

from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

IST = timezone(timedelta(hours=5, minutes=30))

OPEN_MIN = 9 * 60 + 15      # 09:15  first continuous trade
CLOSE_MIN = 15 * 60 + 30    # 15:30  Category II close (and the whole pre-CAS day)

CAS_OPEN_MIN = 15 * 60 + 15       # 15:15  Category I leaves continuous trading
CAS_ENTRY_MIN = 15 * 60 + 20      # 15:20  auction order entry, limit + market
CAS_LIMIT_MIN = 15 * 60 + 25      # 15:25  limit orders only
CAS_MATCH_MIN = 15 * 60 + 30      # 15:30  matching, no new orders
CAS_CLOSE_MIN = 15 * 60 + 35      # 15:35  closing price published
DERIVATIVES_CLOSE_MIN = 15 * 60 + 40   # 15:40  F&O close
REFERENCE_OPEN_MIN = 15 * 60          # 15:00  reference-VWAP window opens
EOD_SAFE_MIN = 15 * 60 + 41           # 15:41  everything final, safe for EOD jobs

#: The day CAS went live. Before it, one 09:15-15:30 session for everything.
CAS_START_DATE = date(2026, 8, 3)

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


def _bases():
    """Where to look for the plain-text lists: cwd first, then the package."""
    out = [Path.cwd()]
    try:
        from . import config
        out += [config.BASE_DIR, config.BASE_DIR.parent]
    except Exception:  # noqa: BLE001
        pass
    return out


def _load_holiday_file() -> set:
    """Merge dates from an optional nse_holidays.txt (one YYYY-MM-DD per line)."""
    out = set()
    for base in _bases():
        p = Path(base) / "nse_holidays.txt"
        if p.exists():
            for line in p.read_text().splitlines():
                s = line.strip()[:10]
                if len(s) == 10 and s[4] == "-" and s[7] == "-":
                    out.add(s)
            break
    return out


def _load_cas_stocks() -> set:
    """The Category I list: symbols that close by auction instead of at 15:30.

    Category I is defined as "has F&O contracts", so the F&O universe *is* the
    list. Read `cas_stocks.txt` if present, else fall back to `fno_stocks.txt`.
    Both are one NSE symbol per line, '#' starts a comment — the same shape as
    nse_holidays.txt, so you paste the exchange's list in without a code change.

    Note fno_stocks.txt is Garuda's *curated* condor subset, not the full F&O
    universe. Until a complete list is pasted into cas_stocks.txt, names missing
    from it are treated as Category II — they will be quoted a few minutes past
    their real 15:15 cutoff. Paper-only, and it fails in the safe direction
    (Garuda under-trades rather than filling against an auction).
    """
    for name in ("cas_stocks.txt", "fno_stocks.txt"):
        for base in _bases():
            p = Path(base) / name
            if not p.exists():
                continue
            out = set()
            for line in p.read_text().splitlines():
                s = line.split("#")[0].strip().upper()
                if s:
                    out.add(s)
            if out:
                return out
    return set()


# NSE trading holidays (YYYY-MM-DD): fixed national days + the pasted official list.
HOLIDAYS = _FIXED_HOLIDAYS | _load_holiday_file()

#: Category I symbols — they close by auction. Empty is safe: everything is
#: then treated as Category II, i.e. exactly the pre-CAS behaviour.
CAS_STOCKS = _load_cas_stocks()


def now_ist():
    return datetime.now(IST)


def _mins(dt) -> int:
    return dt.hour * 60 + dt.minute


def cas_in_effect(dt=None) -> bool:
    """Was the auction live on this date? False for anything before 2026-08-03."""
    dt = dt or now_ist()
    return dt.date() >= CAS_START_DATE


def is_trading_day(dt=None) -> bool:
    dt = dt or now_ist()
    return dt.weekday() < 5 and dt.date().isoformat() not in HOLIDAYS


def is_cas_symbol(sym) -> bool:
    """Does this symbol close by auction (Category I)?

    Indices are not cash securities and never enter the auction themselves —
    though their closing *values* are built from constituents that do, which is
    why index F&O expiry settlement now reflects auction prices.
    """
    return bool(sym) and str(sym).strip().upper() in CAS_STOCKS


def close_min(dt=None, sym=None) -> int:
    """The minute continuous trading stops for this security."""
    if not cas_in_effect(dt):
        return CLOSE_MIN
    return CAS_OPEN_MIN if is_cas_symbol(sym) else CLOSE_MIN


def is_market_open(dt=None, sym=None) -> bool:
    """True only during *continuous* cash trading — never inside the auction.

    Pass ``sym`` to get the answer for one security: a Category I name goes
    quiet at 15:15, everything else at 15:30. Without a symbol this answers the
    looser question "is any cash security still trading?", which is what the
    dashboard and the once-a-day scan gate on.
    """
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    return OPEN_MIN <= _mins(dt) < close_min(dt, sym)


def in_cas_window(dt=None) -> bool:
    """True from 15:15 to 15:35, while the closing auction runs."""
    dt = dt or now_ist()
    if not is_trading_day(dt) or not cas_in_effect(dt):
        return False
    return CAS_OPEN_MIN <= _mins(dt) < CAS_CLOSE_MIN


def is_derivatives_open(dt=None) -> bool:
    """True while equity derivatives trade — to 15:40 since CAS, 15:30 before.

    Note the asymmetry: from 15:15 a Category I stock's cash market is in
    auction while its options keep trading, so those premiums are priced off an
    indicative auction price rather than a live spot.
    """
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    end = DERIVATIVES_CLOSE_MIN if cas_in_effect(dt) else CLOSE_MIN
    return OPEN_MIN <= _mins(dt) < end


def is_session_live(dt=None) -> bool:
    """True while *anything* is trading — cash, auction, or derivatives.

    This is the gate for passive work like sampling the equity curve, which
    should keep running through the auction; use :func:`is_market_open` for
    anything that transacts.
    """
    return is_market_open(dt) or in_cas_window(dt) or is_derivatives_open(dt)


def closing_price_final(dt=None, sym=None) -> bool:
    """Has the official closing price been published yet?

    Gate EOD snapshots on this: before 15:35 a Category I stock has no closing
    price, only a last traded price and an indicative auction price.
    """
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    if not cas_in_effect(dt):
        return _mins(dt) >= CLOSE_MIN
    return _mins(dt) >= (CAS_CLOSE_MIN if is_cas_symbol(sym) else CLOSE_MIN)


def eod_safe(dt=None) -> bool:
    """True from 15:41 — closes are final and derivatives have shut."""
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    return _mins(dt) >= (EOD_SAFE_MIN if cas_in_effect(dt) else CLOSE_MIN)


def reference_window(dt=None):
    """The 15:00-15:15 window whose VWAP seeds the auction reference price.

    If a stock does not trade in it the exchange falls back to the day's last
    traded price, and failing that to the previous close adjusted for corporate
    actions.
    """
    dt = dt or now_ist()
    return (dt.replace(hour=15, minute=0, second=0, microsecond=0),
            dt.replace(hour=15, minute=15, second=0, microsecond=0))


def recommended_squareoff(dt=None) -> time:
    """Latest sensible intraday square-off for an options position.

    15:10 — five minutes before the underlying's cash market freezes. Exiting
    after 15:15 means trading an option whose underlying is in auction.
    """
    return time(15, 10) if cas_in_effect(dt) else time(15, 20)


def market_status(dt=None) -> str:
    """Short human label used by the dashboard header and the logs."""
    dt = dt or now_ist()
    if dt.weekday() >= 5:
        return "CLOSED · WEEKEND"
    if dt.date().isoformat() in HOLIDAYS:
        return "CLOSED · NSE HOLIDAY"
    mins = _mins(dt)
    if mins < OPEN_MIN:
        return "PRE-OPEN"
    if not cas_in_effect(dt):
        return "MARKET OPEN" if mins < CLOSE_MIN else "CLOSED"
    if mins < CAS_OPEN_MIN:
        return "MARKET OPEN"
    # The auction runs for Category I while Category II trades on to 15:30, so
    # the header names the auction phase and the tail says cash is still live.
    tail = " · CASH OPEN" if mins < CLOSE_MIN else ""
    if mins < CAS_ENTRY_MIN:
        return "AUCTION · OPENING" + tail
    if mins < CAS_LIMIT_MIN:
        return "AUCTION · ORDER ENTRY" + tail
    if mins < CAS_MATCH_MIN:
        return "AUCTION · LIMIT ONLY" + tail
    if mins < CAS_CLOSE_MIN:
        return "AUCTION · MATCHING"
    if mins < DERIVATIVES_CLOSE_MIN:
        return "F&O ONLY"
    return "CLOSED"


# Index derivatives settle on an index value, not a cash security, so their
# underlyings are never Category I themselves.
INDEX_ROOTS = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50",
               "SENSEX", "BANKEX", "SENSEX50"}


def cas_universe_from_instruments(nfo_instruments, nse_instruments):
    """Derive the Category I list from a broker's instrument dump.

    Category I is defined as "carries F&O contracts", so the F&O underlyings
    *are* the list. Pass Kite's ``instruments("NFO")`` and ``instruments("NSE")``
    dumps (lists of dicts). A name is kept only when it also exists as an NSE
    cash symbol, which drops the index derivatives without needing to enumerate
    every index.

    Pure and side-effect free so it can be tested without a broker session; see
    scripts/refresh_cas_stocks.py for the wrapper that writes the file.
    """
    cash = {str(i.get("tradingsymbol", "")).strip().upper()
            for i in nse_instruments}
    cash.discard("")
    out = set()
    for i in nfo_instruments:
        name = str(i.get("name", "")).strip().upper()
        if name and name not in INDEX_ROOTS and name in cash:
            out.add(name)
    return sorted(out)
