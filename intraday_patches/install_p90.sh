#!/bin/bash
# PATCH 90 - THE PAGE SERVER STOPS RE-READING 3 MB (on top of patch 89). The engine's state file (~3 MB, rewritten every
#   second) was parsed again on every request and once more for the index strip - seconds on this server, and every other
#   request (even the page itself) waited behind it. Now: parsed once per change, shared by every reader; the background
#   rebuild of the home data never takes more than ~20% of the server. Then it times each part on this server.
#   dashserve.py (exact anchors). Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g90; mkdir -p $W
grep -q 'def panels' $D/dashserve.py || { echo "patch 89 is not installed yet - paste patch 89 first"; exit 1; }
grep -q 'def live_obj' $D/dashserve.py && { echo "patch 90 is already installed"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p90_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p90_patch.py - PATCH 90: THE PAGE SERVER STOPS RE-READING 3 MB. The engine's state file (dash_state.json, ~3 MB, written
every second) was read and parsed on EVERY request (/home build, /three, /focus, the board...) and once more for the index
strip - on a small server that is seconds, and it held every other request (even the page itself) behind it.
  · live_obj(): live_state() parsed ONCE per change of the file (and the closed-day picture once a minute); every reader uses it
  · the index strip on a closed day reads the cached parse, not the 3 MB file again
  · the home refresher rebuilds every max(5 s, 4 x its own build time) - it can never keep the server busy more than ~20%
Usage: python3 p90_patch.py /home/globalbot/intraday  (anchors must match, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new, n=1):
    EDITS.setdefault(f, []).append((old, new, n))


E("dashserve.py", '''def live_state():''', '''_LO = {"key": None, "v": None, "t": 0.0}


def live_obj():
    """live_state() as a parsed dict, parsed ONCE per change of the engine's state file (the closed-day picture once a minute).
    Every reader shares it: the 3 MB parse used to run on every request and held the whole page server behind it."""
    try:
        m = os.path.getmtime(STATE)
    except Exception:
        m = None
    key = (m, dt.datetime.now(IST).strftime("%Y-%m-%d"))
    if _LO["v"] is not None and _LO["key"] == key and time.time() - _LO["t"] < 60:
        return _LO["v"]
    try:
        raw = live_state()
        v = json.loads(raw)
    except Exception:
        v = {}
    _LO.update({"key": key, "v": v, "t": time.time()})
    return v


def live_state():''')
E("dashserve.py", '''json.loads(live_state())''', '''live_obj()''', n=-1)                 # every reader (home, three, focus, board, ...)
E("dashserve.py", '''            idx = (json.load(open(STATE)).get("idx")) or {}''', '''            idx = (state_json().get("idx")) or {}''')
E("dashserve.py", '''        time.sleep(max(3.0, 2 * took))''', '''        time.sleep(max(5.0, 4 * took))                       # never more than ~20% of the server's time''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new, n) in enumerate(edits, 1):
            c = s.count(old)
            if (n == 1 and c != 1) or (n == -1 and c < 1):
                print("ANCHOR %s #%d found %d times: %r" % (f, i, c, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p90: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new, n in edits:
            if n == -1:
                print("p90: %s: %d readers of the 3 MB file now share one parse" % (f, s.count(old)))
                s = s.replace(old, new)
            else:
                s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p90: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
echo "--- 1. the edits:"
python3 $W/p90_patch.py $D || { echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || back
echo "--- 2. the page tests:"
for t in p81test.py p83test.py p84test.py p89test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
pgrep -f "oistudy.py --fetch" >/dev/null && echo "    note: the two-year study is still downloading in the background - the times below are slower while it runs"
echo "--- 3. each part of the home data, built inside the page server's code on this server (ms):"
timeout 120 python3 -c "
import time, dashserve as d, sectors
def t(name, f):
    t0 = time.time(); f(); print('    %-34s %7.0f ms' % (name, (time.time() - t0) * 1000))
t('the engine state, first parse', d.live_obj)
t('the engine state, cached', d.live_obj)
t('the desk picture (desk.json)', d.desk_state)
t('the sector map', sectors.load)
t('the last chain reading (10-min cache)', d.chain_lines)
t('the index strip', d.idx_closed)
t('THE THREE', d.three)
t('the whole home data (rebuilt)', lambda: d.home(fresh=True))
t('the whole home data (from memory)', d.home)
" 2>&1 | grep -v "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9] "
systemctl restart gir-dash && sleep 12
K=$(cat $D/dash_token.txt)
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q 'id="fkeys"' || { echo "the page is not being served"; back; }
echo "--- 4. how fast each part of the page answers now (seconds · size):"
for p in "/" "/home" "/panels" "/three" "/focus?sym=RELIANCE" "/chart?sym=RELIANCE" "/oi?sym=RELIANCE"; do
  printf "    %-26s " "$p"; curl -s -o /dev/null --compressed -w "%{time_total} s · %{size_download} bytes\n" --max-time 30 "http://127.0.0.1:8090${p}$( [[ $p == *\?* ]] && echo "&" || echo "?" )k=$K"
done
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 90 APPLIED - reload the page."
