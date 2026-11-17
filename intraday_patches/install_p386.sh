#!/bin/bash
# PATCH 386 - 📚 THE KNOWLEDGE BASE: WHAT A VETERAN KNOWS ABOUT EVERY F&O SHARE (Rama, 17 Nov 20:10: "the team of experts should have all the
#   knowledge of all F&O shares and their sectors, the shares' past history, present and future, and how they will react when things come up").
#   knowledge.py -> data/kb/kb.json, for every F&O share:
#   · MEASURED (facts, a year of Kite day candles + 2 years of world prices): its usual range and move, up days, gaps and how often they fill,
#     its beta to NIFTY and to its sector, its 4%+ days, HOW IT REACTS to crude / the rupee / the Nasdaq / gold / copper / the US yield (only
#     real links), its results reactions and shock days where GIR has them
#   · EXPERT (Claude Fable 5.2, monthly): the business, its drivers and sensitivities, its peers, how it TYPICALLY reacts to each kind of
#     event, what to watch, cautions - labelled general knowledge; the measured part wins where they differ
#   Given to: the senior analyst (the shares in focus), the 💬 answers (in full), the six desks (news: how these shares react; global: who
#   reacts to what; price: their usual moves), every ready file, and 📁 on the page. Renewed every Friday 21:30 (gir-ready).
#   The first build starts now in the background (~20-30 min; about $20 once for the 218 expert profiles, then monthly). Needs patch 385.
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 386" $D/knowledge.py 2>/dev/null && grep -q "share_knowledge" $D/analyst.py; then echo "patch 386 - already in"; exit 0; fi
grep -q "patch 385" $D/readyfile.py 2>/dev/null && [ -f $D/deskteam.py ] && [ -f $D/nightstudy.py ] || { echo "patch 385 (the ready files), 384 (the desks) and nightstudy.py first - nothing done"; exit 1; }
for f in knowledge.py analyst.py deskteam.py readyfile.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "patch 386" $W/knowledge.py && grep -q "share_knowledge" $W/analyst.py && python3 -m py_compile $W/knowledge.py $W/analyst.py $W/deskteam.py $W/readyfile.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
echo "== 1. the test (made-up shares and world in a temp folder; Kite and the model replaced by stand-ins)"
T=$(mktemp -d); mkdir -p $T/data; cp $W/knowledge.py $T/
cat > $T/seclive.py <<'STUB'
def fo_set(): return {"BPCL", "HINDPETRO", "IOC", "INFY"}
def universe(): return {"BPCL": "oil & gas", "HINDPETRO": "oil & gas", "IOC": "oil & gas", "INFY": "it"}, {"BPCL": "Bharat Petroleum", "INFY": "Infosys"}
STUB
python3 - $T <<'PY_TEST' || { echo "❌ the test failed - nothing changed"; exit 1; }
import os, sys, json, random, datetime as dt
T = sys.argv[1]; os.chdir(T); sys.path.insert(0, T)
import knowledge as K
OK = []
def chk(n, c):
    OK.append(bool(c)); print("  %s %s" % ("✓" if c else "✗", n))
random.seed(4); days = []; d = dt.date(2025, 11, 3)
while len(days) < 250:
    if d.weekday() < 5: days.append(d)
    d += dt.timedelta(days=1)
crude = {str(x): random.gauss(0, 0.02) for x in days}; nifty = {str(x): random.gauss(0, 0.008) for x in days}
def series(f, start=100.0):
    rows = []; c = start
    for x in days:
        r = f(str(x)); o = c * (1 + r * 0.3); c2 = c * (1 + r); rows.append([str(x), o, max(o, c2) * 1.005, min(o, c2) * 0.995, c2]); c = c2
    return rows
Y = {"NIFTY": series(lambda k: nifty[k], 26000), "BPCL": series(lambda k: 1.1 * nifty[k] - 0.4 * crude[k] + random.gauss(0, 0.006)),
     "HINDPETRO": series(lambda k: nifty[k] - 0.4 * crude[k] + random.gauss(0, 0.006)), "IOC": series(lambda k: nifty[k] - 0.35 * crude[k] + random.gauss(0, 0.006)),
     "INFY": series(lambda k: 0.7 * nifty[k] + random.gauss(0, 0.01))}
