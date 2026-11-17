#!/usr/bin/env python3
"""analyst.py - patch 384: 🧠 GIR ANALYST - A MARKET EXPERT AT GIR'S DESK (Rama, 17 Nov 19:20: "I need someone in GIR who represents the share
market - an intelligent AI agent who knows the Indian and global markets, understands what is happening and directs me to the share
concerned: 'hey, this share is at its high and this will affect it', or 'Laurus Labs - we have the news, buy now'. Smart and lightning fast,
so I can execute in time. Not only the daily news - the sectors building through the night and the day, sector rotation, market news...").
GIR already collects all of it; nobody put it together and SAID it. The analyst does, in plain trading words:
  THE PICTURE  every minute 09:15-15:30, and AT ONCE (within ~20 s) when an important news reading, a 🧭 policy story or a 🎯 GIR DECIDES
               call arrives: NIFTY / BANKNIFTY · the sectors by size and their rotation (15 / 30 / 60 min) · the F&O movers and why they move
               (moverswhy) · the futures build-up (futlive) · the last 45 min of news with the AI's reading (news.db), the market desk
               (macro.json) and the policy map · the good alert types firing in the last 15 min · GIR DECIDES · the 07:00 list
  THE BRAIN    two models (Rama, 17 Nov 19:45: "a senior market expert, not a baby, who has all the knowledge"): the fast watcher
               (Claude Haiku 5.5, ANALYST_MODEL) looks every minute; the SENIOR EXPERT (Claude Fable 5.2, Anthropic's most capable model,
               ANALYST_EXPERT_MODEL) decides every call that reaches him, reads every fresh news / policy / GIR DECIDES event itself,
               answers his questions and writes the briefings - with a market expert's brief (Indian sectors and F&O shares, how policy / crude / the rupee /
               US markets move them, and which of GIR's signals are PROVEN and which are not). It may use ONLY the facts it is given.
  THE DESKS    (deskteam.py) six specialist agents - sectors & rotation, news & policy, money flow, global & macro, price action, risk -
               write a note every 3 minutes and at once on a fresh event; the senior expert reads all six before deciding
  THE CALLS    at most 3 at a time: SHARE · CE / PE / WATCH / AVOID / CAUTION · one line why (the facts it rests on) · NOW or WATCH.
               A NOW call needs the price already moving its way AND a second, different kind of fact (news, sector, futures, a GIR call).
               It does not repeat itself; it can turn a call (CAUTION) when the facts turn.
  -> data/analyst.json (the page FIRST: the 🧠 box at the top of TRADE NOW) -> Telegram: NOW rings (🧠), WATCH / AVOID / CAUTION quiet (📄).
  THE RECORD   every call keeps its price; at 15:12 the 15:10 price -> its move its way; the running record (data/analyst_log.json) is on the
               page - the analyst is NOT proven; the record will say within days whether it beats the plain rules.
  BRIEFINGS    07:05 (after the 07:00 list) and 19:45 (after WHO & WHY): the day / the night in plain words - which sectors built up,
               the rotation, what to watch at the open. Page + Telegram (quiet).
The key is read from the server's .env (never printed). Orders nothing.
  python3 analyst.py run              the service (gir-analyst)
  python3 analyst.py once [--dry]     one reading now (--dry: the facts it would send, no model call)
  python3 analyst.py brief            a briefing now
  python3 analyst.py ask "question"   ask the analyst now (the page has an ASK box: answered within seconds)"""
