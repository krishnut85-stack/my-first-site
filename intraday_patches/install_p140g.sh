#!/bin/bash
# PATCH 140g - NIFTY / SENSEX / BANKNIFTY / VIX (and the sector indices) SHOW THE RIGHT CHANGE AFTER 15:30.
#   Kite's quote gives a wrong previous close after the market closes (GIR showed NIFTY +15.02 (+0.06%), Kite +58.25 (+0.23%)).
#   Now the previous close is fixed for the day: saved during the session, else Kite's daily candles, else the feed's own -
#   never the wrong after-close figure. idxclose.py (new) · engine2.py (2 anchors). Restarts gir-intraday - outside market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140g; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35"; exit 1; fi
grep -q "patch 140g" $D/engine2.py && { echo "patch 140g is already installed"; exit 1; }
cp $D/engine2.py $D/engine2.py.bak$TS
back() { cp $D/engine2.py.bak$TS $D/engine2.py; rm -f $D/idxclose.py $D/p140gtest.py; systemctl restart gir-intraday; echo "ERROR - old engine back, nothing changed"; exit 1; }
cat > $W/p140g_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140g_patch.py - PATCH 140g: the engine takes every index's previous close from idxclose.py (fixed for the day) instead of
Kite's quote, which is wrong after 15:30. Usage: python3 p140g_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = [
    ('''                    lp_, pc_ = float(v_.get("last_price") or 0), float((v_.get("ohlc") or {}).get("close") or 0)
                    if lp_:
                        SIDX[n_] =''',
     '''                    lp_, pc_ = float(v_.get("last_price") or 0), float((v_.get("ohlc") or {}).get("close") or 0)
                    try:
                        import idxclose
                        pc_ = idxclose.prev_close(kite, "SEC:" + n_, v_)       # patch 140g: fixed for the day (the quote is wrong after 15:30)
                    except Exception:
                        pass
                    if lp_:
                        SIDX[n_] ='''),
    ('''                    lp_, pc_ = float(v_.get("last_price") or 0), float((v_.get("ohlc") or {}).get("close") or 0)
                    if lp_:
                        IDX[nm_] =''',
     '''                    lp_, pc_ = float(v_.get("last_price") or 0), float((v_.get("ohlc") or {}).get("close") or 0)
                    try:
                        import idxclose
                        fpc_ = None
                        if nm_ == "NIFTY" and getattr(feed, "pos", None) and "NIFTY50" in feed.pos:
                            fpc_ = float(feed.pclose[feed.pos["NIFTY50"]])
                        pc_ = idxclose.prev_close(kite, nm_, v_, fpc_)         # patch 140g: fixed for the day (the quote is wrong after 15:30)
                    except Exception:
                        pass
                    if lp_:
                        IDX[nm_] ='''),
]
p = os.path.join(D, "engine2.py")
s = open(p, encoding="utf-8").read()
if "patch 140g" in s:
    print("patch 140g is already in engine2.py"); sys.exit(1)
for a, b in EDITS:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:100].replace("\n", " | "))); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("patched: engine2.py")
PY_PATCH
cat > $D/idxclose.py <<'PY_MOD'
#!/usr/bin/env python3
"""idxclose.py - patch 140g: EVERY INDEX'S PREVIOUS CLOSE, FIXED FOR THE DAY (Rama, 9 Nov 16:50: "the values are always critical").
Kite's quote gives an index's previous close correctly during the session but a different figure after 15:30 (NIFTY 25,029.63
against the real 24,986.40 on 9 Nov - GIR showed +15.02 (+0.06%) where Kite shows +58.25 (+0.23%)). So the previous close is:
  1. the one saved during today's session (data/idx_pc.json - kept across restarts)
  2. else Kite's daily candles: the last day before today (official)
  3. else, for NIFTY, the tick feed's own close (what the NIFTY chart uses)
  4. else the quote's figure - only inside the session (09:00-15:30, Mon-Fri); outside it: unknown (no % shown, never a wrong one)
  python3 idxclose.py      what is saved for today"""
import os, json, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "idx_pc.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
ST = {"day": None, "v": {}, "tried": {}}


def _save():
    try:
        os.makedirs(os.path.dirname(FILE), exist_ok=True)
        json.dump({"day": ST["day"], "v": ST["v"]}, open(FILE + ".tmp", "w"))
        os.replace(FILE + ".tmp", FILE)
    except Exception:
        pass


