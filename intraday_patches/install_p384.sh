#!/bin/bash
# PATCH 384 - 🧠 GIR ANALYST: A MARKET EXPERT AT GIR'S DESK (Rama, 17 Nov 19:20: "I need someone in GIR who represents the share market - an
#   intelligent AI agent who knows the Indian and global markets, understands what is happening and directs me to the share concerned ...
#   smart and lightning fast, so I can execute in time. Not only the daily news - the sectors building through the night and the day,
#   sector rotation, market news"). analyst.py (service gir-analyst):
#   · every minute 09:15-15:30, and AT ONCE (within ~20 s) on an important AI-read news item, a 🧭 policy story or a 🎯 GIR DECIDES call:
#     the picture GIR already has (NIFTY / BANKNIFTY, the sectors and their 15/30/60-min rotation, the F&O movers and why, futures build-up,
#     the last 45 min of news with the AI's reading, the market desk, the policy map, the good alert types firing, GIR DECIDES, the 07:00
#     list) -> Claude Haiku 5.5 with a market expert's brief and GIR's PROVEN facts -> at most 3 calls: SHARE · CE / PE / WATCH / AVOID /
#     CAUTION · why · NOW or watch. A NOW call needs the price already moving its way AND a second kind of fact. ONLY the facts given.
#   · the page FIRST (the 🧠 box at the top of TRADE NOW: the view, the calls, the move since, the briefing, the record), then Telegram:
#     NOW rings (🧠, its own sound), the rest quiet (📄)
#   · briefings at 07:05 and 19:45 (page + quiet Telegram) · every CE / PE call scored at 15:12 -> the running record on the page
#   · it THINKS IN TRADES: bad news + the price turning = PE (not "avoid"); a market expert's playbook (SEBI curbs -> brokers, promoter
#     selling / "no further sale", results, USFDA, orders, crude, rupee, RBI, duties, sector turns) and each share's own story of the last days
#   · 🏛 THE DESKS (deskteam.py): six specialist agents on Claude Sonnet 5.5 - sectors & rotation, news & policy, money flow (futures
#     build-up + the option chain's PCR / roof / floor), global & macro (the world live), price action (20-day high / low, GIR's tested
#     signals), risk (results, ban, expiry, time, open calls turning) - a note every 3 minutes and at once on a fresh event; the senior
#     expert reads all six before deciding. About ₹500-800 a day, capped at 900 desk readings a day.
#   · 💬 ASK THE ANALYST: a question box on the page - "Angel One: PE now?" - answered within seconds from GIR's live facts, any hour
#   · THE SENIOR EXPERT (Rama, 17 Nov 19:45: "a senior market expert, not a baby"): Claude Fable 5.2, Anthropic's most capable model,
#     decides every call that reaches Rama (the fast Haiku 5.5 watcher only proposes), reads every fresh event itself, answers every
#     question and writes the briefings. If the expert is unavailable, the fast model answers and says so.
#   NOT proven - the record will tell within days. Orders nothing. Cost: the watcher ~₹30 a day; the expert about $5-15 (₹400-1,300) a
#   day, capped at 200 expert readings a day.
#   Adds girdecide.py as a module if patch 382 is not in (its alert reader only - no service). Restarts the dashboard only.
set -u
D=/home/globalbot/intraday; U=/etc/systemd/system; R=/root/sectorbot; B=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); DW=$(TZ=Asia/Kolkata date +%u)
if [ "${1:-}" != "now" ] && [ "$DW" -le 5 ] && [ "$H" -ge 0900 ] && [ "$H" -le 1535 ]; then echo "market hours - run after 15:35 (or: bash $0 now)"; exit 1; fi
if grep -q "patch 384" $D/home.html && grep -q "patch 384" $D/dashserve.py && [ -f $U/gir-analyst.service ]; then echo "patch 384 - already in"; exit 0; fi
grep -q 'id="q-act"' $D/home.html && grep -q 'if u.path == "/cockpitdata":' $D/dashserve.py && grep -q "def remember" $D/newsalert.py || { echo "the TRADE NOW box / dashserve's route / patch 381 not found - nothing done"; exit 1; }
for f in analyst.py deskteam.py girdecide.py alertaudit.py; do git -C $R show $B:intraday_patches/$f > $W/$f 2>/dev/null && [ -s $W/$f ] || { echo "❌ $f not in $B - run the git fetch line first; nothing done"; exit 1; }; done
grep -q "patch 384" $W/analyst.py && grep -q "patch 384" $W/deskteam.py && python3 -m py_compile $W/analyst.py $W/deskteam.py $W/girdecide.py $W/alertaudit.py || { echo "❌ the fetched files are older than this patch or do not compile - nothing done"; exit 1; }
echo "== 1. the test (made-up market in a temp folder; the model and Telegram replaced by stand-ins)"
T=$(mktemp -d); mkdir -p $T/data/secstudy; cp $W/analyst.py $W/deskteam.py $W/girdecide.py $W/alertaudit.py $T/
cat > $T/seclive.py <<'STUB'
def fo_set(): return {"LAURUSLABS", "ANGELONE", "BSE", "UPL", "INFY", "TCS"}
def universe(): return {}, {"ANGELONE": "Angel One Limited", "LAURUSLABS": "Laurus Labs Limited"}
STUB
python3 - $T <<'PY_TEST' || { echo "❌ the test failed - nothing changed"; exit 1; }
import os, sys, json, time, sqlite3, datetime as dt
T = sys.argv[1]; os.chdir(T); sys.path.insert(0, T)
import analyst as A
OK = []
def chk(n, c):
    OK.append(bool(c)); print("  %s %s" % ("✓" if c else "✗", n))
