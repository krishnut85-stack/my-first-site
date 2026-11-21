#!/bin/bash
# THE PRE-MOVE STUDY - replays a day: when each 3%+ mover crossed 1 / 2 / 3%, and what came BEFORE it (GIR's alerts, volume
#   spikes, the call / put writers leaving, the sector rotation). Reads only: no service is restarted, nothing is changed.
#   Puts premove.py in the GIR folder, tests it on a made-up day, then studies today (or: bash premove.sh 2026-11-06)
#   and sends the report to GIR's ⚙️ System topic - copy it from Telegram and paste it to Claude.
D=/home/globalbot/intraday
cat > $D/premove.py <<'PY_MAIN'
#!/usr/bin/env python3
"""premove.py - THE PRE-MOVE STUDY (Rama, 9 Nov: "I want the alert BEFORE it moves"). Reads only - changes nothing.
Replays a day from what the server keeps and answers, for every F&O share that moved 3%+ (and the ones Rama named):

  the move     when it crossed 0.5% · 1% · 2% · 3% · 5% its way (5-min candles)
  before it    GIR's own alerts and their times · the first-move / surge / order-book jumps (tomorrow.db) · the 5-min volume
               spikes · the option chain every 15 min: the call writers just above the price (their OI falling = they leave)
               and the put writers just below (adding = a floor) · its sector at that moment
  ROTATION     every sector's average and breadth through the day: when did "money leaving one sector, into another" first
               show (3 levels), the leaders and the laggards of the rising sector and how many minutes the laggards gave
  the gap      for each mover: the first early sign vs the 2% crossing = how much warning GIR could have given

  python3 premove.py [YYYY-MM-DD] [--no-tg]     prints, saves data/premove_<day>.txt / .json, sends the summary to
                                                 GIR's ⚙️ System topic (copy it from Telegram and paste it to Claude)"""
import os, sys, re, json, time, sqlite3, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NAMED = ["COCHINSHIP", "DATAPATTNS", "PNB", "UNIONBANK", "CANBK", "BANKINDIA", "BANKBARODA", "SBIN", "INDIANB", "IRFC", "NBCC", "BOSCHLTD", "JUBLFOOD"]
CROSS = (0.5, 1, 2, 3, 5)


