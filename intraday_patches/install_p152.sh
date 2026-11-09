#!/bin/bash
# PATCH 152 - THE RULES THE 3-YEAR STUDY SET + THE SECTORS SCROLL. 🌅 OPENING CALL: quiet list at 09:12, rings at 09:20 only if the first
#   5 minutes went its way (3 years: +1.5% first 48%, stopped 40%; the gap alone loses). ⚡ ENTER NOW: no ring on rotation laggards
#   (3 years: 34% win, 53% loss); 🔄 ROTATION quiet context. SECTORS scrolls. enternow.py · opencall.py · alertword.py · home.html.
#   Restarts gir-dash and gir-intraday - run outside market hours (before 08:45 is fine).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g152; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 or before 08:45"; exit 1; fi
grep -q "patch 152" $D/opencall.py && { echo "patch 152 is already installed"; exit 1; }
F="enternow.py opencall.py alertword.py home.html p142test.py p143test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p152_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p152_patch.py - PATCH 152: THE RULES THE 3-YEAR STUDY SET (9 Nov 22:10, 742 days, 219 F&O shares) + the SECTORS scroll.
  B  the opening gap alone LOSES (every size: -0.06% to -0.50% a trade). The gap + the FIRST 5 MINUTES going its way WINS: +1.5% first
     48% of the time, stopped 40%, +0.53% a trade; against: 5% / 90%. So 🌅 OPENING CALL no longer rings at 09:12 - the candidates are
     listed quietly ("waits for 09:20"); at 09:20 a candidate whose first 5-minute candle went its way rings as 🌅 OPENING CALL · GO ·
     CONFIRMED; one that went against is dropped (said quietly).
  C  the rotation laggards: 689 trades, WIN 34% · LOSS 53% - no edge (9 Nov's 7 of 7 was one day). ⚡ ENTER NOW no longer rings on a
     rotation (it stays a 📋 TRIAL ENTRY, scored); 🔄 MARKET ROTATION is shown quietly, as context.
  SECTORS  an old rule (the round chart's overflow:hidden) blocked its scroll - removed; the scroll bars lighter, easier to see.
Usage: python3 p152_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
HERE = os.path.dirname(os.path.abspath(__file__))
F = {
 "enternow.py": [
  ('LIVE_KINDS = {"news-pre": 600, "rot-in": 630, "open-call": 600}', 'LIVE_KINDS = {"news-pre": 600, "open-call": 600}   # patch 152: rot-in out - 3 years: 34% WIN 53% LOSS'),
  ('(VWAP · writers · order book) - measured 9 Nov: 7 of 7 early laggards went +1%")', '(VWAP · writers · order book) - context only: over 3 years the laggards alone won 34%, lost 53%")'),
 ],
 "alertword.py": [
  ('''    if "MARKET ROTATION" in H2:                                  # patch 142: the money moving between sectors
        return "move"''', '''    if "MARKET ROTATION" in H2:                                  # patch 152: context, quiet (3 years: no edge alone)
        return "read"'''),
 ],
 "opencall.py": [
  ('''    if send:
        for x in go:
            send(x["text"])
        send(res["summary"])
    return res''', '''    if send:                                                     # patch 152: no ring at 09:12 - the first 5 minutes decide (09:20)
        send(res["summary"])
    return res'''),
  ('''    S = ["📋 OPENING CALL · the rest %s · %d with a reason · %d GO (rang in Box Picks)" % (now.strftime("%H:%M"), len(C), len(go))]''',
   '''    S = ["📋 OPENING CALL %s · %d with a reason · %d wait for 09:20 - a GO rings only if its first 5 minutes go its way (3 years: +1.5%% first 48%% · stopped 40%%; the gap alone loses)" % (now.strftime("%H:%M"), len(C), len(go))]
    S += ["WAITS FOR 09:20 %s %s · gap %+.1f%%" % ("▲" if x["d"] > 0 else "▼", x["s"], (x["open"] / x["pc"] - 1) * 100) for x in go]'''),
  ('''    for x in J["go"]:
        if x.get("failed"):
            continue
        v = q.get("NSE:" + x["s"]) or {}
        px = float(v.get("last_price") or 0)
        if not px:
            continue
        d = x["d"]
        sd = "CE" if d > 0 else "PE"
        if (px - x["stop"]) * d < 0:''', '''    for x in J["go"]:
        if x.get("failed") or x.get("confirmed") is False:
            continue
        v = q.get("NSE:" + x["s"]) or {}
        px = float(v.get("last_price") or 0)
        if not px:
            continue
        d = x["d"]
        sd = "CE" if d > 0 else "PE"
        if x.get("confirmed") is None:                            # patch 152: the first check - the first 5 minutes decide
            if (px - x["open"]) * d > 0 and (px - x["stop"]) * d > 0:
                x["confirmed"] = True
                L_ = x["text"].split("\\n")
                L_[0] = L_[0].replace("· GO ·", "· GO · CONFIRMED %s ·" % now.strftime("%H:%M"), 1)
                out.append("\\n".join(L_ + ["✅ the first 5 minutes went its way: ₹%s → ₹%s · 3 years: +1.5%% first 48%% of the time, stopped 40%%" % (_p(x["open"]), _p(px))]))
            else:
                x["confirmed"] = False
                out.append("· DROPPED %s %s · its first 5 minutes went against (₹%s → ₹%s) - 3 years: +1.5%% first only 5%%" % (x["s"], sd, _p(x["open"]), _p(px)))
            continue
        if (px - x["stop"]) * d < 0:'''),
  ('''        bad = [x for x in out if x.startswith("❌")]
        for x in bad:
            send(x)''', '''        bad = [x for x in out if x.startswith("❌") or x.startswith("🌅")]   # patch 152: + the confirmed GO
        for x in bad:
            send(x)
        dr = [x for x in out if x.startswith("· DROPPED")]
        if dr:
            send("📋 OPENING CALL 09:20 - dropped\\n" + "\\n".join(dr))'''),
 ],
 "p142test.py": [
  ('''check("PNB gets a ringing ⚡ ENTER NOW CE from the early rotation (%s)" % (E.hm(p[0]) if p else "—"), p and p[1].startswith("⚡ ENTER NOW ▲ PNB CE") and "rotation into PSU BANKS" in p[1])''',
   '''check("patch 152: PNB from the rotation is a quiet 📋 TRIAL ENTRY (3 years: no edge)", p and p[1].startswith("📋 TRIAL ENTRY ▲ PNB CE") and "rotation into PSU BANKS" in p[1])'''),
  ('''check("⚡ ENTER NOW rings as act and goes to Box Picks", alertword.tier(p[1]) == "act" and tglanes.lane(p[1]) == "critical")''',
   '''check("⚡ ENTER NOW rings as act and goes to Box Picks", alertword.tier("⚡ ENTER NOW ▲ PNB CE · ₹127") == "act" and tglanes.lane("⚡ ENTER NOW ▲ PNB CE · ₹127") == "critical")'''),
  ('''check("ROTATION goes to Box Picks, ringing", tglanes.lane(r[0][1]) == "critical" and alertword.tier(r[0][1]) in ("move", "act"))''',
   '''check("patch 152: ROTATION is quiet context", alertword.tier(r[0][1]) == "read")'''),
 ],
 "home.html": [
  ('#mk #mk-nif,#mk #mk-don{overflow:hidden}', '#mk #mk-nif{overflow:hidden}#mk #mk-don{overflow-y:auto}   /* patch 152: SECTORS scrolls */'),
  ('#mk .q .bd{scrollbar-width:thin;scrollbar-color:var(--line2) transparent}', '#mk .q .bd{scrollbar-width:auto;scrollbar-color:#5E6F92 var(--panel2)}'),
 ],
}


def main():
    out = {}
    for fn, eds in F.items():
        p = os.path.join(D, fn)
        if not os.path.exists(p):
            print("missing %s" % fn); return 1
        s = open(p, encoding="utf-8").read()
        if "patch 152" in s:
            print("patch 152 is already in %s" % fn); return 1
        for a, b in eds:
            if s.count(a) != 1:
                print("ANCHOR x%d in %s: %s" % (s.count(a), fn, a[:80].replace("\n", " | "))); return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    t = os.path.join(HERE, "p143test.py")
    if os.path.exists(t):
        open(os.path.join(D, "p143test.py"), "w", encoding="utf-8").write(open(t, encoding="utf-8").read())
    print("patched: %s" % ", ".join(sorted(F)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $W/p143test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p143test.py - patch 143: 🌅 OPENING CALL on a made-up morning (a temporary folder, a fake Kite - nothing live touched):
  COCHINSHIP results TODAY, opens +1.6% with buyers 2x -> GO CE, HALF size, out by 14:30 · EICHERMOT results in 4 days, +0.8%,
  buyers 1.5x -> GO · VOLTAS news ▼ but opens +1.0% -> NO · IREDA news ▲ but opens +5.2% -> WAIT (late) · PNB news ▲ flat -> WAIT
  TITAN news ▲ +0.9% but sellers 2x -> WAIT · a holiday (no pre-open trades) -> nothing · 09:20: COCHINSHIP back under the stop
  -> ❌ FAILED, EICHERMOT holding -> ✅ · the GO is a ringing ⚡ ENTER NOW signal · the routing"""
import os, sys, json, sqlite3, tempfile, shutil, datetime as dt
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import opencall as O
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
O.BASE, O.FILE = T, os.path.join(T, "data", "opencall.json")
IST = O.IST
now = dt.datetime(2026, 11, 10, 9, 12, tzinfo=IST)
c = sqlite3.connect(os.path.join(T, "chains.db"))
c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,?)", [(s, 100) for s in ("COCHINSHIP", "EICHERMOT", "VOLTAS", "IREDA", "PNB", "TITAN", "ODDGAP")])
c.execute("create table results_cal(sym text, d text)"); c.executemany("insert into results_cal values(?,?)", [("COCHINSHIP", "2026-11-10"), ("EICHERMOT", "2026-11-14")])
c.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
c.executemany("insert into chain15 values(?,?,?,?,?,?,?,?,?)", [("2026-11-09", "15:15", "COCHINSHIP", "2026-11-23", k, "CE", oi, 20, 1240) for k, oi in ((1240, 5e5), (1260, 9e5), (1280, 4e5))])
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.executemany("insert into alerts values(?,?,?,?,?,?)", [("2026-11-09", "18:10:00", "📄", "VOLTAS", "PE", "📄 NEWS ▼ VOLTAS · RATING · x"), ("2026-11-10", "08:40:00", "📄", "IREDA", "CE", "📄 NEWS ▲ IREDA · OTHER · y"),
    ("2026-11-10", "08:41:00", "📄", "PNB", "CE", "📄 NEWS ▲ PNB · OTHER · z"), ("2026-11-10", "08:42:00", "📄", "TITAN", "CE", "📄 NEWS ▲ TITAN · OTHER · w")])
c.commit(); c.close()
Q = {"COCHINSHIP": (1260.0, 1240.0, 2e5, 1e5), "EICHERMOT": (7560.0, 7500.0, 3e4, 2e4), "VOLTAS": (1040.0, 1029.7, 1e4, 1e4), "IREDA": (120.0, 114.0, 1e6, 5e5),
     "PNB": (132.1, 132.0, 1e6, 1e6), "TITAN": (5050.0, 5005.0, 1e4, 2e4), "ODDGAP": (103.0, 100.0, 1, 1)}
class K:
    vol = 1000
    px = {}
    def quote(self, keys):
        out = {}
        for k in keys:
            s = k.split(":", 1)[1]
            if s == "NIFTY 50":
                out[k] = {"last_price": 25100.0, "ohlc": {"close": 25044.65}}; continue
            if s in Q:
                op, pc, bq, sq = Q[s]
                out[k] = {"last_price": self.px.get(s, op), "ohlc": {"open": op, "close": pc}, "buy_quantity": bq, "sell_quantity": sq, "volume": K.vol}
        return out
import types
sys.modules["dashserve"] = types.SimpleNamespace(_stale_news=lambda h, x: "ALREADY KNOWN" in (x or ""))   # the freshness check is tested in p138
SENT = []
r = O.run(K(), now, SENT.append)
G = {x["s"]: x for x in r["go"]}
print(G.get("COCHINSHIP", {}).get("text", "no COCHINSHIP")); print(); print(r["summary"]); print()
check("COCHINSHIP: results TODAY + gap +1.6% + buyers 2x -> GO CE", "COCHINSHIP" in G and "🌅 OPENING CALL ▲ COCHINSHIP CE · GO" in G["COCHINSHIP"]["text"])
check("COCHINSHIP: HALF size, out by 14:30, the strike CE 1260, the stop", all(x in G["COCHINSHIP"]["text"] for x in ("HALF size", "out by 14:30", "CE 1260", "stop: COCHINSHIP below")))
check("EICHERMOT: results in 4 days, +0.8%, buyers 1.5x -> GO", "EICHERMOT" in G)
check("VOLTAS: news ▼ but opens up -> NO", any(g == "NO" and "VOLTAS" in l for g, l in r["rest"]))
check("IREDA: +5.3% - late -> WAIT", any(g == "WAIT" and "IREDA" in l and "late" in l for g, l in r["rest"]))
check("PNB flat -> WAIT", any(g == "WAIT" and "PNB" in l for g, l in r["rest"]))
check("TITAN: sellers 2x -> WAIT", any(g == "WAIT" and "TITAN" in l and "book" in l for g, l in r["rest"]))
check("ODDGAP +3% with no reason: listed as a look, not a call", "ODDGAP +3.0%" in r["summary"] and "ODDGAP" not in G)
check("patch 152: at 09:12 only the quiet summary (the GO waits for 09:20)", len(SENT) == 1 and "WAITS FOR 09:20 ▲ COCHINSHIP" in SENT[0])
K.vol = 0
check("a holiday (no pre-open trades): nothing", O.run(K(), now, SENT.append)["go"] == [] and len(SENT) == 1)
K.vol = 1000
O.run(K(), now, None)
K.px = {"COCHINSHIP": 1255.0, "EICHERMOT": 7590.0}
out = O.check(K(), now.replace(minute=20), SENT.append)
print("\n".join(out)); print()
check("09:20: COCHINSHIP's first 5 minutes against (1260 -> 1255) -> DROPPED, not rung", any(x.startswith("· DROPPED COCHINSHIP CE") for x in out))
check("09:20: EICHERMOT's first 5 minutes its way -> 🌅 OPENING CALL · GO · CONFIRMED, rings", any(x.startswith("🌅 OPENING CALL ▲ EICHERMOT CE · GO · CONFIRMED 09:20") for x in out))
check("the confirmed GO and the dropped list sent", any(x.startswith("🌅 OPENING CALL ▲ EICHERMOT") for x in SENT) and any("dropped" in x for x in SENT))
K.px = {"EICHERMOT": 7480.0}
o2 = O.check(K(), now.replace(minute=35), SENT.append)
check("09:35: EICHERMOT under its stop -> ❌ FAILED; COCHINSHIP (dropped) not mentioned", any(x.startswith("❌ OPENING CALL FAILED ▼ EICHERMOT CE") for x in o2) and not any("COCHINSHIP" in x for x in o2))
import alertword, tglanes
g = [x for x in out if x.startswith("🌅")][0]; f = [x for x in o2 if x.startswith("❌")][0]; sm = r["summary"]
check("GO and FAILED ring (act) in Box Picks", alertword.tier(g) == "act" and tglanes.lane(g) == "critical" and alertword.tier(f) == "act" and tglanes.lane(f) == "critical")
check("the summary is quiet, in ⚙️ System", alertword.tier(sm) == "read" and tglanes.topic(sm) == "system")
import enternow as E
D = E.Data("2026-11-10")
D.by_sym = {"COCHINSHIP": [(552, "🌅", "COCHINSHIP", "CE", g.split("\n")[0], g)]}
tr = E.triggers(D, "COCHINSHIP", 570, {})
check("⚡ ENTER NOW reads the GO as a ringing signal until 10:00 (%s)" % tr, tr and tr[0][0] == "open-call" and "open-call" in E.live_kinds() and E.live_kinds()["open-call"] == 600)
src = open(os.path.join(HERE, "home.html"), encoding="utf-8").read()
check("the page: the call and FAILED are ACT chips", "OPENING CALL FAILED/.test(H)) return \"act\"" in src)
shutil.rmtree(T)
print("P143 (+152) OPENING CALL TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p152_patch.py $D || { echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile enternow.py opencall.py alertword.py || back
for t in p143test.py p142test.py p140test.py p151test.py p150test.py; do [ -f $t ] && { timeout 120 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep "^FAIL" | head -3; back; }; }; done
systemctl restart gir-dash gir-intraday && sleep 15
for s in gir-dash gir-intraday; do [ "$(systemctl is-active $s)" = "active" ] || { echo "$s did not come back"; back; }; done
echo
echo "PATCH 152 APPLIED. Tomorrow: 09:12 the opening candidates (quiet) · 09:20 a CONFIRMED GO rings. Reload the page (Ctrl+F5)."
