#!/bin/bash
# PATCH 140b - ON A PHONE THE POP-UPS NO LONGER COVER THE ALERT TABS.
#   9 Nov 12:14: the ALL / CRITICAL / OI / MOVES & NEWS tabs and the EARLY header were hidden under two SOMETHING IS HAPPENING pop-ups.
#   On a phone the pop-ups now sit at the bottom (above the NEWS ticker), one at a time, 12 s (a TRADE ALERT 60 s), swipe / ✕ closes.
#   home.html only (exact anchors). Restarts gir-dash only - safe in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140b; mkdir -p $W
grep -q "patch 140b" $D/home.html && { echo "patch 140b is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p140b_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140b_patch.py - PATCH 140b: ON A PHONE THE POP-UPS NO LONGER COVER THE ALERT TABS. Rama, 9 Nov 12:14: the ALL / CRITICAL / OI /
MOVES & NEWS tabs and the EARLY header "disappeared" - two SOMETHING IS HAPPENING pop-ups sat on them (top, 25 s each). On a phone
(700 px or less): the pop-ups sit at the BOTTOM (above the NEWS ticker), one at a time, close after 12 s (a TRADE ALERT after 60 s),
a swipe or ✕ closes one. Wider screens unchanged.
Usage: python3 p140b_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "home.html": [
        ('''  #toasts .ta .tl{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-size:10.5px}#toasts .ta .tg2{font-size:9px}}''',
         '''  #toasts .ta .tl{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-size:10.5px}#toasts .ta .tg2{font-size:9px}
  #toasts{top:auto !important;bottom:calc(var(--tickh,34px) + 8px);flex-direction:column-reverse}#toasts .ta:nth-child(n+2){display:none}   /* patch 140b: at the bottom, one at a time */}'''),
        ('''  setTimeout(()=>{ try{ el.remove(); }catch(e){} }, tr==="act"?60000:25000); }''',
         '''  const ph=window.matchMedia&&window.matchMedia("(max-width:700px)").matches;          /* patch 140b: a phone - shorter, and a swipe closes it */
  if(ph){ let x0=null; el.addEventListener("touchstart",e=>{ x0=e.touches[0].clientX; },{passive:true}); el.addEventListener("touchend",e=>{ if(x0!=null&&Math.abs(e.changedTouches[0].clientX-x0)>50){ e.preventDefault(); el.remove(); } x0=null; }); }
  setTimeout(()=>{ try{ el.remove(); }catch(e){} }, tr==="act"?60000:(ph?12000:25000)); }'''),
    ],
}


def main():
    out = {}
    for fn, eds in EDITS.items():
        p = os.path.join(D, fn)
        s = open(p, encoding="utf-8").read()
        for a, b in eds:
            n = s.count(a)
            if n != 1:
                print("ANCHOR %s x%d in %s: %s" % ("missing" if n == 0 else "not unique", n, fn, a[:90].replace("\n", " | ")))
                return 1
            s = s.replace(a, b)
        out[p] = s
    for p, s in out.items():
        open(p, "w", encoding="utf-8").write(s)
    print("patched: %s" % ", ".join(sorted(EDITS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY_PATCH
python3 $W/p140b_patch.py $D || { echo "the anchors did not match this server's page - nothing was changed"; exit 1; }
cd $D && for t in p136test.py p129test.py p128test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 140b APPLIED. Reload the GIR page on the phone: pop-ups now at the bottom, the alert tabs stay visible."
