#!/bin/bash
# PATCH 266 - THE MY P&L UPLOAD TAKES EXCEL TOO (Rama, 14 Nov: "can't upload - it says not a Zerodha file": Console gives .xlsx, 265 read CSV only).
#   Excel (.xlsx) or CSV · every sheet that is a P&L statement (F&O / equity) or a tradebook is kept · Excel date numbers read · a sheet without
#   the title line is told apart by its symbols. Tested: 8 cases. Restarts the page server and the P&L reader - after 15:35 on a trading day (or: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 265" $D/home.html && [ -f $D/pnlbook.py ] || { echo "patch 265 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/pnlbook.py $D/pnlbook.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/pnlbook.py.bak$TS $D/pnlbook.py; systemctl restart gir-dash gir-pnlwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pnlbook.py <<'PY_PB'
#!/usr/bin/env python3
"""pnlbook.py - patch 265 (+ 266: Excel files too): 📈 MY P&L for the MY F&O tab (Rama, 14 Nov: "a profit and loss chart from my sheet and your Zerodha readings - tick by tick").
  watch     (service gir-pnlwatch) every 3 s 09:15-15:30: the account's F&O positions (READ ONLY - never an order) -> today's P&L ticks
            (data/pnl_live/DAY.json) · at the close the day's total -> data/pnl_days.json (the day-by-day chart grows each day)
  get()     what the page draws: today's ticks (since a time), the open positions, the days, the statement's picture
  upload()  a CSV from the page: Zerodha's P&L statement (F&O or equity) or the tradebook (dated trades -> the days since June)
Your numbers stay on this server (data/), never in the code or on GitHub.   python3 pnlbook.py watch | show"""
import os, re, io, csv, sys, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DATA = os.path.join(BASE, "data")
LIVE = os.path.join(DATA, "pnl_live")
DAYS = os.path.join(DATA, "pnl_days.json")
ST_FO, ST_EQ, TB = os.path.join(DATA, "pnl_statement_fo.csv"), os.path.join(DATA, "pnl_statement_eq.csv"), os.path.join(DATA, "pnl_tradebook.csv")
EVERY = 3
OPT = re.compile(r"^([A-Z0-9][A-Z0-9&\-]*?)(\d{2})([A-Z]{3}|[1-9OND]\d{2})([\d.]+)(CE|PE)$")
FUT = re.compile(r"^([A-Z][A-Z0-9&\-]*?)(\d{2})([A-Z]{3})FUT$")


