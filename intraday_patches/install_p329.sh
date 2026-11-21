#!/bin/bash
# PATCH 329 - THE LAST THREE FROM THE LIVE PAGE CHECK (Rama's file of 15 Nov 14:18, every patch to 328 installed - everything else passed on the
#   phone, iPad and laptop: no blinking under constant redraws, COCKPIT in the header, the iPad tabs, full screen, JUST REPORTED in words):
#   · the "also 18:07 📄 · 12:20 📄" line under an IMPORTANT alert: 11 px and readable (it was 10.5 px, faint - it came with tonight's data)
#   · JUST REPORTED: a change under 0.5% reads "flat" (it said "-0% vs last quarter")
#   · pagecheck.py also takes JUST REPORTED, so the next check covers it
#   Edits home.html, replaces resultsrecent.py (only 328's copy) and pagecheck.py (only 316's). Restarts the dashboard - after 15:35 (or: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
if grep -q "patch 329" $D/home.html && grep -q "+ 329" $D/resultsrecent.py; then echo "patch 329 - already in"; exit 0; fi
grep -q "patch 328" $D/home.html || { echo "patch 328 first"; exit 1; }
[ "$(sha256sum $D/resultsrecent.py | cut -c1-64)" = "fb9d19a6fffa27b665910c7ca2801a6f450c2b0adac5c208faea470d8bf847c3" ] || { echo "resultsrecent.py is not patch 328's copy - nothing done, send this to Claude"; exit 1; }
[ "$(sha256sum $D/pagecheck.py | cut -c1-64)" = "cefd468df4455f73fce85c877154efa3fd11a8f05ac3848293c4b431d2253bf4" ] || { echo "pagecheck.py is not patch 316's copy - nothing done, send this to Claude"; exit 1; }
F="home.html resultsrecent.py pagecheck.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/resultsrecent.py <<'PY_RR'
"""resultsrecent.py - patch 326 + 327 + 328 + 329 (the numbers in plain words, the main lines only, flat = under 0.5%): READ ONLY. F&O shares that REPORTED results in the last N days (Rama, 15 Nov: "you wiped out all the results - we
received PATANJALI, ABB and many more"). The RESULTS tab only listed the next 14 days; this adds the ones just out: the date (the results
calendar, chains.db), GIR's verdict and numbers (the exchange filing, filings.db), the filing link and when it was filed. Newest first."""
import os, json, time, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}


LBL = {"rev": "Revenue", "revenue": "Revenue", "sales": "Revenue", "pat": "Profit", "np": "Profit", "profit": "Profit", "net": "Profit",
       "ebitda": "EBITDA", "op": "Operating profit", "eps": "EPS"}


