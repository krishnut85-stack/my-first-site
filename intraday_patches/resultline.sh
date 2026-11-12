#!/bin/bash
# resultline.sh - READ ONLY. One share's day, minute by minute: when the RESULTS were filed (exchange time) and when GIR read them, every
# GIR alert with its time, the news GIR read, and when the price really turned (5-min candles, up or down). Changes nothing.
#   bash resultline.sh PAGEIND [YYYY-MM-DD]
D=/home/globalbot/intraday; S=${1:-PAGEIND}; DAY=${2:-$(TZ=Asia/Kolkata date +%F)}
cd $D || exit 1
python3 - "$S" "$DAY" <<'PY'
import sys, json, sqlite3, datetime as dt
s, day = sys.argv[1].upper(), sys.argv[2]
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
d0 = dt.datetime.fromisoformat(day).replace(tzinfo=IST).timestamp()
f = lambda x: dt.datetime.fromtimestamp(float(x), IST).strftime("%d %b %H:%M:%S") if x else "-"
bt = lambda i: "%02d:%02d" % divmod(9 * 60 + 15 + 5 * i, 60)


def q(db, sql, a=()):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5); r = c.execute(sql, a).fetchall(); c.close(); return r
    except Exception as ex:
        print("   (%s: %s)" % (db, str(ex)[:70])); return []


print("=== 1 · THE COMPANY'S FILINGS (exchange time -> GIR saw it), the day before to today")
for te, ts, k, sd, sub, det, ver in q("filings.db", "select t_exch, t_seen, kind, side, subject, detail, verdict from filings where sym=? and t_exch>=? and t_exch<? order by t_exch",
                                      (s, d0 - 86400 * 1.5, d0 + 86400)):
    print("   filed %s · GIR saw %s (%s) · %s %s · %s%s" % (f(te), f(ts), ("%.0f min later" % ((ts - te) / 60)) if te and ts else "?", k or "", ("▲" if (sd or 0) > 0 else "▼" if (sd or 0) < 0 else ""),
                                                        (sub or "")[:70], (" · " + (ver or "")[:60]) if ver else ""))
print("=== 2 · THE PRICE (5-min candles, from yesterday's close)")
try:
    x = json.load(open("charts.json")).get(s) or {}
    pc, O, H, L, C, V = x["pc"], x["o"], x["h"], x["l"], x["c"], x["v"]
    n = len([c for c in C if c])
    up, dn = {}, {}
    for i in range(len(C)):
        if not C[i]:
            continue
        for lv in (1, 2, 3, 5, 7, 10):
            if lv not in up and H[i] and (H[i] / pc - 1) * 100 >= lv:
                up[lv] = bt(i)
            if lv not in dn and L[i] and (L[i] / pc - 1) * 100 <= -lv:
                dn[lv] = bt(i)
    hi = max(range(len(H)), key=lambda i: H[i] or 0); lo = min(range(len(L)), key=lambda i: L[i] or 1e18)
    vs = sorted([v for v in V if v]); med = vs[len(vs) // 2] if vs else 1
    last = next((c for c in reversed(C) if c), None)
    print("   open %+.1f%% · day high %+.1f%% at %s · day low %+.1f%% at %s · close %+.1f%%" % ((O[0] / pc - 1) * 100 if O and O[0] else 0, (H[hi] / pc - 1) * 100, bt(hi),
                                                                                       (L[lo] / pc - 1) * 100, bt(lo), (last / pc - 1) * 100 if last else 0))
    print("   down: crossed -1%% %s · -2%% %s · -3%% %s · -5%% %s · -7%% %s · -10%% %s" % tuple(dn.get(k, "-") for k in (1, 2, 3, 5, 7, 10)))
    print("   up:   crossed +1%% %s · +2%% %s · +3%% %s · +5%% %s · +7%% %s · +10%% %s" % tuple(up.get(k, "-") for k in (1, 2, 3, 5, 7, 10)))
    print("   the candles where it moved (volume 2x+ normal or a 1%+ candle):")
    for i in range(len(C)):
        if not C[i] or not O[i]:
            continue
        mv = (C[i] / O[i] - 1) * 100
        if (V[i] or 0) >= 2 * med or abs(mv) >= 1:
            print("     %s  close %+6.1f%%  this candle %+5.1f%%  volume %4.1fx" % (bt(i), (C[i] / pc - 1) * 100, mv, (V[i] or 0) / med))
except Exception as ex:
    print("   candles not read: %s" % ex)
print("=== 3 · EVERY GIR ALERT ON %s THAT DAY" % s)
rows = q("tomorrow.db", "select t, text from alerts where day=? and sym=? order by t", (day, s))
for t, tx in rows:
    print("   %s  %s" % (str(t)[:8], (tx or "").split("\n")[0][:120]))
print("   (%d alerts)" % len(rows))
print("=== 4 · THE NEWS GIR READ ON %s (published -> GIR read)" % s)
cols = [r[1] for r in q("news.db", "pragma table_info(items)")]
sc = next((c for c in cols if c in ("sym", "s", "symbol")), None); hc = next((c for c in cols if c in ("h", "title", "head", "headline")), None)
if sc and hc and "t_pub" in cols and "t_seen" in cols:
    for tp, tsn, h in q("news.db", "select t_pub, t_seen, %s from items where %s=? and t_seen>=? and t_seen<? order by t_pub" % (hc, sc), (s, d0 - 43200, d0 + 86400))[:15]:
        print("   published %s · GIR read %s · %s" % (f(tp), f(tsn), (h or "")[:100]))
else:
    print("   (news.db columns: %s)" % ", ".join(cols))
PY
echo "=== done - nothing was changed"
