#!/bin/bash
# PATCH 125b - RESULTS THAT MATTER REACH YOU (on top of patch 125).
#   Divi's Lab filed on Sat 7 Nov 11:56: GIR read it in 3 minutes (profit +64%, margin +7%) but it never reached Telegram.
#   - a BIG BEAT / BIG MISS (profit +-40% with the margin or the quarter agreeing, or a fresh loss) is now
#     "🚨 CRITICAL RESULTS" in GIR Box Picks with the siren; any results line with BEAT / MISS goes to Box Picks too
#   - fixed reads: sales AND profit both down 15%+ = MISS (Data Patterns read IN LINE); a YoY beat with profit -50% vs
#     last quarter is not a beat (Voltas)
#   - the 08:30 recap opens with RESULTS since the last close, BIG ones first, bullish / bearish with the numbers
#   exchange.py, tglanes.py, home.html (exact anchors) · newsrecap.py (replaced). Restarts every GIR service.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g125b; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p125b.sh now"; exit 1; fi
[ -f $D/newsrecap.py ] || { echo "patch 125 is not installed yet - paste patch 125 first"; exit 1; }
grep -q "CRITICAL RESULTS" $D/exchange.py && { echo "patch 125b is already installed"; exit 1; }
F="exchange.py tglanes.py home.html newsrecap.py p125test.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p125btest.py; systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p125b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p125b_patch.py - PATCH 125b: RESULTS THAT MATTER REACH YOU.
  exchange.judge: sales AND profit both down 15%+ = MISS (DATAPATTNS) · a YoY beat with profit -50% QoQ = IN LINE (VOLTAS) ·
  BIG BEAT / BIG MISS (profit +-40% with the margin or the quarter agreeing; a fresh loss) -> "🚨 CRITICAL RESULTS" (DIVISLAB)
  tglanes / the page: a RESULTS line with BEAT or MISS goes to GIR Box Picks (CRITICAL), not Moves & News
