#!/bin/bash
# PATCH 223 - RESULTS-DAY WATCH (PAGEIND 12 Nov: results 14:29:53, -2% at 14:30:30, the band -10% at 14:36:45, -13.2% at 14:50 - GIR said
#   "RESULTS just filed", "IN LINE" and a wrong-way SHORT COVERING, never "BUY PE", and nothing about the second leg).
#   🚨 RESULTS REACTION ▼/▲ SYM - BUY PE / CE within ~a minute of the filing (1.5%+ on 5x volume, or 2.5%+): a P1 (the ambulance), the price
#      is the verdict, the stop = back over / under the price before the results; THE VOTE never turns it down; the EXIT WATCH follows it
#   PROFIT BOOKING / SHORT COVERING on a share with results in the last 30 min: only after a real turn (5 min with no new extreme)
#   🧱 CIRCUIT NEAR (2% from the band, 5%+ on the day) · 🧱 CIRCUIT BAND WIDENED (the shares near a band re-read every 60 s)
#   Tested: 19 cases on PAGEIND's real times and prices + the simulated day; then TODAY's results filings replayed on this server's candles.
#   Restarts the engine and the news hunt - run it after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); mkdir -p $W/src
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/pbook.py ] && grep -q "patch 215" $D/newshunt.py || { echo "patch 215 first"; exit 1; }
F="newshunt.py pbook.py engine2.py"; [ -f $D/p1vote.py ] && F="$F p1vote.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-newshunt"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/resultreact.py $D/bandwatch.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/src/resultreact.py <<'PY_RR'
#!/usr/bin/env python3
"""resultreact.py - patch 223: 🚨 RESULTS REACTION - a P1 trade call within a minute of the results (Rama, 12 Nov: PAGEIND filed its results at
14:29:53, the share was -2% at 14:30:30 and -10% (the band) at 14:36:45 - GIR said "RESULTS just filed" and "IN LINE", never "BUY PE").
Runs inside the news hunt (every 15 s, live prices). For every F&O share whose RESULTS were filed in the last 20 minutes:
  the price when the filing landed -> the price now: 1.5%+ with this 5-min candle's volume 5x+ normal (or 2.5%+ on any volume)
  -> 🚨 CRITICAL · RESULTS REACTION ▼ SYM: BUY PE (▲: BUY CE) - the price is the verdict (when GIR's reader said IN LINE / BEAT and the
     price falls, it says so) · the stop: a close back over (under) the price before the results. Once a share a side.
It is a P1 on its own proof (the filing + the price + the volume) - THE VOTE (patch 225) shows its checks but never turns it down."""
import os, re, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
WINDOW, MOVE_VOL, MOVE_ANY, VOLX = 1200, 1.5, 2.5, 5.0
ST = {"day": None, "said": set(), "p0": {}, "loaded": 0.0, "res": {}}
_F = {}


def _charts():
    t, v = _F.get("ch", (0.0, None))
    if v is None or time.time() - t > 10:
        try:
            v = json.load(open(os.path.join(BASE, "charts.json")))
        except Exception:
            v = {}
        _F["ch"] = (time.time(), v)
    return v


def results_today(day, now_t):
    """{sym: (filed epoch, GIR's verdict)} - today's RESULTS filings (read every 15 s)"""
    if now_t - ST["loaded"] < 15:
        return ST["res"]
    ST["loaded"] = now_t
    d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST).timestamp()
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "filings.db"), uri=True, timeout=3)
        for s, te, ver in c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>=? order by t_exch", (d0,)):
            if s and s not in out:
                out[s] = (float(te), ver or "")
        c.close()
    except Exception:
        pass
    ST["res"] = out
    return out


def _p_before(sym, te):
    """the price before the results: the close of the 5-min candle before the one the filing landed in (else its open)"""
    c = _charts().get(sym) or {}
    C, O = c.get("c") or [], c.get("o") or []
    tm = dt.datetime.fromtimestamp(te, IST)
    i = ((tm.hour * 60 + tm.minute) - 555) // 5
    if 1 <= i <= len(C) and C[i - 1]:
        return C[i - 1]
    if 0 <= i < len(O) and O[i]:
        return O[i]
    return None


