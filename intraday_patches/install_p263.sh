#!/bin/bash
# PATCH 263 - 🛡 POSITION GUARD: GIR watches YOUR trades (Rama, 14 Nov: "yes, the same Zerodha account"). READ ONLY - it never places, changes or
#   cancels an order. Every minute 09:15-15:30 it reads the account's open F&O positions and rings GIR Box Picks (always with sound):
#   WRONG SIDE (incl. "check this order" 2 min after a buy against GIR's call) · FLIP after a loss on the same share · FAR OUT OF THE MONEY ·
#   STOP (yours, or 30% under the buy) · BOOK HALF at +50% · DAILY LOSS LIMIT (₹20,000 unless set) · GIVING IT BACK · 09:16 the overnight
#   positions · 15:00 hold overnight or exit (days to expiry, the time cost, results tomorrow, GIR's call).
#   Your stop for POLICYBZR 1100 CE (₹35) is set. Change: python3 posguard.py stop SYMBOL PRICE · limit: python3 posguard.py limit AMOUNT
#   Tested: 18 cases on a fake account. Adds its own timer only - nothing else restarts. Safe any time.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; W=$(mktemp -d)
[ -f $D/core.py ] || { echo "GIR's core.py not found"; exit 1; }
[ -f $D/posguard.py ] && cp $D/posguard.py $D/posguard.py.bak$(date +%m%d%H%M%S)
back(){ systemctl disable --now gir-posguard.timer 2>/dev/null; rm -f $U/gir-posguard.service $U/gir-posguard.timer; systemctl daemon-reload; echo "❌ removed again - nothing else was touched"; exit 1; }
cat > $D/posguard.py <<'PY_PG'
#!/usr/bin/env python3
"""posguard.py - patch 263: 🛡 POSITION GUARD - GIR watches YOUR trades, not only the market (Rama, 14 Nov: "yes, the same Zerodha account").
Reads the account's open positions every minute 09:15-15:30 (READ ONLY - it never places, changes or cancels an order) and rings GIR Box Picks:
  WRONG SIDE   you hold CE while GIR's latest confirmed call on that share is PE (or PE vs CE) - and a position bought in the last 2 minutes
               against GIR's call: "check you did not tap the wrong one" (13 Nov: a CE bought instead of the PE)
  FLIP         you take the other side on a share you already lost on today (the costliest pattern in the June-November statement)
  FAR OTM      a new option more than 6% out of the money (cheap far-out options lost money in the June-November statement)
  STOP         the option at your stop (python3 posguard.py stop SYMBOL PRICE) or 30% under your buy price · BOOK HALF at +50%
  DAY LIMIT    the day's P&L at your loss limit (python3 posguard.py limit AMOUNT; ₹20,000 unless set): "stop trading for today"
  GIVE-BACK    the day's profit was ₹10,000+ and half of it is gone
  09:16        the positions you carried overnight, with their stops
  15:00        each open option: days to expiry, what time costs it tomorrow, results / events tomorrow, GIR's view -> HOLD or EXIT
  python3 posguard.py show | stop SYM PRICE | limit AMOUNT | run [--send]"""
import os, re, sys, json, math, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
CONF = os.path.join(BASE, "data", "posguard.json")
STATE = os.path.join(BASE, "data", "posguard_state.json")
INSTR = os.path.join(BASE, "data", "nfo_instr.json")
LIMIT, STOP_PCT, BOOK_PCT, OTM_PCT, GIVE_MIN, NEW_S, CALL_S, RATE = 20000.0, 30.0, 50.0, 6.0, 10000.0, 150, 3600, 0.065
SYMRX = re.compile(r"^([A-Z][A-Z0-9&\-]*?)(\d{2}(?:[A-Z]{3}|[1-9OND]\d{2}))([\d.]+)(CE|PE)$")
IDX = {"NIFTY": "NIFTY 50", "BANKNIFTY": "NIFTY BANK", "FINNIFTY": "NIFTY FIN SERVICE", "MIDCPNIFTY": "NIFTY MID SELECT"}
CALLRX = re.compile(r"RESULTS REACTION|CONFIRMED MOVE|\bSPEED\b|🔴 TRADE ALERT")


