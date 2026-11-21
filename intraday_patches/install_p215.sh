#!/bin/bash
# PATCH 215 - PUSH / PULL STARTED (Rama, 12 Nov: "first we need an alert immediately if someone is trying to pull or push, then I select the
#   share and I see the list" · "only F&O stocks, not any other" · "test them with sample data and simulate them - up and down").
#   - 🚨 PUSH STARTED ▲ / 🚨 PULL STARTED ▼ (every 15 s, F&O shares only): a share moving 0.7%+ in 15 min (or crossing 2%) with 3+ forces
#     behind it including money (futures, option writers, FII, DII, promoter, index funds) - or 2 money forces - and at most one against.
#     One line a force, ▲ / ▼ counted, the kind (🟢 can last / 🟠 fast). Once a share a side; again when 2+ more forces join. Max 25 rings a day.
#   - F&O MOVERS → 🧲 PUSH · PULL: the F&O shares being pushed up / pulled down, the most forces first, ▲ UP / ▼ DOWN pick a side, tap = the
#     share's screen with the full list at the top
#   - SECTOR JUMP names only F&O shares (others counted) and needs an F&O share moving 1%+
#   - PROFIT BOOKING / SHORT COVERING (patch 213): a flat top / bottom counts as fresh until it turns (HDFCBANK in the simulation)
#   Tested here and again on the server: 30 push / pull checks, 11 profit-booking checks, 18 news-hunt checks, and ONE FULL SIMULATED DAY
#   (09:15-15:30, 9 shares up and down, 16 checks). Restarts only the news hunt; the page needs no restart - safe any time. Needs patch 214.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 214" $D/home.html && [ -f $D/pbook.py ] || { echo "patches 213 and 214 first"; exit 1; }
for f in newshunt.py home.html pbook.py; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in newshunt.py home.html pbook.py; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/pushalert.py; systemctl restart gir-newshunt; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pushalert.py <<'PY_PA'
#!/usr/bin/env python3
"""pushalert.py - patch 215: PUSH / PULL STARTED - the moment someone starts pushing a share up or pulling it down (Rama, 12 Nov: "first we
need an alert immediately if someone is trying to pull or push, then I select the share and I see the list"). Runs inside the news hunt
(every 15 s, the live prices) - F&O shares only:
  THE SCREEN  an F&O share moving 0.7%+ in 15 min (beating the market by 0.5%+), or crossing 2% on the day for the first time
  THE CHECK   who is behind it (pushwho - the 12 pushers): 3+ forces on the move's side with at least one of them MONEY (futures, option
              writers, FII, DII, promoter, index funds) - or 2 money forces - and at most one force against
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
    money = sum(1 for r in mine if r["k"] in MONEY)
    if len(them) > MAX_AGAINST or not money or (len(mine) < MIN_F and money < 2):
        return None                                                # 3+ forces with money behind them, or 2 money forces (patch 215: HDFCBANK)
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
cat > $D/pbook.py <<'PY_PB'
#!/usr/bin/env python3
"""pbook.py - patch 213: PROFIT BOOKING - AT THE MOMENT IT STARTS (Rama, 12 Nov: "give me a profit booking alert - the moment the profit
booking started, not after; then it is of no use" · COROMANDEL 11 Nov: +9% on the subsidy news, the early money sold into it, +5.5% at the close).
Runs inside the news hunt (every 15 s, the live prices). For every F&O share that ran 2.5%+ today (1.5%+ when GIR told you to act on it):
  THE START   the price turns down from a FRESH high (made or touched within the last 10 min - a flat top counts until it turns): 8% of the day's move given back (at least 0.5%) when the
              money proves it (futures OI falling / a volume burst), 12% with only a roof forming - the first leg of a give-back, not its end
  THE PROOF   at least one of: the futures OI falling since the high (longs booking) · this 5 minutes' volume 1.5x+ the day's normal
              (real selling, not a pause) · call writers building a roof just above (the desk) · or the give-back already 20%+ of the move
  -> 🚨 PROFIT BOOKING ▼ SYM (🚨 CRITICAL when GIR told you to act on it, or the move was 4%+): was / now / how much given back in how many
     minutes · who is selling · what to do with a CE (book part, the stop that keeps half the move)
  the mirror for a fall: 🚨 SHORT COVERING ▲ SYM - the fall being bought back (book part of a PE)
  once a share a side; again only after a NEW high (low) 0.3% beyond the one it was said at, and 30 min apart"""
import os, re, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
RUN, RUN_ACT, EARLY, START, START_MIN, STRONG, FRESH_S, GAP_S = 2.5, 1.5, 0.08, 0.12, 0.5, 0.20, 600, 1800
ST = {"day": None, "s": {}}
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


def fut_oi(sym):
    """the futures OI % change today (the engine's live reading), None when not known"""
    f = next((x for x in _json("dash_state.json", 10).get("fo_paths") or [] if x.get("s") == sym), None)
    return f.get("oi") if f else None


def vol_x(sym):
    """this 5-min candle's volume vs the day's earlier candles (1.0 = normal), and the day's VWAP"""
    c = (_json("charts.json", 20) or {}).get(sym) or {}
    v = [x for x in (c.get("v") or []) if x]
    vw = c.get("vw")
    if len(v) < 4:
        return None, vw if isinstance(vw, (int, float)) else None
    base = sorted(v[:-1])[len(v[:-1]) // 2] or 1
    return v[-1] / base, (vw if isinstance(vw, (int, float)) else None)


def roof_forming(sym, side):
    wl = ((((_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(sym) or {}).get("lines") or {}).get("walls") or "")
    m = re.search(r"%s forming at ([\d.]+)" % ("roof" if side > 0 else "floor"), wl)
    return m.group(1) if m else None


def acted(day):
    """the shares GIR told you to act on today (GO, ENTER NOW, BOX PICK, TRIAL ENTRY, 🟠 OI)"""
    t, v = _F.get("_acted", (0.0, None))
    if v is not None and time.time() - t < 60:
        return v
    v = set()
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "tomorrow.db"), uri=True, timeout=3)
        for s, tx in c.execute("select sym, text from alerts where day=?", (day,)):
            if s and re.search(r"🟢 GO|ENTER NOW|BOX PICK|TRIAL ENTRY|🟠 OI|OPENING CALL", tx or ""):
                v.add(s)
        c.close()
    except Exception:
        pass
    _F["_acted"] = (time.time(), v)
    return v


def inr(x):
    return "{:,.1f}".format(x) if x < 1000 else "{:,.0f}".format(x)


def tick(now, ltp, chg, fo=None, act=None):
    """now (IST datetime) · ltp {sym: price} · chg {sym: day %} -> [alert texts]"""
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "s": {}})
    hm = now.strftime("%H:%M")
    if not ("09:20" <= hm <= "15:25"):
        return []
    t = now.timestamp()
    act = act if act is not None else acted(day)
    out = []
    for s, px in ltp.items():
        c = chg.get(s)
        if c is None or not px or (fo and s not in fo):
            continue
        pc = px / (1 + c / 100.0)
        if s not in ST["s"]:                                       # first sight (a restart mid-day): the day's high / low so far, as old
            ch_ = (_json("charts.json", 20) or {}).get(s) or {}
            hs, ls = [x for x in (ch_.get("h") or []) if x], [x for x in (ch_.get("l") or []) if x]
            ST["s"][s] = {"hi": max([px] + hs), "t_hi": t - (FRESH_S + 1 if hs and max(hs) > px else 0), "oi_hi": None,
                          "lo": min([px] + ls), "t_lo": t - (FRESH_S + 1 if ls and min(ls) < px else 0), "oi_lo": None, "said": {}}
        st = ST["s"][s]
        for side in (1, -1):
            k_, tk = ("hi", "t_hi") if side > 0 else ("lo", "t_lo")
            if (px > st[k_]) if side > 0 else (px < st[k_]):
                st[k_], st[tk], st["oi_" + k_] = px, t, fut_oi(s)
            elif abs(px / st[k_] - 1) * 100 <= 0.15:
                st[tk] = t                                         # still at the high (low): a flat top / bottom is fresh until it turns
            ext = st[k_]
            move = (ext / pc - 1) * 100 * side                     # the day's move at its best, its way
            need = RUN_ACT if s in act else RUN
            if move < need:
                continue
            said = st["said"].get(side)
            if said and ((ext <= said["at"] * 1.003) if side > 0 else (ext >= said["at"] * 0.997)):
                continue                                           # said already - again only after a new extreme 0.3% beyond
            if said and t - said["t"] < GAP_S:
                continue
            back = (ext - px) / ext * 100 * side                   # how far it came back from the extreme, %
            frac = back / move if move else 0
            if back < max(START_MIN, EARLY * move) or t - st[tk] > FRESH_S:
                continue                                           # not started yet - or the extreme is stale (a slow drift, not booking)
            proof, hard = [], False
            o0, o1 = st["oi_" + k_], fut_oi(s)
            if o0 is not None and o1 is not None and o1 < o0 - 0.3:
                proof.append("futures OI falling %+.1f%% → %+.1f%% (%s booking)" % (o0, o1, "longs" if side > 0 else "shorts")); hard = True
            vx, vw = vol_x(s)
            if vx and vx >= 1.5:
                proof.append("volume %.1fx normal this 5 min (real %s)" % (vx, "selling" if side > 0 else "buying")); hard = True
            rf = roof_forming(s, side)
            if rf:
                proof.append("%s writers building a %s at %s" % ("call" if side > 0 else "put", "roof" if side > 0 else "floor", rf))
            if frac >= STRONG:
                proof.append("already %.0f%% of the move given back" % (100 * frac))
            if not proof or (not hard and back < max(START_MIN, START * move)):
                continue                                           # the money proof (OI / volume) lets it ring at 8% given back, else 12%
            st["said"][side] = {"at": ext, "t": t}
            mins = max(1, int(round((t - st[tk]) / 60)))
            keep = pc * (1 + side * move / 200.0)                   # the stop that keeps half the move
            crit = s in act or move >= 4
            if side > 0:
                head = "🚨 %sPROFIT BOOKING ▼ %s · %s" % ("CRITICAL · " if crit else "", s, hm)
                what = "holding a CE: book part NOW, keep the rest with a stop at ₹%s (keeps half the move)%s · not a PE by itself" % (
                    inr(keep), (" · the day's VWAP ₹%s" % inr(vw)) if vw else "")
            else:
                head = "🚨 %sSHORT COVERING ▲ %s · %s" % ("CRITICAL · " if crit else "", s, hm)
                what = "holding a PE: book part NOW, keep the rest with a stop at ₹%s (keeps half the fall)%s · not a CE by itself" % (
                    inr(keep), (" · the day's VWAP ₹%s" % inr(vw)) if vw else "")
            out.append("\n".join([head,
                                  "was %+.1f%% (₹%s) %d min ago · now %+.1f%% (₹%s) · %.0f%% of the %s given back" % (
                                      move * side, inr(ext), mins, c, inr(px), 100 * frac, "rise" if side > 0 else "fall"),
                                  "who: " + " · ".join(proof),
                                  what]))
    return out
