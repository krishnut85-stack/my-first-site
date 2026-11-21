#!/bin/bash
# PATCH 140c - TWO PHONE BUGS (9 Nov 12:17).
#   - ALERTS tabs: CRITICAL / OI / MOVES & NEWS now open that lane's alerts as a list down the screen (ALL closes it)
#   - the EARLY board on a phone: one card per share (time · share · BUY / WATCH · its way since; the signals, the reason, the strike)
#   home.html only (exact anchors). Restarts gir-dash only - safe in market hours.
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M); W=/tmp/g140c; mkdir -p $W
grep -q "patch 140c" $D/home.html && { echo "patch 140c is already installed"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back() { cp $D/home.html.bak$TS $D/home.html; systemctl restart gir-dash; echo "ERROR - old page back, nothing changed"; exit 1; }
cat > $W/p140c_patch.py <<'PY_PATCH'
#!/usr/bin/env python3
"""p140c_patch.py - PATCH 140c: TWO PHONE BUGS (Rama, 9 Nov 12:17).
  the ALERTS tabs  ALL / CRITICAL / OI / MOVES & NEWS filtered only the one sideways row of chips (a phone shows one chip) - "the
                   list remains the same". A lane tab now opens that lane's alerts as a list down the screen (scrolls; ALL closes it).
  the EARLY board  7 columns: on a phone the reason text was pushed off the right edge and the rows stood tall and empty. On a phone
                   each share is now a card: time · share · BUY / WATCH · its way since, then the 📰🔭💰📈 signals, the reason, the strike.
Usage: python3 p140c_patch.py /home/globalbot/intraday"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/intraday"
EDITS = {
    "home.html": [
        ('''B.className=hasA?"has-act":list.length?"has-move":"";''',
         '''B.className=(hasA?"has-act":list.length?"has-move":"")+(ALANE!=="all"?" lane":"");     /* patch 140c: a lane tab = its list */'''),
        ('''#mk .et td.ewhy{white-space:normal;min-width:220px;max-width:460px;color:var(--txt)}''',
         '''#mk .et td.ewhy{white-space:normal;min-width:220px;max-width:460px;color:var(--txt)}
/* patch 140c: a lane tab opens its alerts as a list; on a phone the EARLY board is one card per share */
#abar.lane .ac{flex-wrap:wrap;align-items:stretch;max-height:42vh;overflow-y:auto;overflow-x:hidden}#abar.lane .ch{flex:1 1 420px}
@media(max-width:700px){#abar.lane .ac{flex-direction:column;flex-wrap:nowrap}#abar.lane .ch{flex:0 0 auto;max-width:none}
  #mk .et,#mk .et tbody{display:block}#mk .et tr{display:grid;grid-template-columns:40px 1fr auto auto;gap:1px 6px;padding:4px 0;border-bottom:1px solid var(--line)}
  #mk .et td{white-space:normal;padding:0 4px}#mk .et td:nth-child(1){grid-column:1;grid-row:1}#mk .et td:nth-child(2){grid-column:2;grid-row:1}
  #mk .et td:nth-child(3){grid-column:3;grid-row:1}#mk .et td:nth-child(7){grid-column:4;grid-row:1;text-align:right}
  #mk .et td:nth-child(4){grid-column:1/-1;grid-row:2}#mk .et td.ewhy{grid-column:1/-1;grid-row:3;min-width:0;max-width:none;font-size:10.5px}
  #mk .et td:nth-child(6){grid-column:1/-1;grid-row:4;font-size:10.5px;color:var(--dim)}#q-ear .bd{max-height:46vh}}'''),
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
python3 $W/p140c_patch.py $D || { echo "the anchors did not match this server's page - nothing was changed"; exit 1; }
cd $D && for t in p136test.py p129test.py p128test.py p119test.py; do [ -f $t ] && { timeout 300 python3 $t >/dev/null 2>&1 && echo "    $t passed" || { echo "$t failed"; back; }; }; done
systemctl restart gir-dash && sleep 8
[ "$(systemctl is-active gir-dash)" = "active" ] || { echo "gir-dash did not come back"; back; }
curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8090/?k=$(cat $D/dash_token.txt)" | grep -q 200 || { echo "the page is not served"; back; }
echo
echo "PATCH 140c APPLIED. Reload the GIR page: tap CRITICAL / OI / MOVES & NEWS = their list; the EARLY board fits the phone."
