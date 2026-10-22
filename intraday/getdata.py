#!/usr/bin/env python3
"""getdata.py - builds the share universe and downloads 5-minute candles from Kite.

  python3 getdata.py            first run: pick universe + download full history
  python3 getdata.py --update   top up every symbol to the last finished candle
  python3 getdata.py --rebuild  pick the universe again (then downloads what is missing)

Kite limits respected (checked against kite.trade docs): historical 3 requests/second,
quote 1 request/second, 5-minute candles fetched in 60-day pieces.
"""
import os, sys, json, time, datetime as dt
import numpy as np
import core

UNI = os.path.join(core.BASE, "universe.json")
NIFTY = {"sym": "NIFTY50", "token": 256265}
CHUNK_DAYS = 60
_hist = core.Limiter(0.36)
_quote = core.Limiter(1.1)


def call(fn, *a, **k):
    """Kite call with retries; backs off on 'Too many requests'."""
    last = None
    for i in range(5):
        try:
            return fn(*a, **k)
        except Exception as ex:
            last = ex
            msg = str(ex).lower()
            if "token" in msg and ("invalid" in msg or "expire" in msg or "incorrect" in msg):
                raise
            time.sleep(1.5 * (i + 1))
    raise last


EXCH = {}            # sym -> "BSE" for BSE-only shares (everything else is NSE)


def key(sym):
    return "%s:%s" % (EXCH.get(sym, "NSE"), sym)


def unkey(k):
    return k.split(":", 1)[1] if ":" in k else k


def eq_list(kite, bse=True):
    """NSE equity shares, plus (optionally) shares that trade only on BSE."""
    out, seen = [], set()
    for i in call(kite.instruments, "NSE"):
        s = i.get("tradingsymbol", "")
        nm = (i.get("name") or "").upper()
        if i.get("instrument_type") != "EQ" or i.get("segment") not in ("NSE", None):
            continue
        if "-" in s or i.get("lot_size", 1) != 1:
            continue
        if "BEES" in s or "ETF" in s or "ETF" in nm or s.startswith("LIQUID") or "FUND" in nm:
            continue
        out.append({"sym": s, "token": int(i["instrument_token"]), "name": nm.title(), "exch": "NSE"})
        seen.add(s)
    if bse:
        try:
            n_b = 0
            for i in call(kite.instruments, "BSE"):
                s = i.get("tradingsymbol", "")
                nm = (i.get("name") or "").upper()
                if i.get("instrument_type") != "EQ" or i.get("segment") not in ("BSE", None):
                    continue
                if not s or s in seen or s.isdigit() or "-" in s or i.get("lot_size", 1) != 1:
                    continue
                if "BEES" in s or "ETF" in s or "ETF" in nm or "FUND" in nm or nm.endswith(" ETF"):
                    continue
                out.append({"sym": s, "token": int(i["instrument_token"]), "name": nm.title(), "exch": "BSE"})
                seen.add(s)
                n_b += 1
            print("BSE-only equity shares found:", n_b)
        except Exception as ex:
            print("BSE instruments failed (NSE only):", ex)
    return out


def turnover_by_quote(kite, eq):
    res = {}
    keys = ["%s:%s" % (e.get("exch", "NSE"), e["sym"]) for e in eq]
    for i in range(0, len(keys), 150):
        _quote.wait()
        try:
            q = call(kite.quote, keys[i:i + 150])
        except Exception as ex:
            print("quote batch failed:", ex)
            continue
        for k, v in q.items():
            px = v.get("last_price") or 0
            vol = v.get("volume") or v.get("volume_traded") or 0
            res[unkey(k)] = (px, px * vol)
    return res


