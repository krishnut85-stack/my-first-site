"""Unit tests for the Early Bird detector (pure logic, no network)."""

import copy

from algotrade.earlybird.detector import DetectorConfig, chain_stats, detect


def make_chain(spot=100.0, dte=10, ce_oi=100_000, pe_oi=100_000,
               ce_ltp=3.0, pe_ltp=3.0, volume=10_000):
    strikes = []
    for k in (95.0, 100.0, 105.0):
        strikes.append({"strike": k, "type": "CE", "oi": ce_oi // 3,
                        "volume": volume, "ltp": ce_ltp})
        strikes.append({"strike": k, "type": "PE", "oi": pe_oi // 3,
                        "volume": volume, "ltp": pe_ltp})
    return {"spot": spot, "dte": dte, "strikes": strikes}


def snap(**chains):
    return {"ts": "2026-06-15T10:00:00", "symbols": chains}


CFG = DetectorConfig(min_score=70)


def test_chain_stats_iv_proxy_dte_normalized():
    s10 = chain_stats(make_chain(dte=10))
    s40 = chain_stats(make_chain(dte=40))
    # same straddle price at higher DTE => lower normalized IV proxy
    assert s40["iv_proxy"] < s10["iv_proxy"]
    assert s10["ce_oi"] == s10["pe_oi"] > 0


def test_put_writing_bullish_signal():
    base = snap(TATAPOWER=make_chain())
    latest = snap(TATAPOWER=make_chain(spot=101.0, pe_oi=140_000, pe_ltp=3.6))
    sigs = detect(base, latest, CFG)
    assert len(sigs) == 1
    assert sigs[0]["pattern"] == "PUT_WRITING"
    assert sigs[0]["direction"] == "BULLISH"
    assert sigs[0]["score"] >= 70


def test_call_writing_bearish_signal():
    base = snap(INFY=make_chain())
    latest = snap(INFY=make_chain(spot=99.0, ce_oi=140_000))
    sigs = detect(base, latest, CFG)
    assert sigs and sigs[0]["pattern"] == "CALL_WRITING"
    assert sigs[0]["direction"] == "BEARISH"


def test_quiet_market_no_signal():
    base = snap(RELIANCE=make_chain())
    latest = snap(RELIANCE=make_chain(spot=100.1, ce_oi=103_000, pe_oi=102_000))
    assert detect(base, latest, CFG) == []


def test_unusual_volume_watch_signal():
    base = snap(KAYNES=make_chain())
    chain = make_chain(spot=100.1)
    chain["strikes"][0]["volume"] = chain["strikes"][0]["oi"] * 5  # 5x vol/OI
    latest = snap(KAYNES=chain)
    sigs = detect(base, latest, DetectorConfig(min_score=60))
    assert sigs and sigs[0]["pattern"] == "UNUSUAL_VOLUME"


def test_no_baseline_means_no_signals():
    latest = snap(SBIN=make_chain(spot=105.0, pe_oi=200_000))
    assert detect(None, latest, CFG) == []


def test_iv_expansion_raises_score():
    base = snap(HDFCBANK=make_chain())
    flat = snap(HDFCBANK=make_chain(spot=101.0, pe_oi=140_000))
    rich = copy.deepcopy(flat)
    for s in rich["symbols"]["HDFCBANK"]["strikes"]:
        s["ltp"] *= 1.5  # straddle 50% richer => IV proxy up
    s_flat = detect(base, flat, CFG)[0]["score"]
    s_rich = detect(base, rich, CFG)[0]["score"]
    assert s_rich > s_flat
