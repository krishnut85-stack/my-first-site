#!/bin/bash
# PATCH 277 - 🌪 BIG MOVERS IN THEIR OWN CHANNEL "GIR Bigmovers" (Rama, 14 Nov: "the alert should be different from all - a different way to identify
#   in the GIR page - I will make a Telegram channel GIR Bigmovers"). Friday's replay: GIR's first alert came a median 15 min after a move began,
#   the phone rang after 20 min with 86% of the move gone; 30 of 47 moves began at the open. The wind watcher (every 3 s from 09:15) now sends:
#     🌪 BIG MOVER ▲/▼ SYM - 0.8%+ in 3 min with NEW futures money its way and 3 of 4 wind (book · sector) · once a share-side in 30 min
#     🔄 TURN CE → PE / PE → CE (patch 276)
#   straight to GIR Bigmovers, with sound - its own look on GIR's page too (🌪 on the BIG MONEY strip, on the alert board). Until the channel is
#   set up they wait on the page (turns: quietly to the usual channel). Early signals: the card says so and gives the stop.
#   Tested: 5 + 7 + 8 cases. Restarts the wind watcher and the page server - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 276" $D/home.html && [ -f $D/windwatch.py ] || { echo "patch 276 first"; exit 1; }
F="windwatch.py home.html tg_lane_setup.py"
for f in $F; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-windwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live · 277: 🌪 BIG MOVERS to their own channel): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
GIR's engine already holds, second by second, every F&O share's price, its futures price + OPEN INTEREST and the ORDER BOOK (buyers / sellers
waiting) - but only the price reached the rest of GIR every second; the money and the book came through slower rounds (5-min candles, sweeps).
Patch 275 makes the engine write them every second (data/fut_live.json) and this watcher reads them every 3 s:
  price move in 3 min · futures OI change in 3 min (new money: long / short build-up · or forced out: short covering / long unwinding) ·
  buyers vs sellers waiting in the book · its sector moving the same way
  -> data/wind.json (the live picture - the MOVE / TRADE CARD reads it: seconds old instead of minutes)
  -> tomorrow.db wind_calls: every early wind signal (score 3 of 4+), so windscore.sh can measure it before it is allowed to ring
