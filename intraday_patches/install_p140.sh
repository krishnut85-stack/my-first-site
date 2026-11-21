#!/bin/bash
# PATCH 140 - THE MOVE EXPLAINED (on top of patch 139).
#   Rama, 9 Nov (JUBLFOOD -4%): "this is what I am expecting - think, and even in a doubt, alert me". When an F&O share moves suddenly
#   (crosses ±2.5% on the day, again at ±5%, or ±1.5% inside 15 minutes; 09:20-15:20) GIR sends on its own:
#     🔍 WHY ▼ JUBLFOOD -4.1% ₹433 · 09:42 · CLEAR (a company reason found) / IN DOUBT (none - the market / the money only, said so)
#     main reason · also ... · against it · OI: the battle, who wrote, who gave up · order book · THE READ: who is in control, the levels
#   The WHY reader also says the run-up into the day ("profit-booking after +9.5% in the 5 sessions before") and the 52-week position.
#   It rings, in the 🚀 Moves topic.
#   movealert.py (new), whymove.py (replaced - patch 133's own file) · engine2.py, alertword.py (exact anchors).
#   Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p140.sh now"; exit 1; fi
[ -f $D/resultsdesk.py ] || { echo "patch 139 is not installed yet - paste patch 139 first"; exit 1; }
[ -f $D/movealert.py ] && { echo "patch 140 is already installed"; exit 1; }
F="engine2.py alertword.py whymove.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/movealert.py $D/p140test.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p140_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140_patch.py - PATCH 140: THE MOVE EXPLAINED (movealert.py) - the engine checks every F&O share every 30 s; a sudden move gets a
🔍 WHY alert (CLEAR / IN DOUBT) with the reasons, the OI battle, the order book and the read; whymove gets the run-up into the day and
the 52-week position.
Usage: python3 p140_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "engine2.py": [
        ('''        if nowt - tick.get("book", 0.0) >= 10:               # patch 137: order book pressure, every F&O share''',
         '''        if nowt - tick.get("mvx", 0.0) >= 30:                # patch 140: a sudden move -> 🔍 WHY (its own thread)
            tick["mvx"] = nowt
            try:
                import movealert
                movealert.scan(feed.syms, feed.ltp, feed.pclose, feed.fo_idx, tg_fo)
            except Exception as ex:
                if ("MVX", "fail") not in _said:
                    _said.add(("MVX", "fail"))
                    log("move explained failed:", ex)
        if nowt - tick.get("book", 0.0) >= 10:               # patch 137: order book pressure, every F&O share'''),
    ],
    "alertword.py": [
        ('''    if re.match(r"🔭 (?:NIFTY|BANKNIFTY) OPTIONS", H2):''', '''    if H2.startswith("🔍 WHY"):                                  # patch 140: the move explained rings (something is happening)
        return "move"
    if re.match(r"🔭 (?:NIFTY|BANKNIFTY) OPTIONS", H2):'''),
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
cat > $W/movealert.py <<'PY_MV'
#!/usr/bin/env python3
"""movealert.py - patch 140: THE MOVE EXPLAINED. Rama, 9 Nov (JUBLFOOD -4%): "this is what I am expecting from you - think, and even in a
doubt, alert me". When an F&O share moves suddenly, GIR now says WHY on its own, like a trader at the desk would:

  when      the day's move crosses ±2.5% (once a side a day; again at ±5%) · or ±1.5% inside 15 minutes (45-min cool-off)
            from 09:20 (the open's first minutes are noise) to 15:20 - market hours only (the engine calls it every 30 s)
  what      🔍 WHY ▼ JUBLFOOD -4.1% ₹433 · 09:42 · CLEAR / IN DOUBT
            the main reason (results / filing / news / broker / run-up / sector / market), the next ones,
            THE OI BATTLE (who writes, who gave up, the walls), the ORDER BOOK, and THE READ: who is in control, the levels,
            what would turn it - CE only above the ceiling with its call OI falling, PE below the floor ...
  CLEAR     a company-level reason found (results, a filing, news, a broker's call)
  IN DOUBT  none found - the market / the money only: said so, never invented
  where     the 🚀 Moves topic, ringing (alertword: 🔍 WHY = something is happening)
  python3 movealert.py JUBLFOOD      the alert as it would read now (nothing sent)"""
import os, sys, time, threading, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
DAY_STEPS, SUDDEN, SUDDEN_MIN, COOL = (2.5, 5.0), 1.5, 15, 45 * 60
ST = {"day": None, "ring": {}, "said": {}, "busy": False, "q": []}
LOCK = threading.Lock()


def _f(v):
    return "{:,.1f}".format(v) if v is not None else "?"


def compose(sym, chg, px, why_text="", now=None):
    """-> the alert text (or None when nothing can be read)"""
    now = now or dt.datetime.now(IST)
    import whymove
    w = whymove.explain(sym, now=now)
    chg = w.get("chg") if w.get("chg") is not None else chg
    px = w.get("px") or px
    d = 1 if (chg or 0) > 0 else -1
    R = w.get("reasons") or []
    lead = [r for r in R if r["side"] == d and r["k"] not in ("options",)]
    stock = w.get("stock")
    conf = "CLEAR" if stock else "IN DOUBT"
    L = ["🔍 WHY %s %s %+.1f%% ₹%s · %s · %s%s" % ("▲" if d > 0 else "▼", sym, chg or 0, _f(px), now.strftime("%H:%M"), conf, (" · " + why_text) if why_text else "")]
    if lead:
        L.append("main reason: " + lead[0]["t"][:200])
        for r in lead[1:3]:
            L.append("also: " + r["t"][:160])
    else:
        L.append("main reason: none found that explains this direction")
    if not stock:
        L.append("IN DOUBT: no company news, filing or broker call found - the market / the money only. Check the share card before acting.")
    ag = [r for r in R if r["side"] == -d and r["w"] >= 2]
    if ag:
        L.append("against it: " + ag[0]["t"][:140])
    b = None
    try:
        import oibattle
        b = oibattle.read(sym)
    except Exception:
        b = None
    if b:
        L.append("OI: %s · ceiling %g · floor %g%s" % (b["verdict"], b["ceil"], b["floor"], ("" if b["score"] == 0 else " (score %+d)" % b["score"])))
        for x in b["lines"][2:5]:
            L.append("  · " + x[:150])
    try:
        import bookpress
        bk = bookpress.for_sym(sym)
    except Exception:
        bk = None
    if bk:
        L.append("order book: %s · buyers %s%% of the orders waiting%s" % (bk["word"].lower(), bk["buy"], (" (15 min ago %s%%)" % bk["b15"]) if bk.get("b15") is not None else ""))
    L.append("THE READ: " + the_read(d, b, px))
    return "\n".join(L)


def the_read(d, b, px):
    if not b:
        return "no option-chain read yet - watch the day's high / low"
    ceil_, floor_, v = b["ceil"], b["floor"], b["verdict"]
    if d < 0 and v == "BEARISH":
        return "sellers in control under %g · below %g the floor goes · CE only back above %g with its call OI falling" % (ceil_, floor_, ceil_)
    if d > 0 and v == "BULLISH":
        return "buyers in control above %g · above %g the call writers must buy back (the move speeds up) · PE only back under %g" % (floor_, ceil_, floor_)
    if d < 0:
        return "a fall into a %s chain - the floor %g decides: holds = a bounce is possible · breaks = it goes on (PE)" % (v.lower(), floor_)
    return "a rise into a %s chain - the ceiling %g decides: breaks with its call OI falling = it goes on (CE) · rejected = back down" % (v.lower(), ceil_)


def scan(syms, ltp, pclose, fo=None, send=None, now=None):
    """the engine's arrays -> the shares to explain now (sent in a thread). Returns the (sym, kind) picked."""
    now = now or dt.datetime.now(IST)
    hm = now.strftime("%H:%M")
    day = str(now.date())
    if ST["day"] != day:
        ST.update({"day": day, "ring": {}, "said": {}})
    if not ("09:20" <= hm <= "15:20"):
        return []
    t = now.timestamp()
    pick = []
    for i, s in enumerate(syms):
        if not i or (fo and i not in fo):
            continue
        try:
            p, pc = float(ltp[i]), float(pclose[i])
        except Exception:
            continue
        if not (p == p and pc == pc) or pc <= 0 or p <= 0:
            continue
        chg = (p / pc - 1) * 100
        rg = ST["ring"].setdefault(s, [])
        if not rg or t - rg[-1][0] >= 30:
            rg.append((t, p))
            while rg and t - rg[0][0] > SUDDEN_MIN * 60 + 60:
                rg.pop(0)
        sd = 1 if chg > 0 else -1
        for st in DAY_STEPS:
            k = (s, "day", sd, st)
            if abs(chg) >= st and k not in ST["said"]:
                for st2 in DAY_STEPS:                           # crossing 5% at once says 5% only
                    if abs(chg) >= st2:
                        ST["said"][(s, "day", sd, st2)] = t
                pick.append((s, "day %+g%%" % (sd * max(x for x in DAY_STEPS if abs(chg) >= x)), chg, p))
                break
        old = next((x for x in rg if t - x[0] >= SUDDEN_MIN * 60 - 30), None)
        if old:
            m = (p / old[1] - 1) * 100
            k = (s, "sudden", 1 if m > 0 else -1)
            if abs(m) >= SUDDEN and t - ST["said"].get(k, 0) >= COOL and not any(x[0] == s for x in pick):
                ST["said"][k] = t
                pick.append((s, "%+.1f%% in %d min" % (m, SUDDEN_MIN), chg, p))
    if pick and send:
        threading.Thread(target=_send_all, args=(pick, send, now), daemon=True).start()
    return [(x[0], x[1]) for x in pick]


def _send_all(pick, send, now):
    for s, why, chg, p in pick[:12]:
        try:
            txt = compose(s, chg, p, why, now)
            if txt:
                send(txt)
        except Exception as ex:
            print("movealert %s: %s" % (s, str(ex)[:80]))


if __name__ == "__main__":
    for s in sys.argv[1:] or ["JUBLFOOD"]:
        print(compose(s.upper(), None, None, "now"))
        print()
PY_MV
cat > $W/whymove.py <<'PY_WHY'
#!/usr/bin/env python3
"""whymove.py - patch 133 (+133b, +140: the run-up into today and the 52-week position, +134: a news story on the results already read is not counted twice; no line on index alerts): WHY IS IT MOVING. When an F&O share moves, the reasons GIR already holds, ranked, in one line:

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
ACTION_RX = re.compile(r"target|upgrade|downgrade|rating|overweight|underweight|outperform|underperform|initiat|reiterat|\bbuy\b|\bsell\b|\badd\b|\breduce\b|\bneutral\b", re.I)
ROUNDUP_RX = re.compile(r"\blive\b|stocks? to (?:buy|watch|sell)|top \d+|\bpicks\b|stocks in focus|stocks? in news|buzzing|market (?:live|today)|these \d+", re.I)
_N = {"t": 0.0, "v": {}}


def _name(sym):
    if time.time() - _N["t"] > 3600:
        try:
            import newsroom
            _N["v"] = {s: n for s, n, l in newsroom.fo_names()}
        except Exception:
            pass
        _N["t"] = time.time()
    return _N["v"].get(sym) or ""


def _names_it(h, sym, name):
    """the headline names this company: its symbol, or the first word of its name (Ambuja, Voltas, Divi's ...)"""
    w = [x for x in re.findall(r"[A-Za-z][A-Za-z'&\-]+", name or "") if x.lower() not in ("the", "ltd", "limited", "india", "of", "and")]
    keys = {sym.lower()} | ({w[0].lower().replace("'", "")} if w and len(w[0]) >= 3 else set())
    hl = re.sub(r"'", "", h.lower())
    return any(re.search(r"\b%s\b" % re.escape(k), hl) for k in keys)


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
            add("results", "results %s%s (%s): %s" % ("BIG " if big and not str(rr["verdict"]).startswith("BIG") else "", rr["verdict"], rr["when"], re.sub(r"\s*\((consolidated|standalone)[^)]*\)", "", rr.get("line") or "")[:150]),
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
    has_res = any(r["k"] == "results" for r in R)
    try:
        con = _ro("tomorrow.db")
        d0 = str((now - dt.timedelta(hours=36)).date())
        seen = set()
        for day, t, kind, side, text in con.execute("select day, t, kind, side, text from alerts where sym=? and day>=? order by day desc, t desc limit 40", (sym, d0)):
            if kind not in ("📰", "🚨", "📄", "⚡"):
                continue
            L = [x for x in (text or "").split("\n") if x.strip() and not re.match(r"(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O|🔔 OPENING \d|⚠ NOT SENT)", x)]   # GIR's own tags are not the news
            head = L[0] if L else ""
            if not re.search(r"\bNEWS\b", head) or re.search(r"FILING|· NSE \d", head):
                continue
            if has_res and any(re.search(r"outcome of (?:the )?board meeting|financial results|RESULTS (?:BIG )?(?:BEAT|MISS|IN LINE)", x, re.I) for x in L[1:2]):
                continue                                        # patch 134: the filing's own echo is not a 2nd reason (a real story on the results stays)                                        # patch 133b: news only - GIR's own desk / OI lines and the filings (read above) are not news
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
        nm = _name(sym)
        for it in newsroom.items_for(sym, 72, 0)[:20]:
            h_ = it.get("h") or ""
            if BROKER_RX.search(h_) and ACTION_RX.search(h_) and not ROUNDUP_RX.search(h_) and _names_it(h_, sym, nm):   # patch 133b: a call on THIS company
                add("broker", "broker (%s): %s" % (it.get("t"), (it.get("h") or "")[:130]), 3, int(it.get("side") or 0))
                break
    except Exception:
        pass
    # patch 140: the run-up into today and the 52-week position (the daily closes, data/oistudy.db)
    try:
        con = _ro(os.path.join("data", "oistudy.db"))
        cl = [r[0] for r in con.execute("select spot from day where sym=? and spot>0 and d<? order by d desc limit 260", (sym, str(now.date())))]
        con.close()
        if len(cl) >= 6 and chg:
            wk = (cl[0] / cl[5] - 1) * 100
            if abs(wk) >= 6:
                if wk * chg < 0:
                    add("runup", "%s after %+.1f%% in the 5 sessions before" % ("profit-booking" if wk > 0 else "a bounce", wk), 2, 1 if chg > 0 else -1)
                else:
                    add("runup", "extends a %+.1f%% run of the 5 sessions before" % wk, 1, 1 if wk > 0 else -1)
        if len(cl) >= 120 and px:
            hi, lo = max(cl), min(cl)
            if px <= lo * 1.03:
                add("52w", "near its 52-week low ₹%s" % ("{:,.1f}".format(lo)), 1, -1 if (chg or 0) < 0 else 0)
            elif px >= hi * 0.97:
                add("52w", "near its 52-week high ₹%s" % ("{:,.1f}".format(hi)), 1, 1 if (chg or 0) > 0 else 0)
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
        add("money", "%s · ₹%.0f cr of fresh futures money" % (f["bu"].lower(), abs(f["cr"])), 2, sg)
    om = next((x for x in _state().get("opt_money") or [] if x.get("s") == sym), None)
    if om and (om.get("rce") or om.get("rpe")):
        lab = lambda w, v: v if str(v).lower().startswith(w) else "%s %s" % (w, v)
        add("options", " · ".join(x for x in (lab("calls", om["rce"]) if om.get("rce") else "", lab("puts", om["rpe"]) if om.get("rpe") else "") if x), 1, 0)
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
        if not m or m.group(1) in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX"):
            return text                                         # patch 134: the index desk's lines carry their own why
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
cat > $D/p140test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p140test.py - THE MOVE EXPLAINED on Rama's JUBLFOOD of 9 Nov (-4%: results BIG MISS, its sector -1.3%, options BEARISH):
🔍 WHY ... CLEAR with the main reason, the OI battle and THE READ; a move with nothing company-level -> IN DOUBT; the run-up
("profit-booking after +9.5%"); when it fires (2.5% once a side, 5% again, 1.5% in 15 min, not before 09:20, F&O only); it rings
in the Moves topic. Fake files - nothing is fetched or sent."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import whymove, movealert, exchange, newsroom, oibattle, bookpress, tglanes, alertword
IST = whymove.IST
tmp = tempfile.mkdtemp(prefix="p140")
try:
    whymove.BASE = tmp; os.makedirs(os.path.join(tmp, "data"))
    now = dt.datetime(2026, 11, 9, 9, 42, tzinfo=IST)
    json.dump({"t": time.time(), "q": {"JUBLFOOD": [433.0, -4.1], "DEVYANI": [150.0, -1.5], "WESTLIFE": [700.0, -1.1], "YESBANK": [24.0, 3.0], "PNB": [100.0, 0.1], "SBIN": [800, 0.0]}},
              open(os.path.join(tmp, "quotes_live.json"), "w"))
    json.dump({"fo_paths": [{"s": "JUBLFOOD", "bu": "SHORT BUILD-UP", "cr": 40.0}]}, open(os.path.join(tmp, "dash_state.json"), "w"))
    whymove._sectors = lambda u: {"Consumer Services": ["JUBLFOOD", "DEVYANI", "WESTLIFE"], "Banks": ["YESBANK", "PNB", "SBIN"]}
    exchange.results_read = lambda sym, hours=40, con=None: ({"verdict": "BIG MISS", "side": -1, "line": "revenue ₹2,608 cr +12% YoY · profit ₹112 cr -43% YoY",
                                                              "read": {"big": True}, "when": "06 Nov 15:20"} if sym == "JUBLFOOD" else None)
    newsroom.items_for = lambda *a, **k: []
    o = sqlite3.connect(os.path.join(tmp, "data", "oistudy.db")); o.execute("create table day(sym text, d text, spot real)")
    for i in range(1, 200):
        d = str(now.date() - dt.timedelta(days=i))
        o.execute("insert into day values(?,?,?)", ("JUBLFOOD", d, 451.0 if i <= 2 else 412.0 if i <= 6 else 520.0))
    o.commit(); o.close()
    for f in ("tomorrow.db", "filings.db", "chains.db"):
        sqlite3.connect(os.path.join(tmp, f)).close()
    whymove._C.clear(); whymove._F.update({"state": (0.0, {}), "q": (0.0, {}), "sec": (0.0, {})})
    oibattle.read = lambda sym, ivp=None, data=None: ({"verdict": "BEARISH", "score": -2, "ceil": 460, "floor": 400, "lines": ["c", "f", "today CALLS written more (7.4 L vs puts 2.5 L): big money sees no rise - bearish",
                                                                                                                              "most new puts at 410 (+4.9 L, +125%)", "put writers GAVE UP above the price: 450 -33%, 460 -26%"]} if sym == "JUBLFOOD" else None)
    bookpress.for_sym = lambda sym: {"word": "BALANCED", "buy": 45.5, "b15": 57.0} if sym == "JUBLFOOD" else None
    w = whymove.explain("JUBLFOOD", now=now)
    ru = [r["t"] for r in w["reasons"] if r["k"] == "runup"]
    check("the run-up read: %s" % ru, ru and "+9.5% in the 5 sessions before" in ru[0] and ru[0].startswith("extends") is False)
    t = movealert.compose("JUBLFOOD", -4.1, 433.0, "day -2%", now)
    print("\n".join("     " + x for x in t.split("\n")))
    L = t.split("\n")
    check("🔍 WHY ▼ JUBLFOOD -4.1% ... CLEAR", L[0].startswith("🔍 WHY ▼ JUBLFOOD -4.1% ₹433.0 · 09:42 · CLEAR"))
    check("main reason: the results BIG MISS", L[1].startswith("main reason: results BIG MISS (06 Nov 15:20)"))
    check("the OI battle and the order book in it", any(x.startswith("OI: BEARISH · ceiling 460 · floor 400") for x in L) and any(x.startswith("order book: balanced · buyers 45.5%") for x in L))
    check("THE READ: sellers in control under 460, CE only back above 460", L[-1] == "THE READ: sellers in control under 460 · below 400 the floor goes · CE only back above 460 with its call OI falling")
    whymove._C.clear()
    y = movealert.compose("YESBANK", 3.0, 24.0, "day +2%", now)
    check("YESBANK +3%%, nothing company-level -> IN DOUBT, said so: %s" % y.split("\n")[0], " · IN DOUBT" in y.split("\n")[0] and "IN DOUBT: no company news" in y)
    check("it rings (%s) in the Moves topic (%s)" % (alertword.tier(t), tglanes.topic(t)), alertword.tier(t) == "move" and tglanes.lane(t) == "moves" and tglanes.topic(t) == "moves")
    print("2. when it fires")
    SENT = []
    movealert.compose = lambda s, c, p, why, now=None: "🔍 WHY %s %s" % (s, why)
    syms = ["NIFTY50", "JUBLFOOD", "TCS", "SMALLCO"]; fo = {1, 2}; pc = [1, 451.0, 3000.0, 100.0]
    T = lambda h, m, s=0: dt.datetime(2026, 11, 9, h, m, s, tzinfo=IST)
    r0 = movealert.scan(syms, [1, 435.0, 3000, 90], pc, fo, None, T(9, 18))
    r1 = movealert.scan(syms, [1, 438.0, 3000, 90], pc, fo, None, T(9, 21))
    r2 = movealert.scan(syms, [1, 436.0, 3000, 90], pc, fo, None, T(9, 25))
    r3 = movealert.scan(syms, [1, 427.0, 3000, 90], pc, fo, None, T(9, 30))
    check("09:18 nothing (the open); 09:21 JUBLFOOD -2.9%% once (%s); not again at 09:25 (%s); -5.3%% at 09:30 (%s); SMALLCO (not F&O) never" % (r1, r2, r3),
          r0 == [] and r1 == [("JUBLFOOD", "day -2.5%")] and r2 == [] and r3 == [("JUBLFOOD", "day -5%")])
    for k in range(0, 34):
        tt = T(10, 0) + dt.timedelta(seconds=30 * k)
        p = 3000.0 if k < 31 else 3050.0
        rs = movealert.scan(syms, [1, 427.0, p, 90], pc, fo, None, tt)
        if rs:
            break
    check("TCS +1.7%% inside 15 min -> %s" % rs, rs == [("TCS", "+1.7% in 15 min")])
    movealert.scan(syms, [1, 427.0, 3050.0, 90], pc, fo, SENT.append, T(10, 20))
    en = open(os.path.join(B, "engine2.py"), encoding="utf-8").read()
    check("the engine checks every 30 s", "movealert.scan(feed.syms, feed.ltp, feed.pclose, feed.fo_idx, tg_fo)" in en)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP140 THE MOVE EXPLAINED TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p140_patch.py $D || { rm -f $D/p140test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/movealert.py $D/ && cp $W/whymove.py $D/whymove.py
cd $D && python3 -m py_compile movealert.py whymove.py engine2.py alertword.py p140test.py || back
timeout 120 python3 p140test.py 2>&1 | grep "OK  \|FAIL\|P140"
timeout 120 python3 p140test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p133test.py p133btest.py p134test.py p135test.py p137test.py p138ctest.py p124test.py p123test.py p114test.py fmtest.py p88test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 140 APPLIED. From tomorrow 09:20 a sudden move sends 🔍 WHY. Today's two, as GIR would have written them:"
cd $D && timeout 120 python3 movealert.py JUBLFOOD DATAPATTNS
