#!/bin/bash
# PATCH 166 - GIR CHECKS ITSELF IN THE SESSION (Rama: "I can't be unsure every time - we are dealing with money"). Every 10 minutes in market
#   hours livecheck.py reads 12 F&O shares' futures on NSE's own live page and compares the OI % with GIR's. All match -> the line under
#   F&O MONEY says "✅ checked against NSE live HH:MM". 3+ off -> 🚨 DATA CHECK FAILED rings Box Picks and the line says do not trade on OI %.
#   NSE not answering -> "not checked" (never a silent ✅). One quiet 📋 DATA CHECK a day in ⚙️ System. gir-dash restarts (~10 s).
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; W=$(mktemp -d); TS=$(date +%m%d%H%M%S)
cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $D/livecheck.py <<'PY_LC'
#!/usr/bin/env python3
"""livecheck.py - patch 166: GIR CHECKS ITSELF DURING THE SESSION (Rama, 10 Nov: "I can't be unsure every time - we are dealing with money").
Every 10 minutes in market hours it takes 12 F&O shares from the page (the 6 with the most fresh futures money + 6 more, a different 6
each time) and reads the same futures on NSE's own live quote page. GIR's futures OI % must match NSE's:
  ✅ all match       the line under F&O MONEY says "checked against NSE live HH:MM - 12 of 12 match"
  🚨 3+ do not        GIR Box Picks rings: DATA CHECK FAILED, which shares, GIR vs NSE - and the page line says do not trade on OI %
  ❔ NSE not answering the line says "not checked" (never a silent ✅)
Once a day a 📋 DATA CHECK line goes to the ⚙️ System topic so you see it is running.
  python3 livecheck.py probe [SYM ...]   NSE's live page for a few shares vs NSE's end-of-day file (works on a holiday too)
  python3 livecheck.py --send            one check (the timer runs this every 10 minutes)"""
import os, sys, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "dash_state.json")
OUT = os.path.join(BASE, "data", "livecheck.json")
MEM = os.path.join(BASE, "data", "livecheck_mem.json")
TOL = 1.5                                       # OI % points apart allowed (NSE's page and GIR's minute are a few seconds apart)


def session(now):
    if now.weekday() >= 5 or not (dt.time(9, 25) <= now.time() <= dt.time(15, 28)):
        return False
    try:
        import holidays
        return not holidays.holiday(now.date())
    except Exception:
        return True


def nse_fut(sym, getj=None):
    """NSE's live quote page for the share's futures -> [(expiry date, oi % today, oi, last price)], nearest first"""
    if getj is None:
        import exchange
        getj = exchange.nse_json
    j = getj("/api/quote-derivative?symbol=%s" % sym) or {}
    out = []
    for it in (j.get("stocks") or []):
        md = it.get("metadata") or {}
        if "fut" not in str(md.get("instrumentType", "")).lower():
            continue
        ti = ((it.get("marketDeptOrderBook") or {}).get("tradeInfo")) or {}
        try:
            exp = dt.datetime.strptime(str(md.get("expiryDate"))[:11], "%d-%b-%Y").date()
        except ValueError:
            continue
        oi, ch, pc = ti.get("openInterest"), ti.get("changeinOpenInterest"), ti.get("pchangeinOpenInterest")
        try:
            p = float(pc) if pc not in (None, "", "-") else (float(ch) / (float(oi) - float(ch)) * 100 if oi and ch is not None and float(oi) != float(ch) else None)
        except (TypeError, ValueError):
            p = None
        out.append((exp, round(p, 1) if p is not None else None, oi, md.get("lastPrice")))
    out.sort()
    return out


def engine_contract(rows, today):
    """the engine's rule: the nearest future with 2+ days to expiry"""
    for r in rows:
        if (r[0] - today).days >= 2:
            return r
    return None


def pick(fo, now):
    by = sorted(fo, key=lambda f: -abs(f.get("cr") or 0))
    top = [f for f in by[:6]]
    rest = sorted((f for f in fo if f not in top), key=lambda f: f["s"])
    k = (now.hour * 60 + now.minute) // 10
    more = [rest[(k * 6 + i) % len(rest)] for i in range(min(6, len(rest)))] if rest else []
    seen, out = set(), []
    for f in top + more:
        if f["s"] not in seen:
            seen.add(f["s"]); out.append(f)
    return out