READ ONLY (no orders, nothing sent).   python3 windwatch.py run | show"""
import os, sys, json, time, sqlite3, collections, datetime as dt

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
IST = dt.timezone(dt.timedelta(hours=5, minutes=30))
EVERY, LOOK, KEEP = 3, 180, 900
PX_MIN, OI_MIN, BOOK_X, REPEAT_S = 0.5, 0.5, 1.5, 1800


def _load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None


def sectors_of():
    try:
        import sectors
        return sectors.load()
    except Exception:
        return {}


class Wind:
    def __init__(self, secmap=None):
        self.h = collections.defaultdict(lambda: collections.deque(maxlen=KEEP // EVERY + 5))
        self.sec = secmap if secmap is not None else sectors_of()
        self.of = {}
        for k, v in self.sec.items():
            for s in v:
                self.of.setdefault(s, k)
        self.said = {}

    def feed(self, t, q, f):
        """q: {sym: [px, chg%]} (quotes_live) · f: {sym: [fut px, fut OI, buy qty, sell qty]} (fut_live)"""
        for s, v in (q or {}).items():
            if not isinstance(v, (list, tuple)) or not v or not v[0]:
                continue
            x = (f or {}).get(s) or [None, None, 0, 0]
            self.h[s].append((t, float(v[0]), v[1] if len(v) > 1 else None, x[1], x[2] or 0, x[3] or 0))

    def _ago(self, s, t):
        d = self.h.get(s)
        if not d or len(d) < 2 or t - d[0][0] < LOOK * 0.8:
            return None, None
        old = next((r for r in d if r[0] >= t - LOOK), d[0])
        return old, d[-1]

    def read(self, t):
        """-> {sym: {dir, kind, px3, oi3, book, sec, sec_up, sec_dn, score}} for every share moving now"""
        mv = {}
        for s in list(self.h):
            old, new = self._ago(s, t)
            if not old or not old[1]:
                continue
            px3 = (new[1] / old[1] - 1) * 100
            oi3 = ((new[3] / old[3] - 1) * 100) if (new[3] and old[3]) else None
            book = (new[4] / new[5]) if (new[4] and new[5]) else None
            mv[s] = (px3, oi3, book, new)
        out = {}
        for s, (px3, oi3, book, new) in mv.items():
            d = 1 if px3 >= PX_MIN else -1 if px3 <= -PX_MIN else 0
            if not d:
                continue
            kind = "PRICE ONLY"
            if oi3 is not None and oi3 >= OI_MIN:
                kind = "LONG BUILD-UP" if d > 0 else "SHORT BUILD-UP"             # new money its way
            elif oi3 is not None and oi3 <= -OI_MIN:
                kind = "SHORT COVERING" if d > 0 else "LONG UNWINDING"            # the other side forced out
            sec = self.of.get(s)
            peers = [mv[p][0] for p in (self.sec.get(sec) or []) if p != s and p in mv]
            up, dn = sum(1 for x in peers if x > 0.2), sum(1 for x in peers if x < -0.2)
            sec_ok = bool(peers) and (up if d > 0 else dn) * 2 >= len(peers)
            book_ok = book is not None and (book >= BOOK_X if d > 0 else book <= 1 / BOOK_X)
            score = (abs(px3) >= 0.6) + (kind in ("LONG BUILD-UP", "SHORT BUILD-UP")) + book_ok + sec_ok
            out[s] = {"dir": d, "kind": kind, "px3": round(px3, 2), "oi3": None if oi3 is None else round(oi3, 2), "book": None if book is None else round(book, 2),
                      "sec": sec, "sec_up": up, "sec_dn": dn, "sec_n": len(peers), "score": int(score), "px": new[1], "chg": new[2]}
        return out

    def calls(self, t, W):
        """the early wind signals worth measuring: score 3+ of 4, once a share-side in 30 min"""
        out = []
        for s, w in W.items():
            k = (s, w["dir"])
            if w["score"] >= 3 and (k not in self.said or t - self.said[k] >= REPEAT_S):
                self.said[k] = t
                out.append((s, w))
        return out


def line(w, age=None):
    """the live words for the cards: 'LIVE 4 s ago: futures OI +1.4% in 3 min (new buyers) · buyers 2.1x sellers · its sector 4 of 5 up'"""
    if not w:
        return None
    d = w["dir"]
    k = {"LONG BUILD-UP": "new buyers", "SHORT BUILD-UP": "new sellers", "SHORT COVERING": "sellers forced out", "LONG UNWINDING": "buyers giving up"}.get(w["kind"])
    bits = ["price %+.1f%% in 3 min" % w["px3"]]
    if w.get("oi3") is not None:
        bits.append("futures OI %+.1f%%%s" % (w["oi3"], (" (%s)" % k) if k else ""))
    if w.get("book"):
        b = w["book"]
        bits.append(("buyers %.1fx sellers waiting" % b) if b >= 1 else ("sellers %.1fx buyers waiting" % (1 / b)))
    if w.get("sec") and w.get("sec_n"):
        bits.append("its sector %d of %d %s" % (w["sec_up"] if d > 0 else w["sec_dn"], w["sec_n"], "up" if d > 0 else "down"))
    return "LIVE%s: %s · wind %d of 4" % ((" %d s ago" % age) if age is not None else "", " · ".join(bits), w["score"])


# ---------------- patch 276: THE TURNS (Rama, 14 Nov: "for CE who is building, and from CE to PE who is pulling; for PE who is losing, and from PE to CE
# who is building - the option trader works both ways") ----------------
DAY_PX, DAY_OI, STEADY, TURN_S = 0.3, 0.5, 3, 1200
BASEF = os.path.join(BASE, "data", "wind_base.json")
CE_SIDE, PE_SIDE = ("LONG BUILD-UP", "SHORT COVERING"), ("SHORT BUILD-UP", "LONG UNWINDING")


def day_kind(chg, doi):
    """the day so far: price vs yesterday's close and futures OI vs the day's first reading"""
    if chg is None or doi is None or abs(chg) < DAY_PX or abs(doi) < DAY_OI:
        return None
    if chg > 0:
        return "LONG BUILD-UP" if doi > 0 else "SHORT COVERING"
    return "SHORT BUILD-UP" if doi > 0 else "LONG UNWINDING"


class Turns:
    """per share: the day's side and the live 3-min kind; a turn when the live kind holds for 3 readings (9 s) against the day's side"""
    def __init__(self, day):
        self.day = day
        b = _load(BASEF) or {}
        self.base = b.get("oi") if b.get("day") == day else {}
        self.streak, self.said, self.list = {}, {}, []

    def save(self):
        try:
            json.dump({"day": self.day, "oi": self.base}, open(BASEF + ".tmp", "w")); os.replace(BASEF + ".tmp", BASEF)
        except Exception:
            pass

    def step(self, t, hm, W, wind):
        """W: the Wind (its history) · wind: W.read(t) -> [new turns]"""
        new, changed = [], False
        for s, d in W.h.items():
            if not d:
                continue
            last = d[-1]
            if last[3] and s not in self.base:
                self.base[s] = last[3]; changed = True
        if changed:
            self.save()
        for s, w in wind.items():
            d = W.h.get(s)
            last = d[-1] if d else None
            doi = ((last[3] / self.base[s] - 1) * 100) if (last and last[3] and self.base.get(s)) else None
            dk = day_kind(last[2] if last else None, doi)
            w["day_kind"], w["day_oi"] = dk, None if doi is None else round(doi, 2)
            lk = w["kind"] if w.get("oi3") is not None and abs(w["oi3"]) >= OI_MIN and abs(w["px3"]) >= 0.4 else None
            prev = self.streak.get(s)
            self.streak[s] = (lk, (prev[1] + 1) if prev and prev[0] == lk else 1)
            if not lk or self.streak[s][1] < STEADY or not dk:
                continue
            ev = None
            if dk in CE_SIDE and lk == "LONG UNWINDING":
                ev = ("CE LEAVING", -1, "⚠ the CE side is leaving - buyers unwinding")
            elif dk in CE_SIDE and lk == "SHORT BUILD-UP":
                ev = ("CE → PE", -1, "🔄 TURNED CE → PE - new sellers coming in")
            elif dk in PE_SIDE and lk == "SHORT COVERING":
                ev = ("PE COVERING", 1, "⚠ the PE side is losing - sellers covering")
            elif dk in PE_SIDE and lk == "LONG BUILD-UP":
                ev = ("PE → CE", 1, "🔄 TURNED PE → CE - new buyers coming in")
            if not ev:
                continue
            k = (s, ev[0])
            if k in self.said and t - self.said[k] < TURN_S:
                continue
            self.said[k] = t
            x = {"t": hm, "ts": int(t), "s": s, "turn": ev[0], "dir": ev[1], "words": ev[2], "day_kind": dk, "day_oi": w["day_oi"], "kind": lk,
                 "px3": w["px3"], "oi3": w["oi3"], "book": w.get("book"), "px": w.get("px"), "chg": w.get("chg")}
            self.list.append(x); new.append(x)
            w["turn"] = ev[0]; w["turn_t"] = hm
        self.list = [x for x in self.list if t - x["ts"] < 3 * 3600][-60:]
        for x in self.list:                                            # keep the last turn on the share's live line
            if x["s"] in wind and "turn" not in wind[x["s"]]:
                wind[x["s"]]["turn"], wind[x["s"]]["turn_t"] = x["turn"], x["t"]
        return new


def turn_text(x):
    up = x["dir"] > 0
    was = (x["day_kind"] or "").lower()
    b = x.get("book")
    book = (" · buyers %.1fx sellers waiting" % b if b >= 1 else " · sellers %.1fx buyers waiting" % (1 / b)) if b else ""
    full = x["turn"] in ("CE → PE", "PE → CE")
    return "\n".join([
        "🔄 TURN %s %s · %s · %s" % ("▲" if up else "▼", x["s"], x["turn"], x["t"]),
        "the day so far: %s%s · now: %s - price %+.1f%% in 3 min, futures OI %+.1f%%%s" % (was, (" (futures OI %+.1f%% today)" % x["day_oi"]) if x.get("day_oi") is not None else "",
                                                                                   x["kind"].lower(), x["px3"], x["oi3"], book),
        ("for you: %s holders - protect it now (exit / tighten the stop) · the %s side now has the money - a trade only when GIR confirms" % ("PE" if up else "CE", "CE" if up else "PE")) if full else
        ("for you: %s holders - watch it closely; if it turns fully GIR says 🔄 TURNED" % ("PE" if up else "CE"))])


def turns_db(xs, day):
    try:
        c = db()
        c.execute("create table if not exists wind_turns(day text, t text, sym text, turn text, side text, day_kind text, kind text, px real, px3 real, oi3 real)")
        c.executemany("insert into wind_turns values (?,?,?,?,?,?,?,?,?,?)", [(day, x["t"], x["s"], x["turn"], "CE" if x["dir"] > 0 else "PE", x["day_kind"], x["kind"], x["px"], x["px3"], x["oi3"]) for x in xs])
        c.commit(); c.close()
    except Exception:
        pass


# ---------------- patch 277: 🌪 BIG MOVERS - their own Telegram channel "GIR Bigmovers" (Rama, 14 Nov) ----------------
BIG_PX, BIG_S = 0.8, 1800
ENVF = "/home/globalbot/.env"
_ENV = {"t": 0.0, "e": {}}


def env():
    """GIR's .env, read (never copied) once a minute - a channel set up later is picked up without a restart"""
    if time.time() - _ENV["t"] > 60:
        e = {}
        try:
            import re as _re
            for ln in open(ENVF):
                m = _re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", ln)
                if m:
                    e[m.group(1)] = m.group(2).strip("'\"")
        except Exception:
            pass
        _ENV.update({"t": time.time(), "e": e})
    return _ENV["e"]