import os, re, sys, json, time, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "analyst.json")
LOG = os.path.join(D, "data", "analyst_log.json")
MODEL = os.environ.get("ANALYST_MODEL") or "claude-haiku-5-5"            # the fast watcher, every minute
EXPERT = os.environ.get("ANALYST_EXPERT_MODEL") or "claude-fable-5-2"     # the SENIOR expert (Rama, 17 Nov: "a senior market expert, not a baby"):
EVERY, DAY_CAP, EXPERT_CAP = 60, 450, 200                                 # every call that reaches him, every answer, every briefing
SEND = None                                                   # tests put a list's append here
ASK = None                                                    # tests put a stand-in model here: ASK(system, user) -> text
SYSTEM = """You are the senior market analyst at an Indian F&O options trader's desk. You know the Indian market well: NSE sectors and their
F&O shares, how a sector's leaders pull it, how regulator and government actions hit groups of shares (SEBI rules on margin trading or F&O
hit brokers, exchanges and depositories; RBI rules hit lenders; crude hits oil marketers, paints and airlines; the rupee hits IT and pharma
exporters; US tech moves Indian IT sentiment; metal prices move metal producers), and how a promoter's stake sale, a block deal, a results
surprise, an order or a regulator's action moves a share.
You are given ONLY facts collected by the trader's own system in the last minutes. Your job: tell him, in plain trading words, what matters
NOW and which share to act on.
What his system has PROVEN on its own data (use it):
- Price-led signals early in the day pay: two different good alert types agreeing on a share before 10:30 (GIR DECIDES) beat the shares
  moving at the same time; the opening alerts were the best single type.
- Overnight news and world markets mostly show in the OPENING price; after the open they have not paid on their own.
- Shares that already moved 2%+ before an alert did NOT do worse after it - do not refuse a call only because it has moved.
- A news headline's words can mislead ("rules out stake sale" is GOOD news); trust the AI's full-story reading given with the news.
Rules:
- Use ONLY the facts given. Never invent news, numbers, levels, times or reasons. If a level is not in the facts, do not give one.
- "share_knowledge" is what a veteran knows about each share in focus: its usual range, its beta, how it reacts to crude / the rupee / US
  markets, and how it typically reacts to each kind of event. Use it: a 2% move is big for a share whose usual move is 0.8%, routine for one
  whose usual move is 3%; judge a news item by how THIS share has reacted to such news before.
- "desk_notes" are your six specialist desks (sectors & rotation, news & policy, money flow, global & macro, price action, risk). Weigh
  them: a call is strongest when two or more desks point the same way; respect the RISK desk's warnings; you decide.
- A NOW call needs BOTH: the share's price already moving the call's way in the facts, AND at least one different kind of fact behind it
  (news with the AI's reading, its sector moving the same way, futures money building the same way, a GIR DECIDES call, a policy story).
- Prefer the freshest, most direct cause. A sector story: name the most exposed F&O shares in the facts.
- THINK IN TRADES. Bad news for a share or its group + its price already turning down (off its high, falling in the last 15-30 min, its
  sector falling) = a PE call, NOT "avoid". Good news + the price rising = CE. A share at its high when bad news for its group lands is the
  BEST PE setup once it turns - say so, and say what the turn is (falling in the last 15 min, its sector falling).
- CAUTION: a share in an earlier call whose facts turned against it. AVOID only when there is no tradeable direction at all (mixed facts,
  no price confirmation either way). WATCH: a setup not confirmed yet - say exactly what would confirm it (e.g. "PE if it keeps falling
  with the sector in the next 15 min").
THE PLAYBOOK (tendencies a market expert knows - confirm each with the price before NOW):
- SEBI / exchange curbs on trading, margin funding (MTF), F&O, brokerage -> brokers, exchanges, depositories, registrars DOWN (ANGELONE,
  BSE, MCX, CDSL, MOTILALOFS, NUVAMA, KFINTECH, CAMS); a relaxation or a denial of curbs -> UP.
- A promoter / big holder selling (stake sale, OFS, block deal at a discount) -> DOWN short term; "no further sale", lock-in extended,
  pledge released -> UP. A buyback or promoter buying -> UP.
- Results: a beat with better guidance or margins -> UP; a miss, margin fall or guidance cut -> DOWN; already up 5%+ into results -> the
  reaction can be sell-the-news.
- USFDA warning letter / import alert / OAI -> that pharma share DOWN; an approval or a clean inspection -> UP.
- An order large against the company's size -> UP; a lost contract, a penalty, a raid, a probe, fraud, an auditor quitting -> DOWN.
- Crude up sharply -> BPCL / HINDPETRO / IOC, paints, INDIGO DOWN, ONGC / OIL UP. Rupee weaker -> IT and pharma exporters UP.
- RBI rate cut / easier liquidity -> banks, NBFCs, autos, realty UP; tighter rules on lending -> lenders DOWN.
- Government subsidy, PLI, a duty on imports competing with a sector -> that sector UP; an export ban or a duty on its exports -> DOWN.
- A whole sector moving together on no news: follow its strongest F&O shares, not the laggards; when a leading sector turns over (gives
  back 1%+ from its high with most of its shares falling) before 12:30, its falling F&O shares are PE candidates (GIR's own test).
- At most 3 calls; fewer is better. No call is better than a weak call. Do not repeat a call already made unless something new happened.
Answer with ONE JSON object only:
{"view": "one line on the market now (under 25 words)",
 "calls": [{"s": "SYMBOL", "act": "CE|PE|WATCH|AVOID|CAUTION", "urgency": "now|watch", "why": "under 30 words, the facts it rests on",
            "confirm": "for WATCH: what would confirm it, else empty"}]}"""
