#!/bin/bash
# PATCH 208 - THE PUSH WATCH (Rama: "who can push a share up and push it down - monitor all 12 points by our agents, the two kinds of
#   push and the study"). Every F&O share, the 12 pushers (FII · DII · option writers · futures · promoters · index funds · the company ·
#   regulators / ban · the market tide · brokers · algos / stop-losses · ex-dates / expiry) and the KIND of push:
#     🟢 NEW MONEY (can last - hold) · 🟠 FORCED OUT (fast - book early) · 🟢🟠 BOTH (strongest) · ⚪ TIDE ONLY (follows the market)
#   - every move / OI / GO alert gets a "⚙️ push:" line (Telegram and the page) · the share card gets WHO IS PUSHING (12 boxes)
#   - the IMPORTANT rows show the kind · promoter buy / sell / pledge and record dates are now read (the filings reader kept them as routine)
#   - the desk's futures agent now votes in EVERY sector (it voted only in sectors of 15+ shares: oil-gas, metals, power, auto ... had none)
#   - THE PUSH STUDY (since Jan 2025): after NEW MONEY / FORCED OUT, what did the share do next - runs now in the background and every
#     weekday 20:15; its numbers join the push line. Restarts the desk, the engine, the newsroom, the exchange reader, TV watch, the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d); U=/etc/systemd/system
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35"; exit 1; fi
grep -q "patch 207" $D/home.html || { echo "patch 207 is not in - run install_p207.sh first"; exit 1; }
FILES="tgq.py dashserve.py desk.py home.html"
for f in $FILES; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/pushwho.py; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/pushwho.py <<'PY_PUSH'
#!/usr/bin/env python3
"""pushwho.py - patch 208: THE PUSH WATCH - WHO IS PUSHING THIS SHARE (Rama, 11 Nov: "how many ways a stock can go up and go down - who
can push up and push down? Monitor all the points by our agents - the 12 points, the two kinds of push and the study").
Every F&O share, the 12 pushers - each ON (with what GIR sees and its side ▲ / ▼) or quiet:
   1 FII            foreign funds: their named bulk / block deals (5 days) · the market's FII figure
   2 DII            Indian funds / insurers: their named deals (5 days) · the market's DII figure · yesterday's delivery (big hands)
   3 WRITERS        option writers: a wall BREAKING (writers buying back) · calls / puts BOUGHT at the biggest strike · a wall forming
   4 FUTURES        today's futures build-up and its ₹ crore (long / short build-up, short covering, long unwinding)
   5 PROMOTER       promoter buying / selling / pledging (the SAST and insider-trading filings, 10 days) · promoters in the deals
   6 INDEX          index inclusion / exclusion / rebalancing in the news (MSCI, FTSE, NIFTY, SENSEX, 10 days)
   7 COMPANY        results, orders, board decisions, management, sales, the news GIR read (whymove)
   8 REGULATOR      a regulator's / court's action (filings, news) · the F&O ban list
   9 TIDE           NIFTY, its sector, global news
  10 BROKERS        a broker's call on this company (3 days)
  11 ALGOS          speed: GIR's own RUNNING / SPEED / SUDDEN alerts today · the last 15 minutes' momentum · volume vs normal
  12 MECHANICAL     a record date / ex-date (dividend, bonus, split) · expiry week · results due (positioning)
THE TWO KINDS OF PUSH (the move's own direction):
  🟢 NEW MONEY      fresh positions its way - long (short) build-up, calls (puts) bought, big hands' delivery, FII / DII / promoter
                    buying (selling), index money -> the move can last: hold, trail the stop
  🟠 FORCED OUT     the other side giving up - short covering (long unwinding), writers buying back at a broken wall -> fast and
                    short: book early, do not buy late
  🟢🟠 BOTH         fresh money AND the other side giving up - the strongest push
  ⚪ TIDE ONLY      it moves with NIFTY / its sector, no money of its own -> it follows the market, weak on its own
Local reads only (the files the engine, the desk, the exchange reader and the page server write) - safe in the alert path.
The study (pushstudy.py) measures what each kind did next; its numbers are added to the line when they exist.
  python3 pushwho.py SYM [SYM ...]     the board for these shares now"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
NAMES = [(1, "FII", "foreign funds"), (2, "DII", "Indian funds"), (3, "WRITERS", "option writers"), (4, "FUTURES", "futures traders"),
         (5, "PROMOTER", "promoters"), (6, "INDEX", "index funds"), (7, "COMPANY", "the company"), (8, "REGULATOR", "regulators / ban"),
         (9, "TIDE", "the market tide"), (10, "BROKERS", "brokers"), (11, "ALGOS", "algos / stop-losses"), (12, "MECHANICAL", "ex-dates / expiry")]
INDEX_RX = re.compile(r"\bMSCI\b|\bFTSE\b|index (?:inclusion|exclusion|review|rebalanc\w*|change)|rebalanc\w*|(?:inclu\w+|exclu\w+|added|dropped|removed|entry|exit)"
                      r"\b.{0,40}\b(?:nifty|sensex|index|indices|msci|ftse)\b|(?:nifty|sensex|msci|ftse)\b.{0,40}\b(?:inclu\w+|exclu\w+|entry|exit|add\w*|drop\w*)\b|passive (?:inflow|outflow|fund)", re.I)
INDEX_DN = re.compile(r"exclu\w+|dropped|removed|\bexit\b|outflow|deleted|weight (?:cut|reduc\w*)", re.I)
PROMO_RX = re.compile(r"\bsast\b|takeover|insider trading|\bpit\b|pledge|encumbrance|promoter", re.I)
PROMO_UP = re.compile(r"acqui\w+|purchas\w*|\bbought\b|\bbuy\w*|creeping|increase\w* (?:in )?(?:stake|holding)|release of pledge|pledge (?:released|release|revoked|revocation)|revocation", re.I)
PROMO_DN = re.compile(r"dispos\w+|\bsold\b|\bsale\b|\bsell\w*|offload\w*|decrease\w* (?:in )?(?:stake|holding)|creation of pledge|pledge (?:created|creation|invoked|invocation)|invocation|encumbrance created", re.I)
CORP_RX = re.compile(r"record date|ex-?date|book closure|corporate action", re.I)
CORP_KIND = re.compile(r"dividend|bonus|split|sub-?division|rights|buy-?back", re.I)
_F = {}
_C = {}


def _json(name, ttl):
    t, v = _F.get(name, (0.0, None))
    if v is not None and time.time() - t < ttl:
        return v
    try:
        v = json.load(open(os.path.join(BASE, name)))
    except Exception:
        v = {}
    _F[name] = (time.time(), v)
    return v


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=3)


def _fo_path(sym):
    st = _json("dash_state.json", 20)
    return next((x for x in st.get("fo_paths") or [] if x.get("s") == sym), {}) or {}


def _inst():
    t, v = _F.get("_inst", (0.0, None))
    if v is not None and time.time() - t < 300:
        return v
    try:
        import instflow
        v = instflow.summary() or {}
    except Exception:
        v = {}
    _F["_inst"] = (time.time(), v)
    return v


def _study():
    return _json(os.path.join("data", "pushstudy.json"), 3600)


def _alerts_today(sym, day):
    try:
        c = _ro("tomorrow.db")
        rows = c.execute("select t, kind, text from alerts where day=? and sym=? order by t", (day, sym)).fetchall()
        c.close()
        return rows
    except Exception:
        return []


def _filings(sym, hours, routine_only=True):
    try:
        c = _ro("filings.db")
        rows = c.execute("select kind, side, subject, detail, t_exch from filings where sym=? and t_exch>? %s order by t_exch desc limit 40"
                         % ("and kind='ROUTINE'" if routine_only else ""), (sym, time.time() - hours * 3600)).fetchall()
        c.close()
        return rows
    except Exception:
        return []


def _news(sym, hours):
    try:
        import newsroom
        return newsroom.items_for(sym, hours, 0) or []
    except Exception:
        return []


def expiry_days(d):
    """calendar days to the month's stock F&O expiry (NSE: the last Tuesday of the month, a holiday moves it a day earlier)"""
    try:
        for mo in (0, 1):
            y, m = d.year + (d.month + mo - 1) // 12, (d.month + mo - 1) % 12 + 1
            last = dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1)
            e = last - dt.timedelta(days=(last.weekday() - 1) % 7)
            try:
                import holidays
                while holidays.holiday(e):
                    e -= dt.timedelta(days=1)
            except Exception:
                pass
            if e >= d:
                return (e - d).days
    except Exception:
        pass
    return None


