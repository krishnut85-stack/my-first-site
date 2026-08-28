"""Fetch real intraday bars from Kite's historical API into a CSV Garuda can test.

Run this ON THE DROPLET (where your Kite key + daily token live), then feed the
CSV straight into the backtester:

    python3 -m garuda.fetch_bars RELIANCE --interval 5minute --days 60
    python3 -m garuda backtest --csv RELIANCE_5minute.csv

Credentials are read from the environment at runtime (never committed):
    KITE_API_KEY         your Kite Connect api key
    KITE_ACCESS_TOKEN    the daily token, OR
    KITE_TOKEN_FILE      path to kite_token.json (what your main bot refreshes)

Kite limits a single 5-minute request to ~100 days; keep --days <= 100.
"""

import csv
import json
import os
import sys
from pathlib import Path


def _resolve_token() -> str:
    tok = os.environ.get("KITE_ACCESS_TOKEN", "").strip()
    if tok:
        return tok
    tf = os.environ.get("KITE_TOKEN_FILE", "")
    if tf and Path(tf).exists():
        raw = Path(tf).read_text().strip()
        try:
            d = json.loads(raw)
            if isinstance(d, dict):
                for k in ("access_token", "accessToken", "token"):
                    if d.get(k):
                        return str(d[k]).strip()
        except Exception:  # noqa: BLE001
            pass
        for line in raw.splitlines():
            if "access_token" in line.lower() and "=" in line:
                return line.split("=", 1)[1].strip().strip('"\'')
        if raw and "\n" not in raw:
            return raw
    return ""


def fetch(symbol: str, interval: str = "5minute", days: int = 60,
          out: str | None = None) -> str:
    try:
        from kiteconnect import KiteConnect  # type: ignore
    except ImportError:
        raise SystemExit("kiteconnect not installed — run: pip3 install kiteconnect")

    api_key = os.environ.get("KITE_API_KEY", "")
    if not api_key:
        raise SystemExit("KITE_API_KEY not set (source /home/globalbot/.env first)")
    token = _resolve_token()
    if not token:
        raise SystemExit("No Kite access token — set KITE_ACCESS_TOKEN or "
                         "KITE_TOKEN_FILE (e.g. /home/globalbot/data/kite_token.json)")

    kite = KiteConnect(api_key=api_key)
    kite.set_access_token(token)

    instrument_token = None
    for inst in kite.instruments("NSE"):
        if inst["tradingsymbol"] == symbol:
            instrument_token = inst["instrument_token"]
            break
    if not instrument_token:
        raise SystemExit(f"symbol {symbol!r} not found on NSE")

    from datetime import date, timedelta
    frm = date.today() - timedelta(days=days)
    bars = kite.historical_data(instrument_token, frm, date.today(), interval)

    out = out or f"{symbol}_{interval}.csv"
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["date", "close"])
        for b in bars:
            w.writerow([b["date"], b["close"]])
    print(f"Wrote {len(bars)} {interval} bars for {symbol} -> {out}")
    print(f"Now run:  python3 -m garuda backtest --csv {out}")
    return out


def main() -> None:
    args = sys.argv[1:]
    if not args:
        raise SystemExit("usage: python3 -m garuda.fetch_bars SYMBOL "
                         "[--interval 5minute] [--days 60] [--out file.csv]")
    symbol = args[0].upper()

    def _opt(flag, cast, default):
        return cast(args[args.index(flag) + 1]) if flag in args else default

    fetch(symbol,
          interval=_opt("--interval", str, "5minute"),
          days=_opt("--days", int, 60),
          out=_opt("--out", str, None))


if __name__ == "__main__":
    main()
