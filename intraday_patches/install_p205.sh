#!/bin/bash
# PATCH 205 - ALARM MANAGEMENT (Rama: "removing alerts is not alert management"): NOTHING is dropped any more.
#   P1 🔴 ACT NOW (GO, ENTER NOW, opening call, your stop): Trade Now, loud · the page: stays until ✓ SEEN, the tab title counts them
#   P2 🟠 IMPORTANT (critical news, regulator, shock, results, 🟠 OI): rings at once · the page: pop-up
#   P3 🟡 INFO (OI readings, runs, speed, ordinary news, filings): ONE quiet 🟡 DIGEST a channel every 15 min (hourly outside market
#      hours), grouped by share - what patch 192 dropped now arrives, sorted · SYSTEM: at once. Restarts the senders.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
[ -f $D/tgquiet.py ] || { echo "patch 192 is not in - run install_p192.sh first"; exit 1; }
FILES="tgquiet.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/digest.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/digest.py <<'PY_D'
#!/usr/bin/env python3
"""digest.py - patch 205: ALARM MANAGEMENT, the P3 level (Rama, 11 Nov: "alarm management is how efficiently you handle alerts to reach
the user - removing alerts is not alert management"). Patch 192 dropped the quiet alerts from Telegram; now NOTHING is dropped:
  P1 🔴 ACT NOW    (GO, ENTER NOW, the opening call, your stop)                    Trade Now, loud, at once  · the page: stays until ✓
  P2 🟠 IMPORTANT  (critical news, regulator, shock, results, 🟠 OI)              rings, at once            · the page: pop-up
  P3 🟡 INFO       (OI readings, runs, speed, ordinary news, filings ...)         ONE quiet 🟡 DIGEST a channel every 15 min in market
                                                                                  hours (hourly outside), grouped by share
  SYSTEM ⚙️        (data check, audits, service down, AI credit)                  at once
Every P3 line the sender holds back goes to data/digest_spool.jsonl (and data/quiet/<day>.log); this program (gir-digest, every 15 min)
sends each channel its digest - the share, how many, what - the full text stays on GIR.
  python3 digest.py            send what is due        python3 digest.py --show     print it, send nothing"""
import os, re, sys, json, time, fcntl, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
SPOOL = os.path.join(BASE, "data", "digest_spool.jsonl")
OUT_HOURS_WAIT = 3600
SYM_RX = re.compile(r"[▲▼]\s*([A-Z][A-Z0-9&-]{1,}(?:-[A-Z]+)?)\b")
WORDS = {"CE", "PE", "BUY", "SELL", "WATCH", "UP", "DOWN", "NOW", "NEWS", "OI", "NSE", "BSE", "RUNNING", "SPEED", "FILING", "RESULTS", "ORDER",
         "REG", "MGMT", "BOARD", "SALES", "RATING", "GAP", "THE", "CALLS", "PUTS", "BOUGHT", "LONG", "SHORT", "SCENARIOS", "MOVE", "FIRST", "MARKET"}


