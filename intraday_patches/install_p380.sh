#!/bin/bash
# PATCH 380 - 🌅 THE MORNING LIST, READY AT 07:00 (Rama, 17 Nov 16:45: "how will you know when something happens, which shares will be
#   affected once the market is over? You need to start monitoring all the news and the overnight sector movement, and keep the list ready
#   at 07:00"). The 🌙 OVERNIGHT list read only the NEWS, at 08:35. Now:
#   · 07:00  the list is made at 07:00, and it also reads the OVERNIGHT MARKETS (morningmkts.py, Yahoo Finance's public price feed, no key):
#            the US indices and sector funds, Infosys / Wipro / HDFC Bank / ICICI Bank / Dr Reddy's in New York, Brent crude, natural gas,
#            gold, silver, copper, aluminium, the US 10-year yield, the dollar, the rupee, Japan / Hong Kong / Korea / Shanghai.
#            A big move -> a 🌍 MARKET item (the F&O shares it usually moves, which way, one reason) and the SECTOR TILT. The links are
#            written out in morningmkts.py (LINKS) so they can be read and corrected - they are GIR's working assumptions, scored from today.
#            📅 TODAY: results due today and last evening (chains.db), the F&O ban list (NSE). 👀 WATCH AT THE OPEN: a share two or more
#            items point the same way, none the other way.
#   · 08:35  the same again with the fresh markets (Asia open) and news; what came after 07:00 is marked NEW
#   · 15:50  the score as before; the 🌍 MARKET items are scored on their own row of the record ("market links"), not mixed with the news
#   A paper record: no sound, no Telegram (the channel is Rama's choice), no order. Replaces overnight.py, adds morningmkts.py, adds 07:00 to
#   the gir-overnight timer, edits the 🌙 box on the page. Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 380" $D/home.html && grep -q "patch 380" $D/overnight.py && grep -q "07:00:00" $U/gir-overnight.timer 2>/dev/null; then echo "patch 380 - already in"; exit 0; fi
grep -q "patch 358" $D/home.html && [ -f $D/overnight.py ] && [ -f $U/gir-overnight.timer ] || { echo "patch 358 (the 🌙 box, overnight.py, the timer) not found - nothing done"; exit 1; }
for f in overnight.py morningmkts.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "patch 380" $W/overnight.py && python3 -m py_compile $W/overnight.py $W/morningmkts.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
cp $D/home.html $D/home.html.bak$TS; cp $D/overnight.py $D/overnight.py.bak$TS; cp $U/gir-overnight.timer $W/timer.bak
back(){ cp $D/home.html.bak$TS $D/home.html; cp $D/overnight.py.bak$TS $D/overnight.py; rm -f $D/morningmkts.py; cp $W/timer.bak $U/gir-overnight.timer; systemctl daemon-reload; systemctl restart gir-overnight.timer gir-dash; echo "❌ old files put back - nothing changed"; exit 1; }
cp $W/overnight.py $D/overnight.py && cp $W/morningmkts.py $D/morningmkts.py || back
python3 - $D/home.html <<'PY_EDIT' || back
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
if "patch 380" in t:
    sys.exit(0)
