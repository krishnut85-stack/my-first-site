#!/bin/bash
# PATCH 381 - THE NEWS DIRECTION: THE AI'S READING COUNTS, AND NOTHING IS MUTED AS "ALREADY KNOWN" (Rama, 17 Nov, LAURUSLABS: "Promoter rules
#   out further stake sale" came at 12:26 (Moneycontrol) and 12:42 (CNBC); GIR filed it as a BLOCK deal with direction 0 / DOWN; the AI read
#   BULLISH at 12:47 but nothing took its word; the 12:26 story never reached you). From GIR's own code (the files sent 17 Nov 18:30):
#   1 newsroom.news_side reads headline WORDS: "stake sale" counts as selling even after "rules out" / "no further plans". Now a sale, a
#     pledge or a share issue that is ruled out, denied, called off or locked in reads UP.
#   2 newsalert: the AI's reading of the full story went into the alert text only - news.db kept the word direction, and the page, the
#     share note, WHY NOW (callwhy) and the engine's "driving it" all read news.db. Now the AI's reading is written back to every copy of
#     that story (the same story from any source, 36 hours) - BULLISH / BEARISH / NEUTRAL replaces the word direction, and the alert says
#     when it corrected the words ("🔁 the headline words read DOWN - the full story reads UP: this reading counts").
#   3 newsalert: an item the AI marked "already in the price" was dropped (patch 138c), even a fresh critical one ("shares rise 3.5% as
#     promoter says no further plans for stake sale" - the move was the news). Now a fresh (since the last close) critical / important
#     item is still sent, QUIETLY (📄, no ring), saying "the reader thinks this is already in the price - information, not a call".
#     Nothing muted without Rama's word.
#   Edits newsroom.py and newsalert.py (exact lines from the server's own copies), checks them on the Laurus headlines, restarts the news
#   services (and the engine, which imports them). Run after 15:35.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 381" $D/newsroom.py && grep -q "patch 381" $D/newsalert.py; then echo "patch 381 - already in"; exit 0; fi
F="newsroom.py newsalert.py"
for f in $F; do [ -f $D/$f ] || { echo "$f not found - nothing done"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; for s in $RS; do systemctl restart $s 2>/dev/null; done; echo "❌ old files put back - nothing changed"; exit 1; }
RS=""
python3 - $D <<'PY_EDIT' || back
import os, sys
D = sys.argv[1]; ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if s.count(old) != 1:
        ERR.append("%s: the line for '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new, 1)); print("  %s: %s" % (f, tag))


# 1 newsroom: a sale / pledge / share issue that is ruled out reads UP
rep("newsroom.py", '''def news_side(h, exch_side=None):
    import verdict
    if exch_side:
        return int(exch_side)
''', '''SELL_W = r"(?:stake|sale|sell\\w*|offload\\w*|pledge\\w*|ofs|offer for sale|dilut\\w*|qip|block deal|bulk deal)"      # patch 381
NEG_SELL = re.compile(r"\\b(?:(?:rules? out|ruled out|no (?:further |more |immediate )?(?:plans?|intention|proposal)s? (?:for|to|of)|den(?:y|ies|ied)|"
                      r"not (?:to |planning to |looking to )?sell|won'?t sell|will not sell|has no plans?|calls? off|called off|scraps?|withdraws?|"
                      r"puts? on hold)(?:\\W+\\w+){0,4}?\\W+" + SELL_W + r"|extends? (?:the )?lock-?in|lock-?in (?:is )?extended|releases? (?:the )?pledge|"
                      r"pledge (?:released|revoked|cut|reduced))\\b", re.I)
SELL_CTX = re.compile(r"\\b" + SELL_W + r"\\b", re.I)


def news_side(h, exch_side=None):
    import verdict
    if exch_side:
        return int(exch_side)
    if NEG_SELL.search(h or ""):                                # patch 381: "promoter rules out further stake sale" - the selling is OFF: UP
        return 1
''', "a sale / pledge that is ruled out reads UP")

# 2 newsalert: the AI's reading is written back to news.db; the alert says when it corrected the words
rep("newsalert.py", '''def story(sym, h, link="", src="", kind="", t=None, word="NEWS", also=(), extra=(), name="", sync=False):''',
'''def remember(sym, h, r, t=None):
    """patch 381: the AI's reading of the full story becomes the direction of every copy of that story in news.db (36 hours, any source) -
    the page, the share note, WHY NOW and the engine's "driving it" read news.db, which kept the headline-word direction (LAURUSLABS 17 Nov).
    Returns the word directions it replaced (non-zero and different)."""
    try:
        import newsroom
        side = int(r.get("side") or 0)
        tag = "AI read: %s" % ("BULLISH" if side > 0 else "BEARISH" if side < 0 else "NEUTRAL")
        try:                                                    # the company's own name words do not make two headlines the same story
            if time.time() - _NM211["t"] > 3600:
                _NM211["v"] = {s_: n_ for s_, n_, l_ in newsroom.fo_names()}; _NM211["t"] = time.time()
        except Exception:
            pass
        nm = newsroom.words("%s %s ltd limited india" % (sym, _NM211["v"].get(sym) or ""))
        mine = newsroom.words(h) - nm
        con = newsroom.db(); now = time.time(); changed = []
        for key, hh, s0, note in con.execute("select key, h, side, note from items where sym=? and t_pub>?", (sym, (t or now) - 36 * 3600)).fetchall():
            o = newsroom.words(hh) - nm; both = mine & o
            if hh == h or (len(both) >= 2 and mine and o and len(both) / min(len(mine), len(o)) >= 0.5):
                note2 = re.sub(r"AI read: [A-Z]+", tag, note) if "AI read: " in (note or "") else ((note or "") + " · " + tag)
                if s0 and int(s0) != side:
                    changed.append(int(s0))
                con.execute("update items set side=?, note=? where sym=? and key=?", (side, note2, sym, key))
        con.commit(); con.close()
        return changed
    except Exception as ex:
        print("news reader remember %s: %s" % (sym, str(ex)[:80]), flush=True)
        return []


def fresh_since_close(t=None):
    """patch 381: published after the last market close (15:30 of the last weekday)"""
    now = dt.datetime.now(IST); c = now.replace(hour=15, minute=30, second=0, microsecond=0)
    if now < c:
        c -= dt.timedelta(days=1)
    while c.weekday() > 4:
        c -= dt.timedelta(days=1)
    return (t or time.time()) >= c.timestamp()


def story(sym, h, link="", src="", kind="", t=None, word="NEWS", also=(), extra=(), name="", sync=False):''', "the AI's reading written back to news.db")

# 3 newsalert: use it in story(); "already in the price" is sent quietly, not dropped
rep("newsalert.py", '''        r = dict(r, full=bool(body))
        if not decide(r):
            return None
        txt = compose(r, word, sym, kind or "NEWS", src, hm, h, (["also names: " + ", ".join(also)] if also else []) + list(extra), link)''',
'''        r = dict(r, full=bool(body))
        fix = []
        if not r.get("quick"):                                  # patch 381: the AI's reading is the direction everywhere
            was = remember(sym, h, r, t)
            if was and r["side"] != 0:
                fix = ["🔁 the headline words read %s - the full story reads %s: this reading counts" % ("UP" if was[0] > 0 else "DOWN", "UP" if r["side"] > 0 else "DOWN")]
        if not decide(r):
            if not (r.get("relevant") and r.get("known") and not r.get("quick") and r.get("level") in ("critical", "important") and fresh_since_close(t)):
                return None
            fix.append("ⓘ the reader thinks this is already in the price - sent as information (quiet), not a call")   # patch 381: not dropped
            r = dict(r, level="minor")
        txt = compose(r, word, sym, kind or "NEWS", src, hm, h, (["also names: " + ", ".join(also)] if also else []) + list(extra) + fix, link)''',
"'already in the price': sent quietly, not dropped")

if ERR:
    print("❌ " + "\\n❌ ".join(ERR)); sys.exit(1)
PY_EDIT
cd $D && python3 -m py_compile newsroom.py newsalert.py || back
grep -q "^import os, re, sys, json, time, threading, datetime as dt" $D/newsalert.py || { echo "❌ newsalert.py does not import re / time / dt as expected"; back; }
cd $D && python3 - <<'PY_TEST' || back
import os, sys, time, tempfile, sqlite3
sys.path.insert(0, os.getcwd())
import newsroom, newsalert
OK = []
def chk(n, c):
    OK.append(bool(c)); print("  %s %s" % ("✓" if c else "✗", n))
S = newsroom.news_side
chk("'Laurus Labs gains – Promoter rules out further stake sale' reads UP", S("Laurus Labs gains – Promoter rules out further stake sale") == 1)
chk("'Laurus Labs shares rise 3.5% as promoter says no further plans for stake sale' reads UP", S("Laurus Labs shares rise 3.5% as promoter says no further plans for stake sale") == 1)
chk("'promoter denies plan to sell stake' reads UP", S("XYZ promoter denies plan to sell stake") == 1)
chk("'promoter sells 2% stake via block deal' does not read UP", S("XYZ promoter sells 2% stake via block deal") != 1)
chk("'company rules out dividend this year' is left to the old word reader (no sale in it)", not newsroom.SELL_CTX.search("XYZ rules out dividend this year"))
chk("'exchange halts trading after promoter stake sale' is left to the old word reader", not newsroom.NEG_SELL.search("Exchange halts trading in XYZ after promoter stake sale"))
chk("'promoter calls off OFS' and 'lock-in extended' read UP", S("XYZ promoter calls off OFS") == 1 and S("XYZ promoters' lock-in extended by a year") == 1)
T = tempfile.mkdtemp(); newsroom.DB = os.path.join(T, "news.db")
newsalert._NM211.update({"t": time.time(), "v": {"LAURUSLABS": "Laurus Labs Limited"}})
c = newsroom.db(); now = time.time()
for key, h, side, dom in (("k1", "Laurus Labs shares rise 3.5% as promoter says no further plans for stake sale", 0, "moneycontrol.com"),
                          ("k2", "Laurus Labs gains – Promoter rules out further stake sale", -1, "cnbctv18.com"),
                          ("k3", "Laurus Labs Q2 profit up 40%", 1, "livemint.com"),
                          ("k4", "Laurus Labs promoter pledges more shares", -1, "zeebiz.com")):
    c.execute("insert into items values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (key, "LAURUSLABS", "GOOGLE NEWS", dom, 70, now - 600, now, h, "", side, "BLOCK", 0, 1, 52, "major wire"))
c.commit(); c.close()
was = newsalert.remember("LAURUSLABS", "Laurus Labs gains – Promoter rules out further stake sale", {"side": 1}, now)
c = sqlite3.connect(newsroom.DB); R = dict((k, (s, n)) for k, s, n in c.execute("select key, side, note from items")); c.close()
chk("the AI's BULLISH written to both copies of the story", R["k1"][0] == 1 and R["k2"][0] == 1 and "AI read: BULLISH" in R["k2"][1])
chk("other stories of the same share are left alone (results; a pledge story sharing one word)", R["k3"][0] == 1 and "AI read" not in R["k3"][1] and R["k4"][0] == -1 and "AI read" not in R["k4"][1])
chk("it reports the word direction it corrected (DOWN)", was == [-1])
newsalert.remember("LAURUSLABS", "Laurus Labs gains – Promoter rules out further stake sale", {"side": -1}, now)
c = sqlite3.connect(newsroom.DB); n2 = c.execute("select note from items where key='k2'").fetchone()[0]; c.close()
chk("a second reading replaces the first tag, not added twice", n2.count("AI read:") == 1 and "AI read: BEARISH" in n2)
chk("fresh_since_close: now is fresh, 4 days ago is not", newsalert.fresh_since_close(time.time()) and not newsalert.fresh_since_close(time.time() - 4 * 86400))
# the quiet send of an 'already in the price' item
sent = []; newsalert.SEND = sent.append
newsalert.recently_sent = lambda s, h, hours=6: False
newsalert.about_it = lambda *a, **k: True
newsalert.model_read = lambda *a, **k: {"relevant": True, "side": 1, "level": "important", "known": True, "conf": 0.8, "reason": "promoter overhang removed", "watch": "", "model": "test"}
import newsbody, newsfresh
newsbody.get = lambda link: ""; newsfresh.check = lambda *a, **k: (True, "")
out = newsalert.story("LAURUSLABS", "Laurus Labs gains – Promoter rules out further stake sale", "", "cnbctv18.com", "BLOCK", time.time(), sync=True)
chk("an 'already in the price' important item is SENT, quietly (📄), saying so", bool(out) and out.startswith("📄") and "already in the price" in out and sent)
newsalert.model_read = lambda *a, **k: {"relevant": True, "side": 1, "level": "important", "known": True, "conf": 0.8, "reason": "x", "watch": "", "model": "test"}
out2 = newsalert.story("LAURUSLABS", "Laurus Labs old story", "", "cnbctv18.com", "BLOCK", time.time() - 5 * 86400, sync=True)
chk("an old (before the last close) 'already known' item is still not sent", out2 is None)
newsalert.model_read = lambda *a, **k: {"relevant": True, "side": 1, "level": "critical", "known": False, "conf": 0.9, "reason": "x", "watch": "", "model": "test"}
out3 = newsalert.story("LAURUSLABS", "Laurus Labs gains – Promoter rules out further stake sale", "", "cnbctv18.com", "BLOCK", time.time(), sync=True)
chk("a new critical item still rings as 🚨 CRITICAL", bool(out3) and out3.startswith("🚨"))
print("  %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
for s in gir-newsroom gir-newshunt gir-intraday; do systemctl is-active --quiet $s && RS="$RS $s"; done
for s in $RS; do systemctl restart $s; done; sleep 8
for s in $RS; do echo "  $s: $(systemctl is-active $s)"; [ "$(systemctl is-active $s)" = "active" ] || back; done
echo "✅ patch 381 done - a story's direction is now the AI's reading of the full story (written back to every copy of it), a ruled-out sale"
echo "   reads UP, and a fresh important story the reader thinks is 'already in the price' comes quietly (📄) instead of never."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart$RS"
