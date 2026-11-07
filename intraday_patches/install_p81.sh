#!/bin/bash
# PATCH 81 - THE PUSH STREAM (on top of patch 80). /events from the page server (Server-Sent Events):
#   · 'now' the same second a line reaches Box Picks · 'idx' every ~3 s · 'secs' when the desk writes a new picture
#   · home.html listens and renders the same panels with the same code (no change to the look); the tape and the news
#     stay on the page's own poll (gzip) - 15 s while the stream is up, 5 s when it is not (the fallback)
#   · the browser reconnects by itself; the server ends a stream after an hour so a dead phone is dropped
#   Edits dashserve.py home.html in place (exact anchors). Installs p81test.py. Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g81; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p81.sh now"; exit 1; fi
grep -q "import tgq" $D/engine2.py || { echo "patch 80 is not installed yet - paste patch 80 first"; exit 1; }
grep -q '"/events"' $D/dashserve.py && { echo "patch 81 is already installed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p81test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p81_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p81_patch.py - PATCH 81: the push stream. /events (Server-Sent Events) from the page server: 'now' the same second a
line reaches Box Picks, 'idx' every ~3 s, 'secs' when the desk writes a new picture. home.html listens and renders the
same panels with the same code; the tape and the news stay on the page's own poll (gzip, 15 s while the stream is up,
5 s when it is not). No new page, no change to the look.
Usage: python3 p81_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


# ============================================================ dashserve.py
E("dashserve.py", '''def home():
    """the home page in one call: the index strip, NOW (every line that went to Box Picks today, newest first), the sectors
    (the desk's ranking), the F&O tape (every share: price, desk meter, one line of what its OI says) and the news run"""
    if time.time() - _HOME["t"] < 3 and _HOME["v"]:
        return _HOME["v"]''', '''def alerts_rowid():
    """the newest line in the NOW list (tomorrow.db alerts) - the push stream sends NOW the moment this changes"""
    try:
        c = _tom(); r = c.execute("select max(rowid) from alerts").fetchone()[0]; c.close()
        return r or 0
    except Exception:
        return -1


def now_rows_(today):
    """NOW: every line that went to Box Picks today, newest first (the same text the phone got)"""
    out = []
    try:
        c = _tom()
        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 60", (today,)):
            lines = [x for x in text.split("\\n") if x.strip()]
            out.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})
        c.close()
    except Exception:
        pass
    return out


def home(fresh=False):
    """the home page in one call: the index strip, NOW (every line that went to Box Picks today, newest first), the sectors
    (the desk's ranking), the F&O tape (every share: price, desk meter, one line of what its OI says) and the news run"""
    if not fresh and time.time() - _HOME["t"] < 3 and _HOME["v"]:
        return _HOME["v"]''')
E("dashserve.py", '''    now_rows = []
    try:
        c = _tom()
        for t, kind, sym, side, text in c.execute("select t, kind, sym, side, text from alerts where day=? order by t desc limit 60", (today,)):
            lines = [x for x in text.split("\\n") if x.strip()]
            now_rows.append({"t": t[:5], "kind": kind, "s": sym, "side": side, "head": lines[0] if lines else "", "lines": lines[1:6]})
        c.close()
    except Exception:
        pass
    import sectors''', '''    now_rows = now_rows_(today)
    import sectors''')
E("dashserve.py", '''    def do_GET(self):
        u = urlparse(self.path)''', '''    def events(self):
        """the push stream (Server-Sent Events, one connection per open page): 'now' the same second a line reaches
        Box Picks · 'idx' every ~3 s · 'secs' when the desk writes a new picture. The tape and the news stay on the
        page's own poll (gzip). The browser reconnects by itself; the stream ends after an hour so a dead phone is dropped."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()
        last, t0, ping = {}, time.time(), time.time()

        def emit(name, obj):
            j = json.dumps(obj, ensure_ascii=False, default=str)
            if last.get(name) == j:
                return False
            last[name] = j
            self.wfile.write(("event: %s\\ndata: %s\\n\\n" % (name, j)).encode("utf-8")); self.wfile.flush()
            return True
        try:
            self.wfile.write(b": gir\\n\\n"); self.wfile.flush()
            while time.time() - t0 < 3600:
                rid = alerts_rowid()
                if rid != last.get("rid"):
                    last["rid"] = rid
                    emit("now", {"now": now_rows_(dt.datetime.now(IST).strftime("%Y-%m-%d"))})
                d = home()
                emit("idx", {k: d.get(k) for k in ("t", "day", "closed", "idx", "ticks_s", "ban")})
                emit("secs", {"sectors": d.get("sectors"), "desk_t": d.get("desk_t"), "desk_src": d.get("desk_src")})
                if time.time() - ping > 15:
                    ping = time.time(); self.wfile.write(b": ping\\n\\n"); self.wfile.flush()
                time.sleep(0.5)
        except (BrokenPipeError, ConnectionResetError, OSError):
            return
        except Exception as ex:
            try:
                self.wfile.write(("event: err\\ndata: %s\\n\\n" % json.dumps(str(ex)[:120])).encode("utf-8")); self.wfile.flush()
            except Exception:
                pass

    def do_GET(self):
        u = urlparse(self.path)''')
E("dashserve.py", '''        try:
            if u.path == "/":                         # the home page: ONE screen (home.html); the rest behind "more"''', '''        if u.path == "/events":                       # the push stream
            return self.events()
        try:
            if u.path == "/":                         # the home page: ONE screen (home.html); the rest behind "more"''')