n = A.now(); day = str(n.date()); now = time.time()
json.dump({"idx": {"NIFTY": {"last": 26010.5, "chg": -0.4}, "BANKNIFTY": {"last": 58900, "chg": -0.2}}}, open("dash_state.json", "w"))
json.dump({"t": now, "q": {"LAURUSLABS": [948.0, 3.4], "ANGELONE": [362.0, 1.1], "BSE": [2900.0, -0.5], "UPL": [652.0, 1.9], "INFY": [1500.0, -0.3], "TCS": [3100.0, 0.1]}}, open("quotes_live.json", "w"))
json.dump({"sectors": [{"name": "pharma", "chg": 1.2, "up": 30, "dn": 10, "rot": {"15": 0.3, "30": 0.6, "60": 0.9}, "top": [["LAURUSLABS", 3.4, True]], "bot": []},
                       {"name": "capital markets", "chg": -0.8, "up": 5, "dn": 20, "rot": {"15": -0.4, "30": -1.1, "60": -1.6}, "top": [], "bot": [["ANGELONE", 1.1, True]]}]}, open("data/seclive.json", "w"))
c = sqlite3.connect("news.db"); c.execute("create table items(key text, sym text, src text, domain text, rank int, t_pub real, t_seen real, h text, l text, side int, kind text, cr real, big int, score int, note text)")
c.execute("insert into items values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", ("k", "LAURUSLABS", "WIRE", "cnbctv18.com", 70, now - 120, now - 60, "Laurus Labs gains - Promoter rules out further stake sale", "", 1, "BLOCK", 0, 1, 90, "major wire · AI read: BULLISH")); c.commit(); c.close()
json.dump({"items": [{"t": now - 300, "src": "Business Today", "score": 4, "h": "SEBI mulls limits on margin trading as retail leverage hits record"}]}, open("data/macro.json", "w"))
c = sqlite3.connect("tomorrow.db"); c.execute("create table alerts(day text, t text, kind text, sym text, side text, text text)")
t1 = (n - dt.timedelta(minutes=5)).strftime("%H:%M:%S"); t2 = (n - dt.timedelta(minutes=2)).strftime("%H:%M:%S")
c.execute("insert into alerts values(?,?,?,?,?,?)", (day, t1, "x", "LAURUSLABS", "", "🔔 OPENING ▲ LAURUSLABS")); c.execute("insert into alerts values(?,?,?,?,?,?)", (day, t2, "x", "LAURUSLABS", "", "⚡ SPEED ▲ LAURUSLABS")); c.commit(); c.close()
open("data/alertaudit.txt", "w").write("1c AGREEMENT (✔ types: OPENING, SPEED, FIRST MOVE)\n")
F = A.facts(n)
chk("the picture has the market, the sectors, the movers, the news with the AI's reading, the market desk, the good alerts (%s)" % ", ".join(F),
    all(k in F for k in ("market", "sectors_best", "gainers", "news", "market_news", "good_alerts_last_15min")) and "AI read: BULLISH" in F["news"][0])
