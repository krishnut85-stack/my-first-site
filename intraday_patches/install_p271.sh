#!/bin/bash
# PATCH 271 - 🃏 MOVE CARD + 🎫 TRADE CARD ON EVERY CONFIRMED ALERT (Rama, 14 Nov: "trade card and move card").
#   A confirmed alert that rings (🚨 RESULTS REACTION · ✅ CONFIRMED MOVE · ⚡ SPEED ▲/▼ · a 🔴 P1 call) carries under it:
#   🃏 MOVE CARD   WHO is pushing (new money / forced out / writers) · WHY (futures, the company's news, the writers) · AGAINST · TIDE (sector, NIFTY) ·
#                  MEASURED (how often this kind was right)
#   🎫 TRADE CARD  the exact option (nearest strike with real trading, an expiry 4+ days away) · premium (the ask) · lot · LOTS FOR YOUR RISK
#                  (₹10,000 a trade; change: python3 movecard.py risk AMOUNT) · the stop ON THE OPTION · target 1 (book half) / 2 · time cost · breakeven
#   ↳ later alerts on that share the same day: "↳ follow-up to the 09:34 MOVE CARD (▲ CE at ₹1,049) · now ₹1,060, +1.0% its way"
#   Prices from Zerodha (READ ONLY - never an order); no answer in 3 s -> the alert goes without the trade card, never held up.
#   Tested: 15 + 4 cases. Restarts the senders - after 15:35 on a trading day (or add: now); on a weekend any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/posguard.py ] && grep -q "patch 264" $D/alertword.py || { echo "patches 263 and 264 first"; exit 1; }
cp $D/alertword.py $D/alertword.py.bak$TS
[ -f $D/movecard.py ] && cp $D/movecard.py $D/movecard.py.bak$TS
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ cp $D/alertword.py.bak$TS $D/alertword.py; rm -f $D/movecard.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/movecard.py <<'PY_MC'
#!/usr/bin/env python3
"""movecard.py - patch 271: 🃏 MOVE CARD + 🎫 TRADE CARD on every confirmed alert (Rama, 14 Nov: "the trade card and the move card").
A confirmed alert (🚨 RESULTS REACTION · ✅ CONFIRMED MOVE · ⚡ SPEED ▲/▼ · a 🔴 P1 trade call) that rings gets, under it:
  🃏 MOVE CARD   WHY (the reasons GIR has: news, filings, futures money, the writers - pushwho) · WHO (new longs / shorts / writers running)
                 · TIDE (its sector and NIFTY today) · MEASURED (how often this kind of alert was right)
  🎫 TRADE CARD  the exact option (the strike nearest the price with real trading, an expiry with 4+ days left), its premium (the ask), the lot,
                 HOW MANY LOTS for your risk (₹10,000 a trade unless set: python3 movecard.py risk AMOUNT), the stop ON THE OPTION (from the
                 share's stop in the alert), target 1 (book half) and 2, the time cost a day, the breakeven at expiry
  ↳ follow-up    any later alert on that share the same day starts with "↳ follow-up to the 09:34 MOVE CARD (▲ CE at ₹1,049) · now ..."
Prices from Zerodha (READ ONLY - never an order). If Zerodha does not answer in 3 s the alert goes without the trade card - never held up."""
import os, re, sys, json, math, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "data", "movecard.json")
CONF = os.path.join(BASE, "data", "posguard.json")
RISK, MIN_DAYS = 10000.0, 4
CARD_RX = re.compile(r"RESULTS REACTION|CONFIRMED MOVE|\bSPEED\b|🔴 TRADE ALERT")
SKIP_RX = re.compile(r"🛑|🎯|⏰|\bEXIT\b|BOOK HALF|POSITION GUARD|EVENT WATCH|📊 RESULTS WEEK|not a buy|🃏 MOVE CARD|🎫 TRADE CARD|↳ follow-up")
TAGS = ("🔴 TRADE ALERT", "🟠 SOMETHING IS HAPPENING", "📌 F&O")
MEASURED = [(r"CONFIRMED MOVE", "the other side kept going 13 of 15 times (7-13 Nov - a small count)"),
            (r"RESULTS REACTION.*DAY \d+ SWING", "day-1 results swings: right 4 of 11, wrong 1 (40-day replay)"),
            (r"RESULTS REACTION", "results moves at the open: right 7 of 10, wrong 2 (40-day replay)"),
            (r"\bSPEED\b", "⚡ SPEED: right 55%, wrong 6% after an hour (7-13 Nov, 3,637 alerts scored)"),
            (r"TRADE ALERT|\bP1\b", "P1 calls: right 24%, wrong 21% (7-13 Nov) - the weakest kind: half size")]
