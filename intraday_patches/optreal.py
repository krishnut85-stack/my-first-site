#!/usr/bin/env python3
"""optreal.py - READ ONLY. GIR'S OWN ALERTS, TRADED IN THE REAL OPTION - KITE'S OWN MINUTE PRICES (Rama, 16 Nov: "you have to check how much it
actually moved based on the Kite data" - an option does not move in a straight line with the share).
For every F&O share GIR alerted on with CE / PE (the alerts table, tomorrow.db):
  the CONTRACT   the real at-the-money option on NFO: the nearest expiry, the strike nearest the share's price at the alert, CE or PE as GIR said
  ENTRY          the option's own Kite minute close at the minute of the alert
  STOP / HALF    watched on the SHARE's Kite minute high / low: 2.5% against -> all out; +1.5% its way -> half out, the stop to the entry
  EXIT           the rest at 15:10
  ₹              the option's own Kite minute closes at those minutes x the lot - the premium as it really traded, before charges
  A) the first alert on each share (any line)   B) the first REAL call (no WATCH / IN DOUBT)   C) by alert type   D) the first N of the day
  E) other stops / half-outs on the same entries
Uses the Kite login GIR refreshes every morning (core.get_kite - it never logs in itself). Reads only. Sends nothing.
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 optreal.py [YYYY-MM-DD ... | N]   -> prints, saves data/optreal.txt
  v4: G) the FUTURES BUILD-UP rebuilt minute by minute from Kite's futures OI (all F&O shares) - an alert at the minute it was identified
  v3: the same trades in the near-month FUTURE (Kite's futures prices, no time decay) + GIR's other records with a side (build-up, surges,
      book moves, desk calls ... - tomorrow.db tables that are not the alert list) as their own types (📊)
  v2: N = the last N trading days (only days whose own monthly contract Kite still has) · E) adds a TIME stop and a PREMIUM stop · F) the best exit per type"""
import os, sys, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import callreplay as C
L = []
f0 = lambda x: "{:,.0f}".format(x)


def say(s=""):
    L.append(s); print(s, flush=True)


class Kite:
    def __init__(self, day):
        import core, getdata
        self.g = getdata; self.k = core.get_kite(); self.day = dt.date.fromisoformat(day); self.cache = {}; self.first_day = self.day
        self.eq = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(self.k.instruments, "NSE") if i.get("instrument_type") == "EQ"}
        self.opt = {}; self.fut = {}
        for i in getdata.call(self.k.instruments, "NFO"):
            t = i.get("instrument_type")
            if t == "FUT" and i.get("name"):                                   # v3: the futures too
                e = i.get("expiry"); e = e if isinstance(e, dt.date) else dt.date.fromisoformat(str(e)[:10])
                self.fut.setdefault(i["name"], []).append((e, int(i["instrument_token"]), i["tradingsymbol"], int(i.get("lot_size") or 0)))
            if t in ("CE", "PE") and i.get("name"):
                e = i.get("expiry"); e = e if isinstance(e, dt.date) else dt.date.fromisoformat(str(e)[:10])
                if e >= self.first_day:
                    self.opt.setdefault((i["name"], t), []).append((e, float(i["strike"]), int(i["instrument_token"]), i["tradingsymbol"], int(i.get("lot_size") or 0)))

    def candles(self, token):
        """{minute since 09:15: (open, high, low, close)} for the day"""
        if (token, self.day) in self.cache:
            return self.cache[(token, self.day)]
        out = {}
        try:
            frm = dt.datetime.combine(self.day, dt.time(9, 15)); to = dt.datetime.combine(self.day, dt.time(15, 30))
            for c in self.g.call(self.k.historical_data, token, frm, to, "minute"):
                d = c["date"]; m = d.hour * 60 + d.minute - 555
                out[m] = (float(c["open"]), float(c["high"]), float(c["low"]), float(c["close"]))
        except Exception as ex:
            print("  candles %s: %s" % (token, str(ex)[:60]), flush=True)
        self.cache[(token, self.day)] = out
        return out

    def fut_oi(self, token):
        """v4: the future's minute candles WITH OI for the day + yesterday's last (close, OI) - to rebuild the build-up minute by minute"""
        key = ("oi", token, self.day)
        if key in self.cache:
            return self.cache[key]
        base, out = None, {}
        try:
            frm = dt.datetime.combine(self.day - dt.timedelta(days=6), dt.time(9, 15)); to = dt.datetime.combine(self.day, dt.time(15, 30))
            for c in self.g.call(self.k.historical_data, token, frm, to, "minute", oi=True):
                d = c["date"]; dd = d.date() if hasattr(d, "date") else d
                if dd < self.day:
                    base = (float(c["close"]), float(c.get("oi") or 0))
                elif dd == self.day:
                    out[d.hour * 60 + d.minute - 555] = (float(c["close"]), float(c.get("oi") or 0))
        except Exception as ex:
            print("  oi %s: %s" % (token, str(ex)[:60]), flush=True)
        self.cache[key] = (base, out)
        return base, out

    def contract(self, sym, dr, px):
        """the at-the-money option of the nearest expiry: (tradingsymbol, token, lot)"""
        R = [r for r in (self.opt.get((sym, "CE" if dr > 0 else "PE")) or []) if r[0] >= self.day]
        if not R:
            return None
        e0 = min(r[0] for r in R)
        if abs((e0 - near_expiry(self.day)).days) > 4:                         # a holiday can move the expiry a few days
            return None                                                        # v2: that day's own month contract has expired - not in Kite
        e, k, tok, ts, lot = min((r for r in R if r[0] == e0), key=lambda r: abs(r[1] - px))
        return ts, tok, lot


