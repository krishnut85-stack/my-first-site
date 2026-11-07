#!/bin/bash
# PATCH 87 - OPEN TO CLOSE (on top of patch 84). The agents watch and alert from the first minute to the last:
#   · ⚡ FIRST MOVE and 📗 ORDER BOOK from 09:16 (one minute of ticks), were 09:30
#   · 09:16-09:29 every line goes to the page and Telegram at once, tagged 🔔 OPENING, with BUY turned to WATCH (the first
#     15 minutes are noisy: you see it, you are told it is not a trade yet); nothing in the pre-open
#   · ⚡ NEWS SHOCK from 09:16, 📈 MOVER from 09:20, ⚡ BREAKING NOW from 09:30 - all to 15:25 (were 15:00 / 15:15)
#   · 📜 YOUR RULES and 🧩 the OI SCENARIOS from 09:20 (open + 5); scenarios before 09:45 are tagged OPENING and read only
#   · 🚨 SUDDEN, your rules and the scenarios run to 15:28 (close - 2), were 15:18; the scenario digest every 15 s, was 60 s
#   The desk's OI meter keeps its rule (no OI call before open + 30). Restarts gir-intraday and gir-desk.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g87; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p87.sh now"; exit 1; fi
grep -q "import scenarios" $D/desk.py || { echo "patch 84 is not installed yet - paste patch 84 first"; exit 1; }
grep -q "the first 15 minutes are noisy: WATCH" $D/engine2.py && { echo "patch 87 is already installed"; exit 1; }
F="engine.py engine2.py desk.py scenarios.py p78test.py fmtest.py"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-intraday gir-desk; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p87_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p87_patch.py - PATCH 87: OPEN TO CLOSE. The agents watch and alert from the first minute of the session to the last.
  · FIRST MOVE + ORDER BOOK (the tick agents): from 09:16 (one minute of ticks), was 09:30
  · the Box Picks gate: from 09:16; 09:16-09:29 every line goes out tagged OPENING with BUY turned to WATCH (the first
    15 minutes are noisy - you see it at once, you are told it is not a trade yet); nothing before 09:16 (pre-open)
  · NEWS SHOCK from 09:16 (a gap shock is news at the open), MOVER from 09:20, all of them to 15:25 (were 15:00 / 15:15)
  · YOUR RULES and the OI SCENARIOS from open + 5 (09:20; the first 5 minutes are the reference) - before open + 30
    the scenarios are tagged OPENING and read only (no Box Picks); the SUDDEN lane, the scenarios and your rules run to
    close - 2 (15:28), were close - 12
  · the scenario digest to GIR Intraday every 15 s (was 60 s)
  The desk's own OI meter keeps its rule (no OI call before open + 30) - SUDDEN still needs it.
Usage: python3 p87_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ engine.py: the tick agents from the first minute
E("engine.py", '''        self.fm_after = 900                            # not in the first 15 minutes of the day (the open is STOCKS IN PLAY's job)''',
  '''        self.fm_after = 60                             # from 09:16: one minute of ticks first (patch 87; the gate tags 09:16-09:29 OPENING)''')

# ============================================================ engine2.py: the gate and the lanes, open to close
E("engine2.py", '''    if now__.strftime("%H:%M") < "09:30":
        log("gate: before 09:30 (STOCKS IN PLAY's time), held: %s %s %s" % key); return False''',
  '''    if now__.strftime("%H:%M") < "09:16":
        log("gate: pre-open, held: %s %s %s" % key); return False
    if now__.strftime("%H:%M") < "09:30":                # the first 15 minutes: alert at once, but as WATCH - the open is noisy
        text = "🔔 OPENING %s — the first 15 minutes are noisy: WATCH, not a trade yet\\n%s" % (now__.strftime("%H:%M:%S"), text.replace("▶ BUY:", "▶ WATCH:").replace("\\nBUY ", "\\nWATCH "))''')
E("engine2.py", '''if not ("09:30" <= hm_ <= "15:15") or not live:''', '''if not ("09:16" <= hm_ <= "15:25") or not live:''')
E("engine2.py", '''if (s_, side_) not in mv_ and "09:35" <= hm_ <= "15:00":''', '''if (s_, side_) not in mv_ and "09:20" <= hm_ <= "15:25":''')
E("engine2.py", '''                if not ("09:35" <= hm_ <= "15:00") or not live:''', '''                if not ("09:30" <= hm_ <= "15:25") or not live:''')

# ============================================================ desk.py: your rules and SUDDEN to the close
E("desk.py", '''        if not self.rules or rd.hm < ref_hm:''', '''        if not self.rules or rd.hm < hm_add(ses["open"], 5):         # from open + 5 (patch 87)''')
E("desk.py", '''        if not (ref_hm <= rd.hm <= hm_add(ses["close"], -12)):''', '''        if not (ref_hm <= rd.hm <= hm_add(ses["close"], -2)):''')

