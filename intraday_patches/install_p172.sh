#!/bin/bash
# PATCH 172 - the index chart beside NIFTY · SENSEX · BANKNIFTY · VIX (laptop): the four boxes 2 x 2 on the left, the chart wide on the
#   right; tap a box = its chart (NIFTY by default, remembered). SENSEX and VIX get charts too (5-min history from Kite, refreshed every
#   trading evening 15:50 IST by ixrefresh.py; today's minutes from the live strip). The chart labels read CEILING (CE) / FLOOR (PE).
#   The phone layout is unchanged. gir-dash restarts (the page shows 502 for 1-3 minutes) - run it outside market hours.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35 (the page restarts)"; exit 1; fi
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS
cat > $D/ixrefresh.py <<'IXREFRESH_PY'
#!/usr/bin/env python3
"""ixrefresh.py - patch 172: the index charts' history kept fresh - NIFTY 50, NIFTY BANK, INDIA VIX (NSE) and SENSEX (BSE): 5-minute
candles for the last 70 days and daily candles for 2 years, from Kite, merged into data/h3/m5 and data/h3/day (what the page's chart
reads). The timer runs it every trading evening at 15:50 IST.  python3 ixrefresh.py"""
import os, sys, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import numpy as np
import hist3y as Hh

IDX = [("NSE", "NIFTY 50"), ("NSE", "NIFTY BANK"), ("NSE", "INDIA VIX"), ("BSE", "SENSEX")]


def merge(path, rows):
    old = []
    if os.path.exists(path):
        a = np.load(path)
        old = [{"date": dt.datetime.fromtimestamp(float(t), Hh.IST), "open": o, "high": h, "low": l, "close": c, "volume": v}
               for t, o, h, l, c, v in zip(a["ts"], a["o"], a["h"], a["l"], a["c"], a["v"])]
    return Hh.save_npz(path, old + rows)


def main():
    try:
        k = Hh.kite()
    except Exception as ex:
        print("Kite not available now (%s) - the charts keep their history; it runs again at 15:50" % str(ex)[:80]); return
    tok = {}
    for exch in ("NSE", "BSE"):
        for i in k.instruments(exch):
            if i.get("segment") == "INDICES" or (exch == "BSE" and i.get("tradingsymbol") == "SENSEX"):
                tok.setdefault((exch, i["tradingsymbol"]), i["instrument_token"])
    end = dt.datetime.now(Hh.IST).date()
    out = []
    for exch, name in IDX:
        t = tok.get((exch, name))
        if not t:
            out.append("%s: no Kite token" % name); continue
        try:
            m5 = Hh.candles(k, t, end - dt.timedelta(days=70), end, "5minute", 90)
            d1 = Hh.candles(k, t, end - dt.timedelta(days=760), end, "day", 1900)
            n5 = merge(os.path.join(Hh.H3, "m5", Hh.fname(name) + ".npz"), m5)
            nd = merge(os.path.join(Hh.H3, "day", Hh.fname(name) + ".npz"), d1)
            out.append("%s: %d 5-min · %d daily candles (last %s)" % (name, n5, nd, str(m5[-1]["date"])[:16] if m5 else "-"))
        except Exception as ex:
            out.append("%s: %s" % (name, str(ex)[:80]))
    print("\n".join(out))


if __name__ == "__main__":
    main()
IXREFRESH_PY
cat > $D/p172test.py <<'P172TEST_PY'
#!/usr/bin/env python3
"""p172test.py - patch 172: the chart data for SENSEX and VIX as well as NIFTY / BANKNIFTY (made-up candles, no network)"""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dashserve as ds
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
IST = ds.IST
T = tempfile.mkdtemp(); B0, S0 = ds.BASE, ds.STATE; ds.BASE = T; ds.STATE = os.path.join(T, "none.json")
for d_ in ("m5", "day"):
    os.makedirs(os.path.join(T, "data", "h3", d_))
def bars(fn, base, day):
    t0 = dt.datetime(2026, 11, day, 9, 15, tzinfo=IST).timestamp()
    ts = np.array([t0 + 300 * i for i in range(75)]); c = base + np.arange(75) * 0.1
    np.savez(os.path.join(T, "data", "h3", "m5", fn + ".npz"), ts=ts, o=c, h=c + 1, l=c - 1, c=c, v=np.zeros(75))
bars("SENSEX", 81000.0, 9); bars("INDIA_VIX", 17.0, 9); bars("NIFTY_BANK", 59700.0, 9)
now = dt.datetime(2026, 11, 11, 10, 0, tzinfo=IST)
for n, fn, lo in (("SENSEX", "SENSEX", 81000.0), ("VIX", "INDIA_VIX", 17.0), ("BANKNIFTY", "NIFTY_BANK", 59700.0)):
    ds._IXH.clear()
    x = ds.ixhist(n, now)
    check("%s: its own 5-min history (%d candles, first %.1f)" % (n, len(x.get("t") or []), (x.get("c") or [0])[0]), x.get("n") == n and len(x["t"]) == 75 and abs(x["c"][0] - lo) < 0.01)
