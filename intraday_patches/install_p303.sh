#!/bin/bash
# PATCH 303 - 📋 THE CHECKLIST, LIVE + THE ✔ DONE TAB (Rama, 15 Nov: "this checklist and the cockpit should keep updating as GIR scans every round"
#   · "once it is done or out of the way it should move to another tab for the checklist - maybe Done").
#   · windwatch.py: every share on the evening checklist, every 3 s - the price, how far the ceiling / floor is now, its VWAP side, the futures now,
#     the 👀 / 🧱 that rang, and its STAGE: ⏳ waiting · 👀 at the level (0.5%) · ✅ entry live (touched the level and turned back 0.3%+ past VWAP, or
#     broke the day's low / high past VWAP; a breakout: held 0.3% past the wall) · then ✔ target (2% its way, or the other wall) · ✖ out (closed
#     back past the level) · ⚠ broke (0.5% through the level before any entry - the idea is off) · ⏹ closed (15:15). data/checklist_live.json.
#   · checklist.html: a LIVE line on every share, ✅ / 👀 ones on top of each tab, done ones move to the new ✔ Done tab with their result.
#   · dashserve.py: /checklistlive. Nothing new rings (👀 / 🧱 already do).
#   Replaces windwatch.py (only patch 299's copy) and checklist.html (only patch 302's). Tested: 15 + the old 5. Restarts the wind watcher and
#   the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "class CheckLive" $D/windwatch.py && grep -q "patch 303" $D/checklist.html && grep -q "patch 303" $D/dashserve.py; then echo "patch 303 - already in"; exit 0; fi
grep -q "patch 302" $D/checklist.html 2>/dev/null || { echo "patch 302 first"; exit 1; }
[ "$(sha256sum $D/windwatch.py | cut -c1-64)" = "59b437ea95fa287f4d47199c475298078fe147d44304ca5cb9c92a5659ad682f" ] || { echo "windwatch.py is not patch 299's copy (changed since?) - nothing done, send this to Claude"; exit 1; }
[ "$(sha256sum $D/checklist.html | cut -c1-64)" = "a4087e90797dc5dffb1eb81ae69f63f96a0f1b6b7a917b1045750630822abff4" ] || { echo "checklist.html is not patch 302's copy (changed since?) - nothing done, send this to Claude"; exit 1; }
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "dashserve.py: the cockpit route (patch 285) not found - nothing done, send this to Claude"; exit 1; }
F="windwatch.py checklist.html dashserve.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-windwatch gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel · 278: the option writers every 5 s, the 🎫 card on every big mover, then 🎯 BOOK HALF / 🚪 EXIT · 280: THE CHECKLIST on every message, how fresh the futures OI is · 281: 🚀 MOMENTUM - Rama's own way · 282: VOLUME vs its normal, ⏳ MONEY LOADING, each side's own rule · 283: 👁 YOUR VIEW · 284: ⚠ SOLO MOVE, the same-day rule · 285: 🎯 THE COCKPIT, 🔄 NIFTY TURNED · 286: the rules from the 30-day test, ✅ / ⚠ TESTED lines · 287: 🌪 on the day's slow build-up too · 288: 🧲 STEADY MOVE, the order book on the cockpit · 289: 📚 THE PLAYBOOK - which tested setup each share is in, live · 290: 📏 THE PUSH FOR ITS SIZE · 292: ⏱ THE BUILD-UP TIMELINE · 294: 💾 GIR's own minute futures history · 295: 🧱 PE MONEY / CE MONEY - the futures, the wall and VWAP together · 296: SHORT CARDS - 3 lines, read in 2 seconds · 298: 👀 WALL WATCH + 🧱 REJECTED AT THE WALL, 🧱 at futures +1.5% · 299: the cockpit's top 5 + any share's cockpit on request · 303: 📋 the checklist, live): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
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
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=int(KEEP // EVERY) + 5))
        self.sec = secmap if secmap is not None else sectors_of()
        self.of = {}
        for k, v in self.sec.items():
            for s in v:
                self.of.setdefault(s, k)
        self.said = {}
        self.oi_last, self.oi_gap = {}, collections.deque(maxlen=6000)      # patch 280: how often Zerodha's futures OI really changes
        self.br = (0, 0, 0)

    def oi_every(self):
        """the median seconds between two changes of a share's futures OI (the last few thousand changes, all shares)"""
        g = sorted(self.oi_gap)
        return round(g[len(g) // 2], 1) if len(g) >= 20 else None

    def feed(self, t, q, f):
        """q: {sym: [px, chg%]} (quotes_live) · f: {sym: [fut px, fut OI, buy qty, sell qty]} (fut_live)"""
        for s, v in (q or {}).items():
            if not isinstance(v, (list, tuple)) or not v or not v[0]:
                continue
            x = (f or {}).get(s) or [None, None, 0, 0]
            if x[1]:
                lo = self.oi_last.get(s)
                if lo is None or lo[0] != x[1]:
                    if lo is not None and t - lo[1] < 600:
                        self.oi_gap.append(t - lo[1])
                    self.oi_last[s] = (x[1], t)
            self.h[s].append((t, float(v[0]), v[1] if len(v) > 1 else None, x[1], x[2] or 0, x[3] or 0, (x[4] or 0) if len(x) > 4 else 0))

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
            vr = None                                                       # patch 282: volume in the 3 min vs its normal for those minutes
            if len(new) > 6 and len(old) > 6 and new[6] and old[6] and new[6] > old[6]:
                nm = vol_normal(s, old[0], new[0])
                if nm:
                    vr = (new[6] - old[6]) / nm
            mv[s] = (px3, oi3, book, new, vr)
        self.br = (sum(1 for v in mv.values() if v[0] > 0.1), sum(1 for v in mv.values() if v[0] < -0.1), len(mv))     # patch 280: the whole market
        out = {}
        for s, (px3, oi3, book, new, vr) in mv.items():
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
                      "sec": sec, "sec_up": up, "sec_dn": dn, "sec_n": len(peers), "score": int(score), "px": new[1], "chg": new[2],
                      "mk_up": self.br[0], "mk_dn": self.br[1], "mk_n": self.br[2], "vr": None if vr is None else round(vr, 1)}
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
    if w.get("ce3") is not None:                                        # patch 278: the option writers, 5 s old
        bits.append(opt_words(w))
    if w.get("sec") and w.get("sec_n"):
        bits.append("its sector %d of %d %s" % (w["sec_up"] if d > 0 else w["sec_dn"], w["sec_n"], "up" if d > 0 else "down"))
    return "LIVE%s: %s · wind %d of 4" % ((" %d s ago" % age) if age is not None else "", " · ".join(bits), w["score"])


# ---------------- patch 276: THE TURNS (Rama, 14 Nov: "for CE who is building, and from CE to PE who is pulling; for PE who is losing, and from PE to CE
# who is building - the option trader works both ways") ----------------
DAY_PX, DAY_OI, STEADY, TURN_S = 0.3, 0.5, 3, 1200
BASEF = os.path.join(BASE, "data", "wind_base.json")
CE_SIDE, PE_SIDE = ("LONG BUILD-UP", "SHORT COVERING"), ("SHORT BUILD-UP", "LONG UNWINDING")


def day_kind(chg, doi):
    """the day so far: price vs yesterday's close and futures OI vs the day's first reading"""
    if chg is None or doi is None or abs(chg) < DAY_PX or abs(doi) < DAY_OI:
        return None
    if chg > 0:
        return "LONG BUILD-UP" if doi > 0 else "SHORT COVERING"
    return "SHORT BUILD-UP" if doi > 0 else "LONG UNWINDING"


# ---------------- patch 292: ⏱ THE BUILD-UP TIMELINE (Rama, 15 Nov: "for futures and OI build-up, whether PE or CE - what time it entered the
# build-up, and any change, what time it changed, going in the same direction or a different direction"). Every F&O share, every 3 s, the
# same rule as everywhere in GIR (day_kind: the price vs yesterday's close + the futures OI vs the day's first reading). A new kind counts once
# it HOLDS 3 MINUTES - then it is written with the time it FIRST showed, the price % and the OI % at that moment. Kept for the day in
# data/buildlog.json (a restart keeps the morning), on GIR's page: B BIG MONEY -> ⏱ BUILD-UP TIMELINE. Nothing rings.
BT_HOLD, BT_MAX = 180, 16
BTF = os.path.join(BASE, "data", "buildlog.json")
BT_SIDE = {"LONG BUILD-UP": 1, "SHORT COVERING": 1, "SHORT BUILD-UP": -1, "LONG UNWINDING": -1}


class BuildLog:
    def __init__(self, day):
        self.day = day
        j = _load(BTF) or {}
        self.log = j.get("log", {}) if j.get("day") == day else {}
        self.cand, self.dirty, self.saved = {}, False, 0.0

    def step(self, t, hm, W, TU):
        """-> the shares whose build-up changed (held 3 min) in this round"""
        out = []
        for s, d in W.h.items():
            if s == "NIFTY50" or not d:
                continue
            last = d[-1]; b = TU.base.get(s)
            doi = ((last[3] / b - 1) * 100) if (last[3] and b) else None
            k = day_kind(last[2], doi)
            if k is None:
                continue                                                   # not clear right now: the last kind stands
            L = self.log.get(s)
            if L and L[-1][1] == k:
                self.cand.pop(s, None); continue
            c = self.cand.get(s)
            if not c or c[0] != k:
                self.cand[s] = (k, t, [hm[:5], k, round(float(last[2]), 2), round(doi, 2), round(float(last[1]), 2)]); continue
            if t - c[1] >= BT_HOLD:
                L = self.log.setdefault(s, [])
                L.append(c[2])
                if len(L) > BT_MAX:
                    del L[1:len(L) - BT_MAX + 1]                               # keep the first of the day and the latest
                self.cand.pop(s, None); self.dirty = True; out.append(s)
        if self.dirty and t - self.saved >= 30:
            self.save(); self.saved = t
        return out

    def save(self):
        try:
            json.dump({"day": self.day, "log": self.log}, open(BTF + ".tmp", "w"), separators=(",", ":")); os.replace(BTF + ".tmp", BTF)
            self.dirty = False
        except Exception:
            pass


# ---------------- patch 294: 💾 GIR'S OWN MINUTE FUTURES HISTORY (Rama, 15 Nov: "go, build patch 294"). The 3-year test showed: without the futures
# money minute by minute, price patterns do not pay - and Zerodha deletes expired contracts, so that history exists nowhere for free. GIR reads
# it every 3 s anyway: from now on, once a minute, every F&O share's futures price, OI, volume and order book is kept - one file a day,
# data/oihist/YYYY-MM-DD.npz (~1 MB). A restart carries on in the same file. In a few months the futures-money rules can be tested on our own
# history (with patch 278's option chain, kept a minute too).   python3 windwatch.py oihist  -> the days kept
OIH_DIR = os.path.join(BASE, "data", "oihist")
OIH_COLS = ("m", "px", "oi", "vol", "tbq", "tsq")


class OIHist:
    """one row a minute per share: minute since 09:15, price, futures OI, the day's volume, buyers / sellers waiting"""
    def __init__(self, day):
        self.day, self.rows, self.last_m, self.saved, self.dirty = day, {}, None, 0.0, False
        try:
            import numpy as np
            z = np.load(os.path.join(OIH_DIR, day + ".npz"))
            for k_ in z.files:
                self.rows[k_] = {int(r[0]): tuple(float(x) for x in r[1:]) for r in z[k_]}
        except Exception:
            pass

    def step(self, t, W):
        loc = dt.datetime.fromtimestamp(t, IST)
        m = (loc.hour * 60 + loc.minute) - 555
        if m < 0 or m >= 376 or m == self.last_m:
            return False
        self.last_m = m
        for s, d in list(W.h.items()):
            if not d:
                continue
            last = d[-1]
            self.rows.setdefault(s, {})[m] = (float(last[1]), float(last[3] or 0), float(last[6] if len(last) > 6 else 0),
                                             float(last[4] if len(last) > 4 else 0), float(last[5] if len(last) > 5 else 0))
        self.dirty = True
        if t - self.saved >= 300:
            self.save(); self.saved = t
        return True

    def save(self):
        if not self.rows:
            return
        try:
            import numpy as np
            os.makedirs(OIH_DIR, exist_ok=True)
            A = {s: np.array([[m] + list(v) for m, v in sorted(R.items())], np.float32) for s, R in self.rows.items() if R}
            tmp = os.path.join(OIH_DIR, self.day + ".tmp.npz")
            np.savez_compressed(tmp, **A); os.replace(tmp, os.path.join(OIH_DIR, self.day + ".npz"))
            self.dirty = False
        except Exception as ex:
            print("oihist: %s" % str(ex)[:80], flush=True)


def oihist_show():
    import numpy as np
    fs = sorted(f for f in os.listdir(OIH_DIR) if f.endswith(".npz") and ".tmp" not in f) if os.path.isdir(OIH_DIR) else []
    print("💾 GIR's own minute futures history: %d days in %s" % (len(fs), OIH_DIR))
    for f in fs[-15:]:
        try:
            z = np.load(os.path.join(OIH_DIR, f)); n = [len(z[k_]) for k_ in z.files]
            print("  %s · %d shares · %d-%d minutes each · %.1f MB" % (f[:-4], len(n), min(n) if n else 0, max(n) if n else 0, os.path.getsize(os.path.join(OIH_DIR, f)) / 1e6))
        except Exception as ex:
            print("  %s: %s" % (f, str(ex)[:60]))


# ---------------- patch 303: 📋 THE CHECKLIST, LIVE (Rama, 15 Nov: "the checklist and the cockpit should keep updating as GIR scans every round · once it
# is done or out of the way it should move to another tab - maybe Done"). Every share on the evening checklist (data/checklist.json), every 3 s:
# the price, how far the ceiling / floor is now, its side of VWAP, the futures now, and its STAGE -
#   ⏳ wait · 👀 at the level (0.5%) · ✅ entry live (touched the level and turned back past VWAP, 0.3%+ off it - or broke the day's low / high
#   past VWAP; breakout: held 0.3% past the wall on its VWAP side) · then ✔ target (2% its way, or the other wall) · ✖ out (closed back past the
#   level) · ⚠ broke (went 0.5% through the level before any entry - the idea is off) · ⏹ closed (15:15). Done ones move to the ✔ DONE tab.
#   data/checklist_live.json (a restart keeps the day). Nothing rings - 👀 / 🧱 already do.
CL_F = os.path.join(BASE, "data", "checklist.json")
CLL_F = os.path.join(BASE, "data", "checklist_live.json")
CL_NEAR, CL_AWAY, CL_TGT, CL_WIN, CL_FROM, CL_END = 0.5, 0.3, 2.0, 1200, "09:20", "15:15"


class CheckLive:
    def __init__(self, day):
        self.day, self.items, self.mt, self.saved = day, {}, None, 0.0
        j = _load(CLL_F) or {}
        self.st = (j.get("st") or {}) if j.get("day") == day else {}

    def load(self):
        try:
            mt = os.path.getmtime(CL_F)
        except Exception:
            return
        if mt == self.mt:
            return
        self.mt = mt
        J = _load(CL_F) or {}
        it = {}
        for sec in ("pe", "ce", "retest", "breakout", "breakdown"):
            for x in J.get(sec) or []:
                it.setdefault(x["s"] + "|" + x["side"], dict(x, sec=sec))
        self.items = it

    def step(self, t, hm, W, TU, CK):
        self.load()
        if not self.items:
            return {}
        hm5 = hm[:5]; live = {}
        rang = {}
        for x in (getattr(CK, "wm_list", None) or []):
            rang.setdefault((x["s"], x["dir"]), []).append("%s %s" % (x.get("t") or "", "👀" if "watch" in (x.get("note") or "") else "🧱"))
        for key, x in self.items.items():
            s = x["s"]; dq = W.h.get(s)
            if not dq or dq[-1][2] is None:
                continue
            last = dq[-1]; px = float(last[1]); chg = float(last[2]); b = TU.base.get(s)
            doi = ((last[3] / b - 1) * 100) if (last[3] and b) else None
            v = CK.vw.get(s) or {}
            vwap = (v["pv"] / v["v"]) if v.get("v") else None
            pe = x["side"] == "PE"; d = -1 if pe else 1
            r = (x.get("roof") or {}).get("k"); f = (x.get("floor") or {}).get("k")
            kind = x.get("kind")
            lvl = f if kind == "breakdown" else r if (kind == "breakout" or pe) else f
            st = self.st.setdefault(key, {"state": "wait"})
            vside = None if not vwap else (1 if px > vwap else -1)
            if st["state"] in ("wait", "at") and hm5 >= CL_END:
                st.update(state="closed", done_t=hm5, done_px=px, note="15:15 - never reached its entry")
            elif st["state"] in ("wait", "at") and lvl:
                past = (px - lvl) / lvl * 100 * d                              # + = gone past the level the trade's way (a PE: under the ceiling)
                if kind in ("breakout", "breakdown"):
                    if hm5 >= CL_FROM and past >= CL_AWAY and vside == d:
                        st.update(state="live", entry_t=hm5, entry_px=px, note="held %.1f%% past the %s %g on its VWAP side" % (past, "ceiling" if kind == "breakout" else "floor", lvl))
                    elif abs(past) <= CL_NEAR:
                        st["state"] = "at"
                else:
                    near = abs(px / lvl - 1) * 100 <= CL_NEAR
                    if near:
                        st["state"] = "at"; st["near_t"] = t
                    elif st["state"] == "at" and t - st.get("near_t", 0) > CL_WIN:
                        st["state"] = "wait"
                    trig = x.get("lo") if pe else x.get("hi")
                    if -past >= CL_NEAR:                                       # through the level the wrong way before any entry
                        st.update(state="broke", done_t=hm5, done_px=px, note="went through the %s %g - the %s is off" % ("ceiling" if pe else "floor", lvl, "PE" if pe else "CE"))
                    elif hm5 >= CL_FROM and st.get("near_t") and t - st["near_t"] <= CL_WIN and past >= CL_AWAY and vside == d:
                        st.update(state="live", entry_t=hm5, entry_px=px, note="touched the %s %g and turned back %s VWAP" % ("ceiling" if pe else "floor", lvl, "under" if pe else "over"))
                    elif hm5 >= CL_FROM and trig and (px - trig) * d > 0 and abs(px / trig - 1) * 100 >= 0.1 and vside == d:
                        st.update(state="live", entry_t=hm5, entry_px=px, note="broke the day's %s ₹%s %s VWAP" % ("low" if pe else "high", "{:,.2f}".format(trig), "under" if pe else "over"))
            elif st["state"] == "live":
                mv = (px / st["entry_px"] - 1) * 100 * d
                other = None if kind in ("breakout", "breakdown") else (f if pe else r)   # a breakout: 2% only (the wall it broke is behind it)
                tgt = mv >= CL_TGT or (other and (px - other) * d >= 0)
                back = lvl and (px - lvl) * d < 0 if kind in ("breakout", "breakdown") else (lvl and (px - lvl) * d < 0 and abs(px / lvl - 1) * 100 > 0.05)
                if tgt:
                    st.update(state="target", done_t=hm5, done_px=px, res=round(mv, 2), note="%+.1f%% its way%s" % (mv, " - reached the %s" % ("floor" if d < 0 else "ceiling") if other and (px - other) * d >= 0 else ""))
                elif back:
                    st.update(state="out", done_t=hm5, done_px=px, res=round(mv, 2), note="back %s the %g - out" % ("over" if d < 0 else "under", lvl))
                elif hm5 >= CL_END:
                    st.update(state="closed", done_t=hm5, done_px=px, res=round(mv, 2), note="15:15 - out at %+.1f%%" % mv)
            live[key] = {"px": round(px, 2), "chg": round(chg, 2), "roof": None if not r else round((r / px - 1) * 100, 2), "floor": None if not f else round((1 - f / px) * 100, 2),
                         "vwap": None if not vwap else round(vwap, 2), "vside": vside, "kind_now": day_kind(chg, doi), "doi": None if doi is None else round(doi, 2),
                         "rang": rang.get((s, d), [])[-3:], "move": round((px / st["entry_px"] - 1) * 100 * d, 2) if st.get("entry_px") else None}
            live[key].update({k_: st.get(k_) for k_ in ("state", "entry_t", "entry_px", "done_t", "done_px", "res", "note")})
        try:
            json.dump({"day": self.day, "t": round(t, 1), "hm": hm5, "st": self.st, "live": live}, open(CLL_F + ".tmp", "w"), separators=(",", ":"))
            os.replace(CLL_F + ".tmp", CLL_F)
        except Exception:
            pass
        return live


class Turns:
    """per share: the day's side and the live 3-min kind; a turn when the live kind holds for 3 readings (9 s) against the day's side"""
    def __init__(self, day):
        self.day = day
        b = _load(BASEF) or {}
        self.base = b.get("oi") if b.get("day") == day else {}
        self.streak, self.said, self.list = {}, {}, []

    def save(self):
        try:
            json.dump({"day": self.day, "oi": self.base}, open(BASEF + ".tmp", "w")); os.replace(BASEF + ".tmp", BASEF)
        except Exception:
            pass

    def step(self, t, hm, W, wind):
        """W: the Wind (its history) · wind: W.read(t) -> [new turns]"""
        new, changed = [], False
        for s, d in W.h.items():
            if not d:
                continue
            last = d[-1]
            if last[3] and s not in self.base:
                self.base[s] = last[3]; changed = True
        if changed:
            self.save()
        for s, w in wind.items():
            d = W.h.get(s)
            last = d[-1] if d else None
            doi = ((last[3] / self.base[s] - 1) * 100) if (last and last[3] and self.base.get(s)) else None
            dk = day_kind(last[2] if last else None, doi)
            w["day_kind"], w["day_oi"] = dk, None if doi is None else round(doi, 2)
            lk = w["kind"] if w.get("oi3") is not None and abs(w["oi3"]) >= OI_MIN and abs(w["px3"]) >= 0.4 else None
            prev = self.streak.get(s)
            self.streak[s] = (lk, (prev[1] + 1) if prev and prev[0] == lk else 1)
            if not lk or self.streak[s][1] < STEADY or not dk:
                continue
            ev = None
            if dk in CE_SIDE and lk == "LONG UNWINDING":
                ev = ("CE LEAVING", -1, "⚠ the CE side is leaving - buyers unwinding")
            elif dk in CE_SIDE and lk == "SHORT BUILD-UP":
                ev = ("CE → PE", -1, "🔄 TURNED CE → PE - new sellers coming in")
            elif dk in PE_SIDE and lk == "SHORT COVERING":
                ev = ("PE COVERING", 1, "⚠ the PE side is losing - sellers covering")
            elif dk in PE_SIDE and lk == "LONG BUILD-UP":
                ev = ("PE → CE", 1, "🔄 TURNED PE → CE - new buyers coming in")
            if not ev:
                continue
            k = (s, ev[0])
            if k in self.said and t - self.said[k] < TURN_S:
                continue
            self.said[k] = t
            x = {"t": hm, "ts": int(t), "s": s, "turn": ev[0], "dir": ev[1], "words": ev[2], "day_kind": dk, "day_oi": w["day_oi"], "kind": lk,
                 "px3": w["px3"], "oi3": w["oi3"], "book": w.get("book"), "px": w.get("px"), "chg": w.get("chg")}
            self.list.append(x); new.append(x)
            w["turn"] = ev[0]; w["turn_t"] = hm
        self.list = [x for x in self.list if t - x["ts"] < 3 * 3600][-60:]
        for x in self.list:                                            # keep the last turn on the share's live line
            if x["s"] in wind and "turn" not in wind[x["s"]]:
                wind[x["s"]]["turn"], wind[x["s"]]["turn_t"] = x["turn"], x["t"]
        return new


def turn_text(x, w=None):
    up = x["dir"] > 0
    was = (x["day_kind"] or "").lower()
    b = x.get("book")
    book = (" · buyers %.1fx sellers waiting" % b if b >= 1 else " · sellers %.1fx buyers waiting" % (1 / b)) if b else ""
    full = x["turn"] in ("CE → PE", "PE → CE")
    return "\n".join([
        "🔄 TURN %s %s · %s · %s" % ("▲" if up else "▼", x["s"], x["turn"], x["t"]),
        "the day so far: %s%s · now: %s - price %+.1f%% in 3 min, futures OI %+.1f%%%s" % (was, (" (futures OI %+.1f%% today)" % x["day_oi"]) if x.get("day_oi") is not None else "",
                                                                                   x["kind"].lower(), x["px3"], x["oi3"], book),
        ("for you: %s holders - protect it now (exit / tighten the stop) · the %s side now has the money - a trade only when GIR confirms" % ("PE" if up else "CE", "CE" if up else "PE")) if full else
        ("for you: %s holders - watch it closely; if it turns fully GIR says 🔄 TURNED" % ("PE" if up else "CE"))] +
        (check_text(w, "THE NEW SIDE - THE 3 (%s)" % ("CE" if up else "PE")) if w and w.get("dir") == x["dir"] else []))


def turns_db(xs, day):
    try:
        c = db()
        c.execute("create table if not exists wind_turns(day text, t text, sym text, turn text, side text, day_kind text, kind text, px real, px3 real, oi3 real)")
        c.executemany("insert into wind_turns values (?,?,?,?,?,?,?,?,?,?)", [(day, x["t"], x["s"], x["turn"], "CE" if x["dir"] > 0 else "PE", x["day_kind"], x["kind"], x["px"], x["px3"], x["oi3"]) for x in xs])
        c.commit(); c.close()
    except Exception:
        pass


# ---------------- patch 277: 🌪 BIG MOVERS - their own Telegram channel "GIR Bigmovers" (Rama, 14 Nov) ----------------
BIG_PX, BIG_S = 0.8, 1800
ENVF = "/home/globalbot/.env"
_ENV = {"t": 0.0, "e": {}}


def env():
    """GIR's .env, read (never copied) once a minute - a channel set up later is picked up without a restart"""
    if time.time() - _ENV["t"] > 60:
        e = {}
        try:
            import re as _re
            for ln in open(ENVF):
                m = _re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", ln)
                if m:
                    e[m.group(1)] = m.group(2).strip("'\"")
        except Exception:
            pass
        _ENV.update({"t": time.time(), "e": e})
    return _ENV["e"]


DAY_BUILD = 1.0          # patch 287: the day's futures OI +1% since the open, its way, counts as new money


def day_build(w):
    """patch 287 (Rama, 14 Nov - POLICYBZR 13 Nov: the futures money crept in 0.1-0.3% every 3 min from 09:30, the price jumped 09:41-09:45 - the 3-min
    rule never saw new money): True when the DAY's futures build-up is already its way - long build-up for a rise, short for a fall, OI +1% since the open"""
    want = "LONG BUILD-UP" if w["dir"] > 0 else "SHORT BUILD-UP"
    return w.get("day_kind") == want and abs(w.get("day_oi") or 0) >= DAY_BUILD


def new_money(w):
    """new futures money its way: in the last 3 min (the old rule) OR built up through the day (patch 287)"""
    return w["kind"] in ("LONG BUILD-UP", "SHORT BUILD-UP") or day_build(w)


def big_movers(t, wind, said):
    """the early, fast movers: 0.8%+ in 3 min with NEW futures money its way (the last 3 min, or the day's build-up - patch 287) and 3 of 4 wind
    - once a share-side in 30 min"""
    out = []
    for s, w in wind.items():
        sc = w["score"] + (1 if (day_build(w) and w["kind"] not in ("LONG BUILD-UP", "SHORT BUILD-UP")) else 0)
        if sc >= 3 and abs(w["px3"]) >= BIG_PX and new_money(w):
            w["slow"] = w["kind"] not in ("LONG BUILD-UP", "SHORT BUILD-UP")
            k = (s, w["dir"])
            if k not in said or t - said[k] >= BIG_S:
                said[k] = t
                out.append((s, w))
    return out


# ---------------- patch 280: THE CHECKLIST on every message (Rama, 14 Nov: "in order for the shares to move all should move together - tell me what
# all 3 are, and when you give the alarm and message you should mention that also") ----------------
# THE 3 THAT MUST MOVE TOGETHER: the price (0.6%+ in 3 min) · the futures money (NEW money its way: long / short build-up) · its sector (half of
# its peers or more the same way). THE HELPERS: the order book (buyers / sellers waiting 1.5x) · the option writers (CE vs PE OI near the
# price) · the whole market (55%+ of the F&O shares moving the same way in 3 min).
def checklist(w):
    """-> (must_ok, must_of, help_ok, help_of, line_must, line_help)"""
    up = w["dir"] > 0
    M, Hh = [], []
    px = abs(w.get("px3") or 0) >= 0.6
    M.append((px, "price %+.1f%% in 3 min" % (w.get("px3") or 0)))
    k = w.get("kind")
    if k in ("LONG BUILD-UP", "SHORT BUILD-UP"):
        M.append((True, "futures money: %s (OI %+.1f%%)" % ("new buyers" if up else "new sellers", w.get("oi3") or 0)))
    elif "day_kind" in w and day_build(w):                                  # patch 287: the slow build-up of the day
        M.append((True, "futures money: %s since the open (OI %+.1f%% today, coming in slowly)" % ("new buyers" if up else "new sellers", w.get("day_oi") or 0)))
    elif k in ("SHORT COVERING", "LONG UNWINDING"):
        M.append((None, "futures: %s (OI %+.1f%%) - no new money" % ("sellers running" if up else "buyers leaving", w.get("oi3") or 0)))
    else:
        M.append((False, "futures money: not moving"))
    if w.get("sec_n"):
        n_ = w["sec_up"] if up else w["sec_dn"]
        M.append((n_ * 2 >= w["sec_n"], "sector %d of %d %s" % (n_, w["sec_n"], "up" if up else "down")))
    else:
        M.append((None, "sector: no peers to compare"))
    b = w.get("book")
    if b:
        ok = b >= BOOK_X if up else b <= 1 / BOOK_X
        Hh.append((ok, ("buyers %.1fx sellers waiting" % b) if b >= 1 else ("sellers %.1fx buyers waiting" % (1 / b))))
    else:
        Hh.append((None, "order book: not known"))
    if w.get("ce3") is not None:
        a = w.get("opt")
        Hh.append((a, "writers: %s (CE OI %+.1f%% · PE OI %+.1f%%)" % ({True: "back it", False: "against it", None: "no side"}[a], w["ce3"], w["pe3"])))
    else:
        Hh.append((None, "writers: not known yet"))
    if w.get("vr") is not None:                                         # patch 282: the volume - in most real moves (2.2x as often as normal)
        Hh.append((True if w["vr"] >= VOL_X else None, "volume %.1fx its normal (3 min)" % w["vr"]))
    if w.get("mk_n"):
        mu, md, mn = w["mk_up"], w["mk_dn"], w["mk_n"]
        same, other = (mu, md) if up else (md, mu)
        Hh.append((True if same >= 0.55 * mn else False if other >= 0.55 * mn else None, "market: %d of %d shares %s" % (same, mn, "rising" if up else "falling")))
    ic = lambda v: "✅" if v is True else "❌" if v is False else "⚪"
    mo, ho = sum(1 for v, _ in M if v is True), sum(1 for v, _ in Hh if v is True)
    return (mo, len(M), ho, len(Hh), " · ".join("%s %s" % (ic(v), t) for v, t in M), " · ".join("%s %s" % (ic(v), t) for v, t in Hh))


def check_text(w, head="THE 3 THAT MUST MOVE TOGETHER"):
    if not w:
        return []
    mo, mn, ho, hn, lm, lh = checklist(w)
    return ["%s (%d of %d): %s" % (head, mo, mn, lm), "HELPERS (%d of %d): %s" % (ho, hn, lh)]


def big_text(s, w, hm, card=None):
    """patch 280: the head, THE CHECKLIST (the 3 that must move together + the helpers), the 🎫 card, the plan"""
    up = w["dir"] > 0
    stop = w["px"] / (1 + w["px3"] / 100)
    L = ["🌪 BIG MOVER %s %s · %s · ₹%s (%+.1f%% today)" % ("▲" if up else "▼", s, hm, "{:,.2f}".format(w["px"]), w.get("chg") or 0)]
    if w.get("slow"):                                                       # patch 287
        L.append("the money came first: %s since the open (futures OI %+.1f%% today) - now the price is breaking out (%+.1f%% in 3 min)" % (
            "long build-up" if up else "short build-up", w.get("day_oi") or 0, w["px3"]))
    L += check_text(w)
    L.append(side_rule(w))                                                      # patch 282
    sl = solo_line(w, w["dir"])                                                 # patch 284
    if sl:
        L.append(sl)
    L += list(card or [])
    L.append("%s side · early card: HALF your usual size until the scorecard proves it · stop: the share back %s ₹%s · GIR follows it here: 🎯 BOOK HALF · 🚪 EXIT · same day: out by 15:15" % (
        "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(stop)))
    return "\n".join(L)


def _log(text):
    try:
        import opencall
        opencall.log_alert(text)
    except Exception:
        pass


def send_big(text, log=True):
    """straight to GIR Bigmovers (TG_CHAT_BIGMOVERS), with sound - and onto GIR's page; False when the channel is not set up yet"""
    e = env()
    chat, tok = e.get("TG_CHAT_BIGMOVERS"), e.get("TELEGRAM_TOKEN") or e.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_TOKEN")
    if not (chat and tok):
        if log:
            _log(text)
        return False
    _log(text)
    try:
        import requests
        a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
        d = {"chat_id": a, "text": text[:4000], "disable_web_page_preview": "true"}
        if b and b.isdigit():
            d["message_thread_id"] = b
        return requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=15).ok
    except Exception:
        return False


# ---------------- patch 278: THE OPTION WRITERS EVERY 5 s + THE CARD FOLLOWED TO THE EXIT (Rama, 14 Nov: "when the futures are investing and
# disinvesting the shares are definitely going up and down - GIR should find it in time and alert me, then we invest, make money and exit") ----------------
# The engine already writes every pinned strike (the 11 nearest the price, CE and PE, all 218 shares) to pins_live.json every 5 s (patch 79) -
# only the desk read it. Now the wind reads it too: CE OI vs PE OI near the price in the last 3 min (who is writing), and every 🌪 card is
# followed: 🎯 BOOK HALF at 1x the risk (stop to the buy price), 🎯 TARGET 2 at 2x, 🚪 EXIT when the futures money leaves (3 readings in a row),
# the stop, or 15:10. Every card and its result go to tomorrow.db wind_cards; the strikes once a minute to data/chainlive.db (10 days).
PINF = os.path.join(BASE, "pins_live.json")
NEAR, OPT_GAP, OPT_MIN_OI = 3, 2.0, 1000
HISTF = os.path.join(BASE, "data", "chainlive.db")
HALF_X, T2_X, MIN_R, EXIT_HM = 1.0, 2.0, 0.004, "15:10"


class Opts:
    """the pinned strikes, every 5 s: per share the nearest expiry's strikes around the price"""
    def __init__(self):
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=KEEP // 5 + 5))
        self.now, self.spot, self.last = {}, {}, None

    def feed(self, P, t):
        if not P or not P.get("t") or P["t"] == self.last or t - float(P["t"]) > 40:
            return False
        self.last = P["t"]
        self.spot = P.get("spot") or {}
        for s, rows in (P.get("rows") or {}).items():
            rows = [r for r in (rows or []) if isinstance(r, (list, tuple)) and len(r) >= 5]
            if not rows:
                continue
            ex = min(r[0] for r in rows)
            self.h[s].append((t, {(float(r[1]), r[2]): float(r[3] or 0) for r in rows if r[0] == ex}))
            self.now[s] = {(r[0], float(r[1]), r[2]): float(r[4] or 0) for r in rows}
        return True

    def read(self, s, t, spot=None):
        """-> {ce3, pe3} the % change of CE OI and PE OI on the strikes nearest the price, over the last 3 min (same strikes both ends)"""
        d = self.h.get(s)
        if not d or len(d) < 2 or t - d[0][0] < LOOK * 0.8:
            return None
        old = next((r for r in d if r[0] >= t - LOOK), d[0])[1]
        new = d[-1][1]
        spot = spot or self.spot.get(s)
        ks = sorted({k for k, _ in new})
        if not ks:
            return None
        if spot:
            ks = sorted(ks, key=lambda k: abs(k - spot))[:2 * NEAR]
        out = {}
        for side in ("CE", "PE"):
            keys = [(k, side) for k in ks if (k, side) in new and (k, side) in old]
            a, b = sum(old[x] for x in keys), sum(new[x] for x in keys)
            if a < OPT_MIN_OI:
                return None
            out[side.lower() + "3"] = round((b / a - 1) * 100, 2)
        return out

    def prem(self, s, exp, k, side):
        return (self.now.get(s) or {}).get((exp, float(k), side))


def opt_agree(d, ce3, pe3):
    """the writers: a rise is backed when PE OI grows faster than CE OI (put writers add / call writers cover); a fall the other way.
    True = they back the move · False = they are against it · None = no clear side"""
    if ce3 is None or pe3 is None:
        return None
    g = (pe3 - ce3) if d > 0 else (ce3 - pe3)
    return True if g >= OPT_GAP else False if g <= -OPT_GAP else None


def opt_words(w):
    up = w["dir"] > 0
    a = w.get("opt")
    tail = {True: "put writers back the rise" if up else "call writers back the fall", False: "the writers are against it - careful",
            None: "the writers have no clear side"}[a]
    return "options CE OI %+.1f%% · PE OI %+.1f%% in 3 min (%s)" % (w["ce3"], w["pe3"], tail)


def opt_into(wind, O, t):
    for s, w in wind.items():
        o = O.read(s, t, w.get("px"))
        if o:
            w["ce3"], w["pe3"] = o["ce3"], o["pe3"]
            w["opt"] = opt_agree(w["dir"], o["ce3"], o["pe3"])


def card_lines(s, side, ustop, now):
    """the 🎫 TRADE CARD (movecard.py - Zerodha's quote, 3 s at most) -> (lines, (exp, strike, premium) or None)"""
    try:
        import movecard
        L = movecard.trade_card(s, side, ustop, now)
    except Exception as ex:
        return ["🎫 TRADE CARD: not available right now (%s) - take the strike nearest the price" % str(ex)[:60]], None
    import re as _re
    m = _re.search(r"BUY \S+ ([\d.]+) (CE|PE) · expiry (\d\d \w{3})", L[0] if L else "")
    p = _re.search(r"premium ₹([\d,]+\.?\d*)", L[1] if len(L) > 1 else "")
    pick = None
    if m and p:
        try:
            ex = dt.datetime.strptime("%s %d" % (m.group(3), now.year), "%d %b %Y").date()
            if ex < now.date():
                ex = ex.replace(year=now.year + 1)
            pick = (str(ex), float(m.group(1)), float(p.group(1).replace(",", "")))
        except Exception:
            pick = None
    return L, pick


class Book:
    """the 🌪 cards GIR gave today, followed every 3 s until the exit"""
    def __init__(self, day):
        self.day, self.open, self.done = day, {}, []

    def add(self, s, w, t, hm, r=None):
        d, e = w["dir"], w["px"]
        stop = e / (1 + w["px3"] / 100)
        r = r if r else max(abs(e - stop), e * MIN_R)
        stop = e - d * r
        p = {"s": s, "dir": d, "t": hm, "ts": t, "entry": e, "stop0": stop, "stop": stop, "r": r, "half": False, "t2": False, "bad": 0, "pick": None}
        self.open[(s, d)] = p
        return p

    def step(self, t, hm, W, wind, O=None):
        """-> [(kind, card, px, words)]  kind: HALF · T2 · EXIT"""
        out = []
        for k, p in list(self.open.items()):
            s, d = k
            dq = W.h.get(s)
            if not dq or dq[-1][0] <= p["ts"]:
                continue
            px = dq[-1][1]
            mv = (px - p["entry"]) * d
            w = wind.get(s)
            ev = None
            if (px - p["stop"]) * d <= 0:
                ev = "the stop: the share is back %s ₹%s%s" % ("under" if d > 0 else "over", "{:,.2f}".format(p["stop"]),
                                                             " (your buy price - the rest goes out at no loss)" if p["half"] else " - the move failed")
            else:
                against = ("LONG UNWINDING", "SHORT BUILD-UP") if d > 0 else ("SHORT COVERING", "LONG BUILD-UP")
                if w and w.get("oi3") is not None and abs(w["oi3"]) >= OI_MIN and w["kind"] in against:
                    p["bad"] += 1
                else:
                    p["bad"] = 0
                if p["bad"] >= STEADY:
                    ev = "the futures money is leaving: %s (OI %+.1f%%, price %+.1f%% in 3 min)" % (
                        {"LONG UNWINDING": "buyers unwinding", "SHORT BUILD-UP": "new sellers coming in", "SHORT COVERING": "sellers covering",
                         "LONG BUILD-UP": "new buyers coming in"}[w["kind"]], w["oi3"], w["px3"])
                elif hm >= EXIT_HM:
                    ev = "%s - an early card is not held overnight: close it before 15:20" % EXIT_HM
            if ev:
                del self.open[k]
                r_ = (mv + (p["half_px"] - p["entry"]) * d) / 2 if p.get("half_px") is not None else mv      # patch 280: half booked at target 1 counts
                p.update({"exit_t": hm, "exit_px": px, "why": ev, "res": round(r_ / p["entry"] * 100, 2)})
                self.done.append(p)
                out.append(("EXIT", p, px, ev))
                continue
            if not p["half"] and mv >= HALF_X * p["r"]:
                p["half"], p["stop"], p["half_px"] = True, p["entry"], px
                out.append(("HALF", p, px, "target 1 reached (+1x the risk)"))
            elif p["half"] and not p["t2"] and mv >= T2_X * p["r"]:
                p["t2"], p["stop"] = True, p["entry"] + d * p["r"]
                out.append(("T2", p, px, "target 2 reached (+2x the risk)"))
        return out

    def status(self):
        st = {}
        for p in self.done:
            st[(p["s"], p["dir"], p["t"])] = ("exit %+.1f%%" % p["res"], 1 if p["res"] > 0 else -1 if p["res"] < 0 else 0)
        for p in self.open.values():
            st[(p["s"], p["dir"], p["t"])] = ("target 2 · open" if p["t2"] else "½ booked · open" if p["half"] else "open", 1 if p["half"] else 0)
        return st


def follow_text(kind, p, px, words, O=None, w=None):
    up = p["dir"] > 0
    side = "CE" if up else "PE"
    head = {"EXIT": "🚪 EXIT", "HALF": "🎯 BOOK HALF", "T2": "🎯 TARGET 2"}[kind]
    mv = (px / p["entry"] - 1) * 100
    L = ["%s %s %s %s · %s" % (head, "▲" if up else "▼", p["s"], side, dt.datetime.now(IST).strftime("%H:%M:%S")),
         words,
         "from the %s 🌪 card: share ₹%s → ₹%s (%+.1f%%)" % (p["t"][:5], "{:,.2f}".format(p["entry"]), "{:,.2f}".format(px), mv)]
    pk = p.get("pick")
    if pk and O is not None:
        now_ = O.prem(p["s"], pk[0], pk[1], side)
        if now_:
            L[-1] += " · %s %s premium ₹%.2f (card ₹%.2f: %+.0f%%)" % ("{:g}".format(pk[1]), side, now_, pk[2], (now_ / pk[2] - 1) * 100)
    L.append({"EXIT": "sell the rest now" if p.get("half") else "sell it all now",
              "HALF": "sell half now · move the stop to your buy price (share ₹%s)" % "{:,.2f}".format(p["entry"]),
              "T2": "sell most of the rest · keep the last part with the stop at ₹%s" % "{:,.2f}".format(p["stop"])}[kind])
    if w:
        L += check_text(w, "NOW (%s)" % ("▲" if w["dir"] > 0 else "▼"))
    return "\n".join(L)


def cards_db(p, day):
    try:
        c = db()
        c.execute("create table if not exists wind_cards(day text, t text, sym text, side text, entry real, stop real, half int, exit_t text, exit_px real, why text, res real)")
        c.execute("insert into wind_cards values (?,?,?,?,?,?,?,?,?,?,?)", (day, p["t"], p["s"], "CE" if p["dir"] > 0 else "PE", p["entry"], p["stop0"], int(p["half"]),
                                                                           p.get("exit_t"), p.get("exit_px"), (p.get("why") or "")[:120], p.get("res")))
        c.commit(); c.close()
    except Exception:
        pass


def hist_save(O, t, day, hm):
    """once a minute: the strikes nearest the price (nearest expiry) -> data/chainlive.db, so a replay sees minutes, not 40-min gaps"""
    try:
        c = sqlite3.connect(HISTF, timeout=5)
        c.execute("create table if not exists pins(d text, t text, sym text, strike real, kind text, oi real)")
        c.execute("create index if not exists pins_ds on pins(d, sym)")
        rows = []
        for s, dq in O.h.items():
            if not dq:
                continue
            m = dq[-1][1]
            sp = O.spot.get(s)
            ks = sorted({k for k, _ in m}, key=lambda k: abs(k - sp) if sp else 0)[:2 * NEAR]
            rows += [(day, hm, s, k, kd, m[(k, kd)]) for k in ks for kd in ("CE", "PE") if (k, kd) in m]
        c.executemany("insert into pins values (?,?,?,?,?,?)", rows)
        if hm == "09:16":
            c.execute("delete from pins where d < date(?, '-10 days')", (day,))
        c.commit(); c.close()
        return len(rows)
    except Exception:
        return 0


def db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists wind_calls(day text, t text, sym text, side text, kind text, px real, px3 real, oi3 real, book real, sec text, score int)")
    return c



# ---------------- patch 281: 🚀 MOMENTUM - RAMA'S OWN WAY (14 Nov: "most of the money I made by momentum: the stock goes up 10%, then I invest, make
# money and exit"). Measured on 9 results-season days (2-13 Nov, fastreplay.py 3e): a share already +3% on the day, entered there, went 2% MORE
# 24% of the time and turned back 2% first 10% - BEFORE 10:00: 33% vs 11%; after 10:00: 15% vs 12% (a coin flip).
# On a strong market day the other side turns back (6 Nov: -3% shares turned up 58%).
# So: the FIRST time an F&O share crosses +3% (or -3%) on the day -> 🚀 card; +5% / +8% -> an update on the same card. To GIR Bigmovers with
# sound only BEFORE 10:00 and not against a strong market (65%+ of the F&O shares the other way); else on the page only, saying why.
MOM_LV, MOM_END, MOM_R, MOM_AGAINST, MOM_FROM, MOM_DAY_MAX = (3.0, 5.0, 8.0), "10:00", 0.02, 0.65, "09:17", 12
MOM_SAID = {True: "before 10:00, shares already 3%+ on the day went 2% MORE 33% of the time, turned back 2% first 11% (9 results days, 2-13 Nov)",
            False: "after 10:00 it is a coin flip: went 2% more 15%, turned back 12% (9 results days) - half size, or skip"}


def results_set(day):
    """the shares with results TODAY or the EVENING BEFORE (the last weekday) - chains.db results_cal"""
    out = set()
    try:
        d = dt.date.fromisoformat(day); p = d - dt.timedelta(days=1)
        while p.weekday() > 4:
            p -= dt.timedelta(days=1)
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        out = {r[0] for r in c.execute("select sym from results_cal where d in (?, ?)", (str(d), str(p)))}
        c.close()
    except Exception:
        pass
    return out


class Momentum:
    """per share and side: the highest level crossed today (3 / 5 / 8%) -> [(sym, side, level, first, px, chg)]"""
    def __init__(self, day):
        self.day, self.lv, self.res, self.list = day, {}, results_set(day), []

    def step(self, W):
        """results first, then the biggest move - so the day's 12 cards go to the strongest"""
        out = []
        for s, d in W.h.items():
            if not d or d[-1][2] is None:
                continue
            px, chg = d[-1][1], float(d[-1][2])
            for sd in (1, -1):
                got = self.lv.get((s, sd), 0.0)
                top = max([L for L in MOM_LV if chg * sd >= L] or [0.0])
                if top > got:
                    self.lv[(s, sd)] = top
                    out.append((s, sd, top, got == 0.0, px, chg))
        return sorted(out, key=lambda e: (e[0] not in self.res, -abs(e[5])))

    @staticmethod
    def market(W):
        """the whole market TODAY: F&O shares up / down 0.3%+ on the day"""
        ch = [d[-1][2] for d in W.h.values() if d and d[-1][2] is not None]
        return sum(1 for x in ch if x > 0.3), sum(1 for x in ch if x < -0.3), len(ch)


def mom_text(s, sd, L, px, chg, hm, early, mk, doi, res, card=None, w=None, ds=None, nst=None, day2=False):
    up = sd > 0
    same, other, n = (mk[0], mk[1], mk[2]) if up else (mk[1], mk[0], mk[2])
    ic = lambda v: "✅" if v is True else "❌" if v is False else "⚪"
    mok = True if n and same >= 0.5 * n else False if n and other >= MOM_AGAINST * n else None
    mon = True if (doi is not None and doi >= 1.0) else None                      # new futures money its way since the open
    L_ = ["🚀 MOMENTUM %s %s %+.1f%% today · %s · ₹%s%s" % ("▲" if up else "▼", s, chg, hm, "{:,.2f}".format(px), " · RESULTS" if res else ""),
          "THE CHECK: %s before 10:00 · %s market %d of %d shares %s · %s futures OI %s since the open%s" % (
              ic(early), ic(mok), same, n, "rising" if up else "falling", ic(mon), ("%+.1f%%" % doi) if doi is not None else "not known yet",
              " · ✅ results today / last evening" if res else ""),
          "MEASURED: " + MOM_SAID[early]]
    g_, w_ = tested("CE" if up else "PE", hm, nst, day2, None, None, chg * sd)       # patch 286
    L_ += ["TESTED: " + x for x in g_ + w_]
    if w:
        L_ += check_text(w)
        L_.append(side_rule(dict(w, dir=sd)))                                   # patch 282
    sl = solo_line(w, sd, ds)                                                   # patch 284
    if sl:
        L_.append(sl)
    L_ += list(card or [])
    L_.append("%s side · stop: the share back %s ₹%s (2%% back) · 🎯 BOOK HALF at ₹%s (2%% more) · GIR follows it here: 🎯 / 🚪 · same day: out by 15:15" % (
        "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(px * (1 - MOM_R * sd)), "{:,.2f}".format(px * (1 + MOM_R * sd))))
    return "\n".join(L_)


def _send_mom(s_, sd, L, px, chg, hm_, early, mk, doi, res, cp, now_, w, ds=None, nst=None, day2=False):
    stop = px * (1 - MOM_R * sd)
    L_, pick = card_lines(s_, "CE" if sd > 0 else "PE", stop, now_)
    if cp is not None:
        cp["pick"] = pick
    why = "already %+.1f%% today · futures OI %s since the open%s" % (chg, ("%+.1f%%" % doi) if doi is not None else "not known", " · results" if res else "")
    send_big(short_card("🚀", s_, sd, px, chg, hm_, why, pick, stop))                                              # patch 296: 3 lines



# ---------------- patch 282 (Rama, 14 Nov: "build patch 282 now") - what 10 days and 1,043 real moves showed (fastreplay.py 3d):
# UP moves ride the TIDE: its sector moving with it 4.6x as often as normal, new futures money 4.2x, the sector already moving 15 min before 2.5x,
#   NIFTY with it 2.3x, volume 2x its normal 2.2x
# DOWN moves are the share's OWN break: fresh futures sellers 6.6x, its sector with it 4.7x - and the market already falling before was LESS
#   often (0.4-0.6x)
# BOTH: the futures money comes BEFORE the price - OI +0.5% in the 15 min before (2.3x up, 2.8x down) -> ⏳ MONEY LOADING
# Hidden orders and news: no edge (1.1x). ----------------
VOL_X, VOLF = 2.0, os.path.join(BASE, "data", "vol_normal.json")
_VN = {"day": None, "m": {}}


def vol_build(day, syms):
    """the normal volume for each 5-minute slot of the day, per share: the median of the last 8 sessions (data/SYM.npz, 5-min candles) -> per minute"""
    out = {}
    try:
        import numpy as np
    except Exception:
        return out
    for s in syms:
        try:
            z = np.load(os.path.join(BASE, "data", s + ".npz"))
            ts, v = np.asarray(z["ts"], float), np.asarray(z["v"], float)
        except Exception:
            continue
        dd = ((ts + 19800) // 86400).astype(int)
        days = sorted(set(dd.tolist()))
        keep = [d for d in days if str(dt.date(1970, 1, 1) + dt.timedelta(days=d)) < day][-8:]
        if len(keep) < 3:
            continue
        slots = {}
        for t_, v_, d_ in zip(ts, v, dd):
            if d_ in keep and v_ > 0:
                m = int(((t_ + 19800) % 86400) // 60) // 5 * 5
                slots.setdefault(m, []).append(float(v_))
        out[s] = {str(m): round(sorted(L)[len(L) // 2] / 5.0, 1) for m, L in slots.items() if len(L) >= 3}
    return out


def vol_normal(s, t0, t1):
    """the normal volume of share s between t0 and t1 (epoch seconds) - built once a day, kept in data/vol_normal.json"""
    day = str(dt.datetime.fromtimestamp(t1, IST).date())
    if _VN["day"] != day:
        j = _load(VOLF) or {}
        if j.get("day") == day and j.get("m"):
            _VN.update({"day": day, "m": j["m"]})
        else:
            _VN.update({"day": day, "m": {}})
        _VN["tried"] = set()
    m = _VN["m"].get(s)
    if m is None:
        if s in _VN.get("tried", set()):
            return None
        _VN.setdefault("tried", set()).add(s)
        b = vol_build(day, [s])
        if s not in b:
            return None
        _VN["m"][s] = m = b[s]
        try:
            json.dump({"day": day, "m": _VN["m"]}, open(VOLF + ".tmp", "w"), separators=(",", ":")); os.replace(VOLF + ".tmp", VOLF)
        except Exception:
            pass
    tot, t = 0.0, t0
    while t < t1:
        mm = int(((t + 19800) % 86400) // 60)
        tot += m.get(str(mm // 5 * 5), 0.0) * min(60.0, t1 - t) / 60.0
        t += 60.0
    return tot if tot > 0 else None


# ---------------- patch 290: 📏 THE PUSH FOR ITS SIZE (Rama, 15 Nov: "₹200 cr pushing Reliance futures is nothing because of its size - the same
# amount in a small company is a big push. Friday Idea had a huge short build-up and fell only 2-3%"). The new futures money since the open,
# measured against what that share NORMALLY trades in a whole day: new futures shares ÷ the shares a normal day trades (the median of the last
# 8 sessions, slot by slot - the same file the volume check uses). The price cancels out, so ₹ crore vs ₹ crore of a normal day gives the same number.
# Every F&O share is ranked on it every 3 s: the top 10% today = BIG for its size, the top third = above normal, the rest = small for its size.
# On the screen and the cards only - the 30-day test (fastreplay 3p, stratpool) decides whether it goes into the rules.
PUSH_BIG, PUSH_MID, PUSH_BUILD = 0.10, 0.33, 25
_DN = {"day": None, "v": {}}


def day_normal(s, t):
    """the shares a normal whole day trades for s (09:15-15:30, the last 8 sessions) - None if not known yet"""
    day = str(dt.datetime.fromtimestamp(t, IST).date())
    if _DN["day"] != day:
        _DN.update({"day": day, "v": {}})
    if s not in _DN["v"]:
        t0 = dt.datetime.combine(dt.date.fromisoformat(day), dt.time(9, 15), IST).timestamp()
        _DN["v"][s] = vol_normal(s, t0, t0 + 375 * 60)
    return _DN["v"][s]


def push_word(v, r, n):
    if v is None:
        return ""
    if v <= 0:
        return "money leaving"
    return "BIG for its size" if r <= max(1, round(n * PUSH_BIG)) else "above normal for its size" if r <= round(n * PUSH_MID) else "small for its size"


def push_text(v, r, n, cr=None):
    """'₹5,000 cr = 0.30x its normal day · #45 of 180 today - small for its size'"""
    if v is None:
        return None
    return "%s%sx its normal day%s" % (("₹{:,.0f} cr = ".format(cr)) if cr is not None else "", ("%.2f" if abs(v) >= 0.1 else "%.3f") % v,
                                         (" · #%d of %d today - %s" % (r, n, push_word(v, r, n))) if v > 0 else " - money leaving")


def sector_day(W, s):
    """its sector TODAY (patch 284): peers up / down 0.3%+ on the day"""
    peers = [p for p in (W.sec.get(W.of.get(s)) or []) if p != s and W.h.get(p) and W.h[p][-1][2] is not None]
    ch = [float(W.h[p][-1][2]) for p in peers]
    return sum(1 for x in ch if x > 0.3), sum(1 for x in ch if x < -0.3), len(ch)


def solo_line(w, sd, ds=None):
    """patch 284 (Rama, 14 Nov - POLICYBZR up while NBFC fell): real moves ride the tide (its sector with it 4.6x as often); a solo move fades more"""
    up, dn, n = ds if ds else ((w or {}).get("sec_up", 0), (w or {}).get("sec_dn", 0), (w or {}).get("sec_n", 0))
    other = dn if sd > 0 else up
    if n and other >= 2 and other * 2 >= n:
        return "⚠ SOLO MOVE: %s while its sector %s (%d of %d) - real moves ride the tide, a solo move fades more often: half size, a quick profit" % (
            "rising" if sd > 0 else "falling", "falls" if sd > 0 else "rises", other, n)
    return None


def side_rule(w):
    """each side's own rule, from the 10 days: CE rides the tide · PE is the share's own break on fresh sellers"""
    up = w["dir"] > 0
    ic = lambda v: "✅" if v else "❌"
    vol = w.get("vr")
    vtx = (" · %s volume %.1fx" % (ic(vol >= VOL_X), vol)) if vol is not None else ""
    if up:
        sec = bool(w.get("sec_n")) and w["sec_up"] * 2 >= w["sec_n"]
        mk = bool(w.get("mk_n")) and w["mk_up"] >= 0.5 * w["mk_n"]
        return "CE RULE - real rises ride the tide: %s its sector with it · %s the market with it%s" % (ic(sec), ic(mk), vtx)
    new = w.get("kind") == "SHORT BUILD-UP"
    return "PE RULE - real falls are the share's own break on fresh sellers: %s new futures sellers (OI %+.1f%%)%s" % (ic(new), w.get("oi3") or 0, vtx)


LOAD_OI, LOAD_PX, LOAD_S, LOAD_BOOK, LOAD_END = 0.5, 0.3, 1800, 1.3, 2700


class Loading:
    """⏳ MONEY LOADING: futures OI +0.5% in 15 min while the price has not moved yet (under 0.3%) - the head start. On the page only, each one
    followed 45 min: did the price go 1% - which way, and was it the side the book / the lean pointed to?"""
    def __init__(self, day):
        self.day, self.said, self.list = day, {}, []

    def step(self, t, hm, W):
        new = []
        for s, d in W.h.items():
            if not d or t - d[0][0] < 0.8 * KEEP:
                continue
            old = next((r for r in d if r[0] >= t - KEEP), d[0]); cur = d[-1]
            if not (old[3] and cur[3] and old[1]):
                continue
            oi15 = (cur[3] / old[3] - 1) * 100; px15 = (cur[1] / old[1] - 1) * 100
            if oi15 < LOAD_OI or abs(px15) >= LOAD_PX or t - self.said.get(s, -1e9) < LOAD_S:
                continue
            self.said[s] = t
            b = (cur[4] / cur[5]) if (cur[4] and cur[5]) else None
            side = 1 if (b and b >= LOAD_BOOK) else -1 if (b and b <= 1 / LOAD_BOOK) else (1 if px15 >= 0.1 else -1 if px15 <= -0.1 else 0)
            x = {"t": hm, "ts": int(t), "s": s, "side": side, "oi15": round(oi15, 2), "px15": round(px15, 2), "book": None if b is None else round(b, 2),
                 "px": cur[1], "up": 0.0, "dn": 0.0, "res": None}
            self.list.append(x); new.append(x)
        done = []
        for x in self.list:                                            # follow each one 45 min
            if x["res"] is not None:
                continue
            d = W.h.get(x["s"])
            if d:
                mv = (d[-1][1] / x["px"] - 1) * 100
                x["up"], x["dn"] = max(x["up"], mv), min(x["dn"], mv)
                if x["up"] >= 1.0 and x["dn"] > -1.0:
                    x["res"] = "▲ +1%"
                elif x["dn"] <= -1.0 and x["up"] < 1.0:
                    x["res"] = "▼ -1%"
            if x["res"] is None and t - x["ts"] >= LOAD_END:
                x["res"] = "nothing (%+.1f%% / %+.1f%%)" % (x["up"], x["dn"])
            if x["res"] is not None:
                done.append(x)
        self.list = [x for x in self.list if t - x["ts"] < 4 * 3600][-80:]
        return new, done


def loading_db(xs, day):
    try:
        c = db()
        c.execute("create table if not exists wind_loading(day text, t text, sym text, side int, oi15 real, px15 real, book real, px real, res text, up real, dn real)")
        c.executemany("insert into wind_loading values (?,?,?,?,?,?,?,?,?,?,?)", [(day, x["t"], x["s"], x["side"], x["oi15"], x["px15"], x["book"], x["px"], x["res"],
                                                                                 round(x["up"], 2), round(x["dn"], 2)) for x in xs])
        c.commit(); c.close()
    except Exception:
        pass


def loading_show(day=None):
    """python3 windwatch.py loading [DAY] - every ⏳ MONEY LOADING and what the price did next"""
    day = day or str(dt.datetime.now(IST).date())
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True)
        R = c.execute("select t, sym, side, oi15, px15, book, res from wind_loading where day=? order by t", (day,)).fetchall()
    except Exception:
        R = []
    print("=== ⏳ MONEY LOADING %s: %d" % (day, len(R)))
    for r in R:
        print("  %s %-11s %s OI %+.1f%% · price %+.2f%% · book %s → %s" % (r[0], r[1], {1: "▲", -1: "▼", 0: "?"}[r[2]], r[3], r[4], ("%.1fx" % r[5]) if r[5] else "-", r[6]))
    if R:
        mv = [r for r in R if r[6] and r[6][0] in "▲▼"]
        right = sum(1 for r in mv if (r[6][0] == "▲" and r[2] > 0) or (r[6][0] == "▼" and r[2] < 0))
        print("  moved 1%% within 45 min: %d of %d (%d%%) · the side it pointed to was right: %d of %d" % (len(mv), len(R), round(100 * len(mv) / len(R)), right,
              sum(1 for r in mv if r[2])))



# ---------------- patch 283: 👁 YOUR VIEW (Rama, 14 Nov: "PAYTM up, PATANJALI down - that is my thinking"): GIR watches the shares you have a
# view on - 👁 ✅ when it moves your way (1% / 2% / 3% today, with the checklist and its side's rule) · 👁 ⚠ when it goes 1% / 2% AGAINST you.
# python3 windwatch.py view SYM up|down|off · view (the list). Kept in data/myview.json until you turn it off.
VIEWF, VIEW_WITH, VIEW_AGAINST = os.path.join(BASE, "data", "myview.json"), (1.0, 2.0, 3.0), (1.0, 2.0)


def views():
    j = _load(VIEWF) or {}
    return {k.upper(): int(v) for k, v in (j.get("v") or {}).items() if v in (1, -1)}


def view_set(sym, how):
    j = _load(VIEWF) or {}
    v = j.get("v") or {}
    if how == "off":
        v.pop(sym.upper(), None)
    else:
        v[sym.upper()] = 1 if how == "up" else -1
    j["v"] = v
    os.makedirs(os.path.dirname(VIEWF), exist_ok=True)
    json.dump(j, open(VIEWF + ".tmp", "w")); os.replace(VIEWF + ".tmp", VIEWF)
    return views()


class View:
    def __init__(self, day):
        self.day, self.said, self.t = day, set(), 0.0
        self.v = views()

    def step(self, t, W, wind):
        """-> [(sym, view, kind 'with'/'against', level, px, chg, w)]"""
        if t - self.t > 60:
            self.t, self.v = t, views()
        out = []
        for s, vd in self.v.items():
            d = W.h.get(s)
            if not d or d[-1][2] is None:
                continue
            px, chg = d[-1][1], float(d[-1][2])
            mv = chg * vd
            for kind, levels in (("with", VIEW_WITH), ("against", VIEW_AGAINST)):
                for L in levels:
                    hit = mv >= L if kind == "with" else mv <= -L
                    if hit and (s, kind, L) not in self.said:
                        self.said.add((s, kind, L))
                        if L == max(x for x in levels if (mv >= x if kind == "with" else mv <= -x)):
                            out.append((s, vd, kind, L, px, chg, wind.get(s)))
        return out


def view_text(s, vd, kind, L, px, chg, hm, w):
    want = "▲ UP (CE)" if vd > 0 else "▼ DOWN (PE)"
    if kind == "with":
        Lx = ["👁 YOUR VIEW ✅ %s %s %+.1f%% today · %s · ₹%s" % ("▲" if vd > 0 else "▼", s, chg, hm, "{:,.2f}".format(px)),
              "moving YOUR way (%s) - %g%% today" % (want, L)]
        if w and w.get("dir") == vd:
            Lx += check_text(w); Lx.append(side_rule(w))
        Lx.append("your rules: at / 1 in the money · 11+ days to expiry · ₹1.5-3 lakh · book in 5-45 min" + (" · after 10:00: half size" if hm >= "10:00" else ""))
    else:
        Lx = ["👁 YOUR VIEW ⚠ %s %s %+.1f%% today · %s · ₹%s" % ("▲" if chg > 0 else "▼", s, chg, hm, "{:,.2f}".format(px)),
              "AGAINST your view (%s) by %g%% - if you hold it, protect it (exit or the stop); the market is saying otherwise" % (want, L)]
        if w and w.get("dir") == -vd:
            Lx += check_text(w, "WHAT IS PUSHING AGAINST YOU")
    return "\n".join(Lx)


# ---------------- patch 285: 🎯 THE COCKPIT (Rama, 14 Nov: "NIFTY at the top - rising or falling NOW, not 'today is a PE day', the market can bounce
# back · BANKNIFTY for a bank share · the futures, long build-up, the OI resistance and support, VWAP, the sector - all on one screen") ----------------
# Every 3 s -> data/cockpit.json for /cockpit: NIFTY / BANKNIFTY NOW (rising / falling / sideways: vs its open and its last 15 min, a change must
# hold 3 readings) · one box per watch-list share (👁 YOUR VIEW, + the newest 🚀 / 🌪 when fewer than 4): its index, its sector, the futures
# build-up (and whether the money is still coming), VWAP, the walls (R1 R2 S1 S2 with today's change), the writers, the 5-minute break, volume,
# IV, the score and TRADE / SMALL / SKIP. 🔄 NIFTY TURNED to GIR Bigmovers when NIFTY flips rising <-> falling and holds 1 min (8 a day at most).
import re as _re
CK_F = os.path.join(BASE, "data", "cockpit.json")
CK_TURN_HOLD, CK_TURN_MAX, CK_ROOM = 60, 8, 1.5
CK_BOXES, CK_ASK_KEEP = 5, 120                                                    # patch 299: 5 boxes · a page's ask kept 2 min (the page renews it)
CK_ASKF = os.path.join(BASE, "data", "cockpit_ask.json")
SEC_IDX = [(r"\bPSU BANK", "NIFTY PSU BANK"), (r"\bPRIVATE BANK|\bPVT BANK", "NIFTY PVT BANK"), (r"\bBANK", "NIFTY BANK"), (r"\bCAPITAL MARKET|\bBROK|\bEXCHANGE", "NIFTY CAPITAL MKT"),
           (r"\bNBFC|\bFINANC|\bINSUR|\bLENDER", "NIFTY FIN SERVICE"), (r"\bCAPITAL GOODS|\bINFRA|\bCEMENT|\bCONSTRUCT", "NIFTY INFRA"), (r"\bIT\b|\bSOFTWARE|\bTECH", "NIFTY IT"),
           (r"\bPHARMA", "NIFTY PHARMA"), (r"\bHEALTH|\bHOSPITAL", "NIFTY HEALTHCARE"), (r"\bAUTO", "NIFTY AUTO"), (r"\bFMCG|\bCONSUMER STAPLE", "NIFTY FMCG"),
           (r"\bMETAL|\bMINING|\bSTEEL", "NIFTY METAL"), (r"\bREALTY|\bREAL ESTATE", "NIFTY REALTY"), (r"\bOIL|\bGAS", "NIFTY OIL AND GAS"), (r"\bENERGY|\bPOWER", "NIFTY ENERGY"),
           (r"\bMEDIA", "NIFTY MEDIA"), (r"\bCHEMIC", "NIFTY CHEMICALS"), (r"\bDURABLE", "NIFTY CONSR DURBL")]
_DS = {"m": 0.0, "v": {}}


def dash_state():
    """dash_state.json (the engine, every second): the NSE sector indices (every 15 s) - read only when it changed"""
    p = os.path.join(BASE, "dash_state.json")
    try:
        m = os.path.getmtime(p)
        if m != _DS["m"]:
            _DS.update({"m": m, "v": json.load(open(p))})
    except Exception:
        pass
    return _DS["v"] or {}


def sec_index(sec):
    for rx, nm in SEC_IDX:
        if sec and _re.search(rx, sec.upper()):
            return nm
    return None


class Cockpit:
    def __init__(self, day):
        self.day = day
        self.idxh, self.open, self.state, self.since, self.cand = {}, {}, {}, {}, {}
        self.f5, self.vw, self.oi0, self.ivc = {}, {}, {}, {}
        self.pend, self.alerted, self.turns = None, None, 0
        self.day2 = res_day2(day)                                              # patch 286
        self.op, self.vrun, self.steady_said, self.steady_n, self.steady_list, self.nif_now = {}, {}, set(), 0, [], None      # patch 288
        self.sr, self.pb_list, self.pb_seen = {}, [], {}                                   # patch 289: the second run, 📚 the playbook now
        self.push, self.push_top = {}, []                                                  # patch 290: 📏 the push for its size, every share
        self.wm_said, self.wm_n, self.wm_list, self.wb_saved = set(), 0, [], 0.0           # patch 295: 🧱 PE MONEY / CE MONEY
        self.wr_watch, self.wr_said, self.wr_nw, self.wr_nr = {}, set(), 0, 0              # patch 298: 👀 WALL WATCH / 🧱 REJECTED
        try:
            j_ = _load(WALLB_F) or {}
            if j_.get("day") == day:
                for k_, v_ in (j_.get("oi") or {}).items():
                    a_, b_, c_ = k_.split("|"); self.oi0[(a_, float(b_), c_)] = v_
        except Exception:
            pass

    def index(self, name, t, px, hm):
        """-> {px, open, p15, state, since} · state changes only after 3 readings the same"""
        if not px:
            return None
        h = self.idxh.setdefault(name, collections.deque(maxlen=600))
        if not h or h[-1][1] != px or t - h[-1][0] >= 3:
            h.append((t, px))
        if name not in self.open and hm >= "09:15":
            self.open[name] = px
        op = self.open.get(name)
        old = next((x for x in h if x[0] >= t - 900), h[0])
        p15 = (px / old[1] - 1) * 100 if old[1] else 0.0
        st = "RISING" if (op and px > op * 1.0005 and p15 >= 0) else "FALLING" if (op and px < op * 0.9995 and p15 <= 0) else "SIDEWAYS"
        if name not in self.state:
            self.state[name], self.since[name] = st, hm
        elif st != self.state[name]:
            c = self.cand.get(name)
            self.cand[name] = (st, c[1] + 1) if c and c[0] == st else (st, 1)
            if self.cand[name][1] >= 3:
                self.state[name], self.since[name] = st, hm; self.cand.pop(name, None)
        else:
            self.cand.pop(name, None)
        return {"px": round(px, 2), "open": round(op, 2) if op else None, "p15": round(p15, 2), "state": self.state[name], "since": self.since[name],
                "above_open": (px > op) if op else None}

    def turned(self, t, hm, nif):
        """🔄 NIFTY TURNED: rising <-> falling, held 1 min, after 09:20, 8 a day at most -> the text or None"""
        if not nif or hm < "09:20" or self.turns >= CK_TURN_MAX:
            return None
        st = nif["state"]
        if st == "SIDEWAYS":
            self.pend = None; return None
        if self.alerted is None:
            self.alerted = st; return None
        if st == self.alerted:
            self.pend = None; return None
        if not self.pend or self.pend[0] != st:
            self.pend = (st, t); return None
        if t - self.pend[1] < CK_TURN_HOLD:
            return None
        self.alerted, self.pend = st, None; self.turns += 1
        up = st == "RISING"
        return "🔄 NIFTY TURNED %s · NOW %s %s\nNIFTY %s · %s its open %s · last 15 min %+.2f%%\nyour open %s trades: tighten the stop or exit · new trades: the %s side" % (
            hm[:5], "▲" if up else "▼", st, "{:,.2f}".format(nif["px"]), "above" if up else "below", "{:,.2f}".format(nif["open"] or 0), nif["p15"],
            "PE" if up else "CE", "CE" if up else "PE")

    def track(self, s, d, t, hm):
        """VWAP from the 3-s samples (price x new volume) and the first 5 minutes' high / low"""
        last = d[-1]; px = last[1]; vol = last[6] if len(last) > 6 else 0
        v = self.vw.setdefault(s, {"pv": 0.0, "v": 0.0, "last": None, "from": hm})
        if vol and v["last"] is not None and vol > v["last"]:
            dv = vol - v["last"]; v["pv"] += px * dv; v["v"] += dv
        if vol:
            v["last"] = vol
        if "09:15" <= hm < "09:20":
            f = self.f5.setdefault(s, [px, px]); f[0] = max(f[0], px); f[1] = min(f[1], px)
        if hm >= "09:15":                                                      # patch 288: the open, and the time on one side of VWAP
            self.op.setdefault(s, px)
            if v.get("v"):
                sd_ = 1 if px > v["pv"] / v["v"] else -1
                r_ = self.vrun.get(s)
                if not r_ or r_[0] != sd_:
                    self.vrun[s] = (sd_, t)
            if hm <= "14:30":                                                  # patch 289: 🔁 THE SECOND RUN, both ways
                op_ = self.op[s]; vw_ = (v["pv"] / v["v"]) if v.get("v") else None
                for d_ in (1, -1):
                    r2 = self.sr.setdefault((s, d_), {"ext": None, "pull": False, "dead": False, "hit": None})
                    if r2["dead"] or r2["hit"]:
                        continue
                    if r2["ext"] is None:
                        if (px / op_ - 1) * 100 * d_ >= 1.5:
                            r2["ext"] = px
                        continue
                    if not r2["pull"]:
                        if (px - r2["ext"]) * d_ > 0:
                            r2["ext"] = px
                        elif (r2["ext"] - px) / r2["ext"] * 100 * d_ >= 0.5:
                            r2["pull"] = True
                        continue
                    if vw_ and (px - vw_) * d_ < 0:
                        r2["dead"] = True; continue                            # the pullback broke VWAP: no second run
                    if (px - r2["ext"]) * d_ > 0:
                        r2["hit"] = (t, hm[:5])

    # ---------- patch 288: 🧲 STEADY MOVE (fastreplay 3o, 30 days: a steady fall before 11:00 with a +2% short build-up - 1% under its open, under
    # VWAP 15 min: +0.36% a trade after costs, won 62%, 754 trades; 1.5% under: +0.38%, won 61%. Steady CE did not pay in those 30 days.) ----------
    def steady_state(self, s, d, t, hm, W, TU):
        """-> None or {dir, mv, doi, vmin, px, chg} when the share is in a steady move its way"""
        dq = W.h.get(s); op = self.op.get(s); b = TU.base.get(s)
        if not dq or not op or not b or dq[-1][2] is None or not dq[-1][3]:
            return None
        last = dq[-1]; px = last[1]; chg = float(last[2])
        mv = (px / op - 1) * 100 * d
        doi = (last[3] / b - 1) * 100
        r_ = self.vrun.get(s)
        vmin = (t - r_[1]) / 60 if (r_ and r_[0] == d) else 0
        if mv >= STEADY_MV and chg * d > 0 and doi >= STEADY_OI and vmin >= STEADY_VMIN:
            return {"dir": d, "mv": round(mv, 2), "doi": round(doi, 2), "vmin": int(vmin), "px": px, "chg": round(chg, 2)}
        return None

    def steady_scan(self, t, hm, W, TU, nif):
        """-> new 🧲 PE signals to ring (before 11:00, 8 a day, the biggest build-up first); CE steady moves go on the page only"""
        if not ("09:30" <= hm < STEADY_END):
            return []
        new = []
        for s in list(W.h):
            if s == "NIFTY50":
                continue
            for d in (-1, 1):
                if (s, d) in self.steady_said:
                    continue
                st = self.steady_state(s, d, t, hm, W, TU)
                if st:
                    self.steady_said.add((s, d))
                    up_, dn_, n_ = sector_day(W, s)
                    st.update({"s": s, "t": hm, "sec": [up_ if d > 0 else dn_, n_], "nifty": (nif or {}).get("state")})
                    self.steady_list.append(st)
                    if d < 0:
                        new.append(st)
        new.sort(key=lambda x: -x["doi"])
        out = []
        for st in new:
            if self.steady_n >= STEADY_MAX:
                st["note"] = "page only (8 a day)"; continue
            if st["nifty"] == "RISING":
                st["note"] = "page only - NIFTY rising (the other way lost in the test)"; continue
            self.steady_n += 1; st["note"] = "card sent"
            out.append(st)
        self.steady_list = self.steady_list[-40:]
        return out

    # ---------- patch 289: 📚 THE PLAYBOOK (Rama, 15 Nov: "we need to have the specific type for that share - if not then say no, and what is the
    # best in the full list - I need to know which one for that share"). The 10 setups that made money in the 30-day tests, ranked; for every share,
    # live: the one it is in now, the loser it is in (❌), or "none" + what is missing for the nearest one + the best share in the list now. ----------
    def pb_facts(self, s, d, t, hm, W, TU):
        dq = W.h.get(s); op = self.op.get(s)
        if not dq or dq[-1][2] is None or not op:
            return None
        last = dq[-1]; px = last[1]; chg = float(last[2]); b = TU.base.get(s)
        doi = ((last[3] / b - 1) * 100) if (last[3] and b) else None
        r_ = self.vrun.get(s)
        vmin = max(0.0, (t - r_[1]) / 60) if (r_ and r_[0] == d) else 0
        old = next((x for x in dq if x[0] >= t - 180), dq[0])
        p3 = ((px / old[1] - 1) * 100 * d) if old[1] else 0.0
        o3 = ((last[3] / old[3] - 1) * 100) if (last[3] and old[3]) else None
        f5 = self.f5.get(s)
        brk = (((px > f5[0]) if d > 0 else (px < f5[1])) if (f5 and hm >= "09:20") else None)
        r2 = self.sr.get((s, d)) or {}
        run2 = bool(r2.get("hit") and t - r2["hit"][0] <= 900 and r2["hit"][1] < "10:00" and vmin > 0)
        return {"px": px, "chg": chg, "doi": doi, "mv": (px / op - 1) * 100 * d, "vmin": vmin, "p3": p3, "o3": o3, "brk": brk, "f5": f5, "run2": run2,
                "day2": s in self.day2}

    def pb_hits(self, s, d, f, hm, nif, W):
        H = []; ns = (nif or {}).get("state")
        st_ok = f["doi"] is not None and f["chg"] * d > 0 and f["doi"] >= 2.0 and f["vmin"] >= 15
        if d < 0:
            if st_ok and "09:30" <= hm < "11:00":
                H.append(1 if f["mv"] >= 1.5 else 2 if f["mv"] >= 1.0 else 4 if f["mv"] >= 0.75 else 0)
            if st_ok and f["mv"] >= 1.0 and "09:30" <= hm < "13:00" and ns == "FALLING":
                up_, dn_, n_ = sector_day(W, s)
                if n_ and dn_ * 2 >= n_:
                    H.append(7)
            if f["run2"]:
                H.append(8)
            if "09:20" <= hm < "11:00" and f["p3"] >= 1.0 and (f["o3"] or 0) >= 0.5:
                H.append(10)
        else:
            if f["run2"]:
                H.append(3)
            if f["day2"] and f["chg"] > 0 and hm < "10:00":
                H.append(5)
            if f["chg"] >= 3.0 and "09:17" <= hm < "10:00":
                H.append(6)
            if f["brk"] and hm < "10:00" and ns == "RISING":
                H.append(9)
        return sorted(x for x in H if x)

    def pb_bad(self, d, f, hm, nif):
        if hm >= "13:00":
            return "❌ after 13:00 - every tested setting lost (-0.22% to -0.25% a trade): no new trade"
        if d < 0 and f["day2"]:
            return "❌ RESULTS DAY 2 PE - lost -0.9% a trade, won only 23-25%: the bad news is usually in the price"
        if d > 0 and (nif or {}).get("state") == "FALLING":
            return "❌ CE while NIFTY falls - lost -0.27% to -0.40% a trade"
        if d < 0 and (nif or {}).get("state") == "RISING":
            return "❌ PE while NIFTY rises - the other way lost in the test"
        if f["chg"] * d <= -3.0:
            return "❌ betting a 3% move turns back - lost in every version"
        return None

    def pb_near(self, d, f, hm, nif):
        ns = (nif or {}).get("state")
        if d < 0:
            if hm >= "11:00":
                return "the steady-fall setups are for 09:30-11:00 · until 13:00 only #7 (a steady fall with its sector AND NIFTY falling)"
            need = []
            if f["mv"] < 1.0:
                need.append("1%% under its open (now %.1f%% %s)" % (abs(f["mv"]), "under" if f["mv"] > 0 else "over"))
            if f["chg"] >= 0:
                need.append("below yesterday's close (now %+.1f%%)" % f["chg"])
            if (f["doi"] or 0) < 2.0:
                need.append("short build-up +2%% (now %s)" % ("%+.1f%%" % f["doi"] if f["doi"] is not None else "not known"))
            if f["vmin"] < 15:
                need.append("15 min under VWAP (now %d)" % f["vmin"])
            if hm < "09:30":
                need.append("09:30")
            return "nearest: #2 🧲 STEADY FALL - needs " + " · ".join(need)
        if hm >= "10:00":
            return "no tested CE setup after 10:00 - all the CE winners are before 10:00"
        need = []
        if ns != "RISING":
            need.append("NIFTY rising (now %s)" % (ns or "not known").lower())
        if not f["brk"]:
            need.append("a break over its first 5-min high%s" % (" ₹{:,.2f}".format(f["f5"][0]) if f["f5"] else " (from 09:20)"))
        return "nearest: #9 📈 OPENING 5-min BREAK CE - needs " + " · ".join(need or ["-"])

    def play(self, s, d, t, hm, W, TU, nif, near=True):
        """-> None or {hits, rank, name, tested, bad, near} - which tested setup this share-side is in right now"""
        f = self.pb_facts(s, d, t, hm, W, TU)
        if not f:
            return None
        H = self.pb_hits(s, d, f, hm, nif, W)
        out = {"hits": H, "bad": self.pb_bad(d, f, hm, nif)}
        if H:
            p_ = PB_BY[H[0]]; out.update({"rank": p_[0], "name": p_[2], "tested": p_[4], "short": p_[5]})
        elif near:
            out["near"] = self.pb_near(d, f, hm, nif)
        return out

    def push_all(self, t, W, TU):
        """📏 every F&O share: new futures shares since the open ÷ a normal whole day's shares -> self.push {s: (x, rank, n, ₹ cr, price %)}"""
        P, built = {}, 0
        for s, d in list(W.h.items()):
            if s == "NIFTY50" or not d:
                continue
            last = d[-1]; b = TU.base.get(s)
            if not (last[3] and b):
                continue
            if s not in _DN["v"] or _DN["day"] != str(dt.datetime.fromtimestamp(t, IST).date()):
                if built >= PUSH_BUILD:
                    continue                                                   # the normal day of 25 new shares a round - all in within ~30 s
                built += 1
            nd = day_normal(s, t)
            if not nd:
                continue
            P[s] = ((last[3] - b) / nd, (last[3] - b) * last[1] / 1e7, None if last[2] is None else float(last[2]))
        order = sorted(P, key=lambda k_: -P[k_][0]); n = len(order)
        self.push = {s: (round(P[s][0], 3), i + 1, n, round(P[s][1], 1), P[s][2]) for i, s in enumerate(order)}
        self.push_top = [{"s": s, "x": self.push[s][0], "r": self.push[s][1], "n": n, "cr": self.push[s][3], "dir": 1 if (P[s][2] or 0) >= 0 else -1}
                         for s in order[:8] if P[s][0] > 0]
        return self.push

    def pb_scan(self, t, hm, W, TU, nif):
        """every F&O share, both ways -> self.pb_list: the shares in a tested winner right now, the best rank first"""
        L = []
        for s in list(W.h):
            if s == "NIFTY50":
                continue
            for d in (1, -1):
                try:
                    r = self.play(s, d, t, hm, W, TU, nif, near=False)
                except Exception:
                    r = None
                if not r or not r["hits"] or r["bad"]:
                    continue
                k_ = (s, d, r["rank"])
                self.pb_seen.setdefault(k_, hm[:5])
                L.append({"s": s, "dir": d, "side": "CE" if d > 0 else "PE", "rank": r["rank"], "short": r["short"], "tested": r["tested"],
                          "since": self.pb_seen[k_], "also": r["hits"][1:]})
        L.sort(key=lambda x: (x["rank"], x["since"]))
        self.pb_list = L[:12]
        _PBCTX.update({"ck": self, "W": W, "TU": TU})
        return self.pb_list

    # ---------- patch 295: 🧱 PE MONEY / CE MONEY (Rama, 15 Nov: "MANAPPURAM on the 13th - a big 320 CE wall and the futures betting ₹103 cr it
    # will fall, and it fell 3.7%; TMPV the same. That's the clear signal - these should be prioritised, and you check all the F&O and tell me
    # immediately"). Every F&O share, every 3 s: the futures betting one way (a build-up of OI +2% since the open, the price 0.5%+ that way) AND
    # the option writers' wall on the other side close by (the biggest call wall within 3% above for a PE - writers adding 10%+ today - or the
    # biggest put wall within 3% below for a CE) AND the price on its side of VWAP 5+ min AND NIFTY not against it. Rings once a share-side a
    # day, 10 a day at most, 09:30-14:30, the biggest build-up first. Not tested over history yet (no free option history - GIR keeps it now).
    def wall_seed(self, O, t):
        """the day's first OI of every pinned strike (the walls' "today" baseline), kept in data/wall_base.json"""
        new = False
        for s, dq in O.h.items():
            if dq:
                for key, oi in dq[-1][1].items():
                    if (s,) + key not in self.oi0 and oi:
                        self.oi0[(s,) + key] = oi; new = True
        if new and t - self.wb_saved >= 60:
            try:
                json.dump({"day": self.day, "oi": {"%s|%g|%s" % k_: v for k_, v in self.oi0.items()}}, open(WALLB_F + ".tmp", "w"), separators=(",", ":"))
                os.replace(WALLB_F + ".tmp", WALLB_F); self.wb_saved = t
            except Exception:
                pass

    def wallmoney_scan(self, t, hm, W, TU, O, nif, BT=None):
        """-> the new 🧱 signals to ring (the rest go on the page list)"""
        if not ("09:30" <= hm[:5] <= WALLM_END):
            return []
        new, ns = [], (nif or {}).get("state")
        for s in list(W.h):
            if s == "NIFTY50":
                continue
            dq = W.h.get(s)
            if not dq or dq[-1][2] is None:
                continue
            last = dq[-1]; px = last[1]; chg = float(last[2]); b = TU.base.get(s)
            if not (last[3] and b):
                continue
            doi = (last[3] / b - 1) * 100
            if doi < WALLM_OI or abs(chg) < WALLM_PX:
                continue
            d = 1 if chg > 0 else -1
            if (s, d) in self.wm_said or ns == ("RISING" if d < 0 else "FALLING"):
                continue
            r_ = self.vrun.get(s)
            vmin = (t - r_[1]) / 60 if (r_ and r_[0] == d) else 0
            if vmin < WALLM_VMIN:
                continue
            wl = self.walls(s, O, px, d)
            side = (wl or {}).get("R" if d < 0 else "S") or []
            if not side:
                continue
            w = max(side, key=lambda x: x["oi"])
            if not (0 < w["pct"] <= WALLM_DIST and (w["ch"] or 0) >= WALLM_ADD):
                continue
            other = (wl.get("S") if d < 0 else wl.get("R")) or []
            fl = min(other, key=lambda x: x["pct"]) if other else None
            want, since = ("SHORT BUILD-UP" if d < 0 else "LONG BUILD-UP"), None
            L_ = ((BT.log.get(s) if BT is not None else None) or [])
            if L_ and L_[-1][1] == want:
                since = L_[-1][0]
            up_, dn_, n_ = sector_day(W, s)
            pu = self.push.get(s)
            x = {"s": s, "dir": d, "t": hm[:5], "px": round(px, 2), "chg": round(chg, 2), "doi": round(doi, 2), "cr": round((last[3] - b) * px / 1e7, 1),
                 "vmin": int(vmin), "wall": [w["k"], w["oi"], w["ch"], w["pct"]], "floor": [fl["k"], fl["pct"]] if fl else None, "since": since,
                 "nifty": ns, "sec": [dn_ if d < 0 else up_, n_], "push": [pu[0], pu[1], pu[2]] if pu else None}
            self.wm_said.add((s, d)); self.wm_list.append(x); new.append(x)
        new.sort(key=lambda x: -x["doi"])
        out = []
        for x in new:
            if self.wm_n >= WALLM_MAX:
                x["note"] = "page only (%d a day)" % WALLM_MAX; continue
            self.wm_n += 1; x["note"] = "card sent"; out.append(x)
        self.wm_list = self.wm_list[-40:]
        return out

    # ---------- patch 298: 👀 WALL WATCH -> 🧱 REJECTED AT THE WALL (Rama, 15 Nov: "go, threshold + wall rejection. First it has to alert that the
    # share is going close to the wall - at 0.5% - not when it is already there and I don't have time to complete the trade"). The wall = the
    # biggest call (or put) OI within 3% of the price, grown 30%+ today. STAGE 1 👀 WATCH: the price within 0.5% of it (either side) with new
    # futures money (OI +1% since the open) -> rings with the trade card ready. STAGE 2 🧱 REJECTED: within 20 min of that, the price turns back
    # to the other side of VWAP, 0.3%+ away from the wall, NIFTY not against it -> 🧱 BUY PE (off a call wall) / BUY CE (off a put floor).
    # MANAPPURAM 13 Nov: at the 320 CE wall 09:23-09:27, rejected 09:28 at ~₹315. Tuned on that one day - half size, watch the evening cards.
    def wall_near(self, s, O, px, kind):
        dq = O.h.get(s)
        if not dq:
            return None
        best = None
        for (k_, kd), oi in dq[-1][1].items():
            if kd != kind or not oi or abs(k_ / px - 1) * 100 > 3.0:
                continue
            o0 = self.oi0.get((s, k_, kd))
            if best is None or oi > best[1]:
                best = (k_, oi, ((oi / o0 - 1) * 100) if o0 else 0.0)
        return best

    def wallrej_scan(self, t, hm, W, TU, O, nif):
        """-> (the new 👀 WATCH alerts, the new 🧱 REJECTED alerts)"""
        if not (WR_FROM <= hm[:5] <= WR_END):
            return [], []
        ns, watch, rej = (nif or {}).get("state"), [], []
        for s in list(W.h):
            if s == "NIFTY50":
                continue
            dq = W.h.get(s)
            if not dq or dq[-1][2] is None:
                continue
            last = dq[-1]; px = last[1]; chg = float(last[2]); b = TU.base.get(s)
            if not (last[3] and b):
                continue
            doi = (last[3] / b - 1) * 100
            v = self.vw.get(s) or {}
            vwap = (v["pv"] / v["v"]) if v.get("v") else None
            if doi < WR_OI or not vwap:
                continue
            for d, kind in ((-1, "CE"), (1, "PE")):
                w = self.wall_near(s, O, px, kind)
                if not w or w[2] < WR_GROW:
                    continue
                dist = (w[0] / px - 1) * 100                                   # + the wall above the price, - below
                key = (s, d)
                x = {"s": s, "dir": d, "t": hm[:5], "px": round(px, 2), "chg": round(chg, 2), "doi": round(doi, 2), "vwap": round(vwap, 2),
                     "wall": [w[0], w[1], round(w[2]), round(abs(dist), 2)]}
                if abs(dist) <= WR_NEAR:
                    first_ = (s, d, "watch") not in self.wr_said
                    self.wr_watch[key] = (t, w[0])
                    if first_:
                        self.wr_said.add((s, d, "watch"))
                        if self.wr_nw < WR_MAXW:
                            self.wr_nw += 1; x["note"] = "👀 watch - at the wall"; watch.append(x)
                        else:
                            x["note"] = "👀 watch (page only, %d a day)" % WR_MAXW
                        self.wm_list.append(x)
                    continue
                wt = self.wr_watch.get(key)
                if not wt or t - wt[0] > WR_WIN or wt[1] != w[0] or (s, d, "rej") in self.wr_said or (s, d) in self.wm_said:
                    continue
                away = dist * (-d)                                             # PE: the wall above us · CE: the floor below us
                if (px - vwap) * d > 0 and away >= WR_AWAY and ns != ("RISING" if d < 0 else "FALLING"):
                    self.wr_said.add((s, d, "rej")); self.wm_said.add((s, d))
                    if self.wr_nr < WR_MAXR:
                        self.wr_nr += 1; x["note"] = "🧱 rejected at the wall"; rej.append(x)
                    else:
                        x["note"] = "🧱 rejected (page only, %d a day)" % WR_MAXR
                    self.wm_list.append(x)
        self.wm_list = self.wm_list[-40:]
        return watch, rej

    def walls(self, s, O, px, d):
        dq = O.h.get(s)
        if not dq:
            return None
        m = dq[-1][1]
        for key, oi in m.items():
            self.oi0.setdefault((s,) + key, oi)
        ch = lambda k_, kd: ((m[(k_, kd)] / self.oi0[(s, k_, kd)] - 1) * 100) if self.oi0.get((s, k_, kd)) else None
        calls = sorted([(oi, k_) for (k_, kd), oi in m.items() if kd == "CE" and k_ > px], reverse=True)
        puts = sorted([(oi, k_) for (k_, kd), oi in m.items() if kd == "PE" and k_ < px], reverse=True)
        R = [{"k": k_, "oi": oi, "pct": round((k_ / px - 1) * 100, 1), "ch": None if ch(k_, "CE") is None else round(ch(k_, "CE"))} for oi, k_ in sorted(calls[:2], key=lambda x: x[1])]           # R1 = the nearer of the two biggest call walls
        S_ = [{"k": k_, "oi": oi, "pct": round((1 - k_ / px) * 100, 1), "ch": None if ch(k_, "PE") is None else round(ch(k_, "PE"))} for oi, k_ in sorted(puts[:2], key=lambda x: -x[1])]          # S1 = the nearer of the two biggest put walls
        ca = sum(oi - self.oi0.get((s, k_, kd), oi) for (k_, kd), oi in m.items() if kd == "CE" and px < k_ <= px * 1.06)
        pa = sum(oi - self.oi0.get((s, k_, kd), oi) for (k_, kd), oi in m.items() if kd == "PE" and px * 0.94 <= k_ < px)
        lean = 1 if (pa > ca and pa > 0) else -1 if (ca > pa and ca > 0) else 0
        return {"R": R, "S": S_, "lean": lean}

    def iv(self, s, O, px, t, side):
        c = self.ivc.get(s)
        if c and t - c[0] < 60:
            return c[1]
        out = None
        try:
            now = O.now.get(s) or {}
            exs = sorted({k_[0] for k_ in now})
            if exs:
                ex = exs[0]; ks = sorted({k_[1] for k_ in now if k_[0] == ex})
                K = min(ks, key=lambda k_: abs(k_ - px)); P = now.get((ex, K, side))
                if P:
                    import posguard as PG, movecard as MC
                    T = max((dt.datetime.combine(dt.date.fromisoformat(ex), dt.time(15, 30), IST) - dt.datetime.now(IST)).total_seconds() / (365 * 86400), 1e-4)
                    v = PG.iv(P, px, K, T, side); rv = MC.rv20(s, dt.datetime.now(IST).date())
                    out = {"iv": round(v * 100), "rv": round(rv * 100) if rv else None, "k": K,
                           "word": ("EXPENSIVE" if rv and v / rv >= 1.3 else "cheap" if rv and v / rv <= 0.9 else "fair") if rv else None}
        except Exception:
            out = None
        self.ivc[s] = (t, out)
        return out

    def box(self, s, vd, t, hm, W, TU, O, nif, bank, sidx, how):
        d = W.h.get(s)
        if not d or d[-1][2] is None:
            return None
        last = d[-1]; px, chg = last[1], float(last[2])
        side = "CE" if vd > 0 else "PE"
        b = TU.base.get(s)
        doi = ((last[3] / b - 1) * 100) if (last[3] and b) else None
        kind = day_kind(chg, doi)
        old = next((r for r in d if r[0] >= t - 180), d[0])
        oi3 = ((last[3] / old[3] - 1) * 100) if (last[3] and old[3]) else None
        cr = round((last[3] - b) * px / 1e7, 1) if (last[3] and b) else None
        v = self.vw.get(s) or {}
        vwap = (v["pv"] / v["v"]) if v.get("v") else None
        f5 = self.f5.get(s)
        nm = vol_normal(s, dt.datetime.combine(dt.datetime.now(IST).date(), dt.time(9, 15), IST).timestamp(), t) if (len(last) > 6 and last[6]) else None
        vr = (last[6] / nm) if nm else None
        wl = self.walls(s, O, px, vd)
        up_, dn_, n_ = sector_day(W, s)
        sec = W.of.get(s); si = sec_index(sec)
        sic = (sidx.get(si) or {}).get("chg") if si else None
        bankish = bool(si and "BANK" in si)
        C = []
        mk_ok = nif and ((nif["state"] == "RISING") if vd > 0 else (nif["state"] == "FALLING"))
        C.append(("market", bool(mk_ok), "NIFTY %s - %s your %s" % ((nif or {}).get("state", "?").lower(), "with" if mk_ok else "against" if nif and nif["state"] != "SIDEWAYS" else "no help for", side)))
        if bankish and bank:
            bk_ok = (bank["state"] == "RISING") if vd > 0 else (bank["state"] == "FALLING")
            C.append(("bank", bool(bk_ok), "BANKNIFTY %s" % bank["state"].lower()))
        sec_ok = bool(n_) and ((up_ if vd > 0 else dn_) * 2 >= n_)
        solo = bool(n_) and ((dn_ if vd > 0 else up_) * 2 >= n_ and (dn_ if vd > 0 else up_) >= 2)
        C.append(("sector", sec_ok, "%s %s (%d of %d)%s%s" % (sec or "its sector", "with it" if sec_ok else ("against it - SOLO MOVE" if solo else "mixed"), (up_ if vd > 0 else dn_), n_,
                                                             (" · %s %+.2f%%" % (si, sic)) if sic is not None else "", "")))
        fut_ok = kind == ("LONG BUILD-UP" if vd > 0 else "SHORT BUILD-UP")
        kw = {"LONG BUILD-UP": "LONG BUILD-UP · new buyers", "SHORT BUILD-UP": "SHORT BUILD-UP · new sellers", "SHORT COVERING": "SHORT COVERING · sellers running (weak)",
              "LONG UNWINDING": "LONG UNWINDING · buyers leaving (weak)"}.get(kind, "no clear futures money yet")
        pu = self.push.get(s)                                                  # patch 290: 📏 the push for its size
        C.append(("futures", fut_ok, "%s%s%s%s%s" % (kw, (" · ₹%s cr" % cr) if cr is not None else "", (" · OI %+.1f%%" % doi) if doi is not None else "",
                                                     (" · still coming" if (oi3 is not None and oi3 > 0.2) else " · slowing" if oi3 is not None else ""),
                                                     (" · 📏 " + push_text(pu[0], pu[1], pu[2])) if pu else "")))
        vw_ok = vwap is not None and (px - vwap) * vd > 0
        C.append(("vwap", vw_ok, ("VWAP %s · price %.1f%% %s (%s in control)" % ("{:,.2f}".format(vwap), abs(px / vwap - 1) * 100, "above" if px > vwap else "below",
                                                                              "buyers" if px > vwap else "sellers")) if vwap else "VWAP: not enough trades yet"))
        room = None; wall_ok = False
        if wl:
            near = (wl["R"] if vd > 0 else wl["S"])
            room = min((x["pct"] for x in near), default=None)
            wall_ok = (wl["lean"] == vd) and (room is None or room >= CK_ROOM)
            C.append(("walls", wall_ok, "writers %s%s" % ({1: "back a RISE (puts added below)", -1: "back a FALL (calls added above)", 0: "no clear side"}[wl["lean"]],
                                                          (" · room %.1f%% to the %s%s" % (room, "roof" if vd > 0 else "floor", " - close ⚠" if room < CK_ROOM else "")) if room is not None else "")))
        else:
            C.append(("walls", False, "walls: no option data yet"))
        score = sum(1 for k_, ok, _ in C if ok and k_ in ("market", "sector", "futures", "vwap", "walls"))
        verdict = "TRADE" if (score >= 4 and mk_ok and fut_ok) else "SMALL" if (score == 3 and mk_ok) else "SKIP"     # patch 286: NIFTY against -> SKIP
        day2 = s in self.day2
        steady = self.steady_state(s, vd, t, hm, W, TU) if hm < STEADY_END else None                                   # patch 288
        if verdict == "TRADE" and (vd < 0 or hm >= "10:00") and not (steady and vd < 0):
            verdict = "SMALL"                                                  # patch 286: PE / after 10:00 - at most SMALL (288: a steady PE before 11:00 may TRADE)
        if vd < 0 and day2:
            verdict = "SKIP"                                                   # patch 286: results day 2 PE lost in the test
        brk = None
        if f5:
            brk = (px > f5[0]) if vd > 0 else (px < f5[1])
        ivx = self.iv(s, O, px, t, side)
        good, warn = tested(side, hm, (nif or {}).get("state"), day2, score, brk, chg, steady)
        bq, sq_ = (last[4] if len(last) > 4 else 0), (last[5] if len(last) > 5 else 0)
        book = (bq / sq_) if (bq and sq_) else None                            # patch 288: the order book (total buyers / sellers waiting)
        pb = self.play(s, vd, t, hm, W, TU, nif)                                # patch 289: 📚 the playbook for this share
        if pb is not None:
            bst = next((x for x in self.pb_list if x["s"] != s), None)
            pb["best"] = bst
        tgt = None
        if wl:
            tw = (wl["R"] if vd > 0 else wl["S"])
            tgt = min(tw, key=lambda x: x["pct"])["k"] if tw else None
        return {"s": s, "side": side, "dir": vd, "how": how, "px": round(px, 2), "chg": round(chg, 2), "checks": [[k_, ok, tx] for k_, ok, tx in C], "score": score,
                "verdict": verdict, "walls": wl, "f5": f5, "brk": brk, "vr": None if vr is None else round(vr, 1), "iv": ivx, "vwap": None if vwap is None else round(vwap, 2),
                "vwap_from": v.get("from"), "stop": round(px * (1 - 0.02 * vd), 2), "half": round(px * (1 + 0.02 * vd), 2), "target": tgt,
                "strike": (ivx or {}).get("k"), "bankish": bankish, "index": si, "index_chg": sic, "good": good, "warn": warn, "day2": day2,
                "book": None if book is None else round(book, 2), "book_ok": None if book is None else (book >= BOOK_X if vd > 0 else book <= 1 / BOOK_X), "steady": steady, "play": pb,
                "push": ({"x": pu[0], "r": pu[1], "n": pu[2], "word": push_word(pu[0], pu[1], pu[2])} if pu else None)}

    def write(self, t, hm, W, TU, O, MO, BL, LD):
        Q = W.h.get("NIFTY50")
        nif = self.index("NIFTY", t, Q[-1][1], hm) if Q else None
        self.nif_now = nif
        ds = dash_state(); sidx = ds.get("sidx") or {}
        bk = (sidx.get("NIFTY BANK") or {}).get("last") or ((ds.get("idx") or {}).get("BANKNIFTY") or {}).get("last")
        bank = self.index("BANKNIFTY", t, float(bk), hm) if bk else None
        for s, d in W.h.items():
            if d and s != "NIFTY50":
                self.track(s, d, t, hm)
        try:
            self.wall_seed(O, t)                                               # patch 295: the walls' morning baseline
        except Exception:
            pass
        try:
            self.push_all(t, W, TU)                                            # patch 290
        except Exception as ex:
            print("push: %s" % str(ex)[:80], flush=True)
        try:
            self.pb_scan(t, hm, W, TU, nif)                                    # patch 289
        except Exception as ex:
            print("playbook: %s" % str(ex)[:80], flush=True)
        want = dict(views())                                                   # patch 299: your views, then the latest alerts - 🧱 first - 5 in all
        cand = [x for x in reversed(self.wm_list) if "watch" not in (x.get("note") or "")] + \
               [x for x in reversed(self.steady_list) if x.get("note") == "card sent"] + list(reversed((MO.list or []) + (BL or [])))
        for x in cand:
            if len(want) >= CK_BOXES:
                break
            want.setdefault(x["s"], x["dir"])
        boxes = []
        for s, vd in want.items():
            try:
                bx = self.box(s, vd, t, hm, W, TU, O, nif, bank, sidx, "your view" if s in views() else "GIR spotted")
            except Exception as ex:
                bx = None; print("cockpit %s: %s" % (s, str(ex)[:80]), flush=True)
            if bx:
                boxes.append(bx)
        mk = [sum(1 for s, d in W.h.items() if d and s != "NIFTY50" and d[-1][2] is not None and d[-1][2] > 0), 0, 0]
        mk[2] = sum(1 for s, d in W.h.items() if d and s != "NIFTY50" and d[-1][2] is not None); mk[1] = mk[2] - mk[0]
        secs = sorted([(v.get("chg"), k_) for k_, v in sidx.items() if v.get("chg") is not None], reverse=True)
        try:
            st = _load(os.path.join(BASE, "data", "posguard_state.json")) or {}
            pos = {"open": [k_ for k_, q in (st.get("qty") or {}).items() if q] if st.get("day") == self.day else [],
                   "losses": len(st.get("lost") or {}) if st.get("day") == self.day else 0}
        except Exception:
            pos = {"open": [], "losses": 0}
        ask = {}                                                               # patch 299: a share's own page asked for its cockpit
        try:
            A_ = _load(CK_ASKF) or {}
            for s_, ta in sorted(A_.items(), key=lambda x: -x[1])[:6]:
                if t - float(ta) <= CK_ASK_KEEP and s_ in W.h and s_ != "NIFTY50":
                    d_ = W.h[s_]
                    vd_ = views().get(s_) or (1 if (d_ and d_[-1][2] is not None and float(d_[-1][2]) >= 0) else -1)
                    bx_ = self.box(s_, vd_, t, hm, W, TU, O, nif, bank, sidx, "asked from its page")
                    if bx_:
                        ask[s_] = bx_
        except Exception as ex:
            print("cockpit ask: %s" % str(ex)[:80], flush=True)
        out = {"t": round(t, 1), "hm": hm, "nifty": nif, "bank": bank, "mk": mk, "ask": ask, "sectors": [[k_, c] for c, k_ in secs[:4]] + [[k_, c] for c, k_ in secs[-3:]],
               "boxes": boxes, "big": (BL or [])[-6:], "mom": (MO.list or [])[-6:], "load": [x for x in (LD.list or []) if x.get("res") is None][-6:], "pos": pos,
               "steady": self.steady_list[-10:], "pb": self.pb_list,
               "pb_all": [list(p_[:5]) for p_ in PLAYBOOK], "pb_avoid": PB_AVOID, "push_top": self.push_top, "wm": self.wm_list[-12:]}
        json.dump(out, open(CK_F + ".tmp", "w"), separators=(",", ":"), default=str); os.replace(CK_F + ".tmp", CK_F)
        return self.turned(t, hm, nif)



# ---------------- patch 286 (Rama, 14 Nov: "out of all the strategies we tested, the best ones we should keep - give me a message and a warning").
# fastreplay.py, 30 days (30 Sep - 13 Nov), NSE prices, after ~0.20% costs, split by what NIFTY said at 09:30 (regime.py):
#   BEST  opening 5-min break CE with NIFTY up at 09:30 +0.18% a trade (754, won 50%) · momentum before 10:00 CE: kept going 33%, turned back 11%
#         (Nov) · second run CE before 10:00: kept going 32%, held +0.35% · CE with a 4-5 score +0.30%, with news +0.29% · results day 2 CE +0.16%
#   AVOID CE with NIFTY down at 09:30 (-0.27% to -0.40%) · results day 2 PE (-0.9%, won 23-25%) · fading a 3% move (lost in every version) ·
#         after 10:00 (kept going 9-11% vs 32-37% before) · PE with a 4-5 score (-0.29%) - no reliable morning PE edge in 30 days ----------------
def res_day2(day):
    """the shares whose results came the day before (or the evening before) - today is their DAY 2"""
    try:
        d = dt.date.fromisoformat(day); p = d - dt.timedelta(days=1)
        while p.weekday() > 4:
            p -= dt.timedelta(days=1)
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        out = {r[0] for r in c.execute("select sym from results_cal where d=?", (str(p),))}
        c.close(); return out
    except Exception:
        return set()


def tested(side, hm, nst, day2, score=None, brk=None, chg=None, steady=None):
    """-> (✅ lines, ⚠ / ❌ lines) - what the 30-day test said about this kind of trade"""
    G, Wn = [], []
    early = hm < "10:00"
    up = side == "CE"
    if up:
        if steady:
            Wn.append("⚠ STEADY CE did not pay in the 30 days (best +0.09% before 11:00) - small size")
        if nst == "FALLING":
            Wn.append("❌ CE while NIFTY falls: lost -0.27% to -0.40% a trade in the test - skip")
        if early and brk and nst == "RISING":
            G.append("✅ OPENING 5-min BREAK CE with NIFTY rising: +0.18% a trade after costs, won 50% (754 trades)")
        if early and chg is not None and chg >= 3.0:
            G.append("✅ MOMENTUM before 10:00 CE: kept going 33%, turned back 11%")
        if day2 and chg is not None and chg > 0:
            G.append("✅ RESULTS DAY 2 CE: +0.16% a trade after costs - better with news")
        if score is not None and score >= 4:
            G.append("✅ a 4-5 score on CE: held +0.30% (second-run test)")
    else:
        if steady and hm < STEADY_END:                                         # patch 288
            G.append("✅ STEADY PE before 11:00 with a +2% short build-up: +0.36% a trade after costs, won 62% (754 trades) ≈ +4% on the premium")
        if day2:
            Wn.append("❌ RESULTS DAY 2 PE: lost -0.9% a trade, won only 23-25% - the bad news is usually already in the price")
        if not steady:
            Wn.append("⚠ PE without a steady move: no reliable edge in 30 days - small size, quick profit")
        if score is not None and score >= 4:
            Wn.append("⚠ a high score did not help PE in the test (-0.29%)")
    if hm >= "13:00":
        Wn.append("❌ after 13:00: every steady and burst setting lost (-0.22% to -0.25%) - skip")
    elif not early:
        Wn.append("⚠ after 10:00: moves kept going 9-11% vs 32-37% before 10:00 - small size")
    return G, Wn


STEADY_MV, STEADY_OI, STEADY_VMIN, STEADY_END, STEADY_MAX = 1.0, 2.0, 15, "11:00", 8
WALLM_OI, WALLM_PX, WALLM_DIST, WALLM_ADD, WALLM_VMIN, WALLM_MAX, WALLM_END = 1.5, 0.5, 3.0, 10.0, 5, 10, "14:30"     # patch 295 · 298: futures +1.5% (was 2%)
WR_NEAR, WR_GROW, WR_OI, WR_AWAY, WR_WIN, WR_FROM, WR_END, WR_MAXW, WR_MAXR = 0.5, 30.0, 1.0, 0.3, 1200, "09:20", "14:30", 12, 10    # patch 298
WALLB_F = os.path.join(BASE, "data", "wall_base.json")


def wallmoney_text(x, hm, card=None):
    """🧱 PE MONEY ▼ / CE MONEY ▲ - the futures, the writers' wall and VWAP all the same way"""
    up = x["dir"] > 0
    w = x["wall"]
    L = ["🧱 %s MONEY %s %s · %s · ₹%s (%+.1f%% today) · PRIORITY: the futures AND the option writers the same way" % ("CE" if up else "PE", "▲" if up else "▼", x["s"], hm,
         "{:,.2f}".format(x["px"]), x["chg"]),
         "the futures bet %s: %s%s · futures OI %+.1f%% since the open (₹%s cr)%s" % ("UP" if up else "DOWN", "long build-up" if up else "short build-up",
             (" since %s" % x["since"]) if x.get("since") else "", x["doi"], "{:,.0f}".format(abs(x["cr"])),
             (" · 📏 %sx its normal day, #%d of %d" % (("%.2f" if abs(x["push"][0]) >= 0.1 else "%.3f") % x["push"][0], x["push"][1], x["push"][2])) if x.get("push") else ""),
         "the %s: %g %s %.1f L (%+.0f%% today) only %.1f%% %s - the %s writers bet it %s" % ("floor" if up else "roof", w[0], "PE" if up else "CE", w[1] / 1e5, w[2] or 0, w[3],
             "below" if up else "above", "put" if up else "call", "stays above" if up else "stays below"),
         "%s VWAP for %d min · NIFTY %s · its sector %d of %d %s%s" % ("above" if up else "below", x["vmin"], (x.get("nifty") or "?").lower(), x["sec"][0], x["sec"][1],
             "up" if up else "down", (" · the %s: %g, %.1f%% %s (room to run)" % ("roof" if up else "floor", x["floor"][0], x["floor"][1], "above" if up else "below")) if x.get("floor") else "")]
    if hm[:5] >= "13:00":
        L.append("⚠ after 13:00 - late moves lost in the 30-day test: smaller size, a quick profit")
    L.append("TESTED: not over history yet (the option walls have no free history) - GIR keeps them from now; watch how these end in the evening cards")
    if card:
        L += list(card)
    L.append("plan: let it run · out if it closes back %s VWAP or %s the %s (%g) · same day: out by 15:15" % ("under" if up else "over", "under" if up else "over",
             "floor" if up else "roof", w[0]))
    return "\n".join(L)


def _send_wallm(x, hm_, now_):
    up = x["dir"] > 0; w = x["wall"]
    _, pick = card_lines(x["s"], "CE" if up else "PE", float(w[0]), now_)
    why = "futures %s ₹%s cr + %g %s %s %.1f%% %s + %s VWAP" % ("buying" if up else "selling", "{:,.0f}".format(abs(x["cr"])), w[0], "PE" if up else "CE",
                                                        "floor" if up else "wall", w[3], "below" if up else "above", "over" if up else "under")
    send_big(short_card("🧱", x["s"], x["dir"], x["px"], x["chg"], hm_, why, pick, float(w[0])))


# ---------------- patch 296: SHORT CARDS (Rama, 15 Nov: "too much information in the card - before I read the card the stock will react").
# Every 🧱 / 🧲 / 🌪 / 🚀 card is now 3 lines: WHAT to buy · WHY in one line · the exact option and the exit - plus one ⚠ line only when it
# matters (a tested loser, NIFTY against, after 13:00). All the detail stays on the 🎯 cockpit.
def pb_short(s, d, hm):
    """-> (the playbook tag for line 1, one warning line or None)"""
    tag, warn = "", None
    c = _PBCTX.get("ck")
    try:
        r = c.play(s, d, time.time(), dt.datetime.now(IST).strftime("%H:%M"), _PBCTX["W"], _PBCTX["TU"], c.nif_now) if c is not None else None
    except Exception:
        r = None
    if r:
        if r.get("bad"):
            warn = "⚠ " + r["bad"].replace("❌ ", "").split(" - ")[0] + " - skip or small"
        elif r.get("rank"):
            tag = " · 📚#%d" % r["rank"]
    if not warn and hm[:5] >= "13:00":
        warn = "⚠ after 13:00 - late moves lost in the test: small size, quick profit"
    return tag, warn


def _send_wrwatch(x, hm_, now_):
    """👀 STAGE 1 - at the wall: the trade card ready, both outcomes"""
    up = x["dir"] > 0; w = x["wall"]
    brk = w[0] * (0.995 if up else 1.005)
    _, pick = card_lines(x["s"], "CE" if up else "PE", brk, now_)
    L = ["👀 🧱 WATCH %s %s · ₹%s · %s · at the %g %s %s (%.1f%% away)" % ("▲" if up else "▼", x["s"], "{:,.2f}".format(x["px"]), hm_[:5], w[0],
         "PE" if up else "CE", "floor" if up else "wall", w[3]),
         "writers %+d%% today · futures OI %+.1f%% · if it turns back %s VWAP ₹%s → BUY %s" % (w[2], x["doi"], "over" if up else "under",
         "{:,.2f}".format(x["vwap"]), "CE" if up else "PE"),
         ("🎫 %g %s %s · ₹%s (get it ready)" % (pick[1], "CE" if up else "PE", dt.date.fromisoformat(pick[0]).strftime("%d %b"), "{:,.2f}".format(pick[2])) if pick
          else "🎫 the strike nearest the price (get it ready)") + " · if it breaks %s ₹%s instead → no %s" % ("under" if up else "over", "{:,.2f}".format(brk),
          "CE" if up else "PE")]
    send_big("\n".join(L))


def _send_wrrej(x, hm_, now_):
    """🧱 STAGE 2 - rejected at the wall: buy"""
    up = x["dir"] > 0; w = x["wall"]
    stop = w[0] * (0.995 if up else 1.005)
    _, pick = card_lines(x["s"], "CE" if up else "PE", stop, now_)
    why = "%s the %g %s %s · back %s VWAP · futures OI %+.1f%%" % ("bounced off" if up else "rejected at", w[0], "PE" if up else "CE", "floor" if up else "wall",
                                                          "over" if up else "under", x["doi"])
    send_big(short_card("🧱", x["s"], x["dir"], x["px"], x["chg"], hm_, why, pick, stop))


def short_card(icon, s, d, px, chg, hm, why, pick, stop):
    up = d > 0
    tag, warn = pb_short(s, d, hm)
    L = ["%s BUY %s %s %s · ₹%s (%+.1f%%) · %s%s" % (icon, "CE" if up else "PE", "▲" if up else "▼", s, "{:,.2f}".format(px), chg or 0, hm[:5], tag), why]
    out = "out: share %s ₹%s · by 15:15" % ("under" if up else "over", "{:,.2f}".format(stop))
    if pick:
        ex = dt.date.fromisoformat(pick[0]).strftime("%d %b")
        L.append("🎫 %g %s %s · ₹%s · %s" % (pick[1], "CE" if up else "PE", ex, "{:,.2f}".format(pick[2]), out))
    else:
        L.append("🎫 the strike nearest the price · " + out)
    if warn:
        L.append(warn)
    return "\n".join(L)

# ---------------- patch 289: 📚 THE PLAYBOOK - the 10 setups that made money in the 30-day tests (30 Sep - 13 Nov, NSE minute data), ranked.
# (rank, side, name, when, what the test said, short name). Steady falls and bursts: fastreplay 3o after ~0.20% costs · second runs: 3l, kept
# going 2% more / turned back 2% / held to 15:20 · results day 2 and the opening break: the NIFTY-at-09:30 split, after costs · momentum: 3e.
PLAYBOOK = [
    (1, "PE", "🧲 STEADY FALL - 1.5%+ under its open · short build-up +2% · under VWAP 15 min", "09:30-11:00", "+0.38% a trade after costs, won 61% (500 trades) ≈ +4% on the premium", "🧲 steady fall 1.5%"),
    (2, "PE", "🧲 STEADY FALL - 1%+ under its open · short build-up +2% · under VWAP 15 min", "09:30-11:00", "+0.36% a trade after costs, won 62% (754 trades) ≈ +4% on the premium", "🧲 steady fall 1%"),
    (3, "CE", "🔁 SECOND RUN CE - up 1.5%, back 0.5% staying over VWAP, then a new high", "before 10:00", "kept going 2% more 32%, turned back 19%, held to the close +0.35% (196)", "🔁 second run"),
    (4, "PE", "🧲 STEADY FALL - 0.75%+ under its open · short build-up +2% · under VWAP 15 min", "09:30-11:00", "+0.33% a trade after costs, won 60% (905 trades)", "🧲 steady fall 0.75%"),
    (5, "CE", "📊 RESULTS DAY 2 CE - results yesterday, the share up today", "before 10:00", "+0.16% a trade after costs (133) · +0.25% on mixed NIFTY mornings", "📊 results day 2"),
    (6, "CE", "🚀 MOMENTUM CE - already +3% on the day", "09:17-10:00", "kept going 2% more 33%, turned back 11%", "🚀 momentum +3%"),
    (7, "PE", "🧲 STEADY FALL with its sector AND NIFTY falling", "09:30-13:00", "+0.21% a trade after costs (821)", "🧲 steady fall + sector + NIFTY"),
    (8, "PE", "🔁 SECOND RUN PE - down 1.5%, back 0.5% staying under VWAP, then a new low", "before 10:00", "kept going 2% more 37%, turned back 22%, held to the close +0.21% (121)", "🔁 second run"),
    (9, "CE", "📈 OPENING 5-min BREAK CE with NIFTY rising", "09:20-10:00", "+0.18% a trade after costs, won 50% (754)", "📈 opening break"),
    (10, "PE", "⚡ BURST PE - down 1% in 3 min with futures OI +0.5% in 3 min", "09:20-11:00", "+0.12% a trade after costs (140)", "⚡ burst"),
]
PB_BY = {p_[0]: p_ for p_ in PLAYBOOK}
PB_AVOID = ["anything after 13:00 (-0.22% to -0.25%)", "results day 2 PE (-0.9%, won 23-25%)", "CE while NIFTY falls (-0.27% to -0.40%)", "PE while NIFTY rises",
            "betting a 3% move turns back (lost every version)", "closing at 0.5% off the best (cuts the winners)"]
_PBCTX = {}


def pb_card_line(s, d, t=None, hm=None):
    """📚 one line for a Telegram card: the setup this share is in now, the loser it is in, or none + the nearest + the best in the list"""
    c = _PBCTX.get("ck")
    if c is None:
        return None
    try:
        r = c.play(s, d, t or time.time(), hm or dt.datetime.now(IST).strftime("%H:%M"), _PBCTX["W"], _PBCTX["TU"], c.nif_now)
    except Exception:
        r = None
    if not r:
        return None
    if r.get("bad"):
        return "📚 PLAYBOOK: " + r["bad"]
    if r.get("rank"):
        return "📚 PLAYBOOK: ✅ #%d of 10 · %s · %s" % (r["rank"], r["name"], r["tested"])
    b = next((x for x in c.pb_list if x["s"] != s), None)
    return "📚 PLAYBOOK: no tested setup for %s %s now · %s%s" % (s, "CE" if d > 0 else "PE", r.get("near") or "",
        (" · the best in the list now: %s %s #%d %s" % (b["s"], b["side"], b["rank"], b["short"])) if b else " · nothing in the list matches any share right now")


def push_card_line(s):
    """📏 one line for a Telegram card (patch 290)"""
    c = _PBCTX.get("ck")
    pu = (c.push.get(s) if c is not None else None)
    if not pu:
        return None
    return "📏 FOR ITS SIZE: new futures money " + push_text(pu[0], pu[1], pu[2], pu[3])


def _pb_add(text, s, d, t=None, hm=None):
    L = []
    for f_ in (lambda: pb_card_line(s, d, t, hm), lambda: push_card_line(s)):
        try:
            ln = f_()
        except Exception:
            ln = None
        if ln:
            L.append(ln)
    if not L:
        return text
    a, _, b = text.partition("\n")
    return a + "\n" + "\n".join(L) + ("\n" + b if b else "")


def steady_text(st, hm, card=None):
    up = st["dir"] > 0
    px = st["px"]
    L = ["🧲 STEADY MOVE %s %s · %s · ₹%s (%+.1f%% from the open · %+.1f%% today)" % ("▲" if up else "▼", st["s"], hm, "{:,.2f}".format(px), st["mv"] * st["dir"], st["chg"]),
         "%s since the open: futures OI %+.1f%% · %s VWAP for %d min · NIFTY %s · its sector %d of %d %s" % (
             "long build-up" if up else "short build-up", st["doi"], "above" if up else "below", st["vmin"], (st.get("nifty") or "?").lower(),
             st["sec"][0], st["sec"][1], "up" if up else "down"),
         "TESTED (30 days): steady %s before 11:00 with a +2%% %s build-up: %s" % ("CE" if up else "PE", "long" if up else "short",
             "did not pay - small size" if up else "+0.36% a trade after costs, won 62% (754 trades) ≈ +4% on the premium")]
    L += list(card or [])
    L.append("plan: let it run - book at ₹%s (2%% more) · out if it goes back to ₹%s (2%%) or crosses back %s VWAP · same day: out by 15:15 · "
             "closing at 0.5%% off the best cut the winners in the test" % ("{:,.2f}".format(px * (1 + 0.02 * st["dir"])), "{:,.2f}".format(px * (1 - 0.02 * st["dir"])), "under" if up else "over"))
    return "\n".join(L)


def _send_steady(st, hm_, now_):
    up = st["dir"] > 0; stop = st["px"] * (1 - 0.02 * st["dir"])
    _, pick = card_lines(st["s"], "CE" if up else "PE", stop, now_)
    why = "steady %s %.1f%% from the open · new %s, OI %+.1f%% · %s VWAP %d min" % ("rise" if up else "fall", abs(st["mv"]), "buyers" if up else "sellers", st["doi"],
                                                                         "over" if up else "under", st["vmin"])
    send_big(short_card("🧲", st["s"], st["dir"], st["px"], st["chg"], hm_, why, pick, stop))           # patch 296: 3 lines


BIG_DAY_MAX = 30


def live_all(W, TU):
    """every share with futures data -> [price % today, futures OI % since the day's first reading (= yesterday's close OI), fresh ₹ cr]"""
    out = {}
    for s, d in W.h.items():
        if not d:
            continue
        last = d[-1]
        b = TU.base.get(s)
        if last[3] and b:
            out[s] = [None if last[2] is None else round(float(last[2]), 2), round((last[3] / b - 1) * 100, 2), round((last[3] - b) * last[1] / 1e7, 1)]
    return out


def _bg(fn, *a):
    """send without holding the 3-s loop (Zerodha's quote for the card takes up to 3 s, Telegram up to 15 s)"""
    import threading
    threading.Thread(target=fn, args=a, daemon=True).start()


def _send_card(s_, w_, hm_, p_, now_):
    side = "CE" if w_["dir"] > 0 else "PE"
    L, pick = card_lines(s_, side, p_["stop0"], now_)
    p_["pick"] = pick
    if w_.get("slow"):
        why = "the money came first (OI %+.1f%% today) · now %+.1f%% in 3 min" % (w_.get("day_oi") or 0, w_.get("px3") or 0)
    else:
        why = "%+.1f%% in 3 min with new futures money (OI %+.1f%% in 3 min)" % (w_.get("px3") or 0, w_.get("oi3") or 0)
    send_big(short_card("🌪", s_, w_["dir"], w_["px"], w_.get("chg") or 0, hm_, why, pick, p_["stop0"]))            # patch 296: 3 lines


def run():
    W = Wind()
    TU = Turns(str(dt.datetime.now(IST).date()))
    O, BK = Opts(), Book(str(dt.datetime.now(IST).date()))        # patch 278
    last_q, last_min = 0.0, None
    sent = {"day": None, "n": 0, "big": 0}
    bsaid, BL = {}, []
    MO = Momentum(str(dt.datetime.now(IST).date()))                  # patch 281
    LD = Loading(str(dt.datetime.now(IST).date()))                   # patch 282
    VW = View(str(dt.datetime.now(IST).date()))                      # patch 283
    CK = Cockpit(str(dt.datetime.now(IST).date()))                   # patch 285
    BT = BuildLog(str(dt.datetime.now(IST).date()))                  # patch 292
    OH = OIHist(str(dt.datetime.now(IST).date()))                    # patch 294
    CL = CheckLive(str(dt.datetime.now(IST).date()))                 # patch 303
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            if W.h:
                W, O = Wind(), Opts()
            if TU.day != str(now.date()):
                TU = Turns(str(now.date()))
            if BK.day != str(now.date()):
                BK = Book(str(now.date()))
            if MO.day != str(now.date()):
                MO = Momentum(str(now.date()))
            if LD.day != str(now.date()):
                LD = Loading(str(now.date()))
            if VW.day != str(now.date()):
                VW = View(str(now.date()))
            if CK.day != str(now.date()):
                CK = Cockpit(str(now.date()))
            if BT.day != str(now.date()):
                BT = BuildLog(str(now.date()))
            elif BT.dirty:
                BT.save()
            if CL.day != str(now.date()):
                CL = CheckLive(str(now.date()))
            if OH.day != str(now.date()):
                if OH.dirty:
                    OH.save()
                OH = OIHist(str(now.date()))
            elif OH.dirty:
                OH.save()                                                  # patch 294: the day's last minutes onto the disk after 15:30
            time.sleep(20); continue
        try:
            Q = _load(os.path.join(BASE, "quotes_live.json")) or {}
            F = _load(os.path.join(BASE, "data", "fut_live.json")) or {}
            t = time.time()
            day, hms = str(now.date()), now.strftime("%H:%M:%S")
            if sent["day"] != day:
                sent.update({"day": day, "n": 0, "big": 0, "mom": 0})
            O.feed(_load(PINF), t)                                          # patch 278: the strikes, 5 s old
            if hm != last_min and O.h:
                last_min = hm
                hist_save(O, t, day, hm)
            if Q.get("t") and Q["t"] != last_q and t - Q["t"] < 30:
                last_q = Q["t"]
                W.feed(t, Q.get("q"), F.get("f") if F.get("t") and t - F["t"] < 30 else {})
                cur = W.read(t)
                opt_into(cur, O, t)
                for w_ in cur.values():                                           # patch 280: the checklist count for the page
                    c_ = checklist(w_); w_["chk"] = [c_[0], c_[1], c_[2], c_[3]]
                NT = TU.step(t, hms, W, cur)          # patch 276: the turns
                try:
                    BT.step(t, hms, W, TU)                                          # patch 292: ⏱ the build-up timeline
                except Exception as ex:
                    print("buildlog: %s" % str(ex)[:80], flush=True)
                try:
                    OH.step(t, W)                                                   # patch 294: 💾 a minute of every share's futures, kept
                except Exception as ex:
                    print("oihist: %s" % str(ex)[:80], flush=True)
                p = os.path.join(BASE, "data", "wind.json")
                for kind, cp, px, words in BK.step(t, hm, W, cur, O):     # patch 278: the cards followed
                    _bg(send_big, follow_text(kind, cp, px, words, O, cur.get(cp["s"])))
                    if kind == "EXIT":
                        cards_db(cp, day)
                BG = big_movers(t, cur, bsaid)                                   # patch 277: 🌪 BIG MOVERS
                for s_, w_ in BG:
                    x = {"t": hms, "ts": int(t), "s": s_, "dir": w_["dir"], "px3": w_["px3"], "oi3": w_["oi3"], "score": w_["score"], "opt": w_.get("opt")}
                    BL.append(x)
                    if w_.get("opt") is False:
                        x["st"], x["won"] = "held · writers against", 0                 # shown, not sent: the option writers fight it
                        continue
                    if (s_, w_["dir"]) in BK.open:
                        x["st"], x["won"] = "card already open", 0
                        continue
                    if sent["big"] >= BIG_DAY_MAX:
                        x["st"], x["won"] = "page only (30 a day)", 0
                        continue
                    sent["big"] += 1
                    other = BK.open.pop((s_, -w_["dir"]), None)
                    if other:                                                        # the other side's card on the same share: out
                        other.update({"exit_t": hm, "exit_px": w_["px"], "why": "a big mover the other way", "res": round((w_["px"] - other["entry"]) * other["dir"] / other["entry"] * 100, 2)})
                        BK.done.append(other); cards_db(other, day)
                        _bg(send_big, follow_text("EXIT", other, w_["px"], "a 🌪 big mover the OTHER way on the same share", O))
                    cp = BK.add(s_, w_, t, hms)
                    _bg(_send_card, s_, w_, hms, cp, now)
                MK = Momentum.market(W)                                            # patch 281: 🚀 MOMENTUM
                for s_, sd, L, first, px, chg in (MO.step(W) if hm >= MOM_FROM else []):     # the first 2 minutes are noise: not even counted
                    early = hm < MOM_END
                    same, other = (MK[0], MK[1]) if sd > 0 else (MK[1], MK[0])
                    against = MK[2] and other >= MOM_AGAINST * MK[2]
                    dq = W.h.get(s_); b_ = TU.base.get(s_)
                    doi = ((dq[-1][3] / b_ - 1) * 100) if (dq and dq[-1][3] and b_) else None
                    res = s_ in MO.res
                    x = {"t": hms, "ts": int(t), "s": s_, "dir": sd, "L": L, "chg": round(chg, 2), "res": res, "early": early}
                    MO.list.append(x)
                    open_ = BK.open.get((s_, sd))
                    if not first:                                                    # +5% / +8%: an update on the same card
                        x["st"] = "now %+.0f%%" % (L * sd)
                        if open_ is not None and open_.get("mom"):
                            _bg(send_big, "🚀 MOMENTUM %s %s now %+.1f%% today · %s · from the %s card: ₹%s → ₹%s (%+.1f%%)" % (
                                "▲" if sd > 0 else "▼", s_, chg, hms[:5], open_["t"][:5], "{:,.2f}".format(open_["entry"]), "{:,.2f}".format(px), (px / open_["entry"] - 1) * 100))
                        continue
                    if not early or against or hm < MOM_FROM or sent.get("mom", 0) >= MOM_DAY_MAX:
                        x["st"] = "page only · " + ("after 10:00 - a coin flip" if not early else "against a strong market" if against else
                                                    "the first 2 minutes are noise" if hm < MOM_FROM else "12 cards a day")
                        continue
                    if open_ is not None:
                        x["st"] = "card already open"
                        continue
                    sent["mom"] = sent.get("mom", 0) + 1
                    cp = BK.add(s_, {"dir": sd, "px": px, "px3": 0.0}, t, hms, r=px * MOM_R); cp["mom"] = True
                    x["st"] = "card sent"
                    _bg(_send_mom, s_, sd, L, px, chg, hms, early, MK, doi, res, cp, now, cur.get(s_), sector_day(W, s_), CK.state.get("NIFTY"), s_ in CK.day2)
                MO.list[:] = MO.list[-60:]
                for s_, vd, kind, L, px, chg, w_ in (VW.step(t, W, cur) if hm >= MOM_FROM else []):     # patch 283: 👁 YOUR VIEW
                    _bg(send_big, view_text(s_, vd, kind, L, px, chg, hms, w_))
                try:                                                                # patch 285: 🎯 THE COCKPIT
                    tx_ = CK.write(t, hms, W, TU, O, MO, BL, LD)
                    if tx_:
                        _bg(send_big, tx_)
                    for st_ in CK.steady_scan(t, hm, W, TU, CK.nif_now):                # patch 288: 🧲 STEADY MOVE
                        _bg(_send_steady, st_, hms, now)
                    for x_ in CK.wallmoney_scan(t, hms, W, TU, O, CK.nif_now, BT):     # patch 295: 🧱 PE MONEY / CE MONEY
                        _bg(_send_wallm, x_, hms, now)
                    try:
                        CL.step(t, hms, W, TU, CK)                                      # patch 303: 📋 the checklist, live
                    except Exception as ex_:
                        print("checklist live: %s" % str(ex_)[:80], flush=True)
                    _ww, _wr = CK.wallrej_scan(t, hms, W, TU, O, CK.nif_now)           # patch 298: 👀 WALL WATCH / 🧱 REJECTED
                    for x_ in _ww:
                        _bg(_send_wrwatch, x_, hms, now)
                    for x_ in _wr:
                        _bg(_send_wrrej, x_, hms, now)
                except Exception as ex:
                    print("cockpit: %s" % str(ex)[:120], flush=True)
                _ln, _ld = LD.step(t, hms, W)                                       # patch 282: ⏳ MONEY LOADING (page only, followed 45 min)
                if _ld:
                    loading_db(_ld, day)
                st = BK.status()
                for x in BL:
                    if (x["s"], x["dir"], x["t"]) in st:
                        x["st"], x["won"] = st[(x["s"], x["dir"], x["t"])]
                BL[:] = [x for x in BL if t - x["ts"] < 3 * 3600][-40:]
                ALL = live_all(W, TU)                                                # patch 278: every share's day, live (the BIG MONEY table)
                for s_, pu_ in CK.push.items():                                     # patch 290: + 📏 the push for its size, its rank, of how many
                    if s_ in ALL:
                        ALL[s_] = ALL[s_][:3] + [pu_[0], pu_[1], pu_[2]]
                cards = [{k: c.get(k) for k in ("s", "dir", "t", "entry", "stop", "half", "t2", "exit_t", "exit_px", "why", "res")} for c in list(BK.open.values()) + BK.done[-30:]]
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "opt": bool(O.h), "s": cur, "turns": TU.list[-40:], "big": BL[-40:], "cards": cards, "all": ALL, "oi_every": W.oi_every(), "mk": list(W.br), "mom": MO.list[-40:], "load": LD.list[-30:], "bt": BT.log, "bt_day": BT.day},
                          open(p + ".tmp", "w"), separators=(",", ":")); os.replace(p + ".tmp", p)
                C = W.calls(t, cur)
                if C:
                    c = db()
                    c.executemany("insert into wind_calls values (?,?,?,?,?,?,?,?,?,?,?)", [(day, hms, s, "CE" if w["dir"] > 0 else "PE",
                                  w["kind"], w["px"], w["px3"], w["oi3"], w["book"], w["sec"], w["score"]) for s, w in C])
                    c.commit(); c.close()
                if NT:
                    turns_db(NT, day)
                    for x in NT:                                              # a FULL turn: to GIR Bigmovers (patch 277), else quietly to the usual channel
                        if x["turn"] in ("CE → PE", "PE → CE") and sent["n"] < 40:
                            sent["n"] += 1
                            _bg(_send_turn, turn_text(x, cur.get(x["s"])))
        except Exception as ex:
            print("%s %s" % (hm, str(ex)[:120]), flush=True); time.sleep(5)
        time.sleep(EVERY)


def _send_turn(text):
    if not send_big(text, log=False):
        try:
            import opencall
            opencall.send_tg(text)
        except Exception as ex:
            print("send: %s" % str(ex)[:80], flush=True)


def cards_show(day=None):
    """python3 windwatch.py cards [DAY] - every 🌪 card and how it ended"""
    day = day or str(dt.datetime.now(IST).date())
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True)
        R = c.execute("select t, sym, side, entry, half, exit_t, exit_px, why, res from wind_cards where day=? order by t", (day,)).fetchall()
    except Exception:
        R = []
    print("=== 🌪 CARDS %s: %d" % (day, len(R)))
    for r in R:
        print("  %s %-11s %s ₹%-9s %s → %s %-7s %s" % (r[0][:5], r[1], r[2], "{:,.2f}".format(r[3]), "½" if r[4] else " ", r[5] or "-", ("%+.2f%%" % r[8]) if r[8] is not None else "", (r[7] or "")[:60]))
    if R:
        w = [r[8] for r in R if r[8] is not None]
        print("  won %d · lost %d · booked half first %d · average %+.2f%% on the share" % (sum(1 for x in w if x > 0), sum(1 for x in w if x < 0), sum(1 for r in R if r[4]), sum(w) / max(1, len(w))))


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"]:
        run()
    elif sys.argv[1:2] == ["view"]:
        if len(sys.argv) >= 4 and sys.argv[3] in ("up", "down", "off"):
            v = view_set(sys.argv[2], sys.argv[3])
        else:
            v = views()
        print("👁 YOUR VIEW: " + (" · ".join("%s %s" % (k, "▲ up" if x > 0 else "▼ down") for k, x in sorted(v.items())) or "none") +
              "   (python3 windwatch.py view SYM up|down|off)")
    elif sys.argv[1:2] == ["loading"]:
        loading_show(sys.argv[2] if len(sys.argv) > 2 else None)
    elif sys.argv[1:2] == ["cards"]:
        cards_show(sys.argv[2] if len(sys.argv) > 2 else None)
    elif sys.argv[1:2] == ["oihist"]:
        oihist_show()
    else:
        j = _load(os.path.join(BASE, "data", "wind.json")) or {}
        age = time.time() - (j.get("t") or 0)
        print("wind.json: %s · futures data %s · futures OI changes every %s · option strikes %s" % (("%.0f s old" % age) if j else "not written yet (from 09:15 on a trading day)",
              "in" if j.get("fut") else "not in yet", ("~%s s (median, all shares)" % j["oi_every"]) if j.get("oi_every") else "-", "in" if j.get("opt") else "not in yet"))
        for s, w in sorted((j.get("s") or {}).items(), key=lambda x: -x[1]["score"])[:15]:
            print("  %-11s %s" % (s, line(w)))
PY_WW
cat > $W/checklist.html <<'HTML_CL'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR Checklist</title>
<style>
:root{--bg:#07090d;--panel:#0e131b;--panel2:#141b26;--line:#1f2a38;--text:#e6edf3;--dim:#8b98a8;--up:#3ddc84;--dn:#ff5c5c;--am:#ffb347;--hi:#ffffff}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header{position:sticky;top:0;z-index:5;background:#0b1018;border-bottom:1px solid var(--line);padding:10px 14px}
.title{font-weight:700;font-size:16px}.sub{color:var(--dim);font-size:12.5px}
.tabs{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.tabs a{cursor:pointer;padding:6px 12px;border:1px solid var(--line);border-radius:999px;background:var(--panel2);font-weight:600;font-size:13px}
.tabs a.on{background:var(--am);color:#1a1205;border-color:var(--am)}
.ctl{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;align-items:center;font-size:13px;color:var(--dim)}
.ctl select{background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:6px;padding:4px 6px;font:inherit}
main{padding:10px 14px 30px;max-width:1100px}
.row{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-bottom:10px}
.top{display:flex;justify-content:space-between;gap:10px;align-items:baseline;flex-wrap:wrap}
.rank{color:var(--am);font-weight:700;margin-right:6px}.name{font-weight:700;font-size:16px;color:inherit}.px{color:var(--dim)}
.sc{display:inline-block;padding:1px 8px;border-radius:6px;background:var(--panel2);font-weight:700;margin-left:6px}
.up{color:var(--up)}.dn{color:var(--dn)}.am{color:var(--am)}.dim{color:var(--dim)}b{color:var(--hi)}
.lv{margin-top:6px}.lv .k{font-weight:700}.lv .why{color:var(--dim);font-size:13px;margin-left:14px}
.todo{margin-top:6px;padding:6px 8px;border-radius:6px;background:#101a26}.warn{margin-top:6px;color:var(--am)}
details{margin-top:6px}summary{cursor:pointer;color:var(--dim);font-size:13px}.ok{color:var(--up)}.no{color:var(--dim)}
.w{background:#1a2230;border:1px solid var(--line);color:var(--text);border-radius:6px;padding:4px 10px;cursor:pointer;font:inherit;font-size:13px}.w.on{background:#0f3d24;border-color:var(--up)}
.help p{margin:6px 0}.help h3{margin:14px 0 4px;font-size:15px}
.live{margin-top:6px;padding:6px 8px;border-radius:6px;background:#0c1520;border-left:3px solid var(--dim);font-size:13px}.live .st{margin-top:3px}
.live.s-at{border-color:var(--am)}.live.s-live{border-color:var(--up);background:#0d2418}.live.s-target{border-color:var(--up)}.live.s-out,.live.s-broke{border-color:var(--dn)}
.stg{display:inline-block;padding:1px 8px;border-radius:6px;font-weight:700;font-size:12.5px;margin-left:6px;background:var(--panel2);color:var(--dim)}
.stg.s-at{background:#3a2c12;color:var(--am)}.stg.s-live,.stg.s-target{background:#0f3d24;color:var(--up)}.stg.s-out,.stg.s-broke{background:#45161a;color:var(--dn)}
#lvst{margin-top:6px;font-size:12.5px}.sum{margin:4px 0 10px}
</style></head><body>
<header id="top"><span class="dim">📋 GIR CHECKLIST · loading…</span></header>
<main id="m"></main>
<script>
/* patch 302: 📋 THE CHECKLIST IN PLAIN WORDS - tabs, a ranked list, big-wall filter, every number explained (data: wallcheck2.py, patch 301) */
/* patch 303: 📋 THE CHECKLIST, LIVE - every share's stage every 3 s from the wind watcher (checklistlive); done ones move to the ✔ Done tab */
const Q=location.search;
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const rs=v=>v==null?"—":"₹"+Number(v).toLocaleString("en-IN",{minimumFractionDigits:0,maximumFractionDigits:2});
const pc=v=>v==null?"":(v>0?"+":"")+v+"%";
function shareURL(s){ const u=new URLSearchParams(location.search); u.set("w",s); return "./?"+u.toString(); }
let D=null, TAB="pe", SORT="rank", BIG="all", WATCHED=new Set(), LV=null, OPEN=new Set();
const STG={wait:"⏳ waiting",at:"👀 at the level",live:"✅ entry live",target:"✔ target hit",out:"✖ out",broke:"⚠ broke - off",closed:"⏹ closed"};
const DONE=new Set(["target","out","broke","closed"]);
const FUTN={"LONG BUILD-UP":"new buyers","SHORT BUILD-UP":"new sellers","SHORT COVERING":"sellers running","LONG UNWINDING":"buyers leaving"};
function lvOn(){ return !!(LV&&LV.live&&LV.day&&D&&LV.day>D.day); }          /* today's stages belong to this list (made the evening before) */
function L_(x){ return lvOn()?LV.live[x.s+"|"+x.side]||null:null; }
function isDone(x){ const l=L_(x); return !!(l&&DONE.has(l.state)); }
function tog(el){ if(el.open) OPEN.add(el.dataset.k); else OPEN.delete(el.dataset.k); }
function stg(x){ const l=L_(x); return l&&l.state?`<span class="stg s-${l.state}">${STG[l.state]||esc(l.state)}</span>`:""; }
function lvlOf(x){ const pe=x.side==="PE"; return x.kind==="breakdown"?x.floor:(x.kind==="breakout"||pe)?x.roof:x.floor; }
function stageText(x,l){ const pe=x.side==="PE", w=lvlOf(x), k=w?rs(w.k):"—", d=pe?-1:1;
  if(l.state==="wait") return x.kind?`⏳ waiting for it to hold ${x.kind==="breakout"?"over the ceiling":"under the floor"} ${k}`
    :`⏳ waiting for it to ${pe?"come up to the ceiling":"come down to the floor"} ${k}${(pe?x.lo:x.hi)?` (or break the day's ${pe?"low":"high"} ${rs(pe?x.lo:x.hi)})`:""}`;
  if(l.state==="at") return x.kind?`👀 at ${k} - the entry is when it holds 0.3% past it on its VWAP side`
    :`👀 at the ${pe?"ceiling":"floor"} ${k} - the entry is the turn back ${pe?"under":"over"} VWAP (GIR rings 🧱)`;
  if(l.state==="live"){ const tg=l.entry_px*(1+0.02*d), ot=x.kind?null:(pe?x.floor:x.roof);
    return `✅ entry ${esc(l.entry_t)} at ${rs(l.entry_px)} - ${esc(l.note||"")} · now <b class="${l.move>=0?"up":"dn"}">${pc(l.move)}</b> its way · target ${rs(Math.round(tg*100)/100)}${ot?` or the ${pe?"floor":"ceiling"} ${rs(ot.k)}`:""} · out if it closes back ${pe?"over":"under"} ${k} · out by 15:15`; }
  return `${STG[l.state]} ${esc(l.done_t||"")} at ${rs(l.done_px)} - ${esc(l.note||"")}${l.res!=null?` · result <b class="${l.res>=0?"up":"dn"}">${pc(l.res)}</b> on the share`:""}`; }
function liveLine(x,noSt){ const l=L_(x); if(!l) return ""; const pe=x.side==="PE";
  const P=[`<b>LIVE ${esc(LV.hm||"")}</b> ${rs(l.px)} <span class="${l.chg>0?"up":l.chg<0?"dn":"dim"}">${pc(l.chg)}</span>`,
    l.roof==null?"":l.roof>=0?`ceiling ${l.roof}% above`:`<span class="up">over the ceiling by ${Math.abs(l.roof)}%</span>`,
    l.floor==null?"":l.floor>=0?`floor ${l.floor}% below`:`<span class="dn">under the floor by ${Math.abs(l.floor)}%</span>`,
    l.vside==null?"":`${l.vside>0?"over":"under"} VWAP ${rs(l.vwap)} ${(l.vside>0)===!pe?"✅":"⚠"}`,
    l.kind_now?`futures now: ${FUTN[l.kind_now]||esc(l.kind_now)} (OI ${pc(l.doi)}) ${(l.kind_now==="SHORT BUILD-UP"||l.kind_now==="LONG UNWINDING")===pe?"✅":"⚠"}`:l.doi!=null?`futures OI ${pc(l.doi)} - no clear bet`:"",
    (l.rang||[]).length?`rang ${esc(l.rang.join(" · "))}`:""].filter(Boolean).join(" · ");
  return `<div class="live s-${l.state}"><div>${P}</div>${noSt?"":`<div class="st">${stageText(x,l)}</div>`}</div>`; }
function allItems(){ const seen=new Set(), A=[]; if(!D) return A;
  ["pe","ce","retest","breakout","breakdown"].forEach(k=>(D[k]||[]).forEach(x=>{ const key=x.s+"|"+x.side; if(!seen.has(key)){ seen.add(key); A.push(x); } })); return A; }
function doneRow(x){ const l=L_(x), pe=x.side==="PE";
  return `<div class="row"><div class="top"><span><span class="${pe?"dn":"up"}">${pe?"▼ PE":"▲ CE"}</span> <a class="name" href="${shareURL(x.s)}" target="_blank">${esc(x.s)}</a>${stg(x)}</span>
    <span class="${l.res==null?"dim":l.res>=0?"up":"dn"}">${l.res==null?"no entry":"result "+pc(l.res)+" on the share"}</span></div>
    <div class="lv">${l.entry_t?`in ${esc(l.entry_t)} at ${rs(l.entry_px)} → `:""}${l.entry_t?"out":"off"} ${esc(l.done_t||"")} at ${rs(l.done_px)} · ${esc(l.note||"")}</div>${liveLine(x,true)}</div>`; }
function doneList(){ const A=allItems().filter(isDone).sort((a,b)=>String(L_(b).done_t).localeCompare(String(L_(a).done_t)));
  if(!lvOn()) return '<div class="dim">Shares move here once they are done for the day: ✔ target hit · ✖ out · ⚠ broke (the idea is off) · ⏹ closed at 15:15. Live from 09:20 on a market day.</div>';
  const n=s_=>A.filter(x=>L_(x).state===s_).length;
  return `<div class="sum">today: <span class="up">✔ ${n("target")} target hit</span> · <span class="dn">✖ ${n("out")} out</span> · <span class="dn">⚠ ${n("broke")} broke</span> · ⏹ ${n("closed")} closed</div>`+(A.length?A.map(doneRow).join(""):'<div class="dim">none done yet today</div>'); }
try{ TAB=localStorage.getItem("gir_cl_tab")||"pe"; SORT=localStorage.getItem("gir_cl_sort")||"rank"; BIG=localStorage.getItem("gir_cl_big")||"all"; }catch(e){}
function setv(k,v){ if(k==="tab") TAB=v; else if(k==="sort") SORT=v; else BIG=v; try{ localStorage.setItem("gir_cl_"+k,v); }catch(e){} paint(); }
async function watch(s,side,btn){ try{ const u=new URLSearchParams(location.search); u.set("w",s); u.set("d",side==="PE"?"down":"up");
  const j=await (await fetch("checklistwatch?"+u.toString(),{cache:"no-store"})).json(); if(j.ok){ WATCHED.add(s); btn.classList.add("on"); btn.textContent="✓ on your watch list"; } }catch(e){} }
const SIZE={DENSE:"BIG wall",MEDIUM:"medium wall",THIN:"small wall"};
function writers(w,isRoof,s){ const who=isRoof?"Call sellers":"Put sellers", keep=isRoof?"stays below":"stays above", what=isRoof?"ceiling":"floor";
  if(w.add==null) return `New sellers opened this strike today - a fresh ${what}.`;
  if(w.add>=10) return `${who} added ${w.add}% more contracts here today - they are betting harder that ${esc(s)} ${keep} ${rs(w.k)}. The ${what} got stronger.`;
  if(w.add>0) return `${who} added a little (${w.add}%) - the ${what} is holding.`;
  if(w.add>-10) return `${who} cut ${Math.abs(w.add)}% - the ${what} is about the same.`;
  return `${who} took back ${Math.abs(w.add)}% here today - they are giving up. ⚠ The ${what} may break${isRoof?" (good for a CE if it does)":" (good for a PE if it does)"}.`; }
function level(w,isRoof,s){ if(!w) return `<div class="lv"><span class="k">${isRoof?"CEILING (resistance)":"FLOOR (support)"}:</span> none within 15% - open room ${isRoof?"to rise":"to fall"}</div>`;
  return `<div class="lv"><span class="k">${isRoof?"CEILING (resistance)":"FLOOR (support)"}: ${rs(w.k)}</span> · ${w.dist}% ${isRoof?"above":"below"} · <b>${SIZE[w.den]||w.den}</b> (₹${Number(w.cr).toLocaleString("en-IN")} cr of ${isRoof?"calls":"puts"} sold)
    <div class="why">→ ${writers(w,isRoof,s)}</div></div>`; }
const FUT={"LONG BUILD-UP":"new buyers are betting on a rise (long build-up)","SHORT BUILD-UP":"new sellers are betting on a fall (short build-up)",
  "SHORT COVERING":"sellers are closing their bets (short covering) - a rise without new money","LONG UNWINDING":"buyers are leaving (long unwinding) - a fall without new money"};
const WHY={"roof close":"the ceiling is within 3% above","roof dense":"the ceiling is a big wall","writers adding at the roof":"call sellers are adding at the ceiling",
  "new futures sellers":"new futures sellers","room to the floor":"room to fall (the floor is 3%+ below)","trend down":"the 5-day trend is down","sector down":"its sector is down",
  "NIFTY 5 days down":"NIFTY's 5 days are down","big hands selling":"big investors are selling (high delivery)","news ▼":"the latest news is bad",
  "floor close":"the floor is within 3% below","floor dense":"the floor is a big wall","writers adding at the floor":"put sellers are adding at the floor",
  "new futures buyers":"new futures buyers","room to the roof":"room to rise (the ceiling is 3%+ above)","trend up":"the 5-day trend is up","sector up":"its sector is up",
  "NIFTY 5 days up":"NIFTY's 5 days are up","big hands buying":"big investors are buying (high delivery)","news ▲":"the latest news is good"};
function todo(x){ const pe=x.side==="PE", r=x.roof, f=x.floor;
  if(x.kind==="breakout") return `▲ CE only once it holds above the ceiling ${rs(r&&r.k)} while the call sellers keep leaving. Exit if it falls back below ${rs(r&&r.k)}.`;
  if(x.kind==="breakdown") return `▼ PE only once it holds below the floor ${rs(f&&f.k)} while the put sellers keep leaving. Exit if it climbs back above ${rs(f&&f.k)}.`;
  return pe?`▼ PE if it bounces up to the ceiling ${rs(r&&r.k)} and fails there, or breaks below the day's low ${rs(x.lo)}. Exit if it closes above ${rs(r?r.k:x.hi)}.`
           :`▲ CE if it dips to the floor ${rs(f&&f.k)} and holds there, or breaks above the day's high ${rs(x.hi)}. Exit if it closes below ${rs(f?f.k:x.lo)}.`; }
function row(x,i){ const pe=x.side==="PE"; i=(x._r||i+1)-1;
  const why=(x.why||[]).map(w=>`<div class="${w[1]?"ok":"no"}">${w[1]?"✅":"·"} ${esc(WHY[w[0]]||w[0])}</div>`).join("");
  const extra=[x.d5!=null?`5 days ${pc(x.d5)}`:"", x.rsi!=null?`RSI ${x.rsi}${x.rsi>=75?" (stretched up)":x.rsi<=30?" (stretched down)":""}`:"", x.sec!=null?`its sector ${pc(x.sec)} today`:"",
    x.dlx>=1.5?`big investors ${x.dlbuy?"bought":"sold"} (delivery ${x.dlx}× normal)`:"", x.news?`news: ${x.news[0]} good / ${x.news[1]} bad`:""].filter(Boolean).join(" · ");
  return `<div class="row"><div class="top"><span><span class="rank">#${i+1}</span><span class="${pe?"dn":"up"}">${pe?"▼ PE":"▲ CE"}</span> <a class="name" href="${shareURL(x.s)}" target="_blank">${esc(x.s)}</a>
      <span class="px">${rs(x.px)} (${pc(x.chg)} on the day)</span>${x.kind?"":`<span class="sc">score ${x.score}/10</span>`}${stg(x)}</span>
      <button class="w${WATCHED.has(x.s)?" on":""}" onclick="watch('${esc(x.s)}','${x.side}',this)">${WATCHED.has(x.s)?"✓ on your watch list":"➕ watch"}</button></div>
    ${liveLine(x)}
    ${pe||x.kind==="breakout"?level(x.roof,true,x.s)+level(x.floor,false,x.s):level(x.floor,false,x.s)+level(x.roof,true,x.s)}
    <div class="lv"><span class="k">FUTURES:</span> ${esc(FUT[x.bu]||"no clear futures bet")}${x.bu?` · open interest ${pc(x.foi)}`:""}</div>
    <div class="todo"><b>WHAT TO DO:</b> ${todo(x)}</div>
    ${x.done?`<div class="warn">⚠ It already moved ${x.moved}% (${x.typ?"a normal day for it is about ±"+x.typ+"%":"its normal day is not known - 1.5% used"}) - don't chase at the open; wait for it to come back to the level.</div>`:""}
    ${x.kind?"":`<details data-k="${esc(x.s+x.side)}" ontoggle="tog(this)"${OPEN.has(x.s+x.side)?" open":""}><summary>why ${x.score}/10 - the 10 checks${extra?" · "+esc(extra):""}</summary>${why}</details>`}</div>`; }
function mainWall(x){ return (x.side==="PE"||x.kind==="breakout")?x.roof:x.floor; }
function list(L){ let A=(L||[]).map((x,i)=>Object.assign({},x,{_r:i+1})); const all=A.length; A=A.filter(x=>!isDone(x));
  if(all&&!A.length) return '<div class="dim">all done for today - see ✔ Done</div>';
  if(BIG==="big") A=A.filter(x=>{ const w=mainWall(x); return w&&w.den==="DENSE"; });
  if(SORT==="big") A.sort((a,b)=>((mainWall(b)||{}).cr||0)-((mainWall(a)||{}).cr||0));
  else if(SORT==="near") A.sort((a,b)=>((mainWall(a)||{}).dist??99)-((mainWall(b)||{}).dist??99));
  const pri=x=>{ const l=L_(x); return l?({live:0,at:1}[l.state]??2):2; }; A.sort((a,b)=>pri(a)-pri(b));      /* ✅ live and 👀 at the level on top */
  return A.length?A.map(row).join(""):'<div class="dim">nothing here with these filters</div>'; }
function help(){ return `<div class="help">
  <h3>The ceiling and the floor</h3><p><b>CEILING (resistance)</b> = the price above the share where the most CALL options are sold. Call sellers lose money if the share goes above it, so they defend it - the share often stops there.</p>
  <p><b>FLOOR (support)</b> = the price below where the most PUT options are sold. Put sellers lose money if the share falls below it, so they defend it - the share often bounces there.</p>
  <h3>"Call sellers added 12%"</h3><p>Today, 12% more call contracts were sold at that ceiling than yesterday. More sellers = they are betting harder the share will NOT go above it = <b>a stronger ceiling</b>.</p>
  <p>"Call sellers took back 33%" = they bought back a third of their calls - they are giving up = <b>the ceiling may break</b>. The same for the floor with put sellers.</p>
  <h3>BIG / medium / small wall</h3><p>The wall's size in rupees (contracts × the strike), compared with every F&O share: the top third = BIG, the bottom third = small. A big wall is strong; a small wall means little.</p>
  <h3>Futures</h3><p><b>Long build-up</b> = new buyers betting on a rise · <b>short build-up</b> = new sellers betting on a fall · <b>short covering</b> = sellers running (a rise without new money) · <b>long unwinding</b> = buyers leaving (a fall without new money).</p>
  <h3>Score /10</h3><p>How many of 10 checks agree for that side (the wall close, big, sellers adding, the futures, room to move, the trend, the sector, NIFTY, big investors, news). It lines up the reasons - it does not predict. One point is taken off when the move already happened.</p>
  <h3>Wait for the retest</h3><p>The share already moved most of a normal day for it - selling at the low (or buying at the high) is late. Wait for it to come back to the level and fail there.</p>
  <h3>Small option chains</h3><p>So few options that the walls mean little and the options are hard to trade - skip, or a tiny size.</p>
  <h3>The live stages (from 09:20, every 3 s)</h3><p><b>⏳ waiting</b> - not at its level yet · <b>👀 at the level</b> - within 0.5% of the ceiling (PE) or the floor (CE) · <b>✅ entry live</b> - it touched the level and turned back 0.3%+ on the right side of VWAP, or broke the day's low (PE) / high (CE) on the right side of VWAP; a breakout: held 0.3% past the wall.</p>
  <p>Then it moves to <b>✔ Done</b>: <b>✔ target hit</b> - 2% its way or the other wall · <b>✖ out</b> - closed back past the level · <b>⚠ broke</b> - went 0.5% through the level before any entry, the idea is off · <b>⏹ closed</b> - 15:15. The result is the share's move, not the option's.</p>
  <h3>Every share</h3><p>This list is levels for the day. The trade is the live entry at the level after 09:30 - GIR rings 👀 near a wall and 🧱 on the rejection. Half size, out by 15:15.</p></div>`; }
function lvStatus(){ const el=document.getElementById("lvst"); if(!el) return;
  if(!lvOn()){ el.innerHTML='<span class="dim">⚪ live stages: from 09:20 on a market day - GIR follows every share on this list every 3 s</span>'; return; }
  const age=Date.now()/1000-(LV.t||0), A=allItems().map(L_).filter(Boolean), n=s_=>A.filter(l=>l.state===s_).length;
  el.innerHTML=`${age<60?`<b class="up">🟢 LIVE ${esc(LV.hm)}</b>`:`<b class="am">⏸ last update ${esc(LV.hm)}</b>`} · <span class="up">✅ ${n("live")} entry live</span> · <span class="am">👀 ${n("at")} at the level</span> · ⏳ ${n("wait")} waiting · ✔ ${A.filter(l=>DONE.has(l.state)).length} done`; }
function paintBody(){ if(!D) return;
  const act=L=>(L||[]).filter(x=>!isDone(x));
  const T=[["pe","▼ PE",act(D.pe)],["ce","▲ CE",act(D.ce)],["retest","⏳ Wait for the retest",act(D.retest)],["bo","⚡ Breakout / breakdown",act((D.breakout||[]).concat(D.breakdown||[]))],["done","✔ Done",allItems().filter(isDone)],["thin","⚠ Small chains",D.thin],["help","ⓘ How to read",null]];
  const tb=document.getElementById("tabs"); if(tb) tb.innerHTML=T.map(t=>`<a class="${TAB===t[0]?"on":""}" onclick="setv('tab','${t[0]}')">${t[1]}${t[2]?" · "+t[2].length:""}</a>`).join("");
  lvStatus();
  const m=document.getElementById("m");
  if(TAB==="help") m.innerHTML=help();
  else if(TAB==="done") m.innerHTML=doneList();
  else if(TAB==="thin") m.innerHTML=`<p class="dim">These F&amp;O shares have so few options that their walls mean little and the options are hard to trade - skip them, or a tiny size. Smallest first (the whole option chain in ₹ crore):</p><div>${(D.thin||[]).map(x=>`<a href="${shareURL(x[0])}" target="_blank" style="color:inherit">${esc(x[0])}</a> <span class="dim">₹${x[1]} cr</span>`).join(" · ")}</div>`;
  else m.innerHTML=list(TAB==="pe"?D.pe:TAB==="ce"?D.ce:TAB==="retest"?D.retest:(D.breakout||[]).concat(D.breakdown||[])); }
function paint(){ if(!D) return;
  document.getElementById("top").innerHTML=`<div class="title">📋 Tomorrow's checklist</div>
    <div class="sub">from NSE's end-of-day file of ${esc(D.day)} · made ${esc(D.made)} · ${D.n} F&amp;O shares · NIFTY 5 days ${D.nifty5!=null?pc(D.nifty5):"-"} · levels for the day: trade the live entry after 09:30, half size, out by 15:15</div>
    <div id="lvst"></div><div class="tabs" id="tabs"></div>
    ${["pe","ce","retest","bo"].includes(TAB)?`<div class="ctl">sort <select onchange="setv('sort',this.value)"><option value="rank"${SORT==="rank"?" selected":""}>by rank (score)</option><option value="big"${SORT==="big"?" selected":""}>biggest wall first</option><option value="near"${SORT==="near"?" selected":""}>closest wall first</option></select>
      show <select onchange="setv('big',this.value)"><option value="all"${BIG==="all"?" selected":""}>all walls</option><option value="big"${BIG==="big"?" selected":""}>big walls only</option></select></div>`:""}`;
  paintBody(); }
async function pull(){ try{ const r=await fetch("checklistdata"+Q,{cache:"no-store"}); if(r.ok){ const d=await r.json(); if(d&&d.day){ D=d; paint(); }
  else document.getElementById("top").innerHTML='<div class="title">📋 Tomorrow\'s checklist</div><div class="sub">not made yet - GIR makes it every market evening at 19:15</div>'; } }catch(e){} }
pull(); setInterval(()=>{ if(!document.hidden) pull(); },300000);
async function pullLive(){ try{ const r=await fetch("checklistlive"+Q,{cache:"no-store"}); if(r.ok){ LV=await r.json(); paintBody(); } }catch(e){} }      /* patch 303 */
pullLive(); setInterval(()=>{ if(!document.hidden) pullLive(); },3000);
</script></body></html>
HTML_CL
cat > $W/p303test.py <<'PY_T303'
#!/usr/bin/env python3
"""p303test.py - 📋 THE CHECKLIST, LIVE: each share's stage every round - wait, at the level, entry live, then target / out / broke / closed
(made-up shares, temp folder, nothing sent)"""
import os, sys, json, time, shutil, tempfile, collections
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
WW.ENVF = os.path.join(T, "no.env"); WW.BASE = T
WW.CL_F = os.path.join(T, "data", "checklist.json"); WW.CLL_F = os.path.join(T, "data", "checklist_live.json")
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:600]))
def it(s, side, roof, floor, lo=0.0, hi=0.0, kind=None):
    return {"s": s, "side": side, "px": 0, "chg": 0, "score": 6, "kind": kind, "lo": lo, "hi": hi,
            "roof": {"k": roof, "dist": 1, "cr": 500, "den": "DENSE", "add": 20} if roof else None,
            "floor": {"k": floor, "dist": 1, "cr": 500, "den": "DENSE", "add": 20} if floor else None}
json.dump({"day": "2026-11-13", "pe": [it("PECO", "PE", 100, 90), it("BRKCO", "PE", 200, 180), it("LOWCO", "PE", 500, 450, lo=480)],
           "ce": [it("CECO", "CE", 60, 50)], "retest": [it("WAITCO", "PE", 1000, 900)], "breakout": [it("BOCO", "CE", 300, 250, kind="breakout")],
           "breakdown": [], "thin": []}, open(WW.CL_F, "w"))
DAY = "2026-11-16"
W = type("W", (), {})(); W.h = collections.defaultdict(lambda: collections.deque(maxlen=50))
TU = type("TU", (), {})(); TU.base = {s: 1_000_000 for s in ("PECO", "BRKCO", "LOWCO", "CECO", "WAITCO", "BOCO")}
CK = type("CK", (), {})(); CK.vw = {}; CK.wm_list = []
T0 = 1_800_000_000.0
def at(sec, s, px, vwap, oi=1_020_000):
    W.h[s].append((T0 + sec, px, -0.5, oi, 0, 0, 0)); CK.vw[s] = {"pv": vwap * 1000, "v": 1000}
CL = WW.CheckLive(DAY)
def step(sec, hm):
    return CL.step(T0 + sec, hm, W, TU, CK)
# 09:17 - LOWCO under yesterday's low and under VWAP, but before 09:20: no entry yet
for s, p, v in (("PECO", 98, 98.5), ("BRKCO", 195, 196), ("LOWCO", 479, 482), ("CECO", 52, 51.8), ("WAITCO", 950, 951), ("BOCO", 298, 297)):
    at(0, s, p, v)
L = step(0, "09:17:00")
chk("before 09:20 nothing goes live (LOWCO already under yesterday's low - waits)", L["LOWCO|PE"]["state"] == "wait", L["LOWCO|PE"])
chk("every share on the list gets a live line: price, the ceiling / floor distance now, its VWAP side, the futures now",
    len(L) == 6 and L["PECO|PE"]["px"] == 98 and L["PECO|PE"]["roof"] == 2.04 and L["PECO|PE"]["floor"] == 8.16 and L["PECO|PE"]["vside"] == -1 and L["PECO|PE"]["doi"] == 2.0, L.get("PECO|PE"))
at(240, "LOWCO", 479, 482); L = step(240, "09:21:00")
chk("09:21 LOWCO: broke the day's low under VWAP -> ✅ entry live", L["LOWCO|PE"]["state"] == "live" and "day's low" in L["LOWCO|PE"]["note"] and L["LOWCO|PE"]["entry_t"] == "09:21", L["LOWCO|PE"])
# PECO: up to the ceiling 100 (at), then turns back under VWAP 0.6% off it -> live, then 2% its way -> target
at(300, "PECO", 99.7, 99.0); CK.wm_list = [{"s": "PECO", "dir": -1, "t": "09:22", "note": "👀 watch - at the wall"}]; L = step(300, "09:22:00")
chk("PECO at ₹99.7 - within 0.5% of the ceiling 100 -> 👀 at the level (and the 👀 that rang shows)", L["PECO|PE"]["state"] == "at" and L["PECO|PE"]["rang"] == ["09:22 👀"], L["PECO|PE"])
at(400, "PECO", 99.4, 99.6); L = step(400, "09:24:00")
chk("PECO back to ₹99.4 under VWAP (0.6% under the ceiling) -> ✅ entry live at ₹99.4", L["PECO|PE"]["state"] == "live" and L["PECO|PE"]["entry_px"] == 99.4, L["PECO|PE"])
at(900, "PECO", 97.3, 98.5); L = step(900, "09:33:00")
chk("PECO down to ₹97.3 (2.1% its way) -> ✔ target, moves to the Done tab", L["PECO|PE"]["state"] == "target" and L["PECO|PE"]["res"] == 2.11 and L["PECO|PE"]["done_t"] == "09:33", L["PECO|PE"])
# BRKCO: at the ceiling 200, then through it by 0.6% before any entry -> broke
at(500, "BRKCO", 200.5, 199); step(500, "09:25:00"); at(560, "BRKCO", 201.2, 200); L = step(560, "09:26:00")
chk("BRKCO went 0.6% through its ceiling 200 before any entry -> ⚠ broke (the PE is off)", L["BRKCO|PE"]["state"] == "broke" and "off" in L["BRKCO|PE"]["note"], L["BRKCO|PE"])
# CECO: dips to the floor 50, holds over VWAP -> live; then back under the floor -> out
at(600, "CECO", 50.2, 50.6); step(600, "09:27:00"); at(660, "CECO", 50.4, 50.3); L = step(660, "09:28:00")
chk("CECO dipped to the floor 50 and turned back over VWAP -> ✅ entry live", L["CECO|CE"]["state"] == "live", L["CECO|CE"])
at(720, "CECO", 49.9, 50.2); L = step(720, "09:29:00")
chk("CECO closed back under the floor 50 -> ✖ out (with its result)", L["CECO|CE"]["state"] == "out" and L["CECO|CE"]["res"] == -0.99, L["CECO|CE"])
# BOCO breakout: held 0.4% over the ceiling 300 on its VWAP side -> live; 0.7% more is not a target (2% only)
at(800, "BOCO", 301.2, 300.5); L = step(800, "09:31:00")
chk("BOCO held 0.4% over its ceiling 300 above VWAP -> ✅ breakout live", L["BOCO|CE"]["state"] == "live", L["BOCO|CE"])
at(860, "BOCO", 303.3, 301); L = step(860, "09:32:00")
chk("BOCO +0.7% - still live (a breakout's target is 2%, not the wall it broke)", L["BOCO|CE"]["state"] == "live" and L["BOCO|CE"]["move"] == 0.7, L["BOCO|CE"])
# a restart keeps the day
CL = WW.CheckLive(DAY); L = step(900, "09:33:00")
chk("a restart keeps the day: PECO still ✔ target, BOCO still live", L["PECO|PE"]["state"] == "target" and L["BOCO|CE"]["state"] == "live", {k: v["state"] for k, v in L.items()})
chk("a new day starts fresh", WW.CheckLive("2026-11-17").st == {})
# 15:15 - everything still open closes
L = step(21000, "15:15:00")
chk("15:15: BOCO (live) closed with its result, WAITCO (never reached) closed", L["BOCO|CE"]["state"] == "closed" and L["BOCO|CE"]["res"] == 0.7 and L["WAITCO|PE"]["state"] == "closed" and "never" in L["WAITCO|PE"]["note"], {k: (v["state"], v.get("res")) for k, v in L.items()})
J = json.load(open(WW.CLL_F))
chk("data/checklist_live.json written (the day, the time, every share's stage)", J["day"] == DAY and J["hm"] == "15:15" and len(J["live"]) == 6 and len(J["st"]) == 6, list(J))
print("THE PATCH 303 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_T303
cat > $W/p299test.py <<'PY_T299'
#!/usr/bin/env python3
"""p299test.py - the cockpit's top 5 (your views, then 🧱 / 🧲 / 🚀 / 🌪) + any share's cockpit on request (made-up shares, temp folder, nothing sent)"""
import os, sys, json, time, shutil, tempfile, collections, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("windwatch.py", "cockpitask.py"):
    shutil.copy(os.path.join(WK, f), T)
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW, cockpitask as CA
WW.ENVF = os.path.join(T, "no.env"); WW.BASE = T; WW.CK_F = os.path.join(T, "data", "cockpit.json"); WW.CK_ASKF = os.path.join(T, "data", "cockpit_ask.json")
WW.VIEWF = os.path.join(T, "data", "views.json"); CA.F = WW.CK_ASKF
WW.dash_state = lambda: {}
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:600]))
json.dump({"v": {"RELIANCE": -1}}, open(WW.VIEWF, "w"))
t0 = time.time() - 600
names = ["RELIANCE", "WALLCO", "STEADCO", "MOMCO", "BIGCO", "OTHER1", "OTHER2", "ASKCO"]
W = WW.Wind(secmap={"X": names})
class TU: base = {s: 1_000_000 for s in names}
class O_:
    h = collections.defaultdict(lambda: collections.deque(maxlen=50)); now = {}; spot = {}
for k in range(100):
    for i, s in enumerate(names):
        W.h[s].append((t0 + 3 * k, 100 + i, (-1) ** i * 1.2, 1_000_000 * (1 + 0.0002 * k), 1000, 1000, 1000 + 10 * k))
    W.h["NIFTY50"].append((t0 + 3 * k, 25000.0, -0.2, None, 0, 0, 0))
CK = WW.Cockpit(str(dt.date.today()))
CK.wm_list = [{"s": "WALLCO", "dir": -1, "note": "card sent"}, {"s": "OTHER2", "dir": 1, "note": "👀 watch - at the wall"}]
CK.steady_list = [{"s": "STEADCO", "dir": -1, "note": "card sent"}]
class MO: list = [{"s": "MOMCO", "dir": 1}]
BL = [{"s": "OTHER1", "dir": 1}, {"s": "BIGCO", "dir": -1}]
class LD: list = []
tN = t0 + 300
CK.write(tN, "10:30:00", W, TU, O_(), MO, BL, LD)
j = json.load(open(WW.CK_F))
got = [b["s"] for b in j["boxes"]]
chk("5 boxes: your view (RELIANCE) first, then 🧱 WALLCO, 🧲 STEADCO, then the latest 🌪 / 🚀 (BIGCO, OTHER1) (got %s)" % got,
    len(got) == 5 and got[0] == "RELIANCE" and got[1] == "WALLCO" and got[2] == "STEADCO" and set(got[3:]) <= {"BIGCO", "OTHER1", "MOMCO"}, got)
chk("a 👀 watch alone does not take a box (OTHER2)", "OTHER2" not in got, got)
chk("cockpitask: a bad name is refused, a good one written", CA.ask("../etc") is False and CA.ask("askco") is True and "ASKCO" in json.load(open(WW.CK_ASKF)))
CK.write(tN + 3, "10:30:03", W, TU, O_(), MO, BL, LD)
j = json.load(open(WW.CK_F))
a = (j.get("ask") or {}).get("ASKCO")
chk("ASKCO asked from its page -> its full box in the cockpit's data within a round ('asked from its page', the price's side today)", a and a["s"] == "ASKCO" and a["how"] == "asked from its page" and a["checks"], a)
J = json.load(open(WW.CK_ASKF)); J["ASKCO"] = time.time() - 600; json.dump(J, open(WW.CK_ASKF, "w"))
CK.write(tN + 6, "10:30:06", W, TU, O_(), MO, BL, LD)
chk("an ask older than 2 min is dropped (the page renews it every 30 s while open)", "ASKCO" not in (json.load(open(WW.CK_F)).get("ask") or {}))
print("THE PATCH 299 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_T299
cat > $W/cockpitask.py <<'PY_ASK'
"""cockpitask.py - patch 299: a share's own page asks for its 🎯 cockpit box -> data/cockpit_ask.json (the wind watcher reads it every 3 s,
works out that share's box and puts it in the cockpit's data; the page renews the ask every 30 s, an ask is kept 2 min)."""
import os, re, json, time
BASE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(BASE, "data", "cockpit_ask.json")


def ask(sym, now=None):
    s = (sym or "").upper().strip()
    if not re.fullmatch(r"[A-Z0-9&\-]{1,20}", s):
        return False
    now = now or time.time()
    try:
        J = json.load(open(F))
    except Exception:
        J = {}
    J = {k: v for k, v in J.items() if now - float(v) <= 300}
    J[s] = now
    J = dict(sorted(J.items(), key=lambda x: -x[1])[:10])
    os.makedirs(os.path.dirname(F), exist_ok=True)
    json.dump(J, open(F + ".tmp", "w")); os.replace(F + ".tmp", F)
    return True
PY_ASK
echo "=== tests (made-up shares, nothing sent)"
for t in p303test p299test; do python3 $W/$t.py $W > $W/t.out 2>&1; RC=$?; tail -1 $W/t.out; [ $RC -eq 0 ] || { cat $W/t.out; echo "❌ $t failed - nothing changed"; exit 1; }; done
cp $W/windwatch.py $D/windwatch.py && cp $W/checklist.html $D/checklist.html || back
python3 - $D <<'PY_EDIT' || back
import os, sys
D = sys.argv[1]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 303" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/checklistlive":            # patch 303: the checklist, live (windwatch.py, every 3 s)
                try:
                    body_ = open(os.path.join(BASE, "data", "checklist_live.json"), "rb").read()
                except Exception:
                    body_ = b'{}'
                return self.send(200, body_, "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /checklistlive")
PY_EDIT
cd $D && python3 -m py_compile windwatch.py dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/checklist.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the checklist page's code checked ✓"
fi
systemctl restart gir-windwatch gir-dash; sleep 6
echo "  gir-windwatch: $(systemctl is-active gir-windwatch) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-windwatch)" = "active" ] || back
echo "✅ patch 303 done - girtrader.com/checklist goes live from 09:20 on Monday: a LIVE line on every share, ✅ / 👀 on top, done ones in ✔ Done. Ctrl + Shift + R."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-windwatch gir-dash"
