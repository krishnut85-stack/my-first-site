#!/bin/bash
# PATCH 169c - the morning brief, fixed after its first look (11 Nov 08:44):
#   * the shares' lines showed the ring tag ("🟠 SOMETHING IS HAPPENING ...") instead of the news itself
#   * NSE's PDF letters ("Adjudica0ng", "en0re") read back as "Adjudicating", "entire"
#   * a regulator order IN FAVOUR of the company (BHEL: the demand dropped) is GOOD NEWS, not trouble
#   + sends TODAY's brief now (it was installed after 08:30). Nothing restarts.
set -u
D=/home/globalbot/intraday
[ -f $D/morningbrief.py ] || { echo "install_p169.sh first"; exit 1; }
cp $D/morningbrief.py $D/morningbrief.py.bak169c
cat > $D/morningbrief.py <<'PY_MB'
#!/usr/bin/env python3
"""morningbrief.py - patch 169: ☀️ MORNING BRIEF at 08:30 IST on NSE trading days, to GIR Box Picks (it rings) and the page.
(Rama, 10 Nov: Prestige filed its Allure deal on Friday 21:02 - GIR sent it 102 s later, but at night it gets lost.)
Everything that matters for an F&O share since the last session's close (15:30), in one short message:
  ▼ TROUBLE      regulator / management / results misses / downgrades filed on NSE, ⚠️ SHOCK WATCH ▼ (news, TV, regulator pages)
  ▲ GOOD NEWS    orders, deals, approvals, results beats, upgrades, ⚠️ SHOCK WATCH ▲
  ◆ RESULTS      results filed with no side yet (numbers not read)
  🏛 MARKET      🚨 CRITICAL GOVT (RBI / SEBI / government) of the night
Each line: the share, what, the size in ₹ crore when the filing gives one, when it was filed.
  python3 morningbrief.py           print it (nothing sent)        python3 morningbrief.py --send     send it"""
import os, re, sys, json, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
KINDS = ("RESULTS", "ORDER", "SALES", "RATING", "REG", "MGMT", "BOARD")
NAME = {"RESULTS": "RESULTS", "ORDER": "ORDER", "SALES": "SALES", "RATING": "RATING", "REG": "REGULATOR", "MGMT": "MANAGEMENT", "BOARD": "DEAL / BOARD"}


def holiday(d):
    try:
        import holidays
        return bool(holidays.holiday(d))
    except Exception:
        return d.weekday() >= 5


def window_start(now):
    """the last session's close (15:30) before today - over weekends and NSE holidays"""
    d = now.date() - dt.timedelta(days=1)
    while holiday(d):
        d -= dt.timedelta(days=1)
    return dt.datetime.combine(d, dt.time(15, 30), IST)


def amount(text):
    try:
        import exchange
        return exchange.amount_cr(text)
    except Exception:
        best = 0.0
        for m in re.finditer(r"(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)\s*(crores?|cr\b)", text or "", re.I):
            try:
                best = max(best, float(m.group(1).replace(",", "")))
            except ValueError:
                pass
        return best


TAGLINE = re.compile(r"SOMETHING IS HAPPENING|not a trade by itself|TRADE ALERT|ACT NOW|^[🟠🔴🟢⚪🟡]")
GOODREG = re.compile(r"in favou?r of|dropp(ed|ing) the|quash|set aside the (demand|order)|relief|allowed the appeal|approv|granted|clean|no observation", re.I)


def clean(s):
    s = (s or "").replace("Ɵ", "ti").replace("ﬁ", "fi").replace("ﬂ", "fl").replace("ﬀ", "ff")   # PDF ligatures (NSE's text)
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"^(?:dear sir/?madam|sub(?:ject)?\s*:)\s*", "", s, flags=re.I)
    return s


def filings(start, now):
    p = os.path.join(BASE, "filings.db")
    if not os.path.exists(p):
        return []
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=5)
    rows = c.execute("select sym, t_exch, kind, side, subject, detail, verdict from filings where t_exch >= ? and t_exch <= ? and kind in (%s) order by t_exch"
                     % ",".join("?" * len(KINDS)), (start.timestamp(), now.timestamp()) + KINDS).fetchall()
    c.close()
    out, seen = [], set()
    for sym, te, kind, side, subj, det, verdict in rows:
        k = (sym, kind, (subj or "")[:60])
        if k in seen:
            continue
        seen.add(k)
        text = clean(det) or clean(subj)
        v = (verdict or "").upper()
        if kind == "RESULTS" and v in ("BEAT", "BIG BEAT"):
            side = 1
        elif kind == "RESULTS" and v in ("MISS", "BIG MISS"):
            side = -1
        if kind == "REG" and GOODREG.search("%s %s" % (subj, det)):
            side = 1                                              # an order IN FAVOUR of the company is good news
        out.append({"sym": sym, "t": te, "kind": NAME.get(kind, kind), "side": side or 0, "cr": amount("%s %s" % (subj, det)),
                    "what": ("%s · " % v if kind == "RESULTS" and v and v not in ("XBRL NOT UP YET", "NUMBERS NOT READ") else "") + text[:110], "src": "NSE"})
    return out


