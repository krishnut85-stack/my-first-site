"""Fetch DAILY bars for a basket of NSE symbols into one wide CSV for cross.py.

Run ON THE DROPLET (Kite key + token there). Writes date,SYM1,SYM2,... aligned
to the dates every symbol has, then feed it to the cross-sectional backtest:

    python3 -m garuda.fetch_daily --days 400
    python3 -m garuda cross --csv daily.csv --mode reversion --pick 10
    python3 -m garuda cross --csv daily.csv --mode momentum  --pick 10

By default it pulls a liquid ~50-name basket (Nifty-50-ish). Pass your own with
--symbols "RELIANCE,INFY,TCS,...". We test LIQUID names on purpose: of the ~5000
listed shares, most are illiquid microcaps whose real slippage would dwarf any
signal — "it went up" there is untradeable in size.
"""

import csv
import os
import sys
import time
from pathlib import Path

from .fetch_bars import _resolve_token

# A liquid, tradeable default basket (Nifty-50-ish). Edit freely with --symbols.
DEFAULT_BASKET = [
    "RELIANCE", "HDFCBANK", "ICICIBANK", "INFY", "TCS", "ITC", "LT", "SBIN",
    "BHARTIARTL", "KOTAKBANK", "AXISBANK", "HINDUNILVR", "BAJFINANCE", "ASIANPAINT",
    "MARUTI", "SUNPHARMA", "TITAN", "ULTRACEMCO", "WIPRO", "NESTLEIND", "TATAMOTORS",
    "TATASTEEL", "POWERGRID", "NTPC", "TECHM", "HCLTECH", "ADANIENT", "JSWSTEEL",
    "INDUSINDBK", "GRASIM", "CIPLA", "COALINDIA", "DRREDDY", "BAJAJFINSV", "HDFCLIFE",
    "BRITANNIA", "EICHERMOT", "HEROMOTOCO", "DIVISLAB", "BPCL", "ONGC", "APOLLOHOSP",
    "SBILIFE", "TATACONSUM", "M&M", "UPL", "BAJAJ-AUTO", "HINDALCO", "SHREECEM", "IOC",
]


def fetch_daily(symbols, days: int = 400, out: str = "daily.csv") -> str:
    try:
        from kiteconnect import KiteConnect  # type: ignore
    except ImportError:
        raise SystemExit("kiteconnect not installed — run: pip3 install kiteconnect")
    api_key = os.environ.get("KITE_API_KEY", "")
    if not api_key:
        raise SystemExit("KITE_API_KEY not set (source /home/globalbot/.env first)")
    token = _resolve_token()
    if not token:
        raise SystemExit("No Kite access token (KITE_ACCESS_TOKEN or KITE_TOKEN_FILE)")

    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(token)
    tokens = {i["tradingsymbol"]: i["instrument_token"] for i in kite.instruments("NSE")}

    from datetime import date, timedelta
    frm = date.today() - timedelta(days=days)
    series: dict[str, dict[str, float]] = {}
    for s in symbols:
        tok = tokens.get(s)
        if not tok:
            print(f"  skip {s} (not found on NSE)")
            continue
        try:
            data = kite.historical_data(tok, frm, date.today(), "day")
        except Exception as exc:  # noqa: BLE001
            print(f"  skip {s} ({exc})")
            continue
        series[s] = {d["date"].date().isoformat(): d["close"] for d in data}
        time.sleep(0.3)  # be gentle with Kite's rate limit

    if not series:
        raise SystemExit("no data fetched")
    common = set.intersection(*[set(v) for v in series.values()])
    dates = sorted(common)
    cols = list(series)
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["date"] + cols)
        for dt in dates:
            w.writerow([dt] + [series[s][dt] for s in cols])
    print(f"Wrote {len(dates)} days x {len(cols)} symbols -> {out}")
    print(f"Now run: python3 -m garuda cross --csv {out} --mode reversion --pick 10")
    return out


def main() -> None:
    args = sys.argv[1:]

    def _opt(flag, cast, default):
        return cast(args[args.index(flag) + 1]) if flag in args else default

    syms_arg = _opt("--symbols", str, "")
    symbols = [s.strip().upper() for s in syms_arg.split(",") if s.strip()] or DEFAULT_BASKET
    fetch_daily(symbols, days=_opt("--days", int, 400), out=_opt("--out", str, "daily.csv"))


if __name__ == "__main__":
    main()
