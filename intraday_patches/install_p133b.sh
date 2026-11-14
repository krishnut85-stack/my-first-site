#!/bin/bash
# PATCH 133b - WHY IS IT MOVING, CLEANED ON THE REAL DATA (on top of patch 133).
#   - GIR's own desk / OI lines ("EXTREME BEARISH -> PE ...") are not news; the results filing is not counted twice
#   - a broker call counts only when the headline names THIS company and is not a "Live" / "stocks to buy" roundup
#     (Ambuja got Motilal's call on Bharat Forge)
#   - "calls calls written" -> "calls written" · "short build-up · futures bought ₹29 cr" -> "short build-up · ₹29 cr of fresh futures money"
#   whymove.py (replaced - patch 133's own file). Restarts gir-dash and gir-intraday (outside market hours).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g133b; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35, or: bash install_p133b.sh now"; exit 1; fi
[ -f $D/whymove.py ] || { echo "patch 133 is not installed yet - paste patch 133 first"; exit 1; }
grep -q "patch 133b" $D/whymove.py && { echo "patch 133b is already installed"; exit 1; }
cp $D/whymove.py $D/whymove.py.bak$TS
back() { cp $D/whymove.py.bak$TS $D/whymove.py; rm -f $D/p133btest.py; systemctl restart gir-dash gir-intraday; echo "ERROR - old file back, nothing changed"; exit 1; }
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
            if not re.search(r"\bNEWS\b", head) or re.search(r"FILING|· NSE \d", head):
                continue                                        # patch 133b: news only - GIR's own desk / OI lines and the filings (read above) are not news
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
cat > $D/p133btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p133btest.py - WHY IS IT MOVING, cleaned on Rama's real data (8 Nov): GIR's own desk / OI lines are not news; the results
filing is not counted twice; a broker call counts only when it names THIS company and is not a roundup; no "calls calls";
the futures money is "₹N cr of fresh futures money" (no bought / sold that contradicts the build-up)."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import whymove, exchange, newsroom
tmp = tempfile.mkdtemp(prefix="p133b")
try:
    whymove.BASE = tmp
    today = str(dt.datetime.now(whymove.IST).date())
    json.dump({"t": time.time(), "q": {"AMBUJACEM": [560.0, 1.3], "ACC": [2000.0, 0.2], "ULTRACEMCO": [11000.0, 0.1]}}, open(os.path.join(tmp, "quotes_live.json"), "w"))
    json.dump({"fo_paths": [{"s": "AMBUJACEM", "bu": "SHORT BUILD-UP", "cr": 29.0}], "opt_money": [{"s": "AMBUJACEM", "rce": "calls bought — betting UP", "rpe": "written — support"}]},
              open(os.path.join(tmp, "dash_state.json"), "w"))
    whymove._sectors = lambda u: {"Cement": ["AMBUJACEM", "ACC", "ULTRACEMCO"]}
    whymove._name = lambda s: {"AMBUJACEM": "Ambuja Cements Limited"}.get(s, "")
    exchange.results_read = lambda sym, hours=40, con=None: None
    newsroom.items_for = lambda sym, hours=96, min_score=0, con=None: [
        {"t": "07 Nov 16:26", "h": "Neutral Bharat Forge; target of Rs 1800: Motilal Oswal", "side": 1},
        {"t": "06 Nov 09:07", "h": "Q2 Results 06th Nov Live: Hindalco, Bosch, Ambuja target prices", "side": -1},
        {"t": "08 Nov 10:00", "h": "Ambuja Cements: Jefferies upgrades to buy, target Rs 700", "side": 1}]
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    c.executemany("insert into alerts values(?,?,?,?,?,?)", [
        (today, "15:16:00", "🚨", "AMBUJACEM", "PE", "🚨 SUDDEN ▼ AMBUJACEM\nEXTREME BEARISH → PE (share price going DOWN). 560 PE: OI 3.8 L"),
        (today, "15:10:00", "📰", "AMBUJACEM", "CE", "📰 FILING · AMBUJACEM · RESULTS · BEAT · NSE 15:10:00\nRESULTS BEAT — beats: Outcome of Board Meeting"),
        (today, "18:04:00", "📰", "AMBUJACEM", "CE", "📰 NEWS ▲ AMBUJACEM · CAPEX · ET 18:04\n🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR\nAmbuja Cements to invest ₹14,500 crore to add 30 MTPA\nthe reader (x): big capacity add · IMPORTANT · sure 80%")])
    c.commit(); c.close()
    for f in ("filings.db", "chains.db"):
        sqlite3.connect(os.path.join(tmp, f)).close()
    whymove._C.clear(); whymove._F.update({"state": (0.0, {}), "q": (0.0, {}), "sec": (0.0, {})})
    w = whymove.explain("AMBUJACEM")
    T = [r["t"] for r in w["reasons"]]
    news = [t for t in T if t.startswith("news")]
    check("news = the real headline only (no EXTREME BEARISH desk line, no results filing): %s" % news,
          len(news) == 1 and "Ambuja Cements to invest ₹14,500 crore" in news[0] and "SOMETHING IS HAPPENING" not in news[0])
    br = [t for t in T if t.startswith("broker")]
    check("broker = the call on Ambuja (not Bharat Forge, not a 'Live' roundup): %s" % br, len(br) == 1 and "Jefferies upgrades" in br[0])
    check("options: no 'calls calls': %s" % next((t for t in T if "bought" in t or "written" in t), ""), not any("calls calls" in t or "puts puts" in t for t in T)
          and any("calls bought — betting UP" in t and "puts written — support" in t for t in T))
    check("money: %s" % next((t for t in T if "futures" in t), ""), any(t == "short build-up · ₹29 cr of fresh futures money" for t in T))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP133B WHY CLEANED TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cp $W/whymove.py $D/whymove.py
cd $D && python3 -m py_compile whymove.py p133btest.py || back
timeout 120 python3 p133btest.py 2>&1 | grep "OK  \|FAIL\|P133B"
timeout 120 python3 p133btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p133test.py p132test.py p124test.py p123test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
systemctl restart gir-intraday && sleep 5
[ "$(systemctl is-active gir-intraday)" = "active" ] || { echo "gir-intraday did not come back"; back; }
echo
echo "PATCH 133b APPLIED. The same four, read again:"
cd $D && for s in VOLTAS DIVISLAB DATAPATTNS AMBUJACEM; do timeout 60 python3 whymove.py $s 2>&1 | head -2; done
