#!/bin/bash
# PATCH 121 - MORE F&O DATA + 3 YEARS OF HISTORY (on top of patch 120).
#   - new daily NSE files: every F&O share's OI as % of its market-wide limit (the ban is at 95%), the delivery %, and
#     FII / DII / Pro / Client positions in stock and index futures (nsextra.py -> data/extra.db)
#   - the history goes back to Nov 2023 (NSE's older F&O file format is read too) - about 3 years for the study
#   - 6 new footprints in the early-warning study (near the ban limit · OI limit jumping · high delivery with the price
#     flat · high delivery with the price falling · FII adding stock-futures shorts / longs); a footprint must now work in
#     EVERY year with 50+ cases; the ones that do are alerted by the evening run (🔭 EARLY), as before
#   - the downloads (~35 min) run in the background (gir-history); the study prints when they finish
#   nsextra.py (new) · earlystudy.py. Restarts gir-intraday (it reads the study's verdicts).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g121; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p121.sh now"; exit 1; fi
grep -q "def nifty_1m" $D/dashserve.py || { echo "patch 120 is not installed yet - paste patch 120 first"; exit 1; }
[ -f $D/nsextra.py ] && { echo "patch 121 is already installed - the downloads:  tail -5 $D/data/history.log"; exit 1; }
cp $D/earlystudy.py $D/earlystudy.py.bak$TS
back() { cp $D/earlystudy.py.bak$TS $D/earlystudy.py; rm -f $D/nsextra.py $D/p121test.py; systemctl restart gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/nsextra.py <<'PY_NX'
#!/usr/bin/env python3
"""nsextra.py - MORE F&O DATA FROM NSE'S OWN DAILY FILES (patch 121), for the early-warning study and its alerts:
  mwpl   every F&O share's open interest as a % of its market-wide position limit (the F&O ban is at 95%)  combineoi_DDMMYYYY.zip
  deliv  every share's delivery % (shares taken home, not traded away the same day)                       sec_bhavdata_full_DDMMYYYY.csv
  part   FII / DII / Pro / Client positions in stock and index futures (contracts)                         fao_participant_oi_DDMMYYYY.csv
and THE OLDER HISTORY: NSE's F&O day files before July 2024 (the old "fo..bhav.csv" format) read into data/oistudy.db,
so the study covers about 3 years instead of 2.

  python3 nsextra.py --probe [DATE]          read each source for one day and say what came back (nothing stored)
  python3 nsextra.py --fetch FROM TO         download + store every weekday (resumes); also the old F&O days
  python3 nsextra.py --status                how many days each source has
Everything goes to data/extra.db (and the old F&O days to data/oistudy.db)."""
import os, io, re, sys, csv, time, zipfile, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "data", "extra.db")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Referer": "https://www.nseindia.com/", "Accept": "*/*"}
URL = {"mwpl": "https://nsearchives.nseindia.com/archives/nsccl/mwpl/combineoi_%s.zip",
       "deliv": "https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_%s.csv",
       "part": "https://nsearchives.nseindia.com/content/nsccl/fao_participant_oi_%s.csv",
       "oldfo": "https://nsearchives.nseindia.com/content/historical/DERIVATIVES/%s/%s/fo%s%s%sbhav.csv.zip"}


def db(path=None):
    c = sqlite3.connect(path or DB, timeout=30)
    c.execute("create table if not exists fetched(d text, src text, status text, n int, primary key(d, src))")
    c.execute("create table if not exists mwpl(d text, sym text, mwpl real, oi real, pct real, primary key(d, sym))")
    c.execute("create table if not exists deliv(d text, sym text, qty real, dq real, dp real, primary key(d, sym))")
    c.execute("create table if not exists part(d text, who text, fi_l real, fi_s real, fs_l real, fs_s real, primary key(d, who))")
    return c