BRIEF = """You are the senior market analyst at an Indian F&O options trader's desk. Write his briefing from ONLY the facts given (never invent):
- the market and the sectors (which built up, which weakened, the rotation), - the stories that matter for which F&O shares and which way,
- what to watch at the open (the shares, and what would confirm them). Plain trading words, at most 12 short lines, no greeting.
Remember: overnight news mostly shows in the opening price - say 'watch' for those, not 'buy at the open'."""


QA = os.path.join(D, "data", "analyst_qa.json")
ANSWER = """You are the senior market analyst at an Indian F&O options trader's desk, and he is asking you directly. Answer like a market expert
talking to a trader: the direct answer FIRST (the share, CE or PE or wait, and why), then the facts it rests on, then what would change
your mind. Use the facts given (his system's live data and the share's own recent stories) for anything about TODAY - never invent news,
prices, levels or times. You may use your general knowledge of Indian markets (how a sector or an event usually moves shares) to explain,
but say "usually" / "in general" for that part. If the facts cannot answer it, say what is missing. At most 10 short lines, plain words."""


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


def fo_set():
    try:
        import seclive as SL
        return SL.fo_set()
    except Exception:
        return set()


def facts(n=None):
    """the picture, as short lines a person could read - each family separately, each guarded"""
    n = n or now(); F = {}; FO = fo_set(); since = n.timestamp() - 45 * 60
    try:
        ix = (_j(os.path.join(D, "dash_state.json"), {}).get("idx") or {})
        F["market"] = ["%s %s (%+.2f%%)" % (k, ix[k].get("last"), float(ix[k].get("chg") or 0)) for k in ("NIFTY", "BANKNIFTY") if k in ix]
    except Exception:
        pass
    try:
        S = _j(os.path.join(D, "data", "seclive.json"), {}); sec = S.get("sectors") or []
        def sl(x):
            rot = x.get("rot") or {}
            fo = [t for t in (x.get("top") or []) + (x.get("bot") or []) if t[2]]
            return "%s %+.2f%% (last 15 min %s, 30 min %s; %d up / %d down; F&O: %s)" % (x["name"], x["chg"], rot.get("15"), rot.get("30"), x.get("up", 0), x.get("dn", 0),
                   ", ".join("%s %+.1f%%" % (t[0], t[1]) for t in fo[:4]))
        F["sectors_best"] = [sl(x) for x in sec[:5]]; F["sectors_worst"] = [sl(x) for x in sec[-5:][::-1]]
        mv = sorted([x for x in sec if (x.get("rot") or {}).get("30") is not None], key=lambda x: -abs((x.get("rot") or {}).get("30") or 0))[:4]
        F["sectors_moving_now"] = ["%s %+.2f%% in the last 30 min" % (x["name"], x["rot"]["30"]) for x in mv]
    except Exception:
        pass
    try:
        q = _j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}
        W = {r["s"]: r for r in (_j(os.path.join(D, "data", "moverswhy.json"), {}).get("rows") or [])} if _j(os.path.join(D, "data", "moverswhy.json"), {}).get("day") == str(n.date()) else {}
        fut = _j(os.path.join(D, "data", "futlive.json"), {}).get("rows") or {}
        R = sorted([(s, float(v[0]), float(v[1])) for s, v in q.items() if (not FO or s in FO) and v and v[1] is not None], key=lambda r: -r[2])
        def ml(s, px, c):
            w = W.get(s); f = fut.get(s) or {}; tot = f.get("total") or {}
            return "%s ₹%.2f %+.2f%%%s%s" % (s, px, c, (" · futures: %s, OI %+.1f%%" % (f.get("bu") or "-", float(tot.get("pc") or 0))) if f else "",
                                             (" · why: %s (%s)" % (w.get("why"), w.get("sure"))) if w else "")
        F["gainers"] = [ml(*r) for r in R[:8]]; F["losers"] = [ml(*r) for r in R[-8:][::-1]]
    except Exception:
        pass
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        rows = c.execute("select sym, src, t_seen, h, side, kind, score, note from items where t_seen>? and score>=50 order by t_seen desc limit 30", (since,)).fetchall(); c.close()
        F["news"] = ["%s %s %s · %s · %s%s" % (dt.datetime.fromtimestamp(ts, IST).strftime("%H:%M"), s, {1: "▲", -1: "▼"}.get(sd, "·"), kd, (h or "")[:110],
                     (" · " + re.search(r"AI read: [A-Z]+", note).group(0)) if note and "AI read:" in note else "") for s, src, ts, h, sd, kd, sc, note in rows if not FO or s in FO][:20]
    except Exception:
        pass
    try:
        M = [x for x in (_j(os.path.join(D, "data", "macro.json"), {}).get("items") or []) if float(x.get("t") or 0) >= since and (x.get("score") or 0) >= 4]
        F["market_news"] = ["%s %s: %s" % (dt.datetime.fromtimestamp(float(x["t"]), IST).strftime("%H:%M"), x.get("src"), str(x.get("h"))[:120]) for x in M[-10:]]
    except Exception:
        pass
    try:
        P = _j(os.path.join(D, "data", "policymap.json"), {}).get("sent") or {}
        F["policy"] = ["%s %s %s: %s" % (dt.datetime.fromtimestamp(v["t"], IST).strftime("%H:%M"), k.split("|")[1], {1: "▲", -1: "▼"}.get(v.get("side"), "·"), v.get("h", "")[:100])
                       for k, v in P.items() if v.get("t", 0) >= since]
    except Exception:
        pass
    try:
        import girdecide as GD, alertaudit as AA
        OK, _ = GD.ok_types(); t15 = (n - dt.timedelta(minutes=15)).strftime("%H:%M:%S"); agg = {}
        for t, k, s, side, text in GD.alerts_today(str(n.date())):
            if str(t) >= t15:
                ty = AA.kind_of(text); dr = GD.side_of(side, text)
                if ty in OK and dr:
                    agg.setdefault((s, dr), set()).add(ty)
        F["good_alerts_last_15min"] = ["%s %s: %s" % (s, "▲" if dr > 0 else "▼", " + ".join(sorted(v))) for (s, dr), v in sorted(agg.items(), key=lambda kv: -len(kv[1]))[:12]]
        G = _j(GD.OUT, {})
        if G.get("day") == str(n.date()):
            F["gir_decides"] = ["%s %s %s (%s)" % (c_["t"], c_["s"], "CE" if c_["dir"] > 0 else "PE", " + ".join(a for a, b in c_["types"])) for c_ in (G.get("calls") or [])[-10:]]
    except Exception:
        pass
    try:
        ov = _j(os.path.join(D, "data", "overnight.json"), {})
        if ov.get("day") == str(n.date()):
            F["morning_list"] = ["tilt: " + " · ".join("%s %s" % (t["sector"], t["dir"]) for t in (ov.get("tilt") or [])[:6])] + \
                                ["watch: %s %s" % (w["s"], w["dir"]) for w in (ov.get("watch") or [])[:6]]
    except Exception:
        pass
    try:                                                        # the F&O shares of the sectors in focus (so a sector story names the right shares)
        S = _j(os.path.join(D, "data", "seclive.json"), {}).get("sectors") or []
        F["sector_fo_shares"] = ["%s: %s" % (x["name"], ", ".join((x.get("fos") or [])[:12])) for x in (S[:3] + S[-3:]) if x.get("fos")]
    except Exception:
        pass
    try:                                                        # the story memory: the last 3 days' AI-read stories of the shares in focus
        focus = []
        for k_ in ("gainers", "losers", "news"):
            for ln in F.get(k_) or []:
                m_ = re.search(r"\b([A-Z][A-Z0-9&\-]{1,14})\b", ln.split("·")[0] if k_ != "news" else ln[6:])
                if m_ and m_.group(1) not in focus and (not FO or m_.group(1) in FO):
                    focus.append(m_.group(1))
        F["story_memory"] = memory(focus[:10], n)
        try:                                                    # 📚 how these shares usually trade and react (patch 386)
            import knowledge
            kn = [ln for s_ in focus[:8] for ln in knowledge.brief(s_)]
            if kn:
                F["share_knowledge"] = kn[:24]
        except Exception:
            pass
    except Exception:
        pass
    try:                                                        # 📁 the ready files: tonight's BE READY list and today's level alerts (readyfile.py)
        R = _j(os.path.join(D, "data", "ready", "files.json"), {})
        if R.get("for") == str(n.date()):
            mk = R.get("market") or {}
            F["be_ready_list"] = ["%s %s: %s" % (x["s"], x["side"], x["why"]) for x in mk.get("be_ready") or []]
            if mk.get("outlook"):
                F["market_file_outlook"] = [mk["outlook"]]
        Hh = _j(os.path.join(D, "data", "ready", "hits.json"), {})
        if Hh.get("day") == str(n.date()):
            F["level_alerts_today"] = ["%s %s %s %s (%s) -> %s" % (h["t"], h["s"], h["kind"], h["level"], h["name"], h["side"]) for h in (Hh.get("hits") or [])[-10:]]
    except Exception:
        pass
    try:                                                        # 🏛 the six specialist desks' latest notes (deskteam.py)
        import deskteam
        dl = deskteam.lines()
        if dl:
            F["desk_notes"] = dl
    except Exception:
        pass
    st = _j(OUT, {})
    if st.get("day") == str(n.date()):
        F["your_calls_so_far"] = ["%s %s %s (%s): %s" % (c_["t"], c_["s"], c_["act"], c_["urgency"], c_["why"][:80]) for c_ in (st.get("calls") or [])[-8:]]
    return {k: v for k, v in F.items() if v}


