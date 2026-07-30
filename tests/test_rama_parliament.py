"""Tests for Rama's SEPARATE Parliament audit panel. All offline: provider stays
'rules', so no LLM/network is touched. Confirms the panel reaches sane consensus,
the executor vetoes/accepts correctly, the fallback chain holds, and enable()
wires cleanly into Rama's audit hook without disturbing the core engine."""

import pytest

from rama import config
from rama.screener import Industry
from rama.parliament import analyst, panel, executor, enable, disable


def _ind(score=60.0, pe=25):
    return Industry(name="Wires & Cables", sector="Ind", day_change=0,
                    industry_score=0, qtr_change=0, half_change=0, year_change=0,
                    roe=0, rev_growth=0, breadth=0, pe=pe, score=score)


@pytest.fixture(autouse=True)
def _rules_only(monkeypatch, tmp_path):
    monkeypatch.setattr(config, "PARLIAMENT_PROVIDER", "rules")
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    yield
    disable()  # never leak the hook into other tests


# --- lenses -----------------------------------------------------------------

def test_trend_lens_avoids_downtrend():
    v = analyst.trend_lens("KEI", _ind(), {"uptrend": False})
    assert v.vote == "AVOID"


def test_insider_lens_reads_catalyst():
    assert analyst.insider_lens("X", _ind(), {"catalyst_score": -0.9}).vote == "AVOID"
    assert analyst.insider_lens("X", _ind(), {"catalyst_score": 0.5}).vote == "BUY"


# --- panel consensus --------------------------------------------------------

def test_panel_healthy_candidate_buys():
    r = panel.deliberate("KEI", _ind(score=70, pe=25),
                         {"uptrend": True, "catalyst_score": 0.4})
    assert r["vote"] == "BUY"
    assert r["used_llm"] is False           # rules-only, no provider
    assert r["verdicts"]                     # full deliberation captured


def test_panel_vetoes_downtrend_plus_insider_selling():
    r = panel.deliberate("SUZLON", _ind(score=70, pe=25),
                         {"uptrend": False, "catalyst_score": -0.9})
    assert r["vote"] == "AVOID"
    assert r["confidence"] > 0


# --- executor (the hook Rama calls) ----------------------------------------

def test_executor_vetoes_and_accepts(monkeypatch):
    monkeypatch.setattr(config, "PARLIAMENT_MIN_CONFIDENCE", 0.6)
    ok, reason = executor.audit_hook("SUZLON", _ind(score=70),
                                     {"uptrend": False, "catalyst_score": -0.9})
    assert ok is False and "AVOID" in reason
    ok2, reason2 = executor.audit_hook("KEI", _ind(score=70, pe=25),
                                       {"uptrend": True, "catalyst_score": 0.4})
    assert ok2 is True


# --- fallback chain: a broken LLM provider must not break the panel ---------

def test_fallback_when_llm_fails(monkeypatch):
    monkeypatch.setattr(config, "PARLIAMENT_PROVIDER", "gemini")
    monkeypatch.setattr(config, "GEMINI_API_KEY", "")   # no key -> llm_analyst raises
    r = panel.deliberate("KEI", _ind(score=70, pe=25),
                         {"uptrend": True, "catalyst_score": 0.4})
    assert r["used_llm"] is False        # dropped the LLM, rules carried the call
    assert r["vote"] in ("BUY", "HOLD", "AVOID")


# --- enable() wires into the audit hook, disable() reverts ------------------

def test_enable_installs_hook_then_reverts():
    from rama import audit
    assert audit.external_auditor is None
    enable()
    assert audit.external_auditor is executor.audit_hook
    # a healthy candidate passes the built-in rules, THEN runs through Parliament
    # via the hook — so the surfaced reason is Parliament's own verdict.
    res = audit.audit_candidate("KEI", _ind(score=70, pe=25), ltp=100.0,
                                uptrend=True, catalyst_score=0.4)
    assert res.ok and "Parliament" in res.reason
    disable()
    assert audit.external_auditor is None
