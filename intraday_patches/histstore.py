#!/usr/bin/env python3
"""histstore.py - READ ONLY for GIR (changes nothing in GIR, sends nothing, orders nothing). THE 2-YEAR DATA STORE for the long backtest
(Rama, 15 Nov: "why can't we test all we did for at least 2 years - find a way to do it faster").

The old way fetched every day again for every test (30 days = hours). This fetches ONCE and keeps it on disk; longtest.py then runs every
study over all the days from the disk, in minutes. Re-run it any evening: it fetches only the days that are new.

  python3 histstore.py check          disk space, the Zerodha login, how many shares, how long - fetches nothing
  python3 histstore.py nsecheck       one NSE daily futures file: shows its columns (run once, send the output to Claude)
  python3 histstore.py get [DAYS]     the minute candles of every F&O share + NIFTY + BANKNIFTY (NSE cash, the share itself) for DAYS calendar
                                      days (default 730 = 2 years), then NSE's daily futures OI file for each of those days
  python3 histstore.py nse            only the NSE daily futures files (if the minute part is done)

WHAT IS IN IT / WHAT IS NOT: Zerodha keeps years of MINUTE candles for every share (price + volume). Zerodha does NOT keep the futures or options
of contracts that have EXPIRED - so the futures OI minute by minute exists only for the last few weeks. For the 2 years, the futures money comes
from NSE's own daily file (the OI at each day's close, every F&O share) - the day's build-up, not minute by minute.
Zerodha's limit is 3 requests a second: never run this while another backtest is fetching, and run it after 15:35.
Store: /root/hist (the minute files min/SYM.npz, fo_daily.json, sectors.json). About 2 MB a share, ~0.5 GB in all.
Run it with GIR's keys loaded:   ( set -a; . /home/globalbot/.env; set +a; python3 histstore.py get )"""
import os, sys, json, time, shutil, threading, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__)) if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), "windwatch.py")) else "/home/globalbot/intraday"
sys.path.insert(0, BASE)
STORE = os.environ.get("GIR_HIST", "/root/hist")
MIN_DIR = os.path.join(STORE, "min")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime.now(IST)
CHUNK = 55                      # Zerodha gives at most 60 days of minute candles a request
GAP = 0.36                      # seconds between requests (under 3 a second)
IDX = {"NIFTY": 256265, "BANKNIFTY": 260105}
NOT_SHARES = {"NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50", "SENSEX", "BANKEX"}


def kite():
    import core
    k = core.get_kite()
    try:
        k.timeout = 20
    except Exception:
        pass
    k.profile()
    return k


def fo_list(k):
    """today's F&O shares (their futures are listed) -> {share: its NSE cash token}"""
    fut = {r["name"] for r in k.instruments("NFO") if r.get("instrument_type") == "FUT"} - NOT_SHARES
    eq = {r["tradingsymbol"]: r["instrument_token"] for r in k.instruments("NSE") if r.get("segment") == "NSE" and r.get("instrument_type") == "EQ"}
    return {s: eq[s] for s in sorted(fut) if s in eq}


def free_gb():
    os.makedirs(STORE, exist_ok=True)
    return shutil.disk_usage(STORE).free / 1e9


class Gate:
    """one request every GAP seconds across all threads"""
    def __init__(self):
        self.lock, self.t = threading.Lock(), 0.0

    def wait(self):
        with self.lock:
            dt_ = self.t + GAP - time.time()
            if dt_ > 0:
                time.sleep(dt_)
            self.t = time.time()


def fetch(k, gate, tok, a, b):
    for tr in range(5):
        gate.wait()
        try:
            return k.historical_data(tok, a, b, "minute") or []
        except Exception as ex:
            m = str(ex)
            if "Too many" in m or "429" in m or "rate" in m.lower():
                time.sleep(2 + 2 * tr); continue
            if tr < 2 and ("timed out" in m.lower() or "connection" in m.lower()):
                time.sleep(3); continue
            raise
    return []


def load(path):
    import numpy as np
    try:
        z = np.load(path)
        return {k_: z[k_] for k_ in ("ts", "o", "h", "l", "c", "v")}
    except Exception:
        return None


def save(path, rows, old=None):
    import numpy as np
    seen, R = set(), []
    if old is not None:
        for i in range(len(old["ts"])):
            t = int(old["ts"][i]); seen.add(t)
            R.append((t, float(old["o"][i]), float(old["h"][i]), float(old["l"][i]), float(old["c"][i]), float(old["v"][i])))
    for r in rows:
        d_ = r["date"]
        t = int(d_.timestamp()) if hasattr(d_, "timestamp") else int(dt.datetime.fromisoformat(str(d_)).timestamp())
        if t not in seen:
            seen.add(t); R.append((t, r["open"], r["high"], r["low"], r["close"], r.get("volume") or 0))
    if not R:
        return 0
    R.sort()
    a = np.array(R, dtype=np.float64)
    tmp = path + ".tmp.npz"
    np.savez_compressed(tmp, ts=a[:, 0].astype(np.int64), o=a[:, 1].astype(np.float32), h=a[:, 2].astype(np.float32), l=a[:, 3].astype(np.float32),
                        c=a[:, 4].astype(np.float32), v=a[:, 5].astype(np.float32))
    os.replace(tmp, path)
    return len(R)


