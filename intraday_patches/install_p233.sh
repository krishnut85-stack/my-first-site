#!/bin/bash
# PATCH 233 - WHO IS PUSHING: the two pushers that lit up on almost every share (Rama, 12 Nov audit: WRITERS on 214 of 218 F&O shares, ALGOS on
#   209; PUSH / PULL STARTED right 52 of 134 times). WRITERS: a roof and a floor FORMING are on every chain, and the code took the roof's side
#   first - most shares read "WRITERS ▼" from the order of two lines; now a wall forming is context, WRITERS pushes only on a change (a wall
#   breaking, calls / puts bought, writers running). ALGOS: volume / momentum are the move itself - now neutral, not counted anywhere.
#   GIR's own old test (p215test.py, run by the evening audit) gets the new counts. Tested: the push tests 30 of 30 + FII/DII 7 + the
#   simulated day 16; then this server's 218 shares counted again. Restarts the senders + page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="pushwho.py pushalert.py"; [ -f $D/p215test.py ] && F="$F p215test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p233_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p233_patch.py - PATCH 233: WHO IS PUSHING - the two pushers that lit up on almost every share (Rama, 12 Nov audit: WRITERS on 214 of 218
F&O shares, ALGOS on 209; PUSH / PULL STARTED right 52 of 134 times).
  WRITERS  a roof and a floor FORMING are on every chain - and the code took the first one it checked (the roof) as the side: most shares got
           "WRITERS ▼ pulling down" from the order of two lines. Now a wall forming is context (no side); WRITERS pushes only on a CHANGE:
           a wall BREAKING (writers buying back), calls / puts BOUGHT, writers running
  ALGOS    volume and momentum are the move itself, not who is behind it - still shown, no longer counted in PUSH / PULL STARTED (nor MECHANICAL:
           expiry / dividend dates)
Usage: python3 p233_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        ERR.append("%s missing" % f); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("pushwho.py", '''            on(3, "writers building a %s at %s (%s)" % (side_, m.group(1), "a cap above" if side_ == "roof" else "support below"), k_)''',
    '''            on(3, "writers building a %s at %s (%s)" % (side_, m.group(1), "a cap above" if side_ == "roof" else "support below"))   # patch 233: context - a wall forming is on every chain, not a push''',
    "WRITERS: a wall forming is context, not a side")
rep("pushalert.py", '''    on = [r for r in p.get("rows") or [] if r.get("on")]
    up, dn = [r for r in on if r.get("side", 0) > 0], [r for r in on if r.get("side", 0) < 0]''',
    '''    on = [r for r in p.get("rows") or [] if r.get("on") and r.get("k") not in NOT_FORCE]   # patch 233: ALGOS / MECHANICAL are the move, not who is behind it
    up, dn = [r for r in on if r.get("side", 0) > 0], [r for r in on if r.get("side", 0) < 0]''', "judge: ALGOS / MECHANICAL not counted")
rep("pushalert.py", '''MONEY = ("FUTURES", "WRITERS", "FII", "DII", "PROMOTER", "INDEX")''',
    '''MONEY = ("FUTURES", "WRITERS", "FII", "DII", "PROMOTER", "INDEX")
NOT_FORCE = ("ALGOS", "MECHANICAL")                                 # patch 233''', "NOT_FORCE")
rep("pushwho.py", '''        on(11, "%d fast-move alert%s today (first %s)" % (len(sp), "" if len(sp) == 1 else "s", sp[0][0][:5]), d)''',
    '''        on(11, "%d fast-move alert%s today (first %s)" % (len(sp), "" if len(sp) == 1 else "s", sp[0][0][:5]))   # patch 233: the move itself - neutral''', "ALGOS neutral (fast-move alerts)")
rep("pushwho.py", '''        on(11, "volume %.1fx normal for this time" % f["rv"], d)''', '''        on(11, "volume %.1fx normal for this time" % f["rv"])   # patch 233''', "ALGOS neutral (volume)")
rep("pushwho.py", '''        on(11, "strong momentum in the last 15 min", d)''', '''        on(11, "strong momentum in the last 15 min")   # patch 233''', "ALGOS neutral (momentum)")
# GIR's evening audit runs these old tests: their expectations follow the change (ALGOS no longer counted)
import re as _re
for tf, pairs in (("p215test.py", (("▲ 0 pushing up · ▼ 7 pulling down", "▲ 0 pushing up · ▼ 6 pulling down"), ("▼ 7 pulling down · ▲ 0 pushing up", "▼ 6 pulling down · ▲ 0 pushing up"),
                                   ("▲ 7 pushing up · ▼ 0 pulling down", "▲ 6 pushing up · ▼ 0 pulling down"),
                                   ('''mk("DOWN", [], ["FUTURES", "TIDE", "ALGOS"])''', '''mk("DOWN", [], ["FUTURES", "TIDE", "COMPANY"])'''),
                                   ('''· TIDE (banks) · ALGOS", {"FUTURES", "WRITERS", "FII", "DII", "REGULATOR", "TIDE", "ALGOS"} <= dn''',
                                    '''· TIDE (banks) (ALGOS: neutral since patch 233)", {"FUTURES", "WRITERS", "FII", "DII", "REGULATOR", "TIDE"} <= dn'''))),):
    tp = os.path.join(D, tf)
    if os.path.exists(tp):
        ts = open(tp, encoding="utf-8").read(); n0 = ts
        for a, b in pairs:
            ts = ts.replace(a, b)
        if ts != n0:
            open(tp, "w", encoding="utf-8").write(ts); print("  %s: its expectations follow patch 233" % tf)
        else:
            print("  %s: expectations already updated (or not the same test)" % tf)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 233 in")
PY_PATCH
python3 $W/p233_patch.py $D || back
cd $D && python3 -m py_compile pushwho.py pushalert.py || back
if [ -f $D/p215test.py ]; then
  echo "=== test: the push / pull tests (GIR's own, with the new counts)"
  python3 $D/p215test.py $D 2>&1 | tail -4
  python3 $D/p215test.py $D >/dev/null 2>&1 || back
fi
echo "=== this server's F&O shares now: how often each pusher lights up WITH A SIDE (before: WRITERS 214, ALGOS 209 of 218)"
cd $D && timeout 300 python3 - <<'PY'
import sys, json, collections
sys.path.insert(0, "/home/globalbot/intraday")
import pushwho, pushalert
st = json.load(open("dash_state.json"))
fps = [f["s"] for f in st.get("fo_paths") or [] if f.get("s")]
side, on, push, n = collections.Counter(), collections.Counter(), 0, 0
for s in fps:
    try:
        p = pushwho.read(s)
    except Exception:
        continue
    n += 1
    for r in p["rows"]:
        if r["on"]:
            on[r["k"]] += 1
            if r["side"]:
                side[r["k"]] += 1
    push += bool(pushalert.judge(p))
print("   %d shares · with a side (shown / pushing): " % n + " · ".join("%s %d/%d" % (k, on[k], side[k]) for k in ("FII", "DII", "FUTURES", "WRITERS", "PROMOTER", "INDEX", "COMPANY", "REGULATOR", "TIDE", "BROKERS", "ALGOS")))
print("   shares where PUSH / PULL STARTED's rule says 'a push' right now: %d of %d" % (push, n))
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 233 done - WRITERS pushes only on a change, ALGOS is neutral; the push counts mean something again."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
