"""
Hunter Scorer — 4-feature accumulation composite ranker.

Pure functions, no I/O. Takes a pandas DataFrame of daily OHLCV candles
(columns: open, high, low, close, volume; index: datetime ascending) and
a Nifty50 OHLCV DataFrame (same shape) for the relative-strength feature.

Outputs a per-symbol composite score 0-100 + the four sub-scores so we
can audit which feature drove each pick.

Features (all 0-100 percentile-ranked within current scan universe):
  F1 BB-squeeze       : Bollinger Band width at 6-month percentile (LOW = squeeze = high score)
  F2 RS-vs-Nifty      : 5d + 20d outperformance vs Nifty, weighted 60/40
  F3 Vol-pickup       : Last 2d vol vs 20d avg, only if price held tight range
  F4 Dist-from-52w-hi : Sweet spot 8-15% below 52w high (bell curve, peak at 11%)

Composite = equal-weighted mean of the four sub-scores.

Author: GIR-HUNTER v0.1   |   Date: May 16 2026
"""

from __future__ import annotations

import math
from dataclasses import dataclass, asdict, field
from typing import Optional

import numpy as np
import pandas as pd

# ============================================================================
# PAPER MODE (Phase 4B 2026-05-21) — record scoring decisions
# ============================================================================
import sys as _sys
_sys.path.insert(0, '/home/globalbot/paper')
try:
    from paper_trader import PAPER_MODE, record_event
except Exception as _paper_e:
    PAPER_MODE = False
    print(f"[SCORER WARNING] paper_trader import failed: {_paper_e}", file=_sys.stderr)
    def record_event(**kwargs): pass


# ============================================================================
# CONSTANTS — tuned for NSE daily data
# ============================================================================

MIN_CANDLES        = 50      # need ~2.5 months of history for BB + 52w features
BB_PERIOD          = 20      # standard Bollinger window
BB_STDEV           = 2.0
BB_LOOKBACK_DAYS   = 126     # ~6 months of trading days for percentile rank
RS_SHORT_DAYS      = 5
RS_LONG_DAYS       = 20
RS_SHORT_WEIGHT    = 0.60
RS_LONG_WEIGHT     = 0.40
VOL_AVG_DAYS       = 20
VOL_PICKUP_RATIO   = 1.5     # last 2d avg vol must exceed 20d avg by this
VOL_RANGE_DAYS     = 10      # check last 10d for tight range
VOL_RANGE_PCT      = 8.0     # range = (high-low)/close ≤ 8% over window (TUNED v0.2)
VOL_RANGE_TAPER_HI = 14.0    # range > 14% → multiplier 0 (was 10%)
HI52_WINDOW        = 252     # ~1 year trading days
HI52_SWEET_LOW     = 8.0     # min % below 52w high
HI52_SWEET_HIGH    = 15.0    # max % below 52w high
HI52_PEAK          = 11.0    # bell-curve peak inside sweet spot
HI52_SIGMA         = 4.0     # bell-curve width


# ============================================================================
# RESULT DATACLASS
# ============================================================================

@dataclass
class HunterScore:
    symbol: str
    composite: float
    bb_squeeze: float
    rs_vs_nifty: float
    vol_pickup: float
    dist_52w_hi: float
    # raw values for audit trail
    last_close: float
    bb_width_pct: float
    bb_width_rank: float
    rs_5d: float
    rs_20d: float
    vol_last2_ratio: float
    range_10d_pct: float
    pct_below_52w_hi: float
    candles_used: int

    # V219: quality gate fields (Trendlyne fundamentals)
    quality_score: float = 0.0
    quality_multiplier: float = 1.0
    quality_reasons: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)


# ============================================================================
# FEATURE 1 — Bollinger Band squeeze
# ============================================================================

def _bb_squeeze_score(df: pd.DataFrame) -> tuple[float, float, float]:
    """
    Compute BB-width percentile rank over last 6 months.
    Lower BB width (tighter squeeze) → higher score (more energy build-up).

    Returns (score_0_100, current_bb_width_pct_of_price, percentile_rank_0_100)
    """
    closes = df["close"]
    sma = closes.rolling(BB_PERIOD).mean()
    sd  = closes.rolling(BB_PERIOD).std(ddof=0)
    bb_width = (4.0 * sd) / sma * 100.0     # full-band width as % of mid

    current_w = float(bb_width.iloc[-1])
    lookback  = bb_width.tail(BB_LOOKBACK_DAYS).dropna()
    if len(lookback) < 30 or math.isnan(current_w):
        return (50.0, current_w if not math.isnan(current_w) else 0.0, 50.0)

    # percentile rank: what % of historical widths are GREATER than current
    # (current narrow → high % above it → high score)
    pct_above = (lookback > current_w).sum() / len(lookback) * 100.0
    return (float(pct_above), current_w, float(pct_above))