def num(x):
    try:
        return float(str(x).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def _rows(txt):
    """csv text -> list of dicts with stripped, lower-case keys (NSE files carry spaces and a title line now and then)"""
    lines = [l for l in txt.splitlines() if l.strip()]
    for i, l in enumerate(lines[:5]):                          # the header is the first line with 3+ commas and letters
        if l.count(",") >= 3 and re.search(r"[A-Za-z]", l) and not re.match(r'^\s*"?participant wise', l, re.I):
            rd = csv.DictReader(io.StringIO("\n".join(lines[i:])))
            return [{(k or "").strip().lower(): (v or "").strip() for k, v in r.items()} for r in rd]
    return []


def parse_mwpl(txt):
    out = {}
    for r in _rows(txt):
        sym = next((r[k] for k in r if "symbol" in k), "") or ""
        mw = num(next((r[k] for k in r if k.startswith("mwpl")), None))
        oi = num(next((r[k] for k in r if "open interest" in k), None))
        if sym and mw and oi is not None:
            out[sym.upper()] = (mw, oi, round(100.0 * oi / mw, 2))
    return out


def parse_deliv(txt):
    out = {}
    for r in _rows(txt):
        if (r.get("series") or "").upper() != "EQ":
            continue
        q, dq, dp = num(r.get("ttl_trd_qnty")), num(r.get("deliv_qty")), num(r.get("deliv_per"))
        if r.get("symbol") and q:
            out[r["symbol"].upper()] = (q, dq, dp)
    return out


def parse_part(txt):
    out = {}
    for r in _rows(txt):
        who = (r.get("client type") or "").upper()
        if who in ("CLIENT", "DII", "FII", "PRO", "TOTAL"):
            out[who] = tuple(num(r.get(k)) for k in ("future index long", "future index short", "future stock long", "future stock short"))
    return out


def old_fo_to_udiff(txt):
    """the old F&O day file (INSTRUMENT, SYMBOL, EXPIRY_DT, STRIKE_PR, OPTION_TYP, ..., CLOSE, OPEN_INT, CHG_IN_OI) ->
    the column names oistudy.boil reads (FinInstrmTp, TckrSymb, XpryDt, ...). No underlying price in the old file:
    boil then takes the near future's close as the price."""
    rd = csv.DictReader(io.StringIO(txt))
    hdr = ["FinInstrmTp", "TckrSymb", "XpryDt", "StrkPric", "OptnTp", "OpnPric", "HghPric", "LwPric", "ClsPric", "PrvsClsgPric", "UndrlygPric",
           "OpnIntrst", "ChngInOpnIntrst", "TtlTradgVol"]
    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(hdr)
    tp = {"FUTSTK": "STF", "OPTSTK": "STO", "FUTIDX": "IDF", "OPTIDX": "IDO"}
    for r in rd:
        r = {(k or "").strip(): (v or "").strip() for k, v in r.items()}
        t = tp.get(r.get("INSTRUMENT", ""))
        if not t:
            continue
        kd = r.get("OPTION_TYP", "")
        w.writerow([t, r.get("SYMBOL", ""), r.get("EXPIRY_DT", ""), r.get("STRIKE_PR", "") if t in ("STO", "IDO") else "", kd if kd in ("CE", "PE") else "",
                    r.get("OPEN", ""), r.get("HIGH", ""), r.get("LOW", ""), r.get("CLOSE", ""), "", "", r.get("OPEN_INT", ""), r.get("CHG_IN_OI", ""), r.get("CONTRACTS", "")])
    return out.getvalue()


def _session():
    import requests
    s = requests.Session()
    return lambda url: s.get(url, headers=UA, timeout=40)


def _body(r):
    data = r.content
    if data[:2] == b"PK":
        z = zipfile.ZipFile(io.BytesIO(data))
        return z.read(z.namelist()[0]).decode("utf-8", "ignore")
    return data.decode("utf-8", "ignore")


def url_for(src, d):
    if src == "oldfo":
        mon = d.strftime("%b").upper()
        return URL["oldfo"] % (d.strftime("%Y"), mon, d.strftime("%d"), mon, d.strftime("%Y"))
    return URL[src] % d.strftime("%d%m%Y")


def read_day(src, d, get):
    """-> ('ok', parsed) / ('none', None) for a day without a file / raises on a network error"""
    r = get(url_for(src, d))
    if r.status_code == 404:
        return "none", None
    if r.status_code != 200:
        raise IOError("NSE answered %s" % r.status_code)
    txt = _body(r)
    if src == "mwpl":
        return "ok", parse_mwpl(txt)
    if src == "deliv":
        return "ok", parse_deliv(txt)
    if src == "part":
        return "ok", parse_part(txt)
    return "ok", txt


def store(c, src, d, parsed):
    ds = str(d)
    if src == "mwpl":
        c.executemany("insert or replace into mwpl values(?,?,?,?,?)", [(ds, s, a, b, p) for s, (a, b, p) in parsed.items()])
    elif src == "deliv":
        c.executemany("insert or replace into deliv values(?,?,?,?,?)", [(ds, s, q, dq, dp) for s, (q, dq, dp) in parsed.items()])
    elif src == "part":
        c.executemany("insert or replace into part values(?,?,?,?,?,?)", [(ds, w, *v) for w, v in parsed.items()])
    c.execute("insert or replace into fetched values(?,?,?,?)", (ds, src, "ok", len(parsed)))


def fetch_extra(d0, d1, get=None, quiet=False, sources=("mwpl", "deliv", "part")):
    get = get or _session()
    c = db()
    n, fails = 0, 0
    for src in sources:
        done = {r[0] for r in c.execute("select d from fetched where src=? and status in ('ok','none')", (src,))}
        d = d0
        while d <= d1:
            if d.weekday() < 5 and str(d) not in done:
                try:
                    st, parsed = read_day(src, d, get)
                    if st == "ok" and parsed:
                        store(c, src, d, parsed); n += 1
                    else:
                        c.execute("insert or replace into fetched values(?,?,?,?)", (str(d), src, "none", 0))
                    c.commit(); fails = 0
                    time.sleep(0.35)
                except Exception as ex:
                    fails += 1
                    if not quiet:
                        print("  %s %s: %s" % (src, d, str(ex)[:80]), flush=True)
                    if fails >= 8:
                        print("STOP: NSE is not answering (8 in a row) - run again later, it resumes", flush=True)
                        c.close(); return n
                    time.sleep(3 * fails)
                    continue
                if not quiet and n and n % 50 == 0:
                    print("  %s: %d files stored ..." % (d, n), flush=True)
            d += dt.timedelta(days=1)
    c.close()
    return n


def fetch_old_fo(d0, d1, get=None, quiet=False):
    """the F&O day files before 2025 into data/oistudy.db: the new format (from July 2024), else the old one"""
    import oistudy
    get = get or _session()
    c = oistudy.db()
    done = {r[0] for r in c.execute("select d from fetched where status in ('ok', 'none')")}
    d, n, fails = d0, 0, 0
    while d <= d1:
        if d.weekday() < 5 and str(d) not in done:
            try:
                txt = None
                r = get(oistudy.URL % d.strftime("%Y%m%d"))
                if r.status_code == 200 and r.content[:2] == b"PK":
                    txt = _body(r)
                else:
                    r2 = get(url_for("oldfo", d))
                    if r2.status_code == 200 and r2.content[:2] == b"PK":
                        txt = old_fo_to_udiff(_body(r2))
                    elif r.status_code not in (200, 404) and r2.status_code not in (200, 404):
                        raise IOError("NSE answered %s / %s" % (r.status_code, r2.status_code))
                if txt:
                    rows = oistudy.boil(txt, d, oistudy.prev_rows(c, d))
                    oistudy.store(c, rows)
                    c.execute("insert or replace into fetched values(?,?,?)", (str(d), "ok", len(rows))); n += 1
                else:
                    c.execute("insert or replace into fetched values(?,?,?)", (str(d), "none", 0))
                c.commit(); fails = 0
                time.sleep(0.35)
                if not quiet and n and n % 25 == 0:
                    print("  old F&O %s: %d days stored ..." % (d, n), flush=True)
            except ValueError as ex:
                print("STOP: %s (%s)" % (ex, d), flush=True); break
            except Exception as ex:
                fails += 1
                if not quiet:
                    print("  old F&O %s: %s" % (d, str(ex)[:80]), flush=True)
                if fails >= 8:
                    print("STOP: NSE is not answering (8 in a row) - run again later, it resumes", flush=True); break
                time.sleep(3 * fails)
                continue
        d += dt.timedelta(days=1)
    c.close()
    return n


def extra_maps(path=None):
    """for the study: {(d, sym): {"mwpl_pct", "dp"}} and {d: {"fii_sl", "fii_ss"}} (FII stock futures long / short)"""
    per, day = {}, {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % (path or DB), uri=True, timeout=10)
        for d, s, p in c.execute("select d, sym, pct from mwpl"):
            per.setdefault((d, s), {})["mwpl_pct"] = p
        for d, s, dp in c.execute("select d, sym, dp from deliv"):
            per.setdefault((d, s), {})["dp"] = dp
        for d, l, s in c.execute("select d, fs_l, fs_s from part where who='FII'"):
            day[d] = {"fii_sl": l, "fii_ss": s}
        c.close()
    except Exception:
        pass
    return per, day


def status():
    c = db()
    for src in ("mwpl", "deliv", "part"):
        r = c.execute("select count(*), min(d), max(d) from fetched where src=? and status='ok'", (src,)).fetchone()
        print("  %-6s %d days (%s .. %s)" % (src, r[0], r[1], r[2]))
    c.close()
    try:
        import oistudy
        c = oistudy.db()
        r = c.execute("select count(*), min(d), max(d) from fetched where status='ok'").fetchone()
        print("  F&O    %d days (%s .. %s)" % r)
        c.close()
    except Exception:
        pass


if __name__ == "__main__":
    a = sys.argv[1:]
    fd = lambda s: dt.datetime.strptime(s, "%Y-%m-%d").date()
    if a[:1] == ["--probe"]:
        d = fd(a[1]) if len(a) > 1 else None
        get = _session()
        for src in ("mwpl", "deliv", "part", "oldfo"):
            dd = d or (dt.date(2024, 3, 15) if src == "oldfo" else dt.date.today() - dt.timedelta(days=1))
            while dd.weekday() >= 5:
                dd -= dt.timedelta(days=1)
            try:
                st, parsed = read_day(src, dd, get)
                if src == "oldfo" and parsed:
                    import oistudy
                    rows = oistudy.boil(old_fo_to_udiff(parsed), dd)
                    print("  %-6s %s: %s · %d F&O shares read" % (src, dd, st, len(rows)))
                else:
                    sample = list(parsed.items())[:2] if parsed else []
                    print("  %-6s %s: %s · %d rows%s" % (src, dd, st, len(parsed or {}), (" · e.g. %s" % sample) if sample else ""))
            except Exception as ex:
                print("  %-6s %s: FAILED %s" % (src, dd, str(ex)[:90]))
        sys.exit(0)
    if a[:1] == ["--fetch"] and len(a) >= 3:
        d0, d1 = fd(a[1]), fd(a[2])
        print("old F&O days: %d new" % fetch_old_fo(d0, min(d1, dt.date(2024, 12, 31))), flush=True)
        print("extra files: %d new" % fetch_extra(d0, d1), flush=True)
        sys.exit(0)
    if a[:1] == ["--status"]:
        status(); sys.exit(0)
    print(__doc__)
PY_NX
cat > $W/earlystudy.py <<'PY_ES'
#!/usr/bin/env python3
"""earlystudy.py - THE EARLY-WARNING STUDY (patch 115): which OI footprints came BEFORE the big moves, hours to days ahead?
Read-only, on data/oistudy.db (NSE's daily F&O files boiled down per share-day by oistudy.py: futures OI, the option chain).

For every share-day it asks two questions, separately for each year:
  FORWARD  when a footprint shows up after the close, how often does a BIG MOVE (4%+ from that close, any day within the
           next 1 / 3 / 5 trading days) follow - against the same rate on every share-day (the base). lift = hit / base.
  MIRROR   of all the big days (a share closing 5%+ up or down), how many had the footprint in the 5 days before
           (= how often it would have warned you in time).
A footprint is a WARNING when it has 50+ cases and a lift of 1.5x or more in BOTH years. Its direction is usable when the
big moves that followed went its way 60%+ of the time. Everything is shown, the failures too.

  python3 earlystudy.py --study      the table (also saved to data/earlystudy.txt and data/earlystudy.json)
  python3 earlystudy.py --today      the shares showing a WARNING footprint on the latest day in the file
  python3 earlystudy.py --test       the self-test (synthetic data, no network)"""
import os, sys, json, sqlite3, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BIG, BIGDAY, HOR = 4.0, 5.0, (1, 3, 5)
UP, DN, ANY = "UP", "DOWN", "EITHER"


def _db_path():
    try:
        import core
        return os.path.join(core.DATA, "oistudy.db")
    except Exception:
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "oistudy.db")


