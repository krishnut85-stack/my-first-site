#!/bin/bash
# PATCH 353 - ONE CLEAR TRADE ALERT, ENTRY AND EXIT (Rama, 16 Nov: "the alert and the notification are not correct - late for entry and exit").
#   The alerts table had 2,548 lines today and 2,190 of them carried CE/PE - even "OPENING - WATCH, not a trade yet" and "IN DOUBT".
#   · every tested trade (👀 scanner, 🔻🔺 sector alert) now rings as ONE card, the same shape every time:
#       🟢 BUY CE / 🔴 BUY PE · SHARE · time
#       ENTRY ₹ (buy only up to ₹ - 0.5% further) · STOP ₹ → EXIT ALL · HALF ₹ → book half, stop to entry · REST out at 15:10 · why · tested
#     a sector alert gives one card per share, each with its own prices
#   · the exits: ✅ BOOK HALF / ❌ EXIT ALL / ⏹ EXIT ALL 15:10 / 📈 HOLD - checked every 15 SECONDS from the live price (quotes_live.json),
#     not every 5 minutes; the 5-min bar only if the live price is older than 60 s
#   · missed.py: "WATCH, not a trade yet" / "IN DOUBT" / WHY / news lines no longer count as a CE/PE call
#   Page first, Telegram (GIR Bigmovers) 8 s later - as before. Nothing muted. Replaces headsup.py, missed.py. Restarts gir-headsup only.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
grep -q "patch 352" $D/headsup.py 2>/dev/null || { echo "patch 352 first"; exit 1; }
cat > $W/headsup.py <<'PY_headsup'
#!/usr/bin/env python3
"""headsup.py - patch 351 + 352 + 353 (353: every trade alert = one clear 🟢 BUY CE / 🔴 BUY PE card with the entry, the stop, the half-out and the exit; the exits are checked every 15 seconds from the live price, not every 5 minutes. the sector alerts use the settings the replay chose - data/headsup_cfg.json): 👀 HEADS-UP + 🔻🔺 SECTOR ALERTS, LIVE (Rama, 16 Nov: "let me know BEFORE the move - a clear alert and a clear
monitoring system; the shares of a falling sector never got an alert"). Every 5 minutes, 09:20-14:30 on a trading day, the SAME logic that was
replayed on 25 days (movescan.py: +₹6,472 a day at a 2.5% stop, 18 of 25 days green, before charges):
  👀 HEADS-UP   the scanner's new top shares (volume 1.5x+ its normal, the move still running, its sector the same way) - CE or PE, the stop
                (2.5% on the share), half out at +1.5%
  🔻🔺 SECTOR   a whole sector 0.6%+ one way with 70%+ of its shares -> its 3 weakest (PE) / strongest (CE)
  MONITORING    every alerted share is followed: "+1% more" (rings), "half out at +1.5%" (rings), "stop hit - OUT" (rings), 15:10 "close it"
  a share rings again only when something is NEW (another 1%, the target, the stop, a sector going 0.5% deeper) - never repeats
Sends to GIR Bigmovers on Telegram (with sound) and onto GIR's page (windwatch.send_big); the page's 👀 box reads data/headsup.json.
Reads this server's own page feeds; orders nothing.   python3 headsup.py once   (one pass now, prints, sends nothing)"""
import os, sys, json, time, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import movescan as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "headsup.json")
TH, STOP, HALF, MORE = 4, 0.025, 0.015, 0.01
CHASE = 0.005             # patch 353: "buy up to" = the alert price + 0.5% the trade's way; further than that the stop is too far - skip it
WATCH_S = 15              # patch 353: the exits (stop, half out, 15:10) are checked this often from quotes_live.json


def live_px():
    """patch 353: every share's last price from the engine's quotes_live.json (written once a second) - {} when older than 60 s"""
    try:
        j = json.load(open(os.path.join(D, "quotes_live.json")))
        if time.time() - float(j.get("t") or 0) > 60:
            return {}
        return {s: float(v[0]) for s, v in (j.get("q") or {}).items() if v and v[0]}
    except Exception:
        return {}


