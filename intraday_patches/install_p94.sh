#!/bin/bash
# PATCH 94 - THE PHONE RINGS ONLY FOR WHAT MATTERS (Rama: "an alert which clearly says that something is happening, a trade
#   alert, and what F&O needs to know for the trading"). Box Picks, both senders (the engine + the newsroom, and the desk):
#     🔴 TRADE ALERT - act on it        a BUY by the house rule (measured 55%+ on 50+ cases, no agent against) · your trade · book it
#     🟠 SOMETHING IS HAPPENING          🚨 SUDDEN · ⚡ NEWS SHOCK · 🚀 RUNNING 3%+ · ⚡ SPEED on a 2%+ day · a BUY held in the open
#     📌 F&O - know this                 THE THREE · TOMORROW list · PRE-OPEN WATCH · your own rules · the day-cap notice
#   ring the phone, the tag as the 2nd line. EVERYTHING ELSE STILL REACHES BOX PICKS, SILENTLY (first moves, movers,
#   readings, scorecards, WATCH lines) - nothing is dropped. The page's ALERTS bar (patch 93) uses the same rule.
#   + the NOW list files RUNNING / SPEED / OPENING lines under the share (they were filed under "RUNNING").
#   engine2.py · desk.py (exact anchors) · new alertword.py. Installs p94test.py. Restarts gir-intraday, gir-desk, gir-newsroom.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g94; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p94.sh now"; exit 1; fi
grep -q "def surge_text" $D/engine2.py || { echo "patch 88 is not installed yet - paste patch 88 first"; exit 1; }
grep -q "import tgq" $D/desk.py || { echo "the desk has no sender queue (patch 80) - paste patch 80 first"; exit 1; }
grep -q "import alertword" $D/engine2.py && { echo "patch 94 is already installed"; exit 1; }
F="engine2.py desk.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/alertword.py $D/p94test.py; systemctl restart gir-intraday gir-desk; systemctl is-active --quiet gir-newsroom && systemctl restart gir-newsroom; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p94_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p94_patch.py - PATCH 94: THE PHONE RINGS ONLY FOR WHAT MATTERS. Both Box Picks senders (engine2.tg_fo - the engine, the
newsroom, the shock chain, the picks; desk.tg_box - SUDDEN, your rules, the OI scenarios) ask alertword.py: a TRADE ALERT,
SOMETHING IS HAPPENING or an F&O must-know rings the phone with its tag as the 2nd line; every other line still goes to Box
Picks, silently. And the NOW list stops filing RUNNING / SPEED / OPENING lines under a share called "RUNNING".
Usage: python3 p94_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


E("engine2.py", '''    import tgq                                                  # the sender queue: this thread never waits for Telegram
    tgq.send(tok, chat, text, on_ok=alert_log,''', '''    import tgq                                                  # the sender queue: this thread never waits for Telegram
    try:                                                        # patch 94: only a trade alert / something happening / an F&O must-know rings
        import alertword
        text, silent_ = alertword.dress(text)
    except Exception as ex:
        silent_ = False; log("alertword: %s" % str(ex)[:80])
    tgq.send(tok, chat, text, on_ok=alert_log, silent=silent_,''')
E("engine2.py", '''        first = text.strip().split("\\n")[0]
        m = re.search(r"\\b([A-Z][A-Z0-9&-]{2,}(?:-[A-Z]+)?)\\b", re.sub(r"\\b(CE|PE|BUY|SELL|WATCH|UP|DOWN|NOW|BOX|PICK|FIRST|MOVE|ORDER|BOOK|SUDDEN|WALL|FLIP|MOVER|RESULTS|YOUR|TRADE|NEWS|SHOCK|LOADING|TOMORROW|THE|THREE)\\b", "", first))''',
  '''        first = text.strip().split("\\n")[0]
        lines_ = text.strip().split("\\n")                    # patch 94: the alert's own head line, then the share after ▲ / ▼
        if first.startswith("🔔 OPENING · "):
            first = first[len("🔔 OPENING · "):]
        elif first.startswith("🔔 OPENING") and len(lines_) > 1:
            first = lines_[1]
        m = re.search(r"[▲▼]\\s*([A-Z][A-Z0-9&-]{1,}(?:-[A-Z]+)?)\\b", first) or re.search(r"\\b([A-Z][A-Z0-9&-]{2,}(?:-[A-Z]+)?)\\b", re.sub(r"\\b(CE|PE|BUY|SELL|WATCH|UP|DOWN|NOW|BOX|PICK|FIRST|MOVE|ORDER|BOOK|SUDDEN|WALL|FLIP|MOVER|RESULTS|YOUR|TRADE|NEWS|SHOCK|LOADING|TOMORROW|THE|THREE|RUNNING|SPEED|OPENING|BREAKING|EXTREME|PRE-OPEN|RULE|SCORECARD|CALLS|PUTS)\\b", "", first))''')
