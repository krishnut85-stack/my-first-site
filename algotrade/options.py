"""Black-Scholes pricing, Greeks, and implied volatility for index options.

European-style pricing is appropriate for NSE index options. Rates and time
are annualised; volatility is expressed as a decimal (0.15 = 15%).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from .instruments import OptionType

_SQRT_2PI = math.sqrt(2.0 * math.pi)


def _norm_pdf(x: float) -> float:
    return math.exp(-0.5 * x * x) / _SQRT_2PI

def _norm_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


@dataclass(frozen=True)
class Greeks:
    price: float
    delta: float
    gamma: float
    theta: float  # per calendar day
    vega: float   # per 1 vol point (1%)
    rho: float    # per 1% rate move


def _d1_d2(spot: float, strike: float, t: float, r: float, sigma: float):
    d1 = (math.log(spot / strike) + (r + 0.5 * sigma * sigma) * t) / (
        sigma * math.sqrt(t)
    )
    return d1, d1 - sigma * math.sqrt(t)


def bs_price(
    spot: float,
    strike: float,
    t_years: float,
    sigma: float,
    option_type: OptionType,
    r: float = 0.065,
) -> float:
    """Black-Scholes price. t_years must be > 0; at expiry use intrinsic value."""
    if t_years <= 0:
        intrinsic = spot - strike if option_type is OptionType.CALL else strike - spot
        return max(intrinsic, 0.0)
    d1, d2 = _d1_d2(spot, strike, t_years, r, sigma)
    if option_type is OptionType.CALL:
        return spot * _norm_cdf(d1) - strike * math.exp(-r * t_years) * _norm_cdf(d2)
    return strike * math.exp(-r * t_years) * _norm_cdf(-d2) - spot * _norm_cdf(-d1)


def bs_greeks(
    spot: float,
    strike: float,
    t_years: float,
    sigma: float,
    option_type: OptionType,
    r: float = 0.065,
) -> Greeks:
    if t_years <= 0:
        raise ValueError("Greeks are undefined at or after expiry (t_years <= 0)")
    d1, d2 = _d1_d2(spot, strike, t_years, r, sigma)
    pdf_d1 = _norm_pdf(d1)
    gamma = pdf_d1 / (spot * sigma * math.sqrt(t_years))
    vega = spot * pdf_d1 * math.sqrt(t_years) / 100.0
    disc = math.exp(-r * t_years)

    if option_type is OptionType.CALL:
        delta = _norm_cdf(d1)
        theta = (
            -spot * pdf_d1 * sigma / (2.0 * math.sqrt(t_years))
            - r * strike * disc * _norm_cdf(d2)
        )
        rho = strike * t_years * disc * _norm_cdf(d2) / 100.0
    else:
        delta = _norm_cdf(d1) - 1.0
        theta = (
            -spot * pdf_d1 * sigma / (2.0 * math.sqrt(t_years))
            + r * strike * disc * _norm_cdf(-d2)
        )
        rho = -strike * t_years * disc * _norm_cdf(-d2) / 100.0

    price = bs_price(spot, strike, t_years, sigma, option_type, r)
    return Greeks(
        price=price,
        delta=delta,
        gamma=gamma,
        theta=theta / 365.0,
        vega=vega,
        rho=rho,
    )


def implied_volatility(
    market_price: float,
    spot: float,
    strike: float,
    t_years: float,
    option_type: OptionType,
    r: float = 0.065,
    tol: float = 1e-6,
    max_iter: int = 100,
) -> float:
    """Implied vol via bisection (robust for far OTM strikes where Newton fails)."""
    lo, hi = 1e-4, 5.0
    if not (
        bs_price(spot, strike, t_years, lo, option_type, r)
        <= market_price
        <= bs_price(spot, strike, t_years, hi, option_type, r)
    ):
        raise ValueError("market price outside arbitrage-free bounds for vol search")
    for _ in range(max_iter):
        mid = 0.5 * (lo + hi)
        price = bs_price(spot, strike, t_years, mid, option_type, r)
        if abs(price - market_price) < tol:
            return mid
        if price < market_price:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def years_to_expiry(days: float) -> float:
    """Calendar-day convention; pass fractional days for intraday precision."""
    return days / 365.0