def memory(syms, n=None, days=3):
    """the share's own story of the last days: its AI-read (or important) news, oldest first - so 'no further stake sale' is read against
    yesterday's 'promoter sells'"""
    n = n or now(); out = []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        for s in syms:
            R = c.execute("select t_pub, h, side, note from items where sym=? and t_pub>? and score>=50 order by t_pub", (s, n.timestamp() - days * 86400)).fetchall()
            R = [r for r in R if "AI read:" in (r[3] or "")] or R
            for tp, h, sd, note in R[-4:]:
                m_ = re.search(r"AI read: [A-Z]+", note or "")
                out.append("%s %s: %s%s" % (s, dt.datetime.fromtimestamp(tp, IST).strftime("%d %b %H:%M"), (h or "")[:100], (" · " + m_.group(0)) if m_ else ""))
        c.close()
    except Exception:
        pass
    return out[:30]


def ask(system, user, max_tokens=1500, model=None, effort=None):
    """one reading. The fast watcher (Haiku) streams; the senior expert (Fable 5.2) thinks (always on; `effort` sets how deep), with the
    server-side refusal fallback; an older SDK without those options gets the plain call. Any failure of the expert -> the watcher's model."""
    if ASK is not None:
        return ASK(system, user)
    import anthropic
    m = model or MODEL; msgs = [{"role": "user", "content": user}]
    cl = anthropic.Anthropic()
    if m == MODEL:
        with cl.messages.stream(model=m, max_tokens=max_tokens, system=system, messages=msgs) as s_:
            r = s_.get_final_message()
    else:
        kw = dict(model=m, max_tokens=16000, system=system, messages=msgs); c2 = cl.with_options(timeout=150)
        try:
            r = c2.beta.messages.create(betas=["server-side-fallback-2026-07-01"], fallbacks="default", output_config={"effort": effort or "medium"}, **kw)
        except TypeError:                                       # an SDK that does not know these options yet
            try:
                r = c2.messages.create(output_config={"effort": effort or "medium"}, **kw)
            except TypeError:
                r = c2.messages.create(**kw)
        if getattr(r, "stop_reason", "") == "refusal":
            raise RuntimeError("the expert model declined this reading")
    return "\n".join(b.text for b in r.content if getattr(b, "type", "") == "text")


