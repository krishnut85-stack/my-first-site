#!/bin/bash
# PATCH 351 - 👀 HEADS-UP + 🔻🔺 SECTOR ALERTS, LIVE, WITH MONITORING (Rama, 16 Nov: "let me know BEFORE the move - a clear alert and a clear
#   monitoring system; the shares of a falling sector (SAIL, SYRMA) never got an alert").
#   · headsup.py + gir-headsup service: every 5 min 09:20-14:30 the scanner replayed on 25 days (+₹6,472 a day at a 2.5% stop, 18 of 25 green,
#     before charges) -> 👀 HEADS-UP (share, CE/PE, stop 2.5%, half out at +1.5%); a whole sector 0.6%+ one way with 70%+ of its shares ->
#     🔻🔺 SECTOR (its 3 weakest / strongest). Every alerted share FOLLOWED: 📈 +1% more · ✅ half out · ❌ stop - OUT · ⏹ 15:10 close.
#     Never the same thing twice. GIR's PAGE FIRST (the 👀 box + the alert list), Telegram GIR Bigmovers (with sound) 8 seconds after.
#   · GIR (laptop, iPad, phone): a 👀 box at the top of TRADE NOW - each share, its side, where it is now (WATCH / HALF OUT / STOPPED), a chime on new
#   · dashserve.py /headsup · movescan.py (the replay, + sector alerts) refreshed
#   Restarts the dashboard. Starts gir-headsup (it rings from tomorrow 09:20). Prints the 25-day replay at the end.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 351" $D/home.html && [ -f $D/headsup.py ] && systemctl is-active --quiet gir-headsup; then echo "patch 351 - already in"; exit 0; fi
grep -q "patch 350" $D/engine2.py && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py || { echo "patch 350 first / dashserve's route not found - nothing done"; exit 1; }
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl disable --now gir-headsup 2>/dev/null; rm -f /etc/systemd/system/gir-headsup.service $D/headsup.py; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/headsup.py <<'PY_HU'
#!/usr/bin/env python3
"""headsup.py - patch 351: 👀 HEADS-UP + 🔻🔺 SECTOR ALERTS, LIVE (Rama, 16 Nov: "let me know BEFORE the move - a clear alert and a clear
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
            txt = ("👀 HEADS-UP %s %s %s · ₹%s · %s\n%s %+.1f%% (%d%% of its shares the same way) · volume %.1fx its normal\n"
                   "the at-the-money %s · stop: the share back %s ₹%s (2.5%%) · half out at ₹%s (+1.5%%)\nnot confirmed yet - GIR follows it and rings when it goes +1%% more, "
                   "reaches the target or fails") % ("▲" if dr > 0 else "▼", f["s"], "CE" if dr > 0 else "PE", "{:,.2f}".format(px), f["hm"], (secn or "its sector").upper(),
                                                     f["sec"] * 100, round(f["same"] * 100), f["volx"], "CE" if dr > 0 else "PE", "under" if dr > 0 else "over",
                                                     "{:,.2f}".format(stop), "{:,.2f}".format(half))
            out.append(txt)
            self.mon[k] = {"s": f["s"], "dir": dr, "t": f["hm"], "px": px, "stop": stop, "half": half, "step": 1, "st": "open", "kind": "👀"}
        for a in M.sector_alerts(P, self.SECS, self.W, d, upto=hm):
            k = (a["name"], a["dir"], round(abs(a["mv"]) * 200))
            if k in self.sec_sent:
                continue
            first = not any(x[0] == a["name"] and x[1] == a["dir"] for x in self.sec_sent)
            self.sec_sent.add(k)
            if a["hm"] < (n - dt.timedelta(minutes=12)).strftime("%H:%M"):
                continue                                                       # an old one (a restart) - not rung again
            txt = ("%s SECTOR %s · %s %+.1f%% · %d of %d shares %s · %s\n%s → %s side\n%s") % (
                "🔻" if a["dir"] < 0 else "🔺", "FALLING" if a["dir"] < 0 else "RISING", a["name"].upper(), a["mv"] * 100, round(a["same"] * a["n"]), a["n"],
                "down" if a["dir"] < 0 else "up", a["hm"], " · ".join("%s %+.1f%%" % (p["s"], p["rp"] * 100) for p in a["picks"]), "PE" if a["dir"] < 0 else "CE",
                "first alert - stop 2.5% on each share, half out at +1.5%" if first else "still going - the same trade, no new entry")
            out.append(txt)
            if first:
                for p in a["picks"]:
                    if p["s"] not in self.mon:
                        dr = a["dir"]; px = p["px"]
                        self.mon[p["s"]] = {"s": p["s"], "dir": dr, "t": a["hm"], "px": px, "stop": px * (1 - dr * STOP), "half": px * (1 + dr * HALF), "step": 1, "st": "open", "kind": "🔻" if dr < 0 else "🔺"}
                        self.sent[p["s"]] = True
        for k, m in self.mon.items():                                          # MONITORING - every alerted share, to its end
            if m["st"] in ("out", "closed") or k not in P or d not in P[k]:
                continue
            last = P[k][d]["rows"][-1]; px = last["c"]; dr = m["dir"]; mv = (px / m["px"] - 1) * dr; m["now"] = px; m["mv"] = round(mv * 100, 2)
            msg = None
            if (px - m["stop"]) * dr <= 0:
                m["st"] = "out"; msg = "❌ OUT %s %s · ₹%s · the stop (%s) - the move failed%s" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), "{:,.2f}".format(m["stop"]), " · half was booked" if m.get("halfd") else "")
            elif not m.get("halfd") and mv >= HALF:
                m["halfd"] = True; m["stop"] = m["px"]; m["st"] = "half"
                msg = "✅ HALF OUT %s %s · ₹%s (+1.5%%) · book half · the stop moves to your entry ₹%s - no loss from here" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), "{:,.2f}".format(m["px"]))
            elif mv >= MORE * (m["step"] + 1):
                m["step"] = int(mv / MORE)
                msg = "📈 STILL GOING %s %s · ₹%s · %+.1f%% from the alert at %s" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), mv * 100, m["t"])
            elif hm >= "15:10":
                m["st"] = "closed"; msg = "⏹ 15:10 CLOSE %s %s · ₹%s · %+.1f%% from the alert at %s - not held overnight" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), mv * 100, m["t"])
            if msg:
                out.append(msg)
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        json.dump({"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": d, "mon": self.mon, "sec_sent": [list(x) for x in self.sec_sent],
                   "sectors": [{"hm": a["hm"], "name": a["name"], "dir": a["dir"], "mv": round(a["mv"] * 100, 2), "same": round(a["same"] * 100)} for a in M.sector_alerts(P, self.SECS, self.W, d, upto=hm)][-12:]},
                  open(OUT + ".tmp", "w")); os.replace(OUT + ".tmp", OUT)
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
        except Exception as ex:
            print("headsup: %s" % str(ex)[:120], flush=True); time.sleep(30)
        time.sleep(10)


if __name__ == "__main__":
    main()
PY_HU
cat > $W/movescan.py <<'PY_MS'
#!/usr/bin/env python3
"""movescan.py - patch 347: READ ONLY. 🎯 THE MOVE SCANNER, REPLAYED (Rama, 16 Nov: "most alerts come after the move - SYRMA, SAIL, no signal at all
- find the shares for CE and PE before they move"). Scores every F&O share every 5 minutes on what comes BEFORE a big move, then replays it on
GIR's own saved 5-minute bars (about 30 trading days): when it would have flagged, how early, how much move was left, the false alarms.
  the score (one direction at a time, max 9):  price out of the first 15 minutes' range (1) · on the right side of VWAP (1) · moving 0.4%+ from the
  open but not over 2.5% (1) · volume vs its own normal at that time of day 1.5x (1) / 2.5x (2) · its SECTOR the same way 0.4%+ with 65% of its
  shares (2) / 0.2%+ (1) · NIFTY the same way 0.2%+ (1) · one flag per share per day, none after 14:30
  a HIT = the price goes 1.5%+ the flagged way before 0.75% against (by the close) · a BIG MOVE = a share going 2.5%+ one way from the open
  thresholds tried 5 / 6 / 7: the one that catches the most big moves early with at most ~20 flags a day is chosen - by the numbers
Data via this server's own page feeds (/home, /hist) and NSE's futures file for the size weights. Nothing is changed, nothing is sent.
python3 movescan.py [days]      -> prints the report, saves data/movescan.txt (download: girtrader.com/doctor.txt after `cp`)"""
import os, sys, json, glob, time, math, sqlite3, urllib.request, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, D)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
OUT = os.path.join(D, "data", "movescan.txt")
L = []
def say(s=""):
    L.append(s); print(s)


def get(path, tok, base="http://127.0.0.1:8090"):
    u = base + path + ("&" if "?" in path else "?") + "k=" + urllib.request.quote(tok)
    return json.loads(urllib.request.urlopen(u, timeout=60).read() or b"null")


def days_of(b):
    """bars -> {date: [(t, o, h, l, c, v), ...]}"""
    out = {}
    for i, t in enumerate(b.get("t") or []):
        d = dt.datetime.fromtimestamp(t, IST)
        out.setdefault(str(d.date()), []).append((d.strftime("%H:%M"), b["o"][i], b["h"][i], b["l"][i], b["c"][i], b["v"][i] or 0))
    return out


def prep(B):
    """per share: {date: dict(arrays)} with prev close, the open range, vwap, cumulative volume"""
    out, prev_c = {}, None
    for d in sorted(B):
        bars = [x for x in B[d] if "09:15" <= x[0] <= "15:29"]
        if len(bars) < 20:
            prev_c = bars[-1][4] if bars else prev_c
            continue
        o0 = bars[0][1]; pc = prev_c or o0
        orh = max(x[2] for x in bars[:3]); orl = min(x[3] for x in bars[:3])
        pv = vv = cv = 0.0; rows = []
        for (hm, o, h, l, c, v) in bars:
            tp = (h + l + c) / 3; pv += tp * v; vv += v; cv += v
            rows.append({"hm": hm, "h": h, "l": l, "c": c, "vwap": pv / vv if vv else c, "cv": cv, "rp": c / pc - 1, "ro": c / o0 - 1})
        out[d] = {"o0": o0, "pc": pc, "orh": orh, "orl": orl, "rows": rows}
        prev_c = bars[-1][4]
    return out


def scan(P, SEC, W, NIF, th, day_cap=12, per_bar=2):
    """v2 (16 Nov, after the first replay: every flag landed at 09:30, the big gap movers were missed):
    · volume 1.5x its normal at that time is REQUIRED (the 09:30 noise had 0.4-0.9x)
    · momentum REQUIRED: the last 15 minutes 0.3%+ the same way (a move still running, not a stale open)
    · strength from YESTERDAY'S CLOSE, no 2.5% cap - a gap mover still counts while it keeps going
    · every 5 minutes only the best `per_bar` new shares (highest score), at most `day_cap` a day - a ranked list, not first-come"""
    dates = sorted({d for s in P for d in P[s]})
    flags = {}
    for k, d in enumerate(dates):
        prev10 = dates[max(0, k - 10):k]
        if len(prev10) < 5:
            continue
        RP = {s: {r["hm"]: r["rp"] for r in P[s][d]["rows"]} for s in P if d in P[s]}
        BASE = {}
        for s in P:
            if d not in P[s]:
                continue
            b_ = {}
            for pd_ in prev10:
                if pd_ in P[s]:
                    for r in P[s][pd_]["rows"]:
                        b_.setdefault(r["hm"], []).append(r["cv"])
            BASE[s] = b_
        hms = sorted({r["hm"] for s in P if d in P[s] for r in P[s][d]["rows"] if "09:20" <= r["hm"] <= "14:30"})   # v3: from 09:20 - the gap movers
        done, F = set(), []
        for hm in hms:
            cand = []
            for s in P:
                if s in done or d not in P[s]:
                    continue
                day = P[s][d]; rows = day["rows"]
                i = next((j for j, r in enumerate(rows) if r["hm"] == hm), None)
                if i is None or i < 1:
                    continue
                r = rows[i]; bl = BASE[s].get(hm) or []
                volx = r["cv"] / (sum(bl) / len(bl)) if bl and sum(bl) > 0 else 1.0
                if volx < 1.5:
                    continue
                mom = r["c"] / (rows[i - 3]["c"] if i >= 3 else day["o0"]) - 1
                peers = [p for p in SEC.get(s, []) if p != s and p in RP]
                pr = [(RP[p].get(hm), W.get(p, 1.0)) for p in peers if RP[p].get(hm) is not None]
                sw = sum(w for _, w in pr); sec = sum(x * w for x, w in pr) / sw if sw else 0.0
                nif = (NIF.get(d) or {}).get(hm, 0.0)
                for dr in (1, -1):
                    if mom * dr < 0.003 or r["rp"] * dr < 0.005:
                        continue
                    sc = 0
                    sc += 1 if (r["c"] > day["orh"] if dr > 0 else r["c"] < day["orl"]) else 0
                    sc += 1 if (r["c"] - r["vwap"]) * dr > 0 else 0
                    sc += 2 if volx >= 2.5 else 1
                    sc += 1 if mom * dr >= 0.006 else 0
                    same = sum(1 for x, _ in pr if x * dr > 0) / len(pr) if pr else 0
                    if pr and same < 0.5 and volx < 4:                     # v3: against its own sector - only a share with its OWN big news volume (4x+) counts
                        continue
                    sc += 2 if (sec * dr >= 0.004 and same >= 0.65) else 1 if sec * dr >= 0.002 else 0
                    sc += 1 if volx >= 4 else 0
                    sc += 1 if nif * dr >= 0.002 else 0
                    if sc >= th:
                        cand.append((sc, volx, s, dr, i, r, sec, same, abs(r["rp"]) * min(volx, 10)))
            cand.sort(key=lambda x: (-x[0], -x[8]))                         # v3: the strongest first - score, then move x volume
            for sc, volx, s, dr, i, r, sec, same, _ in cand[:per_bar]:
                if len(F) >= day_cap:
                    break
                done.add(s)
                rest = P[s][d]["rows"][i + 1:]; P0 = r["c"]; hit = False; mfe = 0.0; mn = None
                for j, x in enumerate(rest):
                    fav = ((x["h"] / P0 - 1) if dr > 0 else (1 - x["l"] / P0)); adv = ((1 - x["l"] / P0) if dr > 0 else (x["h"] / P0 - 1))
                    mfe = max(mfe, fav)
                    if adv >= 0.0075:
                        break
                    if fav >= 0.015:
                        hit = True; mn = (j + 1) * 5; break
                pnl = sim(P[s][d]["rows"][i + 1:], P0, dr)
                pn = {k_: sim(P[s][d]["rows"][i + 1:], P0, dr, k_) for k_ in (0.0075, 0.015, 0.025)}
                F.append({"pnl": pnl, "pn": pn, "s": s, "hm": hm, "dir": dr, "sc": sc, "px": P0, "volx": volx, "sec": sec, "same": same, "hit": hit, "mins": mn, "mfe": mfe})
        flags[d] = F
    return flags


def sim(rest, P0, dr, st=0.0075):
    """the share's % result of one trade: stop -st; at +1.5% half is booked and the stop goes to the entry; the rest out at 15:10"""
    half = None; stop = -st
    for x in rest:
        lo = ((x["l"] / P0 - 1) if dr > 0 else (1 - x["h"] / P0)); hi = ((x["h"] / P0 - 1) if dr > 0 else (1 - x["l"] / P0))
        if lo <= stop:
            return stop if half is None else (half + stop) / 2
        if half is None and hi >= 0.015:
            half, stop = 0.015, 0.0
        if x["hm"] >= "15:10":
            c = (x["c"] / P0 - 1) * dr
            return c if half is None else (half + c) / 2
    c = (rest[-1]["c"] / P0 - 1) * dr if rest else 0.0
    return c if half is None else (half + c) / 2


def big_moves(P, d):
    out = []
    for s in P:
        if d not in P[s]:
            continue
        rows = P[s][d]["rows"]; o0 = P[s][d]["o0"]
        up = max(r["h"] for r in rows) / o0 - 1; dn = 1 - min(r["l"] for r in rows) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size < 0.025:
            continue
        start = next((r["hm"] for r in rows if r["ro"] * dr >= 0.005), None)
        half = next((r["hm"] for r in rows if r["ro"] * dr >= size / 2), None)
        out.append({"s": s, "dir": dr, "size": size, "start": start, "half": half})
    return sorted(out, key=lambda m: -m["size"])[:10]                       # v3: the day's 10 biggest movers


def mins(a, b):
    return (int(b[:2]) * 60 + int(b[3:])) - (int(a[:2]) * 60 + int(a[3:]))


def evaluate(P, flags):
    days = sorted(flags); tot = {"flags": 0, "hits": 0, "big": 0, "caught": 0, "early": []}
    for d in days:
        F = flags[d]; tot["flags"] += len(F); tot["hits"] += sum(1 for f in F if f["hit"])
        for m in big_moves(P, d):
            tot["big"] += 1
            f = next((f for f in F if f["s"] == m["s"] and f["dir"] == m["dir"]), None)
            if f and m["half"] and f["hm"] <= m["half"]:
                tot["caught"] += 1; tot["early"].append(mins(m["start"], f["hm"]) if m["start"] else 0)
    n = len(days) or 1
    return {"days": len(days), "per_day": tot["flags"] / n, "hit": tot["hits"] / tot["flags"] if tot["flags"] else 0, "big": tot["big"], "caught": tot["caught"],
            "cover": tot["caught"] / tot["big"] if tot["big"] else 0, "after_start": (sorted(tot["early"])[len(tot["early"]) // 2] if tot["early"] else None)}


def gir_first(day):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        R = c.execute("select sym, min(t) from alerts where day=? and sym!='' group by sym", (day,)).fetchall(); c.close()
        return {s: t[:5] for s, t in R}
    except Exception:
        return {}


def sector_alerts(P, SECS, W, d, upto="14:30", th=0.006, br=0.7, deeper=0.005):
    """🔻🔺 a whole SECTOR moving (Rama, 16 Nov: "the shares of a falling sector never got an alert - SAIL, SYRMA"): every 5 min from 09:20, a
    sector of 4+ F&O shares whose size-weighted move from yesterday's close is 0.6%+ with 70%+ of its shares the same way -> its 3 weakest
    (falling, PE) / strongest (rising, CE) shares. Again only if it goes another 0.5% deeper."""
    out, last = [], {}
    hms = sorted({r["hm"] for s in P if d in P[s] for r in P[s][d]["rows"] if "09:20" <= r["hm"] <= upto})
    for hm in hms:
        for g in SECS:
            name = g.get("name"); syms = [s for s in (g.get("syms") or []) if s in P and d in P[s]]
            if len(syms) < 4:
                continue
            cur = []
            for s in syms:
                rows = P[s][d]["rows"]; i = next((j for j, r in enumerate(rows) if r["hm"] == hm), None)
                if i is not None:
                    cur.append((s, rows[i]["rp"], rows[i]["c"], i))
            if len(cur) < 4:
                continue
            sw = sum(W.get(s, 1.0) for s, *_ in cur); mv = sum(x * W.get(s, 1.0) for s, x, *_ in cur) / sw if sw else 0.0
            for dr in (1, -1):
                same = sum(1 for _, x, *_ in cur if x * dr > 0) / len(cur)
                if mv * dr < th or same < br:
                    continue
                k = (name, dr)
                if k in last and mv * dr < last[k] + deeper:
                    continue
                last[k] = mv * dr
                picks = sorted(cur, key=lambda c: -c[1] * dr)[:3]
                out.append({"hm": hm, "name": name, "dir": dr, "mv": mv, "same": same, "n": len(cur),
                            "picks": [{"s": s, "rp": x, "px": c, "pnl": sim(P[s][d]["rows"][i + 1:], c, dr, 0.025)} for s, x, c, i in picks]})
    return out


def lots():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        R = dict(c.execute("select sym, lot from fo_list").fetchall()); c.close(); return R
    except Exception:
        return {}


def money(P, fl):
    """₹ per trade = the share's % move x its price x its lot x 0.5 (an at-the-money option moves about half the share's rupees), 1 lot,
    before charges. The scanner's flags (its own exit rule) vs GIR's own cards today (tomorrow.db wind_cards)."""
    LOT = lots(); days = sorted(fl)
    if not days:
        return
    rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    say(""); say("💰 THE MONEY (1 lot each, an at-the-money option ~ half the share's rupee move, before charges)")
    for st in (0.0075, 0.015, 0.025):                                      # v4: how wide the stop must be - over all the days
        tot = sum(rs(f["pn"][st], f["px"], f["s"]) for d in days for f in fl[d]); n = sum(len(fl[d]) for d in days)
        won = sum(1 for d in days for f in fl[d] if f["pn"][st] > 0); good = sum(1 for d in days if sum(rs(f["pn"][st], f["px"], f["s"]) for f in fl[d]) > 0)
        say("  stop %.2f%% on the share · %d days · %d trades · %d won · %d green days · total ₹%s (₹%s a day)" % (st * 100, len(days), n, won, good, "{:,.0f}".format(tot), "{:,.0f}".format(tot / max(1, len(days)))))
    for d in days[-3:]:
        F = fl[d]; tot = sum(rs(f["pnl"], f["px"], f["s"]) for f in F); w = sum(1 for f in F if f["pnl"] > 0)
        say("  %s · the scanner: %d trades · %d won · ₹%s" % (d, len(F), w, "{:,.0f}".format(tot)))
    day = days[-1]
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "tomorrow.db"), uri=True, timeout=5)
        R = c.execute("select sym, entry, res from wind_cards where day=?", (day,)).fetchall(); c.close()
    except Exception:
        R = []
    if R:
        g = sum(rs((res or 0) / 100.0, e or 0, s) for s, e, res in R); fo = sum(1 for s, _, _ in R if s in LOT)
        say("  %s · GIR's own cards: %d cards (%d of them F&O) · %d won · ₹%s on the F&O ones" % (day, len(R), fo, sum(1 for *_, r in R if (r or 0) > 0),
                                                                                     "{:,.0f}".format(sum(rs((res or 0) / 100.0, e or 0, s) for s, e, res in R if s in LOT))))
    say("  %s · each scanner trade (₹ at stop 0.75%% · 1.5%% · 2.5%%):" % day)
    for f in sorted(fl[day], key=lambda f: -rs(f["pn"][0.015], f["px"], f["s"])):
        say("    %s %-11s %s at ₹%s · lot %s · ₹%s · ₹%s · ₹%s" % (f["hm"], f["s"], "CE" if f["dir"] > 0 else "PE", "{:,.2f}".format(f["px"]), LOT.get(f["s"], "?"),
              *["{:,.0f}".format(rs(f["pn"][k_], f["px"], f["s"])) for k_ in (0.0075, 0.015, 0.025)]))
    top = big_moves(P, day)
    pot = sum(rs(m["size"] * 0.6, P[m["s"]][day]["o0"], m["s"]) for m in top)
    say("  %s · if you had caught 60%% of each of the 10 biggest moves (the most an early alert can give): about ₹%s" % (day, "{:,.0f}".format(pot)))


def sector_report(P, SECS, W, days):
    LOT = lots(); rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    tot = n = won = 0; per = {}
    for d in days:
        A = sector_alerts(P, SECS, W, d)
        seen = set()
        for a in A:
            a["first"] = (a["name"], a["dir"]) not in seen; seen.add((a["name"], a["dir"]))
            if not a["first"]:
                continue                                                   # a deeper move = an update on the same trade, not a new one
            for p in a["picks"]:
                v = rs(p["pnl"], p["px"], p["s"]); tot += v; n += 1; won += p["pnl"] > 0; per[d] = per.get(d, 0) + v
        if d == days[-1]:
            last = A
    say(""); say("🔻🔺 SECTOR ALERTS replayed (a whole sector 0.6%+ one way, 70%+ of its shares - its 3 weakest / strongest; stop 2.5%, half at +1.5%)")
    say("  %d days · %d trades · %d won · %d green days · total ₹%s (₹%s a day)" % (len(days), n, won, sum(1 for v in per.values() if v > 0), "{:,.0f}".format(tot), "{:,.0f}".format(tot / max(1, len(days)))))
    for a in (last if days else []):
        say("  %s %s %s%s %+.1f%% (%d%% of %d same way) → %s" % (a["hm"], "" if a.get("first") else "   ↳ still going:", "🔻" if a["dir"] < 0 else "🔺", a["name"].upper(), a["mv"] * 100, round(a["same"] * 100), a["n"],
            " · ".join("%s %s %+.1f%% then ₹%s" % (p["s"], "PE" if a["dir"] < 0 else "CE", p["rp"] * 100, "{:,.0f}".format(rs(p["pnl"], p["px"], p["s"]))) for p in a["picks"])))


def main():
    ndays = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 30
    import dashserve
    tok = str(getattr(dashserve, "TOKEN", "") or "")
    H = get("/home", tok); SECS = H.get("sectors") or []
    SEC = {}
    for x in SECS:
        for s in x.get("syms") or []:
            SEC[s] = x["syms"]
    syms = sorted(SEC)
    W = {}
    fs = sorted(glob.glob(os.path.join(D, "data", "nsefutx_*.json")))
    for f in reversed(fs):
        try:
            N = json.load(open(f))
            if N:
                W = {s: sum((r[2] or 0) * (r[1] or 0) for r in R) for s, R in N.items()}; break
        except Exception:
            pass
    say("🎯 MOVE SCANNER replay v4 · %s IST · %d F&O shares · %d sectors · size weights %s" % (dt.datetime.now(IST).strftime("%d %b %H:%M"), len(syms), len(SECS), "from NSE's futures file" if W else "equal"))
    P = {}
    for i, s in enumerate(syms):
        try:
            b = get("/hist?sym=%s&days=%d" % (urllib.request.quote(s), ndays), tok)
            if b and b.get("t"):
                P[s] = prep(days_of(b))
        except Exception:
            pass
    NIF = {}
    try:
        nb = get("/hist?sym=NIFTY50&days=%d" % ndays, tok)
        for d, day in prep(days_of(nb)).items():
            NIF[d] = {r["hm"]: r["rp"] for r in day["rows"]}
    except Exception:
        pass
    say("  read %d shares' 5-min bars · NIFTY %s" % (len(P), "yes" if NIF else "NOT read (market tide left out)"))
    best = None
    for th in (4, 5, 6, 7):
        fl = scan(P, SEC, W, NIF, th); ev = evaluate(P, fl)
        say("  threshold %d: %4.1f flags a day · hit %3.0f%% (1.5%%+ before -0.75%%) · the day's 10 biggest movers caught before half-way: %d of %d (%3.0f%%) · median %s min after the move started" % (
            th, ev["per_day"], ev["hit"] * 100, ev["caught"], ev["big"], ev["cover"] * 100, ev["after_start"]))
        sc = ev["cover"] * (0.5 + ev["hit"]) if ev["per_day"] <= 22 else -1
        if best is None or sc > best[0]:
            best = (sc, th, fl, ev)
    _, th, fl, ev = best
    say(""); say("  CHOSEN: threshold %d - catches %d%% of the big moves before half-way, %d%% of its flags hit 1.5%%+" % (th, round(ev["cover"] * 100), round(ev["hit"] * 100)))
    days = sorted(fl)
    for d in days[-2:]:
        G = gir_first(d)
        say(""); say("  ── %s: the scanner's flags (time · share · side · score · then)  vs  GIR's first alert that day" % d)
        for f in fl[d]:
            say("   %s  %-11s %s  score %d  vol %.1fx  sector %+.1f%% (%d%% same)  → %s   GIR first alert: %s" % (f["hm"], f["s"], "▲ CE" if f["dir"] > 0 else "▼ PE", f["sc"], f["volx"], f["sec"] * 100, f["same"] * 100,
                ("HIT +1.5%% in %d min" % f["mins"]) if f["hit"] else "no (best %.1f%%)" % (f["mfe"] * 100), G.get(f["s"], "none")))
        mv = big_moves(P, d)
        caught = {f["s"] for f in fl[d]}
        miss = [m for m in mv if m["s"] not in caught]
        if miss:
            say("   big moves NOT flagged: " + " · ".join("%s %s%.1f%% from %s" % (m["s"], "+" if m["dir"] > 0 else "−", m["size"] * 100, m["start"]) for m in sorted(miss, key=lambda m: -m["size"])[:12]))
    money(P, fl)
    sector_report(P, SECS, W, sorted(fl))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write("\n".join(L) + "\n")
    say(""); say("saved data/movescan.txt")


if __name__ == "__main__":
    main()
PY_MS
cat > $W/home_add.html <<'ADD_H'
<style>/* patch 351: 👀 HEADS-UP · 🔻🔺 SECTORS at the top of TRADE NOW - every alerted share and where it is now */
#gxhu{margin:0 0 10px;border:1px solid #5c4410;border-radius:8px;background:#151006;font:12.5px/1.4 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3}
#gxhu .h{display:flex;justify-content:space-between;align-items:center;padding:7px 10px;border-bottom:1px solid #3a2c10;font:800 12px ui-monospace,Menlo,monospace;letter-spacing:.06em;color:#f5a623}
#gxhu .h small{font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf}
#gxhu .r{display:grid;grid-template-columns:42px minmax(0,1fr) auto;gap:6px;align-items:center;padding:6px 10px;border-bottom:1px solid #22190a;cursor:pointer}
#gxhu .r:last-child{border-bottom:0}#gxhu .r:hover{background:#1d160a}
#gxhu .t{font:12px ui-monospace,Menlo,monospace;color:#a3aebf}#gxhu .s{font:700 12.5px ui-monospace,Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#gxhu .st{font:700 11px ui-monospace,Menlo,monospace;padding:2px 7px;border-radius:3px;white-space:nowrap}
#gxhu .st.open{background:#1b2a3a;color:#8fc3ff}#gxhu .st.half{background:#0d3324;color:#4fd69c}#gxhu .st.out{background:#3a1416;color:#f58a86}#gxhu .st.closed{background:#1b222d;color:#a3aebf}
#gxhu .up{color:#26c281}#gxhu .dn{color:#f0544f}#gxhu .sec{padding:6px 10px;border-bottom:1px solid #22190a;font-size:12px;color:#c9d1dc}
#gxhu .none{padding:8px 10px;color:#a3aebf;font-size:12px}
</style>
<script>/* patch 351: the 👀 box - data/headsup.json (headsup.py, every 5 min) - a chime when a new share or sector is added; read every 5 s, the phone rings 8 s after */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let V=null, seen=null;
  function chime(){ try{ const A=new (window.AudioContext||window.webkitAudioContext)(); [880,1320].forEach((f,i)=>{ const o=A.createOscillator(), g=A.createGain(); o.frequency.value=f; o.connect(g); g.connect(A.destination);
      g.gain.setValueAtTime(0.0001,A.currentTime+i*0.18); g.gain.exponentialRampToValueAtTime(0.25,A.currentTime+i*0.18+0.02); g.gain.exponentialRampToValueAtTime(0.0001,A.currentTime+i*0.18+0.3); o.start(A.currentTime+i*0.18); o.stop(A.currentTime+i*0.18+0.32); }); }catch(e){} }
  function draw(){ const host=document.getElementById("q-act"); if(!host) return; let el=document.getElementById("gxhu");
    if(!el){ el=document.createElement("div"); el.id="gxhu"; const h3=host.querySelector("h3"); (h3||host.firstChild)?(h3||host.firstChild).after?((h3||host.firstChild).after(el)):host.prepend(el):host.prepend(el); }
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10);
    const M=V&&V.day===today?Object.values(V.mon||{}).sort((a,b)=>String(b.t).localeCompare(String(a.t))):[], SX=V&&V.day===today?(V.sectors||[]).slice(-3).reverse():[];
    const ST={open:"WATCH",half:"HALF OUT ✓",out:"STOPPED",closed:"CLOSED 15:10"};
    el.innerHTML=`<div class="h"><span>👀 HEADS-UP · BEFORE THE MOVE</span><small>${V&&V.at?"checked "+E(V.at.slice(0,5))+" · every 5 min":"from 09:20"}</small></div>`+
      SX.map(a=>`<div class="sec">${a.dir<0?"🔻":"🔺"} <b>${E(String(a.name).toUpperCase())}</b> ${a.mv>0?"+":""}${a.mv}% · ${a.same}% of its shares ${a.dir<0?"down → PE":"up → CE"} · ${E(a.hm)}</div>`).join("")+
      (M.length?M.map(m=>`<div class="r" onclick="try{mkOpen('${E(m.s).replace(/'/g,"")}')}catch(e){}"><span class="t">${E(m.t)}</span><span class="s">${E(m.kind||"👀")} ${E(m.s)} <span class="${m.dir>0?"up":"dn"}">${m.dir>0?"CE":"PE"}</span> <span class="t">₹${Number(m.px).toLocaleString("en-IN",{maximumFractionDigits:2})}${m.mv!=null?` · now <b class="${m.mv>0?"up":m.mv<0?"dn":""}">${m.mv>0?"+":""}${m.mv}%</b>`:""}</span></span><span class="st ${E(m.st)}">${ST[m.st]||E(m.st)}</span></div>`).join("")
        :'<div class="none">nothing yet today - a share or a sector moving with volume shows here (and rings) before the move runs</div>'); }
  async function pull(){ try{ const r=await fetch("headsup?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok){ V=await r.json();
        const keys=new Set([...Object.keys(V.mon||{}),...(V.sectors||[]).map(a=>a.name+a.dir+a.hm)]);
        if(seen&&[...keys].some(k=>!seen.has(k))) chime(); seen=keys; draw(); } }catch(e){} }
  let q=false; try{ new MutationObserver(()=>{ if(q) return; q=true; setTimeout(()=>{ q=false; if(!document.getElementById("gxhu")) draw(); },300); }).observe(document.body,{childList:true,subtree:true}); }catch(e){}
  setInterval(()=>{ if(!document.hidden) pull(); },5000); pull(); })();   /* every 5 s - the page before the phone */
