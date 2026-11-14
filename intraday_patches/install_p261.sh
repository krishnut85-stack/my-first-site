#!/bin/bash
# PATCH 261 - RESULTS FILED OVERNIGHT -> A CONFIRMED ALERT AT THE OPEN (Rama, 14 Nov: "some shares gap up / gap down on results right after
#   the open and keep going"). 🚨 RESULTS REACTION only looked 20 min after a filing made in market hours - most results come out in the evening,
#   and at 09:15 GIR said nothing for them (only the opening call did, silent since patch 259). Now, 09:20-11:00, every F&O share whose results
#   were filed after the last session's close and before 09:15:
#     HELD   opened 1.5%+ away, the first 5-min candle done, the price breaks that candle's high (low) -> 🚨 RESULTS REACTION ▲ BUY CE (▼ BUY PE)
#     FADED  opened 2%+ away, the price back through yesterday's close by 0.5% -> the market rejected the results: the other side
#   Once a share a day · rings like every RESULTS REACTION (09:15-09:30 too) · Box Picks · the vote never turns it down · the exit watch follows.
#   Tested: 18 cases. Then the same rule replayed on this server's past results days (read only). Restarts the news hunt - after 15:35 (or: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/resultreact.py ] || { echo "resultreact.py missing (patch 223)"; exit 1; }
cp $D/resultreact.py $D/resultreact.py.bak$TS
back(){ cp $D/resultreact.py.bak$TS $D/resultreact.py; systemctl restart gir-newshunt 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p261_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p261_patch.py - patch 261: RESULTS FILED OVERNIGHT -> a confirmed alert at the open (Rama, 14 Nov: "some shares gap up / gap down on good
results right after the open and keep going"). 🚨 RESULTS REACTION only looked 20 min after a filing made in market hours; most results come out
in the evening or night - at 09:15 GIR said nothing for them (only the opening call did, silent since 259). Now, 09:20-11:00, for each F&O share
whose RESULTS were filed after the last session's close (15:30) and before 09:15:
  HELD   it opened 1.5%+ away from yesterday's close, the first 5-min candle is done, and the price breaks that candle's high (gap up) / low
         (gap down) while still 1.5%+ away  -> 🚨 RESULTS REACTION ▲ BUY CE / ▼ BUY PE · stop: back under / over the first candle
  FADED  it opened 2%+ away and the price has crossed back through yesterday's close by 0.5%  -> the market rejected the results: the other side
Once a share a day. The same head as 223's RESULTS REACTION, so it rings (the ambulance, 09:15-09:30 too), goes to Box Picks, the vote never
turns it down, the exit watch follows it.   python3 p261_patch.py DIR"""
import os, sys
D = sys.argv[1]
p = os.path.join(D, "resultreact.py")
s = open(p, encoding="utf-8").read()
if "patch 261" in s:
    print("  resultreact.py: patch 261 - already in"); sys.exit(0)

NEW = r'''GAP_MIN, FADE_MIN, GAP_FROM, GAP_TO = 1.5, 2.0, "09:20", "11:00"     # patch 261: results filed overnight


def _last_session(today):
    """patch 261: the trading day before today (NSE holidays from holidays.py, else weekdays)"""
    c_ = ST.get("ls")
    if c_ and c_[0] == today:
        return c_[1]
    d = today - dt.timedelta(days=1)
    for _ in range(12):
        try:
            import holidays as _HD
            off = _HD.holiday(d)
        except Exception:
            off = "weekend" if d.weekday() >= 5 else None
        if not off:
            break
        d -= dt.timedelta(days=1)
    ST["ls"] = (today, d)
    return d


def overnight(day, now_t):
    """patch 261: {sym: (filed epoch, verdict)} - RESULTS filed after the last session's close (15:30) and before today's 09:15"""
    c_ = ST.get("ov")
    if c_ and c_[0] == day and now_t - c_[1] < 60:
        return c_[2]
    today = dt.date.fromisoformat(day)
    a = dt.datetime.combine(_last_session(today), dt.time(15, 30), IST).timestamp()
    b = dt.datetime.combine(today, dt.time(9, 15), IST).timestamp()
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "filings.db"), uri=True, timeout=3)
        for s, te, ver in c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>=? and t_exch<? order by t_exch", (a, b)):
            if s and s not in out:
                out[s] = (float(te), ver or "")
        c.close()
    except Exception:
        pass
    ST["ov"] = (day, now_t, out)
    return out


def gap_tick(now, ltp, chg=None, fo=None):
    """patch 261: 09:20-11:00 - an overnight results share that HELD its gap past the first 5-min candle, or FADED it through yesterday's close"""
    hm = now.strftime("%H:%M")
    if not (GAP_FROM <= hm <= GAP_TO):
        return []
    out = []
    for s, (te, ver) in overnight(str(now.date()), now.timestamp()).items():
        if (fo and s not in fo) or (s, "gap") in ST["said"] or (s, 1) in ST["said"] or (s, -1) in ST["said"]:
            continue
        px, c = ltp.get(s), _charts().get(s) or {}
        pc, O, Hh, L = c.get("pc"), c.get("o") or [], c.get("h") or [], c.get("l") or []
        if not (px and pc and O and O[0] and Hh and Hh[0] and L and L[0]):
            continue
        gap, mv = (O[0] / pc - 1) * 100, (px / pc - 1) * 100
        d = kind = 0
        if gap >= GAP_MIN and px > Hh[0] and mv >= GAP_MIN:
            d, kind = 1, "held"
        elif gap <= -GAP_MIN and px < L[0] and mv <= -GAP_MIN:
            d, kind = -1, "held"
        elif gap >= FADE_MIN and mv <= -0.5:
            d, kind = -1, "faded"
        elif gap <= -FADE_MIN and mv >= 0.5:
            d, kind = 1, "faded"
        if not d:
            continue
        ST["said"].add((s, "gap"))
        read = "MISS" if d < 0 else "BEAT"
        vd = (ver or "").upper()
        said = ""
        if vd and ((d < 0 and re.search(r"BEAT|IN LINE|INLINE", vd)) or (d > 0 and re.search(r"MISS|IN LINE|INLINE", vd))):
            said = " - GIR's reader said %s, the price says %s: the price is the verdict" % (vd[:24], read)
        side = "PE" if d < 0 else "CE"
        filed = dt.datetime.fromtimestamp(te, IST).strftime("%a %H:%M")
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
            "results filed %s (after the close) · %s" % (filed, how),
            why,
            "▶ BUY %s (at the money) - %s · stop: a close %s ₹%s (%s)" % (side, "▼ DOWN → PE" if d < 0 else "▲ UP → CE", "over" if d < 0 else "under", _inr(stop), sw),
            "results gaps can run all day, but a big gap can also snap back: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    return out


def _p_before(sym, te):'''

TAIL_OLD = '''            "results moves run fast: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    return out'''
TAIL_NEW = '''            "results moves run fast: book half into the next leg (GIR rings 🧱 near the band) - the exit watch follows this call"]))
    out += gap_tick(now, ltp, chg, fo)                          # patch 261: results filed overnight - at the open
    return out'''
for old, new, tag in (("def _p_before(sym, te):", NEW, "the overnight results list and the open check"),
                      (TAIL_OLD, TAIL_NEW, "the open check runs every 15 s with the results reaction")):
    if s.count(old) != 1:
        print("❌ resultreact.py: anchor for '%s' found %d times (needs 1)" % (tag, s.count(old))); sys.exit(1)
    s = s.replace(old, new)
    print("  resultreact.py: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("resultreact.py: patch 261 in")
PY_PATCH
cat > $W/p261test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p261test.py - results filed overnight -> a confirmed RESULTS REACTION at the open (made-up filings and candles, temp copy, nothing sent).
python3 p261test.py DIR   (DIR: resultreact.py [, alertword.py, tglanes.py, exitwatch.py])"""
import os, sys, json, types, shutil, sqlite3, tempfile, datetime as dt
SRC = sys.argv[1]
T = tempfile.mkdtemp()
for f in ("resultreact.py", "alertword.py", "ringgov.py", "tglanes.py", "exitwatch.py", "p1vote.py"):
    if os.path.exists(os.path.join(SRC, f)):
        shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
HOL = {"2026-11-24"}
sys.modules["holidays"] = types.SimpleNamespace(holiday=lambda d: "weekend" if d.weekday() >= 5 else ("Guru Nanak" if str(d) in HOL else None))
at = lambda y, m, d, h, mi: dt.datetime(y, m, d, h, mi, tzinfo=IST)
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
F = [("XYZ", at(2026, 11, 13, 18, 42), "BEAT"), ("ABC", at(2026, 11, 13, 20, 5), "MISS"), ("DEF", at(2026, 11, 16, 7, 40), "BEAT"),
     ("GHI", at(2026, 11, 13, 14, 0), "BEAT"), ("JKL", at(2026, 11, 12, 19, 0), "BEAT"), ("SML", at(2026, 11, 13, 17, 0), "BEAT"),
     ("NFO", at(2026, 11, 13, 17, 30), "BEAT"), ("INL", at(2026, 11, 13, 19, 30), "IN LINE"), ("WAIT", at(2026, 11, 13, 21, 0), "BEAT"),
     ("LATE", at(2026, 11, 13, 22, 0), "BEAT"), ("HOL", at(2026, 11, 23, 19, 0), "BEAT")]
for i, (s, t, v) in enumerate(F):
    c.execute("insert into filings(key, sym, t_exch, kind, verdict) values(?,?,?,?,?)", ("k%d" % i, s, int(t.timestamp()), "RESULTS", v))
c.commit(); c.close()
bar = lambda pc, o, h, l, cl: {"pc": pc, "o": [o], "h": [h], "l": [l], "c": [cl], "v": [1000]}
json.dump({"XYZ": bar(1000, 1041, 1050, 1032, 1046), "ABC": bar(500, 480, 485, 476, 478), "DEF": bar(200, 206, 207, 203, 204),
           "GHI": bar(300, 312, 315, 309, 313), "JKL": bar(100, 104, 105, 103, 104), "SML": bar(100, 100.8, 101.2, 100.5, 101),
           "NFO": bar(100, 104, 105, 103, 104), "INL": bar(100, 97, 97.5, 96.2, 96.5), "WAIT": bar(100, 103, 104, 102.5, 103.5),
           "LATE": bar(100, 103, 104, 102.5, 103.5), "HOL": bar(100, 103, 104, 102.5, 103.5)}, open(os.path.join(T, "charts.json"), "w"))
import resultreact as RR
FO = {"XYZ", "ABC", "DEF", "GHI", "JKL", "SML", "INL", "WAIT", "LATE", "HOL"}
OK = []
def chk(name, cond, extra=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   -> %s" % (extra,)))
def tick(t, q):
    return RR.tick(t, q, {}, fo=FO)
mon = lambda h, m: at(2026, 11, 16, h, m)

r = tick(mon(9, 18), {"XYZ": 1055.0})
chk("09:18 XYZ +5.5% (first 5-min candle not done): nothing yet", r == [], r)
r = tick(mon(9, 21), {"XYZ": 1046.0})
chk("09:21 XYZ inside its first candle (₹1,032-1,050): nothing - not confirmed", r == [], r)
r = tick(mon(9, 22), {"XYZ": 1052.0})
x = r[0] if r else ""
chk("09:22 XYZ (filed Fri 18:42) breaks ₹1,050: 🚨 RESULTS REACTION ▲ BUY CE", len(r) == 1 and x.startswith("🚨 CRITICAL · RESULTS REACTION ▲ XYZ · 09:22")
    and "BUY CE" in x and "Fri 18:42" in x and "opened +4.1%" in x and "broke its high ₹1,050" in x, r)
chk("... stop: a close under ₹1,032 (the first 5-min low)", "stop: a close under ₹1,032 (the first 5-min low)" in x, x)
print("\n" + x + "\n")
chk("09:30 XYZ again: once a share a day", tick(mon(9, 30), {"XYZ": 1070.0}) == [])
r = tick(mon(9, 25), {"ABC": 474.0})
chk("ABC (Fri 20:05, MISS) opened -4%, breaks its first low ₹476: ▼ BUY PE, stop over ₹485", len(r) == 1 and "RESULTS REACTION ▼ ABC" in r[0]
    and "BUY PE" in r[0] and "stop: a close over ₹485" in r[0], r)
r = tick(mon(9, 40), {"DEF": 198.9})
chk("DEF (filed 07:40 today) opened +3%, now -0.55% below yesterday: FADED -> ▼ BUY PE", len(r) == 1 and "RESULTS REACTION ▼ DEF" in r[0]
    and "the gap is gone" in r[0] and "sold the good open" in r[0] and "BUY PE" in r[0] and "stop: a close over ₹203" in r[0], r)
chk("GHI filed Fri 14:00 (in market hours - it already reacted Friday): nothing at the Monday open", tick(mon(9, 26), {"GHI": 318.0}) == [])
chk("JKL filed Thu evening (Friday traded it): nothing on Monday", tick(mon(9, 26), {"JKL": 106.0}) == [])
chk("SML opened only +0.8%: no results gap, nothing", tick(mon(9, 26), {"SML": 101.5}) == [])
chk("NFO not an F&O share: nothing", tick(mon(9, 26), {"NFO": 106.0}) == [])
r = tick(mon(9, 27), {"INL": 96.0})
chk("INL: GIR's reader said IN LINE, the price fell through: ▼ PE + 'the price is the verdict'", len(r) == 1 and "the price is the verdict" in r[0], r)
chk("WAIT at 10:59 breaking out: still in time", len(tick(mon(10, 59), {"WAIT": 104.5})) == 1)
chk("LATE at 11:05: past the open window, nothing", tick(mon(11, 5), {"LATE": 104.5}) == [])
r = tick(at(2026, 11, 25, 9, 22), {"HOL": 104.6})
chk("HOL filed Mon 23 Nov 19:00, Tue 24 Nov a holiday: rings Wed 25 Nov", len(r) == 1 and "Mon 19:00" in r[0], r)
if os.path.exists(os.path.join(T, "alertword.py")):
    import alertword as AW
    ref = "🚨 CRITICAL · RESULTS REACTION ▼ PAGEIND · 14:30\nresults filed 14:29:53 · the share -1.9% since\n▶ BUY PE (at the money) - ▼ DOWN → PE · stop: a close over ₹36,500 (where it was before the results)"
    chk("the same tier as 223's RESULTS REACTION (%s)" % AW.tier(ref), AW.tier(x) == AW.tier(ref), (AW.tier(x), AW.tier(ref)))
if os.path.exists(os.path.join(T, "tglanes.py")):
    import tglanes as TL
    f_ = getattr(TL, "lane", None)
    if f_:
        try:
            chk("the same Telegram lane as 223's RESULTS REACTION", f_(x) == f_(ref), (f_(x), f_(ref)))
        except TypeError:
            pass
if os.path.exists(os.path.join(T, "exitwatch.py")):
    import exitwatch as XW
    st = (XW.parse(x) or {}).get("stop")
    chk("the exit watch reads its stop (₹1,032)", st and abs(st[1] - 1032.0) < 0.01, XW.parse(x))
print("RESULTS AT THE OPEN test: %d of %d passed" % (sum(OK), len(OK)))
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
rows, seen = [], set()
for s, te, ver in c.execute("select sym, t_exch, verdict from filings where kind='RESULTS' and t_exch>? order by t_exch", (now - DAYS * 86400,)):
    if s and (not fo or s in fo):
        rows.append((s, float(te), ver or ""))
c.close()
def bars(sym):
    for p in ("data/%s.npz" % sym, "data/h3/%s.npz" % sym, "data/h3/5min/%s.npz" % sym):
        try:
            z = np.load(p); return {k: np.asarray(z[k], dtype=float) for k in ("ts", "o", "h", "l", "c")}
        except Exception:
            continue
    return None
out = []
for s, te, ver in rows:
    B = bars(s)
    if B is None or not len(B["ts"]):
        continue
    day = ((B["ts"] + 19800) // 86400).astype(int)
    tday = int((te + 19800) // 86400)
    tm = dt.datetime.fromtimestamp(te, IST)
    in_hours = tday in set(day.tolist()) and "09:15" <= tm.strftime("%H:%M") < "15:30"
    if in_hours:
        continue
    nxt = sorted(d for d in set(day.tolist()) if d > tday or (d == tday and tm.strftime("%H:%M") < "09:15"))
    if not nxt:
        continue
    nd = nxt[0]
    if (s, nd) in seen:
        continue
    seen.add((s, nd))
    prev = np.nonzero(day < nd)[0]
    idx = np.nonzero(day == nd)[0]
    if not len(prev) or len(idx) < 14:
        continue
    pc = B["c"][prev[-1]]
    O, H, L, C = B["o"][idx], B["h"][idx], B["l"][idx], B["c"][idx]
    gap = (O[0] / pc - 1) * 100
    sig = None
    for k in range(1, min(len(idx), 21)):                    # 09:20 .. 11:00
        if gap >= 1.5 and H[k] > H[0] and (max(H[k], H[0]) / pc - 1) * 100 >= 1.5:
            sig = (k, 1, "held", max(H[0], O[k])); break
        if gap <= -1.5 and L[k] < L[0] and (min(L[k], L[0]) / pc - 1) * 100 <= -1.5:
            sig = (k, -1, "held", min(L[0], O[k])); break
        if gap >= 2.0 and L[k] <= pc * 0.995:
            sig = (k, -1, "faded", min(pc * 0.995, O[k])); break
        if gap <= -2.0 and H[k] >= pc * 1.005:
            sig = (k, 1, "faded", max(pc * 1.005, O[k])); break
    r60 = rday = None
    if sig:
        k, d, kind, e = sig
        r60 = (C[min(len(C) - 1, k + 12)] / e - 1) * 100 * d
        rday = (C[-1] / e - 1) * 100 * d
    out.append((dt.datetime.fromtimestamp(nd * 86400 - 19800 + 33300, IST).strftime("%d %b"), s, tm.strftime("%d %b %H:%M"), ver[:10], gap, sig, r60, rday))
print("   %-7s %-11s %-13s %-10s %6s  %-26s %7s %7s" % ("day", "share", "filed", "reader", "gap", "GIR at the open (patch 261)", "60 min", "close"))
for d_, s, f_, v, g, sig, r60, rd in out:
    if sig:
        k = sig[0]; hm = "%02d:%02d" % divmod(9 * 60 + 15 + 5 * k, 60)
        what = "%s %s %s" % (hm, "▲ CE" if sig[1] > 0 else "▼ PE", sig[2])
        print("   %-7s %-11s %-13s %-10s %+5.1f%%  %-26s %+6.1f%% %+6.1f%%" % (d_, s, f_, v, g, what, r60, rd))
    else:
        print("   %-7s %-11s %-13s %-10s %+5.1f%%  %-26s" % (d_, s, f_, v, g, "nothing (no gap or not confirmed)"))
S = [x for x in out if x[5]]
if S:
    r = [x[6] for x in S]
    print("   overnight results: %d · GIR would have rung %d · right (0.5%%+ its way after 60 min) %d · wrong (0.5%%+ against) %d · avg %+.2f%% · avg to the close %+.2f%%" % (
        len(out), len(S), sum(1 for x in r if x >= 0.5), sum(1 for x in r if x <= -0.5), sum(r) / len(r), sum(x[7] for x in S) / len(S)))
    for kd in ("held", "faded"):
        z = [x[6] for x in S if x[5][2] == kd]
        if z:
            print("     %-6s %d · right %d · wrong %d · avg %+.2f%%" % (kd, len(z), sum(1 for x in z if x >= 0.5), sum(1 for x in z if x <= -0.5), sum(z) / len(z)))
else:
    print("   overnight results found: %d · none confirmed" % len(out))
print("   (by 5-min candle - live GIR reads every 15 s, so it rings sooner; a small count - re-measured with the next results days)")
PY_STUDY
python3 $W/p261_patch.py $D || back
cd $D && python3 -m py_compile resultreact.py || back
echo "=== test"
python3 $W/p261test.py $D || back
systemctl restart gir-newshunt 2>/dev/null; sleep 5
echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
echo "=== the same rule on this server's past results days (last 40 days, read only)"
timeout 120 python3 $W/study.py $D 40 2>&1 | tail -45 || echo "  (the replay could not run - the patch is in)"
echo "✅ patch 261 done - from Monday: results filed overnight get a 🚨 RESULTS REACTION at the open once the gap is confirmed (or rejected)."
echo "   undo: cp $D/resultreact.py.bak$TS $D/resultreact.py; systemctl restart gir-newshunt"