_K = {"k": None, "t": 0.0, "fail": 0.0}


def _inr(x, d=0):
    x = float(x)
    return ("-" if x < 0 else "") + ("₹{:,.%df}" % d).format(abs(x))


def _load(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def _save(p, v):
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        json.dump(v, open(p + ".tmp", "w")); os.replace(p + ".tmp", p)
    except Exception:
        pass


def risk():
    return float(_load(CONF, {}).get("risk") or RISK)


def _head(text):
    L = (text or "").split("\n")
    h = L[0] if L else ""
    if h.startswith("🔔 OPENING · "):
        h = h[len("🔔 OPENING · "):]
    elif h.startswith("🔔 OPENING") and len(L) > 1:
        h = L[1]
    return h


def parse(text):
    """-> (sym, 'CE'/'PE', the share's stop or None) for a card-worthy alert, else None"""
    h = _head(text)
    if not CARD_RX.search(text or "") or SKIP_RX.search(text or "") or "🔕" in (text or ""):
        return None
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
    if not m:
        return None
    side = "CE" if m.group(1) == "▲" else "PE"
    if re.search(r"BUY PE", text) and side == "CE" or re.search(r"BUY CE", text) and side == "PE":
        return None
    st = re.search(r"stop:?\s*(?:a close\s*)?(?:under|over|below|above)\s*₹\s*([\d,]+(?:\.\d+)?)", text or "", re.I) or \
        re.search(r"out if it goes back\s*(?:under|over)\s*₹\s*([\d,]+(?:\.\d+)?)", text or "", re.I)
    return m.group(2), side, (float(st.group(1).replace(",", "")) if st else None)


# ---------------- the prices ----------------
def kite():
    if _K["k"] is not None and time.time() - _K["t"] < 3600:
        return _K["k"]
    if time.time() - _K["fail"] < 120:
        return None
    try:
        import core
        k = core.get_kite()
        try:
            k.timeout = 3
        except Exception:
            pass
        _K.update({"k": k, "t": time.time()})
        return k
    except Exception:
        _K["fail"] = time.time(); return None


def live():
    try:
        j = json.load(open(os.path.join(BASE, "quotes_live.json")))
        return j.get("q") or {} if time.time() - float(j.get("t") or 0) < 300 else {}
    except Exception:
        return {}


def _N(x):
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def trade_card(sym, side, ustop, now, k=None, M=None, q_live=None):
    """-> [lines] or [one line saying why there is no card]"""
    k = k if k is not None else kite()
    if k is None:
        return ["🎫 TRADE CARD: option prices not available right now (Zerodha did not answer) - take the strike nearest the price"]
    import posguard as PG
    M = M if M is not None else PG.instruments(k, now.date())
    opts = [(ts, v[1], v[2], v[4]) for ts, v in M.items() if v[0] == sym and v[3] == side and v[1] and v[1] >= str(now.date())]
    if not opts:
        return ["🎫 TRADE CARD: no %s options found for %s" % (side, sym)]
    exps = sorted({o[1] for o in opts})
    ex = next((e for e in exps if (dt.date.fromisoformat(e) - now.date()).days >= MIN_DAYS), exps[-1])
    days = (dt.date.fromisoformat(ex) - now.date()).days
    ql = (q_live if q_live is not None else live()).get(sym)
    spot = ql[0] if isinstance(ql, (list, tuple)) and ql else None
    row = sorted((o for o in opts if o[1] == ex), key=lambda o: o[2])
    if spot is None:
        try:
            spot = k.ltp(["NSE:" + sym])["NSE:" + sym]["last_price"]
        except Exception:
            return ["🎫 TRADE CARD: no live price for %s right now" % sym]
    i = min(range(len(row)), key=lambda j: abs(row[j][2] - spot))
    cand = [row[j] for j in (i, i - 1 if side == "CE" else i + 1, i + 1 if side == "CE" else i - 1) if 0 <= j < len(row)]
    try:
        Q = k.quote(["NFO:" + c[0] for c in cand] + ["NSE:" + sym])
    except Exception:
        return ["🎫 TRADE CARD: option prices not available right now - take the strike nearest the price"]
    spot = (Q.get("NSE:" + sym) or {}).get("last_price") or spot
    best = None
    for c in cand:
        x = Q.get("NFO:" + c[0]) or {}
        ltp = float(x.get("last_price") or 0)
        dp = x.get("depth") or {}
        ask = float(((dp.get("sell") or [{}])[0] or {}).get("price") or 0)
        bid = float(((dp.get("buy") or [{}])[0] or {}).get("price") or 0)
        prem = ask or ltp
        spread = (ask - bid) / ask * 100 if ask and bid else None
        oi = float(x.get("oi") or 0)
        if prem <= 0:
            continue
        ok = oi > 0 and (spread is None or spread <= 3.0)
        r = (ok, c, prem, spread, oi)
        if best is None or (ok and not best[0]):
            best = r
        if best[0] and best[1] is cand[0]:
            break
    if best is None:
        return ["🎫 TRADE CARD: no traded %s strike near ₹%s for %s" % (side, "{:,.0f}".format(spot), sym)]
    ok, (ts, ex, K, lot), P, spread, oi = best
    T = max((dt.datetime.combine(dt.date.fromisoformat(ex), dt.time(15, 30), IST) - now).total_seconds() / (365 * 86400), 1e-4)
    v = PG.iv(P, spot, K, T, side)
    d1 = (math.log(spot / K) + (PG.RATE + v * v / 2) * T) / (v * math.sqrt(T))
    delta = abs(_N(d1) if side == "CE" else _N(d1) - 1)
    if ustop and abs(spot - ustop) / spot < 0.1:
        pst = P - delta * abs(spot - ustop)
        why_st = "≈ the share back %s ₹%s" % ("under" if side == "CE" else "over", "{:,.2f}".format(ustop))
    else:
        pst, why_st = P * 0.75, "25% under the premium"
    pst = min(max(pst, P * 0.60), P * 0.85)
    ru = P - pst
    R = risk()
    lots = int(R // (ru * lot)) if ru * lot > 0 else 0
    dc = PG.decay(P, spot, K, ex, side, now)
    be = K + P if side == "CE" else K - P
    L = ["🎫 TRADE CARD · BUY %s %s %s · expiry %s (%d days)" % (sym, "{:g}".format(K), side, dt.date.fromisoformat(ex).strftime("%d %b"), days),
         "premium %s (%s%s) · lot %d · 1 lot %s%s" % (_inr(P, 2), "the ask" if spread is not None else "last trade", (" · spread %.1f%%" % spread) if spread is not None else "",
                                                     lot, _inr(P * lot), (" · OI %s" % ("{:,.0f}".format(oi))) if oi else "")]
    if lots >= 1:
        q = lots * lot
        L.append("your risk %s → %d lot%s = %s qty · cost %s" % (_inr(R), lots, "s" if lots > 1 else "", "{:,}".format(q), _inr(P * q)))
    else:
        q = lot
        L.append("1 lot risks %s - more than your %s: skip it, or 1 lot only if you accept that" % (_inr(ru * lot), _inr(R)))
    L += ["stop %s on the option (%s) · loss at the stop %s" % (_inr(pst, 2), why_st, _inr(ru * q)),
          "target 1 %s → book half (+%s) · target 2 %s (+%s) · then move the stop to your buy price" % (_inr(P + ru, 2), _inr(ru * q / 2), _inr(P + 2 * ru, 2), _inr(ru * q)),
          "time costs ≈ %s a unit a day (%s on %s qty) · breakeven at expiry %s" % (_inr(dc[1], 2) if dc else "-", _inr(dc[1] * q) if dc else "-", "{:,}".format(q), _inr(be, 2))]
    if not ok:
        L.append("⚠ thin trading in this strike (wide spread / no open interest) - use a limit order at the ask")
    return L


# ---------------- why / who / tide ----------------
def why_who(sym, side, q_live=None):
    d = 1 if side == "CE" else -1
    L = []
    try:
        import pushwho
        P = pushwho.read(sym)
        rows = [r for r in (P.get("rows") or []) if r.get("on") and r.get("t")]
        mine = [r for r in rows if r.get("side") in (d, 0)]
        against = [r for r in rows if r.get("side") == -d]
        if P.get("kline"):
            L.append("WHO: " + re.sub(r"^[🟢🔴🟡⚪]\s*", "", P["kline"])[:160])
        if mine:
            L.append("WHY: " + " · ".join("%s - %s" % (r.get("k", ""), r["t"]) for r in mine[:3])[:260])
        if against:
            L.append("AGAINST: " + " · ".join("%s - %s" % (r.get("k", ""), r["t"]) for r in against[:2])[:200])
    except Exception:
        pass
    if not any(x.startswith("WHY") for x in L):
        L.append("WHY: no news or filing found yet - the price and the money are the reason")
    try:
        import sectors
        q = q_live if q_live is not None else live()
        m = sectors.load()
        sec = next((s for s, v in m.items() if sym in v), None)
        tide = []
        if sec:
            ch = [q[s][1] for s in m[sec] if s != sym and isinstance(q.get(s), (list, tuple)) and len(q[s]) > 1 and q[s][1] is not None]
            if ch:
                tide.append("%s %+.1f%% (%d of %d up)" % (sec.upper(), sum(ch) / len(ch), sum(1 for c in ch if c > 0), len(ch)))
        for nk in ("NIFTY 50", "NIFTY"):
            n = q.get(nk)
            if isinstance(n, (list, tuple)) and len(n) > 1 and n[1] is not None:
                tide.append("NIFTY %+.1f%%" % n[1]); break
        if tide:
            L.append("TIDE: " + " · ".join(tide))
    except Exception:
        pass
    return L


def measured(text):
    for rx, w in MEASURED:
        if re.search(rx, text or ""):
            return "MEASURED: " + w
    return None


# ---------------- the card on the alert ----------------
def decorate(text, silent=False, now=None, k=None, M=None, q_live=None):
    now = now or dt.datetime.now(IST)
    day = str(now.date())
    st = _load(STATE, {})
    if st.get("day") != day:
        st = {"day": day, "cards": {}}
    p = parse(text)
    if p and not silent:
        sym, side, ust = p
        key = "%s:%s" % (sym, side)
        if key not in st["cards"]:
            q = q_live if q_live is not None else live()
            ql = q.get(sym)
            px = ql[0] if isinstance(ql, (list, tuple)) and ql else None
            L = ["", "🃏 MOVE CARD · %s %s %s · %s" % (sym, "▲" if side == "CE" else "▼", side, now.strftime("%H:%M"))] + why_who(sym, side, q)
            mz = measured(text)
            if mz:
                L.append(mz)
            try:
                L += [""] + trade_card(sym, side, ust, now, k, M, q)
            except Exception as ex:
                L += ["", "🎫 TRADE CARD: not ready (%s) - take the strike nearest the price" % str(ex)[:60]]
            st["cards"][key] = {"t": now.strftime("%H:%M"), "px": px}
            _save(STATE, st)
            return text.rstrip("\n") + "\n" + "\n".join(L)
    if "↳ follow-up" in (text or "") or "🃏 MOVE CARD" in (text or ""):
        return text
    h = _head(text)
    m = re.search(r"\b([A-Z][A-Z0-9&\-]{1,19})\b", re.sub(r"^[^A-Z]*", "", h))
    syms = set(re.findall(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)) or ({m.group(1)} if m else set())
    for key, c in st["cards"].items():
        s, side = key.split(":")
        if s in syms:
            q = q_live if q_live is not None else live()
            ql = q.get(s)
            now_px = ql[0] if isinstance(ql, (list, tuple)) and ql else None
            mv = ""
            if now_px and c.get("px"):
                ch = (now_px / c["px"] - 1) * 100 * (1 if side == "CE" else -1)
                mv = " · now ₹%s, %+.1f%% %s" % ("{:,.2f}".format(now_px), ch, "its way" if ch >= 0 else "against it")
            fl = "↳ follow-up to the %s MOVE CARD on %s (%s %s%s)%s" % (c["t"], s, "▲" if side == "CE" else "▼", side,
                                                                      (" at ₹%s" % "{:,.2f}".format(c["px"])) if c.get("px") else "", mv)
            L = text.split("\n")
            at = 1
            while at < len(L) and (L[at].startswith(TAGS) or (at == 1 and L[0].startswith("🔔 OPENING") and not L[0].startswith("🔔 OPENING · "))):
                at += 1
            return "\n".join(L[:at] + [fl] + L[at:])
    return text


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "risk" and len(a) == 2:
        c = _load(CONF, {}); c["risk"] = abs(float(a[1])); _save(CONF, c); print("risk a trade: ₹{:,.0f}".format(c["risk"]))
    elif a and a[0] == "try" and len(a) >= 3:                         # python3 movecard.py try SYM CE|PE [share stop] - the card now, nothing sent
        print("\n".join(why_who(a[1].upper(), a[2].upper()) + [""] + trade_card(a[1].upper(), a[2].upper(), float(a[3]) if len(a) > 3 else None, dt.datetime.now(IST))))
    else:
        print(__doc__)
PY_MC
cat > $W/p271_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p271_patch.py - patch 271: every sender's alertword.dress() adds the MOVE CARD + TRADE CARD (movecard.py) to a confirmed alert that rings,
and the "↳ follow-up" line to any later alert on that share.  python3 p271_patch.py DIR"""
import os, sys
D = sys.argv[1]
p = os.path.join(D, "alertword.py"); s = open(p, encoding="utf-8").read()
if "patch 271" in s:
    print("  alertword.py: patch 271 - already in"); sys.exit(0)
s = s.rstrip("\n") + '''


_dress271 = dress                                                  # patch 271: the MOVE CARD + TRADE CARD on a confirmed alert that rings


def dress(text):
    t, silent = _dress271(text)
    try:
        import movecard
        t = movecard.decorate(t, silent)
    except Exception:
        pass                                                         # never hold an alert up
    return t, silent
'''
open(p, "w", encoding="utf-8").write(s)
print("  alertword.py: every sender's alerts carry the MOVE CARD + TRADE CARD (confirmed, ringing) and the follow-up line")
print("patch 271 in")
PY_PATCH
cat > $W/p271test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p271test.py - MOVE CARD + TRADE CARD on made-up prices (a fake Zerodha, temp folder, nothing sent).  python3 p271test.py DIR"""
import os, sys, json, types, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("movecard.py", "posguard.py", "alertword.py"):
    if os.path.exists(os.path.join(SRC, f)):
        shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); os.chdir(T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime(2026, 11, 16, 9, 34, tzinfo=IST)
sys.modules["pushwho"] = types.SimpleNamespace(read=lambda s: {"kline": "🟢 ▲ NEW MONEY - long build-up ₹226 cr - futures OI +11.1%", "rows": [
    {"k": "FUTURES", "on": True, "side": 1, "t": "long build-up ₹226 cr · futures OI +11.1%"}, {"k": "COMPANY", "on": True, "side": 1, "t": "IRDAI may modify the draft (CNBC-TV18)"},
    {"k": "WRITERS", "on": True, "side": -1, "t": "writers building a roof at 1100"}]} if s == "POLICYBZR" else {"rows": []})
sys.modules["sectors"] = types.SimpleNamespace(load=lambda: {"insurance": ["POLICYBZR", "LICI", "SBILIFE", "HDFCLIFE"]})
Q = {"POLICYBZR": [1049.0, 4.2], "LICI": [900.0, 1.0], "SBILIFE": [1800.0, 0.5], "HDFCLIFE": [700.0, -0.2], "NIFTY 50": [25200.0, 0.3]}
import movecard as MC
M = {"POLICYBZR26NOV1040CE": ["POLICYBZR", "2026-11-24", 1040.0, "CE", 350], "POLICYBZR26NOV1060CE": ["POLICYBZR", "2026-11-24", 1060.0, "CE", 350],
     "POLICYBZR26NOV1050CE": ["POLICYBZR", "2026-11-24", 1050.0, "CE", 350], "POLICYBZR26NOV1050PE": ["POLICYBZR", "2026-11-24", 1050.0, "PE", 350],
     "POLICYBZR26NOV1050CEX": ["POLICYBZR", "2026-11-17", 1050.0, "CE", 350],
     "THIN26NOV100CE": ["THIN", "2026-11-24", 100.0, "CE", 1000], "THIN26NOV105CE": ["THIN", "2026-11-24", 105.0, "CE", 1000]}
def dq(ltp, bid, ask, oi):
    return {"last_price": ltp, "oi": oi, "depth": {"buy": [{"price": bid}], "sell": [{"price": ask}]}}
class K:
    calls = 0
    def quote(self, keys):
        K.calls += 1
        D = {"NFO:POLICYBZR26NOV1050CE": dq(36.0, 35.6, 36.2, 420000), "NFO:POLICYBZR26NOV1040CE": dq(42.0, 41.5, 42.3, 300000),
             "NFO:POLICYBZR26NOV1060CE": dq(31.0, 30.6, 31.2, 250000), "NSE:POLICYBZR": {"last_price": 1049.0},
             "NFO:THIN26NOV100CE": dq(4.0, 2.0, 5.0, 0), "NFO:THIN26NOV105CE": dq(2.0, 1.0, 3.0, 0), "NSE:THIN": {"last_price": 101.0}}
        return {k: D[k] for k in keys if k in D}
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:500]))
CF = "✅ CONFIRMED MOVE ▲ POLICYBZR · CE · 09:34\nthe morning sellers gave up: ₹1,040.40 → ₹1,049.00 in 14 min (0.8% the other way)\nfor you: CE, the strike nearest ₹1,049 · stay while the share holds above ₹1,049.00 · out if it goes back under ₹1,040.40"
chk("parse: POLICYBZR · CE · the share's stop ₹1,040.40", MC.parse(CF) == ("POLICYBZR", "CE", 1040.4), MC.parse(CF))
chk("not a card: an EXIT, a POSITION GUARD line, an EVENT WATCH, a 📊 RESULTS WEEK line, a held (🔕) one",
    not any(MC.parse(x) for x in ("🛑 EXIT ▲ POLICYBZR", "⚠ 🛡 POSITION GUARD · AGAINST YOU ▲ POLICYBZR CONFIRMED MOVE", "🚨 CRITICAL · 👁 EVENT WATCH ▲ POLICYBZR SPEED",
                                   "📊 RESULTS WEEK · DAY 3 SWING ▲ POLICYBZR RESULTS REACTION", "⚡ SPEED ▲ POLICYBZR\n🔕 no ring - why")))