def card(s, dr, px, stop, half, hm, why, tested):
    """patch 353: THE trade alert - the same shape every time, so it cannot be mistaken for an info line"""
    ce = dr > 0; f = lambda x: "{:,.2f}".format(x)
    return ("%s BUY %s · %s · %s\n"
            "ENTRY  ₹%s  (buy only up to ₹%s)\n"
            "STOP   ₹%s  (the share %s %.1f%%) → EXIT ALL\n"
            "HALF   ₹%s  (the share %s %.1f%%) → book half, stop to entry\n"
            "REST   out at 15:10\n"
            "why: %s\n"
            "%s") % ("🟢" if ce else "🔴", "CE" if ce else "PE", s, hm, f(px), f(px * (1 + dr * CHASE)), f(stop), "down" if ce else "up", abs(stop / px - 1) * 100,
                     f(half), "up" if ce else "down", abs(half / px - 1) * 100, why, tested)


def now():
    return dt.datetime.now(IST)


def session(n):
    if n.weekday() > 4:
        return False
    try:
        import sessions
        if not sessions.session(n.date()):
            return False
    except Exception:
        pass
    return True


PAGE_FIRST_S = 8          # the page shows it first; Telegram rings 8 seconds later (Rama: "on the GIR page first, then Telegram")


def page_log(text):
    try:
        import opencall
        opencall.log_alert(text)
    except Exception:
        pass


def telegram(text):
    """GIR Bigmovers with sound - the page was written before (no second page line)"""
    try:
        import windwatch
        e = windwatch.env()
        chat, tok = e.get("TG_CHAT_BIGMOVERS"), e.get("TELEGRAM_TOKEN") or e.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_TOKEN")
        if not (chat and tok):
            return False
        import requests
        a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
        d = {"chat_id": a, "text": text[:4000], "disable_web_page_preview": "true"}
        if b and b.isdigit():
            d["message_thread_id"] = b
        return requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=15).ok
    except Exception as ex:
        print("telegram: %s" % ex, flush=True); return False


def send(text, quiet=False):
    """kept for one-off use: page, then Telegram"""
    if quiet:
        print(text, flush=True); return True
    page_log(text); time.sleep(PAGE_FIRST_S); return telegram(text)


