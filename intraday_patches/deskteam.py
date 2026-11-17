#!/usr/bin/env python3
"""deskteam.py - patch 384: 🏛 THE DESKS - SPECIALIST AGENTS FOR EVERY ASPECT OF THE MARKET (Rama, 17 Nov 19:50: "I think more agents to cover
all the aspects of share markets"). One analyst cannot watch everything equally well. Six specialist desks, each an AI with its OWN facts and
its own expertise, write a short note every 3 minutes in market hours (and at once on a fresh event); the senior expert (analyst.py, Claude
Fable 5.2) reads all six notes before every decision.
  1 SECTORS & ROTATION   the sectors by size, their 15/30/60-min rotation, who leads each, the sector runs / turns GIR found (secsurge)
  2 NEWS & POLICY        company news with the AI's reading, the market desk, the policy map, each share's own story of the last days
  3 MONEY FLOW           futures build-up (long / short build-up, short covering, unwinding) and the option chain: PCR, the biggest call
                         wall (the roof) and put wall (the floor) for NIFTY, BANKNIFTY and the movers
  4 GLOBAL & MACRO       the world now (US futures, crude, gold, the dollar, the rupee, Asia, the US yield) and the 07:00 list's tilt
  5 PRICE ACTION         the movers, where they stand against their 20-day high / low, GIR's good alert types firing, GIR DECIDES
  6 RISK                 results today / last evening, the F&O ban, expiry, the time of day, NIFTY's mood, and the analyst's open calls
                         that the facts have turned against
Each desk answers in JSON: a headline, up to 4 points, up to 4 shares with a direction and why, and how sure it is. Only its facts - never
invented. The desks run on Claude Sonnet 5.5 (DESK_MODEL; an expert model, quicker and cheaper than the senior), at most 900 desk readings a day.
-> data/desks.json (the page shows the six notes in the 🧠 box)."""
import os, re, sys, json, time, sqlite3, datetime as dt
from concurrent.futures import ThreadPoolExecutor
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "desks.json")
DESK_MODEL = os.environ.get("DESK_MODEL") or "claude-sonnet-5-5"
EVERY, CAP = 180, 900
ASK = None                                                    # tests: ASK(desk, system, user) -> text
COMMON = """Answer with ONE JSON object only: {"headline": "under 20 words", "points": ["up to 4 short points, each resting on a fact"],
"shares": [{"s": "SYMBOL", "dir": "up|down|unclear", "why": "under 20 words"}], "sure": "high|medium|low"}. Use ONLY the facts given -
never invent news, prices, levels or times. Name only F&O shares that appear in the facts. If nothing stands out, say so in the headline
and leave shares empty. You write for the senior analyst of an Indian F&O options trader - plain trading words."""
DESKS = {
    "sectors": ("🧭 SECTORS & ROTATION", "You are the sector and rotation specialist on an Indian F&O desk. You read which sectors lead and lag, where money "
                "is rotating in the last 15/30/60 minutes, which F&O shares are pulling a sector, and when a leading sector is turning over (giving back "
                "1%+ from its high with most shares falling - a PE setup before 12:30 in the trader's own test) or a weak one turning up."),
    "news": ("📰 NEWS & POLICY", "You are the news and policy specialist. You judge what each story means for the share's price and which way, read it "
             "against the share's own recent story (a promoter who sold yesterday and rules out more today is GOOD news), link regulator and "
             "government stories to the groups they hit, and say which story is fresh enough to still move the price."),
    "flow": ("💰 MONEY FLOW", "You are the derivatives and money-flow specialist. Futures: price up + OI up = long build-up (bullish), price down + OI up "
             "= short build-up (bearish), price up + OI down = short covering (a weaker rise), price down + OI down = long unwinding. Options: "
             "the biggest call OI strike is the roof, the biggest put OI strike the floor; PCR above 1.2 = put writers confident (support), below "
             "0.7 = call writers confident (resistance). Say where the money is going and which shares it backs or warns against."),
    "global": ("🌍 GLOBAL & MACRO", "You are the global and macro specialist. You read the world live (US index futures, crude, gold, the dollar, the "
               "rupee, Asia, the US 10-year yield) and say what it means for the Indian market and its sectors NOW - crude for oil marketers, paints, "
               "airlines; the rupee for IT and pharma exporters; metals for metal producers; a falling US / Asia for foreign selling."),
    "price": ("📈 PRICE ACTION", "You are the price-action specialist. You read the movers' strength, whether they are breaking their 20-day high or low "
              "or failing at it, how much of the move is done, and the trader's own tested signals: two good alert types agreeing before 10:30 "
              "(GIR DECIDES) beat the market; the opening alerts were the best single type; a share that already moved 2%+ did not do worse after."),
    "risk": ("🛡 RISK", "You are the risk manager. You flag what can hurt a trade now: results today or last evening (gap risk), shares in the F&O ban "
             "(no new positions), expiry-day moves, late-day time decay, NIFTY's mood against a call, and any of the analyst's open calls whose "
             "facts have turned (say CAUTION and why). You protect money first."),
}


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