# ============================================================================
# FEATURE 2 — Relative strength vs Nifty
# ============================================================================

def _rs_score(df: pd.DataFrame, nifty: pd.DataFrame) -> tuple[float, float, float]:
    """
    Stock return minus Nifty return over 5d and 20d, weighted 60/40.
    Mapped to 0-100: -10% → 0, 0% → 50, +10% → 100 (clipped).

    Returns (score_0_100, rs_5d_pct, rs_20d_pct)
    """
    def _pct_return(series: pd.Series, days: int) -> float:
        if len(series) < days + 1:
            return 0.0
        return float((series.iloc[-1] / series.iloc[-1 - days] - 1.0) * 100.0)

    stock_5d  = _pct_return(df["close"],     RS_SHORT_DAYS)
    stock_20d = _pct_return(df["close"],     RS_LONG_DAYS)
    nifty_5d  = _pct_return(nifty["close"],  RS_SHORT_DAYS)
    nifty_20d = _pct_return(nifty["close"],  RS_LONG_DAYS)

    rs_5d  = stock_5d  - nifty_5d
    rs_20d = stock_20d - nifty_20d
    rs_blend = RS_SHORT_WEIGHT * rs_5d + RS_LONG_WEIGHT * rs_20d

    # map -10..+10 → 0..100, clip
    score = max(0.0, min(100.0, 50.0 + rs_blend * 5.0))
    return (score, rs_5d, rs_20d)


# ============================================================================
# FEATURE 3 — Volume pickup in tight range
# ============================================================================

def _vol_pickup_score(df: pd.DataFrame) -> tuple[float, float, float]:
    """
    Reward stocks where:
    - Last 2 days volume > 1.5× 20-day avg AND
    - Price stayed in a tight range (high-low spread ≤ 6% over last 10d)

    The combination = accumulation without breakout. Pure vol pickup with
    expanding range = chase. Pure tight range with no vol = dead.

    Returns (score_0_100, vol_last2_ratio, range_10d_pct)
    """
    vol = df["volume"]
    if len(vol) < VOL_AVG_DAYS + 2:
        return (0.0, 0.0, 0.0)

    last2_avg = float(vol.iloc[-2:].mean())
    avg20     = float(vol.iloc[-(VOL_AVG_DAYS + 2):-2].mean())
    vol_ratio = last2_avg / avg20 if avg20 > 0 else 0.0

    # range tightness over last 10d
    win = df.tail(VOL_RANGE_DAYS)
    range_pct = (win["high"].max() - win["low"].min()) / win["close"].mean() * 100.0

    # score blend: vol_ratio dominant, range gate as multiplier
    # vol_ratio 1.0 → 0, 1.5 → 50, 2.0 → 75, 3.0+ → 100
    vol_part = max(0.0, min(100.0, (vol_ratio - 1.0) * 50.0))

    # range gate: ≤8% → 1.0, 8-14% → linear taper to 0.3, >14% → 0.0
    if range_pct <= VOL_RANGE_PCT:
        range_mult = 1.0
    elif range_pct <= VOL_RANGE_TAPER_HI:
        range_mult = 1.0 - 0.7 * (range_pct - VOL_RANGE_PCT) / (VOL_RANGE_TAPER_HI - VOL_RANGE_PCT)
    else:
        range_mult = 0.0

    score = vol_part * range_mult
    return (float(score), float(vol_ratio), float(range_pct))


# ============================================================================
# FEATURE 4 — Distance from 52w high (sweet-spot bell curve)
# ============================================================================

def _dist_52w_score(df: pd.DataFrame) -> tuple[float, float]:
    """
    Bell-curve scoring: peak at 11% below 52w high, sigma = 4%.
    - At 52w high (0% below) → low score (chase risk)
    - 8-15% below → high score (post-breakout consolidation)
    - >25% below → low score (basement / deep retrace)

    Returns (score_0_100, pct_below_52w_hi)
    """
    win = df.tail(HI52_WINDOW)
    if len(win) < 30:
        return (50.0, 0.0)

    hi52  = float(win["high"].max())
    close = float(df["close"].iloc[-1])
    pct_below = (hi52 - close) / hi52 * 100.0 if hi52 > 0 else 0.0

    # gaussian centered at HI52_PEAK
    z = (pct_below - HI52_PEAK) / HI52_SIGMA
    score = 100.0 * math.exp(-0.5 * z * z)
    return (float(score), float(pct_below))


# ============================================================================
# PUBLIC ENTRY POINT
# ============================================================================


