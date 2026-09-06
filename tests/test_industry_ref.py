"""Trendlyne's industry table as a coverage map and an outside opinion."""

import pytest

from garuda import industry_ref as ir

ROWS = ('"S.No","Name","Day Change %","Sector","No. of Companies",'
        '"Month Change %","Qtr Change %","Half Yr Change %","1Yr Change %"\n'
        '"1","Aluminium and Aluminium Products","1.2","Metals & Mining","29",'
        '"-0.16","67.42","68.65","94.01"\n'
        '"2","Wires & Cables","-5.9","Consumer Durables","21",'
        '"-2.09","-1.16","16.57","36.9"\n'
        '"3","Sugar","-1.9","Fast Moving Consumer Goods","24",'
        '"1.0","-","2.0","1,708.14"\n')


@pytest.fixture
def ref(tmp_path):
    p = tmp_path / "industries.csv"
    p.write_text(ROWS, encoding="utf-8-sig")
    return ir.load_reference(p)


def test_it_reads_names_sectors_counts_and_windows(ref):
    a = ref["Aluminium and Aluminium Products"]
    assert a["sector"] == "Metals & Mining" and a["companies"] == 29
    assert a["3m"] == pytest.approx(67.42)
    assert a["6m"] == pytest.approx(68.65)


def test_thousands_separators_and_dashes_are_handled(ref):
    assert ref["Sugar"]["12m"] == pytest.approx(1708.14)
    assert ref["Sugar"]["3m"] is None          # "-" is absent, not zero


def test_a_missing_file_reads_as_empty_not_a_crash(tmp_path):
    assert ir.load_reference(tmp_path / "nope.csv") == {}


def test_coverage_names_what_is_not_measured(ref):
    cov = ir.coverage(ref, measured={"Wires & Cables"},
                      meta={"Wires & Cables": {"members": 4, "with_data": 3}})
    assert cov["total"] == 3 and cov["measured"] == 1
    assert cov["companies_total"] == 74 and cov["companies_covered"] == 21
    # the biggest unmeasured industry is named first
    assert cov["missing"][0]["industry"] == "Aluminium and Aluminium Products"
    assert cov["have"][0]["priced"] == 3


def test_compare_puts_the_biggest_disagreement_first(ref):
    ours = [{"industry": "Aluminium and Aluminium Products", "6m": 20.0},
            {"industry": "Wires & Cables", "6m": 16.0},
            {"industry": "Not In Reference", "6m": 5.0}]
    pairs = ir.compare(ref, ours, "6m")
    assert [p["industry"] for p in pairs][0] == "Aluminium and Aluminium Products"
    assert pairs[0]["gap"] == pytest.approx(20.0 - 68.65)
    assert len(pairs) == 2            # the unknown industry is dropped


def test_agreement_detects_two_series_measuring_the_same_thing():
    same = [{"industry": str(i), "ours": v, "theirs": v + 2, "gap": -2.0}
            for i, v in enumerate([1, 5, 9, 20, 44, 60])]
    assert ir.agreement(same)["corr"] > 0.99          # offset but same shape
    import random
    random.seed(4)
    noise = [{"industry": str(i), "ours": random.uniform(-50, 50),
              "theirs": random.uniform(-50, 50), "gap": 0.0} for i in range(40)]
    assert abs(ir.agreement(noise)["corr"]) < 0.5     # unrelated series
    assert ir.agreement([])["corr"] is None


BREADTH = ('﻿"S.No","NAME","NO. OF STOCKS","MARKET CAP","MOMENTUM SCORE",'
           '"RSI > 50","MFI > 50","LTP > SMA20","LTP > SMA50","LTP > SMA200",'
           '"SMA50 > SMA200","DAY GAINERS%","WEEK GAINERS%"\n'
           '"1","Iron & Steel Products","88","5,11,783.33","44.31","23.5%",'
           '"58.8%","23.5%","30.7%","44.3%","29.4%","52.9%","23.5%"\n'
           '"2","Microfinance Institutions","5","1,234.00","61.00","80%",'
           '"80%","60%","80%","80%","60%","40%","60%"\n')


@pytest.fixture
def breadth(tmp_path):
    p = tmp_path / "breadth.csv"
    p.write_text(BREADTH, encoding="utf-8")
    return ir.load_breadth(p)


def test_breadth_reads_counts_and_percentages(breadth):
    b = breadth["Iron & Steel Products"]
    assert b["stocks"] == 88
    assert b["mcap_cr"] == pytest.approx(511783.33)   # Indian grouping
    assert b["above_sma200"] == pytest.approx(44.3)   # the "%" is stripped
    assert b["above_sma50"] == pytest.approx(30.7)
    assert b["momentum"] == pytest.approx(44.31)


def test_a_missing_breadth_file_reads_as_empty(tmp_path):
    assert ir.load_breadth(tmp_path / "nope.csv") == {}


def test_a_rise_carried_by_a_minority_is_flagged_narrow(breadth):
    picks = [{"industry": "Iron & Steel Products", "trailing": 56.8,
              "members": ["APLAPOLLO", "SURYAROSNI", "USHAMART", "WELCORP"]},
             {"industry": "Microfinance Institutions", "trailing": 12.0,
              "members": ["A", "B"]}]
    rows = {r["industry"]: r for r in ir.breadth_for_picks(picks, breadth)}
    narrow = rows["Iron & Steel Products"]
    assert narrow["narrow"] is True            # 44.3% < NARROW_SMA200
    assert narrow["stocks"] == 88 and narrow["in_universe"] == 4
    assert narrow["coverage_pct"] == pytest.approx(4.5)   # we hold 4 of 88
    assert rows["Microfinance Institutions"]["narrow"] is False


def test_an_industry_absent_from_the_export_says_so_rather_than_guessing(breadth):
    rows = ir.breadth_for_picks(
        [{"industry": "Nonesuch", "trailing": 1.0, "members": ["X"]}], breadth)
    assert rows[0]["breadth"] is None
    assert "not in the breadth export" in rows[0]["note"]
    assert rows[0]["held"] == 1
