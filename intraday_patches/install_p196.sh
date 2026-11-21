#!/bin/bash
# PATCH 196 - THE TRADE CARD, a STUDY first (nothing is sent, nothing restarts). Rama, 11 Nov: "every OI alert - the next strike had a
#   big resistance" · "find stocks which go up / go down for sure". For every F&O share, every 5 min, on the stored candles and option
#   chain: the side (price + VWAP 45 min) · the money (option sellers agree) · the WALL in the way and the room to it · the start
#   (a breakout / a QUIET BUILD like RVNL) -> grade A; a wall too close -> WAIT, then BREAK when the wall's writers run.
#   Each card is scored (the wall reached first = WIN, 1% against first = LOSS). It replays today and the last 20 days with a chain.
set -u
D=/home/globalbot/intraday
cat > $D/tradecard.py <<'PY_TC'
#!/usr/bin/env python3
"""tradecard.py - patch 196: THE TRADE CARD - a STUDY first (nothing is sent). Rama, 11 Nov: "every time you gave me an OI alert I went
to the share and found the next strike has big resistance" · "find stocks which go up for sure and which go down for sure" ·
COROMANDEL (+₹50,000 - the money was in since the morning, the price broke out, room above) · RVNL crept +1% then ran to +3%.

For every F&O share, every 5 minutes from 09:45 to 14:45, on the stored 5-min candles and the stored option chain (chains.db):
  SIDE     CE: 0.5%+ up and above VWAP for the last 45 min · PE: the mirror
  MONEY    the option sellers agree: new put OI below the price >= new call OI above it (CE) in the last 30 min, or the
           wall above is being bought back (its call OI -5%+) · PE: the mirror
  WALL     the nearest BIG call strike above (60%+ of the biggest call OI within 8%) - the "470 CE" in the way
  ROOM     the wall 1.5%+ away (none within 8% = room up to +3%)
  START    BREAKOUT: a new day high (CE) / low (PE) · or QUIET BUILD: 0.5-1.5% its way, last 3 candles' volume 1.3x+ the day's
           median, the price held on its side of VWAP 45 min (RVNL's 10:00-12:00)
  LATE     3%+ already moved -> no card
GRADE A = side + money + room + start. WAIT = A but the wall under 1.5% away -> it becomes a BREAK card when the price closes
above the wall (below it for PE) AND that wall's OI has fallen 5%+ (the writers ran) - the next wall is the target.
OUTCOME (each card): from the card's price, the target = the wall (at most +3%), the stop = 1% against; the 5-min candles after
it to 15:15 decide WIN (target first) / LOSS (stop first) / OPEN (the 15:15 move).
And the day's OI alerts with a side: how many had a wall within 1.5% when they came (the problem Rama found).
  python3 tradecard.py --replay [YYYY-MM-DD]     one day (default: the last day with candles)
  python3 tradecard.py --study 20                the last 20 days that have the option chain stored - the totals"""
import os, sys, json, sqlite3, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
START_M, LAST_M, EXIT_M = 585, 885, 915            # 09:45 · 14:45 · 15:15
HOLD, BIG, BAND, ROOM_MIN, LATE, STOP, TGT_MAX, MIN_CHG = 9, 0.6, 8.0, 1.5, 3.0, 1.0, 3.0, 0.5


