#!/usr/bin/env python3
"""secaudit.py - READ ONLY. IS EVERY SHARE IN THE RIGHT SECTOR? (Rama, 17 Nov 10:45, after NAM-INDIA - a fund house - showed in INSURANCE:
"you have not done your basics - which share belongs to which sector").
GIR's sector for a share comes from NSE's list (one of about 22 NSE sectors) and then GIR's own rules split some of them: Financial Services by
the company's name (banks / nbfc & finance / insurance / capital markets - patch 97), healthcare into pharma / hospitals, telecom into services /
equipment, electronics makers out of capital goods (354c). A rule can be wrong. This checks EVERY share against three things that do not depend
on those rules:
  1 NSE'S SECTOR INDICES   NSE's own constituent lists (niftyindices.com): a share in Nifty Bank / PSU Bank / Private Bank is a bank, in Nifty
                           Capital Markets a capital-markets company, in Nifty Pharma a pharma company, in Nifty IT an IT company, in Nifty
                           Auto / Metal / Realty / Media / FMCG / Oil & Gas / Chemicals / Consumer Durables ... that sector
  2 NSE'S OWN SECTOR       the share's NSE sector (data/nse_sectors.json): GIR's sector must be NSE's or one of its splits
  3 THE COMPANY'S NAME     "... Bank" is a bank, "... Asset Management / AMC" a fund house, "... Insurance" an insurer, "... Hospital" a hospital
Every F&O share is listed with its NSE sector, GIR's sector and the evidence; the ones that disagree come first, with the sector the evidence
points to. The other NSE shares (they count in the sector %) are listed only where they disagree. Nothing is changed, no Kite call.
  cd /home/globalbot/intraday && nice -n 15 python3 secaudit.py      -> prints, saves data/secaudit.txt and data/secaudit.json"""