out = MC.decorate(CF, False, NOW, K(), M, Q)
print("\n" + out + "\n")
chk("🃏 MOVE CARD under the alert: WHO (new money) · WHY (futures + the company news) · AGAINST (the writers' roof) · TIDE · MEASURED",
    "🃏 MOVE CARD · POLICYBZR ▲ CE · 09:34" in out and "WHO: ▲ NEW MONEY" in out and "WHY: FUTURES - long build-up" in out and "COMPANY - IRDAI" in out
    and "AGAINST: WRITERS" in out and "TIDE: INSURANCE +0.4% (2 of 3 up) · NIFTY +0.3%" in out and "13 of 15" in out, out)
chk("🎫 TRADE CARD: the 1050 CE (nearest ₹1,049, real trading) on the 24 Nov expiry (the 17 Nov one has 1 day - skipped)",
    "🎫 TRADE CARD · BUY POLICYBZR 1050 CE · expiry 24 Nov (8 days)" in out, out)
chk("... premium = the ask ₹36.20 · lot 350 · 1 lot ₹12,670", "premium ₹36.20 (the ask · spread 1.7%) · lot 350 · 1 lot ₹12,670" in out, out)
import re
m = re.search(r"stop ₹([\d.]+) on the option \(≈ the share back under ₹1,040.40\) · loss at the stop ₹([\d,]+)", out)
chk("... the stop on the option from the share's stop ₹1,040.40 (delta ~0.5 → about ₹4 lower)", m and 30.7 <= float(m.group(1)) <= 33.0, out)
lm = re.search(r"your risk ₹10,000 → (\d+) lots? = ([\d,]+) qty", out)
chk("... lots for ₹10,000 risk: the loss at the stop stays within ₹10,000", lm and m and int(m.group(2).replace(",", "")) <= 10000 and int(lm.group(1)) >= 1, out)
chk("... target 1 (book half) and 2, the time cost a day, the breakeven at expiry ₹1,086.20", "target 1 ₹" in out and "book half" in out and "time costs ≈ ₹" in out and "breakeven at expiry ₹1,086.20" in out, out)
SP = "⚡ SPEED ▲ POLICYBZR ₹1,060 +1.1% in 5 min · 09:52"
o2 = MC.decorate(SP, False, NOW.replace(minute=52), K(), M, dict(Q, POLICYBZR=[1060.0, 5.2]))
chk("the next alert on POLICYBZR the same side: no second card - '↳ follow-up to the 09:34 MOVE CARD ... now ₹1,060.00, +1.0% its way'",
    "🃏" not in o2 and "↳ follow-up to the 09:34 MOVE CARD on POLICYBZR (▲ CE at ₹1,049.00) · now ₹1,060.00, +1.0% its way" in o2, o2)