def alerts(start, now):
    p = os.path.join(BASE, "tomorrow.db")
    if not os.path.exists(p):
        return []
    c = sqlite3.connect("file:%s?mode=ro" % p, uri=True, timeout=5)
    rows = c.execute("select day, t, sym, text from alerts where (day = ? and t >= '15:30') or (day > ? and day < ?) or (day = ? and t <= ?)",
                     (str(start.date()), str(start.date()), str(now.date()), str(now.date()), now.strftime("%H:%M:%S"))).fetchall()
    c.close()
    out = []
    for day, t, sym, text in rows:
        L = [x for x in (text or "").split("\n") if x.strip() and not TAGLINE.search(x.strip())]   # never the ring tag
        if not L:
            continue
        h = L[0]
        ts = dt.datetime.fromisoformat("%s %s" % (day, t[:8] if len(t) >= 8 else t + ":00")).replace(tzinfo=IST).timestamp()
        if h.startswith("⚠️ SHOCK WATCH"):
            m = re.search(r"([▲▼])\s*([A-Z0-9&-]+)\s*·\s*([A-Z /]+?)\s*·", h)
            if m:
                out.append({"sym": m.group(2), "t": ts, "kind": m.group(3).strip(), "side": -1 if m.group(1) == "▼" else 1, "cr": amount(" ".join(L[1:2])),
                            "what": clean(L[1] if len(L) > 1 else "")[:110], "src": "SHOCK WATCH"})
        elif h.startswith("🚨 CRITICAL GOVT"):
            out.append({"sym": "MARKET", "t": ts, "kind": "GOVT", "side": 0, "cr": 0, "what": clean(L[1] if len(L) > 1 else h)[:120], "src": h.split("·")[1].strip() if "·" in h else ""})
    return out


def build(now=None):
    now = now or dt.datetime.now(IST)
    start = window_start(now)
    items = filings(start, now) + alerts(start, now)
    seen, uniq = set(), []
    for x in sorted(items, key=lambda x: x["t"]):
        k = (x["sym"], x["kind"], x["what"][:40])
        if k not in seen:
            seen.add(k); uniq.append(x)
    bad = [x for x in uniq if x["sym"] != "MARKET" and x["side"] < 0]
    good = [x for x in uniq if x["sym"] != "MARKET" and x["side"] > 0]
    res = [x for x in uniq if x["sym"] != "MARKET" and x["side"] == 0 and x["kind"] == "RESULTS"]
    mkt = [x for x in uniq if x["sym"] == "MARKET"]
    when = lambda t: dt.datetime.fromtimestamp(t, IST).strftime("%a %H:%M")
    one = lambda x: "  %s · %s · %s%s · %s" % (x["sym"], x["kind"], x["what"][:100], (" (₹%s cr)" % format(int(round(x["cr"])), ",")) if x["cr"] >= 1 else "", when(x["t"]))
    L = ["☀️ MORNING BRIEF · %s · since %s 15:30 · F&O shares" % (now.strftime("%a %d %b"), start.strftime("%a %d %b"))]
    for title, xs, key in (("▼ TROUBLE", bad, lambda x: (-x["cr"], -x["t"])), ("▲ GOOD NEWS", good, lambda x: (-x["cr"], -x["t"])),
                           ("◆ RESULTS (numbers not read yet)", res, lambda x: -x["t"]), ("🏛 MARKET", mkt, lambda x: -x["t"])):
        if xs:
            xs = sorted(xs, key=key)
            L += ["", "%s (%d)" % (title, len(xs))] + [one(x) for x in xs[:8]] + (["  … %d more on the page (NEWS)" % (len(xs) - 8)] if len(xs) > 8 else [])
    if len(L) == 1:
        L += ["", "nothing of size filed overnight on F&O shares - a quiet open"]
    L += ["", "the side is the news only - trade it only if the price confirms after 09:15 · opening call 09:12 · TV WATCH from 09:00"]
    txt = "\n".join(L)
    return txt[:3900], {"bad": len(bad), "good": len(good), "res": len(res), "mkt": len(mkt)}


if __name__ == "__main__":
    now = dt.datetime.now(IST)
    if "--send" in sys.argv and holiday(now.date()) and "--force" not in sys.argv:
        print("NSE holiday / weekend - no brief"); sys.exit(0)
    txt, n = build(now)
    print(txt)
    if "--send" in sys.argv:
        import opencall
        opencall.send_tg(txt)
PY_MB
cd $D && python3 -m py_compile morningbrief.py && timeout 60 python3 p169test.py > /tmp/p169test.log 2>&1 && echo "p169test.py passed" || { cp $D/morningbrief.py.bak169c $D/morningbrief.py; echo "TEST FAILED - old file back"; exit 1; }
cd /home/globalbot && set -a && source .env; set +a; cd $D
echo "sending today's brief to Box Picks now:"
timeout 120 python3 morningbrief.py --send 2>&1 | head -40
echo
echo "PATCH 169c APPLIED - from tomorrow it comes by itself at 08:30."
