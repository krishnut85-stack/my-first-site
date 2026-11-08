#!/bin/bash
# PATCH 132 - THE CHAIN'S OI % ON EVERY STRIKE + COMPANY EVENTS WITH THEIR TIMES (on top of patch 131b).
#   1) Divi's far strikes showed "—": GIR's own readings keep only the strikes within 8% of that day's price. NSE's
#      end-of-day F&O file (every strike) is now read each evening (bhavfull.py) - the chain's OI % and the engine's
#      "since yesterday" growth use it for the strikes GIR did not read; a strike with no OI at the close shows "new".
#   2) Earnings calls, analyst / investor meets and board meetings, with the time, read from the companies' NSE filings
#      (events.py): the share card (COMPANY EVENTS), the 08:30 recap, 🗓 on Telegram 30 min before (📰 News topic) and
#      the evening list for the next trading day.
#   bhavfull.py, events.py (new) · chains.py, dashserve.py, exchange.py, girhealth.py, tglanes.py, newsrecap.py,
#   home.html (exact anchors). Restarts gir-dash, gir-exchange and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g132; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p132.sh now"; exit 1; fi
grep -q "function chTrim" $D/home.html 2>/dev/null || { echo "patch 131b is not installed yet - paste patch 131b first"; exit 1; }
[ -f $D/bhavfull.py ] && { echo "patch 132 is already installed"; exit 1; }
F="chains.py dashserve.py exchange.py girhealth.py tglanes.py newsrecap.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/bhavfull.py $D/events.py $D/p132test.py; systemctl restart gir-dash gir-exchange gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p132_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p132_patch.py - PATCH 132: (1) the chain's OI % on every strike - the strikes a day's own readings did not hold come from
NSE's end-of-day F&O file (bhavfull.py); (2) COMPANY EVENTS WITH TIMES - earnings calls, analyst meets, board meetings read
from the companies' NSE filings (events.py): on the share card, in the 08:30 recap, 🗓 30 min before on Telegram.
Usage: python3 p132_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "chains.py": [
        ('''        con.close()
        log("live chains: %d strikes with yesterday's OI (%s)" % (len(self.prev), d))
        return d''', '''        con.close()
        try:                                                    # patch 132: the strikes yesterday's 8% band did not hold - NSE's end-of-day file
            import bhavfull
            n_ = bhavfull.fill(self.prev, d, syms) if d else 0
            if n_:
                log("live chains: +%d strikes from NSE's end-of-day file (%s)" % (n_, d))
        except Exception as ex_:
            log("bhavfull: %s" % str(ex_)[:80])
        log("live chains: %d strikes with yesterday's OI (%s)" % (len(self.prev), d))
        return d'''),
    ],
    "dashserve.py": [
        ('''    finally:
        con.close()
    if len(_PREV) > 400:
        _PREV.clear()
    _PREV[ck] = out
    return out''', '''    finally:
        con.close()
    try:                                                        # patch 132: the strikes that day's own readings did not hold - NSE's end-of-day file
        import bhavfull
        d_ = out.get("_d")
        if not d_:
            import sessions
            x_ = dt.date.fromisoformat(str(day)[:10])
            for _ in range(10):
                x_ -= dt.timedelta(days=1)
                if sessions.session(x_):
                    d_ = str(x_)
                    break
        if d_:
            out["_bd"] = d_
        if d_ and bhavfull.have(d_):
            b_ = bhavfull.prev_for(sym, d_, exp)
            if b_:
                for kk in keys:
                    for kd in ("ce", "pe"):
                        if kd not in (out.get(kk) or {}) and kd in (b_.get(kk) or {}):
                            out.setdefault(kk, {})[kd] = b_[kk][kd]
                out["_d"], out["_full"] = d_, 1
    except Exception:
        pass
    if len(_PREV) > 400:
        _PREV.clear()
    _PREV[ck] = out
    return out'''),
        ('''    ck = (sym, day, exp)
    if ck in _PREV:
        return _PREV[ck]''', '''    ck = (sym, day, exp)
    if ck in _PREV:
        v_ = _PREV[ck]
        try:                                                    # patch 132: read again once NSE's end-of-day file for that day has come in
            import bhavfull
            if v_.get("_full") or not v_.get("_bd") or not bhavfull.have(v_["_bd"]):
                return v_
        except Exception:
            return v_'''),
        ('''                out["prev_d"] = pv_.get("_d")
                out["prev"] = {k_: v_ for k_, v_ in pv_.items() if k_ != "_d"}''', '''                out["prev_d"] = pv_.get("_d")
                out["prev"] = {k_: v_ for k_, v_ in pv_.items() if not str(k_).startswith("_")}
                out["prev_full"] = bool(pv_.get("_full"))             # patch 132: every strike of that day known (a strike missing = new)'''),
        ('''def checklist_for(sym, peek=False):''', '''def _ev_add(sym, c):
    """patch 132: the share's company events (earnings call, analyst meet, board meeting) with their times -> c["ev"]"""
    try:
        import events
        c["ev"] = events.for_sym(sym)
    except Exception:
        pass
    return c


def checklist_for(sym, peek=False):'''),
        ('''            c = e["c"]; c["src"] = "ticks"
            return c''', '''            c = e["c"]; c["src"] = "ticks"
            return _ev_add(sym, c)'''),
        ('''        c = dict(c); c["src"] = "sweep"; c["sweep_age"] = int(time.time() - _CHK["m"])''', '''        c = dict(c); c["src"] = "sweep"; c["sweep_age"] = int(time.time() - _CHK["m"]); _ev_add(sym, c)'''),
    ],
    "exchange.py": [
        ('''    last_fo = time.time(); fails = 0''', '''    last_fo = time.time(); fails = 0; last_ev = 0.0'''),
        ('''        try:
            followup(con)
        except Exception as ex:
            log("followup:", str(ex)[:80])
        time.sleep(15)''', '''        try:
            followup(con)
        except Exception as ex:
            log("followup:", str(ex)[:80])
        if time.time() - last_ev > 120:                         # patch 132: company events with their times (calls, analyst meets, board meetings)
            last_ev = time.time()
            try:
                import events
                n_ev = events.scan(con, pdf_text, limit=6)
                if n_ev:
                    jlog("   events: %d company event(s) read from the filings" % n_ev)
            except Exception as ex:
                log("events:", str(ex)[:80])
        time.sleep(15)'''),
    ],
    "girhealth.py": [
        ('''import os, re, json, time, subprocess, datetime as dt''', '''import os, re, json, time, subprocess, threading, datetime as dt'''),
        ('''SEND = None                                   # tests put a list's append here; else engine2.tg_fo''', '''SEND = None                                   # tests put a list's append here; else engine2.tg_fo
_HERE = os.path.dirname(os.path.abspath(__file__))


def _bhav():
    """patch 132: NSE's end-of-day F&O file of the last trading days (every strike) - read in the background"""
    try:
        import bhavfull
        for x in bhavfull.ensure():
            print("bhavfull %s" % x)
    except Exception as ex:
        print("bhavfull: %s" % str(ex)[:80])'''),
        ('''    if nows - float(h.get("news_at") or 0) >= 3600:''', '''    try:                                                      # patch 132: company events - 🗓 30 min before each, the evening list
        import events
        events.FILE = os.path.join(BASE, "data", "events.json")
        for t in events.remind(now, h):
            say(t)
    except Exception as ex:
        h["ev_err"] = str(ex)[:80]
    if BASE == _HERE and nows - float(h.get("bhav_at") or 0) >= 1800:
        h["bhav_at"] = nows
        threading.Thread(target=_bhav, daemon=True).start()
    if nows - float(h.get("news_at") or 0) >= 3600:'''),
    ],
    "tglanes.py": [
        ('''        if k in ("📰", "📄", "🏛") or "MARKET NEWS" in H2:''', '''        if k in ("📰", "📄", "🏛", "🗓") or "MARKET NEWS" in H2:      # patch 132: + 🗓 company events'''),
    ],
    "newsrecap.py": [
        ('''    out = {"now": now, "prev": prev, "since": t_close, "overnight": [], "session": [], "market": [], "reaction": [], "held": 0, "results": [], "due": due(now)}''',
         '''    out = {"now": now, "prev": prev, "since": t_close, "overnight": [], "session": [], "market": [], "reaction": [], "held": 0, "results": [], "due": due(now), "events": []}
    try:                                                         # patch 132: today's company events with their times
        import events
        out["events"] = events.day_list(now.date())
    except Exception as ex:
        print("recap events: %s" % str(ex)[:80])'''),
        ('''        on = g["overnight"][:n_on]
        story.append(section("OVERNIGHT''', '''        if g.get("events"):                                        # patch 132: today's company events (calls, analyst meets, board meetings)
            evs = g["events"][:n_ev]
            story.append(section("COMPANY EVENTS TODAY", "%d · earnings calls, analyst meets, board meetings - times from the filings · 🗓 on Telegram 30 min before" % len(g["events"])
                                 if uni else "%d - times from the filings" % len(g["events"])))
            rows_ = [[Paragraph(esc(e.get("t") or "--:--"), st(7.6, bold=True)), Paragraph("<b>%s</b>" % esc(e["s"]), st(7.6)),
                      Paragraph(esc(e["kind"] + ((" · hosted by " + e["host"]) if e.get("host") else "")), st(7.2))] for e in evs]
            t3 = Table(rows_, colWidths=[46, 76, 409])
            t3.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                    ("TOPPADDING", (0, 0), (-1, -1), 1.2), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.2), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
            story += [t3, Spacer(1, 5)]
        on = g["overnight"][:n_on]
        story.append(section("OVERNIGHT'''),
        ('''def build_pdf(g, path, read=None, caps=(24, 10, 10, 10), n_res=14, n_due=16):''', '''def build_pdf(g, path, read=None, caps=(24, 10, 10, 10), n_res=14, n_due=16, n_ev=12):'''),
        ('''        n_due = max(6, n_due - 2)''', '''        n_due = max(6, n_due - 2)
        n_ev = max(6, n_ev - 2)'''),
    ],
    "home.html": [
        ('''  const pc=v=>v==null?'<i class="dim">—</i>':`<i class="${v>0.05?"pu":v<-0.05?"pd":"dim"}">''',
         '''  const pc=v=>v==null?'<i class="dim">—</i>':v==="new"?'<i class="am" title="no open interest at the last close - opened today">new</i>':`<i class="${v>0.05?"pu":v<-0.05?"pd":"dim"}">'''),
        ('''    const oiP=(oi,d,o0)=>hasP?pct(oi,o0):(d!=null&&oi!=null&&oi-d>0?d/(oi-d)*100:null);''',
         '''    const oiP=(oi,d,o0)=>hasP?((!o0&&FOI&&FOI.prev_full&&oi>0)?"new":pct(oi,o0)):(d!=null&&oi!=null&&oi-d>0?d/(oi-d)*100:null);   /* patch 132: every strike from NSE's close file */'''),
        ('''${c&&c.exp?` · expiry ${esc(c.exp.slice(5))} (${c.days}d)`:""}</div></div>`; }''',
         '''${c&&c.exp?` · expiry ${esc(c.exp.slice(5))} (${c.days}d)`:""}</div>
    ${c&&c.ev&&c.ev.length?`<div class="cev"><small>COMPANY EVENTS (from the filings)</small>${c.ev.map(e=>`<span><b class="${e.today?"pd":"am"}">${esc(e.when)}</b> ${esc(e.kind)}${e.host?" · "+esc(e.host):""}</span>`).join("<br>")}</div>`:""}</div>`; }'''),
        ("""— = that strike was not recorded yesterday (it was far from the price then)""",
         """new = no open interest at the last close (opened today) · — = no reading of that strike at the last close"""),
    ],
}
NEW = {"bhavfull.py", "events.py"}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $W/bhavfull.py <<'PY_BHAV'
#!/usr/bin/env python3
"""bhavfull.py - patch 132: NSE's END-OF-DAY F&O FILE, EVERY STRIKE. GIR's own chain readings keep only the strikes within
8% of that day's price, so after a big move (Divi's on its results) the far strikes had no previous reading and the
chain's OI % showed "—". NSE's daily F&O file (the bhavcopy) has every strike's closing OI and price: it is read once
each evening and kept in data/bhav/<day>.json; the page's OI % and the engine's "since yesterday" growth fill the
missing strikes from it.

  units     NSE's file and Kite may count OI differently (contracts / shares): each share is checked against GIR's own
            last reading of that day (the strikes both have) and scaled; a share that cannot be checked is not used
  when      the dashboard's refresher calls ensure() - the last 3 trading days, and today's after 19:00
  python3 bhavfull.py                 what is kept
  python3 bhavfull.py fetch 2026-11-06   read one day now"""
