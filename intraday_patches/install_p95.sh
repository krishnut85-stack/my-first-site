#!/bin/bash
# PATCH 95 - HOME = THE TRADING SCREEN + NSE SECTORS (on top of patch 93).
#   · laptop / desktop: the home page opens straight into the trading screen - the ALERTS bar, then the F&O shares | price
#     (tick or 5-min, the OI at each strike on its price scale) | OI build-up | OI chart - on the share you had open last,
#     else the day's biggest mover. The keys 1-0 show their panel (THE THREE, sectors, tape, news ...); ⌂ HOME comes back.
#     The desk line, the ticket and the OI-scenario line take one row each, so the charts get the height. Phone: unchanged.
#   · sectors by NSE's OWN classification (NSE's Nifty Total Market file, fetched on this server, refreshed once a month):
#     Healthcare = pharma + hospitals + labs; NSE's Financial Services split into banks · nbfc & finance · insurance ·
#     capital markets; every F&O share in one sector. Only the page uses it - the desk keeps its own sector map.
#   dashserve.py (exact anchors) · home.html · new nsesec.py. Installs p95test.py. Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g95; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p95.sh now"; exit 1; fi
grep -q "function alertTier" $D/home.html || { echo "patch 93 is not installed yet - paste patches 91-93 first"; exit 1; }
grep -q "function homeOpen" $D/home.html && { echo "patch 95 is already installed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/nsesec.py $D/p95test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p95_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p95_patch.py - PATCH 95 (server side): the page's sectors by NSE's own classification (nsesec.py) - Healthcare is pharma
+ hospitals + diagnostics, NSE's Financial Services split into banks · nbfc & finance · insurance · capital markets; every
F&O share the page shows is in one sector. NSE's list is refreshed once a month in the background (never on a request's
time). The desk keeps sectors.py as before.
Usage: python3 p95_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