Usage: python3 p125b_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "exchange.py": [
        ('''    v = "BEAT" if sc >= 2 else "MISS" if sc <= -2 else "IN LINE"
''', '''    v = "BEAT" if sc >= 2 else "MISS" if sc <= -2 else "IN LINE"
    # patch 125b: sales AND profit both down 15%+ is a MISS whatever the margin did (DATAPATTNS 6 Nov: -57% / -56%, margin +545 bps read IN LINE)
    if ry is not None and py is not None and ry <= -15 and py <= -15 and not turned:
        v = "MISS"
    # a YoY beat on a profit that collapsed against last quarter is not a beat (VOLTAS 6 Nov: +50% YoY but -78% QoQ)
    if v == "BEAT" and pq is not None and pq <= -50 and not loss_now and not turned:
        v = "IN LINE"
    # the BIG ones ring as 🚨 CRITICAL RESULTS (DIVISLAB 7 Nov: profit +64%, margin +711 bps - about 50% over the brokers' numbers)
    big_beat = v == "BEAT" and ((py is not None and py >= 40 and ((bps or 0) >= 300 or (pq or 0) >= 20)) or (turned and (ry or 0) >= 10))
    big_miss = v == "MISS" and ((py is not None and py <= -40) or (loss_now and (pat.get("yoy") or 0) > 0) or (bps is not None and bps <= -500))
    big = bool(big_beat or big_miss)
'''),
        ('''    basis = pat.get("basis") or rev.get("basis") or ""
''', '''    if v == "IN LINE" and pq is not None and pq <= -50 and (py or 0) > 0:
        why += (" · " if why else "") + "but profit fell %.0f%% against last quarter" % -pq
    if big:
        why = "BIG %s" % ("BEAT" if v == "BEAT" else "MISS") + ((" · " + why) if why else "")
    basis = pat.get("basis") or rev.get("basis") or ""
'''),
        ('''    res["read"] = {"v": v, "sc": sc, "why": why, "rev"''', '''    res["read"] = {"v": v, "sc": sc, "why": why, "big": big, "rev"'''),
        ('''                    v, s2, res_line = judge(res)
''', '''                    v, s2, res_line = judge(res)
                    f["big"] = bool((res.get("read") or {}).get("big"))          # patch 125b
'''),
        ('''        f = {"exch": "NSE", "sym": sym, "t_exch": t_exch, "kind": "RESULTS", "side": side, "verdict": v, "subject": subject, "detail": "", "link": link}
''', '''        f = {"exch": "NSE", "sym": sym, "t_exch": t_exch, "kind": "RESULTS", "side": side, "verdict": v, "subject": subject, "detail": "", "link": link,
             "big": bool((res.get("read") or {}).get("big"))}                   # patch 125b
'''),
        ('''(f.get("head") or "📰 FILING", arrow, f["sym"], f["kind"], (" · %s" % f["verdict"]) if f.get("verdict") else "", when, lag_s)''',
         '''(f.get("head") or ("🚨 CRITICAL RESULTS" if f.get("big") else "📰 FILING"), arrow, f["sym"], f["kind"],
                                                                (" · %s%s" % ("BIG " if f.get("big") else "", f["verdict"])) if f.get("verdict") else "", when, lag_s)'''),
    ],
    "tglanes.py": [
        ('''        if "WALL FLIP" in H2:''', '''        if re.search(r"· RESULTS · (BIG )?(BEAT|MISS)\\b", H2):     # patch 125b: a results verdict with a side - the critical channel
            return "critical"
        if "WALL FLIP" in H2:'''),
    ],
    "home.html": [
        ('''  if(/WALL FLIP/.test(H)) return "oi";''', '''  if(/· RESULTS · (BIG )?(BEAT|MISS)\\b/.test(H)) return "critical";   /* patch 125b */
  if(/WALL FLIP/.test(H)) return "oi";'''),
    ],
}
out = {}
for fn, edits in EDITS.items():
    s = open(os.path.join(D, fn), encoding="utf-8").read()
    for old, new in edits:
        n = s.count(old)
        if n != 1:
            print("%s: anchor found %d times (want 1): %s" % (fn, n, old.strip().splitlines()[0][:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    out[fn] = s
for fn, s in out.items():
    open(os.path.join(D, fn), "w", encoding="utf-8").write(s)
print("exchange.py: the results rules + 🚨 CRITICAL RESULTS · tglanes.py + home.html: results verdicts to Box Picks")
PY_PATCH
cat > $W/newsrecap.py <<'PY_RECAP'
#!/usr/bin/env python3
"""newsrecap.py - patch 125: 🗞 THE MORNING NEWS RECAP - one PDF page to "GIR Moves & News" every day at 08:30 IST.

  THE MORNING READ   three lines from the news reader: what an F&O trader must know before 09:15
  RESULTS            every F&O company's results since the last close, BIG BEAT / BIG MISS first, bullish ▲ or bearish ▼
                     with the numbers behind it (patch 125b)
  OVERNIGHT          every news line GIR sent after the last close (15:30): 🚨 critical first, then company news, filings
  MARKET & GLOBAL    the top market / policy / global headlines of the night
  YESTERDAY'S NEWS → THE CLOSE   the session's news lines and what the share did by the close (✔ the side was right)
Only news GIR already checked and sent (old news is held by newsfresh, never in the recap). The PDF is kept in
data/recap/. gir-recap.timer runs it.
  python3 newsrecap.py --send     build and send now          python3 newsrecap.py --pdf    build only (prints the path)"""
import os, re, sys, json, time, sqlite3, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(BASE, "data", "recap")
FONTS = ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
NEWS_KINDS = ("📰", "🚨", "📄", "🏛", "⚡")
TAGS = ("🔴", "🟠", "📌")


def prev_session(now):
    """the last weekday before today (holidays aside) -> its date"""
    d = now.date() - dt.timedelta(days=1)
    while d.weekday() >= 5:
        d -= dt.timedelta(days=1)
    return d


def _parse(text):
    """an alert's text -> (head, headline, reader's reason, link)"""
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return "", "", "", ""
    head = L[0]
    if head.startswith("🔔 OPENING") and len(L) > 1:
        L = L[1:]; head = L[0]
    body = [x for x in L[1:] if not x.startswith(TAGS)]
    hl = next((x for x in body if not x.startswith(("the reader", "quick read", "share price", "no clear", "http", "also names", "watch:", "NIFTY", "why it matters", "⚠"))), head)
    rs = next((x for x in body if x.startswith("the reader")), "")
    m = re.match(r"the reader \([^)]*\):\s*(.*?)\s*·\s*(CRITICAL|IMPORTANT|MINOR)", rs)
    reason = m.group(1) if m else ""
    link = next((x.strip() for x in body if x.startswith("http")), "")
    return head, hl, reason, link


def _level(kind, head):
    return "critical" if "CRITICAL" in head else "minor" if kind == "📄" else "market" if (kind == "🏛" or " MARKET " in head) else "important"


def _key(sym, h):
    w = re.findall(r"[a-z0-9]+", h.lower())
    return sym + ":" + " ".join(w[:7])


def results_since(hours):
    """{sym: exchange.results_read(...)} - the results GIR read off the exchange in the last `hours`"""
    import exchange
    return exchange.results_map(hours)


def gather(now=None, db=None):
    """-> {"since", "prev", "overnight": [...], "session": [...], "market": [...], "reaction": [...], "held": n}"""
    now = now or dt.datetime.now(IST)
    prev = prev_session(now)
    t_close = dt.datetime.combine(prev, dt.time(15, 30), IST)
    t_open = dt.datetime.combine(prev, dt.time(9, 0), IST)
    out = {"now": now, "prev": prev, "since": t_close, "overnight": [], "session": [], "market": [], "reaction": [], "held": 0, "results": []}
    try:                                                         # patch 125b: the results since the last close (not yet traded)
        for sym, r in (results_since(max(1.0, (now - t_close).total_seconds() / 3600.0)) or {}).items():
            if not r or float(r.get("t_exch") or 0) < t_close.timestamp():
                continue
            out["results"].append({"s": sym, "v": r.get("verdict") or "", "side": int(r.get("side") or 0), "big": bool((r.get("read") or {}).get("big")),
                                   "line": r.get("line") or "", "at": dt.datetime.fromtimestamp(float(r["t_exch"]), IST), "check": bool(r.get("unverified"))})
        out["results"].sort(key=lambda x: (not x["big"], x["side"] == 0, x["v"] in ("NUMBERS NOT READ", "XBRL NOT UP YET"), -x["at"].timestamp()))
    except Exception as ex:
        print("recap results: %s" % str(ex)[:80])
    seen = set()
    try:
        c = sqlite3.connect(db or os.path.join(BASE, "tomorrow.db"), timeout=10)
        rows = c.execute("select day, t, kind, sym, side, text from alerts where day>=? order by day, t", (str(prev),)).fetchall()
        for day, t, kind, sym, side, text in rows:
            if kind not in NEWS_KINDS:
                continue
            head, hl, reason, link = _parse(text)
            if (kind == "🚨" and "CRITICAL" not in head) or (kind == "⚡" and "NEWS SHOCK" not in head) or "NOT SENT" in (text or ""):
                continue
            try:
                at = dt.datetime.strptime(day + " " + t[:8], "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
            except Exception:
                continue
            if at < t_open or at > now:
                continue
            k = _key(sym or "MARKET", hl)
            if k in seen:
                continue
            seen.add(k)
            lv = _level(kind, head)
            it = {"at": at, "s": sym or "MARKET", "side": side or "", "lvl": lv, "h": hl, "why": reason, "link": link}
            if lv == "market":
                out["market"].append(it)
            elif at >= t_close:
                out["overnight"].append(it)
            else:
                out["session"].append(it)
        try:
            for r in c.execute("select t, sym, side, lvl, head, p0, pc, nc from news_react where day=? and p0 is not null and pc is not null", (str(prev),)).fetchall():
                t, sym, side, lvl, head, p0, pc, nc = r
                mc = round((pc / p0 - 1) * 100, 2) if p0 and pc else None
                sg = 1 if side == "CE" else -1 if side == "PE" else 0
                out["reaction"].append({"t": t[:5], "s": sym, "side": side or "", "lvl": lvl, "h": head, "mc": mc,
                                        "right": None if (not sg or mc is None) else (mc * sg >= 0.5)})
        except Exception:
            pass
        c.close()
    except Exception as ex:
        print("recap alerts: %s" % str(ex)[:80])
    try:                                                         # the market headlines GIR kept (scored, trusted) but did not send
        j = json.load(open(os.path.join(BASE, "data", "macro.json")))
        for x in sorted(j.get("items") or [], key=lambda x: -(x.get("score") or 0)):
            at = dt.datetime.fromtimestamp(float(x.get("t") or 0), IST)
            if at < t_close or at > now or (x.get("score") or 0) < 4:
                continue
            k = _key("MARKET", x.get("h") or "")
            if k in seen:
                continue
            seen.add(k)
            out["market"].append({"at": at, "s": "MARKET", "side": "CE" if x.get("side", 0) > 0 else "PE" if x.get("side", 0) < 0 else "", "lvl": "market",
                                  "h": x.get("h") or "", "why": x.get("why") or "", "link": x.get("link") or "", "src": x.get("src") or ""})
    except Exception:
        pass
    try:
        held = json.load(open(os.path.join(BASE, "data", "news_held.json")))
        out["held"] = sum(1 for x in held if x.get("at", "") >= t_close.strftime("%Y-%m-%d %H:%M:%S"))
    except Exception:
        pass
    rank = {"critical": 0, "important": 1, "minor": 2, "market": 3}
    out["overnight"].sort(key=lambda x: (rank.get(x["lvl"], 9), -x["at"].timestamp()))
    out["session"].sort(key=lambda x: (rank.get(x["lvl"], 9), -x["at"].timestamp()))
    out["market"].sort(key=lambda x: -x["at"].timestamp())
    out["reaction"].sort(key=lambda x: -abs(x["mc"] or 0))
    return out


def morning_read(g):
    """three lines from the news reader (the model), or [] when it is not there"""
    try:
        import llmread
        if not llmread.available():
            return []
        items = g["overnight"][:25] + g["market"][:10]
        res_ = "\n".join("- RESULTS %s %s: %s" % (x["s"], ("BIG " if x["big"] else "") + x["v"], x["line"][:160]) for x in g.get("results", [])[:12])
        if not items and not res_:
            return []
        lines = "\n".join("- %s %s %s: %s" % (x["at"].strftime("%a %H:%M"), x["s"], {"CE": "UP", "PE": "DOWN"}.get(x["side"], ""), x["h"]) for x in items) + ("\n" + res_ if res_ else "")
        p = ("You are the senior news reader on an Indian F&O desk. It is %s, before the 09:15 open. These are the news lines since "
             "yesterday's close:\n%s\n\nWrite exactly 3 short lines (max 22 words each) for a trader: what matters most at the open "
             "today, naming the shares and UP / DOWN. No intro, no bullets symbols, plain text, one item per line.") % (g["now"].strftime("%a %d %b %H:%M"), lines)
        txt, _m = llmread.ask(p, max_tokens=300)
        return [re.sub(r"^[\-\*\d\.\)\s]+", "", x).strip() for x in (txt or "").split("\n") if x.strip()][:3]
    except Exception as ex:
        print("recap morning read: %s" % str(ex)[:80])
        return []


def build_pdf(g, path, read=None, caps=(24, 10, 10, 10), n_res=14):
    """one A4 page; when it does not fit, fewer rows (never a second page). -> (path, rows shown)"""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    F, FB = "Helvetica", "Helvetica-Bold"
    if all(os.path.exists(f) for f in FONTS):
        try:
            pdfmetrics.registerFont(TTFont("GirSans", FONTS[0])); pdfmetrics.registerFont(TTFont("GirSans-B", FONTS[1]))
            pdfmetrics.registerFontFamily("GirSans", normal="GirSans", bold="GirSans-B", italic="GirSans", boldItalic="GirSans-B")
            F, FB = "GirSans", "GirSans-B"
        except Exception:
            pass
    uni = F == "GirSans"
    esc = lambda s: (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") if uni else \
        (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("₹", "Rs ").encode("latin-1", "ignore").decode("latin-1")
    UP, DN, AM, DIM, INK, RED = colors.HexColor("#0a8a3a"), colors.HexColor("#c62828"), colors.HexColor("#b26a00"), colors.HexColor("#6b7280"), colors.HexColor("#111827"), colors.HexColor("#c62828")
    st = lambda size=7.6, bold=False, col=INK, lead=None: ParagraphStyle("x", fontName=FB if bold else F, fontSize=size, leading=lead or size * 1.22, textColor=col)
    arrow = lambda side: ('<font color="#0a8a3a">%s</font>' % ("▲" if uni else "+")) if side == "CE" else ('<font color="#c62828">%s</font>' % ("▼" if uni else "-")) if side == "PE" else ('<font color="#6b7280">·</font>')
    lvl_word = {"critical": '<font color="#c62828"><b>CRITICAL</b></font>', "important": "news", "minor": '<font color="#6b7280">minor</font>', "market": "market"}

    def news_table(rows, show_day):
        data = []
        for x in rows:
            when = x["at"].strftime("%a %H:%M" if show_day else "%H:%M")
            why = (" — " + esc(x["why"][:110])) if x.get("why") else ""
            data.append([Paragraph(when, st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow(x["side"])), st(7.6)),
                         Paragraph(lvl_word.get(x["lvl"], ""), st(6.8)), Paragraph(esc(x["h"][:170]) + '<font color="#6b7280">%s</font>' % why, st(7.4))])
        t = Table(data, colWidths=[46, 76, 50, 359])
        t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                               ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
        return t

    def section(title, sub):
        return Paragraph('<font color="#b26a00"><b>%s</b></font> <font color="#6b7280" size="7">%s</font>' % (esc(title), esc(sub)), st(9.5, lead=13))

    n_on, n_mk, n_rx, n_se = caps
    for _try in range(8):
        story = []
        now = g["now"]
        crit = [x for x in g["overnight"] if x["lvl"] == "critical"]
        hdr = Table([[Paragraph('<font color="#ffb000"><b>GIR</b></font> <font color="#ffffff"><b>MORNING NEWS RECAP</b></font>', st(13, col=colors.white, lead=16)),
                      Paragraph('<font color="#ffffff">%s · %s IST</font><br/><font color="#9ca3af">news since %s close · %d overnight · %d critical · %d old stories held back</font>' % (
                          esc(now.strftime("%a %d %b %Y")), now.strftime("%H:%M"), esc(g["prev"].strftime("%a %d %b")), len(g["overnight"]), len(crit), g["held"]), st(7.6, col=colors.white))]],
                    colWidths=[270, 261])
        hdr.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#0b0d11")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                                 ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6), ("LEFTPADDING", (0, 0), (-1, -1), 8)]))
        story += [hdr, Spacer(1, 5)]
        if read:
            box = Table([[Paragraph("<b>THE MORNING READ</b><br/>" + "<br/>".join("• " + esc(x) for x in read), st(8.2, lead=11))]], colWidths=[531])
            box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#fff7e6")), ("BOX", (0, 0), (-1, -1), 0.6, AM),
                                     ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
            story += [box, Spacer(1, 5)]
        rs = g.get("results", [])[:n_res]                           # patch 125b: RESULTS first - the market has not traded them yet
        if g.get("results"):
            nb = sum(1 for x in g["results"] if x["big"])
            story.append(section("RESULTS · since the %s close" % g["prev"].strftime("%a"), "%d companies%s · not traded yet - the move comes at 09:15" % (
                len(g["results"]), (" · %d BIG" % nb) if nb else "")))
            vcol = lambda x: "#0a8a3a" if x["side"] > 0 else "#c62828" if x["side"] < 0 else "#6b7280"
            data = [[Paragraph(x["at"].strftime("%a %H:%M"), st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow("CE" if x["side"] > 0 else "PE" if x["side"] < 0 else "")), st(7.6)),
                     Paragraph('<font color="%s">%s%s</font>' % (vcol(x), "<b>BIG %s</b>" % esc(x["v"]) if x["big"] else esc(x["v"]).replace("NUMBERS NOT READ", "not read"),
                                                                 "<br/>(check)" if x["check"] else ""), st(7, lead=8.4)),
                     Paragraph(esc(re.sub(r"\s*\((consolidated|standalone)[^)]*\)", "", x["line"])[:240]), st(7.2))] for x in rs]
            t = Table(data, colWidths=[46, 76, 50, 359])
            t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                   ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]
                                  + [("BACKGROUND", (0, i), (-1, i), colors.HexColor("#eefaf1" if x["side"] > 0 else "#fdeeee")) for i, x in enumerate(rs) if x["big"]]))
            story += [t, Spacer(1, 5)]
        on = g["overnight"][:n_on]
        story.append(section("OVERNIGHT · after the %s close" % g["prev"].strftime("%a"), "%d lines%s" % (len(g["overnight"]), (" · top %d shown" % len(on)) if len(on) < len(g["overnight"]) else "")))
        story.append(news_table(on, True) if on else Paragraph("no company news after the close", st(7.4, col=DIM)))
        story.append(Spacer(1, 5))
        mk = g["market"][:n_mk]
        story.append(section("MARKET & GLOBAL", "policy · RBI · SEBI · global · crude · rupee"))
        story.append(news_table(mk, True) if mk else Paragraph("no market headline of weight", st(7.4, col=DIM)))
        story.append(Spacer(1, 5))
        rx = g["reaction"][:n_rx]
        rt = [x for x in g["reaction"] if x["right"] is not None]
        story.append(section("YESTERDAY'S NEWS → THE CLOSE", "%s · the reader's side right by the close: %d of %d" % (g["prev"].strftime("%a %d %b"), sum(1 for x in rt if x["right"]), len(rt))))
        if rx:
            data = [[Paragraph(esc(x["t"]), st(7, col=DIM)), Paragraph("<b>%s</b> %s" % (esc(x["s"]), arrow(x["side"])), st(7.6)),
                     Paragraph(esc((x["h"] or "")[:150]), st(7.3)),
                     Paragraph(('<font color="%s"><b>%+.1f%%</b></font>' % ("#0a8a3a" if (x["mc"] or 0) > 0 else "#c62828", x["mc"])) if x["mc"] is not None else "—", st(7.6)),
                     Paragraph("" if x["right"] is None else ('<font color="#0a8a3a">%s</font>' % ("✔" if uni else "right")) if x["right"] else ('<font color="#c62828">%s</font>' % ("✖" if uni else "wrong")), st(7.6))]
                    for x in rx]
            t = Table(data, colWidths=[30, 78, 351, 42, 30])
            t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                   ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
            story.append(t)
        else:
            se = g["session"][:n_se]
            story.append(news_table(se, False) if se else Paragraph("no news lines in the session", st(7.4, col=DIM)))
        story.append(Spacer(1, 6))
        story.append(Paragraph("GIR · only news GIR checked (old stories held back) · ▲ share likely UP → CE · ▼ likely DOWN → PE · news, not a trade by itself"
                               if uni else "GIR - only news GIR checked (old stories held back) - + likely UP (CE) - likely DOWN (PE)", st(6.4, col=DIM)))
        doc = SimpleDocTemplate(path, pagesize=A4, leftMargin=32, rightMargin=32, topMargin=26, bottomMargin=22,
                                title="GIR news recap %s" % now.strftime("%Y-%m-%d"), author="GIR")
        doc.build(story)
        if doc.page <= 1:
            return path, (len(on), len(mk), len(rx))
        n_on, n_mk, n_rx, n_se = max(4, n_on - 2), max(3, n_mk - 2), max(4, n_rx - 2), max(4, n_se - 2)
        n_res = max(6, n_res - 1)
    return path, (n_on, n_mk, n_rx)