PB = "📉 PROFIT BOOKING ▼ POLICYBZR · 11:20\n🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR\nsellers at the top"
o3 = MC.decorate(PB, False, NOW.replace(hour=11, minute=20), K(), M, dict(Q, POLICYBZR=[1055.0, 4.8]))
chk("any later alert on it (profit booking) carries the follow-up line right under its head and tag", o3.split("\n")[2].startswith("↳ follow-up to the 09:34 MOVE CARD"), o3)
RR = "🚨 CRITICAL · RESULTS REACTION ▲ THIN · 10:05\n▶ BUY CE (at the money) - ▲ UP → CE · stop: a close under ₹99.00 (the first 5-min low)"
o4 = MC.decorate(RR, False, NOW.replace(hour=10, minute=5), K(), M, dict(Q, THIN=[101.0, 3.0]))
chk("a thin strike (wide spread, no open interest): the card warns 'use a limit order'", "thin trading" in o4, o4)
chk("a silent alert gets no card (no Zerodha call)", MC.decorate("⚡ SPEED ▲ LICI · 10:00", True, NOW, K(), M, Q) == "⚡ SPEED ▲ LICI · 10:00")
class Dead:
    def quote(self, keys): raise TimeoutError("no answer")
o5 = MC.decorate("✅ CONFIRMED MOVE ▼ SBILIFE · PE · 10:10", False, NOW.replace(hour=10, minute=10), Dead(), {"SBILIFE26NOV1800PE": ["SBILIFE", "2026-11-24", 1800.0, "PE", 375]}, Q)
chk("Zerodha does not answer: the alert still goes, the move card says the prices are not available", "🃏 MOVE CARD · SBILIFE ▼ PE" in o5 and "option prices not available" in o5, o5)
json.dump({"risk": 25000}, open(MC.CONF, "w"))
os.remove(MC.STATE)
o6 = MC.decorate(CF, False, NOW, K(), M, Q)
l6 = re.search(r"your risk ₹25,000 → (\d+) lots", o6)
chk("your risk set to ₹25,000 (python3 movecard.py risk 25000): more lots", l6 and lm and int(l6.group(1)) > int(lm.group(1)), (l6, lm))
src = open("movecard.py").read()
chk("read only: no order calls in the code", not any(w in src for w in ("place_order", "modify_order", "cancel_order")))
print("MOVE CARD + TRADE CARD test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p271int.py <<'PY_INT'
#!/usr/bin/env python3
"""p271int.py - the cards through GIR's own alertword.dress (temp copies, a fake Zerodha, nothing sent).  python3 p271int.py DIR"""
import os, sys, json, time, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "movecard.py", "posguard.py"):
    shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); os.chdir(T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); today = dt.datetime.now(IST).date()