def _load(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def _save(p, v):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(v, open(p + ".tmp", "w"), separators=(",", ":"), default=str); os.replace(p + ".tmp", p)


def fo(P):
    return [p for p in (P or []) if p.get("exchange") in ("NFO", "BFO")]


def reading(P):
    """positions -> (today's P&L, open now, booked today, rows)"""
    P = fo(P)
    day = sum(float(p.get("m2m") if p.get("m2m") is not None else (p.get("pnl") or 0)) for p in P)
    opn = sum(float(p.get("unrealised") if p.get("unrealised") is not None else ((p.get("pnl") or 0) if p.get("quantity") else 0)) for p in P if p.get("quantity"))
    rows = [{"ts": p.get("tradingsymbol"), "q": int(p.get("quantity") or 0), "avg": round(float(p.get("average_price") or 0), 2),
             "ltp": round(float(p.get("last_price") or 0), 2), "pnl": round(float(p.get("pnl") or 0)), "m2m": round(float(p.get("m2m") or 0))} for p in P]
    return round(day), round(opn), round(day - opn), rows


def record(now, P):
    """one tick into today's file; at 15:30+ the day's total into the days"""
    d = str(now.date())
    p = os.path.join(LIVE, d + ".json")
    j = _load(p, {"t": [], "v": [], "o": []})
    day, opn, _bk, rows = reading(P)
    j["t"].append(int(now.timestamp())); j["v"].append(day); j["o"].append(opn)
    j["rows"], j["at"] = rows, now.strftime("%H:%M:%S")
    _save(p, j)
    if now.strftime("%H:%M") >= "15:30":
        D = _load(DAYS, {}); D[d] = day; _save(DAYS, D)
    return day


def watch():
    kite, last_err = None, 0
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            kite = None; time.sleep(20); continue
        try:
            if kite is None:
                import core
                kite = core.get_kite()
            record(now, kite.positions().get("net") or [])
        except Exception as ex:
            kite = None
            if time.time() - last_err > 300:
                print("%s %s" % (hm, str(ex)[:120]), flush=True); last_err = time.time()
            time.sleep(10)
        time.sleep(EVERY)


# ---------------- the statement / the tradebook ----------------
def _rows(raw):
    return list(csv.reader(io.StringIO(raw)))


def kind_of(raw):
    """patch 266: tolerant - Zerodha's title line, or the table's own header (Symbol + Realized P&L / trade_date + trade_type)"""
    head = raw[:6000].lower()
    if "trade_date" in head and "trade_type" in head:
        return "tradebook"
    if "p&l statement for f&o" in head or "p&l statement for futures" in head or "statement for f&o" in head:
        return "fo"
    if "p&l statement for equity" in head or "statement for equity" in head:
        return "eq"
    if "symbol" in head and "realized p&l" in head:                  # no title: tell F&O from equity by the symbols
        _s, C = statement(raw)
        if C:
            n = sum(1 for c in C if OPT.match(c[0]) or FUT.match(c[0]))
            return "fo" if n * 2 >= len(C) else "eq"
    return None


def _col(ref):
    m = re.match(r"([A-Z]+)", ref or "")
    if not m:
        return None
    n = 0
    for ch in m.group(1):
        n = n * 26 + ord(ch) - 64
    return n - 1


def xlsx_texts(b):
    """patch 266: an Excel file (.xlsx) -> one CSV text per sheet (no extra library: the file is a zip of XML)"""
    import zipfile, xml.etree.ElementTree as ET
    M = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
    z = zipfile.ZipFile(io.BytesIO(b))
    names = z.namelist()
    ss = []
    if "xl/sharedStrings.xml" in names:
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).iter(M + "si"):
            ss.append("".join(t.text or "" for t in si.iter(M + "t")))
    out = []
    for n in sorted((x for x in names if re.match(r"xl/worksheets/sheet\d+\.xml$", x)), key=lambda x: int(re.findall(r"\d+", x)[-1])):
        rows = []
        for r in ET.fromstring(z.read(n)).iter(M + "row"):
            cells, nxt = {}, 0
            for c in r.findall(M + "c"):
                i = _col(c.get("r"))
                i = nxt if i is None else i
                t, v = c.get("t"), c.find(M + "v")
                if t == "s" and v is not None:
                    val = ss[int(v.text)]
                elif t == "inlineStr":
                    val = "".join(x.text or "" for x in c.iter(M + "t"))
                else:
                    val = v.text if v is not None and v.text is not None else ""
                cells[i] = val; nxt = i + 1
            rows.append([cells.get(i, "") for i in range(max(cells) + 1)] if cells else [])
        buf = io.StringIO(); csv.writer(buf).writerows(rows); out.append(buf.getvalue())
    return out


def _xdate(x):
    """patch 266: an Excel date number (46340 / 46340.4) -> 'YYYY-MM-DD HH:MM:SS'; text stays text"""
    try:
        f = float(x)
    except (TypeError, ValueError):
        return x
    if 20000 < f < 80000:
        return (dt.datetime(1899, 12, 30) + dt.timedelta(days=f)).strftime("%Y-%m-%d %H:%M:%S")
    return x


def statement(raw):
    """Zerodha's P&L statement -> {summary, contracts: [(symbol, realised)]}"""
    R = _rows(raw); summ, out, hdr = {}, [], None
    for r in R:
        c = [x.strip() for x in r]
        if len(c) > 2 and c[1] in ("Charges", "Other Credit & Debit", "Realized P&L", "Unrealized P&L") and hdr is None:
            try:
                summ[c[1]] = float(c[2])
            except ValueError:
                pass
        if len(c) > 6 and c[1] == "Symbol":
            hdr = c; continue
        if hdr and len(c) > 6 and c[1]:
            try:
                out.append((c[1], float(c[hdr.index("Realized P&L")] or 0), float(c[hdr.index("Unrealized P&L")] or 0) if "Unrealized P&L" in hdr else 0.0,
                            float(c[hdr.index("Buy Value")] or 0) if "Buy Value" in hdr else 0.0))
            except (ValueError, IndexError):
                continue
    return summ, out


