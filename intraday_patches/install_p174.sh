#!/bin/bash
# PATCH 174 - MY F&O (tab 9) becomes your P&L calculator: set your capital once; each trade with its stop and target; the open trades'
#   price and P&L now (Kite every minute in the session); 🛑 YOUR STOP / 💼 YOUR TARGET ring GIR Trade now; the risk at your stop as
#   % of capital while you type (warns above 2%); capital now, return %, best / worst day, biggest fall, month by month - all net of
#   charges. gir-dash restarts (the page shows 502 for 1-3 minutes) - run it outside market hours.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
HOL=$(cd $D && python3 -c "import holidays, datetime as d; print(1 if holidays.holiday(d.date.today()) else 0)" 2>/dev/null || echo 0)
if [ "$DOW" -le 5 ] && [ "$HOL" = "0" ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run after 15:35 (the page restarts)"; exit 1; fi
cp $D/home.html $D/home.html.bak$TS; cp $D/dashserve.py $D/dashserve.py.bak$TS; [ -f $D/fo_ledger.db ] && cp $D/fo_ledger.db $D/fo_ledger.db.bak$TS
cat > $D/myfo.py <<'MYFO_PY'
#!/usr/bin/env python3
"""myfo.py - patch 174: MY F&O, the calculator for Rama's own trades (entered by hand on the page's 9 MY F&O tab).
  * capital      set once (data/myfo.json): capital now = capital + every closed trade's net + the open trades' P&L now; return %,
                 best / worst day, the biggest fall from a top, month by month
  * open trades  the option's price now (Kite, every minute in the session - myfo.py watch; else GIR's last chain read), P&L in ₹
                 and %, net of the charges a sale now would cost
  * stop/target  entered with the trade; when the price reaches one: 🛑 YOUR STOP / 💼 YOUR TARGET rings in GIR Trade now, once
  * risk         the loss at the stop as % of capital (the page warns above 2%)
  python3 myfo.py watch [--send]     one pass (the timer runs it every minute 09:15-15:30 IST on trading days)"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SET = os.path.join(BASE, "data", "myfo.json")
LIVE = os.path.join(BASE, "data", "myfo_live.json")
MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


def settings():
    try:
        return json.load(open(SET))
    except Exception:
        return {}


def set_capital(cap, now=None):
    s = settings()
    s["capital"] = float(cap)
    s.setdefault("start", (now or dt.datetime.now(IST)).strftime("%Y-%m-%d"))
    os.makedirs(os.path.dirname(SET), exist_ok=True)
    json.dump(s, open(SET, "w"))
    return s


def chain_price(sym, strike, kind, exp=None, base=None):
    """GIR's last option-chain read for that strike -> (ltp, 'dd hh:mm', expiry) or None"""
    p = os.path.join(base or BASE, "chains.db")
    if not os.path.exists(p):
        return None
    try:
        c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=3)
        q = "select ltp, d, t, exp from chain where sym=? and strike=? and kind=? and ltp>0"
        a = [sym, float(strike), kind]
        if exp:
            q += " and exp=?"; a.append(str(exp)[:10])
        else:
            q += " and exp>=?"; a.append(dt.datetime.now(IST).strftime("%Y-%m-%d"))
        r = c.execute(q + " order by exp, d desc, t desc limit 1", a).fetchone()
        c.close()
        return (r[0], "%s %s" % (r[1][5:], r[2]), r[3]) if r else None
    except Exception:
        return None


def live_prices():
    try:
        j = json.load(open(LIVE))
        return j if time.time() - float(j.get("_t", 0)) < 180 else {}
    except Exception:
        return {}


def charges_fn():
    try:
        import dashserve
        return dashserve.charges
    except Exception:
        return lambda q, b, s: round(q * (b + (s or 0)) * 0.0012 + 40, 2)