R = [
 # the header: ready at 07:00, refreshed at 08:35
 ('''· a paper record - no sound · read at 08:35${mine&&V.at?" (today "+E(V.at)+", "+E(V.n_lines)+" lines since "+E(V.since)+")":""}</small></div>`+''',
  '''· a paper record - no sound · ready at 07:00, refreshed at 08:35${mine&&V.at?" (today: made "+(V.upd&&V.first_at?E(V.first_at)+", refreshed ":"")+E(V.at)+" · "+E(V.n_lines)+" lines since "+E(V.since)+")":""}</small></div>`+mk()+'''),
 ('''"today's list is made at 08:35"''', '''"today's list is made at 07:00"'''),
 # a 🌍 market item and a NEW item are marked
 ('''<span class="k ${E(it.strength)}">${E(it.strength)}</span>${sh}</div>''',
  '''<span class="k ${E(it.strength)}">${it.kind==="market"?"🌍 market":E(it.strength)}</span>${it.new?'<span class="k nw">NEW</span>':""}${sh}</div>'''),
 # the record: the market links on their own row
 ('''moderate: ${rec("moderate")} · weak: ${rec("weak")}<br>''', '''moderate: ${rec("moderate")} · weak: ${rec("weak")}<br>🌍 market links: ${rec("market")}<br>'''),
 # the markets, the tilt, the calendar and the watch list - drawn above the items
 ('''    const R=V.record||{}, rec=k=>R[k]?''',
  '''    const s1=s=>`<span class="s" onclick="try{mkOpen('${E(s).replace(/'/g,"")}')}catch(e){}">${E(s)}</span>`;   /* patch 380 */
    const mk=()=>{ if(!mine) return ""; const A=V.mkts||[], M=A.filter(m=>m.ok), miss=A.length-M.length;
      const O=[...M.filter(m=>m.big).sort((a,b)=>Math.abs(b.chg)-Math.abs(a.chg)),...M.filter(m=>!m.big)];
      const chip=m=>`<span class="mc${m.big?" big":""}" title="as of ${E(m.at)}"><span class="${m.chg>=0?"up":"dn"}">${E(m.name)} ${m.chg>=0?"+":""}${(+m.chg).toFixed(2)}${m.unit==="%"?"%":" pts"}</span></span>`;
      const T=(V.tilt||[]).map(x=>`<span class="${x.dir==="up"?"up":x.dir==="down"?"dn":"dim"}" title="${E([...x.up.map(y=>"▲ "+y),...x.down.map(y=>"▼ "+y)].join(" · "))}">${x.dir==="up"?"▲":x.dir==="down"?"▼":"↕"} ${E(x.sector)}</span>`).join(" · ");
      const C=V.cal||{}, cal=[(C.results||[]).length?"results today: "+C.results.map(s1).join(" "):"", (C.results_prev||[]).length?"results last evening: "+C.results_prev.map(s1).join(" "):"",
        (C.ban||[]).length?"F&amp;O ban (no new positions): "+C.ban.map(s1).join(" "):"", C.ban_note?`<span class="dim">${E(C.ban_note)}</span>`:""].filter(Boolean).join(" · ");
      const Wl=(V.watch||[]).map(w=>`<div class="w"><span class="${w.dir==="up"?"up":"dn"}">${w.dir==="up"?"▲ UP":"▼ DOWN"}</span> ${s1(w.s)}${w.results?' <span class="k">results</span>':""}${w.ban?' <span class="k strong">F&amp;O BAN</span>':""} <span class="dim">${(w.why||[]).map(E).join(" + ")}</span></div>`).join("");
      return `<div class="mk"><div><b>🌍 OVERNIGHT MARKETS</b> <span class="dim">big moves first${miss?" · "+miss+" not read":""}</span></div><div class="mcs">${O.length?O.map(chip).join(""):'<span class="dim">the markets were not read</span>'}</div>`+
        (T?`<div><b>SECTOR TILT</b> <span class="dim">(from the big moves, GIR's written links - scored daily)</span> ${T}</div>`:"")+
        `<div><b>📅 TODAY</b> ${cal||'<span class="dim">no results due, no F&amp;O share in the ban</span>'}</div>`+
        (Wl?`<div><b>👀 WATCH AT THE OPEN</b> <span class="dim">two or more items point the same way · the news is usually in the opening price - no tested edge in trading its direction at the open, watch the first 15 minutes</span>${Wl}</div>`:"")+`</div>`; };
    const R=V.record||{}, rec=k=>R[k]?'''),
]
for a, b in R:
    if t.count(a) != 1:
        print("❌ home.html: the patch 358 line not found (x%d): %s" % (t.count(a), a[:70])); sys.exit(1)
    t = t.replace(a, b, 1)
