#!/usr/bin/env python3
"""readyfile.py - patch 385: 📁 THE READY FILES AND ⚡ BE READY (Rama, 17 Nov 20:00: "For F&O trading we need a lot of information kept ready -
all the details of what will happen today, tomorrow and in future, based on what happened yesterday, a few days back and today" ...
"build the ready files for all F&O shares. He should wake me up and tell me: hey, be ready, something is happening. Not me asking him.")
  THE FILES   every evening (19:50) for EVERY F&O share, refreshed at 07:10 with the night's news, and DURING TRADING rewritten at once
              when something happens to the share (AI-read news, a 🧭 policy story, a 2%+ move since its file) - "⚡ BE READY · FILE
              UPDATED" rings with what happened, what changed and the new levels (Rama, 17 Nov 20:20: "if something happens during trading,
              that also will come at 19:30?" - no: at once) - kept in data/ready/files.json:
                BEHIND  the last 5 sessions (close, % move, high / low), the 20-day high / low, the futures money day by day (long / short
                        build-up, short covering, unwinding - oistudy.db), the option chain's roof / floor / PCR (chains.db), the news of
                        the last 7 days with the AI's reading (news.db), the last results date
                AHEAD   the next results date, the F&O ban, the expiry
                OUTLOOK written by Claude Sonnet 5.5 from those facts ONLY: bias, why, tomorrow, what to watch, and the LEVELS that
                        matter - each level must be one of the file's own numbers (20-day high / low, yesterday's high / low / close,
                        roof, floor), or it is dropped. Each level becomes a trigger: "above 942 (20-day high) -> CE".
              THE MARKET FILE: NIFTY / BANKNIFTY / India VIX for 5 days, the sectors at the close, results this week, the expiry,
              the ban - and the senior expert (Claude Fable 5.2) writes the outlook and picks the shares to be ready for.
  ⚡ BE READY  GIR tells Rama - he does not ask:
                07:15  "⚡ BE READY TODAY" rings: the market outlook, the shares to be ready for with their levels, today's events
                09:15-15:30, every 15 s: a share NEARING a level from its file (within 0.4%) -> "⚡ BE READY ▲ LAURUSLABS · near 942";
                       CROSSING it (a gap at the open counts) -> "⚡ BE READY ▲ LAURUSLABS · crossed 942" - rings, with the file's
                       why, the news, the sector; the 🧠 analyst reads it at once (data/ready/hits.json)
  The page: the ⚡ BE READY box at the top of TRADE NOW (today's alerts, the morning list, the market outlook) and 📁 any share's file.
  The files are evidence-based notes, not proven calls; the strike, size and stop stay Rama's. Orders nothing.
  python3 readyfile.py build [--dry]   build all the files now (needs Kite - the .env)       python3 readyfile.py show SYM
  python3 readyfile.py run             the service (gir-ready)"""
import os, re, sys, json, time, sqlite3, datetime as dt
from concurrent.futures import ThreadPoolExecutor
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
RD = os.path.join(D, "data", "ready")
DAILY, FILES, HITS = os.path.join(RD, "daily.json"), os.path.join(RD, "files.json"), os.path.join(RD, "hits.json")
WRITER = os.environ.get("READY_MODEL") or "claude-sonnet-5-5"
NEAR = 0.004
ASK = None                                                    # tests: ASK(kind, system, user) -> text
SEND = None
IDX = {"NIFTY": 256265, "BANKNIFTY": 260105, "INDIAVIX": 264969}
WRITE_SYS = """You are a senior Indian F&O analyst preparing a trader's READY FILE on one share for the next session. You get only facts from
his own system (with "knowledge": how this share usually trades and reacts - use it to judge what tomorrow's news or levels mean): the last 5 sessions, the 20-day range, the futures money day by day, the option chain's roof / floor / PCR, the share's
news of the last 7 days with the AI's reading, results dates, the ban list. Write from those facts ONLY - never invent news, dates or
numbers. Read the story in order (a promoter who sold and then rules out more selling is GOOD news).
If "today_live" is given, the session is LIVE: write for the REST OF TODAY and tomorrow - what the fresh news or move changes.
LEVELS: you may only use numbers from "levels_you_may_use". Give at most 3 triggers - the levels that would matter tomorrow - each with
the side it would favour (CE above a resistance that breaks, PE below a support that breaks).
Answer with ONE JSON object only:
{"bias": "up|down|range|unclear", "summary": "one line, under 25 words: where the share stands and why",
 "tomorrow": "one line: what is likely tomorrow and on what condition",
 "watch": ["up to 3 short things to watch"],
 "triggers": [{"type": "above|below", "level": number, "side": "CE|PE", "say": "under 15 words: why this level matters"}],
 "catalyst": "the fresh reason it could move (news / results / money / sector), or empty"}"""