PY_PB
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
chk("2 MONEY forces down (longs leaving + floor writers running): a pull", (A.judge(mk("DOWN", [], ["FUTURES", "WRITERS"])) or [0])[0] == -1)
chk("1 money + 1 other: no alert", A.judge(mk("UP", ["FUTURES", "COMPANY"], [])) is None)
shutil.rmtree(T, ignore_errors=True)
print("PUSH / PULL test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T
cat > $D/p213test.py <<'PY_T3'
#!/usr/bin/env python3
"""p213test.py - patch 213's own test: PROFIT BOOKING replayed (made-up prices like COROMANDEL on 11 Nov) - nothing sent. python3 p213test.py DIR"""
import os, sys, json, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data")); shutil.copy(os.path.join(SRC, "pbook.py"), T)
sys.path.insert(0, T)
import pbook as P
P.BASE = T
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
D0 = dt.datetime(2026, 11, 11, 14, 0, tzinfo=IST)
OK = []
def chk(n, c, g=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(g)[:500]))
def run(path, oi_path=None, act=(), vol=None, minutes=40):
    """path(m) -> day % at minute m after 14:00 ; oi_path(m) -> futures OI %"""
    P.ST.update({"day": None, "s": {}}); P._F.clear()
    out = []
    for i in range(0, minutes * 4 + 1):
        now = D0 + dt.timedelta(seconds=15 * i); m = i / 4.0
        c = path(m); px = 1880 * (1 + c / 100)
        json.dump({"fo_paths": [{"s": "COROMANDEL", "oi": oi_path(m) if oi_path else 6.0}]}, open(os.path.join(T, "dash_state.json"), "w"))
        json.dump({"COROMANDEL": {"v": vol(m) if vol else [100] * 20, "vw": 1985.0}}, open(os.path.join(T, "charts.json"), "w"))
        P._F.clear()
        for msg in P.tick(now, {"COROMANDEL": px}, {"COROMANDEL": c}, act=set(act)):
            out.append((now.strftime("%H:%M:%S"), c, msg))
    return out
