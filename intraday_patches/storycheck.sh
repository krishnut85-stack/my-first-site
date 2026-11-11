#!/bin/bash
# storycheck.sh - DID GIR CATCH THIS STORY, AND WHEN? Read-only: nothing is changed or sent.
#   bash storycheck.sh "fertili|subsidy|cabinet" [YYYY-MM-DD]
# Looks for the words (a regular expression, any case) in everything GIR heard / read / sent that day, with the times:
#   📺 TV WATCH (data/tv.db) · 🏛 GOVT WATCH (PIB / RBI / SEBI) · the news reader (news.db) · the filings (filings.db) ·
#   what GIR sent or put on the page (tomorrow.db alerts) · what was held back from Telegram (data/quiet, the 🟡 digest spool) ·
#   the service logs · and the F&O shares of the sector now
D=/home/globalbot/intraday
RX="${1:-fertili|subsidy|cabinet}"
DAY="${2:-$(TZ=Asia/Kolkata date +%F)}"
cd $D || exit 1
echo "=== looking for /$RX/ on $DAY"
echo "=== services: tvwatch $(systemctl is-active gir-tvwatch 2>/dev/null) · govwatch timer $(systemctl is-active gir-govwatch.timer 2>/dev/null) · exchange $(systemctl is-active gir-exchange 2>/dev/null)"
python3 - "$RX" "$DAY" <<'PY'
import os, re, sys, json, sqlite3, datetime as dt
rx = re.compile(sys.argv[1], re.I); day = sys.argv[2]
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST).timestamp(); d1 = d0 + 86400
f = lambda x: dt.datetime.fromtimestamp(float(x), IST).strftime("%H:%M:%S") if x else "-"
def q(db, sql, a=()):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5); r = c.execute(sql, a).fetchall(); c.close(); return r
    except Exception as ex:
        print("   (%s not read: %s)" % (db, str(ex)[:60])); return []
def show(title, rows, n=8):
    print("=== %s: %d" % (title, len(rows)))
    for r in rows[:n]:
        print("   " + r)
# 1 TV
rows = q("data/tv.db", "select ts, ch, text from tv where ts>=? and ts<?", (d0, d1))
hrs = sorted({f(ts)[:2] for ts, ch, t in rows})
print("=== 📺 TV WATCH heard %d pieces of 20 s that day · hours: %s" % (len(rows), " ".join(hrs) or "none"))
show("📺 TV - the words were said on air", ["%s %s: %s" % (f(ts), ch, re.sub(r"\s+", " ", t or "")[:150]) for ts, ch, t in rows if rx.search(t or "")])
# 2 GOVT WATCH (its memory of the releases it saw)
gw = []
try:
    j = json.load(open("data/govwatch.json"))
    items = j.get("seen") if isinstance(j, dict) else j
    items = items.items() if isinstance(items, dict) else enumerate(items or [])
    for k, v in items:
        s = json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v
        if rx.search(str(k)) or rx.search(s):
            gw.append("%s %s" % (str(k)[:80], s[:150]))
except Exception as ex:
    print("   (govwatch.json not read: %s)" % str(ex)[:60])
show("🏛 GOVT WATCH - releases it saw (PIB / RBI / SEBI)", gw)
# 3 news reader
rows = q("news.db", "select t_pub, t_seen, sym, src, h, side, kind from items where t_seen>=? and t_seen<? order by t_seen", (d0, d1))
show("📰 the news reader - headlines read", ["published %s · GIR read %s · %s · %s · %s%s" % (f(a), f(b), s or "-", src or "", (h or "")[:110], " · side %+d" % sd if sd else "")
                                             for a, b, s, src, h, sd, k in rows if rx.search(h or "")], 12)
# 4 filings
rows = q("filings.db", "select t_exch, t_seen, sym, kind, subject, detail from filings where t_exch>=? and t_exch<? order by t_exch", (d0, d1))
show("📄 filings", ["filed %s · seen %s · %s %s · %s" % (f(a), f(b), s, k, ((sj or "") + " " + (dd or ""))[:110]) for a, b, s, k, sj, dd in rows if rx.search((sj or "") + " " + (dd or ""))])
# 5 what GIR sent / put on the page
rows = q("tomorrow.db", "select t, kind, sym, text from alerts where day=? order by t", (day,))
show("🔔 GIR ALERTS (Telegram + page) with the words", ["%s %s %s · %s" % (t[:8], k or "", s or "", (x or "").split("\n")[0][:120]) for t, k, s, x in rows if rx.search(x or "")], 12)
# 6 held back from Telegram (patch 192 / 205)
qp = "data/quiet/%s.log" % day
ql = [l.strip() for l in open(qp, encoding="utf-8", errors="ignore")] if os.path.exists(qp) else []
show("🟡 HELD BACK from Telegram (page + 15-min digest only)", [l[:170] for l in ql if rx.search(l)])
sp = "data/digest_spool.jsonl"
sl = [json.loads(l) for l in open(sp, encoding="utf-8", errors="ignore") if l.strip()] if os.path.exists(sp) else []
show("🟡 still waiting in the digest spool", ["%s %s" % (f(x.get("t")), (x.get("text") or "").split("\n")[0][:140]) for x in sl if rx.search(x.get("text") or "")])
# 7 the F&O shares now (fertiliser / agri)
try:
    qq = (json.load(open("quotes_live.json")) or {}).get("q") or {}
    print("=== the agri / fertiliser F&O shares now: " + " · ".join("%s %+.2f%%" % (s, qq[s][1]) for s in ("COROMANDEL", "CHAMBLFERT", "UPL", "PIIND", "DEEPAKFERT", "GNFC", "RCF") if s in qq and len(qq[s]) > 1 and qq[s][1] is not None))
except Exception as ex:
    print("   (quotes not read: %s)" % ex)
PY
echo "=== the service logs that day with the words"
journalctl --since "$DAY 00:00" --until "$DAY 23:59" --no-pager 2>/dev/null | grep -iE "$RX" | grep -iE "govwatch|tvwatch|shock|news|exchange" | tail -n 12 | cut -c1-200 | sed 's/^/   /'
ls $D/data/govwatch*.log $D/data/govwatch*.txt 2>/dev/null | head -2 | while read f; do echo "=== $f"; grep -iE "$RX" "$f" | tail -n 6 | cut -c1-200 | sed 's/^/   /'; done
echo "=== done (nothing changed)"
