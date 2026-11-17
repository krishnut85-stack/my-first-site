#!/usr/bin/env python3
"""overnight.py - patch 358: CATCH THE OVERNIGHT NEWS, AND OBSERVE (Rama, 17 Nov, on "EU targets Indian steel with 9.5% duty": "these are
macro news. You need to catch these news and observe."). GIR's news desks already collect such lines through the night (the EU duty was in
GIR's list at 22:59). What was missing: one list BEFORE THE OPEN of what came after yesterday's close, which F&O shares it touches and which way
- and a record of what those shares then did, so we learn whether such news is all in the opening gap or still pays after the open.
  make    (08:35, before the open) the lines GIR collected since the last close - the market-wide desk (macro.py: Finance Ministry, RBI, SEBI,
          trade duties, the Fed, crude ...) and the company news GIR sent (alerts) - plus (patch 362) the headlines of the Indian business papers
          and the world's wires and markets (Google News searches) - are read once by Claude (OVERNIGHT_MODEL, else
          claude-haiku-5-5; the key in the server's .env). It may use only those lines and only GIR's F&O shares, and returns for each story:
          time, headline, the F&O shares touched, up / down / unclear, strong / moderate / weak, one clause why. -> data/overnight.json
  score   (15:50) every listed share with a direction: the OPENING GAP its way, open -> 10:00 and open -> 15:10 its way (Kite 5-minute prices)
          -> data/overnight_log.json, the running record by strength. The gap cannot be traded; the two after-the-open columns can.
  view()  for the page: today's list and the record.
  patch 380 (Rama, 17 Nov 16:45: "start monitoring all the news and the overnight sector movement, and keep the list ready at 07:00"):
  07:00   the list is made at 07:00 (not 08:35), and now also reads the OVERNIGHT MARKETS (morningmkts.py: the US indices and sector funds,
          the Indian companies in New York, crude, metals, gold, the yield, the dollar, the rupee, Asia): every big move becomes a line for the
          reader AND a 🌍 MARKET item on the list (the F&O shares it usually moves, which way, why) · the SECTOR TILT (which Indian sectors the
          night's markets point up or down) · TODAY'S CALENDAR (results due today and last evening, the F&O ban list) · 👀 WATCH AT THE OPEN
          (a share that two or more items point the same way)
  08:35   the same again with the fresh markets and news (Asia is open by then); what is new since 07:00 is marked NEW
  15:50   the score as before - the 🌍 MARKET items are scored too, so the record shows whether the market links pay ("market" row)
A paper record: no sound, no Telegram, no order.     python3 overnight.py make | score [YYYY-MM-DD] | auto | show"""
import os, re, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "overnight.json")
LOG = os.path.join(D, "data", "overnight_log.json")
MODEL = os.environ.get("OVERNIGHT_MODEL") or "claude-haiku-5-5"

SYSTEM = """You prepare a short morning list for an Indian F&O options trader: the news that arrived after yesterday's market close and could move an F&O share at today's open. You are given (1) news lines his own system collected, each with its time, and (2) his F&O shares grouped by sector.

Rules:
- Use only the lines given. Never add news, numbers or events of your own.
- Keep a story only if it could plausibly move a share at the open: government or regulator action, duties and tariffs, court orders, results, large orders, approvals or bans, big global moves (crude, the dollar, US markets, metals). Drop routine items: small fines, small orders, meetings, ESOPs, reviews with no decision, opinion pieces, lists of "stocks to watch".
- The same story from several sources is ONE item (use the earliest time).
- "shares" may contain only symbols from the F&O list given, the ones most directly touched (at most 6). If a story touches a whole sector, list that sector's largest F&O shares. If it touches no F&O share, drop it.
- "dir": "up", "down" or "unclear". Say "unclear" when the line does not tell - do not guess.
- "strength": "strong" (a decision with a number that changes profits), "moderate", or "weak".
- A world headline that names no Indian company (US shares, the Fed, crude, metals, the dollar, the US FDA, visas) may be kept only where the link to an Indian sector is direct and well known - crude to oil marketers, paints and airlines; US technology shares and visas to IT; metal prices to metals; US drug rules to pharma; the dollar to exporters. Give it at most "moderate" and begin its "why" with "read-across:".
- BUDGET talk (pre-budget meetings, what an industry asks for, what economists advise) is an expectation, not a decision: keep it only when it names a sector or a tax that F&O shares depend on, give it "weak" - or "moderate" when a minister or a named official signals it - and begin its "why" with "budget:". A decision already taken is rated like any other news.
- At most 14 items, the strongest first.

Answer with a JSON array only, no other text. Each item: {"time": "HH:MM", "headline": "...", "shares": ["SYM"], "dir": "...", "strength": "...", "why": "one short clause"}. If nothing qualifies, answer []."""


