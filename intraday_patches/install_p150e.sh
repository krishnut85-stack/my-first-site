#!/bin/bash
# PATCH 150e - NSE'S INDEX FIGURES SURVIVE A RESTART (VIX showed -0.29% after a restart until NSE answered). dashserve.py only (needs 146f).
#   Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g150e; mkdir -p $W
grep -q "patch 150e" $D/dashserve.py && { echo "patch 150e is already installed"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
back() { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/p150e_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p150e_patch.py - PATCH 150e: NSE'S INDEX FIGURES SURVIVE A RESTART (9 Nov 21:40: after a page restart VIX showed 17.42 -0.29% until NSE
answered again). The last good NSE index list is kept in data/nse_indices.json and read back at once after a restart (same session
day only). Usage: python3 p150e_patch.py /home/globalbot/intraday  (needs 146f)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''    if fetch is None or out:
        _NSEI.update({"t": time.time(), "v": out})
    return out''',
     '''    if fetch is None or out:
        _NSEI.update({"t": time.time(), "v": out})
    if out:                                                      # patch 150e: kept for a restart
        try:
            json.dump({"day": _last_session_day(), "v": out}, open(os.path.join(BASE, "data", "nse_indices.json.tmp"), "w"))
            os.replace(os.path.join(BASE, "data", "nse_indices.json.tmp"), os.path.join(BASE, "data", "nse_indices.json"))
        except Exception:
            pass
    return out'''),
    ('''    if fetch is None:                                            # patch 146f: never wait for NSE in a request''',
     '''    if fetch is None and not _NSEI["v"] and not _NSEI.get("loaded"):   # patch 150e: the last good list after a restart
        _NSEI["loaded"] = True
        try:
            j_ = json.load(open(os.path.join(BASE, "data", "nse_indices.json")))
            if j_.get("day") == _last_session_day():
                _NSEI["v"] = {k: tuple(v) for k, v in (j_.get("v") or {}).items()}
        except Exception:
            pass
    if fetch is None:                                            # patch 146f: never wait for NSE in a request'''),
]
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if "patch 150e" in s:
    print("patch 150e is already in dashserve.py"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:80])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: dashserve.py")
PY_PATCH
python3 $W/p150e_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py || back
for t in p146etest.py p146btest.py p145etest.py p145btest.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo
echo "PATCH 150e APPLIED."