def read(sym, now=None):
    """-> {"s", "chg", "dir", "rows": [{"n", "k", "who", "on", "side", "t"}], "kind", "kline", "advice", "n_on"}"""
    sym = (sym or "").upper()
    c_ = _C.get(sym)
    if c_ and time.time() - c_[0] < 30 and now is None:
        return c_[1]
    now = now or dt.datetime.now(IST)
    day = str(now.date())
    try:
        import whymove
        W = whymove.explain(sym, now=None)
    except Exception:
        W = {"reasons": [], "chg": None}
    f = _fo_path(sym)
    chg = W.get("chg") if W.get("chg") is not None else f.get("chg")
    d = 1 if (chg or 0) > 0 else -1 if (chg or 0) < 0 else 0
    R = {n: {"n": n, "k": k, "who": w, "on": False, "side": 0, "t": ""} for n, k, w in NAMES}
    new, forced = [], []

    def on(n, t, side=0, kind=None):
        r = R[n]
        r["on"] = True
        r["t"] = (r["t"] + " · " if r["t"] else "") + t
        if side and not r["side"]:
            r["side"] = side
        if kind == "new" and side and side == d:
            new.append(t)
        elif kind == "forced" and side and side == d:
            forced.append(t)

    # 4 FUTURES
    bu, cr, foi = (f.get("bu") or "").replace("_", " ").upper(), abs(f.get("cr") or 0), f.get("oi")
    if bu and cr >= 5:
        sd = 1 if bu in ("LONG BUILD-UP", "SHORT COVERING") else -1
        kind = "new" if bu in ("LONG BUILD-UP", "SHORT BUILD-UP") else "forced"
        txt = "%s ₹%.0f cr%s" % (bu.lower(), cr, (" · futures OI %+.1f%%" % foi) if foi is not None else "")
        if kind == "forced":
            txt += " (%s leaving)" % ("sellers" if sd > 0 else "buyers")
        on(4, txt, sd, kind if cr >= 10 else None)
    # 3 WRITERS (the desk's walls agent)
    dk = (_json(os.path.join("data", "desk.json"), 20).get("shares") or {}).get(sym) or {}
    wl = ((dk.get("lines") or {}).get("walls") or "")
    m = re.search(r"roof at ([\d.]+) BREAKING", wl)
    if m:
        on(3, "call writers buying back at %s (the roof is breaking)" % m.group(1), 1, "forced")
    m = re.search(r"floor at ([\d.]+) BREAKING", wl)
    if m:
        on(3, "put writers buying back at %s (the floor is breaking)" % m.group(1), -1, "forced")
    m = re.search(r"calls ([\d.]+) was BOUGHT", wl)
    if m:
        on(3, "calls bought at %s - a bet on UP" % m.group(1), 1, "new")
    m = re.search(r"puts ([\d.]+) was BOUGHT", wl)
    if m:
        on(3, "puts bought at %s - a bet on DOWN" % m.group(1), -1, "new")
    for side_, k_ in (("roof", -1), ("floor", 1)):
        m = re.search(r"%s forming at ([\d.]+)" % side_, wl)
        if m:
            on(3, "writers building a %s at %s (%s)" % (side_, m.group(1), "a cap above" if side_ == "roof" else "support below"), k_)
    st = ((dk.get("lines") or {}).get("strikes") or "")
    if re.search(r"sellers running", st):
        on(3, "the desk sees option sellers running: %s" % re.sub(r"\s+", " ", st)[:90])
    # 1 FII · 2 DII · delivery
    I = _inst()
    w5 = (I.get("w") or {}).get("5") or {}
    for n, cls in ((1, "fii"), (2, "dii")):
        for key, sd in (("_buy", 1), ("_sell", -1)):
            x = next((r for r in w5.get(cls + key) or [] if r.get("s") == sym), None)
            if x:
                on(n, "%s %s ₹%.0f cr in named deals, 5 days%s" % (cls.upper(), "bought" if sd > 0 else "sold", abs(x.get("cr") or 0), (" (" + x["who"] + ")") if x.get("who") else ""), sd, "new")
    dl = I.get("deliv") or {}
    for key, sd in (("acc", 1), ("dist", -1)):
        x = next((r for r in dl.get(key) or [] if r.get("s") == sym), None)
        if x:
            on(2, "big hands %s on %s: delivery %.1fx normal (₹%.0f cr extra)" % ("BUYING" if sd > 0 else "SELLING", (dl.get("day") or "")[5:], x.get("x") or 0, x.get("extra") or 0), sd, "new")
    ctx = (_json("dash_state.json", 20).get("ctx") or {})
    fd = ctx.get("fiidii")
    if isinstance(fd, dict):
        g = lambda k: next((v for a, v in fd.items() if a.upper() == k), None)
        for n, k in ((1, "FII"), (2, "DII")):
            v = g(k)
            if isinstance(v, (int, float)) and abs(v) >= 1000:
                on(n, "the market's %s %s ₹%s cr (cash, last day)" % (k, "bought" if v > 0 else "sold", format(int(abs(v)), ",")), 1 if v > 0 else -1)
    # 5 PROMOTER (SAST / insider trading / pledge filings - the reader files them as routine, they are kept)
    seen = 0
    for kind, side, subj, det, te in _filings(sym, 240):
        s_ = "%s %s" % (subj or "", det or "")
        if not PROMO_RX.search(s_) or not re.search(r"promoter|\bsast\b|takeover|pledge|encumbrance", s_, re.I):
            continue
        up_, dn_ = bool(PROMO_UP.search(s_)), bool(PROMO_DN.search(s_))
        sd = 1 if up_ and not dn_ else -1 if dn_ and not up_ else 0
        when = dt.datetime.fromtimestamp(te, IST).strftime("%d %b")
        on(5, "%s (%s): %s" % ("promoter BUYING / pledge released" if sd > 0 else "promoter SELLING / pledging" if sd < 0 else "promoter filing", when, re.sub(r"\s+", " ", det or subj or "")[:90]), sd, "new" if sd else None)
        seen += 1
        if seen >= 2:
            break
    # 12 MECHANICAL: a record date / ex-date (dividend, bonus, split ...) in the last 20 days' filings
    for kind, side, subj, det, te in _filings(sym, 480):
        s_ = "%s %s" % (subj or "", det or "")
        if CORP_RX.search(s_) and CORP_KIND.search(s_):
            on(12, "%s: %s" % (CORP_KIND.search(s_).group(0).lower(), re.sub(r"\s+", " ", det or subj or "")[:100]))
            break
    # 6 INDEX
    for it in _news(sym, 240)[:60]:
        h_ = it.get("h") or ""
        if INDEX_RX.search(h_):
            sd = -1 if INDEX_DN.search(h_) else 1
            on(6, "index money (%s): %s" % (it.get("t") or "", h_[:110]), sd, "new")
            break
    # 7 COMPANY · 8 REGULATOR · 9 TIDE · 10 BROKERS · 12 due (whymove's reasons)
    for r in W.get("reasons") or []:
        k, t, sd = r.get("k"), r.get("t") or "", int(r.get("side") or 0)
        if k in ("results", "news", "event"):
            on(7, t[:120], sd)
        elif k == "filing":
            on(8 if t.lower().startswith("reg ") else 7, t[:120], sd)
        elif k in ("sector", "market", "global", "alone"):
            on(9, t[:110], sd)
        elif k == "broker":
            on(10, t[:120], sd)
        elif k == "due":
            on(12, t[:100])
        elif k == "options" and not R[3]["on"]:
            on(3, "options: " + t[:100])
    for r in W.get("reasons") or []:
        if r.get("k") == "news" and re.search(r"sebi|rbi|court|tribunal|usfda|\bfda\b|penalt|regulator|ministry|government", r.get("t") or "", re.I):
            on(8, (r.get("t") or "")[:110], int(r.get("side") or 0))
            break
    ban = _json(os.path.join("data", "desk.json"), 20).get("ban") or []
    if sym in ban:
        on(8, "in the F&O ban list - only closing allowed, the share drifts as positions are cut")
    # 11 ALGOS / stop-losses
    sp = [(t, k) for t, k, tx in _alerts_today(sym, day) if re.search(r"RUNNING|SPEED|SUDDEN|FIRST MOVE", tx or "")]
    bars = f.get("bars") or {}
    if sp:
        on(11, "%d fast-move alert%s today (first %s)" % (len(sp), "" if len(sp) == 1 else "s", sp[0][0][:5]), d)
    if f.get("rv") and f["rv"] >= 2:
        on(11, "volume %.1fx normal for this time" % f["rv"], d)
    if (bars.get("mom") or 0) >= 0.8:
        on(11, "strong momentum in the last 15 min", d)
    # 12 expiry week
    dl_ = expiry_days(now.date())
    if dl_ is not None and dl_ <= 4:
        on(12, "expiry week (%s) - writers try to pin the price at their strikes" % ("expiry TODAY" if dl_ == 0 else "%d day%s left" % (dl_, "" if dl_ == 1 else "s")))
    # the kind of push
    ar = "▲" if d > 0 else "▼" if d < 0 else ""
    if new and forced:
        kind, adv = "BOTH", "fresh money AND the other side giving up - the strongest push"
    elif new:
        kind, adv = "NEW MONEY", "fresh positions its way - can last: hold, trail the stop"
    elif forced:
        kind, adv = "FORCED OUT", "the other side giving up - fast and short: book early, do not buy late"
    elif chg is not None and abs(chg) >= 0.7 and (R[9]["on"] and R[9]["side"] == d):
        kind, adv = "TIDE ONLY", "moving with the market / its sector, no money of its own - it follows the market"
    else:
        kind, adv = "", ""
    meas = ""
    S = _study().get("kinds") or {}
    sk = S.get("%s %s" % (kind, "UP" if d > 0 else "DOWN")) if kind else None
    if sk and sk.get("n", 0) >= 30:
        meas = " · measured: went on its way the next day %d%% of %d (avg %+.1f%%)" % (sk.get("cont1", 0), sk["n"], sk.get("avg1", 0))
    icon = {"BOTH": "🟢🟠", "NEW MONEY": "🟢", "FORCED OUT": "🟠", "TIDE ONLY": "⚪"}.get(kind, "")
    parts = (new + forced)[:3]
    kline = ("%s %s %s - %s%s" % (icon, ar, kind, " · ".join(p[:70] for p in parts) if parts else adv, meas)) if kind else ""
    rows = [R[n] for n, k, w in NAMES]
    out = {"s": sym, "chg": chg, "dir": "UP" if d > 0 else "DOWN" if d < 0 else "", "rows": rows, "n_on": sum(1 for r in rows if r["on"]),
           "kind": kind, "kline": kline, "advice": adv, "new": new, "forced": forced}
    if len(_C) > 400:
        _C.clear()
    _C[sym] = (time.time(), out)
    return out