def _load(path, default):
    try:
        return json.load(open(path))
    except Exception:
        return default


def _save(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path + ".tmp", "w"), ensure_ascii=False); os.replace(path + ".tmp", path)


def last_close(now):
    """15:30 of the last trading day before today (weekends skipped; a holiday only makes the window longer)"""
    d = now.date() - dt.timedelta(days=1)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    return dt.datetime.combine(d, dt.time(15, 30), IST)


# patch 362: the newspapers and the world (Rama, 17 Nov: "daily Indian newspapers like Business Standard and The Hindu, and worldwide newspapers?").
#   GIR's market desk keeps a headline only when it names India - so the Fed, crude, US shares, metal prices never reached the list. For the
#   morning list these Google News searches are read once (headlines only - the papers' full text is behind their paywalls):
WORLD = (("Indian papers", '(site:thehindubusinessline.com OR site:business-standard.com OR site:financialexpress.com OR site:thehindu.com) (stocks OR shares OR sector OR tariff OR duty OR policy OR ban OR approval OR results) when:1d'),
         ("world wires on India", '(site:reuters.com OR site:bloomberg.com OR site:cnbc.com OR site:ft.com OR site:wsj.com) (India OR Indian) (stocks OR market OR economy OR company OR tariff) when:1d'),
         ("US markets", '("Wall Street" OR Nasdaq OR "S&P 500" OR "Federal Reserve" OR "Treasury yields" OR "US inflation") (falls OR rises OR slumps OR rallies OR record OR cut OR hike OR surges) when:1d'),
         ("commodities", '(crude OR Brent OR "oil prices" OR copper OR aluminium OR "steel prices" OR "iron ore" OR gold) (jumps OR falls OR surges OR slumps OR record OR plunges) when:1d'),
         ("trade and tariffs", '(tariff OR "anti-dumping" OR sanctions OR "export ban" OR "import duty") (India OR China OR EU OR "United States") when:1d'),
         # patch 363: the BUDGET watch (Rama, 17 Nov: "from yesterday the budget meeting started") - what each industry asks for and what officials signal
         ("budget", '("pre-budget" OR "Budget 2027" OR "Union Budget" OR "budget expectations" OR "budget wishlist") (sector OR industry OR seeks OR urges OR demands OR tax OR duty OR STT OR LTCG OR allocation OR incentive) when:1d'),
         ("pharma and IT abroad", '("US FDA" OR USFDA OR "H-1B" OR "visa fee" OR "drug pricing" OR "Nasdaq tech" OR "AI spending") when:1d'))


