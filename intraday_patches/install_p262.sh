#!/bin/bash
# PATCH 262 - THE RESULTS WEEK, 09:15 TO THE CLOSE (Rama, 14 Nov: "monitor the quarterly results shares for at least one week - they may react
#   days later; from 09:15, the full trading day - they can swing violently"). Every F&O share in its first 7 sessions from the results:
#     OPEN   09:20-11:00 the gap held past the first 5-min candle, or faded through yesterday's close (day 1: 1.5%+ · days 2-7: 2%+)
#     SWING  09:30-15:15 3%+ on the day, a new day high (low), volume 2x+ -> 🚨 RESULTS REACTION · DAY N SWING ▲ BUY CE / ▼ BUY PE, stop VWAP
#   ⚡ SPEED now rings on results shares (rule 4 had muted it) · the special force (EVENT WATCH) 09:15-15:29 and 10 days after the results.
#   Tested: 22 cases. Then the rules replayed on this server's last 40 days of results (read only).
#   Restarts the senders - after 15:35 on a trading day (or add: now); on a weekend any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 261" $D/resultreact.py || { echo "patch 261 first (install_p261.sh)"; exit 1; }
F="resultreact.py ringgov.py eventwatch.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p262_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p262_patch.py - patch 262: THE RESULTS WEEK, 09:15 TO THE CLOSE (Rama, 14 Nov: "monitor the quarterly results shares for at least one week -
they may react days later; from 09:15, the full trading day - they can swing violently").
  resultreact.py  every F&O share in its results week (the first 7 sessions from the results):
     OPEN   09:20-11:00: the gap held past the first 5-min candle, or faded through yesterday's close (day 1: 1.5%+ gap · days 2-7: 2%+)
     SWING  09:30-15:15: 3%+ on the day, a new day high (low), volume 2x+ normal -> 🚨 RESULTS REACTION · DAY N ▲ BUY CE / ▼ BUY PE,
            stop: today's VWAP. Once a side a day; the other side later rings too (a reversal).
  ringgov.py      rule 4 (a results share: only P1 / results / EVENT WATCH ring) let ⚡ SPEED through - the best-measured alert was muted on
                  exactly the shares that swing most
  eventwatch.py   the special force from 09:15 (was 09:20) to 15:29 · after the results: 10 calendar days (= 7 sessions, was 7 days)
