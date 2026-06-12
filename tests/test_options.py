import math

import pytest

from algotrade.instruments import OptionType
from algotrade.options import bs_greeks, bs_price, implied_volatility


SPOT, STRIKE, T, VOL, R = 24_500.0, 24_500.0, 7 / 365, 0.14, 0.065


def test_put_call_parity():
    call = bs_price(SPOT, STRIKE, T, VOL, OptionType.CALL, R)
    put = bs_price(SPOT, STRIKE, T, VOL, OptionType.PUT, R)
    parity = SPOT - STRIKE * math.exp(-R * T)
    assert call - put == pytest.approx(parity, abs=1e-6)


def test_intrinsic_at_expiry():
    assert bs_price(24_600, 24_500, 0.0, VOL, OptionType.CALL) == 100.0
    assert bs_price(24_600, 24_500, 0.0, VOL, OptionType.PUT) == 0.0


def test_greeks_sanity():
    g = bs_greeks(SPOT, STRIKE, T, VOL, OptionType.CALL, R)
    assert 0.45 < g.delta < 0.60  # ATM call delta near 0.5
    assert g.gamma > 0
    assert g.theta < 0            # long options decay
    assert g.vega > 0
    p = bs_greeks(SPOT, STRIKE, T, VOL, OptionType.PUT, R)
    assert -0.55 < p.delta < -0.40
    assert p.gamma == pytest.approx(g.gamma)


def test_implied_vol_round_trip():
    price = bs_price(SPOT, STRIKE, T, 0.18, OptionType.CALL, R)
    iv = implied_volatility(price, SPOT, STRIKE, T, OptionType.CALL, R)
    assert iv == pytest.approx(0.18, abs=1e-4)