seen_user = []
A.ASK = lambda system, user: (seen_user.append(user), json.dumps({"view": "pharma leads, brokers weak on the SEBI story", "calls": [
    {"s": "LAURUSLABS", "act": "CE", "urgency": "now", "why": "promoter rules out more selling (AI: bullish), +3.4%, OPENING + SPEED agree", "confirm": ""},
    {"s": "ANGELONE", "act": "AVOID", "urgency": "now", "why": "SEBI may curb margin trading; brokers falling", "confirm": ""},
    {"s": "NOTFO", "act": "CE", "urgency": "now", "why": "x"}, {"s": "UPL", "act": "BUY", "urgency": "now", "why": "x"}]}))[1]
sent = []; A.SEND = sent.append
st, new = A.reading(why_now="test")
chk("the model is told the facts and only the facts", seen_user and "promoter rules out" in seen_user[0].lower())
chk("calls on shares outside F&O or with an unknown action are dropped (%d kept)" % len(new), [c["s"] for c in new] == ["LAURUSLABS", "ANGELONE"])
chk("AVOID can never be 'act now' (it goes quiet)", next(c for c in new if c["s"] == "ANGELONE")["urgency"] == "watch")
chk("the page file is written before Telegram, each call with its price", os.path.exists(A.OUT) and json.load(open(A.OUT))["calls"][0]["px"] == 948.0)
chk("a NOW call rings as 🧠, the rest quiet as 📄", sent[0].startswith("🧠 GIR ANALYST ▲ LAURUSLABS · CE side · NOW") and sent[1].startswith("📄 GIR ANALYST"))
import alertaudit
chk("the analyst's lines are their own type for the audit (not BUY CE / OPENING ...)", all(alertaudit.kind_of(x) == "GIR ANALYST" for x in sent))
n_sent = len(sent); st, new2 = A.reading(why_now="test again")
chk("the same calls are not sent again within 30 minutes", not new2 and len(sent) == n_sent)
chk("a fresh AI-read news item is a reason to read at once", any("LAURUSLABS" in e for e in A.triggers(now - 600)))
q = json.load(open("quotes_live.json")); q["q"]["LAURUSLABS"] = [960.0, 4.7]; json.dump(q, open("quotes_live.json", "w"))
rows = A.score(n)
chk("the 15:12 score: LAURUSLABS CE +1.27%% its way (%s)" % rows, rows and rows[0]["s"] == "LAURUSLABS" and abs(rows[0]["res"] - 1.27) < 0.01)
chk("the running record on the page", A.view()["record"]["rec"]["now"]["n"] == 1)
A.ASK = lambda system, user: "pharma built up; brokers fell on the SEBI margin story; watch LAURUSLABS at the open"
txt = A.brief(n, "%s 19:45" % day)
chk("the briefing goes to the page and quietly to Telegram", "pharma" in txt and sent[-1].startswith("📄 GIR ANALYST · BRIEFING") and json.load(open(A.OUT))["briefs"][-1]["key"].endswith("19:45"))
# the senior expert decides: the watcher's proposal goes to the expert, who can change it
calls_seen = []
def two(system, user):
    calls_seen.append(user)
    if "junior watcher proposes" in user:                       # the expert turns the junior's AVOID into a PE
        return json.dumps({"view": "brokers turning on the SEBI story", "calls": [{"s": "BSE", "act": "PE", "urgency": "now", "why": "SEBI margin curbs; off its high, capital markets falling", "confirm": ""}]})
    return json.dumps({"view": "x", "calls": [{"s": "BSE", "act": "AVOID", "urgency": "watch", "why": "at high, bad news", "confirm": ""}]})
A.ASK = two; n_before = len(sent)
st, new3 = A.reading(why_now="the minute")
chk("a junior proposal goes to the senior expert, and the expert's decision is what is sent (BSE PE, not AVOID)",
    len(calls_seen) == 2 and new3 and new3[0]["act"] == "PE" and new3[0]["by"] == A.EXPERT and sent[-1].startswith("🧠 GIR ANALYST ▼ BSE · PE side · NOW"))
