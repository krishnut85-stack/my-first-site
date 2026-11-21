#!/usr/bin/env python3
"""secmoney.py - patch 360: 💰 SECTOR MONEY - investment and disinvestment, every sector on one board (Rama, 17 Nov: "let's not drift away from
finding the sector investment and disinvestment ... we want to complete also about the sectors"). One row a sector, from what GIR holds:
  TODAY          its move and rank (all NSE shares, by size - seclive.py), shares up / down, the shares pushing it
  FOREIGN FUNDS  NSDL's last fortnights: net buying / selling (₹ crore), the run ("BUYING 4 in a row"), the last 3 months as a % of what they hold
  MUTUAL FUNDS   SEBI's last month: the sector's share of all funds' equity money and its change in 3 months (leaning in / out)
  DELIVERY       NSE's last file: the value taken home against the sector's 10-day normal · the last 5 days against the 20 before
  PRICE          against the whole market over 5 and 60 trading days · the average RSI of its shares (above 70 overbought, under 30 oversold)
  WHO            a plain label from the two fund records: BOTH BUYING · BOTH SELLING · FUNDS BUY, FOREIGNERS SELL · FOREIGNERS BUY, FUNDS SELL
Several GIR sectors share one fund sector (banks / NBFC / insurance / capital markets = Financial Services; pharma / hospitals = Healthcare):
the fund columns then show the shared figure. Facts only - which of them lead the price is what fpisec / mfsec / flowtest / flowpath test.
view() -> dashserve /secmoney. Local files only (daily prices: the files the studies keep in data/secdaily). Orders nothing, sends nothing.
  python3 secmoney.py"""
import os, re, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
_V, _P = {"t": 0.0, "v": None}, {"t": 0.0, "v": None}


def _j(*p):
    try:
        return json.load(open(os.path.join(D, *p)))
    except Exception:
        return {}


def _prices():
    """per share from the newest daily file kept: (last close, 5-day return, 60-day return, RSI 14, the file's last day) - worked out once in 6 hours"""
    if _P["v"] is not None and time.time() - _P["t"] < 6 * 3600:
        return _P["v"]
    import numpy as np
    C = os.path.join(D, "data", "secdaily"); best = {}; out = {}
    for f in (os.listdir(C) if os.path.isdir(C) else []):
        m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)_(\d+)\.npy$", f)
        if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
            best[m.group(1)] = (m.group(2), f)
    for k, (_, f) in best.items():
        try:
            a = np.load(os.path.join(C, f)); c = a[:, 4]
            if len(c) < 62:
                continue
            d = np.diff(c[-90:]); up, dn = np.where(d > 0, d, 0.0), np.where(d < 0, -d, 0.0); au, ad = up[:14].mean(), dn[:14].mean()
            for i in range(14, len(d)):
                au = (au * 13 + up[i]) / 14; ad = (ad * 13 + dn[i]) / 14
            out[k] = (float(c[-1]), float(c[-1] / c[-6] - 1), float(c[-1] / c[-61] - 1), 100.0 if ad == 0 else float(100 - 100 / (1 + au / ad)), int(a[-1, 0]))
        except Exception:
            pass
    _P["v"], _P["t"] = out, time.time()
    return out