SYM_RX = re.compile(r"[▲▼]\s+([A-Z][A-Z0-9&\-]{1,19})\b")
PUSH_K = ("🚀", "⚡", "🌅", "📈", "🧩", "🔭", "🔎", "🟠", "🟢", "🚨")


def add_line(text):
    """a move / OI / GO alert -> the same alert with a "⚙️ push:" line (once); any other alert unchanged"""
    try:
        if "⚙️ push:" in (text or ""):
            return text
        L = (text or "").split("\n")
        head = L[0]
        if head.startswith("🔔 OPENING") and len(L) > 1 and not head.startswith("🔔 OPENING · "):
            head = L[1]
        h2 = head[len("🔔 OPENING · "):] if head.startswith("🔔 OPENING · ") else head
        k = h2.split()[0] if h2.split() else ""
        if k not in PUSH_K:
            return text
        cand = [m.group(1) for m in SYM_RX.finditer(h2)] + [m.group(1) for m in re.finditer(r"·\s+([A-Z][A-Z0-9&\-]{1,19})\s+[▲▼]", h2)]
        sym = next((x for x in cand if x not in ("CE", "PE", "BUY", "SELL", "UP", "DOWN", "OI", "GO")), None)
        if not sym or sym in ("NIFTY", "BANKNIFTY", "FINNIFTY", "SENSEX", "MARKET"):
            return text
        p = read(sym)
        if not p.get("kline"):
            return text
        return text.rstrip("\n") + "\n⚙️ push: " + p["kline"][:260]
    except Exception:
        return text


