#!/bin/bash
# PATCH 216 - THE CHECKLIST SAYS HOW FRESH IT IS (Rama, 12 Nov: "sometimes this section for the share is not updating with the market - this
#   is also very critical"). The share window asks every 10 s; the engine keeps the 4 share windows you looked at last on LIVE ticks - any other
#   window got the chain sweep's reading, minutes old, shown as if live. Now the decision box always says: 🟢 LIVE · ticks, 2 s ago · 🟢 LIVE ·
#   the chain sweep, 1 min ago · 🟠 NOT LIVE · this reading is 14 min old (11:06) - click this window (or close others) + "DECISION (old)" ·
#   before the open: "the reading of 11-11 15:26 - decide after 09:20" as before. Tested: 6 cases. The page only - no restart, safe any time.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
grep -q "patch 214" $D/home.html || { echo "patch 214 first"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old page back - nothing changed"; exit 1; }
cat > $W/p216_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p216_patch.py - PATCH 216: THE CHECKLIST SAYS HOW FRESH IT IS (Rama, 12 Nov: "sometimes this section for the share is not updating with the
market - this is also very critical"). The share window asks for the checklist every 10 s; the engine keeps the 4 share windows you looked
at last on LIVE ticks (rebuilt every 2 s) - any other window gets the chain sweep's reading, minutes old, and the page showed it as if live.
Now the decision box always says which it is:
  🟢 LIVE · ticks, 2 s ago                     the live reading
  🟢 LIVE · the chain sweep, 1 min ago          fresh enough (up to 3 min)
  🟠 NOT LIVE · this reading is 14 min old (12:10) - GIR keeps the 4 share windows you look at live; click this window (or close
     others) - it turns live within ~10 s · and the decision is marked "(old)"
  ⏸ the reading of 11-11 15:26 - decide on the live reading after 09:20        (before the open / a closed day, as before)
Page only - no restart. Usage: python3 p216_patch.py DIR"""
import sys, os
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
p = os.path.join(D, "home.html"); s = open(p, encoding="utf-8").read()
ERR = []


def rep(old, new, tag):
    global s
    if new in s:
        print("  home.html: %s - already in" % tag); return
    if s.count(old) != 1:
        ERR.append("anchor '%s' found %d times" % (tag, s.count(old))); return
    s = s.replace(old, new); print("  home.html: %s" % tag)


rep('''  const live=c.d===today&&ist.getUTCDay()>0&&ist.getUTCDay()<6&&hm>="09:20"&&hm<="15:30";''',
    '''  const live=c.d===today&&ist.getUTCDay()>0&&ist.getUTCDay()<6&&hm>="09:20"&&hm<="15:30";
  /* patch 216: how old is this reading - live ticks, a fresh sweep, or minutes old */
  const tsec=(x=>{ const m=String(x||"").match(/^(\\d\\d):(\\d\\d)(?::(\\d\\d))?/); return m?+m[1]*3600+ +m[2]*60+ +(m[3]||0):null; })(c.t);
  const nsec=ist.getUTCHours()*3600+ist.getUTCMinutes()*60+ist.getUTCSeconds(); const age=(live&&tsec!=null)?Math.max(0,nsec-tsec):null;
  const stale=live&&c.src!=="ticks"&&age!=null&&age>180;
  const agew=a=>a==null?"":a<90?Math.round(a)+" s ago":Math.round(a/60)+" min ago";
  const fresh=!live?"":stale?`<div class="frs old">🟠 NOT LIVE · this reading is ${Math.round(age/60)} min old (${esc((c.t||"").slice(0,5))}) - GIR keeps the 4 share windows you look at on live ticks; click this window (or close others) - it turns live within ~10 s</div>`
    :`<div class="frs ok">🟢 LIVE · ${c.src==="ticks"?"ticks":"the chain sweep"}${age!=null?", "+agew(age):""}</div>`;''', "the age of the reading")
rep('''  return `<div class="dec ${cls}"><b>DECISION: ${word}</b> <span>${esc(why)}</span>${old}</div>`; }''',
    '''  return `<div class="dec ${stale?"no":cls}">${fresh}<b>DECISION${stale?" (old)":""}: ${word}</b> <span>${esc(why)}</span>${old}</div>`; }''', "the decision box says it")
rep('''/* patch 214: the push / pull strip */''', '''/* patch 216: the checklist's freshness */
.dec .frs{font:700 11px/1.5 var(--ui);letter-spacing:.03em;margin-bottom:3px}.dec .frs.ok{color:var(--up)}.dec .frs.old{color:#1a1205;background:var(--amber);padding:3px 6px;border-radius:4px}
/* patch 214: the push / pull strip */''', "the look")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
print("home.html: patch 216 in")
PY_PATCH
python3 $W/p216_patch.py $D || back
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(m.group(1) for m in re.finditer(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", s, re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the page's code checked ✓"
fi
echo "✅ patch 216 done - Ctrl + Shift + R on GIR. Each share's checklist now says 🟢 LIVE or 🟠 NOT LIVE · N min old."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