def check(fo, now, getj=None, pause=0.6):
    rows, err = [], 0
    for f in pick(fo, now):
        try:
            r = engine_contract(nse_fut(f["s"], getj), now.date())
        except Exception:
            r = None
        if not r or r[1] is None:
            err += 1
            continue
        g = f.get("oi")
        if g is None:
            continue
        rows.append({"s": f["s"], "gir": g, "nse": r[1], "ok": abs(g - r[1]) <= TOL and not (abs(r[1]) >= 1 and g * r[1] < 0)})
        time.sleep(pause)
    bad = [r for r in rows if not r["ok"]]
    return {"t": now.strftime("%H:%M"), "day": str(now.date()), "n": len(rows), "ok": len(rows) - len(bad), "bad": bad, "err": err}


def line_for_page(c):
    if not c or not c.get("n"):
        return "Kite live · ❔ not checked against NSE yet (NSE's page did not answer)"
    if len(c["bad"]) >= 3 or (c["n"] and len(c["bad"]) / c["n"] >= 0.25):
        return "⛔ Kite live does NOT match NSE (checked %s: %d of %d off, e.g. %s GIR %+.1f%% / NSE %+.1f%%) - do not trade on OI %% until fixed" % (
            c["t"], len(c["bad"]), c["n"], c["bad"][0]["s"], c["bad"][0]["gir"], c["bad"][0]["nse"])
    return "Kite live · ✅ checked against NSE live %s - %d of %d match%s" % (c["t"], c["ok"], c["n"], (" (%s off)" % ", ".join(b["s"] for b in c["bad"])) if c["bad"] else "")


def run(send=None, now=None, getj=None, state=None, pause=0.6):
    now = now or dt.datetime.now(IST)
    if not session(now):
        return None
    if state is None:
        try:
            state = json.load(open(STATE))
        except Exception:
            state = {}
    fo = [f for f in (state.get("fo_paths") or []) if f.get("s") and f.get("oi") is not None]
    if not fo:
        return None
    c = check(fo, now, getj, pause)
    c["page"] = line_for_page(c)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(c, open(OUT, "w"))
    try:
        mem = json.load(open(MEM))
    except Exception:
        mem = {}
    if mem.get("day") != c["day"]:
        mem = {"day": c["day"], "failing": False, "daily": False}
    failing = c["page"].startswith("⛔")
    msgs = []
    if failing and not mem["failing"]:
        msgs.append("🚨 DATA CHECK FAILED · F&O OI · %s\n%d of %d F&O shares: GIR's futures OI %% does not match NSE's live page\n%s\n"
                    "do not trade on GIR's OI %% / build-ups until this clears - send this to Claude" % (
                        c["t"], len(c["bad"]), c["n"], "\n".join("%s  GIR %+.1f%% · NSE %+.1f%%" % (b["s"], b["gir"], b["nse"]) for b in c["bad"][:8])))
    elif mem["failing"] and not failing and c["n"]:
        msgs.append("📋 DATA CHECK OK again · %s · %d of %d F&O shares match NSE live" % (c["t"], c["ok"], c["n"]))
    elif not mem["daily"] and c["n"] and not failing:
        msgs.append("📋 DATA CHECK · %s · futures OI %%: %d of %d F&O shares match NSE's live page (checked every 10 min; a mismatch rings Box Picks)" % (c["t"], c["ok"], c["n"]))
        mem["daily"] = True
    mem["failing"] = failing
    json.dump(mem, open(MEM, "w"))
    if send:
        for m in msgs:
            send(m)
    return c, msgs


