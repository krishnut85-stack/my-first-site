#!/bin/bash
# PATCH 210 - GOVT WATCH reads PIB in Hindi (whylate.sh, 11 Nov: PIB answered, every title in Hindi - patch 151c skipped all Hindi titles
#   expecting an English twin that never came, so GOVT WATCH saw nothing all day, the Cabinet's fertiliser subsidy included).
#   - Hindi titles are read through a word list (मंत्रिमंडल = cabinet, उर्वरक = fertiliser, सब्सिडी = subsidy, करोड़ = crore ...)
#   - a Cabinet approval or ₹5,000 cr+ rings as 🚨 CRITICAL GOVT (a subsidy did not ring before)
#   - fertiliser news names COROMANDEL · CHAMBLFERT · UPL · PIIND (it named HUL / ITC / Nestle)
#   govwatch runs on its 2-minute timer - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
[ -f $D/govwatch.py ] || { echo "govwatch.py missing (patch 151)"; exit 1; }
cp $D/govwatch.py $D/govwatch.py.bak$TS
back(){ cp $D/govwatch.py.bak$TS $D/govwatch.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p210_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p210_patch.py - PATCH 210: GOVT WATCH reads PIB in Hindi too (whylate.sh, 11 Nov: PIB answered 20 items, the titles in Hindi -
patch 151c skipped every Hindi title "its English twin is in the feed", there was none: GOVT WATCH saw nothing all day, the Cabinet's
₹62,370 cr fertiliser subsidy included). Now:
  - a Hindi title is read through a word list (मंत्रिमंडल = cabinet, उर्वरक = fertiliser, सब्सिडी = subsidy, करोड़ = crore ...) and judged
    like an English one; the line shows the Hindi title and what GIR read in it
  - a Cabinet approval, or ₹5,000 cr+, is 🚨 CRITICAL GOVT (rings) - a subsidy was not on the critical list
  - fertiliser news names the fertiliser shares (COROMANDEL · CHAMBLFERT · UPL · PIIND), not HUL / ITC / Nestle
Usage: python3 p210_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "govwatch.py")
s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  govwatch.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  govwatch.py: %s" % tag)


rep('''    (r"fmcg|sugar|edible oil|wheat|rice|food|fertili[sz]er|agricultur", ["fmcg", "chemicals"]),''',
    '''    (r"fertili[sz]er|\\burea\\b|nutrient[- ]based|\\bnbs\\b|phosphatic|potassic|\\bp&k\\b|di-?ammonium", ["fertiliser"]),   # patch 210: its own shares
    (r"fmcg|sugar|edible oil|wheat|rice|food|agricultur", ["fmcg", "chemicals"]),''', "fertiliser -> the fertiliser shares")