def ask_expert(system, user, effort="medium", max_tokens=1500):
    """the senior expert; if it fails or the day's expert readings are spent, the watcher's model answers and the reply says so"""
    st = _j(OUT, {}); day = str(now().date())
    used = int(st.get("n_expert") or 0) if st.get("day") == day else 0
    if used < EXPERT_CAP:
        try:
            txt = ask(system, user, max_tokens, EXPERT, effort)
            st = _j(OUT, {})
            if st.get("day") == day:
                st["n_expert"] = int(st.get("n_expert") or 0) + 1; _save(st, OUT)
            return txt, EXPERT
        except Exception as ex:
            print("analyst expert: %s" % str(ex)[:120], flush=True)
    return ask(system, user, max_tokens), MODEL


def parse(txt):
    a, b = (txt or "").find("{"), (txt or "").rfind("}")
    try:
        j = json.loads(txt[a:b + 1]) if a >= 0 and b > a else {}
    except Exception:
        j = {}
    out = []
    FO = fo_set()
    for c in (j.get("calls") or [])[:3]:
        if not isinstance(c, dict):
            continue
        s = str(c.get("s") or "").upper().strip(); act = str(c.get("act") or "").upper().strip()
        if not s or (FO and s not in FO) or act not in ("CE", "PE", "WATCH", "AVOID", "CAUTION"):
            continue
        out.append({"s": s, "act": act, "urgency": "now" if str(c.get("urgency")).lower() == "now" and act in ("CE", "PE", "CAUTION") else "watch",
                    "why": str(c.get("why") or "")[:240], "confirm": str(c.get("confirm") or "")[:160]})
    return str(j.get("view") or "")[:200], out


def price(s):
    q = (_j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}).get(s)
    try:
        return float(q[0]), float(q[1])
    except Exception:
        return None, None