python3 p262_patch.py DIR"""
import os, sys
D = sys.argv[1]
def rd(f):
    return open(os.path.join(D, f), encoding="utf-8").read()
def wr(f, s):
    open(os.path.join(D, f), "w", encoding="utf-8").write(s)

# ---------- resultreact.py ----------
s = rd("resultreact.py")
if "patch 262" in s:
    print("  resultreact.py: patch 262 - already in")
else:
    if "patch 261" not in s:
        print("❌ resultreact.py: patch 261 first"); sys.exit(1)
    a, b = s.find("def gap_tick("), s.find("def _p_before(sym, te):")
    if a < 0 or b < a:
        print("❌ resultreact.py: gap_tick not found"); sys.exit(1)
    NEW = r'''WEEK, GAP_MIN2, SWING_MIN, SWING_VOL, SWING_FROM, SWING_TO = 7, 2.0, 3.0, 2.0, "09:30", "15:15"   # patch 262: the results week


def _sessions(today, n=12):
    """patch 262: today and the trading days before it, newest first"""
    out, d = [today], today
    for _ in range(n):
        ST.pop("ls", None)
        d = _last_session(d)
        out.append(d)
    return out


def results_week(day, now_t):
    """patch 262: {sym: (filed epoch, verdict, session n)} - F&O results in their first 7 sessions (n = 1 the first session that could react)"""
    c_ = ST.get("rw")
    if c_ and c_[0] == day and now_t - c_[1] < 60:
        return c_[2]
    today = dt.date.fromisoformat(day)
    S = _sessions(today)
    SS = set(S)
    t0 = dt.datetime.combine(S[-1], dt.time(0), IST).timestamp()
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "filings.db"), uri=True, timeout=3)
        rows = c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>=? and t_exch<=? order by t_exch", (t0, now_t)).fetchall()
        c.close()
    except Exception:
        rows = []
    for s, te, ver in rows:
        if not s:
            continue
        tm = dt.datetime.fromtimestamp(float(te), IST)
        fd, hm = tm.date(), tm.strftime("%H:%M")
        first = fd if (fd in SS and hm < "15:30") else min([x for x in S if x > fd] or [today])
        n = sum(1 for x in S if first <= x <= today)
        if 1 <= n <= WEEK:
            out[s] = (float(te), ver or "", n)                        # the latest filing wins
    ST["rw"] = (day, now_t, out)
    return out


def _filed_words(te, n):
    w = dt.datetime.fromtimestamp(te, IST).strftime("%a %H:%M")
    return "results filed %s (after the close)" % w if n == 1 else "results filed %s · day %d of the results week" % (w, n)


def _verdict(d, ver):
    read = "MISS" if d < 0 else "BEAT"
    vd = (ver or "").upper()
    said = ""
    if vd and ((d < 0 and re.search(r"BEAT|IN LINE|INLINE", vd)) or (d > 0 and re.search(r"MISS|IN LINE|INLINE", vd))):
        said = " - GIR's reader said %s, the price says %s: the price is the verdict" % (vd[:24], read)
    return read, said


def gap_tick(now, ltp, chg=None, fo=None):
    """patch 261 + 262: 09:20-11:00 - a results-week share that HELD its gap past the first 5-min candle, or FADED it through yesterday's close"""
    hm = now.strftime("%H:%M")
    if not (GAP_FROM <= hm <= GAP_TO):
        return []
    out = []
    open_t = dt.datetime.combine(now.date(), dt.time(9, 15), IST).timestamp()
    for s, (te, ver, n) in results_week(str(now.date()), now.timestamp()).items():
        if te >= open_t or (fo and s not in fo) or (s, "gap") in ST["said"] or (s, 1) in ST["said"] or (s, -1) in ST["said"]:
            continue
        px, c = ltp.get(s), _charts().get(s) or {}
        pc, O, Hh, L = c.get("pc"), c.get("o") or [], c.get("h") or [], c.get("l") or []
        if not (px and pc and O and O[0] and Hh and Hh[0] and L and L[0]):
            continue
        gm, fm = (GAP_MIN, FADE_MIN) if n == 1 else (GAP_MIN2, max(FADE_MIN, GAP_MIN2))
        gap, mv = (O[0] / pc - 1) * 100, (px / pc - 1) * 100
        d = kind = 0
        if gap >= gm and px > Hh[0] and mv >= gm:
            d, kind = 1, "held"
        elif gap <= -gm and px < L[0] and mv <= -gm:
            d, kind = -1, "held"
        elif gap >= fm and mv <= -0.5:
            d, kind = -1, "faded"
        elif gap <= -fm and mv >= 0.5:
            d, kind = 1, "faded"
        if not d:
            continue
        ST["said"].add((s, "gap")); ST["said"].add((s, "sw", d))
        read, said = _verdict(d, ver)
        side = "PE" if d < 0 else "CE"
        if kind == "held":
            stop = L[0] if d > 0 else Hh[0]
            how = "opened %+.1f%% (₹%s -> ₹%s) · held the first 5 min and broke its %s ₹%s · now %+.1f%%" % (
                gap, _inr(pc), _inr(O[0]), "high" if d > 0 else "low", _inr(Hh[0] if d > 0 else L[0]), mv)
            why = "the market reads it as a %s%s" % (read, said)
            sw = "the first 5-min %s" % ("low" if d > 0 else "high")
        else:
            stop = (L[0] if L[0] > px else pc) if d < 0 else (Hh[0] if Hh[0] < px else pc)
            how = "opened %+.1f%% (₹%s -> ₹%s) but the gap is gone: now ₹%s, %+.1f%% from yesterday's close" % (gap, _inr(pc), _inr(O[0]), _inr(px), mv)
            why = "the market %s the %s open - it reads the results as a %s%s" % ("sold" if d < 0 else "bought", "good" if d < 0 else "bad", read, said)
            sw = "the first 5-min %s" % ("low" if d < 0 else "high") if stop != pc else "yesterday's close"
        out.append("\n".join([
            "🚨 CRITICAL · RESULTS REACTION %s %s · %s" % ("▼" if d < 0 else "▲", s, hm),
            "%s · %s" % (_filed_words(te, n), how),
            why,
            "▶ BUY %s (at the money) - %s · stop: a close %s ₹%s (%s)" % (side, "▼ DOWN → PE" if d < 0 else "▲ UP → CE", "over" if d < 0 else "under", _inr(stop), sw),
            "results gaps can run all day, but a big gap can also snap back: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    return out


def _last(x):
    if isinstance(x, (list, tuple)):
        for v in reversed(x):
            if v:
                return v
        return None
    return x or None


def swing_tick(now, ltp, chg=None, fo=None):
    """patch 262: 09:30-15:15 - a results-week share 3%+ on the day at a new day high (low) on 2x+ volume: the delayed reaction, a trade call"""
    hm = now.strftime("%H:%M")
    if not (SWING_FROM <= hm <= SWING_TO):
        return []
    out, t = [], now.timestamp()
    k = ((now.hour * 60 + now.minute) - 555) // 5                    # the 5-min candle now forming
    for s, (te, ver, n) in results_week(str(now.date()), t).items():
        if (fo and s not in fo) or t - te < WINDOW:                      # the first 20 min after a filing are the results reaction's
            continue
        px, c = ltp.get(s), _charts().get(s) or {}
        pc, Hh, L, V = c.get("pc"), c.get("h") or [], c.get("l") or [], c.get("v") or []
        done = [i for i in range(min(k, len(Hh), len(L))) if Hh[i] and L[i]]
        if not (px and pc) or len(done) < 3:
            continue
        mv = (px / pc - 1) * 100
        d = 1 if (mv >= SWING_MIN and px > max(Hh[i] for i in done)) else (-1 if (mv <= -SWING_MIN and px < min(L[i] for i in done)) else 0)
        if not d or (s, "sw", d) in ST["said"] or (s, d) in ST["said"]:
            continue
        base = sorted(V[i] for i in range(min(k - 1, len(V))) if V[i])
        rec = max([V[i] for i in (k - 1, k) if 0 <= i < len(V) and V[i]] or [0])
        vx = rec / base[len(base) // 2] if len(base) >= 3 else None
        if not vx or vx < SWING_VOL:
            continue
        ST["said"].add((s, "sw", d))
        read, said = _verdict(d, ver)
        side = "PE" if d < 0 else "CE"
        vw = _last(c.get("vw"))
        if vw and ((d > 0 and vw < px) or (d < 0 and vw > px)):
            stop, sw = vw, "today's VWAP"
        else:
            stop, sw = (min(L[i] for i in done) if d > 0 else max(Hh[i] for i in done)), "today's %s" % ("low" if d > 0 else "high")
        filed = dt.datetime.fromtimestamp(te, IST).strftime("%a %H:%M")
        out.append("\n".join([
            "🚨 CRITICAL · RESULTS REACTION %s %s · %s · DAY %d SWING" % ("▼" if d < 0 else "▲", s, hm, n),
            "results filed %s · day %d of the results week · today %+.1f%% (₹%s -> ₹%s) · a new day %s on %.1fx volume" % (
                filed, n, mv, _inr(pc), _inr(px), "high" if d > 0 else "low", vx),
            "the delayed reaction - the market is still pricing the results: it reads them as a %s%s" % (read, said),
            "▶ BUY %s (at the money) - %s · stop: a close %s ₹%s (%s)" % (side, "▼ DOWN → PE" if d < 0 else "▲ UP → CE", "over" if d < 0 else "under", _inr(stop), sw),
            "results-week swings can be violent both ways: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    return out


'''
    s = s[:a] + NEW + s[b:]
    old = "    out += gap_tick(now, ltp, chg, fo)                          # patch 261: results filed overnight - at the open"
    if s.count(old) != 1:
        print("❌ resultreact.py: the 261 call not found"); sys.exit(1)
    s = s.replace(old, "    out += gap_tick(now, ltp, chg, fo) + swing_tick(now, ltp, chg, fo)   # patch 261 + 262: the open, then the results week all day")
    wr("resultreact.py", s)
    print("  resultreact.py: the results week - the open (days 1-7) and the SWING all day")

# ---------- ringgov.py ----------
s = rd("ringgov.py")
old = '''        if sym and not protect and not RES249.search(h) and "EVENT WATCH" not in h:   # rule 4'''
if "patch 262" in s:
    print("  ringgov.py: patch 262 - already in")
elif s.count(old) == 1:
    wr("ringgov.py", s.replace(old, '''        if sym and not protect and not RES249.search(h) and "EVENT WATCH" not in h and not re.search(r"\\bSPEED\\b", h):   # rule 4 (patch 262: ⚡ SPEED rings on results shares)'''))
    print("  ringgov.py: ⚡ SPEED rings on results-week shares too")
else:
    print("❌ ringgov.py: rule 4 not found"); sys.exit(1)

# ---------- eventwatch.py ----------
s = rd("eventwatch.py")
if "patch 262" in s:
    print("  eventwatch.py: patch 262 - already in")
else:
    E = [("WINDOW, CR_MIN, LATE_TOTAL, LATE_TODAY = 7, 25.0, 3.0, 1.5",
          "WINDOW, CR_MIN, LATE_TOTAL, LATE_TODAY = 7, 25.0, 3.0, 1.5\nAFTER = 10                                                      # patch 262: after the results 10 days (7 sessions)"),
         ("    d0, d1 = now.date() - dt.timedelta(days=WINDOW), now.date() + dt.timedelta(days=WINDOW)",
          "    d0, d1 = now.date() - dt.timedelta(days=AFTER), now.date() + dt.timedelta(days=WINDOW)"),
         ('    if now.weekday() > 4 or not ("09:20" <= hm <= "15:25"):',
          '    if now.weekday() > 4 or not ("09:15" <= hm <= "15:29"):        # patch 262: from the first minute to the close')]
    for o_, n_ in E:
        if s.count(o_) != 1:
            print("❌ eventwatch.py: anchor not found: %s" % o_[:60]); sys.exit(1)
        s = s.replace(o_, n_)
    wr("eventwatch.py", s)
    print("  eventwatch.py: the special force 09:15-15:29 · 10 days after the results")
print("patch 262 in")
PY_PATCH
cat > $W/p262test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p262test.py - the results week, 09:15 to the close (made-up filings and candles, temp copies, nothing sent).  python3 p262test.py DIR"""
import os, sys, json, types, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("resultreact.py", "alertword.py", "tglanes.py", "ringgov.py", "exitwatch.py", "p1vote.py", "eventwatch.py", "eventbrain.py"):
    if os.path.exists(os.path.join(SRC, f)):
        shutil.copy(os.path.join(SRC, f), T)
json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
sys.modules["holidays"] = types.SimpleNamespace(holiday=lambda d: "weekend" if d.weekday() >= 5 else ("Guru Nanak" if str(d) == "2026-11-24" else None))
at = lambda y, m, d, h, mi: dt.datetime(y, m, d, h, mi, tzinfo=IST)
mon = lambda h, m: at(2026, 11, 16, h, m)
c = sqlite3.connect("filings.db")
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
F = [("ABC", at(2026, 11, 11, 18, 0), "BEAT"), ("OLD", at(2026, 11, 4, 18, 0), "BEAT"), ("TOD", at(2026, 11, 16, 11, 0), "MISS"),
     ("GD3", at(2026, 11, 11, 19, 0), "BEAT"), ("SM3", at(2026, 11, 11, 19, 30), "BEAT"), ("OVN", at(2026, 11, 13, 18, 0), "BEAT"),
     ("LOV", at(2026, 11, 12, 18, 0), "BEAT"), ("NOH", at(2026, 11, 12, 18, 0), "BEAT"), ("REV", at(2026, 11, 10, 18, 0), "IN LINE")]
for i, (s, t, v) in enumerate(F):
    c.execute("insert into filings(key, sym, t_exch, kind, verdict) values(?,?,?,?,?)", ("k%d" % i, s, int(t.timestamp()), "RESULTS", v))
c.commit(); c.close()
def day(pc, path, vol=1000, spike=None, vw=None):
    o = [p for p in path]; h = [p * 1.003 for p in path]; l = [p * 0.997 for p in path]; v = [vol] * len(path)
    if spike:
        for i in spike:
            v[i] = vol * 3.2
    return {"pc": pc, "o": o, "h": h, "l": l, "c": path, "v": v, "vw": vw or [sum(path) / len(path)] * len(path)}
flat = lambda p, n: [p] * n
CH = {"ABC": day(100, flat(101, 70), spike=[52, 62]),          # 13:40 = candle 53 forming; 52 the last done
      "OLD": day(100, flat(101, 53), spike=[52]), "TOD": day(100, flat(99, 53), spike=[52]),
      "GD3": {"pc": 100, "o": [101.7], "h": [102.0], "l": [101.3], "c": [101.8], "v": [1000]},
      "SM3": {"pc": 100, "o": [102.5], "h": [102.8], "l": [102.2], "c": [102.6], "v": [1000]},
      "OVN": {"pc": 100, "o": [101.6], "h": [101.9], "l": [101.2], "c": [101.7], "v": [1000]},
      "LOV": day(100, flat(101, 53)), "NOH": day(100, flat(101, 40) + flat(104, 13), spike=[52]),
      "REV": day(100, flat(101, 53), spike=[52])}
json.dump(CH, open("charts.json", "w"))
import resultreact as RR
FO = {s for s, _, _ in F}
OK = []
def chk(n, cnd, got=""):
    OK.append(bool(cnd)); print("  %s %s%s" % ("✅" if cnd else "❌", n, "" if cnd else "   got: %s" % str(got)[:300]))
tick = lambda t, q: RR.tick(t, q, {}, fo=FO)
W = RR.results_week("2026-11-16", mon(13, 40).timestamp())
chk("the results week: ABC (Wed evening) day 3 · OVN (Fri evening) day 1 · TOD (today 11:00) day 1 · OLD (8 sessions back) out",
    W.get("ABC", (0, 0, 0))[2] == 3 and W.get("OVN", (0, 0, 0))[2] == 1 and W.get("TOD", (0, 0, 0))[2] == 1 and "OLD" not in W, {k: v[2] for k, v in W.items()})
# THE OPEN, days 1-7
r = tick(mon(9, 22), {"GD3": 102.3, "SM3": 103.0, "OVN": 102.2})
txt = "\n".join(r)
chk("day 1 OVN +1.6% gap held: rings (as patch 261)", "RESULTS REACTION ▲ OVN" in txt and "(after the close)" in txt, r)
chk("day 3 GD3 only +1.7% gap: nothing (days 2-7 need 2%+)", "GD3" not in txt, r)
chk("day 3 SM3 +2.5% gap held: rings - 'day 3 of the results week'", "RESULTS REACTION ▲ SM3" in txt and "day 3 of the results week" in txt, r)
# THE SWING, all day
r = tick(mon(13, 40), {"ABC": 102.6})
chk("13:40 ABC day 3 +2.6%: under 3%, nothing", r == [], r)
r = tick(mon(13, 41), {"ABC": 103.4})
x = r[0] if r else ""
chk("13:41 ABC day 3 +3.4%, a new day high on 3.2x volume: 🚨 RESULTS REACTION · DAY 3 SWING ▲ BUY CE", len(r) == 1 and
    x.startswith("🚨 CRITICAL · RESULTS REACTION ▲ ABC · 13:41 · DAY 3 SWING") and "BUY CE" in x and "day 3 of the results week" in x and "3.2x volume" in x, r)
chk("... stop: a close under today's VWAP ₹101.0", "stop: a close under ₹101.0 (today's VWAP)" in x, x)
print("\n" + x + "\n")
chk("13:50 ABC higher still: once a side a day", tick(mon(13, 50), {"ABC": 104.5}) == [])
r = tick(mon(14, 30), {"ABC": 96.5})
chk("14:30 ABC turns -3.5%, a new day low: the other side rings (a reversal) ▼ BUY PE", len(r) == 1 and "RESULTS REACTION ▼ ABC" in r[0] and "BUY PE" in r[0], r)
chk("OLD (results 8 sessions back) +3.4% new high: outside the week, nothing", tick(mon(13, 42), {"OLD": 103.4}) == [])
chk("LOV +3.4% new high but normal volume: nothing", tick(mon(13, 42), {"LOV": 103.4}) == [])
chk("NOH +4.2% but under its earlier day high ₹104.3: nothing", tick(mon(13, 42), {"NOH": 104.2}) == [])
r = tick(mon(11, 10), {"TOD": 96.0})
chk("TOD filed today 11:00 - at 11:10 the results reaction's own call (▼ PE), not a SWING", len(r) == 1 and "RESULTS REACTION ▼ TOD" in r[0] and "SWING" not in r[0], r)
chk("TOD at 13:43 still down: the same side is not called twice", tick(mon(13, 43), {"TOD": 95.5}) == [])
r = tick(mon(13, 44), {"REV": 103.5})
chk("REV (reader said IN LINE, day 4 - 10 Nov evening) +3.5%: rings + 'the price is the verdict'", len(r) == 1 and "DAY 4 SWING" in r[0] and "the price is the verdict" in r[0], r)
chk("15:20: past the SWING window, nothing", tick(mon(15, 20), {"LOV": 110.0}) == [])
# the ring rules and the levels
import alertword as A, tglanes as L
ref = "🚨 CRITICAL · RESULTS REACTION ▼ PAGEIND · 14:30\nresults filed 14:29:53\n▶ BUY PE (at the money) - ▼ DOWN → PE · stop: a close over ₹36,500 (where it was before the results)"
chk("the SWING has the RESULTS REACTION level (%s) and lane" % A.tier(ref), A.tier(x) == A.tier(ref) and L.lane(x) == L.lane(ref), (A.tier(x), L.lane(x)))
if os.path.exists("exitwatch.py"):
    import exitwatch as XW
    st = (XW.parse(x) or {}).get("stop")
    chk("the exit watch reads the SWING's stop (₹101.0)", st and abs(st[1] - 101.0) < 0.01, XW.parse(x))
open("eventwatch.py.real", "w").write(open("eventwatch.py").read())
open("eventwatch.py", "w").write("def watch_list(now=None):\n    return {'ABC': {'agent': 'RESULTS', 'date': '2026-11-11'}}\n")
sys.modules.pop("eventwatch", None)
import ringgov as G
SP = "⚡ SPEED ▲ ABC ₹103.4 +1.3% in 5 min · day +3.4% · 13:41:10"
o, sl = G.gate(SP, A.tier(SP), now=mon(13, 41), px=103.4, candles={})
chk("⚡ SPEED on a results-week share rings now (rule 4 muted it)", sl is False, o)
SU = "🚨 SUDDEN ▲ ABC ₹103.6 · 13:55"
o, sl = G.gate(SU, A.tier(SU), now=mon(13, 55), px=103.6, candles={})
chk("... other generic alerts on it stay quiet (the special force speaks)", sl is True, o)
open("eventwatch.py", "w").write(open("eventwatch.py.real").read()); sys.modules.pop("eventwatch", None)
src = open("eventwatch.py").read()
chk("the special force watches from 09:15 to 15:29", '"09:15" <= hm <= "15:29"' in src)
try:
    import eventwatch as E
    c = sqlite3.connect("chains.db"); c.execute("create table if not exists results_cal(sym text, d text)"); c.commit(); c.close()
    Lr = E.results_list(at(2026, 11, 20, 10, 0), {"ABC", "OLD", "REV"})
    chk("... and keeps a results share 10 days after (ABC 11 Nov on 20 Nov: kept · OLD 4 Nov: out)", "ABC" in Lr and "OLD" not in Lr, Lr)
except Exception as ex:
    chk("eventwatch loads", False, ex)
print("THE RESULTS WEEK test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/study.py <<'PY_STUDY'
import os, sys, sqlite3, datetime as dt
import numpy as np
D = sys.argv[1]; DAYS = int(sys.argv[2]) if len(sys.argv) > 2 else 40
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
os.chdir(D)
fo = None
try:
    c = sqlite3.connect("file:chains.db?mode=ro", uri=True, timeout=5); fo = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
except Exception:
    pass
c = sqlite3.connect("file:filings.db?mode=ro", uri=True, timeout=5)
now = dt.datetime.now(IST).timestamp()
rows = [(s, float(te), v or "") for s, te, v in c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>? order by t_exch", (now - DAYS * 86400,)) if s and (not fo or s in fo)]
c.close()
H = {}
def bars(sym):
    if sym not in H:
        H[sym] = None
        for p in ("data/%s.npz" % sym, "data/h3/%s.npz" % sym, "data/h3/5min/%s.npz" % sym):
            try:
                z = np.load(p); H[sym] = {k: np.asarray(z[k], dtype=float) for k in ("ts", "o", "h", "l", "c", "v")}; break
            except Exception:
                continue
    return H[sym]
hm = lambda k: "%02d:%02d" % divmod(9 * 60 + 15 + 5 * k, 60)
out, seen = [], set()
for s, te, ver in reversed(rows):                                   # the latest filing wins a day
    B = bars(s)
    if B is None or not len(B["ts"]):
        continue
    day = ((B["ts"] + 19800) // 86400).astype(int)
    days = sorted(set(day.tolist()))
    tm = dt.datetime.fromtimestamp(te, IST); tday = int((te + 19800) // 86400)
    first = tday if (tday in days and tm.strftime("%H:%M") < "15:30") else next((d for d in days if d > tday), None)
    if first is None:
        continue
    week = [d for d in days if d >= first][:7]
    for n, nd in enumerate(week, 1):
        if (s, nd) in seen:
            continue
        seen.add((s, nd))
        prev = np.nonzero(day < nd)[0]; idx = np.nonzero(day == nd)[0]
        if not len(prev) or len(idx) < 14:
            continue
        pc = B["c"][prev[-1]]
        O, Hh, L, C, V = B["o"][idx], B["h"][idx], B["l"][idx], B["c"][idx], np.nan_to_num(B["v"][idx])
        k0 = 0
        if nd == tday:                                       # filed in market hours that day: start 20 min after
            k0 = max(0, ((tm.hour * 60 + tm.minute) - 555) // 5 + 4)
        sig = []
        if nd != tday or tm.strftime("%H:%M") < "09:15":     # the open check
            gm, fm = (1.5, 2.0) if n == 1 else (2.0, 2.0)
            gap = (O[0] / pc - 1) * 100
            for k in range(1, min(len(idx), 21)):
                if gap >= gm and Hh[k] > Hh[0] and (max(Hh[k], Hh[0]) / pc - 1) * 100 >= gm:
                    sig.append(("OPEN", k, 1, max(Hh[0], O[k]))); break
                if gap <= -gm and L[k] < L[0] and (min(L[k], L[0]) / pc - 1) * 100 <= -gm:
                    sig.append(("OPEN", k, -1, min(L[0], O[k]))); break
                if gap >= fm and L[k] <= pc * 0.995:
                    sig.append(("OPEN", k, -1, min(pc * 0.995, O[k]))); break
                if gap <= -fm and Hh[k] >= pc * 1.005:
                    sig.append(("OPEN", k, 1, max(pc * 1.005, O[k]))); break
        said = {x[2] for x in sig}
        for k in range(max(3, k0, 3), min(len(idx), 73)):     # 09:30 .. 15:15
            if k < 3:
                continue
            base = sorted(x for x in V[:k - 1] if x)
            if len(base) < 3:
                continue
            vx = max(V[k - 1], V[k]) / base[len(base) // 2] if base[len(base) // 2] else 0
            for d in (1, -1):
                if d in said:
                    continue
                lvl = pc * (1 + 0.03 * d)
                ext = np.nanmax(Hh[:k]) if d > 0 else np.nanmin(L[:k])
                hit = (Hh[k] > max(ext, lvl)) if d > 0 else (L[k] < min(ext, lvl))
                if hit and vx >= 2.0:
                    e = max(ext, lvl, O[k]) if d > 0 else min(ext, lvl, O[k])
                    sig.append(("SWING", k, d, e)); said.add(d)
        for kind, k, d, e in sig:
            r60 = (C[min(len(C) - 1, k + 12)] / e - 1) * 100 * d
            rcl = (C[-1] / e - 1) * 100 * d
            out.append((dt.datetime.fromtimestamp(nd * 86400 - 19800 + 33300, IST).strftime("%d %b"), s, n, kind, hm(k), d, r60, rcl, ver[:10], nd))
print("   %-7s %-11s %4s %-6s %-6s %-5s %7s %7s  %s" % ("day", "share", "day#", "kind", "time", "side", "60 min", "close", "reader"))
out.sort(key=lambda x: (x[9], x[4]))
for x in out[-40:]:
    print("   %-7s %-11s %4d %-6s %-6s %-5s %+6.1f%% %+6.1f%%  %s" % (x[0], x[1], x[2], x[3], x[4], "▲ CE" if x[5] > 0 else "▼ PE", x[6], x[7], x[8]))
def summ(lab, z):
    if not z:
        print("   %-26s none" % lab); return
    r = [x[6] for x in z]
    print("   %-26s %3d · right (0.5%%+ its way after 60 min) %d (%d%%) · wrong (0.5%%+ against) %d (%d%%) · avg %+.2f%% · to the close %+.2f%%" % (
        lab, len(z), sum(1 for v in r if v >= 0.5), 100 * sum(1 for v in r if v >= 0.5) // len(z), sum(1 for v in r if v <= -0.5),
        100 * sum(1 for v in r if v <= -0.5) // len(z), sum(r) / len(r), sum(x[7] for x in z) / len(z)))
print("   --- %d results filings, last %d days (%s shown above: the latest 40)" % (len(rows), DAYS, len(out)))
summ("ALL", out)
summ("OPEN day 1", [x for x in out if x[3] == "OPEN" and x[2] == 1])
summ("OPEN days 2-7", [x for x in out if x[3] == "OPEN" and x[2] > 1])
summ("SWING day 1", [x for x in out if x[3] == "SWING" and x[2] == 1])
summ("SWING days 2-7", [x for x in out if x[3] == "SWING" and x[2] > 1])
print("   (by 5-min candle - live GIR reads every 15 s, so it rings sooner · compare: ★ SPEED 55% right / 6% wrong, OPENING CALL 8% / 41%)")
PY_STUDY
python3 $W/p262_patch.py $D || back
cd $D && python3 -m py_compile resultreact.py ringgov.py eventwatch.py || back
echo "=== test"
python3 $W/p262test.py $D || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "=== the results-week rules on this server's last 40 days (read only)"
timeout 180 python3 $W/study.py $D 40 2>&1 | tail -50 || echo "  (the replay could not run - the patch is in)"
echo "✅ patch 262 done - results shares watched 7 sessions, 09:15 to the close: the open, the SWING, ⚡ SPEED rings on them."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
