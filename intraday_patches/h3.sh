#!/bin/bash
# PATCH 144 - THE 3-YEAR STUDY, STEP 1: THE DOWNLOAD. A 1-minute check of each source (Kite's daily and 5-min candles 3 years
#   back, NSE's daily F&O file in both its formats, NSE's results history), then - if all answer - the download starts in the
#   background (about 1-2 hours, ~1-2 GB under data/h3/). It stops by itself at 08:40 on a weekday and carries on when started
#   again. Nothing in GIR changes; no service restarted.   bash h3.sh            check + start
#   progress:  python3 /home/globalbot/intraday/hist3y.py status   ·   tail /home/globalbot/intraday/data/h3/download.log
D=/home/globalbot/intraday
FREE=$(df -Pm $D | awk 'NR==2{print $4}'); [ "$FREE" -gt 3000 ] || { echo "only ${FREE} MB free - need 3 GB"; exit 1; }
cat > $D/hist3y.py <<'PY_H3'
#!/usr/bin/env python3
"""hist3y.py - patch 144: THREE YEARS OF HISTORY for the study (Rama, 9 Nov: "go ahead with the 3 year study"). Reads only from
outside; writes only under data/h3/. Resumable: run it again and it carries on where it stopped. Stops itself on a weekday
between 08:40 and 15:40 (Kite's limits are shared with the engine) - run it again in the evening.

  kite day     daily candles, 3 years: every F&O share, NIFTY 50, NIFTY BANK and the NSE sector indices -> data/h3/day/SYM.npz
  kite 5min    5-minute candles, 3 years, the same list (90 days a request)                         -> data/h3/m5/SYM.npz
  nse fo       NSE's daily F&O file, every trading day (the old format before Jul 2024, UDiFF after): per share the near
               future's close / OI / OI change / contracts and the total CE / PE OI                -> data/h3/fut.db
  nse results  every quarterly result's filing time, 12 quarters a share (GIR's NSE reader)        -> data/h3/results.json
  python3 hist3y.py probe       a 1-minute check of each source (nothing big downloaded)
  python3 hist3y.py run         everything (about 1-2 hours the first time)      python3 hist3y.py status"""
import os, io, re, csv, sys, json, time, zipfile, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
H3 = os.path.join(BASE, "data", "h3")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
YEARS = 3
UDIFF_FROM = dt.date(2024, 7, 8)
URL_NEW = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
URL_OLD = "https://nsearchives.nseindia.com/content/historical/DERIVATIVES/%s/%s/fo%s%s%sbhav.csv.zip"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*"}
INDICES = ["NIFTY 50", "NIFTY BANK", "NIFTY PSU BANK", "NIFTY PVT BANK", "NIFTY FIN SERVICE", "NIFTY IT", "NIFTY AUTO", "NIFTY FMCG",
           "NIFTY METAL", "NIFTY PHARMA", "NIFTY HEALTHCARE", "NIFTY REALTY", "NIFTY ENERGY", "NIFTY OIL AND GAS", "NIFTY CONSR DURBL",
           "NIFTY MEDIA", "NIFTY INFRA", "NIFTY COMMODITIES", "NIFTY CPSE", "NIFTY PSE", "NIFTY CAPITAL MKT", "NIFTY CHEMICALS", "INDIA VIX"]
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


def log(*a):
    print(dt.datetime.now(IST).strftime("%H:%M:%S"), *a, flush=True)


def stop_now():
    n = dt.datetime.now(IST)
    return n.weekday() < 5 and "08:40" <= n.strftime("%H:%M") <= "15:40" and "--anytime" not in sys.argv


def fo_list():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        v = [r[0] for r in c.execute("select sym from fo_list order by sym")]
        c.close()
        return v
    except Exception:
        return []


def fname(s):
    return re.sub(r"[^A-Za-z0-9&-]", "_", s)


# ---------- Kite ----------
def kite():
    import core
    return core.get_kite()


def tokens(k):
    out = {}
    for i in k.instruments("NSE"):
        if i.get("segment") == "INDICES" or (i.get("segment") == "NSE" and i.get("instrument_type") == "EQ"):
            out.setdefault(i["tradingsymbol"], i["instrument_token"])
    return out


