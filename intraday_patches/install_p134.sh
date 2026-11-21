#!/bin/bash
# PATCH 134 - THE NIFTY / BANKNIFTY OPTIONS DESK (on top of patch 133b).
#   Every minute in market hours (its own thread - the engine never waits): both indices' option chains, nearest expiry, from Kite.
#   CEILING / FLOOR (the biggest call / put walls), PCR, MAX PAIN, ATM IV, the straddle, puts vs calls written since the close,
#   the chain with each strike's OI % vs the last close (NSE's end-of-day file, patch 132), and a DECISION from 4 checks
#   (writers · PCR trend · the walls moving · the price vs its close and day average): BUY CE / BUY PE / WAIT, with the strike,
#   premium, stop (-30%) and the wall it runs to.
#   - MARKET screen: NIFTY · BANKNIFTY OPTIONS (a tab per index)
#   - Telegram (🔭 OI topic): 🔭 NIFTY OPTIONS ▲ BUY CE ... when the decision turns (rings, 30-min cooldown) and when it is off;
#     🧱 WALL FLIP ... when the floor / ceiling moves (held 2 readings)
#   - whymove: a story on the results is kept, only the filing's own echo is dropped (Divi's counted twice); no why-line on index lines
#   idxdesk.py (new), whymove.py (replaced) · engine2.py, dashserve.py, home.html, alertword.py (exact anchors).
#   Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g134; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p134.sh now"; exit 1; fi
grep -q "patch 133b" $D/whymove.py 2>/dev/null || { echo "patch 133b is not installed yet - paste patch 133b first"; exit 1; }
[ -f $D/idxdesk.py ] && { echo "patch 134 is already installed"; exit 1; }
F="engine2.py dashserve.py home.html alertword.py whymove.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/idxdesk.py $D/p134test.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p134_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p134_patch.py - PATCH 134: THE NIFTY / BANKNIFTY OPTIONS DESK (idxdesk.py): the engine kicks a sweep every minute (its own
thread), the page shows it on the MARKET screen, Telegram gets the decision turning and the walls moving.
Usage: python3 p134_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''        if nowt - tick.get("sidx", 0.0) >= 15:               # patch 120: the official NSE sector indices''',
         '''        if nowt - tick.get("idxd", 0.0) >= 60:               # patch 134: the NIFTY / BANKNIFTY options desk (its own thread)
            tick["idxd"] = nowt
            try:
                import idxdesk
                idxdesk.kick(kite, tg_fo)
            except Exception as ex:
                if ("IDXD", "fail") not in _said:
                    _said.add(("IDXD", "fail"))
                    log("index desk failed:", ex)
        if nowt - tick.get("sidx", 0.0) >= 15:               # patch 120: the official NSE sector indices'''),
    ],
    "alertword.py": [
        ('''    if KNOW.match(H2):
        return "know"''', '''    if re.match(r"🔭 (?:NIFTY|BANKNIFTY) OPTIONS", H2):           # patch 134: the index desk's BUY rings (a new rule - not yet measured)
        return "move" if re.search(r"[▲▼] BUY", H2) else "read"
    if KNOW.match(H2):
        return "know"'''),
    ],
    "dashserve.py": [
        ('''"chain": market_chain()}''', '''"chain": market_chain(), "idxd": _idxd()}'''),
        ('''def market():''', '''def _idxd():
    """patch 134: the NIFTY / BANKNIFTY options desk (data/idxdesk.json - the engine writes it every minute)"""
    try:
        return json.load(open(os.path.join(BASE, "data", "idxdesk.json")))
    except Exception:
        return {}


def market():'''),
    ],
    "home.html": [
        ('''    <div class="q" id="q-hea">''', '''    <div class="q" id="q-idx"><h3>NIFTY · BANKNIFTY OPTIONS <span>nearest expiry · every minute</span></h3><div class="bd" id="mk-idx"></div></div>
    <div class="q" id="q-hea">'''),
        ('''grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus mon nws"}''',
         '''grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus idx nws"}'''),
        ('''#q-nws{grid-area:nws}}''', '''#q-nws{grid-area:nws}#q-idx{grid-area:idx}}'''),
        ('''#mk .q .bd{flex:1;min-height:0;overflow:auto;position:relative;scrollbar-width:thin}''',
         '''#mk .q .bd{flex:1;min-height:0;overflow:auto;position:relative;scrollbar-width:thin}
/* patch 134: the NIFTY / BANKNIFTY options desk */
#mk-idx .ixt{display:flex;gap:6px;align-items:center;padding:3px 6px;flex-wrap:wrap}#mk-idx .ixt a{padding:0 6px;border:1px solid var(--line2);cursor:pointer;color:var(--dim)}
#mk-idx .ixt a.on{background:var(--amber);color:#000;border-color:var(--amber)}#mk-idx .ixd{margin:2px 6px;padding:4px 6px;border-left:4px solid var(--dim);background:#06080b;line-height:1.4}
#mk-idx .ixd.up{border-left-color:var(--up)}#mk-idx .ixd.up b{color:var(--up)}#mk-idx .ixd.dn{border-left-color:var(--dn)}#mk-idx .ixd.dn b{color:var(--dn)}#mk-idx .ixd b{margin-right:6px}
#mk-idx .ixw{padding:1px 8px;color:var(--dim);font-size:10.5px;line-height:1.35}#mk-idx .ixs{display:flex;flex-wrap:wrap;gap:2px 10px;padding:3px 8px;font-size:10.5px;color:var(--dim)}#mk-idx .ixs b{color:var(--hi)}
#mk-idx table{width:100%;border-collapse:collapse;font-size:10.5px}#mk-idx td{padding:1px 4px;text-align:right;position:relative}#mk-idx td.k{text-align:center;color:var(--hi);font-weight:700}
#mk-idx tr.atm td{background:rgba(255,176,0,.10)}#mk-idx td i{font-style:normal;font-size:9.5px;margin-left:3px}#mk-idx td u{text-decoration:none;font-size:8.5px;color:#000;background:var(--amber);padding:0 2px;margin-left:3px}'''),
        ('''  // SECTORS THROUGH THE DAY''', '''  MKH("mk-idx").innerHTML=idxDeskHTML(M.idxd||{});        // patch 134
  // SECTORS THROUGH THE DAY'''),
        ('''["mk-nws","OI SCENARIOS · NEWS"]]''', '''["mk-nws","OI SCENARIOS · NEWS"],["mk-idx","NIFTY · BANKNIFTY OPTIONS"]]'''),
        ('''function nifTf(t){''', '''/* patch 134: THE NIFTY / BANKNIFTY OPTIONS DESK (the engine's idxdesk.py, every minute) */
let IDXT="NIFTY"; try{ IDXT=localStorage.getItem("gir_idxt")||"NIFTY"; }catch(e){}
function idxSet(n){ IDXT=n; try{ localStorage.setItem("gir_idxt",n); }catch(e){} drawMarket.force=true; drawMarket(); drawMarket.force=false; }
function idxDeskHTML(J){ const tabs=["NIFTY","BANKNIFTY"].map(n=>`<a class="${IDXT===n?"on":""}" onclick="idxSet('${n}')">${n}</a>`).join("");
  const d=J&&J[IDXT]; const today=new Date(Date.now()+19800000).toISOString().slice(0,10);
  if(!d) return `<div class="ixt">${tabs}</div><div class="empty">both option chains are read every minute from 09:15 - nothing read yet</div>`;
  const L=v=>v==null?"—":Math.abs(v)>=1e7?(v/1e7).toFixed(2)+"Cr":(v/1e5).toFixed(1)+"L"; const P=v=>v==null?"":`<i class="${v>0?"pu":v<0?"pd":"dim"}">${v>0?"+":""}${Math.abs(v)>=100?Math.round(v):v}%</i>`;
  const sg=s=>s>0?'<b class="pu">▲</b>':s<0?'<b class="pd">▼</b>':'<b class="dim">·</b>'; const X=d.dec||{}, t=X.trade;
  const when=d.day!==today?`<span class="dim">${esc(d.day.slice(5))} ${esc(d.t)} · the last session</span>`:`<span class="dim">${esc(d.t)}</span>`;
  const mx=Math.max(1,...(d.rows||[]).map(r=>Math.max(r.ce||0,r.pe||0)));
  const tr=(d.rows||[]).slice().sort((a,b)=>b.k-a.k).map(r=>`<tr class="${r.k===d.atm?"atm":""}"><td><span class="pd">${L(r.ce)}</span>${P(r.ce_pc)}</td><td class="dim">${r.ce_p!=null?r.ce_p:"—"}</td><td class="k">${r.k}${r.k===d.ceil?"<u>CEIL</u>":""}${r.k===d.floor?"<u>FLOOR</u>":""}</td><td class="dim">${r.pe_p!=null?r.pe_p:"—"}</td><td><span class="pu">${L(r.pe)}</span>${P(r.pe_pc)}</td></tr>`).join("");
  return `<div class="ixt">${tabs}<b>${inr(d.spot)}</b> <span class="${cls(d.chg)}">${mkPc(d.chg)}</span> <span class="dim">exp ${esc(String(d.exp).slice(5))} · ${d.dte}d · lot ${d.lot||"?"}</span> ${when}</div>
    <div class="ixd ${X.side==="CE"?"up":X.side==="PE"?"dn":""}"><b>DECISION: ${esc(X.word||"—")}</b>${t?`${t.strike} ${t.kind} ₹${t.prem} · stop ₹${t.stop} · target ${IDXT} ${t.target_spot}${t.lot_cost?` · 1 lot ₹${inr(t.lot_cost)}`:""}`:`<span class="dim">${X.bull||0} ▲ · ${X.bear||0} ▼ of 4 · a BUY needs 3 agreeing and none against</span>`}${X.note?`<br><span class="am">⚠ ${esc(X.note)}</span>`:""}</div>
    <div class="ixw">${(X.why||[]).map(w=>`<div>${sg(w[0])} ${esc(w[1])}</div>`).join("")}</div>
    <div class="ixs"><span>PCR <b>${d.pcr??"—"}</b></span><span>MAX PAIN <b>${d.pain??"—"}</b></span><span>FLOOR <b class="pu">${d.floor??"—"}</b></span><span>CEILING <b class="pd">${d.ceil??"—"}</b></span><span>ATM IV <b>${d.iv!=null?d.iv+"%":"—"}</b></span><span>MOVE <b>±${d.straddle??"—"}</b></span><span>OI today: puts <b>${L(d.pe_add)}</b> · calls <b>${L(d.ce_add)}</b></span></div>
    <table><tr class="dim"><td>CE OI · % vs ${esc(d.ref||"")}</td><td>CE ₹</td><td class="k">STRIKE</td><td>PE ₹</td><td>PE OI</td></tr>${tr}</table>`; }
function nifTf(t){'''),
    ],
}


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
cat > $W/idxdesk.py <<'PY_IDX'
#!/usr/bin/env python3
"""idxdesk.py - patch 134: THE NIFTY / BANKNIFTY OPTIONS DESK. Every minute in market hours (its own thread - the engine never
waits) both indices' option chains, nearest expiry, the strikes around the price, from Kite:

  the chain        per strike: CE / PE open interest, the change since the last close (NSE's end-of-day file), the premium
  the walls        CEILING = the strike above the price with the most calls written, FLOOR = below, most puts written
  PCR · MAX PAIN · ATM IV · the straddle (the move the options price in)
  OI today         puts written vs calls written since the close
  DECISION         4 checks, each ▲ / ▼ / · :
                     writers   puts written more than calls (a floor is built: ▲) or the other way (▼)
                     PCR       rising 0.05+ in 30 min (▲) / falling (▼)
                     walls     the floor moved up / the ceiling moved up (▲) - down (▼), since the morning
                     price     above the last close AND its day average (▲) / below both (▼)
                   BUY CE = 3+ ▲ and no ▼ · BUY PE = 3+ ▼ and no ▲ · else WAIT. Before 09:30: WAIT (the open is noise).
                   The trade: the at-the-money strike, its premium, stop = premium -30%, target = the wall it runs to
  Telegram         🔭 NIFTY OPTIONS ▲ BUY CE ... when the decision turns (30-min cooldown) and when it is off again;
                   🧱 WALL FLIP ... when the floor / ceiling moves (held 2 readings)
  page             MARKET screen: NIFTY · BANKNIFTY OPTIONS (data/idxdesk.json)
  python3 idxdesk.py        the last reading"""
