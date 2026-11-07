#!/bin/bash
# PATCH 97 - THE FINANCE SECTORS BY THE COMPANY'S OWN NAME (on top of patch 96). NSE puts every bank, insurer, broker and
#   lender in one "Financial Services"; patch 95 split it with GIR's own lists, so a bank or insurer not on them (CUB,
#   KARURVYSYA, ICICILIFE ...) fell into NBFC. Now NSE's company name decides: ... Bank -> banks, ... Insurance / Life ->
#   insurance, Exchange / Depository / Securities / Wealth / AMC / Broking -> capital markets, the rest -> nbfc & finance.
#   Index contracts on the F&O list (NIFTYFPI ...) are not shares: left out of the sectors.
#   nsesec.py replaced (backed up) · NSE's list fetched again (with the company names). Installs p97test.py. Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M)
grep -q "FO_CHANGES" $D/chains.py || { echo "patch 96 is not installed yet - paste patch 96 first"; exit 1; }
grep -q "def fin_by_name" $D/nsesec.py && { echo "patch 97 is already installed"; exit 1; }
cp $D/nsesec.py $D/nsesec.py.bak$TS; [ -f $D/data/nse_sectors.json ] && cp $D/data/nse_sectors.json $D/data/nse_sectors.json.bak$TS
back() { cp $D/nsesec.py.bak$TS $D/nsesec.py; [ -f $D/data/nse_sectors.json.bak$TS ] && cp $D/data/nse_sectors.json.bak$TS $D/data/nse_sectors.json; rm -f $D/p97test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $D/nsesec.py <<'PY_NSE'
#!/usr/bin/env python3
"""nsesec.py - the page's sectors by NSE's OWN classification (patch 95). NSE puts every listed share in one sector
(Healthcare = pharma + hospitals + diagnostics, Automobile and Auto Components, Capital Goods ...). The list comes from
NSE's index file for the Nifty Total Market (750 shares, every F&O share is in it), kept in data/nse_sectors.json.
NSE's one big "Financial Services" is split (Rama's choice) into banks · nbfc & finance · insurance · capital markets -
by GIR's own lists first, then by NSE's company name (... Bank -> banks, ... Insurance / Life -> insurance, Exchange /
Depository / Securities / Wealth / Asset Management / Broking -> capital markets, the rest -> nbfc & finance) (patch 97).
Index contracts (NIFTY..., e.g. NIFTYFPI) are not shares and are left out.
A share NSE's file does not have keeps its place from GIR's own map (sectors.py), under the NSE name.
Only the page uses this - the desk and its sector watchers keep sectors.py exactly as before.
  python3 nsesec.py --fetch      download NSE's list now (the page also refreshes it by itself once a month)
  python3 nsesec.py              print the page's sectors for the F&O shares"""
import os, sys, csv, io, json, re, time

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


def parse(text, names=None):
    """NSE's index CSV -> {SYMBOL: NSE sector}; names (a dict) gets {SYMBOL: company name}"""
    out = {}
    for row in csv.DictReader(io.StringIO(text.lstrip("﻿"))):
        r = {(k or "").strip().lower(): (v or "").strip() for k, v in row.items()}
        s, ind = r.get("symbol"), r.get("industry")
        if s and ind:
            out[s.upper()] = ind
            if names is not None and r.get("company name"):
                names[s.upper()] = r["company name"]
    return out


def not_a_share(sym):
    """index contracts on the F&O list (NIFTY, NIFTYFPI ...) are not shares"""
    return sym.upper().startswith("NIFTY") or sym.upper() in ("BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "SENSEX", "BANKEX")


def fin_by_name(name):
    """NSE's Financial Services, split by the company's own name"""
    n = (name or "").lower()
    if re.search(r"\bbank\b", n):
        return "banks"
    if re.search(r"insurance|\blife\b|assurance", n):
        return "insurance"
    if re.search(r"exchange|depositor|securities|wealth|asset management|\bamc\b|broking|registr|capital markets|stock", n):
        return "capital markets"
    return None


def fetch():
    """download NSE's list -> data/nse_sectors.json. Returns (n shares, source) or (0, why)."""
    import requests
    why = []
    for u in URLS:
        try:
            r = requests.get(u, timeout=20, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
                                                     "Accept": "text/csv,*/*", "Referer": "https://www.niftyindices.com/"})
            nm = {}
            m = parse(r.text, nm) if r.ok else {}
            if len(m) >= 300:
                os.makedirs(os.path.dirname(FILE), exist_ok=True)
                tmp = FILE + ".tmp"
                json.dump({"t": time.time(), "src": u, "map": m, "names": nm}, open(tmp, "w"))
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


def sector_of(sym, nse, hand, names=None):
    """one page sector for a share: NSE's (finance split by GIR's own lists, then the company's name), else GIR's own map
    under the NSE name"""
    ind = (nse or {}).get(sym)
    if ind == "Financial Services" or (ind is None and any(sym in hand.get(k, []) for k, _ in FIN)):
        for k, name in FIN:
            if sym in hand.get(k, []):
                return name
        return fin_by_name((names or {}).get(sym)) or "nbfc & finance"
    if ind:
        return NAME.get(ind, ind.lower())
    for k, v in hand.items():
        if sym in v and k in HAND:
            return HAND[k]
    return "others"


def page_map(universe, nse=None, hand=None, names=None):
    """{page sector: [F&O shares]} in NSE's order, for the shares the page shows"""
    j = None
    if nse is None:
        j = load_map() or {}
        nse = j.get("map") or {}
    if names is None:
        names = (j if j is not None else (load_map() or {})).get("names") or {}
    if hand is None:
        import sectors
        hand = sectors.hand_map()
    m = {}
    for s in sorted(universe):
        if not_a_share(s):
            continue
        m.setdefault(sector_of(s, nse, hand, names), []).append(s)
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
cat > $D/p97test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p97test.py - NSE's Financial Services split by the company's own name, and index contracts left out (no network)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nsesec, sectors
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


nm = {}
CSV = ("Company Name,Industry,Symbol,Series,ISIN Code\n"
       "City Union Bank Ltd.,Financial Services,CUB,EQ,x\nKarur Vysya Bank Ltd.,Financial Services,KARURVYSYA,EQ,x\n"
       "ICICI Prudential Life Insurance Company Ltd.,Financial Services,ICICILIFE,EQ,x\nAnand Rathi Wealth Ltd.,Financial Services,ANANDRATHI,EQ,x\n"
       "Some Finance Ltd.,Financial Services,SOMEFIN,EQ,x\nHDFC Bank Ltd.,Financial Services,HDFCBANK,EQ,x\nSun Pharmaceutical Industries Ltd.,Healthcare,SUNPHARMA,EQ,x\n")
nse = nsesec.parse(CSV, nm)
check("NSE's company names kept (%d)" % len(nm), nm.get("CUB") == "City Union Bank Ltd.")
pm = nsesec.page_map(["CUB", "KARURVYSYA", "ICICILIFE", "ANANDRATHI", "SOMEFIN", "HDFCBANK", "SUNPHARMA", "NIFTYFPI", "NIFTY"], nse, sectors.hand_map(), nm)
check("banks by name: %s" % pm.get("banks"), pm.get("banks") == ["CUB", "HDFCBANK", "KARURVYSYA"])
check("insurance by name: %s · capital markets by name: %s" % (pm.get("insurance"), pm.get("capital markets")), pm.get("insurance") == ["ICICILIFE"] and pm.get("capital markets") == ["ANANDRATHI"])
check("the rest of finance -> nbfc & finance: %s" % pm.get("nbfc & finance"), pm.get("nbfc & finance") == ["SOMEFIN"])
check("index contracts (NIFTYFPI, NIFTY) are not shares - left out", not any(s.startswith("NIFTY") for v in pm.values() for s in v))
print("\nP97 SECTOR NAMES TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile nsesec.py p97test.py || back
echo "--- 1. the tests:"
timeout 120 python3 p97test.py 2>&1 | grep "OK  \|FAIL\|NAMES TEST"
timeout 120 python3 p97test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p95test.py p96test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo "--- 2. NSE's list again (with the company names):"
timeout 90 python3 nsesec.py --fetch
echo "--- 3. the F&O shares by sector (what the page shows):"
timeout 60 python3 -c "
import sqlite3, nsesec
c = sqlite3.connect('file:chains.db?mode=ro', uri=True); fo = set(r[0] for r in c.execute('select sym from fo_list')); c.close()
pm = nsesec.page_map(fo)
print('    %d F&O shares in %d sectors' % (sum(len(v) for v in pm.values()), len(pm)))
for k, v in pm.items():
    print('    %-20s %3d  %s' % (k, len(v), ' '.join(v)))
" 2>&1 | head -40
systemctl restart gir-dash && sleep 8
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 97 APPLIED - reload the page."
