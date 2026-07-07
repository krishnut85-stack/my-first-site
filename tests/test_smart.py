"""Tests for Mayura's smart DVM scoring layer."""

from sectorbot import config
from sectorbot.screener import load_industries, score_industries
from sectorbot.smart import _blend, _high, _low, compute_dvm


def test_high_low_normalisation():
    assert _high(None, 0, 10) is None
    assert _high(0, 0, 10) == 0.0
    assert _high(10, 0, 10) == 100.0
    assert _high(5, 0, 10) == 50.0
    assert _high(99, 0, 10) == 100.0      # clamped
    # lower-is-better
    assert _low(0, 0, 10) == 100.0
    assert _low(10, 0, 10) == 0.0
    assert _low(None, 0, 10) is None


def test_blend_ignores_missing_and_renormalises():
    assert _blend([]) is None
    assert _blend([(None, 1.0)]) is None
    # one present component -> just that value
    assert _blend([(80.0, 0.5), (None, 0.5)]) == 80.0
    # renormalised average
    assert _blend([(100.0, 0.5), (0.0, 0.5)]) == 50.0


def test_dvm_pillars_in_range():
    inds = load_industries(config.DATA_CSV)
    for ind in inds:
        # breadth pillar reads sector_breadth_score; default 0 is fine here
        compute_dvm(ind)
        for pillar in (ind.durability, ind.valuation, ind.momentum,
                       ind.smart_score):
            assert pillar is None or 0.0 <= pillar <= 100.0


def test_smart_score_sorts_and_populates(monkeypatch):
    monkeypatch.setattr(config, "USE_SMART_SCORE", True)
    ranked = score_industries(load_industries(config.DATA_CSV))
    scores = [i.score for i in ranked]
    assert scores == sorted(scores, reverse=True)
    # at least the top names should have a computed DVM breakdown
    top = ranked[0]
    assert top.smart_score is not None
    assert top.durability is not None
    assert top.momentum is not None


def test_smart_toggle_changes_ranking(monkeypatch):
    base = load_industries(config.DATA_CSV)
    monkeypatch.setattr(config, "USE_SMART_SCORE", False)
    legacy = [i.name for i in score_industries(load_industries(config.DATA_CSV))]
    monkeypatch.setattr(config, "USE_SMART_SCORE", True)
    smart = [i.name for i in score_industries(load_industries(config.DATA_CSV))]
    # both rank the same universe...
    assert set(legacy) == set(smart) == {i.name for i in base}
    # ...but the smart brain should reorder at least some names
    assert legacy != smart
