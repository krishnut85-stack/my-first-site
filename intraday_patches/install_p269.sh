#!/bin/bash
# PATCH 269 - MY F&O ALL AUTOMATIC (Rama, 14 Nov: "the tabs have the upload CSV - since you read online we don't need them; think as a human" ·
#   "we have no December trade but GIR shows DEC"). The upload box and the old typed-in ledger (CAPITAL / ADD TRADE) go. A 💰 ZERODHA strip: cash
#   available, margin in use, holdings value and P&L - read from the account (READ ONLY) every minute in market hours, every 30 min outside.
#   BARS view: a short note under the chart (it listed all 66 dates).
#   MY RECORD's months are the months you TRADED (your tradebook) - DEC was the expiry month of a NIFTY December option traded in November.
#   Tested: 4 cases + 267's 7. Restarts the page server and the P&L reader - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 267" $D/home.html && [ -f $D/pnlbook.py ] || { echo "patch 267 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/pnlbook.py $D/pnlbook.py.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/pnlbook.py.bak$TS $D/pnlbook.py; systemctl restart gir-dash gir-pnlwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pnlbook.py <<'PY_PB'
#!/usr/bin/env python3
"""pnlbook.py - patch 265 (+ 266: Excel files too · 267: the statement carried into DAY BY DAY · 269: funds and holdings from Zerodha): 📈 MY P&L for the MY F&O tab (Rama, 14 Nov: "a profit and loss chart from my sheet and your Zerodha readings - tick by tick").
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


FUNDS = os.path.join(DATA, "pnl_funds.json")


def funds(kite, now=None):
    """patch 269: the account's money from Zerodha (read only): cash available, margin in use, the holdings' value and P&L"""
    now = now or dt.datetime.now(IST)
    out = {"at": now.strftime("%d %b %H:%M"), "t": int(now.timestamp())}
    try:
        e = (kite.margins() or {}).get("equity") or {}
        av, ut = e.get("available") or {}, e.get("utilised") or {}
        out.update({"avail": round(float(e.get("net") or 0)), "used": round(float(ut.get("debits") or 0)), "opening": round(float(av.get("opening_balance") or 0))})
    except Exception as ex:
        out["err_m"] = str(ex)[:80]
    try:
        H = kite.holdings() or []
        val = sum(float(h.get("last_price") or 0) * int(h.get("quantity") or 0) for h in H)
        pl = sum(float(h.get("pnl") or 0) for h in H)
        day = sum(float(h.get("day_change") or 0) * int(h.get("quantity") or 0) for h in H)
        top = sorted(((h.get("tradingsymbol"), round(float(h.get("pnl") or 0))) for h in H), key=lambda x: -abs(x[1]))[:6]
        out.update({"h_n": len(H), "h_val": round(val), "h_pl": round(pl), "h_day": round(day), "h_top": top})
    except Exception as ex:
        out["err_h"] = str(ex)[:80]
    if "avail" in out or "h_n" in out:
        _save(FUNDS, out)
    return out


def watch():
    kite, last_err, last_f = None, 0, 0.0
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        live = now.weekday() <= 4 and "09:15" <= hm <= "15:30"
        try:
            if live or time.time() - last_f > 1800:                  # patch 269: funds every minute live, else every 30 min (weekends too)
                if kite is None:
                    import core
                    kite = core.get_kite()
                if time.time() - last_f > (60 if live else 1800):
                    funds(kite, now); last_f = time.time()
                if live:
                    record(now, kite.positions().get("net") or [])
        except Exception as ex:
            kite = None
            if live:
                last_f = time.time() - 50
            else:
                last_f = time.time()                                  # not ready (a weekend login) - try again in 30 min
            if time.time() - last_err > 300:
                print("%s %s" % (hm, str(ex)[:120]), flush=True); last_err = time.time()
            time.sleep(10)
        time.sleep(EVERY if live else 20)


# ---------------- the statement / the tradebook ----------------
def _rows(raw):
    return list(csv.reader(io.StringIO(raw)))


def kind_of(raw):
    """patch 266: tolerant - Zerodha's title line, or the table's own header (Symbol + Realized P&L / trade_date + trade_type)"""
    head = raw[:6000].lower()
    if ("trade_date" in head and "trade_type" in head) or ("trade date" in head and "trade type" in head):
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
    """Zerodha's tradebook -> {day: realised P&L} (first in, first out per contract; before charges)
    patch 267: Console's own file - title lines first, then "Symbol, ISIN, Trade Date, ... Trade Type ..." (spaces, capitals)"""
    R = list(csv.reader(io.StringIO(raw)))
    h = next((i for i, r in enumerate(R) if any((c or "").strip().lower() in ("trade_date", "trade date") for c in r)), None)
    if h is None:
        return {}
    keys = [re.sub(r"\s+", "_", (c or "").strip().lower()) for c in R[h]]
    T = []
    for row in R[h + 1:]:
        r = {k: (row[i] if i < len(row) else "").strip() for i, k in enumerate(keys) if k}
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


