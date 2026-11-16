#!/bin/bash
# PATCH 355b - A THIRD CANDIDATE IN THE PAPER TEST: 🧪 BOUNCE (Rama, 16 Nov: "ABB had a good result and was still crushed by the sector wave - when
#   it comes back it will bounce"). sectoropt.py, 14 days, real option: a share that fell 2%+ yesterday WITH its theme (the theme -1%+, the share not
#   far worse - a wave, not its own news), CE at 09:45 the next morning: 88 trades, 53% won, +₹97,000 with the card rule (stop 2.5%, half +1.5%,
#   rest 15:10), 6 of 10 days green. The market was rising in those 14 days - so it goes into the paper test, not onto a BUY card:
#   · seccand.py: a 09:45 check - BOUNCE (the 41 themes of themestudy.py) · scored each evening with the card rule · BREAK and WEAK as before
#   · the 🧪 CANDIDATES box: BOUNCE rows and its own live record
#   No sound, no BUY card. Replaces seccand.py + the patch-355 block in home.html. Restarts the dashboard and the sector reader.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
grep -q "patch 355" $D/home.html && [ -f $D/seccand.py ] && [ -f $D/themestudy.py ] || { echo "patch 355 / themestudy.py not found - nothing done"; exit 1; }
if grep -q "355b" $D/home.html && grep -q "355b" $D/seccand.py; then echo "patch 355b - already in"; exit 0; fi
cp $D/home.html $D/home.html.bak$TS; cp $D/seccand.py $D/seccand.py.bak355b
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak355b $D/seccand.py; systemctl restart gir-seclive gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/seccand.py <<'PY_SC'
#!/usr/bin/env python3
"""seccand.py - patch 355: THE SECTOR CANDIDATES, LIVE - A PAPER TEST (no sound, no BUY card). sectoropt.py (14 days, real option prices, the 2-hour
rule) found two picks with a lean:
  B  an F&O share PAST ITS 20-DAY HIGH (CE) / LOW (PE) while its sector is one of the 3 best / worst with 70%+ of its shares that way, the share
     on the right side of VWAP - checked at 10:00 and 10:30            (94 trades, 52% won, +₹39,280, 9 of 13 days green)
  A  PE on the 3 DRIVERS of the WEAKEST sector - checked at 10:30, 11:00, 12:00   (44 trades, 64% won, +₹17,631, 7 of 11 days green)
  E  CE at 09:45 on a share that fell 2%+ yesterday WITH its theme (355b)   (88 trades, 53% won, +₹97,000 with the card rule, 6 of 10 days green)
One big day carried B and the market was rising: promising, not proven. So GIR only SHOWS them and keeps score:
  · tick()   called by seclive.py every pass: at each check time (a 4-minute window - a missed time is NOT made up later) the candidates are written
             to data/seccand.json: time, kind, share, CE/PE, the price, the sector and why. A share once a day per kind.
  · score()  after 15:40: every candidate priced in the real at-the-money option (Kite minute prices): stop 2.5% on the share, out after 2 hours,
             the rest at 15:10 - 1 lot, before charges. The day goes into data/seccand_log.json (the running record the page shows).
Reads only. Orders nothing, sends nothing.      python3 seccand.py score [YYYY-MM-DD]     python3 seccand.py show"""
import os, sys, json, time, threading, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "seccand.json")
LOG = os.path.join(D, "data", "seccand_log.json")
LVF = os.path.join(D, "data", "seccand_lv.json")
TRIG = (("09:45", "E"), ("10:00", "B"), ("10:30", "AB"), ("11:00", "A"), ("12:00", "A"))
# patch 355b: E = BOUNCE - a share that fell 2%+ yesterday WITH its theme (the theme -1%+; the share not far worse than the theme): CE at 09:45.
#   sectoropt.py, 14 days, real option: 88 trades, 53% won, +₹97,000 with the CARD rule (stop 2.5%, half +1.5%, rest 15:10) - scored that way.
RULE = {"A": (0.025, 0.035, 120), "B": (0.025, 0.035, 120), "E": (0.025, 0.015, None)}
WINDOW_MIN = 4
_lv = {"day": None, "lv": {}, "busy": False}


