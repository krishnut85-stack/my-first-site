#!/bin/bash
# PATCH 219 - WHO IS PUSHING: two wrong readings fixed (Rama, 12 Nov 09:41: DATAPATTNS +4.06% "6 pushing up: FII, WRITERS, FUTURES, COMPANY,
#   TIDE, ALGOS · 1 pulling down: DII · ⚪ TIDE ONLY - moving with the market, no money of its own" - is it correct?)
#   1 FII ▲ / DII ▼ on EVERY share was the whole market's FII / DII cash figure of the last day - not that share's. Now FII / DII light up
#     only for the share's OWN deals (bulk / block, 5 days) or delivery; the market's figure is a note on TIDE. It also stops PUSH STARTED
#     alerts that had the market's FII as their only "money".
#   2 ⚪ TIDE ONLY was said for a share running 4x its sector. Now TIDE ONLY only when the move is about the tide's size; far beyond it (or
#     1.5%+ alone) with no money proven = 🔵 OWN MOVE - check the futures before trusting it.
#   Tested: 12 cases (old code reproduces the screen) + patch 215's 30 + the simulated day's 16. Then old vs new on this server's 40 movers.
#   In market hours (with: now) it restarts only the page server (the 🧲 list + share screens fixed at once); after 15:35 it also restarts
#   the senders (the alerts' push line, PUSH STARTED). Run with "now" during the day, and once more after 15:35 - the second run only restarts.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); MKT=0
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then MKT=1; [ "${1:-}" != "now" ] && { echo "market hours - add: now (restarts only the page server), or run it after 15:35"; exit 1; }; fi
[ -f $D/pushwho.py ] && [ -f $D/pushalert.py ] && grep -q "patch 214" $D/home.html || { echo "patches 208 / 214 / 215 first"; exit 1; }
if grep -q "patch 219" $D/pushwho.py && grep -q "patch 219" $D/home.html; then   # already in (a re-run): no old code left to compare - restart only
  echo "  patch 219 is already in - nothing to change"
  systemctl restart gir-dash && sleep 8 && echo "  gir-dash: $(systemctl is-active gir-dash)"
  if [ "$MKT" = "0" ]; then
    for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do systemctl restart $s 2>/dev/null; done
    sleep 8; for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do echo "  $s: $(systemctl is-active $s)"; done
    echo "✅ patch 219: the senders now use the new push reading too"
  else
    echo "✅ patch 219 on the page - run this again after 15:35 for the senders"
  fi
  exit 0
fi
for f in pushwho.py pushalert.py home.html; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in pushwho.py pushalert.py home.html; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p219_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p219_patch.py - PATCH 219: WHO IS PUSHING - two wrong readings fixed (Rama, 12 Nov 09:41: DATAPATTNS +4.06% said "6 pushing up: FII,
WRITERS, FUTURES, COMPANY, TIDE, ALGOS · 1 pulling down: DII · ⚪ TIDE ONLY - moving with the market, no money of its own" - is it correct?)
  1 FII ▲ / DII ▼ on EVERY share came from the whole market's FII / DII cash figure of the last day (FII bought, DII sold) - not this share's.
    Now FII / DII light up only for THIS share's own deals (bulk / block, 5 days) or its delivery; the market's figure is a note on TIDE
  2 ⚪ TIDE ONLY ("moving with the market") was said for a share running 4x its sector. Now TIDE ONLY only when the move is about the
    tide's size; a share far beyond its sector / NIFTY (or moving 1.5%+ alone) with no money proof is 🔵 OWN MOVE - its own buyers or
    news, no futures / option / deal money proven yet: check the futures before trusting it
  (pushwho.py; the page and the alert line know 🔵) Usage: python3 p219_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, marker=None):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s or (marker and marker in s):
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("pushwho.py", '''            if isinstance(v, (int, float)) and abs(v) >= 1000:
                on(n, "the market's %s %s ₹%s cr (cash, last day)" % (k, "bought" if v > 0 else "sold", format(int(abs(v)), ",")), 1 if v > 0 else -1)''',
    '''            if isinstance(v, (int, float)) and abs(v) >= 1000:  # patch 219: the WHOLE market's cash figure - a note on the tide, not this share's FII / DII
                mkt_.append("%s %s ₹%s cr" % (k, "bought" if v > 0 else "sold", format(int(abs(v)), ",")))''', "FII / DII: only this share's own money")
rep("pushwho.py", '''    ctx = (_json("dash_state.json", 20).get("ctx") or {})
    fd = ctx.get("fiidii")''', '''    ctx = (_json("dash_state.json", 20).get("ctx") or {})
    mkt_ = []
    fd = ctx.get("fiidii")''', "the market's figure kept aside")
