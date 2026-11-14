#!/bin/bash
# PATCH 88 - 🚀 RUNNING: no running share slips past (on top of patch 80; best after 87). Two tick agents inside the engine:
#   · STEP: every whole 1% a share crosses from 2% on, either way (+2 +3 +4 +5 +6 ... / -2 -3 ...), the SECOND it crosses -
#     with how fast it came from the last step, the volume behind it, and what drives it: the futures build-up and the
#     latest news, or "no news found: this is money". YESBANK 6 Nov (+2% -> +6% in a staircase) is exactly this.
#   · SPEED: 1%+ in the last 5 minutes on 3x+ the share's normal volume, any time of the day (the staircase FIRST MOVE misses:
#     FIRST MOVE needs 0.4% inside 60 s on 4x volume at a new day high)
#   · never held by the day's cap; on the page (NOW) and GIR Box Picks the same second (WATCH: it tells you something is
#     driving the share; the desk and the OI confirm); every fire scored 30 min later -> the rule's own number
#   engine.py engine2.py (exact anchors). Installs p88test.py. Restarts gir-intraday.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g88; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p88.sh now"; exit 1; fi
grep -q "import tgq" $D/engine2.py || { echo "patch 80 is not installed yet - paste patches 78-80 first"; exit 1; }
grep -q "def surge_text" $D/engine2.py && { echo "patch 88 is already installed"; exit 1; }
F="engine.py engine2.py"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p88test.py; systemctl restart gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p88_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p88_patch.py - PATCH 88: 🚀 RUNNING - no running share slips past. Two tick agents inside the engine's own feed:
  · STEP: every whole 1% a share crosses from 2% on, either way (+2, +3, +4, +5, +6 ... / -2, -3 ...): the second it
    crosses, with how fast it came from the last step, the volume behind it, and what drives it (the futures build-up,
    the latest news - or "no news found: this is money")
  · SPEED: 1%+ in the last 5 minutes on 3x+ the share's normal volume, any time of the day (a staircase FIRST MOVE misses)
Both exempt from the day's cap, every fire scored 30 min later (did it go a further 0.5% that way?) -> the rule's number.
Usage: python3 p88_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ engine.py: the tick agents
E("engine.py", '''        self.book_moves = collections.deque()          # (epoch, sym, side, price, tb, ts, x, pclose)''',
  '''        self.book_moves = collections.deque()          # (epoch, sym, side, price, tb, ts, x, pclose)
        # 🚀 RUNNING (patch 88): every whole 1% crossed from 2% on, and 1% in 5 min on 3x volume - on the tick
        self.run_step = {}                             # (i, sign) -> the highest step alerted today
        self.run_at = {}                               # (i, sign) -> epoch of the last step (how fast the next one came)
        self.run_ring = {}                             # i -> deque of (epoch, price, cum volume), one per 5 s, 10 min
        self.vel_fired = {}                            # (i, sign) -> epoch of the last SPEED fire (15-min cool-off)
        self.surges = collections.deque()              # (epoch, sym, kind, side, day chg %, step or 5-min move %, secs, x volume, price, pclose)''')
