#!/bin/bash
# PATCH 218 - THE PRE-OPEN ON GIR (Rama, 12 Nov 09:11: "pre-market - GIR still not updating · it came online a few seconds and went back to
#   this NIFTY reading"). 09:00-09:15 the page server put YESTERDAY's index picture back on every refresh (patch 157), while the live price
#   stream pushed today's NIFTY - the box flipped to today's for a second, then back. Now 09:00-09:15 on a trading day:
#   - NIFTY / BANKNIFTY / SENSEX / VIX = today's pre-open values the engine reads, each marked PRE-OPEN (a box with no pre-open value
#     yet keeps yesterday's close, unmarked) · the status line: 🌅 PRE-OPEN · trading from 09:15
#   - the page never draws an older NIFTY over the live tick, and the points always agree with the % (it showed +168.85 next to -0.16%)
#   Tested: 12 server cases + 9 page cases (the old page reproduces the flip, the new one does not).
#   Restarts the page server only (the page reconnects in ~15 s) - run it after 15:35 (or add: now).
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
H=$(TZ=Asia/Kolkata date +%H%M)
if [ "$H" -ge 0900 ] && [ "$H" -le 1535 ] && [ "${1:-}" != "now" ]; then echo "market hours - run it after 15:35 (or add: now)"; exit 1; fi
grep -q "patch 214" $D/home.html || { echo "patch 214 first"; exit 1; }
for f in dashserve.py home.html; do cp $D/$f $D/$f.bak$TS; done
back(){ for f in dashserve.py home.html; do cp $D/$f.bak$TS $D/$f; done; systemctl restart gir-dash; echo "❌ old files back - nothing changed"; exit 1; }
cat > $W/p218_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p218_patch.py - PATCH 218: THE PRE-OPEN ON GIR (Rama, 12 Nov 09:11: "pre-market - still GIR is not updating · it came online a few seconds
and went back to this NIFTY reading"). From 09:00 to 09:15 the page server put back YESTERDAY's checked index picture (patch 157, "before the
open show it") on every refresh, while the live price stream pushed today's NIFTY - the box flipped to today's for a second, then back.
Now, 09:00-09:15 on a trading day, when the engine is reading today's prices:
  - NIFTY / BANKNIFTY / SENSEX / VIX = today's pre-open values the engine reads (Kite's pre-open quote; NIFTY from its own tick, every
    second), each marked PRE-OPEN on the page - any box the engine has no pre-open value for keeps yesterday's close, as before
  - the status line says 🌅 PRE-OPEN · trading from 09:15
  - the page never draws an older NIFTY over the live tick (the cause of the flip, also for a second at a time in market hours)