import os, re, sys, json, math, time, threading, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "idxdesk.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
INDEX = {"NIFTY": {"spot": "NSE:NIFTY 50", "band": 0.035}, "BANKNIFTY": {"spot": "NSE:NIFTY BANK", "band": 0.045}}
ST = {"ins": None, "ins_day": None, "busy": False, "day": None, "first": {}, "hist": {}, "said": {}, "walls": {}, "dec": {}, "err": ""}
LOCK = threading.Lock()


def log(*a):
    try:
        from engine import log as _l
        _l(*a)
    except Exception:
        print(*a)


# ------------------------------------------------------------------ Black-Scholes (the IV of the at-the-money options)
def _ncdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def _bs(spot, k, days, vol, kind, r=0.065):
    t = max(days, 0.05) / 365.0
    d1 = (math.log(spot / k) + (r + 0.5 * vol * vol) * t) / (vol * math.sqrt(t))
    d2 = d1 - vol * math.sqrt(t)
    if kind == "CE":
        return spot * _ncdf(d1) - k * math.exp(-r * t) * _ncdf(d2)
    return k * math.exp(-r * t) * _ncdf(-d2) - spot * _ncdf(-d1)


def iv(price, spot, k, days, kind):
    if not price or price <= 0 or spot <= 0:
        return None
    lo, hi = 0.01, 3.0
    try:
        if _bs(spot, k, days, lo, kind) > price or _bs(spot, k, days, hi, kind) < price:
            return None
        for _ in range(40):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if _bs(spot, k, days, mid, kind) < price else (lo, mid)
        return (lo + hi) / 2
    except Exception:
        return None