exp = str(today + dt.timedelta(days=10))
M = {"POLICYBZR%sCE" % k: ["POLICYBZR", exp, float(k), "CE", 350] for k in (1040, 1050, 1060)}
json.dump({"day": str(today), "m": M}, open(os.path.join(T, "data", "nfo_instr.json"), "w"))
json.dump({"t": time.time(), "q": {"POLICYBZR": [1049.0, 4.2]}}, open(os.path.join(T, "quotes_live.json"), "w"))
class K:
    def quote(self, keys):
        d = lambda l, b, a, oi: {"last_price": l, "oi": oi, "depth": {"buy": [{"price": b}], "sell": [{"price": a}]}}
        D = {"NFO:POLICYBZR1050CE": d(36.0, 35.6, 36.2, 420000), "NFO:POLICYBZR1040CE": d(42.0, 41.5, 42.3, 300000), "NFO:POLICYBZR1060CE": d(31.0, 30.6, 31.2, 250000),
             "NSE:POLICYBZR": {"last_price": 1049.0}}
        return {k: D[k] for k in keys if k in D}
import movecard as MC, alertword as A
MC._K.update({"k": K(), "t": time.time(), "fail": 0.0})
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
CF = "✅ CONFIRMED MOVE ▲ POLICYBZR · CE · 09:34\nthe morning sellers gave up\nfor you: CE · out if it goes back under ₹1,040.40"
t, silent = A.dress(CF)
chk("GIR's own dress(): a ringing CONFIRMED MOVE comes out with its tag, the MOVE CARD and the TRADE CARD", not silent and t.split("\n")[0] == CF.split("\n")[0]
    and "🃏 MOVE CARD · POLICYBZR ▲ CE" in t and "🎫 TRADE CARD · BUY POLICYBZR 1050 CE" in t, t)