rep("pushwho.py", '''    ban = _json(os.path.join("data", "desk.json"), 20).get("ban") or []''', '''    tide_ = 0.0                                                  # patch 219: how big the tide is (its sector / NIFTY, its way)
    for r in W.get("reasons") or []:
        if r.get("k") in ("sector", "market") and int(r.get("side") or 0) == d:
            m_ = re.search(r"([+-]?\\d+(?:\\.\\d+)?)%", r.get("t") or "")
            if m_:
                tide_ = max(tide_, abs(float(m_.group(1))))
    if mkt_ and R[9]["on"]:
        R[9]["t"] += " · the market's cash, last day: %s (all shares - not this one's)" % " · ".join(mkt_)
    ban = _json(os.path.join("data", "desk.json"), 20).get("ban") or []''', "the tide's size")
rep("pushwho.py", '''    elif chg is not None and abs(chg) >= 0.7 and (R[9]["on"] and R[9]["side"] == d):
        kind, adv = "TIDE ONLY", "moving with the market / its sector, no money of its own - it follows the market"''', '''    elif chg is not None and abs(chg) >= 0.7 and (R[9]["on"] and R[9]["side"] == d) and abs(chg) <= max(2 * tide_, tide_ + 1.5):
        kind, adv = "TIDE ONLY", "moving with the market / its sector, no money of its own - it follows the market"
    elif chg is not None and abs(chg) >= 1.5:                    # patch 219: far beyond the tide (or alone), no money proven
        kind, adv = "OWN MOVE", "%+.1f%% %s - its own buyers / news, no futures, option or deal money proven yet: check the futures before trusting it" % (
            chg, ("vs the tide %+.1f%%" % (tide_ * d)) if tide_ else "with no sector / market tide")''', "OWN MOVE vs TIDE ONLY")
rep("pushwho.py", '''    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪"}.get(kind, "")''',
    '''    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪", "OWN MOVE": "🔵"}.get(kind, "")''', "the 🔵 icon")
rep("pushalert.py", '''    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪"}.get(p.get("kind") or "", "")''',
    '''    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪", "OWN MOVE": "🔵"}.get(p.get("kind") or "", "")''', "the alert's 🔵 icon")
rep("home.html", '''function ppKind(k){ return k==="BOTH"?"🟢🟠":k==="NEW MONEY"?"🟢":k==="FORCED OUT"?"🟠":k==="TIDE ONLY"?"⚪":""; }''',
    '''function ppKind(k){ return k==="BOTH"?"🟢🟠":k==="NEW MONEY"?"🟢":k==="FORCED OUT"?"🟠":k==="TIDE ONLY"?"⚪":k==="OWN MOVE"?"🔵":""; }   /* patch 219: 🔵 */''', "the page: 🔵 OWN MOVE")
