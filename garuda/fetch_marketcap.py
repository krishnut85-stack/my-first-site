"""Fetch market cap (₹ crore) per NSE symbol -> marketcap.csv, via Yahoo Finance.

Kite has no fundamentals and NSE blocks datacenter IPs, so we use Yahoo's quote
API (works from cloud servers, and batches many symbols per request). NSE
symbols map to Yahoo as SYMBOL.NS. Best-effort: writes whatever it gets.

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


def yahoo_session():
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    op.addheaders = [("User-Agent", UA), ("Accept", "*/*")]
    for url in ("https://fc.yahoo.com", "https://finance.yahoo.com"):
        try:
            op.open(url, timeout=20).read()
        except Exception:  # noqa: BLE001 — just seeding cookies
            pass
    crumb = ""
    try:
        crumb = op.open("https://query2.finance.yahoo.com/v1/test/getcrumb",
                        timeout=20).read().decode().strip()
    except Exception:  # noqa: BLE001
        pass
    return op, crumb


def batch_mcap(op, crumb, syms):
    q = ",".join(s + ".NS" for s in syms)
    url = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=" + quote(q)
    if crumb:
        url += "&crumb=" + quote(crumb)
    out = {}
    try:
        raw = op.open(url, timeout=25).read()
        d = json.loads(raw)
        for r in d.get("quoteResponse", {}).get("result", []):
            sym = (r.get("symbol") or "").replace(".NS", "")
            mc = r.get("marketCap")
            if sym and mc:
                out[sym] = mc / 1e7          # rupees -> ₹ crore
    except Exception as exc:  # noqa: BLE001
        print(f"[mcap] batch failed: {exc}", flush=True)
    return out


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

    op, crumb = yahoo_session()
    print(f"[mcap] Yahoo session (crumb: {'ok' if crumb else 'none'}); "
          f"fetching {len(syms)} symbols…", flush=True)
    rows = []
    for i in range(0, len(syms), 50):
        chunk = syms[i:i + 50]
        m = batch_mcap(op, crumb, chunk)
        for s in chunk:
            if s in m:
                rows.append((s, round(m[s], 2)))
        print(f"[mcap] {min(i + 50, len(syms))}/{len(syms)} ({len(rows)} with data)", flush=True)
        time.sleep(1.0)
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["symbol", "marketcap"])
        w.writerows(rows)
    print(f"[mcap] wrote {len(rows)} market caps -> {out}", flush=True)
    if not rows:
        print("[mcap] got nothing — Yahoo may be blocking this IP too; "
              "market cap will show — on the dashboard.", flush=True)


if __name__ == "__main__":
    main()
