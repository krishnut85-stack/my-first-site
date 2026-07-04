"""Fetch full market cap (₹ crore) per NSE symbol -> marketcap.csv.

Kite doesn't expose market cap, so we pull it from NSE's public quote API
(the trade_info section carries totalMarketCap). Best-effort: NSE rate-limits
and needs a session cookie, so this fetches politely and skips what it can't
get. Run it from the daily cron; the dashboard reads marketcap.csv if present.

    python3 -m garuda.fetch_marketcap --symbols-file smallcap_list.csv micro.csv --out marketcap.csv

Stdlib only (urllib + cookiejar).
"""

import csv
import http.cookiejar
import json
import sys
import time
import urllib.request
from pathlib import Path
from urllib.parse import quote

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")
HOME = "https://www.nseindia.com"
API = "https://www.nseindia.com/api/quote-equity?symbol={}&section=trade_info"


def _opener():
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    op.addheaders = [("User-Agent", UA), ("Accept", "application/json, text/plain, */*"),
                     ("Accept-Language", "en-US,en;q=0.9"), ("Referer", HOME + "/")]
    try:
        op.open(HOME, timeout=20).read()      # seed the session cookie
    except Exception:  # noqa: BLE001
        pass
    return op


def _symbols(files):
    syms = []
    for fp in files:
        p = Path(fp)
        if not p.exists():
            continue
        with open(p, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                s = (row.get("Symbol") or row.get("symbol") or "").strip()
                if s:
                    syms.append(s)
    return sorted(set(syms))


def market_cap(op, symbol):
    try:
        raw = op.open(API.format(quote(symbol)), timeout=20).read()
        d = json.loads(raw)
        mc = d.get("marketDeptOrderBook", {}).get("tradeInfo", {}).get("totalMarketCap")
        return float(mc) if mc else None
    except Exception:  # noqa: BLE001
        return None


def main():
    args = sys.argv[1:]

    def _multi(flag):
        if flag not in args:
            return []
        out = []
        for a in args[args.index(flag) + 1:]:
            if a.startswith("--"):
                break
            out.append(a)
        return out

    files = _multi("--symbols-file") or ["smallcap_list.csv", "micro.csv"]
    out = args[args.index("--out") + 1] if "--out" in args else "marketcap.csv"
    syms = _symbols(files)
    if not syms:
        raise SystemExit(f"no symbols found in {files}")
    print(f"[mcap] fetching market cap for {len(syms)} symbols from NSE…", flush=True)
    op = _opener()
    rows, ok = [], 0
    for i, s in enumerate(syms, 1):
        mc = market_cap(op, s)
        if mc:
            rows.append((s, round(mc, 2)))
            ok += 1
        if i % 50 == 0:
            print(f"[mcap] {i}/{len(syms)} ({ok} with data)", flush=True)
            op = _opener()                    # refresh the session periodically
        time.sleep(0.35)                      # be polite to NSE
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["symbol", "marketcap"])
        w.writerows(rows)
    print(f"[mcap] wrote {len(rows)} market caps -> {out}", flush=True)


if __name__ == "__main__":
    main()