COLS = ["d", "sym", "spot", "foi", "fvol", "exp", "oexp", "ce_oi", "pe_oi", "roof_k", "floor_k", "atm_k", "atm_ce", "atm_pe", "strikes"]


def load(path=None):
    c = sqlite3.connect("file:%s?mode=ro" % (path or _db_path()), uri=True, timeout=30)
    by = collections.OrderedDict()
    for r in c.execute("select %s from day order by sym, d" % ",".join(COLS)):
        x = dict(zip(COLS, r))
        if x["spot"]:
            by.setdefault(x["sym"], []).append(x)
    c.close()
    try:                                                   # patch 121: the OI limit %, the delivery %, the FII futures positions
        import nsextra
        per, day = nsextra.extra_maps()
        if per or day:
            for rs in by.values():
                for x in rs:
                    e, f = per.get((x["d"], x["sym"])), day.get(x["d"])
                    if e:
                        x.update(e)
                    if f:
                        x.update(f)
    except Exception:
        pass
    return by


def pct(a, b):
    return (a / b - 1) * 100 if a and b else None


def same_series(rs, i, k):
    """no futures expiry inside the window (the expired month drops out of the OI total) and the same option expiry"""
    w = rs[i - k:i + 1]
    return all(x["exp"] == w[0]["exp"] for x in w) and all(x["oexp"] == w[0]["oexp"] for x in w)


def strikes(r):
    if "_k" not in r:
        try:
            r["_k"] = {float(k): v for k, v in json.loads(r["strikes"]).items()} if r.get("strikes") else {}
        except Exception:
            r["_k"] = {}
    return r["_k"]


def spike(rs, i, kind):
    """ONE out-of-the-money strike whose OI at least doubled in 3 days, holds 2x+ its neighbours and 10%+ of its side"""
    a, b = rs[i], rs[i - 3]
    ka, kb, sp = strikes(a), strikes(b), a["spot"]
    if not ka or not kb or a["oexp"] != b["oexp"]:
        return None
    j = 0 if kind == "CE" else 2
    ks = sorted(ka)
    tot = sum(v[j] or 0 for v in ka.values()) or 1
    best = None
    for n, k in enumerate(ks):
        if (kind == "CE" and k < sp * 1.02) or (kind == "PE" and k > sp * 0.98):
            continue
        oi, oi0 = ka[k][j] or 0, (kb.get(k) or [0, 0, 0, 0])[j] or 0
        if oi < 0.10 * tot or oi0 <= 0 or oi < 2 * oi0:
            continue
        nb = [ka[ks[m]][j] or 0 for m in (n - 1, n + 1) if 0 <= m < len(ks)]
        if nb and oi < 2 * (sum(nb) / len(nb)):
            continue
        if not best or oi / oi0 > best[1]:
            best = (k, oi / oi0)
    return best


def flat(rs, i, k, lim=1.5):
    m = pct(rs[i]["spot"], rs[i - k]["spot"])
    return m is not None and abs(m) <= lim


