"""Tests for profit banking (Nifty condor) + the stock-options condor book."""

from datetime import date, timedelta

from garuda.options import OptionsBook
from garuda.stock_options import StockCondorBook, load_fno_universe, month_expiry


# --- profit banking on the Nifty condor (exit at ₹50k milestones) ----------
def _book(realized=0.0, bank_at=50_000.0):
    b = OptionsBook(capital=1_000_000.0, dist=0.025, wing=0.01,
                    credit_frac=0.30, alloc_pct=0.02, realized=realized,
                    bank_at=bank_at)
    return b


def test_banks_early_when_crossing_the_milestone():
    b = _book(realized=48_000.0)
    b.step(24_000.0, date(2026, 7, 24), True)          # Friday: opens the week
    assert b.condor is not None
    # mid-week (Tue), spot safely in range → earned theta pushes past 50k
    b.step(24_050.0, date(2026, 7, 28), True)
    settles = [t for t in b.trades if t["side"] == "SETTLE"]
    assert settles and "banked early" in settles[-1].get("reason", "")
    assert b.realized > 48_000.0
    assert b.condor is not None                        # rolled straight into a new one


def test_no_banking_below_milestone_or_when_disabled():
    b = _book(realized=10_000.0)                       # far from 50k
    b.step(24_000.0, date(2026, 7, 24), True)
    b.step(24_050.0, date(2026, 7, 28), True)
    assert not any("banked early" in (t.get("reason") or "") for t in b.trades)
    b2 = _book(realized=48_000.0, bank_at=0)           # rule disabled
    b2.step(24_000.0, date(2026, 7, 24), True)
    b2.step(24_050.0, date(2026, 7, 28), True)
    assert not any("banked early" in (t.get("reason") or "") for t in b2.trades)


def test_banked_amount_uses_linear_theta_not_full_credit():
    b = _book(realized=49_900.0)
    b.step(24_000.0, date(2026, 7, 24), True)          # opens; expiry Thu 30th
    b.step(24_000.0, date(2026, 7, 27), True)          # half the week elapsed
    settle = [t for t in b.trades if t["side"] == "SETTLE"][-1]
    full_credit = b._credit_frac_to_rs()
    assert 0 < settle["pnl"] < full_credit             # partial, never the full credit


# --- monthly expiry calendar ------------------------------------------------
def test_month_expiry_is_last_thursday():
    assert month_expiry(date(2026, 7, 1)) == "2026-07-30"    # last Thu of July 2026
    # on/past July's expiry → rolls to August's last Thursday (never 0-DTE)
    assert month_expiry(date(2026, 7, 30)) == "2026-08-27"
    assert month_expiry(date(2026, 7, 31)) == "2026-08-27"
    assert month_expiry(date(2026, 12, 30)) == "2026-12-31"  # Dec 31 is a Thursday
    assert month_expiry(date(2026, 12, 31)) == "2027-01-28"  # year rollover


# --- the stock condor book --------------------------------------------------
def _prices(**kw):
    return dict(kw)


def test_opens_up_to_max_names_from_universe():
    b = StockCondorBook(max_names=2)
    uni = ["AAA", "BBB", "CCC"]
    b.step(_prices(AAA=100.0, BBB=200.0, CCC=300.0), date(2026, 7, 1), True,
           universe=uni)
    assert set(b.positions) == {"AAA", "BBB"}          # top of the list, capped
    p = b.positions["AAA"]
    assert p["strikes"]["sp"] == 94.0 and p["strikes"]["sc"] == 106.0  # ±6%
    assert p["expiry"] == "2026-07-30"


def test_skips_unpriceable_and_closed_market():
    b = StockCondorBook(max_names=3)
    b.step(_prices(AAA=0.0), date(2026, 7, 1), True, universe=["AAA"])
    assert b.positions == {}                           # no price → no condor
    b.step(_prices(AAA=100.0), date(2026, 7, 1), False, universe=["AAA"])
    assert b.positions == {}                           # market shut → nothing


def test_settles_at_monthly_expiry_and_rolls():
    b = StockCondorBook(max_names=1)
    b.step(_prices(AAA=100.0), date(2026, 7, 1), True, universe=["AAA"])
    # expiry day, spot stayed inside the band → full (modelled) credit banked
    b.step(_prices(AAA=101.0), date(2026, 7, 30), True, universe=["AAA"])
    settles = [t for t in b.trades if t["side"] == "SETTLE"]
    assert len(settles) == 1 and settles[0]["pnl"] > 0
    assert b.realized > 0
    # and it re-opened for the next month
    assert "AAA" in b.positions
    assert b.positions["AAA"]["expiry"] == "2026-08-27"


def test_breach_loss_is_capped_at_risk_per_name():
    b = StockCondorBook(max_names=1, alloc_pct=0.01)
    b.step(_prices(AAA=100.0), date(2026, 7, 1), True, universe=["AAA"])
    b.step(_prices(AAA=60.0), date(2026, 7, 30), True, universe=[])  # crash through
    settle = [t for t in b.trades if t["side"] == "SETTLE"][0]
    assert settle["pnl"] < 0
    assert abs(settle["pnl"]) <= b.starting_capital * 0.01 + 1     # defined risk


def test_state_reports_positions_and_totals():
    b = StockCondorBook(max_names=2)
    b.step(_prices(AAA=100.0, BBB=200.0), date(2026, 7, 1), True,
           universe=["AAA", "BBB"])
    st = b.state(_prices(AAA=101.0, BBB=150.0))       # BBB breached (-25%)
    assert st["n"] == 2
    marks = {r["sym"]: r for r in st["positions"]}
    assert marks["AAA"]["in_range"] and not marks["BBB"]["in_range"]
    assert st["positions"][0]["sym"] == "BBB"          # worst mark first
    assert st["equity"] == b.starting_capital + st["unrealized"]


def test_universe_loader(tmp_path, monkeypatch):
    f = tmp_path / "fno.txt"
    f.write_text("# comment\nRELIANCE\ntcs\nRELIANCE\n\nM&M\n")
    monkeypatch.setenv("FNO_STOCKS", str(f))
    assert load_fno_universe() == ["RELIANCE", "TCS", "M&M"]
    monkeypatch.setenv("FNO_STOCKS", str(tmp_path / "missing.txt"))
    assert load_fno_universe() == []


def test_save_load_roundtrip(tmp_path):
    b = StockCondorBook(max_names=1)
    b.step(_prices(AAA=100.0), date(2026, 7, 1), True, universe=["AAA"])
    b.save(tmp_path / "b.json")
    b2 = StockCondorBook.load(tmp_path / "b.json")
    assert "AAA" in b2.positions and b2.max_names == 1
