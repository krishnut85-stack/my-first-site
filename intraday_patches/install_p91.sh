#!/bin/bash
# PATCH 91 - THE WORKSTATION (on top of patch 89; patch 90 first is better). Tap a share = one full-screen window:
#   · ⌂ HOME on the brand, on the first function key and in the window - one tap back to the home page
#   · laptop / desktop, left to right: ALL F&O SHARES | PRICE (5-min chart) | OI BUILD-UP (centre) | OI CHART (calls · puts at
#     every strike + total OI through the day); the desk's lines under them
#   · the share list: sector tabs (ALL · BANKS · IT · PHARMA ...), sort A-Z / PRICE / CHG % / OI % / DESK - tap again to
#     reverse (low->high, high->low), filters ▲ UP / ▼ DOWN and LB / SB / SC / LU; the choice is remembered
#   · the OI build-up table: tap any column to sort (again = reverse); filters ALL STRIKES / NEAR THE PRICE / CALLS ADDED /
#     PUTS ADDED / CLOSING
#   · phone: tabs CHART · OI BUILD-UP · OI CHART · SHARES · THE DESK; the home page no longer slides sideways
#   dashserve.py (one exact anchor: each share carries its futures OI change %) · home.html. Installs p91test.py.
#   Restarts gir-dash only (the engine, the desk and Telegram are not touched).
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g91; mkdir -p $W
H=$(TZ=Asia/Kolkata date +%H%M); DOW=$(TZ=Asia/Kolkata date +%u)
if [ "$1" != "now" ] && [ "$DOW" -le 5 ] && [ "$H" -ge 0915 ] && [ "$H" -le 1535 ]; then echo "market is open (IST $H) - run after 15:35, or: bash install_p91.sh now"; exit 1; fi
grep -q 'id="fkeys"' $D/home.html || { echo "patch 89 is not installed yet - paste patch 89 first"; exit 1; }
grep -q "function shareListHTML" $D/home.html && { echo "patch 91 is already installed"; exit 1; }
grep -q 'def live_obj' $D/dashserve.py || echo "note: patch 90 (the faster page server) is not installed - paste it too, before or after this one"
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back() { for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/p91test.py; systemctl restart gir-dash; echo "ERROR - old files back, nothing changed"; exit 1; }
cat > $W/p91_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p91_patch.py - PATCH 91 (server side): each share on the /home tape also carries its futures OI change % ("foi"), so the
workstation's share list can sort and filter by OI. One exact anchor, else nothing is written.
Usage: python3 p91_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
OLD = '''"bu": (f.get("bu") or "").replace("_", " "), "cr": f.get("cr")})'''
NEW = '''"bu": (f.get("bu") or "").replace("_", " "), "cr": f.get("cr"), "foi": f.get("oi")})'''
p = os.path.join(D, "dashserve.py")
s = open(p, encoding="utf-8").read()
if s.count(OLD) != 1:
    print("ANCHOR dashserve.py found %d times (need 1): %r" % (s.count(OLD), OLD[:90])); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(OLD, NEW, 1))
print("p91: dashserve.py  1 edit")
PY_PATCH
cat > $W/home.html <<'HTML_P91'
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
#tick .run{white-space:nowrap;will-change:transform;font-size:12px;padding-left:12px}
#tick .run b{color:var(--hi)}#tick .run em{font-style:normal;color:var(--dim);margin:0 10px 0 0}
</style></head><body>
<div id="top">
  <div id="idx"></div>
  <div id="cmd"><span class="pr">&gt;</span><input id="q" placeholder="TICKER  ·  type a share, Enter = FOCUS" autocomplete="off" autocapitalize="characters"><button id="go">GO</button><select id="secsel"><option value="">ALL SECTORS</option></select><a class="x" id="unf" onclick="unfocus()">✕ ALL</a></div>
  <div id="fkeys"><a data-v="all" onclick="goHome()"><b>⌂</b>HOME</a><a data-v="now" onclick="setView('now')"><b>1</b>NOW</a><a data-v="three" onclick="setView('three')"><b>2</b>THE THREE</a><a data-v="scn" onclick="setView('scn')"><b>3</b>OI SCENARIOS</a><a data-v="secs" onclick="setView('secs')"><b>4</b>SECTORS</a><a data-v="tape" onclick="setView('tape')"><b>5</b>F&amp;O TAPE</a><a data-v="news" onclick="setView('news')"><b>6</b>NEWS</a><a data-v="picks" onclick="setView('picks')"><b>7</b>PICKS</a><a data-v="tom" onclick="setView('tom')"><b>8</b>TOMORROW</a><a data-v="myfo" onclick="setView('myfo')"><b>9</b>MY F&amp;O</a><a data-v="desk" onclick="setView('desk')"><b>0</b>DESK P&amp;L</a></div>