def prev_close(kite, key, q, feed_pc=None, now=None):
    """key: the index's name · q: its kite.quote() entry · feed_pc: the tick feed's close if the index is on the feed -> the
    previous close (float) or 0.0 when it cannot be known for sure"""
    now = now or dt.datetime.now(IST)
    day, hm = str(now.date()), now.strftime("%H:%M")
    if ST["day"] != day:
        ST.update({"day": day, "v": {}, "tried": {}})
        try:
            j = json.load(open(FILE))
            if j.get("day") == day:
                ST["v"] = {k: float(v) for k, v in (j.get("v") or {}).items()}
        except Exception:
            pass
    if ST["v"].get(key):
        return ST["v"][key]
    q = q or {}
    pc_q = float((q.get("ohlc") or {}).get("close") or 0)
    in_session = now.weekday() < 5 and "09:00" <= hm < "15:30"
    pc = 0.0
    if in_session and pc_q > 0:
        pc = pc_q
    else:
        tok = q.get("instrument_token")
        t0 = ST["tried"].get(key, 0)
        if kite is not None and tok and now.timestamp() - t0 > 600:          # the daily candles: once per 10 min per index at most
            ST["tried"][key] = now.timestamp()
            try:
                C = kite.historical_data(int(tok), now.date() - dt.timedelta(days=12), now.date(), "day") or []
                prev = [c for c in C if str(c.get("date"))[:10] < day and c.get("close")]
                if prev:
                    pc = float(prev[-1]["close"])
            except Exception:
                pc = 0.0
        if not pc and feed_pc and feed_pc == feed_pc and feed_pc > 0:
            pc = float(feed_pc)
    if pc > 0:
        ST["v"][key] = round(pc, 2)
        _save()
        return ST["v"][key]
    return 0.0


if __name__ == "__main__":
    try:
        print(json.load(open(FILE)))
    except Exception as ex:
        print("nothing saved yet:", ex)
PY_MOD
cat > $D/p140gtest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p140gtest.py - patch 140g: the index's previous close stays right after 15:30 (fake Kite, a temporary folder)"""
import os, sys, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import idxclose as X
X.FILE = os.path.join(tempfile.mkdtemp(), "idx_pc.json")
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
IST = X.IST
class K:
    n = 0
    def historical_data(self, tok, a, b, iv):
        K.n += 1
        return [{"date": "2026-11-06 00:00:00+05:30", "close": 24900.0}, {"date": "2026-11-09 00:00:00+05:30", "close": 25044.65}][:1] + [{"date": "2026-11-09", "close": 1}]
q_day = {"instrument_token": 256265, "ohlc": {"close": 24986.4}}
q_eve = {"instrument_token": 256265, "ohlc": {"close": 25029.63}}
t = lambda h, m, d=9: dt.datetime(2026, 11, d, h, m, tzinfo=IST)
check("10:00: the session's figure 24986.4 is kept", X.prev_close(K(), "NIFTY", q_day, now=t(10, 0)) == 24986.4)
check("16:50: the after-close quote 25029.63 is NOT used - still 24986.4", X.prev_close(K(), "NIFTY", q_eve, now=t(16, 50)) == 24986.4)
X.ST["day"] = None
check("after a restart the saved figure comes back from the file", X.prev_close(K(), "NIFTY", q_eve, now=t(16, 55)) == 24986.4)
X.ST.update({"day": None}); os.remove(X.FILE)
check("an engine started after the close: the daily candles (the last day before today = 24900)", X.prev_close(K(), "BANKNIFTY", q_eve, now=t(17, 0)) == 24900.0)
class Bad:
    def historical_data(self, *a):
        raise Exception("no historical access")
X.ST.update({"day": None}); os.remove(X.FILE)
check("no daily candles: NIFTY takes the tick feed's close", X.prev_close(Bad(), "NIFTY", q_eve, feed_pc=24986.4, now=t(17, 0)) == 24986.4)
check("no daily candles, not on the feed: unknown (0) - never the wrong after-close figure", X.prev_close(Bad(), "SENSEX", {"ohlc": {"close": 81025.62}, "instrument_token": 265}, now=t(17, 0)) == 0.0)
X.ST.update({"day": None})
check("a new day: yesterday's saved figure is not reused", X.prev_close(None, "NIFTY", {"ohlc": {"close": 25044.65}}, now=t(9, 20, 10)) == 25044.65)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
check("the engine uses it for NIFTY / SENSEX / BANKNIFTY / VIX and the sector indices", src.count("idxclose.prev_close(") == 2)
print("P140g TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p140g_patch.py $D || { rm -f $D/idxclose.py $D/p140gtest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile engine2.py idxclose.py p140gtest.py || back
for t in p140gtest.py p140test.py p137test.py p134test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-intraday && sleep 15
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
sleep 60; echo "    saved previous closes: $(python3 $D/idxclose.py)"
echo
echo "PATCH 140g APPLIED. Reload the GIR page: NIFTY / SENSEX / BANKNIFTY / VIX change as Kite shows it (an index with no"
echo "sure previous close shows no % rather than a wrong one)."
