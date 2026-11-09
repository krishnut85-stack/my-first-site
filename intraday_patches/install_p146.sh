#!/bin/bash
# PATCH 146 - THE NSE AUDIT: every number GIR shows checked against NSE's own, every trading evening at 18:40 (and now).
#   A indices · B sector indices · C every F&O share's price and % · the up / down count · D futures OI % and the build-up word (near
#   month and all months) · E every option strike's OI · F roof / floor · G stocks PCR · H FII / DII · I the ban list
#   -> ✅ / ❌ per check with the disagreements, to GIR's ⚙️ System topic and data/nseaudit_<day>.txt. Reads only - changes nothing.
D=/home/globalbot/intraday; U=/etc/systemd/system
cat > $D/nseaudit.py <<'PY_AU'
#!/usr/bin/env python3
"""nseaudit.py - patch 146: EVERY NUMBER GIR SHOWS, CHECKED AGAINST NSE'S OWN (Rama, 9 Nov: "check all the values against NSE and
rework the formulas"). Reads only. After NSE publishes its end-of-day files (~18:00):

  A indices        NIFTY / BANKNIFTY / VIX: the value and the % vs NSE's index list (official previous close)
  B sector index   every sector index GIR shows vs NSE's index list
  C shares         every F&O share's price and % vs NSE's equity file (the official close and previous close); the F&O up / down count
  D futures OI     GIR's OI % and build-up word vs NSE's F&O file - the near month, and all months together (the rollover)
  E option chains  each share's last chain reading of the day, every strike's OI vs NSE's file (the same expiry)
  F roof / floor   the biggest call OI above / put OI below the price (within 8%) - GIR's vs the same rule on NSE's numbers
  G stocks PCR     GIR's put-call ratio vs the same on NSE's file
  H FII / DII      GIR's figure vs NSE's
  I ban list       GIR's vs NSE's
  python3 nseaudit.py [YYYY-MM-DD] [--no-tg]  -> data/nseaudit_<day>.txt, the summary to GIR's ⚙️ System topic"""
