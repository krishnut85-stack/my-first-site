#!/bin/bash
# PATCH 141 - THE ENTRY CHECK AS A PDF, 09:16 · 12:00 · 14:00 ON EVERY TRADING DAY.
#   GIR's ⚡ EARLY BUY signals, each cross-checked with the OI battle, the order book, results in 3 days, the IV percentile and how far
#   it already ran -> READY / WAIT / AVOID, plus the NIFTY / BANKNIFTY desk's decision. One A4 page to the 🗞 Recap topic.
#   Only on a trading day (holidays / special sessions from sessions.py), inside the session.
#   entryreport.py (new) · gir-entry.timer + gir-entry.service (new). Touches no running service - safe in market hours.
D=/home/globalbot/intraday; W=/tmp/g141; mkdir -p $W
[ -f $D/bookpress.py ] || { echo "patch 137 is not installed yet - paste patch 137 first"; exit 1; }
[ -f $D/entryreport.py ] && { echo "patch 141 is already installed"; exit 1; }
back() { rm -f $D/entryreport.py $D/p141test.py; systemctl disable --now gir-entry.timer >/dev/null 2>&1; rm -f /etc/systemd/system/gir-entry.timer /etc/systemd/system/gir-entry.service; systemctl daemon-reload; echo "ERROR - removed again, nothing else was changed"; exit 1; }
cat > $D/entryreport.py <<'PY_ENTRY'
#!/usr/bin/env python3
"""entryreport.py - patch 141: THE ENTRY CHECK AS A PDF, 09:16 · 12:00 · 14:00 on every trading day (gir-entry.timer).
Which F&O options are at the right time to enter NOW: GIR's ⚡ EARLY BUY signals, each cross-checked with
  the OI battle (agrees with the side?) · the order book (buyers / sellers loading the same way?) · results in 3 days (the IV drop)
  · the IV percentile (options expensive?) · how far it already ran (late?) · moving against the signal
-> READY (all agree) / WAIT (something not confirmed - for and against listed) / AVOID (the reason), and the NIFTY / BANKNIFTY
options desk's decision. One A4 page to the 🗞 Recap topic. A filter, not advice - size small, keep the stop.
  python3 entryreport.py            build it now, print the lines (nothing sent)
  python3 entryreport.py --send     build and send (only on a trading day, inside the session)
  systemctl start gir-entry.service send one now"""
import os, sys, time, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(BASE, "data", "entry")
HARD = ("RESULTS", "OI says", "already", "moving against")


