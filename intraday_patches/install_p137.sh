#!/bin/bash
# PATCH 137 - ORDER BOOK PRESSURE, EVERY F&O SHARE (on top of patch 136).
#   Every 10 s: each F&O share's buy and sell orders waiting (the feed already carries them) -> buy%, 5 and 15 minutes ago,
#   BUYERS / SELLERS LOADING (10+ points in 5 min) or QUEUED (70+ / 30-). The NIFTY / BANKNIFTY futures: Kite's 5-level book every
#   minute - buyers %, the big orders (2x the usual level), the big orders PULLED before the price got there; the desk's 5th check.
#   - the share card: ORDER BOOK · - MARKET, F&O DESK: the most buyer- / seller-heavy shares and the fastest loading · - the index
#     desk: FUTURES BOOK
#   bookpress.py (new), idxdesk.py (replaced - patch 134's own file) · engine2.py, dashserve.py, home.html (exact anchors).
#   Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g137; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p137.sh now"; exit 1; fi
grep -q "async function pullNprev" $D/home.html 2>/dev/null || { echo "patch 136 is not installed yet - paste patch 136 first"; exit 1; }
[ -f $D/bookpress.py ] && { echo "patch 137 is already installed"; exit 1; }
F="engine2.py dashserve.py home.html idxdesk.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/bookpress.py $D/p137test.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p137_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p137_patch.py - PATCH 137: ORDER BOOK PRESSURE - every F&O share (bookpress.py, from the feed's buy / sell orders waiting, every
10 s) and the NIFTY / BANKNIFTY futures' 5-level book with the big and the pulled orders (idxdesk.py, the desk's 5th check).
Usage: python3 p137_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''        if nowt - tick.get("sidx", 0.0) >= 15:               # patch 120: the official NSE sector indices''',
         '''        if nowt - tick.get("book", 0.0) >= 10:               # patch 137: order book pressure, every F&O share
            tick["book"] = nowt
            try:
                import bookpress
                bookpress.update(feed.syms, feed.tbq, feed.tsq, feed.ltp, feed.pclose, feed.fo_idx)
            except Exception as ex:
                if ("BOOK", "fail") not in _said:
                    _said.add(("BOOK", "fail"))
                    log("book pressure failed:", ex)
        if nowt - tick.get("sidx", 0.0) >= 15:               # patch 120: the official NSE sector indices'''),
    ],
    "dashserve.py": [
        ('''"chain": market_chain(), "idxd": _idxd()}''', '''"chain": market_chain(), "idxd": _idxd(), "book": _book_top()}'''),
        ('''def _idxd():''', '''def _book_top():
    """patch 137: the most buyer- / seller-heavy F&O shares in the order book now (data/book.json - the engine, every 10 s)"""
    try:
        import bookpress
        return bookpress.top()
    except Exception:
        return {}


def _idxd():'''),
        ('''    try:                                                        # patch 135: THE OI BATTLE''', '''    try:                                                        # patch 137: ORDER BOOK pressure
        import bookpress
        c["book"] = bookpress.for_sym(sym)
    except Exception:
        pass
    try:                                                        # patch 135: THE OI BATTLE'''),
    ],
    "home.html": [
        ('''    <div><small>EVENTS</small>${c&&c.results_in!=null''',
         '''    ${c&&c.book?(b=>`<div><small>ORDER BOOK · ${esc(b.hm||"")} · all orders waiting</small><b class="${b.side>0?"pu":b.side<0?"pd":""}">${esc(b.word)}</b> buyers ${(b.tb/1e5).toFixed(1)} L <b>${b.buy}%</b> · sellers ${(b.ts/1e5).toFixed(1)} L${b.b5!=null?` · 5 min ago ${b.b5}%`:""}${b.b15!=null?` · 15 min ${b.b15}%`:""}</div>`)(c.book):""}
    <div><small>EVENTS</small>${c&&c.results_in!=null'''),
        ('''      <div><em>RESULTS</em>''', '''      <div><em>ORDER BOOK</em>${(()=>{ const B=M.book||{}; if(!(B.buy||[]).length) return '<span class="dim">from 09:15 - buy vs sell orders waiting, every F&amp;O share</span>';
        const one=x=>`<span class="k" onclick="mkOpen('${esc(x.s)}')"><b>${esc(x.s)}</b> ${x.buy}%${x.b5!=null&&Math.abs(x.buy-x.b5)>=10?`<i class="${x.buy>x.b5?"pu":"pd"}">${x.buy>x.b5?"▲":"▼"}${Math.abs(x.buy-x.b5).toFixed(0)}</i>`:""}</span>`;
        return `<span class="dim">${esc(B.hm||"")} · buyers waiting %</span><br><b class="pu">BUYERS</b> ${(B.buy||[]).slice(0,5).map(one).join(" · ")}<br><b class="pd">SELLERS</b> ${(B.sell||[]).slice(0,5).map(one).join(" · ")}<br><b class="am">LOADING</b> ${(B.loading||[]).slice(0,5).map(one).join(" · ")}`; })()}</div>
      <div><em>RESULTS</em>'''),
        ('''    <table><tr class="dim"><td>CE OI · % vs ${esc(d.ref||"")}</td>''',
         '''    ${d.book?(b=>`<div class="ixw"><b>FUTURES BOOK</b> ${esc(b.fut||"")} ₹${b.px??"—"}${b.basis!=null?` (${b.basis>0?"+":""}${b.basis} vs spot)`:""} · buyers <b class="${b.buy>=60?"pu":b.buy<=40?"pd":""}">${b.buy??"—"}%</b> of the orders waiting · best bid ${b.bids&&b.bids[0]?b.bids[0][0]+" ("+b.bids[0][1]+" lots)":"—"} · best ask ${b.asks&&b.asks[0]?b.asks[0][0]+" ("+b.asks[0][1]+" lots)":"—"}${(b.big||[]).length?`<br>big orders (2× the usual ${b.usual} lots): ${b.big.map(x=>`<span class="${x.side==="BUY"?"pu":"pd"}">${x.side} ${x.lots} lots @${x.price} (${x.x}×)</span>`).join(" · ")}`:""}${(b.pulled||[]).length?`<br><span class="am">PULLED before the price got there: ${b.pulled.map(x=>`${x.side} ${x.lots} lots @${x.price}`).join(" · ")}</span>`:""}</div>`)(d.book):""}
    <table><tr class="dim"><td>CE OI · % vs ${esc(d.ref||"")}</td>'''),
        ('''of 4 · a BUY needs 3 agreeing and none against''', '''of ${(X.why||[]).length} · a BUY needs 3 agreeing and none against'''),
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
cat > $W/bookpress.py <<'PY_BOOK'
#!/usr/bin/env python3
"""bookpress.py - patch 137: ORDER BOOK PRESSURE FOR EVERY F&O SHARE. The live feed already carries, per share, the exchange's
total quantity of BUY orders waiting and of SELL orders waiting (what Kite shows under the market depth). Every 10 s the engine
hands them here; this keeps a snapshot a minute (20 min) and writes data/book.json:

  buy%      buy orders waiting / (buy + sell waiting) - over 60: the buyers are queued (pressure up) · under 40: the sellers
  5 / 15 m  the same 5 and 15 minutes ago -> "buyers loading" (buy% up 10+ points) / "sellers loading" / "steady"
  read      the TOTALS include orders far from the price, so the CHANGE says more than the level; a level alone over 70 / under 30
            with the price agreeing is worth a look. Big single orders: only the index futures' 5-level book (idxdesk.py).

  share card     ORDER BOOK (buyers / sellers waiting, the % now, 5 and 15 min ago, loading?)
  MARKET         F&O DESK: the most buyer-heavy and seller-heavy F&O shares now, the fastest loading
  python3 bookpress.py           the top of the list now"""
import os, sys, json, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
FILE = os.path.join(BASE, "data", "book.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
ST = {"day": None, "snap": {}, "at": 0.0, "last_min": None}
_R = {"m": None, "v": {}}


def update(syms, tbq, tsq, ltp=None, pclose=None, fo=None, now=None, write=True):
    """syms / tbq / tsq / ltp / pclose: the feed's arrays by index; fo: the indices of the F&O shares -> the snapshot written"""
    now = now or dt.datetime.now(IST)
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "snap": {}, "last_min": None})
    cur = {}
    for i, s in enumerate(syms):
        if not i or (fo and i not in fo):
            continue
        try:
            tb, ts = float(tbq[i]), float(tsq[i])
        except Exception:
            continue
        if not (tb == tb and ts == ts) or tb + ts <= 0:
            continue
        cur[s] = (tb, ts, i)
    m = now.strftime("%H:%M")
    if m != ST["last_min"]:
        ST["last_min"] = m
        ST["snap"][m] = {s: round(v[0] / (v[0] + v[1]) * 100, 1) for s, v in cur.items()}
        for k in sorted(ST["snap"])[:-21]:
            del ST["snap"][k]
    ago = lambda mins: ST["snap"].get((now - dt.timedelta(minutes=mins)).strftime("%H:%M")) or {}
    a5, a15 = ago(5), ago(15)
    out = {}
    for s, (tb, ts, i) in cur.items():
        p = round(tb / (tb + ts) * 100, 1)
        lp = float(ltp[i]) if ltp is not None else float("nan")
        pc = float(pclose[i]) if pclose is not None else float("nan")
        out[s] = [int(tb), int(ts), p, a5.get(s), a15.get(s), round(lp, 2) if lp == lp else None,
                  round((lp / pc - 1) * 100, 2) if (lp == lp and pc == pc and pc > 0) else None]
    j = {"t": time.time(), "hm": now.strftime("%H:%M:%S"), "day": day, "s": out}
    if write:
        os.makedirs(os.path.dirname(FILE), exist_ok=True)
        json.dump(j, open(FILE + ".tmp", "w"), separators=(",", ":"))
        os.replace(FILE + ".tmp", FILE)
    return j


