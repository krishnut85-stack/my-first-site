#!/usr/bin/env python3
"""wallcheck.py - READ ONLY (changes nothing, sends nothing, asks Zerodha nothing). THE WALL CHECKLIST for tomorrow (Rama, 15 Nov: "check the highest
resistance and highest support for the shares, how close and how far they are - like MANAPPURAM and TMPV - to prepare a checklist for tomorrow").

From GIR's last option chain reading (pins_live.json - 11 strikes around the price, every F&O share), its minute history (data/chainlive.db - how
much the writers added that day) and the futures (dash_state.json - each share's build-up):
  ROOF  = the biggest CALL open interest above the price (the call writers' wall - resistance)
  FLOOR = the biggest PUT open interest below the price (the put writers' wall - support)
  1 ▼ PE WATCH    under a roof 2.5% or less away AND the futures a short build-up (new sellers) - like MANAPPURAM on 13 Nov
  2 ▲ CE WATCH    over a floor 2.5% or less away AND the futures a long build-up (new buyers)
  3 AT THE ROOF / AT THE FLOOR   within 1% of the wall, any futures - watch for the rejection (👀 / 🧱 ring live)
  4 🔒 SQUEEZED   roof and floor both within 2.5% - stuck in a range; the break can be sharp
  5 the full list, the nearest wall first
python3 wallcheck.py              the checklist (all F&O shares)
python3 wallcheck.py SYM SYM      only those shares"""
import os, sys, json, sqlite3, datetime as dt
BASE = "/home/globalbot/intraday" if os.path.isdir("/home/globalbot/intraday") else os.path.dirname(os.path.abspath(__file__))
BASE = os.environ.get("GIR_BASE", BASE)
NEAR_W, AT_W = 2.5, 1.0
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))


def load(p):
    try:
        return json.load(open(os.path.join(BASE, p)))
    except Exception:
        return {}


def walls():
    P = load("pins_live.json")
    spot = P.get("spot") or {}
    when = dt.datetime.fromtimestamp(float(P["t"]), IST) if P.get("t") else None
    out = {}
    for s, rows in (P.get("rows") or {}).items():
        rows = [r for r in (rows or []) if isinstance(r, (list, tuple)) and len(r) >= 4]
        px = spot.get(s)
        if not rows or not px:
            continue
        ex = min(r[0] for r in rows)
        ce = [(float(r[3] or 0), float(r[1])) for r in rows if r[0] == ex and r[2] == "CE" and float(r[1]) > px]
        pe = [(float(r[3] or 0), float(r[1])) for r in rows if r[0] == ex and r[2] == "PE" and float(r[1]) < px]
        R = max(ce) if ce else None
        S = max(pe) if pe else None
        out[s] = {"px": float(px), "ex": ex, "R": R, "S": S}
    return out, when


def growth(day):
    """{(sym, strike, kind): % change of OI that day} from the minute history (only the strikes it keeps)"""
    g = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "data", "chainlive.db"), uri=True, timeout=5)
        first, last = {}, {}
        for t, sym, k, kd, oi in c.execute("select t, sym, strike, kind, oi from pins where d=? order by t", (day,)):
            key = (sym, float(k), kd)
            if oi:
                first.setdefault(key, oi); last[key] = oi
        c.close()
        for key, a in first.items():
            g[key] = (last[key] / a - 1) * 100 if a else None
    except Exception:
        pass
    return g


def fut():
    st = load("dash_state.json")
    return {f.get("s"): f for f in (st.get("fo_paths") or []) if f.get("s")}


