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
  cd /home/globalbot && set -a && source .env && set +a && cd intraday && python3 optreal.py [YYYY-MM-DD]   -> prints, saves data/optreal.txt"""
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
        self.g = getdata; self.k = core.get_kite(); self.day = dt.date.fromisoformat(day); self.cache = {}
        self.eq = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(self.k.instruments, "NSE") if i.get("instrument_type") == "EQ"}
        self.opt = {}
        for i in getdata.call(self.k.instruments, "NFO"):
            t = i.get("instrument_type")
            if t in ("CE", "PE") and i.get("name"):
                e = i.get("expiry"); e = e if isinstance(e, dt.date) else dt.date.fromisoformat(str(e)[:10])
                if e >= self.day:
                    self.opt.setdefault((i["name"], t), []).append((e, float(i["strike"]), int(i["instrument_token"]), i["tradingsymbol"], int(i.get("lot_size") or 0)))

    def candles(self, token):
        """{minute since 09:15: (open, high, low, close)} for the day"""
        if token in self.cache:
            return self.cache[token]
        out = {}
        try:
            frm = dt.datetime.combine(self.day, dt.time(9, 15)); to = dt.datetime.combine(self.day, dt.time(15, 30))
            for c in self.g.call(self.k.historical_data, token, frm, to, "minute"):
                d = c["date"]; m = d.hour * 60 + d.minute - 555
                out[m] = (float(c["open"]), float(c["high"]), float(c["low"]), float(c["close"]))
        except Exception as ex:
            print("  candles %s: %s" % (token, str(ex)[:60]), flush=True)
        self.cache[token] = out
        return out

    def contract(self, sym, dr, px):
        """the at-the-money option of the nearest expiry: (tradingsymbol, token, lot)"""
        R = self.opt.get((sym, "CE" if dr > 0 else "PE")) or []
        if not R:
            return None
        e0 = min(r[0] for r in R)
        e, k, tok, ts, lot = min((r for r in R if r[0] == e0), key=lambda r: abs(r[1] - px))
        return ts, tok, lot


def at(cs, m):
    """the close at minute m, or the last one before it (an option may not trade every minute)"""
    ks = [k for k in cs if k <= m]
    return cs[max(ks)][3] if ks else None


def walk(S, m0, P0, dr, st, hf):
    """on the SHARE's minute candles: -> (half minute or None, exit minute, how)"""
    half = None; stop = -st
    for m in sorted(k for k in S if k > m0):
        o, h, l, c = S[m]
        bad = ((l if dr > 0 else h) / P0 - 1) * dr; good = ((h if dr > 0 else l) / P0 - 1) * dr
        if bad <= stop:
            return half, m, ("STOP" if half is None else "HALF+ENTRY")
        if half is None and good >= hf:
            half = m; stop = 0.0
        if m >= C.CLOSE_M:
            return half, m, ("15:10" if half is None else "HALF+15:10")
    return half, (max(S) if S else m0), "LAST"


def money(t, st=C.STOP, hf=C.HALF):
    hm_, mx, how = walk(t["S"], t["m0"], t["P0"], t["dir"], st, hf)
    pe = at(t["O"], mx)
    if pe is None:
        return None
    if hm_ is None:
        return (pe - t["p0"]) * t["lot"], how, mx, pe
    ph = at(t["O"], hm_) or pe
    return (0.5 * (ph - t["p0"]) + 0.5 * (pe - t["p0"])) * t["lot"], how, mx, pe