calls_seen.clear(); A.ASK = lambda system, user: (calls_seen.append(user), json.dumps({"view": "y", "calls": []}))[1]
A.reading(why_now="just now: news on UPL: made-up")
chk("a fresh event goes straight to the senior expert (one reading)", len(calls_seen) == 1)
chk("the expert is Claude Fable 5.2 by default; the watcher Claude Haiku 5.5", A.EXPERT == "claude-fable-5-2" and A.MODEL == "claude-haiku-5-5")
# 🏛 the six desks
import deskteam as DT, numpy as np
c = sqlite3.connect("chains.db"); c.execute("create table chain(d text, t text, sym text, exp text, strike real, kind text, oi real, ltp real, spot real)")
c.execute("create table results_cal(sym text, d text)"); c.execute("insert into results_cal values('UPL', ?)", (day,))
for k, kd, oi in ((25900, "PE", 9e6), (26000, "PE", 4e6), (26000, "CE", 5e6), (26200, "CE", 8e6)):
    c.execute("insert into chain values(?,?,?,?,?,?,?,?,?)", (day, "12:30:00", "NIFTY", day, k, kd, oi, 10, 26010.5))
c.commit(); c.close()
rows = []
for i, d_ in enumerate(range(n.toordinal() - 25, n.toordinal())):
    for b_ in range(3):
        rows.append([d_, 5 * b_, 900, 940 + (i % 3), 880 - (i % 3), 920, 1])
np.save("data/secstudy/LAURUSLABS_2026-11-16.npy", np.array(rows, dtype=float))
json.dump({"ban": ["SAIL"]}, open("data/ban.json", "w"))
DT.world = lambda: ["US Nasdaq futures -0.80%", "Brent crude +2.10% (as of now)"]
X = DT.desk_facts(A.facts(n), n)
chk("each desk gets its own facts: the chain (PCR, roof, floor) for MONEY FLOW", any("NIFTY" in x and "roof (biggest call OI) 26200" in x and "floor (biggest put OI) 25900" in x for x in X["flow"]["option_chain"]))
chk("PRICE ACTION sees LAURUSLABS above its 20-day high (948 > 942)", any(x.startswith("LAURUSLABS") and "ABOVE its 20-day high" in x for x in X["price"]["range_20_days"]))
chk("RISK sees results today, the F&O ban, expiry today; GLOBAL sees the world now", "UPL" in X["risk"]["results_today"] and X["risk"]["fo_ban"] == ["SAIL"] and "TODAY is expiry" in X["risk"]["nifty_expiry"] and X["global"]["world_now"])
asked_desks = []
DT.ASK = lambda desk, system, user: (asked_desks.append(desk), json.dumps({"headline": "%s desk: brokers weak, pharma strong" % desk, "points": ["p1"],
                                       "shares": [{"s": "BSE", "dir": "down", "why": "SEBI margin story"}], "sure": "medium"}))[1]