def scan(now=None):
    """-> {"t", "n", "rows": [{"grade", "s", "side", "trade", "levels", "ok", "bad"}], "idx": [(name, line)]}"""
    import dashserve, oibattle, bookpress
    now = now or dt.datetime.now(IST)
    E = dashserve.early(fresh=True)
    sig = [r for r in (E.get("rows") or []) if r.get("verdict") == "BUY"]
    rows = []
    for r in sig:
        s, side = r["s"], r.get("side")
        d = 1 if side == "CE" else -1
        try:
            c = dashserve.checklist_for(s, peek=True) or {}
        except Exception:
            c = {}
        ivp, res = c.get("ivp"), c.get("results_in")
        try:
            b = oibattle.read(s, ivp)
        except Exception:
            b = None
        try:
            bk = bookpress.for_sym(s)
        except Exception:
            bk = None
        ok, bad = ["EARLY %s" % (r.get("how") or "")], []
        if b:
            v = b["verdict"]
            if (v == "BULLISH" and d > 0) or (v == "BEARISH" and d < 0):
                ok.append("OI %s" % v)
            elif v == "BATTLE":
                bad.append("OI battle (no side)")
            else:
                bad.append("OI says %s" % v)
        else:
            bad.append("no OI read")
        if bk:
            if bk.get("side") == d:
                ok.append("book %s" % bk["word"].lower())
            elif bk.get("side") == -d:
                bad.append("book %s" % bk["word"].lower())
        if res is not None and 0 <= res <= 3:
            bad.append("RESULTS in %d day%s - IV drop" % (res, "" if res == 1 else "s"))
        if ivp is not None and ivp >= 80:
            bad.append("options expensive (IV pct %d)" % ivp)
        since = r.get("since")
        if since is not None and since >= 3:
            bad.append("already moved %+.1f%% its way - late" % since)
        if since is not None and since <= -1.5:
            bad.append("moving against the signal %+.1f%%" % since)
        hard = [x for x in bad if x.startswith(HARD)]
        grade = "AVOID" if hard else ("READY" if not bad else "WAIT")
        st = r.get("stk") or {}
        trade = ("%s %s %s @ ₹%s · stop ₹%s%s" % (side, st.get("k"), str(st.get("exp") or "")[5:], st.get("p"), st.get("stop"),
                 (" · 1 lot ₹{:,}".format(int(st["cost"])) if st.get("cost") else ""))) if st else "%s (no strike read yet)" % side
        rows.append({"grade": grade, "s": s, "side": side, "trade": trade, "levels": ("ceiling %g · floor %g" % (b["ceil"], b["floor"])) if b else "",
                     "ok": ok, "bad": bad, "hard": hard, "since": since})
    order = {"READY": 0, "WAIT": 1, "AVOID": 2}
    rows.sort(key=lambda x: (order[x["grade"]], -len(x["ok"]), len(x["bad"])))
    idx = []
    try:
        import idxdesk
        J = idxdesk.load() or {}
        for n in ("NIFTY", "BANKNIFTY"):
            x = J.get(n) or {}
            dc = x.get("dec") or {}
            if dc and x.get("day") == str(now.date()):
                t = dc.get("trade") or {}
                idx.append((n, "%s · %s%s · %d ▲ / %d ▼ of %d checks · floor %s · ceiling %s" % (
                    x.get("t", ""), dc.get("word"), (" %g %s @ ₹%s stop ₹%s" % (t.get("strike") or 0, t.get("kind"), t.get("prem"), t.get("stop"))) if t else "",
                    dc.get("bull", 0), dc.get("bear", 0), len(dc.get("why") or []), x.get("floor"), x.get("ceil"))))
    except Exception:
        pass
    return {"t": now, "n": len(sig), "rows": rows, "idx": idx}


def text(res):
    L = ["GIR ENTRY CHECK %s · %d BUY signals" % (res["t"].strftime("%a %d %b %H:%M"), res["n"])]
    for r in res["rows"]:
        if r["grade"] == "AVOID":
            continue
        L.append("%-5s %-11s %s%s" % (r["grade"], r["s"], r["trade"], (" · " + r["levels"]) if r["levels"] else ""))
        L.append("      for: " + " · ".join(r["ok"]))
        if r["bad"]:
            L.append("      against: " + " · ".join(r["bad"]))
    av = [r for r in res["rows"] if r["grade"] == "AVOID"]
    if av:
        L.append("AVOID: " + " · ".join("%s (%s)" % (r["s"], "; ".join(r["hard"])) for r in av))
    for n, x in res["idx"]:
        L.append("%s %s" % (n, x))
    return "\n".join(L)


