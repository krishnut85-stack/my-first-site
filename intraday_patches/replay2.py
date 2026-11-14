#!/usr/bin/env python3
"""replay2.py - READ ONLY. ONE DAY, ONE SHARE, MINUTE BY MINUTE (Rama, 14 Nov: "on Friday, when the futures were building up for POLICYBZR, at what
time did the share start moving and when did GIR alert me - and with the new speed, how would GIR tell me before it goes up - POLICYBZR, HINDALCO,
and was the sector the same way"). From Zerodha's minute data: the share (NSE) price and volume, its futures OI, NIFTY, its sector's shares;
GIR's real alerts of that day from tomorrow.db; and when the new rules (patches 275-286) would have fired. Changes nothing, sends nothing.
python3 replay2.py [DAY] [SYM SYM ...]      (default: 2026-11-13 POLICYBZR HINDALCO)"""
import os, sys, re, time, sqlite3, datetime as dt
BASE = "/home/globalbot/intraday"
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
day = sys.argv[1] if len(sys.argv) > 1 else "2026-11-13"
SWEEP = "sweep" in [a.lower() for a in sys.argv[2:]]
SYMS = [s.upper() for s in sys.argv[2:] if s.lower() != "sweep"] or ["POLICYBZR", "HINDALCO"]
dd = dt.date.fromisoformat(day)
import core
k = core.get_kite()
def hd(*a, **kw):
    for n in range(8):
        try:
            r = k.historical_data(*a, **kw); time.sleep(0.4); return r
        except Exception as ex:
            if "too many" in str(ex).lower() or "rate" in str(ex).lower():
                time.sleep(2 + n); continue
            print("  (data: %s)" % str(ex)[:80]); return []
    return []
EQ = {r["tradingsymbol"]: r["instrument_token"] for r in k.instruments("NSE") if r.get("segment") == "NSE" and r.get("instrument_type") == "EQ"}
FUT = {}
for r in k.instruments("NFO"):
    if r.get("instrument_type") == "FUT" and r.get("expiry") and r["expiry"] >= dd:
        if r["name"] not in FUT or r["expiry"] < FUT[r["name"]][1]:
            FUT[r["name"]] = (r["instrument_token"], r["expiry"])
a, b = dt.datetime(dd.year, dd.month, dd.day, 9, 15), dt.datetime(dd.year, dd.month, dd.day, 15, 30)
def minutes(tok, oi=False):
    R = hd(tok, a, b, "minute", oi=oi)
    return {r["date"].astimezone(IST).strftime("%H:%M"): r for r in R if r["date"].astimezone(IST).date() == dd}
def prevclose(tok):
    R = [r for r in hd(tok, dd - dt.timedelta(days=10), dd - dt.timedelta(days=1), "day") if r["date"].date() < dd]
    return float(R[-1]["close"]) if R else None
try:
    import windwatch as WW
    SEC = WW.sectors_of()
except Exception:
    SEC = {}
OF = {}
for kk, v in SEC.items():
    for s in v:
        OF.setdefault(s, kk)
NI = minutes(256265); nipc = prevclose(256265)
HMS = sorted(NI)
def nifty_at(hm):
    if hm not in NI or not nipc:
        return None
    o = float(NI[HMS[0]]["open"]); c = float(NI[hm]["close"])
    i = HMS.index(hm); old = float(NI[HMS[max(0, i - 15)]]["close"])
    st = "RISING" if (c > o * 1.0005 and c >= old) else "FALLING" if (c < o * 0.9995 and c <= old) else "SIDEWAYS"
    return st, (c / nipc - 1) * 100
def alerts(s):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=5)
        R = c.execute("select t, text from alerts where day=? and (sym=? or text like ?) order by t", (day, s, "%" + s + "%")).fetchall(); c.close()
        return [(str(t)[:8], (tx or "").split("\n")[0][:95]) for t, tx in R]
    except Exception as ex:
        return [("-", "(tomorrow.db: %s)" % str(ex)[:60])]