def text_of(c):
    mark = {"CE": "▲", "PE": "▼"}.get(c["act"], "•")
    head = "%s GIR ANALYST %s %s · %s · %s · %s" % ("🧠" if c["urgency"] == "now" else "📄", mark, c["s"], c["act"] if c["act"] not in ("CE", "PE") else c["act"] + " side",
                                                    "NOW" if c["urgency"] == "now" else "watch", c["t"])
    L = [head, ("₹%.2f (%+.2f%% today)" % (c["px"], c["chg"])) if c.get("px") else "", "why: " + c["why"], ("confirm: " + c["confirm"]) if c.get("confirm") else "",
         "the analyst is an AI reading GIR's facts - NOT proven yet; its record is on the page · the strike, size and stop are your call"]
    return "\n".join(x for x in L if x)


def send(t):
    if SEND is not None:
        return SEND(t)
    try:
        import engine2
        return engine2.tg_fo(t)
    except Exception as ex:
        print("analyst telegram: %s" % str(ex)[:80], flush=True); return False


def reading(dry=False, why_now="the minute", n_=None):
    n = n_ or now(); day = str(n.date())
    st = _j(OUT, {})
    if st.get("day") != day:
        st = {"day": day, "calls": [], "views": [], "n_model": 0}
    F = facts(n)
    user = "Now %s IST (%s). The facts:\n%s" % (n.strftime("%H:%M"), why_now, json.dumps(F, ensure_ascii=False, indent=0))
    if dry:
        print(user[:6000]); return st, []
    if st["n_model"] >= DAY_CAP:
        return st, []
    st["n_model"] += 1; _save(st, OUT)
    by = MODEL
    try:
        if why_now.startswith("just now"):                      # fresh news / policy / GIR DECIDES: straight to the senior expert
            txt, by = ask_expert(SYSTEM, user, "low")
            view, calls = parse(txt)
        else:                                                   # the minute: the fast watcher looks first ...
            view, calls = parse(ask(SYSTEM, user))
            recent_ = {(c["s"], c["act"]) for c in st["calls"] if n.timestamp() - c.get("ts", 0) < 30 * 60}
            prop = [c for c in calls if (c["s"], c["act"]) not in recent_]
            if prop:                                            # ... and nothing reaches Rama unless the senior expert decides it
                txt, by = ask_expert(SYSTEM, user + "\n\nThe junior watcher proposes: %s\nDecide as the senior analyst: keep, change or drop each - and add "
                                     "only what the facts clearly support." % json.dumps(prop, ensure_ascii=False), "low")
                view, calls = parse(txt)
    except Exception as ex:
        st["err"] = str(ex)[:120]; _save(st, OUT); return st, []
    st = dict(_j(OUT, {}), **{k: v for k, v in st.items() if k not in ("n_expert",)})
    st["views"] = (st.get("views") or [])[-30:] + [{"t": n.strftime("%H:%M"), "v": view, "why": why_now}]
    new = []
    recent = {(c["s"], c["act"]) for c in st["calls"] if n.timestamp() - c.get("ts", 0) < 30 * 60}
    for c in calls:
        if (c["s"], c["act"]) in recent:
            continue                                            # not the same call again within 30 min
        px, chg = price(c["s"])
        c.update({"t": n.strftime("%H:%M"), "ts": n.timestamp(), "px": px, "chg": chg, "why_now": why_now, "by": by})
        st["calls"].append(c); new.append(c)
    st["at"] = n.strftime("%H:%M:%S"); st["model"] = MODEL; st["expert"] = EXPERT
    _save(st, OUT)                                              # the page first
    for c in new:
        send(text_of(c))                                        # then Telegram
    return st, new


def triggers(last):
    """fresh events since `last` (epoch): an important AI-read news item, a policy story, a GIR DECIDES call -> a reason to read NOW"""
    ev = []
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "news.db"), uri=True, timeout=5)
        for s, h in c.execute("select sym, h from items where t_seen>? and score>=60 and note like '%AI read: %' and note not like '%AI read: NEUTRAL%'", (last,)):
            ev.append("news on %s: %s" % (s, (h or "")[:70]))
        c.close()
    except Exception:
        pass
    try:
        for k, v in (_j(os.path.join(D, "data", "policymap.json"), {}).get("sent") or {}).items():
            if v.get("t", 0) > last:
                ev.append("policy story on %s" % k.split("|")[1])
    except Exception:
        pass
    try:
        for h in _j(os.path.join(D, "data", "ready", "hits.json"), {}).get("hits") or []:
            if h.get("ts", 0) > last:
                ev.append("%s %s its file's level %s (%s)" % (h["s"], h["kind"], h["level"], h["name"]))
    except Exception:
        pass
    try:
        for c_ in _j(os.path.join(D, "data", "girdecide.json"), {}).get("calls") or []:
            if c_.get("ts", 0) > last:
                ev.append("GIR DECIDES %s" % c_["s"])
    except Exception:
        pass
    return ev