# id, name, claim, what it means
FP = [
    ("fut_accum3", "FUTURES OI +10% IN 3 DAYS, PRICE FLAT", ANY, "money piling into futures while the price sleeps (±1.5%)"),
    ("fut_accum5", "FUTURES OI +15% IN 5 DAYS, PRICE FLAT", ANY, "the same over a week (±2%)"),
    ("ce_spike", "ONE CALL STRIKE DOUBLED IN 3 DAYS", UP, "an out-of-the-money call strike 2x in 3 days, 2x its neighbours"),
    ("pe_spike", "ONE PUT STRIKE DOUBLED IN 3 DAYS", DN, "an out-of-the-money put strike 2x in 3 days, 2x its neighbours"),
    ("ce_build3", "CALLS BUILDING 3 DAYS, PRICE FLAT", ANY, "call OI near the price +25% in 3 days, puts not, price ±1.5%"),
    ("pe_build3", "PUTS BUILDING 3 DAYS, PRICE FLAT", ANY, "put OI near the price +25% in 3 days, calls not, price ±1.5%"),
    ("pcr_rise3", "PCR UP 0.3+ IN 3 DAYS", UP, "puts written faster than calls for 3 days"),
    ("pcr_high", "PCR 1.5 OR MORE", UP, "puts 1.5x the calls near the price"),
    ("pcr_low", "PCR 0.5 OR LESS", DN, "calls 2x the puts near the price (the mirror of PCR 1.5+)"),
    ("pcr_fall3", "PCR DOWN 0.3+ IN 3 DAYS", DN, "calls written faster than puts for 3 days (the mirror of PCR up)"),
    ("coil", "OI AT A 20-DAY HIGH, PRICE IN A 2.5% BOX", ANY, "the most futures OI in 20 days while 5 closes sit inside 2.5%"),
    ("prem_build", "OPTION PREMIUM UP 20% WITH THE PRICE FLAT", ANY, "the at-the-money call + put (as % of the price) up 20% in 3 days, price ±1.5%"),
    ("roof_leaving", "THE ROOF'S CALLS LEAVING", UP, "the biggest call strike above loses 20% of its OI in 2 days, price within 3% under it"),
    ("floor_leaving", "THE FLOOR'S PUTS LEAVING", DN, "the biggest put strike below loses 20% of its OI in 2 days, price within 3% over it"),
    ("quiet_then_oi", "QUIET VOLUME, OI CREEPING UP", ANY, "futures volume 5-day average under 60% of 20-day, OI +5% in 5 days"),
    ("mwpl_80", "OI NEAR THE BAN LIMIT (80%+ OF MWPL)", ANY, "OI crossed 80% of its market-wide limit, from under 70% within 5 days (the F&O ban is at 95%)"),
    ("mwpl_jump", "OI +15 POINTS OF ITS LIMIT IN 5 DAYS, PRICE FLAT", ANY, "OI as % of the market-wide limit up 15 points in 5 days, price within ±2%"),
    ("deliv_acc", "HIGH DELIVERY, PRICE FLAT (ACCUMULATION)", UP, "delivery % at 1.5x its 20-day average on 2 of the last 3 days, price within ±2%"),
    ("deliv_dump", "HIGH DELIVERY WITH THE PRICE FALLING", DN, "delivery % at 1.5x its 20-day average on 2 of the last 3 days, price down 2%+"),
    ("fii_short3", "FII ADDING STOCK-FUTURES SHORTS (3 DAYS)", DN, "FII stock-futures shorts +5% in 3 days, their longs not rising (the whole market)"),
    ("fii_long3", "FII ADDING STOCK-FUTURES LONGS (3 DAYS)", UP, "FII stock-futures longs +5% in 3 days, their shorts not rising (the whole market)"),
]
FPD = {f[0]: f for f in FP}


def fires(rs, i):
    """the footprints on share-day i (after its close)"""
    out = []
    r = rs[i]
    if i >= 3 and same_series(rs, i, 3):
        o3 = pct(r["foi"], rs[i - 3]["foi"])
        if o3 is not None and o3 >= 10 and flat(rs, i, 3):
            out.append("fut_accum3")
        if spike(rs, i, "CE"):
            out.append("ce_spike")
        if spike(rs, i, "PE"):
            out.append("pe_spike")
        c3, p3 = pct(r["ce_oi"], rs[i - 3]["ce_oi"]), pct(r["pe_oi"], rs[i - 3]["pe_oi"])
        if c3 is not None and p3 is not None and flat(rs, i, 3):
            if c3 >= 25 and p3 <= 5:
                out.append("ce_build3")
            if p3 >= 25 and c3 <= 5:
                out.append("pe_build3")
        if r["ce_oi"] and rs[i - 3]["ce_oi"] and r["pe_oi"] is not None and rs[i - 3]["pe_oi"] is not None:
            if r["pe_oi"] / r["ce_oi"] - rs[i - 3]["pe_oi"] / rs[i - 3]["ce_oi"] >= 0.3:
                out.append("pcr_rise3")
            if r["pe_oi"] / r["ce_oi"] - rs[i - 3]["pe_oi"] / rs[i - 3]["ce_oi"] <= -0.3:
                out.append("pcr_fall3")
        a0, a1 = rs[i - 3], r
        if a0["atm_ce"] and a0["atm_pe"] and a1["atm_ce"] and a1["atm_pe"] and flat(rs, i, 3):
            s0, s1 = (a0["atm_ce"] + a0["atm_pe"]) / a0["spot"], (a1["atm_ce"] + a1["atm_pe"]) / a1["spot"]
            if s1 >= 1.2 * s0:
                out.append("prem_build")
    if r["ce_oi"] and r["pe_oi"] and r["pe_oi"] / r["ce_oi"] >= 1.5:
        out.append("pcr_high")
    if r["ce_oi"] and r["pe_oi"] is not None and r["pe_oi"] / r["ce_oi"] <= 0.5:
        out.append("pcr_low")
    if i >= 5 and same_series(rs, i, 5):
        o5 = pct(r["foi"], rs[i - 5]["foi"])
        if o5 is not None and o5 >= 15 and flat(rs, i, 5, 2.0):
            out.append("fut_accum5")
    if i >= 20:
        w = rs[i - 19:i + 1]
        if all(x["foi"] for x in w) and r["foi"] >= max(x["foi"] for x in w) and same_series(rs, i, 5):
            cl = [x["spot"] for x in rs[i - 4:i + 1]]
            if (max(cl) / min(cl) - 1) * 100 <= 2.5:
                out.append("coil")
        v20 = [x["fvol"] or 0 for x in w]
        v5 = v20[-5:]
        o5 = pct(r["foi"], rs[i - 5]["foi"])
        if sum(v20) > 0 and (sum(v5) / 5) < 0.6 * (sum(v20) / 20) and o5 is not None and o5 >= 5 and same_series(rs, i, 5):
            out.append("quiet_then_oi")
    mp = r.get("mwpl_pct")                                 # patch 121: the new NSE data
    if mp is not None and i >= 5:
        pv = [x.get("mwpl_pct") for x in rs[i - 5:i] if x.get("mwpl_pct") is not None]
        if pv and mp >= 80 and min(pv) < 70:
            out.append("mwpl_80")
        if pv and mp - pv[0] >= 15 and flat(rs, i, 5, 2.0):
            out.append("mwpl_jump")
    if i >= 20 and r.get("dp") is not None:
        hd = [x.get("dp") for x in rs[i - 20:i - 2] if x.get("dp") is not None]
        if len(hd) >= 10:
            avg = sum(hd) / len(hd)
            hi = sum(1 for x in rs[i - 2:i + 1] if x.get("dp") is not None and avg > 0 and x["dp"] >= 1.5 * avg)
            m3 = pct(r["spot"], rs[i - 3]["spot"])
            if hi >= 2 and m3 is not None:
                if abs(m3) <= 2:
                    out.append("deliv_acc")
                elif m3 <= -2:
                    out.append("deliv_dump")
    if i >= 3 and r.get("fii_sl") and rs[i - 3].get("fii_sl") and r.get("fii_ss") and rs[i - 3].get("fii_ss"):
        dl_, ds_ = pct(r["fii_sl"], rs[i - 3]["fii_sl"]), pct(r["fii_ss"], rs[i - 3]["fii_ss"])
        if ds_ >= 5 and dl_ <= 0:
            out.append("fii_short3")
        if dl_ >= 5 and ds_ <= 0:
            out.append("fii_long3")
    if i >= 2 and same_series(rs, i, 2):
        for key, kind, j, want in (("roof_k", "CE", 0, "roof_leaving"), ("floor_k", "PE", 2, "floor_leaving")):
            k = r[key]
            if not k:
                continue
            a, b = strikes(r).get(float(k)), strikes(rs[i - 2]).get(float(k))
            if a and b and b[j] and a[j] is not None and a[j] <= 0.8 * b[j]:
                gap = (k / r["spot"] - 1) * 100 if kind == "CE" else (r["spot"] / k - 1) * 100
                if 0 <= gap <= 3:
                    out.append(want)
    return out