import os, io, re, sys, csv, json, time, zipfile, sqlite3, statistics, urllib.request, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", "Accept": "*/*"}
URL_FO = "https://nsearchives.nseindia.com/content/fo/BhavCopy_NSE_FO_0_0_0_%s_F_0000.csv.zip"
URL_CM = "https://nsearchives.nseindia.com/content/cm/BhavCopy_NSE_CM_0_0_0_%s_F_0000.csv.zip"
URL_BAN = "https://nsearchives.nseindia.com/content/fo/fo_secban.csv"
GET = None                                                    # tests: a function(url) -> bytes or None


def _get(url):
    if GET is not None:
        return GET(url)
    import requests
    r = requests.get(url, headers=UA, timeout=40)
    return r.content if r.status_code == 200 else None


def _csv_zip(raw):
    z = zipfile.ZipFile(io.BytesIO(raw))
    return list(csv.DictReader(io.StringIO(z.read(z.namelist()[0]).decode("utf-8", "ignore"))))


def _f(x):
    try:
        return float(str(x).replace(",", ""))
    except Exception:
        return 0.0


def _gir(path):
    k = open(os.path.join(BASE, "dash_token.txt")).read().strip()
    return json.load(urllib.request.urlopen("http://127.0.0.1:8090/%s%sk=%s" % (path, "&" if "?" in path else "?", k), timeout=60))


# ---------- NSE's files ----------
def nse_cm(day):
    """-> {sym: (close, last, previous close)} the EQ series"""
    raw = _get(URL_CM % day.strftime("%Y%m%d"))
    if not raw:
        return {}
    out = {}
    for e in _csv_zip(raw):
        if (e.get("SctySrs") or "").strip() in ("EQ", "BE") and e.get("TckrSymb"):
            out[e["TckrSymb"].strip()] = (_f(e.get("ClsPric")), _f(e.get("LastPric")), _f(e.get("PrvsClsgPric")))
    return out


def nse_fo(day):
    """-> (fut {sym: [(exp, close, oi, chg_oi)]}, opt {sym: {exp: {(strike, CE/PE): oi}}}, under {sym: underlying price})"""
    raw = _get(URL_FO % day.strftime("%Y%m%d"))
    if not raw:
        return {}, {}, {}
    fut, opt, und = {}, {}, {}
    for e in _csv_zip(raw):
        tp, s, exp = (e.get("FinInstrmTp") or "").strip(), (e.get("TckrSymb") or "").strip(), (e.get("XpryDt") or "").strip()[:10]
        if not s or not exp:
            continue
        if tp in ("STF", "IDF"):
            fut.setdefault(s, []).append((exp, _f(e.get("ClsPric")), _f(e.get("OpnIntrst")), _f(e.get("ChngInOpnIntrst"))))
            if _f(e.get("UndrlygPric")):
                und.setdefault(s, _f(e.get("UndrlygPric")))
        elif tp in ("STO", "IDO"):
            kd = (e.get("OptnTp") or "").strip().upper()
            if kd in ("CE", "PE"):
                opt.setdefault(s, {}).setdefault(exp, {})[(_f(e.get("StrkPric")), kd)] = _f(e.get("OpnIntrst"))
                if _f(e.get("UndrlygPric")):
                    und.setdefault(s, _f(e.get("UndrlygPric")))
    for v in fut.values():
        v.sort()
    return fut, opt, und


def nse_indices():
    import exchange
    j = exchange.nse_json("/api/allIndices") or {}
    out = {}
    for e in (j.get("data") if isinstance(j, dict) else j) or []:
        out[_nkey(e.get("index"))] = (_f(e.get("last")), _f(e.get("previousClose")), _f(e.get("percentChange")))
    return out


_NSYN = {"NIFTYFINSERVICE": "NIFTYFINANCIALSERVICES", "NIFTYCONSRDURBL": "NIFTYCONSUMERDURABLES", "NIFTYSERVSECTOR": "NIFTYSERVICESSECTOR",
         "NIFTYCAPITALMKT": "NIFTYCAPITALMARKETS", "NIFTYINDIAMFG": "NIFTYINDIAMANUFACTURING", "NIFTYCONSUMPTION": "NIFTYINDIACONSUMPTION",
         "NIFTY": "NIFTY50", "BANKNIFTY": "NIFTYBANK", "VIX": "INDIAVIX"}


def _nkey(n):
    k = re.sub(r"[^A-Z0-9]", "", str(n or "").upper().replace("&", "AND"))
    return _NSYN.get(k, k)


# ---------- the checks ----------
def sec(title, rows, bad, n):
    """-> lines: '✓ n of m agree' + up to 10 disagreements"""
    ok = n - len(bad)
    L = ["%s %s · %d of %d agree" % ("✅" if not bad else "❌", title, ok, n)]
    L += ["   ✗ " + b for b in bad[:10]]
    if len(bad) > 10:
        L.append("   ... %d more" % (len(bad) - 10))
    return L


def check_indices(home, mk, NI):
    L, bad, n = [], [], 0
    for name in ("NIFTY", "BANKNIFTY", "VIX"):
        g = (home.get("idx") or {}).get(name) or {}
        x = NI.get(_nkey(name))
        if not (g and x):
            continue
        n += 1
        pc_n = (x[0] / x[1] - 1) * 100 if x[1] else x[2]
        if abs((g.get("last") or 0) / x[0] - 1) > 0.0005 or g.get("chg") is None or abs(g["chg"] - pc_n) > 0.03:
            bad.append("%s GIR %s (%s%%) · NSE %s (%+.2f%%)" % (name, g.get("last"), g.get("chg"), x[0], pc_n))
    L += sec("A INDICES (NSE's index list)", None, bad, n)
    bad, n = [], 0
    for name, g in (mk.get("sidx") or {}).items():
        x = NI.get(_nkey(name))
        if not x:
            continue
        n += 1
        pc_n = (x[0] / x[1] - 1) * 100 if x[1] else x[2]
        if g.get("chg") is None or abs(g["chg"] - pc_n) > 0.05:
            bad.append("%s GIR %s%% · NSE %+.2f%%" % (name, g.get("chg"), pc_n))
    L += sec("B SECTOR INDICES (NSE's index list)", None, bad, n)
    return L


def check_shares(home, mk, CM):
    bad, n = [], 0
    up = dn = 0
    for r in home.get("tape") or []:
        s, px, chg = r.get("s"), r.get("px"), r.get("chg")
        x = CM.get(s)
        if not x or not x[2]:
            continue
        n += 1
        cl, last, pcl = x
        nc = (cl / pcl - 1) * 100
        nl = (last / pcl - 1) * 100 if last else nc
        up += nc > 0; dn += nc < 0
        if chg is None or (abs(chg - nc) > 0.15 and abs(chg - nl) > 0.15) or (px and abs(px / cl - 1) > 0.004 and abs(px / (last or cl) - 1) > 0.002):
            bad.append("%s GIR ₹%s %s%% · NSE close ₹%s (%+.2f%%), last ₹%s (%+.2f%%), prev close ₹%s" % (s, px, chg, cl, nc, last, nl, pcl))
    L = sec("C F&O SHARES - price and % (NSE's equity file)", None, bad, n)
    L.append("   F&O up / down: GIR %s / %s · NSE %d / %d" % (mk.get("fo_up"), mk.get("fo_dn"), up, dn))
    return L


def bu_word(px_chg, oi_chg):
    if px_chg > 0:
        return "LONG BUILD-UP" if oi_chg > 0 else "SHORT COVERING"
    return "SHORT BUILD-UP" if oi_chg > 0 else "LONG UNWINDING"


def check_futures(home, FUT, CM):
    bad, n, roll = [], 0, 0
    for r in home.get("tape") or []:
        s, foi = r.get("s"), r.get("foi")
        F = FUT.get(s)
        if foi is None or not F:
            continue
        n += 1
        near = F[0]
        near_pct = near[3] / (near[2] - near[3]) * 100 if near[2] - near[3] > 0 else 0.0
        tot, totc = sum(x[2] for x in F), sum(x[3] for x in F)
        all_pct = totc / (tot - totc) * 100 if tot - totc > 0 else 0.0
        x = CM.get(s)
        pxc = (x[0] / x[2] - 1) * 100 if (x and x[2]) else (r.get("chg") or 0)
        w_near, w_all = bu_word(pxc, near_pct), bu_word(pxc, all_pct)
        gw = (r.get("bu") or "").upper()
        off = abs(foi - near_pct) > max(1.5, abs(near_pct) * 0.25)
        if w_near != w_all:
            roll += 1
        if off or (gw and gw != w_near):
            bad.append("%s GIR OI %+.1f%% %s · NSE near month %+.1f%% = %s · all months %+.1f%% = %s" % (s, foi, gw or "-", near_pct, w_near, all_pct, w_all))
    L = sec("D FUTURES OI % and the build-up word (NSE's F&O file)", None, bad, n)
    L.append("   the near month and all months together disagree on the word for %d shares (rollover)" % roll)
    return L


def chain_today(day):
    """-> {sym: (t, exp, {(strike, kind): oi}, spot)} each share's last chain reading of the day (chains.db)"""
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        tabs = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
        tb = "chain15" if "chain15" in tabs else "chain"
        last = {s: t for s, t in c.execute("select sym, max(t) from %s where d=? group by sym" % tb, (str(day),))}
        for s, t in last.items():
            rows = c.execute("select exp, strike, kind, oi, spot from %s where d=? and sym=? and t=?" % tb, (str(day), s, t)).fetchall()
            if not rows:
                continue
            exp = min(str(r[0])[:10] for r in rows)
            out[s] = (t, exp, {(float(r[1]), r[2]): float(r[3] or 0) for r in rows if str(r[0])[:10] == exp}, next((r[4] for r in rows if r[4]), None))
        c.close()
    except Exception as ex:
        print("chains.db:", ex)
    return out


def roof_floor(oi, spot):
    ce = [(v, k) for (k, kd), v in oi.items() if kd == "CE" and k >= spot and abs(k / spot - 1) <= 0.08 and v]
    pe = [(v, k) for (k, kd), v in oi.items() if kd == "PE" and k <= spot and abs(k / spot - 1) <= 0.08 and v]
    return (max(ce)[1] if ce else None), (max(pe)[1] if pe else None)


def check_chains(day, OPT, UND):
    G = chain_today(day)
    bad, n, ratios, rf_bad, rf_n = [], 0, [], [], 0
    g_ce = g_pe = n_ce = n_pe = 0.0
    for s, (t, exp, oi, spot) in G.items():
        N = (OPT.get(s) or {}).get(exp)
        if not N:
            continue
        both = [(k, kd) for (k, kd) in oi if (k, kd) in N and N[(k, kd)] > 0 and oi[(k, kd)] > 0]
        if len(both) < 4:
            continue
        n += 1
        rs = [oi[x] / N[x] for x in both]
        med = statistics.median(rs)
        ratios.append(med)
        far = [x for x in both if abs(oi[x] / N[x] - med) > 0.10 * med]
        if abs(med - 1) > 0.03 or len(far) > len(both) * 0.2:
            bad.append("%s (%s, read %s): GIR's strike OI = %.2fx NSE's (median), %d of %d strikes more than 10%% off" % (s, exp, t, med, len(far), len(both)))
        sp = UND.get(s) or spot
        if sp:
            rf_n += 1
            gr, gf = roof_floor(oi, spot or sp)
            nr, nf = roof_floor({x: N[x] for x in N}, sp)
            if (gr, gf) != (nr, nf):
                rf_bad.append("%s roof / floor GIR %s / %s · NSE %s / %s" % (s, gr, gf, nr, nf))
        for (k, kd), v in oi.items():
            if kd == "CE":
                g_ce += v; n_ce += N.get((k, kd), 0)
            else:
                g_pe += v; n_pe += N.get((k, kd), 0)
    L = sec("E OPTION CHAINS - every strike's OI, the day's last reading vs NSE's close", None, bad, n)
    if ratios:
        L.append("   GIR / NSE OI ratio across shares: median %.2f · range %.2f - %.2f" % (statistics.median(ratios), min(ratios), max(ratios)))
    L += sec("F ROOF / FLOOR (the biggest call OI above, put OI below, within 8%)", None, rf_bad, rf_n)
    return L, (g_pe / g_ce if g_ce else None, n_pe / n_ce if n_ce else None)


def check_pcr(mk, OPT, UND, pcr_same):
    ch = mk.get("chain") or {}
    g = ch.get("pcr_now")
    tce = tpe = nce = npe = 0.0
    for s, E in OPT.items():
        if s in ("NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "NIFTYNXT50"):
            continue
        sp = UND.get(s)
        exps = sorted(E)
        for i, exp in enumerate(exps):
            for (k, kd), v in E[exp].items():
                if kd == "CE":
                    tce += v
                else:
                    tpe += v
                if i == 0 and sp and abs(k / sp - 1) <= 0.08:
                    if kd == "CE":
                        nce += v
                    else:
                        npe += v
    all_ = tpe / tce if tce else None
    band = npe / nce if nce else None
    L = ["%s G STOCKS PCR · GIR %s · NSE all strikes, all expiries %s · NSE the nearest expiry within 8%% (GIR's rule) %s%s" % (
        "✅" if (g and band and abs(g - band) <= 0.05) else "❌", g, round(all_, 2) if all_ else None, round(band, 2) if band else None,
        (" · GIR's own last readings %.2f vs NSE on the same strikes %.2f" % pcr_same) if all(pcr_same) else "")]
    return L


def check_fii(mk):
    try:
        import exchange
        j = exchange.nse_json("/api/fiidiiTradeReact") or []
        rows = {("FII" if "FII" in (e.get("category") or "").upper() else "DII"): (_f(e.get("netValue")), e.get("date")) for e in j if isinstance(e, dict)}
    except Exception as ex:
        return ["❔ H FII / DII · NSE not read: %s" % str(ex)[:80]]
    g = mk.get("fiidii")
    gs = json.dumps(g)[:160] if g is not None else "—"
    return ["ℹ️ H FII / DII · NSE: FII %s cr · DII %s cr (%s) · GIR shows: %s" % (rows.get("FII", ("?",))[0], rows.get("DII", ("?",))[0], (rows.get("FII") or (0, "?"))[1], gs)]


def check_ban(mk):
    raw = _get(URL_BAN)
    if not raw:
        return ["❔ I BAN LIST · NSE's file not read"]
    txt = raw.decode("utf-8", "ignore")
    nse = sorted({m.group(1) for m in re.finditer(r"(?m)^\s*\d+\s*,\s*([A-Z][A-Z0-9&-]{1,19})\s*$", txt)})
    g = sorted(mk.get("ban") or [])
    return ["%s I BAN LIST · GIR %s · NSE %s" % ("✅" if set(g) == set(nse) else "❌", ", ".join(g) or "none", ", ".join(nse) or "none")]


def audit(day=None):
    day = day or dt.datetime.now(IST).date()
    L = ["📋 NSE AUDIT %s - every GIR number against NSE's own" % day]
    CM = nse_cm(day)
    FUT, OPT, UND = nse_fo(day)
    if not CM or not FUT:
        return L + ["NSE's end-of-day files for %s are not out yet (equity %s · F&O %s) - they come ~18:00" % (day, "yes" if CM else "no", "yes" if FUT else "no")]
    home, mk = _gir("home"), _gir("market")
    try:
        NI = nse_indices()
    except Exception as ex:
        NI = {}; L.append("❔ NSE's index list not read: %s" % str(ex)[:80])
    for f in (lambda: check_indices(home, mk, NI), lambda: check_shares(home, mk, CM), lambda: check_futures(home, FUT, CM)):
        try:
            L += f()
        except Exception as ex:
            L.append("❔ a check failed: %s" % str(ex)[:120])
    try:
        c, same = check_chains(day, OPT, UND)
        L += c
        L += check_pcr(mk, OPT, UND, same)
    except Exception as ex:
        L.append("❔ the chain checks failed: %s" % str(ex)[:120])
    for f in (lambda: check_fii(mk), lambda: check_ban(mk)):
        try:
            L += f()
        except Exception as ex:
            L.append("❔ %s" % str(ex)[:120])
    return L


def send_tg(text):
    try:
        import premove
        return premove.send_tg(text)
    except Exception as ex:
        print("telegram: %s" % ex); return 0


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    L = audit(dt.date.fromisoformat(a[0]) if a else None)
    txt = "\n".join(L)
    print(txt)
    open(os.path.join(BASE, "data", "nseaudit_%s.txt" % (a[0] if a else dt.date.today())), "w").write(txt)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % send_tg(txt))
PY_AU
cat > $D/p146test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p146test.py - patch 146: the NSE audit on made-up files (no network): it finds a wrong %, a wrong OI %, a wrong word, a chain in
other units, a wrong roof, and passes what is right"""
import os, io, sys, json, zipfile, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nseaudit as A
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
def z(txt):
    b = io.BytesIO(); f = zipfile.ZipFile(b, "w"); f.writestr("x.csv", txt); f.close(); return b.getvalue()
CM = "TckrSymb,SctySrs,ClsPric,LastPric,PrvsClsgPric\nICICIBANK,EQ,1400,1401,1378.9\nSBIN,EQ,1042,1042,1016\nTCS,EQ,3000,3000,3030\n"
FO = """FinInstrmTp,TckrSymb,XpryDt,StrkPric,OptnTp,ClsPric,OpnIntrst,ChngInOpnIntrst,UndrlygPric
STF,ICICIBANK,2026-11-24,,,1405,97000000,-3000000,1400
STF,ICICIBANK,2026-12-29,,,1412,20000000,15000000,1400
STF,SBIN,2026-11-24,,,1045,100000000,3288000,1042
STF,TCS,2026-11-24,,,3005,10000000,196000,3000
STO,SBIN,2026-11-24,1040,CE,20,5000000,0,1042
STO,SBIN,2026-11-24,1060,CE,10,9000000,0,1042
STO,SBIN,2026-11-24,1080,CE,5,4000000,0,1042
STO,SBIN,2026-11-24,1020,PE,15,7000000,0,1042
STO,SBIN,2026-11-24,1000,PE,8,3000000,0,1042
"""
A.GET = lambda url: z(CM) if "/cm/" in url else z(FO) if "/fo/BhavCopy" in url else b"Securities in Ban For Trade Date 10-NOV-2026:\n1,KAYNES\n"
T = tempfile.mkdtemp(); A.BASE = T
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
day = dt.date(2026, 11, 9)
c.executemany("insert into chain15 values(?,?,?,?,?,?,?,?,?)", [(str(day), "15:15", "SBIN", "2026-11-24", k, kd, oi * 2, 1, 1042) for k, kd, oi in
    ((1040, "CE", 5e6), (1060, "CE", 9e6), (1080, "CE", 4e6), (1020, "PE", 7e6), (1000, "PE", 3e6))])
c.commit(); c.close()
HOME = {"idx": {"NIFTY": {"last": 25044.65, "chg": 0.23}, "BANKNIFTY": {"last": 59741.25, "chg": 1.11}},
        "tape": [{"s": "ICICIBANK", "px": 1401, "chg": 1.60, "foi": 12.7, "bu": "LONG BUILD-UP"}, {"s": "SBIN", "px": 1042, "chg": 2.56, "foi": 3.4, "bu": "LONG BUILD-UP"},
                 {"s": "TCS", "px": 3000, "chg": -0.4, "foi": 2.0, "bu": "SHORT BUILD-UP"}]}
MK = {"sidx": {"NIFTY PSU BANK": {"chg": 3.66}}, "fo_up": 2, "fo_dn": 1, "chain": {"pcr_now": 0.55}, "ban": ["KAYNES"]}
A._gir = lambda p: HOME if p == "home" else MK
A.nse_indices = lambda: {"NIFTY50": (25044.65, 24986.4, 0.23), "NIFTYBANK": (59741.25, 58850.65, 1.51), "NIFTYPSUBANK": (8800, 8489.3, 3.66)}
L = A.audit(day)
txt = "\n".join(L); print(txt); print("-" * 30)
check("A: NIFTY right, BANKNIFTY +1.11% caught (NSE +1.51%)", "BANKNIFTY GIR 59741.25 (1.11%)" in txt and "NIFTY GIR" not in txt.replace("BANKNIFTY GIR", ""))
check("B: the PSU BANK index agrees", "B SECTOR INDICES (NSE's index list) · 1 of 1 agree" in txt)
check("C: TCS -0.4% caught (NSE -0.99%); ICICIBANK +1.60% within the close / last", "TCS GIR ₹3000 -0.4%" in txt and "ICICIBANK GIR ₹1401" not in txt)
check("D: ICICIBANK OI +12.7% caught - NSE near month -3.0% = SHORT COVERING, all months +11.4% (the rollover)", "ICICIBANK GIR OI +12.7%" in txt and "SHORT COVERING" in txt and "all months +11.4%" in txt)
check("D: SBIN +3.4% agrees", "SBIN GIR OI" not in txt)
check("E: SBIN's chain in other units (2.00x NSE) caught", "SBIN (2026-11-24, read 15:15): GIR's strike OI = 2.00x" in txt)
check("F: roof / floor the same strikes (1060 / 1020)", "F ROOF / FLOOR (the biggest call OI above, put OI below, within 8%) · 1 of 1 agree" in txt)
check("I: the ban list agrees", "✅ I BAN LIST" in txt)
shutil.rmtree(T)
print("P146 NSE AUDIT TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile nseaudit.py p146test.py && timeout 120 python3 p146test.py > /dev/null 2>&1 && echo "    p146test.py passed" || { echo "the audit's own test failed - nothing set"; exit 1; }
cat > $U/gir-nseaudit.service <<'UNIT'
[Unit]
Description=GIR NSE audit (every number vs NSE's end-of-day files)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 nseaudit.py >> data/nseaudit.log 2>&1'
UNIT
cat > $U/gir-nseaudit.timer <<'UNIT'
[Unit]
Description=GIR NSE audit 18:40 on trading days
[Timer]
OnCalendar=Mon..Fri *-*-* 18:40:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-nseaudit.timer && echo "    every trading evening at 18:40"
echo "    the audit of today, now:"
echo
( cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 nseaudit.py )
