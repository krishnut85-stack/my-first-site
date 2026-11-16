#!/usr/bin/env python3
"""movescan.py - patch 347: READ ONLY. 🎯 THE MOVE SCANNER, REPLAYED (Rama, 16 Nov: "most alerts come after the move - SYRMA, SAIL, no signal at all
- find the shares for CE and PE before they move"). Scores every F&O share every 5 minutes on what comes BEFORE a big move, then replays it on
GIR's own saved 5-minute bars (about 30 trading days): when it would have flagged, how early, how much move was left, the false alarms.
  the score (one direction at a time, max 9):  price out of the first 15 minutes' range (1) · on the right side of VWAP (1) · moving 0.4%+ from the
  open but not over 2.5% (1) · volume vs its own normal at that time of day 1.5x (1) / 2.5x (2) · its SECTOR the same way 0.4%+ with 65% of its
  shares (2) / 0.2%+ (1) · NIFTY the same way 0.2%+ (1) · one flag per share per day, none after 14:30
  a HIT = the price goes 1.5%+ the flagged way before 0.75% against (by the close) · a BIG MOVE = a share going 2.5%+ one way from the open
  thresholds tried 5 / 6 / 7: the one that catches the most big moves early with at most ~20 flags a day is chosen - by the numbers
Data via this server's own page feeds (/home, /hist) and NSE's futures file for the size weights. Nothing is changed, nothing is sent.
python3 movescan.py [days]      -> prints the report, saves data/movescan.txt (download: girtrader.com/doctor.txt after `cp`)"""
import os, sys, json, glob, time, math, sqlite3, urllib.request, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "movescan.txt")
L = []
def say(s=""):
    L.append(s); print(s)


def get(path, tok, base="http://127.0.0.1:8090"):
    u = base + path + ("&" if "?" in path else "?") + "k=" + urllib.request.quote(tok)
    return json.loads(urllib.request.urlopen(u, timeout=60).read() or b"null")


def days_of(b):
    """bars -> {date: [(t, o, h, l, c, v), ...]}"""
    out = {}
    for i, t in enumerate(b.get("t") or []):
        d = dt.datetime.fromtimestamp(t, IST)
        out.setdefault(str(d.date()), []).append((d.strftime("%H:%M"), b["o"][i], b["h"][i], b["l"][i], b["c"][i], b["v"][i] or 0))
    return out


def prep(B):
    """per share: {date: dict(arrays)} with prev close, the open range, vwap, cumulative volume"""
    out, prev_c = {}, None
    for d in sorted(B):
        bars = [x for x in B[d] if "09:15" <= x[0] <= "15:29"]
        if len(bars) < 20:
            prev_c = bars[-1][4] if bars else prev_c
            continue
        o0 = bars[0][1]; pc = prev_c or o0
        orh = max(x[2] for x in bars[:3]); orl = min(x[3] for x in bars[:3])
        pv = vv = cv = 0.0; rows = []
        for (hm, o, h, l, c, v) in bars:
            tp = (h + l + c) / 3; pv += tp * v; vv += v; cv += v
            rows.append({"hm": hm, "h": h, "l": l, "c": c, "vwap": pv / vv if vv else c, "cv": cv, "rp": c / pc - 1, "ro": c / o0 - 1})
        out[d] = {"o0": o0, "pc": pc, "orh": orh, "orl": orl, "rows": rows}
        prev_c = bars[-1][4]
    return out


