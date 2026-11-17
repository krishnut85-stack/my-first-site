#!/bin/bash
# PATCH 387 - 🔕 THE LOSING AND LATE ALARMS GO QUIET; THE EARLY WINNERS KEEP RINGING (Rama, 17 Nov 20:40: "Yes, quiet the losing alert types. I want
#   the winning alert types - the early alert, not the late alert"). The alert audit (alertaudit.py, every alert scored against the shares
#   already moving at the same time of day):
#   · QUIET now (still on the page and in Box Picks, but no ring - on the phone or the page):
#       losing  SUDDEN · TRIAL ENTRY · OI · CALLS BOUGHT · ROOF MOVED / FLOOR MOVED   (worse than no alert, or no edge)
#       late    RUNNING · MOVER   (they win, but they come AFTER the move - Rama wants the early alert)
#   · STILL RING: the early winners OPENING · FIRST MOVE · SPEED · YOUR RULE · LONG BUILD-UP; your own trade's EXIT / BOOK HALF / STOP / TIME
#     EXIT; and the NEWS (not a trade signal by itself in the audit - but Rama needs to react to news fast, so it keeps ringing as before)
#   · everything else rings exactly as before - checked on TODAY'S real alerts: the quiet types now silent, every other alert unchanged
#   The type of an alert is read exactly as the audit read it (alertaudit.kind_of). Edits alertword.py (a wrapper at its end) and home.html.
#   Undo puts both back. Safe at any hour (the dashboard restarts; alertword is read fresh by each sender).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 387" $D/alertword.py && grep -q "patch 387" $D/home.html; then echo "patch 387 - already in"; exit 0; fi
[ -f $D/alertword.py ] && [ -f $D/alertaudit.py ] && grep -q "patch 374" $D/home.html || { echo "alertword.py / alertaudit.py / patch 374 (the page's sounds) not found - nothing done"; exit 1; }
cat > $W/add.py <<'PY_ADD'


# ---- patch 387: the losing and late alert types are QUIET (Rama, 17 Nov: "quiet the losing alert types - I want the early winners").
#      They still reach Box Picks and the page; they do not ring. The type is read exactly as the alert audit reads it.
QUIET_387 = ("SUDDEN", "TRIAL ENTRY", "OI", "CALLS BOUGHT", "ROOF MOVED", "FLOOR MOVED", "RUNNING", "MOVER")
NEVER_QUIET_387 = re.compile(r"EXIT|BOOK HALF|STOP|TIME EXIT|💼|🛑|GIR DECIDES|BE READY|GIR ANALYST")


def quiet_387(text):
    try:
        import alertaudit
        first = (text or "").split("\n")[0]
        if NEVER_QUIET_387.search(first):
            return False
        k = alertaudit.kind_of(text)
        return any(k == q or k.startswith(q + " ") for q in QUIET_387)
    except Exception:
        return False


_tier_387 = tier


def tier(text):
    if quiet_387(text):
        return "read"
    return _tier_387(text)
PY_ADD
echo "== 1. the check on TODAY's real alerts (a copy in a temp folder; nothing sent)"
T=$(mktemp -d); cp $D/alertword.py $D/alertaudit.py $T/; [ -f $D/ringgov.py ] && cp $D/ringgov.py $T/
cp $T/alertword.py $T/alertword_old.py; cat $W/add.py >> $T/alertword.py
python3 - $T $D <<'PY_TEST' || { echo "❌ the check failed - nothing changed"; exit 1; }
import os, sys, sqlite3, collections, importlib, datetime as dt
T, D = sys.argv[1], sys.argv[2]; sys.path.insert(0, T); sys.path.insert(1, D); os.chdir(T)
import alertaudit as AA
NEW = importlib.import_module("alertword"); OLD = importlib.import_module("alertword_old")
p = next((x for x in (os.path.join(D, "tomorrow.db"), os.path.join(D, "data", "tomorrow.db")) if os.path.exists(x)), None)
c = sqlite3.connect("file:%s?mode=ro" % p, uri=True); day = c.execute("select max(day) from alerts").fetchone()[0]
A = [r[0] for r in c.execute("select text from alerts where day=?", (day,))]; c.close()
rang_old, rang_new, changed_other = collections.Counter(), collections.Counter(), 0
for txt in A:
    k = AA.kind_of(txt); o = OLD.tier(txt); n_ = NEW.tier(txt)
    if o != "read":
        rang_old[k] += 1
    if n_ != "read":
        rang_new[k] += 1
    if not NEW.quiet_387(txt) and o != n_:
        changed_other += 1
