#!/bin/bash
# PATCH 273 - ONE STORY, ONE MESSAGE (Rama, 14 Nov: "the same message should not be sent to me multiple times - I have seen the same messages come
#   from different sources"). GIR's readers (NSE filings, the news hunt, the newsroom, GOVT WATCH, TV watch, the business wires) each found the same
#   story and each sent it. Now every Telegram sender asks first (storydup.py): the same share's same story within 6 h (the same ₹ amount, 35%+ of the
#   words, or the same kind of news within 90 min; for market lines the same regulator) goes ONCE - the repeats stay on the page, marked 🔁.
#   Never held: trade calls (RESULTS REACTION, CONFIRMED MOVE, SPEED, P1), the cards, stops / exits, POSITION GUARD, GIR's own alarms.
#   NSE filings are the first source: always sent, and remembered. Tested: 7 + 3 cases. Restarts the senders - after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
[ -f $D/tgq.py ] && [ -f $D/opencall.py ] || { echo "GIR's tgq.py / opencall.py not found"; exit 1; }
F="tgq.py opencall.py exchange.py"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt gir-eventwatch gir-dash"
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; rm -f $D/storydup.py; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/storydup.py <<'PY_SD'
#!/usr/bin/env python3
"""storydup.py - patch 273: ONE STORY, ONE MESSAGE (Rama, 14 Nov: "the same message should not be sent to me multiple times - the same messages come
from different sources"). GIR's readers (NSE filings, the news hunt, the newsroom, GOVT WATCH, TV watch, the business wires) each found the same story
and each sent it: PAYTM's RBI wallet nod came 6+ times, IRDAI's commission story again and again.
  check(text) -> None (send it) or "HH:MM" (the same story already went at HH:MM: keep it on the page, do not send it again)
  the same story = the same share and, within 6 h: the same ₹ amount, or 35%+ of the headline's words in common, or the same kind of news
  (RESULTS / ORDER / REGULATOR / DEAL / MANAGEMENT) within 90 min · a market line: the same regulator within 6 h, or 35%+ words in common
  never held: trade calls (RESULTS REACTION, CONFIRMED MOVE, SPEED, P1), the cards, exits / stops, POSITION GUARD, GIR's own alarms
Shared by every sender (tgq.send, opencall.send_tg, exchange.send) through data/storydup.json."""
import os, re, json, time

BASE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(BASE, "data", "storydup.json")
WINDOW, KIND_S, OVERLAP = 6 * 3600, 90 * 60, 0.35
NEWS = re.compile(r"📰|📄|🏛|📑|📺|SHOCK WATCH|NEWS SHOCK|THE REASON|GOVT|REGULATOR|·\s*REG\b|MACRO|FILING|just filed|RESULTS\b|ORDER\b|TV WATCH|NEWS\b|"
                  r"BOARD|DEAL|MGMT|MANAGEMENT|RATING|SALES|BLOCK DEAL|BULK DEAL", re.I)
NEVER = re.compile(r"RESULTS REACTION|CONFIRMED MOVE|\bSPEED\b|🔴 TRADE ALERT|\bP1\b|🃏|🎫|🛑|🎯|⏰|\bEXIT\b|BOOK HALF|POSITION GUARD|LIVE FEED|SOCKET|"
                   r"CIRCUIT|NIFTY SHOCK|DAILY LOSS|MORNING BRIEF|THE WEEK|RESULTS DAY|TOMORROW|SELF-CHECK|MACRO WARNING|EVENT WATCH")
KINDS = (("RESULTS", r"result|q[1-4]\b|quarter|profit|revenue|earnings|ebitda"), ("ORDER", r"\border|contract|bags|wins|lo[ai] "),
         ("REGULATOR", r"sebi|rbi|irdai|cci|usfda|fda|regulat|penalt|show cause|notice|ban|tribunal|court|nclt"),
         ("DEAL", r"acquir|stake|merger|demerger|buyback|split|dividend|bonus|fund ?rais|qip|block deal|bulk deal"),
         ("MANAGEMENT", r"resign|appoint|ceo|md\b|cfo|chairman|director"))
REGS = ("IRDAI", "SEBI", "RBI", "CCI", "TRAI", "USFDA", "DGCA", "PIB", "CABINET", "MINISTRY", "GST COUNCIL")
SMALL = set("this that with from into over after says said will have been their about more than also amid shares share stock stocks india indian "
            "company limited ltd crore lakh today news report reports update updates check here what know".split())


