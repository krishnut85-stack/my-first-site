#!/bin/bash
# PATCH 84 - THE OI SCENARIO AGENT (on top of patch 83). Every way open interest builds up, named in a trader's words,
#   watched on every F&O share on every 5-s reading, alerting on the GIR page and on Telegram.
#   · 28 scenarios: the futures LONG BUILD-UP / SHORT BUILD-UP / SHORT COVERING / LONG UNWINDING and THE FUTURES TURNED ·
#     the four boxes on calls and on puts (CALLS BOUGHT, SELLERS BUILDING A ROOF, CALL WRITERS RUNNING, CALL BUYERS LEAVING,
#     PUTS BOUGHT, SELLERS BUILDING A FLOOR, PUT WRITERS RUNNING, PUT BUYERS LEAVING) · the combinations (FLOOR BUILDING,
#     ROOF LEAVING · ROOF BUILDING, FLOOR LEAVING · SELLERS BOX IT IN · THE RISE / THE FALL IS NOT TRUSTED) · the walls
#     moving (floor / roof up / down) · PCR swings · max pain moving · both premiums pumped / crushed with the price flat
#   · each one: a side (UP -> CE / DOWN -> PE) or a reading, a claim the 15:45 audit scores on the same-day close, and its
#     measured number - from the live fires AND from a backfill over the 10 days of 15-min chain readings on this server
#   · a scenario must hold 60 s before it fires; once per share and scenario a day; from 09:45 (open + 30) to 15:18
#   · the reading-only lines go to GIR Intraday as ONE silent digest a minute at most (12 a message) - the phone is not flooded
#   · GIR Box Picks (sound) only with every gate: a side, the rule measuring BUY (55% on 50+), a liquid strike (OI 20,000+,
#     Rs 2+), the stop, the size, not banned, not expiry week, no CE under a roof / PE over a floor, the desk and the results
#     not reading the other way. Everything else -> GIR Intraday without sound. Every scenario is on the page. Nothing muted.
#     Your word: data/scenarios_off.txt (ids, page only) · data/scn_config.json {"box_when": "WATCH"} (every acting one to Box Picks)
#   · the page: an OI SCENARIOS panel (today's fires per scenario, the shares, the number), the share's scenarios in FOCUS,
#     the tape's OI line names the share's latest scenario
#   scenarios.py (new) · desk.py dashserve.py (exact anchors) · home.html. Installs p84test.py. Restarts gir-desk, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g84; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p84.sh now"; exit 1; fi
grep -q '"/oi"' $D/dashserve.py || { echo "patch 83 is not installed yet - paste patch 83 first"; exit 1; }
grep -q "import scenarios" $D/desk.py && { echo "patch 84 is already installed"; exit 1; }
F="desk.py dashserve.py home.html"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/scenarios.py $D/p84test.py; systemctl restart gir-desk gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $D/scenarios.py <<'PY_SCN'
#!/usr/bin/env python3
"""scenarios.py - THE OI SCENARIO AGENT: every way open interest builds up, named in a trader's words, on every F&O share.

Runs inside THE DESK (desk.py) on every 5-second reading of the engine's pinned strikes (pins_live.json) and the futures
build-up from the engine's state. Each scenario has:
  · a name in plain words ("PUTS BOUGHT", "SELLERS BUILDING A ROOF", "SHORT COVERING" ...)
  · a side (share price going UP -> CE / DOWN -> PE) or none (a reading: a range, a wall, the premiums)
  · a CLAIM the 15:45 audit can score on the same-day close (it closed higher / lower / under the roof / inside the range ...)
  · its measured number: right N% of M on THIS server - from the live fires and from a backfill over the 10 days of
    15-minute chain readings already on the server (chains.db chain15). New rules start as WATCH; BUY needs 55% on 50+.
Gates before a scenario reaches GIR Box Picks (the acting channel, with sound): a side, open+30 (09:45) or later, not in
the F&O ban list, not in expiry week (rollover fakes OI), a liquid strike (OI 20,000+, premium Rs 2+), the stop and the
size, no CE under a roof / PE over a floor, the desk and the results not reading the other way, and the rule measuring
BUY (55%+ on 50+). Everything else goes to GIR Intraday without sound - nothing is muted - and every line is on the page.
A scenario must hold for 60 s on the 5-s readings before it fires (one thin reading is not a build-up); once per share
and scenario a day. data/scenarios_off.txt (scenario ids, one per line) keeps a scenario on the page only - your word.
data/scn_config.json {"box_when": "BUY"} - set "WATCH" to send every acting scenario to Box Picks while it is new.

  python3 scenarios.py --list               the catalogue
  python3 scenarios.py --backfill [days]    replay chain15 (default: every day on the server) -> the measured numbers
  python3 scenarios.py --replay YYYY-MM-DD  what would have fired on that day, line by line (prints only)
  python3 scenarios.py --scores             the measured table
  python3 scenarios.py --test               the self-test (synthetic chains, every scenario, no network)
"""
import os, re, sys, json, time, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core

BASE, DATA = core.BASE, core.DATA
BAND, WALL_BAND = 0.08, 0.10
MIN_OI, MIN_P = 20000, 2.0
HOLD_S = 60

# id, NAME, side (CE / PE / None / "dyn"), acts (may reach Box Picks), claim, what it means
CAT = [
    ("fut_long_buildup", "LONG BUILD-UP", "CE", True, "up", "price up and futures OI up: buyers came in with fresh money"),
    ("fut_short_buildup", "SHORT BUILD-UP", "PE", True, "down", "price down and futures OI up: sellers came in with fresh money"),
    ("fut_short_covering", "SHORT COVERING", "CE", True, "up", "price up and futures OI down: sellers running, buying back — fast, and it can fade unless new buyers come in"),
    ("fut_long_unwinding", "LONG UNWINDING", "PE", True, "down", "price down and futures OI down: buyers leaving — a slow drift lower; avoid CE"),
    ("fut_turn", "THE FUTURES TURNED", "dyn", True, "side", "the futures build-up changed sides after holding 30 min: the money that drove the move is leaving"),
    ("calls_bought", "CALLS BOUGHT", "CE", True, "up", "calls BOUGHT (OI up, premium up): someone bets on a rise"),
    ("call_writing", "SELLERS BUILDING A ROOF", None, False, "notup", "calls WRITTEN (OI up, premium down) just above the price: sellers say it will not go higher"),
    ("call_short_covering", "CALL WRITERS RUNNING", "CE", True, "up", "call writers buying back (OI down, premium up): the roof is giving way"),
    ("call_unwinding", "CALL BUYERS LEAVING", "PE", False, "down", "call buyers closing (OI down, premium down): the rise is losing believers"),
    ("puts_bought", "PUTS BOUGHT", "PE", True, "down", "puts BOUGHT (OI up, premium up): someone bets on a fall"),
    ("put_writing", "SELLERS BUILDING A FLOOR", None, False, "notdown", "puts WRITTEN (OI up, premium down) just under the price: sellers say it will not go lower"),
    ("put_short_covering", "PUT WRITERS RUNNING", "PE", True, "down", "put writers buying back (OI down, premium up): the floor is giving way"),
    ("put_unwinding", "PUT BUYERS LEAVING", "CE", False, "up", "put buyers closing (OI down, premium down): the fall is losing believers"),
    ("bull_shift", "FLOOR BUILDING, ROOF LEAVING", "CE", True, "up", "puts written under the price while call writers run above: the strongest CE set-up in the chain"),
    ("bear_shift", "ROOF BUILDING, FLOOR LEAVING", "PE", True, "down", "calls written above the price while put writers run below: the strongest PE set-up in the chain"),
    ("range_writing", "SELLERS BOX IT IN", None, False, "range", "calls written above and puts written below with the price flat: sellers expect a range — option buyers lose to time here, WAIT"),
    ("rise_not_trusted", "THE RISE IS NOT TRUSTED", "PE", False, "down", "the share is up, but sellers keep writing calls just above and nobody writes puts below"),
    ("fall_not_trusted", "THE FALL IS NOT TRUSTED", "CE", False, "up", "the share is down, but sellers keep writing puts just below and nobody writes calls above"),
    ("floor_up", "THE FLOOR MOVED UP", "CE", True, "up", "the biggest put wall moved to a higher strike: put sellers now defend a higher price"),
    ("floor_down", "THE FLOOR MOVED DOWN", "PE", False, "down", "the biggest put wall moved to a lower strike: the old support was given up"),
    ("roof_up", "THE ROOF MOVED UP", "CE", False, "up", "the biggest call wall moved to a higher strike: the ceiling was raised"),
    ("roof_down", "THE ROOF MOVED DOWN", "PE", True, "down", "the biggest call wall moved to a lower strike: call sellers now cap a lower price"),
    ("pcr_up", "PUTS ADDED FASTER", "CE", False, "up", "the put-call ratio near the price rose sharply since the morning: put writers outnumber call writers"),
    ("pcr_down", "CALLS ADDED FASTER", "PE", False, "down", "the put-call ratio near the price fell sharply since the morning: call writers outnumber put writers"),
    ("maxpain_up", "MAX PAIN MOVED UP", "CE", False, "up", "the strike where option sellers lose least moved up: the sellers' comfort zone is higher"),
    ("maxpain_down", "MAX PAIN MOVED DOWN", "PE", False, "down", "the strike where option sellers lose least moved down: the sellers' comfort zone is lower"),
    ("iv_pump", "BOTH SIDES PUMPED", None, False, "big", "CE and PE premiums both up with the price flat: someone expects a big move soon (news, results)"),
    ("iv_crush", "BOTH SIDES CRUSHED", None, False, "small", "CE and PE premiums both falling with the price flat: tickets losing value — not a buyer's market"),
]
C = {c[0]: {"id": c[0], "name": c[1], "side": c[2], "acts": c[3], "claim": c[4], "what": c[5]} for c in CAT}
FUT = {"LONG BUILD-UP": "fut_long_buildup", "SHORT BUILD-UP": "fut_short_buildup", "SHORT COVERING": "fut_short_covering", "LONG UNWINDING": "fut_long_unwinding"}
FUT_UP = ("LONG BUILD-UP", "SHORT COVERING")
CLAIM_TXT = {"up": "the share closes higher", "down": "the share closes lower", "below": "the share closes under %(k1)g (the roof holds)",
             "above": "the share closes over %(k1)g (the floor holds)", "range": "the share closes inside %(k2)g–%(k1)g",
             "big": "a move of 1.5%% or more by the close", "small": "the share stays within 1%% to the close",
             "notup": "the share does not close higher than now", "notdown": "the share does not close lower than now"}


def L(v):
    v = float(v or 0)
    return ("%.2f L" % (v / 1e5)) if abs(v) >= 1e5 else "{:,}".format(int(round(v)))


def claim_ok(claim, side, spot, close, k1=None, k2=None):
    """did the scenario's claim hold on the close? -> (right: bool, move % your way or abs move)"""
    if not spot or not close:
        return None, None
    mv = (close / spot - 1) * 100
    if claim == "side":
        claim = "up" if side == "CE" else "down"
    if claim == "up":
        return mv > 0, mv
    if claim == "down":
        return mv < 0, -mv
    if claim == "below":
        return close <= (k1 or spot), -mv
    if claim == "above":
        return close >= (k1 or spot), mv
    if claim == "range":
        return (k2 or 0) <= close <= (k1 or 9e9), -abs(mv)
    if claim == "notup":
        return mv <= 0.2, -mv
    if claim == "notdown":
        return mv >= -0.2, mv
    if claim == "big":
        return abs(mv) >= 1.5, abs(mv)
    if claim == "small":
        return abs(mv) < 1.0, -abs(mv)
    return None, None


# ---------------------------------------------------------------- the chain maths
def one_expiry(ch, spot):
    """the nearest expiry with 6+ strikes within the band -> {(k, kind): (oi, ltp, tt)}"""
    if not ch or not spot:
        return {}, None
    by = {}
    for (e, k, kd), x in ch.items():
        if abs(k / spot - 1) <= WALL_BAND:
            by.setdefault(e, {})[(float(k), kd)] = x
    for e in sorted(by):
        if len(by[e]) >= 6:
            return by[e], e
    return {}, None


def walls(c, spot):
    """roof = the CE strike with the most OI from the price to +10%; floor = the PE strike with the most OI from -10% to the price"""
    ce = [(x[0], k) for (k, kd), x in c.items() if kd == "CE" and spot <= k <= spot * 1.10 and x[0] >= 50000]
    pe = [(x[0], k) for (k, kd), x in c.items() if kd == "PE" and spot * 0.90 <= k <= spot and x[0] >= 50000]
    roof = max(ce) if ce else None
    floor = max(pe) if pe else None
    return ({"k": roof[1], "oi": roof[0]} if roof else None), ({"k": floor[1], "oi": floor[0]} if floor else None)


def pcr(c, spot):
    sce = sum(x[0] for (k, kd), x in c.items() if kd == "CE" and abs(k / spot - 1) <= BAND)
    spe = sum(x[0] for (k, kd), x in c.items() if kd == "PE" and abs(k / spot - 1) <= BAND)
    return (spe / sce if sce else None), sce + spe


def max_pain(c, spot):
    ks = sorted({k for (k, kd) in c})
    if len(ks) < 5:
        return None
    best = None
    for K in ks:
        pain = sum(max(0, K - k) * x[0] for (k, kd), x in c.items() if kd == "CE") + sum(max(0, k - K) * x[0] for (k, kd), x in c.items() if kd == "PE")
        if best is None or pain < best[0]:
            best = (pain, K)
    return best[1]


def events(now, prev, spot, maxwall, normal, t_now=None, live=True):
    """the strikes where real money moved between `prev` and `now`: the four boxes, liquid and big only.
    box: bought (OI up, premium up) · written (OI up, premium down) · running (OI down, premium up) · leaving (OI down, premium down)"""
    out = []
    for key, (oi, ltp, tt) in now.items():
        k, kd = key
        if abs(k / spot - 1) > BAND or (live and tt and t_now and t_now - tt > 300):
            continue
        p = prev.get(key)
        if not p:
            continue
        oi0, p0 = p[0], p[1]
        if max(oi, oi0) < MIN_OI or max(ltp, p0) < MIN_P or not p0:
            continue
        doi, dp = oi - oi0, ltp - p0
        if abs(doi) < max(0.15 * max(oi, oi0), 10000, 0.03 * maxwall) or abs(dp) < 0.05 * p0:
            continue
        big = abs(doi) >= max(25000, 0.10 * maxwall) and ((not normal) or abs(doi) >= 3 * normal or (oi0 and doi / oi0 >= 1.0))
        if not big:
            continue
        box = ("bought" if dp > 0 else "written") if doi > 0 else ("running" if dp > 0 else "leaving")
        out.append({"k": k, "kind": kd, "box": box, "oi0": oi0, "oi": oi, "p0": p0, "p": ltp, "doi": doi, "x": (abs(doi) / normal) if normal else None})
    return out


def ev_text(e, win):
    who = {"bought": "BOUGHT", "written": "WRITTEN", "running": "writers buying back", "leaving": "buyers closing"}[e["box"]]
    return "%g %s: OI %s → %s%s, premium ₹%g → ₹%g %s — %s %s" % (
        e["k"], e["kind"], L(e["oi0"]), L(e["oi"]), (" (%.0fx normal)" % e["x"]) if e.get("x") and e["x"] >= 3 else "",
        round(e["p0"], 2), round(e["p"], 2), win, "calls" if e["kind"] == "CE" else "puts", who)


def pick(evs, kind, box, ok=lambda e: True):
    c = [e for e in evs if e["kind"] == kind and e["box"] == box and ok(e)]
    return max(c, key=lambda e: abs(e["doi"])) if c else None