def picture_fo(raw):
    summ, C = statement(raw)
    if not C:
        return None
    months, shares, side = {}, {}, {"CE": [0, 0, 0.0], "PE": [0, 0, 0.0], "FUT": [0, 0, 0.0]}
    small = [0, 0.0]
    for s, r, u, buy in C:
        m = OPT.match(s) or FUT.match(s)
        if not m:
            continue
        und, mon = m.group(1), m.group(3)
        k = m.group(5) if OPT.match(s) else "FUT"
        months[mon] = months.get(mon, 0.0) + r
        shares[und] = shares.get(und, 0.0) + r
        side[k][0] += 1; side[k][1] += r > 0; side[k][2] += r
        if 0 < buy < 30000:
            small[0] += 1; small[1] += r
    order = {m: i for i, m in enumerate("JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC".split())}
    W = [r for _s, r, _u, _b in C if r > 0]; L = [r for _s, r, _u, _b in C if r < 0]
    sh = sorted(shares.items(), key=lambda x: -x[1])
    return {"realised": round(summ.get("Realized P&L", sum(r for _s, r, _u, _b in C))), "charges": round(summ.get("Charges", 0)),
            "net": round(summ.get("Realized P&L", 0) - summ.get("Charges", 0) + summ.get("Other Credit & Debit", 0)),
            "n": len(C), "won": len(W), "avg_win": round(sum(W) / len(W)) if W else 0, "avg_loss": round(sum(L) / len(L)) if L else 0,
            "months": [[m, round(v)] for m, v in sorted(months.items(), key=lambda x: order.get(x[0], 99))],
            "best": [[s, round(v)] for s, v in sh[:6] if v > 0], "worst": [[s, round(v)] for s, v in sh[::-1][:6] if v < 0],
            "side": {k: [v[0], v[1], round(v[2])] for k, v in side.items() if v[0]}, "small": [small[0], round(small[1])]}


def picture_eq(raw):
    summ, C = statement(raw)
    if not C and not summ:
        return None
    return {"realised": round(summ.get("Realized P&L", 0)), "unrealised": round(summ.get("Unrealized P&L", 0)), "charges": round(summ.get("Charges", 0)),
            "trades": [[s, round(r)] for s, r, _u, _b in C if r], "holdings": [[s, round(u)] for s, _r, u, _b in C if u]}


def tradebook_days(raw):
    """Zerodha's tradebook -> {day: realised P&L} (first in, first out per contract; before charges)"""
    rd = csv.DictReader(io.StringIO(raw))
    T = []
    for r in rd:
        r = {(k or "").strip().lower(): (v or "").strip() for k, v in r.items()}
        try:
            td = _xdate(r["trade_date"])
            T.append((_xdate(r.get("order_execution_time")) or td, td[:10], r["symbol"], r["trade_type"].lower(), float(r["quantity"]), float(r["price"])))
        except (KeyError, ValueError):
            continue
    T.sort()
    book, days = {}, {}
    for _t, d, s, side, q, px in T:
        lots = book.setdefault(s, [])                                   # [(signed qty, price)] open, first in first out
        sg = 1 if side == "buy" else -1
        while q > 1e-9 and lots and (lots[0][0] > 0) != (sg > 0):
            oq, op = lots[0]; m = min(q, abs(oq))
            days[d] = days.get(d, 0.0) + (px - op) * m * (1 if oq > 0 else -1)
            q -= m
            lots[0] = (oq - m * (1 if oq > 0 else -1), op)
            if abs(lots[0][0]) < 1e-9:
                lots.pop(0)
        if q > 1e-9:
            lots.append((sg * q, px))
    return {d: round(v) for d, v in sorted(days.items())}


def upload(raw):
    """patch 266: a CSV or an Excel file (.xlsx) from Zerodha Console -> kept in data/ (every sheet that is a P&L statement or a tradebook)"""
    if isinstance(raw, (bytes, bytearray)) and raw[:2] == b"PK":
        try:
            texts = xlsx_texts(bytes(raw))
        except Exception as ex:
            raise ValueError("the Excel file could not be read (%s)" % str(ex)[:60])
    else:
        texts = [raw.decode("utf-8-sig", "replace") if isinstance(raw, (bytes, bytearray)) else raw]
    os.makedirs(DATA, exist_ok=True)
    said = []
    for t in texts:
        k = kind_of(t)
        if k is None:
            continue
        open({"fo": ST_FO, "eq": ST_EQ, "tradebook": TB}[k], "w", encoding="utf-8").write(t)
        if k == "fo":
            x = picture_fo(t); said.append("F&O P&L statement (%d contracts)" % (x["n"] if x else 0))
        elif k == "eq":
            said.append("equity P&L statement")
        else:
            said.append("tradebook (%d days)" % len(tradebook_days(t)))
    if not said:
        raise ValueError("this is not a Zerodha P&L statement or tradebook - in Console: Reports → P&L (or Tradebook) → download, Excel or CSV")
    return {"saved": " + ".join(said)}