def _inr(x):
    x = float(x)
    return ("-" if x < 0 else "") + "₹{:,.0f}".format(abs(x)) if abs(x) >= 100 else "₹{:,.2f}".format(x)


def _load(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def _save(p, v):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(v, open(p + ".tmp", "w"), default=str); os.replace(p + ".tmp", p)


def conf():
    c = _load(CONF, {})
    c.setdefault("stops", {}); c.setdefault("limit", LIMIT)
    return c


# ---------------- the option behind a position ----------------
def instruments(kite, today):
    """{tradingsymbol: [underlying, expiry, strike, CE/PE, lot]} - NFO, read once a day"""
    j = _load(INSTR, {})
    if j.get("day") == str(today) and j.get("m"):
        return j["m"]
    m = {}
    try:
        for r in kite.instruments("NFO"):
            if r.get("instrument_type") in ("CE", "PE"):
                m[r["tradingsymbol"]] = [r.get("name"), str(r.get("expiry"))[:10], float(r.get("strike") or 0), r["instrument_type"], int(r.get("lot_size") or 0)]
        _save(INSTR, {"day": str(today), "m": m})
    except Exception:
        m = j.get("m") or {}
    return m


def opt_of(ts, M):
    """-> (underlying, expiry 'YYYY-MM-DD' or None, strike, 'CE'/'PE') or None"""
    if ts in M:
        u, e, k, t, _l = M[ts]
        return u, e, k, t
    m = SYMRX.match(ts or "")
    return (m.group(1), None, float(m.group(3)), m.group(4)) if m else None


# ---------------- the time cost (Black-Scholes) ----------------
def _N(x):
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def bs(S, K, T, v, typ):
    if T <= 0 or v <= 0:
        return max(0.0, S - K) if typ == "CE" else max(0.0, K - S)
    d1 = (math.log(S / K) + (RATE + v * v / 2) * T) / (v * math.sqrt(T)); d2 = d1 - v * math.sqrt(T)
    if typ == "CE":
        return S * _N(d1) - K * math.exp(-RATE * T) * _N(d2)
    return K * math.exp(-RATE * T) * _N(-d2) - S * _N(-d1)


def iv(P, S, K, T, typ):
    lo, hi = 0.01, 4.0
    if P <= bs(S, K, T, lo, typ):
        return lo
    for _ in range(60):
        mid = (lo + hi) / 2
        if bs(S, K, T, mid, typ) > P:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def decay(P, S, K, expiry, typ, now):
    """-> (days left, ₹ a unit time takes by tomorrow, time value now) or None"""
    try:
        ex = dt.datetime.combine(dt.date.fromisoformat(expiry), dt.time(15, 30), IST)
    except Exception:
        return None
    T = (ex - now).total_seconds() / (365 * 86400)
    if T <= 0 or not (P and S and K):
        return None
    v = iv(P, S, K, T, typ)
    T1 = max(0.0, T - 1 / 365.0)
    intrinsic = max(0.0, S - K) if typ == "CE" else max(0.0, K - S)
    return (ex.date() - now.date()).days, max(0.0, bs(S, K, T, v, typ) - bs(S, K, T1, v, typ)), max(0.0, P - intrinsic)


# ---------------- GIR's view ----------------
def gir_calls(day, since_t=0):
    """{SYM: (epoch, +1 CE / -1 PE, head)} - GIR's latest confirmed (ringing) call per share today"""
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=3)
        rows = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall()
        c.close()
    except Exception:
        return out
    for t, sym, tx in rows:
        L = (tx or "").split("\n")
        h = L[0] if L else ""
        if not CALLRX.search(tx or "") or "🔕" in (tx or "") or "EVENT WATCH" in h or "not a buy" in (tx or ""):
            continue
        d = 1 if ("▲" in h or "BUY CE" in (tx or "") or "· CE" in h) else (-1 if ("▼" in h or "BUY PE" in (tx or "") or "· PE" in h) else 0)
        m = re.search(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
        s = (m.group(1) if m else (sym or "")).upper()
        if not s or not d:
            continue
        try:
            te = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
        except Exception:
            continue
        if te >= since_t:
            out[s] = (te, d, h[:90])
    return out


def results_soon(syms, nxt):
    out = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)
        for s in syms:
            r = c.execute("select min(d) from results_cal where sym=? and d>=? and d<=?", (s, nxt[0], nxt[1])).fetchone()
            if r and r[0]:
                out[s] = r[0]
        c.close()
    except Exception:
        pass
    return out