def world(since):
    """[(when, source, headline)] from the searches above, published since the last close - any search that fails is skipped"""
    import requests, xml.etree.ElementTree as ET
    from email.utils import parsedate_to_datetime
    from urllib.parse import quote
    out = []
    for name, q in WORLD:
        try:
            r = requests.get("https://news.google.com/rss/search?q=" + quote(q) + "&hl=en-IN&gl=IN&ceid=IN:en", headers={"User-Agent": "Mozilla/5.0"}, timeout=20)
            if r.status_code != 200:
                continue
            n = 0
            for it in ET.fromstring(r.content).iter("item"):
                try:
                    t = parsedate_to_datetime(it.findtext("pubDate") or "").astimezone(IST)
                except Exception:
                    continue
                h = (it.findtext("title") or "").strip(); src = (it.findtext("source") or "").strip() or name
                if t >= since and h:
                    out.append((t, "%s · %s" % (src, name), re.sub(r"\s+-\s+[^-]{2,40}$", "", h))); n += 1
                    if n >= 22:
                        break
        except Exception:
            pass
    return out


def lines(now):
    """what GIR collected since the last close: [(when, source, text)] - the market-wide desk and the company news GIR sent, the same story once"""
    since = last_close(now); out, seen = [], set()

    def add(t, src, txt):
        k = re.sub(r"[^a-z0-9]", "", txt.lower())[:48]
        if txt and k not in seen:
            seen.add(k); out.append((t, src, txt[:230]))
    try:
        for x in _load(os.path.join(D, "data", "macro.json"), {}).get("items") or []:
            t = dt.datetime.fromtimestamp(float(x.get("t") or 0), IST)
            if t >= since and (x.get("score") or 0) >= 4:
                add(t, str(x.get("src") or "market desk"), str(x.get("h") or ""))
    except Exception:
        pass
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=10)
        for day, t, kind, sym, text in c.execute("select day, t, kind, sym, text from alerts where day>=? order by day, t", (str(since.date()),)):
            if kind not in ("📰", "🚨", "📄", "🏛"):
                continue
            try:
                when = dt.datetime.combine(dt.date.fromisoformat(day), dt.time.fromisoformat(str(t)[:8]), IST)
            except Exception:
                continue
            if when < since:
                continue
            ln = [x.strip() for x in str(text or "").split("\n") if x.strip() and not re.match(r"(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|🔔 OPENING|⚠ NOT SENT|↳)", x.strip())]
            if len(ln) >= 2 or (ln and len(ln[0]) > 40):
                add(when, str(sym or ""), " | ".join(ln[:2]))
        c.close()
    except Exception:
        pass
    own = len(out)
    for t, src, h in world(since):
        add(t, src, h)
    out.sort(key=lambda x: x[0])
    return since, out[-230:]


def market_part(now, FO, M=None, cal=None):
    """patch 380: the overnight markets -> 🌍 MARKET items, the sector tilt, today's calendar. M / cal can be given (the test)"""
    import morningmkts as MM
    if M is None:
        try:
            M = MM.markets()
        except Exception as ex:
            M = []; print("overnight: the markets were not read: %s" % str(ex)[:80], flush=True)
    if cal is None:
        cal = MM.calendar(now.date())
        try:                                                 # results declared last evening (after the close) count too
            d = now.date() - dt.timedelta(days=1)
            while d.weekday() > 4:
                d -= dt.timedelta(days=1)
            c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=10)
            cal["results_prev"] = sorted({s for (s,) in c.execute("select sym from results_cal where d=?", (str(d),))}); c.close()
        except Exception:
            cal["results_prev"] = []
    for k in ("results", "results_prev", "ban"):
        cal[k] = [s for s in (cal.get(k) or []) if s in FO]
    items, tilt = [], {}
    for m in M:
        if not (m.get("ok") and m.get("big")):
            continue
        mv = "%s %s%.2f%s" % (m["name"], "+" if m["chg"] > 0 else "", m["chg"], "%" if m.get("unit") == "%" else " pts")
        for l in m["links"]:
            if l["dir"] in ("up", "down"):
                t_ = tilt.setdefault(l["sector"], {"up": [], "down": []}); t_[l["dir"]].append(mv)
            sh = [s for s in l["shares"] if s in FO][:6]
            if sh:
                items.append({"time": (m.get("at") or "")[-5:], "headline": "%s overnight (as of %s)" % (mv, m.get("at") or "?"), "shares": sh, "dir": l["dir"] if l["dir"] in ("up", "down") else "unclear",
                              "strength": "market", "kind": "market", "why": "read-across: " + l["why"]})
    TL = []
    for sec, v in tilt.items():
        n = len(v["up"]) - len(v["down"])
        TL.append({"sector": sec, "dir": "up" if n > 0 else "down" if n < 0 else "mixed", "up": v["up"], "down": v["down"]})
    TL.sort(key=lambda x: (x["sector"] != "whole market", -abs(len(x["up"]) - len(x["down"])), x["sector"]))
    mk = [{k: m.get(k) for k in ("sym", "name", "ok", "chg", "unit", "at", "big")} for m in M]
    return M, mk, items, TL, cal