def fut_contract(K, sym):
    """v3: that day's own near-month future: (tradingsymbol, token, lot)"""
    R_ = [r for r in K.fut.get(sym) or [] if r[0] >= K.day and abs((r[0] - near_expiry(K.day)).days) <= 4]
    if not R_:
        return None
    e, tok, ts, lot = min(R_)
    return ts, tok, lot


BU_CR = (10, 25, 50, 100)                                                       # v4: the build-up size (₹ crore of OI added / cut) that counts as "identified"


def buildups(K):
    """v4: GIR's build-up word, rebuilt minute by minute from Kite's futures OI - for every F&O share: the FIRST minute (09:15-15:00) its
    build-up reached each size. LONG BUILD-UP (price up, OI up) -> CE · SHORT BUILD-UP (price down, OI up) -> PE · SHORT COVERING (price up,
    OI down) -> CE · LONG UNWINDING (price down, OI down) -> PE. Price and OI against yesterday's close, ₹ crore = the OI change x the price."""
    out = []
    for sym in sorted(K.fut):
        if sym not in K.eq:
            continue
        fc = fut_contract(K, sym)
        if not fc:
            continue
        base, M = K.fut_oi(fc[1])
        if not base or not base[0] or not base[1] or not M:
            continue
        got = set()
        for m in sorted(M):
            if m > 345:
                break
            px, oi = M[m]
            if not oi:
                continue
            p = px / base[0] - 1; o = oi / base[1] - 1; cr = (oi - base[1]) * px / 1e7
            if abs(p) < 0.001:
                continue
            w = ("LONG BUILD-UP" if o > 0 else "SHORT COVERING") if p > 0 else ("SHORT BUILD-UP" if o > 0 else "LONG UNWINDING")
            for T in BU_CR:
                if abs(cr) >= T and (w, T) not in got:
                    got.add((w, T))
                    out.append({"m": m, "t": C.hm(m) + ":00", "s": sym, "dir": 1 if p > 0 else -1, "lab": "%s ₹%d cr+" % (w, T), "call": True,
                                "first": w, "pre": p * 100, "cr": cr, "w": w, "T": T})
    return out


