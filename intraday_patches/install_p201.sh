#!/bin/bash
# PATCH 201 - 🟢 GO from 09:16 (Rama: "start from 09:16"): the rule that measured positive (GAP + ROOM: 28 cases, 13 won, 8 lost).
#   09:15-09:30 every 5 s: a 0.5-3% gap holding its open (never filled), 3%+ room to the next big wall at yesterday's close, the share's
#   own habit not FADES -> 🟢 GO rings GIR Trade Now (strike, stop 0.8%, target +1.5% then the wall) - at most 5 a morning.
#   15:35: 📋 GO SCORECARD (each GO of the day and all so far). Needs patch 200. No restart (the page: Ctrl + Shift + R).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
[ -f $D/stockpattern.py ] || { echo "patch 200 is not in - run install_p200.sh first"; exit 1; }
FILES="alertword.py tglanes.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/gonow.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/gonow.py <<'PY_GO'
#!/usr/bin/env python3
"""gonow.py - patch 201: 🟢 GO from 09:16 - the first rule that measured positive (ROOM TO RUN, 9 + 11 Nov: GAP + ROOM 28 trades, 13 WIN,
8 LOSS, +0.50% a trade on the share; SBIN, POLICYBZR, SWIGGY, FORCEMOT among them). Rama, 11 Nov: "start from 09:16".
Every 5 s from 09:15 to 09:30 on NSE trading days, for every F&O share:
  GAP      today's open 0.5-3% away from yesterday's close (up -> CE, down -> PE)
  HOLDS    from 09:16: the price still beyond its open, and the gap not filled (never back to yesterday's close)
  ROOM     the next big wall (60%+ of the biggest OI within 8%) at YESTERDAY'S CLOSE (NSE's file, every strike - the chain is not read
           before ~09:21) 3%+ away - none within 8% = open room
  HABIT    the share's own 3 years on a gap like this (stockpattern.json) is not FADES
  -> 🟢 GO rings (GIR Trade Now / Box Picks) with the strike, the stop (0.8% against), the target (+1.5%, then the wall) - at most 5 a morning
15:35  python3 gonow.py --score  -> 📋 GO SCORECARD: each GO of the day (+1.5% before -0.8% by 15:15, the 5-min candles) and all so far
  python3 gonow.py --run [--dry]    the morning watch (--dry: prints, sends nothing)"""
import os, sys, json, time, glob, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
GAP_LO, GAP_HI, ROOM, BIG, BAND, STOP, TGT, MAX_GO = 0.5, 3.0, 3.0, 0.6, 8.0, 0.8, 1.5, 5
DATA = os.path.join(BASE, "data")
SCORE_F = os.path.join(DATA, "gonow_score.json")


def day_file(d):
    return os.path.join(DATA, "gonow_%s.json" % d)


def _f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def chain_of(bsym, today):
    """yesterday's closing chain of the nearest expiry -> {(strike, 'ce'/'pe'): oi}"""
    o = (bsym or {}).get("o") or {}
    exps = sorted(e for e in o if e >= str(today))
    if not exps:
        return {}
    return {(float(k), kd): _f((v.get(kd) or [0])[0]) for k, v in o[exps[0]].items() for kd in ("ce", "pe") if v.get(kd)}


def wall(ch, px, side):
    kd = "ce" if side > 0 else "pe"
    xs = [(k, oi) for (k, d), oi in ch.items() if d == kd and (k > px if side > 0 else k < px) and abs(k / px - 1) * 100 <= BAND]
    if not xs:
        return None, None, 0
    mx = max(oi for k, oi in xs)
    big = sorted([(k, oi) for k, oi in xs if mx > 0 and oi >= BIG * mx], key=lambda x: abs(x[0] - px))
    k, oi = big[0]
    return k, abs(k / px - 1) * 100, oi


def strike(ch, px, side):
    ks = sorted({k for (k, d) in ch})
    up = [k for k in ks if k >= px]
    dn = [k for k in ks if k <= px]
    return (up[0] if up else None) if side > 0 else (dn[-1] if dn else None)