def caption(g):
    crit = [x for x in g["overnight"] if x["lvl"] == "critical"]
    top = (crit or g["overnight"])[:4]
    s = "🗞 GIR MORNING NEWS RECAP · %s · %d overnight · %d critical" % (g["now"].strftime("%a %d %b %H:%M"), len(g["overnight"]), len(crit))
    big = [x for x in g.get("results", []) if x["big"]]
    if g.get("results"):
        s += " · %d results" % len(g["results"])
    if big:
        s += "\nRESULTS: " + " · ".join("%s %s BIG %s" % (x["s"], "▲" if x["side"] > 0 else "▼", x["v"]) for x in big[:5])
    if top:
        s += "\n" + " · ".join("%s %s" % (x["s"], "▲" if x["side"] == "CE" else "▼" if x["side"] == "PE" else "·") for x in top)
    return s


def send_pdf(path, cap, post=None):
    """the PDF as a document to GIR Moves & News (or Box Picks until that channel is set). True when Telegram took it."""
    env = {}
    try:
        for line in open("/home/globalbot/.env"):
            m = re.match(r"\s*(?:export\s+)?([A-Z_]+)\s*=\s*(.*?)\s*$", line)
            if m:
                env[m.group(1)] = m.group(2).strip("'\"")
    except Exception:
        pass
    tok = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN") or env.get("TELEGRAM_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
    box = os.environ.get("TG_CHAT_BOX") or env.get("TG_CHAT_BOX")
    try:
        import tglanes
        chat = tglanes.chat_for(cap, box)
    except Exception:
        chat = box
    if not tok or not chat:
        print("recap: no Telegram token / channel"); return False
    if post is None:
        import requests
        post = requests.post
    for try_ in range(3):
        try:
            with open(path, "rb") as fh:
                r = post("https://api.telegram.org/bot%s/sendDocument" % tok, data={"chat_id": chat, "caption": cap[:1000]},
                         files={"document": (os.path.basename(path), fh, "application/pdf")}, timeout=60)
            if getattr(r, "ok", False):
                return True
            print("recap telegram: %s %s" % (getattr(r, "status_code", "?"), (getattr(r, "text", "") or "")[:120]))
            if getattr(r, "status_code", 0) == 429:
                time.sleep(10); continue
            return False
        except Exception as ex:
            print("recap telegram: %s" % str(ex)[:100]); time.sleep(3)
    return False


