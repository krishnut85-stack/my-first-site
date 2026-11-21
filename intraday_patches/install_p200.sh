#!/bin/bash
# PATCH 200 - EACH SHARE'S OWN HABIT (Rama: "find a trend for each and every stock"): for every F&O share, GIR's 3 years - on a gap up /
#   down of 0.5-1.5% · 1.5-3% · 3%+: did it HOLD (close beyond its open) or FADE (its extreme before 11:00), and after a 3% day does it
#   FOLLOW or REVERSE next day. The 09:08 PRE-OPEN shows each gapping share's own line; rebuilt every evening 19:45. No restart.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
cp $D/preopen.py $D/preopen.py.bak$TS
back(){ cp $D/preopen.py.bak$TS $D/preopen.py; echo "❌ old file back - nothing changed"; exit 1; }
cat > $D/stockpattern.py <<'PY_SP'
#!/usr/bin/env python3
"""stockpattern.py - patch 200: EACH SHARE'S OWN HABIT, from GIR's 3 years (Rama, 11 Nov: "this is how you need to find a trend for each
and every stock" - after the NIFTY table of patch 198). Some shares' gaps hold and run all day, some fade by 11:00; some follow a 3%
day, some give it back. For every F&O share (data/h3: daily + 5-min candles):
  GAP UP   +0.5-1.5% · +1.5-3% · +3%+     how often it CLOSED ABOVE ITS OPEN (held) · its high BEFORE 11:00 · open -> close
  GAP DOWN -0.5-1.5% · -1.5-3% · -3%+     the mirror (closed below its open · its low before 11:00)
  AFTER A 3% DAY   up / down: how often the next day went the SAME way (close vs the previous close)
  -> a word for each: HOLDS (let it run) · FADES (book before 11:00) · no edge · too few days (under 8)
  nightly 19:45 -> data/stockpattern.json · the 09:08 PRE-OPEN shows each gapping share's own line · the page can show it
  python3 stockpattern.py --build    all shares -> the file (a few minutes)
  python3 stockpattern.py SYM        one share's table
  python3 stockpattern.py --study    the shares whose habit is the clearest (gap-and-go, gap-and-fade, follow-through)"""
import os, sys, json, statistics, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
OUT = os.path.join(BASE, "data", "stockpattern.json")
I11 = 21
BUCKETS = [(0.5, 1.5, "+0.5-1.5%"), (1.5, 3.0, "+1.5-3%"), (3.0, 99, "+3%+")]
MIN_N = 8


def rows(D, M):
    ks = sorted(D)
    out = []
    for j in range(2, len(ks)):
        k, kp, kpp = ks[j], ks[j - 1], ks[j - 2]
        x = M.get(k)
        if x is None or x[5].sum() < 60:
            continue
        pc, ppc = D[kp][3], D[kpp][3]
        o, c = float(x[0][0]), float(D[k][3])
        if not pc or not o or not ppc:
            continue
        out.append({"gap": (o / pc - 1) * 100, "held": c > o, "faded": c < o, "oc": (c / o - 1) * 100,
                    "hi11": int(x[1].argmax()) <= I11, "lo11": int(x[2].argmin()) <= I11,
                    "prev": (pc / ppc - 1) * 100, "day": (c / pc - 1) * 100})
    return out


def word(n, good, bad, early):
    """good = the gap's way held · bad = it faded · early = the extreme came before 11:00"""
    if n < MIN_N:
        return "too few"
    if good / n >= 0.6:
        return "HOLDS"
    if bad / n >= 0.6 and early / n >= 0.55:
        return "FADES"
    return "no edge"


def stats(R):
    out = {}
    for lo, hi, lab in BUCKETS:
        for side in (1, -1):
            X = [r for r in R if lo <= r["gap"] * side < hi]
            n = len(X)
            if not n:
                continue
            good = sum(1 for r in X if (r["held"] if side > 0 else r["faded"]))
            bad = n - good
            early = sum(1 for r in X if (r["hi11"] if side > 0 else r["lo11"]))
            out[("up " if side > 0 else "down ") + lab.lstrip("+")] = {
                "n": n, "held": good, "early": early, "oc": round(statistics.mean(r["oc"] for r in X), 2), "word": word(n, good, bad, early)}
    for side, lab in ((1, "after a 3% up day"), (-1, "after a 3% down day")):
        X = [r for r in R if r["prev"] * side >= 3]
        if X:
            same = sum(1 for r in X if r["day"] * side > 0)
            out[lab] = {"n": len(X), "same": same, "avg": round(statistics.mean(r["day"] for r in X), 2),
                        "word": "too few" if len(X) < MIN_N else "FOLLOWS" if same / len(X) >= 0.6 else "REVERSES" if same / len(X) <= 0.4 else "no edge"}
    return out