# ------------------------------------------------------------------ Kite
def instruments(kite):
    """{index: {"exps": [date...], "rows": [(tradingsymbol, exp, strike, kind)], "lot": n}} - the nearest two expiries"""
    import getdata
    today = dt.datetime.now(IST).date()
    by = {n: [] for n in INDEX}
    lot = {}
    for i in getdata.call(kite.instruments, "NFO"):
        n = i.get("name")
        if n not in by or i.get("instrument_type") not in ("CE", "PE"):
            continue
        e = i.get("expiry")
        if isinstance(e, dt.datetime):
            e = e.date()
        if isinstance(e, str):
            e = dt.date.fromisoformat(e[:10])
        if not e or e < today:
            continue
        by[n].append((i["tradingsymbol"], e, float(i["strike"]), i["instrument_type"]))
        lot[n] = int(i.get("lot_size") or lot.get(n) or 0)
    out = {}
    for n, rows in by.items():
        exps = sorted(set(r[1] for r in rows))[:2]
        out[n] = {"exps": exps, "rows": [r for r in rows if r[1] in exps], "lot": lot.get(n) or 0}
    return out


def _prev_day(d):
    try:
        import sessions
        x = d
        for _ in range(10):
            x -= dt.timedelta(days=1)
            if sessions.session(x):
                return x
    except Exception:
        pass
    x = d - dt.timedelta(days=1)
    while x.weekday() >= 5:
        x -= dt.timedelta(days=1)
    return x


def _prev_close(name, exp, now):
    try:
        import bhavfull
        return bhavfull.prev_for(name, str(_prev_day(now.date())), str(exp))
    except Exception:
        return {}


# ------------------------------------------------------------------ the read
def compute(name, spot, pc, exp, chain, prev, first, hist, now, lot=0, step=None):
    """chain {(strike, "CE"/"PE"): (oi, ltp)} -> the desk's picture of one index"""
    ks = sorted(set(k for k, _ in chain))
    if not ks or not spot:
        return None
    step = step or (min(b - a for a, b in zip(ks, ks[1:])) if len(ks) > 1 else 50)
    atm = min(ks, key=lambda k: abs(k - spot))
    ref = lambda k, kd: (((prev.get("%g" % k) or {}).get(kd.lower()) or [None])[0]) if prev else None
    rows, ce_add, pe_add, ce_tot, pe_tot, src_prev = [], 0.0, 0.0, 0.0, 0.0, 0
    for k in ks:
        r = {"k": k}
        for kd in ("CE", "PE"):
            oi, ltp = chain.get((k, kd), (None, None))
            r0 = ref(k, kd)
            if r0 is not None:
                src_prev += 1
            else:
                r0 = first.get((k, kd))
            r[kd.lower()] = oi
            r[kd.lower() + "_p"] = ltp
            r[kd.lower() + "_d"] = (oi - r0) if (oi is not None and r0 is not None) else None
            r[kd.lower() + "_pc"] = round((oi / r0 - 1) * 100, 1) if (oi is not None and r0) else None
            if oi:
                if kd == "CE":
                    ce_tot += oi; ce_add += (r["ce_d"] or 0)
                else:
                    pe_tot += oi; pe_add += (r["pe_d"] or 0)
        rows.append(r)
    above = [r for r in rows if r["k"] >= spot and r.get("ce")]
    below = [r for r in rows if r["k"] <= spot and r.get("pe")]
    ceil_ = max(above, key=lambda r: r["ce"])["k"] if above else None
    floor_ = max(below, key=lambda r: r["pe"])["k"] if below else None
    pcr = round(pe_tot / ce_tot, 2) if ce_tot else None
    pain = None
    best = None
    for K in ks:
        v = sum((r.get("ce") or 0) * max(0.0, K - r["k"]) + (r.get("pe") or 0) * max(0.0, r["k"] - K) for r in rows)
        if best is None or v < best:
            best, pain = v, K
    a = next(r for r in rows if r["k"] == atm)
    close_t = dt.datetime.combine(exp, dt.time(15, 30), IST)
    days = max(0.02, (close_t - now).total_seconds() / 86400.0)
    ivs = [x for x in (iv(a.get("ce_p"), spot, atm, days, "CE"), iv(a.get("pe_p"), spot, atm, days, "PE")) if x]
    straddle = round((a.get("ce_p") or 0) + (a.get("pe_p") or 0), 1) if a.get("ce_p") and a.get("pe_p") else None
    d = {"name": name, "t": now.strftime("%H:%M"), "day": str(now.date()), "spot": round(spot, 2), "pc": pc, "chg": round((spot / pc - 1) * 100, 2) if pc else None,
         "exp": str(exp), "dte": (exp - now.date()).days, "lot": lot, "step": step, "atm": atm, "pcr": pcr, "pain": pain, "ceil": ceil_, "floor": floor_,
         "iv": round(sum(ivs) / len(ivs) * 100, 1) if ivs else None, "straddle": straddle, "ce_add": round(ce_add), "pe_add": round(pe_add),
         "ref": "the last close" if src_prev else "the first reading today", "rows": [r for r in rows if abs(r["k"] - atm) <= 7 * step]}
    d["dec"] = decide(d, hist, now)
    return d