def _load(path, default):
    try:
        return json.load(open(path))
    except Exception:
        return default


def _save(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path + ".tmp", "w"), ensure_ascii=False, separators=(",", ":")); os.replace(path + ".tmp", path)


def state(day):
    s = _load(OUT, {})
    return s if s.get("day") == day else {"day": day, "done": {}, "cands": [], "scored": False}


def levels(kite, FO, day):
    """{sym: [the highest high, the lowest low] of the 20 trading days before today} - Kite's day candles, once a day, kept on disk"""
    j = _load(LVF, {})
    if j.get("day") == day and len(j.get("lv") or {}) > 50:
        return j["lv"]
    import getdata
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    d0 = dt.date.fromisoformat(day); frm = dt.datetime.combine(d0 - dt.timedelta(days=45), dt.time(9, 15)); to = dt.datetime.combine(d0 - dt.timedelta(days=1), dt.time(15, 30))
    lv = {}
    for s in sorted(FO):
        if s not in tok:
            continue
        try:
            rows = [r for r in kite.historical_data(tok[s], frm, to, "day") if r["date"].date() < d0][-20:]; time.sleep(0.36)
            if len(rows) >= 10:
                lv[s] = [max(float(r["high"]) for r in rows), min(float(r["low"]) for r in rows), float(rows[-1]["close"]), float(rows[-2]["close"])]   # + the last two closes (E)
        except Exception as ex:
            print("seccand levels %s: %s" % (s, str(ex)[:60]), flush=True)
    if len(lv) > 50:
        _save({"day": day, "lv": lv}, LVF)
    return lv


def _levels_bg(kite, FO, day):
    try:
        _lv["lv"] = levels(kite, FO, day); _lv["day"] = day
        print("seccand: 20-day levels for %d F&O shares" % len(_lv["lv"]), flush=True)
    except Exception as ex:
        print("seccand levels: %s" % str(ex)[:120], flush=True)
    _lv["busy"] = False


def themes():
    try:
        import themestudy
        return themestudy.THEMES
    except Exception:
        return {}


def find_bounce(Q, FO, LV):
    """E: [(kind, sym, +1, price, theme, theme's fall yesterday, why)]"""
    out = []
    for t, (fo, also, why) in themes().items():
        y = {s: LV[s][2] / LV[s][3] - 1 for s in (fo + " " + also).split() if s in LV and len(LV[s]) >= 4 and LV[s][3]}
        if len(y) < 2:
            continue
        yth = sum(y.values()) / len(y)
        if yth > -0.01:
            continue
        for s in fo.split():
            if s in y and s in FO and s in Q and y[s] <= -0.02 and y[s] >= 2.0 * yth - 0.01:
                out.append(("E", s, 1, Q[s][0], t, yth, "fell %.1f%% yesterday with its theme (%s %.1f%%) - a wave, not its own news: the next-morning bounce" % (y[s] * 100, t, yth * 100)))
    return out


