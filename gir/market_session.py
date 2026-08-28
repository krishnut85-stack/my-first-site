"""NSE session calendar for GIR — CAS-aware.

GIR deploys flat to /home/globalbot, separately from Garuda's package tree, so
it carries its own copy of the calendar. The two are deliberately kept in
lockstep: tests/test_cas_parity.py walks every minute of a trading day and
fails if this module and garuda/market.py ever disagree. Change one, change
both.

Why this exists
---------------
SEBI's Closing Auction Session went live on **2026-08-03** and split the day
that GIR's code assumed was a single 09:15-15:30 session:

* **Category I** stocks — those carrying F&O contracts — leave continuous
  trading at **15:15** and settle in a call auction that publishes the closing
  price at **15:35**.
* **Category II** (everything else) trades continuously to **15:30** and still
  closes on the old last-30-minute VWAP.
* **Equity derivatives** run to **15:40**, ten minutes later than before.

    15:00-15:15  continuous; this window's VWAP is the auction REFERENCE price
    15:15-15:20  transition into the auction
    15:20-15:25  order entry — limit AND market
    15:25-15:30  limit only; random cutoff in the last two minutes
    15:30-15:35  matching; closing price published
    15:40        derivatives close

Consequences for GIR specifically:

* A 15:20-15:30 square-off runs entirely inside the auction, with the
  underlying frozen — exits must be done by 15:15.
* An "EOD" snapshot at 15:25 or 15:30 predates the closing price.
* A daily summary at 15:35 is taken while derivatives still trade.

Every check branches on :data:`CAS_START_DATE` rather than "today", so replays
and backtests over the changeover get the right timings on both sides.
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
EOD_SAFE_MIN = 15 * 60 + 41           # 15:41  safe for EOD jobs

#: The day CAS went live. Before it, one 09:15-15:30 session for everything.
CAS_START_DATE = date(2026, 8, 3)

_FIXED_HOLIDAYS = {
    "2026-01-26",  # Republic Day
    "2026-04-03",  # Good Friday
    "2026-05-01",  # Maharashtra Day
    "2026-08-15",  # Independence Day
    "2026-10-02",  # Gandhi Jayanti
    "2026-12-25",  # Christmas
}


def _bases():
    here = Path(__file__).resolve().parent
    return [Path.cwd(), here, here.parent]


def _load_lines(name) -> set:
    """Read a one-token-per-line list ('#' comments) from the first file found."""
    for base in _bases():
        p = Path(base) / name
        if not p.exists():
            continue
        out = {ln.split("#")[0].strip().upper()
               for ln in p.read_text().splitlines()}
        out.discard("")
        if out:
            return out
    return set()


#: NSE trading holidays (YYYY-MM-DD): fixed national days + nse_holidays.txt.
HOLIDAYS = _FIXED_HOLIDAYS | {s for s in _load_lines("nse_holidays.txt")
                              if len(s) == 10 and s[4] == "-"}

#: Category I symbols — they close by auction. Written by
#: scripts/refresh_cas_stocks.py; falls back to the F&O universe list. Empty is
#: safe: everything is then treated as Category II, i.e. the pre-CAS behaviour.
CAS_STOCKS = _load_lines("cas_stocks.txt") or _load_lines("fno_stocks.txt")


def now_ist():
    return datetime.now(IST)


def _mins(dt) -> int:
    return dt.hour * 60 + dt.minute


def cas_in_effect(dt=None) -> bool:
    """Was the auction live on this date? False before 2026-08-03."""
    dt = dt or now_ist()
    return dt.date() >= CAS_START_DATE


def is_trading_day(dt=None) -> bool:
    dt = dt or now_ist()
    return dt.weekday() < 5 and dt.date().isoformat() not in HOLIDAYS


def is_cas_symbol(sym) -> bool:
    """Does this symbol close by auction (Category I)?"""
    return bool(sym) and str(sym).strip().upper() in CAS_STOCKS


def close_min(dt=None, sym=None) -> int:
    """The minute continuous trading stops for this security."""
    if not cas_in_effect(dt):
        return CLOSE_MIN
    return CAS_OPEN_MIN if is_cas_symbol(sym) else CLOSE_MIN


def is_market_open(dt=None, sym=None) -> bool:
    """True only during *continuous* cash trading — never inside the auction.

    Pass ``sym`` for one security: a Category I name goes quiet at 15:15,
    everything else at 15:30. Without a symbol this answers the looser "is any
    cash security still trading?".
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

    From 15:15 a Category I underlying is in auction while its options keep
    trading, so those premiums price off an indicative auction price rather
    than a live spot. Size and stop accordingly.
    """
    dt = dt or now_ist()
    if not is_trading_day(dt):
        return False
    end = DERIVATIVES_CLOSE_MIN if cas_in_effect(dt) else CLOSE_MIN
    return OPEN_MIN <= _mins(dt) < end


def is_session_live(dt=None) -> bool:
    """True while anything trades — cash, auction, or derivatives."""
    return is_market_open(dt) or in_cas_window(dt) or is_derivatives_open(dt)


def closing_price_final(dt=None, sym=None) -> bool:
    """Has the official closing price been published yet? Gate EOD snapshots."""
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
    """The 15:00-15:15 window whose VWAP seeds the auction reference price."""
    dt = dt or now_ist()
    return (dt.replace(hour=15, minute=0, second=0, microsecond=0),
            dt.replace(hour=15, minute=15, second=0, microsecond=0))


def recommended_squareoff(dt=None) -> time:
    """Latest sensible intraday square-off — 15:10, before the cash freeze."""
    return time(15, 10) if cas_in_effect(dt) else time(15, 20)


def market_status(dt=None) -> str:
    """Short human label for logs and Telegram."""
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