def one(k, gate, s, tok, start, end):
    """fetch what is missing for one share -> (rows added, requests)"""
    path = os.path.join(MIN_DIR, s + ".npz")
    old = load(path) if os.path.exists(path) else None
    a = start
    if old is not None and len(old["ts"]):
        first = dt.datetime.fromtimestamp(int(old["ts"][0]), IST).date(); last = dt.datetime.fromtimestamp(int(old["ts"][-1]), IST).date()
        if first <= start + dt.timedelta(days=7):
            a = last + dt.timedelta(days=1)                                    # only the new days
        else:
            old = None                                                         # asked for more history than kept: fetch it all again
    rows, n = [], 0
    while a <= end:
        b = min(end, a + dt.timedelta(days=CHUNK - 1))
        rows += fetch(k, gate, tok, dt.datetime.combine(a, dt.time(9, 0)), dt.datetime.combine(b, dt.time(15, 35)))
        n += 1; a = b + dt.timedelta(days=1)
    if rows or old is None:
        save(path, rows, old)
    return len(rows), n


def get_min(days):
    import numpy as np
    k = kite()
    S = fo_list(k)
    S.update(IDX)
    os.makedirs(MIN_DIR, exist_ok=True)
    try:
        import windwatch as WW
        json.dump(WW.sectors_of(), open(os.path.join(STORE, "sectors.json"), "w"))
    except Exception as ex:
        print("  (the sectors were not saved: %s - the sector part of the test will be left out)" % str(ex)[:80])
    end = NOW.date() - dt.timedelta(days=0 if NOW.strftime("%H:%M") >= "15:35" else 1)
    start = NOW.date() - dt.timedelta(days=days)
    names = list(S)
    print("=== fetching %d shares + the 2 indices, %s -> %s (minute candles, NSE cash) · 3 at a time, under Zerodha's 3 a second" % (len(names) - 2, start, end), flush=True)
    gate, lock, done, errs, t0 = Gate(), threading.Lock(), [0], [], time.time()
    q = list(names)

    def worker():
        while True:
            with lock:
                if not q:
                    return
                s = q.pop(0)
            try:
                if free_gb() < 1.0:
                    with lock:
                        errs.append((s, "disk nearly full")); q.clear()
                    return
                added, n = one(k, gate, s, S[s], start, end)
            except Exception as ex:
                with lock:
                    errs.append((s, str(ex)[:80]))
                added, n = 0, 0
            with lock:
                done[0] += 1
                if done[0] % 10 == 0 or done[0] == len(names):
                    el = time.time() - t0
                    print("  %d of %d · %s · %.0f min so far, about %.0f min left" % (done[0], len(names), s, el / 60, el / done[0] * (len(names) - done[0]) / 60), flush=True)

    th = [threading.Thread(target=worker) for _ in range(3)]
    for x in th:
        x.start()
    for x in th:
        x.join()
    sz = sum(os.path.getsize(os.path.join(MIN_DIR, f)) for f in os.listdir(MIN_DIR)) / 1e6
    print("=== minute candles: %d files · %.0f MB · %.0f min · problems: %d" % (len(os.listdir(MIN_DIR)), sz, (time.time() - t0) / 60, len(errs)))
    for s, e in errs[:15]:
        print("   %s: %s" % (s, e))
    if errs:
        print("   (run the same command again - it fetches only what is missing)")


