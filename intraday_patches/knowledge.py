#!/usr/bin/env python3
"""knowledge.py - patch 386: 📚 THE KNOWLEDGE BASE - WHAT A VETERAN KNOWS ABOUT EVERY F&O SHARE (Rama, 17 Nov 20:10: "the team of experts should
have all the knowledge of all F&O shares and their sectors, the shares' past history, present and future, and how they will react when things
come up. That kind of expert I need."). For every F&O share, kept in data/kb/kb.json and given to the desks, the senior analyst, the ready files
and the 💬 answers:
  MEASURED (from the data - facts):
    · its usual day: average range and move, % of up days, how often it gaps 1%+ and how often the gap fills (Kite, the last year, daily)
    · its beta to NIFTY and to its own sector (the sector's other F&O shares), and how closely it follows each
    · its big days: 4%+ days in the year, the last ones with their dates
    · HOW IT REACTS to the world: its day move against the night's crude, dollar-rupee, Nasdaq, gold, copper, US 10-year yield (2 years,
      Yahoo) - only the links that are real (|correlation| 0.15+ on 120+ days), in plain words ("falls when crude rises")
    · its results reactions (GIR's results desk, where it has them) and its shock days with their reasons (data/h3/circuits.json)
  EXPERT (Claude Fable 5.2's knowledge of the company, monthly - labelled as general knowledge, checked against the measured part):
    · the business and what drives its profit · its sensitivities (rates, crude, rupee, regulation, monsoon ...) · its peers
    · how it TYPICALLY reacts to each kind of event (results beat / miss, promoter selling, a block deal, an order, a regulator, a price war ...)
    · what to watch for it
  python3 knowledge.py build [SYM ...]   measure all (or these) and write the expert part where it is older than 30 days (needs Kite: .env)
  python3 knowledge.py show SYM          one share's knowledge
Weekly (Friday 21:30, by gir-ready - Kite's login is still valid then): measured again for all; the expert part renewed after 30 days. Orders nothing, sends nothing."""
import os, re, sys, json, time, datetime as dt
from concurrent.futures import ThreadPoolExecutor
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
KB = os.path.join(D, "data", "kb", "kb.json")
ASK = None                                                    # tests: ASK(system, user) -> text
WORLD = [("BZ=F", "crude (Brent)"), ("INR=X", "dollar-rupee (a weaker rupee)"), ("^IXIC", "the Nasdaq"), ("GC=F", "gold"), ("HG=F", "copper"), ("^TNX", "the US 10-year yield")]
PROFILE = """You are a veteran Indian equity and F&O analyst who has followed this NSE company for years. Write what an experienced trader must
know about it, from your general knowledge of the company - and check it against the MEASURED facts given (they are from the market data
and win where they disagree). Plain trading words, specific to THIS company (no generic text). Say "not sure" rather than guess a fact.
Answer with ONE JSON object only:
{"business": "one line: what it does and where its profit comes from",
 "drivers": ["up to 4 things that move its profit / price"],
 "sensitivities": ["up to 4: rates / crude / rupee / regulation / monsoon / metal prices / US demand ... and which way"],
 "peers": ["up to 5 NSE symbols of its closest listed peers"],
 "reactions": [{"event": "results beat / miss, promoter stake sale, block deal, big order, regulator action, price cut, management change ...",
                "reaction": "how this share typically reacts and for how long"}],
 "watch": ["up to 3 things to watch for it now"],
 "caution": "anything about how it trades a trader must respect (low float, operator-driven, circuit-prone, news-sensitive ...) or empty"}
"reactions": up to 6, the events that matter most for THIS company."""


def now():
    return dt.datetime.now(IST)


def _j(p, d):
    try:
        return json.load(open(p))
    except Exception:
        return d


def _save(o, p):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(o, open(p + ".tmp", "w"), ensure_ascii=False); os.replace(p + ".tmp", p)


