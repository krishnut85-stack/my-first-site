#!/bin/bash
# PATCH 385 - 📁 THE READY FILES AND ⚡ BE READY (Rama, 17 Nov 20:00: "for F&O trading we need a lot of information kept ready - what will happen
#   today, tomorrow and in future, based on yesterday, a few days back and today ... build the ready files for all F&O shares. He should wake
#   me up and tell me: hey, be ready, something is happening. Not me asking him.")
#   · readyfile.py (service gir-ready): every evening 19:50 a FILE for every F&O share - the last 5 sessions, the 20-day high / low, the
#     futures money day by day, the option chain's roof / floor / PCR, 7 days of news with the AI's reading, results next / last, the ban -
#     and its OUTLOOK (Claude Sonnet 5.5): bias, why, tomorrow, what to watch, and up to 3 LEVELS that matter, each one of the file's own
#     numbers (else dropped). The MARKET FILE: NIFTY / BANKNIFTY / VIX for 5 days, the sectors, results this week, expiry, ban - the senior
#     expert (Claude Fable 5.2) writes the outlook and picks the shares to be ready for. Refreshed 07:10 for shares with news overnight.
#   · DURING TRADING the file is rewritten AT ONCE when something happens to the share (AI-read news, a 🧭 policy story, a 2%+ move since
#     its file) - "⚡ BE READY · FILE UPDATED" rings with what happened, whether the picture turned, the new levels (Rama, 17 Nov 20:20)
#   · ⚡ BE READY - GIR tells, Rama does not ask: 07:15 "⚡ BE READY TODAY" (rings) · 09:15-15:30 every 15 s a share NEARING (0.4%) or
#     CROSSING a level from its file (a gap at the open counts) rings with the file's why, the catalyst, the news; the 🧠 analyst reads it
#   · THE RING FIX: GIR's ring rule sent 🎯 GIR DECIDES and the 🧠 analyst's NOW calls to Telegram SILENTLY (their first line was not in
#     its list). Now ⚡ BE READY and 🎯 GIR DECIDES ring; a 🧠 NOW call rings as a trade alert; 📄 lines stay quiet.
#   · the page: the ⚡ BE READY box at the top of TRADE NOW (today's alerts, the list, the market outlook, 📁 any share's file)
#   Needs patch 384. About ₹400-600 a night for the files. Restarts the dashboard and the analyst. Orders nothing.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 385" $D/home.html && grep -q "patch 385" $D/alertword.py && [ -f $U/gir-ready.service ]; then echo "patch 385 - already in"; exit 0; fi
grep -q "patch 384" $D/analyst.py 2>/dev/null && [ -f $U/gir-analyst.service ] && [ -f $D/alertword.py ] || { echo "patch 384 (the analyst) first - nothing done"; exit 1; }
for f in readyfile.py analyst.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "patch 385" $W/readyfile.py && grep -q "ready_files" $W/analyst.py && python3 -m py_compile $W/readyfile.py $W/analyst.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
echo "== 1. the test (made-up shares in a temp folder; Kite, the models and Telegram replaced by stand-ins)"
T=$(mktemp -d); mkdir -p $T/data; cp $W/readyfile.py $T/
cat > $T/seclive.py <<'STUB'
def fo_set(): return {"LAURUSLABS", "ANGELONE"}
def universe(): return {"LAURUSLABS": "pharma", "ANGELONE": "capital markets"}, {"LAURUSLABS": "Laurus Labs", "ANGELONE": "Angel One"}
STUB
python3 - $T <<'PY_TEST' || { echo "❌ the test failed - nothing changed"; exit 1; }
import os, sys, json, time, sqlite3, datetime as dt
T = sys.argv[1]; os.chdir(T); sys.path.insert(0, T)
import readyfile as RF
OK = []
def chk(n, c):
    OK.append(bool(c)); print("  %s %s" % ("✓" if c else "✗", n))