def watch_list(items, cal):
    """👀 a share with a NEWS item and at least one more item (news or market) the SAME way, and none the other way - two market links alone
    are left to the sector tilt (on a strong Nasdaq night every IT share would be listed); results / ban added as facts"""
    W = {}
    for it in items:
        for s in it["shares"]:
            if it["dir"] in ("up", "down"):
                mk_ = it.get("kind") == "market"
                W.setdefault(s, {"up": [], "down": []})[it["dir"]].append((mk_, ("🌍 " + it["headline"].split(" overnight")[0]) if mk_ else ("📰 " + it["headline"][:80])))
    out = []
    for s, v in W.items():
        for d_, o_ in (("up", "down"), ("down", "up")):
            if len(v[d_]) >= 2 and any(not m for m, _ in v[d_]) and not v[o_]:
                out.append({"s": s, "dir": d_, "why": [w for m, w in sorted(v[d_], key=lambda x: x[0])][:3],
                            "results": s in (cal.get("results") or []) or s in (cal.get("results_prev") or []), "ban": s in (cal.get("ban") or [])})
    return sorted(out, key=lambda x: -len(x["why"]))[:8]


def make(now=None, update=False, M=None, cal=None):
    """the morning list -> data/overnight.json (07:00; `update` at 08:35 keeps the 07:00 time and marks what is new)"""
    import seclive as SL
    now = now or dt.datetime.now(IST); day = str(now.date())
    since, LN = lines(now)
    SEC, _ = SL.universe(); FO = SL.fo_set(); W, _w = SL.nse_weights()
    by = {}
    for s in sorted(FO, key=lambda s: -(W.get(s) or 0)):
        by.setdefault(SEC.get(s, "other"), []).append(s)
    M, mk, mitems, TL, cal = market_part(now, FO, M, cal)
    try:
        import morningmkts as MM
        for x in MM.lines_for_model(M):
            LN.append((now, "world markets", x))
    except Exception:
        pass
    prev = _load(OUT, {})
    st = {"day": day, "at": now.strftime("%H:%M"), "since": since.strftime("%d %b %H:%M"), "n_lines": len(LN), "items": [], "scored": False, "model": MODEL,
          "mkts": mk, "tilt": TL, "cal": cal, "watch": [], "first_at": prev.get("first_at") or prev.get("at") if (update and prev.get("day") == day) else now.strftime("%H:%M"), "upd": bool(update)}
    old = {re.sub(r"[^a-z0-9]", "", (it.get("headline") or "").lower())[:40] for it in (prev.get("items") or [])} if (update and prev.get("day") == day) else None
    if not LN:
        st["items"] = mitems; st["watch"] = watch_list(mitems, cal)
        st["note"] = "GIR collected no news lines since the close"; _save(st, OUT); return st
    import anthropic
    user = "The news lines collected since %s IST (time · source · text):\n%s\n\nThe F&O shares by sector (the largest first):\n%s" % (
        since.strftime("%d %b %H:%M"), "\n".join("%s · %s · %s" % (t.strftime("%d %b %H:%M"), src, txt) for t, src, txt in LN), json.dumps(by, ensure_ascii=False))
    try:
        with anthropic.Anthropic().messages.stream(model=MODEL, max_tokens=16000, system=SYSTEM, messages=[{"role": "user", "content": user}]) as s_:
            r = s_.get_final_message()
    except Exception as ex:                                  # patch 380: the markets and the calendar are kept even when the reader fails
        st["items"] = mitems; st["watch"] = watch_list(mitems, cal); st["note"] = "the news reader failed (%s) - the market items only" % str(ex)[:60]
        _save(st, OUT); return st
    txt = "\n".join(b.text for b in r.content if b.type == "text")
    a, b = txt.find("["), txt.rfind("]")
    try:
        raw = json.loads(txt[a:b + 1]) if a >= 0 and b > a else []
    except Exception:
        raw = []; st["note"] = "the reading could not be parsed"
    for x in raw if isinstance(raw, list) else []:
        if not isinstance(x, dict):
            continue
        sh = [s for s in (str(v).upper().strip() for v in (x.get("shares") or [])) if s in FO][:6]
        if not sh:
            continue
        st["items"].append({"time": str(x.get("time") or "")[:11], "headline": str(x.get("headline") or "")[:170], "shares": sh,
                            "dir": x.get("dir") if x.get("dir") in ("up", "down") else "unclear", "strength": x.get("strength") if x.get("strength") in ("strong", "moderate", "weak") else "weak",
                            "why": str(x.get("why") or "")[:140]})
    st["items"] = st["items"][:14] + mitems; st["tokens"] = [r.usage.input_tokens, r.usage.output_tokens]
    st["watch"] = watch_list(st["items"], cal)
    if old is not None:
        for it in st["items"]:
            if it.get("kind") != "market" and re.sub(r"[^a-z0-9]", "", it["headline"].lower())[:40] not in old:
                it["new"] = True
    if r.stop_reason == "refusal":
        st["note"] = "the model declined to read"
    _save(st, OUT)
    return st