def build_pdf(res, path):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    F, FB = "Helvetica", "Helvetica-Bold"
    try:
        import newsrecap
        if all(os.path.exists(f) for f in newsrecap.FONTS):
            pdfmetrics.registerFont(TTFont("GirSans", newsrecap.FONTS[0])); pdfmetrics.registerFont(TTFont("GirSans-B", newsrecap.FONTS[1]))
            F, FB = "GirSans", "GirSans-B"
    except Exception:
        pass
    uni = F == "GirSans"
    esc = lambda s: (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") if uni else \
        (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("₹", "Rs ").replace("·", "-").replace("▲", "up").replace("▼", "down").encode("latin-1", "ignore").decode("latin-1")
    INK, DIM = colors.HexColor("#111827"), colors.HexColor("#6b7280")
    st = lambda size=8, bold=False, col=INK: ParagraphStyle("x", fontName=FB if bold else F, fontSize=size, leading=size * 1.25, textColor=col)
    G = {"READY": colors.HexColor("#0a8a3a"), "WAIT": colors.HexColor("#b26a00"), "AVOID": colors.HexColor("#c62828")}
    now = res["t"]
    rows = res["rows"]
    nR = sum(1 for r in rows if r["grade"] == "READY"); nW = sum(1 for r in rows if r["grade"] == "WAIT"); nA = len(rows) - nR - nW
    story = []
    hdr = Table([[Paragraph('<font color="#ffb000"><b>GIR</b></font> <font color="#ffffff"><b>ENTRY CHECK</b></font>', st(13, col=colors.white)),
                  Paragraph('<font color="#ffffff">%s IST</font><br/><font color="#9ca3af">%d BUY signals · %d READY · %d WAIT · %d AVOID</font>' % (
                      esc(now.strftime("%a %d %b %Y · %H:%M")), res["n"], nR, nW, nA), st(8, col=colors.white))]], colWidths=[250, 281])
    hdr.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#0b0d11")), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                             ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6), ("LEFTPADDING", (0, 0), (-1, -1), 8)]))
    story += [hdr, Spacer(1, 6)]
    if res["idx"]:
        story.append(Paragraph("<b>INDEX OPTIONS DESK</b>", st(9.5, col=colors.HexColor("#b26a00"))))
        for n, x in res["idx"]:
            story.append(Paragraph("<b>%s</b> %s" % (esc(n), esc(x)), st(8)))
        story.append(Spacer(1, 5))
    for g, sub in (("READY", "signal + OI + order book agree · no results within 3 days · options not expensive · not late"),
                   ("WAIT", "a signal, but something is not confirmed yet - see 'against'")):
        R = [r for r in rows if r["grade"] == g][:18 if g == "READY" else 14]
        story.append(Paragraph('<font color="%s"><b>%s</b></font> <font color="#6b7280" size="7">%s</font>' % (G[g].hexval().replace("0x", "#"), g, esc(sub)), st(9.5)))
        if not R:
            story.append(Paragraph("none now", st(7.5, col=DIM)))
        else:
            data = [[Paragraph("<b>%s</b>" % esc(r["s"]), st(8.2)),
                     Paragraph(esc(r["trade"]) + (('<br/><font color="#6b7280">%s</font>' % esc(r["levels"])) if r["levels"] else ""), st(7.6)),
                     Paragraph(esc(" · ".join(r["ok"])) + (('<br/><font color="#c62828">against: %s</font>' % esc(" · ".join(r["bad"]))) if r["bad"] else ""), st(7.4))] for r in R]
            t = Table(data, colWidths=[72, 200, 259])
            t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LINEBELOW", (0, 0), (-1, -1), 0.25, colors.HexColor("#e5e7eb")),
                                   ("TOPPADDING", (0, 0), (-1, -1), 1.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5), ("LEFTPADDING", (0, 0), (-1, -1), 2)]))
            story.append(t)
        story.append(Spacer(1, 6))
    av = [r for r in rows if r["grade"] == "AVOID"]
    if av:
        story.append(Paragraph('<font color="#c62828"><b>AVOID</b></font> <font color="#6b7280" size="7">a hard reason against</font>', st(9.5)))
        story.append(Paragraph(esc(" · ".join("%s %s (%s)" % (r["s"], r["side"], "; ".join(r["hard"])) for r in av[:40])), st(7.4)))
        story.append(Spacer(1, 6))
    story.append(Paragraph("GIR · a filter, not advice: size small, keep the stop · READY needs the EARLY signal (2+ of news / OI / futures money / price), "
                           "the OI battle and the order book on the same side, no results within 3 days, IV percentile under 80, not 3%+ already run.", st(6.4, col=DIM)))
    doc = SimpleDocTemplate(path, pagesize=A4, leftMargin=32, rightMargin=32, topMargin=26, bottomMargin=22, title="GIR entry check %s" % now.strftime("%Y-%m-%d %H:%M"), author="GIR")
    doc.build(story)
    return path


