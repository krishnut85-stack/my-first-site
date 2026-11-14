#!/bin/bash
# PATCH 275 - 🌬 THE WIND EVERY 3 SECONDS (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
#   GIR's engine already holds, second by second, every F&O share's price, futures price + OPEN INTEREST and the ORDER BOOK - only the price reached
#   the rest of GIR each second; the money and the book came through 5-min candles and sweeps (3-5 min late). Now:
#   1 the engine writes the futures OI + the order book every second (data/fut_live.json), beside the prices
#   2 windwatch.py (service gir-windwatch), every 3 s: the 3-min price move, the 3-min futures OI change (new money / forced out), buyers vs sellers
#     waiting, its sector moving with it -> data/wind.json · the 🃏 MOVE CARD's first line becomes this live wind (seconds old, not minutes)
#   3 every early wind signal (3 of 4) is recorded (wind_calls) - windscore.sh measures it; it rings only once it proves as good as SPEED
#   + at the end: Friday replayed (windaudit.sh) - where GIR's minutes went. READ ONLY - no orders. Tested: 8 cases.
#   Restarts the engine and the senders - after 15:35 on a trading day (or add: now); on a weekend any time.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 271" $D/alertword.py && [ -f $D/movecard.py ] && [ -f $D/engine2.py ] || { echo "patch 271 first"; exit 1; }
F="engine2.py movecard.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl disable --now gir-windwatch 2>/dev/null; rm -f $U/gir-windwatch.service; systemctl daemon-reload; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275: 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
GIR's engine already holds, second by second, every F&O share's price, its futures price + OPEN INTEREST and the ORDER BOOK (buyers / sellers
waiting) - but only the price reached the rest of GIR every second; the money and the book came through slower rounds (5-min candles, sweeps).
Patch 275 makes the engine write them every second (data/fut_live.json) and this watcher reads them every 3 s:
  price move in 3 min · futures OI change in 3 min (new money: long / short build-up · or forced out: short covering / long unwinding) ·
  buyers vs sellers waiting in the book · its sector moving the same way
  -> data/wind.json (the live picture - the MOVE / TRADE CARD reads it: seconds old instead of minutes)
  -> tomorrow.db wind_calls: every early wind signal (score 3 of 4+), so windscore.sh can measure it before it is allowed to ring
