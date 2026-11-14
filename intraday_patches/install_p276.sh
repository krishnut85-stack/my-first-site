#!/bin/bash
# PATCH 276 - BIG MONEY · LIVE: THE TURNS, BOTH WAYS (Rama, 14 Nov: "for CE who is building, and from CE to PE who is pulling; for PE who is losing,
#   and from PE to CE who is building - the option trader works both ways; this page should update lightning fast and give me an update").
#   windwatch (every 3 s) compares each share's side for the DAY (price vs yesterday + futures OI vs the day's first reading) with the LAST 3 MIN:
#     CE side (long build-up / short covering) -> ⚠ long unwinding (CE buyers leaving) -> 🔄 short build-up = CE → PE
#     PE side (short build-up / long unwinding) -> ⚠ short covering (PE sellers covering) -> 🔄 long build-up = PE → CE
#   (the live kind must hold 9 s; once a share-turn in 20 min) · BIG MONEY: a LIVE · 3 s column on every row + a 🔄 TURNS strip, refreshed every 3 s
#   · a full turn (🔄 CE → PE / PE → CE) comes to Telegram QUIETLY (no ring until the scorecard proves it) · a ±40% one-day futures OI is marked ⚠ check.
#   Tested: 7 cases + the page in a browser. Restarts the page server and the wind watcher - after 15:35 on a trading day (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 275" $D/movecard.py && [ -f $D/windwatch.py ] && grep -q "patch 265" $D/dashserve.py || { echo "patch 275 (and 265) first"; exit 1; }
F="windwatch.py dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash gir-windwatch 2>/dev/null; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/windwatch.py <<'PY_WW'
#!/usr/bin/env python3
"""windwatch.py - patch 275 (+ 276: the TURNS - CE -> PE and PE -> CE, live): 🌬 THE WIND, every 3 seconds (Rama, 14 Nov: "you have to find a way to increase the speed of the data").
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


def db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists wind_calls(day text, t text, sym text, side text, kind text, px real, px3 real, oi3 real, book real, sec text, score int)")
    return c


def run():
    W = Wind()
    TU = Turns(str(dt.datetime.now(IST).date()))
    last_q = 0.0
    sent = {"day": None, "n": 0}
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
                json.dump({"t": round(t, 1), "fut": bool(F.get("f")), "s": cur, "turns": TU.list[-40:]}, open(p + ".tmp", "w"), separators=(",", ":")); os.replace(p + ".tmp", p)
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
                    for x in NT:                                              # a quiet Telegram update for a FULL turn (no ring until it is scored)
                        if x["turn"] in ("CE → PE", "PE → CE") and sent["n"] < 40:
                            try:
                                import opencall
                                opencall.send_tg(turn_text(x)); sent["n"] += 1
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
cat > $W/p276_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p276_patch.py - patch 276: GET /wind (dashserve.py) + BIG MONEY · LIVE (home.html).  python3 p276_patch.py DIR JS CSS"""
import os, sys
D = sys.argv[1]; JS = open(sys.argv[2], encoding="utf-8").read(); CSS = open(sys.argv[3], encoding="utf-8").read()
def edit(f, pairs):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if "patch 276" in s:
        print("  %s: patch 276 - already in" % f); return
    for o, n, tag in pairs:
        if s.count(o) != 1:
            print("❌ %s: anchor for '%s' found %d times" % (f, tag, s.count(o))); sys.exit(1)
        s = s.replace(o, n); print("  %s: %s" % (f, tag))
    open(p, "w", encoding="utf-8").write(s)
