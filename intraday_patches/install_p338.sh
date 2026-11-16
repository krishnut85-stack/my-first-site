#!/bin/bash
# PATCH 338 - FUTURES BY MONTH + THE TOTAL (Rama, 16 Nov: "show the futures value for NOV, for DEC separately, and add them up - the total;
#   bullish / bearish works on the total too"). GIR's futures ₹ crore and build-up word came from the NEAR month only: in the week before expiry
#   traders roll - NOV OI falls, DEC rises by about the same - and the near month alone read "money leaving" when it only moved.
#   · nseaudit.py: one line more - every expiry of every future to data/nsefutx_<day>.json (the engine's own nsefut file is NOT changed)
#   · futmonths.py (READ ONLY): per share NOV ₹ cr · DEC ₹ cr · (JAN) · TOTAL ₹ cr with OI %, the build-up word on the TOTAL, rollover %,
#     ↻ ROLLOVER when NOV's fall is matched by DEC's rise · dashserve.py /futx
#   · a share's page (phone, iPad, laptop): FUTURES BY MONTH under "who is pulling"
#   From NSE's end-of-day file (official, each evening). The live in-session total needs the engine - after the close.
#   Tested: 9 + 4 sizes. Restarts the dashboard. Re-runs the NSE audit once (no Telegram) so Friday's numbers show now.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 338" $D/home.html && grep -q "patch 338" $D/dashserve.py && [ -f $D/futmonths.py ]; then echo "patch 338 - already in"; cd $D && python3 futmonths.py; exit 0; fi
grep -q "patch 335" $D/home.html || { echo "patch 335 first"; exit 1; }
grep -q '"nsefut_%s.json" % day), "w"))' $D/nseaudit.py && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "nseaudit's futures file line / dashserve's route not found - nothing done, send this to Claude"; exit 1; }
F="dashserve.py home.html nseaudit.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/futmonths.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/futmonths.py <<'PY_FM'
"""futmonths.py - patch 338: READ ONLY. FUTURES MONTH BY MONTH + THE TOTAL (Rama, 16 Nov: "show the futures value for NOV, for DEC separately,
and add them up - the total. Bullish / bearish works on the total too").
  why     GIR's futures ₹ crore and build-up word came from the NEAR month only. In the week before expiry traders ROLL: November OI falls,
          December OI rises by about the same - near month alone reads "money leaving / unwinding" when it only moved.
  source  NSE's own end-of-day F&O file - every expiry (the NSE audit writes data/nsefutx_<day>.json from patch 338 on); the day's price
          move from NSE's close files (data/bhav/<day>.json, the underlying's close)
  gives   per share: each month's OI, its change, ₹ crore (change x that contract's close), OI %; the TOTAL; the build-up word on the total
          (price up + OI up = LONG BUILD-UP ...); rollover % (OI in the later months); ROLLOVER when the near month's fall is matched by
          the later months' rise (the total moved less than 35% of the near month's change)
python3 futmonths.py [SYM ...]      what GIR will show"""
import os, re, sys, json, glob, time, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {"k": None, "v": None}


def _cr(chg, px):
    return round((chg or 0) * (px or 0) / 1e7, 1)


def _pc(oi, chg):
    try:
        return round(chg / (oi - chg) * 100, 1) if oi and oi - chg > 0 else None
    except Exception:
        return None


def word(price_pc, oi_pc):
    if price_pc is None or oi_pc is None or abs(oi_pc) < 0.05:
        return ""
    if price_pc > 0:
        return "LONG BUILD-UP" if oi_pc > 0 else "SHORT COVERING"
    if price_pc < 0:
        return "SHORT BUILD-UP" if oi_pc > 0 else "LONG UNWINDING"
    return ""