def hm(m):
    return "%02d:%02d" % (m // 60, m % 60)


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


# ---------- the inputs (each one replaceable in the test) ----------
def fo_list():
    try:
        c = _ro("chains.db"); v = [r[0] for r in c.execute("select sym from fo_list")]; c.close(); return v
    except Exception:
        return []


def sector_map():
    try:
        import sectors
        return {k: list(v) for k, v in (sectors.load() or {}).items()}
    except Exception:
        return {}


def bars_of(sym, day):
    """-> (pc, [(minute of the bar's start, o, h, l, c, v)]) for that day, from the server's 5-min candles"""
    import dashserve as ds
    h = ds.hist(sym, 3)
    rows, prev = [], []
    for i, t in enumerate(h.get("t") or []):
        d = dt.datetime.fromtimestamp(t, IST)
        r = (d.hour * 60 + d.minute, h["o"][i], h["h"][i], h["l"][i], h["c"][i], h["v"][i])
        if str(d.date()) == day:
            rows.append(r)
        elif str(d.date()) < day:
            prev.append((str(d.date()), r))
    pc = h.get("pc") if day == dt.datetime.now(IST).strftime("%Y-%m-%d") else None
    if not pc and prev:
        pc = sorted(prev)[-1][1][4]
    return pc, rows


def gir_rows(day, sym):
    """-> [(hh:mm, what)] GIR's alerts and the engine's own jumps for the share that day"""
    out = []
    try:
        c = _ro("tomorrow.db")
        for t, kind, side, text in c.execute("select t, kind, side, text from alerts where day=? and sym=? order by t", (day, sym)):
            out.append((t[:5], "alert %s %s" % (side or "", (text or "").split("\n")[0][:80])))
        for tb, cols in (("first_moves", "t, side, chg, xvol"), ("surges", "t, side, chg, kind"), ("book_moves", "t, side, x, p15")):
            try:
                for r in c.execute("select %s from %s where day=? and sym=? order by t" % (cols, tb), (day, sym)):
                    out.append((str(r[0])[:5], "%s %s %s" % (tb.replace("_", " "), r[1], " ".join(str(x) for x in r[2:]))))
            except Exception:
                pass
        c.close()
    except Exception:
        pass
    return sorted(out)


def chain_of(day, sym):
    """-> [(t, spot, {(strike, kind): oi})] the 15-min readings of the nearest expiry"""
    try:
        c = _ro("chains.db")
        tabs = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
        tb = "chain15" if "chain15" in tabs else ("chain" if "chain" in tabs else None)
        if not tb:
            return []
        rows = c.execute("select t, exp, strike, kind, oi, spot from %s where d=? and sym=? order by t" % tb, (day, sym)).fetchall()
        c.close()
    except Exception:
        return []
    if not rows:
        return []
    exp = sorted({r[1] for r in rows})[0]
    by = {}
    for t, e, k, kd, oi, sp in rows:
        if e != exp:
            continue
        b = by.setdefault(str(t)[:5], [sp, {}])
        if sp:
            b[0] = sp
        b[1][(k, kd)] = oi or 0
    return [(t, v[0], v[1]) for t, v in sorted(by.items())]


# ---------- the study ----------
def series(pc, rows):
    """-> [(minute, close %, high %, low %, vol, open %)]"""
    if not pc:
        return []
    f = lambda x: (x / pc - 1) * 100
    return [(m, f(c), f(h), f(l), v, f(o)) for m, o, h, l, c, v in rows]


def crossings(S, d):
    out = {}
    for x in CROSS:
        for m, c, h, l, v, o in S:
            if (h if d > 0 else -l) >= x:
                out[x] = m
                break
    return out


def vol_spikes(S, d, before):
    """5-min bars with volume 3x+ the median of the bars before, the candle going the move's way, before minute `before`"""
    out = []
    for i in range(3, len(S)):
        m, c, h, l, v, o = S[i]
        if before is not None and m >= before:
            break
        med = statistics.median([x[4] for x in S[:i]] or [0])
        if med > 0 and v >= 3 * med and (c - o) * d > 0:
            out.append((m, round(v / med, 1)))
    return out


def chain_story(CH, d):
    """-> lines: per reading, the writers just above / below the price, and the first time the near writers left"""
    lines, left, prev = [], None, {}
    for t, sp, oi in CH:
        if not sp:
            continue
        ks = sorted({k for k, kd in oi})
        above = next((k for k in ks if k > sp), None)
        below = next((k for k in reversed(ks) if k < sp), None)
        wall = above if d > 0 else below                      # the writers in the move's way
        floor_ = below if d > 0 else above                    # the writers behind it
        wk, fk = ("CE", "PE") if d > 0 else ("PE", "CE")
        w, f = oi.get((wall, wk)), oi.get((floor_, fk))
        pw, pf = prev.get((wall, wk)), prev.get((floor_, fk))
        dw = (w / pw - 1) * 100 if (w and pw) else None
        df = (f / pf - 1) * 100 if (f and pf) else None
        if left is None and dw is not None and dw <= -5:
            left = t
        lines.append("%s spot %g · %s %g %s%s · %s %g %s%s" % (t, sp, wk, wall or 0, int(w or 0), (" (%+.0f%%)" % dw) if dw is not None else "",
                                                             fk, floor_ or 0, int(f or 0), (" (%+.0f%%)" % df) if df is not None else ""))
        prev = dict(oi)
    return lines, left


def rotation(SER, smap):
    """-> (timeline lines, first rotation per level, the rising sector's members with their 1% / 2% times)"""
    secs = {n: [s for s in syms if s in SER and SER[s]] for n, syms in smap.items()}
    secs = {n: v for n, v in secs.items() if len(v) >= 3}
    mins = sorted({x[0] for v in SER.values() for x in v})
    at = {}
    for n, syms in secs.items():
        for m in mins:
            cc = [next((x[1] for x in reversed(SER[s]) if x[0] <= m), None) for s in syms]
            cc = [c for c in cc if c is not None]
            if len(cc) >= 3:
                at.setdefault(n, {})[m] = (sum(cc) / len(cc), sum(1 for c in cc if c > 0) / len(cc), sum(1 for c in cc if c < 0) / len(cc))
    first = {}
    for lv, (a, b) in (("L1 avg 0.5% · 65% of shares", (0.5, 0.65)), ("L2 avg 0.8% · 70%", (0.8, 0.70)), ("L3 avg 1.2% · 75%", (1.2, 0.75))):
        for m in mins:
            ups = [(at[n][m][0], n) for n in at if m in at[n] and at[n][m][0] >= a and at[n][m][1] >= b]
            dns = [(at[n][m][0], n) for n in at if m in at[n] and at[n][m][0] <= -a and at[n][m][2] >= b]
            if ups and dns:
                first[lv] = (m, max(ups)[1], max(ups)[0], min(dns)[1], min(dns)[0])
                break
    last = mins[-1] if mins else None
    order = sorted(at, key=lambda n: at[n].get(last, (0,))[0]) if last is not None else []
    show = order[:4] + order[-4:] if len(order) > 8 else order
    marks = [m for m in mins if m % 30 == 15 or m == last]
    tl = ["SECTOR      " + " ".join(hm(m) for m in marks)]
    for n in reversed(show):
        tl.append("%-11s " % n[:11].upper() + " ".join("%+5.1f" % at[n][m][0] if m in at[n] else "    ·" for m in marks))
    lead = []
    if order:
        top = order[-1]
        for s in secs[top]:
            cr = crossings(SER[s], 1)
            lead.append((cr.get(1, 9999), s, cr.get(2), round(SER[s][-1][1], 1)))
        lead.sort()
    return tl, first, (order[-1] if order else None, lead), (order[0] if order else None)


def study(day=None):
    day = day or dt.datetime.now(IST).strftime("%Y-%m-%d")
    fo = fo_list()
    smap = sector_map()
    SER = {}
    for s in fo:
        try:
            pc, rows = bars_of(s, day)
            S = series(pc, rows)
            if S:
                SER[s] = S
        except Exception:
            continue
    out = {"day": day, "n": len(SER), "movers": [], "rotation": {}}
    L = ["📋 PRE-MOVE STUDY %s · %d F&O shares with candles" % (day, len(SER))]
    if not SER:
        L.append("no 5-min candles for this day on the server")
        return L, out
    tl, first, (topsec, lead), botsec = rotation(SER, smap)
    L.append("")
    L.append("🔄 ROTATION - when money moving between sectors first showed:")
    for lv, v in first.items():
        L.append("  %s: %s  %s %+.1f%%  ←  %s %+.1f%%" % (lv, hm(v[0]), v[1], v[2], v[3], v[4]))
    if not first:
        L.append("  no clear rotation by these levels")
    L.append("  the day's sectors (avg %, every 30 min):")
    L += ["  " + x for x in tl]
    if topsec:
        L.append("  %s - who moved first (1%% · 2%% · now · minutes after the rotation showed):" % topsec.upper())
        r0 = next(iter(first.values()), None)
        for m1, s, m2, now in lead:
            L.append("    %-11s 1%% %s · 2%% %s · now %+.1f%%%s" % (s, hm(m1) if m1 < 9999 else "—", hm(m2) if m2 else "—", now,
                     (" · 2%% came %d min after" % (m2 - r0[0])) if (r0 and m2 and r0[1] == topsec) else ""))
    out["rotation"] = {"first": {k: [hm(v[0])] + list(v[1:]) for k, v in first.items()}, "top": topsec, "bottom": botsec,
                       "lead": [(s, hm(m1) if m1 < 9999 else None, hm(m2) if m2 else None, now) for m1, s, m2, now in lead]}
    mv = []
    for s, S in SER.items():
        up, dn = max(x[2] for x in S), -min(x[3] for x in S)
        d = 1 if up >= dn else -1
        ex = up if d > 0 else dn
        if ex >= 3 or s in NAMED:
            mv.append((ex, s, d))
    mv.sort(reverse=True)
    sec_of = {s: n for n, v in smap.items() for s in v}
    L.append("")
    L.append("🎯 THE MOVERS - the move vs what came before it:")
    for ex, s, d in mv[:25]:
        S = SER[s]
        cr = crossings(S, d)
        m2 = cr.get(2)
        G = gir_rows(day, s)
        vs = vol_spikes(S, d, m2)
        CH = chain_of(day, s)
        cl, left = chain_story(CH, d)
        early = []
        if G:
            early.append(("GIR " + G[0][1][:40], int(G[0][0][:2]) * 60 + int(G[0][0][3:5])))
        if vs:
            early.append(("volume %gx" % vs[0][1], vs[0][0]))
        r1 = next(iter(first.values()), None)                  # the rotation showing, for a share of the sector it went into / out of
        if r1 and ((d > 0 and sec_of.get(s) == r1[1]) or (d < 0 and sec_of.get(s) == r1[3])):
            early.append(("rotation %s %s" % ("into" if d > 0 else "out of", sec_of.get(s)), r1[0]))
        if left:
            early.append(("%s writers left" % ("call" if d > 0 else "put"), int(left[:2]) * 60 + int(left[3:5])))
        first_sign = min(early, key=lambda x: x[1]) if early else None
        warn = (m2 - first_sign[1]) if (first_sign and m2) else None
        L.append("")
        L.append("%s %s %+.1f%% (close %+.1f%%) · %s" % ("▲" if d > 0 else "▼", s, ex * d, S[-1][1], sec_of.get(s, "")))
        L.append("  crossed: " + " · ".join("%g%% %s" % (x, hm(cr[x])) for x in CROSS if x in cr))
        if first_sign:
            L.append("  first sign: %s at %s%s" % (first_sign[0], hm(first_sign[1]), (" = %d min before 2%%" % warn) if warn is not None else ""))
        for t, w in G[:6]:
            L.append("  %s %s" % (t, w[:90]))
        if vs:
            L.append("  volume spikes before 2%%: %s" % " · ".join("%s %gx" % (hm(m), x) for m, x in vs[:4]))
        if cl:
            L.append("  chain: " + " | ".join(cl[:6]))
        out["movers"].append({"s": s, "d": d, "ex": round(ex, 2), "close": round(S[-1][1], 2), "cross": {str(k): hm(v) for k, v in cr.items()},
                              "gir": G[:12], "vol": [(hm(m), x) for m, x in vs], "chain": cl, "writers_left": left,
                              "first_sign": (first_sign[0], hm(first_sign[1])) if first_sign else None, "warn_min": warn, "sector": sec_of.get(s)})
    W = [x["warn_min"] for x in out["movers"] if x["warn_min"] is not None]
    L.append("")
    L.append("SUMMARY: %d movers · an early sign before 2%% for %d · median warning %s min" % (len(out["movers"]), sum(1 for w in W if w > 0),
                                                                                             int(statistics.median(W)) if W else "—"))
    return L, out


def send_tg(text):
    env = {}
    try:
        for line in open("/home/globalbot/.env"):
            m = re.match(r"\s*(?:export\s+)?([A-Z_]+)\s*=\s*(.*?)\s*$", line)
            if m:
                env[m.group(1)] = m.group(2).strip("'\"")
    except Exception:
        pass
    tok = env.get("TELEGRAM_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
    box = env.get("TG_CHAT_BOX")
    try:
        import tglanes
        chat = tglanes.chat_for("📋 PRE-MOVE STUDY", box)
    except Exception:
        chat = box
    if not tok or not chat:
        print("no Telegram token / chat - the report is in the file only"); return 0
    import requests
    a, b = (str(chat).rsplit(":", 1) + [None])[:2] if ":" in str(chat) else (str(chat), None)
    parts, cur = [], ""
    for ln in text.split("\n"):
        if len(cur) + len(ln) > 3800:
            parts.append(cur); cur = ""
        cur += ln + "\n"
    parts.append(cur)
    n = 0
    for p in parts:
        d = {"chat_id": a, "text": p}
        if b:
            d["message_thread_id"] = b
        try:
            r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=30)
            n += 1 if r.ok else 0
            time.sleep(1.2)
        except Exception as ex:
            print("telegram: %s" % str(ex)[:80])
    return n


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    L, out = study(a[0] if a else None)
    txt = "\n".join(L)
    print(txt)
    os.makedirs(os.path.join(BASE, "data"), exist_ok=True)
    open(os.path.join(BASE, "data", "premove_%s.txt" % out["day"]), "w").write(txt)
    json.dump(out, open(os.path.join(BASE, "data", "premove_%s.json" % out["day"]), "w"), default=str)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % send_tg(txt))