E("engine.py", '''    def book_check(self, i, now, tb, ts, p):''', '''    def running(self, i, now, p, cum):
        """🚀 on every trade tick of share i: STEP (each whole 1% crossed from 2% on, either way) and SPEED (1%+ in 5 min on
        3x+ the normal volume) -> feed.surges; the engine's sender puts them on the page and Telegram the same second"""
        if self.fo_idx and i not in self.fo_idx:
            return
        pc = self.pclose[i]
        if not p or not np.isfinite(pc) or pc <= 0:
            return
        rg = self.run_ring.get(i)
        if rg is None:
            rg = self.run_ring[i] = collections.deque()
        fresh = not rg or now - rg[-1][0] >= 5
        if fresh:
            rg.append((now, p, cum))
            while rg and now - rg[0][0] > 600:
                rg.popleft()
        if now - self.t0 < self.fm_after:
            return
        chg = (p / pc - 1) * 100
        sg = 1 if chg > 0 else -1
        step = int(abs(chg))
        if step >= 2 and step > self.run_step.get((i, sg), 1):
            self.run_step[(i, sg)] = step
            prev = self.run_at.get((i, sg))
            self.run_at[(i, sg)] = now
            self.surges.append((now, self.syms[i], "step", "CE" if sg > 0 else "PE", chg, step, (now - prev) if prev else None, self.run_xvol(i, now, cum, rg), p, float(pc)))
            self.fm_event.set()
        if not fresh:
            return
        old = None
        for e in rg:
            if now - e[0] >= 300:
                old = e
            else:
                break
        if old and old[1] > 0 and cum > old[2]:
            mv = (p / old[1] - 1) * 100
            if abs(mv) >= 1.0:
                s2 = 1 if mv > 0 else -1
                x = self.run_xvol(i, now, cum, rg, old)
                if x is not None and x >= 3 and now - self.vel_fired.get((i, s2), 0) >= 900:
                    self.vel_fired[(i, s2)] = now
                    self.surges.append((now, self.syms[i], "speed", "CE" if s2 > 0 else "PE", chg, round(mv, 2), now - old[0], x, p, float(pc)))
                    self.fm_event.set()

    def run_xvol(self, i, now, cum, rg, old=None):
        """the volume of the last ~5 minutes as a multiple of the share's normal for this time of day"""
        if self.vnorm is None or i >= len(self.vnorm):
            return None
        if old is None:
            old = next((e for e in rg if now - e[0] <= 300), None)
        if not old or cum <= old[2]:
            return None
        slot = min(74, max(0, int((now - self.t0) // 300)))
        vn = self.vnorm[i, slot]
        if not vn or not np.isfinite(vn) or vn <= 0:
            return None
        return round((cum - old[2]) / (vn * max(30.0, now - old[0]) / 60.0), 1)

    def book_check(self, i, now, tb, ts, p):''')
E("engine.py", '''                    self.first_move(i, now, p, cum, p >= self.dh[i], p <= self.dl[i])
''', '''                    self.first_move(i, now, p, cum, p >= self.dh[i], p <= self.dl[i])
                    self.running(i, now, p, cum)
''')

# ============================================================ engine2.py: the sender, the words, the store, the score
E("engine2.py", '''    c.execute("create table if not exists book_moves(''', '''    c.execute("create table if not exists surges(day text, t text, sym text, kind text, side text, px real, chg real, step real, x real, p30 real, primary key(day, t, sym, kind, side))")
    c.execute("create table if not exists book_moves(''')