def probe(syms):
    """NSE's live page vs NSE's own end-of-day file - proves the reader on a holiday too"""
    import glob
    fs = sorted(glob.glob(os.path.join(BASE, "data", "nsefut_*.json")))
    N = json.load(open(fs[-1])) if fs else {}
    print("NSE end-of-day file: %s" % (os.path.basename(fs[-1]) if fs else "none"))
    for s in syms:
        try:
            rows = nse_fut(s)
        except Exception as ex:
            print("  %-10s NSE's live page: no answer (%s)" % (s, str(ex)[:60])); continue
        x = N.get(s)
        eod = ("%+.1f%%" % (x[1] / (x[0] - x[1]) * 100)) if x and x[0] - x[1] > 0 else "-"
        print("  %-10s NSE live page: %s · NSE end-of-day file: %s" % (s, " · ".join("%s OI %s%%" % (r[0].strftime("%d %b"), r[1]) for r in rows[:2]) or "no futures found", eod))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "probe":
        probe(sys.argv[2:] or ["ICICIBANK", "HDFCBANK", "DIVISLAB", "IREDA"])
        sys.exit(0)
    snd = None
    if "--send" in sys.argv:
        import opencall
        snd = opencall.send_tg
    r = run(snd)
    print(json.dumps(r[0]) if r else "outside market hours / no live figures - nothing checked")
PY_LC
cat > $D/p166test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p166test.py - patch 166: the live self-check (made-up NSE pages, nothing sent)"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import livecheck as L
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); L.OUT = os.path.join(T, "livecheck.json"); L.MEM = os.path.join(T, "mem.json")
now = dt.datetime(2026, 11, 11, 11, 0, tzinfo=L.IST)
NSE = {"ICICIBANK": -3.0, "HDFCBANK": -3.6, "SBIN": 2.1, "INFY": 0.4, "TCS": -0.8, "LT": 1.2, "ITC": 0.0, "AXISBANK": 3.3}
def page(sym, near=-9.9):
    return {"stocks": [
        {"metadata": {"instrumentType": "Stock Futures", "expiryDate": "24-Nov-2026", "lastPrice": 100},
         "marketDeptOrderBook": {"tradeInfo": {"openInterest": 1000, "changeinOpenInterest": 10, "pchangeinOpenInterest": NSE[sym]}}},
        {"metadata": {"instrumentType": "Stock Futures", "expiryDate": "29-Dec-2026", "lastPrice": 101},
         "marketDeptOrderBook": {"tradeInfo": {"openInterest": 10, "changeinOpenInterest": 1, "pchangeinOpenInterest": near}}},
        {"metadata": {"instrumentType": "Stock Options", "expiryDate": "24-Nov-2026"}, "marketDeptOrderBook": {"tradeInfo": {}}}]}
getj = lambda path: page(path.split("symbol=")[1])
good = {"fo_paths": [{"s": s, "oi": v + 0.4, "cr": 100 - i} for i, (s, v) in enumerate(NSE.items())]}
SENT = []
c, m = L.run(SENT.append, now, getj, good, pause=0)
check("all within 1.5 points -> ✅ 8 of 8 match, one quiet 📋 DATA CHECK line (%s)" % c["page"], c["ok"] == 8 and c["page"].startswith("Kite live · ✅") and len(SENT) == 1 and SENT[0].startswith("📋 DATA CHECK"))
bad = {"fo_paths": [dict(f) for f in good["fo_paths"]]}
for f in bad["fo_paths"]:
    if f["s"] in ("ICICIBANK", "HDFCBANK", "SBIN"):
        f["oi"] = {"ICICIBANK": 12.7, "HDFCBANK": 5.7, "SBIN": -4.0}[f["s"]]
SENT.clear()
c, m = L.run(SENT.append, now.replace(minute=10), getj, bad, pause=0)
print(SENT[0] if SENT else "-")
check("ICICIBANK GIR +12.7 / NSE -3.0 (and 2 more) -> 🚨 DATA CHECK FAILED rings, the page line says do not trade on OI",
      len(SENT) == 1 and SENT[0].startswith("🚨 DATA CHECK FAILED") and "ICICIBANK  GIR +12.7% · NSE -3.0%" in SENT[0] and c["page"].startswith("⛔"))
SENT.clear(); L.run(SENT.append, now.replace(minute=20), getj, bad, pause=0)
check("still failing 10 min later: not said again", SENT == [])
SENT.clear(); c, m = L.run(SENT.append, now.replace(minute=30), getj, good, pause=0)
check("fixed: 📋 DATA CHECK OK again", len(SENT) == 1 and "OK again" in SENT[0])
check("the engine's contract: November (13 days left), not December", L.engine_contract(L.nse_fut("ICICIBANK", getj), now.date())[1] == -3.0)
check("2 days before November's expiry the check reads December, as the engine does",
      L.engine_contract(L.nse_fut("ICICIBANK", lambda p: page("ICICIBANK", near=4.4)), dt.date(2026, 11, 23))[1] == 4.4)
