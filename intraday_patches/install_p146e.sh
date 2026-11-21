#!/bin/bash
# PATCH 146e - SECTORS IN ONE COLUMN, HEALTHCARE / CONSTRUCTION FILLED, FII / DII FROM NSE. SECTORS: NSE's own index % where there is one
#   (HEALTHCARE, CONSTRUCTION were blank - NSE names them differently and Kite has neither), else the F&O shares' average marked F&O.
#   FII / DII: NSE's cash-market net for FII and DII, and the FIIs' F&O positions (index futures, stock futures, index calls / puts:
#   net contracts and the change from the day before) from NSE's participant-wise OI file. dashserve.py · home.html (needs 146b, 146c).
#   Restarts gir-dash only - safe any time.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g146e; mkdir -p $W
grep -q "patch 146e" $D/dashserve.py && { echo "patch 146e is already installed"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back() { for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p146etest.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p146e_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p146e_patch.py - PATCH 146e (Rama, 9 Nov 20:40):
  1. SECTORS: one % column - NSE's own sector index where there is one, else the F&O shares' average marked "F&O"; HEALTHCARE and
     CONSTRUCTION were blank (NSE calls them NIFTY HEALTHCARE INDEX / NIFTY INFRASTRUCTURE; Kite has neither) - every sector index
     Kite does not give comes from NSE's list, in the session too
  2. FII / DII from NSE itself: the day's cash market net (FII, DII) and the FIIs' F&O positions from NSE's participant-wise open
     interest file (index futures, stock futures, index options - long, short, net, the change from the day before). It showed
     "FII 0 cr".
Usage: python3 p146e_patch.py /home/globalbot/intraday  (needs 145e, 146b)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
DASH = [
    ('''         "NIFTY": "NIFTY50", "BANKNIFTY": "NIFTYBANK", "VIX": "INDIAVIX"}''',
     '''         "NIFTY": "NIFTY50", "BANKNIFTY": "NIFTYBANK", "VIX": "INDIAVIX",
         "NIFTYHEALTHCARE": "NIFTYHEALTHCAREINDEX", "NIFTYINFRA": "NIFTYINFRASTRUCTURE", "NIFTYPVTBANK": "NIFTYPRIVATEBANK"}   # patch 146e'''),
    ('''"sidx": _sidx_fix(st.get("sidx") or {}),''', '''"sidx": _sidx_all(_sidx_fix(st.get("sidx") or {})), "fii_nse": _fii_nse(),'''),
    ('''def _last_session_day(now=None):''', '''SIDX_NAMES = ["NIFTY CAPITAL MKT", "NIFTY INDIA MFG", "NIFTY BANK", "NIFTY FIN SERVICE", "NIFTY IT", "NIFTY HEALTHCARE", "NIFTY AUTO", "NIFTY FMCG",
              "NIFTY METAL", "NIFTY OIL AND GAS", "NIFTY ENERGY", "NIFTY COMMODITIES", "NIFTY INFRA", "NIFTY REALTY", "NIFTY CONSR DURBL",
              "NIFTY CONSUMPTION", "NIFTY CHEMICALS", "NIFTY MEDIA", "NIFTY SERV SECTOR", "NIFTY PSU BANK", "NIFTY PVT BANK", "NIFTY PHARMA"]


def _sidx_all(sidx):
    """patch 146e: every sector index the page maps, also those Kite does not give (HEALTHCARE, INFRA) - from NSE's list"""
    out = dict(sidx or {})
    miss = [n for n in SIDX_NAMES if not (out.get(n) or {}).get("chg") is not None]
    if miss:
        N = _nse_indices()
        for n in miss:
            x = N.get(_nkey(n))
            if x and x[0] and x[1]:
                out[n] = {"last": x[0], "chg": round((x[0] / x[1] - 1) * 100, 2), "src": "NSE"}
    return out


_FII = {"t": 0.0, "v": None}


def _fii_nse(get=None, now=None):
    """patch 146e: NSE's FII / DII: the cash market net of the last day, and the FIIs' F&O positions (participant-wise OI file) with
    the change from the day before. Cached 20 min."""
    if get is None and _FII["v"] is not None and time.time() - _FII["t"] < 1200:
        return _FII["v"]
    out = {}
    try:
        if get is None:
            import exchange
            j = exchange.nse_json("/api/fiidiiTradeReact") or []
        else:
            j = get("cash")
        for e in j if isinstance(j, list) else []:
            c = str(e.get("category") or "").upper()
            k = "FII" if "FII" in c or "FPI" in c else "DII" if "DII" in c else None
            if k:
                out.setdefault("cash", {})[k] = float(str(e.get("netValue") or 0).replace(",", ""))
                out["cash"]["date"] = e.get("date")
    except Exception:
        pass

    def part(d):
        url = "https://nsearchives.nseindia.com/content/nsccl/fao_participant_oi_%s.csv" % d.strftime("%d%m%Y")
        try:
            if get is None:
                import requests
                r = requests.get(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"}, timeout=20)
                txt = r.text if r.status_code == 200 else ""
            else:
                txt = get(url) or ""
        except Exception:
            txt = ""
        rows, head = {}, None
        for ln in txt.splitlines():
            c = [x.strip().strip('"') for x in ln.split(",")]
            if c and c[0].lower().startswith("client type"):
                head = [x.lower() for x in c]
                continue
            if head and c and c[0] and len(c) >= len(head) - 1:
                try:
                    rows[c[0].upper()] = {h: float(v.replace(",", "") or 0) for h, v in zip(head[1:], c[1:]) if h}
                except ValueError:
                    continue
        return rows.get("FII")
    now = now or dt.datetime.now(IST)
    d, got = now.date(), []
    for _ in range(10):
        if d.weekday() < 5 or d == dt.date(2026, 11, 8):
            p = part(d)
            if p:
                got.append((d, p))
                if len(got) == 2:
                    break
        d -= dt.timedelta(days=1)
    if got:
        (d0, a), prev = got[0], (got[1][1] if len(got) > 1 else None)
        g = lambda r, k: r.get(k, 0.0) if r else 0.0
        fo = {"date": str(d0)}
        for name, L, S in (("idx_fut", "future index long", "future index short"), ("stk_fut", "future stock long", "future stock short"),
                           ("idx_call", "option index call long", "option index call short"), ("idx_put", "option index put long", "option index put short")):
            net = g(a, L) - g(a, S)
            fo[name] = {"long": g(a, L), "short": g(a, S), "net": net, "chg": (net - (g(prev, L) - g(prev, S))) if prev else None}
        out["fo"] = fo
    if get is None:
        _FII.update({"t": time.time(), "v": out})
    return out


def _last_session_day(now=None):'''),
]
PAGE = [
    ('''      g+=`<text x="${W-64}" y="12" fill="var(--dim)" font-size="9" text-anchor="end">NSE INDEX</text><text x="${W-6}" y="12" fill="var(--dim)" font-size="9" text-anchor="end">F&amp;O AVG</text>`;''',
     '''      g+=`<text x="${W-6}" y="12" fill="var(--dim)" font-size="9" text-anchor="end">% TODAY · F&amp;O = shares' average</text>`;   /* patch 146e: one column */'''),
    ('''<text x="${W-64}" y="${yt}" fill="${ic==null?"var(--dim)":ic>=0?"var(--up)":"var(--dn)"}" font-size="${fs}" font-weight="700" text-anchor="end">${ic==null?"—":mkPc(ic)}</text><text x="${W-6}" y="${yt}" fill="var(--dim)" font-size="${fs-1}" text-anchor="end">${mkPc(x.chg)}</text>''',
     '''${ic!=null?`<text x="${W-6}" y="${yt}" fill="${ic>=0?"var(--up)":"var(--dn)"}" font-size="${fs}" font-weight="700" text-anchor="end">${mkPc(ic)}</text>`:`<text x="${W-6}" y="${yt}" fill="${(x.chg||0)>=0?"var(--up)":"var(--dn)"}" font-size="${fs}" text-anchor="end"><tspan fill="var(--dim)" font-size="8">F&amp;O </tspan>${mkPc(x.chg)}</text>`}'''),
    ('''      <div><em>FII / DII</em>${fdt}</div>''',
     '''      <div><em>FII / DII</em>${(()=>{ const N=M.fii_nse||{}, C=N.cash, F=N.fo; if(!C&&!F) return fdt;   /* patch 146e: NSE's own */
        const cr=v=>v==null?"—":`<b class="${v>0?"pu":v<0?"pd":""}">${v>0?"+":"−"}₹${Math.abs(Math.round(v)).toLocaleString("en-IN")} cr</b>`;
        const ct=v=>v==null?"":`${v>0?"+":"−"}${Math.abs(v)>=1e5?(Math.abs(v)/1e5).toFixed(2)+" L":Math.abs(Math.round(v)).toLocaleString("en-IN")}`;
        const ln=(lab,x,bull)=>x?`${lab} <b class="${x.net>0?(bull?"pu":"pd"):x.net<0?(bull?"pd":"pu"):""}">net ${ct(x.net)}</b>${x.chg!=null?` <span class="dim">(${ct(x.chg)} vs the day before)</span>`:""}`:"";
        return `${C?`cash ${esc(C.date||"")}: FII ${cr(C.FII)} · DII ${cr(C.DII)}`:""}${F?`<br><span class="dim">FII in F&amp;O ${esc(F.date)}, contracts:</span> ${ln("index futures",F.idx_fut,1)} · ${ln("stock futures",F.stk_fut,1)}<br>${ln("index calls",F.idx_call,1)} · ${ln("index puts",F.idx_put,0)} <span class="dim">(green = bullish for the market)</span>`:""}`; })()}</div>'''),
]


def apply(p, eds):
    s = open(p, encoding="utf-8").read()
    if "patch 146e" in s:
        print("patch 146e is already in %s" % os.path.basename(p)); return None
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
cat > $D/p146etest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p146etest.py - patch 146e: FII / DII from NSE (made-up NSE answers, no network) and the sector indices Kite does not give"""
import os, sys, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
P1 = """Participant wise Open Interest (no. of contracts) in Equity Derivatives as on Nov 09, 2026
Client Type,Future Index Long,Future Index Short,Future Stock Long,Future Stock Short,Option Index Call Long,Option Index Put Long,Option Index Call Short,Option Index Put Short,Option Stock Call Long,Option Stock Put Long,Option Stock Call Short,Option Stock Put Short,Total Long Contracts,Total Short Contracts
Client,1,1,1,1,1,1,1,1,1,1,1,1,1,1
FII,60000,180000,1200000,900000,400000,350000,300000,420000,1,1,1,1,1,1
TOTAL,1,1,1,1,1,1,1,1,1,1,1,1,1,1
"""
P0 = P1.replace("FII,60000,180000,1200000,900000", "FII,62000,170000,1180000,900000")
def get(u):
    if u == "cash":
        return [{"category": "DII **", "date": "09-Nov-2026", "netValue": "2,345.10"}, {"category": "FII/FPI **", "date": "09-Nov-2026", "netValue": "-1,234.50"}]
    return P1 if "09112026" in u else P0 if "06112026" in u or "08112026" in u else ""
v = ds._fii_nse(get, dt.datetime(2026, 11, 9, 20, 40, tzinfo=ds.IST))
print(v)
check("cash: FII -1,234.5 cr, DII +2,345.1 cr, 09-Nov-2026", v["cash"]["FII"] == -1234.5 and v["cash"]["DII"] == 2345.1)
check("F&O: index futures net -1.2 L contracts (-12,000 vs the day before), stock futures net +3 L", v["fo"]["idx_fut"]["net"] == -120000 and v["fo"]["idx_fut"]["chg"] == -12000 and v["fo"]["stk_fut"]["net"] == 300000)
ds._NSEI.update({"t": 9e18, "v": {"NIFTYHEALTHCAREINDEX": (14000.0, 13805.0), "NIFTYINFRASTRUCTURE": (9000.0, 8950.0)}})
s = ds._sidx_all({"NIFTY BANK": {"last": 1, "chg": 1.51}})
check("HEALTHCARE and INFRA from NSE's list (Kite has neither): %s / %s" % (s.get("NIFTY HEALTHCARE"), s.get("NIFTY INFRA")), s["NIFTY HEALTHCARE"]["chg"] == 1.41 and s["NIFTY INFRA"]["chg"] == 0.56 and s["NIFTY BANK"]["chg"] == 1.51)
print("P146e TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p146e_patch.py $D || { rm -f $D/p146etest.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p146etest.py || back
for t in p146etest.py p146btest.py p145etest.py p145btest.py p145dtest.py p143test.py p142test.py p129test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep FAIL | head -3; back; }; }; done
systemctl restart gir-dash && sleep 10
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo "    what the page now has:"
curl -s "http://127.0.0.1:8090/market?k=$(cat $D/dash_token.txt)" | python3 -c "
import json, sys
M = json.load(sys.stdin)
S = M.get('sidx') or {}
print('      sectors: ' + ' · '.join('%s %s' % (n.replace('NIFTY ', ''), ('%+.2f%%' % v['chg']) if v.get('chg') is not None else '—') for n, v in sorted(S.items())))
F = M.get('fii_nse') or {}
print('      FII / DII cash: %s' % F.get('cash'))
fo = F.get('fo') or {}
print('      FII in F&O %s: ' % fo.get('date') + ' · '.join('%s net %s (%s)' % (k, int(v['net']), v.get('chg')) for k, v in fo.items() if isinstance(v, dict)))
"
echo
echo "PATCH 146e APPLIED. Reload the GIR page (Ctrl+F5)."