def build(syms=None):
    import study3y as S
    syms = syms or S.fo_list()
    P = {}
    for s in syms:
        try:
            R = rows(S.daily(s), S.intraday(s))
        except Exception:
            continue
        if R:
            P[s] = stats(R)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump({"built": dt.datetime.now().isoformat(timespec="minutes"), "shares": P}, open(OUT + ".tmp", "w"))
    os.replace(OUT + ".tmp", OUT)
    return P


def load():
    try:
        return (json.load(open(OUT)) or {}).get("shares") or {}
    except Exception:
        return {}


def key_for(gap):
    a = abs(gap)
    if a < 0.5:
        return None
    lab = next(l for lo, hi, l in BUCKETS if lo <= a < hi).lstrip("+")
    return ("up " if gap > 0 else "down ") + lab


def gap_line(sym, gap, P=None):
    """the 09:08 line for one share opening with this gap - '' when nothing to say"""
    P = P if P is not None else load()
    k = key_for(gap)
    st = (P.get(sym) or {}).get(k) if k else None
    if not st:
        return ""
    up = gap > 0
    w = st["word"]
    do = {"HOLDS": "usually HOLDS - %s, let it run" % ("CE" if up else "PE"),
          "FADES": "usually FADES - book before 11:00, no fresh %s on the open" % ("CE" if up else "PE"),
          "no edge": "no clear habit - the first 5 minutes decide", "too few": "too few such days to say"}[w]
    return "   %s's own 3 years, %d gaps %s: %s on %d · its %s before 11:00 on %d · open→close %+.2f%% → %s" % (
        sym, st["n"], k.split(" ", 1)[1], "closed above its open" if up else "closed below its open", st["held"],
        "high" if up else "low", st["early"], st["oc"], do)


def table(sym, P):
    st = P.get(sym) or {}
    L = ["%s - its own habit (GIR's 3 years)" % sym]
    for k, v in st.items():
        if k.startswith(("up", "down")):
            L.append("  gap %-12s %3d days · held %3d · extreme before 11:00 %3d · open→close %+.2f%% · %s" % (k, v["n"], v["held"], v["early"], v["oc"], v["word"]))
        else:
            L.append("  %-16s %3d days · the same way next day %3d · avg %+.2f%% · %s" % (k, v["n"], v["same"], v["avg"], v["word"]))
    return L