def extend(state, charges=None, now=None, base=None):
    """adds to the ledger state: each open row's price now and P&L, the capital block, month by month"""
    charges = charges or charges_fn()
    rows = state.get("rows") or []
    lv = live_prices()
    unreal = 0.0
    for r in rows:
        if r.get("net") is not None:
            continue
        x = lv.get(str(r["id"]))
        if x:
            ltp, at, src = x["ltp"], x["t"], "live"
        else:
            cp = chain_price(r["sym"], r["strike"], r["kind"], r.get("expiry") or None, base)
            ltp, at, src = (cp[0], cp[1], "chain") if cp else (None, None, None)
        if ltp:
            g = (ltp - r["buy"]) * r["qty"]
            n = g - charges(r["qty"], r["buy"], ltp)
            r.update({"now": round(ltp, 2), "now_t": at, "now_src": src, "unreal": round(n, 2), "unreal_pct": round((ltp / r["buy"] - 1) * 100, 1)})
            unreal += n
        if r.get("stop"):
            r["risk"] = round(max(0.0, (r["buy"] - r["stop"]) * r["qty"]) + charges(r["qty"], r["buy"], r["stop"]), 2)
    s = settings()
    cap = float(s.get("capital") or 0)
    closed = sorted([r for r in rows if r.get("net") is not None], key=lambda r: (r["day"], r.get("closed") or ""))
    by_day, by_mon = {}, {}
    for r in closed:
        by_day[r["day"]] = by_day.get(r["day"], 0) + r["net"]
        m = by_mon.setdefault(r["day"][:7], [0.0, 0, 0])
        m[0] += r["net"]; m[1] += 1; m[2] += r["net"] > 0
    real = sum(by_day.values())
    eq, top, dd = cap, cap, 0.0
    for d in sorted(by_day):
        eq += by_day[d]; top = max(top, eq)
        if top > 0:
            dd = min(dd, (eq - top) / top * 100)
    state.setdefault("sum", {})["unreal"] = round(unreal, 2)
    state["capital"] = {"set": bool(cap), "capital": cap, "start": s.get("start"), "real": round(real, 2), "now": round(cap + real + unreal, 2),
                        "ret": round((real + unreal) / cap * 100, 2) if cap else None,
                        "best": max(by_day.items(), key=lambda kv: kv[1]) if by_day else None, "worst": min(by_day.items(), key=lambda kv: kv[1]) if by_day else None,
                        "maxdd": round(dd, 2), "months": [[m, round(v[0], 2), v[1], v[2]] for m, v in sorted(by_mon.items(), reverse=True)][:12]}
    return state


# ---------------------------------------------------------------- the watcher (every minute in the session)
def session(now):
    if now.weekday() >= 5 or not (dt.time(9, 15) <= now.time() <= dt.time(15, 30)):
        return False
    try:
        import holidays
        return not holidays.holiday(now.date())
    except Exception:
        return True


def tsym(sym, strike, kind, exp):
    """the NFO trading symbol of a monthly stock option: COCHINSHIP26NOV1200PE"""
    e = dt.date.fromisoformat(str(exp)[:10])
    k = ("%g" % float(strike))
    return "%s%02d%s%s%s" % (sym, e.year % 100, MON[e.month - 1], k, kind)


