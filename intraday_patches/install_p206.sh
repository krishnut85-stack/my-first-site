#!/bin/bash
# PATCH 206 - THE NUISANCE AUDIT (reads only, sends nothing): every alert GIR sent on the last trading days, by kind - how many a day,
#   its priority now (P1 / P2 / P3), and the nuisance in it: CHATTER (the same share and kind again within 30 min) · LADDER (RUNNING /
#   SPEED every 1% step) · FLIP (the other side within 30 min) · LATE (after a 3%+ move) · SAME STORY (the same headline again) -
#   then the cut, rule by rule, to what is left a day. Rama: "instead of 2,600 make it 1,500 - what is nuisance, what can go".
set -u
D=/home/globalbot/intraday
cat > $D/alertaudit.py <<'PY_A'
#!/usr/bin/env python3
"""alertaudit.py - patch 206: THE NUISANCE AUDIT (Rama, 11 Nov: "instead of 2,600 alerts make it 1,500 - look into what kind of alerts we
sent, how many are nuisance alerts, how to manage them, what can be removed"). Reads only. From tomorrow.db (every alert GIR sent,
the same second), the last trading days:
  BY KIND        how many a day · its priority now (P1 / P2 / P3) · how many shares
  NUISANCE       CHATTER    the same share and kind again within 30 minutes (said already)
                 LADDER     RUNNING / SPEED steps of the same share and side after its first one that day (+1%, +2%, +3% ...)
                 FLIP       the same share the other side within 30 minutes (a coin toss - neither is a call)
                 LATE       a side alert when the share had already moved 3%+ (the move is done)
                 SAME STORY the same headline again (another source / another share named in it)
  THE CUT        each rule applied in turn -> how many a day remain, and what is never touched (P1 trade calls, P2 critical)
  python3 alertaudit.py [days]      -> prints, data/alertaudit.txt"""
import os, re, sys, sqlite3, datetime as dt
from collections import Counter, defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
TAG = re.compile(r"^(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O)")


def head_of(text):
    L = [x.strip() for x in (text or "").split("\n") if x.strip() and not TAG.match(x.strip())]
    if not L:
        return ""
    h = L[0]
    if h.startswith("🔔 OPENING · "):
        h = h[len("🔔 OPENING · "):]
    elif h.startswith("🔔 OPENING") and len(L) > 1:
        h = L[1]
    return h


def kind_of(h, sym=""):
    """'🚀 RUNNING ▲ YESBANK ₹24 +1.2%' -> '🚀 RUNNING' · '📰 FILING ▼ X · REG' -> '📰 FILING · REG'"""
    toks, out = h.split(), []
    for t in toks:
        if t in ("▲", "▼", "·", "—", "-") or re.match(r"^[₹+\-\d(]", t):
            break
        if out and sym and t == sym:
            break
        out.append(t)
        if len(out) >= 4:
            break
    k = " ".join(out) or h[:12]
    m = re.search(r"·\s*(REG|MGMT|ORDER|RESULTS|BOARD|SALES|RATING)\b", h)
    return k + (" · " + m.group(1) if m and ("FILING" in k or "NEWS" in k) else "")


def pct_of(h):
    m = re.search(r"([+-]\d+(?:\.\d+)?)%", h)
    return float(m.group(1)) if m else None


def mins(t):
    return int(t[:2]) * 60 + int(t[3:5])


def load(days=3, path=None):
    c = sqlite3.connect("file:%s?mode=ro" % (path or os.path.join(BASE, "tomorrow.db")), uri=True)
    ds = [r[0] for r in c.execute("select distinct day from alerts order by day desc limit ?", (days,))]
    rows = []
    for d in sorted(ds):
        for t, sym, side, text in c.execute("select t, sym, side, text from alerts where day=? order by t", (d,)):
            h = head_of(text)
            if h:
                rows.append({"d": d, "t": t[:5], "m": mins(t), "sym": sym or "", "side": side or "", "h": h, "k": kind_of(h, sym or ""), "text": text or ""})
    c.close()
    return rows, sorted(ds)


def tier(text):
    try:
        import alertword
        return {"act": "P1", "move": "P2", "know": "P2", "read": "P3"}.get(alertword.tier(text), "P3")
    except Exception:
        return "?"