def big_movers(t, wind, said):
    """the early, fast movers: 0.8%+ in 3 min with NEW futures money its way and 3 of 4 wind - once a share-side in 30 min"""
    out = []
    for s, w in wind.items():
        if w["score"] >= 3 and abs(w["px3"]) >= BIG_PX and w["kind"] in ("LONG BUILD-UP", "SHORT BUILD-UP"):
            k = (s, w["dir"])
            if k not in said or t - said[k] >= BIG_S:
                said[k] = t
                out.append((s, w))
    return out


def big_text(s, w, hm):
    up = w["dir"] > 0
    b = w.get("book")
    book = (" · buyers %.1fx sellers waiting" % b if b >= 1 else " · sellers %.1fx buyers waiting" % (1 / b)) if b else ""
    sec = (" · its sector %d of %d %s" % (w["sec_up"] if up else w["sec_dn"], w["sec_n"], "up" if up else "down")) if w.get("sec_n") else ""
    return "\n".join([
        "🌪 BIG MOVER %s %s · %s" % ("▲" if up else "▼", s, hm),
        "price %+.1f%% in 3 min (₹%s · %+.1f%% today) · futures OI %+.1f%% (%s)%s%s · wind %d/4" % (
            w["px3"], "{:,.2f}".format(w["px"]), w.get("chg") or 0, w.get("oi3") or 0, "new buyers" if up else "new sellers", book, sec, w["score"]),
        "%s side · early, not yet confirmed - wait for GIR's 🃏 card, or enter small with a tight stop (back %s ₹%s)" % (
            "CE" if up else "PE", "under" if up else "over", "{:,.2f}".format(w["px"] / (1 + w["px3"] / 100)))])