def hm(m):
    return "%02d:%02d" % (m // 60, m % 60)


def _num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def vwap_at(C):
    sv = sum(x[5] for x in C)
    return sum((x[2] + x[3] + x[4]) / 3 * x[5] for x in C) / sv if sv else None


def snap_at(ch, t, back=0):
    """the chain snapshot at or before minute t-back -> (minute, spot, {(k, kd): (oi, ltp)}) or None"""
    s = None
    for x in ch:
        if x[0] <= t - back:
            s = x
    return s


def walls(snap, px, side):
    """-> (the nearest BIG wall in the way, its OI, the next big wall after it) for CE (calls above) / PE (puts below)"""
    if not snap or not px:
        return None, 0, None
    kd = "CE" if side > 0 else "PE"
    xs = [(k, _num(v[0])) for (k, d), v in snap[2].items() if d == kd and (k > px if side > 0 else k < px) and abs(k / px - 1) * 100 <= BAND]
    if not xs:
        return None, 0, None
    mx = max(o for k, o in xs)
    big = sorted([(k, o) for k, o in xs if mx > 0 and o >= BIG * mx], key=lambda x: abs(x[0] - px))
    if not big:
        return None, 0, None
    nxt = big[1][0] if len(big) > 1 else None
    return big[0][0], big[0][1], nxt


def money(snap, old, px, side):
    """the option sellers in the last 30 min: (agree?, put OI added below, call OI added above, the wall bought back?)"""
    if not snap or not old or not px:
        return False, 0, 0
    floor_add = roof_add = 0.0
    for (k, d), v in snap[2].items():
        if abs(k / px - 1) * 100 > 3:
            continue
        o0 = _num((old[2].get((k, d)) or (0, 0))[0])
        dd = _num(v[0]) - o0
        if dd <= 0:
            continue
        if d == "PE" and k < px:
            floor_add += dd
        elif d == "CE" and k > px:
            roof_add += dd
    fav, unf = (floor_add, roof_add) if side > 0 else (roof_add, floor_add)
    return fav >= unf and fav > 0, floor_add, roof_add


def oi_of(snap, k, side):
    if not snap or k is None:
        return 0.0
    return _num((snap[2].get((k, "CE" if side > 0 else "PE")) or (0, 0))[0])


def outcome(C, i, px, side, target):
    """from candle index i+1 on (to 15:15): WIN / LOSS / OPEN, the move % at the end, the best move %"""
    stop = px * (1 - STOP / 100 * side)
    best, last = 0.0, px
    for m, o, h, l, c, v in C[i + 1:]:
        if m + 5 > EXIT_M:
            break
        fav = (h / px - 1) * 100 * side if side > 0 else (1 - l / px) * 100
        best = max(best, fav)
        hit_t = (h >= target) if side > 0 else (l <= target)
        hit_s = (l <= stop) if side > 0 else (h >= stop)
        if hit_s and hit_t:
            return "LOSS", -STOP, best                           # both in one candle: the stop counted first (the careful way)
        if hit_s:
            return "LOSS", -STOP, best
        if hit_t:
            return "WIN", abs(target / px - 1) * 100, best
        last = c
    return "OPEN", (last / px - 1) * 100 * side, best


def read_share(D, s):
    """the day of one share -> [card dict] (A, WAIT, BREAK), at most one card a side"""
    C = D.candles.get(s) or []
    pc = D.pc.get(s)
    if len(C) < 8 or not pc:
        return []
    ch = D.chain(s, 24 * 60) or []
    if not ch:
        return []
    out, done_side, waiting = [], set(), {}
    vs, VW, pv, sv = [], [], 0.0, 0.0
    for x in C:                                                 # the VWAP after each candle, once
        pv += (x[2] + x[3] + x[4]) / 3 * x[5]; sv += x[5]
        VW.append(pv / sv if sv else None)
    for i, (m, o, h, l, c, v) in enumerate(C):
        t = m + 5                                               # the candle is finished at t
        vs.append(v)
        if t < START_M or t > LAST_M or i < HOLD:
            continue
        vw = VW[i]
        if not vw:
            continue
        chg = (c / pc - 1) * 100
        for side in (1, -1):
            if side in done_side:
                continue
            held = all(VW[j] and ((C[j][4] > VW[j]) if side > 0 else (C[j][4] < VW[j])) for j in range(i - HOLD + 1, i + 1))
            way = chg * side
            snap, old = snap_at(ch, t), snap_at(ch, t, 30)
            w, w_oi, nxt = walls(snap, c, side)
            # a WAIT that breaks: price beyond the old wall, the wall's OI down 5%+ from when we waited
            if side in waiting:
                wk, w0, wt = waiting[side]
                beyond = (c > wk) if side > 0 else (c < wk)
                now_oi = oi_of(snap, wk, side)
                if beyond and w0 > 0 and now_oi <= 0.95 * w0 and way < LATE:
                    tgt_k = w if w else c * (1 + TGT_MAX / 100 * side)
                    target = min(tgt_k, c * (1 + TGT_MAX / 100)) if side > 0 else max(tgt_k, c * (1 - TGT_MAX / 100))
                    res, mv, best = outcome(C, i, c, side, target)
                    out.append({"kind": "BREAK", "t": hm(t), "s": s, "side": side, "px": c, "chg": chg, "wall": wk, "wall_oi_fell": (1 - now_oi / w0) * 100,
                                "next": w, "res": res, "mv": mv, "best": best, "waited": hm(wt)})
                    done_side.add(side)
                continue
            if way < MIN_CHG or way >= LATE or not held:
                continue
            ok_money, fa, ra = money(snap, old, c, side)
            if not ok_money:
                continue
            dist = abs(w / c - 1) * 100 if w else None
            prior = [x[2] if side > 0 else x[3] for x in C[:i]]
            breakout = (c > max(prior)) if side > 0 else (c < min(prior))
            med = statistics.median(vs[:-3]) if len(vs) > 4 else 0
            volx = (sum(vs[-3:]) / 3 / med) if med else 0
            quiet = MIN_CHG <= way <= 1.5 and volx >= 1.3
            if not (breakout or quiet):
                continue
            if dist is not None and dist < ROOM_MIN:
                if side not in waiting:
                    waiting[side] = (w, w_oi, t)
                    out.append({"kind": "WAIT", "t": hm(t), "s": s, "side": side, "px": c, "chg": chg, "wall": w, "dist": dist, "wall_oi": w_oi})
                continue
            target = (w if w else c * (1 + TGT_MAX / 100 * side))
            target = min(target, c * (1 + TGT_MAX / 100)) if side > 0 else max(target, c * (1 - TGT_MAX / 100))
            res, mv, best = outcome(C, i, c, side, target)
            out.append({"kind": "A", "start": "BREAKOUT" if breakout else "QUIET BUILD", "t": hm(t), "s": s, "side": side, "px": c, "chg": chg,
                        "wall": w, "dist": dist, "volx": volx, "floor_add": fa, "roof_add": ra, "res": res, "mv": mv, "best": best})
            done_side.add(side)
    return out


def alert_walls(D):
    """the day's OI alerts with a side: was a big wall within 1.5% in the way when each came?"""
    n = near = 0
    for a in D.alerts:
        m, kind, s, sd, head = a[0], a[1], a[2], a[3], a[4]
        if kind != "🧩" and "BUILD" not in head and "BOUGHT" not in head and "RUNNING" not in head:
            continue
        ch = D.chain(s, 24 * 60) or []
        snap = snap_at(ch, m)
        if not snap or not snap[1]:
            continue
        side = 1 if sd == "CE" else -1
        w, _o, _n = walls(snap, snap[1], side)
        n += 1
        if w and abs(w / snap[1] - 1) * 100 < ROOM_MIN:
            near += 1
    return n, near


_H = {}


def day_cards(day, syms=None, D=None):
    if D is None:
        import enternow
        if syms is None:
            syms = fo_syms()
        for s_ in syms:                                         # the stored 5-min candles, read once a run
            if s_ not in _H:
                try:
                    _H[s_] = enternow._hist(s_)
                except Exception:
                    _H[s_] = {}
        D = enternow.StoredData(day, syms, _H)
    cards = []
    for s in sorted(D.candles):
        try:
            cards += read_share(D, s)
        except Exception as ex:
            print("  %s: %s" % (s, str(ex)[:80]))
    return cards, alert_walls(D), D


def fo_syms():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        xs = [r[0] for r in c.execute("select sym from fo_list")]
        c.close()
        return xs
    except Exception:
        return []


def chain_days(n):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True)
        tabs = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
        tb = "chain15" if "chain15" in tabs else "chain"
        ds = [r[0] for r in c.execute("select distinct d from %s order by d desc limit ?" % tb, (n,))]
        c.close()
        return sorted(ds)
    except Exception:
        return []


