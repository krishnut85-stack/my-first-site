#!/bin/bash
# PATCH 342b - NO FAKE CRORES IN THE LIVE FUTURES (16 Nov 10:41: the first live reading showed IDEA NOV -₹5,423 cr - Kite and NSE count IDEA's
#   November contract differently, a lot / contract change, not money). A month whose open interest moves 40%+ in a day is now marked
#   "⚠ data mismatch", left out of the TOTAL and the build-up word (as patch 325 does in the checklist). futlive.py replaced (342's only),
#   home.html: BIG MONEY and the share line say "⚠ data mismatch" for that month; the table sorts by tapping PRICE / NEAR / NEXT / TOTAL /
#   TRADED (▼▲); the BIG MONEY key shows ▲ long build-ups · ▼ short build-ups from the live TOTAL (it read ▲0 ▼0). Restarts gir-futlive only (the engine and the dashboard keep running).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 342b" $D/futlive.py 2>/dev/null && grep -q "patch 342b" $D/home.html; then echo "patch 342b - already in"; exit 0; fi
grep -q "patch 342" $D/futlive.py 2>/dev/null && grep -q "patch 342" $D/home.html || { echo "patch 342 first"; exit 1; }
cp $D/futlive.py $D/futlive.py.bak$TS; cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/futlive.py.bak$TS $D/futlive.py; cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-futlive 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/futlive.py <<'PY_FL'
"""futlive.py - patch 342 + 342b (a month whose OI moved 40%+ in a day is a data mismatch - lot / contract change - never money): READ ONLY. LIVE FUTURES BY MONTH (Rama, 16 Nov 10:30: "rectify the futures build-up - I am not able to predict
anything"). GIR's engine streams only the NEAR month; in the week before expiry traders roll NOV -> DEC, so near-month OI falls everywhere
and the build-up reads wrong (AGREE UP / DOWN stayed 0). This reader does not touch the engine:
  · every 15 s in the session: ONE or TWO Kite quote calls for every F&O future, all expiries (NOV, DEC, JAN) - far below Kite's limits
  · each month's open interest against NSE's OFFICIAL close of the last session for THAT month (data/nsefutx_<day>.json, patch 338)
  · per share: NOV / DEC / JAN ₹ crore and OI %, the TOTAL, the build-up word on the TOTAL (price = the near future vs its last close),
    ↻ ROLLOVER, the futures traded value today (volume x price, all months)
  · writes data/futlive.json (atomic). Kite session from core.get_kite() (today's login - no new login, nothing ordered, nothing sent)
python3 futlive.py once      one reading now, printed
python3 futlive.py           the loop (the gir-futlive service)"""
import os, sys, json, time, glob, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
OUT = os.path.join(BASE, "data", "futlive.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
EVERY = 15
_I = {"day": None, "map": {}}


def now_ist():
    return dt.datetime.now(IST)


def session(n):
    if n.weekday() > 4:
        return False
    try:
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return "09:15" <= n.strftime("%H:%M") <= "15:31"


def log(*a):
    print(now_ist().strftime("%H:%M:%S"), *a, flush=True)


def instruments(kite, today):
    """{underlying: [(expiry 'YYYY-MM-DD', 'NFO:TRADINGSYMBOL'), ...] nearest 3} - once a day"""
    if _I["day"] == today and _I["map"]:
        return _I["map"]
    try:
        import getdata
        rows = getdata.call(kite.instruments, "NFO")
    except Exception:
        rows = kite.instruments("NFO")
    m = {}
    for i in rows or []:
        if i.get("instrument_type") != "FUT":
            continue
        e = i.get("expiry")
        e = e.date() if isinstance(e, dt.datetime) else dt.date.fromisoformat(str(e)[:10]) if e else None
        if not e or str(e) < today:
            continue
        m.setdefault(i.get("name"), []).append((str(e), "NFO:" + i["tradingsymbol"]))
    m = {k: sorted(v)[:3] for k, v in m.items() if k}
    _I.update({"day": today, "map": m})
    return m


def base(today):
    """NSE's official close per (underlying, expiry) of the last session before today -> ({(s, exp): (oi, close)}, day)"""
    fs = sorted(f for f in glob.glob(os.path.join(BASE, "data", "nsefutx_*.json")) if os.path.basename(f)[8:18] < today)
    for f in reversed(fs):
        try:
            N = json.load(open(f))
        except Exception:
            continue
        if not N:
            continue
        out = {}
        for s, R in N.items():
            for e, px, oi, ch in R:
                out[(s, str(e)[:10])] = (oi or 0, px)
        return out, os.path.basename(f)[8:18]
    return {}, None


def word(p, o):
    if p is None or o is None or abs(o) < 0.05:
        return ""
    if p > 0:
        return "LONG BUILD-UP" if o > 0 else "SHORT COVERING"
    if p < 0:
        return "SHORT BUILD-UP" if o > 0 else "LONG UNWINDING"
    return ""


def compute(M, Q, B):
    """M = instruments map, Q = kite quote answer, B = NSE base -> rows"""
    rows = {}
    known_s = {k[0] for k in B}
    for s, L in M.items():
        ms, tv = [], 0.0
        for e, key in L:
            q = Q.get(key) or {}
            oi = float(q.get("oi") or 0)
            px = float(q.get("last_price") or 0)
            if not px and not oi:
                continue
            b = B.get((s, e))
            b_oi = float(b[0]) if b else (0.0 if s in known_s else None)   # a month NSE's file has not got (listed since): all its OI is new
            ch = (oi - b_oi) if b_oi is not None else None
            odd = bool(ch is not None and b_oi and abs(ch) / b_oi > 0.4)   # patch 342b: IDEA 16 Nov NOV -71% = Kite vs NSE units, not ₹5,423 cr
            if odd:
                ch = None
            tv += float(q.get("volume") or 0) * px
            ms.append({"m": dt.date.fromisoformat(e).strftime("%b").upper(), "exp": e, "oi": oi, "chg": ch, "px": px,
                       "cr": round(ch * px / 1e7, 1) if ch is not None else None,
                       "pc": round(ch / b_oi * 100, 1) if (ch is not None and b_oi) else None, "new": b is None and not odd, "odd": odd,
                       "prev": float(((q.get("ohlc") or {}).get("close")) or 0) or None})
        if not ms:
            continue
        known = [x for x in ms if x["chg"] is not None]
        toi = sum(x["oi"] for x in ms)
        bsum = sum((x["oi"] - x["chg"]) for x in known)
        tch = sum(x["chg"] for x in known)
        t = {"oi": toi, "chg": tch, "cr": round(sum(x["cr"] for x in known), 1), "pc": round(tch / bsum * 100, 1) if bsum else None}
        n0 = ms[0]
        pp = round((n0["px"] / n0["prev"] - 1) * 100, 2) if n0.get("prev") and n0["px"] else None
        rest = sum(x["chg"] for x in ms[1:] if x["chg"] is not None)
        roll = bool(n0["chg"] is not None and n0["chg"] < 0 and rest > 0 and abs(n0["chg"] + rest) < 0.35 * abs(n0["chg"]))
        rows[s] = {"months": ms, "total": t, "price_pc": pp, "px": n0["px"], "bu": word(pp, t["pc"]), "near_bu": word(pp, n0["pc"]),
                   "odd": any(x.get("odd") for x in ms), "rollover": roll, "roll_pc": round(sum(x["oi"] for x in ms[1:]) / toi * 100, 1) if toi else None, "traded_cr": round(tv / 1e7, 1)}
    return rows


def once(kite, n=None):
    n = n or now_ist(); today = str(n.date())
    M = instruments(kite, today)
    B, bday = base(today)
    keys = [k for L in M.values() for _, k in L]
    Q = {}
    for i in range(0, len(keys), 450):
        part = kite.quote(keys[i:i + 450]) or {}
        Q.update(part)
        if i + 450 < len(keys):
            time.sleep(1.1)
    rows = compute(M, Q, B)
    out = {"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": today, "base_day": bday, "n": len(rows), "src": "live", "rows": rows}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, open(OUT + ".tmp", "w"), separators=(",", ":")); os.replace(OUT + ".tmp", OUT)
    return out


