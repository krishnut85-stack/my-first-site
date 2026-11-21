#!/bin/bash
# PATCH 231 - EVERY RESULT REACHES YOU, WITH ITS NUMBERS AND A PLAIN READ (Rama, 12 Nov: RVNL / NMDC "the verdict follows in 1-3 minutes", then
#   nothing; at 21:00 the digest showed only "FILING · RESULTS · IN LINE"). GIR had the numbers in ~2 min - an IN LINE result was a quiet line.
#   · a result WITH its numbers always goes to Telegram at once, full text (BEAT / MISS ring, IN LINE without sound); "XBRL NOT UP YET" stays out
#   · under the numbers: "plain read: STRONG / STEADY / MIXED / FLAT / WEAK - why" (sales vs profit vs margins, a loss)
#   · a share whose results are out leaves the "results coming" list
#   Tested: 13 cases on tonight's 6 results. Restarts the senders and the page server - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
F="tgquiet.py exchange.py resultsdesk.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-dash"
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p231_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p231_patch.py - PATCH 231: EVERY RESULT REACHES YOU, WITH ITS NUMBERS AND A PLAIN READ (Rama, 12 Nov: RVNL / NMDC "just filed - the verdict
follows in 1-3 minutes", then nothing; the digest at 21:00 showed only "FILING · RESULTS · IN LINE"). GIR had read the numbers within ~2 min,
but an IN LINE result has no ▲/▼, so it was a quiet line -> the hourly digest, headline only.
  tgquiet      a results line WITH its numbers (BEAT / MISS / IN LINE) always goes to Telegram at once, full text (IN LINE without sound);
               the interim "XBRL NOT UP YET" stays out
  exchange     under the numbers, a plain read: STRONG / STEADY / MIXED / FLAT / WEAK and why (sales vs profit vs margins, a loss)
  resultsdesk  a share whose results are already out leaves the "results coming" list (RVNL showed for tomorrow after filing tonight)
Usage: python3 p231_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        ERR.append("%s missing" % f); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("tgquiet.py", '''        return alertword.tier(text) != "read"''', '''        if re.search(r"·\\s*RESULTS\\s*·[^\\n]*\\b(BEAT|MISS|IN LINE)\\b", H2) and not re.search(r"NOT UP YET|NOT READ", H2):
            return True                                       # patch 231: a result WITH its numbers always reaches Telegram (IN LINE: no sound)
        return alertword.tier(text) != "read"''', "a result with its numbers always goes to Telegram")
rep("exchange.py", '''def judge(res):''', '''def plain_read(rd):
    """patch 231: the result in plain words, from the numbers (res["read"]) - what a trader would say"""
    try:
        rv, pt, mg = rd.get("rev") or [None] * 3, rd.get("pat") or [None] * 3, rd.get("margin") or [None] * 4
        ry, pc, py, bps = rv[1], pt[0], pt[1], (mg[2] if len(mg) > 2 else None)
        f = lambda x: "%+.0f%%" % x
        if pc is not None and pc < 0:
            return ("MIXED - still a loss (₹{:,.0f} cr) but sales {}".format(-pc, f(ry)) if (ry or 0) > 0 else
                    "WEAK - a loss (₹{:,.0f} cr) and sales {}".format(-pc, f(ry) if ry is not None else "not up"))
        if ry is not None and ry <= -5 and (py or 0) > 0:
            return "WEAK - sales fell %.0f%%; profit %s only because costs fell" % (abs(ry), f(py))
        if ry is not None and ry >= 15 and bps is not None and bps <= -300:
            return "MIXED - sales strong (%s) but margins squeezed (%.1f points), profit only %s" % (f(ry), bps / 100.0, f(py) if py is not None else "?")
        if py is not None and ry is not None and py >= 25 and ry >= 10:
            return "STRONG - profit %s and sales %s vs last year" % (f(py), f(ry))
        if py is not None and py <= -10:
            return "WEAK - profit down %s vs last year" % f(py)
        if py is not None and abs(py) < 5:
            return "FLAT - profit hardly changed (%s), sales %s" % (f(py), f(ry) if ry is not None else "?")
        if py is not None:
            return "STEADY - profit %s, sales %s" % (f(py), f(ry) if ry is not None else "?")
    except Exception:
        pass
    return ""


def judge(res):''', "plain_read()")
rep("exchange.py", '''    return v, (1 if v == "BEAT" else -1 if v == "MISS" else 0), line + ((" → " + why) if why else "")''',
    '''    pr_ = plain_read(res.get("read") or {})                     # patch 231: the plain read under the numbers
    return v, (1 if v == "BEAT" else -1 if v == "MISS" else 0), line + ((" → " + why) if why else "") + (("\\nplain read: " + pr_) if pr_ else "")''',
    "the plain read under every result")
rep("resultsdesk.py", '''            rows.append(one(sym, d, now, fo))''', '''            if _filed(sym, now):
                continue                                        # patch 231: its results are already out - not "coming" any more
            rows.append(one(sym, d, now, fo))''', "results already out leave the list")
rep("resultsdesk.py", '''def _fo():''', '''def _filed(sym, now):
    """patch 231: this share filed its results in the last 3 days"""
    try:
        c = _ro("filings.db")
        r = c.execute("select 1 from filings where sym=? and kind='RESULTS' and t_exch>? limit 1", (sym, now.timestamp() - 3 * 86400)).fetchone()
        c.close()
        return bool(r)
    except Exception:
        return False


def _fo():''', "_filed()")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 231 in")
PY_PATCH
cat > $W/p231test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p231test.py - every result reaches Telegram with its numbers + a plain read; tonight's 6 results (made-up files, nothing sent).
python3 p231test.py DIR   (tgquiet.py, exchange.py, resultsdesk.py, alertword.py)"""
import os, sys, shutil, sqlite3, tempfile, datetime as dt
D = os.path.abspath(sys.argv[1])
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("tgquiet.py", "exchange.py", "resultsdesk.py", "alertword.py"):
    shutil.copy(os.path.join(D, f), T)
for f in ("core.py", "getdata.py", "engine.py"):                          # the server has them; a stand-in only where they are missing (a local run)
    if os.path.exists(os.path.join(D, f)):
        shutil.copy(os.path.join(D, f), T)
    else:
        open(os.path.join(T, f), "w").write("BASE = %r\ndef __getattr__(n):\n    return lambda *a, **k: None\n" % T)
sys.path.insert(0, T); sys.path.insert(1, D); os.chdir(T)
import tgquiet as Q
OK = []
def chk(name, cond, got=""):
    OK.append(bool(cond)); print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:300]))
print("1 · the follow-up reaches Telegram")
inline = "📰 FILING · RVNL · RESULTS · IN LINE · NSE 19:49:22 (read in 120s)\nOutcome of Board Meeting\nrevenue ₹4,701 cr -8% YoY · profit ₹254 cr +10% YoY"
chk("RVNL 'RESULTS · IN LINE' with its numbers: SENT to Telegram (it went to the digest before)", Q.allow(inline))
chk("NMDC the same", Q.allow(inline.replace("RVNL", "NMDC")))
chk("'RESULTS · XBRL NOT UP YET' (the interim line): stays out, as before", not Q.allow("📰 FILING · RVNL · RESULTS · XBRL NOT UP YET · NSE 19:49:22 (read in 29s)\nOutcome of Board Meeting"))
chk("an ordinary quiet line (🔍 WHY): stays out, as before", not Q.allow("🔍 WHY ▲ BAJFINANCE +2.7% · CLEAR"))
import alertword as A
chk("IN LINE stays a quiet level - it arrives WITHOUT sound (BEAT / MISS ring as before)", A.tier(inline) == "read")
print("2 · the plain read (tonight's numbers)")
import exchange as X
R = {"MANAPPURAM": ({"rev": [3352, 47, 20], "pat": [701, 217, 20], "margin": ["pbt", 28.0, 1470, 0]}, "STRONG"),
     "OIL": ({"rev": [11915, 22, 0], "pat": [2520, 53, -37], "margin": ["ebitda", 36.6, 774, 0]}, "STRONG"),
     "POWERINDIA": ({"rev": [2997, 64, 0], "pat": [318, 20, 8], "margin": ["ebitda", 15.5, -537, 0]}, "MIXED"),
     "IDEA": ({"rev": [11884, 6, 0], "pat": [-5975, None, None], "margin": ["ebitda", 45.1, 232, 0]}, "MIXED"),
     "RVNL": ({"rev": [4701, -8, 0], "pat": [254, 10, 59], "margin": ["ebitda", 9.1, 25, 0]}, "WEAK"),
     "NMDC": ({"rev": [6638, 4, 0], "pat": [1664, -1, -17], "margin": ["ebitda", 36.7, -60, 0]}, "FLAT")}
for s, (rd, want) in R.items():
    pr = X.plain_read(rd)
    chk("%-10s -> %s" % (s, pr), pr.startswith(want), pr)
chk("missing numbers: no plain read, no crash", X.plain_read({}) == "")
print("3 · the results calendar")
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); now = dt.datetime(2026, 11, 12, 21, 0, tzinfo=IST)
c = sqlite3.connect("filings.db"); c.execute("create table filings(sym text, kind text, t_exch real)"); c.execute("insert into filings values ('RVNL', 'RESULTS', ?)", (now.timestamp() - 4000,)); c.commit(); c.close()
import resultsdesk as RD
chk("RVNL (filed tonight) is no longer 'coming'; ABB (not filed) still is", RD._filed("RVNL", now) and not RD._filed("ABB", now))
print("RESULTS FOLLOW-UP test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
python3 $W/p231_patch.py $D || back
cd $D && python3 -m py_compile tgquiet.py exchange.py resultsdesk.py || back
echo "=== test: tonight's 6 results"
python3 $W/p231test.py $D || back
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 10; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 231 done - every result now reaches Telegram with its numbers and a plain read (IN LINE without sound)."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
