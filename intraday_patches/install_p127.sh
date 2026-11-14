#!/bin/bash
# PATCH 127 - ONE "GIR" GROUP WITH TOPICS (on top of patch 126c).
#   GIR Box Picks stays its own channel for the CRITICAL alerts (a group takes only ~20 messages a minute in all - the
#   critical ones must never wait behind a busy morning). Everything else goes to a topic of one GIR group:
#   🔭 OI · 🚀 Moves · 📰 News · 📑 Results · 🗞 Recap · ⚙️ System   (tg_group_setup.py creates the topics).
#   Until the group is set up nothing changes: GIR OI / GIR Moves & News keep getting their alerts.
#   tglanes.py, tgq.py, newsrecap.py (exact anchors) · tg_group_setup.py (new). Restarts every GIR service.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g127; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p127.sh now"; exit 1; fi
grep -q "patch 126c" $D/expect.py 2>/dev/null || { echo "patch 126c is not installed yet - paste patch 126c first"; exit 1; }
grep -q "def topic" $D/tglanes.py && { echo "patch 127 is already installed"; exit 1; }
F="tglanes.py tgq.py newsrecap.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/tg_group_setup.py $D/p127test.py; systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p127_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p127_patch.py - PATCH 127: ONE "GIR" GROUP WITH TOPICS. GIR Box Picks stays its own channel (the critical alerts are
never held behind a busy group); everything else goes to a topic of the GIR group when it is set up (tg_group_setup.py):
🔭 OI · 🚀 Moves · 📰 News · 📑 Results · 🗞 Recap · ⚙️ System. Not set up -> GIR OI / GIR Moves & News as before.
  tglanes.py: topic() + chat_for() gives "group:topic"; tgq.py and newsrecap.py send into the topic (message_thread_id)
