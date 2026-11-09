#!/bin/bash
# PATCH 138c - "ALREADY KNOWN" IS NOT A SIGNAL (on top of patch 138b).
#   9 Nov 07:13 / 07:22: the reader wrote "weekly recap ... ALREADY KNOWN" on JIOFIN and SUNPHARMA, yet they went out CRITICAL and the
#   EARLY board showed BUY PE. Now: an ALREADY KNOWN story is not sent (critical or not); on the EARLY board a news line marked
#   ALREADY KNOWN, or one the news gate holds (recap / round-up / old results / not F&O), is no signal - today's lines drop off at once.
#   newsalert.py, dashserve.py (exact anchors), p119test.py (its test checks the board only).
#   Restarts gir-dash, gir-newsroom, gir-exchange (the engine is not touched).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g138c; mkdir -p $W
grep -q "patch 138b" $D/newsfresh.py 2>/dev/null || { echo "patch 138b is not installed yet - paste patch 138b first"; exit 1; }
grep -q "patch 138c" $D/newsalert.py && { echo "patch 138c is already installed"; exit 1; }
F="newsalert.py dashserve.py p119test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p138ctest.py; systemctl restart gir-dash gir-newsroom gir-exchange; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p138c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p138c_patch.py - PATCH 138c: "ALREADY KNOWN" IS NOT A SIGNAL. 9 Nov 07:13 / 07:22: the reader itself wrote "weekly recap ...
ALREADY KNOWN" on JIOFIN and SUNPHARMA, yet they went out CRITICAL and the EARLY board showed BUY PE.
  newsalert.decide: a story the reader marks ALREADY KNOWN is not sent (critical or not)
  the EARLY board: a news line marked ALREADY KNOWN, or one the news gate now holds (recap / round-up / old results / not F&O), is
  not a signal - today's JIOFIN / SUNPHARMA lines drop off at once
Usage: python3 p138c_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "newsalert.py": [
        ('''    if r["known"] and r["level"] != "critical":
        return False''', '''    if r["known"]:                                              # patch 138c: already known = already in the price - not sent, critical or not
        return False'''),
    ],
    "p119test.py": [
        ("""import dashserve, engine2, alertword""", """import dashserve, engine2, alertword
import newsfresh; newsfresh.stale_kind = lambda *a, **k: None      # patch 138c: its own test checks the board, not the news gate"""),
    ],
    "dashserve.py": [
        ('''    h = head or ""
    m = re.search(r"sure (\\d+)%", text or "")''', '''    h = head or ""
    if kind in ("🚨", "📰", "📄", "⚡") and _stale_news(h, text):   # patch 138c: the reader's ALREADY KNOWN / a story the news gate holds
        return None
    m = re.search(r"sure (\\d+)%", text or "")'''),
        ('''def _sig_of(kind, head, text):''', '''def _stale_news(head, text):
    """patch 138c: a news line that is no signal: the reader said ALREADY KNOWN, or newsfresh now holds it (recap / round-up /
    results out 4+ days ago / not F&O)"""
    if "ALREADY KNOWN" in (text or ""):
        return True
    m = re.search(r"[▲▼]\\s+([A-Z][A-Z0-9&\\-]{1,19})\\b", head or "") or re.search(r"·\\s+([A-Z][A-Z0-9&\\-]{1,19})\\s+·", head or "")
    if not m or "NEWS" not in (head or ""):
        return False
    L = [x for x in (text or "").split("\\n")[1:] if x.strip() and not re.match(r"(🔴|🟠|📌|🔔|⚠|the reader|also names|watch)", x)]
    try:
        import newsfresh
        return bool(newsfresh.stale_kind(m.group(1), L[0] if L else head))
    except Exception:
        return False


def _sig_of(kind, head, text):'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $D/p138ctest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p138ctest.py - 9 Nov morning: JIOFIN / SUNPHARMA "weekly recap ... ALREADY KNOWN" lines are no EARLY signal and the reader does not
send an already-known story; a real news line still is a signal."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import dashserve, newsalert, newsfresh
newsfresh.stale_kind = lambda s, h, now=None: ("a recap" if "Recap" in (h or "") else None)
J = ("🚨 CRITICAL NEWS ▼ JIOFIN · RESULTS · ET 07:13\n🟠 SOMETHING IS HAPPENING — not a trade by itself\nJio Financial Q2 profit down 51%\n"
     "the reader (x): Q2 profit down 51% is a shock, but this is a weekly recap so numbers already filed and in price · CRITICAL · ALREADY KNOWN · sure 85%")
S = "🚨 CRITICAL NEWS ▼ SUNPHARMA · REG · ET 07:22\nWeekly Recap: Plant halt for eye products\nthe reader (x): plant halt · CRITICAL · sure 85%"
G = "📰 NEWS ▲ AMBUJACEM · CAPEX · ET 18:04\nAmbuja Cements to invest ₹14,500 crore\nthe reader (x): big capacity add · IMPORTANT · sure 80%"
check("JIOFIN 'ALREADY KNOWN': no EARLY signal", dashserve._sig_of("🚨", J.split("\n")[0], J) is None)
check("SUNPHARMA 'Weekly Recap' (the gate holds it): no EARLY signal", dashserve._sig_of("🚨", S.split("\n")[0], S) is None)
check("AMBUJACEM real news: still a signal %s" % (dashserve._sig_of("📰", G.split("\n")[0], G),), dashserve._sig_of("📰", G.split("\n")[0], G) == ("news", "important", 80))
check("the reader: an ALREADY KNOWN critical story is not sent", newsalert.decide({"level": "critical", "relevant": True, "known": True}) is False
      and newsalert.decide({"level": "critical", "relevant": True, "known": False}) is True)
print("\nP138C ALREADY KNOWN TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p138c_patch.py $D || { rm -f $D/p138ctest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile newsalert.py dashserve.py p138ctest.py || back
timeout 120 python3 p138ctest.py 2>&1 | grep "OK  \|FAIL\|P138C"
timeout 120 python3 p138ctest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p119test.py p132ctest.py p118test.py p123test.py p133test.py p138test.py p138btest.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash gir-newsroom gir-exchange && sleep 8
for u in gir-dash gir-newsroom gir-exchange; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 138c APPLIED (the engine was not touched). Reload the GIR page: the EARLY board now -"
cd $D && timeout 60 python3 -c "
import dashserve
E = dashserve.early(fresh=True)
for r in E.get('rows') or []:
    print('  %s %-11s %s' % (r.get('first'), r.get('s'), r.get('verdict')))
print('  (%d shares)' % len(E.get('rows') or []))"
