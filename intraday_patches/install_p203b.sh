#!/bin/bash
# PATCH 203b - the WALL LADDER in every 🟠 OI message (Rama: "get the start, but say there is no room - or how many supports / resistances
#   it has"): every big wall up to +5% its way, nearest first - its OI and since 09:45: ↑ building / ↓ writers leaving · how many to
#   cross and how many hold · the room = the first wall that HOLDS · the supports behind. Needs patch 203. Restarts the engine.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
cp $D/scenarios.py $D/scenarios.py.bak$TS
back(){ cp $D/scenarios.py.bak$TS $D/scenarios.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p203b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p203b_patch.py - PATCH 203b: the WALL LADDER in every 🟠 OI message (Rama, 11 Nov: "we should get the start, but it should say there is
no room to run - or check how many supports or resistances it has"). Up to +5% its way: every significant wall (40%+ of the biggest OI
there), nearest first, at most 4 - its OI and since the morning (09:45): ↑ building / ↓ writers leaving. The ROOM = the nearest wall
that is NOT shrinking (a wall whose writers leave is no wall). And the supports behind (for CE: the put walls below). Needs patch 203.
Usage: python3 p203b_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "scenarios.py"); s = open(p, encoding="utf-8").read()
if "patch 203b" in s:
    print("  scenarios.py: already in"); sys.exit(0)
if "patch 203:" not in s:
    print("patch 203 is not in - run install_p203.sh first"); sys.exit(1)
ERR = []


def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  scenarios.py: %s" % tag)


rep('''def imp_text(sym, side, b, hm):''', '''def ladder(now_ch, ref_ch, spot, side, upto=5.0, n=4):
    """patch 203b: the walls in the way up to +5% (CE: calls above · PE: puts below) and the supports behind - [(strike, OI, change
    since the morning or None)], nearest first"""
    c, exp = one_expiry(now_ch or {}, spot)
    if not c:
        return [], []
    ref = {(float(k), kd): x for (e, k, kd), x in (ref_ch or {}).items() if e == exp}

    def one(kd, above):
        xs = [(k, float(x[0] or 0)) for (k, d), x in c.items() if d == kd and ((k > spot) if above else (k < spot)) and abs(k / spot - 1) * 100 <= upto]
        if not xs:
            return []
        mx = max(o for k, o in xs)
        out = []
        for k, o in sorted([x for x in xs if mx > 0 and x[1] >= 0.4 * mx], key=lambda x: abs(x[0] - spot))[:n]:
            o0 = (ref.get((k, kd)) or (None,))[0]
            out.append((k, o, (o - float(o0)) if o0 is not None else None))
        return out
    up = side == "CE"
    return one("CE" if up else "PE", up), one("PE" if up else "CE", not up)


def rung(k, o, d, kd):
    arrow = "" if d is None else (" ↑ building +%s" % L(d)) if d > 0 else (" ↓ writers leaving %s" % L(d).replace("-", "−")) if d < 0 else " · flat"
    return "%g %s %s%s" % (k, kd, L(o), arrow)


def imp_text(sym, side, b, hm):''', "the ladder")
rep('''    w = b.get("w") or {}
    way, back = (w.get("roof"), w.get("floor")) if up else (w.get("floor"), w.get("roof"))
    if way and way.get("k") and way.get("away") is not None:''', '''    lad = b.get("ladder")
    if lad and (lad[0] or lad[1]):                               # patch 203b: the whole road, not one wall
        ws, bs = lad
        px = b.get("spot") or 0
        kd, kb = ("CE", "PE") if up else ("PE", "CE")
        hold = [x for x in ws if x[2] is None or x[2] >= 0]
        if hold and px:
            a = abs(hold[0][0] / px - 1) * 100
            L.append("room: %.1f%% to %g, the first wall that holds %s" % (a, hold[0][0], "✅" if a >= 3 else "⚠️" if a >= 1.5 else "❌ too close - it must break first"))
        else:
            L.append("room: no holding wall within 5%% ✅%s" % (" (every wall in the way is losing its writers)" if ws else ""))
        L.append("in the way up to %s5%%: %s" % ("+" if up else "−", " · ".join(rung(k, o, d, kd) for k, o, d in ws) if ws else "nothing big"))
        L.append("%d wall%s to cross · %d holding" % (len(ws), "" if len(ws) == 1 else "s", len(hold)))
        if bs:
            L.append("%s behind: %s" % ("supports" if up else "resistances", " · ".join(rung(k, o, d, kb) for k, o, d in bs[:2])))
        L.append("%s side if the price keeps going its way · room ✅ 3%%+ · ⚠️ 1.5-3%% · ❌ under 1.5%%" % side)
        return "\\n".join(L)
    w = b.get("w") or {}
    way, back = (w.get("roof"), w.get("floor")) if up else (w.get("floor"), w.get("roof"))
    if way and way.get("k") and way.get("away") is not None:''', "the message reads the ladder")
rep('''        hits, exp = detect(now, prev15, ref, spot, spot15, self.ref_spot.get(sym), fp, normal, ref_hm, rd.t, tag != "replay", self.mp.setdefault(sym, {}))''',
    '''        hits, exp = detect(now, prev15, ref, spot, spot15, self.ref_spot.get(sym), fp, normal, ref_hm, rd.t, tag != "replay", self.mp.setdefault(sym, {}))
        if not hasattr(self, "chains"):
            self.chains = {}
        self.chains[sym] = (now, ref)                              # patch 203b: for the 🟠 OI ladder''', "the chain kept for the ladder")