# ============================================================ scenarios.py: from open + 5, tagged OPENING until open + 30
E("scenarios.py", '''        if rd.hm < ref_hm or not spot:
            self.cur[sym] = []
            return []''', '''        self.ref_hm = ref_hm
        if rd.hm < self.early(ref_hm) or not spot:               # from open + 5 (open + 30 minus 25 min)
            self.cur[sym] = []
            return []''')
E("scenarios.py", '''    # -- the lane: hold -> gates -> words -> the channel''', '''    @staticmethod
    def early(ref_hm):
        """open + 5: the reference time (open + 30) minus 25 minutes"""
        h, m = int(ref_hm[:2]), int(ref_hm[3:5])
        t = max(0, h * 60 + m - 25)
        return "%02d:%02d" % (t // 60, t % 60)

    # -- the lane: hold -> gates -> words -> the channel''')
E("scenarios.py", '''        close_by = hm_add(ses["close"], -12) if hm_add else "15:18"
        if not (ref_hm <= rd.hm <= close_by):''', '''        close_by = hm_add(ses["close"], -2) if hm_add else "15:28"
        if not (self.early(ref_hm) <= rd.hm <= close_by):''')
E("scenarios.py", '''        acting = bool(cat["acts"] and side)''', '''        acting = bool(cat["acts"] and side)
        opening = rd.hm < getattr(self, "ref_hm", "00:00")
        if opening and acting:
            acting = False                                       # before open + 30: a reading, not a Box Pick''')
E("scenarios.py", '''        L1 = "🧩 %s %s %s ₹%g%s · %s" % (cat["name"]''', '''        L1 = ("🔔 OPENING · " if opening else "") + "🧩 %s %s %s ₹%g%s · %s" % (cat["name"]''')
E("scenarios.py", '''rd.t - self.digest_at >= 60):''', '''rd.t - self.digest_at >= 15):''')
E("scenarios.py", '''    rd = R(T0 - 3600, "09:35", {"EEE": xch}, {"EEE": sp})
    check("before 09:45 (open+30) nothing is read",''', '''    rd = R(T0 - 3600, "09:12", {"EEE": xch}, {"EEE": sp})
    check("before 09:20 (open + 5) nothing is read",''')

# ============================================================ the tests learn the new times
E("p78test.py", '''check("09:25: a BOX PICK is held", _gate("pick", "GLENMARK", "CE", "🎯 BOX PICK test") is False and not SENT)
check("09:25: a FIRST MOVE is held too", _gate("firstmove", "GLENMARK", "CE", "⚡ FIRST MOVE test", exempt=True) is False and not SENT)''',
  '''clock("09:12")
check("09:12 (pre-open): a BOX PICK is held", _gate("pick", "GLENMARK", "CE", "🎯 BOX PICK test") is False and not SENT)
clock("09:25")
check("09:25 (the opening): a FIRST MOVE goes at once, tagged OPENING, BUY turned to WATCH", _gate("firstmove", "GLENMARK", "CE", "⚡ FIRST MOVE test\\n▶ BUY: 2600 CE", exempt=True) is True and SENT and SENT[-1].startswith("🔔 OPENING") and "▶ WATCH:" in SENT[-1] and "▶ BUY:" not in SENT[-1])
SENT[:] = []; LOGGED[:] = []; engine2._GATE["sent"].clear()''')
E("fmtest.py", '''# first 15 minutes of the day: nothing fires
g = engine.WsFeed(["YESBANK"], {"YESBANK": 111}, real_time() - 60); g.vnorm = np.full((2, 75), 20000.0)
for k in range(15):''', '''# the first minute of the day: nothing fires (one minute of ticks first)
g = engine.WsFeed(["YESBANK"], {"YESBANK": 111}, real_time()); g.vnorm = np.full((2, 75), 20000.0)
for k in range(11):''')


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
        print("p87: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p87: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p87_patch.py $D || { echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine.py engine2.py desk.py scenarios.py p78test.py fmtest.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. every test with the new times:"
timeout 120 python3 p78test.py 2>&1 | grep "09:12\|09:25\|GATE TEST"
timeout 120 python3 fmtest.py 2>&1 | tail -1
for t in "p78test.py" "fmtest.py" "scenarios.py --test" "p84test.py" "p79test.py" "p80test.py"; do timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; done
timeout 300 python3 desk.py --test >/dev/null 2>&1 && echo "    desk self-test passed" || { echo "the desk self-test failed"; back; }
systemctl restart gir-intraday gir-desk && sleep 8
echo "engine: $(systemctl is-active gir-intraday) · desk: $(systemctl is-active gir-desk)"
journalctl -u gir-intraday --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
journalctl -u gir-desk --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
echo "PATCH 87 APPLIED - from the next session the agents alert from 09:16 (tagged OPENING until 09:30) to 15:28."
