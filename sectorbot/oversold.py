"""NSE F&O oversold screener — which futures & options stocks have RSI < 30?

Answers "which F&O stocks are in the oversold zone right now?" by pulling real
daily candles for every NSE F&O underlying and computing Wilder's RSI(14).

Data sources, in order of preference:
  1. Kite (your Zerodha login) — the F&O list comes LIVE from the NFO
     instruments dump, candles from the Kite historical API. Needs
     KITE_API_KEY + a valid access token (same setup the rest of the bot
     uses) and the historical-data add-on on your Kite Connect app.
  2. Yahoo Finance — free fallback needing no keys at all. The F&O list then
     comes from data/fo_underlyings.csv, a shipped snapshot of the F&O
     universe (NSE revises the list a few times a year — refresh the CSV or
     use Kite for the always-current list).

Run it:
    python -m sectorbot oversold                 # auto: Kite if configured, else Yahoo
    python -m sectorbot oversold --source yahoo  # force the free fallback
    python -m sectorbot oversold --threshold 35  # widen the net

READ-ONLY: this fetches prices and prints a table. It never places orders.
An oversold RSI is a description of the recent past, not a buy signal.
"""

import csv
import json
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass

from . import config
from .indicators import rsi

RSI_PERIOD = 14
OVERSOLD = 30.0          # classic oversold line
NEAR_OVERSOLD = 35.0     # "approaching oversold" band shown separately
HISTORY_BARS = 120       # candles per stock; plenty for a stable Wilder RSI

# Index futures also live in the NFO dump — they're not stocks, skip them.
_INDEX_UNDERLYINGS = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY",
                      "NIFTYNXT50", "NIFTYIT"}

FO_FALLBACK_CSV = config.DATA_DIR / "fo_underlyings.csv"


@dataclass
class ScreenRow:
    symbol: str
    rsi: float
    close: float


# --------------------------------------------------------------------------
# F&O universe
# --------------------------------------------------------------------------
def fo_underlyings_from_kite(kite) -> list[str]:
    """Live F&O stock list: unique underlyings of NFO futures, minus indices."""
    names = {i["name"] for i in kite.instruments("NFO")
             if i.get("segment") == "NFO-FUT"}
    return sorted(n for n in names if n and n not in _INDEX_UNDERLYINGS)


def fo_underlyings_fallback() -> list[str]:
    """Shipped snapshot of the F&O universe (used when Kite isn't available)."""
    with open(FO_FALLBACK_CSV, newline="") as f:
        return sorted({row["symbol"].strip() for row in csv.DictReader(f)
                       if row.get("symbol", "").strip()})


# --------------------------------------------------------------------------
# Price history
# --------------------------------------------------------------------------
def closes_from_yahoo(symbol: str) -> list[float]:
    """Daily closes from Yahoo Finance ('SYMBOL.NS'), oldest first.

    Free and keyless, so it's the fallback everyone can run. Yahoo wants a
    browser-ish User-Agent or it rejects the call.
    """
    ysym = urllib.parse.quote(f"{symbol}.NS")
    url = (f"https://query1.finance.yahoo.com/v8/finance/chart/{ysym}"
           f"?range=6mo&interval=1d")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.load(resp)
    result = (data.get("chart", {}).get("result") or [None])[0]
    if not result:
        return []
    closes = result["indicators"]["quote"][0].get("close") or []
    return [c for c in closes if c is not None]


def _kite_history_fetcher(ds):
    """Wrap KiteDataSource.history into a closes fetcher, pacing calls to stay
    inside Kite's historical-API rate limit (~3 req/s)."""
    def fetch(symbol: str) -> list[float]:
        time.sleep(0.35)
        return [b.close for b in ds.history(symbol, HISTORY_BARS)]
    return fetch


