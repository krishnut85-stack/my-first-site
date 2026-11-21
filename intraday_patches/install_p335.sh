#!/bin/bash
# PATCH 335 - 🌅 PRE-OPEN (Rama, 15 Nov: "during the pre-market open some shares go up and down - who decides? GIR was not updating").
#   9:00-9:08 NSE collects orders - no trades - and shows the price each share would open at; ~9:08 one opening price is fixed; trading 9:15.
#   Options have no pre-open, so no OI build-up before 9:15: the pre-open tells the GAP and WHO IS STRONGER (buy vs sell orders waiting).
#   · preopen.py (READ ONLY): NSE's own pre-open data for the F&O shares, every minute 08:59-09:20 (else 10 min), the last good copy kept
#     (data/preopen.json); "could not be read" is said, never a quiet blank · dashserve.py /preopen · the page check saves it too
#   · GIR (phone, iPad, laptop): a 🌅 PRE-OPEN button 08:55-10:00 on market days; the board opens by itself once a day 09:00-09:15:
#     GAP UP | GAP DOWN, opening price, gap %, buy vs sell orders, yesterday's futures build-up (LB/SB/SC/LU), ⛔ ban; tap a share to open it
#   The engine is not touched. Adds preopen.py; edits dashserve.py, home.html, pagecheck.py. Tested: 8 + 4 sizes. Restarts the dashboard.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 335" $D/home.html && grep -q "patch 335" $D/dashserve.py && [ -f $D/preopen.py ]; then echo "patch 335 - already in"; cd $D && timeout 60 python3 preopen.py; exit 0; fi
grep -q "patch 334" $D/home.html || { echo "patch 334 first"; exit 1; }
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "dashserve's route not found - nothing done, send this to Claude"; exit 1; }
F="dashserve.py home.html pagecheck.py"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; rm -f $D/preopen.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/preopen.py <<'PY_PO'
"""preopen.py - patch 335: READ ONLY. THE PRE-OPEN (Rama, 15 Nov: "during the pre-market open some shares go up and down - who decides? GIR was
not updating"). 9:00-9:08 NSE collects orders and shows the price the share would open at (the equilibrium price, IEP); ~9:08 one opening
price is fixed; trading starts 9:15. No option trades before 9:15 - so no OI build-up yet: what the pre-open tells is the GAP and WHO IS
STRONGER (buy orders vs sell orders).
  source  NSE's own pre-open data for the F&O shares (nseindia.com, market-data-pre-open?key=FO) with a browser's headers; every minute
          08:59-09:20, else every 10 minutes; the last good copy kept (data/preopen.json) - "could not be read" is said, never a quiet blank
  gives   per share: the expected open price, the gap % vs yesterday's close, buy vs sell quantity waiting, the matched (final) quantity
python3 preopen.py     what GIR will show"""
import os, re, json, time, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(BASE, "data", "preopen.json")
HOME = "https://www.nseindia.com/market-data/pre-open-market-cm-and-emerge-market"
URL = "https://www.nseindia.com/api/market-data-pre-open?key=FO"
HDR = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36",
       "Accept": "application/json, text/plain, */*", "Accept-Language": "en-IN,en;q=0.9", "Referer": HOME}
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"t": 0.0, "v": None}


def _f(x):
    try:
        if x in (None, "", "-"):
            return None
        return float(str(x).replace(",", ""))
    except Exception:
        return None