E("engine2.py", '''def first_move_sender(feed):''', '''def drivers(sym):
    """what is driving a running share, from what the server already holds: the futures build-up (the engine's state, written
    every second) and the latest audited news on it (the newsroom)"""
    money = news = ""
    try:
        st = json.load(open(os.path.join(core.BASE, "dash_state.json")))
        f = next((x for x in (st.get("fo_paths") or []) if x.get("s") == sym), None)
        if f and f.get("bu"):
            money = "futures: %s ₹%.0f cr (OI %+.1f%%)" % (str(f["bu"]).lower().replace("_", " "), abs(float(f.get("cr") or 0)), float(f.get("oi") or 0))
    except Exception:
        pass
    try:
        import newsroom
        it = next(iter(newsroom.items_for(sym, 24, 0)), None)
        if it:
            news = "news: %s" % (it.get("h") or "")[:120]
    except Exception:
        pass
    return money, news


def surge_measured(kind):
    try:
        c = fm_db()
        rows = c.execute("select side, px, p30 from surges where kind=? and p30 is not null and px > 0", (kind,)).fetchall(); c.close()
        if not rows:
            return "not measured yet (new rule) — WATCH"
        ok = sum(1 for sd, px, p30 in rows if (p30 / px - 1) * 100 * (1 if sd == "CE" else -1) >= 0.5)
        return "%d%% of %d went a further 0.5%% that way within 30 min" % (round(100.0 * ok / len(rows)), len(rows))
    except Exception:
        return "not measured"


def surge_text(rec, hm, drv=None):
    """one 🚀 RUNNING / ⚡ SPEED line in plain words"""
    t_, s_, kind_, side_, chg_, step_, secs_, x_, p_, pc_ = rec
    money, news = drv if drv is not None else drivers(s_)
    up = side_ == "CE"
    vol = ("volume %.1fx its normal" % x_) if x_ is not None else "volume not read"
    if kind_ == "step":
        head = "🚀 RUNNING %s %s ₹%g %+.1f%% · %s" % ("▲" if up else "▼", s_, round(p_, 2), chg_, hm)
        how = "crossed %s%d%% — %s · %s" % ("+" if up else "-", step_, ("from %s%d%% in %s" % ("+" if up else "-", step_ - 1, ("%d min" % round(secs_ / 60.0)) if secs_ >= 60 else ("%d s" % secs_))) if secs_ else "the first step today", vol)
    else:
        head = "⚡ SPEED %s %s ₹%g %+.1f%% in %d min · day %+.1f%% · %s" % ("▲" if up else "▼", s_, round(p_, 2), step_, round(secs_ / 60.0), chg_, hm)
        how = "%s in the last 5 minutes" % vol
    why = " · ".join(x for x in (money, news) if x) or "no news found — this is money"
    return "%s\\n%s\\nshare price going %s → %s side · driving it: %s\\nWATCH — not a trade by itself: tap %s on GIR for the OI and the chart; the desk confirms\\n%s rule measured: %s" % (
        head, how, "UP" if up else "DOWN", side_, why, s_, "running" if kind_ == "step" else "speed", surge_measured(kind_))


def first_move_sender(feed):''')
E("engine2.py", '''            while feed.book_moves:''', '''            while getattr(feed, "surges", None):                # 🚀 RUNNING / ⚡ SPEED (patch 88): the second it happens, never capped
                rec_ = feed.surges.popleft()
                t_, s_, kind_, side_, chg_, step_, secs_, x_, p_, pc_ = rec_
                try:
                    c_ = fm_db(); c_.execute("insert or ignore into surges(day,t,sym,kind,side,px,chg,step,x) values(?,?,?,?,?,?,?,?,?)", (d_, hm_, s_, kind_, side_, p_, chg_, step_, x_)); c_.commit(); c_.close()
                except Exception as ex:
                    log("surges log: %s" % str(ex)[:80])
                tg_gate(("run%d" % int(step_)) if kind_ == "step" else "speed", s_, side_, surge_text(rec_, hm_), exempt=True, dup_s=86400 if kind_ == "step" else 900)
                log("%s %s %s %+.2f%% step/move %s x%s" % ("RUNNING" if kind_ == "step" else "SPEED", s_, side_, chg_, step_, x_))
                try:
                    dash.event("FLOW", "%s %s %s %+.1f%%" % ("🚀 RUNNING" if kind_ == "step" else "⚡ SPEED", s_, side_, chg_))
                except Exception:
                    pass
            while feed.book_moves:''')