READ ONLY (no orders, nothing sent).   python3 windwatch.py run | show"""
import os, sys, json, time, sqlite3, collections, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
EVERY, LOOK, KEEP = 3, 180, 900
PX_MIN, OI_MIN, BOOK_X, REPEAT_S = 0.5, 0.5, 1.5, 1800


def _load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None


def sectors_of():
    try:
        import sectors
        return sectors.load()
    except Exception:
        return {}


class Wind:
    def __init__(self, secmap=None):
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=KEEP // EVERY + 5))
        self.sec = secmap if secmap is not None else sectors_of()
        self.of = {}
        for k, v in self.sec.items():
            for s in v:
                self.of.setdefault(s, k)
        self.said = {}

    def feed(self, t, q, f):
        """q: {sym: [px, chg%]} (quotes_live) · f: {sym: [fut px, fut OI, buy qty, sell qty]} (fut_live)"""
        for s, v in (q or {}).items():
            if not isinstance(v, (list, tuple)) or not v or not v[0]:
                continue
            x = (f or {}).get(s) or [None, None, 0, 0]
            self.h[s].append((t, float(v[0]), v[1] if len(v) > 1 else None, x[1], x[2] or 0, x[3] or 0))

    def _ago(self, s, t):
        d = self.h.get(s)
        if not d or len(d) < 2 or t - d[0][0] < LOOK * 0.8:
            return None, None
        old = next((r for r in d if r[0] >= t - LOOK), d[0])
        return old, d[-1]

    def read(self, t):
        """-> {sym: {dir, kind, px3, oi3, book, sec, sec_up, sec_dn, score}} for every share moving now"""
        mv = {}
        for s in list(self.h):
            old, new = self._ago(s, t)
            if not old or not old[1]:
                continue
            px3 = (new[1] / old[1] - 1) * 100
            oi3 = ((new[3] / old[3] - 1) * 100) if (new[3] and old[3]) else None
            book = (new[4] / new[5]) if (new[4] and new[5]) else None
            mv[s] = (px3, oi3, book, new)
        out = {}
        for s, (px3, oi3, book, new) in mv.items():
            d = 1 if px3 >= PX_MIN else -1 if px3 <= -PX_MIN else 0
            if not d:
                continue
            kind = "PRICE ONLY"
            if oi3 is not None and oi3 >= OI_MIN:
                kind = "LONG BUILD-UP" if d > 0 else "SHORT BUILD-UP"             # new money its way
            elif oi3 is not None and oi3 <= -OI_MIN:
                kind = "SHORT COVERING" if d > 0 else "LONG UNWINDING"            # the other side forced out
            sec = self.of.get(s)
            peers = [mv[p][0] for p in (self.sec.get(sec) or []) if p != s and p in mv]
            up, dn = sum(1 for x in peers if x > 0.2), sum(1 for x in peers if x < -0.2)
            sec_ok = bool(peers) and (up if d > 0 else dn) * 2 >= len(peers)
            book_ok = book is not None and (book >= BOOK_X if d > 0 else book <= 1 / BOOK_X)
            score = (abs(px3) >= 0.6) + (kind in ("LONG BUILD-UP", "SHORT BUILD-UP")) + book_ok + sec_ok
            out[s] = {"dir": d, "kind": kind, "px3": round(px3, 2), "oi3": None if oi3 is None else round(oi3, 2), "book": None if book is None else round(book, 2),
                      "sec": sec, "sec_up": up, "sec_dn": dn, "sec_n": len(peers), "score": int(score), "px": new[1], "chg": new[2]}
        return out

    def calls(self, t, W):
        """the early wind signals worth measuring: score 3+ of 4, once a share-side in 30 min"""
        out = []
        for s, w in W.items():
            k = (s, w["dir"])
            if w["score"] >= 3 and (k not in self.said or t - self.said[k] >= REPEAT_S):
                self.said[k] = t
                out.append((s, w))
        return out


def line(w, age=None):
    """the live words for the cards: 'LIVE 4 s ago: futures OI +1.4% in 3 min (new buyers) · buyers 2.1x sellers · its sector 4 of 5 up'"""
    if not w:
        return None
    d = w["dir"]
    k = {"LONG BUILD-UP": "new buyers", "SHORT BUILD-UP": "new sellers", "SHORT COVERING": "sellers forced out", "LONG UNWINDING": "buyers giving up"}.get(w["kind"])
    bits = ["price %+.1f%% in 3 min" % w["px3"]]
    if w.get("oi3") is not None:
        bits.append("futures OI %+.1f%%%s" % (w["oi3"], (" (%s)" % k) if k else ""))
    if w.get("book"):
        b = w["book"]
        bits.append(("buyers %.1fx sellers waiting" % b) if b >= 1 else ("sellers %.1fx buyers waiting" % (1 / b)))
    if w.get("sec") and w.get("sec_n"):
        bits.append("its sector %d of %d %s" % (w["sec_up"] if d > 0 else w["sec_dn"], w["sec_n"], "up" if d > 0 else "down"))
    return "LIVE%s: %s · wind %d of 4" % ((" %d s ago" % age) if age is not None else "", " · ".join(bits), w["score"])


def db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists wind_calls(day text, t text, sym text, side text, kind text, px real, px3 real, oi3 real, book real, sec text, score int)")
    return c


def run():
    W = Wind()
    last_q = last_f = 0.0
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            if W.h:
                W = Wind()
            time.sleep(20); continue
        try:
            Q = _load(os.path.join(BASE, "quotes_live.json")) or {}
            F = _load(os.path.join(BASE, "data", "fut_live.json")) or {}
            t = time.time()
            if Q.get("t") and Q["t"] != last_q and t - Q["t"] < 30:
                last_q = Q["t"]
                W.feed(t, Q.get("q"), F.get("f") if F.get("t") and t - F["t"] < 30 else {})
                cur = W.read(t)
                p = os.path.join(BASE, "data", "wind.json")
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "s": cur}, open(p + ".tmp", "w"), separators=(",", ":")); os.replace(p + ".tmp", p)
                C = W.calls(t, cur)
                if C:
                    c = db()
                    c.executemany("insert into wind_calls values (?,?,?,?,?,?,?,?,?,?,?)", [(str(now.date()), now.strftime("%H:%M:%S"), s, "CE" if w["dir"] > 0 else "PE",
                                  w["kind"], w["px"], w["px3"], w["oi3"], w["book"], w["sec"], w["score"]) for s, w in C])
                    c.commit(); c.close()
        except Exception as ex:
            print("%s %s" % (hm, str(ex)[:120]), flush=True); time.sleep(5)
        time.sleep(EVERY)


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"]:
        run()
    else:
        j = _load(os.path.join(BASE, "data", "wind.json")) or {}
        age = time.time() - (j.get("t") or 0)
        print("wind.json: %s · futures data %s" % (("%.0f s old" % age) if j else "not written yet (from 09:15 on a trading day)", "in" if j.get("fut") else "not in yet"))
        for s, w in sorted((j.get("s") or {}).items(), key=lambda x: -x[1]["score"])[:15]:
            print("  %-11s %s" % (s, line(w)))
PY_WW
cat > $W/p275_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p275_patch.py - patch 275: the engine writes the futures OI + order book every second; the cards read the live wind.  python3 p275_patch.py DIR"""
import os, sys
D = sys.argv[1]
def edit(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if "patch 275" in s:
        print("  %s: patch 275 - already in" % f); return
    if s.count(old) != 1:
        print("❌ %s: anchor for '%s' found %d times" % (f, tag, s.count(old))); sys.exit(1)
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))
OLD = '''    os.replace(p_ + ".tmp", p_)
    return len(q)'''