def candles(k, tok, start, end, interval, step):
    rows, a = [], start
    while a <= end:
        b = min(end, a + dt.timedelta(days=step))
        for tr in range(4):
            try:
                rows += k.historical_data(tok, a, b, interval) or []
                break
            except Exception as ex:
                if "Too many" in str(ex) or "429" in str(ex):
                    time.sleep(2 + tr * 2); continue
                raise
        time.sleep(0.36)                                          # under Kite's 3 a second
        a = b + dt.timedelta(days=1)
    return rows


def save_npz(path, rows):
    import numpy as np
    seen, R = set(), []
    for r in rows:
        t = int(r["date"].timestamp()) if hasattr(r["date"], "timestamp") else int(dt.datetime.fromisoformat(str(r["date"])).timestamp())
        if t not in seen:
            seen.add(t); R.append((t, r["open"], r["high"], r["low"], r["close"], r.get("volume") or 0))
    R.sort()
    if not R:
        return 0
    a = np.array(R, dtype=float)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    np.savez_compressed(path + ".tmp.npz", ts=a[:, 0], o=a[:, 1], h=a[:, 2], l=a[:, 3], c=a[:, 4], v=a[:, 5])
    os.replace(path + ".tmp.npz", path)
    return len(R)


def kite_all(k, names, kind):
    tok = tokens(k)
    end = dt.date.today() - dt.timedelta(days=1)
    start = end - dt.timedelta(days=365 * YEARS)
    d = os.path.join(H3, kind)
    n_ok = n_skip = 0
    miss = []
    for i, s in enumerate(names):
        if stop_now():
            log("market hours - stopping; run again after 15:40 (it carries on)"); return False
        p = os.path.join(d, fname(s) + ".npz")
        if os.path.exists(p) and time.time() - os.path.getmtime(p) < 5 * 86400:
            n_skip += 1; continue
        t = tok.get(s)
        if not t:
            miss.append(s); continue
        try:
            rows = candles(k, t, start, end, "day" if kind == "day" else "5minute", 1900 if kind == "day" else 90)
            n = save_npz(p, rows)
            n_ok += 1
            if i % 20 == 0:
                log("kite %s %d/%d %s: %d candles" % (kind, i + 1, len(names), s, n))
        except Exception as ex:
            log("kite %s %s: %s" % (kind, s, str(ex)[:100]))
            if "permission" in str(ex).lower() or "subscription" in str(ex).lower():
                log("Kite says no historical data on this plan - the Kite part stops here"); return False
    log("kite %s done: %d new · %d kept · not on Kite: %s" % (kind, n_ok, n_skip, ", ".join(miss[:15]) or "none"))
    return True


# ---------- NSE's daily F&O file ----------
def fo_db():
    os.makedirs(H3, exist_ok=True)
    c = sqlite3.connect(os.path.join(H3, "fut.db"), timeout=20)
    c.execute("create table if not exists fut(d text, sym text, fclose real, foi real, fchg real, fvol real, exp text, ce_oi real, pe_oi real, ce_chg real, pe_chg real, primary key(d, sym))")
    c.execute("create table if not exists done(d text primary key, status text)")
    return c


def _f(x):
    try:
        return float(str(x).replace(",", ""))
    except Exception:
        return 0.0


def _date(s):
    s = (s or "").strip()
    for f in ("%Y-%m-%d", "%d-%b-%Y", "%d-%b-%y", "%d%b%Y"):
        try:
            return dt.datetime.strptime(s[:11] if f != "%Y-%m-%d" else s[:10], f).date()
        except Exception:
            continue
    return None


def parse_fo(txt, new):
    """-> {sym: [fclose, foi, fchg, fvol, exp, ce_oi, pe_oi, ce_chg, pe_chg]} (near-month future; options summed)"""
    out, fut = {}, {}
    for e in csv.DictReader(io.StringIO(txt)):
        e = {(k or "").strip(): (v or "").strip() for k, v in e.items()}
        if new:
            tp, s, exp = e.get("FinInstrmTp"), e.get("TckrSymb"), _date(e.get("XpryDt"))
            cl, oi, ch, vol, ot = _f(e.get("ClsPric")), _f(e.get("OpnIntrst")), _f(e.get("ChngInOpnIntrst")), _f(e.get("TtlTradgVol")), (e.get("OptnTp") or "").upper()
            isfut, isopt = tp == "STF", tp == "STO"
        else:
            tp, s, exp = e.get("INSTRUMENT"), e.get("SYMBOL"), _date(e.get("EXPIRY_DT"))
            cl, oi, ch, vol, ot = _f(e.get("CLOSE")), _f(e.get("OPEN_INT")), _f(e.get("CHG_IN_OI")), _f(e.get("CONTRACTS")), (e.get("OPTION_TYP") or "").upper()
            isfut, isopt = tp == "FUTSTK", tp == "OPTSTK"
        if not s or not exp:
            continue
        if isfut:
            if s not in fut or exp < fut[s][4]:
                fut[s] = [cl, oi, ch, vol, exp]
        elif isopt and ot in ("CE", "PE"):
            o = out.setdefault(s, [0.0, 0.0, 0.0, 0.0])
            if ot == "CE":
                o[0] += oi; o[2] += ch
            else:
                o[1] += oi; o[3] += ch
    res = {}
    for s, f in fut.items():
        o = out.get(s, [0.0] * 4)
        res[s] = f[:4] + [str(f[4])] + o
    return res