def plain(nums):
    """the filing's numbers (stored as JSON) -> "Revenue +44% vs last year · Profit -19% vs last year" (a text kept as it is)"""
    if not nums:
        return ""
    try:
        J = json.loads(nums)
    except Exception:
        return str(nums)[:200]
    if not isinstance(J, dict):
        return str(nums)[:200]
    out = []
    for k, v in J.items():
        if not isinstance(v, dict) or not isinstance(v.get("cur"), (int, float)):
            continue
        if k.lower() not in LBL:
            continue
        name, cur, yoy, qoq = LBL[k.lower()], v["cur"], v.get("yoy"), v.get("qoq")
        def pc(base):
            if not isinstance(base, (int, float)) or base == 0:
                return None
            if base < 0 <= cur:
                return "turned positive"
            if cur < 0 <= base:
                return "turned negative"
            ch = (cur / base - 1) * 100 * (1 if base > 0 else -1)
            return "flat" if abs(ch) < 0.5 else "%+.0f%%" % ch
        y, q = pc(yoy), pc(qoq)
        if y or q:
            out.append("%s %s" % (name, " · ".join(x for x in (y and "%s vs last year" % y, q and "%s vs last quarter" % q) if x)))
    return " · ".join(out[:3]) if out else "numbers filed - open the filing"


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def recent(days=7, now=None):
    if now is None and _C["v"] is not None and time.time() - _C["t"] < 120:
        return _C["v"]
    now = now or dt.datetime.now(IST)
    d0, d1 = str(now.date() - dt.timedelta(days=days)), str(now.date())
    rows, fo = {}, set()
    try:
        c = _ro("chains.db")
        fo = {r[0] for r in c.execute("select sym from fo_list")}
        for d, s in c.execute("select d, sym from results_cal where d>=? and d<=? order by d desc", (d0, d1)):
            if s in fo and s not in rows:
                rows[s] = {"s": s, "d": d}
        c.close()
    except Exception as ex:
        return {"rows": [], "err": "calendar: %s" % str(ex)[:80]}
    t0 = (now - dt.timedelta(days=days + 3)).timestamp()
    try:
        c = _ro("filings.db")
        cols = {r[1] for r in c.execute("pragma table_info(filings)")}
        want = [x for x in ("sym", "t_exch", "verdict", "nums", "link", "subject") if x in cols]
        q = "select %s from filings where kind='RESULTS' and t_exch>=? order by t_exch desc" % ",".join(want)
        for r in c.execute(q, (t0,)):
            f = dict(zip(want, r)); s = f.get("sym")
            if s not in fo:
                continue
            x = rows.setdefault(s, {"s": s, "d": str(dt.datetime.fromtimestamp(f.get("t_exch") or 0, IST).date())})
            if "filed" not in x or (not x.get("verdict") and f.get("verdict")):
                x["filed"] = dt.datetime.fromtimestamp(f.get("t_exch") or 0, IST).strftime("%a %d %b %H:%M")
                x["verdict"] = (f.get("verdict") or "").strip()
                x["nums"] = plain((f.get("nums") or "").strip())
                x["link"] = f.get("link") or ""
        c.close()
    except Exception:
        pass
    L = sorted(rows.values(), key=lambda x: (x["d"], x.get("filed", "")), reverse=True)
    L = [x for x in L if d0 <= x["d"] <= d1]
    v = {"t": time.time(), "days": days, "n": len(L), "rows": L}
    if now is None or True:
        _C.update({"t": time.time(), "v": v})
    return v


if __name__ == "__main__":
    v = recent()
    print("JUST REPORTED (last %d days): %d F&O shares" % (v["days"], v["n"]))
    for x in v["rows"]:
        print("  %s  %-12s %-9s %s" % (x["d"], x["s"], x.get("verdict") or "-", (x.get("nums") or "")[:90]))
PY_RR
cat > $W/pagecheck.py <<'PY_PC'
#!/usr/bin/env python3
"""pagecheck.py - patch 316 + 329 (JUST REPORTED too): READ ONLY. One file with GIR's pages and a snapshot of every feed they read, so Claude can open every screen at
phone and laptop sizes with GIR's real code and today's data (Rama, 15 Nov: "click each and every page and check how ugly it is").
  · a private copy of the page server on this machine's own loopback (127.0.0.1, a free port) - nothing outside is touched, nothing is written
    except data/pagecheck.json; the live stream and anything that writes (ledger, watch, ask) are skipped
  · positions, P&L, orders, trades, holdings and the trade ledger are removed; the page key never appears in the file
python3 pagecheck.py [SYM SYM ...]     (no names: tonight's top checklist shares + MANAPPURAM)
then on the phone (signed in): girtrader.com/pagecheck.json -> download -> attach it in the chat with Claude"""
import os, re, sys, json, time, threading, urllib.request, urllib.parse
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
OUT = os.path.join(D, "data", "pagecheck.json")
PRIV = re.compile(r"(^|_)(pos|positions|pnl|mypnl|myfo|my_fo|ledger|orders?|trades?|holdings?|account|acct|statement|funds|margin|tradebook)(_|$)", re.I)
PAGES = ["/", "/cockpit", "/checklist", "/today"]
FEEDS = ["/home", "/market", "/panels", "/three", "/cockpitdata", "/checklistdata", "/checklistlive", "/brief", "/wind", "/pushpull", "/flow",
         "/early", "/react", "/results", "/resultsrecent", "/signstate", "/ixhist?n=NIFTY", "/ixhist?n=BANKNIFTY", "/ixhist?n=SENSEX", "/ixhist?n=VIX",
         "/chart?sym=NIFTY50", "/hist?sym=NIFTY50&days=2", "/hist?sym=NIFTY50&days=3"]
