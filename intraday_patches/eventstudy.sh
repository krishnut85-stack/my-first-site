#!/bin/bash
# THE POLICY EVENT STUDY (patch 160) - Budgets, the 2024 election result, 13 RBI rate decisions, the GST cut, the online-gaming bill: how NIFTY and
#   the touched sectors reacted (the gap, 30 min after, the close, the next day) and whether following the first 30 minutes paid. Reads only.
#   Add events in /home/globalbot/intraday/data/events_extra.csv (date,time,kind,title,sectors). Needs scenlab.sh run first (scenlab.py).
D=/home/globalbot/intraday
[ -f $D/scenlab.py ] || { echo "run the scenario lab (scenlab.sh) first - this uses its scoring"; exit 1; }
cat > $D/eventstudy.py <<'PY_EV'
#!/usr/bin/env python3
"""eventstudy.py - patch 160: HOW THE MARKET REACTED TO POLICY EVENTS (Rama, 10 Nov: "what about the market reaction after Parliament passes
bills - check all the scenarios"). For each event (Budgets, the 2024 election result, RBI rate decisions, the GST cut, bills that hit a
sector): NIFTY and the sectors it touches - the gap, the first 30 minutes after the news, the close, the next day and 3 days - and the
trading question: when the touched sector's shares moved with the news in the first 30 minutes, did it carry on (+1% before -0.7%)?
Events: the list below + data/events_extra.csv (date,time,kind,title,sectors - sectors as GIR's groups, ';' between) to add more.
  python3 eventstudy.py [--no-tg]     -> data/h3/eventstudy.txt and the report to GIR's ⚙️ System topic"""
import os, sys, csv, json, datetime as dt
import numpy as np

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import study3y as S
import scenlab as L

RATE = ["PSU BANKS", "PRIVATE BANKS", "NBFC", "AUTO", "CEMENT-INFRA"]
ALL = "ALL"
# (date, time - "10:00" during the session / "pre" before the open / "close" after it, kind, title, the sectors it touches)
EVENTS = [
    ("2024-02-01", "11:00", "BUDGET", "Interim Budget 2024", ALL),
    ("2024-06-04", "pre", "ELECTION", "Lok Sabha election results", ALL),
    ("2024-07-23", "11:00", "BUDGET", "Union Budget 2024 (capital gains tax raised)", ALL),
    ("2025-02-01", "11:00", "BUDGET", "Union Budget 2025 (income-tax relief)", ALL),
    ("2024-02-08", "10:00", "RBI", "RBI holds the repo rate", RATE),
    ("2024-04-05", "10:00", "RBI", "RBI holds", RATE),
    ("2024-06-07", "10:00", "RBI", "RBI holds", RATE),
    ("2024-08-08", "10:00", "RBI", "RBI holds", RATE),
    ("2024-10-09", "10:00", "RBI", "RBI holds, stance to neutral", RATE),
    ("2024-12-06", "10:00", "RBI", "RBI holds, CRR cut", RATE),
    ("2025-02-07", "10:00", "RBI", "RBI cuts 25 bp", RATE),
    ("2025-04-09", "10:00", "RBI", "RBI cuts 25 bp", RATE),
    ("2025-06-06", "10:00", "RBI", "RBI cuts 50 bp + CRR cut", RATE),
    ("2025-08-06", "10:00", "RBI", "RBI holds", RATE),
    ("2025-10-01", "10:00", "RBI", "RBI holds", RATE),
    ("2025-12-05", "10:00", "RBI", "RBI cuts 25 bp", RATE),
    ("2026-02-06", "10:00", "RBI", "RBI holds", RATE),
    ("2025-09-03", "close", "GST", "GST Council cuts rates (autos, FMCG, durables, cement)", ["AUTO", "AUTO-ANC", "FMCG", "CONSUMER", "CEMENT-INFRA"]),
    ("2025-08-20", "close", "BILL", "Online Gaming Bill passed (Lok Sabha)", ["TELECOM-MEDIA", "IT"]),
]


def load_extra():
    p = os.path.join(BASE, "data", "events_extra.csv")
    out = []
    try:
        for r in csv.reader(open(p)):
            if len(r) >= 5 and r[0][:2] == "20":
                out.append((r[0].strip(), r[1].strip(), r[2].strip(), r[3].strip(), [x.strip().upper() for x in r[4].split(";")] if r[4].strip().upper() != ALL else ALL))
    except Exception:
        pass
    return out


