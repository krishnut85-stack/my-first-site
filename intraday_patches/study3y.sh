#!/bin/bash
# THE 3-YEAR STUDY, STEP 2: THE STUDY. Run when the download (step 1) has finished. Adds the results dates NSE's results list
#   misses (its board-meeting calendar, ~10 min), then studies: A results run-up · B the opening gap · C rotation · D the 5%
#   days · E big market days. Reads only; ~5-15 min; sends the report to GIR's ⚙️ System topic.   bash study3y.sh
D=/home/globalbot/intraday
systemctl is-active --quiet gir-h3 && { echo "the download is still running - try later:"; python3 $D/hist3y.py status; tail -3 $D/data/h3/download.log; exit 1; }
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
               + the board meetings for results (NSE's results list misses the latest quarters) -> data/h3/results_bm.json
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


def bm_all(syms):
    """NSE's board-meeting calendar: the meetings for financial results, 3 years (NSE's results list misses the latest
    quarters for some shares) -> data/h3/results_bm.json {sym: ["YYYY-MM-DD", ...]}"""
    import exchange
    p = os.path.join(H3, "results_bm.json")
    try:
        R = json.load(open(p))
    except Exception:
        R = {}
    today = dt.date.today()
    for i, s in enumerate(syms):
        if s in R:
            continue
        if stop_now():
            log("market hours - stopping"); break
        dates = set()
        for k in range(YEARS + 1):
            to = today - dt.timedelta(days=365 * k)
            fr = to - dt.timedelta(days=364)
            try:
                data = exchange.nse_json("/api/corporate-board-meetings?index=equities&symbol=%s&from_date=%s&to_date=%s" % (
                    s, fr.strftime("%d-%m-%Y"), to.strftime("%d-%m-%Y")))
            except Exception:
                time.sleep(1); continue
            for e in (data if isinstance(data, list) else (data or {}).get("data", []) or []):
                if not isinstance(e, dict) or not re.search(r"financial result", " ".join(str(v) for v in e.values()), re.I):
                    continue
                for kk, v in e.items():
                    if "date" in kk.lower():
                        t = exchange.parse_t(v)
                        if t:
                            dates.add(str(dt.datetime.fromtimestamp(t, IST).date())); break
            time.sleep(0.5)
        R[s] = sorted(dates)
        if i % 25 == 0:
            log("board meetings %d/%d %s: %d" % (i + 1, len(syms), s, len(R[s])))
            json.dump(R, open(p, "w"))
    json.dump(R, open(p, "w"))
    log("board meetings done: %d shares · %d with dates" % (len(R), sum(1 for v in R.values() if v)))
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
    if cmd == "bm":
        bm_all(fo_list()); sys.exit(0)
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
        bm_all(syms)
        log("status: %s" % json.dumps(status()))
PY_H3
cat > $D/study3y.py <<'PY_ST'
#!/usr/bin/env python3
"""study3y.py - patch 144: THE 3-YEAR STUDY on data/h3 (hist3y.py). Reads only. Five answers, each with how often it held:

  A  RESULTS RUN-UP     every quarterly result 3 years: the 5 days into it, the reaction day (results after 15:30 -> the next
                        day), the gap. "Buy 5 days before, sell the day before" vs "hold through". The shares with results in the
                        next 7 days: their own last results.
  B  THE OPENING GAP    every F&O share every day: a 0.3-4% gap at the open - does it hold? (the 🌅 OPENING CALL's own stop:
                        back under yesterday's close / 1% from the open; target +1.5%; out 15:15) - by gap size, with / against
                        NIFTY's gap, results-day gaps, and when the first 5 minutes go its way
  C  ROTATION           the ⚡ ENTER NOW rule that rings: a group 0.8%+ up (70% of its shares) while another 0.8%+ down, shown
                        by 10:00 -> the laggards entered when above VWAP and 0.3%+ up, by 10:30: +1% before -0.7%?  vs the same
                        laggards entered without the check, vs rotations shown after 10:00
  D  THE 5% DAYS        every F&O share's 5%+ day: what was there the day before (volume 2x+, futures OI +5% with the price,
                        a 20-day high / low, the options' OI) - and how often the same sign came with NO big move (false alarms)
  E  BIG MARKET DAYS    NIFTY 2%+ days: the date, the leading and the lagging sector indices, and whether NIFTY at 09:30 already
                        pointed the way
  python3 study3y.py [A|B|C|D|E ...] [--no-tg]  -> prints, data/h3/study.txt, the report to GIR's ⚙️ System topic"""
import os, re, sys, json, math, sqlite3, statistics, datetime as dt
import numpy as np

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
H3 = os.path.join(BASE, "data", "h3")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NB = 75                                               # 5-min bars 09:15 .. 15:25
WIN, STOP = 1.0, 0.7


def fname(s):
    return re.sub(r"[^A-Za-z0-9&-]", "_", s)


def pct(a, b):
    return (a / b - 1) * 100 if (a and b) else None


def avg(L):
    return sum(L) / len(L) if L else 0.0


def share(n, d):
    return "%d%%" % round(100 * n / d) if d else "—"


# ---------- loading ----------
def daily(s):
    """-> {date: (o, h, l, c, v)}"""
    p = os.path.join(H3, "day", fname(s) + ".npz")
    if not os.path.exists(p):
        return {}
    a = np.load(p)
    return {str(dt.datetime.fromtimestamp(t, IST).date()): (o, h, l, c, v) for t, o, h, l, c, v in zip(a["ts"], a["o"], a["h"], a["l"], a["c"], a["v"])}


def intraday(s):
    """-> {date: float32 array (6, NB): o, h, l, c, v, filled} the 5-min bars of each day"""
    p = os.path.join(H3, "m5", fname(s) + ".npz")
    if not os.path.exists(p):
        return {}
    a = np.load(p)
    out = {}
    for t, o, h, l, c, v in zip(a["ts"], a["o"], a["h"], a["l"], a["c"], a["v"]):
        d = dt.datetime.fromtimestamp(t, IST)
        i = (d.hour * 60 + d.minute - 555) // 5
        if not 0 <= i < NB:
            continue
        k = str(d.date())
        x = out.get(k)
        if x is None:
            x = out[k] = np.zeros((6, NB), dtype=np.float32)
        x[:, i] = (o, h, l, c, v, 1)
    for x in out.values():                                     # a missing bar takes the last close
        last = None
        for i in range(NB):
            if x[5, i]:
                last = x[3, i]
            elif last is not None:
                x[0:4, i] = last
    return out


def prev_close_map(D):
    ks = sorted(D)
    return {ks[i]: D[ks[i - 1]][3] for i in range(1, len(ks))}


def fo_list():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        v = [r[0] for r in c.execute("select sym from fo_list order by sym")]
        c.close()
        return v
    except Exception:
        return [os.path.basename(f)[:-4] for f in os.listdir(os.path.join(H3, "day")) if f.endswith(".npz")]


def result_days(s, R, BM, days):
    """-> sorted reaction days (a trading day) of the share's results: filed after 15:30 -> the next trading day"""
    out = set()
    for t in R.get(s) or []:
        d = dt.datetime.fromtimestamp(t, IST)
        k = str(d.date())
        nxt = [x for x in days if (x > k if d.strftime("%H:%M") >= "15:30" else x >= k)]
        if nxt:
            out.add(nxt[0])
    have = sorted(out)
    for k in BM.get(s) or []:                                  # the board meeting's day: the reaction is that day or the next
        if any(abs((dt.date.fromisoformat(x) - dt.date.fromisoformat(k)).days) <= 3 for x in have):
            continue
        nxt = [x for x in days if x > k]                       # results usually come after the meeting - the next day reacts
        if nxt:
            out.add(nxt[0])
    return sorted(out)


def barrier(path_hi, path_lo, d, entry, end_i, start_i, close_arr):
    """+1% its way before -0.7% against, from bar start_i to end_i -> ("WIN"/"LOSS"/"OPEN", the move at the end %)"""
    for i in range(start_i, end_i + 1):
        fav = (path_hi[i] / entry - 1) * 100 if d > 0 else (1 - path_lo[i] / entry) * 100
        adv = (path_lo[i] / entry - 1) * 100 if d > 0 else (1 - path_hi[i] / entry) * 100
        if adv <= -STOP:
            return "LOSS", -STOP
        if fav >= WIN:
            return "WIN", WIN
    return "OPEN", (close_arr[end_i] / entry - 1) * 100 * d


def tally(L):
    w = sum(1 for x in L if x[0] == "WIN"); l = sum(1 for x in L if x[0] == "LOSS"); o = [x[1] for x in L if x[0] == "OPEN"]
    ev = (w * WIN - l * STOP + sum(o)) / len(L) if L else 0
    return "%d trades · WIN %s · LOSS %s · OPEN %d (avg %+.2f%%) · per trade %+.2f%%" % (len(L), share(w, len(L)), share(l, len(L)), len(o), avg(o), ev)


# ---------- A: results ----------
def study_a(syms, DAY, R, BM):
    L = ["", "A · RESULTS RUN-UP (3 years)"]
    ev = []
    for s in syms:
        D = DAY.get(s) or {}
        days = sorted(D)
        idx = {k: i for i, k in enumerate(days)}
        for T in result_days(s, R, BM, days):
            i = idx.get(T)
            if i is None or i < 6:
                continue
            c = lambda j: D[days[j]][3]
            run5 = pct(c(i - 1), c(i - 6))
            react = pct(c(i), c(i - 1))
            gap = pct(D[T][0], c(i - 1))
            d3 = pct(c(i + 2), c(i - 1)) if i + 2 < len(days) else None
            ev.append((s, T, run5, react, gap, d3))
    if not ev:
        return L + ["  no results history yet"], ev
    up = [e for e in ev if e[2] >= 5]; dn = [e for e in ev if e[2] <= -5]; mid = [e for e in ev if -5 < e[2] < 5]
    L.append("  %d results · the 5 days into them: up %s of the time, avg %+.1f%% · the reaction day avg %+.1f%%, avg size ±%.1f%%" % (
        len(ev), share(sum(1 for e in ev if e[2] > 0), len(ev)), avg([e[2] for e in ev]), avg([e[3] for e in ev]), avg([abs(e[3]) for e in ev])))
    for name, G in (("ran up 5%+ into results", up), ("fell 5%+ into results", dn), ("flat into results", mid)):
        if G:
            L.append("  %s (%d): reaction day avg %+.1f%% · fell %s · gapped down %s · 3 days later avg %+.1f%%" % (
                name, len(G), avg([e[3] for e in G]), share(sum(1 for e in G if e[3] < 0), len(G)), share(sum(1 for e in G if e[4] < 0), len(G)),
                avg([e[5] for e in G if e[5] is not None])))
    hold = [e[2] + e[3] for e in up]
    if up:
        L.append("  → the run-up trade (in 5 days before, OUT the day before results): avg %+.1f%% (it already ran) · holding THROUGH the results: avg %+.1f%%, worse %s of the time" % (
            avg([e[2] for e in up]), avg(hold), share(sum(1 for e in up if e[3] < 0), len(up))))
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        soon = [r[0] for r in c.execute("select sym from results_cal where d>=? and d<=? group by sym", (str(dt.date.today()), str(dt.date.today() + dt.timedelta(days=7))))]
        c.close()
    except Exception:
        soon = []
    for s in [x for x in soon if any(e[0] == x for e in ev)][:12]:
        E = [e for e in ev if e[0] == s][-6:]
        L.append("  %s: " % s + " | ".join("%s run %+.0f%% → %+.1f%%" % (e[1][2:7], e[2], e[3]) for e in E))
    return L, ev


# ---------- B: the opening gap ----------
def study_b(syms, DAY, M5, NIF, RD):
    L = ["", "B · THE OPENING GAP (0.3-4%, the 🌅 OPENING CALL's own stop and target, 3 years)"]
    B = {}
    for s in syms:
        D, X = DAY.get(s) or {}, M5.get(s) or {}
        pcm = prev_close_map(D)
        rset = set(RD.get(s) or [])
        for k, x in X.items():
            pc = pcm.get(k)
            if not pc or not x[5, 0]:
                continue
            op = float(x[0, 0])
            g = pct(op, pc)
            if g is None or abs(g) < 0.3:
                continue
            d = 1 if g > 0 else -1
            ng = NIF.get(k)
            if abs(g) > 4:
                key = ">4%"
            else:
                key = "0.3-1%" if abs(g) < 1 else "1-2%" if abs(g) < 2 else "2-4%"
            stop = max(pc, op * 0.99) if d > 0 else min(pc, op * 1.01)
            res = "OPEN"
            tgt = op * (1 + 0.015 * d)
            for i in range(NB - 2):
                if (x[2, i] <= stop if d > 0 else x[1, i] >= stop):
                    res = "LOSS"; mv = (stop / op - 1) * 100 * d; break
                if (x[1, i] >= tgt if d > 0 else x[2, i] <= tgt):
                    res = "WIN"; mv = 1.5; break
            if res == "OPEN":
                mv = (float(x[3, NB - 3]) / op - 1) * 100 * d
            row = (res, mv)
            B.setdefault(key, []).append(row)
            if abs(g) <= 4:
                if ng is not None:
                    B.setdefault("with NIFTY's gap" if ng * d > 0.1 else "against NIFTY's gap" if ng * d < -0.1 else "NIFTY flat", []).append(row)
                if (x[3, 0] - op) * d > 0:
                    B.setdefault("first 5 min its way", []).append(row)
                else:
                    B.setdefault("first 5 min against", []).append(row)
                if k in rset:
                    B.setdefault("results day", []).append(row)
    for key in ("0.3-1%", "1-2%", "2-4%", ">4%", "with NIFTY's gap", "against NIFTY's gap", "first 5 min its way", "first 5 min against", "results day"):
        if B.get(key):
            G = B[key]
            w = sum(1 for r in G if r[0] == "WIN"); l = sum(1 for r in G if r[0] == "LOSS")
            L.append("  %-22s %6d · +1.5%% first %s · stopped %s · per trade %+.2f%%" % (key, len(G), share(w, len(G)), share(l, len(G)), avg([r[1] for r in G])))
    return L, B


# ---------- C: rotation ----------
def study_c(syms, DAY, M5, G):
    L = ["", "C · ROTATION → the laggards (the ⚡ ENTER NOW rule that rings, 3 years)"]
    days = sorted({k for s in syms for k in (M5.get(s) or {})})
    pcm = {s: prev_close_map(DAY.get(s) or {}) for s in syms}
    rule, nochk, late, leaders, n_rot = [], [], [], [], 0
    for k in days:
        P = {}
        for s in syms:
            x = (M5.get(s) or {}).get(k)
            pc = pcm[s].get(k)
            if x is not None and pc:
                P[s] = (x, pc)
        if len(P) < 50:
            continue
        found = None
        for i in range(1, 30):                                  # bars ending 09:25 .. 11:45
            at = {}
            for n, mem in G.items():
                cc = [(float(P[s][0][3, i]) / P[s][1] - 1) * 100 for s in mem if s in P]
                if len(cc) >= 3:
                    at[n] = (avg(cc), sum(1 for c in cc if c > 0) / len(cc), sum(1 for c in cc if c < 0) / len(cc))
            ups = sorted([(v[0], n) for n, v in at.items() if v[0] >= 0.8 and v[1] >= 0.7], reverse=True)
            dns = [n for n, v in at.items() if v[0] <= -0.8 and v[2] >= 0.7]
            if ups and dns:
                found = (i, ups[0][1], ups[0][0]); break
        if not found:
            continue
        n_rot += 1
        i0, grp, a0 = found
        for s in G[grp]:
            if s not in P:
                continue
            x, pc = P[s]
            c0 = (float(x[3, i0]) / pc - 1) * 100
            if c0 >= a0 * 0.5:
                if i0 <= 8:
                    leaders.append(barrier(x[1], x[2], 1, float(x[3, i0]), NB - 3, i0 + 1, x[3]))
                continue
            dest = late if i0 > 8 else nochk
            dest.append(barrier(x[1], x[2], 1, float(x[3, i0]), NB - 3, i0 + 1, x[3]))
            if i0 > 8:
                continue
            cv = cvv = 0.0
            for j in range(0, min(i0 + 13, NB - 3)):             # confirmed by 10:30: 0.3%+ up and above VWAP
                tp = (float(x[1, j]) + float(x[2, j]) + float(x[3, j])) / 3
                cv += tp * float(x[4, j]); cvv += float(x[4, j])
                if j < i0:
                    continue
                c = (float(x[3, j]) / pc - 1) * 100
                if cvv and c >= 0.3 and float(x[3, j]) > cv / cvv and c < 3:
                    rule.append(barrier(x[1], x[2], 1, float(x[3, j]), NB - 3, j + 1, x[3]))
                    break
    L.append("  %d days with a rotation (of %d)" % (n_rot, len(days)))
    L.append("  THE RULE (by 10:00, laggard confirmed by 10:30): " + tally(rule))
    L.append("  the same laggards, no check:                    " + tally(nochk))
    L.append("  the leaders at that moment:                      " + tally(leaders))
    L.append("  rotations shown after 10:00 (laggards):          " + tally(late))
    return L, {"rule": rule, "nochk": nochk, "late": late, "leaders": leaders}


# ---------- D: 5% days ----------
def study_d(syms, DAY):
    L = ["", "D · THE 5% DAYS - the day before (3 years)"]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(H3, "fut.db"), uri=True)
        F = {}
        for d, s, fc, foi, fch, fv, ce, pe, cech, pech in c.execute("select d, sym, fclose, foi, fchg, fvol, ce_oi, pe_oi, ce_chg, pe_chg from fut"):
            F[(s, d)] = (foi, fch, fv, ce, pe, cech, pech)
        c.close()
    except Exception:
        F = {}
    sig = {}
    base = 0; big = 0
    for s in syms:
        D = DAY.get(s) or {}
        ks = sorted(D)
        for i in range(21, len(ks) - 1):
            k0, k1 = ks[i], ks[i + 1]                          # the sign on k0, the move on k1
            o, h, l, c0, v = D[k0]
            pcl = D[ks[i - 1]][3]
            mv = abs(pct(D[k1][3], c0) or 0)
            is_big = mv >= 5
            base += 1; big += is_big
            v20 = avg([D[ks[j]][4] for j in range(i - 20, i)])
            hi20, lo20 = max(D[ks[j]][1] for j in range(i - 20, i)), min(D[ks[j]][2] for j in range(i - 20, i))
            ch0 = pct(c0, pcl) or 0
            f = F.get((s, k0))
            S = []
            if v20 and v >= 2 * v20:
                S.append("volume 2x+")
            if v20 and v >= 3 * v20:
                S.append("volume 3x+")
            if h > hi20 or l < lo20:
                S.append("a 20-day high / low")
            if abs(ch0) >= 3:
                S.append("moved 3%+ that day")
            if f and f[0] and f[1] and f[0] - f[1] > 0:
                och = f[1] / (f[0] - f[1]) * 100
                if och >= 5 and abs(ch0) >= 1:
                    S.append("futures OI +5% with the price")
                if och >= 10:
                    S.append("futures OI +10%")
                if f[5] and f[6] and f[3] and f[4]:
                    if f[5] / max(f[3], 1) > 0.15 or f[6] / max(f[4], 1) > 0.15:
                        S.append("options OI +15% one side")
            if len(S) >= 2:
                S.append("2+ of these")
            for x in S:
                t = sig.setdefault(x, [0, 0])
                t[0] += 1; t[1] += is_big
    if not base:
        return L + ["  no daily data yet"], sig
    br = big / base
    L.append("  %d share-days · a 5%%+ move the next day: %d (%.1f%% of days - the base)" % (base, big, br * 100))
    for x, (n, b) in sorted(sig.items(), key=lambda kv: -(kv[1][1] / kv[1][0] if kv[1][0] else 0)):
        if n >= 30:
            L.append("  %-30s %6d days · a 5%% move next day %.1f%% (%.1fx the base) · false alarms %s" % (x, n, 100 * b / n, (b / n) / br if br else 0, share(n - b, n)))
    return L, sig