if __name__ == "__main__":
    for s in sys.argv[1:] or ["SBIN"]:
        p = read(s)
        print("%s %s %s · %d of 12 pushers on" % (p["s"], ("%+.2f%%" % p["chg"]) if p["chg"] is not None else "?", p["dir"], p["n_on"]))
        print("  PUSH: %s" % (p["kline"] or "no clear push"))
        for r in p["rows"]:
            print("  %2d %-10s %s %s" % (r["n"], r["k"], ({1: "▲", -1: "▼", 0: "·"}[r["side"]] if r["on"] else " "), r["t"] or "-"))
PY_PUSH
cat > $D/pushstudy.py <<'PY_STUDY'
#!/usr/bin/env python3
"""pushstudy.py - patch 208: THE PUSH STUDY - NEW MONEY vs FORCED OUT (Rama, 11 Nov: "the two kinds of push and the study").
Reads only, sends nothing. GIR's oistudy.db (NSE's daily F&O file since Jan 2025: every share-day's futures OI and its change, every strike
within 10%) and, when it is there, the 5-min candles of the next day (data/h3).
  THE MOVE      a share-day that closed 1.5%+ up or down
  ITS PUSH      NEW MONEY    the futures OI rose 2%+ with it (long / short build-up) and no wall's writers ran
                FORCED OUT   the futures OI fell 2%+ (short covering / long unwinding) - or the writers of the wall it crossed ran
                             (call OI at yesterday's roof fell while the price closed above it; the mirror for puts at the floor)
                BOTH         fresh futures money AND the wall's writers ran
                NO OI CHANGE the futures OI within ±2% and no wall broken: the tide / the cash market
  WHAT NEXT     the next day: did it go on its way (close to close), the average; 3 days; the next open's gap its way;
                the Rama morning trade (in 09:20 when the first 5 min go its way, +1.5% before -0.8%) when the 5-min file exists
  by the size of the move (1.5-3% · 3%+) and by year - the base: every share-day
  python3 pushstudy.py      -> prints, data/pushstudy.txt, data/pushstudy.json (the live ⚙️ push line adds its numbers)"""
import os, sys, json, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
MOVE, OIX = 1.5, 2.0


def kind_of(rs, i):
    """-> (kind, side, chg, why) for the share-day rs[i], or None (no 1.5%+ move)"""
    r, p = rs[i], rs[i - 1]
    if not r.get("spot") or not p.get("spot"):
        return None
    chg = (r["spot"] / p["spot"] - 1) * 100
    if abs(chg) < MOVE:
        return None
    d = 1 if chg > 0 else -1
    foi, fdoi = r.get("foi") or 0, r.get("fdoi")
    if fdoi is None and p.get("foi"):
        fdoi = foi - p["foi"]                                   # no change column: from the day before
    fdoi = fdoi or 0
    base = foi - fdoi
    oip = (fdoi / base * 100) if base > 0 else 0.0
    ran = False
    try:
        st = json.loads(r.get("strikes") or "{}")
        k0 = p.get("roof_k") if d > 0 else p.get("floor_k")
        if k0 and st:
            v = st.get("%g" % k0) or st.get(str(k0)) or next((vv for kk, vv in st.items() if abs(float(kk) - k0) < 1e-6), None)
            crossed = r["spot"] > k0 if d > 0 else r["spot"] < k0
            if v and crossed:
                dd = v[1] if d > 0 else v[3]
                if not dd:                                      # no change column: against the day before at that strike
                    pv = json.loads(p.get("strikes") or "{}")
                    pv = pv.get("%g" % k0) or pv.get(str(k0))
                    if pv:
                        dd = (v[0] - pv[0]) if d > 0 else (v[2] - pv[2])
                ran = bool(dd) and dd < 0
    except Exception:
        pass
    if oip >= OIX and ran:
        k = "BOTH"
    elif oip >= OIX:
        k = "NEW MONEY"
    elif oip <= -OIX or ran:
        k = "FORCED OUT"
    else:
        k = "NO OI CHANGE"
    return k, d, chg, {"oip": oip, "ran": ran}