def _volx(sym, now):
    c = _charts().get(sym) or {}
    V = c.get("v") or []
    n = min(len(V), ((now.hour * 60 + now.minute) - 555) // 5 + 1)
    base = sorted(x for x in V[:max(0, n - 1)] if x)
    if len(base) < 3 or n < 1 or not V[n - 1]:
        return None
    return V[n - 1] / base[len(base) // 2]


def _inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def tick(now, ltp, chg=None, fo=None):
    """now (IST) · ltp {sym: price} -> [alert texts]"""
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "said": set(), "p0": {}, "loaded": 0.0, "res": {}})
    hm = now.strftime("%H:%M")
    if not ("09:15" <= hm <= "15:25"):
        return []
    t = now.timestamp()
    out = []
    for s, (te, ver) in results_today(day, t).items():
        if (fo and s not in fo) or not (0 <= t - te <= WINDOW):
            continue
        px = ltp.get(s)
        if not px:
            continue
        if s not in ST["p0"]:
            ST["p0"][s] = _p_before(s, te) or px                  # the close before the filing's candle (else the price now)
        p0 = ST["p0"][s]
        mv = (px / p0 - 1) * 100
        d = 1 if mv > 0 else -1
        if (s, d) in ST["said"]:
            continue
        vx = _volx(s, now)
        if not (abs(mv) >= MOVE_ANY or (abs(mv) >= MOVE_VOL and vx and vx >= VOLX)):
            continue
        ST["said"].add((s, d))
        mins = max(1, int(round((t - te) / 60)))
        read = "MISS" if d < 0 else "BEAT"
        vd = (ver or "").upper()
        said = ""
        if vd and ((d < 0 and re.search(r"BEAT|IN LINE|INLINE", vd)) or (d > 0 and re.search(r"MISS|IN LINE|INLINE", vd))):
            said = " - GIR's reader said %s, the price says %s: the price is the verdict" % (vd[:24], read)
        side = "PE" if d < 0 else "CE"
        out.append("\n".join([
            "🚨 CRITICAL · RESULTS REACTION %s %s · %s" % ("▼" if d < 0 else "▲", s, hm),
            "results filed %s · the share %+.1f%% since (₹%s -> ₹%s) in %d min%s · %+.1f%% today" % (
                dt.datetime.fromtimestamp(te, IST).strftime("%H:%M:%S"), mv, _inr(p0), _inr(px), mins, (" · volume %.0fx normal" % vx) if vx else "",
                (chg or {}).get(s) or 0),
            "the market reads it as a %s%s" % (read, said),
            "▶ BUY %s (at the money) - %s · stop: a close %s ₹%s (where it was before the results)" % (
                side, "▼ DOWN → PE" if d < 0 else "▲ UP → CE", "over" if d < 0 else "under", _inr(p0)),
            "results moves run fast: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    return out
PY_RR
cat > $W/src/bandwatch.py <<'PY_BW'
#!/usr/bin/env python3
"""bandwatch.py - patch 223: the F&O price bands (PAGEIND 12 Nov: the lower band -10% at 14:36:45, the band widened, -13.2% at 14:50 - GIR
said nothing about the second leg). Called by the engine's circuit agent:
  near()     every second, every F&O share: 🧱 CIRCUIT NEAR - a share 5%+ on the day within 2% of its band (once a band); and it marks the
             shares near a band (3%) as "hot"
  refresh()  every 60 s: the hot shares' bands read again (one Kite call) -> 🧱 CIRCUIT BAND WIDENED when the exchange moves the band"""
import time

NEAR, HOT, DAYMIN, EVERY = 0.02, 0.03, 5.0, 60


def _inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def near(s, p, lo, hi, pc, G, hms=None):
    """-> a 🧱 CIRCUIT NEAR text or None; marks hot shares in G["hot"]"""
    hot = G.setdefault("hot", {})
    if (lo and p <= lo * (1 + HOT)) or (hi and p >= hi * (1 - HOT)):
        hot[s] = time.time()
    if not pc:
        return None
    day = (p / pc - 1) * 100
    side = -1 if (lo and lo * 1.002 < p <= lo * (1 + NEAR)) else 1 if (hi and hi * (1 - NEAR) <= p < hi * 0.998) else 0
    if not side or day * side < DAYMIN:
        return None
    band = lo if side < 0 else hi
    key = ("near", s, side, band)
    fired = G.setdefault("fired", set())
    if key in fired:
        return None
    fired.add(key)
    hms = hms or time.strftime("%H:%M:%S", time.gmtime(time.time() + 19800))
    return ("🧱 CIRCUIT NEAR %s %s ₹%s · day %+.1f%% · the %s band ₹%s is %.1f%% away · %s\n"
            "%s racing to the band: at the band it locks (only %s) - F&O bands widen by 5%% after a cooling-off, GIR rings 🧱 BAND WIDENED") % (
        "▼" if side < 0 else "▲", s, _inr(p), day, "lower" if side < 0 else "upper", _inr(band), abs(band / p - 1) * 100, hms,
        "sellers" if side < 0 else "buyers", "sellers" if side < 0 else "buyers")


def refresh(kite, G, getdata, now=None):
    """the hot shares' bands again, every 60 s -> [🧱 CIRCUIT BAND WIDENED texts]"""
    now = now or time.time()
    if now - G.get("t_hot", 0.0) < EVERY:
        return []
    G["t_hot"] = now
    hot = [s for s, t in (G.get("hot") or {}).items() if now - t < 1800]
    if not hot:
        return []
    try:
        q = getdata.call(kite.quote, [getdata.key(s) for s in hot])
    except Exception:
        return []
    out = []
    for k, v in (q or {}).items():
        s = getdata.unkey(k)
        lo, hi = float(v.get("lower_circuit_limit") or 0), float(v.get("upper_circuit_limit") or 0)
        old = (G.get("lim") or {}).get(s)
        lp = float(v.get("last_price") or 0)
        if not (lo and hi and old):
            continue
        if abs(lo - old[0]) > 0.01 or abs(hi - old[1]) > 0.01:
            G["lim"][s] = (lo, hi)
            pc = (G.get("pc") or {}).get(s)
            down = lp and abs(lp / old[0] - 1) < abs(lp / old[1] - 1)
            nb, ob = (lo, old[0]) if down else (hi, old[1])
            out.append("🧱 CIRCUIT BAND WIDENED %s %s ₹%s%s · the %s band ₹%s -> ₹%s%s · %s\n"
                       "room for %.1f%% more before the next lock - the second leg (PAGEIND 12 Nov: -10%% -> -13.2%% in 14 min)" % (
                           "▼" if down else "▲", s, _inr(lp), (" · day %+.1f%%" % ((lp / pc - 1) * 100)) if (pc and lp) else "", "lower" if down else "upper",
                           _inr(ob), _inr(nb), (" (%+.0f%%)" % ((nb / pc - 1) * 100)) if pc else "", time.strftime("%H:%M:%S", time.gmtime(now + 19800)),
                           abs(nb / lp - 1) * 100 if lp else 0))
    return out
PY_BW
cat > $W/p223_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p223_patch.py - PATCH 223: RESULTS-DAY WATCH (PAGEIND 12 Nov). resultreact.py + bandwatch.py next to this script.
  newshunt   🚨 RESULTS REACTION every 15 s (a P1: BUY PE / CE within a minute of the results)
  pbook      PROFIT BOOKING / SHORT COVERING on a share with results in the last 30 min only after a real turn (5 min with no new extreme)
  engine2    🧱 CIRCUIT NEAR (2% from the band, 5%+ on the day) · 🧱 CIRCUIT BAND WIDENED (the hot shares' bands every 60 s)
  p1vote     (when patch 225 is in) a results reaction shows the vote but is never turned down
Usage: python3 p223_patch.py DIR SRCDIR"""
import sys, os, shutil
D, SRC = sys.argv[1], sys.argv[2]
ERR = []
for f in ("resultreact.py", "bandwatch.py"):
    shutil.copy(os.path.join(SRC, f), os.path.join(D, f)); print("  %s: in" % f)


def rep(f, old, new, tag, need=True):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        if need:
            ERR.append("%s missing" % f)
        else:
            print("  %s: not here - skipped" % f)
        return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


A = '''        if q and live:                                          # patch 213: PROFIT BOOKING - the moment it starts'''
rep("newshunt.py", A, '''        if q and live:                                          # patch 223: RESULTS REACTION - a P1 within a minute of the results
            try:
                import resultreact
                msgs += resultreact.tick(now, q, day_mv, fo=fo_set())
            except Exception as ex:
                log("results reaction: %s" % str(ex)[:80])
''' + A, "🚨 RESULTS REACTION every 15 s")
rep("pbook.py", '''def tick(now, ltp, chg, fo=None, act=None):''', '''def results_recent(s, t):
    """patch 223: the share's results came out in the last 30 min"""
    try:
        import resultreact
        r = resultreact.results_today(dt.datetime.fromtimestamp(t, IST).strftime("%Y-%m-%d"), t).get(s)
        return bool(r and 0 <= t - r[0] <= 1800)
    except Exception:
        return False


def tick(now, ltp, chg, fo=None, act=None):''', "results_recent()")
rep("pbook.py", '''                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)''',
    '''                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)
            if t - st[tk] < 300 and results_recent(s, t):
                continue                                           # patch 223: results - a bounce right after a new extreme is not a turn (PAGEIND 14:33)''',
    "results: a real turn only")
rep("engine2.py", '''        side = "PE" if p <= lo * 1.002 else "CE" if p >= hi * 0.998 else None''', '''        try:                                                    # patch 223: 🧱 CIRCUIT NEAR + the shares whose band is re-read every 60 s
            import bandwatch
            nt_ = bandwatch.near(s, p, lo, hi, _GAPC["pc"].get(s), _GAPC)
            if nt_:
                tg_fo(nt_); out.append(nt_)
        except Exception:
            pass
        side = "PE" if p <= lo * 1.002 else "CE" if p >= hi * 0.998 else None''', "🧱 CIRCUIT NEAR")
rep("engine2.py", '''            elif "09:45:00" <= hms <= "15:25:00" and time.time() - _GAPC["t_lim"] >= 1200:
                gap_quotes(kite, syms)''', '''            elif "09:45:00" <= hms <= "15:25:00" and time.time() - _GAPC["t_lim"] >= 1200:
                gap_quotes(kite, syms)
            if "09:15:05" <= hms <= "15:28:00" and _GAPC.get("hot"):   # patch 223: 🧱 BAND WIDENED - the hot shares' bands every 60 s
                import bandwatch
                for t_ in bandwatch.refresh(kite, _GAPC, getdata):
                    tg_fo(t_)''', "🧱 CIRCUIT BAND WIDENED")
rep("p1vote.py", '''        marks = " · ".join("%s %s" % (k, "✓" if ok else "✗" if ok is False else "?") for k, ok, _ in res)''',
    '''        marks = " · ".join("%s %s" % (k, "✓" if ok else "✗" if ok is False else "?") for k, ok, _ in res)
        if "RESULTS REACTION" in h2:                            # patch 223: a results reaction is a P1 on its own proof - shown, never turned down
            L = text.split("\\n")
            return "\\n".join(L[:1] + ["⚖ VOTE %d/6 ✔ P1 (a results reaction - the filing, the price and the volume are its proof) · %s" % (yes, marks)] + L[1:])''',
    "a results reaction is never voted down", need=False)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 223 in")
PY_PATCH
cat > $W/p223test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p223test.py - RESULTS-DAY WATCH replayed on PAGEIND 12 Nov (filed 14:29:53, -2% at 14:30:30, the band -10% at 14:36:45, -13.2% at 14:50)
with made-up files (temp folder, nothing sent).  python3 p223test.py DIR SRCDIR   (DIR: alertword.py, pbook.py [, p1vote.py, exitwatch.py])"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
D, SRC = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "pbook.py", "p1vote.py", "exitwatch.py", "tglanes.py"):
    if os.path.exists(os.path.join(D, f)):
        shutil.copy(os.path.join(D, f), T)