def one(rows, price_pc=None):
    """rows = [[exp, close, oi, chg], ...] (sorted by expiry) -> the month-by-month view"""
    rows = sorted([r for r in rows if r and r[0]], key=lambda r: str(r[0]))[:3]
    if not rows:
        return None
    ms = []
    for e, px, oi, ch in rows:
        try:
            m = dt.date.fromisoformat(str(e)[:10]).strftime("%b").upper()
        except Exception:
            m = str(e)[:7]
        ms.append({"m": m, "exp": str(e)[:10], "oi": oi or 0, "chg": ch or 0, "cr": _cr(ch, px), "pc": _pc(oi, ch or 0), "px": px})
    toi, tch = sum(x["oi"] for x in ms), sum(x["chg"] for x in ms)
    t = {"oi": toi, "chg": tch, "cr": round(sum(x["cr"] for x in ms), 1), "pc": _pc(toi, tch)}
    n0, rest = ms[0]["chg"], sum(x["chg"] for x in ms[1:])
    roll = bool(n0 < 0 and rest > 0 and abs(n0 + rest) < 0.35 * abs(n0))
    return {"months": ms, "total": t, "roll_pc": round(sum(x["oi"] for x in ms[1:]) / toi * 100, 1) if toi else None, "rollover": roll,
            "price_pc": price_pc, "bu": word(price_pc, t["pc"]), "near_bu": word(price_pc, ms[0]["pc"])}


def _spot(day):
    try:
        return {s: (v or {}).get("spot") for s, v in (json.load(open(os.path.join(BASE, "data", "bhav", "%s.json" % day))).get("s") or {}).items()}
    except Exception:
        return {}


def view(now=None):
    now = now or dt.datetime.now(IST)
    fs = sorted(f for f in glob.glob(os.path.join(BASE, "data", "nsefutx_*.json")) if os.path.basename(f)[8:18] <= str(now.date()))
    if not fs:
        return {"ok": False, "err": "no month-by-month futures file yet - the NSE audit writes it each evening (18:40)", "rows": {}}
    f = fs[-1]; day = os.path.basename(f)[8:18]
    key = (f, os.path.getmtime(f))
    if _C["k"] == key:
        return _C["v"]
    try:
        N = json.load(open(f))
    except Exception as ex:
        return {"ok": False, "err": "the futures file could not be read: %s" % str(ex)[:80], "rows": {}}
    bd = sorted(os.path.basename(x)[:10] for x in glob.glob(os.path.join(BASE, "data", "bhav", "20??-??-??.json")))
    prev = [d for d in bd if d < day]
    s1, s0 = _spot(day), (_spot(prev[-1]) if prev else {})
    rows = {}
    for s, R in N.items():
        a, b = s1.get(s), s0.get(s)
        pp = round((a / b - 1) * 100, 2) if a and b else None
        v = one(R, pp)
        if v:
            rows[s] = v
    out = {"ok": True, "day": day, "prev": prev[-1] if prev else None, "rows": rows, "n": len(rows)}
    _C.update({"k": key, "v": out})
    return out


if __name__ == "__main__":
    v = view()
    if not v.get("ok"):
        print("FUTURES BY MONTH: %s" % v.get("err")); sys.exit(0)
    want = [x.upper() for x in sys.argv[1:]] or sorted(v["rows"], key=lambda s: -abs(v["rows"][s]["total"]["cr"]))[:8]
    nroll = sum(1 for r in v["rows"].values() if r["rollover"]); flip = sum(1 for r in v["rows"].values() if r["bu"] and r["near_bu"] and r["bu"] != r["near_bu"])
    print("FUTURES BY MONTH (NSE close %s): %d shares · %d rolling over · %d where the near month alone gave the WRONG build-up word" % (v["day"], v["n"], nroll, flip))
    for s in want:
        r = v["rows"].get(s)
        if not r:
            print("  %s: not in NSE's file" % s); continue
        m = " · ".join("%s ₹%+.1f cr (%s)" % (x["m"], x["cr"], ("%+.1f%%" % x["pc"]) if x["pc"] is not None else "new") for x in r["months"])
        print("  %-11s %s · TOTAL ₹%+.1f cr (%s) → %s%s%s" % (s, m, r["total"]["cr"], ("%+.1f%%" % r["total"]["pc"]) if r["total"]["pc"] is not None else "—",
              r["bu"] or "—", "  ↻ ROLLOVER" if r["rollover"] else "", ("  (near month alone said %s)" % r["near_bu"]) if r["near_bu"] and r["near_bu"] != r["bu"] else ""))