def next_of(rs, i, d, M=None):
    """what came next -> {"n1", "n3", "gap", "trade"} (its way, %)"""
    r = rs[i]
    out = {}
    if i + 1 < len(rs) and rs[i + 1].get("spot"):
        out["n1"] = (rs[i + 1]["spot"] / r["spot"] - 1) * 100 * d
        fo, fc = rs[i + 1].get("fo"), r.get("fc")
        if fo and fc:
            out["gap"] = (fo / fc - 1) * 100 * d
    if i + 3 < len(rs) and rs[i + 3].get("spot"):
        out["n3"] = (rs[i + 3]["spot"] / r["spot"] - 1) * 100 * d
    if M is not None and i + 1 < len(rs):
        try:
            import oiroom
            t = oiroom.trade(M.get(rs[i + 1]["d"]), r["spot"], d)
            if t and t[0] not in ("LATE", "NO GO"):
                out["trade"] = t
        except Exception:
            pass
    return out


def run(by, m5_of=None):
    R = []
    for sym, rs in by.items():
        M = m5_of(sym) if m5_of else None
        for i in range(1, len(rs) - 1):
            k = kind_of(rs, i)
            if not k:
                continue
            kind, d, chg, why = k
            R.append({"s": sym, "d": rs[i]["d"], "kind": kind, "side": d, "chg": chg, "big": abs(chg) >= 3, "oip": why["oip"], "ran": why["ran"], **next_of(rs, i, d, M)})
    return R


def stats(X):
    n1 = [x["n1"] for x in X if "n1" in x]
    n3 = [x["n3"] for x in X if "n3" in x]
    gp = [x["gap"] for x in X if "gap" in x]
    tr = [x["trade"] for x in X if "trade" in x]
    if not n1:
        return {"n": 0}
    o = {"n": len(n1), "cont1": round(100 * sum(1 for v in n1 if v > 0) / len(n1)), "avg1": round(sum(n1) / len(n1), 2),
         "avg3": round(sum(n3) / len(n3), 2) if n3 else None, "cont3": round(100 * sum(1 for v in n3 if v > 0) / len(n3)) if n3 else None,
         "gap": round(sum(gp) / len(gp), 2) if gp else None}
    if tr:
        o.update({"tn": len(tr), "twin": round(100 * sum(1 for t in tr if t[0] == "WIN") / len(tr)), "tloss": round(100 * sum(1 for t in tr if t[0] == "LOSS") / len(tr)),
                  "tper": round(sum(t[1] for t in tr) / len(tr), 2)})
    return o


def line(o):
    if not o.get("n"):
        return "     0"
    s = "%6d · next day its way %3d%% · avg %+.2f%% · 3 days %s · next open gap %s" % (
        o["n"], o["cont1"], o["avg1"], ("%+.2f%% (%d%% its way)" % (o["avg3"], o["cont3"])) if o.get("avg3") is not None else "—",
        ("%+.2f%%" % o["gap"]) if o.get("gap") is not None else "—")
    if o.get("tn"):
        s += " · morning trade %d: WIN %d%% LOSS %d%% per trade %+.2f%%" % (o["tn"], o["twin"], o["tloss"], o["tper"])
    return s


KINDS = ("NEW MONEY", "FORCED OUT", "BOTH", "NO OI CHANGE")


def report(R):
    days = sorted({x["d"] for x in R})
    L = ["THE PUSH STUDY · NEW MONEY vs FORCED OUT · %d moves of 1.5%%+ · %s .. %s · 'its way' = the move's own direction" % (len(R), days[0] if days else "-", days[-1] if days else "-"),
         "  NEW MONEY = futures OI +2%+ with the move · FORCED OUT = futures OI -2%+ or the crossed wall's writers ran · BOTH = both · NO OI CHANGE = neither", ""]
    J = {"kinds": {}, "at": dt.datetime.now().strftime("%Y-%m-%d %H:%M"), "n": len(R)}
    for d, nm in ((1, "UP"), (-1, "DOWN")):
        L.append("THE SHARE CLOSED %s 1.5%%+" % nm)
        X = [x for x in R if x["side"] == d]
        L.append("  %-14s %s" % ("all", line(stats(X))))
        for k in KINDS:
            Y = [x for x in X if x["kind"] == k]
            o = stats(Y)
            J["kinds"]["%s %s" % (k, nm)] = o
            L.append("  %-14s %s" % (k, line(o)))
            for big, t in ((False, "   1.5-3%"), (True, "   3%+")):
                L.append("  %-14s %s" % (t, line(stats([y for y in Y if y["big"] == big]))))
        L.append("")
    L.append("BY YEAR (the same split, both sides)")
    for y in sorted({x["d"][:4] for x in R}):
        for k in KINDS:
            L.append("  %s %-13s %s" % (y, k, line(stats([x for x in R if x["d"][:4] == y and x["kind"] == k]))))
    L.append("")
    nm_, fo_ = stats([x for x in R if x["kind"] == "NEW MONEY"]), stats([x for x in R if x["kind"] == "FORCED OUT"])
    if nm_.get("n") and fo_.get("n"):
        L.append("IN ONE LINE: after NEW MONEY the next day went on %d%% of the time (avg %+.2f%%), after FORCED OUT %d%% (avg %+.2f%%) - %s" % (
            nm_["cont1"], nm_["avg1"], fo_["cont1"], fo_["avg1"],
            "new money lasts longer" if nm_["avg1"] > fo_["avg1"] + 0.1 else "forced-out lasts longer" if fo_["avg1"] > nm_["avg1"] + 0.1 else "no real difference the next day"))
    return L, J