import os, io, re, csv, sys, json, time, zipfile, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(BASE, "data", "bhav")
CHAINS = os.path.join(BASE, "chains.db")
URL = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
      "Accept": "*/*", "Accept-Language": "en-US,en;q=0.9"}
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
BAND = 0.35                       # strikes within 35% of the price (the far ones a big move reaches; the rest is noise)
FETCH = None                      # tests put a function(url) -> bytes here
_MEM = {}
MON = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}


def path(d):
    return os.path.join(DIR, "%s.json" % d)


def _exp(s):
    s = (s or "").strip()
    try:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}.*", s):
            return s[:10]
        m = re.fullmatch(r"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})", s)
        if m:
            y = int(m.group(3)); y = y + 2000 if y < 100 else y
            return str(dt.date(y, MON[m.group(2).lower()], int(m.group(1))))
        if re.fullmatch(r"\d{8}", s):
            return "%s-%s-%s" % (s[:4], s[4:6], s[6:])
    except Exception:
        pass
    return s


def _f(x):
    try:
        return float(x)
    except Exception:
        return 0.0


def parse(txt):
    """the UDiFF csv -> {sym: {"spot": px, "o": {exp: {"%g" strike: {"ce": [oi, close], "pe": [...]}}}}} (stock + index options)"""
    recs = list(csv.DictReader(io.StringIO(txt)))
    spot = {}
    for e in recs:
        if e.get("FinInstrmTp") in ("STF", "IDF") and _f(e.get("UndrlygPric")):
            spot.setdefault(e.get("TckrSymb"), _f(e.get("UndrlygPric")))
    out = {}
    for e in recs:
        if e.get("FinInstrmTp") not in ("STO", "IDO"):
            continue
        s = e.get("TckrSymb")
        k, kd = _f(e.get("StrkPric")), (e.get("OptnTp") or "").upper()
        sp = spot.get(s) or _f(e.get("UndrlygPric"))
        if not s or not k or kd not in ("CE", "PE") or not sp or abs(k / sp - 1) > BAND:
            continue
        o = out.setdefault(s, {"spot": sp, "o": {}})
        o["o"].setdefault(_exp(e.get("XpryDt")), {}).setdefault("%g" % k, {})[kd.lower()] = [_f(e.get("OpnIntrst")), _f(e.get("ClsPric"))]
    return out


