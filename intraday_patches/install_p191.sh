#!/bin/bash
# PATCH 191 - only what matters rings (Rama, 11 Nov: "lot of alerts ... wasting my time ... no clear cut"):
#   RINGS + the GIR pop-up: trade calls (ENTER NOW · OPENING CALL · a measured BUY · your trade) · 🚨 CRITICAL · regulator action ·
#   a top boss leaving · an order of ₹1,000 cr+ · ⚠️ SHOCK WATCH · PRE-OPEN · MORNING BRIEF. Everything else: on the page, no sound.
#   A fine / tax demand under ₹100 crore never rings. An OI reading must agree with the share's own move (no PE while it rises).
#   ROTATION: 15M · 30M · 1H · TODAY, ⟳ REFRESH, redraws itself every 30 s.
#   Market hours (09:10-15:35): only the page changes (no restart - reload the page). Run it again after 15:35 for the rest.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M); MODE=all
if [ "$H" -ge 0910 ] && [ "$H" -le 1535 ]; then MODE=page; fi
FILES="alertword.py scenarios.py engine2.py shockwatch.py home.html data/scn_config.json"
for f in $FILES; do [ -f $D/$f ] && cp $D/$f $D/$f.bak$TS; done
back(){ for f in $FILES; do [ -f $D/$f.bak$TS ] && cp $D/$f.bak$TS $D/$f; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p191_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p191_patch.py - PATCH 191 (Rama, 11 Nov 12:44: "Lot of alerts since morning. I ended up seeing all the alerts and wasting my time.
There is no clear cut" · "I want a ring and the GIR notification for all critical alerts. When it's possible for me to trade and make
profit. For critical news, for regulatory news" · "it says fine Rs 1 lakh ... and it says shock alert"):
  RINGS (phone + the GIR pop-up + IMPORTANT): trade calls (⚡ ENTER NOW · 🌅 OPENING CALL · a BUY by the measured rule · 🔭 index BUY ·
    your own trade) · 🚨 CRITICAL (news / results / government / filing / GIR down) · regulator action · a top boss leaving ·
    an order of ₹1,000 cr+ · ⚠️ SHOCK WATCH · NIFTY / NEWS SHOCK · 🧱 CIRCUIT · 🌅 PRE-OPEN · ☀️ MORNING BRIEF · 🌙 TOMORROW · 📜 YOUR RULE
  QUIET (still on the page and in Telegram, no sound, no pop-up): 🧩 OI readings that are not a measured BUY · 🚨 SUDDEN ·
    🚀 RUNNING · ⚡ SPEED · single-share gaps · 📰 filings that are not regulator / boss / big order · the lists
  * a fine / penalty / tax demand under ₹100 crore never rings (anywhere: ⚠️, 🚨, 📰)
  * an OI scenario's side must agree with the share's own move (no PE while the share is up, no CE while it is down) - else WAIT
  * "share price going DOWN" was a fixed phrase - now "points DOWN"; the "set risk_rs in data/desk_config.json" text is gone
  * OI scenarios go to Box Picks only as a measured BUY (data/scn_config.json box_when ALL -> BUY), the rest to the quiet digest
  * ROTATION: 15M · 30M · 1H · TODAY buttons, ⟳ REFRESH, and it redraws by itself every 30 s ("updated hh:mm:ss")
Usage: python3 p191_patch.py /home/globalbot/intraday"""
import sys, os, re, json

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
PAGE_ONLY = "--page-only" in sys.argv                      # in market hours: only the page (no restart needed - a reload)
ERR = []


def rd(f):
    return open(os.path.join(D, f), encoding="utf-8").read()


def wr(f, s):
    if PAGE_ONLY and f != "home.html":
        return                                              # market hours: the engine files wait for the full run after 15:35
    open(os.path.join(D, f), "w", encoding="utf-8").write(s)


def rep(f, s, old, new, tag):
    if new in s:
        print("  %s: %s - already in" % (f, tag)); return s
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return s
    print("  %s: %s" % (f, tag))
    return s.replace(old, new)


# ------------------------------------------------------------------ 1 alertword.py - what rings
TIER = r'''# patch 191: Rama 11 Nov - ring ONLY trade calls, critical alerts, regulator news; a small fine never rings
MONEY = re.compile(r"penalt\w*|\bfined\b|\b(?:a|the) fine\b|fine of|demand (?:notice|order)|\b(?:GST|tax|duty|excise|customs|IT) demand|\bdemand of", re.I)
KNOW_RING = re.compile(r"^(🌙 TOMORROW ·|📋 PRE-OPEN|📜 YOUR RULE)")


def amount_cr(s):
    """the largest rupee amount in the text, in crore (0 if none): ₹ / Rs / INR 5 lakh, 2,500 crore, 45,23,000/-"""
    best = 0.0
    for m in re.finditer(r"(?:(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d+)?)\s*(lakhs?|lacs?|crores?|cr\b|million|mn\b|billion|bn\b)?|\b([\d,]+(?:\.\d+)?)/-|\b([\d,]+(?:\.\d+)?)\s*(lakhs?|lacs?|crores?)\b)", s or "", re.I):
        try:
            v = float((m.group(1) or m.group(3) or m.group(4)).replace(",", ""))
        except (ValueError, AttributeError):
            continue
        u = (m.group(2) or m.group(5) or "").lower()
        cr = v / 100 if u.startswith(("lakh", "lac")) else v if u.startswith("cr") else v / 10 if u.startswith(("million", "mn")) else v * 100 if u.startswith(("billion", "bn")) else v / 1e7
        best = max(best, cr)
    return best


def small_money(T):
    """a fine / penalty / tax demand with an amount under ₹100 crore - news, never a shock"""
    if not MONEY.search(T or ""):
        return False
    a = amount_cr(T)
    return 0 < a < 100


def tier(text):
    L = [x for x in (text or "").split("\n") if x.strip()]
    if not L:
        return "read"
    H, T = L[0], "\n".join(L)
    opening, H2, body = _head(L)
    k = H2.split()[0] if H2.split() else ""
    if H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2:   # patch 143: GO before the open / get out - rings loud
        return "act"
    if H2.startswith("⚡ ENTER NOW"):                             # patch 142: the entry BEFORE the move - rings loud
        return "act"
    if k in ("💼", "🛑"):                                       # your own trade
        return "act"
    if "MORNING BRIEF" in H2:                                  # patch 169: the 08:30 brief rings
        return "move"
    if small_money(T):                                         # patch 191: a fine of ₹1 lakh is not a shock
        return "read"
    if "SHOCK WATCH" in H2:                                    # patch 161: ⚠️ rings (trouble / a big jump on an F&O share), 📰 is quiet
        return "move" if H2.startswith("⚠️") else "read"
    if "MARKET ROTATION" in H2 or H2.startswith("🔍 WHY"):
        return "read"
    if re.match(r"🔭 (?:NIFTY|BANKNIFTY) OPTIONS", H2):           # patch 134: the index desk's BUY rings
        return "move" if re.search(r"[▲▼] BUY", H2) else "read"
    if KNOW.match(H2):                                          # patch 191: of the lists only these three ring
        return "know" if KNOW_RING.match(H2) else "read"
    if "NOT SENT" in T and "BUY" not in T:
        return "read"
    m = re.search(r"measured:\s*(\d+)%\s*right of\s*(\d+)", T)
    meas = bool(m and int(m.group(1)) >= 55 and int(m.group(2)) >= 50)
    buy_line = any(re.match(r"(▶\s*)?BUY\b", x.strip()) for x in body) or bool(re.search(r"—\s*BUY\b", H2))
    clean_buy = not opening and "disagrees" not in T and not re.search(r"\bWATCH\b|\bWAIT\b", T)
    if opening and (buy_line or meas):                         # a BUY held back in the opening 15 minutes
        return "move"
    if k == "🧩":                                                # patch 191: an OI reading rings only as a measured BUY
        return "act" if (clean_buy and buy_line) else "read"
    if k == "📰":                                                # patch 191: a filing / story rings only when it is critical
        if not re.search(r"[▲▼]", H2.split("·")[0]):
            return "read"
        if re.search(r"·\s*(REG|REGULATOR|MGMT)\b", H2):
            return "move"
        if re.search(r"·\s*ORDER\b", H2) and amount_cr(T) >= 1000:
            return "move"
        return "read"
    if k == "🌅":                                               # 🌅 PRE-OPEN (09:08) rings; a single gap is a reading
        return "move" if H2.startswith("🌅 PRE-OPEN") else "read"
    if k == "🧱":
        return "move" if "CIRCUIT" in H2 else "read"
    if clean_buy and (buy_line or (k == "🚨" and meas)):
        return "act"
    if k == "🚨":                                               # 🚨 CRITICAL news / results / government / GIR down ring; SUDDEN is a reading
        return "read" if "SUDDEN" in H2 else "move"
    if "NEWS SHOCK" in H2 or "NIFTY SHOCK" in H2 or "MARKET NEWS" in H2:
        return "move"
    return "read"


'''
f = "alertword.py"
s = rd(f)
if "patch 191" in s:
    print("  alertword.py: already in")
else:
    a, b = s.find("def tier(text):"), s.find("\ndef dress(")
    if a < 0 or b < 0:
        ERR.append("alertword.py: tier() / dress() not found")
    else:
        s = s[:a] + TIER + s[b + 1:]
        print("  alertword.py: the new ring rule")
        wr(f, s)

# ------------------------------------------------------------------ 2 scenarios.py - the price must agree, honest words
f = "scenarios.py"
s = rd(f)
s = rep(f, s, '''            rs = ((getattr(self.desk, "rs", {}) or {}).get(sym)) or {}''',
        '''            chg_ = r.get("chg")                                 # patch 191: the share's own move must agree (PE calls on shares going up)
            if chg_ is not None and ((side == "PE" and chg_ > -0.3) or (side == "CE" and chg_ < 0.3)):
                notes.append("the share is %+.1f%% today — not going %s: WAIT" % (chg_, "down" if side == "PE" else "up"))
            rs = ((getattr(self.desk, "rs", {}) or {}).get(sym)) or {}''', "the price must agree")
s = rep(f, s, '''("share price going %s → %s side · the desk: %s" % ("UP" if side == "CE" else "DOWN", side,''',
        '''("points %s → %s side · the desk: %s" % ("UP" if side == "CE" else "DOWN", side,''', "points UP/DOWN (not 'going')")
wr(f, s)

# ------------------------------------------------------------------ 3 engine2.py - no developer text on an alert
f = "engine2.py"
s = rd(f)
s = rep(f, s, '''        return "size: set risk_rs in data/desk_config.json"''',
        '''        return ""                                           # patch 191: no 'set risk_rs in data/desk_config.json' on an alert''', "the size note")
wr(f, s)

# ------------------------------------------------------------------ 4 shockwatch.py - a small fine is not a shock
f = "shockwatch.py"
s = rd(f)
s = rep(f, s, '''    if x.get("known"):
        return False
    if x["side"] < 0 or x.get("circ") or x["reason"] == "REGULATOR":''',
        '''    if x.get("known"):
        return False
    try:                                                     # patch 191: a fine / tax demand under ₹100 crore is not a shock
        import alertword
        if alertword.small_money("%s %s" % (x.get("head") or "", x.get("detail") or "")):
            return False
    except Exception:
        pass
    if x["side"] < 0 or x.get("circ") or x["reason"] == "REGULATOR":''', "small fines never ring")
s = rep(f, s, '''        out.append({"key": "F:" + str(key), "sym": s, "reason": r, "side": side or C.side_of(txt) or -1, "head": (subj or "")[:200],''',
        '''        out.append({"key": "F:" + str(key), "sym": s, "reason": r, "side": side or C.side_of(txt) or -1, "head": (subj or "")[:200], "detail": (det or "")[:600],''', "the filing's amount is read")
wr(f, s)

# ------------------------------------------------------------------ 5 OI scenarios: Box Picks only as a measured BUY
p = os.path.join(D, "data", "scn_config.json")
try:
    cfg = json.load(open(p))
except Exception:
    cfg = {}
if cfg.get("box_when") != "BUY" and not PAGE_ONLY:
    cfg["box_when"] = "BUY"
    json.dump(cfg, open(p, "w"))
    print("  data/scn_config.json: box_when BUY (was ALL)")



# ------------------------------------------------------------------ 6 home.html - the page rings by the same rule, ROTATION controls
f = "home.html"
s = rd(f)
JS_OLD_A = '''  if(k==="🧩") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 123: an OI build-up with a side
  if(k==="📰") return /[▲▼]/.test(H.split("·")[0])?"move":"watch";      // patch 117: a filing / a wire story
  if(/^🌅 OPENING CALL|OPENING CALL FAILED/.test(H)) return "act";      // patch 143: the 09:12 call / get out
  if(/^⚡ ENTER NOW/.test(H)) return "act";      // patch 142: the entry before the move
  if(/MARKET ROTATION/.test(H)) return "move";   // patch 142: the money moving between sectors
  if(k==="🔍"&&/^🔍 WHY/.test(H)) return "watch";      // patch 142: the move explained - on the NOW list, no sound
  if(k==="🌅"||k==="🧱") return /^🌅 GAPS/.test(H)?"watch":"move";      // patch 114: a 5%+ gap / a circuit
  if(k==="💼"||k==="🛑") return "act";
  const opening=/OPENING/.test(T);
  const m=T.match(/measured:\\s*(\\d+)%\\s*right of\\s*(\\d+)/); const meas=m&&+m[1]>=55&&+m[2]>=50;
  const buyLine=L.some(l=>/^(▶\\s*)?BUY\\b/.test(l.trim()))||/—\\s*BUY\\b/.test(H);
  const disagree=/disagrees/.test(T);
  if(!opening&&!disagree&&!/\\bWATCH\\b/.test(T)&&(buyLine||(k==="🚨"&&meas))) return "act";
  if(k==="🚨"||/NEWS SHOCK/.test(H)||/NIFTY SHOCK|MARKET NEWS/.test(H)||(opening&&(buyLine||meas))) return "move";
  if(/RUNNING/.test(H)){ const c=T.match(/crossed\\s*[+-](\\d+)%/); if(c&&+c[1]>=3) return "move"; }
  if(/SPEED/.test(H)){ const d=H.match(/day\\s*([+-]?\\d+(\\.\\d+)?)%/); if(d&&Math.abs(+d[1])>=2) return "move"; }
  return "watch"; }'''
JS_NEW_A = '''  /* patch 191: Rama 11 Nov - ring ONLY trade calls, critical alerts, regulator news (the same rule as alertword.py); a fine under ₹100 cr never rings */
  if(/^🌅 OPENING CALL|OPENING CALL FAILED/.test(H)||/^⚡ ENTER NOW/.test(H)||k==="💼"||k==="🛑") return "act";
  if(/MORNING BRIEF/.test(H)) return "move";
  if(smallMoney(T)) return "watch";
  if(/SHOCK WATCH/.test(H)) return /^⚠️/.test(H)?"move":"watch";
  if(/MARKET ROTATION/.test(H)||/^🔍 WHY/.test(H)) return "watch";
  if(/^🔭 (NIFTY|BANKNIFTY) OPTIONS/.test(H)) return /[▲▼] BUY/.test(H)?"move":"watch";
  if(/^(🎯 THE THREE|🌙 TOMORROW ·|📋 PRE-OPEN|📋 F&O LIST|⚠ the day's|📜 YOUR RULE|ℹ️|🔎 BUILD-UP|🌅 GAPS|🔭 EARLY)/.test(H)) return /^(🌙 TOMORROW ·|📋 PRE-OPEN|📜 YOUR RULE)/.test(H)?"move":"watch";
  const opening=/OPENING/.test(T);
  const m=T.match(/measured:\\s*(\\d+)%\\s*right of\\s*(\\d+)/); const meas=m&&+m[1]>=55&&+m[2]>=50;
  const buyLine=L.some(l=>/^(▶\\s*)?BUY\\b/.test(l.trim()))||/—\\s*BUY\\b/.test(H);
  const cleanBuy=!opening&&!/disagrees/.test(T)&&!/\\bWATCH\\b|\\bWAIT\\b/.test(T);
  if(opening&&(buyLine||meas)) return "move";
  if(k==="🧩") return (cleanBuy&&buyLine)?"act":"watch";
  if(k==="📰"){ if(!/[▲▼]/.test(H.split("·")[0])) return "watch"; if(/·\\s*(REG|REGULATOR|MGMT)\\b/.test(H)) return "move"; if(/·\\s*ORDER\\b/.test(H)&&amountCr(T)>=1000) return "move"; return "watch"; }
  if(k==="🌅") return /^🌅 PRE-OPEN/.test(H)?"move":"watch";
  if(k==="🧱") return /CIRCUIT/.test(H)?"move":"watch";
  if(cleanBuy&&(buyLine||(k==="🚨"&&meas))) return "act";
  if(k==="🚨") return /SUDDEN/.test(H)?"watch":"move";
  if(/NEWS SHOCK|NIFTY SHOCK|MARKET NEWS/.test(H)) return "move";
  return "watch"; }
function amountCr(s){ let best=0; const rx=/(?:(?:rs\\.?|inr|₹)\\s*([\\d,]+(?:\\.\\d+)?)\\s*(lakhs?|lacs?|crores?|cr\\b|million|mn\\b|billion|bn\\b)?|\\b([\\d,]+(?:\\.\\d+)?)\\/-|\\b([\\d,]+(?:\\.\\d+)?)\\s*(lakhs?|lacs?|crores?)\\b)/gi; let m;
  while((m=rx.exec(s||""))){ const v=parseFloat(String(m[1]||m[3]||m[4]||"").replace(/,/g,"")); if(isNaN(v)) continue; const u=String(m[2]||m[5]||"").toLowerCase();
    const cr=/^(lakh|lac)/.test(u)?v/100:/^cr/.test(u)?v:/^(million|mn)/.test(u)?v/10:/^(billion|bn)/.test(u)?v*100:v/1e7; if(cr>best) best=cr; } return best; }
function smallMoney(T){ if(!/penalt\\w*|\\bfined\\b|\\b(?:a|the) fine\\b|fine of|demand (?:notice|order)|\\b(?:GST|tax|duty|excise|customs|IT) demand|\\bdemand of/i.test(T||"")) return false; const a=amountCr(T); return a>0&&a<100; }'''
s = rep(f, s, JS_OLD_A, JS_NEW_A, "the page rings by the same rule")

# ROTATION: the window buttons, refresh, auto-redraw
s = rep(f, s, '''function rotGroups(){ const by={}; (TAPE||[]).forEach(r=>{ if(r.chg!=null) by[r.s]=r; }); const G=[];''',
        '''/* patch 191: ROTATION over a time window - 15M / 30M / 1H / TODAY. The page keeps one price a minute per share (this browser, this
   day, kept across a reload); TODAY = the change from yesterday's close (NSE). ⟳ REFRESH pulls now; it redraws itself every 30 s. */
let RW="day"; try{ RW=localStorage.getItem("gir_rw")||"day"; }catch(e){}
let RH=null, RUPD=0;
function rhLoad(){ if(RH) return RH; const d=new Date(Date.now()+330*60000).toISOString().slice(0,10); try{ const x=JSON.parse(localStorage.getItem("gir_rh")||"null"); if(x&&x.d===d){ RH=x; return RH; } }catch(e){} RH={d,s:[]}; return RH; }
function rhAdd(){ const H=rhLoad(), now=new Date(Date.now()+330*60000), d=now.toISOString().slice(0,10); if(H.d!==d){ H.d=d; H.s=[]; }
  const mn=now.getUTCHours()*60+now.getUTCMinutes(); if(mn<555||mn>930) return; const last=H.s[H.s.length-1]; if(last&&last.m===mn) return;
  const p={}; (TAPE||[]).forEach(r=>{ if(r.s&&r.px) p[r.s]=r.px; }); if(!Object.keys(p).length) return;
  H.s.push({m:mn,p}); while(H.s.length>70) H.s.shift(); try{ localStorage.setItem("gir_rh",JSON.stringify(H)); }catch(e){} }
function rwBase(){ if(RW==="day") return null; const H=rhLoad(); if(!H.s.length) return null; const now=new Date(Date.now()+330*60000), mn=now.getUTCHours()*60+now.getUTCMinutes();
  const want=mn-{"15":15,"30":30,"60":60}[RW]; let b=null; for(const x of H.s){ if(x.m<=want) b=x; } return b||H.s[0]; }
function rwSet(w){ RW=w; try{ localStorage.setItem("gir_rw",w); }catch(e){} drawRot(); }
async function rotRefresh(){ const b=$("rotref"); if(b) b.textContent="⟳ …"; try{ const r=await fetch("home?k="+encodeURIComponent(K),{cache:"no-store"}); if(r.ok) render(await r.json()); }catch(e){} drawRot(); }
setInterval(()=>{ try{ rhAdd(); if(!document.hidden&&typeof VIEW!=="undefined"&&VIEW==="market") drawRot(); }catch(e){} },30000);
function rotGroups(){ const by={}; const B=rwBase(); (TAPE||[]).forEach(r=>{ if(B){ const p0=B.p[r.s]; if(p0&&r.px) by[r.s]=Object.assign({},r,{chg:(r.px/p0-1)*100}); } else if(r.chg!=null) by[r.s]=r; }); const G=[];''',
        "ROTATION: the window")
s = rep(f, s, '''      const si=ix?(((MK&&MK.sidx)||{})[ix]||null):secIdx(x.name); G.push({n,avg,up,dn,cc,ic:si&&si.chg!=null?si.chg:null}); }); });''',
        '''      const si=ix?(((MK&&MK.sidx)||{})[ix]||null):secIdx(x.name); G.push({n,avg,up,dn,cc,ic:(!B&&si&&si.chg!=null)?si.chg:null}); }); });''',
        "ROTATION: the index % only on TODAY")
s = rep(f, s, '''function drawRot(){ const el=$("mk-rot"); if(!el) return; const G=rotGroups();
  if(!G.length){ MKH("mk-rot").innerHTML='<div class="empty">the sectors come with the first prices</div>'; return; }
  const ins=G.filter(g=>g.avg>=0.8&&g.up>=0.7), outs=G.filter(g=>g.avg<=-0.8&&g.dn>=0.7).reverse();''',
        '''function drawRot(){ const el=$("mk-rot"); if(!el) return; rhAdd(); const G=rotGroups(); RUPD=Date.now();
  const B=rwBase(), thr={"day":0.8,"60":0.5,"30":0.35,"15":0.25}[RW]||0.8, nowm=(()=>{ const n=new Date(Date.now()+330*60000); return n.getUTCHours()*60+n.getUTCMinutes(); })();
  const hm=m=>String(Math.floor(m/60)).padStart(2,"0")+":"+String(m%60).padStart(2,"0");
  const short=B&&(nowm-B.m)<({"15":15,"30":30,"60":60}[RW]||0)-2;
  const tb=`<div class="rt">${[["15","15M"],["30","30M"],["60","1H"],["day","TODAY"]].map(([k,t])=>`<a class="${RW===k?"on":""}" onclick="rwSet('${k}')">${t}</a>`).join("")}<a id="rotref" onclick="rotRefresh()" title="pull the prices now">⟳ REFRESH</a><small>${RW==="day"?"since yesterday's close":B?("since "+hm(B.m)+(short?" (this page has watched only since then)":"")):"the page needs a few minutes of prices for this window - showing TODAY"} · auto every 30 s · updated ${new Date(RUPD+330*60000).toISOString().slice(11,19)}</small></div>`;
  if(!G.length){ MKH("mk-rot").innerHTML=tb+'<div class="empty">the sectors come with the first prices</div>'; return; }
  const ins=G.filter(g=>g.avg>=thr&&g.up>=0.7), outs=G.filter(g=>g.avg<=-thr&&g.dn>=0.7).reverse();''',
        "ROTATION: the buttons")
s = rep(f, s, ''':`no rotation by the rule now <small class="dim">(one group +0.8% with 70% of its shares up while another is −0.8% with 70% down)</small>''',
        ''':`no rotation by the rule now <small class="dim">(one group +${thr}% with 70% of its shares up while another is −${thr}% with 70% down)</small>''',
        "ROTATION: the rule for the window")
s = rep(f, s, '''  MKH("mk-rot").innerHTML=`<div class="rs">${st}</div><div class="rc">''',
        '''  MKH("mk-rot").innerHTML=`${tb}<div class="rs">${st}</div><div class="rc">''', "ROTATION: the toolbar on top")
s = rep(f, s, '''#mk-rot .ra{padding:4px 10px;''',
        '''#mk-rot .rt{display:flex;flex-wrap:wrap;gap:4px;align-items:center;padding:5px 10px;border-bottom:1px solid var(--line)}#mk-rot .rt a{cursor:pointer;padding:2px 9px;border:1px solid var(--line);font-size:12px;font-weight:700;color:var(--dim)}#mk-rot .rt a.on{background:var(--amber);color:#000;border-color:var(--amber)}#mk-rot .rt a:hover{color:var(--fg,#fff)}#mk-rot .rt small{color:var(--dim);margin-left:6px}
#mk-rot .ra{padding:4px 10px;''', "ROTATION: the button style")
wr(f, s)

if ERR:
    print("NOT DONE:"); [print("  " + e) for e in ERR]; sys.exit(1)
print("patch 191 written")
PY_PATCH
cat > $D/p191test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p191test.py - PATCH 191: what rings (Python and the page agree), small fines never ring, the scenario price gate, ROTATION controls"""
import os, sys, re, json, subprocess, shutil
B = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, B)
import alertword
FAILS = []


def check(name, good):
    print(("  ok   " if good else "  FAIL ") + name)
    if not good:
        FAILS.append(name)


R, Q = "ring", "quiet"
CASES = [
    # the 11 Nov screenshot: PE readings on shares going up - quiet
    ("🧩 PUT WRITERS RUNNING ▼ CROMPTON ₹220.28 +0.6% · 12:44\n210 PE: OI 10.19 L → 7.61 L, premium ₹1.83 → ₹2.05 since 09:45 — puts writers buying back\n"
     "put writers buying back (OI down, premium up): the floor is giving way — points DOWN → PE side · the desk: EXTREME BEARISH -2\n"
     "WATCH — not a trade yet: the share is +0.6% today — not going down: WAIT\nrule measured: 51% right of 80", Q),
    ("🧩 CALL WRITERS RUNNING ▲ TITAN ₹3500 +1.2% · 10:42\nCE 3600 OI 5.2 L → 3.1 L\n▶ BUY: 3500 CE ₹42 · stop: a close under 3450\nrule measured: 61% right of 120 · scored on: up", R),
    ("🧩 CALL WRITERS RUNNING ▲ TITAN ₹3500 +1.2% · 10:42\nCE 3600 OI 5.2 L → 3.1 L\nWATCH — not a trade yet: the roof ₹3550 is only 1.4% above", Q),
    ("⚡ ENTER NOW ▲ RVNL ₹209 · 09:55\nBUY 210 CE", R),
    ("🌅 OPENING CALL · 09:12\nGO: COCHINSHIP PE", R),
    ("💼 YOUR TRADE · COCHINSHIP 1180 PE · +₹57,820", R),
    ("🚨 CRITICAL GOVT · RBI · 11:02\nRBI cuts the repo rate by 25 bps", R),
    ("🚨 CRITICAL RESULTS ▼ COCHINSHIP · RESULTS · BIG MISS · NSE 16:05:10 (read in 40s)\nprofit -45%", R),
    ("🚨 SUDDEN TATASTEEL ▲ +1.1% in 5 min · 11:20\nEXTREME", Q),
    ("🚀 RUNNING ▲ YESBANK ₹24.3 +3.2% · 10:05\ncrossed +3%", Q),
    ("⚡ SPEED ▲ IREDA day +2.2% · 12:43", Q),
    ("📰 FILING ▼ ASTRAL · REG · NSE 10:00:01 (read in 30s)\nUSFDA warning letter for the Ahmedabad plant", R),
    ("📰 FILING ▼ XYZ · REG · NSE 10:00:01 (read in 30s)\nPenalty of Rs 1,00,000/- imposed by the GST department", Q),
    ("📰 FILING ▼ XYZ · REG · NSE 10:00:01 (read in 30s)\nGST demand order of Rs 45.6 crore with interest and penalty", Q),
    ("📰 FILING ▼ XYZ · REG · NSE 10:00:01 (read in 30s)\nIncome tax demand of Rs 1,250 crore - the company will appeal", R),
    ("📰 FILING ▼ XYZ · MGMT · NSE 10:00:01 (read in 30s)\nthe Managing Director and CEO has resigned", R),
    ("📰 FILING ▲ BHEL · ORDER · NSE 10:00:01 (read in 30s)\nbags an order worth Rs 2,500 crore from NTPC", R),
    ("📰 FILING ▲ KEC · ORDER · NSE 10:00:01 (read in 30s)\norders worth Rs 450 crore", Q),
    ("📰 NEWS ▲ NBCC · ORDER · 10:00\nNBCC wins work order of Rs 300 crore", Q),
    ("⚠️ SHOCK WATCH · ▼ PNB · REGULATOR · NSE filing 22:10\nRBI imposes a penalty of Rs 1 lakh on Punjab National Bank", Q),
    ("⚠️ SHOCK WATCH · ▼ PNB · REGULATOR · NSE filing 22:10\nRBI imposes a monetary penalty of ₹2.5 crore on the bank", Q),
    ("⚠️ SHOCK WATCH · ▼ POLICYBZR · REGULATOR · Google News 10:12\nIRDAI bars Policybazaar from selling new policies", R),
    ("📰 SHOCK WATCH · ▲ KEC · ORDER · Google News 10:12\nKEC bags Rs 400 crore orders", Q),
    ("🌅 PRE-OPEN 09:08 · F&O shares opening with a gap · 2 with news, 1 without\n▼ COCHINSHIP -7.5%", R),
    ("🌅 GAP ▲ WAAREEENER +6.5% · 09:15", Q),
    ("🧱 CIRCUIT ▼ XYZ lower circuit · 10:00", R),
    ("🧱 WALL FLIP ▲ XYZ · 10:00", Q),
    ("☀️ MORNING BRIEF · Wed 11 Nov · since Mon 09 Nov 15:30 · F&O shares\n▼ TROUBLE (2)", R),
    ("🌙 TOMORROW · 5 shares to watch", R),
    ("📜 YOUR RULE · RVNL hit your level", R),
    ("🔎 BUILD-UP · 10:30 · 12 shares", Q),
    ("🔄 MARKET ROTATION · money into PSU BANKS", Q),
    ("🔍 WHY ▲ RVNL +3.9%", Q),
    ("🔭 NIFTY OPTIONS ▲ BUY 25400 CE · 11:00", R),
    ("🔭 NIFTY OPTIONS · reading · 11:00", Q),
    ("📈 NIFTY SHOCK ▼ -1.2% in 10 min", R),
    ("🔔 OPENING · 🧩 CALLS BOUGHT ▲ SBIN ₹800 · 09:20\n▶ BUY: 800 CE", R),
]
for txt, want in CASES:
    got = alertword.tier(txt)
    check("py  %-6s %s" % (want, txt.split("\n")[0][:70]), (got != "read") == (want == R))

# the page: the same rule in home.html (node runs the page's own alertTier)
h = open(os.path.join(B, "home.html"), encoding="utf-8").read()
a = h.find("function alertTier(r)"); b = h.find("/* patch 124: the three channels -")
js = h[a:b]
node = shutil.which("node")
if node:
    prog = js + "\nconst C=" + json.dumps([[t, w] for t, w in CASES], ensure_ascii=False) + ";\n" + \
        "C.forEach(([t,w])=>{ const L=t.split('\\n'); const r={head:L[0],lines:L.slice(1)}; const g=alertTier(r); console.log(((g!=='watch')===(w==='ring')?'ok':'FAIL')+'\\t'+w+'\\t'+g+'\\t'+L[0].slice(0,60)); });"
    out = subprocess.run([node, "-e", prog], capture_output=True, text=True)
    lines = [x for x in out.stdout.splitlines() if x]
    check("page: node ran the page's rule (%s)" % (out.stderr.strip()[:120] or "no error"), len(lines) == len(CASES))
    for x in lines:
        check("page " + x.split("\t", 1)[1].replace("\t", " "), x.startswith("ok"))
else:
    check("node not here - the page's rule read by eye", "smallMoney(T)" in js)

# shockwatch: a small fine never rings, a real regulator action does
import shockwatch
check("SHOCK WATCH: RBI penalty Rs 1 lakh - no ring", not shockwatch.rings({"side": -1, "reason": "REGULATOR", "head": "RBI imposes penalty of Rs 1 lakh on PNB"}))
check("SHOCK WATCH: the amount in the filing's detail is read", not shockwatch.rings({"side": -1, "reason": "REGULATOR", "head": "Disclosure under Regulation 30 - penalty",
                                                                                   "detail": "a penalty of Rs 5,00,000/- was imposed by the Commissioner"}))
check("SHOCK WATCH: IRDAI bars - rings", shockwatch.rings({"side": -1, "reason": "REGULATOR", "head": "IRDAI bars Policybazaar from selling new policies"}))
check("SHOCK WATCH: USFDA warning letter - rings", shockwatch.rings({"side": -1, "reason": "REGULATOR", "head": "USFDA warning letter to Glenmark"}))
check("SHOCK WATCH: tax demand Rs 1,250 crore - rings", shockwatch.rings({"side": -1, "reason": "REGULATOR", "head": "Income tax demand of Rs 1,250 crore on Vedanta"}))

# scenarios: the price gate and the honest words; engine2: no developer text
sc = open(os.path.join(B, "scenarios.py"), encoding="utf-8").read()
check("scenario: PE while the share is up -> WAIT", 'side == "PE" and chg_ > -0.3' in sc and "not going %s: WAIT" in sc)
check("scenario: 'points DOWN' - not 'share price going DOWN'", '"points %s → %s side' in sc and "share price going %s" not in sc)
import importlib
e2 = open(os.path.join(B, "engine2.py"), encoding="utf-8").read()
check("no 'set risk_rs in data/desk_config.json' on an alert", "set risk_rs in data/desk_config.json\"" not in e2)
check("OI scenarios to Box Picks only as a measured BUY", json.load(open(os.path.join(B, "data", "scn_config.json"))).get("box_when") == "BUY")

# ROTATION
check("ROTATION: 15M 30M 1H TODAY + REFRESH + auto 30 s", all(x in h for x in ('["15","15M"]', '["60","1H"]', '["day","TODAY"]', 'onclick="rotRefresh()"', "auto every 30 s", "},30000);")))
print("\n%s" % ("ALL PASSED" if not FAILS else "%d FAILED" % len(FAILS)))
sys.exit(1 if FAILS else 0)
PY_TEST
echo "=== patch 191 ($([ $MODE = page ] && echo 'market hours: the page only' || echo 'everything'))"
if [ $MODE = page ]; then
  python3 $W/p191_patch.py $D --page-only || back
  grep -q "function smallMoney" $D/home.html && grep -q 'onclick="rotRefresh()"' $D/home.html || back
  echo
  echo "✅ the page is done - press Ctrl + Shift + R on GIR:"
  echo "   * pop-ups / IMPORTANT: only trade calls, critical, regulator news (no OI WATCH lines, no small fines)"
  echo "   * ROTATION: 15M · 30M · 1H · TODAY · ⟳ REFRESH · updates by itself every 30 s"
  echo "⏳ Telegram still rings the old way until you run this same command again AFTER 15:35 (the engine restarts then)"
  exit 0
fi
python3 $W/p191_patch.py $D || back
cd $D && python3 -m py_compile alertword.py scenarios.py engine2.py shockwatch.py || back
echo "=== the test"
timeout 120 python3 $D/p191test.py > /tmp/p191test.out 2>&1; R=$?
grep -E "FAIL|PASSED|FAILED" /tmp/p191test.out | head -20
[ $R = 0 ] || back
echo "=== restarting the engine, the filings reader, TV WATCH, the page server (the page shows 502 for up to 2 minutes)"
for s in gir-intraday gir-exchange gir-tvwatch; do systemctl restart $s && echo "  $s restarted"; done
systemctl restart gir-dash
OK=0; for i in $(seq 1 48); do c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 http://127.0.0.1:8090/login); [ "$c" = "200" ] && { OK=1; break; }; echo -n "."; sleep 5; done; echo
sleep 20
for s in gir-intraday gir-exchange gir-tvwatch gir-dash; do echo "  $s: $(systemctl is-active $s)"; done
[ $OK = 1 ] || { echo "the page server did not come back - old files back"; back; }
echo
echo "✅ patch 191 done. From now on your phone rings ONLY for: trade calls · 🚨 critical · regulator news · ⚠️ SHOCK WATCH (no fines under ₹100 cr)."
echo "   Everything else is still on GIR and in Telegram - silently. Ctrl + Shift + R on the page."
