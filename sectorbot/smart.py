"""Mayura's SMART layer — a Trendlyne-style DVM score (Durability, Valuation,
Momentum) computed from the columns your CSV already contains.

This is the "smart bot using max features" brain. Trendlyne's flagship metric is
the **DVM Score**; here we reconstruct the same three pillars from the raw
fundamentals you export, so Mayura ranks on quality + value + trend instead of
momentum alone:

  • Durability  — is the business financially strong?  (ROE, ROA, profit &
                  revenue growth, the provider's Industry Score)
  • Valuation   — is it reasonably priced?             (PEG, PE, Price/Book,
                  dividend yield)  ← cheaper scores higher
  • Momentum    — is the trend strong AND consistent?  (week/month/qtr/half/year
                  change + market breadth, with an alignment bonus)

Every pillar is 0–100. Missing columns are skipped and the remaining weights
re-normalised, so a leaner CSV still produces a sensible score (graceful
degrade). Nothing here predicts the future — it only summarises the data.
"""

from typing import Optional

from . import config


def _high(value: Optional[float], lo: float, hi: float) -> Optional[float]:
    """Higher is better: map value in [lo,hi] to 0–100 (None stays None)."""
    if value is None:
        return None
    if hi == lo:
        return 50.0
    return max(0.0, min(100.0, (value - lo) / (hi - lo) * 100.0))


def _low(value: Optional[float], lo: float, hi: float) -> Optional[float]:
    """Lower is better (e.g. PE, PEG): map [lo,hi] to 100–0. <=lo -> 100."""
    if value is None:
        return None
    if hi == lo:
        return 50.0
    return max(0.0, min(100.0, (hi - value) / (hi - lo) * 100.0))


def _blend(components: list[tuple[Optional[float], float]]) -> Optional[float]:
    """Weighted average of (sub_score, weight), ignoring None components and
    re-normalising the surviving weights. Returns None if nothing is present."""
    present = [(s, w) for s, w in components if s is not None and w > 0]
    if not present:
        return None
    total_w = sum(w for _, w in present)
    return sum(s * w for s, w in present) / total_w


def durability_score(ind) -> Optional[float]:
    """How financially strong the industry is (0–100, higher better)."""
    return _blend([
        (_high(ind.roe, 0, 30), 0.30),
        (_high(ind.roa, 0, 15), 0.15),
        (_high(ind.net_profit_growth, -10, 40), 0.25),
        (_high(ind.rev_growth, -10, 40), 0.20),
        (_high(ind.industry_score, 0, 70), 0.10),
    ])


def valuation_score(ind) -> Optional[float]:
    """How reasonably priced (0–100). Cheaper relative to growth scores higher.
    A momentum strategy never buys ONLY cheap names, so this is a tilt, not a
    hard gate — but it stops Mayura paying any price for momentum."""
    # PEG and PE can be absent (None) for loss-making / no-growth industries.
    peg = ind.peg if (ind.peg is not None and ind.peg > 0) else None
    pe = ind.pe if (ind.pe is not None and ind.pe > 0) else None
    pbv = ind.pbv if (ind.pbv is not None and ind.pbv > 0) else None
    return _blend([
        (_low(peg, 0.8, 3.0), 0.35),     # PEG ~1 is the sweet spot
        (_low(pe, 10, 70), 0.30),
        (_low(pbv, 1, 12), 0.25),
        (_high(ind.div_yield, 0, 3), 0.10),
    ])


def momentum_score(ind) -> Optional[float]:
    """Trend strength + consistency (0–100). Multi-timeframe change blended with
    market breadth, plus a bonus when EVERY timeframe is positive (a clean,
    aligned uptrend is worth more than one spiky number)."""
    base = _blend([
        (_high(ind.week_change, -5, 10), 0.10),
        (_high(ind.month_change, -10, 20), 0.20),
        (_high(ind.qtr_change, -10, 40), 0.25),
        (_high(ind.half_change, -10, 60), 0.20),
        (_high(ind.year_change, -20, 80), 0.15),
        # sector_breadth_score is already 0–100 (set before this is called)
        (ind.sector_breadth_score or None, 0.10),
    ])
    if base is None:
        return None
    # Alignment bonus: reward a fully-stacked uptrend across all timeframes.
    frames = [ind.week_change, ind.month_change, ind.qtr_change,
              ind.half_change, ind.year_change]
    positives = sum(1 for f in frames if f > 0)
    bonus = (positives / len(frames)) * config.SMART_ALIGNMENT_BONUS  # 0..bonus
    return max(0.0, min(100.0, base + bonus))


def compute_dvm(ind) -> Optional[float]:
    """Attach durability/valuation/momentum + the blended smart_score to an
    Industry and return the smart_score (0–100), or None if nothing computable.

    Call this AFTER sector_breadth_score is set so the momentum pillar can use
    breadth. Weights live in config.SMART_WEIGHTS."""
    ind.durability = durability_score(ind)
    ind.valuation = valuation_score(ind)
    ind.momentum = momentum_score(ind)
    w = config.SMART_WEIGHTS
    ind.smart_score = _blend([
        (ind.durability, w["durability"]),
        (ind.valuation, w["valuation"]),
        (ind.momentum, w["momentum"]),
    ])
    return ind.smart_score