W = {"crude (Brent)": crude, "gold": {str(x): random.gauss(0, 0.01) for x in days}}
asked = []
K.ASK = lambda system, user: (asked.append(user), json.dumps({"business": "an oil refiner and fuel marketer", "drivers": ["refining margins", "marketing margins"],
    "sensitivities": ["crude up hurts marketing margins"], "peers": ["HINDPETRO", "IOC"], "reactions": [{"event": "crude spikes", "reaction": "falls the same day"}],
    "watch": ["crude", "fuel price cuts"], "caution": ""}))[1]
kb = K.build(Y=Y, W=W)
m = kb["shares"]["BPCL"]["measured"]
chk("the usual day is measured (range, move, up days, gaps and fills)", m["avg_range_pct"] > 0 and m["avg_move_pct"] > 0 and m["up_days_pct"] is not None and m["gap_days_pct"] is not None)
chk("beta to NIFTY (planted 1.1, read %s) and to its sector (oil & gas, %s peers)" % (m["nifty"]["beta"], m["sector"]["peers"]), 0.8 <= m["nifty"]["beta"] <= 1.4 and m["sector"]["peers"] == 2)
chk("it FALLS when crude rises (planted), and the gold noise is not called a link", any("falls when crude" in w["say"] for w in m["world"]) and not any("gold" in w["to"] for w in m["world"]))
chk("INFY has no crude link", not any("crude" in w["to"] for w in (kb["shares"]["INFY"]["measured"]["world"] or [])))
chk("the expert profile is written once per share and told the measured facts", kb["shares"]["BPCL"]["profile"]["business"] and "avg_range_pct" in asked[0] and len(asked) == 4)
asked.clear(); K.build(Y=Y, W=W)
chk("a profile is not written again within 30 days (no new model reads)", not asked)
b = K.brief("BPCL"); bf = K.brief("BPCL", True)
chk("the short brief for the agents: business, usual day, reactions to the world, typical reactions", len(b) == 4 and "falls when crude" in b[2] and "typically" in b[3])
chk("the full brief adds drivers, sensitivities, peers, watch", any("peers: HINDPETRO, IOC" in x for x in bf) and len(bf) > len(b))
chk("who reacts to crude: the three oil marketers", sorted(x.split()[0] for x in K.who_reacts("crude")) == ["BPCL", "HINDPETRO", "IOC"])
print("  %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
rm -rf $T
echo "== 2. the files"
F="analyst.py deskteam.py readyfile.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/knowledge.py; systemctl restart gir-analyst gir-ready; echo "❌ old files put back - nothing changed"; exit 1; }
cp $W/knowledge.py $D/knowledge.py && for f in $F; do cp $W/$f $D/$f; done || back
cd $D && python3 -m py_compile knowledge.py analyst.py deskteam.py readyfile.py || back
systemctl restart gir-analyst gir-ready; sleep 4
echo "  gir-analyst: $(systemctl is-active gir-analyst) · gir-ready: $(systemctl is-active gir-ready)"
[ "$(systemctl is-active gir-analyst)" = "active" ] && [ "$(systemctl is-active gir-ready)" = "active" ] || back
echo "== 3. the first build, in the background (~20-30 min)"
nohup bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && nice -n 10 python3 knowledge.py build' >> $D/data/knowledge_build.log 2>&1 &
echo "✅ patch 386 done - the knowledge base is being built now. Watch it: tail -f $D/data/knowledge_build.log"
echo "   when it says 'knowledge: ... shares measured', see one share:  cd $D && python3 knowledge.py show LAURUSLABS"
echo "   then rebuild tonight's ready files with it (optional):  cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 readyfile.py build"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/knowledge.py; systemctl restart gir-analyst gir-ready"