def run(send=True, now=None):
    now = now or dt.datetime.now(IST)
    g = gather(now)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "GIR_news_recap_%s.pdf" % now.strftime("%Y-%m-%d"))
    path, shown = build_pdf(g, path, morning_read(g))
    for f in sorted(os.listdir(OUT))[:-30]:                      # keep a month
        try:
            os.remove(os.path.join(OUT, f))
        except Exception:
            pass
    ok = send_pdf(path, caption(g)) if send else None
    print("recap %s: %d overnight · %d market · %d reactions · shown %s · %s" % (now.strftime("%Y-%m-%d %H:%M"), len(g["overnight"]), len(g["market"]), len(g["reaction"]), shown,
                                                                          "sent" if ok else "NOT sent" if send else path))
    return path, ok


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--send" in a:
        sys.exit(0 if run(True)[1] else 1)
    elif "--pdf" in a:
        print(run(False)[0])
    else:
        print(__doc__)
PY_RECAP
cat > $D/p125btest.py <<'PY_TEST'
#!/usr/bin/env python3
"""p125btest.py - RESULTS THAT MATTER REACH YOU: Divi's +64% = 🚨 CRITICAL RESULTS in GIR Box Picks; Data Patterns
(sales and profit halved) = MISS; Voltas (-78% QoQ) not a beat; the 08:30 recap opens with the results. Sample numbers only."""
import os, sys, json, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import exchange, tglanes, alertword, newsrecap