rep('''def fo_map():''', '''# patch 210: PIB answers in Hindi - the words that matter, read in English (judged like an English title)
HI = [("मंत्रिमंडल", "cabinet"), ("कैबिनेट", "cabinet"), ("उर्वरक", "fertiliser"), ("यूरिया", "urea"), ("सब्सिडी", "subsidy"),
      ("अनुदान", "subsidy"), ("रबी", "rabi"), ("खरीफ", "kharif"), ("न्यूनतम समर्थन मूल्य", "msp"), ("एमएसपी", "msp"), ("मंजूरी", "approves"),
      ("स्वीकृति", "approves"), ("अनुमोदन", "approves"), ("करोड़", "crore"), ("रेलवे", "railway"), ("रेल", "railway"), ("राजमार्ग", "highway"),
      ("रक्षा", "defence"), ("सेना", "military"), ("बैंक", "public sector bank"), ("रेपो", "repo rate"), ("पेट्रोल", "petrol"), ("डीजल", "diesel"),
      ("कच्चा तेल", "crude"), ("प्राकृतिक गैस", "natural gas"), ("इस्पात", "steel"), ("स्टील", "steel"), ("कोयला", "coal"), ("खनन", "mining"),
      ("बिजली", "power"), ("विद्युत", "electricity"), ("सौर", "solar"), ("दवा", "drug"), ("औषधि", "pharma"), ("स्वास्थ्य", "healthcare"),
      ("दूरसंचार", "telecom"), ("स्पेक्ट्रम", "spectrum"), ("चीनी", "sugar"), ("इथेनॉल", "ethanol"), ("सीमा शुल्क", "customs duty"),
      ("आयात शुल्क", "import duty"), ("निर्यात शुल्क", "export duty"), ("प्रतिबंध", "ban"), ("विनिवेश", "disinvest"), ("जीएसटी", "gst council"),
      ("पीएलआई", "pli"), ("सेमीकंडक्टर", "semiconductor"), ("इलेक्ट्रॉनिक्स", "electronics"), ("वाहन", "vehicle"), ("सीमेंट", "cement"),
      ("आवास", "housing"), ("मेट्रो", "metro"), ("बीमा", "insurance"), ("शेयर बाजार", "stock exchange"), ("सेबी", "sebi")]
EXTRA_SH = {"fertiliser": ["COROMANDEL", "CHAMBLFERT", "UPL", "PIIND", "DEEPAKFERT"]}
CAB = re.compile(r"\\bcabinet\\b.{0,60}\\b(?:approv\\w*|clear\\w*|nod|okays?|gives)|\\b(?:approv\\w*|clear\\w*)\\b.{0,60}\\bcabinet\\b", re.I)


def hindi(title):
    return sum(1 for ch in title if ord(ch) > 0x900) > len(title) * 0.3


def hi_en(title):
    """a Hindi title -> the English words GIR found in it ('' when none)"""
    return " ".join(dict.fromkeys(en for hi, en in HI if hi in title))


def amount_cr(t):
    best = 0.0
    for m in re.finditer(r"(?:rs\\.?|inr|₹)\\s*([\\d,]+(?:\\.\\d+)?)\\s*(lakh crore|crore|cr\\b)?|([\\d,]+(?:\\.\\d+)?)\\s*(?:करोड़|crore)", t or "", re.I):
        try:
            v = float((m.group(1) or m.group(3) or "0").replace(",", ""))
        except ValueError:
            continue
        u = (m.group(2) or "crore").lower()
        best = max(best, v * 1e5 if u.startswith("lakh") else v)
    return best


def fo_map():''', "Hindi word list, the Cabinet rule")
rep('''    shares = []
    for s in secs:
        shares += [x for x in (M.get(s) or [])[:5] if x not in shares]
    return bool(CRIT.search(title)), secs, shares[:8]''', '''    shares = []
    for s in secs:
        shares += [x for x in (M.get(s) or EXTRA_SH.get(s) or [])[:5] if x not in shares]
    crit = bool(CRIT.search(title)) or bool(CAB.search(title)) or amount_cr(title) >= 5000     # patch 210: a Cabinet decision / ₹5,000 cr+ rings
    return crit, secs, shares[:8]''', "a Cabinet decision or ₹5,000 cr+ is critical")
rep('''            if sum(1 for ch in title if ord(ch) > 0x900) > len(title) * 0.3:
                continue                                         # patch 151c: a Hindi headline - its English twin is in the feed
            j = judge(title, M)''', '''            read = title
            if hindi(title):                                    # patch 210: PIB sends Hindi only - read its words (151c skipped them all)
                en = hi_en(title)
                if not en:
                    continue
                read = en + " " + re.sub(r"[^\\x00-\\x7f₹]+", " ", title)
            j = judge(read, M)
            if j and read is not title:
                title = "%s  (Hindi - GIR read: %s)" % (title, hi_en(title))''', "Hindi titles are read")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("govwatch.py: patch 210 in")
