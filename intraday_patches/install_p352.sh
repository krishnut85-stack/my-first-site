#!/bin/bash
# PATCH 352 - FEWER, BETTER EARLY ALERTS (Rama, 16 Nov: "the target is ONE thing - an early alert so I can buy the lot and make money").
#   · the 🔻🔺 sector alerts were ~50 a day, 13 of 25 days green: 8 settings replayed on 25 days, the one with at most 10 trades a day and the most
#     green days is chosen BY THE NUMBERS (data/headsup_cfg.json) and the live alerts (headsup.py) use it from tomorrow
#   · missed.py: a real CE/PE call counted apart from a news / list mention (the "on time" in the first table was a mention, not a call)
#   · loadtest.py: "futures money loading while the price is flat" tested on today's minute history at 3 / 5 / 10 minutes - before the move?
#   Replaces headsup.py (351's), movescan.py, missed.py; adds loadtest.py. Restarts gir-headsup only. Prints the three results.
set -u
D=/home/globalbot/intraday; W=$(mktemp -d)
grep -q "patch 351" $D/headsup.py 2>/dev/null || { echo "patch 351 first"; exit 1; }
cat > $W/headsup.py <<'PY_headsup'
#!/usr/bin/env python3
"""headsup.py - patch 351 + 352 (the sector alerts use the settings the replay chose - data/headsup_cfg.json): 👀 HEADS-UP + 🔻🔺 SECTOR ALERTS, LIVE (Rama, 16 Nov: "let me know BEFORE the move - a clear alert and a clear
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
            txt = ("👀 HEADS-UP %s %s %s · ₹%s · %s\n%s %+.1f%% (%d%% of its shares the same way) · volume %.1fx its normal\n"
                   "the at-the-money %s · stop: the share back %s ₹%s (2.5%%) · half out at ₹%s (+1.5%%)\nnot confirmed yet - GIR follows it and rings when it goes +1%% more, "
                   "reaches the target or fails") % ("▲" if dr > 0 else "▼", f["s"], "CE" if dr > 0 else "PE", "{:,.2f}".format(px), f["hm"], (secn or "its sector").upper(),
                                                     f["sec"] * 100, round(f["same"] * 100), f["volx"], "CE" if dr > 0 else "PE", "under" if dr > 0 else "over",
                                                     "{:,.2f}".format(stop), "{:,.2f}".format(half))
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
            txt = ("%s SECTOR %s · %s %+.1f%% · %d of %d shares %s · %s\n%s → %s side\n%s") % (
                "🔻" if a["dir"] < 0 else "🔺", "FALLING" if a["dir"] < 0 else "RISING", a["name"].upper(), a["mv"] * 100, round(a["same"] * a["n"]), a["n"],
                "down" if a["dir"] < 0 else "up", a["hm"], " · ".join("%s %+.1f%%" % (p["s"], p["rp"] * 100) for p in a["picks"]), "PE" if a["dir"] < 0 else "CE",
                ("first alert - stop %.1f%% on each share, half out at +%.1f%%" % (sst * 100, shf * 100)) if first else "still going - the same trade, no new entry")
            out.append(txt)
            if first:
                for p in a["picks"]:
                    if p["s"] not in self.mon:
                        dr = a["dir"]; px = p["px"]
                        self.mon[p["s"]] = {"s": p["s"], "dir": dr, "t": a["hm"], "px": px, "stop": px * (1 - dr * sst), "half": px * (1 + dr * shf), "hf": shf, "step": 1, "st": "open", "kind": "🔻" if dr < 0 else "🔺"}
                        self.sent[p["s"]] = True
        for k, m in self.mon.items():                                          # MONITORING - every alerted share, to its end
            if m["st"] in ("out", "closed") or k not in P or d not in P[k]:
                continue
            last = P[k][d]["rows"][-1]; px = last["c"]; dr = m["dir"]; mv = (px / m["px"] - 1) * dr; m["now"] = px; m["mv"] = round(mv * 100, 2)
            msg = None
            if (px - m["stop"]) * dr <= 0:
                m["st"] = "out"; msg = "❌ OUT %s %s · ₹%s · the stop (%s) - the move failed%s" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), "{:,.2f}".format(m["stop"]), " · half was booked" if m.get("halfd") else "")
            elif not m.get("halfd") and mv >= m.get("hf", HALF):
                m["halfd"] = True; m["stop"] = m["px"]; m["st"] = "half"
                msg = "✅ HALF OUT %s %s · ₹%s (+%.1f%%) · book half · the stop moves to your entry ₹%s - no loss from here" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), m.get("hf", HALF) * 100, "{:,.2f}".format(m["px"]))
            elif mv >= MORE * (m["step"] + 1):
                m["step"] = int(mv / MORE)
                msg = "📈 STILL GOING %s %s · ₹%s · %+.1f%% from the alert at %s" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), mv * 100, m["t"])
            elif hm >= "15:10":
                m["st"] = "closed"; msg = "⏹ 15:10 CLOSE %s %s · ₹%s · %+.1f%% from the alert at %s - not held overnight" % (k, "CE" if dr > 0 else "PE", "{:,.2f}".format(px), mv * 100, m["t"])
            if msg:
                out.append(msg)
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        json.dump({"t": time.time(), "at": n.strftime("%H:%M:%S"), "day": d, "mon": self.mon, "sec_sent": [list(x) for x in self.sec_sent],
                   "sectors": [{"hm": a["hm"], "name": a["name"], "dir": a["dir"], "mv": round(a["mv"] * 100, 2), "same": round(a["same"] * 100)} for a in M.sector_alerts(P, self.SECS, self.W, d, upto=hm, **self.secv())][-12:]},
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
PY_headsup
cat > $W/movescan.py <<'PY_movescan'
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


def sim(rest, P0, dr, st=0.0075, hf=0.015):
    """the share's % result of one trade: stop -st; at +hf (1.5%) half is booked and the stop goes to the entry; the rest out at 15:10"""
    half = None; stop = -st
    for x in rest:
        lo = ((x["l"] / P0 - 1) if dr > 0 else (1 - x["h"] / P0)); hi = ((x["h"] / P0 - 1) if dr > 0 else (1 - x["l"] / P0))
        if lo <= stop:
            return stop if half is None else (half + stop) / 2
        if half is None and hi >= hf:
            half, stop = hf, 0.0
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


