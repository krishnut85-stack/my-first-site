#!/bin/bash
# newsaudit.sh - EVERY NEWS LIST GIR SHOWS, CHECKED (Rama, 14 Nov: "I am afraid whether you follow up and code correctly"). READ ONLY - nothing is
#   changed or sent. For the last 24 hours (or: bash newsaudit.sh 48):
#   1 Telegram + the page's alert board (tomorrow.db): every news line - OLD (published 48 h+ before GIR sent it), REPEAT (the same story again),
#     UNREADABLE (scanned-PDF letters / a letterhead), ROUND-UP (a many-stock list sent as one company's news)
#   2 the NEWS tab (news.db): the same checks, and how late GIR read each item (published -> read)
#   3 the TOMORROW tab's morning brief, built now: what it shows
#   Every check prints its count and up to 5 examples. All zero = clean.
D=/home/globalbot/intraday; HRS="${1:-24}"
cd $D || exit 1
python3 - "$HRS" <<'PY'
import os, re, sys, sqlite3, datetime as dt
sys.path.insert(0, ".")
import newsclean as NC
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); now = dt.datetime.now(IST); H = float(sys.argv[1]); t0 = now.timestamp() - H * 3600
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
def show(lab, xs):
    print("   %-58s %4d%s" % (lab, len(xs), "  ✅" if not xs else "  ⚠"))
    for x in xs[:5]:
        print("       · " + x[:150])
NEWS = re.compile(r"GOVT WATCH|CRITICAL GOVT|SHOCK WATCH|NEWS SHOCK|THE REASON|MACRO|📰|REGULATOR|· REG\b")
print("=== 1 · TELEGRAM / THE ALERT BOARD (tomorrow.db) · last %g h" % H)
try:
    c = ro("tomorrow.db")
    rows = c.execute("select day, t, sym, text from alerts where day >= ? order by day, t", (str((now - dt.timedelta(hours=H)).date()),)).fetchall(); c.close()
except Exception as ex:
    rows = []; print("   (tomorrow.db: %s)" % ex)
seen, rep, junk, rnd, old, n = {}, [], [], [], [], 0
for day, t, sym, tx in rows:
    L = [x for x in (tx or "").split("\n") if x.strip()]
    if not L or not NEWS.search(L[0]):
        continue
    try:
        ts = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    if ts < t0:
        continue
    n += 1
    body = L[1] if len(L) > 1 else L[0]
    lab = "%s %s %s · %s" % (day[5:], str(t)[:5], sym or "", body)
    m = re.search(r"(\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* (20\d\d)", tx or "")
    if m:
        try:
            d0 = dt.datetime.strptime(" ".join(m.groups()), "%d %b %Y").replace(tzinfo=IST)
            if (dt.datetime.fromtimestamp(ts, IST) - d0).days >= 3 and "dated" not in (tx or "").lower():
                old.append("%s   (the text is dated %s)" % (lab, d0.strftime("%d %b")))
        except ValueError:
            pass
    k = NC.story_key(sym or "MARKET", L[0].split("·")[0].strip()[:20], body)
    if k in seen and ts - seen[k] < 6 * 3600:
        rep.append(lab)
    seen[k] = ts
    if NC.junk(body) or NC.letterhead(body):
        junk.append(lab)
    if NC.roundup(body) and "GOVT" not in L[0]:
        rnd.append(lab)
print("   news lines checked: %d" % n)
show("OLD (the story's own date 3+ days before GIR sent it)", old)
show("REPEAT (the same story again within 6 h)", rep)
show("UNREADABLE (scanned-PDF letters / a letterhead)", junk)
show("ROUND-UP (a many-stock list sent as one company's news)", rnd)
print("\n=== 2 · THE NEWS TAB (news.db) · last %g h" % H)
try:
    c = ro("news.db")
    R = c.execute("select sym, src, domain, t_pub, t_seen, h from items where t_seen >= ? order by t_seen", (t0,)).fetchall(); c.close()
except Exception as ex:
    R = []; print("   (news.db: %s)" % ex)
old2 = ["%s %s · %s   (published %s, read %s)" % (s, dm or src, h, dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %H:%M"), dt.datetime.fromtimestamp(tse, IST).strftime("%d %b %H:%M"))
        for s, src, dm, tp, tse, h in R if tp and tse and tse - tp > 48 * 3600]
junk2 = ["%s · %s" % (s, h) for s, src, dm, tp, tse, h in R if NC.junk(h) or NC.letterhead(h)]
rnd2 = ["%s · %s" % (s, h) for s, src, dm, tp, tse, h in R if NC.roundup(h)]
lag = sorted(tse - tp for s, src, dm, tp, tse, h in R if tp and tse and 0 <= tse - tp < 48 * 3600)
print("   items read: %d%s" % (len(R), (" · read after publishing: median %d min, 9 of 10 within %d min" % (lag[len(lag) // 2] / 60, lag[int(len(lag) * 0.9)] / 60)) if lag else ""))
show("OLD (read 48 h+ after it was published)", old2)
show("UNREADABLE", junk2)
show("ROUND-UP (kept in the share's news - shown, never rung)", rnd2)
print("\n=== 3 · THE TOMORROW TAB - the morning brief as it is built now")
try:
    import morningbrief
    txt = morningbrief.build(now)[0]
    print("\n".join("   " + x for x in txt.split("\n")[:40]))
except Exception as ex:
    print("   (morningbrief: %s)" % ex)
PY