def fetch_year(syms):
    """Kite day candles, a year, for the shares and NIFTY -> {sym: [[date, o, h, l, c], ...]}"""
    import seclive as SL, getdata
    kite = SL.get_kite()
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    tok["NIFTY"] = 256265; out = {}; to = now(); frm = to - dt.timedelta(days=380)
    for s in list(syms) + ["NIFTY"]:
        if s not in tok:
            continue
        for k in range(2):
            try:
                out[s] = [[str(r["date"])[:10], float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"])] for r in kite.historical_data(tok[s], frm, to, "day")]
                time.sleep(0.36); break
            except Exception:
                time.sleep(2.0)
    return out


def _ret(rows):
    return {rows[i][0]: rows[i][4] / rows[i - 1][4] - 1 for i in range(1, len(rows)) if rows[i - 1][4]}


def _corr(a, b):
    import numpy as np
    if len(a) < 30:
        return float("nan"), float("nan")
    a, b = np.array(a), np.array(b)
    if a.std() == 0 or b.std() == 0:
        return float("nan"), float("nan")
    return float(np.corrcoef(a, b)[0, 1]), float(np.cov(a, b)[0, 1] / b.var())


def world_moves():
    """{market: {Indian date: the night's move}} - the session that closed before that Indian day (nightstudy's reading)"""
    import nightstudy as NS
    out = {}
    for sym, name in WORLD:
        H = NS.history(sym)
        if len(H) < 60:
            continue
        mv = {}
        for i in range(1, len(H)):
            d_ = H[i][0] + (dt.timedelta(days=0) if sym == "INR=X" else dt.timedelta(days=1))   # the rupee trades WITH the Indian day; the rest the night before
            while d_.weekday() > 4:
                d_ += dt.timedelta(days=1)
            mv[str(d_)] = (H[i][1] - H[i - 1][1]) if sym == "^TNX" else (H[i][1] / H[i - 1][1] - 1)
        out[name] = mv
        time.sleep(0.4)
    return out


def measure(sym, Y, SEC, W):
    """the measured part of one share's knowledge"""
    rows = Y.get(sym) or []
    if len(rows) < 60:
        return None
    r = _ret(rows); n_ = _ret(Y.get("NIFTY") or [])
    peers = [s for s, v in SEC.items() if v == SEC.get(sym) and s != sym and Y.get(s)]
    pr = {}
    for p in peers:
        for d_, x in _ret(Y[p]).items():
            pr.setdefault(d_, []).append(x)
    sec = {d_: sum(v) / len(v) for d_, v in pr.items() if len(v) >= 2}
    days = sorted(r)
    rng = [100 * (rows[i][2] - rows[i][3]) / rows[i - 1][4] for i in range(1, len(rows)) if rows[i - 1][4]]
    gaps = [(i, rows[i][1] / rows[i - 1][4] - 1) for i in range(1, len(rows)) if rows[i - 1][4]]
    big_g = [(i, g) for i, g in gaps if abs(g) >= 0.01]
    filled = sum(1 for i, g in big_g if rows[i][3] <= rows[i - 1][4] <= rows[i][2])
    cn, bn = _corr([r[d_] for d_ in days if d_ in n_], [n_[d_] for d_ in days if d_ in n_])
    cs, bs = _corr([r[d_] for d_ in days if d_ in sec], [sec[d_] for d_ in days if d_ in sec])
    big = [(rows[i][0], 100 * (rows[i][4] / rows[i - 1][4] - 1)) for i in range(1, len(rows)) if rows[i - 1][4] and abs(rows[i][4] / rows[i - 1][4] - 1) >= 0.04]
    M = {"days": len(rows), "avg_range_pct": round(sum(rng) / len(rng), 2), "avg_move_pct": round(100 * sum(abs(x) for x in r.values()) / len(r), 2),
         "up_days_pct": round(100.0 * sum(1 for x in r.values() if x > 0) / len(r)), "gap_days_pct": round(100.0 * len(big_g) / max(1, len(gaps))),
         "gaps_filled_pct": round(100.0 * filled / len(big_g)) if big_g else None,
         "nifty": {"beta": round(bn, 2), "corr": round(cn, 2)} if cn == cn else None,
         "sector": {"name": SEC.get(sym), "peers": len(peers), "beta": round(bs, 2), "corr": round(cs, 2)} if cs == cs else None,
         "big_days": len(big), "last_big_days": ["%s %+.1f%%" % b for b in big[-4:]], "world": []}
    for name, mv in (W or {}).items():                         # how it reacts to the world - only the real links
        X = [(r[d_], mv[d_]) for d_ in days if d_ in mv]
        c, b = _corr([x for x, _ in X], [y for _, y in X])
        if c == c and abs(c) >= 0.15 and len(X) >= 120:
            M["world"].append({"to": name, "corr": round(c, 2), "say": "%s when %s rises (%s, %d days)" % ("rises" if c > 0 else "falls", name, "a clear link" if abs(c) >= 0.3 else "a mild link", len(X))})
    try:                                                        # its results reactions, where GIR's results desk has them
        import resultsdesk
        H = resultsdesk.history(sym, 8)
        if isinstance(H, list) and H:
            M["results"] = [{k: h.get(k) for k in ("q", "verdict", "d1", "d3") if k in h} for h in H[:8] if isinstance(h, dict)]
    except Exception:
        pass
    try:                                                        # its shock days with their reasons (patch 161)
        J = _j(os.path.join(D, "data", "h3", "circuits.json"), {}); found = []

        def walk(o):
            if isinstance(o, dict):
                if (o.get("sym") or o.get("s")) == sym and (o.get("reason") or o.get("why")):
                    found.append("%s %s: %s" % (o.get("d") or o.get("date") or "", o.get("chg") or o.get("move") or "", str(o.get("reason") or o.get("why"))[:120]))
                for v in o.values():
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
        walk(J)
        if found:
            M["shocks"] = found[-6:]
    except Exception:
        pass
    return M


def ask(system, user):
    if ASK is not None:
        return ASK(system, user)
    import analyst
    return analyst.ask(system, user, 2000, analyst.EXPERT, "medium")


def profile(sym, name, sector, M):
    txt = ask(PROFILE, json.dumps({"symbol": sym, "company": name, "nse_sector": sector, "measured": M}, ensure_ascii=False))
    a, b = (txt or "").find("{"), (txt or "").rfind("}")
    try:
        j = json.loads(txt[a:b + 1]) if a >= 0 and b > a else {}
    except Exception:
        j = {}
    if not j.get("business"):
        return None
    return {"business": str(j.get("business"))[:240], "drivers": [str(x)[:140] for x in (j.get("drivers") or [])[:4]],
            "sensitivities": [str(x)[:140] for x in (j.get("sensitivities") or [])[:4]], "peers": [str(x).upper()[:20] for x in (j.get("peers") or [])[:5]],
            "reactions": [{"event": str(x.get("event"))[:100], "reaction": str(x.get("reaction"))[:200]} for x in (j.get("reactions") or [])[:6] if isinstance(x, dict)],
            "watch": [str(x)[:140] for x in (j.get("watch") or [])[:3]], "caution": str(j.get("caution") or "")[:200],
            "made": now().strftime("%Y-%m-%d"), "note": "the expert's general knowledge of the company - the measured part wins where they differ"}


def build(syms=None, Y=None, W=None, n_=None):
    import seclive as SL
    SEC, NM = SL.universe(); FO = sorted(SL.fo_set())
    syms = syms or FO
    Y = Y if Y is not None else fetch_year(syms if syms != FO else FO)
    if W is None:
        try:
            W = world_moves()
        except Exception as ex:
            W = {}; print("the world's history not read: %s" % str(ex)[:80], flush=True)
    kb = _j(KB, {"shares": {}}); S = kb.setdefault("shares", {}); n = n_ or now()
    for s in syms:
        m = measure(s, Y, SEC, W)
        if m:
            S.setdefault(s, {})["measured"] = m; S[s]["measured_at"] = n.strftime("%Y-%m-%d"); S[s]["name"] = NM.get(s, ""); S[s]["sector"] = SEC.get(s, "")
    _save(kb, KB)
    due = [s for s in syms if s in S and (not S[s].get("profile") or (n.date() - dt.date.fromisoformat(S[s]["profile"].get("made", "2000-01-01"))).days >= 30)]

    def one(s):
        try:
            return s, profile(s, S[s].get("name"), S[s].get("sector"), S[s].get("measured"))
        except Exception as ex:
            print("profile %s: %s" % (s, str(ex)[:80]), flush=True); return s, None
    with ThreadPoolExecutor(max_workers=6) as P:
        for i, (s, pf) in enumerate(P.map(one, due)):
            if pf:
                S[s]["profile"] = pf
            if i % 20 == 19:
                _save(kb, KB); print("  profiles written: %d of %d" % (i + 1, len(due)), flush=True)
    kb["built"] = n.strftime("%Y-%m-%d %H:%M"); _save(kb, KB)
    return kb


def brief(sym, full=False):
    """one share's knowledge as short lines for the agents (full=True for the 💬 answers and the page)"""
    k = (_j(KB, {}).get("shares") or {}).get(sym)
    if not k:
        return []
    M, P = k.get("measured") or {}, k.get("profile") or {}; L = []
    if P.get("business"):
        L.append("%s: %s" % (sym, P["business"]))
    if M:
        L.append("%s usually: range %s%%, move %s%% a day · beta %s to NIFTY, %s to its sector (%s) · gaps 1%%+ on %s%% of days (%s%% filled) · %s days of 4%%+ a year" % (
            sym, M.get("avg_range_pct"), M.get("avg_move_pct"), (M.get("nifty") or {}).get("beta"), (M.get("sector") or {}).get("beta"), (M.get("sector") or {}).get("name"),
            M.get("gap_days_pct"), M.get("gaps_filled_pct"), M.get("big_days")))
        if M.get("world"):
            L.append("%s reacts: %s" % (sym, "; ".join(w["say"] for w in M["world"])))
    if P.get("reactions"):
        L.append("%s typically: %s" % (sym, "; ".join("%s -> %s" % (x["event"], x["reaction"]) for x in P["reactions"][:(6 if full else 3)])))
    if full:
        for k_, lab in (("drivers", "drivers"), ("sensitivities", "sensitive to"), ("peers", "peers"), ("watch", "watch")):
            if P.get(k_):
                L.append("%s %s: %s" % (sym, lab, ", ".join(P[k_])))
        if P.get("caution"):
            L.append("%s caution: %s" % (sym, P["caution"]))
        if M.get("results"):
            L.append("%s results reactions: %s" % (sym, json.dumps(M["results"], ensure_ascii=False)[:400]))
        if M.get("shocks"):
            L.append("%s shock days: %s" % (sym, " | ".join(M["shocks"])))
        if M.get("last_big_days"):
            L.append("%s last big days: %s" % (sym, ", ".join(M["last_big_days"])))
    return L


def who_reacts(name_part, top=8):
    """the shares with the clearest link to a world market ('crude', 'rupee', 'Nasdaq', 'gold', 'copper', 'yield')"""
    out = []
    for s, k in (_j(KB, {}).get("shares") or {}).items():
        for w in ((k.get("measured") or {}).get("world") or []):
            if name_part.lower() in w["to"].lower():
                out.append((abs(w["corr"]), "%s %s (%+.2f)" % (s, "rises" if w["corr"] > 0 else "falls", w["corr"])))
    return [x for _, x in sorted(out, reverse=True)[:top]]


def view(sym):
    k = (_j(KB, {}).get("shares") or {}).get(str(sym).upper())
    return {"s": str(sym).upper(), "kb": k, "lines": brief(str(sym).upper(), True)}


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["build"]:
        kb = build([x.upper() for x in a[1:]] or None)
        S = kb.get("shares") or {}
        print("knowledge: %d shares measured · %d with the expert's profile · built %s" % (sum(1 for v in S.values() if v.get("measured")), sum(1 for v in S.values() if v.get("profile")), kb.get("built")))
    elif a[:1] == ["show"] and a[1:]:
        print("\n".join(brief(a[1].upper(), True)) or "no knowledge for %s yet" % a[1].upper())