def decide(s, pc, op, px, lo, hi, bsym, habit, today):
    """-> the GO card or None (with why not, for the log)"""
    if not (pc and op and px):
        return None, "no price"
    gap = (op / pc - 1) * 100
    side = 1 if gap > 0 else -1
    if not GAP_LO <= abs(gap) <= GAP_HI:
        return None, "gap %+.1f%%" % gap
    if (px - op) * side <= 0:
        return None, "not holding its open"
    if (lo <= pc) if side > 0 else (hi >= pc):
        return None, "the gap was filled"
    if (px / pc - 1) * 100 * side > GAP_HI:
        return None, "already 3%+"
    ch = chain_of(bsym, today)
    if not ch:
        return None, "no closing chain"
    w, dist, w_oi = wall(ch, px, side)
    if w is not None and dist < ROOM:
        return None, "wall %g only %.1f%% away" % (w, dist)
    word, hn, hh = "no clear habit", 0, 0
    try:
        import stockpattern
        k = stockpattern.key_for(gap)
        st = (habit.get(s) or {}).get(k) if k else None
        if st:
            if st["word"] == "FADES":
                return None, "its own habit: FADES"
            word, hn, hh = st["word"], st["n"], st["held"]
    except Exception:
        pass
    return {"s": s, "side": side, "gap": gap, "op": op, "px": px, "pc": pc, "wall": w, "dist": dist, "w_oi": w_oi,
            "k": strike(ch, px, side), "habit": word, "hn": hn, "hh": hh}, ""


def text(c, now):
    up = c["side"] > 0
    kd = "CE" if up else "PE"
    stop, tgt = c["px"] * (1 - STOP / 100 * c["side"]), c["px"] * (1 + TGT / 100 * c["side"])
    hab = ("its own 3 years on a gap like this: %s %d of %d" % (c["habit"], c["hh"], c["hn"])) if c["hn"] else "its own habit: no clear one on a gap like this"
    room = ("next %s wall %g (%.1f L at yesterday's close) = %.1f%% away" % ("call" if up else "put", c["wall"], c["w_oi"] / 1e5, c["dist"])) if c["wall"] else "no big %s wall within 8%%" % ("call" if up else "put")
    return "\n".join([
        "🟢 GO · %s %s %s · %s" % (c["s"], "▲" if up else "▼", kd, now.strftime("%H:%M")),
        "gap %+.1f%% · holding %s its open ₹%s (now ₹%s) · yesterday ₹%s" % (c["gap"], "above" if up else "below", format(round(c["op"], 2), ","), format(round(c["px"], 2), ","), format(round(c["pc"], 2), ",")),
        "room: " + room, hab,
        "buy: %s %s · stop: %s %s ₹%s (0.8%%) · target ₹%s (+1.5%%)%s" % (("%g" % c["k"]) if c["k"] else "the ATM", kd, c["s"], "below" if up else "above",
                                                                    format(round(stop, 2), ","), format(round(tgt, 2), ","), (" → then the wall %g" % c["wall"]) if c["wall"] else ""),
        "trial rule (28 past cases: 13 won, 8 lost) - keep the size small; the 📋 GO SCORECARD at 15:35 tracks it"])


def holiday(d):
    try:
        import holidays
        return bool(holidays.holiday(d))
    except Exception:
        return d.weekday() >= 5


def prev_bhav(today):
    try:
        import bhavfull
        fs = sorted(f for f in glob.glob(os.path.join(bhavfull.DIR, "*.json")) if os.path.basename(f)[:10] < str(today) and os.path.basename(f)[:4].isdigit())
        return bhavfull.load(os.path.basename(fs[-1])[:10]) if fs else {}
    except Exception:
        return {}


def opens_from_charts():
    try:
        J = json.load(open(os.path.join(BASE, "charts.json"))) or {}
        return {s: float((ch.get("o") or [None])[0]) for s, ch in J.items() if (ch.get("o") or [None])[0]}
    except Exception:
        return {}


def send(txt, dry):
    print(txt + "\n", flush=True)
    if not dry:
        import opencall
        opencall.send_tg(txt)


