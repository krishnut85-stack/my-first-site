#!/bin/bash
# PATCH 176 - EARLIER ALERTS:
#   1. 🚨 RESULTS FILED - one line to Box Picks the moment GIR sees a results filing (before: the numbers were read first, 1-3 minutes);
#      the BEAT / MISS verdict and the strike follow as before
#   2. 🌅 PRE-OPEN at 09:08 IST - NSE's pre-open price of every F&O share beside the news since the last close: a 2%+ gap with news,
#      a 4%+ gap with none - 7 minutes before the open; the 09:20 opening call still decides
#   3. the shock-day report goes to ⚙️ System (it went to Box Picks)
#   The exchange reader restarts (a few seconds); the trading engine is not touched.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
for f in exchange.py tglanes.py circuits.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
cat > $D/preopen.py <<'PREOPEN_PY'
#!/usr/bin/env python3
"""preopen.py - patch 176: 🌅 PRE-OPEN at 09:08 IST on NSE trading days - 7 minutes before the market opens.
NSE's pre-open session (09:00-09:08) fixes each share's opening price (the IEP). GIR reads it for every F&O share and puts it beside
the news since the last close (NSE filings: results / regulator / management / orders / deals, ⚠️ SHOCK WATCH from the news, TV and
regulator pages):
  * a 2%+ gap WITH news behind it   - the share, the gap, the price it opens at, the news
  * a 4%+ gap with NO news found    - said too (money moving on something not yet public)
One message to GIR Box Picks (it rings). The 3-year study: a gap that the first 5 minutes confirm paid +0.53% a trade - so the line
says what to wait for: the 🌅 OPENING CALL at 09:20 decides.
  python3 preopen.py              print it now (nothing sent)        python3 preopen.py --send     send it"""
import os, re, sys, json, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NEWS_KINDS = ("RESULTS", "REG", "MGMT", "ORDER", "BOARD", "RATING", "SALES")
NAME = {"RESULTS": "RESULTS", "REG": "REGULATOR", "MGMT": "MANAGEMENT", "ORDER": "ORDER", "BOARD": "DEAL / BOARD", "RATING": "RATING", "SALES": "SALES"}
GAP_NEWS, GAP_BARE = 2.0, 4.0


def holiday(d):
    try:
        import holidays
        return bool(holidays.holiday(d))
    except Exception:
        return d.weekday() >= 5


def last_close(now):
    d = now.date() - dt.timedelta(days=1)
    while holiday(d):
        d -= dt.timedelta(days=1)
    return dt.datetime.combine(d, dt.time(15, 30), IST)


def _f(x):
    try:
        return float(str(x).replace(",", ""))
    except (TypeError, ValueError):
        return None


def nse_preopen(getj=None):
    """-> {sym: (iep, prev close, gap %, final qty)} for the F&O shares in NSE's pre-open"""
    if getj is None:
        import exchange
        getj = exchange.nse_json
    j = getj("/api/market-data-pre-open?key=FO") or {}
    out = {}
    for it in (j.get("data") if isinstance(j, dict) else j) or []:
        m = (it or {}).get("metadata") or {}
        po = ((it or {}).get("detail") or {}).get("preOpenMarket") or {}
        s = str(m.get("symbol") or "").upper()
        iep = _f(m.get("iep")) or _f(po.get("IEP")) or _f(m.get("lastPrice"))
        pc = _f(m.get("previousClose"))
        g = _f(m.get("pChange"))
        if g is None and iep and pc:
            g = (iep / pc - 1) * 100
        if s and iep and g is not None:
            out[s] = (iep, pc, g, _f(m.get("finalQuantity")) or _f(po.get("totalTradedVolume")) or 0)
    return out