def line(x):
    a = "▲ CE" if x["side"] > 0 else "▼ PE"
    if x["kind"] == "WAIT":
        return "  WAIT  %s %-11s %s ₹%s %+.1f%% · wall %g only %.1f%% away (%.1f L) - not a trade until it breaks" % (x["t"], x["s"], a, format(round(x["px"], 2), ","), x["chg"], x["wall"], x["dist"], x["wall_oi"] / 1e5)
    res = "%s %+.1f%% (best %+.1f%%)" % (x["res"], x["mv"], x["best"])
    if x["kind"] == "BREAK":
        return "  BREAK %s %-11s %s ₹%s %+.1f%% · the wall %g broke (its OI -%.0f%%, waited since %s) · next %s → %s" % (
            x["t"], x["s"], a, format(round(x["px"], 2), ","), x["chg"], x["wall"], x["wall_oi_fell"], x["waited"], ("%g" % x["next"]) if x["next"] else "none near", res)
    return "  A     %s %-11s %s ₹%s %+.1f%% · %s · wall %s · vol %.1fx → %s" % (
        x["t"], x["s"], a, format(round(x["px"], 2), ","), x["chg"], x["start"], ("%g (%.1f%% away)" % (x["wall"], x["dist"])) if x["wall"] else "none within 8%", x["volx"], res)