for f in ("resultreact.py", "bandwatch.py"):
    shutil.copy(os.path.join(SRC, f), T)
open(os.path.join(T, "pushwho.py"), "w").write("def read(s):\n    return {'dir': 'UP', 'kind': 'NEW MONEY'}\n")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DAY = dt.datetime(2026, 11, 12, tzinfo=IST)
at = lambda h, m, s=0: DAY.replace(hour=h, minute=m, second=s)
PC = 36572.0
N = 75
def idx(h, m): return ((h * 60 + m) - 555) // 5
c = [36500.0] * N; v = [1000] * N
i30 = idx(14, 30)
for j in range(i30, N): c[j] = 33640.0; v[j] = 80000                  # from 14:30: the crash candles, 80x volume
ch = {"PAGEIND": {"o": list(c), "h": [x + 20 for x in c], "l": [x - 20 for x in c], "c": c, "v": v, "pc": PC},
      "KALYANKJIL": {"o": [650.0] * N, "h": [651.0] * N, "l": [649.0] * N, "c": [650.0] * N, "v": [1000] * N, "pc": 650.0},
      "XYZ": {"o": list(c), "h": [x + 20 for x in c], "l": [x - 20 for x in c], "c": list(c), "v": list(v), "pc": PC}}
json.dump(ch, open(os.path.join(T, "charts.json"), "w"))
db = sqlite3.connect(os.path.join(T, "filings.db"))
db.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
for k, s, te, ver in (("a", "PAGEIND", at(14, 29, 53), "IN LINE"), ("b", "KALYANKJIL", at(13, 0), "BEAT"), ("c", "HAL", at(12, 0), "MISS")):
    db.execute("insert into filings(key, sym, t_exch, t_seen, kind, verdict, subject) values (?, ?, ?, ?, 'RESULTS', ?, 'Outcome of Board Meeting')", (k, s, te.timestamp(), te.timestamp() + 30, ver))