def parse(j):
    """NSE's answer -> {"rows": [...], "nse_t": "...", "adv", "dec"}"""
    rows = []
    for e in (j or {}).get("data") or []:
        m = e.get("metadata") or {}
        p = ((e.get("detail") or {}).get("preOpenMarket")) or {}
        s = str(m.get("symbol") or "").strip().upper()
        if not s:
            continue
        prev = _f(m.get("previousClose")) or _f(p.get("prevClose"))
        iep = _f(m.get("iep")) or _f(p.get("IEP")) or _f(m.get("lastPrice")) or _f(p.get("finalPrice"))
        pc = _f(m.get("pChange"))
        if pc is None and prev and iep:
            pc = (iep / prev - 1) * 100
        buy, sell = _f(p.get("totalBuyQuantity")), _f(p.get("totalSellQuantity"))
        rows.append({"s": s, "iep": iep, "prev": prev, "pc": round(pc, 2) if pc is not None else None, "chg": _f(m.get("change")),
                     "buy": buy, "sell": sell, "bs": round(buy / sell, 2) if buy and sell else None,
                     "fq": _f(m.get("finalQuantity")) or _f(p.get("finalQuantity")), "t": str(p.get("lastUpdateTime") or "")[:20]})
    ts = [r["t"] for r in rows if r["t"]]
    return {"rows": rows, "nse_t": max(ts) if ts else str((j or {}).get("timestamp") or "")[:20],
            "adv": sum(1 for r in rows if (r["pc"] or 0) > 0), "dec": sum(1 for r in rows if (r["pc"] or 0) < 0)}


def _fetch():
    import requests
    s = requests.Session()
    try:
        s.get("https://www.nseindia.com/", headers=dict(HDR, Accept="text/html,*/*"), timeout=15)
        s.get(HOME, headers=dict(HDR, Accept="text/html,*/*"), timeout=15)
    except Exception:
        pass
    r = s.get(URL, headers=HDR, timeout=20)
    if r.status_code != 200:
        raise RuntimeError("NSE answered %s" % r.status_code)
    return r.json()


def window(now):
    return now.weekday() < 5 and "08:59" <= now.strftime("%H:%M") <= "09:20"


def state(fetch=None, now=None):
    """-> {"ok", "err", "read_at", "nse_t", "rows", "adv", "dec", "live"} (1 min in the pre-open window, else 10 min)"""
    now = now or dt.datetime.now(IST)
    live = window(now)
    if fetch is None and _C["v"] is not None and time.time() - _C["t"] < (50 if live else 600):
        return _C["v"]
    v = {"ok": False, "err": "", "read_at": "", "nse_t": "", "rows": [], "adv": 0, "dec": 0, "src": "NSE pre-open (F&O shares)"}
    try:
        x = parse((fetch or _fetch)())
        if not x["rows"]:
            raise RuntimeError("NSE's answer had no shares")
        v.update(x, ok=True, read_at=now.strftime("%Y-%m-%d %H:%M:%S"))
        try:
            os.makedirs(os.path.dirname(F), exist_ok=True)
            json.dump(v, open(F + ".tmp", "w")); os.replace(F + ".tmp", F)
        except Exception:
            pass
    except Exception as ex:
        v["err"] = str(ex)[:120]
        try:
            old = json.load(open(F))
            v.update({k: old.get(k) for k in ("rows", "nse_t", "adv", "dec", "read_at")})
        except Exception:
            pass
    v["live"] = live
    v["now"] = now.strftime("%H:%M:%S")
    if fetch is None:
        _C.update({"t": time.time(), "v": v})
    return v


if __name__ == "__main__":
    v = state()
    R = sorted([r for r in v["rows"] if r["pc"] is not None], key=lambda r: -r["pc"])
    print("PRE-OPEN (NSE, F&O shares): %s - %d shares · %d up · %d down · NSE time %s" % (
        "read OK" if v["ok"] else "NOT READ NOW - " + v["err"], len(v["rows"]), v["adv"], v["dec"], v["nse_t"] or "—"))
    for lab, L in (("biggest gap-ups", R[:5]), ("biggest gap-downs", R[::-1][:5])):
        print("  %s: %s" % (lab, " · ".join("%s %+.2f%% (buy/sell %s)" % (r["s"], r["pc"], r["bs"] if r["bs"] is not None else "—") for r in L) or "—"))