# ---------- E: big market days ----------
def study_e(DAY, M5, IDX):
    L = ["", "E · BIG MARKET DAYS (NIFTY 2%+)"]
    N = DAY.get("NIFTY 50") or {}
    X = M5.get("NIFTY 50") or {}
    pcm = prev_close_map(N)
    ks = sorted(N)
    rows, told = [], 0
    for k in ks:
        pc = pcm.get(k)
        if not pc:
            continue
        m = pct(N[k][3], pc)
        if abs(m) < 2:
            continue
        x = X.get(k)
        e930 = pct(float(x[3, 2]), pc) if x is not None else None
        if e930 is not None and e930 * m > 0.3:
            told += 1
        secs = []
        for n in IDX:
            Dn = DAY.get(n) or {}
            pn = prev_close_map(Dn).get(k)
            if Dn.get(k) and pn:
                secs.append((pct(Dn[k][3], pn), n.replace("NIFTY ", "")))
        secs.sort()
        rows.append("  %s NIFTY %+.1f%% · at 09:30 %s · best %s · worst %s" % (k, m, ("%+.1f%%" % e930) if e930 is not None else "—",
                    " ".join("%s %+.1f" % (b, a) for a, b in secs[-2:][::-1]), " ".join("%s %+.1f" % (b, a) for a, b in secs[:2])))
    L.append("  %d days · NIFTY at 09:30 already 0.3%%+ the day's way: %d of them" % (len(rows), told))
    return L + rows[-25:], rows