# ============================================================================
# V219 QUALITY GATE — Trendlyne fundamental signals
# ============================================================================
def _quality_score(symbol: str, trendlyne_quality):
    """V219 B2 quality gate + boost.

    Args:
        symbol: NSE symbol (for logging/audit).
        trendlyne_quality: dict of Trendlyne fields for this symbol, or None.

    Returns:
        (quality_score 0-100, multiplier 0.80-1.20, reasons list, rejected bool)

    HARD REJECTS (return rejected=True immediately):
        - Promoter pledge > 30%
        - Promoter pledge change QoQ > +5%
        - Promoter change QoQ < -2%
        - DVM_M < 30

    SOFT BOOST/PENALTY via multiplier (0.80-1.20):
        - DVM_M tiers (>70/>55/<40)
        - MF accumulation/distribution (>+/-0.5%)
        - FII accumulation (>+0.5%)
        - DVM_Class flag (Expensive/Underperformer)

    COMPOUND SOFT REJECT: multiplier < 0.85 AND DVM_M < 45
    """
    reasons = []

    if trendlyne_quality is None:
        return 50.0, 1.0, ["no_trendlyne_data"], False

    def _safe_float(key, default=0.0):
        v = trendlyne_quality.get(key, default)
        try:
            if v is None:
                return default
            fv = float(v)
            if math.isnan(fv):
                return default
            return fv
        except (TypeError, ValueError):
            return default

    # HARD REJECTS
    pledge = _safe_float('Promoter_Pledge', 0)
    if pledge > 30:
        return 0.0, 0.0, [f"REJECT_pledge_{pledge:.1f}pct"], True

    pledge_change = _safe_float('Promoter_Pledge_Change_QoQ', 0)
    if pledge_change > 5:
        return 0.0, 0.0, [f"REJECT_pledge_rising_{pledge_change:+.1f}pct"], True

    promoter_change = _safe_float('Promoter_Change_QoQ', 0)
    if promoter_change < -2:
        return 0.0, 0.0, [f"REJECT_promoter_dumping_{promoter_change:+.1f}pct"], True

    dvm_m = _safe_float('DVM_M', 50)
    if dvm_m < 30:
        return 0.0, 0.0, [f"REJECT_dvm_m_low_{dvm_m:.0f}"], True

    # SOFT QUALITY SCORE + MULTIPLIER
    score = 50.0
    multiplier = 1.0

    if dvm_m > 70:
        score += 20
        multiplier *= 1.10
        reasons.append(f"dvm_m_strong_{dvm_m:.0f}")
    elif dvm_m > 55:
        score += 10
        multiplier *= 1.05
        reasons.append(f"dvm_m_good_{dvm_m:.0f}")
    elif dvm_m < 40:
        score -= 10
        multiplier *= 0.95
        reasons.append(f"dvm_m_weak_{dvm_m:.0f}")

    mf_change = _safe_float('MF_Change_QoQ', 0)
    if mf_change > 0.5:
        score += 8
        multiplier *= 1.05
        reasons.append(f"mf_buying_{mf_change:+.2f}pct")
    elif mf_change < -0.5:
        score -= 8
        multiplier *= 0.95
        reasons.append(f"mf_selling_{mf_change:+.2f}pct")

    fii_change = _safe_float('FII_Change_QoQ', 0)
    if fii_change > 0.5:
        score += 5
        multiplier *= 1.03
        reasons.append(f"fii_buying_{fii_change:+.2f}pct")

    dvm_class = str(trendlyne_quality.get('DVM_Class', '') or '')
    if 'Expensive' in dvm_class or 'Underperformer' in dvm_class:
        score -= 5
        multiplier *= 0.95
        reasons.append(f"dvm_flag_{dvm_class[:20]}")

    # Cap
    multiplier = max(0.80, min(1.20, multiplier))
    score = max(0.0, min(100.0, score))

    # COMPOUND SOFT REJECT
    if multiplier < 0.85 and dvm_m < 45:
        reasons.append(f"REJECT_compound_mult{multiplier:.2f}_dvm{dvm_m:.0f}")
        return score, 0.0, reasons, True

    return score, multiplier, reasons, False


