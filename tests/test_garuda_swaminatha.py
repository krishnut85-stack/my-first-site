"""Tests for the Swaminatha news-driven book (Garuda's 8th book).

Covers the offline pieces — the keyword/value funnel, the event-driven exits,
sizing, persistence and the fail-safe (no Gemini key => no buys). The live NSE
fetch + Gemini judgment are network/LLM and intentionally not exercised here.
"""

from garuda import filings
from garuda.swaminatha import SwaminathaBook


class FakeFeed:
    """Minimal stand-in for KiteFeed: canned LTPs + optional daily bars."""

    def __init__(self, prices=None, bars=None):
        self._p = prices or {}
        self._bars = bars or {}

    def ltp(self, syms):
        return {s: self._p[s] for s in syms if s in self._p}

    def ohlc_daily(self, sym, days=5):
        return self._bars.get(sym, [])


# --- the cheap funnel (no AI, no network) ----------------------------------
def test_classifier_flags_order_win_bullish():
    v, bull, bear, _ = filings.classify(
        "Transrail Lighting secures order worth Rs 459 crore in the MENA region")
    assert v == "bullish" and bull > 0 and bear == 0


def test_classifier_red_flag_beats_good_words():
    # a single strong red flag must win over bullish words (safety first)
    v, _, bear, _ = filings.classify(
        "Company bags order worth Rs 200 crore; auditor resignation reported")
    assert v == "bearish" and bear >= 3


def test_order_value_floor_drops_small_orders():
    big = filings.Announcement("BIG", "2026-07-08", "bags order worth Rs 459 crore")
    small = filings.Announcement("SML", "2026-07-08", "bags order worth Rs 12 crore")
    assert filings.passes_value_floor(big, 100) is True
    assert filings.passes_value_floor(small, 100) is False
    # a non-order catalyst has no value to floor -> it passes through to Gemini
    appr = filings.Announcement("APP", "2026-07-08", "receives USFDA approval")
    assert filings.passes_value_floor(appr, 100) is True


# --- event-driven exits ----------------------------------------------------
def _book_with_holding(entry=100.0, entry_date="2026-07-08", peak=None):
    b = SwaminathaBook(capital=1_000_000.0, alloc_pct=0.10, stop=0.08,
                       trail_arm=0.10, trail_give=0.10, hold_days=15)
    b.cash -= entry * 100
    b.holdings["TEST"] = {"qty": 100, "entry_price": entry, "entry_date": entry_date,
                          "peak": peak or entry, "event": "📰 test", "conf": 70.0}
    return b


def test_hard_stop_sells_below_floor():
    b = _book_with_holding(entry=100.0)
    b._apply_exits({"TEST": 90.0}, "2026-07-09")     # 90 <= 92 hard stop
    assert "TEST" not in b.holdings
    assert b.trades[-1]["side"] == "SELL" and b.trades[-1]["reason"] == "stop"
    assert b.realized < 0                              # sold at a loss


def test_trailing_lock_sells_after_gain_gives_back():
    b = _book_with_holding(entry=100.0)
    b._apply_exits({"TEST": 120.0}, "2026-07-09")     # peak -> 120, trail armed (>=110)
    assert "TEST" in b.holdings and b.holdings["TEST"]["peak"] == 120.0
    b._apply_exits({"TEST": 107.0}, "2026-07-10")     # 107 <= 120*0.9=108 -> trail exit
    assert "TEST" not in b.holdings
    assert b.trades[-1]["reason"] == "trail" and b.realized > 0   # locked a profit


def test_time_exit_after_hold_days():
    b = _book_with_holding(entry=100.0, entry_date="2026-06-01")   # >15 days before
    b._apply_exits({"TEST": 101.0}, "2026-07-01")     # above stop, but held too long
    assert "TEST" not in b.holdings and b.trades[-1]["reason"] == "time"


# --- sizing / buys ---------------------------------------------------------
def test_buy_sizes_to_alloc_and_debits_cash():
    b = SwaminathaBook(capital=1_000_000.0, alloc_pct=0.10)
    ok = b._buy("ACME", 500.0, "📰 big order", 80.0, "2026-07-13")
    assert ok and b.holdings["ACME"]["qty"] == 200          # 100k alloc / 500
    assert abs(b.cash - (1_000_000.0 - 200 * 500.0)) < 1e-6
    assert b.news_log and b.news_log[-1]["symbol"] == "ACME"


def test_buy_rejected_when_cash_short():
    b = SwaminathaBook(capital=1_000.0, alloc_pct=1.0)
    assert b._buy("PRICEY", 5000.0, "x", 90.0, "2026-07-13") is False
    assert not b.holdings


# --- state / equity --------------------------------------------------------
def test_state_reports_live_pnl_and_equity():
    b = _book_with_holding(entry=100.0)
    st = b.state(lambda s: 130.0)                     # priced up 30%
    assert st["n"] == 1
    pos = st["positions"][0]
    assert pos["sym"] == "TEST" and pos["chg"] == 30.0 and pos["pnl"] == 3000.0
    assert st["equity"] > b.starting_capital
    assert st["gemini_ok"] is False                   # no key in the test env


# --- fail-safe + lifecycle -------------------------------------------------
def test_poll_news_returns_empty_without_gemini_key():
    # no GEMINI_API_KEY in the test env -> the book never buys (no confident read)
    b = SwaminathaBook()
    assert b.poll_news(FakeFeed(), "2026-07-13") == []


def test_step_market_closed_is_a_noop():
    b = _book_with_holding(entry=100.0)
    before = dict(b.holdings["TEST"])
    res = b.step(FakeFeed({"TEST": 50.0}), "2026-07-13", market_open=False)
    assert "closed" in res["status"] and b.holdings["TEST"] == before   # no exit while shut


def test_save_load_roundtrip(tmp_path):
    b = _book_with_holding(entry=100.0)
    b.realized = 555.0
    b.seen["abc123"] = "2026-07-13"
    b.gemini_day, b.gemini_count = "2026-07-13", 4
    p = tmp_path / "swaminatha.json"
    b.save(str(p))
    b2 = SwaminathaBook.load(str(p))
    assert b2.starting_capital == 1_000_000.0 and b2.realized == 555.0
    assert b2.holdings["TEST"]["qty"] == 100 and b2.seen == {"abc123": "2026-07-13"}
    assert b2.gemini_count == 4