def decide(d, hist, now):
    """the 4 checks -> {"word", "side", "why": [(+1/-1/0, text)], "trade"}"""
    H = hist or []
    S = []
    tot = abs(d["pe_add"]) + abs(d["ce_add"])
    r = (d["pe_add"] - d["ce_add"]) / tot if tot else 0
    S.append((1 if r > 0.2 else -1 if r < -0.2 else 0, "writers: puts %s · calls %s since %s" % (_lk(d["pe_add"]), _lk(d["ce_add"]), d["ref"])))
    old = [h for h in H if h["t"] <= (now - dt.timedelta(minutes=30)).strftime("%H:%M")]
    o = old[-1] if old else (H[0] if H else None)
    if o and o.get("pcr") is not None and d["pcr"] is not None:
        dp = d["pcr"] - o["pcr"]
        S.append((1 if dp >= 0.05 else -1 if dp <= -0.05 else 0, "PCR %.2f → %.2f since %s" % (o["pcr"], d["pcr"], o["t"])))
    else:
        S.append((0, "PCR %s (its trend after 30 min)" % d["pcr"]))
    f0 = H[0] if H else None
    w = 0
    txt = []
    if f0 and f0.get("floor") and d["floor"]:
        w += (d["floor"] > f0["floor"]) - (d["floor"] < f0["floor"])
        txt.append("floor %g → %g" % (f0["floor"], d["floor"]) if d["floor"] != f0["floor"] else "floor %g" % d["floor"])
    if f0 and f0.get("ceil") and d["ceil"]:
        w += (d["ceil"] > f0["ceil"]) - (d["ceil"] < f0["ceil"])
        txt.append("ceiling %g → %g" % (f0["ceil"], d["ceil"]) if d["ceil"] != f0["ceil"] else "ceiling %g" % d["ceil"])
    S.append((1 if w > 0 else -1 if w < 0 else 0, "walls: " + (" · ".join(txt) or "floor %s · ceiling %s" % (d["floor"], d["ceil"]))))
    avg = sum(h["spot"] for h in H) / len(H) if H else None
    if d["pc"] and avg:
        up, dn = d["spot"] > d["pc"] and d["spot"] > avg, d["spot"] < d["pc"] and d["spot"] < avg
        S.append((1 if up else -1 if dn else 0, "price %s the last close (%g) and %s its day average (%g)" % (
            "above" if d["spot"] > d["pc"] else "below", d["pc"], "above" if d["spot"] > avg else "below", round(avg, 1))))
    else:
        S.append((0, "price: the day average after the first readings"))
    bull, bear = sum(1 for s, _ in S if s > 0), sum(1 for s, _ in S if s < 0)
    hm = now.strftime("%H:%M")
    side = "CE" if bull >= 3 and not bear else "PE" if bear >= 3 and not bull else None
    if hm < "09:30":
        word, side = "WAIT", None
        S.append((0, "before 09:30 - the first 15 minutes are noise"))
    else:
        word = ("BUY " + side) if side else "WAIT"
    out = {"word": word, "side": side, "bull": bull, "bear": bear, "why": S, "trade": None}
    if side:
        a = next((x for x in d["rows"] if x["k"] == d["atm"]), {})
        p = a.get(side.lower() + "_p")
        tgt = d["ceil"] if side == "CE" and d["ceil"] and d["ceil"] > d["spot"] else d["floor"] if side == "PE" and d["floor"] and d["floor"] < d["spot"] else None
        if not tgt and d["straddle"]:
            tgt = round(d["spot"] + (d["straddle"] / 2 if side == "CE" else -d["straddle"] / 2))
        out["trade"] = {"strike": d["atm"], "kind": side, "prem": p, "stop": round(p * 0.7, 1) if p else None, "target_spot": tgt,
                        "lot_cost": round(p * d["lot"]) if p and d["lot"] else None}
    if d["dte"] == 0:
        out["note"] = "expiry day - premiums melt fast: small size, out by 15:00"
    return out


def _lk(v):
    if v is None:
        return "?"
    a = abs(v)
    s = ("%.2f Cr" % (a / 1e7)) if a >= 1e7 else ("%.1f L" % (a / 1e5)) if a >= 1e5 else ("%d" % a)
    return ("+" if v > 0 else "-" if v < 0 else "") + s


# ------------------------------------------------------------------ the sweep (a thread; the engine only kicks it)
def kick(kite, send=None):
    """called by the engine's loop every minute: one sweep in its own thread unless one is still running"""
    with LOCK:
        if ST["busy"]:
            return False
        ST["busy"] = True
    threading.Thread(target=_run, args=(kite, send), daemon=True).start()
    return True


def _run(kite, send):
    try:
        sweep(kite, send)
    except Exception as ex:
        ST["err"] = str(ex)[:120]
        log("index desk: %s" % ST["err"])
    finally:
        ST["busy"] = False


def sweep(kite, send=None, now=None):
    now = now or dt.datetime.now(IST)
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "first": {}, "hist": {}, "said": {}, "walls": {}, "dec": {}})
        j = load()                                              # the engine restarted in the day: the day's path goes on
        for n in INDEX:
            if (j.get(n) or {}).get("day") == day:
                ST["hist"][n] = list(j[n].get("hist") or [])
                ST["dec"][n] = (j[n].get("dec") or {}).get("word")
    if ST["ins"] is None or ST["ins_day"] != day:
        ST["ins"], ST["ins_day"] = instruments(kite), day
    ins = ST["ins"]
    q = kite.quote([v["spot"] for v in INDEX.values()]) or {}
    spot = {}
    for n, v in INDEX.items():
        e = q.get(v["spot"]) or {}
        if e.get("last_price"):
            spot[n] = (float(e["last_price"]), float((e.get("ohlc") or {}).get("close") or 0) or None)
    keys, meta = [], {}
    for n, (sp, _) in spot.items():
        I = ins.get(n) or {}
        if not I.get("exps"):
            continue
        exp = I["exps"][0]
        for ts, e, k, kd in I["rows"]:
            if e == exp and abs(k / sp - 1) <= INDEX[n]["band"]:
                keys.append("NFO:" + ts)
                meta["NFO:" + ts] = (n, k, kd)
    qq = {}
    for i in range(0, len(keys), 400):
        qq.update(kite.quote(keys[i:i + 400]) or {})
    out = load() if os.path.exists(FILE) else {}
    for n, (sp, pc) in spot.items():
        I = ins.get(n) or {}
        if not I.get("exps"):
            continue
        exp = I["exps"][0]
        chain = {}
        for kk, v in qq.items():
            m = meta.get(kk)
            if m and m[0] == n:
                chain[(m[1], m[2])] = (float(v.get("oi") or 0), float(v.get("last_price") or 0) or None)
        fr = ST["first"].setdefault(n, {})
        for key, (oi, _) in chain.items():
            fr.setdefault(key, oi)
        H = ST["hist"].setdefault(n, [])
        d = compute(n, sp, pc, exp, chain, _prev_close(n, exp, now), fr, H, now, I.get("lot") or 0)
        if not d:
            continue
        H.append({"t": d["t"], "spot": d["spot"], "pcr": d["pcr"], "floor": d["floor"], "ceil": d["ceil"]})
        del H[:-400]
        d["hist"] = H[-80:]
        out[n] = d
        if send:
            for line in alerts(n, d, now):
                try:
                    send(line)
                except Exception as ex:
                    log("index desk telegram: %s" % str(ex)[:80])
    out["at"] = time.time()
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    json.dump(out, open(FILE + ".tmp", "w"), separators=(",", ":"))
    os.replace(FILE + ".tmp", FILE)
    return out