if __name__ == "__main__":
    import oistudy
    by = oistudy.load()
    m5 = None
    try:
        import study3y as S
        if os.path.isdir(os.path.join(BASE, "data", "h3")):
            m5 = lambda s: S.intraday(s)
    except Exception:
        m5 = None
    R = run(by, m5)
    L, J = report(R)
    txt = "\n".join(L)
    print(txt)
    open(os.path.join(BASE, "data", "pushstudy.txt"), "w").write(txt + "\n")
    json.dump(J, open(os.path.join(BASE, "data", "pushstudy.json"), "w"))
PY_STUDY
cat > $D/p208test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p208test.py - patch 208's own test: the PUSH WATCH on made-up files (a temp folder, stub readers) - no network, nothing sent.
  python3 p208test.py DIR      (DIR = the folder that holds pushwho.py)"""
import os, sys, json, time, shutil, sqlite3, tempfile, importlib, datetime as dt
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
T = tempfile.mkdtemp()
os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "pushwho.py"), T)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
day = str(now.date())
open(os.path.join(T, "whymove.py"), "w").write('''
def explain(sym, now=None):
    R = {"COROMANDEL": [{"k": "filing", "t": "order filing (Tue 10:02): order worth Rs 1,200 cr", "w": 4, "side": 1},
                        {"k": "sector", "t": "the chemicals sector is +1.2% (14 shares) - it moves with its sector", "w": 2, "side": 1},
                        {"k": "broker", "t": "broker (09:40): Jefferies raises target to 2,600", "w": 3, "side": 1}],
         "AXISBANK": [{"k": "filing", "t": "reg filing (Tue 14:00): RBI imposed a penalty", "w": 4, "side": -1}],
         "ITC": [{"k": "market", "t": "NIFTY +0.9% - the whole market", "w": 1, "side": 1}]}
    chg = {"COROMANDEL": 2.4, "SBIN": 1.8, "AXISBANK": -2.1, "ITC": 0.9, "QUIET": 0.1}.get(sym)
    return {"s": sym, "chg": chg, "reasons": R.get(sym, [])}
''')
open(os.path.join(T, "instflow.py"), "w").write('''
def summary():
    return {"w": {"5": {"fii_buy": [{"s": "COROMANDEL", "cr": 140.0, "who": "GOLDMAN SACHS"}], "fii_sell": [], "dii_buy": [], "dii_sell": []}},
            "deliv": {"day": "2026-11-10", "acc": [{"s": "COROMANDEL", "x": 2.3, "extra": 61.0}], "dist": []}}
''')
open(os.path.join(T, "newsroom.py"), "w").write('''
def items_for(sym, hours, x):
    return [{"t": "08:10", "h": "Coromandel set for inclusion in MSCI India index, passive inflows seen"}] if sym == "COROMANDEL" else []
''')
json.dump({"day": day, "fo_paths": [
    {"s": "COROMANDEL", "chg": 2.4, "bu": "LONG_BUILD-UP", "cr": 85.0, "oi": 6.1, "rv": 2.6, "bars": {"mom": 0.9}},
    {"s": "SBIN", "chg": 1.8, "bu": "SHORT COVERING", "cr": 120.0, "oi": -3.2, "rv": 1.1, "bars": {}},
    {"s": "AXISBANK", "chg": -2.1, "bu": "SHORT BUILD-UP", "cr": 60.0, "oi": 4.0},
    {"s": "ITC", "chg": 0.9, "bu": "", "cr": 0},
], "ctx": {"fiidii": {"FII": -2300.5, "DII": 3100.0, "DATE": "10-Nov"}}}, open(os.path.join(T, "dash_state.json"), "w"))
json.dump({"ban": ["AXISBANK"], "shares": {"SBIN": {"lines": {"walls": "roof at 1000 BREAKING: price through it, OI 12.0 L → 8.1 L (writers buying back), premium up · floor 960 (20.1 L, 4.0% away)",
                                                              "strikes": "1000 CE: sellers running"}},
                                           "COROMANDEL": {"lines": {"walls": "calls 2400 was BOUGHT (OI 1.2 L → 2.4 L, premium up) — a bet on UP, not a roof"}}}},
          open(os.path.join(T, "data", "desk.json"), "w"))
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(id integer primary key autoincrement, key text unique, exch text, sym text, name text, t_exch int, t_seen int, kind text, side int, subject text, detail text, link text, verdict text, nums text, pushed int default 0)")
c.execute("insert into filings(key, sym, t_exch, kind, side, subject, detail) values ('a', 'COROMANDEL', ?, 'ROUTINE', 0, 'Disclosure under SEBI Takeover Regulations', 'Acquisition of 0.8% shares by promoter group E.I.D. Parry')", (time.time() - 86400,))
c.execute("insert into filings(key, sym, t_exch, kind, side, subject, detail) values ('b', 'AXISBANK', ?, 'ROUTINE', 0, 'Record Date', 'Record date for final dividend of Rs 1 per share on 14 Nov 2026')", (time.time() - 3 * 86400,))
c.execute("insert into filings(key, sym, t_exch, kind, side, subject, detail) values ('c', 'ITC', ?, 'ROUTINE', 0, 'Trading Window', 'Closure of trading window')", (time.time() - 3600,))
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values (?, '10:05', '🚀', 'COROMANDEL', 'CE', '🚀 RUNNING ▲ COROMANDEL ₹2,410 +2.1%')", (day,))
c.execute("insert into alerts values (?, '10:20', '⚡', 'COROMANDEL', 'CE', '⚡ SPEED ▲ COROMANDEL ₹2,430 +2.4%')", (day,))
c.commit(); c.close()
sys.path.insert(0, T)
import pushwho
OK = []


def chk(name, cond, got=""):
    OK.append(bool(cond))
    print("  %s %s%s" % ("✅" if cond else "❌", name, "" if cond else "   got: %s" % str(got)[:300]))


p = pushwho.read("COROMANDEL")
on = {r["k"]: r for r in p["rows"] if r["on"]}
chk("COROMANDEL: NEW MONEY ▲ (long build-up, calls bought, FII, delivery, promoter, index)", p["kind"] == "NEW MONEY" and p["dir"] == "UP", p["kline"])
chk("COROMANDEL: 9+ of the 12 pushers seen", p["n_on"] >= 9, [r["k"] for r in p["rows"] if r["on"]])
chk("COROMANDEL: promoter buying ▲", on.get("PROMOTER", {}).get("side") == 1, on.get("PROMOTER"))
chk("COROMANDEL: index money ▲ (MSCI)", on.get("INDEX", {}).get("side") == 1, on.get("INDEX"))
chk("COROMANDEL: FII named deal ▲ and delivery (DII / big hands) ▲", on.get("FII", {}).get("side") == 1 and "delivery" in on.get("DII", {}).get("t", ""), (on.get("FII"), on.get("DII")))
chk("COROMANDEL: algos - 2 fast-move alerts, volume 2.6x", "2 fast-move" in on.get("ALGOS", {}).get("t", "") and "2.6x" in on.get("ALGOS", {}).get("t", ""), on.get("ALGOS"))
chk("COROMANDEL: company (order) and brokers (Jefferies) and tide (sector)", "COMPANY" in on and "BROKERS" in on and "TIDE" in on, list(on))
p = pushwho.read("SBIN")
chk("SBIN: FORCED OUT ▲ (short covering + call writers buying back at 1000)", p["kind"] == "FORCED OUT" and p["dir"] == "UP" and "1000" in p["kline"] and "short covering" in p["kline"], p["kline"])
p = pushwho.read("AXISBANK")
on = {r["k"]: r for r in p["rows"] if r["on"]}
chk("AXISBANK: NEW MONEY ▼ (short build-up)", p["kind"] == "NEW MONEY" and p["dir"] == "DOWN", p["kline"])
chk("AXISBANK: regulator ▼ (RBI filing) + the F&O ban", on.get("REGULATOR", {}).get("side") == -1 and "ban" in on.get("REGULATOR", {}).get("t", ""), on.get("REGULATOR"))
chk("AXISBANK: mechanical - the dividend record date", "dividend" in on.get("MECHANICAL", {}).get("t", ""), on.get("MECHANICAL"))
p = pushwho.read("ITC")
chk("ITC: TIDE ONLY (NIFTY up, no money of its own)", p["kind"] == "TIDE ONLY", p)
chk("ITC: the trading-window filing is not a promoter push", not any(r["k"] == "PROMOTER" and r["on"] for r in p["rows"]), p["rows"])
p = pushwho.read("QUIET")
chk("QUIET: no push, no line", p["kind"] == "" and p["kline"] == "", p)
# the alert line
t = pushwho.add_line("🟠 OI ▲ SBIN · CE · ₹1,004 +1.8% · 11:20\nroom: 4.1% to 1,045 ✅")
chk("an 🟠 OI alert gets a ⚙️ push: line", t.endswith("") and "\n⚙️ push: 🟠 ▲ FORCED OUT" in t, t)
chk("…once only", pushwho.add_line(t) == t)
t = pushwho.add_line("🟢 GO · COROMANDEL ▲ CE · 09:16\ngap +1.7%")
chk("a 🟢 GO alert gets the line (its symbol before the arrow)", "⚙️ push: 🟢 ▲ NEW MONEY" in t, t)
chk("a system line is untouched", pushwho.add_line("🟡 DIGEST · 09:15–09:30 · 12 quiet alerts") == "🟡 DIGEST · 09:15–09:30 · 12 quiet alerts")
chk("an index line is untouched", pushwho.add_line("🚀 RUNNING ▲ NIFTY 25,100 +1.1%") == "🚀 RUNNING ▲ NIFTY 25,100 +1.1%")
# the study's numbers join the line
json.dump({"kinds": {"FORCED OUT UP": {"n": 412, "cont1": 44, "avg1": -0.2}}}, open(os.path.join(T, "data", "pushstudy.json"), "w"))
pushwho._F.clear(); pushwho._C.clear()
chk("the study's numbers are added when they exist", "measured: went on its way the next day 44% of 412" in pushwho.read("SBIN")["kline"], pushwho.read("SBIN")["kline"])
# a broken file never breaks an alert
open(os.path.join(T, "dash_state.json"), "w").write("{broken")
pushwho._F.clear(); pushwho._C.clear()
chk("a broken state file: the alert passes unchanged", pushwho.add_line("🚀 RUNNING ▲ ITC ₹410 +0.9%").startswith("🚀 RUNNING ▲ ITC"))
shutil.rmtree(T, ignore_errors=True)
print("PUSH WATCH test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p208_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p208_patch.py - PATCH 208: THE PUSH WATCH wired in - the "⚙️ push:" line on every move / OI / GO alert (tgq.send, so every sender),
the WHO IS PUSHING board on the share card (dashserve + the page), the push kind on the IMPORTANT rows, and the desk's futures agent
voting in EVERY sector (it voted only in sectors of 15+ shares - oil-gas, metals, power, auto, insurance ... had none).
Usage: python3 p208_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("tgq.py", '''    """queue one message on its channel's own queue; returns at once (True = queued). The thread starts on first use."""
''', '''    """queue one message on its channel's own queue; returns at once (True = queued). The thread starts on first use."""
    try:                                                        # patch 208: "⚙️ push:" - who is pushing (new money / forced out / both / tide)
        import pushwho
        text = pushwho.add_line(text)
    except Exception as ex:
        print("pushwho: %s" % str(ex)[:80])
