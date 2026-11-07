#!/bin/bash
# PATCH 79 - THE MONEY WITHIN 5 SECONDS (on top of patch 78). No new socket, no new app, no login spent.
#   · engine2.py: pins_live.json is written every 5 s from the socket ticks the engine already holds (ATM±N on GIR Live 2/3/4),
#     on its own thread (the REST chain sweep, 1.5-2 min a pass, used to pace it); the spot in it is the share's LIVE price
#     from the equity socket, not the last sweep's
#   · desk.py: reads it every 5 s (a reading older than 40 s is stale); the history of readings is kept by time (2 min in
#     full, one a minute before that, 30 min back) so the 15-minute window, the open+30 reference, the 5-minute confirmation
#     and the rules' windows are exactly what they were; the desk's own REST pull stays at once a minute; the results map
#     once a minute; a reading slower than 4 s is said in the log
#   Edits engine2.py desk.py in place (exact anchors). Installs p79test.py. Restarts gir-intraday, gir-desk.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g79; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p79.sh now"; exit 1; fi
grep -q "def ban_today" $D/engine2.py || { echo "patch 78 is not installed yet - paste patch 78 first"; exit 1; }
grep -q "def pins_loop" $D/engine2.py && { echo "patch 79 is already installed"; exit 1; }
F="engine2.py desk.py"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p79test.py; systemctl restart gir-intraday gir-desk; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p79_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p79_patch.py - PATCH 79: the engine writes pins_live.json every 5 s from the socket ticks (its own thread, the live
share price as the spot), the desk reads it every 5 s. The 15-minute window, the open+30 reference, the 5-minute
confirmation and the once-a-minute own pull stay exactly as they are. No new socket, no new app, no login spent.
Usage: python3 p79_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ engine2.py
# 1. pin_snap every 5 s, with the LIVE share price from the equity socket as the spot (lv.spot is the last REST sweep, 1.5-2 min old)
E("engine2.py", '''            def pin_snap():
                """every 60 s: pins_live.json - the last tick (time, OI, premium) on every pinned strike, so an audit can put
                GIR's number next to Kite's at the same second instead of a 15-minute-old snapshot"""
                if feed is None or not getattr(feed, "opt_pin", None) or time.time() - PIN.get("snap_at", 0.0) < 60:
                    return
                PIN["snap_at"] = time.time()
                try:
                    lt_ = feed.pin_latest(); out_ = {}
                    for tok_, (s_, label_, e_, k_, kd_) in list(feed.opt_pin.items()):
                        q_ = lt_.get(tok_)
                        if q_:
                            out_.setdefault(s_, []).append([e_, k_, kd_, q_[1], q_[2], int(q_[0])])
                    tmp_ = os.path.join(core.BASE, "pins_live.json.tmp")
                    with open(tmp_, "w") as fh_:
                        json.dump({"t": int(time.time()), "spot": {s_: lv.spot.get(s_) for s_ in out_}, "rows": out_}, fh_, separators=(",", ":"))
                    os.replace(tmp_, os.path.join(core.BASE, "pins_live.json"))
                except Exception as ex:
                    log("pins snap: %s" % str(ex)[:80])
''', '''            def live_spot(s_):
                """the share's last traded price from the equity socket (this second); the last REST sweep's spot when it has none"""
                i_ = getattr(feed, "pos", {}).get(s_)
                try:
                    if i_ is not None and np.isfinite(feed.ltp[i_]) and feed.ltp[i_] > 0:
                        return float(feed.ltp[i_])
                except Exception:
                    pass
                return lv.spot.get(s_)

            def pin_snap():
                """every 5 s: pins_live.json - the last tick (time, OI, premium) on every pinned strike and the live spot, so
                THE DESK reads the money within 5 s (its own thread below - the REST sweep must not pace it)"""
                if feed is None or not getattr(feed, "opt_pin", None) or time.time() - PIN.get("snap_at", 0.0) < 5:
                    return
                PIN["snap_at"] = time.time()
                try:
                    lt_ = feed.pin_latest(); out_ = {}
                    for tok_, (s_, label_, e_, k_, kd_) in list(feed.opt_pin.items()):
                        q_ = lt_.get(tok_)
                        if q_:
                            out_.setdefault(s_, []).append([e_, k_, kd_, q_[1], q_[2], int(q_[0])])
                    tmp_ = os.path.join(core.BASE, "pins_live.json.tmp")
                    with open(tmp_, "w") as fh_:
                        json.dump({"t": int(time.time()), "spot": {s_: live_spot(s_) for s_ in out_}, "rows": out_}, fh_, separators=(",", ":"))
                    os.replace(tmp_, os.path.join(core.BASE, "pins_live.json"))
                except Exception as ex:
                    log("pins snap: %s" % str(ex)[:80])

            def pins_loop():
                """the 5-second writer of pins_live.json, on its own thread (the sweep thread is busy 1.5-2 min per pass)"""
                while True:
                    time.sleep(1.0)
                    try:
                        if feed is None or not live or core.ist_now() > at(15, 40):
                            continue
                        pin_snap()
                    except Exception as ex:
                        log("pins loop: %s" % str(ex)[:80])
''')
E("engine2.py", '''            if not CH.get("ticks_thr"):
                CH["ticks_thr"] = True
                threading.Thread(target=focus_ticks_loop, daemon=True).start()''', '''            if not CH.get("ticks_thr"):
                CH["ticks_thr"] = True
                threading.Thread(target=focus_ticks_loop, daemon=True).start()
            if not CH.get("pins_thr"):
                CH["pins_thr"] = True
                threading.Thread(target=pins_loop, daemon=True).start()''')

