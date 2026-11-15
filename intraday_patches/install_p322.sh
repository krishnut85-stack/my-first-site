#!/bin/bash
# PATCH 322 - KEEP GIR OUT OF GOOGLE + ONE MORE SAFETY HEADER (Rama, 15 Nov: "the app is showing in Google - I don't want anyone to jack the
#   website"). The web server (Caddy) now: answers /robots.txt with "User-agent: * / Disallow: /" (every search engine: stay out), sends
#   "X-Robots-Tag: noindex, nofollow, noarchive" on every page (a search engine that already saw it drops it), and "X-Content-Type-Options:
#   nosniff". Already there (patch 167): https only, Strict-Transport-Security, no framing by other sites, no referrer to other sites, the
#   password kept as a salted hash, 8 wrong tries -> 15 min lock, the sign-in cookie HttpOnly + Secure. Edits /etc/caddy/Caddyfile only
#   (checked with "caddy validate" first - the old file comes back on any problem). Reloads Caddy (no downtime). GIR's pages untouched.
set -u
C=/etc/caddy/Caddyfile; TS=$(date +%m%d%H%M%S)
[ -f $C ] || { echo "no $C - nothing done, send this to Claude"; exit 1; }
if grep -q "patch 322" $C; then echo "patch 322 - already in"; exit 0; fi
grep -q -- "-Server" $C || { echo "$C: the header block (patch 167) not found - nothing done, send this to Claude"; exit 1; }
cp $C $C.bak$TS
back(){ cp $C.bak$TS $C; systemctl reload caddy 2>/dev/null; echo "❌ old Caddy settings back - nothing changed"; exit 1; }
python3 - $C <<'PY_EDIT' || back
import sys, re
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
if s.count("-Server") != 1:
    print("❌ -Server found %d times" % s.count("-Server")); sys.exit(1)
s = s.replace("\t\t-Server", '\t\tX-Robots-Tag "noindex, nofollow, noarchive"\n\t\tX-Content-Type-Options "nosniff"\n\t\t-Server', 1)
m = re.search(r"^(\S[^\n]*)\{\s*$", s, re.M)
if not m:
    print("❌ the site block not found"); sys.exit(1)
add = "\n\t# patch 322: every search engine - stay out\n\t@robots path /robots.txt\n\trespond @robots `User-agent: *\nDisallow: /\n` 200\n"
s = s[:m.end()] + add + s[m.end():]
open(p, "w", encoding="utf-8").write(s); print("  Caddyfile: robots.txt (stay out) · X-Robots-Tag noindex · nosniff")
PY_EDIT
caddy validate --config $C --adapter caddyfile >/tmp/p322.val 2>&1 || { tail -3 /tmp/p322.val; back; }
echo "  the new settings checked ✓"
systemctl reload caddy || back
sleep 3
DOM=$(grep -m1 -oE "^[a-z0-9.-]+\.[a-z]+" $C)
R=$(curl -s --max-time 15 "https://$DOM/robots.txt" | tr '\n' ' ')
H=$(curl -s -o /dev/null -D - --max-time 15 "https://$DOM/login" | grep -i "^x-robots-tag" | tr -d '\r')
echo "  https://$DOM/robots.txt -> $R"
echo "  https://$DOM/login -> ${H:-no X-Robots-Tag seen}"
case "$R" in *"Disallow: /"*) ;; *) echo "❌ robots.txt not answering as expected"; back;; esac
echo "✅ patch 322 done - search engines told to stay out of $DOM (robots.txt + noindex on every page). GIR works as before."
echo "   undo: cp $C.bak$TS $C; systemctl reload caddy"