def outcome(rs, i, h):
    """-> (max rise %, max fall %) of the closes over the next h trading days, or None near the end of the data"""
    if i + h >= len(rs):
        return None
    p0 = rs[i]["spot"]
    w = [x["spot"] for x in rs[i + 1:i + h + 1] if x["spot"]]
    if not w:
        return None
    return (max(w) / p0 - 1) * 100, (min(w) / p0 - 1) * 100


def hit(claim, o):
    up, dn = o[0] >= BIG, o[1] <= -BIG
    return up if claim == UP else dn if claim == DN else (up or dn)


def study(by=None, path=None):
    by = by if by is not None else load(path)
    F = collections.defaultdict(lambda: {"n": 0, "h": {h: 0 for h in HOR}, "up": 0, "dn": 0, "last": []})
    base = collections.defaultdict(lambda: {"n": 0, UP: 0, DN: 0, ANY: 0})
    mirror = collections.defaultdict(lambda: {"big": 0, "warned": collections.Counter(), "any": 0})
    days = set()
    for sym, rs in by.items():
        fl = [fires(rs, i) for i in range(len(rs))]
        for i, r in enumerate(rs):
            days.add(r["d"])
            yr = r["d"][:4]
            o5 = outcome(rs, i, 5)
            if o5 is not None:
                b = base[yr]; b["n"] += 1
                for cl in (UP, DN, ANY):
                    b[cl] += int(hit(cl, o5))
            for f in fl[i]:
                e = F[(f, yr)]
                oo = {h: outcome(rs, i, h) for h in HOR}
                if oo[5] is None:
                    continue
                e["n"] += 1
                for h in HOR:
                    e["h"][h] += int(oo[h] is not None and hit(FPD[f][2], oo[h]))
                if oo[5][0] >= BIG:
                    e["up"] += 1
                if oo[5][1] <= -BIG:
                    e["dn"] += 1
                if hit(FPD[f][2], oo[5]):
                    e["last"] = (e["last"] + ["%s %s %+.1f%%" % (r["d"], sym, oo[5][0] if oo[5][0] >= -oo[5][1] else oo[5][1])])[-4:]
            if i >= 1 and rs[i - 1]["spot"]:
                mv = pct(r["spot"], rs[i - 1]["spot"])
                if mv is not None and abs(mv) >= BIGDAY:
                    m = mirror[yr]; m["big"] += 1
                    seen = set(f for j in range(max(0, i - 5), i) for f in fl[j])
                    for f in seen:
                        m["warned"][f] += 1
                    m["any"] += int(bool(seen & set(WARN_OK or [x[0] for x in FP])))
    years = sorted({y for (_, y) in F} | set(base))
    rows = []
    for fid, name, claim, what in FP:
        row = {"id": fid, "name": name, "claim": claim, "what": what, "years": {}}
        for y in years:
            e, b = F.get((fid, y)), base.get(y)
            if not e or not e["n"] or not b or not b["n"]:
                continue
            br = 100.0 * b[claim] / b["n"]
            hr = 100.0 * e["h"][5] / e["n"]
            big = e["up"] + e["dn"]
            row["years"][y] = {"n": e["n"], "h1": round(100.0 * e["h"][1] / e["n"], 1), "h3": round(100.0 * e["h"][3] / e["n"], 1), "h5": round(hr, 1),
                               "base": round(br, 1), "lift": round(hr / br, 2) if br else None, "up_share": round(100.0 * e["up"] / big) if big else None,
                               "warned": mirror[y]["warned"].get(fid, 0), "bigdays": mirror[y]["big"], "last": e["last"]}
        full = [row["years"][y] for y in years if y in row["years"] and row["years"][y]["n"] >= 50]      # patch 121: every year with 50+ cases
        good = [v for v in full if (v["lift"] or 0) >= 1.5]
        weak = [v for v in full if (v["lift"] or 0) >= 1.2]
        row["verdict"] = ("WARNING WORKS EVERY YEAR" if len(full) >= 2 and len(good) == len(full) else "NOT EVERY YEAR" if good
                          else "WEAK" if len(full) >= 2 and len(weak) == len(full) else "FEW CASES" if len(full) < 2 else "NO EARLY WARNING")
        v = full[-1] if full else None
        if claim == ANY and v and v["up_share"] is not None:
            row["direction"] = "mostly UP" if v["up_share"] >= 60 else "mostly DOWN" if v["up_share"] <= 40 else "either way"
        rows.append(row)
    order = {"WARNING WORKS EVERY YEAR": 0, "WARNING WORKS BOTH YEARS": 0, "NOT EVERY YEAR": 1, "ONE YEAR ONLY": 1, "WEAK": 2, "NO EARLY WARNING": 3, "FEW CASES": 4}
    rows.sort(key=lambda r: (order[r["verdict"]], -max([(v["lift"] or 0) for v in r["years"].values()] or [0])))
    return {"years": years, "shares": len(by), "days": len(days), "first": min(days) if days else None, "last": max(days) if days else None,
            "base": {y: {k: round(100.0 * b[k] / b["n"], 1) for k in (UP, DN, ANY)} for y, b in base.items() if b["n"]},
            "mirror": {y: {"big": m["big"], "any": m["any"]} for y, m in mirror.items()}, "rows": rows}


WARN_OK = None