def _load():
    try:
        return json.load(open(STATE))
    except Exception:
        return []


def _save(v):
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        json.dump(v, open(STATE + ".tmp", "w")); os.replace(STATE + ".tmp", STATE)
    except Exception:
        pass


def parts(text):
    """-> (sym or 'MARKET', words, amounts, kind, regulator) or None when this is not a news line"""
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return None
    h = L[0][len("🔔 OPENING · "):] if L[0].startswith("🔔 OPENING · ") else L[0]
    if NEVER.search(text) or not NEWS.search(h):
        return None
    m = re.search(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b", h) or re.search(r"·\s*([A-Z][A-Z0-9&\-]{2,19})\s*·", h) or re.search(r"^\S+\s+[A-Z ]*?\b([A-Z][A-Z0-9&\-]{2,19})\s*·", h)
    sym = m.group(1) if m and not re.search(r"GOVT|MACRO|MARKET NEWS", h) else "MARKET"     # a government / market line is the market's story
    if sym in ("NEWS", "GOVT", "WATCH", "REGULATOR", "RESULTS", "ORDER", "CRITICAL", "MARKET", "SHOCK", "REASON", "THE", "REG", "DEAL", "IRDAI", "SEBI", "RBI", "PIB", "POLICY", "TV", "CABINET", "MINISTRY"):
        sym = "MARKET"
    body = " ".join(x for x in L[1:4] if not re.match(r"(🟠|🔴|📌|🔕|⚙️|🔎|⚖|touches:|F&O shares|https?://)", x.strip())) or h
    body = re.sub(r"\s+[-|–]\s+[^-|–]{2,60}$", "", body)                  # " - The Hindu"
    t = (h + " " + body).lower()
    words = sorted({w for w in re.findall(r"[a-z][a-z0-9]{3,}", body.lower()) if w not in SMALL})
    amts = sorted({a.replace(",", "") for a in re.findall(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)\s*(?:cr|crore|lakh|bn|billion)", t)})
    kind = next((k for k, rx in KINDS if re.search(rx, t)), "")
    reg = next((r for r in REGS if re.search(r"\b%s\b" % r, (h + " " + body).upper())), "")
    return sym, words, amts, kind, reg


def same(a, b):
    """a, b: stored parts (+ 't') - the same story?"""
    if a["sym"] != b["sym"]:
        return False
    wa, wb = set(a["w"]), set(b["w"])
    ov = len(wa & wb) / max(1, min(len(wa), len(wb)))
    if a["sym"] == "MARKET":
        return bool(a["reg"] and a["reg"] == b["reg"]) or ov >= OVERLAP
    if set(a["a"]) & set(b["a"]):
        return True
    if ov >= OVERLAP and len(wa & wb) >= 2:
        return True
    return bool(a["k"] and a["k"] == b["k"] and abs(a["t"] - b["t"]) < KIND_S)


def check(text, now=None, remember=True):
    """-> None: send it (and it is remembered) · 'HH:MM': the same story already went then - do not send"""
    p = parts(text)
    if not p:
        return None
    now = now or time.time()
    sym, w, a, k, reg = p
    me = {"t": now, "sym": sym, "w": w, "a": a, "k": k, "reg": reg, "hm": time.strftime("%H:%M", time.gmtime(now + 19800))}      # IST
    S = [x for x in _load() if now - x.get("t", 0) < WINDOW]
    for x in S:
        if 0 <= now - x["t"] < WINDOW and same(me, x):
            return x.get("hm") or "earlier"
    if remember:
        S.append(me); _save(S[-400:])
    return None


def note(text, hm):
    return text.rstrip() + "\n🔁 the same story already went at %s - kept on the page, not sent again" % hm
PY_SD
cat > $W/p273_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p273_patch.py - patch 273: every Telegram sender asks storydup.check() first - one story, one message.  python3 p273_patch.py DIR"""
import os, sys
D = sys.argv[1]
MAIN = 'if __name__ == "__main__":'
TGQ = '''

_send273 = send                                                    # patch 273: one story, one message - a repeat stays on the page only


def send(tok, chat, text, on_ok=None, on_fail=None, silent=False):
    try:
        import storydup
        hm = storydup.check(text)
    except Exception:
        hm = None
    if hm:
        if on_ok:
            try:
                on_ok(storydup.note(text, hm))
            except Exception:
                pass
        return True
    return _send273(tok, chat, text, on_ok=on_ok, on_fail=on_fail, silent=silent)
'''
OC = '''_send_tg273 = send_tg                                              # patch 273: one story, one message


def send_tg(text):
    try:
        import storydup
        hm = storydup.check(text)
    except Exception:
        hm = None
    if hm:
        try:
            log_alert(storydup.note(text, hm))
        except Exception:
            pass
        return True
    return _send_tg273(text)


''' + MAIN
EX = '''_send273 = send                                                    # patch 273: an NSE filing is the first source - always sent, and remembered


def send(text):
    try:
        import storydup
        storydup.check(text)
    except Exception:
        pass
    return _send273(text)


''' + MAIN
for f, mode, add, must in (("tgq.py", "end", TGQ, True), ("opencall.py", "main", OC, True), ("exchange.py", "main", EX, False)):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        if must:
            print("❌ %s missing" % f); sys.exit(1)
        print("  %s: not on this server - skipped" % f); continue
    s = open(p, encoding="utf-8").read()
    if "patch 273" in s:
        print("  %s: patch 273 - already in" % f); continue
    if mode == "end":
        if "\ndef send(" not in s:
            print("❌ %s: send() not found" % f); sys.exit(1)
        s = s.rstrip("\n") + add
    else:
        if s.count(MAIN) != 1 or ("\ndef send_tg(" not in s if f == "opencall.py" else "\ndef send(" not in s):
            if must:
                print("❌ %s: anchor not found" % f); sys.exit(1)
            print("  %s: its layout is different - skipped (its filings are not remembered, nothing else changes)" % f); continue
        s = s.replace(MAIN, add)
    open(p, "w", encoding="utf-8").write(s)
    print("  %s: %s" % (f, {"tgq.py": "the one sender queue checks every message - a repeat story stays on the page only",
                            "opencall.py": "the direct sender (confirmed move, govt watch, briefs) checks too",
                            "exchange.py": "NSE filings: always sent, remembered - the news readers' copies of them are not sent again"}[f]))
print("patch 273 in")
PY_PATCH
cat > $W/p273test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p273test.py - one story, one message (made-up messages, temp folder, nothing sent).  python3 p273test.py DIR"""
import os, sys, shutil, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "storydup.py"), T)
sys.path.insert(0, T); os.chdir(T)
import storydup as SD
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
t0 = dt.datetime(2026, 11, 13, 18, 30, tzinfo=IST).timestamp()
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
PAY = ["⚠️ SHOCK WATCH ▲ PAYTM · REGULATOR · RBI\nPaytm gets RBI's in-principle nod to revive wallet business; shares hit record high - The Hindu",
       "📰 NEWS ▲ PAYTM · REG · Economic Times 18:40\nPaytm gets preliminary RBI approval to bring its wallet back - Economic Times",
       "🚨 THE REASON ▲ PAYTM · 18:50\nRBI gives in-principle approval for Paytm wallet licence",
       "📰 NEWS ▲ PAYTM · REG · Mint 19:05\nPaytm Prepaid Wallets Win RBI Nod, But Final Approval Still Pending - Mint"]
r = [SD.check(x, t0 + 600 * i) for i, x in enumerate(PAY)]
chk("PAYTM's RBI wallet nod from 4 readers / sites: the first is sent, the 3 others not ('already went at 18:30')", r[0] is None and r[1:] == ["18:30"] * 3, r)
IR = ["🚨 CRITICAL GOVT · IRDAI · 15:30\nIRDAI may modify draft distribution paper, reports CNBC-TV18 - CNBC TV18",
      "🏛 GOVT WATCH · IRDAI · 16:10\nIRDAI To Modify Insurance Distribution Norms After Industry Feedback - Moneycontrol",
      "🚨 CRITICAL GOVT · POLICY · 18:08\nTurtlemint flags lower income for agents under IRDAI proposed commission curbs - Business Standard"]
t1 = dt.datetime(2026, 11, 13, 15, 30, tzinfo=IST).timestamp()
r = [SD.check(x, t1 + 2400 * i) for i, x in enumerate(IR)]
chk("IRDAI's story from GOVT WATCH, the news sites, the policy feed: sent once", r[0] is None and r[1] and r[2], r)
chk("a different share's news is sent (LICI after PAYTM)", SD.check("📰 NEWS ▲ LICI · DEAL · ET 19:10\nLIC raises stake in a health insurer - Economic Times", t0 + 2400) is None)
chk("the same share, a DIFFERENT story is sent (PAYTM results after the RBI nod)", SD.check("📰 NEWS ▲ PAYTM · RESULTS · ET\nPaytm Q2 loss narrows to Rs 120 crore, revenue up 30%", t0 + 3000) is None)
O = ["📄 ORDER ▲ BEL · NSE 18:31\nBharat Electronics receives orders worth Rs 619 crore", "📰 NEWS ▲ BEL · ORDER · Moneycontrol\nBEL bags Rs 619 crore defence contracts - Moneycontrol"]
chk("an NSE order filing then the news site's report of it (same ₹619 cr): sent once", SD.check(O[0], t0) is None and SD.check(O[1], t0 + 900))
NEVER = ["🚨 CRITICAL · RESULTS REACTION ▲ PAYTM · 09:22\n▶ BUY CE", "✅ CONFIRMED MOVE ▲ PAYTM · CE · 09:34", "⚡ SPEED ▲ PAYTM ₹1,200 +1.3% in 5 min",
         "🛑 🛡 POSITION GUARD · STOP · 10:00\nPAYTM26NOV1200CE", "🔴 TRADE ALERT ▲ PAYTM P1 · BUY CE"]
chk("trade calls, the cards, stops, POSITION GUARD are never held - even right after PAYTM's news", all(SD.check(x, t0 + 1200) is None for x in NEVER))
chk("7 hours later the same story may come again (a new day's follow-up)", SD.check(PAY[1], t0 + 7 * 3600) is None)
print("ONE STORY ONE MESSAGE test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p273int.py <<'PY_INT'
#!/usr/bin/env python3
"""p273int.py - one story, one message through GIR's own senders (temp copies; Telegram is replaced, nothing sent).  python3 p273int.py DIR"""
import os, sys, shutil, tempfile
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
for f in ("storydup.py", "tgq.py", "opencall.py"):
    shutil.copy(os.path.join(SRC, f), T)
sys.path.insert(0, T); sys.path.append(SRC); os.chdir(T)
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:300]))
import tgq
Q, P = [], []
tgq._send273 = lambda tok, chat, text, on_ok=None, on_fail=None, silent=False: Q.append(text) or True
A = "⚠️ SHOCK WATCH ▲ PAYTM · REGULATOR · RBI\nPaytm gets RBI's in-principle nod to revive wallet business - The Hindu"
B = "📰 NEWS ▲ PAYTM · REG · Economic Times 18:40\nPaytm gets preliminary RBI approval to bring its wallet back - Economic Times"
tgq.send("tok", "chat", A, on_ok=P.append); tgq.send("tok", "chat", B, on_ok=P.append)
chk("the sender queue: the first PAYTM story goes to Telegram, the repeat does not - it reaches the page marked 🔁", len(Q) == 1 and Q[0] == A and len(P) == 1 and "🔁 the same story already went" in P[0], (Q, P))
tgq.send("tok", "chat", "✅ CONFIRMED MOVE ▲ PAYTM · CE · 09:34", on_ok=P.append)
chk("... a trade call on PAYTM right after: sent", len(Q) == 2)
try:
    import opencall
    S_, L_ = [], []
    opencall._send_tg273 = lambda text: S_.append(text) or True
    opencall.log_alert = lambda text: L_.append(text)
    opencall.send_tg("🏛 GOVT WATCH · IRDAI · 16:10\nIRDAI To Modify Insurance Distribution Norms After Industry Feedback - Moneycontrol")
    opencall.send_tg("🚨 CRITICAL GOVT · IRDAI · 18:00\nIRDAI may roll out insurance commission caps from January - Economic Times")
    chk("the direct sender: IRDAI's story once; the repeat goes to the page only", len(S_) == 1 and len(L_) == 1 and "🔁" in L_[0], (S_, L_))
except Exception as ex:
    chk("opencall loads", False, ex)
print("ONE STORY IN GIR'S SENDERS test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_INT
python3 $W/p273_patch.py $D || back
cd $D && python3 -m py_compile storydup.py tgq.py opencall.py exchange.py || back
echo "=== test"
python3 $W/p273test.py $D > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
python3 $W/p273int.py $D > $W/t2.out 2>&1; RC=$?; cat $W/t2.out; [ $RC -eq 0 ] || back
chown --reference=$D $D/storydup.py 2>/dev/null
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "✅ patch 273 done - one story, one message: a repeat from another reader or website stays on the page (🔁), never a second Telegram message."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
