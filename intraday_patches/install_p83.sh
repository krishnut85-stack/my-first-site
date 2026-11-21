#!/bin/bash
# PATCH 83 - THE SHARE'S OWN LIVE WINDOW (on top of patch 82). Tap a share (or type it) and FOCUS becomes its window, Kite order:
#   · PRICE: today's 5-minute candles with volume, VWAP (amber), yesterday's close (dashed), PDH/PDL, the last price tag -
#     and the last candle moves with every tick (/live, once a second while the window is open; the engine already puts
#     the share's whole strike band on the socket when the page asks)
#   · OI BUILD-UP: calls | strike | puts with the OI bars, LTP, and ΔOI since the day's first reading (new /oi: the engine's
#     15-min chain readings within 8%), the roof / floor marked, the at-the-money strike in amber, totals and PCR, and the
#     trend of total call / put OI through the day; the live per-minute OI path of the strikes on ticks rides along
#   · THE DESK: the ticket, the four agents' lines, the chain picture, the share's news - as before
#   Same data, no new Kite call: /chart (charts.json, every 10 s), /live (focus_ticks.json), chains.db chain15, dash_state oi_live.
#   Edits dashserve.py (exact anchors: /oi) and replaces home.html. Installs p83test.py. Restarts gir-dash.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g83; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p83.sh now"; exit 1; fi
grep -q 'id="cmd"' $D/home.html || { echo "patch 82 is not installed yet - paste patch 82 first"; exit 1; }
grep -q '"/oi"' $D/dashserve.py && { echo "patch 83 is already installed"; exit 1; }
F="dashserve.py home.html"
for f in $F; do [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }; cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p83test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p83_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p83_patch.py - PATCH 83 (server side): /oi?sym= - the OI build-up of one share for the day: every strike's OI at the
day's first reading and now (chains.db chain15, every 15 min within 8%), the 15-min series of total CE / PE OI, and the
per-minute OI path of the strikes the engine has on ticks (dash_state oi_live). Cached 15 s per share. Read-only.
Usage: python3 p83_patch.py /home/globalbot/intraday  (every anchor must match exactly once, else nothing is written)"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {}


def E(f, old, new):
    EDITS.setdefault(f, []).append((old, new))


