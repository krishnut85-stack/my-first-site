#!/bin/bash
# PATCH 143 - 🌅 OPENING CALL AT 09:12, every trading day. GIR collects the shares with a reason known before the open (results in
#   the next days - COCHINSHIP, EICHERMOT · results out since yesterday 15:30 vs the brokers · news with a side · yesterday's
#   futures build-up), reads the pre-open price and the buy / sell orders waiting, and calls:
#   GO   gap 0.3-4% its way + the book with it -> 🌅 OPENING CALL ▲ SYM CE · GO in Box Picks, ringing: the strike, the stop, out by
#        15:15 (results today: HALF size, out by 14:30) - and a ⚡ ENTER NOW signal until 10:00
#   WAIT / NO and the big gaps with no reason -> one quiet summary in ⚙️ System
#   09:20 + 09:35: ❌ OPENING CALL FAILED (back under the stop - out), ringing · ✅ HOLDING, quiet
#   opencall.py (new) · enternow.py, alertword.py, tglanes.py, home.html · 2 timers. Restarts gir-dash, gir-intraday - outside hours.
D=/home/globalbot/intraday; U=/etc/systemd/system; TS=$(date +%m%d%H%M); W=/tmp/g143; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0845 ] && [ "$H" -le 1535 ]; then echo "market hours (IST $H) - run after 15:35 or before 08:45"; exit 1; fi
grep -q "patch 142b" $D/enternow.py 2>/dev/null || { echo "patch 142b is not installed yet - install it first"; exit 1; }
grep -q "patch 143" $D/enternow.py && { echo "patch 143 is already installed"; exit 1; }
F="enternow.py alertword.py tglanes.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/opencall.py $D/p143test.py; systemctl disable --now gir-opencall.timer gir-opencall-check.timer 2>/dev/null
         rm -f $U/gir-opencall.service $U/gir-opencall.timer $U/gir-opencall-check.service $U/gir-opencall-check.timer; systemctl daemon-reload; systemctl restart gir-dash gir-intraday; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p143_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p143_patch.py - PATCH 143: 🌅 OPENING CALL wired in: a GO is a ringing signal for ⚡ ENTER NOW until 10:00; the GO and the