def score(day=None):
    """what the listed shares did: the opening gap, open -> 10:00 and open -> 15:10, each in the listed direction -> the log"""
    import getdata, seclive as SL
    day = day or str(dt.datetime.now(IST).date()); st = _load(OUT, {})
    if st.get("day") != day or not st.get("items"):
        return None
    kite = SL.get_kite(); d0 = dt.date.fromisoformat(day)
    tok = {i["tradingsymbol"]: int(i["instrument_token"]) for i in getdata.call(kite.instruments, "NSE") if i.get("instrument_type") == "EQ"}
    syms = sorted({s for it in st["items"] for s in it["shares"]}); px = {}
    for s in syms:
        try:
            if s not in tok:
                continue
            b = kite.historical_data(tok[s], dt.datetime.combine(d0 - dt.timedelta(days=6), dt.time(9, 15)), dt.datetime.combine(d0, dt.time(15, 30)), "5minute"); time.sleep(0.36)
            td = [r for r in b if r["date"].date() == d0]; pv = [r for r in b if r["date"].date() < d0]
            if len(td) < 20 or not pv:
                continue
            mn = lambda r: r["date"].hour * 60 + r["date"].minute
            a10 = [r for r in td if mn(r) <= 595]; e = [r for r in td if mn(r) <= 905]
            px[s] = (float(pv[-1]["close"]), float(td[0]["open"]), float(a10[-1]["close"]), float(e[-1]["close"]))
        except Exception as ex:
            print("overnight score %s: %s" % (s, str(ex)[:80]), flush=True)
    rows = []
    for it in st["items"]:
        it["res"] = {}
        for s in it["shares"]:
            if s not in px:
                continue
            pc_, o, p10, pe = px[s]; dr = 1 if it["dir"] == "up" else -1 if it["dir"] == "down" else 0
            it["res"][s] = {"day_pct": round(100 * (pe / pc_ - 1), 2), "gap": round(100 * (o / pc_ - 1), 2), "o10": round(100 * (p10 / o - 1), 2), "oc": round(100 * (pe / o - 1), 2)}
            if dr:
                rows.append({"s": s, "strength": it["strength"], "gap": round(100 * (o / pc_ - 1) * dr, 2), "o10": round(100 * (p10 / o - 1) * dr, 2), "oc": round(100 * (pe / o - 1) * dr, 2)})
    st["scored"] = True; _save(st, OUT)
    lg = _load(LOG, {"days": {}}); lg["days"][day] = rows; _save(lg, LOG)
    return rows