def run(dry=False, now_f=None, quotes_f=None, sleep=time.sleep, bh=None, habit=None, opens=None):
    now_f = now_f or (lambda: dt.datetime.now(IST))
    now = now_f()
    today = now.date()
    if holiday(today) and not dry:
        print("NSE holiday / weekend"); return []
    bh = bh if bh is not None else prev_bhav(today)
    if habit is None:
        try:
            import stockpattern
            habit = stockpattern.load()
        except Exception:
            habit = {}
    try:
        said = json.load(open(day_file(today)))
    except Exception:
        said = []
    seen = {}
    while True:
        now = now_f()
        hm = now.strftime("%H:%M")
        if hm > "09:30":
            break
        q = (quotes_f() if quotes_f else json.load(open(os.path.join(BASE, "quotes_live.json")))) or {}
        if time.time() - float(q.get("t") or 0) > 60 and not quotes_f:
            sleep(5); continue                                  # the live prices are not fresh - wait
        op_c = opens if opens is not None else opens_from_charts()
        for s, v in (q.get("q") or {}).items():
            px, ch = _f(v[0]), v[1] if len(v) > 1 else None
            if not px or ch is None:
                continue
            pc = px / (1 + ch / 100)
            st = seen.setdefault(s, {"op": op_c.get(s) or px, "lo": px, "hi": px})
            if op_c.get(s):
                st["op"] = op_c[s]
            st["lo"], st["hi"] = min(st["lo"], px), max(st["hi"], px)
            if hm < "09:16" or s in [x["s"] for x in said] or len(said) >= MAX_GO:
                continue
            c, why = decide(s, pc, st["op"], px, st["lo"], st["hi"], bh.get(s), habit, today)
            if c:
                c["t"] = hm
                said.append(c)
                send(text(c, now), dry)
                if not dry:
                    json.dump(said, open(day_file(today), "w"))
        if len(said) >= MAX_GO:
            break
        sleep(5)
    return said


def outcome(C, t, px, side):
    """C = the 5-min candles of the day [(start minute, o, h, l, c)] -> WIN / LOSS / OPEN and the move %"""
    m0 = int(t[:2]) * 60 + int(t[3:5])
    stop, tgt = px * (1 - STOP / 100 * side), px * (1 + TGT / 100 * side)
    last = px
    for m, o, h, l, c in C:
        if m + 5 <= m0 or m + 5 > 915:
            continue
        if (l <= stop) if side > 0 else (h >= stop):
            return "LOSS", -STOP
        if (h >= tgt) if side > 0 else (l <= tgt):
            return "WIN", TGT
        last = c
    return "OPEN", (last / px - 1) * 100 * side


def score(now=None, charts=None, dry=False):
    now = now or dt.datetime.now(IST)
    today = now.date()
    try:
        said = json.load(open(day_file(today)))
    except Exception:
        said = []
    if not said:
        print("no GO today"); return None
    J = charts if charts is not None else (json.load(open(os.path.join(BASE, "charts.json"))) or {})
    rows = []
    for c in said:
        ch = J.get(c["s"]) or {}
        C = [(555 + 5 * i, (ch.get("o") or [])[i], (ch.get("h") or [])[i], (ch.get("l") or [])[i], x) for i, x in enumerate(ch.get("c") or []) if x is not None]
        res, mv = outcome(C, c["t"], c["px"], c["side"]) if C else ("?", 0.0)
        rows.append((c, res, mv))
    try:
        S = json.load(open(SCORE_F))
    except Exception:
        S = {}
    S[str(today)] = [{"s": c["s"], "side": c["side"], "res": r, "mv": round(m, 2)} for c, r, m in rows]
    if not dry:
        json.dump(S, open(SCORE_F, "w"))
    allr = [x for v in S.values() for x in v if x["res"] in ("WIN", "LOSS", "OPEN")]
    w = sum(1 for x in allr if x["res"] == "WIN"); l_ = sum(1 for x in allr if x["res"] == "LOSS")
    L = ["📋 GO SCORECARD · %s · %d GO today" % (now.strftime("%a %d %b"), len(rows))]
    for c, r, m in rows:
        L.append("  %s %s %s %s from ₹%s → %s %+.1f%% (share)" % (c["t"], c["s"], "▲ CE" if c["side"] > 0 else "▼ PE", "gap %+.1f%%" % c["gap"], format(round(c["px"], 2), ","), r, m))
    L.append("all GO so far: %d · WIN %d · LOSS %d · open %d · per trade %+.2f%% on the share (%d days)" % (
        len(allr), w, l_, len(allr) - w - l_, (sum(x["mv"] for x in allr) / len(allr)) if allr else 0, len(S)))
    txt = "\n".join(L)
    print(txt)
    if not dry:
        import opencall
        opencall.send_tg(txt)
    return txt


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--run"]:
        run(dry="--dry" in a)
    elif a[:1] == ["--score"]:
        if holiday(dt.datetime.now(IST).date()) and "--force" not in a:
            print("NSE holiday / weekend"); sys.exit(0)
        score(dry="--dry" in a)
    else:
        print(__doc__)
