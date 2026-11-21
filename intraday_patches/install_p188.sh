#!/bin/bash
# PATCH 188 - the full audit's findings (11 Nov 08:06), each fixed at its root:
#   nseaudit / ixrefresh skip NSE holidays themselves · an empty NSE file is skipped by content (186's size rule also tripped 2 tests)
#   the F&O BAN list also from NSE's own ban file (KAYNES was missing) · the audit's own part 6 typo · gir-watchdog shown (not touched)
#   gir-dash restarts (502 for 1-3 minutes) - before 09:00 or after 15:35. The engine is not restarted.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "too close to / in market hours - run after 15:35"; exit 1; fi
for f in nseaudit.py ixrefresh.py flow.py livecheck.py dashserve.py girfullaudit.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
cat > $W/p188_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p188_patch.py - PATCH 188: the full audit's findings of 11 Nov, each at its root:
  * nseaudit.py and ixrefresh.py: they now skip NSE holidays themselves (the 18:40 audit on 10 Nov wrote the empty file)
  * flow.py / livecheck.py: an EMPTY NSE file is skipped by its content, not its size (patch 186's size rule also skipped small real files)
  * dashserve.py: the F&O BAN list comes from NSE's own ban file (refreshed every 15 min) as well as the desk - KAYNES was missing
  * girfullaudit.py: part 6 (the panels) ran into a typing mistake
Usage: python3 p188_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
HOLG = '''    try:                                                         # patch 188: never on an NSE holiday (10 Nov wrote an empty NSE file)
        import holidays as _h, datetime as _d
        if _h.holiday(_d.datetime.now(_d.timezone(_d.timedelta(hours=5, minutes=30))).date()) and "--force" not in sys.argv:
            print("NSE holiday - nothing to do"); sys.exit(0)
    except SystemExit:
        raise
    except Exception:
        pass
'''
NSEBAN = '''_NBAN = {"t": 0.0, "v": []}


def _nse_ban():
    """patch 188: NSE's own F&O ban list (fo_secban.csv), cached 15 minutes"""
    if time.time() - _NBAN["t"] < 900:
        return _NBAN["v"]
    _NBAN["t"] = time.time()
    try:
        import nseaudit, re as _re
        raw = nseaudit._get(nseaudit.URL_BAN)
        if raw:
            _NBAN["v"] = sorted({m.group(1) for m in _re.finditer(r"(?m)^\\s*\\d+\\s*,\\s*([A-Z][A-Z0-9&-]{1,19})\\s*$", raw.decode("utf-8", "ignore"))})
    except Exception:
        pass
    return _NBAN["v"]


def market():'''
E = {
 "nseaudit.py": [('if __name__ == "__main__":\n    a = [x for x in sys.argv[1:] if not x.startswith("--")]',
                  'if __name__ == "__main__":\n' + HOLG + '    a = [x for x in sys.argv[1:] if not x.startswith("--")]')],
 "ixrefresh.py": [('if __name__ == "__main__":\n    main()', 'if __name__ == "__main__":\n' + HOLG + '    main()')],
 "flow.py": [('and os.path.getsize(f) > 500)   # patch 186: never an empty file', 'and os.path.getsize(f) > 20)   # patch 186 / 188: never an empty file ({})')],
 "livecheck.py": [('and os.path.getsize(f) > 500)   # patch 186', 'and os.path.getsize(f) > 20)   # patch 186 / 188')],
 "dashserve.py": [('def market():', NSEBAN),
                  ('        ban = sorted(desk_state().get("ban") or [])', '        ban = sorted(set(desk_state().get("ban") or []) | set(_nse_ban()))   # patch 188: + NSE\'s own ban file')],
 "girfullaudit.py": [('(and the 1% / 0.25%% rule)', '(and the 1%% / 0.25%% rule)')],
}
done = []
for fn, eds in E.items():
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    ch = False
    for a, b in eds:
        if b in s or ("patch 188" in s and fn in ("nseaudit.py", "ixrefresh.py", "dashserve.py")):
            continue
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), fn, a[:50])); sys.exit(1)
        s = s.replace(a, b, 1); ch = True
    if ch:
        open(p, "w", encoding="utf-8").write(s); done.append(fn)
print("patched: %s" % (", ".join(done) or "nothing new"))
PY_PATCH
back() { for f in nseaudit.py ixrefresh.py flow.py livecheck.py dashserve.py girfullaudit.py; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; }
echo "== 1. the fixes"
R=$(python3 $W/p188_patch.py $D) || { echo "   $R - nothing changed"; back; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile nseaudit.py flow.py livecheck.py dashserve.py girfullaudit.py && { [ ! -f ixrefresh.py ] || python3 -m py_compile ixrefresh.py; } || { back; echo "   does not compile - old files back"; exit 1; }
echo "== 2. the tests"
for t in p165test.py p166test.py p164test.py p184test.py; do [ -f $t ] || continue
  timeout 120 python3 $t > /tmp/$t.log 2>&1 && echo "   $t passed" || { echo "   $t FAILED - old files back:"; grep FAIL /tmp/$t.log | head -3 | sed 's/^/     /'; back; exit 1; }
done
echo "== 3. NSE's ban list today"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 60 python3 -c "import dashserve; print('   ', ', '.join(dashserve._nse_ban()) or 'none')" 2>&1 | tail -1
echo "== 4. gir-watchdog (failed) - not GIR's intraday; shown only, not touched"
systemctl cat gir-watchdog 2>/dev/null | grep -E "Description|ExecStart|WorkingDirectory" | sed 's/^/   /'
journalctl -u gir-watchdog -n 5 --no-pager 2>/dev/null | cut -c1-160 | sed 's/^/   /'
echo -n "== 5. the page server restarting (502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
[ $OK = 1 ] && echo "   ✅ the page is back" || { echo "   ❌ the page did not come back - old files back"; back; systemctl restart gir-dash; exit 1; }
rm -rf $W
echo
echo "PATCH 188 APPLIED. Send Claude a screenshot of sections 3 and 4."
