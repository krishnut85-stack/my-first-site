#!/usr/bin/env python3
"""seccand.py - patch 355: THE SECTOR CANDIDATES, LIVE - A PAPER TEST (no sound, no BUY card). sectoropt.py (14 days, real option prices, the 2-hour
rule) found two picks with a lean:
  B  an F&O share PAST ITS 20-DAY HIGH (CE) / LOW (PE) while its sector is one of the 3 best / worst with 70%+ of its shares that way, the share
     on the right side of VWAP - checked at 10:00 and 10:30            (94 trades, 52% won, +₹39,280, 9 of 13 days green)
  A  PE on the 3 DRIVERS of the WEAKEST sector - checked at 10:30, 11:00, 12:00   (44 trades, 64% won, +₹17,631, 7 of 11 days green)
  E  CE at 09:45 on a share that fell 2%+ yesterday WITH its theme (355b)   (88 trades, 53% won, +₹97,000 with the card rule, 6 of 10 days green)
One big day carried B and the market was rising: promising, not proven. So GIR only SHOWS them and keeps score:
  · tick()   called by seclive.py every pass: at each check time (a 4-minute window - a missed time is NOT made up later) the candidates are written
             to data/seccand.json: time, kind, share, CE/PE, the price, the sector and why. A share once a day per kind.
  · score()  after 15:40: every candidate priced in the real at-the-money option (Kite minute prices): stop 2.5% on the share, out after 2 hours,
             the rest at 15:10 - 1 lot, before charges. The day goes into data/seccand_log.json (the running record the page shows).
Reads only. Orders nothing, sends nothing.      python3 seccand.py score [YYYY-MM-DD]     python3 seccand.py show"""
import os, sys, json, time, threading, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "seccand.json")
LOG = os.path.join(D, "data", "seccand_log.json")
LVF = os.path.join(D, "data", "seccand_lv.json")
TRIG = (("09:45", "E"), ("10:00", "B"), ("10:30", "AB"), ("11:00", "A"), ("12:00", "A"))
# patch 355b: E = BOUNCE - a share that fell 2%+ yesterday WITH its theme (the theme -1%+; the share not far worse than the theme): CE at 09:45.
#   sectoropt.py, 14 days, real option: 88 trades, 53% won, +₹97,000 with the CARD rule (stop 2.5%, half +1.5%, rest 15:10) - scored that way.
RULE = {"A": (0.025, 0.035, 120), "B": (0.025, 0.035, 120), "E": (0.025, 0.015, None)}
WINDOW_MIN = 4
_lv = {"day": None, "lv": {}, "busy": False}


def _load(path, default):
    try:
        return json.load(open(path))
    except Exception:
        return default


def _save(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path + ".tmp", "w"), ensure_ascii=False, separators=(",", ":")); os.replace(path + ".tmp", path)


def state(day):
    s = _load(OUT, {})
    return s if s.get("day") == day else {"day": day, "done": {}, "cands": [], "scored": False}


def levels(kite, FO, day):
    """{sym: [the highest high, the lowest low] of the 20 trading days before today} - Kite's day candles, once a day, kept on disk"""
    j = _load(LVF, {})
    if j.get("day") == day and len(j.get("lv") or {}) > 50:
        return j["lv"]
    import getdata
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    d0 = dt.date.fromisoformat(day); frm = dt.datetime.combine(d0 - dt.timedelta(days=45), dt.time(9, 15)); to = dt.datetime.combine(d0 - dt.timedelta(days=1), dt.time(15, 30))
    lv = {}
    for s in sorted(FO):
        if s not in tok:
            continue
        try:
            rows = [r for r in kite.historical_data(tok[s], frm, to, "day") if r["date"].date() < d0][-20:]; time.sleep(0.36)
            if len(rows) >= 10:
                lv[s] = [max(float(r["high"]) for r in rows), min(float(r["low"]) for r in rows), float(rows[-1]["close"]), float(rows[-2]["close"])]   # + the last two closes (E)
        except Exception as ex:
            print("seccand levels %s: %s" % (s, str(ex)[:60]), flush=True)
    if len(lv) > 50:
        _save({"day": day, "lv": lv}, LVF)
    return lv


def _levels_bg(kite, FO, day):
    try:
        _lv["lv"] = levels(kite, FO, day); _lv["day"] = day
        print("seccand: 20-day levels for %d F&O shares" % len(_lv["lv"]), flush=True)
    except Exception as ex:
        print("seccand levels: %s" % str(ex)[:120], flush=True)
    _lv["busy"] = False


def themes():
    try:
        import themestudy
        return themestudy.THEMES
    except Exception:
        return {}


