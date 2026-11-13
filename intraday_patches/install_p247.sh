#!/bin/bash
# PATCH 247 - 🏦 MACRO WARNING (Rama, 13 Nov 12:18: "you should warn me that due to the rate hikes the NBFC and banking sector will take a hit").
#   GIR's market-news reader saw "RBI May Hike Interest Rates Amid Rising Food Inflation Risks" at 08:00 but nothing said "watch NBFCs and banks"
#   (they fell 1.4% / 0.8%). Now: rate-hike fears / rate-cut hopes · US Fed · crude · rupee · US tariffs -> the sectors that move first:
#   - 08:30 📅 THE WEEK: the macro news since the close and the sectors to watch (▼ / ▲)
#   - 09:20-15:20 every 2 min: when those sectors REALLY move that way -> one ringing 🏦 MACRO WARNING to Box Picks (once a theme a day;
#     the same sectors are not warned twice); an actual RBI / Fed decision rings at once
#   - 15:25: each warning scored by the close (data/macrowarn.json)
#   Tested: 16 headlines + 11 cases (13 Nov replayed). No service restart (its own timer); safe any time - best with 242 in first.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
F="tglanes.py alertword.py home.html"; [ -f $D/weekview.py ] && F="$F weekview.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/macrowarn.py $U/gir-macrowarn.service $U/gir-macrowarn.timer; systemctl daemon-reload; echo "❌ old files back - nothing changed"; exit 1; }
cat > $D/macrowarn.py <<'PY_MW'
#!/usr/bin/env python3
"""macrowarn.py - patch 247: 🏦 MACRO WARNING (Rama, 13 Nov 12:18: "you should warn me that due to the rate hikes the NBFC and banking sector will
take a hit"). GIR's market-news reader (macro.py, data/macro.json) saw "RBI May Hike Interest Rates Amid Rising Food Inflation Risks" at 08:00, but
nothing turned it into "watch NBFCs and banks" - they fell 1.4% / 0.8%.
  THEMES      rate-hike fears · rate-cut hopes · US Fed hawkish / dovish · crude up / down · rupee weak / strong · US tariffs on India
              -> the sectors that usually move first, and which way (plain rules, not forecasts)
  08:30       premarket_lines(): the 📅 THE WEEK message shows the macro news since the close and the sectors to watch
  09:20-15:20 every 2 min: when those sectors are REALLY moving the expected way (avg 0.4%+, 60% of their F&O shares) -> one ringing
              🏦 MACRO WARNING to Box Picks (once a theme a day). An actual RBI / Fed decision (not "may") rings at once.
  15:25+      each warning scored by the close: did the named sectors end the expected way? (data/macrowarn.json)
  python3 macrowarn.py            what it sees now (nothing sent)        python3 macrowarn.py --send     the timer's run"""
import os, re, sys, json, time, sqlite3, datetime as dt
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
STATE = os.path.join(BASE, "data", "macrowarn.json")
REALTY = ["DLF", "LODHA", "GODREJPROP", "OBEROIRLTY", "PRESTIGE", "PHOENIXLTD", "BRIGADE", "SOBHA"]
OMC = ["BPCL", "HINDPETRO", "IOC"]
PAINTS = ["ASIANPAINT", "BERGEPAINT", "INDIGOPNTS", "KANSAINER"]
AIR = ["INDIGO"]
UPSTREAM = ["ONGC", "OIL"]
SPEC = re.compile(r"\b(may|might|could|likely|fears?|risks?|expected|seen|poll|bets?|hints?|signals?|odds|worr\w*|warns?|concerns?|pressure|ahead of|wait)\b", re.I)


