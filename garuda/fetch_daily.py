"""Fetch DAILY bars for the WHOLE stock universe (or a basket) into one CSV.

Run ON THE DROPLET. Writes long format `symbol,date,close` (works for any number
of stocks — no alignment needed), then feed it to the setup / cross backtests:

    python3 -m garuda.fetch_daily --all                 # every NSE stock (~2000)
    python3 -m garuda.fetch_daily --all --exchange BSE  # every BSE stock (~5000)
    python3 -m garuda.setups --csv daily.csv            # RSI-2 bounce on ALL of them

Or a custom list:  --symbols "RELIANCE,INFY,TCS"
Credentials are read from the env (KITE_API_KEY + KITE_ACCESS_TOKEN/KITE_TOKEN_FILE).

Note: pulling ~2000-5000 stocks is one Kite call each, so it takes several
minutes and prints progress. Many are thinly traded — the backtest reports on
whatever trades trigger; you decide what's liquid enough to act on.
"""

import csv
import os
import sys
import time

from .fetch_bars import _resolve_token

# a quick default basket if you don't pass --all / --symbols
DEFAULT_BASKET = ["RELIANCE", "HDFCBANK", "ICICIBANK", "INFY", "TCS", "ITC",
                  "LT", "SBIN", "BHARTIARTL", "KOTAKBANK"]


def _kite():
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
    k = KiteConnect(api_key=api_key)
    k.set_access_token(token)
    return k


def _universe(kite, exchange: str) -> dict:
    """{tradingsymbol: instrument_token} of EQ stocks. exchange 'BOTH' = the
    whole market: NSE + BSE unioned (NSE token preferred for shared names)."""
    exchanges = ["NSE", "BSE"] if exchange == "BOTH" else [exchange]
    tokens: dict = {}
    for ex in exchanges:
        for i in kite.instruments(ex):
            if i.get("instrument_type") == "EQ":
                tokens.setdefault(i["tradingsymbol"], i["instrument_token"])
    return tokens


def fetch_daily(symbols=None, days=400, out="daily.csv", exchange="NSE",
                all_stocks=False, limit=0) -> str:
    kite = _kite()
    tokens = _universe(kite, exchange)

    if all_stocks:
        symbols = sorted(tokens)
    symbols = symbols or DEFAULT_BASKET
    if limit:
        symbols = symbols[:limit]

    print(f"Fetching {len(symbols)} {exchange} stocks x {days}d (this takes a few min)...")
    from datetime import date, timedelta
    frm = date.today() - timedelta(days=days)

    written = rows = 0
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["symbol", "date", "close"])
        for n, s in enumerate(symbols, 1):
            tok = tokens.get(s)
            if not tok:
                continue
            try:
                data = kite.historical_data(tok, frm, date.today(), "day")
            except Exception:  # noqa: BLE001 — skip a bad symbol, keep going
                continue
            for d in data:
                w.writerow([s, d["date"].date().isoformat(), d["close"]])
                rows += 1
            written += 1
            if n % 100 == 0:
                print(f"  {n}/{len(symbols)} done ({written} with data)...")
            time.sleep(0.22)  # respect Kite's historical rate limit

    print(f"Wrote {written} stocks, {rows} rows -> {out}")
    print(f"Now run: python3 -m garuda.setups --csv {out}")
    return out


def _read_symbols_file(path) -> list:
    """Read symbols from a file: an NSE constituent CSV (has a 'Symbol' column)
    or a plain one-symbol-per-line list."""
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    if not rows:
        return []
    header = [c.strip().lower() for c in rows[0]]
    if "symbol" in header:
        idx = header.index("symbol")
        return [r[idx].strip().upper() for r in rows[1:] if len(r) > idx and r[idx].strip()]
    return [r[0].strip().upper() for r in rows if r and r[0].strip()]


def main() -> None:
    args = sys.argv[1:]

    def _opt(flag, cast, default):
        return cast(args[args.index(flag) + 1]) if flag in args else default

    symbols = None
    sfile = _opt("--symbols-file", str, "")
    if sfile:
        symbols = _read_symbols_file(sfile)
        print(f"Loaded {len(symbols)} symbols from {sfile}")
    else:
        syms_arg = _opt("--symbols", str, "")
        symbols = [s.strip().upper() for s in syms_arg.split(",") if s.strip()] or None
    # default: `--all` alone pulls the WHOLE market (NSE + BSE ~5000+); pass an
    # explicit --exchange NSE / BSE to restrict.
    exchange = _opt("--exchange", str, "").upper()
    if not exchange:
        exchange = "BOTH" if ("--all" in args) else "NSE"
    fetch_daily(
        symbols=symbols,
        days=_opt("--days", int, 400),
        out=_opt("--out", str, "daily.csv"),
        exchange=exchange,
        all_stocks=("--all" in args),
        limit=_opt("--limit", int, 0),
    )


if __name__ == "__main__":
    main()