def find(kinds, SEC, W, Q, FO, LV, vwap):
    """the candidates now: [(kind, sym, dir, price, sector, sector %, why)] - the same rules as sectoropt.py"""
    G = {}
    for s, sec in SEC.items():
        if s in Q and (W.get(s) or not W):
            lp, pc = Q[s]; G.setdefault(sec, []).append((s, lp / pc - 1, W.get(s) or 1.0, lp))
    sc = {}
    for sec, R in G.items():
        if len(R) >= 5:
            w = sum(r[2] for r in R)
            sc[sec] = (sum(r[1] * r[2] for r in R) / w, sum(1 for r in R if r[1] > 0) / len(R), sum(1 for r in R if r[1] < 0) / len(R), w)
    if len(sc) < 8:
        return []
    at = sorted(sc, key=lambda k: -sc[k][0]); out = []
    if "A" in kinds:
        sec = at[-1]; mv = sc[sec][0]
        if mv < 0:
            for s, c, wt, lp in sorted([r for r in G[sec] if r[0] in FO and r[1] < 0], key=lambda r: r[1] * r[2])[:3]:
                out.append(("A", s, -1, lp, sec, mv, "a driver of the weakest sector (%s %+.2f%%) - the share %+.1f%%, %d%% of the sector's move" % (
                    sec, mv * 100, c * 100, round(100 * c * wt / sc[sec][3] / mv) if mv else 0)))
    if "B" in kinds:
        for rk in (1, 2, 3):
            for sec, dr in ((at[rk - 1], 1), (at[-rk], -1)):
                mv = sc[sec][0]; br = sc[sec][1] if dr > 0 else sc[sec][2]
                if mv * dr <= 0 or br < 0.7:
                    continue
                for s, c, wt, lp in G[sec]:
                    lv, vw = LV.get(s), vwap.get(s)
                    if s in FO and lv and vw and ((lp > lv[0]) if dr > 0 else (lp < lv[1])) and (lp - vw) * dr > 0:
                        out.append(("B", s, dr, lp, sec, mv, "past its 20-day %s ₹%s with its sector (%s %+.2f%%, no.%d %s, %d%% of its shares that way) · %s VWAP" % (
                            "high" if dr > 0 else "low", "{:,.2f}".format(lv[0] if dr > 0 else lv[1]), sec, mv * 100, rk, "best" if dr > 0 else "worst", round(br * 100), "above" if dr > 0 else "below")))
    return out


def tick(n, SEC, W, Q, FO, kite):
    """seclive.py calls this every pass in market hours. Never raises."""
    try:
        day = str(n.date()); hm = n.strftime("%H:%M")
        if _lv["day"] != day and not _lv["busy"] and hm >= "09:18":
            also = {s for fo, al, _ in themes().values() for s in al.split()}
            _lv["busy"] = True; threading.Thread(target=_levels_bg, args=(kite, set(FO) | also, day), daemon=True).start()
        st = state(day); changed = False
        for t, kinds in TRIG:
            if t in st["done"] or hm < t:
                continue
            late = (n.hour * 60 + n.minute) - (int(t[:2]) * 60 + int(t[3:]))
            if late > WINDOW_MIN:
                st["done"][t] = "missed (GIR was not watching at %s)" % t; changed = True; continue
            if ("B" in kinds or "E" in kinds) and _lv["day"] != day:
                if late < WINDOW_MIN:
                    continue                                                 # the 20-day levels are still being fetched - try again on the next pass
                kinds = kinds.replace("B", "").replace("E", "")
            vwap = {}
            if "B" in kinds:
                import getdata
                fo = sorted(s for s in FO if s in Q)
                for i in range(0, len(fo), 450):
                    q = getdata.call(kite.quote, ["NSE:" + s for s in fo[i:i + 450]]) or {}
                    for k, v in q.items():
                        if v.get("average_price"):
                            vwap[k.split(":", 1)[1]] = float(v["average_price"])
            have = {(c["kind"], c["s"]) for c in st["cands"]}; new = 0
            LV_ = _lv["lv"] if _lv["day"] == day else {}
            for kind, s, dr, lp, sec, mv, why in find(kinds, SEC, W, Q, FO, LV_, vwap) + (find_bounce(Q, FO, LV_) if "E" in kinds else []):
                if (kind, s) not in have:
                    have.add((kind, s)); new += 1
                    st["cands"].append({"t": t, "kind": kind, "s": s, "dir": dr, "px": round(lp, 2), "sec": sec, "secchg": round(mv * 100, 2), "why": why})
            st["done"][t] = "%d new" % new; changed = True
            print("seccand %s: %d new candidates (%s)" % (t, new, kinds or "no levels yet"), flush=True)
        if changed:
            st["at"] = n.strftime("%H:%M:%S"); _save(st, OUT)
    except Exception as ex:
        print("seccand tick: %s" % str(ex)[:160], flush=True)