def scale(day, data, con=None):
    """each share's OI against GIR's own last reading of that day (strikes both have) -> {sym: factor}; a share with
    nothing to compare gets the factor most shares had, only when that factor is 1 (no lot guesswork)"""
    own = con is None
    try:
        con = con or sqlite3.connect("file:%s?mode=ro" % CHAINS, uri=True, timeout=5)
    except Exception:
        return {}
    lots = {}
    mine = {}
    try:
        tabs = set(r[0] for r in con.execute("select name from sqlite_master where type='table'"))
        if "fo_list" in tabs:
            lots = dict(con.execute("select sym, lot from fo_list"))
        for tb in [x for x in ("chain15", "chain") if x in tabs]:
            q = "select sym, exp, strike, kind, oi from %s where d=? %s order by t" % (tb, "and t!='EOD'" if tb == "chain" else "")
            for s, e, k, kd, oi in con.execute(q, (str(day),)):
                if s in data:
                    mine.setdefault(s, {})[(str(e)[:10], "%g" % k, (kd or "").lower())] = oi
            if mine:
                break
    finally:
        if own:
            con.close()
    fac = {}
    for s, m in mine.items():
        rs = []
        for (e, k, kd), oi in m.items():
            b = ((data[s]["o"].get(e) or {}).get(k) or {}).get(kd)
            if b and b[0] > 0 and oi and oi > 0:
                rs.append(oi / b[0])
        if len(rs) < 3:
            continue
        rs.sort()
        r = rs[len(rs) // 2]
        lot = float(lots.get(s) or 0)
        if 0.8 <= r <= 1.25:
            fac[s] = 1.0
        elif lot > 1 and abs(r / lot - 1) < 0.3:
            fac[s] = lot
    if fac:
        ones = sum(1 for v in fac.values() if v == 1.0)
        if ones >= 0.8 * len(fac):                              # NSE counts like Kite: the shares GIR did not read that day too
            for s in data:
                fac.setdefault(s, 1.0)
    return fac


def fetch(day):
    """read NSE's file for one day -> number of shares kept (written to data/bhav/<day>.json), or an error string"""
    d = dt.date.fromisoformat(str(day))
    url = URL % d.strftime("%Y%m%d")
    try:
        if FETCH is not None:
            raw = FETCH(url)
        else:
            import requests
            s = requests.Session()
            r = s.get(url, headers=UA, timeout=40)
            if r.status_code != 200:
                return "NSE answered %s" % r.status_code
            raw = r.content
        z = zipfile.ZipFile(io.BytesIO(raw))
        txt = z.read(z.namelist()[0]).decode("utf-8", "ignore")
    except Exception as ex:
        return "not read: %s" % str(ex)[:80]
    data = parse(txt)
    if not data:
        return "the file had no option rows"
    fac = scale(d, data)
    keep = {}
    for s, v in data.items():
        f = fac.get(s)
        if f is None:
            continue                                            # not checked against GIR's own reading - not used
        if f != 1.0:
            for e in v["o"].values():
                for row in e.values():
                    for kd in row:
                        row[kd][0] = round(row[kd][0] * f)
        keep[s] = v
    os.makedirs(DIR, exist_ok=True)
    json.dump({"d": str(d), "at": time.time(), "n_file": len(data), "scaled": {s: f for s, f in fac.items() if f != 1.0}, "s": keep},
              open(path(d) + ".tmp", "w"), separators=(",", ":"))
    os.replace(path(d) + ".tmp", path(d))
    _MEM.pop(str(d), None)
    return len(keep)


def load(day):
    """{sym: {"spot", "o"}} of one day ({} when not read)"""
    k = str(day)
    p = path(k)
    try:
        m = os.path.getmtime(p)
    except Exception:
        return {}
    c = _MEM.get(k)
    if c and c[0] == m:
        return c[1]
    try:
        v = json.load(open(p)).get("s") or {}
    except Exception:
        v = {}
    if len(_MEM) > 3:
        _MEM.clear()
    _MEM[k] = (m, v)
    return v


def have(day):
    return os.path.exists(path(day))


def prev_for(sym, day, exp):
    """{"%g" strike: {"ce": [oi, close], "pe": [...]}} of one share and expiry on that day ({} when not there)"""
    return ((load(day).get(sym) or {}).get("o") or {}).get(str(exp)[:10]) or {}


def fill(prev, day, syms):
    """the engine's yesterday map {(sym, exp, strike, kind): (oi, ltp)}: add the strikes it does not have -> number added"""
    b = load(day)
    n = 0
    for s in syms:
        for e, ks in ((b.get(s) or {}).get("o") or {}).items():
            for k, row in ks.items():
                for kd, v in row.items():
                    key = (s, e, float(k), kd.upper())
                    if key not in prev:
                        prev[key] = (v[0], v[1])
                        n += 1
    return n


_ST = os.path.join(BASE, "data", "bhav", "_tries.json")


def ensure(now=None, tries_max=6):
    """the last 3 trading days (and today's after 19:00) that are not read yet - one try each per 30 min -> lines done"""
    import sessions
    now = now or dt.datetime.now(IST)
    days = []
    if sessions.session(now.date()) and now.strftime("%H:%M") >= "19:00":
        days.append(now.date())
    d = now.date()
    for _ in range(12):
        d -= dt.timedelta(days=1)
        if sessions.session(d):
            days.append(d)
        if len(days) >= 4:
            break
    try:
        st = json.load(open(_ST))
    except Exception:
        st = {}
    out = []
    for d in days:
        k = str(d)
        if have(k):
            continue
        t = st.get(k) or [0, 0.0]
        if t[0] >= tries_max or time.time() - t[1] < 1800:
            continue
        r = fetch(k)
        st[k] = [t[0] + 1, time.time()]
        out.append("%s: %s" % (k, ("%d shares" % r) if isinstance(r, int) else r))
    if out:
        os.makedirs(DIR, exist_ok=True)
        st = {k: v for k, v in st.items() if k >= str(now.date() - dt.timedelta(days=20))}
        json.dump(st, open(_ST, "w"))
        for f in os.listdir(DIR):                               # keep 20 days
            if f.endswith(".json") and f[:10] < str(now.date() - dt.timedelta(days=20)) and re.match(r"\d{4}-\d{2}-\d{2}\.json$", f):
                os.remove(os.path.join(DIR, f))
    return out


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["fetch"] and len(a) > 1:
        r = fetch(a[1])
        print("%s: %s" % (a[1], ("%d shares kept (every strike within %d%% of the price)" % (r, BAND * 100)) if isinstance(r, int) else r))
    elif a[:1] == ["ensure"]:
        print("\n".join(ensure()) or "nothing to read (the last trading days are there)")
    else:
        fs = sorted(f for f in os.listdir(DIR) if re.match(r"\d{4}-\d{2}-\d{2}\.json$", f)) if os.path.isdir(DIR) else []
        print("NSE end-of-day F&O files kept: %s" % (", ".join(f[:10] for f in fs) or "none yet"))
        for f in fs[-2:]:
            j = json.load(open(os.path.join(DIR, f)))
            print("  %s: %d shares (of %d in NSE's file)%s" % (f[:10], len(j.get("s") or {}), j.get("n_file") or 0,
                                                            (" · scaled from contracts: %s" % ", ".join(sorted(j["scaled"]))) if j.get("scaled") else ""))
PY_BHAV
cat > $W/events.py <<'PY_EVENTS'
#!/usr/bin/env python3
"""events.py - patch 132: COMPANY EVENTS WITH THEIR TIMES. Earnings calls, analyst / investor meets and board meetings of
the F&O shares, read from the companies' own NSE filings (the exchange reader keeps every filing in filings.db; the
time is in the filing's text or its PDF).

  share card    COMPANY EVENTS: today 11:00 earnings call · hosted by ...
  08:30 recap   COMPANY EVENTS TODAY
  Telegram      🗓 IN 30 MIN · <share> · <event> <time>           (the 📰 News topic)
                🗓 COMPANY EVENTS · <next trading day>            (the evening before, 18:00-21:00)
  python3 events.py              the events kept
  python3 events.py --scan       read the filings now (the exchange reader does it every 2 minutes)"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "events.json")
FILINGS = os.path.join(BASE, "filings.db")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
MON = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}
MN = r"(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?"

EV_RX = re.compile(r"analyst|investor|institutional|con\.?\s?call|conference call|earnings call|board meeting|\bmeet\b|\bmeeting\b", re.I)
NOT_EV = re.compile(r"transcript|audio|video|recording|outcome|newspaper|presentation|handout|postal ballot|e-?voting|\bagm\b|\begm\b|annual general|scrutini[sz]er|trading window", re.I)
DATE_RX = [
    re.compile(r"(\d{1,2})(?:st|nd|rd|th)?\s*(?:day\s+of\s+)?" + MN + r"[,\s]*(\d{4})", re.I),         # 10th November, 2026
    re.compile(MN + r"\s+(\d{1,2})(?:st|nd|rd|th)?,?\s*(\d{4})", re.I),                            # November 10, 2026
    re.compile(r"(\d{1,2})-" + MN + r"-(\d{2,4})", re.I),                                          # 10-Nov-2026
    re.compile(r"\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b"),                                         # 10/11/2026 (Indian: day first)
]
TIME_RX = [
    re.compile(r"\b(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?\s?m\.?|p\.?\s?m\.?)(?![a-z])", re.I),                # 11:00 AM · 4.30 p.m. · 4 PM
    re.compile(r"\b(\d{2})[:.]?(\d{2})\s*(?:hrs|hours|h\b|ist)", re.I),                              # 1500 hrs · 16:00 hours · 11:00 IST
    re.compile(r"\b(\d{1,2}):(\d{2})\b"),                                                           # 11:00
    re.compile(r"\b(12)\s*(noon)\b", re.I),
]
CAT_RX = re.compile(r"analysts?\s*/\s*institutional investor meet\s*/\s*con\.?\s*call updates?", re.I)
HOST_RX = re.compile(r"(?i:hosted|organi[sz]ed|arranged)\s+(?i:by)\s+([A-Z][A-Za-z0-9&.,'\- ]{2,48}?)(?=\s*(?:\(|\.|,|;|\n| on | at | for | to | in |$))")


def _date(m, i):
    g = m.groups()
    try:
        if i == 0:
            return dt.date(int(g[2]), MON[g[1][:3].lower()], int(g[0]))
        if i == 1:
            return dt.date(int(g[2]), MON[g[0][:3].lower()], int(g[1]))
        if i == 2:
            y = int(g[2]); y = y + 2000 if y < 100 else y
            return dt.date(y, MON[g[1][:3].lower()], int(g[0]))
        return dt.date(int(g[2]), int(g[1]), int(g[0]))
    except Exception:
        return None


def _time(m, i):
    g = m.groups()
    try:
        if i == 3:
            return "12:00"
        h, mi = int(g[0]), int(g[1] or 0)
        if i == 0:
            ap = g[2].lower().replace(".", "").replace(" ", "")
            if ap.startswith("p") and h < 12:
                h += 12
            if ap.startswith("a") and h == 12:
                h = 0
        if not (0 <= h <= 23 and 0 <= mi <= 59) or (i == 0 and int(g[0]) > 12):
            return None
        if i == 2 and not (7 <= h <= 21):
            return None                                         # a bare hh:mm only in business hours (no "1:2" ratios)
        return "%02d:%02d" % (h, mi)
    except Exception:
        return None


def kind_of(text):
    if re.search(r"con\.?\s?call|conference call|earnings call|investor call|analyst call", text, re.I):
        return "earnings call"
    if re.search(r"analyst|investor|institutional|\bmeet\b|one[- ]on[- ]one|roadshow|road show", text, re.I):
        return "analyst / investor meet"
    if re.search(r"board meeting|meeting of the board|board of directors", text, re.I):
        return "board meeting"
    if re.search(r"\bcall\b|webinar", text, re.I):
        return "call"
    return "meeting"


def extract(text, filed):
    """the filing's text -> [(date, "HH:MM" or None)] of the event(s) it announces (dates from a day before the filing to 60
    days after; each date takes the nearest time after it (150 characters) or before it (60))"""
    text = re.sub(r"\s+", " ", text or "")
    dates, taken = [], []
    for i, rx in enumerate(DATE_RX):
        for m in rx.finditer(text):
            if any(a < m.end() and m.start() < b for a, b in taken):
                continue
            d = _date(m, i)
            if d and filed - dt.timedelta(days=1) <= d <= filed + dt.timedelta(days=60):
                dates.append((m.start(), m.end(), d))
            taken.append((m.start(), m.end()))
    times = []
    for i, rx in enumerate(TIME_RX):
        for m in rx.finditer(text):
            if any(a < m.end() and m.start() < b for a, b in taken):
                continue
            t = _time(m, i)
            if t:
                times.append((m.start(), m.end(), t))
                taken.append((m.start(), m.end()))
    out = []
    for a, b, d in sorted(dates):
        aft = [x for x in times if 0 <= x[0] - b <= 150 and not any(b <= a2 < x[0] for a2, b2, d2 in dates)]   # no other date in between
        bef = [x for x in times if 0 <= a - x[1] <= 60]
        t = min(aft, key=lambda x: x[0] - b)[2] if aft else (max(bef, key=lambda x: x[1])[2] if bef else None)
        if (d, t) not in out:
            out.append((d, t))
    if any(t for d, t in out):                                  # a date with no time next to timed ones: a letter date, the same event again
        out = [(d, t) for d, t in out if t]
    else:
        out = [(d, t) for d, t in out if d > filed]             # an untimed date on / before the filing day is the letter's own date
    return out[:4]


def _load():
    try:
        j = json.load(open(FILE))
        return {"seen": j.get("seen") or {}, "ev": j.get("ev") or []}
    except Exception:
        return {"seen": {}, "ev": []}


def _save(j):
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    cut = str(dt.datetime.now(IST).date() - dt.timedelta(days=30))
    j["ev"] = [e for e in j["ev"] if e["d"] >= cut]
    cut_t = time.time() - 40 * 86400
    j["seen"] = {k: v for k, v in j["seen"].items() if v >= cut_t}
    json.dump(j, open(FILE + ".tmp", "w"), ensure_ascii=False)
    os.replace(FILE + ".tmp", FILE)


def scan(con=None, pdf=None, limit=6, days=15, now=None):
    """the event filings of the last `days` days not read yet (at most `limit` per call) -> events added. pdf(url) -> text
    is asked only when the filing's own text has no time."""
    now_t = (now or dt.datetime.now(IST)).timestamp()
    own = con is None
    con = con or sqlite3.connect("file:%s?mode=ro" % FILINGS, uri=True, timeout=10)
    try:
        rows = con.execute("select key, sym, t_exch, subject, detail, link from filings where t_exch>? order by t_exch desc", (int(now_t - days * 86400),)).fetchall()
    finally:
        if own:
            con.close()
    j = _load()
    added, done = 0, 0
    for key, sym, te, subj, det, link in rows:
        if key in j["seen"]:
            continue
        txt = "%s. %s" % (subj or "", det or "")
        if not EV_RX.search(txt) or NOT_EV.search(subj or "") or (NOT_EV.search(det or "") and not re.search(r"schedule|intimation|will (?:be )?(?:held|host|participate)|is scheduled", det or "", re.I)):
            j["seen"][key] = time.time()
            continue
        if done >= limit:
            break
        done += 1
        filed = dt.datetime.fromtimestamp(float(te), IST).date()
        evs = extract(txt, filed)
        if not any(t for d, t in evs) and pdf and (link or "").lower().endswith(".pdf"):
            try:
                more = pdf(link) or ""
            except Exception:
                more = ""
            if more:
                txt2 = txt + " " + more
                evs = extract(txt2, filed) or evs
                txt = txt2
        j["seen"][key] = time.time()
        kd = kind_of(CAT_RX.sub(" ", txt))                      # NSE's category name says "Con. Call" for every meet: read the filing's own words
        hm = HOST_RX.search(txt)
        for d, t in evs:
            if any(e["s"] == sym and e["d"] == str(d) and e.get("t") == t and e["kind"] == kd for e in j["ev"]):
                continue
            j["ev"].append({"s": sym, "d": str(d), "t": t, "kind": kd, "host": (hm.group(1).strip(" ,.") if hm else ""), "what": (subj or "")[:120],
                            "key": key, "link": link or "", "filed": int(te)})
            added += 1
        if done % 10 == 0:
            _save(j)                                            # a long first read keeps what it has read so far
    _save(j)
    return added


