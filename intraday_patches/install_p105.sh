#!/bin/bash
# PATCH 105 - HOW AN ALERT SHOWS ON THE PAGE (on top of patch 104).
#   · every new TRADE ALERT (red, 3 beeps, 60 s) or SOMETHING IS HAPPENING (amber, 1 beep, 25 s) pops up as a CARD, top right,
#     on every screen (MARKET, a share's window, the phone): the share, UP -> CE / DOWN -> PE, the headline and the ticket.
#     Tap = open it (the share's window; MARKET for NIFTY / market news). ✕ closes it. At most 4 (2 small ones on a phone).
#   · the ALERTS bar shows the NEWEST first (an older ACT no longer hides the newest alert)
#   · NIFTY SHOCK / MARKET NEWS chips show the move and the headline
#   home.html only. Installs p105test.py. Restarts gir-dash only.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g105; mkdir -p $W
grep -q "function proRender" $D/home.html || { echo "patch 104 is not installed yet - paste patch 104 first"; exit 1; }
grep -q "function toast(r,tr)" $D/home.html && { echo "patch 105 is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; rm -f $D/p105test.py; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/home.html <<'HTML_P105'
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
body.solo #cmd,body.solo #fkeys{display:none}
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
#mk table{border-collapse:collapse;width:100%}#mk td{padding:1px 4px;white-space:nowrap}#mk tr:nth-child(odd) td{background:#0a0d12}
#mk .r{text-align:right}#mk .c{text-align:center}#mk .k{cursor:pointer}#mk .k:hover td{background:#14202e}
#mk .hm td{text-align:center;font-size:10px;padding:2px 3px}#mk .hm td:first-child{text-align:left}
#mk .mn{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:2px 8px;padding:3px 6px}#mk .mn h4{font-size:10px;letter-spacing:.06em;margin-top:2px}
#mk .dk div{padding:3px 8px;border-bottom:1px solid var(--line)}#mk .dk b{color:var(--hi)}#mk .dk em{font-style:normal;color:var(--dim);display:inline-block;width:78px}
@media(min-width:1100px){
  #mk{height:calc(100vh - var(--toph,150px) - 34px);grid-template-columns:1.25fr 1.25fr 1.05fr 1.15fr 1fr;grid-template-rows:1fr 1fr;
      grid-template-areas:"mov nif don mon dsk" "mov hea bus mon nws"}
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
  <div id="fkeys"><a data-v="all" onclick="goHome()"><b>⌂</b>HOME</a><a data-v="market" onclick="setView('market')"><b>M</b>MARKET</a><a data-v="now" onclick="setView('now')"><b>1</b>NOW</a><a data-v="three" onclick="setView('three')"><b>2</b>THE THREE</a><a data-v="scn" onclick="setView('scn')"><b>3</b>OI SCENARIOS</a><a data-v="secs" onclick="setView('secs')"><b>4</b>SECTORS</a><a data-v="tape" onclick="setView('tape')"><b>5</b>F&amp;O TAPE</a><a data-v="news" onclick="setView('news')"><b>6</b>NEWS</a><a data-v="picks" onclick="setView('picks')"><b>7</b>PICKS</a><a data-v="tom" onclick="setView('tom')"><b>8</b>TOMORROW</a><a data-v="myfo" onclick="setView('myfo')"><b>9</b>MY F&amp;O</a><a data-v="desk" onclick="setView('desk')"><b>0</b>DESK P&amp;L</a></div>
  <div id="abar"></div><div id="toasts"></div>
</div>
<div id="grid">
  <section class="p" id="market"><h2>MARKET</h2><div id="mk">
    <div class="q" id="q-mov"><h3>F&amp;O MOVERS<span id="lvq"></span> <span id="mk-movh">% today · tap = its trading screen</span></h3><div class="bd" id="mk-mov"></div></div>
    <div class="q" id="q-nif"><h3>NIFTY · F&amp;O BREADTH <span>through the day</span></h3><div class="bd" id="mk-nif"></div></div>
    <div class="q" id="q-don"><h3>SECTORS <span>% today · size = F&amp;O shares · tap = its shares</span></h3><div class="bd" id="mk-don"></div></div>
    <div class="q" id="q-mon"><h3>F&amp;O MONEY <span>fresh futures money today · ₹ cr</span></h3><div class="bd" id="mk-mon"></div></div>
    <div class="q" id="q-dsk"><h3>F&amp;O DESK <span>expiry · PCR · VIX · FII/DII · ban · results</span></h3><div class="bd dk" id="mk-dsk"></div></div>
    <div class="q" id="q-hea"><h3>SECTORS THROUGH THE DAY <span>% · every 30 min</span></h3><div class="bd" id="mk-hea"></div></div>
    <div class="q" id="q-bus"><h3>OI BUILD-UP BY SECTOR <span>futures · number of shares</span></h3><div class="bd" id="mk-bus"></div></div>
    <div class="q" id="q-nws"><h3>OI SCENARIOS · NEWS <span>newest first</span></h3><div class="bd" id="mk-nws"></div></div>
  </div></section>
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
  return N.slice(0,12).map(x=>`<div class="r" onclick="focusOn('${esc(x.s)}')"><div class="t">${esc(x.hm||"")}</div><div><b>${x.s==="MARKET"?"🏛 MARKET":esc(x.s)}</b>${x.side?`<span class="sd ${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""} <span class="dim">${esc(x.kind||"")}</span></div><div class="h">${esc(x.h)}</div>${x.why?`<div class="w">${esc(x.why)}</div>`:""}</div>`).join(""); }
function runHTML(N){ return N.slice(0,30).map(x=>`<em>${esc((x.hm||"").slice(-5))}</em><b>${x.s==="MARKET"?"🏛 MARKET":esc(x.s)}</b> ${x.side?`<span class="${x.side>0?"pu":"pd"}">${x.side>0?"▲":"▼"}</span> `:""}${esc(x.h)}${x.why?` <span class="dim">— ${esc(x.why)}</span>`:""}<em>&nbsp;&nbsp;·&nbsp;&nbsp;</em>`).join(""); }
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
let OIT="chg"; try{ OIT=localStorage.getItem("gir_oit")||"chg"; }catch(e){}
function oitMode(m){ OIT=m; try{ localStorage.setItem("gir_oit",m); }catch(e){} paint(); }
function oiTrendData(){ const S=FOI&&FOI.series; if(!S||!(S.t||[]).length||S.t.length<2) return null; const n=S.t.length;
  const ce=S.ce.slice(), pe=S.pe.slice(); const sp=(S.spot||[]).map(v=>v==null?null:+v);
  return {n, t:S.t, ce, pe, sp, ced:ce.map(v=>v-ce[0]), ped:pe.map(v=>v-pe[0]), pcr:ce.map((v,i)=>v?pe[i]/v:null)}; }
function oitRead(D,i){ const sg=v=>(v>0?"+":"")+fmtL(v).replace(/^\+/,""); const pcr=D.pcr[i];
  return `<b class="am">${esc(D.t[i])}</b> · <span style="color:var(--dn)">CALLS <b>${fmtL(D.ce[i])}</b> (${sg(D.ced[i])})</span> · <span style="color:var(--up)">PUTS <b>${fmtL(D.pe[i])}</b> (${sg(D.ped[i])})</span> · PCR <b>${pcr!=null?pcr.toFixed(2):"—"}</b>${D.sp[i]!=null?` · price <b class="am">₹${inr(D.sp[i])}</b>`:""}`; }
function oiTrendSVG(boxId,hh){ const D=oiTrendData(); if(!D) return "";
  const box=boxId&&$(boxId); const W=Math.max(260,Math.floor((box&&box.clientWidth)||560)); const H=hh||Math.max(190,Math.min(260,Math.round(W*0.42)));
  const L=50,R=56,T=10,B=20, n=D.n; const pw=W-L-R, ph=H-T-B; const x=i=>L+pw*(i/(n-1));
  const ser=OIT==="tot"?[[D.ce,"var(--dn)"],[D.pe,"var(--up)"]]:OIT==="pcr"?[[D.pcr,"#4fc3f7"]]:[[D.ced,"var(--dn)"],[D.ped,"var(--up)"]];
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
  return `<div class="oitw" id="${id}"><div class="oith"><b>OI LINE</b>${[["chg","OI CHANGE"],["tot","TOTAL OI"],["pcr","PCR"]].map(([k,l])=>`<a class="${OIT===k?"on":""}" onclick="oitMode('${k}')">${l}</a>`).join("")}<span class="dim" style="margin-left:auto">${OIT==="pcr"?`<i style="display:inline-block;width:10px;height:2px;background:#4fc3f7;vertical-align:middle"></i> PCR = puts ÷ calls (dashed 1.0 = even)`:`<i style="display:inline-block;width:10px;height:2px;background:var(--dn);vertical-align:middle"></i> calls <i style="display:inline-block;width:10px;height:2px;background:var(--up);vertical-align:middle"></i> puts${OIT==="chg"?" (added since the first reading)":""}`} <i style="display:inline-block;width:10px;border-top:2px dashed var(--amber);vertical-align:middle"></i> price</span><div class="oitr">${oitRead(D,D.n-1)}</div></div><div class="oitg"></div></div>`; }
function oitPaint(host,id){ const h=$(host); if(!h) return; const D=oiTrendData(); let hh=0;
  if(host==="oitPx"&&wsWide()&&$("wsPx")&&$("tvbox")) hh=Math.max(150,Math.min(320,$("wsPx").clientHeight-$("tvbox").offsetHeight-92));
  const k=[OIT,D&&D.n,D&&D.ce[D.n-1],D&&D.pe[D.n-1],D&&D.sp[D.n-1],h.clientWidth,hh,id].join("|");
  if(h.dataset.k===k&&h.firstChild) return; h.dataset.k=k; h.innerHTML=oiTrendBox(id); oiTrendPut(id,hh); }
function oiTrendPut(id,hh){ const w=$(id); if(!w) return; const g=w.querySelector(".oitg"); if(g) g.innerHTML=oiTrendSVG(id,hh||0); }
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
/* patch 102: on a laptop / desktop the MARKET screen is home; a share opens in its OWN window (see 3-4 side by side) */
const SOLO=((new URLSearchParams(location.search)).get("w")||"").toUpperCase().replace(/[^A-Z0-9&-]/g,"").slice(0,20);
const WINS={};
function openWin(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return;
  const n=Object.keys(WINS).filter(k=>WINS[k]&&!WINS[k].closed).length; const W=Math.floor((screen.availWidth||1536)/2), H=(screen.availHeight||860);
  const u=location.pathname+"?k="+encodeURIComponent(K)+"&w="+encodeURIComponent(sym);
  const w=window.open(u,"gir_"+sym,`popup=yes,width=${W},height=${H},left=${(n%2)*W},top=0`);
  if(w){ WINS[sym]=w; try{ w.focus(); }catch(e){} } else { HOMED=true; setView("all"); focusOn.inner=true; focusOn(sym); focusOn.inner=false; } }   // a blocked pop-up: open it here
function goHome(){ HOMED=false; if(SOLO){ focusOn(SOLO); return; } if(wsWide()){ unfocus(); setView("market"); window.scrollTo(0,0); } else { setView("all"); unfocus(); window.scrollTo(0,0); } }
/* patch 95: HOME = the trading screen - the share you had open last, else the day's biggest mover */
let HOMED=false; let LASTS=""; try{ LASTS=localStorage.getItem("gir_last")||""; }catch(e){}
function homeOpen(){ if(!wsWide()||!SOLO) return; if(FOC){ HOMED=true; return; } const T=TAPE||[];
  let s=(LASTS&&(T.some(r=>r.s===LASTS)||!T.length))?LASTS:""; if(!s&&T.length){ s=T.slice().sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0))[0].s; }
  if(s){ HOMED=true; focusOn(s); } }
