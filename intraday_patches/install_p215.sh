#!/bin/bash
# PATCH 215 - PUSH / PULL STARTED (Rama, 12 Nov: "first we need an alert immediately if someone is trying to pull or push, then I select the
#   share and I see the list" · "only F&O stocks, not any other" · "test them for shares going up and coming down - both are important").
#   - 🚨 PUSH STARTED ▲ / 🚨 PULL STARTED ▼ (every 15 s, F&O shares only): a share moving 0.7%+ in 15 min (or crossing 2%) with 3+ forces behind
#     it - at least one of them money (futures, option writers, FII, DII, promoter, index funds) - and at most one against. One line a force,
#     ▲ / ▼ counted, the kind (🟢 can last / 🟠 fast). Once a share a side; again when 2+ more forces join. Max 25 rings a day.
#   - F&O MOVERS → 🧲 PUSH · PULL: the F&O shares being pushed up / pulled down, the most forces first, ▲ UP / ▼ DOWN pick a side, tap = the
#     share's screen with the full list at the top
#   - SECTOR JUMP names only F&O shares (others counted as "N more shares of the group (not F&O)") and needs an F&O share moving 1%+
#   Tested: 28 checks (up and down: new money, forced out, tide, index exclusion, promoter pledge, regulator, F&O only, no false alarms).
#   Restarts only the news hunt; the page needs no restart - safe any time. Needs patch 214.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 214" $D/home.html && [ -f $D/pbook.py ] || { echo "patches 213 and 214 first"; exit 1; }
for f in newshunt.py home.html; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in newshunt.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/pushalert.py; systemctl restart gir-newshunt; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pushalert.py <<'PY_PA'
#!/usr/bin/env python3
"""pushalert.py - patch 215: PUSH / PULL STARTED - the moment someone starts pushing a share up or pulling it down (Rama, 12 Nov: "first we
need an alert immediately if someone is trying to pull or push, then I select the share and I see the list"). Runs inside the news hunt
(every 15 s, the live prices) - F&O shares only:
  THE SCREEN  an F&O share moving 0.7%+ in 15 min (beating the market by 0.5%+), or crossing 2% on the day for the first time
  THE CHECK   who is behind it (pushwho - the 12 pushers): 3+ forces on the move's side, at least one of them MONEY (futures, option writers,
              FII, DII, promoter, index funds), and at most one force against
  -> 🚨 PUSH STARTED ▲ SYM / 🚨 PULL STARTED ▼ SYM: the move in 15 min · ▲ who pushes up · ▼ who pulls down · the kind of push (🟢 new money
     can last · 🟠 forced out is fast) - tap it: the share's screen, the full list at the top
  once a share a side a day; again only when 2+ more forces join (it got stronger); at most 25 a day ring, the rest are quiet lines"""
import time, datetime as dt

MONEY = ("FUTURES", "WRITERS", "FII", "DII", "PROMOTER", "INDEX")
MV15, REL, DAY, MIN_F, MAX_AGAINST, RING_CAP = 0.7, 0.5, 2.0, 3, 1, 25
ST = {"day": None, "said": {}, "rang": 0, "crossed": set()}


def judge(p):
    """pushwho's read -> (side, up rows, down rows) or None when no push / pull lines up"""
    on = [r for r in p.get("rows") or [] if r.get("on")]
    up, dn = [r for r in on if r.get("side", 0) > 0], [r for r in on if r.get("side", 0) < 0]
    d = 1 if p.get("dir") == "UP" else -1 if p.get("dir") == "DOWN" else 0
    if not d:
        return None
    mine, them = (up, dn) if d > 0 else (dn, up)
    if len(mine) < MIN_F or len(them) > MAX_AGAINST or not any(r["k"] in MONEY for r in mine):
        return None
    return d, up, dn


def cut(t, n=80):
    t = " ".join((t or "").split())
    return t if len(t) <= n else t[:n].rsplit(" ", 1)[0] + "…"