def R(rev, pat, opp=None):
    r = {"unit": "crore", "rev": dict(zip(("cur", "yoy", "qoq"), rev)), "pat": dict(zip(("cur", "yoy", "qoq"), pat))}
    if opp:
        r["opp"] = dict(zip(("cur", "yoy", "qoq"), opp))
    return r


C = {"DIVISLAB": R((3676, 2715, 3200), (1127, 689, 902), (1662, 1035, 1300)), "DATAPATTNS": R((133, 309, 150), (22, 50, 25), (39.6, 75, 40)),
     "VOLTAS": R((2707, 2354, 4500), (48, 32, 218), (127, 99, 400)), "SIEMENS": R((5734, 4900, 3900), (504, 480, 343), (780, 730, 520))}
J = {s: exchange.judge(r) + (bool(r["read"].get("big")),) for s, r in C.items()}
print("1. the results reader")
check("DIVI'S LAB (profit +64%%, margin +7%%): BIG BEAT, bullish: %s" % (J["DIVISLAB"][:2] + J["DIVISLAB"][3:],), J["DIVISLAB"][0] == "BEAT" and J["DIVISLAB"][1] == 1 and J["DIVISLAB"][3] and "BIG BEAT" in J["DIVISLAB"][2])
check("DATA PATTERNS (sales -57%%, profit -56%%, margin up): MISS, bearish (was IN LINE): %s" % (J["DATAPATTNS"][:2],), J["DATAPATTNS"][:2] == ("MISS", -1))
check("VOLTAS (+50%% YoY but -78%% QoQ): not a beat: %s · %s" % (J["VOLTAS"][0], J["VOLTAS"][2][-60:]), J["VOLTAS"][0] == "IN LINE" and "-78" not in J["VOLTAS"][2][:0] and "78% against last quarter" in J["VOLTAS"][2])
check("SIEMENS (+5%% profit, margin down): no BIG flag: %s" % (J["SIEMENS"][:2] + J["SIEMENS"][3:],), not J["SIEMENS"][3])
print("2. the alert")
f = {"exch": "NSE", "sym": "DIVISLAB", "t_exch": dt.datetime(2026, 11, 7, 11, 56, 36, tzinfo=exchange.IST).timestamp(), "kind": "RESULTS", "side": 1, "verdict": "BEAT",
     "subject": "Outcome of Board Meeting", "detail": "", "link": "", "big": True}