FAILED lines ring in Box Picks; the summary is quiet in ⚙️ System.
Usage: python3 p143_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "enternow.py": [
        ('''LIVE_KINDS = {"news-pre": 600, "rot-in": 630}''', '''LIVE_KINDS = {"news-pre": 600, "rot-in": 630, "open-call": 600}      # patch 143: + the 🌅 OPENING CALL GO'''),
        ('''        if kind in ("📄", "📰") and re.search(r"[▲▼]", head.split("·")[0]) and m >= 480 and t - m <= VALID["news"]:''',
         '''        if head.startswith("🌅 OPENING CALL") and "GO" in head:   # patch 143: the 09:12 call - a signal until 10:00
            if t - m <= 50:
                out.append(("open-call", d, m, head[:90]))
            continue
        if kind in ("📄", "📰") and re.search(r"[▲▼]", head.split("·")[0]) and m >= 480 and t - m <= VALID["news"]:'''),
        ('''for k in ("news-pre", "news-day", "rule", "box", "oi", "volume", "rot-in", "rot-out")}''',
         '''for k in ("news-pre", "news-day", "rule", "box", "oi", "volume", "rot-in", "rot-out", "open-call")}'''),
    ],
    "alertword.py": [
        ('''    if H2.startswith("⚡ ENTER NOW"):                             # patch 142: the entry BEFORE the move - rings loud''',
         '''    if H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2:   # patch 143: GO before the open / get out - rings loud
        return "act"
    if H2.startswith("⚡ ENTER NOW"):                             # patch 142: the entry BEFORE the move - rings loud'''),
    ],
    "tglanes.py": [
        ('''CIRCUIT|ENTER NOW|MARKET ROTATION")''', '''CIRCUIT|ENTER NOW|MARKET ROTATION|🌅 OPENING CALL|OPENING CALL FAILED")   # patch 143'''),
    ],
    "home.html": [
        ('''  if(/^⚡ ENTER NOW/.test(H)) return "act";      // patch 142: the entry before the move''',
         '''  if(/^🌅 OPENING CALL|OPENING CALL FAILED/.test(H)) return "act";      // patch 143: the 09:12 call / get out
  if(/^⚡ ENTER NOW/.test(H)) return "act";      // patch 142: the entry before the move'''),
        ('''CIRCUIT|ENTER NOW|MARKET ROTATION/.test(H)) return "critical";''', '''CIRCUIT|ENTER NOW|MARKET ROTATION|🌅 OPENING CALL|OPENING CALL FAILED/.test(H)) return "critical";'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        if "patch 143" in s:
            print("patch 143 is already in %s" % fn); return 1
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
cat > $D/opencall.py <<'PY_OC'
#!/usr/bin/env python3
"""opencall.py - patch 143: 🌅 OPENING CALL at 09:12 (Rama, 9 Nov: "all the moves happen from 09:15 · if COCHINSHIP shows a gap up,
it is good to go - we expect good results · EICHERMOT results are coming: if it goes up, go"). The backtest of 9 Nov: the news
before the open was right 4 of 5 - the move is decided before 09:15, so GIR reads it before 09:15.

  THE CANDIDATES (a reason with a side, known before the open)
    results-run-up   results in the next 0-5 days (results_cal) - the side is the pre-open gap's
    results-out      results filed since yesterday 15:30 against the brokers (ABOVE / BELOW) or last year (BEAT / MISS)
    news             a 📄 / 📰 story with a side since yesterday 15:30 (not ALREADY KNOWN, not stale)
    money            yesterday: futures OI +5%+ with the price 1.5%+ the same way (long / short build-up)
  THE PRE-OPEN (09:00-09:08 order matching; read at 09:12 - one Kite quote for every F&O share)
    gap              the opening price vs yesterday's close
    book             the buy orders waiting vs the sell orders waiting
  THE CALL (per candidate, d = its side)
    GO     the gap 0.3%-4% its way and the book with it (buyers 1.2x+ for CE, sellers for PE) -> 🌅 OPENING CALL ▲ SYM CE ·
           GO, ringing in Box Picks: the reason, the gap, the book, the strike, the stop (back under yesterday's close / 1% under
           the open = out), out by 15:15 (results today: out by 14:30, half size)
    WAIT   opened 4%+ its way (late - a dip to the open is the entry, not the open) · no real gap · the book against
    NO     opening against the story
    + the biggest pre-open gaps with no reason GIR knows (a look, not a call)        -> one quiet summary in ⚙️ System
  09:20 / 09:35 (--check): every GO again: ✅ HOLDING (above the open) - quiet · ❌ OPENING CALL FAILED (back under yesterday's
           close / the stop) - ringing, "out"
  Each GO is also a signal for ⚡ ENTER NOW (rings until 10:00 when the price confirms).
  python3 opencall.py [--send] [--check]      (no --send = print only)"""
import os, re, sys, json, time, sqlite3, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
FILE = os.path.join(BASE, "data", "opencall.json")
GAP_MIN, GAP_MAX, BOOK_MIN, RUNUP_DAYS = 0.3, 4.0, 1.2, 5


def _ro(name):
    return sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, name), uri=True, timeout=5)


def _p(v):
    return "{:,.2f}".format(v) if v < 100 else "{:,.1f}".format(v) if v < 10000 else "{:,.0f}".format(v)


def fo_list():
    try:
        c = _ro("chains.db"); v = {r[0]: r[1] for r in c.execute("select sym, lot from fo_list")}; c.close(); return v
    except Exception:
        return {}


def prev_day(now):
    """the last weekday before today, 15:30 IST, as epoch (the news / results window starts there)"""
    d = now.date() - dt.timedelta(days=1)
    while d.weekday() > 4:
        d -= dt.timedelta(days=1)
    return dt.datetime(d.year, d.month, d.day, 15, 30, tzinfo=IST), str(d)


# ---------- the candidates ----------
def candidates(now, fo):
    """-> {sym: {"d": 1 / -1 / 0 (0 = the gap decides), "why": [..], "kind": [..], "res": days or None}}"""
    t0, d0 = prev_day(now)
    today = str(now.date())
    C = {}

    def add(s, d, kind, why, res=None):
        if fo and s not in fo:
            return
        x = C.setdefault(s, {"d": 0, "why": [], "kind": [], "res": None})
        if d and not x["d"]:
            x["d"] = d
        elif d and x["d"] and d != x["d"]:
            x["conflict"] = True
        x["why"].append(why); x["kind"].append(kind)
        if res is not None:
            x["res"] = res
    try:                                                         # results in the next days
        c = _ro("chains.db")
        for s, d in c.execute("select sym, min(d) from results_cal where d>=? and d<=? group by sym",
                              (today, str(now.date() + dt.timedelta(days=RUNUP_DAYS)))):
            n = (dt.date.fromisoformat(d) - now.date()).days
            add(s, 0, "results-run-up", "results %s (%s)" % ("TODAY" if n == 0 else "tomorrow" if n == 1 else "in %d days" % n, d[5:]), n)
        c.close()
    except Exception:
        pass
    try:                                                         # results out since yesterday 15:30
        c = _ro(os.path.join("data", "expect.db"))
        for s, q, tf, verdict in c.execute("select sym, q, t_filed, verdict from act where t_filed>=?", (t0.timestamp(),)):
            cm = c.execute("select word, surprise from cmp where sym=? and q=?", (s, q)).fetchone()
            w = (cm[0] if cm else "") or ""
            d = 1 if ("ABOVE" in w or (not w and verdict and "BEAT" in verdict)) else -1 if ("BELOW" in w or (not w and verdict and "MISS" in verdict)) else 0
            if d:
                add(s, d, "results-out", "results out %s: %s" % (q, w or verdict))
        c.close()
    except Exception:
        pass
    try:                                                         # news with a side since yesterday 15:30
        c = _ro("tomorrow.db")
        rows = c.execute("select day, t, kind, sym, side, text from alerts where (day=? and t>='15:30') or day=? order by day, t", (d0, today)).fetchall()
        c.close()
        try:
            import dashserve
            stale = dashserve._stale_news
        except Exception:
            stale = lambda h, t: "ALREADY KNOWN" in (t or "")
        for day, t, kind, s, side, text in rows:
            head = (text or "").split("\n")[0]
            if kind in ("📄", "📰") and side in ("CE", "PE") and re.search(r"[▲▼]", head.split("·")[0]) and not stale(head, text):
                add(s, 1 if side == "CE" else -1, "news", "news %s %s: %s" % (day[5:], t[:5], head[:90]))
    except Exception:
        pass
    try:                                                         # yesterday's futures money
        c = _ro(os.path.join("data", "oistudy.db"))
        dd = c.execute("select max(d) from day where d<?", (today,)).fetchone()[0]
        if dd:
            pv = c.execute("select max(d) from day where d<?", (dd,)).fetchone()[0]
            prev = {r[0]: r[1] for r in c.execute("select sym, spot from day where d=?", (pv,))} if pv else {}
            for s, spot, foi, fdoi in c.execute("select sym, spot, foi, fdoi from day where d=?", (dd,)):
                if not (spot and prev.get(s) and foi and fdoi and foi - fdoi > 0):
                    continue
                pch, och = (spot / prev[s] - 1) * 100, fdoi / (foi - fdoi) * 100
                if och >= 5 and abs(pch) >= 1.5:
                    add(s, 1 if pch > 0 else -1, "money", "%s %s: price %+.1f%%, futures OI %+.0f%%" % ("long build-up" if pch > 0 else "short build-up", dd[5:], pch, och))
        c.close()
    except Exception:
        pass
    return C


# ---------- the pre-open ----------
def preopen(kite, syms):
    """-> {sym: {"open", "pc", "gap", "bq", "sq"}} from one Kite quote (500 at a time)"""
    out = {}
    syms = list(syms)
    for i in range(0, len(syms), 450):
        q = kite.quote(["NSE:" + s for s in syms[i:i + 450]]) or {}
        for k, v in q.items():
            s = k.split(":", 1)[1]
            o = v.get("ohlc") or {}
            op = float(o.get("open") or 0) or float(v.get("last_price") or 0)
            pc = float(o.get("close") or 0)
            if op > 0 and pc > 0 and abs(op / pc - 1) < 0.2:
                out[s] = {"open": op, "pc": pc, "gap": (op / pc - 1) * 100, "bq": float(v.get("buy_quantity") or 0), "sq": float(v.get("sell_quantity") or 0),
                          "vol": float(v.get("volume") or 0)}
    return out


def strike_for(s, d, px):
    try:
        c = _ro("chains.db")
        tabs = set(r[0] for r in c.execute("select name from sqlite_master where type='table'"))
        tb = "chain15" if "chain15" in tabs else "chain"
        dd = c.execute("select max(d) from %s where sym=?" % tb, (s,)).fetchone()[0]
        rows = c.execute("select exp, strike, oi from %s where d=? and sym=? and kind=? and t=(select max(t) from %s where d=? and sym=?)" % (tb, tb), (dd, s, "CE" if d > 0 else "PE", dd, s)).fetchall() if dd else []
        c.close()
    except Exception:
        return None
    if not rows:
        return None
    exp = sorted({r[0] for r in rows})[0]
    ks = sorted({r[1] for r in rows if r[0] == exp})
    beyond = [k for k in ks if (k >= px if d > 0 else k <= px)]
    k = (beyond[0] if d > 0 else beyond[-1]) if beyond else min(ks, key=lambda x: abs(x - px))
    if abs(k - px) / px > 0.02:
        k = min(ks, key=lambda x: abs(x - px))
    far = [(oi, kk) for e, kk, oi in rows if e == exp and (kk > px if d > 0 else kk < px) and abs(kk / px - 1) <= 0.06]
    wall = max(far)[1] if far else None
    return {"k": k, "exp": exp, "wall": wall}


def call(s, c, p, lot=None, now=None):
    """-> (grade, side, lines, stop)"""
    now = now or dt.datetime.now(IST)
    d = c["d"] or (1 if p["gap"] >= GAP_MIN else -1 if p["gap"] <= -GAP_MIN else 0)
    if not d:
        return "WAIT", 0, ["%s · %s · no real gap (%+.1f%%) - ⚡ ENTER NOW judges it after 09:20" % (s, " · ".join(c["why"][:2]), p["gap"])], None
    gd = p["gap"] * d
    bk = (p["bq"] / p["sq"] if d > 0 else p["sq"] / p["bq"]) if (p["bq"] > 0 and p["sq"] > 0) else None
    sd = "CE" if d > 0 else "PE"
    why = " · ".join(c["why"][:3])
    if c.get("conflict"):
        return "WAIT", d, ["%s · reasons on both sides (%s) - no call" % (s, why)], None
    if gd < 0:
        return "NO", d, ["%s %s · %s · but it opens %+.1f%% against it - no" % ("▲" if d > 0 else "▼", s, why, p["gap"])], None
    if gd > GAP_MAX:
        return "WAIT", d, ["%s %s · %s · opened %+.1f%% - late; the entry is a dip back to ₹%s, not the open" % ("▲" if d > 0 else "▼", s, why, p["gap"], _p(p["pc"] * (1 + d * 0.02)))], None
    if gd < GAP_MIN:
        return "WAIT", d, ["%s %s · %s · opens flat (%+.1f%%) - ⚡ ENTER NOW judges it after 09:20" % ("▲" if d > 0 else "▼", s, why, p["gap"])], None
    if bk is not None and bk < BOOK_MIN:
        return "WAIT", d, ["%s %s · %s · gap %+.1f%% but the book is not with it (%s %.1fx) - wait for 09:20" % ("▲" if d > 0 else "▼", s, why, p["gap"], "buyers" if d > 0 else "sellers", bk)], None
    op, pc = p["open"], p["pc"]
    stop = max(pc, op * 0.99) if d > 0 else min(pc, op * 1.01)
    st = strike_for(s, d, op)
    L = ["🌅 OPENING CALL %s %s %s · GO · pre-open %+.1f%% (₹%s) · %s · %s" % ("▲" if d > 0 else "▼", s, sd, p["gap"], _p(op),
         ("%s %.1fx %s" % ("buyers" if d > 0 else "sellers", bk, "sellers" if d > 0 else "buyers")) if bk else "the book not read", now.strftime("%H:%M"))]
    L.append("why: " + why)
    if st:
        L.append("trade: %s %g (%s) - the premium at 09:15%s%s" % (sd, st["k"], str(st["exp"])[5:], (" · 1 lot %s" % lot) if lot else "",
                                                                   (" · target ₹%s (the %s wall)" % (_p(st["wall"]), "call" if d > 0 else "put")) if st.get("wall") else ""))
    r = c.get("res")
    half = r is not None and r <= 1
    L.append("stop: %s %s ₹%s (%s) · out by %s%s" % (s, "below" if d > 0 else "above", _p(stop), "yesterday's close - the gap filled" if stop == pc else "1% from the open",
                                                    "14:30" if r == 0 else "15:15", " · results %s: a run-up trade - HALF size" % ("TODAY" if r == 0 else "tomorrow") if half else ""))
    return "GO", d, L, round(stop, 2)


def run(kite, now=None, send=None):
    now = now or dt.datetime.now(IST)
    fo = fo_list()
    C = candidates(now, fo)
    P = preopen(kite, list(fo) if fo else list(C))
    if not P or not any(v["vol"] > 0 for v in P.values()):
        return {"go": [], "note": "no pre-open trading (a holiday, or before 09:08) - nothing sent"}
    go, rest = [], []
    for s, c in C.items():
        if s not in P:
            continue
        g, d, L, stop = call(s, c, P[s], fo.get(s), now)
        if g == "GO":
            go.append({"s": s, "d": d, "open": P[s]["open"], "pc": P[s]["pc"], "stop": stop, "text": "\n".join(L)})
        else:
            rest.append((g, L[0]))
    known = set(C)
    odd = sorted([(abs(v["gap"]), s, v["gap"]) for s, v in P.items() if s not in known and abs(v["gap"]) >= 2], reverse=True)[:6]
    S = ["📋 OPENING CALL · the rest %s · %d with a reason · %d GO (rang in Box Picks)" % (now.strftime("%H:%M"), len(C), len(go))]
    for g in ("WAIT", "NO"):
        for gg, l in rest:
            if gg == g:
                S.append("%s %s" % (g, l))
    if odd:
        S.append("big gaps with no reason GIR knows (a look, not a call): " + " · ".join("%s %+.1f%%" % (s, gp) for a, s, gp in odd))
    try:
        nf = (kite.quote(["NSE:NIFTY 50"]) or {}).get("NSE:NIFTY 50") or {}
        o = nf.get("ohlc") or {}
        if nf.get("last_price") and o.get("close"):
            S.append("NIFTY pre-open %+.2f%% (₹%s)" % ((nf["last_price"] / o["close"] - 1) * 100, _p(nf["last_price"])))
    except Exception:
        pass
    res = {"day": str(now.date()), "t": now.strftime("%H:%M"), "go": go, "rest": rest, "summary": "\n".join(S)}
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    json.dump(res, open(FILE, "w"), default=str)
    if send:
        for x in go:
            send(x["text"])
        send(res["summary"])
    return res


def check(kite, now=None, send=None):
    """09:20 / 09:35: each GO holding or failed"""
    now = now or dt.datetime.now(IST)
    try:
        J = json.load(open(FILE))
    except Exception:
        return []
    if J.get("day") != str(now.date()) or not J.get("go"):
        return []
    q = kite.quote(["NSE:" + x["s"] for x in J["go"]]) or {}
    out = []
    for x in J["go"]:
        if x.get("failed"):
            continue
        v = q.get("NSE:" + x["s"]) or {}
        px = float(v.get("last_price") or 0)
        if not px:
            continue
        d = x["d"]
        sd = "CE" if d > 0 else "PE"
        if (px - x["stop"]) * d < 0:
            x["failed"] = now.strftime("%H:%M")
            out.append("❌ OPENING CALL FAILED %s %s %s · ₹%s %s the stop ₹%s · %s - out (it opened ₹%s)" % (
                "▼" if d > 0 else "▲", x["s"], sd, _p(px), "below" if d > 0 else "above", _p(x["stop"]), now.strftime("%H:%M"), _p(x["open"])))
        else:
            out.append("✅ OPENING CALL HOLDING %s %s · ₹%s (opened ₹%s, stop ₹%s) · %s" % (x["s"], sd, _p(px), _p(x["open"]), _p(x["stop"]), now.strftime("%H:%M")))
    json.dump(J, open(FILE, "w"), default=str)
    if send:
        bad = [x for x in out if x.startswith("❌")]
        for x in bad:
            send(x)
        ok = [x for x in out if x.startswith("✅")]
        if ok:
            send("📋 OPENING CALL CHECK %s\n" % now.strftime("%H:%M") + "\n".join(ok))
    return out


# ---------- sending (as the engine does: the lane, the ring, the NOW list) ----------
def send_tg(text):
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
    silent = False
    try:
        import alertword, tglanes
        chat = tglanes.chat_for(text, box)
        text, silent = alertword.dress(text)
    except Exception:
        chat = box
    log_alert(text)
    if not tok or not chat:
        print("no Telegram token / chat:\n" + text); return False
    import requests
    a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
    d = {"chat_id": a, "text": text, "disable_notification": "true" if silent else "false"}
    if b:
        d["message_thread_id"] = b
    for _ in range(3):
        try:
            r = requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=30)
            if r.ok:
                return True
            time.sleep(3)
        except Exception as ex:
            print("telegram: %s" % str(ex)[:80]); time.sleep(3)
    return False


def log_alert(text):
    """the page's NOW list and ⚡ ENTER NOW read tomorrow.db alerts"""
    try:
        first = text.split("\n")[0]
        m = re.search(r"[▲▼]\s*([A-Z][A-Z0-9&-]{1,})\b", first)
        side = "CE" if re.search(r"\bCE\b", first) else "PE" if re.search(r"\bPE\b", first) else ""
        now = dt.datetime.now(IST)
        c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
        c.execute("create table if not exists alerts(day text, t text, kind text, sym text, side text, text text)")
        c.execute("insert into alerts(day,t,kind,sym,side,text) values(?,?,?,?,?,?)", (str(now.date()), now.strftime("%H:%M:%S"), first.split()[0], m.group(1) if m else "MARKET", side, text[:1500]))
        c.commit(); c.close()
    except Exception as ex:
        print("alert log: %s" % ex)


def _kite():
    import core
    end = time.time() + 150
    while True:
        try:
            return core.get_kite()
        except Exception as ex:
            if time.time() > end:
                raise
            print("kite not ready: %s" % str(ex)[:80]); time.sleep(15)


if __name__ == "__main__":
    now = dt.datetime.now(IST)
    if now.weekday() > 4 and "--force" not in sys.argv:
        print("weekend"); sys.exit(0)
    k = _kite()
    snd = send_tg if "--send" in sys.argv else None
    if "--check" in sys.argv:
        for x in check(k, now, snd):
            print(x)
    else:
        r = run(k, now, snd)
        for x in r.get("go") or []:
            print(x["text"] + "\n")
        print(r.get("summary") or r.get("note"))
PY_OC
cat > $D/p143test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p143test.py - patch 143: 🌅 OPENING CALL on a made-up morning (a temporary folder, a fake Kite - nothing live touched):
  COCHINSHIP results TODAY, opens +1.6% with buyers 2x -> GO CE, HALF size, out by 14:30 · EICHERMOT results in 4 days, +0.8%,
  buyers 1.5x -> GO · VOLTAS news ▼ but opens +1.0% -> NO · IREDA news ▲ but opens +5.2% -> WAIT (late) · PNB news ▲ flat -> WAIT
  TITAN news ▲ +0.9% but sellers 2x -> WAIT · a holiday (no pre-open trades) -> nothing · 09:20: COCHINSHIP back under the stop
  -> ❌ FAILED, EICHERMOT holding -> ✅ · the GO is a ringing ⚡ ENTER NOW signal · the routing"""
import os, sys, json, sqlite3, tempfile, shutil, datetime as dt
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import opencall as O
ok = True
def check(n, g):
    global ok
    print(("OK   " if g else "FAIL ") + n); ok = ok and bool(g)
T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
O.BASE, O.FILE = T, os.path.join(T, "data", "opencall.json")
IST = O.IST
now = dt.datetime(2026, 11, 10, 9, 12, tzinfo=IST)
c = sqlite3.connect(os.path.join(T, "chains.db"))
c.execute("create table fo_list(sym text, lot int)"); c.executemany("insert into fo_list values(?,?)", [(s, 100) for s in ("COCHINSHIP", "EICHERMOT", "VOLTAS", "IREDA", "PNB", "TITAN", "ODDGAP")])
c.execute("create table results_cal(sym text, d text)"); c.executemany("insert into results_cal values(?,?)", [("COCHINSHIP", "2026-11-10"), ("EICHERMOT", "2026-11-14")])
c.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
c.executemany("insert into chain15 values(?,?,?,?,?,?,?,?,?)", [("2026-11-09", "15:15", "COCHINSHIP", "2026-11-23", k, "CE", oi, 20, 1240) for k, oi in ((1240, 5e5), (1260, 9e5), (1280, 4e5))])
c.commit(); c.close()
c = sqlite3.connect(os.path.join(T, "tomorrow.db"))
c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
c.executemany("insert into alerts values(?,?,?,?,?,?)", [("2026-11-09", "18:10:00", "📄", "VOLTAS", "PE", "📄 NEWS ▼ VOLTAS · RATING · x"), ("2026-11-10", "08:40:00", "📄", "IREDA", "CE", "📄 NEWS ▲ IREDA · OTHER · y"),
    ("2026-11-10", "08:41:00", "📄", "PNB", "CE", "📄 NEWS ▲ PNB · OTHER · z"), ("2026-11-10", "08:42:00", "📄", "TITAN", "CE", "📄 NEWS ▲ TITAN · OTHER · w")])
c.commit(); c.close()
Q = {"COCHINSHIP": (1260.0, 1240.0, 2e5, 1e5), "EICHERMOT": (7560.0, 7500.0, 3e4, 2e4), "VOLTAS": (1040.0, 1029.7, 1e4, 1e4), "IREDA": (120.0, 114.0, 1e6, 5e5),
     "PNB": (132.1, 132.0, 1e6, 1e6), "TITAN": (5050.0, 5005.0, 1e4, 2e4), "ODDGAP": (103.0, 100.0, 1, 1)}
class K:
    vol = 1000
    px = {}
    def quote(self, keys):
        out = {}
        for k in keys:
            s = k.split(":", 1)[1]
            if s == "NIFTY 50":
                out[k] = {"last_price": 25100.0, "ohlc": {"close": 25044.65}}; continue
            if s in Q:
                op, pc, bq, sq = Q[s]
                out[k] = {"last_price": self.px.get(s, op), "ohlc": {"open": op, "close": pc}, "buy_quantity": bq, "sell_quantity": sq, "volume": K.vol}
        return out
import types
sys.modules["dashserve"] = types.SimpleNamespace(_stale_news=lambda h, x: "ALREADY KNOWN" in (x or ""))   # the freshness check is tested in p138
SENT = []
r = O.run(K(), now, SENT.append)
G = {x["s"]: x for x in r["go"]}
print(G.get("COCHINSHIP", {}).get("text", "no COCHINSHIP")); print(); print(r["summary"]); print()
check("COCHINSHIP: results TODAY + gap +1.6% + buyers 2x -> GO CE", "COCHINSHIP" in G and "🌅 OPENING CALL ▲ COCHINSHIP CE · GO" in G["COCHINSHIP"]["text"])
check("COCHINSHIP: HALF size, out by 14:30, the strike CE 1260, the stop", all(x in G["COCHINSHIP"]["text"] for x in ("HALF size", "out by 14:30", "CE 1260", "stop: COCHINSHIP below")))
check("EICHERMOT: results in 4 days, +0.8%, buyers 1.5x -> GO", "EICHERMOT" in G)
check("VOLTAS: news ▼ but opens up -> NO", any(g == "NO" and "VOLTAS" in l for g, l in r["rest"]))
check("IREDA: +5.3% - late -> WAIT", any(g == "WAIT" and "IREDA" in l and "late" in l for g, l in r["rest"]))
check("PNB flat -> WAIT", any(g == "WAIT" and "PNB" in l for g, l in r["rest"]))
check("TITAN: sellers 2x -> WAIT", any(g == "WAIT" and "TITAN" in l and "book" in l for g, l in r["rest"]))
check("ODDGAP +3% with no reason: listed as a look, not a call", "ODDGAP +3.0%" in r["summary"] and "ODDGAP" not in G)
check("sent: the 2 GO lines + 1 summary", len(SENT) == 3)
K.vol = 0
check("a holiday (no pre-open trades): nothing", O.run(K(), now, SENT.append)["go"] == [] and len(SENT) == 3)
K.vol = 1000
O.run(K(), now, None)
K.px = {"COCHINSHIP": 1236.0}
out = O.check(K(), now.replace(minute=20), SENT.append)
print("\n".join(out)); print()
check("09:20: COCHINSHIP back under yesterday's close -> ❌ OPENING CALL FAILED", any(x.startswith("❌ OPENING CALL FAILED ▼ COCHINSHIP CE") for x in out))
check("09:20: EICHERMOT holding -> ✅", any(x.startswith("✅ OPENING CALL HOLDING EICHERMOT") for x in out))
check("a failed call is said once", not any("COCHINSHIP" in x for x in O.check(K(), now.replace(minute=35), None)))
import alertword, tglanes
g, f, sm = G["COCHINSHIP"]["text"], [x for x in out if x.startswith("❌")][0], r["summary"]
check("GO and FAILED ring (act) in Box Picks", alertword.tier(g) == "act" and tglanes.lane(g) == "critical" and alertword.tier(f) == "act" and tglanes.lane(f) == "critical")
check("the summary is quiet, in ⚙️ System", alertword.tier(sm) == "read" and tglanes.topic(sm) == "system")
import enternow as E
D = E.Data("2026-11-10")
D.by_sym = {"COCHINSHIP": [(552, "🌅", "COCHINSHIP", "CE", g.split("\n")[0], g)]}
tr = E.triggers(D, "COCHINSHIP", 570, {})
check("⚡ ENTER NOW reads the GO as a ringing signal until 10:00 (%s)" % tr, tr and tr[0][0] == "open-call" and "open-call" in E.live_kinds() and E.live_kinds()["open-call"] == 600)
src = open(os.path.join(HERE, "home.html"), encoding="utf-8").read()
check("the page: the call and FAILED are ACT chips", "OPENING CALL FAILED/.test(H)) return \"act\"" in src)
shutil.rmtree(T)
print("P143 OPENING CALL TEST " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p143_patch.py $D || { rm -f $D/opencall.py $D/p143test.py; echo "nothing was changed"; exit 1; }
cd $D && python3 -m py_compile opencall.py enternow.py alertword.py tglanes.py p143test.py || back
for t in p143test.py p142test.py p140test.py p139test.py p137test.py p136test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; python3 $t 2>&1 | grep -E "FAIL|Error" | head -5; back; }; }; done
cat > $U/gir-opencall.service <<'UNIT'
[Unit]
Description=GIR opening call (09:12 on trading days)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 opencall.py --send >> data/opencall.log 2>&1'
UNIT
cat > $U/gir-opencall.timer <<'UNIT'
[Unit]
Description=GIR opening call 09:12
[Timer]
OnCalendar=Mon..Fri *-*-* 09:12:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
cat > $U/gir-opencall-check.service <<'UNIT'
[Unit]
Description=GIR opening call check (09:20 / 09:35)
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && source .env && set +a && cd /home/globalbot/intraday && python3 opencall.py --check --send >> data/opencall.log 2>&1'
UNIT
cat > $U/gir-opencall-check.timer <<'UNIT'
[Unit]
Description=GIR opening call check 09:20 / 09:35
[Timer]
OnCalendar=Mon..Fri *-*-* 09:20:00 Asia/Kolkata
OnCalendar=Mon..Fri *-*-* 09:35:00 Asia/Kolkata
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-opencall.timer gir-opencall-check.timer || back
systemctl restart gir-dash gir-intraday && sleep 15
for s in gir-dash gir-intraday; do [ "$(systemctl is-active $s)" = "active" ] || { echo "$s did not come back"; back; }; done
echo "    next runs: $(systemctl list-timers gir-opencall.timer gir-opencall-check.timer --no-pager 2>/dev/null | grep -c gir-opencall) timers set"
echo "    the reasons GIR holds so far for the next open:"
python3 -c "
import opencall, datetime as dt
C = opencall.candidates(dt.datetime.now(opencall.IST) + dt.timedelta(hours=12), opencall.fo_list())
for s, c in sorted(C.items()):
    print('      %-11s %s' % (s, ' · '.join(c['why'][:2])[:110]))
print('      (%d shares - news coming in tonight and before 09:12 joins them)' % len(C))
" 2>&1 | head -25
echo
echo "PATCH 143 APPLIED. Tomorrow 09:12: 🌅 OPENING CALL in Box Picks (GO only), the rest in ⚙️ System; 09:20 / 09:35 the check."