def find_bounce(Q, FO, LV):
    """E: [(kind, sym, +1, price, theme, theme's fall yesterday, why)]"""
    out = []
    for t, (fo, also, why) in themes().items():
        y = {s: LV[s][2] / LV[s][3] - 1 for s in (fo + " " + also).split() if s in LV and len(LV[s]) >= 4 and LV[s][3]}
        if len(y) < 2:
            continue
        yth = sum(y.values()) / len(y)
        if yth > -0.01:
            continue
        for s in fo.split():
            if s in y and s in FO and s in Q and y[s] <= -0.02 and y[s] >= 2.0 * yth - 0.01:
                out.append(("E", s, 1, Q[s][0], t, yth, "fell %.1f%% yesterday with its theme (%s %.1f%%) - a wave, not its own news: the next-morning bounce" % (y[s] * 100, t, yth * 100)))
    return out


def find(kinds, SEC, W, Q, FO, LV, vwap):
    """the candidates now: [(kind, sym, dir, price, sector, sector %, why)] - the same rules as sectoropt.py"""
    G = {}
    for s, sec in SEC.items():
        if s in Q and (W.get(s) or not W):
            lp, pc = Q[s]; G.setdefault(sec, []).append((s, lp / pc - 1, W.get(s) or 1.0, lp))
    sc = {}
    for sec, R in G.items():
        if len(R) >= 5:
            w = sum(r[2] for r in R)
            sc[sec] = (sum(r[1] * r[2] for r in R) / w, sum(1 for r in R if r[1] > 0) / len(R), sum(1 for r in R if r[1] < 0) / len(R), w)
    if len(sc) < 8:
        return []
    at = sorted(sc, key=lambda k: -sc[k][0]); out = []
    if "A" in kinds:
        sec = at[-1]; mv = sc[sec][0]
        if mv < 0:
            for s, c, wt, lp in sorted([r for r in G[sec] if r[0] in FO and r[1] < 0], key=lambda r: r[1] * r[2])[:3]:
                out.append(("A", s, -1, lp, sec, mv, "a driver of the weakest sector (%s %+.2f%%) - the share %+.1f%%, %d%% of the sector's move" % (
                    sec, mv * 100, c * 100, round(100 * c * wt / sc[sec][3] / mv) if mv else 0)))
    if "B" in kinds:
        for rk in (1, 2, 3):
            for sec, dr in ((at[rk - 1], 1), (at[-rk], -1)):
                mv = sc[sec][0]; br = sc[sec][1] if dr > 0 else sc[sec][2]
                if mv * dr <= 0 or br < 0.7:
                    continue
                for s, c, wt, lp in G[sec]:
                    lv, vw = LV.get(s), vwap.get(s)
                    if s in FO and lv and vw and ((lp > lv[0]) if dr > 0 else (lp < lv[1])) and (lp - vw) * dr > 0:
                        out.append(("B", s, dr, lp, sec, mv, "past its 20-day %s ₹%s with its sector (%s %+.2f%%, no.%d %s, %d%% of its shares that way) · %s VWAP" % (
                            "high" if dr > 0 else "low", "{:,.2f}".format(lv[0] if dr > 0 else lv[1]), sec, mv * 100, rk, "best" if dr > 0 else "worst", round(br * 100), "above" if dr > 0 else "below")))
    return out


def tick(n, SEC, W, Q, FO, kite):
    """seclive.py calls this every pass in market hours. Never raises."""
    try:
        day = str(n.date()); hm = n.strftime("%H:%M")
        if _lv["day"] != day and not _lv["busy"] and hm >= "09:18":
            also = {s for fo, al, _ in themes().values() for s in al.split()}
            _lv["busy"] = True; threading.Thread(target=_levels_bg, args=(kite, set(FO) | also, day), daemon=True).start()
        st = state(day); changed = False
        for t, kinds in TRIG:
            if t in st["done"] or hm < t:
                continue
            late = (n.hour * 60 + n.minute) - (int(t[:2]) * 60 + int(t[3:]))
            if late > WINDOW_MIN:
                st["done"][t] = "missed (GIR was not watching at %s)" % t; changed = True; continue
            if ("B" in kinds or "E" in kinds) and _lv["day"] != day:
                if late < WINDOW_MIN:
                    continue                                                 # the 20-day levels are still being fetched - try again on the next pass
                kinds = kinds.replace("B", "").replace("E", "")
            vwap = {}
            if "B" in kinds:
                import getdata
                fo = sorted(s for s in FO if s in Q)
                for i in range(0, len(fo), 450):
                    q = getdata.call(kite.quote, ["NSE:" + s for s in fo[i:i + 450]]) or {}
                    for k, v in q.items():
                        if v.get("average_price"):
                            vwap[k.split(":", 1)[1]] = float(v["average_price"])
            have = {(c["kind"], c["s"]) for c in st["cands"]}; new = 0
            LV_ = _lv["lv"] if _lv["day"] == day else {}
            for kind, s, dr, lp, sec, mv, why in find(kinds, SEC, W, Q, FO, LV_, vwap) + (find_bounce(Q, FO, LV_) if "E" in kinds else []):
                if (kind, s) not in have:
                    have.add((kind, s)); new += 1
                    st["cands"].append({"t": t, "kind": kind, "s": s, "dir": dr, "px": round(lp, 2), "sec": sec, "secchg": round(mv * 100, 2), "why": why})
            st["done"][t] = "%d new" % new; changed = True
            print("seccand %s: %d new candidates (%s)" % (t, new, kinds or "no levels yet"), flush=True)
        if changed:
            st["at"] = n.strftime("%H:%M:%S"); _save(st, OUT)
    except Exception as ex:
        print("seccand tick: %s" % str(ex)[:160], flush=True)