def run(send=False, now=None):
    now = now or dt.datetime.now(IST)
    if send:
        try:
            import sessions
            s = sessions.session(now.date())
        except Exception:
            s = {"open": "09:15", "close": "15:30"} if now.weekday() < 5 else None
        hm = now.strftime("%H:%M")
        if not s or not (s["open"] <= hm <= s["close"]):
            print("entry check: no session now (%s) - nothing sent" % hm)
            return None
    res = scan(now)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "entry_%s.pdf" % now.strftime("%Y%m%d_%H%M"))
    build_pdf(res, path)
    nR = sum(1 for r in res["rows"] if r["grade"] == "READY"); nW = sum(1 for r in res["rows"] if r["grade"] == "WAIT")
    cap = "🗞 GIR ENTRY CHECK · %s · %d READY · %d WAIT · %d AVOID" % (now.strftime("%a %d %b %H:%M"), nR, nW, len(res["rows"]) - nR - nW)
    if nR:
        cap += "\nREADY: " + " · ".join("%s %s" % (r["s"], r["side"]) for r in res["rows"] if r["grade"] == "READY")[:600]
    print(text(res))
    if send:
        import newsrecap
        ok = newsrecap.send_pdf(path, cap)
        print("sent: %s · %s" % (ok, path))
    else:
        print("built (not sent): %s" % path)
    for f in sorted(os.listdir(OUT))[:-60]:                       # keep the last 60
        try:
            os.remove(os.path.join(OUT, f))
        except Exception:
            pass
    return path


if __name__ == "__main__":
    run(send="--send" in sys.argv)
