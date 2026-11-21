#!/bin/bash
# PATCH 331 - NEXT MONTH'S OPTION CHAIN: THE DECEMBER OI BUILD-UP (Rama, 15 Nov: "we should start seeing the next month option chain OI build up").
#   In the last week before an expiry traders roll into the next month - the new positions, the new walls and the next month's PCR show
#   where the money is going. GIR's chain readings hold only the nearest expiry; NSE's end-of-day F&O file (already kept each evening by
#   bhavfull.py, 20 days) holds every expiry. Nothing new is fetched, no Kite call, the engine is not touched.
#   · nextmonth.py (READ ONLY): every strike's next-month OI at NSE's close, what was added since the day before, the next month's
#     RESISTANCE / SUPPORT / PCR, the biggest builds and the ROLLOVER (% of option OI already in the next month, day by day) · /nextoi
#   · a share's OPTION CHAIN and the NIFTY / BANKNIFTY option chains get a switch: 23 NOV · LIVE | DEC 28 · NEXT MONTH (phone, iPad, laptop)
#   · the page check also saves /nextoi
#   Adds nextmonth.py; edits dashserve.py, home.html, pagecheck.py. Tested: 12 + every size. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 331" $D/home.html && grep -q "patch 331" $D/dashserve.py && [ -f $D/nextmonth.py ]; then echo "patch 331 - already in"; cd $D && python3 nextmonth.py NIFTY BANKNIFTY; exit 0; fi
grep -q "patch 330" $D/home.html || { echo "patch 330 first"; exit 1; }
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "function chainHTML()" $D/home.html && grep -q "function idxDeskHTML(J)" $D/home.html || { echo "dashserve's route / the option chains not found - nothing done, send this to Claude"; exit 1; }
F="dashserve.py home.html pagecheck.py"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; rm -f $D/nextmonth.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/nextmonth.py <<'PY_NM'
"""nextmonth.py - patch 331: READ ONLY. NEXT MONTH'S OPTION CHAIN - the OI BUILD-UP of the next expiry (Rama, 15 Nov: "we should start
seeing the next month option chain OI build up"). In the last days before an expiry traders roll into the next month: the new
positions, the new walls (resistance / support) and the PCR of the next month tell where the money is going.
  source   NSE's own end-of-day F&O file (bhavcopy), every strike of every expiry - GIR already keeps it each evening (bhavfull.py,
           data/bhav/<day>.json, 20 days). Nothing new is fetched; no Kite call; the engine is not touched.
  gives    per strike: the next month's CE / PE open interest at the close, its change since the day before, the closing premium;
           the next month's RESISTANCE (most calls above the price) / SUPPORT (most puts below), PCR, the biggest builds;
           ROLLOVER: the share of the option OI already in the next month, day by day
  for      every F&O share and NIFTY / BANKNIFTY. The next month = the monthly expiry after this month's.
python3 nextmonth.py TECHM      what GIR will show"""
import os, re, sys, json, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(BASE, "data", "bhav")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DAYS = 6                                   # the roll-over line: the last 6 trading days kept
INDEX = {"NIFTY": 0.06, "BANKNIFTY": 0.07, "FINNIFTY": 0.07, "MIDCPNIFTY": 0.08}
BAND, ROWS = 0.15, 40                      # strikes shown: within 15% of the price (index: its own band), at most 40 round the price
_FULL, _TOT, _RES = {}, {}, {}


def _days(today):
    try:
        fs = [f[:10] for f in os.listdir(DIR) if re.fullmatch(r"\d{4}-\d{2}-\d{2}\.json", f) and f[:10] <= today]
    except Exception:
        return []
    return sorted(fs)[-DAYS:]


def _mt(day):
    try:
        return os.path.getmtime(os.path.join(DIR, day + ".json"))
    except Exception:
        return 0


def _load(day):
    """{sym: {"spot", "o": {exp: {"%g" strike: {"ce": [oi, close], "pe": [...]}}}}} - the 2 newest days kept in memory"""
    m = _mt(day)
    c = _FULL.get(day)
    if c and c[0] == m:
        return c[1]
    try:
        v = json.load(open(os.path.join(DIR, day + ".json"))).get("s") or {}
    except Exception:
        v = {}
    _FULL[day] = (m, v)
    while len(_FULL) > 2:
        del _FULL[min(_FULL)]
    tot = {}
    for s, x in v.items():
        t = tot.setdefault(s, {})
        for e, ks in (x.get("o") or {}).items():
            ce = sum(((r.get("ce") or [0])[0] or 0) for r in ks.values())
            pe = sum(((r.get("pe") or [0])[0] or 0) for r in ks.values())
            t[e] = [ce, pe]
    _TOT[day] = (m, tot)
    return v


def _tot(day):
    c = _TOT.get(day)
    if not (c and c[0] == _mt(day)):
        _load(day)
        c = _TOT.get(day) or (0, {})
    return c[1]