# --------------------------------------------------------------------------
# The screen
# --------------------------------------------------------------------------
def run_screen(source: str = "auto", threshold: float = OVERSOLD,
               near: float = NEAR_OVERSOLD, period: int = RSI_PERIOD,
               verbose: bool = True) -> dict:
    """Screen every F&O stock for RSI below `threshold` (and up to `near`).

    Returns {"source", "universe", "checked", "failed", "oversold": [...],
    "near_oversold": [...]} with rows sorted most-oversold first.
    """
    fetch = None
    used = "yahoo"
    symbols: list[str] = []

    if source in ("auto", "kite") and config.KITE_API_KEY:
        try:
            from .datasource import KiteDataSource
            ds = KiteDataSource()
            symbols = fo_underlyings_from_kite(ds.kite)
            fetch = _kite_history_fetcher(ds)
            used = "kite"
        except Exception as exc:  # noqa: BLE001
            if source == "kite":
                raise
            if verbose:
                print(f"[oversold] Kite unavailable ({exc}) — using Yahoo.")
    elif source == "kite":
        raise RuntimeError("KITE_API_KEY not configured — cannot use --source kite.")

    if fetch is None:
        symbols = fo_underlyings_fallback()
        fetch = closes_from_yahoo
    elif used == "kite" and source == "auto":
        # Kite's historical API is a paid add-on some apps don't have. Probe
        # one symbol; if history comes back empty, use Yahoo candles instead
        # (keeping the live Kite-derived F&O list, which needs no add-on).
        try:
            probe = fetch(symbols[0])
        except Exception:  # noqa: BLE001
            probe = []
        if len(probe) < period + 1:
            if verbose:
                print("[oversold] Kite historical data unavailable (no add-on?) "
                      "— using Yahoo candles with the live Kite F&O list.")
            fetch, used = closes_from_yahoo, "kite-list+yahoo"

    oversold_rows: list[ScreenRow] = []
    near_rows: list[ScreenRow] = []
    failed: list[str] = []
    for n, sym in enumerate(symbols, 1):
        if verbose and n % 25 == 0:
            print(f"[oversold] {n}/{len(symbols)} checked...")
        try:
            closes = fetch(sym)
            value = rsi(closes, period)
        except Exception:  # noqa: BLE001
            value, closes = None, []
        if value is None:
            failed.append(sym)
            continue
        row = ScreenRow(sym, round(value, 1), round(closes[-1], 2))
        if value < threshold:
            oversold_rows.append(row)
        elif value < near:
            near_rows.append(row)
    oversold_rows.sort(key=lambda r: r.rsi)
    near_rows.sort(key=lambda r: r.rsi)
    return {
        "source": used,
        "universe": len(symbols),
        "checked": len(symbols) - len(failed),
        "failed": failed,
        "rsi_period": period,
        "threshold": threshold,
        "oversold": [row.__dict__ for row in oversold_rows],
        "near_oversold": [row.__dict__ for row in near_rows],
        "disclaimer": ("RSI describes past price action; oversold is not a "
                       "buy signal or advice."),
    }


def format_screen(result: dict) -> str:
    lines = ["", "=" * 58,
             f"  NSE F&O · OVERSOLD SCREEN   (RSI{result['rsi_period']} < "
             f"{result['threshold']:.0f}, source: {result['source']})",
             "=" * 58]
    if not result["oversold"]:
        lines.append("  No F&O stock is in the oversold zone right now.")
    else:
        lines.append(f"  {'Symbol':14} {'RSI':>6} {'Close':>10}")
        lines.append("  " + "-" * 34)
        for r in result["oversold"]:
            lines.append(f"  {r['symbol']:14} {r['rsi']:>6.1f} {r['close']:>10.2f}")
    if result["near_oversold"]:
        lines.append("")
        lines.append(f"  Approaching oversold (RSI {result['threshold']:.0f}-35):")
        for r in result["near_oversold"]:
            lines.append(f"  {r['symbol']:14} {r['rsi']:>6.1f} {r['close']:>10.2f}")
    lines.append("-" * 58)
    lines.append(f"  Checked {result['checked']}/{result['universe']} F&O stocks."
                 + (f"  Failed: {len(result['failed'])}" if result["failed"] else ""))
    lines.append("  " + result["disclaimer"])
    lines.append("=" * 58)
    return "\n".join(lines)