rep('''            self.imp_rang[key] = rd.t
            self.imp_n += 1''', '''            self.imp_rang[key] = rd.t
            self.imp_n += 1
            try:                                                    # patch 203b: the wall ladder
                nc, rc = (getattr(self, "chains", {}) or {}).get(key[0], (None, None))
                if nc:
                    b["ladder"] = ladder(nc, rc, b.get("spot"), key[1])
            except Exception as ex:
                self.log("ladder %s: %s" % (key[0], str(ex)[:80]))''', "the ladder added before sending")
if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("patch 203b written")
PY_PATCH
cat > $D/p203btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p203btest.py - PATCH 203b: the wall ladder in 🟠 OI (made-up chains, nothing sent)"""
import os, sys, types, tempfile
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import scenarios as S
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
E = "2026-11-23"
def ch(d):
    return {(E, float(k), kd): (oi, 10.0, 0) for (k, kd), oi in d.items()}
NOW = {(1900, "PE"): 4e5, (1880, "PE"): 6.1e5, (1920, "CE"): 2e5, (1940, "CE"): 3e5, (1960, "CE"): 5.2e5, (1980, "CE"): 3.5e5, (2000, "CE"): 8e5, (1860, "PE"): 2e5}
REF = dict(NOW); REF[(1960, "CE")] = 4.4e5; REF[(1980, "CE")] = 4.6e5; REF[(1880, "PE")] = 5e5
SENT = []
desk = types.SimpleNamespace(shares={"COROX": {"chg": 2.4, "v": 1, "walls": {}}, "SBINX": {"chg": 0.5, "v": 1, "walls": {}}}, ban=set(), rs={}, last=None, spots={})
ag = S.Agent(desk, P={"tom": os.path.join(tempfile.mkdtemp(), "t.db")}, hooks={"tg_box": lambda t, **k: SENT.append(t), "log": lambda m: None})
ag.reset("2026-11-12")
ag.chains = {"COROX": (ch(NOW), ch(REF))}
rd = types.SimpleNamespace(t=1e6, hm="10:42")
ag.fire("COROX", {"id": "roof_up", "side": "CE", "line": "the roof 1900 → 1960", "spot": 1912.0, "k1": None, "k2": None, "expiry_week": False}, rd, True)
ag.flush_imp(rd)
t = SENT[-1] if SENT else ""
print(t)
check("the ladder: 1960 ↑ building, 1980 ↓ writers leaving, 2000 - nearest first", "1960 CE 5.20 L ↑ building +80,000" in t and "1980 CE 3.50 L ↓ writers leaving −1.10 L" in t and "2000 CE 8.00 L · flat" in t)
check("3 walls to cross · 2 holding", "3 walls to cross · 2 holding" in t)
check("the room = the first wall that holds (1960, 2.5% ⚠️)", "room: 2.5% to 1960, the first wall that holds ⚠️" in t)
check("the supports behind: 1900 and 1880 ↑", "supports behind: 1900 PE 4.00 L" in t and "1880 PE 6.10 L ↑ building +1.10 L" in t)
# SBIN-like: every call wall in the way losing its writers -> open road
N2 = {(1040, "PE"): 9e5, (1030, "PE"): 5e5, (1050, "CE"): 1.2e6, (1060, "CE"): 1.6e6, (1070, "CE"): 1.5e6, (1080, "CE"): 1.4e6, (1020, "PE"): 3e5}
R2 = dict(N2); R2[(1050, "CE")] = 3.6e6; R2[(1060, "CE")] = 1.9e6; R2[(1070, "CE")] = 1.7e6; R2[(1080, "CE")] = 1.6e6
ag.chains["SBINX"] = (ch(N2), ch(R2))
ag.fire("SBINX", {"id": "call_short_covering", "side": "CE", "line": "1050 CE: OI 36 L → 12 L - writers buying back", "spot": 1045.0, "k1": None, "k2": None, "expiry_week": False}, rd, True)
ag.flush_imp(rd)
t2 = SENT[-1] if len(SENT) > 1 else ""
print(t2)
check("SBIN-like: every wall in the way losing its writers -> 'no holding wall within 5% ✅'", "room: no holding wall within 5% ✅ (every wall in the way is losing its writers)" in t2 and "0 holding" in t2)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 203b"
python3 $W/p203b_patch.py $D || back
cd $D && python3 -m py_compile scenarios.py || back
echo "=== the tests (made-up chains - nothing sent)"
for t in p203btest.py p203test.py; do timeout 60 python3 $D/$t > /tmp/$t.out 2>&1 && echo "  $t passed" || { grep FAIL /tmp/$t.out; back; }; done
echo "=== restarting the engine"
systemctl restart gir-intraday && sleep 15 && echo "  gir-intraday: $(systemctl is-active gir-intraday)"
echo
echo "✅ patch 203b done. Every 🟠 OI message now shows the whole road: each wall to +5%, building or leaving, and the supports behind."
