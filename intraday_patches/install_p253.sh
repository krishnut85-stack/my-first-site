#!/bin/bash
# PATCH 253 - NEWS FASTER FOR THE SHARES THAT MATTER (lagaudit 13 Nov: company news reached Rama a median 25 min after publication; the news
#   scout walks 218 shares one by one, ~22 min a round). Now the hot shares - moving 1.5%+ (the 15 biggest) and results today / tomorrow - are
#   searched every 3 min between the round's shares; a story found 15+ min late says "🕒 found N min after it was published". 6 s between two
#   searches kept. Tested with a fake clock: 9 cases. Restarts the newsroom only - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
cp $D/newsroom.py $D/newsroom.py.bak$TS
back(){ cp $D/newsroom.py.bak$TS $D/newsroom.py; systemctl restart gir-newsroom 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/p253_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p253_patch.py - PATCH 253: NEWS FASTER FOR THE SHARES THAT MATTER (lagaudit 13 Nov: company news reached Rama a median 25 min after it was
published - the news scout walks 218 shares one by one, 6 s apart, ~22 min a round; MANAPPURAM's 09:41 story at 11:40).
  HOT SHARES   every F&O share moving 1.5%+ on the day (the 15 biggest) and every share with results today / tomorrow is searched every 3 min,
               between the round's normal shares (the round itself goes on; with many hot shares it takes ~30 min instead of ~22)
  FOUND LATE   a story found 15+ min after it was published says so: "🕒 found 47 min after it was published - the price may have moved already"
The 6 s between two searches is kept (Google must not block GIR). Usage: python3 p253_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "newsroom.py"); S = {"s": open(p, encoding="utf-8").read()}
ERR = []


def rep(old, new, tag):
    s = S["s"]
    if new in s:
        print("  newsroom.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    S["s"] = s.replace(old, new); print("  newsroom.py: %s" % tag)


rep('''                    newsalert.story(sym, h, link, dom, a["kind"], t_pub, word="NEWS")''',
    '''                    lag_ = int((now - t_pub) / 60)                     # patch 253: a story found late says so
                    newsalert.story(sym, h, link, dom, a["kind"], t_pub, word="NEWS",
                                    extra=(["🕒 found %d min after it was published - the price may have moved already" % lag_] if lag_ >= 15 else []))''',
    "a story found 15+ min late says so")
rep('''def scout_round(con, stop=None, tick=None):''', '''HOT_S, HOT_N, HOT_MOVE = 180, 15, 1.5                        # patch 253: the hot shares - every 3 min
_HOT = {}


def hot_list(now=None):
    """the F&O shares to search every 3 min: moving 1.5%+ today (the 15 biggest, live prices) + results today / tomorrow"""
    out = []
    try:
        q = json.load(open(os.path.join(core.BASE, "quotes_live.json")))
        if time.time() - float(q.get("t") or 0) < 120:
            mv = sorted(((abs(v[1]), s) for s, v in (q.get("q") or {}).items() if v and v[1] is not None and abs(v[1]) >= HOT_MOVE and s != "NIFTY50"), reverse=True)
            out += [s for _, s in mv[:HOT_N]]
    except Exception:
        pass
    try:
        now = now or core.ist_now()
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(core.BASE, "chains.db"), uri=True, timeout=5)
        d0, d1 = str(now.date()), str(now.date() + dt.timedelta(days=1))
        out += [r[0] for r in c.execute("select distinct sym from results_cal where d>=? and d<=?", (d0, d1)) if r[0] not in out]
        c.close()
    except Exception:
        pass
    return out


def _hot_one(con, names, stop=None):
    """one due hot share searched (not searched for 3 min) -> new items"""
    hm = core.ist_now().strftime("%H:%M")
    if not ("09:00" <= hm <= "15:35") or (stop and stop.is_set()):
        return 0
    for s in hot_list():
        if s in names and time.time() - _HOT.get(s, 0) >= HOT_S:
            _HOT[s] = time.time()
            n = scout_one(con, s, names[s])
            time.sleep(GAP_S)
            return n
    return 0


def scout_round(con, stop=None, tick=None):''', "hot_list() · _hot_one()")
rep('''        new += scout_one(con, sym, name)
        if i % 40 == 0:
            new += scout_exchange(con)
        time.sleep(GAP_S)''', '''        if time.time() - _HOT.get(sym, 0) >= HOT_S:            # patch 253: not again if it was just searched as a hot share
            _HOT[sym] = time.time()
            new += scout_one(con, sym, name)
        if i % 40 == 0:
            new += scout_exchange(con)
        time.sleep(GAP_S)
        try:                                                    # patch 253: a hot share (moving / results) every 3 min, between the round's shares
            new += _hot_one(con, {s_: n_ for s_, n_, l_ in syms}, stop)
        except Exception as ex_:
            log("newsroom hot: %s" % str(ex_)[:80])''', "the round searches a due hot share after each share")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(S["s"])
print("patch 253 in")
PY_PATCH
cat > $W/p253test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p253test.py - the hot shares searched every 3 min · a late story labelled (fake clock, stub search, temp folder, nothing sent).
python3 p253test.py DIR (newsroom.py after patch 253)"""
import os, sys, json, types, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp()
shutil.copy(os.path.join(SRC, "newsroom.py"), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
CLK = {"t": dt.datetime(2026, 11, 16, 10, 0, tzinfo=IST).timestamp()}
core = types.ModuleType("core"); core.BASE = T; core.ist_now = lambda: dt.datetime.fromtimestamp(CLK["t"], IST); sys.modules["core"] = core
eng = types.ModuleType("engine"); eng.log = lambda *a: None; sys.modules["engine"] = eng
import re as _re
ver = types.ModuleType("verdict"); ver.BULL_NEWS = _re.compile(r"jump|rise"); ver.BEAR_NEWS = _re.compile(r"fall"); sys.modules["verdict"] = ver
SENT = []
na = types.ModuleType("newsalert"); na.about_it = lambda s, h, src="", name="": True
na.story = lambda sym, h, link="", src="", kind="", t=None, word="NEWS", also=(), extra=(), name="", sync=False: SENT.append((sym, h, list(extra)))
sys.modules["newsalert"] = na
sys.path.insert(0, T); os.chdir(T)
import time as _time
import newsroom as N
N.time = types.SimpleNamespace(time=lambda: CLK["t"], sleep=lambda s: CLK.__setitem__("t", CLK["t"] + s))
SYMS = [("S%03d" % i, "Share %d" % i, 1) for i in range(215)] + [("AMBER", "Amber Enterprises", 1), ("GRASIM", "Grasim", 1), ("RVNL", "Rail Vikas", 1)]
N.fo_names = lambda: SYMS
CALLS = []
N.google_news = lambda name, sym, days=4: CALLS.append((CLK["t"], sym)) or []
N.scout_exchange = lambda con, hours=48: 0
json.dump({"t": CLK["t"] + 10 ** 6, "q": {"AMBER": [6700, 8.4], "GRASIM": [3020, -3.0], "S005": [100, 0.4], "NIFTY50": [25100, -0.6]}}, open(os.path.join(T, "quotes_live.json"), "w"))
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table results_cal(d text, sym text, purpose text)")
c.execute("insert into results_cal values('2026-11-17','RVNL','')"); c.execute("insert into results_cal values('2026-11-25','S010','')"); c.commit(); c.close()
OK = []
def chk(n, cnd, got=""):
    OK.append(bool(cnd)); print("  %s %s%s" % ("✅" if cnd else "❌", n, "" if cnd else "   got: %s" % str(got)[:300]))
chk("the hot list: AMBER, GRASIM (1.5%+), RVNL (results tomorrow) - not S005 (0.4%), not S010 (results next week)", N.hot_list() == ["AMBER", "GRASIM", "RVNL"], N.hot_list())
con = N.db()
t0 = CLK["t"]; N.scout_round(con)
dur = (CLK["t"] - t0) / 60
by = {}
for t, s in CALLS:
    by.setdefault(s, []).append(t)
gaps = lambda s: [round((b - a) / 60, 1) for a, b in zip(by[s], by[s][1:])]
chk("AMBER searched again and again, every ~3 min (%d times in the %.0f-min round)" % (len(by["AMBER"]), dur), len(by["AMBER"]) >= dur / 3.5 and max(gaps("AMBER")) <= 3.6, gaps("AMBER")[:8])
chk("GRASIM and RVNL too (%d and %d times)" % (len(by["GRASIM"]), len(by["RVNL"])), len(by["GRASIM"]) >= dur / 3.5 and len(by["RVNL"]) >= dur / 3.5, (len(by["GRASIM"]), len(by["RVNL"])))
chk("every normal share still searched once in the round (215)", all(len(by.get("S%03d" % i, [])) == 1 for i in range(215)), [s for s in by if len(by[s]) != 1 and s.startswith("S")][:5])
chk("the round with 3 hot shares: %.0f min (was ~22)" % dur, 20 <= dur <= 32, dur)
gaps_all = sorted(b - a for (a, _), (b, _) in zip(CALLS, CALLS[1:]))
chk("never two searches closer than 6 s (Google is not hammered)", gaps_all[0] >= 6, gaps_all[:3])
CALLS.clear(); CLK["t"] = dt.datetime(2026, 11, 16, 17, 0, tzinfo=IST).timestamp()
json.dump({"t": 0, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
N.scout_round(con)
chk("after the market (17:00): no hot searches - one round as before (218)", len(CALLS) == 218, len(CALLS))
CLK["t"] = dt.datetime(2026, 11, 16, 11, 40, tzinfo=IST).timestamp()
N.store(con, "MANAPPURAM", [(CLK["t"] - 119 * 60, "Manappuram Finance shares jump 4% on gold loan growth", "http://x/1", "moneycontrol.com")])
N.store(con, "MUTHOOTFIN", [(CLK["t"] - 5 * 60, "Muthoot Finance shares jump on strong Q2", "http://x/2", "moneycontrol.com")])
late = [x for x in SENT if x[0] == "MANAPPURAM"]; fresh = [x for x in SENT if x[0] == "MUTHOOTFIN"]
chk("MANAPPURAM's 09:41 story found at 11:40: '🕒 found 119 min after it was published'", late and late[0][2] and "found 119 min after" in late[0][2][0], late)
chk("a story found 5 min after: no label", fresh and not fresh[0][2], fresh)
print("NEWS SPEED test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p253_patch.py $D || back
cd $D && python3 -m py_compile newsroom.py || back
echo "=== test: the hot shares every 3 min, a late story labelled (fake clock)"
python3 $W/p253test.py $D || back
echo "=== the hot list on this server now (outside market hours it holds only the results shares):"
cd $D && timeout 30 python3 -c "
import sys; sys.path.insert(0, '$D')
import newsroom; print('   ', newsroom.hot_list() or '(none now)')" 2>&1 | tail -1
systemctl restart gir-newsroom; sleep 5; echo "  gir-newsroom: $(systemctl is-active gir-newsroom)"
[ "$(systemctl is-active gir-newsroom)" = "active" ] || back
echo "✅ patch 253 done - moving and results shares get their news every 3 min; late stories are labelled."
echo "   undo: cp $D/newsroom.py.bak$TS $D/newsroom.py; systemctl restart gir-newsroom"
