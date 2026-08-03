"""Tests for sector-breadth loading, scoring and the fundamentals blend."""

import textwrap

import pytest

from sectorbot import config
from sectorbot.breadth import _pct, load_breadth, normalize_sector
from sectorbot.data_loader import classify_csv, resolve_breadth_csv, resolve_csv
from sectorbot.screener import load_industries, score_industries


BREADTH_CSV = textwrap.dedent("""\
    S.No,NAME,NO. OF STOCKS,MARKET CAP,MOMENTUM SCORE,RSI > 50,MFI > 50,LTP > SMA20,LTP > SMA50,LTP > SMA200,SMA50 > SMA200,DAY GAINERS%,WEEK GAINERS%
    1,Metals & Mining,221,"27,30,770.24",47.47,30.10%,26.50%,32%,27.90%,80.50%,81.30%,78.10%,61.40%
    2,General Industrials,417,"36,25,303.66",60.91,95.30%,88.80%,95.90%,94.10%,87.10%,75.70%,55.30%,95.70%
""")


def test_pct_parsing():
    assert _pct("30.10%") == 30.10
    assert _pct("1,234") == 1234
    assert _pct("-") == 0.0
    assert _pct("") == 0.0
    assert _pct(None) == 0.0


def test_normalize_sector_matches_amp_and_and():
    assert normalize_sector("Banking & Finance") == normalize_sector("Banking and Finance")
    assert normalize_sector("Food, Beverages & Tobacco") == "food beverages and tobacco"


def test_load_breadth_scores_range(tmp_path):
    p = tmp_path / "breadth.csv"
    p.write_text(BREADTH_CSV)
    data = load_breadth(p)
    assert "metals and mining" in data
    assert "general industrials" in data
    # all-bullish General Industrials should outscore weak Metals & Mining
    assert data["general industrials"]["score"] > data["metals and mining"]["score"]
    for v in data.values():
        assert 0 <= v["score"] <= 100


def test_classify_breadth_vs_fundamentals(tmp_path):
    b = tmp_path / "b.csv"
    b.write_text(BREADTH_CSV)
    assert classify_csv(b) == "breadth"
    assert classify_csv(config.DATA_CSV) == "fundamentals"


def test_breadth_file_not_used_as_main(tmp_path, monkeypatch):
    b = tmp_path / "2026-06-22.csv"   # dated, but breadth content
    b.write_text(BREADTH_CSV)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    monkeypatch.setattr(config, "CSV_OVERRIDE", "")
    # breadth file must NOT be picked as the main fundamentals file
    assert resolve_csv() == config.DATA_CSV
    assert resolve_breadth_csv().name == "2026-06-22.csv"


def test_blend_changes_scores(tmp_path, monkeypatch):
    # This test exercises the legacy fundamental+breadth formula directly, so
    # pin the smart DVM brain off (it has its own tests in test_smart.py).
    monkeypatch.setattr(config, "USE_SMART_SCORE", False)
    p = tmp_path / "breadth.csv"
    p.write_text(BREADTH_CSV)
    breadth = load_breadth(p)

    inds = load_industries(config.DATA_CSV)
    with_blend = {i.name: i.score for i in score_industries(load_industries(config.DATA_CSV), breadth=breadth)}
    no_blend = {i.name: i.score for i in score_industries(load_industries(config.DATA_CSV), breadth={})}

    # an industry in a covered sector (Metals & Mining) should differ once blended
    metals = [i for i in inds if i.sector == "Metals & Mining"]
    assert metals, "expected at least one Metals & Mining industry"
    name = metals[0].name
    assert with_blend[name] != no_blend[name]


INDUSTRY_BREADTH_CSV = textwrap.dedent("""\
    S.No,NAME,NO. OF STOCKS,MARKET CAP,MOMENTUM SCORE,RSI > 50,MFI > 50,LTP > SMA20,LTP > SMA50,LTP > SMA200,SMA50 > SMA200,DAY GAINERS%,WEEK GAINERS%
    1,Aluminium and Aluminium Products,24,"6,11,015.7",99.0,100%,100%,100%,100%,100%,100%,100%,100%
""")


def test_multiple_breadth_files_merge(tmp_path, monkeypatch):
    (tmp_path / "sector-breadth.csv").write_text(BREADTH_CSV)
    (tmp_path / "industry-breadth.csv").write_text(INDUSTRY_BREADTH_CSV)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    from sectorbot.breadth import load_breadth_scores

    merged = load_breadth_scores()
    # contains both a sector key and an industry key
    assert "metals and mining" in merged
    assert "aluminium and aluminium products" in merged


def test_industry_breadth_preferred_over_sector(tmp_path, monkeypatch):
    # sector file: Metals & Mining (weak). industry file: the industry itself
    # (all-bullish -> ~100). The industry's own breadth must win.
    (tmp_path / "sector-breadth.csv").write_text(BREADTH_CSV)
    (tmp_path / "industry-breadth.csv").write_text(INDUSTRY_BREADTH_CSV)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)

    ranked = score_industries(load_industries(config.DATA_CSV))
    alu = next(i for i in ranked if i.name == "Aluminium and Aluminium Products")
    # industry-level all-bullish breadth ~ very high, not the weak Metals sector
    assert alu.sector_breadth_score > 90


def test_blend_respects_toggle(monkeypatch, tmp_path):
    monkeypatch.setattr(config, "USE_SMART_SCORE", False)  # test legacy formula
    p = tmp_path / "breadth.csv"
    p.write_text(BREADTH_CSV)
    breadth = load_breadth(p)
    monkeypatch.setattr(config, "USE_BREADTH_BLEND", False)
    ranked = score_industries(load_industries(config.DATA_CSV), breadth=breadth)
    # with blend off, score == fundamental_score
    assert all(abs(i.score - i.fundamental_score) < 1e-9 for i in ranked)
