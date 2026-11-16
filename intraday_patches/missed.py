#!/usr/bin/env python3
"""missed.py - READ ONLY (v352/353: a real CE/PE call apart from a news / list mention or a "WATCH, not a trade yet" / "IN DOUBT" line). TODAY'S MISSED MONEY (Rama, 16 Nov: "it was a good day - I missed them. Replay the shares it alerted LATE, the ones
it NOTICED but never rang, and the ones it never noticed - if the alarm had come with the right direction, how much could I have made?").
For every F&O share that moved 2.5%+ today (from the open, either way):
  · the move: its side, size, the 5-min bar it started (0.5% its way)
  · GIR NOTICED: the first row GIR wrote about it today in ANY of its own logs (tomorrow.db: first moves, surges, book moves, the desk's calls,
    cards, turns ... + the engine's "JUDGE NO" lines) - the right side only
  · GIR RANG: its first line in the alert list (what reached the page / phone). NOTE: alerts sent while the database was locked (10:55-11:10,
    13:20-13:50) may be missing here although Telegram rang
  · the money, 1 lot, an at-the-money option ~ half the share's rupee move, stop 2.5% on the share, half out at +1.5%, the rest at 15:10, before
    charges: had it rung when GIR FIRST NOTICED · when it really rang
python3 missed.py [YYYY-MM-DD]     -> prints, saves data/missed.txt"""
import os, re, sys, json, sqlite3, subprocess, urllib.request, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import movescan as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
L = []
def say(s=""):
    L.append(s); print(s)
UP = re.compile(r"^(CE|UP|BUY|LONG|1|\+1|▲|BULL)", re.I); DN = re.compile(r"^(PE|DOWN|SELL|SHORT|-1|▼|BEAR)", re.I)


NOTCALL = re.compile(r"not a trade|IN DOUBT|WATCH,|^🔍|^🔎|^📰|^📄", re.I)    # v353: GIR said it, but did not say BUY


def side_of(v):
    v = str(v if v is not None else "").strip()
    return 1 if UP.match(v) else -1 if DN.match(v) else 0


def hm5(t):
    t = str(t or "")[:5]
    return t if re.fullmatch(r"\d\d:\d\d", t) else None