MARKET_SYS = """You are the senior market strategist of an Indian F&O options trader, writing tonight's MARKET FILE and the BE READY list for
the next session, from ONLY the facts given (the indices and India VIX for 5 days, the sectors at the close, the calendar, and one line per
F&O share from his ready files). Never invent. Remember: overnight news mostly shows in the opening price.
Answer with ONE JSON object only:
{"outlook": "3 short lines on the market for tomorrow, with the condition that would change it",
 "sectors": "one line: which sectors to lean on and which to avoid",
 "be_ready": [{"s": "SYMBOL", "side": "CE|PE|WATCH", "why": "under 20 words, from its file"}],
 "events": "one line: the day's events from the calendar (results, expiry, ban)"}
"be_ready": at most 8 shares, the clearest setups with a fresh catalyst - fewer is better."""


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


def next_day(d):
    d = d + dt.timedelta(days=1)
    while d.weekday() > 4:
        d += dt.timedelta(days=1)
    return d


def fo_names():
    try:
        import seclive as SL
        SEC, NM = SL.universe()
        return sorted(SL.fo_set()), SEC, NM
    except Exception:
        return [], {}, {}


def fetch_daily(syms, days=40):
    """Kite day candles for every F&O share and the indices -> data/ready/daily.json {sym: [[date, o, h, l, c, v], ...]}"""
    import seclive as SL, getdata
    kite = SL.get_kite()
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    tok.update(IDX)
    to = now(); frm = to - dt.timedelta(days=int(days * 1.6) + 5); out = {}; fails = 0
    for s in list(syms) + list(IDX):
        if s not in tok:
            continue
        for k in range(2):
            try:
                rows = kite.historical_data(tok[s], frm, to, "day"); time.sleep(0.36)
                out[s] = [[str(r["date"])[:10], float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"]), float(r.get("volume") or 0)] for r in rows][-days:]
                break
            except Exception:
                time.sleep(2.0); fails += 1
    _save({"at": to.strftime("%Y-%m-%d %H:%M"), "rows": out}, DAILY)
    return out, fails


def buildup(dp, doi):
    if dp is None or doi is None:
        return "-"
    return ("long build-up" if doi > 0 else "short covering") if dp > 0 else ("short build-up" if doi > 0 else "long unwinding")


def gather(sym, rows, SEC, n=None):
    """the facts of one share's file - no model"""
    n = n or now(); F = {"s": sym, "sector": SEC.get(sym, "")}
    rows = [r for r in rows if r[0] < str(n.date())] if n.strftime("%H:%M") < "15:30" else rows        # only finished sessions
    if len(rows) < 6:
        return None
    last5 = rows[-5:]; prev = rows[-6]
    F["last5"] = []
    for i, r in enumerate(last5):
        pc = (rows[-6 + i][4]) if i else prev[4]
        F["last5"].append("%s close %.2f (%+.2f%%) high %.2f low %.2f" % (r[0], r[4], 100 * (r[4] / pc - 1), r[2], r[3]))
    R20 = rows[-20:]; hi20, lo20 = max(r[2] for r in R20), min(r[3] for r in R20); L = rows[-1]
    F["range20"] = {"high": round(hi20, 2), "low": round(lo20, 2), "close": L[4], "pct_from_high": round(100 * (hi20 / L[4] - 1), 2), "pct_from_low": round(100 * (L[4] / lo20 - 1), 2)}
    lv = {"20-day high": round(hi20, 2), "20-day low": round(lo20, 2), "last high": round(L[2], 2), "last low": round(L[3], 2), "last close": round(L[4], 2)}
    try:                                                        # the futures money, day by day
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "data", "oistudy.db"), uri=True, timeout=5)
        X = c.execute("select d, spot, foi from day where sym=? order by d desc limit 6", (sym,)).fetchall()[::-1]; c.close()
        F["futures"] = ["%s: price %+.2f%%, futures OI %+.1f%% -> %s" % (X[i][0], 100 * (X[i][1] / X[i - 1][1] - 1), 100 * (X[i][2] / X[i - 1][2] - 1),
                        buildup(X[i][1] - X[i - 1][1], X[i][2] - X[i - 1][2])) for i in range(1, len(X)) if X[i - 1][1] and X[i - 1][2]]
    except Exception:
        pass
    try:                                                        # the option chain's last reading
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        d_ = c.execute("select max(d) from chain where sym=?", (sym,)).fetchone()[0]
        if d_:
            t_ = c.execute("select max(t) from chain where d=? and sym=?", (d_, sym)).fetchone()[0]
            ex = c.execute("select min(exp) from chain where d=? and sym=? and t=? and exp>=?", (d_, sym, t_, str(n.date()))).fetchone()[0]
            Rr = c.execute("select strike, kind, oi from chain where d=? and sym=? and t=? and exp=?", (d_, sym, t_, ex)).fetchall()
            ce = [(k, oi) for k, kd, oi in Rr if kd == "CE" and oi]; pe = [(k, oi) for k, kd, oi in Rr if kd == "PE" and oi]
            if ce and pe:
                roof, floor = max(ce, key=lambda x: x[1])[0], max(pe, key=lambda x: x[1])[0]
                F["options"] = {"as_of": "%s %s" % (d_, str(t_)[:5]), "expiry": ex, "pcr": round(sum(o for _, o in pe) / max(1, sum(o for _, o in ce)), 2), "roof": roof, "floor": floor}
                lv.update({"roof (biggest call OI)": roof, "floor (biggest put OI)": floor})
        F["results_next"] = (c.execute("select min(d) from results_cal where sym=? and d>=?", (sym, str(n.date()))).fetchone() or [None])[0]
        F["results_last"] = (c.execute("select max(d) from results_cal where sym=? and d<?", (sym, str(n.date()))).fetchone() or [None])[0]
        lot = c.execute("select lot from fo_list where sym=?", (sym,)).fetchone()
        F["lot"] = lot[0] if lot else None
        c.close()
    except Exception:
        pass
    try:                                                        # the share's story of the last 7 days
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        Nw = c.execute("select t_pub, h, side, note from items where sym=? and t_pub>? and score>=50 order by t_pub", (sym, n.timestamp() - 7 * 86400)).fetchall(); c.close()
        F["news"] = ["%s %s%s" % (dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %H:%M"), (h or "")[:110], (" · " + re.search(r"AI read: [A-Z]+", note).group(0)) if note and "AI read:" in note else "")
                     for tp, h, sd, note in Nw][-8:]
    except Exception:
        pass
    b = _j(os.path.join(D, "data", "ban.json"), {})
    F["in_fo_ban"] = sym in (b.get("ban") or [])
    try:                                                        # 📚 what a veteran knows about it (patch 386)
        import knowledge
        kn = knowledge.brief(sym)
        if kn:
            F["knowledge"] = kn
    except Exception:
        pass
    if "09:15" <= n.strftime("%H:%M") < "15:30":              # the session is LIVE: today's price so far (the chain above is today's live one)
        q = (_j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}).get(sym)
        if q and q[0]:
            F["today_live"] = {"time": n.strftime("%H:%M"), "price": q[0], "chg_pct": q[1]}
    F["levels_you_may_use"] = lv
    return F