def overnight_news(start, now, base=None):
    """{sym: [(epoch, kind, side, text)]} - NSE filings + ⚠️ SHOCK WATCH lines since the last close"""
    b = base or BASE
    out = {}
    p = os.path.join(b, "filings.db")
    if os.path.exists(p):
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=5)
        for s, te, k, sd, subj, det, v in c.execute("select sym, t_exch, kind, side, subject, detail, verdict from filings where t_exch between ? and ? and kind in (%s) order by t_exch"
                                                    % ",".join("?" * len(NEWS_KINDS)), (start.timestamp(), now.timestamp()) + NEWS_KINDS):
            vv = (v or "").upper()
            if k == "RESULTS" and vv in ("BEAT", "BIG BEAT"):
                sd = 1
            elif k == "RESULTS" and vv in ("MISS", "BIG MISS"):
                sd = -1
            txt = ("%s%s" % ((vv + " · ") if k == "RESULTS" and vv and vv not in ("XBRL NOT UP YET", "NUMBERS NOT READ") else "",
                             re.sub(r"\s+", " ", (det or subj or "")).strip()))[:90]
            out.setdefault(s, []).append((te, NAME.get(k, k), sd or 0, txt))
        c.close()
    p = os.path.join(b, "tomorrow.db")
    if os.path.exists(p):
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=5)
        for day, t, text in c.execute("select day, t, text from alerts where (day = ? and t >= '15:30') or (day > ? and day <= ?)",
                                      (str(start.date()), str(start.date()), str(now.date()))):
            L = [x for x in (text or "").split("\n") if x.strip()]
            m = re.match(r"⚠️ SHOCK WATCH · ([▲▼]) ([A-Z0-9&-]+) · ([A-Z /]+?) ·", L[0] if L else "")
            if m:
                te = dt.datetime.fromisoformat("%s %s" % (day, t[:8])).replace(tzinfo=IST).timestamp()
                out.setdefault(m.group(2), []).append((te, m.group(3).strip(), -1 if m.group(1) == "▼" else 1, (L[1] if len(L) > 1 else "")[:90]))
        c.close()
    return out


def build(now=None, getj=None, base=None):
    now = now or dt.datetime.now(IST)
    po = nse_preopen(getj)
    if not po:
        return None, "NSE's pre-open list did not answer"
    news = overnight_news(last_close(now), now, base)
    rows = []
    for s, (iep, pc, g, q) in po.items():
        nw = news.get(s) or []
        if nw and abs(g) >= GAP_NEWS:
            agree = [x for x in nw if x[2] * g > 0]
            top = sorted(agree or nw, key=lambda x: -x[0])[0]
            rows.append((0 if agree else 1, -abs(g), s, iep, pc, g, top, bool(agree)))
        elif not nw and abs(g) >= GAP_BARE:
            rows.append((2, -abs(g), s, iep, pc, g, None, False))
    rows.sort()
    when = lambda t: dt.datetime.fromtimestamp(t, IST).strftime("%a %H:%M")
    L = ["🌅 PRE-OPEN %s · F&O shares opening with a gap · %d with news, %d without" % (now.strftime("%H:%M"), sum(1 for r in rows if r[6]), sum(1 for r in rows if not r[6]))]
    if not rows:
        L.append("no F&O share opens 2%+ away with news, none 4%+ without - a quiet open")
    for _o, _g, s, iep, pc, g, top, agree in rows[:10]:
        a = "▲" if g > 0 else "▼"
        L.append("")
        L.append("%s %s %+.1f%% · opens ₹%s (closed ₹%s)" % (a, s, g, format(round(iep, 2), ","), format(round(pc, 2), ",") if pc else "?"))
        if top:
            L.append("   %s%s: %s (%s)" % (top[1], "" if agree else " - the news points the OTHER way", top[3], when(top[0])))
        else:
            L.append("   no news found since the close - money moving on something not public yet")
        L.append("   %s side only if the first 5 minutes confirm - the 🌅 OPENING CALL at 09:20 decides" % ("CE" if g > 0 else "PE"))
    if len(rows) > 10:
        L.append("\n… %d more on GIR" % (len(rows) - 10))
    return "\n".join(L)[:3900], rows


if __name__ == "__main__":
    now = dt.datetime.now(IST)
    if holiday(now.date()) and "--force" not in sys.argv:
        print("NSE holiday / weekend - no pre-open"); sys.exit(0)
    txt, info = build(now)
    print(txt or info)
    if txt and "--send" in sys.argv:
        import opencall
        opencall.send_tg(txt)