chk("the head line stays first (the NOW list reads it)", t.split("\n")[0] == "✅ CONFIRMED MOVE ▲ POLICYBZR · CE · 09:34", t.split("\n")[0])
t2, s2 = A.dress("🌅 OPENING CALL ▼ LICI PE · GO · 09:20")
chk("a silent alert (an opening call) is untouched", s2 and "🃏" not in t2, t2)
import movecard
movecard.decorate = lambda *a, **k: 1 / 0
t3, s3 = A.dress(CF.replace("POLICYBZR", "SBILIFE"))
chk("if the card breaks, the alert still goes out (as before)", "SBILIFE" in t3 and not s3, t3)
print("THE CARDS IN GIR'S ALERTS test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_INT
python3 $W/p271_patch.py $D || back
cd $D && python3 -m py_compile movecard.py alertword.py || back
echo "=== test"
python3 $W/p271test.py $D | grep -v "^[A-Z🃏🎫✅]\|^$\|^the \|^for \|^premium\|^your\|^stop\|^target\|^time" || true
python3 $W/p271test.py $D >/dev/null 2>&1 || back
python3 $W/p271int.py $D || back
chown --reference=$D $D/movecard.py 2>/dev/null
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "=== a card on POLICYBZR right now, with real Zerodha prices (read only - nothing sent; on a weekend Zerodha may not answer)"
(cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 40 python3 movecard.py try POLICYBZR CE 1040) 2>&1 | tail -12
echo "✅ patch 271 done - from Monday every confirmed alert carries the 🃏 MOVE CARD and the 🎫 TRADE CARD; later alerts on that share say '↳ follow-up'."
echo "   your risk a trade: ₹10,000 (change: cd $D && python3 movecard.py risk 15000)"
echo "   undo: cp $D/alertword.py.bak$TS $D/alertword.py; systemctl restart $SV"
