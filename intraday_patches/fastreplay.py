#!/usr/bin/env python3
"""fastreplay.py - READ ONLY. FRIDAY AGAIN, WITH PATCHES 275-278 (Rama, 14 Nov: "recheck one more time with the Friday data after updating the code -
how fast are we getting the futures, options and OI data"). Zerodha keeps every F&O contract's MINUTE candles with OPEN INTEREST: this fetches the
day's futures (218 shares) and, for every 🌪 card, the 6 strikes nearest the price (CE + PE), then runs the SAME rules as windwatch.py on them:
the wind (price 3 min · futures OI 3 min · sector), 🌪 BIG MOVER, the writers, and each card to its 🎯 / 🚪. Against the day's 47 real moves and what
GIR really sent that day. The live watcher reads every 3 s; this replay only has minutes - the live one is up to a minute EARLIER than shown here.
The order book is not in Zerodha's history: shown both ways (book counted as no = strict · as yes = loose).
Changes nothing, sends nothing, orders nothing.   python3 fastreplay.py [YYYY-MM-DD]"""
import os, re, sys, json, time, sqlite3, statistics, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__)) if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), "windwatch.py")) else "/home/globalbot/intraday"
sys.path.insert(0, BASE); os.chdir(BASE)
import numpy as np
import windwatch as WW
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
day = sys.argv[1] if len(sys.argv) > 1 else ""
if not day:
    d = now.date() - dt.timedelta(days=1 if now.strftime("%H:%M") < "15:35" else 0)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    day = str(d)
D0 = dt.datetime.fromisoformat(day + " 09:15").replace(tzinfo=IST)
d0 = D0.timestamp()
HM = lambda ts: dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M")
med = lambda L: statistics.median(L) if L else None
def ro(db):
    return sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)

# ---------------- 1 · the data pipes, as they are now ----------------
print("=== 1 · HOW FAST THE DATA COMES NOW (patches 275-278)")
def age(p, key="t"):
    try:
        j = json.load(open(p)); t = float(j.get(key) or 0)
        return t
    except Exception:
        return None
live_open = now.weekday() < 5 and "09:15" <= now.strftime("%H:%M") <= "15:30"
for name, p, every in (("prices of every share (quotes_live.json)", "quotes_live.json", "every 1 s"),
                       ("futures price + OI + order book (data/fut_live.json)", "data/fut_live.json", "every 1 s"),
                       ("option strikes, 11 nearest × CE/PE, 218 shares (pins_live.json)", "pins_live.json", "every 5 s"),
                       ("the wind: read + 🌪 / 🔄 / 🎯 / 🚪 decided (data/wind.json)", "data/wind.json", "every 3 s")):
    t = age(p)
    st = ("%.0f s old ✓" % (time.time() - t) if time.time() - t < 30 else "%.0f s old ⚠" % (time.time() - t)) if (t and live_open) else \
         ("last written %s (market closed)" % dt.datetime.fromtimestamp(t, IST).strftime("%a %H:%M:%S") if t else "not written yet")
    print("  %-70s %-10s %s" % (name, every, st))
print("  Telegram: 🌪 / 🎯 / 🚪 / 🔄 go straight to GIR Bigmovers (about 1-2 s) · the old path's median was 28 s")
print("  before (Friday): futures OI reached the alerts on 5-min candles · option OI from the slow chain - %s" % "every ~75 min per share (1,090 readings / 218 shares)")

# ---------------- 2 · the day's real moves (the same rule as windaudit.sh) ----------------
fo = set()
try:
    c = ro("chains.db"); fo = {r[0] for r in c.execute("select sym from fo_list")}; c.close()
except Exception:
    pass
CJ = {}
try:
    CJ = json.load(open("charts.json"))
except Exception:
    pass