PY_FM
cat > $W/p338test.py <<'PY_T'
#!/usr/bin/env python3
"""p338test.py - FUTURES BY MONTH + TOTAL: made-up NSE files in a temp folder (no real data, nothing fetched)"""
import os, sys, json, shutil, tempfile, datetime as dt
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data", "bhav")); shutil.copy(os.path.join(WK, "futmonths.py"), T); sys.path.insert(0, T)
import futmonths as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); OK = []
def chk(n, c_, got=""):
    OK.append(bool(c_)); print("  %s %s%s" % ("✅" if c_ else "❌", n, "" if c_ else "   got: %s" % str(got)[:400]))
J = lambda p, v: json.dump(v, open(os.path.join(T, "data", p), "w"))
# ZZROLL: a fund rolls 10 lakh shares from NOV to DEC, price up 1% - near month alone says SHORT COVERING; the total barely moved
# ZZBULL: price up 5%, NOV +2 lakh, DEC +3 lakh - LONG BUILD-UP on the total; ZZBEAR: price down, both months add - SHORT BUILD-UP
J("nsefutx_2026-11-13.json", {
  "ZZROLL": [["2026-11-23", 100.0, 4000000, -1000000], ["2026-12-28", 101.0, 3000000, 1000000], ["2027-01-25", 102.0, 100000, 20000]],
  "ZZBULL": [["2026-11-23", 200.0, 5000000, 200000], ["2026-12-28", 202.0, 1000000, 300000]],
  "ZZBEAR": [["2026-11-23", 50.0, 9000000, 600000], ["2026-12-28", 50.5, 2000000, 400000]]})
