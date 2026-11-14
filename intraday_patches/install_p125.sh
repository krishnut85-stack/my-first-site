#!/bin/bash
# PATCH 125 - 🗞 THE MORNING NEWS RECAP (on top of patch 124c).
#   Every day at 08:30 IST one PDF page goes to "GIR Moves & News": THE MORNING READ (3 lines from the news reader) ·
#   OVERNIGHT (every news line after the last close, critical first) · MARKET & GLOBAL · YESTERDAY'S NEWS → THE CLOSE
#   (what each share did by the close, ✔ when the side was right). Only news GIR checked - old stories are held back.
#   newsrecap.py (new) · gir-recap.timer (new) · python3-reportlab + fonts-dejavu-core (apt, if missing).
#   Nothing running is restarted. Sends one recap now so you can see it.
D=/home/globalbot/intraday; W=/tmp/g125; mkdir -p $W
[ -f $D/newsfresh.py ] || { echo "patch 124c is not installed yet - paste patch 124c first"; exit 1; }
[ -f $D/newsrecap.py ] && { echo "patch 125 is already installed"; exit 1; }
back() { rm -f $D/newsrecap.py $D/p125test.py; systemctl disable --now gir-recap.timer >/dev/null 2>&1; rm -f /etc/systemd/system/gir-recap.timer /etc/systemd/system/gir-recap.service; systemctl daemon-reload; echo "ERROR - removed again, nothing else was changed"; exit 1; }
python3 -c "import reportlab" 2>/dev/null || { echo "installing the PDF maker (python3-reportlab) ..."; DEBIAN_FRONTEND=noninteractive apt-get install -y python3-reportlab >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y python3-reportlab >/dev/null 2>&1; }; }
python3 -c "import reportlab" 2>/dev/null || { echo "could not install python3-reportlab - nothing was changed"; exit 1; }
[ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ] || DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-dejavu-core >/dev/null 2>&1
[ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ] && echo "PDF maker ready (reportlab + DejaVu font: ₹ ▲ ▼ ✔ print right)" || echo "PDF maker ready (no DejaVu font: plain letters instead of ₹ ▲ ▼)"
cat > $W/newsrecap.py <<'PY_RECAP'
#!/usr/bin/env python3
"""newsrecap.py - patch 125: 🗞 THE MORNING NEWS RECAP - one PDF page to "GIR Moves & News" every day at 08:30 IST.

  THE MORNING READ   three lines from the news reader: what an F&O trader must know before 09:15
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


def gather(now=None, db=None):
    """-> {"since", "prev", "overnight": [...], "session": [...], "market": [...], "reaction": [...], "held": n}"""
    now = now or dt.datetime.now(IST)
    prev = prev_session(now)
    t_close = dt.datetime.combine(prev, dt.time(15, 30), IST)
    t_open = dt.datetime.combine(prev, dt.time(9, 0), IST)
    out = {"now": now, "prev": prev, "since": t_close, "overnight": [], "session": [], "market": [], "reaction": [], "held": 0}
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
        if not items:
            return []
        lines = "\n".join("- %s %s %s: %s" % (x["at"].strftime("%a %H:%M"), x["s"], {"CE": "UP", "PE": "DOWN"}.get(x["side"], ""), x["h"]) for x in items)
        p = ("You are the senior news reader on an Indian F&O desk. It is %s, before the 09:15 open. These are the news lines since "
             "yesterday's close:\n%s\n\nWrite exactly 3 short lines (max 22 words each) for a trader: what matters most at the open "
             "today, naming the shares and UP / DOWN. No intro, no bullets symbols, plain text, one item per line.") % (g["now"].strftime("%a %d %b %H:%M"), lines)
        txt, _m = llmread.ask(p, max_tokens=300)
        return [re.sub(r"^[\-\*\d\.\)\s]+", "", x).strip() for x in (txt or "").split("\n") if x.strip()][:3]
    except Exception as ex:
        print("recap morning read: %s" % str(ex)[:80])
        return []


def build_pdf(g, path, read=None, caps=(24, 10, 10, 10)):
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
    return path, (n_on, n_mk, n_rx)


def caption(g):
    crit = [x for x in g["overnight"] if x["lvl"] == "critical"]
    top = (crit or g["overnight"])[:4]
    s = "🗞 GIR MORNING NEWS RECAP · %s 08:30 · %d overnight · %d critical" % (g["now"].strftime("%a %d %b"), len(g["overnight"]), len(crit))
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
cat > $D/p125test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p125test.py - 🗞 the morning news recap: one PDF page from the news GIR sent (overnight, market, yesterday's news ->
the close), sent as a document to GIR Moves & News. Sample data and a fake Telegram only."""
import os, sys, json, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import newsrecap
IST = newsrecap.IST
KEEP = "--keep" in sys.argv
tmp = tempfile.mkdtemp(prefix="p125")
try:
    newsrecap.BASE = tmp; os.makedirs(os.path.join(tmp, "data"))
    now = dt.datetime(2026, 11, 10, 8, 30, tzinfo=IST)            # Tuesday 08:30
    prev = "2026-11-09"
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    c.execute("create table news_react(id integer primary key, day text, t text, sym text, kind text, lvl text, side text, head text, ah int, p0 real, n0 real, b0 real,"
              " p5 real, n5 real, b5 real, p15 real, n15 real, b15 real, p60 real, n60 real, b60 real, pc real, nc real, bc real, pn real, nn real, bn real, nday text)")
    A = [
        (prev, "10:02:11", "📰", "TITAN", "CE", "📰 NEWS ▲ TITAN · RESULTS · Economic Times 10:01\n🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR\nTitan Q2 FY27 profit up 32%, jewellery sales beat estimates\nthe reader (claude-sonnet-4-5): profit and margins beat · IMPORTANT · sure 80%\nshare price likely going UP → CE side · WATCH, not a trade by itself\nhttps://economictimes.indiatimes.com/a/1.cms"),
        (prev, "13:40:00", "🚨", "GLENMARK", "CE", "🚨 SUDDEN GLENMARK ₹2625 · 13:40 · pharma\nEXTREME BULLISH → CE"),
        (prev, "17:05:30", "🚨", "ASTRAL", "PE", "🚨 CRITICAL NEWS ▼ ASTRAL · REG · Moneycontrol 17:05\n🟠 SOMETHING IS HAPPENING — not a trade by itself, open it on GIR\nAstral: income tax raids at 12 locations, CFO resigns\nthe reader (claude-sonnet-4-5): a raid plus the CFO leaving changes the investment case · CRITICAL · sure 90%\nshare price likely going DOWN → PE side · WATCH, not a trade by itself"),
        (prev, "18:20:00", "📰", "BEL", "CE", "📰 FILING ▲ BEL · ORDER · NSE 18:20\nBEL receives orders worth ₹909 crore from the defence ministry\nthe reader (claude-sonnet-4-5): order is 4% of yearly sales · IMPORTANT · sure 75%"),
        (prev, "19:10:00", "📄", "NBCC", "", "📄 NEWS · NBCC · MGMT · ET 19:10\nNBCC appoints new director (finance)"),
        (prev, "21:59:00", "📰", "INDIGO", "PE", "📰 NEWS ▼ INDIGO · OTHER · Mint 21:59\nLucknow-bound IndiGo flight returns to Bengaluru after hijack threat note\nthe reader (claude-sonnet-4-5): a safety scare, small for the business · IMPORTANT · sure 60%"),
        (prev, "22:05:00", "📰", "INDIGO", "PE", "📰 NEWS ▼ INDIGO · OTHER · ET 22:05\nLucknow-bound IndiGo flight returns to Bengaluru after hijack threat note\nthe reader (x): same · IMPORTANT · sure 60%"),
        (prev, "23:40:00", "🏛", "MARKET", "PE", "🏛 MARKET NEWS ▼ likely DOWN · 23:40 · Reuters\nUS 10-year yield jumps to 4.9% after strong jobs data\nwhy it matters: FPIs sell when US yields rise"),
        ("2026-11-10", "07:15:00", "📰", "OIL", "CE", "📰 NEWS ▲ OIL · OTHER · Moneycontrol 07:15\nCrude up 3% after explosions at Iran's Qeshm island\nthe reader (x): crude up helps the oil producers · IMPORTANT · sure 70%"),
        ("2026-11-10", "07:20:00", "📰", "DLF", "PE", "📰 NEWS ▼ DLF · REG · ndtvprofit 07:20\nold story\n⚠ NOT SENT to Telegram (400) — on the page only"),
    ]
    c.executemany("insert into alerts values(?,?,?,?,?,?)", A)
    c.execute("insert into news_react(day,t,sym,kind,lvl,side,head,p0,pc,nc) values(?,?,?,?,?,?,?,?,?,?)", (prev, "10:02:11", "TITAN", "📰", "important", "CE", "Titan Q2 FY27 profit up 32%, jewellery sales beat estimates", 3500, 3605, 25110))
    c.execute("insert into news_react(day,t,sym,kind,lvl,side,head,p0,pc,nc) values(?,?,?,?,?,?,?,?,?,?)", (prev, "11:30:00", "DABUR", "📰", "important", "PE", "Dabur: rural demand slows, volume growth 2%", 520, 524, 25110))
    c.commit(); c.close()
    json.dump({"items": [{"t": (now - dt.timedelta(hours=9)).timestamp(), "h": "RBI keeps repo rate at 5.5%, cuts CRR by 50 bps", "src": "Business Standard", "score": 7, "side": 1, "why": "more money in banks"},
                         {"t": (now - dt.timedelta(hours=2)).timestamp(), "h": "Brent crude jumps 3% on Middle East tension", "src": "Mint", "score": 5, "side": -1, "why": "India imports 85% of its oil"},
                         {"t": (now - dt.timedelta(days=3)).timestamp(), "h": "an old market line", "src": "Mint", "score": 9, "side": 0}]}, open(os.path.join(tmp, "data", "macro.json"), "w"))
    json.dump([{"at": "2026-11-09 20:00:00", "s": "DLF", "h": "DLF Shares Slump on Fresh CCI Probe", "why": "old"}], open(os.path.join(tmp, "data", "news_held.json"), "w"))
    g = newsrecap.gather(now)
    on = [(x["s"], x["lvl"]) for x in g["overnight"]]
    check("overnight = after Monday's 15:30 close, critical first, the IndiGo repeat once, NOT SENT left out: %s" % on,
          on[0] == ("ASTRAL", "critical") and [s for s, _ in on].count("INDIGO") == 1 and "DLF" not in [s for s, _ in on] and "TITAN" not in [s for s, _ in on]
          and set(s for s, _ in on) == {"ASTRAL", "BEL", "NBCC", "INDIGO", "OIL"})
    check("SUDDEN (an OI line) is not news; the session's news is Titan", "GLENMARK" not in str(g) and [x["s"] for x in g["session"]] == ["TITAN"])
    check("market & global: the US-yield line + RBI + crude, not the 3-day-old one: %d" % len(g["market"]), len(g["market"]) == 3 and "an old market line" not in str(g["market"]))
    check("yesterday's news → the close: Titan +3.0%% ✔, Dabur +0.8%% ✖ (the reader said DOWN): %s" % [(x["s"], x["mc"], x["right"]) for x in g["reaction"]],
          [(x["s"], x["mc"], x["right"]) for x in g["reaction"]] == [("TITAN", 3.0, True), ("DABUR", 0.77, False)])
    check("the old DLF story counted as held back: %d" % g["held"], g["held"] == 1)
    read = ["ASTRAL ▼: income-tax raids and the CFO quitting - expect a gap down, puts in focus.",
            "Crude +3% on Iran: OIL / ONGC ▲, paints and airlines (INDIGO) ▼.", "RBI's CRR cut helps banks ▲ - BANKNIFTY may lead at the open."]
    path = os.path.join(tmp, "data", "recap.pdf")
    path, shown = newsrecap.build_pdf(g, path, read)
    from reportlab.lib.pagesizes import A4  # noqa
    pdf = open(path, "rb").read()
    check("one PDF page: %d bytes, rows shown %s" % (len(pdf), shown), pdf.startswith(b"%PDF") and pdf.count(b"/Type /Page\n") + pdf.count(b"/Type /Page ") + pdf.count(b"/Type /Page>") <= 1 and b"/Count 1" in pdf)
    big = dict(g); big["overnight"] = [dict(g["overnight"][1], h="a long headline about something that happened %d " % i * 3) for i in range(60)]
    p2, sh2 = newsrecap.build_pdf(big, os.path.join(tmp, "data", "big.pdf"), read)
    check("60 overnight lines still fit on ONE page (fewer rows shown: %s)" % (sh2,), b"/Count 1" in open(p2, "rb").read() and sh2[0] < 60)
    cap = newsrecap.caption(g)
    check("the caption: %s" % cap.replace("\n", " / "), cap.startswith("🗞 GIR MORNING NEWS RECAP · Tue 10 Nov 08:30 · 5 overnight · 1 critical") and "ASTRAL ▼" in cap)
    SENT = []

    class Resp(object):
        ok, status_code, text = True, 200, "{}"
    newsrecap_env = os.environ.get("TELEGRAM_TOKEN")
    os.environ["TELEGRAM_TOKEN"] = "test"; os.environ["TG_CHAT_BOX"] = "-100box"
    import tglanes
    tglanes.ENVS = [os.path.join(tmp, ".env")]; open(tglanes.ENVS[0], "w").write("TG_CHAT_GIRMOVES=-100mv\n"); tglanes._C["at"] = 0.0
    r = newsrecap.send_pdf(path, cap, post=lambda url, data=None, files=None, timeout=None: SENT.append((url, data, files["document"][0])) or Resp())
    check("sent as a PDF document to GIR Moves & News: %s" % (SENT[0][1]["chat_id"] if SENT else None), r and SENT and SENT[0][0].endswith("/sendDocument") and SENT[0][1]["chat_id"] == "-100mv" and SENT[0][2].endswith(".pdf"))
    if KEEP:
        shutil.copy(path, os.path.join(B, "p125_sample.pdf")); shutil.copy(p2, os.path.join(B, "p125_big.pdf"))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP125 MORNING RECAP TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cp $W/newsrecap.py $D/
cd $D && python3 -m py_compile newsrecap.py p125test.py || back
timeout 120 python3 p125test.py 2>&1 | grep "OK  \|FAIL\|RECAP TEST"
timeout 120 python3 p125test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
cat > /etc/systemd/system/gir-recap.service <<'UNIT'
[Unit]
Description=GIR morning news recap (one PDF page to GIR Moves & News)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 newsrecap.py --send >> data/recap.log 2>&1'
UNIT
cat > /etc/systemd/system/gir-recap.timer <<'UNIT'
[Unit]
Description=GIR morning news recap at 08:30 IST every day
[Timer]
OnCalendar=*-*-* 08:30:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-recap.timer >/dev/null 2>&1 || back
echo "recap timer: $(systemctl is-active gir-recap.timer) · next: $(systemctl list-timers gir-recap.timer --no-pager | sed -n 2p | cut -c1-32)"
echo
echo "PATCH 125 APPLIED. Sending today's recap now to GIR Moves & News ..."
cd /home/globalbot && set -a && source .env && set +a && cd $D && python3 newsrecap.py --send
echo "Send one again any time:  systemctl start gir-recap.service      PDFs kept in $D/data/recap/"