class Live:
    def __init__(self):
        self.day = None; self.past = {}; self.SECS = []; self.SEC = {}; self.W = {}; self.tok = ""
        self.sent = {}; self.sec_sent = set(); self.mon = {}

    def secv(self):
        """patch 352: the sector-alert settings the 25-day replay chose (data/headsup_cfg.json, written by movescan.py)"""
        try:
            v = json.load(open(os.path.join(D, "data", "headsup_cfg.json")))["sec"]
            return {"th": float(v["th"]), "picks": int(v["picks"]), "top_only": bool(v["top_only"])}
        except Exception:
            return {"th": 0.01, "picks": 2, "top_only": True}             # the careful default until the replay has chosen

    def exitv(self):
        """patch 352b: the stop and half-out the replay chose TOGETHER with the entry (the same headsup_cfg.json)"""
        try:
            x = json.load(open(os.path.join(D, "data", "headsup_cfg.json")))["exit"]
            return float(x["stop"]), float(x["half"])
        except Exception:
            return STOP, HALF

    def setup(self, day):
        import dashserve, glob
        self.tok = str(getattr(dashserve, "TOKEN", "") or "")
        H = M.get("/home", self.tok); self.SECS = H.get("sectors") or []
        self.SEC = {s: x["syms"] for x in self.SECS for s in (x.get("syms") or [])}
        for f in reversed(sorted(glob.glob(os.path.join(D, "data", "nsefutx_*.json")))):
            try:
                N = json.load(open(f))
                if N:
                    self.W = {s: sum((r[2] or 0) * (r[1] or 0) for r in R) for s, R in N.items()}; break
            except Exception:
                pass
        self.past = {}
        for s in list(self.SEC) + ["NIFTY50"]:
            try:
                b = M.get("/hist?sym=%s&days=15" % s, self.tok)
                self.past[s] = {k: v for k, v in M.days_of(b).items() if k < day}
            except Exception:
                pass
        self.day = day; self.sent = {}; self.sec_sent = set(); self.mon = {}
        self.load()

    def load(self):
        try:
            j = json.load(open(OUT))
            if j.get("day") == self.day:
                self.mon = {k: v for k, v in (j.get("mon") or {}).items()}
                self.sent = {k: True for k in self.mon}; self.sec_sent = set(tuple(x) for x in j.get("sec_sent") or [])
        except Exception:
            pass

    def bars(self):
        P, NIF = {}, {}
        for s in list(self.SEC) + ["NIFTY50"]:
            try:
                b = M.get("/hist?sym=%s&days=2" % s, self.tok); B = dict(self.past.get(s) or {}); B.update({k: v for k, v in M.days_of(b).items() if k == self.day})
            except Exception:
                B = dict(self.past.get(s) or {})
            if s == "NIFTY50":
                for d, x in M.prep(B).items():
                    NIF[d] = {r["hm"]: r["rp"] for r in x["rows"]}
            else:
                P[s] = M.prep(B)
        return P, NIF

    def step(self, n, quiet=False):
        P, NIF = self.bars(); d = self.day; hm = n.strftime("%H:%M"); out = []
        fl = M.scan(P, self.SEC, self.W, NIF, TH).get(d) or []
        for f in fl:
            k = f["s"]
            if k in self.sent:
                continue
            self.sent[k] = True
            px, dr = f["px"], f["dir"]; stop = px * (1 - dr * STOP); half = px * (1 + dr * HALF)
            if f["hm"] < (n - dt.timedelta(minutes=12)).strftime("%H:%M"):          # an old one (GIR was restarted) - followed, not rung as new
                self.mon[k] = {"s": f["s"], "dir": dr, "t": f["hm"], "px": px, "stop": stop, "half": half, "step": 1, "st": "open", "kind": "👀", "late": True}
                continue
            secn = next((g["name"] for g in self.SECS if f["s"] in (g.get("syms") or [])), "")
            rp = next((r["rp"] for r in P[k][d]["rows"] if r["hm"] == f["hm"]), 0.0) if k in P and d in P[k] else 0.0
            txt = card(f["s"], dr, px, stop, half, f["hm"], "%s %+.1f%% (%d%% of its shares the same way) · the share %+.1f%% · volume %.1fx its normal" % (
                (secn or "its sector").upper(), f["sec"] * 100, round(f["same"] * 100), rp * 100, f["volx"]), "👀 scanner - tested on 25 days with this stop")
            out.append(txt)
            self.mon[k] = {"s": f["s"], "dir": dr, "t": f["hm"], "px": px, "stop": stop, "half": half, "step": 1, "st": "open", "kind": "👀"}
        sst, shf = self.exitv()
        for a in M.sector_alerts(P, self.SECS, self.W, d, upto=hm, **self.secv()):
            k = (a["name"], a["dir"], round(abs(a["mv"]) * 200))
            if k in self.sec_sent:
                continue
            first = not any(x[0] == a["name"] and x[1] == a["dir"] for x in self.sec_sent)
            self.sec_sent.add(k)
            if a["hm"] < (n - dt.timedelta(minutes=12)).strftime("%H:%M"):
                continue                                                       # an old one (a restart) - not rung again
            head = "%s SECTOR %s · %s %+.1f%% · %d of %d shares %s · %s" % (
                "🔻" if a["dir"] < 0 else "🔺", "FALLING" if a["dir"] < 0 else "RISING", a["name"].upper(), a["mv"] * 100, round(a["same"] * a["n"]), a["n"],
                "down" if a["dir"] < 0 else "up", a["hm"])
            if not first:
                out.append(head + "\nstill going - HOLD the trades you have, no new entry"); continue
            for p in a["picks"]:
                if p["s"] in self.mon:
                    continue
                dr = a["dir"]; px = p["px"]
                out.append(card(p["s"], dr, px, px * (1 - dr * sst), px * (1 + dr * shf), a["hm"], head + " · the share %+.1f%%" % (p["rp"] * 100),
                                "🔻🔺 sector alert - tested: %s" % self.tested()))
            if first:
                for p in a["picks"]:
                    if p["s"] not in self.mon:
                        dr = a["dir"]; px = p["px"]
                        self.mon[p["s"]] = {"s": p["s"], "dir": dr, "t": a["hm"], "px": px, "stop": px * (1 - dr * sst), "half": px * (1 + dr * shf), "hf": shf, "step": 1, "st": "open", "kind": "🔻" if dr < 0 else "🔺"}
                        self.sent[p["s"]] = True
        out += self.watch(n, P)
        self.lastP = P; self.secs_now = [{"hm": a["hm"], "name": a["name"], "dir": a["dir"], "mv": round(a["mv"] * 100, 2), "same": round(a["same"] * 100)} for a in M.sector_alerts(P, self.SECS, self.W, d, upto=hm, **self.secv())][-12:]
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        self.save(n)
        return self.emit(out, quiet)

    def save(self, n):
        json.dump({"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": self.day, "mon": self.mon, "sec_sent": [list(x) for x in self.sec_sent],
                   "sectors": getattr(self, "secs_now", [])}, open(OUT + ".tmp", "w")); os.replace(OUT + ".tmp", OUT)

    def emit(self, out, quiet=False):
        if quiet:
            for m in out:
                print(m, flush=True)
            return out
        for m in out:                                                          # 1) the page: GIR's alert list (+ the 👀 box from headsup.json, already written)
            page_log(m)
        if out:
            time.sleep(PAGE_FIRST_S)                                           # 2) then the phone
            for m in out:
                telegram(m)
        return out

    def tested(self):
        try:
            j = json.load(open(os.path.join(D, "data", "headsup_cfg.json"))); return "%d of %d days green" % (j["green"], j["days"])
        except Exception:
            return "the careful default settings"

    def watch(self, n, P=None):
        """patch 353: MONITORING every alerted share to its end - the live price (quotes_live.json, every 15 s), the last 5-min bar if that is stale"""
        hm = n.strftime("%H:%M"); d = self.day; out = []; Q = live_px(); P = P or getattr(self, "lastP", {}) or {}
        for k, m in self.mon.items():
            if m["st"] in ("out", "closed"):
                continue
            px = Q.get(k)
            if not px:
                if k not in P or d not in P[k]:
                    continue
                px = P[k][d]["rows"][-1]["c"]
            dr = m["dir"]; mv = (px / m["px"] - 1) * dr; m["now"] = px; m["mv"] = round(mv * 100, 2); c = "CE" if dr > 0 else "PE"; f = lambda x: "{:,.2f}".format(x)
            msg = None
            if (px - m["stop"]) * dr <= 0:
                m["st"] = "out"
                msg = ("❌ EXIT ALL · %s %s · ₹%s\nthe stop ₹%s was hit%s" % (k, c, f(px), f(m["stop"]), " - half was booked before, the rest out at your entry, no loss" if m.get("halfd") else " - the move failed, take the small loss"))
            elif not m.get("halfd") and mv >= m.get("hf", HALF):
                m["halfd"] = True; m["stop"] = m["px"]; m["st"] = "half"
                msg = "✅ BOOK HALF · %s %s · ₹%s (+%.1f%%)\nsell half now · the stop on the rest moves to your entry ₹%s" % (k, c, f(px), mv * 100, f(m["px"]))
            elif hm >= "15:10":
                m["st"] = "closed"; msg = "⏹ EXIT ALL 15:10 · %s %s · ₹%s · %+.1f%% from the entry at %s - not held overnight" % (k, c, f(px), mv * 100, m["t"])
            elif mv >= MORE * (m["step"] + 1):
                m["step"] = int(mv / MORE)
                msg = "📈 HOLD · %s %s · ₹%s · %+.1f%% from the entry at %s · stop ₹%s" % (k, c, f(px), mv * 100, m["t"], f(m["stop"]))
            if msg:
                out.append(msg)
        return out