IST = RF.IST; n = dt.datetime.now(IST).replace(hour=20, minute=0)
days = []; d = n.date() - dt.timedelta(days=40)
while d <= n.date():
    if d.weekday() < 5: days.append(d)
    d += dt.timedelta(days=1)
daily = {"LAURUSLABS": [[str(x), 898 + i * 0.5, 903 + i * 0.5 + (i % 5), 895 + i * 0.5 - (i % 4), 900 + i * 0.5, 1e6] for i, x in enumerate(days)],
         "ANGELONE": [[str(x), 350, 360, 340, 350 + (i % 3), 1e6] for i, x in enumerate(days)],
         "NIFTY": [[str(x), 26000, 26100, 25900, 26000 + i, 0] for i, x in enumerate(days)]}
c = sqlite3.connect("data/oistudy.db"); c.execute("create table day(d text, sym text, spot real, foi real)")
for i, x in enumerate(days[-6:]):
    c.execute("insert into day values(?,?,?,?)", (str(x), "LAURUSLABS", 900 + i * 3, 1e6 * (1 - 0.02 * i)))
c.commit(); c.close()
c = sqlite3.connect("chains.db"); c.execute("create table chain(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
c.execute("create table results_cal(sym text, d text)"); c.execute("create table fo_list(sym text, lot int)")
c.execute("insert into fo_list values('LAURUSLABS', 1700)"); c.execute("insert into results_cal values('ANGELONE', ?)", (str(RF.next_day(n.date())),))
for k, kd, oi in ((900, "PE", 9e5), (940, "CE", 1e6), (960, "CE", 2e6)):
    c.execute("insert into chain values(?,?,?,?,?,?,?,?,?)", (str(n.date()), "15:25:00", "LAURUSLABS", str(RF.next_day(n.date())), k, kd, oi, 5, 920))
c.commit(); c.close()
c = sqlite3.connect("news.db"); c.execute("create table items(key text, sym text, src text, domain text, rank int, t_pub real, t_seen real, h text, l text, side int, kind text, cr real, big int, score int, note text)")
c.execute("insert into items values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", ("k", "LAURUSLABS", "WIRE", "x", 70, time.time() - 30000, time.time() - 29000, "Laurus Labs promoter rules out further stake sale", "", 1, "BLOCK", 0, 1, 90, "AI read: BULLISH")); c.commit(); c.close()
F = RF.gather("LAURUSLABS", daily["LAURUSLABS"], {"LAURUSLABS": "pharma"}, n)
chk("a file has the last 5 sessions, the 20-day range, the futures money, the chain, the news, results, lot", F and len(F["last5"]) == 5 and F["range20"]["high"] and F.get("futures") and F["options"]["roof"] == 960 and F["news"] and F["lot"] == 1700)
chk("the futures money is read day by day (price up, OI down = short covering)", "short covering" in F["futures"][-1])
hi = F["levels_you_may_use"]["20-day high"]
RF.ASK = lambda kind, system, user: json.dumps({"bias": "up", "summary": "overhang removed; short covering; near the 20-day high", "tomorrow": "CE above the 20-day high",
    "watch": ["pharma"], "catalyst": "promoter rules out more selling",
    "triggers": [{"type": "above", "level": hi, "side": "CE", "say": "20-day high breaks"}, {"type": "above", "level": 999.9, "side": "CE", "say": "made-up"},
                 {"type": "below", "level": 900, "side": "PE", "say": "the put floor"}]}) if kind == "share" else json.dumps({"outlook": "steady; pharma strong",
    "sectors": "lean on pharma", "be_ready": [{"s": "LAURUSLABS", "side": "CE", "why": "overhang gone, at the 20-day high"}, {"s": "NOTAFILE", "side": "CE", "why": "x"}], "events": "ANGELONE results"})
w = RF.write(F)
chk("a level that is not one of the file's own numbers is dropped (999.9); the 20-day high and the put floor kept", [t["level"] for t in w["triggers"]] == [hi, 900.0])
st = RF.build(n_=n, daily=daily)
chk("the files are built for the NEXT trading day, both shares, with the market file", st["for"] == str(RF.next_day(n.date())) and set(st["shares"]) == {"LAURUSLABS", "ANGELONE"} and st["market"]["outlook"])
chk("the BE READY list keeps only shares that have a file", [x["s"] for x in st["market"]["be_ready"]] == ["LAURUSLABS"])
sent = []; RF.SEND = sent.append
m = dt.datetime.combine(dt.date.fromisoformat(st["for"]), dt.time(7, 15), IST)
txt = RF.wake(m)
chk("07:15: ⚡ BE READY TODAY with the outlook, the share, its levels, the events", txt.startswith("⚡ BE READY TODAY") and "LAURUSLABS CE" in txt and "levels: above %s" % hi in txt and "ANGELONE results" in txt)
t9 = dt.datetime.combine(dt.date.fromisoformat(st["for"]), dt.time(9, 20), IST)
out = RF.check(t9, {"LAURUSLABS": [hi * 0.998, 1.0]})
chk("nearing the 20-day high (0.2% under) rings ⚡ BE READY ... NEAR", len(out) == 1 and out[0][0]["kind"] == "near" and sent[-1].startswith("⚡ BE READY ▲ LAURUSLABS · NEAR"))
out = RF.check(t9 + dt.timedelta(minutes=1), {"LAURUSLABS": [hi * 0.998, 1.0]})
chk("the same NEAR is not sent twice", not out)
out = RF.check(t9 + dt.timedelta(minutes=2), {"LAURUSLABS": [hi * 1.003, 1.6]})
chk("crossing it rings ⚡ BE READY ... CROSSED with the file's why and catalyst", len(out) == 1 and out[0][0]["kind"] == "crossed" and "catalyst: promoter rules out" in sent[-1])
RF._save({"day": "x"}, RF.HITS); out = RF.check(t9, {"LAURUSLABS": [hi * 1.01, 2.0]})
chk("a gap through the level at the open counts as crossed (from yesterday's close)", out and out[0][0]["kind"] == "crossed")
v = RF.view("laurusLABS")
chk("📁 a share's file opens on the page", v["file"] and v["file"]["w"]["bias"] == "up")
# DURING TRADING: fresh news rewrites the share's file at once
c = sqlite3.connect("news.db"); c.execute("insert into items values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", ("k2", "LAURUSLABS", "WIRE", "x", 70, time.time() - 30, time.time() - 20,
    "Laurus Labs: USFDA warning letter for Vizag unit", "", -1, "REG", 0, 1, 90, "AI read: BEARISH")); c.commit(); c.close()
json.dump({"q": {"LAURUSLABS": [905.0, -2.4], "ANGELONE": [351.0, 0.2]}}, open("quotes_live.json", "w"))
ev = RF.live_events(time.time() - 120, t9)
chk("fresh AI-read news on a share is an event during trading (and a 2%+ move)", "LAURUSLABS" in ev and ev["LAURUSLABS"].startswith("news: Laurus Labs: USFDA"))
mk_before = json.load(open(RF.FILES))["market"]["outlook"]
RF.ASK = lambda kind, system, user: json.dumps({"bias": "down", "summary": "USFDA warning letter - the overhang story is replaced by a regulatory hit", "tomorrow": "PE below the put floor",
    "watch": ["USFDA details"], "catalyst": "USFDA warning letter", "triggers": [{"type": "below", "level": 900, "side": "PE", "say": "the put floor breaks"}]})
RF._save({"rows": daily}, RF.DAILY)                            # the evening build keeps the day candles here
n_sent = len(sent); out = RF.live_refresh(ev, t9 + dt.timedelta(hours=3))
f2 = json.load(open(RF.FILES))
chk("the file is rewritten AT ONCE (12:20), the market file left as it was", f2["shares"]["LAURUSLABS"]["w"]["bias"] == "down" and f2["market"]["outlook"] == mk_before)
chk("⚡ BE READY · FILE UPDATED rings: what happened, the picture TURNED up → down, the new levels",
    len(sent) == n_sent + 1 and sent[-1].startswith("⚡ BE READY ▼ LAURUSLABS · FILE UPDATED") and "the picture TURNED: up → down" in sent[-1] and "below 900.0" in sent[-1])
chk("the live file carries today's price", (f2["shares"]["LAURUSLABS"].get("today_live") or {}).get("price") == 905.0)
out2 = RF.live_refresh({"LAURUSLABS": "a move: -2.4% today"}, t9 + dt.timedelta(hours=3, minutes=5))
chk("a move alone does not rewrite the same file again within 30 minutes", not out2)
print("  %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
rm -rf $T
echo "== 2. the files"
F="dashserve.py home.html alertword.py analyst.py"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/readyfile.py; systemctl disable --now gir-ready >/dev/null 2>&1; rm -f $U/gir-ready.service; systemctl daemon-reload; systemctl restart gir-dash gir-analyst; echo "❌ old files put back - nothing changed"; exit 1; }
cp $W/readyfile.py $D/readyfile.py && cp $W/analyst.py $D/analyst.py || back
python3 - $D <<'PY_RING' || back
import os, sys
D = sys.argv[1]; p = os.path.join(D, "alertword.py"); s = open(p, encoding="utf-8").read()
if "patch 385" in s:
    sys.exit(0)
NEW = '''    if re.match(r"⚡ BE READY|🎯 GIR DECIDES [▲▼]", H2):                     # patch 385: BE READY and GIR DECIDES ring (they were sent silently)
        return "move"
    if re.match(r"🧠 GIR ANALYST .*· NOW", H2):                                 # patch 385: the analyst's NOW call is a trade alert
        return "act"
'''
for A in ('''    if H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2:''', '''    if k in ("💼", "🛑"):'''):
    if s.count(A) == 1:
        s = s.replace(A, NEW + A, 1); open(p, "w", encoding="utf-8").write(s); print("  alertword.py: ⚡ BE READY / 🎯 GIR DECIDES / 🧠 NOW ring"); sys.exit(0)
print("❌ alertword.py: its ring rule's lines were not found - nothing done"); sys.exit(1)
PY_RING
cd $D && python3 -m py_compile alertword.py && python3 - <<'PY_RINGTEST' || back
import os, sys
sys.path.insert(0, os.getcwd())
import alertword as A
ok = True
for txt, want in (("⚡ BE READY ▲ LAURUSLABS · CROSSED 942.0 (20-day high) · 09:31\n₹944", "move"), ("🎯 GIR DECIDES ▲ UPL · CE side · 09:31\nagreed: ...", "move"),
                  ("🧠 GIR ANALYST ▼ ANGELONE · PE side · NOW · 13:01\nwhy: ...", "act"), ("📄 GIR ANALYST • BSE · WATCH · watch · 13:01\nwhy", "read"), ("⚡ BE READY TODAY · Wed 18 Nov\n...", "move")):
    t = A.tier(txt); good = t == want; ok = ok and good
    try:
        dressed, silent = A.dress(txt)
    except Exception as ex:
        silent = "?(%s)" % ex
    print("  %s %-34s rule: %-4s · the phone: %s" % ("✓" if good else "✗", txt.split("\n")[0][:34], t, "silent" if silent is True else "RINGS" if silent is False else silent))
sys.exit(0 if ok else 1)
PY_RINGTEST
cat > $W/home_add.html <<'ADD_385'
<style>/* patch 385: ⚡ BE READY - the ready files tell Rama, at the top of TRADE NOW */
#gxrd{margin:0 0 10px;border:2px solid #26c281;border-radius:8px;background:#0a1712;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3;text-align:left}
#gxrd .h{padding:7px 10px;border-bottom:1px solid #18382b;font:800 13px ui-monospace,Menlo,monospace;letter-spacing:.05em;color:#26c281;display:flex;flex-wrap:wrap;gap:8px;align-items:baseline}
#gxrd .h small{flex-basis:100%;font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf}#gxrd .h a{cursor:pointer;font:600 11px -apple-system,sans-serif;color:#c9d4e3}
#gxrd .r{padding:6px 10px;border-bottom:1px solid #12291f}#gxrd .r.nw{background:#123324}#gxrd .a{display:flex;flex-wrap:wrap;gap:7px;align-items:baseline;font:800 13px ui-monospace,Menlo,monospace}
#gxrd .s{cursor:pointer;text-decoration:underline dotted}#gxrd .up{color:#26c281}#gxrd .dn{color:#f0544f}#gxrd .dim{color:#a3aebf;font-weight:500}#gxrd .w{font:12px/1.4 -apple-system,sans-serif;color:#c9d4e3;margin-top:2px}
#gxrd .mk{padding:6px 10px;border-bottom:1px solid #18382b;white-space:pre-wrap}#gxrd .f{display:flex;gap:6px;padding:7px 10px;border-top:1px solid #18382b}
#gxrd .f input{flex:1;min-width:0;background:#06100c;border:1px solid #1f4a37;border-radius:5px;color:#e6edf3;padding:6px 8px;font:13px ui-monospace,Menlo,monospace;text-transform:uppercase}
#gxrd .f button{background:#1f7a55;border:0;border-radius:5px;color:#fff;font:700 12px ui-monospace,Menlo,monospace;padding:0 12px;cursor:pointer}#gxrd .fl{padding:6px 10px;border-top:1px solid #12291f;white-space:pre-wrap;font:12px/1.45 -apple-system,sans-serif}
</style>
<script>/* patch 385 (Rama, 17 Nov: "He should wake me up and tell me: hey, be ready, something is happening. Not me asking him."): ⚡ BE READY -
   today's level alerts from the ready files (newest first), the morning BE READY list, the market outlook, and 📁 any share's file.
   data/ready through dashserve /ready and /readyfile, every 8 s. Its own sound; the same alert in the ALERTS list does not ring twice. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let V=null, seen=null, played={}, FILE=null, showMk=false;
  function snd(){ try{ if(typeof ASND!=="undefined"&&!ASND) return; const vol=(typeof AVOL!=="undefined"?AVOL:1); if(vol<=0) return;
      const A=window.__gxAC||(window.__gxAC=new (window.AudioContext||window.webkitAudioContext)()); if(A.state==="suspended") A.resume();
      const o=(typeof amaster==="function"&&amaster()&&amaster()._g)?amaster():A.destination; const t=A.currentTime+0.03;
      const n=(at,f,d,v,ty)=>{ const x=A.createOscillator(), g=A.createGain(); x.type=ty||"sine"; x.frequency.setValueAtTime(f,at); x.connect(g); g.connect(o);
        g.gain.setValueAtTime(0.0001,at); g.gain.exponentialRampToValueAtTime(v,at+0.01); g.gain.exponentialRampToValueAtTime(0.0001,at+d); x.start(at); x.stop(at+d+0.03); };
      for(let r=0;r<3;r++){ [660,880,1100,1320].forEach((f,i)=>n(t+r*0.9+i*0.09,f,0.12,0.8,"square")); }      /* three quick rising runs: be ready */
    }catch(e){} }
  window.gxReadySound=snd;
  function wrap(){ if(window.__gx385w||typeof window.gxAlarm!=="function") return; window.__gx385w=1; const old=window.gxAlarm;
    window.gxAlarm=function(kind){ const h=String(window.GXRH||""); const m=/⚡ BE READY\s*[▲▼]?\s*([A-Z0-9&\-]+)/.exec(h);
      if(m){ window.GXRH=""; if(Date.now()-(played[m[1]]||0)<60000) return; played[m[1]]=Date.now(); snd(); return; }
      return old.apply(this,arguments); }; }
  async function openFile(sym){ sym=String(sym||"").trim().toUpperCase(); if(!sym) return; try{ const r=await fetch("readyfile?k="+encodeURIComponent(KEY())+"&s="+encodeURIComponent(sym),{cache:"no-store"}); FILE=r.ok?await r.json():null; }catch(e){ FILE=null; } FILE=FILE||{}; FILE.__s=sym; draw(); }
  window.gxReadyOpen=openFile;
  function fileText(f){ if(!f||!f.file) return `no file for ${E(FILE&&FILE.__s||"")} yet - the files are made at 19:50`; const x=f.file, w=x.w||{};
    return `📁 ${E(x.s)} ${x.name?"· "+E(x.name):""} · ${E(x.sector||"")}${x.lot?" · lot "+E(x.lot):""} · made ${E(x.made||"")}\n`+
      `BIAS ${E((w.bias||"").toUpperCase())} · ${E(w.summary||"")}\nTOMORROW: ${E(w.tomorrow||"-")}\n`+
      ((w.triggers||[]).length?"LEVELS: "+w.triggers.map(t=>`${t.type} ${t.level} (${E(t.name)}) → ${t.side}: ${E(t.say)}`).join(" · ")+"\n":"")+
      ((w.watch||[]).length?"WATCH: "+w.watch.map(E).join(" · ")+"\n":"")+(w.catalyst?"CATALYST: "+E(w.catalyst)+"\n":"")+
      `LAST 5: ${(x.last5||[]).map(E).join(" | ")}\n20-DAY: high ${E((x.range20||{}).high)} · low ${E((x.range20||{}).low)}\n`+
      ((x.futures||[]).length?"FUTURES: "+x.futures.map(E).join(" | ")+"\n":"")+(x.options?`OPTIONS (${E(x.options.as_of)}): roof ${E(x.options.roof)} · floor ${E(x.options.floor)} · PCR ${E(x.options.pcr)}\n`:"")+
      `RESULTS: next ${E(x.results_next||"-")} · last ${E(x.results_last||"-")}${x.in_fo_ban?" · ⚠ IN F&O BAN":""}\n`+((x.news||[]).length?"NEWS: "+x.news.map(E).join(" | "):""); }
  function draw(){ const host=document.getElementById("q-act"); if(!host||!V) return; let el=document.getElementById("gxrd");
    if(!el){ el=document.createElement("div"); el.id="gxrd"; const h3=host.querySelector("h3"); if(h3) h3.after(el); else host.prepend(el);
      el.innerHTML='<div id="gxrdm"></div><div class="f"><input id="gxrdq" maxlength="20" placeholder="📁 a share\'s file - e.g. LAURUSLABS"><button id="gxrdb">OPEN</button></div><div id="gxrdf"></div>';
      document.getElementById("gxrdb").addEventListener("click",()=>openFile(document.getElementById("gxrdq").value));
      document.getElementById("gxrdq").addEventListener("keydown",e=>{ if(e.key==="Enter") openFile(e.target.value); }); }
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10), Hh=(V.hits||[]).slice().reverse(), mk=V.market||{}, mine=V.for===today;
    if(seen===null){ seen=new Set(Hh.map(h=>h.s+h.kind+h.level)); }
    let fresh=false; Hh.forEach(h=>{ const k=h.s+h.kind+h.level; if(!seen.has(k)){ seen.add(k); fresh=true; played[h.s]=Date.now(); } }); if(fresh) snd();
    const row=h=>`<div class="r${Date.now()/1000-(h.ts||0)<300?" nw":""}"><div class="a"><span class="dim">${E(h.t)}</span><span class="${h.side==="CE"?"up":h.side==="PE"?"dn":"dim"}">${h.side==="CE"?"▲":h.side==="PE"?"▼":"•"} ${E(h.side)}</span>`+
      `<span class="s" onclick="window.gxReadyOpen&&gxReadyOpen('${E(h.s).replace(/'/g,"")}')">${E(h.s)}</span><span>${h.kind==="updated"?"FILE UPDATED":h.kind==="crossed"?"CROSSED "+E(h.level):"near "+E(h.level)}</span><span class="dim">${E(h.name)}${h.px?" · ₹"+E(h.px):""}</span></div></div>`;
    document.getElementById("gxrdm").innerHTML=`<div class="h">⚡ BE READY <span class="dim">${Hh.length} today</span><a onclick="window.gxReadySound&&gxReadySound()">🔊 TEST</a>`+
      `${mine&&mk.outlook?`<a onclick="window.__gxrdMk=!window.__gxrdMk;window.__gxrdDraw&&__gxrdDraw()">🌐 market file ${window.__gxrdMk?"▴":"▾"}</a>`:""}`+
      `<small>the ready files (${E(V.n||0)} shares, made ${E(V.made||"-")}) ring when a share nears or crosses a level that matters - GIR tells you; the strike, size and stop are your call</small></div>`+
      (window.__gxrdMk&&mine?`<div class="mk">🌐 ${E(mk.outlook||"")}\n🧭 ${E(mk.sectors||"")}\n📅 ${E(mk.events||"")}</div>`:"")+
      (Hh.length?Hh.slice(0,10).map(row).join(""):"")+
      (mine&&(mk.be_ready||[]).length?`<div class="r"><div class="w"><b>today's list:</b> ${mk.be_ready.map(x=>`<span class="s" onclick="window.gxReadyOpen&&gxReadyOpen('${E(x.s)}')">${x.side==="CE"?"▲":x.side==="PE"?"▼":"•"} ${E(x.s)}</span> <span class="dim">${E(x.why)}</span>`).join(" · ")}</div></div>`:
        (!Hh.length?`<div class="r dim">${mine?"nothing near a level yet":"the files for today are made at 19:50 the evening before and refreshed at 07:10"}</div>`:""));
    document.getElementById("gxrdf").innerHTML=FILE?`<div class="fl">${fileText(FILE)}</div>`:""; }
  window.__gxrdDraw=draw;
  async function pull(){ wrap(); try{ const r=await fetch("ready?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} draw(); }
  setInterval(()=>{ if(!document.hidden) pull(); },8000); setTimeout(pull,1000); })();
</script>
<!-- patch 385 -->
ADD_385
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 385" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path in ("/ready", "/readyfile"):    # patch 385: ⚡ BE READY and 📁 a share's ready file (read only)
                try:
                    from urllib.parse import parse_qs as _pq385
                    import readyfile
                    v_ = readyfile.view((_pq385(u.query).get("s") or [None])[0] if u.path == "/readyfile" else None)
                except Exception:
                    v_ = {"for": None, "hits": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /ready, /readyfile")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 385" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the ⚡ BE READY box at the top of TRADE NOW")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py readyfile.py analyst.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cat > $U/gir-ready.service <<'UNIT'
[Unit]
Description=GIR ready files + BE READY (readyfile.py, patch 385)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && exec python3 readyfile.py run >> data/ready.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-ready >/dev/null 2>&1 && systemctl restart gir-ready gir-analyst || back
systemctl restart gir-dash; sleep 6
echo "  gir-ready: $(systemctl is-active gir-ready) · gir-analyst: $(systemctl is-active gir-analyst) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-ready)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 385 done - refresh GIR (Ctrl+Shift+R): ⚡ BE READY sits at the top of TRADE NOW (🔊 TEST for its sound)."
echo "   Tonight (19:50-21:30 on market days) the files are built for tomorrow - about 5-10 minutes; 07:10 refresh; 07:15 ⚡ BE READY TODAY rings."
echo "   to watch the build: tail -f $D/data/ready.log   ·   one file: cd $D && python3 readyfile.py show LAURUSLABS"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-ready; rm $U/gir-ready.service $D/readyfile.py; systemctl daemon-reload; systemctl restart gir-dash gir-analyst"
