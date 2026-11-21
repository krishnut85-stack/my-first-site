#!/bin/bash
# PATCH 203 - 🟠 OI: the IMPORTANT OI situations ring again, MANAGED (Rama: "you are not trying to manage the alerts - you lost important
#   signals"): futures build-up / short covering / long unwinding / the futures turned · the roof or floor moving (resistance / support
#   shifting) · call / put writers running (a wall giving way) · bull / bear shift -> ONE message a share a side (whatever fired together),
#   at most one every 30 min, 40 a day, only when the share's move agrees, each with the ROOM (✅ 3%+ · ⚠️ 1.5-3% · ❌ under 1.5%).
#   GIR Live -> the OI topic + the page. Restarts the engine (run after 15:35 or before 09:00).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
FILES="scenarios.py alertword.py tglanes.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p203_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p203_patch.py - PATCH 203: 🟠 OI - the IMPORTANT OI situations ring again, MANAGED (Rama, 11 Nov: "you are trying to reduce the alerts,
you are not trying to manage them - in due course you lost many important signals": the futures build-up, the resistance moving to
the next strike, the support leaving and a new resistance coming up - COROMANDEL).
  rings (GIR Live -> the OI topic, and the page)   the futures: LONG / SHORT BUILD-UP, SHORT COVERING, LONG UNWINDING (₹25 cr+),
        THE FUTURES TURNED · the walls: THE ROOF MOVED UP / DOWN, THE FLOOR MOVED UP / DOWN, CALL / PUT WRITERS RUNNING (a wall giving
        way) · FLOOR BUILDING + ROOF LEAVING / ROOF BUILDING + FLOOR LEAVING
  managed   ONE message for a share and its side, whatever fired together (the roof moved + long build-up = one message) · at most one
        a share a side every 30 minutes · 40 a day · only when the share's own move agrees (no PE while it rises) · every one says
        the ROOM: ✅ the next wall 3%+ away · ⚠️ 1.5-3% · ❌ under 1.5% - and the floor / roof behind
  the rest stays on the page (the OI tab, the share's screen). Usage: python3 p203_patch.py DIR"""
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


rep("scenarios.py", '''HOLD_S = 60
''', '''HOLD_S = 60
# patch 203: the IMPORTANT OI situations ring again as 🟠 OI - managed (one message a share a side, 30 min apart, 40 a day)
IMPORTANT = {"fut_long_buildup", "fut_short_buildup", "fut_short_covering", "fut_long_unwinding", "fut_turn", "roof_up", "roof_down",
             "floor_up", "floor_down", "call_short_covering", "put_short_covering", "bull_shift", "bear_shift"}
IMP_GAP_S, IMP_CAP = 1800, 40


def imp_text(sym, side, b, hm):
    """one 🟠 OI message: what moved, the money, the room"""
    up = side == "CE"
    chg = b.get("chg")
    L = ["🟠 OI %s %s · %s · ₹%s%s · %s" % ("▲" if up else "▼", sym, side, format(round(b.get("spot") or 0, 2), ","), (" %+.1f%%" % chg) if chg is not None else "", hm)]
    for name, line in b["items"]:
        L.append("• %s: %s" % (name, line))
    w = b.get("w") or {}
    way, back = (w.get("roof"), w.get("floor")) if up else (w.get("floor"), w.get("roof"))
    if way and way.get("k") and way.get("away") is not None:
        a = float(way["away"])
        L.append("room: the next %s wall %g = %.1f%% away %s" % ("call" if up else "put", way["k"], a, "✅" if a >= 3 else "⚠️ (1.5-3%)" if a >= 1.5 else "❌ too close - wait for it to break"))
    else:
        L.append("room: no big %s wall near ✅" % ("call" if up else "put"))
    if back and back.get("k") and back.get("away") is not None:
        L.append("%s behind: %g (%.1f%% %s)" % ("the floor" if up else "the roof", back["k"], float(back["away"]), "below" if up else "above"))
    L.append("%s side if the price keeps going its way · room ✅ 3%%+ · ⚠️ 1.5-3%% · ❌ under 1.5%%" % side)
    return "\\n".join(L)
''', "the important OI situations and the message")
rep("scenarios.py", '''        self.pending, self.digest_at = [], 0.0
''', '''        self.pending, self.digest_at = [], 0.0
        self.imp, self.imp_rang, self.imp_n = {}, {}, 0                 # patch 203
''', "the day's 🟠 OI state")
rep("scenarios.py", '''        text = "\\n".join(x for x in (L1, L2, L3, L4, L5) if x)
        if send:''', '''        text = "\\n".join(x for x in (L1, L2, L3, L4, L5) if x)
        if h["id"] in IMPORTANT and side and send and (chg is None or (chg > 0 if side == "CE" else chg < 0)):   # patch 203: 🟠 OI
            b_ = self.imp.setdefault((sym, side), {"items": [], "spot": spot, "chg": chg, "w": r.get("walls") or {}})
            b_["items"].append((cat["name"], h["line"][:160])); b_["spot"], b_["chg"], b_["w"] = spot, chg, r.get("walls") or {}
            ch = "imp"
        if send:''', "a fired important situation joins its share's 🟠 OI message")
rep("scenarios.py", '''        if send:
            self.digest(rd)
        return fired''', '''        if send:
            self.digest(rd)
            self.flush_imp(rd)                                        # patch 203
        return fired''', "the 🟠 OI messages go out after each reading")
rep("scenarios.py", '''    def digest(self, rd, force=False):''', '''    def flush_imp(self, rd):
        """patch 203: one 🟠 OI message a share a side - at most one every 30 min, 40 a day (the rest: on the page)"""
        for key in list(getattr(self, "imp", {}) or {}):
            b = self.imp.pop(key)
            if rd.t - self.imp_rang.get(key, 0) < IMP_GAP_S or self.imp_n >= IMP_CAP:
                continue
            self.imp_rang[key] = rd.t
            self.imp_n += 1
            try:
                (self.hooks.get("tg_box") or (lambda *a, **k: False))(imp_text(key[0], key[1], b, rd.hm), sym=key[0], side=key[1])
            except Exception as ex:
                self.log("🟠 OI %s: %s" % (key[0], str(ex)[:80]))

    def digest(self, rd, force=False):''', "the managed sender")
rep("alertword.py", '''    if k == "🧩":                                                # patch 191: an OI reading rings only as a measured BUY''',
    '''    if H2.startswith("🟠 OI "):                                 # patch 203: the important OI situations ring (managed in scenarios.py)
        return "move"
    if k == "🧩":                                                # patch 191: an OI reading rings only as a measured BUY''', "🟠 OI rings")
rep("tglanes.py", '''OI_K = ("🧩", "🔭", "🔎")''', '''OI_K = ("🧩", "🔭", "🔎", "🟠")                                     # patch 203: + 🟠 OI''', "🟠 OI -> the OI topic")
rep("home.html", '''  if(k==="🧩") return (cleanBuy&&buyLine)?"act":"watch";''', '''  if(/^🟠 OI /.test(H)) return "move";   /* patch 203 */
  if(k==="🧩") return (cleanBuy&&buyLine)?"act":"watch";''', "the page: 🟠 OI pops up")
rep("home.html", '''  if(["🧩","🔭","🔎"].includes(k)''', '''  if(["🧩","🔭","🔎","🟠"].includes(k)''', "the page: 🟠 OI in the OI lane")
if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 203 written")
PY_PATCH
cat > $D/p203test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p203test.py - PATCH 203: 🟠 OI - the important OI situations ring, managed (a made-up desk, nothing sent)"""
import os, sys, types, tempfile
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import scenarios as S, alertword, tglanes
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
SENT = []
desk = types.SimpleNamespace(shares={"COROX": {"chg": 2.4, "v": 1, "label": "BULLISH", "walls": {"roof": {"k": 1960, "away": 2.5}, "floor": {"k": 1880, "away": 1.7}}},
                                     "UPX": {"chg": 0.6, "v": 0, "walls": {"floor": {"k": 95, "away": 4.0}}}},
                             ban=set(), rs={}, last=None, spots={})
ag = S.Agent(desk, P={"tom": os.path.join(tempfile.mkdtemp(), "t.db")}, hooks={"tg_box": lambda t, **k: SENT.append(t), "log": lambda m: None})
ag.reset("2026-11-12")
rd = types.SimpleNamespace(t=1_000_000.0, hm="10:42")
def h(id_, side, line, spot):
    return {"id": id_, "side": side, "line": line, "spot": spot, "k1": None, "k2": None, "expiry_week": False}
ag.fire("COROX", h("roof_up", "CE", "the roof 1900 → 1960 (call OI 5.2 L at 1960, 1.1 L left at 1900)", 1912.0), rd, True)
ag.fire("COROX", h("fut_long_buildup", "CE", "price +2.4%, futures OI +4.1% (₹62 cr)", 1912.0), rd, True)
ag.flush_imp(rd)
print(SENT[0] if SENT else "-")
check("COROMANDEL-like: the roof moved up + the long build-up -> ONE 🟠 OI message", len(SENT) == 1 and "THE ROOF MOVED UP" in SENT[0] and "LONG BUILD-UP" in SENT[0])
check("... it says the room (the 1960 wall 2.5% away ⚠️) and the floor behind", SENT and "1960 = 2.5% away ⚠️" in SENT[0] and "the floor behind: 1880" in SENT[0])
rd2 = types.SimpleNamespace(t=rd.t + 600, hm="10:52")
ag.fire("COROX", h("floor_up", "CE", "the floor 1860 → 1880", 1915.0), rd2, True); ag.flush_imp(rd2)
check("10 min later, the same share and side: no second ring (on the page only)", len(SENT) == 1)
rd3 = types.SimpleNamespace(t=rd.t + 1900, hm="11:14")
ag.fire("COROX", h("call_short_covering", "CE", "1960 CE: OI 5.2 L → 3.1 L - writers buying back", 1930.0), rd3, True); ag.flush_imp(rd3)
check("31 min later: it rings again (the 1960 writers running)", len(SENT) == 2 and "CALL WRITERS RUNNING" in SENT[1])
ag.fire("UPX", h("roof_down", "PE", "the roof 105 → 100", 101.0), rd3, True); ag.flush_imp(rd3)
check("a PE situation while the share is UP: no ring", len(SENT) == 2)
check("not an important situation (max pain moved): no 🟠 OI", "maxpain_up" not in S.IMPORTANT)
check("🟠 OI rings (move), to the OI topic, through the Telegram gate", alertword.tier(SENT[0]) == "move" and tglanes.lane(SENT[0]) == "oi")
ag.imp_n = S.IMP_CAP
rd4 = types.SimpleNamespace(t=rd.t + 9000, hm="13:12")
ag.fire("COROX", h("roof_up", "CE", "the roof 1960 → 2000", 1955.0), rd4, True); ag.flush_imp(rd4)
check("after 40 in a day: no more rings (the page keeps them)", len(SENT) == 2)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 203"
python3 $W/p203_patch.py $D || back
cd $D && python3 -m py_compile scenarios.py alertword.py tglanes.py || back
echo "=== the test (a made-up desk - nothing sent)"
timeout 60 python3 $D/p203test.py > /tmp/p203test.out 2>&1; R=$?
grep -E "  ok|FAIL|PASSED" /tmp/p203test.out; [ $R = 0 ] || back
echo "=== restarting the engine and the senders"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
sleep 15
for s in gir-intraday gir-exchange gir-tvwatch; do echo "  $s: $(systemctl is-active $s)"; done
echo
echo "✅ patch 203 done. From tomorrow: 🟠 OI rings in GIR Live (OI topic) for the important OI situations, managed. Ctrl + Shift + R on the page."
