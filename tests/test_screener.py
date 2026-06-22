"""Tests for the screener: parsing, scoring, ranking, PE filter."""

from sectorbot import config
from sectorbot.screener import (
    _num,
    load_industries,
    score_industries,
    top_industries,
)


def test_num_parsing():
    assert _num("1,282.26") == 1282.26
    assert _num("-3.17") == -3.17
    assert _num("-") is None
    assert _num("") is None
    assert _num(None) is None


def test_load_industries_nonempty():
    inds = load_industries(config.DATA_CSV)
    assert len(inds) > 50
    assert all(i.name for i in inds)


def test_scoring_sorted_desc():
    ranked = score_industries(load_industries(config.DATA_CSV))
    scores = [i.score for i in ranked]
    assert scores == sorted(scores, reverse=True)


def test_top_industries_respects_pe_filter():
    picks = top_industries(n=8, max_pe=60, csv_path=config.DATA_CSV)
    assert len(picks) <= 8
    # every pick must be at/under the PE cap (or have unknown PE)
    assert all(p.pe is None or p.pe <= 60 for p in picks)


def test_overheated_industry_excluded():
    # Telecom Cables (PE ~92) is top-scored but must be filtered out at max_pe=60
    picks = top_industries(n=10, max_pe=60, csv_path=config.DATA_CSV)
    names = {p.name for p in picks}
    assert "Telecom Cables" not in names