function shareListHTML(){ const sx=WS.sec?SECS.find(x=>x.name===WS.sec):null; if(WS.sec&&!sx&&SECS.length) WS.sec=""; const set=sx?new Set(sx.syms||[]):null;
  let rows=(TAPE||[]).filter(r=>(!set||set.has(r.s))&&(!WS.bu||(r.bu||"").toUpperCase()===WS.bu)&&(!WS.pn||(WS.pn==="up"?(r.chg||0)>0:(r.chg||0)<0)));
  const val={s:r=>r.s, px:r=>r.px??-1e18, chg:r=>r.chg??-1e18, foi:r=>r.foi??-1e18, v:r=>r.v||0}[WS.k]||(r=>r.chg??0);
  rows=rows.slice().sort((a,b)=>{ const x=val(a), y=val(b); return (x<y?-1:x>y?1:0)*WS.dir; });
  const btn=(k,l)=>`<a class="${WS.k===k?"on":""}" onclick="wsSort('${k}')">${l}${WS.k===k?(WS.dir>0?" ▲":" ▼"):""}</a>`;
  return `<div class="wst"><a class="${!WS.sec?"on":""}" onclick="wsSec('')">ALL</a>${SECS.map(x=>`<a class="${WS.sec===x.name?"on":""}" onclick="wsSec('${esc(x.name)}')">${esc(x.name.toUpperCase())}</a>`).join("")}</div>
    <div class="wss">${btn("s","A–Z")}${btn("px","PRICE")}${btn("chg","CHG %")}${btn("foi","OI %")}${btn("v","DESK")}</div>
    <div class="wss"><a class="${WS.pn==="up"?"on":""}" onclick="wsPn('up')"><span class="${WS.pn==="up"?"":"pu"}">▲ UP</span></a><a class="${WS.pn==="dn"?"on":""}" onclick="wsPn('dn')"><span class="${WS.pn==="dn"?"":"pd"}">▼ DOWN</span></a>${Object.entries(BUS).map(([n,[sh,c]])=>`<a class="${WS.bu===n?"on":""}" onclick="wsBu('${n}')"><span class="${WS.bu===n?"":c}">${sh}</span></a>`).join("")}<span class="dim">${rows.length} shares</span></div>
    <div class="wsl">${rows.map(r=>{ const bb=BUS[(r.bu||"").toUpperCase()]; return `<div class="${r.s===FOC?"cur":""}" onclick="focusOn('${esc(r.s)}')"><b>${esc(r.s)}</b><span class="${cls(r.chg)}${qfl(r.s)}">${pc(r.chg)}</span><small>₹${r.px!=null?inr(r.px):"—"}${r.foi!=null?` · OI <span class="${r.foi>0?"pu":r.foi<0?"pd":""}">${r.foi>0?"+":""}${Number(r.foi).toFixed(1)}%</span>`:""}${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")||'<div class="empty">no share matches</div>'}</div>`; }
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
  if(wsWide()) return head+`<div class="ws"><div id="wsList"></div><div id="wsPx"><div class="wsh">PRICE <span id="wsOhlc"></span></div><div class="tv" id="tvbox"></div><div id="oitPx"></div><div class="pat" id="patl"></div></div><div id="wsOi"><div class="wsh">OI BUILD-UP <span>tap a column to sort · again to reverse</span></div><div id="wsOiB"></div></div><div id="wsOc"><div class="wsh">F&amp;O CHECKLIST <span>buy CE · buy PE · 7 checks</span></div><div id="wsChk"></div><div class="wsh" style="position:static">OI CHART <span>calls · puts at every strike</span></div><div id="wsOcB"></div></div></div><div id="wsDesk"></div>`;
  return head+`<div class="tabs">${[["chart","CHART"],["chk","CHECKLIST"],["oi","OI BUILD-UP"],["oc","OI CHART"],["list","SHARES"],["desk","THE DESK"]].map(([k,l])=>`<span class="${FTAB===k?"on":""}" onclick="FTAB='${k}';paint()">${l}</span>`).join("")}</div><div id="fbody"></div>`; }
function paint(){ const F=$("focus"); if(!FD||F.hidden) return; const wide=wsWide();
  if(paint.wide!==wide||!F.querySelector(wide?".ws":"#fbody")){ paint.wide=wide; F.innerHTML=focusHTML(FD); WSKEY=""; }
  else { const hd=F.querySelector(".hd"); if(hd){ const tmp=document.createElement("div"); tmp.innerHTML=focusHTML(FD); const nh=tmp.querySelector(".hd"); if(nh) hd.replaceWith(nh); }
    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","chk","oi","oc","list","desk"][i]===FTAB)); }
  const ch=FCH; const n=ch&&ch.c?ch.c.length:0; const last=n?ch.c[n-1]:null;
  const ohlc=`O <b>${n?inr(ch.o[0]):"—"}</b> H <b>${n?inr(Math.max(...ch.h.filter(x=>x!=null))):"—"}</b> L <b>${n?inr(Math.min(...ch.l.filter(x=>x!=null))):"—"}</b> LAST <b>${FLV&&FLV.px!=null?inr(FLV.px):(last!=null?inr(last):"—")}</b> VWAP <b class="am">${ch&&ch.vw!=null?inr(ch.vw):"—"}</b> PREV <b>${ch&&ch.pc!=null?inr(ch.pc):"—"}</b>`;
  const pat=tv=>tv.txt.length?"<b>PATTERNS</b> · "+tv.txt.join(" · "):"";
  const oiH=()=>`<div class="sub"><span>expiry <b>${esc((FLV&&FLV.exp)||(FOI&&FOI.exp)||(FD&&FD.exp)||"—")}</b></span><span>since <b>${esc((FOI&&FOI.ref_t)||"the first reading")}</b></span>${FD&&FD.roof?`<span>roof <b class="pd">${FD.roof.k}</b></span>`:""}${FD&&FD.floor?`<span>floor <b class="pu">${FD.floor.k}</b></span>`:""}<span>${FLV&&FLV.ok?`live · OI tick ${FLV.age_o!=null?FLV.age_o+"s":"—"} ago`:"last reading"}</span></div>${oiView(wsWide()?"wsOiB":"fbody")}<div class="legend">${OIMODE==="chart"?"bars = OI at each strike: red calls (resistance), green puts (support) · bright top = added today · dashed = closed today · amber line = the price":"ΔOI = contracts added or closed since the day's first reading · ▪ the roof / the floor · amber = at the money"}</div>${scnFocus()}`;
  const ocH=id=>oiProfileSVG(id)+'<div class="legend"><i style="background:var(--dn)"></i>calls <i style="background:var(--up)"></i>puts · bright = added today · dashed = closed today · the amber line = the price</div>';
  const deskH=()=>{ const d=FD.desk, ln=(d&&d.lines)||{}; return `${shareInfo()}${["strikes","walls","futures","reader"].map(k=>ln[k]?`<div class="ag"><b>${k}</b>${esc(ln[k])}</div>`:"").join("")}${!d&&FD.bu?`<div class="ag"><b>futures</b>${esc(FD.bu.toLowerCase())}${FD.cr?` ₹${Math.round(FD.cr)} cr`:""}</div>`:""}${(FD.news||[]).length?`<div class="nw">${FD.news.slice(0,6).map(x=>`<em>${esc(x.hm)}</em> ${esc(x.h)}${x.side?` — <span class="${x.side>0?"pu":"pd"}">${x.side>0?"UP":"DOWN"}</span>`:""}${x.why?` · ${esc(x.why)}`:""}`).join("<br>")}</div>`:`<div class="nw dim">no news on this share in the last 26 hours</div>`}`; };
  if(wide){ const lk=JSON.stringify([WS,FOC,D&&D.t,(TAPE||[]).length]); if(lk!==WSKEY){ WSKEY=lk; const L=$("wsList"); const st=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st; }
    $("wsOhlc").innerHTML=pxChips()+ohlc; const pxH=$("wsPx").clientHeight;
    if(PXM==="pro"){ if(proEnsure("tvbox",Math.max(300,pxH-34))) proRender(); $("patl").innerHTML=""; $("oitPx").innerHTML=""; $("oitPx").dataset.k=""; }
    else if(tickOn()){ $("tvbox").innerHTML=tickBox("wsPx",Math.max(280,Math.min(720,pxH-26-128))); $("patl").innerHTML=""; $("oitPx").innerHTML=""; $("oitPx").dataset.k=""; }
    else { const tv=tradingView(ch,FLV,{box:"wsPx",h:Math.max(220,Math.min(360,pxH-26-62-170))}); $("tvbox").innerHTML=(PXM==="tick"?'<div class="legend">TICK: recording from now (market hours) - the 5-min chart until the first ticks arrive</div>':"")+tv.svg; $("patl").innerHTML=pat(tv); oitPaint("oitPx","oitA"); }
    $("wsOiB").innerHTML=oiH(); $("wsChk").innerHTML=chkHTML(FCK); $("wsOcB").innerHTML=ocH("wsOc"); $("wsDesk").innerHTML=deskH(); return; }
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
    return `<rect x="${(x0+bw*0.06).toFixed(1)}" y="${y(x.pe).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.pe)).toFixed(1)}" fill="var(--up)" opacity="${isF?1:0.5}"/><rect x="${(x0+bw*0.52).toFixed(1)}" y="${y(x.ce).toFixed(1)}" width="${w.toFixed(1)}" height="${(H-B-y(x.ce)).toFixed(1)}" fill="var(--dn)" opacity="${isR?1:0.5}"/>${(i%Math.ceil(n/8)===0)?`<text x="${(x0+bw/2).toFixed(1)}" y="${H-6}" fill="var(--dim)" font-size="10" text-anchor="middle" font-family="monospace">${x.k}</text>`:""}`; }).join("");
  const ks=S.map(x=>x.k); const lo=Math.min(...ks), hi=Math.max(...ks); const sx=L+((f.spot-lo)/((hi-lo)||1))*(W-L-R-bw)+bw/2;
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" style="width:100%;height:120px;display:block;background:#000"><line x1="${L}" x2="${W-R}" y1="${H-B}" y2="${H-B}" stroke="var(--line2)"/>${bars}<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="4 3"/></svg>`; }
async function getJ(u){ try{ const r=await fetch(u,{cache:"no-store"}); return r.ok?await r.json():null; }catch(e){ return null; } }
async function pullLive(){ if(!FOC) return; const since=(TK.sym===FOC&&TK.pts.length)?TK.pts[TK.pts.length-1][0]:0;
  const v=await getJ("live?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)+"&since="+since); if(v&&v.sym===FOC){ FLV=v; tkFeed(v); paint(); } }
async function pullChart(){ if(!FOC) return; const v=await getJ("chart?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.c){ FCH=v; paint(); } }
async function pullOI(){ if(!FOC) return; const v=await getJ("oi?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FOI=v; paint(); } }
function stopLive(){ for(const k in FT){ if(FT[k]) clearInterval(FT[k]); FT[k]=null; } }
async function focusOn(sym){ sym=(sym||"").toUpperCase().trim(); if(!sym) return;
  if(sym==="MARKET"||sym==="NIFTY"||sym==="NIFTY50"){ if(!SOLO) setView("market"); return; }      // patch 103: the market itself
  if(!SOLO&&!focusOn.inner&&wsWide()){ openWin(sym); return; }                       // patch 102: the main window stays on MARKET
  if(SOLO&&sym!==FOC){ document.title=sym+" · GIR"; try{ history.replaceState(null,"",location.pathname+"?k="+encodeURIComponent(K)+"&w="+encodeURIComponent(sym)); }catch(e){} }
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
  const nk=(D.news||[]).map(x=>x.t+x.s).join("|")+"|"+FOC; if(nk!==render.nk){ render.nk=nk; const nn=FOC?(D.news||[]).filter(x=>x.s===FOC):(D.news||[]); $("newsl").innerHTML=newsHTML(nn); $("run").innerHTML=runHTML(D.news||[]); }
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
  else if(FOC&&wsWide()){ const L=$("wsList"); if(L){ const st=L.scrollTop; L.innerHTML=shareListHTML(); L.scrollTop=st; } }
  else if(VIEW==="tape"||VIEW==="all") drawTape(); }
/* ---------- patch 93: THE ALERT BAR - only what is clear-cut ---------- */
/* ACT  = a BUY by the house rule (measured 55%+ on 50+ cases, agents agreeing) or your own money (💼 your trade, 🛑 book it)
   MOVE = something IS happening, not a trade by itself: 🚨 SUDDEN (EXTREME, 5-min confirmed) · ⚡ NEWS SHOCK chain ·
          🚀 RUNNING at 3%+ · ⚡ SPEED with the day already 2%+ · a BUY held back in the opening 15 minutes
   everything else (first moves, readings, movers, scorecards) stays in 1 NOW - no bar, no sound */
function alertTier(r){ const H=r.head||"", L=r.lines||[], T=[H].concat(L).join("\n"), k=r.kind||H.split(" ")[0]||"";
  if(/NOT SENT/.test(T)&&!/BUY/.test(T)) return "watch";
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
function beep(n,f){ if(!ASND) return; try{ acUnlock(); for(let i=0;i<n;i++){ const o=AC.createOscillator(), g=AC.createGain(); o.type="square"; o.frequency.value=f; o.connect(g); g.connect(AC.destination);
  const t=AC.currentTime+i*0.24; g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(0.25,t+0.02); g.gain.exponentialRampToValueAtTime(0.0001,t+0.2); o.start(t); o.stop(t+0.22); } }catch(e){} }
function sndToggle(){ ASND=!ASND; try{ localStorage.setItem("gir_snd",ASND?"1":"0"); }catch(e){} if(ASND){ acUnlock(); beep(1,880); } drawAlerts(true); }
let ATITLE=document.title; function titleFlag(on){ document.title=on?"🔴 ALERT · "+ATITLE:ATITLE; }
document.addEventListener("visibilitychange",()=>{ if(!document.hidden) titleFlag(false); });
function drawAlerts(force){ const B=$("abar"); if(!B||!D) return; const rows=(D.now||[]);
  const per={}; const keyOf=r=>r.t+"|"+r.head;
  rows.forEach(r=>{ const tr=alertTier(r); if(tr==="watch"||!r.s) return; const o=per[r.s]; if(!o||(o.tier!=="act"&&tr==="act")||(o.tier===tr&&r.t>o.r.t)) per[r.s]={r,tier:tr,n:(o?o.n:0)+1}; else o.n++; });
  const list=Object.values(per).sort((a,b)=>(b.r.t>a.r.t?1:b.r.t<a.r.t?-1:0)||(a.tier===b.tier?0:a.tier==="act"?-1:1));   // patch 105: newest first
  const nW=rows.filter(r=>alertTier(r)==="watch").length;
  if(ASEEN===null){ ASEEN=new Set(rows.map(keyOf)); }
  else { let ring=0; rows.forEach(r=>{ const k=keyOf(r); if(ASEEN.has(k)) return; ASEEN.add(k); const tr=alertTier(r); if(tr==="watch") return; AFRESH[r.s]=Date.now(); ring=Math.max(ring,tr==="act"?2:1); toast(r,tr); });
    if(ring){ beep(ring===2?3:1,ring===2?988:660); try{ if(navigator.vibrate&&(!navigator.userActivation||navigator.userActivation.hasBeenActive)) navigator.vibrate(ring===2?[200,100,200,100,200]:[150]); }catch(e){} if(document.hidden) titleFlag(true); } }
  const ck=JSON.stringify([list.map(x=>[x.r.s,x.r.t,x.tier,x.n,!!AFRESH[x.r.s]&&Date.now()-AFRESH[x.r.s]<9000]),nW,ASND,FOC]); if(!force&&ck===drawAlerts.ck) return; drawAlerts.ck=ck;
  const hasA=list.some(x=>x.tier==="act");
  B.className=hasA?"has-act":list.length?"has-move":"";
  const chip=x=>{ const r=x.r, up=r.side==="CE", dn=r.side==="PE"; const fr=AFRESH[r.s]&&Date.now()-AFRESH[r.s]<9000;
    return `<div class="ch ${x.tier}${fr?" fresh":""}" title="${esc([r.head].concat(r.lines||[]).join("\n"))}" onclick="focusOn('${esc(r.s)}')"><span class="tg">${x.tier==="act"?"ACT":"MOVING"}</span><span class="tm">${esc(r.t)}</span><b>${esc(r.s)}</b><span class="${up?"pu":dn?"pd":"dim"}">${up?"▲ UP → CE":dn?"▼ DOWN → PE":""}</span><span class="tk">${esc(r.kind||"")} ${esc(alertTicket(r))}</span>${x.n>1?`<span class="dim">×${x.n}</span>`:""}</div>`; };
  B.innerHTML=`<div class="al">ALERTS</div><div class="ac">${list.length?list.slice(0,12).map(chip).join(""):`<span class="ae">nothing clear-cut yet today — a BUY by the measured rule, your own trade, or a move that is really happening (SUDDEN · SHOCK · RUNNING 3%+) shows here with a sound</span>`}</div><div class="ar"><a class="${ASND?"on":""}" onclick="sndToggle()">${ASND?"🔔 SOUND ON":"🔕 SOUND OFF"}</a><a onclick="setView('now')">WATCH ${nW} →</a></div>`;
  if(FOC&&wsWide()) document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px"); }
setInterval(()=>{ if(Object.values(AFRESH).some(t=>Date.now()-t<10000)||drawAlerts.ck) drawAlerts(); },3000);

/* ---------- patch 93: THE TICK CHART - the price tick by tick, the calls' / puts' OI under it, one time axis ---------- */
let PXM="tick", TKW=900, TK={sym:"",pts:[],tk0:null,mv:[]}, TKH=null;
try{ PXM=localStorage.getItem("gir_pxm")||"tick"; TKW=+(localStorage.getItem("gir_tkw")||900); }catch(e){}
function pxMode(m){ PXM=m; try{ localStorage.setItem("gir_pxm",m); }catch(e){} paint(); }
function tkWin(w){ TKW=w; try{ localStorage.setItem("gir_tkw",String(w)); }catch(e){} paint(); }
function tickOn(){ return PXM==="tick"&&TK.sym===FOC&&TK.pts.length>=5; }
function pxChips(){ return `<span class="pxm"><a class="${PXM==="pro"?"on":""}" onclick="pxMode('pro')" title="TradingView-style: timeframes, indicators, drawing, zoom">PRO</a><a class="${PXM==="tick"?"on":""}" onclick="pxMode('tick')">TICK</a><a class="${PXM!=="tick"&&PXM!=="pro"?"on":""}" onclick="pxMode('5m')" title="PRICE · 5 MIN candles">5 MIN + OI</a></span>`; }
try{ if(!localStorage.getItem("gir_pxm_104")){ PXM="pro"; localStorage.setItem("gir_pxm","pro"); localStorage.setItem("gir_pxm_104","1"); } }catch(e){}
function tkFeed(v){ if(!v||!Array.isArray(v.tk)) return; if(TK.sym!==v.sym) TK={sym:v.sym,pts:[],tk0:null,mv:[]};
  const last=TK.pts.length?TK.pts[TK.pts.length-1][0]:0; for(const p of v.tk){ if(p[0]>last) TK.pts.push(p); } if(TK.pts.length>30000) TK.pts.splice(0,TK.pts.length-30000);
  TK.tk0=v.tk0; TK.mv=v.mv||[]; }
const hms=t=>{ const d=new Date((t+19800)*1000); return d.toISOString().slice(11,19); };
function tkView(){ const P=TK.pts; if(!P.length) return []; const t1=P[P.length-1][0]; const t0=TKW?t1-TKW:P[0][0]; let i=0; while(i<P.length&&P[i][0]<t0) i++; return P.slice(Math.max(0,i-1)); }
function tkRead(V,j){ const p=V[j], b=V[0]; if(!p) return ""; const dc=p[2]-b[2], dp=p[3]-b[3]; const sg=v=>(v>0?"+":"")+fmtL(v);
  const ch=FLV&&FLV.pc?(p[1]/FLV.pc-1)*100:null;
  return `<b class="am">${hms(p[0])}</b> · price <b class="${cls(ch)}">₹${inr(p[1])}</b>${ch!=null?` <span class="${cls(ch)}">${pc(ch)}</span>`:""} · in this window: <span style="color:var(--dn)">calls OI <b>${sg(dc)}</b></span> · <span style="color:var(--up)">puts OI <b>${sg(dp)}</b></span>`; }
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
      g+=`<text x="3" y="${T-3}" fill="var(--dn)" font-size="9" font-family="monospace">CALLS</text><text x="${LW-3}" y="${T-3}" fill="var(--up)" font-size="9" font-family="monospace" text-anchor="end">PUTS</text><line x1="${LW+2}" x2="${LW+2}" y1="${T}" y2="${T+ph}" stroke="var(--line2)"/>`;
      const bar=(yy,oi,d,dir,col)=>{ if(!oi) return ""; const w=(oi/mx)*half, add=Math.max(0,d||0)/mx*half, base=Math.max(0,w-add), x0=dir<0?KX-KWH:KX+KWH;
        let o=`<rect x="${(dir<0?x0-base:x0).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${base.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}" opacity=".42"/>`;
        if(add>0) o+=`<rect x="${(dir<0?x0-base-add:x0+base).toFixed(1)}" y="${(yy-bh).toFixed(1)}" width="${add.toFixed(1)}" height="${(2*bh).toFixed(1)}" fill="${col}"/>`;
        if((d||0)<0){ const cl=Math.min(half-w,-d/mx*half); if(cl>0) o+=`<rect x="${(dir<0?x0-w-cl:x0+w).toFixed(1)}" y="${(yy-bh+0.5).toFixed(1)}" width="${cl.toFixed(1)}" height="${(2*bh-1).toFixed(1)}" fill="none" stroke="${col}" stroke-dasharray="2 2"/>`; }
        return o; };
      vis.forEach(r=>{ const yy=yp(r.k); const isW=r.k===rf||r.k===fl;
        g+=`<line x1="${LW+2}" x2="${W-R}" y1="${yy.toFixed(1)}" y2="${yy.toFixed(1)}" stroke="${isW?(r.k===rf?"var(--dn)":"var(--up)"):"var(--line)"}" stroke-dasharray="${isW?"6 3":"1 4"}" opacity="${isW?.8:.7}"/>`;
        g+=bar(yy,r.ce_oi,r.ce_d,-1,"var(--dn)")+bar(yy,r.pe_oi,r.pe_d,1,"var(--up)");
        g+=`<text x="${KX}" y="${(yy+3.5).toFixed(1)}" fill="${isW?"var(--amber)":r===atm?"var(--hi)":"var(--dim)"}" font-size="${phone?9:10}" font-weight="${isW||r===atm?700:400}" font-family="monospace" text-anchor="middle">${r.k}</text>`; }); } }
  for(let k=0;k<=4;k++){ const v=lo+(hi-lo)*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${yp(v).toFixed(1)}" y2="${yp(v).toFixed(1)}" stroke="var(--line)"/><text x="${W-R+5}" y="${(yp(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace">${inr(+v.toFixed(2))}</text>`; }
  for(let k=0;k<=2;k++){ const v=olo+(ohi-olo)*k/2; g+=`<line x1="${L}" x2="${W-R}" y1="${yo(v).toFixed(1)}" y2="${yo(v).toFixed(1)}" stroke="var(--line)"/><text x="${L-5}" y="${(yo(v)+3.5).toFixed(1)}" fill="var(--dim)" font-size="10" font-family="monospace" text-anchor="end">${(v>0?"+":"")+fmtL(Math.round(v))}</text>`; }
  g+=`<line x1="${L}" x2="${W-R}" y1="${yo(0).toFixed(1)}" y2="${yo(0).toFixed(1)}" stroke="var(--dim)" stroke-dasharray="4 3"/>`;
  g+=`<text x="${L+4}" y="11" fill="var(--amber)" font-size="10" font-family="monospace">PRICE · TICK BY TICK</text><text x="${L}" y="${y0o-6}" fill="var(--dim)" font-size="10" font-family="monospace">OI ADDED: <tspan fill="var(--dn)">CALLS</tspan> · <tspan fill="var(--up)">PUTS</tspan></text>`;
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
  const mv=(TK.mv||[]).length?`<div class="tkm">OI moving now (last ${Math.max(1,Math.round((TK.mv[0].secs||300)/60))} min): ${TK.mv.slice(0,5).map(m=>`<b style="color:${m.side==="CE"?"var(--dn)":"var(--up)"}">${esc(m.k)} ${m.side} ${(m.d>0?"+":"")+fmtL(m.d)}</b>`).join(" · ")} <span class="dim">(+ = added, − = closed)</span></div>`:"";
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
    grid:{vertLines:{color:"#0f1620"},horzLines:{color:"#0f1620"}},rightPriceScale:{borderColor:"#1a2230"},timeScale:{borderColor:"#1a2230",timeVisible:true,secondsVisible:false,rightOffset:6},
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
    sr.R.forEach((x,i)=>pl(x.k,dn,`R${i+1} ${x.k} · ${fmtL(x.oi)}`)); sr.S.forEach((x,i)=>pl(x.k,up,`S${i+1} ${x.k} · ${fmtL(x.oi)}`));
    const ch_=FCH||{}; if(ch_.pdh) pl(ch_.pdh,"#7d8b9c","PDH",3); if(ch_.pdl) pl(ch_.pdl,"#7d8b9c","PDL",3); const pc_=(PH.d&&PH.d.pc)||ch_.pc; if(pc_) pl(pc_,"#9aa5b1","PREV CLOSE",1); }
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
      const a=sub.addLineSeries({color:dn,lineWidth:2,priceLineVisible:false,title:"CALLS ΔOI"}); a.setData(S.ce.map((v,i)=>tt[i]!=null?{time:tt[i],value:v-S.ce[0]}:null).filter(Boolean)); PC.ss.ce=a;
      const b2=sub.addLineSeries({color:up,lineWidth:2,priceLineVisible:false,title:"PUTS ΔOI"}); b2.setData(S.pe.map((v,i)=>tt[i]!=null?{time:tt[i],value:v-S.pe[0]}:null).filter(Boolean)); PC.ss.pe=b2;
      PC.lg2.innerHTML=`OI added today: <span class="pd">calls ${fmtL(S.ce[S.ce.length-1]-S.ce[0])}</span> · <span class="pu">puts ${fmtL(S.pe[S.pe.length-1]-S.pe[0])}</span>`; } else PC.lg2.innerHTML='<span class="dim">the OI line starts after two chain readings today</span>'; }
  PC.subReady=PRO.study!=="none"&&Object.keys(PC.ss).length>0;
  if(PC.subReady){ try{ if(PRO.study==="oi"){ const r=main.timeScale().getVisibleRange(); if(r) sub.timeScale().setVisibleRange(r); } else { const r=main.timeScale().getVisibleLogicalRange(); if(r) sub.timeScale().setVisibleLogicalRange(r); } }catch(e){} }
  if(keepR){ try{ main.timeScale().setVisibleLogicalRange(keepR); }catch(e){} }
  else if(!PC.fitted||PC.fitTf!==PRO.tf){ PC.fitted=true; PC.fitTf=PRO.tf; const n=B.length; const want=PRO.tf==="D"?n:PRO.tf==="60"?Math.min(n,70):PRO.tf==="15"?Math.min(n,100):Math.min(n,PRO.tf==="1"?180:150); main.timeScale().setVisibleLogicalRange({from:n-want,to:n+4}); }
  proLegend(null); }
/* ---------- patch 102: THE OI BUILD-UP CHART + SHARE INFO ---------- */
let OIMODE="chart"; try{ OIMODE=localStorage.getItem("gir_oim")||"chart"; }catch(e){}
function oiMode(m){ OIMODE=m; try{ localStorage.setItem("gir_oim",m); }catch(e){} paint(); }
function srLevels(rows,spot){ const up=rows.filter(r=>r.k>spot&&(r.ce_oi||0)>0).sort((a,b)=>b.ce_oi-a.ce_oi), dn=rows.filter(r=>r.k<spot&&(r.pe_oi||0)>0).sort((a,b)=>b.pe_oi-a.pe_oi);
  const R=up.slice(0,3).map(r=>({k:r.k,oi:r.ce_oi,d:r.ce_d})), S=dn.slice(0,3).map(r=>({k:r.k,oi:r.pe_oi,d:r.pe_d}));
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
    g+=bar(r.ce_oi,r.ce_d,-bw-0.5,"var(--dn)")+bar(r.pe_oi,r.pe_d,0.5,"var(--up)");
    const lab=rk.get(r.k)||sk.get(r.k); if(lab){ const isR=lab[0]==="R"; const top=y(isR?r.ce_oi:r.pe_oi); g+=`<text x="${x0.toFixed(1)}" y="${Math.max(12,top-4).toFixed(1)}" fill="${isR?"var(--dn)":"var(--up)"}" font-size="10" font-weight="700" text-anchor="middle">${lab}</text>`; }
    if(n<=16||i%Math.ceil(n/14)===0||rk.has(r.k)||sk.has(r.k)) g+=`<text x="${x0.toFixed(1)}" y="${H-B+12}" fill="${rk.has(r.k)||sk.has(r.k)?"var(--amber)":"var(--dim)"}" font-size="9" text-anchor="middle" transform="rotate(-35 ${x0.toFixed(1)} ${H-B+12})">${r.k}</text>`; });
  let si=rows.findIndex(r=>r.k>=spot); if(si<0) si=n; const prev=si>0?rows[si-1]:null, nxt=rows[si]; const sx=nxt&&prev?L+(si-1)*gw+gw/2+gw*((spot-prev.k)/((nxt.k-prev.k)||1)):L+si*gw;
  g+=`<line x1="${sx.toFixed(1)}" x2="${sx.toFixed(1)}" y1="${T-6}" y2="${H-B}" stroke="var(--amber)" stroke-dasharray="3 3"/><text x="${sx.toFixed(1)}" y="${T-10}" fill="var(--amber)" font-size="10" text-anchor="middle">₹${inr(spot)}</text>`;
  g+=`<text x="${L}" y="12" fill="var(--dn)" font-size="10">▮ CALL OI = resistance above</text><text x="${W-R}" y="12" fill="var(--up)" font-size="10" text-anchor="end">PUT OI = support below ▮</text>`;
  return `<div class="oic"><svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${g}</svg></div>`; }
function srBar(){ const rows=oiRows(); const spot=(FLV&&FLV.px)||(FD&&(FD.spot||FD.px))||0; if(!rows.length||!spot) return ""; const sr=srLevels(rows,spot);
  const one=(x,i,t)=>`<span><b class="${t==="R"?"pd":"pu"}">${t}${i+1} ${x.k}</b> <span class="dim">${fmtL(x.oi)}${x.d?` (${x.d>0?"+":""}${fmtL(x.d)})`:""} · ${((x.k/spot-1)*100).toFixed(1)}%</span></span>`;
  return `<div class="srb"><span class="t">RESISTANCE</span><b class="pd">${sr.nR} strong</b><span class="dim">of ${sr.aR} call strikes above</span>${sr.R.map((x,i)=>one(x,i,"R")).join("")}</div>
    <div class="srb"><span class="t">SUPPORT</span><b class="pu">${sr.nS} strong</b><span class="dim">of ${sr.aS} put strikes below</span>${sr.S.map((x,i)=>one(x,i,"S")).join("")}</div>`; }
function oiView(boxId){ return `<div class="sub"><span class="oimd"><a class="${OIMODE==="chart"?"on":""}" onclick="oiMode('chart')">CHART</a><a class="${OIMODE!=="chart"?"on":""}" onclick="oiMode('table')">TABLE</a></span><span class="dim">strong = at least half the biggest wall</span></div>${srBar()}${OIMODE==="chart"?oiChartSVG(boxId):oiChips()+oiTable()}`; }
function shareInfo(){ if(!FOC) return ""; const r=(TAPE||[]).find(x=>x.s===FOC)||{}; const sec=(SECS||[]).find(x=>(x.syms||[]).includes(FOC)); const c=FCK&&FCK.s===FOC?FCK:null;
  const peers=sec?(TAPE||[]).filter(x=>sec.syms.includes(x.s)&&x.s!==FOC&&x.chg!=null).sort((a,b)=>Math.abs(b.chg)-Math.abs(a.chg)).slice(0,6):[];
  const bu=(r.bu||"").toUpperCase(); const buc=bu.includes("LONG BUILD")||bu.includes("SHORT COVER")?"pu":bu?"pd":"dim";
  return `<div class="shi"><div><small>FUTURES</small><b class="${buc}">${esc(bu||"no clear build-up")}</b>${r.cr!=null?` · ₹${Math.abs(Math.round(r.cr))} cr`:""}${r.foi!=null?` · OI ${r.foi>0?"+":""}${r.foi}%`:""}</div>
    <div><small>SECTOR</small>${sec?`<b>${esc(sec.name.toUpperCase())}</b> <span class="${cls(sec.chg)}">${pc(sec.chg)}</span> · ${(sec.syms||[]).length} F&amp;O shares`:"—"}</div>
    <div><small>PEERS (biggest moves)</small>${peers.map(x=>`<a onclick="focusOn('${esc(x.s)}')"><b>${esc(x.s)}</b> <span class="${cls(x.chg)}">${pc(x.chg)}</span></a>`).join(" · ")||"—"}</div>
    <div><small>EVENTS</small>${c&&c.results_in!=null?`<b class="pd">results in ${c.results_in} day${c.results_in===1?"":"s"}</b>`:"no results in 7 days"}${c&&c.lot?` · lot ${c.lot}`:""}${c&&c.exp?` · expiry ${esc(c.exp.slice(5))} (${c.days}d)`:""}</div></div>`; }
/* ---------- patch 101: THE F&O CHECKLIST (the server's /chk: IV, IV percentile, expected move, breakeven, liquidity, max pain, PCR, results) ---------- */
let FCK=null;
async function pullChk(){ if(!FOC) return; const v=await getJ("chk?k="+encodeURIComponent(K)+"&sym="+encodeURIComponent(FOC)); if(v&&v.s===FOC){ FCK=v; paint(); } }
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
/* ---------- patch 98: THE MARKET SCREEN ---------- */
let MK=null, MKT=0;
async function pullMarket(force){ if(VIEW!=="market") return; if(!force&&Date.now()-MKT<9000) return; MKT=Date.now(); const v=await getJ("market?k="+encodeURIComponent(K)); if(v){ MK=v; drawMarket(); } }
function mkOpen(s){ if(wsWide()&&!SOLO){ openWin(s); return; } setView("all"); HOMED=true; focusOn(s); }
function mkSec(n){ WS.sec=n; WS.k="chg"; WS.dir=-1; wsSave(); WSKEY=""; if(!(wsWide()&&!SOLO)) setView("all"); const T=(TAPE||[]).filter(r=>((SECS.find(x=>x.name===n)||{}).syms||[]).includes(r.s)).sort((a,b)=>Math.abs(b.chg||0)-Math.abs(a.chg||0)); HOMED=true; if(T.length) focusOn(T[0].s); else homeOpen(); }
const mkHeat=v=>{ if(v==null) return "transparent"; const a=Math.min(1,Math.abs(v)/2.5); return v>=0?`rgba(30,215,96,${(0.12+a*0.75).toFixed(2)})`:`rgba(255,59,74,${(0.12+a*0.75).toFixed(2)})`; };
const mkPc=v=>v==null?"—":(v>=0?"+":"")+Number(v).toFixed(2)+"%";
function drawMarket(){ if(VIEW!=="market"||!D) return; const M=MK||{};
  if(wsWide()) document.documentElement.style.setProperty("--toph",$("top").offsetHeight+"px");
  // F&O MOVERS: gainers | losers
  { const el=$("mk-mov"); const T=(TAPE||[]).filter(r=>r.chg!=null).slice().sort((a,b)=>b.chg-a.chg); const n=Math.max(12,Math.floor((el.clientHeight||300)/15)-1);
    const up=T.filter(r=>r.chg>0).slice(0,n), dn=T.filter(r=>r.chg<0).reverse().slice(0,n); const N=Math.max(up.length,dn.length);
    const wide=(el.clientWidth||300)>=430; const cell=r=>r?`<td class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b></td>${wide?`<td class="r dim">${r.px!=null?inr(r.px):""}</td>`:""}<td class="r ${cls(r.chg)}${qfl(r.s)}">${mkPc(r.chg)}</td>`:(wide?"<td></td><td></td><td></td>":"<td></td><td></td>");
    $("mk-movh").textContent=`${T.filter(r=>r.chg>0).length} up · ${T.filter(r=>r.chg<0).length} down · tap = its trading screen`;
    el.innerHTML=`<table>${Array.from({length:N},(_,i)=>`<tr>${cell(up[i])}<td style="border-left:1px solid var(--line);padding:0"></td>${cell(dn[i])}</tr>`).join("")}</table>`; }
  // NIFTY through the day (% from the open) + F&O advance − decline
  { const el=$("mk-nif"); const W=Math.max(260,el.clientWidth), H=Math.max(200,el.clientHeight); const A=(M.nifty||[]).filter(v=>v!=null), B=M.adv||[];
    const ix=(D.idx||{}).NIFTY||{}, bx=(D.idx||{}).BANKNIFTY||{};
    if(A.length<2&&B.length<2){ el.innerHTML='<div class="empty">the day\'s path starts with the first 5-min bar (09:20)</div>'; }
    else { const L=6,R=54,T=40,PH=(H-T-22)*0.62,G=14,BH=(H-T-22)-PH-G; const NB=Math.max(A.length,B.length,2); const x=i=>L+(W-L-R)*i/Math.max(1,Math.max(NB-1,(M.bars||NB)-1, 1));
      const sc=(arr,y0,h)=>{ let lo=Math.min(0,...arr),hi=Math.max(0,...arr); if(hi===lo){hi+=1;lo-=1;} return v=>y0+h*(1-(v-lo)/(hi-lo)); };
      const ya=sc(A,T,PH), yb=sc(B,T+PH+G,BH); let g="";
      for(let k=0;k<5;k++){ const y=T+PH*k/4; g+=`<line x1="${L}" x2="${W-R}" y1="${y}" y2="${y}" stroke="var(--line)"/>`; }
      if(A.length>1){ g+=`<line x1="${L}" x2="${W-R}" y1="${ya(0)}" y2="${ya(0)}" stroke="var(--dim)" stroke-dasharray="3 3"/><polyline fill="none" stroke="#fff" stroke-width="1.5" points="${A.map((v,i)=>`${x(i).toFixed(1)},${ya(v).toFixed(1)}`).join(" ")}"/><text x="${W-R+4}" y="${(ya(A[A.length-1])+4).toFixed(1)}" fill="#fff" font-size="10">${mkPc(A[A.length-1]).replace("%","")}</text>`; }
      if(B.length>1){ const z=yb(0); g+=`<line x1="${L}" x2="${W-R}" y1="${z}" y2="${z}" stroke="var(--dim)" stroke-dasharray="3 3"/>`+B.map((v,i)=>`<rect x="${x(i).toFixed(1)}" y="${Math.min(z,yb(v)).toFixed(1)}" width="${Math.max(1,(W-L-R)/NB-0.8).toFixed(1)}" height="${Math.abs(yb(v)-z).toFixed(1)}" fill="${v>=0?"var(--up)":"var(--dn)"}" opacity=".8"/>`).join("")+`<text x="${W-R+4}" y="${(T+PH+G+10)}" fill="var(--dim)" font-size="9">adv−dec</text><text x="${W-R+4}" y="${(T+PH+G+22)}" fill="${B[B.length-1]>=0?"var(--up)":"var(--dn)"}" font-size="10">${B[B.length-1]>0?"+":""}${B[B.length-1]}</text>`; }
      g+=["09:15","10:30","11:45","13:00","14:15","15:30"].map((t,k)=>`<text x="${(L+(W-L-R)*k/5).toFixed(0)}" y="${H-4}" fill="var(--dim)" font-size="9" text-anchor="${k===0?"start":k===5?"end":"middle"}">${t}</text>`).join("");
      g+=`<text x="${L+2}" y="12" fill="#fff" font-size="11">NIFTY ${ix.last!=null?inr(ix.last):""} <tspan fill="${(ix.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(ix.chg)}</tspan></text><text x="${L+2}" y="23" fill="var(--amber)" font-size="10">BANKNIFTY ${bx.last!=null?inr(bx.last):""} <tspan fill="${(bx.chg||0)>=0?"var(--up)":"var(--dn)"}">${mkPc(bx.chg)}</tspan></text><text x="${L+2}" y="34" fill="var(--dim)" font-size="9">line = NIFTY % from the open · bars = F&amp;O shares up − down</text>`;
      el.innerHTML=`<svg width="${W}" height="${H}">${g}</svg>`; } }
  // live: every sector's average move and the F&O up / down from the second-by-second prices (patch 99)
  const LV={}; { const by={}; (TAPE||[]).forEach(r=>by[r.s]=r); for(const x of (SECS||[])){ const v=(x.syms||[]).map(s=>by[s]&&by[s].chg).filter(v=>v!=null); if(v.length) LV[x.name]=v.reduce((a,b)=>a+b,0)/v.length; }
    if(M.sectors) M.sectors.forEach(x=>{ if(LV[x.name]!=null) x.chg=+LV[x.name].toFixed(2); });
    const T=(TAPE||[]).filter(r=>r.chg!=null); if(T.length){ M.fo_up=T.filter(r=>r.chg>0).length; M.fo_dn=T.filter(r=>r.chg<0).length; } }
  // SECTOR DONUT
  { const el=$("mk-don"); const W=Math.max(260,el.clientWidth), H=Math.max(200,el.clientHeight); const S=(M.sectors&&M.sectors.length?M.sectors:(SECS||[]).map(x=>({name:x.name,n:(x.syms||[]).length,chg:x.chg}))).filter(x=>x.n);
    if(!S.length){ el.innerHTML='<div class="empty">no sectors yet</div>'; }
    else { const R=Math.min(H/2-12,W*0.23), cx=R+10, cy=H/2, r=R*0.52; const tot=S.reduce((a,x)=>a+x.n,0); let ang=-Math.PI/2, g="";
      S.forEach(x=>{ const a0=ang,a1=ang+2*Math.PI*x.n/tot; ang=a1; const p=(a,rr)=>[(cx+rr*Math.cos(a)).toFixed(1),(cy+rr*Math.sin(a)).toFixed(1)]; const lg=a1-a0>Math.PI?1:0; const [x0,y0]=p(a0,R),[x1,y1]=p(a1,R),[x2,y2]=p(a1,r),[x3,y3]=p(a0,r);
        g+=`<path class="k" onclick="mkSec('${esc(x.name)}')" d="M${x0},${y0} A${R},${R} 0 ${lg} 1 ${x1},${y1} L${x2},${y2} A${r},${r} 0 ${lg} 0 ${x3},${y3} Z" fill="${mkHeat(x.chg)}" stroke="#07090c" stroke-width="1.5"><title>${esc(x.name)} ${mkPc(x.chg)} · ${x.n} shares</title></path>`; });
      const all=(TAPE||[]).filter(r=>r.chg!=null); const av=all.length?all.reduce((a,r)=>a+r.chg,0)/all.length:null;
      g+=`<text x="${cx}" y="${cy-4}" fill="#fff" font-size="11" text-anchor="middle">F&amp;O</text><text x="${cx}" y="${cy+12}" fill="${(av||0)>=0?"var(--up)":"var(--dn)"}" font-size="12" font-weight="700" text-anchor="middle">${mkPc(av)}</text>`;
      const lx=cx+R+14, lh=Math.max(11,Math.min(16,(H-8)/S.length)); g+=S.slice().sort((a,b)=>(b.chg??-99)-(a.chg??-99)).map((x,i)=>`<g class="k" onclick="mkSec('${esc(x.name)}')"><rect x="${lx}" y="${6+i*lh}" width="9" height="${lh-3}" fill="${mkHeat(x.chg)}"/><text x="${lx+14}" y="${6+i*lh+lh-5}" fill="var(--txt)" font-size="9">${esc(x.name.toUpperCase().slice(0,14))} <tspan fill="var(--dim)">${x.n}</tspan></text><text x="${W-6}" y="${6+i*lh+lh-5}" fill="${(x.chg||0)>=0?"var(--up)":"var(--dn)"}" font-size="9" text-anchor="end">${mkPc(x.chg)}</text></g>`).join("");
      el.innerHTML=`<svg width="${W}" height="${H}">${g}</svg>`; } }
  // F&O MONEY: the shares with the most fresh futures money, per build-up
  { const mo=M.money||{}; const blk=(b,c)=>{ const xs=mo[b]||[]; return `<div><h4 class="${c}">${b}</h4><table>${xs.length?xs.map(x=>`<tr class="k" onclick="mkOpen('${esc(x.s)}')"><td><b>${esc(x.s)}</b></td><td class="r ${c}">₹${Math.abs(Math.round(x.cr||0))} cr</td><td class="r dim">OI ${x.oi>0?"+":""}${x.oi??"—"}%</td><td class="r ${cls(x.chg)}">${mkPc(x.chg)}</td></tr>`).join(""):'<tr><td class="dim">none yet</td></tr>'}</table></div>`; };
    $("mk-mon").innerHTML=`<div class="mn">${blk("LONG BUILD-UP","pu")}${blk("SHORT BUILD-UP","pd")}${blk("SHORT COVERING","pu")}${blk("LONG UNWINDING","pd")}</div><div class="legend" style="padding:3px 6px">LONG BUILD-UP = price up + OI up (fresh buying) · SHORT BUILD-UP = price down + OI up (fresh selling) · SHORT COVERING = price up + OI down · LONG UNWINDING = price down + OI down</div>`; }
  // F&O DESK: expiry · PCR · VIX · FII/DII · market · ban · results
  { const C=M.chain||{}; const vx=(D.idx||{}).VIX||{}; const ew=C.days!=null&&C.days<=4;
    const spark=(arr)=>{ if(!arr||arr.length<2) return ""; const W=110,H=18; const vs=arr.map(x=>x[1]); const lo=Math.min(...vs),hi=Math.max(...vs); return `<svg width="${W}" height="${H}" style="vertical-align:middle;margin-left:6px"><polyline fill="none" stroke="#4fc3f7" stroke-width="1.4" points="${vs.map((v,i)=>`${(W*i/(vs.length-1)).toFixed(1)},${(H-2-(H-4)*((v-lo)/((hi-lo)||1))).toFixed(1)}`).join(" ")}"/></svg>`; };
    const fd=M.fiidii; const fdt=fd==null?"not read":typeof fd==="object"?Object.entries(fd).slice(0,4).map(([k,v])=>`${esc(k).toUpperCase()} <b class="${(+v||0)>=0?"pu":"pd"}">${typeof v==="number"?(v>0?"+":"")+inr(Math.round(v)):esc(String(v))}</b>`).join(" · "):esc(String(fd));
    $("mk-dsk").innerHTML=`<div><em>EXPIRY</em><b class="${ew?"am":""}">${C.exp?esc(C.exp):"—"}</b>${C.days!=null?` · ${C.days} day${C.days===1?"":"s"} left`:""}${ew?' · <b class="am">EXPIRY WEEK</b> — premiums melt fast':""}</div>
      <div><em>PCR</em><b>${C.pcr_now??"—"}</b> <span class="dim">stocks, puts ÷ calls</span>${spark(C.pcr)}</div>
      <div><em>VIX</em><b>${vx.last!=null?inr(vx.last):(M.vix??"—")}</b> <span class="${cls(vx.chg)}">${vx.chg!=null?mkPc(vx.chg):""}</span></div>
      <div><em>MARKET</em><b class="${M.india==="BULLISH"?"pu":M.india==="BEARISH"?"pd":""}">${esc(M.india||"—")}</b> · F&amp;O <span class="pu">${M.fo_up??"—"} up</span> · <span class="pd">${M.fo_dn??"—"} down</span></div>
      <div><em>FII / DII</em>${fdt}</div>
      <div><em>BAN</em>${(M.ban||[]).length?(M.ban||[]).map(x=>`<b class="pd">${esc(x)}</b>`).join(" "):'<span class="dim">no share in the F&amp;O ban today</span>'}${(M.ban||[]).length?' <span class="dim">— no new positions</span>':""}</div>
      <div><em>RESULTS</em>${(C.results||[]).length?(C.results||[]).slice(0,10).map(r=>`<span class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b> <span class="dim">${esc((r.d||"").slice(5))}</span></span>`).join(" · "):'<span class="dim">no F&amp;O results in the next 7 days</span>'}</div>`; }
  // SECTORS THROUGH THE DAY
  { const S=M.sectors||[], L0=M.labels||[]; const fit=Math.max(3,Math.floor((($("mk-hea").clientWidth||400)-120)/38)-1); const cut=Math.max(0,L0.length-fit), L=L0.slice(cut);
    $("mk-hea").innerHTML=S.length&&L.length?`<table class="hm"><tr><td></td>${L.map(t=>`<td class="dim">${t}</td>`).join("")}<td class="am">NOW</td></tr>${S.map(x=>`<tr class="k" onclick="mkSec('${esc(x.name)}')"><td>${esc(x.name.toUpperCase().slice(0,16))}</td>${(x.series||[]).slice(cut).map(v=>`<td style="background:${mkHeat(v)};color:#fff">${v==null?"":(v>=0?"+":"")+v.toFixed(1)}</td>`).join("")}<td style="background:${mkHeat(x.chg)};color:#fff;font-weight:700">${x.chg==null?"":(x.chg>=0?"+":"")+x.chg.toFixed(1)}</td></tr>`).join("")}</table>`:'<div class="empty">fills from the first 30 minutes of the day</div>'; }
  // OI BUILD-UP BY SECTOR
  { const S=M.sectors||[]; const B=[["LONG BUILD-UP","LONG BU",1],["SHORT BUILD-UP","SHORT BU",-1],["SHORT COVERING","SHORT COV",1],["LONG UNWINDING","LONG UNW",-1]]; const bc=M.bu_cnt||{};
    $("mk-bus").innerHTML=S.length?`<table class="hm"><tr><td></td>${B.map(b=>`<td class="${b[2]>0?"pu":"pd"}">${b[1]}</td>`).join("")}</tr>${S.map(x=>`<tr class="k" onclick="mkSec('${esc(x.name)}')"><td>${esc(x.name.toUpperCase())}</td>${B.map(b=>{ const k=(x.bu||{})[b[0]]||0; return `<td style="background:${k?mkHeat(b[2]*k/Math.max(1,x.n)*3):"transparent"};color:#fff">${k||""}</td>`; }).join("")}</tr>`).join("")}<tr><td><b>ALL F&amp;O</b></td>${B.map(b=>`<td><b class="${b[2]>0?"pu":"pd"}">${bc[b[0]]??""}</b></td>`).join("")}</tr></table>`:'<div class="empty">from the first futures reading</div>'; }
  // OI SCENARIOS + NEWS, newest first
  { const sc=((D.scn||{}).today||[]).map(r=>({t:r.t,k:"🧩",s:r.s,h:r.name,c:r.side==="CE"?"pu":r.side==="PE"?"pd":"dim",l:r.line})); const nw=(D.news||[]).map(x=>({t:(x.hm||"").slice(-5),k:x.s==="MARKET"?"🏛":"📰",s:x.s,h:x.h,c:x.side>0?"pu":x.side<0?"pd":"dim",l:x.why||""}));
    const all=sc.concat(nw).sort((a,b)=>(b.t||"")>(a.t||"")?1:-1).slice(0,40);
    $("mk-nws").innerHTML=all.length?`<table>${all.map(r=>`<tr class="k" onclick="mkOpen('${esc(r.s||"")}')"><td class="am">${esc(r.t||"")}</td><td>${r.k} <b>${esc(r.s||"")}</b> <span class="${r.c}">${esc((r.h||"").slice(0,60))}</span>${r.l?`<br><span class="dim">${esc(r.l.slice(0,90))}</span>`:""}</td></tr>`).join("")}</table>`:'<div class="empty">no scenario or news yet today</div>'; }
}
window.addEventListener("resize",()=>{ if(VIEW==="market") drawMarket(); });
/* ---------- patch 89: the function keys and the panels ---------- */
let VIEW="all"; try{ VIEW=localStorage.getItem("gir_fk")||"all"; }catch(e){}
let PN=null, PNT=null;
const rsx=v=>v==null?"—":(v<0?"−₹":"₹")+Math.abs(Math.round(v)).toLocaleString("en-IN");
function setView(v){ VIEW=v; try{ localStorage.setItem("gir_fk",v); }catch(e){}
  if(v!=="all"&&FOC&&wsWide()) unfocus();                       // a function key shows its panel; HOME brings the trading screen back
  document.body.classList.toggle("one",v!=="all");
  document.querySelectorAll("#fkeys a").forEach(a=>a.classList.toggle("on",a.dataset.v===v));
  document.querySelectorAll("#grid>section").forEach(x=>x.classList.toggle("on",x.id===v));
  if(v==="market"){ drawMarket(); pullMarket(true); }
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
document.addEventListener("keydown",e=>{ if(e.target&&["INPUT","SELECT","TEXTAREA"].includes(e.target.tagName)) return; const k=e.key; const m={"`":"all","m":"market","M":"market","1":"now","2":"three","3":"scn","4":"secs","5":"tape","6":"news","7":"picks","8":"tom","9":"myfo","0":"desk"}; if(m[k]) setView(m[k]); });
if(SOLO){ document.body.classList.add("solo"); VIEW="all"; document.title=SOLO+" · GIR"; } else if(wsWide()&&VIEW==="all") VIEW="market";   // patch 102: MARKET is home
loop(); stream(); loadThree(); setInterval(loadThree,120000); setView(VIEW); if(SOLO){ HOMED=true; focusOn(SOLO); }
</script></body></html>
HTML_P105
cat > $D/p105test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p105test.py - the alerts on the page: the bar shows the NEWEST first; every new ACT / MOVING alert pops up as a card
(top right; red TRADE ALERT 60 s, amber SOMETHING IS HAPPENING 25 s; 2 small cards on a phone); NIFTY SHOCK / MARKET NEWS
chips show the move / the headline"""
import os, sys
B = os.path.dirname(os.path.abspath(__file__))
ok = True


def check(name, good):
    global ok
    print("  %s %s" % ("OK  " if good else "FAIL", name)); ok = ok and bool(good)


h = open(os.path.join(B, "home.html"), encoding="utf-8").read()
check("the alert bar: newest first", "// patch 105: newest first" in h)
check("a card for every new ACT / MOVING alert, on every screen", "function toast(r,tr)" in h and 'id="toasts"' in h and "toast(r,tr); });" in h)
check("TRADE ALERT 60 s, SOMETHING IS HAPPENING 25 s, at most 4 (2 on a phone); a tap opens the share", 'tr==="act"?60000:25000' in h and "box.children.length>4" in h and ":nth-child(n+3){display:none}" in h and "focusOn(r.s||\"MARKET\")" in h)
check("NIFTY SHOCK / MARKET NEWS chips show the move / the headline", "if(/NIFTY SHOCK|MARKET NEWS/.test(r.head||\"\"))" in h)
check("patches 91-104 are still there", all(x in h for x in ("function shareListHTML", "function alertTier", "function drawMarket", "function applyQ", "function chkHTML", "function openWin", "function proRender")))
print("\nP105 ALERT CARDS TEST %s" % ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
PY_TEST
grep -q "function toast(r,tr)" $W/home.html && grep -q "function proRender" $W/home.html && grep -q "</html>" $W/home.html || { echo "the new page is not complete"; rm -f $D/p105test.py; exit 1; }
cp $W/home.html $D/home.html && echo "    home.html replaced ($(wc -c < $D/home.html) bytes)"
cd $D && python3 -m py_compile p105test.py || back
timeout 60 python3 p105test.py 2>&1 | grep "OK  \|FAIL\|CARDS TEST"
timeout 60 python3 p105test.py >/dev/null 2>&1 || { echo "the test failed"; back; }
for t in p93test.py p102test.py p103test.py p104test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 10
K=$(cat $D/dash_token.txt)
curl -s --max-time 15 "http://127.0.0.1:8090/?k=$K" | grep -q "function toast(r,tr)" || { echo "the new page is not being served"; back; }
echo "page: $(systemctl is-active gir-dash)"
echo "PATCH 105 APPLIED - reload the page."
echo "    http://64.227.155.177:8090/?k=$K"