def spool(chat, text, now=None):
    """the sender's hand-off (tgquiet.keep): one line per held-back alert"""
    try:
        os.makedirs(os.path.dirname(SPOOL), exist_ok=True)
        with open(SPOOL, "a", encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            f.write(json.dumps({"t": now or time.time(), "chat": str(chat), "text": (text or "")[:1500]}, ensure_ascii=False) + "\n")
            fcntl.flock(f, fcntl.LOCK_UN)
    except Exception:
        pass


def take():
    """-> every spooled line, the spool emptied (under the lock)"""
    if not os.path.exists(SPOOL):
        return []
    out = []
    with open(SPOOL, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        for line in f:
            try:
                out.append(json.loads(line))
            except Exception:
                pass
        f.seek(0); f.truncate()
        fcntl.flock(f, fcntl.LOCK_UN)
    return out


def put_back(items):
    for x in items:
        spool(x["chat"], x["text"], x["t"])


def sym_of(head):
    m = SYM_RX.search(head)
    if m and m.group(1) not in WORDS:
        return m.group(1)
    for t in re.findall(r"\b[A-Z][A-Z0-9&-]{2,}\b", head):
        if t not in WORDS:
            return t
    return ""


def heads(text):
    L = [x.strip() for x in (text or "").split("\n") if x.strip()]
    if not L:
        return []
    if L[0].startswith("🧩 OI SCENARIOS") or L[0].startswith("📈"):      # an old digest of its own: its lines
        return L[1:]
    return [L[0]]


def build(items, now=None):
    """-> [(chat, text)] one digest a channel (split at 3,800 characters)"""
    now = now or dt.datetime.now(IST)
    by_chat = {}
    for x in sorted(items, key=lambda x: x["t"]):
        by_chat.setdefault(x["chat"], []).append(x)
    out = []
    for chat, xs in by_chat.items():
        t0 = dt.datetime.fromtimestamp(xs[0]["t"], IST).strftime("%H:%M")
        groups, order = {}, []
        n = 0
        for x in xs:
            for h in heads(x["text"]):
                n += 1
                s = sym_of(h) or "·"
                if s not in groups:
                    groups[s] = []; order.append(s)
                g_ = re.sub(r"\s+", " ", h.replace(s, "", 1) if s != "·" else h)
                groups[s].append(re.sub(r"(?:·\s*){2,}", "· ", g_)[:80].strip(" ·"))
        order.sort(key=lambda s: (-len(groups[s]), s == "·"))
        lines = []
        for s in order:
            g = groups[s]
            if s == "·":
                lines += ["· " + h for h in g[:6]] + (["· … %d more" % (len(g) - 6)] if len(g) > 6 else [])
            else:
                lines.append("%s%s: %s" % (s, (" ×%d" % len(g)) if len(g) > 1 else "", " · ".join(dict.fromkeys(g[:3]))) + (" · …" if len(g) > 3 else ""))
        head = "🟡 DIGEST · %s–%s · %d quiet alert%s (P3) · the full text is on GIR" % (t0, now.strftime("%H:%M"), n, "" if n == 1 else "s")
        part, size = [head], len(head)
        for l in lines:
            if size + len(l) + 1 > 3800:
                out.append((chat, "\n".join(part))); part, size = [head + " (continued)"], len(head) + 12
            part.append(l); size += len(l) + 1
        out.append((chat, "\n".join(part)))
    return out


def market_hours(now):
    try:
        import holidays
        if holidays.holiday(now.date()):
            return False
    except Exception:
        if now.weekday() >= 5:
            return False
    return "09:15" <= now.strftime("%H:%M") <= "15:45"


def run(send=None, now=None, show=False):
    now = now or dt.datetime.now(IST)
    items = take()
    if not items:
        print("nothing held back"); return []
    if not market_hours(now) and time.time() - min(x["t"] for x in items) < OUT_HOURS_WAIT and not show:
        put_back(items); print("outside market hours - hourly"); return []
    msgs = build(items, now)
    if show:
        put_back(items)
        for c, t in msgs:
            print("[%s]\n%s\n" % (c[-6:], t))
        return msgs
    if send is None:
        import tgq
        tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
        if not tok:
            put_back(items); print("no Telegram token"); return []
        send = lambda chat, text: tgq.send(tok, chat, text, silent=True)
    try:
        for c, t in msgs:
            send(c, t)
        try:
            import tgq
            tgq.flush(30)
        except Exception:
            pass
    except Exception as ex:
        put_back(items); print("digest not sent: %s" % ex)
        return []
    print("%d digest(s) · %d alerts" % (len(msgs), len(items)))
    return msgs


if __name__ == "__main__":
    run(show="--show" in sys.argv)
PY_D
cat > $W/p205_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p205_patch.py - PATCH 205: ALARM MANAGEMENT - nothing dropped: P3 lines go to the 15-min 🟡 DIGEST (tgquiet -> digest.spool) ·
the page: P1 (ACT NOW) stays on screen until ✓ SEEN, the tab title counts the unseen ones, every chip says P1 / P2 / P3.
Usage: python3 p205_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("tgquiet.py", '''    """the line that did not go to Telegram -> data/quiet/<day>.log (14 days kept)"""
    try:''', '''    """the line that did not go to Telegram -> data/quiet/<day>.log (14 days kept)"""
    try:                                                      # patch 205: P3 - into the 15-min 🟡 DIGEST (nothing is dropped)
        import digest
        digest.spool(chat, text)
    except Exception:
        pass
    try:''', "P3 lines go to the 15-min digest")
rep("tgquiet.py", '''SYS_RE = re.compile(r"^(📋 (DATA CHECK|NSE AUDIT|GIR FULL AUDIT)|''', '''SYS_RE = re.compile(r"^(🟡 DIGEST|📋 (DATA CHECK|NSE AUDIT|GIR FULL AUDIT|GO SCORECARD)|''', "the digest and the scorecard pass")
rep("home.html", '''<span class="tg2">${tr==="act"?"TRADE ALERT":"SOMETHING IS HAPPENING"}</span>''',
    '''<span class="tg2">${tr==="act"?"🔴 P1 · ACT NOW":"🟠 P2 · IMPORTANT"}</span>''', "the pop-up says P1 / P2")
rep("home.html", '''<span class="tx" title="close">✕</span></div><div><b>${esc(r.head||"")}</b></div>''',
    '''<span class="tx" title="${tr==="act"?"seen - remove it":"close"}">${tr==="act"?"✓ SEEN":"✕"}</span></div><div><b>${esc(r.head||"")}</b></div>''', "P1: a ✓ SEEN button")
rep("home.html", '''  el.onclick=e=>{ if(e.target.classList.contains("tx")){ el.remove(); return; } el.remove(); focusOn(r.s||"MARKET"); };
  box.prepend(el); while(box.children.length>4) box.lastChild.remove();''',
    '''  el.onclick=e=>{ if(e.target.classList.contains("tx")){ el.remove(); p1Title(); return; } el.remove(); p1Title(); focusOn(r.s||"MARKET"); };
  box.prepend(el); while(box.children.length>4){ const lc=[...box.children].reverse().find(c=>!c.classList.contains("act")); if(!lc) break; lc.remove(); }   /* patch 205: a P1 is never pushed out */
  p1Title();''', "P1 is never pushed out by others")
rep("home.html", '''  setTimeout(()=>{ try{ el.remove(); }catch(e){} }, tr==="act"?60000:(ph?12000:25000)); }''',
    '''  if(tr!=="act") setTimeout(()=>{ try{ el.remove(); }catch(e){} }, ph?12000:25000); }   /* patch 205: a P1 stays until ✓ SEEN */
function p1Title(){ const n=document.querySelectorAll("#toasts .ta.act").length; document.title=(n?"("+n+") ":"")+document.title.replace(/^\\(\\d+\\) /,""); }''', "P1 stays until seen; the title counts them")
rep("home.html", '''${x.tier==="act"?"ACT":x.tier==="move"?(alertLane(r)==="critical"?"CRITICAL":"MOVING"):"INFO"}''',
    '''${x.tier==="act"?"P1 ACT":x.tier==="move"?(alertLane(r)==="critical"?"P2 CRITICAL":"P2 IMPORTANT"):"P3 INFO"}''', "the chips say P1 / P2 / P3")
if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 205 written")
PY_PATCH
cat > $D/p205test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p205test.py - PATCH 205: nothing dropped - P3 into the 15-min digest, grouped by share (a stand-in for Telegram - nothing sent)"""
import os, sys, shutil, tempfile, time, datetime as dt
B = os.path.dirname(os.path.abspath(__file__))
W = tempfile.mkdtemp()
for f in ("tgq.py", "tgquiet.py", "alertword.py", "digest.py"):
    shutil.copy(os.path.join(B, f), W)
os.makedirs(os.path.join(W, "data")); sys.path.insert(0, W)
import tgq, tgquiet, digest
FAILS = []
def check(n, g):
    print(("  ok   " if g else "  FAIL ") + n)
    if not g: FAILS.append(n)
posted = []
tgq._post = lambda tok, chat, text, silent: (posted.append((chat, text, silent)) or (True, None, True, 0))
for t in ("🚀 RUNNING ▲ COROX ₹1,912 +1.2% · 10:05\ncrossed +1%", "🧩 CALLS BOUGHT ▲ COROX ₹1,915 · 10:07\nWATCH", "⚡ SPEED ▲ COROX day +1.4% · 10:09",
          "🚀 RUNNING ▲ SBINX ₹1,045 +1.1% · 10:10\ncrossed +1%", "📰 NEWS · TATAX · BOARD · 10:11\nboard meeting on 20 Nov"):
    tgq.send("T", "-100:5", t, silent=True)
tgq.flush(5)
check("P3 lines are not sent one by one (%d posted)" % len(posted), not posted)
check("... and none is dropped: all 5 wait in the digest spool", len(open(digest.SPOOL).read().strip().split("\n")) == 5)
now = dt.datetime(2026, 11, 12, 10, 15, tzinfo=digest.IST)
digest.market_hours = lambda n: True
sent = []
digest.run(send=lambda c, t: sent.append((c, t)), now=now)
print(sent[0][1] if sent else "-")
check("ONE digest for the channel, grouped by share: COROX ×3 first, then SBINX, then the rest", len(sent) == 1 and "COROX ×3:" in sent[0][1] and sent[0][1].index("COROX") < sent[0][1].index("SBINX") and "TATAX" in sent[0][1])
check("... headed 🟡 DIGEST, 5 quiet alerts", sent and sent[0][1].startswith("🟡 DIGEST") and "5 quiet alerts" in sent[0][1])
check("the spool is empty after it went", not open(digest.SPOOL).read().strip())
check("the digest itself passes the gate (and goes silent)", tgquiet.allow(sent[0][1]))
check("a P1 / P2 is never held back", tgquiet.allow("🟢 GO · SWIGGY ▲ CE · 09:16\nx") and tgquiet.allow("🚨 CRITICAL GOVT · RBI · 11:02\nx"))
digest.market_hours = lambda n: False
digest.spool("-100:5", "🚀 RUNNING ▲ LATEX ₹10 +1% · 20:05", time.time())
s2 = []
digest.run(send=lambda c, t: s2.append(t), now=dt.datetime(2026, 11, 12, 20, 15, tzinfo=digest.IST))
check("outside market hours: hourly (a 10-min-old line waits)", not s2 and "LATEX" in open(digest.SPOOL).read())
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS))); shutil.rmtree(W); sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 205"
python3 $W/p205_patch.py $D || back
cd $D && python3 -m py_compile digest.py tgquiet.py || back
echo "=== the test (a stand-in for Telegram - nothing sent)"
timeout 60 python3 $D/p205test.py > /tmp/p205test.out 2>&1; R=$?
grep -E "  ok|FAIL|PASSED" /tmp/p205test.out; [ $R = 0 ] || back
cat > $U/gir-digest.service <<'UNIT'
[Unit]
Description=GIR 🟡 DIGEST - the P3 alerts, one quiet message a channel
[Service]
Type=oneshot
TimeoutStartSec=300
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 digest.py >> data/digest.log 2>&1'
UNIT
cat > $U/gir-digest.timer <<'UNIT'
[Unit]
Description=GIR 🟡 DIGEST every 15 minutes (hourly outside market hours - it decides itself)
[Timer]
OnCalendar=*-*-* *:00/15:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-digest.timer >/dev/null 2>&1
echo "=== restarting the senders"
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do systemctl restart $s && echo "  $s restarted"; done
sleep 20
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
echo "  🟡 DIGEST next: $(TZ=Asia/Kolkata date -d "$(systemctl show gir-digest.timer -p NextElapseUSecRealtime --value)" '+%H:%M IST' 2>/dev/null)"
echo
echo "✅ patch 205 done. P1 rings loud and stays on the page until ✓ · P2 rings · P3 arrives as a quiet 🟡 DIGEST every 15 min. Ctrl + Shift + R."