def groups():
    """{label: [F&O symbols]} from GIR's sector map + a few exact lists"""
    try:
        import sectors
        m = sectors.hand_map()
    except Exception:
        m = {}
    g = {"BANKS": m.get("banks", []), "NBFC & FINANCE": [s for s in m.get("nbfc", []) if s not in m.get("insurance", [])], "REALTY": REALTY,
         "AUTO": m.get("auto", []), "IT": m.get("it", []), "PHARMA": m.get("pharma", []), "AUTO PARTS": m.get("auto-anc", []),
         "OIL MARKETING": OMC, "PAINTS": PAINTS, "AVIATION": AIR, "OIL PRODUCERS": UPSTREAM}
    fo = fo_set()
    return {k: [s for s in v if not fo or s in fo] for k, v in g.items()}


def fo_set():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=5)
        v = {r[0] for r in c.execute("select sym from fo_list")}; c.close(); return v
    except Exception:
        return set()


RB = r"\b(rbi|reserve bank|repo|mpc|monetary policy|interest rates?|rate hikes?|rate cuts?|policy rates?)\b"
THEMES = [   # (key, name, regex - all must match, down groups, up groups, what it means)
    ("RATE_UP", "RATE-HIKE FEARS", [RB + r".*\b(hikes?|hiking|raise[sd]?|tighten\w*|hawkish|higher)\b|\b(hikes?|raise[sd]?)\b.*" + RB,
                                    r"\b(rbi|reserve bank|repo|india|indian|mpc|inflation|cpi|wpi)\b"],
     ["NBFC & FINANCE", "BANKS", "REALTY", "AUTO"], [], "higher interest rates make loans dearer - lenders, home and car buying feel it first"),
    ("RATE_UP", "RATE-HIKE FEARS", [r"\b(inflation|cpi|wpi|food prices?)\b", r"\b(ris\w+|jumps?|spikes?|surges?|high\w*|upside risks?|accelerat\w+|soars?|climbs?)\b",
                                    r"\b(india|indian|rbi|retail|food|cpi|wpi|monsoons?|el nino)\b"],
     ["NBFC & FINANCE", "BANKS", "REALTY", "AUTO"], [], "rising inflation makes an RBI rate hike more likely - lenders, home and car buying feel it first"),
    ("RATE_DOWN", "RATE-CUT HOPES", [RB + r".*\b(cuts?|cutting|lower\w*|eas\w+|dovish|reduce[sd]?)\b|\b(rate cuts?)\b"],
     [], ["NBFC & FINANCE", "BANKS", "REALTY", "AUTO"], "cheaper loans help lenders, home and car buying first"),
    ("FED_UP", "US FED HAWKISH", [r"\b(fed|federal reserve|fomc|powell|us yields?|treasury yields?)\b", r"\b(hikes?|hawkish|higher for longer|ris\w+|surg\w+|jumps?|climbs?)\b"],
     ["BANKS", "NBFC & FINANCE"], [], "higher US rates pull foreign money (FIIs) out of India - banks and finance get sold first"),
    ("FED_DOWN", "US FED DOVISH", [r"\b(fed|federal reserve|fomc|powell)\b", r"\b(cuts?|cutting|dovish|eas\w+|pause)\b"],
     [], ["BANKS", "NBFC & FINANCE"], "lower US rates bring foreign money (FIIs) back - banks and finance get bought first"),
    ("CRUDE_UP", "CRUDE OIL RISING", [r"\b(crude|brent|oil prices?)\b", r"\b(ris\w+|jumps?|surg\w+|spikes?|climbs?|soars?|higher|gains?|rall\w+)\b"],
     ["OIL MARKETING", "PAINTS", "AVIATION"], ["OIL PRODUCERS"], "dearer crude squeezes fuel sellers, paint makers and airlines; helps ONGC / Oil India"),
    ("CRUDE_DOWN", "CRUDE OIL FALLING", [r"\b(crude|brent|oil prices?)\b", r"\b(falls?|fell|drops?|slumps?|plunges?|slides?|tumbles?|lower|declines?|eases?)\b"],
     ["OIL PRODUCERS"], ["OIL MARKETING", "PAINTS", "AVIATION"], "cheaper crude helps fuel sellers, paint makers and airlines; hurts ONGC / Oil India"),
    ("RUPEE_WEAK", "RUPEE WEAK", [r"\brupee\b", r"\b(falls?|fell|weakens?|record low|all-time low|slides?|depreciat\w+|slumps?|lowest)\b"],
     ["OIL MARKETING"], ["IT", "PHARMA"], "a weaker rupee helps exporters (IT, pharma), makes imported crude dearer"),
    ("RUPEE_STRONG", "RUPEE STRONG", [r"\brupee\b", r"\b(rises?|gains?|strengthens?|appreciat\w+|jumps?|rall\w+)\b"],
     ["IT"], ["OIL MARKETING"], "a stronger rupee trims exporters' earnings (IT), makes crude cheaper"),
    ("TARIFF", "US TARIFFS ON INDIA", [r"\b(tariffs?|trade war|sanctions?)\b", r"\b(india|indian)\b"],
     ["IT", "PHARMA", "AUTO PARTS"], [], "tariffs hit exporters - IT, pharma and auto parts first")]