for s in SYMS:
    print("\n" + "=" * 100)
    if s not in EQ:
        print("%s: not found on NSE" % s); continue
    P = minutes(EQ[s]); pc = prevclose(EQ[s])
    F = minutes(FUT[s][0], oi=True) if s in FUT else {}
    peers = [p for p in (SEC.get(OF.get(s)) or []) if p != s and p in EQ][:10]
    PP = {p: (minutes(EQ[p]), prevclose(EQ[p])) for p in peers}
    T = [hm for hm in sorted(P) if hm in F]
    if len(T) < 20 or not pc:
        print("%s: not enough minute data for %s" % (s, day)); continue
    o = float(P[T[0]]["open"]); oi0 = next((float(F[hm].get("oi") or 0) for hm in T if F[hm].get("oi")), 0)
    close = float(P[T[-1]]["close"]); d = 1 if close >= pc else -1
    print("%s · %s · %s · closed %+.2f%% (₹%s → ₹%s) · the day's direction: %s · sector %s (%d shares)" % (
        s, day, "▲" if d > 0 else "▼", (close / pc - 1) * 100, "{:,.2f}".format(pc), "{:,.2f}".format(close), "UP (CE)" if d > 0 else "DOWN (PE)", OF.get(s, "-"), len(peers)))
    def row(i):
        hm = T[i]; px = float(P[hm]["close"]); oi = float(F[hm].get("oi") or 0)
        j3, j15 = T[max(0, i - 3)], T[max(0, i - 15)]
        p3 = (px / float(P[j3]["close"]) - 1) * 100; p15 = (px / float(P[j15]["close"]) - 1) * 100
        o3 = (oi / float(F[j3].get("oi") or oi) - 1) * 100 if F[j3].get("oi") else 0
        o15 = (oi / float(F[j15].get("oi") or oi) - 1) * 100 if F[j15].get("oi") else 0
        od = (oi / oi0 - 1) * 100 if oi0 else 0
        su = sd = 0
        for p, (PM, ppc) in PP.items():
            if hm in PM and ppc:
                ch = (float(PM[hm]["close"]) / ppc - 1) * 100
                su += ch > 0.3; sd += ch < -0.3
        vol = float(P[hm].get("volume") or 0)
        return {"hm": hm, "px": px, "chg": (px / pc - 1) * 100, "p3": p3, "p15": p15, "o3": o3, "o15": o15, "od": od, "su": su, "sd": sd, "vol": vol}
    R = [row(i) for i in range(len(T))]
    def first(f, frm="09:15"):
        return next((r for r in R if r["hm"] >= frm and f(r)), None)
    EV = []
    x = first(lambda r: r["od"] >= 1.0 and (r["chg"] * d) > 0)
    EV.append(("FUTURES MONEY STARTS", x, "futures OI +1%% since the open, price on the day's side (%s build-up begins)" % ("long" if d > 0 else "short")))
    x = first(lambda r: (r["px"] / o - 1) * 100 * d >= 1.0)
    EV.append(("THE SHARE STARTS MOVING", x, "1% from its open, the day's way"))
    x = first(lambda r: r["o15"] >= 0.5 and abs(r["p15"]) < 0.3, "09:30")
    EV.append(("⏳ MONEY LOADING (new, page)", x, "futures OI +0.5% in 15 min while the price is still flat"))
    def bigm(r):
        sec_ok = (r["su"] if d > 0 else r["sd"]) * 2 >= max(1, len(peers))
        sc = (abs(r["p3"]) >= 0.6) + (r["o3"] >= 0.5) + bool(sec_ok)
        return r["p3"] * d >= 0.8 and r["o3"] >= 0.5 and sc >= 2
    x = first(bigm, "09:16")
    EV.append(("🌪 BIG MOVER (new, rings)", x, "0.8% in 3 min with new futures money and the sector (the order book not in old data: 2 of 3 used)"))
    def bigm287(r):
        sec_ok = (r["su"] if d > 0 else r["sd"]) * 2 >= max(1, len(peers))
        money = r["o3"] >= 0.5 or (r["od"] >= 1.0 and r["chg"] * d >= 0.3)
        sc = (abs(r["p3"]) >= 0.6) + bool(money) + bool(sec_ok)
        return r["p3"] * d >= 0.8 and money and sc >= 2
    x = first(bigm287, "09:16")
    EV.append(("🌪 BIG MOVER (patch 287 rule)", x, "0.8% in 3 min with new futures money - the last 3 min OR the day's build-up"))
    x = first(lambda r: r["chg"] * d >= 3.0, "09:17")
    EV.append(("🚀 MOMENTUM (new, rings before 10:00)", x, "crosses %s3%% on the day" % ("+" if d > 0 else "-")))
    print("  WHAT HAPPENED, and WHEN THE NEW RULES FIRE:")
    for nm, r, why in sorted(EV, key=lambda e: e[1]["hm"] if e[1] else "99"):
        if r:
            na = nifty_at(r["hm"])
            print("   %s  %-38s ₹%-9s %+.2f%% · fut OI %+.1f%% (15 min %+.1f%%) · sector %d up / %d down · NIFTY %s" % (
                r["hm"], nm, "{:,.2f}".format(r["px"]), r["chg"], r["od"], r["o15"], r["su"], r["sd"], ("%s %+.2f%%" % na) if na else "-"))
        else:
            print("   --:--  %-38s did not happen (%s)" % (nm, why))
    A = alerts(s)
    print("  WHAT GIR REALLY SENT THAT DAY (the old system, before patches 275-286): %d" % len(A))
    for t, h in A[:14]:
        print("   %s  %s" % (t, h))
    mv = next((e[1] for e in EV if e[0] == "THE SHARE STARTS MOVING"), None)
    new1 = min([e[1]["hm"] for e in EV if e[1] and ("new" in e[0])] or ["99"])
    old1 = A[0][0][:5] if A and A[0][0] != "-" else "99"
    if mv:
        print("  → the share started moving at %s · GIR's first alert then: %s · the first new-rule signal: %s" % (mv["hm"], old1 if old1 != "99" else "none", new1 if new1 != "99" else "none"))
    if SWEEP:
        hi = max(r["chg"] * d for r in R)
        print("  SETTINGS TEST - the 🌪 BIG MOVER rule with other numbers (a burst in 3 min + new futures money: the last 3 min OR the day's build-up)")
        print("  %-62s %-6s %-9s %-14s %s" % ("setting", "alert", "price", "move left", "alerts that day (noise)"))
        for pb in (0.5, 0.8, 1.0):
            for o3m in (0.3, 0.5):
                for odm in (0.5, 1.0, 1.5, 2.0, None):
                    def rule(r, pb=pb, o3m=o3m, odm=odm):
                        sec_ok = (r["su"] if d > 0 else r["sd"]) * 2 >= max(1, len(peers))
                        money = r["o3"] >= o3m or (odm is not None and r["od"] >= odm and r["chg"] * d >= 0.3)
                        sc = (abs(r["p3"]) >= 0.6) + bool(money) + bool(sec_ok)
                        return r["p3"] * d >= pb and money and sc >= 2
                    hits, last = [], -999
                    for i, r in enumerate(R):
                        if r["hm"] >= "09:16" and r["hm"] <= "15:00" and rule(r) and i - last >= 30:
                            hits.append(r); last = i
                    nm = "burst %.1f%% in 3 min · money: OI +%.1f%% in 3 min%s" % (pb, o3m, (" OR the day's build-up +%.1f%%" % odm) if odm else " only (the old way)")
                    star = " ◀ patch 287" if (pb == 0.8 and o3m == 0.5 and odm == 1.0) else (" ◀ the old rule" if (pb == 0.8 and o3m == 0.5 and odm is None) else "")
                    if hits:
                        f = hits[0]
                        print("  %-62s %-6s %+6.2f%%  %+6.2f%% left   %d%s" % (nm, f["hm"], f["chg"], hi - f["chg"] * d, len(hits), star))
                    else:
                        print("  %-62s %-6s %-9s %-14s %d%s" % (nm, "none", "-", "-", 0, star))
        print("  ⏳ MONEY LOADING with other numbers (futures OI up in 15 min while the price is still flat - the head start):")
        for o15m in (0.3, 0.5, 0.8):
            for flat in (0.3, 0.5):
                f = first(lambda r, o15m=o15m, flat=flat: r["o15"] >= o15m and abs(r["p15"]) < flat, "09:30")
                print("   OI +%.1f%% in 15 min · price within %.1f%%   -> %s" % (o15m, flat, ("%s at %+.2f%% (the jump began %s)" % (f["hm"], f["chg"], mv["hm"] if mv else "-")) if f else "none"))
    print("  MINUTE BY MINUTE around the start (price · fut OI since open · OI last 3 min · sector up/down · NIFTY):")
    st = (mv or R[0])["hm"]; i0 = max(0, T.index(st) - 10)
    for r in R[i0:i0 + 25]:
        na = nifty_at(r["hm"])
        print("   %s ₹%-9s %+5.2f%% · OI %+5.1f%% · 3m %+4.1f%% · sector %d/%d · NIFTY %s" % (r["hm"], "{:,.2f}".format(r["px"]), r["chg"], r["od"], r["o3"], r["su"], r["sd"], na[0] if na else "-"))
print("\nREAD: live, the new watcher reads every 3 seconds (this replay has minutes) - so live it would be up to a minute earlier than shown.")