def text(sym, p, d, up, dn, m15, hm):
    ar = "▲" if d > 0 else "▼"
    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪"}.get(p.get("kind") or "", "")
    mine, them = (up, dn) if d > 0 else (dn, up)
    L = ["🚨 %s %s %s · %s" % ("PUSH STARTED" if d > 0 else "PULL STARTED", ar, sym, hm),
         "%s%+.1f%% today · ▲ %d pushing up · ▼ %d pulling down" % (("%+.1f%% in 15 min · " % m15) if m15 is not None else "", p.get("chg") or 0, len(up), len(dn))]
    L += ["%s %s: %s" % (ar, r["k"], cut(r.get("t"))) for r in mine[:6]]
    if len(mine) > 6:
        L.append("%s … %d more" % (ar, len(mine) - 6))
    L += ["%s against - %s: %s" % ("▼" if d > 0 else "▲", r["k"], cut(r.get("t"), 60)) for r in them[:1]]
    if p.get("kind"):
        L.append("%s %s %s - %s" % (icon, ar, p["kind"], p.get("advice") or ""))
    L.append("tap the share: the full list at the top of its screen")
    return "\n".join(L)


def tick(now, mv15, day_mv, med=0.0, fo=None, read=None):
    """now (IST) · mv15 {sym: % in 15 min} · day_mv {sym: % today} -> [alert texts]"""
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "said": {}, "rang": 0, "crossed": set()})
    hm = now.strftime("%H:%M")
    if not ("09:20" <= hm <= "15:25"):
        return []
    if not fo:
        return []                                                  # F&O shares only (Rama) - no list known, nothing said
    if read is None:
        import pushwho
        read = pushwho.read
    cands = []
    for s, m in mv15.items():
        if s not in fo:
            continue
        if abs(m) >= MV15 and abs(m - med) >= REL:
            cands.append((abs(m), s, m))
    for s, c in day_mv.items():
        if s not in fo or c is None or abs(c) < DAY or s in ST["crossed"]:
            continue
        ST["crossed"].add(s)
        cands.append((abs(c), s, mv15.get(s)))
    out, seen = [], set()
    for _, s, m in sorted(cands, reverse=True)[:25]:
        if s in seen:
            continue
        seen.add(s)
        try:
            p = read(s)
        except Exception:
            continue
        j = judge(p)
        if not j:
            continue
        d, up, dn = j
        n = len(up) if d > 0 else len(dn)
        k = (s, d)
        prev = ST["said"].get(k)
        if prev is not None and n < prev + 2:
            continue                                               # said already - again only when it got 2+ forces stronger
        if m is not None and m * d < 0:
            continue                                               # the last 15 min went the other way - not starting now
        ST["said"][k] = n
        t = text(s, p, d, up, dn, m, hm)
        if ST["rang"] >= RING_CAP:
            t = t.replace("🚨 ", "📈 ", 1)                         # the day's rings are spent - a quiet line (the page + the digest)
        else:
            ST["rang"] += 1
        out.append(t)
    return out