def watch(send=None, now=None, quote=None, base=None):
    now = now or dt.datetime.now(IST)
    b = base or BASE
    p = os.path.join(b, "fo_ledger.db")
    if not os.path.exists(p):
        return []
    c = sqlite3.connect(p, timeout=10)
    cols = [r[1] for r in c.execute("pragma table_info(fo_ledger)")]
    if "stop" not in cols:
        c.close(); return []
    rows = c.execute("select id, sym, kind, strike, expiry, qty, buy, stop, target from fo_ledger where sell is null").fetchall()
    c.close()
    if not rows:
        return []
    keys = {}
    for i, sym, kind, k, exp, q, buy, stop, tgt in rows:
        if not exp:
            cp = chain_price(sym, k, kind, None, b)
            exp = cp[2] if cp else None
        if exp:
            keys["NFO:" + tsym(sym, k, kind, exp)] = (i, sym, kind, k, q, buy, stop, tgt)
    if quote is None:
        import core
        quote = core.get_kite().quote
    try:
        Q = quote(list(keys)) if keys else {}
    except Exception as ex:
        print("quote: %s" % str(ex)[:100]); return []
    live = {"_t": time.time()}
    try:
        said = json.load(open(os.path.join(b, "data", "myfo_said.json")))
    except Exception:
        said = {}
    cap = float(settings().get("capital") or 0)
    ch = charges_fn()
    out = []
    for key, (i, sym, kind, k, q, buy, stop, tgt) in keys.items():
        ltp = float((Q.get(key) or {}).get("last_price") or 0)
        if not ltp:
            continue
        live[str(i)] = {"ltp": ltp, "t": now.strftime("%H:%M")}
        net = (ltp - buy) * q - ch(q, buy, ltp)
        pc = " (%+.1f%% of capital)" % (net / cap * 100) if cap else ""
        hit = None
        if stop and ltp <= stop and not said.get("%s:stop" % i):
            hit = ("🛑 YOUR STOP · %s %g %s · ₹%.2f ≤ your stop ₹%.2f" % (sym, k, kind, ltp, stop), "stop")
        elif tgt and ltp >= tgt and not said.get("%s:tgt" % i):
            hit = ("💼 YOUR TARGET · %s %g %s · ₹%.2f ≥ your target ₹%.2f" % (sym, k, kind, ltp, tgt), "tgt")
        if hit:
            said["%s:%s" % (i, hit[1])] = now.strftime("%Y-%m-%d %H:%M")
            out.append("%s\nbought ₹%.2f × %d · if you sell now: %s₹%s net after charges%s\nexit in Kite, then enter the sell price on GIR (9 MY F&O)" % (
                hit[0], buy, q, "+" if net >= 0 else "−", format(abs(int(round(net))), ","), pc))
    os.makedirs(os.path.join(b, "data"), exist_ok=True)
    json.dump(live, open(os.path.join(b, "data", "myfo_live.json"), "w"))
    json.dump(said, open(os.path.join(b, "data", "myfo_said.json"), "w"))
    if send:
        for m in out:
            send(m)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "watch":
        n = dt.datetime.now(IST)
        if not session(n) and "--force" not in sys.argv:
            print("outside the session"); sys.exit(0)
        snd = None
        if "--send" in sys.argv:
            import opencall
            snd = opencall.send_tg
        for m in watch(snd):
            print(m + "\n")
