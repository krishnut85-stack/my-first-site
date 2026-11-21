#!/bin/bash
# PATCH 133 - WHY IS IT MOVING (on top of patch 132c).
#   When an F&O share moves, the reasons GIR already holds, ranked: its results (GIR's read), filings, the news GIR checked,
#   a broker's call, its sector / NIFTY moving the same way (or "on its own"), the futures money, calls / puts bought, results
#   due soon, a company event today. Nothing company-level found is said too. Local reads only, a minute's cache.
#   - the share card: WHY IT IS MOVING (the line + every reason, ▲ / ▼)
#   - Telegram: a "🔎 why:" line under 🚀 RUNNING · ⚡ SPEED / FIRST MOVE · 🌅 GAP · 📈 MOVER · 🧩 OI alerts (news alerts are the reason)
#   whymove.py (new) · engine2.py, dashserve.py, home.html (exact anchors). Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g133; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p133.sh now"; exit 1; fi
grep -q "patch 132c" $D/dashserve.py 2>/dev/null || { echo "patch 132c is not installed yet - paste patch 132c first"; exit 1; }
[ -f $D/whymove.py ] && { echo "patch 133 is already installed"; exit 1; }
F="engine2.py dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/whymove.py $D/p133test.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p133_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p133_patch.py - PATCH 133: WHY IS IT MOVING (whymove.py) on the share card and under the move / OI alerts on Telegram.
Usage: python3 p133_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''        silent_ = False; log("alertword: %s" % str(ex)[:80])''', '''        silent_ = False; log("alertword: %s" % str(ex)[:80])
    try:                                                        # patch 133: a "🔎 why:" line under the move / OI alerts
        import whymove
        text = whymove.add_line(text)
    except Exception as ex:
        log("whymove: %s" % str(ex)[:80])'''),
    ],
    "dashserve.py": [
        ('''        c["ev"] = events.for_sym(sym)
    except Exception:
        pass
    return c''', '''        c["ev"] = events.for_sym(sym)
    except Exception:
        pass
    try:                                                        # patch 133: WHY IS IT MOVING
        import whymove
        c["why"] = whymove.explain(sym)
    except Exception:
        pass
    return c'''),
    ],
    "home.html": [
        ('''  return `<div class="shi"><div><small>FUTURES</small>''',
         '''  const W=c&&c.why&&c.why.line?c.why:null;      /* patch 133: WHY IS IT MOVING */
  const whyH=W?`<div style="grid-column:1/-1"><small>WHY IT IS MOVING${W.chg!=null?` · ${W.chg>0?"▲":"▼"} ${pc(W.chg)}`:""}</small><b>${esc(W.line)}</b>${(W.reasons||[]).length>1?`<br>${W.reasons.slice(0,7).map(r=>`<span class="${r.side>0?"pu":r.side<0?"pd":"dim"}">${r.side>0?"▲":r.side<0?"▼":"·"}</span> ${esc(r.t)}`).join("<br>")}`:""}</div>`:"";
  return `<div class="shi">${whyH}<div><small>FUTURES</small>'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