def monthly(exps, today):
    """-> (this month's expiry, the next month's) from a list of expiries (an index has weeklies: the last one of each month)"""
    last = {}
    for e in sorted(set(exps)):
        if e >= today:
            last[e[:7]] = e
    ms = [last[k] for k in sorted(last)]
    return (ms[0] if ms else None), (ms[1] if len(ms) > 1 else None)


def _words(sym, nx, roll):
    w = []
    ce, pe = nx.get("ce_d"), nx.get("pe_d")
    if ce is not None and pe is not None:
        if ce <= 0 and pe <= 0 and (ce or pe):
            w.append("positions in %s were closed (calls %s · puts %s) - no new build" % (nx["mon"], _l(ce), _l(pe)))
        elif pe > 0 and pe >= 1.25 * max(ce, 0):
            w.append("%s puts written more than calls (%s vs %s) - support building%s" % (nx["mon"], _l(pe), _l(ce), " at %g" % nx["floor"]["k"] if nx.get("floor") else ""))
        elif ce > 0 and ce >= 1.25 * max(pe, 0):
            w.append("%s calls written more than puts (%s vs %s) - a cap building%s" % (nx["mon"], _l(ce), _l(pe), " at %g" % nx["ceil"]["k"] if nx.get("ceil") else ""))
        elif ce > 0 or pe > 0:
            w.append("%s calls and puts built evenly (calls %s · puts %s) - no side yet" % (nx["mon"], _l(ce), _l(pe)))
    if roll:
        r = roll[-1]
        if len(roll) > 1:
            w.append("%d%% of the option OI is now in %s (%d%% on %s)" % (round(r["pct"]), nx["mon"], round(roll[0]["pct"]), _dm(roll[0]["d"])))
        else:
            w.append("%d%% of the option OI is now in %s" % (round(r["pct"]), nx["mon"]))
    return " · ".join(w)


def _l(v):
    if v is None:
        return "—"
    a = abs(v)
    s = ("%.2f Cr" % (a / 1e7)) if a >= 1e7 else ("%.1f L" % (a / 1e5)) if a >= 1e4 else ("%d" % a)
    return ("+" if v > 0 else "−" if v < 0 else "") + s


def _dm(d):
    try:
        x = dt.date.fromisoformat(d)
        return "%d %s" % (x.day, x.strftime("%b"))
    except Exception:
        return str(d)