E("desk.py", '''    import tgq                                                  # the sender queue: the desk never waits for Telegram
    tgq.send(tok, chat, text, on_ok=_logged,''', '''    import tgq                                                  # the sender queue: the desk never waits for Telegram
    try:                                                        # patch 94: only a trade alert / something happening / an F&O must-know rings
        import alertword
        text, silent_ = alertword.dress(text)
    except Exception as ex:
        silent_ = False; log("alertword: %s" % str(ex)[:80])
    tgq.send(tok, chat, text, on_ok=_logged, silent=silent_,''')


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
        print("p94: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p94: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/alertword.py <<'PY_AW'
#!/usr/bin/env python3
"""alertword.py - WHICH Box Picks lines ring the phone (patch 94). Rama: "an alert which clearly says that something is
happening, a trade alert, and what F&O needs to know for the trading" - everything else still reaches Box Picks, SILENTLY.
  act  🔴 TRADE ALERT          a BUY by the house rule (measured 55%+ on 50+ cases, no agent against) · your trade · book it
  move 🟠 SOMETHING IS HAPPENING 🚨 SUDDEN (EXTREME, 5-min confirmed) · ⚡ NEWS SHOCK · 🚀 RUNNING 3%+ · ⚡ SPEED on a 2%+ day ·
                               a BUY held back in the opening 15 minutes
  know 📌 F&O                  THE THREE · TOMORROW list · PRE-OPEN WATCH · your own rules · the day-cap notice
  read (silent)                first moves, movers, readings, scorecards, wall lines that are WATCH ...
The page's ALERTS bar uses the same rule (home.html alertTier)."""
import re

TAG = {"act": "🔴 TRADE ALERT — act on it", "move": "🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR",
       "know": "📌 F&O — know this before you trade"}
KNOW = re.compile(r"^(🎯 THE THREE|🌙 TOMORROW ·|📋 PRE-OPEN|⚠ the day's|📜 YOUR RULE|ℹ️)")


def _head(L):
    """-> (opening?, the alert's head line, the lines under it). Two opening forms: the gate's note on its own line
    ("🔔 OPENING 09:21:04 — ...", the alert under it) and the scenario's prefix ("🔔 OPENING · 🧩 ... ")"""
    H = L[0]
    if H.startswith("🔔 OPENING · "):
        return True, H[len("🔔 OPENING · "):], L[1:]
    if H.startswith("🔔 OPENING") and len(L) > 1:
        return True, L[1], L[2:]
    return H.startswith("🔔 OPENING"), H, L[1:]


def tier(text):
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return "read"
    H, T = L[0], "\n".join(L)
    opening, H2, body = _head(L)
    k = H2.split()[0] if H2.split() else ""
    if KNOW.match(H2):
        return "know"
    if "NOT SENT" in T and "BUY" not in T:
        return "read"
    if k in ("💼", "🛑"):
        return "act"
    m = re.search(r"measured:\s*(\d+)%\s*right of\s*(\d+)", T)
    meas = bool(m and int(m.group(1)) >= 55 and int(m.group(2)) >= 50)
    buy_line = any(re.match(r"(▶\s*)?BUY\b", x.strip()) for x in body) or bool(re.search(r"—\s*BUY\b", H2))
    if not opening and "disagrees" not in T and not re.search(r"\bWATCH\b", T) and (buy_line or (k == "🚨" and meas)):
        return "act"
    if k == "🚨" or "NEWS SHOCK" in H2 or (opening and (buy_line or meas)):
        return "move"
    if "RUNNING" in H2:
        c = re.search(r"crossed\s*[+-](\d+)%", T)
        if c and int(c.group(1)) >= 3:
            return "move"
    if "SPEED" in H2:
        d = re.search(r"day\s*([+-]?\d+(?:\.\d+)?)%", H2)
        if d and abs(float(d.group(1))) >= 2:
            return "move"
    return "read"


def dress(text):
    """-> (text with the tag as its 2nd line when it rings, silent?). The 1st line stays as it was (the NOW list reads it)."""
    t = tier(text)
    if t == "read":
        return text, True
    if TAG[t] in text:
        return text, False
    L = text.split("\n")
    at = 2 if (L[0].startswith("🔔 OPENING") and not L[0].startswith("🔔 OPENING · ") and len(L) > 1) else 1   # under the alert's own head line
    return "\n".join(L[:at] + [TAG[t]] + L[at:]), False


if __name__ == "__main__":
    import sys
    s = sys.stdin.read()
    print(tier(s)); print(dress(s)[0])
PY_AW
cat > $D/p94test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p94test.py - the phone rings only for what matters (nothing is sent: Telegram is replaced by a recorder, the NOW list
goes to a scratch database).
  1 every real alert format -> TRADE ALERT / SOMETHING IS HAPPENING / F&O must-know (ring) or silent
  2 the tag is the 2nd line, the 1st line untouched; a silent line keeps its text
  3 both senders (engine2.tg_fo and desk.tg_box) ring or stay silent by the rule, and every line still reaches Box Picks
  4 the NOW list files RUNNING / SPEED / OPENING lines under the share, not under "RUNNING\""""
import os, sys, tempfile, sqlite3, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alertword
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


C = [("🚨 SUDDEN GLENMARK ₹2625 +5.8% · 12:52 · pharma\nEXTREME BULLISH → CE\n▶ 2640 CE ₹75.2 · stop: a close under 2600\nauditor: confirmed over 5 min · desk rule measured: 71% right of 58", "act"),
     ("🚨 SUDDEN X ₹100 +3%\n▶ 100 CE ₹4\nauditor: confirmed over 5 min · desk rule measured: not yet", "move"),
     ("🎯 BOX PICK ▼ UNOMINDA BREAKDOWN\nBUY 1100 PE at about ₹46\nrule measured: 61% right of 84", "act"),
     ("🎯 BOX PICK ▼ X\nWATCH 1100 PE at about ₹46\nrule measured: 51% right of 84", "read"),
     ("🧩 PUTS BOUGHT ▼ XYZCO ₹100 -2.1% · 11:02\n▶ BUY: 100 PE ₹4 · stop\nrule measured: 60% right of 70\n⚠ NEWS disagrees — your call, size small", "read"),
     ("💼 YOUR TRADE GLENMARK 2600 CE (bought ₹64)\nthe share reached the roof — book half", "act"),
     ("🛑 PIIND: the money turned — book the profit on the PE", "act"),
     ("⚡ NEWS SHOCK ▼ PIIND -9.2% today\n▶ WATCH: PE 3300 ~₹118", "move"),
     ("🚀 RUNNING ▲ YESBANK ₹24.7 +3.1% · 11:42\ncrossed +3% — from +2% in 9 min\nWATCH — not a trade by itself", "move"),
     ("🚀 RUNNING ▲ YESBANK ₹24.5 +2.1% · 11:33\ncrossed +2% — from the open\nWATCH — not a trade by itself", "read"),
     ("⚡ SPEED ▲ SAIL ₹101.2 +1.2% in 5 min · day +2.6% · 12:05\nvolume 5.0x\nWATCH", "move"),
     ("⚡ SPEED ▲ SAIL ₹101.2 +1.2% in 5 min · day +1.4% · 12:05\nvolume 5.0x\nWATCH", "read"),
     ("⚡ FIRST MOVE ▲ HINDALCO ₹712 +0.6% in 48 s\nWATCH — not a trade yet\nfirst-move rule measured: 58% right of 60", "read"),
     ("📈 MOVER ▲ YESBANK ₹24.3 +4.9%\n▶ WATCH: CE 25 ~₹0.6\nrule measured: not yet (new rule)", "read"),
     ("🔔 OPENING 09:21:04 — the first 15 minutes are noisy: WATCH, not a trade yet\n🧩 CALLS BOUGHT ▲ XYZCO ₹100\n▶ WATCH: 100 CE ₹4\nrule measured: 60% right of 70", "move"),
     ("🔔 OPENING 09:18:00 — the first 15 minutes are noisy: WATCH, not a trade yet\n⚡ FIRST MOVE ▲ X ₹100 +0.5%\nWATCH", "read"),
     ("🔔 OPENING · 🧩 CALLS BOUGHT ▲ XYZCO ₹100 +1.1% · 09:22\n100 CE: OI 0.1 L → 0.9 L\n▶ WATCH: 100 CE ₹4\nrule measured: 60% right of 70", "move"),
     ("🎯 THE THREE · Mon 10 Nov 18:30 — for tomorrow\n1 ▲ GLENMARK ₹2625\n   BUY — roof broken", "know"),
     ("🌙 TOMORROW · 14:30 — buy now, SELL BY 09:30 tomorrow\n▲ MAHABANK 86 CE ₹2.33", "know"),
     ("📒 TOMORROW SCORECARD · the 2026-11-06 list → 09:35 today\n▲ X box · share +1.2% your way ✅\n3 of 5 right", "read"),
     ("📋 PRE-OPEN WATCH 09:09 — overnight company news + pre-open price", "know"),
     ("📜 YOUR RULE \"puts bought\" · UNOMINDA ₹1101 -3.4% · 12:40\n1060 PE: OI 0.18 L → 2.45 L", "know"),
     ("⚠ the day's 12 actionable alerts are spent — from now the picks stay on the home page", "know"),
     ("🧱 WALL FLIP SAIL ₹128.4 +3.1%\n▶ BUY: 130 CE ₹2.4 · stop: a close under 125\nrule measured: 64% right of 52", "act")]
print("1. which lines ring")
for t, want in C:
    got = alertword.tier(t)
    check("%-5s %s" % (got, t.split("\n")[0][:70]), got == want)

print("2. the words on the phone")
d, sil = alertword.dress(C[0][0])
check("a TRADE ALERT rings, its tag is the 2nd line, the 1st line is untouched", not sil and d.split("\n")[1] == alertword.TAG["act"] and d.split("\n")[0] == C[0][0].split("\n")[0])
d, sil = alertword.dress(C[8][0])
check("RUNNING +3%% rings as SOMETHING IS HAPPENING", not sil and d.split("\n")[1].startswith("🟠 SOMETHING IS HAPPENING"))
d, sil = alertword.dress(C[12][0])
check("a FIRST MOVE goes silently, its text unchanged", sil and d == C[12][0])
check("dressing twice adds no second tag", alertword.dress(alertword.dress(C[0][0])[0])[0].count("TRADE ALERT") == 1)
check("the tags never say BUY or WATCH (the page reads those words)", not any(w in v for v in alertword.TAG.values() for w in ("BUY", "WATCH")))

print("3. both senders")
import tgq
SENT = []
tgq.send = lambda tok, chat, text, on_ok=None, on_fail=None, silent=False: (SENT.append((text, silent)), on_ok and on_ok(text), True)[-1]
tmp = tempfile.mkdtemp()
os.environ["TELEGRAM_TOKEN"] = "TEST"; os.environ["TG_CHAT_BOX"] = "TEST"
import core
core.BASE = tmp
import engine2
engine2._TGFO.update({"at": time.time() + 9e9, "chat": "TEST"})
for t, want in C:
    engine2.tg_fo(t)
r_ = [s for _, s in SENT]
check("engine2.tg_fo: %d lines, %d ring, %d silent - every line still reaches Box Picks" % (len(SENT), r_.count(False), r_.count(True)),
      len(SENT) == len(C) and [not s for s in r_] == [w != "read" for _, w in C])
import desk
desk.P["tom"] = os.path.join(tmp, "tomorrow.db")
n0 = len(SENT)
desk.tg_box(C[0][0]); desk.tg_box(next(t for t, _ in C if t.startswith("📜"))); desk.tg_box(C[3][0])
check("desk.tg_box: SUDDEN rings, YOUR RULE rings, a WATCH box pick is silent", [s for _, s in SENT[n0:]] == [False, False, True])

print("4. the NOW list")
c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
rows = c.execute("select sym, text from alerts").fetchall(); c.close()
syms = {t.split("\n")[0][:20]: s for s, t in rows}
check("RUNNING / SPEED / OPENING lines are filed under the share: %s" % sorted(set(s for s, _ in rows if s))[:12],
      not any(s in ("RUNNING", "SPEED", "OPENING", "SCORECARD", "RULE", "SOMETHING", "TRADE", "ALERT", "PUTS", "CALLS", "BOUGHT") for s, _ in rows) and any(s == "YESBANK" for s, _ in rows) and any(s == "SAIL" for s, _ in rows))
op = [t for _, t in rows if t.startswith("🔔 OPENING 09:21")]
check("an opening alert: the note, then the alert, then the tag", op and op[0].split("\n")[1].startswith("🧩") and op[0].split("\n")[2].startswith("🟠"))
check("the TRADE ALERT tag is on the page too (the NOW list keeps the phone's text)", any(alertword.TAG["act"] in t for _, t in rows))
print("\nP94 PHONE RINGS ONLY FOR WHAT MATTERS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits:"
python3 $W/p94_patch.py $D || { rm -f $D/alertword.py $D/p94test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py desk.py alertword.py p94test.py || back
echo "--- 2. the tests (nothing is sent - Telegram is replaced by a recorder):"
timeout 300 python3 p94test.py 2>&1 | grep "OK  \|FAIL\|MATTERS TEST"
timeout 300 python3 p94test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p78test.py p80test.py p88test.py p93test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-intraday gir-desk && sleep 10
systemctl is-active --quiet gir-newsroom && systemctl restart gir-newsroom
echo "engine: $(systemctl is-active gir-intraday) · desk: $(systemctl is-active gir-desk) · newsroom: $(systemctl is-active gir-newsroom)"
[ "$(systemctl is-active gir-intraday)" = "active" ] && [ "$(systemctl is-active gir-desk)" = "active" ] || { echo "a service did not come back"; back; }
journalctl -u gir-intraday -u gir-desk --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
echo "PATCH 94 APPLIED - from the next alert: 🔴 TRADE ALERT / 🟠 SOMETHING IS HAPPENING / 📌 F&O ring the phone;"
echo "  every other line still comes to Box Picks, silently."
