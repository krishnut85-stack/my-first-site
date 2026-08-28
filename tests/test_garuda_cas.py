"""The Closing Auction Session (live 2026-08-03) split the trading day in three.

Category I (F&O) stocks leave continuous trading at 15:15 and settle in an
auction that publishes the close at 15:35; everything else trades on to 15:30;
equity derivatives run to 15:40.
"""

from datetime import datetime, time

import pytest

from garuda import market as mkt

CAS_SYM = "RELIANCE"      # Category I - in fno_stocks.txt
PLAIN = "SOMESMALLCAP"    # Category II - not in the F&O list


@pytest.fixture(autouse=True)
def _known_universe(monkeypatch):
    monkeypatch.setattr(mkt, "CAS_STOCKS", {CAS_SYM})


def at(hh, mm, day=27):
    """A Thursday in August 2026 - after CAS went live."""
    return datetime(2026, 8, day, hh, mm)


def before(hh, mm):
    """The same weekday in July 2026 - before CAS went live."""
    return datetime(2026, 7, 30, hh, mm)


def test_category_one_stops_trading_at_1515():
    assert mkt.is_market_open(at(15, 14), CAS_SYM)
    assert not mkt.is_market_open(at(15, 15), CAS_SYM)
    assert not mkt.is_market_open(at(15, 25), CAS_SYM)


def test_category_two_still_trades_to_1530():
    assert mkt.is_market_open(at(15, 25), PLAIN)
    assert not mkt.is_market_open(at(15, 30), PLAIN)


def test_symbol_less_call_asks_whether_any_cash_is_open():
    # The dashboard and the daily scan use this looser question.
    assert mkt.is_market_open(at(15, 20))
    assert not mkt.is_market_open(at(15, 30))


def test_derivatives_run_ten_minutes_past_the_cash_close():
    assert mkt.is_derivatives_open(at(15, 35))
    assert mkt.is_derivatives_open(at(15, 39))
    assert not mkt.is_derivatives_open(at(15, 40))
    assert not mkt.is_derivatives_open(before(15, 35))


def test_auction_window_spans_1515_to_1535():
    assert not mkt.in_cas_window(at(15, 14))
    assert mkt.in_cas_window(at(15, 15))
    assert mkt.in_cas_window(at(15, 34))
    assert not mkt.in_cas_window(at(15, 35))
    assert not mkt.in_cas_window(before(15, 20))    # no auction before 2026-08-03


def test_session_live_covers_the_whole_day():
    assert mkt.is_session_live(at(11, 0))
    assert mkt.is_session_live(at(15, 20))     # auction
    assert mkt.is_session_live(at(15, 38))     # F&O tail
    assert not mkt.is_session_live(at(15, 41))


def test_no_closing_price_before_the_auction_matches():
    assert not mkt.closing_price_final(at(15, 30), CAS_SYM)
    assert mkt.closing_price_final(at(15, 35), CAS_SYM)
    assert mkt.closing_price_final(at(15, 30), PLAIN)


def test_eod_jobs_wait_for_1541():
    assert not mkt.eod_safe(at(15, 35))
    assert mkt.eod_safe(at(15, 41))
    assert mkt.eod_safe(before(15, 31))        # old day ended at 15:30


def test_pre_cas_dates_keep_the_old_single_session():
    assert mkt.is_market_open(before(15, 25), CAS_SYM)   # no auction back then
    assert not mkt.is_market_open(before(15, 30), CAS_SYM)
    assert not mkt.cas_in_effect(before(11, 0))


def test_status_labels_name_the_auction_phase():
    assert mkt.market_status(at(11, 0)) == "MARKET OPEN"
    assert mkt.market_status(at(15, 22)) == "AUCTION · ORDER ENTRY · CASH OPEN"
    assert mkt.market_status(at(15, 27)) == "AUCTION · LIMIT ONLY · CASH OPEN"
    assert mkt.market_status(at(15, 32)) == "AUCTION · MATCHING"
    assert mkt.market_status(at(15, 37)) == "F&O ONLY"
    assert mkt.market_status(at(15, 45)) == "CLOSED"
    assert mkt.market_status(at(11, 0, day=29)) == "CLOSED · WEEKEND"


def test_squareoff_moves_ahead_of_the_auction():
    assert mkt.recommended_squareoff(at(9, 30)) == time(15, 10)
    assert mkt.recommended_squareoff(before(9, 30)) == time(15, 20)


def test_reference_window_is_the_last_quarter_hour():
    start, end = mkt.reference_window(at(9, 30))
    assert (start.hour, start.minute) == (15, 0)
    assert (end.hour, end.minute) == (15, 15)


def test_scan_withholds_auction_names_from_fills(tmp_path, monkeypatch):
    from garuda import config
    from garuda.live import GarudaLive
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    live = GarudaLive(csv_dir=str(tmp_path))
    live.prices = {CAS_SYM: 1400.0, PLAIN: 90.0}

    monkeypatch.setattr("garuda.live.in_cas_window", lambda *a: False)
    assert live._fillable_prices() == live.prices

    # inside the auction the Category I quote is indicative -> not fillable
    monkeypatch.setattr("garuda.live.in_cas_window", lambda *a: True)
    monkeypatch.setattr("garuda.live.is_cas_symbol", lambda s: s == CAS_SYM)
    assert live._fillable_prices() == {PLAIN: 90.0}


def test_cas_universe_derives_from_the_instrument_dump():
    """Category I = F&O underlyings that are also NSE cash securities."""
    nfo = [{"name": "RELIANCE", "tradingsymbol": "RELIANCE26SEPFUT"},
           {"name": "RELIANCE", "tradingsymbol": "RELIANCE26SEP1400CE"},
           {"name": "TCS", "tradingsymbol": "TCS26SEPFUT"},
           {"name": "NIFTY", "tradingsymbol": "NIFTY26SEP24300CE"},
           {"name": "BANKNIFTY", "tradingsymbol": "BANKNIFTY26SEPFUT"},
           {"name": "DELISTED", "tradingsymbol": "DELISTED26SEPFUT"}]
    nse = [{"tradingsymbol": "RELIANCE"}, {"tradingsymbol": "TCS"},
           {"tradingsymbol": "IRFC"}]
    got = mkt.cas_universe_from_instruments(nfo, nse)
    assert got == ["RELIANCE", "TCS"]          # deduped and sorted
    assert "NIFTY" not in got                  # an index is not a cash security
    assert "IRFC" not in got                   # cash-only name, still 15:30