E("dashserve.py", '''def live_ticks(sym):''', '''_OI = {}
_STJ = {"m": 0.0, "v": {}}


def state_json():
    """dash_state.json parsed once per change (the engine writes it every second)"""
    try:
        m = os.path.getmtime(STATE)
        if m != _STJ["m"]:
            _STJ["v"], _STJ["m"] = json.load(open(STATE)), m
    except Exception:
        pass
    return _STJ["v"] or {}


def oi_day(sym):
    """the OI build-up of one share today, as Kite shows it and more:
    rows[strike] = {"ce": [oi_first, oi_now, ltp_now], "pe": [...]} from chain15 (the engine's 15-min readings within 8%)
    series = {"t": ["09:30", ...], "ce": [total CE OI], "pe": [total PE OI], "spot": [...]} through the day
    live = {"CE 2600": [[minute, oi, ltp], ...]} the per-minute path of the strikes on the tick feed (the engine's oi_live)"""
    sym = "".join(ch for ch in (sym or "").upper() if ch.isalnum() or ch in "&-")[:20]
    now = time.time()
    c_ = _OI.get(sym)
    if c_ and now - c_[0] < 15:
        return c_[1]
    today = dt.datetime.now(IST).strftime("%Y-%m-%d")
    out = {"s": sym, "day": today, "exp": None, "ref_t": None, "last_t": None, "rows": {}, "series": {"t": [], "ce": [], "pe": [], "spot": []}, "live": {}}
    try:
        con = sqlite3.connect("file:%s?mode=ro" % os.path.join(BASE, "chains.db"), uri=True, timeout=3)
        rows = con.execute("select t, exp, strike, kind, oi, ltp, spot from chain15 where d=? and sym=? order by t", (today, sym)).fetchall()
        if not rows:                                            # before the first 15-min reading, or a closed day: the last day there is
            d_ = con.execute("select max(d) from chain15 where sym=?", (sym,)).fetchone()[0]
            if d_:
                out["day"] = d_
                rows = con.execute("select t, exp, strike, kind, oi, ltp, spot from chain15 where d=? and sym=? order by t", (d_, sym)).fetchall()
        con.close()
        if rows:
            exps = sorted({r[1] for r in rows}); exp = exps[0]; out["exp"] = exp
            rows = [r for r in rows if r[1] == exp]
            ts = sorted({r[0] for r in rows}); out["ref_t"], out["last_t"] = ts[0], ts[-1]
            first = {(r[2], r[3]): r for r in rows if r[0] == ts[0]}
            last = {}
            for r in rows:
                last[(r[2], r[3])] = r
            for (k, kd), r in last.items():
                f = first.get((k, kd))
                row = out["rows"].setdefault("%g" % k, {})
                row[kd.lower()] = [f[4] if f else None, r[4], r[5]]
            by_t = {}
            for r in rows:
                b = by_t.setdefault(r[0], {"ce": 0.0, "pe": 0.0, "spot": r[6]})
                b["ce" if r[3] == "CE" else "pe"] += r[4] or 0
            for t_ in ts:
                b = by_t[t_]; out["series"]["t"].append(t_); out["series"]["ce"].append(int(b["ce"])); out["series"]["pe"].append(int(b["pe"])); out["series"]["spot"].append(b["spot"])
    except Exception as ex:
        out["err"] = str(ex)[:80]
    try:
        st = state_json()
        if st.get("day") == today:
            for e in (st.get("oi_live") or {}).get(sym) or []:
                lab = str(e.get("k") or "")
                m = re.match(r"^(CE|PE)\\s+([\\d.]+)", lab) or re.match(r"^([\\d.]+)\\s+(CE|PE)", lab)
                if m:
                    kd, k = (m.group(1), m.group(2)) if m.group(1) in ("CE", "PE") else (m.group(2), m.group(1))
                    out["live"]["%s %g" % (kd, float(k))] = e.get("p") or []
    except Exception as ex:
        out["err_live"] = str(ex)[:80]
    _OI[sym] = (now, out)
    return out


def live_ticks(sym):''')
E("dashserve.py", '''            if u.path == "/fo":''', '''            if u.path == "/oi":                       # the OI build-up of one share for the day (FOCUS)
                return self.send(200, json.dumps(oi_day((parse_qs(u.query).get("sym") or [""])[0]), ensure_ascii=False, default=str), "application/json; charset=utf-8")
            if u.path == "/fo":''')


def main():
    bad = 0
    texts = {}
    for f, edits in EDITS.items():
        p = os.path.join(D, f)
        if not os.path.exists(p):
            print("MISSING %s" % p); bad += 1; continue
        s = open(p, encoding="utf-8").read()
        for i, (old, new) in enumerate(edits, 1):
            n = s.count(old)
            if n != 1:
                print("ANCHOR %s #%d found %d times (need 1): %r" % (f, i, n, old[:90])); bad += 1
        texts[f] = s
    if bad:
        print("p83: %d anchors did not match - nothing written" % bad); sys.exit(1)
    for f, edits in EDITS.items():
        s = texts[f]
        for old, new in edits:
            s = s.replace(old, new, 1)
        open(os.path.join(D, f), "w", encoding="utf-8").write(s)
        print("p83: %-12s %2d edits" % (f, len(edits)))


if __name__ == "__main__":
    main()