def study(P):
    L = ["EACH SHARE'S HABIT - the clearest ones (8+ days, 60%%+ one way) · %d shares" % len(P)]
    for k, title in (("up 0.5-1.5%", "GAP UP 0.5-1.5%"), ("up 1.5-3%", "GAP UP 1.5-3%"), ("down 0.5-1.5%", "GAP DOWN 0.5-1.5%"), ("down 1.5-3%", "GAP DOWN 1.5-3%")):
        H = sorted([(s, v[k]) for s, v in P.items() if k in v and v[k]["word"] == "HOLDS"], key=lambda x: -x[1]["held"] / x[1]["n"])
        F = sorted([(s, v[k]) for s, v in P.items() if k in v and v[k]["word"] == "FADES"], key=lambda x: x[1]["held"] / x[1]["n"])
        L.append("")
        L.append("%s - HOLDS (let it run): %s" % (title, ", ".join("%s %d/%d" % (s, v["held"], v["n"]) for s, v in H[:15]) or "none"))
        L.append("%s - FADES (book before 11:00): %s" % (title, ", ".join("%s %d/%d" % (s, v["n"] - v["held"], v["n"]) for s, v in F[:15]) or "none"))
    for k in ("after a 3% up day", "after a 3% down day"):
        Fo = sorted([(s, v[k]) for s, v in P.items() if k in v and v[k]["word"] == "FOLLOWS"], key=lambda x: -x[1]["same"] / x[1]["n"])
        Re = sorted([(s, v[k]) for s, v in P.items() if k in v and v[k]["word"] == "REVERSES"], key=lambda x: x[1]["same"] / x[1]["n"])
        L.append("")
        L.append("%s - FOLLOWS next day: %s" % (k.upper(), ", ".join("%s %d/%d" % (s, v["same"], v["n"]) for s, v in Fo[:15]) or "none"))
        L.append("%s - REVERSES next day: %s" % (k.upper(), ", ".join("%s %d/%d" % (s, v["n"] - v["same"], v["n"]) for s, v in Re[:15]) or "none"))
    n_all = sum(1 for v in P.values() for k, x in v.items() if k.startswith(("up", "down")) and x["word"] != "too few")
    n_clear = sum(1 for v in P.values() for k, x in v.items() if k.startswith(("up", "down")) and x["word"] in ("HOLDS", "FADES"))
    L.append("")
    L.append("of %d share-and-gap tables with 8+ days, %d show a clear habit (the rest: no edge - the first 5 minutes decide)" % (n_all, n_clear))
    return L


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--build"]:
        P = build(); print("built: %d shares -> %s" % (len(P), OUT))
    elif a[:1] == ["--study"]:
        print("\n".join(study(load() or build())))
    elif a:
        print("\n".join(table(a[0].upper(), load() or build([a[0].upper()]))))
    else:
        print(__doc__)
PY_SP
cat > $W/p200_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p200_patch.py - PATCH 200: the 09:08 PRE-OPEN shows each gapping share's own 3-year habit. Usage: python3 p200_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "preopen.py"); s = open(p, encoding="utf-8").read()
if "patch 200" in s:
    print("  preopen.py: already in"); sys.exit(0)
A = '''    rows.sort()
'''
B = '''        L.append("   %s side only if the first 5 minutes confirm - the 🌅 OPENING CALL at 09:20 decides" % ("CE" if g > 0 else "PE"))'''
if s.count(A) != 1 or s.count(B) != 1:
    print("NOT DONE: preopen.py anchors (%d, %d)" % (s.count(A), s.count(B))); sys.exit(1)
s = s.replace(A, '''    rows.sort()
    try:                                                        # patch 200: each share's own 3-year habit on a gap like this
        import stockpattern
        SP = stockpattern.load()
    except Exception:
        SP = {}
''').replace(B, '''        try:
            pl = stockpattern.gap_line(s, g, SP) if SP else ""           # patch 200
            if pl:
                L.append(pl)
        except Exception:
            pass
''' + B)
open(p, "w", encoding="utf-8").write(s); print("  preopen.py: each gapping share's own habit"); print("patch 200 written")
PY_PATCH
cat > $D/p200test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p200test.py - PATCH 200: each share's own habit on made-up shares, and the 09:08 line (no server data, nothing sent)"""
import os, sys, json, shutil, tempfile, datetime as dt
import numpy as np
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp()
for f in ("stockpattern.py", "preopen.py"):
    shutil.copy(os.path.join(B, f), W)
os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W)
import stockpattern as P
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
def make(kind, gp=1.01):
    """60 sessions; every 5th one gaps +1%: 'go' holds it (closes +2% above the open), 'fade' gives it back by 10:30"""
    D, M, d, px = {}, {}, dt.date(2026, 6, 1), 100.0
    i = 0
    while len(D) < 60:
        if d.weekday() < 5:
            k = str(d); g = (i % 5 == 4)
            o = px * (gp if g else 1.0)
            if g and kind == "go":
                path = [o * (1 + 0.0003 * j) for j in range(75)]
            elif g:
                path = [o * (1 + 0.0005 * j) for j in range(10)] + [o * 1.005 - o * 0.0003 * j for j in range(65)]
            else:
                path = [o] * 75
            x = np.zeros((6, 75), dtype=np.float32); p0 = o
            for j, c in enumerate(path):
                x[:, j] = (p0, max(p0, c) * 1.0001, min(p0, c) * 0.9999, c, 1, 1); p0 = c
            M[k] = x; D[k] = (o, max(path), min(path), path[-1], 1); px = path[-1]; i += 1
        d += dt.timedelta(days=1)
    return D, M