def sector_alerts(P, SECS, W, d, upto="14:30", th=0.006, br=0.7, deeper=0.005, picks=3, top_only=False):
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
                if top_only and any(x[1] == dr and x[0] != name for x in last):   # v352: one sector a side a day - the first, strongest to qualify
                    continue
                if k in last and mv * dr < last[k] + deeper:
                    continue
                last[k] = mv * dr
                picks_ = sorted(cur, key=lambda c: -c[1] * dr)[:picks]
                out.append({"hm": hm, "name": name, "dir": dr, "mv": mv, "same": same, "n": len(cur),
                            "picks": [{"s": s, "rp": x, "px": c, "i": i, "pnl": sim(P[s][d]["rows"][i + 1:], c, dr, 0.025)} for s, x, c, i in picks_]})
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


SEC_VARIANTS = [{"th": th, "picks": pk, "top_only": to} for th in (0.006, 0.01) for pk in (2, 3) for to in (False, True)]


EXITS = [(st, hf) for st in (0.01, 0.015, 0.025) for hf in (0.015, 0.025)]   # v352b: the stop and the half-out target, tested WITH each entry


def sector_eval(P, SECS, W, days, v):
    """one entry setting, every exit: {(stop, half): result}. Entry = the close of the 5-min bar the alert fires on; out at the stop, half
    booked at +half and the stop to the entry, the rest out at 15:10; a bar touching both the stop and the target counts as the stop"""
    LOT = lots(); rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    acc = {e: {"tot": 0.0, "n": 0, "won": 0, "per": {}} for e in EXITS}
    for d in days:
        seen = set()
        for a in sector_alerts(P, SECS, W, d, th=v["th"], picks=v["picks"], top_only=v["top_only"]):
            if (a["name"], a["dir"]) in seen:
                continue
            seen.add((a["name"], a["dir"]))
            for p in a["picks"]:
                rest = P[p["s"]][d]["rows"][p["i"] + 1:]
                for e in EXITS:
                    r = sim(rest, p["px"], a["dir"], e[0], e[1]); x = rs(r, p["px"], p["s"]); A = acc[e]
                    A["tot"] += x; A["n"] += 1; A["won"] += r > 0; A["per"][d] = A["per"].get(d, 0) + x
    return {e: {"tot": A["tot"], "n": A["n"], "won": A["won"], "green": sum(1 for x in A["per"].values() if x > 0), "days": len(days),
                "per_day": A["n"] / max(1, len(days))} for e, A in acc.items()}