</script>
ADD_H
python3 -m py_compile $W/headsup.py $W/movescan.py || { echo "❌ did not compile - nothing changed"; exit 1; }
cp $W/headsup.py $D/headsup.py && cp $W/movescan.py $D/movescan.py || back
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 351" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/headsup":                  # patch 351: 👀 HEADS-UP + sector alerts and where each share is now (read only)
                try:
                    v_ = json.load(open(os.path.join(BASE, "data", "headsup.json")))
                except Exception:
                    v_ = {"mon": {}, "sectors": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /headsup")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 351" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the 👀 box in TRADE NOW")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cat > /etc/systemd/system/gir-headsup.service <<'UNIT'
[Unit]
Description=GIR HEADS-UP + sector alerts with monitoring (patch 351)
After=network-online.target gir-dash.service
[Service]
Type=simple
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd /home/globalbot/intraday && exec python3 -u headsup.py >> data/headsup.log 2>&1'
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now gir-headsup >/dev/null 2>&1 || back
systemctl restart gir-dash; sleep 6
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-headsup: $(systemctl is-active gir-headsup)"
[ "$(systemctl is-active gir-dash)" = "active" ] && [ "$(systemctl is-active gir-headsup)" = "active" ] || back
echo "=== the 25-day replay (the scanner + the sector alerts), about 2 minutes"
cd $D && timeout 400 python3 movescan.py 30 | grep -A12 "THE MONEY\|SECTOR ALERTS" | grep -v "each scanner trade\|^    [0-9]"
echo "✅ patch 351 done - from tomorrow 09:20: 👀 HEADS-UP and 🔻🔺 SECTOR rings on GIR Bigmovers + the 👀 box in TRADE NOW."
echo "   undo: systemctl disable --now gir-headsup; rm /etc/systemd/system/gir-headsup.service; for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