def table(out):
    ys = out["years"][-4:]
    L = ["EARLY-WARNING STUDY · %d shares · %d trading days (%s → %s) · NSE F&O daily files" % (out["shares"], out["days"], out["first"], out["last"]),
         "BIG MOVE = the close 4%+ away from the signal day's close on any day within the next 5 trading days",
         "base (any share-day): " + " · ".join("%s up %s%% / down %s%% / either %s%%" % (y, out["base"][y][UP], out["base"][y][DN], out["base"][y][ANY]) for y in ys if y in out["base"]),
         ""]
    for r in out["rows"]:
        L.append("%s · %s · %s%s" % (r["name"], {"UP": "expect UP", "DOWN": "expect DOWN", "EITHER": "a big move either way"}[r["claim"]], r["verdict"],
                                    (" (%s)" % r["direction"]) if r.get("direction") else ""))
        for y in ys:
            v = r["years"].get(y)
            if v:
                L.append("   %s: %d cases · big move within 5 days %.0f%% vs %.0f%% normal = %.1fx (1 day %.0f%%, 3 days %.0f%%) · warned %d of %d big days"
                         % (y, v["n"], v["h5"], v["base"], v["lift"] or 0, v["h1"], v["h3"], v["warned"], v["bigdays"]))
    L += ["", "warned = of the big days that year (a close 5%+ up or down), how many had this footprint in the 5 days before",
          "lift = how many times more often a big move followed than on an ordinary share-day. 1.5x+ in every year with 50+ cases = WARNING WORKS"]
    for y in ys:
        m = out["mirror"].get(y)
        if m:
            L.append("%s: %d big days · %d (%d%%) had at least one footprint in the 5 days before" % (y, m["big"], m["any"], round(100.0 * m["any"] / m["big"]) if m["big"] else 0))
    L.append("")
    L.append("EXAMPLES (the latest hits of each footprint that works):")
    for r in out["rows"]:
        if r["verdict"] in WORKS + ("NOT EVERY YEAR", "ONE YEAR ONLY"):
            v = r["years"].get(ys[-1]) or {}
            L.append("  %s: %s" % (r["name"], " · ".join(v.get("last") or [])))
    return "\n".join(L)


def today(out, by=None, path=None):
    by = by if by is not None else load(path)
    ok = {r["id"] for r in out["rows"] if r["verdict"] in WORKS + ("NOT EVERY YEAR", "ONE YEAR ONLY")}
    last = max((rs[-1]["d"] for rs in by.values() if rs), default=None)
    L = ["ON %s (the latest day in the file) - shares showing a footprint that works:" % last]
    n = 0
    for sym, rs in by.items():
        if not rs or rs[-1]["d"] != last:
            continue
        f = [x for x in fires(rs, len(rs) - 1) if x in ok]
        if f:
            n += 1
            L.append("  %-11s %s" % (sym, " · ".join(FPD[x][1] + " (" + FPD[x][2] + ")" for x in f)))
    if not n:
        L.append("  none")
    return "\n".join(L)


WORKS = ("WARNING WORKS EVERY YEAR", "WARNING WORKS BOTH YEARS")


def saved(path=None):
    """the last study (data/earlystudy.json) or None"""
    try:
        return json.load(open(path or os.path.join(os.path.dirname(_db_path()), "earlystudy.json")))
    except Exception:
        return None


def record(row):
    """'2025: a 4%+ rise within 5 days 44% of the time vs 20% normally (2.2x, 936 cases) · 2026: ...' from a study row"""
    word = {"UP": "rise", "DOWN": "fall", "EITHER": "move"}[row["claim"]]
    ys = sorted(row["years"])[-2:]
    return "measured on NSE's files — " + " · ".join("%s: a 4%%+ %s within 5 days %.0f%% of the time vs %.0f%% normally (%.1fx, %d cases)" % (
        y, word, row["years"][y]["h5"], row["years"][y]["base"], row["years"][y]["lift"] or 0, row["years"][y]["n"]) for y in ys)


def early_text(sym, row, detail, src):
    up = row["claim"] == "UP"
    return ("🔭 EARLY %s %s · %s%s · %s\n%s\n"
            "WATCH — not a trade yet: share price likely going %s → %s side in the next days. GIR rings again when it starts (🚀 RUNNING · ⚡ FIRST MOVE).") % (
        "▲" if up else "▼", sym, row["name"], (" · " + detail) if detail else "", src, record(row), "UP" if up else "DOWN", "CE" if up else "PE")


def sent_db():
    try:
        import core
        p = os.path.join(core.BASE, "tomorrow.db")
    except Exception:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tomorrow.db")
    c = sqlite3.connect(p, timeout=10)
    c.execute("create table if not exists early_sent(day text, sym text, side text, fp text, src text, t text, primary key(day, sym, side))")
    return c


def mark(day, sym, side, fp, src):
    """True the first time (day, share, side) is alerted - 15:00 live and the evening file share one record"""
    c = sent_db()
    try:
        import time as _t
        c.execute("insert into early_sent(day,sym,side,fp,src,t) values(?,?,?,?,?,?)", (day, sym, side, fp, src, _t.strftime("%H:%M")))
        c.commit(); return True
    except sqlite3.IntegrityError:
        return False
    finally:
        c.close()


def evening(out, by, send=None):
    """after NSE's closing file: every share showing a footprint that WORKS BOTH YEARS on the latest day -> one 🔭 EARLY line"""
    rows = {r["id"]: r for r in out["rows"] if r["verdict"] in WORKS}
    last = max((rs[-1]["d"] for rs in by.values() if rs), default=None)
    lines = []
    for sym, rs in by.items():
        if not rs or rs[-1]["d"] != last:
            continue
        r = rs[-1]
        for f in fires(rs, len(rs) - 1):
            if f not in rows:
                continue
            row = rows[f]
            side = "CE" if row["claim"] == UP else "PE" if row["claim"] == DN else ""
            if not side:
                continue
            pcr = (r["pe_oi"] / r["ce_oi"]) if r.get("ce_oi") and r.get("pe_oi") is not None else None
            detail = ("PCR %.2f near the price" % pcr) if pcr is not None and f.startswith("pcr") else ""
            if send is not None and not mark(last, sym, side, f, "evening"):
                continue
            t = early_text(sym, row, detail, "NSE's closing file %s" % last)
            lines.append(t)
            if send is not None:
                send(t)
            break
    return last, lines