def ask(kind, system, user, model=None, effort="low"):
    if ASK is not None:
        return ASK(kind, system, user)
    import analyst
    return analyst.ask(system, user, 1500, model or WRITER, effort)


def pj(txt):
    a, b = (txt or "").find("{"), (txt or "").rfind("}")
    try:
        return json.loads(txt[a:b + 1]) if a >= 0 and b > a else {}
    except Exception:
        return {}


def write(F):
    """the outlook of one file; every trigger's level must be one of the file's own numbers (within 0.15%)"""
    j = pj(ask("share", WRITE_SYS, json.dumps(F, ensure_ascii=False, indent=0)))
    allowed = {float(v): k for k, v in (F.get("levels_you_may_use") or {}).items() if v}
    T = []
    for t in (j.get("triggers") or [])[:3]:
        try:
            lvl = float(t.get("level"))
        except Exception:
            continue
        hit = next((a for a in allowed if abs(a / lvl - 1) <= 0.0015), None)
        if hit is None or t.get("type") not in ("above", "below"):
            continue                                            # a level not in the file is dropped
        T.append({"type": t["type"], "level": hit, "name": allowed[hit], "side": t.get("side") if t.get("side") in ("CE", "PE") else ("CE" if t["type"] == "above" else "PE"),
                  "say": str(t.get("say") or "")[:120]})
    return {"bias": j.get("bias") if j.get("bias") in ("up", "down", "range", "unclear") else "unclear", "summary": str(j.get("summary") or "")[:220],
            "tomorrow": str(j.get("tomorrow") or "")[:220], "watch": [str(x)[:120] for x in (j.get("watch") or [])[:3]], "triggers": T,
            "catalyst": str(j.get("catalyst") or "")[:160]}