_C = {"m": None, "ev": []}


def all_events():
    try:
        m = os.path.getmtime(FILE)
    except Exception:
        return []
    if m != _C["m"]:
        _C["m"], _C["ev"] = m, _load()["ev"]
    return _C["ev"]


def _when(e, today):
    d = dt.date.fromisoformat(e["d"])
    day = "today" if d == today else "tomorrow" if d == today + dt.timedelta(days=1) else d.strftime("%a %d %b")
    return "%s %s" % (day, e["t"]) if e.get("t") else "%s (time not given)" % day


def for_sym(sym, now=None):
    """the share's events from today on (up to 4) -> [{"when", "kind", "host", "today", "d", "t", "link"}] for the share card"""
    now = now or dt.datetime.now(IST)
    today = now.date()
    evs = sorted((e for e in all_events() if e["s"] == sym and e["d"] >= str(today)), key=lambda e: (e["d"], e.get("t") or "99"))
    return [{"when": _when(e, today), "kind": e["kind"], "host": e.get("host") or "", "today": e["d"] == str(today), "d": e["d"], "t": e.get("t"),
             "link": e.get("link") or ""} for e in evs[:4]]


def day_list(d):
    """one day's events, timed first -> [event]"""
    return sorted((e for e in all_events() if e["d"] == str(d)), key=lambda e: (e.get("t") or "99", e["s"]))