# 1 · COROMANDEL: +5% at 14:00 -> +9% at 14:24 -> the early money sells: +7.5% by 14:32, futures OI falling from 14:25
up = lambda m: 5 + 4 * min(m, 24) / 24 if m <= 24 else 9 - 1.5 * min(m - 24, 8) / 8
oi = lambda m: 6.0 if m <= 25 else 6.0 - 0.15 * (m - 25)
o = run(up, oi, act=["COROMANDEL"])
chk("COROMANDEL: 🚨 CRITICAL · PROFIT BOOKING ▼ (GIR said act on it)", o and o[0][2].startswith("🚨 CRITICAL · PROFIT BOOKING ▼ COROMANDEL"), o)
chk("… at the START: within 5 min of the +9% high, while it is still +8.2% or higher", o and o[0][0] <= "14:29:00" and o[0][1] >= 8.2, o[:1])
chk("… says who is selling: futures OI falling (longs booking)", o and "futures OI falling" in o[0][2] and "longs booking" in o[0][2], o[:1])
chk("… and what to do: book part of the CE, the stop that keeps half the move", o and "book part NOW" in o[0][2] and "stop at ₹" in o[0][2], o[:1])
chk("… said once (not every 15 s)", len(o) == 1, [x[0] for x in o])
# 2 · a pause without proof (OI steady, normal volume, a small dip) -> nothing
pause = lambda m: 5 + 4 * min(m, 24) / 24 if m <= 24 else 9 - 0.9 * min(m - 24, 3) / 3
o = run(pause)
chk("a 0.9% pause off the high, OI steady, normal volume: no alert (not booking yet)", o == [], o)
# 3 · no proof from OI but a volume burst -> alert
o = run(up, None, vol=lambda m: [100] * 19 + ([260] if m > 25 else [100]))
chk("the same give-back with 2.6x volume (OI unknown): alert, proof = volume", o and "volume 2.6x" in o[0][2], o)
# 4 · a slow drift hours after the high (stale) -> nothing
slow = lambda m: 9 - 2.0 * m / 40
o = run(slow, lambda m: 6.0 - 0.05 * m)
chk("a slow drift from an old high: no alert (that is not the start)", o == [], o)
# 5 · a share up only 1.8% that GIR did not call: not watched
small = lambda m: 1.0 + 0.8 * min(m, 20) / 20 if m <= 20 else 1.8 - 0.6 * (m - 20) / 10
o = run(small, lambda m: 6.0 - 0.1 * m)
chk("a 1.8% mover GIR did not call: not watched", o == [], o)
# 5b · a flat top for 12 min, then the booking: the top is still fresh (it was touched until it turned)
flat = lambda m: 5 + 4 * min(m, 12) / 12 if m <= 24 else 9 - 1.5 * min(m - 24, 8) / 8
o = run(flat, lambda m: 6.0 if m <= 25 else 6.0 - 0.15 * (m - 25))
chk("a flat top (14:12-14:24) then the booking: alert (the top was touched until it turned)", o and "PROFIT BOOKING" in o[0][2] and o[0][0] <= "14:29:00", o)
# 6 · the mirror: a fall being bought back (short covering)
down = lambda m: -4 - 3 * min(m, 20) / 20 if m <= 20 else -7 + 1.6 * min(m - 20, 8) / 8
o = run(down, lambda m: 5.0 if m <= 21 else 5.0 - 0.2 * (m - 21))
chk("the mirror: -7% then bought back -> 🚨 CRITICAL · SHORT COVERING ▲ (book part of a PE)", o and "SHORT COVERING ▲ COROMANDEL" in o[0][2] and "holding a PE" in o[0][2], o)
shutil.rmtree(T, ignore_errors=True)
print("PROFIT BOOKING test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_T3
cat > $D/simday.py <<'PY_SIM'
#!/usr/bin/env python3
"""simday.py - ONE SIMULATED TRADING DAY through the real news hunt (newshunt.py + pbook.py + pushalert.py + pushwho.py, as on the server):
09:15-15:30, a tick every 15 s, made-up prices / futures OI / news for 9 shares, every alert caught with its time, then checked.
  python3 simday.py DIR      (DIR = newshunt.py, pbook.py, pushalert.py, pushwho.py, macro.py)"""
import os, sys, json, html, shutil, sqlite3, tempfile, datetime as dt
from email.utils import format_datetime
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("newshunt.py", "pbook.py", "pushalert.py", "pushwho.py", "macro.py"):
    shutil.copy(os.path.join(SRC, f), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
D0 = dt.datetime(2026, 11, 12, 9, 15, tzinfo=IST)
FO = ["LICI", "PNB", "HDFCBANK", "COROMANDEL", "CHAMBLFERT", "ITC", "INFY", "SBIN", "AXISBANK", "ICICIBANK", "KOTAKBANK", "TCS", "WIPRO", "HCLTECH"]
PC = {"LICI": 900, "PNB": 108, "HDFCBANK": 1700, "COROMANDEL": 1880, "CHAMBLFERT": 520, "ITC": 410, "INFY": 1500, "SBIN": 1000, "AXISBANK": 1150,
      "ICICIBANK": 1300, "KOTAKBANK": 2000, "TCS": 3100, "WIPRO": 250, "HCLTECH": 1600, "DEEPAKFERT": 1400, "RCF": 160, "GNFC": 560, "FACT": 900}


def lin(m, pts):
    """piecewise-linear path: pts = [(minute, value)]"""
    if m <= pts[0][0]:
        return pts[0][1]
    for (a, x), (b, y) in zip(pts, pts[1:]):
        if a <= m <= b:
            return x + (y - x) * (m - a) / (b - a)
    return pts[-1][1]


# minutes after 09:15 -> day % ; the stories of the day
P = {"LICI": [(0, 0.2), (15, 0.5), (30, 2.0), (45, 2.9), (375, 3.0)],                       # 09:30-10:00 pushed up (MSCI, FII, longs)
     "PNB": [(0, -0.2), (105, -0.4), (115, -1.4), (135, -3.4), (375, -3.3)],                   # 11:00-11:30 pulled down (RBI penalty, shorts)
     "HDFCBANK": [(0, 0.1), (60, -0.3), (90, -3.1), (100, -3.1), (106, -2.5), (130, -1.9), (375, -2.0)],   # falls, then the fall is bought back
     "COROMANDEL": [(0, 1.0), (175, 1.2), (193, 4.0), (249, 9.0), (265, 7.4), (375, 5.9)],     # 12:10 jump on the subsidy, 13:24 top, booked
     "CHAMBLFERT": [(0, 0.3), (175, 0.4), (193, 2.8), (375, 3.0)],
     "DEEPAKFERT": [(0, 0.5), (175, 0.6), (193, 4.6), (375, 6.0)], "RCF": [(0, 0.2), (175, 0.3), (193, 4.1), (375, 5.3)],
     "GNFC": [(0, 0.1), (175, 0.2), (193, 2.4), (375, 1.5)], "FACT": [(0, 0.0), (175, 0.1), (193, 3.9), (375, 4.0)],
     "ITC": [(0, 0.1), (375, 0.4)], "INFY": [(0, -0.2), (200, -1.4), (375, -1.5)],
     "SBIN": [(0, 0.3), (375, 0.5)], "AXISBANK": [(0, 0.1), (375, 0.0)], "ICICIBANK": [(0, 0.2), (375, 0.3)], "KOTAKBANK": [(0, -0.1), (375, 0.1)],
     "TCS": [(0, 0.0), (375, -0.2)], "WIPRO": [(0, 0.1), (375, 0.0)], "HCLTECH": [(0, 0.2), (375, 0.1)]}
# the futures (bu, ₹ cr, OI %) through the day
def fut(s, m):
    if s == "LICI":
        return ("LONG BUILD-UP", 30 + 4 * max(0, m - 15), 1.0 + 0.15 * max(0, min(m, 60) - 15)) if m >= 20 else ("", 0, 0.5)
    if s == "PNB":
        return ("SHORT BUILD-UP", 10 + 2.5 * max(0, m - 105), 0.5 + 0.3 * max(0, min(m, 140) - 105)) if m >= 108 else ("", 0, 0.2)
    if s == "HDFCBANK":
        if m < 62:
            return ("", 0, 0.2)
        if m <= 100:
            return ("LONG UNWINDING", 40 + 6 * (m - 62), 0.2 - 0.08 * (m - 62))                # longs leaving on the fall
        return ("SHORT BUILD-UP" if m <= 101 else "LONG UNWINDING", 260, -2.9 - 0.15 * min(m - 100, 20))   # then shorts cover: OI keeps falling
    if s == "COROMANDEL":
        if m < 178:
            return ("", 0, 0.5)
        oi = 0.5 + 0.12 * (min(m, 249) - 178)                                                 # longs building to the top
        if m > 250:
            oi -= 0.12 * (m - 250)                                                            # the early money leaving
        return ("LONG BUILD-UP", 20 + 2 * (min(m, 249) - 178), oi)
    return ("", 0, 0.0)


NEWS = [(D0 + dt.timedelta(minutes=10), "LIC makes the cut in MSCI India index; passive inflows seen", "CNBC TV18"),
        (D0 + dt.timedelta(minutes=104), "RBI imposes Rs 120 crore penalty on Punjab National Bank", "Economic Times"),
        (D0 + dt.timedelta(minutes=196), "Cabinet approves Rs 62,370 crore subsidy on P&K fertilisers for rabi season", "Business Today")]
open(os.path.join(T, "sectors.py"), "w").write('''
def load():
    return {"banks": "PNB HDFCBANK SBIN AXISBANK ICICIBANK KOTAKBANK".split(), "chemicals": "COROMANDEL CHAMBLFERT".split(),
            "insurance": "LICI".split(), "fmcg": "ITC".split(), "it": "INFY TCS WIPRO HCLTECH".split()}
def themes():
    return {}
''')
open(os.path.join(T, "newsroom.py"), "w").write('''
import json, os, time
N = {"LICI": "Life Insurance Corporation of India", "PNB": "Punjab National Bank", "HDFCBANK": "HDFC Bank", "COROMANDEL": "Coromandel International",
     "CHAMBLFERT": "Chambal Fertilisers and Chemicals", "ITC": "ITC Ltd", "INFY": "Infosys", "SBIN": "State Bank of India", "AXISBANK": "Axis Bank",
     "ICICIBANK": "ICICI Bank", "KOTAKBANK": "Kotak Mahindra Bank", "TCS": "Tata Consultancy Services", "WIPRO": "Wipro", "HCLTECH": "HCL Technologies"}
def fo_names():
    return [(s, n, 1) for s, n in N.items()]
def items_for(sym, hours, x):
    now = json.load(open(os.path.join(os.path.dirname(__file__), "simnow.json")))["t"]
    return [{"t": "08:30", "h": "LIC makes the cut in MSCI India index; passive inflows seen"}] if sym == "LICI" and now > 0 else []
''')
open(os.path.join(T, "whymove.py"), "w").write('''
import json, os
B = os.path.dirname(__file__)
def explain(sym, now=None):
    q = json.load(open(os.path.join(B, "quotes_live.json")))["q"]
    t = json.load(open(os.path.join(B, "simnow.json")))["m"]
    R = []
    if sym == "PNB" and t >= 104:
        R.append({"k": "filing", "t": "reg filing (Thu 11:00): RBI imposes Rs 120 crore penalty", "w": 4, "side": -1})
    if sym == "COROMANDEL" and t >= 196:
        R.append({"k": "news", "t": "news: Cabinet approves Rs 62,370 crore fertiliser subsidy", "w": 5, "side": 1})
    if sym in ("HDFCBANK", "PNB") and q.get("PNB", [0, 0])[1] < -1:
        R.append({"k": "sector", "t": "the banks sector is down - it moves with its sector", "w": 2, "side": -1})
    return {"s": sym, "chg": (q.get(sym) or [None, None])[1], "reasons": R}
''')
open(os.path.join(T, "instflow.py"), "w").write('''
def summary():
    return {"w": {"5": {"fii_buy": [{"s": "LICI", "cr": 210.0, "who": "VANGUARD"}], "fii_sell": [{"s": "PNB", "cr": -95.0, "who": "MORGAN STANLEY"}],
                        "dii_buy": [], "dii_sell": []}}, "deliv": {"day": "2026-11-11", "acc": [{"s": "LICI", "x": 2.1, "extra": 80.0}], "dist": [{"s": "PNB", "x": 1.9, "extra": 45.0}]}}
''')
json.dump({"ban": [], "shares": {"LICI": {"lines": {"walls": "calls 930 was BOUGHT (OI 1.0 L → 2.2 L, premium up) — a bet on UP, not a roof"}},
                                 "PNB": {"lines": {"walls": "puts 104 was BOUGHT (OI 2.1 L → 4.0 L, premium up) — a bet on DOWN, not a floor"}},
                                 "HDFCBANK": {"lines": {"walls": "floor at 1660 BREAKING: price through it, OI 9.0 L → 6.2 L (writers buying back), premium up"}},
                                 "COROMANDEL": {"lines": {"walls": "calls 2000 was BOUGHT (OI 1.2 L → 2.6 L, premium up) — a bet on UP, not a roof"}}}},
          open(os.path.join(T, "data", "desk.json"), "w"))
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values ('2026-11-12', '12:20', '🟢', 'COROMANDEL', 'CE', '🟢 GO · COROMANDEL ▲ CE · 12:20')")   # GIR told you to act on it
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)
import newshunt as N, pbook as PB, pushwho as PW


def rss(now):
    x = "".join("<item><title>%s - %s</title><link>http://x/%d</link><pubDate>%s</pubDate></item>" % (html.escape(h), src, i, format_datetime(t))
                for i, (t, h, src) in enumerate(NEWS) if t <= now)
    return "<rss><channel>%s</channel></rss>" % x


clock = {"t": D0}
sent = []
h = N.Hunter(fetch=lambda url: rss(clock["t"]) if "news.google" in url else "<rss><channel></channel></rss>",
             send=lambda m: sent.append((clock["t"].strftime("%H:%M:%S"), m)), now_f=lambda: clock["t"],
             quotes_f=lambda: {s: PC[s] * (1 + lin((clock["t"] - D0).total_seconds() / 60, P[s]) / 100) for s in P}, wires=False)
h.last_policy = 9e18                                                       # the policy lane is tested elsewhere (patch 209)
for i in range(0, 375 * 4 + 1):
    clock["t"] = now = D0 + dt.timedelta(seconds=15 * i)
    m = i / 4.0
    q = {s: [PC[s] * (1 + lin(m, P[s]) / 100), round(lin(m, P[s]), 3)] for s in P}
    json.dump({"t": now.timestamp(), "q": q}, open("quotes_live.json", "w"))
    json.dump({"t": now.timestamp(), "m": m}, open("simnow.json", "w"))
    fps = []
    for s in FO:
        bu, cr, oi = fut(s, m)
        fps.append({"s": s, "chg": q[s][1], "bu": bu, "cr": cr, "oi": round(oi, 2), "rv": 1.2})
    json.dump({"day": "2026-11-12", "fo_paths": fps, "ctx": {}}, open("dash_state.json", "w"))
    PW._F.clear(); PW._C.clear(); PB._F.clear()                         # the files change every tick (the real caches last 10-30 s)
    h.tick(now)

# ---------------------------------------------------------------- the checks
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))