css = '''<style>/* patch 380: 🌅 the morning list at 07:00 - the overnight markets, the sector tilt, today's calendar, the watch list */
#gxon .mk{padding:7px 10px;border-bottom:1px solid #2a2547;font:12px/1.5 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#c9d4e3;text-align:left}
#gxon .mk b{font:800 11px ui-monospace,Menlo,monospace;letter-spacing:.05em;color:#c3b3ff}#gxon .mk>div{margin:3px 0}
#gxon .mcs{display:flex;flex-wrap:wrap;gap:4px}#gxon .mc{font:600 11px ui-monospace,Menlo,monospace;padding:1px 6px;border-radius:3px;background:#17152b;opacity:.65}
#gxon .mc.big{opacity:1;background:#221f3d;font-weight:800}#gxon .mk .w{margin:2px 0 2px 8px}#gxon .k.nw{background:#123a2a;color:#26c281}
</style>
'''
t = t.replace("</body>", css + "<!-- patch 380 -->\n</body>", 1)
open(p, "w", encoding="utf-8").write(t); print("  home.html: the 🌙 box now shows the markets, the sector tilt, today's calendar and the watch list")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
grep -q "07:00:00" $U/gir-overnight.timer || sed -i 's|^OnCalendar=Mon..Fri \*-\*-\* 08:35:00 Asia/Kolkata|OnCalendar=Mon..Fri *-*-* 07:00:00 Asia/Kolkata\n&|' $U/gir-overnight.timer
sed -i 's|^Description=GIR overnight news, 08:35 and 15:50 IST Monday-Friday|Description=GIR morning list 07:00 (refreshed 08:35) and its score 15:50 IST Monday-Friday|' $U/gir-overnight.timer
grep -q "07:00:00" $U/gir-overnight.timer || { echo "❌ the timer line not added"; back; }
systemctl daemon-reload && systemctl restart gir-overnight.timer || back
echo "  the timer: $(systemctl is-active gir-overnight.timer) · next: $(systemctl list-timers gir-overnight.timer --no-pager 2>/dev/null | sed -n 2p | awk '{print $1, $2, $3}')"
cd $D && timeout 300 python3 -c "
import morningmkts as M, datetime as dt
r = M.markets(); ok = [m for m in r if m['ok']]
print('  the overnight markets read now: %d of %d' % (len(ok), len(r)) + ('' if len(ok) == len(r) else ' - not read: ' + ', '.join(m['name'] for m in r if not m['ok'])))
for m in sorted([m for m in ok if m['big']], key=lambda m: -abs(m['chg']))[:8]:
    print('    BIG %-28s %+.2f%s (as of %s)' % (m['name'], m['chg'], m['unit'] if m['unit'] == '%' else ' pts', m['at']))
c = M.calendar(dt.datetime.now(M.IST).date()); print('  results today: %s · F&O ban: %s' % (', '.join(c['results']) or 'none', ', '.join(c['ban']) or c['ban_note'] or 'none'))
" || echo "  ⚠ the markets test did not finish - the 07:00 run will show 'not read' for what it cannot reach"
python3 -c "import overnight; v = overnight.view(); print('  /overnight still answers: day %s · %d items' % (v['day'], len(v['items'])))" || back
systemctl restart gir-dash; sleep 6
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 380 done - refresh GIR (Ctrl+Shift+R). Tomorrow from 07:00 the 🌙 box in TRADE NOW shows 🌍 the overnight markets, the sector"
echo "   tilt, 📅 today's results and F&O ban, 👀 the watch list, then the news items; refreshed at 08:35 (NEW marked); scored at 15:50."
echo "   to see it right now (it is made for tomorrow's date only from midnight):  tail -5 $D/data/overnight_run.txt  after 07:01"
echo "   undo: cp $D/home.html.bak$TS $D/home.html; cp $D/overnight.py.bak$TS $D/overnight.py; rm $D/morningmkts.py; sed -i '/07:00:00/d' $U/gir-overnight.timer; systemctl daemon-reload; systemctl restart gir-overnight.timer gir-dash"