def scan(P, SEC, W, NIF, th, day_cap=12, per_bar=2):
    """v2 (16 Nov, after the first replay: every flag landed at 09:30, the big gap movers were missed):
    · volume 1.5x its normal at that time is REQUIRED (the 09:30 noise had 0.4-0.9x)
    · momentum REQUIRED: the last 15 minutes 0.3%+ the same way (a move still running, not a stale open)
    · strength from YESTERDAY'S CLOSE, no 2.5% cap - a gap mover still counts while it keeps going
    · every 5 minutes only the best `per_bar` new shares (highest score), at most `day_cap` a day - a ranked list, not first-come"""
    dates = sorted({d for s in P for d in P[s]})
    flags = {}
    for k, d in enumerate(dates):
        prev10 = dates[max(0, k - 10):k]
        if len(prev10) < 5:
            continue
        RP = {s: {r["hm"]: r["rp"] for r in P[s][d]["rows"]} for s in P if d in P[s]}
        BASE = {}
        for s in P:
            if d not in P[s]:
                continue
            b_ = {}
            for pd_ in prev10:
                if pd_ in P[s]:
                    for r in P[s][pd_]["rows"]:
                        b_.setdefault(r["hm"], []).append(r["cv"])
            BASE[s] = b_
        hms = sorted({r["hm"] for s in P if d in P[s] for r in P[s][d]["rows"] if "09:20" <= r["hm"] <= "14:30"})   # v3: from 09:20 - the gap movers
        done, F = set(), []
        for hm in hms:
            cand = []
            for s in P:
                if s in done or d not in P[s]:
                    continue
                day = P[s][d]; rows = day["rows"]
                i = next((j for j, r in enumerate(rows) if r["hm"] == hm), None)
                if i is None or i < 1:
                    continue
                r = rows[i]; bl = BASE[s].get(hm) or []
                volx = r["cv"] / (sum(bl) / len(bl)) if bl and sum(bl) > 0 else 1.0
                if volx < 1.5:
                    continue
                mom = r["c"] / (rows[i - 3]["c"] if i >= 3 else day["o0"]) - 1
                peers = [p for p in SEC.get(s, []) if p != s and p in RP]
                pr = [(RP[p].get(hm), W.get(p, 1.0)) for p in peers if RP[p].get(hm) is not None]
                sw = sum(w for _, w in pr); sec = sum(x * w for x, w in pr) / sw if sw else 0.0
                nif = (NIF.get(d) or {}).get(hm, 0.0)
                for dr in (1, -1):
                    if mom * dr < 0.003 or r["rp"] * dr < 0.005:
                        continue
                    sc = 0
                    sc += 1 if (r["c"] > day["orh"] if dr > 0 else r["c"] < day["orl"]) else 0
                    sc += 1 if (r["c"] - r["vwap"]) * dr > 0 else 0
                    sc += 2 if volx >= 2.5 else 1
                    sc += 1 if mom * dr >= 0.006 else 0
                    same = sum(1 for x, _ in pr if x * dr > 0) / len(pr) if pr else 0
                    if pr and same < 0.5 and volx < 4:                     # v3: against its own sector - only a share with its OWN big news volume (4x+) counts
                        continue
                    sc += 2 if (sec * dr >= 0.004 and same >= 0.65) else 1 if sec * dr >= 0.002 else 0
                    sc += 1 if volx >= 4 else 0
                    sc += 1 if nif * dr >= 0.002 else 0
                    if sc >= th:
                        cand.append((sc, volx, s, dr, i, r, sec, same, abs(r["rp"]) * min(volx, 10)))
            cand.sort(key=lambda x: (-x[0], -x[8]))                         # v3: the strongest first - score, then move x volume
            for sc, volx, s, dr, i, r, sec, same, _ in cand[:per_bar]:
                if len(F) >= day_cap:
                    break
                done.add(s)
                rest = P[s][d]["rows"][i + 1:]; P0 = r["c"]; hit = False; mfe = 0.0; mn = None
                for j, x in enumerate(rest):
                    fav = ((x["h"] / P0 - 1) if dr > 0 else (1 - x["l"] / P0)); adv = ((1 - x["l"] / P0) if dr > 0 else (x["h"] / P0 - 1))
                    mfe = max(mfe, fav)
                    if adv >= 0.0075:
                        break
                    if fav >= 0.015:
                        hit = True; mn = (j + 1) * 5; break
                pnl = sim(P[s][d]["rows"][i + 1:], P0, dr)
                F.append({"pnl": pnl, "s": s, "hm": hm, "dir": dr, "sc": sc, "px": P0, "volx": volx, "sec": sec, "same": same, "hit": hit, "mins": mn, "mfe": mfe})
        flags[d] = F
    return flags


def sim(rest, P0, dr):
    """the share's % result of one trade: stop -0.75%; at +1.5% half is booked and the stop goes to the entry; the rest out at 15:10"""
    half = None; stop = -0.0075
    for x in rest:
        lo = ((x["l"] / P0 - 1) if dr > 0 else (1 - x["h"] / P0)); hi = ((x["h"] / P0 - 1) if dr > 0 else (1 - x["l"] / P0))
        if lo <= stop:
            return stop if half is None else (half + stop) / 2
        if half is None and hi >= 0.015:
            half, stop = 0.015, 0.0
        if x["hm"] >= "15:10":
            c = (x["c"] / P0 - 1) * dr
            return c if half is None else (half + c) / 2
    c = (rest[-1]["c"] / P0 - 1) * dr if rest else 0.0
    return c if half is None else (half + c) / 2