E("dashserve.py", '''def live_ticks(sym):''', '''_NSR = {"tried": 0.0}


def nse_refresh():
    """NSE's sector list (data/nse_sectors.json): fetched again once a month, in the background (patch 95)"""
    try:
        import nsesec
        j = nsesec.load_map()
        if (j and time.time() - float(j.get("t") or 0) < 30 * 86400) or time.time() - _NSR["tried"] < 6 * 3600:
            return
        _NSR["tried"] = time.time()
        threading.Thread(target=nsesec.fetch, daemon=True).start()
    except Exception:
        pass


def nse_secs(fps, dks, uni):
    """the page's sectors by NSE's classification: name, average move, the F&O shares, the best / worst, the desk's CE / PE"""
    import nsesec
    out = []
    for name, syms in nsesec.page_map(uni).items():
        mv = sorted([(fps[s]["chg"], s) for s in syms if s in fps and fps[s].get("chg") is not None])
        ce = sorted([{"s": s, "v": dks[s].get("v"), "conf": dks[s].get("conf")} for s in syms if s in dks and (dks[s].get("v") or 0) > 0], key=lambda r: -r["v"])[:3]
        pe = sorted([{"s": s, "v": dks[s].get("v"), "conf": dks[s].get("conf")} for s in syms if s in dks and (dks[s].get("v") or 0) < 0], key=lambda r: r["v"])[:3]
        out.append({"name": name, "chg": round(sum(c for c, _ in mv) / len(mv), 2) if mv else None, "syms": syms,
                    "top": {"s": mv[-1][1], "chg": mv[-1][0]} if mv else None, "bot": {"s": mv[0][1], "chg": mv[0][0]} if mv else None, "ce": ce, "pe": pe})
    return out


def live_ticks(sym):''')
E("dashserve.py", '''    tape = []
    scn_last = {}''', '''    try:                                                         # patch 95: the page's sectors by NSE's own classification
        nse_refresh()
        uni_ = set(fps) | set(dks) | set(chain_lines())
        secs_n = nse_secs(fps, dks, uni_) if uni_ else []
        if secs_n:
            secs = secs_n
    except Exception:
        pass
    tape = []
    scn_last = {}''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new) in enumerate(edits, 1):
            n = s.count(old)
            if n != 1:
                print("ANCHOR %s #%d found %d times (need 1): %r" % (f, i, n, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p95: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p95: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/nsesec.py <<'PY_NSE'
#!/usr/bin/env python3
"""nsesec.py - the page's sectors by NSE's OWN classification (patch 95). NSE puts every listed share in one sector
(Healthcare = pharma + hospitals + diagnostics, Automobile and Auto Components, Capital Goods ...). The list comes from
NSE's index file for the Nifty Total Market (750 shares, every F&O share is in it), kept in data/nse_sectors.json.
NSE's one big "Financial Services" is split (Rama's choice) into banks · nbfc & finance · insurance · capital markets.
A share NSE's file does not have keeps its place from GIR's own map (sectors.py), under the NSE name.
Only the page uses this - the desk and its sector watchers keep sectors.py exactly as before.
  python3 nsesec.py --fetch      download NSE's list now (the page also refreshes it by itself once a month)
  python3 nsesec.py              print the page's sectors for the F&O shares"""
import os, sys, csv, io, json, time

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "nse_sectors.json")
URLS = ["https://www.niftyindices.com/IndexConstituent/ind_niftytotalmarket_list.csv",
        "https://archives.nseindia.com/content/indices/ind_niftytotalmarket_list.csv",
        "https://www.niftyindices.com/IndexConstituent/ind_nifty500list.csv",
        "https://archives.nseindia.com/content/indices/ind_nifty500list.csv"]
NAME = {"Healthcare": "healthcare", "Information Technology": "it", "Automobile and Auto Components": "auto",
        "Fast Moving Consumer Goods": "fmcg", "Metals & Mining": "metals & mining", "Oil Gas & Consumable Fuels": "oil & gas",
        "Power": "power", "Capital Goods": "capital goods", "Construction Materials": "cement & materials", "Construction": "construction",
        "Realty": "realty", "Chemicals": "chemicals", "Consumer Durables": "consumer durables", "Consumer Services": "consumer services",
        "Telecommunication": "telecom", "Media Entertainment & Publication": "media", "Services": "services", "Textiles": "textiles",
        "Diversified": "diversified", "Forest Materials": "forest materials"}
FIN = (("banks", "banks"), ("insurance", "insurance"), ("capital-mkts", "capital markets"), ("nbfc", "nbfc & finance"))
HAND = {"banks": "banks", "nbfc": "nbfc & finance", "insurance": "insurance", "capital-mkts": "capital markets", "it": "it",
        "auto": "auto", "auto-anc": "auto", "pharma": "healthcare", "healthcare": "healthcare", "fmcg": "fmcg", "consumer": "consumer services",
        "metals": "metals & mining", "oil-gas": "oil & gas", "power": "power", "capital-goods": "capital goods", "cement-infra": "construction",
        "chemicals": "chemicals", "telecom-media": "telecom", "conglomerate": "diversified", "others": "services"}
ORDER = ["banks", "nbfc & finance", "insurance", "capital markets", "it", "healthcare", "auto", "fmcg", "metals & mining", "oil & gas",
         "power", "capital goods", "cement & materials", "construction", "realty", "chemicals", "consumer durables", "consumer services",
         "telecom", "media", "services", "textiles", "diversified", "forest materials"]


def parse(text):
    """NSE's index CSV -> {SYMBOL: NSE sector}"""
    out = {}
    for row in csv.DictReader(io.StringIO(text.lstrip("﻿"))):
        r = {(k or "").strip().lower(): (v or "").strip() for k, v in row.items()}
        s, ind = r.get("symbol"), r.get("industry")
        if s and ind:
            out[s.upper()] = ind
    return out


def fetch():
    """download NSE's list -> data/nse_sectors.json. Returns (n shares, source) or (0, why)."""
    import requests
    why = []
    for u in URLS:
        try:
            r = requests.get(u, timeout=20, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
                                                     "Accept": "text/csv,*/*", "Referer": "https://www.niftyindices.com/"})
            m = parse(r.text) if r.ok else {}
            if len(m) >= 300:
                os.makedirs(os.path.dirname(FILE), exist_ok=True)
                tmp = FILE + ".tmp"
                json.dump({"t": time.time(), "src": u, "map": m}, open(tmp, "w"))
                os.replace(tmp, FILE)
                return len(m), u
            why.append("%s: %s" % (u.split("/")[2], r.status_code if not r.ok else "only %d rows" % len(m)))
        except Exception as ex:
            why.append("%s: %s" % (u.split("/")[2], str(ex)[:60]))
    return 0, " · ".join(why)


def load_map():
    try:
        return json.load(open(FILE))
    except Exception:
        return None


def sector_of(sym, nse, hand):
    """one page sector for a share: NSE's (finance split by GIR's own lists), else GIR's own map under the NSE name"""
    ind = (nse or {}).get(sym)
    if ind == "Financial Services" or (ind is None and any(sym in hand.get(k, []) for k, _ in FIN)):
        for k, name in FIN:
            if sym in hand.get(k, []):
                return name
        return "nbfc & finance"
    if ind:
        return NAME.get(ind, ind.lower())
    for k, v in hand.items():
        if sym in v and k in HAND:
            return HAND[k]
    return "others"


def page_map(universe, nse=None, hand=None):
    """{page sector: [F&O shares]} in NSE's order, for the shares the page shows"""
    if nse is None:
        nse = (load_map() or {}).get("map") or {}
    if hand is None:
        import sectors
        hand = sectors.hand_map()
    m = {}
    for s in sorted(universe):
        m.setdefault(sector_of(s, nse, hand), []).append(s)
    return {k: m[k] for k in sorted(m, key=lambda k: (ORDER.index(k) if k in ORDER else 99, k))}


if __name__ == "__main__":
    if sys.argv[1:2] == ["--fetch"]:
        n, src = fetch()
        print(("NSE sectors: %d shares from %s" % (n, src)) if n else ("NSE sectors NOT fetched (%s) - the page keeps GIR's own map, under NSE's names" % src))
        sys.exit(0)
    import sectors
    uni = set(s for v in sectors.hand_map().values() for s in v)
    j = load_map()
    print("NSE file: %s" % (("%d shares, %s" % (len(j["map"]), time.strftime("%d %b %Y", time.localtime(j["t"])))) if j else "not fetched yet"))
    for k, v in page_map(uni).items():
        print("%-20s %3d  %s" % (k, len(v), " ".join(v)))
PY_NSE
cat > $W/home.html <<'HTML_P95'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>GIR</title>
<style>
:root{--bg:#000;--panel:#07090c;--line:#1a2230;--line2:#243040;--dim:#7d8b9c;--txt:#d6dee8;--hi:#ffffff;--amber:#ffb000;--amber2:#ffcc4d;--up:#1ed760;--dn:#ff3b4a;--wt:#ffb000;
--mono:"JetBrains Mono","SFMono-Regular",Menlo,Consolas,"Roboto Mono",monospace}
*{box-sizing:border-box;margin:0;padding:0}html{-webkit-text-size-adjust:100%}
body{background:var(--bg);color:var(--txt);font:13px/1.35 var(--mono);padding-bottom:34px}
a{color:inherit;text-decoration:none}
.pu{color:var(--up)}.pd{color:var(--dn)}.am{color:var(--amber)}.dim{color:var(--dim)}.hi{color:var(--hi)}
/* top: index strip + command line, always there */
#top{position:sticky;top:0;z-index:20;background:#000;border-bottom:1px solid var(--amber)}
#idx{display:flex;gap:0;align-items:stretch;overflow-x:auto;scrollbar-width:none;border-bottom:1px solid var(--line)}
#idx::-webkit-scrollbar{display:none}
#idx .brand{padding:6px 10px;color:#000;background:var(--amber);font-weight:700;letter-spacing:.08em;display:flex;align-items:center}
#idx .ix{padding:4px 10px;border-right:1px solid var(--line);white-space:nowrap;display:flex;flex-direction:column;justify-content:center;min-width:92px}
#idx .ix b{display:block;font-size:10px;letter-spacing:.08em;color:var(--dim);font-weight:400}
#idx .ix span{font-size:14px;color:var(--hi)}#idx .ix small{font-size:11px;margin-left:5px}
#idx .st{margin-left:auto;padding:4px 10px;white-space:nowrap;font-size:11px;color:var(--dim);display:flex;align-items:center;gap:8px}
#idx .st .live{color:var(--up)}#idx .st .closed{color:var(--dim)}
#cmd{display:flex;align-items:center;gap:6px;padding:5px 8px;background:#050607}
#cmd .pr{color:var(--amber);font-weight:700}
#cmd input{flex:1;min-width:0;background:#000;color:var(--amber2);border:1px solid var(--line2);padding:7px 10px;font:14px var(--mono);letter-spacing:.06em;text-transform:uppercase;outline:none}
#cmd input:focus{border-color:var(--amber)}
#cmd button{background:var(--amber);color:#000;border:0;font:700 12px var(--mono);padding:8px 12px;letter-spacing:.06em}
#cmd select{background:#000;color:var(--txt);border:1px solid var(--line2);font:12px var(--mono);padding:7px 6px;max-width:34vw}
#cmd .x{color:var(--amber);border:1px solid var(--line2);padding:7px 10px;display:none}
/* the grid of panels */
#grid{display:grid;grid-template-columns:1fr;gap:1px;background:var(--line)}
.p{background:var(--panel);min-width:0}
.p h2{font-size:11px;font-weight:700;letter-spacing:.1em;color:var(--amber);padding:6px 8px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:8px;text-transform:uppercase}
.p h2 small{font-weight:400;color:var(--dim);letter-spacing:0;text-transform:none;margin-left:auto;font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.empty{padding:14px 8px;color:var(--dim);font-size:12px}
#focus[hidden]{display:none}
@media(min-width:900px){body{font-size:12px}#grid{grid-template-columns:repeat(12,1fr);grid-auto-rows:min-content}
  #now{grid-column:1/5;grid-row:1/4;max-height:calc(100vh - 118px);overflow:auto}
  #focus{grid-column:5/13;grid-row:1}#three{grid-column:5/13;grid-row:2}#secs{grid-column:5/13;grid-row:3}
  #focus[hidden]~#three{grid-row:1}#focus[hidden]~#secs{grid-row:2}
  #tape{grid-column:1/9;grid-row:4;max-height:70vh;overflow:auto}#news{grid-column:9/13;grid-row:4;max-height:70vh;overflow:auto}
  #now .r{padding:4px 8px}#now .s{font-size:13px}#three .r{padding:4px 8px}#tape td{padding:3px 6px;font-size:11px}#news .r{padding:4px 8px;font-size:11px}}
@media(min-width:1100px){
  #now{grid-column:1/4;grid-row:1/4}#focus{grid-column:4/10;grid-row:1}#three{grid-column:10/13;grid-row:1/3}
  #focus:not([hidden])~#three{grid-column:10/13;grid-row:1/3}#focus[hidden]~#three{grid-column:4/13;grid-row:1}
  #secs{grid-column:4/10;grid-row:2}#focus[hidden]~#secs{grid-column:4/13;grid-row:2}#tape{grid-column:4/10;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:3;max-height:none}
  #secs .g{grid-template-columns:repeat(5,1fr)}#three .r{grid-template-columns:18px 1fr}#three .r>div:nth-child(3){display:none}}
@media(min-width:1500px){#secs .g{grid-template-columns:repeat(10,1fr)}}
/* NOW */
#now .r{display:grid;grid-template-columns:44px 1fr auto;gap:4px 8px;padding:6px 8px;border-bottom:1px solid var(--line);align-items:start}
#now .r.new{animation:flash 1.6s ease-out}
@keyframes flash{0%{background:rgba(255,176,0,.35)}100%{background:transparent}}
#now .t{color:var(--dim);font-size:11px;padding-top:2px}
#now .s{color:var(--hi);font-weight:700;font-size:14px}
#now .side{font-size:11px;font-weight:700;padding:1px 6px;border:1px solid;white-space:nowrap}
#now .side.up{color:var(--up);border-color:var(--up)}#now .side.dn{color:var(--dn);border-color:var(--dn)}#now .side.na{color:var(--dim);border-color:var(--line2)}
#now .h{grid-column:2/4;color:var(--txt)}
#now .l{grid-column:2/4;color:var(--dim);font-size:11px;white-space:pre-wrap}
#now .l .w{color:var(--wt)}#now .l .b{color:var(--up)}
/* THE THREE */
#three .r{display:grid;grid-template-columns:22px 1fr auto;gap:2px 8px;padding:6px 8px;border-bottom:1px solid var(--line)}
#three .rk{color:var(--amber);font-weight:700;font-size:16px}
#three .l1 b{color:var(--hi);font-size:14px}#three .l1 .sd{margin-left:6px;font-weight:700}
#three .vd{grid-column:2/4;font-size:12px}#three .vd.wt{color:var(--wt)}#three .vd.dn{color:var(--dim)}
#three .l2{grid-column:2/4;color:var(--dim);font-size:11px}#three .l2 em{font-style:normal;color:var(--txt)}
/* SECTORS: a heat grid */
#secs .g{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line)}
@media(min-width:600px){#secs .g{grid-template-columns:repeat(5,1fr)}}@media(min-width:900px){#secs .g{grid-template-columns:repeat(10,1fr)}}
#secs .c{background:var(--panel);padding:6px 6px 5px;min-height:62px;cursor:pointer;position:relative;overflow:hidden}
#secs .c.sel{outline:1px solid var(--amber)}
#secs .c .n{font-size:10px;letter-spacing:.06em;color:var(--txt);text-transform:uppercase;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .v{font-size:15px;font-weight:700;margin-top:1px}
#secs .c .tb{font-size:10px;color:var(--dim);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .pl{position:absolute;top:5px;right:5px;font-size:10px;font-weight:700}
/* TAPE: a dense table, still */
#tape table{width:100%;border-collapse:collapse;table-layout:fixed}
#tape th{font-size:10px;color:var(--dim);font-weight:400;text-align:left;padding:4px 6px;border-bottom:1px solid var(--line);letter-spacing:.06em;cursor:pointer;white-space:nowrap}
#tape th.on{color:var(--amber)}
#tape td{padding:4px 6px;border-bottom:1px solid var(--line);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:12px}
#tape tr{cursor:pointer}#tape tr:active{background:#111}
#tape .s{color:var(--hi);font-weight:700;width:92px}#tape .px{text-align:right;width:70px}#tape .ch{text-align:right;width:62px}#tape .m{width:52px}
#tape .m i{display:inline-block;width:9px;height:10px;margin-right:1px;background:var(--line2);vertical-align:middle}
#tape .m i.u{background:var(--up)}#tape .m i.d{background:var(--dn)}
#tape .oi{color:var(--dim);font-size:11px}
#tape td.fu{animation:fu 1.4s ease-out}#tape td.fd{animation:fd 1.4s ease-out}
@keyframes fu{0%{background:rgba(30,215,96,.45)}100%{background:transparent}}@keyframes fd{0%{background:rgba(255,59,74,.45)}100%{background:transparent}}
#idx .ix span.fu{color:var(--up)}#idx .ix span.fd{color:var(--dn)}
#tape .more{padding:6px 8px;color:var(--dim);font-size:11px;text-align:center;cursor:pointer}
/* NEWS */
#news .r{padding:5px 8px;border-bottom:1px solid var(--line);font-size:12px;display:grid;grid-template-columns:auto 1fr;gap:2px 8px}
#news .r .t{color:var(--dim);font-size:11px}#news .r b{color:var(--hi)}#news .r .h{grid-column:1/3;color:var(--txt)}
#news .r .w{grid-column:1/3;font-size:11px;color:var(--dim)}#news .sd{font-weight:700;margin-left:6px}
/* FOCUS */
#focus .hd{display:flex;align-items:baseline;gap:10px;padding:8px;border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .hd b{font-size:20px;color:var(--hi)}#focus .hd .px{font-size:16px}
#focus .m{padding:6px 8px;font-weight:700;border-bottom:1px solid var(--line)}
#focus svg{width:100%;height:150px;display:block;background:#000}
#focus .cap{padding:4px 8px;color:var(--dim);font-size:10px;border-bottom:1px solid var(--line)}
#focus .ag{padding:4px 8px;font-size:12px;border-bottom:1px solid var(--line)}#focus .ag b{color:var(--amber);text-transform:uppercase;font-size:10px;letter-spacing:.06em;margin-right:6px}
#focus .tk{padding:8px;background:#0c0a04;border-left:3px solid var(--amber);font-size:13px;color:var(--hi);white-space:pre-wrap}
#focus .nw{padding:6px 8px;font-size:12px;color:var(--txt)}#focus .nw em{font-style:normal;color:var(--dim)}
@media(max-width:899px){#focus.sheet{position:fixed;inset:0;z-index:30;overflow:auto;background:var(--panel);padding-bottom:40px}}

/* FOCUS v2: the share's own window */
#focus .tabs{display:flex;gap:1px;background:var(--line);border-bottom:1px solid var(--line)}
#focus .tabs span{flex:1;text-align:center;padding:5px 4px;font-size:10px;letter-spacing:.08em;color:var(--dim);background:var(--panel);cursor:pointer;text-transform:uppercase}
#focus .tabs span.on{color:var(--amber);border-bottom:2px solid var(--amber)}
#focus .sub{display:flex;gap:10px;padding:4px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .sub b{color:var(--txt);font-weight:400}
#focus svg.px{width:100%;height:230px;display:block;background:#000}
#focus svg.oit{width:100%;height:110px;display:block;background:#000}
/* THE OI LINE CHART (patch 92): full size, under the price chart */
#focus .oitw{border-top:1px solid var(--line);background:#05070a}
#focus .oitw .oith{display:flex;flex-wrap:wrap;gap:2px 8px;align-items:center;padding:5px 8px;font-size:11px;border-bottom:1px solid var(--line)}
#focus .oitw .oith>b{color:var(--amber);font-size:10px;letter-spacing:.08em;font-weight:700}
#focus .oitw .oith a{padding:2px 7px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;white-space:nowrap}
#focus .oitw .oith a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .oitw .oitr{width:100%;font-size:11px;color:var(--dim)}#focus .oitw .oitr b{font-weight:700}
#focus .oitw svg{display:block;width:100%;height:auto;max-height:none;touch-action:pan-y}
/* THE ALERT BAR (patch 93): only the clear-cut alerts, on every screen */
#abar{display:flex;align-items:stretch;gap:0;border-bottom:1px solid var(--line);background:#0b0d11;min-height:30px;font-size:11px}
#abar .al{flex:none;display:flex;align-items:center;padding:0 9px;font-weight:700;letter-spacing:.08em;color:#000;background:var(--dim);font-size:10px}
#abar.has-act .al{background:var(--dn);color:#fff}#abar.has-move .al{background:var(--amber)}
#abar .ac{flex:1;display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:3px 4px;align-items:center}#abar .ac::-webkit-scrollbar{display:none}
#abar .ch{flex:none;display:flex;gap:6px;align-items:center;padding:3px 8px;border:1px solid var(--line2);background:#000;cursor:pointer;white-space:nowrap;max-width:400px;overflow:hidden;text-overflow:ellipsis}
#abar .ch.act{border-color:var(--dn);background:#2a0b0e}#abar .ch.move{border-color:#7a5600;background:#1d1500}
#abar .ch .tg{font-size:9px;font-weight:700;padding:1px 4px;letter-spacing:.06em}#abar .ch.act .tg{background:var(--dn);color:#fff}#abar .ch.move .tg{background:var(--amber);color:#000}
#abar .ch .tm{color:var(--dim)}#abar .ch b{color:var(--hi)}#abar .ch .tk{color:var(--txt);overflow:hidden;text-overflow:ellipsis}
#abar .ch.fresh{animation:abfl 1s ease-in-out 8}
@keyframes abfl{0%,100%{box-shadow:none}50%{box-shadow:0 0 0 2px var(--amber2)}}
#abar .ae{color:var(--dim);padding:0 6px;white-space:nowrap}
#abar .ar{flex:none;display:flex;gap:4px;align-items:center;padding:0 6px;border-left:1px solid var(--line)}
#abar .ar a{cursor:pointer;padding:3px 7px;border:1px solid var(--line2);white-space:nowrap;font-size:10px;color:var(--txt);background:#000}
#abar .ar a.on{border-color:var(--up);color:var(--up)}
@media(max-width:700px){#abar{flex-wrap:wrap}#abar .al{padding:4px 9px}#abar .ar{margin-left:auto;border-left:0;padding:3px 4px}#abar .ac{order:3;flex-basis:100%;border-top:1px solid var(--line)}#abar .ch{max-width:92vw}#abar .ae{white-space:normal;font-size:10px}}
/* THE TICK CHART (patch 93): price tick by tick, the calls' / puts' OI under it on the same time axis */
#focus .pxm{display:inline-flex;gap:2px;margin-right:8px;vertical-align:middle}
#focus .pxm a{padding:1px 7px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;letter-spacing:.04em}
#focus .pxm a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .tkw{background:#05070a}
#focus .tkh{display:flex;flex-wrap:wrap;gap:3px 8px;align-items:center;padding:5px 8px;font-size:11px;border-bottom:1px solid var(--line)}
#focus .tkh .tkr{width:100%;color:var(--dim)}#focus .tkh .tkr b{font-weight:700}
#focus .tkh .tkm{width:100%;color:var(--dim);font-size:10px}
#focus .tkw svg{display:block;width:100%;height:auto;max-height:none;touch-action:pan-y}
/* HOME = THE TRADING SCREEN (patch 95): on a laptop / desktop the share's window IS the home page - no HOME / CLOSE inside it,
   the desk line, the ticket and the OI-scenario line one row each, so the charts get the height */
#focus.ws-on .hd .hm,#focus.ws-on .hd a.am{display:none}
#focus.ws-on .hd{padding:4px 8px}
#focus.ws-on .m,#focus.ws-on .tk,#focus.ws-on .rib{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-top:3px;padding-bottom:3px}
#focus.ws-on .tk{font-size:12px}
@media(min-width:1300px){body{font-size:13px}#focus .wsl>div{font-size:12px}}
#focus table.oi{width:100%;border-collapse:collapse;table-layout:fixed;font-size:11px}
#focus table.oi th{font-size:9px;color:var(--dim);font-weight:400;padding:3px 4px;border-bottom:1px solid var(--line);letter-spacing:.06em;text-align:right}
#focus table.oi th.k{text-align:center}#focus table.oi th.l{text-align:left}
#focus table.oi td{padding:3px 4px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap;position:relative;overflow:hidden}
#focus table.oi td.k{text-align:center;color:var(--hi);font-weight:700;background:#0b0e13}
#focus table.oi td.l{text-align:left}
#focus table.oi tr.atm td.k{color:var(--amber);outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi tr.wall td.k::after{content:" ▪";color:var(--amber)}
#focus table.oi td i{position:absolute;top:0;bottom:0;opacity:.22;z-index:0}
#focus table.oi td.ce i{right:0;background:var(--dn)}#focus table.oi td.pe i{left:0;background:var(--up)}
#focus table.oi td span{position:relative;z-index:1}
#focus table.oi td.d.up span{color:var(--up)}#focus table.oi td.d.dn span{color:var(--dn)}
#focus table.oi tr.tot td{color:var(--hi);border-top:1px solid var(--line2);font-weight:700}
#focus .legend{padding:3px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line)}
#focus .legend i{display:inline-block;width:9px;height:9px;vertical-align:middle;margin:0 3px 0 8px}
@media(min-width:1100px){#focus svg.px{height:260px}}

/* OI SCENARIOS (patch 84) */
#scn .r{display:grid;grid-template-columns:1fr auto auto;gap:2px 8px;padding:5px 8px;border-bottom:1px solid var(--line);align-items:baseline}
#scn .nm{color:var(--hi);font-weight:700;font-size:12px}#scn .nm .sd{font-size:10px;margin-left:6px;font-weight:400}
#scn .n{color:var(--amber);font-weight:700}#scn .ms{color:var(--dim);font-size:10px;text-align:right;white-space:nowrap}#scn .ms b{color:var(--up)}
#scn .sy{grid-column:1/4;font-size:11px;color:var(--dim);line-height:1.6}#scn .sy a{color:var(--txt);margin-right:10px;cursor:pointer;white-space:nowrap}#scn .sy a.box{color:var(--up)}
#scn .ft{padding:5px 8px;color:var(--dim);font-size:10px;line-height:1.5}
#focus .rib{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line);background:#0a0c10}#focus .rib b{color:var(--amber)}
#focus .scl{border-bottom:1px solid var(--line2)}#focus .scl div{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line)}#focus .scl .dim{font-size:10px}
@media(min-width:900px){#scn{grid-column:9/13;grid-row:4;max-height:45vh;overflow:auto}#news{grid-row:5}#tape{grid-row:4/6}}
@media(min-width:1100px){#scn{grid-column:10/13;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:4}#tape{grid-row:3/5}}

/* THE TRADING VIEW (patch 85): OI left, chart right, one price scale */
#focus .tv{display:block;background:#000;border-bottom:1px solid var(--line)}
#focus .tv svg{display:block;width:100%;height:auto;max-width:100%}
#focus .pat{padding:5px 8px;font-size:11px;color:var(--txt);border-bottom:1px solid var(--line);line-height:1.5}
#focus .pat b{color:var(--amber);font-weight:400}#focus .pat .u{color:var(--up)}#focus .pat .d{color:var(--dn)}
@media(min-width:1100px){#focus:not([hidden]){grid-column:4/13;grid-row:1}#focus:not([hidden])~#three{grid-column:10/13;grid-row:2}
  #focus:not([hidden])~#secs{grid-column:4/10;grid-row:2}}

/* patch 89: the index strip never overlaps · the function keys · one panel at a time */
#idx .ix{flex:none}
#tick .lb{position:relative;z-index:2}#tick{z-index:15}
@media(max-width:600px){#idx .ix{min-width:0;padding:3px 8px}#idx .ix span{font-size:12px}#idx .ix small{display:block;margin-left:0;font-size:10px}#idx .st{font-size:10px;gap:6px}}
#fkeys{display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:4px 8px 6px;background:#050607;border-top:1px solid var(--line)}
#fkeys::-webkit-scrollbar{display:none}
#fkeys a{flex:none;padding:5px 9px;border:1px solid var(--line2);color:var(--txt);font-size:11px;letter-spacing:.06em;cursor:pointer;white-space:nowrap;background:#000}
#fkeys a.on{background:var(--amber);color:#000;border-color:var(--amber);font-weight:700}
#fkeys a b{color:var(--amber);margin-right:4px;font-weight:700}#fkeys a.on b{color:#000}
.xp{display:none}
body.one #grid{grid-template-columns:1fr !important}
body.one #grid>section{display:none}
body.one #grid>section.on, body.one #grid>#focus:not([hidden]){display:block;grid-column:1/-1 !important;grid-row:auto !important;max-height:none !important}
.pn .r{display:grid;grid-template-columns:96px 1fr;gap:2px 10px;padding:6px 8px;border-bottom:1px solid var(--line);cursor:pointer}
.pn .r .sy b{color:var(--hi);font-size:13px}.pn .r .sy small{display:block;color:var(--dim);font-size:10px}
.pn .do{font-weight:700}.pn .do.up{color:var(--up)}.pn .do.dn{color:var(--dn)}.pn .why{color:var(--dim);font-size:11px}
.pn .hd2{padding:6px 8px;color:var(--amber);font-size:11px;letter-spacing:.08em;border-bottom:1px solid var(--line);background:#0a0c10}
.pn .kp{display:grid;grid-template-columns:repeat(2,1fr);gap:1px;background:var(--line)}
@media(min-width:900px){.pn .kp{grid-template-columns:repeat(4,1fr)}}
.pn .kp div{background:var(--panel);padding:8px}.pn .kp b{display:block;font-size:20px;color:var(--hi)}.pn .kp small{color:var(--dim);font-size:10px;letter-spacing:.06em}
.pn .bars{display:flex;align-items:flex-end;gap:2px;height:70px;padding:6px 8px;border-bottom:1px solid var(--line)}
.pn .bars i{flex:1;min-width:3px;display:block}
.pn form{display:flex;flex-wrap:wrap;gap:4px;padding:8px;border-bottom:1px solid var(--line)}
.pn input,.pn select{background:#000;color:var(--txt);border:1px solid var(--line2);font:12px var(--mono);padding:6px;width:86px}
.pn button{background:var(--amber);color:#000;border:0;font:700 11px var(--mono);padding:6px 10px;cursor:pointer}
.pn .msg{padding:4px 8px;font-size:11px;color:var(--amber)}

/* THE WORKSTATION (patch 91) */
#tape{min-width:0}#tapel{overflow-x:auto;max-width:100%}
@media(min-width:900px){#focus .wst{flex-wrap:wrap;max-height:74px;overflow-y:auto}}
#focus.ws-on{position:fixed;left:0;right:0;top:var(--toph,0px);bottom:30px;z-index:25;overflow:auto;background:var(--panel)}
#focus .hm{color:#000;background:var(--amber);padding:3px 9px;font-weight:700;cursor:pointer;font-size:12px;letter-spacing:.06em}
#focus .ws{display:grid;grid-template-columns:minmax(200px,14%) minmax(0,1.35fr) minmax(0,1fr) minmax(0,.85fr);gap:1px;background:var(--line);height:max(440px,calc(100vh - var(--toph,0px) - 230px))}
#focus .ws>div{background:var(--panel);min-width:0;overflow:auto}
#focus .wsh{padding:5px 8px;color:var(--amber);font-size:10px;letter-spacing:.08em;border-bottom:1px solid var(--line);background:#0a0c10;position:sticky;top:0;z-index:2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#focus .wsh span{color:var(--dim);letter-spacing:0;margin-left:6px}#focus .wsh b{color:var(--txt);font-weight:400}
#focus .wst{display:flex;gap:2px;overflow-x:auto;padding:4px;border-bottom:1px solid var(--line);scrollbar-width:none;position:sticky;top:0;background:var(--panel);z-index:2}
#focus .wst::-webkit-scrollbar{display:none}
#focus .wst a,#focus .wss a{flex:none;padding:3px 6px;border:1px solid var(--line2);font-size:9px;letter-spacing:.04em;cursor:pointer;white-space:nowrap;color:var(--txt);background:#000}
#focus .wst a.on,#focus .wss a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .wss{display:flex;gap:2px;flex-wrap:wrap;padding:4px;border-bottom:1px solid var(--line);align-items:center}
#focus .wss .dim{font-size:9px;margin-left:auto}
#focus .wsl>div{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:0 6px;padding:4px 6px;border-bottom:1px solid var(--line);font-size:11px;cursor:pointer}
#focus .wsl>div b{color:var(--hi);overflow:hidden;text-overflow:ellipsis}#focus .wsl>div small{grid-column:1/3;color:var(--dim);font-size:10px}
#focus .wsl>div.cur{background:#1a1406;outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi th.s{cursor:pointer;user-select:none}#focus table.oi th.on{color:var(--amber)}
#focus .ocsvg svg{display:block;width:100%;height:auto}
@media(max-width:899px){#focus .wsl{max-height:none}}
/* the news ticker at the bottom */
#tick{position:fixed;left:0;right:0;bottom:0;height:30px;background:#000;border-top:1px solid var(--amber);display:flex;align-items:center;overflow:hidden;z-index:15}
#tick .lb{background:var(--amber);color:#000;font-weight:700;font-size:11px;padding:0 8px;height:100%;display:flex;align-items:center;letter-spacing:.08em;flex:none}
#tick .run{white-space:nowrap;will-change:transform;font-size:12px;padding-left:12px}
#tick .run b{color:var(--hi)}#tick .run em{font-style:normal;color:var(--dim);margin:0 10px 0 0}
</style></head><body>
<div id="top">
  <div id="idx"></div>
  <div id="cmd"><span class="pr">&gt;</span><input id="q" placeholder="TICKER  ·  type a share, Enter = FOCUS" autocomplete="off" autocapitalize="characters"><button id="go">GO</button><select id="secsel"><option value="">ALL SECTORS</option></select><a class="x" id="unf" onclick="unfocus()">✕ ALL</a></div>
  <div id="fkeys"><a data-v="all" onclick="goHome()"><b>⌂</b>HOME</a><a data-v="now" onclick="setView('now')"><b>1</b>NOW</a><a data-v="three" onclick="setView('three')"><b>2</b>THE THREE</a><a data-v="scn" onclick="setView('scn')"><b>3</b>OI SCENARIOS</a><a data-v="secs" onclick="setView('secs')"><b>4</b>SECTORS</a><a data-v="tape" onclick="setView('tape')"><b>5</b>F&amp;O TAPE</a><a data-v="news" onclick="setView('news')"><b>6</b>NEWS</a><a data-v="picks" onclick="setView('picks')"><b>7</b>PICKS</a><a data-v="tom" onclick="setView('tom')"><b>8</b>TOMORROW</a><a data-v="myfo" onclick="setView('myfo')"><b>9</b>MY F&amp;O</a><a data-v="desk" onclick="setView('desk')"><b>0</b>DESK P&amp;L</a></div>
  <div id="abar"></div>
</div>
<div id="grid">
  <section class="p" id="now"><h2>NOW <small id="hnow">moving right now · newest first · every line went to Telegram the same second</small></h2><div id="nowl"></div></section>
  <section class="p" id="focus" hidden></section>
  <section class="p" id="three"><h2 id="h3">THE THREE</h2><div id="threel"></div></section>
  <section class="p" id="scn"><h2>OI SCENARIOS <small id="scnh">how the money is building up · today</small></h2><div id="scnl"><div class="empty">the scenario agent reads from 09:20 (open + 5)</div></div></section>
  <section class="p" id="secs"><h2>SECTORS <small>tap a sector to filter the tape · ++ EXTREME · + plain · ✓ confirmed</small></h2><div class="g" id="secg"></div></section>
  <section class="p" id="tape"><h2>F&amp;O TAPE <small id="tfoot"></small></h2><div id="tapel"></div></section>
  <section class="p" id="news"><h2>NEWS <small>filings + headlines · the reader's verdict</small></h2><div id="newsl"></div></section>
  <section class="p pn xp" id="picks"><h2>PICKS <small id="pkh">where to look now · every F&amp;O share's box, the ones that say BUY</small></h2><div id="pkl"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="tom"><h2>TOMORROW <small id="tmh">buy 14:30 · sell by 09:30 the day after</small></h2><div id="tml"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="myfo"><h2>MY F&amp;O <small>your real trades · net after charges</small></h2><div id="mfl"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="desk"><h2>DESK P&amp;L <small>the paper desk · since the start</small></h2><div id="dkl"><div class="empty">loading…</div></div></section>
</div>
<div id="tick"><div class="lb">NEWS</div><div class="run" id="run"></div></div>
<script>
const K=new URLSearchParams(location.search).get("k")||""; const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const pc=v=>v==null?"":(v>=0?"+":"")+Number(v).toFixed(2)+"%"; const cls=v=>v==null?"dim":v>0.05?"pu":v<-0.05?"pd":"dim";
const inr=v=>v==null?"":Number(v).toLocaleString("en-IN",{maximumFractionDigits:2});
let D=null, T3=null, FD=null, FOC="", SEL="", SECS=[], TAPE=[], seen=new Set(), first=true, sortBy="move", showAll=false, LASTIX={};
/* ---------- the index strip ---------- */
function idxHTML(d){ const I=d.idx||{}; const one=(n,x)=>{ if(!x) return ""; const o=LASTIX[n]; const f=(o!=null&&x.last!=null&&x.last!==o)?(x.last>o?" fu":" fd"):""; LASTIX[n]=x.last; return `<div class="ix"><b>${n}</b><div><span class="${f.trim()}">${x.last!=null?inr(x.last):"—"}</span><small class="${cls(x.chg)}">${pc(x.chg)}</small></div></div>`; };
  const deskLive=d.closed&&d.desk_t&&ageMin(d.desk_t)<3; const st=d.closed?(deskLive?`<span class="live">● DESK LIVE ${esc(d.desk_t)} (${esc(d.desk_src||"own pull")})</span>`:'<span class="closed">● CLOSED</span>'):'<span class="live">● LIVE</span>';
  return `<div class="brand" onclick="goHome()" style="cursor:pointer" title="home">⌂ GIR</div>${one("NIFTY",I.NIFTY)}${one("SENSEX",I.SENSEX)}${one("BANKNIFTY",I.BANKNIFTY)}${one("VIX",I.VIX)}<div class="st"><span id="clk">${istClock()}</span>${st}${d.ticks_s?`<span>${Math.round(d.ticks_s)} t/s</span>`:""}<span>${(d.now||[]).length} moving</span><span id="ago"></span>${d.ban&&d.ban.length?`<span class="pd">BAN ${esc(d.ban.join(" "))}</span>`:""}</div>`; }
function istClock(){ const t=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); return t.toTimeString().slice(0,8); }
function ageMin(hm){ const n=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const [h,m]=String(hm).split(":").map(Number); return (n.getHours()*60+n.getMinutes())-(h*60+m); }
let lastAt=0; setInterval(()=>{ const c=$("clk"); if(c) c.textContent=istClock(); const a=$("ago"); if(a&&lastAt) a.textContent=`upd ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s`; },1000);
/* ---------- NOW ---------- */
function nowHTML(rows){ if(!rows.length) return '<div class="empty">nothing has moved yet — the first lines come from 09:16 (🚀 RUNNING · ⚡ FIRST MOVE · 📗 ORDER BOOK) and 09:20 (your rules · 🧩 OI scenarios)</div>';
  return rows.slice(0,40).map(r=>{ const key=r.t+r.head; const isNew=!first&&!seen.has(key); seen.add(key); const sd=r.side==="CE"?"up":r.side==="PE"?"dn":"na";
    const head=(r.head||"").replace(/^(\S+\s+)/,""); const lines=(r.lines||[]).slice(0,3).map(l=>esc(l).replace(/\b(WATCH)\b/g,'<span class="w">$1</span>').replace(/\b(BUY)\b/g,'<span class="b">$1</span>')).join("\n");
    return `<div class="r${isNew?" new":""}" onclick="focusOn('${esc(r.s)}')"><div class="t">${esc(r.t)}</div><div class="s">${esc(r.s||"")}</div><div class="side ${sd}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"—"}</div><div class="h">${esc(r.kind||"")} ${esc(head)}</div>${lines?`<div class="l">${lines}</div>`:""}</div>`; }).join(""); }
/* ---------- THE THREE ---------- */
function threeHTML(T){ const ev=T&&T.evening, lv=T&&T.live; const X=(lv&&(lv.rows||[]).length)?lv:ev; if(!X||!(X.rows||[]).length){ $("h3").textContent="THE THREE"; return '<div class="empty">no list yet — the newsroom builds it at 18:30</div>'; }
  $("h3").innerHTML=(X===ev)?`THE THREE <small>for tomorrow · newsroom ${esc(X.t||"18:30")} · buy at 14:30, sell by 09:30 the day after</small>`:`THE THREE <small>today · ${esc(X.phase||"")}</small>`;
  return X.rows.slice(0,3).map(r=>{ const up=r.side==="CE"; const v=r.verdict||""; const vc=/^WAIT/.test(v)?"dn":/^WATCH|^SELL/.test(v)?"wt":(up?"pu":"pd"); const e=r.edge;
    return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="rk">${r.rank}</div><div class="l1"><b>${esc(r.s)}</b><span class="sd ${up?"pu":"pd"}">${up?"UP → CE":"DOWN → PE"}</span> <span class="${cls(r.chg)}">₹${inr(r.spot)} ${pc(r.chg)}</span></div><div></div>
      <div class="vd ${vc}">${esc(v.slice(0,150))}</div>
      <div class="l2">${r.k?`<em>${r.k} ${esc(r.side)} ₹${r.p}</em> · 1 lot ₹${inr(r.cost||0)} · stop ₹${r.stop_p} / share ${r.stop_share??"—"}${r.tgt?` · target ${r.tgt}`:""} · `:""}${e?`rule ${e[0]}% of ${e[1]}`:"not measured yet"}</div></div>`; }).join(""); }
async function loadThree(){ try{ const r=await fetch("three?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ T3=await r.json(); $("threel").innerHTML=threeHTML(T3); } }catch(e){} }
/* ---------- SECTORS ---------- */
function heat(c){ if(c==null) return "transparent"; const a=Math.min(1,Math.abs(c)/2.5)*0.55+0.08; return c>=0?`rgba(30,215,96,${a.toFixed(2)})`:`rgba(255,59,74,${a.toFixed(2)})`; }
function secHTML(S){ if(!S.length) return '<div class="empty">no sectors yet</div>';
  return S.map(s=>{ const ce=(s.ce||[])[0], pe=(s.pe||[])[0]; const pill=(ce&&Math.abs(ce.v)===2)?'<span class="pl pu">++</span>':(pe&&Math.abs(pe.v)===2)?'<span class="pl pd">++</span>':(ce||pe)?`<span class="pl ${ce?"pu":"pd"}">+</span>`:"";
    return `<div class="c${SEL===s.name?" sel":""}" style="background:${heat(s.chg)}" onclick="pickSector('${esc(s.name)}')">${pill}<div class="n">${esc(s.name)}</div><div class="v ${cls(s.chg)}">${s.chg==null?"—":pc(s.chg)}</div><div class="tb">${ce?`<span class="pu">${esc(ce.s)}${ce.conf?"✓":""}</span>`:""}${ce&&pe?" · ":""}${pe?`<span class="pd">${esc(pe.s)}${pe.conf?"✓":""}</span>`:""}${!ce&&!pe&&s.top?`<span class="pu">${esc(s.top.s)} ${pc(s.top.chg)}</span>`:""}</div></div>`; }).join(""); }
function pickSector(n){ SEL=(SEL===n)?"":n; $("secsel").value=SEL; drawSecs(); drawTape(); }
function drawSecs(){ $("secg").innerHTML=secHTML(SECS); }
/* ---------- TAPE ---------- */
function meter(v){ let h=""; for(let i=-2;i<=2;i++){ if(i===0){ h+='<i style="width:3px;background:var(--line2)"></i>'; continue; } const on=(v>0&&i>0&&i<=v)||(v<0&&i<0&&i>=v); h+=`<i class="${on?(v>0?"u":"d"):""}"></i>`; } return h; }
function sectorSyms(){ const s=SECS.find(x=>x.name===SEL); return s?new Set(s.syms||[]):null; }
let LASTPX={};
function drawTape(){ const set=sectorSyms(); let rows=set?TAPE.filter(r=>set.has(r.s)):TAPE.slice();
  const by={move:(a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0), desk:(a,b)=>Math.abs(b.v||0)-Math.abs(a.v||0)||Math.abs(b.chg||0)-Math.abs(a.chg||0), name:(a,b)=>a.s<b.s?-1:1, chg:(a,b)=>(b.chg||0)-(a.chg||0)};
  rows.sort(by[sortBy]||by.move); const n=rows.length; if(!showAll&&window.innerWidth<900) rows=rows.slice(0,40);
  const th=(k,l)=>`<th class="${sortBy===k?"on":""}" onclick="sortBy='${k}';drawTape()">${l}${sortBy===k?" ▾":""}</th>`;
  $("tapel").innerHTML=`<table><thead><tr>${th("name","SHARE")}${th("chg","PRICE")}${th("move","CHG")}${th("desk","DESK")}<th>WHAT THE OI SAYS</th></tr></thead><tbody>`+
    rows.map(r=>{ const o=LASTPX[r.s]; const f=(o!=null&&r.px!=null&&r.px!==o)?(r.px>o?" fu":" fd"):""; return `<tr onclick="focusOn('${esc(r.s)}')"><td class="s">${esc(r.s)}</td><td class="px hi${f}">${r.px!=null?inr(r.px):"—"}</td><td class="ch ${cls(r.chg)}">${pc(r.chg)}</td><td class="m">${meter(r.v||0)}${r.conf?'<span class="pu"> ✓</span>':""}</td><td class="oi">${esc(r.oi||(r.bu?r.bu.toLowerCase()+(r.cr?` ₹${Math.round(r.cr)} cr`:""):"—"))}</td></tr>`; }).join("")+
    `</tbody></table>`+(n>rows.length?`<div class="more" onclick="showAll=true;drawTape()">show all ${n} shares</div>`:"");
  LASTPX={}; for(const r of TAPE) LASTPX[r.s]=r.px;
  $("tfoot").textContent=`${n} ${SEL?SEL+" ":""}shares · ${D&&D.desk_t?`desk ${D.desk_t} (${D.desk_src||""})`:`desk: no reading yet`}`; }
/* ---------- NEWS ---------- */
function newsHTML(N){ if(!N.length) return '<div class="empty">no news read in the last 26 hours</div>';
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${esc(x.h)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${esc(x.h)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
let nx=0; function runNews(){ const R=$("run"); const w=R.scrollWidth; nx+=0.55; if(nx>w) nx=0; R.style.transform=`translateX(${-nx}px)`; requestAnimationFrame(runNews); } requestAnimationFrame(runNews);
/* ---------- OI SCENARIOS (patch 84) ---------- */
const SCAT={};
function scnPill(c){ return c.side==="CE"?'<span class="sd pu">UP → CE</span>':c.side==="PE"?'<span class="sd pd">DOWN → PE</span>':c.side==="dyn"?'<span class="sd am">TURN</span>':'<span class="sd dim">READING</span>'; }
function scnHTML(S){ if(!S||!S.cat) return '<div class="empty">the scenario agent reads from 09:20 (open + 5)</div>';
  for(const c of S.cat) SCAT[c.id]=c; const sc=S.scores||{}; const by={};
  for(const r of (S.today||[])) (by[r.id]=by[r.id]||[]).push(r);
  const ids=Object.keys(by).sort((a,b)=>by[b].length-by[a].length);
  const ms=id=>{ const v=sc[id]; const a=(SCAT[id]||{}).acts; return v?(v[1]>=50&&v[0]>=55?`<b>${v[0]}% of ${v[1]}${a?" · BUY":" · proven"}</b>`:`${v[0]}% of ${v[1]}`):(a?"new · WATCH":"new"); };
  let h=ids.map(id=>{ const c=SCAT[id]||{name:id}; const seen=new Set(), syms=[]; for(const r of by[id].slice().reverse()){ if(!seen.has(r.s)){ seen.add(r.s); syms.push(r); } }
    return `<div class="r"><div class="nm">${esc(c.name)}${scnPill(c)}</div><div class="n">${by[id].length}</div><div class="ms">${ms(id)}</div><div class="sy">${syms.slice(0,8).map(r=>`<a class="${r.ch==="box"?"box":""}" onclick="focusOn('${esc(r.s)}')">${esc(r.s)} <span class="dim">${esc(r.t)}</span></a>`).join("")}${syms.length>8?`<span>+${syms.length-8} more</span>`:""}</div></div>`; }).join("");
  if(!ids.length) h='<div class="empty">no OI scenario has fired yet today</div>';
  const quiet=S.cat.filter(c=>!by[c.id]).map(c=>c.name.toLowerCase());
  return h+`<div class="ft">${S.cat.length} scenarios watched on every F&amp;O share every 5 s · a scenario fires after holding ${S.hold||60} s, once a share a day · green share = went to Box Picks (measured BUY) · the number = right on the same-day close, this server · quiet today: ${esc(quiet.join(" · "))}</div>`; }
function scnRibbon(sym){ const f=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===sym).slice(-3).reverse(); if(!f.length) return "";
  return `<div class="rib">🧩 ${f.map(r=>`<b>${esc(r.t)}</b> ${esc(r.name)} <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span>`).join(" · ")} <span class="dim">· the OI BUILD-UP tab has the numbers · 🧩 marks them on the chart</span></div>`; }
function scnFocus(){ const d=FD&&FD.desk; const hold=((d&&d.scn)||[]).filter(h=>!h.fired); const fired=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).slice().reverse();
  if(!hold.length&&!fired.length) return '<div class="scl"><div class="dim">OI SCENARIOS on this share: nothing has built up yet today</div></div>';
  return `<div class="scl">${fired.map(r=>`<div><b class="am">${esc(r.t)}</b> 🧩 <b>${esc(r.name)}</b> <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span> · ${esc(r.word)}${r.ch==="box"?" · went to Box Picks":r.ch==="read"?" · GIR Intraday":""}<br><span class="dim">${esc(r.line)}</span></div>`).join("")}${hold.map(h=>`<div><span class="am">holding ${h.held}s</span> 🧩 ${esc(h.name)} <span class="dim">— ${esc(h.line)}</span></div>`).join("")}</div>`; }
/* ---------- THE TRADING VIEW (patch 85): OI left, chart right, one price scale ---------- */
function vwapSeries(C,H,L,V){ let pv=0,vv=0; return C.map((c,i)=>{ if(c==null) return null; const tp=((H[i]??c)+(L[i]??c)+c)/3, v=V[i]||0; pv+=tp*v; vv+=v; return vv?pv/vv:c; }); }
function wallsOf(rows,spot){ let roof=null,floor=null; for(const r of rows){ if(r.k>=spot&&(r.ce_oi||0)>0&&(!roof||r.ce_oi>roof.oi)) roof={k:r.k,oi:r.ce_oi}; if(r.k<=spot&&(r.pe_oi||0)>0&&(!floor||r.pe_oi>floor.oi)) floor={k:r.k,oi:r.pe_oi}; } return {roof,floor}; }
function minIdx(hm){ const m=String(hm||"").match(/(\d+):(\d+)/); if(!m) return null; return Math.floor(((+m[1])*60+(+m[2])-555)/5); }
function chartPatterns(O,H,L,C,V,roof,floor){ const n=C.length, marks=[], txt=[]; let orb=null;
  const okH=H.slice(0,3).filter(x=>x!=null), okL=L.slice(0,3).filter(x=>x!=null);
  if(n>=4&&okH.length){ orb={hi:Math.max(...okH),lo:Math.min(...okL)}; let br=null;
    for(let i=3;i<n;i++){ if(C[i]==null) continue; if(C[i]>orb.hi){ br={i,up:true}; break; } if(C[i]<orb.lo){ br={i,up:false}; break; } }
    if(br){ marks.push({i:br.i,up:br.up,t:br.up?"ORB▲":"ORB▼"}); txt.push(`opening range ${inr(orb.lo)}–${inr(orb.hi)} broke <span class="${br.up?"u":"d"}">${br.up?"UP":"DOWN"}</span> at <b>${hhmm(br.i+1)}</b>`); }
    else txt.push(`still inside the opening range ${inr(orb.lo)}–${inr(orb.hi)}`); }
  const vw=vwapSeries(C,H,L,V); let side=null,lastX=null;
  for(let i=1;i<n;i++){ if(C[i]==null||vw[i]==null) continue; const sd=C[i]>=vw[i]; if(side!==null&&sd!==side) lastX={i,up:sd}; side=sd; }
  if(lastX){ marks.push({i:lastX.i,up:lastX.up,t:lastX.up?"VWAP▲":"VWAP▼"}); txt.push(`<span class="${side?"u":"d"}">${side?"above":"below"}</span> VWAP since <b>${hhmm(lastX.i+1)}</b>`); }
  else if(side!==null) txt.push(`<span class="${side?"u":"d"}">${side?"above":"below"}</span> VWAP all day`);
  let hi=-Infinity,lo=Infinity,nh=null,nl=null;
  for(let i=0;i<n;i++){ if(H[i]!=null){ if(i>=9&&H[i]>hi&&C[i]!=null&&C[i]>=hi) nh=i; hi=Math.max(hi,H[i]); } if(L[i]!=null){ if(i>=9&&L[i]<lo&&C[i]!=null&&C[i]<=lo) nl=i; lo=Math.min(lo,L[i]); } }
  if(nh!=null&&(nl==null||nh>nl)){ marks.push({i:nh,up:true,t:"HIGH▲"}); txt.push(`new day high closed at <b>${hhmm(nh+1)}</b>`); }
  else if(nl!=null){ marks.push({i:nl,up:false,t:"LOW▼"}); txt.push(`new day low closed at <b>${hhmm(nl+1)}</b>`); }
  for(const [w,isR] of [[roof,true],[floor,false]]){ if(!w) continue; let tests=0,brk=null,prev=null;
    for(let i=0;i<n;i++){ if(C[i]==null) continue; const beyond=isR?C[i]>w.k:C[i]<w.k;
      if(beyond&&prev===false) brk=i;                                   // a cross FROM the protected side only
      if(!beyond){ if(isR?(H[i]!=null&&H[i]>=w.k*0.997):(L[i]!=null&&L[i]<=w.k*1.003)) tests++; }
      prev=beyond; }
    const nowBeyond=n&&C[n-1]!=null&&(isR?C[n-1]>w.k:C[n-1]<w.k);
    if(brk!=null&&nowBeyond){ marks.push({i:brk,up:isR,t:(isR?"ROOF ":"FLOOR ")+w.k}); txt.push(`closed ${isR?"above the roof":"below the floor"} <b>${w.k}</b> at <b>${hhmm(brk+1)}</b> and is holding — the ${isR?"call":"put"} sellers there are trapped`); }
    else if(brk!=null){ marks.push({i:brk,up:!isR,t:"FAIL "+w.k}); txt.push(`broke ${isR?"above the roof":"below the floor"} <b>${w.k}</b> at <b>${hhmm(brk+1)}</b> and fell back — <span class="${isR?"d":"u"}">a failed break</span>`); }
    else if(tests) txt.push(`tested the ${isR?"roof":"floor"} <b>${w.k}</b> ${tests}× — it held`); }
  const k=[]; for(let i=Math.max(0,n-7);i<n;i++) if(L[i]!=null&&H[i]!=null) k.push(i);
  if(k.length>=5){ let hl=0,lh=0; for(let j=1;j<k.length;j++){ if(L[k[j]]>L[k[j-1]]) hl++; if(H[k[j]]<H[k[j-1]]) lh++; }
    if(hl>=k.length-2) txt.push(`<span class="u">trend up</span>: ${hl} of the last ${k.length-1} candles made a higher low`);
    else if(lh>=k.length-2) txt.push(`<span class="d">trend down</span>: ${lh} of the last ${k.length-1} candles made a lower high`);
    else txt.push("no clear trend in the last 30 min"); }
  return {marks,txt,orb,vw}; }
function tradingView(ch,lv,opt){ opt=opt||{}; const box=(opt.box&&$(opt.box))||$("fbody")||$("focus"); const W=Math.max(320,Math.floor((box&&box.clientWidth)||700)); const phone=W<600; const Hh=opt.h||(phone?320:360);
  const rows=oiRows(); const spot=(lv&&lv.px)||(FD&&(FD.px||FD.spot))||0;
  const n=ch&&ch.c?ch.c.length:0; const O=n?ch.o.slice():[],H=n?ch.h.slice():[],L=n?ch.l.slice():[],C=n?ch.c.slice():[],V=n?(ch.v||[]).slice():[];
  if(n&&lv&&lv.px!=null){ const i=n-1; C[i]=lv.px; H[i]=Math.max(H[i]??lv.px,lv.px); L[i]=Math.min(L[i]??lv.px,lv.px); }
  const {roof,floor}=wallsOf(rows,spot||C[n-1]||0);
  const P=chartPatterns(O,H,L,C,V,roof,floor);
  let vals=[].concat(H,L).filter(x=>x!=null); if(spot) vals.push(spot); if(roof) vals.push(roof.k); if(floor) vals.push(floor.k);
  if(!vals.length) return {svg:'<div class="empty">no price and no strikes read yet</div>',txt:[]};
  const ref=spot||vals[vals.length-1]; let lo=Math.max(Math.min(...vals),ref*0.94), hi=Math.min(Math.max(...vals),ref*1.06); const pad=(hi-lo)*0.06||ref*0.01; lo-=pad; hi+=pad;
  const LW=opt.profile===false?0:Math.round(W*(phone?0.40:0.34)), RX0=opt.profile===false?0:LW+4, RM=phone?50:58, T=18, B=18, VH=phone?22:30;
  const y=v=>T+(Hh-T-B-VH)*(1-(v-lo)/(hi-lo)); const ybot=Hh-B;
  let g=`<rect x="0" y="0" width="${LW}" height="${Hh}" fill="#05070a"/>`;
  // ---- left: the OI at each strike, on the chart's price scale
  if(LW>0){
  const vis=rows.filter(r=>r.k>=lo&&r.k<=hi).sort((a,b)=>b.k-a.k);
  const gapPx=vis.length>1?Math.min(...vis.slice(1).map((r,i)=>Math.abs(y(vis[i].k)-y(r.k)))):20; const bh=Math.max(2,Math.min(phone?7:9,gapPx*0.42));
  const mx=Math.max(...vis.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=LW/2, KWH=phone?19:23, half=KX-KWH-2;
  const atm=vis.length?vis.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,vis[0]):null;
  g+=`<text x="4" y="12" fill="var(--dn)" font-size="10" font-family="monospace">CALLS</text><text x="${LW-4}" y="12" fill="var(--up)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  for(const r of vis){ const yy=y(r.k); const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    const bar=(oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
      let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
      if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
      if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
      return o; };
    g+=bar(r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(r.pe_oi,r.pe_d,1,"var(--up)");
    g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="${phone?9:10}" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; }
  }
  // ---- right: the candles
  const NB=Math.min(75,Math.max(n+6,42)); const bw=(W-RX0-RM)/NB; const cx=i=>RX0+i*bw+bw/2;     // the session so far, widening through the day
  [0,0.25,0.5,0.75,1].forEach(f=>{ const v=lo+(hi-lo)*f; g+=`<line x1="${RX0}" x2="${W-RM}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-RM+3}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace">${inr(Math.round(v*10)/10)}</text>`; });
  if(P.orb) g+=`<rect x="${RX0}" y="${y(P.orb.hi).toFixed(1)}" width="${(3*bw).toFixed(1)}" height="${Math.max(1,y(P.orb.lo)-y(P.orb.hi)).toFixed(1)}" fill="var(--amber)" opacity=".10"/><line x1="${RX0}" x2="${W-RM}" y1="${y(P.orb.hi).toFixed(1)}" y2="${y(P.orb.hi).toFixed(1)}" stroke="var(--amber)" stroke-dasharray="1 4" opacity=".5"/><line x1="${RX0}" x2="${W-RM}" y1="${y(P.orb.lo).toFixed(1)}" y2="${y(P.orb.lo).toFixed(1)}" stroke="var(--amber)" stroke-dasharray="1 4" opacity=".5"/>`;
  if(ch&&ch.pc!=null&&ch.pc>lo&&ch.pc<hi) g+=`<line x1="${RX0}" x2="${W-RM}" y1="${y(ch.pc).toFixed(1)}" y2="${y(ch.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${W-RM+3}" y="${(y(ch.pc)-3).toFixed(1)}" fill="var(--dim)" font-size="8" font-family="monospace">prev</text>`;
  // the roof and the floor: across BOTH panes - the day's resistance and support, from the OI
  for(const [w,col,lab] of [[roof,"var(--dn)","ROOF"],[floor,"var(--up)","FLOOR"]]){ if(!w||w.k<lo||w.k>hi) continue;
    g+=`<line x1="0" x2="${W-RM}" y1="${y(w.k).toFixed(1)}" y2="${y(w.k).toFixed(1)}" stroke="${col}" stroke-width="1.2" stroke-dasharray="6 3" opacity=".85"/><text x="${RX0+4}" y="${(y(w.k)+(lab==="ROOF"?-4:11)).toFixed(1)}" fill="${col}" font-size="10" font-weight="700" font-family="monospace">${lab} ${w.k} · ${fmtL(w.oi)} ${lab==="ROOF"?"calls":"puts"}</text>`; }
  const vmax=Math.max(...V.filter(x=>x),1);
  for(let i=0;i<n;i++){ if(C[i]==null||O[i]==null) continue; const x=cx(i), up=C[i]>=O[i], col=up?"var(--up)":"var(--dn)";
    g+=`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(H[i]).toFixed(1)}" y2="${y(L[i]).toFixed(1)}" stroke="${col}"/>`;
    const y0=y(Math.max(O[i],C[i])), y1=y(Math.min(O[i],C[i])); g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${y0.toFixed(1)}" width="${Math.max(1,bw*0.72).toFixed(1)}" height="${Math.max(1,y1-y0).toFixed(1)}" fill="${col}"/>`;
    if(V[i]) g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${(ybot-(V[i]/vmax)*(VH-4)).toFixed(1)}" width="${Math.max(1,bw*0.72).toFixed(1)}" height="${((V[i]/vmax)*(VH-4)).toFixed(1)}" fill="${col}" opacity=".35"/>`; }
  const vpts=P.vw.map((v,i)=>v==null?null:`${cx(i).toFixed(1)},${y(v).toFixed(1)}`).filter(Boolean); if(vpts.length>1) g+=`<polyline fill="none" stroke="var(--amber)" stroke-width="1.3" points="${vpts.join(" ")}"/>`;
  for(const m of P.marks){ if(m.i==null||H[m.i]==null) continue; const x=cx(m.i), yy=m.up?y(L[m.i])+12:y(H[m.i])-6;
    g+=`<text x="${x.toFixed(1)}" y="${Math.min(ybot-VH,Math.max(T+8,yy)).toFixed(1)}" fill="${m.up?"var(--up)":"var(--dn)"}" font-size="9" font-weight="700" font-family="monospace" text-anchor="middle">${m.t}</text>`; }
  for(const r of ((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC)){ const i=minIdx(r.t); if(i==null||i<0||i>74) continue;
    if(i>=NB) continue;
    g+=`<g><title>${esc(r.t+" "+r.name)}</title><text x="${cx(i).toFixed(1)}" y="${T-4}" font-size="10" text-anchor="middle">🧩</text><line x1="${cx(i).toFixed(1)}" x2="${cx(i).toFixed(1)}" y1="${T}" y2="${ybot-VH}" stroke="var(--amber)" stroke-dasharray="1 3" opacity=".35"/></g>`; }
  const last=n?C[n-1]:spot; if(last!=null){ const upd=ch&&ch.pc!=null?last>=ch.pc:true;
    g+=`<line x1="0" x2="${W-RM}" y1="${y(last).toFixed(1)}" y2="${y(last).toFixed(1)}" stroke="${upd?"var(--up)":"var(--dn)"}" stroke-dasharray="2 3" opacity=".55"/><rect x="${W-RM+1}" y="${(y(last)-8).toFixed(1)}" width="${RM-2}" height="15" fill="${upd?"var(--up)":"var(--dn)"}"/><text x="${W-RM+4}" y="${(y(last)+3).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(last)}</text>`; }
  [0,6,12,18,24,30,36,42,48,54,60,66,72].filter(i=>i<NB).filter((i,j,a)=>NB<=48||j%2===0).forEach(i=>{ g+=`<text x="${cx(i).toFixed(1)}" y="${Hh-5}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="${i===0?"start":"middle"}">${hhmm(i)}</text>`; });
  if(LW>0) g+=`<line x1="${LW+1.5}" x2="${LW+1.5}" y1="0" y2="${Hh}" stroke="var(--line2)"/>`;
  return {svg:`<svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${g}</svg>`,txt:P.txt}; }
window.addEventListener("resize",()=>{ if(FOC){ const F=$("focus"); if(window.innerWidth<900){ F.classList.remove("ws-on"); F.classList.add("sheet"); } else { F.classList.remove("sheet"); F.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); } paint(); } });
/* ---------- FOCUS: the share's own live window ---------- */
let FT={live:null,chart:null,oi:null}, FCH=null, FLV=null, FOI=null, FTAB="chart";
const fmtL=v=>v==null?"—":(Math.abs(v)>=1e5?(v/1e5).toFixed(2)+" L":Math.round(v).toLocaleString("en-IN"));
const dL=v=>v==null?"":(v>=0?"+":"−")+(Math.abs(v)>=1e5?(Math.abs(v)/1e5).toFixed(2)+" L":Math.round(Math.abs(v)).toLocaleString("en-IN"));
function hhmm(i){ const m=9*60+15+i*5; return `${String(Math.floor(m/60)).padStart(2,"0")}:${String(m%60).padStart(2,"0")}`; }
function candleSVG(ch,lv){ if(!ch||!(ch.c||[]).length) return '<div class="empty">no candles yet today</div>';
  const n=ch.c.length; const O=ch.o.slice(),H=ch.h.slice(),L=ch.l.slice(),C=ch.c.slice(),V=ch.v||[];
  if(lv&&lv.px!=null&&n){ const i=n-1; C[i]=lv.px; H[i]=Math.max(H[i]??lv.px,lv.px); L[i]=Math.min(L[i]??lv.px,lv.px); }
  const W=720,Hh=230,Lm=6,Rm=58,T=10,B=22,VH=34; const bw=(W-Lm-Rm)/75; const vals=[].concat(H,L,[ch.pc,ch.vw].filter(x=>x!=null)).filter(x=>x!=null);
  let lo=Math.min(...vals), hi=Math.max(...vals); const pad=(hi-lo)*0.06||1; lo-=pad; hi+=pad; const y=v=>T+(Hh-T-B-VH)*(1-(v-lo)/(hi-lo));
  const vmax=Math.max(...V,1); const yv=v=>(Hh-B)-(v/vmax)*(VH-4);
  let g=""; for(let i=0;i<n;i++){ if(C[i]==null||O[i]==null) continue; const x=Lm+i*bw+bw/2; const up=C[i]>=O[i]; const col=up?"var(--up)":"var(--dn)";
    g+=`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(H[i]).toFixed(1)}" y2="${y(L[i]).toFixed(1)}" stroke="${col}" stroke-width="1"/>`;
    const y0=y(Math.max(O[i],C[i])), y1=y(Math.min(O[i],C[i])); g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${y0.toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${Math.max(1,y1-y0).toFixed(1)}" fill="${up?"var(--up)":"var(--dn)"}"/>`;
    if(V[i]) g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${yv(V[i]).toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${((Hh-B)-yv(V[i])).toFixed(1)}" fill="${col}" opacity=".35"/>`; }
  const grid=[0,0.25,0.5,0.75,1].map(f=>{ const v=lo+(hi-lo)*f; return `<line x1="${Lm}" x2="${W-Rm}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-Rm+4}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(Math.round(v*10)/10)}</text>`; }).join("");
  const xs=[0,12,24,36,48,60,72].map(i=>`<text x="${(Lm+i*bw).toFixed(1)}" y="${Hh-6}" fill="var(--dim)" font-size="10" font-family="monospace">${hhmm(i)}</text>`).join("");
  const pcl=ch.pc!=null?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pc).toFixed(1)}" y2="${y(ch.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${W-Rm+4}" y="${(y(ch.pc)-4).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace">prev ${inr(ch.pc)}</text>`:"";
  const vwl=ch.vw!=null?`<line x1="${Lm}" x2="${(Lm+n*bw).toFixed(1)}" y1="${y(ch.vw).toFixed(1)}" y2="${y(ch.vw).toFixed(1)}" stroke="var(--amber)" stroke-width="1" opacity=".8"/><text x="${W-Rm+4}" y="${(y(ch.vw)+10).toFixed(1)}" fill="var(--amber)" font-size="9" font-family="monospace">vwap ${inr(ch.vw)}</text>`:"";
  const last=C[n-1]; const up=ch.pc!=null?last>=ch.pc:true;
  const lpx=last!=null?`<rect x="${W-Rm+1}" y="${(y(last)-8).toFixed(1)}" width="${Rm-2}" height="15" fill="${up?"var(--up)":"var(--dn)"}"/><text x="${W-Rm+4}" y="${(y(last)+3).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(last)}</text><line x1="${Lm}" x2="${W-Rm}" y1="${y(last).toFixed(1)}" y2="${y(last).toFixed(1)}" stroke="${up?"var(--up)":"var(--dn)"}" stroke-dasharray="2 3" opacity=".7"/>`:"";
  const pdh=ch.pdh!=null&&ch.pdh<hi&&ch.pdh>lo?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pdh).toFixed(1)}" y2="${y(ch.pdh).toFixed(1)}" stroke="var(--line2)" stroke-dasharray="1 4"/>`:"";
  return `<svg class="px" viewBox="0 0 ${W} ${Hh}" preserveAspectRatio="none">${grid}${pdh}${pcl}${vwl}${g}${lpx}${xs}</svg>`; }
function oiRows(){ const o=(FLV&&FLV.ok&&FLV.o&&Object.keys(FLV.o).length)?FLV.o:null; const R=(FOI&&FOI.rows)||{}; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||(FD&&FD.px);
  let ks=o?Object.keys(o).map(Number):(FD&&FD.strikes||[]).map(x=>x.k); if(!ks.length) ks=Object.keys(R).map(Number); ks=[...new Set(ks)].filter(k=>k&&spot&&Math.abs(k/spot-1)<=0.08).sort((a,b)=>b-a);
  return ks.map(k=>{ const kk=String(k); const lo=o&&(o[kk]||o[("%s"===""?kk:kk)]); const ref=R[("%g".length,String(+k))]||R[kk]||{}; const fs=(FD&&FD.strikes||[]).find(x=>x.k===k)||{};
    const ce_oi=lo?lo[1]:(ref.ce?ref.ce[1]:fs.ce), pe_oi=lo?lo[3]:(ref.pe?ref.pe[1]:fs.pe), ce_p=lo?lo[0]:(ref.ce?ref.ce[2]:null), pe_p=lo?lo[2]:(ref.pe?ref.pe[2]:null);
    const ce_d=(ref.ce&&ref.ce[0]!=null&&ce_oi!=null)?ce_oi-ref.ce[0]:null, pe_d=(ref.pe&&ref.pe[0]!=null&&pe_oi!=null)?pe_oi-ref.pe[0]:null;
    return {k,ce_oi,pe_oi,ce_p,pe_p,ce_d,pe_d}; }); }
function oiTable(){ let rows=oiRows(); if(OIS.f){ const sp=(FLV&&FLV.px)||(FD&&FD.spot)||0; const near=rows.slice().sort((a,b)=>Math.abs(a.k-sp)-Math.abs(b.k-sp)).slice(0,11).map(r=>r.k);
    rows=rows.filter(r=>OIS.f==="near"?near.includes(r.k):OIS.f==="ce"?(r.ce_d||0)>0:OIS.f==="pe"?(r.pe_d||0)>0:OIS.f==="cl"?((r.ce_d||0)<0||(r.pe_d||0)<0):true); if(!rows.length) return '<div class="empty">no strike matches this filter</div>'; } if(OIS.k!=="k"||OIS.dir!==-1){ const f=r=>r[OIS.k]??-1e18; rows.sort((a,b)=>(f(a)<f(b)?-1:f(a)>f(b)?1:0)*OIS.dir); } if(!rows.length) return '<div class="empty">no strikes read yet</div>'; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||0;
  const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const atm=rows.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,rows[0]);
  const roof=FD&&FD.roof&&FD.roof.k, floor=FD&&FD.floor&&FD.floor.k; let tce=0,tpe=0,tced=0,tped=0,hasd=false;
  const tr=rows.map(r=>{ tce+=r.ce_oi||0; tpe+=r.pe_oi||0; if(r.ce_d!=null){tced+=r.ce_d;hasd=true;} if(r.pe_d!=null){tped+=r.pe_d;}
    const cw=((r.ce_oi||0)/mx*100).toFixed(0), pw=((r.pe_oi||0)/mx*100).toFixed(0);
    return `<tr class="${r===atm?"atm":""}${(r.k===roof||r.k===floor)?" wall":""}"><td class="d ${r.ce_d>0?"up":r.ce_d<0?"dn":""}"><span>${dL(r.ce_d)}</span></td><td class="ce"><i style="width:${cw}%"></i><span>${fmtL(r.ce_oi)}</span></td><td><span>${r.ce_p!=null?r.ce_p:"—"}</span></td><td class="k">${r.k}</td><td class="l"><span>${r.pe_p!=null?r.pe_p:"—"}</span></td><td class="pe l"><i style="width:${pw}%"></i><span>${fmtL(r.pe_oi)}</span></td><td class="d l ${r.pe_d>0?"up":r.pe_d<0?"dn":""}"><span>${dL(r.pe_d)}</span></td></tr>`; }).join("");
  const pcr=tce?(tpe/tce).toFixed(2):"—";
  return `<table class="oi"><thead><tr>${oth("ce_d","CE ΔOI","")}${oth("ce_oi","CE OI","")}${oth("ce_p","CE LTP","")}${oth("k","STRIKE","k")}${oth("pe_p","PE LTP","l")}${oth("pe_oi","PE OI","l")}${oth("pe_d","PE ΔOI","l")}</tr></thead><tbody>${tr}<tr class="tot"><td class="d ${tced>0?"up":tced<0?"dn":""}"><span>${hasd?dL(tced):""}</span></td><td><span>${fmtL(tce)}</span></td><td><span class="dim">calls</span></td><td class="k">PCR ${pcr}</td><td class="l"><span class="dim">puts</span></td><td class="l"><span>${fmtL(tpe)}</span></td><td class="d l ${tped>0?"up":tped<0?"dn":""}"><span>${hasd?dL(tped):""}</span></td></tr></tbody></table>`; }
let OIT="chg"; try{ OIT=localStorage.getItem("gir_oit")||"chg"; }catch(e){}
function oitMode(m){ OIT=m; try{ localStorage.setItem("gir_oit",m); }catch(e){} paint(); }
function oiTrendData(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return null; const n=S.t.length;
  const ce=S.ce.slice(), pe=S.pe.slice(); const sp=(S.spot||[]).map(v=>v==null?null:+v);
  return {n, t:S.t, ce, pe, sp, ced:ce.map(v=>v-ce[0]), ped:pe.map(v=>v-pe[0]), pcr:ce.map((v,i)=>v?pe[i]/v:null)}; }
function oitRead(D,i){ const sg=v=>(v>0?"+":"")+fmtL(v).replace(/^\+/,""); const pcr=D.pcr[i];
  return `<b class="am">${esc(D.t[i])}</b> · <span style="color:var(--dn)">CALLS <b>${fmtL(D.ce[i])}</b> (${sg(D.ced[i])})</span> · <span style="color:var(--up)">PUTS <b>${fmtL(D.pe[i])}</b> (${sg(D.ped[i])})</span> · PCR <b>${pcr!=null?pcr.toFixed(2):"—"}</b>${D.sp[i]!=null?` · price <b class="am">₹${inr(D.sp[i])}</b>`:""}`; }
function oiTrendSVG(boxId,hh){ const D=oiTrendData(); if(!D) return "";
  const box=boxId&&$(boxId); const W=Math.max(260,Math.floor((box&&box.clientWidth)||560)); const H=hh||Math.max(190,Math.min(260,Math.round(W*0.42)));
  const L=50,R=56,T=10,B=20, n=D.n; const pw=W-L-R, ph=H-T-B; const x=i=>L+pw*(i/(n-1));
  const ser=OIT==="tot"?[[D.ce,"var(--dn)"],[D.pe,"var(--up)"]]:OIT==="pcr"?[[D.pcr,"#4fc3f7"]]:[[D.ced,"var(--dn)"],[D.ped,"var(--up)"]];
  const vals=[].concat(...ser.map(z=>z[0])).filter(v=>v!=null); if(OIT!=="tot") vals.push(OIT==="pcr"?1:0);
  let lo=Math.min(...vals), hi=Math.max(...vals); if(hi===lo){ hi+=1; lo-=1; } const pad=(hi-lo)*0.08; lo-=pad; hi+=pad;
  const y=v=>T+ph*(1-(v-lo)/(hi-lo)); const fy=v=>OIT==="pcr"?v.toFixed(2):(OIT==="chg"&&v>0?"+":"")+fmtL(v);
  let g=`<rect x="0" y="0" width="${W}" height="${H}" fill="#05070a"/>`;
  for(let k=0;k<=4;k++){ const v=lo+(hi-lo)*k/4, yy=y(v); g+=`<line x1="${L}" x2="${W-R}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="var(--line)"/><text x="${L-5}" y="${(yy+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="end">${fy(v)}</text>`; }
  if(OIT!=="tot"){ const z=y(OIT==="pcr"?1:0); g+=`<line x1="${L}" x2="${W-R}" y1="${z.toFixed(1)}" y2="${z.toFixed(1)}" stroke="var(--dim)" stroke-dasharray="4 3"/>`; }
  const sp=D.sp.filter(v=>v!=null); if(sp.length>1){ let a=Math.min(...sp), b=Math.max(...sp); if(a===b){a-=1;b+=1;} const ys=v=>T+ph*(1-(v-a)/(b-a));
    g+=`<polyline fill="none" stroke="var(--amber)" stroke-width="1.2" stroke-dasharray="3 2" opacity=".85" points="${D.sp.map((v,i)=>v==null?"":`${x(i).toFixed(1)},${ys(v).toFixed(1)}`).join(" ")}"/>`;
    [b,(a+b)/2,a].forEach(v=>{ g+=`<text x="${W-R+5}" y="${(ys(v)+3.5).toFixed(1)}" fill="var(--amber)" font-size="10" font-family="monospace" opacity=".8">${inr(v)}</text>`; }); }
  ser.forEach(([arr,col])=>{ const pts=arr.map((v,i)=>v==null?"":`${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
    g+=`<polyline fill="none" stroke="${col}" stroke-width="2.2" stroke-linejoin="round" points="${pts}"/>`;
    const lv=arr[n-1]; if(lv!=null) g+=`<circle cx="${x(n-1).toFixed(1)}" cy="${y(lv).toFixed(1)}" r="3.5" fill="${col}"/>`; });
  const step=Math.max(1,Math.ceil(n/Math.max(3,Math.floor(pw/70))));
  D.t.forEach((t,i)=>{ if(i%step===0||i===n-1){ if(i!==n-1&&n-1-i<step*0.6) return; g+=`<text x="${x(i).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="${i===0?"start":i===n-1?"end":"middle"}">${esc(t)}</text>`; } });
  g+=`<line class="oitx" x1="0" x2="0" y1="${T}" y2="${T+ph}" stroke="var(--hi)" stroke-width="1" opacity="0"/>`;
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" data-l="${L}" data-pw="${pw}" data-n="${n}" onmousemove="oitHover(event,this)" ontouchmove="oitHover(event,this)" onmouseleave="oitHover(null,this)">${g}</svg>`; }
function oitHover(ev,svg){ const D=oiTrendData(); const w=svg.closest(".oitw"); if(!D||!w) return; const rd=w.querySelector(".oitr"), ln=svg.querySelector(".oitx");
  if(!ev){ rd.innerHTML=oitRead(D,D.n-1); ln.setAttribute("opacity","0"); return; }
  const p=ev.touches?ev.touches[0]:ev; const r=svg.getBoundingClientRect(); const L=+svg.dataset.l, pw=+svg.dataset.pw, n=+svg.dataset.n;
  const i=Math.max(0,Math.min(n-1,Math.round(((p.clientX-r.left)-L)/pw*(n-1)))); const xx=L+pw*(i/(n-1));
  ln.setAttribute("x1",xx); ln.setAttribute("x2",xx); ln.setAttribute("opacity",".5"); rd.innerHTML=oitRead(D,i); }
function oiTrendBox(id){ const D=oiTrendData();
  if(!D) return `<div class="oitw"><div class="oith"><b>OI LINE</b><span class="dim">the line starts after two chain readings (every 15 min from 09:30)</span></div></div>`;
  return `<div class="oitw" id="${id}"><div class="oith"><b>OI LINE</b>${[["chg","OI CHANGE"],["tot","TOTAL OI"],["pcr","PCR"]].map(([k,l])=>`<a class="${OIT===k?"on":""}" onclick="oitMode('${k}')">${l}</a>`).join("")}<span class="dim" style="margin-left:auto">${OIT==="pcr"?`<i style="display:inline-block;width:10px;height:2px;background:#4fc3f7;vertical-align:middle"></i> PCR = puts ÷ calls (dashed 1.0 = even)`:`<i style="display:inline-block;width:10px;height:2px;background:var(--dn);vertical-align:middle"></i> calls <i style="display:inline-block;width:10px;height:2px;background:var(--up);vertical-align:middle"></i> puts${OIT==="chg"?" (added since the first reading)":""}`} <i style="display:inline-block;width:10px;border-top:2px dashed var(--amber);vertical-align:middle"></i> price</span><div class="oitr">${oitRead(D,D.n-1)}</div></div><div class="oitg"></div></div>`; }
function oitPaint(host,id){ const h=$(host); if(!h) return; const D=oiTrendData(); let hh=0;
  if(host==="oitPx"&&wsWide()&&$("wsPx")&&$("tvbox")) hh=Math.max(150,Math.min(320,$("wsPx").clientHeight-$("tvbox").offsetHeight-92));
  const k=[OIT,D&&D.n,D&&D.ce[D.n-1],D&&D.pe[D.n-1],D&&D.sp[D.n-1],h.clientWidth,hh,id].join("|");
  if(h.dataset.k===k&&h.firstChild) return; h.dataset.k=k; h.innerHTML=oiTrendBox(id); oiTrendPut(id,hh); }
function oiTrendPut(id,hh){ const w=$(id); if(!w) return; const g=w.querySelector(".oitg"); if(g) g.innerHTML=oiTrendSVG(id,hh||0); }
let WS={k:"chg",dir:-1,sec:"",bu:"",pn:""}, OIS={k:"k",dir:-1,f:""}, WSKEY="";
try{ const w=JSON.parse(localStorage.getItem("gir_ws")||"null"); if(w) WS=Object.assign(WS,w); }catch(e){}
function wsSave(){ try{ localStorage.setItem("gir_ws",JSON.stringify(WS)); }catch(e){} }
function wsWide(){ return window.innerWidth>=900; }
const BUS={"LONG BUILD-UP":["LB","pu"],"SHORT BUILD-UP":["SB","pd"],"SHORT COVERING":["SC","pu"],"LONG UNWINDING":["LU","pd"]};
function wsSort(k){ if(WS.k===k) WS.dir=-WS.dir; else { WS.k=k; WS.dir=(k==="s")?1:-1; } wsSave(); WSKEY=""; paint(); }
function wsSec(n){ WS.sec=(WS.sec===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsBu(n){ WS.bu=(WS.bu===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsPn(n){ WS.pn=(WS.pn===n)?"":n; wsSave(); WSKEY=""; paint(); }
function oiF(f){ OIS.f=(OIS.f===f)?"":f; paint(); }
function oiChips(){ return `<div class="wss oif">${[["","ALL STRIKES"],["near","NEAR THE PRICE"],["ce","CALLS ADDED"],["pe","PUTS ADDED"],["cl","CLOSING"]].map(([k,l])=>`<a class="${OIS.f===k?"on":""}" onclick="oiF('${k}')">${l}</a>`).join("")}</div>`; }
function oiSort(k){ if(OIS.k===k) OIS.dir=-OIS.dir; else { OIS.k=k; OIS.dir=-1; } paint(); }
function oth(k,l,c){ return `<th class="s ${c}${OIS.k===k?" on":""}" onclick="oiSort('${k}')">${l}${OIS.k===k?(OIS.dir>0?" ▲":" ▼"):""}</th>`; }
function goHome(){ HOMED=false; setView("all"); if(wsWide()) homeOpen(); else { unfocus(); window.scrollTo(0,0); } }
/* patch 95: HOME = the trading screen - the share you had open last, else the day's biggest mover */
let HOMED=false; let LASTS=""; try{ LASTS=localStorage.getItem("gir_last")||""; }catch(e){}
function homeOpen(){ if(!wsWide()) return; if(FOC){ HOMED=true; return; } const T=TAPE||[];
  let s=(LASTS&&(T.some(r=>r.s===LASTS)||!T.length))?LASTS:""; if(!s&&T.length){ s=T.slice().sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0))[0].s; }
  if(s){ HOMED=true; focusOn(s); } }
function shareListHTML(){ const sx=WS.sec?SECS.find(x=>x.name===WS.sec):null; if(WS.sec&&!sx&&SECS.length) WS.sec=""; const set=sx?new Set(sx.syms||[]):null;
  let rows=(TAPE||[]).filter(r=>(!set||set.has(r.s))&&(!WS.bu||(r.bu||"").toUpperCase()===WS.bu)&&(!WS.pn||(WS.pn==="up"?(r.chg||0)>0:(r.chg||0)<0)));
  const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);
  rows=rows.slice().sort((a,b)=>{ const x=val(a), y=val(b); return (x<y?-1:x>y?1:0)*WS.dir; });
  const btn=(k,l)=>`<a class="${WS.k===k?"on":""}" onclick="wsSort('${k}')">${l}${WS.k===k?(WS.dir>0?" ▲":" ▼"):""}</a>`;
  return `<div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${SECS.map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>
    <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("v","DESK")}</div>
    <div class="wss"><a class="${WS.pn==="up"?"on":""}" onclick="wsPn('up')"><span class="${WS.pn==="up"?"":"pu"}">▲ UP</span></a><a class="${WS.pn==="dn"?"on":""}" onclick="wsPn('dn')"><span class="${WS.pn==="dn"?"":"pd"}">▼ DOWN</span></a>${Object.entries(BUS).map(([n,[sh,c]])=>`<a class="${WS.bu===n?"on":""}" onclick="wsBu('${n}')"><span class="${WS.bu===n?"":c}">${sh}</span></a>`).join("")}<span class="dim">${rows.length} shares</span></div>
    <div class="wsl">${rows.map(r=>{ const bb=BUS[(r.bu||"").toUpperCase()]; return `<div class="${r.s===FOC?"cur":""}" onclick="focusOn('${esc(r.s)}')"><b>${esc(r.s)}</b><span class="${cls(r.chg)}">${pc(r.chg)}</span><small>₹${r.px!=null?inr(r.px):"—"}${r.foi!=null?` · OI <span class="${r.foi>0?"pu":r.foi<0?"pd":""}">${r.foi>0?"+":""}${Number(r.foi).toFixed(1)}%</span>`:""}${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")||'<div class="empty">no share matches</div>'}</div>`; }
function oiProfileSVG(boxId){ const rows=oiRows().slice().sort((a,b)=>b.k-a.k); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0;
  if(!rows.length) return '<div class="empty">no strikes read yet</div>';
  const box=$(boxId); const W=Math.max(220,Math.floor((box&&box.clientWidth)||300)); const rh=Math.max(13,Math.min(20,Math.floor(440/rows.length))); const Hh=rows.length*rh+24;
  const {roof,floor}=wallsOf(rows,spot); const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=W/2, KWH=24, half=KX-KWH-2; const bh=Math.max(3,rh*0.36);
  const atm=rows.reduce((q,r)=>Math.abs(r.k-spot)<Math.abs(q.k-spot)?r:q,rows[0]);
  let g=`<rect x="0" y="0" width="${W}" height="${Hh}" fill="#05070a"/><text x="4" y="13" fill="var(--dn)" font-size="10" font-family="monospace">CALLS</text><text x="${W-4}" y="13" fill="var(--up)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
    let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
    if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
    if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
    return o; };
  rows.forEach((r,i)=>{ const yy=22+i*rh+rh/2; const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    if(isW) g+=`<line x1="0" x2="${W}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${roof&&r.k===roof.k?"var(--dn)":"var(--up)"}" stroke-dasharray="5 3" opacity=".6"/>`;
    g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--up)");
    g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="10" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; });
  if(spot){ let i=rows.findIndex(r=>r.k<=spot); if(i<0) i=rows.length; const yy=22+i*rh; g+=`<line x1="0" x2="${W}" y1="${yy}" y2="${yy}" stroke="var(--amber)" stroke-dasharray="2 3"/><text x="${W-4}" y="${yy-3}" fill="var(--amber)" font-size="9" font-family="monospace" text-anchor="end">₹${inr(spot)}</text>`; }
  return `<div class="ocsvg"><svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${g}</svg></div>`; }
function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?`tick ${FLV.age_p}s ago`:"on ticks"):(f.src||"");
  const head=`<div class="hd"><a class="hm" onclick="goHome()">⌂ HOME</a><b>${esc(f.s)}</b><span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span><span class="dim">${esc(age)}</span><a class="am" style="margin-left:auto" onclick="unfocus()">✕ CLOSE</a></div>
    <div class="m ${c}">${d?`DESK ${esc(d.label)} ${d.v>0?"+":""}${d.v}${Math.abs(d.v)===2?(d.conf?" ✓ CONFIRMED":" · awaiting the 5-min confirmation"):""}`:"no desk reading yet (the desk reads from 09:20)"}${d&&d.steps&&d.steps.length?` <span class="dim">· ${esc(d.steps.join(" · "))}</span>`:""}${d&&d.notes&&d.notes.length?` <span class="pd">· ${esc(d.notes.join(" · "))}</span>`:""}</div>
    ${d&&d.ticket?`<div class="tk">▶ ${esc(d.ticket)}${d.stop?` · stop: a close ${d.v>0?"under":"over"} ${d.stop}`:""}${d.line_k?` · line ${d.line_k}`:""}${d.size?`\n${esc(d.size)}`:""}</div>`:""}
    ${scnRibbon(f.s)}`;
  if(wsWide()) return head+`<div class="ws"><div id="wsList"></div><div id="wsPx"><div class="wsh">PRICE <span id="wsOhlc"></span></div><div class="tv" id="tvbox"></div><div id="oitPx"></div><div class="pat" id="patl"></div></div><div id="wsOi"><div class="wsh">OI BUILD-UP <span>tap a column to sort · again to reverse</span></div><div id="wsOiB"></div></div><div id="wsOc"><div class="wsh">OI CHART <span>calls · puts at every strike</span></div><div id="wsOcB"></div></div></div><div id="wsDesk"></div>`;
  return head+`<div class="tabs">${[["chart","CHART"],["oi","OI BUILD-UP"],["oc","OI CHART"],["list","SHARES"],["desk","THE DESK"]].map(([k,l])=>`<span class="${FTAB===k?"on":""}" onclick="FTAB='${k}';paint()">${l}</span>`).join("")}</div><div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; const wide=wsWide();
  if(paint.wide!==wide||!F.querySelector(wide?".ws":"#fbody")){ paint.wide=wide; F.innerHTML=focusHTML(FD); WSKEY=""; }
  else { const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); const nh=tmp.querySelector(".hd"); if(nh) hd.replaceWith(nh); }
    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","oi","oc","list","desk"][i]===FTAB)); }
  const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
  const ohlc=`O <b>${n?inr(ch.o[0]):"—"}</b> H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b> L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b> LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b> VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b> PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b>`;
  const pat=tv=>tv.txt.length?"<b>PATTERNS</b> · "+tv.txt.join(" · "):"";
  const oiH=()=>`${scnFocus()}<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiChips()}${oiTable()}<div class="legend">ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money</div>`;
  const ocH=id=>oiProfileSVG(id)+'<div class="legend"><i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts · bright = added today · dashed = closed today · the amber line = the price</div>';
  const deskH=()=>{ const d=FD.desk, ln=(d&&d.lines)||{}; return `${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${esc(x.h)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; };
  if(wide){ const lk=JSON.stringify([WS,FOC,D&&D.t,(TAPE||[]).length]); if(lk!==WSKEY){ WSKEY=lk; const L=$("wsList"); const st=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st; }
    $("wsOhlc").innerHTML=pxChips()+ohlc; const pxH=$("wsPx").clientHeight;
    if(tickOn()){ $("tvbox").innerHTML=tickBox("wsPx",Math.max(280,Math.min(720,pxH-26-128))); $("patl").innerHTML=""; $("oitPx").innerHTML=""; $("oitPx").dataset.k=""; }
    else { const tv=tradingView(ch,FLV,{box:"wsPx",h:Math.max(220,Math.min(360,pxH-26-62-170))}); $("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); }
    $("wsOiB").innerHTML=oiH(); $("wsOcB").innerHTML=ocH("wsOc"); $("wsDesk").innerHTML=deskH(); return; }
  const B=$("fbody"); if(!B) return;
  if(FTAB==="chart"){ B.innerHTML=`<div class="sub"><span>${pxChips()}${ohlc}</span></div><div class="tv" id="tvbox"></div><div id="oitPx"></div><div class="pat" id="patl"></div><div class="legend">5-min candles · <i style="background:var(--amber)"></i>VWAP · the opening-range box · the roof / floor from the OI · ▲▼ the patterns · 🧩 an OI scenario fired</div>`;
    if(tickOn()){ $("tvbox").innerHTML=tickBox("tvbox",420); $("patl").innerHTML=""; const lg=B.querySelector(".legend"); if(lg) lg.innerHTML='price tick by tick (one point a second) · under it, on the same time axis: the OI the calls / puts added in the window · ▪ dashed lines = an alert on this share (red = ACT, amber = MOVING, grey = watch)'; }
    else { const tv=tradingView(ch,FLV,{}); $("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); } }
  else if(FTAB==="oi") B.innerHTML=oiH();
  else if(FTAB==="oc"){ B.innerHTML='<div id="ocbox"></div>'; $("ocbox").innerHTML='<div id="oitOc"></div>'+ocH("ocbox"); oitPaint("oitOc","oitB"); }
  else if(FTAB==="list"){ const st=B.scrollTop; B.innerHTML=shareListHTML(); }
  else B.innerHTML=deskH(); }
function chainSVG(f){ const S=f.strikes||[]; if(!S.length||!f.spot) return ""; const W=640,H=120,L=50,R=10,T=8,B=20; const n=S.length; const bw=(W-L-R)/n; const mx=Math.max(...S.map(x=>Math.max(x.ce,x.pe)),1);
  const y=v=>T+(H-T-B)*(1-v/mx); const bars=S.map((x,i)=>{ const x0=L+i*bw; const w=Math.max(2,bw*0.42); const isR=f.roof&&f.roof.k===x.k, isF=f.floor&&f.floor.k===x.k;
    return `<rect x="${(x0+bw*0.06).toFixed(1)}" y="${y(x.pe).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.pe)).toFixed(1)}" fill="var(--up)" opacity="${isF?1:0.5}"/><rect x="${(x0+bw*0.52).toFixed(1)}" y="${y(x.ce).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.ce)).toFixed(1)}" fill="var(--dn)" opacity="${isR?1:0.5}"/>${(i%Math.ceil(n/8)===0)?`<text x="${(x0+bw/2).toFixed(1)}" y="${H-6}" fill="var(--dim)" font-size="10" text-anchor="middle" font-family="monospace">${x.k}</text>`:""}`; }).join("");
  const ks=S.map(x=>x.k); const lo=Math.min(...ks), hi=Math.max(...ks); const sx=L+((f.spot-lo)/((hi-lo)||1))*(W-L-R-bw)+bw/2;
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" style="width:100%;height:120px;display:block;background:#000"><line x1="${L}" x2="${W-R}" y1="${H-B}" y2="${H-B}" stroke="var(--line2)"/>${bars}<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="4 3"/></svg>`; }
async function getJ(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pullLive(){ if(!FOC) return; const since=(TK.sym===FOC&&TK.pts.length)?TK.pts[TK.pts.length-1][0]:0;
  const v=await getJ("live?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&since="+since); if(v&&v.sym===FOC){ FLV=v; tkFeed(v); paint(); } }
async function pullChart(){ if(!FOC) return; const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.c){ FCH=v; paint(); } }
async function pullOI(){ if(!FOC) return; const v=await getJ("oi?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FOI=v; paint(); } }
function stopLive(){ for(const k in FT){ if(FT[k]) clearInterval(FT[k]); FT[k]=null; } }
async function focusOn(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return; LASTS=sym; try{ localStorage.setItem("gir_last",sym); }catch(e){} const fresh=sym!==FOC; FOC=sym; $("q").value=sym; $("unf").style.display="inline-block";
  if(fresh){ FCH=null; FLV=null; FOI=null; TKH=null; stopLive(); }
  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;
  const F=$("focus"); F.hidden=false; if(window.innerWidth<900) F.classList.add("sheet"); else { F.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
  if(!FD||(!(FD.strikes||[]).length&&FD.px==null&&!FD.desk)){ F.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">not an F&amp;O share on the desk</div>`; return; }
  if(fresh||!$("fbody")) F.innerHTML=focusHTML(FD); paint();
  if(fresh){ pullChart(); pullLive(); pullOI(); FT.live=setInterval(pullLive,1000); FT.chart=setInterval(pullChart,10000); FT.oi=setInterval(pullOI,30000); }
  if(D){ $("nowl").innerHTML=nowHTML((D.now||[]).filter(r=>r.s===FOC)); $("hnow").textContent=`${FOC} only · tap ✕ ALL for every share`; const nn=(D.news||[]).filter(x=>x.s===FOC); $("newsl").innerHTML=newsHTML(nn); } }
function unfocus(){ FOC=""; FD=null; FCH=null; FLV=null; FOI=null; stopLive(); const F=$("focus"); F.hidden=true; F.classList.remove("sheet","ws-on"); F.innerHTML=""; $("q").value=""; $("unf").style.display="none"; if(D){ $("nowl").innerHTML=nowHTML(D.now||[]); $("hnow").textContent="moving right now · newest first · every line went to Telegram the same second"; $("newsl").innerHTML=newsHTML(D.news||[]); } }
$("go").onclick=()=>focusOn($("q").value); $("q").addEventListener("keydown",e=>{ if(e.key==="Enter") focusOn($("q").value); }); $("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };
/* ---------- render: the same code for the poll and the push ---------- */
function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now(); drawAlerts();
  $("idx").innerHTML=idxHTML(D); $("nowl").innerHTML=nowHTML(FOC?(D.now||[]).filter(r=>r.s===FOC):(D.now||[])); SECS=D.sectors||[]; drawSecs();
  { const S_=D.scn||{}; const ck=JSON.stringify([(S_.today||[]).length,S_.scores,(S_.cat||[]).length]); if(ck!==render.ck){ render.ck=ck; $("scnl").innerHTML=scnHTML(D.scn); $("scnh").textContent=`how the money is building up · ${(S_.today||[]).length} today`; } }
  if(FOC&&(!render.fat||Date.now()-render.fat>30000)){ render.fat=Date.now(); getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)).then(v=>{ if(v&&FOC===v.s){ FD=v; paint(); } }); }
  const sk=SECS.map(s=>s.name).join("|"); if(sk!==render.sk){ render.sk=sk; $("secsel").innerHTML='<option value="">ALL SECTORS</option>'+SECS.map(s=>`<option value="${esc(s.name)}">${esc(s.name).toUpperCase()}</option>`).join(""); $("secsel").value=SEL; }
  const tk=JSON.stringify((D.tape||[]).map(r=>[r.s,r.px,r.v,r.oi])); if(tk!==render.tk){ render.tk=tk; TAPE=D.tape||[]; drawTape(); }
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); }
  if(VIEW==="all"&&!FOC&&!HOMED&&wsWide()&&(TAPE||[]).length) homeOpen();
  first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
/* ---------- patch 93: THE ALERT BAR - only what is clear-cut ---------- */
/* ACT  = a BUY by the house rule (measured 55%+ on 50+ cases, agents agreeing) or your own money (💼 your trade, 🛑 book it)
   MOVE = something IS happening, not a trade by itself: 🚨 SUDDEN (EXTREME, 5-min confirmed) · ⚡ NEWS SHOCK chain ·
          🚀 RUNNING at 3%+ · ⚡ SPEED with the day already 2%+ · a BUY held back in the opening 15 minutes
   everything else (first moves, readings, movers, scorecards) stays in 1 NOW - no bar, no sound */
function alertTier(r){ const H=r.head||"", L=r.lines||[], T=[H].concat(L).join("\n"), k=r.kind||H.split(" ")[0]||"";
  if(/NOT SENT/.test(T)&&!/BUY/.test(T)) return "watch";
  if(k==="💼"||k==="🛑") return "act";
  const opening=/OPENING/.test(T);
  const m=T.match(/measured:\s*(\d+)%\s*right of\s*(\d+)/); const meas=m&&+m[1]>=55&&+m[2]>=50;
  const buyLine=L.some(l=>/^(▶\s*)?BUY\b/.test(l.trim()))||/—\s*BUY\b/.test(H);
  const disagree=/disagrees/.test(T);
  if(!opening&&!disagree&&!/\bWATCH\b/.test(T)&&(buyLine||(k==="🚨"&&meas))) return "act";
  if(k==="🚨"||/NEWS SHOCK/.test(H)||(opening&&(buyLine||meas))) return "move";
  if(/RUNNING/.test(H)){ const c=T.match(/crossed\s*[+-](\d+)%/); if(c&&+c[1]>=3) return "move"; }
  if(/SPEED/.test(H)){ const d=H.match(/day\s*([+-]?\d+(\.\d+)?)%/); if(d&&Math.abs(+d[1])>=2) return "move"; }
  return "watch"; }
function alertTicket(r){ const L=r.lines||[]; const tk=L.find(l=>/^▶/.test(l.trim()))||L.find(l=>/^(BUY|WATCH)\b/.test(l.trim()))||L[0]||"";
  return tk.replace(/^▶\s*/,"").replace(/\s*·\s*size:.*$/,"").slice(0,90); }
let ASEEN=null, AFRESH={}, ASND=true, AC=null; try{ ASND=localStorage.getItem("gir_snd")!=="0"; }catch(e){}
function acUnlock(){ try{ AC=AC||new (window.AudioContext||window.webkitAudioContext)(); if(AC.state==="suspended") AC.resume(); }catch(e){} }
document.addEventListener("pointerdown",acUnlock,{once:true}); document.addEventListener("keydown",acUnlock,{once:true});
function beep(n,f){ if(!ASND) return; try{ acUnlock(); for(let i=0;i<n;i++){ const o=AC.createOscillator(), g=AC.createGain(); o.type="square"; o.frequency.value=f; o.connect(g); g.connect(AC.destination);
  const t=AC.currentTime+i*0.24; g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.25,t+0.02); g.gain.exponentialRampToValueAtTime(0.0001,t+0.2); o.start(t); o.stop(t+0.22); } }catch(e){} }
function sndToggle(){ ASND=!ASND; try{ localStorage.setItem("gir_snd",ASND?"1":"0"); }catch(e){} if(ASND){ acUnlock(); beep(1,880); } drawAlerts(true); }
let ATITLE=document.title; function titleFlag(on){ document.title=on?"🔴 ALERT · "+ATITLE:ATITLE; }
document.addEventListener("visibilitychange",()=>{ if(!document.hidden) titleFlag(false); });
function drawAlerts(force){ const B=$("abar"); if(!B||!D) return; const rows=(D.now||[]);
  const per={}; const keyOf=r=>r.t+"|"+r.head;
  rows.forEach(r=>{ const tr=alertTier(r); if(tr==="watch"||!r.s) return; const o=per[r.s]; if(!o||(o.tier!=="act"&&tr==="act")||(o.tier===tr&&r.t>o.r.t)) per[r.s]={r,tier:tr,n:(o?o.n:0)+1}; else o.n++; });
  const list=Object.values(per).sort((a,b)=>(a.tier===b.tier?0:a.tier==="act"?-1:1)||(b.r.t>a.r.t?1:b.r.t<a.r.t?-1:0));
  const nW=rows.filter(r=>alertTier(r)==="watch").length;
  if(ASEEN===null){ ASEEN=new Set(rows.map(keyOf)); }
  else { let ring=0; rows.forEach(r=>{ const k=keyOf(r); if(ASEEN.has(k)) return; ASEEN.add(k); const tr=alertTier(r); if(tr==="watch") return; AFRESH[r.s]=Date.now(); ring=Math.max(ring,tr==="act"?2:1); });
    if(ring){ beep(ring===2?3:1,ring===2?988:660); try{ if(navigator.vibrate) navigator.vibrate(ring===2?[200,100,200,100,200]:[150]); }catch(e){} if(document.hidden) titleFlag(true); } }
  const ck=JSON.stringify([list.map(x=>[x.r.s,x.r.t,x.tier,x.n,!!AFRESH[x.r.s]&&Date.now()-AFRESH[x.r.s]<9000]),nW,ASND,FOC]); if(!force&&ck===drawAlerts.ck) return; drawAlerts.ck=ck;
  const hasA=list.some(x=>x.tier==="act");
  B.className=hasA?"has-act":list.length?"has-move":"";
  const chip=x=>{ const r=x.r, up=r.side==="CE", dn=r.side==="PE"; const fr=AFRESH[r.s]&&Date.now()-AFRESH[r.s]<9000;
    return `<div class="ch ${x.tier}${fr?" fresh":""}" title="${esc([r.head].concat(r.lines||[]).join("\n"))}" onclick="focusOn('${esc(r.s)}')"><span class="tg">${x.tier==="act"?"ACT":"MOVING"}</span><span class="tm">${esc(r.t)}</span><b>${esc(r.s)}</b><span class="${up?"pu":dn?"pd":"dim"}">${up?"▲ UP → CE":dn?"▼ DOWN → PE":""}</span><span class="tk">${esc(r.kind||"")} ${esc(alertTicket(r))}</span>${x.n>1?`<span class="dim">×${x.n}</span>`:""}</div>`; };
  B.innerHTML=`<div class="al">ALERTS</div><div class="ac">${list.length?list.slice(0,12).map(chip).join(""):`<span class="ae">nothing clear-cut yet today — a BUY by the measured rule, your own trade, or a move that is really happening (SUDDEN · SHOCK · RUNNING 3%+) shows here with a sound</span>`}</div><div class="ar"><a class="${ASND?"on":""}" onclick="sndToggle()">${ASND?"🔔 SOUND ON":"🔕 SOUND OFF"}</a><a onclick="setView('now')">WATCH ${nW} →</a></div>`;
  if(FOC&&wsWide()) document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
setInterval(()=>{ if(Object.values(AFRESH).some(t=>Date.now()-t<10000)||drawAlerts.ck) drawAlerts(); },3000);

/* ---------- patch 93: THE TICK CHART - the price tick by tick, the calls' / puts' OI under it, one time axis ---------- */
let PXM="tick", TKW=900, TK={sym:"",pts:[],tk0:null,mv:[]}, TKH=null;
try{ PXM=localStorage.getItem("gir_pxm")||"tick"; TKW=+(localStorage.getItem("gir_tkw")||900); }catch(e){}
function pxMode(m){ PXM=m; try{ localStorage.setItem("gir_pxm",m); }catch(e){} paint(); }
function tkWin(w){ TKW=w; try{ localStorage.setItem("gir_tkw",String(w)); }catch(e){} paint(); }
function tickOn(){ return PXM==="tick"&&TK.sym===FOC&&TK.pts.length>=5; }
function pxChips(){ return `<span class="pxm"><a class="${PXM==="tick"?"on":""}" onclick="pxMode('tick')">TICK</a><a class="${PXM!=="tick"?"on":""}" onclick="pxMode('5m')" title="PRICE · 5 MIN candles">5 MIN</a></span>`; }
function tkFeed(v){ if(!v||!Array.isArray(v.tk)) return; if(TK.sym!==v.sym) TK={sym:v.sym,pts:[],tk0:null,mv:[]};
  const last=TK.pts.length?TK.pts[TK.pts.length-1][0]:0; for(const p of v.tk){ if(p[0]>last) TK.pts.push(p); } if(TK.pts.length>30000) TK.pts.splice(0,TK.pts.length-30000);
  TK.tk0=v.tk0; TK.mv=v.mv||[]; }
const hms=t=>{ const d=new Date((t+19800)*1000); return d.toISOString().slice(11,19); };
function tkView(){ const P=TK.pts; if(!P.length) return []; const t1=P[P.length-1][0]; const t0=TKW?t1-TKW:P[0][0]; let i=0; while(i<P.length&&P[i][0]<t0) i++; return P.slice(Math.max(0,i-1)); }
function tkRead(V,j){ const p=V[j], b=V[0]; if(!p) return ""; const dc=p[2]-b[2], dp=p[3]-b[3]; const sg=v=>(v>0?"+":"")+fmtL(v);
  const ch=FLV&&FLV.pc?(p[1]/FLV.pc-1)*100:null;
  return `<b class="am">${hms(p[0])}</b> · price <b class="${cls(ch)}">₹${inr(p[1])}</b>${ch!=null?` <span class="${cls(ch)}">${pc(ch)}</span>`:""} · in this window: <span style="color:var(--dn)">calls OI <b>${sg(dc)}</b></span> · <span style="color:var(--up)">puts OI <b>${sg(dp)}</b></span>`; }
function tkMarks(t0,t1){ if(!D) return []; const P=TK.pts; if(!P.length) return []; const day0=Math.floor((P[P.length-1][0]+19800)/86400)*86400-19800;
  return (D.now||[]).filter(r=>r.s===FOC).map(r=>{ const m=(r.t||"").match(/^(\d\d):(\d\d)/); if(!m) return null; const t=day0+ +m[1]*3600+ +m[2]*60; return (t>=t0&&t<=t1)?{t,tier:alertTier(r),k:r.kind||""}:null; }).filter(Boolean); }
function tickSVG(boxId,hh){ const V=tkView(); if(V.length<2) return ""; const box=$(boxId); const W=Math.max(280,Math.floor((box&&box.clientWidth)||600)); const H=hh||380;
  const phone=W<600; const LW=Math.round(W*(phone?0.34:0.28)); const L=LW+6,R=64,T=26,GAP=22,B=20; const ph=Math.round((H-T-GAP-B)*0.62), oh=H-T-GAP-B-ph; const y0o=T+ph+GAP; const pw=W-L-R;
  const t0=TKW?V[V.length-1][0]-TKW:V[0][0], t1=V[V.length-1][0]; const span=Math.max(1,t1-t0); const x=t=>L+pw*Math.max(0,(t-t0))/span;
  const pxs=V.map(p=>p[1]); let lo=Math.min(...pxs), hi=Math.max(...pxs); const rf=FD&&FD.roof&&FD.roof.k, fl=FD&&FD.floor&&FD.floor.k;
  const rows=oiRows(); const ks=rows.map(r=>r.k).sort((a,b)=>a-b); const lp_=pxs[pxs.length-1];
  const kb=ks.filter(k=>k<=lo).pop(), ka=ks.find(k=>k>=hi); if(kb!=null) lo=kb; if(ka!=null) hi=ka;          // the nearest strike under and over the price
  [rf,fl].forEach(k=>{ if(k&&Math.abs(k/lp_-1)<=0.02){ lo=Math.min(lo,k); hi=Math.max(hi,k); } });          // the roof / floor when within 2%
  if(hi-lo<hi*0.002){ const m=(hi+lo)/2; lo=m-m*0.001; hi=m+m*0.001; } const pd=(hi-lo)*0.06; lo-=pd; hi+=pd; const yp=v=>T+ph*(1-(v-lo)/(hi-lo));
  const b=V[0]; const dc=V.map(p=>p[2]-b[2]), dp=V.map(p=>p[3]-b[3]); let olo=Math.min(0,...dc,...dp), ohi=Math.max(0,...dc,...dp); if(ohi===olo){ ohi+=1; olo-=1; } const opd=(ohi-olo)*0.08; olo-=opd; ohi+=opd;
  const yo=v=>y0o+oh*(1-(v-olo)/(ohi-olo));
  let g=`<rect x="0" y="0" width="${W}" height="${H}" fill="#05070a"/>`;
  { const vis=rows.filter(r=>r.k>=lo&&r.k<=hi).sort((a,b)=>b.k-a.k);                                       // the OI at each strike, on this price scale
    if(vis.length){ const gp=vis.length>1?Math.min(...vis.slice(1).map((r,i)=>Math.abs(yp(vis[i].k)-yp(r.k)))):24; const bh=Math.max(2,Math.min(9,gp*0.38));
      const mx=Math.max(...vis.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=LW/2, KWH=phone?19:23, half=KX-KWH-2;
      const atm=vis.reduce((q,r)=>Math.abs(r.k-lp_)<Math.abs(q.k-lp_)?r:q,vis[0]);
      g+=`<text x="3" y="${T-3}" fill="var(--dn)" font-size="9" font-family="monospace">CALLS</text><text x="${LW-3}" y="${T-3}" fill="var(--up)" font-size="9" font-family="monospace" text-anchor="end">PUTS</text><line x1="${LW+2}" x2="${LW+2}" y1="${T}" y2="${T+ph}" stroke="var(--line2)"/>`;
      const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
        let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
        if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
        if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
        return o; };
      vis.forEach(r=>{ const yy=yp(r.k); const isW=r.k===rf||r.k===fl;
        g+=`<line x1="${LW+2}" x2="${W-R}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${isW?(r.k===rf?"var(--dn)":"var(--up)"):"var(--line)"}" stroke-dasharray="${isW?"6 3":"1 4"}" opacity="${isW?.8:.7}"/>`;
        g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--up)");
        g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="${phone?9:10}" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; }); } }
  for(let k=0;k<=4;k++){ const v=lo+(hi-lo)*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${yp(v).toFixed(1)}" y2="${yp(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-R+5}" y="${(yp(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(+v.toFixed(2))}</text>`; }
  for(let k=0;k<=2;k++){ const v=olo+(ohi-olo)*k/2; g+=`<line x1="${L}" x2="${W-R}" y1="${yo(v).toFixed(1)}" y2="${yo(v).toFixed(1)}" stroke="var(--line)"/><text x="${L-5}" y="${(yo(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="end">${(v>0?"+":"")+fmtL(Math.round(v))}</text>`; }
  g+=`<line x1="${L}" x2="${W-R}" y1="${yo(0).toFixed(1)}" y2="${yo(0).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="4 3"/>`;
  g+=`<text x="${L+4}" y="11" fill="var(--amber)" font-size="10" font-family="monospace">PRICE · TICK BY TICK</text><text x="${L}" y="${y0o-6}" fill="var(--dim)" font-size="10" font-family="monospace">OI ADDED: <tspan fill="var(--dn)">CALLS</tspan> · <tspan fill="var(--up)">PUTS</tspan></text>`;
  [[rf,"var(--dn)","ROOF"],[fl,"var(--up)","FLOOR"]].forEach(([k,c,n])=>{ if(k&&k>=lo&&k<=hi) g+=`<text x="${L+4}" y="${(yp(k)-3).toFixed(1)}" fill="${c}" font-size="10" font-family="monospace">${n} ${k}</text>`; });
  if(FLV&&FLV.pc&&FLV.pc>=lo&&FLV.pc<=hi) g+=`<line x1="${L}" x2="${W-R}" y1="${yp(FLV.pc).toFixed(1)}" y2="${yp(FLV.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="2 4"/><text x="${W-R-4}" y="${(yp(FLV.pc)-3).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="end">prev close</text>`;
  const cols=Math.max(50,Math.floor(pw)); const bk=new Map(); V.forEach((p,i)=>{ const c=Math.round((x(p[0])-L)/pw*cols); const o=bk.get(c); if(!o) bk.set(c,{i0:i,i1:i,lo:p[1],hi:p[1],il:i,ih:i}); else { o.i1=i; if(p[1]<o.lo){o.lo=p[1];o.il=i;} if(p[1]>o.hi){o.hi=p[1];o.ih=i;} } });
  const pts=[]; for(const [c,o] of bk){ const xx=x(V[o.i1][0]); const seq=[o.i0, ...(o.il<o.ih?[o.il,o.ih]:[o.ih,o.il]), o.i1]; seq.forEach(i=>pts.push(`${xx.toFixed(1)},${yp(V[i][1]).toFixed(1)}`)); }
  const up=V[V.length-1][1]>=V[0][1];
  g+=`<polyline fill="none" stroke="${up?"var(--up)":"var(--dn)"}" stroke-width="1.6" stroke-linejoin="round" points="${pts.join(" ")}"/>`;
  const ol=(arr,col)=>{ const q=[]; let lc=-1; arr.forEach((v,i)=>{ const c=Math.round((x(V[i][0])-L)/pw*cols); if(c!==lc||i===arr.length-1){ q.push(`${x(V[i][0]).toFixed(1)},${yo(v).toFixed(1)}`); lc=c; } }); return `<polyline fill="none" stroke="${col}" stroke-width="2" stroke-linejoin="round" points="${q.join(" ")}"/>`; };
  g+=ol(dc,"var(--dn)")+ol(dp,"var(--up)");
  const lp=V[V.length-1]; g+=`<rect x="${W-R+1}" y="${(yp(lp[1])-8).toFixed(1)}" width="${R-2}" height="16" fill="${up?"var(--up)":"var(--dn)"}"/><text x="${W-R+4}" y="${(yp(lp[1])+4).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(lp[1])}</text>`;
  tkMarks(t0,t1).forEach(mk=>{ const xx=x(mk.t), c=mk.tier==="act"?"var(--dn)":mk.tier==="move"?"var(--amber)":"var(--dim)"; g+=`<line x1="${xx.toFixed(1)}" x2="${xx.toFixed(1)}" y1="${T}" y2="${y0o+oh}" stroke="${c}" stroke-dasharray="3 3" opacity="${mk.tier==="watch"?.45:.9}"/><text x="${xx.toFixed(1)}" y="${T+10}" font-size="11" text-anchor="middle">${esc(mk.k)}</text>`; });
  const nl=Math.max(2,Math.floor(pw/90)); for(let k=0;k<=nl;k++){ const t=t0+span*k/nl; g+=`<text x="${x(t).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="${k===0?"start":k===nl?"end":"middle"}">${span<=1200?hms(t):hms(t).slice(0,5)}</text>`; }
  let hx=-10; if(TKH!=null){ let j=V.findIndex(p=>p[0]>=TKH); if(j<0) j=V.length-1; hx=x(V[j][0]); }
  g+=`<line class="tkx" x1="${hx}" x2="${hx}" y1="${T}" y2="${y0o+oh}" stroke="var(--hi)" opacity="${TKH!=null?.5:0}"/>`;
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" data-l="${L}" data-pw="${pw}" data-t0="${t0}" data-sp="${span}" onmousemove="tkHover(event,this)" ontouchmove="tkHover(event,this)" onmouseleave="tkHover(null,this)">${g}</svg>`; }
function tkHover(ev,svg){ const w=svg.closest(".tkw"); const V=tkView(); if(!w||!V.length) return; const rd=w.querySelector(".tkr"), ln=svg.querySelector(".tkx");
  if(!ev){ TKH=null; ln.setAttribute("opacity","0"); rd.innerHTML=tkRead(V,V.length-1); return; }
  const p=ev.touches?ev.touches[0]:ev; const r=svg.getBoundingClientRect(); const L=+svg.dataset.l, pw=+svg.dataset.pw, t0=+svg.dataset.t0, sp=+svg.dataset.sp;
  const t=t0+((p.clientX-r.left)-L)/pw*sp; let j=V.findIndex(q=>q[0]>=t); if(j<0) j=V.length-1; TKH=V[j][0]; const xx=L+pw*Math.max(0,V[j][0]-t0)/sp;
  ln.setAttribute("x1",xx); ln.setAttribute("x2",xx); ln.setAttribute("opacity",".5"); rd.innerHTML=tkRead(V,j); }
function tickBox(boxId,hh){ const V=tkView(); const n=TK.pts.length;
  const mv=(TK.mv||[]).length?`<div class="tkm">OI moving now (last ${Math.max(1,Math.round((TK.mv[0].secs||300)/60))} min): ${TK.mv.slice(0,5).map(m=>`<b style="color:${m.side==="CE"?"var(--dn)":"var(--up)"}">${esc(m.k)} ${m.side} ${(m.d>0?"+":"")+fmtL(m.d)}</b>`).join(" · ")} <span class="dim">(+ = added, − = closed)</span></div>`:"";
  const head=`<div class="tkh">${[[300,"5 MIN"],[900,"15 MIN"],[3600,"1 HOUR"],[0,"ALL"]].map(([w,l])=>`<span class="pxm" style="margin:0"><a class="${TKW===w?"on":""}" onclick="tkWin(${w})">${l}</a></span>`).join("")}<span class="dim">ticks since ${TK.pts.length?hms(TK.pts[0][0]):"—"} (when this share was opened) · ${n.toLocaleString("en-IN")} points</span><div class="tkr">${tkRead(V,TKH!=null?Math.max(0,V.findIndex(p=>p[0]>=TKH)):V.length-1)}</div>${mv}</div>`;
  return `<div class="tkw">${head}${tickSVG(boxId,hh)}</div>`; }
/* ---------- patch 89: the function keys and the panels ---------- */
let VIEW="all"; try{ VIEW=localStorage.getItem("gir_fk")||"all"; }catch(e){}
let PN=null, PNT=null;
const rsx=v=>v==null?"—":(v<0?"−₹":"₹")+Math.abs(Math.round(v)).toLocaleString("en-IN");
function setView(v){ VIEW=v; try{ localStorage.setItem("gir_fk",v); }catch(e){}
  if(v!=="all"&&FOC&&wsWide()) unfocus();                       // a function key shows its panel; HOME brings the trading screen back
  document.body.classList.toggle("one",v!=="all");
  document.querySelectorAll("#fkeys a").forEach(a=>a.classList.toggle("on",a.dataset.v===v));
  document.querySelectorAll("#grid>section").forEach(x=>x.classList.toggle("on",x.id===v));
  if(["picks","tom","myfo","desk"].includes(v)){ loadPanels(); if(!PNT) PNT=setInterval(()=>{ if(["picks","tom","myfo","desk"].includes(VIEW)) loadPanels(); },10000); }
  window.scrollTo(0,0); }
async function loadPanels(){ try{ const r=await fetch("panels?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ PN=await r.json(); drawPanels(); } }catch(e){} }
function pkRow(r){ const ce=r.act==="BUY CE"; return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)} <span class="${cls(r.chg)}">${pc(r.chg)}</span></small></div><div><div class="do ${ce?"up":"dn"}">BUY ${r.k} ${esc(r.kind||"")} at ₹${r.p}${r.cost?` · 1 lot ₹${inr(r.cost)}`:""}</div><div class="why">${esc(r.title||"")}${r.vd?` · chain ${esc(r.vd)}`:""} · target ₹${r.tgt} (≈ +${r.gain}%) · stop ${ce?"below":"above"} ₹${r.stop??"—"} · room ${r.room}%${r.late?' · <span class="am">late — moved a lot already</span>':""}</div></div></div>`; }
function drawPanels(){ const P=PN||{};
  // PICKS
  const B=P.box_picks||{}; const M=P.my_pos||[];
  $("pkh").textContent=B.n_read?`${B.n_buy} of ${B.n_read} F&O shares say BUY · read ${B.t||""}`:(P.closed?"market closed · fills from 09:20 on the next session":"waiting for the first read");
  let h=""; if(M.length) h+=`<div class="hd2">💼 YOUR OPEN TRADES — checked against the box every sweep</div>`+M.map(m=>{ const ce=m.kind==="CE"; return `<div class="r" onclick="focusOn('${esc(m.s)}')"><div class="sy"><b>${esc(m.s)}</b><small class="${ce?"pu":"pd"}">${m.k} ${esc(m.kind)}</small></div><div><div class="do ${m.pnl>0?"up":m.pnl<0?"dn":""}">bought ₹${m.buy} → now ${m.ltp!=null?"₹"+m.ltp:"not read"}${m.pnl!=null?` (${m.pnl>0?"+":""}${m.pnl}%)`:""}</div><div class="why">${m.note?esc(m.note):`share ₹${m.spot} · roof ₹${m.roof??"—"} · floor ₹${m.floor??"—"} · box ${esc(m.box||"")}`}</div>${(m.flags||[]).map(f=>`<div class="am">⚠ ${esc(f)}</div>`).join("")}</div></div>`; }).join("");
  h+=`<div class="hd2">▲ BUY CE — share going up</div>`+((B.ce||[]).map(pkRow).join("")||'<div class="empty">none right now</div>');
  h+=`<div class="hd2">▼ BUY PE — share going down</div>`+((B.pe||[]).map(pkRow).join("")||'<div class="empty">none right now</div>');
  if((B.edge||[]).length) h+=`<div class="hd2">ON A WALL — the next break</div>`+B.edge.map(r=>`<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)}</small></div><div><div class="do ${r.side==="CE"?"up":"dn"}">${r.side==="CE"?"testing the roof":"testing the floor"} ₹${r.k} · ${r.away_pct}% away</div><div class="why">${esc(r.do||"")} · target ${esc(r.target||"")}</div></div></div>`).join("");
  $("pkl").innerHTML=h;
  // TOMORROW
  const T=P.tomorrow||{}; const tr=(T.ce||[]).concat(T.pe||[]);
  $("tmh").textContent=T.t?`list at ${T.t}${T.frozen?" · frozen":""} · buy 14:30 · sell by 09:30 the day after`:"the list forms from 14:00";
  $("tml").innerHTML=tr.length?tr.map(r=>{ const up=r.side==="CE"; return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)} <span class="${cls(r.chg)}">${pc(r.chg)}</span></small></div><div><div class="do ${up?"up":"dn"}">${r.strong?"⭐ STRONG · ":""}${up?"UP → CE":"DOWN → PE"} · ${r.k??""} ${esc(r.side)} ₹${r.p??"—"}${r.cost?` · 1 lot ₹${inr(r.cost)}`:""} · stop ₹${r.stop_p??"—"}</div><div class="why">${esc((r.why||[]).join(" · "))}${r.vd?` · chain ${esc(r.vd)}`:""}${r.late?' · <span class="am">moved a lot already — half size</span>':""}</div></div></div>`; }).join(""):'<div class="empty">no TOMORROW list yet — it forms from 14:00 and is final at 14:30</div>';
  // MY F&O
  const L=P.ledger||{}, S=L.sum||{}; const rows=L.rows||[]; const op=rows.filter(r=>r.net==null), cl=rows.filter(r=>r.net!=null).slice(0,15);
  $("mfl").innerHTML=`<div class="kp"><div><small>TODAY</small><b class="${cls(S.today)}">${rsx(S.today)}</b></div><div><small>SINCE START</small><b class="${cls(S.total)}">${rsx(S.total)}</b></div><div><small>TRADES · WON</small><b>${S.n||0} · ${S.wins||0}</b></div><div><small>OPEN · COST</small><b>${S.open||0} · ${rsx(S.open_cost)}</b></div></div>
    <form onsubmit="return mfAdd(event)"><input id="mf_s" placeholder="SHARE" style="width:110px;text-transform:uppercase"><select id="mf_k"><option>CE</option><option>PE</option></select><input id="mf_k2" placeholder="strike" inputmode="decimal"><input id="mf_q" placeholder="qty" inputmode="numeric"><input id="mf_b" placeholder="buy ₹" inputmode="decimal"><button>+ ADD TRADE</button></form><div class="msg" id="mf_m"></div>
    ${op.length?`<div class="hd2">OPEN</div>`+op.map(r=>`<div class="r"><div class="sy"><b onclick="focusOn('${esc(r.sym)}')">${esc(r.sym)}</b><small>${r.strike} ${esc(r.kind)} · ${r.qty} qty</small></div><div><div class="do">bought ₹${r.buy} · cost ${rsx(r.cost)}</div><div class="why"><input id="mfx_${r.id}" placeholder="sell ₹" inputmode="decimal" style="width:80px"> <button onclick="mfExit(${r.id})">EXIT</button></div></div></div>`).join(""):""}
    ${cl.length?`<div class="hd2">CLOSED</div>`+cl.map(r=>`<div class="r"><div class="sy"><b>${esc(r.sym)}</b><small>${esc(r.day)} · ${r.strike} ${esc(r.kind)}</small></div><div><div class="do ${r.net>0?"up":"dn"}">₹${r.buy} → ₹${r.sell} · NET ${rsx(r.net)}</div><div class="why">charges ${rsx(r.charges)} · gross ${rsx(r.gross)}</div></div></div>`).join(""):'<div class="empty">no closed trade yet</div>'}`;
  // DESK P&L
  const p=P.pnl||{}, H=P.hist||[], HS=P.hist_sum||{}; const mx=Math.max(...H.map(x=>Math.abs(x.net)),1);
  $("dkl").innerHTML=`<div class="kp"><div><small>TODAY (PAPER)</small><b class="${cls(p.total)}">${P.closed?"—":rsx(p.total)}</b></div><div><small>SINCE START</small><b class="${cls(HS.cum)}">${rsx(HS.cum)}</b></div><div><small>DAYS · GREEN</small><b>${HS.days||0} · ${HS.green||0}</b></div><div><small>TRADES</small><b>${HS.n||0}</b></div></div>
    ${H.length?`<div class="bars">${H.map(x=>`<i title="${esc(x.d)} ${rsx(x.net)}" style="height:${Math.max(2,Math.abs(x.net)/mx*60)}px;background:${x.net>=0?"var(--up)":"var(--dn)"};opacity:.8"></i>`).join("")}</div><div class="why" style="padding:4px 8px">the last ${H.length} days, one bar a day · green = a winning day</div>`:""}
    ${H.slice().reverse().slice(0,12).map(x=>`<div class="r"><div class="sy"><b>${esc(x.d.slice(5))}</b><small>${x.n} trades · ${x.w} won</small></div><div><div class="do ${x.net>=0?"up":"dn"}">${rsx(x.net)}</div><div class="why">running ${rsx(x.cum)}</div></div></div>`).join("")}`; }
async function mfAdd(ev){ ev.preventDefault(); const m=$("mf_m"); m.textContent="saving…";
  const d=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const day=d.toISOString().slice(0,10);
  try{ const r=await fetch("ledger?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({op:"add",sym:$("mf_s").value.toUpperCase().trim(),kind:$("mf_k").value,strike:$("mf_k2").value,qty:$("mf_q").value,buy:$("mf_b").value,sell:"",expiry:"",day:day,note:""})});
    if(!r.ok) throw new Error(await r.text()); m.textContent="saved ✓"; loadPanels(); }catch(e){ m.textContent="not saved: "+e.message; } return false; }
async function mfExit(id){ const v=+($("mfx_"+id).value||0); if(!v){ $("mfx_"+id).focus(); return; }
  try{ const r=await fetch("ledger?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({op:"exit",id:id,sell:v})}); if(!r.ok) throw new Error(await r.text()); loadPanels(); }catch(e){ $("mf_m").textContent="not saved: "+e.message; } }
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return; const k=e.key; const m={"`":"all","1":"now","2":"three","3":"scn","4":"secs","5":"tape","6":"news","7":"picks","8":"tom","9":"myfo","0":"desk"}; if(m[k]) setView(m[k]); });
loop(); stream(); loadThree(); setInterval(loadThree,120000); setView(VIEW); if(VIEW==="all"&&LASTS&&wsWide()) homeOpen();
</script></body></html>
HTML_P95
cat > $D/p95test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p95test.py - HOME = the trading screen + NSE sectors on the page (read-only; NSE is not called - a sample list is used).
  1 NSE's list read right; Healthcare = pharma + hospitals + labs; Financial Services split banks / nbfc / insurance /
    capital markets; a share NSE's file lacks keeps GIR's own place under the NSE name; every share in ONE sector
  2 /home: every share on the tape sits in exactly one sector, the names are NSE's
  3 the page: HOME opens the trading screen (last share, else the biggest mover), the keys show their panel"""
import os, sys, json, time, socket, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nsesec, sectors
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


print("1. NSE's sectors")
CSV = ("﻿Company Name,Industry,Symbol,Series,ISIN Code\n"
       "Sun Pharmaceutical Industries Ltd.,Healthcare,SUNPHARMA,EQ,INE044A01036\n"
       "Apollo Hospitals Enterprise Ltd.,Healthcare,APOLLOHOSP,EQ,INE437A01024\n"
       "Dr. Lal Path Labs Ltd.,Healthcare,LALPATHLAB,EQ,INE600L01024\n"
       "HDFC Bank Ltd.,Financial Services,HDFCBANK,EQ,INE040A01034\n"
       "Bajaj Finance Ltd.,Financial Services,BAJFINANCE,EQ,INE296A01032\n"
       "SBI Life Insurance Company Ltd.,Financial Services,SBILIFE,EQ,INE123W01016\n"
       "BSE Ltd.,Financial Services,BSE,EQ,INE118H01025\n"
       "Some New Finance Ltd.,Financial Services,NEWFIN,EQ,INE000000000\n"
       "Bharat Forge Ltd.,Automobile and Auto Components,BHARATFORG,EQ,INE465A01025\n"
       "Tata Steel Ltd.,Metals & Mining,TATASTEEL,EQ,INE081A01020\n")
nse = nsesec.parse(CSV)
check("NSE's CSV read (%d shares)" % len(nse), len(nse) == 10 and nse["SUNPHARMA"] == "Healthcare")
hand = sectors.hand_map()
so = lambda s: nsesec.sector_of(s, nse, hand)
check("Healthcare = pharma + hospitals + labs (%s %s %s)" % (so("SUNPHARMA"), so("APOLLOHOSP"), so("LALPATHLAB")), so("SUNPHARMA") == so("APOLLOHOSP") == so("LALPATHLAB") == "healthcare")
check("finance split: %s · %s · %s · %s · a new one -> %s" % (so("HDFCBANK"), so("BAJFINANCE"), so("SBILIFE"), so("BSE"), so("NEWFIN")),
      (so("HDFCBANK"), so("BAJFINANCE"), so("SBILIFE"), so("BSE"), so("NEWFIN")) == ("banks", "nbfc & finance", "insurance", "capital markets", "nbfc & finance"))
check("NSE's names: auto parts are AUTO (%s), metals (%s)" % (so("BHARATFORG"), so("TATASTEEL")), so("BHARATFORG") == "auto" and so("TATASTEEL") == "metals & mining")
check("a share NSE's file lacks keeps GIR's place under the NSE name (CIPLA -> %s, TCS -> %s)" % (so("CIPLA"), so("TCS")), so("CIPLA") == "healthcare" and so("TCS") == "it")
uni = set(s for v in hand.values() for s in v)
pm = nsesec.page_map(uni, nse, hand)
allsyms = [s for v in pm.values() for s in v]
check("every share in ONE sector (%d shares, %d sectors, healthcare %d)" % (len(allsyms), len(pm), len(pm.get("healthcare", []))),
      len(allsyms) == len(set(allsyms)) == len(uni) and len(pm.get("healthcare", [])) >= 15)
check("NSE's order: banks first", list(pm)[0] == "banks")

print("2. /home")
import dashserve
nsesec.load_map = lambda: {"t": time.time(), "src": "test", "map": nse}
srv = dashserve.ThreadingHTTPServer(("127.0.0.1", 0), dashserve.H); port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
s_ = socket.create_connection(("127.0.0.1", port), timeout=120)
s_.sendall(("GET /home?k=%s HTTP/1.0\r\nHost: x\r\n\r\n" % dashserve.TOKEN).encode()); buf = b""
while True:
    d_ = s_.recv(65536)
    if not d_:
        break
    buf += d_
s_.close(); srv.shutdown()
j = json.loads(buf.decode("utf-8", "replace").split("\r\n\r\n", 1)[-1])
tape = [r["s"] for r in j.get("tape") or []]
secs = j.get("sectors") or []
if tape:
    where = {}
    for x in secs:
        for s in x.get("syms") or []:
            where.setdefault(s, []).append(x["name"])
    check("every share on the tape in exactly one sector (%d shares, %d sectors)" % (len(tape), len(secs)), all(len(where.get(s, [])) == 1 for s in tape))
    check("the sector names are NSE's: %s" % [x["name"] for x in secs][:8], all(x["name"] in nsesec.ORDER or x["name"] == "others" for x in secs))
else:
    check("no shares on the tape on this machine - the sectors are left as they were (%d)" % len(secs), True)

print("3. the page")
h = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("HOME opens the trading screen: the last share, else the biggest mover", "function homeOpen" in h and "gir_last" in h and 'HOMED=false; setView("all"); if(wsWide()) homeOpen()' in h)
check("a function key shows its panel (the window steps aside)", 'if(v!=="all"&&FOC&&wsWide()) unfocus();' in h)
check("no HOME / CLOSE inside the window on a laptop; one row each for the desk line, the ticket, the scenarios", "#focus.ws-on .hd .hm,#focus.ws-on .hd a.am{display:none}" in h)
check("a sector the new list does not have falls back to ALL", "if(WS.sec&&!sx&&SECS.length) WS.sec=\"\"" in h)
check("patches 91-93 are still there", all(x in h for x in ("function shareListHTML", "function oiTrendBox", "function alertTier", "function tickSVG")))
print("\nP95 HOME + NSE SECTORS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits:"
python3 $W/p95_patch.py $D || { rm -f $D/nsesec.py $D/p95test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
grep -q "function homeOpen" $W/home.html && grep -q "function alertTier" $W/home.html && grep -q "</html>" $W/home.html || { echo "the new page is not complete"; back; }
cp $W/home.html $D/home.html
cd $D && python3 -m py_compile dashserve.py nsesec.py p95test.py || back
echo "--- 2. NSE's sector list (from this server):"
timeout 90 python3 nsesec.py --fetch
timeout 60 python3 -c "
import nsesec, sqlite3, os
uni = set()
try:
    c = sqlite3.connect('file:chains.db?mode=ro', uri=True); uni = set(r[0] for r in c.execute('select distinct sym from chain15')); c.close()
except Exception:
    pass
if not uni:
    import sectors; uni = set(s for v in sectors.hand_map().values() for s in v)
pm = nsesec.page_map(uni)
print('    %d F&O shares in %d sectors' % (sum(len(v) for v in pm.values()), len(pm)))
for k, v in pm.items():
    print('    %-20s %3d  %s' % (k, len(v), ' '.join(v[:14]) + (' ...' if len(v) > 14 else '')))
" 2>&1 | head -30
echo "--- 3. the tests:"
timeout 300 python3 p95test.py 2>&1 | grep "OK  \|FAIL\|SECTORS TEST"
timeout 300 python3 p95test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p89test.py p91test.py p92test.py p93test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 12
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function homeOpen" || { echo "the new page is not being served"; back; }
printf "    /home  "; curl -s -o /dev/null --compressed -w "%{time_total} s · %{size_download} bytes\n" --max-time 30 "http://127.0.0.1:8090/home?k=$K"
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 95 APPLIED - reload the page on the laptop: it opens on the trading screen. Keys 1-0 = the other panels, ⌂ HOME = back."