# ---------------- one look ----------------
def check(now, kite, send=None, M=None):
    """-> [texts]"""
    hm, day = now.strftime("%H:%M"), str(now.date())
    if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
        return []
    C = conf()
    st = _load(STATE, {})
    if st.get("day") != day:
        st = {"day": day, "said": [], "qty": st.get("qty") if st.get("day") else {}, "peak": 0.0, "first": {}, "lost": {}}
    said = set(st["said"])
    M = M if M is not None else instruments(kite, now.date())
    try:
        P = kite.positions().get("net") or []
    except Exception as ex:
        print("positions: %s" % str(ex)[:80]); return []
    pos = [p for p in P if p.get("exchange") in ("NFO", "BFO")]
    out = []

    def say(key, txt):
        if key not in said:
            said.add(key); out.append(txt)

    opens, unders = [], set()
    for p in pos:
        o = opt_of(p.get("tradingsymbol"), M)
        if not o:
            continue
        q = int(p.get("quantity") or 0)
        if q:
            opens.append((p, o, q)); unders.add(o[0])
        else:                                                          # closed today: remember a loss on that share and side
            r = float(p.get("pnl") or 0)
            if r < 0:
                st["lost"].setdefault(o[0], [o[3], r])
    spot = {}
    try:
        keys = ["NSE:" + IDX.get(u, u) for u in unders]
        if keys:
            L = kite.ltp(keys)
            spot = {u: (L.get("NSE:" + IDX.get(u, u)) or {}).get("last_price") for u in unders}
    except Exception:
        pass
    calls = gir_calls(day, now.timestamp() - CALL_S)
    t = now.timestamp()
    day_pl = sum(float(p.get("m2m") if p.get("m2m") is not None else (p.get("pnl") or 0)) for p in pos)

    # 09:16 - what you carried overnight
    if not st.get("morning") and opens:
        st["morning"] = True
        L = ["🛡 POSITION GUARD · %s · your open positions" % hm]
        for p, o, q in opens:
            ts = p["tradingsymbol"]; avg = float(p.get("average_price") or 0); ltp = float(p.get("last_price") or 0)
            stp = C["stops"].get(ts) or round(avg * (1 - STOP_PCT / 100), 2)
            L.append("• %s · %s qty · bought %s · now %s (%+.0f%%) · stop %s%s" % (ts, q, _inr(avg), _inr(ltp), (ltp / avg - 1) * 100 if avg else 0,
                     _inr(stp), " (yours)" if ts in C["stops"] else " (30% under your buy - set yours: posguard.py stop)"))
        L.append("GIR rings here when: the stop is hit · GIR's call turns against you · the day's loss reaches %s" % _inr(C["limit"]))
        out.append("\n".join(L))

    for p, o, q in opens:
        ts = p["tradingsymbol"]; u, ex, K, typ = o
        side = (1 if typ == "CE" else -1) * (1 if q > 0 else -1)            # a sold CE is a bet on the fall
        avg = float(p.get("average_price") or 0); ltp = float(p.get("last_price") or 0)
        prev = (st.get("qty") or {}).get(ts, 0)
        new = (abs(q) > abs(prev)) and st.get("seen_once")
        if new:
            st["first"][ts] = t
        fresh = t - st["first"].get(ts, 0) <= NEW_S
        g = calls.get(u)
        if g and g[1] != side:
            if fresh:
                say("wrong-new:%s:%d" % (ts, g[0]), "⚠ 🛡 POSITION GUARD · CHECK THIS ORDER · %s\nyou just bought %s - a bet that %s goes %s\nGIR's call on %s at %s was %s (%s)\n"
                    "if you tapped the wrong one, exit now while the loss is small" % (hm, ts, u, "UP" if side > 0 else "DOWN", u,
                    dt.datetime.fromtimestamp(g[0], IST).strftime("%H:%M"), "▲ CE" if g[1] > 0 else "▼ PE", g[2]))
            else:
                say("wrong:%s:%d" % (ts, g[0]), "⚠ 🛡 POSITION GUARD · AGAINST YOU · %s\nyou hold %s (%s) - GIR's call on %s at %s is %s\n%s\nnow %s (%+.0f%% from your %s) · protect it: exit, or tighten the stop" % (
                    hm, ts, "▲ CE side" if side > 0 else "▼ PE side", u, dt.datetime.fromtimestamp(g[0], IST).strftime("%H:%M"),
                    "▲ CE" if g[1] > 0 else "▼ PE", g[2], _inr(ltp), (ltp / avg - 1) * 100 if avg else 0, _inr(avg)))
        lost = st["lost"].get(u)
        if new and lost and lost[0] != typ:
            say("flip:%s" % ts, "⚠ 🛡 POSITION GUARD · FLIP · %s\nyou lost %s on %s %s today and now hold %s - the other side\nthe second trade is usually the loss trying to win itself back - "
                "your statement shows it as the costliest habit\nare you following a GIR call, or the loss?" % (hm, _inr(lost[1]), u, lost[0], ts))
        S = spot.get(u)
        if new and S and K and q > 0:
            otm = ((K / S - 1) * 100) if typ == "CE" else ((1 - K / S) * 100)
            if otm > OTM_PCT:
                say("otm:%s" % ts, "⚠ 🛡 POSITION GUARD · FAR OUT OF THE MONEY · %s\n%s is %.0f%% away from %s (₹%s) - it needs a big move just to be worth something at expiry\n"
                    "cheap far-out options lost money in your June-November statement - the strike nearest the price works better" % (hm, ts, otm, u, "{:,.1f}".format(S)))
        if q > 0 and avg and ltp:
            stp = C["stops"].get(ts) or avg * (1 - STOP_PCT / 100)
            if ltp <= stp:
                say("stop:%s" % ts, "🛑 🛡 POSITION GUARD · STOP · %s\n%s at %s - your stop %s%s\nloss now %s on %s qty · exit: the plan said out here" % (
                    hm, ts, _inr(ltp), _inr(stp), " (yours)" if ts in C["stops"] else " (30% under your buy)", _inr((ltp - avg) * q), q))
            elif ltp >= avg * (1 + BOOK_PCT / 100):
                say("book:%s" % ts, "🎯 🛡 POSITION GUARD · BOOK HALF · %s\n%s at %s, +%.0f%% on your %s · profit %s on %s qty\nbook half now, keep the rest with the stop at your buy price %s" % (
                    hm, ts, _inr(ltp), (ltp / avg - 1) * 100, _inr(avg), _inr((ltp - avg) * q), q, _inr(avg)))

    st["peak"] = max(st.get("peak") or 0.0, day_pl)
    if day_pl <= -abs(C["limit"]):
        say("limit", "🛑 🛡 POSITION GUARD · DAILY LOSS LIMIT · %s\ntoday %s - your limit is %s\nSTOP TRADING FOR TODAY. Close what is open with its stop; no new trades. Tomorrow is a new day." % (
            hm, _inr(day_pl), _inr(C["limit"])))
    elif st["peak"] >= GIVE_MIN and day_pl <= st["peak"] / 2:
        say("give", "⚠ 🛡 POSITION GUARD · GIVING IT BACK · %s\ntoday was %s at best, now %s - half the day's profit is gone\nbook what is left, or stop the open trades at break-even" % (
            hm, _inr(st["peak"]), _inr(day_pl)))

    # 15:00 - hold overnight or exit
    if hm >= "15:00" and not st.get("eod") and any(q > 0 for _p, _o, q in opens):
        st["eod"] = True
        nd = now.date() + dt.timedelta(days=1)
        while nd.weekday() > 4:
            nd += dt.timedelta(days=1)
        rs = results_soon([o[0] for _p, o, _q in opens], (str(nd), str(nd)))
        allday = gir_calls(day, 0)                                     # GIR's latest call of the whole day
        L = ["🛡 POSITION GUARD · 15:00 · hold overnight or exit?"]
        for p, o, q in opens:
            if q <= 0:
                continue
            ts = p["tradingsymbol"]; u, ex, K, typ = o
            avg = float(p.get("average_price") or 0); ltp = float(p.get("last_price") or 0)
            side = 1 if typ == "CE" else -1
            dc = decay(ltp, spot.get(u), K, ex, typ, now) if ex else None
            g = allday.get(u)
            why = []
            if dc:
                why.append("%d days to expiry · time costs about %s a unit by tomorrow (%s on your %s qty) · %.0f%% of the price is time" % (
                    dc[0], _inr(dc[1]), _inr(dc[1] * q), q, 100 * dc[2] / ltp if ltp else 0))
            if u in rs:
                why.append("results tomorrow - holding is a bet on the number")
            if g:
                why.append("GIR's call today: %s at %s" % ("▲ CE" if g[1] > 0 else "▼ PE", dt.datetime.fromtimestamp(g[0], IST).strftime("%H:%M")))
            exit_ = (g and g[1] != side) or (dc and dc[0] <= 2 and ltp and dc[2] / ltp > 0.5) or (u in rs)
            stp = C["stops"].get(ts) or avg * (1 - STOP_PCT / 100)
            L.append("• %s · now %s (%+.0f%%) · P&L %s\n  %s\n  → %s" % (ts, _inr(ltp), (ltp / avg - 1) * 100 if avg else 0, _inr((ltp - avg) * q),
                     " · ".join(why) or "-", "EXIT before the close" if exit_ else "HOLD with the stop %s" % _inr(stp)))
        out.append("\n".join(L))

    st["qty"] = {p["tradingsymbol"]: int(p.get("quantity") or 0) for p in pos}
    st["seen_once"] = True
    st["said"] = sorted(said)
    _save(STATE, st)
    if send:
        for x in out:
            send(x)
    return out