db.commit(); db.close()
c2 = sqlite3.connect(os.path.join(T, "tomorrow.db")); c2.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)"); c2.commit(); c2.close()
sys.path.insert(0, T); os.chdir(T)
import resultreact as RR, bandwatch as BW, alertword as AW
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:500]))
FO = {"PAGEIND", "KALYANKJIL", "HAL", "XYZ"}
print("1 · 🚨 RESULTS REACTION")
m = RR.tick(at(14, 30, 10), {"PAGEIND": 36300.0}, {"PAGEIND": -0.7}, FO)
chk("14:30:10 PAGEIND -0.6% since the filing: nothing yet", m == [], m)
m = RR.tick(at(14, 30, 30), {"PAGEIND": 35825.0, "HAL": 4000.0}, {"PAGEIND": -2.0}, FO)
t = m[0] if m else ""
print("     " + t.replace("\n", "\n     "))
chk("14:30:30 -1.9% on 80x volume: 🚨 RESULTS REACTION ▼ PAGEIND - 37 s after the filing", len(m) == 1 and t.startswith("🚨 CRITICAL · RESULTS REACTION ▼ PAGEIND"), m)
chk("it says GIR's reader said IN LINE, the price says MISS", "reader said IN LINE, the price says MISS" in t, t)
chk("it is a P1 trade call: ▶ BUY PE + its stop (a close over the price before the results)", AW.tier(t) == "act" and "▶ BUY PE" in t and "stop: a close over ₹36,500" in t, AW.tier(t))
m = RR.tick(at(14, 31, 30), {"PAGEIND": 35000.0}, {"PAGEIND": -4.3}, FO)
chk("14:31:30 -4%: not said again", m == [], m)
m = RR.tick(at(13, 2), {"KALYANKJIL": 667.0}, {"KALYANKJIL": 2.6}, FO)
chk("KALYANKJIL BEAT, +2.6% in 2 min: ▲ BUY CE, no 'reader said' note (it agrees)", m and "RESULTS REACTION ▲ KALYANKJIL" in m[0] and "BUY CE" in m[0] and "reader said" not in m[0], m)
m = RR.tick(at(12, 45), {"HAL": 3800.0}, {"HAL": -5.0}, FO)
chk("HAL: results 45 min ago - outside the 20 min window: nothing", m == [], m)
m = RR.tick(at(14, 31, 45), {"PAGEIND": 35000.0}, {}, {"KALYANKJIL"})
chk("not on the F&O list: nothing", m == [], m)
if os.path.exists("p1vote.py"):
    import p1vote as PV
    vt = PV.vote(t, at(14, 30, 31))
    chk("THE VOTE shows its checks but never turns a results reaction down (✔ P1)", "⚖ VOTE" in vt and "✔ P1 (a results reaction" in vt and AW.tier(vt) == "act", vt.split("\n")[1] if "\n" in vt else vt)