def chain_summary(syms, n=None):
    """the option chain's last reading, nearest expiry: PCR, the roof (largest call OI strike) and the floor (largest put OI strike)"""
    out = []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5); day = str((n or now()).date())
        for s in syms:
            r = c.execute("select max(t) from chain where d=? and sym=?", (day, s)).fetchone()
            if not r or not r[0]:
                continue
            t = r[0]; ex = c.execute("select min(exp) from chain where d=? and sym=? and t=?", (day, s, t)).fetchone()[0]
            R = c.execute("select strike, kind, oi, spot from chain where d=? and sym=? and t=? and exp=?", (day, s, t, ex)).fetchall()
            ce = [(k, oi) for k, kd, oi, sp in R if kd == "CE" and oi]; pe = [(k, oi) for k, kd, oi, sp in R if kd == "PE" and oi]
            if not ce or not pe:
                continue
            spot = next((sp for *_, sp in R if sp), None); pcr = sum(o for _, o in pe) / max(1, sum(o for _, o in ce))
            out.append("%s (spot %s, %s, expiry %s): PCR %.2f · roof (biggest call OI) %s · floor (biggest put OI) %s" % (
                s, spot, str(t)[:5], ex, pcr, max(ce, key=lambda x: x[1])[0], max(pe, key=lambda x: x[1])[0]))
        c.close()
    except Exception:
        pass
    return out


def range20(syms):
    """each share against its 20-day high / low (Kite 5-minute history in data/secstudy, the days before today)"""
    out = []
    try:
        import numpy as np
        C = os.path.join(D, "data", "secstudy"); best = {}
        for f in os.listdir(C):
            m = re.match(r"^(.+)_(\d{4}-\d\d-\d\d)\.npy$", f)
            if m and (m.group(1) not in best or m.group(2) > best[m.group(1)][0]):
                best[m.group(1)] = (m.group(2), f)
        q = _j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}; today = now().date().toordinal()
        for s in syms:
            b = best.get(re.sub(r"[^A-Z0-9]", "_", s)); px = (q.get(s) or [None])[0]
            if not b or not px:
                continue
            A = np.load(os.path.join(C, b[1])); A = A[A[:, 0] < today]
            days = sorted(set(A[:, 0].astype(int)))[-20:]
            A = A[np.isin(A[:, 0].astype(int), days)]
            if not len(A):
                continue
            hi, lo = float(A[:, 3].max()), float(A[:, 4].min())
            where = "ABOVE its 20-day high" if px > hi else "BELOW its 20-day low" if px < lo else "%.1f%% under its 20-day high, %.1f%% over its low" % (100 * (hi / px - 1), 100 * (px / lo - 1))
            out.append("%s ₹%s: %s (20-day high %.2f, low %.2f)" % (s, px, where, hi, lo))
    except Exception:
        pass
    return out