''', "the push line on every sender's alerts")
rep("dashserve.py", '''        c["why"] = whymove.explain(sym)
    except Exception:
        pass''', '''        c["why"] = whymove.explain(sym)
    except Exception:
        pass
    try:                                                        # patch 208: WHO IS PUSHING - the 12 pushers, the kind of push
        import pushwho
        c["push"] = pushwho.read(sym)
    except Exception:
        pass''', "the share card gets the push board")
rep("desk.py", '''    def __init__(self, sectors_map=None, normal=None, big=15, fetch_ban=True, news=True):''',
    '''    def __init__(self, sectors_map=None, normal=None, big=1, fetch_ban=True, news=True):   # patch 208: the futures agent in EVERY sector (was 15+ shares)''',
    "the futures agent votes in every sector")
rep("home.html", '''  return `<div class="shi">${whyH}''', '''  const PW=c&&c.push&&c.push.rows?c.push:null;   /* patch 208: WHO IS PUSHING - the 12 pushers */
  const pushH=PW?`<div class="pwb" style="grid-column:1/-1"><small>WHO IS PUSHING · ${PW.n_on} of 12 seen${PW.kline?"":" · no clear push"}</small>${PW.kline?`<b class="${PW.kind==="FORCED OUT"?"am":PW.kind==="TIDE ONLY"?"dim":PW.dir==="UP"?"pu":"pd"}">${esc(PW.kline)}</b>${PW.advice?`<br><span class="dim">${esc(PW.advice)}</span>`:""}`:""}<div class="pwg">${PW.rows.map(r=>`<span class="${r.on?(r.side>0?"u":r.side<0?"d":"o"):"x"}" title="${esc(r.who+(r.t?": "+r.t:" - nothing seen"))}">${r.n} ${esc(r.k)} ${r.on?(r.side>0?"▲":r.side<0?"▼":"●"):"○"}</span>`).join("")}</div>${PW.rows.filter(r=>r.on).map(r=>`<div class="pwl"><b class="${r.side>0?"pu":r.side<0?"pd":""}">${esc(r.k)}</b> ${esc(r.t)}</div>`).join("")}</div>`:"";
  return `<div class="shi">${whyH}${pushH}''', "the share card: WHO IS PUSHING")
