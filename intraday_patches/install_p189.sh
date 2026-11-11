#!/bin/bash
# PATCH 189 - the company-name reader names the RIGHT share (SHOCK WATCH, REGULATOR WATCH, TV WATCH, the brief):
#   "excess ITC" (input tax credit) is not ITC Ltd · "BSE Sensex" is not BSE Ltd · "Reserve Bank of India" is not Bank of India ·
#   "Siemens Energy" is ENRIN not SIEMENS (the longest name wins) · the brief: one line per share and kind, penalties under ₹1 cr out.
#   TV WATCH restarts (seconds). Safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
for f in shockwatch.py morningbrief.py; do cp $D/$f $D/$f.bak$TS; done
cat > $W/p189_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p189_patch.py - PATCH 189: the company-name reader names the RIGHT share (the brief of 11 Nov showed it naming wrong ones):
  * "GST demand for excess ITC" - ITC there is input tax credit, not ITC Ltd · "BSE Sensex" is the index, not BSE Ltd ·
    "Reserve Bank of India" is not BANKINDIA (Bank of India) · "Siemens Energy" is ENRIN, not SIEMENS - the longest name wins
  * the brief: one line per share and kind of news (Siemens Energy's buyback came 6 times), regulator penalties under ₹1 crore left out
Usage: python3 p189_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
OLD = '''    def f(t):
        out = []
        for s, rx in pats:
            if s not in out and rx.search(t or ""):
                out.append(s)
        return out
    return f'''
NEW = '''    AMBIG = {"ITC": re.compile(r"\\bITC\\s*(Ltd|Limited|share|stock|Hotels|'s)|\\bshares? of ITC\\b", re.I),       # patch 189: ITC = input tax credit too
             "BSE": re.compile(r"\\bBSE\\s*(Ltd|Limited|share|stock|'s)|\\bshares? of BSE\\b|\\bBSE (results|profit|revenue|Q[1-4])", re.I)}
    BANKPRE = re.compile(r"(Reserve|Central|State|Union|Punjab National|Punjab & Sind|Export-Import|Industrial Development|Development|Small Industries Development)\\s+$", re.I)

    def f(t):
        t = t or ""
        hits = []
        for s, rx in pats:
            for m in rx.finditer(t):
                n = m.group(0)
                if n.upper() in AMBIG and not AMBIG[n.upper()].search(t):
                    continue
                if n.lower().startswith("bank of") and BANKPRE.search(t[max(0, m.start() - 40):m.start()]):
                    continue                                          # "Reserve Bank of India" is not Bank of India
                hits.append((m.start(), m.end(), s))
        keep = []
        for a, b, s in hits:                                          # the longest name wins: "Siemens Energy" over "Siemens"
            if any(a2 <= a and b <= b2 and (b2 - a2) > (b - a) and s2 != s for a2, b2, s2 in hits):
                continue
            if s not in keep:
                keep.append(s)
        return keep
    return f'''
B_OLD = '''    seen, uniq = set(), []
    for x in sorted(items, key=lambda x: x["t"]):
        k = (x["sym"], x["kind"], x["what"][:40])
        if k not in seen:
            seen.add(k); uniq.append(x)'''
B_NEW = '''    seen, uniq = set(), []
    for x in sorted(items, key=lambda x: (-x["cr"], -x["t"])):           # patch 189: one line per share and kind - the biggest / newest
        k = (x["sym"], x["kind"])
        if x["sym"] != "MARKET" and x["kind"] in ("REGULATOR", "GOVERNANCE") and x["side"] < 0 and 0 < x["cr"] < 1 \\
                and re.search(r"penal|fine", x["what"], re.I):
            continue                                                  # a penalty under ₹1 crore is not trouble for an F&O share
        if k not in seen or x["sym"] == "MARKET":
            seen.add(k); uniq.append(x)'''
done = []
for fn, a, b in (("shockwatch.py", OLD, NEW), ("morningbrief.py", B_OLD, B_NEW)):
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    if "patch 189" in s:
        continue
    if s.count(a) != 1:
        print("ANCHOR x%d in %s" % (s.count(a), fn)); sys.exit(1)
    open(p, "w", encoding="utf-8").write(s.replace(a, b, 1)); done.append(fn)
print("patched: %s" % (", ".join(done) or "nothing new"))
PY_PATCH
back() { for f in shockwatch.py morningbrief.py; do cp $D/$f.bak$TS $D/$f; done; }
R=$(python3 $W/p189_patch.py $D) || { echo "$R - nothing changed"; back; exit 1; }; echo "$R"
cd $D && python3 -m py_compile shockwatch.py morningbrief.py || { back; echo "does not compile - old files back"; exit 1; }
for t in p161test.py p168test.py p169test.py p163test.py p162test.py; do [ -f $t ] || continue
  timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "$t passed" || { echo "$t FAILED - old files back:"; grep FAIL /tmp/$t.log | head -3; back; exit 1; }; done
python3 - <<'PY'
import sys; sys.path.insert(0, "/home/globalbot/intraday")
import shockwatch as W, circuits as C
m = W.matcher(C.names(W.fo_syms()))
for t in ("Jindal Steel receives Rs 8.41 crore GST demand for alleged excess ITC", "Punjab National Bank penalised by Reserve Bank of India",
          "Siemens Energy adds up to EUR9 billion buyback", "BSE Sensex falls 500 points", "ITC shares fall after Q2 results"):
    print("   %-70s -> %s" % (t, ", ".join(m(t)) or "no F&O share"))
PY
systemctl restart gir-tvwatch 2>/dev/null && echo "TV WATCH restarted with the new reader"
rm -rf $W
echo "PATCH 189 APPLIED."
