#!/bin/bash
# PATCH 336 - 🩺 GIR DOCTOR: THE WHOLE-SYSTEM CHECK (Rama, 16 Nov: "we did a lot of clean-up, modifications and rework - recheck the complete
#   system for bugs, errors and communication bugs with Kite or anything else").
#   girdoctor.py (READ ONLY - changes nothing, sends nothing): every gir-* service and timer (+ caddy) · the last 24 h of every log, errors
#   counted and shown, KITE token / rate-limit / network / quote / order errors counted · is Kite's data fresh (live prices, chain readings,
#   index desk) · every data file's age · every feed the pages read, called on this server · data sanity (missing prices, volume all 0,
#   futures OI jumps of 40%+, NSE ban / pre-open / close files, results without a verdict) · disk, memory, load.
#   Keys, tokens, passwords and chat ids never appear: every value in .env and anything that looks like a token is blanked.
#   The report: data/doctor.txt - download on the phone (signed in): girtrader.com/doctor.txt. dashserve.py gets that download.
#   Tested on made-up logs and secrets (all blanked). Restarts the dashboard. Prints the problems found.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 336" $D/dashserve.py && [ -f $D/girdoctor.py ]; then echo "patch 336 - already in - running the doctor:"; cd $D && timeout 300 python3 girdoctor.py; exit 0; fi
grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "dashserve's route not found - nothing done, send this to Claude"; exit 1; }
cp $D/dashserve.py $D/dashserve.py.bak$TS
back(){ cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/girdoctor.py; systemctl restart gir-dash 2>/dev/null; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/girdoctor.py <<'PY_DOC'
#!/usr/bin/env python3
"""girdoctor.py - patch 336: READ ONLY. THE WHOLE-SYSTEM CHECK (Rama, 16 Nov: "we did a lot of clean-up, modifications and rework - recheck the
complete system for bugs, errors and communication bugs with Kite or anything else").
  1 SERVICES   every gir-* service and timer (+ caddy): running / failed, restarts, since when
  2 LOGS       the last N hours of each service's log: errors counted, the distinct ones shown; KITE: token, rate limit (429), network /
               time-outs, order or quote errors counted on their own
  3 KITE DATA  is the data from Kite fresh: the last tick, today's chain readings, the index desk - judged against market hours
  4 FILES      every data file GIR writes: when it was last written
  5 FEEDS      every feed the pages read, called on this server: answers, time taken, size, an "err" inside
  6 SANITY     prices missing, volume all 0, futures OI jumps of 40%+ (lot changes), NSE ban / pre-open / close-file read, results read
  7 MACHINE    disk, memory, load
Nothing is changed, nothing is sent. Keys, tokens, passwords and chat ids never appear: every value in /home/globalbot/.env and anything that
looks like a token is blanked. Saves data/doctor.txt (download: girtrader.com/doctor.txt, signed in).
python3 girdoctor.py [hours]        (default 24)"""
import os, re, sys, json, time, glob, sqlite3, subprocess, urllib.request, datetime as dt
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, D)
OUT = os.path.join(D, "data", "doctor.txt")
ENV = "/home/globalbot/.env"
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
L, PROB = [], []
KITE = [("token / login", r"TokenException|access_token|Incorrect .api_key|invalid.*token|session expired|re-?login"),
        ("rate limit 429", r"Too many requests|\b429\b|rate.?limit"),
        ("network / time-out", r"NetworkException|timed? ?out|Max retries|ConnectionError|Connection reset|RemoteDisconnected|Temporary failure in name"),
        ("quote / data", r"DataException|InputException|instrument.*not found|invalid instrument"),
        ("orders", r"OrderException|order.*(rejected|failed)|MarginException")]
ERR = re.compile(r"Traceback|Error\b|Exception|\bfailed\b|\bFAIL\b|CRITICAL|cannot|could not|not read|refused", re.I)


def _secrets():
    s = set()
    try:
        for ln in open(ENV, encoding="utf-8", errors="ignore"):
            if "=" in ln and not ln.lstrip().startswith("#"):
                v = ln.split("=", 1)[1].strip().strip('"').strip("'")
                if len(v) >= 6:
                    s.add(v)
    except Exception:
        pass
    try:
        import dashserve
        t = str(getattr(dashserve, "TOKEN", "") or "")
        if len(t) >= 6:
            s.add(t)
    except Exception:
        pass
    return sorted(s, key=len, reverse=True)