def score(n_=None):
    """15:12: each call's move its way to 15:10 -> the running record"""
    n = n_ or now(); st = _j(OUT, {})
    if st.get("day") != str(n.date()) or st.get("scored"):
        return None
    rows = []
    for c in st.get("calls") or []:
        px, _ = price(c["s"])
        if px and c.get("px") and c["act"] in ("CE", "PE"):
            dr = 1 if c["act"] == "CE" else -1
            c["res"] = round(100 * (px / c["px"] - 1) * dr, 2); rows.append({"s": c["s"], "act": c["act"], "u": c["urgency"], "t": c["t"], "res": c["res"]})
    st["scored"] = True; _save(st, OUT)
    lg = _j(LOG, {"days": {}}); lg["days"][st["day"]] = rows; _save(lg, LOG)
    return rows


def record():
    lg = _j(LOG, {"days": {}}); R = [r for v in lg.get("days", {}).values() for r in v]
    out = {}
    for k, f in (("all", lambda r: True), ("now", lambda r: r["u"] == "now")):
        X = [r["res"] for r in R if f(r)]
        if X:
            out[k] = {"n": len(X), "avg": round(sum(X) / len(X), 2), "its_way": round(100.0 * sum(1 for x in X if x > 0) / len(X))}
    return {"days": len(lg.get("days", {})), "rec": out}


def brief(n_=None, key=""):
    n = n_ or now(); F = facts(n)
    try:
        wd = _j(os.path.join(D, "data", "whydesk.json"), {})
        if wd:
            F["who_and_why"] = [json.dumps(wd, ensure_ascii=False)[:2500]]
    except Exception:
        pass
    txt, by_ = ask_expert(BRIEF, "Now %s IST. The facts:\n%s" % (n.strftime("%d %b %H:%M"), json.dumps(F, ensure_ascii=False, indent=0)), "high", 2000)
    txt = txt.strip()
    st = _j(OUT, {})
    if st.get("day") != str(n.date()):
        st.update({"day": str(n.date()), "calls": [], "views": [], "n_model": 0})
    st["briefs"] = (st.get("briefs") or [])[-3:] + [{"t": n.strftime("%d %b %H:%M"), "key": key, "text": txt[:2500]}]
    _save(st, OUT)
    send("📄 GIR ANALYST · BRIEFING %s\n%s" % (n.strftime("%H:%M"), txt[:3000]))
    return txt


def ask_q(q):
    """the page's question -> the queue (answered by the service within seconds)"""
    q = re.sub(r"\s+", " ", str(q or "")).strip()[:300]
    if len(q) < 3:
        return {"ok": False, "err": "empty"}
    st = _j(QA, {"qa": []}); day = str(now().date())
    if sum(1 for x in st["qa"] if x.get("day") == day) >= 80:
        return {"ok": False, "err": "80 questions today - the limit"}
    i = "%d" % int(time.time() * 1000)
    st["qa"] = st["qa"][-40:] + [{"id": i, "day": day, "t": now().strftime("%H:%M:%S"), "q": q}]
    _save(st, QA)
    return {"ok": True, "id": i}


def answer(q, n_=None):
    """one question with the live facts and the story memory of the shares it names"""
    n = n_ or now(); F = facts(n); FO = fo_set()
    names = {}
    try:
        import seclive as SL
        _, names = SL.universe()
    except Exception:
        pass
    words = set(re.findall(r"[A-Za-z][A-Za-z0-9&\-]+", q))
    syms = [s for s in (FO or []) if s in {w.upper() for w in words} or (names.get(s) and re.search(r"\b%s\b" % re.escape(names[s].split()[0]), q, re.I) and len(names[s].split()[0]) >= 4)]
    if syms:
        F["asked_about"] = []
        q_ = _j(os.path.join(D, "quotes_live.json"), {}).get("q") or {}; fut = _j(os.path.join(D, "data", "futlive.json"), {}).get("rows") or {}
        for s in syms[:5]:
            v = q_.get(s) or [None, None]; f = fut.get(s) or {}
            F["asked_about"].append("%s%s: ₹%s %s%% today · futures %s, OI %s%%" % (s, (" (" + names[s] + ")") if names.get(s) else "", v[0], v[1], f.get("bu") or "-", (f.get("total") or {}).get("pc")))
        F["their_stories"] = memory(syms[:5], n, days=5)
        try:
            import knowledge
            F["their_knowledge"] = [ln for s_ in syms[:3] for ln in knowledge.brief(s_, True)]
        except Exception:
            pass
        R = _j(os.path.join(D, "data", "ready", "files.json"), {}).get("shares") or {}
        F["their_ready_files"] = [json.dumps({k: R[s].get(k) for k in ("last5", "range20", "futures", "options", "results_next", "w")}, ensure_ascii=False)[:1800]
                                  for s in syms[:3] if s in R]
    txt, by = ask_expert(ANSWER, "Now %s IST. His question: %s\n\nThe facts:\n%s" % (n.strftime("%d %b %H:%M"), q, json.dumps(F, ensure_ascii=False, indent=0)), "medium", 1500)
    return txt.strip() + ("" if by == EXPERT else "\n(answered by the fast model - the senior expert was not available)")