if os.path.exists("exitwatch.py"):
    import exitwatch as XW
    chk("the exit watch can follow it (it reads the stop ₹36,500)", XW.parse(t)["stop"] == (1, 36500.0), XW.parse(t))
print("2 · PROFIT BOOKING / SHORT COVERING on a results share - a real turn only")
import pbook as PB
flat = {"o": [36500.0] * 60, "h": [36520.0] * 60, "l": [36480.0] * 60, "c": [36500.0] * 60, "v": [1000] * 59 + [80000], "pc": PC}   # the day so far, the last candle 80x
json.dump({"PAGEIND": flat, "XYZ": flat}, open("charts.json", "w"))
def run(sym, seq):
    PB.ST.update({"day": None, "s": {}}); PB._F.clear(); out = []
    for (h, mi, se), px in seq:
        out += PB.tick(at(h, mi, se), {sym: px}, {sym: (px / PC - 1) * 100}, fo=FO, act=set())
    return out
crash = [((14, 31, 0), 35480.0), ((14, 32, 0), 34745.0), ((14, 33, 28), 34340.0), ((14, 33, 47), 34530.0)]
ctl = run("XYZ", crash)
chk("a share WITHOUT results, the same bounce at 14:33:47: SHORT COVERING rings (as before)", any("SHORT COVERING" in x for x in ctl), ctl)
pg = run("PAGEIND", crash)
chk("PAGEIND (results 4 min ago): the 14:33:47 tick bounce does NOT ring SHORT COVERING (it fell to -13% after)", not any("SHORT COVERING" in x for x in pg), pg)
pg2 = run("PAGEIND", crash + [((14, 39, 0), 32915.0), ((14, 44, 40), 33230.0)])
chk("PAGEIND: a bounce 5+ min after the last low (a real turn): SHORT COVERING rings", any("SHORT COVERING" in x for x in pg2), pg2)
print("3 · 🧱 THE BAND")
G = {"lim": {"PAGEIND": (32915.0, 40229.0)}, "pc": {"PAGEIND": PC}, "fired": set()}
chk("-6% (the band 4% away): no NEAR yet", BW.near("PAGEIND", 34380.0, 32915.0, 40229.0, PC, G, "14:31:10") is None)
n1 = BW.near("PAGEIND", 33500.0, 32915.0, 40229.0, PC, G, "14:34:30")
chk("-8.4%, the lower band 1.7% away: 🧱 CIRCUIT NEAR ▼ PAGEIND (rings: it says CIRCUIT)", n1 and n1.startswith("🧱 CIRCUIT NEAR ▼ PAGEIND") and AW.tier(n1) == "move", n1)
chk("said once a band", BW.near("PAGEIND", 33400.0, 32915.0, 40229.0, PC, G, "14:35:00") is None)
chk("PAGEIND is now 'hot' (its band re-read every 60 s)", "PAGEIND" in G.get("hot", {}))
class K:
    def quote(self, keys): return {"NSE:PAGEIND": {"lower_circuit_limit": 31086.2, "upper_circuit_limit": 42058.0, "last_price": 32300.0}}
