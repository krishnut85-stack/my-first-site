#!/bin/bash
# PATCH 313 - THE INDEX OPTIONS PANEL IN PROFESSIONAL TERMS (Rama, 15 Nov: "the details mentioned are not professional, both for mobile and the
#   laptop · it should be NIFTY OPTION"). The title follows the index picked: NIFTY OPTION CHAIN / BANKNIFTY OPTION CHAIN. The words:
#   SIGNAL (was DECISION) · Bullish / Bearish of 4, entry needs 3 aligned, 0 opposed · Fresh writing vs prev close: PE / CE · OI levels:
#   Support / Resistance · Spot vs prev close and day avg · SUPPORT / RESISTANCE / EXP. MOVE / OI change · FUTURES ORDER BOOK (basis,
#   bid share) · Large orders · Cancelled before fill · CE OI Δ% vs prev close. Display only: the signal, the numbers and the server
#   unchanged. Edits home.html only. No restart - refresh the page.
set -u
D=/home/globalbot/intraday; TS=$(date +%m%d%H%M%S); W=$(mktemp -d)
if grep -q "patch 313" $D/home.html; then echo "patch 313 - already in"; exit 0; fi
grep -q "function idxDeskHTML(J)" $D/home.html || { echo "home.html: the index options panel (patch 134) not found - nothing done, send this to Claude"; exit 1; }
cp $D/home.html $D/home.html.bak$TS
back(){ cp $D/home.html.bak$TS $D/home.html; echo "❌ old file back - nothing changed"; exit 1; }
cat > $W/js.html <<'JS_313'
<script>/* patch 313: the index options panel in professional terms (display only - the signal, the numbers and the server unchanged);
   its title follows the index picked: NIFTY OPTION CHAIN / BANKNIFTY OPTION CHAIN (laptop and phone) */
(function(){ if(typeof idxDeskHTML!=="function") return; const ORIG=idxDeskHTML;
  const R=[
    [/DECISION: /g,"SIGNAL: "],
    [/(\d+) ▲ · (\d+) ▼ of (\d+) · a BUY needs 3 agreeing and none against/g,"Bullish $1 · Bearish $2 of $3 · entry needs 3 aligned, 0 opposed"],
    [/writers: puts (.+?) · calls (.+?) since ([^<]+)/g,"Fresh writing vs $3: PE $1 · CE $2"],
    [/<span>FLOOR <b/g,"<span>SUPPORT <b"],[/<span>CEILING <b/g,"<span>RESISTANCE <b"],
    [/\(its trend after 30 min\)/g,"(trend after 30 min)"],
    [/walls: ([^<]+)/g,(m,x)=>"OI levels: "+x.replace(/\bfloor\b/g,"Support").replace(/\bceiling\b/g,"Resistance")],
    [/price (above|below) the last close \(([^)]+)\) and (above|below) its day average \(([^)]+)\)/g,"Spot $1 prev close $2 · $3 day avg $4"],
    [/price: the day average after the first readings/g,"Spot vs day avg: after the first readings"],
    [/before 09:30 - the first 15 minutes are noise/g,"Before 09:30 – opening volatility, no signal"],
    [/futures book: buyers ([^%]*)% of the orders waiting/g,"Futures order book: bid share $1%"],
    [/ · big: /g," · large: "],
    [/<b>FUTURES BOOK<\/b>/g,"<b>FUTURES ORDER BOOK</b>"],
    [/\(([+-]?[\d.]+) vs spot\)/g,"(basis $1)"],
    [/buyers (<b[^>]*>[^<]*<\/b>) of the orders waiting/g,"bid share $1"],
    [/big orders \(2× the usual (\S+) lots\):/g,"Large orders (≥2× avg $1 lots):"],
    [/PULLED before the price got there:/g,"Cancelled before fill:"],
    [/OI today: puts (<b>[^<]*<\/b>) · calls (<b>[^<]*<\/b>)/g,"OI change: PE $1 · CE $2"],
    [/>MOVE </g,">EXP. MOVE <"],
    [/CE OI · % vs /g,"CE OI · Δ% vs "],
    [/both option chains are read every minute from 09:15 - nothing read yet/g,"Option chain updates every minute from 09:15"],
    [/ · the last session/g," · last session"],
    [/the last close/g,"prev close"]];
  function title(){ try{ const h=document.querySelector("#q-idx > h3"); const n=(typeof IDXT!=="undefined"&&IDXT)||"NIFTY";
      const want=n+" OPTION CHAIN <span>nearest expiry · updates every minute</span>"; if(h&&h.innerHTML!==want) h.innerHTML=want; }catch(e){} }
  idxDeskHTML=function(J){ let h=ORIG(J); try{ for(const [a,b] of R) h=h.replace(a,b); }catch(e){} setTimeout(title,0); return h; };
  title(); setInterval(title,3000); })();
</script>
JS_313
python3 - $D/home.html $W/js.html <<'PY_EDIT' || back
import sys
h, j = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
t = open(h, encoding="utf-8").read()
if t.count("</body>") != 1:
    print("❌ home.html: </body> x%d - send this to Claude" % t.count("</body>")); sys.exit(1)
open(h, "w", encoding="utf-8").write(t.replace("</body>", j + "\n</body>", 1)); print("  home.html: the option chain panel in professional terms")
PY_EDIT
if command -v node >/dev/null 2>&1; then
  python3 - $D/home.html $W/page.js <<'PY_JS'
import re, sys
open(sys.argv[2], "w", encoding="utf-8").write("\n;\n".join(re.findall(r"<script>(.*?)</script>", open(sys.argv[1], encoding="utf-8").read(), re.S)))
PY_JS
  node --check $W/page.js 2>$W/js.err || { head -5 $W/js.err; back; }
  echo "  the home page's code checked ✓"
fi
echo "✅ patch 313 done - NIFTY OPTION CHAIN / BANKNIFTY OPTION CHAIN in professional terms (laptop and phone). Refresh the page."
echo "   undo: cp $D/home.html.bak$TS $D/home.html"