def load():
    try:
        m = os.path.getmtime(FILE)
    except Exception:
        return {}
    if m != _R["m"]:
        try:
            _R["v"], _R["m"] = json.load(open(FILE)), m
        except Exception:
            return _R["v"]
    return _R["v"]


def word(p, p5):
    if p5 is not None and p - p5 >= 10:
        return "BUYERS LOADING", 1
    if p5 is not None and p5 - p >= 10:
        return "SELLERS LOADING", -1
    if p >= 70:
        return "BUYERS QUEUED", 1
    if p <= 30:
        return "SELLERS QUEUED", -1
    return "BALANCED", 0


def for_sym(sym):
    """the share card: {"tb", "ts", "buy", "b5", "b15", "word", "side", "hm", "day"} or None"""
    j = load()
    v = (j.get("s") or {}).get(sym)
    if not v:
        return None
    w, sd = word(v[2], v[3])
    return {"tb": v[0], "ts": v[1], "buy": v[2], "b5": v[3], "b15": v[4], "word": w, "side": sd, "hm": j.get("hm"), "day": j.get("day")}


def top(n=6):
    """the MARKET screen: the most buyer-heavy / seller-heavy F&O shares and the fastest loading, with the price agreeing first"""
    j = load()
    S = j.get("s") or {}
    rows = [(s, v) for s, v in S.items() if v[0] + v[1] > 0]
    agree = lambda v, sd: 1 if (v[6] is not None and v[6] * sd > 0) else 0
    buy = sorted([x for x in rows if x[1][2] >= 55], key=lambda x: (-agree(x[1], 1), -x[1][2]))[:n]          # buyers' side only
    sell = sorted([x for x in rows if x[1][2] <= 45], key=lambda x: (-agree(x[1], -1), x[1][2]))[:n]         # sellers' side only
    load_ = sorted([x for x in rows if x[1][3] is not None and abs(x[1][2] - x[1][3]) >= 5], key=lambda x: -abs(x[1][2] - x[1][3]))[:n]
    f = lambda x: {"s": x[0], "buy": x[1][2], "b5": x[1][3], "chg": x[1][6]}
    return {"hm": j.get("hm"), "day": j.get("day"), "n": len(rows), "buy": [f(x) for x in buy], "sell": [f(x) for x in sell], "loading": [f(x) for x in load_]}