def main():
    L = Live()
    if sys.argv[1:2] == ["once"]:
        n = now(); L.setup(str(n.date())); out = L.step(n, quiet=True)
        print("headsup once %s: %d messages · %d shares followed" % (n.strftime("%H:%M"), len(out), len(L.mon))); return
    while True:
        n = now(); hm = n.strftime("%H:%M")
        if not session(n) or hm < "09:20" or hm > "15:15":
            time.sleep(60); continue
        try:
            if L.day != str(n.date()):
                L.setup(str(n.date()))
            if n.minute % 5 == 0 and n.second >= 20 and L.__dict__.get("last") != hm:
                L.last = hm; L.step(n)
            elif time.time() - L.__dict__.get("wlast", 0) >= WATCH_S and L.mon:  # patch 353: the exits between the 5-minute scans
                L.wlast = time.time(); o = L.watch(n)
                if o:
                    L.save(n); L.emit(o)
        except Exception as ex:
            print("headsup: %s" % str(ex)[:120], flush=True); time.sleep(30)
        time.sleep(5)


if __name__ == "__main__":
    main()
PY_headsup
cat > $W/missed.py <<'PY_missed'
#!/usr/bin/env python3
"""missed.py - READ ONLY (v352/353: a real CE/PE call apart from a news / list mention or a "WATCH, not a trade yet" / "IN DOUBT" line). TODAY'S MISSED MONEY (Rama, 16 Nov: "it was a good day - I missed them. Replay the shares it alerted LATE, the ones
it NOTICED but never rang, and the ones it never noticed - if the alarm had come with the right direction, how much could I have made?").
For every F&O share that moved 2.5%+ today (from the open, either way):
  · the move: its side, size, the 5-min bar it started (0.5% its way)
  · GIR NOTICED: the first row GIR wrote about it today in ANY of its own logs (tomorrow.db: first moves, surges, book moves, the desk's calls,
    cards, turns ... + the engine's "JUDGE NO" lines) - the right side only
  · GIR RANG: its first line in the alert list (what reached the page / phone). NOTE: alerts sent while the database was locked (10:55-11:10,
    13:20-13:50) may be missing here although Telegram rang
  · the money, 1 lot, an at-the-money option ~ half the share's rupee move, stop 2.5% on the share, half out at +1.5%, the rest at 15:10, before
    charges: had it rung when GIR FIRST NOTICED · when it really rang
python3 missed.py [YYYY-MM-DD]     -> prints, saves data/missed.txt"""
import os, re, sys, json, sqlite3, subprocess, urllib.request, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
import movescan as M
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
L = []
def say(s=""):
    L.append(s); print(s)