def selftest():
    import random
    ok = True

    def check(name, good):
        nonlocal ok
        print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)
    random.seed(7)
    by = {}
    for s in range(60):
        rs, sp, foi, d = [], 1000.0, 1e6, 0
        import datetime as dt
        day = dt.date(2025, 1, 1)
        plant = 0
        while day <= dt.date(2026, 10, 30):
            if day.weekday() < 5:
                mv = random.gauss(0, 1.1)
                if plant == 1:
                    mv = 6.0                                         # planted: after 3 flat days of futures OI piling up, a 6% day
                if plant > 1:
                    mv = random.uniform(-0.3, 0.3); foi *= 1.05      # the planted build: OI +5% a day, the price flat
                plant = plant - 1 if plant else (4 if random.random() < 0.02 else 0)
                sp *= 1 + mv / 100
                foi *= 1 + random.uniform(-0.01, 0.01)
                rs.append({"d": str(day), "sym": "S%d" % s, "spot": sp, "foi": foi, "fvol": 1e5, "exp": day.strftime("%Y-%m"), "oexp": day.strftime("%Y-%m"),
                           "ce_oi": 1e5, "pe_oi": 1e5, "roof_k": None, "floor_k": None, "atm_k": None, "atm_ce": None, "atm_pe": None, "strikes": None})
            day += dt.timedelta(days=1)
        by["S%d" % s] = rs
    out = study(by)
    fa = next(r for r in out["rows"] if r["id"] == "fut_accum3")
    y = fa["years"].get("2025") or {}
    check("the planted footprint (futures OI piling up, price flat -> a 6%% day) is found: lift %sx · %s" % (y.get("lift"), fa["verdict"]),
          fa["verdict"] in WORKS and (y.get("lift") or 0) >= 1.5)
    ph = next(r for r in out["rows"] if r["id"] == "pcr_high")
    check("a footprint that never shows up is FEW CASES, not a winner (%s)" % ph["verdict"], ph["verdict"] == "FEW CASES")
    check("the mirror counts the big days and how many were warned (%s)" % out["mirror"].get("2025"),
          out["mirror"].get("2025", {}).get("big", 0) > 0 and out["mirror"]["2025"]["any"] > 0)
    t = table(out)
    check("the table prints", "EARLY-WARNING STUDY" in t and "WARNING WORKS EVERY YEAR" in t)
    print("\nEARLY-WARNING STUDY SELF-TEST %s" % ("PASSED" if ok else "FAILED"))
    return ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--test" in a:
        sys.exit(0 if selftest() else 1)
    if "--send" in a:                                   # the evening run (gir-early.timer): today's NSE file -> 🔭 EARLY lines to GIR Box Picks
        import datetime as _dt
        try:                                            # today's NSE file (published in the evening); a 'not there yet' mark is cleared so 21:45 retries
            import core, oistudy
            td_ = core.ist_now().date()
            c_ = oistudy.db(); c_.execute("delete from fetched where d=? and status='none'", (str(td_),)); c_.commit(); c_.close()
            print("fetched %d new days" % oistudy.fetch(_dt.date(2025, 1, 1), td_, quiet=True), flush=True)
            import nsextra                                # patch 121: the OI limit %, the delivery %, the FII positions
            ce_ = nsextra.db(); ce_.execute("delete from fetched where d=? and status='none'", (str(td_),)); ce_.commit(); ce_.close()
            print("new NSE files: %d" % nsextra.fetch_extra(td_ - _dt.timedelta(days=10), td_, quiet=True), flush=True)
        except Exception as ex:
            print("fetch: %s" % str(ex)[:120])
        out = study()
        try:
            import core
            json.dump(out, open(os.path.join(core.DATA, "earlystudy.json"), "w"), default=str)
            today_ = str(core.ist_now().date())
        except Exception:
            today_ = str(_dt.date.today())
        by = load()
        last = max((rs[-1]["d"] for rs in by.values() if rs), default=None)
        if last != today_:
            print("NSE's file for %s is not in yet (latest %s) - nothing sent; the next run tries again" % (today_, last)); sys.exit(0)
        import engine2, tgq
        last, lines = evening(out, by, send=engine2.tg_fo)
        tgq.flush(120)
        print("%s: %d EARLY lines sent to GIR Box Picks" % (last, len(lines)))
        for t in lines:
            print("  " + t.split("\n")[0])
        sys.exit(0)
    out = study()
    if "--study" in a or not a:
        t = table(out)
        print(t)
        try:
            import core
            d = core.DATA
        except Exception:
            d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
        open(os.path.join(d, "earlystudy.txt"), "w").write(t + "\n")
        json.dump(out, open(os.path.join(d, "earlystudy.json"), "w"), default=str)
    if "--today" in a:
        print(today(out))