def score(day=None):
    """every candidate of the day in the real option: stop 2.5% on the share, out after 2 hours, the rest at 15:10. -> the day's line in the log"""
    import optreal as OR
    day = day or str(dt.datetime.now(IST).date())
    st = _load(OUT, {})
    if st.get("day") != day or not st.get("cands"):
        return None
    K = OR.Kite(day); tot = {"A": [0, 0, 0.0], "B": [0, 0, 0.0], "E": [0, 0, 0.0]}
    for c in st["cands"]:
        try:
            if c["s"] not in K.eq:
                continue
            Sm = K.candles(K.eq[c["s"]]); tm = int(c["t"][:2]) * 60 + int(c["t"][3:]) - 555
            m0 = next((m for m in sorted(Sm) if m >= tm), None)
            if m0 is None:
                continue
            P0 = Sm[m0][3]; k = K.contract(c["s"], c["dir"], P0)
            if not k:
                continue
            O = K.candles(k[1]); p0 = OR.at(O, m0)
            if not p0:
                continue
            x = {"S": sorted((a,) + v for a, v in Sm.items()), "O": OR.ff(O), "m0": m0, "P0": P0, "dir": c["dir"], "lot": k[2], "p0": p0}
            r = OR.money(x, *RULE.get(c["kind"], RULE["A"]))
            if r:
                c["opt"] = {"ts": k[0], "p0": round(p0, 2), "pe": round(r[3], 2), "rs": round(r[0]), "how": r[1], "out": OR.C.hm(r[2]), "lot": k[2]}
                a = tot[c["kind"]]; a[0] += 1; a[1] += r[0] > 0; a[2] += r[0]
        except Exception as ex:
            print("seccand score %s: %s" % (c.get("s"), str(ex)[:80]), flush=True)
    st["scored"] = True; _save(st, OUT)
    lg = _load(LOG, {"days": {}}); lg["days"][day] = {k: [v[0], v[1], round(v[2])] for k, v in tot.items()}; _save(lg, LOG)
    return tot


def after_close(n):
    """seclive.py calls this after the close: score once a day, from 15:40. Never raises."""
    try:
        day = str(n.date()); st = _load(OUT, {})
        if n.strftime("%H:%M") >= "15:40" and st.get("day") == day and st.get("cands") and not st.get("scored"):
            t = score(day); print("seccand scored %s: %s" % (day, t), flush=True)
    except Exception as ex:
        print("seccand after_close: %s" % str(ex)[:160], flush=True)


def view():
    """what the page shows: today's candidates + the running record"""
    st = _load(OUT, {}); lg = _load(LOG, {"days": {}})
    rec = {"A": [0, 0, 0, 0, 0], "B": [0, 0, 0, 0, 0], "E": [0, 0, 0, 0, 0]}  # trades, won, ₹, days, green days
    for d, v in sorted(lg.get("days", {}).items()):
        for k in "ABE":
            a = v.get(k) or [0, 0, 0]
            if a[0]:
                r = rec[k]; r[0] += a[0]; r[1] += a[1]; r[2] += a[2]; r[3] += 1; r[4] += a[2] > 0
    return {"day": st.get("day"), "at": st.get("at"), "done": st.get("done") or {}, "cands": st.get("cands") or [], "scored": bool(st.get("scored")), "record": rec,
            "days": len(lg.get("days", {})), "t": time.time()}


if __name__ == "__main__":
    if sys.argv[1:2] == ["score"]:
        print(score(sys.argv[2] if sys.argv[2:] else None))
    else:
        v = view(); print("candidates %s · checked %s · record %s" % (v["day"], v["done"], v["record"]))
        for c in v["cands"]:
            o = c.get("opt")
            print("  %s %s %-11s %s at ₹%s · %s%s" % (c["t"], c["kind"], c["s"], "CE" if c["dir"] > 0 else "PE", c["px"], c["why"][:90], (" · option ₹%s → ₹%s = ₹%s (%s %s)" % (o["p0"], o["pe"], o["rs"], o["how"], o["out"])) if o else ""))