UP = re.compile(r"^(CE|UP|BUY|LONG|1|\+1|▲|BULL)", re.I); DN = re.compile(r"^(PE|DOWN|SELL|SHORT|-1|▼|BEAR)", re.I)


NOTCALL = re.compile(r"not a trade|IN DOUBT|WATCH,|^🔍|^🔎|^📰|^📄", re.I)    # v353: GIR said it, but did not say BUY


def side_of(v):
    v = str(v if v is not None else "").strip()
    return 1 if UP.match(v) else -1 if DN.match(v) else 0


def hm5(t):
    t = str(t or "")[:5]
    return t if re.fullmatch(r"\d\d:\d\d", t) else None


def events(day):
    """{sym: [(hm, side, source)]} from every tomorrow.db table with day + t + sym, and the engine's JUDGE NO lines"""
    ev, rang = {}, {}
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        for (tb,) in c.execute("select name from sqlite_master where type='table'").fetchall():
            cols = [r[1] for r in c.execute("pragma table_info(%s)" % tb)]
            if not {"day", "t", "sym"} <= set(cols):
                continue
            sc = next((x for x in ("side", "dir", "kind") if x in cols), None)
            for t, s, sd in c.execute("select t, sym, %s from %s where day=?" % (sc or "''", tb), (day,)):
                h = hm5(t)
                if not h or not s:
                    continue
                if tb == "alerts":
                    continue                                                   # v353: read below, with its text
                else:
                    ev.setdefault(s, []).append((h, side_of(sd), tb))
        if "text" in [r[1] for r in c.execute("pragma table_info(alerts)")]:
            for t, s, sd, tx in c.execute("select t, sym, side, text from alerts where day=?", (day,)):
                h = hm5(t)
                if not h or not s:
                    continue
                tx = str(tx or "")
                if NOTCALL.search(tx):                                         # v353: "WATCH, not a trade yet" / "IN DOUBT" / a WHY line - a mention
                    ev.setdefault(s, []).append((h, side_of(sd), "said but not a trade: " + tx.split("\n")[0][:50])); rang.setdefault(s, []).append((h, 0))
                else:
                    rang.setdefault(s, []).append((h, side_of(sd)))
        c.close()
    except Exception as ex:
        say("  (tomorrow.db: %s)" % ex)
    try:
        out = subprocess.run("journalctl -u gir-intraday --since '%s 00:00' --until '%s 23:59' -o cat --no-pager 2>/dev/null | grep 'JUDGE NO'" % (day, day),
                             shell=True, capture_output=True, text=True, timeout=60).stdout
        for ln in out.splitlines():
            m = re.search(r"(\d\d:\d\d):\d\d JUDGE NO (\S+) (.*)", ln)
            if m:
                ev.setdefault(m.group(2), []).append((m.group(1), 0, "judged NO: " + m.group(3)[:60]))
    except Exception:
        pass
    return ev, rang