_GL = {"t": 0, "v": []}


def world():
    """the world now - read at most every 5 minutes (morningmkts, Yahoo's public feed); US index futures added"""
    if time.time() - _GL["t"] < 300:
        return _GL["v"]
    out = []
    try:
        import morningmkts as MM
        for sym, name in (("ES=F", "US S&P 500 futures"), ("NQ=F", "US Nasdaq futures")):
            q = MM.quote(sym)
            if q:
                out.append("%s %+.2f%%" % (name, 100 * (q[0] / q[1] - 1)))
        for m in MM.markets():
            if m.get("ok"):
                out.append("%s %+.2f%s (as of %s)" % (m["name"], m["chg"], "%" if m.get("unit") == "%" else " pts", m.get("at")))
    except Exception:
        pass
    _GL.update({"t": time.time(), "v": out})
    return out


def desk_facts(F, n=None):
    """each desk's own slice of the picture (F = analyst.facts()) plus what only that desk reads"""
    n = n or now()
    g = lambda *ks: {k: F[k] for k in ks if F.get(k)}
    movers = [re.match(r"([A-Z][A-Z0-9&\-]+)", x).group(1) for x in (F.get("gainers") or [])[:6] + (F.get("losers") or [])[:6] if re.match(r"([A-Z][A-Z0-9&\-]+)", x)]
    X = {"sectors": g("market", "sectors_best", "sectors_worst", "sectors_moving_now", "sector_fo_shares"),
         "news": g("news", "market_news", "policy", "story_memory"),
         "flow": g("market", "gainers", "losers"),
         "global": g("market", "morning_list", "market_news"),
         "price": g("market", "gainers", "losers", "good_alerts_last_15min", "gir_decides"),
         "risk": g("market", "your_calls_so_far", "gir_decides")}
    try:
        ev = _j(os.path.join(D, "data", "secsurge", "%s.json" % n.date()), {})
        E = ev.get("events") or ev.get("ev") or []
        if E:
            X["sectors"]["sector_runs_and_turns"] = [json.dumps(e, ensure_ascii=False)[:160] for e in E[-6:]]
    except Exception:
        pass
    try:                                                        # 📚 the knowledge base (patch 386)
        import knowledge
        nsy = []
        for ln in F.get("news") or []:
            m_ = re.match(r"\S+ ([A-Z][A-Z0-9&\-]+)", ln)
            if m_ and m_.group(1) not in nsy:
                nsy.append(m_.group(1))
        kn = [ln for s_ in nsy[:6] for ln in knowledge.brief(s_)]
        if kn:
            X["news"]["how_these_shares_react"] = kn[:18]
        X["global"]["who_reacts_to_what"] = {k: knowledge.who_reacts(k) for k in ("crude", "rupee", "Nasdaq", "gold", "copper", "yield")}
        X["price"]["usual_moves"] = [ln for s_ in movers[:8] for ln in knowledge.brief(s_)[1:2]]
    except Exception:
        pass
    X["flow"]["option_chain"] = chain_summary(["NIFTY", "BANKNIFTY"] + movers[:8], n)
    X["global"]["world_now"] = world()
    X["price"]["range_20_days"] = range20(movers)
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        d0 = n.date(); d1 = d0 - dt.timedelta(days=1)
        while d1.weekday() > 4:
            d1 -= dt.timedelta(days=1)
        X["risk"]["results_today"] = sorted({s for (s,) in c.execute("select sym from results_cal where d=?", (str(d0),))})
        X["risk"]["results_last_evening"] = sorted({s for (s,) in c.execute("select sym from results_cal where d=?", (str(d1),))})
        e_ = c.execute("select min(exp) from chain where d=? and sym='NIFTY'", (str(d0),)).fetchone()
        if e_ and e_[0]:
            X["risk"]["nifty_expiry"] = "%s%s" % (e_[0], " - TODAY is expiry" if str(e_[0])[:10] == str(d0) else "")
        c.close()
    except Exception:
        pass
    b = _j(os.path.join(D, "data", "ban.json"), {})
    if b.get("ban"):
        X["risk"]["fo_ban"] = b["ban"]
    X["risk"]["time"] = n.strftime("%H:%M") + (" - the last hour: time decay is fastest" if n.strftime("%H:%M") >= "14:30" else "")
    return X