PY_ENTRY
cat > $D/p141test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p141test.py - THE ENTRY CHECK PDF: GIR's EARLY BUY signals graded READY / WAIT / AVOID (OI, order book, results in 3 days, IV,
late), a one-page PDF with them and the index desk, sent to the 🗞 Recap topic only inside a trading session. Fakes - nothing is sent."""
import os, sys, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import entryreport, dashserve, oibattle, bookpress, newsrecap, tglanes
IST = entryreport.IST
tmp = tempfile.mkdtemp(prefix="p141")
try:
    entryreport.OUT = os.path.join(tmp, "entry")
    dashserve.early = lambda fresh=False: {"rows": [
        {"s": "HINDALCO", "verdict": "BUY", "side": "CE", "how": "4 of 4 agree", "since": 1.2, "stk": {"k": 780, "exp": "2026-11-23", "p": 14.9, "stop": 7.45, "cost": 11175}},
        {"s": "COCHINSHIP", "verdict": "BUY", "side": "CE", "how": "2 of 4 agree", "since": 0.5, "stk": {"k": 1260, "exp": "2026-11-23", "p": 48.5, "stop": 24}},
        {"s": "BOSCHLTD", "verdict": "BUY", "side": "PE", "how": "4 of 4 agree", "since": -0.8, "stk": {"k": 49500, "exp": "2026-11-23", "p": 1240, "stop": 620}},
        {"s": "TCS", "verdict": "WATCH", "side": "CE", "how": "1 of 4"}]}
    C = {"HINDALCO": {"ivp": 45}, "COCHINSHIP": {"ivp": 81, "results_in": 1}, "BOSCHLTD": {"ivp": 70}}
    dashserve.checklist_for = lambda s, peek=False: C.get(s, {})
    oibattle.read = lambda s, ivp=None: {"HINDALCO": {"verdict": "BULLISH", "ceil": 800, "floor": 760}, "COCHINSHIP": {"verdict": "BATTLE", "ceil": 1300, "floor": 1200},
                                         "BOSCHLTD": {"verdict": "BATTLE", "ceil": 50000, "floor": 49000}}.get(s)
    bookpress.for_sym = lambda s: {"HINDALCO": {"side": 1, "word": "BUYERS LOADING"}, "BOSCHLTD": {"side": -1, "word": "SELLERS QUEUED"}}.get(s)
    now = dt.datetime(2026, 11, 9, 12, 0, tzinfo=IST)
    res = entryreport.scan(now)
    g = [(r["s"], r["grade"]) for r in res["rows"]]
    check("graded: %s (TCS - only a WATCH - left out)" % g, g == [("HINDALCO", "READY"), ("BOSCHLTD", "WAIT"), ("COCHINSHIP", "AVOID")] and res["n"] == 3)
    co = res["rows"][2]
    check("COCHINSHIP: AVOID - %s" % co["hard"], co["hard"] == ["RESULTS in 1 day - IV drop"])
    SENT = []
    newsrecap.send_pdf = lambda path, cap, post=None: SENT.append((path, cap)) or True
    import sessions, holidays
    holidays.holiday = lambda d=None: ("weekend" if d.weekday() >= 5 else None)
    sessions.FILE = os.path.join(tmp, "sessions.json")
    p = entryreport.run(send=True, now=now)
    from pypdf import PdfReader
    rd = PdfReader(p); tx = rd.pages[0].extract_text()
    check("one page: READY HINDALCO, WAIT BOSCHLTD, AVOID COCHINSHIP", len(rd.pages) == 1 and "HINDALCO" in tx and "BOSCHLTD" in tx and "COCHINSHIP" in tx and "ENTRY CHECK" in tx)
    check("sent once: %s" % (SENT[0][1].split("\n")[0] if SENT else None), len(SENT) == 1 and SENT[0][1].startswith("🗞 GIR ENTRY CHECK · Mon 09 Nov 12:00 · 1 READY · 1 WAIT · 1 AVOID") and "READY: HINDALCO CE" in SENT[0][1])
    check("it goes to the 🗞 Recap topic (%s)" % tglanes.topic(SENT[0][1]), tglanes.topic(SENT[0][1]) == "recap")
    entryreport.run(send=True, now=dt.datetime(2026, 11, 7, 12, 0, tzinfo=IST))            # a Saturday
    entryreport.run(send=True, now=dt.datetime(2026, 11, 9, 16, 30, tzinfo=IST))           # after the close
    check("Saturday / after the close: nothing sent (%d)" % len(SENT), len(SENT) == 1)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("\nP141 ENTRY CHECK PDF TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
cd $D && python3 -m py_compile entryreport.py p141test.py || back
timeout 120 python3 p141test.py 2>&1 | grep "OK  \|FAIL\|P141"
timeout 120 python3 p141test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
cat > /etc/systemd/system/gir-entry.service <<'UNIT'
[Unit]
Description=GIR entry check PDF (09:16 / 12:00 / 14:00 on trading days)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 entryreport.py --send >> data/entry.log 2>&1'
UNIT
cat > /etc/systemd/system/gir-entry.timer <<'UNIT'
[Unit]
Description=GIR entry check PDF
[Timer]
OnCalendar=*-*-* 09:16:00 Asia/Kolkata
OnCalendar=*-*-* 12:00:00 Asia/Kolkata
OnCalendar=*-*-* 14:00:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-entry.timer >/dev/null 2>&1 || back
echo "entry timer: $(systemctl is-active gir-entry.timer) · next: $(systemctl list-timers gir-entry.timer --no-pager | sed -n 2p | cut -c1-32)"
echo
echo "PATCH 141 APPLIED. One is being sent now (if the market is open) - see the 🗞 Recap topic:"
systemctl start gir-entry.service; sleep 2; tail -25 $D/data/entry.log
echo
echo "Send one any time:  systemctl start gir-entry.service      PDFs kept in $D/data/entry/"