J("bhav/2026-11-12.json", {"s": {"ZZROLL": {"spot": 100.0}, "ZZBULL": {"spot": 190.0}, "ZZBEAR": {"spot": 52.0}}})
J("bhav/2026-11-13.json", {"s": {"ZZROLL": {"spot": 101.0}, "ZZBULL": {"spot": 199.5}, "ZZBEAR": {"spot": 50.0}}})
v = M.view(now=dt.datetime(2026, 11, 16, 8, 0, tzinfo=IST)); R = v["rows"]
r = R["ZZROLL"]
chk("ZZROLL: NOV ₹-10.0 cr, DEC ₹+10.1 cr, JAN ₹+0.2 cr - TOTAL ₹+0.3 cr", [x["cr"] for x in r["months"]] == [-10.0, 10.1, 0.2] and r["total"]["cr"] == 0.3, r)
chk("ZZROLL: marked ↻ ROLLOVER; the near month alone said SHORT COVERING", r["rollover"] and r["near_bu"] == "SHORT COVERING", r)
chk("ZZROLL: price +1.0% from NSE's close files; total OI +0.3% -> LONG BUILD-UP on the total", r["price_pc"] == 1.0 and r["total"]["pc"] == 0.3 and r["bu"] == "LONG BUILD-UP", r)
chk("ZZROLL: rollover %% = OI in DEC + JAN = %s%%" % r["roll_pc"], r["roll_pc"] == round(3100000 / 7100000 * 100, 1), r)
b = R["ZZBULL"]
chk("ZZBULL: NOV ₹+4.0 · DEC ₹+6.1 · TOTAL ₹+10.1 cr, OI +5.0%%, price +5%% -> LONG BUILD-UP, no rollover", b["total"]["cr"] == 10.1 and b["bu"] == "LONG BUILD-UP" and not b["rollover"] and b["total"]["pc"] == round(500000 / 5500000 * 100, 1), b)
e = R["ZZBEAR"]
chk("ZZBEAR: price -3.85%%, OI up -> SHORT BUILD-UP, TOTAL ₹+5.0 cr", e["bu"] == "SHORT BUILD-UP" and e["total"]["cr"] == 5.0, e)
chk("the file's day and the price day before: 2026-11-13 vs 2026-11-12", v["day"] == "2026-11-13" and v["prev"] == "2026-11-12", v)
os.remove(os.path.join(T, "data", "bhav", "2026-11-12.json")); M._C["k"] = None
w = M.view(now=dt.datetime(2026, 11, 16, 8, 0, tzinfo=IST))
chk("no price file for the day before: months and total still shown, no build-up word (never a guess)", w["rows"]["ZZBULL"]["bu"] == "" and w["rows"]["ZZBULL"]["total"]["cr"] == 10.1, w["rows"]["ZZBULL"])
shutil.rmtree(os.path.join(T, "data")); os.makedirs(os.path.join(T, "data")); M._C["k"] = None
chk("no file yet: not ok, says when it comes", not M.view()["ok"] and "18:40" in M.view()["err"])
print("THE PATCH 338 TEST: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True); sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 338: FUTURES BY MONTH + TOTAL on a share's page (NSE's close, every expiry) */
#gxfx{display:flex;flex-wrap:wrap;align-items:center;gap:6px 10px;margin:6px 0 8px;padding:8px 12px;border:1px solid #1c2532;border-radius:8px;background:#0b1017;color:#e6edf3;font:12.5px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif}
#gxfx .h{font:700 11.5px ui-monospace,Menlo,monospace;letter-spacing:.1em;color:#f5a623}
#gxfx .d{font-size:11.5px;color:#8b97a9}
#gxfx .m{font:600 12.5px ui-monospace,Menlo,monospace;padding:2px 8px;border-radius:4px;background:#121923;border:1px solid #273244;white-space:nowrap}
#gxfx .t{font:800 13px ui-monospace,Menlo,monospace;padding:3px 9px;border-radius:4px;background:#1b222d;border:1px solid #3a4658;white-space:nowrap}
#gxfx .up{color:#26c281}#gxfx .dn{color:#f0544f}#gxfx .mu{color:#a3aebf}
#gxfx .w{font:800 12px ui-monospace,Menlo,monospace;letter-spacing:.04em;padding:3px 9px;border-radius:4px;white-space:nowrap}
#gxfx .w.LB{background:#0d3324;color:#4fd69c}#gxfx .w.SC{background:#0d2a33;color:#7fd3f0}#gxfx .w.SB{background:#3a1416;color:#f58a86}#gxfx .w.LU{background:#3a2c10;color:#ffc35c}
#gxfx .r{font:700 11.5px ui-monospace,Menlo,monospace;padding:3px 8px;border-radius:4px;background:#2a2410;color:#ffd58a;border:1px solid #6b5418;white-space:nowrap}
#gxfx .n{flex-basis:100%;font-size:11.5px;color:#a3aebf}
@media(max-width:899px){ #gxfx{margin:6px 8px 8px;padding:8px 10px} }
</style>
<script>/* patch 338: FUTURES BY MONTH + TOTAL. GIR's futures ₹ crore and build-up came from the near month only - in the week before expiry
   traders roll from NOV to DEC and the near month alone reads "money leaving". Now, on a share's page: NOV ₹ cr · DEC ₹ cr · TOTAL ₹ cr,
   the build-up word on the TOTAL, ↻ ROLLOVER when NOV's fall is matched by DEC's rise. From NSE's end-of-day file (every expiry). */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const MON=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"], WD=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  const dw=s=>{ const m=String(s||"").match(/(\d{4})-(\d{2})-(\d{2})/); return m?WD[new Date(Date.UTC(+m[1],+m[2]-1,+m[3])).getUTCDay()]+" "+(+m[3])+" "+MON[+m[2]-1]:""; };
  const CR=v=>v==null?"—":(v>0?"+":v<0?"−":"")+"₹"+Math.abs(v).toLocaleString("en-IN",{maximumFractionDigits:Math.abs(v)>=100?0:1})+" cr";
  const PC=v=>v==null?"new":(v>0?"+":v<0?"−":"")+Math.abs(v).toFixed(1)+"%";
  const AB={"LONG BUILD-UP":"LB","SHORT BUILD-UP":"SB","SHORT COVERING":"SC","LONG UNWINDING":"LU"};
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let V=null, T=0, busy=false;
  async function pull(){ if(busy||Date.now()-T<600000) return; busy=true; T=Date.now();
    try{ const r=await fetch("futx?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ V=await r.json(); draw(); } }catch(e){} busy=false; }
  function html(s){ const r=V&&V.rows&&V.rows[s]; if(!r) return "";
    const ms=r.months.map(x=>`<span class="m">${E(x.m)} <b class="${x.cr>0?"up":x.cr<0?"dn":"mu"}">${CR(x.cr)}</b> <span class="mu">(${PC(x.pc)})</span></span>`).join("");
    const t=r.total, w=r.bu, a=AB[w]||"";
    const near=r.near_bu&&r.near_bu!==w?`<span class="n">The ${E(r.months[0].m)} contract alone would have said ${E(r.near_bu)} - the total is what counts.</span>`:"";
    return `<span class="h">FUTURES BY MONTH</span>${ms}<span class="t">TOTAL <b class="${t.cr>0?"up":t.cr<0?"dn":"mu"}">${CR(t.cr)}</b> <span class="mu">(${PC(t.pc)})</span></span>
      ${r.rollover?`<span class="r">↻ ROLLOVER - ${E(r.months[0].m)} positions moved to ${E((r.months[1]||{}).m||"next month")}, not closed</span>${w?`<span class="d">net: ${E(w.toLowerCase())} ${PC(t.pc)} (small)</span>`:""}`:(w?`<span class="w ${a}">→ ${E(w)}</span>`:"")}
      <span class="d">rollover ${r.roll_pc!=null?r.roll_pc+"%":"—"} · NSE close ${E(dw(V.day))}${r.price_pc!=null?" · price "+(r.price_pc>0?"+":"")+r.price_pc+"%":""}</span>${near}`; }
  function draw(){ try{ const s=((typeof FOC!=="undefined"&&FOC)||"").toUpperCase(); const pp=document.querySelector("#focus #ppStrip");
      let el=document.getElementById("gxfx");
      if(!s||!pp||!V||!V.ok){ if(el) el.remove(); return; }
      const h=html(s); if(!h){ if(el) el.remove(); return; }
      if(!el||el.previousElementSibling!==pp){ if(el) el.remove(); el=document.createElement("div"); el.id="gxfx"; pp.after(el); }
      if(el.dataset.k!==s+"|"+V.day){ el.innerHTML=h; el.dataset.k=s+"|"+V.day; } }catch(e){} }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; draw(); },120); }).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  setInterval(()=>{ pull(); draw(); },3000); pull(); })();