def _log(text):
    try:
        import opencall
        opencall.log_alert(text)
    except Exception:
        pass


def send_big(text, log=True):
    """straight to GIR Bigmovers (TG_CHAT_BIGMOVERS), with sound - and onto GIR's page; False when the channel is not set up yet"""
    e = env()
    chat, tok = e.get("TG_CHAT_BIGMOVERS"), e.get("TELEGRAM_TOKEN") or e.get("TELEGRAM_BOT_TOKEN") or os.environ.get("TELEGRAM_TOKEN")
    if not (chat and tok):
        if log:
            _log(text)
        return False
    _log(text)
    try:
        import requests
        a, b = (str(chat).rsplit(":", 1) if ":" in str(chat) else (str(chat), None))
        d = {"chat_id": a, "text": text[:4000], "disable_web_page_preview": "true"}
        if b and b.isdigit():
            d["message_thread_id"] = b
        return requests.post("https://api.telegram.org/bot%s/sendMessage" % tok, data=d, timeout=15).ok
    except Exception:
        return False


def db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists wind_calls(day text, t text, sym text, side text, kind text, px real, px3 real, oi3 real, book real, sec text, score int)")
    return c


def run():
    W = Wind()
    TU = Turns(str(dt.datetime.now(IST).date()))
    last_q = 0.0
    sent = {"day": None, "n": 0}
    bsaid, BL = {}, []
    while True:
        now = dt.datetime.now(IST); hm = now.strftime("%H:%M")
        if now.weekday() > 4 or not ("09:15" <= hm <= "15:30"):
            if W.h:
                W = Wind()
            if TU.day != str(now.date()):
                TU = Turns(str(now.date()))
            time.sleep(20); continue
        try:
            Q = _load(os.path.join(BASE, "quotes_live.json")) or {}
            F = _load(os.path.join(BASE, "data", "fut_live.json")) or {}
            t = time.time()
            if Q.get("t") and Q["t"] != last_q and t - Q["t"] < 30:
                last_q = Q["t"]
                W.feed(t, Q.get("q"), F.get("f") if F.get("t") and t - F["t"] < 30 else {})
                cur = W.read(t)
                NT = TU.step(t, now.strftime("%H:%M:%S"), W, cur)          # patch 276: the turns
                p = os.path.join(BASE, "data", "wind.json")
                BG = big_movers(t, cur, bsaid)                                   # patch 277: 🌪 BIG MOVERS
                for s_, w_ in BG:
                    BL.append({"t": now.strftime("%H:%M:%S"), "ts": int(t), "s": s_, "dir": w_["dir"], "px3": w_["px3"], "oi3": w_["oi3"], "score": w_["score"]})
                    send_big(big_text(s_, w_, now.strftime("%H:%M:%S")))
                BL[:] = [x for x in BL if t - x["ts"] < 3 * 3600][-40:]
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "s": cur, "turns": TU.list[-40:], "big": BL[-40:]}, open(p + ".tmp", "w"), separators=(",", ":")); os.replace(p + ".tmp", p)
                C = W.calls(t, cur)
                if C:
                    c = db()
                    c.executemany("insert into wind_calls values (?,?,?,?,?,?,?,?,?,?,?)", [(str(now.date()), now.strftime("%H:%M:%S"), s, "CE" if w["dir"] > 0 else "PE",
                                  w["kind"], w["px"], w["px3"], w["oi3"], w["book"], w["sec"], w["score"]) for s, w in C])
                    c.commit(); c.close()
                if NT:
                    turns_db(NT, str(now.date()))
                    if sent["day"] != str(now.date()):
                        sent.update({"day": str(now.date()), "n": 0})
                    for x in NT:                                              # a FULL turn: to GIR Bigmovers (patch 277), else quietly to the usual channel
                        if x["turn"] in ("CE → PE", "PE → CE") and sent["n"] < 40:
                            sent["n"] += 1
                            if not send_big(turn_text(x), log=False):
                                try:
                                    import opencall
                                    opencall.send_tg(turn_text(x))
                                except Exception as ex:
                                    print("send: %s" % str(ex)[:80], flush=True)
        except Exception as ex:
            print("%s %s" % (hm, str(ex)[:120]), flush=True); time.sleep(5)
        time.sleep(EVERY)


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"]:
        run()
    else:
        j = _load(os.path.join(BASE, "data", "wind.json")) or {}
        age = time.time() - (j.get("t") or 0)
        print("wind.json: %s · futures data %s" % (("%.0f s old" % age) if j else "not written yet (from 09:15 on a trading day)", "in" if j.get("fut") else "not in yet"))
        for s, w in sorted((j.get("s") or {}).items(), key=lambda x: -x[1]["score"])[:15]:
            print("  %-11s %s" % (s, line(w)))