def score(day=None):
    """every candidate of the day in the real option: stop 2.5% on the share, out after 2 hours, the rest at 15:10. -> the day's line in the log"""
    import optreal as OR
    day = day or str(dt.datetime.now(IST).date())
    st = _load(OUT, {})
    if st.get("day") != day or not st.get("cands"):
        return None
    K = OR.Kite(day); tot = {"A": [0, 0, 0.0], "B": [0, 0, 0.0], "E": [0, 0, 0.0]}
    for c in st["cands"]:
        try:
            if c["s"] not in K.eq:
                continue
            Sm = K.candles(K.eq[c["s"]]); tm = int(c["t"][:2]) * 60 + int(c["t"][3:]) - 555
            m0 = next((m for m in sorted(Sm) if m >= tm), None)
            if m0 is None:
                continue
            P0 = Sm[m0][3]; k = K.contract(c["s"], c["dir"], P0)
            if not k:
                continue
            O = K.candles(k[1]); p0 = OR.at(O, m0)
            if not p0:
                continue
            x = {"S": sorted((a,) + v for a, v in Sm.items()), "O": OR.ff(O), "m0": m0, "P0": P0, "dir": c["dir"], "lot": k[2], "p0": p0}
            r = OR.money(x, *RULE.get(c["kind"], RULE["A"]))
            if r:
                c["opt"] = {"ts": k[0], "p0": round(p0, 2), "pe": round(r[3], 2), "rs": round(r[0]), "how": r[1], "out": OR.C.hm(r[2]), "lot": k[2]}
                a = tot[c["kind"]]; a[0] += 1; a[1] += r[0] > 0; a[2] += r[0]
        except Exception as ex:
            print("seccand score %s: %s" % (c.get("s"), str(ex)[:80]), flush=True)
    st["scored"] = True; _save(st, OUT)
    lg = _load(LOG, {"days": {}}); lg["days"][day] = {k: [v[0], v[1], round(v[2])] for k, v in tot.items()}; _save(lg, LOG)
    return tot


def after_close(n):
    """seclive.py calls this after the close: score once a day, from 15:40. Never raises."""
    try:
        day = str(n.date()); st = _load(OUT, {})
        if n.strftime("%H:%M") >= "15:40" and st.get("day") == day and st.get("cands") and not st.get("scored"):
            t = score(day); print("seccand scored %s: %s" % (day, t), flush=True)
    except Exception as ex:
        print("seccand after_close: %s" % str(ex)[:160], flush=True)


def view():
    """what the page shows: today's candidates + the running record"""
    st = _load(OUT, {}); lg = _load(LOG, {"days": {}})
    rec = {"A": [0, 0, 0, 0, 0], "B": [0, 0, 0, 0, 0], "E": [0, 0, 0, 0, 0]}  # trades, won, ₹, days, green days
    for d, v in sorted(lg.get("days", {}).items()):
        for k in "ABE":
            a = v.get(k) or [0, 0, 0]
            if a[0]:
                r = rec[k]; r[0] += a[0]; r[1] += a[1]; r[2] += a[2]; r[3] += 1; r[4] += a[2] > 0
    return {"day": st.get("day"), "at": st.get("at"), "done": st.get("done") or {}, "cands": st.get("cands") or [], "scored": bool(st.get("scored")), "record": rec,
            "days": len(lg.get("days", {})), "t": time.time()}


if __name__ == "__main__":
    if sys.argv[1:2] == ["score"]:
        print(score(sys.argv[2] if sys.argv[2:] else None))
    else:
        v = view(); print("candidates %s · checked %s · record %s" % (v["day"], v["done"], v["record"]))
        for c in v["cands"]:
            o = c.get("opt")
            print("  %s %s %-11s %s at ₹%s · %s%s" % (c["t"], c["kind"], c["s"], "CE" if c["dir"] > 0 else "PE", c["px"], c["why"][:90], (" · option ₹%s → ₹%s = ₹%s (%s %s)" % (o["p0"], o["pe"], o["rs"], o["how"], o["out"])) if o else ""))