def bar_of(t):
    if t in ("pre", "close"):
        return 0
    h, m = int(t[:2]), int(t[3:5])
    return max(0, min(70, (h * 60 + m - 555) // 5))


def study(syms, DAY, M5, NIFX, G, events):
    days = sorted(NIFX)
    pcm = {s: S.prev_close_map(DAY.get(s) or {}) for s in syms}
    L_, trades = [], {}
    for ev in events:
        d0, t, kind, title, secs = ev
        k = next((x for x in days if (x > d0 if t == "close" else x >= d0)), None)
        if not k:
            L_.append("  %s %s · %s - no candles for that day" % (d0, kind, title)); continue
        j = days.index(k)
        b = 0 if t in ("pre", "close") else bar_of(t)
        e = min(70, b + 6)                                          # 30 minutes after the news (09:45 for news before the open)
        if t in ("pre", "close"):
            e = 5
        nx = NIFX[k]
        npc = S.prev_close_map(DAY.get("NIFTY 50") or {}).get(k)
        if not npc:
            continue
        n_e, n_c = (nx[3][e] / npc - 1) * 100, (nx[3][72] / npc - 1) * 100
        n_gap = (nx[0][0] / npc - 1) * 100
        nxt = days[j + 1] if j + 1 < len(days) else None
        n_d1 = ((NIFX[nxt][3][-1] / nx[3][-1] - 1) * 100) if nxt else None
        L_.append("")
        L_.append("%s %s · %s%s" % (k, kind, title, "" if k == d0 else " (news %s, reaction %s)" % (d0, k)))
        L_.append("  NIFTY gap %+.2f%% · 30 min after %+.2f%% · close %+.2f%% · next day %s - the first 30 min %s the day" % (
            n_gap, n_e, n_c, ("%+.2f%%" % n_d1) if n_d1 is not None else "—", "TOLD" if n_e * n_c > 0 and abs(n_c) >= abs(n_e) * 0.5 else "did not tell"))
        groups = list(G) if secs == ALL else [g for g in secs if g in G]
        rows = []
        for g in groups:
            P = []
            for s in G[g]:
                x = (M5.get(s) or {}).get(k); pc = (pcm.get(s) or {}).get(k)
                if x is None or not pc:
                    continue
                c = x[3].astype(np.float64)
                P.append((s, (c[e] / pc - 1) * 100, (c[72] / pc - 1) * 100, x))
            if len(P) < 3:
                continue
            ae, ac = np.mean([p[1] for p in P]), np.mean([p[2] for p in P])
            rows.append((g, ae, ac))
            sd = 1 if ae > 0 else -1
            if abs(ae) >= 0.3:
                for s, pe, pcl, x in P:
                    if pe * sd > 0.2:
                        r = L.outcome(x[1].astype(np.float64), x[2].astype(np.float64), x[3].astype(np.float64), sd, float(x[3][e]), e, *L.TARGETS["A"])
                        if r is not None:
                            trades.setdefault(kind, []).append(r); trades.setdefault("ALL", []).append(r)
        rows.sort(key=lambda r: -abs(r[1]))
        if rows:
            L_.append("  sectors (30 min after → close): " + " · ".join("%s %+.1f→%+.1f%s" % (g, a, c, "" if a * c > 0 else " ↺") for g, a, c in rows[:6]))
    S_ = ["", "THE TRADE - the touched sector's shares that moved with the news in the first 30 min, entered then (+1% before -0.7%, out 15:15, costs):"]
    for k_, R in sorted(trades.items(), key=lambda kv: kv[0] != "ALL"):
        w = sum(1 for r in R if r > 0)
        S_.append("  %-9s %4d trades · WIN %d%% · per trade %+.2f%%" % (k_, len(R), round(100 * w / len(R)) if R else 0, sum(R) / len(R) if R else 0))
    return L_ + S_, trades


def main():
    import sectors, enternow
    syms = S.fo_list()
    G = enternow.groups(sectors.load())
    DAY = {s: S.daily(s) for s in syms + ["NIFTY 50"]}
    M5 = {s: S.intraday(s) for s in syms}
    NIFX = S.intraday("NIFTY 50")
    evs = EVENTS + load_extra()
    evs.sort()
    L_, T = study(syms, DAY, M5, NIFX, G, evs)
    return ["📋 POLICY EVENTS · %d events · how NIFTY and the touched sectors reacted" % len(evs)] + L_, T


if __name__ == "__main__":
    L_, T = main()
    txt = "\n".join(L_)
    print(txt)
    os.makedirs(S.H3, exist_ok=True)
    open(os.path.join(S.H3, "eventstudy.txt"), "w").write(txt)
    if "--no-tg" not in sys.argv:
        print("\nsent to Telegram (⚙️ System): %d message(s)" % S.send_tg(txt))
PY_EV
cat > $D/p160test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p160test.py - patch 160: the event study on a made-up RBI day (no files)"""
import os, sys, datetime as dt
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import eventstudy as E
NB = E.S.NB
days = ["2025-06-05", "2025-06-06", "2025-06-09"]
def bars(path):
    x = np.zeros((6, NB), dtype=np.float32)
    for i in range(NB):
        c0, c1 = path(i), path(i + 1); x[:, i] = (c0, max(c0, c1) + 0.01, min(c0, c1) - 0.01, c1, 1000, 1)
    return x
flat = lambda i: 100.0
up = lambda i: 100.0 if i < 9 else 100.0 + min(3.0, 0.08 * (i - 9))     # the RBI cut at 10:00, banks climb
G = {"PSU BANKS": ["B1", "B2", "B3"], "IT": ["I1", "I2", "I3"]}
syms = ["B1", "B2", "B3", "I1", "I2", "I3"]
DAY = {s: {k: (100, 100, 100, 100, 1) for k in days} for s in syms + ["NIFTY 50"]}
M5 = {s: {k: bars(up if s.startswith("B") and k == "2025-06-06" else flat) for k in days} for s in syms}
NIFX = {k: bars(flat) for k in days}
L, T = E.study(syms, DAY, M5, NIFX, G, [("2025-06-06", "10:00", "RBI", "RBI cuts 50 bp", ["PSU BANKS", "PRIVATE BANKS"])])
print("\n".join(L))
ok = any("PSU BANKS" in x for x in L) and len(T.get("RBI", [])) == 3 and all(r > 0.9 for r in T["RBI"])
print("P160 EVENT STUDY TEST " + ("PASSED" if ok else "FAILED")); sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile eventstudy.py && timeout 120 python3 p160test.py > /dev/null 2>&1 && echo "    p160test.py passed" || { echo "test failed - nothing run"; exit 1; }
echo "    loading the candles (5-15 min)..."
cd /home/globalbot && set -a && source .env && set +a && cd $D && nice -n 10 python3 eventstudy.py
