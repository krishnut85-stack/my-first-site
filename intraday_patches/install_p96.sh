#!/bin/bash
# PATCH 96 - ONLY F&O SHARES, AND THE LIST KEEPS ITSELF UP TO DATE (on top of patches 94 and 95).
#   · the engine reads NSE's official F&O list from Kite every day (chains.fo_universe). A share NSE takes OUT of F&O is
#     now removed from the list (before, it stayed forever); a new one is added. A short answer from Kite removes nothing.
#   · the day it changes: one 📋 F&O LIST CHANGED line to Box Picks (it rings - an F&O must-know): ➕ added · ➖ removed
#   · the page: the sectors and the share list carry ONLY the shares on that list
#   chains.py · engine2.py · alertword.py · dashserve.py (exact anchors). Installs p96test.py. Restarts gir-intraday, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g96; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p96.sh now"; exit 1; fi
grep -q "import alertword" $D/engine2.py || { echo "patch 94 is not installed yet - paste patch 94 first"; exit 1; }
grep -q "def nse_secs" $D/dashserve.py || { echo "patch 95 is not installed yet - paste patch 95 first"; exit 1; }
grep -q "FO_CHANGES" $D/chains.py && { echo "patch 96 is already installed"; exit 1; }
F="chains.py engine2.py alertword.py dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p96test.py; systemctl restart gir-intraday gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p96_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p96_patch.py - PATCH 96: ONLY F&O SHARES, AND THE LIST KEEPS ITSELF UP TO DATE.
  · chains.fo_universe (the engine reads NSE's official F&O list from Kite every day): a share NSE takes out of F&O is now
    REMOVED from the list (it used to stay forever) and a new one added; the change is kept (chains.FO_CHANGES)
  · the engine sends one 📋 F&O LIST CHANGED line to Box Picks (rings: an F&O must-know) on the day it changes
  · the page: the sectors and the share list carry only the shares on that list
Usage: python3 p96_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


E("chains.py", '''    if out:
        con = db()
        con.executemany("insert or replace into fo_list values(?,?,?)", [(s, l, str(core.ist_now())[:16]) for s, l in out.items()])
        con.commit(); con.close()
    return out''', '''    global FO_CHANGES
    if out:
        con = db()
        old = set(r[0] for r in con.execute("select sym from fo_list"))
        added, removed = sorted(set(out) - old), sorted(old - set(out))
        if old and len(out) < 0.8 * len(old):                  # a short answer from Kite is not NSE removing shares
            log("fo universe: only %d of %d shares came back - nothing removed today" % (len(out), len(old))); removed = []
        con.executemany("insert or replace into fo_list values(?,?,?)", [(s, l, str(core.ist_now())[:16]) for s, l in out.items()])
        if removed:
            con.executemany("delete from fo_list where sym=?", [(s,) for s in removed])
        con.execute("create table if not exists fo_changes(d text, sym text, change text, primary key(d, sym))")
        d_ = str(core.ist_now().date())
        if old:                                                  # the very first list is not a change
            con.executemany("insert or replace into fo_changes values(?,?,?)", [(d_, s, "added") for s in added] + [(d_, s, "removed") for s in removed])
        con.commit(); con.close()
        FO_CHANGES = (added, removed) if old else ([], [])      # the very first list is not a change
        if old and (added or removed):
            log("F&O list changed: added %s · removed %s" % (" ".join(added) or "-", " ".join(removed) or "-"))
    return out


FO_CHANGES = ([], [])        # (added, removed) by the last fo_universe() - patch 96''')
E("engine2.py", '''            fo = chains.fo_universe(kite)
            if not fo:
                return''', '''            fo = chains.fo_universe(kite)
            if not fo:
                return
            try:                                                 # patch 96: NSE added / removed F&O shares -> one line to Box Picks
                ad_, rm_ = getattr(chains, "FO_CHANGES", ([], []))
                if ad_ or rm_:
                    tg_fo("📋 F&O LIST CHANGED · %d shares now\\n%s%s\\nthe page, the sectors and the desk follow the new list from today" % (
                        len(fo), ("➕ added: %s\\n" % " ".join(ad_)) if ad_ else "", ("➖ removed (no F&O any more): %s" % " ".join(rm_)) if rm_ else ""))
            except Exception as ex:
                log("F&O list change line: %s" % str(ex)[:80])''')
E("alertword.py", '''KNOW = re.compile(r"^(🎯 THE THREE|🌙 TOMORROW ·|📋 PRE-OPEN|⚠ the day's|📜 YOUR RULE|ℹ️)")''',
  '''KNOW = re.compile(r"^(🎯 THE THREE|🌙 TOMORROW ·|📋 PRE-OPEN|📋 F&O LIST|⚠ the day's|📜 YOUR RULE|ℹ️)")''')
E("dashserve.py", '''def live_ticks(sym):''', '''_FOS = {"t": 0.0, "v": set()}


def fo_set():
    """NSE's F&O shares today (chains.db fo_list - the engine reads it from Kite every day, adds and removes); 10-min cache"""
    if time.time() - _FOS["t"] < 600 and _FOS["v"]:
        return _FOS["v"]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)
        v = set(r[0] for r in c.execute("select sym from fo_list")); c.close()
    except Exception:
        v = set()
    _FOS.update({"t": time.time(), "v": v})
    return v


def live_ticks(sym):''')
E("dashserve.py", '''        uni_ = set(fps) | set(dks) | set(chain_lines())''', '''        uni_ = fo_set() or (set(fps) | set(dks) | set(chain_lines()))      # patch 96: only NSE's F&O shares''')
E("dashserve.py", '''    for sym in sorted(set(fps) | set(dks) | set(chl)):''', '''    fo_ = fo_set()
    for sym in sorted(set(fps) | set(dks) | set(chl)):
        if fo_ and sym not in fo_:                                # patch 96: only NSE's F&O shares on the list
            continue''')


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
        print("p96: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p96: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p96test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p96test.py - only F&O shares, and the list keeps itself up to date (no network, a scratch chains.db, nothing sent).
  1 day 1: Kite's list -> fo_list, no "change" reported (the first list is not a change)
  2 day 2: NSE added one and removed one -> fo_list follows, FO_CHANGES says which, fo_changes keeps it
  3 a short answer from Kite (a hiccup) removes nothing
  4 the 📋 F&O LIST CHANGED line rings the phone (an F&O must-know); the page reads the list and shows only those shares"""
import os, sys, tempfile, sqlite3
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chains, alertword
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


tmp = tempfile.mkdtemp()
chains.DB = os.path.join(tmp, "chains.db")


class K:
    def __init__(self, syms):
        self.syms = syms

    def instruments(self, seg):
        out = [{"instrument_type": "FUT", "segment": "NFO-FUT", "name": s, "lot_size": 100} for s in self.syms]
        out += [{"instrument_type": "FUT", "segment": "NFO-FUT", "name": "NIFTY", "lot_size": 75}, {"instrument_type": "CE", "segment": "NFO-OPT", "name": "ZZZ", "lot_size": 1}]
        return out


def listed():
    c = sqlite3.connect(chains.DB); v = sorted(r[0] for r in c.execute("select sym from fo_list")); c.close(); return v


day1 = ["S%03d" % i for i in range(200)]
print("1. the first list")
chains.fo_universe(K(day1))
check("fo_list = Kite's 200 F&O shares, the index left out (%d)" % len(listed()), listed() == sorted(day1))
check("the first list is not reported as a change", chains.FO_CHANGES == ([], []))
print("2. NSE adds one, removes one")
day2 = day1[1:] + ["NEWCO"]
chains.fo_universe(K(day2))
check("fo_list follows: NEWCO in, S000 out (%d shares)" % len(listed()), "NEWCO" in listed() and "S000" not in listed() and len(listed()) == 200)
check("FO_CHANGES = %s" % (chains.FO_CHANGES,), chains.FO_CHANGES == (["NEWCO"], ["S000"]))
c = sqlite3.connect(chains.DB); fc = c.execute("select sym, change from fo_changes order by sym").fetchall(); c.close()
check("the change is kept in fo_changes: %s" % fc, fc == [("NEWCO", "added"), ("S000", "removed")])
chains.fo_universe(K(day2))
check("the next day with no change reports none", chains.FO_CHANGES == ([], []))
print("3. a short answer from Kite")
chains.fo_universe(K(day2[:50]))
check("only 50 of 200 came back -> nothing removed (%d still listed)" % len(listed()), len(listed()) == 200 and chains.FO_CHANGES[1] == [])
chains.fo_universe(K([]))
check("an empty answer changes nothing", len(listed()) == 200)
print("4. the phone and the page")
msg = "📋 F&O LIST CHANGED · 200 shares now\n➕ added: NEWCO\n➖ removed (no F&O any more): S000\nthe page, the sectors and the desk follow the new list from today"
check("📋 F&O LIST CHANGED rings the phone as an F&O must-know", alertword.tier(msg) == "know")
import dashserve
dashserve.BASE = tmp; dashserve._FOS["t"] = 0
check("the page reads the list (%d shares)" % len(dashserve.fo_set()), dashserve.fo_set() == set(listed()))
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dashserve.py"), encoding="utf-8").read()
check("the sectors and the share list carry only those shares", "uni_ = fo_set() or" in src and "if fo_ and sym not in fo_:" in src)
print("\nP96 F&O LIST TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits:"
python3 $W/p96_patch.py $D || { rm -f $D/p96test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile chains.py engine2.py alertword.py dashserve.py p96test.py || back
echo "--- 2. the tests (a scratch database, nothing sent):"
timeout 300 python3 p96test.py 2>&1 | grep "OK  \|FAIL\|LIST TEST"
timeout 300 python3 p96test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p88test.py p93test.py p94test.py p95test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo "--- 3. NSE's F&O list on this server today, by sector (only these show on the page):"
timeout 60 python3 -c "
import sqlite3, nsesec
c = sqlite3.connect('file:chains.db?mode=ro', uri=True)
fo = set(r[0] for r in c.execute('select sym from fo_list')); up = c.execute('select max(updated) from fo_list').fetchone()[0]; c.close()
print('    %d F&O shares (read from Kite %s; the engine reads it again every day - removed shares drop off then)' % (len(fo), up))
for k, v in nsesec.page_map(fo).items():
    print('    %-20s %3d  %s' % (k, len(v), ' '.join(v[:12]) + (' ...' if len(v) > 12 else '')))
" 2>&1 | head -30
systemctl restart gir-intraday gir-dash && sleep 12
echo "engine: $(systemctl is-active gir-intraday) · page: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-intraday)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || { echo "a service did not come back"; back; }
journalctl -u gir-intraday --since "-1min" --no-pager -o cat | grep -i "error\|traceback\|F&O list changed" | head -3
echo "PATCH 96 APPLIED - reload the page: the sectors and the list carry only NSE's F&O shares; a change in the list comes to Box Picks."