def sector_pick(P, SECS, W, days):
    say(""); say("🔻🔺 SECTOR ALERTS - entry AND exit tried together on %d days (choose: at most 10 trades a day, then the most green days, then the most ₹)" % len(days))
    say("  each line = one entry setting with the stop / half-out that worked best for it")
    best = None
    for v in SEC_VARIANTS:
        E = sector_eval(P, SECS, W, days, v)
        k_ = lambda e: (E[e]["per_day"] <= 10, E[e]["green"], E[e]["tot"]); ex = max(EXITS, key=k_); e = E[ex]
        say("  sector %.1f%%+ · %d shares · %-24s · stop %.1f%% · half out +%.1f%% → %4.1f trades a day · %d won of %d · %d of %d days green · ₹%s a day" % (
            v["th"] * 100, v["picks"], "one sector a side a day" if v["top_only"] else "every sector", ex[0] * 100, ex[1] * 100, e["per_day"], e["won"], e["n"],
            e["green"], e["days"], "{:,.0f}".format(e["tot"] / max(1, e["days"]))))
        if best is None or k_(ex) > best[0]:
            best = (k_(ex), v, ex, e)
    _, v, ex, e = best
    say("  CHOSEN: sector %.1f%%+, %d shares, %s · stop %.1f%% · half out at +%.1f%% · %d of %d days green, ₹%s a day" % (v["th"] * 100, v["picks"],
        "one sector a side a day" if v["top_only"] else "every sector", ex[0] * 100, ex[1] * 100, e["green"], e["days"], "{:,.0f}".format(e["tot"] / max(1, e["days"]))))
    try:
        json.dump({"sec": v, "exit": {"stop": ex[0], "half": ex[1]}, "at": dt.datetime.now(IST).strftime("%Y-%m-%d %H:%M"), "green": e["green"], "days": e["days"]},
                  open(os.path.join(D, "data", "headsup_cfg.json"), "w"))
    except Exception:
        pass
    return dict(v, stop=ex[0], half=ex[1])


