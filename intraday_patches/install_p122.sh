#!/bin/bash
# PATCH 122 - the FII / DII positions file read right (patch 121 read 0 rows from NSE's real file: its title line looked
#   like the header). nsextra.py only. When the running history download (gir-history) ends, the participant files are
#   read again (the days it marked 'no file' are cleared) and the early-warning study runs once more. No restart.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g122; mkdir -p $W
[ -f $D/nsextra.py ] || { echo "patch 121 is not installed yet - paste patch 121 first"; exit 1; }
grep -q "patch 122" $D/nsextra.py && { echo "patch 122 is already installed"; exit 1; }
cp $D/nsextra.py $D/nsextra.py.bak$TS
back() { cp $D/nsextra.py.bak$TS $D/nsextra.py; rm -f $D/p122test.py; echo "ERROR - old file back, nothing changed"; exit 1; }
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


def _rows(txt, key=None):
    """csv text -> list of dicts with stripped, lower-case keys (NSE files carry spaces, a byte-order mark and a title line
    now and then). key: a word the header line must hold (patch 122: the participant file's title line looked like a header)"""
    lines = [l.lstrip("\ufeff") for l in txt.lstrip("\ufeff").splitlines() if l.strip(" ,\t\r")]
    for i, l in enumerate(lines[:8]):                          # the header is the first line with 3+ commas and letters
        if key and key not in l.lower():
            continue
        if l.count(",") >= 3 and re.search(r"[A-Za-z]", l) and (key or not re.match(r'^\s*"?participant wise', l, re.I)):
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
    for r in _rows(txt, key="client type"):
        who = (r.get("client type") or "").strip(' "').upper()
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
                    if st == "ok" and not parsed:                # patch 122: show what the file starts with, so the reader can be fixed
                        r_ = get(url_for(src, dd))
                        print("         the file starts: %r" % _body(r_)[:300])
            except Exception as ex:
                print("  %-6s %s: FAILED %s" % (src, dd, str(ex)[:90]))
        sys.exit(0)
    if a[:1] == ["--fetch"] and len(a) >= 3:
        d0, d1 = fd(a[1]), fd(a[2])
        print("old F&O days: %d new" % fetch_old_fo(d0, min(d1, dt.date(2024, 12, 31))), flush=True)
        print("extra files: %d new" % fetch_extra(d0, d1), flush=True)
        sys.exit(0)
    if a[:1] == ["--refetch"] and len(a) >= 4:              # patch 122: one source again (its 'no file' marks cleared)
        c_ = db(); c_.execute("delete from fetched where src=? and status='none'", (a[1],)); c_.commit(); c_.close()
        print("%s: %d files stored" % (a[1], fetch_extra(fd(a[2]), fd(a[3]), sources=(a[1],))), flush=True)
        sys.exit(0)
    if a[:1] == ["--status"]:
        status(); sys.exit(0)
    print(__doc__)
PY_NX
cat > $D/p122test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p122test.py - the FII / DII participant file read in its real shapes (a byte-order mark, a title line full of commas,
quoted names, spaces, Windows line ends)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nsextra
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


T1 = ('﻿"Participant wise Open Interest (no. of contracts) in Equity Derivatives as on Nov 06, 2026",,,,,,,,,,,,,,\n'
      'Client Type,Future Index Long,Future Index Short,Future Stock Long,Future Stock Short\t,Option Index Call Long\nClient,1,2,3,4,5\n"FII",150000,250000,1500000,1200000,7\nTOTAL,1,1,1,1,1\n')
T2 = ('Participant wise Open Interest (no. of contracts) in Equity Derivatives as on Nov 06, 2026,,,,,\n\n'
      'Client Type ,Future Index Long ,Future Index Short ,Future Stock Long ,Future Stock Short ,x\r\nFII ,150000 ,250000 ,1500000 ,1200000 ,7\r\n')
for i, t in enumerate((T1, T2)):
    p = nsextra.parse_part(t)
    check("participant file shape %d: FII stock futures long 15 L / short 12 L: %s" % (i + 1, p.get("FII")), p.get("FII") == (150000.0, 250000.0, 1500000.0, 1200000.0))
m = nsextra.parse_mwpl("Date,ISIN,Scrip Name,NSE Symbol,MWPL,Open Interest,Limit for Next Day\n06-NOV-2026,INE1,X,ASTRAL,100,86.5,Ban\n")
check("the OI-limit file still reads (ASTRAL 86.5%%): %s" % (m.get("ASTRAL"),), m.get("ASTRAL") == (100.0, 86.5, 86.5))
print("\nP122 PARTICIPANT FILE TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cp $W/nsextra.py $D/nsextra.py
cd $D && python3 -m py_compile nsextra.py p122test.py || back
timeout 60 python3 p122test.py 2>&1 | grep "OK  \|FAIL\|FILE TEST"
timeout 60 python3 p122test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
[ -f p121test.py ] && { timeout 300 python3 p121test.py >/dev/null 2>&1 && echo "    p121test.py passed" || { echo "p121test.py failed"; back; }; }
echo "--- the participant file now (one day, nothing stored):"
timeout 60 python3 nsextra.py --probe 2>&1 | grep -A1 "^  part"
TO=$(TZ=Asia/Kolkata date +%Y-%m-%d)
JOB="while systemctl is-active --quiet gir-history; do sleep 30; done; cd $D && nice -n 19 python3 nsextra.py --refetch part 2023-11-01 $TO && nice -n 19 python3 earlystudy.py --study --today"
if command -v systemd-run >/dev/null; then
  systemd-run --unit=gir-history2 --collect -p StandardOutput=append:$D/data/history.log -p StandardError=append:$D/data/history.log /bin/bash -c "$JOB" >/dev/null 2>&1 || nohup /bin/bash -c "$JOB" >> $D/data/history.log 2>&1 &
else
  nohup /bin/bash -c "$JOB" >> $D/data/history.log 2>&1 &
fi
echo
echo "PATCH 122 APPLIED. The FII / DII files are read again after the history download (about 45 min in all)."
echo "    how far it is:     cd $D && python3 nsextra.py --status; tail -3 data/history.log"
echo "    the new results:   cat $D/data/earlystudy.txt   (when 'part' shows days in the status)"
