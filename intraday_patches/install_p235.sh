#!/bin/bash
# PATCH 235 - 👁 EVENT WATCH: two agents for the shares around a big event, in their own service (Rama, 13 Nov: "an agent only for the results
#   shares - a week before and a week after; some shares react days later, COROMANDEL, NAVINFLUOR; an alert and eye power that something is
#   brewing, not a buy").
#   AGENT 1 RESULTS: results in the next 7 days or filed in the last 7 · AGENT 2 EVENTS: shares named in a critical event of the last 7 days
#   (Cabinet / govt "shares to watch", shock watch, regulator, results reaction, the reason) + shares added by hand.
#   Every minute 09:20-15:25: fresh futures money ₹25 cr+ · option writers moving (wall breaking, calls / puts bought) · the delayed reaction
#   (3%+ since the event day and 1.5%+ today the same way) · big hands (delivery). ONE alert a share: 🚨 CRITICAL · 👁 EVENT WATCH ▲/▼/▲▼ SYM -
#   the nee-naw (Box Picks), never the ambulance; "an eye on it, not a buy call". 09:25 the list of watched shares.
#   Tested: 22 simulated cases (COROMANDEL, NAVINFLUOR, EICHERMOT, GRASIM mixed, quiet shares, repeats, caps) with this server's alert levels.
#   Adds a NEW service only (gir-eventwatch) - nothing else restarts: safe any time.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d); mkdir -p $W/src; U=/etc/systemd/system
[ -f $D/opencall.py ] && [ -f $D/pushwho.py ] || { echo "GIR's opencall / pushwho not found"; exit 1; }
[ -f $D/eventwatch.py ] && cp $D/eventwatch.py $D/eventwatch.py.bak$(date +%m%d%H%M%S)
back(){ systemctl disable --now gir-eventwatch 2>/dev/null; rm -f $U/gir-eventwatch.service $D/eventwatch.py; systemctl daemon-reload; echo "❌ removed again - nothing else was touched"; exit 1; }
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


def text(sym, w, sigs, now):
    """one alert for one share: every new thing brewing in it"""
    ups, dns = sum(1 for x in sigs if x[1] > 0), sum(1 for x in sigs if x[1] < 0)
    ar = "▲" if ups and not dns else "▼" if dns and not ups else "▲▼"
    L = ["🚨 CRITICAL · 👁 EVENT WATCH %s %s · %s" % (ar, sym, now.strftime("%H:%M")),
         "%s · %s" % ("RESULTS WATCH" if w["agent"] == "RESULTS" else "EVENT WATCH", _when(w))]
    L += ["brewing (%s): %s" % (k.lower(), line) for k, sd, line, _k in sigs]
    if ups and dns:
        L.append("⚠ mixed - some bet on a rise, some on a fall: wait for one side to win")
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
        L.append("%s %s - %s" % ("📅" if w["phase"] == "before" else "👁", s, _when(w)))
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
        for sig in signals(sym, w, st):
            key = "%s|%s" % (sym, json.dumps(sig[3]))
            kk = "%s|%s" % (sym, sig[0])
            if key in st["said"] or t - (st["said"].get(kk) or 0) < GAP_S:
                continue
            st["said"][key] = t; st["said"][kk] = t
            new_.append(sig)
        if new_:
            st["per"][sym] = st["per"].get(sym, 0) + 1
            tx = text(sym, w, new_, now)
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
cat > $W/p235test.py <<'PY_TEST'
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
PY_TEST
echo "=== test: 22 simulated cases (with this server's alert levels and channels)"
python3 $W/p235test.py $W/src $D 2>&1 | grep -E "❌|passed" || true
python3 $W/p235test.py $W/src $D >/dev/null 2>&1 || { echo "❌ test failed - nothing installed"; exit 1; }
cp $W/src/eventwatch.py $D/eventwatch.py && cd $D && python3 -m py_compile eventwatch.py || back
cat > $U/gir-eventwatch.service <<'UNIT'
[Unit]
Description=GIR 👁 EVENT WATCH (results and critical-event shares, a week before / after)
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
echo "=== who is being watched now (this server's calendar, filings and alerts)"
cd $D && timeout 120 python3 eventwatch.py list 2>&1 | head -40
echo "✅ patch 235 done - 👁 EVENT WATCH runs on its own. 09:25 the list, then one nee-naw alert a share when money starts building."
echo "   add a share by hand:   cd $D && python3 eventwatch.py add COROMANDEL \"fertiliser subsidy\" 7"
echo "   its log:               tail -f $D/data/eventwatch.log"
echo "   undo:                  systemctl disable --now gir-eventwatch"