def market_facts(daily, files, n=None):
    n = n or now(); M = {}
    for k in ("NIFTY", "BANKNIFTY", "INDIAVIX"):
        R = [r for r in daily.get(k) or [] if r[0] <= str(n.date())][-6:]
        if len(R) >= 2:
            M[k] = ["%s %.2f (%+.2f%%)" % (R[i][0], R[i][4], 100 * (R[i][4] / R[i - 1][4] - 1)) for i in range(1, len(R))]
    S = _j(os.path.join(D, "data", "seclive.json"), {})
    if S.get("sectors"):
        M["sectors_last"] = ["%s %+.2f%%" % (x["name"], x["chg"]) for x in S["sectors"]]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5); d0 = n.date(); dd = [str(d0)]
        for _ in range(5):
            d0 = next_day(d0); dd.append(str(d0))
        M["results_this_week"] = ["%s: %s" % (d, ", ".join(sorted({s for (s,) in c.execute("select sym from results_cal where d=?", (d,))})) or "none") for d in dd]
        e_ = c.execute("select min(exp) from chain where sym='NIFTY' and exp>=?", (str(n.date()),)).fetchone()
        M["nifty_expiry"] = e_[0] if e_ else None
        c.close()
    except Exception:
        pass
    M["fo_ban"] = (_j(os.path.join(D, "data", "ban.json"), {}).get("ban") or [])
    M["shares"] = ["%s %s: %s%s" % (s, f["w"]["bias"], f["w"]["summary"], (" · catalyst: " + f["w"]["catalyst"]) if f["w"].get("catalyst") else "")
                   for s, f in files.items() if f.get("w") and f["w"].get("bias") in ("up", "down")][:260]
    return M


def build(dry=False, refresh_only=None, n_=None, daily=None, market=True):
    """all the files (or only `refresh_only` shares - the 07:10 refresh) -> data/ready/files.json"""
    n = n_ or now(); FO, SEC, NM = fo_names()
    if daily is None:
        daily = (fetch_daily(FO)[0] if not refresh_only else _j(DAILY, {}).get("rows")) or _j(DAILY, {}).get("rows") or {}
    old = _j(FILES, {}); files = dict(old.get("shares") or {}) if refresh_only else {}
    syms = refresh_only or FO
    facts = {s: gather(s, daily.get(s) or [], SEC, n) for s in syms}
    facts = {s: f for s, f in facts.items() if f}
    if dry:
        return facts

    def one(s):
        try:
            return s, write(facts[s])
        except Exception as ex:
            return s, {"bias": "unclear", "summary": "", "err": str(ex)[:100], "triggers": []}
    with ThreadPoolExecutor(max_workers=6) as P:
        for s, w in P.map(one, list(facts)):
            files[s] = dict(facts[s], w=w, name=NM.get(s, ""), made=n.strftime("%d %b %H:%M"))
    for_day = str(next_day(n.date()) if n.strftime("%H:%M") >= "15:30" else n.date())
    if not market and old.get("market"):                        # a live refresh of a few shares: the market file stays as it is
        st = dict(old, shares=files); _save(st, FILES)
        return st
    M = market_facts(daily, files, n)
    mk = pj(ask("market", MARKET_SYS, json.dumps(M, ensure_ascii=False, indent=0), model=_expert(), effort="medium"))
    br = [x for x in (mk.get("be_ready") or [])[:8] if isinstance(x, dict) and str(x.get("s") or "").upper() in files]
    st = {"for": for_day, "made": n.strftime("%d %b %H:%M"), "market": {"facts": M, "outlook": str(mk.get("outlook") or "")[:600], "sectors": str(mk.get("sectors") or "")[:300],
          "be_ready": [{"s": str(x["s"]).upper(), "side": x.get("side") if x.get("side") in ("CE", "PE", "WATCH") else "WATCH", "why": str(x.get("why") or "")[:160]} for x in br],
          "events": str(mk.get("events") or "")[:300]}, "shares": files}
    _save(st, FILES)
    return st


