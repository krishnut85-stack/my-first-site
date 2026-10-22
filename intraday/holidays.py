#!/usr/bin/env python3
"""holidays.py - NSE trading holidays. Official list from NSE (cached per year), with a small built-in
fallback of fixed-date holidays. The engine's 09:30 "no Nifty candle" check stays as the safety net."""
import os, json, datetime as dt
import core

CACHE = os.path.join(core.BASE, "holidays_%d.json")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Accept": "application/json", "Accept-Language": "en-US,en;q=0.9"}
# fixed-date NSE holidays (same every year); the moving ones come from NSE
FIXED = {(1, 26, "Republic Day"), (4, 14, "Dr. Ambedkar Jayanti"), (5, 1, "Maharashtra Day"), (8, 15, "Independence Day"),
         (10, 2, "Mahatma Gandhi Jayanti"), (12, 25, "Christmas")}
KNOWN = {"2026-10-20": "Dussehra", "2026-04-03": "Good Friday", "2026-03-03": "Holi", "2026-03-26": "Shri Ram Navami",
         "2026-03-31": "Shri Mahavir Jayanti", "2026-11-24": "Guru Nanak Jayanti"}


def fetch_nse(year):
    """{'YYYY-MM-DD': description} for the cash market, or None if NSE could not be read."""
    try:
        import requests
        s = requests.Session()
        s.get("https://www.nseindia.com/", headers=UA, timeout=15)
        r = s.get("https://www.nseindia.com/api/holiday-master?type=trading", headers=dict(UA, Referer="https://www.nseindia.com/"), timeout=15)
        r.raise_for_status()
        out = {}
        for e in r.json().get("CM", []):
            d = dt.datetime.strptime(e["tradingDate"], "%d-%b-%Y").date()
            if d.year == year:
                out[str(d)] = (e.get("description") or "holiday").strip()
        return out or None
    except Exception:
        return None


def table(year):
    p = CACHE % year
    if os.path.exists(p):
        try:
            j = json.load(open(p))
            if j.get("source") == "nse":
                return j["days"]
        except Exception:
            pass
    days = fetch_nse(year)
    src = "nse"
    if not days:
        src = "builtin"
        days = {k: v for k, v in KNOWN.items() if k.startswith(str(year))}
        for m, d, name in FIXED:
            days.setdefault("%d-%02d-%02d" % (year, m, d), name)
    try:
        json.dump({"source": src, "days": days, "fetched": str(core.ist_now())[:16]}, open(p, "w"))
    except Exception:
        pass
    return days


def holiday(day=None):
    """Name of the NSE holiday on `day` (date or 'YYYY-MM-DD'), or None. Weekends return 'weekend'."""
    d = day or core.ist_now().date()
    if isinstance(d, str):
        d = dt.date.fromisoformat(d)
    if d.weekday() >= 5:
        return "weekend"
    return table(d.year).get(str(d))


def next_trading_day(after=None):
    d = (after or core.ist_now().date()) + dt.timedelta(days=1)
    while holiday(d):
        d += dt.timedelta(days=1)
    return d