PY_PATCH
cat > $D/p210test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p210test.py - patch 210's own test: GOVT WATCH on a made-up PIB feed in Hindi (as PIB sent it on 11 Nov) - no network, nothing sent.
  python3 p210test.py DIR   (DIR = the folder with govwatch.py)"""
import os, sys, json, shutil, tempfile
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "govwatch.py"), T)
sys.path.insert(0, T)
import govwatch as G
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))


def feed(items):
    return "<rss><channel>%s</channel></rss>" % "".join("<item><title>%s</title><link>https://pib.gov.in/x?id=%d</link><pubDate>Wed, 11 Nov 2026 15:00:00 +0530</pubDate></item>" % (t, i) for i, t in enumerate(items))


OLD = ["भारत की राष्ट्रपति ने स्वच्छ सर्वेक्षण पुरस्कार प्रदान किए"]
NEW = OLD + ["मंत्रिमंडल ने रबी सीजन 2026-27 के लिए फॉस्फेटिक और पोटाशिक (पीएंडके) उर्वरकों पर पोषक तत्व आधारित सब्सिडी (एनबीएस) दरों को मंजूरी दी - 62,370 करोड़ रुपये",
             "प्रधानमंत्री ने राष्ट्रीय एकता दिवस पर नागरिकों को शुभकामनाएं दीं",
             "Cabinet approves extension of Noida metro, Rs 7,500 crore",
             "Union Cabinet approves Nutrient Based Subsidy rates for Rabi season 2026-27 on P&K fertilisers"]
state = {"feed": OLD}
get = lambda url: feed(state["feed"]) if "pib" in url else "<rss><channel></channel></rss>"
out = G.run(get=get)
chk("the first run only remembers (no flood)", out == [], out)
state["feed"] = NEW
out = G.run(get=get)
txt = "\n\n".join(out)
hi = [x for x in out if "मंत्रिमंडल" in x]
chk("the Hindi Cabinet release is read (151c skipped it)", len(hi) == 1, txt)
chk("… as 🚨 CRITICAL GOVT (a Cabinet approval)", hi and hi[0].startswith("🚨 CRITICAL GOVT"), hi)
chk("… what GIR read in it is shown: cabinet · fertiliser · subsidy · rabi · approves", hi and all(w in hi[0] for w in ("cabinet", "fertiliser", "subsidy", "rabi", "approves")), hi)
chk("… the fertiliser shares named: COROMANDEL · CHAMBLFERT (not HUL / ITC / Nestle)", hi and "COROMANDEL" in hi[0] and "CHAMBLFERT" in hi[0] and "HINDUNILVR" not in hi[0], hi)
chk("a Hindi greeting (no market word) is not said", not any("शुभकामनाएं" in x for x in out), txt)
en = [x for x in out if "Nutrient Based Subsidy" in x]
chk("the English twin: 🚨 CRITICAL GOVT, FERTILISER, the fertiliser shares", en and en[0].startswith("🚨 CRITICAL GOVT") and "FERTILISER" in en[0] and "COROMANDEL" in en[0], en)
chk("a Cabinet approval of a metro (₹7,500 cr) rings too", any("Noida metro" in x and x.startswith("🚨 CRITICAL GOVT") for x in out), txt)
out2 = G.run(get=get)
chk("said once (the next pass sends nothing again)", out2 == [], out2)
chk("hi_en: 'उर्वरक सब्सिडी' -> fertiliser subsidy", G.hi_en("उर्वरक सब्सिडी") == "fertiliser subsidy", G.hi_en("उर्वरक सब्सिडी"))
shutil.rmtree(T, ignore_errors=True)
print("GOVT WATCH test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p210_patch.py $D || back
cd $D && python3 -m py_compile govwatch.py || back
echo "=== the test (a made-up Hindi PIB feed - nothing sent)"
timeout 60 python3 p210test.py $D > /tmp/p210test.out 2>&1; R=$?
grep -E "✅|❌|passed" /tmp/p210test.out; [ $R = 0 ] || back
echo "=== what PIB / RBI / SEBI answer now"
timeout 60 python3 govwatch.py probe 2>&1 | cut -c1-170 | sed 's/^/   /'
echo "=== PIB's latest titles, read the new way (nothing sent)"
timeout 60 python3 - <<'PY_READ' 2>&1 | head -12 | cut -c1-190
import govwatch as G
txt = G.fetch(G.SOURCES[0][1]) or ""
M = G.fo_map()
for t, l, d in G.items(txt)[:12]:
    en = G.hi_en(t) if G.hindi(t) else ""
    j = G.judge((en + " " + t) if en else t, M)
    print("   %s %s%s" % ("🚨" if j and j[0] else "🏛" if j else "·", t[:80], ("  [read: %s]" % en) if en else ""))
PY_READ
echo "✅ patch 210 done. GOVT WATCH reads PIB's Hindi releases from its next 2-minute run."
echo "   undo: cp $D/govwatch.py.bak$TS $D/govwatch.py"