def records(day):
    """v3: GIR's OTHER records with a side (not the alert list): every tomorrow.db table with day + t + sym + side/dir - first moves, surges,
    book moves, desk calls, wind calls ... -> the same shape as the alerts, the type = the table's name"""
    import sqlite3, re
    out = []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
        for (tb,) in c.execute("select name from sqlite_master where type='table'").fetchall():
            if tb == "alerts":
                continue
            cols = [r[1] for r in c.execute("pragma table_info(%s)" % tb)]
            sc = "side" if "side" in cols else "dir" if "dir" in cols else None
            if not ({"day", "t", "sym"} <= set(cols) and sc):
                continue
            for t_, s, sd in c.execute("select t, sym, %s from %s where day=? order by t" % (sc, tb), (day,)):
                t_ = str(t_ or "")
                if not re.match(r"\d\d:\d\d", t_) or not s:
                    continue
                dr = C.side(sd) if not isinstance(sd, (int, float)) else (1 if sd > 0 else -1 if sd < 0 else 0)
                m = int(t_[:2]) * 60 + int(t_[3:5]) - 555
                if dr and 0 <= m <= 345:
                    out.append({"m": m, "t": t_[:8], "s": str(s).upper(), "dir": dr, "lab": "📊 " + tb, "call": True, "first": tb})
        c.close()
    except Exception as ex:
        print("  records %s: %s" % (day, str(ex)[:80]), flush=True)
    return sorted(out, key=lambda a: a["t"])


def near_expiry(d):
    """the monthly stock-option expiry for day d: the last Tuesday of its month, or of the next month once it has passed"""
    def last_tue(y, m):
        n = dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1)
        return n - dt.timedelta(days=(n.weekday() - 1) % 7)
    e = last_tue(d.year, d.month)
    return e if d <= e else last_tue(d.year + (d.month == 12), d.month % 12 + 1)


def at(cs, m):
    """the close at minute m, or the last one before it (an option may not trade every minute)"""
    if isinstance(cs, list):                                                  # a forward-filled list (ff) - fast
        return cs[min(max(m, 0), len(cs) - 1)] if cs else None
    ks = [k for k in cs if k <= m]
    return cs[max(ks)][3] if ks else None


def ff(cs):
    """{minute: candle} -> [close at minute 0..375], forward-filled (None before the first trade)"""
    out, last = [], None
    for m in range(376):
        if m in cs:
            last = cs[m][3]
        out.append(last)
    return out


def walk(S, m0, P0, dr, st, hf, tmax=None, O=None, p0=None, pst=None):
    """on the SHARE's minute candles: -> (half minute or None, exit minute, how). v2: tmax = out if the half-out is not reached in tmax
    minutes (the time stop); pst = out if the OPTION is down pst (the premium stop)"""
    half = None; stop = -st
    for m, o, h, l, c in (S if isinstance(S, list) else sorted((k,) + v for k, v in S.items())):
        if m <= m0:
            continue
        bad = ((l if dr > 0 else h) / P0 - 1) * dr; good = ((h if dr > 0 else l) / P0 - 1) * dr
        if bad <= stop:
            return half, m, ("STOP" if half is None else "HALF+ENTRY")
        if pst and half is None and O and p0:
            q = at(O, m)
            if q and q / p0 - 1 <= -pst:
                return half, m, "PREMIUM STOP"
        if tmax and half is None and m - m0 >= tmax and good < hf:
            return half, m, "TIME STOP"
        if half is None and good >= hf:
            half = m; stop = 0.0
        if m >= C.CLOSE_M:
            return half, m, ("15:10" if half is None else "HALF+15:10")
    return half, ((S[-1][0] if isinstance(S, list) else max(S)) if S else m0), "LAST"


def fmoney(t, st=C.STOP, hf=C.HALF, tmax=None):
    """v3: the same trade in the near-month FUTURE (no time decay): ₹ for 1 lot, real Kite futures prices"""
    F = t.get("F")
    if not F or not t.get("f0"):
        return None
    hm_, mx, how = walk(t["S"], t["m0"], t["P0"], t["dir"], st, hf, tmax)
    fe = at(F, mx)
    if fe is None:
        return None
    if hm_ is None:
        return (fe - t["f0"]) * t["dir"] * t["flot"]
    fh = at(F, hm_) or fe
    return (0.5 * (fh - t["f0"]) + 0.5 * (fe - t["f0"])) * t["dir"] * t["flot"]