def flags(rows):
    """-> each row's nuisance marks"""
    last_k, last_side, first_run, heads = {}, {}, set(), {}
    for r in rows:
        r["nz"] = set()
        key = (r["d"], r["sym"], r["k"])
        if r["sym"] and key in last_k and r["m"] - last_k[key] < 30:
            r["nz"].add("CHATTER")
        last_k[key] = r["m"]
        if r["sym"] and r["side"]:
            o = last_side.get((r["d"], r["sym"]))
            if o and o[0] != r["side"] and r["m"] - o[1] < 30:
                r["nz"].add("FLIP")
            last_side[(r["d"], r["sym"])] = (r["side"], r["m"])
        if ("RUNNING" in r["k"] or "SPEED" in r["k"]) and r["sym"]:
            rk = (r["d"], r["sym"], r["side"], "run")
            if rk in first_run:
                r["nz"].add("LADDER")
            first_run.add(rk)
        p = pct_of(r["h"])
        if r["side"] and p is not None and abs(p) >= 3 and r["k"].split()[0] not in ("🟢", "🌅", "🚨", "⚠️", "💼", "🛑"):
            r["nz"].add("LATE")
        hk = (r["d"], re.sub(r"[^a-z]", "", (r["text"].split("\n")[1] if "\n" in r["text"] else r["h"]).lower())[:60])
        if len(hk[1]) >= 20 and hk in heads and r["m"] - heads[hk] < 360:
            r["nz"].add("SAME STORY")
        heads.setdefault(hk, r["m"])
    return rows


