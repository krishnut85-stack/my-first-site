#!/bin/bash
# PATCH 153 - 🟥 GIR TRADE NOW: the trade calls (⚡ ENTER NOW · 🌅 OPENING CALL GO · ❌ FAILED · 💼 your trade · 🛑 your stop) go to their own
#   Telegram channel once it is set; nothing else goes there. Until then they stay in Box Picks. tglanes.py + tg_tradenow_setup.py.
#   No restart needed (the engine reads the channel setting every minute) - safe any time.
#   Then:  python3 /home/globalbot/intraday/tg_tradenow_setup.py @gir_tradenow
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g153; mkdir -p $W
grep -q "patch 153" $D/tglanes.py && { echo "patch 153 is already installed"; exit 1; }
cp $D/tglanes.py $D/tglanes.py.bak$TS
cat > $W/p153_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p153_patch.py - PATCH 153: 🟥 GIR TRADE NOW - THE TRADE CALLS IN THEIR OWN TELEGRAM CHANNEL (Rama, 9 Nov: "every alert comes the same; the
COCHINSHIP one was really important and I nearly missed it"). Once TG_CHAT_TRADENOW is set (tg_tradenow_setup.py), these go there and
nowhere else: ⚡ ENTER NOW · 🌅 OPENING CALL · GO · CONFIRMED · ❌ OPENING CALL FAILED · 💼 YOUR TRADE · 🛑 your stop. Give that channel its
own loud ringtone in Telegram. Everything else stays where it is (Box Picks, the group's topics). Not set = Box Picks, as today.
Usage: python3 p153_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
A = '''def chat_for(text, box_chat):
    """the chat for this alert: critical -> GIR Box Picks; the rest -> its topic of the GIR group ("group:topic") when the
    group is set up, else its channel (GIR OI / GIR Moves & News), else GIR Box Picks"""
    ln = lane(text)'''
B = '''def trade_now(text):
    """patch 153: a trade call - ⚡ ENTER NOW · 🌅 OPENING CALL (GO) · ❌ OPENING CALL FAILED · 💼 your trade · 🛑 your stop"""
    try:
        import alertword
        L = [x for x in (text or "").split("\\n") if x.strip()]
        _o, H2, _b = alertword._head(L) if L else (False, "", [])
    except Exception:
        H2 = (text or "").split("\\n")[0]
    k = H2.split()[0] if H2.split() else ""
    return H2.startswith("⚡ ENTER NOW") or H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2 or k in ("💼", "🛑")


def chat_for(text, box_chat):
    """the chat for this alert: critical -> GIR Box Picks; the rest -> its topic of the GIR group ("group:topic") when the
    group is set up, else its channel (GIR OI / GIR Moves & News), else GIR Box Picks"""
    tn = _get("TG_CHAT_TRADENOW")                                # patch 153: the trade calls in their own loud channel
    if tn and trade_now(text):
        return tn
    ln = lane(text)'''
p = os.path.join(D, "tglanes.py")
s = open(p, encoding="utf-8").read()
if "patch 153" in s:
    print("patch 153 is already in tglanes.py"); sys.exit(1)
if s.count(A) != 1:
    print("ANCHOR: chat_for"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(A, B))
print("patched: tglanes.py")
PY_PATCH
cat > $D/p153test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p153test.py - patch 153: the trade calls go to TG_CHAT_TRADENOW when it is set; nothing else does"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tglanes as T
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
env = {"TG_CHAT_TRADENOW": "-100777"}
T._get = lambda k: env.get(k)
for t, want in (("⚡ ENTER NOW ▲ PNB CE · ₹127.40", True), ("🌅 OPENING CALL ▲ EICHERMOT CE · GO · CONFIRMED 09:20 · x", True),
                ("❌ OPENING CALL FAILED ▼ EICHERMOT CE · ₹7,480", True), ("💼 YOUR TRADE PNB CE 130", True),
                ("🚨 CRITICAL RESULTS ▲ BHEL · BIG BEAT", False), ("🔄 MARKET ROTATION · money into PSU BANKS", False), ("📰 NEWS ▲ BHEL · x", False),
                ("📋 OPENING CALL 09:12 · 3 wait for 09:20", False), ("📋 TRIAL ENTRY ▲ X CE", False)):
    check("%s -> %s" % (t[:40], "TRADE NOW" if want else "as before"), (T.chat_for(t, "-100BOX") == "-100777") == want)
env.clear()
check("not set -> the trade calls stay in Box Picks", T.chat_for("⚡ ENTER NOW ▲ PNB CE", "-100BOX") == "-100BOX")
print("P153 TRADE NOW CHANNEL TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p153_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile tglanes.py && for t in p153test.py p143test.py p142test.py p151test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; cp $D/tglanes.py.bak$TS $D/tglanes.py; echo "old file back"; exit 1; }; }; done
sed -e 's/^KEY = "TG_CHAT_BOX"/KEY = "TG_CHAT_TRADENOW"/' -e 's/"GIR Box Picks"/"GIR Trade Now"/g' -e 's/gir_boxpicks/gir_tradenow/g' -e 's/tg_box_setup.py/tg_tradenow_setup.py/g' \
    -e 's/send the GIR box alerts (🎯 BOX PICK · 💼 YOUR TRADE · ⚡ BREAKING NOW) to their OWN Telegram channel/send the TRADE CALLS (⚡ ENTER NOW · 🌅 OPENING CALL · ❌ FAILED · 💼 · 🛑) to their OWN loud channel/' \
    $D/tg_box_setup.py > $D/tg_tradenow_setup.py
grep -q 'KEY = "TG_CHAT_TRADENOW"' $D/tg_tradenow_setup.py && echo "    tg_tradenow_setup.py ready" || echo "    could not make tg_tradenow_setup.py - send this to Claude"
echo
echo "PATCH 153 APPLIED. Now: make the Telegram channel (see Claude's steps), then:"
echo "   python3 $D/tg_tradenow_setup.py @gir_tradenow"