def theme_of(h):
    """-> (key, name, down, up, why, decided) or None"""
    t = (h or "").lower()
    for key, name, rxs, dn, up, why in THEMES:
        if all(re.search(r, t) for r in rxs):
            decided = key in ("RATE_UP", "RATE_DOWN", "FED_UP", "FED_DOWN") and \
                bool(re.search(r"\b(rbi|reserve bank|mpc|fed|federal reserve|fomc)\s+(hikes|raises|cuts|slashes|lowers)\b", t)) and \
                not re.search(r"\b(may|might|could|likely|expected|seen|poll|bets?|odds|if|would)\b", t)
            return key, name, dn, up, why, decided
    return None


def headlines(since, now):
    """the market headlines GIR kept (macro.json) between since and now, trusted sources, with a theme"""
    try:
        j = json.load(open(os.path.join(BASE, "data", "macro.json")))
    except Exception:
        return []
    try:
        import macro
        trusted = macro.trusted
    except Exception:
        trusted = lambda s: True
    out = []
    for it in j.get("items") or []:
        t = float(it.get("t") or 0)
        if since <= t <= now + 60 and trusted(it.get("src")):
            th = theme_of(it.get("h"))
            if th:
                out.append(dict(it, th=th))
    return sorted(out, key=lambda x: x["t"])


def quotes():
    try:
        j = json.load(open(os.path.join(BASE, "quotes_live.json")))
        if time.time() - float(j.get("t") or 0) > 120:
            return {}
        return {s: v[1] for s, v in (j.get("q") or {}).items() if v and v[1] is not None}
    except Exception:
        return {}


def gmove(q, syms):
    v = [q[s] for s in syms if s in q]
    if not v:
        return None
    return {"avg": sum(v) / len(v), "n": len(v), "dn": sum(x < 0 for x in v), "up": sum(x > 0 for x in v),
            "worst": sorted([(q[s], s) for s in syms if s in q])[:3], "best": sorted([(q[s], s) for s in syms if s in q], reverse=True)[:3]}


def confirms(m, side):
    """the group is really moving that way: avg 0.4%+ and 60% of its shares"""
    if not m:
        return False
    k = m["dn"] if side < 0 else m["up"]
    return (m["avg"] <= -0.4 if side < 0 else m["avg"] >= 0.4) and k >= 0.6 * m["n"]


def last_close(now):
    try:
        import holidays
        d = now.date() - dt.timedelta(days=1)
        while holidays.holiday(d):
            d -= dt.timedelta(days=1)
    except Exception:
        d = now.date() - dt.timedelta(days=1)
        while d.weekday() >= 5:
            d -= dt.timedelta(days=1)
    return dt.datetime.combine(d, dt.time(15, 30), IST)