t = exchange.box_text(f, 192, J["DIVISLAB"][2], False)
check("the line: %s" % t.split("\n")[0], t.startswith("🚨 CRITICAL RESULTS ▲ DIVISLAB · RESULTS · BIG BEAT · NSE 11:56:36"))
check("GIR Box Picks (the critical channel) and it rings", tglanes.lane(t) == "critical" and alertword.tier(t) == "move")
t2 = exchange.box_text(dict(f, big=False, verdict="MISS", side=-1, sym="FORTIS"), 60, "x", False)
t3 = exchange.box_text(dict(f, big=False, verdict="IN LINE", side=0, sym="SIEMENS"), 60, "x", False)
t4 = exchange.box_text(dict(f, big=False, verdict="XBRL NOT UP YET", side=0, sym="TATASTEEL"), 60, "", False)
check("a plain MISS also goes to Box Picks; IN LINE and 'numbers coming' to Moves & News: %s %s %s" % (tglanes.lane(t2), tglanes.lane(t3), tglanes.lane(t4)),
      (tglanes.lane(t2), tglanes.lane(t3), tglanes.lane(t4)) == ("critical", "moves", "moves"))
print("3. the 08:30 recap")
tmp = tempfile.mkdtemp(prefix="p125b")
try:
    newsrecap.BASE = tmp; os.makedirs(os.path.join(tmp, "data"))
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db")); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)"); c.commit(); c.close()
    now = dt.datetime(2026, 11, 9, 8, 30, tzinfo=newsrecap.IST)              # Monday
    ts = lambda d, hm: dt.datetime.strptime("2026-11-%02d %s" % (d, hm), "%Y-%m-%d %H:%M").replace(tzinfo=newsrecap.IST).timestamp()
    RS = {"DIVISLAB": {"verdict": "BEAT", "side": 1, "line": J["DIVISLAB"][2], "t_exch": ts(7, "11:56"), "read": {"big": True}},
          "TATASTEEL": {"verdict": "NUMBERS NOT READ", "side": 0, "line": "the numbers read off the pdf did not pass the sanity check — no side", "t_exch": ts(7, "13:06"), "read": None},
          "DATAPATTNS": {"verdict": "MISS", "side": -1, "line": J["DATAPATTNS"][2], "t_exch": ts(6, "18:51"), "read": {"big": True}},
          "VOLTAS": {"verdict": "IN LINE", "side": 0, "line": J["VOLTAS"][2], "t_exch": ts(6, "16:59"), "read": {"big": False}},
          "SIEMENS": {"verdict": "IN LINE", "side": 0, "line": J["SIEMENS"][2], "t_exch": ts(6, "15:48"), "read": {"big": False}},
          "JUBLFOOD": {"verdict": "MISS", "side": -1, "line": "in the session - already traded", "t_exch": ts(6, "15:20"), "read": {"big": True}}}
    newsrecap.results_since = lambda hours: RS
    g = newsrecap.gather(now)
    order = [(x["s"], x["big"]) for x in g["results"]]
    check("results since Friday's close, BIG ones first, the in-session one left out: %s" % order,
          order[:2] == [("DIVISLAB", True), ("DATAPATTNS", True)] and "JUBLFOOD" not in [s for s, _ in order] and len(order) == 5 and order[-1][0] == "TATASTEEL")
    cap = newsrecap.caption(g)
    check("the caption names them: %s" % cap.replace("\n", " / "), "5 results" in cap and "DIVISLAB ▲ BIG BEAT" in cap and "DATAPATTNS ▼ BIG MISS" in cap)
    path, shown = newsrecap.build_pdf(g, os.path.join(tmp, "data", "r.pdf"), ["DIVISLAB ▲: profit +64%, far above the brokers' numbers - the gap-up candidate at 09:15."])
    check("still one page with the RESULTS section", b"/Count 1" in open(path, "rb").read())
    if "--keep" in sys.argv:
        shutil.copy(path, os.path.join(B, "p125b_sample.pdf"))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page's alert bar files a results verdict under 🚨 CRITICAL", '/· RESULTS · (BIG )?(BEAT|MISS)\\b/.test(H)) return "critical"' in pg)