def alerts(n, d, now):
    """the lines to send now: the decision turning (30-min cooldown per index and side) and off again; a wall moving"""
    out = []
    S = ST["said"]
    dec = d["dec"]
    prev = ST["dec"].get(n)
    ST["dec"][n] = dec["word"]
    arrow = lambda s: "▲" if s == "CE" else "▼"
    if dec["side"] and prev != dec["word"] and time.time() - S.get((n, dec["word"]), 0) >= 1800:
        S[(n, dec["word"])] = time.time()
        t = dec["trade"] or {}
        why = " · ".join(("▲ " if s > 0 else "▼ " if s < 0 else "· ") + x for s, x in dec["why"])
        out.append("🔭 %s OPTIONS %s %s %g %s · ₹%s · %s\nstop ₹%s (premium -30%%) · target: %s %s (%s)\n%d of 4 agree: %s\nlot %s = ₹%s · expiry %s (%d day%s)%s" % (
            n, arrow(dec["side"]), dec["word"], t.get("strike") or 0, dec["side"], t.get("prem"), d["t"], t.get("stop"), n, t.get("target_spot"),
            "the ceiling" if dec["side"] == "CE" else "the floor", dec["bull"] if dec["side"] == "CE" else dec["bear"], why, d["lot"],
            "{:,}".format(t["lot_cost"]) if t.get("lot_cost") else "?", dt.date.fromisoformat(d["exp"]).strftime("%a %d %b"), d["dte"], "" if d["dte"] == 1 else "s",
            ("\n⚠ " + dec["note"]) if dec.get("note") else ""))
    elif prev and prev.startswith("BUY") and dec["word"] != prev:
        out.append("🔭 %s OPTIONS · %s is off · %s\nnow %s (%d ▲ · %d ▼) - book or tighten the stop" % (n, prev, d["t"], dec["word"], dec["bull"], dec["bear"]))
    W = ST["walls"].setdefault(n, {})
    for kind, word in (("floor", "floor"), ("ceil", "ceiling")):
        cur = d.get(kind)
        st = W.get(kind)
        if st is None:
            W[kind] = {"k": cur, "cand": None}
            continue
        if cur == st["k"]:
            st["cand"] = None
            continue
        if st["cand"] != cur:
            st["cand"] = cur                                    # held 2 readings before it is said
            continue
        old = st["k"]
        st.update({"k": cur, "cand": None})
        if old and cur and time.time() - S.get((n, kind), 0) >= 1200:
            S[(n, kind)] = time.time()
            up = cur > old
            r = next((x for x in d["rows"] if x["k"] == cur), {})
            oi = r.get("pe" if kind == "floor" else "ce")
            out.append("🧱 WALL FLIP %s %s · %s %g → %g · %s\n%s writers moved %s: %s now %g (%s OI %s) · %s %s" % (
                "▲" if up else "▼", n, word, old, cur, d["t"], "put" if kind == "floor" else "call", "up" if up else "down",
                "support" if kind == "floor" else "resistance", cur, "PE" if kind == "floor" else "CE", _lk(oi).lstrip("+"), n, "{:,}".format(round(d["spot"], 1))))
    return out


def load():
    try:
        return json.load(open(FILE))
    except Exception:
        return {}


if __name__ == "__main__":
    j = load()
    print("index desk: %s" % (time.strftime("%d %b %H:%M", time.localtime(j["at"])) if j.get("at") else "no reading yet"))
    for n in INDEX:
        d = j.get(n)
        if not d:
            print("  %s: -" % n); continue
        print("  %s %s %+.2f%% · exp %s (%dd) · PCR %s · max pain %s · floor %s · ceiling %s · IV %s · straddle %s" % (
            n, d["spot"], d.get("chg") or 0, d["exp"], d["dte"], d["pcr"], d["pain"], d["floor"], d["ceil"], d["iv"], d["straddle"]))
        print("    DECISION %s · %s" % (d["dec"]["word"], " · ".join(("▲ " if s > 0 else "▼ " if s < 0 else "· ") + x for s, x in d["dec"]["why"])))
PY_IDX
cat > $W/whymove.py <<'PY_WHY'
#!/usr/bin/env python3
"""whymove.py - patch 133 (+133b, +134: a news story on the results already read is not counted twice; no line on index alerts): WHY IS IT MOVING. When an F&O share moves, the reasons GIR already holds, ranked, in one line:

  results     the company's results filed in the last 3 days (GIR's read: BEAT / MISS / IN LINE, the numbers)
  filings     an order, a regulator's action, a board decision, a rating (NSE, last 2 days)
  news        the news GIR checked and sent (the reader's sentence), last 36 h
  brokers     a broker's call in the news (target, upgrade, downgrade ...), last 3 days
  sector      its NSE sector moving the same way ("moving with the sector") - or not ("on its own")
  market      NIFTY moving the same way; the day's market headline when nothing company-level is found
  money       the futures build-up (₹ crore of fresh money), calls / puts being bought
  calendar    results due in the next 2 days (positioning), a company event today
Nothing company-level found is said too: "no company news found - the market / the money only".
Local reads only (no website is asked), cached a minute per share - safe inside the engine's alert path.

  share card      WHY IT IS MOVING (the line + every reason)
  Telegram        a "🔎 why:" line under 🚀 RUNNING · ⚡ SPEED / FIRST MOVE · 🌅 GAP · 📈 MOVER · 🧩 OI alerts
  python3 whymove.py VOLTAS        the reasons for one share now"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {}
_F = {"state": (0.0, {}), "sec": (0.0, {}), "q": (0.0, {})}
BROKER_RX = re.compile(r"\btarget\b|upgrade|downgrade|\bbuy\b.*\b(?:call|rating)\b|\bsell\b.*\b(?:call|rating)\b|overweight|underweight|outperform|underperform|"
                       r"initiat\w* coverage|reiterat|price target|brokerage|motilal|jefferies|morgan stanley|goldman|nomura|clsa|jp ?morgan|citi\b|macquarie|"
                       r"bernstein|\bubs\b|hsbc|kotak institutional|nuvama|emkay|icici securities|axis capital|antique|investec|bofa|elara", re.I)
ACTION_RX = re.compile(r"target|upgrade|downgrade|rating|overweight|underweight|outperform|underperform|initiat|reiterat|\bbuy\b|\bsell\b|\badd\b|\breduce\b|\bneutral\b", re.I)
ROUNDUP_RX = re.compile(r"\blive\b|stocks? to (?:buy|watch|sell)|top \d+|\bpicks\b|stocks in focus|stocks? in news|buzzing|market (?:live|today)|these \d+", re.I)
_N = {"t": 0.0, "v": {}}


def _name(sym):
    if time.time() - _N["t"] > 3600:
        try:
            import newsroom
            _N["v"] = {s: n for s, n, l in newsroom.fo_names()}
        except Exception:
            pass
        _N["t"] = time.time()
    return _N["v"].get(sym) or ""


def _names_it(h, sym, name):
    """the headline names this company: its symbol, or the first word of its name (Ambuja, Voltas, Divi's ...)"""
    w = [x for x in re.findall(r"[A-Za-z][A-Za-z'&\-]+", name or "") if x.lower() not in ("the", "ltd", "limited", "india", "of", "and")]
    keys = {sym.lower()} | ({w[0].lower().replace("'", "")} if w and len(w[0]) >= 3 else set())
    hl = re.sub(r"'", "", h.lower())
    return any(re.search(r"\b%s\b" % re.escape(k), hl) for k in keys)


MOVE_K = ("🚀", "⚡", "🌅", "📈", "🧩", "🔭", "🔎")


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def _state():
    t, v = _F["state"]
    if time.time() - t < 30:
        return v
    try:
        v = json.load(open(os.path.join(BASE, "dash_state.json")))
    except Exception:
        v = {}
    _F["state"] = (time.time(), v)
    return v


def _quotes():
    t, v = _F["q"]
    if time.time() - t < 10:
        return v
    try:
        v = (json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}).get("q") or {}
    except Exception:
        v = {}
    _F["q"] = (time.time(), v)
    return v