class GD:
    call = staticmethod(lambda f, a: f(a)); key = staticmethod(lambda s: "NSE:" + s); unkey = staticmethod(lambda k: k.split(":", 1)[1])
w = BW.refresh(K(), G, GD, now=1e9)
chk("the exchange widens the band: 🧱 CIRCUIT BAND WIDENED ▼ PAGEIND ₹32,915 -> ₹31,086 (-15%)", w and "BAND WIDENED ▼ PAGEIND" in w[0] and "₹32,915 -> ₹31,086" in w[0] and AW.tier(w[0]) == "move", w)
chk("read again within 60 s: nothing (one Kite call a minute)", BW.refresh(K(), G, GD, now=1e9 + 30) == [])
print("RESULTS-DAY WATCH test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p223_patch.py $D $W/src || back
cd $D && python3 -m py_compile resultreact.py bandwatch.py newshunt.py pbook.py engine2.py || back
echo "=== test: PAGEIND 12 Nov replayed (this server's alertword, pbook, vote, exit watch)"
python3 $W/p223test.py $D $W/src || back
echo "=== TODAY's results filings on this server's 5-min candles: when 🚨 RESULTS REACTION would have rung (by candle close - live it reads every 15 s, so sooner)"
cd $D && python3 - "$(TZ=Asia/Kolkata date +%F)" <<'PY'
import sys, json, sqlite3, datetime as dt
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
day = sys.argv[1]; d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST).timestamp()
try:
    fo = set(json.load(open("dash_state.json")).get("fo_paths") and [f["s"] for f in json.load(open("dash_state.json"))["fo_paths"] if f.get("s")])