SEC = []
TOKRE = [re.compile(r"\b\d{6,12}:[A-Za-z0-9_-]{25,}\b"),                          # telegram bot tokens
         re.compile(r"(?i)\b(api[_-]?key|api[_-]?secret|access[_-]?token|request[_-]?token|token|secret|password|passwd|bearer|authorization|k)=\S+"),
         re.compile(r"(?i)(bearer|token|authorization)[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9._\-]{8,}"),
         re.compile(r"-100\d{6,}"),                                              # telegram chat ids
         re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"),                                 # e-mail addresses
         re.compile(r"\b[A-Za-z0-9_\-]{28,}\b")]                                 # anything long enough to be a key


def scrub(x):
    x = str(x)
    for v in SEC:
        if v in x:
            x = x.replace(v, "•••")
    for r in TOKRE:
        x = r.sub("•••", x)
    return x


def say(s=""):
    L.append(scrub(s))


def bad(s):
    PROB.append(scrub(s))


def sh(cmd, t=40):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception as ex:
        return "(%s)" % ex


def ist_now():
    return dt.datetime.now(IST)


def market_open(n=None):
    n = n or ist_now()
    return n.weekday() < 5 and "09:15" <= n.strftime("%H:%M") <= "15:30"


def age(ts):
    s = max(0, time.time() - ts)
    return "%ds" % s if s < 120 else "%dm" % (s // 60) if s < 7200 else "%.1fh" % (s / 3600) if s < 172800 else "%.0fd" % (s / 86400)


# ------------------------------------------------------------------ 1 services
def services():
    say("== 1 SERVICES")
    units = sorted(set(re.findall(r"(gir-[\w.@-]+\.(?:service|timer))", sh("systemctl list-units --all --no-legend --plain 'gir-*' 2>/dev/null") +
                                                                          sh("systemctl list-unit-files --no-legend 'gir-*' 2>/dev/null"))))
    units += ["caddy.service"]
    out = []
    for u in units:
        p = dict(re.findall(r"^(\w+)=(.*)$", sh("systemctl show %s -p ActiveState -p SubState -p NRestarts -p ActiveEnterTimestamp -p UnitFileState -p Result" % u), re.M))
        st, sub = p.get("ActiveState", "?"), p.get("SubState", "")
        nr = p.get("NRestarts", "0") or "0"
        line = "  %-28s %-9s %-10s restarts %-3s since %s" % (u, st, sub, nr, (p.get("ActiveEnterTimestamp") or "-")[4:20])
        say(line); out.append(u)
        if st == "failed" or p.get("Result") not in (None, "", "success"):
            bad("SERVICE %s is %s (%s)" % (u, st, p.get("Result")))
        elif u.endswith(".service") and st != "active" and p.get("UnitFileState") == "enabled" and "oneshot" not in sh("systemctl show %s -p Type" % u):
            bad("SERVICE %s is not running (%s/%s)" % (u, st, sub))
        try:
            if int(nr) >= 3:
                bad("SERVICE %s restarted %s times" % (u, nr))
        except Exception:
            pass
    return [u for u in out if u.endswith(".service")]


# ------------------------------------------------------------------ 2 logs
def logs(units, hours):
    say(""); say("== 2 LOGS (last %d hours)" % hours)
    kite = {k: 0 for k, _ in KITE}
    kite_ex = {k: "" for k, _ in KITE}
    for u in units:
        txt = sh("journalctl -u %s --since '%d hours ago' -o cat --no-pager 2>/dev/null | tail -n 20000" % (u, hours), t=60)
        lines = txt.splitlines()
        errs = [l for l in lines if ERR.search(l)]
        for name, rx in KITE:
            hit = [l for l in lines if re.search(rx, l, re.I)]
            kite[name] += len(hit)
            if hit and not kite_ex[name]:
                kite_ex[name] = "%s: %s" % (u, hit[-1].strip()[:160])
        if not lines:
            continue
        dist = {}
        for l in errs:
            k = re.sub(r"\d+", "#", l.strip())[:110]
            dist.setdefault(k, [0, l.strip()])[0] += 1
        say("  %-28s %6d lines · %d error lines%s" % (u, len(lines), len(errs), "" if errs else " ✓"))
        for k, (n, ex) in sorted(dist.items(), key=lambda x: -x[1][0])[:5]:
            say("      ×%-4d %s" % (n, ex[:170]))
        if len(errs) >= 20:
            bad("LOGS %s: %d error lines in %dh - top: %s" % (u, len(errs), hours, sorted(dist.items(), key=lambda x: -x[1][0])[0][1][1][:120]))
    say("  KITE in the logs:")
    for name, _ in KITE:
        say("    %-20s %5d%s" % (name, kite[name], ("   last: " + kite_ex[name]) if kite[name] else ""))
    if kite["token / login"]:
        bad("KITE token / login messages: %d - last: %s" % (kite["token / login"], kite_ex["token / login"][:140]))
    if kite["rate limit 429"] >= 5:
        bad("KITE rate limit hit %d times - too many calls at once" % kite["rate limit 429"])
    if kite["network / time-out"] >= 20:
        bad("KITE / network time-outs: %d" % kite["network / time-out"])
    if kite["orders"]:
        bad("ORDER errors in the logs: %d - last: %s" % (kite["orders"], kite_ex["orders"][:140]))


# ------------------------------------------------------------------ 3 kite data, 6 sanity, 5 feeds (through this server)
def get(path, tok, base="http://127.0.0.1:8090"):
    u = base + path + ("&" if "?" in path else "?") + "k=" + urllib.request.quote(tok)
    t0 = time.time()
    try:
        r = urllib.request.urlopen(u, timeout=40)
        b = r.read()
        return r.status, b, time.time() - t0
    except urllib.error.HTTPError as ex:
        return ex.code, b"", time.time() - t0
    except Exception as ex:
        return 0, str(ex).encode()[:200], time.time() - t0


def feeds(tok):
    say(""); say("== 5 FEEDS (every feed the pages read, on this server)")
    P = ["/", "/cockpit", "/checklist", "/today", "/home", "/market", "/panels", "/three", "/cockpitdata", "/checklistdata", "/checklistlive", "/brief", "/wind",
         "/pushpull", "/flow", "/early", "/react", "/results", "/resultsrecent", "/signstate", "/banstate", "/preopen", "/nextoi?sym=NIFTY", "/nextoi?sym=BANKNIFTY",
         "/ixhist?n=NIFTY", "/ixhist?n=BANKNIFTY", "/ixhist?n=SENSEX", "/ixhist?n=VIX"]
    sym = "RELIANCE"
    P += [p % sym for p in ("/focus?sym=%s", "/chk?sym=%s&peek=1", "/chart?sym=%s", "/live?sym=%s", "/oi?sym=%s", "/nextoi?sym=%s", "/hist?sym=%s&days=30")]
    J = {}
    for p in P:
        st, b, sec = get(p, tok)
        note = ""
        if st == 200 and not p.split("?")[0] in ("/", "/cockpit", "/checklist", "/today"):
            try:
                j = json.loads(b or b"null"); J[p] = j
                if isinstance(j, dict) and j.get("err"):
                    note = "err: " + str(j.get("err"))[:90]
                if j in (None, {}, []):
                    note = "EMPTY"
            except Exception:
                note = "NOT JSON"
        mark = "✓" if st == 200 and not note else "⚠" if st == 200 else "❌"
        say("  %s %-26s %3s %6.2fs %7.1f KB %s" % (mark, p.replace(sym, "SYM"), st, sec, len(b or b"") / 1024, note))
        if st != 200:
            bad("FEED %s answered %s" % (p, st))
        elif sec > 8:
            bad("FEED %s slow: %.1fs" % (p, sec))
        elif note in ("NOT JSON",):
            bad("FEED %s: %s" % (p, note))
    return J


def kitedata(J):
    say(""); say("== 3 DATA FROM KITE (fresh?)")
    n = ist_now(); mo = market_open(n)
    say("  now %s IST · market %s" % (n.strftime("%a %d %b %H:%M"), "OPEN" if mo else "closed"))
    h = J.get("/home") or {}
    say("  /home: day %s · ticks_s %s · chain_as_of %s · desk %s %s" % (h.get("day"), h.get("ticks_s"), h.get("chain_as_of"), h.get("desk_src"), h.get("desk_t")))
    lv = J.get("/live?sym=RELIANCE") or {}
    say("  live price feed (RELIANCE): ok %s · last price tick %s s ago · last OI tick %s s ago" % (lv.get("ok"), lv.get("age_p") if lv.get("age_p") is not None else "—", lv.get("age_o") if lv.get("age_o") is not None else "—"))
    try:
        ap = float(lv.get("age_p")) if lv.get("age_p") is not None else None
    except Exception:
        ap = None
    if mo and (not lv.get("ok") or (ap is not None and ap > 120)):
        bad("KITE live prices stalled in market hours (ok %s, last tick %ss ago)" % (lv.get("ok"), lv.get("age_p")))
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        tabs = {r[0] for r in c.execute("select name from sqlite_master where type='table'")}
        for tb in [x for x in ("chain15", "chain") if x in tabs]:
            d, t = c.execute("select max(d), max(t) from %s where d=(select max(d) from %s)" % (tb, tb)).fetchone()
            nsym = c.execute("select count(distinct sym) from %s where d=?" % tb, (d,)).fetchone()[0]
            say("  chains.db %-7s last %s %s · %d shares" % (tb, d, t, nsym))
            if mo and d != str(n.date()):
                bad("KITE chain readings: none today in %s (last %s)" % (tb, d))
            elif mo and t and t < (n - dt.timedelta(minutes=30)).strftime("%H:%M"):
                bad("KITE chain readings stale: last %s in %s" % (t, tb))
        c.close()
    except Exception as ex:
        say("  chains.db: %s" % ex)
    ix = (J.get("/market") or {}).get("idxd") or {}
    for k in ("NIFTY", "BANKNIFTY"):
        x = ix.get(k) or {}
        say("  index desk %-9s day %s t %s exp %s" % (k, x.get("day"), x.get("t"), x.get("exp")))
        if mo and x.get("day") != str(n.date()):
            bad("INDEX DESK %s not updated today (day %s)" % (k, x.get("day")))


def sanity(J):
    say(""); say("== 6 DATA SANITY")
    tape = (J.get("/home") or {}).get("tape") or []
    if tape:
        nopx = [x["s"] for x in tape if not x.get("px")]
        v0 = sum(1 for x in tape if not x.get("v"))
        jump = [("%s %+.0f%%" % (x["s"], x["foi"])) for x in tape if isinstance(x.get("foi"), (int, float)) and abs(x["foi"]) >= 40]
        say("  tape: %d shares · no price %d · volume 0 on %d · futures OI jumps 40%%+: %s" % (len(tape), len(nopx), v0, ", ".join(jump) or "none"))
        if nopx:
            bad("PRICES missing for %d shares: %s" % (len(nopx), ", ".join(nopx[:10])))
        if v0 >= 0.9 * len(tape):
            bad("VOLUME is 0 for %d of %d shares - traded volume is not being recorded" % (v0, len(tape)))
        if jump:
            bad("FUTURES OI jumps of 40%%+ (lot / contract change - the ₹ crore is wrong for these): %s" % ", ".join(jump[:8]))
    b = J.get("/banstate") or {}
    say("  F&O ban: %s · read %s · %s" % (", ".join(b.get("ban") or []) or "none", b.get("read_at"), "OK" if b.get("ok") else "NOT READ - " + str(b.get("err"))))
    if b and not b.get("ok"):
        bad("NSE BAN list not read now: %s" % b.get("err"))
    p = J.get("/preopen") or {}
    say("  pre-open: %s · %d shares · NSE %s" % ("OK" if p.get("ok") else "NOT READ - " + str(p.get("err")), len(p.get("rows") or []), p.get("nse_t")))
    try:
        fs = sorted(glob.glob(os.path.join(D, "data", "bhav", "20??-??-??.json")))
        say("  NSE close files: last %s (%d kept)" % (os.path.basename(fs[-1])[:10] if fs else "none", len(fs)))
        if fs:
            last = dt.date.fromisoformat(os.path.basename(fs[-1])[:10]); gap = (ist_now().date() - last).days
            if gap > 4:
                bad("NSE CLOSE FILE: the last one is %s (%d days old)" % (last, gap))
    except Exception:
        pass
    r = J.get("/resultsrecent") or {}
    rows = r.get("rows") or []
    nov = [x["s"] for x in rows if not x.get("verdict")]
    say("  results last 7 days: %d F&O shares · without a verdict: %s" % (len(rows), ", ".join(nov) or "none"))
    if rows and len(nov) > len(rows) / 2:
        bad("RESULTS: %d of %d recent results have no verdict - the filing reader may be failing" % (len(nov), len(rows)))
    n = J.get("/nextoi?sym=NIFTY") or {}
    say("  next-month view NIFTY: %s" % ("OK " + str((n.get("nxt") or {}).get("exp")) if n.get("ok") else "NOT OK - " + str(n.get("err"))))


# ------------------------------------------------------------------ 4 files, 7 machine
def files():
    say(""); say("== 4 DATA FILES (last written)")
    pats = ["data/*.json", "data/*.db", "*.db"]
    seen = []
    for p in pats:
        for f in glob.glob(os.path.join(D, p)):
            if os.path.basename(f) in ("pagecheck.json",):
                continue
            seen.append((os.path.getmtime(f), f))
    for m, f in sorted(seen, reverse=True)[:40]:
        say("  %-8s %-38s %8.1f MB" % (age(m), os.path.relpath(f, D), os.path.getsize(f) / 1e6))


def machine():
    say(""); say("== 7 MACHINE")
    du = sh("df -h / | tail -1").split()
    say("  disk: %s used of %s (%s)" % (du[2] if len(du) > 4 else "?", du[1] if len(du) > 4 else "?", du[4] if len(du) > 4 else "?"))
    try:
        if int(du[4].rstrip("%")) >= 85:
            bad("DISK %s full" % du[4])
    except Exception:
        pass
    mem = sh("free -m | sed -n 2p").split()
    say("  memory: %s MB used of %s MB" % (mem[2] if len(mem) > 2 else "?", mem[1] if len(mem) > 1 else "?"))
    say("  load: %s" % sh("cat /proc/loadavg").strip())
    say("  timers:"); [say("    " + x[:150]) for x in sh("systemctl list-timers --all --no-pager 'gir-*' | head -20").splitlines()[1:-3] if x.strip()]


def main():
    global SEC
    hours = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 24
    SEC = _secrets()
    t0 = time.time()
    say("GIR DOCTOR · %s IST · read only · last %d hours" % (ist_now().strftime("%a %d %b %Y %H:%M"), hours))
    tok = ""
    try:
        import dashserve
        tok = str(getattr(dashserve, "TOKEN", "") or "")
    except Exception as ex:
        bad("dashserve could not be read: %s" % ex)
    units = []
    for name, fn in (("services", lambda: services()), ("logs", lambda: logs(units, hours)), ("feeds", lambda: feeds(tok)), ("files", files), ("machine", machine)):
        try:
            r = fn()
            if name == "services":
                units = r or []
            if name == "feeds":
                J = r or {}
                kitedata(J); sanity(J)
        except Exception as ex:
            bad("the %s check itself failed: %s" % (name, ex))
    head = ["", "== PROBLEMS FOUND: %d" % len(PROB)] + ["  ❗ " + p for p in PROB] + ([] if PROB else ["  none ✓"]) + [""]
    txt = "\n".join(L[:1] + head + L[1:]) + "\n\n(%.0fs)\n" % (time.time() - t0)
    txt = scrub(txt)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(txt)
    print("\n".join(L[:1] + head))
    print("full report: data/doctor.txt · on the phone (signed in): girtrader.com/doctor.txt")


if __name__ == "__main__":
    main()
PY_DOC
python3 -m py_compile $W/girdoctor.py || { echo "❌ girdoctor.py did not compile - nothing changed"; exit 1; }
cp $W/girdoctor.py $D/girdoctor.py || back
python3 - $D <<'PY_EDIT' || back
import os, sys
D = sys.argv[1]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 336" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/doctor.txt":               # patch 336: the whole-system check report (girdoctor.py) - signed in only
                try:
                    b_ = open(os.path.join(BASE, "data", "doctor.txt"), "rb").read()
                except Exception:
                    return self.send(404, b"not made yet - on the server: python3 /home/globalbot/intraday/girdoctor.py", "text/plain; charset=utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Disposition", 'attachment; filename="gir_doctor.txt"')
                self.send_header("Content-Length", str(len(b_)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(b_)
                return
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /doctor.txt")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== 🩺 GIR DOCTOR (read only, about a minute)"
cd $D && timeout 300 python3 girdoctor.py
echo "✅ patch 336 done - run it any time: python3 /home/globalbot/intraday/girdoctor.py · the full report: girtrader.com/doctor.txt (signed in)"
echo "   undo: cp $D/dashserve.py.bak$TS $D/dashserve.py; rm -f $D/girdoctor.py; systemctl restart gir-dash"