def _expert():
    try:
        import analyst
        return analyst.EXPERT
    except Exception:
        return "claude-fable-5-2"


def send(t):
    if SEND is not None:
        return SEND(t)
    try:
        import engine2
        return engine2.tg_fo(t)
    except Exception as ex:
        print("ready telegram: %s" % str(ex)[:80], flush=True); return False


def wake(n_=None):
    """07:15 - ⚡ BE READY TODAY (rings): the market outlook, the shares to be ready for with their levels, the day's events"""
    n = n_ or now(); st = _j(FILES, {})
    if st.get("for") != str(n.date()):
        return None
    mk = st.get("market") or {}; L = ["⚡ BE READY TODAY · %s" % n.strftime("%a %d %b")]
    if mk.get("outlook"):
        L.append("🌐 " + mk["outlook"])
    if mk.get("sectors"):
        L.append("🧭 " + mk["sectors"])
    for x in mk.get("be_ready") or []:
        f = (st.get("shares") or {}).get(x["s"]) or {}; w = f.get("w") or {}
        lv = " · ".join("%s %s (%s)" % ("above" if t["type"] == "above" else "below", t["level"], t["name"]) for t in (w.get("triggers") or [])[:2])
        L.append("%s %s %s - %s%s" % ("▲" if x["side"] == "CE" else "▼" if x["side"] == "PE" else "•", x["s"], x["side"], x["why"], (" · levels: " + lv) if lv else ""))
    if mk.get("events"):
        L.append("📅 " + mk["events"])
    L.append("GIR rings again the moment any of these nears or crosses its level · the files are on the page (📁)")
    txt = "\n".join(L); send(txt)
    return txt


def check(n_=None, q=None):
    """every 15 s in market hours: a share nearing / crossing a level from its file -> ⚡ BE READY (rings) + data/ready/hits.json"""
    n = n_ or now(); day = str(n.date()); st = _j(FILES, {})
    if st.get("for") != day:
        return []
    q = q if q is not None else (_j(os.path.join(D, "quotes_live.json"), {}).get("q") or {})
    H = _j(HITS, {})
    if H.get("day") != day:
        H = {"day": day, "hits": [], "last": {}, "done": []}
    done = set(H["done"]); out = []
    for s, f in (st.get("shares") or {}).items():
        px = (q.get(s) or [None])[0]
        if not px:
            continue
        prev = H["last"].get(s) or (f.get("range20") or {}).get("close")
        for t in (f.get("w") or {}).get("triggers") or []:
            lv = float(t["level"]); up = t["type"] == "above"
            crossed = (prev is not None and ((up and prev <= lv < px) or (not up and prev >= lv > px)))
            near = (not crossed) and ((up and lv * (1 - NEAR) <= px <= lv) or (not up and lv <= px <= lv * (1 + NEAR)))
            kind = "crossed" if crossed else "near" if near else None
            key = "%s|%s|%s|%s" % (s, t["type"], lv, kind)
            if not kind or key in done or (kind == "near" and "%s|%s|%s|crossed" % (s, t["type"], lv) in done):
                continue
            done.add(key)
            w = f.get("w") or {}; chg = (q.get(s) or [None, None])[1]
            txt = "\n".join(x for x in [
                "⚡ BE READY %s %s · %s %s (%s) · %s" % ("▲" if t["side"] == "CE" else "▼", s, "CROSSED" if crossed else "NEAR", lv, t["name"], n.strftime("%H:%M")),
                "₹%.2f%s · the file said: %s → %s side%s" % (px, (" (%+.2f%% today)" % chg) if chg is not None else "", t["say"] or "a level that matters", t["side"], ""),
                ("why: " + w["summary"]) if w.get("summary") else "", ("catalyst: " + w["catalyst"]) if w.get("catalyst") else "",
                ("news: " + f["news"][-1]) if f.get("news") else "",
                "be ready - not a trade by itself: the 🧠 analyst reads it now · the strike, size and stop are your call"] if x)
            h = {"s": s, "t": n.strftime("%H:%M"), "ts": n.timestamp(), "kind": kind, "type": t["type"], "level": lv, "name": t["name"], "side": t["side"], "px": px}
            H["hits"].append(h); out.append((h, txt))
        H["last"][s] = px
    H["done"] = sorted(done); _save(H, HITS)                    # the page first
    for h, txt in out:
        send(txt)                                               # then Telegram
    return out


