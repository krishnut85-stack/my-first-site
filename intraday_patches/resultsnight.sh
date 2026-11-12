#!/bin/bash
# resultsnight.sh - READ ONLY. 1) the F&O results filed today after 15:30 (after the market): the numbers GIR read (profit / revenue vs last
# year, vs the brokers), GIR's verdict, and the plain read · 2) the F&O shares with results TOMORROW (GIR's results desk: the brokers'
# number, the run-up, what the options price in). Changes nothing.   bash resultsnight.sh [YYYY-MM-DD]
D=/home/globalbot/intraday; DAY=${1:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$DAY" <<'PY'
import sys, re, json, sqlite3, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
day = sys.argv[1]
d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST)
t1530 = d0.replace(hour=15, minute=30).timestamp()
def q(db, sql, a=()):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5); r = c.execute(sql, a).fetchall(); c.close(); return r
    except Exception as ex:
        print("   (%s: %s)" % (db, str(ex)[:60])); return []
try:
    fo = {f["s"] for f in json.load(open("dash_state.json")).get("fo_paths") or [] if f.get("s")}
except Exception:
    fo = set()
print("=== 1 · F&O RESULTS FILED TODAY AFTER 15:30 (%s)" % day)
seen = []
for s, te, ver, sub, det in q("filings.db", "select sym, t_exch, verdict, subject, detail from filings where kind='RESULTS' and t_exch>=? and t_exch<? order by t_exch",
                              (t1530, d0.timestamp() + 86400)):
    if not s or s in seen or (fo and s not in fo):
        continue
    seen.append(s)
    print("\n  %s  %-11s GIR's reader: %s" % (dt.datetime.fromtimestamp(te, IST).strftime("%H:%M"), s, ver or "-"))
    al = q("tomorrow.db", "select t, text from alerts where day=? and sym=? and t>='15:30' and (text like '%RESULTS%') order by t", (day, s))
    shown = 0
    for t, tx in al:
        L = [x for x in (tx or "").split("\n") if x.strip()]
        num = [x for x in L if re.search(r"profit|revenue|ebitda|margin|₹[\d,.]+ ?cr|YoY|QoQ|brokers|estimate", x, re.I)]
        if num:
            for x in ([L[0]] + num)[:5]:
                print("     " + x[:170])
            shown = 1; break
    if not shown:
        print("     " + ((sub or "") + " · " + (det or ""))[:170])
    big = " ".join(x for _, x in al)
    py = re.search(r"profit[^·\n]*?([+-]\d+(?:\.\d+)?)% YoY", big, re.I); ry = re.search(r"revenue[^·\n]*?([+-]\d+(?:\.\d+)?)% YoY", big, re.I)
    if py or ry:
        p, r = float(py.group(1)) if py else None, float(ry.group(1)) if ry else None
        sc = (p or 0) + 0.5 * (r or 0)
        word = "looks BULLISH (profit and sales up)" if sc >= 10 and (p or 0) > 0 else "looks BEARISH (profit down)" if (p is not None and p < -5) else "MIXED / in line"
        print("     the numbers: profit %s YoY · revenue %s YoY -> %s" % (("%+.0f%%" % p) if p is not None else "?", ("%+.0f%%" % r) if r is not None else "?", word))
print("\n  (%d F&O results after 15:30) - tomorrow's opening price is the real verdict: the 09:08 pre-open shows it first" % len(seen))
print("\n=== 2 · F&O RESULTS TOMORROW (GIR's results desk)")
try:
    import resultsdesk
    v = resultsdesk.desk()
    tm = [r for r in v.get("rows") or [] if r.get("days") == 1 and not r.get("err")]
    if not tm:
        nxt = sorted({r.get("d") for r in v.get("rows") or [] if r.get("days") and r["days"] > 0})
        print("   none tomorrow%s" % ((" - the next: " + ", ".join(str(x) for x in nxt[:3])) if nxt else ""))
    for r in tm:
        print("\n  %-11s %s · brokers expect: %s" % (r["s"], r.get("q") or "", r.get("exp") or "no broker number found"))
        for x in (r.get("read") or [])[:4]:
            print("     · " + x[:170])
except Exception as ex:
    print("   results desk not read: %s" % ex)
PY
echo "=== done - nothing was changed"
