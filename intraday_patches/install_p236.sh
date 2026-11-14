#!/bin/bash
# PATCH 236 - 👁 THE SPECIAL FORCE: the EVENT WATCH (patch 235) with a brain - install this one (it includes 235).
#   Two agents in their own service (gir-eventwatch): RESULTS (a week before / after results) and EVENTS (a week after a critical event, + shares
#   added by hand). For each share a FILE far deeper than the main engine looks: every option strike (today, 5 days, ₹ added), the pre-results
#   LEAK detector (one strike building for days, price flat), futures over 5 days, delivery, named deals and promoter / insider filings over
#   30 days, its own news (only headlines naming it), brokers' expectations, its past results reactions, peers' results this week - and a
#   🧠 AI analyst that reads the file: bias, how sure, who is positioned how, the levels, what would change its mind.
#   Triggers: futures money · writers moving · the delayed reaction · big hands · 🕵 LEAK · 🤫 QUIET BUILD -> ONE nee-naw alert a share
#   (never the ambulance), "an eye on it, not a buy call". 09:25 the list with the AI's one-liner per share.
#   Tested: 22 + 12 simulated cases. The AI: GIR's own reader (the daily $ cap), kept 30 min a share. Adds a new service only - safe any time.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d); mkdir -p $W/src; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S)
[ -f $D/opencall.py ] && [ -f $D/pushwho.py ] && [ -f $D/chains.py ] && [ -f $D/llmread.py ] || { echo "GIR's opencall / pushwho / chains / llmread not found"; exit 1; }
for f in eventwatch.py eventbrain.py; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ systemctl disable --now gir-eventwatch 2>/dev/null; rm -f $U/gir-eventwatch.service $D/eventwatch.py $D/eventbrain.py; systemctl daemon-reload; echo "❌ removed again - nothing else was touched"; exit 1; }
cat > $W/src/eventwatch.py <<'PY_EW'
#!/usr/bin/env python3
"""eventwatch.py - patch 235: 👁 EVENT WATCH - two agents for the shares around a big event (Rama, 13 Nov: "an agent only for the results shares,
one week before and one week after; some shares react days later - COROMANDEL, NAVINFLUOR; for me it is an alert and eye power that something
is brewing, someone trying to push or pull - not a buy").
  AGENT 1 · RESULTS   every F&O share with results in the next 7 days (the calendar) or filed in the last 7 days
  AGENT 2 · EVENTS    every F&O share named in a critical event of the last 7 days (🚨 CRITICAL GOVT "F&O shares to watch", ⚠️ SHOCK WATCH,
                      RESULTS REACTION, 🚨 THE REASON, regulator lines) - and shares Rama adds by hand (python3 eventwatch.py add SYM "why" [days])
Every minute in market hours, for those shares only, it looks for SOMETHING BREWING:
  FUTURES   fresh futures money ₹25 cr+ (long / short build-up, short covering, long unwinding) - again only when it doubles
  WRITERS   the option writers move: a wall BREAKING (writers buying back), calls / puts BOUGHT
  LATE MOVE after the event: the share 3%+ from the event-day close AND 1.5%+ today the same way - the delayed reaction
  BIG HANDS delivery 1.5x+ normal (bought and kept / sold) - once a day
-> 🚨 CRITICAL · 👁 EVENT WATCH ▲/▼ SYM (the nee-naw, GIR Box Picks): the event and how far away, what is brewing, who bets what, the move since
   the event - and "an eye on it, not a buy call". The ambulance stays for trade calls. 09:25 a list of the shares being watched.
   Each kind once an hour a share, at most 4 a share and 30 a day ring (the rest arrive without sound). Runs as its own service (gir-eventwatch).
  python3 eventwatch.py list        the shares being watched now (nothing sent)
  python3 eventwatch.py run         the service loop"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
WINDOW, CR_MIN, LATE_TOTAL, LATE_TODAY = 7, 25.0, 3.0, 1.5
GAP_S, PER_SHARE, DAY_CAP = 3600, 4, 30
STATE = os.path.join(BASE, "data", "eventwatch.json")
MANUAL = os.path.join(BASE, "data", "eventwatch_manual.json")
UP_BU, DN_BU = ("LONG BUILD-UP", "SHORT COVERING"), ("SHORT BUILD-UP", "LONG UNWINDING")
EV_RX = re.compile(r"CRITICAL GOVT|SHOCK WATCH|RESULTS REACTION|THE REASON|NEWS SHOCK|·\s*REG(?:ULATOR)?\b|CRITICAL RESULTS")
NOT_SYM = ("MARKET", "NIFTY", "BANKNIFTY", "SENSEX", "FINNIFTY", "")
_F = {}


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def _json(name, ttl):
    t, v = _F.get(name, (0.0, None))
    if v is not None and time.time() - t < ttl:
        return v
    try:
        v = json.load(open(os.path.join(BASE, name)))
    except Exception:
        v = {}
    _F[name] = (time.time(), v)
    return v


def fo_set():
    try:
        c = _ro("chains.db"); v = {r[0] for r in c.execute("select sym from fo_list")}; c.close(); return v
    except Exception:
        return set()


def _inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


# ---------------- the two agents' lists ----------------
def results_list(now, fo):
    out = {}
    d0, d1 = now.date() - dt.timedelta(days=WINDOW), now.date() + dt.timedelta(days=WINDOW)
    try:
        c = _ro("chains.db")
        for s, d in c.execute("select sym, min(d) from results_cal where d>=? and d<=? group by sym", (str(now.date()), str(d1))):
            if s in fo:
                dd = dt.date.fromisoformat(d)
                out[s] = {"agent": "RESULTS", "phase": "before", "date": d, "days": (dd - now.date()).days, "why": "results"}
        c.close()
    except Exception:
        pass
    try:
        c = _ro("filings.db")
        t0 = dt.datetime.combine(d0, dt.time(0), IST).timestamp()
        for s, te, v in c.execute("select sym, max(t_exch), verdict from filings where kind='RESULTS' and t_exch>=? group by sym", (t0,)):
            if s in fo:
                d = dt.datetime.fromtimestamp(te, IST).date()
                out[s] = {"agent": "RESULTS", "phase": "after", "date": str(d), "days": (now.date() - d).days, "t": te,
                          "why": "results%s" % ((" (GIR's reader: %s)" % v) if v and v not in ("XBRL NOT UP YET", "NUMBERS NOT READ") else "")}
        c.close()
    except Exception:
        pass
    return out


def events_list(now, fo):
    out = {}
    d0 = str(now.date() - dt.timedelta(days=WINDOW))
    try:
        c = _ro("tomorrow.db")
        rows = c.execute("select day, t, sym, text from alerts where day>=? order by day, t", (d0,)).fetchall()
        c.close()
    except Exception:
        rows = []
    for day, t, s, tx in rows:
        L = [x for x in (tx or "").split("\n") if x.strip()]
        if not L or not EV_RX.search(L[0]) or "EVENT WATCH" in L[0]:
            continue
        body = [x for x in L[1:] if not re.match(r"(🔴|🟠|📌|🔔|⚠ NOT|⚙️|🔎|⚖|🔕|touches:|F&O shares to watch|https?://)", x.strip())]
        why = re.sub(r"\s+", " ", body[0] if body else L[0])[:90]
        syms = [s] if s and s not in NOT_SYM else []
        m = next((re.search(r"F&O shares to watch:\s*(.+)", x) for x in L if "F&O shares to watch" in x), None)
        if m:
            syms += [x.strip() for x in m.group(1).split("·") if x.strip()]
        for x in syms:
            if x in fo:
                out[x] = {"agent": "EVENTS", "phase": "after", "date": day, "days": (now.date() - dt.date.fromisoformat(day)).days, "why": why}
    try:
        for x, v in (json.load(open(MANUAL)) or {}).items():
            if x in fo and str(v.get("until") or "9999") >= str(now.date()):
                out[x] = {"agent": "EVENTS", "phase": "after", "date": v.get("since") or str(now.date()), "days": (now.date() - dt.date.fromisoformat(v.get("since") or str(now.date()))).days,
                          "why": "added by Rama: %s" % (v.get("why") or "watch")}
    except Exception:
        pass
    return out


def watch_list(now=None):
    """{sym: {agent, phase (before / after), date, days, why}} - results first; an event on a results share adds to its why"""
    now = now or dt.datetime.now(IST)
    fo = fo_set()
    W = events_list(now, fo)
    for s, v in results_list(now, fo).items():
        if s in W and W[s]["why"] != v["why"]:
            v = dict(v, why=v["why"] + " · also: " + W[s]["why"])
        W[s] = v
    return W


# ---------------- what is brewing ----------------
def close_on(sym, d):
    """the share's close on day d (or the last day before it)"""
    try:
        c = _ro(os.path.join("data", "oistudy.db"))
        r = c.execute("select spot from day where sym=? and d<=? and spot>0 order by d desc limit 1", (sym, d)).fetchone()
        c.close()
        return r[0] if r else None
    except Exception:
        return None