def premarket_lines(now=None):
    """for 📅 THE WEEK at 08:30: the macro news since the last close and the sectors to watch"""
    now = now or dt.datetime.now(IST)
    H = headlines(last_close(now).timestamp(), now.timestamp())
    seen, L = set(), []
    for it in H[::-1]:
        key, name, dn, up, why, decided = it["th"]
        if key in seen:
            continue
        seen.add(key)
        side = ("▼ watch " + " · ".join(dn)) if dn else ""
        side += ((" · " if side else "") + "▲ " + " · ".join(up)) if up else ""
        L.append("  %s%s - \"%s\" (%s %s) → %s" % (name, " (DECIDED)" if decided else "", it["h"][:110], it.get("src", ""), it.get("hm", ""), side))
        L.append("     why: %s" % why)
    if L:
        L = ["🏦 MACRO - the news since the close that moves whole sectors"] + L + \
            ["  CEs on the ▼ sectors need extra care today; GIR rings 🏦 MACRO WARNING if their prices confirm it"]
    return L


def warn_text(it, now, q, G):
    key, name, dn, up, why, decided = it["th"]
    rows, weak = [], []
    for lab, side in [(x, -1) for x in dn] + [(x, 1) for x in up]:
        m = gmove(q, G.get(lab, []))
        if not m:
            continue
        ok = confirms(m, side)
        rows.append("%s %s %+.1f%% (%d of %d %s)%s" % ("▼" if side < 0 else "▲", lab, m["avg"], m["dn"] if side < 0 else m["up"], m["n"],
                                                     "down" if side < 0 else "up", "" if ok else " - not yet"))
        if ok:
            weak += m["worst"] if side < 0 else m["best"]
    L = ["🏦 MACRO WARNING · %s · %s" % (name, now.strftime("%H:%M")),
         "the news: \"%s\" (%s %s)%s" % (it["h"][:160], it.get("src", ""), it.get("hm", ""), " - a DECISION" if decided else ""),
         "why: " + why,
         "in the prices now: " + " · ".join(rows)]
    if weak:
        L.append("most hit: " + " · ".join("%s %+.1f%%" % (s, v) for v, s in sorted(weak, key=lambda x: abs(x[0]), reverse=True)[:6]))
    if dn:
        L.append("for you: careful with CEs (bets on a rise) on the ▼ shares today - the whole group is moving on the news, not one company. "
                 "A PE fits only if the share is also weak on its own chart.")
    if not decided:
        L.append("(a worry in the news, not a decision - it can reverse if nothing more comes)")
    return "\n".join(L)


