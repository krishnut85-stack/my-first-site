"""Tests for CAPTAIN — the discretionary seat: the user picks, Garuda tracks."""

from garuda.portfolio import LivePortfolio
from garuda.scan import _load_captain_picks, _run_captain, run_scan
from garuda.strategy import PROFILES


def _flat(px=100.0, days=260):
    return [px] * days


def test_captain_profile():
    p = PROFILES["captain"]
    assert p.strategy == "captain"
    assert p.daily_csv == "strength_daily.csv"
    assert p.capital == 1_000_000
    assert "captain" in p.rules.lower()
    assert len(PROFILES) == 11                    # seat 12 (11 equity + options)


def test_empty_picks_holds_quietly():
    p = PROFILES["captain"]
    pf = LivePortfolio(p.capital)
    pf.buy("KEEP", 10, 100.0, entry_len=200)
    res = _run_captain(p, {"KEEP": _flat()}, pf, picks=[])
    assert res["buys"] == [] and res["sells"] == []
    assert "KEEP" in pf.holdings                  # nothing panic-sold


def test_first_list_bootstraps_equal_weight():
    p = PROFILES["captain"]
    series = {"AAA": _flat(100.0), "BBB": _flat(200.0), "CCC": _flat(50.0)}
    pf = LivePortfolio(p.capital)
    res = _run_captain(p, series, pf, picks=["AAA", "BBB", "CCC"])
    assert {b["symbol"] for b in res["buys"]} == {"AAA", "BBB", "CCC"}
    vals = {s: h["qty"] * series[s][-1] for s, h in pf.holdings.items()}
    hi, lo = max(vals.values()), min(vals.values())
    assert hi - lo < 250                          # equal slices (within 1 share)
    # unpriceable picks are skipped, never bought blind
    res2 = _run_captain(p, series, pf, picks=["AAA", "BBB", "CCC", "GHOST"])
    assert all(b["symbol"] != "GHOST" for b in res2["buys"])


def test_list_change_rotates_to_match():
    p = PROFILES["captain"]
    series = {"AAA": _flat(), "BBB": _flat(), "CCC": _flat()}
    pf = LivePortfolio(p.capital)
    _run_captain(p, series, pf, picks=["AAA", "BBB"])
    # quarter passes; the captain swaps BBB for CCC
    res = _run_captain(p, series, pf, picks=["AAA", "CCC"])
    assert any(s["symbol"] == "BBB" for s in res["sells"])
    assert any(b["symbol"] == "CCC" for b in res["buys"])
    assert set(pf.holdings) == {"AAA", "CCC"}
    # unchanged list: idempotent — no churn
    res2 = _run_captain(p, series, pf, picks=["AAA", "CCC"])
    assert res2["buys"] == [] and res2["sells"] == []


def test_picks_loader_formats(tmp_path, monkeypatch):
    f = tmp_path / "picks.csv"
    f.write_text("# my quarter-3 list\nSymbol\nTCS\ninfy, my note\n\nTCS\n")
    monkeypatch.setenv("CAPTAIN_PICKS", str(f))
    assert _load_captain_picks() == ["TCS", "INFY"]   # deduped, upper, no header
    monkeypatch.setenv("CAPTAIN_PICKS", str(tmp_path / "missing.csv"))
    assert _load_captain_picks() == []


def test_picks_loader_exact_qty_column(tmp_path, monkeypatch):
    f = tmp_path / "picks.csv"
    f.write_text("RRKABEL,100\nTCS, watch this one\nINFY\n")
    monkeypatch.setenv("CAPTAIN_PICKS", str(f))
    syms, qtys = _load_captain_picks(with_qty=True)
    assert syms == ["RRKABEL", "TCS", "INFY"]
    assert qtys == {"RRKABEL": 100}          # notes are not quantities


def test_captain_buys_exact_share_count():
    p = PROFILES["captain"]
    series = {"RRKABEL": _flat(1400.0)}
    pf = LivePortfolio(p.capital)
    res = _run_captain(p, series, pf, picks=["RRKABEL"],
                       qtys={"RRKABEL": 100})
    assert pf.holdings["RRKABEL"]["qty"] == 100       # exactly, not equal-weight
    assert res["buys"][0]["qty"] == 100
    # idempotent: same list next scan -> no churn
    res2 = _run_captain(p, series, pf, picks=["RRKABEL"],
                        qtys={"RRKABEL": 100})
    assert res2["buys"] == [] and res2["sells"] == []


def test_captain_mixes_exact_and_equal_weight():
    p = PROFILES["captain"]
    series = {"FIXED": _flat(1000.0), "AAA": _flat(100.0), "BBB": _flat(200.0)}
    pf = LivePortfolio(p.capital)
    _run_captain(p, series, pf, picks=["FIXED", "AAA", "BBB"],
                 qtys={"FIXED": 100})
    assert pf.holdings["FIXED"]["qty"] == 100          # the captain's number
    # the two flex picks split the REMAINING 9L equally (~4.5L each)
    va = pf.holdings["AAA"]["qty"] * 100.0
    vb = pf.holdings["BBB"]["qty"] * 200.0
    assert abs(va - vb) < 250 and 4_000_00 < va < 5_000_00


def test_run_scan_dispatches_captain(monkeypatch):
    monkeypatch.setenv("CAPTAIN_PICKS", "/nonexistent.csv")
    res = run_scan(PROFILES["captain"], {"AAA": _flat()},
                   LivePortfolio(1_000_000))
    assert res["profile"] == "Garuda-CPT"