MYFO_PY
cat > $D/p174test.py <<'P174TEST_PY'
#!/usr/bin/env python3
"""p174test.py - patch 174: MY F&O - capital, the open trade's P&L now, stop / target alerts (made-up prices, a stand-in Kite, nothing sent)"""
import os, sys, json, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve as ds, myfo as M
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
ds.LEDGER = os.path.join(T, "fo_ledger.db"); M.BASE = T; M.SET = os.path.join(T, "data", "myfo.json"); M.LIVE = os.path.join(T, "data", "myfo_live.json")
c = sqlite3.connect(os.path.join(T, "chains.db"))
c.execute("create table chain(d text, t text, sym text, exp text, strike real, kind text, oi real, vol real, ltp real, spot real)")
c.execute("insert into chain values('2026-11-11','10:30','COCHINSHIP','2026-11-23',1200,'PE',1,1,52.0,1180)"); c.commit(); c.close()
ds.ledger_write({"op": "cap", "capital": "250000"})
st = ds.ledger_write({"op": "add", "sym": "cochinship", "kind": "PE", "strike": "1200", "qty": "400", "buy": "45", "stop": "31.5", "target": "70", "day": "2026-11-11"})
r = [x for x in st["rows"] if x["net"] is None][0]
check("capital ₹2,50,000 saved; the trade with its stop ₹31.5 and target ₹70", st["capital"]["capital"] == 250000 and r["stop"] == 31.5 and r["target"] == 70)
check("the PE now ₹52 (GIR's chain read): P&L ≈ +₹2,800 before charges, +15.6%% (%s)" % r.get("unreal"), r.get("now") == 52 and 2600 < r["unreal"] < 2800 and r["unreal_pct"] == 15.6)
check("risk at the stop: (45 - 31.5) x 400 = ₹5,400 + charges = %.1f%% of capital" % (r["risk"] / 2500), 5400 < r["risk"] < 5600)
check("capital now = 2,50,000 + the open P&L", abs(st["capital"]["now"] - (250000 + r["unreal"])) < 1)
st = ds.ledger_write({"op": "exit", "id": r["id"], "sell": "60"})
cl = [x for x in st["rows"] if x["net"] is not None][0]; C = st["capital"]
check("sold at ₹60: net = ₹6,000 - charges, capital now = 2,50,000 + net, return %% (%s)" % C, 5800 < cl["net"] < 6000 and abs(C["now"] - 250000 - cl["net"]) < 1 and C["ret"] > 2.3)
check("month by month: 2026-11 one trade, won", C["months"][0][0] == "2026-11" and C["months"][0][2] == 1 and C["months"][0][3] == 1)
ds.ledger_write({"op": "add", "sym": "SBIN", "kind": "CE", "strike": "800", "qty": "750", "buy": "10", "stop": "7", "target": "15", "day": "2026-11-11"})
ds.ledger_write({"op": "add", "sym": "COCHINSHIP", "kind": "PE", "strike": "1200", "qty": "400", "buy": "45", "stop": "31.5", "target": "70", "day": "2026-11-11"})
ds.ledger_write({"op": "lvl", "id": 3, "stop": "35", "target": "70"})
check("the tradingsymbol Kite wants: COCHINSHIP26NOV1200PE", M.tsym("COCHINSHIP", 1200, "PE", "2026-11-23") == "COCHINSHIP26NOV1200PE")
Q = {"NFO:COCHINSHIP26NOV1200PE": {"last_price": 34.0}}
now = dt.datetime(2026, 11, 11, 11, 0, tzinfo=M.IST)
import shutil as sh_
os.makedirs(os.path.join(T, "data"), exist_ok=True)
sh_.copy(ds.LEDGER, os.path.join(T, "fo_ledger.db")) if ds.LEDGER != os.path.join(T, "fo_ledger.db") else None
out = M.watch(None, now, lambda keys: {k: v for k, v in Q.items() if k in keys}, T)
print("\n".join(out))
check("COCHINSHIP PE ₹34 ≤ its stop ₹35 -> 🛑 YOUR STOP, with the loss in ₹ and %% of capital", len(out) == 1 and out[0].startswith("🛑 YOUR STOP · COCHINSHIP 1200 PE") and "% of capital" in out[0] and "−₹" in out[0])
check("said once - not again next minute", M.watch(None, now, lambda keys: {k: v for k, v in Q.items() if k in keys}, T) == [])
Q["NFO:COCHINSHIP26NOV1200PE"] = {"last_price": 71.0}
out = M.watch(None, now, lambda keys: {k: v for k, v in Q.items() if k in keys}, T)
check("then ₹71 ≥ target ₹70 -> 💼 YOUR TARGET", len(out) == 1 and out[0].startswith("💼 YOUR TARGET"))
st = ds.ledger_state()
o = [x for x in st["rows"] if x["id"] == 3][0]
check("the page now shows the live Kite price (₹71, 'live')", o.get("now") == 71 and o.get("now_src") == "live")
try:
    import tglanes, alertword
    m = "🛑 YOUR STOP · X 1 PE · ₹1 ≤ your stop ₹2\nbought"
    check("🛑 / 💼 go to GIR Trade now and ring", tglanes.trade_now(m) and tglanes.trade_now("💼 YOUR TARGET · X") and alertword.tier(m) == "act")
except Exception as ex:
    check("routing (%s)" % ex, False)