def deliv():
    t, v = _F.get("_dl", (0.0, None))
    if v is None or time.time() - t > 1800:
        try:
            import instflow
            v = instflow.deliv_signals() or {}
        except Exception:
            v = {}
        _F["_dl"] = (time.time(), v)
    return v


def signals(sym, w, st):
    """-> [(kind, side, text, key)] for one watched share now"""
    out = []
    f = next((x for x in _json("dash_state.json", 10).get("fo_paths") or [] if x.get("s") == sym), None) or {}
    bu, cr = (f.get("bu") or "").replace("_", " ").upper(), abs(f.get("cr") or 0)
    if bu in UP_BU + DN_BU and cr >= CR_MIN:
        sd = 1 if bu in UP_BU else -1
        last = (st.get("fut") or {}).get(sym) or {}
        if last.get("bu") != bu or cr >= 2 * (last.get("cr") or 0):
            word = {"LONG BUILD-UP": "fresh futures LONGS - someone betting on a RISE", "SHORT BUILD-UP": "fresh futures SHORTS - someone betting on a FALL",
                    "SHORT COVERING": "shorts buying back - those who bet on a fall are leaving", "LONG UNWINDING": "longs selling out - those who bet on a rise are leaving"}[bu]
            out.append(("FUTURES", sd, "%s: ₹%.0f cr%s" % (word, cr, (" · futures OI %+.1f%%" % f["oi"]) if f.get("oi") is not None else ""), ("FUT", bu, round(cr))))
            st.setdefault("fut", {})[sym] = {"bu": bu, "cr": cr}
    wl = ((((_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(sym) or {}).get("lines") or {}).get("walls") or "")
    for rx, sd, word in ((r"roof at ([\d.]+) BREAKING", 1, "call writers buying back at %s - the ceiling is breaking"),
                         (r"floor at ([\d.]+) BREAKING", -1, "put writers buying back at %s - the floor is breaking"),
                         (r"calls ([\d.]+) was BOUGHT", 1, "calls at %s being BOUGHT - a bet on a RISE"),
                         (r"puts ([\d.]+) was BOUGHT", -1, "puts at %s being BOUGHT - a bet on a FALL")):
        m = re.search(rx, wl)
        if m:
            out.append(("WRITERS", sd, word % m.group(1), ("WR", rx[:6], m.group(1))))
    q = ((_json("quotes_live.json", 3).get("q") or {}).get(sym)) or []
    px, today = (q[0] if q else f.get("ltp")), (q[1] if len(q) > 1 else f.get("chg"))
    if w["phase"] == "after" and px and today is not None and w["days"] >= 1:
        ref = close_on(sym, w["date"])
        if ref:
            tot = (px / ref - 1) * 100
            if abs(tot) >= LATE_TOTAL and abs(today) >= LATE_TODAY and tot * today > 0:
                sd = 1 if tot > 0 else -1
                out.append(("LATE MOVE", sd, "the delayed reaction: %+.1f%% since the event-day close (₹%s -> ₹%s), %+.1f%% today" % (tot, _inr(ref), _inr(px), today), ("LATE", sd)))
    dl = deliv()
    for key, sd in (("acc", 1), ("dist", -1)):
        x = next((r for r in dl.get(key) or [] if r.get("s") == sym), None)
        if x:
            out.append(("BIG HANDS", sd, "big hands %s on %s: delivery %.1fx normal (₹%.0f cr extra) - FII or DII, not named" % (
                "bought and KEPT the shares" if sd > 0 else "SOLD", (dl.get("day") or "")[5:], x.get("x") or 0, x.get("extra") or 0), ("DL", dl.get("day"), sd)))
    return out


def _when(w):
    if w["phase"] == "before":
        return "results %s" % ("TODAY" if w["days"] == 0 else "TOMORROW" if w["days"] == 1 else "in %d days (%s)" % (w["days"], w["date"][5:]))
    return "%s: %s" % ("today" if w["days"] == 0 else "%d day%s after" % (w["days"], "" if w["days"] == 1 else "s"), w["why"][:80])


def _file(sym, w):
    """patch 236: the special force's file on the share (eventbrain.dossier), kept 5 minutes"""
    k = "_file_" + sym
    t, v = _F.get(k, (0.0, None))
    if v is not None and time.time() - t < 300:
        return v
    try:
        import eventbrain
        v = eventbrain.dossier(sym, w)
    except Exception:
        v = {}
    _F[k] = (time.time(), v)
    return v


def _ai(sym, D):
    try:
        import eventbrain
        return eventbrain.ai_read(sym, D)
    except Exception:
        return None


def text(sym, w, sigs, now, D=None):
    """one alert for one share: every new thing brewing in it + the file's key facts + the AI's read (patch 236)"""
    ups, dns = sum(1 for x in sigs if x[1] > 0), sum(1 for x in sigs if x[1] < 0)
    ar = "▲" if ups and not dns else "▼" if dns and not ups else "▲▼"
    L = ["🚨 CRITICAL · 👁 EVENT WATCH %s %s · %s" % (ar, sym, now.strftime("%H:%M")),
         "%s · %s" % ("RESULTS WATCH" if w["agent"] == "RESULTS" else "EVENT WATCH", _when(w))]
    L += ["brewing (%s): %s" % (k.lower(), line) for k, sd, line, _k in sigs]
    if ups and dns:
        L.append("⚠ mixed - some bet on a rise, some on a fall: wait for one side to win")
    elif not ups and not dns:
        L.append("the side is not clear yet - watch which way it breaks")
    o = (D or {}).get("options, every strike")
    if o:
        L.append("options: call OI %s today / %s in 5 days · put OI %s / %s · PCR %s%s" % tuple(
            [("%+.0f%%" % o[k]) if o.get(k) is not None else "?" for k in ("call OI today %", "call OI 5 days %", "put OI today %", "put OI 5 days %")] + [o.get("PCR"),
             (" · " + o["biggest additions today"][0]) if o.get("biggest additions today") else ""]))
    if D:
        try:
            import eventbrain
            L.append(eventbrain.ai_line(_ai(sym, D)))
        except Exception:
            pass
    try:
        import pushwho
        p = pushwho.read(sym)
        up = [x["k"] for x in p["rows"] if x["on"] and x["side"] > 0]; dn = [x["k"] for x in p["rows"] if x["on"] and x["side"] < 0]
        L.append("who is pushing: ▲ %s · ▼ %s" % (", ".join(up) or "none", ", ".join(dn) or "none"))
    except Exception:
        pass
    L.append("👁 an eye on it, not a buy call - GIR rings the ambulance only when a trade sets up%s" % (
        " · before results options are expensive (they fall after the numbers)" if w["phase"] == "before" else ""))
    return "\n".join(L)


def summary(W, now):
    if not W:
        return None
    rows = sorted(W.items(), key=lambda kv: (kv[1]["phase"] != "before", kv[1]["days"]))
    L = ["🚨 CRITICAL · 👁 EVENT WATCH · %s · %d F&O shares watched today (a week before / after their event)" % (now.strftime("%H:%M"), len(W))]
    for s, w in rows[:30]:
        r = _ai(s, _file(s, w)) if _file(s, w) else None
        L.append("%s %s - %s%s" % ("📅" if w["phase"] == "before" else "👁", s, _when(w), (" · 🧠 %s %d%%" % (r["bias"], r["confidence"])) if r else ""))
    L.append("GIR rings when money starts building in one of them - an eye on it, not a buy call")
    return "\n".join(L)


# ---------------- the loop ----------------
def _load(day):
    try:
        st = json.load(open(STATE))
        if st.get("day") == day:
            return st
    except Exception:
        pass
    return {"day": day, "said": {}, "per": {}, "rang": 0, "fut": {}, "summary": False}


def _save(st):
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        json.dump(st, open(STATE + ".tmp", "w"), default=str); os.replace(STATE + ".tmp", STATE)
    except Exception:
        pass


def tick(now=None, send=None, W=None):
    """one look -> [texts sent]"""
    now = now or dt.datetime.now(IST)
    hm = now.strftime("%H:%M")
    if now.weekday() > 4 or not ("09:20" <= hm <= "15:25"):
        return []
    st = _load(str(now.date()))
    W = W if W is not None else watch_list(now)
    out = []
    if not st.get("summary") and hm >= "09:25":
        st["summary"] = True
        s_ = summary(W, now)
        if s_:
            out.append(s_)
    t = now.timestamp()
    for sym, w in W.items():
        new_ = []
        D = _file(sym, w)
        try:
            import eventbrain
            deep = eventbrain.deep_signals(sym, w, D) if D else []
        except Exception:
            deep = []
        for sig in signals(sym, w, st) + deep:
            key = "%s|%s" % (sym, json.dumps(sig[3]))
            kk = "%s|%s" % (sym, sig[0])
            if key in st["said"] or t - (st["said"].get(kk) or 0) < GAP_S:
                continue
            st["said"][key] = t; st["said"][kk] = t
            new_.append(sig)
        if new_:
            st["per"][sym] = st["per"].get(sym, 0) + 1
            tx = text(sym, w, new_, now, D)
            if st["rang"] >= DAY_CAP or st["per"][sym] > PER_SHARE:
                tx = tx.replace("🚨 CRITICAL · ", "", 1)          # the day's / the share's rings spent - it arrives without sound
            else:
                st["rang"] += 1
            out.append(tx)
    _save(st)
    snd = send
    if snd is None:
        import opencall
        snd = opencall.send_tg
    for x in out:
        try:
            snd(x)
        except Exception as ex:
            print("send: %s" % str(ex)[:80])
    return out


def add(sym, why, days=7):
    try:
        m = json.load(open(MANUAL))
    except Exception:
        m = {}
    now = dt.datetime.now(IST)
    m[sym.upper()] = {"why": why, "since": str(now.date()), "until": str(now.date() + dt.timedelta(days=int(days)))}
    os.makedirs(os.path.dirname(MANUAL), exist_ok=True)
    json.dump(m, open(MANUAL, "w"), indent=1)
    return m[sym.upper()]


if __name__ == "__main__":
    a = sys.argv[1:] or ["list"]
    if a[0] == "list":
        W = watch_list()
        print("👁 EVENT WATCH - %d F&O shares being watched" % len(W))
        for s, w in sorted(W.items(), key=lambda kv: (kv[1]["phase"] != "before", kv[1]["days"])):
            print("  %-12s %-8s %s" % (s, w["agent"], _when(w)))
    elif a[0] == "add" and len(a) >= 2:
        print("added:", add(a[1], a[2] if len(a) > 2 else "watch", a[3] if len(a) > 3 else 7))
    elif a[0] == "remove" and len(a) >= 2:
        try:
            m = json.load(open(MANUAL)); m.pop(a[1].upper(), None); json.dump(m, open(MANUAL, "w"), indent=1); print("removed", a[1].upper())
        except Exception as ex:
            print("not removed:", ex)
    elif a[0] == "run":
        print("eventwatch: the loop starts", flush=True)
        while True:
            try:
                n = tick()
                if n:
                    print("%s · %d alert(s)" % (dt.datetime.now(IST).strftime("%H:%M"), len(n)), flush=True)
            except Exception as ex:
                print("tick: %s" % str(ex)[:120], flush=True)
            time.sleep(60)
PY_EW
cat > $W/src/eventbrain.py <<'PY_EB'
#!/usr/bin/env python3
"""eventbrain.py - patch 236: THE SPECIAL FORCE'S BRAIN (Rama, 13 Nov: "dedicated special forces - high intelligence and power; if they read the same
as GIR it is useless"). For each share the EVENT WATCH follows (a week before / after results or a critical event) it builds a full FILE from
everything GIR records - far deeper than the main engine looks at 218 shares - and an AI analyst reads the file:
  options    every strike (chains.db, several readings a day + 20 days): call vs put OI today and over 5 days, PCR, the strikes where money was
             added today and its value in ₹ (OI added x premium)
  the leak   a single out-of-the-money strike building for days while the price stays flat (chains.results_tell - the pre-results footprint)
  futures    today's build-up AND the 5-day futures OI vs price (OI up, price flat = a big position built quietly)
  big hands  delivery today · named FII / DII deals over 30 days · promoter / insider (SAST, pledge) filings over 30 days
  news       the share's own news over 72 h (only headlines that name it) · brokers' expectations
  history    how it moved after its last results: day 1, day 3 · peers in its sector that reported this week and how they moved
  🧠 the AI  reads the file and answers: bias UP / DOWN / MIXED / NONE, how sure, who is positioned how, the levels, what would change its mind
Two deep triggers for the EVENT WATCH: 🕵 LEAK (the single-strike build, score 50+) and 🤫 QUIET BUILD (futures OI +15% in 5 days, price within 2%).
The AI uses GIR's reader (llmread: the daily $ cap) - a few cents a share a day; its answer is kept 30 minutes.
  python3 eventbrain.py SYM      the full file + the AI read for one share (nothing sent)"""
import os, re, sys, json, time, glob, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
LEAK_MIN, QUIET_OI, QUIET_PX, AI_TTL = 50, 15.0, 2.0, 1800
_AI = {}
_F = {}


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def _json(name, ttl=10):
    t, v = _F.get(name, (0.0, None))
    if v is not None and time.time() - t < ttl:
        return v
    try:
        v = json.load(open(os.path.join(BASE, name)))
    except Exception:
        v = {}
    _F[name] = (time.time(), v)
    return v


def _cr(x):
    return round(x / 1e7, 1)


def options(sym):
    """call vs put OI today / 5 days, PCR, today's biggest additions in ₹ - from chains.db (every strike)"""
    try:
        import chains
        g = chains.general_flow(sym)
    except Exception:
        g = None
    if not g:
        return None
    lot = 1
    try:
        c = _ro("chains.db"); r = c.execute("select lot from fo_list where sym=?", (sym,)).fetchone(); c.close(); lot = (r[0] or 1) if r else 1
    except Exception:
        pass
    top = []
    for x in g.get("top") or []:
        top.append("%s %g added %s (₹%s cr of premium)" % (x["kind"], x["strike"], "{:,}".format(x["oi_add"]), _cr(x["oi_add"] * (x.get("ltp") or 0))))
    return {"call OI today %": g.get("ce_d1"), "put OI today %": g.get("pe_d1"), "call OI 5 days %": g.get("ce_d5"), "put OI 5 days %": g.get("pe_d5"),
            "PCR": g.get("pcr"), "price 5 days %": g.get("px_d5"), "biggest additions today": top, "days of history": g.get("days")}


def leak(sym):
    try:
        import chains
        r = chains.results_tell(sym)
    except Exception:
        return None
    return r if r and r.get("score") else None


def futures(sym):
    f = next((x for x in _json("dash_state.json").get("fo_paths") or [] if x.get("s") == sym), None) or {}
    out = {"today": ("%s ₹%.0f cr · futures OI %s" % ((f.get("bu") or "").replace("_", " ").lower(), abs(f.get("cr") or 0),
                                                     ("%+.1f%%" % f["oi"]) if f.get("oi") is not None else "?")) if f.get("bu") else "no build-up today"}
    try:
        c = _ro(os.path.join("data", "oistudy.db"))
        rows = c.execute("select d, spot, foi from day where sym=? and spot>0 order by d desc limit 6", (sym,)).fetchall()
        c.close()
        if len(rows) >= 6 and rows[0][2] and rows[5][2]:
            out["5 days"] = {"futures OI %": round((rows[0][2] / rows[5][2] - 1) * 100, 1), "price %": round((rows[0][1] / rows[5][1] - 1) * 100, 1)}
    except Exception:
        pass
    return out


def big_hands(sym):
    out = {}
    try:
        import instflow
        dl = instflow.deliv_signals() or {}
        for key, w in (("acc", "bought and KEPT"), ("dist", "SOLD")):
            x = next((r for r in dl.get(key) or [] if r.get("s") == sym), None)
            if x:
                out["delivery %s" % dl.get("day")] = "big hands %s: %.1fx normal (₹%.0f cr extra)" % (w, x.get("x") or 0, x.get("extra") or 0)
    except Exception:
        pass
    deals = []
    for f in sorted(glob.glob(os.path.join(BASE, "data", "instdeals", "2*.json")))[-30:]:
        try:
            for r in json.load(open(f)).get("rows") or []:
                if r.get("s") == sym:
                    deals.append("%s %s %s ₹%s cr (%s)" % (os.path.basename(f)[5:10], r.get("who", "")[:30], r.get("side"), _cr(r.get("q", 0) * r.get("p", 0)), r.get("cls", "")))
        except Exception:
            pass
    if deals:
        out["named deals, 30 days"] = deals[-8:]
    try:
        c = _ro("filings.db")
        rows = c.execute("select t_exch, subject, detail from filings where sym=? and t_exch>? order by t_exch desc limit 40", (sym, time.time() - 30 * 86400)).fetchall()
        c.close()
        ins = ["%s %s" % (dt.datetime.fromtimestamp(t, IST).strftime("%d %b"), re.sub(r"\s+", " ", (d or s or ""))[:110]) for t, s, d in rows
               if re.search(r"promoter|\bsast\b|insider|pledge|encumbrance|acquisition of shares|disposal", "%s %s" % (s or "", d or ""), re.I)]
        if ins:
            out["promoter / insider filings, 30 days"] = ins[:5]
    except Exception:
        pass
    return out


def news(sym):
    try:
        import newsroom, newsalert
        its = newsroom.items_for(sym, 72)
        out = []
        for it in its:
            if newsalert.about_it(sym, it.get("h") or "") is True:
                out.append("%s · %s" % (it.get("t"), (it.get("h") or "")[:120]))
            if len(out) >= 5:
                break
        return out
    except Exception:
        return []


def results_ctx(sym, w):
    out = {}
    try:
        import resultsdesk
        if w.get("phase") == "before" and w.get("agent") == "RESULTS":
            r = resultsdesk.one(sym, w["date"])
            out = {"brokers expect": r.get("exp") or "no broker number", "into the results": "%s week · %s month" % (r.get("wk"), r.get("mo")),
                   "options price in ±%%": r.get("em"), "IV percentile": r.get("ivp"), "OI battle": (r.get("battle") or {}).get("short")}
        h = resultsdesk.history(sym)
        if h:
            out["past results (verdict, vs brokers, next day %, 3 days %)"] = ["%s %s %s %s %s" % (x.get("q"), x.get("verdict"), x.get("word") or "", x.get("d1"), x.get("d3")) for x in h]
    except Exception:
        pass
    return out


def peers(sym):
    try:
        import sectors
        sec = next((n for n, s in sectors.load().items() if sym in s), None)
        if not sec:
            return []
        grp = [x for x in sectors.load()[sec] if x != sym]
        c = _ro("filings.db")
        rows = c.execute("select sym, max(t_exch), verdict from filings where kind='RESULTS' and t_exch>? and sym in (%s) group by sym" % ",".join("?" * len(grp)),
                         [time.time() - 10 * 86400] + grp).fetchall()
        c.close()
        q = _json("quotes_live.json", 3).get("q") or {}
        return ["%s results %s (%s) · today %s" % (s, dt.datetime.fromtimestamp(t, IST).strftime("%d %b"), v or "-", ("%+.1f%%" % q[s][1]) if q.get(s) else "?") for s, t, v in rows][:5]
    except Exception:
        return []


def dossier(sym, w):
    q = (_json("quotes_live.json", 3).get("q") or {}).get(sym) or []
    D = {"share": sym, "event": {"agent": w.get("agent"), "phase": w.get("phase"), "date": w.get("date"), "days": w.get("days"), "what": w.get("why")},
         "price now": q[0] if q else None, "today %": q[1] if len(q) > 1 else None}
    try:
        wl = ((((_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(sym) or {}).get("lines") or {}))
        D["option writers (the desk)"] = {"walls": (wl.get("walls") or "")[:240], "strikes": (wl.get("strikes") or "")[:200]}
    except Exception:
        pass
    for k, fn in (("options, every strike", lambda: options(sym)), ("the leak detector", lambda: leak(sym)), ("futures", lambda: futures(sym)),
                  ("big hands", lambda: big_hands(sym)), ("news about it, 72 h", lambda: news(sym)), ("results", lambda: results_ctx(sym, w)),
                  ("sector peers' results this week", lambda: peers(sym))):
        try:
            v = fn()
            if v:
                D[k] = v
        except Exception:
            pass
    return D


PROMPT = """You are a careful Indian F&O market analyst. Below is everything recorded about the NSE share {sym} around an event ({what}).
Judge who is positioned how BEFORE the market shows it. Use ONLY the facts in the file - never invent a number.
Guidance: call OI rising with the price flat or falling usually means call WRITERS capping it (bearish); put OI rising usually means put writers
building support (bullish); futures OI rising with the price up = new longs, with the price down = new shorts; a single far strike building for days
while the price is flat can be informed money. Before results, options are expensive - say so if relevant. If the facts disagree, say MIXED.
Answer ONLY this JSON:
{{"bias": "UP|DOWN|MIXED|NONE", "confidence": 0-100, "who": "who is positioned how, one sentence", "why": ["fact", "fact", "fact"],
"levels": "the price levels that matter", "changes_mind": "what would flip this read", "plain": "two plain sentences for a trader who is not an expert"}}
THE FILE:
{file}"""


def ai_read(sym, D, force=False):
    """-> {bias, confidence, who, why, levels, changes_mind, plain, model} or None (no AI / budget spent)"""
    k = sym
    if not force and k in _AI and time.time() - _AI[k][0] < AI_TTL:
        return _AI[k][1]
    try:
        import llmread
        text, model = llmread.ask(PROMPT.format(sym=sym, what=(D.get("event") or {}).get("what"), file=json.dumps(D, ensure_ascii=False, default=str)[:9000]), max_tokens=700)
        r = llmread._json(text)
        r["model"] = model
        r["bias"] = str(r.get("bias") or "NONE").upper()
        r["confidence"] = int(r.get("confidence") or 0)
    except Exception as ex:
        r = None
        _F["ai_err"] = (time.time(), str(ex)[:120])
    _AI[k] = (time.time(), r)
    return r


def ai_line(r):
    if not r:
        return "🧠 AI read: not available now (GIR's daily AI budget or the API) - the facts above still stand"
    return "🧠 AI read: %s · %d%% sure - %s" % (r["bias"], r["confidence"], (r.get("plain") or r.get("who") or "")[:220])


def deep_signals(sym, w, D):
    """the special force's own triggers -> [(kind, side, text, key)]"""
    out = []
    lk = D.get("the leak detector")
    if lk and (lk.get("score") or 0) >= LEAK_MIN and w.get("phase") == "before":
        sd = -1 if lk.get("kind") == "PE" else 1
        out.append(("LEAK", sd, "🕵 %s - %s (score %d)" % (lk.get("side"), lk.get("note"), lk["score"]), ("LEAK", lk.get("key"))))
    fu = (D.get("futures") or {}).get("5 days")
    if fu and fu.get("futures OI %") is not None and fu["futures OI %"] >= QUIET_OI and abs(fu.get("price %") or 0) <= QUIET_PX:
        out.append(("QUIET BUILD", 0, "🤫 futures OI %+.1f%% in 5 days while the price moved only %+.1f%% - a big position built quietly, its side not shown yet" % (
            fu["futures OI %"], fu.get("price %") or 0), ("QB", round(fu["futures OI %"]))))
    return out


if __name__ == "__main__":
    s = (sys.argv[1] if len(sys.argv) > 1 else "").upper()
    if not s:
        print(__doc__.split("\n\n")[-1]); sys.exit(1)
    try:
        import eventwatch
        w = eventwatch.watch_list().get(s) or {"agent": "MANUAL", "phase": "after", "date": str(dt.date.today()), "days": 0, "why": "asked for by hand"}
    except Exception:
        w = {"agent": "MANUAL", "phase": "after", "date": str(dt.date.today()), "days": 0, "why": "asked for by hand"}
    D = dossier(s, w)
    print(json.dumps(D, indent=1, ensure_ascii=False, default=str))
    r = ai_read(s, D, force=True)
    print("\n" + ai_line(r))
    if r:
        for k in ("who", "why", "levels", "changes_mind"):
            print("   %s: %s" % (k, r.get(k)))
        print("   (model: %s)" % r.get("model"))
    elif _F.get("ai_err"):
        print("   (AI not used: %s)" % _F["ai_err"][1])
PY_EB
cat > $W/p235test.py <<'PY_T1'
#!/usr/bin/env python3
"""p235test.py - 👁 EVENT WATCH simulated on 13-14 Nov scenarios (made-up files, temp folder, nothing sent).
python3 p235test.py SRCDIR [SERVERDIR]   (SRCDIR: eventwatch.py · SERVERDIR: the real alertword / tglanes / ringgov, when given)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); SRV = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else None
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "eventwatch.py"), T)
if SRV:
    for f in ("alertword.py", "tglanes.py", "ringgov.py", "p1vote.py"):
        if os.path.exists(os.path.join(SRV, f)):
            shutil.copy(os.path.join(SRV, f), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime(2026, 11, 14, 11, 0, tzinfo=IST)               # a Saturday? no - 14 Nov 2026 is a Saturday; use Monday 16 Nov
NOW = dt.datetime(2026, 11, 16, 11, 0, tzinfo=IST)
D = lambda n: str((NOW - dt.timedelta(days=n)).date())
FO = ["COROMANDEL", "NAVINFLUOR", "EICHERMOT", "GRASIM", "SBIN", "OLDNEWS", "POLICYBZR", "MANUALSH"]
c = sqlite3.connect(os.path.join(T, "chains.db"))
c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values (?, 1)", [(s,) for s in FO])
c.execute("create table results_cal(sym text, d text)")
c.executemany("insert into results_cal values (?, ?)", [("EICHERMOT", str((NOW + dt.timedelta(days=2)).date())), ("GRASIM", str((NOW + dt.timedelta(days=1)).date())),
                                                        ("NOTFO", str((NOW + dt.timedelta(days=1)).date()))])
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "filings.db")); c.execute("create table filings(sym text, t_exch real, verdict text, kind text)")
c.execute("insert into filings values ('NAVINFLUOR', ?, 'BEAT', 'RESULTS')", (dt.datetime.fromisoformat(D(5) + "T16:10:00+05:30").timestamp(),)); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.executemany("insert into alerts values (?, ?, '', ?, '', ?)", [
    (D(5), "19:33:00", "MARKET", "🚨 CRITICAL GOVT · PIB · 19:33\nCabinet approves Rs 37,000 crore nutrient based subsidy for rabi\ntouches: FERTILISER\nF&O shares to watch: COROMANDEL · CHAMBLFERT"),
    (D(9), "10:00:00", "OLDNEWS", "⚠️ SHOCK WATCH · ▼ OLDNEWS · REGULATOR · old order"),
    (D(1), "19:47:00", "POLICYBZR", "📰 NEWS ▼ POLICYBZR · REG · medianama.com 19:32\n🟠 SOMETHING IS HAPPENING — not a trade by itself\nIRDAI's insurance overhaul pushes PB Fintech to non-insurance services")])
c.commit(); c.close()
o = sqlite3.connect(os.path.join(T, "data", "oistudy.db")); o.execute("create table day(d text, sym text, spot real)")
o.executemany("insert into day values (?, ?, ?)", [(D(5), "COROMANDEL", 1890.0), (D(5), "NAVINFLUOR", 4100.0), (D(4), "NAVINFLUOR", 4120.0)]); o.commit(); o.close()
json.dump({"fo_paths": [
    {"s": "COROMANDEL", "chg": 2.1, "bu": "LONG BUILD-UP", "cr": 60.0, "oi": 6.2},          # 5 days after the subsidy: +4.3% since, +2.1% today, fresh longs
    {"s": "NAVINFLUOR", "chg": -1.9, "bu": "SHORT BUILD-UP", "cr": 40.0, "oi": 5.0},        # 5 days after results: -3.4% since, -1.9% today, fresh shorts
    {"s": "EICHERMOT", "chg": 0.6, "bu": "LONG BUILD-UP", "cr": 80.0, "oi": 4.1},           # results in 2 days: money building
    {"s": "GRASIM", "chg": 0.1, "bu": "", "cr": 2.0},                                        # results tomorrow: quiet
    {"s": "SBIN", "chg": 1.0, "bu": "LONG BUILD-UP", "cr": 300.0},                          # no event: not this agent's job
    {"s": "OLDNEWS", "chg": -2.0, "bu": "SHORT BUILD-UP", "cr": 90.0},                     # its event was 9 days ago: outside the week
    {"s": "POLICYBZR", "chg": 0.2, "bu": "", "cr": 1.0}, {"s": "MANUALSH", "chg": 0.0, "bu": "", "cr": 0}]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"t": 0, "q": {"COROMANDEL": [1971.0, 2.1], "NAVINFLUOR": [3960.0, -1.9], "EICHERMOT": [7050.0, 0.6], "GRASIM": [2700.0, 0.1], "SBIN": [800.0, 1.0],
                         "OLDNEWS": [100.0, -2.0], "POLICYBZR": [1050.0, 0.2]}}, open(os.path.join(T, "quotes_live.json"), "w"))
json.dump({"shares": {"EICHERMOT": {"lines": {"walls": "calls 7100 was BOUGHT (OI 1 L → 2 L, premium up) — a bet on UP, not a roof"}}}}, open(os.path.join(T, "data", "desk.json"), "w"))
open(os.path.join(T, "instflow.py"), "w").write("def deliv_signals(min_x=1.5):\n    return {'day': '%s', 'acc': [{'s': 'COROMANDEL', 'x': 2.4, 'extra': 31.0}], 'dist': []}\n" % D(1))
open(os.path.join(T, "pushwho.py"), "w").write("def read(s):\n    return {'rows': [{'k': 'FUTURES', 'on': True, 'side': 1}]}\n")
sys.path.insert(0, T); os.chdir(T)
import eventwatch as E
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))
print("1 · who is watched (a week before / after)")
W = E.watch_list(NOW)
for s, w in sorted(W.items()):
    print("     %-11s %-7s %s" % (s, w["agent"], E._when(w)))
chk("RESULTS agent: EICHERMOT (in 2 days), GRASIM (tomorrow) before · NAVINFLUOR (5 days after) after", W.get("EICHERMOT", {}).get("phase") == "before" and W.get("GRASIM", {}).get("days") == 1 and W.get("NAVINFLUOR", {}).get("phase") == "after", W)
chk("EVENTS agent: COROMANDEL from the Cabinet subsidy's 'F&O shares to watch' (5 days after) · POLICYBZR from the IRDAI news", W.get("COROMANDEL", {}).get("agent") == "EVENTS" and "subsidy" in W["COROMANDEL"]["why"] and "POLICYBZR" in W, W.get("COROMANDEL"))
chk("not watched: SBIN (no event), OLDNEWS (9 days ago), NOTFO (not F&O), CHAMBLFERT (not on the F&O list here)", not any(x in W for x in ("SBIN", "OLDNEWS", "NOTFO", "CHAMBLFERT")), list(W))
sent = []
out = E.tick(NOW.replace(hour=9, minute=26), send=sent.append, W=W)
print("2 · 09:26 the first look")
for x in out:
    print("     " + x.replace("\n", "\n     "))
heads = [x.split("\n")[0] for x in out]
chk("09:25 the list of watched shares is sent first", out and "shares watched today" in out[0], heads)
chk("COROMANDEL ▲: the delayed reaction (+4.3% since the event day, +2.1% today) - the COROMANDEL case", any("EVENT WATCH ▲ COROMANDEL" in x and "delayed reaction: +4.3%" in x for x in out), heads)
chk("COROMANDEL ▲: fresh futures longs ₹60 cr - someone betting on a RISE", any("▲ COROMANDEL" in x and "betting on a RISE: ₹60 cr" in x for x in out))
chk("COROMANDEL ▲: big hands bought and kept (delivery 2.4x)", any("▲ COROMANDEL" in x and "bought and KEPT" in x for x in out))
chk("NAVINFLUOR ▼: 5 days after results, -3.4% since, -1.9% today + fresh shorts - the NAVINFLUOR case", any("▼ NAVINFLUOR" in x and "delayed reaction: -3.4%" in x for x in out) and any("▼ NAVINFLUOR" in x and "betting on a FALL" in x for x in out))
chk("EICHERMOT ▲ before its results: longs ₹80 cr + calls bought - says 'results in 2 days' and that options are expensive before results", any("▲ EICHERMOT" in x and "results in 2 days" in x and "expensive" in x for x in out) and any("▲ EICHERMOT" in x and "calls at 7100 being BOUGHT" in x for x in out))
chk("ONE alert a share: COROMANDEL's three signals (futures, late move, big hands) in one message", sum(1 for h in heads if "COROMANDEL" in h and "EVENT WATCH ▲" in h) == 1, heads)
chk("the reason is the headline, not GIR's header (POLICYBZR's IRDAI news)", "medianama.com 19:32" not in W["POLICYBZR"]["why"], W["POLICYBZR"]["why"])
chk("quiet GRASIM: no alert · SBIN / OLDNEWS: no alert from this agent", not any(("GRASIM" in h or "SBIN" in h or "OLDNEWS" in h) for h in heads[1:]), heads)
chk("every alert says 'an eye on it, not a buy call'", all("not a buy call" in x for x in out[1:]))
chk("it was handed to the sender (Telegram + page)", len(sent) == len(out))
out2 = E.tick(NOW.replace(hour=9, minute=27), send=sent.append, W=W)
chk("a minute later: nothing said twice (and no second list)", out2 == [], [x.split("\n")[0] for x in out2])
d_ = json.load(open("dash_state.json")); d_["fo_paths"][0]["cr"] = 130.0; json.dump(d_, open("dash_state.json", "w")); E._F.clear()
out3 = E.tick(NOW.replace(hour=10, minute=40), send=sent.append, W=W)
chk("an hour later the COROMANDEL longs DOUBLE (₹60 -> ₹130 cr): said again", any("COROMANDEL" in x and "₹130 cr" in x for x in out3), [x.split("\n")[0] for x in out3])
chk("outside 09:20-15:25 and on a Saturday: silent", E.tick(NOW.replace(hour=15, minute=40), send=sent.append, W=W) == [] and E.tick(dt.datetime(2026, 11, 14, 11, 0, tzinfo=IST), send=sent.append, W=W) == [])
d_ = json.load(open("dash_state.json")); d_["fo_paths"][3].update({"bu": "LONG BUILD-UP", "cr": 45.0})
json.dump(d_, open("dash_state.json", "w"))
dk = json.load(open(os.path.join("data", "desk.json"))); dk["shares"]["GRASIM"] = {"lines": {"walls": "puts 2650 was BOUGHT (OI 1 L → 3 L, premium up) — a bet on DOWN"}}
json.dump(dk, open(os.path.join("data", "desk.json"), "w")); E._F.clear()
out5 = E.tick(NOW.replace(hour=13, minute=0), send=sent.append, W=W)
g = next((x for x in out5 if "GRASIM" in x.split("\n")[0]), "")
chk("GRASIM the day before results: longs ₹45 cr BUT puts bought -> one alert '▲▼' that says MIXED - wait for one side", "EVENT WATCH ▲▼ GRASIM" in g and "mixed" in g, g)
E.add("MANUALSH", "promoter stake sale talk", 7)
chk("Rama adds a share by hand: it is watched for 7 days", "MANUALSH" in E.watch_list(NOW) and "added by Rama" in E.watch_list(NOW)["MANUALSH"]["why"])
E.DAY_CAP = 0; E._F.clear()
d_["fo_paths"][1]["cr"] = 200.0; json.dump(d_, open("dash_state.json", "w"))
out4 = E.tick(NOW.replace(hour=12, minute=0), send=sent.append, W=W)
chk("after the day's 30 rings an alert still arrives, without sound (no '🚨 CRITICAL')", out4 and not out4[0].startswith("🚨"), out4)
if SRV and os.path.exists("alertword.py"):
    import alertword as A, tglanes as G
    x = next(x for x in out if "▲ COROMANDEL" in x)
    chk("through GIR's real levels: P2 (rings the nee-naw), not P1", A.tier(x) == "move")
    chk("... goes to GIR Box Picks (critical), NOT the ambulance channel", not G.trade_now(x) and G.lane(x) == "critical", (G.trade_now(x), G.lane(x)))
print("EVENT WATCH test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T1
cat > $W/p236test.py <<'PY_T2'
#!/usr/bin/env python3
"""p236test.py - THE SPECIAL FORCE: the file, the deep triggers (🕵 LEAK, 🤫 QUIET BUILD) and the AI read, simulated (stub data and a stub AI -
nothing sent, no AI spent).  python3 p236test.py SRCDIR  (eventwatch.py + eventbrain.py)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data", "instdeals"))
for f in ("eventwatch.py", "eventbrain.py"):
    shutil.copy(os.path.join(SRC, f), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime(2026, 11, 16, 9, 26, tzinfo=IST)
D = lambda n: str((NOW - dt.timedelta(days=n)).date())
FO = ["GRASIM", "POLICYBZR", "INOXWIND"]
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values (?, 1)", [(s,) for s in FO])
c.execute("create table results_cal(sym text, d text)"); c.execute("insert into results_cal values ('GRASIM', ?)", (str((NOW + dt.timedelta(days=1)).date()),))
c.execute("insert into results_cal values ('INOXWIND', ?)", (str((NOW + dt.timedelta(days=3)).date()),)); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "filings.db")); c.execute("create table filings(sym text, t_exch real, verdict text, kind text, subject text, detail text)")
c.execute("insert into filings values ('POLICYBZR', ?, '', 'ROUTINE', 'Disclosure under SEBI SAST', 'Acquisition of shares by promoter group entity')", (NOW.timestamp() - 3 * 86400,))
c.execute("insert into filings values ('ICICIGI', ?, 'BEAT', 'RESULTS', 'Outcome', '')", (NOW.timestamp() - 2 * 86400,)); c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values (?, '19:47:00', '', 'POLICYBZR', '', ?)", (D(1), "📰 NEWS ▼ POLICYBZR · REG · medianama.com 19:32\nIRDAI's insurance overhaul pushes PB Fintech to non-insurance services"))
c.commit(); c.close()
o = sqlite3.connect(os.path.join(T, "data", "oistudy.db")); o.execute("create table day(d text, sym text, spot real, foi real)")
for i in range(6):                                                   # POLICYBZR: futures OI +22% in 5 days, price +0.8% - a quiet build
    o.execute("insert into day values (?, 'POLICYBZR', ?, ?)", (D(i + 1), 1050.0 - (5 - i) * 0 + (0 if i else 8.4) - 0, 1.22e7 if i == 0 else 1.0e7))
o.commit(); o.close()
json.dump({"fo_paths": [{"s": "GRASIM", "chg": 0.1}, {"s": "POLICYBZR", "chg": 0.3}, {"s": "INOXWIND", "chg": 0.2}]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"t": 0, "q": {"GRASIM": [2700.0, 0.1], "POLICYBZR": [1058.0, 0.3], "INOXWIND": [140.0, 0.2]}}, open(os.path.join(T, "quotes_live.json"), "w"))
json.dump({"shares": {}}, open(os.path.join(T, "data", "desk.json"), "w"))
json.dump({"day": D(1), "rows": [{"s": "POLICYBZR", "cls": "other", "side": "BUY", "q": 500000, "p": 1050.0, "who": "GRAVITON RESEARCH CAPITAL LLP"}]}, open(os.path.join(T, "data", "instdeals", D(1) + ".json"), "w"))
open(os.path.join(T, "chains.py"), "w").write('''
def general_flow(sym, con=None):
    return {"GRASIM": {"ce_d1": 4.0, "pe_d1": 3.0, "ce_d5": 9.0, "pe_d5": 8.0, "pcr": 0.8, "px_d5": 0.4, "days": 12,
                       "top": [{"kind": "CE", "strike": 2800, "oi_add": 250000, "ltp": 21.0}]},
            "POLICYBZR": {"ce_d1": 2.0, "pe_d1": 18.0, "ce_d5": 5.0, "pe_d5": 44.0, "pcr": 1.3, "px_d5": 0.8, "days": 12,
                          "top": [{"kind": "PE", "strike": 1000, "oi_add": 900000, "ltp": 14.0}]}}.get(sym)
def results_tell(sym, con=None, lookback=5):
    if sym == "GRASIM":
        return {"s": sym, "score": 72, "kind": "CE", "key": "CE 2800 11-25", "side": "CALLS building → someone positioned for a BEAT",
                "note": "CE 2800 11-25 OI 1,10,000 → 3,60,000 (+227%) over 5 days · holds 4.1x its neighbouring strikes (was 1.3x) · price +0.4%"}
    return {"s": sym, "score": 0, "note": "no build"}
''')
open(os.path.join(T, "newsroom.py"), "w").write('''
def items_for(sym, hours=96, min_score=0, con=None):
    return {"POLICYBZR": [{"t": "15 Nov 19:32", "h": "IRDAI's insurance overhaul pushes PB Fintech to non-insurance services"},
                          {"t": "15 Nov 08:18", "h": "India bonds to stay hemmed in by oil"}]}.get(sym, [])
''')
open(os.path.join(T, "newsalert.py"), "w").write("def about_it(sym, h, src='', name=''):\n    return 'PB Fintech' in h if sym == 'POLICYBZR' else False\n")
open(os.path.join(T, "sectors.py"), "w").write("def load():\n    return {'insurance': ['POLICYBZR', 'ICICIGI', 'SBILIFE'], 'cement': ['GRASIM']}\n")
open(os.path.join(T, "resultsdesk.py"), "w").write('''
def one(sym, d, now=None, fo=None):
    return {"exp": "₹1,450 cr (+12% YoY)", "wk": 0.8, "mo": 2.1, "em": 4.2, "ivp": 88, "battle": {"short": "BATTLE · ceiling 2800 · floor 2600"}}
def history(sym, n=4):
    return [{"q": "Q1FY27", "verdict": "BEAT", "word": "above", "d1": 2.4, "d3": 4.1}] if sym == "GRASIM" else []
''')
open(os.path.join(T, "instflow.py"), "w").write("def deliv_signals(min_x=1.5):\n    return {'day': '%s', 'acc': [], 'dist': []}\n" % D(1))
open(os.path.join(T, "pushwho.py"), "w").write("def read(s):\n    return {'rows': []}\n")
open(os.path.join(T, "llmread.py"), "w").write('''
import json
CALLS = []
MODE = {"ok": True}
def ask(prompt, max_tokens=1500, strong=False, results=False):
    CALLS.append(prompt)
    if not MODE["ok"]:
        raise RuntimeError("daily AI budget spent ($5.00 of $5.00)")
    if "GRASIM" in prompt.split("THE FILE")[0]:
        return json.dumps({"bias": "UP", "confidence": 68, "who": "call buyers at 2800 for days, price flat", "why": ["CE 2800 +227%", "past results beat"],
                           "levels": "2800", "changes_mind": "put OI jumps", "plain": "Someone has been buying 2800 calls for five days. Options are expensive before results."}), "haiku-test"
    return json.dumps({"bias": "MIXED", "confidence": 40, "who": "put writers below, a quiet futures build", "why": ["put OI +44% in 5 days"], "levels": "1000",
                       "changes_mind": "a break of 1000", "plain": "Support is being built at 1000, but the futures build has no clear side yet."}), "haiku-test"
def _json(t):
    return json.loads(t)
''')
sys.path.insert(0, T); os.chdir(T)
import eventwatch as E, eventbrain as B, llmread as LL
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:500]))
W = E.watch_list(NOW)
print("1 · the file (POLICYBZR)")
F = B.dossier("POLICYBZR", W["POLICYBZR"])
print("     " + json.dumps(F, ensure_ascii=False, default=str)[:900])
chk("options from every strike: put OI +44% in 5 days, the biggest addition in ₹ (PE 1000: ₹1.3 cr of premium)", F["options, every strike"]["put OI 5 days %"] == 44.0 and "₹1.3 cr" in F["options, every strike"]["biggest additions today"][0], F.get("options, every strike"))
chk("futures over 5 days: OI +22%, price +0.8%", F["futures"]["5 days"] == {"futures OI %": 22.0, "price %": 0.8}, F.get("futures"))
chk("big hands: the promoter's SAST filing and the named deal (Graviton)", any("promoter" in x for x in F["big hands"]["promoter / insider filings, 30 days"]) and any("GRAVITON" in x for x in F["big hands"]["named deals, 30 days"]), F.get("big hands"))
chk("news: only the headline that names PB Fintech (the bond story is left out)", F["news about it, 72 h"] == ["15 Nov 19:32 · IRDAI's insurance overhaul pushes PB Fintech to non-insurance services"], F.get("news about it, 72 h"))
chk("peers: ICICIGI's results this week (read-across)", any("ICICIGI" in x for x in F.get("sector peers' results this week") or []), F.get("sector peers' results this week"))
print("2 · 09:26 - the deep triggers and the AI")
sent = []
out = E.tick(NOW, send=sent.append, W=W)
for x in out:
    print("     " + x.replace("\n", "\n     "))
