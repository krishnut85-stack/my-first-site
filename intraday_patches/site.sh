#!/bin/bash
# PATCH 167 - THE GIR WEBSITE: https://girtrader.com with the padlock (Let's Encrypt certificate through Caddy, renews by itself) and a
#   sign-in page (your username + password; the phone / laptop stays signed in 90 days; 8 wrong tries -> 15 min wait). When the https
#   site answers, the old http://64.227.155.177:8090 address is closed to the outside (GIR's own tools still use it inside the server),
#   and the morning Telegram link points to the website. Every step checks itself; if one is not ready, nothing breaks.
#   bash site.sh [domain]      (default girtrader.com)
set -u
DOM=${1:-girtrader.com}; IP=64.227.155.177
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
echo "== 1. does $DOM point to this server?"
for h in $DOM www.$DOM; do a=$(getent ahostsv4 $h | awk '{print $1}' | sort -u | tr '\n' ' '); echo "   $h -> ${a:-not yet}"; done
getent ahostsv4 $DOM | grep -q "$IP" || { echo "   NOT YET - GoDaddy's change takes 5 minutes to 2 hours. Nothing was changed; run this again later."; exit 1; }
NAMES="$DOM"; getent ahostsv4 www.$DOM | grep -q "$IP" && NAMES="$DOM, www.$DOM" || echo "   (www.$DOM not pointing here yet - the site starts on $DOM; run this again later to add www)"
echo "== 2. the web ports (80, 443) are free?"
OTHER=$(ss -ltnpH '( sport = :80 or sport = :443 )' 2>/dev/null | grep -v '"caddy"' || true)
[ -z "$OTHER" ] && echo "   free" || { echo "   another program uses them - stopping so it is not broken:"; echo "$OTHER" | sed 's/^/     /'; echo "   send this to Claude"; exit 1; }
echo "== 3. the sign-in"
cat > $D/sitelogin.py <<'PY_SL'
#!/usr/bin/env python3
"""sitelogin.py - patch 167: the login for the GIR website (https://girtrader.com). One user, a password kept only as a salted hash
(PBKDF2-SHA256, 300,000 rounds) in data/site_login.json; a signed cookie keeps the phone / laptop signed in for 90 days; 8 wrong
passwords from one address in 15 minutes -> that address waits 15 minutes.
  python3 sitelogin.py set <username>     choose / change the password (typed twice, never shown)
  python3 sitelogin.py signout-all        every phone / laptop has to sign in again (a new signing key)"""
import os, sys, json, time, hmac, hashlib, secrets, html

BASE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(BASE, "data", "site_login.json")
DAYS = 90
COOKIE = "gir_s"
_FAIL = {}


def _load():
    try:
        return json.load(open(F))
    except Exception:
        return None


def configured():
    c = _load()
    return bool(c and c.get("hash") and c.get("key"))


def set_password(user, pw):
    salt = secrets.token_hex(16)
    h = hashlib.pbkdf2_hmac("sha256", pw.encode(), bytes.fromhex(salt), 300000).hex()
    c = _load() or {}
    c.update({"user": user.strip(), "salt": salt, "hash": h, "rounds": 300000, "key": c.get("key") or secrets.token_hex(32)})
    os.makedirs(os.path.dirname(F), exist_ok=True)
    tmp = F + ".tmp"
    with open(tmp, "w") as f:
        json.dump(c, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, F)


def signout_all():
    c = _load()
    if c:
        c["key"] = secrets.token_hex(32)
        json.dump(c, open(F, "w")); os.chmod(F, 0o600)


def _locked(ip, now=None):
    now = now or time.time()
    n, t0 = _FAIL.get(ip, (0, now))
    if now - t0 > 900:
        _FAIL.pop(ip, None)
        return False
    return n >= 8


def check(user, pw, ip="?", now=None):
    """-> True / False / "locked" """
    now = now or time.time()
    if _locked(ip, now):
        return "locked"
    c = _load()
    ok = False
    if c and c.get("hash"):
        h = hashlib.pbkdf2_hmac("sha256", (pw or "").encode(), bytes.fromhex(c["salt"]), int(c.get("rounds", 300000))).hex()
        ok = hmac.compare_digest(h, c["hash"]) and hmac.compare_digest((user or "").strip().lower(), c["user"].lower())
    if ok:
        _FAIL.pop(ip, None)
    else:
        n, t0 = _FAIL.get(ip, (0, now))
        _FAIL[ip] = (n + 1, t0 if now - t0 <= 900 else now)
    return ok


def _sig(key, body):
    return hmac.new(bytes.fromhex(key), body.encode(), hashlib.sha256).hexdigest()


