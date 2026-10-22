#!/usr/bin/env python3
"""replay.py - run the v2 desk over a PAST session using Kite's real candles and the real news
database, with a simulated clock. Nothing is sent to Telegram and the real journal is untouched.

  python3 replay.py 2026-10-13 11:00 60     (date, stop time IST, number of shares)
"""
import sys, time, calendar, datetime as dt, os
DAY = dt.date.fromisoformat(sys.argv[1])
STOP = sys.argv[2] if len(sys.argv) > 2 else "11:00"
N = int(sys.argv[3]) if len(sys.argv) > 3 else 60
os.environ.pop("TELEGRAM_TOKEN", None); os.environ.pop("TELEGRAM_BOT_TOKEN", None)
clock = [calendar.timegm(dt.datetime(DAY.year, DAY.month, DAY.day, 9, 14).timetuple()) - 19800]
real_time, real_sleep = time.time, time.sleep
time.time = lambda: clock[0]
def _sleep(s):
    clock[0] += max(s, 0.01)
    real_sleep(min(s, 0.3) if s < 1 else 0.3)   # keep Kite's 3-requests-a-second limit real
time.sleep = _sleep
import core, getdata, engine, engine2
engine.DB = engine2.DB = os.path.join(core.BASE, "replay.db")
if os.path.exists(engine.DB):
    os.remove(engine.DB)
engine.HIST_DAYS = 40
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
c = engine2.cfg2(); c["use_websocket"] = False; c["rest_fallback_size"] = N
kite = core.get_kite(c)
real_hist = kite.historical_data
cache = {}
def hist(token, a, b, interval, *x, **k):
    key = (token, interval, a.date())
    if key not in cache:
        real_sleep(0.36)
        cache[key] = real_hist(token, a, b.replace(hour=23, minute=59) if interval == "5minute" else b, interval)
    now = dt.datetime.fromtimestamp(clock[0], IST)
    return [r for r in cache[key] if r["date"] <= now]
kite.historical_data = hist
tokens = {e["sym"]: e["token"] for e in getdata.load_universe()}
def ltp(keys):
    now = dt.datetime.fromtimestamp(clock[0], IST); out = {}
    for k in keys:
        rows = hist(tokens[k[4:]], now.replace(hour=9, minute=15, tzinfo=None), now.replace(tzinfo=None), "5minute")
        if rows:
            r = rows[-1]; f = min(1.0, (now - r["date"]).total_seconds() / 300.0)
            out[k] = {"last_price": round(r["open"] + f * (r["close"] - r["open"]), 2)}
    return out
kite.ltp = ltp
core.get_kite = lambda c=None: kite
h, m = map(int, STOP.split(":"))
stop_at = calendar.timegm(dt.datetime(DAY.year, DAY.month, DAY.day, h, m).timetuple()) - 19800
_bars = engine.RestFeed.bars
def bars(self, j, kite_, now):
    if clock[0] >= stop_at:
        print("=== replay stopped at", STOP, "IST ==="); raise SystemExit(0)
    return _bars(self, j, kite_, now)
engine.RestFeed.bars = bars
print("=== REPLAY of %s with %d shares, Kite candles + real news, until %s IST ===" % (DAY, N, STOP))
engine2.run_day(c)