def summary(cards):
    L = []
    for kind in ("A", "BREAK"):
        xs = [x for x in cards if x["kind"] == kind]
        if not xs:
            L.append("  %-5s none" % kind); continue
        w = sum(1 for x in xs if x["res"] == "WIN"); l_ = sum(1 for x in xs if x["res"] == "LOSS"); o = len(xs) - w - l_
        L.append("  %-5s %d cards · %d WIN · %d LOSS · %d open · average %+.2f%% a card (share move, before options)" % (kind, len(xs), w, l_, o, sum(x["mv"] for x in xs) / len(xs)))
    L.append("  WAIT  %d times a wall stood within 1.5%% (no card)" % sum(1 for x in cards if x["kind"] == "WAIT"))
    return L


def main(a):
    if a[:1] == ["--study"]:
        n = int(a[1]) if len(a) > 1 else 20
        days = chain_days(n)
        if not days:
            print("no stored option chain (chains.db chain15) - nothing to study"); return
        syms = fo_syms()
        allc, an, anear = [], 0, 0
        for d in days:
            cards, (n_, near), D = day_cards(d, syms)
            allc += cards; an += n_; anear += near
            A = [x for x in cards if x["kind"] in ("A", "BREAK")]
            print("%s · %3d shares · %d cards (%d WIN %d LOSS) · OI alerts %d, %d with a wall within 1.5%%" % (
                d, len(D.candles), len(A), sum(1 for x in A if x["res"] == "WIN"), sum(1 for x in A if x["res"] == "LOSS"), n_, near))
        print("\nTHE %d DAYS %s - %s" % (len(days), days[0], days[-1]))
        print("\n".join(summary(allc)))
        if an:
            print("  the OI alerts with a side: %d · %d (%.0f%%) had a big wall within 1.5%% when they came" % (an, anear, 100.0 * anear / an))
        return
    day = a[1] if a[:1] == ["--replay"] and len(a) > 1 else (chain_days(1) or [str(dt.date.today())])[-1]
    cards, (an, anear), D = day_cards(day)
    print("TRADE CARD REPLAY · %s · %d shares with candles · nothing sent\n" % (day, len(D.candles)))
    for x in sorted(cards, key=lambda x: x["t"]):
        print(line(x))
    print("\n".join([""] + summary(cards)))
    if an:
        print("  the day's OI alerts with a side: %d · %d (%.0f%%) had a big wall within 1.5%% when they came" % (an, anear, 100.0 * anear / an))


