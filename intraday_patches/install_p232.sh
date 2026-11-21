#!/bin/bash
# PATCH 232 - FII / DII IN WHO IS PUSHING: every named deal counted, told honestly (Rama, 12 Nov: "I don't see any FII pushing nor pulling, DII
#   very rare"). NSE gives no daily FII / DII figure per share - only the bulk / block deals (after 15:30). GIR looked only at the 12 biggest
#   deals per list (a share 13th never showed FII) and only 5 days; and filed the delivery footprint as DII though delivery names nobody.
#   Now: every F&O share's net deals · 5 days = a push (new money) · 30 days = context, not counted · delivery = "FII or DII - not named".
#   Tested: 7 cases + the push tests (30, 12) + the simulated day (16). Restarts the senders + page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="instflow.py pushwho.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p232_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p232_patch.py - PATCH 232: FII / DII IN WHO IS PUSHING - every named deal counted, told honestly (Rama, 12 Nov: "I don't see any FII pushing
nor pulling, and DII also very rare - recheck the code and audit"). NSE publishes no daily FII / DII figure per share; the only daily names are
the bulk / block deals (after 15:30). GIR used them badly:
  1 it looked only at the 12 biggest deals per list - a share whose FII deal was 13th never showed FII. Now every F&O share's net deals are
    kept (instflow: fii_all / dii_all) and pushwho reads them all
  2 only 5 days counted - now 5 days count as a push (new money); 30 days show as context ("older, not counted as a push")
  3 the delivery footprint (shares bought and KEPT) was always filed as DII - delivery does not say who; the line now says "big hands (FII or
    DII - delivery does not name them)", and the page's simple words say so too
Usage: python3 p232_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, need=True):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        (ERR.append("%s missing" % f) if need else print("  %s: not here - skipped" % f)); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("instflow.py", '''            W[cls.lower() + "_net"] = round(sum(x[1] for x in net), 1)''', '''            W[cls.lower() + "_net"] = round(sum(x[1] for x in net), 1)
            W[cls.lower() + "_all"] = {s_: {"cr": round(n_, 1), "n": a_["n"], "who": max(a_["who"].items(), key=lambda kv: abs(kv[1]))[0][:34] if a_["who"] else ""}
                                       for s_, n_, a_ in net}         # patch 232: every F&O share, not only the 12 biggest''', "every share's net deals (fii_all / dii_all)")
rep("pushwho.py", '''    w5 = (I.get("w") or {}).get("5") or {}
    for n, cls in ((1, "fii"), (2, "dii")):
        for key, sd in (("_buy", 1), ("_sell", -1)):
            x = next((r for r in w5.get(cls + key) or [] if r.get("s") == sym), None)
            if x:
                on(n, "%s %s ₹%.0f cr in named deals, 5 days%s" % (cls.upper(), "bought" if sd > 0 else "sold", abs(x.get("cr") or 0), (" (" + x["who"] + ")") if x.get("who") else ""), sd, "new")''',
    '''    w5 = (I.get("w") or {}).get("5") or {}
    w30 = (I.get("w") or {}).get("30") or {}
    for n, cls in ((1, "fii"), (2, "dii")):                    # patch 232: every F&O share's named deals (not the 12 biggest), 5 days = a push, 30 = context
        a5, a30 = w5.get(cls + "_all"), w30.get(cls + "_all")
        if a5 is None:                                         # an older instflow: the lists, as before
            for key, sd in (("_buy", 1), ("_sell", -1)):
                x = next((r for r in w5.get(cls + key) or [] if r.get("s") == sym), None)
                if x:
                    on(n, "%s %s ₹%.0f cr in named deals, 5 days%s" % (cls.upper(), "bought" if sd > 0 else "sold", abs(x.get("cr") or 0), (" (" + x["who"] + ")") if x.get("who") else ""), sd, "new")
            continue
        x = (a5 or {}).get(sym)
        if x and abs(x.get("cr") or 0) >= 1:
            sd = 1 if x["cr"] > 0 else -1
            on(n, "%s %s ₹%.0f cr in named deals (net), 5 days%s" % (cls.upper(), "bought" if sd > 0 else "sold", abs(x["cr"]), (" (" + x["who"] + ")") if x.get("who") else ""), sd, "new")
            continue
        x = (a30 or {}).get(sym)
        if x and abs(x.get("cr") or 0) >= 1:
            on(n, "%s %s ₹%.0f cr in named deals (net) over 30 days%s - older, context only (not counted as a push)" % (
                cls.upper(), "bought" if x["cr"] > 0 else "sold", abs(x["cr"]), (" (" + x["who"] + ")") if x.get("who") else ""))''',
    "FII / DII: every share, 5 days a push, 30 days context")