except Exception:
    fo = set()
ch = json.load(open("charts.json"))
c = sqlite3.connect("file:filings.db?mode=ro", uri=True)
seen = set()
for s, te, ver in c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>=? order by t_exch", (d0,)):
    if s in seen or (fo and s not in fo):
        continue
    seen.add(s)
    x = ch.get(s) or {}
    C, V, pc = x.get("c") or [], x.get("v") or [], x.get("pc")
    tm = dt.datetime.fromtimestamp(te, IST)
    if not ("09:15" <= tm.strftime("%H:%M") <= "15:25") or not C:
        print("   %-11s filed %s · %s · outside market hours" % (s, tm.strftime("%H:%M"), ver or "")); continue
    i = ((tm.hour * 60 + tm.minute) - 555) // 5
    p0 = C[i - 1] if i >= 1 and C[i - 1] else C[i]
    vs = sorted(v for v in V[:i] if v); med = vs[len(vs) // 2] if vs else 0
    hit = None
    for j in range(i, min(len(C), i + 5)):
        if not C[j]:
            continue
        mv = (C[j] / p0 - 1) * 100; vx = (V[j] / med) if med and V[j] else 0
        if abs(mv) >= 2.5 or (abs(mv) >= 1.5 and vx >= 5):
            hit = (j, mv, vx); break
    endp = next((y for y in reversed(C) if y), None)
    if hit:
        j, mv, vx = hit
        e = 555 + 5 * (j + 1)
        print("   %-11s filed %s · GIR's reader: %-10s · RINGS by %02d:%02d %s %+.1f%% (volume %.0fx) · close %+.1f%% vs before the results" % (
            s, tm.strftime("%H:%M:%S"), (ver or "-")[:10], e // 60, e % 60, "▼ BUY PE" if mv < 0 else "▲ BUY CE", mv, vx, (endp / p0 - 1) * 100 if endp else 0))
    else:
        print("   %-11s filed %s · GIR's reader: %-10s · no reaction big enough in 25 min (quiet - right)" % (s, tm.strftime("%H:%M:%S"), (ver or "-")[:10]))
print("   (%d F&O results filings today)" % len(seen))
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 223 done - from tomorrow: 🚨 RESULTS REACTION (ambulance) within ~a minute of a results filing that moves the share; 🧱 NEAR / BAND WIDENED."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/resultreact.py $D/bandwatch.py; systemctl restart $SV"