PY_ES
cat > $D/p121test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p121test.py - MORE F&O DATA + 3 YEARS: NSE's OI-limit (MWPL), delivery and participant files read right; the old F&O
day files (before July 2024) converted and boiled like the new ones; the early-warning study with the new footprints and
'every year' verdicts. Sample files only (no network)."""
import os, sys, io, zipfile, tempfile, shutil, random, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import nsextra, oistudy, earlystudy

MW = "Date,ISIN,Scrip Name,NSE Symbol,MWPL,Open Interest,Limit for Next Day\n06-NOV-2026,INE1,ASTRAL LIMITED,ASTRAL,10000000,8650000,Ban\n06-NOV-2026,INE2,TITAN COMPANY,TITAN,40000000,12000000,No Fresh Positions\n"
m = nsextra.parse_mwpl(MW)
check("MWPL: ASTRAL's OI is 86.5%% of its limit: %s" % (m.get("ASTRAL"),), m.get("ASTRAL") == (10000000.0, 8650000.0, 86.5) and m["TITAN"][2] == 30.0)
DV = (" SYMBOL, SERIES, DATE1, PREV_CLOSE, OPEN_PRICE, HIGH_PRICE, LOW_PRICE, LAST_PRICE, CLOSE_PRICE, AVG_PRICE, TTL_TRD_QNTY, TURNOVER_LACS, NO_OF_TRADES, DELIV_QTY, DELIV_PER\n"
      "ASTRAL, EQ, 06-Nov-2026, 1340, 1300, 1310, 1200, 1210, 1206, 1250, 2500000, 31250, 90000, 1500000, 60.00\nASTRAL, BE, 06-Nov-2026, 1,1,1,1,1,1,1, 10, 1, 1, 5, 50.00\n")
d = nsextra.parse_deliv(DV)
check("delivery: ASTRAL EQ 60%% delivered (the BE line left out): %s" % (d.get("ASTRAL"),), d.get("ASTRAL") == (2500000.0, 1500000.0, 60.0))
PT = ('"Participant wise Open Interest (no. of contracts) in Equity Derivatives as on Nov 06, 2026"\n'
      "Client Type,Future Index Long,Future Index Short,Future Stock Long,Future Stock Short\t,Option Index Call Long\n"
      "Client,100,200,1000,2000,5\nFII,150000,250000,1500000,1200000,7\nTOTAL,1,1,1,1,1\n")
p = nsextra.parse_part(PT)
check("participants: FII stock futures long 15 L / short 12 L (the title line skipped): %s" % (p.get("FII"),), p.get("FII") == (150000.0, 250000.0, 1500000.0, 1200000.0))
OLD = ("INSTRUMENT,SYMBOL,EXPIRY_DT,STRIKE_PR,OPTION_TYP,OPEN,HIGH,LOW,CLOSE,SETTLE_PR,CONTRACTS,VAL_INLAKH,OPEN_INT,CHG_IN_OI,TIMESTAMP,\n"
       "FUTSTK,ABC,27-Jun-2024,0,XX,1000,1015,995,1010,1010,9000,1,600000,30000,14-JUN-2024,\n"
       "OPTSTK,ABC,27-Jun-2024,1020,CE,10,12,8,9,9,100,1,420000,200000,14-JUN-2024,\n"
       "OPTSTK,ABC,27-Jun-2024,980,PE,6,9,5,8,8,100,1,330000,180000,14-JUN-2024,\n"
       "OPTIDX,NIFTY,27-Jun-2024,23000,CE,1,1,1,1,1,1,1,1,1,14-JUN-2024,\n")
rows = oistudy.boil(nsextra.old_fo_to_udiff(OLD), dt.date(2024, 6, 14))
r = rows.get("ABC") or {}
check("the old F&O format (before July 2024) read like the new one: ABC price %s (the future's close), OI 6 L +0.3 L, roof %s, floor %s; NIFTY left out"
      % (r.get("spot"), r.get("roof_k"), r.get("floor_k")), r.get("spot") == 1010 and r.get("foi") == 600000 and r.get("fdoi") == 30000 and r.get("roof_k") == 1020 and r.get("floor_k") == 980 and "NIFTY" not in rows)

tmp = tempfile.mkdtemp()
try:
    nsextra.DB = os.path.join(tmp, "extra.db"); oistudy.DB = os.path.join(tmp, "oistudy.db")

    def zipped(name, txt):
        b = io.BytesIO(); z = zipfile.ZipFile(b, "w"); z.writestr(name, txt); z.close(); return b.getvalue()

    class R(object):
        def __init__(self, code, content=b""):
            self.status_code, self.content = code, content
    calls = []

    def get(url):
        calls.append(url)
        if "combineoi_06112026" in url:
            return R(200, zipped("combineoi_06112026.csv", MW))
        if "sec_bhavdata_full_06112026" in url:
            return R(200, DV.encode())
        if "fao_participant_oi_06112026" in url:
            return R(200, PT.encode())
        if "fo14JUN2024bhav" in url:
            return R(200, zipped("fo14JUN2024bhav.csv", OLD))
        return R(404)
    n = nsextra.fetch_extra(dt.date(2026, 11, 5), dt.date(2026, 11, 6), get=get, quiet=True)
    c = nsextra.db()
    got = c.execute("select (select count(*) from mwpl), (select count(*) from deliv), (select count(*) from part), (select count(*) from fetched where status='none')").fetchone()
    c.close()
    check("the three files of 6 Nov stored; 5 Nov had none (marked, not retried): %s" % (got,), n == 3 and got == (2, 1, 3, 3))
    k = len(calls)
    nsextra.fetch_extra(dt.date(2026, 11, 5), dt.date(2026, 11, 6), get=get, quiet=True)
    check("a second run reads nothing again (it resumes)", len(calls) == k)
    n2 = nsextra.fetch_old_fo(dt.date(2024, 6, 14), dt.date(2024, 6, 14), get=get, quiet=True)
    c = oistudy.db()
    sp = c.execute("select spot, roof_k from day where d='2024-06-14' and sym='ABC'").fetchone(); c.close()
    check("an old F&O day (14 Jun 2024): the new address answers 404, the old file is read and stored: %s" % (sp,), n2 == 1 and sp == (1010.0, 1020.0))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

# the study with the new footprints, over 3 years
random.seed(9)
by = {}
for s in range(50):
    rs, sp, day, plant = [], 1000.0, dt.date(2024, 1, 1), 0
    while day <= dt.date(2026, 10, 30):
        if day.weekday() < 5:
            mv = random.gauss(0, 1.0)
            dp = random.uniform(30, 40)
            if plant in (3, 2):
                dp, mv = 70.0, random.uniform(-0.3, 0.3)           # planted: delivery 2x with the price flat ...
            if plant == 1:
                mv = 6.0                                            # ... then a 6% rise
            plant = plant - 1 if plant else (3 if random.random() < 0.03 else 0)
            sp *= 1 + mv / 100
            rs.append({"d": str(day), "sym": "S%d" % s, "spot": sp, "foi": 1e6, "fvol": 1e5, "exp": day.strftime("%Y-%m"), "oexp": day.strftime("%Y-%m"),
                       "ce_oi": 1e5, "pe_oi": 1e5, "roof_k": None, "floor_k": None, "atm_k": None, "atm_ce": None, "atm_pe": None, "strikes": None,
                       "dp": dp, "mwpl_pct": 40.0, "fii_sl": 1e6, "fii_ss": 1e6})
        day += dt.timedelta(days=1)
    by["S%d" % s] = rs
out = earlystudy.study(by)
da = next(r for r in out["rows"] if r["id"] == "deliv_acc")
check("3 years in the study: %s" % out["years"], out["years"] == ["2024", "2025", "2026"])
check("the planted footprint (high delivery, price flat -> a 6%% rise) is found in every year: %s · lifts %s" % (da["verdict"], [v["lift"] for v in da["years"].values()]),
      da["verdict"] == "WARNING WORKS EVERY YEAR" and da["verdict"] in earlystudy.WORKS)
check("a footprint that never shows up is FEW CASES", next(r for r in out["rows"] if r["id"] == "mwpl_80")["verdict"] == "FEW CASES")
src = open(os.path.join(B, "earlystudy.py"), encoding="utf-8").read()
check("the evening run (19:45 / 21:45) also brings in the new NSE files", "nsextra.fetch_extra(td_ - _dt.timedelta(days=10), td_, quiet=True)" in src)
print("\nP121 MORE DATA + 3 YEARS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cp $W/nsextra.py $D/nsextra.py; cp $W/earlystudy.py $D/earlystudy.py
cd $D && python3 -m py_compile nsextra.py earlystudy.py p121test.py || back
timeout 300 python3 p121test.py 2>&1 | grep "OK  \|FAIL\|YEARS TEST"
timeout 300 python3 p121test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
timeout 120 python3 earlystudy.py --test >/dev/null 2>&1 || { echo "the study self-test failed"; back; }
for t in p116test.py p118test.py p119test.py p120test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo "--- can this server read the new NSE files? (one day each, nothing stored):"
timeout 120 python3 nsextra.py --probe 2>&1 | grep -v "^20[0-9][0-9]-"
systemctl restart gir-intraday && sleep 10
echo "engine: $(systemctl is-active gir-intraday)"
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "the engine did not come back"; back; }
TO=$(TZ=Asia/Kolkata date +%Y-%m-%d)
JOB="cd $D && nice -n 19 python3 nsextra.py --fetch 2023-11-01 $TO && nice -n 19 python3 earlystudy.py --study --today"
if command -v systemd-run >/dev/null; then
  systemd-run --unit=gir-history --collect -p StandardOutput=append:$D/data/history.log -p StandardError=append:$D/data/history.log /bin/bash -c "$JOB" >/dev/null 2>&1 \
    && echo "--- the history downloads started in the background (gir-history, about 35 min)" || { nohup /bin/bash -c "$JOB" >> $D/data/history.log 2>&1 & echo "--- the history downloads started in the background (about 35 min)"; }
else
  nohup /bin/bash -c "$JOB" >> $D/data/history.log 2>&1 &
  echo "--- the history downloads started in the background (about 35 min)"
fi
echo
echo "PATCH 121 APPLIED. In about 35 minutes:"
echo "    how far it is:     cd $D && python3 nsextra.py --status; tail -3 data/history.log"
echo "    the new results:   cat $D/data/earlystudy.txt   (send me a photo)"