def big_moves(P, d):
    out = []
    for s in P:
        if d not in P[s]:
            continue
        rows = P[s][d]["rows"]; o0 = P[s][d]["o0"]
        up = max(r["h"] for r in rows) / o0 - 1; dn = 1 - min(r["l"] for r in rows) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size < 0.025:
            continue
        start = next((r["hm"] for r in rows if r["ro"] * dr >= 0.005), None)
        half = next((r["hm"] for r in rows if r["ro"] * dr >= size / 2), None)
        out.append({"s": s, "dir": dr, "size": size, "start": start, "half": half})
    return sorted(out, key=lambda m: -m["size"])[:10]                       # v3: the day's 10 biggest movers


def mins(a, b):
    return (int(b[:2]) * 60 + int(b[3:])) - (int(a[:2]) * 60 + int(a[3:]))


def evaluate(P, flags):
    days = sorted(flags); tot = {"flags": 0, "hits": 0, "big": 0, "caught": 0, "early": []}
    for d in days:
        F = flags[d]; tot["flags"] += len(F); tot["hits"] += sum(1 for f in F if f["hit"])
        for m in big_moves(P, d):
            tot["big"] += 1
            f = next((f for f in F if f["s"] == m["s"] and f["dir"] == m["dir"]), None)
            if f and m["half"] and f["hm"] <= m["half"]:
                tot["caught"] += 1; tot["early"].append(mins(m["start"], f["hm"]) if m["start"] else 0)
    n = len(days) or 1
    return {"days": len(days), "per_day": tot["flags"] / n, "hit": tot["hits"] / tot["flags"] if tot["flags"] else 0, "big": tot["big"], "caught": tot["caught"],
            "cover": tot["caught"] / tot["big"] if tot["big"] else 0, "after_start": (sorted(tot["early"])[len(tot["early"]) // 2] if tot["early"] else None)}


def gir_first(day):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        R = c.execute("select sym, min(t) from alerts where day=? and sym!='' group by sym", (day,)).fetchall(); c.close()
        return {s: t[:5] for s, t in R}
    except Exception:
        return {}


def lots():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        R = dict(c.execute("select sym, lot from fo_list").fetchall()); c.close(); return R
    except Exception:
        return {}


def money(P, fl):
    """₹ per trade = the share's % move x its price x its lot x 0.5 (an at-the-money option moves about half the share's rupees), 1 lot,
    before charges. The scanner's flags (its own exit rule) vs GIR's own cards today (tomorrow.db wind_cards)."""
    LOT = lots(); days = sorted(fl)
    if not days:
        return
    rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    say(""); say("💰 THE MONEY (1 lot each, an at-the-money option ~ half the share's rupee move, before charges)")
    for d in days[-3:]:
        F = fl[d]; tot = sum(rs(f["pnl"], f["px"], f["s"]) for f in F); w = sum(1 for f in F if f["pnl"] > 0)
        say("  %s · the scanner: %d trades · %d won · ₹%s" % (d, len(F), w, "{:,.0f}".format(tot)))
    day = days[-1]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        R = c.execute("select sym, entry, res from wind_cards where day=?", (day,)).fetchall(); c.close()
    except Exception:
        R = []
    if R:
        g = sum(rs((res or 0) / 100.0, e or 0, s) for s, e, res in R); fo = sum(1 for s, _, _ in R if s in LOT)
        say("  %s · GIR's own cards: %d cards (%d of them F&O) · %d won · ₹%s on the F&O ones" % (day, len(R), fo, sum(1 for *_, r in R if (r or 0) > 0),
                                                                                     "{:,.0f}".format(sum(rs((res or 0) / 100.0, e or 0, s) for s, e, res in R if s in LOT))))
    say("  %s · each scanner trade:" % day)
    for f in sorted(fl[day], key=lambda f: -rs(f["pnl"], f["px"], f["s"])):
        say("    %s %-11s %s at ₹%s · lot %s · %+.2f%% on the share · ₹%s" % (f["hm"], f["s"], "CE" if f["dir"] > 0 else "PE", "{:,.2f}".format(f["px"]), LOT.get(f["s"], "?"),
                                                                       f["pnl"] * 100, "{:,.0f}".format(rs(f["pnl"], f["px"], f["s"]))))
    top = big_moves(P, day)
    pot = sum(rs(m["size"] * 0.6, P[m["s"]][day]["o0"], m["s"]) for m in top)
    say("  %s · if you had caught 60%% of each of the 10 biggest moves (the most an early alert can give): about ₹%s" % (day, "{:,.0f}".format(pot)))


def main():
    ndays = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 30
    import dashserve
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    H = get("/home", tok); SECS = H.get("sectors") or []
    SEC = {}
    for x in SECS:
        for s in x.get("syms") or []:
            SEC[s] = x["syms"]
    syms = sorted(SEC)
    W = {}
    fs = sorted(glob.glob(os.path.join(D, "data", "nsefutx_*.json")))
    for f in reversed(fs):
        try:
            N = json.load(open(f))
            if N:
                W = {s: sum((r[2] or 0) * (r[1] or 0) for r in R) for s, R in N.items()}; break
        except Exception:
            pass
    say("🎯 MOVE SCANNER replay v2 · %s IST · %d F&O shares · %d sectors · size weights %s" % (dt.datetime.now(IST).strftime("%d %b %H:%M"), len(syms), len(SECS), "from NSE's futures file" if W else "equal"))
    P = {}
    for i, s in enumerate(syms):
        try:
            b = get("/hist?sym=%s&days=%d" % (urllib.request.quote(s), ndays), tok)
            if b and b.get("t"):
                P[s] = prep(days_of(b))
        except Exception:
            pass
    NIF = {}
    try:
        nb = get("/hist?sym=NIFTY50&days=%d" % ndays, tok)
        for d, day in prep(days_of(nb)).items():
            NIF[d] = {r["hm"]: r["rp"] for r in day["rows"]}
    except Exception:
        pass
    say("  read %d shares' 5-min bars · NIFTY %s" % (len(P), "yes" if NIF else "NOT read (market tide left out)"))
    best = None
    for th in (4, 5, 6, 7):
        fl = scan(P, SEC, W, NIF, th); ev = evaluate(P, fl)
        say("  threshold %d: %4.1f flags a day · hit %3.0f%% (1.5%%+ before -0.75%%) · the day's 10 biggest movers caught before half-way: %d of %d (%3.0f%%) · median %s min after the move started" % (
            th, ev["per_day"], ev["hit"] * 100, ev["caught"], ev["big"], ev["cover"] * 100, ev["after_start"]))
        sc = ev["cover"] * (0.5 + ev["hit"]) if ev["per_day"] <= 22 else -1
        if best is None or sc > best[0]:
            best = (sc, th, fl, ev)
    _, th, fl, ev = best
    say(""); say("  CHOSEN: threshold %d - catches %d%% of the big moves before half-way, %d%% of its flags hit 1.5%%+" % (th, round(ev["cover"] * 100), round(ev["hit"] * 100)))
    days = sorted(fl)
    for d in days[-2:]:
        G = gir_first(d)
        say(""); say("  ── %s: the scanner's flags (time · share · side · score · then)  vs  GIR's first alert that day" % d)
        for f in fl[d]:
            say("   %s  %-11s %s  score %d  vol %.1fx  sector %+.1f%% (%d%% same)  → %s   GIR first alert: %s" % (f["hm"], f["s"], "▲ CE" if f["dir"] > 0 else "▼ PE", f["sc"], f["volx"], f["sec"] * 100, f["same"] * 100,
                ("HIT +1.5%% in %d min" % f["mins"]) if f["hit"] else "no (best %.1f%%)" % (f["mfe"] * 100), G.get(f["s"], "none")))
        mv = big_moves(P, d)
        caught = {f["s"] for f in fl[d]}
        miss = [m for m in mv if m["s"] not in caught]
        if miss:
            say("   big moves NOT flagged: " + " · ".join("%s %s%.1f%% from %s" % (m["s"], "+" if m["dir"] > 0 else "−", m["size"] * 100, m["start"]) for m in sorted(miss, key=lambda m: -m["size"])[:12]))
    money(P, fl)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write("\n".join(L) + "\n")
    say(""); say("saved data/movescan.txt")


if __name__ == "__main__":
    main()