def fo_one(d, get=None):
    if d >= UDIFF_FROM:
        url, new = URL_NEW % d.strftime("%Y%m%d"), True
    else:
        url, new = URL_OLD % (d.year, MON[d.month - 1], "%02d" % d.day, MON[d.month - 1], d.year), False
    if get is None:
        import requests
        r = requests.get(url, headers=UA, timeout=40)
        if r.status_code == 404:
            return "holiday"
        if r.status_code != 200:
            return "http %s" % r.status_code
        raw = r.content
    else:
        raw = get(url)
        if raw is None:
            return "holiday"
    z = zipfile.ZipFile(io.BytesIO(raw))
    return parse_fo(z.read(z.namelist()[0]).decode("utf-8", "ignore"), new)


def fo_all():
    c = fo_db()
    done = {r[0] for r in c.execute("select d from done where status in ('ok', 'holiday')")}
    end = dt.date.today() - dt.timedelta(days=1)
    d = end - dt.timedelta(days=365 * YEARS)
    n = 0
    while d <= end:
        if d.weekday() < 5 and str(d) not in done:
            if stop_now():
                log("market hours - stopping; run again after 15:40"); c.close(); return False
            try:
                v = fo_one(d)
                if isinstance(v, str):
                    c.execute("insert or replace into done values(?,?)", (str(d), v))
                else:
                    c.executemany("insert or replace into fut values(?,?,?,?,?,?,?,?,?,?,?)", [(str(d), s) + tuple(x) for s, x in v.items()])
                    c.execute("insert or replace into done values(?,?)", (str(d), "ok"))
                c.commit(); n += 1
                if n % 50 == 0:
                    log("nse fo: %d days read, at %s" % (n, d))
            except Exception as ex:
                log("nse fo %s: %s" % (d, str(ex)[:80]))
            time.sleep(0.8)
        d += dt.timedelta(days=1)
    log("nse fo done: %d days read now · %d in all" % (n, c.execute("select count(*) from done where status='ok'").fetchone()[0]))
    c.close()
    return True


# ---------- the results' filing times ----------
def results_all(syms):
    p = os.path.join(H3, "results.json")
    try:
        R = json.load(open(p))
    except Exception:
        R = {}
    import expect
    for i, s in enumerate(syms):
        if s in R:
            continue
        if stop_now():
            log("market hours - stopping"); break
        try:
            R[s] = [t for t, e in expect.nse_history(s, 12)]
        except Exception as ex:
            log("results %s: %s" % (s, str(ex)[:80])); R[s] = []
        if i % 25 == 0:
            log("results %d/%d %s: %d quarters" % (i + 1, len(syms), s, len(R[s])))
            json.dump(R, open(p, "w"))
    json.dump(R, open(p, "w"))
    log("results done: %d shares · %d with history" % (len(R), sum(1 for v in R.values() if v)))
    return True


def status():
    out = {}
    for kind in ("day", "m5"):
        d = os.path.join(H3, kind)
        out[kind] = len(os.listdir(d)) if os.path.isdir(d) else 0
    try:
        c = sqlite3.connect(os.path.join(H3, "fut.db"))
        out["fo_days"] = c.execute("select count(*) from done where status='ok'").fetchone()[0]
        out["fo_first"], out["fo_last"] = c.execute("select min(d), max(d) from fut").fetchone()
        c.close()
    except Exception:
        out["fo_days"] = 0
    try:
        R = json.load(open(os.path.join(H3, "results.json")))
        out["results"] = sum(1 for v in R.values() if v)
    except Exception:
        out["results"] = 0
    out["mb"] = round(sum(os.path.getsize(os.path.join(a, f)) for a, _, fs in os.walk(H3) for f in fs) / 1e6) if os.path.isdir(H3) else 0
    return out