def send_box(text):
    """straight to GIR Box Picks, always with sound (your money - never held by the ring rules)"""
    tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
    chat = os.environ.get("TG_CHAT_BOX")
    try:
        import opencall
        opencall.log_alert(text)
    except Exception:
        pass
    if not tok or not chat:
        print("no Telegram token / chat:\n" + text); return False
    import requests
    a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
    d = {"chat_id": a, "text": text, "disable_notification": "false"}
    if b:
        d["message_thread_id"] = b
    for _ in range(3):
        try:
            if requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=30).ok:
                return True
        except Exception:
            pass
        time.sleep(2)
    return False


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "stop" and len(a) == 3:
        c = conf(); c["stops"][a[1].upper()] = float(a[2]); _save(CONF, c); print("stop for %s: ₹%s" % (a[1].upper(), a[2]))
    elif a and a[0] == "limit" and len(a) == 2:
        c = conf(); c["limit"] = abs(float(a[1])); _save(CONF, c); print("daily loss limit: ₹{:,.0f}".format(c["limit"]))
    elif a and a[0] == "show":
        c = conf(); print("daily loss limit: ₹{:,.0f}".format(c["limit"])); [print("stop %s: ₹%s" % kv) for kv in c["stops"].items()]
        try:
            import core
            k = core.get_kite()
            P = [p for p in (k.positions().get("net") or []) if p.get("quantity")]
            print("open positions in the account: %d" % len(P))
            for p in P:
                print("  %-26s qty %6s · avg %8.2f · now %8.2f · P&L %10.0f" % (p["tradingsymbol"], p["quantity"], p["average_price"], p["last_price"], p.get("pnl") or 0))
        except Exception as ex:
            print("the account could not be read now (%s) - GIR's Zerodha login is renewed each trading morning" % str(ex)[:90])
    elif a and a[0] == "run":
        now = dt.datetime.now(IST)
        if now.weekday() > 4 or not ("09:15" <= now.strftime("%H:%M") <= "15:30"):
            sys.exit(0)
        try:
            import core
            kite = core.get_kite()
        except Exception as ex:
            print("%s the account could not be read: %s" % (now.strftime("%H:%M:%S"), str(ex)[:100])); sys.exit(0)
        out = check(now, kite, send_box if "--send" in a else None)
        print("\n\n".join(out) if out else "(nothing to say)")
    else:
        print(__doc__)