LIVE_CAP, LIVE_GAP, BIG_MOVE = 150, 1800, 2.0


def live_events(last, n=None):
    """during trading: {sym: why} - fresh AI-read news (not neutral), a 🧭 policy story, or a move of 2%+ since its file was written"""
    n = n or now(); ev = {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        for s_, h, note in c.execute("select sym, h, note from items where t_seen>? and score>=60 and note like '%AI read: %' and note not like '%AI read: NEUTRAL%'", (last,)):
            ev.setdefault(s_, "news: %s (%s)" % ((h or "")[:90], re.search(r"AI read: [A-Z]+", note).group(0)))
        c.close()
    except Exception:
        pass
    try:
        for k, v in (_j(os.path.join(D, "data", "policymap.json"), {}).get("sent") or {}).items():
            if v.get("t", 0) > last:
                ev.setdefault(k.split("|")[1], "policy: %s" % v.get("h", "")[:90])
    except Exception:
        pass
    st = _j(FILES, {}); q = _j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}
    for s_, f in (st.get("shares") or {}).items():
        v = q.get(s_)
        base = (f.get("today_live") or {}).get("chg_pct") or 0.0
        if v and v[1] is not None and abs(float(v[1]) - float(base)) >= BIG_MOVE:
            ev.setdefault(s_, "a move: %+.2f%% today (%+.2f%% since its file was written)" % (v[1], float(v[1]) - float(base)))
    return {s_: w for s_, w in ev.items() if s_ in (st.get("shares") or {})}


def live_refresh(ev, n_=None):
    """rewrite the files of the shares with a fresh event, at once, and tell Rama what changed (⚡ BE READY · FILE UPDATED - rings)"""
    n = n_ or now(); day = str(n.date()); H = _j(HITS, {})
    if H.get("day") != day:
        H = {"day": day, "hits": [], "last": {}, "done": []}
    LV = H.setdefault("live", {}); n_live = sum(1 for v in LV.values() if v.get("day") == day)
    todo = [s_ for s_ in ev if n.timestamp() - (LV.get(s_) or {}).get("ts", 0) >= LIVE_GAP or ev[s_].startswith(("news", "policy"))][:max(0, LIVE_CAP - n_live)]
    if not todo:
        return []
    old = {s_: ((_j(FILES, {}).get("shares") or {}).get(s_) or {}).get("w") or {} for s_ in todo}
    st = build(refresh_only=todo, market=False, n_=n)
    out = []
    for s_ in todo:
        f = (st.get("shares") or {}).get(s_) or {}; w = f.get("w") or {}
        LV[s_] = {"day": day, "ts": n.timestamp(), "why": ev[s_]}
        turned = old[s_].get("bias") and old[s_].get("bias") != w.get("bias")
        lv = " · ".join("%s %s (%s) → %s" % (t["type"], t["level"], t["name"], t["side"]) for t in w.get("triggers") or [])
        txt = "\n".join(x for x in [
            "⚡ BE READY %s %s · FILE UPDATED · %s" % ("▲" if w.get("bias") == "up" else "▼" if w.get("bias") == "down" else "•", s_, n.strftime("%H:%M")),
            "what happened: " + ev[s_],
            ("the picture TURNED: %s → %s" % (old[s_].get("bias"), w.get("bias"))) if turned else "",
            "now: " + (w.get("summary") or "-"), ("next: " + w["tomorrow"]) if w.get("tomorrow") else "", ("levels: " + lv) if lv else "",
            "be ready - the 🧠 analyst reads it now · the strike, size and stop are your call"] if x)
        h = {"s": s_, "t": n.strftime("%H:%M"), "ts": n.timestamp(), "kind": "updated", "type": "", "level": None, "name": ev[s_][:60], "side": "CE" if w.get("bias") == "up" else "PE" if w.get("bias") == "down" else "", "px": (f.get("today_live") or {}).get("price")}
        H["hits"].append(h); out.append((h, txt))
    _save(H, HITS)                                              # the page first
    for h, txt in out:
        send(txt)                                               # then Telegram
    return out


