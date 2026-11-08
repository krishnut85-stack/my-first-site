#!/bin/bash
# PATCH 135b - THE OI BATTLE: THE LAST CLOSE FOR EVERY SHARE (on top of patch 135).
#   ASHOKLEY read "no reading of the last close yet": GIR's 15-min chain readings hold only the shares watched that day.
#   The last session's close now also comes from the daily chain readings and NSE's end-of-day file (patch 132) - every strike.
#   oibattle.py (replaced - patch 135's own file). Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g135b; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p135b.sh now"; exit 1; fi
[ -f $D/oibattle.py ] || { echo "patch 135 is not installed yet - paste patch 135 first"; exit 1; }
grep -q "patch 135b" $D/oibattle.py && { echo "patch 135b is already installed"; exit 1; }
cp $D/oibattle.py $D/oibattle.py.bak$TS
back() { cp $D/oibattle.py.bak$TS $D/oibattle.py; rm -f $D/p135btest.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old file back, nothing changed"; exit 1; }
cat > $W/oibattle.py <<'PY_BAT'
#!/usr/bin/env python3
"""oibattle.py - patch 135 (+135b: the last close from the daily chain and NSE's end-of-day file when the share was not watched that day): THE OI BATTLE, IN WORDS. Not "high resistance at 180" but who is doing what and who is winning:

  option WRITERS (sellers) are mostly the big money (a lot needs ₹1-2 lakh of margin); they win when the price stays away.
  CEILING  the strike above the price with the most calls written - they defend it (they sell futures / shares as the price
           comes near: that selling IS the resistance); if it breaks they must buy back fast (short covering: the move speeds up)
  FLOOR    below the price, the most puts written - the support, the same way down
  today    who wrote more (puts = they see no fall: bullish · calls = they see no rise: bearish), who GAVE UP (call writers
           below the price covering = bullish · put writers above the price covering = bearish), the floor / ceiling moving
  verdict  BULLISH / BEARISH / BATTLE, the two levels and what confirms each:
             breakout   the price holds above the ceiling AND the ceiling's call OI falls (the writers leave) -> CE to the next wall
             rejection  it stalls under the ceiling, its call OI keeps rising, the floor's put OI falls -> back to the floor
  IV       percentile 80+: options are expensive - buy only on the confirmed break, small, quick stop
From GIR's own chain readings (chain15, every 15 min) against the last close (+ NSE's end-of-day file for the far strikes).

  share card   THE OI BATTLE (the story + the two levels)
  Telegram     "⚔ battle:" under the 🧩 OI alerts
  python3 oibattle.py ASHOKLEY"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {}


def _lk(v):
    a = abs(v or 0)
    return ("%.2f Cr" % (a / 1e7)) if a >= 1e7 else ("%.1f L" % (a / 1e5)) if a >= 1e5 else "%d" % a


def _pc(now, ref):
    return round((now / ref - 1) * 100) if ref else None


def _prev_session(day):
    """the trading session before `day` (sessions.py: holidays and special sessions known)"""
    try:
        import sessions
        x = dt.date.fromisoformat(str(day)[:10])
        for _ in range(10):
            x -= dt.timedelta(days=1)
            if sessions.session(x):
                return str(x)
    except Exception:
        return None
    return None


def chain(sym, day=None):
    """-> (day, exp, spot, {(strike, kind): oi now}, {(strike, kind): oi at the last close}) from chains.db (+ NSE's file)"""
    con = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)
    try:
        tabs = set(r[0] for r in con.execute("select name from sqlite_master where type='table'"))
        tb = "chain15" if "chain15" in tabs else "chain" if "chain" in tabs else None
        if not tb:
            return None
        day = day or con.execute("select max(d) from %s where sym=?" % tb, (sym,)).fetchone()[0]
        if not day:
            return None
        rows = con.execute("select t, exp, strike, kind, oi, spot from %s where d=? and sym=? %s order by t" % (tb, "and t!='EOD'" if tb == "chain" else ""), (day, sym)).fetchall()
        if not rows:
            return None
        exp = sorted({r[1] for r in rows})[0]
        cur, spot = {}, None
        for t, e, k, kd, oi, sp in rows:
            if e == exp:
                cur[(float(k), kd)] = oi
                spot = sp or spot
        pd_ = _prev_session(day) or con.execute("select max(d) from %s where d<?" % tb, (day,)).fetchone()[0]
        prev = {}
        if pd_:                                                 # patch 135b: the last session's close - GIR's own readings of the share
            for t2 in [x for x in (tb, "chain") if x in tabs]:  # (chain15 holds only the shares watched that day), then the daily chain,
                q2 = "select t, strike, kind, oi from %s where d=? and sym=? and exp=? %s order by t" % (t2, "and t!='EOD'" if t2 == "chain" else "")
                got = {}
                for t, k, kd, oi in con.execute(q2, (pd_, sym, exp)):
                    got[(float(k), kd)] = oi
                for kk, v in got.items():
                    prev.setdefault(kk, v)
        try:
            import bhavfull
            for kk, row in (bhavfull.prev_for(sym, pd_, exp) if pd_ else {}).items():
                for kd, v in row.items():
                    prev.setdefault((float(kk), kd.upper()), v[0])
        except Exception:
            pass
    finally:
        con.close()
    return day, exp, spot, cur, prev


def read(sym, ivp=None, data=None):
    """-> {"verdict", "score", "lines": [the story], "breakout": {...}, "rejection": {...}, "short": one line} or None"""
    sym = (sym or "").upper()
    c = _C.get(sym)
    if c and time.time() - c[0] < 60 and data is None:
        out = dict(c[1])
    else:
        try:
            ch = data or chain(sym)
        except Exception:
            ch = None
        if not ch:
            return None
        day, exp, spot, cur, prev = ch
        if not cur or not spot:
            return None
        out = _read(sym, day, exp, spot, cur, prev)
        if data is None:
            _C[sym] = (time.time(), dict(out))
    if out and ivp is not None and ivp >= 80:
        out["lines"] = out["lines"] + ["IV percentile %d: options are EXPENSIVE - a calm day shrinks the premium even if the price holds; buy only on the confirmed break, small, quick stop" % ivp]
    return out


def _read(sym, day, exp, spot, cur, prev):
    ks = sorted({k for k, _ in cur})
    g = lambda k, kd: cur.get((k, kd))
    p = lambda k, kd: prev.get((k, kd))
    up = [k for k in ks if k >= spot and g(k, "CE")]
    dn = [k for k in ks if k <= spot and g(k, "PE")]
    if not up or not dn:
        return None
    ceil_ = max(up, key=lambda k: g(k, "CE"))
    floor_ = max(dn, key=lambda k: g(k, "PE"))
    nxt = sorted([k for k in up if k > ceil_], key=lambda k: -(g(k, "CE") or 0))
    nxt = nxt[0] if nxt else None
    # yesterday's walls
    pup = [k for k in ks if k >= spot and p(k, "CE")]
    pdn = [k for k in ks if k <= spot and p(k, "PE")]
    pfloor = max(pdn, key=lambda k: p(k, "PE")) if pdn else None
    pceil = max(pup, key=lambda k: p(k, "CE")) if pup else None
    add = lambda kd: sum((g(k, kd) or 0) - p(k, kd) for k in ks if p(k, kd) is not None and g(k, kd) is not None)
    ce_add, pe_add = add("CE"), add("PE")
    cover_ce = [(k, _pc(g(k, "CE"), p(k, "CE"))) for k in ks if k < spot and p(k, "CE") and g(k, "CE") is not None and g(k, "CE") < p(k, "CE") * 0.9]
    cover_pe = [(k, _pc(g(k, "PE"), p(k, "PE"))) for k in ks if k > spot and p(k, "PE") and g(k, "PE") is not None and g(k, "PE") < p(k, "PE") * 0.9]
    pw = sorted([(k, (g(k, "PE") or 0) - (p(k, "PE") or 0)) for k in ks if p(k, "PE") is not None], key=lambda x: -x[1])[:1]
    cw = sorted([(k, (g(k, "CE") or 0) - (p(k, "CE") or 0)) for k in ks if p(k, "CE") is not None], key=lambda x: -x[1])[:1]
    S, L = 0, []
    L.append("CEILING %g: %s calls written%s - the writers bet it stays under %g till %s; near it they sell (the resistance), above it they must buy back (the move speeds up)" % (
        ceil_, _lk(g(ceil_, "CE")), (" (%+d%% today)" % _pc(g(ceil_, "CE"), p(ceil_, "CE"))) if p(ceil_, "CE") else "", ceil_, dt.date.fromisoformat(str(exp)[:10]).strftime("%d %b")))
    L.append("FLOOR %g: %s puts written%s - they bet it stays above %g" % (floor_, _lk(g(floor_, "PE")), (" (%+d%% today)" % _pc(g(floor_, "PE"), p(floor_, "PE"))) if p(floor_, "PE") else "", floor_))
    if prev:
        tot = abs(ce_add) + abs(pe_add)
        r = (pe_add - ce_add) / tot if tot else 0
        if r > 0.2:
            S += 1; L.append("today PUTS written more (%s vs calls %s): big money sees no fall - bullish" % (_lk(pe_add), _lk(ce_add)))
        elif r < -0.2:
            S -= 1; L.append("today CALLS written more (%s vs puts %s): big money sees no rise - bearish" % (_lk(ce_add), _lk(pe_add)))
        if pw and pw[0][1] > 0:
            L.append("most new puts at %g (+%s%s)" % (pw[0][0], _lk(pw[0][1]), (", %+d%%" % _pc(g(pw[0][0], "PE"), p(pw[0][0], "PE"))) if p(pw[0][0], "PE") else ""))
        if cw and cw[0][1] > 0:
            L.append("most new calls at %g (+%s%s)" % (cw[0][0], _lk(cw[0][1]), (", %+d%%" % _pc(g(cw[0][0], "CE"), p(cw[0][0], "CE"))) if p(cw[0][0], "CE") else ""))
        if cover_ce:
            S += 1; L.append("call writers GAVE UP below the price: %s - they lost and bought back (that buying pushed it up)" % ", ".join("%g %+d%%" % x for x in cover_ce[:3]))
        if cover_pe:
            S -= 1; L.append("put writers GAVE UP above the price: %s - they lost and bought back (bearish)" % ", ".join("%g %+d%%" % x for x in cover_pe[:3]))
        if pfloor and floor_ != pfloor:
            S += 1 if floor_ > pfloor else -1; L.append("the FLOOR moved %s: %g → %g" % ("UP" if floor_ > pfloor else "DOWN", pfloor, floor_))
        if pceil and ceil_ != pceil:
            S += 1 if ceil_ > pceil else -1; L.append("the CEILING moved %s: %g → %g" % ("UP" if ceil_ > pceil else "DOWN", pceil, ceil_))
    else:
        L.append("no reading of the last close yet - today's changes come with the next close")
    verdict = "BULLISH" if S >= 2 else "BEARISH" if S <= -2 else "BATTLE"
    dist = (ceil_ / spot - 1) * 100
    bo = {"level": ceil_, "confirm": "the price holds above %g AND the %g CE open interest falls (the writers leave)" % (ceil_, ceil_),
          "then": ("CE - towards the next wall %g" % nxt) if nxt else "CE"}
    rj = {"level": ceil_, "confirm": "it stalls under %g, the %g CE OI keeps rising and the %g PE OI falls" % (ceil_, ceil_, floor_), "then": "back towards the floor %g (PE)" % floor_}
    short = "%s · price %g · ceiling %g (%s CE%s) · floor %g (%s PE%s) · break = above %g with its CE OI falling" % (
        verdict, round(spot, 2), ceil_, _lk(g(ceil_, "CE")), (" %+d%%" % _pc(g(ceil_, "CE"), p(ceil_, "CE"))) if p(ceil_, "CE") else "",
        floor_, _lk(g(floor_, "PE")), (" %+d%%" % _pc(g(floor_, "PE"), p(floor_, "PE"))) if p(floor_, "PE") else "", ceil_)
    return {"s": sym, "day": day, "exp": str(exp), "spot": spot, "verdict": verdict, "score": S, "ceil": ceil_, "floor": floor_, "next": nxt,
            "dist": round(dist, 1), "lines": L, "breakout": bo, "rejection": rj, "short": short}


SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")


def add_line(text):
    """a 🧩 OI alert -> + "⚔ battle: ..." (once); anything else unchanged"""
    try:
        L = (text or "").split("\n")
        h = L[0][len("🔔 OPENING · "):] if L[0].startswith("🔔 OPENING · ") else (L[1] if L[0].startswith("🔔 OPENING") and len(L) > 1 else L[0])
        if not h.startswith("🧩") or "⚔ battle:" in text:
            return text
        m = SYM_RX.search(h)
        if not m or m.group(1) in ("NIFTY", "BANKNIFTY"):
            return text
        b = read(m.group(1))
        return text.rstrip("\n") + "\n⚔ battle: " + b["short"] if b else text
    except Exception:
        return text


if __name__ == "__main__":
    for s in sys.argv[1:] or ["ASHOKLEY"]:
        b = read(s)
        if not b:
            print("%s: no chain reading" % s); continue
        print("%s %s (%s, expiry %s) · score %+d" % (s, b["verdict"], b["day"], b["exp"], b["score"]))
        for x in b["lines"]:
            print("  · " + x)
        print("  BREAKOUT  %s -> %s" % (b["breakout"]["confirm"], b["breakout"]["then"]))
        print("  REJECTION %s -> %s" % (b["rejection"]["confirm"], b["rejection"]["then"]))
PY_BAT
cat > $D/p135btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p135btest.py - THE OI BATTLE when the share was not watched on the last session (Rama's ASHOKLEY, 8 Nov: "no reading of the
last close yet"): the last close comes from NSE's end-of-day file of the session before -> the same BULLISH read."""
import os, sys, json, sqlite3, tempfile, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import oibattle, bhavfull, holidays
holidays.holiday = lambda d=None: ("weekend" if d.weekday() >= 5 else None)
tmp = tempfile.mkdtemp(prefix="p135b")
try:
    oibattle.BASE = tmp; oibattle._C.clear()
    bhavfull.DIR = os.path.join(tmp, "bhav"); bhavfull._MEM.clear(); os.makedirs(bhavfull.DIR)
    CE = {170: (50.00, -24.18), 172.5: (13.45, -15.40), 175: (54.05, 6.08), 177.5: (19.90, 88.62), 180: (85.20, 24.19), 182.5: (12.00, 56.86), 185: (42.45, 14.72)}
    PE = {170: (64.20, -8.61), 172.5: (21.85, 82.84), 175: (36.20, 168.14), 177.5: (4.25, 0.0), 180: (35.60, 92.95), 182.5: (1.75, 0.0), 185: (24.30, -3.57)}
    c = sqlite3.connect(os.path.join(tmp, "chains.db"))
    c.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
    c.execute("insert into chain15 values('2026-11-06','15:25','TCS','2026-11-23',3000,'CE',1,1,3000)")       # another share watched on Friday
    o = {}
    for kd, M in (("CE", CE), ("PE", PE)):
        for k, (now, pc) in M.items():
            c.execute("insert into chain15 values(?,?,?,?,?,?,?,?,?)", ("2026-11-08", "15:25", "ASHOKLEY", "2026-11-23", k, kd, now * 1e5, 1, 178.0))
            o.setdefault("%g" % k, {})[kd.lower()] = [now * 1e5 / (1 + pc / 100), 1.0]
    c.commit(); c.close()
    json.dump({"d": "2026-11-06", "s": {"ASHOKLEY": {"spot": 172.1, "o": {"2026-11-23": o}}}}, open(os.path.join(bhavfull.DIR, "2026-11-06.json"), "w"))
    b = oibattle.read("ASHOKLEY")
    check("ASHOKLEY not watched on Friday: the last close from NSE's file -> %s (score %+d)" % (b["verdict"], b["score"]),
          b["verdict"] == "BULLISH" and not any("no reading of the last close" in x for x in b["lines"]) and any("GAVE UP" in x for x in b["lines"]))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP135B LAST CLOSE TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cp $W/oibattle.py $D/oibattle.py
cd $D && python3 -m py_compile oibattle.py p135btest.py || back
timeout 120 python3 p135btest.py 2>&1 | grep "OK  \|FAIL\|P135B"
timeout 120 python3 p135btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p135test.py p134test.py p133test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 135b APPLIED. Ashok Leyland again, from your server's own data:"
cd $D && timeout 60 python3 oibattle.py ASHOKLEY