def events(day):
    """{sym: [(hm, side, source)]} from every tomorrow.db table with day + t + sym, and the engine's JUDGE NO lines"""
    ev, rang = {}, {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        for (tb,) in c.execute("select name from sqlite_master where type='table'").fetchall():
            cols = [r[1] for r in c.execute("pragma table_info(%s)" % tb)]
            if not {"day", "t", "sym"} <= set(cols):
                continue
            sc = next((x for x in ("side", "dir", "kind") if x in cols), None)
            for t, s, sd in c.execute("select t, sym, %s from %s where day=?" % (sc or "''", tb), (day,)):
                h = hm5(t)
                if not h or not s:
                    continue
                if tb == "alerts":
                    continue                                                   # v353: read below, with its text
                else:
                    ev.setdefault(s, []).append((h, side_of(sd), tb))
        if "text" in [r[1] for r in c.execute("pragma table_info(alerts)")]:
            for t, s, sd, tx in c.execute("select t, sym, side, text from alerts where day=?", (day,)):
                h = hm5(t)
                if not h or not s:
                    continue
                tx = str(tx or "")
                if NOTCALL.search(tx):                                         # v353: "WATCH, not a trade yet" / "IN DOUBT" / a WHY line - a mention
                    ev.setdefault(s, []).append((h, side_of(sd), "said but not a trade: " + tx.split("\n")[0][:50])); rang.setdefault(s, []).append((h, 0))
                else:
                    rang.setdefault(s, []).append((h, side_of(sd)))
        c.close()
    except Exception as ex:
        say("  (tomorrow.db: %s)" % ex)
    try:
        out = subprocess.run("journalctl -u gir-intraday --since '%s 00:00' --until '%s 23:59' -o cat --no-pager 2>/dev/null | grep 'JUDGE NO'" % (day, day),
                             shell=True, capture_output=True, text=True, timeout=60).stdout
        for ln in out.splitlines():
            m = re.search(r"(\d\d:\d\d):\d\d JUDGE NO (\S+) (.*)", ln)
            if m:
                ev.setdefault(m.group(2), []).append((m.group(1), 0, "judged NO: " + m.group(3)[:60]))
    except Exception:
        pass
    return ev, rang


def at(rows, h):
    i = next((j for j, r in enumerate(rows) if r["hm"] >= h), None)
    return (i, rows[i]["c"]) if i is not None else (None, None)


def main():
    day = sys.argv[1] if len(sys.argv) > 1 else str(dt.datetime.now(IST).date())
    import dashserve
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    H = M.get("/home", tok); syms = sorted({s for x in (H.get("sectors") or []) for s in (x.get("syms") or [])})
    LOT = M.lots(); rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    P = {}
    for s in syms:
        try:
            P[s] = M.prep(M.days_of(M.get("/hist?sym=%s&days=15" % s, tok)))
        except Exception:
            pass
    mv = []
    for s in P:
        if day not in P[s]:
            continue
        rows = P[s][day]["rows"]; o0 = P[s][day]["o0"]
        up = max(r["h"] for r in rows) / o0 - 1; dn = 1 - min(r["l"] for r in rows) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size >= 0.025:
            start = next((r["hm"] for r in rows if r["ro"] * dr >= 0.005), rows[0]["hm"])
            mv.append({"s": s, "dir": dr, "size": size, "start": start})
    mv.sort(key=lambda m: -m["size"])
    ev, rang = events(day)
    say("💸 TODAY'S MISSED MONEY · %s · %d F&O shares moved 2.5%%+ · 1 lot, at-the-money option ~ half the rupee move, stop 2.5%%, half at +1.5%%, out 15:10, before charges" % (day, len(mv)))
    say("  %-11s %-6s %-6s  %-34s %-7s %-16s %10s %10s" % ("SHARE", "MOVE", "START", "GIR NOTICED FIRST (right side)", "CE/PE", "VERDICT", "₹ AT NOTICE", "₹ AS CALLED"))
    T = {"on": [0, 0, 0], "late": [0, 0, 0], "mention": [0, 0, 0], "silent": [0, 0, 0], "never": [0, 0, 0]}
    for m in mv:
        s, dr = m["s"], m["dir"]; rows = P[s][day]["rows"]
        E = sorted([e for e in ev.get(s, []) if e[1] in (dr, 0)])
        R = sorted([r for r in rang.get(s, []) if r[1] == dr])                 # v352: a real CE / PE call the right way
        MN = sorted([r for r in rang.get(s, []) if r[1] == 0])                 # a mention without a side (news, results, a list line)
        nt = E[0] if E else None; rt = R[0][0] if R else None
        for x in ([R[0]] if R else []) + ([MN[0]] if MN else []):
            if not nt or x[0] < nt[0]:
                nt = (x[0], dr, "a CE/PE call" if x in R else "a news / list mention")
        def money(h):
            if not h:
                return None
            i, px = at(rows, h)
            return rs(M.sim(rows[i + 1:], px, dr, 0.025), px, s) if i is not None else None
        mn, mr = money(nt[0] if nt else None), money(rt)
        if rt and M.mins(m["start"], rt) <= 10:
            v = "on"
        elif rt:
            v = "late"
        elif nt and MN:
            v = "mention"
        elif nt:
            v = "silent"
        else:
            v = "never"
        T[v][0] += 1; T[v][1] += mn or 0; T[v][2] += mr or 0
        say("  %-11s %s%-5s %-6s  %-34s %-7s %-16s %10s %10s" % (s, "▲" if dr > 0 else "▼", "%.1f%%" % (m["size"] * 100), m["start"],
            ("%s %s" % (nt[0], nt[2]))[:34] if nt else "—", rt or "—", {"on": "ON TIME", "late": "LATE %d min" % M.mins(m["start"], rt) if rt else "", "mention": "ONLY A MENTION", "silent": "NOTICED, NO ALARM", "never": "NEVER NOTICED"}[v],
            "{:,.0f}".format(mn) if mn is not None else "—", "{:,.0f}".format(mr) if mr is not None else "—"))
    say("")
    for k, lab in (("on", "CE/PE call on time"), ("late", "CE/PE call LATE"), ("mention", "only mentioned, no CE/PE call"), ("silent", "noticed, nothing rang"), ("never", "never noticed")):
        say("  %-26s %3d shares · had it rung at the first notice: ₹%s · as it really rang: ₹%s" % (lab, T[k][0], "{:,.0f}".format(T[k][1]), "{:,.0f}".format(T[k][2])))
    tot = sum(T[k][1] for k in T)
    say("  ALL: had GIR rung every move it noticed, at the first notice, the right side: about ₹%s (1 lot each, before charges)" % "{:,.0f}".format(tot))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "missed.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/missed.txt")


if __name__ == "__main__":
    main()