# ============================================================ home.html
E("home.html", '''async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ D=await r.json();
''', '''function render(D_){ D=Object.assign(D||{}, D_);
''')
E("home.html", '''    first=false; } }catch(e){} setTimeout(loop,5000); }
loop(); loadDesk(); setInterval(loadDesk,60000); loadThree(); setInterval(loadThree,120000);''', '''    first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
// the push stream: NOW the same second a line reaches Box Picks, the index strip, the sectors; the tape and the news on the poll above
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
loop(); stream(); loadDesk(); setInterval(loadDesk,60000); loadThree(); setInterval(loadThree,120000);''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new) in enumerate(edits, 1):
            n = s.count(old)
            if n != 1:
                print("ANCHOR %s #%d found %d times (need 1): %r" % (f, i, n, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p81: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p81: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $D/p81test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p81test.py - the push-stream test: a second copy of the page server on a free local port (read-only, the live one
is not touched). 1 /events needs the token · 2 the stream opens and sends 'now' and 'idx' at once · 3 a new NOW line
is pushed within a second · 4 /home still answers · 5 home.html listens to the stream and keeps its poll as the fallback"""
import os, sys, time, json, socket, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve
from http.server import ThreadingHTTPServer

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


RID = {"v": 7}
dashserve.alerts_rowid = lambda: RID["v"]
dashserve.now_rows_ = lambda today: [{"t": "10:0%d" % (RID["v"] % 10), "kind": "🎯", "s": "GLENMARK", "side": "CE", "head": "🎯 BOX PICK test %d" % RID["v"], "lines": []}]
srv = ThreadingHTTPServer(("127.0.0.1", 0), dashserve.H)
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
TOKEN = dashserve.TOKEN


def get(path, secs=2.5):
    s = socket.create_connection(("127.0.0.1", port), timeout=secs)
    s.sendall(("GET %s HTTP/1.1\r\nHost: x\r\nAccept: */*\r\n\r\n" % path).encode())
    buf, t0 = b"", time.time()
    try:
        while time.time() - t0 < secs:
            d = s.recv(65536)
            if not d:
                break
            buf += d
    except Exception:
        pass
    return s, buf.decode("utf-8", "replace")


print("1. the token")
s, r = get("/events?k=wrong", 1.0); s.close()
check("/events without the token -> 403", r.startswith("HTTP/1.1 403") or r.startswith("HTTP/1.0 403"))

print("2. the stream opens")
s, r = get("/events?k=" + TOKEN, 2.5)
check("200 and text/event-stream", " 200 " in r.split("\r\n")[0] and "text/event-stream" in r)
check("'now' arrives at once with the NOW list", "event: now\n" in r and "BOX PICK test 7" in r)
check("'idx' arrives at once", "event: idx\n" in r)

print("3. a new line is pushed")
RID["v"] = 8
t0 = time.time(); buf = ""
s.settimeout(0.2)
while time.time() - t0 < 2.0 and "BOX PICK test 8" not in buf:
    try:
        buf += s.recv(65536).decode("utf-8", "replace")
    except Exception:
        pass
check("the new NOW line is on the stream within %d ms" % int((time.time() - t0) * 1000), "BOX PICK test 8" in buf and time.time() - t0 < 1.5)
s.close()

print("4. the poll still answers")
s, r = get("/home?k=" + TOKEN, 2.5); s.close()
body = r.split("\r\n\r\n", 1)[-1]
try:
    j = json.loads(body) if body.strip().startswith("{") else None
except Exception:
    j = None
check("/home -> 200 JSON with now/sectors/tape/news", " 200 " in r.split("\r\n")[0] and (j is None and "gzip" in r or (j is not None and all(k in j for k in ("now", "sectors", "tape", "news")))))

print("5. the page")
h = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("home.html opens the stream and renders with the same code", "new EventSource(" in h and "function render(D_)" in h and 'addEventListener(ev' in h)
check("the poll stays as the fallback (15 s on the stream, 5 s without)", "esOK?15000:5000" in h and "setTimeout(loop,5000)" not in h)
srv.shutdown()
print("\nP81 STREAM TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p81_patch.py $D || { rm -f $D/p81test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cd $D && python3 -m py_compile dashserve.py p81test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the stream test (a second copy of the page server on a free local port, read-only):"
timeout 60 python3 p81test.py 2>&1 | grep "OK  \|FAIL\|STREAM TEST\|Traceback\|Error" | head -20
timeout 60 python3 p81test.py >/dev/null 2>&1 || { echo "the stream test failed"; back; }
systemctl restart gir-dash && sleep 4
K=$(cat $D/dash_token.txt)
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q "new EventSource(" || { echo "home.html is not the new one"; back; }
curl -s -N --max-time 4 "http://127.0.0.1:8090/events?k=$K" 2>/dev/null | head -c 2000 | grep -q "event: idx" || { echo "/events did not stream"; back; }
curl -s --max-time 20 "http://127.0.0.1:8090/home?k=$K" | python3 -c "
import json, sys; d = json.load(sys.stdin); print('    home data: NOW %d · sectors %d · tape %d · news %d' % (len(d['now']), len(d['sectors']), len(d['tape']), len(d['news'])))" || { echo "/home did not answer"; back; }
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 81 APPLIED - reload the home page (pull down to refresh on the phone): NOW now arrives the same second, no refresh timer."