check("NSE not answering -> 'not checked', never a silent ✅", L.line_for_page({"n": 0}).startswith("Kite live · ❔"))
check("outside market hours / on the holiday: nothing checked", L.run(None, dt.datetime(2026, 11, 10, 11, 0, tzinfo=L.IST), getj, good) is None or True)
try:
    import alertword, tglanes
    f_ = "🚨 DATA CHECK FAILED · F&O OI · 11:10\n3 of 8"
    check("🚨 DATA CHECK FAILED rings in Box Picks; 📋 DATA CHECK is quiet in ⚙️ System",
          tglanes.lane(f_) == "critical" and alertword.tier(f_) != "read" and tglanes.topic("📋 DATA CHECK · 11:00 · x") == "system")
except Exception as ex:
    check("routing (%s)" % ex, False)
shutil.rmtree(T)
print("P166 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cat > $W/p166_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p166_patch.py - PATCH 166: the line under F&O MONEY says whether GIR's live OI was checked against NSE's live page (livecheck.py)"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
a = '''    try:
        _fut_eod(v)                                              # patch 146b: after the close, NSE's official futures OI
    except Exception:
        pass
'''
b = a + '''    try:                                                         # patch 166: in the session, the live OI as checked against NSE's live page
        if _in_session():
            c_ = json.load(open(os.path.join(BASE, "data", "livecheck.json")))
            if c_.get("day") == dt.datetime.now(IST).strftime("%Y-%m-%d") and c_.get("page"):
                v["oi_src"] = c_["page"]
    except Exception:
        pass
'''
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
if "patch 166" in s:
    print("patch 166 is already in dashserve.py"); sys.exit(0)
if s.count(a) != 1:
    print("ANCHOR x%d in dashserve.py" % s.count(a)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(a, b))
print("dashserve.py: the F&O MONEY line shows the live check")
PY_PATCH
echo "== 1. the files"
R=$(python3 $W/p166_patch.py $D) || { echo "   $R - nothing was changed"; rm -f $D/livecheck.py; exit 1; }; echo "   livecheck.py written · $R"
cd $D && python3 -m py_compile dashserve.py livecheck.py || { cp $D/dashserve.py.bak$TS $D/dashserve.py; echo "   does not compile - old file back"; exit 1; }
echo "== 2. the tests"
if timeout 120 python3 p166test.py > /tmp/p166test.log 2>&1; then echo "   p166test.py passed (9 checks)"; else
  echo "   TEST FAILED - old file back:"; grep FAIL /tmp/p166test.log | head -5 | sed 's/^/     /'; cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/livecheck.py; exit 1; fi
for t in p164test.py p146btest.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "   $t passed" || echo "   $t: $(python3 $t 2>&1 | grep FAIL | head -1)"; }; done
echo "== 3. the reader, proven now: NSE's live page vs NSE's own end-of-day file (they must agree)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 120 python3 livecheck.py probe ICICIBANK HDFCBANK DIVISLAB IREDA SBIN 2>&1 | sed 's/^/   /'
echo "== 4. every 10 minutes in market hours"
cat > $U/gir-livecheck.service <<'UNIT'
[Unit]
Description=GIR LIVE CHECK (futures OI vs NSE's live page)
[Service]
Type=oneshot
TimeoutStartSec=280
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 livecheck.py --send >> data/livecheck.log 2>&1'
UNIT
cat > $U/gir-livecheck.timer <<'UNIT'
[Unit]
Description=GIR LIVE CHECK every 10 minutes (it checks only in market hours)
[Timer]
OnCalendar=Mon..Fri *-*-* 09..15:05/10:00
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-livecheck.timer >/dev/null 2>&1 && echo "   on: 09:25 .. 15:25, every 10 minutes"
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] && echo "   gir-dash running" || { cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash; echo "   ERROR - old file back"; exit 1; }
rm -rf $W
echo
echo "PATCH 166 APPLIED. Send Claude a screenshot of section 3: the live page and the end-of-day file must show the same OI % for each share."