</div>
<div id="grid">
  <section class="p" id="now"><h2>NOW <small id="hnow">moving right now · newest first · every line went to Telegram the same second</small></h2><div id="nowl"></div></section>
  <section class="p" id="focus" hidden></section>
  <section class="p" id="three"><h2 id="h3">THE THREE</h2><div id="threel"></div></section>
  <section class="p" id="scn"><h2>OI SCENARIOS <small id="scnh">how the money is building up · today</small></h2><div id="scnl"><div class="empty">the scenario agent reads from 09:20 (open + 5)</div></div></section>
  <section class="p" id="secs"><h2>SECTORS <small>tap a sector to filter the tape · ++ EXTREME · + plain · ✓ confirmed</small></h2><div class="g" id="secg"></div></section>
  <section class="p" id="tape"><h2>F&amp;O TAPE <small id="tfoot"></small></h2><div id="tapel"></div></section>
  <section class="p" id="news"><h2>NEWS <small>filings + headlines · the reader's verdict</small></h2><div id="newsl"></div></section>
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
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${esc(x.h)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${esc(x.h)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
let nx=0; function runNews(){ const R=$("run"); const w=R.scrollWidth; nx+=0.55; if(nx>w) nx=0; R.style.transform=`translateX(${-nx}px)`; requestAnimationFrame(runNews); } requestAnimationFrame(runNews);
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
function tradingView(ch,lv,opt){ opt=opt||{}; const box=(opt.box&&$(opt.box))||$("fbody")||$("focus"); const W=Math.max(320,Math.floor((box&&box.clientWidth)||700)); const phone=W<600; const Hh=phone?320:360;
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
  g+=`<text x="4" y="12" fill="var(--dn)" font-size="10" font-family="monospace">CALLS</text><text x="${LW-4}" y="12" fill="var(--up)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  for(const r of vis){ const yy=y(r.k); const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    const bar=(oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
      let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
      if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
      if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
      return o; };
    g+=bar(r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(r.pe_oi,r.pe_d,1,"var(--up)");
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
function oiRows(){ const o=(FLV&&FLV.ok&&FLV.o&&Object.keys(FLV.o).length)?FLV.o:null; const R=(FOI&&FOI.rows)||{}; const spot=(FLV&&FLV.px)||(FD&&FD.spot)||(FD&&FD.px);
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
function oiTrendSVG(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return ""; const W=720,H=110,L=6,R=58,T=8,B=18; const n=S.t.length; const x=i=>L+(W-L-R)*(i/(n-1));
  const vals=[].concat(S.ce,S.pe); const lo=Math.min(...vals), hi=Math.max(...vals)||1; const y=v=>T+(H-T-B)*(1-(v-lo)/((hi-lo)||1));
  const path=(arr,col)=>`<polyline fill="none" stroke="${col}" stroke-width="1.6" points="${arr.map((v,i)=>`${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ")}"/>`;
  const lab=(arr,col,dy)=>`<text x="${W-R+4}" y="${(y(arr[n-1])+dy).toFixed(1)}" fill="${col}" font-size="10" font-family="monospace">${fmtL(arr[n-1])}</text>`;
  const xs=S.t.map((t,i)=>(i%Math.ceil(n/6)===0||i===n-1)?`<text x="${x(i).toFixed(1)}" y="${H-5}" fill="var(--dim)" font-size="9" font-family="monospace" text-anchor="${i===n-1?"end":"start"}">${t}</text>`:"").join("");
  return `<svg class="oit" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${path(S.ce,"var(--dn)")}${path(S.pe,"var(--up)")}${lab(S.ce,"var(--dn)",3)}${lab(S.pe,"var(--up)",14)}${xs}</svg>`; }
