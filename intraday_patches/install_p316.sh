#!/bin/bash
# PATCH 316 - THE PAGE CHECK FILE (Rama, 15 Nov: "click each and every page and information and check how ugly it is, on the mobile and the
#   laptop"). Claude cannot open GIR's pages (they are behind your sign-in, and the key / password never go in the chat), so:
#   pagecheck.py (READ ONLY) starts a private copy of the page server on this machine's own loopback, reads every page (home, cockpit,
#   checklist, today) and every feed they use (+ the share page's feeds for tonight's top checklist shares and MANAPPURAM), takes out
#   positions, P&L, orders, trades and the trade ledger, replaces the key with KEY, and saves one file: data/pagecheck.json.
#   dashserve.py: /pagecheck.json downloads it (signed in only). Restarts the dashboard, then makes the file once.
#   Then on the phone: girtrader.com/pagecheck.json -> download -> attach it in the chat with Claude. It never goes on GitHub.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "dashserve.py: the cockpit route not found - nothing done, send this to Claude"; exit 1; }
F="dashserve.py"
cp $D/dashserve.py $D/dashserve.py.bak$TS
back(){ cp $D/dashserve.py.bak$TS $D/dashserve.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/pagecheck.py <<'PY_PC'
#!/usr/bin/env python3
"""pagecheck.py - patch 316: READ ONLY. One file with GIR's pages and a snapshot of every feed they read, so Claude can open every screen at
phone and laptop sizes with GIR's real code and today's data (Rama, 15 Nov: "click each and every page and check how ugly it is").
  · a private copy of the page server on this machine's own loopback (127.0.0.1, a free port) - nothing outside is touched, nothing is written
    except data/pagecheck.json; the live stream and anything that writes (ledger, watch, ask) are skipped
  · positions, P&L, orders, trades, holdings and the trade ledger are removed; the page key never appears in the file
python3 pagecheck.py [SYM SYM ...]     (no names: tonight's top checklist shares + MANAPPURAM)
then on the phone (signed in): girtrader.com/pagecheck.json -> download -> attach it in the chat with Claude"""
import os, re, sys, json, time, threading, urllib.request, urllib.parse
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
OUT = os.path.join(D, "data", "pagecheck.json")
PRIV = re.compile(r"(^|_)(pos|positions|pnl|mypnl|myfo|my_fo|ledger|orders?|trades?|holdings?|account|acct|statement|funds|margin|tradebook)(_|$)", re.I)
PAGES = ["/", "/cockpit", "/checklist", "/today"]
FEEDS = ["/home", "/market", "/panels", "/three", "/cockpitdata", "/checklistdata", "/checklistlive", "/brief", "/wind", "/pushpull", "/flow",
         "/early", "/react", "/results", "/signstate", "/ixhist?n=NIFTY", "/ixhist?n=BANKNIFTY", "/ixhist?n=SENSEX", "/ixhist?n=VIX",
         "/chart?sym=NIFTY50", "/hist?sym=NIFTY50&days=2", "/hist?sym=NIFTY50&days=3"]
PER_SYM = ["/focus?sym=%s", "/chk?sym=%s&peek=1", "/chart?sym=%s", "/live?sym=%s", "/oi?sym=%s", "/hist?sym=%s&days=30", "/hist?sym=%s&days=60",
           "/hist?sym=%s&days=120"]
CAP = 4_000_000                                          # one feed at most 4 MB in the file


def scrub(v):
    if isinstance(v, dict):
        return {k: scrub(x) for k, x in v.items() if not PRIV.search(str(k))}
    if isinstance(v, list):
        return [scrub(x) for x in v]
    return v


def syms_default():
    try:
        J = json.load(open(os.path.join(D, "data", "checklist.json")))
        L = [x["s"] for k in ("pe", "ce", "retest", "breakout") for x in (J.get(k) or [])]
    except Exception:
        L = []
    out = []
    for s in L + ["MANAPPURAM"]:
        if s not in out:
            out.append(s)
    return out[:5]


def main():
    import dashserve
    from http.server import HTTPServer
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    srv = HTTPServer(("127.0.0.1", 0), dashserve.H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % srv.server_address[1]
    syms = [s.upper() for s in sys.argv[1:] if re.fullmatch(r"[A-Za-z0-9&\-]{1,20}", s)] or syms_default()
    paths = PAGES + FEEDS + [p % urllib.parse.quote(s) for s in syms for p in PER_SYM]
    res, n_ok, size = {}, 0, 0
    for p in paths:
        url = base + p + ("&" if "?" in p else "?") + "k=" + urllib.parse.quote(tok)
        t0 = time.time()
        try:
            r = urllib.request.urlopen(url, timeout=40)
            st, ct, b = r.status, r.headers.get("Content-Type", ""), r.read(CAP + 1)
        except urllib.error.HTTPError as e:
            st, ct, b = e.code, e.headers.get("Content-Type", ""), e.read(2000)
        except Exception as e:
            st, ct, b = 0, "error", str(e)[:200].encode()
        txt = b[:CAP].decode("utf-8", "replace")
        if tok:
            txt = txt.replace(tok, "KEY")
        body = txt
        if "json" in ct:
            try:
                body = scrub(json.loads(txt))
            except Exception:
                pass
        res[p] = {"status": st, "ct": ct, "ms": int((time.time() - t0) * 1000), "cut": len(b) > CAP, "body": body}
        n_ok += st == 200
        size += len(txt)
        print("  %-32s %s  %7.0f KB" % (p[:32], st, len(txt) / 1024), flush=True)
    srv.shutdown()
    J = {"made": time.strftime("%Y-%m-%d %H:%M:%S"), "syms": syms, "feeds": res,
         "note": "GIR pages + feeds for a layout check - positions, P&L, orders and the ledger removed; the key replaced by KEY"}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    s = json.dumps(J, separators=(",", ":"), default=str)
    if tok:
        s = s.replace(tok, "KEY")
    open(OUT + ".tmp", "w", encoding="utf-8").write(s)
    os.replace(OUT + ".tmp", OUT)
    print("saved data/pagecheck.json · %d of %d read · %.1f MB · shares %s" % (n_ok, len(paths), len(s) / 1e6, ", ".join(syms)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PC
cp $W/pagecheck.py $D/pagecheck.py || back
python3 - $D <<'PY_EDIT' || back
import os, sys
D = sys.argv[1]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 316" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/pagecheck.json":           # patch 316: the page check file (pagecheck.py) - a download, signed in only
                try:
                    b_ = open(os.path.join(BASE, "data", "pagecheck.json"), "rb").read()
                except Exception:
                    return self.send(404, b"not made yet - on the server: python3 /home/globalbot/intraday/pagecheck.py", "text/plain; charset=utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Disposition", 'attachment; filename="gir_pagecheck.json"')
                self.send_header("Content-Length", str(len(b_)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(b_)
                return
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /pagecheck.json (a download, signed in only)")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py pagecheck.py || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== making the page check file (1-3 minutes)"
cd $D && timeout 900 python3 pagecheck.py || { echo "❌ the page check file could not be made - send this to Claude"; exit 1; }
echo "✅ patch 316 done - on the phone, signed in: girtrader.com/pagecheck.json -> download -> attach it in the chat with Claude."
echo "   again any time: python3 $D/pagecheck.py · undo: cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/pagecheck.py $D/data/pagecheck.json; systemctl restart gir-dash"