def at(rows, h):
    i = next((j for j, r in enumerate(rows) if r["hm"] >= h), None)
    return (i, rows[i]["c"]) if i is not None else (None, None)


def main():
    day = sys.argv[1] if len(sys.argv) > 1 else str(dt.datetime.now(IST).date())
    import dashserve
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    H = M.get("/home", tok); syms = sorted({s for x in (H.get("sectors") or []) for s in (x.get("syms") or [])})
    LOT = M.lots(); rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    P = {}
    for s in syms:
        try:
            P[s] = M.prep(M.days_of(M.get("/hist?sym=%s&days=15" % s, tok)))
        except Exception:
            pass
    mv = []
    for s in P:
        if day not in P[s]:
            continue
        rows = P[s][day]["rows"]; o0 = P[s][day]["o0"]
        up = max(r["h"] for r in rows) / o0 - 1; dn = 1 - min(r["l"] for r in rows) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size >= 0.025:
            start = next((r["hm"] for r in rows if r["ro"] * dr >= 0.005), rows[0]["hm"])
            mv.append({"s": s, "dir": dr, "size": size, "start": start})
    mv.sort(key=lambda m: -m["size"])
    ev, rang = events(day)
    say("💸 TODAY'S MISSED MONEY · %s · %d F&O shares moved 2.5%%+ · 1 lot, at-the-money option ~ half the rupee move, stop 2.5%%, half at +1.5%%, out 15:10, before charges" % (day, len(mv)))
    say("  %-11s %-6s %-6s  %-34s %-7s %-16s %10s %10s" % ("SHARE", "MOVE", "START", "GIR NOTICED FIRST (right side)", "CE/PE", "VERDICT", "₹ AT NOTICE", "₹ AS CALLED"))
    T = {"on": [0, 0, 0], "late": [0, 0, 0], "mention": [0, 0, 0], "silent": [0, 0, 0], "never": [0, 0, 0]}
    for m in mv:
        s, dr = m["s"], m["dir"]; rows = P[s][day]["rows"]
        E = sorted([e for e in ev.get(s, []) if e[1] in (dr, 0)])
        R = sorted([r for r in rang.get(s, []) if r[1] == dr])                 # v352: a real CE / PE call the right way
        MN = sorted([r for r in rang.get(s, []) if r[1] == 0])                 # a mention without a side (news, results, a list line)
        nt = E[0] if E else None; rt = R[0][0] if R else None
        for x in ([R[0]] if R else []) + ([MN[0]] if MN else []):
            if not nt or x[0] < nt[0]:
                nt = (x[0], dr, "a CE/PE call" if x in R else "a news / list mention")
        def money(h):
            if not h:
                return None
            i, px = at(rows, h)
            return rs(M.sim(rows[i + 1:], px, dr, 0.025), px, s) if i is not None else None
        mn, mr = money(nt[0] if nt else None), money(rt)
        if rt and M.mins(m["start"], rt) <= 10:
            v = "on"
        elif rt:
            v = "late"
        elif nt and MN:
            v = "mention"
        elif nt:
            v = "silent"
        else:
            v = "never"
        T[v][0] += 1; T[v][1] += mn or 0; T[v][2] += mr or 0
        say("  %-11s %s%-5s %-6s  %-34s %-7s %-16s %10s %10s" % (s, "▲" if dr > 0 else "▼", "%.1f%%" % (m["size"] * 100), m["start"],
            ("%s %s" % (nt[0], nt[2]))[:34] if nt else "—", rt or "—", {"on": "ON TIME", "late": "LATE %d min" % M.mins(m["start"], rt) if rt else "", "mention": "ONLY A MENTION", "silent": "NOTICED, NO ALARM", "never": "NEVER NOTICED"}[v],
            "{:,.0f}".format(mn) if mn is not None else "—", "{:,.0f}".format(mr) if mr is not None else "—"))
    say("")
    for k, lab in (("on", "CE/PE call on time"), ("late", "CE/PE call LATE"), ("mention", "only mentioned, no CE/PE call"), ("silent", "noticed, nothing rang"), ("never", "never noticed")):
        say("  %-26s %3d shares · had it rung at the first notice: ₹%s · as it really rang: ₹%s" % (lab, T[k][0], "{:,.0f}".format(T[k][1]), "{:,.0f}".format(T[k][2])))
    tot = sum(T[k][1] for k in T)
    say("  ALL: had GIR rung every move it noticed, at the first notice, the right side: about ₹%s (1 lot each, before charges)" % "{:,.0f}".format(tot))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "missed.txt"), "w").write("\n".join(L) + "\n")
    say("saved data/missed.txt")


