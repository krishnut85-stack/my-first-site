"""The rotation rule as a live paper book: pick, hold, do nothing."""

import json

import pytest

from garuda.rotation import HOLD_M, RotationBook, months_between


def study(picks, as_of="2026-09"):
    return {"today": {"as_of": as_of, "picks": picks}}


PICKS = [
    {"industry": "Iron & Steel Products", "trailing": 56.8,
     "members": ["APLAPOLLO", "WELCORP"], "thin_history": False,
     "history_months": 240},
    {"industry": "Healthcare Services", "trailing": 55.3,
     "members": ["LALPATHLAB", "VIJAYA"], "thin_history": False,
     "history_months": 120},
    {"industry": "Special Consumer Services", "trailing": 50.9,
     "members": ["WEWORK"], "thin_history": True, "history_months": 14},
]

PRICES = {"APLAPOLLO": 1000.0, "WELCORP": 500.0,
          "LALPATHLAB": 2000.0, "VIJAYA": 400.0, "WEWORK": 100.0}


def test_months_between_counts_whole_months():
    assert months_between("2026-09-06", "2027-03-01") == 6
    assert months_between("2026-09-30", "2026-10-01") == 1
    assert months_between("2026-09-01", "2026-09-28") == 0


def test_it_rebalances_before_the_first_holding_then_goes_quiet():
    b = RotationBook()
    assert b.due("2026-09-07")
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    assert not b.due("2026-09-08")
    assert not b.due("2027-02-28")          # five months in, still holding
    assert b.due("2027-03-07")              # six months up
    assert b.next_rerank() == "2027-03"


def test_capital_is_split_equally_across_industries_then_stocks():
    b = RotationBook(capital=1_000_000.0)
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    h = b.pf.holdings
    # two usable industries -> 5L each; within each, split across its stocks
    assert h["APLAPOLLO"]["qty"] == 250        # 250k / 1000
    assert h["WELCORP"]["qty"] == 500          # 250k / 500
    assert h["LALPATHLAB"]["qty"] == 125       # 250k / 2000
    assert h["VIJAYA"]["qty"] == 625           # 250k / 400


def test_a_thin_history_pick_is_skipped_not_bought():
    """The 20-year test cannot vouch for an industry that listed last year."""
    b = RotationBook()
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    assert "WEWORK" not in b.pf.holdings
    assert b.skipped == [{"industry": "Special Consumer Services", "months": 14}]
    assert "Special Consumer Services" not in b.industries


def test_it_does_nothing_between_rebalances():
    b = RotationBook()
    b.step(PRICES, "2026-09-07", True, study(PICKS))
    before = dict(b.pf.holdings)
    moved = {k: v * 5 for k, v in PRICES.items()}      # the market rips
    assert b.step(moved, "2026-11-20", True, study(PICKS)) is None
    assert b.pf.holdings == before                     # no trims, no stops


def test_it_will_not_trade_on_a_closed_market_or_without_prices():
    b = RotationBook()
    assert b.step(PRICES, "2026-09-07", False, study(PICKS)) is None
    assert b.step({}, "2026-09-07", True, study(PICKS)) is None
    assert not b.pf.holdings


def test_a_missing_study_holds_rather_than_guessing():
    b = RotationBook()
    note = b.rebalance(PRICES, None, "2026-09-07")
    assert "no usable picks" in note
    assert not b.pf.holdings
    b2 = RotationBook()
    b2.rebalance(PRICES, study([]), "2026-09-07")
    assert not b2.pf.holdings


def test_the_second_rebalance_sells_what_left_the_top_five():
    b = RotationBook()
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    assert "APLAPOLLO" in b.pf.holdings
    later = [{"industry": "Gems & Jewellery", "members": ["TITAN"],
              "thin_history": False, "history_months": 240}]
    b.rebalance({**PRICES, "TITAN": 3000.0}, study(later), "2027-03-07")
    assert "APLAPOLLO" not in b.pf.holdings      # rotated out
    assert "TITAN" in b.pf.holdings
    assert any(t["side"] == "SELL" for t in b.pf.trades)


def test_state_and_persistence_survive_a_restart(tmp_path):
    b = RotationBook()
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    p = tmp_path / "rot.json"
    b.save(p)
    again = RotationBook.load(p)
    assert again.industries == b.industries
    assert again.opened == "2026-09-07"
    assert again.pf.holdings == b.pf.holdings
    st = again.state(lambda s: PRICES.get(s))
    assert st["capital"] == 1_000_000.0
    assert st["next_rerank"] == "2027-03"
    assert len(st["positions"]) == 4
    assert "6-month momentum" in st["rule"]
    json.dumps(st)


def test_equity_tracks_prices_moving():
    b = RotationBook()
    b.rebalance(PRICES, study(PICKS), "2026-09-07")
    flat = b.equity(lambda s: PRICES.get(s))
    up = b.equity(lambda s: (PRICES.get(s) or 0) * 1.10)
    assert up > flat
    assert flat == pytest.approx(1_000_000.0, abs=2_000)   # minus rounding cash
