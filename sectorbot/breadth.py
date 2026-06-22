"""Load the sector bullish/bearish breadth CSV (Trendlyne) and score sectors.

Columns: NAME, NO. OF STOCKS, MARKET CAP, MOMENTUM SCORE, RSI > 50, MFI > 50,
LTP > SMA20, LTP > SMA50, LTP > SMA200, SMA50 > SMA200, DAY GAINERS%,
WEEK GAINERS%.

The breadth score is a transparent weighted blend (config.BREADTH_WEIGHTS) of
those signals, on a 0-100 scale. It measures how broadly bullish a sector is
right now -- NOT a prediction.
"""

import csv

from . import config


def _pct(value) -> float:
    """Parse '30.10%' / '1,234' / '-' into a float (0.0 if blank)."""
    if value is None:
        return 0.0
    value = value.replace("%", "").replace(",", "").strip()
    if value in ("", "-"):
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def normalize_sector(name: str) -> str:
    """Canonical sector key so the two CSVs match despite '&' vs 'and', commas,
    casing, etc. e.g. 'Banking & Finance' and 'Banking and Finance' -> same."""
    s = name.lower().replace("&", " and ")
    s = "".join(ch if (ch.isalnum() or ch.isspace()) else " " for ch in s)
    return " ".join(s.split())


def _score(row: dict) -> tuple[float, dict]:
    comp = {
        "momentum_score": _pct(row.get("MOMENTUM SCORE")),
        "rsi50": _pct(row.get("RSI > 50")),
        "mfi50": _pct(row.get("MFI > 50")),
        "sma20": _pct(row.get("LTP > SMA20")),
        "sma50": _pct(row.get("LTP > SMA50")),
        "sma200": _pct(row.get("LTP > SMA200")),
        "golden_cross": _pct(row.get("SMA50 > SMA200")),
        "week_gainers": _pct(row.get("WEEK GAINERS%")),
    }
    w = config.BREADTH_WEIGHTS
    score = sum(comp[k] * w[k] for k in w)
    return score, comp


def load_breadth(csv_path) -> dict[str, dict]:
    """Return {normalized_sector_name: {name, score, **components}}."""
    out: dict[str, dict] = {}
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            name = (row.get("NAME") or "").strip()
            if not name:
                continue
            score, comp = _score(row)
            out[normalize_sector(name)] = {"name": name, "score": score, **comp}
    return out


def load_breadth_scores(path=None) -> dict[str, dict]:
    """Load breadth for the newest breadth CSV in data/, or {} if none."""
    from .data_loader import resolve_breadth_csv

    p = path or resolve_breadth_csv()
    if not p:
        return {}
    return load_breadth(p)