def view(sym, now=None):
    sym = re.sub(r"[^A-Z0-9&\-]", "", str(sym or "").upper())[:20]
    now = now or dt.datetime.now(IST)
    today = str(now.date())
    days = _days(today)
    key = (sym, today, tuple((d, _mt(d)) for d in days))
    if key in _RES:
        return _RES[key]
    out = {"s": sym, "ok": False, "src": "NSE end-of-day F&O file"}
    if not days:
        out["err"] = "NSE's end-of-day files are not on the server yet (bhavfull.py reads them each evening)"
        return out
    tots = {d: _tot(d) for d in days[:-2]}                        # the older days: only their totals
    for d in days[-2:]:
        _load(d); tots[d] = _tot(d)
    last = days[-1]
    have = [d for d in days if sym in tots[d]]
    if last not in have:
        out["err"] = "%s is not in NSE's file of %s" % (sym, _dm(last)) if have else "no NSE file holds %s's options" % sym
        out["asof"] = last
        return out
    near, nxt = monthly(list(tots[last][sym].keys()), today)
    if not nxt:
        out.update(err="NSE's file of %s has no next-month expiry for %s yet" % (_dm(last), sym), asof=last)
        return out
    L = _load(last).get(sym) or {}
    prev_d = days[-2] if len(days) > 1 else None
    P = ((_load(prev_d).get(sym) or {}).get("o") or {}).get(nxt) if prev_d else None
    spot = float(L.get("spot") or 0)
    ch = (L.get("o") or {}).get(nxt) or {}
    band = INDEX.get(sym, BAND)
    rows = []
    for k_, r in ch.items():
        k = float(k_)
        c, p = r.get("ce") or [None, None], r.get("pe") or [None, None]
        row = {"k": k, "ce": c[0], "ce_p": c[1], "pe": p[0], "pe_p": p[1]}
        if P is not None:
            q = P.get(k_) or {}
            for kd, now_ in (("ce", c[0]), ("pe", p[0])):
                o0 = (q.get(kd) or [None])[0]
                row[kd + "_d"] = (now_ - o0) if (now_ is not None and o0 is not None) else (now_ if now_ else None)
                row[kd + "_new"] = bool(now_) and not o0
        rows.append(row)
    rows.sort(key=lambda r: r["k"])
    ce_t = sum(r["ce"] or 0 for r in rows); pe_t = sum(r["pe"] or 0 for r in rows)
    above = [r for r in rows if spot and r["k"] >= spot and r["ce"]]
    below = [r for r in rows if spot and r["k"] <= spot and r["pe"]]
    ceil = max(above, key=lambda r: r["ce"]) if above else None
    floor = max(below, key=lambda r: r["pe"]) if below else None
    builds, cuts = [], []
    if P is not None:
        mv = [(r["k"], kd.upper(), r.get(kd + "_d") or 0, r[kd] or 0) for r in rows for kd in ("ce", "pe") if r.get(kd + "_d")]
        builds = [{"k": k, "kd": kd, "d": d, "oi": oi} for k, kd, d, oi in sorted(mv, key=lambda x: -x[2]) if d > 0][:4]
        cuts = [{"k": k, "kd": kd, "d": d, "oi": oi} for k, kd, d, oi in sorted(mv, key=lambda x: x[2]) if d < 0][:2]
    ce_d = pe_d = None
    if P is not None:
        ce_d = ce_t - sum(((v.get("ce") or [0])[0] or 0) for v in P.values())
        pe_d = pe_t - sum(((v.get("pe") or [0])[0] or 0) for v in P.values())
    roll = []
    for d in have:
        t = tots[d][sym]
        a, b = sum(t.get(near) or [0, 0]) if near else 0, sum(t.get(nxt) or [0, 0])
        if a + b > 0:
            roll.append({"d": d, "pct": round(b / (a + b) * 100, 1), "near": a, "nxt": b})
    shown = [r for r in rows if not spot or abs(r["k"] / spot - 1) <= band]
    if spot and len(shown) > ROWS:
        shown = sorted(sorted(shown, key=lambda r: abs(r["k"] - spot))[:ROWS], key=lambda r: r["k"])
    xd = (dt.date.fromisoformat(nxt) - now.date()).days
    mon = dt.date.fromisoformat(nxt).strftime("%b").upper()
    nx = {"exp": nxt, "mon": mon, "days": xd, "ce": ce_t, "pe": pe_t, "ce_d": ce_d, "pe_d": pe_d,
          "pcr": round(pe_t / ce_t, 2) if ce_t else None, "ceil": {"k": ceil["k"], "oi": ceil["ce"]} if ceil else None,
          "floor": {"k": floor["k"], "oi": floor["pe"]} if floor else None, "builds": builds, "cuts": cuts}
    nt = (tots[last][sym].get(near) or [0, 0]) if near else [0, 0]
    out.update(ok=True, asof=last, prev_d=prev_d if P is not None else None, spot=spot, index=sym in INDEX,
               near={"exp": near, "mon": dt.date.fromisoformat(near).strftime("%b").upper() if near else "", "ce": nt[0], "pe": nt[1],
                     "days": (dt.date.fromisoformat(near) - now.date()).days if near else None},
               nxt=nx, roll=roll, rows=shown)
    out["read"] = _words(sym, nx, roll)
    if len(_RES) > 400:
        _RES.clear()
    _RES[key] = out
    return out


if __name__ == "__main__":
    for s in (sys.argv[1:] or ["NIFTY"]):
        v = view(s)
        if not v.get("ok"):
            print("%s: %s" % (s, v.get("err"))); continue
        n = v["nxt"]
        print("%s - NEXT MONTH %s (%s, %d days) · NSE close %s%s" % (s, n["mon"], n["exp"], n["days"], v["asof"], " vs %s" % v["prev_d"] if v.get("prev_d") else ""))
        print("  RESISTANCE %s · SUPPORT %s · PCR %s · calls %s (%s) · puts %s (%s)" % (
            "%g" % n["ceil"]["k"] if n["ceil"] else "—", "%g" % n["floor"]["k"] if n["floor"] else "—", n["pcr"], _l(n["ce"]).lstrip("+"), _l(n["ce_d"]), _l(n["pe"]).lstrip("+"), _l(n["pe_d"])))
        print("  ROLLOVER %s" % " → ".join("%s %d%%" % (_dm(r["d"]), round(r["pct"])) for r in v["roll"]))
        print("  " + (v.get("read") or ""))