# ---------------- NSE's daily futures file (UDiFF bhavcopy, from July 2024): every F&O contract's OI at the day's close ----------------
NSE_URL = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36", "Accept": "*/*", "Referer": "https://www.nseindia.com/"}


def nse_day(sess, d):
    """-> None (no file: a holiday) or the CSV rows of that day"""
    import io, csv, zipfile
    r = sess.get(NSE_URL % d.strftime("%Y%m%d"), headers=HDR, timeout=30)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    z = zipfile.ZipFile(io.BytesIO(r.content))
    txt = z.read(z.namelist()[0]).decode("utf-8", "replace")
    return list(csv.DictReader(io.StringIO(txt)))


def col(row, *names):
    for n in names:
        if n in row and row[n] not in (None, ""):
            return row[n]
    return None


def nse_sum(rows):
    """-> {share: [OI, change in OI, contracts traded, the nearest future's close]} - every futures expiry added up (shares and indices)"""
    out, near = {}, {}
    for r in rows:
        tp = (col(r, "FinInstrmTp") or "").strip()
        if tp not in ("STF", "IDF"):
            continue
        s = (col(r, "TckrSymb") or "").strip(); ex = col(r, "XpryDt", "FininstrmActlXpryDt") or ""
        try:
            oi = float(col(r, "OpnIntrst") or 0); ch = float(col(r, "ChngInOpnIntrst") or 0); vo = float(col(r, "TtlTradgVol") or 0); cl = float(col(r, "ClsPric") or 0)
        except ValueError:
            continue
        a = out.setdefault(s, [0.0, 0.0, 0.0, 0.0])
        a[0] += oi; a[1] += ch; a[2] += vo
        if s not in near or ex < near[s]:
            near[s] = ex; a[3] = cl
    return out


def get_nse():
    import requests
    import numpy as np
    nf = os.path.join(MIN_DIR, "NIFTY.npz")
    if not os.path.exists(nf):
        print("the NIFTY minute file is not there yet - run:  python3 histstore.py get"); return
    ts = np.load(nf)["ts"]
    days = sorted({dt.datetime.fromtimestamp(int(t), IST).date() for t in ts[::300]} | {dt.datetime.fromtimestamp(int(ts[-1]), IST).date()})
    days = [d for d in days if d >= dt.date(2024, 7, 8)]                        # NSE's UDiFF file starts 8 July 2024
    path = os.path.join(STORE, "fo_daily.json")
    J = json.load(open(path)) if os.path.exists(path) else {"done": [], "d": {}}
    have = set(J["done"])
    todo = [d for d in days if str(d) not in have]
    print("=== NSE's daily futures file: %d days to fetch (%d already in) · one every 0.7 s" % (len(todo), len(have)), flush=True)
    sess = requests.Session(); fails = 0; t0 = time.time()
    for i, d in enumerate(todo):
        try:
            rows = nse_day(sess, d); fails = 0
        except Exception as ex:
            fails += 1
            print("  %s: %s" % (d, str(ex)[:80]))
            if fails >= 4:
                print("  NSE is not answering - stopped. Run  python3 histstore.py nse  again later (it keeps what it has)."); break
            time.sleep(5); continue
        if rows:
            for s, v in nse_sum(rows).items():
                J["d"].setdefault(s, {})[str(d)] = [round(v[0]), round(v[1]), round(v[2]), v[3]]
        J["done"].append(str(d))
        if i % 25 == 24:
            json.dump(J, open(path + ".tmp", "w"), separators=(",", ":")); os.replace(path + ".tmp", path)
            print("  %d of %d · %s · %.0f min" % (i + 1, len(todo), d, (time.time() - t0) / 60), flush=True)
        time.sleep(0.7)
    json.dump(J, open(path + ".tmp", "w"), separators=(",", ":")); os.replace(path + ".tmp", path)
    print("=== NSE daily futures: %d days · %d shares" % (len(J["done"]), len(J["d"])))


def nsecheck():
    import requests
    sess = requests.Session(); d = NOW.date() - dt.timedelta(days=1)
    for _ in range(10):
        while d.weekday() > 4:
            d -= dt.timedelta(days=1)
        try:
            rows = nse_day(sess, d)
        except Exception as ex:
            print("NSE %s: %s" % (d, str(ex)[:120])); return
        if rows:
            break
        d -= dt.timedelta(days=1)
    if not rows:
        print("no NSE file found in the last 10 days"); return
    print("NSE daily futures file %s: %d rows · columns:" % (d, len(rows)))
    print("  " + ", ".join(rows[0].keys()))
    st = [r for r in rows if (col(r, "FinInstrmTp") or "").strip() == "STF"]
    print("stock futures rows: %d · e.g.:" % len(st))
    for r in [x for x in st if (col(x, "TckrSymb") or "").strip() in ("RELIANCE", "IDEA", "SBIN")][:4]:
        print("  %s %s OI %s change %s lot %s close %s" % (col(r, "TckrSymb"), col(r, "XpryDt"), col(r, "OpnIntrst"), col(r, "ChngInOpnIntrst"), col(r, "NewBrdLotQty"), col(r, "ClsPric")))
    S = nse_sum(rows)
    print("added up: " + " · ".join("%s OI %s" % (s, "{:,.0f}".format(S[s][0])) for s in ("RELIANCE", "IDEA", "SBIN", "NIFTY") if s in S))


def check():
    print("store: %s · free disk %.1f GB (needs about 1 GB)" % (STORE, free_gb()))
    try:
        k = kite(); S = fo_list(k)
    except Exception as ex:
        print("Zerodha: %s - run it with GIR's keys loaded, after GIR's morning login on a market day" % str(ex)[:100]); return
    n = len(S) + 2; req = n * (730 // CHUNK + 1)
    print("Zerodha: logged in · %d F&O shares + 2 indices · about %d requests for 2 years · about %.0f-%.0f min" % (len(S), n, req, req * GAP / 60 * 1.2, req * 1.0 / 60))
    if os.path.isdir(MIN_DIR):
        print("already in the store: %d minute files" % len(os.listdir(MIN_DIR)))


if __name__ == "__main__":
    a = sys.argv[1:] or ["check"]
    if a[0] == "check":
        check()
    elif a[0] == "nsecheck":
        nsecheck()
    elif a[0] == "get":
        if free_gb() < 1.5:
            print("free disk %.1f GB - needs about 1 GB (+ room). Nothing fetched." % free_gb()); sys.exit(1)
        get_min(int(a[1]) if len(a) > 1 else 730)
        get_nse()
    elif a[0] == "nse":
        get_nse()
    else:
        print(__doc__)