def _sectors(universe):
    t, v = _F["sec"]
    if time.time() - t < 600 and v:
        return v
    try:
        import nsesec
        v = nsesec.page_map(set(universe)) or {}
    except Exception:
        v = {}
    _F["sec"] = (time.time(), v)
    return v


def _move(sym):
    q = _quotes().get(sym) or []
    f = next((x for x in _state().get("fo_paths") or [] if x.get("s") == sym), {}) or {}
    px = (q[0] if q else None) or f.get("px")
    chg = (q[1] if len(q) > 1 else None)
    if chg is None:
        chg = f.get("chg")
    return px, chg, f


def explain(sym, now=None):
    """-> {"s", "px", "chg", "dir", "reasons": [{"k", "t", "w", "side"}], "line", "stock": bool (a company-level reason found)}"""
    sym = (sym or "").upper()
    c = _C.get(sym)
    if c and time.time() - c[0] < 60 and now is None:
        return c[1]
    now = now or dt.datetime.now(IST)
    px, chg, f = _move(sym)
    d = 1 if (chg or 0) > 0 else -1 if (chg or 0) < 0 else 0
    R = []
    add = lambda k, t, w, side=0: R.append({"k": k, "t": t, "w": w, "side": side})
    # results
    try:
        import exchange
        rr = exchange.results_read(sym, 72)
        if rr:
            big = bool((rr.get("read") or {}).get("big"))
            add("results", "results %s%s (%s): %s" % ("BIG " if big else "", rr["verdict"], rr["when"], re.sub(r"\s*\((consolidated|standalone)[^)]*\)", "", rr.get("line") or "")[:150]),
                6 if big else 5, int(rr.get("side") or 0))
    except Exception:
        pass
    # filings (not results)
    try:
        con = _ro("filings.db")
        for kind, side, subj, det, te in con.execute("select kind, side, subject, detail, t_exch from filings where sym=? and t_exch>? and kind in "
                                                     "('ORDER','REG','BOARD','SALES','RATING','MGMT') order by t_exch desc limit 3", (sym, time.time() - 48 * 3600)):
            add("filing", "%s filing (%s): %s" % (kind.lower(), dt.datetime.fromtimestamp(te, IST).strftime("%a %H:%M"), (det or subj or "")[:130]), 4, int(side or 0))
        con.close()
    except Exception:
        pass
    # the news GIR checked and sent
    has_res = any(r["k"] == "results" for r in R)
    try:
        con = _ro("tomorrow.db")
        d0 = str((now - dt.timedelta(hours=36)).date())
        seen = set()
        for day, t, kind, side, text in con.execute("select day, t, kind, side, text from alerts where sym=? and day>=? order by day desc, t desc limit 40", (sym, d0)):
            if kind not in ("📰", "🚨", "📄", "⚡"):
                continue
            L = [x for x in (text or "").split("\n") if x.strip() and not re.match(r"(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|🔔 OPENING \d|⚠ NOT SENT)", x)]   # GIR's own tags are not the news
            head = L[0] if L else ""
            if not re.search(r"\bNEWS\b", head) or re.search(r"FILING|· NSE \d", head):
                continue
            if has_res and any(re.search(r"outcome of (?:the )?board meeting|financial results|RESULTS (?:BIG )?(?:BEAT|MISS|IN LINE)", x, re.I) for x in L[1:2]):
                continue                                        # patch 134: the filing's own echo is not a 2nd reason (a real story on the results stays)                                        # patch 133b: news only - GIR's own desk / OI lines and the filings (read above) are not news
            hl = L[1][:120] if len(L) > 1 else head[:120]
            rd = next((x.split(":", 1)[-1].strip() for x in L if x.startswith("the reader")), "")
            rd = re.sub(r"\s*·\s*(?:CRITICAL|IMPORTANT|MINOR|NOISE)\b.*$", "", rd)            # the reader's level stays out of the line
            k_ = hl[:50].lower()
            if k_ in seen:
                continue
            seen.add(k_)
            sg = 1 if side == "CE" else -1 if side == "PE" else 0
            add("news", "news %s %s: %s%s" % (day[5:], t[:5], hl, (" — " + rd[:110]) if rd else ""), 5 if "CRITICAL" in head else 3, sg)
            if len(seen) >= 3:
                break
        con.close()
    except Exception:
        pass
    # brokers in the news
    try:
        import newsroom
        nm = _name(sym)
        for it in newsroom.items_for(sym, 72, 0)[:20]:
            h_ = it.get("h") or ""
            if BROKER_RX.search(h_) and ACTION_RX.search(h_) and not ROUNDUP_RX.search(h_) and _names_it(h_, sym, nm):   # patch 133b: a call on THIS company
                add("broker", "broker (%s): %s" % (it.get("t"), (it.get("h") or "")[:130]), 3, int(it.get("side") or 0))
                break
    except Exception:
        pass
    # sector and market
    q = _quotes()
    secs = _sectors(q.keys())
    sec = next(((n, s) for n, s in secs.items() if sym in s), None)
    if sec and chg is not None:
        v = [q[s][1] for s in sec[1] if s != sym and s in q and len(q[s]) > 1 and q[s][1] is not None]
        if len(v) >= 2:
            sa = sum(v) / len(v)
            if abs(sa) >= 0.7 and sa * chg > 0:
                add("sector", "the %s sector is %+.1f%% (%d shares) - it moves with its sector" % (sec[0].lower(), sa, len(v)), 2, 1 if sa > 0 else -1)
            elif abs(chg) >= 1.5 and (sa * chg <= 0 or abs(sa) < 0.4):
                add("alone", "on its own - its %s sector is %s" % (sec[0].lower(), "flat" if abs(sa) < 0.05 else "%+.1f%%" % sa), 1, 0)
    nif = ((_state().get("idx") or {}).get("NIFTY") or {}).get("chg")
    if nif is not None and chg is not None and abs(nif) >= 0.6 and nif * chg > 0:
        add("market", "NIFTY %+.1f%% - the whole market" % nif, 1, 1 if nif > 0 else -1)
    # money
    if f.get("bu") and abs(f.get("cr") or 0) >= 5:
        sg = 1 if f["bu"] in ("LONG BUILD-UP", "SHORT COVERING") else -1
        add("money", "%s · ₹%.0f cr of fresh futures money" % (f["bu"].lower(), abs(f["cr"])), 2, sg)
    om = next((x for x in _state().get("opt_money") or [] if x.get("s") == sym), None)
    if om and (om.get("rce") or om.get("rpe")):
        lab = lambda w, v: v if str(v).lower().startswith(w) else "%s %s" % (w, v)
        add("options", " · ".join(x for x in (lab("calls", om["rce"]) if om.get("rce") else "", lab("puts", om["rpe"]) if om.get("rpe") else "") if x), 1, 0)
    # calendar
    try:
        con = _ro("chains.db")
        r = con.execute("select d from results_cal where sym=? and d>=? and d<=? order by d limit 1", (sym, str(now.date()), str(now.date() + dt.timedelta(days=2)))).fetchone()
        con.close()
        if r:
            add("due", "results due %s - money positioning before the numbers" % dt.date.fromisoformat(r[0]).strftime("%a %d %b"), 1, 0)
    except Exception:
        pass
    try:
        import events
        for e in events.for_sym(sym, now)[:1]:
            if e["today"]:
                add("event", "%s %s" % (e["kind"], e["when"]), 1, 0)
    except Exception:
        pass
    stock = any(r["k"] in ("results", "filing", "news", "broker") for r in R)
    if not stock and chg is not None and abs(chg) >= 1:
        try:
            j = json.load(open(os.path.join(BASE, "data", "macro.json")))
            it = max((x for x in j.get("items") or [] if time.time() - float(x.get("t") or 0) < 12 * 3600 and (x.get("score") or 0) >= 5),
                     key=lambda x: x.get("score") or 0, default=None)
            if it and nif is not None and abs(nif) >= 0.4:
                add("global", "market news: %s" % (it.get("h") or "")[:110], 1, 0)
        except Exception:
            pass
        add("none", "no company news found - the market / the money only", 0, 0)
    # rank: what explains this direction first, then the rest
    R.sort(key=lambda r: (-(r["side"] == d and d != 0), -r["w"]))
    against = [r for r in R if d and r["side"] == -d and r["w"] >= 3]
    parts = [r["t"] for r in R if r["side"] in (d, 0) or not d][:4]
    line = " · ".join(p[:100] + ("…" if len(p) > 100 else "") for p in parts)
    if against:
        line += " · ⚠ against: %s" % against[0]["t"][:70]
    out = {"s": sym, "px": px, "chg": chg, "dir": "UP" if d > 0 else "DOWN" if d < 0 else "", "reasons": R, "line": line, "stock": stock}
    if len(_C) > 400:
        _C.clear()
    _C[sym] = (time.time(), out)
    return out


SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")


def add_line(text):
    """a move / OI alert -> the same alert with a "🔎 why:" line (once); any other alert unchanged"""
    try:
        L = (text or "").split("\n")
        head = L[0]
        if head.startswith("🔔 OPENING") and len(L) > 1 and not head.startswith("🔔 OPENING · "):
            head = L[1]
        h2 = head[len("🔔 OPENING · "):] if head.startswith("🔔 OPENING · ") else head
        k = h2.split()[0] if h2.split() else ""
        if k not in MOVE_K or "🔎 why:" in text or "CRITICAL" in h2 or "NEWS" in h2:
            return text
        m = SYM_RX.search(h2)
        if not m or m.group(1) in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX"):
            return text                                         # patch 134: the index desk's lines carry their own why
        w = explain(m.group(1))
        if not w.get("line"):
            return text
        return text.rstrip("\n") + "\n🔎 why: " + w["line"][:300]
    except Exception:
        return text


if __name__ == "__main__":
    for s in sys.argv[1:] or ["VOLTAS"]:
        w = explain(s)
        print("%s %s %s" % (w["s"], ("%+.2f%%" % w["chg"]) if w["chg"] is not None else "?", w["dir"]))
        print("  WHY: %s" % (w["line"] or "-"))
        for r in w["reasons"]:
            print("   %s %-8s w%d  %s" % ({1: "▲", -1: "▼", 0: "·"}[r["side"]], r["k"], r["w"], r["t"]))
PY_WHY
cat > $D/p134test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p134test.py - THE NIFTY / BANKNIFTY OPTIONS DESK with a fake Kite (nothing is fetched or sent): the chain, PCR, max pain,
floor / ceiling, the 4 checks -> BUY CE on a bullish morning, the Telegram lines (the decision turning, a wall moving after 2
readings, the decision off), the page's data; whymove leaves the index lines alone and counts the results once."""
import os, sys, json, time, types, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