def history(raw):
    """patch 267: the P&L statement -> [(date, realised, month)] one point per expiry month up to the statement's end
    (the statement has no trade dates: each month sits at its month end; contracts expiring after the end sit at the end date)"""
    m = re.search(r"from (\d{4}-\d\d-\d\d) to (\d{4}-\d\d-\d\d)", raw[:3000])
    if not m:
        return []
    end = dt.date.fromisoformat(m.group(2))
    _s, C = statement(raw)
    order = {x: i + 1 for i, x in enumerate("JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC".split())}
    pts = {}
    for s, r, _u, _b in C:
        mm = OPT.match(s) or FUT.match(s)
        if not mm or mm.group(3) not in order:
            continue
        mo = order[mm.group(3)]
        y = end.year if mo <= end.month + 2 else end.year - 1
        last = (dt.date(y + (mo == 12), mo % 12 + 1, 1) - dt.timedelta(days=1))
        d = min(last, end)
        key = (str(d), "%s %d" % (mm.group(3), y) if d < end else "to %s" % end.strftime("%d %b"))
        pts[key] = pts.get(key, 0.0) + r
    return [(d, round(v), lab) for (d, lab), v in sorted(pts.items())]


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
    if tb and not tradebook_days(tb):
        tb = None
    if tb:
        tbd = tradebook_days(tb)
        days.update(tbd)
        out["tb_last"] = max(tbd)                                     # patch 267: your trades up to here, GIR's live days after
    days.update({k: v for k, v in _load(DAYS, {}).items()})            # GIR's own readings win
    out["days"] = sorted(days.items())
    f, e = _read(ST_FO), _read(ST_EQ)
    out["fo"] = picture_fo(f) if f else None
    if out["fo"] and tb:                                              # patch 269: by the month you TRADED (the tradebook's dates), not the option's expiry month
        mm = {}
        for d_, v_ in tradebook_days(tb).items():
            k_ = dt.date.fromisoformat(d_).strftime("%b %Y").upper()
            mm.setdefault(d_[:7], [k_, 0])[1] += v_
        out["fo"]["months"] = [[mm[k][0], round(mm[k][1])] for k in sorted(mm)]
        out["fo"]["months_by"] = "trade"
    H = [] if tb else (history(f) if f else [])                     # patch 267: no tradebook -> the statement's months, then the live days
    if H:
        cut = H[-1][0]
        out["hist"] = H
        out["days"] = [x for x in out["days"] if x[0] > cut]
    hl = {}                                                           # patch 267: each live day's best and worst moment (the candle's wicks)
    for d_, _v in out["days"]:
        j_ = _load(os.path.join(LIVE, d_ + ".json"), None)
        if j_ and j_.get("v"):
            hl[d_] = [max(j_["v"]), min(j_["v"])]
    out["dayhl"] = hl
    out["eq"] = picture_eq(e) if e else None
    out["live"] = os.path.isdir(LIVE)
    out["funds"] = _load(FUNDS, None)                                 # patch 269
    return out


if __name__ == "__main__":
    if sys.argv[1:2] == ["watch"]:
        watch()
    else:
        print(json.dumps(get(), indent=1, default=str)[:3000])