def sector_report(P, SECS, W, days, v=None):
    v = v or {"th": 0.006, "picks": 3, "top_only": False}
    st, hf = v.get("stop", 0.025), v.get("half", 0.015)
    LOT = lots(); rs = lambda r, px, s: r * px * (LOT.get(s) or 0) * 0.5
    tot = n = won = 0; per = {}
    for d in days:
        A = sector_alerts(P, SECS, W, d, th=v["th"], picks=v["picks"], top_only=v["top_only"])
        seen = set()
        for a in A:
            a["first"] = (a["name"], a["dir"]) not in seen; seen.add((a["name"], a["dir"]))
            if not a["first"]:
                continue                                                   # a deeper move = an update on the same trade, not a new one
            for p in a["picks"]:
                p["pnl"] = sim(P[p["s"]][d]["rows"][p["i"] + 1:], p["px"], a["dir"], st, hf)
                x_ = rs(p["pnl"], p["px"], p["s"]); tot += x_; n += 1; won += p["pnl"] > 0; per[d] = per.get(d, 0) + x_
        if d == days[-1]:
            last = A
    say(""); say("🔻🔺 SECTOR ALERTS replayed with the CHOSEN set (sector %.1f%%+ one way, 70%%+ of its shares - its %d weakest / strongest; stop %.1f%%, half at +%.1f%%)" % (
        v["th"] * 100, v["picks"], st * 100, hf * 100))
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
    sector_report(P, SECS, W, sorted(fl), sector_pick(P, SECS, W, sorted(fl)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write("\n".join(L) + "\n")
    say(""); say("saved data/movescan.txt")


if __name__ == "__main__":
    main()
PY_movescan
cat > $W/missed.py <<'PY_missed'
#!/usr/bin/env python3
"""missed.py - READ ONLY (v352: a real CE/PE call apart from a news / list mention). TODAY'S MISSED MONEY (Rama, 16 Nov: "it was a good day - I missed them. Replay the shares it alerted LATE, the ones
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
                    rang.setdefault(s, []).append((h, side_of(sd)))
                else:
                    ev.setdefault(s, []).append((h, side_of(sd), tb))
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
cat > $W/loadtest.py <<'PY_loadtest'
#!/usr/bin/env python3
"""loadtest.py - READ ONLY. "MONEY LOADING BEFORE THE MOVE" - tested on GIR's own minute futures history (Rama, 16 Nov: "the build-up alert comes after
the move - and 10-15 minutes is also too late"). data/oihist/<day>.npz: per share, a row a minute: minute since 09:15, price, futures OI, volume,
buyers waiting, sellers waiting.
  a LOADING signal at minute m, window w (3 / 5 / 10 min): futures OI up k% (0.5 / 1.0 / 1.5) in w minutes while the price moved under 0.3% -
  the side from the order book (buyers 1.3x sellers -> CE, sellers 1.3x buyers -> PE), first signal per share per day, 09:20-14:30
  then: did the price go 1.5%+ that way (before 0.75% against)? the money (1 lot, an at-the-money option ~ half the rupee move, stop 2.5%, half at
  +1.5%, out 15:10)? and for the day's big movers (2.5%+): how many minutes BEFORE their move started did the signal come?
python3 loadtest.py [YYYY-MM-DD ...]   (no day: every day kept)   -> prints, saves data/loadtest.txt"""
import os, sys, glob, sqlite3, datetime as dt
D = os.path.dirname(os.path.abspath(__file__)); OD = os.path.join(D, "data", "oihist")
L = []
def say(s=""):
    L.append(s); print(s)
hmf = lambda m: "%02d:%02d" % ((555 + m) // 60, (555 + m) % 60)


def lots():
    try:
        c = sqlite3.connect("file:%s?mode=ro" % os.path.join(D, "chains.db"), uri=True, timeout=5)
        R = dict(c.execute("select sym, lot from fo_list").fetchall()); c.close(); return R
    except Exception:
        return {}


def load(day):
    import numpy as np
    z = np.load(os.path.join(OD, day + ".npz")); out = {}
    for s in z.files:
        a = z[s]
        if len(a) < 60:
            continue
        out[s] = {int(r[0]): (float(r[1]), float(r[2]), float(r[3]), float(r[4]), float(r[5])) for r in a}
    return out


def sim(seq, P0, dr, st=0.025):
    half = None; stop = -st
    for m, px in seq:
        x = (px / P0 - 1) * dr
        if x <= stop:
            return stop if half is None else (half + stop) / 2
        if half is None and x >= 0.015:
            half, stop = 0.015, 0.0
        if m >= 355:                                                           # 15:10
            return x if half is None else (half + x) / 2
    x = (seq[-1][1] / P0 - 1) * dr if seq else 0.0
    return x if half is None else (half + x) / 2


def signals(S, w, k):
    out = []
    for s, R in S.items():
        ms = sorted(R)
        for m in ms:
            if m < 5 or m > 315 or (m - w) not in R:
                continue
            px, oi, vol, b, sl = R[m]; px0, oi0 = R[m - w][0], R[m - w][1]
            if not oi0 or not px0 or not oi:
                continue
            doi = oi / oi0 - 1; dpx = px / px0 - 1
            if doi < k or abs(dpx) > 0.003:
                continue
            dr = 1 if b >= 1.3 * max(sl, 1) else -1 if sl >= 1.3 * max(b, 1) else 0
            if not dr:
                continue
            out.append({"s": s, "m": m, "dir": dr, "px": px, "doi": doi})
            break
    return out


def movers(S):
    out = {}
    for s, R in S.items():
        ms = sorted(R); o0 = R[ms[0]][0]
        if not o0:
            continue
        up = max(R[m][0] for m in ms) / o0 - 1; dn = 1 - min(R[m][0] for m in ms) / o0
        dr = 1 if up >= dn else -1; size = max(up, dn)
        if size >= 0.025:
            st = next((m for m in ms if (R[m][0] / o0 - 1) * dr >= 0.005), ms[0])
            out[s] = (dr, size, st)
    return out


def main():
    days = sys.argv[1:] or sorted(os.path.basename(f)[:10] for f in glob.glob(os.path.join(OD, "20??-??-??.npz")))
    LOT = lots()
    say("💰 MONEY LOADING BEFORE THE MOVE - tested on GIR's minute futures history · %d day(s): %s" % (len(days), ", ".join(days)))
    for day in days:
        try:
            S = load(day)
        except Exception as ex:
            say("  %s: not readable (%s)" % (day, ex)); continue
        S = {s: R for s, R in S.items() if not LOT or s in LOT}
        MV = movers(S)
        say(""); say("  %s · %d F&O shares · %d moved 2.5%%+" % (day, len(S), len(MV)))
        for w in (3, 5, 10):
            for k in (0.005, 0.01, 0.015):
                G = signals(S, w, k); tot = 0.0; hit = 0; lead = []
                for g in G:
                    R = S[g["s"]]; seq = [(m, R[m][0]) for m in sorted(R) if m > g["m"]]
                    p = sim(seq, g["px"], g["dir"]); tot += p * g["px"] * (LOT.get(g["s"]) or 0) * 0.5; hit += p > 0
                    mv = MV.get(g["s"])
                    if mv and mv[0] == g["dir"]:
                        lead.append(mv[2] - g["m"])
                before = sum(1 for x in lead if x >= 0)
                say("    %2d min · OI +%.1f%% · price flat → %3d signals · %3d won · ₹%9s · big movers caught: %d (%d BEFORE their move, median %s min)" % (
                    w, k * 100, len(G), hit, "{:,.0f}".format(tot), len(lead), before, sorted(lead)[len(lead) // 2] if lead else "—"))
    os.makedirs(os.path.join(D, "data"), exist_ok=True); open(os.path.join(D, "data", "loadtest.txt"), "w").write("\n".join(L) + "\n")
    say(""); say("saved data/loadtest.txt")


if __name__ == "__main__":
    main()
PY_loadtest
python3 -m py_compile $W/headsup.py $W/movescan.py $W/missed.py $W/loadtest.py || { echo "❌ did not compile - nothing changed"; exit 1; }
for f in headsup movescan missed loadtest; do [ -f $D/$f.py ] && cp $D/$f.py $D/$f.py.bak352; cp $W/$f.py $D/$f.py; done
echo "=== 1) the sector alerts: 8 settings on 25 days, chosen by the numbers (about 3 minutes)"
cd $D && timeout 600 python3 movescan.py 30 | sed -n '/SECTOR ALERTS - entry AND exit/,/CHOSEN/p'
echo "  saved for the live alerts: $(cat $D/data/headsup_cfg.json 2>/dev/null | cut -c1-120)"
systemctl restart gir-headsup; sleep 3; echo "  gir-headsup: $(systemctl is-active gir-headsup)"
echo "=== 2) money loading before the move (today's minute history)"
cd $D && timeout 300 python3 loadtest.py | grep -v "^saved"
echo "=== 3) today, honestly: a real CE/PE call vs a mention"
cd $D && timeout 400 python3 missed.py | tail -8
echo "✅ patch 352 done - the sector alerts use the chosen entry + stop + half-out from tomorrow 09:20. Undo: for f in headsup movescan missed; do cp $D/\$f.py.bak352 $D/\$f.py; done; systemctl restart gir-headsup"