print("\nP125B RESULTS REACH YOU TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p125b_patch.py $D || { rm -f $D/p125btest.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
cp $W/newsrecap.py $D/newsrecap.py
grep -q "newsrecap.results_since = lambda" $D/p125test.py || sed -i 's/^IST = newsrecap.IST$/newsrecap.results_since = lambda hours: {}          # patch 125b: no live results in this test\nIST = newsrecap.IST/' $D/p125test.py
cd $D && python3 -m py_compile exchange.py tglanes.py newsrecap.py p125btest.py p125test.py || back
timeout 120 python3 p125btest.py 2>&1 | grep "OK  \|FAIL\|REACH YOU TEST"
timeout 120 python3 p125btest.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p124test.py p124ctest.py p125test.py p118test.py p119test.py p123test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-exchange gir-intraday gir-desk gir-newsroom gir-dash && sleep 15
for u in gir-exchange gir-intraday gir-desk gir-newsroom gir-dash; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
echo
echo "PATCH 125b APPLIED. The results GIR read since Friday's close, with today's rules:"
cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 - <<'PY'
import datetime as dt, newsrecap
g = newsrecap.gather()
for x in g["results"]:
    print("  %s %-11s %-9s %s" % (x["at"].strftime("%a %H:%M"), x["s"], ("BIG " if x["big"] else "") + x["v"], ("▲ BULLISH" if x["side"] > 0 else "▼ BEARISH" if x["side"] < 0 else "· neutral")))
PY
echo "Sending a fresh recap (with RESULTS) to GIR Moves & News now ..."
python3 newsrecap.py --send