def _read(p):
    try:
        return open(p, encoding="utf-8").read()
    except Exception:
        return None


def get(since=0, now=None):
    now = now or dt.datetime.now(IST)
    d = str(now.date())
    j = _load(os.path.join(LIVE, d + ".json"), None)
    if j is None:                                                      # before the open / a holiday: the last day recorded
        fs = sorted(f for f in (os.listdir(LIVE) if os.path.isdir(LIVE) else []) if f.endswith(".json"))
        if fs:
            j = _load(os.path.join(LIVE, fs[-1]), None); d = fs[-1][:-5]
    out = {"day": d, "t": [], "v": [], "o": [], "rows": [], "at": None}
    if j:
        i = 0
        if since:
            while i < len(j["t"]) and j["t"][i] <= since:
                i += 1
        out.update({"t": j["t"][i:], "v": j["v"][i:], "o": j["o"][i:], "rows": j.get("rows") or [], "at": j.get("at"), "n": len(j["t"])})
        if j["v"]:
            out.update({"now": j["v"][-1], "open": j["o"][-1], "hi": max(j["v"]), "lo": min(j["v"])})
    if since:
        return out
    days = {}
    tb = _read(TB)
    if tb:
        days.update(tradebook_days(tb))
    days.update({k: v for k, v in _load(DAYS, {}).items()})            # GIR's own readings win
    out["days"] = sorted(days.items())
    f, e = _read(ST_FO), _read(ST_EQ)
    out["fo"] = picture_fo(f) if f else None
    out["eq"] = picture_eq(e) if e else None
    out["live"] = os.path.isdir(LIVE)
    return out


if __name__ == "__main__":
    if sys.argv[1:2] == ["watch"]:
        watch()
    else:
        print(json.dumps(get(), indent=1, default=str)[:3000])
PY_PB
cat > $W/p266_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p266_patch.py - patch 266: the MY P&L upload takes Excel (.xlsx) as well as CSV - the page sends the file as it is.  python3 p266_patch.py DIR"""
import os, sys
D = sys.argv[1]
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 266" in s:
    print("  home.html: patch 266 - already in"); sys.exit(0)
E = [('{method:"POST",headers:{"Content-Type":"text/csv"},body:await f.text()}', '{method:"POST",headers:{"Content-Type":"application/octet-stream"},body:f}/* patch 266: as it is - Excel or CSV */', "the file goes as it is"),
     ('<b>UPLOAD</b> a CSV from Zerodha Console', '<b>UPLOAD</b> the Excel or CSV file from Zerodha Console', "the words"),
     ('<input type="file" accept=".csv,text/csv" onchange="pnlUp(this)">', '<input type="file" accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" onchange="pnlUp(this)">', "Excel files can be chosen")]
for o, n, tag in E:
    if s.count(o) != 1:
        print("❌ home.html: anchor for '%s' found %d times (patch 265 first)" % (tag, s.count(o))); sys.exit(1)
    s = s.replace(o, n); print("  home.html: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("patch 266 in")
PY_PATCH
cat > $W/p266test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p266test.py - the MY P&L upload with Excel (.xlsx) files built here (temp folder, nothing sent).  python3 p266test.py DIR"""
import os, io, sys, json, shutil, zipfile, tempfile
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "pnlbook.py"), T)
sys.path.insert(0, T); os.chdir(T)
import pnlbook as P
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
def xlsx(sheets, shared=True):
    """sheets: [[row, ...], ...] - cells: str or number, from column B like Zerodha"""
    b = io.BytesIO(); z = zipfile.ZipFile(b, "w"); SS = []
    for si, rows in enumerate(sheets, 1):
        x = ['<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>']
        for ri, row in enumerate(rows, 1):
            x.append('<row r="%d">' % ri)
            for ci, v in enumerate(row):
                ref = "%s%d" % (chr(66 + ci), ri)
                if isinstance(v, (int, float)):
                    x.append('<c r="%s"><v>%s</v></c>' % (ref, v))
                elif shared:
                    SS.append(v); x.append('<c r="%s" t="s"><v>%d</v></c>' % (ref, len(SS) - 1))
                else:
                    x.append('<c r="%s" t="inlineStr"><is><t>%s</t></is></c>' % (ref, v.replace("&", "&amp;")))
            x.append("</row>")
        x.append("</sheetData></worksheet>")
        z.writestr("xl/worksheets/sheet%d.xml" % si, "".join(x))
    if SS:
        z.writestr("xl/sharedStrings.xml", '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
                   "".join("<si><t>%s</t></si>" % v.replace("&", "&amp;") for v in SS) + "</sst>")
    z.close(); return b.getvalue()