cat > $W/whymove.py <<'PY_WHY'
#!/usr/bin/env python3
"""whymove.py - patch 133: WHY IS IT MOVING. When an F&O share moves, the reasons GIR already holds, ranked, in one line:

  results     the company's results filed in the last 3 days (GIR's read: BEAT / MISS / IN LINE, the numbers)
  filings     an order, a regulator's action, a board decision, a rating (NSE, last 2 days)
  news        the news GIR checked and sent (the reader's sentence), last 36 h
  brokers     a broker's call in the news (target, upgrade, downgrade ...), last 3 days
  sector      its NSE sector moving the same way ("moving with the sector") - or not ("on its own")
  market      NIFTY moving the same way; the day's market headline when nothing company-level is found
  money       the futures build-up (₹ crore of fresh money), calls / puts being bought
  calendar    results due in the next 2 days (positioning), a company event today
Nothing company-level found is said too: "no company news found - the market / the money only".
Local reads only (no website is asked), cached a minute per share - safe inside the engine's alert path.

  share card      WHY IT IS MOVING (the line + every reason)
  Telegram        a "🔎 why:" line under 🚀 RUNNING · ⚡ SPEED / FIRST MOVE · 🌅 GAP · 📈 MOVER · 🧩 OI alerts
  python3 whymove.py VOLTAS        the reasons for one share now"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
_C = {}
_F = {"state": (0.0, {}), "sec": (0.0, {}), "q": (0.0, {})}
BROKER_RX = re.compile(r"\btarget\b|upgrade|downgrade|\bbuy\b.*\b(?:call|rating)\b|\bsell\b.*\b(?:call|rating)\b|overweight|underweight|outperform|underperform|"
                       r"initiat\w* coverage|reiterat|price target|brokerage|motilal|jefferies|morgan stanley|goldman|nomura|clsa|jp ?morgan|citi\b|macquarie|"
                       r"bernstein|\bubs\b|hsbc|kotak institutional|nuvama|emkay|icici securities|axis capital|antique|investec|bofa|elara", re.I)
MOVE_K = ("🚀", "⚡", "🌅", "📈", "🧩", "🔭", "🔎")


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def _state():
    t, v = _F["state"]
    if time.time() - t < 30:
        return v
    try:
        v = json.load(open(os.path.join(BASE, "dash_state.json")))
    except Exception:
        v = {}
    _F["state"] = (time.time(), v)
    return v


def _quotes():
    t, v = _F["q"]
    if time.time() - t < 10:
        return v
    try:
        v = (json.load(open(os.path.join(BASE, "quotes_live.json"))) or {}).get("q") or {}
    except Exception:
        v = {}
    _F["q"] = (time.time(), v)
    return v


def _sectors(universe):
    t, v = _F["sec"]
    if time.time() - t < 600 and v:
        return v
    try:
        import nsesec
        v = nsesec.page_map(set(universe)) or {}
    except Exception:
        v = {}
    _F["sec"] = (time.time(), v)
    return v


def _move(sym):
    q = _quotes().get(sym) or []
    f = next((x for x in _state().get("fo_paths") or [] if x.get("s") == sym), {}) or {}
    px = (q[0] if q else None) or f.get("px")
    chg = (q[1] if len(q) > 1 else None)
    if chg is None:
        chg = f.get("chg")
    return px, chg, f


def explain(sym, now=None):
    """-> {"s", "px", "chg", "dir", "reasons": [{"k", "t", "w", "side"}], "line", "stock": bool (a company-level reason found)}"""
    sym = (sym or "").upper()
    c = _C.get(sym)
    if c and time.time() - c[0] < 60 and now is None:
        return c[1]
    now = now or dt.datetime.now(IST)
    px, chg, f = _move(sym)
    d = 1 if (chg or 0) > 0 else -1 if (chg or 0) < 0 else 0
    R = []
    add = lambda k, t, w, side=0: R.append({"k": k, "t": t, "w": w, "side": side})
    # results
    try:
        import exchange
        rr = exchange.results_read(sym, 72)
        if rr:
            big = bool((rr.get("read") or {}).get("big"))
            add("results", "results %s%s (%s): %s" % ("BIG " if big else "", rr["verdict"], rr["when"], re.sub(r"\s*\((consolidated|standalone)[^)]*\)", "", rr.get("line") or "")[:150]),
                6 if big else 5, int(rr.get("side") or 0))
    except Exception:
        pass
    # filings (not results)
    try:
        con = _ro("filings.db")
        for kind, side, subj, det, te in con.execute("select kind, side, subject, detail, t_exch from filings where sym=? and t_exch>? and kind in "
                                                     "('ORDER','REG','BOARD','SALES','RATING','MGMT') order by t_exch desc limit 3", (sym, time.time() - 48 * 3600)):
            add("filing", "%s filing (%s): %s" % (kind.lower(), dt.datetime.fromtimestamp(te, IST).strftime("%a %H:%M"), (det or subj or "")[:130]), 4, int(side or 0))
        con.close()
    except Exception:
        pass
    # the news GIR checked and sent
    try:
        con = _ro("tomorrow.db")
        d0 = str((now - dt.timedelta(hours=36)).date())
        seen = set()
        for day, t, kind, side, text in con.execute("select day, t, kind, side, text from alerts where sym=? and day>=? order by day desc, t desc limit 40", (sym, d0)):
            if kind not in ("📰", "🚨", "📄", "⚡"):
                continue
            L = [x for x in (text or "").split("\n") if x.strip() and not re.match(r"(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|🔔 OPENING \d|⚠ NOT SENT)", x)]   # GIR's own tags are not the news
            head = L[0] if L else ""
            if kind == "⚡" and "NEWS SHOCK" not in head:
                continue
            hl = L[1][:120] if len(L) > 1 else head[:120]
            rd = next((x.split(":", 1)[-1].strip() for x in L if x.startswith("the reader")), "")
            rd = re.sub(r"\s*·\s*(?:CRITICAL|IMPORTANT|MINOR|NOISE)\b.*$", "", rd)            # the reader's level stays out of the line
            k_ = hl[:50].lower()
            if k_ in seen:
                continue
            seen.add(k_)
            sg = 1 if side == "CE" else -1 if side == "PE" else 0
            add("news", "news %s %s: %s%s" % (day[5:], t[:5], hl, (" — " + rd[:110]) if rd else ""), 5 if "CRITICAL" in head else 3, sg)
            if len(seen) >= 3:
                break
        con.close()
    except Exception:
        pass
    # brokers in the news
    try:
        import newsroom
        for it in newsroom.items_for(sym, 72, 0)[:20]:
            if BROKER_RX.search(it.get("h") or ""):
                add("broker", "broker (%s): %s" % (it.get("t"), (it.get("h") or "")[:130]), 3, int(it.get("side") or 0))
                break
    except Exception:
        pass
    # sector and market
    q = _quotes()
    secs = _sectors(q.keys())
    sec = next(((n, s) for n, s in secs.items() if sym in s), None)
    if sec and chg is not None:
        v = [q[s][1] for s in sec[1] if s != sym and s in q and len(q[s]) > 1 and q[s][1] is not None]
        if len(v) >= 2:
            sa = sum(v) / len(v)
            if abs(sa) >= 0.7 and sa * chg > 0:
                add("sector", "the %s sector is %+.1f%% (%d shares) - it moves with its sector" % (sec[0].lower(), sa, len(v)), 2, 1 if sa > 0 else -1)
            elif abs(chg) >= 1.5 and (sa * chg <= 0 or abs(sa) < 0.4):
                add("alone", "on its own - its %s sector is %s" % (sec[0].lower(), "flat" if abs(sa) < 0.05 else "%+.1f%%" % sa), 1, 0)
    nif = ((_state().get("idx") or {}).get("NIFTY") or {}).get("chg")
    if nif is not None and chg is not None and abs(nif) >= 0.6 and nif * chg > 0:
        add("market", "NIFTY %+.1f%% - the whole market" % nif, 1, 1 if nif > 0 else -1)
    # money
    if f.get("bu") and abs(f.get("cr") or 0) >= 5:
        sg = 1 if f["bu"] in ("LONG BUILD-UP", "SHORT COVERING") else -1
        add("money", "%s · futures %s ₹%.0f cr" % (f["bu"].lower(), "bought" if (f.get("cr") or 0) > 0 else "sold", abs(f["cr"])), 2, sg)
    om = next((x for x in _state().get("opt_money") or [] if x.get("s") == sym), None)
    if om and (om.get("rce") or om.get("rpe")):
        add("options", " · ".join(x for x in (("calls " + om["rce"]) if om.get("rce") else "", ("puts " + om["rpe"]) if om.get("rpe") else "") if x), 1, 0)
    # calendar
    try:
        con = _ro("chains.db")
        r = con.execute("select d from results_cal where sym=? and d>=? and d<=? order by d limit 1", (sym, str(now.date()), str(now.date() + dt.timedelta(days=2)))).fetchone()
        con.close()
        if r:
            add("due", "results due %s - money positioning before the numbers" % dt.date.fromisoformat(r[0]).strftime("%a %d %b"), 1, 0)
    except Exception:
        pass
    try:
        import events
        for e in events.for_sym(sym, now)[:1]:
            if e["today"]:
                add("event", "%s %s" % (e["kind"], e["when"]), 1, 0)
    except Exception:
        pass
    stock = any(r["k"] in ("results", "filing", "news", "broker") for r in R)
    if not stock and chg is not None and abs(chg) >= 1:
        try:
            j = json.load(open(os.path.join(BASE, "data", "macro.json")))
            it = max((x for x in j.get("items") or [] if time.time() - float(x.get("t") or 0) < 12 * 3600 and (x.get("score") or 0) >= 5),
                     key=lambda x: x.get("score") or 0, default=None)
            if it and nif is not None and abs(nif) >= 0.4:
                add("global", "market news: %s" % (it.get("h") or "")[:110], 1, 0)
        except Exception:
            pass
        add("none", "no company news found - the market / the money only", 0, 0)
    # rank: what explains this direction first, then the rest
    R.sort(key=lambda r: (-(r["side"] == d and d != 0), -r["w"]))
    against = [r for r in R if d and r["side"] == -d and r["w"] >= 3]
    parts = [r["t"] for r in R if r["side"] in (d, 0) or not d][:4]
    line = " · ".join(p[:100] + ("…" if len(p) > 100 else "") for p in parts)
    if against:
        line += " · ⚠ against: %s" % against[0]["t"][:70]
    out = {"s": sym, "px": px, "chg": chg, "dir": "UP" if d > 0 else "DOWN" if d < 0 else "", "reasons": R, "line": line, "stock": stock}
    if len(_C) > 400:
        _C.clear()
    _C[sym] = (time.time(), out)
    return out


SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")


def add_line(text):
    """a move / OI alert -> the same alert with a "🔎 why:" line (once); any other alert unchanged"""
    try:
        L = (text or "").split("\n")
        head = L[0]
        if head.startswith("🔔 OPENING") and len(L) > 1 and not head.startswith("🔔 OPENING · "):
            head = L[1]
        h2 = head[len("🔔 OPENING · "):] if head.startswith("🔔 OPENING · ") else head
        k = h2.split()[0] if h2.split() else ""
        if k not in MOVE_K or "🔎 why:" in text or "CRITICAL" in h2 or "NEWS" in h2:
            return text
        m = SYM_RX.search(h2)
        if not m:
            return text
        w = explain(m.group(1))
        if not w.get("line"):
            return text
        return text.rstrip("\n") + "\n🔎 why: " + w["line"][:300]
    except Exception:
        return text


if __name__ == "__main__":
    for s in sys.argv[1:] or ["VOLTAS"]:
        w = explain(s)
        print("%s %s %s" % (w["s"], ("%+.2f%%" % w["chg"]) if w["chg"] is not None else "?", w["dir"]))
        print("  WHY: %s" % (w["line"] or "-"))
        for r in w["reasons"]:
            print("   %s %-8s w%d  %s" % ({1: "▲", -1: "▼", 0: "·"}[r["side"]], r["k"], r["w"], r["t"]))
PY_WHY
cat > $D/p133test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p133test.py - WHY IS IT MOVING: a share down on weak results, its sector down too, futures sold -> the reasons in order;
a share up with no company news -> "no company news found"; the "🔎 why:" line under a RUNNING alert (once), never under news;
the share card gets it. Fake files - nothing is fetched or sent."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import whymove, exchange, newsroom, tglanes, alertword
IST = whymove.IST
tmp = tempfile.mkdtemp(prefix="p133")
try:
    whymove.BASE = tmp
    now = dt.datetime.now(IST)
    today = str(now.date())
    json.dump({"t": time.time(), "q": {"VOLTAS": [1290.0, -4.1], "BLUESTARCO": [1800.0, -1.6], "HAVELLS": [1500.0, -1.0], "CROMPTON": [350.0, -0.9],
                                       "YESBANK": [24.3, 2.4], "PNB": [100.0, 0.1], "SBIN": [800.0, -0.2], "CANBK": [110.0, 0.0]}},
              open(os.path.join(tmp, "quotes_live.json"), "w"))
    json.dump({"idx": {"NIFTY": {"last": 24986.4, "chg": -0.18}}, "fo_paths": [{"s": "VOLTAS", "bu": "SHORT BUILD-UP", "cr": -45.0, "px": 1290, "chg": -4.1}],
               "opt_money": [{"s": "VOLTAS", "rpe": "puts bought 1300 PE"}]}, open(os.path.join(tmp, "dash_state.json"), "w"))
    whymove._sectors = lambda u: {"Consumer Durables": ["VOLTAS", "BLUESTARCO", "HAVELLS", "CROMPTON"], "Banks": ["YESBANK", "PNB", "SBIN", "CANBK"]}
    exchange.results_read = lambda sym, hours=40, con=None: ({"verdict": "IN LINE", "side": -1, "line": "profit ₹134 cr, -78% QoQ · margin 4.7%", "read": {"big": False},
                                                              "when": "07 Nov 16:40"} if sym == "VOLTAS" else None)
    newsroom.items_for = lambda sym, hours=96, min_score=0, con=None: ([{"t": "08 Nov 09:10", "h": "Voltas target cut to ₹1,150 by Jefferies, downgrade to underperform", "side": -1}] if sym == "VOLTAS" else [])
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    c.execute("insert into alerts values(?,?,?,?,?,?)", (today, "09:20:00", "📰", "VOLTAS", "PE", "📰 NEWS ▼ VOLTAS · RESULTS · ET 09:20\n🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR\nVoltas Q2 profit falls 78% on weak AC demand\nthe reader (x): a weak quarter, demand soft · IMPORTANT · sure 80%"))
    c.commit(); c.close()
    for f in ("filings.db", "chains.db"):
        sqlite3.connect(os.path.join(tmp, f)).close()
    whymove._C.clear(); whymove._F.update({"state": (0.0, {}), "q": (0.0, {}), "sec": (0.0, {})})
    w = whymove.explain("VOLTAS")
    ks = [r["k"] for r in w["reasons"]]
    check("VOLTAS -4.1%%: the reasons, the ones that explain DOWN first: %s" % ks, ks[:5] == ["results", "news", "broker", "sector", "money"] and w["dir"] == "DOWN" and w["stock"])
    check("the line: %s" % w["line"][:160], w["line"].startswith("results IN LINE (07 Nov 16:40): profit ₹134 cr, -78% QoQ") and "Voltas Q2 profit falls 78%" in w["line"] and "CRITICAL" not in w["line"] and "IMPORTANT" not in w["line"])
    check("the sector read: %s" % next(r["t"] for r in w["reasons"] if r["k"] == "sector"), any(r["k"] == "sector" and "consumer durables sector is -1.2%" in r["t"] for r in w["reasons"]))
    y = whymove.explain("YESBANK")
    check("YESBANK +2.4%%, nothing company-level: %s" % y["line"], not y["stock"] and "on its own" in y["line"] and "no company news found" in y["line"])
    a = whymove.add_line("🚀 RUNNING ▼ VOLTAS ₹1290 -4.1% · 10:05\ncrossed -4%")
    check("RUNNING alert gets one 🔎 why line: %s" % a.split("\n")[-1][:90], a.count("🔎 why:") == 1 and a.split("\n")[-1].startswith("🔎 why: results IN LINE") and whymove.add_line(a) == a)
    n = "📰 NEWS ▼ VOLTAS · RESULTS · ET 09:20\nVoltas Q2 profit falls"
    k = "🚨 CRITICAL NEWS ▼ VOLTAS · REG · x"
    check("news / critical alerts unchanged (the news is the reason)", whymove.add_line(n) == n and whymove.add_line(k) == k)
    o = "🔔 OPENING · 🧩 CALLS BOUGHT ▲ YESBANK ₹24.3 · 09:21"
    check("an opening OI alert gets it too", "🔎 why:" in whymove.add_line(o))
    check("the line does not change the alert's channel or ring (%s / %s)" % (tglanes.lane(a), alertword.tier(a)),
          tglanes.lane(a) == tglanes.lane("🚀 RUNNING ▼ VOLTAS ₹1290 -4.1% · 10:05\ncrossed -4%") and alertword.tier(a) == alertword.tier("🚀 RUNNING ▼ VOLTAS ₹1290 -4.1% · 10:05\ncrossed -4%"))
    import dashserve
    cc = dashserve._ev_add("VOLTAS", {"s": "VOLTAS"})
    check("share card data: why with %d reasons" % len((cc.get("why") or {}).get("reasons") or []), (cc.get("why") or {}).get("line", "").startswith("results IN LINE"))
    pg = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
    check("the page shows WHY IT IS MOVING on the share card", "WHY IT IS MOVING" in pg and "c.why.line" in pg)
    en = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine2.py"), encoding="utf-8").read()
    check("the engine adds the line after the channel and the ring are decided", en.index("text = whymove.add_line(text)") > en.index("text, silent_ = alertword.dress(text)") > en.index("chat = tglanes.chat_for(text, chat)"))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP133 WHY IS IT MOVING TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p133_patch.py $D || { rm -f $D/p133test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/whymove.py $D/
cd $D && python3 -m py_compile whymove.py engine2.py dashserve.py p133test.py || back
timeout 120 python3 p133test.py 2>&1 | grep "OK  \|FAIL\|P133"
timeout 120 python3 p133test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p132ctest.py p132btest.py p132test.py p131test.py p130test.py p130ctest.py p129test.py p128test.py p127test.py p125btest.py p124test.py p123test.py p120test.py p119test.py p113test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 133 APPLIED. Reload the GIR page - open a share: WHY IT IS MOVING is on top of its card. Today's movers, read now:"
cd $D && for s in VOLTAS DIVISLAB DATAPATTNS AMBUJACEM; do timeout 60 python3 whymove.py $s 2>&1 | head -2; done