def detect(now_ch, prev_ch, ref_ch, spot, spot15=None, ref_spot=None, fp=None, normal=None, ref_t="09:45", t_now=None, live=True, mp_cache=None):
    """one share, one reading -> [hit]: {"id", "side", "k1", "k2", "line"} (pure: the agent adds the hold, the gates, the words)"""
    hits = []
    now, exp = one_expiry(now_ch, spot)
    if not now:
        return hits, exp
    prev = {(float(k), kd): x for (e, k, kd), x in (prev_ch or {}).items() if e == exp}
    ref = {(float(k), kd): x for (e, k, kd), x in (ref_ch or {}).items() if e == exp}
    maxwall = max([x[0] for x in now.values()] or [0])
    wins = []
    if prev:
        wins.append(("in 15 min", events(now, prev, spot, maxwall, normal, t_now, live)))
    if ref and ref_ch is not prev_ch:
        wins.append(("since %s" % ref_t, events(now, ref, spot, maxwall, normal, t_now, live)))
    seen = set()

    def add(id_, line, side=None, k1=None, k2=None):
        if id_ in seen:
            return
        seen.add(id_)
        hits.append({"id": id_, "side": side or C[id_]["side"], "k1": k1, "k2": k2, "line": line})

    near_up = lambda lo, hi: (lambda e: spot * lo <= e["k"] <= spot * hi)
    for win, evs in wins:
        cb = pick(evs, "CE", "bought", near_up(0.97, 9))
        cw = pick(evs, "CE", "written", near_up(0.995, 1.03))
        cr = pick(evs, "CE", "running", near_up(0.98, 9))
        cl = pick(evs, "CE", "leaving")
        pb = pick(evs, "PE", "bought", near_up(0, 1.03))
        pw = pick(evs, "PE", "written", near_up(0.97, 1.005))
        pr = pick(evs, "PE", "running", near_up(0, 1.02))
        pl = pick(evs, "PE", "leaving")
        if pw and cr:
            add("bull_shift", "%s · %s" % (ev_text(pw, win), ev_text(cr, win)), k1=pw["k"])
        if cw and pr:
            add("bear_shift", "%s · %s" % (ev_text(cw, win), ev_text(pr, win)), k1=cw["k"])
        for id_, e in (("calls_bought", cb), ("call_writing", cw), ("call_short_covering", cr), ("call_unwinding", cl),
                       ("puts_bought", pb), ("put_writing", pw), ("put_short_covering", pr), ("put_unwinding", pl)):
            if e:
                add(id_, ev_text(e, win), k1=e["k"])
        if win.startswith("since") and ref_spot:
            day_mv = (spot / ref_spot - 1) * 100
            cw3 = pick(evs, "CE", "written", near_up(1.0, 1.03))
            pw3 = pick(evs, "PE", "written", near_up(0.97, 1.0))
            if cw3 and pw3 and abs(day_mv) <= 0.5:
                add("range_writing", "%s · %s · price %+.1f%% %s" % (ev_text(cw3, win), ev_text(pw3, win), day_mv, win), k1=cw3["k"], k2=pw3["k"])
            chg = (fp or {}).get("chg")
            up_day = (chg if chg is not None else day_mv)
            if up_day >= 1.0 and cw3 and not pick(evs, "PE", "written"):
                add("rise_not_trusted", "share %+.1f%% today · %s · no put writing under the price" % (up_day, ev_text(cw3, win)), k1=cw3["k"])
            if up_day <= -1.0 and pw3 and not pick(evs, "CE", "written"):
                add("fall_not_trusted", "share %+.1f%% today · %s · no call writing above the price" % (up_day, ev_text(pw3, win)), k1=pw3["k"])
    # the walls moving, PCR, max pain - since the morning reference
    if ref and ref_spot:
        r0, f0 = walls(ref, ref_spot)
        r1, f1 = walls(now, spot)
        if f0 and f1 and f1["k"] != f0["k"]:
            old_now = (now.get((f0["k"], "PE")) or (0,))[0]
            if f1["oi"] >= 0.8 * max(old_now, 1):
                add("floor_up" if f1["k"] > f0["k"] else "floor_down", "the floor %g → %g (put OI %s at %g, %s left at %g)" % (f0["k"], f1["k"], L(f1["oi"]), f1["k"], L(old_now), f0["k"]), k1=f1["k"])
        if r0 and r1 and r1["k"] != r0["k"]:
            old_now = (now.get((r0["k"], "CE")) or (0,))[0]
            if r1["oi"] >= 0.8 * max(old_now, 1):
                add("roof_up" if r1["k"] > r0["k"] else "roof_down", "the roof %g → %g (call OI %s at %g, %s left at %g)" % (r0["k"], r1["k"], L(r1["oi"]), r1["k"], L(old_now), r0["k"]), k1=r1["k"])
        p0, n0 = pcr(ref, ref_spot)
        p1, n1 = pcr(now, spot)
        if p0 is not None and p1 is not None and min(n0, n1) >= 200000:
            if p1 - p0 >= 0.25 and p1 >= 1.0:
                add("pcr_up", "PCR near the price %.2f → %.2f %s" % (p0, p1, "since %s" % ref_t))
            elif p0 - p1 >= 0.25 and p1 <= 0.8:
                add("pcr_down", "PCR near the price %.2f → %.2f %s" % (p0, p1, "since %s" % ref_t))
        mp = None
        if mp_cache is not None and mp_cache.get("t", 0) > (t_now or 0) - 60 and mp_cache.get("v"):
            mp0, mp1 = mp_cache["v"]
        else:
            common = {key: x for key, x in now.items() if key in ref}
            mp0, mp1 = max_pain({key: ref[key] for key in common}, ref_spot), max_pain(common, spot)
            if mp_cache is not None:
                mp_cache.update({"t": t_now or 0, "v": (mp0, mp1)})
        if mp0 and mp1 and mp1 != mp0 and abs(mp1 / mp0 - 1) >= 0.005:
            add("maxpain_up" if mp1 > mp0 else "maxpain_down", "max pain %g → %g since %s" % (mp0, mp1, ref_t), k1=mp1)
    # both premiums at the money with the price flat
    if prev and spot15:
        ks = sorted({k for (k, kd) in now if (k, "CE") in now and (k, "PE") in now and (k, "CE") in prev and (k, "PE") in prev}, key=lambda k: abs(k - spot))
        if ks:
            k = ks[0]
            c1, c0, q1, q0 = (round(x, 2) for x in (now[(k, "CE")][1], prev[(k, "CE")][1], now[(k, "PE")][1], prev[(k, "PE")][1]))
            mv = (spot / spot15 - 1) * 100
            if min(c0, q0) >= MIN_P and abs(mv) <= 0.3:
                rc, rq = c1 / c0 - 1, q1 / q0 - 1
                if rc >= 0.10 and rq >= 0.10:
                    add("iv_pump", "%g CE ₹%g → ₹%g and %g PE ₹%g → ₹%g in 15 min, price %+.1f%%" % (k, c0, c1, k, q0, q1, mv), k1=k)
                elif rc <= -0.10 and rq <= -0.10:
                    add("iv_crush", "%g CE ₹%g → ₹%g and %g PE ₹%g → ₹%g in 15 min, price %+.1f%%" % (k, c0, c1, k, q0, q1, mv), k1=k)
    # the futures build-up (the engine's quadrant: price vs futures OI since yesterday)
    if fp:
        bu, cr_, oi_, chg = (fp.get("bu") or "").upper().replace("_", " "), abs(float(fp.get("cr") or 0)), float(fp.get("oi") or 0), float(fp.get("chg") or 0)
        if bu in FUT and cr_ >= 25 and abs(oi_) >= 2 and abs(chg) >= 0.5:
            pp = [x for x in (fp.get("pp") or []) if x is not None]
            brk = ""
            if len(pp) >= 3:
                brk = " · at a new day high" if pp[-1] >= max(pp[:-1]) else " · at a new day low" if pp[-1] <= min(pp[:-1]) else ""
            add(FUT[bu], "price %+.1f%%, futures OI %+.1f%% (₹%.0f cr)%s" % (chg, oi_, cr_, brk))
    return hits, exp


# ---------------------------------------------------------------- the store and the measured numbers
def tom_path(P=None):
    return (P or {}).get("tom") or os.path.join(BASE, "tomorrow.db")


def db(P=None):
    c = sqlite3.connect(tom_path(P), timeout=10)
    c.execute("create table if not exists scn_calls(day text, t text, sym text, scn text, side text, spot real, k1 real, k2 real, close real, src text, ch text, "
              "primary key(day, sym, scn, src))")
    return c


_SC = {"at": 0.0, "v": {}, "path": None}


def scores(P=None, fresh=False):
    """{scn: {"n", "right", "pct", "avg"}} over every call with a close (live + the chain15 backfill) - cached 60 s"""
    path = tom_path(P)
    if not fresh and _SC["path"] == path and time.time() - _SC["at"] < 60:
        return _SC["v"]
    out = {}
    try:
        c = db(P)
        for scn, side, spot, k1, k2, close in c.execute("select scn, side, spot, k1, k2, close from scn_calls where close is not null and spot > 0"):
            if scn not in C:
                continue
            ok, mv = claim_ok(C[scn]["claim"], side, spot, close, k1, k2)
            if ok is None:
                continue
            b = out.setdefault(scn, {"n": 0, "right": 0, "sum": 0.0})
            b["n"] += 1; b["right"] += int(ok); b["sum"] += mv or 0
        c.close()
    except Exception as ex:
        core_log("scenario scores: %s" % str(ex)[:80])
    for b in out.values():
        b["pct"] = int(round(100.0 * b["right"] / b["n"])) if b["n"] else 0
        b["avg"] = round(b["sum"] / b["n"], 2) if b["n"] else 0
    _SC.update({"at": time.time(), "v": out, "path": path})
    return out


def rule_word(s):
    """the house rule: BUY only when the rule measures 55%+ on 50+ cases; else WATCH"""
    if s and s.get("n", 0) >= 50 and s.get("pct", 0) >= 55:
        return "BUY", "rule measured: %d%% right of %d (same-day close, this server)" % (s["pct"], s["n"])
    if s and s.get("n"):
        return "WATCH", "rule measured: %d%% right of %d — not 55%% on 50+ yet, so WATCH" % (s["pct"], s["n"])
    return "WATCH", "rule measured: not yet (new rule) — WATCH until it has 50 cases"


def core_log(msg):
    print("%s %s" % (core.ist_now().strftime("%H:%M:%S"), msg), flush=True)


