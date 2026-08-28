"""The session calendar knows CAS split the trading day in three."""

from datetime import date, datetime, time

import pytest

import market_session as ms
from market_session import Phase

# A Thursday after CAS went live, and the same weekday before it.
POST = date(2026, 8, 27)
PRE = date(2026, 7, 30)


def at(d: date, hh: int, mm: int) -> datetime:
    return datetime(d.year, d.month, d.day, hh, mm, tzinfo=ms.IST)


@pytest.mark.parametrize(
    "hh,mm,expected",
    [
        (9, 5, Phase.PRE_OPEN),
        (9, 15, Phase.CONTINUOUS),
        (14, 59, Phase.CONTINUOUS),
        (15, 14, Phase.CONTINUOUS),      # last minute of continuous trading
        (15, 15, Phase.CAS_TRANSITION),
        (15, 20, Phase.CAS_ORDER_ENTRY),
        (15, 25, Phase.CAS_LIMIT_ONLY),
        (15, 30, Phase.CAS_MATCHING),
        (15, 35, Phase.DERIVATIVES_ONLY),  # close published, F&O still open
        (15, 40, Phase.CLOSED),
    ],
)
def test_cas_stock_walks_the_auction_phases(hh, mm, expected):
    assert ms.phase(at(POST, hh, mm)) is expected


def test_non_cas_stock_trades_continuously_to_1530():
    assert ms.phase(at(POST, 15, 20), cas=False) is Phase.CONTINUOUS
    assert ms.phase(at(POST, 15, 30), cas=False) is Phase.DERIVATIVES_ONLY


def test_before_2026_08_03_the_old_session_applies():
    assert ms.phase(at(PRE, 15, 25)) is Phase.CONTINUOUS
    assert ms.phase(at(PRE, 15, 30)) is Phase.CLOSED
    assert ms.cash_close_time(at(PRE, 12, 0)) == time(15, 30)
    assert not ms.cas_in_effect(at(PRE, 12, 0))


def test_cash_open_is_false_inside_the_auction():
    # The bug this module exists to prevent: 15:20 used to read as "open".
    assert ms.is_cash_open(at(POST, 15, 14))
    assert not ms.is_cash_open(at(POST, 15, 20))
    assert ms.in_cas_window(at(POST, 15, 20))


def test_derivatives_run_ten_minutes_past_the_auction():
    assert ms.is_derivatives_open(at(POST, 15, 35))
    assert ms.is_derivatives_open(at(POST, 15, 39))
    assert not ms.is_derivatives_open(at(POST, 15, 40))
    assert not ms.is_derivatives_open(at(PRE, 15, 35))


def test_no_closing_price_before_the_auction_matches():
    assert not ms.closing_price_final(at(POST, 15, 25))   # old OI snapshot slot
    assert not ms.closing_price_final(at(POST, 15, 30))
    assert ms.closing_price_final(at(POST, 15, 35))
    assert ms.closing_price_final(at(POST, 15, 30), cas=False)


def test_eod_jobs_must_wait_for_1541():
    assert not ms.eod_safe(at(POST, 15, 35))   # old daily-summary slot
    assert ms.eod_safe(at(POST, 15, 41))


def test_weekends_and_holidays_are_closed():
    saturday = datetime(2026, 8, 29, 11, 0, tzinfo=ms.IST)
    assert ms.phase(saturday) is Phase.CLOSED
    assert not ms.is_derivatives_open(saturday)
    assert ms.phase(at(POST, 11, 0), holidays=[POST]) is Phase.CLOSED


def test_reference_window_is_the_last_quarter_hour_of_trading():
    start, end = ms.reference_window(at(POST, 9, 30))
    assert (start.hour, start.minute) == (15, 0)
    assert (end.hour, end.minute) == (15, 15)
    assert start.date() == POST


def test_squareoff_moves_ahead_of_the_auction():
    assert ms.recommended_squareoff(at(POST, 9, 30)) == time(15, 10)
    assert ms.recommended_squareoff(at(PRE, 9, 30)) == time(15, 20)


def test_cas_membership_comes_from_the_fno_list():
    fno = ["RELIANCE", "tcs"]
    assert ms.is_cas_security("reliance", fno)
    assert ms.is_cas_security("TCS", fno)
    assert not ms.is_cas_security("IRFC", fno)


def test_naive_datetimes_are_read_as_ist():
    assert ms.phase(datetime(2026, 8, 27, 15, 20)) is Phase.CAS_ORDER_ENTRY