PREOPEN_PY
cat > $D/p176test.py <<'P176TEST_PY'
#!/usr/bin/env python3
"""p176test.py - patch 176: 🌅 PRE-OPEN at 09:08 and the instant RESULTS FILED line (made-up NSE answers, nothing sent)"""
import os, sys, types, sqlite3, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
H = types.ModuleType("holidays")
H.holiday = lambda d: "weekend" if d.weekday() >= 5 else ("Diwali" if str(d) == "2026-11-10" else None)
sys.modules["holidays"] = H
import preopen as P
ok = True
def check(n, g):
    global ok
    print(("  ok   " if g else "  FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); IST = P.IST
ts = lambda d, h, m: dt.datetime(2026, 11, d, h, m, tzinfo=IST).timestamp()
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(sym text, t_exch int, kind text, side int, subject text, detail text, verdict text)")
c.execute("insert into filings values('COCHINSHIP',?,'RESULTS',0,'Outcome of Board Meeting','Q2 results','BIG MISS')", (ts(10, 14, 27),))
c.execute("insert into filings values('LT',?,'ORDER',1,'Order','L&T bags Rs 9,000 crore order','')", (ts(9, 18, 0),))
c.commit(); c.close()
def getj(path):
    row = lambda s, pc, iep: {"metadata": {"symbol": s, "previousClose": pc, "iep": iep, "pChange": round((iep / pc - 1) * 100, 2), "finalQuantity": 1000}}
    return {"data": [row("COCHINSHIP", 1289.86, 1188.0), row("LT", 3600, 3690), row("XYZ", 100, 105.5), row("SBIN", 800, 801)]}
txt, rows = P.build(dt.datetime(2026, 11, 11, 9, 8, tzinfo=IST), getj, T)
print(txt)
check("Wed 09:08 after Tuesday's holiday: COCHINSHIP -7.9% with its BIG MISS (filed Tue 14:27)", "▼ COCHINSHIP -7.9%" in txt and "BIG MISS" in txt and "Tue 14:27" in txt)
check("LT +2.5% with its ₹9,000 cr order (Mon evening)", "▲ LT +2.5%" in txt and "9,000" in txt)
check("XYZ +5.5% with no news: said as 'not public yet'", "▲ XYZ +5.5%" in txt and "not public yet" in txt)
check("SBIN +0.1%: not in it", "SBIN" not in txt)
check("each says the 09:20 OPENING CALL decides", txt.count("09:20 decides") == 3)
import tglanes, alertword
check("🌅 PRE-OPEN rings in Box Picks", tglanes.lane(txt) == "critical")
import exchange as X
sent = []
sys.modules["engine2"] = types.SimpleNamespace(tg_fo=lambda m: sent.append(m) or True)
f = {"sym": "COCHINSHIP", "t_exch": ts(10, 14, 27), "subject": "Outcome of Board Meeting - financial results"}
X._quick_results(f, 12); X._quick_results(f, 40)
check("results filed -> '🚨 RESULTS FILED · COCHINSHIP' at once, once only", len(sent) == 1 and sent[0].startswith("🚨 RESULTS FILED · COCHINSHIP") and "seen in 12s" in sent[0])
check("it rings (critical)", tglanes.lane(sent[0]) == "critical")
shutil.rmtree(T)
print("P176 TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
P176TEST_PY
cat > $W/p176_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p176_patch.py - PATCH 176: (1) exchange.py - a results filing is said the moment it is seen ("🚨 RESULTS FILED"), the numbers follow;
(2) tglanes.py - 🌅 PRE-OPEN rings in GIR Box Picks; (3) circuits.py - the shock-day report goes to ⚙️ System (📋, not 🧱 = Box Picks).
Usage: python3 p176_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
QUICK = '''_QUICK = {}


def _quick_results(f, lag):
    """patch 176: one line the moment a results filing is seen - reading the numbers takes 1-3 minutes more"""
    s = f["sym"]
    if time.time() - _QUICK.get(s, 0) < 1800:
        return False
    _QUICK[s] = time.time()
    t = dt.datetime.fromtimestamp(f["t_exch"], IST).strftime("%H:%M:%S")
    try:
        import engine2
        engine2.tg_fo("🚨 RESULTS FILED · %s · NSE %s (seen in %ds)\\n%s\\nreading the numbers now - the BEAT / MISS verdict and the strike follow in 1-3 minutes"
                      % (s, t, lag, (f.get("subject") or "")[:120]))
        jlog("   quick results line sent: %s" % s)
        return True
    except Exception as ex:
        log("quick results: %s" % str(ex)[:80])
        return False


def process(items, con, fo, prime=False):'''
E = {
 "exchange.py": [('def process(items, con, fo, prime=False):', QUICK),
                 ('        kind, side = classify(f["subject"], f["detail"])\n        if not prime and kind != "ROUTINE":',
                  '        kind, side = classify(f["subject"], f["detail"])\n'
                  '        if kind == "RESULTS" and not prime and now - f["t_exch"] < 1800:          # patch 176: say it at once - the numbers follow\n'
                  '            _quick_results(f, int(now - f["t_exch"]))\n'
                  '        if not prime and kind != "ROUTINE":')],
 "tglanes.py": [('CRIT_RE = re.compile(r"', 'CRIT_RE = re.compile(r"PRE-OPEN|')],
 "circuits.py": [('L = ["🧱 SHOCK DAYS', 'L = ["📋 SHOCK DAYS')],
}
done = []
for fn, eds in E.items():
    p = os.path.join(D, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    if "patch 176" in s or ("PRE-OPEN|" in s and fn == "tglanes.py") or ("📋 SHOCK DAYS" in s and fn == "circuits.py"):
        continue
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), fn, a[:60])); sys.exit(1)
        s = s.replace(a, b, 1)
    open(p, "w", encoding="utf-8").write(s); done.append(fn)
print("patched: %s" % (", ".join(done) or "nothing new"))
PY_PATCH
back() { for f in exchange.py tglanes.py circuits.py; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; rm -f $D/preopen.py; }
echo "== 1. the patch"
R=$(python3 $W/p176_patch.py $D) || { echo "   $R"; back; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile exchange.py tglanes.py preopen.py || { back; echo "   does not compile - undone"; exit 1; }
echo "== 2. the tests"
for t in p176test.py p169test.py p168test.py; do [ -f $t ] || continue
  timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "   $t passed" || { echo "   $t FAILED - undone:"; grep -E "FAIL|Error" /tmp/$t.log | head -4 | sed 's/^/     /'; back; exit 1; }
done
echo "== 3. NSE's pre-open list from the server (today it shows the last session's - a check that it answers)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 60 python3 -c "import preopen; print('   %d F&O shares in NSE pre-open' % len(preopen.nse_preopen()))" 2>&1 | tail -1
echo "== 4. the timer and the exchange reader"
cat > $U/gir-preopen.service <<'UNIT'
[Unit]
Description=GIR PRE-OPEN 09:08 (gaps of F&O shares + the news behind them)
[Service]
Type=oneshot
TimeoutStartSec=120
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 preopen.py --send >> data/preopen.log 2>&1'
UNIT
cat > $U/gir-preopen.timer <<'UNIT'
[Unit]
Description=GIR PRE-OPEN 09:08 IST Monday-Friday (it skips NSE holidays itself)
[Timer]
OnCalendar=Mon..Fri *-*-* 09:08:15 Asia/Kolkata
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-preopen.timer >/dev/null 2>&1 && echo "   🌅 PRE-OPEN: every trading day 09:08 IST"
systemctl restart gir-exchange 2>/dev/null && sleep 4 && [ "$(systemctl is-active gir-exchange)" = "active" ] && echo "   exchange reader restarted - results are said the moment they are filed" \
  || { back; systemctl restart gir-exchange 2>/dev/null; echo "   the exchange reader did not come back - undone; send this to Claude"; exit 1; }
rm -rf $W
echo
echo "PATCH 176 APPLIED. Tomorrow: 08:30 ☀️ brief · 09:08 🌅 pre-open · 09:12 / 09:20 opening call."