# ---------------------------------------------------------------- the agent inside the desk
class Agent(object):
    def __init__(self, desk, P=None, hooks=None, hold=HOLD_S):
        self.desk, self.P, self.hooks, self.hold = desk, P or {}, hooks or {}, hold
        self.log = self.hooks.get("log") or core_log
        self.day = None
        self.reset(None)
        self.cfg, self.cfg_at = {}, 0.0

    def reset(self, d):
        self.day = d
        self.ref_spot, self.seen, self.fired, self.cur, self.bu, self.today, self.mp = {}, {}, {}, {}, {}, [], {}
        self.pending, self.digest_at = [], 0.0

    def config(self):
        if time.time() - self.cfg_at > 120:
            self.cfg_at = time.time()
            cfg = {"box_when": "BUY", "off": set()}
            try:
                cfg.update(json.load(open(os.path.join(DATA, "scn_config.json"))) or {})
            except Exception:
                pass
            try:
                cfg["off"] = {x.strip() for x in open(os.path.join(DATA, "scenarios_off.txt")).read().split() if x.strip() and not x.startswith("#")}
            except Exception:
                cfg["off"] = set()
            self.cfg = cfg
        return self.cfg

    def read(self, sym, now, prev15, ref, spot, a, r, rd, ref_hm, expiry_week=False, tag="live"):
        """one share on one reading -> the scenarios holding now (the lane fires them after the hold)"""
        d = str((dt.datetime(1970, 1, 1) + dt.timedelta(seconds=rd.t + core.IST_OFF)).date())
        if self.day != d:
            self.reset(d)
        if rd.hm < ref_hm or not spot:
            self.cur[sym] = []
            return []
        if ref is not None and sym not in self.ref_spot:
            self.ref_spot[sym] = spot
        spots = (getattr(self.desk, "spots", {}) or {}).get(sym, [])
        spot15 = next((sp for t, sp in reversed(spots) if rd.t - t >= 14 * 60), None)
        fp = ((getattr(self.desk, "fut", None) and self.desk.fut.fp) or {}).get(sym) or {}
        normal = (getattr(getattr(self.desk, "strikes", None), "normal", {}) or {}).get(sym)
        hits, exp = detect(now, prev15, ref, spot, spot15, self.ref_spot.get(sym), fp, normal, ref_hm, rd.t, tag != "replay", self.mp.setdefault(sym, {}))
        # the futures turning: a build-up that held 30 min changes sides
        bu = (fp.get("bu") or "").upper().replace("_", " ")
        if bu in FUT:
            old = self.bu.get(sym)
            if old is None or old[0] != bu:
                if old and rd.t - old[1] >= 1800 and ((old[0] in FUT_UP) != (bu in FUT_UP)):
                    hits.append({"id": "fut_turn", "side": "CE" if bu in FUT_UP else "PE", "k1": None, "k2": None,
                                 "line": "the futures went from %s to %s (price %+.1f%%, futures OI %+.1f%%)" % (old[0].lower(), bu.lower(), float(fp.get("chg") or 0), float(fp.get("oi") or 0))})
                self.bu[sym] = (bu, rd.t)
        out = []
        ids = set()
        for h in hits:
            key = (sym, h["id"])
            ids.add(h["id"])
            s = self.seen.get(key)
            if s is None:
                s = self.seen[key] = [rd.t, rd.t]
            s[1] = rd.t
            h.update({"held": int(rd.t - s[0]), "fired": self.fired.get(key), "exp": exp, "expiry_week": expiry_week, "spot": spot})
            out.append(h)
        for key in [k for k in self.seen if k[0] == sym and k[1] not in ids]:
            if rd.t - self.seen[key][1] > 30:                  # gone for 30 s: the hold starts again
                self.seen.pop(key, None)
        self.cur[sym] = out
        return [{"id": h["id"], "name": C[h["id"]]["name"], "side": h["side"], "line": h["line"][:220], "held": h["held"], "fired": h["fired"]} for h in out]

    # -- the lane: hold -> gates -> words -> the channel
    def lane(self, rd, ses, ref_hm, send=True, hm_add=None):
        close_by = hm_add(ses["close"], -12) if hm_add else "15:18"
        if not (ref_hm <= rd.hm <= close_by):
            return []
        fired = []
        for sym, hits in list(self.cur.items()):
            for h in hits:
                key = (sym, h["id"])
                if key in self.fired or h["held"] < self.hold:
                    continue
                self.fired[key] = rd.hm
                try:
                    fired.append(self.fire(sym, h, rd, send))
                except Exception as ex:
                    self.log("scenario fire %s %s: %s" % (sym, h["id"], str(ex)[:100]))
        if send:
            self.digest(rd)
        return fired

    def digest(self, rd, force=False):
        """the reading lines go to GIR Intraday WITHOUT sound as one digest a minute at most (12 a message): nothing is
        muted, the phone is not flooded, and Telegram's rate limit is never hit"""
        if not self.pending or not (force or len(self.pending) >= 12 or rd.t - self.digest_at >= 60):
            return
        self.digest_at = rd.t
        while self.pending:
            chunk, self.pending = self.pending[:12], self.pending[12:]
            text = "🧩 OI SCENARIOS · %s · %d new (readings, not trades — tap the share on GIR for the numbers)\n%s" % (rd.hm, len(chunk), "\n".join(chunk))
            try:
                core.tg(text[:3900], silent=True)
            except Exception as ex:
                self.log("scenario digest: %s" % str(ex)[:80])

    def ticket(self, sym, side, spot):
        now = (getattr(self.desk, "last", None) and self.desk.last.ch.get(sym)) or {}
        c, _ = one_expiry(now, spot)
        tk = sorted([(k, x[1]) for (k, kd), x in c.items() if kd == side and x[1] >= MIN_P and x[0] >= MIN_OI and ((k >= spot) if side == "CE" else (k <= spot))],
                    key=lambda x: abs(x[0] - spot))
        return ("%g %s ₹%g" % (tk[0][0], side, tk[0][1])) if tk else None

    def fire(self, sym, h, rd, send):
        cat = C[h["id"]]
        side = h["side"] if h["side"] in ("CE", "PE") else None
        spot = h["spot"]
        r = (getattr(self.desk, "shares", {}) or {}).get(sym) or {}
        sc = scores(self.P).get(h["id"])
        word, meas = rule_word(sc)
        cfg = self.config()
        notes, ticket, stop, size = [], None, None, ""
        acting = bool(cat["acts"] and side)
        if acting:
            if sym in (getattr(self.desk, "ban", set()) or set()):
                notes.append("in the F&O ban list — no new positions")
            if h.get("expiry_week") and not h["id"].startswith("fut_"):
                notes.append("expiry week — rollover can fake an OI build-up")
            rv = r.get("v") or 0
            if rv and (rv > 0) != (side == "CE"):
                notes.append("the desk reads %s %+d — two readings disagree: WAIT" % (r.get("label") or "", rv))
            rs = ((getattr(self.desk, "rs", {}) or {}).get(sym)) or {}
            if rs.get("side") and (rs["side"] > 0) != (side == "CE"):
                notes.append("results out: the numbers say %s — the numbers decide" % ("UP" if rs["side"] > 0 else "DOWN"))
            w = r.get("walls") or {}
            roof, floor = w.get("roof"), w.get("floor")
            if side == "CE" and roof and roof.get("k") and spot < roof["k"] and (roof.get("away") or 9) < 2.0 and h["id"] not in ("call_short_covering", "bull_shift", "roof_up"):
                notes.append("the roof ₹%g is only %.1f%% above — no CE under a roof" % (roof["k"], roof["away"]))
            if side == "PE" and floor and floor.get("k") and spot > floor["k"] and (floor.get("away") or 9) < 2.0 and h["id"] not in ("put_short_covering", "bear_shift", "floor_down"):
                notes.append("the floor ₹%g is only %.1f%% below — no PE over a floor" % (floor["k"], floor["away"]))
            ticket = self.ticket(sym, side, spot)
            if not ticket:
                notes.append("no liquid strike (OI 20,000+ and ₹2+)")
            else:
                wl = floor if side == "CE" else roof
                stop = wl["k"] if (wl and (wl.get("away") or 9) <= 3) else round(spot * (0.985 if side == "CE" else 1.015), 1)
                size = (self.hooks.get("size") or (lambda s, t: ""))(sym, ticket)
        box = acting and not notes and (word == "BUY" or cfg.get("box_when") == "WATCH")
        ch = "box" if box else "read"
        if h["id"] in cfg.get("off", set()):
            ch = "page"
        chg = r.get("chg")
        arrow = "▲" if side == "CE" else "▼" if side == "PE" else "·"
        L1 = "🧩 %s %s %s ₹%g%s · %s" % (cat["name"], arrow, sym, round(spot, 2), (" %+.1f%%" % chg) if chg is not None else "", rd.hm)
        L2 = h["line"]
        L3 = "%s — %s" % (cat["what"], ("share price going %s → %s side · the desk: %s" % ("UP" if side == "CE" else "DOWN", side, ("%s %+d" % (r.get("label"), r.get("v"))) if r.get("v") else "no call")) if side else "a reading, not a trade")
        if acting and ticket and not notes:
            L4 = "▶ %s: %s · stop: a close %s %g%s%s" % (word, ticket, "under" if side == "CE" else "over", stop, (" · " + size) if size else "",
                                                        "" if box else " · on GIR Intraday until it measures 55% on 50+")
        elif acting:
            L4 = "WATCH — not a trade yet: " + " · ".join(notes)
        else:
            L4 = ""
        claim = CLAIM_TXT.get(cat["claim"] if cat["claim"] != "side" else ("up" if side == "CE" else "down"), "") % {"k1": h.get("k1") or 0, "k2": h.get("k2") or 0}
        L5 = "%s · scored on: %s" % (meas, claim)
        text = "\n".join(x for x in (L1, L2, L3, L4, L5) if x)
        if send:
            try:
                c = db(self.P)
                c.execute("insert or ignore into scn_calls(day,t,sym,scn,side,spot,k1,k2,src,ch) values(?,?,?,?,?,?,?,?,?,?)",
                          (self.day, rd.hm, sym, h["id"], side or "", spot, h.get("k1"), h.get("k2"), "live", ch))
                c.commit(); c.close()
            except Exception as ex:
                self.log("scn_calls: %s" % str(ex)[:80])
            if ch == "box":
                (self.hooks.get("tg_box") or (lambda *a, **k: False))(text, sym=sym, side=side or "")
            elif ch == "read":
                self.pending.append("%s %s %s — %s · %s" % (arrow, sym, cat["name"], L2[:150], ("%d%% of %d" % (sc["pct"], sc["n"])) if sc else "new"))
        self.log("SCENARIO %s %s %s -> %s%s" % (h["id"], sym, side or "-", ch, (" (" + "; ".join(notes) + ")") if notes else ""))
        row = {"t": rd.hm, "s": sym, "id": h["id"], "name": cat["name"], "side": side, "ch": ch, "word": word if acting and not notes else ("WAIT" if notes else "READ"), "line": L2[:200]}
        self.today.append(row)
        self.today = self.today[-400:]
        return row

    def alert_row(self, sym, side, text):
        """a reading-channel line on the home page's NOW list (Box Picks lines are logged by tg_box itself)"""
        try:
            now_ = core.ist_now()
            c = sqlite3.connect(tom_path(self.P), timeout=10)
            c.execute("create table if not exists alerts(day text, t text, kind text, sym text, side text, text text)")
            c.execute("insert into alerts(day,t,kind,sym,side,text) values(?,?,?,?,?,?)", (str(now_.date()), now_.strftime("%H:%M:%S"), "🧩", sym, side, text[:1500]))
            c.commit(); c.close()
        except Exception as ex:
            self.log("scenario alert log: %s" % str(ex)[:80])

    def fill(self, day, closes):
        """15:45: the day's close on every live call -> the measured numbers"""
        try:
            c = db(self.P)
            for sym, scn in c.execute("select sym, scn from scn_calls where day=? and close is null and src='live'", (day,)).fetchall():
                if closes.get(sym):
                    c.execute("update scn_calls set close=? where day=? and sym=? and scn=? and src='live'", (closes[sym], day, sym, scn))
            c.commit(); c.close()
            scores(self.P, fresh=True)
        except Exception as ex:
            self.log("scenario fill: %s" % str(ex)[:80])

    def audit_line(self, day):
        try:
            c = db(self.P)
            rows = c.execute("select scn, side, spot, k1, k2, close from scn_calls where day=? and src='live' and close is not null", (day,)).fetchall(); c.close()
        except Exception:
            rows = []
        if not rows:
            return "🧩 OI SCENARIOS %s: no scenario fired" % day
        by = {}
        for scn, side, spot, k1, k2, close in rows:
            ok, _ = claim_ok(C[scn]["claim"], side, spot, close, k1, k2) if scn in C else (None, None)
            if ok is None:
                continue
            b = by.setdefault(scn, [0, 0]); b[0] += 1; b[1] += int(ok)
        n, rt = sum(b[0] for b in by.values()), sum(b[1] for b in by.values())
        return "🧩 OI SCENARIOS %s: %d of %d right · %s" % (day, rt, n, " · ".join("%s %d/%d" % (C[k]["name"].lower(), v[1], v[0]) for k, v in sorted(by.items(), key=lambda kv: -kv[1][0])[:8]))

    def state(self):
        sc = scores(self.P)
        cnt = {}
        for r in self.today:
            cnt[r["id"]] = cnt.get(r["id"], 0) + 1
        return {"today": self.today[-150:], "counts": cnt, "scores": {k: [v["pct"], v["n"]] for k, v in sc.items()},
                "cat": [{"id": c["id"], "name": c["name"], "side": c["side"], "acts": c["acts"]} for c in C.values()],
                "box_when": self.config().get("box_when"), "hold": self.hold}


# ---------------------------------------------------------------- the backfill: replay the server's own 15-minute readings
def day_readings(con, d):
    """chain15 of one day -> [(t, {sym: chain}, {sym: spot})] in time order"""
    by = {}
    for t, sym, exp, k, kd, oi, ltp, spot in con.execute("select t, sym, exp, strike, kind, oi, ltp, spot from chain15 where d=? order by t", (d,)):
        b = by.setdefault(t, ({}, {}))
        b[0].setdefault(sym, {})[(exp, float(k), kd)] = (float(oi or 0), float(ltp or 0), 0)
        if spot:
            b[1][sym] = float(spot)
    return [(t, by[t][0], by[t][1]) for t in sorted(by)]


def replay_day(con, d, normals=None, ref_t="09:45", last_t="15:00"):
    """every scenario that would have fired on day d (hold 0: the 15-min readings are already 15 min apart)"""
    rs = day_readings(con, d)
    if not rs:
        return [], {}
    closes = {}
    for t, chs, sp in rs:
        closes.update({k: round(v, 2) for k, v in sp.items()})
    ref, ref_spot, prev, prev_spot, fired, out = {}, {}, {}, {}, set(), []
    for t, chs, sp in rs:
        for sym, ch in chs.items():
            spot = sp.get(sym)
            if not spot:
                continue
            if t >= ref_t and sym not in ref:
                ref[sym], ref_spot[sym] = ch, spot
                prev[sym], prev_spot[sym] = ch, spot
                continue
            if t < ref_t or t > last_t or t >= rs[-1][0] or sym not in ref:
                prev[sym], prev_spot[sym] = ch, spot
                continue
            exps = sorted({e for (e, k, kd) in ch})
            ew = bool(exps) and (dt.date.fromisoformat(str(exps[0])[:10]) - dt.date.fromisoformat(d)).days <= 2
            hits, exp = detect(ch, prev.get(sym), ref[sym], spot, prev_spot.get(sym), ref_spot[sym], None, (normals or {}).get(sym), ref_t, None, False)
            for h in hits:
                if (sym, h["id"]) in fired:
                    continue
                fired.add((sym, h["id"]))
                out.append({"day": d, "t": t, "sym": sym, "scn": h["id"], "side": h["side"] if h["side"] in ("CE", "PE") else "", "spot": round(spot, 2), "k1": h.get("k1"), "k2": h.get("k2"),
                            "close": closes.get(sym), "line": h["line"], "ew": ew})
            prev[sym], prev_spot[sym] = ch, spot
    return out, closes


def backfill(days=None, P=None, quiet=False):
    con = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=10)
    today = str(core.ist_now().date())
    ds = [r[0] for r in con.execute("select distinct d from chain15 where d < ? order by d", (today,))]
    if days:
        ds = ds[-int(days):]
    try:
        import desk
        normals = desk.normal_oi()
    except Exception:
        normals = {}
    c = db(P)
    n_all, per_day = 0, {}
    for d in ds:
        out, closes = replay_day(con, d, normals)
        rows = [(x["day"], x["t"], x["sym"], x["scn"], x["side"], x["spot"], x["k1"], x["k2"], x["close"], "replay", "acts" if C[x["scn"]]["acts"] else "read") for x in out]
        c.executemany("insert or ignore into scn_calls(day,t,sym,scn,side,spot,k1,k2,close,src,ch) values(?,?,?,?,?,?,?,?,?,?,?)", rows)
        c.commit()
        per_day[d] = (len(out), sum(1 for x in out if C[x["scn"]]["acts"]))
        n_all += len(out)
        if not quiet:
            print("  %s: %d scenario fires on %d shares (%d acting kind)" % (d, len(out), len({x["sym"] for x in out}), per_day[d][1]))
    c.close(); con.close()
    scores(P, fresh=True)
    return ds, n_all, per_day


def table(P=None):
    sc = scores(P, fresh=True)
    lines = ["%-32s %-5s %-6s %s" % ("SCENARIO", "SIDE", "KIND", "MEASURED (same-day close, this server)")]
    for c in C.values():
        s = sc.get(c["id"])
        w, _ = rule_word(s)
        if not c["acts"]:
            w = "proven" if w == "BUY" else "not proven yet"
        lines.append("%-32s %-5s %-6s %s" % (c["name"][:32], c["side"] if c["side"] in ("CE", "PE") else ("dyn" if c["side"] == "dyn" else "—"), "acts" if c["acts"] else "read",
                                            ("%3d%% right of %4d · avg %+.2f%% · %s" % (s["pct"], s["n"], s["avg"], w)) if s else "not measured yet · WATCH"))
    return "\n".join(lines)