NEW = '''    os.replace(p_ + ".tmp", p_)
    try:                                                        # patch 275: the futures price + OI and the order book, once a second -> data/fut_live.json
        if hasattr(feed, "f_oi"):
            f_ = {}
            with feed.lock:
                for s_, i_ in pos.items():
                    o_ = float(feed.f_oi[i_])
                    if o_ == o_ and o_ > 0:
                        fl_ = float(feed.f_ltp[i_]) if hasattr(feed, "f_ltp") else float("nan")
                        tb_ = float(feed.tbq[i_]) if hasattr(feed, "tbq") else 0.0
                        ts_ = float(feed.tsq[i_]) if hasattr(feed, "tsq") else 0.0
                        f_[s_] = [round(fl_, 2) if fl_ == fl_ else None, int(o_), int(tb_), int(ts_)]
            pf_ = os.path.join(core.BASE, "data", "fut_live.json")
            with open(pf_ + ".tmp", "w") as fh_:
                json.dump({"t": round(time.time(), 2), "f": f_}, fh_, separators=(",", ":"))
            os.replace(pf_ + ".tmp", pf_)
    except Exception:
        pass
    return len(q)'''
edit("engine2.py", OLD, NEW, "futures OI + the order book written every second (data/fut_live.json)")
MO = '''    d = 1 if side == "CE" else -1
    L = []'''
MN = '''    d = 1 if side == "CE" else -1
    L = []
    try:                                                             # patch 275: the live wind (3 s old) first
        import windwatch
        j_ = json.load(open(os.path.join(BASE, "data", "wind.json")))
        age_ = time.time() - float(j_.get("t") or 0)
        w_ = (j_.get("s") or {}).get(sym)
        if w_ and age_ < 30 and w_.get("dir") == d:
            L.append(windwatch.line(w_, int(age_)))
    except Exception:
        pass'''