PER_SYM = ["/focus?sym=%s", "/chk?sym=%s&peek=1", "/chart?sym=%s", "/live?sym=%s", "/oi?sym=%s", "/hist?sym=%s&days=30", "/hist?sym=%s&days=60",
           "/hist?sym=%s&days=120"]
CAP = 4_000_000                                          # one feed at most 4 MB in the file


def scrub(v):
    if isinstance(v, dict):
        return {k: scrub(x) for k, x in v.items() if not PRIV.search(str(k))}
    if isinstance(v, list):
        return [scrub(x) for x in v]
    return v


def syms_default():
    try:
        J = json.load(open(os.path.join(D, "data", "checklist.json")))
        L = [x["s"] for k in ("pe", "ce", "retest", "breakout") for x in (J.get(k) or [])]
    except Exception:
        L = []
    out = []
    for s in L + ["MANAPPURAM"]:
        if s not in out:
            out.append(s)
    return out[:5]


def main():
    import dashserve
    from http.server import HTTPServer
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    srv = HTTPServer(("127.0.0.1", 0), dashserve.H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % srv.server_address[1]
    syms = [s.upper() for s in sys.argv[1:] if re.fullmatch(r"[A-Za-z0-9&\-]{1,20}", s)] or syms_default()
    paths = PAGES + FEEDS + [p % urllib.parse.quote(s) for s in syms for p in PER_SYM]
    res, n_ok, size = {}, 0, 0
    for p in paths:
        url = base + p + ("&" if "?" in p else "?") + "k=" + urllib.parse.quote(tok)
        t0 = time.time()
        try:
            r = urllib.request.urlopen(url, timeout=40)
            st, ct, b = r.status, r.headers.get("Content-Type", ""), r.read(CAP + 1)
        except urllib.error.HTTPError as e:
            st, ct, b = e.code, e.headers.get("Content-Type", ""), e.read(2000)
        except Exception as e:
            st, ct, b = 0, "error", str(e)[:200].encode()
        txt = b[:CAP].decode("utf-8", "replace")
        if tok:
            txt = txt.replace(tok, "KEY")
        body = txt
        if "json" in ct:
            try:
                body = scrub(json.loads(txt))
            except Exception:
                pass
        res[p] = {"status": st, "ct": ct, "ms": int((time.time() - t0) * 1000), "cut": len(b) > CAP, "body": body}
        n_ok += st == 200
        size += len(txt)
        print("  %-32s %s  %7.0f KB" % (p[:32], st, len(txt) / 1024), flush=True)
    srv.shutdown()
    J = {"made": time.strftime("%Y-%m-%d %H:%M:%S"), "syms": syms, "feeds": res,
         "note": "GIR pages + feeds for a layout check - positions, P&L, orders and the ledger removed; the key replaced by KEY"}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    s = json.dumps(J, separators=(",", ":"), default=str)
    if tok:
        s = s.replace(tok, "KEY")
    open(OUT + ".tmp", "w", encoding="utf-8").write(s)
    os.replace(OUT + ".tmp", OUT)
    print("saved data/pagecheck.json · %d of %d read · %.1f MB · shares %s" % (n_ok, len(paths), len(s) / 1e6, ", ".join(syms)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PC
cat > $W/p329test.py <<'PY_T'
#!/usr/bin/env python3
"""p329test.py - JUST REPORTED: F&O shares with results in the last 7 days, GIR's verdict from the filing (made-up data, temp folder)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); shutil.copy(os.path.join(WK, "resultsrecent.py"), T); sys.path.insert(0, T)
import resultsrecent as R
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); NOW = dt.datetime(2026, 11, 15, 18, 0, tzinfo=IST)
OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.execute("create table results_cal(d text, sym text, purpose text)")
c.executemany("insert into fo_list values(?,1)", [("ALPHACO",), ("BETACO",), ("GAMMACO",), ("OLDCO",)])
c.executemany("insert into results_cal values(?,?,'Results')", [("2026-11-14", "ALPHACO"), ("2026-11-13", "BETACO"), ("2026-11-12", "GAMMACO"), ("2026-11-14", "NOTFO"), ("2026-11-01", "OLDCO"), ("2026-11-18", "BETACO")])
c.commit(); c.close()
f = sqlite3.connect(os.path.join(T, "filings.db"))
f.execute("create table filings(id integer primary key, key text, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int)")
ts = lambda d, h: int(dt.datetime(2026, 11, d, h, 0, tzinfo=IST).timestamp())
f.executemany("insert into filings(sym,t_exch,kind,verdict,nums,link) values(?,?,?,?,?,?)", [
    ("ALPHACO", ts(14, 13), "RESULTS", "MISS", "profit -19% · sales +15%", "https://x/a"), ("BETACO", ts(13, 16), "RESULTS", "BEAT", "profit +40%", "https://x/b"),
    ("BETACO", ts(13, 15), "RESULTS", "", "", ""), ("GAMMACO", ts(12, 17), "BOARD", "", "", ""), ("NOTFO", ts(14, 12), "RESULTS", "BEAT", "", "")])
f.commit(); f.close()
v = R.recent(7, NOW)
S = [x["s"] for x in v["rows"]]
chk("the last 7 days, F&O only, newest first: ALPHACO (14th) · BETACO (13th) · GAMMACO (12th) - not NOTFO, not OLDCO (1st), not BETACO's next date", S == ["ALPHACO", "BETACO", "GAMMACO"], v)
a = v["rows"][0]
chk("ALPHACO: GIR's verdict MISS, the numbers, the filing link, when filed", a.get("verdict") == "MISS" and "profit -19%" in a.get("nums", "") and a.get("link") == "https://x/a" and a.get("filed", "").startswith("Sat 14 Nov"), a)
chk("BETACO: the filing WITH the verdict is kept (BEAT), not the earlier one without", v["rows"][1].get("verdict") == "BEAT", v["rows"][1])
chk("GAMMACO: in the calendar, no results filing read - listed without a verdict", v["rows"][2].get("verdict", "") == "", v["rows"][2])
chk("the numbers in plain words: Revenue +44% vs last year · +20% vs last quarter", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92, "basis": "standalone"}}') == "Revenue +44% vs last year · +20% vs last quarter", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92}}'))
chk("a loss turned to profit is said so", "turned positive" in R.plain('{"pat": {"cur": 5, "qoq": -2, "yoy": -10}}'))
chk("only the main lines (revenue, profit) - not other income / expenses / null", R.plain('{"rev": {"cur": 6672.71, "qoq": 5556.4, "yoy": 4621.92}, "inc": null, "pat": {"cur": 970.72, "qoq": 721.54, "yoy": 245.22}, "oth": {"cur": 64.94, "yoy": 134.78}, "exp": 1}') == "Revenue +44% vs last year · +20% vs last quarter · Profit +296% vs last year · +35% vs last quarter")
chk("a change under 0.5% reads flat (not -0%)", "flat vs last quarter" in R.plain('{"rev": {"cur": 1132258.27, "qoq": 1133745.12, "yoy": 979883.55}}'))
os.remove(os.path.join(T, "filings.db")); R._C["v"] = None
chk("no filings.db: the calendar list still comes (no verdicts)", [x["s"] for x in R.recent(7, NOW)["rows"]] == ["ALPHACO", "BETACO", "GAMMACO"])
print("THE PATCH 329 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home329.html <<'ADD_H'
<style>/* patch 329: clarity - the "also 18:07 📄" line under an IMPORTANT alert (10.5 px, faint) */
html body a.im p.ol,html body a.im .ol{font-size:11px !important;color:#a3aebf !important;opacity:1 !important}
</style>
ADD_H
echo "=== test (made-up data, nothing sent)"
python3 $W/p329test.py $W > $W/t.out 2>&1; RC=$?; tail -2 $W/t.out; [ $RC -eq 0 ] || { cat $W/t.out; echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/resultsrecent.py $D/resultsrecent.py && cp $W/pagecheck.py $D/pagecheck.py && (cd $D && python3 -m py_compile resultsrecent.py pagecheck.py) || back
python3 - $D/home.html $W/home329.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if "patch 329" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", a + "\n</body>", 1)); print("  home.html: patch 329")
PY_EDIT
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
cd $D && python3 resultsrecent.py | head -4
echo "✅ patch 329 done - the small alert line readable, 'flat' instead of -0%, the page check covers JUST REPORTED. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