if __name__ == "__main__":
    main()
PY_missed
python3 -m py_compile $W/headsup.py $W/missed.py || { echo "❌ did not compile - nothing changed"; exit 1; }
for f in headsup missed; do [ -f $D/$f.py ] && cp $D/$f.py $D/$f.py.bak353; cp $W/$f.py $D/$f.py; done
systemctl restart gir-headsup; sleep 3; echo "gir-headsup: $(systemctl is-active gir-headsup)"
echo "=== what a trade alert looks like from tomorrow (a made-up example):"
cd $D && python3 -c "import headsup as h; print(h.card('EXAMPLE', -1, 100.0, 102.5, 98.5, '09:25', 'METAL falling -1.2%, 9 of 11 shares down', 'tested: '+h.Live().tested()))"
echo "=== live price for the exits: $(cd $D && python3 -c "import headsup as h; q=h.live_px(); print(str(len(q))+' shares, fresh' if q else 'none fresh now (the engine writes it in market hours) - the 5-min bar is used until then')")"
echo "=== today again, honestly (WATCH / IN DOUBT lines are not calls now):"
cd $D && timeout 400 python3 missed.py | tail -8
echo "✅ patch 353 done - from tomorrow 09:20 every trade alert is one 🟢/🔴 BUY card with entry, stop, half-out; exits checked every 15 s. Undo: for f in headsup missed; do cp $D/\$f.py.bak353 $D/\$f.py; done; systemctl restart gir-headsup"