stD = DT.tick(why="test", n_=n)
chk("all six desks read in parallel, one note each", sorted(asked_desks) == sorted(DT.DESKS) and len(stD["notes"]) == 6)
F2 = A.facts(n)
chk("the senior expert's facts carry the six desk notes", len(F2.get("desk_notes") or []) == 6 and "MONEY FLOW" in " ".join(F2["desk_notes"]))
chk("the page view carries the desks", len(A.view()["desks"]["notes"]) == 6)
chk("the brief says: bad news + the price turning = PE, not 'avoid'; the playbook is in it", "THINK IN TRADES" in A.SYSTEM and "a PE call, NOT" in A.SYSTEM and "MTF" in A.SYSTEM)
r_ = A.ask_q("Angel One: PE now?"); asked = []
A.ASK = lambda system, user: (asked.append(user), "ANGELONE: PE once it keeps falling with capital markets - SEBI may curb margin funding (bearish for brokers).")[1]
A.answer_pending(); qa = A.view()["qa"]
chk("a question from the page is queued and answered (%s)" % r_, r_["ok"] and qa and qa[-1]["a"].startswith("ANGELONE: PE"))
chk("the answer is given the live facts and the share's own story", asked and "ANGELONE" in asked[0] and "asked_about" in asked[0])
print("  %d of %d checks passed" % (sum(OK), len(OK)))
sys.exit(0 if all(OK) else 1)
PY_TEST
rm -rf $T
echo "== 2. the files"
F="dashserve.py home.html"
for f in $F; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in $F; do cp $D/$f.bak$TS $D/$f; done; rm -f $D/analyst.py $D/deskteam.py; systemctl disable --now gir-analyst >/dev/null 2>&1; rm -f $U/gir-analyst.service; systemctl daemon-reload; systemctl restart gir-dash; echo "❌ old files put back - nothing changed"; exit 1; }
cp $W/analyst.py $D/analyst.py && cp $W/deskteam.py $D/deskteam.py || back
[ -f $D/girdecide.py ] || { cp $W/girdecide.py $D/girdecide.py && echo "  girdecide.py added as a module (its alert reader) - patch 382's service is not started"; }
cp $W/alertaudit.py $D/alertaudit.py
cat > $W/home_add.html <<'ADD_384'
<style>/* patch 384: 🧠 GIR ANALYST - the market expert at GIR's desk, at the top of TRADE NOW */
#gxan{margin:0 0 10px;border:2px solid #7c5cff;border-radius:8px;background:#110e24;font:12.5px/1.45 -apple-system,"Segoe UI",Roboto,system-ui,sans-serif;color:#e6edf3;text-align:left}
#gxan .h{padding:7px 10px;border-bottom:1px solid #2a2450;font:800 13px ui-monospace,Menlo,monospace;letter-spacing:.05em;color:#b9a8ff;display:flex;flex-wrap:wrap;gap:8px;align-items:baseline}
#gxan .h small{flex-basis:100%;font:500 11px -apple-system,sans-serif;letter-spacing:0;color:#a3aebf}#gxan .h a{cursor:pointer;font:600 11px -apple-system,sans-serif;color:#c9d4e3}
#gxan .v{padding:6px 10px;border-bottom:1px solid #2a2450;color:#e6edf3;font-weight:600}
#gxan .r{padding:7px 10px;border-bottom:1px solid #1e1a3a}#gxan .r.nw{background:#1d1840}#gxan .a{display:flex;flex-wrap:wrap;gap:7px;align-items:baseline;font:800 13.5px ui-monospace,Menlo,monospace}
#gxan .s{cursor:pointer;text-decoration:underline dotted}#gxan .t{font-weight:500;color:#a3aebf}#gxan .up{color:#26c281}#gxan .dn{color:#f0544f}#gxan .wa{color:#f0b429}#gxan .dim{color:#a3aebf;font-weight:500}
#gxan .w{font:12px/1.4 -apple-system,sans-serif;color:#c9d4e3;margin-top:2px}#gxan .b{padding:7px 10px;border-top:1px solid #2a2450;white-space:pre-wrap;font:12px/1.45 -apple-system,sans-serif;color:#c9d4e3}
#gxan .rec,#gxan .none{padding:6px 10px;color:#a3aebf;font-size:11.5px}
#gxan .dk{padding:6px 10px;border-top:1px solid #2a2450}#gxan .dk a{cursor:pointer;font:700 12px ui-monospace,Menlo,monospace;color:#b9a8ff}#gxan .dk .w{margin-top:4px}
#gxan .ask{display:flex;gap:6px;padding:8px 10px;border-top:1px solid #2a2450}#gxan .ask input{flex:1;min-width:0;background:#0b0a1a;border:1px solid #3a3270;border-radius:5px;color:#e6edf3;padding:7px 8px;font:13px -apple-system,sans-serif}
#gxan .ask button{background:#7c5cff;border:0;border-radius:5px;color:#fff;font:700 12px ui-monospace,Menlo,monospace;padding:0 12px;cursor:pointer}
#gxan .qa{padding:6px 10px;border-top:1px solid #1e1a3a}#gxan .qa .q{color:#b9a8ff;font-weight:600}#gxan .qa .an{white-space:pre-wrap;color:#e6edf3;margin-top:3px;font:12.5px/1.45 -apple-system,sans-serif}
</style>
<script>/* patch 384 (Rama, 17 Nov: "I need someone in GIR who represents the share market ... and directs me to the share concerned, lightning
   fast"): 🧠 GIR ANALYST - an AI reading every minute (and at once on fresh news / policy / GIR DECIDES) what GIR collects, and saying which
   share and which way. NOT proven - its record is shown. data/analyst.json through dashserve /analyst, every 8 s. Its own sound for a NOW call;
   the same call arriving in the ALERTS list does not ring twice. */