PY_WW
cat > $W/p277_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p277_patch.py - patch 277: the GIR Bigmovers lane in tg_lane_setup.py + 🌪 BIG MOVERS on the BIG MONEY strip.  python3 p277_patch.py DIR"""
import os, sys
D = sys.argv[1]
def edit(f, pairs, need=True):
    p = os.path.join(D, f)
    if not os.path.exists(p):
        if need:
            print("❌ %s missing" % f); sys.exit(1)
        print("  %s: not here - skipped" % f); return
    s = open(p, encoding="utf-8").read()
    if "patch 277" in s:
        print("  %s: patch 277 - already in" % f); return
    for o, n, tag in pairs:
        if s.count(o) != 1:
            print("❌ %s: anchor for '%s' found %d times" % (f, tag, s.count(o))); sys.exit(1)
        s = s.replace(o, n); print("  %s: %s" % (f, tag))
    open(p, "w", encoding="utf-8").write(s)
L = '''         "moves": ("TG_CHAT_GIRMOVES", "GIR Moves & News", "🚀 RUNNING from 1% · ⚡ SPEED · 🌅 GAP · 📰 news · 📊 news reaction")}'''
edit("tg_lane_setup.py", [(L, '''         "moves": ("TG_CHAT_GIRMOVES", "GIR Moves & News", "🚀 RUNNING from 1% · ⚡ SPEED · 🌅 GAP · 📰 news · 📊 news reaction"),
         "bigmovers": ("TG_CHAT_BIGMOVERS", "GIR Bigmovers", "🌪 BIG MOVER (0.8%+ in 3 min with new futures money) · 🔄 TURN CE → PE / PE → CE")}   # patch 277''',
                           "a 4th channel: GIR Bigmovers (python3 tg_lane_setup.py bigmovers @link)")])
edit("home.html", [("const TS=(WIND.turns||[]).slice().reverse().slice(0,10);", "const TS=(WIND.turns||[]).slice().reverse().slice(0,10), BG=(WIND.big||[]).slice().reverse().slice(0,10);   /* patch 277 */", "the big movers' list"),
                   ("· <b>🔄 TURNS</b> ${TS.length?", "· <b>🌪 BIG MOVERS</b> ${BG.length?BG.map(x=>`<span class=\"k\" onclick=\"mkOpen('${esc(x.s)}')\"><b class=\"${x.dir>0?\"pu\":\"pd\"}\">${x.dir>0?\"▲\":\"▼\"} ${esc(x.s)}</b> <span class=\"dim\">${esc(x.t.slice(0,5))}</span></span>`).join(\" · \"):'<span class=\"dim\">none yet</span>'} · <b>🔄 TURNS</b> ${TS.length?", "🌪 BIG MOVERS on the BIG MONEY strip")])
print("patch 277 in")
PY_PATCH
cat > $W/p277test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p277test.py - 🌪 BIG MOVERS (made-up readings, temp folder, nothing sent).  python3 p277test.py WORK"""
import os, sys, json, shutil, tempfile
WK = os.path.abspath(sys.argv[1]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
WW.ENVF = os.path.join(T, "no.env")
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
W = {"POLICYBZR": {"dir": 1, "kind": "LONG BUILD-UP", "px3": 1.1, "oi3": 1.6, "book": 2.3, "score": 4, "px": 1049.0, "chg": 3.2, "sec_up": 3, "sec_dn": 0, "sec_n": 4},
     "SLOW": {"dir": 1, "kind": "LONG BUILD-UP", "px3": 0.6, "oi3": 1.0, "book": 2.0, "score": 4, "px": 100.0, "chg": 1.0, "sec_up": 1, "sec_dn": 0, "sec_n": 1},
     "FORCED": {"dir": 1, "kind": "SHORT COVERING", "px3": 1.4, "oi3": -2.0, "book": 2.0, "score": 3, "px": 200.0, "chg": 2.0, "sec_up": 1, "sec_dn": 0, "sec_n": 1},
     "WEAK": {"dir": -1, "kind": "SHORT BUILD-UP", "px3": -0.9, "oi3": 1.0, "book": None, "score": 2, "px": 50.0, "chg": -1.0, "sec_up": 0, "sec_dn": 0, "sec_n": 0}}
said = {}
B = WW.big_movers(1_000_000, W, said)
chk("a big mover = 0.8%+ in 3 min with NEW futures money its way and 3 of 4 wind (POLICYBZR) - not a slow one, not sellers forced out, not a weak one",
    [s for s, _ in B] == ["POLICYBZR"], B)
chk("once a share-side in 30 min", WW.big_movers(1_000_000 + 600, W, said) == [] and [s for s, _ in WW.big_movers(1_000_000 + 1900, W, said)] == ["POLICYBZR"])
tx = WW.big_text("POLICYBZR", W["POLICYBZR"], "09:19:42")
print("\n" + tx + "\n")
chk("its own look: '🌪 BIG MOVER ▲ POLICYBZR' · the move, the new money, the book, the sector · CE side · early - the stop", tx.startswith("🌪 BIG MOVER ▲ POLICYBZR · 09:19:42")
    and "price +1.1% in 3 min (₹1,049.00 · +3.2% today) · futures OI +1.6% (new buyers) · buyers 2.3x sellers waiting · its sector 3 of 4 up · wind 4/4" in tx and "CE side · early, not yet confirmed" in tx, tx)
chk("the channel not set up yet: nothing sent (and nothing breaks)", WW.send_big(tx) is False)
open(WW.ENVF, "w").write("TG_CHAT_BIGMOVERS=-1001234\nTELEGRAM_TOKEN=x\n"); WW._ENV["t"] = 0
chk("the channel is read from .env (read, never copied) - set up later, no restart", WW.env().get("TG_CHAT_BIGMOVERS") == "-1001234")
print("BIG MOVERS test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p277_patch.py $D || back
cd $D && python3 -m py_compile windwatch.py tg_lane_setup.py || back
echo "=== test"
python3 $W/p277test.py $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-windwatch gir-dash; sleep 5
echo "  gir-windwatch: $(systemctl is-active gir-windwatch) · gir-dash: $(systemctl is-active gir-dash)"
echo "✅ patch 277 done - 🌪 BIG MOVERS and 🔄 TURNS go to GIR Bigmovers once the channel is set up:"
echo "   1) Telegram: create the channel GIR Bigmovers, add GIR's bot as an admin, give it a public link for a moment (yours: girbigmovers)"
echo "   2) here:     python3 $D/tg_lane_setup.py bigmovers @girbigmovers      (a test message arrives there; no restart)"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-windwatch gir-dash"