g = next((x for x in out if "GRASIM" in x.split("\n")[0]), ""); p = next((x for x in out if "POLICYBZR" in x.split("\n")[0]), "")
chk("🕵 LEAK: GRASIM the day before results - CE 2800 building for 5 days, price flat -> ▲ GRASIM", "EVENT WATCH ▲ GRASIM" in g and "🕵 CALLS building" in g and "score 72" in g, g)
chk("... with the AI's read: UP · 68% sure, in plain words", "🧠 AI read: UP · 68% sure - Someone has been buying 2800 calls" in g, g)
chk("🤫 QUIET BUILD: POLICYBZR futures OI +22% in 5 days, price +0.8% -> 'side not clear yet' + the options line", "🤫 futures OI +22.0% in 5 days" in p and "side is not clear yet" in p and "put OI +18% / +44%" in p, p)
chk("... the AI says MIXED · 40% (not a forced direction)", "🧠 AI read: MIXED · 40% sure" in p, p)
chk("the 09:25 list carries the AI's one-liner per share", out and "GRASIM" in out[0] and "🧠 UP 68%" in out[0], out[0] if out else "")
n = len(LL.CALLS)
E._F.clear()
E.tick(NOW.replace(minute=40), send=sent.append, W=W)
chk("the AI is asked once per share and kept 30 min (no new calls 14 min later)", len(LL.CALLS) == n, (n, len(LL.CALLS)))
print("3 · the AI unavailable (budget spent / no credit)")
B._AI.clear(); LL.MODE["ok"] = False; E._F.clear()
st = json.load(open(E.STATE)); st["said"] = {}; st["per"] = {}; json.dump(st, open(E.STATE, "w"))
out3 = E.tick(NOW.replace(hour=11), send=sent.append, W=W)
g3 = next((x for x in out3 if "GRASIM" in x.split("\n")[0]), "")
chk("the alert still goes out, with 'AI read: not available' - the facts stand", "🕵 CALLS building" in g3 and "AI read: not available" in g3, g3)
print("SPECIAL FORCE test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T2
echo "=== test: the event watch (22 cases, this server's alert levels) + the special force (12 cases, a stub AI - nothing spent)"
python3 $W/p235test.py $W/src $D 2>&1 | grep -E "❌|passed" || true
python3 $W/p236test.py $W/src 2>&1 | grep -E "❌|passed" || true
python3 $W/p235test.py $W/src $D >/dev/null 2>&1 && python3 $W/p236test.py $W/src >/dev/null 2>&1 || { echo "❌ a test failed - nothing installed"; exit 1; }
cp $W/src/eventwatch.py $W/src/eventbrain.py $D/ && cd $D && python3 -m py_compile eventwatch.py eventbrain.py || back
cat > $U/gir-eventwatch.service <<'UNIT'
[Unit]
Description=GIR 👁 EVENT WATCH - the special force (results and critical-event shares, a week before / after)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && exec python3 -u eventwatch.py run >> data/eventwatch.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-eventwatch >/dev/null 2>&1 && systemctl restart gir-eventwatch
sleep 5; echo "  gir-eventwatch: $(systemctl is-active gir-eventwatch)"
[ "$(systemctl is-active gir-eventwatch)" = "active" ] || back
echo "=== who the special force watches now (this server's calendar, filings and alerts)"
cd $D && timeout 120 python3 eventwatch.py list 2>&1 | head -30
echo "✅ patch 236 done - the special force runs on its own (gir-eventwatch)."
echo "   one share's full file + the AI's read (uses a few cents of AI):  cd $D && python3 eventbrain.py COROMANDEL"
echo "   add a share by hand for 7 days:                                  cd $D && python3 eventwatch.py add COROMANDEL \"fertiliser subsidy\" 7"
echo "   its log: tail -f $D/data/eventwatch.log      undo: systemctl disable --now gir-eventwatch"