(function(){
  const E=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const KEY=()=>{ try{ return new URLSearchParams(location.search).get("k")||""; }catch(e){ return ""; } };
  let V=null, seen=null, played={}, showB=false;
  function snd(){ try{ if(typeof ASND!=="undefined"&&!ASND) return; const vol=(typeof AVOL!=="undefined"?AVOL:1); if(vol<=0) return;
      const A=window.__gxAC||(window.__gxAC=new (window.AudioContext||window.webkitAudioContext)()); if(A.state==="suspended") A.resume();
      const o=(typeof amaster==="function"&&amaster()&&amaster()._g)?amaster():A.destination; const t=A.currentTime+0.03;
      const n=(at,f,d,v,ty)=>{ const x=A.createOscillator(), g=A.createGain(); x.type=ty||"sine"; x.frequency.setValueAtTime(f,at); x.connect(g); g.connect(o);
        g.gain.setValueAtTime(0.0001,at); g.gain.exponentialRampToValueAtTime(v,at+0.01); g.gain.exponentialRampToValueAtTime(0.0001,at+d); x.start(at); x.stop(at+d+0.03); };
      for(let r=0;r<2;r++){ n(t+r*0.8,1760,0.12,0.8,"square"); n(t+r*0.8+0.16,1760,0.12,0.8,"square"); n(t+r*0.8+0.34,1319,0.4,0.8,"triangle"); }   /* two double-pings */
    }catch(e){} }
  window.gxAnalystSound=snd;
  function wrap(){ if(window.__gx384w||typeof window.gxAlarm!=="function") return; window.__gx384w=1; const old=window.gxAlarm;
    window.gxAlarm=function(kind){ const h=String(window.GXRH||""); const m=/GIR ANALYST\s*[▲▼•]?\s*([A-Z0-9&\-]+)/.exec(h);
      if(m){ window.GXRH=""; if(/^📄/.test(h)||/BRIEFING/.test(h)) return; if(Date.now()-(played[m[1]]||0)<120000) return; played[m[1]]=Date.now(); snd(); return; }
      return old.apply(this,arguments); }; }
  function draw(){ const host=document.getElementById("q-act"); if(!host||!V) return; let el=document.getElementById("gxan");
    if(!el){ el=document.createElement("div"); el.id="gxan"; const h3=host.querySelector("h3"); if(h3) h3.after(el); else host.prepend(el);
      el.innerHTML='<div id="gxanm"></div><div class="ask"><input id="gxanq" maxlength="300" placeholder="ask the analyst - e.g. Angel One: PE now? why is pharma up?"><button id="gxanb">ASK</button></div><div id="gxanqa"></div>';
      const go=async()=>{ const i=document.getElementById("gxanq"), q=(i.value||"").trim(); if(q.length<3) return; i.value=""; i.placeholder="asked - the answer comes here in a few seconds";
        try{ await fetch("analystask?k="+encodeURIComponent(KEY())+"&q="+encodeURIComponent(q),{cache:"no-store"}); }catch(e){} let n=0; const f=setInterval(()=>{ pull(); if(++n>20) clearInterval(f); },2000); };
      document.getElementById("gxanb").addEventListener("click",go); document.getElementById("gxanq").addEventListener("keydown",e=>{ if(e.key==="Enter") go(); }); }
    const QA=(V.qa||[]).slice().reverse(); document.getElementById("gxanqa").innerHTML=QA.map(x=>`<div class="qa"><div class="q">${E(x.t.slice(0,5))} you: ${E(x.q)}</div><div class="an">${x.a?E(x.a):"🧠 thinking…"}</div></div>`).join("");
    const today=new Date(Date.now()+19800000).toISOString().slice(0,10), C=(V.day===today?(V.calls||[]):[]).slice().reverse();
    if(seen===null){ seen=new Set(C.map(c=>c.s+c.act+c.t)); }
    let fresh=false; C.forEach(c=>{ const k=c.s+c.act+c.t; if(!seen.has(k)){ seen.add(k); if(c.urgency==="now"){ fresh=true; played[c.s]=Date.now(); } } }); if(fresh) snd();
    const cls=a=>a==="CE"?"up":a==="PE"?"dn":"wa", lab=a=>a==="CE"?"▲ CE":a==="PE"?"▼ PE":a;
    const row=c=>`<div class="r${Date.now()/1000-(c.ts||0)<300?" nw":""}"><div class="a"><span class="t">${E(c.t)}</span><span class="${cls(c.act)}">${lab(c.act)}</span>`+
      `<span class="s" onclick="try{mkOpen('${E(c.s).replace(/'/g,"")}')}catch(e){}">${E(c.s)}</span><span class="dim">${c.urgency==="now"?"NOW":"watch"}</span>`+
      `${c.px?`<span class="dim">at ₹${(+c.px).toFixed(2)}</span>`:""}${c.since!=null?`<span class="${c.since>=0?"up":"dn"}">${c.since>=0?"+":""}${(+c.since).toFixed(2)}% its way since</span>`:""}`+
      `${c.res!=null?`<span class="dim">15:10: ${c.res>=0?"+":""}${(+c.res).toFixed(2)}%</span>`:""}</div><div class="w">${E(c.why)}</div>${c.confirm?`<div class="w dim">confirm: ${E(c.confirm)}</div>`:""}</div>`;
    const vw=(V.views||[]).slice(-1)[0], br=(V.briefs||[]).slice(-1)[0], R=(V.record||{}).rec||{};
    const rec=k=>R[k]?`${R[k].n} calls · ${R[k].avg>=0?"+":""}${R[k].avg}% its way to 15:10 on average · ${R[k].its_way}% went its way`:"none yet";
    document.getElementById("gxanm").innerHTML=`<div class="h">🧠 GIR ANALYST <span class="dim">${V.at?"read "+E(String(V.at).slice(0,5)):""}</span><a onclick="window.gxAnalystSound&&gxAnalystSound()" title="hear the analyst's NOW sound">🔊 TEST</a>`+
      `${br?`<a onclick="window.__gxanB=!window.__gxanB;window.__gxanDraw&&__gxanDraw()">📋 briefing ${E(br.t)}</a>`:""}`+
      `<small>an AI reading GIR's facts every minute and at once on fresh news - which share, which way, why · NOT proven yet: its record is below · the strike, size and stop are your call</small></div>`+
      (vw&&V.day===today?`<div class="v">${E(vw.t)} · ${E(vw.v)}</div>`:"")+
      (C.length?C.slice(0,8).map(row).join(""):`<div class="none">no call yet today</div>`)+
      (window.__gxanB&&br?`<div class="b">${E(br.text)}</div>`:"")+
      (()=>{ const N=((V.desks||{}).notes||[]).filter(x=>x.headline); if(!N.length||(V.desks||{}).day!==today) return "";
        return `<div class="dk"><a onclick="window.__gxanD=!window.__gxanD;window.__gxanDraw&&__gxanDraw()">🏛 THE DESKS (${N.length}) ${window.__gxanD?"▴":"▾"} <span class="dim">${E((V.desks||{}).at||"").slice(0,5)}</span></a>`+
          (window.__gxanD?N.map(x=>`<div class="w"><b>${E(x.name)}</b> <span class="dim">${E(x.t||"")} · sure ${E(x.sure||"")}</span><br>${E(x.headline)}${(x.shares||[]).length?`<br><span class="dim">${x.shares.map(y=>E(y.s)+" "+(y.dir==="up"?"▲":y.dir==="down"?"▼":"?")).join(" · ")}</span>`:""}</div>`).join(""):
           `<div class="w dim">${N.map(x=>E(x.name.split(" ")[0])+" "+E(x.headline)).slice(0,3).join(" · ")}</div>`)+`</div>`; })()+
      `<div class="rec">the record (${E((V.record||{}).days||0)} days) · NOW calls: ${rec("now")} · all CE / PE calls: ${rec("all")}</div>`; }
  window.__gxanDraw=draw;
  async function pull(){ wrap(); try{ const r=await fetch("analyst?k="+encodeURIComponent(KEY()),{cache:"no-store"}); if(r.ok) V=await r.json(); }catch(e){} draw(); }
  setInterval(()=>{ if(!document.hidden) pull(); },8000); setTimeout(pull,1200); })();