sys.modules["getdata"] = types.SimpleNamespace(call=lambda f, *a: f(*a))
import idxdesk, tglanes, alertword
IST = idxdesk.IST
tmp = tempfile.mkdtemp(prefix="p134")
try:
    idxdesk.FILE = os.path.join(tmp, "data", "idxdesk.json")
    today = dt.datetime.now(IST).date()
    exp = today + dt.timedelta(days=2)
    K = [24000 + 50 * i for i in range(41)]                       # 24000 .. 26000
    INS = [{"name": "NIFTY", "instrument_type": kd, "expiry": exp, "strike": k, "tradingsymbol": "NIFTYX%d%s" % (k, kd), "lot_size": 75} for k in K for kd in ("CE", "PE")]
    INS += [{"name": "NIFTY", "instrument_type": "CE", "expiry": exp + dt.timedelta(days=7), "strike": 25000, "tradingsymbol": "NIFTYNEXT", "lot_size": 75}]
    W = {"spot": 24990.0, "pe_floor": 24900, "boost": 0.0}

    def oi(k, kd):
        if kd == "CE":
            return 400000 + (900000 if k == 25200 else 0) + max(0, 25000 - k) * 20
        base = 380000 + max(0, k - 25000) * 20 + (800000 if k == 24900 else 0)
        if W["boost"] and k in (24950, 25000):
            base += W["boost"] * (1.6 if k == 25000 else 0.6)
        return base

    class Kite(object):
        def instruments(self, ex):
            return INS

        def quote(self, keys):
            out = {}
            for kk in keys:
                if kk == "NSE:NIFTY 50":
                    out[kk] = {"last_price": W["spot"], "ohlc": {"close": 24950.0}}
                elif kk.startswith("NFO:NIFTYX"):
                    s = kk[len("NFO:NIFTYX"):]
                    k, kd = int(s[:-2]), s[-2:]
                    prem = max(5.0, (W["spot"] - k if kd == "CE" else k - W["spot"])) + 60
                    out[kk] = {"oi": oi(k, kd), "last_price": round(prem, 1)}
            return out
    prev = {"%g" % k: {"ce": [oi(k, "CE"), 0], "pe": [oi(k, "PE"), 0]} for k in K}
    idxdesk._prev_close = lambda n, e, now: prev if n == "NIFTY" else {}
    T = lambda h, m: dt.datetime.combine(today, dt.time(h, m), IST)
    SENT = []
    print("1. the chain")
    o1 = idxdesk.sweep(Kite(), SENT.append, T(9, 40))
    d = o1["NIFTY"]
    check("NIFTY %s · exp %s (%dd) · lot %s · %d strikes shown around ATM %s" % (d["spot"], d["exp"], d["dte"], d["lot"], len(d["rows"]), d["atm"]),
          d["atm"] == 25000 and d["dte"] == 2 and d["lot"] == 75 and len(d["rows"]) == 15 and "BANKNIFTY" not in o1)
    check("CEILING %s (most calls above) · FLOOR %s (most puts below) · max pain %s · PCR %s" % (d["ceil"], d["floor"], d["pain"], d["pcr"]),
          d["ceil"] == 25200 and d["floor"] == 24900 and d["pain"] is not None and d["pcr"] is not None and 0.3 < d["pcr"] < 3)
    check("IV %s%% and the straddle ±%s from the at-the-money premiums" % (d["iv"], d["straddle"]), d["iv"] and d["straddle"])
    check("09:40, nothing changed since the close: WAIT (%d ▲ %d ▼), no Telegram" % (d["dec"]["bull"], d["dec"]["bear"]), d["dec"]["word"] == "WAIT" and not SENT)
    print("2. a bullish morning: puts written at 24950 / 25000, the price up")
    W.update({"spot": 25060.0, "boost": 1500000})
    o2 = idxdesk.sweep(Kite(), SENT.append, T(10, 15))
    d = o2["NIFTY"]
    check("DECISION %s · %s" % (d["dec"]["word"], " · ".join(("▲" if s > 0 else "▼" if s < 0 else "·") + " " + x for s, x in d["dec"]["why"])),
          d["dec"]["word"] == "BUY CE" and d["dec"]["bull"] >= 3 and d["dec"]["bear"] == 0)
    t = d["dec"]["trade"]
    check("the trade: %s %s ₹%s · stop ₹%s · target NIFTY %s · 1 lot ₹%s" % (t["strike"], t["kind"], t["prem"], t["stop"], t["target_spot"], t["lot_cost"]),
          t["strike"] == 25050 and t["kind"] == "CE" and t["stop"] == round(t["prem"] * 0.7, 1) and t["target_spot"] == 25200 and t["lot_cost"] == round(t["prem"] * 75))
    check("Telegram: %s" % (SENT[0].split("\n")[0] if SENT else None), len(SENT) == 1 and SENT[0].startswith("🔭 NIFTY OPTIONS ▲ BUY CE 25050 CE"))
    check("it goes to %s (lane %s, ring %s)" % (tglanes.topic(SENT[0]), tglanes.lane(SENT[0]), alertword.tier(SENT[0])), tglanes.lane(SENT[0]) == "oi" and alertword.tier(SENT[0]) == "move" and alertword.tier(SENT[-1] if "is off" in SENT[-1] else "🔭 NIFTY OPTIONS · BUY CE is off · 10:50") == "read")
    print("3. the floor moved up - said once it held 2 readings")
    o3 = idxdesk.sweep(Kite(), SENT.append, T(10, 16))
    flips = [x for x in SENT if x.startswith("🧱 WALL FLIP")]
    check("%s" % (flips[0].split("\n")[0] if flips else None), len(flips) == 1 and "floor 24900 → 25000" in flips[0] and "▲" in flips[0] and len([x for x in SENT if x.startswith("🔭")]) == 1)
    check("the wall flip goes to the OI lane (%s)" % tglanes.lane(flips[0]) if flips else "no flip", flips and tglanes.lane(flips[0]) == "oi")
    print("4. the move fades: the decision off")
    W.update({"spot": 24930.0, "boost": 0})
    idxdesk.sweep(Kite(), SENT.append, T(10, 50))
    off = [x for x in SENT if "is off" in x]
    check("🔭 ... BUY CE is off: %s" % (off[0].split("\n")[0] if off else None), len(off) == 1)
    print("5. the page and the restart")
    j = json.load(open(idxdesk.FILE))
    check("data/idxdesk.json: NIFTY with %d readings of the day's path" % len(j["NIFTY"]["hist"]), len(j["NIFTY"]["hist"]) == 4 and j.get("at"))
    idxdesk.ST["day"] = None
    idxdesk.sweep(Kite(), None, T(10, 51))
    check("an engine restart in the day keeps the day's path (%d readings)" % len(idxdesk.ST["hist"]["NIFTY"]), len(idxdesk.ST["hist"]["NIFTY"]) == 5)
    import dashserve
    b0 = dashserve.BASE; dashserve.BASE = tmp
    check("the page server serves it (/market idxd)", (dashserve._idxd().get("NIFTY") or {}).get("spot") == 24930.0)
    dashserve.BASE = b0
    pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
    check("MARKET screen: the NIFTY · BANKNIFTY OPTIONS panel", 'id="mk-idx"' in pg and "function idxDeskHTML(J)" in pg and '"mov hea bus idx nws"' in pg)
    en = open(os.path.join(B, "engine2.py"), encoding="utf-8").read()
    check("the engine kicks it every minute (its own thread)", "idxdesk.kick(kite, tg_fo)" in en)
    import whymove
    check("whymove leaves the index lines alone", whymove.add_line(SENT[0]) == SENT[0])
    import re as _re
    L_ = ["📰 NEWS ▲ DIVISLAB · RESULTS · ET 15:10", "RESULTS BEAT — beats: Outcome of Board Meeting — D (proof)"]
    check("the results filing's echo is recognised (Divi's 8 Nov), a real story is not", any(_re.search(r"outcome of (?:the )?board meeting|financial results|RESULTS (?:BIG )?(?:BEAT|MISS|IN LINE)", x, _re.I) for x in L_[1:2])
          and not _re.search(r"outcome of (?:the )?board meeting|financial results|RESULTS (?:BIG )?(?:BEAT|MISS|IN LINE)", "Voltas Q2 profit falls 78% on weak AC demand", _re.I))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP134 INDEX DESK TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p134_patch.py $D || { rm -f $D/p134test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/idxdesk.py $D/ && cp $W/whymove.py $D/whymove.py
cd $D && python3 -m py_compile idxdesk.py whymove.py engine2.py dashserve.py alertword.py p134test.py || back
timeout 120 python3 p134test.py 2>&1 | grep "OK  \|FAIL\|P134"
timeout 120 python3 p134test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p133btest.py p133test.py p132ctest.py p132btest.py p132test.py p131test.py p130test.py p130ctest.py p129test.py p128test.py p127test.py p125btest.py p124test.py p123test.py p120test.py p119test.py p114test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 134 APPLIED. Reload the GIR page: MARKET screen -> NIFTY · BANKNIFTY OPTIONS. It fills from 09:15 (every minute)."
echo "Check it any time:  python3 /home/globalbot/intraday/idxdesk.py"
