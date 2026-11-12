#!/bin/bash
# PATCH 222 - EXIT WATCH: every 🔴 P1 call followed until it is closed (Rama, 12 Nov: "your duty is not only to signal the entry, also to
#   signal the exit"). Every 15 s, for each of today's P1 calls with a side (GO, ENTER NOW, Box Pick, opening call, measured BUY):
#   🛑 EXIT - STOP (a 5-min close beyond the call's stop) · 🛑 EXIT - TURNED (2+ against: VWAP, futures, desk, who is pushing, half the gain
#   given back) · 🎯 BOOK HALF (1R its way; the rest's stop moves to the call) · 🛑 EXIT THE REST · ⏰ TIME EXIT 15:05. Each rings (🚨
#   CRITICAL -> GIR Box Picks), names the call it follows, once. Tested: 12 made-up cases + the simulated day 16; then TODAY's real P1 calls
#   replayed on this server's 5-min candles (what it would have said). Restarts the news hunt - run it after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); mkdir -p $W/src
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/newshunt.py ] && grep -q "patch 215" $D/newshunt.py || { echo "patch 215 first"; exit 1; }
cp $D/newshunt.py $D/newshunt.py.bak$TS; [ -f $D/exitwatch.py ] && cp $D/exitwatch.py $D/exitwatch.py.bak$TS
back(){ cp $D/newshunt.py.bak$TS $D/newshunt.py; if [ -f $D/exitwatch.py.bak$TS ]; then cp $D/exitwatch.py.bak$TS $D/exitwatch.py; else rm -f $D/exitwatch.py; fi
        systemctl restart gir-newshunt; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/src/exitwatch.py <<'PY_EXIT'
#!/usr/bin/env python3
"""exitwatch.py - patch 222: EXIT WATCH - every 🔴 P1 call followed until it is closed (Rama, 12 Nov: "your duty is not only to signal the
entry, also to signal the exit - UNIONBANK is still going down"). Runs inside the news hunt (every 15 s, the live prices). For each of today's
P1 calls with a side (CE / PE) - a GO, ENTER NOW, Box Pick, opening call, measured BUY:
  🛑 EXIT - STOP      a 5-min candle closes beyond the call's own stop ("stop: a close under 200")
  🛑 EXIT - TURNED    before the stop, 2+ of these turn against it (10 min after the call): the 5-min close through the day's VWAP · the
                      futures flip (long unwinding / short build-up for a CE) · the desk flips · who is pushing turns (new money the other way)
                      · half the best gain given back
  🎯 BOOK HALF        the share moved its way as far as the risk to the stop (1R, at least 0.8%) - sell half, the stop on the rest moves to
                      where GIR called it; a 5-min close back there -> 🛑 EXIT THE REST
  ⏰ TIME EXIT        15:05 - every call still open: an intraday call, sell before the close (the next day is a coin toss)
Every message names the call it follows and rings (🚨 CRITICAL - GIR Box Picks). Once each; the state is kept in data/exitwatch.json (a restart
does not repeat). replay(day) runs the price rules over a day's 5-min candles (a study, nothing sent)."""
import os, re, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
BOOK_MIN, GIVE_MIN, TURN_AFTER, TIME_AT, RING_CAP = 0.8, 0.8, 600, "15:05", 40
STRONG = ("NEW MONEY", "BOTH", "FORCED OUT")
ST = {"day": None, "calls": {}, "rang": 0, "loaded": 0.0}
_F = {}


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


def _p1(text):
    import alertword
    return alertword.tier(text) == "act"


def parse(text):
    """an alert's text -> {"stop": (dir, level) or None, "opt": (strike, CE/PE, premium) or None}"""
    m = re.search(r"stop:\s*a close (under|below|over|above) ₹?([\d,]+(?:\.\d+)?)", text or "")
    o = re.search(r"\b(\d+(?:\.\d+)?)\s+(CE|PE)\s+(?:~\s*)?₹\s*([\d.]+)", text or "")
    return {"stop": (m.group(1) in ("under", "below") and -1 or 1, float(m.group(2).replace(",", ""))) if m else None,
            "opt": (o.group(1), o.group(2), float(o.group(3))) if o else None}


def candles(sym, now=None):
    """the share's 5-min candles today -> (closed closes, running VWAP after each closed candle, the last closed candle's end HH:MM)"""
    c = (_json("charts.json", 10) or {}).get(sym) or {}
    C, H, L, V = c.get("c") or [], c.get("h") or [], c.get("l") or [], c.get("v") or []
    n = len(C)
    if now is not None:
        mins = (now.hour * 60 + now.minute) - (9 * 60 + 15)
        n = max(0, min(n, mins // 5))                           # only the candles that have closed
    cl, vw, pv, vv = [], [], 0.0, 0.0
    for i in range(n):
        if C[i] is None:
            continue
        h_, l_, v_ = (H[i] if i < len(H) and H[i] else C[i]), (L[i] if i < len(L) and L[i] else C[i]), (V[i] if i < len(V) and V[i] else 0)
        pv += (h_ + l_ + C[i]) / 3.0 * v_; vv += v_
        cl.append(C[i]); vw.append(pv / vv if vv else None)
    end = None
    if n:
        e = 9 * 60 + 15 + 5 * n
        end = "%02d:%02d" % (e // 60, e % 60)
    return cl, vw, end


def _save():
    if ST.get("replay"):
        return                                                  # a replay never touches the live state
    try:
        p = os.path.join(BASE, "data", "exitwatch.json")
        json.dump({"day": ST["day"], "rang": ST["rang"], "calls": ST["calls"]}, open(p + ".tmp", "w"), default=str)
        os.replace(p + ".tmp", p)
    except Exception:
        pass


def _restore(day):
    try:
        j = json.load(open(os.path.join(BASE, "data", "exitwatch.json")))
        if j.get("day") == day:
            ST.update({"calls": j.get("calls") or {}, "rang": j.get("rang") or 0})
    except Exception:
        pass


def load_calls(day, now, px, is_p1=None):
    """today's P1 calls with a side, from the alerts table - new ones added (each (share, side) followed once at a time)"""
    is_p1 = is_p1 or _p1
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=3)
        rows = c.execute("select t, sym, side, text from alerts where day=? order by t", (day,)).fetchall()
        c.close()
    except Exception:
        return
    for t, s, side, text in rows:
        side = (side or "").upper()
        if not s or side not in ("CE", "PE") or s in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX", "MARKET"):
            continue
        if re.search(r"EXIT|BOOK HALF|OPENING CALL FAILED", (text or "").split("\n")[0]) or not is_p1(text):
            continue
        hm = str(t)[:5]
        if any(k.startswith("%s|%s|" % (s, side)) and not v.get("closed") for k, v in ST["calls"].items()):
            continue                                            # already following this share's call on that side
        key = "%s|%s|%s" % (s, side, hm)
        if key in ST["calls"]:
            continue
        p = parse(text)
        cl, vw, end = candles(s)
        h_, m_ = int(hm[:2]), int(hm[3:5])
        i = ((h_ * 60 + m_) - (9 * 60 + 15)) // 5               # the candle the call came in
        age = (now.hour * 60 + now.minute) - (h_ * 60 + m_)
        entry = px.get(s) if (age <= 2 and px.get(s)) else (cl[i] if 0 <= i < len(cl) else px.get(s))   # a fresh call: the price now
        if not entry:
            continue
        d = 1 if side == "CE" else -1
        stop = p["stop"][1] if p["stop"] else None
        if stop and (stop - entry) * d >= 0:
            stop = None                                         # a stop on the wrong side of the price is not a stop
        r = abs(entry - stop) / entry * 100 if stop else None
        ST["calls"][key] = {"s": s, "side": side, "d": d, "t": hm, "entry": entry, "stop": stop, "r": r, "opt": p["opt"],
                            "peak": 0.0, "booked": False, "closed": False, "said": [], "since": i + 1}
    _save()


def _name(c):
    o = c.get("opt")
    return "%s %s %s" % (c["s"], o[0], o[1]) if o else "%s %s" % (c["s"], c["side"])


def _msg(c, icon, what, why, px, hm, act):
    o = c.get("opt")
    fav = (px / c["entry"] - 1) * 100                          # no ▲ / ▼ in the head: an exit is not a new CE / PE call
    return "\n".join(["🚨 CRITICAL · %s %s · %s · %s" % (icon, what, _name(c), hm),
                      "the P1 call of %s (%sshare ₹%s)" % (c["t"], ("BUY %s %s ₹%g · " % (o[0], o[1], o[2])) if o else "", _inr(c["entry"])),
                      "why: " + why,
                      "share ₹%s now (%+.1f%% from the call)" % (_inr(px), fav),
                      "▶ " + act])


def _inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def _against(c, s, d):
    """the live checks that turned against the call (futures, desk, who is pushing) -> [reasons]"""
    out = []
    f = next((x for x in _json("dash_state.json", 10).get("fo_paths") or [] if x.get("s") == s), None) or {}
    bu, cr = (f.get("bu") or "").replace("_", " ").upper(), abs(f.get("cr") or 0)
    if cr >= 5 and ((d > 0 and bu in ("LONG UNWINDING", "SHORT BUILD-UP")) or (d < 0 and bu in ("SHORT COVERING", "LONG BUILD-UP"))):
        out.append("the futures turned: %s ₹%.0f cr" % (bu.lower(), cr))
    dk = ((_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(s) or {})
    v = dk.get("v")
    if isinstance(v, (int, float)) and v * d <= -1:
        out.append("the desk turned: %s %+d" % (dk.get("label") or "", v))
    try:
        import pushwho
        p = pushwho.read(s)
        pd_ = 1 if p.get("dir") == "UP" else -1 if p.get("dir") == "DOWN" else 0
        if pd_ == -d and p.get("kind") in STRONG:
            out.append("who is pushing turned: %s %s" % (p.get("kind"), "UP" if pd_ > 0 else "DOWN"))
    except Exception:
        pass
    return out


def step(c, px, cl, vw, hm, live=True):
    """one call, one look -> [messages]; price rules from the closed 5-min candles, the money rules live"""
    if c["closed"]:
        return []
    s, d, out = c["s"], c["d"], []
    fav = (px / c["entry"] - 1) * 100 * d
    c["peak"] = max(c["peak"], fav)
    last = cl[-1] if len(cl) >= c["since"] + 1 else None     # a candle that closed AFTER the call's own candle
    lvw = vw[-1] if vw else None
    said = c["said"]
    # 1 the stop (after BOOK HALF: where GIR called it)
    stp = c["entry"] if c["booked"] else c["stop"]
    if last is not None and stp and ((last - stp) * d <= 0 if c["booked"] else (last - stp) * d < 0):
        c["closed"] = True
        if c["booked"]:
            return [_msg(c, "🛑", "EXIT THE REST", "a 5-min close at %s back to where GIR called it - the first half is booked" % _inr(last), px, hm,
                         "sell the rest of the %s now" % _name(c).split(" ", 1)[1])]
        return [_msg(c, "🛑", "EXIT - STOP", "a 5-min close at %s, %s the stop ₹%s" % (_inr(last), "under" if d > 0 else "over", _inr(c["stop"])), px, hm,
                     "sell the %s now - the call is over" % _name(c).split(" ", 1)[1])]
    # 2 BOOK HALF: as far as the risk (1R), at least 0.8%
    need = max(BOOK_MIN, c["r"] or 1.5)
    if not c["booked"] and fav >= need:
        c["booked"] = True; said.append("book")
        out.append(_msg(c, "🎯", "BOOK HALF", "the share is %+.1f%% its way - as far as the risk to the stop%s" % (fav, (" (%.1f%%)" % c["r"]) if c["r"] else ""),
                        px, hm, "sell HALF the %s now · the stop on the rest moves to ₹%s (where GIR called it)" % (_name(c).split(" ", 1)[1], _inr(c["entry"]))))
    # 3 TURNED: 2+ against, 10 min after the call
    if not c["booked"] and last is not None and len(cl) >= c["since"] + 2:   # 10 min after the call
        why = []
        if lvw and (last - lvw) * d < 0:
            why.append("a 5-min close at %s %s the day's VWAP ₹%s" % (_inr(last), "under" if d > 0 else "over", _inr(lvw)))
        if c["peak"] >= GIVE_MIN and fav <= c["peak"] / 2:
            why.append("half the best gain given back (%+.1f%% -> %+.1f%%)" % (c["peak"], fav))
        if live:
            why += _against(c, s, d)
        if len(why) >= 2:
            c["closed"] = True
            return out + [_msg(c, "🛑", "EXIT - TURNED", " · ".join(why), px, hm, "sell the %s now - do not wait for the stop" % _name(c).split(" ", 1)[1])]
    # 4 TIME
    if hm >= TIME_AT and "time" not in said:
        said.append("time"); c["closed"] = True
        out.append(_msg(c, "⏰", "TIME EXIT", "15:05 - an intraday call; the next day is a coin toss", px, hm,
                        "sell %sthe %s before the close" % ("the rest of " if c["booked"] else "", _name(c).split(" ", 1)[1])))
    return out


def tick(now, ltp, is_p1=None):
    """now (IST) · ltp {sym: price} -> [alert texts]"""
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "calls": {}, "rang": 0, "loaded": 0.0, "replay": False})
        _restore(day)
    hm = now.strftime("%H:%M")
    if not ("09:20" <= hm <= "15:25"):
        return []
    if time.time() - ST["loaded"] >= 30:
        ST["loaded"] = time.time()
        load_calls(day, now, ltp, is_p1)
    out = []
    for k, c in ST["calls"].items():
        px = ltp.get(c["s"])
        if c["closed"] or not px:
            continue
        cl, vw, _ = candles(c["s"], now)
        msgs = step(c, px, cl, vw, hm)
        for m in msgs:
            if ST["rang"] >= RING_CAP:
                m = m.replace("🚨 CRITICAL · ", "", 1)               # the day's rings spent - a quiet line
            else:
                ST["rang"] += 1
            out.append(m)
    if out or any(c["closed"] for c in ST["calls"].values()):
        _save()
    return out


def replay(day, is_p1=None, quiet=False):
    """the price rules (stop, VWAP + give-back, BOOK HALF, the stop moved to the entry, 15:05) over a day's 5-min candles - nothing sent.
    -> [(call, [(HH:MM, message head)], the share at 15:25 vs the call %)]"""
    ST.update({"day": day, "calls": {}, "rang": 0, "replay": True})
    d0 = dt.datetime.strptime(day, "%Y-%m-%d").replace(tzinfo=IST)
    allc = _json("charts.json", 1e9) or {}
    load_calls(day, d0.replace(hour=15, minute=25), {}, is_p1)
    res = []
    for k, c in sorted(ST["calls"].items(), key=lambda x: x[1]["t"]):
        C = (allc.get(c["s"]) or {}).get("c") or []
        ev = []
        for n in range(c["since"] + 1, len(C) + 1):
            e = 9 * 60 + 15 + 5 * n
            hm = "%02d:%02d" % (e // 60, e % 60)
            if hm > "15:25":
                break
            cl, vw, _ = candles(c["s"], d0.replace(hour=e // 60, minute=e % 60))
            if not cl:
                continue
            for m in step(c, cl[-1], cl, vw, hm, live=False):
                ev.append((hm, m.split("\n")[0].replace("🚨 CRITICAL · ", "")))
            if c["closed"]:
                break
        last = [x for x in C if x]
        res.append((c, ev, ((last[-1] / c["entry"] - 1) * 100) if last else None))
    return res


if __name__ == "__main__":
    import sys
    day = sys.argv[1] if len(sys.argv) > 1 else str(dt.datetime.now(IST).date())
    for c, ev, endp in replay(day):
        print("%s %-11s %s entry ₹%s stop %s%s" % (c["t"], c["s"], c["side"], _inr(c["entry"]), ("₹" + _inr(c["stop"])) if c["stop"] else "-",
                                                  (" · at 15:25 %+.1f%% its way" % (endp * c["d"])) if endp is not None else ""))
        for hm, h in ev:
            print("      %s  %s" % (hm, h))
PY_EXIT
cat > $W/p222_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p222_patch.py - PATCH 222: EXIT WATCH wired into the news hunt (every 15 s, the live prices). exitwatch.py sits next to this script.
Usage: python3 p222_patch.py DIR SRCDIR"""
import sys, os, shutil
D, SRC = sys.argv[1], sys.argv[2]
shutil.copy(os.path.join(SRC, "exitwatch.py"), os.path.join(D, "exitwatch.py")); print("  exitwatch.py: in")
p = os.path.join(D, "newshunt.py"); s = open(p, encoding="utf-8").read()
old = '''                msgs += pushalert.tick(now, mv, day_mv, med=med, fo=fo_set())
            except Exception as ex:
                log("push / pull: %s" % str(ex)[:80])'''
new = old + '''
        if q and live:                                          # patch 222: EXIT WATCH - every P1 call followed to its exit
            try:
                import exitwatch
                msgs += exitwatch.tick(now, q)
            except Exception as ex:
                log("exit watch: %s" % str(ex)[:80])'''
if new in s:
    print("  newshunt.py: the exit watch - already in")
elif s.count(old) != 1:
    print("❌ newshunt.py: anchor found %d times" % s.count(old)); sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  newshunt.py: the exit watch every 15 s")
print("patch 222 in")
PY_PATCH
cat > $W/p222test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p222test.py - EXIT WATCH on made-up days (temp folder, stub readers - nothing sent): calls going right, going wrong, CE and PE.
python3 p222test.py DIR  (DIR has exitwatch.py)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "exitwatch.py"), T)
open(os.path.join(T, "pushwho.py"), "w").write("def read(s):\n    return {'dir': '', 'kind': ''}\n")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DAY = "2026-11-12"; D0 = dt.datetime(2026, 11, 12, tzinfo=IST)
N = 75                                                       # 09:15 .. 15:25


def idx(hm):
    return ((int(hm[:2]) * 60 + int(hm[3:])) - (9 * 60 + 15)) // 5


def path(base, pts):
    """closes: flat at base, then straight lines between (HH:MM, price) points"""
    c = [base] * N; last_i, last_p = 0, base
    for hm, p in pts:
        i = idx(hm)
        for j in range(last_i, i + 1):
            c[j] = round(last_p + (p - last_p) * (j - last_i) / max(1, i - last_i), 2)
        last_i, last_p = i, p
    for j in range(last_i, N):
        c[j] = last_p
    return c


CH = {
    "UNIONBANK": path(202.0, [("12:55", 203.9), ("13:30", 202.8), ("13:45", 199.8)]),          # A: a CE call that fails - the stop
    "MCX": path(3580.0, [("12:50", 3600.0), ("13:20", 3637.0), ("13:50", 3595.0)]),               # B: a CE that went +1% then fell back
    "TATASTEEL": path(151.5, [("11:55", 151.5), ("12:00", 150.0), ("12:40", 151.8), ("13:20", 150.7)]),   # G: +1.2% (under 1R), half given back
    "PNB": path(139.0, [("12:40", 140.0), ("13:30", 142.0), ("14:30", 139.8)]),                   # C: CE: BOOK HALF, then back to the call
    "HINDUNILVR": path(2000.0, [("11:00", 1985.0), ("12:30", 1960.0)]),                           # D: a PE that works: BOOK HALF, then 15:05
    "SBIN": path(800.0, [("11:00", 801.0), ("11:30", 805.0)]),                                    # E: a CE that drifts: 15:05 TIME EXIT
    "ITC": path(400.0, [("11:00", 401.0), ("12:00", 396.0)]),                                     # F: a WATCH line - not a P1, never followed
}
json.dump({s: {"c": c, "h": [x + 0.1 for x in c], "l": [x - 0.1 for x in c], "v": [1000] * N} for s, c in CH.items()}, open(os.path.join(T, "charts.json"), "w"))
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
for t, s, sd, tx in [("12:55", "UNIONBANK", "CE", "🎯 BOX PICK ▲ UNIONBANK\nBUY: 205 CE ₹4.48 · stop: a close under 200"),
                     ("12:50", "MCX", "CE", "🟢 GO · MCX ▲ CE\nBUY: 3650 CE ₹99.6 · stop: a close under 3589.3"),
                     ("12:00", "TATASTEEL", "CE", "🟢 GO · TATASTEEL ▲ CE\nBUY: 152 CE ₹2.1 · stop: a close under 147"),
                     ("12:40", "PNB", "CE", "🎯 BOX PICK ▲ PNB\nBUY: 141 CE ₹3.28 · stop: a close under 138.6"),
                     ("11:00", "HINDUNILVR", "PE", "🟢 GO · HINDUNILVR ▼ PE\nBUY: 1960 PE ₹22.2 · stop: a close over 2000"),
                     ("11:00", "SBIN", "CE", "🟢 GO · SBIN ▲ CE\nBUY: 810 CE ₹6.1 · stop: a close under 792"),
                     ("11:00", "ITC", "CE", "🧩 CALL WRITERS RUNNING ▲ ITC\n▶ WATCH CE 400")]:
    c.execute("insert into alerts values (?, ?, '', ?, ?, ?)", (DAY, t, s, sd, tx))
c.commit(); c.close()
json.dump({"day": DAY, "fo_paths": [{"s": "MCX", "bu": "LONG UNWINDING", "cr": 40.0}]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"shares": {"MCX": {"v": -1, "label": "BEARISH"}}}, open(os.path.join(T, "data", "desk.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import exitwatch as X
P1 = lambda t: "BUY" in t and "WATCH" not in t
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:500]))


R = {c["s"]: (c, ev, e) for c, ev, e in X.replay(DAY, is_p1=P1)}
for s, (c, ev, e) in R.items():
    print("   %s %s %s entry %s stop %s: %s" % (c["t"], s, c["side"], c["entry"], c["stop"], " | ".join("%s %s" % x for x in ev) or "-"))
ev = R["UNIONBANK"][1]
chk("A UNIONBANK CE (stop 200): 🛑 EXIT - STOP at the first 5-min close under 200", len(ev) == 1 and "EXIT - STOP" in ev[0][1] and ev[0][0] <= "13:50", ev)
ev = R["MCX"][1]
chk("B MCX CE +1%: 🎯 BOOK HALF, then 🛑 EXIT THE REST when it falls back to the call", [h.split(" · ")[0] for _, h in ev] == ["🎯 BOOK HALF", "🛑 EXIT THE REST"], ev)
ev = R["TATASTEEL"][1]
chk("G TATASTEEL CE +1.2% (under 1R, no booking) then half given back under VWAP: 🛑 EXIT - TURNED, long before the stop 147", len(ev) == 1 and "EXIT - TURNED" in ev[0][1] and ev[0][0] < "13:30", ev)
ev = R["PNB"][1]
chk("C PNB CE: 🎯 BOOK HALF on the way up, then 🛑 EXIT THE REST back at the call", [h.split(" · ")[0] for _, h in ev] == ["🎯 BOOK HALF", "🛑 EXIT THE REST"], ev)
ev = R["HINDUNILVR"][1]
chk("D HINDUNILVR PE (a fall): 🎯 BOOK HALF, then ⏰ TIME EXIT at 15:05 for the rest", [h.split(" · ")[0] for _, h in ev] == ["🎯 BOOK HALF", "⏰ TIME EXIT"] and ev[-1][0] == "15:05", ev)
ev = R["SBIN"][1]
chk("E SBIN CE drifting: no exit until ⏰ TIME EXIT at 15:05", [h.split(" · ")[0] for _, h in ev] == ["⏰ TIME EXIT"], ev)
chk("F ITC (a WATCH line, not a P1): never followed", "ITC" not in R, list(R))
# live: MCX at 13:35 with the futures and the desk turned - exits on the money before the price rules
X.ST.update({"day": None}); X._F.clear()
try:
    os.remove(os.path.join(T, "data", "exitwatch.json"))
except Exception:
    pass
now = D0.replace(hour=13, minute=36)
px = {s: CH[s][idx("13:35") - 1] for s in CH}
m = X.tick(now, px, is_p1=P1)
mm = [x for x in m if "MCX" in x.split("\n")[0]]
chk("live MCX 13:36: 🛑 EXIT - TURNED names the futures and the desk", mm and "EXIT - TURNED" in mm[0] and "futures turned" in mm[0] and "desk turned" in mm[0], m)
chk("the message rings (🚨 CRITICAL) and names the call it follows", mm and mm[0].startswith("🚨 CRITICAL · 🛑") and "the P1 call of 12:50 (BUY 3650 CE ₹99.6" in mm[0] and "▶ sell the 3650 CE now" in mm[0], mm)
m2 = X.tick(now + dt.timedelta(seconds=15), px, is_p1=P1)
chk("15 s later: nothing said twice", not [x for x in m2 if "MCX" in x.split("\n")[0]], m2)
X.ST.update({"day": None, "calls": {}})                     # a restart of the news hunt
m3 = X.tick(now + dt.timedelta(seconds=30), px, is_p1=P1)
chk("after a restart: still nothing said twice (data/exitwatch.json)", not [x for x in m3 if "MCX" in x.split("\n")[0]], m3)
chk("before 09:20 / after 15:25: silent", X.tick(D0.replace(hour=15, minute=40), px, is_p1=P1) == [])
print("EXIT WATCH test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
echo "=== test: made-up days (calls going right, wrong, CE and PE)"
python3 $W/p222test.py $W/src || { echo "❌ test failed - nothing changed"; exit 1; }
python3 $W/p222_patch.py $D $W/src || back
cd $D && python3 -m py_compile exitwatch.py newshunt.py || back
echo "=== TODAY's real P1 calls, replayed on this server's 5-min candles (price rules only - what EXIT WATCH would have said)"
cd $D && timeout 120 python3 exitwatch.py "$(TZ=Asia/Kolkata date +%F)" 2>&1 | head -80
systemctl restart gir-newshunt && sleep 6 && echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
[ "$(systemctl is-active gir-newshunt)" = "active" ] || back
echo "✅ patch 222 done - from tomorrow 09:20 every 🔴 P1 call gets its 🎯 BOOK HALF / 🛑 EXIT / ⏰ TIME EXIT on Telegram (GIR Box Picks)."
echo "   any day's replay: cd $D && python3 exitwatch.py 2026-11-12"
echo "   undo: cp $D/newshunt.py.bak$TS $D/newshunt.py; systemctl restart gir-newshunt"
