#!/usr/bin/env python3
"""callwhy.py - patch 373: WHY NOW, ON EVERY BUY CALL (Rama, 17 Nov 12:00: ANGELONE rang BUY CE at 09:20 and went +7.3% - "why was this not
informed to me? All these things - this is what I was expecting when the alarm rings". GIR knew last night's capital-gains tax news, knew it
hit capital markets, knew ANGELONE moved with its whole sector - and the card said none of it, so it looked like the six other calls of
those 15 minutes, which went -1.7% to +0.3%).
view(sym, dir) -> for one BUY call, from what GIR already holds (nothing fetched from outside - it answers at once):
  NEWS      last night's 🌙 overnight list (overnight.py): a story naming THIS share, or a share of ITS SECTOR - and whether its direction
            agrees with the call. A call whose share or sector is in the news its way is marked NEWS-BACKED.
  SECTOR    its sector now (all NSE shares, by size - seclive): % today, rank, shares up / down, ⚠ when one company is most of it, and a
            🚀 run today (secsurge.py)
  PEERS     its sector's other F&O shares moving the same way (many = the sector, alone = the share's own story)
  THE SHARE its own news GIR found (whymove), the futures build-up, against its 20-day high / low, results due, today's 🧪 candidate
            (all from sharenote.py)
Nothing here is a tested edge by itself - the card says which parts were tested elsewhere. Kept for 30 seconds per share. Orders nothing.
  python3 callwhy.py ANGELONE 1"""
import os, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {}


def _j(*p):
    try:
        return json.load(open(os.path.join(D, *p)))
    except Exception:
        return {}


