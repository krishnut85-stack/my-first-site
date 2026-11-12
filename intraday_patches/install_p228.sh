#!/bin/bash
# PATCH 228 - THE RING RULES (Rama chose all three, 12 Nov). Nothing is dropped - an alert that does not ring still goes to its channel without
#   sound and to the page, with "🔕 no ring - why".
#   ALWAYS RING (the ambulance and GIR's own alarms): 🔴 P1 calls · 🚨 RESULTS REACTION · 🎯 BOOK HALF / 🛑 EXIT / ⏰ TIME EXIT · 💼 · 🧱 CIRCUIT · feed / service
#   down · market-wide alerts.  1 one ring a share every 15 min · 2 YOUR RULE rings when it agrees with a GIR alert (or once a share in 30 min)
#   · 3 the other way within 30 min rings only when a 5-min candle confirms the turn (then "⚠ REVERSAL - at 14:30 you got ▼").
#   Tested: 14 cases; then TODAY's real alerts replayed through the rules (before / after). Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); mkdir -p $W/src
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
for f in alertword.py home.html; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
back(){ for f in alertword.py home.html; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/ringgov.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/src/ringgov.py <<'PY_RG'
#!/usr/bin/env python3
"""ringgov.py - patch 228: THE RING RULES (Rama chose all three, 12 Nov; the day's audit: 322 rings - PAGEIND 12, YOUR RULE 101, 6 contradictions).
Called by alertword.dress for every alert that would ring. Nothing is dropped: an alert that does not ring still goes to its channel (no
sound) and the page, with a line "🔕 no ring - why".
  ALWAYS RING  🔴 P1 calls (after THE VOTE) · 🚨 RESULTS REACTION · 🎯 BOOK HALF / 🛑 EXIT / ⏰ TIME EXIT · 💼 your trade · 🧱 CIRCUIT
               (near / at the band / band widened) · GIR's own
               alarms (feed / socket / service down, AI credit) · market-wide alerts (no share)
  1 one ring a share every 15 min - later alerts on that share in the 15 min come without sound
  2 YOUR RULE rings only when it agrees with a GIR alert on the share (same side, within 15 min) - patch 229
  3 the contradiction guard - the other way on a share within 30 min of a ring: no sound, unless a 5-min candle confirms the turn (closed its
    way, 0.5%+ from the price at that ring) -> it rings with "⚠ REVERSAL - at HH:MM you got ▲"
The rings are kept in data/ringgov.db (every GIR process shares it)."""
import os, re, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DB = os.path.join(BASE, "data", "ringgov.db")
SHARE_S, YR_S, AGREE_S, OPP_S, CONFIRM = 900, 1800, 900, 1800, 0.5
PROTECT = re.compile(r"🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT|RESULTS REACTION|💼|🧱 CIRCUIT|LIVE FEED DOWN|SOCKET (DOWN|BACK)|GIR AI SPEND|CREDIT USED UP|KEY REFUSED|"
                     r"MORNING BRIEF|OPENING CALL FAILED|SERVICE .*DOWN|IS DOWN|GIR DOWN|WATCHDOG")
SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")
NOT_SYM = ("CE", "PE", "BUY", "SELL", "UP", "DOWN", "OI", "GO", "CONFIRMED", "CRITICAL", "BIG", "MISS", "BEAT", "RESULTS", "NEWS", "REG", "ORDER",
           "DEAL", "IN", "LINE", "NEW", "MONEY", "BOTH", "FORCED", "OUT", "TIDE", "OWN", "MOVE", "PUSH", "PULL", "STARTED", "SHORT", "LONG")
_F = {}


def _db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    c = sqlite3.connect(DB, timeout=5)
    c.execute("create table if not exists rings(t real, sym text, side int, kind text, px real, yr int)")
    return c


def target(text):
    """-> (head, sym or None, +1 / -1 / 0)"""
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return "", None, 0
    h = L[1] if (L[0].startswith("🔔 OPENING") and not L[0].startswith("🔔 OPENING · ") and len(L) > 1) else L[0]
    h = h[len("🔔 OPENING · "):] if h.startswith("🔔 OPENING · ") else h
    cand = [m.group(1) for m in SYM_RX.finditer(h)] + [m.group(1) for m in re.finditer(r"·\s+([A-Z][A-Z0-9&\-]{1,19})\s+[▲▼]", h)]
    m = re.search(r"·\s+([A-Z][A-Z0-9&\-]{2,19})\s+(?:[₹(]|·|$)", h)
    if m:
        cand.append(m.group(1))
    sym = next((x for x in cand if x not in NOT_SYM), None)
    if sym in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX", "MARKET"):
        sym = None
    up, dn = ("▲" in h or bool(re.search(r"\bCE\b", h))), ("▼" in h or bool(re.search(r"\bPE\b", h)))
    if up == dn:                                                # no side in the head (YOUR RULE lines): the body's "→ CE / → PE"
        T = "\n".join(L)
        up, dn = bool(re.search(r"→\s*CE|BUY\s+(?:\d+\s+)?CE|▲ UP", T)), bool(re.search(r"→\s*PE|BUY\s+(?:\d+\s+)?PE|▼ DOWN", T))
    return h, sym, (1 if up and not dn else -1 if dn and not up else 0)


def _price(sym):
    try:
        t, q = _F.get("q", (0.0, None))
        if q is None or time.time() - t > 3:
            q = json.load(open(os.path.join(BASE, "quotes_live.json"))).get("q") or {}
            _F["q"] = (time.time(), q)
        v = q.get(sym)
        return float(v[0]) if v else None
    except Exception:
        return None


def _confirmed(sym, d, px0, now, candles=None):
    """the turn confirmed: the last closed 5-min candle closed its way, 0.5%+ from the price at the earlier ring"""
    try:
        if candles is None:
            t, ch = _F.get("ch", (0.0, None))
            if ch is None or time.time() - t > 10:
                ch = json.load(open(os.path.join(BASE, "charts.json"))); _F["ch"] = (time.time(), ch)
            candles = ch.get(sym) or {}
        O, C = candles.get("o") or [], candles.get("c") or []
        n = min(len(C), ((now.hour * 60 + now.minute) - 555) // 5)
        if n < 1 or not C[n - 1] or not O[n - 1] or not px0:
            return False
        return (C[n - 1] - O[n - 1]) * d > 0 and (C[n - 1] / px0 - 1) * 100 * d >= CONFIRM
    except Exception:
        return False


def _hm(t):
    return dt.datetime.fromtimestamp(t, IST).strftime("%H:%M")


def _quiet(text, why):
    return text.rstrip("\n") + "\n🔕 no ring - " + why, True


def gate(text, tr, now=None, px=None, candles=None):
    """an alert that would ring -> (text, silent?)"""
    now = now or dt.datetime.now(IST)
    t = now.timestamp()
    h, sym, d = target(text)
    yr = "YOUR RULE" in h
    kind = (h.split() or ["?"])[0]
    c = _db()
    try:
        c.execute("delete from rings where t < ?", (t - 86400,))
        if px is None and sym:
            px = _price(sym)

        def ring(txt):
            c.execute("insert into rings values (?, ?, ?, ?, ?, ?)", (t, sym or "", d, kind, px, 1 if yr else 0)); c.commit()
            return txt, False
        if tr == "act" or PROTECT.search(h) or not sym:
            return ring(text)
        R = c.execute("select t, side, kind, px, yr from rings where sym=? and t>=? order by t desc", (sym, t - max(OPP_S, YR_S))).fetchall()
        # 3 the contradiction guard
        opp = next((r for r in R if d and r[1] == -d and t - r[0] <= OPP_S), None)
        if opp:
            if _confirmed(sym, d, opp[3], now, candles):
                return ring(text.rstrip("\n") + "\n⚠ REVERSAL - at %s you got %s on %s; a 5-min candle confirms the turn" % (_hm(opp[0]), "▲" if opp[1] > 0 else "▼", sym))
            return _quiet(text, "the other way within 30 min of the %s at %s on %s, not confirmed by a 5-min candle" % ("▲" if opp[1] > 0 else "▼", _hm(opp[0]), sym))
        # 2 YOUR RULE
        if yr:
            agree = next((r for r in R if not r[4] and (r[1] == d or not d or not r[1]) and t - r[0] <= AGREE_S), None)
            last_yr = next((r for r in R if r[4] and t - r[0] <= YR_S), None)
            if agree:
                return ring(text.rstrip("\n") + "\n✔ agrees with GIR's %s at %s" % (agree[2], _hm(agree[0])))
            return _quiet(text, "your rule - it rings when it agrees with a GIR alert on %s (none the same way in the last 15 min)" % sym)   # patch 229
        # 1 one ring a share every 15 min
        last = next((r for r in R if t - r[0] <= SHARE_S), None)
        if last:
            return _quiet(text, "%s rang at %s (one ring a share every 15 min)" % (sym, _hm(last[0])))
        return ring(text)
    finally:
        c.close()
PY_RG
cat > $W/p228_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p228_patch.py - PATCH 228: THE RING RULES wired in (ringgov.py next to this script): alertword.dress asks ringgov.gate for every alert that
would ring · the page does not sound for a line marked "🔕 no ring". Usage: python3 p228_patch.py DIR SRCDIR"""
import sys, os, shutil
D, SRC = sys.argv[1], sys.argv[2]
ERR = []
shutil.copy(os.path.join(SRC, "ringgov.py"), os.path.join(D, "ringgov.py")); print("  ringgov.py: in")


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("alertword.py", '''def dress(text):
    """-> (text with the tag as its 2nd line when it rings, silent?).''', '''def dress(text):
    """patch 228: THE RING RULES on top of the levels - one ring a share / 15 min · your rules ring when they agree · the contradiction
    guard. P1, RESULTS REACTION, the exits and GIR's own alarms always ring. A held alert still goes out, without sound, marked 🔕."""
    out, silent = _dress0(text)
    if silent:
        return out, silent
    try:
        import ringgov
        return ringgov.gate(out, tier(text))
    except Exception:
        return out, silent


def _dress0(text):
    """-> (text with the tag as its 2nd line when it rings, silent?).''', "dress: the ring rules")
rep("home.html", '''const k=keyOf(r); if(ASEEN.has(k)) return; ASEEN.add(k); const tr=alertTier(r); if(tr==="watch") return;''',
    '''const k=keyOf(r); if(ASEEN.has(k)) return; ASEEN.add(k); const tr=alertTier(r); if(tr==="watch") return; if((r.lines||[]).some(x=>/^🔕 no ring/.test(x))) return;   /* patch 228: held by the ring rules - shown, no sound */''',
    "the page: no sound for 🔕")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 228 in")
PY_PATCH
cat > $W/p228test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p228test.py - THE RING RULES on 12 Nov's real cases (made-up files, temp folder, nothing sent).  python3 p228test.py DIR  (DIR: alertword.py, ringgov.py)"""
import os, sys, json, shutil, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("alertword.py", "ringgov.py"):
    shutil.copy(os.path.join(D, f), T)
sys.path.insert(0, T); os.chdir(T)
import ringgov as G, alertword as A
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); DAY = dt.datetime(2026, 11, 12, tzinfo=IST)
at = lambda h, m, s=0: DAY.replace(hour=h, minute=m, second=s)
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:400]))
def g(text, when, px=None, candles=None):
    t, silent = G.gate(text, A.tier(text), now=when, px=px, candles=candles or {})
    return t, silent