rep("home.html", '''${late?'<em class="lt" title="it had already moved 3%+ its way">LATE</em>':""}''',
    '''${late?'<em class="lt" title="it had already moved 3%+ its way">LATE</em>':""}${(()=>{ const pl=(r.lines||[]).find(x=>/^⚙️ push:/.test(x))||""; const k=/BOTH/.test(pl)?["pb","🟢🟠 BOTH"]:/NEW MONEY/.test(pl)?["pn","🟢 NEW MONEY"]:/FORCED OUT/.test(pl)?["pf","🟠 FORCED OUT · book early"]:/TIDE ONLY/.test(pl)?["pt","⚪ TIDE ONLY"]:null; return k?`<em class="pk ${k[0]}" title="${esc(pl)}">${k[1]}</em>`:""; })()}''',
    "IMPORTANT rows: the kind of push")
rep("home.html", '''/* patch 207: SECTORS short bars in columns''', '''/* patch 208: WHO IS PUSHING */
.pwb .pwg{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:3px;margin:5px 0 4px}
.pwb .pwg span{font:600 10.5px/1.6 var(--ui);padding:0 6px;border-radius:3px;border:1px solid var(--line2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:help}
.pwb .pwg .x{color:var(--dim);opacity:.55}.pwb .pwg .u{color:var(--up);border-color:var(--up)}.pwb .pwg .d{color:var(--dn);border-color:var(--dn)}.pwb .pwg .o{color:var(--txt)}
.pwb .pwl{font-size:11.5px;line-height:1.4;color:var(--txt)}.pwb .pwl b{display:inline-block;min-width:84px;font-size:10.5px;letter-spacing:.04em}
#mk-act .im em.pk.pn,#mk-act .im em.pk.pb{color:var(--up)}#mk-act .im em.pk.pf{color:#1a1205;background:var(--amber)}#mk-act .im em.pk.pt{color:var(--dim)}
/* patch 207: SECTORS short bars in columns''', "the look")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 208 wired in")
PY_PATCH
cd $D && python3 -m py_compile pushwho.py pushstudy.py || back
echo "=== the push watch's own test (made-up files - nothing sent)"
timeout 60 python3 $D/p208test.py $D > /tmp/p208test.out 2>&1; R=$?
grep -E "✅|❌|passed" /tmp/p208test.out; [ $R = 0 ] || back
echo "=== patch 208"
python3 $W/p208_patch.py $D || back
python3 -m py_compile tgq.py dashserve.py desk.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "=== on today's real data: who pushed the day's biggest movers"
cd $D && timeout 60 python3 - <<'PY_REAL'
import json, pushwho
try:
    fp = json.load(open("dash_state.json")).get("fo_paths") or []
except Exception:
    fp = []
top = [x["s"] for x in sorted([x for x in fp if x.get("chg") is not None], key=lambda x: -abs(x["chg"]))[:4]] or ["COROMANDEL", "SBIN"]
for s in top + ["COROMANDEL", "CHAMBLFERT"]:
    p = pushwho.read(s)
    print("  %-11s %s · %d of 12 seen · %s" % (s, ("%+.2f%%" % p["chg"]) if p["chg"] is not None else "?", p["n_on"], p["kline"][:150] or "no clear push"))
PY_REAL
cat > $U/gir-pushstudy.service <<'UNIT'
[Unit]
Description=GIR THE PUSH STUDY - new money vs forced out, what came next (reads only)
[Service]
Type=oneshot
TimeoutStartSec=3600
Nice=10
ExecStart=/bin/bash -c 'cd /home/globalbot/intraday && python3 pushstudy.py > data/pushstudy.out 2>&1'
UNIT
cat > $U/gir-pushstudy.timer <<'UNIT'
[Unit]
Description=GIR THE PUSH STUDY every weekday 20:15
[Timer]
OnCalendar=Mon..Fri *-*-* 20:15:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable gir-pushstudy.timer >/dev/null 2>&1 && systemctl start gir-pushstudy.timer
echo "=== restarting the desk, the engine, the newsroom, the exchange reader, TV watch and the page"
for s in gir-desk gir-intraday gir-newsroom gir-exchange gir-tvwatch gir-dash; do systemctl restart $s 2>/dev/null && echo "  $s restarted"; done
sleep 20
for s in gir-desk gir-intraday gir-newsroom gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
echo "=== THE PUSH STUDY runs now in the background (a few minutes): systemctl start --no-block gir-pushstudy"
systemctl start --no-block gir-pushstudy.service
echo
echo "✅ patch 208 done. Ctrl + Shift + R on GIR."
echo "   every move / OI / GO alert: a ⚙️ push: line · tap a share: WHO IS PUSHING (12 boxes) · IMPORTANT rows: 🟢 NEW MONEY / 🟠 FORCED OUT"
echo "   the study's result in ~5-10 min:   cat /home/globalbot/intraday/data/pushstudy.txt"
echo "   undo: for f in $FILES; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-desk gir-intraday gir-newsroom gir-exchange gir-tvwatch gir-dash"