def make_cookie(now=None):
    c = _load()
    exp = int((now or time.time()) + DAYS * 86400)
    body = "%s|%d" % (c["user"], exp)
    v = "%s|%s" % (body, _sig(c["key"], body))
    return "%s=%s; Max-Age=%d; Path=/; HttpOnly; Secure; SameSite=Lax" % (COOKIE, v, DAYS * 86400)


def cookie_ok(header, now=None):
    c = _load()
    if not c or not header:
        return False
    for part in header.split(";"):
        k, _, v = part.strip().partition("=")
        if k != COOKIE:
            continue
        try:
            user, exp, sig = v.split("|")
            body = "%s|%s" % (user, exp)
            return hmac.compare_digest(sig, _sig(c["key"], body)) and int(exp) > (now or time.time()) and user == c["user"]
        except Exception:
            return False
    return False


def page(msg=""):
    return """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GIR · sign in</title><style>
:root{color-scheme:dark}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0f14;color:#e6edf3;font:16px system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
form{width:min(340px,88vw);background:#111821;border:1px solid #223042;border-radius:14px;padding:26px 22px}
h1{margin:0 0 4px;font-size:22px;letter-spacing:.06em}h1 b{color:#f5a524}p{margin:0 0 18px;color:#8b98a8;font-size:13px}
label{display:block;font-size:12px;color:#8b98a8;margin:12px 0 5px}input{width:100%;box-sizing:border-box;padding:12px;border-radius:9px;border:1px solid #2a3a4f;background:#0b0f14;color:#e6edf3;font-size:16px}
button{margin-top:18px;width:100%;padding:12px;border:0;border-radius:9px;background:#f5a524;color:#111;font-weight:700;font-size:16px}.e{color:#ff6b6b;font-size:13px;margin-top:12px}
</style></head><body><form method="post" action="/login"><h1>⌂ <b>GIR</b></h1><p>F&amp;O intraday terminal</p>
<label>Username</label><input name="u" autocomplete="username" autocapitalize="none" required>
<label>Password</label><input name="p" type="password" autocomplete="current-password" required>
<button>Sign in</button>{MSG}</form></body></html>""".replace("{MSG}", ('<div class="e">%s</div>' % html.escape(msg)) if msg else "")


if __name__ == "__main__":
    import getpass
    if len(sys.argv) > 2 and sys.argv[1] == "set":
        a = getpass.getpass("New password for %s (at least 10 characters): " % sys.argv[2])
        b = getpass.getpass("The same password again: ")
        if a != b:
            print("the two did not match - nothing changed"); sys.exit(1)
        if len(a) < 10:
            print("too short - at least 10 characters; nothing changed"); sys.exit(1)
        set_password(sys.argv[2], a)
        print("password set for %s" % sys.argv[2])
    elif len(sys.argv) > 1 and sys.argv[1] == "signout-all":
        signout_all(); print("every phone / laptop has to sign in again")
    else:
        print(__doc__)