</script>
ADD_H
echo "=== test (made-up NSE files, nothing fetched)"
python3 $W/p338test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || { echo "❌ the test failed - nothing changed"; exit 1; }
cp $W/futmonths.py $D/futmonths.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "nseaudit.py"); s = open(p, encoding="utf-8").read()
if "patch 338" not in s:
    A = '"nsefut_%s.json" % day), "w"))'
    L = s.split("\n"); hit = [i for i, l in enumerate(L) if A in l]
    if len(hit) != 1:
        print("❌ nseaudit.py: the futures file line found %d times" % len(hit)); sys.exit(1)
    i = hit[0]; ind = L[i][:len(L[i]) - len(L[i].lstrip())]
    L.insert(i + 1, ind + 'json.dump({s: [[x[0], x[1], x[2], x[3]] for x in F] for s, F in FUT.items() if F}, open(os.path.join(BASE, "data", "nsefutx_%s.json" % day), "w"))   # patch 338: every expiry (NOV + DEC + JAN)')
    open(p, "w", encoding="utf-8").write("\n".join(L)); print("  nseaudit.py: every expiry kept (nsefutx) - the engine's file unchanged")
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 338" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/futx":                     # patch 338: futures month by month + the total (NSE's close, read only)
                try:
                    import futmonths
                    v_ = futmonths.view()
                except Exception as ex_:
                    v_ = {"ok": False, "err": str(ex_)[:120], "rows": {}}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /futx")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 338" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: FUTURES BY MONTH on the share page")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py nseaudit.py futmonths.py || back
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
echo "=== the NSE audit once more (no Telegram) - it now keeps every expiry (about a minute)"
( cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 240 python3 nseaudit.py --no-tg ) > $W/audit.out 2>&1; echo "  audit: $(tail -1 $W/audit.out | cut -c1-100)"
ls $D/data/nsefutx_*.json >/dev/null 2>&1 && echo "  month-by-month file: $(ls -1 $D/data/nsefutx_*.json | tail -1 | xargs basename)" || echo "  ⚠ no month-by-month file yet - it comes with tonight's audit (18:40)"
echo "=== FUTURES BY MONTH, as GIR now shows it"
cd $D && timeout 60 python3 futmonths.py
echo "✅ patch 338 done - open a share: FUTURES BY MONTH (NOV · DEC · TOTAL). Refresh the page."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/futmonths.py; systemctl restart gir-dash"
