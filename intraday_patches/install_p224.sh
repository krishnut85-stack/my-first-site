#!/bin/bash
# PATCH 224 - P1 AND CRITICAL IN THEIR OWN SOUNDS (Rama, 12 Nov: "the P1 alerts and the critical alerts should be in a different sound - like an
#   ambulance sound").
#   Telegram: every 🔴 P1 call + the EXIT WATCH (🎯 BOOK HALF / 🛑 EXIT / ⏰ TIME EXIT) -> GIR TRADE NOW (give it the AMBULANCE sound) ·
#             🚨 critical -> GIR Box Picks (give it the NEE-NAW sound). The two sounds are sent to those channels by this script, ready to save.
#   The page: P1 + exits = an ambulance wail + yelp · critical / circuit = a two-tone nee-naw · 🔊 P1 / 🔊 CRITICAL test buttons.
#   Tested: the routing 8 cases, the page's sounds. Restarts the senders - run it after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; R=/root/sectorbot; BR=origin/ccr-67e340f1-sko8xd; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
for f in tglanes.py home.html; do cp $D/$f $D/$f.bak$TS; done
SV="gir-intraday gir-exchange gir-desk gir-newsroom gir-tvwatch gir-newshunt"
back(){ for f in tglanes.py home.html; do cp $D/$f.bak$TS $D/$f; done; for s in $SV; do systemctl restart $s 2>/dev/null; done; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p224_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p224_patch.py - PATCH 224: P1 AND CRITICAL IN THEIR OWN SOUNDS (Rama, 12 Nov: "the P1 alerts and the critical alerts should be in a different
sound - like an ambulance sound").
  Telegram - every 🔴 P1 call (GO, ENTER NOW, Box Pick, opening call, measured BUY) and the EXIT WATCH's 🎯 BOOK HALF / 🛑 EXIT / ⏰ TIME EXIT
             go to GIR TRADE NOW (patch 153's channel, once TG_CHAT_TRADENOW is set) -> give it the AMBULANCE sound; 🚨 critical stays in
             GIR Box Picks -> give it the NEE-NAW sound. Not set: everything stays in Box Picks, as today.
  the page - P1 and the exits: an ambulance wail + yelp (~4.6 s) · critical / circuit: a two-tone nee-naw · the rest: 3 rising tones as now ·
             🔊 P1 and 🔊 CRITICAL test buttons
Usage: python3 p224_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
ERR = []


def rep(f, old, new, tag, marker=None):
    p = os.path.join(D, f); s = open(p, encoding="utf-8").read()
    if new in s or (marker and marker in s):
        print("  %s: %s - already in" % (f, tag)); return
    if s.count(old) != 1:
        ERR.append("%s: anchor '%s' found %d times" % (f, tag, s.count(old))); return
    open(p, "w", encoding="utf-8").write(s.replace(old, new)); print("  %s: %s" % (f, tag))


rep("tglanes.py", '''    return H2.startswith("⚡ ENTER NOW") or H2.startswith("🟢 GO") or H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2 or k in ("💼", "🛑")''',
    '''    if re.search(r"🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT", H2):        # patch 224: the exit watch - with the entries, in the ambulance channel
        return True
    try:                                                         # patch 224: every 🔴 P1 call
        import alertword as _aw
        if _aw.tier(text) == "act":
            return True
    except Exception:
        pass
    return H2.startswith("⚡ ENTER NOW") or H2.startswith("🟢 GO") or H2.startswith("🌅 OPENING CALL") or "OPENING CALL FAILED" in H2 or k in ("💼", "🛑")''',
    "every P1 + the exits -> GIR TRADE NOW")
rep("home.html", '''function alarm(kind){ if(!ASND||AVOL<=0) return; try{ acUnlock(); amaster()._g.gain.value=2.4*AVOL; const t0=AC.currentTime+0.02, v=1.0;
  if(kind==="act"){ for(let r=0;r<3;r++){ for(let i=0;i<4;i++){ tone(t0+r*1.1+i*0.22,i%2?1319:988,0.2,v); } } }      // TRADE ALERT: hi-lo siren x 3 (about 3 s)''',
    '''function sweep(t,f1,f2,dur,vol){ const o=AC.createOscillator(), o2=AC.createOscillator(), g=AC.createGain(); o.type="square"; o2.type="sawtooth";   /* patch 224 */
  o.frequency.setValueAtTime(f1,t); o.frequency.linearRampToValueAtTime(f2,t+dur); o2.frequency.setValueAtTime(f1*2,t); o2.frequency.linearRampToValueAtTime(f2*2,t+dur);
  o.connect(g); o2.connect(g); g.connect(amaster()); g.gain.setValueAtTime(0.0001,t); g.gain.exponentialRampToValueAtTime(Math.max(0.001,vol),t+0.01); g.gain.setValueAtTime(vol,t+dur-0.01); g.gain.exponentialRampToValueAtTime(0.0001,t+dur+0.01);
  o.start(t); o2.start(t); o.stop(t+dur+0.03); o2.stop(t+dur+0.03); }
function alarm(kind){ if(!ASND||AVOL<=0) return; try{ acUnlock(); amaster()._g.gain.value=2.4*AVOL; const t0=AC.currentTime+0.02, v=1.0;
  if(kind==="act"){ for(let r=0;r<2;r++){ sweep(t0+r*1.4,650,1550,0.7,v); sweep(t0+r*1.4+0.7,1550,650,0.7,v); } for(let i=0;i<8;i++) sweep(t0+2.8+i*0.22,650,1550,0.22,v); }   // patch 224 P1: AMBULANCE wail + yelp (~4.6 s)
  else if(kind==="crit"){ for(let i=0;i<8;i++) tone(t0+i*0.45,i%2?770:960,0.43,v); }                                   // patch 224 CRITICAL: two-tone nee-naw (~3.6 s)''',
    "the page: the ambulance (P1) and the nee-naw (critical)")
rep("home.html", '''ring=Math.max(ring,(tr==="act"||/CIRCUIT/.test(r.head||"")||/CRITICAL/.test(r.head||"")||alertLane(r)==="critical")?2:1);''',
    '''ring=Math.max(ring,(tr==="act"||/🛑 EXIT|🎯 BOOK HALF|⏰ TIME EXIT/.test(r.head||""))?3:(/CIRCUIT/.test(r.head||"")||/CRITICAL/.test(r.head||"")||alertLane(r)==="critical")?2:1);''',
    "the page: P1 + exits = 3, critical = 2")
rep("home.html", '''if(ring){ beep(ring===2?3:1,ring===2?988:660); try{ if(navigator.vibrate&&(!navigator.userActivation||navigator.userActivation.hasBeenActive)) navigator.vibrate(ring===2?[200,100,200,100,200]:[150]); }''',
    '''if(ring){ alarm(ring===3?"act":ring===2?"crit":"move"); try{ if(navigator.vibrate&&(!navigator.userActivation||navigator.userActivation.hasBeenActive)) navigator.vibrate(ring===3?[700,150,700,150,700]:ring===2?[200,100,200,100,200]:[150]); }''',
    "the page: each level its own sound and buzz")
rep("home.html", '''<a onclick="alarm('act')" title="play the TRADE ALERT sound">🔊 TEST</a>''',
    '''<a onclick="alarm('act')" title="play the P1 sound (the ambulance)">🔊 P1</a><a onclick="alarm('crit')" title="play the CRITICAL sound (nee-naw)">🔊 CRITICAL</a>''',
    "the page: two test buttons")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 224 in")
PY_PATCH
python3 $W/p224_patch.py $D || back
cd $D && python3 -m py_compile tglanes.py || back
echo "=== test: where each alert goes"
python3 - <<'PY' || back
import sys; sys.path.insert(0, "/home/globalbot/intraday")
import tglanes as T
cases = [("🟢 GO · SWIGGY ▲ CE · 09:16\nBUY: 300 CE ₹8", True), ("🎯 BOX PICK ▲ UNIONBANK\nBUY: 205 CE ₹4.48 · stop: a close under 200", True),
         ("🚨 CRITICAL · 🛑 EXIT - STOP · UNIONBANK 205 CE · 13:50\nwhy: ...", True), ("🚨 CRITICAL · 🎯 BOOK HALF · PNB 141 CE · 13:25", True),
         ("🚨 CRITICAL · PROFIT BOOKING ▼ CHOLAFIN · 10:38\nwas ...", False), ("🧱 CIRCUIT ▼ PAGEIND ₹32915 · AT THE LOWER CIRCUIT", False),
         ("🚀 RUNNING ▼ PAGEIND ₹35825 -2.0%", False), ("🧩 CALL WRITERS RUNNING ▲ ITC\n▶ WATCH CE 400", False)]
bad = 0
for t, want in cases:
    got = T.trade_now(t); bad += got != want
    print("  %s %-58s -> %s" % ("✅" if got == want else "❌", t.split("\n")[0][:58], "GIR TRADE NOW · ambulance" if got else "its own lane"))
sys.exit(1 if bad else 0)
PY
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
for s in $SV; do systemctl restart $s 2>/dev/null; done
sleep 8; for s in $SV; do echo "  $s: $(systemctl is-active $s)"; done
echo "=== the two sounds -> Telegram (ready to save as notification sounds)"
mkdir -p $D/data/sounds
for f in gir_p1_ambulance.mp3 gir_critical_alarm.mp3; do (cd $R && git show $BR:intraday_patches/sounds/$f > $D/data/sounds/$f) || echo "  $f not fetched - run the git fetch line first"; done
python3 - $D/data/sounds <<'PY'
import os, re, sys, uuid, json, urllib.request
S = sys.argv[1]
env = {}
for line in open("/home/globalbot/.env"):
    m = re.match(r"\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$", line)
    if m:
        env[m.group(1)] = m.group(2).strip("'\"")
tok = env.get("TELEGRAM_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
tn, box = env.get("TG_CHAT_TRADENOW"), env.get("TG_CHAT_BOX")
print("  GIR TRADE NOW channel: %s" % ("set" if tn else "NOT SET - P1 calls stay in GIR Box Picks until you set it (see below)"))


def send(chat, path, cap):
    b = uuid.uuid4().hex; data = open(path, "rb").read()
    body = b"".join([("--%s\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n%s\r\n" % (b, chat)).encode(),
                     ("--%s\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n%s\r\n" % (b, cap)).encode(),
                     ("--%s\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"%s\"\r\nContent-Type: audio/mpeg\r\n\r\n" % (b, os.path.basename(path))).encode(), data,
                     ("\r\n--%s--\r\n" % b).encode()])
    rq = urllib.request.Request("https://api.telegram.org/bot%s/sendAudio" % tok, data=body, headers={"Content-Type": "multipart/form-data; boundary=" + b})
    try:
        r = json.load(urllib.request.urlopen(rq, timeout=30)); return r.get("ok"), r.get("description", "")
    except Exception as ex:
        return False, str(ex)[:80].replace(tok or "-", "***")


how = "Long-press this sound -> Save for Notifications. Then this channel -> its name at the top -> Notifications -> Sound -> pick it."
if not tok:
    print("  no Telegram token in .env - the sounds are in %s" % S)
else:
    for chat, f, cap, name in ((tn or box, "gir_p1_ambulance.mp3", "🚑 GIR P1 sound (ambulance). " + how, "the P1 sound"),
                               (box, "gir_critical_alarm.mp3", "🚨 GIR CRITICAL sound (nee-naw). " + how, "the critical sound")):
        p = os.path.join(S, f)
        if chat and os.path.exists(p) and os.path.getsize(p) > 1000:
            ok, why = send(chat, p, cap)
            print("  %s -> %s: %s" % (name, "GIR TRADE NOW" if (chat == tn and tn) else "GIR Box Picks", "sent ✓" if ok else "not sent (%s)" % why))
PY
echo "✅ patch 224 done - Ctrl + Shift + R on GIR: 🔊 P1 and 🔊 CRITICAL by the volume buttons play the two sounds."
echo "   GIR TRADE NOW not set yet? In Telegram: create a channel \"GIR Trade Now\", add the GIR bot as admin, give it the public link"
echo "   gir_tradenow for a minute, then:  python3 $D/tg_tradenow_setup.py @gir_tradenow   (then make it private again)"
echo "   undo: for f in tglanes.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart $SV"