# ============================================================ desk.py
E("desk.py", "the engine's sockets, every 60 s", "the engine's sockets, every 5 s")
# 2. a reading older than 40 s is stale (the engine writes every 5 s)
E("desk.py", "def read_engine(max_age=150):", "def read_engine(max_age=40):")
# 3. the history of readings is kept by TIME, not by count: every reading of the last 2 min, one a minute before that, 30 min back
E("desk.py", '''class OwnPull(object):''', '''def thin(rows, now, full=120, keep=1800):
    """readings come every 5 s: keep every one from the last `full` seconds, one per minute before that, nothing older
    than `keep` - so prev15 (14+ min old) and the rules' windows still find a reading, without 240 readings a share"""
    out, last_min = [], None
    for t, x in rows:
        age = now - t
        if age > keep:
            continue
        m = int(t // 60)
        if age <= full or m != last_min:
            out.append((t, x)); last_min = m
    return out


class OwnPull(object):''')
E("desk.py", '''        h = self.hist.setdefault(sym, [])
        h.append((rd.t, now))
        if len(h) > 25:
            del h[0]
        sh = self.spots.setdefault(sym, [])
        sh.append((rd.t, spot))
        if len(sh) > 25:
            del sh[0]''', '''        h = self.hist.setdefault(sym, [])
        h.append((rd.t, now))
        sh = self.spots.setdefault(sym, [])
        sh.append((rd.t, spot))
        if len(h) > 30 or len(sh) > 30:                         # readings every 5 s: 2 min in full, then one a minute, 30 min back
            self.hist[sym] = h = thin(h, rd.t)
            self.spots[sym] = sh = thin(sh, rd.t)''')
# 4. the results map (a DB pass) once a minute, not on every 5-s reading
E("desk.py", '''        self.lots = {}
        try:
            c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)''', '''        self.lots = {}
        self.rs, self.rs_at = {}, 0.0                            # exchange.results_map, refreshed once a minute
        try:
            c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)''')
E("desk.py", '''        if self.news:
            try:
                import exchange
                rs = exchange.results_map(40)
            except Exception:
                rs = {}
            try:
                self.reader.refresh(set(rd.ch), rs)''', '''        if self.news:
            if time.time() - self.rs_at >= 60:
                self.rs_at = time.time()
                try:
                    import exchange
                    self.rs = exchange.results_map(40)
                except Exception as ex:
                    log("results map: %s" % str(ex)[:80]); self.rs = self.rs or {}
            try:
                self.reader.refresh(set(rd.ch), self.rs)''')