def send_tg(text):
    try:
        import premove
        return premove.send_tg(text)
    except Exception as ex:
        print("telegram: %s" % ex); return 0


def main(parts):
    import sectors, enternow
    syms = fo_list()
    G = enternow.groups(sectors.load())
    IDX = [x for x in ("NIFTY BANK", "NIFTY PSU BANK", "NIFTY PVT BANK", "NIFTY IT", "NIFTY AUTO", "NIFTY FMCG", "NIFTY METAL", "NIFTY PHARMA", "NIFTY REALTY",
                       "NIFTY ENERGY", "NIFTY MEDIA", "NIFTY INFRA", "NIFTY CPSE", "NIFTY FIN SERVICE", "NIFTY OIL AND GAS", "NIFTY CAPITAL MKT")]
    DAY = {s: daily(s) for s in syms + IDX + ["NIFTY 50"]}
    try:
        R = json.load(open(os.path.join(H3, "results.json")))
    except Exception:
        R = {}
    try:
        BM = json.load(open(os.path.join(H3, "results_bm.json")))
    except Exception:
        BM = {}
    L = ["📋 3-YEAR STUDY · %d F&O shares · daily candles for %d · %s" % (len(syms), sum(1 for s in syms if DAY.get(s)),
         "%s to %s" % (min(DAY["NIFTY 50"]), max(DAY["NIFTY 50"])) if DAY.get("NIFTY 50") else "no NIFTY")]
    out = {}
    RD = {s: result_days(s, R, BM, sorted(DAY.get(s) or {})) for s in syms}
    if "A" in parts:
        a, out["A"] = study_a(syms, DAY, R, BM); L += a
    if "D" in parts:
        d, out["D"] = study_d(syms, DAY); L += d
    if any(p in parts for p in "BCE"):
        M5 = {}
        for s in syms + ["NIFTY 50"]:
            M5[s] = intraday(s)
        NIF = {}
        N = DAY.get("NIFTY 50") or {}
        pcn = prev_close_map(N)
        for k, x in (M5.get("NIFTY 50") or {}).items():
            if pcn.get(k):
                NIF[k] = pct(float(x[0, 0]), pcn[k])
        if "B" in parts:
            b, out["B"] = study_b(syms, DAY, M5, NIF, RD); L += b
        if "C" in parts:
            c, out["C"] = study_c(syms, DAY, M5, G); L += c
        if "E" in parts:
            e, out["E"] = study_e(DAY, M5, IDX); L += e
    return L, out


