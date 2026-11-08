#!/bin/bash
# PATCH 131 - GIR WATCHES ITSELF + THE TRADING CALENDAR (on top of patch 130c).
#   On the Muhurat Sunday the market traded and GIR's engine slept - Rama found it, GIR did not say it. Now, every cycle:
#   - 🚨 GIR NOT LIVE (Box Picks) when a session trades and the engine is not live for 3 min - again every 15 min;
#     ✅ GIR LIVE again when it is back · 🚨 SERVICE DOWN when a GIR service stops in market hours
#   - 📋 GIR HEALTH once a day ~5 min after the open (engine live, ticks a second)
#   - 📅 the evening before: an NSE holiday (no trading) or a special session · 🪔 a special session announced in the
#     news (Muhurat ... "from 6:15 pm to 7:15 pm") is added to the session list by itself
#   girhealth.py (new) · dashserve.py, tglanes.py (exact anchors). Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g131; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p131.sh now"; exit 1; fi
grep -q "def _fo_ok" $D/engine2.py 2>/dev/null || { echo "patch 130c is not installed yet - paste patch 130c first"; exit 1; }
[ -f $D/girhealth.py ] && { echo "patch 131 is already installed"; exit 1; }
F="dashserve.py tglanes.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/girhealth.py $D/p131test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p131_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p131_patch.py - PATCH 131: GIR WATCHES ITSELF - the page server's refresher calls girhealth.tick() every cycle.
Usage: python3 p131_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "dashserve.py": [
        ('''        try:
            react_tick(); react_summary()                         # patch 123: 📊 the news reaction
        except Exception as ex:
            print("news reaction:", str(ex)[:80])
''', '''        try:
            react_tick(); react_summary()                         # patch 123: 📊 the news reaction
        except Exception as ex:
            print("news reaction:", str(ex)[:80])
        try:
            import girhealth; girhealth.tick()                    # patch 131: GIR watches itself (NOT LIVE · SERVICE DOWN · holidays)
        except Exception as ex:
            print("health:", str(ex)[:80])
'''),
    ],
    "tglanes.py": [
        ('''        if k in ("📋", "📊") or "SCORECARD" in H2.upper():''',
         '''        if k in ("📋", "📊", "📅", "🪔") or "SCORECARD" in H2.upper():   # patch 131: + the calendar notes'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("dashserve.py: GIR watches itself every cycle")
PY_PATCH
cat > $W/girhealth.py <<'PY_HEALTH'
#!/usr/bin/env python3
"""girhealth.py - patch 131: GIR WATCHES ITSELF. On the Muhurat Sunday (8 Nov 2026) the market traded and GIR's engine
slept - Rama found it, GIR did not say it. The page server's refresher calls tick() every cycle:

  🚨 GIR NOT LIVE     the market trades (a normal or special session) and the engine's live state is older than 3 minutes
                      -> GIR Box Picks, again every 15 min until it is back; then ✅ GIR LIVE again (and for how long it was out)
  🚨 SERVICE DOWN     a GIR service (engine, desk, exchange, newsroom) is not running in market hours
  📋 GIR HEALTH       once a day ~5 min after the open: engine live, ticks a second, the strike sockets - silence never means
                      "maybe broken"
  📅 TOMORROW         the evening before: an NSE holiday (no trading) or a special session (GIR runs it)
  🪔 FROM THE NEWS    a headline announcing a special session (Muhurat, a Budget-day weekend session ...) -> the date and
                      times are read and added to the session list (sessions.py), and said on Telegram
  python3 girhealth.py      what it sees now"""
import os, re, json, time, subprocess, datetime as dt
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(BASE, "dash_state.json")
QUOTES = os.path.join(BASE, "quotes_live.json")
MINE = os.path.join(BASE, "data", "health.json")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SERVICES = ("gir-intraday", "gir-desk", "gir-exchange", "gir-newsroom")
DOWN_AFTER, REPEAT, EVERY = 180, 900, 30
SEND = None                                   # tests put a list's append here; else engine2.tg_fo


def _send(text):
    if SEND is not None:
        return SEND(text)
    import engine2
    return engine2.tg_fo(text)


def _load():
    try:
        return json.load(open(MINE))
    except Exception:
        return {}


def _save(h):
    os.makedirs(os.path.dirname(MINE), exist_ok=True)
    json.dump(h, open(MINE + ".tmp", "w")); os.replace(MINE + ".tmp", MINE)


def engine_live(now):
    """(live?, why, ticks a second) from the engine's own files"""
    try:
        st = json.load(open(STATE))
    except Exception:
        return False, "no engine state file", None
    day, ts = st.get("day"), st.get("ts") or ""
    if day != now.strftime("%Y-%m-%d"):
        return False, "the engine's state is from %s" % (day or "?"), None
    try:
        age = (now.replace(tzinfo=None) - dt.datetime.strptime(ts[:19], "%Y-%m-%d %H:%M:%S")).total_seconds()
    except Exception:
        age = 1e9
    if st.get("closed") or str(st.get("feed") or "").lower() in ("closed", "market closed"):
        return False, "the engine says closed (%s)" % ts[11:16], None
    if age > DOWN_AFTER:
        return False, "the engine's last state is %d min old (%s)" % (age // 60, ts[11:16]), None
    return True, "live", st.get("ticks_s")


def services_down():
    out = []
    for u in SERVICES:
        try:
            r = subprocess.run(["systemctl", "is-active", u], capture_output=True, text=True, timeout=10)
            if r.stdout.strip() not in ("active", "activating"):
                out.append("%s (%s)" % (u, r.stdout.strip() or "?"))
        except Exception:
            pass
    return out


def _in_session(now):
    import sessions
    s = sessions.session(now.date())
    if not s:
        return None
    hm = now.strftime("%H:%M")
    return s if s["open"] <= hm <= s["close"] else None


def tick(now=None, force=False):
    now = now or dt.datetime.now(IST)
    h = _load()
    if not force and time.time() - float(h.get("at") or 0) < EVERY:
        return []
    h["at"] = time.time()
    out = []
    say = lambda t: (out.append(t), _send(t))
    ses = _in_session(now)
    hm = now.strftime("%H:%M")
    nows = now.timestamp()
    if ses:
        opened = dt.datetime.strptime(now.strftime("%Y-%m-%d ") + ses["open"], "%Y-%m-%d %H:%M").replace(tzinfo=IST)
        live, why, tps = engine_live(now)
        if (nows - opened.timestamp()) >= DOWN_AFTER:          # the first 3 minutes of a session are the engine's to start in
            if not live:
                h.setdefault("down_since", nows)
                if nows - h["down_since"] >= DOWN_AFTER and nows - float(h.get("down_said") or 0) >= REPEAT:
                    h["down_said"] = nows
                    say("🚨 GIR NOT LIVE · %s · the market trades (%s %s-%s) but %s\nno live prices, no OI scanning, no alerts.\n"
                        "Fix on the server:  systemctl restart gir-intraday   (live again in ~2-3 min)" % (
                            hm, ses["name"] if ses.get("special") else "session", ses["open"], ses["close"], why))
            else:
                if h.get("down_said"):
                    say("✅ GIR LIVE again · %s · it was not live from %s" % (hm, dt.datetime.fromtimestamp(h["down_since"], IST).strftime("%H:%M")))
                h.pop("down_since", None); h.pop("down_said", None)
                if h.get("beat_day") != now.strftime("%Y-%m-%d") and nows - opened.timestamp() >= 300:
                    h["beat_day"] = now.strftime("%Y-%m-%d")
                    say("📋 GIR HEALTH %s · engine LIVE%s · %s%s" % (hm, (" · %s ticks/s" % tps) if tps else "", ses["name"] if ses.get("special") else "normal session",
                                                                  " · services all running" if not services_down() else ""))
        if nows - float(h.get("svc_at") or 0) >= 300:
            h["svc_at"] = nows
            down = services_down()
            key = ",".join(down)
            if down and (key != h.get("svc_said") or nows - float(h.get("svc_said_at") or 0) >= 1800):
                h["svc_said"], h["svc_said_at"] = key, nows
                say("🚨 SERVICE DOWN · %s · %s\nFix on the server:  systemctl restart %s" % (hm, ", ".join(down), " ".join(x.split(" ")[0] for x in down)))
            elif not down:
                h.pop("svc_said", None)
    else:
        h.pop("down_since", None); h.pop("down_said", None)
    if "18:00" <= hm <= "21:00" and h.get("eve_day") != now.strftime("%Y-%m-%d"):
        h["eve_day"] = now.strftime("%Y-%m-%d")
        t = tomorrow_note(now)
        if t:
            say(t)
    if nows - float(h.get("news_at") or 0) >= 3600:
        h["news_at"] = nows
        for t in sessions_from_news(now):
            say(t)
    _save(h)
    return out


def tomorrow_note(now):
    """the evening note: a special session before the next weekday, or the next weekday is an NSE holiday"""
    import sessions
    for i in range(1, 4):
        d = now.date() + dt.timedelta(days=i)
        s = sessions.session(d)
        if s and s.get("special"):
            return "📅 %s %s · SPECIAL SESSION %s-%s (%s) - GIR runs it (it starts 40 min before)" % (
                "TOMORROW" if i == 1 else "COMING", d.strftime("%a %d %b"), s["open"], s["close"], s["name"])
        if d.weekday() < 5:
            if s:
                return None                                     # the next weekday trades normally
            try:
                import holidays
                name = holidays.holiday(d) or "holiday"
            except Exception:
                name = "holiday"
            nxt = d + dt.timedelta(days=1)
            while sessions.session(nxt) is None and (nxt - d).days <= 10:
                nxt += dt.timedelta(days=1)
            return "📅 %s %s · NSE HOLIDAY (%s) - no trading · next session %s" % ("TOMORROW" if i == 1 else "NEXT WEEKDAY", d.strftime("%a %d %b"), name, nxt.strftime("%a %d %b"))
    return None


TIME_RX = re.compile(r"(\d{1,2})[:.](\d{2})\s*(am|pm|a\.m\.|p\.m\.)?\s*(?:to|-|–|till|until)\s*(\d{1,2})[:.](\d{2})\s*(am|pm|a\.m\.|p\.m\.)?", re.I)
SES_RX = re.compile(r"muhurat|special (live )?trading session|special session|trading on (saturday|sunday)", re.I)
MONTHS = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}


def parse_session(h, now):
    """a headline -> (date, open, close) of a special session, or None (words only; the model reads it when there)"""
    m = TIME_RX.search(h)
    if not m:
        return None

    def hm(hh, mm, ap):
        hh = int(hh)
        if ap and ap.lower().startswith("p") and hh < 12:
            hh += 12
        return "%02d:%s" % (hh, mm)
    o = hm(m.group(1), m.group(2), m.group(3) or m.group(6))
    c = hm(m.group(4), m.group(5), m.group(6))
    if o >= c:
        return None
    d = None
    dm = re.search(r"(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*", h, re.I) or \
        re.search(r"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})", h, re.I)
    if dm:
        a, b = dm.group(1), dm.group(2)
        day_, mon = (int(a), MONTHS[b[:3].lower()]) if a.isdigit() else (int(b), MONTHS[a[:3].lower()])
        try:
            d = dt.date(now.year, mon, day_)
            if d < now.date() - dt.timedelta(days=1):
                d = dt.date(now.year + 1, mon, day_)
        except Exception:
            d = None
    elif re.search(r"\btoday\b", h, re.I):
        d = now.date()
    elif re.search(r"\btomorrow\b", h, re.I):
        d = now.date() + dt.timedelta(days=1)
    return (d, o, c) if d else None


def sessions_from_news(now, items=None):
    """headlines of the last 3 days announcing a special session -> added to sessions.py (once) -> the lines said"""
    import sessions
    if items is None:
        items = []
        try:
            j = json.load(open(os.path.join(BASE, "data", "macro.json")))
            items = [x.get("h") or "" for x in j.get("items") or [] if now.timestamp() - float(x.get("t") or 0) < 3 * 86400]
        except Exception:
            pass
    out = []
    for h in items:
        if not SES_RX.search(h or ""):
            continue
        p = parse_session(h, now)
        if not p:
            continue
        d, o, c = p
        if d < now.date() or sessions.session(d) is not None and sessions.session(d).get("special"):
            continue
        if sessions.session(d) is not None and (o, c) == ("09:15", "15:30"):
            continue                                            # a normal day said again
        name = "Muhurat" if re.search(r"muhurat", h, re.I) else "special session"
        sessions.save(d, o, c, name + " (from the news)")
        out.append("🪔 GIR added a SPECIAL SESSION from the news: %s %s-%s (%s)\n\"%s\"\nGIR will run it. Wrong? on the server:  python3 sessions.py remove %s" % (
            d.strftime("%a %d %b"), o, c, name, h[:160], d))
    return out


if __name__ == "__main__":
    now = dt.datetime.now(IST)
    live, why, tps = engine_live(now)
    print("session now: %s" % (_in_session(now) or "closed"))
    print("engine: %s%s" % ("LIVE" if live else "not live - " + why, (" · %s ticks/s" % tps) if tps else ""))
    print("services down: %s" % (", ".join(services_down()) or "none"))
    print("tomorrow: %s" % (tomorrow_note(now) or "a normal day / weekend"))
PY_HEALTH
cat > $D/p131test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p131test.py - GIR WATCHES ITSELF: a session with the engine not live -> 🚨 GIR NOT LIVE (once per 15 min) -> ✅ LIVE again;
the daily health line; a service down; the evening holiday / special-session note; a special session read from the news.
Fake files, a fake clock, a fake Telegram."""
import os, sys, json, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import holidays
HOL = {"2026-11-24": "Guru Nanak Jayanti"}
holidays.holiday = lambda d=None: ("weekend" if d.weekday() >= 5 else HOL.get(str(d)))
import girhealth, sessions
IST = girhealth.IST
tmp = tempfile.mkdtemp(prefix="p131")
try:
    girhealth.STATE = os.path.join(tmp, "dash_state.json"); girhealth.MINE = os.path.join(tmp, "health.json"); girhealth.BASE = tmp
    sessions.FILE = os.path.join(tmp, "sessions.json")
    SENT = []
    girhealth.SEND = SENT.append
    DOWN = []
    girhealth.services_down = lambda: list(DOWN)
    os.makedirs(os.path.join(tmp, "data"))
    json.dump({"items": []}, open(os.path.join(tmp, "data", "macro.json"), "w"))

    def state(day, ts, feed="websocket", closed=False, tps=1900):
        json.dump({"day": day, "ts": ts, "feed": feed, "closed": closed, "ticks_s": tps}, open(girhealth.STATE, "w"))
    T = lambda h, m, d=9: dt.datetime(2026, 11, d, h, m, tzinfo=IST)
    print("1. the engine not live in a session")
    state("2026-11-06", "2026-11-06 15:30:20", "closed", True)
    girhealth.tick(T(9, 17), force=True)
    check("09:17 (2 min after the open): quiet - the engine's start-up time", not SENT)
    girhealth.tick(T(9, 19), force=True)
    girhealth.tick(T(9, 22), force=True)
    check("09:22, still Friday's state: 🚨 GIR NOT LIVE: %s" % (SENT[-1].split("\n")[0] if SENT else None),
          len(SENT) == 1 and SENT[0].startswith("🚨 GIR NOT LIVE · 09:22") and "2026-11-06" in SENT[0] and "systemctl restart gir-intraday" in SENT[0])
    girhealth.tick(T(9, 30), force=True)
    check("09:30: not said again within 15 min", len(SENT) == 1)
    girhealth.tick(T(9, 38), force=True)
    check("09:38: said again", len(SENT) == 2)
    state("2026-11-09", "2026-11-09 09:40:01")
    girhealth.tick(T(9, 40), force=True)
    check("09:40 the engine is live: ✅ GIR LIVE again + the day's health line: %s" % [x.split("\n")[0][:60] for x in SENT[2:]],
          any(x.startswith("✅ GIR LIVE again · 09:40 · it was not live from 09:19") for x in SENT) and any(x.startswith("📋 GIR HEALTH 09:40 · engine LIVE · 1900 ticks/s") for x in SENT))
    n = len(SENT)
    state("2026-11-09", "2026-11-09 10:00:00"); girhealth.tick(T(10, 0), force=True)
    check("10:00 all well: nothing more (the health line once a day)", len(SENT) == n)
    print("2. a service down")
    DOWN[:] = ["gir-desk (failed)"]
    state("2026-11-09", "2026-11-09 10:06:00"); girhealth.tick(T(10, 6), force=True)
    check("gir-desk stopped: 🚨 SERVICE DOWN with the fix", SENT[-1].startswith("🚨 SERVICE DOWN · 10:06 · gir-desk (failed)") and "systemctl restart gir-desk" in SENT[-1])
    n = len(SENT); state("2026-11-09", "2026-11-09 10:12:00"); girhealth.tick(T(10, 12), force=True)
    check("not repeated within 30 min", len(SENT) == n)
    DOWN[:] = []
    print("3. the calendar")
    SENT[:] = []
    state("2026-11-23", "2026-11-23 15:30:00", "closed", True)
    girhealth.tick(T(18, 30, 23), force=True)
    check("Mon 23 Nov evening: 📅 TOMORROW Tue 24 Nov NSE HOLIDAY (Guru Nanak Jayanti), next session Wed 25 Nov: %s" % SENT,
          SENT and SENT[0].startswith("📅 TOMORROW Tue 24 Nov · NSE HOLIDAY (Guru Nanak Jayanti)") and "next session Wed 25 Nov" in SENT[0])
    SENT[:] = []
    girhealth.tick(T(18, 30, 7), force=True)
    check("Sat 7 Nov evening: 📅 TOMORROW Sun 08 Nov SPECIAL SESSION 14:20-15:30 (Diwali Muhurat)", SENT and SENT[0].startswith("📅 TOMORROW Sun 08 Nov · SPECIAL SESSION 14:20-15:30 (Diwali Muhurat)"))
    print("4. a special session from the news")
    now = dt.datetime(2027, 10, 20, 12, 0, tzinfo=IST)
    got = girhealth.sessions_from_news(now, ["NSE, BSE to hold Muhurat trading on October 29 from 6:15 pm to 7:15 pm",
                                             "Markets to remain shut on Oct 29 for Diwali, says NSE", "Muhurat trading 2027: what to buy this Diwali"])
    s29 = sessions.session(dt.date(2027, 10, 29))
    check("'Muhurat trading on October 29 from 6:15 pm to 7:15 pm' -> Fri 29 Oct 2027 18:15-19:15 added: %s" % (s29,),
          s29 and s29["special"] and (s29["open"], s29["close"]) == ("18:15", "19:15") and len(got) == 1 and got[0].startswith("🪔 GIR added a SPECIAL SESSION from the news: Fri 29 Oct 18:15-19:15"))
    check("the same headline again adds nothing", girhealth.sessions_from_news(now, ["NSE, BSE to hold Muhurat trading on October 29 from 6:15 pm to 7:15 pm"]) == [])
    check("a headline without times or a date adds nothing", girhealth.parse_session("Muhurat trading 2027: what to buy this Diwali", now) is None)
    import tglanes
    check("the health line, the calendar notes -> ⚙️ System; NOT LIVE / SERVICE DOWN -> Box Picks (critical)",
          [tglanes.topic(x) for x in ("📋 GIR HEALTH 09:20 · engine LIVE", "📅 TOMORROW Tue 24 Nov · NSE HOLIDAY", "🪔 GIR added a SPECIAL SESSION from the news",
                                       "🚨 GIR NOT LIVE · 09:22 · x", "🚨 SERVICE DOWN · 10:06 · gir-desk")] == ["system", "system", "system", "critical", "critical"])
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP131 GIR WATCHES ITSELF TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p131_patch.py $D || { rm -f $D/p131test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/girhealth.py $D/
cd $D && python3 -m py_compile girhealth.py dashserve.py tglanes.py p131test.py || back
timeout 60 python3 p131test.py 2>&1 | grep "OK  \|FAIL\|ITSELF TEST"
timeout 60 python3 p131test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p127test.py p124test.py p123test.py p130test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
echo
echo "PATCH 131 APPLIED. GIR watches itself from now on. What it sees right now:"
python3 $D/girhealth.py