def view(sym=None):
    st = _j(FILES, {})
    if sym:
        f = (st.get("shares") or {}).get(str(sym).upper())
        return {"for": st.get("for"), "made": st.get("made"), "file": f}
    H = _j(HITS, {})
    return {"for": st.get("for"), "made": st.get("made"), "market": {k: v for k, v in (st.get("market") or {}).items() if k != "facts"},
            "hits": H.get("hits") if H.get("day") == str(now().date()) else [], "n": len(st.get("shares") or {}), "t": time.time()}


def overnight_syms(n=None):
    """the shares with news since the evening build (the 07:10 refresh)"""
    n = n or now(); out = set()
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        out = {s for (s,) in c.execute("select distinct sym from items where t_seen>? and score>=60", (n.timestamp() - 12 * 3600,))}; c.close()
    except Exception:
        pass
    FO, _, _ = fo_names()
    return sorted(out & set(FO)) if FO else sorted(out)


def run():
    print("ready files up: build 19:50 · refresh 07:10 · ⚡ BE READY 07:15 · level watch + LIVE file updates 09:15-15:30", flush=True)
    done = set(); last_live = time.time()
    while True:
        n = now(); hm = n.strftime("%H:%M"); day = str(n.date())
        try:
            if n.weekday() < 5:
                st = _j(FILES, {})
                if "19:50" <= hm < "21:30" and (day, "build") not in done and st.get("for") != str(next_day(n.date())):
                    done.add((day, "build")); s_ = build(); print("%s files built: %d shares" % (hm, len(s_.get("shares") or {})), flush=True)
            if n.weekday() == 4 and "21:30" <= hm < "23:30" and (day, "kb") not in done:   # Friday night (Kite's login still valid): the knowledge base renewed (patch 386)
                done.add((day, "kb"))
                try:
                    import knowledge
                    knowledge.build(); print("%s knowledge base renewed" % hm, flush=True)
                except Exception as ex:
                    print("knowledge: %s" % str(ex)[:120], flush=True)
            if n.weekday() < 5:
                if "07:10" <= hm < "09:00" and (day, "refresh") not in done:
                    done.add((day, "refresh"))
                    if st.get("for") == day:
                        R = overnight_syms(n)
                        if R:
                            build(refresh_only=R); print("%s refreshed %d files" % (hm, len(R)), flush=True)
                    else:
                        build(); print("%s files built in the morning (the evening build was missed)" % hm, flush=True)
                if "07:15" <= hm < "09:15" and (day, "wake") not in done and _j(FILES, {}).get("for") == day:
                    done.add((day, "wake")); wake()
                if "09:15" <= hm <= "15:30":
                    for h, _ in check():
                        print("%s ⚡ %s %s %s" % (hm, h["s"], h["kind"], h["level"]), flush=True)
                    ev = live_events(last_live); last_live = time.time()
                    if ev and _j(FILES, {}).get("for") == day:
                        for h, _ in live_refresh(ev):
                            print("%s ⚡ %s file updated: %s" % (hm, h["s"], h["name"]), flush=True)
        except Exception as ex:
            print("ready: %s" % str(ex)[:160], flush=True)
        time.sleep(15)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["run"]:
        run()
    elif a[:1] == ["build"]:
        r = build(dry="--dry" in a)
        print(json.dumps(r if "--dry" in a else {"for": r.get("for"), "n": len(r.get("shares") or {}), "market": r.get("market", {}).get("outlook")}, ensure_ascii=False, indent=1)[:4000])
    elif a[:1] == ["show"] and a[1:]:
        print(json.dumps(view(a[1]), ensure_ascii=False, indent=1))
    elif a[:1] == ["wake"]:
        print(wake())