def _line(e):
    return "%s %s · %s%s" % (e.get("t") or "--:--", e["s"], e["kind"], (" · " + e["host"]) if e.get("host") else "")


def remind(now, h):
    """-> the Telegram lines due now: 🗓 IN 30 MIN (once per event) and the evening list for the next trading day.
    h = girhealth's state dict (kept there)"""
    out = []
    today = str(now.date())
    if (h.get("ev_rem") or {}).get("d") != today:
        h["ev_rem"] = {"d": today, "k": []}
    for e in day_list(now.date()):
        if not e.get("t"):
            continue
        at = dt.datetime.strptime(today + " " + e["t"], "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        mins = (at - now).total_seconds() / 60.0
        k = "%s|%s|%s" % (e["s"], e["t"], e["kind"])
        if 0 < mins <= 30 and k not in h["ev_rem"]["k"]:
            h["ev_rem"]["k"].append(k)
            out.append("🗓 IN %d MIN · %s · %s %s\n%s%s%s" % (max(1, round(mins)), e["s"], e["kind"].upper(), e["t"],
                                                         ("hosted by %s · " % e["host"]) if e.get("host") else "", "from the company's NSE filing",
                                                         ("\n" + e["link"]) if e.get("link") else ""))
    if "18:00" <= now.strftime("%H:%M") <= "21:00" and h.get("ev_eve") != today:
        h["ev_eve"] = today
        try:
            import sessions
            nxt = None
            for i in range(1, 6):
                d = now.date() + dt.timedelta(days=i)
                if sessions.session(d):
                    nxt = d
                    break
        except Exception:
            nxt = now.date() + dt.timedelta(days=1)
        evs = day_list(nxt) if nxt else []
        if evs:
            out.append("🗓 COMPANY EVENTS · %s · %d\n%s\n(a reminder comes 30 min before each timed one)" % (
                nxt.strftime("%a %d %b"), len(evs), "\n".join(_line(e) for e in evs[:15]) + ("\n+%d more" % (len(evs) - 15) if len(evs) > 15 else "")))
    return out


if __name__ == "__main__":
    if "--scan" in sys.argv:
        lim = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else 300
        try:
            import exchange
            pdf = exchange.pdf_text
        except Exception as ex:
            print("(PDFs not read: %s)" % str(ex)[:80]); pdf = None
        print("events added: %d" % scan(pdf=pdf, limit=lim))
    now = dt.datetime.now(IST)
    up = sorted((e for e in all_events() if e["d"] >= str(now.date())), key=lambda e: (e["d"], e.get("t") or "99", e["s"]))
    print("company events from today: %d" % len(up))
    for e in up[:60]:
        print("  %s  %s" % (dt.date.fromisoformat(e["d"]).strftime("%a %d %b"), _line(e)))
PY_EVENTS
cat > $D/p132test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p132test.py - (1) the chain's OI % on every strike from NSE's end-of-day F&O file (a fake file, a fake chains.db);
(2) company events with their times read from filings (a fake filings.db, a fake PDF): the share card, the 30-min
reminder, the evening list, the recap PDF. Nothing is fetched, nothing is sent."""
import os, io, sys, json, time, zipfile, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import bhavfull, events, tglanes, alertword
IST = events.IST
tmp = tempfile.mkdtemp(prefix="p132")
try:
    print("1. NSE's end-of-day F&O file")
    now = dt.datetime.now(IST)
    TODAY = str(now.date())
    PREV = str(now.date() - dt.timedelta(days=3))
    EXP = str(now.date() + dt.timedelta(days=20))
    hdr = "TradDt,BizDt,Sgmt,Src,FinInstrmTp,FinInstrmId,ISIN,TckrSymb,SctySrs,XpryDt,FininstrmActlXpryDt,StrkPric,OptnTp,FinInstrmNm,OpnPric,HghPric,LwPric,ClsPric,LastPric,PrvsClsgPric,UndrlygPric,SttlmPric,OpnIntrst,ChngInOpnIntrst,TtlTradgVol,TtlTrfVal,TtlNbOfTxsExctd,SsnId,NewBrdLotQty,Rmks,Rsvd1,Rsvd2,Rsvd3,Rsvd4"
    rows = [hdr]

    def line(tp, sym, k, kd, oi, cl, und):
        r = dict.fromkeys(hdr.split(","), "")
        r.update({"FinInstrmTp": tp, "TckrSymb": sym, "XpryDt": EXP, "StrkPric": "%.2f" % k if k else "", "OptnTp": kd, "OpnIntrst": str(oi), "ClsPric": str(cl), "UndrlygPric": str(und)})
        return ",".join(r[h] for h in hdr.split(","))
    for sym, sp, step in (("DIVISLAB", 6200, 100), ("INFY", 1500, 20), ("TITAN", 3500, 50), ("XYZ", 100, 5)):
        rows.append(line("STF", sym, 0, "", 0, sp, sp))
        for i in range(-25, 26):
            k = sp + i * step
            rows.append(line("STO", sym, k, "CE", 1000 + i * 10 + 5000, 50 + i, sp)); rows.append(line("STO", sym, k, "PE", 900 + i * 7 + 5000, 40 - i * 0.5, sp))
    rows.append(line("IDO", "NIFTY", 25000, "CE", 99999, 120, 25010))
    zb = io.BytesIO(); zf = zipfile.ZipFile(zb, "w"); zf.writestr("BhavCopy.csv", "\n".join(rows)); zf.close()
    URLS = []
    bhavfull.FETCH = lambda url: (URLS.append(url), zb.getvalue())[1]
    bhavfull.DIR = os.path.join(tmp, "bhav"); bhavfull.CHAINS = os.path.join(tmp, "chains.db"); bhavfull._ST = os.path.join(tmp, "bhav", "_tries.json")
    con = sqlite3.connect(bhavfull.CHAINS)
    con.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real, primary key(d,t,sym,exp,strike,kind))")
    con.execute("create table fo_list(sym text primary key, lot integer, updated text)")
    con.executemany("insert into fo_list values(?,?,?)", [("DIVISLAB", 100, ""), ("INFY", 400, ""), ("TITAN", 175, ""), ("XYZ", 1000, "")])
    ins = []
    for sym, sp, step, f in (("DIVISLAB", 6200, 100, 1), ("INFY", 1500, 20, 1), ("TITAN", 3500, 50, 175)):
        for i in range(-4, 5):                                   # GIR's own readings: only the strikes near that day's price
            k = sp + i * step
            for t in ("15:00", "15:25"):
                ins.append((PREV, t, sym, EXP, float(k), "CE", round((1000 + i * 10 + 5000) * f * (1 if t == "15:25" else 0.97), 4), 50 + i, sp))
                ins.append((PREV, t, sym, EXP, float(k), "PE", round((900 + i * 7 + 5000) * f * (1 if t == "15:25" else 0.97), 4), 40 - i * 0.5, sp))
    # today (the big move): DIVISLAB at 6900 - the strikes 6400..7400
    for i in range(-5, 6):
        k = 6900 + i * 100
        ins.append((TODAY, "09:30", "DIVISLAB", EXP, float(k), "CE", 7000.0, 60, 6900)); ins.append((TODAY, "09:30", "DIVISLAB", EXP, float(k), "PE", 6100.0, 30, 6900))
    con.executemany("insert into chain15 values(?,?,?,?,?,?,?,?,?)", ins); con.commit(); con.close()
    r = bhavfull.fetch(PREV)
    j = json.load(open(bhavfull.path(PREV)))
    check("fetched: %s shares kept · INFY/DIVISLAB as is, TITAN scaled ×175 (its file counted contracts), XYZ (not checked) dropped: %s" % (r, sorted(j["s"])),
          r == 3 and sorted(j["s"]) == ["DIVISLAB", "INFY", "TITAN"] and j["scaled"] == {"TITAN": 175.0} and "20" in URLS[0])
    check("TITAN's OI scaled to shares: %s" % (bhavfull.prev_for("TITAN", PREV, EXP).get("3500") or {}).get("ce"),
          (bhavfull.prev_for("TITAN", PREV, EXP).get("3500") or {}).get("ce") == [6000 * 175, 50.0])
    check("DIVISLAB 7400 CE (16%% above that day's price) is in the file: %s" % (bhavfull.prev_for("DIVISLAB", PREV, EXP).get("7400") or {}).get("ce"),
          (bhavfull.prev_for("DIVISLAB", PREV, EXP).get("7400") or {}).get("ce") == [6120.0, 62.0])

    print("2. the page's OI % (dashserve)")
    import dashserve
    dashserve.BASE = tmp
    dashserve._PREV.clear()
    keys = {"%g" % (6900 + i * 100) for i in range(-5, 6)}
    pv = dashserve.chain_prev("DIVISLAB", TODAY, EXP, keys)
    got = sorted(int(k) for k in pv if not k.startswith("_"))
    check("every one of today's 11 strikes has the last close's OI (GIR's readings had 6400-6600, NSE's file the rest): %s" % got,
          got == list(range(6400, 7500, 100)) and pv.get("_full") == 1 and pv.get("_d") == PREV)
    check("a strike GIR read keeps GIR's own reading (6600 CE %s), a far one NSE's (7200 CE %s)" % (pv["6600"]["ce"], pv["7200"]["ce"]),
          pv["6600"]["ce"] == [6040.0, 54] and pv["7200"]["ce"] == [6100.0, 60.0])
    shutil.move(bhavfull.path(PREV), bhavfull.path(PREV) + ".x"); dashserve._PREV.clear(); bhavfull._MEM.clear()
    pv2 = dashserve.chain_prev("DIVISLAB", TODAY, EXP, keys)
    check("without NSE's file: as before (%d strikes, no _full)" % len([k for k in pv2 if not k.startswith("_")]),
          len([k for k in pv2 if not k.startswith("_")]) == 3 and not pv2.get("_full"))
    shutil.move(bhavfull.path(PREV) + ".x", bhavfull.path(PREV))
    pv3 = dashserve.chain_prev("DIVISLAB", TODAY, EXP, keys)
    check("NSE's file comes in later: read again (%d strikes), then kept" % len([k for k in pv3 if not k.startswith("_")]),
          len([k for k in pv3 if not k.startswith("_")]) == 11 and pv3.get("_full") and dashserve.chain_prev("DIVISLAB", TODAY, EXP, keys) is pv3)
    dashserve._OI.clear(); dashserve._PREV.clear()
    o = dashserve.oi_day("DIVISLAB")
    check("/oi: prev for every strike, prev_full true, no '_' keys: %d strikes, prev_full %s" % (len(o.get("prev") or {}), o.get("prev_full")),
          len(o.get("prev") or {}) == 11 and o.get("prev_full") is True and not any(k.startswith("_") for k in o["prev"]))

    print("3. the engine's 'since yesterday' map")
    pm = {("DIVISLAB", EXP, 6200.0, "CE"): (1.0, 1.0)}
    want = sum(len(v) for v in bhavfull.prev_for("DIVISLAB", PREV, EXP).values()) - 1
    n = bhavfull.fill(pm, PREV, ["DIVISLAB"])
    check("filled %d strikes (all in the file but the one it had), its own reading kept" % n, n == want and n > 80 and pm[("DIVISLAB", EXP, 6200.0, "CE")] == (1.0, 1.0)
          and pm[("DIVISLAB", EXP, 7400.0, "PE")] == (5984.0, 34.0))

    print("4. company events from the filings")
    fdb = os.path.join(tmp, "filings.db")
    c = sqlite3.connect(fdb)
    c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
    D1 = now.date() + dt.timedelta(days=1)
    FILED = int((now - dt.timedelta(days=2)).timestamp())
    F = [("k1", "DATAPATTNS", "Analysts/Institutional Investor Meet/Con. Call Updates",
          "Data Patterns (India) Limited has informed the Exchange about Earnings Conference Call scheduled on %s at 11:00 A.M. (IST) hosted by Ambit Capital." % D1.strftime("%A, %B %d, %Y"), ""),
         ("k2", "DATAPATTNS", "Analysts/Institutional Investor Meet/Con. Call Updates", "Data Patterns (India) Limited has informed the Exchange about Transcript of earnings call", ""),
         ("k3", "VOLTAS", "Board Meeting Intimation", "VOLTAS LIMITED has informed the Exchange about Board Meeting to be held on %s to consider results" % (now.date() + dt.timedelta(days=4)).strftime("%d-%b-%Y"), ""),
         ("k4", "TITAN", "Analysts/Institutional Investor Meet/Con. Call Updates", "Titan Company Limited has informed the Exchange about Schedule of meet", "https://x/t.pdf"),
         ("k5", "TITAN", "Outcome of Board Meeting", "Financial results for the quarter", ""),
         ("k6", "LT", "Press Release", "Larsen & Toubro has informed the Exchange about order win", "")]
    for k, s, sj, dtl, ln in F:
        c.execute("insert into filings(key, exch, sym, name, t_exch, t_seen, kind, side, subject, detail, link) values(?,?,?,?,?,?,?,?,?,?,?)", (k, "NSE", s, s, FILED, FILED, "ROUTINE", 0, sj, dtl, ln))
    c.commit()
    events.FILE = os.path.join(tmp, "data", "events.json")
    PDFS = []
    pdf = lambda u: (PDFS.append(u), "Schedule of Analyst Meet. Date: %s Time: 4.30 p.m. Mode: Virtual. Organised by Kotak Securities." % D1.strftime("%d/%m/%Y"))[1]
    n = events.scan(c, pdf, limit=10, now=now)
    ev = json.load(open(events.FILE))["ev"]
    seen = sorted((e["s"], e["d"], e["t"], e["kind"]) for e in ev)
    check("3 events read (call 11:00, analyst meet 16:30 from the PDF, board meeting no time); transcript / outcome / order skipped: %s" % seen,
          n == 3 and seen == sorted([("DATAPATTNS", str(D1), "11:00", "earnings call"), ("TITAN", str(D1), "16:30", "analyst / investor meet"),
                                     ("VOLTAS", str(now.date() + dt.timedelta(days=4)), None, "board meeting")]) and PDFS == ["https://x/t.pdf"])
    check("hosts read: %s" % sorted(e["host"] for e in ev), sorted(e["host"] for e in ev) == ["", "Ambit Capital", "Kotak Securities"])
    check("scanned again: nothing new", events.scan(c, pdf, limit=10, now=now) == 0 and len(PDFS) == 1)
    fs = events.for_sym("DATAPATTNS", now)
    check("share card: %s" % fs, fs and fs[0]["when"] == "tomorrow 11:00" and fs[0]["kind"] == "earnings call" and fs[0]["host"] == "Ambit Capital" and not fs[0]["today"])
    h = {}
    T = lambda hh, mm: dt.datetime.combine(D1, dt.time(hh, mm), IST)
    a = events.remind(T(10, 20), h)
    b = events.remind(T(10, 31), h)
    c2 = events.remind(T(10, 40), h)
    check("10:20 nothing · 10:31 🗓 IN 29 MIN · DATAPATTNS · EARNINGS CALL 11:00 · 10:40 not again: %s" % [x.split("\n")[0] for x in a + b + c2],
          not a and len(b) == 1 and b[0].startswith("🗓 IN 29 MIN · DATAPATTNS · EARNINGS CALL 11:00") and "Ambit Capital" in b[0] and not c2)
    check("the reminder goes to the 📰 News topic (%s), not Box Picks (lane %s, tier %s)" % (tglanes.topic(b[0]), tglanes.lane(b[0]), alertword.tier(b[0])),
          tglanes.topic(b[0]) == "news" and tglanes.lane(b[0]) != "critical")
    import holidays
    holidays.holiday = lambda d=None: ("weekend" if d.weekday() >= 5 else None)
    import sessions
    sessions.FILE = os.path.join(tmp, "sessions.json")
    eve_day = D1 - dt.timedelta(days=1)
    h2 = {}
    eve = events.remind(dt.datetime.combine(eve_day, dt.time(18, 30), IST), h2)
    if sessions.session(D1):
        check("the evening before: 🗓 COMPANY EVENTS list for %s: %s" % (D1, eve[0].split("\n")[:3] if eve else None),
              len(eve) == 1 and eve[0].startswith("🗓 COMPANY EVENTS · %s · 2" % D1.strftime("%a %d %b")) and "11:00 DATAPATTNS · earnings call · Ambit Capital" in eve[0])
    else:
        check("the evening before a closed day: no list for it (%s)" % eve, all(D1.strftime("%a %d %b") not in x for x in eve))
    check("the evening list once a day", not events.remind(dt.datetime.combine(eve_day, dt.time(19, 30), IST), h2))

    print("5. girhealth calls it")
    import girhealth
    girhealth.BASE = tmp; girhealth.STATE = os.path.join(tmp, "dash_state.json"); girhealth.MINE = os.path.join(tmp, "health.json")
    SENT = []
    girhealth.SEND = SENT.append
    girhealth.services_down = lambda: []
    json.dump({"items": []}, open(os.path.join(tmp, "data", "macro.json"), "w"))
    j = json.load(open(events.FILE))
    j["ev"].append({"s": "HAL", "d": TODAY, "t": (now + dt.timedelta(minutes=20)).strftime("%H:%M"), "kind": "analyst / investor meet", "host": "", "what": "", "key": "kx", "link": "", "filed": FILED})
    json.dump(j, open(events.FILE, "w")); events._C["m"] = None
    if (now + dt.timedelta(minutes=20)).date() == now.date():
        girhealth.tick(now, force=True)
        check("tick: 🗓 IN 20 MIN · HAL said: %s" % [x.split("\n")[0] for x in SENT], any(x.startswith("🗓 IN 20 MIN · HAL") or x.startswith("🗓 IN 19 MIN · HAL") for x in SENT))
    check("girhealth in a test folder does not fetch NSE's file", girhealth.BASE != girhealth._HERE)

    print("6. the 08:30 recap PDF")
    import newsrecap
    g = {"now": dt.datetime.combine(D1, dt.time(8, 30), IST), "prev": now.date(), "overnight": [], "session": [], "market": [], "reaction": [], "held": 0, "results": [], "due": [],
         "events": events.day_list(D1)}
    p = os.path.join(tmp, "r.pdf")
    newsrecap.build_pdf(g, p)
    from pypdf import PdfReader
    rd = PdfReader(p); tx = rd.pages[0].extract_text()
    check("one page with COMPANY EVENTS TODAY · 11:00 DATAPATTNS · 16:30 TITAN", len(rd.pages) == 1 and "COMPANY EVENTS TODAY" in tx and "DATAPATTNS" in tx and "16:30" in tx)

    print("7. the page")
    pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
    check("chain: a strike with no OI at the last close shows 'new'; the share card lists COMPANY EVENTS",
          'v==="new"?' in pg and "FOI.prev_full&&oi>0)?\"new\"" in pg and "COMPANY EVENTS (from the filings)" in pg and "c.ev.map(" in pg)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP132 TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p132_patch.py $D || { rm -f $D/p132test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/bhavfull.py $W/events.py $D/
cd $D && python3 -m py_compile bhavfull.py events.py chains.py dashserve.py exchange.py girhealth.py tglanes.py newsrecap.py p132test.py || back
timeout 120 python3 p132test.py 2>&1 | grep "OK  \|FAIL\|P132 TEST"
timeout 120 python3 p132test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p131test.py p131btest.py p130test.py p129test.py p128test.py p127test.py p125test.py p124test.py p120test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash gir-exchange && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
[ "$(systemctl is-active gir-exchange)" = "active" ] || { echo "gir-exchange did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 132 APPLIED."
echo "1) NSE's end-of-day F&O file for the last trading days (every strike):"
cd $D && timeout 300 python3 bhavfull.py ensure; python3 bhavfull.py
echo
echo "2) company events read from the last 15 days of filings (the first read opens the PDFs - a few minutes):"
cd $D && timeout 900 python3 events.py --scan 2>&1 | tail -40
