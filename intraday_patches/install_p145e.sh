#!/bin/bash
# PATCH 145e - THE INDEX AND SECTOR % FROM NSE ITSELF AFTER THE CLOSE + A SECTOR TAP LISTS ITS SHARES.
#   After 15:30 NIFTY / BANKNIFTY / VIX and every sector index take NSE's own official previous close (nseindia.com - a Muhurat
#   session included; 9 Nov: BANKNIFTY +1.51%, not +1.11%); then GIR's options desk's session reading; the saved closes count until
#   09:15 next morning. Tapping a sector lists its shares in F&O MOVERS (it opened one share's screen - CONSTRUCTION showed only RVNL).
#   🔄 ROTATION ON names the top 3 groups each way. dashserve.py · home.html (needs 145b, 145c). Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g145e; mkdir -p $W
grep -q "patch 145e" $D/dashserve.py && { echo "patch 145e is already installed"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back() { for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p145etest.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p145e_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p145e_patch.py - PATCH 145e: BANKNIFTY'S % RIGHT AFTER A SPECIAL SESSION. 9 Nov came after the Diwali Muhurat session (Sun 8 Nov):
Kite's previous close is the Muhurat close (BANKNIFTY 58,850.65 -> +890.60 / +1.51%), Yahoo's daily candles skip that session and
gave Friday's (59,086 -> +1.11%). The page now takes NIFTY / BANKNIFTY's previous close from GIR's own options desk reading in the
session (data/idxdesk.json, the same Kite figure, before 15:30) before any outside source; the saved closes also count until the
next morning's 09:15. 🔄 ROTATION ON names the top 3 groups each way (it listed 6 on a broad day).
NSE's own index list (nseindia.com, the official previous close) comes first for NIFTY / BANKNIFTY / VIX and every sector index after
the close. A tap on a sector (SECTORS, THROUGH THE DAY, OI BY SECTOR) lists its shares in F&O MOVERS - it opened one share's screen.
Usage: python3 p145e_patch.py /home/globalbot/intraday  (needs 145b and 145c)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
DASH = [
    ('''def _saved_pc():
    try:
        j = json.load(open(os.path.join(BASE, "data", "idx_pc.json")))
        return j.get("v") or {} if j.get("day") == dt.datetime.now(IST).strftime("%Y-%m-%d") else {}
    except Exception:
        return {}''',
     '''def _NSEI_GET(name, last):
    """the official previous close of an index when NSE's list has it and its last value matches GIR's (within 0.3%)"""
    v = _nse_indices().get(_nkey(name))
    return v[1] if (v and last and abs(v[0] / last - 1) < 0.003) else None


def _last_session_day(now=None):
    """today from 09:15, else the last weekday before today (patch 145e)"""
    now = now or dt.datetime.now(IST)
    d = now.date()
    if now.strftime("%H:%M") < "09:15" or d.weekday() > 4:
        d -= dt.timedelta(days=1)
        while d.weekday() > 4:
            d -= dt.timedelta(days=1)
    return str(d)


_NSEI = {"t": 0.0, "v": {}}
_NSYN = {"NIFTYFINSERVICE": "NIFTYFINANCIALSERVICES", "NIFTYCONSRDURBL": "NIFTYCONSUMERDURABLES", "NIFTYSERVSECTOR": "NIFTYSERVICESSECTOR",
         "NIFTYCAPITALMKT": "NIFTYCAPITALMARKETS", "NIFTYINDIAMFG": "NIFTYINDIAMANUFACTURING", "NIFTYCONSUMPTION": "NIFTYINDIACONSUMPTION",
         "NIFTY": "NIFTY50", "BANKNIFTY": "NIFTYBANK", "VIX": "INDIAVIX"}


def _nkey(n):
    k = re.sub(r"[^A-Z0-9]", "", str(n or "").upper().replace("&", "AND"))
    return _NSYN.get(k, k)


def _nse_indices(fetch=None):
    """patch 145e: NSE's own list of every index - the last value and the OFFICIAL previous close (a Muhurat session included),
    cached 5 min -> {key: (last, previous close)}"""
    if fetch is None and time.time() - _NSEI["t"] < 300:
        return _NSEI["v"]
    out = {}
    try:
        if fetch is None:
            import exchange
            fetch = exchange.nse_json
        j = fetch("/api/allIndices") or {}
        for e in (j.get("data") if isinstance(j, dict) else j) or []:
            last, pc = e.get("last"), e.get("previousClose")
            try:
                last, pc = float(str(last).replace(",", "")), float(str(pc).replace(",", ""))
            except Exception:
                continue
            if last > 0 and pc > 0:
                out[_nkey(e.get("index") or e.get("indexSymbol"))] = (last, pc)
    except Exception:
        out = {}
    if fetch is None or out:
        _NSEI.update({"t": time.time(), "v": out})
    return out


def _saved_pc(now=None):
    """the previous closes saved in the session (patch 140g) + NIFTY / BANKNIFTY's from the options desk's session reading
    (patch 145e) - for the last session's day"""
    day = _last_session_day(now)
    out = {}
    try:
        J = json.load(open(os.path.join(BASE, "data", "idxdesk.json"))) or {}
        for n in ("NIFTY", "BANKNIFTY"):
            x = J.get(n) or {}
            if x.get("day") == day and x.get("pc") and str(x.get("t") or "99") < "15:30":
                out[n] = float(x["pc"])
    except Exception:
        pass
    try:
        j = json.load(open(os.path.join(BASE, "data", "idx_pc.json")))
        if j.get("day") == day:
            out.update(j.get("v") or {})
    except Exception:
        pass
    return out'''),
    ('''    pcs = dict(_saved_pc())''', '''    pcs = dict(_saved_pc(now))
    for name, v in out.items():                                  # patch 145e: NSE's official previous close first
        n_ = _NSEI_GET(name, v.get("last"))
        if n_:
            pcs[name] = n_'''),
    ('''    pcs = _saved_pc()
    out = {}''', '''    pcs = _saved_pc(now)
    for n_ in sidx:                                              # patch 145e: NSE's official previous close first
        p_ = _NSEI_GET(n_, (sidx[n_] or {}).get("last"))
        if p_:
            pcs["SEC:" + n_] = p_
    out = {}'''),
]
PAGE = [
    ('''function mkSec(n){ OPEN_SEC=n;''', '''function mkSec(n){ if(VIEW==="market"&&$("q-mov")){ WS.sec=n; WS.pn=""; WS.bu=""; WS.k="chg"; WS.dir=-1; wsSave(); WSKEY=""; mkRe(); const q_=$("q-mov"); q_.scrollIntoView({behavior:"smooth",block:"nearest"}); q_.classList.add("flash"); setTimeout(()=>q_.classList.remove("flash"),1600); return; }   /* patch 145e: a sector = its shares, in F&O MOVERS */
  OPEN_SEC=n;'''),
    ('''/* patch 145c: 🔄 ROTATION */''', '''#q-mov.flash{outline:2px solid var(--amber);outline-offset:-2px}   /* patch 145e */
/* patch 145c: 🔄 ROTATION */'''),
    ('''money into <b>${ins.map(g=>esc(g.n)).join(" · ")}</b> ← out of <b>${outs.map(g=>esc(g.n)).join(" · ")}</b>`''',
     '''money into <b>${ins.slice(0,3).map(g=>esc(g.n)).join(" · ")}${ins.length>3?` <small>+${ins.length-3} more</small>`:""}</b> ← out of <b>${outs.slice(0,3).map(g=>esc(g.n)).join(" · ")}${outs.length>3?` <small>+${outs.length-3} more</small>`:""}</b>`   /* patch 145e: the top 3 */'''),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 145e" in s:
        print("patch 145e is already in %s" % os.path.basename(p)); return None
    for a, b in eds:
        if s.count(a) != 1:
            print("ANCHOR x%d in %s: %s" % (s.count(a), os.path.basename(p), a[:90].replace("\n", " | "))); return None
        s = s.replace(a, b)
    return s


a = apply(os.path.join(D, "dashserve.py"), DASH)
b = apply(os.path.join(D, "home.html"), PAGE)
if a is None or b is None:
    sys.exit(1)
open(os.path.join(D, "dashserve.py"), "w", encoding="utf-8").write(a)
open(os.path.join(D, "home.html"), "w", encoding="utf-8").write(b)
print("patched: dashserve.py, home.html")
PY_PATCH
cat > $D/p145etest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p145etest.py - patch 145e: 9 Nov after the Muhurat session - BANKNIFTY from the options desk's session reading: +890.60 (+1.51%)"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ds._NSEI.update({"t": 9e18, "v": {}})                      # no network in the test
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); B0 = ds.BASE; ds.BASE = T
json.dump({"NIFTY50": {"c": [25044.65], "pc": 24986.4}}, open(os.path.join(T, "charts.json"), "w"))
json.dump({"NIFTY": {"day": "2026-11-09", "t": "15:14", "spot": 25003.65, "pc": 24986.4}, "BANKNIFTY": {"day": "2026-11-09", "t": "15:14", "spot": 59700.0, "pc": 58850.65}}, open(os.path.join(T, "data", "idxdesk.json"), "w"))
IST = ds.IST
eve = dt.datetime(2026, 11, 9, 20, 15, tzinfo=IST)
idx = {"NIFTY": {"last": 25044.65, "chg": 0.06}, "BANKNIFTY": {"last": 59741.25, "chg": 1.11}}
f = ds._idx_fix(idx, eve, {"BANKNIFTY": (59741.25, 59086.0)})
check("BANKNIFTY +1.51%% from the desk's session close 58,850.65 - not Yahoo's Friday 59,086 (%s)" % f["BANKNIFTY"], f["BANKNIFTY"]["chg"] == 1.51 and f["BANKNIFTY"]["pc"] == 58850.65)
check("NIFTY +0.23%%", f["NIFTY"]["chg"] == 0.23)
m = ds._idx_fix(idx, dt.datetime(2026, 11, 10, 8, 0, tzinfo=IST), {})
check("the next morning before 09:15: the same closes (the last session's)", m["BANKNIFTY"]["chg"] == 1.51)
json.dump({"BANKNIFTY": {"day": "2026-11-09", "t": "15:40", "pc": 59085.4}}, open(os.path.join(T, "data", "idxdesk.json"), "w"))
x = ds._idx_fix({"BANKNIFTY": {"last": 59741.25, "chg": 1.11}}, eve, {})
check("a desk reading after 15:30 is not trusted (%s)" % x["BANKNIFTY"], x["BANKNIFTY"]["chg"] is None)
ds._NSEI.update({"t": 9e18, "v": {}})
ds._nse_indices(lambda path: {"data": [{"index": "NIFTY BANK", "last": 59741.25, "previousClose": 58850.65}, {"index": "NIFTY PSU BANK", "last": 8800.0, "previousClose": 8470.0},
    {"index": "NIFTY FINANCIAL SERVICES", "last": 27000.0, "previousClose": 26700.0}, {"index": "INDIA VIX", "last": 17.42, "previousClose": 17.47}]})
ds._NSEI["t"] = 9e18
y = ds._idx_fix({"BANKNIFTY": {"last": 59741.25, "chg": 1.11}, "VIX": {"last": 17.42, "chg": -0.29}}, eve, {})
check("NSE's own list: BANKNIFTY +1.51%%, VIX -0.29%% (%s)" % y, y["BANKNIFTY"]["chg"] == 1.51 and y["VIX"]["chg"] == -0.29)
z = ds._sidx_fix({"NIFTY PSU BANK": {"last": 8800.0, "chg": 9.9}, "NIFTY FIN SERVICE": {"last": 27000.0, "chg": 9.9}, "NIFTY IT": {"last": 1.0, "chg": 9.9}}, eve)
check("the sector indices from NSE's list: PSU BANK +3.90%%, FIN SERVICE +1.12%% (the name told apart), IT none (%s)" % z, z["NIFTY PSU BANK"]["chg"] == 3.9 and z["NIFTY FIN SERVICE"]["chg"] == 1.12 and z["NIFTY IT"]["chg"] is None)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("a sector tap lists its shares in F&O MOVERS", "patch 145e: a sector = its shares" in src)
ds.BASE = B0; shutil.rmtree(T)
print("P145e TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p145e_patch.py $D || { rm -f $D/p145etest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p145etest.py || back
for t in p145etest.py p145btest.py p145dtest.py p143test.py p142test.py p140ftest.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 10
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    the page now shows:"
K=$(cat $D/dash_token.txt)
curl -s "http://127.0.0.1:8090/home?k=$K" | python3 -c "
import json, sys
I = json.load(sys.stdin).get('idx') or {}
for n in ('NIFTY', 'SENSEX', 'BANKNIFTY', 'VIX'):
    x = I.get(n) or {}
    pts = (x['last'] - x['pc']) if (x.get('last') and x.get('pc')) else None
    print('      %-10s %s  %s  %s' % (n, x.get('last'), ('%+.2f' % pts) if pts is not None else '', ('(%+.2f%%)' % x['chg']) if x.get('chg') is not None else '(no sure close)'))
"
curl -s "http://127.0.0.1:8090/market?k=$K" | python3 -c "
import json, sys
S = json.load(sys.stdin).get('sidx') or {}
print('      sector indices: ' + ' · '.join('%s %s' % (n.replace('NIFTY ', ''), ('%+.2f%%' % v['chg']) if v.get('chg') is not None else '—') for n, v in sorted(S.items())))
"
echo
echo "PATCH 145e APPLIED. Reload the GIR page (Ctrl+F5)."