# ---------------------------------------------------------------- the self-test
def selftest():
    ok = True

    def check(name, good):
        nonlocal ok
        print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)

    E = "2026-11-25"
    sp = 1000.0

    def mk(rows):
        return {(E, float(k), kd): (float(oi), float(p), 0) for k, kd, oi, p in rows}
    base = [(960, "PE", 120000, 8), (980, "PE", 150000, 12), (1000, "PE", 200000, 20), (1020, "PE", 60000, 30), (1040, "PE", 40000, 45),
            (960, "CE", 30000, 48), (980, "CE", 60000, 32), (1000, "CE", 180000, 20), (1020, "CE", 220000, 12), (1040, "CE", 260000, 7)]
    B = mk(base)

    def chg(changes):
        d = dict(B)
        for (k, kd), (oi, p) in changes.items():
            d[(E, float(k), kd)] = (float(oi), float(p), 0)
        return d

    def ids(now, prev=B, ref=B, spot=sp, spot15=sp, ref_spot=sp, fp=None):
        h, _ = detect(now, prev, ref, spot, spot15, ref_spot, fp, None, "09:45", None, False)
        return {x["id"]: x for x in h}
    print("1. the four boxes on calls and puts")
    check("calls BOUGHT at 1020 -> CALLS BOUGHT", "calls_bought" in ids(chg({(1020, "CE"): (400000, 15)})))
    check("calls WRITTEN at 1020 -> SELLERS BUILDING A ROOF", "call_writing" in ids(chg({(1020, "CE"): (420000, 9)})))
    check("call writers buying back at 1020 -> CALL WRITERS RUNNING", "call_short_covering" in ids(chg({(1020, "CE"): (110000, 16)})))
    check("call buyers closing at 1040 -> CALL BUYERS LEAVING", "call_unwinding" in ids(chg({(1040, "CE"): (130000, 5)})))
    check("puts BOUGHT at 980 -> PUTS BOUGHT", "puts_bought" in ids(chg({(980, "PE"): (330000, 16)})))
    check("puts WRITTEN at 980 -> SELLERS BUILDING A FLOOR", "put_writing" in ids(chg({(980, "PE"): (330000, 9)})))
    check("put writers buying back at 1000 -> PUT WRITERS RUNNING", "put_short_covering" in ids(chg({(1000, "PE"): (100000, 26)})))
    check("put buyers closing at 960 -> PUT BUYERS LEAVING", "put_unwinding" in ids(chg({(960, "PE"): (55000, 6)})))
    check("a small change is not a build-up", not ids(chg({(1020, "CE"): (230000, 12.5)})))
    thin_now, thin_prev = dict(B), dict(B)
    thin_now[(E, 1060.0, "CE")] = (30000.0, 1.9, 0); thin_prev[(E, 1060.0, "CE")] = (8000.0, 1.2, 0)
    check("an illiquid strike (OI 8,000 -> 30,000 at ₹1.2 -> ₹1.9) is ignored", not ids(thin_now, thin_prev))
    print("2. the combinations")
    check("puts written under + call writers running above -> FLOOR BUILDING, ROOF LEAVING", "bull_shift" in ids(chg({(980, "PE"): (330000, 9), (1020, "CE"): (110000, 16)})))
    check("calls written above + put writers running below -> ROOF BUILDING, FLOOR LEAVING", "bear_shift" in ids(chg({(1020, "CE"): (420000, 9), (1000, "PE"): (100000, 26)})))
    h = ids(chg({(1020, "CE"): (420000, 9), (980, "PE"): (330000, 9)}), prev=None)
    check("calls written above + puts written below, price flat -> SELLERS BOX IT IN (980–1020)", "range_writing" in h and h["range_writing"]["k1"] == 1020 and h["range_writing"]["k2"] == 980)
    h = ids(chg({(1020, "CE"): (420000, 9)}), prev=None, spot=1012, ref_spot=1000)
    check("share +1.2%, calls written just above, no put writing -> THE RISE IS NOT TRUSTED", "rise_not_trusted" in h)
    h = ids(chg({(980, "PE"): (330000, 9)}), prev=None, spot=988, ref_spot=1000)
    check("share -1.2%, puts written just below, no call writing -> THE FALL IS NOT TRUSTED", "fall_not_trusted" in h)
    print("3. the walls, PCR, max pain, the premiums")
    h = ids(chg({(980, "PE"): (150000, 12), (1000, "PE"): (420000, 18)}), prev=None, spot=1004, ref_spot=1004)
    check("the biggest put wall 1000 -> stays (no shift)", "floor_up" not in h)
    ref_f = chg({(980, "PE"): (300000, 12)})
    h = ids(chg({(980, "PE"): (300000, 12), (1000, "PE"): (420000, 18)}), prev=None, ref=ref_f, spot=1004, ref_spot=1004)
    check("the floor 980 -> 1000 -> THE FLOOR MOVED UP", "floor_up" in h and h["floor_up"]["k1"] == 1000)
    ref_r = chg({(1040, "CE"): (500000, 7)})
    h = ids(chg({(1040, "CE"): (500000, 7), (1020, "CE"): (620000, 12)}), prev=None, ref=ref_r)
    check("the roof 1040 -> 1020 -> THE ROOF MOVED DOWN", "roof_down" in h)
    h = ids(chg({(980, "PE"): (450000, 12), (1000, "PE"): (420000, 20), (960, "PE"): (300000, 8)}), prev=None)
    check("puts added fast near the price -> PUTS ADDED FASTER (PCR up)", "pcr_up" in h)
    h = ids(chg({(1000, "CE"): (180000, 23), (1000, "PE"): (200000, 23)}), spot15=1000)
    check("ATM CE and PE both +15% with the price flat -> BOTH SIDES PUMPED", "iv_pump" in h)
    h = ids(chg({(1000, "CE"): (180000, 17), (1000, "PE"): (200000, 17)}), spot15=1000)
    check("ATM CE and PE both -15% with the price flat -> BOTH SIDES CRUSHED", "iv_crush" in h)
    print("4. the futures build-up")
    for bu, id_ in (("LONG BUILD-UP", "fut_long_buildup"), ("SHORT BUILD-UP", "fut_short_buildup"), ("SHORT COVERING", "fut_short_covering"), ("LONG UNWINDING", "fut_long_unwinding")):
        h = ids(B, fp={"bu": bu, "cr": 60, "oi": 4.0 if "BUILD" in bu else -4.0, "chg": 1.2 if bu in FUT_UP else -1.2, "pp": [0.1, 0.5, 1.2]})
        check("%s ₹60 cr -> %s" % (bu.lower(), C[id_]["name"]), id_ in h)
    check("a ₹8 cr build-up is too small", not ids(B, fp={"bu": "LONG BUILD-UP", "cr": 8, "oi": 3.0, "chg": 1.0}))
    print("5. the claims the audit scores")
    check("up: 1000 -> 1012 right", claim_ok("up", "CE", 1000, 1012)[0] is True)
    check("below 1020: close 1015 right, 1025 wrong", claim_ok("below", "", 1000, 1015, 1020)[0] and not claim_ok("below", "", 1000, 1025, 1020)[0])
    check("range 980-1020: close 1003 right", claim_ok("range", "", 1000, 1003, 1020, 980)[0] is True)
    check("big: a 2% move right, a 0.4% move wrong", claim_ok("big", "", 1000, 1020)[0] and not claim_ok("big", "", 1000, 1004)[0])
    print("6. the agent: hold, gates, channel, store (a temporary database)")
    import tempfile
    tmp = tempfile.mkdtemp(prefix="scntest")
    P = {"tom": os.path.join(tmp, "tomorrow.db")}

    class R(object):
        def __init__(self, t, hm, ch, spot):
            self.t, self.hm, self.ch, self.spot = t, hm, ch, spot

    class FakeDesk(object):
        def __init__(self):
            self.spots, self.ban, self.rs, self.shares, self.last = {}, set(), {}, {}, None

            class F(object):
                fp = {}
            self.fut = F()
    sent = []
    fd = FakeDesk()
    ag = Agent(fd, P, {"tg_box": lambda text, sym=None, side=None: sent.append((sym, side, text)), "size": lambda s, t: "size: 1 lot", "log": lambda m: None}, hold=60)
    real_tg = core.tg
    core.tg = lambda text, silent=None: sent.append(("intraday", silent, text))
    now_ch = chg({(980, "PE"): (330000, 9), (1020, "CE"): (110000, 16)})
    T0 = int(core.ist_epoch(dt.datetime(2026, 11, 10, 10, 30)))
    ses = {"open": "09:15", "close": "15:30"}
    for i, t in enumerate(range(T0, T0 + 61, 5)):
        rd = R(t, "10:30", {"ABC": now_ch}, {"ABC": sp}); fd.last = rd
        fd.shares = {"ABC": {"v": 1, "label": "BULLISH", "chg": 0.8, "walls": {"roof": {"k": 1040, "away": 4.0}, "floor": {"k": 980, "away": 2.0}}}}
        ag.read("ABC", now_ch, B, B, sp, {}, fd.shares["ABC"], rd, "09:45", False, "live")
        fired = ag.lane(rd, ses, "09:45", send=True)
        if t < T0 + 60:
            check("held %d s: nothing fired yet" % (t - T0), not fired) if i in (0, 6) else None
    check("after 60 s the scenarios fire once", any(r["id"] == "bull_shift" for r in ag.today) and len([r for r in ag.today if r["id"] == "bull_shift"]) == 1)
    rd = R(T0 + 70, "10:31", {"ABC": now_ch}, {"ABC": sp})
    ag.read("ABC", now_ch, B, B, sp, {}, fd.shares["ABC"], rd, "09:45", False, "live"); ag.lane(rd, ses, "09:45", send=True)
    check("and not again the same day", len([r for r in ag.today if r["id"] == "bull_shift"]) == 1)
    bs = [r for r in ag.today if r["id"] == "bull_shift"][0]
    check("a new rule goes to GIR Intraday without sound (WATCH until 55%% on 50+): %s" % bs["ch"], bs["ch"] == "read")
    check("the line reached GIR Intraday silently, in a digest", any(x[0] == "intraday" and x[1] is True and x[2].startswith("🧩 OI SCENARIOS") and "FLOOR BUILDING" in x[2] for x in sent))
    c = sqlite3.connect(P["tom"])
    nrow = c.execute("select count(*) from scn_calls where src='live'").fetchone()[0]
    c.close()
    check("every fire stored for the audit (%d) and on the panel (%d)" % (nrow, len(ag.today)), nrow >= 2 and nrow == len(ag.today))
    # a measured rule: 60 right of 80 -> BUY -> Box Picks
    c = db(P)
    c.executemany("insert or ignore into scn_calls(day,t,sym,scn,side,spot,close,src) values(?,?,?,?,?,?,?,?)",
                  [("2026-11-0%d" % (1 + i // 20), "10:00", "S%d" % i, "calls_bought", "CE", 100, 101 if i < 60 else 99, "replay") for i in range(80)])
    c.commit(); c.close(); scores(P, fresh=True)
    fd.shares = {"XYZ": {"v": 1, "label": "BULLISH", "chg": 1.1, "walls": {"roof": {"k": 1060, "away": 6}, "floor": {"k": 980, "away": 2}}}}
    xch = chg({(1020, "CE"): (400000, 15)})
    for t in range(T0 + 100, T0 + 170, 5):
        rd = R(t, "10:32", {"XYZ": xch}, {"XYZ": sp}); fd.last = rd
        ag.read("XYZ", xch, B, B, sp, {}, fd.shares["XYZ"], rd, "09:45", False, "live"); ag.lane(rd, ses, "09:45", send=True)
    cb = [r for r in ag.today if r["id"] == "calls_bought" and r["s"] == "XYZ"]
    check("a rule measured 75%% of 80 -> BUY -> GIR Box Picks with the ticket: %s" % (cb[0]["ch"] if cb else None), cb and cb[0]["ch"] == "box" and cb[0]["word"] == "BUY")
    bx = [x for x in sent if x[0] == "XYZ"]
    check("the Box Picks line has the side, a ticket, a stop, the size and the number", bx and "→ CE" in bx[0][2] and "▶ BUY:" in bx[0][2] and "stop: a close under" in bx[0][2] and "size:" in bx[0][2] and "75% right of 80" in bx[0][2])
    # the gates: the desk reads the other way -> WAIT on the reading channel
    fd.shares = {"QQQ": {"v": -2, "label": "EXTREME BEARISH", "chg": -0.5, "walls": {}}}
    for t in range(T0 + 200, T0 + 270, 5):
        rd = R(t, "10:34", {"QQQ": xch}, {"QQQ": sp}); fd.last = rd
        ag.read("QQQ", xch, B, B, sp, {}, fd.shares["QQQ"], rd, "09:45", False, "live"); ag.lane(rd, ses, "09:45", send=True)
    q = [r for r in ag.today if r["id"] == "calls_bought" and r["s"] == "QQQ"]
    check("the desk reads the other way -> WAIT, not Box Picks", q and q[0]["ch"] == "read" and q[0]["word"] == "WAIT")
    fd.ban = {"BBB"}; fd.shares = {"BBB": {"v": 1, "label": "BULLISH", "walls": {}}}
    for t in range(T0 + 300, T0 + 370, 5):
        rd = R(t, "10:36", {"BBB": xch}, {"BBB": sp}); fd.last = rd
        ag.read("BBB", xch, B, B, sp, {}, fd.shares["BBB"], rd, "09:45", False, "live"); ag.lane(rd, ses, "09:45", send=True)
    b = [r for r in ag.today if r["s"] == "BBB" and r["id"] == "calls_bought"]
    check("a banned share -> not Box Picks", b and b[0]["ch"] == "read")
    rd = R(T0 - 3600, "09:35", {"EEE": xch}, {"EEE": sp})
    check("before 09:45 (open+30) nothing is read", ag.read("EEE", xch, B, B, sp, {}, {}, rd, "09:45", False, "live") == [])
    ag.fill("2026-11-10", {"ABC": 1012.0, "XYZ": 1015.0, "QQQ": 990.0, "BBB": 1001.0})
    line = ag.audit_line("2026-11-10")
    check("the 15:45 audit scores today's fires: %s" % line[:90], "right" in line)
    st = ag.state()
    check("the page's state: today's fires, counts, scores, the catalogue of %d" % len(st["cat"]), st["today"] and st["counts"] and len(st["cat"]) == len(CAT))
    core.tg = real_tg
    print("\nSCENARIO SELF-TEST %s" % ("PASSED" if ok else "FAILED"))
    return ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--test"]:
        sys.exit(0 if selftest() else 1)
    if a[:1] == ["--list"]:
        for c in C.values():
            print("%-22s %-32s %-4s %-5s %s" % (c["id"], c["name"], c["side"] or "—", "acts" if c["acts"] else "read", c["what"]))
        sys.exit(0)
    if a[:1] == ["--backfill"]:
        ds, n, per = backfill(a[1] if len(a) > 1 else None)
        print("backfill: %d days, %d scenario fires (%.1f a day across every F&O share)" % (len(ds), n, n / max(1, len(ds))))
        print(table()); sys.exit(0)
    if a[:1] == ["--replay"] and len(a) > 1:
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=10)
        try:
            import desk
            nm = desk.normal_oi()
        except Exception:
            nm = {}
        out, closes = replay_day(con, a[1], nm)
        for x in out:
            ok_, mv = claim_ok(C[x["scn"]]["claim"], x["side"], x["spot"], x["close"], x["k1"], x["k2"])
            print("%s %-11s %-30s %-3s ₹%-9g close ₹%-9s %s\n      %s" % (x["t"], x["sym"], C[x["scn"]]["name"], x["side"] or "—", x["spot"], x["close"], "✅" if ok_ else "❌" if ok_ is False else "·", x["line"][:200]))
        print("%d fires on %s" % (len(out), a[1])); sys.exit(0)
    if a[:1] == ["--scores"]:
        print(table()); sys.exit(0)
    print(__doc__)
PY_SCN
cat > $W/p84_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p84_patch.py - PATCH 84: the OI SCENARIO agent (scenarios.py) inside THE DESK, on the page and on Telegram.
desk.py: the agent reads every share on every 5-s reading, the lane fires after the 60-s hold, the 15:45 audit scores it,
its state goes to data/desk.json; tg_box takes the share and the side for the NOW list.
dashserve.py: the scenarios in /home, /focus and the push stream; the tape's OI column names the share's latest scenario.
Usage: python3 p84_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ desk.py
E("desk.py", '''        self.rs, self.rs_at = {}, 0.0                            # exchange.results_map, refreshed once a minute
''', '''        self.rs, self.rs_at = {}, 0.0                            # exchange.results_map, refreshed once a minute
        import scenarios                                         # THE OI SCENARIO agent (patch 84)
        self.scn = scenarios.Agent(self, P, {"tg_box": tg_box, "size": self.size_line, "log": log})
''')
E("desk.py", '''        a["reader"] = self.reader.read(sym)
        return self.audit(sym, spot, a, rd, ref_hm)''', '''        a["reader"] = self.reader.read(sym)
        r = self.audit(sym, spot, a, rd, ref_hm)
        try:
            r["scn"] = self.scn.read(sym, now, prev15, ref, spot, a, r, rd, ref_hm, expiry_week, tag)
        except Exception as ex:
            log("scenarios %s: %s" % (sym, str(ex)[:100])); r["scn"] = []
        return r''')
E("desk.py", '''        self.your_rules(rd, ses, ref_hm, send=(tag == "live"))
''', '''        self.your_rules(rd, ses, ref_hm, send=(tag == "live"))
        try:
            self.scn.lane(rd, ses, ref_hm, send=(tag == "live"), hm_add=hm_add)
        except Exception as ex:
            log("scenario lane: %s" % str(ex)[:100])
''')
E("desk.py", '''"walls", "news", "size")} for s, r in self.shares.items()},''', '''"walls", "news", "size", "scn")} for s, r in self.shares.items()},''')
E("desk.py", '''                "morning": self.morning_card(),''', '''                "morning": self.morning_card(), "scn": self.scn.state(),''')
E("desk.py", '''        except Exception:
            pass
        c = tom_db()
        for sym, sec, ag, side in c.execute("select sym, sector, agent, side from desk_calls where day=? and close is null", (day,)).fetchall():''', '''        except Exception:
            pass
        try:
            self.scn.fill(day, closes)                           # the OI scenarios of the day get the same close
        except Exception as ex:
            log("scenario close: %s" % str(ex)[:80])
        c = tom_db()
        for sym, sec, ag, side in c.execute("select sym, sector, agent, side from desk_calls where day=? and close is null", (day,)).fetchall():''')
E("desk.py", '''        self.audited = True
        return text, out''', '''        try:
            text += "\\n" + self.scn.audit_line(day)
        except Exception as ex:
            log("scenario audit: %s" % str(ex)[:80])
        self.audited = True
        return text, out''')
E("desk.py", '''def tg_box(text):
    """GIR Box Picks (TG_CHAT_BOX) - the acting channel; never NEWSHAWK's TG_CHAT_FO"""''', '''def tg_box(text, sym=None, side=None):
    """GIR Box Picks (TG_CHAT_BOX) - the acting channel; never NEWSHAWK's TG_CHAT_FO. sym / side: for the page's NOW list"""''')
E("desk.py", '''            sym_ = ((m.group(1) or m.group(2)) if m else "") or ""''', '''            sym_ = sym or ((m.group(1) or m.group(2)) if m else "") or ""''')
E("desk.py", '''                                                                                            "CE" if "→ CE" in t_ else "PE" if "→ PE" in t_ else "", (t_.rstrip() + mark)[:1500]))''',
  '''                                                                                            side or ("CE" if "→ CE" in t_ else "PE" if "→ PE" in t_ else ""), (t_.rstrip() + mark)[:1500]))''')

# ============================================================ dashserve.py
E("dashserve.py", '''    out["desk"] = {k: dk.get(k) for k in ("v", "label", "conf", "steps", "notes", "lines", "ticket", "stop", "line_k", "size", "t")} if dk else None''',
  '''    out["desk"] = {k: dk.get(k) for k in ("v", "label", "conf", "steps", "notes", "lines", "ticket", "stop", "line_k", "size", "t", "scn")} if dk else None''')
E("dashserve.py", '''"morning": (dk.get("morning") or {}).get("cue_lines"), "ban": dk.get("ban") or []}''',
  '''"morning": (dk.get("morning") or {}).get("cue_lines"), "ban": dk.get("ban") or [], "scn": dk.get("scn")}''')
E("dashserve.py", '''    tape = []
    chl = chain_lines()''', '''    tape = []
    scn_last = {}
    for x_ in ((dk.get("scn") or {}).get("today") or []):     # the share's latest OI scenario today leads its OI line
        scn_last[x_.get("s")] = x_
    chl = chain_lines()''')
E("dashserve.py", '''        oi = re.sub(r"OI [\\d.]+ L → [\\d.]+ L ", "", oi)
''', '''        oi = re.sub(r"OI [\\d.]+ L → [\\d.]+ L ", "", oi)
        if sym in scn_last:
            oi = "🧩 %s %s · %s" % (scn_last[sym]["t"], scn_last[sym]["name"].lower(), oi)
''')
E("dashserve.py", '''emit("secs", {"sectors": d.get("sectors"), "desk_t": d.get("desk_t"), "desk_src": d.get("desk_src")})''',
  '''emit("secs", {"sectors": d.get("sectors"), "desk_t": d.get("desk_t"), "desk_src": d.get("desk_src"), "scn": d.get("scn")})''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new) in enumerate(edits, 1):
            n = s.count(old)
            if n != 1:
                print("ANCHOR %s #%d found %d times (need 1): %r" % (f, i, n, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p84: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p84: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $W/home.html <<'HTML_P84'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>GIR</title>
<style>
:root{--bg:#000;--panel:#07090c;--line:#1a2230;--line2:#243040;--dim:#7d8b9c;--txt:#d6dee8;--hi:#ffffff;--amber:#ffb000;--amber2:#ffcc4d;--up:#1ed760;--dn:#ff3b4a;--wt:#ffb000;
--mono:"JetBrains Mono","SFMono-Regular",Menlo,Consolas,"Roboto Mono",monospace}
*{box-sizing:border-box;margin:0;padding:0}html{-webkit-text-size-adjust:100%}
body{background:var(--bg);color:var(--txt);font:13px/1.35 var(--mono);padding-bottom:34px}
a{color:inherit;text-decoration:none}
.pu{color:var(--up)}.pd{color:var(--dn)}.am{color:var(--amber)}.dim{color:var(--dim)}.hi{color:var(--hi)}
/* top: index strip + command line, always there */
#top{position:sticky;top:0;z-index:20;background:#000;border-bottom:1px solid var(--amber)}
#idx{display:flex;gap:0;align-items:stretch;overflow-x:auto;scrollbar-width:none;border-bottom:1px solid var(--line)}
#idx::-webkit-scrollbar{display:none}
#idx .brand{padding:6px 10px;color:#000;background:var(--amber);font-weight:700;letter-spacing:.08em;display:flex;align-items:center}
#idx .ix{padding:4px 10px;border-right:1px solid var(--line);white-space:nowrap;display:flex;flex-direction:column;justify-content:center;min-width:92px}
#idx .ix b{display:block;font-size:10px;letter-spacing:.08em;color:var(--dim);font-weight:400}
#idx .ix span{font-size:14px;color:var(--hi)}#idx .ix small{font-size:11px;margin-left:5px}
#idx .st{margin-left:auto;padding:4px 10px;white-space:nowrap;font-size:11px;color:var(--dim);display:flex;align-items:center;gap:8px}
#idx .st .live{color:var(--up)}#idx .st .closed{color:var(--dim)}
#cmd{display:flex;align-items:center;gap:6px;padding:5px 8px;background:#050607}
#cmd .pr{color:var(--amber);font-weight:700}
#cmd input{flex:1;min-width:0;background:#000;color:var(--amber2);border:1px solid var(--line2);padding:7px 10px;font:14px var(--mono);letter-spacing:.06em;text-transform:uppercase;outline:none}
#cmd input:focus{border-color:var(--amber)}
#cmd button{background:var(--amber);color:#000;border:0;font:700 12px var(--mono);padding:8px 12px;letter-spacing:.06em}
#cmd select{background:#000;color:var(--txt);border:1px solid var(--line2);font:12px var(--mono);padding:7px 6px;max-width:34vw}
#cmd .x{color:var(--amber);border:1px solid var(--line2);padding:7px 10px;display:none}
/* the grid of panels */
#grid{display:grid;grid-template-columns:1fr;gap:1px;background:var(--line)}
.p{background:var(--panel);min-width:0}
.p h2{font-size:11px;font-weight:700;letter-spacing:.1em;color:var(--amber);padding:6px 8px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:8px;text-transform:uppercase}
.p h2 small{font-weight:400;color:var(--dim);letter-spacing:0;text-transform:none;margin-left:auto;font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.empty{padding:14px 8px;color:var(--dim);font-size:12px}
#focus[hidden]{display:none}
@media(min-width:900px){body{font-size:12px}#grid{grid-template-columns:repeat(12,1fr);grid-auto-rows:min-content}
  #now{grid-column:1/5;grid-row:1/4;max-height:calc(100vh - 118px);overflow:auto}
  #focus{grid-column:5/13;grid-row:1}#three{grid-column:5/13;grid-row:2}#secs{grid-column:5/13;grid-row:3}
  #focus[hidden]~#three{grid-row:1}#focus[hidden]~#secs{grid-row:2}
  #tape{grid-column:1/9;grid-row:4;max-height:70vh;overflow:auto}#news{grid-column:9/13;grid-row:4;max-height:70vh;overflow:auto}
  #now .r{padding:4px 8px}#now .s{font-size:13px}#three .r{padding:4px 8px}#tape td{padding:3px 6px;font-size:11px}#news .r{padding:4px 8px;font-size:11px}}
@media(min-width:1100px){
  #now{grid-column:1/4;grid-row:1/4}#focus{grid-column:4/10;grid-row:1}#three{grid-column:10/13;grid-row:1/3}
  #focus:not([hidden])~#three{grid-column:10/13;grid-row:1/3}#focus[hidden]~#three{grid-column:4/13;grid-row:1}
  #secs{grid-column:4/10;grid-row:2}#focus[hidden]~#secs{grid-column:4/13;grid-row:2}#tape{grid-column:4/10;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:3;max-height:none}
  #secs .g{grid-template-columns:repeat(5,1fr)}#three .r{grid-template-columns:18px 1fr}#three .r>div:nth-child(3){display:none}}
@media(min-width:1500px){#secs .g{grid-template-columns:repeat(10,1fr)}}
/* NOW */
#now .r{display:grid;grid-template-columns:44px 1fr auto;gap:4px 8px;padding:6px 8px;border-bottom:1px solid var(--line);align-items:start}
#now .r.new{animation:flash 1.6s ease-out}
@keyframes flash{0%{background:rgba(255,176,0,.35)}100%{background:transparent}}
#now .t{color:var(--dim);font-size:11px;padding-top:2px}
#now .s{color:var(--hi);font-weight:700;font-size:14px}
#now .side{font-size:11px;font-weight:700;padding:1px 6px;border:1px solid;white-space:nowrap}
#now .side.up{color:var(--up);border-color:var(--up)}#now .side.dn{color:var(--dn);border-color:var(--dn)}#now .side.na{color:var(--dim);border-color:var(--line2)}
#now .h{grid-column:2/4;color:var(--txt)}
#now .l{grid-column:2/4;color:var(--dim);font-size:11px;white-space:pre-wrap}
#now .l .w{color:var(--wt)}#now .l .b{color:var(--up)}
/* THE THREE */
#three .r{display:grid;grid-template-columns:22px 1fr auto;gap:2px 8px;padding:6px 8px;border-bottom:1px solid var(--line)}
#three .rk{color:var(--amber);font-weight:700;font-size:16px}
#three .l1 b{color:var(--hi);font-size:14px}#three .l1 .sd{margin-left:6px;font-weight:700}
#three .vd{grid-column:2/4;font-size:12px}#three .vd.wt{color:var(--wt)}#three .vd.dn{color:var(--dim)}
#three .l2{grid-column:2/4;color:var(--dim);font-size:11px}#three .l2 em{font-style:normal;color:var(--txt)}
/* SECTORS: a heat grid */
#secs .g{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line)}
@media(min-width:600px){#secs .g{grid-template-columns:repeat(5,1fr)}}@media(min-width:900px){#secs .g{grid-template-columns:repeat(10,1fr)}}
#secs .c{background:var(--panel);padding:6px 6px 5px;min-height:62px;cursor:pointer;position:relative;overflow:hidden}
#secs .c.sel{outline:1px solid var(--amber)}
#secs .c .n{font-size:10px;letter-spacing:.06em;color:var(--txt);text-transform:uppercase;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .v{font-size:15px;font-weight:700;margin-top:1px}
#secs .c .tb{font-size:10px;color:var(--dim);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .pl{position:absolute;top:5px;right:5px;font-size:10px;font-weight:700}
/* TAPE: a dense table, still */
#tape table{width:100%;border-collapse:collapse;table-layout:fixed}
#tape th{font-size:10px;color:var(--dim);font-weight:400;text-align:left;padding:4px 6px;border-bottom:1px solid var(--line);letter-spacing:.06em;cursor:pointer;white-space:nowrap}
#tape th.on{color:var(--amber)}
#tape td{padding:4px 6px;border-bottom:1px solid var(--line);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:12px}
#tape tr{cursor:pointer}#tape tr:active{background:#111}
#tape .s{color:var(--hi);font-weight:700;width:92px}#tape .px{text-align:right;width:70px}#tape .ch{text-align:right;width:62px}#tape .m{width:52px}
#tape .m i{display:inline-block;width:9px;height:10px;margin-right:1px;background:var(--line2);vertical-align:middle}
#tape .m i.u{background:var(--up)}#tape .m i.d{background:var(--dn)}
#tape .oi{color:var(--dim);font-size:11px}
#tape td.fu{animation:fu 1.4s ease-out}#tape td.fd{animation:fd 1.4s ease-out}
@keyframes fu{0%{background:rgba(30,215,96,.45)}100%{background:transparent}}@keyframes fd{0%{background:rgba(255,59,74,.45)}100%{background:transparent}}
#idx .ix span.fu{color:var(--up)}#idx .ix span.fd{color:var(--dn)}
#tape .more{padding:6px 8px;color:var(--dim);font-size:11px;text-align:center;cursor:pointer}
/* NEWS */
#news .r{padding:5px 8px;border-bottom:1px solid var(--line);font-size:12px;display:grid;grid-template-columns:auto 1fr;gap:2px 8px}
#news .r .t{color:var(--dim);font-size:11px}#news .r b{color:var(--hi)}#news .r .h{grid-column:1/3;color:var(--txt)}
#news .r .w{grid-column:1/3;font-size:11px;color:var(--dim)}#news .sd{font-weight:700;margin-left:6px}
/* FOCUS */
#focus .hd{display:flex;align-items:baseline;gap:10px;padding:8px;border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .hd b{font-size:20px;color:var(--hi)}#focus .hd .px{font-size:16px}
#focus .m{padding:6px 8px;font-weight:700;border-bottom:1px solid var(--line)}
#focus svg{width:100%;height:150px;display:block;background:#000}
#focus .cap{padding:4px 8px;color:var(--dim);font-size:10px;border-bottom:1px solid var(--line)}
#focus .ag{padding:4px 8px;font-size:12px;border-bottom:1px solid var(--line)}#focus .ag b{color:var(--amber);text-transform:uppercase;font-size:10px;letter-spacing:.06em;margin-right:6px}
#focus .tk{padding:8px;background:#0c0a04;border-left:3px solid var(--amber);font-size:13px;color:var(--hi);white-space:pre-wrap}
#focus .nw{padding:6px 8px;font-size:12px;color:var(--txt)}#focus .nw em{font-style:normal;color:var(--dim)}
@media(max-width:899px){#focus.sheet{position:fixed;inset:0;z-index:30;overflow:auto;background:var(--panel);padding-bottom:40px}}

/* FOCUS v2: the share's own window */
#focus .tabs{display:flex;gap:1px;background:var(--line);border-bottom:1px solid var(--line)}
#focus .tabs span{flex:1;text-align:center;padding:5px 4px;font-size:10px;letter-spacing:.08em;color:var(--dim);background:var(--panel);cursor:pointer;text-transform:uppercase}
#focus .tabs span.on{color:var(--amber);border-bottom:2px solid var(--amber)}
#focus .sub{display:flex;gap:10px;padding:4px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .sub b{color:var(--txt);font-weight:400}
#focus svg.px{width:100%;height:230px;display:block;background:#000}
#focus svg.oit{width:100%;height:110px;display:block;background:#000}
#focus table.oi{width:100%;border-collapse:collapse;table-layout:fixed;font-size:11px}
#focus table.oi th{font-size:9px;color:var(--dim);font-weight:400;padding:3px 4px;border-bottom:1px solid var(--line);letter-spacing:.06em;text-align:right}
#focus table.oi th.k{text-align:center}#focus table.oi th.l{text-align:left}
#focus table.oi td{padding:3px 4px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap;position:relative;overflow:hidden}
#focus table.oi td.k{text-align:center;color:var(--hi);font-weight:700;background:#0b0e13}
#focus table.oi td.l{text-align:left}
#focus table.oi tr.atm td.k{color:var(--amber);outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi tr.wall td.k::after{content:" ▪";color:var(--amber)}
#focus table.oi td i{position:absolute;top:0;bottom:0;opacity:.22;z-index:0}
#focus table.oi td.ce i{right:0;background:var(--dn)}#focus table.oi td.pe i{left:0;background:var(--up)}
#focus table.oi td span{position:relative;z-index:1}
#focus table.oi td.d.up span{color:var(--up)}#focus table.oi td.d.dn span{color:var(--dn)}
#focus table.oi tr.tot td{color:var(--hi);border-top:1px solid var(--line2);font-weight:700}
#focus .legend{padding:3px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line)}
#focus .legend i{display:inline-block;width:9px;height:9px;vertical-align:middle;margin:0 3px 0 8px}
@media(min-width:1100px){#focus svg.px{height:260px}}

/* OI SCENARIOS (patch 84) */
#scn .r{display:grid;grid-template-columns:1fr auto auto;gap:2px 8px;padding:5px 8px;border-bottom:1px solid var(--line);align-items:baseline}
#scn .nm{color:var(--hi);font-weight:700;font-size:12px}#scn .nm .sd{font-size:10px;margin-left:6px;font-weight:400}
#scn .n{color:var(--amber);font-weight:700}#scn .ms{color:var(--dim);font-size:10px;text-align:right;white-space:nowrap}#scn .ms b{color:var(--up)}
#scn .sy{grid-column:1/4;font-size:11px;color:var(--dim);line-height:1.6}#scn .sy a{color:var(--txt);margin-right:10px;cursor:pointer;white-space:nowrap}#scn .sy a.box{color:var(--up)}
#scn .ft{padding:5px 8px;color:var(--dim);font-size:10px;line-height:1.5}
#focus .rib{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line);background:#0a0c10}#focus .rib b{color:var(--amber)}
#focus .scl{border-bottom:1px solid var(--line2)}#focus .scl div{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line)}#focus .scl .dim{font-size:10px}
@media(min-width:900px){#scn{grid-column:9/13;grid-row:4;max-height:45vh;overflow:auto}#news{grid-row:5}#tape{grid-row:4/6}}
@media(min-width:1100px){#scn{grid-column:10/13;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:4}#tape{grid-row:3/5}}
/* the news ticker at the bottom */
#tick{position:fixed;left:0;right:0;bottom:0;height:30px;background:#000;border-top:1px solid var(--amber);display:flex;align-items:center;overflow:hidden;z-index:15}
#tick .lb{background:var(--amber);color:#000;font-weight:700;font-size:11px;padding:0 8px;height:100%;display:flex;align-items:center;letter-spacing:.08em;flex:none}
#tick .run{white-space:nowrap;will-change:transform;font-size:12px;padding-left:12px}
#tick .run b{color:var(--hi)}#tick .run em{font-style:normal;color:var(--dim);margin:0 10px 0 0}
</style></head><body>
<div id="top">
  <div id="idx"></div>
  <div id="cmd"><span class="pr">&gt;</span><input id="q" placeholder="TICKER  ·  type a share, Enter = FOCUS" autocomplete="off" autocapitalize="characters"><button id="go">GO</button><select id="secsel"><option value="">ALL SECTORS</option></select><a class="x" id="unf" onclick="unfocus()">✕ ALL</a></div>
</div>
<div id="grid">
  <section class="p" id="now"><h2>NOW <small id="hnow">moving right now · newest first · every line went to Telegram the same second</small></h2><div id="nowl"></div></section>
  <section class="p" id="focus" hidden></section>
  <section class="p" id="three"><h2 id="h3">THE THREE</h2><div id="threel"></div></section>
  <section class="p" id="scn"><h2>OI SCENARIOS <small id="scnh">how the money is building up · today</small></h2><div id="scnl"><div class="empty">the scenario agent reads from 09:45 (open + 30)</div></div></section>
  <section class="p" id="secs"><h2>SECTORS <small>tap a sector to filter the tape · ++ EXTREME · + plain · ✓ confirmed</small></h2><div class="g" id="secg"></div></section>
  <section class="p" id="tape"><h2>F&amp;O TAPE <small id="tfoot"></small></h2><div id="tapel"></div></section>
  <section class="p" id="news"><h2>NEWS <small>filings + headlines · the reader's verdict</small></h2><div id="newsl"></div></section>
</div>
<div id="tick"><div class="lb">NEWS</div><div class="run" id="run"></div></div>
<script>
const K=new URLSearchParams(location.search).get("k")||""; const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const pc=v=>v==null?"":(v>=0?"+":"")+Number(v).toFixed(2)+"%"; const cls=v=>v==null?"dim":v>0.05?"pu":v<-0.05?"pd":"dim";
const inr=v=>v==null?"":Number(v).toLocaleString("en-IN",{maximumFractionDigits:2});
let D=null, T3=null, FD=null, FOC="", SEL="", SECS=[], TAPE=[], seen=new Set(), first=true, sortBy="move", showAll=false, LASTIX={};
/* ---------- the index strip ---------- */
function idxHTML(d){ const I=d.idx||{}; const one=(n,x)=>{ if(!x) return ""; const o=LASTIX[n]; const f=(o!=null&&x.last!=null&&x.last!==o)?(x.last>o?" fu":" fd"):""; LASTIX[n]=x.last; return `<div class="ix"><b>${n}</b><div><span class="${f.trim()}">${x.last!=null?inr(x.last):"—"}</span><small class="${cls(x.chg)}">${pc(x.chg)}</small></div></div>`; };
  const deskLive=d.closed&&d.desk_t&&ageMin(d.desk_t)<3; const st=d.closed?(deskLive?`<span class="live">● DESK LIVE ${esc(d.desk_t)} (${esc(d.desk_src||"own pull")})</span>`:'<span class="closed">● CLOSED</span>'):'<span class="live">● LIVE</span>';
  return `<div class="brand">GIR</div>${one("NIFTY",I.NIFTY)}${one("SENSEX",I.SENSEX)}${one("BANKNIFTY",I.BANKNIFTY)}${one("VIX",I.VIX)}<div class="st"><span id="clk">${istClock()}</span>${st}${d.ticks_s?`<span>${Math.round(d.ticks_s)} t/s</span>`:""}<span>${(d.now||[]).length} moving</span><span id="ago"></span>${d.ban&&d.ban.length?`<span class="pd">BAN ${esc(d.ban.join(" "))}</span>`:""}</div>`; }
function istClock(){ const t=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); return t.toTimeString().slice(0,8); }
function ageMin(hm){ const n=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const [h,m]=String(hm).split(":").map(Number); return (n.getHours()*60+n.getMinutes())-(h*60+m); }
let lastAt=0; setInterval(()=>{ const c=$("clk"); if(c) c.textContent=istClock(); const a=$("ago"); if(a&&lastAt) a.textContent=`upd ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s`; },1000);
/* ---------- NOW ---------- */
function nowHTML(rows){ if(!rows.length) return '<div class="empty">nothing has moved yet — the first lines come at 09:30 (FIRST MOVE) and 09:45 (the desk)</div>';
  return rows.slice(0,40).map(r=>{ const key=r.t+r.head; const isNew=!first&&!seen.has(key); seen.add(key); const sd=r.side==="CE"?"up":r.side==="PE"?"dn":"na";
    const head=(r.head||"").replace(/^(\S+\s+)/,""); const lines=(r.lines||[]).slice(0,3).map(l=>esc(l).replace(/\b(WATCH)\b/g,'<span class="w">$1</span>').replace(/\b(BUY)\b/g,'<span class="b">$1</span>')).join("\n");
    return `<div class="r${isNew?" new":""}" onclick="focusOn('${esc(r.s)}')"><div class="t">${esc(r.t)}</div><div class="s">${esc(r.s||"")}</div><div class="side ${sd}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"—"}</div><div class="h">${esc(r.kind||"")} ${esc(head)}</div>${lines?`<div class="l">${lines}</div>`:""}</div>`; }).join(""); }
/* ---------- THE THREE ---------- */
function threeHTML(T){ const ev=T&&T.evening, lv=T&&T.live; const X=(lv&&(lv.rows||[]).length)?lv:ev; if(!X||!(X.rows||[]).length){ $("h3").textContent="THE THREE"; return '<div class="empty">no list yet — the newsroom builds it at 18:30</div>'; }
  $("h3").innerHTML=(X===ev)?`THE THREE <small>for tomorrow · newsroom ${esc(X.t||"18:30")} · buy at 14:30, sell by 09:30 the day after</small>`:`THE THREE <small>today · ${esc(X.phase||"")}</small>`;
  return X.rows.slice(0,3).map(r=>{ const up=r.side==="CE"; const v=r.verdict||""; const vc=/^WAIT/.test(v)?"dn":/^WATCH|^SELL/.test(v)?"wt":(up?"pu":"pd"); const e=r.edge;
    return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="rk">${r.rank}</div><div class="l1"><b>${esc(r.s)}</b><span class="sd ${up?"pu":"pd"}">${up?"UP → CE":"DOWN → PE"}</span> <span class="${cls(r.chg)}">₹${inr(r.spot)} ${pc(r.chg)}</span></div><div></div>
      <div class="vd ${vc}">${esc(v.slice(0,150))}</div>
      <div class="l2">${r.k?`<em>${r.k} ${esc(r.side)} ₹${r.p}</em> · 1 lot ₹${inr(r.cost||0)} · stop ₹${r.stop_p} / share ${r.stop_share??"—"}${r.tgt?` · target ${r.tgt}`:""} · `:""}${e?`rule ${e[0]}% of ${e[1]}`:"not measured yet"}</div></div>`; }).join(""); }
async function loadThree(){ try{ const r=await fetch("three?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ T3=await r.json(); $("threel").innerHTML=threeHTML(T3); } }catch(e){} }
/* ---------- SECTORS ---------- */
function heat(c){ if(c==null) return "transparent"; const a=Math.min(1,Math.abs(c)/2.5)*0.55+0.08; return c>=0?`rgba(30,215,96,${a.toFixed(2)})`:`rgba(255,59,74,${a.toFixed(2)})`; }
function secHTML(S){ if(!S.length) return '<div class="empty">no sectors yet</div>';
  return S.map(s=>{ const ce=(s.ce||[])[0], pe=(s.pe||[])[0]; const pill=(ce&&Math.abs(ce.v)===2)?'<span class="pl pu">++</span>':(pe&&Math.abs(pe.v)===2)?'<span class="pl pd">++</span>':(ce||pe)?`<span class="pl ${ce?"pu":"pd"}">+</span>`:"";
    return `<div class="c${SEL===s.name?" sel":""}" style="background:${heat(s.chg)}" onclick="pickSector('${esc(s.name)}')">${pill}<div class="n">${esc(s.name)}</div><div class="v ${cls(s.chg)}">${s.chg==null?"—":pc(s.chg)}</div><div class="tb">${ce?`<span class="pu">${esc(ce.s)}${ce.conf?"✓":""}</span>`:""}${ce&&pe?" · ":""}${pe?`<span class="pd">${esc(pe.s)}${pe.conf?"✓":""}</span>`:""}${!ce&&!pe&&s.top?`<span class="pu">${esc(s.top.s)} ${pc(s.top.chg)}</span>`:""}</div></div>`; }).join(""); }
function pickSector(n){ SEL=(SEL===n)?"":n; $("secsel").value=SEL; drawSecs(); drawTape(); }
function drawSecs(){ $("secg").innerHTML=secHTML(SECS); }
/* ---------- TAPE ---------- */
function meter(v){ let h=""; for(let i=-2;i<=2;i++){ if(i===0){ h+='<i style="width:3px;background:var(--line2)"></i>'; continue; } const on=(v>0&&i>0&&i<=v)||(v<0&&i<0&&i>=v); h+=`<i class="${on?(v>0?"u":"d"):""}"></i>`; } return h; }
function sectorSyms(){ const s=SECS.find(x=>x.name===SEL); return s?new Set(s.syms||[]):null; }
let LASTPX={};
function drawTape(){ const set=sectorSyms(); let rows=set?TAPE.filter(r=>set.has(r.s)):TAPE.slice();
  const by={move:(a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0), desk:(a,b)=>Math.abs(b.v||0)-Math.abs(a.v||0)||Math.abs(b.chg||0)-Math.abs(a.chg||0), name:(a,b)=>a.s<b.s?-1:1, chg:(a,b)=>(b.chg||0)-(a.chg||0)};
  rows.sort(by[sortBy]||by.move); const n=rows.length; if(!showAll&&window.innerWidth<900) rows=rows.slice(0,40);
  const th=(k,l)=>`<th class="${sortBy===k?"on":""}" onclick="sortBy='${k}';drawTape()">${l}${sortBy===k?" ▾":""}</th>`;
  $("tapel").innerHTML=`<table><thead><tr>${th("name","SHARE")}${th("chg","PRICE")}${th("move","CHG")}${th("desk","DESK")}<th>WHAT THE OI SAYS</th></tr></thead><tbody>`+
    rows.map(r=>{ const o=LASTPX[r.s]; const f=(o!=null&&r.px!=null&&r.px!==o)?(r.px>o?" fu":" fd"):""; return `<tr onclick="focusOn('${esc(r.s)}')"><td class="s">${esc(r.s)}</td><td class="px hi${f}">${r.px!=null?inr(r.px):"—"}</td><td class="ch ${cls(r.chg)}">${pc(r.chg)}</td><td class="m">${meter(r.v||0)}${r.conf?'<span class="pu"> ✓</span>':""}</td><td class="oi">${esc(r.oi||(r.bu?r.bu.toLowerCase()+(r.cr?` ₹${Math.round(r.cr)} cr`:""):"—"))}</td></tr>`; }).join("")+
    `</tbody></table>`+(n>rows.length?`<div class="more" onclick="showAll=true;drawTape()">show all ${n} shares</div>`:"");
  LASTPX={}; for(const r of TAPE) LASTPX[r.s]=r.px;
  $("tfoot").textContent=`${n} ${SEL?SEL+" ":""}shares · ${D&&D.desk_t?`desk ${D.desk_t} (${D.desk_src||""})`:`desk: no reading yet`}`; }
/* ---------- NEWS ---------- */
function newsHTML(N){ if(!N.length) return '<div class="empty">no news read in the last 26 hours</div>';
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${esc(x.h)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${esc(x.h)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
let nx=0; function runNews(){ const R=$("run"); const w=R.scrollWidth; nx+=0.55; if(nx>w) nx=0; R.style.transform=`translateX(${-nx}px)`; requestAnimationFrame(runNews); } requestAnimationFrame(runNews);
/* ---------- OI SCENARIOS (patch 84) ---------- */
const SCAT={};
function scnPill(c){ return c.side==="CE"?'<span class="sd pu">UP → CE</span>':c.side==="PE"?'<span class="sd pd">DOWN → PE</span>':c.side==="dyn"?'<span class="sd am">TURN</span>':'<span class="sd dim">READING</span>'; }
function scnHTML(S){ if(!S||!S.cat) return '<div class="empty">the scenario agent reads from 09:45 (open + 30)</div>';
  for(const c of S.cat) SCAT[c.id]=c; const sc=S.scores||{}; const by={};
  for(const r of (S.today||[])) (by[r.id]=by[r.id]||[]).push(r);
  const ids=Object.keys(by).sort((a,b)=>by[b].length-by[a].length);
  const ms=id=>{ const v=sc[id]; const a=(SCAT[id]||{}).acts; return v?(v[1]>=50&&v[0]>=55?`<b>${v[0]}% of ${v[1]}${a?" · BUY":" · proven"}</b>`:`${v[0]}% of ${v[1]}`):(a?"new · WATCH":"new"); };
  let h=ids.map(id=>{ const c=SCAT[id]||{name:id}; const seen=new Set(), syms=[]; for(const r of by[id].slice().reverse()){ if(!seen.has(r.s)){ seen.add(r.s); syms.push(r); } }
    return `<div class="r"><div class="nm">${esc(c.name)}${scnPill(c)}</div><div class="n">${by[id].length}</div><div class="ms">${ms(id)}</div><div class="sy">${syms.slice(0,8).map(r=>`<a class="${r.ch==="box"?"box":""}" onclick="focusOn('${esc(r.s)}')">${esc(r.s)} <span class="dim">${esc(r.t)}</span></a>`).join("")}${syms.length>8?`<span>+${syms.length-8} more</span>`:""}</div></div>`; }).join("");
  if(!ids.length) h='<div class="empty">no OI scenario has fired yet today</div>';
  const quiet=S.cat.filter(c=>!by[c.id]).map(c=>c.name.toLowerCase());
  return h+`<div class="ft">${S.cat.length} scenarios watched on every F&amp;O share every 5 s · a scenario fires after holding ${S.hold||60} s, once a share a day · green share = went to Box Picks (measured BUY) · the number = right on the same-day close, this server · quiet today: ${esc(quiet.join(" · "))}</div>`; }
function scnRibbon(sym){ const f=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===sym).slice(-3).reverse(); if(!f.length) return "";
  return `<div class="rib">🧩 ${f.map(r=>`<b>${esc(r.t)}</b> ${esc(r.name)} <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span>`).join(" · ")} <span class="dim">· the OI BUILD-UP tab has the numbers</span></div>`; }
function scnFocus(){ const d=FD&&FD.desk; const hold=((d&&d.scn)||[]).filter(h=>!h.fired); const fired=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).slice().reverse();
  if(!hold.length&&!fired.length) return '<div class="scl"><div class="dim">OI SCENARIOS on this share: nothing has built up yet today</div></div>';
  return `<div class="scl">${fired.map(r=>`<div><b class="am">${esc(r.t)}</b> 🧩 <b>${esc(r.name)}</b> <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span> · ${esc(r.word)}${r.ch==="box"?" · went to Box Picks":r.ch==="read"?" · GIR Intraday":""}<br><span class="dim">${esc(r.line)}</span></div>`).join("")}${hold.map(h=>`<div><span class="am">holding ${h.held}s</span> 🧩 ${esc(h.name)} <span class="dim">— ${esc(h.line)}</span></div>`).join("")}</div>`; }
/* ---------- FOCUS: the share's own live window ---------- */
let FT={live:null,chart:null,oi:null}, FCH=null, FLV=null, FOI=null, FTAB="chart";
const fmtL=v=>v==null?"—":(Math.abs(v)>=1e5?(v/1e5).toFixed(2)+" L":Math.round(v).toLocaleString("en-IN"));
const dL=v=>v==null?"":(v>=0?"+":"−")+(Math.abs(v)>=1e5?(Math.abs(v)/1e5).toFixed(2)+" L":Math.round(Math.abs(v)).toLocaleString("en-IN"));
function hhmm(i){ const m=9*60+15+i*5; return `${String(Math.floor(m/60)).padStart(2,"0")}:${String(m%60).padStart(2,"0")}`; }
function candleSVG(ch,lv){ if(!ch||!(ch.c||[]).length) return '<div class="empty">no candles yet today</div>';
  const n=ch.c.length; const O=ch.o.slice(),H=ch.h.slice(),L=ch.l.slice(),C=ch.c.slice(),V=ch.v||[];
  if(lv&&lv.px!=null&&n){ const i=n-1; C[i]=lv.px; H[i]=Math.max(H[i]??lv.px,lv.px); L[i]=Math.min(L[i]??lv.px,lv.px); }
  const W=720,Hh=230,Lm=6,Rm=58,T=10,B=22,VH=34; const bw=(W-Lm-Rm)/75; const vals=[].concat(H,L,[ch.pc,ch.vw].filter(x=>x!=null)).filter(x=>x!=null);
  let lo=Math.min(...vals), hi=Math.max(...vals); const pad=(hi-lo)*0.06||1; lo-=pad; hi+=pad; const y=v=>T+(Hh-T-B-VH)*(1-(v-lo)/(hi-lo));
  const vmax=Math.max(...V,1); const yv=v=>(Hh-B)-(v/vmax)*(VH-4);
  let g=""; for(let i=0;i<n;i++){ if(C[i]==null||O[i]==null) continue; const x=Lm+i*bw+bw/2; const up=C[i]>=O[i]; const col=up?"var(--up)":"var(--dn)";
    g+=`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(H[i]).toFixed(1)}" y2="${y(L[i]).toFixed(1)}" stroke="${col}" stroke-width="1"/>`;
    const y0=y(Math.max(O[i],C[i])), y1=y(Math.min(O[i],C[i])); g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${y0.toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${Math.max(1,y1-y0).toFixed(1)}" fill="${up?"var(--up)":"var(--dn)"}"/>`;
    if(V[i]) g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${yv(V[i]).toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${((Hh-B)-yv(V[i])).toFixed(1)}" fill="${col}" opacity=".35"/>`; }
  const grid=[0,0.25,0.5,0.75,1].map(f=>{ const v=lo+(hi-lo)*f; return `<line x1="${Lm}" x2="${W-Rm}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-Rm+4}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(Math.round(v*10)/10)}</text>`; }).join("");
  const xs=[0,12,24,36,48,60,72].map(i=>`<text x="${(Lm+i*bw).toFixed(1)}" y="${Hh-6}" fill="var(--dim)" font-size="10" font-family="monospace">${hhmm(i)}</text>`).join("");
  const pcl=ch.pc!=null?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pc).toFixed(1)}" y2="${y(ch.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${W-Rm+4}" y="${(y(ch.pc)-4).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace">prev ${inr(ch.pc)}</text>`:"";
  const vwl=ch.vw!=null?`<line x1="${Lm}" x2="${(Lm+n*bw).toFixed(1)}" y1="${y(ch.vw).toFixed(1)}" y2="${y(ch.vw).toFixed(1)}" stroke="var(--amber)" stroke-width="1" opacity=".8"/><text x="${W-Rm+4}" y="${(y(ch.vw)+10).toFixed(1)}" fill="var(--amber)" font-size="9" font-family="monospace">vwap ${inr(ch.vw)}</text>`:"";
  const last=C[n-1]; const up=ch.pc!=null?last>=ch.pc:true;
  const lpx=last!=null?`<rect x="${W-Rm+1}" y="${(y(last)-8).toFixed(1)}" width="${Rm-2}" height="15" fill="${up?"var(--up)":"var(--dn)"}"/><text x="${W-Rm+4}" y="${(y(last)+3).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(last)}</text><line x1="${Lm}" x2="${W-Rm}" y1="${y(last).toFixed(1)}" y2="${y(last).toFixed(1)}" stroke="${up?"var(--up)":"var(--dn)"}" stroke-dasharray="2 3" opacity=".7"/>`:"";
  const pdh=ch.pdh!=null&&ch.pdh<hi&&ch.pdh>lo?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pdh).toFixed(1)}" y2="${y(ch.pdh).toFixed(1)}" stroke="var(--line2)" stroke-dasharray="1 4"/>`:"";
  return `<svg class="px" viewBox="0 0 ${W} ${Hh}" preserveAspectRatio="none">${grid}${pdh}${pcl}${vwl}${g}${lpx}${xs}</svg>`; }
function oiRows(){ const o=(FLV&&FLV.ok&&FLV.o&&Object.keys(FLV.o).length)?FLV.o:null; const R=(FOI&&FOI.rows)||{}; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||(FD&&FD.px);
  let ks=o?Object.keys(o).map(Number):(FD&&FD.strikes||[]).map(x=>x.k); if(!ks.length) ks=Object.keys(R).map(Number); ks=[...new Set(ks)].filter(k=>k&&spot&&Math.abs(k/spot-1)<=0.08).sort((a,b)=>b-a);
  return ks.map(k=>{ const kk=String(k); const lo=o&&(o[kk]||o[("%s"===""?kk:kk)]); const ref=R[("%g".length,String(+k))]||R[kk]||{}; const fs=(FD&&FD.strikes||[]).find(x=>x.k===k)||{};
    const ce_oi=lo?lo[1]:(ref.ce?ref.ce[1]:fs.ce), pe_oi=lo?lo[3]:(ref.pe?ref.pe[1]:fs.pe), ce_p=lo?lo[0]:(ref.ce?ref.ce[2]:null), pe_p=lo?lo[2]:(ref.pe?ref.pe[2]:null);
    const ce_d=(ref.ce&&ref.ce[0]!=null&&ce_oi!=null)?ce_oi-ref.ce[0]:null, pe_d=(ref.pe&&ref.pe[0]!=null&&pe_oi!=null)?pe_oi-ref.pe[0]:null;
    return {k,ce_oi,pe_oi,ce_p,pe_p,ce_d,pe_d}; }); }
function oiTable(){ const rows=oiRows(); if(!rows.length) return '<div class="empty">no strikes read yet</div>'; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||0;
  const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const atm=rows.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,rows[0]);
  const roof=FD&&FD.roof&&FD.roof.k, floor=FD&&FD.floor&&FD.floor.k; let tce=0,tpe=0,tced=0,tped=0,hasd=false;
  const tr=rows.map(r=>{ tce+=r.ce_oi||0; tpe+=r.pe_oi||0; if(r.ce_d!=null){tced+=r.ce_d;hasd=true;} if(r.pe_d!=null){tped+=r.pe_d;}
    const cw=((r.ce_oi||0)/mx*100).toFixed(0), pw=((r.pe_oi||0)/mx*100).toFixed(0);
    return `<tr class="${r===atm?"atm":""}${(r.k===roof||r.k===floor)?" wall":""}"><td class="d ${r.ce_d>0?"up":r.ce_d<0?"dn":""}"><span>${dL(r.ce_d)}</span></td><td class="ce"><i style="width:${cw}%"></i><span>${fmtL(r.ce_oi)}</span></td><td><span>${r.ce_p!=null?r.ce_p:"—"}</span></td><td class="k">${r.k}</td><td class="l"><span>${r.pe_p!=null?r.pe_p:"—"}</span></td><td class="pe l"><i style="width:${pw}%"></i><span>${fmtL(r.pe_oi)}</span></td><td class="d l ${r.pe_d>0?"up":r.pe_d<0?"dn":""}"><span>${dL(r.pe_d)}</span></td></tr>`; }).join("");
  const pcr=tce?(tpe/tce).toFixed(2):"—";
  return `<table class="oi"><thead><tr><th>CE ΔOI</th><th>CE OI</th><th>CE LTP</th><th class="k">STRIKE</th><th class="l">PE LTP</th><th class="l">PE OI</th><th class="l">PE ΔOI</th></tr></thead><tbody>${tr}<tr class="tot"><td class="d ${tced>0?"up":tced<0?"dn":""}"><span>${hasd?dL(tced):""}</span></td><td><span>${fmtL(tce)}</span></td><td><span class="dim">calls</span></td><td class="k">PCR ${pcr}</td><td class="l"><span class="dim">puts</span></td><td class="l"><span>${fmtL(tpe)}</span></td><td class="d l ${tped>0?"up":tped<0?"dn":""}"><span>${hasd?dL(tped):""}</span></td></tr></tbody></table>`; }
function oiTrendSVG(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return ""; const W=720,H=110,L=6,R=58,T=8,B=18; const n=S.t.length; const x=i=>L+(W-L-R)*(i/(n-1));
  const vals=[].concat(S.ce,S.pe); const lo=Math.min(...vals), hi=Math.max(...vals)||1; const y=v=>T+(H-T-B)*(1-(v-lo)/((hi-lo)||1));
  const path=(arr,col)=>`<polyline fill="none" stroke="${col}" stroke-width="1.6" points="${arr.map((v,i)=>`${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ")}"/>`;
  const lab=(arr,col,dy)=>`<text x="${W-R+4}" y="${(y(arr[n-1])+dy).toFixed(1)}" fill="${col}" font-size="10" font-family="monospace">${fmtL(arr[n-1])}</text>`;
  const xs=S.t.map((t,i)=>(i%Math.ceil(n/6)===0||i===n-1)?`<text x="${x(i).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="${i===n-1?"end":"start"}">${t}</text>`:"").join("");
  return `<svg class="oit" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${path(S.ce,"var(--dn)")}${path(S.pe,"var(--up)")}${lab(S.ce,"var(--dn)",3)}${lab(S.pe,"var(--up)",14)}${xs}</svg>`; }
function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const ln=(d&&d.lines)||{}; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?`tick ${FLV.age_p}s ago`:"on ticks"):(f.src||"");
  return `<div class="hd"><b>${esc(f.s)}</b><span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span><span class="dim">${esc(age)}</span><a class="am" style="margin-left:auto" onclick="unfocus()">✕ ALL SHARES</a></div>
    <div class="m ${c}">${d?`DESK ${esc(d.label)} ${d.v>0?"+":""}${d.v}${Math.abs(d.v)===2?(d.conf?" ✓ CONFIRMED":" · awaiting the 5-min confirmation"):""}`:"no desk reading yet (the desk reads from 09:45)"}${d&&d.steps&&d.steps.length?` <span class="dim">· ${esc(d.steps.join(" · "))}</span>`:""}${d&&d.notes&&d.notes.length?` <span class="pd">· ${esc(d.notes.join(" · "))}</span>`:""}</div>
    ${d&&d.ticket?`<div class="tk">▶ ${esc(d.ticket)}${d.stop?` · stop: a close ${d.v>0?"under":"over"} ${d.stop}`:""}${d.line_k?` · line ${d.line_k}`:""}${d.size?`\n${esc(d.size)}`:""}</div>`:""}
    ${scnRibbon(f.s)}<div class="tabs"><span class="${FTAB==="chart"?"on":""}" onclick="FTAB='chart';paint()">PRICE · 5 MIN</span><span class="${FTAB==="oi"?"on":""}" onclick="FTAB='oi';paint()">OI BUILD-UP</span><span class="${FTAB==="desk"?"on":""}" onclick="FTAB='desk';paint()">THE DESK</span></div>
    <div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; if(!$("fbody")){ F.innerHTML=focusHTML(FD); } else { F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","oi","desk"][i]===FTAB)); const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); hd.replaceWith(tmp.querySelector(".hd")); } }
  const B=$("fbody"); if(!B) return;
  if(FTAB==="chart"){ const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
    B.innerHTML=`<div class="sub"><span>O <b>${n?inr(ch.o[0]):"—"}</b></span><span>H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b></span><span>L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b></span><span>LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b></span><span>VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b></span><span>PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b></span>${ch&&ch.pdh?`<span>PDH <b>${inr(ch.pdh)}</b></span>`:""}${ch&&ch.pdl?`<span>PDL <b>${inr(ch.pdl)}</b></span>`:""}</div>${candleSVG(ch,FLV)}<div class="legend">5-minute candles today · <i style="background:var(--amber)"></i>VWAP · dashed = yesterday's close · the last candle moves with every tick</div>`; }
  else if(FTAB==="oi"){ B.innerHTML=`${scnFocus()}<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiTable()}<div class="legend"><i style="background:var(--dn)"></i>calls (a wall above = roof) <i style="background:var(--up)"></i>puts (a wall below = floor) · ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money</div>${oiTrendSVG()}${FOI&&FOI.series&&FOI.series.t.length>1?'<div class="legend">total OI through the day: <i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts — rising calls above the price = sellers building a roof; rising puts below = a floor</div>':""}`; }
  else { const d=FD.desk, ln=(d&&d.lines)||{}; B.innerHTML=`${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${chainSVG(FD)}<div class="cap">green = PUT contracts under the price (the floor is the tallest) · red = CALL contracts above (the roof is the tallest)${FD.pcr?` · PCR ${FD.pcr}`:""}</div>${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${esc(x.h)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; } }
function chainSVG(f){ const S=f.strikes||[]; if(!S.length||!f.spot) return ""; const W=640,H=120,L=50,R=10,T=8,B=20; const n=S.length; const bw=(W-L-R)/n; const mx=Math.max(...S.map(x=>Math.max(x.ce,x.pe)),1);
  const y=v=>T+(H-T-B)*(1-v/mx); const bars=S.map((x,i)=>{ const x0=L+i*bw; const w=Math.max(2,bw*0.42); const isR=f.roof&&f.roof.k===x.k, isF=f.floor&&f.floor.k===x.k;
    return `<rect x="${(x0+bw*0.06).toFixed(1)}" y="${y(x.pe).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.pe)).toFixed(1)}" fill="var(--up)" opacity="${isF?1:0.5}"/><rect x="${(x0+bw*0.52).toFixed(1)}" y="${y(x.ce).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.ce)).toFixed(1)}" fill="var(--dn)" opacity="${isR?1:0.5}"/>${(i%Math.ceil(n/8)===0)?`<text x="${(x0+bw/2).toFixed(1)}" y="${H-6}" fill="var(--dim)" font-size="10" text-anchor="middle" font-family="monospace">${x.k}</text>`:""}`; }).join("");
  const ks=S.map(x=>x.k); const lo=Math.min(...ks), hi=Math.max(...ks); const sx=L+((f.spot-lo)/((hi-lo)||1))*(W-L-R-bw)+bw/2;
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" style="width:100%;height:120px;display:block;background:#000"><line x1="${L}" x2="${W-R}" y1="${H-B}" y2="${H-B}" stroke="var(--line2)"/>${bars}<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="4 3"/></svg>`; }
async function getJ(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pullLive(){ if(!FOC) return; const v=await getJ("live?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.sym===FOC){ FLV=v; paint(); } }
async function pullChart(){ if(!FOC) return; const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.c){ FCH=v; paint(); } }
async function pullOI(){ if(!FOC) return; const v=await getJ("oi?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FOI=v; paint(); } }
function stopLive(){ for(const k in FT){ if(FT[k]) clearInterval(FT[k]); FT[k]=null; } }
async function focusOn(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return; const fresh=sym!==FOC; FOC=sym; $("q").value=sym; $("unf").style.display="inline-block";
  if(fresh){ FCH=null; FLV=null; FOI=null; stopLive(); }
  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;
  const F=$("focus"); F.hidden=false; if(window.innerWidth<900) F.classList.add("sheet");
  if(!FD||(!(FD.strikes||[]).length&&FD.px==null&&!FD.desk)){ F.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">not an F&amp;O share on the desk</div>`; return; }
  if(fresh||!$("fbody")) F.innerHTML=focusHTML(FD); paint();
  if(fresh){ pullChart(); pullLive(); pullOI(); FT.live=setInterval(pullLive,1000); FT.chart=setInterval(pullChart,10000); FT.oi=setInterval(pullOI,30000); }
  if(D){ $("nowl").innerHTML=nowHTML((D.now||[]).filter(r=>r.s===FOC)); $("hnow").textContent=`${FOC} only · tap ✕ ALL for every share`; const nn=(D.news||[]).filter(x=>x.s===FOC); $("newsl").innerHTML=newsHTML(nn); } }
function unfocus(){ FOC=""; FD=null; FCH=null; FLV=null; FOI=null; stopLive(); const F=$("focus"); F.hidden=true; F.classList.remove("sheet"); F.innerHTML=""; $("q").value=""; $("unf").style.display="none"; if(D){ $("nowl").innerHTML=nowHTML(D.now||[]); $("hnow").textContent="moving right now · newest first · every line went to Telegram the same second"; $("newsl").innerHTML=newsHTML(D.news||[]); } }
$("go").onclick=()=>focusOn($("q").value); $("q").addEventListener("keydown",e=>{ if(e.key==="Enter") focusOn($("q").value); }); $("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };
/* ---------- render: the same code for the poll and the push ---------- */
function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now();
  $("idx").innerHTML=idxHTML(D); $("nowl").innerHTML=nowHTML(FOC?(D.now||[]).filter(r=>r.s===FOC):(D.now||[])); SECS=D.sectors||[]; drawSecs();
  { const S_=D.scn||{}; const ck=JSON.stringify([(S_.today||[]).length,S_.scores,(S_.cat||[]).length]); if(ck!==render.ck){ render.ck=ck; $("scnl").innerHTML=scnHTML(D.scn); $("scnh").textContent=`how the money is building up · ${(S_.today||[]).length} today`; } }
  if(FOC&&(!render.fat||Date.now()-render.fat>30000)){ render.fat=Date.now(); getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)).then(v=>{ if(v&&FOC===v.s){ FD=v; paint(); } }); }
  const sk=SECS.map(s=>s.name).join("|"); if(sk!==render.sk){ render.sk=sk; $("secsel").innerHTML='<option value="">ALL SECTORS</option>'+SECS.map(s=>`<option value="${esc(s.name)}">${esc(s.name).toUpperCase()}</option>`).join(""); $("secsel").value=SEL; }
  const tk=JSON.stringify((D.tape||[]).map(r=>[r.s,r.px,r.v,r.oi])); if(tk!==render.tk){ render.tk=tk; TAPE=D.tape||[]; drawTape(); }
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); }
  first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
loop(); stream(); loadThree(); setInterval(loadThree,120000);
</script></body></html>
HTML_P84
cat > $D/p84test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p84test.py - the OI scenario test (nothing sent, nothing written to the live databases).
  1 the agent's own self-test: every scenario on synthetic chains, the hold, the gates, the channels, the audit
  2 inside THE DESK: the GLENMARK / UNOMINDA day through desk.tick (live mode, Telegram stubbed): the right scenarios fire
  3 the backfill: two synthetic days of 15-min chain readings -> stored with the close -> measured numbers
  4 speed: every scenario on 218 shares in one 5-s reading, well under a second
  5 the page server: the scenarios in /home and the tape's OI line · 6 the page: the panel and FOCUS"""
import os, sys, time, json, sqlite3, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import core, scenarios

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


print("1. the agent's self-test")
import io, contextlib
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    r1 = scenarios.selftest()
fails = [l for l in buf.getvalue().splitlines() if "FAIL" in l]
check("scenarios.py --test: %s" % ("PASSED" if r1 else "FAILED: " + " | ".join(fails)[:200]), r1)

print("2. inside THE DESK (the GLENMARK / UNOMINDA day, live mode, Telegram stubbed)")
import desk
tmp = tempfile.mkdtemp(prefix="p84")
desk.P.update({"out": os.path.join(tmp, "desk.json"), "scores": os.path.join(tmp, "desk_scores.json"), "newscache": os.path.join(tmp, "newsread.json"), "tom": os.path.join(tmp, "tomorrow.db"),
               "filings": os.path.join(tmp, "filings.db"), "news": os.path.join(tmp, "news.db")})
SENT = []
desk.tg_box = lambda text, sym=None, side=None: SENT.append(("box", sym, side, text)) or True
real_tg = core.tg
core.tg = lambda text, silent=None: SENT.append(("intraday", silent, None, text)) or True
d = desk.Desk(sectors_map={"pharma": ["GLENMARK", "QUIET"], "auto-anc": ["UNOMINDA"]}, normal={"GLENMARK": 9000, "UNOMINDA": 6000, "QUIET": 5000}, big=1, fetch_ban=False, news=False)
ses = {"open": "09:15", "close": "15:30", "name": "normal", "special": False}
T = lambda hm: int(core.ist_epoch(dt.datetime(2026, 11, 6, int(hm[:2]), int(hm[3:]))))


def ch(rows, exp="2026-11-25"):
    return {(exp, float(k), kd): (float(oi), float(p), 0) for k, kd, oi, p in rows}


g_ref = ch([(2560, "CE", 39000, 45.0), (2580, "CE", 45000, 39.0), (2600, "CE", 407000, 35.6), (2620, "CE", 46000, 30.0), (2640, "CE", 6000, 26), (2660, "CE", 19000, 22), (2680, "CE", 63000, 19.2), (2700, "CE", 2600, 17.0),
            (2560, "PE", 2200, 310.0), (2580, "PE", 15000, 200.0), (2600, "PE", 4100, 130.0), (2620, "PE", 4000, 227), (2660, "PE", 24000, 255), (2680, "PE", 3700, 200)])
g_1232 = ch([(2560, "CE", 96000, 114.65), (2580, "CE", 109000, 99.15), (2600, "CE", 511000, 90.0), (2620, "CE", 46000, 81.95), (2640, "CE", 6000, 72), (2660, "CE", 19000, 64.05), (2680, "CE", 96000, 56.45), (2700, "CE", 2600, 50.0),
             (2560, "PE", 108000, 51.8), (2580, "PE", 15000, 60.25), (2600, "PE", 168000, 69.95), (2620, "PE", 4000, 79.9), (2660, "PE", 24000, 104.65), (2680, "PE", 78000, 114.2)])
g_1252 = ch([(2560, "CE", 96000, 118), (2580, "CE", 109000, 105), (2600, "CE", 440000, 96.8), (2620, "CE", 55000, 86.0), (2640, "CE", 10000, 75.2), (2660, "CE", 20000, 68), (2680, "CE", 87000, 60.4), (2700, "CE", 234000, 53.4),
             (2560, "PE", 108000, 48), (2580, "PE", 15000, 55), (2600, "PE", 228000, 65.05), (2620, "PE", 6000, 73.7), (2660, "PE", 24000, 104.65), (2680, "PE", 77000, 112.5)])
u_ref = ch([(1040, "CE", 61000, 72), (1060, "CE", 88000, 60), (1080, "CE", 140000, 49), (1100, "CE", 210000, 39), (1120, "CE", 165000, 31), (1140, "CE", 120000, 24), (1160, "CE", 95000, 18),
            (1000, "PE", 90000, 9), (1020, "PE", 110000, 12), (1040, "PE", 130000, 16), (1060, "PE", 18000, 18), (1080, "PE", 150000, 28), (1100, "PE", 98000, 40)])
u_now = ch([(1040, "CE", 55000, 44), (1060, "CE", 52000, 33), (1080, "CE", 54000, 23), (1100, "CE", 82000, 15), (1120, "CE", 64000, 10), (1140, "CE", 70000, 6), (1160, "CE", 60000, 4),
            (1000, "PE", 92000, 14), (1020, "PE", 112000, 19), (1040, "PE", 133000, 25), (1060, "PE", 245000, 38), (1080, "PE", 152000, 46), (1100, "PE", 99000, 62)])
q = ch([(1000, "CE", 300000, 20.0), (1020, "CE", 100000, 12.0), (980, "CE", 20000, 30.0), (980, "PE", 250000, 18.0), (960, "PE", 90000, 10.0), (940, "PE", 30000, 5.0)])
q2 = ch([(1000, "CE", 302000, 19.6), (1020, "CE", 101000, 11.8), (980, "CE", 20500, 30.2), (980, "PE", 251000, 18.1), (960, "PE", 90500, 10.1), (940, "PE", 30000, 5.0)])
steps = [("09:46", {"GLENMARK": 2481.8, "UNOMINDA": 1110.0, "QUIET": 1001.0}, {"GLENMARK": g_ref, "UNOMINDA": u_ref, "QUIET": q}),
         ("12:32", {"GLENMARK": 2614.5, "UNOMINDA": 1108.0, "QUIET": 1001.2}, {"GLENMARK": g_1232, "UNOMINDA": u_ref, "QUIET": q2}),
         ("12:52", {"GLENMARK": 2625.2, "UNOMINDA": 1101.0, "QUIET": 1000.9}, {"GLENMARK": g_1252, "UNOMINDA": u_now, "QUIET": q}),
         ("12:58", {"GLENMARK": 2627.0, "UNOMINDA": 1099.5, "QUIET": 1001.0}, {"GLENMARK": g_1252, "UNOMINDA": u_now, "QUIET": q2})]
real_now = core.ist_now
for hm, spot, chs in steps:
    core.ist_now = (lambda h: (lambda: dt.datetime(2026, 11, 6, int(h[:2]), int(h[3:]))))(hm)
    rd = desk.Reading(T(hm), spot, chs, "test"); rd.hm = hm
    d.tick(rd, ses, tag="live")
core.ist_now = real_now
fired = {(r["s"], r["id"]): r for r in d.scn.today}
print("    fired: %s" % " · ".join("%s %s→%s" % (r["s"], r["id"], r["ch"]) for r in d.scn.today))
check("UNOMINDA: PUTS BOUGHT (1060 PE 13x) fired, DOWN → PE", ("UNOMINDA", "puts_bought") in fired and fired[("UNOMINDA", "puts_bought")]["side"] == "PE")
check("GLENMARK: a CE scenario fired (calls bought / call writers running / floor building)", any(s == "GLENMARK" and r["side"] == "CE" for (s, i), r in fired.items()))
check("QUIET: nothing", not any(s == "QUIET" for (s, i) in fired))
check("nothing on the phone before 09:45 and nothing from the 09:46 reference reading", all(r["t"] >= "12:32" for r in d.scn.today))
SC_SENT = [x for x in SENT if x[3].startswith("🧩")]
check("new rules go to GIR Intraday without sound, as a digest (no Box Picks before 55%% on 50+): %d messages" % len(SC_SENT), SC_SENT and all(x[0] == "intraday" and x[1] is True and x[3].startswith("🧩 OI SCENARIOS") for x in SC_SENT))
c = sqlite3.connect(desk.P["tom"])
n_calls = c.execute("select count(*) from scn_calls where src='live'").fetchone()[0]
try:
    n_now = c.execute("select count(*) from alerts where kind='🧩'").fetchone()[0]
except sqlite3.OperationalError:
    n_now = 0                                                   # no alerts table: nothing was put in NOW
c.close()
check("every fire stored for the audit (%d), on the panel (%d), and NOW stays for Box Picks lines (%d)" % (n_calls, len(d.scn.today), n_now), n_calls == len(d.scn.today) and n_now == 0)
st = d.state(d.last, ses)
check("desk.json carries the scenarios (state + per share)", (st.get("scn") or {}).get("today") and "scn" in (st["shares"].get("UNOMINDA") or {}))
text, _ = d.audit_day("2026-11-06", closes={"GLENMARK": 2650.0, "UNOMINDA": 1070.0, "QUIET": 1001.0})
check("the 15:45 audit scores the scenarios: %s" % text.splitlines()[-1][:100], "OI SCENARIOS 2026-11-06" in text and "right" in text)
core.tg = real_tg

print("3. the backfill on two synthetic days of 15-min readings")
tmp2 = tempfile.mkdtemp(prefix="p84b")
cdb = sqlite3.connect(os.path.join(tmp2, "chains.db"))
cdb.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real, primary key(d, t, sym, exp, strike, kind))")
rows = []
for day, close in (("2026-11-04", 1015.0), ("2026-11-05", 1006.0)):
    for i, t in enumerate(["09:30", "09:45", "10:00", "10:15", "10:30", "15:15"]):
        sp = 1000.0 if t < "10:30" else (1004.0 if t == "10:30" else close)
        for k, kd, oi, p in [(960, "PE", 120000, 8), (980, "PE", 150000, 12), (1000, "PE", 200000, 20), (1020, "PE", 60000, 30), (1040, "PE", 40000, 45),
                             (960, "CE", 30000, 48), (980, "CE", 60000, 32), (1000, "CE", 180000, 20), (1020, "CE", 220000, 12), (1040, "CE", 260000, 7)]:
            if t >= "10:15" and (k, kd) == (980, "PE"):
                oi, p = 330000, 9                                   # puts written under the price from 10:15
            rows.append((day, t, "ABC", "2026-11-25", k, kd, oi, p, sp))
cdb.executemany("insert into chain15 values(?,?,?,?,?,?,?,?,?)", rows); cdb.commit(); cdb.close()
real_base = scenarios.BASE
scenarios.BASE = tmp2
P2 = {"tom": os.path.join(tmp2, "tomorrow.db")}
ds, n_all, per = scenarios.backfill(None, P2, quiet=True)
c = sqlite3.connect(P2["tom"])
bk = c.execute("select day, t, sym, scn, close from scn_calls where src='replay' order by day").fetchall(); c.close()
check("2 days replayed, %d fires stored with the close" % len(bk), len(ds) == 2 and bk and all(r[4] for r in bk))
check("SELLERS BUILDING A FLOOR found at 10:15 on both days", sum(1 for r in bk if r[3] == "put_writing" and r[1] == "10:15") == 2)
sc = scenarios.scores(P2, fresh=True)
check("measured: after the floor was built the share did not close lower, both days (2 of 2)", (sc.get("put_writing") or {}).get("n") == 2 and sc["put_writing"]["right"] == 2)
ds2, n2, _ = scenarios.backfill(None, P2, quiet=True)
scenarios.BASE = real_base
c = sqlite3.connect(P2["tom"]); n_after = c.execute("select count(*) from scn_calls").fetchone()[0]; c.close()
check("running the backfill again adds nothing (%d rows)" % n_after, n_after == len(bk))

print("4. speed")
import random
random.seed(5)
E = "2026-11-25"
chains, prevs = {}, {}
for i in range(218):
    sp = 1000.0
    base = {(E, float(k), kd): (float(random.randint(20000, 400000)), float(random.uniform(3, 60)), 0) for k in range(900, 1101, 20) for kd in ("CE", "PE")}
    chains["S%d" % i] = {key: (oi * random.uniform(0.7, 1.6), p * random.uniform(0.8, 1.25), 0) for key, (oi, p, t) in base.items()}
    prevs["S%d" % i] = base
t0 = time.time()
n_hits = 0
for s in chains:
    h, _ = scenarios.detect(chains[s], prevs[s], prevs[s], 1000.0, 1000.0, 1000.0, {"bu": "LONG BUILD-UP", "cr": 40, "oi": 3, "chg": 1.0}, 8000, "09:45", None, False, {})
    n_hits += len(h)
took = time.time() - t0
check("218 shares × 28 scenarios in %.0f ms (%d raw detections)" % (took * 1000, n_hits), took < 1.5)

print("5. the page server")
import dashserve
dk = {"t": "12:52", "src": "engine", "shares": {"ZZZ": {"spot": 100.0, "v": 1, "lines": {"strikes": "100 CE bought"}, "scn": []}},
      "scn": {"today": [{"t": "12:40", "s": "ZZZ", "id": "calls_bought", "name": "CALLS BOUGHT", "side": "CE", "ch": "read", "word": "WATCH", "line": "x"}], "scores": {}, "cat": [], "hold": 60}}
dashserve.desk_state = lambda: dk
dashserve._HOME["t"] = 0
h = dashserve.home(fresh=True)
z = next((r for r in h.get("tape") or [] if r["s"] == "ZZZ"), None)
check("/home carries the scenarios", (h.get("scn") or {}).get("today"))
check("the tape's OI line leads with the share's latest scenario: %s" % ((z or {}).get("oi") or "")[:60], z and z["oi"].startswith("🧩 12:40 calls bought"))

print("6. the page")
pg = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("the OI SCENARIOS panel", 'id="scn"' in pg and "function scnHTML" in pg)
check("the share's scenarios in FOCUS (ribbon + the OI BUILD-UP tab)", "function scnRibbon" in pg and "${scnFocus()}" in pg)
print("\nP84 SCENARIO TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p84_patch.py $D || { rm -f $D/scenarios.py $D/p84test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
grep -q "function scnHTML" $W/home.html || { echo "the new page is not complete"; back; }
cp $W/home.html $D/home.html
cd $D && python3 -m py_compile scenarios.py desk.py dashserve.py p84test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the scenario test (every scenario on synthetic chains, the GLENMARK / UNOMINDA day through the desk, the backfill, speed):"
timeout 300 python3 p84test.py 2>&1 | grep "OK  \|FAIL\|SCENARIO TEST\|Traceback\|Error\|fired:" | head -30
timeout 300 python3 p84test.py >/dev/null 2>&1 || { echo "the scenario test failed"; back; }
echo "--- 3. the earlier tests still pass:"
timeout 300 python3 desk.py --test 2>&1 | grep "FAIL\|SELF-TEST" | head -10
timeout 300 python3 desk.py --test >/dev/null 2>&1 || { echo "the desk self-test failed"; back; }
for t in p78test p79test p80test p83test; do [ -f $t.py ] && { timeout 300 python3 $t.py >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
echo "--- 4. the backfill: every scenario replayed over the 15-min chain readings on this server (the measured numbers):"
timeout 900 python3 scenarios.py --backfill 2>&1 | tail -45 || echo "    the backfill did not finish - not fatal: the numbers then build from the live fires"
LAST=$(python3 -c "
import sqlite3; c = sqlite3.connect('file:chains.db?mode=ro', uri=True); r = c.execute('select max(d) from chain15 where d < date(\'now\', \'+5 hours\', \'+30 minutes\')').fetchone(); print(r[0] or '')" 2>/dev/null)
if [ -n "$LAST" ]; then echo "--- 5. what would have fired on $LAST (the first 12, in time order):"; timeout 300 python3 scenarios.py --replay $LAST > $W/replay.txt 2>&1; head -24 $W/replay.txt; tail -1 $W/replay.txt; fi
systemctl restart gir-desk gir-dash && sleep 8
K=$(cat $D/dash_token.txt)
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q "function scnHTML" || { echo "the new page is not being served"; back; }
curl -s --max-time 20 "http://127.0.0.1:8090/home?k=$K" | python3 -c "
import json, sys; d = json.load(sys.stdin); print('    home data: NOW %d · sectors %d · tape %d · scenarios key %s' % (len(d['now']), len(d['sectors']), len(d['tape']), 'yes' if 'scn' in d else 'no'))
assert 'scn' in d" || { echo "/home did not answer with the scenarios"; back; }
echo "desk: $(systemctl is-active gir-desk) · page: $(systemctl is-active gir-dash)"
journalctl -u gir-desk --since "-1min" --no-pager -o cat | grep -i "error\|traceback\|scenario" | head -3
echo "PATCH 84 APPLIED - the OI scenario agent reads every share from 09:45 (tomorrow's Muhurat session: from 14:30 on the desk's own reading)."
