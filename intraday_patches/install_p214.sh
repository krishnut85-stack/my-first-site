#!/bin/bash
# PATCH 214 - PUSHING UP · PULLING DOWN where you see it (Rama, 12 Nov: "what happened to WHO IS PUSHING - and we need WHO IS PULLING DOWN -
#   I don't see anything on the laptop and the mobile"). The board sat UNDER the share window's chart / chain / checklist (laptop) and in the
#   DESK tab (phone). Now:
#   - every share screen, AT THE TOP: WHO IS PUSHING IT UP / WHO IS PULLING IT DOWN · ▲ n pushing up (who) · ▼ m pulling down (who) · the kind
#     of push - "all 12 ▾" opens each one's line
#   - MARKET → F&O MOVERS: 🟢 / 🟠 / ⚪ by each share (▲n ▼m in the list views; hover = who) - the 40 biggest movers, every 30 s
#   Restarts the page server (the page shows an error for ~1 minute) - run it before 09:00 or after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 208" $D/home.html && [ -f $D/pushwho.py ] || { echo "patch 208 first"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p214_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p214_patch.py - PATCH 214: PUSHING UP · PULLING DOWN where you see it (Rama, 12 Nov: "what happened to WHO IS PUSHING - and we need WHO IS
PULLING DOWN - I don't see anything on the laptop and the mobile"). The board of patch 208 sat UNDER the share window's chart, chain and
checklist (the laptop) and in the DESK tab (the phone). Now:
  - every share screen, at the TOP (laptop and phone): one line - ▲ N pushing up (who) · ▼ M pulling down (who) · the kind of push -
    tap "all 12 ▾" for each one's line
  - the full board says WHO IS PUSHING IT UP or WHO IS PULLING IT DOWN (by the share's move), up and down counted
  - MARKET → F&O MOVERS: each share shows ▲n ▼m and 🟢 / 🟠 / ⚪ (hover / long-press = who) - the 40 biggest movers, every 30 s
  - dashserve: /pushpull (the 40 biggest movers' push and pull, worked out in the background every 30 s)
Usage: python3 p214_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, marker=None):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s or (marker and marker in s):                    # marker: a later patch (215 / 216) adds inside this block - still "in"
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


# ---- dashserve: /pushpull
rep("dashserve.py", '''            if u.path == "/early":                    # ⚡ EARLY (patch 119)''', '''            if u.path == "/pushpull":                 # patch 214: who is pushing up / pulling down the biggest movers
                return self.send(200, json.dumps(pushpull(), ensure_ascii=False, default=str), "application/json; charset=utf-8")
            if u.path == "/early":                    # ⚡ EARLY (patch 119)''', "/pushpull")
rep("dashserve.py", '''def home(fresh=False):''', '''_PP = {"t": 0.0, "v": {"rows": []}, "busy": False}


def pushpull():
    """patch 214: the 40 biggest F&O movers - who pushes up, who pulls down (pushwho) - worked out in the background every 30 s"""
    if time.time() - _PP["t"] > 30 and not _PP["busy"]:
        _PP["busy"] = True

        def work():
            try:
                import pushwho
                st = json.load(open(os.path.join(BASE, "dash_state.json")))
                fps = sorted([f for f in st.get("fo_paths") or [] if f.get("s") and f.get("chg") is not None], key=lambda f: -abs(f["chg"]))[:40]
                rows = []
                for f in fps:
                    try:
                        p = pushwho.read(f["s"])
                    except Exception:
                        continue
                    rows.append({"s": f["s"], "chg": f["chg"], "dir": p.get("dir"), "kind": p.get("kind"), "kline": (p.get("kline") or "")[:220],
                                 "up": [r["k"] for r in p.get("rows") or [] if r.get("on") and r.get("side", 0) > 0],
                                 "dn": [r["k"] for r in p.get("rows") or [] if r.get("on") and r.get("side", 0) < 0]})
                _PP["v"] = {"rows": rows, "t": time.strftime("%H:%M:%S", time.gmtime(time.time() + 19800))}
            except Exception as ex:
                _PP["v"] = dict(_PP["v"], err=str(ex)[:120])
            finally:
                _PP["t"], _PP["busy"] = time.time(), False
        threading.Thread(target=work, daemon=True).start()
    return _PP["v"]


def home(fresh=False):''', "pushpull() in the background")

# ---- the page
rep("home.html", '''    ${scnRibbon(f.s)}`;
  if(wsWide()) return head+''', '''    ${scnRibbon(f.s)}<div id="ppStrip"></div>`;   /* patch 214: who pushes up · who pulls down - at the top */
  if(wsWide()) return head+''', "the share screen: a place at the top")
rep("home.html", '''    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","chk","oi","oc","list","desk"][i]===FTAB)); }
  const ch=FCH;''', '''    F.querySelectorAll(".tabs span").forEach((e,i)=>e.classList.toggle("on",["chart","chk","oi","oc","list","desk"][i]===FTAB)); }
  { const ps=$("ppStrip"); if(ps){ const h_=ppStrip(); if(ps._h!==h_){ ps._h=h_; ps.innerHTML=h_; } } }   /* patch 214 */
  const ch=FCH;''', "the strip drawn with the share")
rep("home.html", '''function shareInfo(){''', '''/* patch 214: PUSHING UP · PULLING DOWN - the strip on every share screen, the counts on F&O MOVERS */
let PP={}, PPO=false;
function ppLoad(){ fetch("pushpull?k="+encodeURIComponent(K),{cache:"no-store"}).then(r=>r.json()).then(j=>{ const m={}; (j.rows||[]).forEach(x=>m[x.s]=x); PP=m; }).catch(()=>{}); }
setInterval(()=>{ if(!document.hidden) ppLoad(); },30000); setTimeout(ppLoad,2500);
function ppKind(k){ return k==="BOTH"?"🟢🟠":k==="NEW MONEY"?"🟢":k==="FORCED OUT"?"🟠":k==="TIDE ONLY"?"⚪":""; }
function ppBadge(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length)) return "";
  return ` · <i class="ppb" title="${esc("▲ pushing up: "+(r.up.join(", ")||"none")+"\\n▼ pulling down: "+(r.dn.join(", ")||"none")+(r.kline?"\\n"+r.kline:""))}"><span class="pu">▲${r.up.length}</span> <span class="pd">▼${r.dn.length}</span> ${ppKind(r.kind)}</i>`; }
function ppDot(s){ const r=PP[s]; if(!r||!(r.up.length||r.dn.length)) return "";   /* the narrow two-column list: the dot, the counts on hover */
  return `<i class="ppb" title="${esc("▲ "+r.up.length+" pushing up: "+(r.up.join(", ")||"none")+"\\n▼ "+r.dn.length+" pulling down: "+(r.dn.join(", ")||"none")+(r.kline?"\\n"+r.kline:""))}">${ppKind(r.kind)||(r.up.length>=r.dn.length?"▲":"▼")}</i>`; }
function ppStrip(){ const c=FCK&&FCK.s===FOC?FCK:null; const P=c&&c.push&&c.push.rows?c.push:null;
  if(!P){ const r=PP[FOC]; if(!r) return ""; return `<div class="pps"><b>${r.dir==="DOWN"?"WHO IS PULLING IT DOWN":"WHO IS PUSHING IT UP"}</b> <span class="pu">▲ ${r.up.length} up${r.up.length?": "+esc(r.up.join(" · ")):""}</span> <span class="pd">▼ ${r.dn.length} down${r.dn.length?": "+esc(r.dn.join(" · ")):""}</span>${r.kline?` <span class="k">${esc(r.kline)}</span>`:""}</div>`; }
  const on=P.rows.filter(x=>x.on), up=on.filter(x=>x.side>0), dn=on.filter(x=>x.side<0), nt=on.filter(x=>!x.side);
  const kc=P.kind==="FORCED OUT"?"am":P.kind==="TIDE ONLY"?"dim":P.dir==="UP"?"pu":"pd";
  return `<div class="pps"><b>${P.dir==="DOWN"?"WHO IS PULLING IT DOWN":"WHO IS PUSHING IT UP"}</b>
    <span class="pu">▲ ${up.length} pushing up${up.length?": "+up.map(x=>esc(x.k)).join(" · "):""}</span>
    <span class="pd">▼ ${dn.length} pulling down${dn.length?": "+dn.map(x=>esc(x.k)).join(" · "):""}</span>
    ${P.kline?`<span class="k ${kc}">${esc(P.kline)}</span>`:`<span class="k dim">no clear push yet</span>`}
    <a onclick="PPO=!PPO;MKH('ppStrip').innerHTML=ppStrip()">${PPO?"fold ▴":"all 12 ▾"}</a>
    ${PPO?`<div class="ppl">${up.concat(dn,nt).map(x=>`<div><b class="${x.side>0?"pu":x.side<0?"pd":""}">${x.side>0?"▲":x.side<0?"▼":"·"} ${esc(x.k)}</b> ${esc(x.t)}</div>`).join("")}${P.rows.filter(x=>!x.on).length?`<div class="dim">quiet: ${P.rows.filter(x=>!x.on).map(x=>esc(x.k)).join(" · ")}</div>`:""}</div>`:""}</div>`; }
function shareInfo(){''', "the strip and the movers' counts", marker="let PP={}, PPO=false;")
rep("home.html", '''<small>WHO IS PUSHING · ${PW.n_on} of 12 seen${PW.kline?"":" · no clear push"}</small>''',
    '''<small>${PW.dir==="DOWN"?"WHO IS PULLING IT DOWN":"WHO IS PUSHING IT UP"} · ▲ ${PW.rows.filter(x=>x.on&&x.side>0).length} up · ▼ ${PW.rows.filter(x=>x.on&&x.side<0).length} down · ${PW.n_on} of 12 seen${PW.kline?"":" · no clear push"}</small>''',
    "the board says pushing up / pulling down")
rep("home.html", '''${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}</small></div>`; }).join("")}</div>`:'<div class="empty">no share matches</div>'; }''',
    '''${bb?` · <span class="${bb[1]}">${bb[0]}</span>`:""}${r.v?` · desk ${r.v>0?"+":""}${r.v}`:""}${ppBadge(r.s)}</small></div>`; }).join("")}</div>`:'<div class="empty">no share matches</div>'; }''',
    "F&O MOVERS: ▲n ▼m per share")
rep("home.html", '''const cell=r=>r?`<td class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b></td>''',
    '''const cell=r=>r?`<td class="k" onclick="mkOpen('${esc(r.s)}')"><b>${esc(r.s)}</b>${ppDot(r.s)}</td>''', "F&O MOVERS (the two columns): ▲n ▼m")
rep("home.html", '''/* patch 211: alert rows that are links look the same */''', '''/* patch 214: the push / pull strip */
.pps{display:flex;flex-wrap:wrap;gap:4px 12px;align-items:baseline;padding:6px 10px;margin:4px 0;border:1px solid var(--line2);border-radius:6px;background:var(--panel2);font:500 12px/1.45 var(--ui)}
.pps>b{font:700 11px var(--ui);letter-spacing:.08em;color:var(--hi)}.pps .k{flex:1 1 100%;font-weight:600}.pps a{cursor:pointer;color:var(--amber);margin-left:auto}
.pps .ppl{flex:1 1 100%;font-size:11.5px;line-height:1.5}.pps .ppl b{display:inline-block;min-width:100px;font-size:10.5px}
i.ppb{font-style:normal;cursor:help;font-size:10px;margin-left:4px;white-space:nowrap}
/* patch 211: alert rows that are links look the same */''', "the look", marker="/* patch 214: the push / pull strip */")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 214 in")
PY_PATCH
python3 $W/p214_patch.py $D || back
cd $D && python3 -m py_compile dashserve.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
systemctl restart gir-dash && sleep 12 && echo "  gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "=== the 40 biggest movers - who pushes, who pulls (read from the page server)"
TK=$(cat $D/dash_token.txt 2>/dev/null | tr -d '[:space:]')
curl -s "http://127.0.0.1:8090/pushpull?k=$TK" >/dev/null; sleep 20
curl -s "http://127.0.0.1:8090/pushpull?k=$TK" | python3 -c "
import sys, json
try:
    j = json.load(sys.stdin)
except Exception as ex:
    print('   not read:', ex); sys.exit(0)
R = j.get('rows') or []
print('   %d shares%s' % (len(R), (' · error: ' + j['err']) if j.get('err') else ''))
for r in R[:8]:
    print('   %-11s %+6.2f%%  ▲%d %s  ▼%d %s  %s' % (r['s'], r['chg'] or 0, len(r['up']), ','.join(r['up'])[:40], len(r['dn']), ','.join(r['dn'])[:30], r.get('kind') or ''))
"
echo "✅ patch 214 done - Ctrl + Shift + R on GIR (the phone: reload). Tap any share: the push / pull line is at the top."
echo "   undo: for f in dashserve.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