</script>
<!-- patch 384 -->
ADD_384
python3 - $D $W <<'PY_EDIT' || back
import os, sys
D, W = sys.argv[1], sys.argv[2]
p = os.path.join(D, "dashserve.py"); s = open(p, encoding="utf-8").read()
A = '            if u.path == "/cockpitdata":'
if "patch 384" not in s:
    if s.count(A) != 1:
        print("❌ dashserve.py: the anchor found %d times" % s.count(A)); sys.exit(1)
    s = s.replace(A, """            if u.path == "/analyst":                  # patch 384: 🧠 GIR ANALYST (read only)
                try:
                    import analyst
                    v_ = analyst.view()
                except Exception:
                    v_ = {"day": None, "calls": []}
                return self.send(200, json.dumps(v_, ensure_ascii=False, default=str).encode(), "application/json; charset=utf-8")
            if u.path == "/analystask":               # patch 384: a question to the analyst (queued; answered within seconds)
                try:
                    from urllib.parse import parse_qs as _pq384
                    import analyst
                    v_ = analyst.ask_q((_pq384(u.query).get("q") or [""])[0])
                except Exception as ex_:
                    v_ = {"ok": False, "err": str(ex_)[:80]}
                return self.send(200, json.dumps(v_, ensure_ascii=False).encode(), "application/json; charset=utf-8")
""" + A, 1)
    open(p, "w", encoding="utf-8").write(s); print("  dashserve.py: /analyst, /analystask")