def main():
    only = [a.upper() for a in sys.argv[1:]]
    Wl, when = walls()
    if not Wl:
        print("no option chain reading found (pins_live.json) - GIR writes it during market hours; run this after a market day"); return
    day = str(when.date()) if when else ""
    G = growth(day); F = fut()
    rows = []
    for s, w in Wl.items():
        if only and s not in only:
            continue
        px = w["px"]; f = F.get(s) or {}
        R, S = w["R"], w["S"]
        rd = ((R[1] / px - 1) * 100) if R else None
        sd = ((1 - S[1] / px) * 100) if S else None
        rg = G.get((s, R[1], "CE")) if R else None
        sg = G.get((s, S[1], "PE")) if S else None
        bu = (f.get("bu") or "").upper()
        rows.append({"s": s, "px": px, "R": R, "S": S, "rd": rd, "sd": sd, "rg": rg, "sg": sg, "bu": bu, "chg": f.get("chg"), "oi": f.get("oi"), "cr": f.get("cr")})
    def wl(x, side):
        w = x["R"] if side == "R" else x["S"]
        if not w:
            return "-"
        d_ = x["rd"] if side == "R" else x["sd"]; g_ = x["rg"] if side == "R" else x["sg"]
        return "%g %s %.1f L%s %.1f%% %s" % (w[1], "CE" if side == "R" else "PE", w[0] / 1e5, (" (%+.0f%% that day)" % g_) if g_ is not None else "", d_, "up" if side == "R" else "down")
    def futl(x):
        if not x["bu"]:
            return "futures: no clear build-up"
        return "futures: %s%s%s" % (x["bu"], (" · OI %+.1f%%" % x["oi"]) if x["oi"] is not None else "", (" · ₹%s cr" % "{:,.0f}".format(abs(x["cr"]))) if x["cr"] is not None else "")
    def line(x):
        return "  %-11s ₹%-9s %s · ROOF %s · FLOOR %s · %s" % (x["s"], "{:,.2f}".format(x["px"]), ("%+.1f%%" % x["chg"]) if x["chg"] is not None else "", wl(x, "R"), wl(x, "S"), futl(x))
    print("=== THE WALL CHECKLIST · GIR's last option chain reading %s · %d F&O shares · ROOF = the biggest call OI above · FLOOR = the biggest put OI below" % (
        when.strftime("%a %d %b %H:%M") if when else "-", len(rows)))
    print("    (11 strikes around the price - a wall further away is not seen · 'that day' = how much the writers added, where the minute history has it)")
    pe = sorted([x for x in rows if x["rd"] is not None and x["rd"] <= NEAR_W and "SHORT BUILD" in x["bu"]], key=lambda x: x["rd"])
    ce = sorted([x for x in rows if x["sd"] is not None and x["sd"] <= NEAR_W and "LONG BUILD" in x["bu"]], key=lambda x: x["sd"])
    print("\n1 ▼ PE WATCH - under a roof %.1f%% or less away AND new futures sellers (like MANAPPURAM on 13 Nov): %d" % (NEAR_W, len(pe)))
    for x in pe:
        print(line(x)); print("      tomorrow: PE only if it turns under VWAP and stays under %g · out if it closes over %g" % (x["R"][1], x["R"][1]))
    print("\n2 ▲ CE WATCH - over a floor %.1f%% or less away AND new futures buyers: %d" % (NEAR_W, len(ce)))
    for x in ce:
        print(line(x)); print("      tomorrow: CE only if it turns over VWAP and stays over %g · out if it closes under %g" % (x["S"][1], x["S"][1]))
    atr = sorted([x for x in rows if x["rd"] is not None and x["rd"] <= AT_W and x not in pe], key=lambda x: x["rd"])
    ats = sorted([x for x in rows if x["sd"] is not None and x["sd"] <= AT_W and x not in ce], key=lambda x: x["sd"])
    print("\n3 AT THE ROOF - within %.0f%% under the biggest call wall (watch for the rejection, any futures): %d" % (AT_W, len(atr)))
    for x in atr:
        print(line(x))
    print("  AT THE FLOOR - within %.0f%% over the biggest put wall: %d" % (AT_W, len(ats)))
    for x in ats:
        print(line(x))
    sq = sorted([x for x in rows if x["rd"] is not None and x["sd"] is not None and x["rd"] <= NEAR_W and x["sd"] <= NEAR_W], key=lambda x: x["rd"] + x["sd"])
    print("\n4 🔒 SQUEEZED - roof and floor both within %.1f%% (a range; the break can be sharp): %d" % (NEAR_W, len(sq)))
    for x in sq[:25]:
        print(line(x))
    print("\n5 THE FULL LIST - the nearest wall first:")
    for x in sorted(rows, key=lambda x: min(v for v in (x["rd"], x["sd"], 99) if v is not None)):
        print(line(x))
    print("\nREAD: a wall is where option writers bet the price will NOT go. The futures say who is betting on the move. Both the same way + the price")
    print("turning past VWAP = the signal (GIR rings 👀 WATCH at 0.5% from a growing wall, then 🧱 on the rejection). A list to prepare - not a trade.")


if __name__ == "__main__":
    main()