PY_PA
cat > $D/p215test.py <<'PY_T'
#!/usr/bin/env python3
"""p215test.py - patch 215's own test: WHO IS PUSHING UP / PULLING DOWN and PUSH / PULL STARTED, simulated for shares going UP and coming
DOWN (made-up files in a temp folder, stub readers - no network, nothing sent).  python3 p215test.py DIR  (DIR = pushwho.py, pushalert.py)"""
import os, sys, json, time, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("pushwho.py", "pushalert.py"):
    shutil.copy(os.path.join(SRC, f), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime.now(IST).replace(hour=11, minute=0, second=0, microsecond=0)
DAY = str(NOW.date())
CHG = {"LICI": 3.1, "SBIN": 2.2, "PNB": -3.4, "HDFCBANK": -2.6, "PIIND": -4.0, "ITC": 0.9, "INFY": -1.2, "WIPRO": 1.6}
open(os.path.join(T, "whymove.py"), "w").write('''
CHG = %r
R = {"PNB": [{"k": "filing", "t": "reg filing (Thu 10:12): RBI imposes Rs 120 crore penalty", "w": 4, "side": -1},
             {"k": "sector", "t": "the banks sector is -1.4%% - it moves with its sector", "w": 2, "side": -1}],
     "LICI": [{"k": "news", "t": "news 11-12 07:05: LIC makes the cut in the MSCI Global Standard Index", "w": 3, "side": 1}],
     "HDFCBANK": [{"k": "market", "t": "NIFTY -0.9%% - the whole market", "w": 1, "side": -1}],
     "WIPRO": [{"k": "market", "t": "NIFTY +0.9%% - the whole market", "w": 1, "side": 1}]}
def explain(sym, now=None):
    return {"s": sym, "chg": CHG.get(sym), "reasons": R.get(sym, [])}
''' % CHG)
open(os.path.join(T, "instflow.py"), "w").write('''
def summary():
    return {"w": {"5": {"fii_buy": [{"s": "LICI", "cr": 210.0, "who": "VANGUARD"}], "fii_sell": [{"s": "PNB", "cr": -95.0, "who": "MORGAN STANLEY"}],
                        "dii_buy": [], "dii_sell": [{"s": "PIIND", "cr": -60.0, "who": "SBI MUTUAL FUND"}]}},
            "deliv": {"day": "2026-11-11", "acc": [{"s": "LICI", "x": 2.1, "extra": 80.0}], "dist": [{"s": "PNB", "x": 1.9, "extra": 45.0}]}}
''')
open(os.path.join(T, "newsroom.py"), "w").write('''
def items_for(sym, hours, x):
    return {"PIIND": [{"t": "07:02", "h": "PI Industries dropped from the MSCI India index in November rejig"}],
            "LICI": [{"t": "07:01", "h": "LIC, Coforge, Adani Green make the cut in MSCI India index"}]}.get(sym, [])
''')
json.dump({"day": DAY, "fo_paths": [
    {"s": "LICI", "chg": 3.1, "bu": "LONG BUILD-UP", "cr": 140.0, "oi": 7.2, "rv": 2.4},
    {"s": "SBIN", "chg": 2.2, "bu": "SHORT COVERING", "cr": 220.0, "oi": -4.1, "rv": 1.2},
    {"s": "PNB", "chg": -3.4, "bu": "SHORT BUILD-UP", "cr": 75.0, "oi": 9.5, "rv": 2.8},
    {"s": "HDFCBANK", "chg": -2.6, "bu": "LONG UNWINDING", "cr": 310.0, "oi": -3.0, "rv": 1.1},
    {"s": "PIIND", "chg": -4.0, "bu": "SHORT BUILD-UP", "cr": 55.0, "oi": 6.0, "rv": 3.1},
    {"s": "ITC", "chg": 0.9, "bu": "", "cr": 0}, {"s": "INFY", "chg": -1.2, "bu": "", "cr": 2.0},
    {"s": "WIPRO", "chg": 1.6, "bu": "", "cr": 3.0}]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"ban": [], "shares": {
    "SBIN": {"lines": {"walls": "roof at 1000 BREAKING: price through it, OI 12.0 L → 8.1 L (writers buying back), premium up"}},
    "PNB": {"lines": {"walls": "puts 100 was BOUGHT (OI 2.1 L → 4.0 L, premium up) — a bet on DOWN, not a floor · roof forming at 110: OI 5 L → 6 L, premium down"}},
    "HDFCBANK": {"lines": {"walls": "floor at 1650 BREAKING: price through it, OI 9.0 L → 6.2 L (writers buying back), premium up"}},
    "LICI": {"lines": {"walls": "calls 960 was BOUGHT (OI 1.0 L → 2.2 L, premium up) — a bet on UP, not a roof"}}}},
    open(os.path.join(T, "data", "desk.json"), "w"))
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
c.execute("insert into filings(key, sym, t_exch, kind, side, subject, detail) values ('p1', 'PIIND', ?, 'ROUTINE', 0, 'Disclosure under SEBI Takeover Regulations', 'Creation of pledge on 2% shares by promoter group')", (time.time() - 86400,))
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values (?, '10:40', '🚀', 'PNB', 'PE', '🚀 RUNNING ▼ PNB ₹104 -2.1%')", (DAY,))
c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)
import pushwho as W, pushalert as A
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond))
    print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))