if __name__ == "__main__":
    t = top()
    print("order book pressure %s %s · %d F&O shares" % (t.get("day"), t.get("hm"), t.get("n") or 0))
    for k in ("buy", "sell", "loading"):
        print("  %-8s %s" % (k, " · ".join("%s %s%%%s" % (x["s"], x["buy"], (" (5m ago %s%%)" % x["b5"]) if x["b5"] is not None else "") for x in t.get(k) or [])))
    for s in sys.argv[1:]:
        print("  %s: %s" % (s, for_sym(s.upper())))
PY_BOOK
cat > $W/idxdesk.py <<'PY_IDX'
#!/usr/bin/env python3
"""idxdesk.py - patch 134 (+137: the futures' order book - the 5th check): THE NIFTY / BANKNIFTY OPTIONS DESK. Every minute in market hours (its own thread - the engine never
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
    fut = {n: [] for n in INDEX}
    for i in getdata.call(kite.instruments, "NFO"):
        n = i.get("name")
        if n in fut and i.get("instrument_type") == "FUT":       # patch 137: the futures - their order book
            e = i.get("expiry")
            e = e.date() if isinstance(e, dt.datetime) else dt.date.fromisoformat(e[:10]) if isinstance(e, str) else e
            if e and e >= today:
                fut[n].append((e, i["tradingsymbol"]))
            continue
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
        out[n] = {"exps": exps, "rows": [r for r in rows if r[1] in exps], "lot": lot.get(n) or 0, "fut": (sorted(fut[n])[0][1] if fut[n] else None)}
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
def compute(name, spot, pc, exp, chain, prev, first, hist, now, lot=0, step=None, book=None):
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
    d["book"] = book
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
    b = d.get("book")
    if b and b.get("buy") is not None:                          # patch 137: the 5th check - the futures' order book
        S.append((1 if b["buy"] >= 60 else -1 if b["buy"] <= 40 else 0, "futures book: buyers %s%% of the orders waiting%s" % (
            b["buy"], (" · big: " + ", ".join("%s %d lots @%g (%.1fx)" % (x["side"], x["lots"], x["price"], x["x"]) for x in b["big"][:2])) if b.get("big") else "")))
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


def futbook(n, q, ts, lot, spot):
    """patch 137: the index futures' order book (Kite's 5 levels a side): the orders waiting, buy%, the big orders (2x the usual
    level) and the big orders PULLED since the last minute before the price got there"""
    if not q:
        return None
    dp = q.get("depth") or {}
    bids = [[float(x.get("price") or 0), int(x.get("quantity") or 0), int(x.get("orders") or 0)] for x in (dp.get("buy") or []) if x.get("price")]
    asks = [[float(x.get("price") or 0), int(x.get("quantity") or 0), int(x.get("orders") or 0)] for x in (dp.get("sell") or []) if x.get("price")]
    tb, tsq = float(q.get("total_buy_quantity") or 0), float(q.get("total_sell_quantity") or 0)
    px = float(q.get("last_price") or 0) or None
    qs = sorted(x[1] for x in bids + asks if x[1])
    usual = qs[len(qs) // 2] if qs else 0
    L = lambda qty: qty / lot if lot else qty
    big = [{"side": "BUY", "price": p, "lots": round(L(qty)), "x": round(qty / usual, 1)} for p, qty, o in bids if usual and qty >= 2 * usual] + \
          [{"side": "SELL", "price": p, "lots": round(L(qty)), "x": round(qty / usual, 1)} for p, qty, o in asks if usual and qty >= 2 * usual]
    old = ST.setdefault("big", {}).get(n) or []
    pulled = []
    for b in old:
        here = any(x["side"] == b["side"] and x["price"] == b["price"] for x in big)
        reached = px is not None and ((b["side"] == "SELL" and px >= b["price"]) or (b["side"] == "BUY" and px <= b["price"]))
        if not here and not reached:
            pulled.append(b)
    ST["big"][n] = big
    return {"fut": ts, "px": px, "basis": round(px - spot, 1) if px and spot else None, "tb": int(tb), "ts": int(tsq),
            "buy": round(tb / (tb + tsq) * 100, 1) if tb + tsq else None, "bids": [[p, round(L(qty)), o] for p, qty, o in bids],
            "asks": [[p, round(L(qty)), o] for p, qty, o in asks], "usual": round(L(usual)) if usual else None, "big": big, "pulled": pulled}


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
    fk = ["NFO:" + (ins.get(n) or {}).get("fut") for n in INDEX if (ins.get(n) or {}).get("fut")]
    q = kite.quote([v["spot"] for v in INDEX.values()] + fk) or {}
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
        fb = futbook(n, q.get("NFO:" + I["fut"]) if I.get("fut") else None, I.get("fut"), I.get("lot") or 0, sp)
        d = compute(n, sp, pc, exp, chain, _prev_close(n, exp, now), fr, H, now, I.get("lot") or 0, book=fb)
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
        out.append("🔭 %s OPTIONS %s %s %g %s · ₹%s · %s\nstop ₹%s (premium -30%%) · target: %s %s (%s)\n%d of %d agree: %s\nlot %s = ₹%s · expiry %s (%d day%s)%s" % (
            n, arrow(dec["side"]), dec["word"], t.get("strike") or 0, dec["side"], t.get("prem"), d["t"], t.get("stop"), n, t.get("target_spot"),
            "the ceiling" if dec["side"] == "CE" else "the floor", dec["bull"] if dec["side"] == "CE" else dec["bear"], len(dec["why"]), why, d["lot"],
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
cat > $D/p137test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p137test.py - ORDER BOOK PRESSURE: every F&O share's buy / sell orders waiting -> buy%, 5 and 15 minutes ago, BUYERS / SELLERS
LOADING, the MARKET lists (non-F&O shares left out); the NIFTY futures' 5-level book: big orders (2x the usual), an order PULLED
before the price got there, the desk's 5th check. Fake feed, fake Kite - nothing is fetched or sent."""
import os, re, sys, json, types, shutil, tempfile, subprocess, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import bookpress
IST = bookpress.IST
tmp = tempfile.mkdtemp(prefix="p137")
try:
    print("1. every F&O share")
    bookpress.FILE = os.path.join(tmp, "data", "book.json")
    syms = ["NIFTY50", "ASHOKLEY", "VOLTAS", "TCS", "SMALLCO"]
    fo = {1, 2, 3}
    nan = float("nan")
    ltp = [25000, 178.0, 1290.0, 3000.0, 50.0]
    pc = [25030, 172.1, 1342.0, 3010.0, 49.0]
    day = dt.date(2026, 11, 9)
    T = lambda h, m: dt.datetime.combine(day, dt.time(h, m), IST)
    bookpress.update(syms, [0, 500000, 400000, 300000, 9e9], [0, 500000, 400000, 300000, 1], ltp, pc, fo, now=T(10, 0))
    for m in range(1, 5):
        bookpress.update(syms, [0, 500000, 400000, 300000, 9e9], [0, 500000, 400000, 300000, 1], ltp, pc, fo, now=T(10, m))
    j = bookpress.update(syms, [0, 900000, 150000, nan, 9e9], [0, 450000, 600000, 300000, 1], ltp, pc, fo, now=T(10, 5))
    check("F&O shares only, a share with no reading left out: %s" % sorted(j["s"]), sorted(j["s"]) == ["ASHOKLEY", "VOLTAS"])
    a, v = bookpress.for_sym("ASHOKLEY"), bookpress.for_sym("VOLTAS")
    check("ASHOKLEY: buyers 66.7%% (50%% 5 min ago) -> %s" % a["word"], a["buy"] == 66.7 and a["b5"] == 50.0 and a["word"] == "BUYERS LOADING" and a["side"] == 1)
    check("VOLTAS: buyers 20%% (50%% 5 min ago) -> %s" % v["word"], v["buy"] == 20.0 and v["word"] == "SELLERS LOADING" and v["side"] == -1)
    t = bookpress.top()
    check("MARKET lists: buyers %s · sellers %s · loading %s" % ([x["s"] for x in t["buy"]], [x["s"] for x in t["sell"]], [x["s"] for x in t["loading"]]),
          [x["s"] for x in t["buy"]] == ["ASHOKLEY"] and [x["s"] for x in t["sell"]] == ["VOLTAS"] and t["n"] == 2 and "SMALLCO" not in json.dumps(t))
    print("2. the NIFTY futures' book")
    sys.modules["getdata"] = types.SimpleNamespace(call=lambda f, *a: f(*a))
    import idxdesk
    idxdesk.ST["big"] = {}
    lvl = lambda p, q: {"price": p, "quantity": q, "orders": 3}
    Q = {"last_price": 25060.0, "total_buy_quantity": 900000, "total_sell_quantity": 600000,
         "depth": {"buy": [lvl(25055, 2325), lvl(25050, 9075), lvl(25045, 1425), lvl(25040, 2700), lvl(25035, 4125)],
                   "sell": [lvl(25065, 10875), lvl(25070, 9150), lvl(25075, 1650), lvl(25080, 1800), lvl(25110, 15075)]}}
    b = idxdesk.futbook("NIFTY", Q, "NIFTYFUT", 75, 25012.0)
    check("buyers %s%% · usual %s lots · big: %s" % (b["buy"], b["usual"], [(x["side"], x["lots"], x["price"]) for x in b["big"]]),
          b["buy"] == 60.0 and b["usual"] == 55 and ("SELL", 201, 25110.0) in [(x["side"], x["lots"], x["price"]) for x in b["big"]] and b["basis"] == 48.0)
    Q2 = dict(Q, last_price=25070.0, depth={"buy": Q["depth"]["buy"], "sell": [lvl(25075, 1650), lvl(25080, 1800), lvl(25085, 1500), lvl(25090, 1600), lvl(25095, 1700)]})
    b2 = idxdesk.futbook("NIFTY", Q2, "NIFTYFUT", 75, 25012.0)
    check("the 201 lots @25110 gone, the price never got there -> PULLED: %s" % [(x["side"], x["lots"], x["price"]) for x in b2["pulled"]],
          ("SELL", 201, 25110.0) in [(x["side"], x["lots"], x["price"]) for x in b2["pulled"]] and not any(x["price"] == 25065.0 for x in b2["pulled"]))
    now = dt.datetime.now(IST).replace(hour=10, minute=20)
    d = {"pe_add": 1e6, "ce_add": 1e5, "ref": "the last close", "pcr": 1.1, "floor": 25000, "ceil": 25200, "spot": 25060, "pc": 25000, "dte": 2, "atm": 25050,
         "rows": [{"k": 25050, "ce_p": 70, "pe_p": 60}], "straddle": 130, "lot": 75, "book": b}
    dec = idxdesk.decide(d, [{"t": "09:30", "spot": 24990, "pcr": 1.0, "floor": 24900, "ceil": 25200}], now)
    check("the desk's 5th check: %s" % dec["why"][-1][1], len(dec["why"]) == 5 and dec["why"][-1][0] == 1 and dec["why"][-1][1].startswith("futures book: buyers 60.0%"))
    print("3. the page")
    import dashserve
    b0 = dashserve.BASE
    bookpress._R.update({"m": None, "v": {}})
    cc = dashserve._ev_add("ASHOKLEY", {"s": "ASHOKLEY"})
    check("share card data: ORDER BOOK %s" % (cc.get("book") or {}).get("word"), (cc.get("book") or {}).get("word") == "BUYERS LOADING")
    check("MARKET data: the lists", (dashserve._book_top().get("buy") or [{}])[0].get("s") == "ASHOKLEY")
    pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
    check("the page: ORDER BOOK on the share card and the F&O DESK, FUTURES BOOK on the index desk",
          "<small>ORDER BOOK · " in pg and "<em>ORDER BOOK</em>" in pg and "<b>FUTURES BOOK</b>" in pg and "PULLED before the price got there" in pg)
    en = open(os.path.join(B, "engine2.py"), encoding="utf-8").read()
    check("the engine hands the book over every 10 s", "bookpress.update(feed.syms, feed.tbq, feed.tsq, feed.ltp, feed.pclose, feed.fo_idx)" in en)
    node = shutil.which("node")
    if node:
        js = re.findall(r"<script>(.*?)</script>", pg, re.S)
        open(os.path.join(tmp, "p.js"), "w").write(js[0] if js else "")
        r = subprocess.run([node, "--check", os.path.join(tmp, "p.js")], capture_output=True, text=True, timeout=30)
        check("the page's script parses (%s)" % (r.stderr.strip().split("\n")[-1][:80] if r.returncode else "ok"), r.returncode == 0)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP137 ORDER BOOK TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p137_patch.py $D || { rm -f $D/p137test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/bookpress.py $D/ && cp $W/idxdesk.py $D/idxdesk.py
cd $D && python3 -m py_compile bookpress.py idxdesk.py engine2.py dashserve.py p137test.py || back
timeout 120 python3 p137test.py 2>&1 | grep "OK  \|FAIL\|P137"
timeout 120 python3 p137test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p136test.py p135test.py p135btest.py p134test.py p133test.py p132ctest.py p132test.py p131test.py p130test.py p130ctest.py p129test.py p128test.py p124test.py p123test.py p119test.py p113test.py fmtest.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 137 APPLIED. From 09:15: MARKET -> F&O DESK -> ORDER BOOK (every F&O share), a share's card -> ORDER BOOK,"
echo "NIFTY · BANKNIFTY OPTIONS -> FUTURES BOOK. Check it any time:  python3 /home/globalbot/intraday/bookpress.py ASHOKLEY"