def money(t, st=C.STOP, hf=C.HALF, tmax=None, pst=None):
    hm_, mx, how = walk(t["S"], t["m0"], t["P0"], t["dir"], st, hf, tmax, t["O"], t["p0"], pst)
    pe = at(t["O"], mx)
    if pe is None:
        return None
    if hm_ is None:
        return (pe - t["p0"]) * t["lot"], how, mx, pe
    ph = at(t["O"], hm_) or pe
    return (0.5 * (ph - t["p0"]) + 0.5 * (pe - t["p0"])) * t["lot"], how, mx, pe


def days_wanted(args):
    """dates, or a number N = the last N trading days in the alerts table, or nothing = today"""
    import sqlite3
    ist = dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).date()
    if not args:
        return [str(ist)]
    if len(args) == 1 and args[0].isdigit():
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
        ds = [r[0] for r in c.execute("select distinct day from alerts where day <= ? order by day desc limit ?", (str(ist), int(args[0])))]; c.close()
        return sorted(ds)
    return sorted(args)


def main():
    days = days_wanted(sys.argv[1:])
    try:
        K = Kite(days[0])
    except Exception as ex:
        say("Kite not available (%s) - run it with the .env sourced, after GIR's morning login" % str(ex)[:100]); return
    say("📒 GIR'S OWN ALERTS IN THE REAL OPTION (Kite minute prices) · %d day(s): %s" % (len(days), " ".join(days)))
    say("  the at-the-money option of that day's own monthly expiry · entry at the alert minute · 1 lot, before charges")
    say("  card rule now: stop 2.5% / half +1.5% on the share, rest out 15:10 · a day whose own month contract has expired is skipped (Kite has none)")
    say("  fetching the minute candles from Kite (share, option, future with OI - about 5 minutes a day) ...")
    TA, TB, TL, BUL = [], [], {}, {}
    for day in days:
        K.day = dt.date.fromisoformat(day)
        if not any(abs((e - near_expiry(K.day)).days) <= 4 for e in {r[0] for R_ in K.opt.values() for r in R_}):
            say("  %s: skipped - that month's contracts have expired" % day); continue
        A = [a for a in C.alerts(day) if a["s"] in K.eq and ((a["s"], "CE") in K.opt or (a["s"], "PE") in K.opt)]
        built = {}

        def trade(a):
            key = (a["s"], a["dir"], a["m"])
            if key in built:
                return built[key]
            x = None
            S = K.candles(K.eq[a["s"]])
            m0 = next((m for m in sorted(S) if m >= a["m"]), None)
            if m0 is not None:
                P0 = S[m0][3]; c = K.contract(a["s"], a["dir"], P0)
                if c:
                    O = K.candles(c[1]); p0 = at(O, m0)
                    if p0:
                        x = dict(a, S=sorted((k,) + v for k, v in S.items()), O=ff(O), Sf=ff(S), m0=m0, P0=P0, ts=c[0], lot=c[2], p0=p0, day=day)
                        fc = fut_contract(K, a["s"])
                        if fc:
                            _, Mf = K.fut_oi(fc[1]); x["F"] = ff({k: (0, 0, 0, v[0]) for k, v in Mf.items()}); x["f0"] = at(x["F"], m0); x["flot"] = fc[2] or c[2]
                        r = money(x)
                        if r:
                            x["rs"], x["how"], x["mx"], x["pe"] = r
                            x["fs"] = fmoney(x) or 0.0
                        else:
                            x = None
            built[key] = x
            return x

        def first(G):
            seen = set(); out = []
            for a in G:
                if a["s"] not in seen:
                    seen.add(a["s"]); x = trade(a)
                    if x:
                        out.append(x)
            return out

        ta = first(A); tb = first([a for a in A if a["call"]]); TA += ta; TB += tb
        OR = [a for a in records(day) if a["s"] in K.eq and ((a["s"], "CE") in K.opt or (a["s"], "PE") in K.opt)]
        BU = [a for a in buildups(K) if (a["s"], "CE") in K.opt or (a["s"], "PE") in K.opt]
        for a in BU:
            TL.setdefault(a["lab"], {}).setdefault(day, []).append(a)
            BUL.setdefault(a["lab"], {}).setdefault(day, []).append(a)
        for a in A + OR:
            TL.setdefault(a["lab"], {}).setdefault(day, []).append(a)
        for lab in list(TL):
            if day in TL[lab] and TL[lab][day] and isinstance(TL[lab][day][0], dict) and "rs" not in TL[lab][day][0]:
                TL[lab][day] = first(TL[lab][day])
                if lab in BUL:
                    BUL[lab][day] = TL[lab][day]
        tot = sum(x["rs"] for x in ta)
        say("  %s %s · %3d trades · %3d won · option ₹%s · FUTURE ₹%s (the first alert on each share)" % ("✅" if tot > 0 else "❌", day, len(ta), sum(1 for x in ta if x["rs"] > 0), f0(tot), f0(sum(x.get("fs", 0) for x in ta))))
    nd = len({x["day"] for x in TA}) or 1

    def line(name, T):
        won = sum(1 for x in T if x["rs"] > 0); tot = sum(x["rs"] for x in T); fu = sum(x.get("fs", 0) for x in T)
        gd, gf = {}, {}
        for x in T:
            gd[x["day"]] = gd.get(x["day"], 0) + x["rs"]; gf[x["day"]] = gf.get(x["day"], 0) + x.get("fs", 0)
        say("  %s %-36s %4d trades · %3d won (%2d%%) · OPTION ₹%9s (%d/%d days green) · FUTURE ₹%9s (%d/%d days green)%s" % (
            "✅" if max(tot, fu) > 0 else "❌", name[:36], len(T), won, round(100 * won / max(1, len(T))), f0(tot), sum(1 for v in gd.values() if v > 0), len(gd),
            f0(fu), sum(1 for v in gf.values() if v > 0), len(gf), "" if fu or not T else " (no futures prices)"))

    say("")
    line("A) GIR's first alert on each share", TA)
    line("B) first real call (no WATCH)", TB)
    say(""); say("  C) each alert type on its own (its first alert per share per day) - 📊 = GIR's other records (build-up, surges, book moves, desk calls...):")
    rows = sorted(((lab, [x for d in G.values() for x in d]) for lab, G in TL.items()), key=lambda r: -sum(x["rs"] for x in r[1]))
    for lab, T in rows:
        if T:
            line(lab[:40], T)
    say(""); say("  G) THE FUTURES BUILD-UP - an alert at the minute GIR's build-up first reached the size (rebuilt from Kite's futures OI):")
    for w in ("LONG BUILD-UP", "SHORT BUILD-UP", "SHORT COVERING", "LONG UNWINDING"):
        for T in BU_CR:
            lab = "%s ₹%d cr+" % (w, T); X = [x for d in (BUL.get(lab) or {}).values() for x in d]
            if X:
                line(lab, X)
                pre = sorted(abs(x["pre"]) * 1 for x in X); late = sum(1 for v in pre if v >= 2)
                say("        the share had already moved %.1f%% (median) when it was identified · %d of %d already 2%%+ · median time %s" % (
                    pre[len(pre) // 2], late, len(X), sorted(x["t"][:5] for x in X)[len(X) // 2]))
    allbu = [x for G in BUL.values() for d in G.values() for x in d]
    if allbu:
        say("    build-up identified EARLY vs LATE (any size, any word, its first alert per share):")
        for lo, hi, nm in ((0, 1, "the share had moved under 1%"), (1, 2, "1-2% already"), (2, 99, "2%+ already - LATE")):
            seen = set(); X = []
            for x in sorted(allbu, key=lambda x: (x["day"], x["t"])):
                if lo <= abs(x["pre"]) < hi and (x["day"], x["s"]) not in seen:
                    seen.add((x["day"], x["s"])); X.append(x)
            if X:
                line(nm, X)
    say(""); say("  D) the first N alerts of each day (A, in time order - what you could really take):")
    for N in (3, 5, 10, 15, 20, 30):
        T = [x for d in sorted({x["day"] for x in TA}) for x in sorted((y for y in TA if y["day"] == d), key=lambda y: y["t"])[:N]]
        if T:
            line("first %d a day" % N, T)
    say(""); say("  E) other exits on the same entries (A) - the real option prices:")
    res = []
    for st in (0.01, 0.015, 0.025):
        for hf in (0.015, 0.025, 0.035):
            for tm in (None, 30, 60, 120):
                for ps in (None, 0.3, 0.4):
                    R_ = [money(x, st, hf, tm, ps) for x in TA]; R_ = [r for r in R_ if r]
                    res.append((sum(r[0] for r in R_), st, hf, tm, ps, sum(1 for r in R_ if r[0] > 0)))
    desc = lambda st, hf, tm, ps: "stop %.1f%% · half +%.1f%% · %s · %s" % (st * 100, hf * 100, "time stop %d min" % tm if tm else "no time stop", "premium stop -%d%%" % (ps * 100) if ps else "no premium stop")
    for tot, st, hf, tm, ps, won in sorted(res, key=lambda r: -r[0])[:8]:
        say("    %-72s → %4d won · ₹%s (₹%s a day)" % (desc(st, hf, tm, ps), won, f0(tot), f0(tot / nd)))
    now = next(r for r in res if (r[1], r[2], r[3], r[4]) == (C.STOP, C.HALF, None, None))
    say("    (the card rule now: ₹%s)" % f0(now[0]))
    best = sorted(res, key=lambda r: -r[0])[0]
    say(""); say("  E2) the same exits in the FUTURE (no premium stop - a future has no premium):")
    fres = []
    for st in (0.01, 0.015, 0.025):
        for hf in (0.015, 0.025, 0.035):
            for tm in (None, 30, 60, 120):
                R_ = [fmoney(x, st, hf, tm) for x in TA]; R_ = [r for r in R_ if r is not None]
                fres.append((sum(R_), st, hf, tm, None, sum(1 for r in R_ if r > 0)))
    for tot, st, hf, tm, ps, won in sorted(fres, key=lambda r: -r[0])[:5]:
        say("    %-72s → %4d won · ₹%s (₹%s a day)" % (desc(st, hf, tm, ps), won, f0(tot), f0(tot / nd)))
    fnow = next(r for r in fres if (r[1], r[2], r[3]) == (C.STOP, C.HALF, None))
    say("    (the card rule now, in the future: ₹%s)" % f0(fnow[0]))
    say(""); say("  F) the best exit with each alert type (does the right exit turn a type green?):")
    for lab, T in rows[:12]:
        if T:
            R_ = [money(x, best[1], best[2], best[3], best[4]) for x in T]; R_ = [r for r in R_ if r]
            tot = sum(r[0] for r in R_)
            fb = sorted(fres, key=lambda r: -r[0])[0]; fu = sum(r for r in (fmoney(x, fb[1], fb[2], fb[3]) for x in T) if r is not None)
            say("    %s %-36s %4d trades · option ₹%s · future ₹%s (each with its best exit above)" % ("✅" if max(tot, fu) > 0 else "❌", lab[:36], len(T), f0(tot), f0(fu)))
    say(""); say("  A) trade by trade, biggest ₹ first - the contract, its premium at entry and at the exit:")
    for x in sorted(TA, key=lambda x: -x["rs"]):
        say("    %s %s %-11s %-22s premium ₹%-8s → ₹%-8s (%+4.0f%%) · share %+.1f%% · %-10s %s · lot %-5d · ₹%s · future ₹%s" % (
            x["day"][5:], x["t"][:5], x["s"], x["ts"], "{:,.2f}".format(x["p0"]), "{:,.2f}".format(x["pe"]), (x["pe"] / x["p0"] - 1) * 100,
            (at(x["Sf"], x["mx"]) / x["P0"] - 1) * x["dir"] * 100, x["how"], C.hm(x["mx"]), x["lot"], f0(x["rs"]), f0(x.get("fs", 0))))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "optreal.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/optreal.txt")


if __name__ == "__main__":
    main()