if __name__ == "__main__":
    parts = [x for x in sys.argv[1:] if x in ("A", "B", "C", "D", "E")] or ["A", "B", "C", "D", "E"]
    L, out = main(parts)
    txt = "\n".join(L)
    print(txt)
    os.makedirs(H3, exist_ok=True)
    open(os.path.join(H3, "study.txt"), "w").write(txt)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % send_tg(txt))
PY_ST
cat > $D/p144btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p144btest.py - patch 144: the 3-year study's five answers on made-up data (no files): each finds the pattern put in"""
import os, sys, datetime as dt
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import study3y as S
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
IST = S.IST
days = []
d = dt.date(2025, 1, 1)
while len(days) < 80:
    if d.weekday() < 5:
        days.append(str(d))
    d += dt.timedelta(days=1)
def flat(px=100.0, v=1000):
    return {k: (px, px * 1.005, px * 0.995, px, v) for k in days}
DAY = {s: flat() for s in ("RUN", "GAPW", "GAPL", "U1", "U2", "U3", "LAG", "D1", "D2", "D3", "VOL", "NIFTY 50")}
# A: RUN rises 6% over the 5 days before its result day (day 40), then falls 3% on the day
for j, k in enumerate(days):
    if j >= 35:
        c = 100 * (1 + 0.012 * min(5, j - 34)) if j < 40 else 106 * 0.97
        DAY["RUN"][k] = (c, c * 1.005, c * 0.995, c, 1000)