def bars(s):
    for p in ("data/%s.npz" % s, "data/h3/%s.npz" % s, "data/h3/5min/%s.npz" % s):
        try:
            z = np.load(p); ts = np.asarray(z["ts"], float)
            idx = np.nonzero(((ts + 19800) // 86400).astype(int) == int((d0 + 19800) // 86400))[0]
            if len(idx) >= 20:
                return ts[idx], np.asarray(z["c"], float)[idx]
        except Exception:
            continue
    x = CJ.get(s)
    if x and x.get("c") and len(x["c"]) >= 20:
        C = np.array([v if v is not None else np.nan for v in x["c"]], float)
        return np.array([d0 + 300 * i for i in range(len(C))], float), C
    return None
M = []
for s in sorted(fo or (set(CJ) - {"NIFTY 50", "NIFTY BANK"})):
    b = bars(s)
    if not b:
        continue
    ts, C = b
    seen = set()
    for i in range(3, len(C) - 2):
        if np.isnan(C[i]) or np.isnan(C[i - 3]) or not C[i - 3]:
            continue
        r15 = (C[i] / C[i - 3] - 1) * 100
        if abs(r15) < 1.0:
            continue
        sd = 1 if r15 > 0 else -1
        if sd in seen:
            continue
        st = i - 3
        while st < i and not np.isnan(C[st + 1]) and (C[st + 1] - C[st]) * sd <= 0:
            st += 1
        while st > 0 and not np.isnan(C[st - 1]) and (C[st] - C[st - 1]) * sd > 0:
            st -= 1
        fut = C[i:min(len(C), i + 13)]
        best = (np.nanmax(fut) if sd > 0 else np.nanmin(fut))
        if (best / C[st] - 1) * 100 * sd < 1.5:
            continue
        seen.add(sd)
        M.append({"s": s, "sd": sd, "t0": ts[st] + 300, "hour": (best / C[st] - 1) * 100 * sd})
# what GIR really sent that day (the first alert / the first ring per move)
try:
    c = ro("tomorrow.db"); A = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
except Exception:
    A = []
AL = {}
for t, s, tx in A:
    h = (tx or "").split("\n")[0]
    m = re.search(r"([▲▼])\s+([A-Z][A-Z0-9&\-]{1,19})\b", h)
    if not m:
        continue
    try:
        ts_ = dt.datetime.fromisoformat("%s %s" % (day, str(t)[:8])).replace(tzinfo=IST).timestamp()
    except Exception:
        continue
    rang = "🔕" not in (tx or "") and bool(re.search(r"🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|CRITICAL|CONFIRMED MOVE", tx or ""))
    AL.setdefault(m.group(2), []).append((ts_, 1 if m.group(1) == "▲" else -1, rang))

# ---------------- 3 · Zerodha's minute candles with OI ----------------
import core
try:
    k = core.get_kite()
    try:
        k.timeout = 10
    except Exception:
        pass
    NFO = k.instruments("NFO")
    k.profile()
except Exception as ex:
    print("\n⚠ Zerodha did not answer (%s)." % str(ex)[:90])
    print("  Zerodha's login ends every morning at 6 AM - GIR logs in again before the market on a trading day.")
    print("  Run this again on Monday after 08:45 (Friday's data is still there):  python3 %s %s" % (os.path.abspath(__file__), day))
    sys.exit(0)
dd = D0.date()
FUT, OPT = {}, {}
for r in NFO:
    ex = r.get("expiry")
    if not ex or ex < dd:
        continue
    nm = r.get("name")
    if r.get("instrument_type") == "FUT":
        if nm not in FUT or ex < FUT[nm][1]:
            FUT[nm] = (r["instrument_token"], ex)
    elif r.get("instrument_type") in ("CE", "PE"):
        OPT.setdefault(nm, []).append((ex, float(r["strike"]), r["instrument_type"], r["instrument_token"]))
syms = sorted(s for s in (fo or FUT) if s in FUT)
print("\n=== 2 · fetching %s's minute candles + OI from Zerodha: %d futures (about %d s) ..." % (day, len(syms), len(syms) * 0.4), flush=True)
def hist(tok):
    for a in range(3):
        try:
            return k.historical_data(tok, D0.replace(tzinfo=None), D0.replace(hour=15, minute=30, tzinfo=None), "minute", oi=True)
        except Exception as ex:
            if "Too many" in str(ex) or "rate" in str(ex).lower():
                time.sleep(1.5); continue
            return []
    return []
MIN = {}            # sym -> (ts[], close[], oi[])
for n, s in enumerate(syms):
    R = hist(FUT[s][0]); time.sleep(0.34)
    if len(R) >= 30:
        MIN[s] = (np.array([r["date"].timestamp() + 60 for r in R], float), np.array([r["close"] for r in R], float), np.array([r.get("oi") or 0 for r in R], float))
    if n % 50 == 49:
        print("  %d of %d" % (n + 1, len(syms)), flush=True)
print("  futures with minute data: %d" % len(MIN))

# ---------------- 4 · the wind, minute by minute, with windwatch's own rules ----------------
SEC = WW.sectors_of(); OF = {}
for kk, v in SEC.items():
    for s in v:
        OF.setdefault(s, kk)
T = sorted({t for v in MIN.values() for t in v[0]})
def read_at(t):
    mv = {}
    for s, (ts, C, OI) in MIN.items():
        i = np.searchsorted(ts, t, side="right") - 1
        if i < 3 or ts[i] < t - 90:
            continue
        px3 = float((C[i] / C[i - 3] - 1) * 100)
        oi3 = float((OI[i] / OI[i - 3] - 1) * 100) if OI[i] and OI[i - 3] else None
        mv[s] = (px3, oi3, float(C[i]))
    out = {}
    for s, (px3, oi3, px) in mv.items():
        d = 1 if px3 >= WW.PX_MIN else -1 if px3 <= -WW.PX_MIN else 0
        if not d:
            continue
        kind = "PRICE ONLY"
        if oi3 is not None and oi3 >= WW.OI_MIN:
            kind = "LONG BUILD-UP" if d > 0 else "SHORT BUILD-UP"
        elif oi3 is not None and oi3 <= -WW.OI_MIN:
            kind = "SHORT COVERING" if d > 0 else "LONG UNWINDING"
        sec = OF.get(s)
        peers = [mv[p][0] for p in (SEC.get(sec) or []) if p != s and p in mv]
        up, dn = sum(1 for x in peers if x > 0.2), sum(1 for x in peers if x < -0.2)
        sec_ok = bool(peers) and (up if d > 0 else dn) * 2 >= len(peers)
        out[s] = {"dir": d, "kind": kind, "px3": round(px3, 2), "oi3": None if oi3 is None else round(oi3, 2), "px": px, "sec_ok": sec_ok,
                  "base": int(abs(px3) >= 0.6) + int(kind in ("LONG BUILD-UP", "SHORT BUILD-UP")) + int(sec_ok)}
    return out
class FW:
    pass
def run(mode, px_min):
    """mode strict: book = no (score = base) · loose: book = yes (score = base + 1) · px_min: the 🌪 rule's move in 3 min"""
    WW.BIG_PX = px_min
    said, cards = {}, []
    BK = WW.Book(day); W = FW(); W.h = {}
    for t in T:
        hm = HM(t)
        if hm < "09:16" or hm > "15:30":
            continue
        cur = read_at(t)
        for s, w in cur.items():
            w["score"] = w["base"] + (1 if mode == "loose" else 0)
        for s, (ts, C, OI) in MIN.items():
            i = np.searchsorted(ts, t, side="right") - 1
            if i >= 0:
                W.h[s] = [(float(ts[i]), float(C[i]))]
        for kind, p, px, words in BK.step(t, hm, W, cur):
            if kind == "EXIT":
                p["exit_ts"] = t
        for s, w in WW.big_movers(t, cur, said):
            if (s, w["dir"]) in BK.open:
                continue
            other = BK.open.pop((s, -w["dir"]), None)
            if other:
                other.update({"exit_t": hm, "exit_px": w["px"], "why": "a big mover the other way", "res": round((w["px"] - other["entry"]) * other["dir"] / other["entry"] * 100, 2)})
                BK.done.append(other)
            p = BK.add(s, w, t, hm); p["w"] = dict(w)
            cards.append(p)
    for p in list(BK.open.values()):
        BK.done.append(p)
    return cards[:200]

# ---------------- 5 · the writers for each card (the 6 strikes nearest the price, CE + PE) ----------------
WR = {}
def writers(s, t, px, d):
    key = (s, int(t // 60))
    if key in WR:
        return WR[key]
    L = OPT.get(s) or []
    if not L:
        WR[key] = None; return None
    ex = min(o[0] for o in L)
    row = sorted({o[1] for o in L if o[0] == ex}, key=lambda kk: abs(kk - px))[:2 * WW.NEAR]
    sums = {"CE": [0.0, 0.0], "PE": [0.0, 0.0]}
    for o in L:
        if o[0] != ex or o[1] not in row:
            continue
        try:
            R = k.historical_data(o[3], dt.datetime.fromtimestamp(t - 600, IST).replace(tzinfo=None), dt.datetime.fromtimestamp(t, IST).replace(tzinfo=None), "minute", oi=True)
        except Exception:
            R = []
        time.sleep(0.34)
        R = [r for r in R if r["date"].timestamp() + 60 <= t + 1]
        if len(R) >= 4:
            sums[o[2]][0] += R[-4].get("oi") or 0; sums[o[2]][1] += R[-1].get("oi") or 0
    if sums["CE"][0] < WW.OPT_MIN_OI or sums["PE"][0] < WW.OPT_MIN_OI:
        WR[key] = None; return None
    ce3 = (sums["CE"][1] / sums["CE"][0] - 1) * 100; pe3 = (sums["PE"][1] / sums["PE"][0] - 1) * 100
    WR[key] = (round(ce3, 1), round(pe3, 1), WW.opt_agree(d, ce3, pe3))
    return WR[key]

OLD = {}
for n_, (mode, pxm) in enumerate((("strict", 0.8), ("loose", 0.8), ("strict", 0.5), ("loose", 0.5))):
    full = n_ == 0
    cards = run(mode, pxm)
    print("\n=== %d · 🌪 %s%% in 3 min · order book counted as %s (%s)%s · %d cards%s" % (3 + n_, pxm, "NO" if mode == "strict" else "YES", "the rule now" if pxm == 0.8 else "an idea - not live",
          "" if mode == "strict" else " - the best case", len(cards), " - checking the writers for each (6 strikes × CE/PE, about %d s) ..." % (len(cards) * 12 * 0.35) if full else ""), flush=True)
    for p in cards:
        p["wr"] = writers(p["s"], p["ts"], p["entry"], p["dir"]) if full else None
    sent = [p for p in cards if not (p.get("wr") and p["wr"][2] is False)]
    held = [p for p in cards if p.get("wr") and p["wr"][2] is False]
    # against the 47 moves
    caught, mins, rows = 0, [], []
    for m in M:
        cs = [p for p in sent if p["s"] == m["s"] and p["dir"] == m["sd"] and m["t0"] - 600 <= p["ts"] <= m["t0"] + 3600]
        old = [a for a in AL.get(m["s"], []) if a[1] == m["sd"] and a[0] >= m["t0"] - 900]
        o1 = min((a[0] for a in old), default=None); r1 = min((a[0] for a in old if a[2]), default=None)
        if cs:
            caught += 1; mins.append((cs[0]["ts"] - m["t0"]) / 60)
        rows.append((m, cs[0] if cs else None, o1, r1))
    o1s = [(o1 - m["t0"]) / 60 for m, p, o1, r1 in rows if o1]; r1s = [(r1 - m["t0"]) / 60 for m, p, o1, r1 in rows if r1]
    print("  the %d real moves: 🌪 caught %d · median %s min from the move's start · within 3 min: %d   (old GIR that day: first alert median %s min · rang %d, median %s min)" % (
        len(M), caught, ("%+.0f" % med(mins)) if mins else "-", sum(1 for x in mins if x <= 3), ("%.0f" % med(o1s)) if o1s else "-", len(r1s), ("%.0f" % med(r1s)) if r1s else "-"))
    if full:
        for m, p, o1, r1 in rows:
            print("    %s %-11s %s %+.1f%%   🌪 %-14s old: alert %-8s ring %s" % (HM(m["t0"]), m["s"], "▲" if m["sd"] > 0 else "▼", m["hour"] * m["sd"],
                  ("%s (%+.0f min)" % (p["t"][:5], (p["ts"] - m["t0"]) / 60)) if p else "-", ("%+.0f min" % ((o1 - m["t0"]) / 60)) if o1 else "-", ("%+.0f min" % ((r1 - m["t0"]) / 60)) if r1 else "never"))
    res = [p["res"] for p in sent if p.get("res") is not None]
    print("  every card that would have gone to GIR Bigmovers: %d (held by the writers: %d) · won %d · lost %d · ½ booked first %d · average %+.2f%% on the share" % (
        len(sent), len(held), sum(1 for x in res if x > 0), sum(1 for x in res if x < 0), sum(1 for p in sent if p.get("half")), (sum(res) / len(res)) if res else 0))
    why = {}
    for p in sent:
        w_ = (p.get("why") or "open at the close").split(":")[0].split(" - ")[0]
        why[w_] = why.get(w_, 0) + 1
    print("  how they ended: " + " · ".join("%s %d" % (kk, v) for kk, v in sorted(why.items(), key=lambda x: -x[1])))
    if full:
        print("  the cards:")
        for p in cards[:60]:
            wr = p.get("wr")
            print("    %s %-11s %s ₹%-9s %s%s → %s %s" % (p["t"][:5], p["s"], "CE" if p["dir"] > 0 else "PE", "{:,.2f}".format(p["entry"]),
                  ("writers %s (CE %+.1f%% PE %+.1f%%) " % ({True: "✓", False: "✗ HELD", None: "~"}[wr[2]], wr[0], wr[1])) if wr else "", "½ " if p.get("half") else "",
                  p.get("exit_t") or "close", ("%+.2f%% · %s" % (p["res"], (p.get("why") or "")[:50])) if p.get("res") is not None else ""))
print("\nREAD: minutes, not seconds - the live watcher reads every 3 s, so live it is up to a minute earlier than above. Changes nothing, sends nothing.")
