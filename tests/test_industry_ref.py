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