shutil.rmtree(T)
print("P174 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P174TEST_PY
cat > $W/p174_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p174_patch.py - PATCH 174: MY F&O - capital, live P&L of open trades, stop / target, the risk as you type (myfo.py does the sums).
Usage: python3 p174_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"

S = [
 ('''                "qty integer, buy real, sell real, note text, src text, created text, closed text)")
    return con''',
  '''                "qty integer, buy real, sell real, note text, src text, created text, closed text)")
    cols_ = [r[1] for r in con.execute("pragma table_info(fo_ledger)")]          # patch 174: your stop / target
    for c_ in ("stop", "target"):
        if c_ not in cols_:
            con.execute("alter table fo_ledger add column %s real" % c_)
    return con'''),
 ('''    for r in con.execute("select id, day, sym, kind, strike, expiry, qty, buy, sell, note, src, created, closed from fo_ledger order by day desc, id desc"):
        d = dict(zip(("id", "day", "sym", "kind", "strike", "expiry", "qty", "buy", "sell", "note", "src", "created", "closed"), r))''',
  '''    for r in con.execute("select id, day, sym, kind, strike, expiry, qty, buy, sell, note, src, created, closed, stop, target from fo_ledger order by day desc, id desc"):
        d = dict(zip(("id", "day", "sym", "kind", "strike", "expiry", "qty", "buy", "sell", "note", "src", "created", "closed", "stop", "target"), r))'''),
 ('def ledger_state():\n    rows = ledger_rows()', 'def _ledger_state0():\n    rows = ledger_rows()'),
 ('def ledger_write(body):', '''def ledger_state():                                              # patch 174: + capital, the open trades' P&L now
    st = _ledger_state0()
    try:
        import myfo
        myfo.extend(st, charges)
    except Exception as ex:
        st["capital"] = {"set": False, "err": str(ex)[:80]}
    return st


def ledger_write(body):'''),
 ('''                     str(body.get("src") or "")[:20], dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M"), dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M") if sell else None))''',
  '''                     str(body.get("src") or "")[:20], dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M"), dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M") if sell else None))
        st_, tg_ = float(body.get("stop") or 0) or None, float(body.get("target") or 0) or None          # patch 174
        if st_ or tg_:
            con.execute("update fo_ledger set stop=?, target=? where id=last_insert_rowid()", (st_, tg_))'''),
 ('''    elif op == "del":''', '''    elif op == "cap":                                            # patch 174: your capital
        import myfo
        con.close()
        if float(body.get("capital") or 0) <= 0:
            raise ValueError("need the capital in rupees")
        myfo.set_capital(float(body.get("capital")))
        return ledger_state()
    elif op == "lvl":                                            # patch 174: change a trade's stop / target
        con.execute("update fo_ledger set stop=?, target=? where id=?", (float(body.get("stop") or 0) or None, float(body.get("target") or 0) or None, int(body.get("id"))))
    elif op == "del":'''),
]

NEW_RENDER = r'''  // MY F&O (patch 174: capital · the open trades' P&L now · stop / target · month by month)
  const L=P.ledger||{}, S=L.sum||{}, CP=L.capital||{}; const rows=L.rows||[]; const op=rows.filter(r=>r.net==null), cl=rows.filter(r=>r.net!=null).slice(0,15); MFCAP=CP.capital||0;
  const pcs=v=>v==null?"":`${v>=0?"+":""}${v}%`;
  $("mfl").innerHTML=`<div class="kp"><div><small>CAPITAL NOW</small><b class="${cls((CP.now||0)-(CP.capital||0))}">${CP.set?rsx(CP.now):"set it below"}</b>${CP.set?`<small class="${cls(CP.ret)}">${pcs(CP.ret)} since ${esc(CP.start||"")}</small>`:""}</div><div><small>OPEN TRADES NOW</small><b class="${cls(S.unreal)}">${rsx(S.unreal||0)}</b></div><div><small>TODAY (CLOSED)</small><b class="${cls(S.today)}">${rsx(S.today)}</b></div><div><small>SINCE START</small><b class="${cls(S.total)}">${rsx(S.total)}</b></div><div><small>TRADES · WON</small><b>${S.n||0} · ${S.wins||0}</b></div><div><small>BIGGEST FALL</small><b class="${CP.maxdd<0?"pd":""}">${CP.maxdd!=null?CP.maxdd+"%":"—"}</b></div></div>
    <form onsubmit="return mfCap(event)" style="padding:4px 8px">CAPITAL ₹ <input id="mf_cap" inputmode="numeric" value="${CP.capital||""}" placeholder="e.g. 250000" style="width:110px"> <button>SET</button> ${CP.best?`<span class="dim">best day ${esc(CP.best[0].slice(5))} <b class="pu">${rsx(CP.best[1])}</b> · worst ${esc(CP.worst[0].slice(5))} <b class="pd">${rsx(CP.worst[1])}</b></span>`:""}</form>
    <form onsubmit="return mfAdd(event)" oninput="mfRisk()"><input id="mf_s" placeholder="SHARE" style="width:110px;text-transform:uppercase"><select id="mf_k"><option>CE</option><option>PE</option></select><input id="mf_k2" placeholder="strike" inputmode="decimal" style="width:70px"><input id="mf_q" placeholder="qty" inputmode="numeric" style="width:60px"><input id="mf_b" placeholder="buy ₹" inputmode="decimal" style="width:70px"><input id="mf_st" placeholder="stop ₹" inputmode="decimal" style="width:70px"><input id="mf_tg" placeholder="target ₹" inputmode="decimal" style="width:76px"><button>+ ADD TRADE</button></form><div class="msg" id="mf_r"></div><div class="msg" id="mf_m"></div>
    ${op.length?`<div class="hd2">OPEN</div>`+op.map(r=>`<div class="r"><div class="sy"><b onclick="focusOn('${esc(r.sym)}')">${esc(r.sym)}</b><small>${r.strike} ${esc(r.kind)} · ${r.qty} qty</small></div><div><div class="do ${r.unreal>0?"up":r.unreal<0?"dn":""}">bought ₹${r.buy}${r.now!=null?` → now ₹${r.now} <small class="dim">(${r.now_src==="live"?"live "+esc(r.now_t):"GIR chain "+esc(r.now_t||"")})</small> · P&amp;L ${rsx(r.unreal)} (${pcs(r.unreal_pct)})`:` · cost ${rsx(r.cost)} · <span class="dim">price comes in the session</span>`}</div><div class="why">stop <input id="mfs_${r.id}" value="${r.stop||""}" inputmode="decimal" style="width:62px"> target <input id="mft_${r.id}" value="${r.target||""}" inputmode="decimal" style="width:62px"> <button onclick="mfLvl(${r.id})">SAVE</button>${r.risk!=null?` · risk at stop ${rsx(r.risk)}${MFCAP?` (${(r.risk/MFCAP*100).toFixed(1)}% of capital)`:""}`:""} · <input id="mfx_${r.id}" placeholder="sell ₹" inputmode="decimal" style="width:70px"> <button onclick="mfExit(${r.id})">EXIT</button></div></div></div>`).join(""):""}
    ${cl.length?`<div class="hd2">CLOSED</div>`+cl.map(r=>`<div class="r"><div class="sy"><b>${esc(r.sym)}</b><small>${esc(r.day)} · ${r.strike} ${esc(r.kind)}</small></div><div><div class="do ${r.net>0?"up":"dn"}">₹${r.buy} → ₹${r.sell} · NET ${rsx(r.net)}${MFCAP?` <small>(${(r.net/MFCAP*100).toFixed(2)}% of capital)</small>`:""}</div><div class="why">charges ${rsx(r.charges)} · gross ${rsx(r.gross)}</div></div></div>`).join(""):'<div class="empty">no closed trade yet</div>'}
    ${(CP.months||[]).length?`<div class="hd2">MONTH BY MONTH</div>`+CP.months.map(m=>`<div class="r"><div class="sy"><b>${esc(m[0])}</b><small>${m[2]} trades · ${m[3]} won</small></div><div><div class="do ${m[1]>=0?"up":"dn"}">${rsx(m[1])}${MFCAP?` <small>(${(m[1]/MFCAP*100).toFixed(1)}%)</small>`:""}</div></div></div>`).join(""):""}`;
'''

NEW_FUNCS = r'''let MFCAP=0;   /* patch 174 */
function mfRisk(){ const q=+($("mf_q").value||0), b=+($("mf_b").value||0), s=+($("mf_st").value||0), o=$("mf_r"); if(!o) return; if(!q||!b){ o.textContent=""; return; }
  const cost=q*b, risk=s&&s<b?(b-s)*q:cost; const pc=MFCAP?risk/MFCAP*100:null;
  o.innerHTML=`cost ₹${Math.round(cost).toLocaleString("en-IN")}${MFCAP?` (${(cost/MFCAP*100).toFixed(1)}% of capital)`:""} · ${s?"loss at your stop":"no stop - the whole cost is at risk"} ₹${Math.round(risk).toLocaleString("en-IN")}${pc!=null?` = <b class="${pc>2?"pd":"pu"}">${pc.toFixed(1)}% of capital</b>${pc>2?" ⚠ above 2% - fewer lots?":" ✓ within 2%"}`:" · set your capital to see the %"}`; }
async function mfPost(b){ const r=await fetch("ledger?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)}); if(!r.ok) throw new Error(await r.text()); loadPanels(); }
async function mfCap(ev){ ev.preventDefault(); try{ await mfPost({op:"cap",capital:$("mf_cap").value}); $("mf_m").textContent="capital saved ✓"; }catch(e){ $("mf_m").textContent="not saved: "+e.message; } return false; }
async function mfLvl(id){ try{ await mfPost({op:"lvl",id:id,stop:$("mfs_"+id).value,target:$("mft_"+id).value}); $("mf_m").textContent="stop / target saved ✓ - GIR rings Trade now when the price reaches one"; }catch(e){ $("mf_m").textContent="not saved: "+e.message; } }
async function mfAdd(ev){ ev.preventDefault(); const m=$("mf_m"); m.textContent="saving…";
  const d=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const day=d.toISOString().slice(0,10);
  try{ await mfPost({op:"add",sym:$("mf_s").value.toUpperCase().trim(),kind:$("mf_k").value,strike:$("mf_k2").value,qty:$("mf_q").value,buy:$("mf_b").value,stop:$("mf_st").value,target:$("mf_tg").value,sell:"",expiry:"",day:day,note:""}); m.textContent="saved ✓"; }catch(e){ m.textContent="not saved: "+e.message; } return false; }'''

OLD_ADD_START = "async function mfAdd(ev){"
OLD_ADD_END = "return false; }\nasync function mfExit(id){"


def main():
    p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
    h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
    if "patch 174" in s and "patch 174" in t:
        print("patch 174 is already in"); return 0
    for a, b in S:
        if s.count(a) != 1:
            print("ANCHOR x%d in dashserve.py: %s" % (s.count(a), a[:60])); return 1
        s = s.replace(a, b)
    i, j = t.find("  // MY F&O\n"), t.find("  // DESK P&L\n")
    k1 = t.find(OLD_ADD_START); k2 = t.find(OLD_ADD_END, k1)
    if min(i, j, k1, k2) < 0 or not i < j:
        print("the MY F&O page code was not found"); return 1
    t = t[:i] + NEW_RENDER + t[j:]
    k1 = t.find(OLD_ADD_START); k2 = t.find(OLD_ADD_END, k1)
    t = t[:k1] + NEW_FUNCS + "\nasync function mfExit(id){" + t[k2 + len(OLD_ADD_END):]
    open(p, "w", encoding="utf-8").write(s); open(h, "w", encoding="utf-8").write(t)
    print("dashserve.py + home.html: MY F&O with capital, live P&L, stop / target")
    return 0


sys.exit(main())
PY_PATCH
back() { cp $D/home.html.bak$TS $D/home.html; cp $D/dashserve.py.bak$TS $D/dashserve.py; }
echo "== 1. the page and the calculator"
R=$(python3 $W/p174_patch.py $D) || { echo "   $R - nothing changed"; back; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile dashserve.py myfo.py || { back; echo "   does not compile - old files back"; exit 1; }
echo "== 2. the tests (your own trades are not touched - a copy of the ledger is made first)"
for t in p174test.py p172test.py p164test.py p146btest.py; do [ -f $t ] || continue
  timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "   $t passed" || { echo "   $t FAILED - old files back:"; grep -E "FAIL|Error" /tmp/$t.log | head -4 | sed 's/^/     /'; back; exit 1; }
done
echo "== 3. the stop / target watcher - every minute 09:15-15:30 IST on trading days"
cat > $U/gir-myfo.service <<'UNIT'
[Unit]
Description=GIR MY F&O - your open trades' price now, your stop / target
[Service]
Type=oneshot
TimeoutStartSec=50
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 myfo.py watch --send >> data/myfo.log 2>&1'
UNIT
cat > $U/gir-myfo.timer <<'UNIT'
[Unit]
Description=GIR MY F&O every minute in the session (it checks the hours and NSE holidays itself)
[Timer]
OnCalendar=Mon..Fri *-*-* 09..15:*:20 Asia/Kolkata
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-myfo.timer >/dev/null 2>&1 && echo "   on"
echo -n "== 4. the page server restarting (the site shows 502 for 1-3 minutes)"
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
if [ $OK = 1 ]; then echo "   ✅ the page is back"; else echo "   ❌ the page did not come back - old files back"; back; systemctl restart gir-dash; journalctl -u gir-dash -n 8 --no-pager | cut -c1-180 | sed 's/^/     /'; exit 1; fi
rm -rf $W
echo
echo "PATCH 174 APPLIED. On girtrader.com press Ctrl + Shift + R, open 9 MY F&O, type your capital (250000) and SET."
