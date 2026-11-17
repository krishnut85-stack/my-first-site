#!/usr/bin/env python3
"""sharenote.py - patch 357: THE NOTE ON A SHARE (Rama, 17 Nov: "when I hover over the shares there should be a note pad opening saying why the
stock is behaving - or somewhere easy to show the information that is required to know regularly"). One short note for any share name on
GIR's page, from what GIR already holds - nothing is fetched from outside, so it opens at once:
  WHY        GIR's own ranked reasons (whymove.py: results read, exchange filings, the news GIR checked, a broker's call, its sector, the
             market, the futures money, results due) - or plainly "no company news found"
  SECTOR     its sector, the sector's move and rank today (all NSE shares, by size - seclive.py) and this share's part of that move
  LEVELS     against its 20-day high / low and yesterday's close (the levels the 🧪 candidates use)
  MONEY      as bullet points: foreign funds in its sector (NSDL, fortnightly - fpisec.py) · mutual funds: its sector's share of their money
             now against 3 months ago (SEBI, monthly - mfsec.py) · futures: today's build-up and options money · big deals: named bulk / block
             deals · delivery on NSE's last file against its own 10-day normal · FII / DII positions in futures (whole market)
  MARKET     the strongest market-wide headlines of the last hours (Finance Ministry, RBI, SEBI, the Fed, crude ...), marked up or down
  DUE        its results date, if within 14 days
  TODAY      whether it is one of today's 🧪 paper-test candidates
view(sym) -> a dict for dashserve /note. Reads local files only; a share is kept for 45 seconds. Orders nothing, sends nothing.
  python3 sharenote.py RELIANCE"""
import os, re, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C, _U = {}, {"t": 0.0, "sec": {}, "names": {}}


def _j(*path):
    try:
        return json.load(open(os.path.join(D, *path)))
    except Exception:
        return {}


def _universe():
    if time.time() - _U["t"] > 3600 or not _U["sec"]:
        try:
            import seclive
            _U["sec"], _U["names"] = seclive.universe(); _U["t"] = time.time()
        except Exception:
            pass
    return _U["sec"], _U["names"]


