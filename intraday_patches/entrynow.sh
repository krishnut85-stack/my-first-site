#!/bin/bash
# entrynow.sh - which F&O options are at the right time to enter NOW: GIR's EARLY BUY signals cross-checked with the OI battle,
# the order book, results in 3 days, IV percentile and how far it already ran -> READY / WAIT / AVOID. Read-only, sends nothing.
cd /home/globalbot/intraday && python3 - <<'EOF'
import json, datetime as dt
import dashserve, oibattle, bookpress
try:
    import idxdesk
except Exception:
    idxdesk = None
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
now = dt.datetime.now(IST)
E = dashserve.early(fresh=True)
rows = [r for r in (E.get("rows") or []) if r.get("verdict") == "BUY"]
out = []
for r in rows:
    s, side = r["s"], r.get("side")
    d = 1 if side == "CE" else -1
    c = dashserve.checklist_for(s, peek=True) or {}
    ivp, res, em = c.get("ivp"), c.get("results_in"), c.get("em")
    try:
        b = oibattle.read(s, ivp)
    except Exception:
        b = None
    try:
        bk = bookpress.for_sym(s)
    except Exception:
        bk = None
    ok, bad = [], []
    ok.append("EARLY %s" % r.get("how", ""))
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
        if bk["side"] == d:
            ok.append("book %s" % bk["word"].lower())
        elif bk["side"] == -d:
            bad.append("book %s" % bk["word"].lower())
    if res is not None and 0 <= res <= 3:
        bad.append("RESULTS in %d day(s) - IV drop" % res)
    if ivp is not None and ivp >= 80:
        bad.append("options expensive (IV pct %d)" % ivp)
    since = r.get("since")
    if since is not None and since * 1 >= 3:
        bad.append("already moved %+.1f%% its way - late" % since)
    if since is not None and since <= -1.5:
        bad.append("moving against the signal %+.1f%%" % since)
    hard = [x for x in bad if x.startswith(("RESULTS", "OI says", "already", "moving against"))]
    grade = "AVOID" if hard else ("READY" if not bad else "WAIT")
    st = r.get("stk") or {}
    trade = ("%s %s %s @ ₹%s · stop ₹%s%s" % (side, st.get("k"), str(st.get("exp") or "")[5:], st.get("p"), st.get("stop"),
             (" · 1 lot ₹{:,}".format(int(st["cost"])) if st.get("cost") else ""))) if st else "%s (no strike read)" % side
    lv = (" · ceiling %g / floor %g" % (b["ceil"], b["floor"])) if b else ""
    out.append((["READY", "WAIT", "AVOID"].index(grade), -len(ok), grade, s, trade + lv, ok, bad))
out.sort()
print("ENTRY CHECK %s · %d BUY signals on the EARLY board" % (now.strftime("%H:%M"), len(rows)))
for _, _, g, s, t, ok, bad in out:
    if g == "AVOID":
        continue
    print("\n%-5s %-11s %s" % (g, s, t))
    print("      for:     " + " · ".join(ok))
    if bad:
        print("      against: " + " · ".join(bad))
av = [x for x in out if x[2] == "AVOID"]
if av:
    print("\nAVOID: " + " · ".join("%s (%s)" % (x[3], "; ".join(h for h in x[6] if h.startswith(("RESULTS", "OI says", "already", "moving against"))) or (x[6][0] if x[6] else "")) for x in av[:15]))
if idxdesk:
    J = idxdesk.load() or {}
    for n in ("NIFTY", "BANKNIFTY"):
        x = J.get(n) or {}
        dc = x.get("dec") or {}
        if dc:
            t = dc.get("trade") or {}
            print("\n%s %s · %s%s · %d up / %d down of %d checks" % (n, x.get("t", ""), dc.get("word"),
                  (" %s %s @ ₹%s stop ₹%s" % (t.get("strike"), t.get("kind"), t.get("prem"), t.get("stop"))) if t else "", dc.get("bull", 0), dc.get("bear", 0), len(dc.get("why") or [])))
print("\nREADY = signal + OI + order book agree, no results within 3 days, options not expensive. Not advice - size small, keep the stop.")
EOF
