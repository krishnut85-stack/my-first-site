#!/bin/bash
# PATCH 239 - NEWS FILED UNDER THE RIGHT SHARE (Rama, 13 Nov: AMBER's news showed "AMBER Alert issued for 16-year-old girl last seen in New
#   Smyrna Beach" - a US missing-child alert). GIR searches each share's news as "company name" OR the SYMBOL and stored every result unchecked;
#   for shares whose name is an everyday word (AMBER, OIL, IDEA, ETERNAL, TRENT, TITAN ...) that brings unrelated news.
#   - newsalert: for those shares the full name (or "SYM shares / Q2 / results ...") is needed; known false phrases are refused
#     (AMBER Alert, oil / crude prices, BSE Sensex, MCX gold prices, Olympics, Trent Boult, the Titan submarine) unless it plainly says "SYM shares"
#   - newsroom: a searched headline is stored only when it is about the company
#   - one-time clean-up: the last 4 days' wrong headlines are hidden (score 0, kept; undo below)
#   Also: a headline saying "SYM shares / Q2 / results / profit" counts as the company (was wrongly 🌐 foreign: "OIL shares rally", "MCX Q2 profit").
#   Tested: 29 headlines (old vs new, with GIR's foreign filter), GIR's foreign-news test, the clean-up + undo on a sample database.
#   Restarts the news + senders + special force + page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="newsalert.py newsroom.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
mkdir -p $W/old && cp $D/newsalert.py $W/old/
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p239_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p239_patch.py - PATCH 239: NEWS FILED UNDER THE RIGHT SHARE (Rama, 13 Nov: AMBER's news ticker showed "AMBER Alert issued for 16-year-old girl
last seen in New Smyrna Beach" - a US missing-child alert). GIR searches each share's news as "company name" OR the bare SYMBOL; for a symbol that is
an everyday word (AMBER, OIL, TITAN, IDEA, TRENT ...) the bare word brings unrelated news, and every result was stored under the share unchecked.
  newsalert  for those shares the symbol alone is not enough - the full name is needed; known false phrases are refused (AMBER Alert · oil / crude
             prices for OIL · BSE Sensex for BSE · MCX gold / silver prices for MCX · Olympic for IOC)
  newsroom   a searched headline is stored only when it is about the company; a one-time clean-up hides the last 4 days' wrong ones (score 0)
Usage: python3 p239_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("newsalert.py", '''    by_sym = bool(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(sym), h))          # the symbol in CAPITALS only''',
    '''    by_sym = bool(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(sym), h))          # the symbol in CAPITALS only
    strict = bool(re.search(r"(?<![A-Za-z0-9])%s%s" % (re.escape(sym), CTX239), h, re.I))   # patch 239: "AMBER shares", "OIL Q2", "BSE Ltd"
    if sym in WORD_SYMS:                                        # patch 239: an everyday word - the symbol / one word alone is not the company
        by_sym = strict
        if len(w) >= 2:
            by_name = bool(re.search(r"(?<![A-Za-z])%s(?![A-Za-z])" % r"\\s+".join(re.escape(x) for x in w[:2]), h, re.I))
        elif w and w[0].lower() in PLAIN239:                    # "Eternal", "Astral": only with shares / Q2 / results ... after it
            by_name = bool(re.search(r"(?<![A-Za-z])%s%s" % (re.escape(w[0]), CTX239), h, re.I))
        elif w:                                                 # "Titan", "Trent": a capital letter, as a name is written
            by_name = bool(re.search(r"(?<![A-Za-z])%s(?![A-Za-z])" % re.escape(w[0]), h))
    if NOT_IT.get(sym) and not strict and re.search(NOT_IT[sym], h, re.I):
        return False
    by_name = by_name or strict                                 # patch 239: "OIL shares rally", "MCX Q2 profit" - the company, not 🌐 foreign''', "everyday-word symbols need the name · false phrases refused")
rep("newsalert.py", '''    by_sym = by_sym or any(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(a), h) for a in AKA.get(sym, []))''',
    '''    by_sym = by_sym or any(re.search(r"(?<![A-Za-z0-9])%s(?![A-Za-z0-9])" % re.escape(a), h) for a in AKA.get(sym, [])
                           if not (sym in WORD_SYMS and a.upper() == sym and a == a.title()))   # patch 239: "Eternal" alone is not Eternal Ltd ("IndiGo" stays)''', "short names: not the bare everyday word")
rep("newsalert.py", '''def about_it(sym, h, src="", name=""):''', '''WORD_SYMS = {"AMBER", "OIL", "IDEA", "SAIL", "ETERNAL", "PERSISTENT", "PRESTIGE", "MANKIND", "FORTIS", "INDIGO", "ASTRAL", "TITAN", "TRENT"}  # patch 239
PLAIN239 = {"eternal", "astral", "amber", "persistent", "prestige", "mankind", "fortis", "idea", "sail", "oil"}
CTX239 = r"(?:'s)?\\s+(?:shares?|stock|scrip|ltd|limited|q[1-4]|results?|target|futures|options|profit|revenue|board|dividend)\\b"
NOT_IT = {"AMBER": r"\\bamber alert", "OIL": r"\\b(?:crude|brent|wti|opec|oil prices?|edible oil|palm oil)\\b",
          "BSE": r"\\bsensex\\b|\\bbse (?:smallcap|midcap|500|100|200|index)", "IOC": r"\\bolympic",
          "MCX": r"\\bmcx (?:gold|silver|crude|natural gas|copper|zinc|aluminium)|\\b(?:gold|silver) prices?\\b",
          "TITAN": r"\\btitan (?:submarine|sub)\\b|\\bsaturn\\b|\\boceangate\\b", "TRENT": r"\\btrent (?:boult|alexander|bridge)|\\bboult\\b|\\balexander-arnold\\b"}


def about_it(sym, h, src="", name=""):''', "WORD_SYMS · NOT_IT")
rep("newsroom.py", '''        a = audit(h, link, src, exch_side, confirms)''', '''        if src == "GOOGLE NEWS":                                # patch 239: a searched headline is stored only when it is about the company
            try:
                import newsalert
                if newsalert.about_it(sym, h) is False:
                    continue
            except Exception:
                pass
        a = audit(h, link, src, exch_side, confirms)''', "store only headlines about the company")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 239 in")
PY_PATCH
cat > $W/p239test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p239test.py - news filed under the right share (names given; nothing sent).  python3 p239test.py NEWDIR OLDDIR  (newsalert.py in each)"""
import os, sys, shutil, tempfile, importlib.util
NEW, OLD = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
T = tempfile.mkdtemp()
def load(n, d):
    shutil.copy(os.path.join(d, "newsalert.py"), os.path.join(T, n + ".py"))
    sp = importlib.util.spec_from_file_location(n, os.path.join(T, n + ".py")); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m); return m
sys.path.insert(0, T)
N, O = load("na_new", NEW), load("na_old", OLD)
NM = {"AMBER": "Amber Enterprises India", "OIL": "Oil India", "BSE": "BSE", "MCX": "Multi Commodity Exchange of India", "INDIGO": "InterGlobe Aviation",
      "IOC": "Indian Oil Corporation", "TITAN": "Titan Company", "SBIN": "State Bank of India", "COROMANDEL": "Coromandel International", "ETERNAL": "Eternal", "TRENT": "Trent", "HAL": "Hindustan Aeronautics",
      "DIXON": "Dixon Technologies (India)", "IDEA": "Vodafone Idea", "ASTRAL": "Astral"}
C = [("AMBER", "AMBER Alert issued for 16-year-old girl last seen in New Smyrna Beach", False),
     ("AMBER", "Amber Enterprises shares jump 6% on a new order", True),
     ("AMBER", "AMBER shares hit upper circuit after Q2 numbers", True),
     ("OIL", "Oil prices rise as OPEC+ extends output cuts", False),
     ("OIL", "Oil India Q2 profit jumps 53%", True),
     ("OIL", "OIL shares rally 4% after results", True),
     ("BSE", "BSE Sensex falls 500 points as IT stocks drag", False),
     ("BSE", "BSE shares hit a record high on strong F&O volumes", True),
     ("MCX", "MCX gold prices today: yellow metal slips", False),
     ("MCX", "MCX Q2 profit doubles on record volumes", True),
     ("INDIGO", "IndiGo cancels 200 flights amid crew shortage", True),
     ("IOC", "IOC suspends a national body ahead of the Olympics", False),
     ("TITAN", "Titan Q2 results: jewellery sales up 18%", True),
     ("SBIN", "SBI raises Rs 10,000 crore via bonds", True),
     ("COROMANDEL", "Coromandel International raises FY27 EBITDA outlook", True),
     ("ETERNAL", "Eternal love: a story of two old friends", False),
     ("ETERNAL", "Eternal shares rise 3% after Blinkit growth", True),
     ("ETERNAL", "Zomato parent Eternal Q2 profit falls 60%", True),
     ("TRENT", "Trent Boult picks three wickets as New Zealand win", False),
     ("TRENT", "Trent opens 50 new Zudio stores", True),
     ("TITAN", "Titan submarine: report blames OceanGate", False),
     ("BSE", "BSE shares fall 4% as Sensex drops 800 points", True),
     ("MCX", "MCX gets SEBI nod for a new electricity contract", True),
     ("HAL", "HAL bags Rs 62,000 crore order for 97 Tejas jets", True),
     ("DIXON", "Dixon arm signs a JV with a Chinese partner", True),
     ("IDEA", "Vodafone UK completes merger with Three", False),
     ("IDEA", "Vodafone Idea shares jump on AGR relief hopes", True),
     ("ASTRAL", "Astral projection: what science says", False),
     ("ASTRAL", "Astral Q2 profit rises 12%", True)]
ok = 0
for s, h, want in C:
    got = N.about_it(s, h, name=NM[s]); old = O.about_it(s, h, name=NM[s])
    good = (got is False) if not want else (got is not False and not (old is True and got is not True))   # drop = refused; keep = stored, never worse
    ok += good
    print("  %s %-10s %-62s new %-7s old %s%s" % ("✅" if good else "❌", s, h[:62], got, old, "   (kept; 🌐 label is the older foreign rule)" if good and got == "foreign" else ""))
print("NEWS MATCH test: %d of %d passed" % (ok, len(C)))
sys.exit(0 if ok == len(C) else 1)
PY_TEST
cat > $D/p239clean.py <<'PY_CLEAN'
#!/usr/bin/env python3
"""p239clean.py - the one-time clean-up: the last 4 days' searched headlines that are NOT about their share get score 0 (hidden from the ticker,
the share's news and the special force - kept, not deleted; the old scores go to data/p239_hidden.json).
python3 p239clean.py DIR [--dry]      undo: python3 p239clean.py DIR --undo"""
import sys, os, time, json, sqlite3
D = os.path.abspath(sys.argv[1]); dry = "--dry" in sys.argv
sys.path.insert(0, D); os.chdir(D)
c = sqlite3.connect(os.path.join(D, "news.db"), timeout=10)
J = os.path.join(D, "data", "p239_hidden.json")
if "--undo" in sys.argv:
    rows = json.load(open(J))
    c.executemany("update items set score=?, note=replace(note,' · not about it (patch 239)','') where key=? and sym=?", [(sc, k, s) for k, s, sc in rows])
    c.commit(); print("  %d headlines given back their old score" % len(rows)); sys.exit(0)
import newsalert
rows = c.execute("select key, sym, h, score from items where src='GOOGLE NEWS' and t_pub>? and score>0", (time.time() - 4 * 86400,)).fetchall()
bad = [(k, s, h, sc) for k, s, h, sc in rows if newsalert.about_it(s, h) is False]
print("  %d searched headlines in 4 days · %d not about their share%s" % (len(rows), len(bad), " (dry run - nothing changed)" if dry else " - hidden (score 0)"))
for k, s, h, sc in bad[:15]:
    print("     %-11s %s" % (s, h[:100]))
if not dry and bad:
    old = json.load(open(J)) if os.path.exists(J) else []
    json.dump(old + [(k, s, sc) for k, s, h, sc in bad], open(J, "w"))
    c.executemany("update items set score=0, note=coalesce(note,'')||' · not about it (patch 239)' where key=? and sym=?", [(k, s) for k, s, h, sc in bad])
    c.commit()
c.close()
PY_CLEAN
python3 $W/p239_patch.py $D || back
cd $D && python3 -m py_compile newsalert.py newsroom.py || back
echo "=== test: 29 headlines, old reader vs new"
cd $D && PYTHONPATH=$D python3 $W/p239test.py $D $W/old || back
if [ -f $D/p213atest.py ]; then echo "=== GIR's foreign-news test"; cd $D && python3 p213atest.py $D 2>&1 | grep -E "❌|passed"; python3 p213atest.py $D >/dev/null 2>&1 || back; fi
if [ -f $D/p215test.py ]; then cd $D && python3 p215test.py $D 2>&1 | grep -E "❌|passed"; python3 p215test.py $D >/dev/null 2>&1 || back; fi
echo "=== the server's real names (no name given - as the news reader calls it)"
cd $D && python3 - <<'PY' || back
import sys; sys.path.insert(0, "/home/globalbot/intraday")
import newsalert as N
C = [("AMBER", "AMBER Alert issued for 16-year-old girl last seen in New Smyrna Beach", False), ("AMBER", "Amber Enterprises shares jump 6% on a new order", True),
     ("OIL", "Oil prices rise as OPEC+ extends output cuts", False), ("OIL", "Oil India Q2 profit jumps 53%", True),
     ("TRENT", "Trent Boult picks three wickets as New Zealand win", False), ("TRENT", "Trent opens 50 new Zudio stores", True),
     ("INDIGO", "IndiGo cancels 200 flights amid crew shortage", True), ("HAL", "HAL bags Rs 62,000 crore order for 97 Tejas jets", True)]
ok = 0
for s, h, want in C:
    got = N.about_it(s, h); good = (got is False) if not want else (got is not False)   # drop = refused; keep = stored
    ok += good
    print("   %s %-7s %-66s -> %s" % ("✅" if good else "❌", s, h[:66], got))
print("   real names: %d of %d" % (ok, len(C)))
sys.exit(0 if ok == len(C) else 1)
PY
echo "=== one-time clean-up of the last 4 days"
cd $D && python3 p239clean.py $D || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 239 done - searched news is stored only when it is about the company; AMBER Alert-type stories are gone from the share's news."
echo "   undo: python3 $D/p239clean.py $D --undo; for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