G = '''            if u.path == "/mypnl":                    # patch 265: MY P&L - today's ticks from the account, the days, the statement'''
edit("dashserve.py", [(G, '''            if u.path == "/wind":                     # patch 276: the live wind + the turns (windwatch.py, every 3 s)
                try:
                    body_ = open(os.path.join(BASE, "data", "wind.json"), "rb").read()
                except Exception:
                    body_ = b'{"t": 0, "s": {}, "turns": []}'
                return self.send(200, body_, "application/json; charset=utf-8")
''' + G, "GET /wind")])
edit("home.html", [("</style>", CSS + "</style>", "the LIVE look"), ("let MFCAP=0;   /* patch 174 */", JS + "let MFCAP=0;   /* patch 174 */", "BIG MONEY · LIVE every 3 s: the side now and the TURNS")])
print("patch 276 in")
PY_PATCH
cat > $W/page276.js <<'PY_JS276'
/* patch 276: BIG MONEY · LIVE - every 3 s from the engine's ticks (windwatch): each share's side NOW and the TURNS (CE → PE · PE → CE) */
let WIND=null, WINDT=0;
async function pullWind(){ try{ const r=await fetch("wind?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ WIND=await r.json(); WINDT=Date.now(); windPaint(); } }catch(e){} }
const windKW={"LONG BUILD-UP":["new buyers","pu"],"SHORT COVERING":["sellers forced out","pu"],"SHORT BUILD-UP":["new sellers","pd"],"LONG UNWINDING":["buyers giving up","pd"],"PRICE ONLY":["price only","dim"]};
function windCell(w){ if(!w) return '<span class="dim">quiet</span>';
  const k=windKW[w.kind]||[w.kind,"dim"], a=w.dir>0?"▲":"▼";
  const t=w.turn?` <b class="${/→ CE|COVERING/.test(w.turn)?"pu":"pd"} wturn">🔄 ${esc(w.turn)} ${esc((w.turn_t||"").slice(0,5))}</b>`:"";
  return `<b class="${k[1]}">${a} ${esc(w.kind.toLowerCase())}</b> <span class="dim">${w.px3>0?"+":""}${w.px3}% 3m${w.oi3!=null?` · OI ${w.oi3>0?"+":""}${w.oi3}%`:""}${w.book?` · ${w.book>=1?"buyers "+w.book.toFixed(1)+"×":"sellers "+(1/w.book).toFixed(1)+"×"}`:""} · ${w.score}/4</span>${t}`; }
function windPaint(){ const el=$("mk-lnk"); if(!el||!WIND) return; const S=WIND.s||{}, age=Math.max(0,Math.round(Date.now()/1000-(WIND.t||0)));
  const live=age<60;
  let bar=el.querySelector(".wbar"); if(!bar){ bar=document.createElement("div"); bar.className="wbar"; el.insertBefore(bar,el.firstChild); }
  const TS=(WIND.turns||[]).slice().reverse().slice(0,10);
  bar.innerHTML=`<b>🌬 LIVE</b> <span class="dim">${live?`every 3 s · ${age}s ago`:"from 09:15 on a trading day (the engine's own ticks)"}</span> · <b>🔄 TURNS</b> ${TS.length?TS.map(x=>`<span class="k" onclick="mkOpen('${esc(x.s)}')"><b class="${x.dir>0?"pu":"pd"}">${esc(x.s)} ${esc(x.turn)}</b> <span class="dim">${esc(x.t.slice(0,5))}</span></span>`).join(" · "):'<span class="dim">none yet</span>'}
    <div class="dim" style="margin-top:2px">CE side: long build-up (new buyers) → ⚠ long unwinding (buyers leaving) → 🔄 short build-up = CE → PE · PE side: short build-up (new sellers) → ⚠ short covering (sellers covering) → 🔄 long build-up = PE → CE</div>`;
  const tb=el.querySelector("table"); if(!tb) return;
  const hr=tb.querySelector("tr"); if(hr&&!hr.querySelector(".wth")){ const th=document.createElement("th"); th.className="wth"; th.textContent="LIVE · 3 s"; hr.appendChild(th); }
  tb.querySelectorAll("tr.k").forEach(tr=>{ const m=/mkOpen\('([^']+)'\)/.exec(tr.getAttribute("onclick")||""); if(!m) return;
    let td=tr.querySelector("td.wtd"); if(!td){ td=document.createElement("td"); td.className="wtd"; tr.appendChild(td); }
    const h=live?windCell(S[m[1]]):'<span class="dim">—</span>'; if(td._h!==h){ td._h=h; td.innerHTML=h; }
    const oi=tr.children[4]; if(oi&&!oi._w){ const v=parseFloat((oi.textContent||"").replace("+","")); if(Math.abs(v)>=40){ oi._w=1; oi.title="a ±40% futures OI change in one day is almost always a data problem (contract roll / lot change) - not trusted"; oi.innerHTML+=' <span class="am">⚠ check</span>'; } } }); }
{ const dl2_=drawLink; drawLink=function(){ dl2_(); try{ windPaint(); }catch(e){} }; }
setInterval(()=>{ if(typeof VIEW!=="undefined"&&VIEW==="market"&&MKSUB==="big"&&!document.hidden) pullWind(); },3000);
PY_JS276
cat > $W/page276.css <<'PY_CSS276'
/* patch 276: BIG MONEY · LIVE */
#mk-lnk .wbar{padding:6px 10px;margin:0 0 6px;border:1px solid var(--line2);border-left:3px solid var(--amber);border-radius:6px;background:var(--panel2);font:500 12px/1.5 var(--ui)}
#mk-lnk .wbar .k{cursor:pointer}
#mk-lnk td.wtd{white-space:nowrap;font-size:12px}
#mk-lnk .wturn{margin-left:6px;padding:0 5px;border:1px solid currentColor;border-radius:4px}
PY_CSS276
cat > $W/p276test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p276test.py - the TURNS live (made-up ticks, temp copies, nothing sent).  python3 p276test.py DIR WORK"""
import os, sys, json, types, shutil, tempfile
SRC, WK = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]); T = tempfile.mkdtemp(); os.makedirs(os.path.join(T, "data"))
shutil.copy(os.path.join(WK, "windwatch.py"), T)
if os.path.exists(os.path.join(SRC, "alertword.py")):
    shutil.copy(os.path.join(SRC, "alertword.py"), T)
sys.path.insert(0, T); os.chdir(T)
import windwatch as WW
OK = []
def chk(n, c, got=""):
    OK.append(bool(c)); print("  %s %s%s" % ("✅" if c else "❌", n, "" if c else "   got: %s" % str(got)[:400]))
def play(phases, pc=99.0):
    W, TU, ev = WW.Wind({}), WW.Turns("2026-11-16"), []
    t, px, oi = 1_000_000.0, None, None
    for (p1, o1, mins) in phases:
        n = int(mins * 20)
        p0, o0 = (px if px is not None else p1), (oi if oi is not None else o1)
        for i in range(1, n + 1):
            t += 3; px = p0 + (p1 - p0) * i / n; oi = o0 + (o1 - o0) * i / n
            W.feed(t, {"AAA": [px, (px / pc - 1) * 100]}, {"AAA": [px, oi, 50000, 50000]})
            cur = W.read(t)
            for x in TU.step(t, "%05d" % i, W, cur):
                ev.append(x["turn"])
    return ev, TU
ev, TU = play([(100.0, 1_000_000, 1), (101.5, 1_030_000, 5), (100.6, 1_015_000, 4), (99.8, 1_045_000, 5)])
chk("CE side: the day is a long build-up · then buyers leave (long unwinding) · then new sellers (short build-up)", ev[:2] == ["CE LEAVING", "CE → PE"], ev)
ev2, _ = play([(100.0, 1_000_000, 1), (98.5, 1_030_000, 5), (99.4, 1_015_000, 4), (100.2, 1_045_000, 5)], pc=100.8)
chk("PE side: the day is a short build-up · then sellers cover (short covering) · then new buyers (long build-up)", ev2[:2] == ["PE COVERING", "PE → CE"], ev2)
ev3, _ = play([(100.0, 1_000_000, 1), (101.0, 1_020_000, 5), (101.6, 1_040_000, 6)])
chk("a share that keeps going its way (long build-up all day): no turn", ev3 == [], ev3)
ev4, _ = play([(100.0, 1_000_000, 1), (101.0, 1_020_000, 5), (100.6, 1_020_000, 4)])
chk("a dip with no futures money moving: no turn (the price alone is not a turn)", ev4 == [], ev4)
x = {"t": "10:42:07", "s": "HINDALCO", "turn": "CE → PE", "dir": -1, "day_kind": "LONG BUILD-UP", "day_oi": 3.1, "kind": "SHORT BUILD-UP", "px3": -0.8, "oi3": 1.2, "book": 0.42}
tx = WW.turn_text(x)
print("\n" + tx + "\n")
chk("the update: '🔄 TURN ▼ HINDALCO · CE → PE' · the day so far · now · for you (CE holders protect it)", tx.startswith("🔄 TURN ▼ HINDALCO · CE → PE · 10:42:07") and "the day so far: long build-up (futures OI +3.1% today)" in tx
    and "now: short build-up - price -0.8% in 3 min, futures OI +1.2% · sellers 2.4x buyers waiting" in tx and "CE holders - protect it now" in tx, tx)
if os.path.exists("alertword.py"):
    import alertword as A
    chk("on Telegram it comes quietly - no ring until the scorecard proves it (tier: %s)" % A.tier(tx), A.tier(tx) == "read", A.tier(tx))
w = {"AAA": {"dir": -1, "kind": "SHORT BUILD-UP", "px3": -0.8, "oi3": 1.2, "score": 3}}
TU.list = [{"t": "10:42:07", "ts": 1_000_000, "s": "AAA", "turn": "CE → PE", "dir": -1}]
for s in w:
    if "turn" not in w[s]:
        w[s]["turn"] = TU.list[0]["turn"]
chk("the share's live line keeps its last turn for the page", w["AAA"]["turn"] == "CE → PE")
print("THE TURNS test: %d of %d passed" % (sum(OK), len(OK)))
shutil.rmtree(T, ignore_errors=True)
sys.exit(0 if all(OK) else 1)
PY_TEST
cp $W/windwatch.py $D/windwatch.py
python3 $W/p276_patch.py $D $W/page276.js $W/page276.css || back
cd $D && python3 -m py_compile windwatch.py dashserve.py || back
echo "=== test"
python3 $W/p276test.py $D $W > $W/t.out 2>&1; RC=$?; cat $W/t.out; [ $RC -eq 0 ] || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
chown --reference=$D $D/windwatch.py 2>/dev/null
systemctl restart gir-dash gir-windwatch; sleep 5
echo "  gir-dash: $(systemctl is-active gir-dash) · gir-windwatch: $(systemctl is-active gir-windwatch)"
echo "✅ patch 276 done - GIR → B BIG MONEY (Ctrl + Shift + R): a LIVE · 3 s column and the 🔄 TURNS strip, from Monday 09:15; full turns come to Telegram quietly."
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash gir-windwatch"