PY_PATCH
cat > $W/home.html <<'HTML_P83'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>GIR</title>
<style>
:root{--bg:#000;--panel:#07090c;--line:#1a2230;--line2:#243040;--dim:#7d8b9c;--txt:#d6dee8;--hi:#ffffff;--amber:#ffb000;--amber2:#ffcc4d;--up:#1ed760;--dn:#ff3b4a;--wt:#ffb000;
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
#focus table.oi{width:100%;border-collapse:collapse;table-layout:fixed;font-size:11px}
#focus table.oi th{font-size:9px;color:var(--dim);font-weight:400;padding:3px 4px;border-bottom:1px solid var(--line);letter-spacing:.06em;text-align:right}
#focus table.oi th.k{text-align:center}#focus table.oi th.l{text-align:left}
#focus table.oi td{padding:3px 4px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap;position:relative;overflow:hidden}
#focus table.oi td.k{text-align:center;color:var(--hi);font-weight:700;background:#0b0e13}
#focus table.oi td.l{text-align:left}
#focus table.oi tr.atm td.k{color:var(--amber);outline:1px solid var(--amber);outline-offset:-1px}
#focus table.oi tr.wall td.k::after{content:" ▪";color:var(--amber)}
#focus table.oi td i{position:absolute;top:0;bottom:0;opacity:.22;z-index:0}
#focus table.oi td.ce i{right:0;background:var(--dn)}#focus table.oi td.pe i{left:0;background:var(--up)}
#focus table.oi td span{position:relative;z-index:1}
#focus table.oi td.d.up span{color:var(--up)}#focus table.oi td.d.dn span{color:var(--dn)}
#focus table.oi tr.tot td{color:var(--hi);border-top:1px solid var(--line2);font-weight:700}
#focus .legend{padding:3px 8px;font-size:10px;color:var(--dim);border-bottom:1px solid var(--line)}
#focus .legend i{display:inline-block;width:9px;height:9px;vertical-align:middle;margin:0 3px 0 8px}
@media(min-width:1100px){#focus svg.px{height:260px}}
/* the news ticker at the bottom */
#tick{position:fixed;left:0;right:0;bottom:0;height:30px;background:#000;border-top:1px solid var(--amber);display:flex;align-items:center;overflow:hidden;z-index:15}
#tick .lb{background:var(--amber);color:#000;font-weight:700;font-size:11px;padding:0 8px;height:100%;display:flex;align-items:center;letter-spacing:.08em;flex:none}
#tick .run{white-space:nowrap;will-change:transform;font-size:12px;padding-left:12px}
#tick .run b{color:var(--hi)}#tick .run em{font-style:normal;color:var(--dim);margin:0 10px 0 0}
</style></head><body>
<div id="top">
  <div id="idx"></div>
  <div id="cmd"><span class="pr">&gt;</span><input id="q" placeholder="TICKER  ·  type a share, Enter = FOCUS" autocomplete="off" autocapitalize="characters"><button id="go">GO</button><select id="secsel"><option value="">ALL SECTORS</option></select><a class="x" id="unf" onclick="unfocus()">✕ ALL</a></div>
</div>
<div id="grid">
  <section class="p" id="now"><h2>NOW <small id="hnow">moving right now · newest first · every line went to Telegram the same second</small></h2><div id="nowl"></div></section>
  <section class="p" id="focus" hidden></section>
  <section class="p" id="three"><h2 id="h3">THE THREE</h2><div id="threel"></div></section>
  <section class="p" id="secs"><h2>SECTORS <small>tap a sector to filter the tape · ++ EXTREME · + plain · ✓ confirmed</small></h2><div class="g" id="secg"></div></section>
  <section class="p" id="tape"><h2>F&amp;O TAPE <small id="tfoot"></small></h2><div id="tapel"></div></section>
  <section class="p" id="news"><h2>NEWS <small>filings + headlines · the reader's verdict</small></h2><div id="newsl"></div></section>
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
  return `<div class="brand">GIR</div>${one("NIFTY",I.NIFTY)}${one("SENSEX",I.SENSEX)}${one("BANKNIFTY",I.BANKNIFTY)}${one("VIX",I.VIX)}<div class="st"><span id="clk">${istClock()}</span>${st}${d.ticks_s?`<span>${Math.round(d.ticks_s)} t/s</span>`:""}<span>${(d.now||[]).length} moving</span><span id="ago"></span>${d.ban&&d.ban.length?`<span class="pd">BAN ${esc(d.ban.join(" "))}</span>`:""}</div>`; }
function istClock(){ const t=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); return t.toTimeString().slice(0,8); }
function ageMin(hm){ const n=new Date(Date.now()+(330+new Date().getTimezoneOffset())*60000); const [h,m]=String(hm).split(":").map(Number); return (n.getHours()*60+n.getMinutes())-(h*60+m); }
let lastAt=0; setInterval(()=>{ const c=$("clk"); if(c) c.textContent=istClock(); const a=$("ago"); if(a&&lastAt) a.textContent=`upd ${Math.max(0,Math.round((Date.now()-lastAt)/1000))}s`; },1000);
/* ---------- NOW ---------- */
function nowHTML(rows){ if(!rows.length) return '<div class="empty">nothing has moved yet — the first lines come at 09:30 (FIRST MOVE) and 09:45 (the desk)</div>';
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
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${esc(x.h)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${esc(x.h)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
let nx=0; function runNews(){ const R=$("run"); const w=R.scrollWidth; nx+=0.55; if(nx>w) nx=0; R.style.transform=`translateX(${-nx}px)`; requestAnimationFrame(runNews); } requestAnimationFrame(runNews);
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
function oiRows(){ const o=(FLV&&FLV.ok&&FLV.o&&Object.keys(FLV.o).length)?FLV.o:null; const R=(FOI&&FOI.rows)||{}; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||(FD&&FD.px);
  let ks=o?Object.keys(o).map(Number):(FD&&FD.strikes||[]).map(x=>x.k); if(!ks.length) ks=Object.keys(R).map(Number); ks=[...new Set(ks)].filter(k=>k&&spot&&Math.abs(k/spot-1)<=0.08).sort((a,b)=>b-a);
  return ks.map(k=>{ const kk=String(k); const lo=o&&(o[kk]||o[("%s"===""?kk:kk)]); const ref=R[("%g".length,String(+k))]||R[kk]||{}; const fs=(FD&&FD.strikes||[]).find(x=>x.k===k)||{};
    const ce_oi=lo?lo[1]:(ref.ce?ref.ce[1]:fs.ce), pe_oi=lo?lo[3]:(ref.pe?ref.pe[1]:fs.pe), ce_p=lo?lo[0]:(ref.ce?ref.ce[2]:null), pe_p=lo?lo[2]:(ref.pe?ref.pe[2]:null);
    const ce_d=(ref.ce&&ref.ce[0]!=null&&ce_oi!=null)?ce_oi-ref.ce[0]:null, pe_d=(ref.pe&&ref.pe[0]!=null&&pe_oi!=null)?pe_oi-ref.pe[0]:null;
    return {k,ce_oi,pe_oi,ce_p,pe_p,ce_d,pe_d}; }); }
function oiTable(){ const rows=oiRows(); if(!rows.length) return '<div class="empty">no strikes read yet</div>'; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||0;
  const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const atm=rows.reduce((b,r)=>Math.abs(r.k-spot)<Math.abs(b.k-spot)?r:b,rows[0]);
  const roof=FD&&FD.roof&&FD.roof.k, floor=FD&&FD.floor&&FD.floor.k; let tce=0,tpe=0,tced=0,tped=0,hasd=false;
  const tr=rows.map(r=>{ tce+=r.ce_oi||0; tpe+=r.pe_oi||0; if(r.ce_d!=null){tced+=r.ce_d;hasd=true;} if(r.pe_d!=null){tped+=r.pe_d;}
    const cw=((r.ce_oi||0)/mx*100).toFixed(0), pw=((r.pe_oi||0)/mx*100).toFixed(0);
    return `<tr class="${r===atm?"atm":""}${(r.k===roof||r.k===floor)?" wall":""}"><td class="d ${r.ce_d>0?"up":r.ce_d<0?"dn":""}"><span>${dL(r.ce_d)}</span></td><td class="ce"><i style="width:${cw}%"></i><span>${fmtL(r.ce_oi)}</span></td><td><span>${r.ce_p!=null?r.ce_p:"—"}</span></td><td class="k">${r.k}</td><td class="l"><span>${r.pe_p!=null?r.pe_p:"—"}</span></td><td class="pe l"><i style="width:${pw}%"></i><span>${fmtL(r.pe_oi)}</span></td><td class="d l ${r.pe_d>0?"up":r.pe_d<0?"dn":""}"><span>${dL(r.pe_d)}</span></td></tr>`; }).join("");
  const pcr=tce?(tpe/tce).toFixed(2):"—";
  return `<table class="oi"><thead><tr><th>CE ΔOI</th><th>CE OI</th><th>CE LTP</th><th class="k">STRIKE</th><th class="l">PE LTP</th><th class="l">PE OI</th><th class="l">PE ΔOI</th></tr></thead><tbody>${tr}<tr class="tot"><td class="d ${tced>0?"up":tced<0?"dn":""}"><span>${hasd?dL(tced):""}</span></td><td><span>${fmtL(tce)}</span></td><td><span class="dim">calls</span></td><td class="k">PCR ${pcr}</td><td class="l"><span class="dim">puts</span></td><td class="l"><span>${fmtL(tpe)}</span></td><td class="d l ${tped>0?"up":tped<0?"dn":""}"><span>${hasd?dL(tped):""}</span></td></tr></tbody></table>`; }
function oiTrendSVG(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return ""; const W=720,H=110,L=6,R=58,T=8,B=18; const n=S.t.length; const x=i=>L+(W-L-R)*(i/(n-1));
  const vals=[].concat(S.ce,S.pe); const lo=Math.min(...vals), hi=Math.max(...vals)||1; const y=v=>T+(H-T-B)*(1-(v-lo)/((hi-lo)||1));
  const path=(arr,col)=>`<polyline fill="none" stroke="${col}" stroke-width="1.6" points="${arr.map((v,i)=>`${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ")}"/>`;
  const lab=(arr,col,dy)=>`<text x="${W-R+4}" y="${(y(arr[n-1])+dy).toFixed(1)}" fill="${col}" font-size="10" font-family="monospace">${fmtL(arr[n-1])}</text>`;
  const xs=S.t.map((t,i)=>(i%Math.ceil(n/6)===0||i===n-1)?`<text x="${x(i).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="${i===n-1?"end":"start"}">${t}</text>`:"").join("");
  return `<svg class="oit" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${path(S.ce,"var(--dn)")}${path(S.pe,"var(--up)")}${lab(S.ce,"var(--dn)",3)}${lab(S.pe,"var(--up)",14)}${xs}</svg>`; }
function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const ln=(d&&d.lines)||{}; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?`tick ${FLV.age_p}s ago`:"on ticks"):(f.src||"");
  return `<div class="hd"><b>${esc(f.s)}</b><span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span><span class="dim">${esc(age)}</span><a class="am" style="margin-left:auto" onclick="unfocus()">✕ ALL SHARES</a></div>
    <div class="m ${c}">${d?`DESK ${esc(d.label)} ${d.v>0?"+":""}${d.v}${Math.abs(d.v)===2?(d.conf?" ✓ CONFIRMED":" · awaiting the 5-min confirmation"):""}`:"no desk reading yet (the desk reads from 09:45)"}${d&&d.steps&&d.steps.length?` <span class="dim">· ${esc(d.steps.join(" · "))}</span>`:""}${d&&d.notes&&d.notes.length?` <span class="pd">· ${esc(d.notes.join(" · "))}</span>`:""}</div>
    ${d&&d.ticket?`<div class="tk">▶ ${esc(d.ticket)}${d.stop?` · stop: a close ${d.v>0?"under":"over"} ${d.stop}`:""}${d.line_k?` · line ${d.line_k}`:""}${d.size?`\n${esc(d.size)}`:""}</div>`:""}
    <div class="tabs"><span class="${FTAB==="chart"?"on":""}" onclick="FTAB='chart';paint()">PRICE · 5 MIN</span><span class="${FTAB==="oi"?"on":""}" onclick="FTAB='oi';paint()">OI BUILD-UP</span><span class="${FTAB==="desk"?"on":""}" onclick="FTAB='desk';paint()">THE DESK</span></div>
    <div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; if(!$("fbody")){ F.innerHTML=focusHTML(FD); } else { F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","oi","desk"][i]===FTAB)); const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); hd.replaceWith(tmp.querySelector(".hd")); } }
  const B=$("fbody"); if(!B) return;
  if(FTAB==="chart"){ const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
    B.innerHTML=`<div class="sub"><span>O <b>${n?inr(ch.o[0]):"—"}</b></span><span>H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b></span><span>L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b></span><span>LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b></span><span>VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b></span><span>PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b></span>${ch&&ch.pdh?`<span>PDH <b>${inr(ch.pdh)}</b></span>`:""}${ch&&ch.pdl?`<span>PDL <b>${inr(ch.pdl)}</b></span>`:""}</div>${candleSVG(ch,FLV)}<div class="legend">5-minute candles today · <i style="background:var(--amber)"></i>VWAP · dashed = yesterday's close · the last candle moves with every tick</div>`; }
  else if(FTAB==="oi"){ B.innerHTML=`<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiTable()}<div class="legend"><i style="background:var(--dn)"></i>calls (a wall above = roof) <i style="background:var(--up)"></i>puts (a wall below = floor) · ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money</div>${oiTrendSVG()}${FOI&&FOI.series&&FOI.series.t.length>1?'<div class="legend">total OI through the day: <i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts — rising calls above the price = sellers building a roof; rising puts below = a floor</div>':""}`; }
  else { const d=FD.desk, ln=(d&&d.lines)||{}; B.innerHTML=`${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${chainSVG(FD)}<div class="cap">green = PUT contracts under the price (the floor is the tallest) · red = CALL contracts above (the roof is the tallest)${FD.pcr?` · PCR ${FD.pcr}`:""}</div>${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${esc(x.h)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; } }
function chainSVG(f){ const S=f.strikes||[]; if(!S.length||!f.spot) return ""; const W=640,H=120,L=50,R=10,T=8,B=20; const n=S.length; const bw=(W-L-R)/n; const mx=Math.max(...S.map(x=>Math.max(x.ce,x.pe)),1);
  const y=v=>T+(H-T-B)*(1-v/mx); const bars=S.map((x,i)=>{ const x0=L+i*bw; const w=Math.max(2,bw*0.42); const isR=f.roof&&f.roof.k===x.k, isF=f.floor&&f.floor.k===x.k;
    return `<rect x="${(x0+bw*0.06).toFixed(1)}" y="${y(x.pe).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.pe)).toFixed(1)}" fill="var(--up)" opacity="${isF?1:0.5}"/><rect x="${(x0+bw*0.52).toFixed(1)}" y="${y(x.ce).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.ce)).toFixed(1)}" fill="var(--dn)" opacity="${isR?1:0.5}"/>${(i%Math.ceil(n/8)===0)?`<text x="${(x0+bw/2).toFixed(1)}" y="${H-6}" fill="var(--dim)" font-size="10" text-anchor="middle" font-family="monospace">${x.k}</text>`:""}`; }).join("");
  const ks=S.map(x=>x.k); const lo=Math.min(...ks), hi=Math.max(...ks); const sx=L+((f.spot-lo)/((hi-lo)||1))*(W-L-R-bw)+bw/2;
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" style="width:100%;height:120px;display:block;background:#000"><line x1="${L}" x2="${W-R}" y1="${H-B}" y2="${H-B}" stroke="var(--line2)"/>${bars}<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="4 3"/></svg>`; }
async function getJ(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pullLive(){ if(!FOC) return; const v=await getJ("live?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.sym===FOC){ FLV=v; paint(); } }
async function pullChart(){ if(!FOC) return; const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.c){ FCH=v; paint(); } }
async function pullOI(){ if(!FOC) return; const v=await getJ("oi?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FOI=v; paint(); } }
function stopLive(){ for(const k in FT){ if(FT[k]) clearInterval(FT[k]); FT[k]=null; } }
async function focusOn(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return; const fresh=sym!==FOC; FOC=sym; $("q").value=sym; $("unf").style.display="inline-block";
  if(fresh){ FCH=null; FLV=null; FOI=null; stopLive(); }
  const v=await getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(sym)); if(v) FD=v;
  const F=$("focus"); F.hidden=false; if(window.innerWidth<900) F.classList.add("sheet");
  if(!FD||(!(FD.strikes||[]).length&&FD.px==null&&!FD.desk)){ F.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">not an F&amp;O share on the desk</div>`; return; }
  if(fresh||!$("fbody")) F.innerHTML=focusHTML(FD); paint();
  if(fresh){ pullChart(); pullLive(); pullOI(); FT.live=setInterval(pullLive,1000); FT.chart=setInterval(pullChart,10000); FT.oi=setInterval(pullOI,30000); }
  if(D){ $("nowl").innerHTML=nowHTML((D.now||[]).filter(r=>r.s===FOC)); $("hnow").textContent=`${FOC} only · tap ✕ ALL for every share`; const nn=(D.news||[]).filter(x=>x.s===FOC); $("newsl").innerHTML=newsHTML(nn); } }
function unfocus(){ FOC=""; FD=null; FCH=null; FLV=null; FOI=null; stopLive(); const F=$("focus"); F.hidden=true; F.classList.remove("sheet"); F.innerHTML=""; $("q").value=""; $("unf").style.display="none"; if(D){ $("nowl").innerHTML=nowHTML(D.now||[]); $("hnow").textContent="moving right now · newest first · every line went to Telegram the same second"; $("newsl").innerHTML=newsHTML(D.news||[]); } }
$("go").onclick=()=>focusOn($("q").value); $("q").addEventListener("keydown",e=>{ if(e.key==="Enter") focusOn($("q").value); }); $("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };
/* ---------- render: the same code for the poll and the push ---------- */
function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now();
  $("idx").innerHTML=idxHTML(D); $("nowl").innerHTML=nowHTML(FOC?(D.now||[]).filter(r=>r.s===FOC):(D.now||[])); SECS=D.sectors||[]; drawSecs();
  if(FOC&&(!render.fat||Date.now()-render.fat>30000)){ render.fat=Date.now(); getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)).then(v=>{ if(v&&FOC===v.s){ FD=v; paint(); } }); }
  const sk=SECS.map(s=>s.name).join("|"); if(sk!==render.sk){ render.sk=sk; $("secsel").innerHTML='<option value="">ALL SECTORS</option>'+SECS.map(s=>`<option value="${esc(s.name)}">${esc(s.name).toUpperCase()}</option>`).join(""); $("secsel").value=SEL; }
  const tk=JSON.stringify((D.tape||[]).map(r=>[r.s,r.px,r.v,r.oi])); if(tk!==render.tk){ render.tk=tk; TAPE=D.tape||[]; drawTape(); }
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); }
  first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
loop(); stream(); loadThree(); setInterval(loadThree,120000);
</script></body></html>
HTML_P83
cat > $D/p83test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p83test.py - the live-window test (read-only on the live files; its own temporary tables).
  1 oi_day(): first and current OI per strike from chain15, the 15-min series, the per-minute live paths from the engine state
  2 /oi answers through the page server (a second copy on a free port) and needs the token
  3 /chart and /live still answer · 4 the page has the live window: candles, the OI table, the tabs, the live timers"""
import os, sys, json, time, socket, sqlite3, tempfile, threading, datetime as dt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve
from http.server import ThreadingHTTPServer

ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


print("1. oi_day on sample tables")
tmp = tempfile.mkdtemp(prefix="p83")
real_base, real_state = dashserve.BASE, dashserve.STATE
dashserve.BASE, dashserve.STATE = tmp, os.path.join(tmp, "dash_state.json")
today = dt.datetime.now(dashserve.IST).strftime("%Y-%m-%d")
c = sqlite3.connect(os.path.join(tmp, "chains.db"))
c.execute("create table chain15(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real, primary key(d, t, sym, exp, strike, kind))")
rows = []
for i, t in enumerate(["09:30", "09:45", "10:00"]):
    for k in (2580, 2600, 2620):
        rows.append((today, t, "GLENMARK", "2026-11-25", k, "CE", 100000 + 10000 * i + k, 50.0 - i, 2600 + 5 * i))
        rows.append((today, t, "GLENMARK", "2026-11-25", k, "PE", 80000 + 5000 * i, 30.0 + i, 2600 + 5 * i))
        rows.append((today, t, "GLENMARK", "2026-12-30", k, "CE", 1, 1, 2600))          # a far expiry: must be ignored
c.executemany("insert or replace into chain15 values(?,?,?,?,?,?,?,?,?)", rows); c.commit(); c.close()
json.dump({"day": today, "oi_live": {"GLENMARK": [{"k": "CE 2600 11-25", "p": [[180, 100000, 50.0], [181, 101000, 50.5]]}, {"k": "2620 PE", "p": [[180, 1, 1]]}]}}, open(dashserve.STATE, "w"))
o = dashserve.oi_day("GLENMARK")
check("nearest expiry only (%s)" % o.get("exp"), o.get("exp") == "2026-11-25")
check("first reading 09:30, last 10:00", o.get("ref_t") == "09:30" and o.get("last_t") == "10:00")
check("2600 CE: first %s -> now %s, ltp %s" % tuple(o["rows"].get("2600", {}).get("ce") or [None] * 3), (o["rows"].get("2600") or {}).get("ce") == [102600.0, 122600.0, 48.0])
check("the 15-min series: 3 points, total CE OI rising", o["series"]["t"] == ["09:30", "09:45", "10:00"] and o["series"]["ce"][2] > o["series"]["ce"][0])
check("live paths from the engine state, both label spellings", "CE 2600" in o["live"] and "PE 2620" in o["live"] and len(o["live"]["CE 2600"]) == 2)
check("an unknown share -> empty, no error", dashserve.oi_day("NOPE")["rows"] == {})
dashserve._OI.clear(); dashserve.BASE, dashserve.STATE = real_base, real_state

print("2. /oi through the page server")
srv = ThreadingHTTPServer(("127.0.0.1", 0), dashserve.H); port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()


def get(path):
    s = socket.create_connection(("127.0.0.1", port), timeout=5)
    s.sendall(("GET %s HTTP/1.0\r\nHost: x\r\n\r\n" % path).encode()); buf = b""
    while True:
        d = s.recv(65536)
        if not d:
            break
        buf += d
    s.close(); r = buf.decode("utf-8", "replace"); return r.split("\r\n")[0], r.split("\r\n\r\n", 1)[-1]


st, body = get("/oi?k=wrong&sym=GLENMARK"); check("/oi without the token -> 403", " 403 " in st)
st, body = get("/oi?k=%s&sym=GLENMARK" % dashserve.TOKEN)
try:
    j = json.loads(body)
except Exception:
    j = None
check("/oi -> 200 JSON with rows / series / live", " 200 " in st and j is not None and all(k in j for k in ("rows", "series", "live")))
print("3. /chart and /live still answer")
st, body = get("/chart?k=%s&sym=GLENMARK" % dashserve.TOKEN); check("/chart -> 200 JSON", " 200 " in st and body.strip().startswith("{"))
st, body = get("/live?k=%s&sym=GLENMARK" % dashserve.TOKEN); check("/live -> 200 JSON", " 200 " in st and body.strip().startswith("{"))
srv.shutdown()

print("4. the page")
h = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("candles, VWAP and the live tick on the chart", "function candleSVG" in h and "vwap" in h and "setInterval(pullLive,1000)" in h)
check("the OI build-up table and trend", "function oiTable" in h and "function oiTrendSVG" in h and "CE ΔOI" in h)
check("the three tabs and the desk's ticket stay", "PRICE · 5 MIN" in h and "OI BUILD-UP" in h and "THE DESK" in h and 'class="tk"' in h)
check("the live timers stop when the window closes", "function stopLive" in h and "stopLive(); const F=$(\"focus\"); F.hidden=true" in h)
print("\nP83 LIVE WINDOW TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits (every anchor must match exactly once, else nothing is written):"
python3 $W/p83_patch.py $D || { rm -f $D/p83test.py; echo "the anchors did not match this server's files - nothing was changed"; exit 1; }
grep -q "function candleSVG" $W/home.html && grep -q "function oiTable" $W/home.html || { echo "the new page is not complete"; back; }
cp $W/home.html $D/home.html
cd $D && python3 -m py_compile dashserve.py p83test.py || back
cd /home/globalbot && set -a && source .env && set +a && cd $D
echo "--- 2. the live-window test (its own temporary tables; a second page server on a free port, read-only):"
timeout 120 python3 p83test.py 2>&1 | grep "OK  \|FAIL\|WINDOW TEST\|Traceback\|Error" | head -24
timeout 120 python3 p83test.py >/dev/null 2>&1 || { echo "the live-window test failed"; back; }
systemctl restart gir-dash && sleep 8
K=$(cat $D/dash_token.txt)
curl -s --max-time 10 "http://127.0.0.1:8090/?k=$K" | grep -q "function candleSVG" || { echo "the new page is not being served"; back; }
curl -s --max-time 20 "http://127.0.0.1:8090/oi?k=$K&sym=GLENMARK" | python3 -c "
import json, sys; d = json.load(sys.stdin); print('    /oi GLENMARK: day %s · expiry %s · %d strikes · %d readings since %s · live paths %d' % (d.get('day'), d.get('exp'), len(d.get('rows') or {}), len((d.get('series') or {}).get('t') or []), d.get('ref_t'), len(d.get('live') or {})))" || { echo "/oi did not answer"; back; }
curl -s --max-time 20 "http://127.0.0.1:8090/chart?k=$K&sym=GLENMARK" | python3 -c "
import json, sys; d = json.load(sys.stdin); print('    /chart GLENMARK: %d candles · prev close %s · vwap %s' % (len(d.get('c') or []), d.get('pc'), d.get('vw')))" || { echo "/chart did not answer"; back; }
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 83 APPLIED - reload the home page and tap any share: the chart and the OI build-up are its own live window."
