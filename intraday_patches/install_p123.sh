#!/bin/bash
# PATCH 123 - OI BUILD-UP ALERTS TO YOU + 📊 NEWS REACTION (on top of patch 122).
#   - the OI SCENARIO agent reads every F&O share's live strikes every 5 seconds, but its lines reached GIR Box Picks only
#     on a BUY (the rest went silently to GIR Intraday). Now every acting OI build-up goes to Box Picks the moment it is new
#     (🧩 ... with CE / PE), rings when it has a side, shows on the GIR alert bar and counts as 🔭 OI on the ⚡ EARLY board
#     (data/scn_config.json box_when = ALL; "WATCH" or "BUY" puts it back)
#   - 📊 NEWS REACTION: from now on every news line - the share, NIFTY and BANKNIFTY at the moment it came, then after
#     5 / 15 / 60 minutes, by the close and the next close - on the NEWS screen (key 6), and a 15:45 summary to Box Picks
#   scenarios.py, alertword.py, dashserve.py (exact anchors) · home.html · data/scn_config.json.
#   Restarts gir-desk, gir-intraday, gir-newsroom, gir-exchange, gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g123; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p123.sh now"; exit 1; fi
grep -q "patch 122" $D/nsextra.py 2>/dev/null || { echo "patch 122 is not installed yet - paste patch 122 first"; exit 1; }
grep -q "def react_tick" $D/dashserve.py && { echo "patch 123 is already installed"; exit 1; }
F="scenarios.py alertword.py dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
[ -f $D/data/scn_config.json ] && cp $D/data/scn_config.json $D/data/scn_config.json.bak$TS
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; if [ -f $D/data/scn_config.json.bak$TS ]; then cp $D/data/scn_config.json.bak$TS $D/data/scn_config.json; else rm -f $D/data/scn_config.json; fi
         rm -f $D/p123test.py; systemctl restart gir-desk gir-intraday gir-newsroom gir-exchange gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p123_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p123_patch.py - PATCH 123:
  1. OI build-up alerts to GIR Box Picks: the OI SCENARIO agent reads every share's pinned strikes every 5 seconds, but
     its lines went to Box Picks only on a BUY (and the cautious ones never) - now every acting scenario goes, the moment it
     is new (data/scn_config.json box_when = ALL); a line with a CE / PE side rings; it counts as 🔭 OI on the ⚡ EARLY board
  2. 📊 NEWS REACTION (dashserve.py): every news line from now on - the share, NIFTY and BANKNIFTY at the moment it came,
     after 5 / 15 / 60 min, by the close and the next close; /react for the NEWS screen; a 15:45 summary to Box Picks