let WS={k:"chg",dir:-1,sec:"",bu:"",pn:""}, OIS={k:"k",dir:-1,f:""}, WSKEY="";
try{ const w=JSON.parse(localStorage.getItem("gir_ws")||"null"); if(w) WS=Object.assign(WS,w); }catch(e){}
function wsSave(){ try{ localStorage.setItem("gir_ws",JSON.stringify(WS)); }catch(e){} }
function wsWide(){ return window.innerWidth>=900; }
const BUS={"LONG BUILD-UP":["LB","pu"],"SHORT BUILD-UP":["SB","pd"],"SHORT COVERING":["SC","pu"],"LONG UNWINDING":["LU","pd"]};
function wsSort(k){ if(WS.k===k) WS.dir=-WS.dir; else { WS.k=k; WS.dir=(k==="s")?1:-1; } wsSave(); WSKEY=""; paint(); }
function wsSec(n){ WS.sec=(WS.sec===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsBu(n){ WS.bu=(WS.bu===n)?"":n; wsSave(); WSKEY=""; paint(); }
function wsPn(n){ WS.pn=(WS.pn===n)?"":n; wsSave(); WSKEY=""; paint(); }
function oiF(f){ OIS.f=(OIS.f===f)?"":f; paint(); }
function oiChips(){ return `<div class="wss oif">${[["","ALL STRIKES"],["near","NEAR THE PRICE"],["ce","CALLS ADDED"],["pe","PUTS ADDED"],["cl","CLOSING"]].map(([k,l])=>`<a class="${OIS.f===k?"on":""}" onclick="oiF('${k}')">${l}</a>`).join("")}</div>`; }
function oiSort(k){ if(OIS.k===k) OIS.dir=-OIS.dir; else { OIS.k=k; OIS.dir=-1; } paint(); }
function oth(k,l,c){ return `<th class="s ${c}${OIS.k===k?" on":""}" onclick="oiSort('${k}')">${l}${OIS.k===k?(OIS.dir>0?" ▲":" ▼"):""}</th>`; }
function goHome(){ unfocus(); setView("all"); window.scrollTo(0,0); }
function shareListHTML(){ const set=WS.sec?new Set((SECS.find(x=>x.name===WS.sec)||{}).syms||[]):null;
  let rows=(TAPE||[]).filter(r=>(!set||set.has(r.s))&&(!WS.bu||(r.bu||"").toUpperCase()===WS.bu)&&(!WS.pn||(WS.pn==="up"?(r.chg||0)>0:(r.chg||0)<0)));
  const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);
  rows=rows.slice().sort((a,b)=>{ const x=val(a), y=val(b); return (x<y?-1:x>y?1:0)*WS.dir; });
  const btn=(k,l)=>`<a class="${WS.k===k?"on":""}" onclick="wsSort('${k}')">${l}${WS.k===k?(WS.dir>0?" ▲":" ▼"):""}</a>`;
  return `<div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${SECS.map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>
    <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("v","DESK")}</div>
    <div class="wss"><a class="${WS.pn==="up"?"on":""}" onclick="wsPn('up')"><span class="${WS.pn==="up"?"":"pu"}">▲ UP</span></a><a class="${WS.pn==="dn"?"on":""}" onclick="wsPn('dn')"><span class="${WS.pn==="dn"?"":"pd"}">▼ DOWN</span></a>${Object.entries(BUS).map(([n,[sh,c]])=>`<a class="${WS.bu===n?"on":""}" onclick="wsBu('${n}')"><span class="${WS.bu===n?"":c}">${sh}</span></a>`).join("")}<span class="dim">${rows.length} shares</span></div>
    <div class="wsl">${rows.map(r=>{ const bb=BUS[(r.bu||"").toUpperCase()]; return `<div class="${r.s===FOC?"cur":""}" onclick="focusOn('${esc(r.s)}')"><b>${esc(r.s)}</b><span class="${cls(r.chg)}">${pc(r.chg)}</span><small>₹${r.px!=null?inr(r.px):"—"}${r.foi!=null?` · OI <span class="${r.foi>0?"pu":r.foi<0?"pd":""}">${r.foi>0?"+":""}${Number(r.foi).toFixed(1)}%</span>`:""}${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")||'<div class="empty">no share matches</div>'}</div>`; }
function oiProfileSVG(boxId){ const rows=oiRows().slice().sort((a,b)=>b.k-a.k); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0;
  if(!rows.length) return '<div class="empty">no strikes read yet</div>';
  const box=$(boxId); const W=Math.max(220,Math.floor((box&&box.clientWidth)||300)); const rh=Math.max(13,Math.min(20,Math.floor(440/rows.length))); const Hh=rows.length*rh+24;
  const {roof,floor}=wallsOf(rows,spot); const mx=Math.max(...rows.map(r=>Math.max(r.ce_oi||0,r.pe_oi||0)),1); const KX=W/2, KWH=24, half=KX-KWH-2; const bh=Math.max(3,rh*0.36);
  const atm=rows.reduce((q,r)=>Math.abs(r.k-spot)<Math.abs(q.k-spot)?r:q,rows[0]);
  let g=`<rect x="0" y="0" width="${W}" height="${Hh}" fill="#05070a"/><text x="4" y="13" fill="var(--dn)" font-size="10" font-family="monospace">CALLS</text><text x="${W-4}" y="13" fill="var(--up)" font-size="10" font-family="monospace" text-anchor="end">PUTS</text>`;
  const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
    let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
    if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
    if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
    return o; };
  rows.forEach((r,i)=>{ const yy=22+i*rh+rh/2; const isW=(roof&&r.k===roof.k)||(floor&&r.k===floor.k);
    if(isW) g+=`<line x1="0" x2="${W}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${roof&&r.k===roof.k?"var(--dn)":"var(--up)"}" stroke-dasharray="5 3" opacity=".6"/>`;
    g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--up)");
    g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="10" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; });
  if(spot){ let i=rows.findIndex(r=>r.k<=spot); if(i<0) i=rows.length; const yy=22+i*rh; g+=`<line x1="0" x2="${W}" y1="${yy}" y2="${yy}" stroke="var(--amber)" stroke-dasharray="2 3"/><text x="${W-4}" y="${yy-3}" fill="var(--amber)" font-size="9" font-family="monospace" text-anchor="end">₹${inr(spot)}</text>`; }
  return `<div class="ocsvg"><svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${g}</svg></div>`; }
function focusHTML(f){ const d=f.desk; const c=d&&d.v>0?"pu":d&&d.v<0?"pd":"dim"; const px=(FLV&&FLV.px)||f.px; const pcv=(FLV&&FLV.pc)||(FCH&&FCH.pc); const chg=(px&&pcv)?(px/pcv-1)*100:f.chg;
  const age=FLV&&FLV.ok?(FLV.age_p!=null?`tick ${FLV.age_p}s ago`:"on ticks"):(f.src||"");
  const head=`<div class="hd"><a class="hm" onclick="goHome()">⌂ HOME</a><b>${esc(f.s)}</b><span class="px ${cls(chg)}">${px!=null?"₹"+inr(px):""} ${pc(chg)}</span><span class="dim">${esc(age)}</span><a class="am" style="margin-left:auto" onclick="unfocus()">✕ CLOSE</a></div>
    <div class="m ${c}">${d?`DESK ${esc(d.label)} ${d.v>0?"+":""}${d.v}${Math.abs(d.v)===2?(d.conf?" ✓ CONFIRMED":" · awaiting the 5-min confirmation"):""}`:"no desk reading yet (the desk reads from 09:20)"}${d&&d.steps&&d.steps.length?` <span class="dim">· ${esc(d.steps.join(" · "))}</span>`:""}${d&&d.notes&&d.notes.length?` <span class="pd">· ${esc(d.notes.join(" · "))}</span>`:""}</div>
    ${d&&d.ticket?`<div class="tk">▶ ${esc(d.ticket)}${d.stop?` · stop: a close ${d.v>0?"under":"over"} ${d.stop}`:""}${d.line_k?` · line ${d.line_k}`:""}${d.size?`\n${esc(d.size)}`:""}</div>`:""}
    ${scnRibbon(f.s)}`;
  if(wsWide()) return head+`<div class="ws"><div id="wsList"></div><div id="wsPx"><div class="wsh">PRICE · 5 MIN <span id="wsOhlc"></span></div><div class="tv" id="tvbox"></div><div class="pat" id="patl"></div></div><div id="wsOi"><div class="wsh">OI BUILD-UP <span>tap a column to sort · again to reverse</span></div><div id="wsOiB"></div></div><div id="wsOc"><div class="wsh">OI CHART <span>calls · puts at every strike</span></div><div id="wsOcB"></div></div></div><div id="wsDesk"></div>`;
  return head+`<div class="tabs">${[["chart","CHART"],["oi","OI BUILD-UP"],["oc","OI CHART"],["list","SHARES"],["desk","THE DESK"]].map(([k,l])=>`<span class="${FTAB===k?"on":""}" onclick="FTAB='${k}';paint()">${l}</span>`).join("")}</div><div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; const wide=wsWide();
  if(paint.wide!==wide||!F.querySelector(wide?".ws":"#fbody")){ paint.wide=wide; F.innerHTML=focusHTML(FD); WSKEY=""; }
  else { const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); const nh=tmp.querySelector(".hd"); if(nh) hd.replaceWith(nh); }
    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","oi","oc","list","desk"][i]===FTAB)); }
  const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
  const ohlc=`O <b>${n?inr(ch.o[0]):"—"}</b> H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b> L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b> LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b> VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b> PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b>`;
  const pat=tv=>tv.txt.length?"<b>PATTERNS</b> · "+tv.txt.join(" · "):"";
  const oiH=()=>`${scnFocus()}<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiChips()}${oiTable()}<div class="legend">ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money</div>`;
  const ocH=id=>oiProfileSVG(id)+'<div class="legend"><i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts · bright = added today · dashed = closed today · the amber line = the price</div>'+oiTrendSVG()+(FOI&&FOI.series&&FOI.series.t.length>1?'<div class="legend">total OI through the day: <i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts</div>':"");
  const deskH=()=>{ const d=FD.desk, ln=(d&&d.lines)||{}; return `${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${esc(x.h)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; };
  if(wide){ const lk=JSON.stringify([WS,FOC,D&&D.t,(TAPE||[]).length]); if(lk!==WSKEY){ WSKEY=lk; const L=$("wsList"); const st=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st; }
    $("wsOhlc").innerHTML=ohlc; const tv=tradingView(ch,FLV,{profile:false,box:"wsPx"}); $("tvbox").innerHTML=tv.svg; $("patl").innerHTML=pat(tv);
    $("wsOiB").innerHTML=oiH(); $("wsOcB").innerHTML=ocH("wsOc"); $("wsDesk").innerHTML=deskH(); return; }
  const B=$("fbody"); if(!B) return;
  if(FTAB==="chart"){ B.innerHTML=`<div class="sub"><span>${ohlc}</span><span>PRICE · 5 MIN</span></div><div class="tv" id="tvbox"></div><div class="pat" id="patl"></div><div class="legend">5-min candles · <i style="background:var(--amber)"></i>VWAP · the opening-range box · the roof / floor from the OI · ▲▼ the patterns · 🧩 an OI scenario fired</div>`;
    const tv=tradingView(ch,FLV,{profile:false}); $("tvbox").innerHTML=tv.svg; $("patl").innerHTML=pat(tv); }
  else if(FTAB==="oi") B.innerHTML=oiH();
  else if(FTAB==="oc"){ B.innerHTML='<div id="ocbox"></div>'; $("ocbox").innerHTML=ocH("ocbox"); }
  else if(FTAB==="list"){ const st=B.scrollTop; B.innerHTML=shareListHTML(); }
  else B.innerHTML=deskH(); }
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
  const F=$("focus"); F.hidden=false; if(window.innerWidth<900) F.classList.add("sheet"); else { F.classList.add("ws-on"); document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
  if(!FD||(!(FD.strikes||[]).length&&FD.px==null&&!FD.desk)){ F.innerHTML=`<div class="hd"><b>${esc(sym)}</b><a class="am" style="margin-left:auto" onclick="unfocus()">✕</a></div><div class="empty">not an F&amp;O share on the desk</div>`; return; }
  if(fresh||!$("fbody")) F.innerHTML=focusHTML(FD); paint();
  if(fresh){ pullChart(); pullLive(); pullOI(); FT.live=setInterval(pullLive,1000); FT.chart=setInterval(pullChart,10000); FT.oi=setInterval(pullOI,30000); }
  if(D){ $("nowl").innerHTML=nowHTML((D.now||[]).filter(r=>r.s===FOC)); $("hnow").textContent=`${FOC} only · tap ✕ ALL for every share`; const nn=(D.news||[]).filter(x=>x.s===FOC); $("newsl").innerHTML=newsHTML(nn); } }
function unfocus(){ FOC=""; FD=null; FCH=null; FLV=null; FOI=null; stopLive(); const F=$("focus"); F.hidden=true; F.classList.remove("sheet","ws-on"); F.innerHTML=""; $("q").value=""; $("unf").style.display="none"; if(D){ $("nowl").innerHTML=nowHTML(D.now||[]); $("hnow").textContent="moving right now · newest first · every line went to Telegram the same second"; $("newsl").innerHTML=newsHTML(D.news||[]); } }
$("go").onclick=()=>focusOn($("q").value); $("q").addEventListener("keydown",e=>{ if(e.key==="Enter") focusOn($("q").value); }); $("secsel").onchange=()=>{ SEL=$("secsel").value; drawSecs(); drawTape(); };
/* ---------- render: the same code for the poll and the push ---------- */
function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now();
  $("idx").innerHTML=idxHTML(D); $("nowl").innerHTML=nowHTML(FOC?(D.now||[]).filter(r=>r.s===FOC):(D.now||[])); SECS=D.sectors||[]; drawSecs();
  { const S_=D.scn||{}; const ck=JSON.stringify([(S_.today||[]).length,S_.scores,(S_.cat||[]).length]); if(ck!==render.ck){ render.ck=ck; $("scnl").innerHTML=scnHTML(D.scn); $("scnh").textContent=`how the money is building up · ${(S_.today||[]).length} today`; } }
  if(FOC&&(!render.fat||Date.now()-render.fat>30000)){ render.fat=Date.now(); getJ("focus?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)).then(v=>{ if(v&&FOC===v.s){ FD=v; paint(); } }); }
  const sk=SECS.map(s=>s.name).join("|"); if(sk!==render.sk){ render.sk=sk; $("secsel").innerHTML='<option value="">ALL SECTORS</option>'+SECS.map(s=>`<option value="${esc(s.name)}">${esc(s.name).toUpperCase()}</option>`).join(""); $("secsel").value=SEL; }
  const tk=JSON.stringify((D.tape||[]).map(r=>[r.s,r.px,r.v,r.oi])); if(tk!==render.tk){ render.tk=tk; TAPE=D.tape||[]; drawTape(); }
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); }
  first=false; }