R = {"RUN": [dt.datetime.fromisoformat(days[40] + " 14:00").replace(tzinfo=IST).timestamp()]}
a, ev = S.study_a(["RUN"], DAY, R, {})
print("\n".join(a))
check("A: the result found, the run-up +6%, the reaction -3%", len(ev) == 1 and abs(ev[0][2] - 6.0) < 0.2 and abs(ev[0][3] + 3.0) < 0.2)
check("A: 'ran up 5%+ into results ... fell 100%'", any("ran up 5%+" in x and "fell 100%" in x for x in a))
# B / C: the 5-min bars of day 60
k = days[60]
def bars(path, v=1000.0):
    x = np.zeros((6, S.NB), dtype=np.float32)
    for i in range(S.NB):
        c0, c1 = path(i), path(i + 1)
        x[:, i] = (c0, max(c0, c1) + 0.01, min(c0, c1) - 0.01, c1, v, 1)
    return x
M5 = {s: {} for s in DAY}
M5["GAPW"][k] = bars(lambda i: 101.5 + 0.05 * i)          # gaps +1.5% and climbs
M5["GAPL"][k] = bars(lambda i: 101.5 - 0.05 * i)          # gaps +1.5% and falls back
for s in ("U1", "U2", "U3"):
    M5[s][k] = bars(lambda i: 100 + min(2.5, 0.3 * i))