PY_PO
cat > $W/p335test.py <<'PY_T'
#!/usr/bin/env python3
"""p335test.py - PRE-OPEN: NSE's pre-open answer read and trusted (made-up shares, temp folder, nothing fetched)"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(WK, "preopen.py"), T); sys.path.insert(0, T)
import preopen as P
P.F = os.path.join(T, "data", "preopen.json"); IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:300]))
J = {"advances": 1, "declines": 1, "timestamp": "16-Nov-2026 09:07:58", "data": [
    {"metadata": {"symbol": "ZZUP", "iep": 105, "change": 5, "pChange": 5.0, "previousClose": 100, "finalQuantity": 1200, "lastPrice": 105},
     "detail": {"preOpenMarket": {"totalBuyQuantity": 90000, "totalSellQuantity": 30000, "IEP": 105, "lastUpdateTime": "16-Nov-2026 09:07:58"}}},
    {"metadata": {"symbol": "ZZDOWN", "iep": "1,940.00", "change": -60, "pChange": "-3", "previousClose": "2,000", "finalQuantity": 0},
     "detail": {"preOpenMarket": {"totalBuyQuantity": 10000, "totalSellQuantity": 40000, "lastUpdateTime": "16-Nov-2026 09:07:55"}}},
    {"metadata": {"symbol": "ZZNOP", "previousClose": 50}, "detail": {"preOpenMarket": {"IEP": 51, "totalBuyQuantity": 0, "totalSellQuantity": 0}}}]}
NOW = dt.datetime(2026, 11, 16, 9, 5, tzinfo=IST)
v = P.state(fetch=lambda: J, now=NOW); R = {r["s"]: r for r in v["rows"]}
chk("3 shares read, NSE time 09:07:58, in the live window", v["ok"] and len(v["rows"]) == 3 and v["nse_t"].endswith("09:07:58") and v["live"], v)
chk("ZZUP: opens 105, +5% gap, buyers 3x sellers", R["ZZUP"]["iep"] == 105 and R["ZZUP"]["pc"] == 5.0 and R["ZZUP"]["bs"] == 3.0, R["ZZUP"])
chk("ZZDOWN: '1,940.00' read as 1940, -3%, buy/sell 0.25", R["ZZDOWN"]["iep"] == 1940 and R["ZZDOWN"]["pc"] == -3.0 and R["ZZDOWN"]["bs"] == 0.25, R["ZZDOWN"])
chk("ZZNOP: no pChange given - the gap worked out from the IEP (+2%); no orders - buy/sell blank", R["ZZNOP"]["pc"] == 2.0 and R["ZZNOP"]["bs"] is None, R["ZZNOP"])
chk("up / down counted: 2 up, 1 down", v["adv"] == 2 and v["dec"] == 1, v)
def boom(): raise RuntimeError("NSE answered 401")
v2 = P.state(fetch=boom, now=NOW)
chk("NSE does not answer: not ok (with why), the last good copy kept", not v2["ok"] and "401" in v2["err"] and len(v2["rows"]) == 3, v2)
chk("outside 08:59-09:20 (10:30) not live; a Saturday not live", not P.window(dt.datetime(2026, 11, 16, 10, 30, tzinfo=IST)) and not P.window(dt.datetime(2026, 11, 21, 9, 5, tzinfo=IST)))
v3 = P.state(fetch=lambda: {"data": []}, now=NOW)
chk("an empty answer is not taken as 'no moves' - not ok", not v3["ok"] and "no shares" in v3["err"], v3)
print("THE PATCH 335 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 335: 🌅 PRE-OPEN - NSE's expected opening prices 9:00-9:15 (gap, buyers vs sellers) */
#gxprep{position:fixed;left:max(10px,env(safe-area-inset-left,0px));bottom:calc(var(--gxbanb,0px) + 12px);z-index:72;display:none;font:800 12.5px -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;letter-spacing:.04em;color:#1a1205;background:#f5a623;border:0;border-radius:18px;padding:9px 14px;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.5)}
body.gxban-on #gxprep{bottom:calc(var(--gxbanb,0px) + var(--gxbanh,40px) + 10px)}
body.gxpre-btn #gxprep{display:block}
#gxpre{position:fixed;inset:0;z-index:9985;display:none;background:#06080c;color:#e6edf3;overflow:auto;-webkit-overflow-scrolling:touch;font:13px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
body.gxpre-on #gxpre{display:block}body.gxpre-on{overflow:hidden !important}
.gxp-w{max-width:1280px;margin:0 auto;padding:max(12px,env(safe-area-inset-top,0px)) 14px 30px}
.gxp-h{display:flex;flex-wrap:wrap;align-items:center;gap:8px 14px;padding:4px 0 10px;border-bottom:1px solid #1c2532}
.gxp-h b.t{font:800 17px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#f5a623}
.gxp-tag{font:600 11.5px ui-monospace,Menlo,monospace;padding:3px 8px;border:1px solid #273244;border-radius:4px;color:#c9d1dc;white-space:nowrap}
.gxp-tag.live{color:#4fd69c;border-color:#1d5c42}.gxp-tag.old{color:#f5c26b;border-color:#5c4410}
.gxp-x{margin-left:auto;font:700 13px system-ui,sans-serif;color:#1a1205;background:#f5a623;border:0;border-radius:6px;padding:8px 13px;cursor:pointer}
.gxp-how{margin:10px 0;padding:9px 12px;border-radius:6px;background:#0c1118;border:1px solid #1c2532;color:#a3aebf;font-size:12.5px}
.gxp-how b{color:#e6edf3}
.gxp-warn{margin:10px 0;padding:9px 12px;border-radius:6px;background:#3a2c10;border:1px solid #8a6418;color:#ffd58a;font-size:12.5px}
.gxp-bar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:4px 0 10px}
.gxp-bar a{font:700 11.5px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:6px 11px;border:1px solid #2a3546;border-radius:5px;color:#c9d1dc;cursor:pointer}
.gxp-bar a.on{background:#f5a623;border-color:#f5a623;color:#1a1205}.gxp-bar .l{font:600 11px ui-monospace,Menlo,monospace;color:#8b97a9;margin-left:6px}
.gxp-g{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.gxp-c{background:#0b1017;border:1px solid #1c2532;border-radius:8px;min-width:0}
.gxp-ct{display:flex;justify-content:space-between;padding:9px 12px;border-bottom:1px solid #1c2532;font:700 12px ui-monospace,Menlo,monospace;letter-spacing:.1em}
.gxp-ct small{font:500 11px -apple-system,"Segoe UI",sans-serif;letter-spacing:0;color:#8b97a9}
.gxp-r{display:grid;grid-template-columns:minmax(0,1.3fr) 76px 64px minmax(0,1.3fr);gap:8px;align-items:center;padding:7px 12px;border-bottom:1px solid #121923;cursor:pointer}
.gxp-r:hover{background:#0f1520}.gxp-r:last-child{border-bottom:0}
.gxp-r .s{font:700 12.5px ui-monospace,Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.gxp-r .s i{font-style:normal;font:700 11px ui-monospace,Menlo,monospace;padding:1px 5px;border-radius:3px;margin-left:5px;background:#1b222d;color:#a3aebf}
.gxp-r .s i.LB{background:#0d3324;color:#4fd69c}.gxp-r .s i.SC{background:#0d2a33;color:#7fd3f0}.gxp-r .s i.SB{background:#3a1416;color:#f58a86}.gxp-r .s i.LU{background:#3a2c10;color:#ffc35c}.gxp-r .s i.ban{background:#b71c1c;color:#fff}
.gxp-r .gxpx{text-align:right;font:12.5px ui-monospace,Menlo,monospace;color:#e6edf3}
.gxp-r .g{text-align:right;font:700 13px ui-monospace,Menlo,monospace}
.gxp-r .up{color:#26c281}.gxp-r .dn{color:#f0544f}
.gxp-bs{display:flex;align-items:center;gap:6px;font:11.5px ui-monospace,Menlo,monospace;color:#a3aebf;min-width:0}
.gxp-bs .b{flex:1;display:flex;height:8px;border-radius:4px;overflow:hidden;background:#1b222d;min-width:40px}.gxp-bs .b i{display:block;height:100%}
.gxp-more{padding:9px 12px;text-align:center;color:#f5a623;font:700 12px ui-monospace,Menlo,monospace;cursor:pointer}
.gxp-hd{display:grid;grid-template-columns:minmax(0,1.3fr) 76px 64px minmax(0,1.3fr);gap:8px;padding:6px 12px;font:600 11px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#8b97a9;border-bottom:1px solid #1c2532}
.gxp-hd span:nth-child(2),.gxp-hd span:nth-child(3){text-align:right}
@media(max-width:899px){ .gxp-g{grid-template-columns:1fr}.gxp-r,.gxp-hd{grid-template-columns:minmax(0,1.2fr) 70px 58px minmax(0,1fr);gap:6px;padding:7px 10px}.gxp-bs .b{min-width:24px} }
</style>
<script>/* patch 335: 🌅 PRE-OPEN. 9:00-9:08 NSE collects orders and shows the price each share would open at; ~9:08 one opening price is fixed;
   trading from 9:15. Options have no pre-open, so no OI build-up yet - the pre-open shows the GAP and WHO IS STRONGER (buy vs sell orders).
   A 🌅 PRE-OPEN button 08:55-10:00 on market days; the board opens by itself once a day 09:00-09:15 (unless closed); ?pre=1 opens it any time. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const N=(v,d)=>v==null?"—":Number(v).toLocaleString("en-IN",{minimumFractionDigits:d??2,maximumFractionDigits:d??2});
  const Q=(v)=>v==null?"—":v>=1e7?(v/1e7).toFixed(2)+" Cr":v>=1e5?(v/1e5).toFixed(1)+" L":Math.round(v).toLocaleString("en-IN");
  const ist=()=>{ const d=new Date(Date.now()+19800000+(window.GXPRE_SHIFT||0)); return {hm:d.toISOString().slice(11,16),day:d.toISOString().slice(0,10),wd:d.getUTCDay()}; };
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const forced=(()=>{ try{ return new URLSearchParams(location.search).get("pre")==="1"; }catch(e){ return false; } })();
  let V=null, MODE="both", SORT="gap", ALL=false, busy=false;
  const btn=document.createElement("button"); btn.id="gxprep"; btn.textContent="🌅 PRE-OPEN"; document.body.appendChild(btn);
  const box=document.createElement("div"); box.id="gxpre"; document.body.appendChild(box);
  function bu(s){ try{ const t=((typeof TAPE!=="undefined"&&TAPE)||[]).find(x=>x.s===s); const b=String((t&&t.bu)||"").toUpperCase().replace(/[^A-Z]/g,""); return {LB:"LB",SB:"SB",SC:"SC",LU:"LU",LONGBUILDUP:"LB",SHORTBUILDUP:"SB",SHORTCOVERING:"SC",LONGUNWINDING:"LU"}[b]||""; }catch(e){ return ""; } }
  function row(r){ const tot=(r.buy||0)+(r.sell||0), bp=tot?r.buy/tot*100:0, b=bu(r.s), ban=typeof gxBanned==="function"&&gxBanned(r.s);
    return `<div class="gxp-r" onclick="gxPreGo('${E(r.s).replace(/'/g,"")}')"><span class="s">${E(r.s)}${ban?'<i class="ban">⛔ BAN</i>':""}${b?`<i class="${b}" title="yesterday's futures build-up">${b}</i>`:""}</span>
      <span class="gxpx">${r.iep!=null?"₹"+N(r.iep):"—"}</span><span class="g ${r.pc>0?"up":r.pc<0?"dn":""}">${r.pc!=null?(r.pc>0?"+":"")+r.pc.toFixed(2)+"%":"—"}</span>
      <span class="gxp-bs">${tot?`<span class="b"><i style="width:${bp.toFixed(0)}%;background:#26c281"></i><i style="width:${(100-bp).toFixed(0)}%;background:#f0544f"></i></span><span>${r.bs!=null?(r.bs>=1?r.bs.toFixed(1)+"× buy":(1/r.bs).toFixed(1)+"× sell"):"—"}</span>`:'<span>no orders</span>'}</span></div>`; }
  function card(title,cls,L,sub){ const n=ALL?L.length:Math.min(L.length,20);
    return `<div class="gxp-c"><div class="gxp-ct"><span class="${cls}">${title} · ${L.length}</span><small>${sub}</small></div><div class="gxp-hd"><span>SHARE</span><span>OPENS AT</span><span>GAP</span><span>BUY vs SELL ORDERS</span></div>
      ${L.slice(0,n).map(row).join("")||'<div class="gxp-how">none</div>'}${L.length>n?`<div class="gxp-more" onclick="gxPreAll()">show all ${L.length} ▾</div>`:""}</div>`; }
  function draw(){ const t=ist(); if(!V){ box.innerHTML=`<div class="gxp-w"><div class="gxp-h"><b class="t">🌅 PRE-OPEN</b><button class="gxp-x" onclick="gxPreClose()">✕ CLOSE</button></div><div class="gxp-how">reading NSE's pre-open…</div></div>`; return; }
    const R=(V.rows||[]).filter(r=>r.pc!=null), key=SORT==="bs"?(r=>r.bs??1):(r=>r.pc);
    const up=R.filter(r=>r.pc>0).sort((a,b)=>SORT==="bs"?key(b)-key(a):b.pc-a.pc), dn=R.filter(r=>r.pc<0).sort((a,b)=>SORT==="bs"?key(a)-key(b):a.pc-b.pc);
    const live=V.live&&V.ok, nt=String(V.nse_t||"").replace(/^(\d+-\w+-\d+)\s*/,"");
    const stage=t.hm<"09:00"?"orders open at 9:00":t.hm<"09:08"?"ORDERS BEING COLLECTED - prices still moving":t.hm<"09:15"?"OPENING PRICE FIXED - trading starts 9:15":"market open - this was today's pre-open";
    box.innerHTML=`<div class="gxp-w"><div class="gxp-h"><b class="t">🌅 PRE-OPEN</b><span class="gxp-tag ${live?"live":"old"}">${live?"● LIVE · ":"LAST READ · "}NSE ${E(nt||"—")}</span>
      <span class="gxp-tag">${E(stage)}</span><span class="gxp-tag"><b class="up" style="color:#26c281">▲ ${V.adv||0}</b> · <b style="color:#f0544f">▼ ${V.dec||0}</b> F&amp;O shares</span><button class="gxp-x" onclick="gxPreClose()">✕ CLOSE</button></div>
      ${!V.ok?`<div class="gxp-warn">⚠ NSE's pre-open could not be read now${V.err?" ("+E(V.err)+")":""}${V.read_at?" - showing the last read, "+E(V.read_at):""}</div>`:""}
      <div class="gxp-how"><b>How the pre-open works:</b> 9:00-9:08 buyers and sellers place orders - <b>no trades yet</b>; the price shown is where the share would open if it opened now. About 9:08 NSE fixes <b>one opening price</b>. Trading starts at <b>9:15</b>. Options have no pre-open, so the <b>OI build-up starts at 9:15</b>. Read here: the <b>gap</b> and <b>who is stronger</b> (buy vs sell orders waiting). Tag = yesterday's futures build-up. Tap a share to open it.</div>
      <div class="gxp-bar"><a class="${MODE==="both"?"on":""}" onclick="gxPreSet('m','both')">BOTH</a><a class="${MODE==="up"?"on":""}" onclick="gxPreSet('m','up')">▲ GAP UP</a><a class="${MODE==="dn"?"on":""}" onclick="gxPreSet('m','dn')">▼ GAP DOWN</a>
        <span class="l">SORT</span><a class="${SORT==="gap"?"on":""}" onclick="gxPreSet('s','gap')">BIGGEST GAP</a><a class="${SORT==="bs"?"on":""}" onclick="gxPreSet('s','bs')">STRONGEST ORDERS</a></div>
      <div class="gxp-g" style="${MODE!=="both"?"grid-template-columns:1fr":""}">${MODE!=="dn"?card("▲ GAP UP","up",up,"opens above yesterday's close"):""}${MODE!=="up"?card("▼ GAP DOWN","dn",dn,"opens below yesterday's close"):""}</div></div>`; }
  async function pull(){ if(busy) return; busy=true; try{ const r=await fetch("preopen?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ V=await r.json(); if(document.body.classList.contains("gxpre-on")) draw(); } }catch(e){} busy=false; }
  window.gxPreOpen=function(){ document.body.classList.add("gxpre-on"); draw(); pull(); };
  window.gxPreClose=function(){ document.body.classList.remove("gxpre-on"); try{ localStorage.setItem("gir_pre_closed",ist().day); }catch(e){} };
  window.gxPreSet=function(k,v){ if(k==="m") MODE=v; else SORT=v; draw(); };
  window.gxPreAll=function(){ ALL=true; draw(); };
  window.gxPreGo=function(s){ document.body.classList.remove("gxpre-on"); try{ if(typeof mkOpen==="function") mkOpen(s); else if(typeof focusOn==="function") focusOn(s); }catch(e){} };
  btn.onclick=()=>window.gxPreOpen();
  document.addEventListener("keydown",e=>{ if(e.key==="Escape"&&document.body.classList.contains("gxpre-on")) window.gxPreClose(); });
  function tick(){ const t=ist(), mkt=t.wd>=1&&t.wd<=5, show=forced||(mkt&&t.hm>="08:55"&&t.hm<"10:00");
    document.body.classList.toggle("gxpre-btn",show);
    let closed=""; try{ closed=localStorage.getItem("gir_pre_closed")||""; }catch(e){}
    if(mkt&&t.hm>="09:00"&&t.hm<"09:15"&&closed!==t.day&&!document.body.classList.contains("gxpre-on")&&!window.GXPRE_AUTO){ window.GXPRE_AUTO=true; window.gxPreOpen(); }
    if(document.body.classList.contains("gxpre-on")&&!document.hidden&&(t.hm>="08:58"&&t.hm<="09:20")) pull(); }
  if(forced) window.gxPreOpen();
  setInterval(tick,30000); tick(); })();
</script>
ADD_H
echo "=== test (made-up NSE answer, nothing fetched)"
python3 $W/p335test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/preopen.py $D/preopen.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 335" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/preopen":                  # patch 335: NSE's pre-open for the F&O shares (read only)
                try:
                    import preopen
                    v_ = preopen.state()
                except Exception as ex_:
                    v_ = {"ok": False, "err": str(ex_)[:120], "rows": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /preopen")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 335" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the PRE-OPEN board")
pc = os.path.join(D, "pagecheck.py")
if os.path.exists(pc):
    q = open(pc, encoding="utf-8").read()
    a2 = '"/resultsrecent",'
    if "/preopen" not in q and q.count(a2) == 1:
        open(pc, "w", encoding="utf-8").write(q.replace(a2, a2 + ' "/preopen",', 1)); print("  pagecheck.py: saves /preopen too")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py preopen.py || back
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
echo "=== NSE's pre-open, as GIR now reads it (on a weekend: the last trading day's)"
cd $D && timeout 60 python3 preopen.py
echo "✅ patch 335 done - Monday 9:00 the PRE-OPEN board opens by itself; any time: add &pre=1 to the GIR address. Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/preopen.py; systemctl restart gir-dash"