def score_symbol(
    symbol: str,
    df: pd.DataFrame,
    nifty: pd.DataFrame,
    trendlyne_quality=None,
) -> Optional[HunterScore]:
    """
    Score one symbol against the 4 accumulation features.

    Returns None if there isn't enough history (need ≥50 candles).
    """
    if df is None or len(df) < MIN_CANDLES or nifty is None or len(nifty) < MIN_CANDLES:
        try:
            record_event(
                module="hunter_scorer",
                event_type="REJECT",
                symbol=symbol,
                decision="REJECT",
                reason="insufficient_data",
                meta={
                    "df_len": (len(df) if df is not None else 0),
                    "nifty_len": (len(nifty) if nifty is not None else 0),
                    "min_candles": MIN_CANDLES,
                },
            )
        except Exception:
            pass
        return None

    # ensure sorted ascending by date
    df = df.sort_index()
    nifty = nifty.sort_index()

    bb_score,  bb_width, bb_rank   = _bb_squeeze_score(df)
    rs_score,  rs_5d,    rs_20d    = _rs_score(df, nifty)
    vol_score, vol_r,    range_pct = _vol_pickup_score(df)
    h52_score, pct_below            = _dist_52w_score(df)

    composite = (bb_score + rs_score + vol_score + h52_score) / 4.0

    # Paper-trader: log feature breakdown before V219 gate
    try:
        record_event(
            module="hunter_scorer",
            event_type="SCORE",
            symbol=symbol,
            decision="SCORED",
            reason="features_computed",
            composite_score=round(composite, 2),
            feature_breakdown={
                "bb_score": round(bb_score, 2),
                "bb_width": round(bb_width, 4),
                "bb_rank": round(bb_rank, 2),
                "rs_score": round(rs_score, 2),
                "rs_5d": round(rs_5d, 2),
                "rs_20d": round(rs_20d, 2),
                "vol_score": round(vol_score, 2),
                "vol_r": round(vol_r, 2),
                "range_pct": round(range_pct, 2),
                "h52_score": round(h52_score, 2),
                "pct_below_52w": round(pct_below, 2),
            },
            meta={"candles_used": len(df)},
        )
    except Exception:
        pass

    # V219: apply quality gate + multiplier
    q_score, q_mult, q_reasons, q_rejected = _quality_score(symbol, trendlyne_quality)
    if q_rejected:
        try:
            record_event(
                module="hunter_scorer",
                event_type="REJECT",
                symbol=symbol,
                strategy_tag="V219_quality_gate",
                decision="REJECT",
                reason="v219_hard_reject",
                composite_score=round(composite, 2),
                quality_score=round(q_score, 2),
                quality_multiplier=round(q_mult, 3),
                quality_reasons=list(q_reasons) if q_reasons else [],
            )
        except Exception:
            pass
        return None  # V219 hard reject — same return path as insufficient-data
    composite = composite * q_mult

    try:
        record_event(
            module="hunter_scorer",
            event_type="ACCEPT",
            symbol=symbol,
            strategy_tag="V219_passed",
            decision="ACCEPT",
            reason="passed_quality_gate",
            composite_score=round(composite, 2),
            quality_score=round(q_score, 2),
            quality_multiplier=round(q_mult, 3),
            quality_reasons=list(q_reasons) if q_reasons else [],
        )
    except Exception:
        pass

    return HunterScore(
        symbol=symbol,
        composite=round(composite, 2),
        bb_squeeze=round(bb_score, 2),
        rs_vs_nifty=round(rs_score, 2),
        vol_pickup=round(vol_score, 2),
        dist_52w_hi=round(h52_score, 2),
        last_close=round(float(df["close"].iloc[-1]), 2),
        bb_width_pct=round(bb_width, 3),
        bb_width_rank=round(bb_rank, 2),
        rs_5d=round(rs_5d, 2),
        rs_20d=round(rs_20d, 2),
        vol_last2_ratio=round(vol_r, 2),
        range_10d_pct=round(range_pct, 2),
        pct_below_52w_hi=round(pct_below, 2),
        candles_used=len(df),
        quality_score=round(q_score, 2),
        quality_multiplier=round(q_mult, 3),
        quality_reasons=q_reasons,
    )


# ============================================================================
# SELF-TEST  (run as: python3 scorer.py)
# ============================================================================

if __name__ == "__main__":
    # synthetic test data — uptrending stock with recent squeeze + vol spike
    np.random.seed(42)
    n = 200
    base = 100 + np.cumsum(np.random.normal(0.2, 1.5, n))
    df = pd.DataFrame({
        "open":   base + np.random.normal(0, 0.5, n),
        "high":   base + np.abs(np.random.normal(1.5, 0.7, n)),
        "low":    base - np.abs(np.random.normal(1.5, 0.7, n)),
        "close":  base,
        "volume": np.random.randint(100000, 500000, n),
    }, index=pd.date_range("2026-01-01", periods=n))

    nifty = pd.DataFrame({
        "open":   np.linspace(23000, 23700, n),
        "high":   np.linspace(23000, 23700, n) + 50,
        "low":    np.linspace(23000, 23700, n) - 50,
        "close":  np.linspace(23000, 23700, n),
        "volume": [1000000] * n,
    }, index=pd.date_range("2026-01-01", periods=n))

    score = score_symbol("TEST", df, nifty)
    if score:
        print(f"✓ Self-test passed")
        for k, v in score.to_dict().items():
            print(f"  {k:20s} = {v}")
    else:
        print("✗ Self-test failed — score is None")
