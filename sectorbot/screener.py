"""Load the sector/industry CSV and rank industries with a transparent score.

The score is a plain weighted blend of momentum + quality columns. It is NOT a
prediction of the future -- it just summarises what the data already shows.
"""

import csv
from dataclasses import dataclass
from typing import Optional

from . import config
from .breadth import load_breadth_scores, normalize_sector
from .data_loader import resolve_csv


def _num(value: Optional[str]) -> Optional[float]:
    """Parse a CSV cell like '1,282.26' or '-' into a float (or None)."""
    if value is None:
        return None
    value = value.replace(",", "").strip()
    if value in ("", "-"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _cap(value: Optional[float], lo: float, hi: float) -> float:
    """Clamp a value so a few extreme outliers can't dominate the score."""
    if value is None:
        return 0.0
    return max(lo, min(hi, value))


@dataclass
class Industry:
    name: str
    sector: str
    day_change: float
    industry_score: float
    qtr_change: float
    half_change: float
    year_change: float
    roe: float
    rev_growth: float
    breadth: float
    pe: Optional[float]
    score: float = 0.0
    fundamental_score: float = 0.0   # score before the breadth blend
    sector_breadth_score: float = 0.0  # 0-100 breadth of this industry's sector


def load_industries(csv_path=None) -> list[Industry]:
    csv_path = resolve_csv(csv_path)
    out: list[Industry] = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            iscore = _num(row.get("Industry Score"))
            qtr = _num(row.get("Qtr Change %"))
            half = _num(row.get("Half Yr Change %"))
            if iscore is None or qtr is None or half is None:
                continue
            out.append(
                Industry(
                    name=row["Name"].strip(),
                    sector=row["Sector"].strip(),
                    day_change=_num(row.get("Day Change %")) or 0.0,
                    industry_score=iscore,
                    qtr_change=qtr,
                    half_change=half,
                    year_change=_num(row.get("1Yr Change %")) or 0.0,
                    roe=_num(row.get("Return on Equity Annual")) or 0.0,
                    rev_growth=_num(row.get("Revenue growth Qtr YoY%")) or 0.0,
                    breadth=_num(row.get("Advances/ Declines Ratio")) or 0.0,
                    pe=_num(row.get("PE TTM")),
                )
            )
    return out


def score_industries(industries: list[Industry], breadth=None) -> list[Industry]:
    """Attach a score to each industry and return them sorted, best first.

    If a sector-breadth map is available (or auto-loaded), each industry's
    fundamental score is blended with its sector's breadth score.
    """
    if breadth is None:
        breadth = load_breadth_scores()
    w = config.WEIGHTS
    for ind in industries:
        fund = (
            _cap(ind.qtr_change, -50, 80) * w["qtr_change"]
            + _cap(ind.half_change, -50, 120) * w["half_change"]
            + _cap(ind.year_change, -60, 150) * w["year_change"]
            + _cap(ind.industry_score, 0, 80) * w["industry_score"]
            + _cap(ind.roe, -20, 40) * w["roe"]
            + _cap(ind.rev_growth, -50, 80) * w["rev_growth"]
            + _cap(ind.breadth, 0, 13) * w["breadth"] * 5
        )
        ind.fundamental_score = fund
        # prefer industry-level breadth (exact name), fall back to sector-level
        b = None
        if breadth:
            b = breadth.get(normalize_sector(ind.name)) or breadth.get(
                normalize_sector(ind.sector)
            )
        ind.sector_breadth_score = b["score"] if b else 0.0
        if config.USE_BREADTH_BLEND and b:
            ind.score = (
                fund * config.BLEND_FUNDAMENTAL_WEIGHT
                + b["score"] * config.BLEND_BREADTH_WEIGHT
            )
        else:
            ind.score = fund
    return sorted(industries, key=lambda i: i.score, reverse=True)


def top_industries(n=None, max_pe=None, csv_path=None) -> list[Industry]:
    """Return the top-N ranked industries, skipping overheated (high-PE) ones."""
    n = n or config.TOP_N_INDUSTRIES
    max_pe = max_pe if max_pe is not None else config.MAX_PORTFOLIO_PE
    ranked = score_industries(load_industries(csv_path))
    picks = []
    for i in ranked:
        if i.pe is not None and i.pe > max_pe:
            continue  # overheated valuation
        if config.AVOID_OVEREXTENDED and i.qtr_change > config.MAX_QTR_RUNUP_PCT:
            continue  # parabolic recent run-up -> high reversal risk
        picks.append(i)
    return picks[:n]