rep("pushwho.py", '''            on(2, "big hands %s on %s: delivery %.1fx normal (₹%.0f cr extra)" % ("BUYING" if sd > 0 else "SELLING", (dl.get("day") or "")[5:], x.get("x") or 0, x.get("extra") or 0), sd, "new")''',
    '''            on(2, "big hands (FII or DII - delivery does not name them) %s on %s: delivery %.1fx normal (₹%.0f cr extra)" % ("BUYING" if sd > 0 else "SELLING", (dl.get("day") or "")[5:], x.get("x") or 0, x.get("extra") or 0), sd, "new")''',
    "delivery: 'FII or DII - not named'")
rep("home.html", '''    if((x=t.match(/(bought|sold) ₹([\\d,.]+) cr in named deals/))) return `${who} ${x[1]==="bought"?"BOUGHT":"SOLD"} ₹${x[2]} cr of this share in big deals (last 5 days).`;
    if((x=t.match(/big hands (BUYING|SELLING)[^:]*: delivery ([\\d.]+)x/))) return x[1]==="BUYING"?`Big investors BOUGHT and kept the shares (${x[2]}x the normal) - real buying.`:`Big investors SOLD more than normal (${x[2]}x) - real selling.`; }''',
    '''    if(/30 days/.test(t)&&(x=t.match(/(bought|sold) ₹([\\d,.]+) cr in named deals/))) return `${who} ${x[1]} ₹${x[2]} cr of it in big deals over the last 30 days - older news, not pushing it now.`;   /* patch 232 */
    if((x=t.match(/(bought|sold) ₹([\\d,.]+) cr in named deals/))) return `${who} ${x[1]==="bought"?"BOUGHT":"SOLD"} ₹${x[2]} cr of this share in big deals (last 5 days).`;
    if((x=t.match(/big hands[^:]*?(BUYING|SELLING)[^:]*: delivery ([\\d.]+)x/))) return x[1]==="BUYING"?`Big investors (foreign or Indian - not named) BOUGHT and kept the shares (${x[2]}x the normal) - real buying.`:`Big investors (foreign or Indian - not named) SOLD more than normal (${x[2]}x) - real selling.`; }''',
    "the page's simple words: delivery not named, 30-day deals as context", need=False)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 232 in")