def view(sym):
    sym = re.sub(r"[^A-Z0-9&\-]", "", str(sym or "").upper())[:20]
    c = _C.get(sym)
    if c and time.time() - c[0] < 45:
        return c[1]
    now = dt.datetime.now(IST); today = str(now.date())
    out = {"s": sym, "at": now.strftime("%H:%M")}
    px = chg = None
    try:                                                     # WHY - GIR's own reasons
        import whymove
        w = whymove.explain(sym); px, chg = w.get("px"), w.get("chg")
        out["why"] = [str(r.get("t") or "")[:190] for r in (w.get("reasons") or []) if r.get("k") in ("results", "filing", "news", "broker", "event", "global")][:5]
        out["fut"] = [str(r.get("t") or "")[:150] for r in (w.get("reasons") or []) if r.get("k") in ("money", "options")][:2]     # the futures build-up, the options money
        out["nonews"] = not w.get("stock")
    except Exception:
        pass
    if px is None:
        q = (_j("quotes_live.json").get("q") or {}).get(sym)
        if q and len(q) > 1:
            px, chg = q[0], q[1]
    out["px"], out["chg"] = px, chg
    SEC, NAMES = _universe(); sec = SEC.get(sym); out["name"] = (NAMES.get(sym) or "")[:44]
    try:                                                     # SECTOR - its move and rank today, and this share's part of it
        rows = sorted((_j("data", "seclive.json").get("sectors") or []), key=lambda x: -x["chg"])
        i = next((k for k, x in enumerate(rows) if x["name"] == sec), None)
        if i is not None:
            x = rows[i]; out["sector"] = {"name": sec, "chg": x["chg"], "rank": i + 1, "of": len(rows), "up": x.get("up"), "dn": x.get("dn"), "n": x.get("n")}
            W = _j("data", "seclive_w.json").get("w") or {}; tot = sum(W.get(s) or 0 for s in SEC if SEC[s] == sec)
            if chg is not None and W.get(sym) and tot and abs(x["chg"]) >= 0.3:
                out["sector"]["part"] = round(100 * chg * W[sym] / tot / x["chg"])
        elif sec:
            out["sector"] = {"name": sec}
    except Exception:
        pass
    try:                                                     # LEVELS - the 20-day high / low and yesterday's close
        lv = (_j("data", "seccand_lv.json").get("lv") or {}).get(sym)
        if lv and px:
            out["levels"] = {"h20": round(lv[0], 2), "l20": round(lv[1], 2), "yc": round(lv[2], 2) if len(lv) > 2 else None,
                             "to_h20": round(100 * (px / lv[0] - 1), 2), "to_l20": round(100 * (px / lv[1] - 1), 2)}
    except Exception:
        pass
    try:                                                     # MONEY - delivery on NSE's last file against its own 10-day normal
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "extra.db"), uri=True, timeout=3)
        r = [(d, p) for d, p in con.execute("select d, dp from deliv where sym=? order by d desc limit 11", (sym,)) if p is not None]; con.close()
        if len(r) >= 6:
            out["deliv"] = {"day": r[0][0], "pct": round(r[0][1], 1), "normal": round(sum(p for _, p in r[1:]) / (len(r) - 1), 1)}
    except Exception:
        pass
    try:                                                     # MONEY - foreign funds in its sector (NSDL, fortnightly)
        import fpisec
        j = _j("data", "fpisec.json"); F = sorted(k for k, v in (j.get("net") or {}).items() if len(v) >= 12)[::-1]
        ns = next((s for s in (j["net"][F[0]] if F else {}) if sec in (fpisec.gir_groups(s) or ())), None)
        if ns:
            v = [j["net"][k].get(ns) for k in F]; sg = 1 if (v[0] or 0) > 0 else -1; n = 0
            for x in v:
                if x is None or x * sg <= 0:
                    break
                n += 1
            out["fpi"] = {"sector": ns, "to": F[0], "last": round(v[0]) if v[0] is not None else None, "run": sg * n}
    except Exception:
        pass
    try:                                                     # MUTUAL FUNDS - its sector's share of all funds' equity money, now against 3 months ago (SEBI, mfsec.py)
        import mfsec
        S = mfsec.load(); M = sorted(S.get("m") or {}); ns = (out.get("fpi") or {}).get("sector")
        if M and ns:
            H = lambda k: mfsec.by_macro({a: tuple(v) for a, v in S["m"][k].items()}).get(ns)
            t = int(M[-1][:4]) * 12 + int(M[-1][5:]) - 1 - 3; k3 = "%04d-%02d" % (t // 12, t % 12 + 1); now_, old = H(M[-1]), (H(k3) if k3 in S["m"] else None)
            if now_:
                out["mf"] = {"sector": ns, "month": M[-1], "share": round(now_[1], 2), "vs3": round(now_[1] - old[1], 2) if old else None}
    except Exception:
        pass
    try:                                                     # BIG DEALS and WHO - from the last evening's reading (whydesk.py)
        F = _j("data", "whydesk.json").get("facts") or {}
        out["deals"] = [{"kind": x.get("kind"), "date": x.get("date"), "side": x.get("side"), "cr": x.get("cr"), "client": (x.get("client") or "")[:34]} for x in F.get("deals") or [] if x.get("sym") == sym][:3]
        out["who"] = [{"who": str(p.get("who") or "").split(" (")[0], "day": p.get("day"), "idx": p.get("index_fut_net"), "idx1": p.get("index_fut_change_1d"), "stk1": p.get("stock_fut_change_1d")}
                      for p in F.get("participants") or [] if str(p.get("who") or "")[:3] in ("FII", "DII")]
    except Exception:
        pass
    try:                                                     # MARKET NEWS - the strongest market-wide headlines of the last 14 hours (macro.py), up or down
        it = [x for x in (_j("data", "macro.json").get("items") or []) if time.time() - float(x.get("t") or 0) < 14 * 3600 and (x.get("score") or 0) >= 5]
        it.sort(key=lambda x: (-(x.get("score") or 0), -float(x.get("t") or 0)))
        out["macro"] = [{"hm": x.get("hm"), "h": str(x.get("h") or "")[:120], "side": x.get("side") or 0} for x in it[:3]]
    except Exception:
        pass
    try:                                                     # DUE - its results date
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=3)
        r = con.execute("select d from results_cal where sym=? and d>=? and d<=? order by d limit 1", (sym, today, str(now.date() + dt.timedelta(days=14)))).fetchone(); con.close()
        if r:
            out["due"] = r[0]
    except Exception:
        pass
    try:                                                     # TODAY - a 🧪 paper-test candidate?
        st = _j("data", "seccand.json")
        if st.get("day") == today:
            out["cand"] = [{"t": c_["t"], "kind": c_["kind"], "dir": c_["dir"], "px": c_["px"]} for c_ in st.get("cands") or [] if c_.get("s") == sym]
    except Exception:
        pass
    if len(_C) > 500:
        _C.clear()
    _C[sym] = (time.time(), out)
    return out


if __name__ == "__main__":
    print(json.dumps(view(sys.argv[1] if sys.argv[1:] else "RELIANCE"), ensure_ascii=False, indent=1, default=str))