def turnover_by_daily(kite, eq):
    """Slower fallback: median turnover of the last ~15 daily candles."""
    res = {}
    end = core.ist_now()
    start = end - dt.timedelta(days=25)
    for n, e in enumerate(eq):
        _hist.wait()
        try:
            rows = call(kite.historical_data, e["token"], start, end, "day")
        except Exception:
            continue
        if len(rows) >= 5:
            t = sorted(r["close"] * r["volume"] for r in rows)
            res[e["sym"]] = (rows[-1]["close"], t[len(t) // 2])
        if n % 300 == 0:
            print("  ranking %d/%d" % (n, len(eq)))
    return res


def build_universe(kite, c):
    eq = eq_list(kite, bse=c.get("bse", True))
    print("equity shares found (NSE + BSE-only):", len(eq))
    t = turnover_by_quote(kite, eq)
    live = sum(1 for v in t.values() if v[1] > 0)
    if live < min(300, 0.5 * len(eq)):
        print("quote volumes not usable (%d) - ranking from daily candles, takes ~15 min" % live)
        t = turnover_by_daily(kite, eq)
    floor = c["min_turnover_cr"] * 1e7
    def pick(t):
        r = [e for e in eq if e["sym"] in t and t[e["sym"]][0] >= c["min_price"] and t[e["sym"]][1] >= floor]
        r.sort(key=lambda e: -t[e["sym"]][1])
        return r[:c["universe_size"]]
    uni = pick(t)
    if len(uni) < 300 and "--quick" not in sys.argv:
        print("quote ranking gave only %d liquid shares - re-ranking from daily candles (10-15 min)" % len(uni))
        t = turnover_by_daily(kite, eq)
        uni = pick(t)
    nb = sum(1 for e in uni if e.get("exch") == "BSE")
    print("shares priced >= Rs %s with turnover >= Rs %s crore: %d of %d (%d BSE-only)" % (
        c["min_price"], c["min_turnover_cr"], len(uni), len(eq), nb))
    if len(uni) < 20:
        raise RuntimeError("universe too small (%d) - Kite data problem" % len(uni))
    json.dump({"built": str(core.ist_now())[:16], "symbols": uni}, open(UNI, "w"))
    print("universe: %d shares, most liquid first: %s ..." % (len(uni), ", ".join(e["sym"] for e in uni[:8])))
    return uni


def load_universe():
    if not os.path.exists(UNI):
        return None
    uni = json.load(open(UNI))["symbols"]
    EXCH.clear()
    EXCH.update({e["sym"]: "BSE" for e in uni if e.get("exch") == "BSE"})
    return uni


def fetch(kite, token, start, end):
    """5-minute candles from start to end (naive IST datetimes), finished candles only."""
    rows = []
    a = start
    while a < end:
        b = min(a + dt.timedelta(days=CHUNK_DAYS), end)
        _hist.wait()
        rows.extend(call(kite.historical_data, token, a, b, "5minute"))
        a = b + dt.timedelta(seconds=1)
    arr = core.rows_to_arrays(rows)
    done = arr["ts"] + 300 <= time.time()
    return {k: v[done] for k, v in arr.items()}


def update_symbol(kite, e, c, now=None):
    now = now or core.ist_now()
    old = core.load_npz(e["sym"])
    if old is not None and len(old["ts"]):
        last = dt.datetime(1970, 1, 1) + dt.timedelta(seconds=int(old["ts"][-1]) + core.IST_OFF)
        start = dt.datetime(last.year, last.month, last.day, 9, 0)
    else:
        days = int(365 * c["years"])
        for x in sys.argv:
            if x.startswith("--days="):
                days = int(x[7:])
        start = (now - dt.timedelta(days=days)).replace(hour=9, minute=0, second=0, microsecond=0)
    new = fetch(kite, e["token"], start, now)
    merged = core.merge_arrays(old, new)
    if merged is not None and len(merged["ts"]):
        _, first = np.unique(merged["ts"], return_index=True)
        merged = {k: v[first] for k, v in merged.items()}
        core.save_npz(e["sym"], merged)
        return len(merged["ts"])
    return 0


def update_all(kite, c, uni, quiet=False):
    ok, bad = 0, []
    for n, e in enumerate([NIFTY] + uni):
        try:
            rows = update_symbol(kite, e, c)
            ok += 1 if rows else 0
            if not rows:
                bad.append(e["sym"])
        except Exception as ex:
            bad.append(e["sym"])
            print("  %s failed: %s" % (e["sym"], ex))
        if not quiet and n % 50 == 0:
            print("  downloaded %d/%d" % (n, len(uni) + 1))
    return ok, bad


def main():
    c = core.cfg()
    kite = core.get_kite(c)
    uni = None if "--rebuild" in sys.argv else load_universe()
    if uni is None:
        uni = build_universe(kite, c)
    t0 = time.time()
    ok, bad = update_all(kite, c, uni)
    print("data ready: %d symbols ok, %d failed, %.0f s" % (ok, len(bad), time.time() - t0))
    if bad:
        print("failed:", ", ".join(bad[:30]))
    if ok < 0.8 * (len(uni) + 1):
        sys.exit(1)


if __name__ == "__main__":
    main()
