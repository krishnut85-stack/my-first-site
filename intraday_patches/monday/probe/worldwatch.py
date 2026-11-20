#!/usr/bin/env python3
"""worldwatch.py - read-only sampler for I4 (world cues). Every 60 s: GIFT NIFTY / MCX in v2/data/kquote.json (quote ts vs file t),
the old earlyteam.json world series (last point = GIR seen), and the page's drv.* facts (src_ts / seen / state) via
/preview/api/state?prefix=drv. Every 15 min: ONE Yahoo chart call per symbol (11 symbols, 1 s apart) for the source's own quote time
(regularMarketTime). Writes probe/world.jsonl. Stops at 16:30 IST."""
import json, time, os, datetime as dt, urllib.request
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "world.jsonl")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
YS = ["BZ=F", "ES=F", "NQ=F", "HG=F", "ALI=F", "GC=F", "^TNX", "DX-Y.NYB", "^N225", "^KS11", "^HSI"]
f = open(OUT, "a"); last_y = 0
def j(p):
    try: return json.load(open(p))
    except Exception: return None
while dt.datetime.now(IST).strftime("%H:%M") < "16:30":
    now = time.time(); rec = {"t": round(now, 1)}
    k = j("/home/globalbot/intraday/v2/data/kquote.json") or {}
    it = k.get("items") or {}
    rec["kq_file_t"] = k.get("t")
    rec["kq"] = {n: {x: (it.get(n) or {}).get(x) for x in ("px", "ts", "ltt")} for n in ("NSEIX:GIFT NIFTY", "MCX:COPPER", "MCX:ALUMINIUM", "MCX:CRUDEOIL", "CDS:USDINR")}
    e = j("/home/globalbot/intraday/data/earlyteam.json") or {}
    rec["early"] = {s: (v[-1] if v else None) for s, v in (e.get("world") or {}).items()}
    try:
        st = json.loads(urllib.request.urlopen("http://127.0.0.1:8100/preview/api/state?prefix=drv.", timeout=5).read())["store"]
        rec["page"] = {kk: {"src_ts": v.get("src_ts"), "seen": v.get("seen"), "state": v.get("state"), "px": (v.get("v") or {}).get("px"),
                            "pct": (v.get("v") or {}).get("pct"), "src": (v.get("src") or "")[:60]} for kk, v in st.items()}
    except Exception as ex:
        rec["page_err"] = str(ex)[:80]
    if now - last_y > 900:
        last_y = now; y = {}
        for s in YS:
            try:
                req = urllib.request.Request("https://query1.finance.yahoo.com/v8/finance/chart/%s?range=1d&interval=5m" % s.replace("^", "%5E"),
                                             headers={"User-Agent": "Mozilla/5.0"})
                m = json.loads(urllib.request.urlopen(req, timeout=8).read())["chart"]["result"][0]["meta"]
                y[s] = {"rmt": m.get("regularMarketTime"), "px": m.get("regularMarketPrice"), "exch": m.get("exchangeName"), "got": round(time.time(), 1)}
            except Exception as ex:
                y[s] = {"err": str(ex)[:60]}
            time.sleep(1)
        rec["yahoo"] = y
    f.write(json.dumps(rec) + "\n"); f.flush()
    time.sleep(max(5, 60 - (time.time() - now)))