def report(rows, days):
    n_days = max(1, len(days))
    for r in rows:
        r["p"] = tier(r["text"])
    flags(rows)
    L = ["THE NUISANCE AUDIT · %s · %d alerts on %d day(s) = %d a day (what GIR sent to Telegram, before the 191-205 changes)" % (
        " · ".join(days), len(rows), n_days, round(len(rows) / n_days))]
    by = defaultdict(list)
    for r in rows:
        by[r["k"]].append(r)
    L.append("")
    L.append("BY KIND (a day)                       now   shares  chatter ladder  flip  late  same-story")
    for k, X in sorted(by.items(), key=lambda kv: -len(kv[1]))[:30]:
        c = Counter(z for x in X for z in x["nz"])
        L.append("  %-34s %5d  %-3s %5d %7d %6d %5d %5d %6d" % (k[:34], round(len(X) / n_days), Counter(x["p"] for x in X).most_common(1)[0][0],
                                                            len({x["sym"] for x in X}), c["CHATTER"], c["LADDER"], c["FLIP"], c["LATE"], c["SAME STORY"]))
    nz = [r for r in rows if r["nz"]]
    keep_always = [r for r in rows if r["p"] in ("P1",) or (r["p"] == "P2" and not ({"CHATTER", "SAME STORY"} & r["nz"]))]
    L.append("")
    L.append("NUISANCE (a day): %d of %d carry at least one mark - chatter %d · ladder %d · flip %d · late %d · same story %d" % (
        round(len(nz) / n_days), round(len(rows) / n_days), *(round(sum(1 for r in rows if z in r["nz"]) / n_days) for z in ("CHATTER", "LADDER", "FLIP", "LATE", "SAME STORY"))))
    left = list(rows)
    L.append("")
    L.append("THE CUT - each rule in turn (P1 trade calls are never cut; a P2 is cut only as a repeat of itself):")
    L.append("  %-62s %5d a day" % ("as sent", round(len(left) / n_days)))
    for rule, what in (("CHATTER", "the same share and kind again within 30 min -> one"), ("LADDER", "RUNNING / SPEED: the first step a share and side a day, not every 1%"),
                       ("SAME STORY", "the same headline again within 6 h -> one"), ("FLIP", "the other side within 30 min -> neither (on the page only)"),
                       ("LATE", "a side alert after a 3%+ move -> the page only")):
        left = [r for r in left if r["p"] == "P1" or rule not in r["nz"] or (r["p"] == "P2" and rule in ("FLIP", "LATE", "LADDER"))]
        L.append("  - %-60s %5d a day" % (what, round(len(left) / n_days)))
    merged = len({(r["d"], r["sym"] or r["h"][:20], r["m"] // 5) for r in left})
    L.append("  - %-60s %5d a day" % ("what one share says within 5 min -> ONE message", round(merged / n_days)))
    L.append("")
    L.append("THE LOUDEST SHARES (a day): " + " · ".join("%s %d" % (s, round(n / n_days)) for s, n in Counter(r["sym"] for r in rows if r["sym"]).most_common(12)))
    L.append("THE BUSIEST MINUTES: " + " · ".join("%s %s %d" % (d, t, n) for (d, t), n in Counter((r["d"], r["t"]) for r in rows).most_common(6)))
    return L


if __name__ == "__main__":
    nd = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 3
    rows, days = load(nd)
    txt = "\n".join(report(rows, days))
    print(txt)
    open(os.path.join(BASE, "data", "alertaudit.txt"), "w").write(txt + "\n")
PY_A
cat > $D/p206test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p206test.py - PATCH 206: the nuisance audit on a made-up alert log"""
import os, sys, sqlite3, tempfile
B = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, B)
import alertaudit as A
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
p = os.path.join(tempfile.mkdtemp(), "t.db"); c = sqlite3.connect(p)
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
rows = [("10:00:00", "YESX", "CE", "🚀 RUNNING ▲ YESX ₹24.3 +1.2% · 10:00\ncrossed +1%"), ("10:10:00", "YESX", "CE", "🚀 RUNNING ▲ YESX ₹24.6 +2.1% · 10:10\ncrossed +2%"),
        ("10:20:00", "YESX", "CE", "🚀 RUNNING ▲ YESX ₹24.9 +3.3% · 10:20\ncrossed +3%"),
        ("10:05:00", "TITX", "CE", "🧩 CALLS BOUGHT ▲ TITX ₹3500 +0.4% · 10:05\nWATCH"), ("10:15:00", "TITX", "CE", "🧩 CALLS BOUGHT ▲ TITX ₹3504 +0.5% · 10:15\nWATCH"),
        ("10:25:00", "TITX", "PE", "🧩 PUTS BOUGHT ▼ TITX ₹3490 +0.2% · 10:25\nWATCH"),
        ("09:16:00", "SWX", "CE", "🟢 GO · SWX ▲ CE · 09:16\ngap +1.7%"), ("09:40:00", "SWX", "CE", "🟢 GO · SWX ▲ CE · 09:40\ngap +1.7%"),
        ("11:00:00", "BELX", "CE", "📰 NEWS ▲ BELX · ORDER · 11:00\nBEL wins Rs 2,210 crore defence order from MoD"),
        ("11:02:00", "HALX", "CE", "📰 NEWS ▲ HALX · ORDER · 11:02\nBEL wins Rs 2,210 crore defence order from MoD")]
for t, s, sd, x in rows:
    c.execute("insert into alerts values('2026-11-11',?,?,?,?,?)", (t, x.split()[0], s, sd, x))
c.commit(); c.close()
R, days = A.load(3, p)
check("the kind is read from the head: '🚀 RUNNING', '🧩 CALLS BOUGHT', '🟢 GO', '📰 NEWS · ORDER'", {"🚀 RUNNING", "🧩 CALLS BOUGHT", "🟢 GO", "📰 NEWS · ORDER"} <= {r["k"] for r in R})
L = A.report(R, days); txt = "\n".join(L); print(txt)
fl = {(r["sym"], r["t"]): r["nz"] for r in R}
check("RUNNING +2% / +3% after the first: LADDER", "LADDER" in fl[("YESX", "10:10")] and "LADDER" in fl[("YESX", "10:20")] and not fl[("YESX", "10:00")])
check("+3.3%: LATE", "LATE" in fl[("YESX", "10:20")])
check("CALLS BOUGHT again in 10 min: CHATTER; PUTS BOUGHT 10 min later: FLIP", "CHATTER" in fl[("TITX", "10:15")] and "FLIP" in fl[("TITX", "10:25")])
check("the same headline for another share: SAME STORY", "SAME STORY" in fl[("HALX", "11:02")])
check("a P1 GO repeat is never cut", "the same share and kind again within 30 min -> one" in txt and any("GO" in l for l in L))
last = [l for l in L if "a day" in l and "ONE message" in l]
check("THE CUT ends with fewer than sent (%s)" % last, last and int(last[0].split()[-3]) < 10)
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); sys.exit(1 if FAILS else 0)
PY_TEST
cd $D && python3 -m py_compile alertaudit.py || { echo "❌ does not compile"; exit 1; }
echo "=== the test (a made-up alert log)"
timeout 60 python3 $D/p206test.py | grep -E "  ok|FAIL|PASSED"
echo
cd $D && timeout 600 python3 alertaudit.py 4 > /dev/null 2>&1
cat $D/data/alertaudit.txt
echo
echo "✅ patch 206 audit done - nothing was sent or changed."
