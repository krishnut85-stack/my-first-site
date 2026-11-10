#!/bin/bash
# PATCH 169 - ☀️ MORNING BRIEF at 08:30 IST on NSE trading days -> GIR Box Picks (rings) + the page: everything filed / said on F&O shares
#   since the last session's 15:30 (over weekends and holidays): ▼ TROUBLE · ▲ GOOD NEWS (with ₹ crore sizes) · ◆ RESULTS · 🏛 MARKET.
#   (Prestige's Friday-night deal was sent 102 s after filing - but at night it gets lost.) The 08:30 PDF recap (patch 125) stays.
#   + fix: the live OI check's timer (patch 166) was in UTC - now 09:25-15:25 IST.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M%S)
cp $D/alertword.py $D/alertword.py.bak$TS; cp $D/tglanes.py $D/tglanes.py.bak$TS
cat > $D/morningbrief.py <<'MORNINGBRIEF_PY'
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


def clean(s):
    s = re.sub(r"\s+", " ", s or "").strip()
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
        L = [x for x in (text or "").split("\n") if x.strip()]
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
MORNINGBRIEF_PY
cat > $D/p169test.py <<'P169TEST_PY'
#!/usr/bin/env python3
"""p169test.py - patch 169: the ☀️ MORNING BRIEF over a made-up night (Mon close -> Wed 08:30, Tue an NSE holiday) - nothing sent"""
import os, sys, types, sqlite3, shutil, tempfile, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
H = types.ModuleType("holidays")
H.holiday = lambda d: "weekend" if d.weekday() >= 5 else ("Diwali Balipratipada" if str(d) == "2026-11-10" else None)
sys.modules["holidays"] = H
import morningbrief as M
ok = True
def check(n, g):
    global ok
    print(("  ok   " if g else "  FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); M.BASE = T
IST = M.IST
ts = lambda d, h, m: dt.datetime(2026, 11, d, h, m, tzinfo=IST).timestamp()
c = sqlite3.connect(os.path.join(T, "filings.db"))
c.execute("create table filings(sym text, t_exch int, kind text, side int, subject text, detail text, verdict text)")
for r in [("MANAPPURAM", ts(9, 18, 0), "REG", -1, "Action(s) taken or orders passed", "RBI has imposed a penalty of Rs 5 crore on the company", ""),
          ("PRESTIGE", ts(9, 21, 2), "BOARD", 1, "Acquisition", "Prestige to acquire 100% of Allure Developers for up to Rs 524 crore", ""),
          ("LT", ts(9, 14, 0), "ORDER", 1, "Order", "L&T bags order of Rs 9,000 crore", ""),                      # in the session - not overnight
          ("TCS", ts(10, 16, 5), "RESULTS", 0, "Financial Results", "Q2 results", "BEAT"),
          ("INFY", ts(10, 17, 0), "RESULTS", 0, "Financial Results", "Q2 results", "XBRL NOT UP YET"),
          ("COCHINSHIP", ts(11, 8, 0), "ORDER", 1, "Bagging of orders", "Cochin Shipyard bags an order worth Rs 2,500 crore from the Navy", ""),
          ("SBIN", ts(9, 19, 0), "ROUTINE", 0, "Newspaper publication", "", "")]:
    c.execute("insert into filings values(?,?,?,?,?,?,?)", r)
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.execute("insert into alerts values('2026-11-10','11:00:00','⚠️','POLICYBZR','',?)", ("⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · IRDAI site 11:00\nIRDAI: show cause notice to Policybazaar Insurance Brokers",))
c.execute("insert into alerts values('2026-11-10','10:00:00','🚨','MARKET','',?)", ("🚨 CRITICAL GOVT · RBI · 10:00\nRBI cuts the repo rate by 25 basis points",))
c.execute("insert into alerts values('2026-11-09','12:00:00','⚠️','HAL','',?)", ("⚠️ SHOCK WATCH · ▲ HAL · ORDER · TV CNBC-TV18 12:00\non air: HAL order",))
c.commit(); c.close()
txt, n = M.build(dt.datetime(2026, 11, 11, 8, 30, tzinfo=IST))
print(txt)
check("Wed 08:30 after Tuesday's holiday: 'since Mon 09 Nov 15:30'", "since Mon 09 Nov 15:30" in txt)
tr = txt.split("▼ TROUBLE")[1].split("\n\n")[0] if "▼ TROUBLE" in txt else ""
gd = txt.split("▲ GOOD NEWS")[1].split("\n\n")[0] if "▲ GOOD NEWS" in txt else ""
check("▼ TROUBLE: MANAPPURAM (RBI penalty, ₹5 cr) and POLICYBZR (IRDAI, from SHOCK WATCH)", "MANAPPURAM · REGULATOR" in tr and "₹5 cr" in tr and "POLICYBZR · REGULATOR" in tr)
check("▲ GOOD NEWS: COCHINSHIP ₹2,500 cr first, PRESTIGE ₹524 cr, TCS results BEAT",
      "COCHINSHIP" in gd and "₹2,500 cr" in gd and "PRESTIGE" in gd and "₹524 cr" in gd and "TCS · RESULTS · BEAT" in gd and gd.index("COCHINSHIP") < gd.index("PRESTIGE"))
check("◆ RESULTS not read yet: INFY", "◆ RESULTS" in txt and "INFY" in txt.split("◆ RESULTS")[1])
check("🏛 MARKET: the RBI rate cut", "🏛 MARKET" in txt and "repo" in txt.split("🏛 MARKET")[1])
check("in-session news (L&T 14:00, HAL 12:00 Mon) and routine filings (SBIN newspaper) are not in it", "LT ·" not in txt and "HAL" not in txt and "SBIN" not in txt)
e, _ = M.build(dt.datetime(2026, 11, 13, 8, 30, tzinfo=IST))
check("a quiet night says so", "nothing of size filed overnight" in e)
import alertword, tglanes
check("it rings in GIR Box Picks", tglanes.lane(txt) == "critical" and alertword.tier(txt) != "read")
shutil.rmtree(T)
print("P169 TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
P169TEST_PY
cat > $D/patch_169.py <<'PATCH_169_PY'
#!/usr/bin/env python3
"""patch_169.py - ☀️ MORNING BRIEF rings in GIR Box Picks (alertword.tier + tglanes.lane). Usage: python3 patch_169.py <dir>"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
E = {"alertword.py": ('    if H2.startswith("⚡ ENTER NOW"):', '    if "MORNING BRIEF" in H2:                                  # patch 169: the 08:30 brief rings\n        return "move"\n    if H2.startswith("⚡ ENTER NOW"):'),
     "tglanes.py": ('CRIT_RE = re.compile(r"CRITICAL|', 'CRIT_RE = re.compile(r"MORNING BRIEF|CRITICAL|')}
for fn, (a, b) in E.items():
    p = os.path.join(D, fn); s = open(p, encoding="utf-8").read()
    if "MORNING BRIEF" in s:
        continue
    if s.count(a) != 1:
        print("ANCHOR x%d in %s" % (s.count(a), fn)); sys.exit(1)
    open(p, "w", encoding="utf-8").write(s.replace(a, b, 1))
print("the brief rings in Box Picks")
PATCH_169_PY
back() { cp $D/alertword.py.bak$TS $D/alertword.py; cp $D/tglanes.py.bak$TS $D/tglanes.py; rm -f $D/morningbrief.py; }
echo "== 1. the brief + its ring"
R=$(cd $D && python3 patch_169.py $D) || { echo "   $R"; back; exit 1; }; echo "   $R"
cd $D && python3 -m py_compile morningbrief.py alertword.py tglanes.py || { back; echo "   does not compile - undone"; exit 1; }
echo "== 2. the tests"
for t in p169test.py p161test.py p168test.py; do [ -f $t ] || continue
  timeout 200 python3 $t > /tmp/$t.log 2>&1 && echo "   $t passed" || { echo "   $t FAILED - undone:"; grep -E "FAIL|Error" /tmp/$t.log | head -4 | sed 's/^/     /'; back; exit 1; }
done
echo "== 3. the timers (India time)"
cat > $U/gir-brief.service <<'UNIT'
[Unit]
Description=GIR MORNING BRIEF (overnight filings / regulator / shock alerts on F&O shares)
[Service]
Type=oneshot
TimeoutStartSec=120
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 morningbrief.py --send >> data/brief.log 2>&1'
UNIT
cat > $U/gir-brief.timer <<'UNIT'
[Unit]
Description=GIR MORNING BRIEF 08:30 IST, Monday-Friday (it skips NSE holidays itself)
[Timer]
OnCalendar=Mon..Fri *-*-* 08:30:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
if [ -f $U/gir-livecheck.timer ]; then
  sed -i 's#^OnCalendar=Mon..Fri \*-\*-\* 09..15:05/10:00$#OnCalendar=Mon..Fri *-*-* 09..15:05/10:00 Asia/Kolkata#' $U/gir-livecheck.timer
fi
systemctl daemon-reload && systemctl enable --now gir-brief.timer >/dev/null 2>&1
systemctl restart gir-livecheck.timer 2>/dev/null
echo "   ☀️ brief:      next $(systemctl show gir-brief.timer -p NextElapseUSecRealtime --value 2>/dev/null)"
echo "   live OI check: next $(systemctl show gir-livecheck.timer -p NextElapseUSecRealtime --value 2>/dev/null)   (server time is UTC - IST is 5:30 later)"
echo "== 4. how it would look now (not sent)"
cd /home/globalbot && set -a && source .env; set +a; cd $D
timeout 60 python3 morningbrief.py 2>&1 | head -40 | sed 's/^/   /'
echo
echo "PATCH 169 APPLIED. The first brief comes tomorrow (Wed 11 Nov) at 08:30 to Box Picks. Send Claude a screenshot of sections 3 and 4."