# 5. the service loop: read every 5 s; the own REST pull stays once a minute; the same reading is not read twice; slow ticks are said
E("desk.py", '''    own = OwnPull()
    log("THE DESK up: %d sectors · normal OI known for %d shares" % (len(desk.map), len(desk.strikes.normal)))''', '''    own = OwnPull(); own_at = 0.0
    log("THE DESK up: %d sectors · normal OI known for %d shares · reading the engine's pins every 5 s" % (len(desk.map), len(desk.strikes.normal)))''')
E("desk.py", '''        rd = read_engine()
        why = ""
        if rd is None and (ses.get("special") or hm >= hm_add(ses["open"], 12)):   # a normal day: give the engine's pins 12 minutes first
            rd = own.read()
            why = own.why
        elif rd is None:
            why = "waiting for the engine's pins"
        if rd is None:
            write_state({"t": hm, "day": d, "session": ses, "closed": False, "sectors": [], "shares": {}, "scores": desk.scores(), "why": "no reading: engine pins stale and own pull: %s" % why})
            time.sleep(30); continue
        try:
            desk.tick(rd, ses)
            write_state(desk.state(rd, ses, why))
        except Exception as ex:
            import traceback; traceback.print_exc()
            log("tick: %s" % str(ex)[:120])
        time.sleep(max(5, 60 - (time.time() % 60)))''', '''        rd = read_engine()
        why = ""
        if rd is None and (ses.get("special") or hm >= hm_add(ses["open"], 12)):   # a normal day: give the engine's pins 12 minutes first
            if time.time() - own_at >= 60:                                           # the desk's own REST pull stays at once a minute
                own_at = time.time(); rd = own.read()
            why = own.why
        elif rd is None:
            why = "waiting for the engine's pins"
        if rd is None:
            write_state({"t": hm, "day": d, "session": ses, "closed": False, "sectors": [], "shares": {}, "scores": desk.scores(), "why": "no reading: engine pins stale and own pull: %s" % why})
            time.sleep(5); continue
        if desk.last is not None and rd.t == desk.last.t:                            # the same reading again: nothing new yet
            time.sleep(1); continue
        t0_ = time.time()
        try:
            desk.tick(rd, ses)
            write_state(desk.state(rd, ses, why))
        except Exception as ex:
            import traceback; traceback.print_exc()
            log("tick: %s" % str(ex)[:120])
        took_ = time.time() - t0_
        if took_ > 4:
            log("tick took %.1f s - the reading is every 5 s" % took_)
        time.sleep(max(0.5, 5 - (time.time() % 5)))''')


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
        print("p79: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p79: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p79test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p79test.py - the 5-second reading test (no network, nothing written to the live databases).
  1 thin(): 25 minutes of 5-s readings keep the last 2 min in full, one a minute before, nothing past 30 min - and a 14-min-old reading survives
  2 the desk through 20 minutes of 5-s readings: the history stays small, prev15 still finds a reading 14+ min old,
    the 5-minute confirmation still takes 5 minutes (60 readings), the auditor's result is the same as with 1-min readings
  3 read_engine: a 10-s-old file is a reading, a 50-s-old one is stale
  4 the engine has the 5-s writer on its own thread; the desk loop sleeps to the 5-s mark
"""
import os, sys, time, json, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core, desk

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


print("1. thin()")
now = 1_800_000_000
rows = [(now - 25 * 60 + 5 * i, i) for i in range(0, 25 * 12 + 1)]          # 25 min of 5-s readings, oldest first
k = desk.thin(rows, now)
ages = [now - t for t, _ in k]
check("300 readings -> under 60 kept (%d)" % len(k), len(k) < 60)
check("every reading of the last 2 min kept (%d)" % sum(1 for a in ages if a <= 120), sum(1 for a in ages if a <= 120) == 25)
check("one a minute before that", all(ages[i] - ages[i + 1] >= 55 for i in range(len(ages) - 25 - 1)))
check("a reading 14+ min old still there", any(a >= 14 * 60 for a in ages))
check("nothing older than 30 min", max(ages) <= 1800)
rows2 = [(now - 40 * 60 + 5 * i, i) for i in range(0, 40 * 12 + 1)]
check("40 min of readings -> oldest kept is 30 min", max(now - t for t, _ in desk.thin(rows2, now)) <= 1800)
check("order kept, newest last", k[-1][0] == now)

print("2. the desk on 5-s readings vs 1-min readings (UNOMINDA 1060 PE bought)")
tmp = tempfile.mkdtemp(prefix="p79")
desk.P.update({"out": os.path.join(tmp, "desk.json"), "scores": os.path.join(tmp, "desk_scores.json"), "newscache": os.path.join(tmp, "newsread.json"), "tom": os.path.join(tmp, "tomorrow.db"),
               "filings": os.path.join(tmp, "filings.db"), "news": os.path.join(tmp, "news.db")})


def ch(rows, exp="2026-11-25"):
    return {(exp, float(k), kd): (float(oi), float(p), 0) for k, kd, oi, p in rows}


u_ref = ch([(1040, "CE", 61000, 72), (1060, "CE", 88000, 60), (1080, "CE", 140000, 49), (1100, "CE", 210000, 39), (1120, "CE", 165000, 31), (1140, "CE", 120000, 24), (1160, "CE", 95000, 18),
            (1000, "PE", 90000, 9), (1020, "PE", 110000, 12), (1040, "PE", 130000, 16), (1060, "PE", 18000, 18), (1080, "PE", 150000, 28), (1100, "PE", 98000, 40)])
u_now = ch([(1040, "CE", 55000, 44), (1060, "CE", 52000, 33), (1080, "CE", 54000, 23), (1100, "CE", 82000, 15), (1120, "CE", 64000, 10), (1140, "CE", 70000, 6), (1160, "CE", 60000, 4),
            (1000, "PE", 92000, 14), (1020, "PE", 112000, 19), (1040, "PE", 133000, 25), (1060, "PE", 245000, 38), (1080, "PE", 152000, 46), (1100, "PE", 99000, 62)])
ses = {"open": "09:15", "close": "15:30", "name": "normal", "special": False}
T0 = int(core.ist_epoch(dt.datetime(2026, 11, 6, 9, 46)))


def run(step, label):
    d = desk.Desk(sectors_map={"auto-anc": ["UNOMINDA"]}, normal={"UNOMINDA": 6000}, big=1, fetch_ban=False, news=False)
    first_v2 = conf_at = None
    n = 0
    for t in range(T0, T0 + 20 * 60 + 1, step):                   # 09:46 -> 10:06: the reference chain for 10 min, then the bought puts
        chain = u_ref if t < T0 + 10 * 60 else u_now
        rd = desk.Reading(t, {"UNOMINDA": 1110.0 if t < T0 + 10 * 60 else 1101.0}, {"UNOMINDA": chain}, "test")
        sh = d.tick(rd, ses, tag="replay"); n += 1
        r = sh.get("UNOMINDA")
        if r and r["v"] == -2 and first_v2 is None:
            first_v2 = t
        if r and r["v"] == -2 and r["conf"] and conf_at is None:
            conf_at = t
    return d, first_v2, conf_at, n


d5, v5, c5, n5 = run(5, "5 s")
d60, v60, c60, n60 = run(60, "60 s")
h5 = d5.hist["UNOMINDA"]
check("5-s run: %d readings, history kept to %d entries" % (n5, len(h5)), n5 >= 240 and len(h5) <= 60)
check("5-s run: a reading 14+ min old is still in the history", any(T0 + 20 * 60 - t >= 14 * 60 for t, _ in h5))
check("both runs reach EXTREME BEARISH on UNOMINDA (5 s: %s · 60 s: %s)" % (v5 is not None, v60 is not None), v5 is not None and v60 is not None)
check("the 5-s run sees it no later than the 1-min run (%s vs %s)" % (v5, v60), v5 is not None and v60 is not None and v5 <= v60)
check("the 5-minute confirmation still takes 5 min on 5-s readings (%s s)" % (None if (c5 is None or v5 is None) else c5 - v5), c5 is not None and v5 is not None and 295 <= c5 - v5 <= 305)
check("same final meter and side on both (%s %s / %s %s)" % (d5.shares["UNOMINDA"]["v"], d5.shares["UNOMINDA"]["side"], d60.shares["UNOMINDA"]["v"], d60.shares["UNOMINDA"]["side"]),
      d5.shares["UNOMINDA"]["v"] == d60.shares["UNOMINDA"]["v"] == -2 and d5.shares["UNOMINDA"]["side"] == d60.shares["UNOMINDA"]["side"] == "PE")
a5, a60 = [k for k in d5.logged if k[3] == "auditor"], [k for k in d60.logged if k[3] == "auditor"]
check("the auditor's call is logged once per share and side, not once per reading (%d vs %d)" % (len(a5), len(a60)), len(a5) == len(a60) and 1 <= len(a5) <= 2)

print("3. read_engine freshness")
desk.BASE = tmp
json.dump({"t": int(time.time()) - 10, "spot": {"ABC": 100.0}, "rows": {"ABC": [["2026-11-25", 100, "CE", 30000, 5.0, int(time.time()) - 10]]}}, open(os.path.join(tmp, "pins_live.json"), "w"))
check("a 10-s-old pins_live.json is a reading", desk.read_engine() is not None)
json.dump({"t": int(time.time()) - 50, "spot": {}, "rows": {}}, open(os.path.join(tmp, "pins_live.json"), "w"))
check("a 50-s-old pins_live.json is stale", desk.read_engine() is None)

print("4. the code is in place")
here = os.path.dirname(os.path.abspath(__file__))
e2 = open(os.path.join(here, "engine2.py"), encoding="utf-8").read()
dk = open(os.path.join(here, "desk.py"), encoding="utf-8").read()
check("engine2: pins_loop thread and a 5-s pin_snap", "def pins_loop" in e2 and 'PIN.get("snap_at", 0.0) < 5' in e2 and "target=pins_loop" in e2)
check("engine2: the live socket price is the spot", "def live_spot" in e2 and '"spot": {s_: live_spot(s_) for s_ in out_}' in e2)
check("desk: the loop sleeps to the 5-s mark, own pull once a minute", "5 - (time.time() % 5)" in dk and "own_at >= 60" in dk)
check("desk: the results map once a minute", "self.rs_at >= 60" in dk)

print("\nP79 READING TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p79_patch.py $D || { rm -f $D/p79test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py desk.py p79test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the 5-second reading test (20 minutes of 5-s readings through the desk, no network):"
timeout 300 python3 p79test.py 2>&1 | grep "OK  \|FAIL\|READING TEST\|Traceback\|Error" | head -40
timeout 300 python3 p79test.py >/dev/null 2>&1 || { echo "the reading test failed"; back; }
echo "--- 3. the desk self-test and the gate test still pass:"
timeout 180 python3 desk.py --test 2>&1 | grep "FAIL\|SELF-TEST" | head -20
timeout 180 python3 desk.py --test >/dev/null 2>&1 || { echo "the desk self-test failed"; back; }
timeout 120 python3 p78test.py 2>&1 | grep "FAIL\|GATE TEST"
timeout 120 python3 p78test.py >/dev/null 2>&1 || { echo "the gate test failed"; back; }
systemctl restart gir-intraday gir-desk && sleep 8
echo "engine: $(systemctl is-active gir-intraday) · desk: $(systemctl is-active gir-desk)"
journalctl -u gir-intraday --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
journalctl -u gir-desk --since "-1min" --no-pager -o cat | grep -i "error\|traceback\|THE DESK up" | head -3
echo "PATCH 79 APPLIED - from the next session the desk reads the money every 5 s."
echo "  Monday after 09:20, check: ls -l --time-style=full-iso $D/pins_live.json (changes every 5 s) · journalctl -u gir-desk -f (no 'tick took' lines)"