def run(now=None, send=None):
    """the timer: -> list of texts sent"""
    now = now or dt.datetime.now(IST)
    try:
        import holidays
        if holidays.holiday(now.date()):
            return []
    except Exception:
        if now.weekday() >= 5:
            return []
    try:
        st = json.load(open(STATE))
    except Exception:
        st = {}
    day = str(now.date())
    W = st.setdefault(day, {})
    out = []
    q = quotes()
    G = groups()
    if dt.time(9, 20) <= now.time() <= dt.time(15, 20) and q:
        H = headlines(min(last_close(now).timestamp(), now.timestamp() - 6 * 3600), now.timestamp())
        for it in H[::-1]:
            key, name, dn, up, why, decided = it["th"]
            if key in W:
                continue
            gs = [(x, -1) for x in dn] + [(x, 1) for x in up]
            covered = {(x, -1) for w in W.values() for x in w.get("down", [])} | {(x, 1) for w in W.values() for x in w.get("up", [])}
            if gs and set(gs) <= covered:                       # the same sectors, the same way, already warned today - one ring, not two
                continue
            ok = [x for x, sd in gs if confirms(gmove(q, G.get(x, [])), sd)]
            if decided or (gs and len(ok) >= max(1, (len(gs) + 1) // 2)):
                txt = warn_text(it, now, q, G)
                (send or (lambda t: __import__("opencall").send_tg(t)))(txt)
                W[key] = {"t": now.timestamp(), "hm": now.strftime("%H:%M"), "h": it["h"], "name": name, "down": dn, "up": up,
                          "at": {x: round(gmove(q, G.get(x, []))["avg"], 2) for x, sd in gs if gmove(q, G.get(x, []))}}
                out.append(txt)
    if now.time() >= dt.time(15, 25) and q:                    # the close: right or wrong
        for key, w in W.items():
            if "close" in w:
                continue
            gs = [(x, -1) for x in w.get("down", [])] + [(x, 1) for x in w.get("up", [])]
            cl = {x: round(gmove(q, G.get(x, []))["avg"], 2) for x, sd in gs if gmove(q, G.get(x, []))}
            right = sum(1 for x, sd in gs if x in cl and cl[x] * sd > 0)
            w.update({"close": cl, "right": right, "of": len([x for x, sd in gs if x in cl])})
    try:
        json.dump({k: v for k, v in st.items() if k >= str(now.date() - dt.timedelta(days=60))}, open(STATE + ".tmp", "w")); os.replace(STATE + ".tmp", STATE)
    except Exception:
        pass
    return out


if __name__ == "__main__":
    if "--send" in sys.argv:
        r = run()
        print("\n\n".join(r) if r else "nothing to warn")
    else:
        now = dt.datetime.now(IST)
        print("\n".join(premarket_lines(now)) or "no macro news since the close")
        q = quotes(); G = groups()
        for it in headlines(now.timestamp() - 8 * 3600, now.timestamp())[::-1][:6]:
            print("\n" + warn_text(it, now, q, G))
PY_MW
cat > $W/p247test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p247test.py - 🏦 MACRO WARNING over 13 Nov replayed (made-up files, nothing sent). python3 p247test.py DIR (macrowarn.py in DIR)"""
import os, sys, json, time, shutil, sqlite3, tempfile, datetime as dt
SRC = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(SRC, "macrowarn.py"), T)
open(os.path.join(T, "holidays.py"), "w").write("import datetime as dt\ndef holiday(d):\n    return 'weekend' if d.weekday() >= 5 else None\n")
open(os.path.join(T, "macro.py"), "w").write("def trusted(s):\n    return 'blog' not in (s or '').lower()\n")
SEC = {"banks": ["HDFCBANK", "ICICIBANK", "SBIN", "AXISBANK", "KOTAKBANK"], "nbfc": ["BAJFINANCE", "CHOLAFIN", "SHRIRAMFIN", "MUTHOOTFIN", "MANAPPURAM"],
       "insurance": [], "auto": ["MARUTI", "M&M", "TATAMOTORS", "EICHERMOT"], "it": ["INFY", "TCS", "WIPRO"], "pharma": ["SUNPHARMA", "CIPLA", "LUPIN"], "auto-anc": []}
open(os.path.join(T, "sectors.py"), "w").write("def hand_map():\n    return %r\n" % SEC)
ALL = sum(SEC.values(), []) + ["DLF", "LODHA", "GODREJPROP", "BPCL", "HINDPETRO", "IOC", "ASIANPAINT", "INDIGO", "ONGC", "OIL"]
c = sqlite3.connect(os.path.join(T, "chains.db")); c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,1)", [(s,) for s in ALL]); c.commit(); c.close()
IST = dt.timezone(dt.timedelta(hours=5, minutes=30)); D = dt.datetime(2026, 11, 13, tzinfo=IST)
at = lambda h, m: D.replace(hour=h, minute=m)
items = [{"k": "a", "t": at(7, 45).timestamp(), "hm": "07:45", "h": "Gold prices rise above Rs 1.36 lakh/10g, silver slides on MCX amid Fed rate hike worries", "src": "Moneycontrol", "score": 4, "side": -1},
         {"k": "b", "t": at(8, 0).timestamp(), "hm": "08:00", "h": "RBI May Hike Interest Rates Amid Rising Food Inflation Risks in FY27", "src": "Business Standard", "score": 5, "side": -1},
         {"k": "c", "t": at(8, 5).timestamp(), "hm": "08:05", "h": "Crude oil prices surge 4% as OPEC+ cuts output", "src": "some blog", "score": 3, "side": -1}]
json.dump({"items": items}, open(os.path.join(T, "data", "macro.json"), "w"))
def quotes(when, mv):
    q = {s: [100, mv.get(s, 0.05)] for s in ALL}
    json.dump({"t": time.time(), "q": q}, open(os.path.join(T, "quotes_live.json"), "w"))
sys.path.insert(0, T); os.chdir(T)
import macrowarn as M
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
L = "\n".join(M.premarket_lines(at(8, 30)))
chk("08:30 THE WEEK: RATE-HIKE FEARS · ▼ watch NBFC & FINANCE · BANKS · REALTY · AUTO", "RATE-HIKE FEARS" in L and "▼ watch NBFC & FINANCE · BANKS · REALTY · AUTO" in L, L)
chk("... the Fed worry shown too; the crude line from an untrusted blog is not", "US FED HAWKISH" in L and "CRUDE" not in L, L)
S = []
quotes(at(9, 25), {})
chk("09:25, sectors flat: no warning (a headline alone does not ring)", M.run(at(9, 25), S.append) == [] and not S)
FALL = {"BAJFINANCE": -1.3, "CHOLAFIN": -1.2, "SHRIRAMFIN": -2.9, "MUTHOOTFIN": -2.7, "MANAPPURAM": -3.4, "HDFCBANK": -1.3, "ICICIBANK": -0.6, "SBIN": -0.9,
        "AXISBANK": -0.7, "KOTAKBANK": 0.2, "DLF": -0.8, "LODHA": -0.5, "GODREJPROP": 0.1, "MARUTI": -0.9, "M&M": -1.1, "TATAMOTORS": -0.3, "EICHERMOT": 0.2}
quotes(at(12, 18), FALL)
r = M.run(at(12, 18), S.append)
t = S[0] if S else ""
chk("12:18, NBFCs / banks falling: ONE 🏦 MACRO WARNING (not one for RBI and one more for the Fed)", len(S) == 1 and t.startswith("🏦 MACRO WARNING · RATE-HIKE FEARS"), S)
chk("... the news, the sectors' real moves, and what was hit most", "RBI May Hike" in t and "▼ NBFC & FINANCE -2.3% (5 of 5 down)" in t and "most hit: MANAPPURAM -3.4%" in t, t)
chk("... plain advice + 'a worry, not a decision'", "careful with CEs" in t and "not a decision" in t, t)
chk("12:20: not repeated", M.run(at(12, 20), S.append) == [] and len(S) == 1)
json.dump({"items": items + [{"k": "d", "t": at(14, 0).timestamp(), "hm": "14:00", "h": "RBI hikes repo rate by 25 bps to 6.75% in surprise move", "src": "Reuters", "score": 6, "side": -1}]},
          open(os.path.join(T, "data", "macro.json"), "w"))
st = json.load(open(os.path.join(T, "data", "macrowarn.json"))); st["2026-11-14x"] = {}; json.dump(st, open(os.path.join(T, "data", "macrowarn.json"), "w"))
D2 = dt.datetime(2026, 11, 16, tzinfo=IST)
json.dump({"items": [{"k": "e", "t": D2.replace(hour=14).timestamp(), "hm": "14:00", "h": "RBI hikes repo rate by 25 bps to 6.75% in surprise move", "src": "Reuters", "score": 6, "side": -1}]},
          open(os.path.join(T, "data", "macro.json"), "w"))
quotes(None, {})
S2 = []
M.run(D2.replace(hour=14, minute=2), S2.append)
chk("Mon 14:02, an actual RBI hike: rings at once, prices not yet moved, marked a DECISION", len(S2) == 1 and "a DECISION" in S2[0] and "not a decision" not in S2[0], S2)
quotes(None, FALL)
M.run(at(15, 26), S.append)
w = json.load(open(os.path.join(T, "data", "macrowarn.json")))["2026-11-13"]["RATE_UP"]
chk("15:26: scored by the close - 4 of 4 named sectors ended down", w.get("right") == 4 and w.get("of") == 4, w)
sat = dt.datetime(2026, 11, 14, 11, 0, tzinfo=IST)
chk("Saturday: nothing", M.run(sat, S.append) == [] )
json.dump({"t": time.time() - 600, "q": {}}, open(os.path.join(T, "quotes_live.json"), "w"))
chk("live prices 10 min old: nothing (no warning on stale prices)", M.run(D2.replace(hour=11), S.append) == [])
print("MACRO WARNING test: %d of %d passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
cat > $W/p247_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p247_patch.py - PATCH 247: 🏦 MACRO WARNING wired in - it rings in Box Picks (like the morning brief), the page knows it, and 📅 THE WEEK at 08:30
shows the macro news since the close. Usage: python3 p247_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, optional=False):
    p = os.path.join(D, f)
    if optional and not os.path.exists(p):
        print("  %s: not on this server - %s skipped" % (f, tag)); return
    s = open(p, encoding="utf-8").read()
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("tglanes.py", '''CRIT_RE = re.compile(r"TODAY'S PATTERN|MORNING BRIEF|''', '''CRIT_RE = re.compile(r"MACRO WARNING|TODAY'S PATTERN|MORNING BRIEF|''', "MACRO WARNING -> Box Picks")
rep("alertword.py", '''    if "MORNING BRIEF" in H2 or "TODAY'S PATTERN" in H2:''', '''    if "MORNING BRIEF" in H2 or "TODAY'S PATTERN" in H2 or "MACRO WARNING" in H2:   # patch 247''', "MACRO WARNING rings")
rep("home.html", '''  if(/MORNING BRIEF|TODAY'S PATTERN/.test(H)) return "move";''', '''  if(/MORNING BRIEF|TODAY'S PATTERN|MACRO WARNING/.test(H)) return "move";   /* patch 247 */''', "the page: MACRO WARNING")
rep("weekview.py", '''    M = []                                                          # plain reminders - from the facts above, not calls''',
    '''    try:                                                        # patch 247: 🏦 MACRO - the news since the close that moves whole sectors
        import macrowarn
        MW = macrowarn.premarket_lines(now)
        if MW:
            L += [""] + MW
    except Exception as ex_:
        print("macrowarn: %s" % ex_)
    M = []                                                          # plain reminders - from the facts above, not calls''', "08:30 THE WEEK shows the macro news", optional=True)
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 247 in")
PY_PATCH
cd $D && python3 -m py_compile macrowarn.py || back
echo "=== test: 13 Nov replayed"
python3 $W/p247test.py $D || back
python3 $W/p247_patch.py $D || back
cd $D && python3 -m py_compile tglanes.py alertword.py macrowarn.py && { [ ! -f weekview.py ] || python3 -m py_compile weekview.py; } || back
python3 -c "import sys; sys.path.insert(0, '$D'); import tglanes; print('   routing: MACRO WARNING ->', tglanes.lane('🏦 MACRO WARNING · RATE-HIKE FEARS · 12:18'))" || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
cat > $U/gir-macrowarn.service <<'UNIT'
[Unit]
Description=GIR MACRO WARNING (rates / Fed / crude / rupee / tariffs -> the sectors that move first)
[Service]
Type=oneshot
TimeoutStartSec=90
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 macrowarn.py --send >> data/macrowarn.log 2>&1'
UNIT
cat > $U/gir-macrowarn.timer <<'UNIT'
[Unit]
Description=GIR MACRO WARNING, every 2 min in market hours
[Timer]
OnCalendar=Mon..Fri *-*-* 09..15:00/2:50 Asia/Kolkata
AccuracySec=10s
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-macrowarn.timer >/dev/null 2>&1 || back
echo "=== what it sees on this server today (nothing sent):"
cd $D && timeout 60 python3 macrowarn.py 2>&1 | head -30
echo "✅ patch 247 done - 🏦 MACRO WARNING in the 08:30 recap and live when the sectors confirm; timer: $(systemctl is-enabled gir-macrowarn.timer)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-macrowarn.timer; rm $D/macrowarn.py"
