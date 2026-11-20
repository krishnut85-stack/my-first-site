#!/usr/bin/env python3
"""sectorcheck.py - I6: at 10:30, 12:30 and 14:30 IST: GIR's live sectors (data/seclive.json: every listed share of each mapped sector,
size-weighted chg, equal-weight eqw, breadth up / dn, F&O count) vs NSE's OFFICIAL sector indices (ONE call to NSE /api/allIndices,
after the usual cookie page). Writes probe/sector_<HHMM>.json. Read-only; 2 NSE requests per check."""
import json, time, os, sys, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday/v2/sources")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
P = os.path.dirname(os.path.abspath(__file__))
MAP = {"it": "NIFTY IT", "banks": "NIFTY BANK", "auto": "NIFTY AUTO", "fmcg": "NIFTY FMCG", "metals & mining": "NIFTY METAL", "pharma": "NIFTY PHARMA",
       "realty": "NIFTY REALTY", "oil & gas": "NIFTY OIL & GAS", "media": "NIFTY MEDIA", "consumer durables": "NIFTY CONSUMER DURABLES",
       "capital markets": "NIFTY CAPITAL MARKETS", "cement & materials": "NIFTY CEMENT", "chemicals": "NIFTY CHEMICALS", "power": "NIFTY ENERGY",
       "nbfc & finance": "NIFTY FINANCIAL SERVICES EX-BANK", "hospitals & diagnostics": "NIFTY HEALTHCARE INDEX", "insurance": "NIFTY FINANCIAL SERVICES 25/50",
       "capital goods": "NIFTY INDIA MANUFACTURING", "consumer services": "NIFTY INDIA NEW AGE CONSUMPTION", "telecom services": "NIFTY MIDSMALL IT & TELECOM",
       "construction": "NIFTY INFRASTRUCTURE", "services": "NIFTY SERVICES SECTOR"}
EXTRA = ["NIFTY PSU BANK", "NIFTY PRIVATE BANK", "NIFTY INDIA DEFENCE", "NIFTY 50"]

def check(tag):
    import common as C
    gir = json.load(open("/home/globalbot/intraday/data/seclive.json"))
    t_gir = gir.get("t")
    d = C.nse_json("/api/allIndices", referer="https://www.nseindia.com/market-data/live-market-indices")
    t_nse = time.time()
    off = {x.get("index"): x for x in d.get("data") or []}
    rows = []
    for s in gir.get("sectors") or []:
        o = off.get(MAP.get(s["name"], "")) or {}
        rows.append({"sector": s["name"], "gir_pct_size_wt": s.get("chg"), "gir_pct_equal_wt": s.get("eqw"), "gir_up": s.get("up"), "gir_dn": s.get("dn"),
                     "gir_n_listed": s.get("n"), "gir_n_fo": s.get("fo"), "official": MAP.get(s["name"]), "official_pct": o.get("percentChange"),
                     "official_adv": o.get("advances"), "official_dec": o.get("declines"),
                     "diff_pp": round(s["chg"] - o["percentChange"], 2) if (o.get("percentChange") is not None and s.get("chg") is not None) else None})
    ex = {k: {"pct": (off.get(k) or {}).get("percentChange"), "adv": (off.get(k) or {}).get("advances"), "dec": (off.get(k) or {}).get("declines")} for k in EXTRA}
    out = {"tag": tag, "gir_t": t_gir, "gir_at": gir.get("at"), "gir_weights": gir.get("weights"), "nse_t": round(t_nse, 1), "nse_timestamp": d.get("timestamp"),
           "rows": rows, "extra": ex}
    json.dump(out, open(os.path.join(P, "sector_%s.json" % tag), "w"), indent=1)
    print(tag, "written", len(rows))

if len(sys.argv) > 1 and sys.argv[1] == "now":
    check(dt.datetime.now(IST).strftime("%H%M")); sys.exit()
for hm in ("10:30", "12:30", "14:30"):
    while dt.datetime.now(IST).strftime("%H:%M") < hm:
        time.sleep(20)
    if dt.datetime.now(IST).strftime("%H:%M") > hm[:3] + "40":
        continue
    try:
        check(hm.replace(":", ""))
    except Exception as e:
        print(hm, "failed", e, flush=True)