Usage: python3 p218_patch.py DIR"""
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


# ---- dashserve: today's pre-open values 09:00-09:15
rep("dashserve.py", '''def _NSEI_GET(name, last):''', '''def _pre_idx(st, prev=None, now=None, q=None):
    """patch 218: 09:00-09:15 on a trading day (NSE's pre-open) - today's index values the engine reads (Kite's pre-open quote, NIFTY from
    its own tick), each with pre: True. prev = the picture shown before (yesterday's close - the previous close when a value has none).
    None outside the pre-open, or when the engine is not reading today (stopped, a holiday)"""
    now = now or dt.datetime.now(IST)
    hm = now.strftime("%H:%M")
    if now.weekday() > 4 or not ("09:00" <= hm < "09:15") or not isinstance(st, dict):
        return None
    if str(st.get("day") or "") != now.strftime("%Y-%m-%d"):
        return None
    try:
        age = (now.replace(tzinfo=None) - dt.datetime.strptime(str(st.get("ts") or "")[:19], "%Y-%m-%d %H:%M:%S")).total_seconds()
    except Exception:
        return None
    if not (-60 <= age <= 120):
        return None
    out = {}
    for k, v in (st.get("idx") or {}).items():
        if isinstance(v, dict) and v.get("last"):
            out[k] = dict(v, pre=True)
    if q is None:
        try:
            q = quotes_live()
        except Exception:
            q = None
    n = ((q or {}).get("q") or {}).get("NIFTY50")
    if n and n[0]:
        pc = (out.get("NIFTY") or {}).get("pc") or ((n[0] / (1 + n[1] / 100.0)) if n[1] is not None else None)
        out["NIFTY"] = {"last": round(float(n[0]), 2), "pc": round(pc, 2) if pc else None, "pre": True}
    for k, v in out.items():
        pc = v.get("pc")
        if not pc:
            pl = ((prev or {}).get(k) or {}).get("last")
            pc = pl if (pl and abs(v["last"] / pl - 1) < 0.15) else None
            v["pc"] = round(pc, 2) if pc else None
        v["chg"] = round((v["last"] / pc - 1) * 100, 2) if pc else v.get("chg")
    return out or None


def _NSEI_GET(name, last):''', "_pre_idx: today's pre-open values")
rep("dashserve.py", '''    if not idx and st.get("nifty") is not None:
        idx = {"NIFTY": {"last": None, "chg": st.get("nifty")}}
    now_rows = now_rows_(today)''', '''    try:                                                         # patch 218: 09:00-09:15 today's pre-open values over yesterday's picture
        pre_ = _pre_idx(st, idx)
        if pre_:
            idx = dict(idx, **pre_)
    except Exception:
        pass
    if not idx and st.get("nifty") is not None:
        idx = {"NIFTY": {"last": None, "chg": st.get("nifty")}}
    now_rows = now_rows_(today)''', "home(): the pre-open values from 09:00")

# ---- the page
rep("home.html", '''data-n="${n}" onclick="ixPick('${n}')" title="tap: its chart"><b>${n}</b>''',
    '''data-n="${n}" onclick="ixPick('${n}')" title="${x.pre?"NSE pre-open: orders 09:00-09:08, the price fixed at 09:08 - trading from 09:15 · tap: its chart":"tap: its chart"}"><b>${n}${x.pre?' <em class="ixpre">PRE-OPEN</em>':""}</b>''',
    "the boxes: PRE-OPEN")
rep("home.html", '''<span id="clk">${istClock()}</span>${st}''', '''<span id="clk">${istClock()}</span>${st}${preNow()?'<span class="ixpre" title="NSE pre-open 09:00-09:15: orders until 09:08, the opening price fixed at 09:08 - trading from 09:15">🌅 PRE-OPEN · trading from 09:15</span>':""}''',
    "the status line: PRE-OPEN")
rep("home.html", '''function istClock(){''', '''/* patch 218: the pre-open (09:00-09:15 IST on a weekday) · NIFTY's live tick before every drawing of the boxes */
function preNow(){ const d=new Date(Date.now()+19800000), hm=d.toISOString().slice(11,16), w=d.getUTCDay(); return w>0&&w<6&&hm>="09:00"&&hm<"09:15"; }
function ixLiveQ(){ if(!QT||Date.now()/1000-QT>20||!D||!D.idx) return; const n=LQ.NIFTY50; if(!n||!n[0]) return; const o=D.idx.NIFTY||{};
  const x=Object.assign({},o,{last:n[0]}); if(n[1]!=null){ x.chg=n[1]; if(!(o.pc&&Math.abs((n[0]/o.pc-1)*100-n[1])<0.05)) x.pc=Math.round(n[0]/(1+n[1]/100)*100)/100; } else if(o.pc) x.chg=Math.round((n[0]/o.pc-1)*10000)/100; D.idx.NIFTY=x; }
function istClock(){''', "preNow() · ixLiveQ()")
rep("home.html", '''function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now(); drawAlerts();
  $("idx").innerHTML=idxHTML(D);''', '''function render(D_){ D=Object.assign(D||{}, D_); lastAt=Date.now(); drawAlerts();
  ixLiveQ(); $("idx").innerHTML=idxHTML(D);   /* patch 218: never an older NIFTY over the live tick */''', "render: the live tick first")
rep("home.html", '''  const n=LQ.NIFTY50; if(n&&D&&D.idx){ D.idx.NIFTY=Object.assign({},D.idx.NIFTY||{},{last:n[0]},n[1]!=null?{chg:n[1]}:{}); } }''',
    '''  ixLiveQ(); }   /* patch 218: one rule for NIFTY's live tick */''', "overlayQ: the same rule")
rep("home.html", '''/* patch 211: alert rows that are links look the same */''', '''/* patch 218: the pre-open */
.ixpre{font:700 9px var(--ui);font-style:normal;letter-spacing:.06em;color:var(--amber);white-space:nowrap}
/* patch 211: alert rows that are links look the same */''', "the look", marker="/* patch 218: the pre-open */")
if ERR:
    print("❌ " + " · ".join(ERR)); sys.exit(1)
print("patch 218 in")
PY_PATCH
cat > $W/p218test.py <<'PY_TEST'
#!/usr/bin/env python3
"""p218test.py - patch 218: the pre-open index values (sample data, no live call). Usage: python3 p218test.py DIR"""
import sys, os, datetime as dt
D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
sys.path.insert(0, D); os.chdir(D)
import dashserve as ds
IST = ds.IST
T = lambda h, m, s=0, d=12: dt.datetime(2026, 11, d, h, m, s, tzinfo=IST)      # 12 Nov 2026 = Thursday
Y = {"NIFTY": {"last": 25255.05, "chg": 0.84, "pc": 25044.65}, "SENSEX": {"last": 81879.4, "chg": 0.95}, "BANKNIFTY": {"last": 60792.4, "chg": 1.76}, "VIX": {"last": 17.58, "chg": 0.92}}
ENG = {"NIFTY": {"last": 25224.45, "chg": -0.12, "pc": 25255.05}, "BANKNIFTY": {"last": 60858.3, "chg": 0.11, "pc": 60792.4}, "SENSEX": {"last": 81790.0, "chg": None, "pc": None}}
st = lambda ts, day="2026-11-12", idx=ENG: {"day": day, "ts": ts, "idx": idx}
Q = {"t": 0, "q": {"NIFTY50": [25213.5, -0.16]}}
ok = 0; bad = []
def chk(name, cond, got=""):
    global ok
    if cond: ok += 1; print("  ✅ " + name)
    else: bad.append(name); print("  ❌ %s · got %s" % (name, got))
r = ds._pre_idx(st("2026-11-12 09:11:20"), Y, T(9, 11, 21), Q)
chk("09:11 - NIFTY = the live pre-open tick 25,213.50 (-0.16%), marked PRE-OPEN", r and r["NIFTY"]["last"] == 25213.5 and r["NIFTY"]["chg"] == -0.16 and r["NIFTY"]["pre"], r and r.get("NIFTY"))
chk("09:11 - BANKNIFTY = the engine's pre-open quote 60,858.3", r and r["BANKNIFTY"]["last"] == 60858.3 and r["BANKNIFTY"]["chg"] == 0.11, r and r.get("BANKNIFTY"))
chk("09:11 - SENSEX with no previous close: % from yesterday's last (81,879.4) = -0.11%", r and r["SENSEX"]["chg"] == -0.11 and r["SENSEX"]["pc"] == 81879.4, r and r.get("SENSEX"))
chk("09:11 - VIX not read yet: no pre-open value (yesterday's box stays)", r and "VIX" not in r, r and list(r))
m = dict(Y, **r); chk("the merged strip: 3 pre-open boxes + yesterday's VIX", [k for k in m if m[k].get("pre")] == ["NIFTY", "SENSEX", "BANKNIFTY"] and m["VIX"]["last"] == 17.58, m)
r2 = ds._pre_idx(st("2026-11-12 09:11:20"), Y, T(9, 11, 21), {"t": 0, "q": {}})
chk("no NIFTY tick: NIFTY from the engine's quote 25,224.45 (-0.12%)", r2 and r2["NIFTY"]["last"] == 25224.45 and r2["NIFTY"]["chg"] == -0.12, r2 and r2.get("NIFTY"))
chk("08:55 (before the pre-open): nothing - yesterday's picture as before", ds._pre_idx(st("2026-11-12 08:55:00"), Y, T(8, 55), Q) is None)
chk("09:15 (trading): nothing - the normal live path", ds._pre_idx(st("2026-11-12 09:15:01"), Y, T(9, 15, 1), Q) is None)
chk("the engine's file is yesterday's: nothing", ds._pre_idx(st("2026-11-11 15:50:00", "2026-11-11"), Y, T(9, 11), Q) is None)
chk("the engine stopped 5 min ago: nothing", ds._pre_idx(st("2026-11-12 09:06:00"), Y, T(9, 11), Q) is None)
chk("Saturday: nothing", ds._pre_idx(st("2026-11-14 09:11:00", "2026-11-14"), Y, T(9, 11, 0, 14), Q) is None)
bad_pc = ds._pre_idx(st("2026-11-12 09:11:20", idx={"VIX": {"last": 17.9, "chg": None, "pc": None}}), {"VIX": {"last": 1790.0}}, T(9, 11, 21), {"t": 0, "q": {}})
chk("a previous close 99% away is not used (no wrong %)", bad_pc and bad_pc["VIX"]["chg"] is None, bad_pc)
print("%d/%d passed" % (ok, ok + len(bad)))
sys.exit(1 if bad else 0)
PY_TEST
python3 $W/p218_patch.py $D || back
cd $D && python3 -m py_compile dashserve.py || back
echo "=== test: the pre-open values (sample data)"
python3 $W/p218test.py $D || back
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
echo "=== what the engine reads now (for tomorrow 09:00-09:15 these become the PRE-OPEN boxes)"
python3 - $D <<'PY_SHOW'
import sys, os, json
D = sys.argv[1]
try:
    st = json.load(open(os.path.join(D, "dash_state.json")))
    print("   engine file: day %s · written %s" % (st.get("day"), st.get("ts")))
    for k, v in (st.get("idx") or {}).items():
        print("   %-9s %s (%s%%) prev close %s" % (k, v.get("last"), v.get("chg"), v.get("pc")))
except Exception as ex:
    print("   engine file not read:", ex)
try:
    q = json.load(open(os.path.join(D, "quotes_live.json")))
    print("   NIFTY tick: %s" % ((q.get("q") or {}).get("NIFTY50"),))
except Exception as ex:
    print("   live ticks not read:", ex)
PY_SHOW
echo "✅ patch 218 done - Ctrl + Shift + R on GIR (the phone: reload). Tomorrow 09:00-09:15 the index boxes say PRE-OPEN with today's numbers."
echo "   undo: for f in dashserve.py home.html; do cp $D/\$f.bak$TS $D/\$f; done; systemctl restart gir-dash"