M5["LAG"][k] = bars(lambda i: 100 if i < 6 else 100 + min(4.0, 0.15 * (i - 6)))
for s in ("D1", "D2", "D3"):
    M5[s][k] = bars(lambda i: 100 - min(2.0, 0.3 * i))
b, B = S.study_b(["GAPW", "GAPL"], DAY, M5, {}, {})
print("\n".join(b))
check("B: the 1-2%% gaps: one +1.5%% first, one stopped (%s)" % B.get("1-2%"), sorted(r[0] for r in B.get("1-2%", [])) == ["LOSS", "WIN"])
G = {"UP": ["U1", "U2", "U3", "LAG"], "DOWN": ["D1", "D2", "D3"]}
for s in G["UP"] + G["DOWN"]:
    M5[s] = {kk: v for kk, v in M5[s].items()}
S_c = S.study_c(G["UP"] + G["DOWN"] + ["F%d" % i for i in range(50)], dict(DAY, **{"F%d" % i: flat() for i in range(50)}),
                dict(M5, **{"F%d" % i: {k: bars(lambda i: 100.0)} for i in range(50)}), G)
print("\n".join(S_c[0]))
check("C: one rotation day, the laggard LAG confirmed and +1%% first (%s)" % S_c[1]["rule"], S_c[1]["rule"] == [("WIN", 1.0)])
check("C: the leaders counted apart", len(S_c[1]["leaders"]) == 3)
# D: VOL: volume 3x on day 50, a 6% move on day 51
for j, kk in enumerate(days):
    if j == 50:
        DAY["VOL"][kk] = (100, 100.5, 99.5, 100, 3500)
    if j >= 51:
        DAY["VOL"][kk] = (106, 106.5, 105.5, 106, 1000)