PY_SL
cat > $D/p167test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p167test.py - patch 167: the website sign-in on a real page server (127.0.0.1, a free port; a made-up password; nothing kept)"""
import os, sys, json, time, tempfile, shutil, threading, http.client, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitelogin as SL
T = tempfile.mkdtemp(); SL.F = os.path.join(T, "site_login.json")
import dashserve as ds
from http.server import ThreadingHTTPServer
srv = ThreadingHTTPServer(("127.0.0.1", 0), ds.H); port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
def req(method, path, body=None, cookie=None):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=20)
    h = {"Content-Type": "application/x-www-form-urlencoded"}
    if cookie:
        h["Cookie"] = cookie
    c.request(method, path, body=body, headers=h)
    r = c.getresponse(); b = r.read(); hs = dict(r.getheaders()); c.close()
    return r.status, hs, b
K = ds.TOKEN
check("before a password is set: as today - no key 403, the key opens the page", req("GET", "/history")[0] == 403 and req("GET", "/history?k=" + K)[0] == 200)
SL.set_password("rama", "made-up-test-pass-123")
s, h, b = req("GET", "/")
check("signed out: the address opens the sign-in page", s == 303 and h.get("Location") == "/login" and b"Sign in" in req("GET", "/login")[2])
s, h, b = req("POST", "/login", "u=rama&p=wrong-password")
check("a wrong password: 'wrong username or password', no cookie", s == 401 and b"wrong username" in b and "Set-Cookie" not in h)
s, h, b = req("POST", "/login", urllib.parse.urlencode({"u": "Rama", "p": "made-up-test-pass-123"}))
ck = (h.get("Set-Cookie") or "").split(";")[0]
check("the right password: signed in for 90 days (Secure, HttpOnly cookie)", s == 303 and h.get("Location") == "/" and ck.startswith("gir_s=") and "Max-Age=7776000" in h.get("Set-Cookie", "") and "HttpOnly" in h.get("Set-Cookie", ""))
check("signed in: the page's data opens without the key", req("GET", "/history?k=", cookie=ck)[0] == 200)
bad = ck[:-4] + ("0000" if not ck.endswith("0000") else "1111")
check("a tampered cookie does not open it", req("GET", "/history", cookie=bad)[0] == 403)
s, h, b = req("GET", "/logout", cookie=ck)
check("sign out clears the cookie", s == 303 and "Max-Age=0" in h.get("Set-Cookie", ""))
for _ in range(8):
    SL.check("rama", "nope", "9.9.9.9")
check("8 wrong tries from one address: that address waits 15 min (even with the right password)", SL.check("rama", "made-up-test-pass-123", "9.9.9.9") == "locked")
SL.signout_all()
check("'sign out everywhere': the old cookie no longer opens the page", req("GET", "/history", cookie=ck)[0] == 403)
check("the old key keeps working (GIR's own tools use it)", req("GET", "/history?k=" + K)[0] == 200)
srv.shutdown(); shutil.rmtree(T)
print("P167 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cat > $W/p167_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p167_patch.py - PATCH 167: the page server accepts the website's sign-in (sitelogin.py) as well as the old key; /login, /logout.
Usage: python3 p167_patch.py /home/globalbot/intraday"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
E = [
 ('class H(BaseHTTPRequestHandler):\n', '''def _site_on():                                                  # patch 167: the website's sign-in is set up
    try:
        import sitelogin
        return sitelogin.configured()
    except Exception:
        return False


def _site_ok(h):
    try:
        import sitelogin
        return sitelogin.configured() and sitelogin.cookie_ok(h.headers.get("Cookie") or "")
    except Exception:
        return False


class H(BaseHTTPRequestHandler):
'''),
 ('''    def log_message(self, *a):
        pass
''', '''    def log_message(self, *a):
        pass

    def redirect(self, to, cookie=None):                         # patch 167
        self.send_response(303)
        self.send_header("Location", to)
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def site_login(self):
        import sitelogin
        n = int(self.headers.get("Content-Length") or 0)
        f = parse_qs(self.rfile.read(min(n, 4000)).decode("utf-8", "replace"))
        ip = (self.headers.get("X-Forwarded-For") or self.client_address[0]).split(",")[0].strip()
        r = sitelogin.check((f.get("u") or [""])[0], (f.get("p") or [""])[0], ip)
        if r is True:
            return self.redirect("/", sitelogin.make_cookie())
        time.sleep(1.0)
        return self.send(429 if r == "locked" else 401, sitelogin.page("too many tries - wait 15 minutes" if r == "locked" else "wrong username or password"),
                         "text/html; charset=utf-8")
'''),
 ('''    def do_GET(self):
        u = urlparse(self.path)
        k = (parse_qs(u.query).get("k") or [""])[0]
        if not hmac.compare_digest(k.encode(), TOKEN.encode()):
            return self.send(403, "forbidden", "text/plain")
''', '''    def do_GET(self):
        u = urlparse(self.path)
        k = (parse_qs(u.query).get("k") or [""])[0]
        if not hmac.compare_digest(k.encode(), TOKEN.encode()) and not _site_ok(self):   # patch 167: the key, or signed in on the website
            if _site_on() and u.path in ("/", "/login", "/tomorrow", "/logout"):
                import sitelogin
                if u.path == "/login":
                    return self.send(200, sitelogin.page(), "text/html; charset=utf-8")
                return self.redirect("/login")
            return self.send(403, "forbidden", "text/plain")
        if u.path == "/logout":
            return self.redirect("/login", "gir_s=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax")
        if u.path == "/login":
            return self.redirect("/")
'''),
 ('''    def do_POST(self):
        u = urlparse(self.path)
        k = (parse_qs(u.query).get("k") or [""])[0]
        if not hmac.compare_digest(k.encode(), TOKEN.encode()):
            return self.send(403, "forbidden", "text/plain")
''', '''    def do_POST(self):
        u = urlparse(self.path)
        if u.path == "/login" and _site_on():                    # patch 167
            return self.site_login()
        k = (parse_qs(u.query).get("k") or [""])[0]
        if not hmac.compare_digest(k.encode(), TOKEN.encode()) and not _site_ok(self):
            return self.send(403, "forbidden", "text/plain")
'''),
]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
if "patch 167" in s:
    print("patch 167 is already in dashserve.py"); sys.exit(0)
for a, b in E:
    if s.count(a) != 1:
        print("ANCHOR x%d: %s" % (s.count(a), a[:60])); sys.exit(1)
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("dashserve.py: the website sign-in (the old key still works)")
PY_PATCH
cp $D/dashserve.py $D/dashserve.py.bak$TS
R=$(python3 $W/p167_patch.py $D) || { echo "   $R - nothing was changed"; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile dashserve.py sitelogin.py || { cp $D/dashserve.py.bak$TS $D/dashserve.py; echo "   does not compile - old file back"; exit 1; }
if timeout 200 python3 p167test.py > /tmp/p167test.log 2>&1; then echo "   p167test.py passed (10 checks: sign-in, wrong password, tampered cookie, lock-out, sign-out)"; else
  echo "   TEST FAILED - old file back:"; grep -E "FAIL|Error" /tmp/p167test.log | head -5 | sed 's/^/     /'; cp $D/dashserve.py.bak$TS $D/dashserve.py; exit 1; fi
if python3 -c "import sys; sys.path.insert(0,'$D'); import sitelogin; sys.exit(0 if sitelogin.configured() else 1)"; then
  echo "   a password is already set (to change it: cd $D && python3 sitelogin.py set <username>)"
else
  echo "   choose your sign-in for the website (the password is typed twice and never shown; at least 10 characters)"
  read -p "   username: " U
  until python3 $D/sitelogin.py set "$U"; do echo "   again:"; done
fi
systemctl restart gir-dash && sleep 6
echo "== 4. https with the padlock (Caddy)"
command -v caddy >/dev/null || { apt-get update -qq && apt-get install -y -qq caddy >/dev/null; }
command -v caddy >/dev/null && echo "   caddy $(caddy version | cut -d' ' -f1)" || { echo "   caddy could not be installed - send this to Claude"; exit 1; }
if ufw status 2>/dev/null | grep -q "Status: active"; then ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; echo "   firewall: 80 and 443 opened"; fi
mkdir -p /etc/caddy
[ -f /etc/caddy/Caddyfile ] && cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak$TS
cat > /etc/caddy/Caddyfile <<CADDY
$NAMES {
	reverse_proxy 127.0.0.1:8090 {
		flush_interval -1
	}
	header {
		Strict-Transport-Security "max-age=31536000"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "same-origin"
		-Server
	}
}
CADDY
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 || { echo "   the Caddy settings are not valid - send this to Claude"; exit 1; }
systemctl enable caddy >/dev/null 2>&1; systemctl restart caddy
echo -n "   getting the certificate"
OK=0; for i in $(seq 1 36); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 https://$DOM/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
if [ $OK = 0 ]; then
  echo "   https://$DOM does not answer yet. The old address still works. Likely: DigitalOcean's firewall (Networking -> Firewalls) blocks 80/443."
  journalctl -u caddy -n 6 --no-pager 2>/dev/null | cut -c1-200 | sed 's/^/     /'; echo "   send this to Claude"; exit 1; fi
echo "   ✅ https://$DOM answers with the padlock"
echo "== 5. the old address closed, Telegram's link moved"
echo "https://$DOM" > $D/dash_host.txt
cp $D/engine2.py $D/engine2.py.bak$TS
python3 - <<PY
p = "$D/engine2.py"; s = open(p, encoding="utf-8").read()
a = '    return "http://%s:%s/?k=%s" % (ip, v.get("dash_port", 8090), open(p).read().strip())'
if "patch 167" not in s and s.count(a) == 1:
    s = s.replace(a, '    if ip.startswith("https://"):                                   # patch 167: the website - its sign-in page, no key in the link\n        return ip.rstrip("/") + "/"\n' + a)
    open(p, "w", encoding="utf-8").write(s); print("   the morning Telegram link -> https://$DOM/")
PY
python3 -m py_compile $D/engine2.py || { echo "   engine2.py does not compile - restoring"; cp $D/engine2.py.bak$TS $D/engine2.py 2>/dev/null; }
if grep -q 'ThreadingHTTPServer(("0.0.0.0", port), H)' $D/dashserve.py; then
  sed -i 's/ThreadingHTTPServer(("0.0.0.0", port), H)/ThreadingHTTPServer(("127.0.0.1", port), H)   # patch 167: only through the https website/' $D/dashserve.py
  systemctl restart gir-dash && sleep 6
  c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$DOM/login)
  if [ "$c" = "200" ]; then echo "   http://$IP:8090 closed to the outside - GIR is only at https://$DOM"; else
    sed -i 's/ThreadingHTTPServer(("127.0.0.1", port), H)   # patch 167: only through the https website/ThreadingHTTPServer(("0.0.0.0", port), H)/' $D/dashserve.py
    systemctl restart gir-dash; echo "   the site stopped answering after closing 8090 - reopened, send this to Claude"; fi
fi
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -lt 0900 ] || [ "$H" -gt 1535 ] || [ "$(TZ=Asia/Kolkata date +%u)" -gt 5 ]; then systemctl restart gir-intraday && echo "   engine restarted (the new link from tomorrow's morning message)"; else echo "   the engine takes the new link at its next restart"; fi
rm -rf $W
echo
echo "PATCH 167 APPLIED. Open https://$DOM on the phone and the laptop, sign in once, and save it to the home screen."