def sides(p):
    on = [r for r in p["rows"] if r["on"]]
    return {r["k"] for r in on if r["side"] > 0}, {r["k"] for r in on if r["side"] < 0}


print("1 · SHARES GOING UP")
p = W.read("LICI"); up, dn = sides(p)
chk("LICI +3.1%: 🟢 ▲ NEW MONEY (long build-up, calls bought, FII buying, delivery, MSCI inclusion)", p["kind"] == "NEW MONEY" and p["dir"] == "UP", p["kline"])
chk("LICI: ▲ pushing up = FUTURES · WRITERS · FII · DII · INDEX (+ COMPANY news)", {"FUTURES", "WRITERS", "FII", "DII", "INDEX"} <= up, up)
chk("LICI: ▼ nobody pulling down", dn == set(), dn)
p = W.read("SBIN"); up, dn = sides(p)
chk("SBIN +2.2%: 🟠 ▲ FORCED OUT (short covering + call writers buying back at 1000) - fast, book early", p["kind"] == "FORCED OUT" and p["dir"] == "UP" and "book early" in p["advice"], p["kline"])
p = W.read("WIPRO")
chk("WIPRO +1.6% with NIFTY, no money of its own: ⚪ TIDE ONLY", p["kind"] == "TIDE ONLY", p["kline"])
print("2 · SHARES COMING DOWN")
p = W.read("PNB"); up, dn = sides(p)
chk("PNB -3.4%: 🟢 ▼ NEW MONEY (short build-up, puts bought, FII selling, delivery selling)", p["kind"] == "NEW MONEY" and p["dir"] == "DOWN", p["kline"])
chk("PNB: ▼ pulling down = FUTURES · WRITERS · FII · DII · REGULATOR (RBI penalty) · TIDE (banks) · ALGOS", {"FUTURES", "WRITERS", "FII", "DII", "REGULATOR", "TIDE", "ALGOS"} <= dn, dn)
chk("PNB: ▲ nobody pushing up", up == set(), up)
p = W.read("HDFCBANK"); up, dn = sides(p)
chk("HDFCBANK -2.6%: 🟠 ▼ FORCED OUT (long unwinding + put writers buying back at the 1650 floor)", p["kind"] == "FORCED OUT" and p["dir"] == "DOWN" and "1650" in p["kline"], p["kline"])
p = W.read("PIIND"); up, dn = sides(p)
chk("PIIND -4%: ▼ INDEX (MSCI exclusion) · PROMOTER (pledge created) · DII (MF selling) · FUTURES (short build-up)", {"INDEX", "PROMOTER", "DII", "FUTURES"} <= dn, dn)
chk("PIIND: 🟢 ▼ NEW MONEY", p["kind"] == "NEW MONEY" and p["dir"] == "DOWN", p["kline"])
p = W.read("INFY")
chk("INFY -1.2%, nothing behind it: no push, no line (no false alarm)", p["kind"] == "" and p["kline"] == "", p)
print("3 · PUSH / PULL STARTED - the alert (end to end, the same reads)")
FO = {"LICI", "SBIN", "PNB", "HDFCBANK", "PIIND", "ITC", "INFY", "WIPRO"}
A.ST.update({"day": None, "said": {}, "rang": 0, "crossed": set()})
mv15 = {"LICI": 1.4, "SBIN": 1.1, "PNB": -1.6, "HDFCBANK": -1.2, "PIIND": -2.0, "ITC": 0.2, "INFY": -0.8, "WIPRO": 0.9, "DEEPAKFERT": 3.5}
out = A.tick(NOW, mv15, CHG, med=0.1, fo=FO)
heads = [x.split("\n")[0] for x in out]
chk("🚨 PUSH STARTED ▲ LICI", any(h.startswith("🚨 PUSH STARTED ▲ LICI") for h in heads), heads)
chk("🚨 PULL STARTED ▼ PNB", any(h.startswith("🚨 PULL STARTED ▼ PNB") for h in heads), heads)
chk("🚨 PULL STARTED ▼ PIIND (MSCI exclusion, promoter pledge, MF selling)", any("PULL STARTED ▼ PIIND" in h for h in heads), heads)
chk("🚨 PULL STARTED ▼ HDFCBANK (longs leaving + floor writers running)", any("PULL STARTED ▼ HDFCBANK" in h for h in heads), heads)
chk("not INFY (nothing behind it), not WIPRO (the tide only), not ITC (too small)", not any(s in " ".join(heads) for s in ("INFY", "WIPRO", "ITC")), heads)
chk("not DEEPAKFERT (+3.5% but not an F&O share)", "DEEPAKFERT" not in " ".join(heads), heads)
t = next((x for x in out if "PULL STARTED ▼ PNB" in x), "")
chk("the PNB alert: ▼ 7 pulling down · ▲ 0 pushing up, one line a force (FII sold, short build-up, RBI penalty), the kind", "▲ 0 pushing up · ▼ 7 pulling down" in t and "▼ FII: FII sold ₹95 cr" in t and "▼ FUTURES: short build-up" in t and "▼ REGULATOR: reg filing" in t and "🟢 ▼ NEW MONEY" in t, t)
t = next((x for x in out if "PUSH STARTED ▲ LICI" in x), "")
chk("the LICI alert: ▲ 7 pushing up · ▼ 0 pulling down, one line a force (INDEX: MSCI), 🟢 NEW MONEY", "▲ 7 pushing up · ▼ 0 pulling down" in t and "▲ INDEX: index money" in t and "🟢 ▲ NEW MONEY" in t, t)
out2 = A.tick(NOW + dt.timedelta(seconds=15), mv15, CHG, med=0.1, fo=FO)
chk("said once - the next 15 s says nothing again", out2 == [], [x.split("\n")[0] for x in out2])
mv_rev = dict(mv15, LICI=-0.9)
A.ST.update({"day": None, "said": {}, "rang": 0, "crossed": set()})
out3 = A.tick(NOW, {"LICI": -0.9}, {"LICI": 3.1}, med=0.0, fo=FO)
chk("LICI up on the day but the last 15 min DOWN: no 'PUSH STARTED' (it is not starting now)", not any("PUSH STARTED ▲ LICI" in x for x in out3), out3)
A.ST.update({"day": None, "said": {}, "rang": 0, "crossed": set()})
chk("no F&O list known: nothing said (only F&O shares)", A.tick(NOW, mv15, CHG, med=0.1, fo=set()) == [])
A.ST.update({"day": None, "said": {}, "rang": 0, "crossed": set()})
late = NOW.replace(hour=15, minute=40)
chk("after 15:25: nothing", A.tick(late, mv15, CHG, med=0.1, fo=FO) == [])
# the judge on its own: weak cases
mk = lambda d, ups, dns: {"dir": d, "rows": [{"k": k, "on": True, "side": 1, "t": ""} for k in ups] + [{"k": k, "on": True, "side": -1, "t": ""} for k in dns]}
chk("2 forces only: no alert", A.judge(mk("UP", ["FUTURES", "TIDE"], [])) is None)
chk("3 forces but no money (company · tide · algos): no alert", A.judge(mk("UP", ["COMPANY", "TIDE", "ALGOS"], [])) is None)
chk("3 up but 2 against: no alert (a fight, not a push)", A.judge(mk("UP", ["FUTURES", "FII", "TIDE"], ["REGULATOR", "DII"])) is None)
chk("3 down with money: a pull", (A.judge(mk("DOWN", [], ["FUTURES", "TIDE", "ALGOS"])) or [0])[0] == -1)
shutil.rmtree(T, ignore_errors=True)
print("PUSH / PULL test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T
cat > $W/p215b_patch.py <<'PY_B'
#!/usr/bin/env python3
"""p215b_patch.py - PATCH 215b: the news hunt - SECTOR JUMP names F&O shares only (Rama: "only F&O stocks, not any other") and needs an F&O
share moving 1%+ with the group; PUSH / PULL STARTED runs every 15 s (pushalert.py). Usage: python3 p215b_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "newshunt.py"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  newshunt.py: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  newshunt.py: %s" % tag)


rep('''            self.fired[k] = now_t
            syms = [s for s, m in hit]
            ar = "▲" if side > 0 else "▼"
            fo = fo_set()
            r = self.start(g, side, syms + [s for s in groups().get(g, []) if s not in syms], now_t, "jump", True)
            fom = [s for s in groups().get(g, []) if (not fo or s in fo) and s in mv]          # every F&O share of the group, moved yet or not
            fom.sort(key=lambda s: -mv[s] * side)
            L = ["🚨 CRITICAL · SECTOR JUMP %s %s · %s" % (ar, g.upper(), hm),
                 "in 15 min: " + " · ".join("%s %+.1f%%" % (s, m) for s, m in hit[:7]) + (" (market %+.1f%%)" % med),
                 self.reason_text(r) if r else "📰 no news found yet - GIR is hunting, the reason follows",
                 ("F&O %s %s: " % (ar, "CE" if side > 0 else "PE")) + (" · ".join("%s %+.1f%% (day %+.1f%%)" % (s, mv[s], day_mv.get(s, 0)) for s in fom[:6]) or "none in F&O")]''',
    '''            syms = [s for s, m in hit]
            ar = "▲" if side > 0 else "▼"
            fo = fo_set()
            fom = [s for s in groups().get(g, []) if (not fo or s in fo) and s in mv]          # patch 215b: the group's F&O shares only
            fom.sort(key=lambda s: -mv[s] * side)
            if fo and not any(mv[s] * side >= 1.0 for s in fom):
                continue                                           # no F&O share moving 1%+ with it - nothing to trade, not said
            self.fired[k] = now_t
            r = self.start(g, side, syms + [s for s in groups().get(g, []) if s not in syms], now_t, "jump", True)
            others = [s for s in syms if fo and s not in fo]
            L = ["🚨 CRITICAL · SECTOR JUMP %s %s · %s" % (ar, g.upper(), hm),
                 ("F&O %s %s: " % (ar, "CE" if side > 0 else "PE")) + " · ".join("%s %+.1f%% in 15 min (day %+.1f%%)" % (s, mv[s], day_mv.get(s, 0)) for s in fom[:6]),
                 "with it: %s · market %+.1f%%" % (("%d more shares of the group (not F&O)" % len(others)) if others else "the group", med),
                 self.reason_text(r) if r else "📰 no news found yet - GIR is hunting, the reason follows"]''', "SECTOR JUMP: F&O shares only")
rep('''        for m in msgs:
            try:
                self.send(m)''', '''        if mv and live:                                         # patch 215: PUSH / PULL STARTED - F&O shares only
            try:
                import pushalert
                msgs += pushalert.tick(now, mv, day_mv, med=med, fo=fo_set())
            except Exception as ex:
                log("push / pull: %s" % str(ex)[:80])
        for m in msgs:
            try:
                self.send(m)''', "PUSH / PULL STARTED every 15 s")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("newshunt.py: patch 215b in")
PY_B
cat > $W/p215c_patch.py <<'PY_C'
#!/usr/bin/env python3
"""p215c_patch.py - PATCH 215c: F&O MOVERS → 🧲 PUSH · PULL - the F&O shares being pushed up / pulled down now, the most forces first; ▲ UP /
▼ DOWN pick a side; tap a share = its screen with the full list at the top. Usage: python3 p215c_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  home.html: %s" % tag)


rep('''      <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}</div>''',
    '''      <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("pp","🧲 PUSH · PULL")}</div>''', "the 🧲 PUSH · PULL button")
rep('''    let body;
    if(!WS.pn&&!WS.bu&&WS.k==="chg"&&WS.dir<0){''', '''    let body;
    if(WS.k==="pp"){ body=ppListHTML(); }   /* patch 215c */
    else if(!WS.pn&&!WS.bu&&WS.k==="chg"&&WS.dir<0){''', "the movers show the push / pull list")
rep('''function ppStrip(){''', '''function ppListHTML(){   /* patch 215c: the F&O shares being pushed up / pulled down (the 40 biggest F&O movers, every 30 s) */
  const live=s=>{ const t=(TAPE||[]).find(x=>x.s===s); return t&&t.chg!=null?t.chg:null; };
  const R=Object.values(PP).map(r=>{ const c=live(r.s); const chg=c!=null?c:r.chg; const d=chg>0?1:chg<0?-1:0; const mine=d>0?r.up:r.dn, them=d>0?r.dn:r.up;
      return Object.assign({},r,{chg,d,n:mine.length,m:them.length}); })
    .filter(r=>r.n>0&&(!WS.pn||(WS.pn==="up"?r.d>0:r.d<0))).sort((a,b)=>(b.n-b.m)-(a.n-a.m)||Math.abs(b.chg)-Math.abs(a.chg));
  if(!R.length) return '<div class="empty">'+(Object.keys(PP).length?"no F&amp;O share has forces behind its move yet":"reading who pushes and pulls the F&amp;O movers - a few seconds")+'</div>';
  return `<div class="ppn">🧲 who pushes up / pulls down the 40 biggest F&amp;O movers · most forces first · tap = its screen + the full list</div><div class="mvl">${R.map(r=>`<div class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)} ${ppKind(r.kind)}</b><span class="${cls(r.chg)}">${mkPc(r.chg)}</span><small>${r.d>=0?`<span class="pu">▲ ${r.up.length} pushing up${r.up.length?": "+esc(r.up.join(" · ")):""}</span> · <span class="pd">▼ ${r.dn.length}${r.dn.length?": "+esc(r.dn.join(" · ")):""}</span>`:`<span class="pd">▼ ${r.dn.length} pulling down${r.dn.length?": "+esc(r.dn.join(" · ")):""}</span> · <span class="pu">▲ ${r.up.length}${r.up.length?": "+esc(r.up.join(" · ")):""}</span>`}${r.kind?` · ${esc(r.kind)}`:""}</small></div>`).join("")}</div>`; }
function ppStrip(){''', "the push / pull list")
rep('''i.ppb{font-style:normal;cursor:help;''', '''.ppn{font-size:10px;color:var(--dim);padding:2px 6px 4px}
i.ppb{font-style:normal;cursor:help;''', "the look")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: patch 215c in")
PY_C
cd $D && python3 -m py_compile pushalert.py || back
echo "=== the test: shares going up and coming down (made-up files - nothing sent)"
timeout 60 python3 p215test.py $D > /tmp/p215test.out 2>&1; R=$?; cat /tmp/p215test.out; [ $R = 0 ] || back
echo "=== the news hunt"
python3 $W/p215b_patch.py $D || back
python3 -m py_compile newshunt.py || back
timeout 120 python3 p209test.py $D > /tmp/p215b.out 2>&1 || { grep -E "❌|passed|Error" /tmp/p215b.out; back; }
grep passed /tmp/p215b.out
echo "=== the page"
python3 $W/p215c_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-newshunt && sleep 3 && echo "  gir-newshunt: $(systemctl is-active gir-newshunt)"
echo "✅ patch 215 done - Ctrl + Shift + R on GIR (the phone: reload)."
echo "   from 09:20: 🚨 PUSH STARTED ▲ / PULL STARTED ▼ · MARKET → F&O MOVERS → 🧲 PUSH · PULL = the list"
echo "   undo: for f in newshunt.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/pushalert.py; systemctl restart gir-newshunt"
