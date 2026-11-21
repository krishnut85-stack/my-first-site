#!/usr/bin/env python3
"""girtrace.py - READ ONLY diagnostic (16 Nov): the full crash details behind the GIR doctor's problems, keys and tokens blanked
(girdoctor.scrub). Changes nothing, sends nothing. Run on the server:  python3 girtrace.py [hours]"""
import os, re, sys, json, subprocess, urllib.request, collections
D = os.environ.get("GIRD", "/home/globalbot/intraday")
sys.path.insert(0, D)
import girdoctor as G
G.SEC = G._secrets()
H = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 48
P = lambda s="": print(G.scrub(s))
PRE = re.compile(r"^\S+\s+\S+\s+[\w.@-]+(?:\[\d+\])?:\s?")


def jl(unit, extra=""):
    return subprocess.run("journalctl -u %s --since '%d hours ago' -o short-iso --no-pager %s 2>/dev/null | tail -n 60000" % (unit, H, extra),
                          shell=True, capture_output=True, text=True, timeout=120).stdout.splitlines()


def traces(unit, top=6):
    rows = jl(unit)
    blocks, cur = [], None
    for raw in rows:
        ts = raw[:19]
        m = PRE.match(raw); ln = raw[m.end():] if m else raw
        if "Traceback (most recent call last)" in ln:
            cur = {"t": ts, "l": []}; continue
        if cur is not None:
            cur["l"].append(ln.rstrip())
            if ln and not ln.startswith((" ", "\t")) and re.search(r"(Error|Exception|Exit|Interrupt)\b", ln) and not ln.startswith("During handling"):
                blocks.append(cur); cur = None
            elif len(cur["l"]) > 80:
                cur = None
    by = collections.OrderedDict()
    for b in blocks:
        exc = b["l"][-1] if b["l"] else "?"
        files = [x.strip() for x in b["l"] if x.strip().startswith("File ")]
        key = re.sub(r"\d+", "#", (files[-1] if files else "") + "|" + exc.split(":")[0])
        e = by.setdefault(key, {"n": 0, "first": b["t"], "last": b["t"], "b": b})
        e["n"] += 1; e["last"] = b["t"]; e["b"] = b
    P("== %s · %d crashes (tracebacks) in %dh, %d different" % (unit, len(blocks), H, len(by)))
    for k, e in sorted(by.items(), key=lambda x: -x[1]["n"])[:top]:
        L = e["b"]["l"]
        frames = [i for i, x in enumerate(L) if x.strip().startswith("File ")]
        keep = L[frames[-3]:] if len(frames) >= 3 else L[-12:]
        P("  ×%d  first %s · last %s" % (e["n"], e["first"], e["last"]))
        for x in keep[-14:]:
            P("      " + x[:220])
    P()


def restarts(unit):
    rows = jl(unit)
    ev = [r for r in rows if re.search(r"Main process exited|Failed with result|Scheduled restart job|Started |Stopped |Killed|OOM|oom-kill|status=", r)]
    P("== %s · restart events in %dh: %d" % (unit, H, len(ev)))
    per = collections.Counter(r[:10] for r in ev if "Main process exited" in r)
    P("  exits per day: %s" % dict(per))
    codes = collections.Counter(re.sub(r".*(code=\w+, status=[^ ]+).*", r"\1", r) for r in ev if "Main process exited" in r)
    P("  exit codes: %s" % dict(codes))
    idx = [i for i, r in enumerate(rows) if "Main process exited" in r][-3:]
    for i in idx:
        P("  -- the 12 lines before the exit at %s:" % rows[i][:19])
        for r in rows[max(0, i - 12):i + 1]:
            m = PRE.match(r); P("      " + (r[m.end():] if m else r)[:220])
    P()


def tail(unit, n=30):
    P("== %s · its last %d log lines" % (unit, n))
    st = subprocess.run("systemctl show %s -p ActiveState -p Result -p ExecMainStatus -p ExecMainExitTimestamp -p FragmentPath" % unit, shell=True, capture_output=True, text=True).stdout
    P("  " + " · ".join(st.split()))
    for r in jl(unit)[-n:]:
        m = PRE.match(r); P("      " + r[:19] + " " + (r[m.end():] if m else r)[:200])
    P()


def kite429():
    P("== KITE rate limit (429 / too many requests) - which service, when")
    out = subprocess.run("journalctl --since '%d hours ago' -o short-iso --no-pager 2>/dev/null | grep -iE 'too many requests|\\b429\\b' | grep -v crypto | tail -n 15" % H,
                         shell=True, capture_output=True, text=True, timeout=120).stdout.splitlines()
    for r in out:
        P("      " + r[:230])
    P()


def brief():
    P("== /brief (the page's TOMORROW / brief feed)")
    try:
        import dashserve
        tok = str(getattr(dashserve, "TOKEN", "") or "")
        r = urllib.request.urlopen("http://127.0.0.1:8090/brief?k=" + urllib.request.quote(tok), timeout=40)
        b = r.read()
        P("  status %s · type %s · %d bytes" % (r.status, r.headers.get("Content-Type"), len(b)))
        P("  starts: %r" % b[:400].decode("utf-8", "replace"))
        P("  ends:   %r" % b[-200:].decode("utf-8", "replace"))
        try:
            json.loads(b); P("  valid JSON now")
        except Exception as ex:
            P("  JSON error: %s" % ex)
    except Exception as ex:
        P("  could not call it: %s" % ex)
    P()


if __name__ == "__main__":
    P("GIRTRACE · read only · last %d hours" % H); P()
    restarts("gir-intraday")
    for u in ("gir-intraday", "gir-dash", "gir-desk", "gir-exchange", "gir-newsroom", "gir-windwatch"):
        traces(u)
    tail("gir-fullaudit", 25)
    kite429()
    brief()
    P("(end)")