if __name__ == "__main__":
    main(sys.argv[1:] or ["--replay"])
PY_TC
cat > $D/p196test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p196test.py - PATCH 196: the trade card study on made-up days (no server data needed)"""
import os, sys
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import tradecard as T
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)

class FakeD:
    def __init__(self):
        self.candles, self.pc, self.alerts, self._c = {}, {}, [], {}
    def chain(self, s, upto):
        return [x for x in self._c.get(s, []) if x[0] <= upto]

def bars(path, vols):
    """path = closes every 5 min from 09:15; each bar o = previous close"""
    out, prev = [], path[0]
    for i, c in enumerate(path):
        out.append((555 + 5 * i, prev, max(prev, c) * 1.0005, min(prev, c) * 0.9995, c, vols[i]))
        prev = c
    return out

D = FakeD()
# 1 COROMANDEL-like: a slow climb above VWAP all morning, then at 13:45 a new high on volume; the floor builds, room to the 1960 wall
p = [1878 + i * 0.2 for i in range(54)] + [1912, 1918, 1925, 1933, 1940, 1948, 1955, 1962, 1965, 1966] + [1966] * 11
v = [1000] * 54 + [4000] * 10 + [1500] * 11
D.candles["COROM"] = bars(p, v); D.pc["COROM"] = 1870.0
def ch_corom(m, put1880):
    return (m, 1900.0, {(1900.0, "CE"): (300000, 20), (1920.0, "CE"): (200000, 12), (1960.0, "CE"): (520000, 4), (2000.0, "CE"): (800000, 2),
                        (1880.0, "PE"): (put1880, 10), (1860.0, "PE"): (150000, 6)}, "2026-11-23")
D._c["COROM"] = [ch_corom(m, 200000) for m in range(570, 811, 15)] + [ch_corom(m, 300000) for m in range(825, 931, 15)]
# 2 RVNL-like: up 2% but a big 207.5 call wall 0.7% away -> WAIT; at 14:20 the wall's calls are bought back and it closes above -> BREAK
p2 = [203 + i * 0.03 for i in range(40)] + [206 + i * 0.02 for i in range(20)] + [207.0, 208.0, 209.5, 211.0, 212.5, 213.5, 214.5, 215.0] + [215.0] * 7
v2 = [1000] * 40 + [2500] * 20 + [5000] * 8 + [1500] * 7
D.candles["RVNLX"] = bars(p2, v2); D.pc["RVNLX"] = 204.0
def ch_rv(m, wall_oi, put205):
    return (m, 206.0, {(207.5, "CE"): (wall_oi, 2), (210.0, "CE"): (100000, 1), (215.0, "CE"): (900000, 0.5),
                       (205.0, "PE"): (put205, 2), (202.5, "PE"): (300000, 1)}, "2026-11-23")
D._c["RVNLX"] = [ch_rv(m, 1500000, 200000 + 2000 * (m - 570)) for m in range(570, 856, 15)] + [ch_rv(m, 1000000, 800000) for m in range(870, 931, 15)]
# 3 a rise the option sellers do not believe: calls written above, no puts below -> no card
p3 = [100 + i * 0.03 for i in range(75)]
D.candles["NOBEL"] = bars(p3, [1000] * 60 + [3000] * 15); D.pc["NOBEL"] = 99.0
D._c["NOBEL"] = [(m, 101.0, {(103.0, "CE"): (100000 + 5000 * (m - 570), 1), (100.0, "PE"): (100000, 1)}, "x") for m in range(570, 931, 15)]
# 4 the mirror (PE): COROMANDEL turned upside down - a fall below VWAP, then a new low on volume; call sellers build a roof, room to the put wall
M = 2 * 1870.0
D.candles["FALLX"] = [(m, M - o, M - l, M - h, M - c, v_) for (m, o, h, l, c, v_) in D.candles["COROM"]]; D.pc["FALLX"] = 1870.0
D._c["FALLX"] = [(m, M - sp, {(M - k, "PE" if kd == "CE" else "CE"): x for (k, kd), x in d.items()}, e) for (m, sp, d, e) in D._c["COROM"]]
cards = {s: T.read_share(D, s) for s in D.candles}
a = [x for x in cards["COROM"] if x["kind"] == "A"]
check("COROMANDEL-like: grade A ▲ CE on the breakout (%s)" % [(x["t"], x["start"]) for x in a], len(a) == 1 and a[0]["side"] == 1 and a[0]["start"] == "BREAKOUT")
check("... the wall in the way is 1960, room %.1f%% (not 1900/1920 - small ones)" % (a[0]["dist"] if a else -1), a and a[0]["wall"] == 1960.0 and a[0]["dist"] >= 1.5)
check("... and it WINS: the share reaches the wall (%s %+.1f%%)" % ((a[0]["res"], a[0]["mv"]) if a else ("-", 0)), a and a[0]["res"] == "WIN")
w = [x for x in cards["RVNLX"] if x["kind"] == "WAIT"]; br = [x for x in cards["RVNLX"] if x["kind"] == "BREAK"]
check("RVNL-like: WAIT - the 207.5 call wall is under 1.5%% away (%s)" % [(x["t"], round(x["dist"], 1)) for x in w], len(w) == 1 and w[0]["wall"] == 207.5)
check("... no A card under the wall", not [x for x in cards["RVNLX"] if x["kind"] == "A"])
check("... BREAK when it closes above 207.5 and that wall's OI fell (%s)" % [(x["t"], round(x["wall_oi_fell"])) for x in br], len(br) == 1 and br[0]["wall_oi_fell"] >= 5)
check("... the BREAK reaches its target (%s)" % (br[0]["res"] if br else "-"), br and br[0]["res"] == "WIN")
f = [x for x in cards["FALLX"] if x["kind"] == "A"]
check("the mirror: grade A ▼ PE on the new low, the put wall %s in the way, WIN (%s)" % (f[0]["wall"] if f else "-", f[0]["res"] if f else "-"),
      len(f) == 1 and f[0]["side"] == -1 and f[0]["wall"] == 1780.0 and f[0]["res"] == "WIN")
check("a rise the option sellers write calls against: no card", not [x for x in cards["NOBEL"] if x["kind"] in ("A", "BREAK")])
print("\n".join(T.line(x) for xs in cards.values() for x in xs))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile tradecard.py || { echo "❌ tradecard.py does not compile"; exit 1; }
echo "=== the test (made-up days: a COROMANDEL-like breakout, an RVNL-like wall that breaks, the PE mirror, a rise nobody believes)"
timeout 60 python3 $D/p196test.py | grep -E "ok|FAIL|PASSED" | sed 's/^/ /' | head -12
echo
echo "=== TODAY, replayed (nothing sent)"
nice -n 10 timeout 900 python3 $D/tradecard.py --replay $(TZ=Asia/Kolkata date +%Y-%m-%d) 2>&1 | tee $D/data/tradecard_today.txt | tail -45
echo
echo "=== THE LAST 20 DAYS WITH THE OPTION CHAIN STORED (a few minutes)"
nice -n 10 timeout 1800 python3 $D/tradecard.py --study 20 2>&1 | tee $D/data/tradecard_study.txt | tail -32
echo
echo "✅ patch 196 study done - nothing was sent or changed. Send Claude a screenshot of TODAY and THE LAST 20 DAYS."
echo "   the full lists: $D/data/tradecard_today.txt · $D/data/tradecard_study.txt"