PY_GO
cat > $W/p201_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p201_patch.py - PATCH 201: 🟢 GO is a trade call: it rings loud, goes to GIR Trade Now, pops up on the page. Usage: python3 p201_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("alertword.py", '''    if H2.startswith("⚡ ENTER NOW"):                             # patch 142: the entry BEFORE the move - rings loud''',
    '''    if H2.startswith("⚡ ENTER NOW") or H2.startswith("🟢 GO"):  # patch 142: the entry BEFORE the move - rings loud · patch 201: 🟢 GO''', "🟢 GO rings loud")
rep("tglanes.py", '''    return H2.startswith("⚡ ENTER NOW") or H2.startswith("🌅 OPENING CALL")''',
    '''    return H2.startswith("⚡ ENTER NOW") or H2.startswith("🟢 GO") or H2.startswith("🌅 OPENING CALL")''', "🟢 GO -> GIR Trade Now")
rep("home.html", '''  if(/^🌅 OPENING CALL|OPENING CALL FAILED/.test(H)||/^⚡ ENTER NOW/.test(H)||k==="💼"||k==="🛑") return "act";''',
    '''  if(/^🌅 OPENING CALL|OPENING CALL FAILED/.test(H)||/^⚡ ENTER NOW/.test(H)||/^🟢 GO/.test(H)||k==="💼"||k==="🛑") return "act";   /* patch 201 */''', "the page: 🟢 GO pops up")
if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 201 written")
PY_PATCH
cat > $D/p201test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p201test.py - PATCH 201: 🟢 GO from 09:16 on made-up quotes (nothing sent)"""
import os, sys, datetime as dt
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import gonow as G
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
TODAY = dt.date(2026, 11, 12)
def bsym(spot, ce, pe):
    """ce / pe = {strike: oi} at yesterday's close"""
    ks = set(ce) | set(pe)
    return {"spot": spot, "o": {"2026-11-23": {"%g" % k: dict(([("ce", [ce[k], 1])] if k in ce else []) + ([("pe", [pe[k], 1])] if k in pe else [])) for k in ks}}}
SW = bsym(188.6, {190: 900000, 195: 1500000, 200: 3200000, 205: 1000000}, {185: 2000000, 180: 1500000})
HAB = {"SWIGGYX": {"up 1.5-3%": {"n": 12, "held": 9, "word": "HOLDS"}}, "FADEY": {"up 1.5-3%": {"n": 15, "held": 3, "word": "FADES"}}}
c, why = G.decide("SWIGGYX", 188.6, 191.8, 192.6, 191.5, 192.6, SW, HAB, TODAY)
check("SWIGGY-like: gap +1.7%%, holding its open, the 200 wall 3.8%% away, habit HOLDS -> GO (%s)" % why, c and c["side"] == 1 and c["wall"] == 200 and c["habit"] == "HOLDS")
check("... the strike: the first one above the price (195)", c and c["k"] == 195)
c2, why2 = G.decide("WALLX", 188.6, 191.8, 192.6, 191.5, 192.6, bsym(188.6, {195: 5000000, 200: 1000000}, {}), {}, TODAY)
check("a big call wall 1.2%% away -> no GO (%s)" % why2, c2 is None and "wall 195" in why2)
c3, why3 = G.decide("FADEY", 188.6, 191.8, 192.6, 191.5, 192.6, SW, HAB, TODAY)
check("its own habit FADES -> no GO (%s)" % why3, c3 is None and "FADES" in why3)
c4, why4 = G.decide("FILLX", 188.6, 191.8, 192.6, 188.5, 192.6, SW, {}, TODAY)
check("the gap was filled (back to yesterday's close) -> no GO", c4 is None and "filled" in why4)
c5, why5 = G.decide("NOTX", 188.6, 191.8, 191.2, 191.0, 191.9, SW, {}, TODAY)
check("below its open -> no GO", c5 is None and "not holding" in why5)
PE = bsym(500.0, {}, {490: 300000, 470: 2500000, 460: 1000000})
c6, why6 = G.decide("DOWNX", 500.0, 494.0, 493.0, 493.0, 494.2, PE, {}, TODAY)
check("the mirror: gap -1.2%% holding below its open, the 470 put wall 4.7%% away -> GO ▼ PE (%s)" % why6, c6 and c6["side"] == -1 and c6["wall"] == 470)
t = G.text(c, dt.datetime(2026, 11, 12, 9, 16, tzinfo=G.IST)); print(t)
check("the GO text: the share, CE, the strike, the stop, the target, the wall, its habit", all(x in t for x in ("🟢 GO · SWIGGYX ▲ CE · 09:16", "buy: 195 CE", "stop: SWIGGYX below", "target ₹", "the wall 200", "HOLDS 9 of 12")))
# the morning loop on made-up quotes: 09:15:00 the open, 09:16:00 still above -> GO at 09:16, once
clock = [dt.datetime(2026, 11, 12, 9, 15, 0, tzinfo=G.IST) + dt.timedelta(seconds=30 * i) for i in range(40)]
it = iter(clock)
Q = {"t": 0, "q": {"SWIGGYX": [191.8, (191.8 / 188.6 - 1) * 100]}}
def quotes():
    return Q