PY_PB
cat > $W/p269_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p269_patch.py - patch 269: MY F&O is all automatic (Rama, 14 Nov: "the tabs have the upload CSV - since you read online we don't need them;
think as a human"). The upload box and the old typed-in ledger (CAPITAL / ADD TRADE) go; a 💰 ZERODHA strip shows the money from the account.
python3 p269_patch.py DIR"""
import os, re, sys
D = sys.argv[1]
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
if "patch 269" in s:
    print("  home.html: patch 269 - already in"); sys.exit(0)
if "patch 267" not in s:
    print("❌ home.html: patch 267 first"); sys.exit(1)
m = re.findall(r'\n    h\+=`<div class="pnu"><b>UPLOAD</b>[^\n]*', s)
if len(m) != 1:
    print("❌ home.html: the upload line found %d times" % len(m)); sys.exit(1)
s = s.replace(m[0], "\n    /* patch 269: no upload - GIR reads the account itself */"); print("  home.html: the upload box is gone")
E = [("""$("pnx").innerHTML=h||'<div class="empty">upload your statement below</div>'+h;""", """$("pnx").innerHTML=h||'<div class="empty">no record on this server yet</div>';""", "no 'upload' words"),
     ('<div id="pnk" class="kp"></div>', '<div id="pnf" class="pnf"></div><div id="pnk" class="kp"></div>', "the 💰 ZERODHA strip's place"),
     ('  if(PNL.tab==="today"){', '''  { const F=D.funds, r=pnlR;   /* patch 269: the money, straight from Zerodha */
    $("pnf").innerHTML=F&&(F.avail!=null||F.h_n!=null)?`💰 <b>ZERODHA</b> · cash available <b>${r(F.avail)}</b> · margin in use <b>${r(F.used)}</b>${F.h_n!=null?` · holdings ${F.h_n} shares <b>${r(F.h_val)}</b> (P&amp;L <b class="${pnlC(F.h_pl)}">${r(F.h_pl)}</b> · today <b class="${pnlC(F.h_day)}">${r(F.h_day)}</b>)`:""} <span class="dim">· read ${esc(F.at||"")}</span>`:'💰 <b>ZERODHA</b> · cash, margin and holdings are read from your account every minute in market hours (every 30 min outside) - the first reading is on its way'; }
  if(PNL.tab==="today"){''', "the 💰 ZERODHA strip"),
     ('<div class="hd2">BY EXPIRY MONTH</div>', '<div class="hd2">${F.months_by==="trade"?"BY MONTH - when you traded (your tradebook)":"BY EXPIRY MONTH - the option\'s month, not the month you traded"}</div>', "months by when you traded, not by expiry"),
     ('pale bars = your statement by expiry month (${H.map(x=>esc(x[2])+" "+pnlR(x[1])).join(" · ")}) · bright bars = each live day from GIR',
      '${H0.length?"pale bars = your statement by month ("+H0.map(x=>esc(x[2])+" "+pnlR(x[1])).join(" · ")+")":"pale bars = your trading days to "+esc(upto)+" (tradebook)"} · bright bars = each live day from GIR',
      "BARS: a short note, not all 66 dates"),
     ("</style>", "/* patch 269: MY F&O all automatic - the typed-in ledger is hidden (Zerodha is read instead) */\n#mfl{display:none}\n#mfpnl .pnf{padding:4px 8px;font-size:.85em;border-bottom:1px dashed var(--ln,#2a3346)}\n</style>", "the typed-in ledger hidden")]
for o, n, tag in E:
    if s.count(o) != 1:
        print("❌ home.html: anchor for '%s' found %d times" % (tag, s.count(o))); sys.exit(1)
    s = s.replace(o, n); print("  home.html: %s" % tag)
open(p, "w", encoding="utf-8").write(s)
print("patch 269 in")
PY_PATCH
cat > $W/p269test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p269test.py - funds and holdings from a fake Zerodha (temp folder, nothing read from the real account).  python3 p269test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "pnlbook.py"), T)
sys.path.insert(0, T); os.chdir(T)
import pnlbook as P
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
class K:
    def margins(self): return {"equity": {"net": 152340.5, "available": {"opening_balance": 300000}, "utilised": {"debits": 186000.2}}}
    def holdings(self): return [{"tradingsymbol": "AAA", "quantity": 10, "last_price": 500.0, "pnl": 1200.0, "day_change": 4.0},
                                {"tradingsymbol": "BBB", "quantity": 5, "last_price": 100.0, "pnl": -300.0, "day_change": -1.0}]
f = P.funds(K(), dt.datetime(2026, 11, 16, 10, 0, tzinfo=IST))
chk("funds from the account: cash ₹1,52,341 · margin in use ₹1,86,000 · opening ₹3,00,000", f["avail"] in (152340, 152341) and f["used"] == 186000 and f["opening"] == 300000, f)
chk("holdings: 2 shares · value ₹5,500 · P&L ₹900 · today ₹35", f["h_n"] == 2 and f["h_val"] == 5500 and f["h_pl"] == 900 and f["h_day"] == 35, f)
chk("the page gets them (get -> funds)", P.get(0)["funds"]["h_val"] == 5500)
class Bad:
    def margins(self): raise RuntimeError("token old")
    def holdings(self): raise RuntimeError("token old")
P.funds(Bad())
chk("a failed reading keeps the last good one (no blank strip)", P.get(0)["funds"]["h_val"] == 5500)
print("ZERODHA FUNDS test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p267test.py <<'PY_T267'
#!/usr/bin/env python3
"""p267test.py - the statement carried into DAY BY DAY (made-up statement, temp folder).  python3 p267test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "pnlbook.py"), T)
sys.path.insert(0, T); os.chdir(T)
import pnlbook as P
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
fo = """,,
,P&L Statement for F&O from 2026-06-01 to 2026-11-14,,,
,Summary,,
,Charges,1000,,
,Realized P&L,26000,,
,Symbol,ISIN,Quantity,Buy Value,Sell Value,Realized P&L,Realized P&L Pct.,Previous Closing Price,Open Quantity,Open Quantity Type,Open Value,Unrealized P&L,Unrealized P&L Pct.
,AAA26SEP100CE,,100,50000,40000,-10000,-20,0,0,,0,0,0
,BBB26OCT200PE,,100,20000,15000,-5000,-25,0,0,,0,0,0
,CCC26NOV50CE,,100,9000,49000,40000,400,0,0,,0,0,0
,NIFTY26DEC26000CE,,65,4000,5000,1000,25,0,0,,0,0,0
"""
H = P.history(fo)
chk("the statement by expiry month: SEP 30 Sep · OCT 31 Oct · Nov + Dec contracts at the end date 14 Nov", H == [("2026-09-30", -10000, "SEP 2026"), ("2026-10-31", -5000, "OCT 2026"), ("2026-11-14", 41000, "to 14 Nov")], H)
P.upload(fo)
json.dump({"2026-11-13": 999, "2026-11-16": 4000, "2026-11-17": -1500}, open(P.DAYS, "w"))
g = P.get(0, dt.datetime(2026, 11, 17, 16, 0, tzinfo=IST))
chk("DAY BY DAY: the statement's months, then the live days after 14 Nov (a day already in the statement is not counted twice)",
    g["hist"] == H and g["days"] == [("2026-11-16", 4000), ("2026-11-17", -1500)], (g.get("hist"), g["days"]))