print("1 · one ring a share every 15 min")
r = [g("🚨 CRITICAL · THE REASON ▼ PAGEIND · 14:30", at(14, 30, 30), 35825), g("⚠️ SHOCK WATCH · ▼ PAGEIND · RESULTS · news 14:31", at(14, 31, 12), 35465),
     g("🧱 CIRCUIT ▼ PAGEIND ₹32915 · AT THE LOWER CIRCUIT (₹32915)", at(14, 36, 46), 32915), g("⚠️ SHOCK WATCH · ▼ PAGEIND · RESULTS · news 14:50", at(14, 50, 0), 32070)]
chk("PAGEIND: the first rings, the next in 15 min arrive silently (🔕 says why), 🧱 CIRCUIT always rings, 14:50 rings again", [x[1] for x in r] == [False, True, False, True] and "🔕 no ring - PAGEIND rang at 14:30" in r[1][0], [x[1] for x in r])
print("2 · ALWAYS RING")
t, s = g("🚨 CRITICAL · RESULTS REACTION ▼ PAGEIND · 14:31\n▶ BUY PE (at the money) - ▼ DOWN → PE · stop: a close over ₹36,500", at(14, 31, 30), 35000)
chk("🚨 RESULTS REACTION rings even 1 min after a PAGEIND ring", not s, t)
t, s = g("🚨 CRITICAL · 🛑 EXIT - STOP · PAGEIND PE · 14:32\nwhy: ...", at(14, 32), 35000)
chk("🛑 EXIT rings even 2 min after", not s)
t1, s1 = g("🟢 GO · SWIGGY ▲ CE · 10:00\nBUY: 300 CE ₹8", at(10, 0), 300); t2, s2 = g("⚡ ENTER NOW ▲ SWIGGY CE · ₹301 · 10:02\n▶ BUY 300 CE ₹8.5", at(10, 2), 301)
chk("P1 calls ring every time (SWIGGY 10:00 and 10:02)", not s1 and not s2)
t, s = g("📄 MARKET NEWS · MARKET · The Times of India 04:32", at(10, 5))
chk("a market-wide alert (no share) rings as before", not s)
print("3 · YOUR RULE rings only when it agrees with a GIR alert (patch 229)")
y1 = g('📒 YOUR RULE "roof breaking - writers running" · SBILIFE ₹1805.3 +2.2% · 10:00\n→ CE', at(10, 0), 1805.3)
y2 = g('📒 YOUR RULE "big money buying futures" · SBILIFE ₹1808 +2.4% · 10:10\n→ CE', at(10, 10), 1808)
p2 = g("🚨 CRITICAL · PUSH STARTED ▲ SBILIFE · 10:16", at(10, 16), 1812)
y3 = g('📒 YOUR RULE "roof breaking - writers running" · SBILIFE ₹1815 +2.8% · 10:20\n→ CE', at(10, 20), 1815)
chk("a YOUR RULE on SBILIFE with no GIR alert there: silent (patch 229 - it rings only when it agrees)", y1[1] and "it rings when it agrees with a GIR alert on SBILIFE" in y1[0], y1)
chk("the second 10 min later: silent too", y2[1], y2)
chk("... GIR's own alert on SBILIFE at 10:16 rings (nothing rang there before)", not p2[1], p2)
p3 = g("🧩 LONG BUILD-UP ▲ SBILIFE ₹1816 +2.9% · 10:21\n▶ WATCH CE 1820", at(10, 21), 1816)
G_ = G._db(); G_.execute("insert into rings values (?, 'SBILIFE', 1, '🧩', 1816, 0)", (at(10, 21).timestamp(),)); G_.commit(); G_.close()   # a GIR alert on SBILIFE rang (e.g. P2 critical)
y4 = g('📒 YOUR RULE "big money buying futures" · SBILIFE ₹1818 +3.0% · 10:24\n→ CE', at(10, 24), 1818)
chk("a YOUR RULE that agrees with a GIR alert on SBILIFE (▲, 3 min before) rings, with '✔ agrees with'", not y4[1] and "✔ agrees with GIR's" in y4[0], y4)
print("4 · the contradiction guard")
b1 = g("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS · NSE 13:54", at(13, 46), 1063.95)
flat = {"o": [1064.0] * 35, "c": [1063.0] * 35}
b2 = g('📒 YOUR RULE "rising fast" ▲ BDL ₹1063.95 · 13:55\n→ CE', at(13, 55), 1063.95, flat)
chk("BDL ▼ at 13:46 then ▲ at 13:55, no candle confirms: silent (🔕 the other way within 30 min)", b2[1] and "the other way within 30 min of the ▼ at 13:46 on BDL" in b2[0], b2)
h1 = g("🚀 RUNNING ▼ HAL ₹4000 -1.5% · 13:25", at(13, 25), 4000.0)
turn = {"o": [3990.0] * 34 + [4005.0], "c": [3990.0] * 34 + [4030.0]}          # the 13:45 candle (index 34) closed green, +0.75% from 4000
h2 = g("🚀 RUNNING ▲ HAL ₹4032 +0.8% · 13:50", at(13, 50), 4032.0, turn)
chk("HAL ▼ at 13:25 then ▲ at 13:50 with a green 5-min candle +0.75%: rings with ⚠ REVERSAL", not h2[1] and "⚠ REVERSAL - at 13:25 you got ▼ on HAL" in h2[0], h2)
print("5 · through alertword.dress (what every sender calls)")
chk("the share is read right from real heads (▼ BDL · RESULTS · BIG MISS -> BDL)", G.target("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS")[1:] == ("BDL", -1), G.target("🚨 CRITICAL · RESULTS ▼ BDL · RESULTS · BIG MISS"))
x1 = A.dress("🚨 CRITICAL · PUSH STARTED ▲ TESTSYM · now"); x2 = A.dress("⚠️ SHOCK WATCH · ▲ TESTSYM · ORDER · news now")
chk("dress: the first rings, a repeat seconds later is silent and marked 🔕", x1[1] is False and x2[1] is True and "🔕 no ring" in x2[0], (x1[1], x2[1]))
q = A.dress("🔍 WHY ▲ BAJFINANCE +2.7% · CLEAR")
chk("dress: a quiet line stays quiet (as before)", q[1] is True and "🔕" not in q[0], q)
print("RING RULES test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p228_patch.py $D $W/src || back
cd $D && python3 -m py_compile ringgov.py alertword.py || back
echo "=== test: the ring rules on 12 Nov's cases"
python3 $W/p228test.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== TODAY's real alerts replayed through the ring rules (a test copy - the live rings are not touched)"
cd $D && python3 - "$(TZ=Asia/Kolkata date +%F)" "$W/replay.db" <<'PY'
import sys, json, sqlite3, collections, datetime as dt
sys.path.insert(0, "/home/globalbot/intraday")
import alertword, ringgov
day, ringgov.DB = sys.argv[1], sys.argv[2]
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
c = sqlite3.connect("file:tomorrow.db?mode=ro", uri=True)
rows = c.execute("select t, sym, text from alerts where day=? order by t", (day,)).fetchall(); c.close()
ch = json.load(open("charts.json"))
before, after, keep, held = collections.Counter(), collections.Counter(), [], []
kb, ka = collections.Counter(), collections.Counter()
rev = 0
for t, s, tx in rows:
    tx = tx or ""
    tr = alertword.tier(tx)
    if tr == "read":
        continue
    h, sym, d = ringgov.target(tx)
    k = (tx.split() or ["?"])[0]
    before[sym or "-"] += 1; kb[k] += 1
    hh, mm, ss = (int(x) for x in (str(t) + ":00")[:8].split(":"))
    now = dt.datetime.fromisoformat(day).replace(hour=hh, minute=mm, second=ss, tzinfo=IST)
    cc = ch.get(sym) or {}
    C = cc.get("c") or []
    i = min(len(C), ((hh * 60 + mm) - 555) // 5)
    px = C[i - 1] if 0 < i <= len(C) and C[i - 1] else None
    out, silent = ringgov.gate(tx, tr, now=now, px=px, candles=cc)
    if silent:
        held.append((str(t)[:5], out.split("\n")[0][:60], out.split("\n")[-1][2:80]))
    else:
        after[sym or "-"] += 1; ka[k] += 1
        rev += "⚠ REVERSAL" in out
nb, na = sum(before.values()), sum(after.values())
print("   rang today: %d  ->  with the rules: %d  (%d arrive silently, marked 🔕) · %d REVERSAL rings" % (nb, na, nb - na, rev))
print("   by kind (before -> after): " + " · ".join("%s %d->%d" % (k, n, ka[k]) for k, n in kb.most_common(10)))
print("   the busiest shares (before -> after): " + " · ".join("%s %d->%d" % (s, n, after[s]) for s, n in before.most_common(10) if s != "-"))
prot = sum(1 for t, s, tx in rows if alertword.tier(tx or "") == "act" or ringgov.PROTECT.search(ringgov.target(tx or "")[0]))
print("   always ringing (P1, results reaction, exits, GIR alarms): %d - none of them held" % prot)
print("   a few that would have come silently:")
for x in held[:10]:
    print("     %s %-60s %s" % x)
PY
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 228 done - the three ring rules are on; P1, results reactions and exits ring as always. Ctrl + Shift + R on GIR."
echo "   undo: for f in alertword.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; rm $D/ringgov.py; systemctl restart $SV"