PY_SC
cat > $W/home_add.html <<'ADD_355'
<style>/* patch 355 + 355b: 🧪 the sector CANDIDATES - a paper test (no sound, no BUY card) - under the 👀 box in TRADE NOW */
#gxcd{margin:0 0 10px;border:1px solid #24405c;border-radius:8px;background:#0b1522;font:12.5px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3}
#gxcd .h{padding:7px 10px;border-bottom:1px solid #1b3048;font:800 12px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#8fc3ff}
#gxcd .h small{display:block;font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf;margin-top:2px}
#gxcd .r{display:grid;grid-template-columns:40px minmax(0,1fr) auto;gap:6px;align-items:center;padding:6px 10px;border-bottom:1px solid #14243a;cursor:pointer}
#gxcd .r:last-child{border-bottom:0}#gxcd .r:hover{background:#0f1d30}
#gxcd .t{font:12px ui-monospace,Menlo,monospace;color:#a3aebf}#gxcd .s{font:700 12.5px ui-monospace,Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#gxcd .k{font:700 10px ui-monospace,Menlo,monospace;padding:1px 5px;border-radius:3px;background:#1b2a3a;color:#8fc3ff;margin-right:4px}
#gxcd .st{font:600 11px ui-monospace,Menlo,monospace;white-space:nowrap;text-align:right}
#gxcd .up{color:#26c281}#gxcd .dn{color:#f0544f}#gxcd .dim{color:#a3aebf}
#gxcd .none,#gxcd .rec{padding:7px 10px;color:#a3aebf;font-size:11.5px}#gxcd .rec{border-top:1px solid #14243a}#gxcd .rec b{color:#e6edf3}
</style>
<script>/* patch 355 (Rama, 16 Nov: "we have to find a real edge"): the two sector picks that made money in the real option on 14 days (sectoropt.py) -
   B: an F&O share past its 20-day high / low with its sector pushing, 10:00 / 10:30 · A: PE on the weakest sector's drivers, 10:30 / 11:00 / 12:00 -
   shown LIVE as candidates. A paper test: no sound, no BUY card. Each evening GIR prices them in the real option with the 2-hour rule and adds
   the day to the record shown at the bottom. data/seccand.json through dashserve /seccand, read every 10 s. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  const rs=v=>(v<0?"−":"+")+"₹"+Math.abs(Math.round(v)).toLocaleString("en-IN");
  let V=null;
  function draw(){ const host=document.getElementById("q-act"); if(!host) return; let el=document.getElementById("gxcd");
    if(!el){ el=document.createElement("div"); el.id="gxcd"; const hu=document.getElementById("gxhu"), h3=host.querySelector("h3"); if(hu) hu.after(el); else if(h3) h3.after(el); else host.prepend(el); }
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10), nowm=(()=>{ const n=new Date(Date.now()+19800000); return n.getUTCHours()*60+n.getUTCMinutes(); })();
    const C=V&&V.day===today?(V.cands||[]).slice().sort((a,b)=>String(b.t).localeCompare(String(a.t))):[];
    const px={}; ((typeof TAPE!=="undefined"&&TAPE)||[]).forEach(r=>{ if(r.px) px[r.s]=r.px; });
    const row=c=>{ const tm=(+c.t.slice(0,2))*60+(+c.t.slice(3)), left=(c.kind==="E"?(15*60+10-tm):120)-(nowm-tm), p=px[c.s], mv=p?(p/c.px-1)*c.dir*100:null, o=c.opt;
      const st=o?`<span class="${o.rs>=0?"up":"dn"}">${rs(o.rs)}</span> <span class="dim">option ₹${o.p0}→₹${o.pe}</span>`
        :(mv==null?'<span class="dim">—</span>':`<span class="${mv>=0?"up":"dn"}">${mv>=0?"+":""}${mv.toFixed(1)}%</span> <span class="dim">${left>0&&nowm<=915?Math.floor(left/60)+"h"+String(left%60).padStart(2,"0")+" left":(c.kind==="E"?"15:10 over":"2h over")}</span>`);
      return `<div class="r" title="${E(c.why)} · at ₹${E(c.px)}" onclick="try{mkOpen('${E(c.s).replace(/'/g,"")}')}catch(e){}"><span class="t">${E(c.t)}</span><span class="s"><span class="k">${({A:"WEAK",B:"BREAK",E:"BOUNCE"})[c.kind]||c.kind}</span>${E(c.s)} <span class="${c.dir>0?"up":"dn"}">${c.dir>0?"▲ CE":"▼ PE"}</span></span><span class="st">${st}</span></div>`; };
    const R=Object.assign({A:[0,0,0,0,0],B:[0,0,0,0,0],E:[0,0,0,0,0]},(V&&V.record)||{});
    const rec=k=>R[k]&&R[k][0]?`${R[k][0]} trades · ${R[k][1]} won · <b class="${R[k][2]>=0?"up":"dn"}">${rs(R[k][2])}</b> · ${R[k][4]} of ${R[k][3]} days green`:"no day scored yet";
    const done=(V&&V.day===today&&V.done)||{};
    el.innerHTML=`<div class="h">🧪 CANDIDATES · PAPER TEST<small>not a trade alert - no sound · checked at 09:45, 10:00, 10:30, 11:00, 12:00 · scored each evening in the real option</small></div>`+
      (C.length?C.map(row).join(""):`<div class="none">${Object.keys(done).length?"checked "+Object.keys(done).sort().join(", ")+" - none so far":"none yet today - the first check is at 09:45"}</div>`)+
      `<div class="rec">live record · BOUNCE (fell 2%+ yesterday with its theme - CE at 09:45, card rule): ${rec("E")}<br>BREAK (past its 20-day level with its sector, 2-hour rule): ${rec("B")}<br>WEAK (PE on the weakest sector's drivers, 2-hour rule): ${rec("A")}<br><span class="dim">the 14-day test before going live: BOUNCE 88 trades, 53% won, +₹97,000 · BREAK 94, 52%, +₹39,280 · WEAK 44, 64%, +₹17,631</span></div>`; }
  async function pull(){ try{ const r=await fetch("seccand?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} draw(); }
  setInterval(()=>{ if(!document.hidden) pull(); },10000); setInterval(()=>{ if(!document.hidden&&V) draw(); },3000); setTimeout(pull,1500); })();
</script>
ADD_355
python3 -m py_compile $W/seccand.py || { echo "❌ did not compile - nothing changed"; exit 1; }
cp $W/seccand.py $D/seccand.py || back
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); add = open(sys.argv[2], encoding="utf-8").read().strip()
a = t.find("<style>/* patch 355"); m = t.find("/* patch 355 (Rama", a); b = t.find("</script>", m)
if a < 0 or m < 0 or b < 0 or t.count("/* patch 355 (Rama") != 1:
    print("❌ home.html: the patch-355 block not found (%d %d %d)" % (a, m, b)); sys.exit(1)
open(p, "w", encoding="utf-8").write(t[:a] + add + t[b + len("</script>"):]); print("  home.html: 🧪 BOUNCE in the CANDIDATES box")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && python3 -c "import seccand; print('  seccand: checks at', ', '.join(t for t, k in seccand.TRIG), '·', len(seccand.themes()), 'themes · record', seccand.view()['record'])" || back
systemctl restart gir-seclive; systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-seclive: $(systemctl is-active gir-seclive)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-seclive)" = "active" ] || back
echo "✅ patch 355b done - refresh GIR (Ctrl+Shift+R). Tomorrow: BOUNCE at 09:45, BREAK at 10:00 / 10:30, WEAK at 10:30 / 11:00 / 12:00 - a paper test, no sound."
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/seccand.py.bak355b $D/seccand.py; systemctl restart gir-seclive gir-dash"
