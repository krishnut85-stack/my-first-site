#!/bin/bash
# PATCH 370 - NAM-INDIA IS NOT AN INSURER (Rama, 17 Nov 10:40: "for NAM-INDIA it's rising from the insurance sector").
#   Patch 97 splits NSE's "Financial Services" by the company's own name, and it asked "insurance / life" BEFORE "asset management":
#   Nippon LIFE India Asset Management (NAM-INDIA) and Aditya Birla Sun LIFE AMC (ABSLAMC) were put in INSURANCE. They are fund houses -
#   capital markets, with HDFCAMC, UTIAMC, CAMS, KFINTECH. Now "asset management / AMC" is asked first. Banks and real insurers are unchanged
#   (the installer checks SBI Life, HDFC Life, ICICI Prudential Life, LIC, New India Assurance, Star Health, HDFC Bank before it keeps the change).
#   Edits nsesec.py (one rule, backed up). Restarts the sector reader and the dashboard (they re-read the sectors).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 370" $D/nsesec.py; then echo "patch 370 - already in"; exit 0; fi
grep -q "def fin_by_name" $D/nsesec.py || { echo "nsesec.py (patch 97) not found - nothing done"; exit 1; }
cp $D/nsesec.py $D/nsesec.py.bak$TS
back(){ cp $D/nsesec.py.bak$TS $D/nsesec.py; systemctl restart gir-seclive gir-dash; echo "❌ old nsesec.py back - nothing changed"; exit 1; }
python3 - $D/nsesec.py <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
a = '''    if re.search(r"insurance|\\blife\\b|assurance", n):
        return "insurance"
    if re.search(r"exchange|depositor|securities|wealth|asset management|\\bamc\\b|broking|registr|capital markets|stock", n):
        return "capital markets"
'''
b = '''    if re.search(r"asset management|\\bamc\\b", n):                      # patch 370: Nippon Life India Asset Management, Aditya Birla Sun Life AMC are fund houses
        return "capital markets"
    if re.search(r"insurance|\\blife\\b|assurance", n):
        return "insurance"
    if re.search(r"exchange|depositor|securities|wealth|asset management|\\bamc\\b|broking|registr|capital markets|stock", n):
        return "capital markets"
'''
if t.count(a) != 1:
    print("❌ nsesec.py: the finance rule found %d times (expected 1)" % t.count(a)); sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(a, b)); print("  nsesec.py: asset managers -> capital markets")
PY_EDIT
cd $D && python3 - <<'PY_CHECK' || back
import nsesec as N
T = {"Nippon Life India Asset Management Ltd.": "capital markets", "Aditya Birla Sun Life AMC Ltd.": "capital markets", "HDFC Asset Management Company Ltd.": "capital markets",
     "SBI Life Insurance Company Ltd.": "insurance", "HDFC Life Insurance Company Ltd.": "insurance", "ICICI Prudential Life Insurance Company Ltd.": "insurance",
     "Life Insurance Corporation of India": "insurance", "The New India Assurance Company Ltd.": "insurance", "Star Health and Allied Insurance Company Ltd.": "insurance",
     "HDFC Bank Ltd.": "banks", "Central Depository Services (India) Ltd.": "capital markets"}
bad = [(k, N.fin_by_name(k), v) for k, v in T.items() if N.fin_by_name(k) != v]
for k, got, want in bad:
    print("  ❌ %s -> %s (should be %s)" % (k, got, want))
if bad:
    raise SystemExit(1)
print("  the finance names checked ✓ (%d)" % len(T))
try:
    import sectors
    j = N.load_map() or {}; nm = j.get("names") or {}; hand = sectors.hand_map()
    for s in ("NAM-INDIA", "ABSLAMC", "HDFCAMC", "UTIAMC", "SBILIFE", "LICI"):
        if s in (j.get("map") or {}):
            got = N.sector_of(s, j["map"], hand, nm)
            print("   %-10s %-40s -> %s%s" % (s, (nm.get(s) or "")[:40], got, "   ⚠ GIR's own list (sectors.py) still says insurance - tell Claude" if s in ("NAM-INDIA", "ABSLAMC", "HDFCAMC", "UTIAMC") and got != "capital markets" else ""))
except Exception as ex:
    print("   (the live check was not read: %s)" % str(ex)[:80])
PY_CHECK
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 8
echo "  gir-seclive: $(systemctl is-active gir-seclive) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-seclive)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 370 done - refresh GIR (Ctrl+Shift+R): NAM-INDIA and ABSLAMC are now in CAPITAL MARKETS, not INSURANCE."
echo "   undo: cp $D/nsesec.py.bak$TS $D/nsesec.py; systemctl restart gir-seclive gir-dash"