def get_kite():
    import core
    k = core.get_kite()
    try:
        k.timeout = 7
    except Exception:
        pass
    return k


def main():
    if sys.argv[1:2] == ["once"]:
        v = once(get_kite())
        R = v["rows"]
        nroll = sum(1 for r in R.values() if r["rollover"]); flip = sum(1 for r in R.values() if r["bu"] and r["near_bu"] and r["bu"] != r["near_bu"])
        print("LIVE FUTURES BY MONTH %s · %d shares · base NSE close %s · %d rolling over · %d where the near month alone gives the WRONG word" % (v["at"], v["n"], v["base_day"], nroll, flip))
        for s in sorted(R, key=lambda s: -abs(R[s]["total"]["cr"] or 0))[:8]:
            r = R[s]
            print("  %-11s %s · TOTAL ₹%+.1f cr → %s%s" % (s, " · ".join("%s ₹%s" % (x["m"], ("%+.1f" % x["cr"]) if x["cr"] is not None else "new") for x in r["months"]),
                  r["total"]["cr"] or 0, r["bu"] or "—", "  ↻ ROLLOVER" if r["rollover"] else ""))
        return
    k, said = None, set()
    while True:
        n = now_ist()
        if not session(n):
            time.sleep(60); continue
        try:
            if k is None:
                k = get_kite()
            t0 = time.time(); v = once(k, n)
            if "ok" not in said:
                said.add("ok"); log("live futures by month: %d shares, base %s" % (v["n"], v["base_day"]))
            time.sleep(max(3, EVERY - (time.time() - t0)))
        except Exception as ex:
            m = str(ex)[:120]
            if m not in said:
                said.add(m); log("futlive: %s" % m)
            k = None
            time.sleep(30)