os.makedirs(P.LIVE, exist_ok=True)
json.dump({"t": [1, 2, 3], "v": [-2000, 6500, 4000], "o": [0, 0, 0]}, open(os.path.join(P.LIVE, "2026-11-16.json"), "w"))
g = P.get(0, dt.datetime(2026, 11, 17, 16, 0, tzinfo=IST))
chk("each live day's best and worst moment for the candle's wicks (16 Nov: +₹6,500 / -₹2,000)", g["dayhl"].get("2026-11-16") == [6500, -2000], g.get("dayhl"))
chk("the running total carries on: ₹26,000 + ₹4,000 - ₹1,500 = ₹28,500", sum(x[1] for x in g["hist"]) + sum(x[1] for x in g["days"]) == 28500)
os.remove(P.ST_FO)
g = P.get(0, dt.datetime(2026, 11, 17, 16, 0, tzinfo=IST))
chk("no statement: the live days alone, nothing lost", "hist" not in g and len(g["days"]) == 3, g["days"])
tb = ",,,\n,Client ID,XX0000,,\n,Tradebook for F&O from 2026-04-01 to 2026-11-14,,\n,,,\n,Symbol,ISIN,Trade Date,Exchange,Segment,Series,Trade Type,Auction,Quantity,Price,Trade ID,Order ID,Order Execution Time,\n" \
     ",AAA26NOV100CE,,2026-11-10,NSE,FO,,buy,FALSE,100,50,1,1,2026-11-10T10:00:00,2026-11-24\n,AAA26NOV100CE,,2026-11-11,NSE,FO,,sell,FALSE,100,62,2,2,2026-11-11T10:00:00,2026-11-24\n"
chk("Zerodha Console's own tradebook (title lines, 'Trade Date' headers) is read: 11 Nov +₹1,200", P.kind_of(tb) == "tradebook" and P.tradebook_days(tb) == {"2026-11-11": 1200}, P.tradebook_days(tb))
P.upload(fo); P.upload(tb)
g = P.get(0, dt.datetime(2026, 11, 17, 16, 0, tzinfo=IST))
chk("with a tradebook: one candle a DAY from your trades (not a month), then the live days", "hist" not in g and g["tb_last"] == "2026-11-11" and g["days"][0] == ("2026-11-11", 1200) and ("2026-11-16", 4000) in g["days"], (g.get("tb_last"), g["days"][:3]))
print("CARRY-OVER test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_T267
python3 $W/p269_patch.py $D || back
cd $D && python3 -m py_compile pnlbook.py || back
echo "=== test"
python3 $W/p269test.py $D || back
python3 $W/p267test.py $D | tail -1; python3 $W/p267test.py $D >/dev/null 2>&1 || back
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
cd $D && python3 -c "
import pnlbook as P
g = P.get(0); F = g.get('fo') or {}
print('  MY RECORD by month (when you traded): ' + ' · '.join('%s %s' % (m, ('-' if v < 0 else '') + '₹{:,}'.format(abs(v))) for m, v in F.get('months', [])))"
echo "✅ patch 269 done - Ctrl + Shift + R on GIR → 9 MY F&O: no upload, no typed-in ledger; the 💰 ZERODHA strip fills within 30 min (every minute on Monday)."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/pnlbook.py.bak$TS $D/pnlbook.py; systemctl restart gir-dash gir-pnlwatch"