PY_PG
cat > $W/p263test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p263test.py - the POSITION GUARD on made-up positions (a fake Kite: nothing read from or sent to Zerodha / Telegram).  python3 p263test.py DIR"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "posguard.py"), T)
sys.path.insert(0, T); os.chdir(T)
import posguard as PG
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
mon = lambda h, m: dt.datetime(2026, 11, 16, h, m, tzinfo=IST)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
c = sqlite3.connect("tomorrow.db"); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)"); c.commit()
c2 = sqlite3.connect("chains.db"); c2.execute("create table results_cal(sym text, d text)"); c2.execute("insert into results_cal values ('DIVISLAB', '2026-11-17')"); c2.commit(); c2.close()
def alert(t, sym, text):
    c.execute("insert into alerts values ('2026-11-16', ?, '', ?, '', ?)", (t, sym, text)); c.commit()
M = {"POLICYBZR26NOV1100CE": ["POLICYBZR", "2026-11-24", 1100.0, "CE", 350], "GRASIM26NOV3100CE": ["GRASIM", "2026-11-24", 3100.0, "CE", 250],
     "GRASIM26NOV3020PE": ["GRASIM", "2026-11-24", 3020.0, "PE", 250], "AMBER26NOV7500CE": ["AMBER", "2026-11-24", 7500.0, "CE", 100],
     "DIVISLAB26NOV6600CE": ["DIVISLAB", "2026-11-24", 6600.0, "CE", 100], "SBIN26NOV1000CE": ["SBIN", "2026-11-24", 1000.0, "CE", 750]}