async function loop(){ try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok){ render(await r.json()); } }catch(e){} setTimeout(loop, esOK?15000:5000); }
let ES=null, esOK=false;
function stream(){ if(!window.EventSource) return; try{ ES=new EventSource("events?k="+encodeURIComponent(K)); ES.onopen=()=>{ esOK=true; }; ES.onerror=()=>{ esOK=false; };
  for(const ev of ["now","idx","secs"]) ES.addEventListener(ev,e=>{ try{ render(JSON.parse(e.data)); }catch(x){} }); }catch(e){ esOK=false; } }
/* ---------- patch 89: the function keys and the panels ---------- */
let VIEW="all"; try{ VIEW=localStorage.getItem("gir_fk")||"all"; }catch(e){}
let PN=null, PNT=null;
const rsx=v=>v==null?"—":(v<0?"−₹":"₹")+Math.abs(Math.round(v)).toLocaleString("en-IN");
function setView(v){ VIEW=v; try{ localStorage.setItem("gir_fk",v); }catch(e){}
  document.body.classList.toggle("one",v!=="all");
  document.querySelectorAll("#fkeys a").forEach(a=>a.classList.toggle("on",a.dataset.v===v));
  document.querySelectorAll("#grid>section").forEach(x=>x.classList.toggle("on",x.id===v));
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
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return; const k=e.key; const m={"`":"all","1":"now","2":"three","3":"scn","4":"secs","5":"tape","6":"news","7":"picks","8":"tom","9":"myfo","0":"desk"}; if(m[k]) setView(m[k]); });
loop(); stream(); loadThree(); setInterval(loadThree,120000); setView(VIEW);
</script></body></html>
HTML_P91
cat > $D/p91test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p91test.py - the workstation test: /home answers with each share's OI change % for the list (a second page server on a
free port, read-only), and the page has HOME, the four panes (shares | price | OI build-up | OI chart) and the sorts."""
import os, sys, json, time, socket, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dashserve
from http.server import ThreadingHTTPServer
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


srv = ThreadingHTTPServer(("127.0.0.1", 0), dashserve.H); port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()


def get(path):
    t0 = time.time(); s = socket.create_connection(("127.0.0.1", port), timeout=60)
    s.sendall(("GET %s HTTP/1.0\r\nHost: x\r\n\r\n" % path).encode()); buf = b""
    while True:
        d = s.recv(65536)
        if not d:
            break
        buf += d
    s.close(); r = buf.decode("utf-8", "replace"); return r.split("\r\n")[0], r.split("\r\n\r\n", 1)[-1], time.time() - t0


st, body, dt1 = get("/home?k=" + dashserve.TOKEN)
try:
    j = json.loads(body)
except Exception:
    j = None
tape = (j or {}).get("tape") or []
check("/home -> 200 with the share list (%d shares, %d ms)" % (len(tape), dt1 * 1000), " 200 " in st and j is not None)
check("every share carries its OI change %% (foi) - %d with a value" % sum(1 for r in tape if r.get("foi") is not None),
      all("foi" in r for r in tape))
srv.shutdown()
h = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "home.html"), encoding="utf-8").read()
check("a HOME button (the brand, the first key, the window)", 'onclick="goHome()"' in h and "⌂ HOME" in h and "function goHome" in h)
check("the four panes: shares | price | OI build-up | OI chart", all(x in h for x in ('id="wsList"', 'id="wsPx"', 'id="wsOi"', 'id="wsOc"')))
check("the share list: sector tabs, A-Z / PRICE / CHG % / OI % / DESK, build-up chips", "function shareListHTML" in h and "wsSec(" in h and "wsSort(" in h and "wsBu(" in h)
check("the OI build-up table sorts by any column", "function oiSort" in h and "OIS" in h)
check("the OI chart (calls / puts at every strike)", "function oiProfileSVG" in h)
check("phone: tabs CHART / OI BUILD-UP / OI CHART / SHARES / THE DESK", '["list","SHARES"]' in h)
print("\nP91 WORKSTATION TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
echo "--- 1. the edits:"
python3 $W/p91_patch.py $D || { rm -f $D/p91test.py; echo "the anchor did not match this server's files - nothing was changed"; exit 1; }
grep -q "function shareListHTML" $W/home.html && grep -q 'id="fkeys"' $W/home.html && grep -q "</html>" $W/home.html || { echo "the new page is not complete"; back; }
cp $W/home.html $D/home.html
cd $D && python3 -m py_compile dashserve.py p91test.py || back
echo "--- 2. the tests:"
timeout 300 python3 p91test.py 2>&1 | grep "OK  \|FAIL\|WORKSTATION TEST"
timeout 300 python3 p91test.py >/dev/null 2>&1 || { echo "the workstation test failed"; back; }
for t in p81test.py p83test.py p84test.py p89test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 12
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function shareListHTML" || { echo "the new page is not being served"; back; }
curl -s --max-time 30 "http://127.0.0.1:8090/home?k=$K" | grep -q '"foi"' || { echo "the share list has no OI % yet"; back; }
echo "--- 3. how fast the page answers (seconds · size):"
for p in "/" "/home" "/panels"; do
  printf "    %-10s " "$p"; curl -s -o /dev/null --compressed -w "%{time_total} s · %{size_download} bytes\n" --max-time 30 "http://127.0.0.1:8090${p}?k=$K"
done
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 91 APPLIED - reload the page and tap any share: shares | price | OI build-up | OI chart. ⌂ HOME goes back."