ds._IXH.clear()
check("anything else is still NIFTY", ds.ixhist("XYZ", now).get("n") == "NIFTY")
ds._HOME["v"] = {"idx": {"NIFTY": {"last": 25000.0}, "BANKNIFTY": {"last": 59000.0}, "SENSEX": {"last": 81100.0}, "VIX": {"last": 17.4}}}
ds._IX.update({"day": None, "b": {}, "saved": 0})
ds.ix_tick(dt.datetime(2026, 11, 11, 10, 1, tzinfo=IST))
check("today's minutes are kept for SENSEX and VIX too", all(n in ds._IX["b"] for n in ("NIFTY", "BANKNIFTY", "SENSEX", "VIX")))
ds.BASE, ds.STATE = B0, S0; shutil.rmtree(T)
print("P172 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P172TEST_PY
cat > $W/p172_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p172_patch.py - PATCH 172: the index chart beside NIFTY / SENSEX / BANKNIFTY / VIX (laptop). Tap a box = its chart (NIFTY by default).
home.html: the chart moves up next to the four index boxes (2 x 2) on screens 1100 px and wider; the boxes switch it; the chart's own
buttons gain SENSEX and VIX; CEILING (CE) / FLOOR (PE) labels. dashserve.py: the chart data for SENSEX and VIX too (5-min history kept
by ixrefresh.py, today's minutes from the live strip). Usage: python3 p172_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"

CSS = """
/* patch 172: the index chart beside the four index boxes (laptop) */
#idxrow{background:var(--bg)}
body.topchart #idxrow{display:flex;gap:8px;padding:8px 8px 0;align-items:stretch}
body.topchart #idx{display:grid;grid-template-columns:1fr 1fr;gap:6px;padding:0;width:400px;flex:none;overflow:visible;border:0}
body.topchart #idx .brand{grid-column:1/-1;justify-content:center;padding:6px 16px;font-size:17px}
body.topchart #idx .ix{min-width:0;cursor:pointer}
body.topchart #idx .ix:hover{border-color:var(--line2)}
body.topchart #idx .ix.on{border-color:var(--amber);box-shadow:inset 0 0 0 1px var(--amber)}
body.topchart #idx .st{grid-column:1/-1;margin-left:0;flex-wrap:wrap;white-space:normal;padding:2px 4px;gap:4px 10px}
body.topchart #idxrow #q-nif{flex:1;min-width:0;background:var(--panel);border:1px solid var(--line);border-radius:7px;display:flex;flex-direction:column;height:310px}
body.topchart #idxrow #q-nif h3{display:none}
body.topchart #idxrow #mk-nif{flex:1;min-height:0;overflow:hidden;padding:4px 6px}
@media(min-width:1100px){body.topchart #mk{grid-template-areas:"ear ear ear ear" "dsk dsk dsk dsk" "mov don don act" "mov mon mon nws" "ins idx rot nws" !important}}
</style>"""

JS = """
/* patch 172: the index chart beside the index boxes on a laptop; a box = its chart */
function ixPick(n){ if(typeof ixSet==="function") ixSet("n",n); window.IXNOW=n; const q=$("q-nif"); if(q&&!document.body.classList.contains("topchart")) q.scrollIntoView({block:"nearest"});
  document.querySelectorAll("#idx .ix").forEach(e=>e.classList.toggle("on",document.body.classList.contains("topchart")&&e.dataset.n===n)); }
function topChart(){ const wide=window.innerWidth>=1100, q=$("q-nif"), idx=$("idx"), mk=$("mk"), top=$("top"); if(!q||!idx||!mk||!top) return;
  let row=$("idxrow"); if(!row){ row=document.createElement("div"); row.id="idxrow"; idx.parentNode.insertBefore(row,idx); row.appendChild(idx); }
  if(wide&&q.parentNode!==row){ top.parentNode.insertBefore(row,top); row.appendChild(q); document.body.classList.add("topchart"); }
  else if(!wide&&q.parentNode===row){ top.insertBefore(row,top.firstChild); mk.insertBefore(q,$("q-ins")); document.body.classList.remove("topchart"); }
  else return;
  ixPick(window.IXNOW||"NIFTY"); if(typeof IXC!=="undefined"&&IXC){ IXC.key=""; IXC.h=-1; } setTimeout(()=>{ try{ ixDraw(); }catch(e){} },80); }
window.addEventListener("load",()=>setTimeout(topChart,50)); window.addEventListener("resize",()=>{ clearTimeout(window.__tc); window.__tc=setTimeout(topChart,250); });
"""

H = [
 ("</style>", CSS),                                                       # the first </style> - the page's own style block
 ('return `<div class="ix"><b>${n}</b>',
  'return `<div class="ix${(document.body.classList.contains("topchart")&&(window.IXNOW||"NIFTY")===n)?" on":""}" data-n="${n}" onclick="ixPick(\'${n}\')" title="tap: its chart"><b>${n}</b>'),
 ('let IXN="NIFTY"; try{ IXN=localStorage.getItem("gir_ixn")||"NIFTY"; }catch(e){}',
  'let IXN="NIFTY"; try{ IXN=localStorage.getItem("gir_ixn")||"NIFTY"; }catch(e){} window.IXNOW=IXN;' + JS),
 ('function ixSet(k,v){ if(k==="n"){ IXN=v; if(typeof idxSet==="function"&&IDXT!==v){',
  'function ixSet(k,v){ if(k==="n"){ IXN=v; window.IXNOW=v; if(typeof idxSet==="function"&&IDXT!==v&&(v==="NIFTY"||v==="BANKNIFTY")){'),
 ('${["NIFTY","BANKNIFTY"].map(n=>b(IXN===n,n,`ixSet(\'n\',\'${n}\')`)).join("")}',
  '${["NIFTY","SENSEX","BANKNIFTY","VIX"].map(n=>b(IXN===n,n,`ixPick(\'${n}\')`)).join("")}'),
]
H_OPT = [('"CEILING (call writers)"', '"CEILING (CE)"'), ('"FLOOR (put writers)"', '"FLOOR (PE)"'),
         ("FLOOR / CEILING - the option writers' walls (the options desk)", "CEILING = the strike with the most CE open interest above the price · FLOOR = the most PE below (the options desk)")]

S = [
 ('    n = "BANKNIFTY" if "BANK" in str(n or "").upper() else "NIFTY"\n    c_ = _IXH.get(n)',
  '    u_ = str(n or "").upper()                                    # patch 172: + SENSEX, VIX\n'
  '    n = "BANKNIFTY" if "BANK" in u_ else "SENSEX" if "SENSEX" in u_ else "VIX" if "VIX" in u_ else "NIFTY"\n    c_ = _IXH.get(n)'),
 ('    fn = "NIFTY_BANK" if n == "BANKNIFTY" else "NIFTY_50"\n    t0d',
  '    fn = {"BANKNIFTY": "NIFTY_BANK", "SENSEX": "SENSEX", "VIX": "INDIA_VIX"}.get(n, "NIFTY_50")\n    t0d'),
 ('        if n == "BANKNIFTY" or b5 not in rows:', '        if n != "NIFTY" or b5 not in rows:'),
 ('    for n in ("NIFTY", "BANKNIFTY"):\n        p = (idx.get(n) or {}).get("last")', '    for n in ("NIFTY", "BANKNIFTY", "SENSEX", "VIX"):          # patch 172\n        p = (idx.get(n) or {}).get("last")'),
]


def apply(fn, eds, opt=()):
    p = os.path.join(D, fn); s = open(p, encoding="utf-8").read()
    if "patch 172" in s:
        return "%s: already" % fn
    for a, b in eds:
        if s.count(a) < 1 or (a != "</style>" and s.count(a) != 1):
            raise SystemExit("ANCHOR x%d in %s: %s" % (s.count(a), fn, a[:60]))
        s = s.replace(a, b, 1)
    for a, b in opt:
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8").write(s)
    return "%s: done" % fn


print(apply("home.html", H, H_OPT), "·", apply("dashserve.py", S))
PY_PATCH
back() { cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; }
echo "== 1. the page and the chart data"
R=$(python3 $W/p172_patch.py $D) || { echo "   $R - nothing changed"; back; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile dashserve.py ixrefresh.py || { back; echo "   does not compile - old files back"; exit 1; }
echo "== 2. the tests"
for t in p172test.py p164test.py p146btest.py; do [ -f $t ] || continue
  timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "   $t passed" || { echo "   $t FAILED - old files back:"; grep -E "FAIL|Error" /tmp/$t.log | head -4 | sed 's/^/     /'; back; exit 1; }
done
echo "== 3. the four indices' history from Kite (NIFTY, BANKNIFTY, VIX, SENSEX)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 300 python3 ixrefresh.py 2>&1 | sed 's/^/   /'
cat > $U/gir-ixrefresh.service <<'UNIT'
[Unit]
Description=GIR index charts' history (NIFTY, BANKNIFTY, VIX, SENSEX) from Kite
[Service]
Type=oneshot
TimeoutStartSec=600
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 ixrefresh.py >> data/ixrefresh.log 2>&1'
UNIT
cat > $U/gir-ixrefresh.timer <<'UNIT'
[Unit]
Description=GIR index charts' history every trading evening 15:50 IST
[Timer]
OnCalendar=Mon..Fri *-*-* 15:50:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-ixrefresh.timer >/dev/null 2>&1 && echo "   refreshed every trading evening at 15:50 IST"
echo -n "== 4. the page server restarting (the site shows 502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
if [ $OK = 1 ]; then echo "   ✅ the page is back"; else echo "   ❌ the page did not come back - old files back"; back; systemctl restart gir-dash; journalctl -u gir-dash -n 8 --no-pager | cut -c1-180 | sed 's/^/     /'; exit 1; fi
rm -rf $W
echo
echo "PATCH 172 APPLIED. On the laptop press Ctrl + Shift + R on girtrader.com: the chart sits beside the index boxes; tap SENSEX / BANKNIFTY / VIX to switch."