def ask(desk, system, user):
    if ASK is not None:
        return ASK(desk, system, user)
    import analyst
    return analyst.ask(system, user, 1200, DESK_MODEL, "low")


def parse(txt):
    a, b = (txt or "").find("{"), (txt or "").rfind("}")
    try:
        j = json.loads(txt[a:b + 1]) if a >= 0 and b > a else {}
    except Exception:
        j = {}
    sh = [{"s": str(x.get("s") or "").upper()[:20], "dir": x.get("dir") if x.get("dir") in ("up", "down") else "unclear", "why": str(x.get("why") or "")[:140]}
          for x in (j.get("shares") or [])[:4] if isinstance(x, dict) and x.get("s")]
    return {"headline": str(j.get("headline") or "")[:160], "points": [str(p)[:200] for p in (j.get("points") or [])[:4]], "shares": sh,
            "sure": j.get("sure") if j.get("sure") in ("high", "medium", "low") else "low"}


def tick(F=None, why="the 3 minutes", n_=None):
    """all six desks in parallel -> data/desks.json"""
    n = n_ or now(); day = str(n.date()); st = _j(OUT, {})
    if st.get("day") != day:
        st = {"day": day, "n": 0, "notes": {}}
    if st["n"] + len(DESKS) > CAP:
        return st
    if F is None:
        import analyst
        F = analyst.facts(n)
    X = desk_facts(F, n)
    def one(k):
        name, brief = DESKS[k]
        try:
            return k, parse(ask(k, brief + "\n" + COMMON, "Now %s IST (%s). Your facts:\n%s" % (n.strftime("%H:%M"), why, json.dumps(X[k], ensure_ascii=False, indent=0))))
        except Exception as ex:
            return k, {"headline": "", "points": [], "shares": [], "sure": "low", "err": str(ex)[:100]}
    with ThreadPoolExecutor(max_workers=len(DESKS)) as P:
        R = list(P.map(one, list(DESKS)))
    for k, note in R:
        note.update({"t": n.strftime("%H:%M"), "name": DESKS[k][0]}); st["notes"][k] = note
    st["n"] += len(DESKS); st["at"] = n.strftime("%H:%M:%S"); st["model"] = DESK_MODEL; st["ts"] = n.timestamp()
    _save(st, OUT)
    return st


def lines(max_age=900):
    """the six notes, short, for the senior analyst (only notes younger than 15 minutes)"""
    st = _j(OUT, {}); out = []
    if st.get("day") != str(now().date()) or time.time() - float(st.get("ts") or 0) > max_age:
        return out
    for k in DESKS:
        nt = (st.get("notes") or {}).get(k)
        if not nt or not nt.get("headline"):
            continue
        out.append("%s (%s, sure %s): %s%s%s" % (DESKS[k][0], nt.get("t"), nt.get("sure"), nt["headline"], (" · " + " · ".join(nt.get("points") or [])) if nt.get("points") else "",
                   (" · shares: " + ", ".join("%s %s (%s)" % (x["s"], x["dir"], x["why"]) for x in nt.get("shares") or [])) if nt.get("shares") else ""))
    return out


def view():
    st = _j(OUT, {})
    return {"day": st.get("day"), "at": st.get("at"), "model": st.get("model"), "notes": [dict((st.get("notes") or {}).get(k) or {}, key=k, name=DESKS[k][0]) for k in DESKS]}


if __name__ == "__main__":
    st = tick(why="by hand")
    for ln in lines(10 ** 9):
        print(ln); print()