def probe():
    ok = True
    try:
        k = kite(); print("OK   Kite login")
        tok = tokens(k)
        print("OK   Kite instruments: %d (NIFTY 50 %s · NIFTY PSU BANK %s)" % (len(tok), "yes" if "NIFTY 50" in tok else "NO", "yes" if "NIFTY PSU BANK" in tok else "NO"))
        e = dt.date.today() - dt.timedelta(days=1)
        r = k.historical_data(tok["NIFTY 50"], e - dt.timedelta(days=10), e, "day")
        print("OK   Kite daily candles: NIFTY 50 %d days" % len(r))
        old = e - dt.timedelta(days=365 * YEARS)
        r = k.historical_data(tok.get("SBIN"), old, old + dt.timedelta(days=10), "5minute")
        print(("OK " if r else "FAIL") + "  Kite 5-min candles 3 years back (%s): %d" % (old, len(r)))
        ok = ok and bool(r)
    except Exception as ex:
        ok = False
        print("FAIL Kite: %s" % str(ex)[:160])
    for d in (dt.date(2024, 11, 8), dt.date(2023, 11, 10)):
        try:
            v = fo_one(d)
            print(("OK   " if isinstance(v, dict) and v else "FAIL ") + "NSE F&O file %s (%s format): %s" % (d, "new" if d >= UDIFF_FROM else "old",
                  ("%d shares, SBIN future OI %s" % (len(v), int((v.get("SBIN") or [0, 0])[1]))) if isinstance(v, dict) else v))
            ok = ok and isinstance(v, dict) and bool(v)
        except Exception as ex:
            ok = False; print("FAIL NSE F&O file %s: %s" % (d, str(ex)[:120]))
    try:
        import expect
        h = expect.nse_history("COCHINSHIP", 12)
        print(("OK   " if h else "FAIL ") + "NSE results history: COCHINSHIP %d quarters (%s)" % (len(h), ", ".join(dt.datetime.fromtimestamp(t, IST).strftime("%d %b %y") for t, e in h[:4])))
    except Exception as ex:
        print("FAIL NSE results history: %s" % str(ex)[:120])
    print("PROBE " + ("PASSED - the download can run" if ok else "FAILED on some source - send this to Claude"))
    return ok


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "probe":
        sys.exit(0 if probe() else 1)
    if cmd == "status":
        print(json.dumps(status())); sys.exit(0)
    if cmd == "run":
        syms = fo_list()
        log("3-year download: %d F&O shares + %d indices" % (len(syms), len(INDICES)))
        try:
            k = kite()
            kite_all(k, INDICES + syms, "day") and kite_all(k, INDICES + syms, "m5")
        except Exception as ex:
            log("kite: %s" % str(ex)[:120])
        fo_all()
        results_all(syms)
        log("status: %s" % json.dumps(status()))