class Kite:
    def __init__(s): s.P, s.S = [], {}
    def positions(s): return {"net": s.P, "day": []}
    def ltp(s, keys): return {k: {"last_price": s.S.get(k.split(":")[1])} for k in keys}
    def instruments(s, ex): return []
K = Kite()
def pos(ts, q, avg, ltp, pnl=None, m2m=None):
    return {"tradingsymbol": ts, "exchange": "NFO", "quantity": q, "average_price": avg, "last_price": ltp, "pnl": (ltp - avg) * q if pnl is None else pnl,
            "m2m": (ltp - avg) * q if m2m is None else m2m}
run = lambda t: PG.check(t, K, M=M)
json.dump({"stops": {"POLICYBZR26NOV1100CE": 35.0}, "limit": 20000}, open(PG.CONF, "w"))
# Monday 09:15 - the overnight POLICYBZR CE
K.P = [pos("POLICYBZR26NOV1100CE", 3850, 48.30, 50.0, m2m=0)]; K.S = {"POLICYBZR": 1085.0}
r = run(mon(9, 15))
chk("09:15 the overnight positions: POLICYBZR 1100 CE 3,850 qty, your stop ₹35", len(r) == 1 and "your open positions" in r[0] and "3850 qty" in r[0] and "stop ₹35.00 (yours)" in r[0], r)
chk("said once", run(mon(9, 16)) == [])
K.P = [pos("POLICYBZR26NOV1100CE", 3850, 48.30, 34.9, m2m=-50000)]
r = run(mon(9, 20))
chk("CE at ₹34.90 - under your ₹35: 🛑 STOP, loss ₹51,590", any("🛑 🛡 POSITION GUARD · STOP" in x and "₹34.90" in x and "-₹51,590" in x for x in r), r)
chk("day -₹50,000 vs the ₹20,000 limit: 🛑 DAILY LOSS LIMIT - stop trading for today", any("DAILY LOSS LIMIT" in x and "STOP TRADING FOR TODAY" in x for x in r), r)
chk("each said once", run(mon(9, 21)) == [])
# GIR turns against a held position
K.P = [pos("POLICYBZR26NOV1100CE", 3850, 48.30, 40.0, m2m=-30000)]
alert("10:02:10", "POLICYBZR", "🚨 CRITICAL · RESULTS REACTION ▼ POLICYBZR · 10:02\n▶ BUY PE (at the money)")
r = run(mon(10, 3))
chk("GIR's ▼ PE call at 10:02 on a CE you hold: ⚠ AGAINST YOU", any("AGAINST YOU" in x and "POLICYBZR26NOV1100CE" in x and "▼ PE" in x for x in r), r)
alert("10:20:00", "SBIN", "⚡ SPEED ▼ SBIN ₹990 -1.3% in 5 min · 10:20\n🔕 no ring - why: once a share in 15 min")
alert("10:21:00", "AMBER", "👁 EVENT WATCH ▼ AMBER · 10:21 · an eye on it, not a buy call")
alert("10:22:00", "AMBER", "🌅 OPENING CALL ▼ AMBER PE")
chk("a held-back (🔕) call, an EVENT WATCH or an OPENING CALL is not GIR's call", "SBIN" not in PG.gir_calls("2026-11-16") and "AMBER" not in PG.gir_calls("2026-11-16"), PG.gir_calls("2026-11-16"))
# the wrong tap: CE bought right after GIR said PE
alert("13:52:00", "GRASIM", "✅ CONFIRMED MOVE ▼ GRASIM · PE · 13:52")
K.P.append(pos("GRASIM26NOV3100CE", 1250, 60.0, 59.0)); K.S["GRASIM"] = 3050.0
r = run(mon(13, 54))
chk("13:54 GRASIM CE bought 2 min after GIR's ▼ PE: ⚠ CHECK THIS ORDER - 'tapped the wrong one'", any("CHECK THIS ORDER" in x and "GRASIM26NOV3100CE" in x and "wrong one" in x for x in r), r)
# a flip after a loss
K.P = [pos("GRASIM26NOV3100CE", 0, 60.0, 40.0, pnl=-25000), pos("POLICYBZR26NOV1100CE", 3850, 48.30, 40.0, m2m=-30000)]
run(mon(14, 0))
K.P.append(pos("GRASIM26NOV3020PE", 1250, 45.0, 45.0))
r = run(mon(14, 2))
chk("14:02 GRASIM PE after losing ₹25,000 on its CE today: ⚠ FLIP", any("FLIP" in x and "-₹25,000" in x and "GRASIM26NOV3020PE" in x for x in r), r)
# far out of the money
K.P.append(pos("AMBER26NOV7500CE", 500, 9.0, 9.0)); K.S["AMBER"] = 6800.0
r = run(mon(14, 5))
chk("AMBER 7500 CE with AMBER at ₹6,800 (10% away): ⚠ FAR OUT OF THE MONEY", any("FAR OUT OF THE MONEY" in x and "10% away" in x for x in r), r)
# book half
K.P.append(pos("DIVISLAB26NOV6600CE", 600, 100.0, 100.0)); K.S["DIVISLAB"] = 6650.0
run(mon(14, 10))
for p in K.P:
    if p["tradingsymbol"] == "DIVISLAB26NOV6600CE":
        p["last_price"] = 152.0