E("engine2.py", '''                            c_.execute("update book_moves set p15=? where day=? and t=? and sym=? and side=?", (float(feed.ltp[i_]), d_, t__, s__, sd__))
                    c_.commit(); c_.close()''', '''                            c_.execute("update book_moves set p15=? where day=? and t=? and sym=? and side=?", (float(feed.ltp[i_]), d_, t__, s__, sd__))
                    due_ = [(t__, s__, k__, sd__) for t__, s__, k__, sd__ in c_.execute("select t, sym, kind, side from surges where day=? and p30 is null", (d_,)) if hm_[:5] >= "%02d:%02d" % divmod(int(t__[:2]) * 60 + int(t__[3:5]) + 30, 60)]
                    for t__, s__, k__, sd__ in due_:
                        i_ = feed.pos.get(s__)
                        if i_ is not None and np.isfinite(feed.ltp[i_]):
                            c_.execute("update surges set p30=? where day=? and t=? and sym=? and kind=? and side=?", (float(feed.ltp[i_]), d_, t__, s__, k__, sd__))
                    c_.commit(); c_.close()''')


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
        print("p88: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p88: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p88test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p88test.py - the 🚀 RUNNING test (no network, nothing sent).
  1 YESBANK-like: 24.00 -> +2 .. +6% over 40 minutes in a staircase (no 60-s burst): STEP fires at +2 +3 +4 +5 +6, each once,
    the second it crosses, with how long each step took; falling back and rising again does not repeat a step
  2 SPEED: 1.2% in 5 minutes on heavy volume fires once (15-min cool-off); the same move on normal volume does not
  3 a fall: -2, -3 fire on the PE side; a non-F&O share is ignored; nothing in the first minute
  4 the words: the line says the step, the speed, the volume, the side, what drives it, WATCH, the measured number
  5 your own server's 5-min bars: where STEP would have fired on the latest stored day for YESBANK (and any share you name)"""
import os, sys, time, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine, core

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


real_time = time.time
base = real_time()
t0 = base - 3 * 3600                                        # 09:15 was 3 hours ago
f = engine.WsFeed(["YESBANK", "SAIL"], {"YESBANK": 111, "SAIL": 222}, t0)
f.vnorm = np.full((3, 75), 20000.0)                         # normal: 20,000 shares a minute
cum = {111: 5_000_000, 222: 3_000_000}


def tick(tok, p, at, add):
    cum[tok] += add
    engine.time.time = lambda: at
    f.on_ticks([{"instrument_token": tok, "last_price": p, "volume_traded": cum[tok], "ohlc": {"close": 24.0 if tok == 111 else 100.0, "open": 24.0}}])


print("1. a staircase from +1% to +6.4% over 40 minutes (every 5 s, 0.04% a step - never a 60-s burst)")
t = base
p = 24.24
fired = []
while p < 25.54:
    tick(111, round(p, 2), t, 3000)                          # 3,000 shares per 5 s = 36,000 a minute (1.8x normal)
    p += 0.0042; t += 5
steps = [r for r in f.surges if r[2] == "step" and r[1] == "YESBANK"]
check("STEP fired at +2 +3 +4 +5 +6, in order: %s" % [r[5] for r in steps], [r[5] for r in steps] == [2, 3, 4, 5, 6])
check("each step after the first says how long it took (%s)" % ["%dm" % (r[6] / 60) for r in steps[1:]], all(r[6] and r[6] > 60 for r in steps[1:]))
check("FIRST MOVE (0.4%% in 60 s on 4x volume) never fired on this staircase: %d" % len([x for x in f.first_moves if x[1] == "YESBANK" and x[8] == "moderate"]),
      not [x for x in f.first_moves if x[1] == "YESBANK" and x[8] == "moderate"])
n0 = len(f.surges)
for k in range(60):                                         # back to +4.5%, then up to +6.3% again
    tick(111, round(25.08 + 0.0007 * k, 2), t, 500); t += 5
for k in range(40):
    tick(111, round(25.12 + 0.0081 * k, 2), t, 500); t += 5
check("falling back and rising again does not repeat a step", not [r for r in list(f.surges)[n0:] if r[2] == "step"])

print("2. SPEED")
f.surges.clear()
t2 = t + 1200
for k in range(61):                                         # SAIL +1.2% in 5 min on 100,000 shares a minute (5x)
    tick(222, round(100.0 + 0.02 * k, 2), t2 + 5 * k, 8333)
sp = [r for r in f.surges if r[2] == "speed" and r[1] == "SAIL"]
check("1.2%% in 5 min on 5x volume -> SPEED once (%d), x volume %s" % (len(sp), sp[0][7] if sp else None), len(sp) == 1 and sp[0][7] >= 3)
for k in range(61):
    tick(222, round(101.2 + 0.02 * k, 2), t2 + 310 + 5 * k, 8333)
check("again within 15 min -> no second SPEED", len([r for r in f.surges if r[2] == "speed" and r[1] == "SAIL"]) == 1)
g = engine.WsFeed(["QUIET"], {"QUIET": 333}, t0); g.vnorm = np.full((2, 75), 20000.0)
cq = 1_000_000
for k in range(61):
    cq += 1500
    engine.time.time = (lambda at: (lambda: at))(t2 + 5 * k)
    g.on_ticks([{"instrument_token": 333, "last_price": round(50.0 + 0.01 * k, 2), "volume_traded": cq, "ohlc": {"close": 50.0}}])
check("the same 1.2% on normal volume -> no SPEED", not [r for r in g.surges if r[2] == "speed"])

print("3. a fall, the F&O list, the first minute")
h = engine.WsFeed(["DOWNCO", "CASHONLY"], {"DOWNCO": 444, "CASHONLY": 555}, t0); h.vnorm = np.full((3, 75), 20000.0); h.fo_idx = {1}
cd = 1_000_000
for k in range(80):
    cd += 2000
    engine.time.time = (lambda at: (lambda: at))(t2 + 5 * k)
    h.on_ticks([{"instrument_token": 444, "last_price": round(100.0 - 0.045 * k, 2), "volume_traded": cd, "ohlc": {"close": 100.0}},
                {"instrument_token": 555, "last_price": round(100.0 + 0.1 * k, 2), "volume_traded": cd, "ohlc": {"close": 100.0}}])
dn = [r for r in h.surges if r[2] == "step"]
check("a fall to -3.5%%: -2, -3 on the PE side (%s)" % [(r[1], r[3], r[5]) for r in dn], [(r[1], r[3], r[5]) for r in dn] == [("DOWNCO", "PE", 2), ("DOWNCO", "PE", 3)])
o = engine.WsFeed(["GAPPER"], {"GAPPER": 666}, real_time()); o.vnorm = np.full((2, 75), 20000.0)
engine.time.time = lambda: real_time() + 20
o.on_ticks([{"instrument_token": 666, "last_price": 104.0, "volume_traded": 10000, "ohlc": {"close": 100.0}}])
check("nothing in the first minute of the day", not o.surges)
engine.time.time = real_time

print("4. the words")
import engine2
rec = (t, "YESBANK", "step", "CE", 4.2, 4, 540, 5.2, 25.01, 24.0)
txt = engine2.surge_text(rec, "11:42:13", ("", ""))
print("    " + txt.replace("\n", "\n    "))
check("RUNNING line: the step, how fast, the volume, the side, the driver, WATCH, the number",
      "🚀 RUNNING ▲ YESBANK" in txt and "crossed +4% — from +3% in 9 min" in txt and "volume 5.2x" in txt and "→ CE" in txt and "no news found — this is money" in txt and "WATCH" in txt and "rule measured" in txt)
txt2 = engine2.surge_text((t, "SAIL", "speed", "CE", 2.1, 1.2, 300, 5.0, 101.2, 99.0), "12:05:00", ("futures: long build-up ₹62 cr (OI +4.1%)", "news: SAIL wins a ₹4,000 cr order"))
check("SPEED line with the futures and the news as the driver", "⚡ SPEED ▲ SAIL" in txt2 and "long build-up ₹62 cr" in txt2 and "SAIL wins" in txt2)

print("5. your server's own 5-min bars (where STEP would have fired)")
for sym in (sys.argv[1:] or ["YESBANK"]):
    a = core.load_npz(sym)
    if a is None or len(a["ts"]) < 150:
        print("    %s: no stored 5-min bars here" % sym); continue
    day = (a["ts"] + core.IST_OFF) // 86400
    days = np.unique(day)
    d1, d0 = days[-1], days[-2]
    pc = float(a["c"][day == d0][-1])
    m = day == d1
    hit = {}
    for ts_, hi, lo in zip(a["ts"][m], a["h"][m], a["l"][m]):
        for sg, px in ((1, hi), (-1, lo)):
            s_ = int(abs(px / pc - 1) * 100)
            if (px - pc) * sg > 0 and s_ >= 2:
                for k in range(2, s_ + 1):
                    hit.setdefault((sg, k), ts_)
    when = lambda e: time.strftime("%H:%M", time.gmtime(e + core.IST_OFF + 300))
    lines = ["%s%d%% by %s" % ("+" if sg > 0 else "-", k, when(e)) for (sg, k), e in sorted(hit.items(), key=lambda kv: kv[1])]
    print("    %s on %s (prev close %g): %s" % (sym, time.strftime("%d %b", time.gmtime(int(d1) * 86400)), pc, " · ".join(lines) or "never 2% either way"))
print("\nP88 RUNNING TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p88_patch.py $D || { rm -f $D/p88test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine.py engine2.py p88test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the RUNNING test (a YESBANK-like staircase, SPEED, a fall, the words) + YESBANK on this server's latest stored day:"
timeout 180 python3 p88test.py YESBANK 2>&1 | grep -v "^ *$" | tail -26
timeout 180 python3 p88test.py >/dev/null 2>&1 || { echo "the RUNNING test failed"; back; }
echo "--- 3. the earlier tests still pass:"
for t in p78test.py fmtest.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-intraday && sleep 8
echo "engine: $(systemctl is-active gir-intraday)"
journalctl -u gir-intraday --since "-1min" --no-pager -o cat | grep -i "error\|traceback" | head -3
echo "PATCH 88 APPLIED - from the next session every share crossing +-2, 3, 4, 5, 6% ... alerts the second it crosses."
echo "  see any share on the latest stored day:  cd $D && python3 p88test.py YESBANK SAIL PIIND | tail -5"