h = os.path.join(D, "home.html"); t = open(h, encoding="utf-8").read()
if "patch 384" not in t:
    if t.count("</body>") != 1:
        print("❌ home.html: </body> x%d" % t.count("</body>")); sys.exit(1)
    open(h, "w", encoding="utf-8").write(t.replace("</body>", open(os.path.join(W, "home_add.html"), encoding="utf-8").read().strip() + "\n</body>", 1)); print("  home.html: the 🧠 GIR ANALYST box at the top of TRADE NOW")
PY_EDIT
cd $D && python3 -m py_compile dashserve.py analyst.py || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { echo "❌ home.html:"; head -5 $W/js.err; back; }
  echo "  the page code checked ✓"
fi
cd $D && python3 analyst.py once --dry | head -12 || back
cat > $U/gir-analyst.service <<'UNIT'
[Unit]
Description=GIR ANALYST - the AI market expert at GIR's desk (analyst.py, patch 384)
After=network-online.target
[Service]
Type=simple
Nice=5
Restart=always
RestartSec=20
ExecStart=/bin/bash -c 'cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && exec python3 analyst.py run >> data/analyst.log 2>&1'
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable gir-analyst >/dev/null 2>&1 && systemctl restart gir-analyst || back
systemctl restart gir-dash; sleep 6
echo "  gir-analyst: $(systemctl is-active gir-analyst) · gir-dash: $(systemctl is-active gir-dash)"
[ "$(systemctl is-active gir-analyst)" = "active" ] && [ "$(systemctl is-active gir-dash)" = "active" ] || back
echo "✅ patch 384 done - refresh GIR (Ctrl+Shift+R): 🧠 GIR ANALYST sits at the top of TRADE NOW (🔊 TEST for its sound)."
echo "   Tonight 19:45 (if before 20:05) and tomorrow 07:05: a briefing · from 09:15: a reading every minute, at once on fresh news."
echo "   a briefing right now:  cd /home/globalbot && set -a && . ./.env && set +a && cd intraday && python3 analyst.py brief"
echo "   undo: for f in $F; do cp $D/\$f.bak$TS $D/\$f; done; systemctl disable --now gir-analyst; rm $U/gir-analyst.service $D/analyst.py $D/deskteam.py; systemctl daemon-reload; systemctl restart gir-dash"