rep("home.html", '''/TIDE ONLY/.test(pl)?["pt","⚪ TIDE ONLY"]:null;''', '''/TIDE ONLY/.test(pl)?["pt","⚪ TIDE ONLY"]:/OWN MOVE/.test(pl)?["pt","🔵 OWN MOVE · no money proof"]:null;''', "the alert rows: 🔵 OWN MOVE")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 219 in")
PY_PATCH
cat > $W/p219test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p219test.py - patch 219: WHO IS PUSHING with the market's FII / DII figure and a share running far beyond its sector (made-up files in a
temp folder, stub readers - no network, nothing sent).  python3 p219test.py NEWDIR OLDDIR  (pushwho.py + pushalert.py in each)"""
import os, sys, json, shutil, sqlite3, tempfile, importlib.util, datetime as dt
NEW, OLD = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NOW = dt.datetime.now(IST).replace(hour=9, minute=41, second=0, microsecond=0)
DAY = str(NOW.date())
CHG = {"DATAPATTNS": 4.06, "WIPRO": 1.6, "LICI": 3.1, "ITC": 2.1, "KEI": 2.0, "SBIN": 0.9}
open(os.path.join(T, "whymove.py"), "w").write('''
CHG = %r
R = {"DATAPATTNS": [{"k": "sector", "t": "the defence sector is +1.0%% (8 shares) - it moves with its sector", "w": 2, "side": 1},
                    {"k": "news", "t": "news 11-12 08:40: Data Patterns bags Rs 120 crore defence order", "w": 3, "side": 1}],
     "WIPRO": [{"k": "market", "t": "NIFTY +0.9%% - the whole market", "w": 1, "side": 1}],
     "ITC": [{"k": "sector", "t": "the fmcg sector is +1.5%% (14 shares) - it moves with its sector", "w": 2, "side": 1}],
     "KEI": [{"k": "alone", "t": "on its own - its capital goods sector is flat", "w": 1, "side": 0}],
     "LICI": [{"k": "news", "t": "news 11-12 07:05: LIC makes the cut in the MSCI Global Standard Index", "w": 3, "side": 1}]}
def explain(sym, now=None):
    return {"s": sym, "chg": CHG.get(sym), "reasons": R.get(sym, [])}
''' % CHG)
open(os.path.join(T, "instflow.py"), "w").write('''
def summary():
    return {"w": {"5": {"fii_buy": [{"s": "LICI", "cr": 210.0, "who": "VANGUARD"}], "fii_sell": [], "dii_buy": [], "dii_sell": []}}, "deliv": {}}
''')
open(os.path.join(T, "newsroom.py"), "w").write("def items_for(sym, hours, x):\n    return []\n")
json.dump({"day": DAY, "ctx": {"fiidii": {"FII": 2500.0, "DII": -1800.0}}, "fo_paths": [
    {"s": "DATAPATTNS", "chg": 4.06, "bu": "LONG BUILD-UP", "cr": 6.0, "oi": 3.1, "rv": 2.5},
    {"s": "WIPRO", "chg": 1.6, "bu": "", "cr": 2.0}, {"s": "LICI", "chg": 3.1, "bu": "LONG BUILD-UP", "cr": 140.0, "oi": 7.2, "rv": 2.4},
    {"s": "ITC", "chg": 2.1, "bu": "", "cr": 3.0, "rv": 2.2}, {"s": "KEI", "chg": 2.0, "bu": "", "cr": 1.0}, {"s": "SBIN", "chg": 0.9, "bu": "", "cr": 0}]},
    open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"ban": ["KAYNES"], "shares": {"DATAPATTNS": {"lines": {"walls": "floor forming at 2600: OI 1.1 L → 1.6 L, premium down"}}}},
          open(os.path.join(T, "data", "desk.json"), "w"))
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)"); c.commit(); c.close()
sys.path.insert(0, T); os.chdir(T)


def load(name, d):
    for f in ("pushwho.py", "pushalert.py"):
        shutil.copy(os.path.join(d, f), os.path.join(T, name + "_" + f))
    m = {}
    for f in ("pushwho", "pushalert"):
        sp = importlib.util.spec_from_file_location(name + "_" + f, os.path.join(T, name + "_" + f + ".py"))
        m[f] = importlib.util.module_from_spec(sp); sp.loader.exec_module(m[f])
    return m["pushwho"], m["pushalert"]


Wn, An = load("new", NEW)
Wo, Ao = load("old", OLD)
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond))
    print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))


def sides(p):
    on = [r for r in p["rows"] if r["on"]]
    return {r["k"] for r in on if r["side"] > 0}, {r["k"] for r in on if r["side"] < 0}


po, pn = Wo.read("DATAPATTNS", NOW), Wn.read("DATAPATTNS", NOW)
uo, do_ = sides(po); un, dn = sides(pn)
print("DATAPATTNS +4.06%% (defence sector +1.0%%) · old: ▲ %d %s ▼ %d %s · %s" % (len(uo), sorted(uo), len(do_), sorted(do_), po["kind"]))
print("                                       new: ▲ %d %s ▼ %d %s · %s" % (len(un), sorted(un), len(dn), sorted(dn), pn["kind"]))
chk("old reproduces the screen: FII ▲ and DII ▼ from the market's figure, ⚪ TIDE ONLY", "FII" in uo and "DII" in do_ and po["kind"] == "TIDE ONLY", (uo, do_, po["kind"]))
chk("new: FII / DII off - DATAPATTNS has no FII / DII deal of its own", "FII" not in un and "DII" not in dn and not dn, (un, dn))
chk("new: ▲ 5 pushing up = WRITERS · FUTURES · COMPANY · TIDE · ALGOS", un == {"WRITERS", "FUTURES", "COMPANY", "TIDE", "ALGOS"}, un)
chk("new: +4.06% vs its sector +1.0% is 🔵 OWN MOVE, not ⚪ TIDE ONLY", pn["kind"] == "OWN MOVE" and "🔵" in pn["kline"] and "+1.0%" in pn["kline"], pn["kline"])
tr = next(r for r in pn["rows"] if r["k"] == "TIDE")
chk("new: the market's FII / DII figure is a note on TIDE (all shares - not this one's)", "FII bought ₹2,500 cr" in tr["t"] and "not this one's" in tr["t"], tr["t"])
p = Wn.read("LICI", NOW); u, _ = sides(p)
chk("LICI's own FII deal (Vanguard ₹210 cr) still lights FII ▲ · 🟢 NEW MONEY", "FII" in u and p["kind"] == "NEW MONEY", (u, p["kline"]))
p = Wn.read("WIPRO", NOW)
chk("WIPRO +1.6% with NIFTY +0.9%: still ⚪ TIDE ONLY", p["kind"] == "TIDE ONLY", p["kline"])
p = Wn.read("KEI", NOW)
chk("KEI +2.0% alone (sector flat), no money: 🔵 OWN MOVE", p["kind"] == "OWN MOVE" and "no sector / market tide" in p["advice"], p["kline"])
p = Wn.read("SBIN", NOW)
chk("SBIN +0.9%, nothing: no label (as before)", p["kind"] == "", p["kline"])
jo, jn = Ao.judge(Wo.read("ITC", NOW)), An.judge(Wn.read("ITC", NOW))
chk("ITC +2.1% with its sector, no money of its own: old said PUSH STARTED (market FII as money) - new does not", jo and not jn, (jo and len(jo[1]), jn))
jn = An.judge(pn)
chk("DATAPATTNS: still a push by the rule (2 money forces: futures + floor writers), now without the market's FII", jn and jn[0] == 1, jn)
t = An.text("DATAPATTNS", pn, 1, *jn[1:], 1.2, "09:41")
chk("the PUSH STARTED alert says 🔵 OWN MOVE", "🔵 ▲ OWN MOVE" in t, t)
print("patch 219 test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p219_patch.py $D || back
cd $D && python3 -m py_compile pushwho.py pushalert.py || back
mkdir -p $W/old && cp $D/pushwho.py.bak$TS $W/old/pushwho.py && cp $D/pushalert.py.bak$TS $W/old/pushalert.py
echo "=== test: sample shares (old code vs new)"
python3 $W/p219test.py $D $W/old || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== this server's 40 biggest F&O movers now - old reading vs new"
cd $D && python3 - $D $W/old/pushwho.py <<'PY_CMP'
import sys, os, json, importlib.util
D, OLDF = sys.argv[1], sys.argv[2]
sys.path.insert(0, D); os.chdir(D)
import pushwho as N
sp = importlib.util.spec_from_file_location("pushwho_old", OLDF); O = importlib.util.module_from_spec(sp); sp.loader.exec_module(O); O.BASE = D
st = json.load(open(os.path.join(D, "dash_state.json")))
fps = sorted([f for f in st.get("fo_paths") or [] if f.get("s") and f.get("chg") is not None], key=lambda f: -abs(f["chg"]))[:40]
cnt = lambda p: (sum(1 for r in p["rows"] if r["on"] and r["side"] > 0), sum(1 for r in p["rows"] if r["on"] and r["side"] < 0))
fii = kch = 0
print("   %-11s %7s  %-22s  %-22s" % ("share", "today", "old ▲ ▼ kind", "new ▲ ▼ kind"))
for f in fps:
    try:
        o, n = O.read(f["s"]), N.read(f["s"])
    except Exception as ex:
        print("   %-11s not read: %s" % (f["s"], str(ex)[:60])); continue
    fii += any(r["on"] and r["k"] in ("FII", "DII") for r in o["rows"]) and not any(r["on"] and r["k"] in ("FII", "DII") for r in n["rows"])
    kch += o["kind"] != n["kind"]
    print("   %-11s %+6.2f%%  ▲%d ▼%d %-15s  ▲%d ▼%d %-15s%s" % (f["s"], f["chg"], *cnt(o), o["kind"] or "-", *cnt(n), n["kind"] or "-", "  ← changed" if (o["kind"] != n["kind"] or cnt(o) != cnt(n)) else ""))
print("   %d of %d lost a FII / DII that was only the market's figure · %d changed their kind" % (fii, len(fps), kch))
p = N.read("DATAPATTNS")
print("=== DATAPATTNS now (new): %s%%  %s" % (p["chg"], p["kline"] or "no clear push"))
for r in p["rows"]:
    if r["on"]:
        print("   %-10s %s %s" % (r["k"], {1: "▲", -1: "▼", 0: "·"}[r["side"]], r["t"][:150]))
PY_CMP
systemctl restart gir-dash && sleep 12 && echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
if [ "$MKT" = "0" ]; then
  for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do systemctl restart $s 2>/dev/null; done
  sleep 8; for s in gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt; do echo "  $s: $(systemctl is-active $s)"; done
  echo "✅ patch 219 done - the page, the alerts' push line and PUSH STARTED all use the new reading. Ctrl + Shift + R on GIR."
else
  echo "✅ patch 219 on the page now (Ctrl + Shift + R on GIR) - the senders keep the old reading until you run this again after 15:35"
  echo "   (restarting them now would repeat today's PUSH STARTED / PROFIT BOOKING alerts)"
fi
echo "   undo: for f in pushwho.py pushalert.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash gir-newshunt"