def view():
    if _V["v"] is not None and time.time() - _V["t"] < 120:
        return _V["v"]
    import seclive, fpisec
    SEC, _n = seclive.universe(); W = _j("data", "seclive_w.json").get("w") or {}
    key = lambda s: re.sub(r"[^A-Z0-9]", "_", s); PX = _prices()
    rows = {}
    sl = _j("data", "seclive.json"); today = sorted(sl.get("sectors") or [], key=lambda x: -x["chg"])
    for i, x in enumerate(today):
        rows[x["name"]] = {"name": x["name"], "chg": x["chg"], "rank": i + 1, "up": x.get("up"), "dn": x.get("dn"), "n": x.get("n"), "fo": x.get("fo"),
                           "push": (x.get("top") if x["chg"] >= 0 else x.get("bot")) or []}
    for sec in set(SEC.values()):
        rows.setdefault(sec, {"name": sec})
    # price: against the market over 5 and 60 days, the average RSI
    G = {}; tot = [0.0, 0.0, 0.0]; last = 0
    for s, sec in SEC.items():
        p = PX.get(key(s)); w = W.get(s) or 0
        if p and w:
            g = G.setdefault(sec, [0.0, 0.0, 0.0, 0.0, 0]); g[0] += w; g[1] += w * p[1]; g[2] += w * p[2]; g[3] += p[3]; g[4] += 1
            tot[0] += w; tot[1] += w * p[1]; tot[2] += w * p[2]; last = max(last, p[4])
    for sec, g in G.items():
        if g[4] >= 4 and tot[0]:
            rows[sec].update({"r5": round(100 * (g[1] / g[0] - tot[1] / tot[0]), 2), "r60": round(100 * (g[2] / g[0] - tot[2] / tot[0]), 2), "rsi": round(g[3] / g[4])})
    # delivery: the value taken home, the last file against the 10 days before; the last 5 days against the 20 before
    try:
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=5)
        days = [r[0] for r in con.execute("select distinct d from deliv order by d desc limit 26")]; DV = {}
        if len(days) >= 6:
            for d, s, dq in con.execute("select d, sym, dq from deliv where d>=?", (days[-1],)):
                p = PX.get(key(s)); sec = SEC.get(s)
                if p and sec and dq:
                    DV.setdefault(sec, {}).setdefault(d, 0.0); DV[sec][d] += dq * p[0] / 1e7
            for sec, g in DV.items():
                a = g.get(days[0]); prev = [g[d] for d in days[1:11] if d in g]; l5 = [g[d] for d in days[:5] if d in g]; b20 = [g[d] for d in days[5:25] if d in g]
                if a and len(prev) >= 3 and sum(prev):
                    rows[sec]["deliv"] = {"day": days[0], "cr": round(a), "x10": round(a / (sum(prev) / len(prev)), 2),
                                          "build": round((sum(l5) / len(l5)) / (sum(b20) / len(b20)), 2) if len(l5) >= 4 and len(b20) >= 10 and sum(b20) else None}
        con.close()
    except Exception:
        pass
    # foreign funds (NSDL) and mutual funds (SEBI): by the fund sector the GIR sector belongs to
    fj = _j("data", "fpisec.json"); F = sorted(k for k, v in (fj.get("net") or {}).items() if len(v) >= 12)[::-1]; fends = F[:4]; mfm = None
    MF, MF3 = {}, {}
    try:
        import mfsec
        S = mfsec.load(); M = sorted(S.get("m") or {})
        if M:
            mfm = M[-1]; MF = mfsec.by_macro({a: tuple(v) for a, v in S["m"][M[-1]].items()})
            t = int(M[-1][:4]) * 12 + int(M[-1][5:]) - 1 - 3; k3 = "%04d-%02d" % (t // 12, t % 12 + 1)
            MF3 = mfsec.by_macro({a: tuple(v) for a, v in S["m"][k3].items()}) if k3 in S["m"] else {}
    except Exception:
        pass
    for sec, r in rows.items():
        ns = next((s for s in (fj["net"][F[0]] if F else {}) if sec in (fpisec.gir_groups(s) or ())), None)
        if not ns:
            continue
        r["fund_sector"] = ns
        v = [fj["net"][k].get(ns) for k in F]; sg = 1 if (v[0] or 0) > 0 else -1; n = 0
        for x in v:
            if x is None or x * sg <= 0:
                break
            n += 1
        held = next((fj["auc"][a].get(ns) for a in sorted(fj.get("auc") or {}, reverse=True) if fj["auc"][a].get(ns)), None)
        t6 = sum(x for x in v[:6] if x is not None)
        r["fpi"] = {"v": [round(x) if x is not None else None for x in v[:4]], "run": sg * n, "tot": round(t6), "pct": round(100 * t6 / held, 2) if held else None}
        if ns in MF:
            r["mf"] = {"share": round(MF[ns][1], 2), "vs3": round(MF[ns][1] - MF3[ns][1], 2) if ns in MF3 else None}
        f = r["fpi"]["run"]; m = (r.get("mf") or {}).get("vs3")
        if m is not None and abs(m) >= 0.2 and abs(f) >= 2:
            r["who"] = "BOTH BUYING" if f > 0 and m > 0 else "BOTH SELLING" if f < 0 and m < 0 else "FUNDS BUY, FOREIGNERS SELL" if m > 0 else "FOREIGNERS BUY, FUNDS SELL"
    out = {"t": time.time(), "at": sl.get("at"), "day": sl.get("day"), "rows": sorted(rows.values(), key=lambda r: -(r.get("chg") if r.get("chg") is not None else -99)),
           "fpi_ends": fends, "mf_month": mfm, "prices_to": str(dt.date.fromordinal(last)) if last else None}
    _V["v"], _V["t"] = out, time.time()
    return out


if __name__ == "__main__":
    v = view(); print("sector money · today %s %s · foreign funds to %s · mutual funds %s · daily prices to %s" % (v["day"], v["at"], (v["fpi_ends"] or ["none"])[0], v["mf_month"], v["prices_to"]))
    for r in v["rows"]:
        f, m, d = r.get("fpi"), r.get("mf"), r.get("deliv")
        print("  %-26s %7s │ FPI %-22s │ MF %-16s │ deliv %-12s │ 60d %6s RSI %s │ %s" % (r["name"], ("%+.2f%%" % r["chg"]) if r.get("chg") is not None else "—",
              ("%+d cr, run %+d" % (f["v"][0] or 0, f["run"])) if f else "—", ("%.2f%% %+.2f pt" % (m["share"], m["vs3"] or 0)) if m else "—",
              ("%.2fx / %s" % (d["x10"], d["build"])) if d else "—", ("%+.1f%%" % r["r60"]) if r.get("r60") is not None else "—", r.get("rsi", "—"), r.get("who", "")))