heads = [(t, x.split("\n")[0]) for t, x in sent]
print("THE DAY'S ALERTS (%d):" % len(sent))
for t, hd in heads:
    print("   %s  %s" % (t, hd))
first = lambda rx: next(((t, x) for t, x in sent if rx in x.split("\n")[0]), (None, ""))
print("\nCHECKS")
t, x = first("PUSH STARTED ▲ LICI")
chk("LICI pushed up 09:30-10:00: 🚨 PUSH STARTED ▲ LICI, by 09:50 (while it runs, not after)", t and t <= "09:50:00", heads)
chk("… lists ▲ who pushes up (FUTURES · FII · INDEX ...) and 🟢 NEW MONEY", "▲ FUTURES: long build-up" in x and "▲ FII:" in x and "▲ INDEX:" in x and "🟢 ▲ NEW MONEY" in x, x)
t, x = first("PULL STARTED ▼ PNB")
chk("PNB pulled down 11:00-11:30: 🚨 PULL STARTED ▼ PNB, by 11:20", t and "11:00:00" <= t <= "11:20:00", heads)
chk("… lists ▼ who pulls down (FUTURES short build-up · FII sold · REGULATOR RBI penalty) and 🟢 NEW MONEY ▼", "▼ FUTURES: short build-up" in x and "▼ FII:" in x and "▼ REGULATOR:" in x and "▼ NEW MONEY" in x, x)
t, x = first("PULL STARTED ▼ HDFCBANK")
chk("HDFCBANK falls 10:15-10:45: 🚨 PULL STARTED ▼ HDFCBANK by 10:45, 🟠 FORCED OUT (2 money forces: longs leaving, the floor breaking)", t and t <= "10:45:00" and "FORCED OUT" in x and "▼ FUTURES: long unwinding" in x and "▼ WRITERS: put writers buying back" in x, (t, x))
t, x = first("SHORT COVERING ▲ HDFCBANK")
chk("… then the fall is bought back from 10:55: 🚨 SHORT COVERING ▲ HDFCBANK by 11:05 (book part of a PE)", t and "10:55:00" <= t <= "11:05:00" and "holding a PE" in x, (t, x))
t, x = first("PUSH STARTED ▲ COROMANDEL")
chk("COROMANDEL: 🚨 PUSH STARTED ▲ by 12:25 (longs + calls bought - before the news)", t and t <= "12:25:00", (t, x[:200]))
t, x = first("SECTOR JUMP ▲")
chk("12:10 the fertiliser shares jump: 🚨 SECTOR JUMP ▲ by 12:25", t and t <= "12:25:00", heads)
chk("… names F&O shares only (COROMANDEL, CHAMBLFERT) - DEEPAKFERT / RCF / FACT only counted", x and "COROMANDEL" in x and "CHAMBLFERT" in x and not any(s in x for s in ("DEEPAKFERT", "RCF", "FACT", "GNFC")) and "not F&O" in x, x)
t, x = first("THE REASON ▲")
chk("the Cabinet subsidy (out 12:31): 🚨 THE REASON within 2 min, with ⚠ THE MONEY CAME FIRST", t and "12:31:00" <= t <= "12:33:00" and "MONEY CAME FIRST" in x, (t, x[:300]))
t, x = first("PROFIT BOOKING ▼ COROMANDEL")
chk("COROMANDEL tops +9% at 13:24, the early money sells (slowly, 0.1%/min): 🚨 CRITICAL · PROFIT BOOKING ▼ by 13:33, still above +8%", t and "13:24:00" < t <= "13:33:00" and x.startswith("🚨 CRITICAL") and "now +8." in x, (t, x[:300]))
chk("… who is selling: futures OI falling (longs booking)", "futures OI falling" in x, x)
names = " ".join(hd for t, hd in heads)
chk("never a non-F&O share in an alert head (DEEPAKFERT · RCF · FACT · GNFC)", not any(s in names for s in ("DEEPAKFERT", "RCF", "FACT", "GNFC")), heads)
chk("quiet shares stay quiet: no alert on ITC, INFY (a slow drift, nothing behind it), SBIN, TCS, WIPRO", not any(s in names for s in ("ITC", "INFY", "SBIN", "TCS", "WIPRO", "HCLTECH", "AXISBANK", "ICICIBANK", "KOTAKBANK")), heads)
from collections import Counter
dup = [k for k, n in Counter(hd.split(" · ")[0] + hd.split(" · ")[1] if " · " in hd else hd for t, hd in heads).items() if n > 1]
chk("no alert said twice (each kind, each share, each side, once)", not [k for k, n in Counter(hd.rsplit(" · ", 1)[0] for t, hd in heads).items() if n > 1], heads)
chk("nothing before 09:20 or after 15:25", all("09:20:00" <= t <= "15:25:59" for t, hd in heads), heads)
shutil.rmtree(T, ignore_errors=True)
print("SIMULATED DAY: %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_SIM
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
cd $D && python3 -m py_compile pushalert.py pbook.py || back
echo "=== 1 · push / pull: shares going up and coming down (made-up files - nothing sent)"
timeout 60 python3 p215test.py $D > /tmp/p215a.out 2>&1; R=$?; grep -E "^[0-9]|❌|passed" /tmp/p215a.out; [ $R = 0 ] || { cat /tmp/p215a.out | tail -20; back; }
echo "=== 2 · profit booking / short covering"
timeout 60 python3 p213test.py $D > /tmp/p215b.out 2>&1; R=$?; grep -E "❌|passed" /tmp/p215b.out; [ $R = 0 ] || back
echo "=== 3 · the news hunt"
python3 $W/p215b_patch.py $D || back
python3 -m py_compile newshunt.py || back
timeout 120 python3 p209test.py $D > /tmp/p215c.out 2>&1; R=$?; grep -E "❌|passed|Error" /tmp/p215c.out; [ $R = 0 ] || back
echo "=== 4 · ONE FULL SIMULATED DAY through the real news hunt (09:15-15:30, a tick every 15 s - nothing sent)"
timeout 600 python3 simday.py $D > /tmp/p215d.out 2>&1; R=$?; grep -vE "^2026-" /tmp/p215d.out | sed -n '/THE DAY/,$p'; [ $R = 0 ] || back
echo "=== 5 · the page"
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
echo "   undo: for f in newshunt.py home.html pbook.py; do cp $D/\$f.bak$TS $D/\$f; done; rm -f $D/pushalert.py; systemctl restart gir-newshunt"