PY_PATCH
cat > $W/p232test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p232test.py - FII / DII in WHO IS PUSHING (made-up deals, temp folder, nothing sent).  python3 p232test.py DIR  (instflow.py, pushwho.py, pushalert.py)"""
import os, sys, json, shutil, sqlite3, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data", "instdeals"))
for f in ("instflow.py", "pushwho.py", "pushalert.py"):
    if os.path.exists(os.path.join(D, f)):
        shutil.copy(os.path.join(D, f), T)
open(os.path.join(T, "whymove.py"), "w").write("def explain(sym, now=None):\n    return {'s': sym, 'chg': 1.0, 'reasons': []}\n")
syms = ["S%02d" % i for i in range(1, 16)] + ["OLDDEAL", "DELIVSH"]
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text)"); c.executemany("insert into fo_list values (?)", [(s,) for s in syms]); c.commit(); c.close()
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); today = dt.date(2026, 11, 12)
days = []
d = today
while len(days) < 25:
    if d.weekday() < 5:
        days.append(d)
    d -= dt.timedelta(days=1)
for i, dd in enumerate(sorted(days)):
    rows = []
    if dd == today:                                            # 15 FII buys today, ₹15 cr down to ₹1 cr - the 13th, 14th, 15th were cut before
        rows = [{"s": "S%02d" % k, "cls": "FII", "side": "BUY", "q": 100000, "p": (16 - k) * 100.0, "who": "SOCIETE GENERALE"} for k in range(1, 16)]
    if dd == sorted(days)[2]:                                  # an FII sale ~20 trading days ago
        rows = [{"s": "OLDDEAL", "cls": "FII", "side": "SELL", "q": 200000, "p": 1000.0, "who": "MORGAN STANLEY ASIA SINGAPORE PTE"}]
    json.dump({"day": str(dd), "rows": rows}, open(os.path.join(T, "data", "instdeals", "%s.json" % dd), "w"))
json.dump({"fo_paths": [{"s": s, "chg": 1.0} for s in syms]}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"shares": {}}, open(os.path.join(T, "data", "desk.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import instflow as I
I.deliv_signals = lambda min_x=1.5: {"day": "2026-11-11", "acc": [{"s": "DELIVSH", "x": 1.8, "extra": 27.0}], "dist": []}
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:300]))
S = I.summary(now=dt.datetime(2026, 11, 12, 20, 0, tzinfo=IST))
w5 = S["w"]["5"]
chk("the display list still keeps the 12 biggest", len(w5["fii_buy"]) == 12)
chk("... and every share is now kept: fii_all has all 15 (S13, S14, S15 were cut before)", len(w5["fii_all"]) == 15 and "S15" in w5["fii_all"], sorted(w5["fii_all"]))
chk("the 30-day window holds the old sale (OLDDEAL), the 5-day one does not", "OLDDEAL" in S["w"]["30"]["fii_all"] and "OLDDEAL" not in w5["fii_all"])
import pushwho as W
W._F["_inst"] = (9e18, S)
def fii(sym):
    p = W.read(sym); r = {x["k"]: x for x in p["rows"]}
    return r["FII"], r["DII"]
f, _ = fii("S14")
chk("S14 (14th biggest FII buy): FII ▲ lights up now, 'named deals (net), 5 days'", f["on"] and f["side"] == 1 and "named deals (net), 5 days" in f["t"], f)
f, _ = fii("OLDDEAL")
chk("OLDDEAL (FII sold ~20 days ago): FII shown as CONTEXT, no side (not counted as a push)", f["on"] and f["side"] == 0 and "context only" in f["t"], f)
f, dd_ = fii("DELIVSH")
chk("delivery footprint: says 'FII or DII - delivery does not name them'", dd_["on"] and "FII or DII - delivery does not name them" in dd_["t"], dd_)
if os.path.exists("pushalert.py"):
    import pushalert as A
    chk("a 30-day-old deal alone never makes a PUSH STARTED", A.judge(W.read("OLDDEAL")) is None)
print("FII / DII test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p232_patch.py $D || back
cd $D && python3 -m py_compile instflow.py pushwho.py || back
echo "=== test: FII / DII (made-up deals)"
python3 $W/p232test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== this server's F&O shares now: how many show FII / DII (named deals 5 days · 30 days context · delivery)"
cd $D && timeout 300 python3 - <<'PY'
import sys, json, collections
sys.path.insert(0, "/home/globalbot/intraday")
import pushwho
st = json.load(open("dash_state.json"))
fps = [f["s"] for f in st.get("fo_paths") or [] if f.get("s")]
c = collections.Counter(); ex = collections.defaultdict(list)
for s in fps:
    try:
        p = pushwho.read(s)
    except Exception:
        continue
    for r in p["rows"]:
        if r["k"] in ("FII", "DII") and r["on"]:
            k = "%s %s" % (r["k"], "push" if r["side"] else "context")
            if "delivery" in r["t"]:
                k = "delivery (FII or DII)"
            c[k] += 1; ex[k].append(s)
for k, n in c.most_common():
    print("   %-24s %3d shares · e.g. %s" % (k, n, " ".join(ex[k][:8])))
print("   (%d F&O shares read)" % len(fps))
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 232 done - FII / DII now from every named deal (5 days = push, 30 days = context); delivery says 'FII or DII - not named'."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