edit("movecard.py", MO, MN, "the MOVE CARD's first line: the live wind (seconds old)")
print("patch 275 in")
PY_PATCH
cat > $W/p275test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p275test.py - the wind every 3 s (made-up ticks, temp copies, nothing sent).  python3 p275test.py DIR WORK"""
import os, re, sys, json, time, types, shutil, threading, tempfile
SRC, WK = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
for f in ("movecard.py", "posguard.py"):
    if os.path.exists(os.path.join(SRC, f)):
        shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); os.chdir(T)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
# 1 the engine's writer (the patched quotes_write, run on a fake feed)
src = open(os.path.join(SRC, "engine2.py"), encoding="utf-8").read()
a = src.index("def quotes_write("); b = src.index("\ndef ", a + 10)
ns = {"os": os, "json": json, "time": time, "core": types.SimpleNamespace(BASE=T)}
exec(src[a:b], ns)
import numpy as np
class Feed: pass
F = Feed(); F.lock = threading.Lock(); F.pos = {"AAA": 0, "BBB": 1}; F.ltp = np.array([101.0, 50.0]); F.pclose = np.array([100.0, 50.0])
F.f_ltp = np.array([101.5, np.nan]); F.f_oi = np.array([1200000.0, np.nan]); F.tbq = np.array([90000.0, 0]); F.tsq = np.array([30000.0, 0])
n = ns["quotes_write"](F)
fl = json.load(open(os.path.join(T, "data", "fut_live.json")))
chk("the engine writes the futures price, OI and the order book every second (fut_live.json) beside the prices", n == 2 and fl["f"] == {"AAA": [101.5, 1200000, 90000, 30000]}, fl)
# 2 the wind
import windwatch as WW
W = WW.Wind({"metals": ["AAA", "CCC", "DDD"]})
t0 = 1000.0
for i in range(70):                                                  # 3.5 minutes, every 3 s
    t = t0 + 3 * i; up = min(i, 60) / 60
    W.feed(t, {"AAA": [100 * (1 + 0.009 * up), 0.9 * up], "CCC": [200 * (1 + 0.004 * up), 0.4 * up], "DDD": [300 * (1 + 0.003 * up), 0.3 * up], "EEE": [50, 0]},
           {"AAA": [100 * (1 + 0.009 * up), 1_000_000 * (1 + 0.015 * up), 80000, 30000]})
R = W.read(t)
a_ = R.get("AAA") or {}
chk("AAA +0.9% in 3 min, futures OI +1.5%, buyers 2.7x sellers, its sector up: LONG BUILD-UP, wind 4 of 4", a_.get("dir") == 1 and a_.get("kind") == "LONG BUILD-UP" and a_.get("score") == 4, a_)
chk("a share that is not moving is not in the wind", "EEE" not in R)
C = W.calls(t, R)
chk("the early signal is recorded once (score 3+ of 4) - not again in 30 min", [s for s, _ in C] == ["AAA"] and W.calls(t + 60, R) == [], C)
ln = WW.line(a_, 4)
chk("the card's live words: 'LIVE 4 s ago: price +0.8% in 3 min · futures OI +1.3% (new buyers) · buyers 2.7x sellers waiting · its sector 2 of 2 up · wind 4 of 4'",
    ln == "LIVE 4 s ago: price +0.8% in 3 min · futures OI +1.3% (new buyers) · buyers 2.7x sellers waiting · its sector 2 of 2 up · wind 4 of 4", ln)
W2 = WW.Wind({})
for i in range(70):
    t = t0 + 3 * i; up = min(i, 60) / 60
    W2.feed(t, {"BBB": [100 * (1 - 0.008 * up), -0.8 * up]}, {"BBB": [None, 1_000_000 * (1 - 0.02 * up), 20000, 60000]})
b_ = W2.read(t).get("BBB") or {}
chk("BBB -0.8% with futures OI -2%: LONG UNWINDING (buyers giving up) - not new money", b_.get("kind") == "LONG UNWINDING" and b_.get("dir") == -1, b_)
# 3 the card reads it
if os.path.exists("movecard.py"):
    json.dump({"t": time.time() - 4, "fut": True, "s": {"AAA": a_}}, open(os.path.join(T, "data", "wind.json"), "w"))
    sys.modules["pushwho"] = types.SimpleNamespace(read=lambda s: {"rows": []})
    sys.modules["sectors"] = types.SimpleNamespace(load=lambda: {})
    import movecard as MC
    L = MC.why_who("AAA", "CE", {})
    chk("the MOVE CARD's first line is the live wind (seconds old, not minutes)", L and L[0].startswith("LIVE 4 s ago: price +0.8%"), L)
    chk("... not for the other side (a PE card on AAA gets no 'up' wind line)", not any(x.startswith("LIVE") for x in MC.why_who("AAA", "PE", {})))
print("THE WIND test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $D/windscore.sh <<'PY_WS'
#!/bin/bash
# windscore.sh - READ ONLY. THE WIND'S SCORECARD (patch 275): every early wind signal of the day (tomorrow.db wind_calls) - was it right
#   (0.5%+ its way 30 / 60 min later) or wrong (0.5%+ against), and how many MINUTES EARLIER than GIR's first alert on that share and side.
#   Decides whether the wind may ring (it needs SPEED's level: right 55%, wrong under 10%).   bash windscore.sh [YYYY-MM-DD]
D=/home/globalbot/intraday
cd $D || exit 1
python3 - "${1:-$(TZ=Asia/Kolkata date +%F)}" <<'PY'
import re, sys, json, sqlite3, statistics, datetime as dt
import numpy as np
day = sys.argv[1]; IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
d0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST).timestamp()
ro = lambda db: sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
try:
    c = ro("tomorrow.db"); W = c.execute("select t, sym, side, kind, px, px3, oi3, book, sec, score from wind_calls where day=? order by t", (day,)).fetchall()
    A = c.execute("select t, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception as ex:
    print("no wind signals yet (%s) - they start on the first trading day after patch 275" % str(ex)[:60]); sys.exit(0)
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def closes(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float); idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                return ts[idx], np.asarray(z["c"], float)[idx]
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c"):
        return np.array([d0 + 300 * i for i in range(len(x["c"]))], float), np.array([v if v is not None else np.nan for v in x["c"]], float)
    return None
first = {}
for t, tx in A:
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", (tx or "").split("\n")[0])
    if m:
        k = (m.group(2), "CE" if m.group(1) == "▲" else "PE")
        first.setdefault(k, []).append(dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp())
R = []
for t, s, side, kind, px, px3, oi3, book, sec, score in W:
    ts_ = dt.datetime.fromisoformat("%s %s" % (day, t)).replace(tzinfo=IST).timestamp(); sd = 1 if side == "CE" else -1
    b = closes(s); r30 = r60 = None
    if b:
        T_, C = b
        def at(x):
            k = int((x - T_[0]) // 300)
            return C[k] if 0 <= k < len(C) and not np.isnan(C[k]) else None
        p0 = px or at(ts_)
        for mins in (30, 60):
            p = at(ts_ + mins * 60)
            if p and p0:
                v = (p / p0 - 1) * 100 * sd
                if mins == 30: r30 = v
                else: r60 = v
    g = [x for x in first.get((s, side), []) if x >= ts_ - 600]
    lead = (min(g) - ts_) / 60 if g else None
    R.append((t, s, side, kind, score, r30, r60, lead, px3, oi3, book))
print("=== %s · wind signals: %d" % (day, len(R)))
sc = [x for x in R if x[6] is not None]
if sc:
    r = [x[6] for x in sc]
    print("   after 60 min: right (0.5%%+ its way) %d of %d (%d%%) · wrong (0.5%%+ against) %d (%d%%) · avg %+.2f%%   [SPEED: right 55%%, wrong 6%%]" % (
        sum(1 for v in r if v >= 0.5), len(r), 100 * sum(1 for v in r if v >= 0.5) // len(r), sum(1 for v in r if v <= -0.5), 100 * sum(1 for v in r if v <= -0.5) // len(r), sum(r) / len(r)))
    for k in ("LONG BUILD-UP", "SHORT BUILD-UP", "SHORT COVERING", "LONG UNWINDING", "PRICE ONLY"):
        z = [x[6] for x in sc if x[3] == k]
        if z:
            print("     %-15s %3d · right %d · wrong %d · avg %+.2f%%" % (k, len(z), sum(1 for v in z if v >= 0.5), sum(1 for v in z if v <= -0.5), sum(z) / len(z)))
L = [x[7] for x in R if x[7] is not None]
if L:
    print("   GIR's own first alert on that share and side came: median %+.1f min after the wind (positive = the wind was earlier) · the wind earlier in %d of %d" % (
        statistics.median(L), sum(1 for v in L if v > 0), len(L)))
print("   (time · share · side · kind · wind · 30 min · 60 min · GIR's first alert vs the wind)")
for t, s, side, kind, score, r30, r60, lead, px3, oi3, book in R[:60]:
    f = lambda v: "%+.1f%%" % v if v is not None else "  -  "
    print("   %s %-11s %s %-15s %d/4  %6s %6s  %s" % (t[:5], s, side, kind, score, f(r30), f(r60), ("GIR %+.0f min" % lead) if lead is not None else "GIR: no alert"))
PY
PY_WS
cat > $D/windaudit.sh <<'PY_WA'
#!/bin/bash
# windaudit.sh - READ ONLY. HOW EARLY DOES GIR CATCH THE WIND? (Rama, 14 Nov: "replay yesterday - where do we take more time, how fast can we be").
#   For every real move of the day (an F&O share 1%+ in 15 min that kept going 1.5%+ the next hour) it measures, from the minute the move started:
#   when each kind of GIR alert came (SPEED, FIRST MOVE, the futures money / OI build-up, P1, CONFIRMED MOVE, the first that RANG), how much of the
#   hour's move was ALREADY GONE when the phone rang, how far behind the option-chain readings were, and how long Telegram took.
#   Changes nothing, sends nothing.   bash windaudit.sh [YYYY-MM-DD]   (default: the last trading day)
D=/home/globalbot/intraday
cd $D || exit 1
python3 - "${1:-}" <<'PY'
import os, re, sys, json, sqlite3, statistics, datetime as dt
import numpy as np
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
day = sys.argv[1] or ""
if not day:
    d = now.date() - dt.timedelta(days=1 if now.strftime("%H:%M") < "15:35" else 0)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    day = str(d)
d0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST).timestamp()
hm = lambda ts: dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M:%S")
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
fo = set()
try:
    c = ro("chains.db"); fo = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
except Exception:
    pass
# ---- the day's 5-min candles: charts.json (the last session) or the share's history file
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def bars(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s, "data/h3/5min/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float)
            idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                prev = np.nonzero(ts < ts[idx[0]])[0]
                pc = float(z["c"][prev[-1]]) if len(prev) else None
                return ts[idx], np.asarray(z["c"], float)[idx], np.asarray(z["h"], float)[idx], np.asarray(z["l"], float)[idx], pc
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c") and len(x["c"]) >= 20:
        n = len(x["c"]); C = np.array([v if v is not None else np.nan for v in x["c"]], float)
        Hh = np.array([v if v is not None else np.nan for v in (x.get("h") or x["c"])], float); L = np.array([v if v is not None else np.nan for v in (x.get("l") or x["c"])], float)
        return np.array([d0 + 300 * i for i in range(n)], float), C, Hh, L, x.get("pc")
    return None
# ---- the alerts of the day
try:
    c = ro("tomorrow.db"); A = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception as ex:
    A = []; print("(tomorrow.db: %s)" % ex)
FAM = [("SPEED", r"\bSPEED\b"), ("FIRST MOVE", r"FIRST MOVE"), ("MONEY / OI", r"🧩|BUILD-UP|SHORT COVERING|LONG UNWINDING|F&O MONEY|🔎"),
       ("P1 / TRADE", r"🔴 TRADE ALERT|✓ P1|ENTER NOW|🟢 GO"), ("CONFIRMED", r"CONFIRMED MOVE|RESULTS REACTION"), ("RUNNING / SUDDEN", r"RUNNING|SUDDEN")]
AL = {}
for t, s, tx in A:
    L = (tx or "").split("\n"); h = L[0]
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
    if not m:
        continue
    sym, sd = m.group(2), (1 if m.group(1) == "▲" else -1)
    try:
        ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    sg = re.search(r"(?<![\d:])([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?![\d:])", h)
    sig = dt.datetime.fromisoformat("%s %s:%s:%s" % (day, sg.group(1), sg.group(2), sg.group(3) or "00")).replace(tzinfo=IST).timestamp() if sg else ts
    rang = "🔕" not in (tx or "") and bool(re.search(r"🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|CRITICAL|CONFIRMED MOVE", tx or ""))
    fam = next((f for f, rx in FAM if re.search(rx, tx or "")), "other")
    AL.setdefault(sym, []).append({"t": ts, "sig": min(sig, ts) if abs(ts - sig) < 3600 else ts, "sd": sd, "fam": fam, "rang": rang, "h": h[:70]})
# ---- the option-chain readings
SW = {}
try:
    c = ro("chains.db")
    for s, t in c.execute("select sym, t from chain where d=? group by sym, t", (day,)):
        try:
            SW.setdefault(s, []).append(dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8] if len(str(t)) >= 8 else str(t)[:5] + ":00")).replace(tzinfo=IST).timestamp())
        except Exception:
            pass
    c.close()
except Exception as ex:
    print("(chains.db: %s)" % ex)
# ---- the moves
M = []
for s in sorted(fo or (set(CJ) - {"NIFTY 50", "NIFTY BANK"})):
    b = bars(s)
    if not b:
        continue
    ts, C, Hh, L, pc = b
    seen = set()
    for i in range(3, len(C) - 2):
        if np.isnan(C[i]) or np.isnan(C[i - 3]) or not C[i - 3]:
            continue
        r15 = (C[i] / C[i - 3] - 1) * 100
        if abs(r15) < 1.0:
            continue
        sd = 1 if r15 > 0 else -1
        if sd in seen:
            continue
        st = i - 3
        while st < i and not np.isnan(C[st + 1]) and (C[st + 1] - C[st]) * sd <= 0:
            st += 1                                                   # skip the flat bars: the last close before the first step its way
        while st > 0 and not np.isnan(C[st - 1]) and (C[st] - C[st - 1]) * sd > 0:
            st -= 1                                                   # back to where it really began
        p0 = C[st]
        fut = C[i:min(len(C), i + 13)]
        best = (np.nanmax(fut) if sd > 0 else np.nanmin(fut))
        hour = (best / p0 - 1) * 100 * sd
        if hour < 1.5:
            continue
        seen.add(sd)
        M.append({"s": s, "sd": sd, "t0": ts[st] + 300, "p0": p0, "hour": hour, "C": C, "ts": ts, "st": st, "best": best})
print("=== %s · real moves (1%%+ in 15 min, then 1.5%%+ within the hour): %d on %d shares" % (day, len(M), len({m["s"] for m in M})))
def at_price(m, t):
    k = int((t - m["ts"][0]) // 300)
    k = max(0, min(len(m["C"]) - 1, k))
    v = m["C"][k]
    return None if np.isnan(v) else v
R = {f: [] for f, _ in FAM}; R["FIRST RING"] = []; R["ANY ALERT"] = []
gone, tg, swl, rows = [], [], [], []
for m in M:
    xs = [a for a in AL.get(m["s"], []) if a["sd"] == m["sd"] and m["t0"] - 600 <= a["t"] <= m["t0"] + 3600]
    def first(f=None, rang=False):
        z = [a for a in xs if (f is None or a["fam"] == f) and (not rang or a["rang"])]
        return min(z, key=lambda a: a["t"]) if z else None
    line = {"s": m["s"], "sd": m["sd"], "t0": m["t0"], "hour": m["hour"]}
    for f, _ in FAM:
        a = first(f); R[f].append((a["sig"] - m["t0"]) / 60 if a else None)
    a = first(); R["ANY ALERT"].append((a["sig"] - m["t0"]) / 60 if a else None)
    r = first(rang=True); R["FIRST RING"].append((r["t"] - m["t0"]) / 60 if r else None)
    if r:
        tg.append(r["t"] - r["sig"])
        p = at_price(m, r["t"])
        if p:
            gone.append(max(0.0, min(150.0, (p / m["p0"] - 1) * 100 * m["sd"] / m["hour"] * 100)))
    sw = [t for t in SW.get(m["s"], []) if t >= m["t0"]]
    if sw:
        swl.append((min(sw) - m["t0"]) / 60)
    line.update({"first": a, "ring": r})
    rows.append(line)
def band(xs):
    n = len(xs); got = [x for x in xs if x is not None]
    if not n:
        return "-"
    b = [sum(1 for x in got if x <= 1), sum(1 for x in got if 1 < x <= 3), sum(1 for x in got if 3 < x <= 5), sum(1 for x in got if 5 < x <= 10), sum(1 for x in got if x > 10)]
    med = statistics.median(got) if got else None
    return "%3d of %3d  · median %5s min · ≤1 %3d · 1-3 %3d · 3-5 %3d · 5-10 %3d · 10+ %3d · never %3d" % (len(got), n, ("%.1f" % med) if med is not None else "-", *b, n - len(got))
print("\n=== 1 · FROM THE MOVE'S START TO GIR'S ALERT (the time GIR saw it) - per kind")
for f in ["ANY ALERT"] + [f for f, _ in FAM] + ["FIRST RING"]:
    print("   %-17s %s" % (f, band(R[f])))
print("\n=== 2 · HOW MUCH OF THE HOUR'S MOVE WAS ALREADY GONE WHEN THE PHONE FIRST RANG")
if gone:
    g = sorted(gone)
    print("   median %.0f%% gone · in time (under 25%% gone) %d of %d · late (25-50%%) %d · very late (50%%+) %d" % (
        statistics.median(g), sum(1 for x in g if x < 25), len(g), sum(1 for x in g if 25 <= x < 50), sum(1 for x in g if x >= 50)))
else:
    print("   no move rang")
print("\n=== 3 · WHERE THE MINUTES GO")
if tg:
    print("   GIR saw it -> Telegram accepted it: median %.0f s · worst %.0f s" % (statistics.median(tg), max(tg)))
if swl:
    print("   the move's start -> the next option-chain reading: median %.1f min · worst %.1f min" % (statistics.median(swl), max(swl)))
cad = []
for s, v in SW.items():
    v = sorted(set(v))
    cad += [(b - a) / 60 for a, b in zip(v, v[1:]) if b - a < 3600]
if cad:
    print("   the option chain is read every: median %.1f min (%d readings of %d shares)" % (statistics.median(cad), len(cad), len(SW)))
print("\n=== 4 · EVERY MOVE (start · the hour's move · the first alert · the first ring)")
for x in sorted(rows, key=lambda x: x["t0"]):
    a, r = x["first"], x["ring"]
    print("   %s %-11s %s %+5.1f%%  first: %-26s ring: %s" % (hm(x["t0"])[:5], x["s"], "▲" if x["sd"] > 0 else "▼", x["hour"] * x["sd"],
          ("%s +%.0f min %s" % (hm(a["sig"])[:5], (a["sig"] - x["t0"]) / 60, a["fam"])) if a else "-", ("%s +%.0f min %s" % (hm(r["t"])[:5], (r["t"] - x["t0"]) / 60, r["fam"])) if r else "never rang"))
PY
PY_WA
python3 $W/p275_patch.py $D || back
cp $W/windwatch.py $D/windwatch.py
cd $D && python3 -m py_compile engine2.py movecard.py windwatch.py || back
echo "=== test"
python3 $W/p275test.py $D $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
chown --reference=$D $D/windwatch.py $D/windscore.sh $D/windaudit.sh 2>/dev/null
cat > $U/gir-windwatch.service <<'UNIT'
[Unit]
Description=GIR WIND - price, futures OI, order book and sector every 3 s (read only)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && exec python3 -u windwatch.py run >> data/windwatch.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-windwatch >/dev/null 2>&1 || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV gir-windwatch; do echo "  $s: $(systemctl is-active $s)"; done
echo "=== FRIDAY REPLAYED - where GIR's minutes went (read only)"
timeout 240 bash $D/windaudit.sh 2026-11-13 2>&1 | head -70
echo "✅ patch 275 done - from Monday 09:15 the wind is read every 3 s; the MOVE CARD's first line is live. Score it after 15:35: bash $D/windscore.sh"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-windwatch; systemctl restart $SV"