PY_NM
cat > $W/p331test.py <<'PY_T'
#!/usr/bin/env python3
"""p331test.py - NEXT MONTH OI BUILD-UP: made-up NSE close files in a temp folder (no real data, nothing fetched)"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data", "bhav")); shutil.copy(os.path.join(WK, "nextmonth.py"), T); sys.path.insert(0, T)
import nextmonth as N
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
def day(d, dec_ce, dec_pe, nov=(5e5, 5e5)):
    o = {"2026-11-23": {"%g" % k: {"ce": [nov[0], 10], "pe": [nov[1], 9]} for k in (90, 100, 110)},
         "2026-12-28": {"%g" % k: {"ce": [dec_ce.get(k, 0), 12], "pe": [dec_pe.get(k, 0), 11]} for k in (88, 90, 100, 110, 115)}}
    ix = {e: {"%g" % k: {"ce": [1e6, 50], "pe": [1e6, 40]} for k in (25000, 25100)} for e in ("2026-11-17", "2026-11-24", "2026-12-01", "2026-12-29", "2027-01-26")}
    ix["2026-12-29"]["25100"]["ce"] = [3e6, 60]
    json.dump({"d": d, "s": {"ZZTEST": {"spot": 101.0, "o": o}, "NIFTY": {"spot": 25050.0, "o": ix}}}, open(os.path.join(T, "data", "bhav", d + ".json"), "w"))
day("2026-11-11", {100: 1e5, 110: 1e5}, {90: 1e5, 100: 1e5})
day("2026-11-12", {100: 2e5, 110: 2e5}, {90: 2e5, 100: 1e5})
day("2026-11-13", {100: 2.5e5, 110: 4e5, 115: 1e5}, {90: 6e5, 100: 2e5, 88: 1e5})
NOW = dt.datetime(2026, 11, 15, 20, 0, tzinfo=IST)
v = N.view("zztest", now=NOW); n = v.get("nxt") or {}
chk("next month = DEC 28 (this month NOV 23), from NSE's close of 13 Nov vs 12 Nov", v["ok"] and n["exp"] == "2026-12-28" and v["near"]["exp"] == "2026-11-23" and v["asof"] == "2026-11-13" and v["prev_d"] == "2026-11-12", v)
r100 = [r for r in v["rows"] if r["k"] == 100][0]; r80 = [r for r in v["rows"] if r["k"] == 88][0]
chk("per strike: 100 CE 2.5 L, +0.5 L since the day before · 88 PE new (no OI the day before)", r100["ce"] == 2.5e5 and r100["ce_d"] == 0.5e5 and r80["pe_new"] and r80["pe_d"] == 1e5, (r100, r80))
chk("RESISTANCE 110 (most DEC calls above 101) · SUPPORT 90 (most DEC puts below)", n["ceil"]["k"] == 110 and n["floor"]["k"] == 90, n)
chk("DEC calls +3.5 L, puts +6 L since 12 Nov · PCR 1.20", n["ce_d"] == 3.5e5 and n["pe_d"] == 6e5 and n["pcr"] == 1.2, n)
chk("biggest build: 90 PE +4 L first", n["builds"][0] == {"k": 90.0, "kd": "PE", "d": 4e5, "oi": 6e5}, n["builds"])
rl = v["roll"]
chk("ROLLOVER day by day: 3 days, rising (%s)" % [x["pct"] for x in rl], len(rl) == 3 and rl[0]["pct"] < rl[1]["pct"] < rl[2]["pct"] and rl[2]["pct"] == round(16.5e5 / (16.5e5 + 3e6) * 100, 1), rl)
chk("the reading says puts written more - support at 90, and the rollover", "puts written more" in v["read"] and "support building at 90" in v["read"] and "% of the option OI is now in DEC" in v["read"], v["read"])
x = N.view("NIFTY", now=NOW); xn = x.get("nxt") or {}
chk("NIFTY (weeklies): this month = 24 Nov (the last Nov expiry), next month = 29 Dec (not 1 Dec)", x["ok"] and x["near"]["exp"] == "2026-11-24" and xn["exp"] == "2026-12-29", (x.get("near"), xn.get("exp")))
chk("NIFTY next month RESISTANCE 25100 (3 L... the big call wall)", xn["ceil"]["k"] == 25100, xn.get("ceil"))
chk("a share not in the file: not ok, says why", not N.view("NOPE", now=NOW)["ok"] and "NOPE" in N.view("NOPE", now=NOW)["err"])
y = N.view("ZZTEST", now=dt.datetime(2026, 11, 24, 20, 0, tzinfo=IST))
chk("after the Nov expiry, DEC is this month and there is no next month in the file - says so", not y["ok"] and "no next-month" in y["err"], y)
os.remove(os.path.join(T, "data", "bhav", "2026-11-11.json")); os.remove(os.path.join(T, "data", "bhav", "2026-11-12.json"))
z = N.view("ZZTEST", now=NOW)
chk("only one NSE file: no change figures (—), no crash", z["ok"] and z["prev_d"] is None and z["nxt"]["ce_d"] is None and "ce_d" not in z["rows"][0], z)
print("THE PATCH 331 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 331: NEXT MONTH's option chain - the OI build-up of the next expiry (NSE's close file), on a share's chain and the index chains */
.nm-seg{display:flex;flex-wrap:wrap;align-items:center;gap:6px;padding:6px 6px 8px;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;color:#a3aebf}
.nm-seg a{padding:5px 10px;border:1px solid #2a3546;border-radius:5px;cursor:pointer;color:#c9d1dc;white-space:nowrap;text-decoration:none}
.nm-seg a.on{background:#f5a623;border-color:#f5a623;color:#1a1205}
.nm-seg a.nx:not(.on){border-color:#5c4410;color:#f5c26b}
.nm-seg .nm-l{color:#8b97a9}
.oc-h .nm-seg{padding:0}
.gxnm{font:13px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3}
.gxnm .up{color:#26c281}.gxnm .dn{color:#f0544f}.gxnm .am{color:#f5a623}.gxnm .dm{color:#a3aebf}.gxnm .mu{color:#8b97a9}
.gxnm .n{font-family:ui-monospace,"SF Mono",Menlo,Consolas,monospace;font-variant-numeric:tabular-nums}
.nm-card{background:#0b1017;border:1px solid #1c2532;border-radius:8px;padding:10px 12px;margin:0 6px 10px}
.nm-ct{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap;font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.1em;color:#a3aebf;margin-bottom:8px}
.nm-ct small{font:500 11px -apple-system,"Segoe UI",Roboto,sans-serif;letter-spacing:0;color:#8b97a9}
.nm-kpi{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}
.nm-k{background:#0e141d;border:1px solid #1c2532;border-radius:6px;padding:8px 9px;min-width:0}
.nm-k .l{font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#8b97a9}
.nm-k .v{font:700 15px ui-monospace,Menlo,monospace;margin-top:2px;overflow-wrap:anywhere}
.nm-k .s{font-size:11px;color:#a3aebf;margin-top:1px}
.nm-read{margin-top:9px;padding:8px 10px;border-radius:6px;background:#121923;border-left:3px solid #f5a623;color:#e6edf3;font-size:12.5px}
.nm-roll{display:grid;grid-template-columns:62px minmax(0,1fr) 48px;gap:5px 8px;align-items:center;font:12px ui-monospace,Menlo,monospace}
.nm-roll .b{height:8px;border-radius:4px;background:#1b222d;overflow:hidden}.nm-roll .b i{display:block;height:100%;background:#f5a623}
.nm-roll .p{text-align:right;color:#e6edf3}.nm-roll .d{color:#a3aebf}
.nm-chips{display:flex;flex-wrap:wrap;gap:5px}
.nm-chip{font:600 11px ui-monospace,Menlo,monospace;padding:3px 8px;border-radius:4px;background:#121923;border:1px solid #273244;white-space:nowrap}
.nm-chip.ce{color:#f0544f;border-color:#5c1d1f}.nm-chip.pe{color:#26c281;border-color:#1d5c42}.nm-chip.x{color:#a3aebf;text-decoration:line-through}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb{width:100%;border-collapse:collapse;font:12px ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th{position:sticky;top:var(--wshh,0px);z-index:1;background:#0a0c10;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.04em;color:#8b97a9;padding:6px 5px;border-bottom:1px solid #1c2532;text-align:right}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.c{text-align:center}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.l{text-align:left}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.ce{color:#f58a86}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.pe{color:#4fd69c}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td{padding:5px 5px;border-bottom:1px solid #121923;text-align:right;position:relative;white-space:nowrap}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.l{text-align:left}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.k{text-align:center;font-weight:700;background:#0e141d;color:#e6edf3}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td span{position:relative}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb .ch{display:block;font-size:11px;position:relative}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb .bar{position:absolute;top:4px;bottom:4px;opacity:.2;border-radius:2px}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.ce .bar{right:0;background:#f0544f}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.pe .bar{left:0;background:#26c281}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.atm td{border-top:1px solid #f5a623;border-bottom:1px solid #f5a623}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.atm td.k{background:#f5a623;color:#1a1205}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.itmc td.ce,:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.itmp td.pe{background:rgba(245,166,35,.05)}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb u{text-decoration:none;font:700 11px ui-monospace,Menlo,monospace;padding:0 4px;border-radius:3px;margin-left:4px}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb u.r{background:#3a1416;color:#f58a86}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb u.s{background:#0d3324;color:#4fd69c}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.spt td{padding:0;border:0;height:16px;text-align:center}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.spt td span{display:inline-block;background:#1565c0;color:#fff;font-size:11px;padding:0 8px;border-radius:7px;z-index:1}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb tr.spt td:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:1px solid #1565c0}
:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.cp,:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.cp{color:#a3aebf}
.nm-leg{font-size:11.5px;color:#a3aebf;padding:8px 6px 2px}
.nm-empty{padding:14px 12px;color:#a3aebf;font-size:12.5px}
@media(max-width:899px){
  .nm-card{margin:0 0 10px;padding:9px 10px}.nm-kpi{gap:6px}.nm-k{padding:7px}.nm-k .v{font-size:13.5px}
  :is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb{font-size:11.5px}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td,:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th{padding:5px 3px}:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb td.cp,:is(#mk-idx,#focus,#fbody,#wsOi,#gxnmroot) .nm-tb th.cp{display:none}
}
@media(min-width:1100px){ #mk-idx .nm-kpi{grid-template-columns:repeat(6,minmax(0,1fr))} }
</style>
<script>/* patch 331: NEXT MONTH's option chain. A share's OPTION CHAIN and the NIFTY / BANKNIFTY option chains get a switch: this month (the live
   chain, unchanged) | next month (DEC): every strike's open interest at NSE's last close, what was added since the day before, the next month's
   RESISTANCE / SUPPORT / PCR, the biggest builds and the ROLLOVER (the share of the option OI already in the next month, day by day). */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], WD=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dm=s=>{ const m=String(s||"").match(/(\d{4})-(\d{2})-(\d{2})/); return m?(+m[3])+" "+MON[+m[2]-1]:E(s); };
  const dw=s=>{ const m=String(s||"").match(/(\d{4})-(\d{2})-(\d{2})/); return m?WD[new Date(Date.UTC(+m[1],+m[2]-1,+m[3])).getUTCDay()]+" "+dm(s):E(s); };
  const L=v=>v==null?"—":Math.abs(v)>=1e7?(v/1e7).toFixed(2)+" Cr":Math.abs(v)>=1e5?(v/1e5).toFixed(2)+" L":Math.round(v).toLocaleString("en-IN");
  const SL=v=>v==null?"—":(v>0?"+":v<0?"−":"")+L(Math.abs(v));
  const K=v=>Number(v).toLocaleString("en-IN",{maximumFractionDigits:2});
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const D={}, ST={share:{}, ix:false};                       /* D[sym] = {t, v, busy} · ST.share[sym] = next month on? · ST.ix = index next month on? */
  function data(sym, redraw){ sym=String(sym||"").toUpperCase(); if(!sym) return null; const c=D[sym];
    if(c&&(c.busy||Date.now()-c.t<600000)) return c.v;
    D[sym]={t:Date.now(),v:c?c.v:null,busy:true};
    fetch("nextoi?k="+encodeURIComponent(KEY())+"&sym="+encodeURIComponent(sym),{cache:"no-store"}).then(r=>r.ok?r.json():null).then(v=>{
      const old=JSON.stringify((D[sym]||{}).v||null); D[sym]={t:Date.now(),v:v&&v.s===sym?v:null,busy:false};
      if(JSON.stringify(D[sym].v)!==old) try{ redraw(); }catch(e){} }).catch(()=>{ D[sym]={t:Date.now(),v:c?c.v:null,busy:false}; });
    return c?c.v:null; }
  window.gxNmData=data;
  /* ---- the panel (shared by the share page and the index chains) ---- */
  function panel(v, spot, mode){ const n=v.nxt, mon=n.mon;
    const tl=(l,val,s,c)=>`<div class="nm-k"><div class="l">${l}</div><div class="v n ${c||""}">${val}</div>${s?`<div class="s">${s}</div>`:""}</div>`;
    const lastR=(v.roll||[]).slice(-1)[0], firstR=(v.roll||[])[0];
    const has=v.prev_d!=null;
    const kpi=`<div class="nm-kpi">${tl("RESISTANCE",n.ceil?K(n.ceil.k):"—",n.ceil?"most "+mon+" calls · "+L(n.ceil.oi):"","dn")}${tl("SUPPORT",n.floor?K(n.floor.k):"—",n.floor?"most "+mon+" puts · "+L(n.floor.oi):"","up")}
      ${tl("PCR "+mon,n.pcr??"—",n.pcr==null?"":n.pcr>=1.2?"put heavy":n.pcr<=0.8?"call heavy":"balanced")}
      ${tl("CALLS ADDED",has?SL(n.ce_d):"—",has?"since "+dm(v.prev_d)+" · now "+L(n.ce):"total "+L(n.ce),has?(n.ce_d>0?"dn":""):"")}
      ${tl("PUTS ADDED",has?SL(n.pe_d):"—",has?"since "+dm(v.prev_d)+" · now "+L(n.pe):"total "+L(n.pe),has?(n.pe_d>0?"up":""):"")}
      ${tl("ROLLOVER",lastR?Math.round(lastR.pct)+"%":"—",lastR?"of option OI in "+mon+(firstR&&firstR!==lastR?" · "+Math.round(firstR.pct)+"% on "+dm(firstR.d):""):"","am")}</div>`;
    const head=`<div class="nm-card"><div class="nm-ct"><span>${E(mon)} ${E(dm(n.exp).split(" ")[0])} · NEXT MONTH · ${n.days} DAYS</span><small>NSE close ${E(dw(v.asof))}${has?" · change vs "+E(dm(v.prev_d)):""}</small></div>${kpi}
      ${v.read?`<div class="nm-read">${E(v.read)}</div>`:""}</div>`;
    const mx=Math.max(1,...(v.roll||[]).map(r=>r.pct));
    const roll=(v.roll||[]).length>1?`<div class="nm-card"><div class="nm-ct"><span>ROLLOVER INTO ${E(mon)}</span><small>${E(mon)} share of all option OI, day by day</small></div><div class="nm-roll">${v.roll.map(r=>`<span class="d">${E(dm(r.d))}</span><span class="b"><i style="width:${(r.pct/Math.max(mx,40)*100).toFixed(0)}%"></i></span><span class="p">${Math.round(r.pct)}%</span>`).join("")}</div></div>`:"";
    const chips=(n.builds||[]).length||(n.cuts||[]).length?`<div class="nm-card"><div class="nm-ct"><span>BIGGEST ${E(mon)} BUILDS</span><small>since ${E(dm(v.prev_d))} · calls = sellers capping, puts = sellers supporting</small></div><div class="nm-chips">${(n.builds||[]).map(b=>`<span class="nm-chip ${b.kd==="CE"?"ce":"pe"}">${K(b.k)} ${b.kd} ${SL(b.d)}</span>`).join("")}${(n.cuts||[]).map(b=>`<span class="nm-chip x">${K(b.k)} ${b.kd} ${SL(b.d)}</span>`).join("")}</div></div>`:"";
    const R=(v.rows||[]).slice().sort((a,b)=>a.k-b.k), sp=spot||v.spot, mxo=Math.max(1,...R.map(r=>Math.max(r.ce||0,r.pe||0)));
    const atm=R.length&&sp?R.reduce((b,r)=>Math.abs(r.k-sp)<Math.abs(b.k-sp)?r:b,R[0]).k:null;
    const ch=(d,isNew)=>!has?"":isNew?'<i class="ch am">new</i>':d==null?'<i class="ch mu">—</i>':`<i class="ch ${d>0?"up":d<0?"dn":"mu"}">${SL(d)}</i>`;
    let tb="", put=false; const line=sp?`<tr class="spt"><td colspan="5"><span>${mode==="ix"?"":"₹"}${K(sp)}</span></td></tr>`:"";
    R.forEach(r=>{ if(!put&&sp&&r.k>sp){ tb+=line; put=true; } const ic=sp&&r.k<sp, ip=sp&&r.k>sp;
      tb+=`<tr class="${r.k===atm?"atm ":""}${ic?"itmc ":""}${ip?"itmp":""}"><td class="ce cp">${r.ce_p!=null?K(r.ce_p):"—"}</td>
        <td class="ce"><i class="bar" style="width:${((r.ce||0)/mxo*100).toFixed(0)}%"></i><span>${L(r.ce)}</span>${ch(r.ce_d,r.ce_new)}</td>
        <td class="k">${K(r.k)}${n.ceil&&r.k===n.ceil.k?'<u class="r">R</u>':""}${n.floor&&r.k===n.floor.k?'<u class="s">S</u>':""}</td>
        <td class="pe l"><i class="bar" style="width:${((r.pe||0)/mxo*100).toFixed(0)}%"></i><span>${L(r.pe)}</span>${ch(r.pe_d,r.pe_new)}</td>
        <td class="pe cp l">${r.pe_p!=null?K(r.pe_p):"—"}</td></tr>`; });
    if(!put) tb+=line;
    const tbl=`<table class="nm-tb kc-nm"><thead><tr><th class="cp ce">CALL ₹</th><th class="ce">CALL OI${has?" · ADDED":""}</th><th class="c">STRIKE</th><th class="l pe">PUT OI${has?" · ADDED":""}</th><th class="cp l pe">PUT ₹</th></tr></thead><tbody>${tb}</tbody></table>
      <div class="nm-leg">${E(mon)} expiry ${E(dm(n.exp))} · OI and premium at NSE's close of ${E(dw(v.asof))}${has?" · ADDED = change since "+E(dm(v.prev_d)):""} · R = resistance (most calls above the price) · S = support (most puts below) · new = no OI the day before · updated each evening after NSE's file (about 7 pm)</div>`;
    return `<div class="gxnm">${head}${roll}${chips}<div class="nm-card" style="padding:8px 4px">${tbl}</div></div>`; }
  /* ---- the share page: OPTION CHAIN ---- */
  function shareRedraw(){ try{ const w=document.getElementById("wsOi"); if(w) w.dataset.cs=""; }catch(e){} try{ if(typeof paint==="function") paint(); }catch(e){} }
  window.gxNmShare=function(on){ const s=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase(); if(!s) return; ST.share[s]=!!on; shareRedraw(); };
  if(typeof chainHTML==="function"){ const O=chainHTML; chainHTML=function(){ const s=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase();
      const v=data(s,shareRedraw), ok=v&&v.ok&&v.nxt, on=ok&&ST.share[s];
      const near=String((typeof FLV!=="undefined"&&FLV&&FLV.exp)||(typeof FOI!=="undefined"&&FOI&&FOI.exp)||(ok&&v.near&&v.near.exp)||"").slice(0,10);
      const seg=ok?`<div class="nm-seg"><span class="nm-l">EXPIRY</span><a class="${on?"":"on"}" onclick="gxNmShare(false)">${near?E(dm(near)).toUpperCase():"THIS MONTH"} · LIVE</a><a class="nx ${on?"on":""}" onclick="gxNmShare(true)">${E(v.nxt.mon)} ${E(dm(v.nxt.exp).split(" ")[0])} · NEXT MONTH OI BUILD-UP</a></div>`:"";
      if(on){ const sp=(typeof FLV!=="undefined"&&FLV&&FLV.px)||(typeof FD!=="undefined"&&FD&&(FD.spot||FD.px))||v.spot; return seg+panel(v,sp,"share"); }
      return seg+O.apply(this,arguments); }; }
  /* ---- NIFTY / BANKNIFTY option chain ---- */
  function ixRedraw(){ try{ if(typeof drawMarket==="function"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } }catch(e){} }
  window.gxNmIx=function(on){ ST.ix=!!on; ixRedraw(); };
  if(typeof idxDeskHTML==="function"){ const O=idxDeskHTML; idxDeskHTML=function(J){ const T=(typeof IDXT!=="undefined"&&IDXT)||"NIFTY";
      const v=data(T,ixRedraw), ok=v&&v.ok&&v.nxt, d=J&&J[T];
      const seg=ok?`<span class="nm-seg"><a class="${ST.ix?"":"on"}" onclick="gxNmIx(false)">${d&&d.exp?E(dm(d.exp)).toUpperCase()+" · LIVE":"LIVE"}</a><a class="nx ${ST.ix?"on":""}" onclick="gxNmIx(true)">${E(v.nxt.mon)} ${E(dm(v.nxt.exp).split(" ")[0])} · NEXT MONTH</a></span>`:"";
      if(ok&&ST.ix){ const tabs=`<span class="oc-seg">${["NIFTY","BANKNIFTY"].map(n=>`<a class="${T===n?"on":""}" onclick="idxSet('${n}')">${n}</a>`).join("")}</span>`;
        const sp=d&&d.spot||v.spot;
        return `<div class="oc"><div class="oc-h">${tabs}${seg}<span class="oc-px nm">${K(sp)}</span><span class="oc-meta"><span class="oc-tag">EXP ${E(dm(v.nxt.exp))} · ${v.nxt.days} DTE</span><span class="oc-tag">NSE CLOSE ${E(dm(v.asof))}</span></span></div>${panel(v,sp,"ix")}</div>`; }
      let h=O.apply(this,arguments);
      if(seg){ const m=h.match(/<span class="oc-seg">[\s\S]*?<\/span>/); if(m) h=h.replace(m[0],m[0]+seg); }
      return h; };
    ixRedraw(); }
})();
</script>
ADD_H
echo "=== test (made-up NSE files, nothing fetched)"
python3 $W/p331test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/nextmonth.py $D/nextmonth.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 331" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/nextoi":                   # patch 331: next month's option chain - OI build-up from NSE's close file (read only)
                try:
                    import nextmonth
                    v_ = nextmonth.view((parse_qs(u.query).get("sym") or [""])[0])
                except Exception as ex_:
                    v_ = {"ok": False, "err": str(ex_)[:120]}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /nextoi")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 331" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the NEXT MONTH switch")
pc = os.path.join(D, "pagecheck.py")
if os.path.exists(pc):
    q = open(pc, encoding="utf-8").read()
    if "/nextoi" not in q:
        a1, a2 = '"/oi?sym=%s",', '"/resultsrecent",'
        if q.count(a1) == 1 and q.count(a2) == 1:
            q = q.replace(a1, a1 + ' "/nextoi?sym=%s",', 1).replace(a2, a2 + ' "/nextoi?sym=NIFTY", "/nextoi?sym=BANKNIFTY",', 1)
            open(pc, "w", encoding="utf-8").write(q); print("  pagecheck.py: saves /nextoi too")
        else:
            print("  pagecheck.py: not changed (its list looks different) - the page works anyway")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py nextmonth.py || back
[ -f $D/pagecheck.py ] && { python3 -m py_compile $D/pagecheck.py || back; }
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== NSE's end-of-day files GIR keeps"
cd $D && timeout 60 python3 bhavfull.py 2>&1 | head -3
echo "=== NEXT MONTH, as GIR now shows it"
cd $D && timeout 90 python3 nextmonth.py NIFTY BANKNIFTY RELIANCE
echo "✅ patch 331 done - open a share (OPTION CHAIN; on the phone the OI BUILD-UP tab) or OPTIONS, tap  DEC · NEXT MONTH. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/nextmonth.py; systemctl restart gir-dash"