r = run(mon(14, 20))
chk("DIVISLAB CE +52% on your ₹100: 🎯 BOOK HALF", any("BOOK HALF" in x and "+52%" in x for x in r), r)
# 15:00 - hold or exit
r = run(mon(15, 0))
e = next((x for x in r if "15:00" in x), "")
chk("15:00 card: every open option with days to expiry and the time cost", "hold overnight or exit" in e and "8 days to expiry" in e and "time costs about" in e, e)
chk("... POLICYBZR: GIR's call today ▼ PE against your CE -> EXIT", "POLICYBZR26NOV1100CE" in e and e.split("POLICYBZR26NOV1100CE")[1].split("•")[0].count("EXIT before the close") == 1, e)
chk("... DIVISLAB: results tomorrow -> EXIT ('a bet on the number')", "results tomorrow" in e and e.split("DIVISLAB26NOV6600CE")[1].split("•")[0].count("EXIT") == 1, e)
print("\n" + e + "\n")
# give-back
json.dump({"stops": {}, "limit": 50000}, open(PG.CONF, "w"))
os.remove(PG.STATE)
tue = lambda h, m: dt.datetime(2026, 11, 17, h, m, tzinfo=IST)
K.P = [pos("SBIN26NOV1000CE", 750, 10.0, 30.0)]; K.S = {"SBIN": 1010.0}
run(tue(10, 0))
K.P = [pos("SBIN26NOV1000CE", 750, 10.0, 18.0)]
r = run(tue(11, 0))
chk("the day was +₹15,000, now +₹6,000: ⚠ GIVING IT BACK", any("GIVING IT BACK" in x for x in r), r)
chk("after 15:30 and on a Saturday: nothing", run(tue(15, 40)) == [] and run(dt.datetime(2026, 11, 21, 11, 0, tzinfo=IST)) == [])
d = PG.decay(48.3, 1085.0, 1100.0, "2026-11-24", "CE", mon(10, 0))
chk("the time cost (Black-Scholes): POLICYBZR 1100 CE at ₹48.30, 8 days - about ₹%.2f a day" % (d[1] if d else 0), d and 1.0 < d[1] < 6.0, d)
chk("it never places an order (no place_order / modify / cancel in the code)", not any(w in open("posguard.py").read() for w in ("place_order", "modify_order", "cancel_order")))
print("POSITION GUARD test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cd $D && python3 -m py_compile posguard.py || back
echo "=== test"
python3 $W/p263test.py $D || back
mkdir -p $D/data
[ -f $D/data/posguard.json ] || echo '{"stops": {"POLICYBZR26NOV1100CE": 35.0}, "limit": 20000}' > $D/data/posguard.json
chown -R --reference=$D $D/posguard.py $D/data/posguard.json 2>/dev/null
cat > $U/gir-posguard.service <<'UNIT'
[Unit]
Description=GIR POSITION GUARD - reads the account's positions (read only), rings on stop / wrong side / loss limit
[Service]
Type=oneshot
TimeoutStartSec=50
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 posguard.py run --send >> data/posguard.log 2>&1'
UNIT
cat > $U/gir-posguard.timer <<'UNIT'
[Unit]
Description=GIR POSITION GUARD, every minute 09:15-15:30 trading days
[Timer]
OnCalendar=Mon..Fri *-*-* 09..15:*:20 Asia/Kolkata
AccuracySec=5s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-posguard.timer >/dev/null 2>&1 || back
echo "  position guard: $(systemctl is-enabled gir-posguard.timer)"
echo "=== your account now (read only - Zerodha renews GIR's login each trading morning; on a weekend it may say the login is old)"
(cd /home/globalbot && set -a && . ./.env && set +a && cd $D && timeout 60 python3 posguard.py show) 2>&1 | tail -12
echo "✅ patch 263 done - from Monday 09:15 the POSITION GUARD watches your trades. Stop for POLICYBZR 1100 CE: ₹35 · daily loss limit: ₹20,000."
echo "   change: cd $D && python3 posguard.py stop SYMBOL PRICE  ·  python3 posguard.py limit AMOUNT"
echo "   undo: systemctl disable --now gir-posguard.timer"