import os, re, sys, csv, io, json, time
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
L = []
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept": "text/csv,*/*", "Referer": "https://www.niftyindices.com/"}
# NSE's sector index -> the GIR sector its members belong to (names tried in turn - NSE's file names are not all alike)
IDX = [("Nifty Bank", "banks", ["ind_niftybanklist.csv"]),
       ("Nifty PSU Bank", "banks", ["ind_niftypsubanklist.csv"]),
       ("Nifty Private Bank", "banks", ["ind_nifty_privatebanklist.csv", "ind_niftyprivatebanklist.csv"]),
       ("Nifty Capital Markets", "capital markets", ["ind_niftycapitalmarkets_list.csv", "ind_niftycapitalmarketslist.csv", "ind_nifty_capital_markets_list.csv",
                                                     "ind_niftycapitalmarkets.csv"]),
       ("Nifty IT", "it", ["ind_niftyitlist.csv"]),
       ("Nifty Pharma", "pharma", ["ind_niftypharmalist.csv"]),
       ("Nifty Auto", "auto", ["ind_niftyautolist.csv"]),
       ("Nifty Metal", "metals & mining", ["ind_niftymetallist.csv"]),
       ("Nifty Realty", "realty", ["ind_niftyrealtylist.csv"]),
       ("Nifty Media", "media", ["ind_niftymedialist.csv"]),
       ("Nifty FMCG", "fmcg", ["ind_niftyfmcglist.csv"]),
       ("Nifty Oil & Gas", "oil & gas", ["ind_niftyoilgaslist.csv", "ind_niftyoilgas_list.csv", "ind_niftyoil&gaslist.csv"]),
       ("Nifty Chemicals", "chemicals", ["ind_niftychemicals_list.csv", "ind_niftychemicalslist.csv"]),
       ("Nifty Consumer Durables", "consumer durables", ["ind_niftyconsumerdurableslist.csv", "ind_niftyconsumerdurables_list.csv"]),
       ("Nifty Healthcare", "~health", ["ind_niftyhealthcarelist.csv", "ind_niftyhealthcare_list.csv", "ind_niftyhealthcareindexlist.csv"]),
       ("Nifty Financial Services", "~finance", ["ind_niftyfinancelist.csv"]),
       ("Nifty India Defence", "~defence", ["ind_niftyindiadefence_list.csv", "ind_niftyindiadefencelist.csv"]),
       ("Nifty Energy", "~energy", ["ind_niftyenergylist.csv"])]
BASES = ["https://www.niftyindices.com/IndexConstituent/", "https://nsearchives.nseindia.com/content/indices/"]
FIN = {"banks", "nbfc & finance", "insurance", "capital markets"}
HEALTH = {"pharma", "hospitals & diagnostics"}
NAMES = [(r"\bbank\b", "banks"), (r"asset management|\bamc\b", "capital markets"), (r"insurance|assurance", "insurance"),
         (r"hospital|diagnostic|path ?lab|hrudayalaya", "hospitals & diagnostics"), (r"pharma|laborator(y|ies)\b.*(ltd|limited)", "pharma"),
         (r"\bcement", "cement & materials"), (r"exchange|depositor|registr|broking|securities ltd|wealth", "capital markets")]


def say(s=""):
    L.append(s); print(s, flush=True)


def fetch_idx():
    """{index name: (GIR sector, set of symbols)} - kept a day in data/secaudit_idx.json"""
    cf = os.path.join(D, "data", "secaudit_idx.json")
    try:
        j = json.load(open(cf))
        if time.time() - j["t"] < 86400 and len(j["idx"]) >= 8:
            return {k: (v[0], set(v[1])) for k, v in j["idx"].items()}, j.get("miss", [])
    except Exception:
        pass
    import requests
    s = requests.Session(); out = {}; miss = []
    for name, sec, files in IDX:
        got = None
        for b in BASES:
            for f in files:
                try:
                    r = s.get(b + f, headers=UA, timeout=20)
                    if r.ok and "Symbol" in r.text[:400]:
                        rows = list(csv.DictReader(io.StringIO(r.text)))
                        sy = {(x.get("Symbol") or "").strip() for x in rows if (x.get("Symbol") or "").strip()}
                        if len(sy) >= 5:
                            got = sy; break
                except Exception:
                    pass
                time.sleep(0.4)
            if got:
                break
        if got:
            out[name] = (sec, got)
        else:
            miss.append(name)
    try:
        json.dump({"t": time.time(), "idx": {k: [v[0], sorted(v[1])] for k, v in out.items()}, "miss": miss}, open(cf, "w"))
    except Exception:
        pass
    return out, miss


def main():
    import seclive as SL, nsesec as N
    say("🔎 IS EVERY SHARE IN THE RIGHT SECTOR? · GIR's sector against NSE's sector indices, NSE's own sector and the company's name")
    SEC, NM = SL.universe(); FO = SL.fo_set()
    j = N.load_map() or {}; NSE = j.get("map") or {}
    try:
        W, _ = SL.nse_weights()
    except Exception:
        W = {}
    IX, miss = fetch_idx()
    say("  %d NSE shares · %d of them F&O · NSE's sector index lists read: %d (%s)%s" % (len(SEC), sum(1 for s in SEC if s in FO), len(IX), ", ".join(sorted(IX)),
                                                                                    (" · NOT read: " + ", ".join(miss)) if miss else ""))
    if not IX:
        say("  ❌ none of NSE's sector index lists could be read from this server - only the name and NSE-sector checks below")
    mem = {}
    for name, (sec, sy) in IX.items():
        for s in sy:
            mem.setdefault(s, []).append((name, sec))
    rows = []
    for s, g in SEC.items():
        nm = NM.get(s) or ""; ind = NSE.get(s) or ""; ev = []; want = set()
        spec = [sec for _, sec in mem.get(s, []) if not sec.startswith("~")]
        if spec:
            want |= set(spec); ev.append("in " + " + ".join(n for n, sec in mem[s] if not sec.startswith("~")))
        for n, sec in mem.get(s, []):
            if sec == "~health" and g not in HEALTH:
                ev.append("in %s but GIR says %s" % (n, g)); want |= HEALTH if not want else set()
            if sec == "~finance" and g not in FIN:
                ev.append("in %s but GIR says %s" % (n, g)); want |= FIN if not want else set()
        if "Nifty Healthcare" in IX and g == "pharma" and s in IX["Nifty Healthcare"][1] and "Nifty Pharma" in IX and s not in IX["Nifty Pharma"][1] and re.search(r"hospital|diagnos|lab|health", nm, re.I):
            ev.append("in Nifty Healthcare, not in Nifty Pharma - looks like a hospital / lab"); want.add("hospitals & diagnostics")
        nw = None
        for rx, sec in NAMES:
            if re.search(rx, nm, re.I):
                nw = sec; break
        if nw and nw != g and not (nw == "banks" and g in ("nbfc & finance",) and re.search(r"small finance|payments", nm, re.I)):
            if not want or nw in want:
                ev.append("name says %s" % nw); want.add(nw)
        try:
            base = N.NAME.get(ind, ind.lower()) if ind else ""
        except Exception:
            base = ind.lower()
        fam = {base} | (FIN if ind == "Financial Services" else set()) | (HEALTH if base in ("healthcare",) or ind == "Healthcare" else set()) | \
              ({"telecom services", "telecom equipment"} if base.startswith("telecom") else set()) | ({"electronics & hardware"} if base in ("capital goods", "consumer durables") else set())
        off_nse = bool(ind) and g not in fam and g != "others"
        bad = bool(want) and g not in want
        rows.append({"s": s, "fo": s in FO, "name": nm, "nse": ind, "gir": g, "want": sorted(want) if bad else [], "ev": ev, "off_nse": off_nse, "w": W.get(s) or 0})
    F = [r for r in rows if r["fo"]]; FB = [r for r in F if r["want"]]; FN = [r for r in F if not r["want"] and r["off_nse"]]
    say(""); say("1 F&O SHARES IN THE WRONG SECTOR - the evidence points elsewhere (%d of %d)" % (len(FB), len(F)))
    for r in sorted(FB, key=lambda r: r["gir"]):
        say("  ⚠ %-12s %-38s GIR: %-22s → should be: %-26s · %s" % (r["s"], r["name"][:38], r["gir"], " or ".join(r["want"]), " · ".join(r["ev"])))
    if not FB:
        say("  none ✔")
    say(""); say("2 F&O SHARES GIR MOVED OUT OF NSE'S OWN SECTOR (GIR's own list put them there - right or wrong, look at each) (%d)" % len(FN))
    for r in sorted(FN, key=lambda r: r["gir"]):
        say("  ? %-12s %-38s NSE: %-32s GIR: %s" % (r["s"], r["name"][:38], r["nse"][:32], r["gir"]))
    if not FN:
        say("  none ✔")
    O = sorted([r for r in rows if not r["fo"] and r["want"]], key=lambda r: -r["w"])
    say(""); say("3 OTHER NSE SHARES IN THE WRONG SECTOR (not F&O - they still count in the sector %%) (%d) - the biggest first" % len(O))
    for r in O[:60]:
        say("  ⚠ %-12s %-38s GIR: %-22s → should be: %-26s · %s" % (r["s"], r["name"][:38], r["gir"], " or ".join(r["want"]), " · ".join(r["ev"])))
    if len(O) > 60:
        say("  ... and %d more (all in data/secaudit.json)" % (len(O) - 60))
    say(""); say("4 EVERY F&O SHARE AND ITS SECTOR (✔ = nothing disagrees)")
    by = {}
    for r in F:
        by.setdefault(r["gir"], []).append(r)
    for g in sorted(by, key=lambda g: -len(by[g])):
        say("  %-24s %3d │ %s" % (g.upper(), len(by[g]), " ".join(("⚠" if r["want"] else "?" if r["off_nse"] else "") + r["s"] for r in sorted(by[g], key=lambda r: r["s"]))))
    say(""); say("  ⚠ = the evidence says another sector (part 1) · ? = GIR moved it out of NSE's sector (part 2)")
    try:
        open(os.path.join(D, "data", "secaudit.txt"), "w").write("\n".join(L) + "\n")
        json.dump({"t": time.time(), "idx_read": sorted(IX), "idx_missing": miss, "rows": rows}, open(os.path.join(D, "data", "secaudit.json"), "w"))
        say("  saved: data/secaudit.txt")
    except Exception as ex:
        say("  (not saved: %s)" % ex)


if __name__ == "__main__":
    main()
