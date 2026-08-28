"""Bar data for Garuda: a dropped CSV of real bars, or a synthetic series.

Real 5-minute NSE bars export from Kite's historical API — drop a CSV in with a
`close` (or `last`/`ltp`) column, or just one price per line. Offline, the
synthetic series lets the backtester and tests run with no data and no keys.
Synthetic prices are NOT real and are only for wiring/tests.
"""

import csv
import random

from . import config


def synthetic_series(n: int = 3000, seed: int = 7, start: float = 100.0,
                     vol: float = 0.002, drift: float = 0.0) -> list[float]:
    """A deterministic random-walk price path (seeded, so tests are stable)."""
    rng = random.Random(seed)
    price = start
    out = [price]
    for _ in range(n - 1):
        price = max(1.0, price * (1.0 + rng.gauss(drift, vol)))
        out.append(round(price, 2))
    return out


_CLOSE_NAMES = ("close", "last", "ltp", "price")


def load_csv_series(path) -> list[float]:
    """Read a price series from a CSV. Prefers a close-like column; otherwise
    takes the last numeric cell of each row. Non-numeric rows are skipped."""
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    if not rows:
        return []
    header = [h.strip().lower() for h in rows[0]]
    idx = next((i for i, h in enumerate(header) if h in _CLOSE_NAMES), None)
    body = rows[1:] if idx is not None else rows
    closes: list[float] = []
    for r in body:
        if not r:
            continue
        cell = (r[idx] if idx is not None and idx < len(r) else r[-1])
        try:
            closes.append(float(str(cell).replace(",", "").strip()))
        except ValueError:
            continue
    return closes