print("  %s: %d alerts in GIR's log · rang before: %d · ring now: %d" % (day, len(A), sum(rang_old.values()), sum(rang_new.values())))
for k in sorted(set(rang_old) | set(rang_new), key=lambda k: -rang_old[k]):
    print("    %-22s rang %4d -> %4d%s" % (k[:22], rang_old[k], rang_new[k], "   🔕 quiet" if rang_new[k] < rang_old[k] else ""))
ok = changed_other == 0 and all(rang_new[k] == 0 for k in rang_new if any(k == q or k.startswith(q + " ") for q in NEW.QUIET_387))
for s in ("🛑 EXIT ALL UPL - stop hit", "🎯 BOOK HALF UPL ▲"):
    ok = ok and not NEW.quiet_387(s)
print("  %s every other alert rings exactly as before (%d changed) · the quiet types do not ring · your EXIT / BOOK HALF never quiet" % ("✓" if ok else "✗", changed_other))
sys.exit(0 if ok else 1)
PY_TEST
rm -rf $T
echo "== 2. the files"
F="alertword.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "❌ old files put back - nothing changed"; exit 1; }
cat $W/add.py >> $D/alertword.py && cd $D && python3 -m py_compile alertword.py || back
cat > $W/home_add.html <<'ADD_387'
<script>/* patch 387 (Rama, 17 Nov: "quiet the losing alert types - I want the early winners, not the late alerts"): on the page too, an alert of
   a quiet type (SUDDEN, TRIAL ENTRY, OI, CALLS BOUGHT, ROOF / FLOOR MOVED - losing; RUNNING, MOVER - late) makes no sound. It still shows.
   The type is read as the alert audit reads it (alertaudit.kind_of, the same order of names). */
(function(){
  const TYPES=["HEADS-UP","BUY CE","BUY PE","TRADE ALERT","ENTER NOW","OPENING CALL","MOVE CARD","TRADE CARD","NEWS SHOCK","SECTOR JUMP","SECTOR","FIRST MOVE","RUNNING","SPEED","MOVER","SUDDEN",
    "PROFIT BOOKING","SHOCK WATCH","YOUR VIEW","OPENING","WHY","NEWS","RESULTS","OI","BREAK","STRONG3","BOUNCE","WEAK","GAPDAY","BOOK HALF","EXIT","HOLD","STILL GOING","CRITICAL"];
  const QUIET=["SUDDEN","TRIAL ENTRY","OI","CALLS BOUGHT","ROOF MOVED","FLOOR MOVED","RUNNING","MOVER"];
  const esc=s=>s.replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
  function kindOf(t){ const first=String(t||"").split("\n")[0].toUpperCase();
    for(const k of TYPES){ if(new RegExp("(?<![A-Z])"+esc(k)+"(?![A-Z])").test(first)) return k; }
    const m=/[A-Z][A-Z &'-]{3,24}/.exec(first); return (m?m[0].trim():"OTHER").slice(0,24); }
  function quiet(h){ const first=String(h||"").split("\n")[0]; if(/EXIT|BOOK HALF|STOP|TIME EXIT|💼|🛑|GIR DECIDES|BE READY|GIR ANALYST/.test(first)) return false;
    const k=kindOf(first); return QUIET.some(q=>k===q||k.startsWith(q+" ")); }
  window.gxQuiet387=quiet;
  function wrap(){ if(window.__gx387w||typeof window.gxAlarm!=="function") return; window.__gx387w=1; const old=window.gxAlarm;
    window.gxAlarm=function(kind){ if(quiet(window.GXRH)){ window.GXRH=""; return; } return old.apply(this,arguments); }; }
  setInterval(wrap,2000); setTimeout(wrap,800); })();
</script>
<!-- patch 387 -->
ADD_387
python3 - $D/home.html $W/home_add.html <<'PY_EDIT' || back
import sys
h, a = sys.argv[1], sys.argv[2]; t = open(h, encoding="utf-8").read()
if "patch 387" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(a, encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the quiet types make no sound on the page")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
systemctl restart gir-dash; sleep 5; [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 387 done - refresh GIR (Ctrl+Shift+R). From now: SUDDEN, TRIAL ENTRY, OI, CALLS BOUGHT, ROOF / FLOOR MOVED, RUNNING and MOVER"
echo "   show on the page and in Box Picks but do not ring. OPENING, FIRST MOVE, SPEED, YOUR RULE, LONG BUILD-UP, the news and your exits ring as before."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