Usage: python3 p127_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "tglanes.py": [
        ('''                    m = re.match(r"\\s*(?:export\\s+)?(TG_CHAT_[A-Z]+)\\s*=\\s*(.*?)\\s*$", line)''',
         '''                    m = re.match(r"\\s*(?:export\\s+)?(TG_(?:CHAT|TOPIC)_[A-Z]+)\\s*=\\s*(.*?)\\s*$", line)   # patch 127: + the group's topics'''),
        ('''def chat_for(text, box_chat):
    """the chat id for this alert: its lane's channel when set, else GIR Box Picks (box_chat)"""
    k = KEYS[lane(text)]
    if k == "TG_CHAT_BOX":
        return box_chat
    return os.environ.get(k) or _env().get(k) or box_chat''',
         '''# patch 127: the GIR group's topics (tg_group_setup.py creates them and saves TG_CHAT_GIRGROUP + TG_TOPIC_<NAME>)
TOPICS = [("oi", "🔭 OI"), ("moves", "🚀 Moves"), ("news", "📰 News"), ("results", "📑 Results"), ("recap", "🗞 Recap"), ("system", "⚙️ System")]


def topic(text):
    """-> "critical" (GIR Box Picks, never the group) | oi | moves | news | results | recap | system"""
    ln = lane(text)
    if ln != "moves":
        return ln
    try:
        import alertword
        L = [x for x in (text or "").split("\\n") if x.strip()]
        _o, H2, _b = alertword._head(L) if L else (False, "", [])
        k = H2.split()[0] if H2.split() else ""
        if "· RESULTS ·" in H2 and ("FILING" in H2 or re.search(r"· NSE \\d", H2)):     # the exchange reader's results line (a news story about results -> news)
            return "results"
        if k == "🗞" or H2.startswith("📊 NEWS REACTION"):
            return "recap"
        if k in ("📰", "📄", "🏛") or "MARKET NEWS" in H2:
            return "news"
        if k in ("📋", "📊") or "SCORECARD" in H2.upper():
            return "system"
    except Exception:
        pass
    return "moves"


def _get(k):
    return os.environ.get(k) or _env().get(k)


def chat_for(text, box_chat):
    """the chat for this alert: critical -> GIR Box Picks; the rest -> its topic of the GIR group ("group:topic") when the
    group is set up, else its channel (GIR OI / GIR Moves & News), else GIR Box Picks"""
    ln = lane(text)
    if ln == "critical":
        return box_chat
    grp, tid = _get("TG_CHAT_GIRGROUP"), _get("TG_TOPIC_" + topic(text).upper())
    if grp and tid:
        return "%s:%s" % (grp, tid)
    return _get(KEYS[ln]) or box_chat


def split_chat(chat):
    """ "-100123:45" -> ("-100123", "45"); a plain chat id -> (id, None)"""
    s = str(chat or "")
    if ":" in s:
        a, b = s.rsplit(":", 1)
        if b.isdigit():
            return a, b
    return s, None'''),
    ],
    "tgq.py": [
        ('''    data = {"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}''',
         '''    data = {"chat_id": chat, "text": text[:4000], "disable_web_page_preview": "true"}
    if ":" in str(chat):                                         # patch 127: "group:topic" -> the topic of the GIR group
        a_, b_ = str(chat).rsplit(":", 1)
        if b_.isdigit():
            data["chat_id"], data["message_thread_id"] = a_, b_'''),
    ],
    "newsrecap.py": [
        ('''data={"chat_id": chat, "caption": cap[:1000]},''',
         '''data=dict({"chat_id": chat, "caption": cap[:1000]}, **({"chat_id": str(chat).rsplit(":", 1)[0], "message_thread_id": str(chat).rsplit(":", 1)[1]} if ":" in str(chat) else {})),'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("tglanes.py + tgq.py + newsrecap.py: the GIR group's topics")
PY_PATCH
cat > $W/tg_group_setup.py <<'PY_SETUP'
#!/usr/bin/env python3
"""tg_group_setup.py - patch 127: ONE "GIR" GROUP WITH TOPICS for everything except the critical alerts.

  GIR Box Picks stays its own channel: 🔴 trade alerts, 🚨 CRITICAL news / results, 🧱 CIRCUIT, SOCKET DOWN - Telegram
  lets a group take only ~20 messages a minute, so the critical ones never wait behind a busy group.
  The GIR group gets one topic each:  🔭 OI · 🚀 Moves · 📰 News · 📑 Results · 🗞 Recap · ⚙️ System

  1) In Telegram: New Group -> name it "GIR" (add yourself) -> Group settings -> turn ON "Topics".
  2) Add @Billionairerama_bot to the group and make it an ADMIN with "Manage Topics" (and "Post messages").
  3) Give the group a public link for a moment (Group settings -> Group type -> Public, e.g. gir_alerts_group), then
     on the server:   python3 /home/globalbot/intraday/tg_group_setup.py @gir_alerts_group
                 or   python3 /home/globalbot/intraday/tg_group_setup.py -1001234567890     (if you know the id)
     (with nothing after it, it looks in the bot's recent updates - that can briefly interrupt another program that
     reads the same bot, so the link is the better way)
     It creates the six topics, posts a test line in each and saves TG_CHAT_GIRGROUP + TG_TOPIC_* in .env.
     GIR re-reads .env once a minute - no restart. Make the group private any time: the saved id keeps working.
     python3 tg_group_setup.py status      what goes where
It never touches TG_CHAT_FO / TG_CHAT_OI (NEWSHAWK's) or any other program's settings. The token is never printed."""
import sys, os, re, json, time, shutil, urllib.request, urllib.parse, urllib.error

ENV = os.environ.get("GIR_ENV", "/home/globalbot/.env")
API = os.environ.get("TG_API", "https://api.telegram.org/bot")
TOPICS = [("OI", "🔭 OI", "🧩 OI build-up · 🔭 EARLY · 🔎 BUILD-UP · 🚨 SUDDEN · 🧱 WALL FLIP"),
          ("MOVES", "🚀 Moves", "🚀 RUNNING from 1% · ⚡ SPEED · ⚡ FIRST MOVE · 🌅 GAP · 📈 MOVER · 📗 ORDER BOOK"),
          ("NEWS", "📰 News", "📰 / 📄 company news and filings · 🏛 market news (🚨 CRITICAL news stays in Box Picks)"),
          ("RESULTS", "📑 Results", "results IN LINE / numbers coming (a BEAT / MISS / 10%+ surprise stays in Box Picks)"),
          ("RECAP", "🗞 Recap", "🗞 the 08:30 news recap PDF · 📊 the 15:45 news reaction"),
          ("SYSTEM", "⚙️ System", "📋 F&O list changes · 📊 scorecards")]
COLORS = [0x6FB9F0, 0xFFD67E, 0xCB86DB, 0x8EEE98, 0xFF93B2, 0xFB6F5F]


def read_env():
    env = {}
    for line in open(ENV):
        m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line)
        if m:
            env[m.group(1)] = m.group(2).strip("'\"")
    return env


def save(pairs):
    shutil.copy(ENV, ENV + ".bak%d" % int(time.time()))
    keys = set(pairs)
    lines = [l for l in open(ENV) if not any(re.match(r"\s*(?:export\s+)?%s\s*=" % k, l) for k in keys)]
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines += ["%s=%s\n" % (k, v) for k, v in pairs.items()]
    open(ENV, "w").writelines(lines)


def call(tok, method, **params):
    data = urllib.parse.urlencode(params).encode() if params else None
    try:
        return json.load(urllib.request.urlopen(API + tok + "/" + method, data=data, timeout=20))
    except urllib.error.HTTPError as ex:
        try:
            return json.load(ex)
        except Exception:
            return {"ok": False, "description": "HTTP %s" % ex.code}
    except Exception as ex:
        return {"ok": False, "description": str(ex)[:120]}


def find_group(tok):
    """the forum groups the bot was added to (read from the bot's recent updates, nothing is marked as read)"""
    r = call(tok, "getUpdates", limit=100, timeout=0)
    seen = {}
    for u in (r.get("result") or []) if r.get("ok") else []:
        for key in ("my_chat_member", "message", "edited_message", "chat_member"):
            ch = ((u.get(key) or {}).get("chat") or {})
            if ch.get("type") == "supergroup" or ch.get("is_forum"):
                seen[str(ch["id"])] = ch.get("title") or ""
    return seen, (None if r.get("ok") else r.get("description"))


def main():
    if not os.path.exists(ENV):
        print("no %s" % ENV); return 1
    env = read_env()
    tok = env.get("TELEGRAM_TOKEN") or env.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
    if not tok:
        print("no TELEGRAM_TOKEN in %s" % ENV); return 1
    arg = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    if arg == "status":
        print("GIR Box Picks (TG_CHAT_BOX): %s · the CRITICAL alerts - never the group" % ("set" if env.get("TG_CHAT_BOX") else "NOT SET"))
        print("GIR group (TG_CHAT_GIRGROUP): %s" % ("set" if env.get("TG_CHAT_GIRGROUP") else "not set - GIR OI / GIR Moves & News channels are used"))
        for k, name, what in TOPICS:
            print("  %-11s %s · %s" % (name, "topic set" if env.get("TG_TOPIC_" + k) else "-", what))
        return 0
    if re.fullmatch(r"-?\d+", arg):
        chat = arg
    elif arg:
        r = call(tok, "getChat", chat_id=arg if arg.startswith("@") else "@" + arg)
        if not r.get("ok"):
            print("Telegram could not find %s (%s)." % (arg, r.get("description", "?"))); return 1
        chat = str(r["result"]["id"])
    else:
        seen, err = find_group(tok)
        gir = {k: v for k, v in seen.items() if "gir" in v.lower()}
        pick = gir if len(gir) == 1 else seen if len(seen) == 1 else {}
        if not pick:
            if err:
                print("Could not read the bot's recent updates (%s)." % err)
            print("Groups the bot was recently added to: %s" % (", ".join("%s (%s)" % (v, k) for k, v in seen.items()) or "none seen"))
            print("Run again with the group id:  python3 tg_group_setup.py -100xxxxxxxxxx   (or remove and re-add the bot to the group, then run again)")
            return 1
        chat = list(pick)[0]
        print("found the group: %s (id %s)" % (pick[chat], chat))
    clash = [k for k, v in env.items() if k.startswith(("TG_CHAT", "TG_NEWS")) and v == chat and k != "TG_CHAT_GIRGROUP"]
    if clash:
        print("STOP: that chat is already used by %s in .env - make a NEW group for GIR." % ", ".join(clash)); return 1
    r = call(tok, "getChat", chat_id=chat)
    if not r.get("ok"):
        print("Telegram: %s (is the bot in the group?)" % r.get("description", "?")); return 1
    if not r["result"].get("is_forum"):
        print("The group %s has Topics turned OFF. Group settings -> Topics -> ON, then run again." % (r["result"].get("title") or chat)); return 1
    title = r["result"].get("title") or ""
    me = call(tok, "getMe")
    m = call(tok, "getChatMember", chat_id=chat, user_id=(me.get("result") or {}).get("id", 0))
    mr = m.get("result") or {}
    if mr.get("status") not in ("administrator", "creator") or not mr.get("can_manage_topics", mr.get("status") == "creator"):
        print("Make the bot an ADMIN of %s with 'Manage Topics' turned on, then run again." % title); return 1
    new = {"TG_CHAT_GIRGROUP": chat}
    for i, (k, name, what) in enumerate(TOPICS):
        tid = env.get("TG_TOPIC_" + k) if env.get("TG_CHAT_GIRGROUP") == chat else None
        if not tid:
            c = call(tok, "createForumTopic", chat_id=chat, name=name, icon_color=COLORS[i % len(COLORS)])
            if not c.get("ok"):
                print("could not create the topic %s: %s" % (name, c.get("description", "?"))); return 1
            tid = str(c["result"]["message_thread_id"])
            print("  topic created: %s" % name)
        new["TG_TOPIC_" + k] = tid
        t = call(tok, "sendMessage", chat_id=chat, message_thread_id=tid, text="✅ %s - GIR posts here: %s" % (name, what), disable_notification="true")
        if not t.get("ok"):
            print("could not post in %s: %s" % (name, t.get("description", "?"))); return 1
    save(new)
    print("SAVED: the GIR group %s and its %d topics. A test line went to each topic." % (("(" + title + ")") if title else chat, len(TOPICS)))
    print("From now on: critical -> GIR Box Picks · everything else -> its topic. GIR OI / GIR Moves & News get nothing new (keep or delete them).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_SETUP
cat > $D/p127test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p127test.py - ONE GIR GROUP WITH TOPICS: critical stays in GIR Box Picks, the rest goes to its topic; the setup
script creates the topics once. A fake Telegram on this machine - nothing is sent anywhere."""
import os, sys, json, time, threading, tempfile, shutil, subprocess, urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import tglanes
tmp = tempfile.mkdtemp(prefix="p127")
try:
    env = os.path.join(tmp, ".env")
    open(env, "w").write("TELEGRAM_TOKEN=abc\nTG_CHAT_BOX=-100box\nTG_CHAT_GIROI=-100oi\nTG_CHAT_GIRMOVES=-100mv\nTG_CHAT_OI=-100999\n")
    tglanes.ENVS = [env]; tglanes._C["at"] = 0.0
    for k in list(os.environ):
        if k.startswith(("TG_CHAT_GIR", "TG_TOPIC_")):
            os.environ.pop(k)
    S = {"🚨 CRITICAL NEWS ▼ ASTRAL · REG · 10:00\nx": "critical", "🧩 CALL WRITERS RUNNING ▲ TITAN ₹3500 · 10:42\nWATCH": "oi",
         "🚀 RUNNING ▲ YESBANK ₹24.3 +1.2% · 10:05\ncrossed +1%": "moves", "📰 NEWS ▲ TITAN · RESULTS · ET 10:00\nTitan Q2 up": "news",
         "🏛 MARKET NEWS ▲ likely UP · 10:00 · ET": "news", "📰 FILING · VOLTAS · RESULTS · IN LINE · NSE 16:59:00 (read in 60s)": "results",
         "🗞 GIR MORNING NEWS RECAP · Mon 09 Nov 08:30": "recap", "📊 NEWS REACTION · 2026-11-09 · 12 news lines": "recap",
         "📋 F&O LIST CHANGED · 210 shares now": "system", "🚨 CRITICAL RESULTS ▲ DIVISLAB · RESULTS · BEAT YoY · 52% ABOVE ESTIMATES": "critical"}
    bad = [(t[:30], tglanes.topic(t), w) for t, w in S.items() if tglanes.topic(t) != w]
    check("%d alerts -> the right topic%s" % (len(S), (" - wrong: %s" % bad) if bad else ""), not bad)
    check("no group yet: OI -> GIR OI, news -> GIR Moves & News, critical -> Box Picks",
          (tglanes.chat_for("🧩 X ▲ TITAN", "-100box"), tglanes.chat_for("📰 NEWS ▲ TITAN · x", "-100box"), tglanes.chat_for("🚨 CRITICAL NEWS ▼ A", "-100box")) == ("-100oi", "-100mv", "-100box"))

    # a fake Telegram
    LOG, TOPICS_MADE = [], []
    STATE = {"forum": True, "admin": True}

    class H(BaseHTTPRequestHandler):
        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            q = {k: v[0] for k, v in urllib.parse.parse_qs(self.rfile.read(n).decode()).items()}
            m = self.path.rsplit("/", 1)[-1]
            LOG.append((m, q))
            if m == "getChat":
                r = {"ok": True, "result": {"id": -100777, "title": "GIR", "type": "supergroup", "is_forum": STATE["forum"]}}
            elif m == "getMe":
                r = {"ok": True, "result": {"id": 42}}
            elif m == "getChatMember":
                r = {"ok": True, "result": {"status": "administrator" if STATE["admin"] else "member", "can_manage_topics": STATE["admin"]}}
            elif m == "createForumTopic":
                TOPICS_MADE.append(q["name"]); r = {"ok": True, "result": {"message_thread_id": 100 + len(TOPICS_MADE), "name": q["name"]}}
            else:
                r = {"ok": True, "result": {}}
            b = json.dumps(r).encode(); self.send_response(200); self.end_headers(); self.wfile.write(b)

        def log_message(self, *a):
            pass
    srv = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    E = dict(os.environ, GIR_ENV=env, TG_API="http://127.0.0.1:%d/bot" % srv.server_port)
    run = lambda *a: subprocess.run([sys.executable, os.path.join(B, "tg_group_setup.py")] + list(a), env=E, capture_output=True, text=True, timeout=60)
    STATE["forum"] = False
    r0 = run("-100777")
    check("Topics OFF -> it says how to turn them on, saves nothing", r0.returncode == 1 and "Topics turned OFF" in r0.stdout and "GIRGROUP" not in open(env).read())
    STATE["forum"] = True; STATE["admin"] = False
    r0 = run("-100777")
    check("the bot not an admin with 'Manage Topics' -> it says so", r0.returncode == 1 and "Manage Topics" in r0.stdout)
    STATE["admin"] = True
    r0 = run("-100999")
    check("NEWSHAWK's chat (TG_CHAT_OI) is refused", r0.returncode == 1 and "STOP" in r0.stdout)
    r1 = run("-100777")
    e1 = open(env).read()
    posts = [q for m, q in LOG if m == "sendMessage"]
    check("six topics created, a test line in each, saved: %s" % TOPICS_MADE, r1.returncode == 0 and len(TOPICS_MADE) == 6 and "TG_CHAT_GIRGROUP=-100777" in e1
          and "TG_TOPIC_OI=101" in e1 and "TG_TOPIC_SYSTEM=106" in e1 and len(posts) == 6 and {p["message_thread_id"] for p in posts} == {str(i) for i in range(101, 107)})
    r2 = run("-100777")
    check("run again: no new topics (still %d), the same ids" % len(TOPICS_MADE), r2.returncode == 0 and len(TOPICS_MADE) == 6 and open(env).read().count("TG_TOPIC_OI=") == 1)
    check("NEWSHAWK's TG_CHAT_OI untouched", "TG_CHAT_OI=-100999" in open(env).read())
    srv.shutdown()

    tglanes._C["at"] = 0.0
    check("with the group: OI -> topic 101, news -> 103, results -> 104, critical still -> Box Picks: %s" % [tglanes.chat_for(x, "-100box") for x in (
        "🧩 X ▲ TITAN", "📰 NEWS ▲ TITAN · x", "📰 FILING · VOLTAS · RESULTS · IN LINE · NSE", "🚨 CRITICAL NEWS ▼ A")],
          [tglanes.chat_for(x, "-100box") for x in ("🧩 X ▲ TITAN", "📰 NEWS ▲ TITAN · x", "📰 FILING · VOLTAS · RESULTS · IN LINE · NSE", "🚨 CRITICAL NEWS ▼ A")]
          == ["-100777:101", "-100777:103", "-100777:104", "-100box"])

    # the sender puts it into the topic
    SENT = []

    class FakeResp(object):
        status_code, text, ok = 200, "{}", True

    class FakeReq(object):
        def post(self, url, data=None, timeout=None, files=None):
            SENT.append((url, dict(data))); return FakeResp()
    real_req = sys.modules.get("requests")
    sys.modules["requests"] = FakeReq()
    import tgq
    tgq.send("tok", "-100777:101", "🧩 X ▲ TITAN"); tgq.flush()
    check("tgq: chat -100777 + message_thread_id 101", SENT and SENT[-1][1].get("chat_id") == "-100777" and SENT[-1][1].get("message_thread_id") == "101")
    import newsrecap
    pdf = os.path.join(tmp, "r.pdf"); open(pdf, "wb").write(b"%PDF-1.4 test")
    os.environ["TELEGRAM_TOKEN"] = "tok"; os.environ["TG_CHAT_BOX"] = "-100box"
    okr = newsrecap.send_pdf(pdf, "🗞 GIR MORNING NEWS RECAP · Mon 09 Nov 08:30", post=lambda url, data=None, files=None, timeout=None: SENT.append((url, dict(data))) or FakeResp())
    check("the 08:30 recap PDF -> the 🗞 Recap topic (105)", okr and SENT[-1][0].endswith("/sendDocument") and SENT[-1][1].get("chat_id") == "-100777" and SENT[-1][1].get("message_thread_id") == "105")
    if real_req is not None:
        sys.modules["requests"] = real_req
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP127 GIR GROUP TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p127_patch.py $D || { rm -f $D/p127test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/tg_group_setup.py $D/
cd $D && python3 -m py_compile tglanes.py tgq.py newsrecap.py tg_group_setup.py p127test.py || back
timeout 120 python3 p127test.py 2>&1 | grep "OK  \|FAIL\|GROUP TEST"
timeout 120 python3 p127test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p124test.py p125btest.py p125test.py p126test.py p80test.py p118test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash && sleep 15
for u in gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 127 APPLIED. Nothing changes until the GIR group is set up:"
echo "  1) Telegram: New Group 'GIR' -> Group settings -> Topics ON"
echo "  2) add @Billionairerama_bot as ADMIN with 'Manage Topics'"
echo "  3) Group type -> Public for a moment, link e.g. gir_alerts_group, then:"
echo "       python3 $D/tg_group_setup.py @gir_alerts_group"
echo "  4) make the group Private again (the saved id keeps working)"
python3 $D/tg_group_setup.py status
