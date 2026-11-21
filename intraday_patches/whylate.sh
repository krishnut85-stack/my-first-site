#!/bin/bash
# whylate.sh - WHEN DID THE MARKET KNOW, AND WHEN DID GIR? Read-only: nothing is changed or sent (one probe of the govt feeds).
#   bash whylate.sh "COROMANDEL CHAMBLFERT DEEPAKFERT RCF GNFC UPL PIIND" "fertili|subsidy|cabinet|NBS" [YYYY-MM-DD]
#   1 the shares' 5-min candles: when the move started (+1% / +2% / +3% from yesterday's close), the biggest-volume bar
#   2 every GIR alert on those shares that day, with the time
#   3 the business wires GIR reads every minute (data/macro.json): the story, when GIR saw it
#   4 the news reader's lag that day: published -> GIR read (all shares), and the round time
#   5 GOVT WATCH: what PIB / RBI / SEBI answer now, and its log
#   6 TV WATCH: what the channel said in the 10 minutes around the move's start
D=/home/globalbot/intraday
SYMS="${1:-COROMANDEL CHAMBLFERT DEEPAKFERT RCF GNFC UPL PIIND}"
RX="${2:-fertili|subsidy|cabinet|NBS}"
DAY="${3:-$(TZ=Asia/Kolkata date +%F)}"
cd $D || exit 1
python3 - "$SYMS" "$RX" "$DAY" <<'PY'
import os, re, sys, json, sqlite3, statistics, datetime as dt
syms, rx, day = sys.argv[1].split(), re.compile(sys.argv[2], re.I), sys.argv[3]
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST).timestamp(); d1 = d0 + 86400
f = lambda x: dt.datetime.fromtimestamp(float(x), IST).strftime("%H:%M:%S") if x else "-"
bt = lambda i: "%02d:%02d" % divmod(9 * 60 + 15 + 5 * i, 60)
def q(db, sql, a=()):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5); r = c.execute(sql, a).fetchall(); c.close(); return r
    except Exception as ex:
        print("   (%s: %s)" % (db, str(ex)[:60])); return []
print("=== 1 · WHEN THE SHARES MOVED (5-min candles, from yesterday's close)")
starts = []
try:
    C = json.load(open("charts.json"))
except Exception as ex:
    C = {}; print("   charts.json not read: %s" % ex)
for s in syms:
    x = C.get(s)
    if not x or not x.get("pc"):
        print("   %-11s no candles" % s); continue
    pc, c, h, v = x["pc"], x["c"], x["h"], x["v"]
    cross = {}
    for i in range(len(c)):
        if c[i] is None:
            continue
        for lvl in (1, 2, 3, 5):
            if lvl not in cross and h[i] and (h[i] / pc - 1) * 100 >= lvl:
                cross[lvl] = bt(i)
    vi = max(range(len(v)), key=lambda i: v[i] or 0) if v else None
    last = next((c[i] for i in range(len(c) - 1, -1, -1) if c[i]), None)
    print("   %-11s close %+.1f%% · crossed +1%% %s · +2%% %s · +3%% %s · +5%% %s · biggest volume %s" % (
        s, (last / pc - 1) * 100 if last else 0, cross.get(1, "-"), cross.get(2, "-"), cross.get(3, "-"), cross.get(5, "-"), bt(vi) if vi is not None else "-"))
    if 2 in cross:
        starts.append(cross[2])
print("=== 2 · EVERY GIR ALERT ON THESE SHARES THAT DAY")
rows = q("tomorrow.db", "select t, sym, text from alerts where day=? and sym in (%s) order by t" % ",".join("?" * len(syms)), (day, *syms))
for t, s, x in rows[:30]:
    print("   %s %-11s %s" % (t[:8], s, (x or "").split("\n")[0][:110]))
print("   (%d alerts)" % len(rows))
print("=== 3 · THE BUSINESS WIRES (read every minute) - the story")
try:
    M = json.load(open("data/macro.json")).get("items") or []
    hit = sorted([x for x in M if rx.search(x.get("h") or "")], key=lambda x: x.get("t") or 0)
    for x in hit[:12]:
        print("   published %s · %s · score %s · %s" % (f(x.get("t")), x.get("src") or "", x.get("score"), (x.get("h") or "")[:110]))
    print("   (%d of %d kept - a headline is kept only when it scores 3+ as market-moving news)" % (len(hit), len(M)))
except Exception as ex:
    print("   macro.json not read: %s" % ex)
print("=== 4 · THE NEWS READER'S LAG THAT DAY (Google News, published -> GIR read)")
rows = q("news.db", "select t_pub, t_seen from items where t_seen>=? and t_seen<? and t_pub>0", (d0, d1))
lag = [(b - a) / 60 for a, b in rows if b >= a]
mk = [(b - a) / 60 for a, b in rows if b >= a and d0 + 9.25 * 3600 <= a <= d0 + 15.5 * 3600]
if lag:
    print("   all day: %d items · median %.0f min · 75%% within %.0f min · 90%% within %.0f min" % (len(lag), statistics.median(lag), sorted(lag)[int(len(lag) * .75)], sorted(lag)[int(len(lag) * .9)]))
if mk:
    print("   published in market hours: %d items · median %.0f min · 90%% within %.0f min" % (len(mk), statistics.median(mk), sorted(mk)[int(len(mk) * .9)]))
print("=== 5 · GOVT WATCH (PIB / RBI / SEBI) - what each answers now")
os.system("timeout 60 python3 govwatch.py probe 2>&1 | head -8 | cut -c1-170 | sed 's/^/   /'")
os.system("tail -n 5 data/govwatch.log 2>/dev/null | cut -c1-170 | sed 's/^/   log: /'")
print("=== 6 · TV WATCH around the move's start (%s)" % (min(starts) if starts else "no 2% move"))
if starts:
    hh, mm = map(int, min(starts).split(":"))
    t0 = d0 + hh * 3600 + mm * 60
    rows = q("data/tv.db", "select ts, ch, text from tv where ts between ? and ? order by ts", (t0 - 900, t0 + 600))
    for ts, ch, t in rows:
        if t and len(t) > 30:
            print("   %s %s: %s" % (f(ts), ch, re.sub(r"\s+", " ", t)[:150]))
    print("   (%d pieces)" % len(rows))
PY
echo "=== done (nothing changed)"