PY_H3
cat > $D/p144test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p144test.py - patch 144: the 3-year downloader on made-up files (no network): both NSE file formats, the candles, resuming"""
import os, io, sys, zipfile, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hist3y as H
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
def z(txt):
    b = io.BytesIO(); f = zipfile.ZipFile(b, "w"); f.writestr("x.csv", txt); f.close(); return b.getvalue()
OLD = """INSTRUMENT,SYMBOL,EXPIRY_DT,STRIKE_PR,OPTION_TYP,OPEN,HIGH,LOW,CLOSE,SETTLE_PR,CONTRACTS,VAL_INLAKH,OPEN_INT,CHG_IN_OI,TIMESTAMP,
FUTSTK,SBIN,30-Nov-2023,0,XX,1,1,1,580.5,580,1200,1,90000000,500000,10-NOV-2023,
FUTSTK,SBIN,28-Dec-2023,0,XX,1,1,1,583.0,583,100,1,4000000,10000,10-NOV-2023,
OPTSTK,SBIN,30-Nov-2023,600,CE,1,1,1,4,4,10,1,3000000,100000,10-NOV-2023,
OPTSTK,SBIN,30-Nov-2023,560,PE,1,1,1,3,3,10,1,2000000,-50000,10-NOV-2023,
FUTIDX,NIFTY,30-Nov-2023,0,XX,1,1,1,19400,1,1,1,1,1,10-NOV-2023,
"""
NEW = """TradDt,FinInstrmTp,TckrSymb,XpryDt,StrkPric,OptnTp,OpnPric,HghPric,LwPric,ClsPric,OpnIntrst,ChngInOpnIntrst,TtlTradgVol,UndrlygPric
2024-11-08,STF,SBIN,2024-11-28,,,1,1,1,820.1,120000000,-300000,5000,819
2024-11-08,STO,SBIN,2024-11-28,850,CE,1,1,1,5,7000000,200000,10,819
2024-11-08,STO,SBIN,2024-11-28,800,PE,1,1,1,4,6000000,100000,10,819
"""
def get(url):
    if "fo10NOV2023bhav" in url:
        return z(OLD)
    if "20241108" in url:
        return z(NEW)
    return None
o = H.fo_one(dt.date(2023, 11, 10), get)
check("the old format (Nov 2023): the near future, its OI and change, the options summed (%s)" % o.get("SBIN"), o["SBIN"][:4] == [580.5, 90000000.0, 500000.0, 1200.0] and o["SBIN"][5:] == [3000000.0, 2000000.0, 100000.0, -50000.0] and "NIFTY" not in o)
n = H.fo_one(dt.date(2024, 11, 8), get)
check("the new format (Nov 2024): SBIN future 820.1, OI 120m, change -0.3m (%s)" % n.get("SBIN"), n["SBIN"][0] == 820.1 and n["SBIN"][1] == 120000000.0 and n["SBIN"][2] == -300000.0 and n["SBIN"][5] == 7000000.0)
check("a holiday (no file) is said so", H.fo_one(dt.date(2024, 11, 1), get) == "holiday")
T = tempfile.mkdtemp(); H.H3 = T
class K:
    calls = 0
    def historical_data(self, tok, a, b, iv):
        K.calls += 1
        out, d = [], a
        while d <= b:
            if d.weekday() < 5:
                for m in ((0, 555, 560) if iv == "5minute" else (0,)):
                    t = dt.datetime(d.year, d.month, d.day, 9, 15, tzinfo=H.IST) + dt.timedelta(minutes=0 if iv == "day" else (m - 555 if m else 0))
                    out.append({"date": t, "open": 1, "high": 2, "low": 0.5, "close": 1.5, "volume": 10})
            d += dt.timedelta(days=1)
        return out
rows = H.candles(K(), 1, dt.date(2025, 1, 1), dt.date(2025, 6, 30), "5minute", 90)
check("5-min candles in 90-day steps: %d requests for half a year" % K.calls, K.calls == 2 and len(rows) > 100)
p = os.path.join(T, "m5", "SBIN.npz")
n_ = H.save_npz(p, rows + rows[:5])
import numpy as np
a = np.load(p)
check("saved once each, in time order (%d candles)" % n_, n_ == len({r["date"] for r in rows}) and list(a["ts"]) == sorted(a["ts"]))
H.tokens = lambda k: {"SBIN": 1, "NIFTY 50": 2}
H.stop_now = lambda: False
K.calls = 0
H.kite_all(K(), ["SBIN", "NIFTY 50", "NOSUCH"], "m5")
check("resuming: SBIN (just saved) is skipped, NIFTY 50 fetched, NOSUCH listed as not on Kite", os.path.exists(os.path.join(T, "m5", "NIFTY_50.npz")) and K.calls == 13)
shutil.rmtree(T)
print("P144 3-YEAR DOWNLOAD TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile hist3y.py p144test.py && timeout 120 python3 p144test.py > /dev/null 2>&1 && echo "    p144test.py passed" || { echo "the downloader's own test failed - nothing started"; exit 1; }
mkdir -p $D/data/h3
echo "    checking each source (about a minute)..."
( cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 hist3y.py probe ) || { echo; echo "not started - send this to Claude"; exit 1; }
systemctl stop gir-h3 2>/dev/null; systemctl reset-failed gir-h3 2>/dev/null
systemd-run --unit=gir-h3 --nice=10 /bin/bash -c "cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 hist3y.py run >> data/h3/download.log 2>&1" && echo && echo "DOWNLOAD STARTED in the background (gir-h3). You can close this window."
echo "progress: python3 $D/hist3y.py status   ·   tail $D/data/h3/download.log"