def view():
    """the page: today's list (or the last one made) + the record by strength: [cases, gap, open->10:00, open->15:10, % of cases the open->15:10 paid]"""
    st = _load(OUT, {}); lg = _load(LOG, {"days": {}}); rec = {}
    for d, rows in sorted(lg.get("days", {}).items()):
        for r in rows:
            for k in ((r.get("strength") or "weak", "all") if r.get("strength") != "market" else ("market",)):   # patch 380: the market links kept apart
                a = rec.setdefault(k, [0, 0.0, 0.0, 0.0, 0]); a[0] += 1; a[1] += r["gap"]; a[2] += r["o10"]; a[3] += r["oc"]; a[4] += r["oc"] > 0
    rec = {k: [a[0], round(a[1] / a[0], 2), round(a[2] / a[0], 2), round(a[3] / a[0], 2), round(100 * a[4] / a[0])] for k, a in rec.items() if a[0]}
    return {"day": st.get("day"), "at": st.get("at"), "since": st.get("since"), "items": st.get("items") or [], "scored": bool(st.get("scored")), "note": st.get("note"),
            "n_lines": st.get("n_lines"), "record": rec, "days": len(lg.get("days", {})), "t": time.time(),
            "mkts": st.get("mkts") or [], "tilt": st.get("tilt") or [], "cal": st.get("cal") or {}, "watch": st.get("watch") or [], "first_at": st.get("first_at"), "upd": bool(st.get("upd"))}


if __name__ == "__main__":
    a = sys.argv[1:]; now = dt.datetime.now(IST)
    if a[:1] == ["auto"]:                                    # the timer: before the open = make (once a day) · after 15:40 = score (once)
        st = _load(OUT, {}); hm = now.strftime("%H:%M")
        if hm < "09:15" and st.get("day") != str(now.date()):
            a = ["make"]
        elif "08:20" <= hm < "09:15" and st.get("day") == str(now.date()) and not st.get("upd"):   # patch 380: the 08:35 refresh of the 07:00 list
            a = ["update"]
        elif hm >= "15:40" and st.get("day") == str(now.date()) and not st.get("scored"):
            a = ["score"]
        else:
            print("overnight: nothing to do at %s" % hm); sys.exit(0)
    if a[:1] in (["make"], ["update"]):
        st = make(now, update=a[:1] == ["update"]); print("overnight %s: %d news lines since %s -> %d items%s" % (st["day"], st["n_lines"], st["since"], len(st["items"]), (" · " + st["note"]) if st.get("note") else ""))
    elif a[:1] == ["score"]:
        r = score(a[1] if a[1:] else None); print("overnight scored: %s" % (("%d share-rows" % len(r)) if r is not None else "no list for that day"))
    v = view()
    for it in v["items"]:
        print("  %s %-8s %-8s %s · %s%s" % (it["time"], {"up": "▲ UP", "down": "▼ DOWN"}.get(it["dir"], "unclear"), it["strength"], " ".join(it["shares"]), it["headline"][:90],
              (" · " + " ".join("%s gap %+.1f%% then %+.1f%%" % (s, r["gap"], r["oc"]) for s, r in it.get("res", {}).items())) if it.get("res") else ""))
    print("  record (%d days): %s" % (v["days"], " · ".join("%s: %d cases, gap %+.2f%%, open→10:00 %+.2f%%, open→15:10 %+.2f%% (%d%% paid)" % (k, *r) for k, r in sorted(v["record"].items())) or "no day scored yet"))