PY_MAIN
cat > $D/premovetest.py <<'PY_TEST'
#!/usr/bin/env python3
"""premovetest.py - the pre-move study on a made-up day: PSU banks rise from 10:00 (PNB late), IT falls, COCHINSHIP's call
writers leave at 10:30 before it crosses 2% at 11:00, its volume spikes at 10:40"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import premove as P
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
BANKS, IT = ["SBIN", "UNIONBANK", "CANBK", "PNB"], ["TCS", "INFY", "HCLTECH"]
P.fo_list = lambda: BANKS + IT + ["COCHINSHIP", "FLAT1"]
P.sector_map = lambda: {"PSU Banks": BANKS, "IT": IT, "Defence": ["COCHINSHIP", "FLAT1", "X9"]}
def path(s, m):
    t = m - 555
    if s in BANKS:
        st = 600 if s != "PNB" else 690                       # PNB starts 90 min later
        return 0.0 if m < st else min(5.0, (m - st) / 30.0)
    if s in IT:
        return 0.0 if m < 600 else -min(2.5, (m - 600) / 40.0)
    if s == "COCHINSHIP":
        return 0.5 if m < 640 else min(4.3, 0.5 + (m - 640) / 12.0)
    return 0.1
def bars(s, day):
    rows = []
    for m in range(555, 930, 5):
        c0, c1 = 100 * (1 + path(s, m) / 100), 100 * (1 + path(s, m + 5) / 100)
        v = 5000 if (s == "COCHINSHIP" and m == 640) else 1000
        rows.append((m, c0, max(c0, c1), min(c0, c1), c1, v))
    return 100.0, rows
P.bars_of = bars
P.gir_rows = lambda day, s: [("10:42", "alert CE 🚀 RUNNING ▲ COCHINSHIP +0.5%")] if s == "COCHINSHIP" else []
def chain(day, s):
    if s != "COCHINSHIP":
        return []
    return [("10:15", 1255, {(1260, "CE"): 1000, (1250, "PE"): 800}), ("10:30", 1256, {(1260, "CE"): 850, (1250, "PE"): 900}),
            ("10:45", 1262, {(1270, "CE"): 900, (1260, "PE"): 700, (1260, "CE"): 600})]
P.chain_of = chain
L, out = P.study("2026-11-09")
txt = "\n".join(L); print(txt); print("-" * 40)
rot = out["rotation"]
check("a rotation found: PSU BANKS up, IT down (%s)" % rot["first"], any(v[1] == "PSU Banks" and v[3] == "IT" for v in rot["first"].values()))
check("PNB is the laggard of the rising sector (%s)" % (rot["lead"][-1],), rot["lead"][-1][0] == "PNB")
c = next(x for x in out["movers"] if x["s"] == "COCHINSHIP")
check("COCHINSHIP: the call writers left at 10:30 (%s)" % c["writers_left"], c["writers_left"] == "10:30")
check("COCHINSHIP: first sign before 2%% with a warning in minutes (%s, %s min)" % (str(c["first_sign"]), c["warn_min"]), c["warn_min"] and c["warn_min"] > 0)
check("FLAT1 (no move, not named) not in the movers", all(x["s"] != "FLAT1" for x in out["movers"]))
p = next(x for x in out["movers"] if x["s"] == "PNB")
check("PNB: the rotation into PSU banks is its first sign, well before its 2%% (%s, %s min)" % (str(p["first_sign"]), p["warn_min"]), p["first_sign"] and p["first_sign"][0].startswith("rotation") and p["warn_min"] >= 90)
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 premovetest.py > /tmp/premovetest.log 2>&1 || { tail -8 /tmp/premovetest.log; echo "the study's own test failed - nothing run"; exit 1; }
echo "    study test passed"
python3 premove.py ${1:-}
