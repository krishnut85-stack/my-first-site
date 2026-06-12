from datetime import date

from algotrade.instruments import (
    OptionType,
    atm_strike,
    build_future_symbol,
    build_option_symbol,
    is_monthly_expiry,
    monthly_expiry,
    next_monthly_expiry,
    next_weekly_expiry,
)


def test_next_weekly_expiry_is_tuesday():
    # Fri 2026-06-12 -> Tue 2026-06-16
    assert next_weekly_expiry(date(2026, 6, 12)) == date(2026, 6, 16)
    # An expiry day maps to itself.
    assert next_weekly_expiry(date(2026, 6, 16)) == date(2026, 6, 16)


def test_monthly_expiry_last_tuesday():
    assert monthly_expiry(2026, 6) == date(2026, 6, 30)
    assert is_monthly_expiry(date(2026, 6, 30))
    assert not is_monthly_expiry(date(2026, 6, 16))


def test_next_monthly_expiry_rolls_over():
    assert next_monthly_expiry(date(2026, 6, 30)) == date(2026, 6, 30)
    assert next_monthly_expiry(date(2026, 7, 1)) == date(2026, 7, 28)
    assert next_monthly_expiry(date(2026, 12, 30)) == date(2027, 1, 26)


def test_option_symbols():
    # Weekly: YY + month-code + DD
    assert (
        build_option_symbol("NIFTY", date(2026, 6, 16), 24500, OptionType.CALL)
        == "NIFTY2661624500CE"
    )
    # Monthly: YY + MMM
    assert (
        build_option_symbol("NIFTY", date(2026, 6, 30), 24500, OptionType.PUT)
        == "NIFTY26JUN24500PE"
    )
    assert build_future_symbol("NIFTY", date(2026, 6, 30)) == "NIFTY26JUNFUT"


def test_atm_strike_rounding():
    assert atm_strike(24_513, "NIFTY") == 24_500
    assert atm_strike(24_526, "NIFTY") == 24_550
    assert atm_strike(52_870, "BANKNIFTY") == 52_900