Usage: python3 p123_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os, json

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
SRV = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "react_srv.py"), encoding="utf-8").read()
EDITS = {
    "scenarios.py": [
        ('''        box = acting and not notes and (word == "BUY" or cfg.get("box_when") == "WATCH")
''', '''        box = acting and ((not notes and (word == "BUY" or cfg.get("box_when") in ("WATCH", "ALL"))) or cfg.get("box_when") == "ALL")   # patch 123: ALL = every acting scenario
'''),
    ],
    "alertword.py": [
        ('''    if k == "📰":''', '''    if k == "🧩":                                                # patch 123: an OI build-up with a side rings (something is happening)
        return "move" if re.search(r"[▲▼]", H2.split("·")[0]) else "read"
    if k == "📰":'''),
    ],
    "dashserve.py": [
        ('''_NMK = {"t": 0.0, "v": {}}
''', SRV + '''

_NMK = {"t": 0.0, "v": {}}
'''),
        ('''    if kind == "🔭":
        return "oi", "early OI", None
''', '''    if kind == "🧩":                                     # patch 123: the OI scenario agent's build-up lines
        return "oi", "OI build-up", None
    if kind == "🔭":
        return "oi", "early OI", None
'''),
        ('''        try:
            nifty_tick()                                          # patch 120: NIFTY's 1-minute candles
        except Exception as ex:
            print("nifty 1m:", str(ex)[:80])
''', '''        try:
            nifty_tick()                                          # patch 120: NIFTY's 1-minute candles
        except Exception as ex:
            print("nifty 1m:", str(ex)[:80])
        try:
            react_tick(); react_summary()                         # patch 123: 📊 the news reaction
        except Exception as ex:
            print("news reaction:", str(ex)[:80])
'''),
        ('''            if u.path == "/early":                    # ⚡ EARLY (patch 119)
''', '''            if u.path == "/react":                    # 📊 NEWS REACTION (patch 123)
                return self.send(200, json.dumps(react((parse_qs(u.query).get("day") or [None])[0]), ensure_ascii=False, default=str), "application/json; charset=utf-8")
            if u.path == "/early":                    # ⚡ EARLY (patch 119)
'''),
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
cp = os.path.join(D, "data", "scn_config.json")
cfg = {}
try:
    cfg = json.load(open(cp)) or {}
except Exception:
    pass
cfg["box_when"] = "ALL"
json.dump(cfg, open(cp, "w"))
print("scenarios.py + data/scn_config.json: every OI build-up to Box Picks · alertword.py: 🧩 with a side rings · dashserve.py: 📊 news reaction")
PY_PATCH
cat > $W/react_srv.py <<'PY_SRV'

# ---------- patch 123: 📊 NEWS REACTION - every news line from now on, and what the share, NIFTY and BANKNIFTY did ----------
_RX = {"rowid": None, "summary": None}
RX_KINDS = ("📰", "🚨", "📄", "🏛", "⚡")
RX_H = (("5", 5), ("15", 15), ("60", 60))


def _rx_db():
    c = sqlite3.connect(os.path.join(BASE, "tomorrow.db"), timeout=10)
    c.execute("create table if not exists news_react(id integer primary key, day text, t text, sym text, kind text, lvl text, side text, head text,"
              " ah int, p0 real, n0 real, b0 real, p5 real, n5 real, b5 real, p15 real, n15 real, b15 real, p60 real, n60 real, b60 real,"
              " pc real, nc real, bc real, pn real, nn real, bn real, nday text, unique(day, t, sym, head))")
    return c


def _rx_now():
    """(share prices, NIFTY, BANKNIFTY) now, or None when the market is not live"""
    q = quotes_live()
    if not q:
        return None
    qq = q.get("q") or {}
    n = (qq.get("NIFTY50") or [None])[0]
    b = None
    try:
        b = ((live_obj().get("idx") or {}).get("BANKNIFTY") or {}).get("last")
    except Exception:
        pass
    return {s: v[0] for s, v in qq.items() if v and v[0]}, n, b


def _rx_lvl(kind, head):
    return "critical" if "CRITICAL" in head else "minor" if kind == "📄" else "market" if kind == "🏛" or " MARKET " in head else "important"


def react_tick():
    """the page server's refresher, every cycle: new news lines in (with the prices at once if the market is live),
    the 5 / 15 / 60-minute marks, the close (the last prices from 15:25 on) and the next day's close filled in"""
    now = dt.datetime.now(IST)
    c = _rx_db()
    try:
        if _RX["rowid"] is None:                               # the first cycle: start from now (no flood of old lines)
            _RX["rowid"] = c.execute("select coalesce(max(rowid), 0) from alerts").fetchone()[0]
        for rid, day, t, kind, sym, side, text in c.execute("select rowid, day, t, kind, sym, side, text from alerts where rowid>? order by rowid", (_RX["rowid"],)).fetchall():
            _RX["rowid"] = rid
            lines_ = [x for x in (text or "").split("\n") if x.strip()]
            head = lines_[0] if lines_ else ""
            hl = lines_[1] if len(lines_) > 1 and not lines_[1].startswith(("🔴", "🟠", "📌")) else (lines_[2] if len(lines_) > 2 else head)
            if kind not in RX_KINDS or (kind == "⚡" and "NEWS SHOCK" not in head) or (kind == "🚨" and "CRITICAL" not in head):
                continue
            c.execute("insert or ignore into news_react(day,t,sym,kind,lvl,side,head) values(?,?,?,?,?,?,?)",
                      (day, t[:8], sym or "MARKET", kind, _rx_lvl(kind, head), side or "", hl[:200]))
        px = _rx_now()
        if px:
            pr, n, b = px
            today = now.strftime("%Y-%m-%d")
            hm = now.strftime("%H:%M:%S")
            P = lambda s: n if s == "MARKET" else pr.get(s)
            for rid, day, t, sym in c.execute("select id, day, t, sym from news_react where p0 is null").fetchall():
                c.execute("update news_react set p0=?, n0=?, b0=?, ah=? where id=?", (P(sym), n, b, 0 if (day == today and t >= "09:15" and hm[:5] <= "15:30" and
                                                                                                         (dt.datetime.strptime(day + " " + t, "%Y-%m-%d %H:%M:%S") >= now.replace(tzinfo=None) - dt.timedelta(minutes=2))) else 1, rid))
            for k, mins in RX_H:
                for rid, day, t, sym in c.execute("select id, day, t, sym from news_react where p%s is null and p0 is not null and day=?" % k, (today,)).fetchall():
                    due = dt.datetime.strptime(day + " " + t, "%Y-%m-%d %H:%M:%S") + dt.timedelta(minutes=mins)
                    if now.replace(tzinfo=None) >= due and now.replace(tzinfo=None) - due < dt.timedelta(minutes=10):
                        c.execute("update news_react set p%s=?, n%s=?, b%s=? where id=?" % (k, k, k), (P(sym), n, b, rid))
            if hm[:5] >= "15:25":                              # the close: the last prices of the day keep being written until the market stops
                for rid, sym in c.execute("select id, sym from news_react where day=? and p0 is not null", (today,)).fetchall():
                    c.execute("update news_react set pc=?, nc=?, bc=? where id=?", (P(sym), n, b, rid))
                for rid, sym in c.execute("select id, sym from news_react where day<? and pn is null and p0 is not null and (nday is null or nday=?)", (today, today)).fetchall():
                    c.execute("update news_react set pn=?, nn=?, bn=?, nday=? where id=?", (P(sym), n, b, today, rid))
        c.commit()
    finally:
        c.close()


def react(day=None):
    """/react: the day's news lines with the moves (share · NIFTY · BANKNIFTY) after 5 / 15 / 60 min, by the close, the next close"""
    out = []
    try:
        c = _rx_db()
        day = day or c.execute("select max(day) from news_react").fetchone()[0]
        mv = lambda a, b: round((a / b - 1) * 100, 2) if a and b else None
        for r in c.execute("select day, t, sym, kind, lvl, side, head, ah, p0, n0, b0, p5, p15, p60, pc, pn, n15, b15, nc, bc from news_react where day=? order by t desc", (day,)).fetchall():
            (d_, t, sym, kind, lvl, side, head, ah, p0, n0, b0, p5, p15, p60, pc, pn, n15, b15, nc, bc) = r
            sg = 1 if side == "CE" else -1 if side == "PE" else 0
            close = mv(pc, p0)
            out.append({"t": t[:5], "s": sym, "kind": kind, "lvl": lvl, "side": side, "head": head, "ah": ah,
                        "m5": mv(p5, p0), "m15": mv(p15, p0), "m60": mv(p60, p0), "mc": close, "mn": mv(pn, p0),
                        "n15": mv(n15, n0), "b15": mv(b15, b0), "nc": mv(nc, n0), "bc": mv(bc, b0),
                        "right": (None if not sg or close is None else (close * sg >= 0.5))})
        c.close()
    except Exception as ex:
        return {"day": day, "rows": [], "err": str(ex)[:80]}
    rt = [r for r in out if r["right"] is not None]
    return {"day": day, "rows": out, "right": [sum(1 for r in rt if r["right"]), len(rt)]}


def react_summary():
    """15:45 once a day: 📊 NEWS REACTION to GIR Box Picks - how many news lines, how often the reader's side was right by the
    close, the biggest moves, and NIFTY / BANKNIFTY on the market news"""
    now = dt.datetime.now(IST)
    d_ = now.strftime("%Y-%m-%d")
    if now.weekday() >= 5 or now.strftime("%H:%M") < "15:45" or _RX["summary"] == d_:
        return None
    _RX["summary"] = d_
    v = react(d_)
    rows = v.get("rows") or []
    if v.get("day") != d_ or not rows:
        return None
    fmt = lambda x: "—" if x is None else "%+.1f%%" % x
    big = sorted([r for r in rows if r["mc"] is not None and r["s"] != "MARKET"], key=lambda r: -abs(r["mc"]))[:6]
    L = ["📊 NEWS REACTION · %s · %d news lines · the reader's side right by the close: %d of %d" % (d_, len(rows), v["right"][0], v["right"][1])]
    for r in big:
        L.append("  %s %s %s · %s · by the close %s%s" % (r["t"], r["s"], ("▲" if r["side"] == "CE" else "▼" if r["side"] == "PE" else "·"), r["lvl"], fmt(r["mc"]),
                                                         "" if r["right"] is None else (" ✔" if r["right"] else " ✖")))
    mk = [r for r in rows if r["s"] == "MARKET"][:4]
    for r in mk:
        L.append("  %s MARKET · NIFTY %s · BANKNIFTY %s by the close · %s" % (r["t"], fmt(r["nc"]), fmt(r["bc"]), r["head"][:70]))
    try:
        import engine2
        engine2.tg_fo("\n".join(L))
    except Exception as ex:
        print("react summary: %s" % str(ex)[:80])
    return "\n".join(L)

PY_SRV
cat > $W/home.html <<'HTML_P123'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>GIR</title>
<style>
:root{--ce:#1ed760;--pe:#ff3b4a;--bg:#000;--panel:#07090c;--line:#1a2230;--line2:#243040;--dim:#7d8b9c;--txt:#d6dee8;--hi:#ffffff;--amber:#ffb000;--amber2:#ffcc4d;--up:#1ed760;--dn:#ff3b4a;--wt:#ffb000;
--mono:"JetBrains Mono","SFMono-Regular",Menlo,Consolas,"Roboto Mono",monospace}
*{box-sizing:border-box;margin:0;padding:0}html{-webkit-text-size-adjust:100%}
body{background:var(--bg);color:var(--txt);font:13px/1.35 var(--mono);padding-bottom:34px}
a{color:inherit;text-decoration:none}
.pu{color:var(--up)}.pd{color:var(--dn)}.am{color:var(--amber)}.dim{color:var(--dim)}.hi{color:var(--hi)}
/* top: index strip + command line, always there */
#top{position:sticky;top:0;z-index:20;background:#000;border-bottom:1px solid var(--amber)}
#idx{display:flex;gap:0;align-items:stretch;overflow-x:auto;scrollbar-width:none;border-bottom:1px solid var(--line)}
#idx::-webkit-scrollbar{display:none}
#idx .brand{padding:6px 10px;color:#000;background:var(--amber);font-weight:700;letter-spacing:.08em;display:flex;align-items:center}
#idx .ix{padding:4px 10px;border-right:1px solid var(--line);white-space:nowrap;display:flex;flex-direction:column;justify-content:center;min-width:92px}
#idx .ix b{display:block;font-size:10px;letter-spacing:.08em;color:var(--dim);font-weight:400}
#idx .ix span{font-size:14px;color:var(--hi)}#idx .ix small{font-size:11px;margin-left:5px}
#idx .st{margin-left:auto;padding:4px 10px;white-space:nowrap;font-size:11px;color:var(--dim);display:flex;align-items:center;gap:8px}
#idx .st .live{color:var(--up)}#idx .st .closed{color:var(--dim)}
#cmd{display:flex;align-items:center;gap:6px;padding:5px 8px;background:#050607}
#cmd .pr{color:var(--amber);font-weight:700}
#cmd input{flex:1;min-width:0;background:#000;color:var(--amber2);border:1px solid var(--line2);padding:7px 10px;font:14px var(--mono);letter-spacing:.06em;text-transform:uppercase;outline:none}
#cmd input:focus{border-color:var(--amber)}
#cmd button{background:var(--amber);color:#000;border:0;font:700 12px var(--mono);padding:8px 12px;letter-spacing:.06em}
#cmd select{background:#000;color:var(--txt);border:1px solid var(--line2);font:12px var(--mono);padding:7px 6px;max-width:34vw}
#cmd .x{color:var(--amber);border:1px solid var(--line2);padding:7px 10px;display:none}
/* the grid of panels */
#grid{display:grid;grid-template-columns:1fr;gap:1px;background:var(--line)}
.p{background:var(--panel);min-width:0}
.p h2{font-size:11px;font-weight:700;letter-spacing:.1em;color:var(--amber);padding:6px 8px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:8px;text-transform:uppercase}
.p h2 small{font-weight:400;color:var(--dim);letter-spacing:0;text-transform:none;margin-left:auto;font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.empty{padding:14px 8px;color:var(--dim);font-size:12px}
#focus[hidden]{display:none}
@media(min-width:900px){body{font-size:12px}#grid{grid-template-columns:repeat(12,1fr);grid-auto-rows:min-content}
  #now{grid-column:1/5;grid-row:1/4;max-height:calc(100vh - 118px);overflow:auto}
  #focus{grid-column:5/13;grid-row:1}#three{grid-column:5/13;grid-row:2}#secs{grid-column:5/13;grid-row:3}
  #focus[hidden]~#three{grid-row:1}#focus[hidden]~#secs{grid-row:2}
  #tape{grid-column:1/9;grid-row:4;max-height:70vh;overflow:auto}#news{grid-column:9/13;grid-row:4;max-height:70vh;overflow:auto}
  #now .r{padding:4px 8px}#now .s{font-size:13px}#three .r{padding:4px 8px}#tape td{padding:3px 6px;font-size:11px}#news .r{padding:4px 8px;font-size:11px}}
@media(min-width:1100px){
  #now{grid-column:1/4;grid-row:1/4}#focus{grid-column:4/10;grid-row:1}#three{grid-column:10/13;grid-row:1/3}
  #focus:not([hidden])~#three{grid-column:10/13;grid-row:1/3}#focus[hidden]~#three{grid-column:4/13;grid-row:1}
  #secs{grid-column:4/10;grid-row:2}#focus[hidden]~#secs{grid-column:4/13;grid-row:2}#tape{grid-column:4/10;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:3;max-height:none}
  #secs .g{grid-template-columns:repeat(5,1fr)}#three .r{grid-template-columns:18px 1fr}#three .r>div:nth-child(3){display:none}}
@media(min-width:1500px){#secs .g{grid-template-columns:repeat(10,1fr)}}
/* NOW */
#now .r{display:grid;grid-template-columns:44px 1fr auto;gap:4px 8px;padding:6px 8px;border-bottom:1px solid var(--line);align-items:start}
#now .r.new{animation:flash 1.6s ease-out}
@keyframes flash{0%{background:rgba(255,176,0,.35)}100%{background:transparent}}
#now .t{color:var(--dim);font-size:11px;padding-top:2px}
#now .s{color:var(--hi);font-weight:700;font-size:14px}
#now .side{font-size:11px;font-weight:700;padding:1px 6px;border:1px solid;white-space:nowrap}
#now .side.up{color:var(--up);border-color:var(--up)}#now .side.dn{color:var(--dn);border-color:var(--dn)}#now .side.na{color:var(--dim);border-color:var(--line2)}
#now .h{grid-column:2/4;color:var(--txt)}
#now .l{grid-column:2/4;color:var(--dim);font-size:11px;white-space:pre-wrap}
#now .l .w{color:var(--wt)}#now .l .b{color:var(--up)}
/* THE THREE */
#three .r{display:grid;grid-template-columns:22px 1fr auto;gap:2px 8px;padding:6px 8px;border-bottom:1px solid var(--line)}
#three .rk{color:var(--amber);font-weight:700;font-size:16px}
#three .l1 b{color:var(--hi);font-size:14px}#three .l1 .sd{margin-left:6px;font-weight:700}
#three .vd{grid-column:2/4;font-size:12px}#three .vd.wt{color:var(--wt)}#three .vd.dn{color:var(--dim)}
#three .l2{grid-column:2/4;color:var(--dim);font-size:11px}#three .l2 em{font-style:normal;color:var(--txt)}
/* SECTORS: a heat grid */
#secs .g{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line)}
@media(min-width:600px){#secs .g{grid-template-columns:repeat(5,1fr)}}@media(min-width:900px){#secs .g{grid-template-columns:repeat(10,1fr)}}
#secs .c{background:var(--panel);padding:6px 6px 5px;min-height:62px;cursor:pointer;position:relative;overflow:hidden}
#secs .c.sel{outline:1px solid var(--amber)}
#secs .c .n{font-size:10px;letter-spacing:.06em;color:var(--txt);text-transform:uppercase;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .v{font-size:15px;font-weight:700;margin-top:1px}
#secs .c .tb{font-size:10px;color:var(--dim);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#secs .c .pl{position:absolute;top:5px;right:5px;font-size:10px;font-weight:700}
/* TAPE: a dense table, still */
#tape table{width:100%;border-collapse:collapse;table-layout:fixed}
#tape th{font-size:10px;color:var(--dim);font-weight:400;text-align:left;padding:4px 6px;border-bottom:1px solid var(--line);letter-spacing:.06em;cursor:pointer;white-space:nowrap}
#tape th.on{color:var(--amber)}
#tape td{padding:4px 6px;border-bottom:1px solid var(--line);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:12px}
#tape tr{cursor:pointer}#tape tr:active{background:#111}
#tape .s{color:var(--hi);font-weight:700;width:92px}#tape .px{text-align:right;width:70px}#tape .ch{text-align:right;width:62px}#tape .m{width:52px}
#tape .m i{display:inline-block;width:9px;height:10px;margin-right:1px;background:var(--line2);vertical-align:middle}
#tape .m i.u{background:var(--up)}#tape .m i.d{background:var(--dn)}
#tape .oi{color:var(--dim);font-size:11px}
#tape td.fu{animation:fu 1.4s ease-out}#tape td.fd{animation:fd 1.4s ease-out}
@keyframes fu{0%{background:rgba(30,215,96,.45)}100%{background:transparent}}@keyframes fd{0%{background:rgba(255,59,74,.45)}100%{background:transparent}}
#idx .ix span.fu{color:var(--up)}#idx .ix span.fd{color:var(--dn)}
#tape .more{padding:6px 8px;color:var(--dim);font-size:11px;text-align:center;cursor:pointer}
/* NEWS */
#news .r{padding:5px 8px;border-bottom:1px solid var(--line);font-size:12px;display:grid;grid-template-columns:auto 1fr;gap:2px 8px}
#news .r .t{color:var(--dim);font-size:11px}#news .r b{color:var(--hi)}#news .r .h{grid-column:1/3;color:var(--txt)}
#news .r .w{grid-column:1/3;font-size:11px;color:var(--dim)}#news .sd{font-weight:700;margin-left:6px}
/* FOCUS */
#focus .hd{display:flex;align-items:baseline;gap:10px;padding:8px;border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .hd b{font-size:20px;color:var(--hi)}#focus .hd .px{font-size:16px}
#focus .m{padding:6px 8px;font-weight:700;border-bottom:1px solid var(--line)}
#focus svg{width:100%;height:150px;display:block;background:#000}
#focus .cap{padding:4px 8px;color:var(--dim);font-size:10px;border-bottom:1px solid var(--line)}
#focus .ag{padding:4px 8px;font-size:12px;border-bottom:1px solid var(--line)}#focus .ag b{color:var(--amber);text-transform:uppercase;font-size:10px;letter-spacing:.06em;margin-right:6px}
#focus .tk{padding:8px;background:#0c0a04;border-left:3px solid var(--amber);font-size:13px;color:var(--hi);white-space:pre-wrap}
#focus .nw{padding:6px 8px;font-size:12px;color:var(--txt)}#focus .nw em{font-style:normal;color:var(--dim)}
@media(max-width:899px){#focus.sheet{position:fixed;inset:0;z-index:30;overflow:auto;background:var(--panel);padding-bottom:40px}}

/* FOCUS v2: the share's own window */
#focus .tabs{display:flex;gap:1px;background:var(--line);border-bottom:1px solid var(--line)}
#focus .tabs span{flex:1;text-align:center;padding:5px 4px;font-size:10px;letter-spacing:.08em;color:var(--dim);background:var(--panel);cursor:pointer;text-transform:uppercase}
#focus .tabs span.on{color:var(--amber);border-bottom:2px solid var(--amber)}
#focus .sub{display:flex;gap:10px;padding:4px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line);flex-wrap:wrap}
#focus .sub b{color:var(--txt);font-weight:400}
#focus svg.px{width:100%;height:230px;display:block;background:#000}
#focus svg.oit{width:100%;height:110px;display:block;background:#000}
/* THE OI LINE CHART (patch 92): full size, under the price chart */
#focus .oitw{border-top:1px solid var(--line);background:#05070a}
#focus .oitw .oith{display:flex;flex-wrap:wrap;gap:2px 8px;align-items:center;padding:5px 8px;font-size:11px;border-bottom:1px solid var(--line)}
#focus .oitw .oith>b{color:var(--amber);font-size:10px;letter-spacing:.08em;font-weight:700}
#focus .oitw .oith a{padding:2px 7px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;white-space:nowrap}
#focus .oitw .oith a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .oitw .oitr{width:100%;font-size:11px;color:var(--dim)}#focus .oitw .oitr b{font-weight:700}
#focus .oitw svg{display:block;width:100%;height:auto;max-height:none;touch-action:pan-y}
/* THE ALERT BAR (patch 93): only the clear-cut alerts, on every screen */
#abar{display:flex;align-items:stretch;gap:0;border-bottom:1px solid var(--line);background:#0b0d11;min-height:30px;font-size:11px}
#abar .al{flex:none;display:flex;align-items:center;padding:0 9px;font-weight:700;letter-spacing:.08em;color:#000;background:var(--dim);font-size:10px}
#abar.has-act .al{background:var(--dn);color:#fff}#abar.has-move .al{background:var(--amber)}
#abar .ac{flex:1;display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:3px 4px;align-items:center}#abar .ac::-webkit-scrollbar{display:none}
#abar .ch{flex:none;display:flex;gap:6px;align-items:center;padding:3px 8px;border:1px solid var(--line2);background:#000;cursor:pointer;white-space:nowrap;max-width:400px;overflow:hidden;text-overflow:ellipsis}
#abar .ch.act{border-color:var(--dn);background:#2a0b0e}#abar .ch.move{border-color:#7a5600;background:#1d1500}
#abar .ch .tg{font-size:9px;font-weight:700;padding:1px 4px;letter-spacing:.06em}#abar .ch.act .tg{background:var(--dn);color:#fff}#abar .ch.move .tg{background:var(--amber);color:#000}
#abar .ch .tm{color:var(--dim)}#abar .ch b{color:var(--hi)}#abar .ch .tk{color:var(--txt);overflow:hidden;text-overflow:ellipsis}
#abar .ch.fresh{animation:abfl 1s ease-in-out 8}
@keyframes abfl{0%,100%{box-shadow:none}50%{box-shadow:0 0 0 2px var(--amber2)}}
#abar .ae{color:var(--dim);padding:0 6px;white-space:nowrap}
#abar .ar{flex:none;display:flex;gap:4px;align-items:center;padding:0 6px;border-left:1px solid var(--line)}
#abar .ar a{cursor:pointer;padding:3px 7px;border:1px solid var(--line2);white-space:nowrap;font-size:10px;color:var(--txt);background:#000}
#abar .ar a.on{border-color:var(--up);color:var(--up)}
@media(max-width:700px){#abar{flex-wrap:wrap}#abar .al{padding:4px 9px}#abar .ar{margin-left:auto;border-left:0;padding:3px 4px}#abar .ac{order:3;flex-basis:100%;border-top:1px solid var(--line)}#abar .ch{max-width:92vw}#abar .ae{white-space:normal;font-size:10px}}
/* THE TICK CHART (patch 93): price tick by tick, the calls' / puts' OI under it on the same time axis */
#focus .pxm{display:inline-flex;gap:2px;margin-right:8px;vertical-align:middle}
#focus .pxm a{padding:1px 7px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;letter-spacing:.04em}
#focus .pxm a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .tkw{background:#05070a}
#focus .tkh{display:flex;flex-wrap:wrap;gap:3px 8px;align-items:center;padding:5px 8px;font-size:11px;border-bottom:1px solid var(--line)}
#focus .tkh .tkr{width:100%;color:var(--dim)}#focus .tkh .tkr b{font-weight:700}
#focus .tkh .tkm{width:100%;color:var(--dim);font-size:10px}
#focus .tkw svg{display:block;width:100%;height:auto;max-height:none;touch-action:pan-y}
/* HOME = THE TRADING SCREEN (patch 95): on a laptop / desktop the share's window IS the home page - no HOME / CLOSE inside it,
   the desk line, the ticket and the OI-scenario line one row each, so the charts get the height */
#focus.ws-on .hd .hm,#focus.ws-on .hd a.am{display:none}
#focus.ws-on .hd{padding:4px 8px}
#focus.ws-on .m,#focus.ws-on .tk,#focus.ws-on .rib{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-top:3px;padding-bottom:3px}
#focus.ws-on .tk{font-size:12px}
@media(min-width:1300px){body{font-size:13px}#focus .wsl>div{font-size:12px}}
/* THE OI BUILD-UP CHART (patch 102): calls and puts at every strike, the resistances R1-R3 and supports S1-S3 marked */
#focus .srb{display:flex;flex-wrap:wrap;gap:3px 10px;padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line)}
#focus .srb b{font-weight:700}#focus .srb .t{color:var(--dim);font-size:10px;letter-spacing:.06em;margin-right:2px}
#focus .oimd{display:inline-flex;gap:2px;margin-left:8px}#focus .oimd a{padding:1px 7px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000}#focus .oimd a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .oic svg{display:block;width:100%;height:auto;max-height:none}
#focus .shi{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:1px;background:var(--line);border-bottom:1px solid var(--line)}
#focus .shi>div{background:#05070a;padding:4px 8px;font-size:11px}#focus .shi small{display:block;color:var(--amber);font-size:9px;letter-spacing:.08em;margin-bottom:2px}
#focus .shi a{cursor:pointer}
/* the OI SCENARIOS · NEWS filters (patch 112) */
#mk .nf{display:inline-flex;gap:2px;margin-left:6px}#mk .nf a{padding:0 5px;border:1px solid var(--line2);font-size:9px;cursor:pointer;color:var(--txt);letter-spacing:0;font-weight:400}#mk .nf a.on{background:var(--amber);color:#000;border-color:var(--amber)}
/* the share list says when it is filtered (patch 113) */
#focus .wsl small i.p{font-style:normal}
#focus .och{display:flex;justify-content:space-between;gap:8px;padding:3px 6px;font-size:10px;color:var(--dim)}#focus .och b{color:var(--hi)}
#focus table.kc{width:100%;border-collapse:collapse;font-size:11px;font-variant-numeric:tabular-nums}
#focus table.kc th{position:sticky;top:var(--wshh,22px);z-index:1;background:#0a0c10;font-size:9px;font-weight:400;color:var(--dim);padding:4px 3px;text-align:right;border-bottom:1px solid var(--line)}
#focus table.kc th.ce{color:var(--ce)}#focus table.kc th.pe{color:var(--pe)}#focus table.kc th:nth-child(3){text-align:center}#focus table.kc th:nth-child(n+4){text-align:left}
#focus table.kc td{padding:2px 4px;text-align:right;border-bottom:1px solid #10151d;position:relative;white-space:nowrap;line-height:1.15}
#focus table.kc td:nth-child(n+4){text-align:left}#focus table.kc td b{display:block;font-weight:600;color:var(--txt);position:relative}#focus table.kc td i{display:block;font-style:normal;font-size:9px;position:relative}
#focus table.kc td s{position:absolute;top:2px;bottom:2px;opacity:.25;text-decoration:none}#focus table.kc td.co s{right:0;background:var(--ce)}#focus table.kc td.po s{left:0;background:var(--pe)}
#focus table.kc td.itm{background:#1a1606}#focus table.kc td.k{text-align:center;color:var(--hi);font-weight:700;background:#0b0e13}
#focus table.kc td.k u{display:block;text-decoration:none;font-size:9px;color:#000;background:var(--amber);margin:1px auto 0;width:max-content;padding:0 3px}
#focus table.kc tr.atm td{border-top:1px solid var(--amber);border-bottom:1px solid var(--amber)}#focus table.kc tr.atm td.k{color:var(--amber)}
#focus table.kc tr.spt td{padding:0;border:0;text-align:center;height:14px}#focus table.kc tr.spt td span{display:inline-block;background:#1565c0;color:#fff;font-size:10px;padding:0 8px;border-radius:7px;position:relative;z-index:1}
#focus table.kc tr.spt td:before{content:"";position:absolute;left:0;right:0;top:50%;border-top:1px solid #1565c0}
#focus table.kc tfoot td{color:var(--dim);font-size:10px;border-top:1px solid var(--line2)}#focus table.kc tfoot td.ce b{color:var(--ce)}#focus table.kc tfoot td.pe b{color:var(--pe)}#focus table.kc tfoot td:nth-child(3){text-align:center}
#focus .ocf{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line);margin-top:4px}#focus .ocf span{background:#0a0c10;padding:4px 6px;font-size:9px;color:var(--dim)}#focus .ocf b{display:block;font-size:13px;color:var(--hi)}
#focus .wsf{padding:4px 6px;background:#1d1500;border-bottom:1px solid #7a5600;color:var(--amber);font-size:10px}#focus .wsf a{margin-left:6px;cursor:pointer;color:#000;background:var(--amber);padding:1px 6px}
/* NEWS LINKS (patch 111): a headline opens the full story in a new tab */
a.nl{color:inherit;text-decoration:underline;text-decoration-color:#7d8b9c66;text-underline-offset:3px;cursor:pointer}a.nl:hover{color:var(--amber);text-decoration-color:var(--amber)}
a.nl .ar_{font-size:.85em;color:var(--amber);margin-left:3px;text-decoration:none;display:inline-block}
/* THE ALARM + SELF-CHECK (patch 108) */
@media(max-width:700px){#abar .ar{flex-wrap:wrap;gap:3px;max-width:100%;justify-content:flex-end}#abar .ar a{padding:3px 5px;font-size:9px}#abar .vol{gap:2px}}
#abar .vol{display:inline-flex;gap:2px;margin-right:4px}#abar .vol a{padding:3px 6px}#abar .vol a.on{border-color:var(--amber);color:#000;background:var(--amber)}
#chkres{position:fixed;left:50%;top:calc(var(--toph,150px) + 8px);transform:translateX(-50%);z-index:90;width:min(980px,calc(100vw - 16px));max-height:calc(100vh - var(--toph,150px) - 40px);overflow:auto;background:#0b0d11;border:1px solid var(--amber);box-shadow:0 10px 40px #000e;font-size:11.5px}
#chkres .ckh{position:sticky;top:0;background:#14100a;padding:8px 10px;border-bottom:1px solid var(--line2);display:flex;gap:12px;align-items:center;font-weight:700}
#chkres .ckh a{margin-left:auto;cursor:pointer;color:var(--txt);border:1px solid var(--line2);padding:2px 8px;font-weight:400}#chkres .ckh a+a{margin-left:0}
#chkres table{border-collapse:collapse;width:100%}#chkres td{padding:3px 8px;border-bottom:1px solid var(--line);vertical-align:top}
#chkres tr.PASS td:first-child{color:var(--up)}#chkres tr.WARN td:first-child{color:var(--amber)}#chkres tr.FAIL td:first-child{color:var(--dn)}#chkres tr.FAIL{background:#2a0b0e}
#chkres td:last-child{color:var(--dim);word-break:break-word}
/* MARKET WITHOUT BLINKING (patch 107): the charts fit their panel exactly - no scrollbar coming and going */
#mk svg{display:block}#mk #mk-nif,#mk #mk-don{overflow:hidden}
/* a share's window at half the screen (patch 107): 2 x 2 - the price (tall) | the OI build-up over the checklist + OI chart */
@media(max-width:1099px){body.solo #focus .ws{grid-template-columns:minmax(0,1.2fr) minmax(0,1fr);grid-template-rows:1fr 1fr;height:calc(100vh - var(--toph,0px) - 120px)}
  body.solo #wsList{display:none}body.solo #wsPx{grid-row:1/3}body.solo #focus .hd b{font-size:15px}}
/* THE ALERT CARD (patch 105): a new ACT / MOVING alert pops up with its full text, top right, on every screen */
#toasts{position:fixed;right:12px;top:calc(var(--toph,150px) + 6px);z-index:80;display:flex;flex-direction:column;gap:6px;width:min(440px,calc(100vw - 24px));pointer-events:none}
#toasts .ta{pointer-events:auto;background:#0b0d11;border:1px solid var(--line2);border-left:5px solid var(--amber);box-shadow:0 6px 24px #000c;padding:8px 10px 8px 10px;font-size:12px;cursor:pointer;animation:tin .25s ease-out}
#toasts .ta.act{border-left-color:var(--dn);background:#1a0709}#toasts .ta.move{border-left-color:var(--amber);background:#161002}
#toasts .ta .th{display:flex;gap:8px;align-items:baseline;margin-bottom:4px}#toasts .ta .tg2{font-size:10px;font-weight:700;padding:1px 6px;letter-spacing:.06em}
#toasts .ta.act .tg2{background:var(--dn);color:#fff}#toasts .ta.move .tg2{background:var(--amber);color:#000}
#toasts .ta b{color:var(--hi)}#toasts .ta .tl{color:var(--txt);font-size:11px;line-height:1.4;white-space:pre-wrap}#toasts .ta .tx{margin-left:auto;color:var(--dim);cursor:pointer;padding:0 4px}
@keyframes tin{from{transform:translateX(30px);opacity:0}to{transform:none;opacity:1}}
@media(max-width:700px){#toasts{right:6px;width:calc(100vw - 12px)}#toasts .ta{padding:6px 8px;font-size:11px}#toasts .ta:nth-child(n+3){display:none}
  #toasts .ta .tl{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-size:10.5px}#toasts .ta .tg2{font-size:9px}}
/* THE PRO CHART (patch 104) */
#focus .pro{background:#05070a}#focus .pro:fullscreen{background:#05070a;padding:4px}
#focus .ptb{display:flex;flex-wrap:wrap;gap:4px 10px;padding:4px 6px;border-bottom:1px solid var(--line);align-items:center}
#focus .ptb span{display:inline-flex;gap:2px}
#focus .ptb a{padding:2px 6px;border:1px solid var(--line2);font-size:10px;cursor:pointer;color:var(--txt);background:#000;white-space:nowrap;letter-spacing:.03em}
#focus .ptb a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .pmain,#focus .psub{position:relative}#focus .psub{border-top:1px solid var(--line)}
#focus .plg,#focus .plg2{position:absolute;left:6px;top:4px;z-index:3;font-size:11px;pointer-events:none;background:#05070acc;padding:1px 4px}
#focus .plg b,#focus .plg2 b{color:var(--hi);font-weight:700}
/* MULTI-WINDOW (patch 102): a share's own window shows only its trading screen - no command line, no keys */
body.solo #fkeys a.on{background:#000;color:var(--txt);border-color:var(--line2)}
/* THE F&O CHECKLIST (patch 101): what an option buyer checks before a trade, for the open share */
#focus .ck{font-size:11px}
#focus .ck .kv{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:1px;background:var(--line);border-bottom:1px solid var(--line)}
#focus .ck .kv div{background:#05070a;padding:3px 6px}#focus .ck .kv small{display:block;color:var(--dim);font-size:9px;letter-spacing:.06em}#focus .ck .kv b{color:var(--hi);font-size:12px}
#focus .ck .sd{display:grid;grid-template-columns:1fr;gap:1px;background:var(--line)}
#focus .ck .sd>div{background:var(--panel);padding:4px 6px;min-width:0}
#focus .ck .vh{display:flex;justify-content:space-between;align-items:baseline;font-weight:700;margin-bottom:3px}
#focus .ck .vb{padding:1px 6px;font-size:10px;letter-spacing:.06em}
#focus .ck .vb.PASS{background:var(--up);color:#000}#focus .ck .vb.MIXED{background:var(--amber);color:#000}#focus .ck .vb.FAIL{background:var(--dn);color:#fff}
#focus .ck .it{display:grid;grid-template-columns:14px 70px 1fr;gap:4px;padding:1px 0;font-size:10.5px;line-height:1.3}
#focus .ck .it span:nth-child(2){color:var(--dim);letter-spacing:.04em;font-size:9.5px;padding-top:1px}
#focus .ck .tkt{margin-top:4px;padding:3px 5px;background:#0c0a04;border-left:3px solid var(--amber);font-size:10.5px}
#focus .ck .wn{padding:3px 6px;color:var(--dn);font-size:10.5px;border-top:1px solid var(--line)}
@media(max-width:700px){#focus .ck .sd{grid-template-columns:1fr}}
/* EVERY SECOND (patch 99): a price that ticks flashes green (up) or red (down), like Kite */
.fu{animation:fu .9s ease-out}.fd{animation:fd .9s ease-out}
@keyframes fu{from{background:rgba(30,215,96,.55)}to{background:transparent}}@keyframes fd{from{background:rgba(255,59,74,.55)}to{background:transparent}}
#lvq{color:var(--up);font-size:10px;margin-left:6px}
/* THE MARKET SCREEN (patch 98): the whole F&O market at a glance, Bloomberg style */
body.one #grid>section#market.on{padding:0;background:#1a2230}
#market>h2{display:none}
#mk{display:grid;gap:2px;background:#1a2230;grid-template-columns:1fr;font-size:11px}
#mk .q{background:var(--panel);display:flex;flex-direction:column;min-height:0;overflow:hidden;height:300px}
#mk .q h3{font-size:10px;color:var(--amber);letter-spacing:.08em;padding:3px 6px;border-bottom:1px solid var(--line);background:#0a0c10;font-weight:700;display:flex;gap:8px;white-space:nowrap;overflow:hidden}
#mk .q h3 span{color:var(--dim);letter-spacing:0;font-weight:400}
#mk .q .bd{flex:1;min-height:0;overflow:auto;position:relative;scrollbar-width:thin}
#mk table{border-collapse:collapse;width:100%}
/* ⚡ EARLY (patch 119) */
.rx{margin-bottom:6px;border:1px solid var(--line)}.rx h3{padding:4px 8px;font-size:11px;color:var(--amber);background:#0a0c10}.rx h3 span{font-weight:400;letter-spacing:0}
.rxt{width:100%;border-collapse:collapse;font-size:11px}.rxt td{padding:3px 6px;border-bottom:1px solid #10151d;white-space:nowrap;vertical-align:top}.rxt td.rxh{white-space:normal;min-width:240px}
#mk .ntf{float:right;text-transform:none;letter-spacing:0}#mk .ntf a{padding:0 6px;margin-left:2px;border:1px solid var(--line2);cursor:pointer;color:var(--dim)}#mk .ntf a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .och a{padding:0 5px;margin-right:3px;border:1px solid var(--line2);cursor:pointer;color:var(--dim)}#focus .och a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#q-ear .bd{overflow:auto;max-height:30vh}#mk .et td{padding:3px 6px;vertical-align:top}#mk .et .ei{font-style:normal;margin-right:5px;white-space:nowrap}
#mk .et .eb{padding:1px 7px;color:#000;font-weight:700}#mk .et .eb.ce{background:var(--ce)}#mk .et .eb.pe{background:var(--pe)}#mk .et .ew{color:var(--amber)}
#mk .et td.ewhy{white-space:normal;min-width:220px;max-width:460px;color:var(--txt)}#mk .erec{padding:3px 8px;color:var(--dim);font-size:10px;border-top:1px solid var(--line)}#mk .erec b{color:var(--hi)}#mk td{padding:1px 4px;white-space:nowrap}#mk tr:nth-child(odd) td{background:#0a0d12}
#mk .r{text-align:right}#mk .c{text-align:center}#mk .k{cursor:pointer}#mk .k:hover td{background:#14202e}
#mk .hm td{text-align:center;font-size:10px;padding:2px 3px}#mk .hm td:first-child{text-align:left}
#mk .mn{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:2px 8px;padding:3px 6px}#mk .mn h4{font-size:10px;letter-spacing:.06em;margin-top:2px}
#mk .dk div{padding:3px 8px;border-bottom:1px solid var(--line)}#mk .dk b{color:var(--hi)}#mk .dk em{font-style:normal;color:var(--dim);display:inline-block;width:78px}
@media(min-width:1100px){
  #mk{height:calc(100vh - var(--toph,150px) - 34px);grid-template-columns:1.25fr 1.25fr 1.05fr 1.15fr 1fr;grid-template-rows:auto 1fr 1fr;
      grid-template-areas:"ear ear ear ear ear" "mov nif don mon dsk" "mov hea bus mon nws"}
  #q-ear{grid-area:ear;max-height:30vh}
  #mk .q{height:auto}
  #q-mov{grid-area:mov}#q-nif{grid-area:nif}#q-don{grid-area:don}#q-mon{grid-area:mon}#q-dsk{grid-area:dsk}#q-hea{grid-area:hea}#q-bus{grid-area:bus}#q-nws{grid-area:nws}}
#focus table.oi{width:100%;border-collapse:collapse;table-layout:fixed;font-size:11px}
#focus table.oi th{font-size:9px;color:var(--dim);font-weight:400;padding:3px 4px;border-bottom:1px solid var(--line);letter-spacing:.06em;text-align:right}
#focus table.oi th.k{text-align:center}#focus table.oi th.l{text-align:left}
#focus table.oi td{padding:3px 4px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap;position:relative;overflow:hidden}
#focus table.oi td.k{text-align:center;color:var(--hi);font-weight:700;background:#0b0e13}
#focus table.oi td.l{text-align:left}
#focus table.oi tr.atm td.k{color:var(--amber);outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi tr.wall td.k::after{content:" ▪";color:var(--amber)}
#focus table.oi td i{position:absolute;top:0;bottom:0;opacity:.22;z-index:0}
#focus table.oi td.ce i{right:0;background:var(--ce)}#focus table.oi td.pe i{left:0;background:var(--pe)}
#focus table.oi td span{position:relative;z-index:1}
#focus table.oi td.d.up span{color:var(--up)}#focus table.oi td.d.dn span{color:var(--dn)}
#focus table.oi tr.tot td{color:var(--hi);border-top:1px solid var(--line2);font-weight:700}
#focus .legend{padding:3px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line)}
#focus .legend i{display:inline-block;width:9px;height:9px;vertical-align:middle;margin:0 3px 0 8px}
@media(min-width:1100px){#focus svg.px{height:260px}}

/* OI SCENARIOS (patch 84) */
#scn .r{display:grid;grid-template-columns:1fr auto auto;gap:2px 8px;padding:5px 8px;border-bottom:1px solid var(--line);align-items:baseline}
#scn .nm{color:var(--hi);font-weight:700;font-size:12px}#scn .nm .sd{font-size:10px;margin-left:6px;font-weight:400}
#scn .n{color:var(--amber);font-weight:700}#scn .ms{color:var(--dim);font-size:10px;text-align:right;white-space:nowrap}#scn .ms b{color:var(--up)}
#scn .sy{grid-column:1/4;font-size:11px;color:var(--dim);line-height:1.6}#scn .sy a{color:var(--txt);margin-right:10px;cursor:pointer;white-space:nowrap}#scn .sy a.box{color:var(--up)}
#scn .ft{padding:5px 8px;color:var(--dim);font-size:10px;line-height:1.5}
#focus .rib{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line);background:#0a0c10}#focus .rib b{color:var(--amber)}
#focus .scl{border-bottom:1px solid var(--line2)}#focus .scl div{padding:4px 8px;font-size:11px;border-bottom:1px solid var(--line)}#focus .scl .dim{font-size:10px}
@media(min-width:900px){#scn{grid-column:9/13;grid-row:4;max-height:45vh;overflow:auto}#news{grid-row:5}#tape{grid-row:4/6}}
@media(min-width:1100px){#scn{grid-column:10/13;grid-row:3;max-height:none}#news{grid-column:10/13;grid-row:4}#tape{grid-row:3/5}}

/* THE TRADING VIEW (patch 85): OI left, chart right, one price scale */
#focus .tv{display:block;background:#000;border-bottom:1px solid var(--line)}
#focus .tv svg{display:block;width:100%;height:auto;max-width:100%}
#focus .pat{padding:5px 8px;font-size:11px;color:var(--txt);border-bottom:1px solid var(--line);line-height:1.5}
#focus .pat b{color:var(--amber);font-weight:400}#focus .pat .u{color:var(--up)}#focus .pat .d{color:var(--dn)}
@media(min-width:1100px){#focus:not([hidden]){grid-column:4/13;grid-row:1}#focus:not([hidden])~#three{grid-column:10/13;grid-row:2}
  #focus:not([hidden])~#secs{grid-column:4/10;grid-row:2}}

/* patch 89: the index strip never overlaps · the function keys · one panel at a time */
#idx .ix{flex:none}
#tick .lb{position:relative;z-index:2}#tick{z-index:15}
@media(max-width:600px){#idx .ix{min-width:0;padding:3px 8px}#idx .ix span{font-size:12px}#idx .ix small{display:block;margin-left:0;font-size:10px}#idx .st{font-size:10px;gap:6px}}
#fkeys{display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:4px 8px 6px;background:#050607;border-top:1px solid var(--line)}
#fkeys::-webkit-scrollbar{display:none}
#fkeys a{flex:none;padding:5px 9px;border:1px solid var(--line2);color:var(--txt);font-size:11px;letter-spacing:.06em;cursor:pointer;white-space:nowrap;background:#000}
#fkeys a.on{background:var(--amber);color:#000;border-color:var(--amber);font-weight:700}
#fkeys a b{color:var(--amber);margin-right:4px;font-weight:700}#fkeys a.on b{color:#000}
.xp{display:none}
body.one #grid{grid-template-columns:1fr !important}
body.one #grid>section{display:none}
body.one #grid>section.on, body.one #grid>#focus:not([hidden]){display:block;grid-column:1/-1 !important;grid-row:auto !important;max-height:none !important}
.pn .r{display:grid;grid-template-columns:96px 1fr;gap:2px 10px;padding:6px 8px;border-bottom:1px solid var(--line);cursor:pointer}
.pn .r .sy b{color:var(--hi);font-size:13px}.pn .r .sy small{display:block;color:var(--dim);font-size:10px}
.pn .do{font-weight:700}.pn .do.up{color:var(--up)}.pn .do.dn{color:var(--dn)}.pn .why{color:var(--dim);font-size:11px}
.pn .hd2{padding:6px 8px;color:var(--amber);font-size:11px;letter-spacing:.08em;border-bottom:1px solid var(--line);background:#0a0c10}
.pn .kp{display:grid;grid-template-columns:repeat(2,1fr);gap:1px;background:var(--line)}
@media(min-width:900px){.pn .kp{grid-template-columns:repeat(4,1fr)}}
.pn .kp div{background:var(--panel);padding:8px}.pn .kp b{display:block;font-size:20px;color:var(--hi)}.pn .kp small{color:var(--dim);font-size:10px;letter-spacing:.06em}
.pn .bars{display:flex;align-items:flex-end;gap:2px;height:70px;padding:6px 8px;border-bottom:1px solid var(--line)}
.pn .bars i{flex:1;min-width:3px;display:block}
.pn form{display:flex;flex-wrap:wrap;gap:4px;padding:8px;border-bottom:1px solid var(--line)}
.pn input,.pn select{background:#000;color:var(--txt);border:1px solid var(--line2);font:12px var(--mono);padding:6px;width:86px}
.pn button{background:var(--amber);color:#000;border:0;font:700 11px var(--mono);padding:6px 10px;cursor:pointer}
.pn .msg{padding:4px 8px;font-size:11px;color:var(--amber)}

/* THE WORKSTATION (patch 91) */
#tape{min-width:0}#tapel{overflow-x:auto;max-width:100%}
@media(min-width:900px){#focus .wst{flex-wrap:wrap;max-height:74px;overflow-y:auto}}
#focus.ws-on{position:fixed;left:0;right:0;top:var(--toph,0px);bottom:30px;z-index:25;overflow:auto;background:var(--panel)}
#focus .hm{color:#000;background:var(--amber);padding:3px 9px;font-weight:700;cursor:pointer;font-size:12px;letter-spacing:.06em}
#focus .ws{display:grid;grid-template-columns:minmax(200px,14%) minmax(0,1.35fr) minmax(0,1fr) minmax(0,.85fr);gap:1px;background:var(--line);height:max(440px,calc(100vh - var(--toph,0px) - 230px))}
#focus .ws>div{background:var(--panel);min-width:0;overflow:auto}
#focus .wsh{padding:5px 8px;color:var(--amber);font-size:10px;letter-spacing:.08em;border-bottom:1px solid var(--line);background:#0a0c10;position:sticky;top:0;z-index:2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#focus .wsh span{color:var(--dim);letter-spacing:0;margin-left:6px}#focus .wsh b{color:var(--txt);font-weight:400}
#focus .wst{display:flex;gap:2px;overflow-x:auto;padding:4px;border-bottom:1px solid var(--line);scrollbar-width:none;position:sticky;top:0;background:var(--panel);z-index:2}
#focus .wst::-webkit-scrollbar{display:none}
#focus .wst a,#focus .wss a{flex:none;padding:3px 6px;border:1px solid var(--line2);font-size:9px;letter-spacing:.04em;cursor:pointer;white-space:nowrap;color:var(--txt);background:#000}
#focus .wst a.on,#focus .wss a.on{background:var(--amber);color:#000;border-color:var(--amber)}
#focus .wss{display:flex;gap:2px;flex-wrap:wrap;padding:4px;border-bottom:1px solid var(--line);align-items:center}
#focus .wss .dim{font-size:9px;margin-left:auto}
#focus .wsl>div{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:0 6px;padding:4px 6px;border-bottom:1px solid var(--line);font-size:11px;cursor:pointer}
#focus .wsl>div b{color:var(--hi);overflow:hidden;text-overflow:ellipsis}#focus .wsl>div small{grid-column:1/3;color:var(--dim);font-size:10px}
#focus .wsl>div.cur{background:#1a1406;outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi th.s{cursor:pointer;user-select:none}#focus table.oi th.on{color:var(--amber)}
#focus .ocsvg svg{display:block;width:100%;height:auto}
@media(max-width:899px){#focus .wsl{max-height:none}}
/* the news ticker at the bottom */
#tick{position:fixed;left:0;right:0;bottom:0;height:30px;background:#000;border-top:1px solid var(--amber);display:flex;align-items:center;overflow:hidden;z-index:15}
#tick .lb{background:var(--amber);color:#000;font-weight:700;font-size:11px;padding:0 8px;height:100%;display:flex;align-items:center;letter-spacing:.08em;flex:none}
#tick .run{white-space:nowrap;will-change:transform;font-size:12px;padding-left:12px;animation:tickrun var(--tdur,90s) linear infinite}
#tick:hover .run,#tick.hold .run{animation-play-state:paused}#tick.hold .lb:after{content:" ❚❚"}
@keyframes tickrun{from{transform:translateX(0)}to{transform:translateX(var(--tw,-3000px))}}
#tick .run b{color:var(--hi)}#tick .run em{font-style:normal;color:var(--dim);margin:0 10px 0 0}
</style></head><body>
<div id="top">
  <div id="idx"></div>
  <div id="cmd"><span class="pr">&gt;</span><input id="q" placeholder="TICKER  ·  type a share, Enter = FOCUS" autocomplete="off" autocapitalize="characters"><button id="go">GO</button><select id="secsel"><option value="">ALL SECTORS</option></select><a class="x" id="unf" onclick="unfocus()">✕ ALL</a></div>
  <div id="fkeys"><a data-v="market" onclick="goHome()" title="home = MARKET (key M)"><b>⌂</b>MARKET</a><a data-v="now" onclick="setView('now')"><b>1</b>NOW</a><a data-v="three" onclick="setView('three')"><b>2</b>THE THREE</a><a data-v="scn" onclick="setView('scn')"><b>3</b>OI SCENARIOS</a><a data-v="secs" onclick="setView('secs')"><b>4</b>SECTORS</a><a data-v="tape" onclick="setView('tape')"><b>5</b>F&amp;O TAPE</a><a data-v="news" onclick="setView('news')"><b>6</b>NEWS</a><a data-v="picks" onclick="setView('picks')"><b>7</b>PICKS</a><a data-v="tom" onclick="setView('tom')"><b>8</b>TOMORROW</a><a data-v="myfo" onclick="setView('myfo')"><b>9</b>MY F&amp;O</a><a data-v="desk" onclick="setView('desk')"><b>0</b>DESK P&amp;L</a></div>
  <div id="abar"></div><div id="toasts"></div><div id="chkres" hidden></div>
</div>
<div id="grid">
  <section class="p" id="market"><h2>MARKET</h2><div id="mk">
    <div class="q" id="q-ear"><h3>⚡ EARLY <span id="mk-earh">today's signals · BUY = 2+ of 📰🔭💰📈 agree, or critical news alone · tap = its trading screen</span></h3><div class="bd" id="mk-ear"></div></div>
    <div class="q" id="q-mov"><h3>F&amp;O MOVERS<span id="lvq"></span> <span id="mk-movh">% today · tap = its trading screen</span></h3><div class="bd" id="mk-mov"></div></div>
    <div class="q" id="q-nif"><h3>NIFTY · F&amp;O BREADTH <span>through the day</span><span class="ntf" id="nifTf"></span></h3><div class="bd" id="mk-nif"></div></div>
    <div class="q" id="q-don"><h3>SECTORS <span>% today · size = F&amp;O shares · tap = its shares</span></h3><div class="bd" id="mk-don"></div></div>
    <div class="q" id="q-mon"><h3>F&amp;O MONEY <span>fresh futures money today · ₹ cr</span></h3><div class="bd" id="mk-mon"></div></div>
    <div class="q" id="q-dsk"><h3>F&amp;O DESK <span>expiry · PCR · VIX · FII/DII · ban · results</span></h3><div class="bd dk" id="mk-dsk"></div></div>
    <div class="q" id="q-hea"><h3>SECTORS THROUGH THE DAY <span>% · every 30 min</span></h3><div class="bd" id="mk-hea"></div></div>
    <div class="q" id="q-bus"><h3>OI BUILD-UP BY SECTOR <span>futures · number of shares</span></h3><div class="bd" id="mk-bus"></div></div>
    <div class="q" id="q-nws"><h3>OI SCENARIOS · NEWS <span id="mk-nf"></span></h3><div class="bd" id="mk-nws"></div></div>
  </div></section>
  <section class="p" id="now"><h2>NOW <small id="hnow">moving right now · newest first · every line went to Telegram the same second</small></h2><div id="nowl"></div></section>
  <section class="p" id="focus" hidden></section>
  <section class="p" id="three"><h2 id="h3">THE THREE</h2><div id="threel"></div></section>
  <section class="p" id="scn"><h2>OI SCENARIOS <small id="scnh">how the money is building up · today</small></h2><div id="scnl"><div class="empty">the scenario agent reads from 09:20 (open + 5)</div></div></section>
  <section class="p" id="secs"><h2>SECTORS <small>tap a sector to filter the tape · ++ EXTREME · + plain · ✓ confirmed</small></h2><div class="g" id="secg"></div></section>
  <section class="p" id="tape"><h2>F&amp;O TAPE <small id="tfoot"></small></h2><div id="tapel"></div></section>
  <section class="p" id="news"><h2>NEWS <small>filings + headlines · the reader's verdict</small></h2><div id="nreact"></div><div id="newsl"></div></section>
  <section class="p pn xp" id="picks"><h2>PICKS <small id="pkh">where to look now · every F&amp;O share's box, the ones that say BUY</small></h2><div id="pkl"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="tom"><h2>TOMORROW <small id="tmh">buy 14:30 · sell by 09:30 the day after</small></h2><div id="tml"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="myfo"><h2>MY F&amp;O <small>your real trades · net after charges</small></h2><div id="mfl"><div class="empty">loading…</div></div></section>
  <section class="p pn xp" id="desk"><h2>DESK P&amp;L <small>the paper desk · since the start</small></h2><div id="dkl"><div class="empty">loading…</div></div></section>
</div>
<div id="tick"><div class="lb">NEWS</div><div class="run" id="run"></div></div>
<script>
const K=new URLSearchParams(location.search).get("k")||""; const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const pc=v=>v==null?"":(v>=0?"+":"")+Number(v).toFixed(2)+"%"; const cls=v=>v==null?"dim":v>0.05?"pu":v<-0.05?"pd":"dim";
const inr=v=>v==null?"":Number(v).toLocaleString("en-IN",{maximumFractionDigits:2});
let D=null, T3=null, FD=null, FOC="", SEL="", SECS=[], TAPE=[], seen=new Set(), first=true, sortBy="move", showAll=false, LASTIX={};
/* ---------- the index strip ---------- */
function idxHTML(d){ const I=d.idx||{}; const one=(n,x)=>{ if(!x) return ""; const o=LASTIX[n]; const f=(o!=null&&x.last!=null&&x.last!==o)?(x.last>o?" fu":" fd"):""; LASTIX[n]=x.last; return `<div class="ix"><b>${n}</b><div><span class="${f.trim()}">${x.last!=null?inr(x.last):"—"}</span><small class="${cls(x.chg)}">${pc(x.chg)}</small></div></div>`; };
  const deskLive=d.closed&&d.desk_t&&ageMin(d.desk_t)<3; const st=d.closed?(deskLive?`<span class="live">● DESK LIVE ${esc(d.desk_t)} (${esc(d.desk_src||"own pull")})</span>`:'<span class="closed">● CLOSED</span>'):'<span class="live">● LIVE</span>';
  return `<div class="brand" onclick="goHome()" style="cursor:pointer" title="home">⌂ GIR</div>${one("NIFTY",I.NIFTY)}${one("SENSEX",I.SENSEX)}${one("BANKNIFTY",I.BANKNIFTY)}${one("VIX",I.VIX)}<div class="st"><span id="clk">${istClock()}</span>${st}${d.ticks_s?`<span>${Math.round(d.ticks_s)} t/s</span>`:""}<span>${(d.now||[]).length} moving</span><span id="ago"></span>${d.ban&&d.ban.length?`<span class="pd">BAN ${esc(d.ban.join(" "))}</span>`:""}</div>`; }
function istClock(){ const t=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); return t.toTimeString().slice(0,8); }
function ageMin(hm){ const n=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const [h,m]=String(hm).split(":").map(Number); return (n.getHours()*60+n.getMinutes())-(h*60+m); }
let lastAt=0; setInterval(()=>{ const c=$("clk"); if(c) c.textContent=istClock(); const a=$("ago"); if(a&&lastAt) a.textContent=`upd ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s`; },1000);
/* ---------- NOW ---------- */
function nowHTML(rows){ if(!rows.length) return '<div class="empty">nothing has moved yet — the first lines come from 09:16 (🚀 RUNNING · ⚡ FIRST MOVE · 📗 ORDER BOOK) and 09:20 (your rules · 🧩 OI scenarios)</div>';
  return rows.slice(0,40).map(r=>{ const key=r.t+r.head; const isNew=!first&&!seen.has(key); seen.add(key); const sd=r.side==="CE"?"up":r.side==="PE"?"dn":"na";
    const head=(r.head||"").replace(/^(\S+\s+)/,""); const lines=(r.lines||[]).slice(0,3).map(l=>esc(l).replace(/\b(WATCH)\b/g,'<span class="w">$1</span>').replace(/\b(BUY)\b/g,'<span class="b">$1</span>')).join("\n");
    return `<div class="r${isNew?" new":""}" onclick="focusOn('${esc(r.s)}')"><div class="t">${esc(r.t)}</div><div class="s">${esc(r.s||"")}</div><div class="side ${sd}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"—"}</div><div class="h">${esc(r.kind||"")} ${esc(head)}</div>${lines?`<div class="l">${lines}</div>`:""}</div>`; }).join(""); }
/* ---------- THE THREE ---------- */
function threeHTML(T){ const ev=T&&T.evening, lv=T&&T.live; const X=(lv&&(lv.rows||[]).length)?lv:ev; if(!X||!(X.rows||[]).length){ $("h3").textContent="THE THREE"; return '<div class="empty">no list yet — the newsroom builds it at 18:30</div>'; }
  $("h3").innerHTML=(X===ev)?`THE THREE <small>for tomorrow · newsroom ${esc(X.t||"18:30")} · buy at 14:30, sell by 09:30 the day after</small>`:`THE THREE <small>today · ${esc(X.phase||"")}</small>`;
  return X.rows.slice(0,3).map(r=>{ const up=r.side==="CE"; const v=r.verdict||""; const vc=/^WAIT/.test(v)?"dn":/^WATCH|^SELL/.test(v)?"wt":(up?"pu":"pd"); const e=r.edge;
    return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="rk">${r.rank}</div><div class="l1"><b>${esc(r.s)}</b><span class="sd ${up?"pu":"pd"}">${up?"UP → CE":"DOWN → PE"}</span> <span class="${cls(r.chg)}">₹${inr(r.spot)} ${pc(r.chg)}</span></div><div></div>
      <div class="vd ${vc}">${esc(v.slice(0,150))}</div>
      <div class="l2">${r.k?`<em>${r.k} ${esc(r.side)} ₹${r.p}</em> · 1 lot ₹${inr(r.cost||0)} · stop ₹${r.stop_p} / share ${r.stop_share??"—"}${r.tgt?` · target ${r.tgt}`:""} · `:""}${e?`rule ${e[0]}% of ${e[1]}`:"not measured yet"}</div></div>`; }).join(""); }
async function loadThree(){ try{ const r=await fetch("three?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ T3=await r.json(); $("threel").innerHTML=threeHTML(T3); } }catch(e){} }
/* ---------- SECTORS ---------- */
function heat(c){ if(c==null) return "transparent"; const a=Math.min(1,Math.abs(c)/2.5)*0.55+0.08; return c>=0?`rgba(30,215,96,${a.toFixed(2)})`:`rgba(255,59,74,${a.toFixed(2)})`; }
function secHTML(S){ if(!S.length) return '<div class="empty">no sectors yet</div>';
  return S.map(s=>{ const ce=(s.ce||[])[0], pe=(s.pe||[])[0]; const pill=(ce&&Math.abs(ce.v)===2)?'<span class="pl pu">++</span>':(pe&&Math.abs(pe.v)===2)?'<span class="pl pd">++</span>':(ce||pe)?`<span class="pl ${ce?"pu":"pd"}">+</span>`:"";
    return `<div class="c${SEL===s.name?" sel":""}" style="background:${heat(s.chg)}" onclick="pickSector('${esc(s.name)}')">${pill}<div class="n">${esc(s.name)}</div><div class="v ${cls(s.chg)}">${s.chg==null?"—":pc(s.chg)}</div><div class="tb">${ce?`<span class="pu">${esc(ce.s)}${ce.conf?"✓":""}</span>`:""}${ce&&pe?" · ":""}${pe?`<span class="pd">${esc(pe.s)}${pe.conf?"✓":""}</span>`:""}${!ce&&!pe&&s.top?`<span class="pu">${esc(s.top.s)} ${pc(s.top.chg)}</span>`:""}</div></div>`; }).join(""); }
function pickSector(n){ SEL=(SEL===n)?"":n; $("secsel").value=SEL; drawSecs(); drawTape(); }
function drawSecs(){ $("secg").innerHTML=secHTML(SECS); }
/* ---------- TAPE ---------- */
function meter(v){ let h=""; for(let i=-2;i<=2;i++){ if(i===0){ h+='<i style="width:3px;background:var(--line2)"></i>'; continue; } const on=(v>0&&i>0&&i<=v)||(v<0&&i<0&&i>=v); h+=`<i class="${on?(v>0?"u":"d"):""}"></i>`; } return h; }
function sectorSyms(){ const s=SECS.find(x=>x.name===SEL); return s?new Set(s.syms||[]):null; }
let LASTPX={};
function drawTape(){ const set=sectorSyms(); let rows=set?TAPE.filter(r=>set.has(r.s)):TAPE.slice();
  const by={move:(a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0), desk:(a,b)=>Math.abs(b.v||0)-Math.abs(a.v||0)||Math.abs(b.chg||0)-Math.abs(a.chg||0), name:(a,b)=>a.s<b.s?-1:1, chg:(a,b)=>(b.chg||0)-(a.chg||0)};
  rows.sort(by[sortBy]||by.move); const n=rows.length; if(!showAll&&window.innerWidth<900) rows=rows.slice(0,40);
  const th=(k,l)=>`<th class="${sortBy===k?"on":""}" onclick="sortBy='${k}';drawTape()">${l}${sortBy===k?" ▾":""}</th>`;
  $("tapel").innerHTML=`<table><thead><tr>${th("name","SHARE")}${th("chg","PRICE")}${th("move","CHG")}${th("desk","DESK")}<th>WHAT THE OI SAYS</th></tr></thead><tbody>`+
    rows.map(r=>{ const o=LASTPX[r.s]; const f=(o!=null&&r.px!=null&&r.px!==o)?(r.px>o?" fu":" fd"):""; return `<tr onclick="focusOn('${esc(r.s)}')"><td class="s">${esc(r.s)}</td><td class="px hi${f}">${r.px!=null?inr(r.px):"—"}</td><td class="ch ${cls(r.chg)}">${pc(r.chg)}</td><td class="m">${meter(r.v||0)}${r.conf?'<span class="pu"> ✓</span>':""}</td><td class="oi">${esc(r.oi||(r.bu?r.bu.toLowerCase()+(r.cr?` ₹${Math.round(r.cr)} cr`:""):"—"))}</td></tr>`; }).join("")+
    `</tbody></table>`+(n>rows.length?`<div class="more" onclick="showAll=true;drawTape()">show all ${n} shares</div>`:"");
  LASTPX={}; for(const r of TAPE) LASTPX[r.s]=r.px;
  $("tfoot").textContent=`${n} ${SEL?SEL+" ":""}shares · ${D&&D.desk_t?`desk ${D.desk_t} (${D.desk_src||""})`:`desk: no reading yet`}`; }
/* ---------- NEWS ---------- */
function newsHTML(N){ if(!N.length) return '<div class="empty">no news read in the last 26 hours</div>';
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${x.s==="MARKET"?"🏛 MARKET":esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${nlink(x)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${x.s==="MARKET"?"🏛 MARKET":esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${nlink(x)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
function tickSize(){ const R=$("run"); if(!R) return; const w=R.scrollWidth; if(!w) return; R.style.setProperty("--tw",(-w)+"px"); R.style.setProperty("--tdur",Math.max(20,w/33).toFixed(0)+"s"); }   // patch 113
window.addEventListener("resize",()=>tickSize()); (()=>{ const T=document.getElementById("tick"); if(T) T.addEventListener("click",e=>{ if(!e.target.closest("a")) T.classList.toggle("hold"); }); })();
/* ---------- OI SCENARIOS (patch 84) ---------- */
const SCAT={};
function scnPill(c){ return c.side==="CE"?'<span class="sd pu">UP → CE</span>':c.side==="PE"?'<span class="sd pd">DOWN → PE</span>':c.side==="dyn"?'<span class="sd am">TURN</span>':'<span class="sd dim">READING</span>'; }
function scnHTML(S){ if(!S||!S.cat) return '<div class="empty">the scenario agent reads from 09:20 (open + 5)</div>';
  for(const c of S.cat) SCAT[c.id]=c; const sc=S.scores||{}; const by={};
  for(const r of (S.today||[])) (by[r.id]=by[r.id]||[]).push(r);
  const ids=Object.keys(by).sort((a,b)=>by[b].length-by[a].length);
  const ms=id=>{ const v=sc[id]; const a=(SCAT[id]||{}).acts; return v?(v[1]>=50&&v[0]>=55?`<b>${v[0]}% of ${v[1]}${a?" · BUY":" · proven"}</b>`:`${v[0]}% of ${v[1]}`):(a?"new · WATCH":"new"); };
  let h=ids.map(id=>{ const c=SCAT[id]||{name:id}; const seen=new Set(), syms=[]; for(const r of by[id].slice().reverse()){ if(!seen.has(r.s)){ seen.add(r.s); syms.push(r); } }
    return `<div class="r"><div class="nm">${esc(c.name)}${scnPill(c)}</div><div class="n">${by[id].length}</div><div class="ms">${ms(id)}</div><div class="sy">${syms.slice(0,8).map(r=>`<a class="${r.ch==="box"?"box":""}" onclick="focusOn('${esc(r.s)}')">${esc(r.s)} <span class="dim">${esc(r.t)}</span></a>`).join("")}${syms.length>8?`<span>+${syms.length-8} more</span>`:""}</div></div>`; }).join("");
  if(!ids.length) h='<div class="empty">no OI scenario has fired yet today</div>';
  const quiet=S.cat.filter(c=>!by[c.id]).map(c=>c.name.toLowerCase());
  return h+`<div class="ft">${S.cat.length} scenarios watched on every F&amp;O share every 5 s · a scenario fires after holding ${S.hold||60} s, once a share a day · green share = went to Box Picks (measured BUY) · the number = right on the same-day close, this server · quiet today: ${esc(quiet.join(" · "))}</div>`; }
function scnRibbon(sym){ const f=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===sym).slice(-3).reverse(); if(!f.length) return "";
  return `<div class="rib">🧩 ${f.map(r=>`<b>${esc(r.t)}</b> ${esc(r.name)} <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span>`).join(" · ")} <span class="dim">· the OI BUILD-UP tab has the numbers · 🧩 marks them on the chart</span></div>`; }
function scnFocus(){ const d=FD&&FD.desk; const hold=((d&&d.scn)||[]).filter(h=>!h.fired); const fired=((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).slice().reverse();
  if(!hold.length&&!fired.length) return '<div class="scl"><div class="dim">OI SCENARIOS on this share: nothing has built up yet today</div></div>';
  return `<div class="scl">${fired.map(r=>`<div><b class="am">${esc(r.t)}</b> 🧩 <b>${esc(r.name)}</b> <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"UP → CE":r.side==="PE"?"DOWN → PE":"reading"}</span> · ${esc(r.word)}${r.ch==="box"?" · went to Box Picks":r.ch==="read"?" · GIR Intraday":""}<br><span class="dim">${esc(r.line)}</span></div>`).join("")}${hold.map(h=>`<div><span class="am">holding ${h.held}s</span> 🧩 ${esc(h.name)} <span class="dim">— ${esc(h.line)}</span></div>`).join("")}</div>`; }
/* ---------- THE TRADING VIEW (patch 85): OI left, chart right, one price scale ---------- */
function vwapSeries(C,H,L,V){ let pv=0,vv=0; return C.map((c,i)=>{ if(c==null) return null; const tp=((H[i]??c)+(L[i]??c)+c)/3, v=V[i]||0; pv+=tp*v; vv+=v; return vv?pv/vv:c; }); }
function wallsOf(rows,spot){ let roof=null,floor=null; for(const r of rows){ if(r.k>=spot&&(r.ce_oi||0)>0&&(!roof||r.ce_oi>roof.oi)) roof={k:r.k,oi:r.ce_oi}; if(r.k<=spot&&(r.pe_oi||0)>0&&(!floor||r.pe_oi>floor.oi)) floor={k:r.k,oi:r.pe_oi}; } return {roof,floor}; }
function minIdx(hm){ const m=String(hm||"").match(/(\d+):(\d+)/); if(!m) return null; return Math.floor(((+m[1])*60+(+m[2])-555)/5); }
function chartPatterns(O,H,L,C,V,roof,floor){ const n=C.length, marks=[], txt=[]; let orb=null;
  const okH=H.slice(0,3).filter(x=>x!=null), okL=L.slice(0,3).filter(x=>x!=null);
  if(n>=4&&okH.length){ orb={hi:Math.max(...okH),lo:Math.min(...okL)}; let br=null;
    for(let i=3;i<n;i++){ if(C[i]==null) continue; if(C[i]>orb.hi){ br={i,up:true}; break; } if(C[i]<orb.lo){ br={i,up:false}; break; } }
    if(br){ marks.push({i:br.i,up:br.up,t:br.up?"ORB▲":"ORB▼"}); txt.push(`opening range ${inr(orb.lo)}–${inr(orb.hi)} broke <span class="${br.up?"u":"d"}">${br.up?"UP":"DOWN"}</span> at <b>${hhmm(br.i+1)}</b>`); }
    else txt.push(`still inside the opening range ${inr(orb.lo)}–${inr(orb.hi)}`); }
  const vw=vwapSeries(C,H,L,V); let side=null,lastX=null;
  for(let i=1;i<n;i++){ if(C[i]==null||vw[i]==null) continue; const sd=C[i]>=vw[i]; if(side!==null&&sd!==side) lastX={i,up:sd}; side=sd; }
  if(lastX){ marks.push({i:lastX.i,up:lastX.up,t:lastX.up?"VWAP▲":"VWAP▼"}); txt.push(`<span class="${side?"u":"d"}">${side?"above":"below"}</span> VWAP since <b>${hhmm(lastX.i+1)}</b>`); }
  else if(side!==null) txt.push(`<span class="${side?"u":"d"}">${side?"above":"below"}</span> VWAP all day`);
  let hi=-Infinity,lo=Infinity,nh=null,nl=null;
  for(let i=0;i<n;i++){ if(H[i]!=null){ if(i>=9&&H[i]>hi&&C[i]!=null&&C[i]>=hi) nh=i; hi=Math.max(hi,H[i]); } if(L[i]!=null){ if(i>=9&&L[i]<lo&&C[i]!=null&&C[i]<=lo) nl=i; lo=Math.min(lo,L[i]); } }
  if(nh!=null&&(nl==null||nh>nl)){ marks.push({i:nh,up:true,t:"HIGH▲"}); txt.push(`new day high closed at <b>${hhmm(nh+1)}</b>`); }
  else if(nl!=null){ marks.push({i:nl,up:false,t:"LOW▼"}); txt.push(`new day low closed at <b>${hhmm(nl+1)}</b>`); }
  for(const [w,isR] of [[roof,true],[floor,false]]){ if(!w) continue; let tests=0,brk=null,prev=null;
    for(let i=0;i<n;i++){ if(C[i]==null) continue; const beyond=isR?C[i]>w.k:C[i]<w.k;
      if(beyond&&prev===false) brk=i;                                   // a cross FROM the protected side only
      if(!beyond){ if(isR?(H[i]!=null&&H[i]>=w.k*0.997):(L[i]!=null&&L[i]<=w.k*1.003)) tests++; }
      prev=beyond; }
    const nowBeyond=n&&C[n-1]!=null&&(isR?C[n-1]>w.k:C[n-1]<w.k);
    if(brk!=null&&nowBeyond){ marks.push({i:brk,up:isR,t:(isR?"ROOF ":"FLOOR ")+w.k}); txt.push(`closed ${isR?"above the roof":"below the floor"} <b>${w.k}</b> at <b>${hhmm(brk+1)}</b> and is holding — the ${isR?"call":"put"} sellers there are trapped`); }
    else if(brk!=null){ marks.push({i:brk,up:!isR,t:"FAIL "+w.k}); txt.push(`broke ${isR?"above the roof":"below the floor"} <b>${w.k}</b> at <b>${hhmm(brk+1)}</b> and fell back — <span class="${isR?"d":"u"}">a failed break</span>`); }
    else if(tests) txt.push(`tested the ${isR?"roof":"floor"} <b>${w.k}</b> ${tests}× — it held`); }
  const k=[]; for(let i=Math.max(0,n-7);i<n;i++) if(L[i]!=null&&H[i]!=null) k.push(i);
  if(k.length>=5){ let hl=0,lh=0; for(let j=1;j<k.length;j++){ if(L[k[j]]>L[k[j-1]]) hl++; if(H[k[j]]<H[k[j-1]]) lh++; }
    if(hl>=k.length-2) txt.push(`<span class="u">trend up</span>: ${hl} of the last ${k.length-1} candles made a higher low`);
    else if(lh>=k.length-2) txt.push(`<span class="d">trend down</span>: ${lh} of the last ${k.length-1} candles made a lower high`);
    else txt.push("no clear trend in the last 30 min"); }
  return {marks,txt,orb,vw}; }
function tradingView(ch,lv,opt){ opt=opt||{}; const box=(opt.box&&$(opt.box))||$("fbody")||$("focus"); const W=Math.max(320,Math.floor((box&&box.clientWidth)||700)); const phone=W<600; const Hh=opt.h||(phone?320:360);
  const rows=oiRows(); const spot=(lv&&lv.px)||(FD&&(FD.px||FD.spot))||0;
  const n=ch&&ch.c?ch.c.length:0; const O=n?ch.o.slice():[],H=n?ch.h.slice():[],L=n?ch.l.slice():[],C=n?ch.c.slice():[],V=n?(ch.v||[]).slice():[];
  if(n&&lv&&lv.px!=null){ const i=n-1; C[i]=lv.px; H[i]=Math.max(H[i]??lv.px,lv.px); L[i]=Math.min(L[i]??lv.px,lv.px); }
  const {roof,floor}=wallsOf(rows,spot||C[n-1]||0);
  const P=chartPatterns(O,H,L,C,V,roof,floor);
  let vals=[].concat(H,L).filter(x=>x!=null); if(spot) vals.push(spot); if(roof) vals.push(roof.k); if(floor) vals.push(floor.k);
  if(!vals.length) return {svg:'<div class="empty">no price and no strikes read yet</div>',txt:[]};
  const ref=spot||vals[vals.length-1]; let lo=Math.max(Math.min(...vals),ref*0.94), hi=Math.min(Math.max(...vals),ref*1.06); const pad=(hi-lo)*0.06||ref*0.01; lo-=pad; hi+=pad;
  const LW=opt.profile===false?0:Math.round(W*(phone?0.40:0.34)), RX0=opt.profile===false?0:LW+4, RM=phone?50:58, T=18, B=18, VH=phone?22:30;
  const y=v=>T+(Hh-T-B-VH)*(1-(v-lo)/(hi-lo)); const ybot=Hh-B;
  let g=`<rect x="0" y="0" width="${LW}" height="${Hh}" fill="#05070a"/>`;
  // ---- left: the OI at each strike, on the chart's price scale
  if(LW>0){
  const vis=rows.filter(r=>r.k>=lo&&r.k<=hi).sort((a,b)=>b.k-a.k);
  const gapPx=vis.length>1?Math.min(...vis.slice(1).map((r,i)=>Math.abs(y(vis[i].k)-y(r.k)))):20; const bh=Math.max(2,Math.min(phone?7:9,gapPx*0.42));
  const mx=Math.max(...vis.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=LW/2, KWH=phone?19:23, half=KX-KWH-2;
  const atm=vis.length?vis.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,vis[0]):null;
  g+=`<text x="4" y="12" fill="var(--ce)" font-size="10" font-family="monospace">CALLS</text><text x="${LW-4}" y="12" fill="var(--pe)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  for(const r of vis){ const yy=y(r.k); const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    const bar=(oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
      let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
      if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
      if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
      return o; };
    g+=bar(r.ce_oi,r.ce_d,-1,"var(--ce)")+bar(r.pe_oi,r.pe_d,1,"var(--pe)");
    g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="${phone?9:10}" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; }
  }
  // ---- right: the candles
  const NB=Math.min(75,Math.max(n+6,42)); const bw=(W-RX0-RM)/NB; const cx=i=>RX0+i*bw+bw/2;     // the session so far, widening through the day
  [0,0.25,0.5,0.75,1].forEach(f=>{ const v=lo+(hi-lo)*f; g+=`<line x1="${RX0}" x2="${W-RM}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-RM+3}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace">${inr(Math.round(v*10)/10)}</text>`; });
  if(P.orb) g+=`<rect x="${RX0}" y="${y(P.orb.hi).toFixed(1)}" width="${(3*bw).toFixed(1)}" height="${Math.max(1,y(P.orb.lo)-y(P.orb.hi)).toFixed(1)}" fill="var(--amber)" opacity=".10"/><line x1="${RX0}" x2="${W-RM}" y1="${y(P.orb.hi).toFixed(1)}" y2="${y(P.orb.hi).toFixed(1)}" stroke="var(--amber)" stroke-dasharray="1 4" opacity=".5"/><line x1="${RX0}" x2="${W-RM}" y1="${y(P.orb.lo).toFixed(1)}" y2="${y(P.orb.lo).toFixed(1)}" stroke="var(--amber)" stroke-dasharray="1 4" opacity=".5"/>`;
  if(ch&&ch.pc!=null&&ch.pc>lo&&ch.pc<hi) g+=`<line x1="${RX0}" x2="${W-RM}" y1="${y(ch.pc).toFixed(1)}" y2="${y(ch.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${W-RM+3}" y="${(y(ch.pc)-3).toFixed(1)}" fill="var(--dim)" font-size="8" font-family="monospace">prev</text>`;
  // the roof and the floor: across BOTH panes - the day's resistance and support, from the OI
  for(const [w,col,lab] of [[roof,"var(--dn)","ROOF"],[floor,"var(--up)","FLOOR"]]){ if(!w||w.k<lo||w.k>hi) continue;
    g+=`<line x1="0" x2="${W-RM}" y1="${y(w.k).toFixed(1)}" y2="${y(w.k).toFixed(1)}" stroke="${col}" stroke-width="1.2" stroke-dasharray="6 3" opacity=".85"/><text x="${RX0+4}" y="${(y(w.k)+(lab==="ROOF"?-4:11)).toFixed(1)}" fill="${col}" font-size="10" font-weight="700" font-family="monospace">${lab} ${w.k} · ${fmtL(w.oi)} ${lab==="ROOF"?"calls":"puts"}</text>`; }
  const vmax=Math.max(...V.filter(x=>x),1);
  for(let i=0;i<n;i++){ if(C[i]==null||O[i]==null) continue; const x=cx(i), up=C[i]>=O[i], col=up?"var(--up)":"var(--dn)";
    g+=`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(H[i]).toFixed(1)}" y2="${y(L[i]).toFixed(1)}" stroke="${col}"/>`;
    const y0=y(Math.max(O[i],C[i])), y1=y(Math.min(O[i],C[i])); g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${y0.toFixed(1)}" width="${Math.max(1,bw*0.72).toFixed(1)}" height="${Math.max(1,y1-y0).toFixed(1)}" fill="${col}"/>`;
    if(V[i]) g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${(ybot-(V[i]/vmax)*(VH-4)).toFixed(1)}" width="${Math.max(1,bw*0.72).toFixed(1)}" height="${((V[i]/vmax)*(VH-4)).toFixed(1)}" fill="${col}" opacity=".35"/>`; }
  const vpts=P.vw.map((v,i)=>v==null?null:`${cx(i).toFixed(1)},${y(v).toFixed(1)}`).filter(Boolean); if(vpts.length>1) g+=`<polyline fill="none" stroke="var(--amber)" stroke-width="1.3" points="${vpts.join(" ")}"/>`;
  for(const m of P.marks){ if(m.i==null||H[m.i]==null) continue; const x=cx(m.i), yy=m.up?y(L[m.i])+12:y(H[m.i])-6;
    g+=`<text x="${x.toFixed(1)}" y="${Math.min(ybot-VH,Math.max(T+8,yy)).toFixed(1)}" fill="${m.up?"var(--up)":"var(--dn)"}" font-size="9" font-weight="700" font-family="monospace" text-anchor="middle">${m.t}</text>`; }
  for(const r of ((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC)){ const i=minIdx(r.t); if(i==null||i<0||i>74) continue;
    if(i>=NB) continue;
    g+=`<g><title>${esc(r.t+" "+r.name)}</title><text x="${cx(i).toFixed(1)}" y="${T-4}" font-size="10" text-anchor="middle">🧩</text><line x1="${cx(i).toFixed(1)}" x2="${cx(i).toFixed(1)}" y1="${T}" y2="${ybot-VH}" stroke="var(--amber)" stroke-dasharray="1 3" opacity=".35"/></g>`; }
  const last=n?C[n-1]:spot; if(last!=null){ const upd=ch&&ch.pc!=null?last>=ch.pc:true;
    g+=`<line x1="0" x2="${W-RM}" y1="${y(last).toFixed(1)}" y2="${y(last).toFixed(1)}" stroke="${upd?"var(--up)":"var(--dn)"}" stroke-dasharray="2 3" opacity=".55"/><rect x="${W-RM+1}" y="${(y(last)-8).toFixed(1)}" width="${RM-2}" height="15" fill="${upd?"var(--up)":"var(--dn)"}"/><text x="${W-RM+4}" y="${(y(last)+3).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(last)}</text>`; }
  [0,6,12,18,24,30,36,42,48,54,60,66,72].filter(i=>i<NB).filter((i,j,a)=>NB<=48||j%2===0).forEach(i=>{ g+=`<text x="${cx(i).toFixed(1)}" y="${Hh-5}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="${i===0?"start":"middle"}">${hhmm(i)}</text>`; });
  if(LW>0) g+=`<line x1="${LW+1.5}" x2="${LW+1.5}" y1="0" y2="${Hh}" stroke="var(--line2)"/>`;
  return {svg:`<svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${g}</svg>`,txt:P.txt}; }
window.addEventListener("resize",()=>{ if(FOC){ const F=$("focus"); if(window.innerWidth<900){ F.classList.remove("ws-on"); F.classList.add("sheet"); } else { F.classList.remove("sheet"); F.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); } paint(); } });
/* ---------- FOCUS: the share's own live window ---------- */
let FT={live:null,chart:null,oi:null}, FCH=null, FLV=null, FOI=null, FTAB="chart";
const fmtL=v=>v==null?"—":(Math.abs(v)>=1e5?(v/1e5).toFixed(2)+" L":Math.round(v).toLocaleString("en-IN"));
const dL=v=>v==null?"":(v>=0?"+":"−")+(Math.abs(v)>=1e5?(Math.abs(v)/1e5).toFixed(2)+" L":Math.round(Math.abs(v)).toLocaleString("en-IN"));
function hhmm(i){ const m=9*60+15+i*5; return `${String(Math.floor(m/60)).padStart(2,"0")}:${String(m%60).padStart(2,"0")}`; }
function candleSVG(ch,lv){ if(!ch||!(ch.c||[]).length) return '<div class="empty">no candles yet today</div>';
  const n=ch.c.length; const O=ch.o.slice(),H=ch.h.slice(),L=ch.l.slice(),C=ch.c.slice(),V=ch.v||[];
  if(lv&&lv.px!=null&&n){ const i=n-1; C[i]=lv.px; H[i]=Math.max(H[i]??lv.px,lv.px); L[i]=Math.min(L[i]??lv.px,lv.px); }
  const W=720,Hh=230,Lm=6,Rm=58,T=10,B=22,VH=34; const bw=(W-Lm-Rm)/75; const vals=[].concat(H,L,[ch.pc,ch.vw].filter(x=>x!=null)).filter(x=>x!=null);
  let lo=Math.min(...vals), hi=Math.max(...vals); const pad=(hi-lo)*0.06||1; lo-=pad; hi+=pad; const y=v=>T+(Hh-T-B-VH)*(1-(v-lo)/(hi-lo));
  const vmax=Math.max(...V,1); const yv=v=>(Hh-B)-(v/vmax)*(VH-4);
  let g=""; for(let i=0;i<n;i++){ if(C[i]==null||O[i]==null) continue; const x=Lm+i*bw+bw/2; const up=C[i]>=O[i]; const col=up?"var(--up)":"var(--dn)";
    g+=`<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(H[i]).toFixed(1)}" y2="${y(L[i]).toFixed(1)}" stroke="${col}" stroke-width="1"/>`;
    const y0=y(Math.max(O[i],C[i])), y1=y(Math.min(O[i],C[i])); g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${y0.toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${Math.max(1,y1-y0).toFixed(1)}" fill="${up?"var(--up)":"var(--dn)"}"/>`;
    if(V[i]) g+=`<rect x="${(x-bw*0.36).toFixed(1)}" y="${yv(V[i]).toFixed(1)}" width="${(bw*0.72).toFixed(1)}" height="${((Hh-B)-yv(V[i])).toFixed(1)}" fill="${col}" opacity=".35"/>`; }
  const grid=[0,0.25,0.5,0.75,1].map(f=>{ const v=lo+(hi-lo)*f; return `<line x1="${Lm}" x2="${W-Rm}" y1="${y(v).toFixed(1)}" y2="${y(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-Rm+4}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(Math.round(v*10)/10)}</text>`; }).join("");
  const xs=[0,12,24,36,48,60,72].map(i=>`<text x="${(Lm+i*bw).toFixed(1)}" y="${Hh-6}" fill="var(--dim)" font-size="10" font-family="monospace">${hhmm(i)}</text>`).join("");
  const pcl=ch.pc!=null?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pc).toFixed(1)}" y2="${y(ch.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${W-Rm+4}" y="${(y(ch.pc)-4).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace">prev ${inr(ch.pc)}</text>`:"";
  const vwl=ch.vw!=null?`<line x1="${Lm}" x2="${(Lm+n*bw).toFixed(1)}" y1="${y(ch.vw).toFixed(1)}" y2="${y(ch.vw).toFixed(1)}" stroke="var(--amber)" stroke-width="1" opacity=".8"/><text x="${W-Rm+4}" y="${(y(ch.vw)+10).toFixed(1)}" fill="var(--amber)" font-size="9" font-family="monospace">vwap ${inr(ch.vw)}</text>`:"";
  const last=C[n-1]; const up=ch.pc!=null?last>=ch.pc:true;
  const lpx=last!=null?`<rect x="${W-Rm+1}" y="${(y(last)-8).toFixed(1)}" width="${Rm-2}" height="15" fill="${up?"var(--up)":"var(--dn)"}"/><text x="${W-Rm+4}" y="${(y(last)+3).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(last)}</text><line x1="${Lm}" x2="${W-Rm}" y1="${y(last).toFixed(1)}" y2="${y(last).toFixed(1)}" stroke="${up?"var(--up)":"var(--dn)"}" stroke-dasharray="2 3" opacity=".7"/>`:"";
  const pdh=ch.pdh!=null&&ch.pdh<hi&&ch.pdh>lo?`<line x1="${Lm}" x2="${W-Rm}" y1="${y(ch.pdh).toFixed(1)}" y2="${y(ch.pdh).toFixed(1)}" stroke="var(--line2)" stroke-dasharray="1 4"/>`:"";
  return `<svg class="px" viewBox="0 0 ${W} ${Hh}" preserveAspectRatio="none">${grid}${pdh}${pcl}${vwl}${g}${lpx}${xs}</svg>`; }
function oiRows(){ const o=(FLV&&FLV.ok&&FLV.o&&Object.keys(FLV.o).length&&!(FOI&&FOI.exp&&FLV.exp&&String(FLV.exp).slice(0,10)!==String(FOI.exp).slice(0,10)))?FLV.o:null; const R=(FOI&&FOI.rows)||{}; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||(FD&&FD.px);
  let ks=o?Object.keys(o).map(Number):(FD&&FD.strikes||[]).map(x=>x.k); if(!ks.length) ks=Object.keys(R).map(Number); ks=[...new Set(ks)].filter(k=>k&&spot&&Math.abs(k/spot-1)<=0.08).sort((a,b)=>b-a);
  return ks.map(k=>{ const kk=String(k); const lo=o&&(o[kk]||o[("%s"===""?kk:kk)]); const ref=R[("%g".length,String(+k))]||R[kk]||{}; const fs=(FD&&FD.strikes||[]).find(x=>x.k===k)||{};
    const ce_oi=lo?lo[1]:(ref.ce?ref.ce[1]:fs.ce), pe_oi=lo?lo[3]:(ref.pe?ref.pe[1]:fs.pe), ce_p=lo?lo[0]:(ref.ce?ref.ce[2]:null), pe_p=lo?lo[2]:(ref.pe?ref.pe[2]:null);
    const ce_d=(ref.ce&&ref.ce[0]!=null&&ce_oi!=null)?ce_oi-ref.ce[0]:null, pe_d=(ref.pe&&ref.pe[0]!=null&&pe_oi!=null)?pe_oi-ref.pe[0]:null;
    return {k,ce_oi,pe_oi,ce_p,pe_p,ce_d,pe_d}; }); }
function oiTable(){ let rows=oiRows(); if(OIS.f){ const sp=(FLV&&FLV.px)||(FD&&FD.spot)||0; const near=rows.slice().sort((a,b)=>Math.abs(a.k-sp)-Math.abs(b.k-sp)).slice(0,11).map(r=>r.k);
    rows=rows.filter(r=>OIS.f==="near"?near.includes(r.k):OIS.f==="ce"?(r.ce_d||0)>0:OIS.f==="pe"?(r.pe_d||0)>0:OIS.f==="cl"?((r.ce_d||0)<0||(r.pe_d||0)<0):true); if(!rows.length) return '<div class="empty">no strike matches this filter</div>'; } if(OIS.k!=="k"||OIS.dir!==-1){ const f=r=>r[OIS.k]??-1e18; rows.sort((a,b)=>(f(a)<f(b)?-1:f(a)>f(b)?1:0)*OIS.dir); } if(!rows.length) return '<div class="empty">no strikes read yet</div>'; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||0;
  const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const atm=rows.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,rows[0]);
  const roof=FD&&FD.roof&&FD.roof.k, floor=FD&&FD.floor&&FD.floor.k; let tce=0,tpe=0,tced=0,tped=0,hasd=false;
  const tr=rows.map(r=>{ tce+=r.ce_oi||0; tpe+=r.pe_oi||0; if(r.ce_d!=null){tced+=r.ce_d;hasd=true;} if(r.pe_d!=null){tped+=r.pe_d;}
    const cw=((r.ce_oi||0)/mx*100).toFixed(0), pw=((r.pe_oi||0)/mx*100).toFixed(0);
    return `<tr class="${r===atm?"atm":""}${(r.k===roof||r.k===floor)?" wall":""}"><td class="d ${r.ce_d>0?"up":r.ce_d<0?"dn":""}"><span>${dL(r.ce_d)}</span></td><td class="ce"><i style="width:${cw}%"></i><span>${fmtL(r.ce_oi)}</span></td><td><span>${r.ce_p!=null?r.ce_p:"—"}</span></td><td class="k">${r.k}</td><td class="l"><span>${r.pe_p!=null?r.pe_p:"—"}</span></td><td class="pe l"><i style="width:${pw}%"></i><span>${fmtL(r.pe_oi)}</span></td><td class="d l ${r.pe_d>0?"up":r.pe_d<0?"dn":""}"><span>${dL(r.pe_d)}</span></td></tr>`; }).join("");
  const pcr=tce?(tpe/tce).toFixed(2):"—";
  return `<table class="oi"><thead><tr>${oth("ce_d","CE ΔOI","")}${oth("ce_oi","CE OI","")}${oth("ce_p","CE LTP","")}${oth("k","STRIKE","k")}${oth("pe_p","PE LTP","l")}${oth("pe_oi","PE OI","l")}${oth("pe_d","PE ΔOI","l")}</tr></thead><tbody>${tr}<tr class="tot"><td class="d ${tced>0?"up":tced<0?"dn":""}"><span>${hasd?dL(tced):""}</span></td><td><span>${fmtL(tce)}</span></td><td><span class="dim">calls</span></td><td class="k">PCR ${pcr}</td><td class="l"><span class="dim">puts</span></td><td class="l"><span>${fmtL(tpe)}</span></td><td class="d l ${tped>0?"up":tped<0?"dn":""}"><span>${hasd?dL(tped):""}</span></td></tr></tbody></table>`; }
let OIT="chg"; try{ OIT=localStorage.getItem("gir_oit")||"chg"; }catch(e){}
function oitMode(m){ OIT=m; try{ localStorage.setItem("gir_oit",m); }catch(e){} paint(); }
function oiTrendData(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return null; const n=S.t.length;
  const ce=S.ce.slice(), pe=S.pe.slice(); const sp=(S.spot||[]).map(v=>v==null?null:+v);
  return {n, t:S.t, ce, pe, sp, ced:ce.map(v=>v-ce[0]), ped:pe.map(v=>v-pe[0]), pcr:ce.map((v,i)=>v?pe[i]/v:null)}; }
function oitRead(D,i){ const sg=v=>(v>0?"+":"")+fmtL(v).replace(/^\+/,""); const pcr=D.pcr[i];
  return `<b class="am">${esc(D.t[i])}</b> · <span style="color:var(--ce)">CALLS <b>${fmtL(D.ce[i])}</b> (${sg(D.ced[i])})</span> · <span style="color:var(--pe)">PUTS <b>${fmtL(D.pe[i])}</b> (${sg(D.ped[i])})</span> · PCR <b>${pcr!=null?pcr.toFixed(2):"—"}</b>${D.sp[i]!=null?` · price <b class="am">₹${inr(D.sp[i])}</b>`:""}`; }
function oiTrendSVG(boxId,hh){ const D=oiTrendData(); if(!D) return "";
  const box=boxId&&$(boxId); const W=Math.max(260,Math.floor((box&&box.clientWidth)||560)); const H=hh||Math.max(190,Math.min(260,Math.round(W*0.42)));
  const L=50,R=56,T=10,B=20, n=D.n; const pw=W-L-R, ph=H-T-B; const x=i=>L+pw*(i/(n-1));
  const ser=OIT==="tot"?[[D.ce,"var(--ce)"],[D.pe,"var(--pe)"]]:OIT==="pcr"?[[D.pcr,"#4fc3f7"]]:[[D.ced,"var(--ce)"],[D.ped,"var(--pe)"]];
  const vals=[].concat(...ser.map(z=>z[0])).filter(v=>v!=null); if(OIT!=="tot") vals.push(OIT==="pcr"?1:0);
  let lo=Math.min(...vals), hi=Math.max(...vals); if(hi===lo){ hi+=1; lo-=1; } const pad=(hi-lo)*0.08; lo-=pad; hi+=pad;
  const y=v=>T+ph*(1-(v-lo)/(hi-lo)); const fy=v=>OIT==="pcr"?v.toFixed(2):(OIT==="chg"&&v>0?"+":"")+fmtL(v);
  let g=`<rect x="0" y="0" width="${W}" height="${H}" fill="#05070a"/>`;
  for(let k=0;k<=4;k++){ const v=lo+(hi-lo)*k/4, yy=y(v); g+=`<line x1="${L}" x2="${W-R}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="var(--line)"/><text x="${L-5}" y="${(yy+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="end">${fy(v)}</text>`; }
  if(OIT!=="tot"){ const z=y(OIT==="pcr"?1:0); g+=`<line x1="${L}" x2="${W-R}" y1="${z.toFixed(1)}" y2="${z.toFixed(1)}" stroke="var(--dim)" stroke-dasharray="4 3"/>`; }
  const sp=D.sp.filter(v=>v!=null); if(sp.length>1){ let a=Math.min(...sp), b=Math.max(...sp); if(a===b){a-=1;b+=1;} const ys=v=>T+ph*(1-(v-a)/(b-a));
    g+=`<polyline fill="none" stroke="var(--amber)" stroke-width="1.2" stroke-dasharray="3 2" opacity=".85" points="${D.sp.map((v,i)=>v==null?"":`${x(i).toFixed(1)},${ys(v).toFixed(1)}`).join(" ")}"/>`;
    [b,(a+b)/2,a].forEach(v=>{ g+=`<text x="${W-R+5}" y="${(ys(v)+3.5).toFixed(1)}" fill="var(--amber)" font-size="10" font-family="monospace" opacity=".8">${inr(v)}</text>`; }); }
  ser.forEach(([arr,col])=>{ const pts=arr.map((v,i)=>v==null?"":`${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
    g+=`<polyline fill="none" stroke="${col}" stroke-width="2.2" stroke-linejoin="round" points="${pts}"/>`;
    const lv=arr[n-1]; if(lv!=null) g+=`<circle cx="${x(n-1).toFixed(1)}" cy="${y(lv).toFixed(1)}" r="3.5" fill="${col}"/>`; });
  const step=Math.max(1,Math.ceil(n/Math.max(3,Math.floor(pw/70))));
  D.t.forEach((t,i)=>{ if(i%step===0||i===n-1){ if(i!==n-1&&n-1-i<step*0.6) return; g+=`<text x="${x(i).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="${i===0?"start":i===n-1?"end":"middle"}">${esc(t)}</text>`; } });
  g+=`<line class="oitx" x1="0" x2="0" y1="${T}" y2="${T+ph}" stroke="var(--hi)" stroke-width="1" opacity="0"/>`;
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" data-l="${L}" data-pw="${pw}" data-n="${n}" onmousemove="oitHover(event,this)" ontouchmove="oitHover(event,this)" onmouseleave="oitHover(null,this)">${g}</svg>`; }
function oitHover(ev,svg){ const D=oiTrendData(); const w=svg.closest(".oitw"); if(!D||!w) return; const rd=w.querySelector(".oitr"), ln=svg.querySelector(".oitx");
  if(!ev){ rd.innerHTML=oitRead(D,D.n-1); ln.setAttribute("opacity","0"); return; }
  const p=ev.touches?ev.touches[0]:ev; const r=svg.getBoundingClientRect(); const L=+svg.dataset.l, pw=+svg.dataset.pw, n=+svg.dataset.n;
  const i=Math.max(0,Math.min(n-1,Math.round(((p.clientX-r.left)-L)/pw*(n-1)))); const xx=L+pw*(i/(n-1));
  ln.setAttribute("x1",xx); ln.setAttribute("x2",xx); ln.setAttribute("opacity",".5"); rd.innerHTML=oitRead(D,i); }
function oiTrendBox(id){ const D=oiTrendData();
  if(!D) return `<div class="oitw"><div class="oith"><b>OI LINE</b><span class="dim">the line starts after two chain readings (every 15 min from 09:30)</span></div></div>`;
  return `<div class="oitw" id="${id}"><div class="oith"><b>OI LINE</b>${[["chg","OI CHANGE"],["tot","TOTAL OI"],["pcr","PCR"]].map(([k,l])=>`<a class="${OIT===k?"on":""}" onclick="oitMode('${k}')">${l}</a>`).join("")}<span class="dim" style="margin-left:auto">${OIT==="pcr"?`<i style="display:inline-block;width:10px;height:2px;background:#4fc3f7;vertical-align:middle"></i> PCR = puts ÷ calls (dashed 1.0 = even)`:`<i style="display:inline-block;width:10px;height:2px;background:var(--ce);vertical-align:middle"></i> calls <i style="display:inline-block;width:10px;height:2px;background:var(--pe);vertical-align:middle"></i> puts${OIT==="chg"?" (added since the first reading)":""}`} <i style="display:inline-block;width:10px;border-top:2px dashed var(--amber);vertical-align:middle"></i> price</span><div class="oitr">${oitRead(D,D.n-1)}</div></div><div class="oitg"></div></div>`; }
function oitPaint(host,id){ const h=$(host); if(!h) return; const D=oiTrendData(); let hh=0;
  if(host==="oitPx"&&wsWide()&&$("wsPx")&&$("tvbox")) hh=Math.max(150,Math.min(320,$("wsPx").clientHeight-$("tvbox").offsetHeight-92));
  const k=[OIT,D&&D.n,D&&D.ce[D.n-1],D&&D.pe[D.n-1],D&&D.sp[D.n-1],h.clientWidth,hh,id].join("|");
  if(h.dataset.k===k&&h.firstChild) return; h.dataset.k=k; h.innerHTML=oiTrendBox(id); oiTrendPut(id,hh); }
function oiTrendPut(id,hh){ const w=$(id); if(!w) return; const g=w.querySelector(".oitg"); if(g) g.innerHTML=oiTrendSVG(id,hh||0); }
let WS={k:"chg",dir:-1,sec:"",bu:"",pn:""}, OIS={k:"k",dir:-1,f:""}, WSKEY="";
try{ const w=JSON.parse(localStorage.getItem("gir_ws")||"null"); if(w){ WS.k=w.k||WS.k; WS.dir=w.dir||WS.dir; } }catch(e){}   // patch 113: only the sort is remembered
try{ const s0_=(new URLSearchParams(location.search)).get("sec"); if(s0_) WS.sec=s0_; }catch(e){}
function wsSave(){ try{ localStorage.setItem("gir_ws",JSON.stringify(WS)); }catch(e){} }
function wsWide(){ return window.innerWidth>=(/[?&]w=/.test(location.search)?640:900); }   // patch 107: a share's own window keeps its panes down to half a laptop screen
const BUS={"LONG BUILD-UP":["LB","pu"],"SHORT BUILD-UP":["SB","pd"],"SHORT COVERING":["SC","pu"],"LONG UNWINDING":["LU","pd"]};
function wsSort(k){ if(WS.k===k) WS.dir=-WS.dir; else { WS.k=k; WS.dir=(k==="s")?1:-1; } wsSave(); WSKEY=""; paint(); }
function wsSec(n){ WS.sec=(WS.sec===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsBu(n){ WS.bu=(WS.bu===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsPn(n){ WS.pn=(WS.pn===n)?"":n; wsSave(); WSKEY=""; paint(); }
function oiF(f){ OIS.f=(OIS.f===f)?"":f; paint(); }
function oiChips(){ return `<div class="wss oif">${[["","ALL STRIKES"],["near","NEAR THE PRICE"],["ce","CALLS ADDED"],["pe","PUTS ADDED"],["cl","CLOSING"]].map(([k,l])=>`<a class="${OIS.f===k?"on":""}" onclick="oiF('${k}')">${l}</a>`).join("")}</div>`; }
function oiSort(k){ if(OIS.k===k) OIS.dir=-OIS.dir; else { OIS.k=k; OIS.dir=-1; } paint(); }
function oth(k,l,c){ return `<th class="s ${c}${OIS.k===k?" on":""}" onclick="oiSort('${k}')">${l}${OIS.k===k?(OIS.dir>0?" ▲":" ▼"):""}</th>`; }
/* patch 102: on a laptop / desktop the MARKET screen is home; a share opens in its OWN window (see 3-4 side by side) */
const SOLO=((new URLSearchParams(location.search)).get("w")||"").toUpperCase().replace(/[^A-Z0-9&-]/g,"").slice(0,20);
const WINS={};
function openWin(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return;
  const n=Object.keys(WINS).filter(k=>WINS[k]&&!WINS[k].closed).length; const W=Math.floor((screen.availWidth||1536)/2), H=(screen.availHeight||860);
  const u=location.pathname+"?k="+encodeURIComponent(K)+"&w="+encodeURIComponent(sym)+(OPEN_SEC?"&sec="+encodeURIComponent(OPEN_SEC):""); OPEN_SEC="";
  if(WINS[sym]&&!WINS[sym].closed){ try{ WINS[sym].focus(); return; }catch(e){} }
  const w=window.open(u,"gir_"+sym);          // patch 110: its own GIR tab, named after the share (drag the tab out to see shares side by side)
  if(w){ WINS[sym]=w; try{ w.focus(); }catch(e){} } else { HOMED=true; setView("all"); focusOn.inner=true; focusOn(sym); focusOn.inner=false; } }   // a blocked pop-up: open it here
function toMain(v){ location.href=location.pathname+"?k="+encodeURIComponent(K)+(v&&v!=="market"?"&v="+encodeURIComponent(v):""); }   // patch 113: the key opens its screen in this tab
function goHome(){ HOMED=false; if(SOLO){ toMain("market"); return; } unfocus(); setView("market"); window.scrollTo(0,0); }   // patch 109: home = MARKET, laptop and phone
/* patch 95: HOME = the trading screen - the share you had open last, else the day's biggest mover */
let HOMED=false; let LASTS=""; try{ LASTS=localStorage.getItem("gir_last")||""; }catch(e){}
function homeOpen(){ if(!wsWide()||!SOLO) return; if(FOC){ HOMED=true; return; } const T=TAPE||[];
  let s=(LASTS&&(T.some(r=>r.s===LASTS)||!T.length))?LASTS:""; if(!s&&T.length){ s=T.slice().sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0))[0].s; }
  if(s){ HOMED=true; focusOn(s); } }
function wsClear(){ WS.sec=""; WS.bu=""; WS.pn=""; wsSave(); WSKEY=""; paint(); }
function wsLive(){ const L=$("wsList"), box=L&&L.querySelector(".wsl"); if(!box) return false; const by={}; for(const r of (TAPE||[])) by[r.s]=r;
  for(const el of box.children){ const s_=el.dataset&&el.dataset.s, r=s_&&by[s_]; if(!r) continue;
    if(WS.pn&&r.chg!=null&&(WS.pn==="up"?r.chg<=0:r.chg>=0)){ const st_=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st_; return true; }   /* patch 114: a share left the UP / DOWN filter */ const sp=el.children[1], pi=el.querySelector("i.p"); if(!sp) continue;
    const t=pc(r.chg), c=cls(r.chg)+qfl(s_); if(sp.textContent!==t) sp.textContent=t; if(sp.className!==c) sp.className=c;
    const pt="₹"+(r.px!=null?inr(r.px):"—"); if(pi&&pi.textContent!==pt) pi.textContent=pt; } return true; }
function shareListHTML(){ const sx=WS.sec?SECS.find(x=>x.name===WS.sec):null; if(WS.sec&&!sx&&SECS.length) WS.sec=""; const set=sx?new Set(sx.syms||[]):null;
  let rows=(TAPE||[]).filter(r=>(!set||set.has(r.s))&&(!WS.bu||(r.bu||"").toUpperCase()===WS.bu)&&(!WS.pn||(WS.pn==="up"?(r.chg||0)>0:(r.chg||0)<0)));
  const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);
  rows=rows.slice().sort((a,b)=>{ const x=val(a), y=val(b); return (x<y?-1:x>y?1:0)*WS.dir; });
  const btn=(k,l)=>`<a class="${WS.k===k?"on":""}" onclick="wsSort('${k}')">${l}${WS.k===k?(WS.dir>0?" ▲":" ▼"):""}</a>`;
  return `<div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${SECS.map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>
    ${(WS.sec||WS.bu||WS.pn)?`<div class="wsf">showing only ${[WS.sec&&WS.sec.toUpperCase(),WS.pn==="up"?"▲ UP":WS.pn==="dn"?"▼ DOWN":"",WS.bu].filter(Boolean).map(esc).join(" · ")} <a onclick="wsClear()">✕ show all</a></div>`:""}
    <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("v","DESK")}</div>
    <div class="wss"><a class="${WS.pn==="up"?"on":""}" onclick="wsPn('up')"><span class="${WS.pn==="up"?"":"pu"}">▲ UP</span></a><a class="${WS.pn==="dn"?"on":""}" onclick="wsPn('dn')"><span class="${WS.pn==="dn"?"":"pd"}">▼ DOWN</span></a>${Object.entries(BUS).map(([n,[sh,c]])=>`<a class="${WS.bu===n?"on":""}" onclick="wsBu('${n}')"><span class="${WS.bu===n?"":c}">${sh}</span></a>`).join("")}<span class="dim">${rows.length} shares</span></div>
    <div class="wsl">${rows.map(r=>{ const bb=BUS[(r.bu||"").toUpperCase()]; return `<div class="${r.s===FOC?"cur":""}" data-s="${esc(r.s)}" onclick="focusOn('${esc(r.s)}')"><b>${esc(r.s)}</b><span class="${cls(r.chg)}${qfl(r.s)}">${pc(r.chg)}</span><small><i class="p">₹${r.px!=null?inr(r.px):"—"}</i>${r.foi!=null?` · OI <span class="${r.foi>0?"pu":r.foi<0?"pd":""}">${r.foi>0?"+":""}${Number(r.foi).toFixed(1)}%</span>`:""}${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")||'<div class="empty">no share matches</div>'}</div>`; }
function oiProfileSVG(boxId){ const rows=oiRows().slice().sort((a,b)=>b.k-a.k); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0;
  if(!rows.length) return '<div class="empty">no strikes read yet</div>';
  const box=$(boxId); const W=Math.max(220,Math.floor((box&&box.clientWidth)||300)); const rh=Math.max(13,Math.min(20,Math.floor(440/rows.length))); const Hh=rows.length*rh+24;
  const {roof,floor}=wallsOf(rows,spot); const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=W/2, KWH=24, half=KX-KWH-2; const bh=Math.max(3,rh*0.36);
  const atm=rows.reduce((q,r)=>Math.abs(r.k-spot)<Math.abs(q.k-spot)?r:q,rows[0]);
  let g=`<rect x="0" y="0" width="${W}" height="${Hh}" fill="#05070a"/><text x="4" y="13" fill="var(--ce)" font-size="10" font-family="monospace">CALLS</text><text x="${W-4}" y="13" fill="var(--pe)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
    let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
    if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
    if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
    return o; };
  rows.forEach((r,i)=>{ const yy=22+i*rh+rh/2; const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    if(isW) g+=`<line x1="0" x2="${W}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${roof&&r.k===roof.k?"var(--dn)":"var(--up)"}" stroke-dasharray="5 3" opacity=".6"/>`;
    g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--ce)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--pe)");
    g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="10" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; });
  if(spot){ let i=rows.findIndex(r=>r.k<=spot); if(i<0) i=rows.length; const yy=22+i*rh; g+=`<line x1="0" x2="${W}" y1="${yy}" y2="${yy}" stroke="var(--amber)" stroke-dasharray="2 3"/><text x="${W-4}" y="${yy-3}" fill="var(--amber)" font-size="9" font-family="monospace" text-anchor="end">₹${inr(spot)}</text>`; }
  return `<div class="ocsvg"><svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${g}</svg></div>`; }
function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?(FLV.age_p<=120?`tick ${FLV.age_p}s ago`:`market closed · last price ${new Date(Date.now()-FLV.age_p*1000+19800000).toISOString().replace("T"," ").slice(5,16)}`):"on ticks"):(f.src||"");
  const head=`<div class="hd"><a class="hm" onclick="goHome()">⌂ HOME</a><b>${esc(f.s)}</b><span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span><span class="dim">${esc(age)}</span><a class="am" style="margin-left:auto" onclick="unfocus()">✕ CLOSE</a></div>
    <div class="m ${c}">${d?`DESK ${esc(d.label)} ${d.v>0?"+":""}${d.v}${Math.abs(d.v)===2?(d.conf?" ✓ CONFIRMED":" · awaiting the 5-min confirmation"):""}`:"no desk reading yet (the desk reads from 09:20)"}${d&&d.steps&&d.steps.length?` <span class="dim">· ${esc(d.steps.join(" · "))}</span>`:""}${d&&d.notes&&d.notes.length?` <span class="pd">· ${esc(d.notes.join(" · "))}</span>`:""}</div>
    ${d&&d.ticket?`<div class="tk">▶ ${esc(d.ticket)}${d.stop?` · stop: a close ${d.v>0?"under":"over"} ${d.stop}`:""}${d.line_k?` · line ${d.line_k}`:""}${d.size?`\n${esc(d.size)}`:""}</div>`:""}
    ${scnRibbon(f.s)}`;
  if(wsWide()) return head+`<div class="ws"><div id="wsList"></div><div id="wsPx"><div class="wsh">PRICE <span id="wsOhlc"></span></div><div class="tv" id="tvbox"></div><div id="oitPx"></div><div class="pat" id="patl"></div></div><div id="wsOi"><div class="wsh">OPTION CHAIN · OI BUILD-UP <span>calls green · puts red · live</span></div><div id="wsOiB"></div></div><div id="wsOc"><div class="wsh">F&amp;O CHECKLIST <span>buy CE · buy PE · 7 checks</span></div><div id="wsChk"></div><div class="wsh" style="position:static">OI CHART <span>calls · puts at every strike</span></div><div id="wsOcB"></div></div></div><div id="wsDesk"></div>`;
  return head+`<div class="tabs">${[["chart","CHART"],["chk","CHECKLIST"],["oi","OI BUILD-UP"],["oc","OI CHART"],["list","SHARES"],["desk","THE DESK"]].map(([k,l])=>`<span class="${FTAB===k?"on":""}" onclick="FTAB='${k}';paint()">${l}</span>`).join("")}</div><div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; const wide=wsWide();
  if(paint.wide!==wide||!F.querySelector(wide?".ws":"#fbody")){ paint.wide=wide; F.innerHTML=focusHTML(FD); WSKEY=""; }
  else { const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); const nh=tmp.querySelector(".hd"); if(nh) hd.replaceWith(nh); }
    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","chk","oi","oc","list","desk"][i]===FTAB)); }
  const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
  const ohlc=`O <b>${n?inr(ch.o[0]):"—"}</b> H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b> L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b> LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b> VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b> PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b>`;
  const pat=tv=>tv.txt.length?"<b>PATTERNS</b> · "+tv.txt.join(" · "):"";
  const oiH=()=>`<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiView(wsWide()?"wsOiB":"fbody")}<div class="legend">${OIMODE==="chain"?"":OIMODE==="chart"?"bars = OI at each strike: green = calls (CE, the resistance), red = puts (PE, the support) · bright top = added today · dashed = closed today · amber line = the price":"ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money"}</div>${scnFocus()}`;
  const ocH=id=>oiProfileSVG(id)+'<div class="legend"><i style="background:var(--ce)"></i>calls <i style="background:var(--pe)"></i>puts · bright = added today · dashed = closed today · the amber line = the price</div>';
  const deskH=()=>{ const d=FD.desk, ln=(d&&d.lines)||{}; return `${shareInfo()}${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${nlink(x)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; };
  if(wide){ const lk=JSON.stringify([WS,FOC,(TAPE||[]).length,Math.floor(Date.now()/30000)]); if(lk!==WSKEY||!$("wsList").querySelector(".wsl")){ WSKEY=lk; const L=$("wsList"); const st=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st; } else wsLive();
    MKH("wsOhlc").innerHTML=pxChips()+ohlc; const pxH=$("wsPx").clientHeight;
    if(PXM==="pro"){ if(proEnsure("tvbox",Math.max(300,pxH-34))) proRender(); $("patl").innerHTML=""; $("oitPx").innerHTML=""; $("oitPx").dataset.k=""; }
    else if(tickOn()){ $("tvbox").innerHTML=tickBox("wsPx",Math.max(280,Math.min(720,pxH-26-128))); $("patl").innerHTML=""; $("oitPx").innerHTML=""; $("oitPx").dataset.k=""; }
    else { const tv=tradingView(ch,FLV,{box:"wsPx",h:Math.max(220,Math.min(360,pxH-26-62-170))}); $("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); $("oitPx").innerHTML=""; }
    MKH("wsOiB").innerHTML=oiH(); chainScroll(); MKH("wsChk").innerHTML=chkHTML(FCK); MKH("wsOcB").innerHTML=ocH("wsOc"); MKH("wsDesk").innerHTML=deskH(); return; }
  const B=$("fbody"); if(!B) return;
  if(FTAB==="chart"&&PXM==="pro"){ if(!B.querySelector("#proWrap")||!PC||PC.sym!==FOC){ B.innerHTML=`<div class="sub"><span>${pxChips()}</span></div><div class="tv" id="tvbox"></div>`; }
    if(proEnsure("tvbox",440)) proRender(); }
  else if(FTAB==="chart"){ B.innerHTML=`<div class="sub"><span>${pxChips()}${ohlc}</span></div><div class="tv" id="tvbox"></div><div id="oitPx"></div><div class="pat" id="patl"></div><div class="legend">5-min candles · <i style="background:var(--amber)"></i>VWAP · the opening-range box · the roof / floor from the OI · ▲▼ the patterns · 🧩 an OI scenario fired</div>`;
    if(tickOn()){ $("tvbox").innerHTML=tickBox("tvbox",420); $("patl").innerHTML=""; const lg=B.querySelector(".legend"); if(lg) lg.innerHTML='price tick by tick (one point a second) · under it, on the same time axis: the OI the calls / puts added in the window · ▪ dashed lines = an alert on this share (red = ACT, amber = MOVING, grey = watch)'; }
    else { const tv=tradingView(ch,FLV,{}); $("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); } }
  else if(FTAB==="oi") B.innerHTML=oiH();
  else if(FTAB==="oc"){ B.innerHTML='<div id="ocbox"></div>'; $("ocbox").innerHTML='<div id="oitOc"></div>'+ocH("ocbox"); oitPaint("oitOc","oitB"); }
  else if(FTAB==="chk") B.innerHTML=chkHTML(FCK);
  else if(FTAB==="list"){ const st=B.scrollTop; B.innerHTML=shareListHTML(); }
  else B.innerHTML=deskH(); }
function chainSVG(f){ const S=f.strikes||[]; if(!S.length||!f.spot) return ""; const W=640,H=120,L=50,R=10,T=8,B=20; const n=S.length; const bw=(W-L-R)/n; const mx=Math.max(...S.map(x=>Math.max(x.ce,x.pe)),1);
  const y=v=>T+(H-T-B)*(1-v/mx); const bars=S.map((x,i)=>{ const x0=L+i*bw; const w=Math.max(2,bw*0.42); const isR=f.roof&&f.roof.k===x.k, isF=f.floor&&f.floor.k===x.k;
    return `<rect x="${(x0+bw*0.06).toFixed(1)}" y="${y(x.pe).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.pe)).toFixed(1)}" fill="var(--pe)" opacity="${isF?1:0.5}"/><rect x="${(x0+bw*0.52).toFixed(1)}" y="${y(x.ce).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.ce)).toFixed(1)}" fill="var(--ce)" opacity="${isR?1:0.5}"/>${(i%Math.ceil(n/8)===0)?`<text x="${(x0+bw/2).toFixed(1)}" y="${H-6}" fill="var(--dim)" font-size="10" text-anchor="middle" font-family="monospace">${x.k}</text>`:""}`; }).join("");
  const ks=S.map(x=>x.k); const lo=Math.min(...ks), hi=Math.max(...ks); const sx=L+((f.spot-lo)/((hi-lo)||1))*(W-L-R-bw)+bw/2;
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" style="width:100%;height:120px;display:block;background:#000"><line x1="${L}" x2="${W-R}" y1="${H-B}" y2="${H-B}" stroke="var(--line2)"/>${bars}<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="4 3"/></svg>`; }
async function getJ(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pullLive(){ if(!FOC||document.hidden) return; const since=(TK.sym===FOC&&TK.pts.length)?TK.pts[TK.pts.length-1][0]:0;
  const v=await getJ("live?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&since="+since); if(v&&v.sym===FOC){ FLV=v; tkFeed(v); paint(); if(SOLO&&v.px){ const pcv=v.pc||(FCH&&FCH.pc); document.title=`${FOC} ₹${inr(v.px)}${pcv?" "+pc((v.px/pcv-1)*100):""}`; } } }
async function pullChart(){ if(!FOC||document.hidden) return; const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.c){ FCH=v; paint(); } }
async function pullOI(){ if(!FOC||document.hidden) return; const v=await getJ("oi?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+(OIEXP.s===FOC&&OIEXP.e?"&exp="+encodeURIComponent(OIEXP.e):"")); if(v&&v.s===FOC){ FOI=v; paint(); } }
function stopLive(){ for(const k in FT){ if(FT[k]) clearInterval(FT[k]); FT[k]=null; } }
async function focusOn(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return;
  if(sym==="MARKET"||sym==="NIFTY"||sym==="NIFTY50"){ if(!SOLO) setView("market"); return; }      // patch 103: the market itself
  if(!SOLO&&!focusOn.inner&&wsWide()){ openWin(sym); return; }                       // patch 102: the main window stays on MARKET
  if(SOLO&&sym!==FOC){ document.title=sym; try{ history.replaceState(null,"",location.pathname+"?k="+encodeURIComponent(K)+"&w="+encodeURIComponent(sym)); }catch(e){} }
  LASTS=sym; try{ localStorage.setItem("gir_last",sym); }catch(e){} const fresh=sym!==FOC; FOC=sym; $("q").value=sym; $("unf").style.display="inline-block";
  if(fresh){ FCH=null; FLV=null; FOI=null; FCK=null; TKH=null; stopLive(); pullChart(); pullLive(); pullOI(); pullChk(); }   // patch 102: all at once
  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;
  const F=$("focus"); F.hidden=false; if(window.innerWidth<900) F.classList.add("sheet"); else { F.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
  if(!FD||(!(FD.strikes||[]).length&&FD.px==null&&!FD.desk)){ F.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">not an F&amp;O share on the desk</div>`; return; }
  if(fresh||!$("fbody")) F.innerHTML=focusHTML(FD); paint();
  if(fresh){ if(PXM==="pro") pullHist(true); FT.live=setInterval(pullLive,1000); FT.chart=setInterval(()=>{ pullChart(); pullChk(); },10000); FT.oi=setInterval(pullOI,30000); }
  if(D){ $("nowl").innerHTML=nowHTML((D.now||[]).filter(r=>r.s===FOC)); $("hnow").textContent=`${FOC} only · tap ✕ ALL for every share`; const nn=(D.news||[]).filter(x=>x.s===FOC); $("newsl").innerHTML=newsHTML(nn); } }
function unfocus(){ FOC=""; FD=null; FCH=null; FLV=null; FOI=null; stopLive(); const F=$("focus"); F.hidden=true; F.classList.remove("sheet","ws-on"); F.innerHTML=""; $("q").value=""; $("unf").style.display="none"; if(D){ $("nowl").innerHTML=nowHTML(D.now||[]); $("hnow").textContent="moving right now · newest first · every line went to Telegram the same second"; $("newsl").innerHTML=newsHTML(D.news||[]); } }
$("go").onclick=()=>focusOn($("q").value); $("q").addEventListener("keydown",e=>{ if(e.key==="Enter") focusOn($("q").value); }); $("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };
/* ---------- render: the same code for the poll and the push ---------- */
function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now(); drawAlerts();
  $("idx").innerHTML=idxHTML(D); $("nowl").innerHTML=nowHTML(FOC?(D.now||[]).filter(r=>r.s===FOC):(D.now||[])); SECS=D.sectors||[]; drawSecs();
  { const S_=D.scn||{}; const ck=JSON.stringify([(S_.today||[]).length,S_.scores,(S_.cat||[]).length]); if(ck!==render.ck){ render.ck=ck; $("scnl").innerHTML=scnHTML(D.scn); $("scnh").textContent=`how the money is building up · ${(S_.today||[]).length} today`; } }
  if(FOC&&(!render.fat||Date.now()-render.fat>30000)){ render.fat=Date.now(); getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)).then(v=>{ if(v&&FOC===v.s){ FD=v; paint(); } }); }
  const sk=SECS.map(s=>s.name).join("|"); if(sk!==render.sk){ render.sk=sk; $("secsel").innerHTML='<option value="">ALL SECTORS</option>'+SECS.map(s=>`<option value="${esc(s.name)}">${esc(s.name).toUpperCase()}</option>`).join(""); $("secsel").value=SEL; }
  const tk=JSON.stringify((D.tape||[]).map(r=>[r.s,r.px,r.v,r.oi])); if(tk!==render.tk){ render.tk=tk; TAPE=D.tape||[]; overlayQ(); drawTape(); }
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); tickSize(); }
  if(VIEW==="all"&&!FOC&&!HOMED&&wsWide()&&(TAPE||[]).length) homeOpen();
  if(VIEW==="market"){ drawMarket(); pullMarket(); }                 // patch 98: rides on the page's own refresh - no new timer
  first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} });
  ES.addEventListener("q",e=>{ try{ applyQ(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
/* patch 99: every F&O share's price every second - the push stream sends only what changed */
let LQ={}, QT=0, QCH={}, QPAINT=0;
function overlayQ(){ if(!QT||Date.now()/1000-QT>20) return; for(const r of (TAPE||[])){ const v=LQ[r.s]; if(v){ r.px=v[0]; if(v[1]!=null) r.chg=v[1]; } }
  const n=LQ.NIFTY50; if(n&&D&&D.idx){ D.idx.NIFTY=Object.assign({},D.idx.NIFTY||{},{last:n[0]},n[1]!=null?{chg:n[1]}:{}); } }
function applyQ(m){ const q=m.q||{}; const now=Date.now(); const by={}; (TAPE||[]).forEach(r=>by[r.s]=r);
  for(const s in q){ const v=q[s], o=LQ[s]; if(o&&v[0]!==o[0]) QCH[s]={d:v[0]>o[0]?1:-1,t:now}; else if(!o&&by[s]&&by[s].px!=null&&v[0]!==by[s].px) QCH[s]={d:v[0]>by[s].px?1:-1,t:now}; LQ[s]=v; }
  QT=m.t||now/1000; overlayQ(); liveRepaint(); }
const qfl=s=>{ const c=QCH[s]; return c&&Date.now()-c.t<1000?(c.d>0?" fu":" fd"):""; };
function liveRepaint(){ const now=Date.now(); if(now-QPAINT<800) return; QPAINT=now;
  if(D&&D.idx) $("idx").innerHTML=idxHTML(D);
  const lv=$("lvq"); if(lv) lv.textContent="● prices live "+new Date((QT+19800)*1000).toISOString().slice(11,19);
  if(VIEW==="market") drawMarket();
  else if(FOC&&wsWide()){ wsLive(); }
  else if(VIEW==="tape"||VIEW==="all") drawTape(); }
/* ---------- patch 93: THE ALERT BAR - only what is clear-cut ---------- */
/* ACT  = a BUY by the house rule (measured 55%+ on 50+ cases, agents agreeing) or your own money (💼 your trade, 🛑 book it)
   MOVE = something IS happening, not a trade by itself: 🚨 SUDDEN (EXTREME, 5-min confirmed) · ⚡ NEWS SHOCK chain ·
          🚀 RUNNING at 3%+ · ⚡ SPEED with the day already 2%+ · a BUY held back in the opening 15 minutes
   everything else (first moves, readings, movers, scorecards) stays in 1 NOW - no bar, no sound */
function alertTier(r){ const H=r.head||"", L=r.lines||[], T=[H].concat(L).join("\n"), k=r.kind||H.split(" ")[0]||"";
  if(/NOT SENT/.test(T)&&!/BUY/.test(T)) return "watch";
  if(k==="🧩") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 123: an OI build-up with a side
  if(k==="📰") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 117: a filing / a wire story
  if(k==="🌅"||k==="🧱") return /^🌅 GAPS/.test(H)?"watch":"move";      // patch 114: a 5%+ gap / a circuit
  if(k==="💼"||k==="🛑") return "act";
  const opening=/OPENING/.test(T);
  const m=T.match(/measured:\s*(\d+)%\s*right of\s*(\d+)/); const meas=m&&+m[1]>=55&&+m[2]>=50;
  const buyLine=L.some(l=>/^(▶\s*)?BUY\b/.test(l.trim()))||/—\s*BUY\b/.test(H);
  const disagree=/disagrees/.test(T);
  if(!opening&&!disagree&&!/\bWATCH\b/.test(T)&&(buyLine||(k==="🚨"&&meas))) return "act";
  if(k==="🚨"||/NEWS SHOCK/.test(H)||/NIFTY SHOCK|MARKET NEWS/.test(H)||(opening&&(buyLine||meas))) return "move";
  if(/RUNNING/.test(H)){ const c=T.match(/crossed\s*[+-](\d+)%/); if(c&&+c[1]>=3) return "move"; }
  if(/SPEED/.test(H)){ const d=H.match(/day\s*([+-]?\d+(\.\d+)?)%/); if(d&&Math.abs(+d[1])>=2) return "move"; }
  return "watch"; }
/* patch 105: the alert card - the full alert, top right, on every screen; 60 s for a TRADE ALERT, 25 s for MOVING */
function toast(r,tr){ const box=$("toasts"); if(!box) return; const el=document.createElement("div"); el.className="ta "+tr;
  const L=(r.lines||[]).filter(x=>!/^(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O)/.test(x)).slice(0,3);
  el.innerHTML=`<div class="th"><span class="tg2">${tr==="act"?"TRADE ALERT":"SOMETHING IS HAPPENING"}</span><span class="dim">${esc(r.t||"")}</span><b>${esc(r.s||"")}</b><span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"▲ UP → CE":r.side==="PE"?"▼ DOWN → PE":""}</span><span class="tx" title="close">✕</span></div><div><b>${esc(r.head||"")}</b></div><div class="tl">${esc(L.join("\n"))}</div>`;
  el.onclick=e=>{ if(e.target.classList.contains("tx")){ el.remove(); return; } el.remove(); focusOn(r.s||"MARKET"); };
  box.prepend(el); while(box.children.length>4) box.lastChild.remove();
  setTimeout(()=>{ try{ el.remove(); }catch(e){} }, tr==="act"?60000:25000); }
function alertTicket(r){ const L=(r.lines||[]).filter(x=>!/^(🔴 TRADE ALERT|🟠 SOMETHING IS HAPPENING|📌 F&O)/.test(x)); if(/NIFTY SHOCK|MARKET NEWS/.test(r.head||"")) return (r.head||"").replace(/^\S+\s+/,"").slice(0,90)+(L[0]&&/MARKET NEWS/.test(r.head)?" · "+L[0].replace(/^WHY NIFTY MOVED \([^)]*\): /,""):"");
  const tk=L.find(l=>/^▶/.test(l.trim()))||L.find(l=>/^(BUY|WATCH)\b/.test(l.trim()))||L[0]||"";
  return tk.replace(/^▶\s*/,"").replace(/\s*·\s*size:.*$/,"").slice(0,90); }
let ASEEN=null, AFRESH={}, ASND=true, AC=null; try{ ASND=localStorage.getItem("gir_snd")!=="0"; }catch(e){}
function acUnlock(){ try{ AC=AC||new (window.AudioContext||window.webkitAudioContext)(); if(AC.state==="suspended") AC.resume(); }catch(e){} }
document.addEventListener("pointerdown",acUnlock,{once:true}); document.addEventListener("keydown",acUnlock,{once:true});
/* patch 108: the quiet beep was replaced by alarm() */
function sndToggle(){ ASND=!ASND; try{ localStorage.setItem("gir_snd",ASND?"1":"0"); }catch(e){} if(ASND){ acUnlock(); alarm("act"); } drawAlerts(true); }
function sndArmed(){ return !!(AC&&AC.state==="running"); }
document.addEventListener("pointerdown",()=>setTimeout(()=>{ try{ drawAlerts(true); }catch(e){} },400),{once:true});
let ATITLE=document.title; function titleFlag(on){ document.title=on?"🔴 ALERT · "+ATITLE:ATITLE; }
document.addEventListener("visibilitychange",()=>{ if(!document.hidden) titleFlag(false); });
function drawAlerts(force){ const B=$("abar"); if(!B||!D) return; const rows=(D.now||[]);
  const per={}; const keyOf=r=>r.t+"|"+r.head;
  rows.forEach(r=>{ const tr=alertTier(r); if(tr==="watch"||!r.s) return; const o=per[r.s]; if(!o||(o.tier!=="act"&&tr==="act")||(o.tier===tr&&r.t>o.r.t)) per[r.s]={r,tier:tr,n:(o?o.n:0)+1}; else o.n++; });
  const list=Object.values(per).sort((a,b)=>(b.r.t>a.r.t?1:b.r.t<a.r.t?-1:0)||(a.tier===b.tier?0:a.tier==="act"?-1:1));   // patch 105: newest first
  const nW=rows.filter(r=>alertTier(r)==="watch").length;
  if(ASEEN===null){ ASEEN=new Set(rows.map(keyOf)); }
  else { let ring=0; rows.forEach(r=>{ const k=keyOf(r); if(ASEEN.has(k)) return; ASEEN.add(k); const tr=alertTier(r); if(tr==="watch") return; AFRESH[r.s]=Date.now(); ring=Math.max(ring,(tr==="act"||/CIRCUIT/.test(r.head||"")||/CRITICAL/.test(r.head||""))?2:1); toast(r,tr); });
    if(ring){ beep(ring===2?3:1,ring===2?988:660); try{ if(navigator.vibrate&&(!navigator.userActivation||navigator.userActivation.hasBeenActive)) navigator.vibrate(ring===2?[200,100,200,100,200]:[150]); }catch(e){} if(document.hidden) titleFlag(true); } }
  const ck=JSON.stringify([list.map(x=>[x.r.s,x.r.t,x.tier,x.n,!!AFRESH[x.r.s]&&Date.now()-AFRESH[x.r.s]<9000]),nW,ASND,FOC]); if(!force&&ck===drawAlerts.ck) return; drawAlerts.ck=ck;
  const hasA=list.some(x=>x.tier==="act");
  B.className=hasA?"has-act":list.length?"has-move":"";
  const chip=x=>{ const r=x.r, up=r.side==="CE", dn=r.side==="PE"; const fr=AFRESH[r.s]&&Date.now()-AFRESH[r.s]<9000;
    return `<div class="ch ${x.tier}${fr?" fresh":""}" title="${esc([r.head].concat(r.lines||[]).join("\n"))}" onclick="focusOn('${esc(r.s)}')"><span class="tg">${x.tier==="act"?"ACT":"MOVING"}</span><span class="tm">${esc(r.t)}</span><b>${esc(r.s)}</b><span class="${up?"pu":dn?"pd":"dim"}">${up?"▲ UP → CE":dn?"▼ DOWN → PE":""}</span><span class="tk">${esc(r.kind||"")} ${esc(alertTicket(r))}</span>${x.n>1?`<span class="dim">×${x.n}</span>`:""}</div>`; };
  B.innerHTML=`<div class="al">ALERTS</div><div class="ac">${list.length?list.slice(0,12).map(chip).join(""):`<span class="ae">nothing clear-cut yet today — a BUY by the measured rule, your own trade, or a move that is really happening (SUDDEN · SHOCK · RUNNING 3%+) shows here with a sound</span>`}</div><div class="ar"><a onclick="selfCheck()" title="clicks through every key, panel and tab on this server's data and lists what works">✓ SELF-CHECK</a><a class="${ASND?"on":""}" onclick="sndToggle()" title="${ASND&&!sndArmed()?"the browser lets a page ring only after one tap or key on it - tap anywhere once":"sound on / off"}">${ASND?(sndArmed()?"🔔 SOUND ON":"🔔 SOUND ON · tap page once"):"🔕 SOUND OFF"}</a><a onclick="setView('now')">WATCH ${nW} →</a></div>`;
  if(FOC&&wsWide()) document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
setInterval(()=>{ if(Object.values(AFRESH).some(t=>Date.now()-t<10000)||drawAlerts.ck) drawAlerts(); },3000);

/* ---------- patch 93: THE TICK CHART - the price tick by tick, the calls' / puts' OI under it, one time axis ---------- */
let PXM="tick", TKW=900, TK={sym:"",pts:[],tk0:null,mv:[]}, TKH=null;
try{ PXM=localStorage.getItem("gir_pxm")||"tick"; TKW=+(localStorage.getItem("gir_tkw")||900); }catch(e){}
function pxMode(m){ PXM=m; try{ localStorage.setItem("gir_pxm",m); }catch(e){} paint(); }
function tkWin(w){ TKW=w; try{ localStorage.setItem("gir_tkw",String(w)); }catch(e){} paint(); }
function tickOn(){ return PXM==="tick"&&TK.sym===FOC&&TK.pts.length>=5; }
function pxChips(){ return `<span class="pxm"><a class="${PXM==="pro"?"on":""}" onclick="pxMode('pro')" title="TradingView-style: timeframes, indicators, drawing, zoom">PRO</a><a class="${PXM==="tick"?"on":""}" onclick="pxMode('tick')">TICK</a><a class="${PXM!=="tick"&&PXM!=="pro"?"on":""}" onclick="pxMode('5m')" title="PRICE · 5 MIN candles">5 MIN</a></span>`; }
try{ if(!localStorage.getItem("gir_pxm_104")){ PXM="pro"; localStorage.setItem("gir_pxm","pro"); localStorage.setItem("gir_pxm_104","1"); } }catch(e){}
function tkFeed(v){ if(!v||!Array.isArray(v.tk)) return; if(TK.sym!==v.sym) TK={sym:v.sym,pts:[],tk0:null,mv:[]};
  const last=TK.pts.length?TK.pts[TK.pts.length-1][0]:0; for(const p of v.tk){ if(p[0]>last) TK.pts.push(p); } if(TK.pts.length>30000) TK.pts.splice(0,TK.pts.length-30000);
  TK.tk0=v.tk0; TK.mv=v.mv||[]; }
const hms=t=>{ const d=new Date((t+19800)*1000); return d.toISOString().slice(11,19); };
function tkView(){ const P=TK.pts; if(!P.length) return []; const t1=P[P.length-1][0]; const t0=TKW?t1-TKW:P[0][0]; let i=0; while(i<P.length&&P[i][0]<t0) i++; return P.slice(Math.max(0,i-1)); }
function tkRead(V,j){ const p=V[j], b=V[0]; if(!p) return ""; const dc=p[2]-b[2], dp=p[3]-b[3]; const sg=v=>(v>0?"+":"")+fmtL(v);
  const ch=FLV&&FLV.pc?(p[1]/FLV.pc-1)*100:null;
  return `<b class="am">${hms(p[0])}</b> · price <b class="${cls(ch)}">₹${inr(p[1])}</b>${ch!=null?` <span class="${cls(ch)}">${pc(ch)}</span>`:""} · in this window: <span style="color:var(--ce)">calls OI <b>${sg(dc)}</b></span> · <span style="color:var(--pe)">puts OI <b>${sg(dp)}</b></span>`; }
function tkMarks(t0,t1){ if(!D) return []; const P=TK.pts; if(!P.length) return []; const day0=Math.floor((P[P.length-1][0]+19800)/86400)*86400-19800;
  return (D.now||[]).filter(r=>r.s===FOC).map(r=>{ const m=(r.t||"").match(/^(\d\d):(\d\d)/); if(!m) return null; const t=day0+ +m[1]*3600+ +m[2]*60; return (t>=t0&&t<=t1)?{t,tier:alertTier(r),k:r.kind||""}:null; }).filter(Boolean); }
function tickSVG(boxId,hh){ const V=tkView(); if(V.length<2) return ""; const box=$(boxId); const W=Math.max(280,Math.floor((box&&box.clientWidth)||600)); const H=hh||380;
  const phone=W<600; const LW=Math.round(W*(phone?0.34:0.28)); const L=LW+6,R=64,T=26,GAP=22,B=20; const ph=Math.round((H-T-GAP-B)*0.62), oh=H-T-GAP-B-ph; const y0o=T+ph+GAP; const pw=W-L-R;
  const t0=TKW?V[V.length-1][0]-TKW:V[0][0], t1=V[V.length-1][0]; const span=Math.max(1,t1-t0); const x=t=>L+pw*Math.max(0,(t-t0))/span;
  const pxs=V.map(p=>p[1]); let lo=Math.min(...pxs), hi=Math.max(...pxs); const rf=FD&&FD.roof&&FD.roof.k, fl=FD&&FD.floor&&FD.floor.k;
  const rows=oiRows(); const ks=rows.map(r=>r.k).sort((a,b)=>a-b); const lp_=pxs[pxs.length-1];
  const kb=ks.filter(k=>k<=lo).pop(), ka=ks.find(k=>k>=hi); if(kb!=null) lo=kb; if(ka!=null) hi=ka;          // the nearest strike under and over the price
  [rf,fl].forEach(k=>{ if(k&&Math.abs(k/lp_-1)<=0.02){ lo=Math.min(lo,k); hi=Math.max(hi,k); } });          // the roof / floor when within 2%
  if(hi-lo<hi*0.002){ const m=(hi+lo)/2; lo=m-m*0.001; hi=m+m*0.001; } const pd=(hi-lo)*0.06; lo-=pd; hi+=pd; const yp=v=>T+ph*(1-(v-lo)/(hi-lo));
  const b=V[0]; const dc=V.map(p=>p[2]-b[2]), dp=V.map(p=>p[3]-b[3]); let olo=Math.min(0,...dc,...dp), ohi=Math.max(0,...dc,...dp); if(ohi===olo){ ohi+=1; olo-=1; } const opd=(ohi-olo)*0.08; olo-=opd; ohi+=opd;
  const yo=v=>y0o+oh*(1-(v-olo)/(ohi-olo));
  let g=`<rect x="0" y="0" width="${W}" height="${H}" fill="#05070a"/>`;
  { const vis=rows.filter(r=>r.k>=lo&&r.k<=hi).sort((a,b)=>b.k-a.k);                                       // the OI at each strike, on this price scale
    if(vis.length){ const gp=vis.length>1?Math.min(...vis.slice(1).map((r,i)=>Math.abs(yp(vis[i].k)-yp(r.k)))):24; const bh=Math.max(2,Math.min(9,gp*0.38));
      const mx=Math.max(...vis.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=LW/2, KWH=phone?19:23, half=KX-KWH-2;
      const atm=vis.reduce((q,r)=>Math.abs(r.k-lp_)<Math.abs(q.k-lp_)?r:q,vis[0]);
      g+=`<text x="3" y="${T-3}" fill="var(--ce)" font-size="9" font-family="monospace">CALLS</text><text x="${LW-3}" y="${T-3}" fill="var(--pe)" font-size="9" font-family="monospace" text-anchor="end">PUTS</text><line x1="${LW+2}" x2="${LW+2}" y1="${T}" y2="${T+ph}" stroke="var(--line2)"/>`;
      const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
        let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
        if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
        if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
        return o; };
      vis.forEach(r=>{ const yy=yp(r.k); const isW=r.k===rf||r.k===fl;
        g+=`<line x1="${LW+2}" x2="${W-R}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${isW?(r.k===rf?"var(--dn)":"var(--up)"):"var(--line)"}" stroke-dasharray="${isW?"6 3":"1 4"}" opacity="${isW?.8:.7}"/>`;
        g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--ce)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--pe)");
        g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="${phone?9:10}" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; }); } }
  for(let k=0;k<=4;k++){ const v=lo+(hi-lo)*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${yp(v).toFixed(1)}" y2="${yp(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-R+5}" y="${(yp(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(+v.toFixed(2))}</text>`; }
  for(let k=0;k<=2;k++){ const v=olo+(ohi-olo)*k/2; g+=`<line x1="${L}" x2="${W-R}" y1="${yo(v).toFixed(1)}" y2="${yo(v).toFixed(1)}" stroke="var(--line)"/><text x="${L-5}" y="${(yo(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="end">${(v>0?"+":"")+fmtL(Math.round(v))}</text>`; }
  g+=`<line x1="${L}" x2="${W-R}" y1="${yo(0).toFixed(1)}" y2="${yo(0).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="4 3"/>`;
  g+=`<text x="${L+4}" y="11" fill="var(--amber)" font-size="10" font-family="monospace">PRICE · TICK BY TICK</text><text x="${L}" y="${y0o-6}" fill="var(--dim)" font-size="10" font-family="monospace">OI ADDED: <tspan fill="var(--ce)">CALLS</tspan> · <tspan fill="var(--pe)">PUTS</tspan></text>`;
  [[rf,"var(--dn)","ROOF"],[fl,"var(--up)","FLOOR"]].forEach(([k,c,n])=>{ if(k&&k>=lo&&k<=hi) g+=`<text x="${L+4}" y="${(yp(k)-3).toFixed(1)}" fill="${c}" font-size="10" font-family="monospace">${n} ${k}</text>`; });
  if(FLV&&FLV.pc&&FLV.pc>=lo&&FLV.pc<=hi) g+=`<line x1="${L}" x2="${W-R}" y1="${yp(FLV.pc).toFixed(1)}" y2="${yp(FLV.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="2 4"/><text x="${W-R-4}" y="${(yp(FLV.pc)-3).toFixed(1)}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="end">prev close</text>`;
  const cols=Math.max(50,Math.floor(pw)); const bk=new Map(); V.forEach((p,i)=>{ const c=Math.round((x(p[0])-L)/pw*cols); const o=bk.get(c); if(!o) bk.set(c,{i0:i,i1:i,lo:p[1],hi:p[1],il:i,ih:i}); else { o.i1=i; if(p[1]<o.lo){o.lo=p[1];o.il=i;} if(p[1]>o.hi){o.hi=p[1];o.ih=i;} } });
  const pts=[]; for(const [c,o] of bk){ const xx=x(V[o.i1][0]); const seq=[o.i0, ...(o.il<o.ih?[o.il,o.ih]:[o.ih,o.il]), o.i1]; seq.forEach(i=>pts.push(`${xx.toFixed(1)},${yp(V[i][1]).toFixed(1)}`)); }
  const up=V[V.length-1][1]>=V[0][1];
  g+=`<polyline fill="none" stroke="${up?"var(--up)":"var(--dn)"}" stroke-width="1.6" stroke-linejoin="round" points="${pts.join(" ")}"/>`;
  const ol=(arr,col)=>{ const q=[]; let lc=-1; arr.forEach((v,i)=>{ const c=Math.round((x(V[i][0])-L)/pw*cols); if(c!==lc||i===arr.length-1){ q.push(`${x(V[i][0]).toFixed(1)},${yo(v).toFixed(1)}`); lc=c; } }); return `<polyline fill="none" stroke="${col}" stroke-width="2" stroke-linejoin="round" points="${q.join(" ")}"/>`; };
  g+=ol(dc,"var(--dn)")+ol(dp,"var(--up)");
  const lp=V[V.length-1]; g+=`<rect x="${W-R+1}" y="${(yp(lp[1])-8).toFixed(1)}" width="${R-2}" height="16" fill="${up?"var(--up)":"var(--dn)"}"/><text x="${W-R+4}" y="${(yp(lp[1])+4).toFixed(1)}" fill="#000" font-size="10" font-weight="700" font-family="monospace">${inr(lp[1])}</text>`;
  tkMarks(t0,t1).forEach(mk=>{ const xx=x(mk.t), c=mk.tier==="act"?"var(--dn)":mk.tier==="move"?"var(--amber)":"var(--dim)"; g+=`<line x1="${xx.toFixed(1)}" x2="${xx.toFixed(1)}" y1="${T}" y2="${y0o+oh}" stroke="${c}" stroke-dasharray="3 3" opacity="${mk.tier==="watch"?.45:.9}"/><text x="${xx.toFixed(1)}" y="${T+10}" font-size="11" text-anchor="middle">${esc(mk.k)}</text>`; });
  const nl=Math.max(2,Math.floor(pw/90)); for(let k=0;k<=nl;k++){ const t=t0+span*k/nl; g+=`<text x="${x(t).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="${k===0?"start":k===nl?"end":"middle"}">${span<=1200?hms(t):hms(t).slice(0,5)}</text>`; }
  let hx=-10; if(TKH!=null){ let j=V.findIndex(p=>p[0]>=TKH); if(j<0) j=V.length-1; hx=x(V[j][0]); }
  g+=`<line class="tkx" x1="${hx}" x2="${hx}" y1="${T}" y2="${y0o+oh}" stroke="var(--hi)" opacity="${TKH!=null?.5:0}"/>`;
  return `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" data-l="${L}" data-pw="${pw}" data-t0="${t0}" data-sp="${span}" onmousemove="tkHover(event,this)" ontouchmove="tkHover(event,this)" onmouseleave="tkHover(null,this)">${g}</svg>`; }
function tkHover(ev,svg){ const w=svg.closest(".tkw"); const V=tkView(); if(!w||!V.length) return; const rd=w.querySelector(".tkr"), ln=svg.querySelector(".tkx");
  if(!ev){ TKH=null; ln.setAttribute("opacity","0"); rd.innerHTML=tkRead(V,V.length-1); return; }
  const p=ev.touches?ev.touches[0]:ev; const r=svg.getBoundingClientRect(); const L=+svg.dataset.l, pw=+svg.dataset.pw, t0=+svg.dataset.t0, sp=+svg.dataset.sp;
  const t=t0+((p.clientX-r.left)-L)/pw*sp; let j=V.findIndex(q=>q[0]>=t); if(j<0) j=V.length-1; TKH=V[j][0]; const xx=L+pw*Math.max(0,V[j][0]-t0)/sp;
  ln.setAttribute("x1",xx); ln.setAttribute("x2",xx); ln.setAttribute("opacity",".5"); rd.innerHTML=tkRead(V,j); }
function tickBox(boxId,hh){ const V=tkView(); const n=TK.pts.length;
  const mv=(TK.mv||[]).length?`<div class="tkm">OI moving now (last ${Math.max(1,Math.round((TK.mv[0].secs||300)/60))} min): ${TK.mv.slice(0,5).map(m=>`<b style="color:${m.side==="CE"?"var(--ce)":"var(--pe)"}">${esc(m.k)} ${m.side} ${(m.d>0?"+":"")+fmtL(m.d)}</b>`).join(" · ")} <span class="dim">(+ = added, − = closed)</span></div>`:"";
  const head=`<div class="tkh">${[[300,"5 MIN"],[900,"15 MIN"],[3600,"1 HOUR"],[0,"ALL"]].map(([w,l])=>`<span class="pxm" style="margin:0"><a class="${TKW===w?"on":""}" onclick="tkWin(${w})">${l}</a></span>`).join("")}<span class="dim">ticks since ${TK.pts.length?hms(TK.pts[0][0]):"—"} (when this share was opened) · ${n.toLocaleString("en-IN")} points</span><div class="tkr">${tkRead(V,TKH!=null?Math.max(0,V.findIndex(p=>p[0]>=TKH)):V.length-1)}</div>${mv}</div>`;
  return `<div class="tkw">${head}${tickSVG(boxId,hh)}</div>`; }
/* ---------- patch 104: THE PRO CHART - TradingView's Lightweight Charts with the trader's controls ---------- */
/* timeframes 1m (ticks) · 5m · 15m · 1h · 1D (30 days of stored 5-min bars + today live) · candles / Heikin-Ashi / bars / line ·
   VWAP · EMA 9 / 21 · SMA 50 · Bollinger · volume · RSI / MACD / OI below · the chain's R1-R3 / S1-S3 and yesterday's levels as lines ·
   alerts and OI scenarios marked on the bar they fired · horizontal and trend lines drawn by hand (kept per share) · zoom (wheel),
   pan (drag), crosshair readout, fit, full screen */
let PRO={tf:"5",type:"candle",ind:{vwap:1,ema9:1,ema21:1,sma50:0,bb:0,vol:1,lv:1,mk:1},study:"rsi",tool:""};
try{ const p_=JSON.parse(localStorage.getItem("gir_pro")||"{}"); PRO=Object.assign(PRO,p_,{ind:Object.assign({},PRO.ind,p_.ind||{})}); }catch(e){} PRO.tool=""; PRO.t1=null;
function proSave(){ try{ localStorage.setItem("gir_pro",JSON.stringify({tf:PRO.tf,type:PRO.type,ind:PRO.ind,study:PRO.study})); }catch(e){} }
let PH={sym:"",t:0,d:null}, PC=null, LWC_LOADING=false; const ISTO=19800;
function lwcLoad(cb){ if(window.LightweightCharts) return cb(); if(LWC_LOADING){ setTimeout(()=>lwcLoad(cb),250); return; } LWC_LOADING=true;
  const sc=document.createElement("script"); sc.src="lwc.js?k="+encodeURIComponent(K); sc.onload=()=>{ LWC_LOADING=false; cb(); }; sc.onerror=()=>{ LWC_LOADING=false; }; document.head.appendChild(sc); }
async function pullHist(force){ if(!FOC) return; if(!force&&PH.sym===FOC&&Date.now()-PH.t<30000) return; PH.t=Date.now();
  const v=await getJ("hist?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&days=30"); if(v&&v.s===FOC){ PH={sym:FOC,t:Date.now(),d:v}; if(PC) PC.key=""; paint(); } }
const day0915=t=>Math.floor((t+ISTO)/86400)*86400-ISTO+33300;
function proBars(){ const tf=PRO.tf; let B=[];
  if(tf==="1"){ if(TK.sym!==FOC||!TK.pts.length) return []; const m=new Map(); for(const p of TK.pts){ const b=Math.floor(p[0]/60)*60; const o=m.get(b); if(!o) m.set(b,{t:b,o:p[1],h:p[1],l:p[1],c:p[1],v:0}); else { o.h=Math.max(o.h,p[1]); o.l=Math.min(o.l,p[1]); o.c=p[1]; } } B=[...m.values()]; }
  else { const d=PH.sym===FOC&&PH.d; if(!d||!d.t||!d.t.length) return []; const n=d.t.length; const raw=[]; for(let i=0;i<n;i++) raw.push({t:d.t[i],o:d.o[i],h:d.h[i],l:d.l[i],c:d.c[i],v:d.v[i]});
    if(FLV&&FLV.ok&&FLV.px&&raw.length&&FLV.age_p!=null&&FLV.age_p<=120){ const now_=Date.now()/1000, d0_=day0915(now_), b_=d0_+Math.floor((now_-d0_)/300)*300;   // patch 113
      if(now_>=d0_&&now_-d0_<22500&&b_>raw[raw.length-1].t) raw.push({t:b_,o:FLV.px,h:FLV.px,l:FLV.px,c:FLV.px,v:0}); }
    if(FLV&&FLV.ok&&FLV.px&&raw.length){ const L=raw[raw.length-1]; if(Date.now()/1000-L.t<330){ L.c=FLV.px; L.h=Math.max(L.h,FLV.px); L.l=Math.min(L.l,FLV.px); } }
    if(tf==="5") B=raw; else { const span=tf==="15"?900:tf==="60"?3600:0; const m=new Map();
      for(const r of raw){ const b=span?day0915(r.t)+Math.floor((r.t-day0915(r.t))/span)*span:Math.floor((r.t+ISTO)/86400)*86400-ISTO; const o=m.get(b);
        if(!o) m.set(b,{t:b,o:r.o,h:r.h,l:r.l,c:r.c,v:r.v}); else { o.h=Math.max(o.h,r.h); o.l=Math.min(o.l,r.l); o.c=r.c; o.v+=r.v; } } B=[...m.values()]; } }
  B.sort((a,b)=>a.t-b.t);
  if(PRO.type==="ha"){ let po=null,pc=null; B=B.map(b=>{ const c=(b.o+b.h+b.l+b.c)/4, o=po==null?(b.o+b.c)/2:(po+pc)/2; po=o; pc=c; return {t:b.t,o,h:Math.max(b.h,o,c),l:Math.min(b.l,o,c),c,v:b.v}; }); }
  return B; }
const ema=(a,n)=>{ const k=2/(n+1); let e=null; return a.map((v,i)=>{ e=e==null?v:v*k+e*(1-k); return i>=n-1?e:null; }); };
const sma=(a,n)=>a.map((v,i)=>{ if(i<n-1) return null; let s=0; for(let j=i-n+1;j<=i;j++) s+=a[j]; return s/n; });
function rsi(a,n=14){ let g=0,l=0; return a.map((v,i)=>{ if(i===0) return null; const d=v-a[i-1]; const up=Math.max(d,0), dn=Math.max(-d,0); if(i<=n){ g+=up/n; l+=dn/n; return i===n?100-100/(1+g/(l||1e-9)):null; } g=(g*(n-1)+up)/n; l=(l*(n-1)+dn)/n; return 100-100/(1+g/(l||1e-9)); }); }
function vwapOf(B){ let d=null,pv=0,vv=0,n=0,s=0; return B.map(b=>{ const dd=Math.floor((b.t+ISTO)/86400); if(dd!==d){ d=dd; pv=0; vv=0; n=0; s=0; } const tp=(b.h+b.l+b.c)/3; pv+=tp*(b.v||0); vv+=(b.v||0); n++; s+=tp; return vv>0?pv/vv:s/n; }); }
const T_=t=>t+ISTO;   // the chart shows India time
function proToolbar(){ const b=(on,l,f,t)=>`<a class="${on?"on":""}" onclick="${f}" ${t?`title="${t}"`:""}>${l}</a>`; const I=PRO.ind;
  return `<div class="ptb"><span>${[["1","1m"],["5","5m"],["15","15m"],["60","1h"],["D","1D"]].map(([k,l])=>b(PRO.tf===k,l,`proSet('tf','${k}')`)).join("")}</span>
    <span>${[["candle","CANDLES"],["ha","HEIKIN-ASHI"],["bar","BARS"],["line","LINE"]].map(([k,l])=>b(PRO.type===k,l,`proSet('type','${k}')`)).join("")}</span>
    <span>${[["vwap","VWAP"],["ema9","EMA 9"],["ema21","EMA 21"],["sma50","SMA 50"],["bb","BOLL"],["vol","VOL"],["lv","LEVELS","the chain's R1-R3 / S1-S3 + yesterday's high, low, close"],["mk","MARKS","alerts and OI scenarios on the bar they fired"]].map(([k,l,t])=>b(I[k],l,`proInd('${k}')`,t)).join("")}</span>
    <span>${[["rsi","RSI"],["macd","MACD"],["oi","OI"],["none","—"]].map(([k,l])=>b(PRO.study===k,l,`proSet('study','${k}')`)).join("")}</span>
    <span>${b(PRO.tool==="h","─ LINE","proTool('h')","click the chart to place a horizontal line")}${b(PRO.tool==="t","╱ TREND","proTool('t')","click two points")}${b(false,"✕","proClear()","remove this share's lines")}${b(false,"⟲ FIT","proFit()")}${b(false,"⛶","proFull()","full screen")}</span></div>`; }
function proSet(k,v){ PRO[k]=v; proSave(); if(PC) PC.key=""; if(k==="tf"&&v==="1"&&!(TK.sym===FOC&&TK.pts.length)) {} paint(); }
function proInd(k){ PRO.ind[k]=PRO.ind[k]?0:1; proSave(); if(PC) PC.key=""; paint(); }
function proTool(t){ PRO.tool=PRO.tool===t?"":t; PRO.t1=null; if(PC){ PC.tb.innerHTML=proToolbar(); PC.main.applyOptions({crosshair:{mode:PRO.tool?0:1}}); } }
function proDraws(){ try{ return JSON.parse(localStorage.getItem("gir_draw_"+FOC)||'{"h":[],"t":[]}'); }catch(e){ return {h:[],t:[]}; } }
function proDrawSave(d){ try{ localStorage.setItem("gir_draw_"+FOC,JSON.stringify(d)); }catch(e){} if(PC) PC.key=""; paint(); }
function proClear(){ proDrawSave({h:[],t:[]}); }
function proFit(){ if(PC) PC.main.timeScale().fitContent(); }
function proFull(){ if(!PC) return; const el=PC.el; if(document.fullscreenElement) document.exitFullscreen(); else if(el.requestFullscreen) el.requestFullscreen(); }
document.addEventListener("fullscreenchange",()=>{ if(PC){ PC.key=""; setTimeout(()=>paint(),150); } });
function proEnsure(boxId,h){ const box=$(boxId); if(!box) return false;
  if(!window.LightweightCharts){ if(!box.querySelector(".empty")) box.innerHTML='<div class="empty">loading the PRO chart…</div>'; lwcLoad(()=>{ PC=null; paint(); }); return false; }
  pullHist(false);
  const full=!!document.fullscreenElement; const H=full?window.innerHeight-40:h;
  if(PC&&PC.box===box&&document.body.contains(PC.el)&&PC.sym===FOC&&PC.h===H) return true;
  if(PC){ try{ PC.main.remove(); PC.sub.remove(); }catch(e){} }
  const sh=PRO.study==="none"?0:Math.round(H*0.26), mh=H-sh-34;
  box.innerHTML=`<div id="proWrap" class="pro"><div class="ptbw"></div><div class="pmain" style="height:${mh}px"><div class="plg"></div></div><div class="psub" style="height:${sh}px"><div class="plg2"></div></div></div>`;
  const el=box.querySelector("#proWrap");
  PC={sym:FOC,box,el,h:H,mh,sh,tb:el.querySelector(".ptbw"),lg:el.querySelector(".plg"),lg2:el.querySelector(".plg2"),key:"",s:{},ss:{},pls:[],sync:false};
  PC.tb.innerHTML=proToolbar(); proCharts();
  return true; }
function proCharts(){ const el=PC.el, mh=PC.mh, sh=PC.sh; const LC=window.LightweightCharts;
  if(PC.main){ try{ PC.main.remove(); }catch(e){} try{ PC.sub.remove(); }catch(e){} }
  el.querySelector(".pmain").querySelectorAll(".tv-lightweight-charts").forEach(x=>x.remove()); el.querySelector(".psub").querySelectorAll(".tv-lightweight-charts").forEach(x=>x.remove());
  const opt=hh=>({height:hh,autoSize:true,layout:{background:{type:"solid",color:"#05070a"},textColor:"#8a97a8",fontSize:11,fontFamily:"JetBrains Mono, Menlo, monospace"},
    grid:{vertLines:{color:"#0f1620"},horzLines:{color:"#0f1620"}},rightPriceScale:{borderColor:"#1a2230"},timeScale:{borderColor:"#1a2230",timeVisible:true,secondsVisible:false,rightOffset:12},
    crosshair:{mode:1,vertLine:{color:"#ffb00088",labelBackgroundColor:"#ffb000"},horzLine:{color:"#ffb00088",labelBackgroundColor:"#ffb000"}},localization:{priceFormatter:p=>inr(+p.toFixed(2))}});
  const main=LC.createChart(el.querySelector(".pmain"),opt(mh)); const sub=LC.createChart(el.querySelector(".psub"),Object.assign(opt(sh),{timeScale:{visible:true,borderColor:"#1a2230",timeVisible:true}}));
  PC.main=main; PC.sub=sub; PC.s={}; PC.ss={}; PC.pls=[];
  main.timeScale().subscribeVisibleLogicalRangeChange(r=>{ if(!r||PC.sync||!PC.subReady||PRO.study==="oi"||PRO.study==="none") return; PC.sync=true; try{ sub.timeScale().setVisibleLogicalRange(r); }catch(e){} PC.sync=false; });
  main.timeScale().subscribeVisibleTimeRangeChange(r=>{ if(!r||PRO.study!=="oi"||PC.sync||!PC.subReady) return; PC.sync=true; try{ sub.timeScale().setVisibleRange(r); }catch(e){} PC.sync=false; });
  sub.timeScale().subscribeVisibleLogicalRangeChange(r=>{ if(!r||PC.sync||!PC.subReady||PRO.study==="oi"||PRO.study==="none") return; PC.sync=true; try{ main.timeScale().setVisibleLogicalRange(r); }catch(e){} PC.sync=false; });
  main.subscribeCrosshairMove(p=>proLegend(p&&p.time));
  main.subscribeClick(p=>{ if(!PRO.tool||!p||!p.point||!PC.s.main) return; const pr=PC.s.main.coordinateToPrice(p.point.y); if(pr==null) return; const d=proDraws();
    if(PRO.tool==="h"){ d.h.push(+pr.toFixed(2)); PRO.tool=""; proDrawSave(d); PC.tb.innerHTML=proToolbar(); }
    else if(PRO.tool==="t"&&p.time!=null){ if(!PRO.t1){ PRO.t1=[p.time,+pr.toFixed(2)]; } else { d.t.push([PRO.t1[0],PRO.t1[1],p.time,+pr.toFixed(2)]); PRO.t1=null; PRO.tool=""; proDrawSave(d); PC.tb.innerHTML=proToolbar(); } } }); }
function proLegend(t){ if(!PC||!PC.B) return; const B=PC.B; let i=B.length-1; if(t!=null){ const k=B.findIndex(b=>T_(b.t)===t); if(k>=0) i=k; } const b=B[i]; if(!b) return; const p=i>0?B[i-1].c:b.o; const ch=(b.c/p-1)*100;
  const iv=(PC.iv||[]).map(([n,arr,c])=>arr[i]!=null?`<span style="color:${c}">${n} ${inr(+arr[i].toFixed(2))}</span>`:"").join(" ");
  const tl=new Date((b.t+ISTO)*1000).toISOString(); PC.lg.innerHTML=`<b>${esc(FOC)}</b> <span class="dim">${PRO.tf==="D"?tl.slice(0,10):tl.slice(5,10)+" "+tl.slice(11,16)} · ${({"1":"1m","5":"5m","15":"15m","60":"1h","D":"1D"})[PRO.tf]}</span> O <b>${inr(b.o)}</b> H <b>${inr(b.h)}</b> L <b>${inr(b.l)}</b> C <b class="${ch>=0?"pu":"pd"}">${inr(+b.c.toFixed(2))}</b> <span class="${ch>=0?"pu":"pd"}">${ch>=0?"+":""}${ch.toFixed(2)}%</span>${b.v?` V <b>${b.v.toLocaleString("en-IN")}</b>`:""} ${iv}`; }
function proRender(){ if(!PC||!window.LightweightCharts) return; const B=proBars(); const LC=window.LightweightCharts;
  const dr=proDraws(); const rows=oiRows(); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0;
  const key=JSON.stringify([FOC,PRO.tf,PRO.type,PRO.ind,PRO.study,PH.d&&PH.sym===FOC?PH.d.t.length:0,PRO.tf==="1"?TK.pts.length:0,(FOI&&FOI.series&&FOI.series.t||[]).length,dr,(D&&D.now||[]).length,rows.length]).replace(/,"t":\d+/,"");
  if(key===PC.key&&B.length&&PC.s.main){ const b=B[B.length-1]; try{ PC.s.main.update(PRO.type==="line"?{time:T_(b.t),value:b.c}:{time:T_(b.t),open:b.o,high:b.h,low:b.l,close:b.c}); }catch(e){} proLegend(null); return; }
  const keepR=(PC.main&&PC.fitTf===PRO.tf&&PC.key)?PC.main.timeScale().getVisibleLogicalRange():null;
  PC.key=key; PC.B=B; PC.subReady=false;
  if(Object.keys(PC.s).length){ proCharts(); }          // a fresh chart for a full redraw: removing series under the mouse breaks the library's hover
  const main=PC.main, sub=PC.sub;
  PC.tb.innerHTML=proToolbar();
  if(!B.length){ PC.lg.innerHTML=`<span class="dim">${PRO.tf==="1"?"1-minute bars come from the ticks recorded since this share was opened (market hours) - pick 5m for the history":"loading the history…"}</span>`; return; }
  const up="#1ed760", dn="#ff3b4a"; const C=B.map(b=>b.c);
  let s; if(PRO.type==="line") s=main.addLineSeries({color:"#e8eef5",lineWidth:2}); else if(PRO.type==="bar") s=main.addBarSeries({upColor:up,downColor:dn}); else s=main.addCandlestickSeries({upColor:up,downColor:dn,borderUpColor:up,borderDownColor:dn,wickUpColor:up,wickDownColor:dn});
  s.setData(B.map(b=>PRO.type==="line"?{time:T_(b.t),value:b.c}:{time:T_(b.t),open:b.o,high:b.h,low:b.l,close:b.c})); PC.s.main=s;
  const I=PRO.ind; PC.iv=[]; const line=(name,arr,color,w=1.5,style=0)=>{ const l=main.addLineSeries({color,lineWidth:w,lineStyle:style,priceLineVisible:false,lastValueVisible:false,crosshairMarkerVisible:false}); l.setData(B.map((b,i)=>arr[i]!=null?{time:T_(b.t),value:arr[i]}:{time:T_(b.t)})); PC.s[name]=l; PC.iv.push([name,arr,color]); };
  if(I.vol){ const v=main.addHistogramSeries({priceScaleId:"vol",priceFormat:{type:"volume"},lastValueVisible:false,priceLineVisible:false}); main.priceScale("vol").applyOptions({scaleMargins:{top:0.82,bottom:0}}); v.setData(B.map(b=>({time:T_(b.t),value:b.v||0,color:b.c>=b.o?"#1ed76055":"#ff3b4a55"}))); PC.s.vol=v; }
  if(I.vwap&&PRO.tf!=="D") line("VWAP",vwapOf(B),"#ffb000",2);
  if(I.ema9) line("EMA9",ema(C,9),"#4fc3f7"); if(I.ema21) line("EMA21",ema(C,21),"#b388ff"); if(I.sma50) line("SMA50",sma(C,50),"#ff8a65");
  if(I.bb){ const m=sma(C,20); const sd=C.map((v,i)=>{ if(i<19) return null; let a=0; for(let j=i-19;j<=i;j++) a+=(C[j]-m[i])**2; return Math.sqrt(a/20); }); line("BB+",m.map((v,i)=>v==null?null:v+2*sd[i]),"#78909c",1,2); line("BB",m,"#78909c",1,1); line("BB-",m.map((v,i)=>v==null?null:v-2*sd[i]),"#78909c",1,2); }
  if(I.lv){ const sr=srLevels(rows,spot); const pl=(price,color,title,st=2)=>PC.pls.push([s,s.createPriceLine({price,color,lineWidth:1,lineStyle:st,axisLabelVisible:true,title})]);
    sr.R.forEach((x,i)=>pl(x.k,dn,`R${i+1}`)); sr.S.forEach((x,i)=>pl(x.k,up,`S${i+1}`));
    const ch_=FCH||{}; if(ch_.pdh) pl(ch_.pdh,"#7d8b9c","PDH",3); if(ch_.pdl) pl(ch_.pdl,"#7d8b9c","PDL",3); const pc_=(PH.d&&PH.d.pc)||ch_.pc; if(pc_) pl(pc_,"#9aa5b1","PREV",1); }
  (dr.h||[]).forEach(p=>PC.pls.push([s,s.createPriceLine({price:p,color:"#ffb000",lineWidth:1,lineStyle:0,axisLabelVisible:true,title:"my line"})]));
  (dr.t||[]).forEach((t,i)=>{ if(t[0]===t[2]) return; const l=main.addLineSeries({color:"#ffb000",lineWidth:2,priceLineVisible:false,lastValueVisible:false,crosshairMarkerVisible:false}); const a=[{time:t[0],value:t[1]},{time:t[2],value:t[3]}].sort((x,y)=>x.time-y.time); l.setData(a); PC.s["tr"+i]=l; });
  if(I.mk&&PRO.tf!=="D"){ const bt=B.map(b=>b.t); const at=hm=>{ const m=(hm||"").match(/^(\d\d):(\d\d)/); if(!m) return null; const d0=Math.floor((B[B.length-1].t+ISTO)/86400)*86400-ISTO; const t=d0+ +m[1]*3600+ +m[2]*60; let j=-1; for(let i=0;i<bt.length;i++){ if(bt[i]<=t) j=i; else break; } return j>=0&&t-bt[j]<86400?T_(bt[j]):null; };
    const mk=[]; (D&&D.now||[]).filter(r=>r.s===FOC).forEach(r=>{ const tm=at(r.t); if(tm==null) return; const tr=alertTier(r); const upS=r.side==="CE"; mk.push({time:tm,position:upS?"belowBar":"aboveBar",color:tr==="act"?dn:tr==="move"?"#ffb000":"#7d8b9c",shape:upS?"arrowUp":"arrowDown",text:(r.kind||"")+(tr!=="watch"?" "+tr.toUpperCase():"")}); });
    ((D&&D.scn&&D.scn.today)||[]).filter(r=>r.s===FOC).forEach(r=>{ const tm=at(r.t); if(tm==null) return; mk.push({time:tm,position:r.side==="PE"?"aboveBar":"belowBar",color:r.side==="CE"?up:r.side==="PE"?dn:"#7d8b9c",shape:"circle",text:"🧩"}); });
    mk.sort((a,b)=>a.time-b.time); try{ s.setMarkers(mk); }catch(e){} }
  // the lower panel
  PC.lg2.innerHTML="";
  if(PRO.study==="rsi"){ const r=rsi(C); const l=sub.addLineSeries({color:"#b388ff",lineWidth:1.5,priceLineVisible:false}); l.setData(B.map((b,i)=>r[i]!=null?{time:T_(b.t),value:r[i]}:{time:T_(b.t)})); PC.pls.push([l,l.createPriceLine({price:70,color:"#ff3b4a88",lineStyle:2,lineWidth:1,title:"70"})],[l,l.createPriceLine({price:30,color:"#1ed76088",lineStyle:2,lineWidth:1,title:"30"})]); PC.ss.rsi=l; PC.lg2.innerHTML=`RSI 14 <b>${r[r.length-1]!=null?r[r.length-1].toFixed(1):"—"}</b>`; }
  else if(PRO.study==="macd"){ const e12=ema(C,12), e26=ema(C,26); const m=C.map((v,i)=>e12[i]!=null&&e26[i]!=null?e12[i]-e26[i]:null); const mv=m.filter(v=>v!=null); const sg=ema(mv,9); const sig=[]; let k=0; m.forEach(v=>{ sig.push(v==null?null:sg[k++]); });
    const h=sub.addHistogramSeries({priceLineVisible:false,lastValueVisible:false}); h.setData(B.map((b,i)=>m[i]!=null&&sig[i]!=null?{time:T_(b.t),value:m[i]-sig[i],color:m[i]-sig[i]>=0?"#1ed76088":"#ff3b4a88"}:{time:T_(b.t)})); PC.ss.h=h;
    const l1=sub.addLineSeries({color:"#4fc3f7",lineWidth:1.5,priceLineVisible:false,lastValueVisible:false}); l1.setData(B.map((b,i)=>m[i]!=null?{time:T_(b.t),value:m[i]}:{time:T_(b.t)})); PC.ss.m=l1;
    const l2=sub.addLineSeries({color:"#ffb000",lineWidth:1.5,priceLineVisible:false,lastValueVisible:false}); l2.setData(B.map((b,i)=>sig[i]!=null?{time:T_(b.t),value:sig[i]}:{time:T_(b.t)})); PC.ss.sg=l2; PC.lg2.innerHTML="MACD 12 26 9"; }
  else if(PRO.study==="oi"){ const S=FOI&&FOI.series; if(S&&S.t&&S.t.length>1){ const d0=Math.floor((B[B.length-1].t+ISTO)/86400)*86400-ISTO; const tt=S.t.map(h=>{ const m=h.match(/^(\d\d):(\d\d)/); return m?T_(d0+ +m[1]*3600+ +m[2]*60):null; });
      const a=sub.addLineSeries({color:up,lineWidth:2,priceLineVisible:false,title:"CALLS ΔOI"}); a.setData(S.ce.map((v,i)=>tt[i]!=null?{time:tt[i],value:v-S.ce[0]}:null).filter(Boolean)); PC.ss.ce=a;
      const b2=sub.addLineSeries({color:dn,lineWidth:2,priceLineVisible:false,title:"PUTS ΔOI"}); b2.setData(S.pe.map((v,i)=>tt[i]!=null?{time:tt[i],value:v-S.pe[0]}:null).filter(Boolean)); PC.ss.pe=b2;
      PC.lg2.innerHTML=`OI added today: <span class="pu">calls ${fmtL(S.ce[S.ce.length-1]-S.ce[0])}</span> · <span class="pd">puts ${fmtL(S.pe[S.pe.length-1]-S.pe[0])}</span>`; } else PC.lg2.innerHTML='<span class="dim">the OI line starts after two chain readings today</span>'; }
  PC.subReady=PRO.study!=="none"&&Object.keys(PC.ss).length>0;
  if(PC.subReady){ try{ if(PRO.study==="oi"){ const r=main.timeScale().getVisibleRange(); if(r) sub.timeScale().setVisibleRange(r); } else { const r=main.timeScale().getVisibleLogicalRange(); if(r) sub.timeScale().setVisibleLogicalRange(r); } }catch(e){} }
  if(keepR){ try{ main.timeScale().setVisibleLogicalRange(keepR); }catch(e){} }
  else if(!PC.fitted||PC.fitTf!==PRO.tf){ PC.fitted=true; PC.fitTf=PRO.tf; const n=B.length; const want=PRO.tf==="D"?n:PRO.tf==="60"?Math.min(n,70):PRO.tf==="15"?Math.min(n,100):Math.min(n,PRO.tf==="1"?180:150); main.timeScale().setVisibleLogicalRange({from:n-want,to:n+4}); }
  proLegend(null); }
/* ---------- patch 102: THE OI BUILD-UP CHART + SHARE INFO ---------- */
let OIMODE="chain"; try{ OIMODE=localStorage.getItem("gir_oim2")||"chain"; }catch(e){}
function oiMode(m){ OIMODE=m; try{ localStorage.setItem("gir_oim2",m); }catch(e){} paint(); }
/* patch 113: THE OPTION CHAIN like Kite - CALLS (OI in lakh, LTP) | STRIKE | PUTS (LTP, OI), each with its % change;
   the price line between the strikes, in-the-money shaded, the ATM strike boxed; PCR · MAX PAIN · ATM IV · IV PERCENTILE */
function chainHTML(){ const rows=oiRows().slice().sort((a,b)=>a.k-b.k); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0;
  if(!rows.length||!spot) return '<div class="empty">no strikes read yet - the chain comes with the first reading (09:20)</div>';
  const P=(FOI&&FOI.prev)||{}; const hasP=Object.keys(P).length>0; const pct=(a,b)=>(a!=null&&b)?(a/b-1)*100:null;
  const pc=v=>v==null?'<i class="dim">—</i>':`<i class="${v>0.05?"pu":v<-0.05?"pd":"dim"}">${v>0?"+":""}${Math.abs(v)>=1000?Math.round(v).toLocaleString("en-IN"):Math.abs(v)>=100?v.toFixed(0):v.toFixed(1)}%</i>`;
  const lk=v=>v==null?"—":(v/1e5).toFixed(2), px=v=>v==null?"—":(+v).toFixed(2);
  const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const sr=srLevels(rows,spot);
  const tag=new Map([...sr.R.map((x,i)=>[x.k,"R"+(i+1)]),...sr.S.map((x,i)=>[x.k,"S"+(i+1)])]);
  const atm=rows.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,rows[0]).k; let tb="", put=false, tce=0, tpe=0;
  const line=`<tr class="spt"><td colspan="5"><span>₹${inr(spot)}</span></td></tr>`;
  rows.forEach(r=>{ if(!put&&r.k>spot){ tb+=line; put=true; }
    tce+=r.ce_oi||0; tpe+=r.pe_oi||0; const q=P[String(r.k)]||{}, c0=q.ce||[], p0=q.pe||[];
    const oiP=(oi,d,o0)=>hasP?pct(oi,o0):(d!=null&&oi!=null&&oi-d>0?d/(oi-d)*100:null);
    const ci=r.k<spot?" itm":"", pi=r.k>spot?" itm":"";
    tb+=`<tr class="${r.k===atm?"atm":""}"><td class="co${ci}"><s style="width:${((r.ce_oi||0)/mx*100).toFixed(0)}%"></s><b>${lk(r.ce_oi)}</b>${pc(oiP(r.ce_oi,r.ce_d,c0[0]))}</td><td class="cl${ci}"><b>${px(r.ce_p)}</b>${pc(pct(r.ce_p,c0[1]))}</td><td class="k">${r.k}${tag.has(r.k)?`<u>${tag.get(r.k)}</u>`:""}</td><td class="pl${pi}"><b>${px(r.pe_p)}</b>${pc(pct(r.pe_p,p0[1]))}</td><td class="po${pi}"><s style="width:${((r.pe_oi||0)/mx*100).toFixed(0)}%"></s><b>${lk(r.pe_oi)}</b>${pc(oiP(r.pe_oi,r.pe_d,p0[0]))}</td></tr>`; });
  if(!put) tb+=line;
  const c=FCK&&FCK.s===FOC?FCK:{}; const mp=c.mp&&typeof c.mp==="object"?(c.mp.k??c.mp.strike):c.mp; const pcr=c.pcr??(tce?(tpe/tce).toFixed(2):null);
  const ex=String((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"");
  return `<div class="och"><span>expiry ${FOI&&FOI.exps&&FOI.exps.length>1?FOI.exps.map(e=>`<a class="${e===FOI.exp?"on":""}" onclick="oiExp('${esc(e)}')">${esc(String(e).slice(5))}</a>`).join("")+(FLV&&FLV.exp&&String(FLV.exp).slice(0,10)!==String(FOI.exp).slice(0,10)?`<i class="dim">last reading ${esc(FOI.last_t||"")}, not live</i>`:""):`<b>${esc(ex.slice(5)||"—")}</b>`}${c.days!=null?` · ${c.days}d`:""}</span><span>% = ${hasP?"vs yesterday's close":"OI vs today's first reading"}</span></div>
  <table class="kc"><thead><tr><th class="ce">CALL OI (lakh)</th><th class="ce">CALL LTP</th><th>STRIKE</th><th class="pe">PUT LTP</th><th class="pe">PUT OI (lakh)</th></tr></thead><tbody>${tb}</tbody>
  <tfoot><tr><td class="ce"><b>${lk(tce)}</b></td><td></td><td>TOTAL</td><td></td><td class="pe"><b>${lk(tpe)}</b></td></tr></tfoot></table>
  <div class="ocf"><span>PCR${c.t?` <small>${esc(String(c.t).slice(0,5))}</small>`:""} <b>${pcr??"—"}</b></span><span>MAX PAIN <b>${mp??"—"}</b></span><span>ATM IV <b>${c.iv!=null?c.iv+"%":"—"}</b></span><span>IV PERCENTILE <b class="${c.ivp>=80?"pd":c.ivp!=null&&c.ivp<=30?"pu":""}">${c.ivp??"—"}</b></span></div>
  <div class="legend">green = calls (CE) · red = puts (PE) · shaded = in the money · ATM boxed in amber · R1-R3 = the biggest call walls above (resistance) · S1-S3 = the biggest put walls below (support) · live on ticks · — = that strike was not recorded yesterday (it was far from the price then)</div>`; }
let OIEXP={s:"",e:""};
function oiExp(e){ OIEXP={s:FOC,e:e}; const w=$("wsOi"); if(w) w.dataset.cs=""; pullOI(); }
function chainScroll(){ const w=$("wsOi"), a=w&&w.querySelector("table.kc tr.atm"); if(!w||!a||w.dataset.cs===FOC) return; w.dataset.cs=FOC; const h_=w.querySelector(".wsh"); if(h_) w.style.setProperty("--wshh",h_.offsetHeight+"px");
  w.scrollTop=Math.max(0,a.getBoundingClientRect().top-w.getBoundingClientRect().top+w.scrollTop-w.clientHeight/2); }
function srLevels(rows,spot){ const up=rows.filter(r=>r.k>spot&&(r.ce_oi||0)>0).sort((a,b)=>b.ce_oi-a.ce_oi), dn=rows.filter(r=>r.k<spot&&(r.pe_oi||0)>0).sort((a,b)=>b.pe_oi-a.pe_oi);
  const R=up.slice(0,3).sort((a,b)=>a.k-b.k).map(r=>({k:r.k,oi:r.ce_oi,d:r.ce_d})), S=dn.slice(0,3).sort((a,b)=>b.k-a.k).map(r=>({k:r.k,oi:r.pe_oi,d:r.pe_d}));   // patch 113: nearest first
  const strong=(arr,key)=>{ const m=arr.length?arr[0][key]:0; return arr.filter(r=>r[key]>=0.5*m).length; };
  return {R,S,nR:strong(up,"ce_oi"),nS:strong(dn,"pe_oi"),aR:up.length,aS:dn.length}; }
function oiChartSVG(boxId){ const rows=oiRows().slice().sort((a,b)=>a.k-b.k); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0; if(!rows.length||!spot) return '<div class="empty">no strikes read yet</div>';
  const box=$(boxId); const W=Math.max(300,Math.floor((box&&box.clientWidth)||520)); const H=Math.max(230,Math.min(340,Math.round(W*0.55)));
  const L=8,R=8,T=30,B=34; const n=rows.length, gw=(W-L-R)/n, bw=Math.max(2,gw*0.36); const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const y=v=>T+(H-T-B)*(1-v/mx);
  const sr=srLevels(rows,spot); const rk=new Map(sr.R.map((x,i)=>[x.k,"R"+(i+1)])), sk=new Map(sr.S.map((x,i)=>[x.k,"S"+(i+1)]));
  let g=`<rect x="0" y="0" width="${W}" height="${H}" fill="#05070a"/>`;
  for(let k=1;k<=3;k++){ const yy=T+(H-T-B)*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${yy}" y2="${yy}" stroke="var(--line)"/>`; }
  rows.forEach((r,i)=>{ const x0=L+i*gw+gw/2; const bar=(oi,d,dx,col)=>{ if(!oi) return ""; const add=Math.max(0,d||0), base=Math.max(0,oi-add); let o=`<rect x="${(x0+dx).toFixed(1)}" y="${y(base).toFixed(1)}" width="${bw.toFixed(1)}" height="${(H-B-y(base)).toFixed(1)}" fill="${col}" opacity=".5"/>`;
      if(add>0) o+=`<rect x="${(x0+dx).toFixed(1)}" y="${y(oi).toFixed(1)}" width="${bw.toFixed(1)}" height="${(y(base)-y(oi)).toFixed(1)}" fill="${col}"/>`;
      if((d||0)<0){ const top=y(Math.min(mx,oi-d)); o+=`<rect x="${(x0+dx).toFixed(1)}" y="${top.toFixed(1)}" width="${bw.toFixed(1)}" height="${(y(oi)-top).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; } return o; };
    g+=bar(r.ce_oi,r.ce_d,-bw-0.5,"var(--ce)")+bar(r.pe_oi,r.pe_d,0.5,"var(--pe)");
    const lab=rk.get(r.k)||sk.get(r.k); if(lab){ const isR=lab[0]==="R"; const top=y(isR?r.ce_oi:r.pe_oi); g+=`<text x="${x0.toFixed(1)}" y="${Math.max(12,top-4).toFixed(1)}" fill="${isR?"var(--ce)":"var(--pe)"}" font-size="10" font-weight="700" text-anchor="middle">${lab}</text>`; }
    if(n<=16||i%Math.ceil(n/14)===0||rk.has(r.k)||sk.has(r.k)) g+=`<text x="${x0.toFixed(1)}" y="${H-B+12}" fill="${rk.has(r.k)||sk.has(r.k)?"var(--amber)":"var(--dim)"}" font-size="9" text-anchor="middle" transform="rotate(-35 ${x0.toFixed(1)} ${H-B+12})">${r.k}</text>`; });
  let si=rows.findIndex(r=>r.k>=spot); if(si<0) si=n; const prev=si>0?rows[si-1]:null, nxt=rows[si]; const sx=nxt&&prev?L+(si-1)*gw+gw/2+gw*((spot-prev.k)/((nxt.k-prev.k)||1)):L+si*gw;
  g+=`<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T-6}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="3 3"/><text x="${sx.toFixed(1)}" y="${T-10}" fill="var(--amber)" font-size="10" text-anchor="middle">₹${inr(spot)}</text>`;
  g+=`<text x="${L}" y="12" fill="var(--ce)" font-size="10">▮ CALL OI (CE) = resistance above</text><text x="${W-R}" y="12" fill="var(--pe)" font-size="10" text-anchor="end">PUT OI = support below ▮</text>`;
  return `<div class="oic"><svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${g}</svg></div>`; }
function srBar(){ const rows=oiRows(); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0; if(!rows.length||!spot) return ""; const sr=srLevels(rows,spot);
  const one=(x,i,t)=>`<span><b class="${t==="R"?"pd":"pu"}">${t}${i+1} ${x.k}</b> <span class="dim">${fmtL(x.oi)}${x.d?` (${x.d>0?"+":""}${fmtL(x.d)})`:""} · ${((x.k/spot-1)*100).toFixed(1)}%</span></span>`;
  return `<div class="srb"><span class="t">RESISTANCE</span><b class="pd">${sr.nR} strong</b><span class="dim">of ${sr.aR} call strikes above</span>${sr.R.map((x,i)=>one(x,i,"R")).join("")}</div>
    <div class="srb"><span class="t">SUPPORT</span><b class="pu">${sr.nS} strong</b><span class="dim">of ${sr.aS} put strikes below</span>${sr.S.map((x,i)=>one(x,i,"S")).join("")}</div>`; }
function oiView(boxId){ return `<div class="sub"><span class="oimd"><a class="${OIMODE==="chain"?"on":""}" onclick="oiMode('chain')">OPTION CHAIN</a><a class="${OIMODE==="chart"?"on":""}" onclick="oiMode('chart')">BARS</a><a class="${OIMODE==="table"?"on":""}" onclick="oiMode('table')">BUILD-UP TABLE</a></span><span class="dim">strong = at least half the biggest wall</span></div>${srBar()}${OIMODE==="chain"?chainHTML():OIMODE==="chart"?oiChartSVG(boxId):oiChips()+oiTable()}`; }
function shareInfo(){ if(!FOC) return ""; const r=(TAPE||[]).find(x=>x.s===FOC)||{}; const sec=(SECS||[]).find(x=>(x.syms||[]).includes(FOC)); const c=FCK&&FCK.s===FOC?FCK:null;
  const peers=sec?(TAPE||[]).filter(x=>sec.syms.includes(x.s)&&x.s!==FOC&&x.chg!=null).sort((a,b)=>Math.abs(b.chg)-Math.abs(a.chg)).slice(0,6):[];
  const bu=(r.bu||"").toUpperCase(); const buc=bu.includes("LONG BUILD")||bu.includes("SHORT COVER")?"pu":bu?"pd":"dim";
  return `<div class="shi"><div><small>FUTURES</small><b class="${buc}">${esc(bu||"no clear build-up")}</b>${r.cr!=null?` · ₹${Math.abs(Math.round(r.cr))} cr`:""}${r.foi!=null?` · OI ${r.foi>0?"+":""}${r.foi}%`:""}</div>
    <div><small>SECTOR</small>${sec?`<b>${esc(sec.name.toUpperCase())}</b> <span class="${cls(sec.chg)}">${pc(sec.chg)}</span> · ${(sec.syms||[]).length} F&amp;O shares`:"—"}</div>
    <div><small>PEERS (biggest moves)</small>${peers.map(x=>`<a onclick="focusOn('${esc(x.s)}')"><b>${esc(x.s)}</b> <span class="${cls(x.chg)}">${pc(x.chg)}</span></a>`).join(" · ")||"—"}</div>
    <div><small>EVENTS</small>${c&&c.results_in!=null?`<b class="pd">results in ${c.results_in} day${c.results_in===1?"":"s"}</b>`:"no results in 7 days"}${c&&c.lot?` · lot ${c.lot}`:""}${c&&c.exp?` · expiry ${esc(c.exp.slice(5))} (${c.days}d)`:""}</div></div>`; }
/* ---------- patch 101: THE F&O CHECKLIST (the server's /chk: IV, IV percentile, expected move, breakeven, liquidity, max pain, PCR, results) ---------- */
let FCK=null;
async function pullChk(){ if(!FOC||document.hidden) return; const v=await getJ("chk?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FCK=v; paint(); } }
function chkHTML(c){ if(!c||!c.s||c.s!==FOC) return '<div class="empty">the F&amp;O checklist comes with the chain sweep (from 09:20; the last day\'s on a closed day)</div>';
  const mp=c.mp&&typeof c.mp==="object"?(c.mp.k??c.mp.strike):c.mp; const ivc=c.ivp!=null?(c.ivp>=80?"pd":c.ivp<=30?"pu":""):"";
  const kv=[["EXPIRY",`${esc((c.exp||"").slice(5))||"—"} · ${c.days??"—"}d`,(c.days!=null&&c.days<=4)?"am":""],["LOT",c.lot?c.lot.toLocaleString("en-IN"):"—",""],
    ["IV",c.iv!=null?c.iv+"%":"—",""],["IV PERCENTILE",c.ivp!=null?String(c.ivp):"—",ivc],["IV vs 20-DAY",c.rv!=null&&c.iv!=null?`${c.iv}% / ${c.rv}%`:"—",""],
    ["EXPECTED MOVE",c.em!=null?"±"+c.em+"%":"—",""],["TYPICAL MOVE",c.typ!=null?"±"+c.typ+"%":"—",""],["PCR",c.pcr??"—",""],["MAX PAIN",mp??"—",""],
    ["RESULTS",c.results_in!=null?`in ${c.results_in}d`:"none soon",c.results_in!=null&&c.results_in<=3?"pd":""]];
  const side=(k)=>{ const x=c[k]; if(!x) return `<div><div class="vh">BUY ${k}</div><div class="dim">not read</div></div>`; const up=k==="CE";
    const it=(x.items||[]).map(t=>`<div class="it"><span class="${t[1]>0?"pu":t[1]<0?"pd":"dim"}">${t[1]>0?"✔":t[1]<0?"✖":"–"}</span><span>${esc(t[0])}</span><span>${esc(t[2])}</span></div>`).join("");
    const a=x.atm||{}; const i=x.itm;
    return `<div><div class="vh"><span class="${up?"pu":"pd"}">BUY ${k} ${up?"▲ share UP":"▼ share DOWN"}</span><span><span class="vb ${esc(x.verdict||"")}">${esc(x.verdict||"")}</span> <span class="dim">${x.score??"—"}/${x.of??7}</span></span></div>${it}
      <div class="tkt">▶ ${esc(a.label||"")} ₹${a.p??"—"}${a.be!=null?` · breakeven ${inr(a.be)}`:""}${a.cost?` · 1 lot ₹${inr(a.cost)}`:""}${x.stop_share!=null?` · stop: share ${up?"under":"over"} ${inr(x.stop_share)}`:""}${i?`<br><span class="dim">1-ITM: ${esc(i.label)} ₹${i.p}</span>`:""}</div></div>`; };
  return `<div class="ck"><div class="kv">${kv.map(([k,v,cl])=>`<div><small>${k}</small><b class="${cl}">${esc(String(v))}</b></div>`).join("")}</div>
    <div class="sd">${side("CE")}${side("PE")}</div>${(c.warn||[]).map(w=>`<div class="wn">⚠ ${esc(w)}</div>`).join("")}
    <div class="legend">${esc(c.src==="ticks"?"live (ticks)":"chain sweep")} ${esc(c.t||"")} · ${c.n_strikes||0} strikes${c.chain==="eod"?" + yesterday's far strikes":""} · ✔ pass ✖ fail – neutral · PASS = 6+ of 7 and no fail</div></div>`; }
/* ---------- patch 111: a news headline is a link to the full story (new tab); the share name still opens the share ---------- */
function nlink(x,txt){ const t=esc(txt!=null?txt:(x&&x.h)||""); const u=x&&(x.l||x.u)||""; if(!/^https?:\/\//i.test(u)) return t;
  return `<a class="nl" href="${esc(u)}" target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()" title="open the full story">${t}<span class="ar_">↗</span></a>`; }
let MKNF="all"; try{ MKNF=localStorage.getItem("gir_mknf")||"all"; }catch(e){}
function mkNf(k){ MKNF=k; try{ localStorage.setItem("gir_mknf",k); }catch(e){} drawMarket(); }   // patch 112
/* ---------- patch 98: THE MARKET SCREEN ---------- */
let MK=null, MKT=0;
async function pullMarket(force){ if(VIEW!=="market") return; if(!force&&Date.now()-MKT<9000) return; MKT=Date.now(); const v=await getJ("market?k="+encodeURIComponent(K)); if(v){ MK=v; await Promise.all([pullNifty(), pullEarly()]); drawMarket(); } }
/* patch 119: ⚡ EARLY - the day's signals per share: BUY (2+ agree, or critical news alone) or WATCH, the strike, the record */
let EAR=null;
async function pullEarly(){ const v=await getJ("early?k="+encodeURIComponent(K)); if(v&&v.rows) EAR=v; }
function drawEarly(){ const el=$("mk-ear"); if(!el) return; const E=EAR;
  if(!E){ MKH("mk-ear").innerHTML='<div class="empty">reading the day\'s signals…</div>'; return; }
  const ic={news:"📰",oi:"🔭",money:"💰",price:"📈"}, nm={news:"news",oi:"OI build-up",money:"futures money",price:"price"};
  const sig=r=>["news","oi","money","price"].map(g=>{ const x=r.sig[g]; if(!x) return `<i class="ei dim" title="${nm[g]}: nothing yet">${ic[g]}·</i>`;
    return `<i class="ei ${x.side==="CE"?"pu":"pd"}" title="${esc(nm[g]+": "+x.lv+(x.conf?" · sure "+x.conf+"%":"")+(x.t?" · "+x.t:"")+" · "+x.head)}">${ic[g]}${x.side==="CE"?"▲":"▼"}</i>`; }).join("");
  const stk=r=>r.stk?`${r.side} ${r.stk.k} ${esc(String(r.stk.exp||"").slice(5))} ₹${r.stk.p}${r.stk.cost?" · 1 lot ₹"+Number(r.stk.cost).toLocaleString("en-IN"):""} · stop ₹${r.stk.stop}`:'<span class="dim">no chain read yet</span>';
  const vd=r=>r.verdict==="BUY"?`<b class="eb ${r.side==="CE"?"ce":"pe"}">BUY ${r.side}</b>`:`<span class="ew">WATCH ${r.side}</span>`;
  const rows=(E.rows||[]).map(r=>`<tr class="k" onclick="mkOpen('${esc(r.s)}')"><td class="dim">${esc(r.first)}</td><td><b>${esc(r.s)}</b></td><td>${vd(r)}<br><small class="dim">${esc(r.how)}</small></td><td>${sig(r)}</td><td class="ewhy">${esc(r.why)}</td><td>${stk(r)}</td><td class="r ${r.since>0?"pu":r.since<0?"pd":"dim"}">${r.since!=null?(r.since>0?"+":"")+r.since.toFixed(1)+"%<br><small class=dim>its way since</small>":"—"}</td></tr>`).join("");
  const rec=(E.record||[]).filter(x=>x.close&&x.close[1]).map(x=>`${esc(x.name)} <b>${x.close[0]}/${x.close[1]}</b>`).join(" · ");
  MKH("mk-ear").innerHTML=(rows?`<table class="et">${rows}</table>`:`<div class="empty">no signals yet ${E.today?"today":"("+esc(E.day)+")"} — news read by the reader, OI build-up, gaps and runs land here as they happen</div>`)
    +`<div class="erec">record · right = moved 0.5%+ its way by the close: ${rec||"being built — every alert is scored after 1 hour, at the close and after 3 days"}</div>`;
  const nb=(E.rows||[]).filter(r=>r.verdict==="BUY").length; $("mk-earh").textContent=`${E.today?"today":E.day} · ${nb} BUY · ${(E.rows||[]).length} shares · BUY = 2+ of 📰🔭💰📈 agree, or critical news alone · tap = its trading screen`; }
/* patch 113: NIFTY as green / red 5-min candles (the engine's bars) - the last candle moves with every tick */
let NCH=null, NSC=null;
async function pullNifty(){ const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym=NIFTY50"); if(v&&v.c&&v.c.some(x=>x!=null)){ NCH=v; return; }
  if(NCH&&NCH.fromHist&&Date.now()-NCH.at<600000) return;            /* patch 117: no candles from the engine yet - the stored 5-min history, the last session */
  const h=await getJ("hist?k="+encodeURIComponent(K)+"&sym=NIFTY50&days=2"); if(!h||!h.t||!h.t.length) return;
  const dd=t=>Math.floor((t+19800)/86400), last=dd(h.t[h.t.length-1]); const o=[],hi=[],lo=[],c=[]; let pc=null;
  for(let i=0;i<h.t.length;i++){ if(dd(h.t[i])<last){ pc=h.c[i]; continue; } const j=Math.round((h.t[i]-day0915(h.t[i]))/300); if(j<0||j>74) continue;
    while(c.length<=j){ o.push(null); hi.push(null); lo.push(null); c.push(null); } o[j]=h.o[i]; hi[j]=h.h[i]; lo[j]=h.l[i]; c[j]=h.c[i]; }
  if(c.some(x=>x!=null)){ NCH={o,h:hi,l:lo,c,pc:pc??h.pc,fromHist:true,at:Date.now()}; SLOW.nif=0; } }
let NTF="5"; try{ NTF=localStorage.getItem("gir_ntf")||"5"; }catch(e){}
function nifTf(t){ NTF=t; try{ localStorage.setItem("gir_ntf",t); }catch(e){} SLOW.nif=0; drawMarket(); }
function nifBars(){ const lq=LQ.NIFTY50, live=lq&&QT&&Date.now()/1000-QT<20?lq[0]:null; const n1=MK&&MK.n1, one=NTF==="1"&&!!(n1&&n1.c&&n1.c.some(x=>x!=null));   /* patch 120 */
  const src=one?n1:NCH, N=one?375:75, step=one?1:5; if(!src&&live==null) return null;
  let o=src?src.o.slice():[], h=src?src.h.slice():[], l=src?src.l.slice():[], c=src?src.c.slice():[];
  if(live!=null){ const ist=new Date(Date.now()+19800000); const j=Math.min(N-1,Math.floor((ist.getUTCHours()*60+ist.getUTCMinutes()-555)/step));
    if(j>=0){ if(c.length-1>j){ o=[];h=[];l=[];c=[]; }
      while(c.length<j+1){ o.push(null);h.push(null);l.push(null);c.push(null); }
      if(c[j]==null){ o[j]=h[j]=l[j]=c[j]=live; } else { c[j]=live; h[j]=Math.max(h[j]??live,live); l[j]=Math.min(l[j]??live,live); } } }
  if(!c.some(x=>x!=null)) return null; return {o,h,l,c,pc:NCH&&NCH.pc,N,one}; }
function nifC(i,o,h,l,c,S){ if(o==null) o=c; if(h==null) h=Math.max(o,c); if(l==null) l=Math.min(o,c); const y=v=>S.T+S.PH*(1-(v-S.lo)/(S.hi-S.lo)); const x=S.L+S.xs*(i+0.5), col=c>=o?"var(--up)":"var(--dn)";
  const yt=y(Math.max(o,c)), yb=y(Math.min(o,c));
  return `<line x1="${x.toFixed(1)}" x2="${x.toFixed(1)}" y1="${y(h).toFixed(1)}" y2="${y(l).toFixed(1)}" stroke="${col}"/><rect x="${(x-S.cw/2).toFixed(1)}" y="${yt.toFixed(1)}" width="${S.cw.toFixed(1)}" height="${Math.max(1,yb-yt).toFixed(1)}" fill="${col}"/>`; }
function nifLast(N,S){ const i=N.c.length-1, c=N.c[i], o=N.o[i]??c; const y=S.T+S.PH*(1-(c-S.lo)/(S.hi-S.lo));
  return nifC(i,N.o[i],N.h[i],N.l[i],c,S)+`<rect x="${S.W-S.R+1}" y="${(y-7).toFixed(1)}" width="${S.R-2}" height="14" fill="${c>=o?"var(--up)":"var(--dn)"}"/><text x="${S.W-S.R+4}" y="${(y+4).toFixed(1)}" fill="#000" font-size="10" font-weight="700">${inr(c)}</text>`; }
function nifSVG(N,L,R,T,PH,W){ const vals=[]; N.h.forEach(v=>v!=null&&vals.push(v)); N.l.forEach(v=>v!=null&&vals.push(v)); N.c.forEach(v=>v!=null&&vals.push(v)); if(N.pc) vals.push(N.pc);
  let lo=Math.min(...vals), hi=Math.max(...vals); const pad=(hi-lo)*0.08||5; lo-=pad; hi+=pad;
  const S={lo,hi,L,R,T,PH,W,xs:(W-L-R)/(N.N||75),cw:Math.max(1,(W-L-R)/(N.N||75)*0.68),last:N.c.length-1}; NSC=S; const y=v=>T+PH*(1-(v-lo)/(hi-lo));
  let g=""; for(const v of [hi-pad,lo+pad]) g+=`<text x="${W-R+4}" y="${(y(v)+3).toFixed(1)}" fill="var(--dim)" font-size="9">${inr(Math.round(v))}</text>`;
  if(N.pc) g+=`<line x1="${L}" x2="${W-R}" y1="${y(N.pc).toFixed(1)}" y2="${y(N.pc).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="3 3"/><text x="${L+2}" y="${(y(N.pc)-3).toFixed(1)}" fill="var(--dim)" font-size="9">prev close ${inr(N.pc)}</text>`;
  for(let i=0;i<N.c.length-1;i++) if(N.c[i]!=null) g+=nifC(i,N.o[i],N.h[i],N.l[i],N.c[i],S);
  return g+`<g id="nifL">${nifLast(N,S)}</g>`; }
function nifTick(){ if(!NSC||VIEW!=="market") return; const N=nifBars(); if(!N) return; const i=N.c.length-1;
  if(i!==NSC.last||N.h[i]>NSC.hi||N.l[i]<NSC.lo||N.c[i]>NSC.hi||N.c[i]<NSC.lo){ SLOW.nif=0; return; }      // a new candle or a new high / low: redraw
  const g=document.getElementById("nifL"); if(g){ const h=nifLast(N,NSC); if(g._h!==h){ g._h=h; g.innerHTML=h; } } }
function mkOpen(s){ if(wsWide()&&!SOLO){ openWin(s); return; } setView("all"); HOMED=true; focusOn(s); }
let OPEN_SEC="";
document.addEventListener("visibilitychange",()=>{ if(!document.hidden&&FOC){ pullLive(); pullChart(); pullOI(); pullChk(); } });
function mkSec(n){ OPEN_SEC=n; WS.sec=n; WS.k="chg"; WS.dir=-1; wsSave(); WSKEY=""; if(!(wsWide()&&!SOLO)) setView("all"); const T=(TAPE||[]).filter(r=>((SECS.find(x=>x.name===n)||{}).syms||[]).includes(r.s)).sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0)); HOMED=true; if(T.length) focusOn(T[0].s); else homeOpen(); }
const mkHeat=v=>{ if(v==null) return "transparent"; const a=Math.min(1,Math.abs(v)/2.5); return v>=0?`rgba(30,215,96,${(0.12+a*0.75).toFixed(2)})`:`rgba(255,59,74,${(0.12+a*0.75).toFixed(2)})`; };
const mkPc=v=>v==null?"—":(v>=0?"+":"")+Number(v).toFixed(2)+"%";
/* patch 107: a MARKET panel is rewritten only when its content changed (it blinked: every panel was rebuilt every second) */
const SLOW={};
function MKH(id){ return { set innerHTML(h){ const e=$(id); if(e&&e._h!==h){ e._h=h; e.innerHTML=h; } } }; }
/* patch 120: each GIR sector (the F&O shares, each one vote) next to the official NSE sector index (size-weighted) + its drivers */
const SIDX_MAP=[[/CAPITAL M/,"NIFTY CAPITAL MKT"],[/CAPITAL G/,"NIFTY INDIA MFG"],[/^BANK/,"NIFTY BANK"],[/NBFC|FINANC/,"NIFTY FIN SERVICE"],[/INSUR/,"NIFTY FIN SERVICE"],[/^IT\b|TECHNOLOG/,"NIFTY IT"],
  [/HEALTH|PHARMA/,"NIFTY HEALTHCARE"],[/AUTO/,"NIFTY AUTO"],[/FMCG/,"NIFTY FMCG"],[/METAL|MINING/,"NIFTY METAL"],[/OIL|GAS/,"NIFTY OIL AND GAS"],[/POWER|ENERGY/,"NIFTY ENERGY"],
  [/CEMENT|MATERIAL/,"NIFTY COMMODITIES"],[/CONSTRUCT|INFRA/,"NIFTY INFRA"],[/REALTY/,"NIFTY REALTY"],[/CONSUMER D/,"NIFTY CONSR DURBL"],[/CONSUMER S/,"NIFTY CONSUMPTION"],
  [/CHEMICAL/,"NIFTY CHEMICALS"],[/MEDIA/,"NIFTY MEDIA"],[/SERVICES/,"NIFTY SERV SECTOR"]];
function secIdx(name){ const n=String(name||"").toUpperCase(); const m=SIDX_MAP.find(([re])=>re.test(n)); const S=(MK&&MK.sidx)||{}; return m&&S[m[1]]?Object.assign({n:m[1]},S[m[1]]):null; }
function secDrivers(name,chg){ const sx=(SECS||[]).find(x=>x.name===name); if(!sx) return []; const sg=(chg||0)>=0?1:-1;
  return (TAPE||[]).filter(r=>(sx.syms||[]).includes(r.s)&&r.chg!=null).sort((a,b)=>(b.chg-a.chg)*sg).slice(0,2); }
/* patch 123: 📊 NEWS REACTION - every news line from now on, and what the share, NIFTY and BANKNIFTY did */
let NRT=null, NRX=null;
async function pullReact(){ const v=await getJ("react?k="+encodeURIComponent(K)); if(v){ NRX=v; drawReact(); } }
function drawReact(){ const el=$("nreact"); if(!el||!NRX) return; const R=NRX.rows||[];
  const f=v=>v==null?'<span class="dim">—</span>':`<span class="${v>0?"pu":v<0?"pd":"dim"}">${v>0?"+":""}${v.toFixed(1)}%</span>`;
  const lv={critical:"🚨",important:"📰",minor:"📄",market:"🏛"};
  el.innerHTML=`<div class="rx"><h3>📊 NEWS REACTION <span class="dim">${esc(NRX.day||"")} · ${R.length} news lines · the reader's side right by the close: ${(NRX.right||[0,0])[0]} of ${(NRX.right||[0,0])[1]} · moves from the moment the news came (after hours: from the next open)</span></h3>`
    +(R.length?`<table class="rxt"><tr class="dim"><td>time</td><td>share</td><td>news</td><td>5 min</td><td>15 min</td><td>1 hour</td><td>close</td><td>next day</td><td>NIFTY 15m · close</td><td>BANKNIFTY 15m · close</td><td></td></tr>${R.map(r=>`<tr class="k" onclick="${r.s!=="MARKET"?`focusOn('${esc(r.s)}')`:""}"><td class="dim">${esc(r.t)}${r.ah?"<br><small>after hrs</small>":""}</td><td><b>${esc(r.s)}</b> <span class="${r.side==="CE"?"pu":r.side==="PE"?"pd":"dim"}">${r.side==="CE"?"▲":r.side==="PE"?"▼":"·"}</span></td><td class="rxh">${lv[r.lvl]||""} ${esc(String(r.head||"").slice(0,120))}</td><td>${f(r.m5)}</td><td>${f(r.m15)}</td><td>${f(r.m60)}</td><td>${f(r.mc)}</td><td>${f(r.mn)}</td><td>${f(r.n15)} · ${f(r.nc)}</td><td>${f(r.b15)} · ${f(r.bc)}</td><td>${r.right==null?"":r.right?'<span class="pu">✔</span>':'<span class="pd">✖</span>'}</td></tr>`).join("")}</table>`
     :'<div class="empty">from now on every news line lands here with what the share, NIFTY and BANKNIFTY did after it</div>')+`</div>`; }
function drawMarket(){ if(VIEW!=="market"||!D) return; const M=MK||{}; drawEarly(); MKH("nifTf").innerHTML=`<a class="${NTF==="1"?"on":""}" onclick="nifTf('1')">1m</a><a class="${NTF!=="1"?"on":""}" onclick="nifTf('5')">5m</a>`;
  if(wsWide()) document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px");
  // F&O MOVERS: gainers | losers
  { const el=$("mk-mov"); const T=(TAPE||[]).filter(r=>r.chg!=null).slice().sort((a,b)=>b.chg-a.chg); const n=Math.max(12,Math.floor((el.clientHeight||300)/15)-1);
    const up=T.filter(r=>r.chg>0).slice(0,n), dn=T.filter(r=>r.chg<0).reverse().slice(0,n); const N=Math.max(up.length,dn.length);
    const wide=(el.clientWidth||300)>=430; const cell=r=>r?`<td class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b></td>${wide?`<td class="r dim">${r.px!=null?inr(r.px):""}</td>`:""}<td class="r ${cls(r.chg)}${qfl(r.s)}">${mkPc(r.chg)}</td>`:(wide?"<td></td><td></td><td></td>":"<td></td><td></td>");
    $("mk-movh").textContent=`${T.filter(r=>r.chg>0).length} up · ${T.filter(r=>r.chg<0).length} down · tap = its trading screen`;
    MKH(el.id).innerHTML=`<table>${Array.from({length:N},(_,i)=>`<tr>${cell(up[i])}<td style="border-left:1px solid var(--line);padding:0"></td>${cell(dn[i])}</tr>`).join("")}</table>`; }
  // NIFTY through the day (% from the open) + F&O advance − decline
  if(SLOW.nif&&Date.now()-SLOW.nif<5000&&!drawMarket.force&&$("mk-nif").querySelector("svg")){ nifTick(); } else { SLOW.nif=Date.now(); const el=$("mk-nif"); const W=Math.max(260,el.clientWidth), H=Math.max(200,el.clientHeight); const A=(M.nifty||[]).filter(v=>v!=null), B=(M.adv||[]).slice();
    if(QT&&Date.now()/1000-QT<20&&(TAPE||[]).length){ const ist_=new Date(Date.now()+19800000), j_=Math.min(74,Math.floor((ist_.getUTCHours()*60+ist_.getUTCMinutes()-555)/5));   // patch 113: live
      if(j_>=0){ let u_=0,d_=0; for(const r of TAPE){ if(r.chg>0) u_++; else if(r.chg<0) d_++; } if(B.length>j_+1) B.length=0; while(B.length<j_) B.push(B.length?B[B.length-1]:0); B[j_]=u_-d_; } }
    const ix=(D.idx||{}).NIFTY||{}, bx=(D.idx||{}).BANKNIFTY||{};
    const NB_=nifBars(); if(!NB_) NSC=null;
    if(A.length<2&&B.length<2&&!NB_){ MKH(el.id).innerHTML='<div class="empty">the day\'s path starts with the first 5-min bar (09:20)</div>'; }
    else { const L=6,R=54,T=40,PH=(H-T-22)*0.62,G=14,BH=(H-T-22)-PH-G; const NB=Math.max(A.length,B.length,2); const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-1, 1));
      const sc=(arr,y0,h)=>{ let lo=Math.min(0,...arr),hi=Math.max(0,...arr); if(hi===lo){hi+=1;lo-=1;} return v=>y0+h*(1-(v-lo)/(hi-lo)); };
      const ya=sc(A,T,PH), yb=sc(B,T+PH+G,BH); let g="";
      for(let k=0;k<5;k++){ const y=T+PH*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${y}" y2="${y}" stroke="var(--line)"/>`; }
      if(NB_) g+=nifSVG(NB_,L,R,T,PH,W);
      else if(A.length>1){ g+=`<line x1="${L}" x2="${W-R}" y1="${ya(0)}" y2="${ya(0)}" stroke="var(--dim)" stroke-dasharray="3 3"/><polyline fill="none" stroke="#fff" stroke-width="1.5" points="${A.map((v,i)=>`${x(i).toFixed(1)},${ya(v).toFixed(1)}`).join(" ")}"/><text x="${W-R+4}" y="${(ya(A[A.length-1])+4).toFixed(1)}" fill="#fff" font-size="10">${mkPc(A[A.length-1]).replace("%","")}</text>`; }
      if(B.length>1){ const z=yb(0); g+=`<line x1="${L}" x2="${W-R}" y1="${z}" y2="${z}" stroke="var(--dim)" stroke-dasharray="3 3"/>`+B.map((v,i)=>`<rect x="${x(i).toFixed(1)}" y="${Math.min(z,yb(v)).toFixed(1)}" width="${Math.max(1,(W-L-R)/NB-0.8).toFixed(1)}" height="${Math.abs(yb(v)-z).toFixed(1)}" fill="${v>=0?"var(--up)":"var(--dn)"}" opacity=".8"/>`).join("")+`<text x="${W-R+4}" y="${(T+PH+G+10)}" fill="var(--dim)" font-size="9">up−down</text><text x="${W-R+4}" y="${(T+PH+G+22)}" fill="${B[B.length-1]>=0?"var(--up)":"var(--dn)"}" font-size="10">${B[B.length-1]>0?"+":""}${B[B.length-1]}</text><text x="${W-R+4}" y="${(T+PH+G+33)}" fill="var(--dim)" font-size="8">${B[B.length-1]>=0?"more up":"more down"}</text>`; }
      g+=["09:15","10:30","11:45","13:00","14:15","15:30"].map((t,k)=>`<text x="${(L+(W-L-R)*k/5).toFixed(0)}" y="${H-4}" fill="var(--dim)" font-size="9" text-anchor="${k===0?"start":k===5?"end":"middle"}">${t}</text>`).join("");
      g+=`<text x="${L+2}" y="12" fill="#fff" font-size="11">NIFTY ${ix.last!=null?inr(ix.last):""} <tspan fill="${(ix.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(ix.chg)}</tspan></text><text x="${L+2}" y="23" fill="var(--amber)" font-size="10">BANKNIFTY ${bx.last!=null?inr(bx.last):""} <tspan fill="${(bx.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(bx.chg)}</tspan></text><text x="${L+2}" y="34" fill="var(--dim)" font-size="9">${NB_?(NCH&&NCH.fromHist&&!(QT&&Date.now()/1000-QT<20)?"NIFTY 5-min candles, the last session":"NIFTY "+(NB_.one?"1":"5")+"-min candles, "+(QT&&Date.now()/1000-QT<20?"live":"the last session")):"line = NIFTY % from the open"} · bars = F&amp;O shares up minus down</text>`;
      MKH(el.id).innerHTML=`<svg width="${W}" height="${H}">${g}</svg>`; } }
  // live: every sector's average move and the F&O up / down from the second-by-second prices (patch 99)
  const LV={}; { const by={}; (TAPE||[]).forEach(r=>by[r.s]=r); for(const x of (SECS||[])){ const v=(x.syms||[]).map(s=>by[s]&&by[s].chg).filter(v=>v!=null); if(v.length) LV[x.name]=v.reduce((a,b)=>a+b,0)/v.length; }
    if(M.sectors) M.sectors.forEach(x=>{ if(LV[x.name]!=null) x.chg=+LV[x.name].toFixed(2); });
    const T=(TAPE||[]).filter(r=>r.chg!=null); if(T.length){ M.fo_up=T.filter(r=>r.chg>0).length; M.fo_dn=T.filter(r=>r.chg<0).length; } }
  // SECTOR DONUT
  if(SLOW.don&&Date.now()-SLOW.don<5000&&!drawMarket.force&&$("mk-don").querySelector("svg")){} else { SLOW.don=Date.now(); const el=$("mk-don"); const W=Math.max(260,el.clientWidth), H=Math.max(200,el.clientHeight); const S=(M.sectors&&M.sectors.length?M.sectors:(SECS||[]).map(x=>({name:x.name,n:(x.syms||[]).length,chg:x.chg}))).filter(x=>x.n);
    if(!S.length){ MKH(el.id).innerHTML='<div class="empty">no sectors yet</div>'; }
    else { const R=Math.min(H/2-12,W*0.23), cx=R+10, cy=H/2, r=R*0.52; const tot=S.reduce((a,x)=>a+x.n,0); let ang=-Math.PI/2, g="";
      S.forEach(x=>{ const a0=ang,a1=ang+2*Math.PI*x.n/tot; ang=a1; const p=(a,rr)=>[(cx+rr*Math.cos(a)).toFixed(1),(cy+rr*Math.sin(a)).toFixed(1)]; const lg=a1-a0>Math.PI?1:0; const [x0,y0]=p(a0,R),[x1,y1]=p(a1,R),[x2,y2]=p(a1,r),[x3,y3]=p(a0,r);
        g+=`<path class="k" onclick="mkSec('${esc(x.name)}')" d="M${x0},${y0} A${R},${R} 0 ${lg} 1 ${x1},${y1} L${x2},${y2} A${r},${r} 0 ${lg} 0 ${x3},${y3} Z" fill="${mkHeat(x.chg)}" stroke="#07090c" stroke-width="1.5"><title>${esc(x.name)} ${mkPc(x.chg)} · ${x.n} shares</title></path>`; });
      const all=(TAPE||[]).filter(r=>r.chg!=null); const av=all.length?all.reduce((a,r)=>a+r.chg,0)/all.length:null;
      g+=`<text x="${cx}" y="${cy-4}" fill="#fff" font-size="11" text-anchor="middle">F&amp;O</text><text x="${cx}" y="${cy+12}" fill="${(av||0)>=0?"var(--up)":"var(--dn)"}" font-size="12" font-weight="700" text-anchor="middle">${mkPc(av)}</text>`;
      const lx=cx+R+14, lh=Math.max(11,Math.min(16,(H-8)/S.length)); g+=S.slice().sort((a,b)=>(b.chg??-99)-(a.chg??-99)).map((x,i)=>`<g class="k" onclick="mkSec('${esc(x.name)}')"><rect x="${lx}" y="${6+i*lh}" width="9" height="${lh-3}" fill="${mkHeat(x.chg)}"/><text x="${lx+14}" y="${6+i*lh+lh-5}" fill="var(--txt)" font-size="9">${esc(x.name.toUpperCase().slice(0,14))} <tspan fill="var(--dim)">${x.n}</tspan></text><text x="${W-6}" y="${6+i*lh+lh-5}" fill="${(x.chg||0)>=0?"var(--up)":"var(--dn)"}" font-size="9" text-anchor="end">${mkPc(x.chg)}</text>${(si=>si&&si.chg!=null?`<text x="${W-50}" y="${6+i*lh+lh-5}" fill="var(--dim)" font-size="8" text-anchor="end">index ${(si.chg>=0?"+":"")+si.chg.toFixed(2)}</text>`:"")(secIdx(x.name))}</g>`).join("");
      MKH(el.id).innerHTML=`<svg width="${W}" height="${H}">${g}</svg>`; } }
  // F&O MONEY: the shares with the most fresh futures money, per build-up
  { const mo=M.money||{}; const blk=(b,c)=>{ const xs=mo[b]||[]; return `<div><h4 class="${c}">${b}</h4><table>${xs.length?xs.map(x=>`<tr class="k" onclick="mkOpen('${esc(x.s)}')"><td><b>${esc(x.s)}</b></td><td class="r ${c}">₹${Math.abs(Math.round(x.cr||0))} cr</td><td class="r dim">OI ${x.oi>0?"+":""}${x.oi??"—"}%</td><td class="r ${cls(x.chg)}">${mkPc(x.chg)}</td></tr>`).join(""):'<tr><td class="dim">none yet</td></tr>'}</table></div>`; };
    MKH("mk-mon").innerHTML=`<div class="mn">${blk("LONG BUILD-UP","pu")}${blk("SHORT BUILD-UP","pd")}${blk("SHORT COVERING","pu")}${blk("LONG UNWINDING","pd")}</div><div class="legend" style="padding:3px 6px">LONG BUILD-UP = price up + OI up (fresh buying) · SHORT BUILD-UP = price down + OI up (fresh selling) · SHORT COVERING = price up + OI down · LONG UNWINDING = price down + OI down</div>`; }
  // F&O DESK: expiry · PCR · VIX · FII/DII · market · ban · results
  { const C=M.chain||{}; const vx=(D.idx||{}).VIX||{}; const ew=C.days!=null&&C.days<=4;
    const spark=(arr)=>{ if(!arr||arr.length<2) return ""; const W=110,H=18; const vs=arr.map(x=>x[1]); const lo=Math.min(...vs),hi=Math.max(...vs); return `<svg width="${W}" height="${H}" style="vertical-align:middle;margin-left:6px"><polyline fill="none" stroke="#4fc3f7" stroke-width="1.4" points="${vs.map((v,i)=>`${(W*i/(vs.length-1)).toFixed(1)},${(H-2-(H-4)*((v-lo)/((hi-lo)||1))).toFixed(1)}`).join(" ")}"/></svg>`; };
    const fd=M.fiidii; const fdt=fd==null?"not read":typeof fd==="object"?Object.entries(fd).slice(0,4).map(([k,v])=>`${esc(k).toUpperCase()} <b class="${(+v||0)>=0?"pu":"pd"}">${typeof v==="number"?(v>0?"+":"")+inr(Math.round(v)):esc(String(v))}</b>`).join(" · "):esc(String(fd));
    MKH("mk-dsk").innerHTML=`<div><em>EXPIRY</em><b class="${ew?"am":""}">${C.exp?esc(C.exp):"—"}</b>${C.days!=null?` · ${C.days} day${C.days===1?"":"s"} left`:""}${ew?' · <b class="am">EXPIRY WEEK</b> — premiums melt fast':""}</div>
      <div><em>PCR</em><b>${C.pcr_now??"—"}</b> <span class="dim">stocks, puts ÷ calls</span>${spark(C.pcr)}</div>
      <div><em>VIX</em><b>${vx.last!=null?inr(vx.last):(M.vix??"—")}</b> <span class="${cls(vx.chg)}">${vx.chg!=null?mkPc(vx.chg):""}</span></div>
      <div><em>MARKET</em>${(()=>{ const nc=((D.idx||{}).NIFTY||{}).chg, tot=(M.fo_up||0)+(M.fo_dn||0), br=tot?(M.fo_up||0)/tot:null; const w=nc==null||br==null?(M.india||"—"):(nc>0.3&&br>0.55)?"BULLISH":(nc<-0.3&&br<0.45)?"BEARISH":"SIDEWAYS"; return `<b class="${w==="BULLISH"?"pu":w==="BEARISH"?"pd":""}">${esc(w)}</b> <span class="dim">NIFTY ${mkPc(nc)}</span>`; })()} · F&amp;O <span class="pu">${M.fo_up??"—"} up</span> · <span class="pd">${M.fo_dn??"—"} down</span></div>
      <div><em>FII / DII</em>${fdt}</div>
      <div><em>BAN</em>${(M.ban||[]).length?(M.ban||[]).map(x=>`<b class="pd">${esc(x)}</b>`).join(" "):'<span class="dim">no share in the F&amp;O ban today</span>'}${(M.ban||[]).length?' <span class="dim">— no new positions</span>':""}</div>
      <div><em>RESULTS</em>${(C.results||[]).length?(C.results||[]).slice(0,10).map(r=>`<span class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b> <span class="dim">${esc((r.d||"").slice(5))}</span></span>`).join(" · "):'<span class="dim">no F&amp;O results in the next 7 days</span>'}</div>`; }
  // SECTORS THROUGH THE DAY
  { const S=M.sectors||[], L0=M.labels||[]; const fit=Math.max(2,Math.floor((($("mk-hea").clientWidth||400)-330)/38)-1); const cut=Math.max(0,L0.length-fit), L=L0.slice(cut);
    MKH("mk-hea").innerHTML=S.length&&L.length?`<table class="hm"><tr><td></td>${L.map(t=>`<td class="dim">${t}</td>`).join("")}<td class="am">NOW</td><td class="am" title="the official NSE sector index - size-weighted, every listed share of the sector">NSE INDEX</td><td class="dim" style="text-align:left">DRIVEN BY</td></tr>${S.map(x=>`<tr class="k" onclick="mkSec('${esc(x.name)}')"><td>${esc(x.name.toUpperCase().slice(0,16))}</td>${(x.series||[]).slice(cut).map(v=>`<td style="background:${mkHeat(v)};color:#fff">${v==null?"":(v>=0?"+":"")+v.toFixed(1)}</td>`).join("")}<td style="background:${mkHeat(x.chg)};color:#fff;font-weight:700">${x.chg==null?"":(x.chg>=0?"+":"")+x.chg.toFixed(1)}</td>${(si=>si?`<td style="background:${mkHeat(si.chg)};color:#fff" title="${esc(si.n)} ${si.last}">${si.chg==null?"":(si.chg>=0?"+":"")+si.chg.toFixed(1)}</td>`:'<td class="dim" title="no NSE index for this sector">—</td>')(secIdx(x.name))}<td style="text-align:left;white-space:nowrap">${secDrivers(x.name,x.chg).map(r=>`<span class="${cls(r.chg)}">${esc(r.s)} ${(r.chg>=0?"+":"")+r.chg.toFixed(1)}</span>`).join(" · ")}</td></tr>`).join("")}</table>`:'<div class="empty">fills from the first 30 minutes of the day</div>'; }
  // OI BUILD-UP BY SECTOR
  { const S=M.sectors||[]; const B=[["LONG BUILD-UP","LONG BU",1],["SHORT BUILD-UP","SHORT BU",-1],["SHORT COVERING","SHORT COV",1],["LONG UNWINDING","LONG UNW",-1]]; const bc=M.bu_cnt||{};
    MKH("mk-bus").innerHTML=S.length?`<table class="hm"><tr><td></td>${B.map(b=>`<td class="${b[2]>0?"pu":"pd"}">${b[1]}</td>`).join("")}</tr>${S.map(x=>`<tr class="k" onclick="mkSec('${esc(x.name)}')"><td>${esc(x.name.toUpperCase())}</td>${B.map(b=>{ const k=(x.bu||{})[b[0]]||0; return `<td style="background:${k?mkHeat(b[2]*k/Math.max(1,x.n)*3):"transparent"};color:#fff">${k||""}</td>`; }).join("")}</tr>`).join("")}<tr><td><b>ALL F&amp;O</b></td>${B.map(b=>`<td><b class="${b[2]>0?"pu":"pd"}">${bc[b[0]]??""}</b></td>`).join("")}</tr></table>`:'<div class="empty">from the first futures reading</div>'; }
  // OI SCENARIOS + NEWS, newest first
  { const sc=((D.scn||{}).today||[]).map(r=>({t:r.t,k:"🧩",s:r.s,h:r.name,c:r.side==="CE"?"pu":r.side==="PE"?"pd":"dim",l:r.line})); const nw=(D.news||[]).map(x=>({t:(x.hm||"").slice(-5),k:x.s==="MARKET"?"🏛":"📰",s:x.s,h:x.h,c:x.side>0?"pu":x.side<0?"pd":"dim",l:x.why||"",u:x.l||""}));
    const F_=MKNF; const all=sc.concat(nw).filter(r=>F_==="all"||(F_==="oi"&&r.k==="🧩")||(F_==="sh"&&r.k==="📰")||(F_==="mkt"&&r.k==="🏛")).sort((a,b)=>(b.t||"")>(a.t||"")?1:-1).slice(0,40);
    const cnt={all:sc.length+nw.length,oi:sc.length,sh:nw.filter(r=>r.k==="📰").length,mkt:nw.filter(r=>r.k==="🏛").length};
    MKH("mk-nf").innerHTML=`<span class="nf">${[["all","ALL"],["oi","🧩 OI"],["sh","📰 SHARES"],["mkt","🏛 MARKET"]].map(([k,l])=>`<a class="${F_===k?"on":""}" onclick="mkNf('${k}')" title="${{all:"everything, newest first",oi:"how the money is building in a share (OI scenarios, market hours)",sh:"news on an F&O share (filings, articles that name the company)",mkt:"news that moves the whole market (FM, RBI, SEBI, Fed ...)"}[k]}">${l} ${cnt[k]}</a>`).join("")}</span>`;
    MKH("mk-nws").innerHTML=all.length?`<table>${all.map(r=>`<tr class="k" onclick="mkOpen('${esc(r.s||"")}')"><td class="am">${esc(r.t||"")}</td><td>${r.k} <b>${esc(r.s||"")}</b> <span class="${r.c}">${r.u?nlink({l:r.u},(r.h||"").slice(0,70)):esc((r.h||"").slice(0,60))}</span>${r.l?`<br><span class="dim">${esc(r.l.slice(0,90))}</span>`:""}</td></tr>`).join("")}</table>`:'<div class="empty">'+({oi:"no OI scenario yet - they fire in market hours (from 09:20)",sh:"no share news in the last 26 hours",mkt:"no market-moving headline in the last 26 hours"}[MKNF]||"no scenario or news yet today")+'</div>'; }
}
window.addEventListener("resize",()=>{ if(VIEW==="market"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; } });
/* ---------- patch 108: THE ALARM (loud, two-tone, repeated) ---------- */
let AVOL=1.0;   // patch 113: always the loud alarm
let AMASTER=null;
function amaster(){ acUnlock(); if(AMASTER&&AMASTER.context===AC) return AMASTER;
  const comp=AC.createDynamicsCompressor(); comp.threshold.value=-18; comp.knee.value=6; comp.ratio.value=8; comp.attack.value=0.002; comp.release.value=0.1;
  const g=AC.createGain(); g.gain.value=2.4*AVOL; comp.connect(g); g.connect(AC.destination); AMASTER=comp; AMASTER._g=g; return comp; }
function tone(t,f,dur,vol){ const o=AC.createOscillator(), o2=AC.createOscillator(), g=AC.createGain(); o.type="square"; o2.type="sawtooth"; o.frequency.value=f; o2.frequency.value=f*2;
  o.connect(g); o2.connect(g); g.connect(amaster()); g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(Math.max(0.001,vol),t+0.01); g.gain.setValueAtTime(vol,t+dur-0.03); g.gain.exponentialRampToValueAtTime(0.0001,t+dur);
  o.start(t); o2.start(t); o.stop(t+dur+0.02); o2.stop(t+dur+0.02); }
function alarm(kind){ if(!ASND||AVOL<=0) return; try{ acUnlock(); amaster()._g.gain.value=2.4*AVOL; const t0=AC.currentTime+0.02, v=1.0;
  if(kind==="act"){ for(let r=0;r<3;r++){ for(let i=0;i<4;i++){ tone(t0+r*1.1+i*0.22,i%2?1319:988,0.2,v); } } }      // TRADE ALERT: hi-lo siren x 3 (about 3 s)
  else { for(let r=0;r<2;r++) for(let i=0;i<3;i++) tone(t0+r*0.9+i*0.26,i===2?988:740,0.22,v); } }catch(e){} }                                // MOVING: 3 rising tones
function beep(n,f){ alarm(n>=3?"act":"move"); }
function volSet(v){ AVOL=v; try{ localStorage.setItem("gir_vol",String(v)); }catch(e){} if(!ASND){ ASND=true; try{ localStorage.setItem("gir_snd","1"); }catch(e){} } alarm("act"); drawAlerts(true); }
function volHTML(){ return `<span class="vol">${[[0.35,"LOW"],[0.7,"MED"],[1,"HIGH"]].map(([v,l])=>`<a class="${ASND&&Math.abs(AVOL-v)<0.01?"on":""}" onclick="volSet(${v})">${l}</a>`).join("")}<a onclick="alarm('act')" title="play the TRADE ALERT sound">🔊 TEST</a></span>`; }

/* ---------- patch 108: ✓ SELF-CHECK - clicks through every key, panel and tab on THIS server's data and shows what works ---------- */
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function selfCheck(only){ if(SOLO){ try{ window.opener.focus(); window.opener.selfCheck(only); return; }catch(e){ toMain("market"); return; } }
  selfCheck.on=true; try{ return await selfCheck2(only); } finally{ selfCheck.on=false; } }
async function selfCheck2(only){ const R=[]; const add=(area,name,st,detail)=>R.push({area,name,st,detail:detail||""}); const txt=id=>{ const e=$(id); return e?(e.innerText||"").trim():""; };
  const box=$("chkres"); box.hidden=false; box.innerHTML='<div class="ckh">✓ SELF-CHECK running… (about 40 seconds - the screens will move by themselves)</div>';
  const errs=[]; const onerr=e=>errs.push(String(e.message||e)); window.addEventListener("error",onerr);
  const wasView=VIEW;
  try{
  // the data
  const now=Date.now()/1000; const T=TAPE||[];
  add("DATA","F&O shares on the page",T.length>=150?"PASS":T.length?"WARN":"FAIL",`${T.length} shares`);
  add("DATA","every share has a price",T.filter(r=>r.px!=null).length>=T.length*0.95?"PASS":"FAIL",`${T.filter(r=>r.px!=null).length} of ${T.length}`);
  add("DATA","prices live every second",QT&&now-QT<15?"PASS":"WARN",QT?`last tick ${Math.round(now-QT)} s ago`:"no live prices (market closed - they start 09:15)");
  const I=(D&&D.idx)||{}; add("DATA","NIFTY · SENSEX · BANKNIFTY · VIX",["NIFTY","SENSEX","BANKNIFTY","VIX"].every(k=>I[k]&&I[k].last)?"PASS":"FAIL",["NIFTY","SENSEX","BANKNIFTY","VIX"].map(k=>k+" "+(I[k]&&I[k].last!=null?inr(I[k].last):"—")).join(" · "));
  const S=SECS||[]; const inS=new Set(S.flatMap(x=>x.syms||[])); add("DATA","sectors (NSE), every share in one",S.length>=10&&T.every(r=>inS.has(r.s))?"PASS":"WARN",`${S.length} sectors · ${T.filter(r=>!inS.has(r.s)).length} shares without a sector`);
  add("DATA","alerts list (NOW) loaded",Array.isArray(D&&D.now)?"PASS":"FAIL",`${(D&&D.now||[]).length} lines today`);
  add("DATA","news loaded",(D&&D.news||[]).length?"PASS":"WARN",`${(D&&D.news||[]).length} items (26 h) · ${(D&&D.news||[]).filter(x=>x.s==="MARKET").length} market headlines`);
  add("ALERTS","sound unlocked in this browser",AC&&AC.state==="running"?"PASS":"WARN",AC?AC.state:"click once on the page so the browser allows sound");
  add("ALERTS","sound on · volume",ASND?"PASS":"FAIL",ASND?(sndArmed()?"the loud alarm is ready":"tap the page once so the browser lets it ring"):"SOUND OFF - tap it to turn on");
  // MARKET
  setView("market"); await sleep(1500); await pullMarket(true); await sleep(1500);
  add("MARKET","the screen opens",VIEW==="market"?"PASS":"FAIL");
  for(const [id,n] of [["mk-mov","F&O MOVERS"],["mk-nif","NIFTY · F&O BREADTH"],["mk-don","SECTORS donut"],["mk-mon","F&O MONEY"],["mk-dsk","F&O DESK"],["mk-hea","SECTORS THROUGH THE DAY"],["mk-bus","OI BUILD-UP BY SECTOR"],["mk-nws","OI SCENARIOS · NEWS"]]){
    const e=$(id), t=txt(id), g=e&&e.querySelector("svg,table"); add("MARKET",n,(g&&t.length>10)||t.length>60?"PASS":/fills from|starts with|no scenario|none yet/.test(t)?"WARN":"FAIL",t.replace(/\s+/g," ").slice(0,90)); }
  const C=(MK&&MK.chain)||{}; add("MARKET","expiry · PCR",C.exp&&C.pcr_now!=null?"PASS":"FAIL",`expiry ${C.exp||"—"} (${C.days??"—"} days) · PCR ${C.pcr_now??"—"}`);
  add("MARKET","F&O money leaders",MK&&Object.values(MK.money||{}).some(v=>v.length)?"PASS":"WARN",Object.entries((MK&&MK.money)||{}).map(([k,v])=>k.split(" ")[0][0]+k.split(" ")[1][0]+" "+v.length).join(" · "));
  // the function keys
  for(const [v,l,b] of [["now","1 NOW","nowl"],["three","2 THE THREE","threel"],["scn","3 OI SCENARIOS","scnl"],["secs","4 SECTORS","secs"],["tape","5 F&O TAPE","tapel"],["news","6 NEWS","newsl"],["picks","7 PICKS","pkl"],["tom","8 TOMORROW","tml"],["myfo","9 MY F&O","mfl"],["desk","0 DESK P&L","dkl"]]){
    setView(v); await sleep(900); const sec=$(v); const vis=sec&&getComputedStyle(sec).display!=="none"; const t=txt(b)||txt(v);
    add("KEYS",l,vis&&t.length>15?(/no |not yet|nothing|forms from|builds it|none/i.test(t.slice(0,80))?"WARN":"PASS"):"FAIL",t.replace(/\s+/g," ").slice(0,90)); }
  goHome(); await sleep(600); add("KEYS","⌂ HOME",wsWide()?(VIEW==="market"?"PASS":"FAIL"):"PASS",wsWide()?"opens MARKET":"the overview (phone)");
  // one share, in this window
  const sym=only||(T.slice().sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0))[0]||{}).s;     // the day's biggest mover
  if(sym){ setView("all"); const t0_=Date.now(); focusOn.inner=true; const fp_=focusOn(sym); focusOn.inner=false; await Promise.race([fp_,sleep(20000)]);
    while(!(FD&&FD.s===sym)&&Date.now()-t0_<20000) await sleep(250); const ms_=Date.now()-t0_; await sleep(5000);
    add("SHARE "+sym,"its data arrives",FD&&FD.s===sym?(ms_<3000?"PASS":ms_<8000?"WARN":"FAIL"):"FAIL",FD&&FD.s===sym?`in ${(ms_/1000).toFixed(1)} s`:"no answer in 20 s");
    add("SHARE "+sym,"its screen opens",FOC===sym&&!$("focus").hidden?"PASS":"FAIL");
    add("SHARE "+sym,"price and change",FD&&(FD.px||FD.spot)?"PASS":"FAIL",`₹${inr((FLV&&FLV.px)||FD&&(FD.px||FD.spot))} · ${pc(((T.find(r=>r.s===sym)||{}).chg))}`);
    const rows=oiRows(); const withP=rows.filter(r=>r.ce_p!=null||r.pe_p!=null).length, withD=rows.filter(r=>r.ce_d!=null||r.pe_d!=null).length;
    add("SHARE "+sym,"OI at every strike",rows.length>=6?"PASS":"FAIL",`${rows.length} strikes · source ${(FOI&&FOI.src)||"—"} · ${FOI&&FOI.ref_t?FOI.ref_t+" → "+FOI.last_t:"no readings"}`);
    add("SHARE "+sym,"premiums (CE / PE LTP)",rows.length&&withP>=rows.length*0.6?"PASS":"FAIL",`${withP} of ${rows.length} strikes`);
    add("SHARE "+sym,"ΔOI since the first reading",rows.length&&withD>=rows.length*0.6?"PASS":rows.length?"WARN":"FAIL",`${withD} of ${rows.length} strikes`);
    const sr=srLevels(rows,(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0); add("SHARE "+sym,"resistance / support",sr.R.length&&sr.S.length?"PASS":"FAIL",`R1 ${sr.R[0]?sr.R[0].k:"—"} · S1 ${sr.S[0]?sr.S[0].k:"—"} · ${sr.nR} strong R · ${sr.nS} strong S`);
    add("SHARE "+sym,"OI line through the day",FOI&&FOI.series&&FOI.series.t.length>1?"PASS":"WARN",FOI&&FOI.series?`${FOI.series.t.length} readings`:"—");
    add("SHARE "+sym,"F&O checklist",FCK&&FCK.s===sym&&FCK.CE?"PASS":"FAIL",FCK&&FCK.s===sym?`expiry ${FCK.exp} · lot ${FCK.lot} · IV ${FCK.iv}% · IVP ${FCK.ivp} · CE ${FCK.CE&&FCK.CE.verdict} · PE ${FCK.PE&&FCK.PE.verdict}`:"not read");
    if(PXM!=="pro") pxMode("pro"); await sleep(3500);
    add("SHARE "+sym,"PRO chart (history + today)",PC&&PC.B&&PC.B.length>100?"PASS":PC&&PC.B&&PC.B.length?"WARN":"FAIL",PC&&PC.B?`${PC.B.length} bars · ${new Set(PC.B.map(b=>Math.floor((b.t+19800)/86400))).size} days`:"no chart");
    for(const [f,l] of [["proSet('tf','15')","15m"],["proSet('tf','D')","1D"],["proSet('study','macd')","MACD"],["proSet('study','oi')","OI study"],["proSet('tf','5')","5m"],["proSet('study','rsi')","RSI"]]){ const n0=errs.length; try{ eval(f); }catch(e){ errs.push(e.message); } await sleep(700); add("SHARE "+sym,"PRO "+l,errs.length===n0&&PC&&PC.B&&PC.B.length?"PASS":"FAIL",PC&&PC.lg?PC.lg.innerText.replace(/\s+/g," ").slice(0,70):""); }
    for(const m of ["chart","table"]){ oiMode(m); await sleep(500); add("SHARE "+sym,"OI BUILD-UP "+m.toUpperCase(),(($("wsOiB")||$("fbody")||{}).innerText||"").length>80?"PASS":"FAIL"); }
    oiMode("chart");
    add("SHARE "+sym,"news on the share",(FD&&FD.news||[]).length?"PASS":"WARN",(FD&&FD.news||[]).length?`${FD.news.length} items`:"no news on this share in 26 h");
    unfocus(); }
  add("PAGE","no script errors during the check",errs.length?"FAIL":"PASS",errs.slice(0,2).join(" | "));
  }catch(e){ add("PAGE","the check itself",'FAIL',String(e.message||e)); }
  window.removeEventListener("error",onerr);
  setView(wsWide()?"market":(wasView||"all"));
  const n={PASS:0,WARN:0,FAIL:0}; R.forEach(r=>n[r.st]++);
  box.innerHTML=`<div class="ckh">✓ SELF-CHECK ${new Date().toLocaleTimeString("en-IN",{timeZone:"Asia/Kolkata"})} · <b class="pu">${n.PASS} PASS</b> · <b class="am">${n.WARN} WARN</b> · <b class="pd">${n.FAIL} FAIL</b><a onclick="$('chkres').hidden=true">✕ close</a><a onclick="selfCheck()">↻ run again</a></div>
    <table>${R.map(r=>`<tr class="${r.st}"><td>${r.st==="PASS"?"✔":r.st==="WARN"?"–":"✖"}</td><td class="dim">${esc(r.area)}</td><td>${esc(r.name)}</td><td>${esc(r.detail)}</td></tr>`).join("")}</table>
    <div class="legend">PASS = working with this server's data · WARN = working, nothing to show yet (closed market / no event) · FAIL = broken - send a photo of this list</div>`;
  return R; }
/* ---------- patch 89: the function keys and the panels ---------- */
let VIEW="all"; try{ VIEW=localStorage.getItem("gir_fk")||"all"; }catch(e){}
let PN=null, PNT=null;
const rsx=v=>v==null?"—":(v<0?"−₹":"₹")+Math.abs(Math.round(v)).toLocaleString("en-IN");
function setView(v){ if(SOLO&&v!=="all"){ toMain(v); return; } VIEW=v; try{ localStorage.setItem("gir_fk",v); }catch(e){}
  if(v!=="all"&&FOC&&wsWide()) unfocus();                       // a function key shows its panel; HOME brings the trading screen back
  document.body.classList.toggle("one",v!=="all");
  document.querySelectorAll("#fkeys a").forEach(a=>a.classList.toggle("on",a.dataset.v===v));
  document.querySelectorAll("#grid>section").forEach(x=>x.classList.toggle("on",x.id===v));
  if(v==="market"){ drawMarket.force=true; drawMarket(); drawMarket.force=false; pullMarket(true); }
  if(v==="news"){ pullReact(); if(!NRT) NRT=setInterval(()=>{ if(VIEW==="news"&&!document.hidden) pullReact(); },20000); }   /* patch 123 */
  if(["picks","tom","myfo","desk"].includes(v)){ loadPanels(); if(!PNT) PNT=setInterval(()=>{ if(["picks","tom","myfo","desk"].includes(VIEW)) loadPanels(); },10000); }
  window.scrollTo(0,0); }
async function loadPanels(){ try{ const r=await fetch("panels?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ PN=await r.json(); drawPanels(); } }catch(e){} }
function pkRow(r){ const ce=r.act==="BUY CE"; return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)} <span class="${cls(r.chg)}">${pc(r.chg)}</span></small></div><div><div class="do ${ce?"up":"dn"}">BUY ${r.k} ${esc(r.kind||"")} at ₹${r.p}${r.cost?` · 1 lot ₹${inr(r.cost)}`:""}</div><div class="why">${esc(r.title||"")}${r.vd?` · chain ${esc(r.vd)}`:""} · target ₹${r.tgt} (≈ +${r.gain}%) · stop ${ce?"below":"above"} ₹${r.stop??"—"} · room ${r.room}%${r.late?' · <span class="am">late — moved a lot already</span>':""}</div></div></div>`; }
function drawPanels(){ const P=PN||{};
  // PICKS
  const B=P.box_picks||{}; const M=P.my_pos||[];
  $("pkh").textContent=B.n_read?`${B.n_buy} of ${B.n_read} F&O shares say BUY · read ${B.t||""}`:(P.closed?"market closed · fills from 09:20 on the next session":"waiting for the first read");
  let h=""; if(M.length) h+=`<div class="hd2">💼 YOUR OPEN TRADES — checked against the box every sweep</div>`+M.map(m=>{ const ce=m.kind==="CE"; return `<div class="r" onclick="focusOn('${esc(m.s)}')"><div class="sy"><b>${esc(m.s)}</b><small class="${ce?"pu":"pd"}">${m.k} ${esc(m.kind)}</small></div><div><div class="do ${m.pnl>0?"up":m.pnl<0?"dn":""}">bought ₹${m.buy} → now ${m.ltp!=null?"₹"+m.ltp:"not read"}${m.pnl!=null?` (${m.pnl>0?"+":""}${m.pnl}%)`:""}</div><div class="why">${m.note?esc(m.note):`share ₹${m.spot} · roof ₹${m.roof??"—"} · floor ₹${m.floor??"—"} · box ${esc(m.box||"")}`}</div>${(m.flags||[]).map(f=>`<div class="am">⚠ ${esc(f)}</div>`).join("")}</div></div>`; }).join("");
  h+=`<div class="hd2">▲ BUY CE — share going up</div>`+((B.ce||[]).map(pkRow).join("")||'<div class="empty">none right now</div>');
  h+=`<div class="hd2">▼ BUY PE — share going down</div>`+((B.pe||[]).map(pkRow).join("")||'<div class="empty">none right now</div>');
  if((B.edge||[]).length) h+=`<div class="hd2">ON A WALL — the next break</div>`+B.edge.map(r=>`<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)}</small></div><div><div class="do ${r.side==="CE"?"up":"dn"}">${r.side==="CE"?"testing the roof":"testing the floor"} ₹${r.k} · ${r.away_pct}% away</div><div class="why">${esc(r.do||"")} · target ${esc(r.target||"")}</div></div></div>`).join("");
  $("pkl").innerHTML=h;
  // TOMORROW
  const T=P.tomorrow||{}; const tr=(T.ce||[]).concat(T.pe||[]);
  $("tmh").textContent=T.t?`list at ${T.t}${T.frozen?" · frozen":""} · buy 14:30 · sell by 09:30 the day after`:"the list forms from 14:00";
  $("tml").innerHTML=tr.length?tr.map(r=>{ const up=r.side==="CE"; return `<div class="r" onclick="focusOn('${esc(r.s)}')"><div class="sy"><b>${esc(r.s)}</b><small>₹${inr(r.spot)} <span class="${cls(r.chg)}">${pc(r.chg)}</span></small></div><div><div class="do ${up?"up":"dn"}">${r.strong?"⭐ STRONG · ":""}${up?"UP → CE":"DOWN → PE"} · ${r.k??""} ${esc(r.side)} ₹${r.p??"—"}${r.cost?` · 1 lot ₹${inr(r.cost)}`:""} · stop ₹${r.stop_p??"—"}</div><div class="why">${esc((r.why||[]).join(" · "))}${r.vd?` · chain ${esc(r.vd)}`:""}${r.late?' · <span class="am">moved a lot already — half size</span>':""}</div></div></div>`; }).join(""):'<div class="empty">no TOMORROW list yet — it forms from 14:00 and is final at 14:30</div>';
  // MY F&O
  const L=P.ledger||{}, S=L.sum||{}; const rows=L.rows||[]; const op=rows.filter(r=>r.net==null), cl=rows.filter(r=>r.net!=null).slice(0,15);
  $("mfl").innerHTML=`<div class="kp"><div><small>TODAY</small><b class="${cls(S.today)}">${rsx(S.today)}</b></div><div><small>SINCE START</small><b class="${cls(S.total)}">${rsx(S.total)}</b></div><div><small>TRADES · WON</small><b>${S.n||0} · ${S.wins||0}</b></div><div><small>OPEN · COST</small><b>${S.open||0} · ${rsx(S.open_cost)}</b></div></div>
    <form onsubmit="return mfAdd(event)"><input id="mf_s" placeholder="SHARE" style="width:110px;text-transform:uppercase"><select id="mf_k"><option>CE</option><option>PE</option></select><input id="mf_k2" placeholder="strike" inputmode="decimal"><input id="mf_q" placeholder="qty" inputmode="numeric"><input id="mf_b" placeholder="buy ₹" inputmode="decimal"><button>+ ADD TRADE</button></form><div class="msg" id="mf_m"></div>
    ${op.length?`<div class="hd2">OPEN</div>`+op.map(r=>`<div class="r"><div class="sy"><b onclick="focusOn('${esc(r.sym)}')">${esc(r.sym)}</b><small>${r.strike} ${esc(r.kind)} · ${r.qty} qty</small></div><div><div class="do">bought ₹${r.buy} · cost ${rsx(r.cost)}</div><div class="why"><input id="mfx_${r.id}" placeholder="sell ₹" inputmode="decimal" style="width:80px"> <button onclick="mfExit(${r.id})">EXIT</button></div></div></div>`).join(""):""}
    ${cl.length?`<div class="hd2">CLOSED</div>`+cl.map(r=>`<div class="r"><div class="sy"><b>${esc(r.sym)}</b><small>${esc(r.day)} · ${r.strike} ${esc(r.kind)}</small></div><div><div class="do ${r.net>0?"up":"dn"}">₹${r.buy} → ₹${r.sell} · NET ${rsx(r.net)}</div><div class="why">charges ${rsx(r.charges)} · gross ${rsx(r.gross)}</div></div></div>`).join(""):'<div class="empty">no closed trade yet</div>'}`;
  // DESK P&L
  const p=P.pnl||{}, H=P.hist||[], HS=P.hist_sum||{}; const mx=Math.max(...H.map(x=>Math.abs(x.net)),1);
  $("dkl").innerHTML=`<div class="kp"><div><small>TODAY (PAPER)</small><b class="${cls(p.total)}">${P.closed?"—":rsx(p.total)}</b></div><div><small>SINCE START</small><b class="${cls(HS.cum)}">${rsx(HS.cum)}</b></div><div><small>DAYS · GREEN</small><b>${HS.days||0} · ${HS.green||0}</b></div><div><small>TRADES</small><b>${HS.n||0}</b></div></div>
    ${H.length?`<div class="bars">${H.map(x=>`<i title="${esc(x.d)} ${rsx(x.net)}" style="height:${Math.max(2,Math.abs(x.net)/mx*60)}px;background:${x.net>=0?"var(--up)":"var(--dn)"};opacity:.8"></i>`).join("")}</div><div class="why" style="padding:4px 8px">the last ${H.length} days, one bar a day · green = a winning day</div>`:""}
    ${H.slice().reverse().slice(0,12).map(x=>`<div class="r"><div class="sy"><b>${esc(x.d.slice(5))}</b><small>${x.n} trades · ${x.w} won</small></div><div><div class="do ${x.net>=0?"up":"dn"}">${rsx(x.net)}</div><div class="why">running ${rsx(x.cum)}</div></div></div>`).join("")}`; }
async function mfAdd(ev){ ev.preventDefault(); const m=$("mf_m"); m.textContent="saving…";
  const d=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const day=d.toISOString().slice(0,10);
  try{ const r=await fetch("ledger?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({op:"add",sym:$("mf_s").value.toUpperCase().trim(),kind:$("mf_k").value,strike:$("mf_k2").value,qty:$("mf_q").value,buy:$("mf_b").value,sell:"",expiry:"",day:day,note:""})});
    if(!r.ok) throw new Error(await r.text()); m.textContent="saved ✓"; loadPanels(); }catch(e){ m.textContent="not saved: "+e.message; } return false; }
async function mfExit(id){ const v=+($("mfx_"+id).value||0); if(!v){ $("mfx_"+id).focus(); return; }
  try{ const r=await fetch("ledger?k="+encodeURIComponent(K),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({op:"exit",id:id,sell:v})}); if(!r.ok) throw new Error(await r.text()); loadPanels(); }catch(e){ $("mf_m").textContent="not saved: "+e.message; } }
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return; const k=e.key; const m={"`":"market","m":"market","M":"market","1":"now","2":"three","3":"scn","4":"secs","5":"tape","6":"news","7":"picks","8":"tom","9":"myfo","0":"desk"}; if(m[k]) setView(m[k]); });
{ const u_=unfocus; unfocus=function(){ u_(); if(!SOLO&&VIEW==="all"&&!selfCheck.on) setView("market"); }; }   // patch 109: closing a share goes back to MARKET
if(SOLO){ document.body.classList.add("solo"); VIEW="all"; document.title=SOLO; } else { const v0_=(new URLSearchParams(location.search)).get("v"); VIEW=["now","three","scn","secs","tape","news","picks","tom","myfo","desk"].includes(v0_)?v0_:"market"; }   // patch 109: the page always opens on MARKET   // patch 102: MARKET is home
loop(); stream(); loadThree();
setInterval(()=>{ if(document.hidden) return; try{ fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}).then(r=>r.ok?r.json():null).then(v=>{ if(v) render(v); }).catch(()=>{});
  if(VIEW==="market") pullMarket(true); if(FOC){ pullLive(); pullChart(); pullOI(); pullChk(); if(PXM==="pro") pullHist(true); } }catch(e){} }, 300000);   // patch 113: the 5-min full refresh
let ESR=0; setInterval(()=>{ const ist_=new Date(Date.now()+19800000), m_=ist_.getUTCHours()*60+ist_.getUTCMinutes(), wd_=ist_.getUTCDay();
  if(wd_<1||wd_>5||m_<555||m_>930||!QT||Date.now()/1000-QT<15||Date.now()-ESR<30000) return;
  ESR=Date.now(); try{ if(ES) ES.close(); }catch(e){} stream(); }, 5000);   // patch 113: a stalled price stream reconnects
 setInterval(loadThree,120000); setView(VIEW); if(SOLO){ HOMED=true; focusOn(SOLO); }
</script></body></html>
HTML_P123
cat > $D/p123test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p123test.py - OI build-up lines reach Box Picks (every acting scenario) and ring with a side; 📊 the news reaction:
the share, NIFTY and BANKNIFTY at the news, +5 / +15 / +60 min, the close, the next close, the 15:45 summary. Fixtures only."""
import os, sys, json, time, sqlite3, tempfile, shutil, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


import alertword, dashserve, engine2

sc = open(os.path.join(B, "scenarios.py"), encoding="utf-8").read()
check("every acting OI scenario goes to Box Picks (box_when = ALL), the cautious ones too",
      'cfg.get("box_when") == "ALL")   # patch 123' in sc and (json.load(open(os.path.join(B, "data", "scn_config.json"))).get("box_when") == "ALL"))
L = "🧩 CALL WRITERS RUNNING ▲ TITAN ₹3500 +1.2% · 10:42\nCE 3600 OI 5.2 L → 3.1 L\nWATCH — not a trade yet: the roof ₹3550 is only 1.4% above"
check("an OI build-up with a side rings (something is happening); without a side it stays silent",
      alertword.tier(L) == "move" and alertword.tier("🧩 BOXED IN · TITAN ₹3500 · 10:42\nboth sides written") == "read")
check("the ⚡ EARLY board counts it as 🔭 OI", dashserve._sig_of("🧩", L.split("\n")[0], L) == ("oi", "OI build-up", None))

SENT = []
engine2.tg_fo = lambda t: SENT.append(t) or True
tmp = tempfile.mkdtemp()
base0 = dashserve.BASE
real = dashserve.dt.datetime
try:
    dashserve.BASE = tmp
    IST = dashserve.IST
    day = dt.datetime.now(IST).strftime("%Y-%m-%d")
    while dt.datetime.strptime(day, "%Y-%m-%d").weekday() >= 4:          # a Mon-Thu, so the next day is a weekday too
        day = (dt.datetime.strptime(day, "%Y-%m-%d") - dt.timedelta(days=1)).strftime("%Y-%m-%d")
    nxt = (dt.datetime.strptime(day, "%Y-%m-%d") + dt.timedelta(days=1)).strftime("%Y-%m-%d")
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
    c.execute("insert into alerts values(?,?,?,?,?,?)", (day, "09:00:00", "📰", "OLD", "CE", "📰 NEWS ▲ OLD · x"))
    c.commit(); c.close()
    clock = {"t": None}

    class FakeDT(dt.datetime):
        @classmethod
        def now(cls, tz=None):
            return clock["t"]
    dashserve.dt.datetime = FakeDT
    PR = {"TITAN": 3500.0, "NIFTY50": 25000.0, "BANK": 59000.0}
    dashserve.quotes_live = lambda: {"t": time.time(), "q": {"TITAN": [PR["TITAN"], 1.0], "NIFTY50": [PR["NIFTY50"], 0.2]}}
    dashserve.live_obj = lambda: {"idx": {"BANKNIFTY": {"last": PR["BANK"]}}}
    at = lambda d, hm: real.strptime(d + " " + hm, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
    clock["t"] = at(day, "09:59:00"); dashserve._RX.update({"rowid": None, "summary": None}); dashserve.react_tick()
    c = sqlite3.connect(os.path.join(tmp, "tomorrow.db"))
    c.execute("insert into alerts values(?,?,?,?,?,?)", (day, "10:00:00", "📰", "TITAN", "CE", "📰 NEWS ▲ TITAN · RESULTS · ET 10:00\nTitan Q2 profit up 32%"))
    c.execute("insert into alerts values(?,?,?,?,?,?)", (day, "10:00:00", "🏛", "MARKET", "", "🏛 MARKET NEWS ▲ likely UP · 10:00 · ET"))
    c.execute("insert into alerts values(?,?,?,?,?,?)", (day, "10:00:01", "🧩", "TITAN", "CE", "🧩 CALL WRITERS RUNNING ▲ TITAN"))
    c.commit(); c.close()
    for hm, t_, n_, b_ in (("10:00:05", 3500, 25000, 59000), ("10:05:10", 3510, 25010, 59020), ("10:15:10", 3535, 25025, 59050),
                           ("11:00:10", 3570, 25050, 59100), ("15:26:00", 3600, 25100, 59200), ("15:29:50", 3605, 25110, 59210)):
        clock["t"] = at(day, hm); PR.update({"TITAN": float(t_), "NIFTY50": float(n_), "BANK": float(b_)}); dashserve.react_tick()
    clock["t"] = at(nxt, "15:28:00"); PR.update({"TITAN": 3640.0, "NIFTY50": 25200.0, "BANK": 59300.0}); dashserve.react_tick()
    v = dashserve.react(day)
    R = {r["s"]: r for r in v["rows"]}
    t = R.get("TITAN") or {}
    check("the old line from before the start is not tracked; the OI line (🧩) is not news", "OLD" not in R and len(v["rows"]) == 2)
    check("TITAN results news ▲ at 10:00: +5 min %s · +15 min %s · +1 h %s · the close %s · the next close %s" % (t.get("m5"), t.get("m15"), t.get("m60"), t.get("mc"), t.get("mn")),
          (t.get("m5"), t.get("m15"), t.get("m60"), t.get("mc"), t.get("mn")) == (0.29, 1.0, 2.0, 3.0, 4.0))
    check("NIFTY and BANKNIFTY alongside: NIFTY 15m %s close %s · BANKNIFTY 15m %s close %s" % (t.get("n15"), t.get("nc"), t.get("b15"), t.get("bc")),
          t.get("n15") == 0.1 and t.get("nc") == 0.44 and t.get("b15") == 0.08 and t.get("bc") == 0.36)
    check("the reader's side was right (▲ and +3%% by the close): %s · the day: %s" % (t.get("right"), v.get("right")), t.get("right") is True and v.get("right") == [1, 1])
    check("the market line: NIFTY's own move by the close %s" % (R.get("MARKET") or {}).get("mc"), (R.get("MARKET") or {}).get("mc") == 0.44)
    clock["t"] = at(day, "15:46:00")
    s1 = dashserve.react_summary(); s2 = dashserve.react_summary()
    check("15:45: 📊 NEWS REACTION to Box Picks once: %s" % (s1 or "").split("\n")[0], s1 and s1.startswith("📊 NEWS REACTION") and "TITAN" in s1 and "✔" in s1 and s2 is None and len(SENT) == 1)
finally:
    dashserve.dt.datetime = real
    dashserve.BASE = base0
    shutil.rmtree(tmp, ignore_errors=True)
pg = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the page: 📊 NEWS REACTION on the NEWS screen; 🧩 OI lines on the alert bar", "function drawReact()" in pg and 'id="nreact"' in pg and 'if(k==="🧩")' in pg)
print("\nP123 OI ALERTS + NEWS REACTION TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
python3 $W/p123_patch.py $D || { rm -f $D/p123test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
grep -q "function drawReact()" $W/home.html && grep -q "function drawEarly()" $W/home.html && grep -q "</html>" $W/home.html || { echo "the new page is not complete"; back; }
cp $W/home.html $D/home.html
cd $D && python3 -m py_compile scenarios.py alertword.py dashserve.py p123test.py || back
timeout 120 python3 p123test.py 2>&1 | grep "OK  \|FAIL\|REACTION TEST"
timeout 120 python3 p123test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p114test.py p116test.py p118test.py p119test.py p120test.py p122test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-desk gir-intraday gir-newsroom gir-exchange gir-dash && sleep 15
echo "desk: $(systemctl is-active gir-desk) · engine: $(systemctl is-active gir-intraday) · newsroom: $(systemctl is-active gir-newsroom) · exchange: $(systemctl is-active gir-exchange) · page: $(systemctl is-active gir-dash)"
for u in gir-desk gir-intraday gir-newsroom gir-exchange gir-dash; do [ "$(systemctl is-active $u)" = "active" ] || { echo "$u did not come back"; back; }; done
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function drawReact()" || { echo "the new page is not being served"; back; }
echo
echo "PATCH 123 APPLIED. From Monday 09:15: every OI build-up (🧩) in GIR Box Picks within seconds; every news line tracked on the NEWS screen (key 6)."
echo "    too many 🧩 lines?  echo '{\"box_when\": \"WATCH\"}' > $D/data/scn_config.json   (only the clean ones) - no restart needed"