SP = {}
for s, kind in (("GOX", "go"), ("FADEX", "fade")):
    D, M = make(kind)
    SP[s] = P.stats(P.rows(D, M))
g, f = SP["GOX"]["up 0.5-1.5%"], SP["FADEX"]["up 0.5-1.5%"]
check("a share whose +1%% gaps hold: HOLDS (%d of %d)" % (g["held"], g["n"]), g["word"] == "HOLDS" and g["n"] >= 8)
check("a share whose +1%% gaps fade by 11:00: FADES (%d held of %d, extreme early %d)" % (f["held"], f["n"], f["early"]), f["word"] == "FADES")
l1, l2 = P.gap_line("GOX", 1.1, SP), P.gap_line("FADEX", 1.1, SP)
print(l1); print(l2)
check("the 09:08 line: GOX 'usually HOLDS - CE, let it run'", "usually HOLDS - CE, let it run" in l1)
check("the 09:08 line: FADEX 'usually FADES - book before 11:00'", "usually FADES - book before 11:00" in l2)
check("a gap under 0.5%: nothing said", P.gap_line("GOX", 0.3, SP) == "")
D3, M3 = make("fade", 1.035); SP["FADEX"] = P.stats(P.rows(D3, M3)); SP["FADEX"].update(P.stats(P.rows(*make("fade"))))   # its +3.5% gaps fade too
check("FADEX's +3.5%% gaps: FADES (%s)" % SP["FADEX"].get("up 3%+", {}).get("word"), SP["FADEX"].get("up 3%+", {}).get("word") == "FADES")
json.dump({"shares": SP}, open(P.OUT, "w"))
import preopen
pj = {"data": [{"metadata": {"symbol": "FADEX", "iep": 101.1, "previousClose": 100.0, "pChange": 4.4, "finalQuantity": 1000}}]}
txt, rows_ = preopen.build(now=dt.datetime(2026, 11, 12, 9, 8, tzinfo=preopen.IST), getj=lambda path: pj, base=W)
print(txt)
check("the PRE-OPEN at 09:08 carries the share's own habit", txt and "FADEX's own 3 years" in txt)
st = P.study(SP)
check("--study names the gap-and-go and the gap-and-fade shares", any("HOLDS" in x and "GOX" in x for x in st) and any("FADES" in x and "FADEX" in x for x in st))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 200"
python3 $W/p200_patch.py $D || back
cd $D && python3 -m py_compile stockpattern.py preopen.py || back
echo "=== the test (made-up shares - nothing sent)"
timeout 60 python3 $D/p200test.py > /tmp/p200test.out 2>&1; R=$?
grep -E "  ok|FAIL|PASSED" /tmp/p200test.out; [ $R = 0 ] || back
cat > $U/gir-stockpattern.service <<'UNIT'
[Unit]
Description=GIR each share's own habit - rebuilt from the 3-year candles
[Service]
Type=oneshot
TimeoutStartSec=1800
Nice=10
ExecStart=/bin/bash -c 'cd /home/globalbot/intraday && python3 stockpattern.py --build >> data/stockpattern.log 2>&1'
UNIT
cat > $U/gir-stockpattern.timer <<'UNIT'
[Unit]
Description=GIR each share's own habit, 19:45 IST Monday-Friday
[Timer]
OnCalendar=Mon..Fri *-*-* 19:45:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-stockpattern.timer >/dev/null 2>&1 && systemctl start gir-stockpattern.timer
echo "=== building every share's habit now (a few minutes)"
cd $D && nice -n 10 timeout 1800 python3 stockpattern.py --build
{ python3 stockpattern.py --study; echo; for s in COROMANDEL SBIN RVNL COCHINSHIP POLICYBZR MANAPPURAM; do python3 stockpattern.py $s; echo; done; } > $D/data/stockpattern_study.txt 2>&1
cat $D/data/stockpattern_study.txt
echo "✅ patch 200 done. From tomorrow the 09:08 PRE-OPEN shows each gapping share's own habit."