d_, sig = S.study_d(["VOL", "U1", "U2"], DAY)
check("D: 'volume 3x+' seen once, followed by the 5%% move (%s)" % sig.get("volume 3x+"), sig.get("volume 3x+") == [1, 1])
# E: NIFTY +2.5% on day 70, already +1% at 09:30
k2 = days[70]
c = DAY["NIFTY 50"][days[69]][3] * 1.025
for kk in days[70:]:
    DAY["NIFTY 50"][kk] = (100, c, 99.9, c, 1)
M5["NIFTY 50"][k2] = bars(lambda i: 100 + 0.5 * min(i, 5))
e, rows = S.study_e(DAY, M5, [])
print("\n".join(e))
check("E: the NIFTY 2%+ day listed, 09:30 pointing the way", len(rows) == 1 and "NIFTY +2.5%" in rows[0] and "1 of them" in e[2])
print("P144 3-YEAR STUDY TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile hist3y.py study3y.py p144btest.py && timeout 120 python3 p144btest.py > /dev/null 2>&1 && echo "    p144btest.py passed" || { echo "the study's own test failed - nothing run"; exit 1; }
echo "    the download: $(python3 hist3y.py status)"
echo "    adding the results dates from NSE's board-meeting calendar (~10 min)..."
( cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 hist3y.py bm --anytime >> data/h3/download.log 2>&1 ); tail -1 data/h3/download.log
AV=$(free -m | awk '/Mem:/{print $7}'); echo "    memory free: ${AV} MB"
if [ "$AV" -lt 900 ]; then
  echo "    low memory - in two parts"
  nice -n 10 python3 study3y.py A D > /tmp/study_ad.out 2>&1; nice -n 10 python3 study3y.py B C E > /tmp/study_bce.out 2>&1
  cat /tmp/study_ad.out /tmp/study_bce.out | grep -v "^sent to"
else
  nice -n 10 python3 study3y.py > /tmp/study.out 2>&1; cat /tmp/study.out
fi