if __name__ == "__main__":
    main()
PY_FL
cp $D/futmonths.py $W/futmonths.py
cat > $W/p342test.py <<'PY_T'
#!/usr/bin/env python3
"""p342test.py - LIVE FUTURES BY MONTH: a fake Kite (made-up quotes), a made-up NSE close file, temp folder - nothing real is called"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(WK, "futlive.py"), T); shutil.copy(os.path.join(WK, "futmonths.py"), T); sys.path.insert(0, T)
import futlive as L, futmonths as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
json.dump({"ZZROLL": [["2026-11-23", 100.0, 4000000, 0], ["2026-12-28", 101.0, 3000000, 0]],
           "ZZSHORT": [["2026-11-23", 200.0, 5000000, 0], ["2026-12-28", 202.0, 1000000, 0]],
           "ZZNEW": [["2026-11-23", 50.0, 1000000, 0]], "ZZODD": [["2026-11-23", 12.0, 9000000000, 0], ["2026-12-28", 12.1, 100000000, 0]]}, open(os.path.join(T, "data", "nsefutx_2026-11-13.json"), "w"))
json.dump({}, open(os.path.join(T, "data", "nsefutx_2026-11-15.json"), "w"))          # an empty file (as this morning) is skipped
class K:
    calls = 0
    def instruments(self, ex):
        R = []
        for n, e, ts in (("ZZROLL", "2026-11-23", "ZZROLL26NOVFUT"), ("ZZROLL", "2026-12-28", "ZZROLL26DECFUT"), ("ZZSHORT", "2026-11-23", "ZZS26NOVFUT"),
                         ("ZZSHORT", "2026-12-28", "ZZS26DECFUT"), ("ZZNEW", "2026-11-23", "ZZN26NOVFUT"), ("ZZNEW", "2027-01-25", "ZZN27JANFUT"), ("ZZODD", "2026-11-23", "ZZO26NOVFUT"), ("ZZODD", "2026-12-28", "ZZO26DECFUT"), ("OLD", "2026-10-27", "OLD26OCTFUT")):
            R.append({"instrument_type": "FUT", "name": n, "expiry": dt.date.fromisoformat(e), "tradingsymbol": ts})
        R.append({"instrument_type": "CE", "name": "ZZROLL", "expiry": dt.date(2026, 11, 23), "tradingsymbol": "X"})
        return R
    def quote(self, keys):
        K.calls += 1
        Q = {"NFO:ZZROLL26NOVFUT": {"oi": 3000000, "last_price": 101.0, "volume": 2000000, "ohlc": {"close": 100.0}},       # NOV -10 L, DEC +10 L: a roll
             "NFO:ZZROLL26DECFUT": {"oi": 4000000, "last_price": 102.0, "volume": 1000000, "ohlc": {"close": 101.0}},
             "NFO:ZZS26NOVFUT": {"oi": 5500000, "last_price": 190.0, "volume": 3000000, "ohlc": {"close": 200.0}},          # price -5%, OI up both months
             "NFO:ZZS26DECFUT": {"oi": 1300000, "last_price": 192.0, "volume": 500000, "ohlc": {"close": 202.0}},
             "NFO:ZZN26NOVFUT": {"oi": 1100000, "last_price": 51.0, "volume": 10000, "ohlc": {"close": 50.0}},
             "NFO:ZZN27JANFUT": {"oi": 20000, "last_price": 52.0, "volume": 100, "ohlc": {"close": 0}},
             "NFO:ZZO26NOVFUT": {"oi": 2600000000, "last_price": 11.8, "volume": 10, "ohlc": {"close": 12.0}}, "NFO:ZZO26DECFUT": {"oi": 104000000, "last_price": 11.9, "volume": 10, "ohlc": {"close": 12.1}}}
        return {k: Q[k] for k in keys if k in Q}
L.OUT = os.path.join(T, "data", "futlive.json"); L.BASE = T; M.BASE = T
v = L.once(K(), dt.datetime(2026, 11, 16, 10, 40, tzinfo=IST)); R = v["rows"]
chk("4 shares read in ONE quote call, base = NSE close 2026-11-13 (the empty file skipped), old expiries left out", v["n"] == 4 and K.calls == 1 and v["base_day"] == "2026-11-13" and "OLD" not in R, (v["n"], K.calls, v["base_day"]))
r = R["ZZROLL"]
chk("ZZROLL: NOV ₹-10.1 cr (-25%%), DEC ₹+10.2 cr (+33.3%%), TOTAL ₹+0.1 cr - ↻ ROLLOVER", [m["cr"] for m in r["months"]] == [-10.1, 10.2] and r["total"]["cr"] == 0.1 and r["rollover"], r)
chk("ZZROLL: price +1%% (near future vs its last close); near month alone says SHORT COVERING, the total does not", r["price_pc"] == 1.0 and r["near_bu"] == "SHORT COVERING" and r["bu"] == "", r)
s = R["ZZSHORT"]
chk("ZZSHORT: price -5%%, NOV +5 L, DEC +3 L -> TOTAL OI +13.3%% -> SHORT BUILD-UP, not a roll", s["bu"] == "SHORT BUILD-UP" and s["total"]["pc"] == round(800000 / 6000000 * 100, 1) and not s["rollover"], s)
chk("ZZSHORT: futures traded today ₹%s cr (volume x price, both months)" % s["traded_cr"], s["traded_cr"] == round((3000000 * 190 + 500000 * 192) / 1e7, 1), s)
n = R["ZZNEW"]
chk("ZZNEW: JAN was not listed at NSE's close -> all its OI is new (₹+0.1 cr), marked new; TOTAL ₹+0.6 cr, OI +12%%", n["months"][1]["new"] and n["months"][1]["chg"] == 20000 and n["total"]["cr"] == 0.6 and n["total"]["pc"] == 12.0, n)
fv = M.view()
chk("the page's feed (/futx) gives the LIVE reading while it is fresh", fv.get("src") == "live" and fv["n"] == 4, fv.get("src"))
j = json.load(open(L.OUT)); j["t"] -= 300; json.dump(j, open(L.OUT, "w")); M._C["k"] = None
chk("a reading older than 90 s is not shown as live (falls back to NSE's close)", M.view().get("src") == "close", M.view().get("src"))
chk("in the session 09:15-15:31 on a weekday only", L.session(dt.datetime(2026, 11, 16, 9, 20, tzinfo=IST)) and not L.session(dt.datetime(2026, 11, 16, 15, 40, tzinfo=IST)) and not L.session(dt.datetime(2026, 11, 21, 10, 0, tzinfo=IST)))
o = R["ZZODD"]
chk("ZZODD (like IDEA): NOV OI -71%% in a day = data mismatch - not counted, marked; TOTAL only from DEC (₹+4.8 cr)", o["months"][0]["odd"] and o["months"][0]["cr"] is None and o["odd"] and o["total"]["cr"] == round(4000000 * 11.9 / 1e7, 1), o)
print("THE PATCH 342 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/edits.json <<'EDITS'
[["const mcol=(r,i)=>{ const m=r.months[i]; return m?`<span class=\"${C(m.cr)}\">${CR(m.cr)}</span><small>${E(m.m)} ${PC(m.pc)}</small>`:'<span class=\"mu\">—</span>'; };", "const mcol=(r,i)=>{ const m=r.months[i]; return m?(m.odd?`<span class=\"mu\" title=\"its open interest moved 40%+ in a day - Kite and NSE count it differently (lot / contract change); not money\">⚠ data mismatch</span><small>${E(m.m)}</small>`:`<span class=\"${C(m.cr)}\">${CR(m.cr)}</span><small>${E(m.m)} ${PC(m.pc)}</small>`):'<span class=\"mu\">—</span>'; };   /* patch 342b */"], ["const ms=r.months.map(x=>`<span class=\"m\">${E(x.m)} <b class=\"${C(x.cr)}\">${CR(x.cr)}</b> <span class=\"mu\">(${PC(x.pc)})</span></span>`).join(\"\"), t=r.total, w=r.bu, a=AB[w]||\"\";", "const ms=r.months.map(x=>x.odd?`<span class=\"m\">${E(x.m)} <b class=\"mu\">⚠ data mismatch</b></span>`:`<span class=\"m\">${E(x.m)} <b class=\"${C(x.cr)}\">${CR(x.cr)}</b> <span class=\"mu\">(${PC(x.pc)})</span></span>`).join(\"\"), t=r.total, w=r.bu, a=AB[w]||\"\";   /* patch 342b */"], ["  let V=null, busy=false, F=\"ALL\", ALL=false, T=0;", "  let V=null, busy=false, F=\"ALL\", ALL=false, T=0, SK=\"tot\", SD=-1;   /* patch 342b: sortable columns */\n  window.gxFlSort=function(k){ if(SK===k) SD=-SD; else { SK=k; SD=-1; } ALL=false; draw(); };\n  const SV={px:r=>r.price_pc, near:r=>(r.months[0]||{}).cr, next:r=>(r.months[1]||{}).cr, tot:r=>r.total.cr, tv:r=>r.traded_cr, s:r=>r.s};"], [".sort((a,b)=>Math.abs(b.total.cr||0)-Math.abs(a.total.cr||0));", ".sort((a,b)=>{ const x=SV[SK](a), y=SV[SK](b); if(SK===\"s\") return SD*String(y).localeCompare(String(x)); if(x==null&&y==null) return 0; if(x==null) return 1; if(y==null) return -1; return SD*(x-y); });"], ["<thead><tr><th>SHARE</th><th>PRICE</th><th>NEAR MONTH ₹ (OI %)</th><th>NEXT MONTH ₹ (OI %)</th><th>TOTAL ₹ (OI %)</th><th>BUILD-UP (TOTAL)</th><th class=\"tv\">FUT TRADED TODAY</th></tr></thead>", "<thead><tr>${[[\"s\",\"SHARE\",\"\"],[\"px\",\"PRICE\",\"\"],[\"near\",\"NEAR MONTH ₹ (OI %)\",\"\"],[\"next\",\"NEXT MONTH ₹ (OI %)\",\"\"],[\"tot\",\"TOTAL ₹ (OI %)\",\"\"]].map(([k,l,c])=>`<th class=\"${c}\" style=\"cursor:pointer\" onclick=\"gxFlSort('${k}')\">${l} ${SK===k?(SD<0?\"▼\":\"▲\"):\"⇅\"}</th>`).join(\"\")}<th>BUILD-UP (TOTAL)</th><th class=\"tv\" style=\"cursor:pointer\" onclick=\"gxFlSort('tv')\">FUT TRADED TODAY ${SK===\"tv\"?(SD<0?\"▼\":\"▲\"):\"⇅\"}</th></tr></thead>"], ["  function draw(){ try{ drawTable(); drawLine(); }catch(e){} }", "  function tab(){ try{ if(!V||!V.ok||!V.rows) return; const a=document.querySelector('#fkeys a[data-v=\"mk-big\"]'); if(!a) return; const R=Object.values(V.rows);\n      const up=R.filter(r=>r.bu===\"LONG BUILD-UP\").length, dn=R.filter(r=>r.bu===\"SHORT BUILD-UP\").length, h=`<b>B</b>BIG MONEY <span class=\"pu\">▲${up}</span> <span class=\"pd\">▼${dn}</span>`;\n      if(a.innerHTML!==h){ a.innerHTML=h; a.title=`futures by month (TOTAL of all months${V.src===\"live\"?\", live\":\"\"}): ▲ ${up} long build-up · ▼ ${dn} short build-up`; } }catch(e){} }   /* patch 342b */\n  function draw(){ try{ drawTable(); drawLine(); tab(); }catch(e){} }\n  setInterval(tab,3000);"]]
EDITS
echo "=== test (a fake Kite, made-up NSE file, nothing real called)"
python3 $W/p342test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/futlive.py $D/futlive.py || back
python3 - $D/home.html $W/edits.json <<'PY_EDIT' || back
import sys, json
h, R = sys.argv[1], json.load(open(sys.argv[2], encoding="utf-8"))
t = open(h, encoding="utf-8").read()
for a, b in R:
    if t.count(a) != 1:
        print("❌ home.html: a patch 342 line found %d times - nothing changed, send this to Claude" % t.count(a)); sys.exit(1)
    t = t.replace(a, b, 1)
open(h, "w", encoding="utf-8").write(t); print("  home.html: '⚠ data mismatch' instead of a fake crore figure")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && python3 -m py_compile futlive.py || back
systemctl restart gir-futlive; sleep 3
echo "  gir-futlive: $(systemctl is-active gir-futlive)"
[ "$(systemctl is-active gir-futlive)" = "active" ] || back
echo "=== one LIVE reading now"
( cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 90 python3 futlive.py once ) 2>&1 | tail -6
echo "✅ patch 342b done - refresh GIR: a contract-change month shows '⚠ data mismatch', not fake crores."
echo "   undo: cp $D/futlive.py.bak$TS $D/futlive.py; cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-futlive"