def nowf():
    n = next(it)
    if n.strftime("%H:%M:%S") >= "09:16:00":
        Q["q"]["SWIGGYX"] = [192.6, (192.6 / 188.6 - 1) * 100]
    return n
said = G.run(dry=True, now_f=nowf, quotes_f=quotes, sleep=lambda s: None, bh={"SWIGGYX": SW}, habit=HAB, opens={})
check("the morning loop: one GO, at 09:16 (%s)" % [(x["s"], x["t"]) for x in said], len(said) == 1 and said[0]["t"] == "09:16")
charts = {"SWIGGYX": {"o": [191.8, 192.6, 193.0] + [194.0] * 10, "h": [192.0, 193.0, 193.6] + [196.0] * 10, "l": [191.5, 192.4, 192.8] + [193.8] * 10, "c": [192.6, 193.0, 193.5] + [195.5] * 10}}
import json, tempfile
G.DATA = tempfile.mkdtemp(); G.SCORE_F = os.path.join(G.DATA, "s.json")
json.dump(said, open(G.day_file(TODAY), "w"))
sc = G.score(now=dt.datetime(2026, 11, 12, 15, 35, tzinfo=G.IST), charts=charts, dry=True)
check("the 15:35 scorecard: SWIGGYX WIN +1.5%", sc and "SWIGGYX ▲ CE" in sc and "WIN +1.5%" in sc)
pass
import alertword, tglanes
check("🟢 GO rings loud (act) and goes to GIR Trade Now", alertword.tier(t) == "act" and tglanes.trade_now(t))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 201"
python3 $W/p201_patch.py $D || back
cd $D && python3 -m py_compile gonow.py alertword.py tglanes.py || back
echo "=== the test (made-up quotes - nothing sent)"
timeout 60 python3 $D/p201test.py > /tmp/p201test.out 2>&1; R=$?
grep -E "  ok|FAIL|PASSED" /tmp/p201test.out; [ $R = 0 ] || back
cat > $U/gir-gonow.service <<'UNIT'
[Unit]
Description=GIR 🟢 GO 09:15-09:30 (gap + room + its own habit)
[Service]
Type=oneshot
TimeoutStartSec=1500
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 gonow.py --run >> data/gonow.log 2>&1'
UNIT
cat > $U/gir-gonow.timer <<'UNIT'
[Unit]
Description=GIR 🟢 GO from 09:15 IST, Monday-Friday (it skips NSE holidays itself)
[Timer]
OnCalendar=Mon..Fri *-*-* 09:15:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
cat > $U/gir-goscore.service <<'UNIT'
[Unit]
Description=GIR 📋 GO SCORECARD 15:35
[Service]
Type=oneshot
TimeoutStartSec=300
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 gonow.py --score >> data/gonow.log 2>&1'
UNIT
cat > $U/gir-goscore.timer <<'UNIT'
[Unit]
Description=GIR 📋 GO SCORECARD 15:35 IST, Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 15:35:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-gonow.timer gir-goscore.timer >/dev/null 2>&1
ist() { TZ=Asia/Kolkata date -d "$(systemctl show $1 -p NextElapseUSecRealtime --value)" '+%a %d %b %H:%M IST' 2>/dev/null; }
echo "=== ready for the morning"
echo "  🟢 GO watch:        next $(ist gir-gonow.timer)"
echo "  📋 GO SCORECARD:    next $(ist gir-goscore.timer)"
cd $D && python3 - <<'PY_CHK'
import datetime as dt, gonow, stockpattern
b = gonow.prev_bhav(dt.date.today() + dt.timedelta(days=1))
print("  yesterday's walls (NSE's closing file): %s" % ("%d shares" % len(b) if b else "NOT FOUND - GO cannot judge room"))
print("  each share's habit: %d shares" % len(stockpattern.load()))
PY_CHK
echo
echo "✅ patch 201 done. From tomorrow 09:16: 🟢 GO rings in GIR Trade Now (at most 5). 15:35: 📋 GO SCORECARD. Ctrl + Shift + R on the page."
