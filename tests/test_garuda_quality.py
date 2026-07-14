"""Tests for LAB QUALITY — the Trendlyne screen diagnostic."""

import json

from garuda.lab_quality import (base_effect, examine, format_report,
                                held_by_books, load_screen, momentum_ranks)

HEADER = ('"Sl No","Stock","Market Cap","Promoter pledge change QoQ %",'
          '"ROCE Ann  %","Rev  Ann  3Y Growth %","Net Profit Ann  YoY Growth %",'
          '"Net Profit Qtr Growth YoY %","Net Profit 3Y Growth %",'
          '"NSE code","NSE Code","BSE Code","ISIN"\n')


def _screen(tmp_path):
    p = tmp_path / "screen.csv"
    p.write_text(
        HEADER
        + '"1","Good Co","4607.14","0","22.68","40.59","28.07","87.97","75.21",'
          '"GOODCO","GOODCO","532884","INE056I01025"\n'
        + '"2","Mirage Co","1026.44","0","16.48","2138.66","17971.68","6801.52",'
          '"15706.05","MIRAGE","MIRAGE","526935","INE377D01018"\n'
        + '"3","BSE Only","3457.49","0","16.62","62.96","54.97","91.07","129.93",'
          '"11625592","","543542","INE0L1C01019"\n')
    return p


def test_load_screen_symbols_and_numbers(tmp_path):
    rows = load_screen(_screen(tmp_path))
    assert [r["symbol"] for r in rows] == ["GOODCO", "MIRAGE", None]
    assert rows[0]["mcap"] == 4607.14 and rows[0]["roce"] == 22.68
    assert rows[0]["np3y"] == 75.21


def test_base_effect_flags(tmp_path):
    rows = load_screen(_screen(tmp_path))
    assert not base_effect(rows[0])          # 40% rev / 75% np3y — sane
    assert base_effect(rows[1])              # 2138% rev growth — mirage


def test_momentum_ranks_percentiles():
    dated = {
        "HOT":  [(f"d{i:03d}", 100.0 * (1.004 ** i)) for i in range(260)],
        "FLAT": [(f"d{i:03d}", 100.0) for i in range(260)],
        "COLD": [(f"d{i:03d}", 100.0 * (0.998 ** i)) for i in range(260)],
    }
    ranks = momentum_ranks(dated)
    assert ranks["HOT"] > ranks["FLAT"] > ranks["COLD"]
    assert ranks["COLD"] == 0
    # universe restriction drops outsiders
    assert "FLAT" not in momentum_ranks(dated, universe={"HOT", "COLD"})


def test_held_by_books(tmp_path):
    (tmp_path / "garuda_smallcap_portfolio.json").write_text(
        json.dumps({"holdings": {"GOODCO": {"qty": 10}}}))
    (tmp_path / "garuda_chakra_portfolio.json").write_text(
        json.dumps({"holdings": {"GOODCO": {"qty": 5}, "OTHER": {"qty": 1}}}))
    held = held_by_books(tmp_path)
    assert held["GOODCO"] == ["chakra", "smallcap"]
    assert held["OTHER"] == ["chakra"]


def test_examine_and_report(tmp_path):
    rows = load_screen(_screen(tmp_path))
    ex = examine(rows, smallcap={"GOODCO"}, ranks={"GOODCO": 85},
                 held={"GOODCO": ["smallcap"]})
    assert [r["symbol"] for r in ex["clean"]] == ["GOODCO"]
    assert [r["symbol"] for r in ex["flagged"]] == ["MIRAGE"]
    assert len(ex["untradable"]) == 1
    txt = format_report(ex)
    assert "NOT a backtest" in txt
    assert "GOODCO" in txt and "MIRAGE" in txt and "BSE Only" in txt
    assert "1/1 clean names" in txt          # smallcap overlap line