HDR = ["Symbol", "ISIN", "Quantity", "Buy Value", "Sell Value", "Realized P&L", "Realized P&L Pct.", "Previous Closing Price", "Open Quantity", "Open Quantity Type", "Open Value", "Unrealized P&L", "Unrealized P&L Pct."]
FO = [[], ["Client ID", "XX0000"], [], ["P&L Statement for F&O from 2026-06-01 to 2026-11-14"], ["Summary"], ["Charges", 1000.5], ["Other Credit & Debit", 0], ["Realized P&L", 25000], ["Unrealized P&L", 0], [], HDR,
      ["AAA26NOV100CE", "", 100, 50000, 80000, 30000, 60, 0, 0, "", 0, 0, 0], ["BBB26OCT200PE", "", 100, 20000, 15000, -5000, -25, 0, 0, "", 0, 0, 0]]
r = P.upload(xlsx([FO]))
x = P.picture_fo(open(P.ST_FO).read())
chk("an Excel F&O P&L statement (shared text cells, like Zerodha's): saved and read - realised ₹25,000, 2 contracts", "F&O P&L statement (2 contracts)" in r["saved"] and x["realised"] == 25000 and x["n"] == 2, (r, x))
EQ = [[], ["P&L Statement for Equity from 2026-06-01 to 2026-11-14"], ["Summary"], ["Charges", 300], ["Realized P&L", -1500], ["Unrealized P&L", 4000], [], HDR,
      ["XYZ", "INE0", 10, 1000, 900, -100, -10, 0, 0, "", 0, 0, 0], ["HOLD1", "INE1", 0, 0, 0, 0, 0, 500, 10, "", 5000, 4000, 80]]
r = P.upload(xlsx([EQ], shared=False))
chk("an Excel equity statement (inline text cells): saved", r["saved"] == "equity P&L statement" and os.path.exists(P.ST_EQ), r)
r = P.upload(xlsx([FO, EQ]))
chk("one Excel file with both sheets: both saved", "F&O" in r["saved"] and "equity" in r["saved"], r)
TBH = ["symbol", "isin", "trade_date", "exchange", "segment", "series", "trade_type", "auction", "quantity", "price", "trade_id", "order_id", "order_execution_time", "expiry_date"]
TBR = [TBH, ["AAA26NOV100CE", "", 46336, "NSE", "FO", "", "buy", "false", 100, 50, 1, 1, 46336.42, "2026-11-24"],
       ["AAA26NOV100CE", "", 46336, "NSE", "FO", "", "sell", "false", 100, 60, 2, 2, 46336.5, "2026-11-24"]]
r = P.upload(xlsx([[row[:] for row in TBR]]))
chk("an Excel tradebook with Excel date numbers (46336 = 10 Nov 2026): +₹1,000 on 10 Nov", "tradebook (1 days)" in r["saved"] and P.tradebook_days(open(P.TB).read()) == {"2026-11-10": 1000}, (r, P.tradebook_days(open(P.TB).read())))
csvt = "\n".join(",".join([""] + [str(c) for c in row]) for row in FO)
r = P.upload(csvt.encode())
chk("CSV still works", "F&O P&L statement" in r["saved"], r)
NOTITLE = [HDR, ["AAA26NOV100CE", "", 100, 50000, 80000, 30000, 60, 0, 0, "", 0, 0, 0]]
r = P.upload(xlsx([NOTITLE]))
chk("a sheet with no title line: told apart by its symbols (options -> F&O)", "F&O" in r["saved"], r)
for bad, lab in ((b"PK\x03\x04garbage", "a broken Excel file"), (xlsx([[["hello", "world"]]]), "an Excel file with something else")):
    try:
        P.upload(bad); ok = False
    except ValueError as ex:
        ok = True; msg = str(ex)
    chk("%s is refused with a plain reason" % lab, ok, msg if ok else "accepted")
print("UPLOAD (Excel / CSV) test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p266_patch.py $D || back
cd $D && python3 -m py_compile pnlbook.py || back
echo "=== test"
python3 $W/p266test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash gir-pnlwatch; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-pnlwatch: $(systemctl is-active gir-pnlwatch)"
echo "✅ patch 266 done - Ctrl + Shift + R on GIR, then 9 MY F&O → MY RECORD → choose your Zerodha file (Excel or CSV)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/pnlbook.py.bak$TS $D/pnlbook.py; systemctl restart gir-dash gir-pnlwatch"
