"""Tests for Thanikesa's valuation guard + Solaimalai's value/quality factors."""

import mayura
from sectorbot import config
from sectorbot import technicals as T
from sectorbot.stocks import load_fundamental_factors, load_valuations

FUND_HEADER = ("NSE Code,Trendlyne Durability Score,Trendlyne Valuation Score,"
               "PE TTM,PBV,Trendlyne Momentum Score,Day SMA50,Day SMA200,"
               "% Distance from 52week high\n")


def _write(tmp_path, name, body):
    p = tmp_path / name
    p.write_text(body)
    return p


# --- Thanikesa valuation guard --------------------------------------------
def test_load_valuations_present(tmp_path):
    p = _write(tmp_path, "thanikesa.csv",
               "NSE Code,Trendlyne Valuation Score,PE TTM\nAAA,33.8,57\nBBB,70,12\n")
    vals = load_valuations(p)
    assert vals["AAA"]["valuation"] == 33.8 and vals["BBB"]["valuation"] == 70


def test_load_valuations_absent_for_bare_list(tmp_path):
    p = _write(tmp_path, "thanikesa.csv", "NSE Code\nAAA\nBBB\n")
    assert load_valuations(p) == {}


def test_valuation_factor_curve():
    # defaults: FLOOR=20, FULL=55, MIN=0.65
    assert mayura._valuation_factor(70) == 1.0           # cheap -> no penalty
    assert mayura._valuation_factor(20) == config.THANIKESA_VALUATION_MIN_FACTOR
    mid = mayura._valuation_factor(37.5)                  # halfway
    assert config.THANIKESA_VALUATION_MIN_FACTOR < mid < 1.0


# --- Solaimalai value/quality factors -------------------------------------
def test_load_fundamental_factors(tmp_path):
    body = FUND_HEADER + (
        "CHEAPQUAL,80,80,12,1.5,60,100,90,5\n"     # cheap + high quality
        "EXPENSIVE,60,30,60,11,70,200,100,1\n"      # pricey
        "MIDQ,50,50,30,5,50,100,95,10\n"
    )
    p = _write(tmp_path, "solaimalai.csv", body)
    rows = load_fundamental_factors(p)
    assert len(rows) == 3
    by = {r["symbol"]: r for r in rows}
    # cheap+quality stock should have higher value & quality than the pricey one
    assert by["CHEAPQUAL"]["factors"]["value"] > by["EXPENSIVE"]["factors"]["value"]
    assert by["CHEAPQUAL"]["factors"]["quality"] > by["EXPENSIVE"]["factors"]["quality"]
    assert by["CHEAPQUAL"]["sma50"] == 100      # levels parsed for engine guards


def test_value_multifactor_ranks_cheap_quality_top(tmp_path):
    body = FUND_HEADER + (
        "CHEAPQUAL,85,85,11,1.2,55,100,90,5\n"
        "EXPENSIVE,55,28,62,12,75,210,100,1\n"
        "MIDQ,55,55,28,4,50,100,95,10\n"
    )
    p = _write(tmp_path, "solaimalai.csv", body)
    rows = load_fundamental_factors(p)
    scores = T.composite_zscore(rows, config.SOLAIMALAI_FUND_WEIGHTS)
    # value-led blend: the cheap, high-quality name must out-rank the pricey one
    assert scores["CHEAPQUAL"] > scores["EXPENSIVE"]


def test_load_fundamental_factors_empty_on_bare_list(tmp_path):
    # No fundamental columns -> all factors None -> no usable rows.
    p = _write(tmp_path, "solaimalai.csv", "NSE Code\nAAA\nBBB\n")
    assert load_fundamental_factors(p) == []