def view(sym, dr=1):
    import re
    sym = re.sub(r"[^A-Z0-9&\-]", "", str(sym or "").upper())[:20]; dr = -1 if str(dr).strip() in ("-1", "dn", "down", "PE") else 1
    c = _C.get((sym, dr))
    if c and time.time() - c[0] < 30:
        return c[1]
    today = str(dt.datetime.now(IST).date())
    out = {"s": sym, "dir": dr, "news": [], "backed": False, "peers": {}, "bul": []}
    try:
        import sharenote
        N = sharenote.view(sym)
    except Exception:
        N = {}
    try:
        import seclive
        SEC, _ = seclive.universe()
    except Exception:
        SEC = {}
    sec = SEC.get(sym) or ((N.get("sector") or {}).get("name"))
    out["sector_name"] = sec
    # NEWS - last night's overnight list: this share, or a share of its sector
    on = _j("data", "overnight.json")
    if on.get("day") == today:
        for it in on.get("items") or []:
            sh = [str(s).upper() for s in it.get("shares") or []]
            how = "this share" if sym in sh else ("its sector - %s named" % ", ".join(s for s in sh if SEC.get(s) == sec)) if sec and any(SEC.get(s) == sec for s in sh) else None
            if not how:
                continue
            d = {"up": 1, "down": -1}.get(it.get("dir"), 0)
            agree = d == dr
            out["news"].append({"t": it.get("time"), "h": str(it.get("headline") or "")[:150], "how": how, "dir": it.get("dir"), "strength": it.get("strength"),
                                "why": str(it.get("why") or "")[:120], "agree": agree})
            if agree and it.get("strength") in ("strong", "moderate"):
                out["backed"] = True
    # SECTOR now, and a run today
    sl = _j("data", "seclive.json"); S = sorted(sl.get("sectors") or [], key=lambda x: -x["chg"])
    x = next((y for y in S if y["name"] == sec), None)
    if x:
        out["sector"] = {"name": sec, "chg": x["chg"], "rank": S.index(x) + 1, "of": len(S), "up": x.get("up"), "dn": x.get("dn"), "n": x.get("n"), "one": x.get("one")}
        F = [f for f in (x.get("fol") or []) if f[0] != sym]
        same = [f for f in F if f[1] * dr > 0.3]
        out["peers"] = {"same": len(same), "of": len(F), "top": [[f[0], f[1]] for f in sorted(same, key=lambda f: -f[1] * dr)[:4]]}
        runs = [e for e in (sl.get("surge") or []) if e.get("sec") == sec and e.get("dir") == dr]
        if runs:
            out["run"] = {"t": runs[-1]["t"], "late": runs[-1].get("late"), "r": runs[-1].get("r")}
    # THE SHARE - from the note
    out["own"] = (N.get("why") or [])[:2]; out["nonews"] = N.get("nonews")
    out["fut"] = (N.get("fut") or [])[:1]; out["levels"] = N.get("levels"); out["due"] = N.get("due"); out["cand"] = N.get("cand") or []
    out["chg"] = N.get("chg"); out["px"] = N.get("px")
    # the bullets, in the order a trader reads them
    B = out["bul"]
    for n in out["news"][:2]:
        B.append(("🗞 %s last night (%s) - %s%s" % ("NEWS FOR" if n["agree"] else "NEWS AGAINST" if n["dir"] in ("up", "down") else "NEWS, direction unclear,", n["how"], n["h"],
                                                      (" · " + n["why"]) if n["why"] else "")))
    if not out["news"]:
        B.append("🗞 nothing for this share or its sector in last night's list")
    if x:
        s_ = out["sector"]; p_ = out["peers"]
        B.append("🏭 %s %+.2f%% today, no.%d of %d · %s of its %s shares up%s%s" % (sec.upper(), s_["chg"], s_["rank"], s_["of"], s_["up"], s_["n"],
                 (" · 🚀 ran at %s%s" % (out["run"]["t"], " (late)" if out["run"].get("late") else "")) if out.get("run") else "",
                 (" · ⚠ mostly %s" % s_["one"][0]) if s_.get("one") else ""))
        if p_.get("of"):
            B.append("👥 %d of its %d other F&O shares moving the same way%s" % (p_["same"], p_["of"], (": " + ", ".join("%s %+.1f%%" % (a, b) for a, b in p_["top"])) if p_["top"] else
                                                                                  " - the share is moving on its own"))
    for w in out["own"]:
        B.append("📰 " + w)
    for f in out["fut"]:
        B.append("📈 " + f)
    lv = out["levels"]
    if lv:
        B.append("📏 %s its 20-day high ₹%s (%+.1f%%)" % ("past" if lv["to_h20"] > 0 else "below", "{:,.1f}".format(lv["h20"]), lv["to_h20"]) if dr > 0 else
                 "📏 %s its 20-day low ₹%s (%+.1f%%)" % ("past" if lv["to_l20"] < 0 else "above", "{:,.1f}".format(lv["l20"]), lv["to_l20"]))
    if out["due"]:
        B.append("📅 results due %s" % out["due"])
    for c_ in out["cand"]:
        B.append("🧪 also today's %s candidate at %s" % ({"A": "WEAK", "B": "BREAK", "E": "BOUNCE", "T": "STRONG3", "G": "GAPDAY"}.get(c_.get("kind"), c_.get("kind")), c_.get("t")))
    try:                                                     # the record: was each call news-backed? (scored later against what the call did)
        rp = os.path.join(D, "data", "callwhy", today + ".json"); os.makedirs(os.path.dirname(rp), exist_ok=True)
        R_ = json.load(open(rp)) if os.path.exists(rp) else {}
        k_ = "%s|%d" % (sym, dr)
        if k_ not in R_:
            R_[k_] = {"t": dt.datetime.now(IST).strftime("%H:%M"), "backed": out["backed"], "against": any(n["dir"] in ("up", "down") and not n["agree"] for n in out["news"]),
                      "sector": out.get("sector"), "peers": out.get("peers"), "run": out.get("run"), "px": out.get("px"), "chg": out.get("chg")}
            json.dump(R_, open(rp + ".tmp", "w")); os.replace(rp + ".tmp", rp)
    except Exception:
        pass
    if len(_C) > 300:
        _C.clear()
    _C[(sym, dr)] = (time.time(), out)
    return out


if __name__ == "__main__":
    v = view(sys.argv[1] if sys.argv[1:] else "ANGELONE", sys.argv[2] if sys.argv[2:] else "1")
    print("WHY NOW · %s %s%s" % ("BUY CE" if v["dir"] > 0 else "BUY PE", v["s"], " · 🗞 NEWS-BACKED" if v["backed"] else ""))
    for b in v["bul"]:
        print("  " + b)
