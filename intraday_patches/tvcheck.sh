#!/bin/bash
# tvcheck.sh - did 📺 TV WATCH listen today? Read-only: the service, the last log lines, what it heard per hour (data/tv.db),
#   the last things it heard, and any SHOCK WATCH it raised from TV today. Nothing is changed or sent.
D=/home/globalbot/intraday
echo "=== the service:  gir-tvwatch is $(systemctl is-active gir-tvwatch)"
echo "=== its last log lines"
tail -4 $D/data/tvwatch.log 2>/dev/null | cut -c1-160 | sed 's/^/  /'
cd $D && python3 - <<'PY'
import sqlite3, datetime as dt
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
t0 = now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
f = lambda x: dt.datetime.fromtimestamp(x, IST).strftime("%H:%M") if x else "-"
try:
    c = sqlite3.connect("file:data/tv.db?mode=ro", uri=True)
    n, a, b, chs = c.execute("select count(*), min(ts), max(ts), group_concat(distinct ch) from tv where ts >= ?", (t0,)).fetchone()
    words = c.execute("select count(*) from tv where ts >= ? and length(text) > 40", (t0,)).fetchone()[0]
    print("=== TODAY (%s): %d pieces of 20 s heard (%d with real speech) · %s to %s · channels: %s" % (now.strftime("%d %b"), n, words, f(a), f(b), chs or "none"))
    for h, k in c.execute("select strftime('%H', ts + 19800, 'unixepoch'), count(*) from tv where ts >= ? group by 1", (t0,)):
        print("  %s:00  %4d  %s" % (h, k, "#" * min(60, k // 3)))
    print("=== the last things it heard")
    for ts, ch, t in c.execute("select ts, ch, text from tv where ts >= ? and length(text) > 40 order by ts desc limit 4", (t0,)):
        print("  %s %s: %s" % (f(ts), ch, (t or "")[:150]))
    c.close()
except Exception as ex:
    print("=== data/tv.db not read: %s" % ex)
try:
    c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
    rows = c.execute("select t, text from alerts where day = ? and text like '%SHOCK WATCH%' and (text like '%CNBC%' or text like '%ET NOW%' or text like '%ZEE%' or text like '%AWAAZ%' or text like '%SANSAD%') order by t", (str(now.date()),)).fetchall()
    print("=== SHOCK WATCH from TV today: %d" % len(rows))
    for t, x in rows[:10]:
        print("  %s %s" % (t[:5], (x or "").split("\n")[0][:120]))
    c.close()
except Exception as ex:
    print("=== alerts not read: %s" % ex)
PY