def answer_pending():
    st = _j(QA, {"qa": []}); done = 0
    for x in st["qa"]:
        if "a" not in x:
            try:
                x["a"] = answer(x["q"])[:2500]
            except Exception as ex:
                x["a"] = "the analyst could not answer now (%s) - ask again in a minute" % str(ex)[:80]
            x["at"] = now().strftime("%H:%M:%S"); done += 1
            _save(st, QA)
    return done


def view():
    st = _j(OUT, {})
    for c in st.get("calls") or []:
        px, _ = price(c["s"])
        if px and c.get("px") and c["act"] in ("CE", "PE"):
            c["since"] = round(100 * (px / c["px"] - 1) * (1 if c["act"] == "CE" else -1), 2)
    st["record"] = record(); st["t"] = time.time()
    st["qa"] = [x for x in (_j(QA, {"qa": []}).get("qa") or []) if x.get("day") == str(now().date())][-6:]
    try:
        import deskteam
        st["desks"] = deskteam.view()
    except Exception:
        pass
    return st


def run():
    print("GIR ANALYST up: every %d s 09:15-15:30, at once on fresh news / policy / GIR DECIDES; briefings 07:05 and 19:45" % EVERY, flush=True)
    last_read = 0.0; last_ev = time.time(); last_desk = 0.0; done = set()
    while True:
        n = now(); hm = n.strftime("%H:%M"); day = str(n.date())
        try:
            if n.weekday() < 5:
                for at in ("07:05", "19:45"):
                    key = "%s %s" % (day, at)
                    if at <= hm < (dt.datetime.strptime(at, "%H:%M") + dt.timedelta(minutes=20)).strftime("%H:%M") and key not in done:
                        done.add(key)
                        if not any(b_.get("key") == key for b_ in (_j(OUT, {}).get("briefs") or [])):   # not again after a restart
                            brief(n, key)
                if "09:15" <= hm <= "15:30":
                    ev = triggers(last_ev); last_ev = time.time()
                    if ev and time.time() - last_read >= 20:
                        if time.time() - last_desk >= 60:       # the desks look at the fresh event first (in parallel, ~15 s)
                            try:
                                import deskteam
                                deskteam.tick(why="just now: " + "; ".join(ev[:4])); last_desk = time.time()
                            except Exception as ex:
                                print("desks: %s" % str(ex)[:120], flush=True)
                        reading(why_now="just now: " + "; ".join(ev[:4])); last_read = time.time()
                    else:
                        if time.time() - last_desk >= 180:      # the six desks every 3 minutes
                            try:
                                import deskteam
                                deskteam.tick(); last_desk = time.time()
                            except Exception as ex:
                                print("desks: %s" % str(ex)[:120], flush=True); last_desk = time.time()
                        if time.time() - last_read >= EVERY:
                            reading(); last_read = time.time()
                if hm >= "15:12" and (day, "score") not in done:
                    done.add((day, "score")); score(n)
        except Exception as ex:
            print("analyst: %s" % str(ex)[:160], flush=True)
        for _ in range(5):                                      # the questions from the page: answered within seconds, any hour
            try:
                answer_pending()
            except Exception as ex:
                print("analyst Q&A: %s" % str(ex)[:120], flush=True)
            time.sleep(2)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["run"]:
        run()
    elif a[:1] == ["brief"]:
        print(brief())
    elif a[:1] == ["ask"]:
        print(answer(" ".join(a[1:])))
    else:
        st, new = reading(dry="--dry" in a, why_now="by hand")
        if "--dry" not in a:
            print("view:", (st.get("views") or [{}])[-1].get("v"))
            for c in new:
                print(text_of(c)); print()