def main():
    day = sys.argv[1] if sys.argv[1:] else str(dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30))).date())
    try:
        K = Kite(day)
    except Exception as ex:
        say("Kite not available (%s) - run it with the .env sourced, after GIR's morning login" % str(ex)[:100]); return
    A = [a for a in C.alerts(day) if a["s"] in K.eq and ((a["s"], "CE") in K.opt or (a["s"], "PE") in K.opt)]
    say("📒 %s · GIR'S OWN ALERTS IN THE REAL OPTION (Kite minute prices) · %d alert lines with CE/PE on %d F&O shares" % (day, len(A), len({a["s"] for a in A})))
    say("  the at-the-money option of the nearest expiry · entry at the alert minute · stop 2.5% / half +1.5% on the share · rest out 15:10 · 1 lot, before charges")
    say("  fetching the minute candles from Kite (2 per share - a few minutes) ...")
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
                    x = dict(a, S=S, O=O, m0=m0, P0=P0, ts=c[0], lot=c[2], p0=p0)
                    r = money(x)
                    if r:
                        x["rs"], x["how"], x["mx"], x["pe"] = r
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

    def line(name, T):
        won = sum(1 for x in T if x["rs"] > 0); tot = sum(x["rs"] for x in T)
        say("  %s %-44s %4d trades · %4d won (%2d%%) · ₹%10s · ₹%s a trade" % ("✅" if tot > 0 else "❌", name, len(T), won, round(100 * won / max(1, len(T))), f0(tot), f0(tot / max(1, len(T)))))

    TA = first(A); TB = first([a for a in A if a["call"]])
    say("")
    line("A) the FIRST alert on each share (any line)", TA)
    line("B) the first REAL call (no WATCH / IN DOUBT)", TB)
    say(""); say("  C) each alert type on its own (its first alert per share):")
    labs = {}
    for a in A:
        labs.setdefault(a["lab"], []).append(a)
    rows = sorted(((lab, first(G)) for lab, G in labs.items()), key=lambda r: -sum(x["rs"] for x in r[1]))
    for lab, T in rows:
        if T:
            line(lab[:44], T)
    say(""); say("  D) the first N alerts of the day (A, in time order - what you could really take):")
    TS = sorted(TA, key=lambda x: x["t"])
    for N in (5, 10, 15, 20, 30, 50):
        if len(TS) >= min(N, 1):
            T = TS[:N]; won = sum(1 for x in T if x["rs"] > 0); tot = sum(x["rs"] for x in T)
            say("    %s first %-3d %3d won (%2d%%) · ₹%10s · alert no. %d rang at %s" % ("✅" if tot > 0 else "❌", N, won, round(100 * won / len(T)), f0(tot), len(T), T[-1]["t"][:5]))
    say(""); say("  E) other exits on the same entries (A) - the real option prices:")
    res = []
    for st in (0.01, 0.015, 0.025, 0.035):
        for hf in (0.015, 0.025, 0.035):
            R = [money(x, st, hf) for x in TA]; R = [r for r in R if r]
            res.append((sum(r[0] for r in R), st, hf, sum(1 for r in R if r[0] > 0)))
    for tot, st, hf, won in sorted(res, reverse=True)[:6]:
        say("    stop %.1f%% · half out +%.1f%% → %3d won · ₹%s%s" % (st * 100, hf * 100, won, f0(tot), "   ← the card rule now" if (st, hf) == (C.STOP, C.HALF) else ""))
    now = next(r for r in res if (r[1], r[2]) == (C.STOP, C.HALF))
    say("    (the card rule now, stop 2.5%% · half +1.5%%: ₹%s)" % f0(now[0]))
    say(""); say("  A) trade by trade, biggest ₹ first - the contract, its premium at entry and at the exit:")
    for x in sorted(TA, key=lambda x: -x["rs"]):
        say("    %s %-11s %-22s premium ₹%-8s → ₹%-8s (%+4.0f%%) · share %+.1f%% · %-10s %s · lot %-5d · ₹%s" % (
            x["t"][:5], x["s"], x["ts"], "{:,.2f}".format(x["p0"]), "{:,.2f}".format(x["pe"]), (x["pe"] / x["p0"] - 1) * 100,
            (at(x["S"], x["mx"]) / x["P0"] - 1) * x["dir"] * 100, x["how"], C.hm(x["mx"]), x["lot"], f0(x["rs"])))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "optreal.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/optreal.txt")


if __name__ == "__main__":
    main()
